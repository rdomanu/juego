class_name Paciencia extends Node
## Paciencia y Satisfacción (#10) — el sistema que convierte la ESPERA en CONSECUENCIA.
##
## Implementado hasta ahora: la **barra individual** de cada persona que espera y **F1** (drenaje, con
## el hacinamiento acelerándolo) [001] · el enganche al **tick**, la congelación al ser llamada y el
## **abandono** ordenado a Flujo [002] · **F2**, la puntuación de cada visita [003].
##
## Reparto de propiedad (arquitectura): la paciencia es estado de ESTE sistema, no de `PersonaFlujo`
## — Flujo no sabe qué es la paciencia, y cuando toque marcharse será Paciencia quien se lo ORDENE
## por la API pública (`Flujo.forzar_abandono`), nunca tocando sus colas (ADR-0001).
##
## Determinismo (ADR-0001): F1 es una función pura del estado y de los minutos transcurridos; no hay
## aleatoriedad en esta story (el RNG llega en la 006, y será SIEMPRE vía RNGService).
##
## Stories: paciencia 001 (núcleo+F1) · 002 (tick/abandono) · 003 (F2) · TR-patience-001..003 · ADR-0001/0003

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
## La ficha de Demanda (para FABRICAR la reclamación que genera un abandono — story 006).
const PersonaScript := preload("res://src/core/demanda/persona.gd")
## El trámite de la hoja de reclamaciones en el catálogo (30 min, Normal, ODAC, SIN tarifa).
const TRAMITE_RECLAMACION := &"reclamacion"
## La celda por la que se entra al edificio (misma que usa Flujo para medir el camino a la ventanilla).
const CELDA_ENTRADA := Vector2i(0, 6)

# ── Tuning (del `.tres`; ver ConfigPaciencia) ────────────────────────────────────────────────
var tolerancia_base_min: float = 30.0
var k_hacinamiento: float = 1.0
var mult_comodidad: float = 1.0
var k_confort: float = 0.02
var mult_comodidad_min: float = 0.6
var prob_uso_comodidad_min: float = 0.04
var umbral_uso_comodidad: float = 75.0
var max_usos_comodidad: int = 2
var prob_consumidor: float = 0.45
var mult_horapunta: float = 1.0
var umbral_animo_alto: float = 66.0
var umbral_animo_bajo: float = 33.0
var puntuacion_base: float = 80.0
var k_espera: float = 0.5
var sat_inicial: float = 50.0
var peso_prioridad_prioritaria: float = 2.5
var prob_reclamacion: float = 0.4
var penalizacion_colado: float = 10.0

# ── Contadores de reclamaciones (story 006 · KPI de eficiencia) ──────────────────────────────
## Hojas de reclamaciones de la jornada en curso y del mes (las **graves** —urgencias de ODAC
## abandonadas— se cuentan aparte: no es lo mismo perder un DNI que perder una denuncia por VioGén).
var reclamaciones_jornada: int = 0
var reclamaciones_mes: int = 0
var reclamaciones_graves_jornada: int = 0
var reclamaciones_graves_mes: int = 0

## Persona (RefCounted de Flujo) → paciencia restante [0, 100]. La persona es la CLAVE: vive mientras
## Flujo la referencie, y Paciencia la suelta al resolverse o marcharse (`olvidar`).
var _paciencia_de: Dictionary = {}
## Persona → paciencia que le quedaba **en el momento de ser LLAMADA** (story 003). Es el dato con el
## que se puntúa la visita: lo que molesta es la ESPERA, no lo que dure el trámite después.
var _paciencia_al_llamar: Dictionary = {}
## Persona → minutos que le quedan de CAMINO HASTA SU SITIO de espera (enmienda 2026-07-26). Mientras
## camina no gasta paciencia: todavía no está esperando, está yendo.
var _camino_a_su_sitio: Dictionary = {}
## Quién está AHORA usando una comodidad y cuánto le queda (story com-003):
## `persona -> {elemento: StringName, restante: float}`. Mientras usa, su paciencia **no baja**: está
## entretenida, que es exactamente lo que el jugador ha comprado. Se serializa con el resto.
var _usando_comodidad: Dictionary = {}
## Veces que cada persona YA se ha levantado en esta visita: `persona -> int`. El tope
## (`max_usos_comodidad`) es lo que impide que quien espera mucho acabe dando cuatro viajes a la
## máquina — a la ventanilla se va a un trámite, no a merendar (feedback del usuario 2026-07-28).
var _usos_comodidad: Dictionary = {}
## ¿Es de los que consumen? `persona -> bool`, decidido UNA vez y para siempre. Hay gente que no toma
## nada ni bebe agua por mucho que espere, y una sala donde TODOS acaban yendo a la máquina no se
## parece a una sala de verdad. Se decide PEREZOSAMENTE (la primera vez que haría falta), no al
## registrarse: así el dado solo se tira cuando de verdad importa y no se altera la secuencia del RNG
## en partidas sin comodidades instaladas.
var _consumidor_de: Dictionary = {}

# ── Sistemas inyectados (dependency injection → testeable sin autoloads ni Main) ─────────────
var _flujo: Node = null
var _construccion: Node = null
var _personal: Node = null
var _tiempo: Node = null
var _bus: Node = null
var _economia: Node = null
var _rng: Node = null
var _suscrito_al_tick: bool = false

## Buffers REUTILIZADOS entre ticks (regla del proyecto: cero allocs en el bucle de simulación —
## esto corre en cada tick con toda la sala dentro). Se limpian, no se recrean.
var _a_abandonar: Array[RefCounted] = []

