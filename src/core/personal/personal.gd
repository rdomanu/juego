class_name Personal extends Node
## Personal — la plantilla de la comisaría (sistema Core; NODO del mundo, NO autoload — arq. §3.4).
##
## Story 001 del epic: la instancia `Agente` (agente.gd) + las FÓRMULAS con knobs (F1 salario efectivo ·
## F2 Rapidez→duración · F3 Trato→satisfacción · F4 Salud→ausencia) y la config data-driven
## (`ConfigPersonal`).
## Story 002: el MERCADO de fichajes (F5 — candidatos sembrados con sesgo al centro, vía RNGService),
## contratar con gate de caja de Economía (E4, sin coste puntual — Open Q4) y despedir (gratis, MVP).
## Story 003: la ASIGNACIÓN a puestos (PA5; puestos ABSTRACTOS registrados por el mundo — Construcción
## registrará los reales con la misma API), máx. 1 Oficial por servicio (PA2) y el GATE FL4 que
## consumirá Flujo (`puesto_dotado` + modificadores por puesto).
## Story 004: las AUSENCIAS del día (PA7/PA11, F4) — tirada diaria al `nuevo_dia` (prioridad 30 del
## dispatcher: la nómina de Economía, prio 20, se cobra ANTES → baja pagada), titularidad conservada
## y aviso por el bus (`incidencia_personal`).
## Story 005: el OFICIAL (PA8/PA9, F6/F7) — cobertura automática de bajas con agentes LIBRES (MVP
## ratificado: no mueve titulares de otros puestos), presupuesto diario `ceil(Mando/2)` por servicio
## (⚠️ errata del GDD anotada: el texto de F6 dice floor, pero su tabla de salida y AC-PE14 son ceil)
## y canalización: con Oficial PRESENTE las incidencias del servicio salen en UN parte agrupado
## (`parte_personal`); sin él, avisos individuales (`incidencia_personal`).
## Story 006: la NÓMINA EFECTIVA a Economía (F1 por agente vía `fijar_salarios_dia` — enmienda que
## ejecuta el hook previsto en eco-003; el COBRO sigue siendo de Economía, prio 20) y la
## PERSISTENCIA (`save()`/`load_state()` + grupo `Persist` — ADR-0002; el RNG lo serializa
## RNGService, los puestos los registra el mundo ANTES de cargar).
##
## Provee (cuando el epic avance) el gate FL4 y los modificadores que consumirá Flujo; el dinero lo
## posee Economía (esta clase solo CALCULA salarios — cobrarlos es de Economía, prio 20 del nuevo_dia).
##
## Story: production/epics/personal/story-001-agente-y-formulas.md · TR-staff-001 · ADR-0003/0002

## Ruta del config de tuning (generado por tools/build_config_personal.gd; fallback a defaults).
const RUTA_CONFIG := "res://datos/config/personal.tres"
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
## La instancia de agente (preload por RUTA — gotcha del headless en frío).
const AgenteScript := preload("res://src/core/personal/agente.gd")

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var k_calidad: float = 0.5
var prima_rango_oficial: float = 1.3
var k_rapidez: float = 0.1
var minutos_aguante: int = 180
var min_pausa_corta: int = 15
var min_pausa_normal: int = 30
var min_pausa_caradura: int = 60
var mult_cansancio_horas_extra: float = 1.5
## Lo que se alarga la pausa cuando NO hay sala de descanso construida: se van a la calle a tomar
## algo y tardan más en volver. 1.5 = media hora de café se convierte en tres cuartos. Así la sala no
## es obligatoria (la partida arranca sin ella y se puede jugar), pero construirla SE NOTA.
var mult_pausa_sin_sala: float = 1.5
var k_cansancio_rendimiento: float = 0.25
## Cuánto acorta la pausa cada punto de calidad instalada en la sala de descanso (bien-005).
var k_confort_pausa: float = 0.03
## Suelo del multiplicador de pausa: por muy montada que esté la sala, el café no baja de aquí.
var mult_pausa_min: float = 0.7
## Plazas que da la sala de descanso VACÍA (uno de pie). Las de verdad se compran.
var plazas_descanso_base: int = 1
## Cómo de generoso es el pago de la hora extra que ha elegido el jugador (0 = el mínimo del
## convenio · 1 = el techo autorizado). Lo empuja Documentación #8 al mover su slider de precio.
## Con 0, la hora extra cansa lo máximo; con 1, cansa como una hora normal: la gente va a gusto.
var _generosidad_peonada: float = 0.0
var k_motivacion_rapidez: float = 0.05
var k_trato: float = 0.25
var k_motivacion_trato: float = 0.1
var base_ausencia: float = 0.03
var k_salud: float = 0.02
var coste_despido: float = 0.0
var n_candidatos: int = 4
var refresco_mercado_jornadas: int = 3
var prob_candidato_oficial: float = 0.2
var pool_nombres: Array[String] = []

## La plantilla contratada (instancias Agente). La puebla el mercado (002) o el arranque del mundo (007).
var plantilla: Array[RefCounted] = []

# ── Mercado de fichajes (Story 002 · TR-staff-001 · GDD PA4/PA6, F5) ─────────────────────────
## Candidatos en oferta (instancias Agente SIN contratar). Se genera bajo demanda (`generar_mercado`)
## y se regenera completo por calendario; contratar solo retira al contratado (decisión de la story).
var mercado: Array[RefCounted] = []
## Jornadas transcurridas desde la última regeneración completa (F5).
var _jornadas_desde_refresco: int = 0
## Economía inyectada (gate E4 de contratación). En runtime la enchufa Main; los tests, una instancia real.
var _economia: Node = null
## EventBus inyectable (patrón Demanda; auto-resuelto en _ready): emite `incidencia_personal` y
## registra el hueco 30 del `nuevo_dia`. Sin bus (tests unitarios), las ausencias corren sin avisar.
var _bus: Node = null
## Construcción y reloj (Bienestar #13): la sala de descanso y el paso del tiempo de las pausas.
var _construccion: Node = null
var _tiempo: Node = null
var _suscrito_al_tick: bool = false
## Quién está de café y cuánto le queda: `agente -> minutos restantes`.
var _descansando: Dictionary = {}
## Buffer reutilizado entre ticks (regla del proyecto: cero allocs en el bucle de simulación).
var _vueltos_del_descanso: Array[RefCounted] = []
## Reusada cada tick (cero asignaciones en el bucle): a quienes el cierre de su ventanilla les pilla
## tomando café y se marchan a casa con el descanso a medias.
var _cerrados_del_descanso: Array[RefCounted] = []

## Tipos contratables del MVP (los 2 perfiles operativos del catálogo; `ag_seguridad` queda fuera del
## mercado — el vigilante llegará con su sistema).
const TIPOS_MERCADO: Array[StringName] = [&"ag_doc", &"ag_odac"]


func _ready() -> void:
	_cargar_config()
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	# Ausencias del día por el DISPATCHER (orden crítico ADR-0001, `nuevo_dia`: Paciencia 10 →
	# Economía 20 → **Personal 30** → Demanda 40). Solo en runtime real (árbol); los tests llaman
	# `_al_nuevo_dia` directo (patrón del proyecto).
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 30, _al_nuevo_dia)
	# Contrato de persistencia (ADR-0002): el SaveManager recoge por el grupo, clave = node.name.
	add_to_group("Persist")


