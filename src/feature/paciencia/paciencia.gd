class_name Paciencia extends Node
## Paciencia y Satisfacción (#10) — el sistema que convierte la ESPERA en CONSECUENCIA.
##
## Esta story (001) implementa el núcleo: la **barra individual** de cada persona que espera y la
## fórmula **F1** que la drena. Es todo lógica pura + estado: aquí NADIE se marcha todavía (el
## abandono real, enganchado al tick, es la story 002) y nadie puntúa nada (003).
##
## Reparto de propiedad (arquitectura): la paciencia es estado de ESTE sistema, no de `PersonaFlujo`
## — Flujo no sabe qué es la paciencia, y cuando toque marcharse será Paciencia quien se lo ORDENE
## por la API pública (`Flujo.forzar_abandono`), nunca tocando sus colas (ADR-0001).
##
## Determinismo (ADR-0001): F1 es una función pura del estado y de los minutos transcurridos; no hay
## aleatoriedad en esta story (el RNG llega en la 006, y será SIEMPRE vía RNGService).
##
## Story: production/epics/paciencia/story-001-nucleo-config-drenaje.md · TR-patience-001 · ADR-0003

const RUTA_CONFIG := "res://datos/config/paciencia.tres"
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
## La persona del flujo — preload por RUTA (gotcha del headless en frío) para leer sus estados.
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")

## Los servicios que vigila (las mismas claves que Flujo y el catálogo).
const SERVICIOS: Array[StringName] = [&"Documentacion", &"ODAC"]

## Paciencia con la que se entra a la cola (PS1: la barra empieza LLENA al coger turno).
const PACIENCIA_INICIAL := 100.0
## Ánimo derivado de la paciencia (PS5). Texto + color en la UI — nunca solo color (daltónicos).
const ANIMO_CONTENTO := &"contento"       # 🟢
const ANIMO_IMPACIENTE := &"impaciente"   # 🟡
const ANIMO_AL_LIMITE := &"al_limite"     # 🔴
## Centinela de "esta persona no está en el sistema" (nunca se confunde con una paciencia real 0-100).
const SIN_PACIENCIA := -1.0

# ── Tuning (del `.tres`; ver ConfigPaciencia) ────────────────────────────────────────────────
var tolerancia_base_min: float = 30.0
var k_hacinamiento: float = 1.0
var mult_comodidad: float = 1.0
var mult_horapunta: float = 1.0
var umbral_animo_alto: float = 66.0
var umbral_animo_bajo: float = 33.0

## Persona (RefCounted de Flujo) → paciencia restante [0, 100]. La persona es la CLAVE: vive mientras
## Flujo la referencie, y Paciencia la suelta al resolverse o marcharse (`olvidar`).
var _paciencia_de: Dictionary = {}

# ── Sistemas inyectados (dependency injection → testeable sin autoloads ni Main) ─────────────
var _flujo: Node = null
var _construccion: Node = null
var _tiempo: Node = null
var _suscrito_al_tick: bool = false

## Buffers REUTILIZADOS entre ticks (regla del proyecto: cero allocs en el bucle de simulación —
## esto corre en cada tick con toda la sala dentro). Se limpian, no se recrean.
var _a_abandonar: Array[RefCounted] = []


func _ready() -> void:
	# Auto-resuelve el reloj real cuando corre en el juego (patrón de Flujo/Economía); en los tests
	# se inyecta uno de mentira con `usar_tiempo` y este get_node no encuentra nada.
	if _tiempo == null:
		usar_tiempo(get_node_or_null("/root/Tiempo"))
	_cargar_config()


# ── Inyección de dependencias (ADR-0001: se ORDENA por API, jamás se muta a otro sistema) ────

## Inyecta Flujo: de él se leen las colas y a él se le ORDENA el abandono (`forzar_abandono`).
## Sin Flujo, Paciencia no hace nada en el tick (las funciones puras de la 001 siguen valiendo).
func usar_flujo(flujo: Node) -> void:
	_flujo = flujo


## Inyecta Construcción para conocer el AFORO de cada servicio (hacinamiento, F1). Sin ella no hay
## sala que medir → multiplicador 1.0 (el drenaje base ya castiga la espera).
func usar_construccion(construccion: Node) -> void:
	_construccion = construccion


## Inyecta el reloj y se suscribe a su tick (idempotente).
## ⚠️ ORDEN DEL ADR-0001: Paciencia se suscribe SIEMPRE DESPUÉS de Flujo (Tiempo → Demanda → Flujo →
## Paciencia). Así, dentro de un mismo tick, Flujo ya ha llamado a quien tocaba ANTES de que
## Paciencia mire quién se harta: por eso el empate llamada-vs-abandono lo gana la llamada (AC-PS19)
## sin necesidad de ninguna regla especial.
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo
	if _suscrito_al_tick or tiempo == null:
		return
	tiempo.suscribir_tick(_al_tick)
	_suscrito_al_tick = true