# ── F3 · La satisfacción del día (story 004) ─────────────────────────────────────────────────
## Acumuladores de la jornada EN CURSO por servicio: numerador y denominador de la media ponderada.
## Se guardan como suma, no como lista de visitas → memoria constante aunque pasen 400 personas.
var _suma_puntuaciones: Dictionary[StringName, float] = {}
var _peso_total: Dictionary[StringName, float] = {}
## `sat_cierre` de cada servicio: la media CERRADA de la jornada anterior. **Es la que manda en el
## dinero** (Economía la usa para el retorno DGP), no la de hoy — así el ingreso no baila intradía.
var _sat_cierre: Dictionary[StringName, float] = {}
## Visitas cerradas por servicio en la jornada (para F5, la media global ponderada por volumen).
var _visitas_jornada: Dictionary[StringName, int] = {}

## Barras leídas de un guardado, a la espera de que Flujo reconstruya a sus dueños (story 007). La
## clave es ESTABLE (`servicio#turno`), no el objeto: al cargar, las PersonaFlujo son objetos NUEVOS.
var _restaurables: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	# Auto-resuelve los autoloads reales cuando corre en el juego (patrón de Flujo/Economía); en los
	# tests se inyectan dobles y estos get_node no encuentran nada.
	if _tiempo == null:
		usar_tiempo(get_node_or_null("/root/Tiempo"))
	if _bus == null:
		usar_bus(get_node_or_null("/root/EventBus"))
	if _rng == null:
		_rng = get_node_or_null("/root/RNGService")
	_cargar_config()
	add_to_group("Persist")   # ADR-0002: el SaveManager recolecta por grupo; clave = node.name


# ── Inyección de dependencias (ADR-0001: se ORDENA por API, jamás se muta a otro sistema) ────

## Inyecta Flujo: de él se leen las colas y a él se le ORDENA el abandono (`forzar_abandono`).
## Sin Flujo, Paciencia no hace nada en el tick (las funciones puras de la 001 siguen valiendo).
func usar_flujo(flujo: Node) -> void:
	_flujo = flujo


## Inyecta Construcción para conocer el AFORO de cada servicio (hacinamiento, F1). Sin ella no hay
## sala que medir → multiplicador 1.0 (el drenaje base ya castiga la espera).
func usar_construccion(construccion: Node) -> void:
	_construccion = construccion


## Inyecta el EventBus y engancha el cierre de jornada como evento ORDENADO.
## ⚠️ PRIORIDAD 10 en `nuevo_dia`: Paciencia cierra su media ANTES de que Economía cobre (prio 20),
## porque el retorno DGP de hoy se calcula con el `sat_cierre` que acaba de fijarse. El orden estaba
## previsto en el propio comentario de Economía: "Paciencia 10 · Economía 20".
func usar_bus(bus: Node) -> void:
	_bus = bus
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 10, _al_nuevo_dia)
		# nuevo_mes: Economía 10 · Paciencia 20 (el orden previsto en el comentario de Economía).
		_bus.registrar_ordenado(&"nuevo_mes", 20, _al_nuevo_mes)


## Inyecta Economía: al cerrar la jornada se le pasa el `sat_cierre` de Documentación, que es con el
## que cobrará TODO el día siguiente (F4 — la fórmula es de Economía; Paciencia solo aporta el dato).
## Sin Economía inyectada, Paciencia funciona igual: el dinero simplemente no se entera (story 005).
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta el RNG determinista (ADR-0002). **Nunca** se usa `randf` propio: el generador es único y su
## estado lo serializa RNGService, para que la misma semilla dé exactamente las mismas reclamaciones.
func usar_rng(rng: Node) -> void:
	_rng = rng


## Inyecta Personal para leer el 🤝Trato del agente que atiende (F2). Sin él → trato neutro (1.0).
func usar_personal(personal: Node) -> void:
	_personal = personal


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
	# Las que ya están en ventanilla no salen en ninguna cola: se las reconoce aparte para que, tras
	# cargar una partida, recuperen su barra en vez de aparecer como desconocidas (story 007).
	for persona: RefCounted in _flujo.personas_en_puestos():
		registrar(persona)
	_a_abandonar.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.numero_turno < b.numero_turno
	)
	for persona: RefCounted in _a_abandonar:
		# `forzar_abandono` devuelve FALSE si a esa persona ya la han llamado (regla dura de Flujo):
		# en ese caso NO se va y NO cuenta como abandono — la llamada le ganó la carrera (AC-PS19).
		# ⚠️ Si se va, NO se la olvida aquí: queda en estado Abandonando y la recoge `_purgar_terminadas`,
		# que ANOTA su visita (puntuación 0) antes de soltarla. Olvidarla aquí borraría el peor dato de
		# la jornada justo antes de contarlo — la satisfacción saldría inflada y nadie lo notaría.
		if _flujo.forzar_abandono(persona):
			procesar_abandono(persona)   # story 006: cuenta la hoja y quizá genere una reclamación
	_anotar_llamadas()
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
	# Lo que el jugador haya comprado para esta sala (story com-002): se calcula UNA vez por servicio
	# y por tick, no por persona — es el mismo número para todos los que esperan ahí.
	var mult_com: float = mult_comodidad_de(servicio)
	personas.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.numero_turno < b.numero_turno
	)
	for persona: RefCounted in personas:
		registrar(persona)
		if not _espera(persona):
			continue   # llamada / en atención: conserva su barra tal cual, congelada
		# ENMIENDA 2026-07-26: el paseo hasta su sitio NO es espera. Los minutos se gastan primero en
		# llegar; solo lo que sobra empieza a consumir paciencia (y normalmente no sobra nada en ese
		# primer tramo, así que la barra no se mueve hasta que se sienta).
		var minutos: float = _consumir_camino(persona, delta_min)
		if minutos <= 0.0:
			continue
		# ¿Está en el vending / la fuente / el revistero? Entonces no está sufriendo la cola
		# (story com-003). Al volver trae paciencia nueva y, si consumió, un euro para la caja.
		minutos = _consumir_uso_comodidad(persona, minutos)
		if minutos <= 0.0:
			continue
		if _quizas_ir_a_una_comodidad(persona, servicio, minutos):
			continue
		if drenar(persona, minutos, mult, mult_com) <= 0.0:
			_a_abandonar.append(persona)