## Inyecta Economía (dependency injection → testeable). Sin ella, contratar avisa y no aplica gate.
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta el EventBus (dependency injection → testeable sin el autoload real).
func usar_bus(bus: Node) -> void:
	_bus = bus


## Inyecta Construcción: solo para saber si hay **sala de descanso** construida (Bienestar #13). Sin
## ella, las pausas se alargan. Personal no construye nada: solo mira.
func usar_construccion(construccion: Node) -> void:
	_construccion = construccion


## Inyecta el reloj y se suscribe al tick: los descansos corren con el tiempo de juego (en Pausa,
## Tiempo no empuja → nadie vuelve del café, que es lo correcto).
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo
	if _tiempo != null and _tiempo.has_method("suscribir_tick") and not _suscrito_al_tick:
		_suscrito_al_tick = true
		_tiempo.suscribir_tick(_al_tick)


# ── F1 · Salario diario efectivo (base × prima de calidad × prima de rango) ──────────────────

## F1: `salario_base(tipo) × (1 + k_calidad × (media_atributos − 3)/2) × prima_rango`. El salario BASE
## vive en el catálogo (`TipoAgente.salario_dia_eur` — Datos); las primas son knobs. Mejor = más caro.
## Tipo inexistente en el catálogo → 0 con aviso (Datos ya avisa; el agente corrupto no cobra).
func salario_dia(agente: RefCounted) -> float:
	var tipo: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	if tipo == null:
		return 0.0
	var prima_calidad: float = 1.0 + k_calidad * (agente.media_atributos() - 3.0) / 2.0
	var prima_rango: float = prima_rango_oficial if agente.rango == AgenteScript.RANGO_OFICIAL else 1.0
	return float(tipo.salario_dia_eur) * prima_calidad * prima_rango


# ── F2 · Modificador de producción (Rapidez → duración efectiva; lo consumirá Flujo F1) ──────

## F2: `clamp((1 − k_rapidez×(R−3)) × (1 − k_mot_rap×(M−3)), 0.5, 1.3)`. Menor = más rápido. El rango
## extendido [0.5, 1.3] es la decisión 2026-07-21: un mal fichaje rinde PEOR que el estándar (>1.0).
func modificador_produccion(agente: RefCounted) -> float:
	var por_rapidez: float = 1.0 - k_rapidez * float(agente.rapidez - 3)
	var por_motivacion: float = 1.0 - k_motivacion_rapidez * float(agente.motivacion - 3)
	return clampf(por_rapidez * por_motivacion, 0.5, 1.3)


# ── F3 · Factor de trato (Trato → multiplicador de satisfacción; lo consumirá Paciencia F2) ──

## F3: `clamp(1 + k_trato×(T−3) × (1 + k_mot_trato×(M−3)), 0.5, 1.5)`. Trato 3 = 1.0 NEUTRO con
## cualquier Motivación (la modulación multiplica el desvío, no la base) — reconciliación 2026-07-22
## con Paciencia: esto es un MULTIPLICADOR de `puntuacion_visita`, no puntos aditivos.
func factor_trato(agente: RefCounted) -> float:
	var desvio: float = k_trato * float(agente.trato - 3)
	var por_motivacion: float = 1.0 + k_motivacion_trato * float(agente.motivacion - 3)
	return clampf(1.0 + desvio * por_motivacion, 0.5, 1.5)


# ── F4 · Probabilidad de ausencia diaria (Salud; la tirada real es de la story 004) ──────────

## ¿Hay sala de descanso construida? Sin ella la gente descansa igual —se va a la calle—, pero tarda
## más en volver. Sin Construcción inyectada se asume que sí (los tests miden otras cosas).
func hay_sala_descanso() -> bool:
	if _construccion == null or not _construccion.has_method("hay_sala_de_tipo"):
		return true
	return _construccion.hay_sala_de_tipo("descanso")


## Lo que dura el café según CÓMO esté la sala (bien-005). Tres tramos, de peor a mejor:
##   • **sin sala** → `mult_pausa_sin_sala` (1.5): se van a la calle y tardan más en volver.
##   • **sala pelada** → 1.0: hay sitio, pero no hay nada. El café dura lo reglamentario.
##   • **sala montada** → baja `k_confort_pausa` por punto instalado, con suelo `mult_pausa_min`.
## La conversión "calidad instalada → minutos" vive AQUÍ y no en Construcción: Construcción solo
## suma lo que hay puesto; qué hace ese número con el cansancio es de Personal, que es su dueño
## (ADR-0001). Es la misma frontera que ya separa el confort de Paciencia del rendimiento de Flujo.
func mult_pausa_por_sala() -> float:
	if not hay_sala_descanso():
		return mult_pausa_sin_sala
	var calidad: float = 0.0
	if _construccion != null and _construccion.has_method("descanso_instalado"):
		calidad = maxf(_construccion.descanso_instalado(), 0.0)
	return clampf(1.0 - k_confort_pausa * calidad, mult_pausa_min, 1.0)


## Cuánta gente cabe A LA VEZ tomándose el café: la plaza base de la sala más las que se han comprado
## (sofá 3, sillas 2). **Sin sala construida no hay tope**: la calle es infinita — el castigo de no
## tener sala ya es que la pausa dura un 50 % más, no hace falta cobrárselo dos veces.
func plazas_de_descanso() -> int:
	if not hay_sala_descanso():
		return 0   # 0 = "sin tope", lo interpreta `hay_sitio_para_descansar`
	var compradas: int = 0
	if _construccion != null and _construccion.has_method("plazas_de_descanso"):
		compradas = _construccion.plazas_de_descanso()
	return plazas_descanso_base + maxi(compradas, 0)


## ¿Queda sitio en la sala de descanso? Si no, el que necesita café **se queda en su ventanilla
## atendiendo** y lo reintentará luego: no pierde su descanso, lo retrasa. Es la decisión de juego que
## pidió el usuario — la sala no es solo cuestión de calidad, también de TAMAÑO.
func hay_sitio_para_descansar() -> bool:
	if not hay_sala_descanso():
		return true   # a la calle caben todos
	return _descansando.size() < plazas_de_descanso()


## Manda al agente a su pausa: deja de dotar su puesto (el gate FL4 ya exige ASIGNADO, así que Flujo
## deja de llamarle solo) y arranca su cronómetro. Sin sala de descanso la pausa se alarga; con la
## sala bien montada, se acorta. Si la sala está LLENA no se va: sigue atendiendo y lo reintenta.
## Devuelve los minutos que va a durar, o 0 si no procede (ya está fuera, no le toca, o no hay sitio).
func enviar_a_descansar(agente: RefCounted) -> float:
	if agente == null or agente.estado != AgenteScript.ESTADO_ASIGNADO:
		return 0.0
	# Con el turno ya terminado no se empieza un café: se va uno a casa. Sin esto, alguien podría
	# irse a la sala de descanso justo al cerrar su ventanilla y quedarse ahí de adorno.
	if turno_terminado(agente.puesto_id):
		return 0.0
	if not hay_sitio_para_descansar():
		return 0.0
	var minutos: float = float(minutos_de_pausa(agente)) * mult_pausa_por_sala()
	agente.estado = AgenteScript.ESTADO_DESCANSANDO
	agente.pausas_gastadas += 1
	_descansando[agente] = minutos
	if _bus != null:
		_bus.incidencia_personal.emit(
			"%s se va a descansar (%d min)" % [agente.nombre, roundi(minutos)]
		)
	return minutos