# ── El tick: drenar, hartarse y marcharse ────────────────────────────────────────────────────

## Un paso de simulación: `delta_min` son MINUTOS DE JUEGO (en Pausa el reloj no llama — AC-PS22:
## la paciencia no drena sola, no hace falta lógica de pausa aquí).
##
## Orden dentro del tick (determinista):
##   1. recorrer cada servicio, en orden de turno, drenando a quien ESPERA;
##   2. anotar a quien llegó a 0 (nunca abandonar DENTRO del bucle — gotcha ya visto en Flujo);
##   3. ordenar los abandonos por turno y ordenárselos a Flujo uno a uno;
##   4. soltar a quien ya no espera (atendida o marchada).
func _al_tick(delta_min: float) -> void:
	if _flujo == null or delta_min <= 0.0:
		return
	_a_abandonar.clear()
	for servicio: StringName in SERVICIOS:
		_drenar_servicio(servicio, delta_min)
	_a_abandonar.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.numero_turno < b.numero_turno
	)
	for persona: RefCounted in _a_abandonar:
		# `forzar_abandono` devuelve FALSE si a esa persona ya la han llamado (regla dura de Flujo):
		# en ese caso NO se va y NO cuenta como abandono — la llamada le ganó la carrera (AC-PS19).
		if _flujo.forzar_abandono(persona):
			olvidar(persona)
	_purgar_terminadas()


## Drena la barra de todos los que esperan un servicio. Los que ya han sido LLAMADOS o están EN
## ATENCIÓN quedan CONGELADOS (AC-PS04): su espera terminó, aunque aún estén cruzando la sala hacia
## la ventanilla (enmienda 2026-07-25 "en camino no se tramita" — un caso que el GDD no preveía).
func _drenar_servicio(servicio: StringName, delta_min: float) -> void:
	var personas: Array = _flujo.personas_de_cola(servicio)
	if personas.is_empty():
		return
	# El hacinamiento se mide con la sala: se aplica a TODOS los de ese servicio (quien no cupo está
	# esperando en la calle por culpa de la misma sala desbordada — su experiencia no es mejor).
	var mult: float = mult_hacinamiento(_flujo.ocupacion_dentro(servicio), _aforo_de(servicio))
	personas.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.numero_turno < b.numero_turno
	)
	for persona: RefCounted in personas:
		registrar(persona)
		if not _espera(persona):
			continue   # llamada / en atención: conserva su barra tal cual, congelada
		if drenar(persona, delta_min, mult) <= 0.0:
			_a_abandonar.append(persona)


## ¿Esta persona está ESPERANDO (dentro o fuera)? Solo entonces drena su paciencia.
func _espera(persona: RefCounted) -> bool:
	return (
		persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
		or persona.estado == PersonaFlujoScript.ESTADO_ESPERANDO_FUERA
	)


## El aforo del servicio según Construcción; sin ella inyectada → -1 ("sin sala que medir").
func _aforo_de(servicio: StringName) -> int:
	if _construccion == null:
		return -1
	return _construccion.aforo_de_servicio(servicio)


## Suelta a quien ya TERMINÓ su visita (atendida o marchada). Sin esto el diccionario crecería para
## siempre.
##
## ⚠️ Se mira el ESTADO de la persona, NO si sigue en la cola: al llamar a alguien, Flujo lo saca de
## la cola (`retirar_de_cola` en el emparejamiento), así que "no está en la cola" NO significa "ya no
## cuenta" — significa que está siendo atendido y su barra debe conservarse congelada (AC-PS04, y la
## necesita la story 003 para puntuar la visita con la paciencia que gastó esperando).
func _purgar_terminadas() -> void:
	var terminadas: Array = []
	for persona: RefCounted in _paciencia_de:
		if (
			persona.estado == PersonaFlujoScript.ESTADO_RESUELTA
			or persona.estado == PersonaFlujoScript.ESTADO_ABANDONANDO
		):
			terminadas.append(persona)
	for persona: RefCounted in terminadas:
		_paciencia_de.erase(persona)


# ── Alta y baja de personas ──────────────────────────────────────────────────────────────────

## PS1 — la persona coge turno: entra con la barra LLENA. Idempotente: registrar dos veces a la
## misma persona NO le regala paciencia (evita que un re-registro accidental borre su espera).
func registrar(persona: RefCounted) -> void:
	if persona == null or _paciencia_de.has(persona):
		return
	_paciencia_de[persona] = PACIENCIA_INICIAL


## La persona sale del sistema (atendida o marchada): Paciencia la suelta.
func olvidar(persona: RefCounted) -> void:
	_paciencia_de.erase(persona)


## ¿Está esta persona esperando bajo el ojo de Paciencia?
func tiene(persona: RefCounted) -> bool:
	return _paciencia_de.has(persona)


## Paciencia restante [0, 100] de una persona; `SIN_PACIENCIA` (-1) si no está registrada.
func paciencia_de(persona: RefCounted) -> float:
	return _paciencia_de.get(persona, SIN_PACIENCIA)