## Gasta `delta_min` en el camino pendiente hasta su sitio y devuelve los minutos que SOBRAN (los que
## ya cuentan como espera de verdad). Sin camino pendiente, devuelve el delta entero.
## **Comodidades de USO (story com-003)** · Gasta los minutos que la persona está en la máquina. Al
## terminar el gesto: recupera paciencia, **entra el dinero de la consumición** y vuelve a su sitio.
## Devuelve los minutos que SOBRAN para la espera normal (0 si sigue allí).
func _consumir_uso_comodidad(persona: RefCounted, delta_min: float) -> float:
	if not _usando_comodidad.has(persona):
		return delta_min
	var uso: Dictionary = _usando_comodidad[persona]
	var restante: float = float(uso["restante"]) - delta_min
	if restante > 0.0:
		uso["restante"] = restante
		return 0.0
	_usando_comodidad.erase(persona)
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", uso["catalogo"])
	if comodidad != null:
		# Vuelve más calmado (la barra sube, con tope 100) y deja su euro si ha consumido.
		_paciencia_de[persona] = minf(
			float(_paciencia_de.get(persona, 0.0)) + comodidad.recupera_paciencia, PACIENCIA_INICIAL
		)
		if comodidad.ingreso_por_uso_eur > 0.0 and _economia != null 				and _economia.has_method("registrar_consumicion"):
			_economia.registrar_consumicion(comodidad.ingreso_por_uso_eur)
	return maxf(-restante, 0.0)   # lo que sobra del minuto ya cuenta como espera normal


## ¿Se levanta a por un café? Solo quien **ya lleva un rato** esperando (por debajo del umbral) y con
## una probabilidad por minuto — el azar viene SIEMPRE de RNGService (determinista, ADR-0002). Elige
## el objeto usable de su sala que más paciencia le devuelva: la gente va a lo que más le apetece.
## Devuelve `true` si se ha levantado (ese minuto ya no cuenta como espera).
func _quizas_ir_a_una_comodidad(persona: RefCounted, servicio: StringName, minutos: float) -> bool:
	if _construccion == null or _rng == null:
		return false
	if int(_usos_comodidad.get(persona, 0)) >= max_usos_comodidad:
		return false   # ya ha ido lo suyo: se queda en el sitio esperando su turno
	if float(_paciencia_de.get(persona, 100.0)) > umbral_uso_comodidad:
		return false
	if not es_consumidor(persona):
		return false   # hay quien no toma nada ni aunque le den las tantas
	if _rng.randf() > prob_uso_comodidad_min * minutos:
		return false
	var elegido: StringName = _mejor_comodidad_usable(servicio)
	if elegido == &"":
		return false
	var comodidad: Resource = Datos.obtener_silencioso(
		&"Comodidad", _construccion.catalogo_de_elemento(elegido)
	)
	if comodidad == null:
		return false
	_usando_comodidad[persona] = {
		"elemento": elegido,
		"catalogo": _construccion.catalogo_de_elemento(elegido),
		"restante": comodidad.minutos_de_uso,
	}
	# Se cuenta al LEVANTARSE, no al volver: si le llaman a media consumición, el viaje ya lo ha
	# hecho — si no, cortarle el café le regalaría un viaje extra.
	_usos_comodidad[persona] = int(_usos_comodidad.get(persona, 0)) + 1
	return true


## ¿Esta persona es de las que consumen? Se decide la PRIMERA vez que se pregunta (cuando ya lleva
## esperando y hay algo que usar) y no cambia en toda su visita: el mismo ciudadano no puede ser de
## los que pasan del vending un minuto y de los que van corriendo al siguiente. Se serializa.
func es_consumidor(persona: RefCounted) -> bool:
	if not _consumidor_de.has(persona):
		if _rng == null:
			return false
		_consumidor_de[persona] = _rng.randf() < prob_consumidor
	return bool(_consumidor_de[persona])


## El objeto USABLE de las salas de espera del servicio que más paciencia devuelve (desempate estable
## por id). `&""` si no hay ninguno instalado.
func _mejor_comodidad_usable(servicio: StringName) -> StringName:
	var mejor: StringName = &""
	var mejor_valor: float = -1.0
	for elemento_id: StringName in _construccion.usables_de_servicio(servicio):
		var comodidad: Resource = Datos.obtener_silencioso(
			&"Comodidad", _construccion.catalogo_de_elemento(elemento_id)
		)
		if comodidad == null:
			continue
		if comodidad.recupera_paciencia > mejor_valor:
			mejor = elemento_id
			mejor_valor = comodidad.recupera_paciencia
	return mejor