## Minutos que le quedan de café (0 si no está descansando) — lo LEE la UI.
func minutos_de_descanso_restantes(agente: RefCounted) -> float:
	return float(_descansando.get(agente, 0.0))


## ¿Está alguien de este puesto tomándose el café ahora mismo? Lo consulta el HUD para explicar por
## qué esa ventanilla no atiende (una ventanilla parada sin motivo visible parece un bug).
func agente_descansando_en(puesto_id: StringName) -> RefCounted:
	var agente: RefCounted = _asignaciones.get(puesto_id)
	if agente != null and agente.estado == AgenteScript.ESTADO_DESCANSANDO:
		return agente
	return null


## Cuánta gente está de café ahora mismo, y de qué ventanillas. Lo consume el HUD para explicar por
## qué no atiende nadie: el jugador tiene que poder distinguir "no he contratado a nadie" de "están
## todos en su descanso reglamentario", porque la solución es distinta en cada caso.
func puestos_en_descanso() -> Array[StringName]:
	var resultado: Array[StringName] = []
	for puesto_id: StringName in _asignaciones:
		if agente_descansando_en(puesto_id) != null:
			resultado.append(puesto_id)
	return resultado


## A qué minuto del día cierra cada ventanilla. Lo empuja Main por el mismo canal que ya se lo dice a
## Flujo (`_al_cambiar_horario_doc`): las ventanillas que no hacen la tarde cierran antes que las que
## sí. Sin entrada para un puesto, se asume que no cierra (ODAC y el resto de servicios de momento).
var _cierre_de_puesto: Dictionary[StringName, int] = {}


## Le dice a Personal a qué hora termina el turno de una ventanilla. Petición del usuario 2026-07-29:
## *"cuando termina el turno de los que no vuelven hasta el día siguiente como documentación se tienen
## que marchar aunque estén descansando"*.
func fijar_cierre_de_puesto(puesto_id: StringName, minuto_del_dia: int) -> void:
	_cierre_de_puesto[puesto_id] = clampi(minuto_del_dia, 0, 1439)


## ¿Ha terminado ya el turno de este puesto? Sin reloj o sin horario conocido, no cierra nunca.
func turno_terminado(puesto_id: StringName) -> bool:
	if _tiempo == null or not _cierre_de_puesto.has(puesto_id):
		return false
	return fposmod(_tiempo.minutos_juego, 1440.0) >= float(_cierre_de_puesto[puesto_id])


## El tick: descuenta el café y devuelve a su puesto a quien ya ha terminado, con la barra a cero.
## En Pausa no corre (Tiempo no empuja el tick), que es justo lo que se espera.
##
## Y **manda a casa a quien le pille el cierre de su ventanilla tomando café**: el turno de
## Documentación no continúa hasta el día siguiente, así que quedarse en la sala de descanso pasada
## esa hora no tiene sentido — se marcha con el café a medias, como cualquiera. Su barra NO se pone a
## cero (no llegó a terminar el descanso); da igual, porque el reinicio diario la limpia de todos modos.
func _al_tick(delta_juego_min: float) -> void:
	if _descansando.is_empty() or delta_juego_min <= 0.0:
		return
	_vueltos_del_descanso.clear()
	_cerrados_del_descanso.clear()
	for agente: RefCounted in _descansando:
		if turno_terminado(agente.puesto_id):
			_cerrados_del_descanso.append(agente)
			continue
		var restante: float = float(_descansando[agente]) - delta_juego_min
		if restante > 0.0:
			_descansando[agente] = restante
			continue
		_vueltos_del_descanso.append(agente)
	# Los que se van a casa: salen de la sala de descanso (dejan de pintarse con su taza) y quedan
	# como el resto de su turno — con el puesto cerrado, Flujo no les manda a nadie y el mostrador se
	# queda vacío igual. No se les avisa por el bus: irse a la hora no es una incidencia.
	for agente: RefCounted in _cerrados_del_descanso:
		_descansando.erase(agente)
		if agente.puesto_id != &"" and _asignaciones.get(agente.puesto_id) == agente:
			agente.estado = AgenteScript.ESTADO_ASIGNADO
		else:
			agente.estado = AgenteScript.ESTADO_LIBRE
	for agente: RefCounted in _vueltos_del_descanso:
		_descansando.erase(agente)
		agente.cansancio = 0.0
		# Vuelve a su puesto SOLO si sigue teniéndolo: pudieron despedirle o reasignarle mientras
		# estaba fuera, y en ese caso no se le devuelve un puesto que ya no es suyo.
		if agente.puesto_id != &"" and _asignaciones.get(agente.puesto_id) == agente:
			agente.estado = AgenteScript.ESTADO_ASIGNADO
		else:
			agente.estado = AgenteScript.ESTADO_LIBRE


## F4: `clamp(base_ausencia − k_salud×(S−3), 0, 1)`. Salud 5 → 0 (clamp) · Salud 3 → 3 % · Salud 1 → 7 %.
func prob_ausencia(agente: RefCounted) -> float:
	return clampf(base_ausencia - k_salud * float(agente.salud - 3), 0.0, 1.0)


# ── Cansancio y descansos (Bienestar #13 · story bien-001) ───────────────────────────────────

## Patrones de descanso. NO son un dado: salen de la **motivación** del agente, que hasta hoy solo
## movía unas fórmulas invisibles y ahora se ve en pantalla. Y cierra un bucle con Documentación #8:
## hacer salir tarde a la gente le baja la motivación… y eso convierte a un cumplidor en un caradura.
const PATRON_DOS_CAFES := &"dos_cafes"     # motivación 5 — parte su media hora en dos
const PATRON_UN_CAFE := &"un_cafe"         # motivación 3-4 — la media hora reglamentaria de un tirón
const PATRON_CARADURA := &"caradura"       # motivación 1-2 — se toma el doble, y lo sabe

## El patrón de descanso de este agente, derivado de su motivación (determinista: el mismo agente se
## comporta igual siempre, y el jugador puede aprender a leerlo).
func patron_de(agente: RefCounted) -> StringName:
	if agente == null:
		return PATRON_UN_CAFE
	if agente.motivacion >= 5:
		return PATRON_DOS_CAFES
	if agente.motivacion <= 2:
		return PATRON_CARADURA
	return PATRON_UN_CAFE


## Cuántas pausas se toma en una jornada (el de "15 y 15" hace dos; el resto, una).
func pausas_de(agente: RefCounted) -> int:
	return 2 if patron_de(agente) == PATRON_DOS_CAFES else 1


## Cuánto dura CADA pausa suya, en minutos de juego.
func minutos_de_pausa(agente: RefCounted) -> int:
	match patron_de(agente):
		PATRON_DOS_CAFES:
			return min_pausa_corta
		PATRON_CARADURA:
			return min_pausa_caradura
		_:
			return min_pausa_normal