## Cuántas personas vigila ahora mismo (getter para tests y HUD).
func personas_vigiladas() -> int:
	return _paciencia_de.size()


# ── F1 · Drenaje (funciones PURAS + su aplicación) ───────────────────────────────────────────

## F1 — multiplicador por hacinamiento: 1.0 mientras la sala no supere su aforo; por encima, crece
## con lo llena que esté (`1 + k × exceso/aforo`). Aforo 0 o negativo → 1.0 (sin sala que medir: el
## drenaje base ya castiga la espera; no inventamos un infinito).
func mult_hacinamiento(ocupacion: int, aforo: int) -> float:
	if aforo <= 0 or ocupacion <= aforo:
		return 1.0
	return 1.0 + k_hacinamiento * (float(ocupacion - aforo) / float(aforo))


## F1 — puntos de paciencia que se pierden por MINUTO DE JUEGO en las condiciones dadas.
## `tolerancia_base_min` <= 0 sería una división por cero: se trata como "paciencia infinita" (0.0),
## que es lo seguro (nadie abandona) en vez de petar.
func tasa_drenaje(mult_hac: float = 1.0) -> float:
	if tolerancia_base_min <= 0.0:
		return 0.0
	return (100.0 / tolerancia_base_min) * mult_hac * mult_comodidad * mult_horapunta


## Minutos que le quedan a una barra llena antes de llegar a 0 en estas condiciones (para tests, UI
## y la espera estimada). Tasa 0 → -1.0 centinela "no se agota" (NUNCA ∞ ni división por cero —
## misma convención que las fórmulas de Flujo).
func minutos_hasta_agotar(mult_hac: float = 1.0) -> float:
	var tasa: float = tasa_drenaje(mult_hac)
	if tasa <= 0.0:
		return -1.0
	return PACIENCIA_INICIAL / tasa


## Aplica F1 a UNA persona durante `delta_min` minutos de juego y devuelve su paciencia resultante
## (0 = lista para marcharse; la 002 decidirá qué hacer con eso). No baja de 0: una barra vacía no
## se vuelve más vacía por seguir esperando.
func drenar(persona: RefCounted, delta_min: float, mult_hac: float = 1.0) -> float:
	if not _paciencia_de.has(persona) or delta_min <= 0.0:
		return paciencia_de(persona)
	var restante: float = maxf(float(_paciencia_de[persona]) - tasa_drenaje(mult_hac) * delta_min, 0.0)
	_paciencia_de[persona] = restante
	return restante


# ── PS5 · Ánimo derivado (lo pinta la UI; DERIVADO, nunca estado paralelo) ───────────────────

## Ánimo que corresponde a una paciencia dada: contento por encima del umbral alto, al límite por
## debajo del bajo, impaciente en medio. Los umbrales son CONFIG (la UI los lee, no los inventa).
## Casos del GDD (AC-PS05): 80 → contento · 50 → impaciente · 20 → al límite.
func animo_de(paciencia: float) -> StringName:
	if paciencia > umbral_animo_alto:
		return ANIMO_CONTENTO
	if paciencia < umbral_animo_bajo:
		return ANIMO_AL_LIMITE
	return ANIMO_IMPACIENTE


## Atajo: el ánimo de una persona registrada (sin registrar → al límite, el caso conservador).
func animo_de_persona(persona: RefCounted) -> StringName:
	var valor: float = paciencia_de(persona)
	if valor == SIN_PACIENCIA:
		return ANIMO_AL_LIMITE
	return animo_de(valor)


# ── Config (patrón del proyecto: fallback seguro + clamps con aviso) ─────────────────────────

## Aplica un `ConfigPaciencia` con clamps. Config nula o de otro tipo → defaults con aviso (no peta).
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigPacienciaScript):
		push_warning("Paciencia: config invalido -> defaults")
		config = ConfigPacienciaScript.new()
	tolerancia_base_min = clampf(config.tolerancia_base_min, 1.0, 600.0)
	k_hacinamiento = clampf(config.k_hacinamiento, 0.0, 10.0)
	mult_comodidad = clampf(config.mult_comodidad, 0.1, 2.0)
	mult_horapunta = clampf(config.mult_horapunta, 0.1, 3.0)
	umbral_animo_alto = clampf(config.umbral_animo_alto, 0.0, 100.0)
	umbral_animo_bajo = clampf(config.umbral_animo_bajo, 0.0, 100.0)
	# Invariante: el umbral bajo NUNCA por encima del alto (si el .tres viniera cruzado, se ordenan
	# en vez de dejar una franja imposible donde el ánimo no se pudiera calcular).
	if umbral_animo_bajo > umbral_animo_alto:
		push_warning("Paciencia: umbrales de animo cruzados -> se ordenan")
		var intercambio: float = umbral_animo_alto
		umbral_animo_alto = umbral_animo_bajo
		umbral_animo_bajo = intercambio


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Paciencia: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)