## El elemento que esta persona está usando ahora mismo (`&""` si ninguno). Lo LEE la capa de NPCs
## para mandar al muñeco hasta la máquina y traerlo de vuelta — cosmético puro.
func comodidad_en_uso(persona: RefCounted) -> StringName:
	if not _usando_comodidad.has(persona):
		return &""
	return _usando_comodidad[persona]["elemento"]


func _consumir_camino(persona: RefCounted, delta_min: float) -> float:
	var restante: float = float(_camino_a_su_sitio.get(persona, 0.0))
	if restante <= 0.0:
		return delta_min
	if restante >= delta_min:
		_camino_a_su_sitio[persona] = restante - delta_min
		return 0.0
	_camino_a_su_sitio.erase(persona)
	return delta_min - restante


## Minutos que tarda esta persona en llegar a su sitio de espera desde la entrada (enmienda
## 2026-07-26: *"si están de camino a la sala de espera, ese camino no debe gastar paciencia"*).
##
## Se mide en el PLANO, como el camino a la ventanilla (FL5): distancia de la celda de entrada al
## centro de su sala de espera, dividida por la MISMA velocidad de paseo que usa Flujo — así el
## muñeco que ves cruzando la sala y el cronómetro lógico cuentan lo mismo. Sin Construcción, sin
## sala o con velocidad 0 → 0 minutos (empieza a esperar al entrar, el comportamiento de antes).
func minutos_hasta_su_sitio(persona: RefCounted) -> float:
	if _construccion == null or _flujo == null:
		return 0.0
	var velocidad: float = float(_flujo.velocidad_camino_celdas_min)
	if velocidad <= 0.0:
		return 0.0
	var salas: Array = _construccion.salas_de_espera_de(persona.servicio())
	if salas.is_empty():
		return 0.0
	var rect: Rect2i = _construccion.rect_de_sala(salas[0])
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var centro := Vector2(rect.position) + Vector2(rect.size) * 0.5 - Vector2(0.5, 0.5)
	return Vector2(CELDA_ENTRADA).distance_to(centro) / velocidad


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


## Congela el "recibo" de la espera (story 003): la primera vez que se ve a alguien LLAMADO o EN
## ATENCIÓN se apunta la paciencia que le quedaba. Ese es el dato que puntúa la visita — a partir de
## ahí su barra ya no baja, así que el valor no cambiaría, pero anotarlo explícitamente deja claro
## QUÉ se está midiendo (la espera) y sobrevive a que la barra se purgue al terminar.
func _anotar_llamadas() -> void:
	for persona: RefCounted in _paciencia_de:
		if _espera(persona) or _paciencia_al_llamar.has(persona):
			continue
		_paciencia_al_llamar[persona] = _paciencia_de[persona]


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
		anotar_visita(persona)   # story 004: su puntuación entra en la media del día ANTES de soltarla
		_paciencia_de.erase(persona)
		_paciencia_al_llamar.erase(persona)
		_camino_a_su_sitio.erase(persona)
		_usando_comodidad.erase(persona)
		_usos_comodidad.erase(persona)
		_consumidor_de.erase(persona)


# ── Alta y baja de personas ──────────────────────────────────────────────────────────────────

## PS1 — la persona coge turno: entra con la barra LLENA. Idempotente: registrar dos veces a la
## misma persona NO le regala paciencia (evita que un re-registro accidental borre su espera).
func registrar(persona: RefCounted) -> void:
	if persona == null or _paciencia_de.has(persona):
		return
	# Al cargar una partida, Flujo crea PersonaFlujo NUEVAS: la barra guardada se reengancha aquí, por
	# clave estable (servicio + turno). Si no hay nada guardado para ella, entra con la barra llena.
	var clave: String = _clave_de(persona)
	if _restaurables.has(clave):
		var guardado: Dictionary = _restaurables[clave]
		_paciencia_de[persona] = float(guardado["valor"])
		if float(guardado["al_llamar"]) >= 0.0:
			_paciencia_al_llamar[persona] = float(guardado["al_llamar"])
		if float(guardado.get("camino", 0.0)) > 0.0:
			_camino_a_su_sitio[persona] = float(guardado["camino"])
		# El que estaba en la máquina sigue en la máquina (story com-003). El ELEMENTO concreto se
		# vuelve a buscar por el catálogo: al cargar, Construcción ha creado ids nuevos.
		var consumidor: int = int(guardado.get("consumidor", -1))
		if consumidor >= 0:
			_consumidor_de[persona] = consumidor == 1
		var usos_previos: int = int(guardado.get("usos_comodidad", 0))
		if usos_previos > 0:
			_usos_comodidad[persona] = usos_previos
		var catalogo_uso: String = String(guardado.get("usando", ""))
		var restante_uso: float = float(guardado.get("usando_restante", 0.0))
		if catalogo_uso != "" and restante_uso > 0.0:
			_usando_comodidad[persona] = {
				"elemento": _elemento_usable_de_catalogo(persona.servicio(), StringName(catalogo_uso)),
				"catalogo": StringName(catalogo_uso),
				"restante": restante_uso,
			}
		_restaurables.erase(clave)
		return
	_paciencia_de[persona] = PACIENCIA_INICIAL
	var camino: float = minutos_hasta_su_sitio(persona)
	if camino > 0.0:
		_camino_a_su_sitio[persona] = camino