## Minutos de ATENCIÓN que aguanta antes de agotar la barra. El presupuesto se reparte entre sus
## pausas: quien hace dos se agota a la mitad de camino, y así los tres patrones gastan lo suyo en
## una jornada normal.
func aguante_efectivo(agente: RefCounted) -> float:
	return float(minutos_aguante) / float(maxi(pausas_de(agente), 1))


## Recibe de Documentación #8 lo generoso que es el pago de la hora extra (0-1). Petición del usuario
## 2026-07-28: *"por defecto cansa 1,5 pero si se paga más esa penalización va bajando"*.
func fijar_generosidad_peonada(generosidad: float) -> void:
	_generosidad_peonada = clampf(generosidad, 0.0, 1.0)


## Lo que cansa una hora extra AHORA MISMO, según lo que se esté pagando: del recargo completo
## (`mult_cansancio_horas_extra`, pago mínimo) a 1.0 (pago máximo, cansa como una hora normal).
## La conversión pago→cansancio es de Personal porque el cansancio es SUYO (ADR-0001); Documentación
## solo dice cómo de bien paga.
func mult_cansancio_efectivo() -> float:
	return lerpf(mult_cansancio_horas_extra, 1.0, _generosidad_peonada)


## Suma cansancio por `minutos` ATENDIENDO (parado no cansa). `en_horas_extra` aplica el recargo de
## la peonada: alargar la tarde no solo cuesta dinero, también quema. Devuelve la barra resultante.
func cansar(agente: RefCounted, minutos: float, en_horas_extra: bool = false) -> float:
	if agente == null:
		return 0.0
	if minutos <= 0.0:
		return agente.cansancio
	var recargo: float = mult_cansancio_efectivo() if en_horas_extra else 1.0
	agente.cansancio += (100.0 / aguante_efectivo(agente)) * minutos * recargo
	return agente.cansancio


## ¿Le toca levantarse? Barra llena **y** le quedan pausas por gastar: agotado su cupo aguanta hasta
## el cierre, que es lo que hace un funcionario de verdad (el caradura ya se pasó antes).
func necesita_descanso(agente: RefCounted) -> bool:
	if agente == null:
		return false
	return agente.cansancio >= 100.0 and agente.pausas_gastadas < pausas_de(agente)


# ── F5 · Mercado de fichajes (Story 002 — todo el azar vía RNGService, orden de llamadas FIJO) ─

## Regenera el mercado COMPLETO: `n_candidatos` candidatos sembrados (F5). Determinista: misma semilla
## → mismos candidatos (AC-PE06). Resetea el contador de refresco.
func generar_mercado() -> void:
	mercado.clear()
	for i: int in range(n_candidatos):
		mercado.append(_generar_candidato())
	_jornadas_desde_refresco = 0


## Un candidato F5: atributos con DISTRIBUCIÓN SESGADA AL CENTRO (media redondeada de 2 tiradas 1-5 →
## triangular: medias comunes, cracks y paquetes raros — el `sesgo_candidatos` del GDD). El rango es
## Oficial con `prob_candidato_oficial` (decisión propuesta de la story: de aquí salen los Oficiales).
## Orden de tiradas FIJO (nombre → tipo → rango → 4 atributos → mando) = contrato determinista.
func _generar_candidato() -> RefCounted:
	var nombre: String = pool_nombres[RNGService.randi_rango(0, pool_nombres.size() - 1)]
	var tipo_id: StringName = TIPOS_MERCADO[RNGService.randi_rango(0, TIPOS_MERCADO.size() - 1)]
	var rango: StringName = AgenteScript.RANGO_POLICIA
	if RNGService.randf() < prob_candidato_oficial:
		rango = AgenteScript.RANGO_OFICIAL
	var rapidez: int = _tirada_sesgada()
	var trato: int = _tirada_sesgada()
	var salud: int = _tirada_sesgada()
	var motivacion: int = _tirada_sesgada()
	var mando: int = _tirada_sesgada() if rango == AgenteScript.RANGO_OFICIAL else 0
	return AgenteScript.new(nombre, tipo_id, rango, rapidez, trato, salud, motivacion, mando)


## Tirada 1-5 sesgada al centro: media redondeada de 2 tiradas uniformes (triangular — el 3 es lo más
## común, el 1 y el 5 escasean).
func _tirada_sesgada() -> int:
	var suma: int = RNGService.randi_rango(1, 5) + RNGService.randi_rango(1, 5)
	return roundi(float(suma) / 2.0)


## Contrata al candidato `indice` del mercado (PA4). Gate E4 de Economía: exige poder pagar su
## `salario_dia` — SOLO comprueba, no cobra (sin coste puntual en el MVP — Open Q4; la nómina diaria
## la cobra Economía). El contratado sale del mercado y entra a plantilla como libre.
func contratar(indice: int) -> bool:
	if indice < 0 or indice >= mercado.size():
		push_warning("Personal: contratar indice %d fuera del mercado (%d candidatos)" % [indice, mercado.size()])
		return false
	var candidato: RefCounted = mercado[indice]
	if _economia != null and not _economia.puede_pagar(salario_dia(candidato)):
		return false
	if _economia == null:
		push_warning("Personal: contratando SIN gate de Economia (no inyectada)")
	mercado.remove_at(indice)
	candidato.estado = AgenteScript.ESTADO_LIBRE
	plantilla.append(candidato)
	_actualizar_nomina()
	return true


## API de ARRANQUE del mundo (Main hoy; escenarios futuros): incorpora un agente YA construido a la
## plantilla (entra libre, SIN gate de caja — la dotación inicial viene dada, story 007) y re-fija
## la nómina. El flujo normal de juego es `contratar()` (mercado + gate E4).
func incorporar(agente: RefCounted) -> void:
	agente.estado = AgenteScript.ESTADO_LIBRE
	plantilla.append(agente)
	_actualizar_nomina()


## Despide a un agente (PA6): sale de la plantilla, LIBERA su puesto y deja de contar en nómina.
## Coste 0 (MVP). (El compromiso "termina su atención en curso" es contrato de Flujo al integrar.)
func despedir(agente: RefCounted) -> void:
	var indice: int = plantilla.find(agente)
	if indice < 0:
		push_warning("Personal: despedir a alguien que no esta en plantilla -> ignorado")
		return
	desasignar(agente)
	plantilla.remove_at(indice)
	_actualizar_nomina()


## Handler del `nuevo_dia` (prioridad 30 del dispatcher — registrado en `_ready`; los tests lo llaman
## directo). Orden interno FIJO — contrato determinista del RNG (cambiarlo rompería la reproducibilidad
## de partidas guardadas): (1) deshacer las coberturas de ayer ANTES de reincorporar (story 005),
## (2) reincorporar a los ausentes de ayer, (3) tirada F4 de ausencia por agente, (4) cobertura del
## Oficial F6, (5) avisos F7 (parte agrupado o individuales), (6) ciclo de refresco del mercado (F5).
## Solo el paso (3) —y el (6) los días de refresco— consume tiradas del RNG.
func _al_nuevo_dia() -> void:
	_reiniciar_cansancio()
	_deshacer_coberturas()
	_reincorporar_ausentes()
	var incidencias: Dictionary = _evaluar_ausencias()
	var cobertura: Dictionary = _cubrir_vacantes()
	_emitir_avisos(incidencias, cobertura)
	_jornadas_desde_refresco += 1
	if _jornadas_desde_refresco >= refresco_mercado_jornadas:
		generar_mercado()