## Un elemento instalado de ese tipo de catálogo en las salas del servicio (`&""` si ya no existe —
## el jugador pudo demoler la máquina antes de guardar y el gesto se queda sin destino visible, que
## es inofensivo: el uso termina igual y la persona vuelve a su sitio).
func _elemento_usable_de_catalogo(servicio: StringName, catalogo: StringName) -> StringName:
	if _construccion == null:
		return &""
	for elemento_id: StringName in _construccion.usables_de_servicio(servicio):
		if _construccion.catalogo_de_elemento(elemento_id) == catalogo:
			return elemento_id
	return &""


## Clave ESTABLE de una persona entre guardado y carga: su servicio y su número de turno (los objetos
## no sobreviven; estos dos datos sí, y juntos son únicos — FL2 no repite turno dentro de un servicio).
func _clave_de(persona: RefCounted) -> String:
	return "%s#%d" % [persona.servicio(), persona.numero_turno]


## La persona sale del sistema (atendida o marchada): Paciencia la suelta.
func olvidar(persona: RefCounted) -> void:
	_paciencia_de.erase(persona)
	_paciencia_al_llamar.erase(persona)
	_camino_a_su_sitio.erase(persona)
	_usando_comodidad.erase(persona)
	_usos_comodidad.erase(persona)
	_consumidor_de.erase(persona)


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
func tasa_drenaje(mult_hac: float = 1.0, mult_com: float = -1.0) -> float:
	if tolerancia_base_min <= 0.0:
		return 0.0
	# `mult_com` negativo = "no me lo han dicho" → el knob del `.tres` (sin Construcción, neutro 1.0).
	var comodidad: float = mult_comodidad if mult_com < 0.0 else mult_com
	return (100.0 / tolerancia_base_min) * mult_hac * comodidad * mult_horapunta


## **Comodidades #15 (story com-002)** · El multiplicador de comodidad que le corresponde a un
## servicio según lo que el jugador tenga INSTALADO en sus salas de espera:
## `clamp(1 − k_confort × confort, mult_comodidad_min, 1.0)`.
##
## Reparto de propiedad: Construcción dice **cuánto confort hay** (suma de los objetos colocados);
## esta conversión es de Paciencia, porque F1 es SU fórmula (ADR-0001). Sin Construcción inyectada
## devuelve el knob de siempre → los tests y las partidas sin salas medibles no cambian.
func mult_comodidad_de(servicio: StringName) -> float:
	if _construccion == null or not _construccion.has_method("confort_de_servicio"):
		return mult_comodidad
	var confort: float = _construccion.confort_de_servicio(servicio)
	return clampf(1.0 - k_confort * confort, mult_comodidad_min, 1.0)


## Minutos que le quedan a una barra llena antes de llegar a 0 en estas condiciones (para tests, UI
## y la espera estimada). Tasa 0 → -1.0 centinela "no se agota" (NUNCA ∞ ni división por cero —
## misma convención que las fórmulas de Flujo).
func minutos_hasta_agotar(mult_hac: float = 1.0, mult_com: float = -1.0) -> float:
	var tasa: float = tasa_drenaje(mult_hac, mult_com)
	if tasa <= 0.0:
		return -1.0
	return PACIENCIA_INICIAL / tasa


## Aplica F1 a UNA persona durante `delta_min` minutos de juego y devuelve su paciencia resultante
## (0 = lista para marcharse; la 002 decidirá qué hacer con eso). No baja de 0: una barra vacía no
## se vuelve más vacía por seguir esperando.
func drenar(
	persona: RefCounted, delta_min: float, mult_hac: float = 1.0, mult_com: float = -1.0
) -> float:
	if not _paciencia_de.has(persona) or delta_min <= 0.0:
		return paciencia_de(persona)
	var restante: float = maxf(
		float(_paciencia_de[persona]) - tasa_drenaje(mult_hac, mult_com) * delta_min, 0.0
	)
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


# ── F2 · Puntuación de la visita (story 003) ─────────────────────────────────────────────────

## F2 — lo que puntúa una visita ATENDIDA [0, 100]: se parte de la puntuación base, se castiga por la
## paciencia que gastó esperando y se modula por el 🤝Trato del agente. El clamp final evita que un
## trato excelente dispare la escala por encima de 100.
## Ejemplos del GDD: sin espera y trato neutro → 80 · al límite con trato 0.7 → 28 · 80×1.3 → 100.
func puntuacion_atendida(paciencia_consumida: float, factor_trato: float = 1.0) -> float:
	var consumida: float = clampf(paciencia_consumida, 0.0, 100.0)
	var factor_espera: float = 1.0 - k_espera * (consumida / 100.0)
	return clampf(puntuacion_base * factor_espera * factor_trato, 0.0, 100.0)


## Paciencia que gastó esperando esta persona: 100 − la que le quedaba al ser llamada (o la que le
## queda ahora si aún espera). Una persona desconocida cuenta como espera total (caso conservador).
func paciencia_consumida_de(persona: RefCounted) -> float:
	if _paciencia_al_llamar.has(persona):
		return PACIENCIA_INICIAL - float(_paciencia_al_llamar[persona])
	var actual: float = paciencia_de(persona)
	if actual == SIN_PACIENCIA:
		return PACIENCIA_INICIAL
	return PACIENCIA_INICIAL - actual


## La puntuación con la que esta visita entra en la media del día (F2 aplicado al caso real):
## quien se marcha puntúa **0** (AC-PS08) — el abandono es el peor resultado posible, no un aprobado
## raspado. Quien es atendida puntúa según su espera y el trato del agente que la atendió.
func puntuacion_de_visita(persona: RefCounted) -> float:
	if persona.estado == PersonaFlujoScript.ESTADO_ABANDONANDO:
		return 0.0
	return puntuacion_atendida(paciencia_consumida_de(persona), _factor_trato_de(persona))


## El 🤝Trato del agente que la atiende (Personal F3). Sin Personal inyectado, sin puesto asignado o
## sin agente → 1.0 neutro: la puntuación no se infla ni se hunde por falta de datos.
func _factor_trato_de(persona: RefCounted) -> float:
	if _personal == null or _flujo == null:
		return 1.0
	var puesto_id: StringName = _flujo.puesto_de(persona)
	if puesto_id == &"":
		return 1.0
	return _personal.factor_trato_de(puesto_id)


# ── F3 · La satisfacción del servicio: media de la jornada + cierre (story 004) ──────────────

## Anota una visita TERMINADA en la media del día de su servicio. Ponderada: en ODAC una denuncia
## Prioritaria pesa `peso_prioridad_prioritaria` (2.5) — atender bien una urgencia vale más, y fallarla
## duele más. En Documentación todas pesan 1.0.
func anotar_visita(persona: RefCounted) -> void:
	var servicio: StringName = persona.servicio()
	var peso: float = peso_de_visita(persona)
	_suma_puntuaciones[servicio] = _suma_puntuaciones.get(servicio, 0.0) + puntuacion_de_visita(persona) * peso
	_peso_total[servicio] = _peso_total.get(servicio, 0.0) + peso
	_visitas_jornada[servicio] = _visitas_jornada.get(servicio, 0) + 1


## El peso de una visita en la media de su servicio: 1.0 salvo denuncia PRIORITARIA de ODAC.
## El tipo se resuelve por el catálogo (Datos); si no está, se asume Normal (nunca se infla el peso
## por un dato que falta).
func peso_de_visita(persona: RefCounted) -> float:
	if persona.servicio() != &"ODAC":
		return 1.0
	var denuncia: Resource = Datos.obtener(&"DenunciaODAC", persona.tramite_id())
	if denuncia == null or denuncia.prioridad != "Prioritaria":
		return 1.0
	return peso_prioridad_prioritaria


## La media VIVA de la jornada en curso (lo que el HUD enseña "construyéndose"). Sin visitas todavía
## → el cierre anterior: mientras no haya datos nuevos, lo que sabemos es lo de ayer.
func sat_actual_de(servicio: StringName) -> float:
	var peso: float = _peso_total.get(servicio, 0.0)
	if peso <= 0.0:
		return sat_cierre_de(servicio)
	return float(_suma_puntuaciones.get(servicio, 0.0)) / peso


## La satisfacción CERRADA de la jornada anterior — la que fija los ingresos de hoy (F4, Economía).
## Antes de la primera jornada cerrada, `sat_inicial` (50).
func sat_cierre_de(servicio: StringName) -> float:
	return _sat_cierre.get(servicio, sat_inicial)


## F5 — satisfacción GLOBAL: media de los servicios ponderada por su VOLUMEN de visitas del día. Solo
## para el HUD y la futura valoración de jefes; Economía NO la usa (cobra por servicio). Sin visitas
## en ningún servicio → media simple de los cierres (algo hay que enseñar, y es lo honesto).
func sat_global() -> float:
	var suma: float = 0.0
	var visitas: int = 0
	for servicio: StringName in SERVICIOS:
		var n: int = _visitas_jornada.get(servicio, 0)
		suma += sat_actual_de(servicio) * float(n)
		visitas += n
	if visitas <= 0:
		var total: float = 0.0
		for servicio: StringName in SERVICIOS:
			total += sat_cierre_de(servicio)
		return total / float(SERVICIOS.size())
	return suma / float(visitas)


## Cierre de la jornada (`nuevo_dia`, prioridad 10 — ANTES de que Economía cobre en la 20): la media
## viva se convierte en el `sat_cierre` que manda mañana, y los acumuladores se resetean.
## **Jornada sin visitas de un servicio → su cierre NO cambia** (AC-PS13): no se hereda un 0 por no
## haber trabajado, ni se divide por cero.
func cerrar_jornada() -> void:
	for servicio: StringName in SERVICIOS:
		if _peso_total.get(servicio, 0.0) > 0.0:
			_sat_cierre[servicio] = sat_actual_de(servicio)
	_suma_puntuaciones.clear()
	_peso_total.clear()
	_visitas_jornada.clear()
	# Las quejas del día se archivan con la jornada; las del MES siguen sumando hasta el `nuevo_mes`
	# (son dos KPI distintos: "cómo ha ido hoy" y "cómo va el mes por el que te evalúan").
	reclamaciones_jornada = 0
	reclamaciones_graves_jornada = 0
	# Story 005: la reputación se convierte en dinero. Economía cobrará TODA la jornada de mañana con
	# este número — por eso se le pasa AQUÍ, al cerrar, y no cada vez que alguien sale por la puerta:
	# si el retorno cambiara a media mañana, el jugador no podría planificar nada.
	if _economia != null and _economia.has_method("fijar_sat_cierre"):
		_economia.fijar_sat_cierre(sat_cierre_de(&"Documentacion"))


## Handler del evento ordenado `nuevo_dia`.
func _al_nuevo_dia() -> void:
	cerrar_jornada()


## Handler del evento ordenado `nuevo_mes`: el contador mensual se evalúa (lo leerá la valoración de
## jefes #28) y se resetea. El de la jornada lo resetea `cerrar_jornada`.
func _al_nuevo_mes() -> void:
	reclamaciones_mes = 0
	reclamaciones_graves_mes = 0