## Jornada nueva, gente descansada (Bienestar #13): la barra vuelve a 0 y el cupo de cafés se
## renueva. A quien pillara el cambio de día en la sala de descanso se le devuelve su puesto: la
## pausa no se arrastra de una jornada a otra.
func _reiniciar_cansancio() -> void:
	_descansando.clear()
	for agente: RefCounted in plantilla:
		agente.cansancio = 0.0
		agente.pausas_gastadas = 0
		if agente.estado == AgenteScript.ESTADO_DESCANSANDO:
			agente.estado = (
				AgenteScript.ESTADO_ASIGNADO if agente.puesto_id != &""
				else AgenteScript.ESTADO_LIBRE
			)


# ── Ausencias del día (Story 004 · TR-staff-003 · GDD PA7/PA11, F4) ──────────────────────────

## Reincorpora a los ausentes de AYER (PA7): el titular vuelve a su puesto (su plaza se le conservó);
## un ausente sin puesto vuelve al banquillo.
func _reincorporar_ausentes() -> void:
	for agente: RefCounted in plantilla:
		if agente.estado == AgenteScript.ESTADO_AUSENTE:
			if agente.puesto_id != &"":
				agente.estado = AgenteScript.ESTADO_ASIGNADO
			else:
				agente.estado = AgenteScript.ESTADO_LIBRE


## La tirada diaria de ausencia (PA11): recorre la plantilla en ORDEN ESTABLE y por agente tira
## `RNGService.randf() < prob_ausencia` (F4) — orden fijo + RNG sembrado = determinista (AC-PE13).
## El ausente CONSERVA la titularidad (no se desasigna) pero su puesto deja de estar dotado
## (`puesto_dotado` → false: pérdida de capacidad real para Flujo — AC-PE15). Devuelve las
## incidencias del día agrupadas por servicio (&"" = baja de un agente del banquillo):
## `servicio -> Array de {agente, puesto}` — los avisos los emite `_emitir_avisos` (F7, story 005).
func _evaluar_ausencias() -> Dictionary:
	var incidencias: Dictionary = {}
	for agente: RefCounted in plantilla:
		if RNGService.randf() < prob_ausencia(agente):
			agente.estado = AgenteScript.ESTADO_AUSENTE
			var servicio: String = "" if agente.puesto_id == &"" else servicio_de_puesto(agente.puesto_id)
			if not incidencias.has(servicio):
				incidencias[servicio] = []
			incidencias[servicio].append({"agente": agente, "puesto": agente.puesto_id})
	return incidencias


# ── El Oficial: cobertura y canalización (Story 005 · TR-staff-003 · GDD PA8/PA9, F6/F7) ─────

## Deshace las coberturas de ayer: cada cubridor vuelve al banquillo. Corre ANTES de reincorporar
## (el titular que vuelve se encuentra su puesto libre de prestados). Si el titular sigue de baja,
## la pasada de cobertura de HOY volverá a cubrirlo (con presupuesto fresco del Oficial).
func _deshacer_coberturas() -> void:
	for puesto_id: StringName in _coberturas:
		_coberturas[puesto_id].estado = AgenteScript.ESTADO_LIBRE
	_coberturas.clear()


## La cobertura del Oficial (F6): por cada puesto con TITULAR DE BAJA (en orden estable de registro),
## si el servicio tiene Oficial asignado Y presente (no de baja él mismo — edge del GDD), gasta su
## presupuesto diario `ceil(Mando/2)` reasignando al primer agente LIBRE compatible
## (`puestos_operables`; MVP ratificado: solo libres, no mueve titulares). Sin candidato o sin
## presupuesto → la baja se ESCALA al jugador (F7). Un puesto sin titular no se cubre (dotarlo es
## tarea del jugador, no una baja). Devuelve `servicio -> {cubiertas, escaladas}`. Sin azar: la
## cobertura es determinista por reglas (manifest).
func _cubrir_vacantes() -> Dictionary:
	var resumen: Dictionary = {}
	var presupuesto: Dictionary = {}
	for puesto_id: StringName in _puestos:
		var titular: RefCounted = _asignaciones.get(puesto_id)
		if titular == null or titular.estado != AgenteScript.ESTADO_AUSENTE:
			continue
		var servicio: String = servicio_de_puesto(puesto_id)
		var oficial: RefCounted = _oficial_de_servicio(servicio)
		if oficial == null or oficial.estado != AgenteScript.ESTADO_ASIGNADO:
			continue   # sin mando presente no hay cobertura NI parte: avisos individuales (F7)
		if not presupuesto.has(servicio):
			# F6 por la TABLA del GDD (Mando 1-2 → 1 · 3-4 → 2 · 5 → 3) = ceil, no el floor del texto.
			presupuesto[servicio] = ceili(float(oficial.mando) / 2.0)
		if not resumen.has(servicio):
			resumen[servicio] = {"cubiertas": 0, "escaladas": 0}
		var candidato: RefCounted = _libre_compatible(_puestos[puesto_id])
		if int(presupuesto[servicio]) <= 0 or candidato == null:
			resumen[servicio]["escaladas"] = int(resumen[servicio]["escaladas"]) + 1
			continue
		presupuesto[servicio] = int(presupuesto[servicio]) - 1
		_coberturas[puesto_id] = candidato
		candidato.estado = AgenteScript.ESTADO_CUBRIENDO
		resumen[servicio]["cubiertas"] = int(resumen[servicio]["cubiertas"]) + 1
	return resumen


## El primer agente LIBRE de la plantilla (orden estable) que puede operar ese tipo de puesto.
func _libre_compatible(tipo_puesto_id: StringName) -> RefCounted:
	for agente: RefCounted in plantilla:
		if agente.estado != AgenteScript.ESTADO_LIBRE:
			continue
		var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
		if tipo_agente != null and tipo_puesto_id in tipo_agente.puestos_operables:
			return agente
	return null


## La canalización (F7, PA9): por servicio con incidencias, CON Oficial presente → UN parte agrupado
## (`parte_personal`; las cubiertas cuentan como autoresueltas, `escaladas` > 0 = requiere decisión);
## SIN Oficial (o bajas del banquillo, servicio &"") → un aviso individual por baja
## (`incidencia_personal`). Orden de emisión determinista (orden de detección de las bajas).
func _emitir_avisos(incidencias: Dictionary, cobertura: Dictionary) -> void:
	if _bus == null:
		return
	for servicio: String in incidencias:
		var lista: Array = incidencias[servicio]
		var oficial: RefCounted = null
		if servicio != "":
			oficial = _oficial_de_servicio(servicio)
		if oficial != null and oficial.estado == AgenteScript.ESTADO_ASIGNADO:
			var datos_cobertura: Dictionary = cobertura.get(servicio, {"cubiertas": 0, "escaladas": 0})
			_bus.parte_personal.emit({
				"servicio": servicio,
				"ausencias": lista.size(),
				"cubiertas": int(datos_cobertura["cubiertas"]),
				"escaladas": int(datos_cobertura["escaladas"]),
			})
		else:
			for incidencia: Dictionary in lista:
				_bus.incidencia_personal.emit(
					"%s no ha venido hoy (baja)" % incidencia["agente"].nombre, incidencia["puesto"]
				)


## Si el agente estaba cubriendo un puesto, la cobertura se anula (el puesto vuelve a quedar sin
## dotar). NO toca el estado del agente — eso lo decide quien llama (asignar/desasignar).
func _liberar_cobertura_de(agente: RefCounted) -> void:
	var puesto_cubierto: Variant = _coberturas.find_key(agente)
	if puesto_cubierto != null:
		_coberturas.erase(puesto_cubierto)


# ── Asignación a puestos y gate FL4 (Story 003 · TR-staff-002 · GDD PA2/PA5) ─────────────────

## Puestos que existen en el mundo: `puesto_id -> tipo_puesto_id` (catálogo). Hoy los registra Main
## (dotación estándar del esqueleto); cuando exista Construcción, registrará los puestos REALES con
## esta misma API y nada se tira.
var _puestos: Dictionary[StringName, StringName] = {}
## Asignaciones vigentes: `puesto_id -> Agente` (`plazas_agente = 1`). SIEMPRE el TITULAR (un
## ausente conserva su entrada — story 004); los cubridores van aparte en `_coberturas`.
var _asignaciones: Dictionary[StringName, RefCounted] = {}
## Coberturas vigentes HOY (story 005): `puesto_id -> cubridor` (estado &"cubriendo"; su `puesto_id`
## propio queda &"" — cubre de prestado, sin titularidad). Se deshacen al empezar cada `nuevo_dia`.
var _coberturas: Dictionary[StringName, RefCounted] = {}


## Registra un puesto del mundo. El tipo debe existir en el catálogo (integridad — patrón Datos).
func registrar_puesto(puesto_id: StringName, tipo_puesto_id: StringName) -> void:
	if Datos.obtener(&"TipoPuesto", tipo_puesto_id) == null:
		push_warning("Personal: tipo de puesto '%s' no existe en el catalogo -> no registrado" % tipo_puesto_id)
		return
	_puestos[puesto_id] = tipo_puesto_id


## Retira un puesto del mundo (demolición futura): su agente, si lo había, queda libre; una
## cobertura activa se anula (el cubridor vuelve al banquillo — story 005).
func quitar_puesto(puesto_id: StringName) -> void:
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		cubridor.estado = AgenteScript.ESTADO_LIBRE
		_coberturas.erase(puesto_id)
	var agente: RefCounted = _asignaciones.get(puesto_id)
	if agente != null:
		desasignar(agente)
	_puestos.erase(puesto_id)


## Asigna un agente a un puesto (PA5). Reglas de juego (false SILENCIOSO — son rechazos normales que
## la UI mostrará deshabilitados, no errores): puesto ocupado, tipo no operable (`puestos_operables`
## de Datos) o 2.º Oficial en el servicio (PA2). Un dato inexistente sí avisa. Si el agente estaba en
## otro puesto, se MUEVE (libera el anterior — atómico; el "no cortar la atención en curso" es
## contrato de Flujo al consumir el cambio).
func asignar(agente: RefCounted, puesto_id: StringName) -> bool:
	if not _puestos.has(puesto_id):
		push_warning("Personal: asignar a puesto no registrado '%s'" % puesto_id)
		return false
	if agente.estado == AgenteScript.ESTADO_AUSENTE:
		return false   # hoy está de baja (story 004): no se incorpora hasta el nuevo_dia siguiente
	var ocupante: RefCounted = _asignaciones.get(puesto_id)
	if ocupante == agente:
		return true   # ya estaba — idempotente
	if ocupante != null:
		return false   # plazas_agente = 1
	var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	if tipo_agente == null:
		return false   # Datos ya avisó
	var tipo_puesto_id: StringName = _puestos[puesto_id]
	if not (tipo_puesto_id in tipo_agente.puestos_operables):
		return false   # un ag_doc no opera un puesto_odac (Datos manda)
	if agente.rango == AgenteScript.RANGO_OFICIAL:
		var servicio: String = servicio_de_puesto(puesto_id)
		var oficial_actual: RefCounted = _oficial_de_servicio(servicio)
		if oficial_actual != null and oficial_actual != agente:
			return false   # máx. 1 Oficial por servicio (PA2)
	if agente.puesto_id != &"":
		_asignaciones.erase(agente.puesto_id)
	# (story 005) si el propio agente estaba cubriendo en otro sitio, deja de hacerlo; y si el puesto
	# destino lo tapaba un cubridor (su titular se fue), el cubridor vuelve al banquillo: llega titular.
	_liberar_cobertura_de(agente)
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		cubridor.estado = AgenteScript.ESTADO_LIBRE
		_coberturas.erase(puesto_id)
	_asignaciones[puesto_id] = agente
	agente.puesto_id = puesto_id
	agente.estado = AgenteScript.ESTADO_ASIGNADO
	return true


## Quita a un agente de su puesto (vuelve al banquillo). Sin puesto → no-op. Un AUSENTE pierde la
## titularidad pero sigue de baja hoy (story 004: la baja es del día, no se "cura" desasignando).
## A un CUBRIENDO se le anula la cobertura (story 005) y queda libre.
func desasignar(agente: RefCounted) -> void:
	_liberar_cobertura_de(agente)
	if agente.puesto_id != &"":
		_asignaciones.erase(agente.puesto_id)
	agente.puesto_id = &""
	if agente.estado != AgenteScript.ESTADO_AUSENTE:
		agente.estado = AgenteScript.ESTADO_LIBRE