# ── Colarse: el favor que pagan los demás (mecánica del usuario, 2026-07-26) ─────────────────

## El jugador ha colado a `favorecida`: TODOS los demás que esperan ese servicio pierden
## `penalizacion_colado` puntos de paciencia. Devuelve a cuántos les ha sentado mal.
##
## Es el precio de hacer un favor: arreglas un caso concreto (alguien que llevaba mucho esperando) y
## empeoras la sala entera. Si el resto ya estaba al límite, colar puede provocar una espantada — y
## esa consecuencia es EXACTAMENTE lo que hace interesante la decisión.
##
## Los que van de camino a su sitio no se enteran (aún no están esperando) y a quien ya han llamado
## tampoco le afecta: su espera terminó.
func penalizar_por_colado(favorecida: RefCounted) -> int:
	if _flujo == null or favorecida == null or penalizacion_colado <= 0.0:
		return 0
	var afectados: int = 0
	for persona: RefCounted in _flujo.personas_de_cola(favorecida.servicio()):
		if persona == favorecida or not _espera(persona):
			continue
		if not _paciencia_de.has(persona) or _camino_a_su_sitio.has(persona):
			continue
		_paciencia_de[persona] = maxf(float(_paciencia_de[persona]) - penalizacion_colado, 0.0)
		afectados += 1
	return afectados


# ── PS13 · Reclamaciones: quien se va cabreado deja trabajo (story 006) ──────────────────────

## Procesa el abandono de una persona: cuenta la hoja y, con probabilidad `prob_reclamacion`, genera
## una RECLAMACIÓN que entra en ODAC como un trámite más — 30 minutos de ventanilla que no paga nadie.
##
## ⚠️ CORTE DE RECURSIÓN (AC-PS17): si quien abandona es YA una reclamación, cuenta pero **no engendra
## otra**. Sin esto, una comisaría saturada entraría en bola de nieve infinita: cada queja abandonada
## generaría otra queja, que a su vez... El corte se detecta por el propio trámite, sin banderas extra.
func procesar_abandono(persona: RefCounted) -> void:
	reclamaciones_jornada += 1
	reclamaciones_mes += 1
	if _es_grave(persona):
		reclamaciones_graves_jornada += 1
		reclamaciones_graves_mes += 1
	if persona.tramite_id() == TRAMITE_RECLAMACION:
		return
	if not _toca_reclamacion():
		return
	_generar_reclamacion()


## ¿Este abandono es GRAVE? Solo si era una denuncia PRIORITARIA de ODAC (VioGén, desaparecidos,
## agresión sexual, atraco): dejar tirada una urgencia no es lo mismo que perder un papeleo.
func _es_grave(persona: RefCounted) -> bool:
	if persona.servicio() != &"ODAC":
		return false
	var denuncia: Resource = Datos.obtener(&"DenunciaODAC", persona.tramite_id())
	return denuncia != null and denuncia.prioridad == "Prioritaria"


## La tirada de si el cabreo llega a hoja oficial. SIEMPRE por RNGService (determinismo, ADR-0002).
## Sin RNG inyectado no se generan reclamaciones (los tests puros no dependen del azar).
func _toca_reclamacion() -> bool:
	if prob_reclamacion <= 0.0 or _rng == null:
		return false
	if prob_reclamacion >= 1.0:
		return true
	return _rng.randf() < prob_reclamacion


## Fabrica la ficha de la reclamación y la suelta por el bus como una llegada más: quien la admite,
## encola y le da cuerpo visible es el mundo (Main), igual que con cualquier ciudadano — Paciencia no
## se salta la puerta de entrada de nadie.
func _generar_reclamacion() -> void:
	if _bus == null:
		return
	var minuto: int = int(_tiempo.minutos_juego) if _tiempo != null else 0
	_bus.persona_generada.emit(PersonaScript.new(&"ODAC", TRAMITE_RECLAMACION, minuto))


# ── Persistencia (story 007 · ADR-0002 — "cargar sitúa": ni señales ni efectos) ──────────────

## Estado serializable (contrato `Persist`; clave = node.name "Paciencia"). SOLO estado propio y no
## derivado: las barras (por clave estable, NUNCA por referencia de objeto), los acumuladores del día,
## los cierres y los contadores de quejas. El RNG **no** se duplica aquí: lo serializa RNGService.
func save() -> Dictionary:
	var barras: Array = []
	for persona: RefCounted in _paciencia_de:
		barras.append({
			"clave": _clave_de(persona),
			"valor": float(_paciencia_de[persona]),
			"al_llamar": float(_paciencia_al_llamar.get(persona, -1.0)),
			"camino": float(_camino_a_su_sitio.get(persona, 0.0)),
			# Quien estaba en el vending al guardar sigue allí al cargar (story com-003): se guarda
			# el id de CATÁLOGO, no el del elemento — al cargar, el objeto es otro id de Construcción.
			"usando": String(_usando_comodidad.get(persona, {}).get("catalogo", "")),
			"usando_restante": float(_usando_comodidad.get(persona, {}).get("restante", 0.0)),
			# Los viajes ya hechos: sin esto, cargar la partida le regalaría el tope entero otra vez.
			"usos_comodidad": int(_usos_comodidad.get(persona, 0)),
			# -1 = "aún no se ha decidido"; 0/1 = ya se sabe si es de los que consumen.
			"consumidor": -1 if not _consumidor_de.has(persona) else (1 if _consumidor_de[persona] else 0),
		})
	var acumulado: Dictionary = {}
	for servicio: StringName in SERVICIOS:
		acumulado[String(servicio)] = {
			"suma": _suma_puntuaciones.get(servicio, 0.0),
			"peso": _peso_total.get(servicio, 0.0),
			"visitas": _visitas_jornada.get(servicio, 0),
		}
	var cierres: Dictionary = {}
	for servicio: StringName in SERVICIOS:
		cierres[String(servicio)] = sat_cierre_de(servicio)
	return {
		"barras": barras,
		"acumulado": acumulado,
		"sat_cierre": cierres,
		"reclamaciones_jornada": reclamaciones_jornada,
		"reclamaciones_mes": reclamaciones_mes,
		"reclamaciones_graves_jornada": reclamaciones_graves_jornada,
		"reclamaciones_graves_mes": reclamaciones_graves_mes,
	}


## Carga el estado. Las barras quedan en el buffer de reenganche: sus dueñas todavía no existen (las
## reconstruye Flujo) y se recuperan en cuanto se las vuelve a ver, en `registrar`.
func load_state(d: Dictionary) -> void:
	_paciencia_de.clear()
	_paciencia_al_llamar.clear()
	_camino_a_su_sitio.clear()
	# Igual que las otras tres: si este `load_state` corre sobre el MISMO nodo (el SaveManager no
	# recrea a Paciencia), un uso de comodidad de la partida anterior no puede sobrevivir — sus
	# personas ya no existen. `registrar()` decide, por la clave estable, si hay que restaurar uno.
	_usando_comodidad.clear()
	_usos_comodidad.clear()
	_consumidor_de.clear()
	_restaurables.clear()
	for barra: Dictionary in d.get("barras", []):
		_restaurables[String(barra.get("clave", ""))] = {
			"valor": float(barra.get("valor", PACIENCIA_INICIAL)),
			"al_llamar": float(barra.get("al_llamar", -1.0)),
			"camino": float(barra.get("camino", 0.0)),
			# BUG corregido (story com-003): `save()` ya escribía "usando"/"usando_restante" en cada
			# barra, pero aquí no se copiaban al buffer de reenganche → `registrar()` los leía siempre
			# vacíos (`get("usando", "")` caía al default) y el gesto nunca sobrevivía al guardado.
			"usando": String(barra.get("usando", "")),
			"usando_restante": float(barra.get("usando_restante", 0.0)),
			"usos_comodidad": int(barra.get("usos_comodidad", 0)),
			"consumidor": int(barra.get("consumidor", -1)),
		}
	_suma_puntuaciones.clear()
	_peso_total.clear()
	_visitas_jornada.clear()
	var acumulado: Dictionary = d.get("acumulado", {})
	for servicio_txt: String in acumulado:
		var servicio: StringName = StringName(servicio_txt)
		var datos: Dictionary = acumulado[servicio_txt]
		_suma_puntuaciones[servicio] = float(datos.get("suma", 0.0))
		_peso_total[servicio] = float(datos.get("peso", 0.0))
		_visitas_jornada[servicio] = int(datos.get("visitas", 0))
	_sat_cierre.clear()
	var cierres: Dictionary = d.get("sat_cierre", {})
	for servicio_txt: String in cierres:
		_sat_cierre[StringName(servicio_txt)] = float(cierres[servicio_txt])
	reclamaciones_jornada = int(d.get("reclamaciones_jornada", 0))
	reclamaciones_mes = int(d.get("reclamaciones_mes", 0))
	reclamaciones_graves_jornada = int(d.get("reclamaciones_graves_jornada", 0))
	reclamaciones_graves_mes = int(d.get("reclamaciones_graves_mes", 0))


# ── Config (patrón del proyecto: fallback seguro + clamps con aviso) ─────────────────────────

## Aplica un `ConfigPaciencia` con clamps. Config nula o de otro tipo → defaults con aviso (no peta).
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigPacienciaScript):
		push_warning("Paciencia: config invalido -> defaults")
		config = ConfigPacienciaScript.new()
	tolerancia_base_min = clampf(config.tolerancia_base_min, 1.0, 600.0)
	k_hacinamiento = clampf(config.k_hacinamiento, 0.0, 10.0)
	mult_comodidad = clampf(config.mult_comodidad, 0.1, 2.0)
	k_confort = clampf(config.k_confort, 0.0, 1.0)
	mult_comodidad_min = clampf(config.mult_comodidad_min, 0.1, 1.0)
	prob_uso_comodidad_min = clampf(config.prob_uso_comodidad_min, 0.0, 1.0)
	umbral_uso_comodidad = clampf(config.umbral_uso_comodidad, 0.0, 100.0)
	max_usos_comodidad = clampi(config.max_usos_comodidad, 0, 10)
	prob_consumidor = clampf(config.prob_consumidor, 0.0, 1.0)
	mult_horapunta = clampf(config.mult_horapunta, 0.1, 3.0)
	umbral_animo_alto = clampf(config.umbral_animo_alto, 0.0, 100.0)
	umbral_animo_bajo = clampf(config.umbral_animo_bajo, 0.0, 100.0)
	puntuacion_base = clampf(config.puntuacion_base, 0.0, 100.0)
	k_espera = clampf(config.k_espera, 0.0, 1.0)
	sat_inicial = clampf(config.sat_inicial, 0.0, 100.0)
	peso_prioridad_prioritaria = clampf(config.peso_prioridad_prioritaria, 1.0, 10.0)
	prob_reclamacion = clampf(config.prob_reclamacion, 0.0, 1.0)
	penalizacion_colado = clampf(config.penalizacion_colado, 0.0, 100.0)
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