## Servicio de un puesto registrado ("Documentacion"/"ODAC"/"Seguridad") — lo posee el catálogo.
func servicio_de_puesto(puesto_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoPuesto", _puestos.get(puesto_id, &""))
	if tipo == null:
		return ""
	return tipo.servicio


## El Oficial ASIGNADO en un servicio (null si no hay) — regla PA2 y, en la story 005, quién cubre.
func _oficial_de_servicio(servicio: String) -> RefCounted:
	for agente: RefCounted in _asignaciones.values():
		if agente.rango == AgenteScript.RANGO_OFICIAL and servicio_de_puesto(agente.puesto_id) == servicio:
			return agente
	return null


# ── Gate FL4 y modificadores por puesto (la API que consumirá Flujo) ─────────────────────────

## ¿El puesto está DOTADO? (gate FL4): hay un cubridor (story 005) o el titular está al pie. El
## AUSENTE no dota (story 004). Un puesto sin dotar está cerrado: Flujo no atiende en él.
func puesto_dotado(puesto_id: StringName) -> bool:
	if _coberturas.has(puesto_id):
		return true
	var agente: RefCounted = _asignaciones.get(puesto_id)
	return agente != null and agente.estado == AgenteScript.ESTADO_ASIGNADO


## Los puestos de un servicio, en **orden de registro** (estable — el mismo que usa Flujo para
## desempatar quién llama primero). Lo consume Documentación #8 para su horario por ventanilla
## (story doc-006) y la UI para listarlas. Incluye los NO dotados: existir y estar cubierto son
## cosas distintas, y la pantalla debe poder enseñar una ventanilla vacante.
func puestos_de_servicio(servicio: StringName) -> Array[StringName]:
	var lista: Array[StringName] = []
	for puesto_id: StringName in _puestos:
		var tipo: Resource = Datos.obtener(&"TipoPuesto", _puestos[puesto_id])
		if tipo != null and tipo.servicio == String(servicio):
			lista.append(puesto_id)
	return lista


## El tipo de puesto (id del catálogo) con el que se registró, o `&""` si el puesto no existe.
func tipo_de_puesto(puesto_id: StringName) -> StringName:
	return _puestos.get(puesto_id, &"")


## Cuántos puestos DOTADOS hay de un servicio (el tipo de puesto lo dice el catálogo). Lo consume
## Documentación #8 para la peonada (F1: la pagan los agentes que cubren las horas extra) — un puesto
## sin dotar no cuenta: nadie cobra por no venir. Story doc-003.
func agentes_dotados_en_servicio(servicio: StringName) -> int:
	var total: int = 0
	for puesto_id: StringName in _puestos:
		if not puesto_dotado(puesto_id):
			continue
		var tipo: Resource = Datos.obtener(&"TipoPuesto", _puestos[puesto_id])
		if tipo != null and tipo.servicio == String(servicio):
			total += 1
	return total


## El agente que responde HOY por el puesto: el cubridor si hay cobertura (story 005); si no, el
## titular (aunque esté ausente — la titularidad se consulta aquí o por `agente.puesto_id`).
func agente_de(puesto_id: StringName) -> RefCounted:
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		return cubridor
	return _asignaciones.get(puesto_id)


## F2 del agente OPERATIVO del puesto (lo consumirá Flujo F1; con cobertura rinde el cubridor).
## Sin agente → 1.0 neutro con aviso.
func modificador_produccion_de(puesto_id: StringName) -> float:
	var agente: RefCounted = agente_de(puesto_id)
	if agente == null:
		push_warning("Personal: modificador de un puesto sin agente ('%s') -> 1.0" % puesto_id)
		return 1.0
	# El cansancio se aplica FUERA del clamp de F2 a propósito: F2 mide lo bueno que es el agente
	# (y ahí un tope tiene sentido); el cansancio es una condición pasajera que se suma encima.
	return modificador_produccion(agente) * mult_cansancio_rendimiento(agente)


## Cuánto ralentiza a este agente lo cansado que está (Bienestar #13): `1 + k × cansancio/100`.
## Con la barra a tope, un 25 % más lento. Progresivo: el bajón se nota en la cola ANTES de que le
## toque el café, que es lo que hace que el jugador vea venir el problema.
func mult_cansancio_rendimiento(agente: RefCounted) -> float:
	if agente == null:
		return 1.0
	return 1.0 + k_cansancio_rendimiento * (agente.cansancio / 100.0)


## F3 del agente OPERATIVO del puesto (lo consumirá Flujo al cerrar → Paciencia). Sin agente → 1.0
## con aviso.
func factor_trato_de(puesto_id: StringName) -> float:
	var agente: RefCounted = agente_de(puesto_id)
	if agente == null:
		push_warning("Personal: factor de trato de un puesto sin agente ('%s') -> 1.0" % puesto_id)
		return 1.0
	return factor_trato(agente)


# ── Nómina efectiva y persistencia (Story 006 · TR-staff-001 · GDD F1/PA6 · ADR-0002) ────────

## Recalcula la nómina del día y se la fija a Economía (F1 por agente — enmienda personal-006). La
## nómina es por PLANTILLA, no por asistencia: el ausente cobra igual (baja pagada, orden 20/30 del
## dispatcher — documentado en la 004). Sin Economía inyectada (tests unitarios) → no-op. No emite.
func _actualizar_nomina() -> void:
	if _economia == null or not _economia.has_method("fijar_salarios_dia"):
		return
	var salarios: Array[float] = []
	for agente: RefCounted in plantilla:
		salarios.append(salario_dia(agente))
	_economia.fijar_salarios_dia(salarios)


## Estado serializable de Personal (contrato `Persist`; clave = node.name). SOLO estado no derivado:
## los salarios se recalculan con F1 al cargar, el RNG lo serializa RNGService (NUNCA duplicarlo
## aquí) y los puestos los registra el mundo al arrancar. Las coberturas se guardan por ÍNDICE de
## plantilla (los nombres pueden repetirse). Tipos JSON-safe (StringName → String).
func save() -> Dictionary:
	var coberturas: Dictionary = {}
	for puesto_id: StringName in _coberturas:
		coberturas[String(puesto_id)] = plantilla.find(_coberturas[puesto_id])
	return {
		"plantilla": plantilla.map(_agente_a_dict),
		"mercado": mercado.map(_agente_a_dict),
		"jornadas_desde_refresco": _jornadas_desde_refresco,
		"coberturas": coberturas,
	}


## Restaura desde un Dictionary (p. ej. parseado de JSON). Defensivo (ADR-0002: el dato corrupto se
## DESCARTA con aviso, nunca invalida el save entero) y SIN señales ("cargar sitúa, no reproduce"):
## ni incidencias ni partes retroactivos; la nómina se re-fija en silencio. INVARIANTE del caller:
## los puestos del mundo ya están registrados ANTES de cargar (los registra Main/Construcción).
func load_state(d: Dictionary) -> void:
	plantilla.clear()
	mercado.clear()
	_asignaciones.clear()
	_coberturas.clear()
	for datos: Variant in d.get("plantilla", []):
		var agente: RefCounted = _agente_desde_dict(datos)
		if agente != null:
			plantilla.append(agente)
	for datos: Variant in d.get("mercado", []):
		var candidato: RefCounted = _agente_desde_dict(datos)
		if candidato != null:
			mercado.append(candidato)
	_jornadas_desde_refresco = maxi(int(d.get("jornadas_desde_refresco", 0)), 0)
	_reconstruir_asignaciones()
	_reconstruir_coberturas(d.get("coberturas", {}))
	_sanear_estados_cargados()
	_actualizar_nomina()


## Un agente → Dictionary JSON-safe (StringName → String; el resto ya son int/String).
func _agente_a_dict(agente: RefCounted) -> Dictionary:
	return {
		"nombre": agente.nombre,
		"tipo": String(agente.tipo_id),
		"rango": String(agente.rango),
		"rapidez": agente.rapidez,
		"trato": agente.trato,
		"salud": agente.salud,
		"motivacion": agente.motivacion,
		"mando": agente.mando,
		"estado": String(agente.estado),
		"puesto": String(agente.puesto_id),
		# Bienestar #13: lo cansado que está y los cafés que ya se ha tomado hoy. Sin esto, guardar y
		# cargar sería un chute de energía gratis para toda la plantilla.
		"cansancio": agente.cansancio,
		"pausas_gastadas": agente.pausas_gastadas,
		"descanso_restante": minutos_de_descanso_restantes(agente),
	}


## Dictionary → agente. Tipo huérfano (no está en el catálogo) → null con aviso (se descarta ESE
## agente, el resto del save carga). Estado desconocido → libre con aviso. Los setters de Agente ya
## clampan los atributos corruptos (edge del GDD).
func _agente_desde_dict(datos: Variant) -> RefCounted:
	if not (datos is Dictionary):
		push_warning("Personal: entrada de agente corrupta en el save -> descartada")
		return null
	var tipo_id: StringName = StringName(String(datos.get("tipo", "")))
	if Datos.obtener(&"TipoAgente", tipo_id) == null:
		push_warning("Personal: TipoAgente '%s' del save no existe -> agente descartado" % tipo_id)
		return null
	var agente: RefCounted = AgenteScript.new(
		String(datos.get("nombre", "")), tipo_id,
		StringName(String(datos.get("rango", "policia"))),
		int(datos.get("rapidez", 3)), int(datos.get("trato", 3)),
		int(datos.get("salud", 3)), int(datos.get("motivacion", 3)),
		int(datos.get("mando", 0))
	)
	var estado: StringName = StringName(String(datos.get("estado", "libre")))
	var conocidos: Array[StringName] = [
		AgenteScript.ESTADO_LIBRE, AgenteScript.ESTADO_ASIGNADO,
		AgenteScript.ESTADO_AUSENTE, AgenteScript.ESTADO_CUBRIENDO,
		AgenteScript.ESTADO_DESCANSANDO,
	]
	if not (estado in conocidos):
		push_warning("Personal: estado '%s' desconocido en el save -> libre" % estado)
		estado = AgenteScript.ESTADO_LIBRE
	agente.estado = estado
	agente.puesto_id = StringName(String(datos.get("puesto", "")))
	# Bienestar #13: vuelve tan cansado como se guardó, con los cafés que ya se había tomado. Si le
	# pilló el guardado en la sala de descanso, sigue allí el rato que le quedaba (lo re-apunta
	# `load_state` al terminar, cuando la plantilla ya está entera).
	agente.cansancio = float(datos.get("cansancio", 0.0))
	agente.pausas_gastadas = int(datos.get("pausas_gastadas", 0))
	var restante: float = float(datos.get("descanso_restante", 0.0))
	if restante > 0.0 and estado == AgenteScript.ESTADO_DESCANSANDO:
		_descansando[agente] = restante
	return agente


## Reconstruye `_asignaciones` desde la titularidad cargada (`puesto_id` de cada agente). Puesto no
## registrado en el mundo o duplicado (gana el 1º — patrón Datos) → el agente pierde la plaza con
## aviso (al banquillo; si estaba ausente, sigue de baja).
func _reconstruir_asignaciones() -> void:
	for agente: RefCounted in plantilla:
		if agente.puesto_id == &"":
			continue
		if not _puestos.has(agente.puesto_id) or _asignaciones.has(agente.puesto_id):
			push_warning(
				"Personal: puesto '%s' del save no registrado o duplicado -> '%s' al banquillo"
				% [agente.puesto_id, agente.nombre]
			)
			agente.puesto_id = &""
			if agente.estado == AgenteScript.ESTADO_ASIGNADO:
				agente.estado = AgenteScript.ESTADO_LIBRE
			continue
		_asignaciones[agente.puesto_id] = agente


## Reconstruye `_coberturas` del save (`{puesto: índice de plantilla}`). Entrada inválida (puesto no
## registrado, índice fuera de rango o agente que no venía como cubriendo) → descartada con aviso.
func _reconstruir_coberturas(guardadas: Variant) -> void:
	if not (guardadas is Dictionary):
		return
	for clave: Variant in guardadas:
		var puesto_id: StringName = StringName(String(clave))
		var indice: int = int(guardadas[clave])
		if not _puestos.has(puesto_id) or indice < 0 or indice >= plantilla.size() \
				or plantilla[indice].estado != AgenteScript.ESTADO_CUBRIENDO:
			push_warning("Personal: cobertura de '%s' invalida en el save -> descartada" % puesto_id)
			continue
		_coberturas[puesto_id] = plantilla[indice]


## Última red tras cargar: un "asignado" sin puesto o un "cubriendo" sin cobertura reconstruida
## queda libre (aviso) — nunca estados huérfanos que confundan al gate FL4.
func _sanear_estados_cargados() -> void:
	for agente: RefCounted in plantilla:
		if agente.estado == AgenteScript.ESTADO_ASIGNADO and agente.puesto_id == &"":
			push_warning("Personal: '%s' asignado sin puesto en el save -> libre" % agente.nombre)
			agente.estado = AgenteScript.ESTADO_LIBRE
		elif agente.estado == AgenteScript.ESTADO_CUBRIENDO and _coberturas.find_key(agente) == null:
			push_warning("Personal: '%s' cubriendo sin cobertura en el save -> libre" % agente.nombre)
			agente.estado = AgenteScript.ESTADO_LIBRE


# ── Config (patrón Economía/Demanda: aplicar con clamp defensivo + carga con fallback) ───────

## Copia los knobs del config con clamp defensivo y aviso. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigPersonalScript):
		push_warning("Personal: config invalido -> defaults")
		config = ConfigPersonalScript.new()
	k_calidad = _clamp_knob(config.k_calidad, "k_calidad")
	prima_rango_oficial = maxf(_clamp_knob(config.prima_rango_oficial, "prima_rango_oficial"), 1.0)
	k_rapidez = _clamp_knob(config.k_rapidez, "k_rapidez")
	minutos_aguante = maxi(config.minutos_aguante, 1)
	min_pausa_corta = clampi(config.min_pausa_corta, 1, 240)
	min_pausa_normal = clampi(config.min_pausa_normal, 1, 240)
	min_pausa_caradura = clampi(config.min_pausa_caradura, 1, 240)
	mult_cansancio_horas_extra = clampf(config.mult_cansancio_horas_extra, 1.0, 5.0)
	mult_pausa_sin_sala = clampf(config.mult_pausa_sin_sala, 1.0, 5.0)
	k_cansancio_rendimiento = clampf(config.k_cansancio_rendimiento, 0.0, 2.0)
	k_confort_pausa = clampf(config.k_confort_pausa, 0.0, 1.0)
	mult_pausa_min = clampf(config.mult_pausa_min, 0.1, 1.0)
	plazas_descanso_base = maxi(config.plazas_descanso_base, 0)
	if config.minutos_aguante < 1:
		push_warning("Personal: knob 'minutos_aguante' fuera de rango (%d) -> 1" % config.minutos_aguante)
	k_motivacion_rapidez = _clamp_knob(config.k_motivacion_rapidez, "k_motivacion_rapidez")
	k_trato = _clamp_knob(config.k_trato, "k_trato")
	k_motivacion_trato = _clamp_knob(config.k_motivacion_trato, "k_motivacion_trato")
	base_ausencia = _clamp_knob(config.base_ausencia, "base_ausencia")
	k_salud = _clamp_knob(config.k_salud, "k_salud")
	coste_despido = _clamp_knob(config.coste_despido, "coste_despido")
	n_candidatos = maxi(config.n_candidatos, 1)
	refresco_mercado_jornadas = maxi(config.refresco_mercado_jornadas, 1)
	prob_candidato_oficial = clampf(config.prob_candidato_oficial, 0.0, 1.0)
	pool_nombres = config.pool_nombres.duplicate()
	if pool_nombres.is_empty():
		push_warning("Personal: pool_nombres vacio -> nombre generico")
		pool_nombres = ["Agente Sin Nombre"]


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Personal: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón Datos/Tiempo/Economía/Demanda).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Personal: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor
