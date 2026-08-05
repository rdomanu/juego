# La IMPRESORA DE DOCUMENTOS y el VIAJE DEL PAPEL — fórmulas y máquina de fases · GDD
# `design/gdd/impresora-documentos-tramite.md` (diseño cerrado 2026-08-01) · ADR-0001/0004.
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj real, sin I/O: los ticks se empujan a mano).
# Aislamiento: nodos con .new() sin árbol; el layout se siembra con el registro directo del modelo.
extends GdUnitTestSuite

const ImpresoraScript := preload("res://src/core/impresora/impresora_documentos.gd")
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

# ── Fixture (números redondos ELEGIDOS para que la fórmula se lea a simple vista) ──────────
## Oficina de Documentación de sobra: x 0..7, y 0..7.
const OFICINA := &"sala_documentacion"
const RECT_OFICINA := Rect2i(0, 0, 8, 8)
const PUESTO := &"puesto_doc_general"
## Ancla con su bloque 2×3 entero dentro: mostrador (2,2)-(3,2), funcionario en y=1, ciudadano en y=3.
const ANCLA_PUESTO := Vector2i(2, 2)
## Celda de la impresora del fixture, a 3 celdas de la celda de trabajo (2,2) → (2,2)→(2,1)→(2,0)... no:
## se elige (5,2), en la misma fila, para que el BFS dé exactamente 3 pasos por suelo libre.
const CELDA_IMPRESORA := Vector2i(5, 2)
const DISTANCIA_IMPRESORA: int = 3
## Una segunda impresora MÁS LEJOS (para el desempate por distancia).
const CELDA_IMPRESORA_LEJOS := Vector2i(7, 6)
## Velocidad de 1 celda/min: así `2 × distancia` se lee tal cual en el resultado.
const VELOCIDAD_UNA_CELDA := 1.0
## Recogida de 2 min: el sumando fijo del viaje.
const RECOGIDA := 2.0
## t_viaje esperado con esos knobs = 2×3/1 + 2 = 8.
const T_VIAJE_ESPERADO := 8.0
const T_AVISO := 5.0
const PUESTO_ID := &"doc_1"
const SERVICIO_ODAC := &"ODAC"
const SERVICIO_DOC := &"Documentacion"
const TRAMITE_TIE := &"tie"
const TRAMITE_DNI := &"dni"
const DENUNCIA_HURTO := &"hurto_robo"
## Turnos del día (0 mañana · 1 tarde · 2 noche) — los mismos enteros que viajan en el bus.
const TURNO_MANANA: int = 0
const TURNO_TARDE: int = 1
## Lo que cuesta un turno de uso de la impresora, según el catálogo aprobado.
const EUR_POR_TURNO: float = 2.0


# ── Helpers de fixture ────────────────────────────────────────────────────────────────────
## Config con los knobs "de laboratorio" (velocidad 1 celda/min, recogida 2 min, aviso 5 min).
func _config() -> Resource:
	var config: Resource = ConfigImpresoraScript.new()
	config.velocidad_celdas_min = VELOCIDAD_UNA_CELDA
	config.t_recogida_min = RECOGIDA
	config.t_aviso_min = T_AVISO
	return config


## Construcción aislada con la oficina y un puesto ya colocados.
func _construccion() -> Node:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion._crear_sala(OFICINA, RECT_OFICINA)
	construccion.construir_de_oficio_elemento(PUESTO, ANCLA_PUESTO, PUESTO_ID)
	return construccion


## Impresora cableada a esa Construcción, con los knobs de laboratorio.
func _impresora(construccion: Node) -> Node:
	var impresora: Node = auto_free(ImpresoraScript.new())
	impresora.aplicar_config(_config())
	impresora.usar_construccion(construccion)
	return impresora


## Coloca una impresora de documentos en una celda y devuelve su id de elemento.
func _colocar_impresora(construccion: Node, celda: Vector2i) -> StringName:
	return construccion.construir_de_oficio_elemento(ImpresoraScript.ID_CATALOGO, celda)


## Empuja `veces` ticks de 1 minuto (el delta más fino: si la cuenta sale aquí, sale con cualquiera).
func _tics(impresora: Node, veces: int) -> void:
	for _i: int in range(veces):
		impresora.avanzar(1.0)


# ── F1 · La fórmula del viaje (§Formulas del GDD) ─────────────────────────────────────────
func test_minutos_de_viaje_es_ida_y_vuelta_mas_recogida() -> void:
	# Arrange
	var impresora: Node = _impresora(_construccion())
	# Act / Assert — 2 × 3 celdas / 1 celda-min + 2 min de recogida = 8.
	assert_float(impresora.minutos_de_viaje(DISTANCIA_IMPRESORA)).is_equal_approx(T_VIAJE_ESPERADO, 0.001)


func test_minutos_de_viaje_con_impresora_pegada_cuesta_solo_la_recogida() -> void:
	# Arrange — distancia 0: el funcionario ya la tiene al lado, pero coger el papel sigue costando.
	var impresora: Node = _impresora(_construccion())
	# Act / Assert
	assert_float(impresora.minutos_de_viaje(0)).is_equal_approx(RECOGIDA, 0.001)


func test_minutos_de_viaje_sin_velocidad_no_divide_por_cero() -> void:
	# Arrange — velocidad 0 = trayecto instantáneo (mismo convenio que el camino 0 de Flujo).
	var impresora: Node = _impresora(_construccion())
	impresora.velocidad_celdas_min = 0.0
	# Act / Assert — ni INF ni crash: solo la recogida.
	assert_float(impresora.minutos_de_viaje(DISTANCIA_IMPRESORA)).is_equal_approx(RECOGIDA, 0.001)


# ── P2 · Qué trámites llevan papel (decisión del usuario) ─────────────────────────────────
func test_denuncia_de_odac_lleva_papel() -> void:
	var impresora: Node = _impresora(_construccion())
	assert_bool(impresora.es_tramite_con_papel(SERVICIO_ODAC, DENUNCIA_HURTO)).is_true()


func test_expedicion_de_tie_lleva_papel() -> void:
	var impresora: Node = _impresora(_construccion())
	assert_bool(impresora.es_tramite_con_papel(SERVICIO_DOC, TRAMITE_TIE)).is_true()


func test_dni_no_lleva_papel() -> void:
	# El resto de Documentación (DNI, pasaporte, consultas) NO hace el viaje — GDD P2.
	var impresora: Node = _impresora(_construccion())
	assert_bool(impresora.es_tramite_con_papel(SERVICIO_DOC, TRAMITE_DNI)).is_false()


func test_aviso_justo_en_el_umbral_de_t_aviso() -> void:
	# Arrange
	var impresora: Node = _impresora(_construccion())
	# Act / Assert — al trámite le quedan exactamente T_AVISO → se levanta YA (el umbral es inclusivo).
	assert_bool(impresora.necesita_aviso(T_AVISO)).is_true()
	assert_bool(impresora.necesita_aviso(T_AVISO + 0.1)).is_false()


# ── Elegir impresora: la más cercana ACCESIBLE, empate por orden de construcción ──────────
func test_elige_la_impresora_mas_cercana() -> void:
	# Arrange — la LEJANA se construye primero, para que ganar no pueda ser "la primera de la lista".
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA_LEJOS)
	var cerca: StringName = _colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	# Act
	var elegida: StringName = impresora.impresora_mas_cercana(ANCLA_PUESTO)
	# Assert
	assert_str(String(elegida)).is_equal(String(cerca))
	assert_int(impresora.distancia_a_impresora(ANCLA_PUESTO)).is_equal(DISTANCIA_IMPRESORA)


func test_sin_impresoras_no_hay_a_donde_ir() -> void:
	# Arrange
	var impresora: Node = _impresora(_construccion())
	# Act / Assert — `&""` y distancia -1: quien pregunta decide, no se inventa un número.
	assert_str(String(impresora.impresora_mas_cercana(ANCLA_PUESTO))).is_equal("")
	assert_int(impresora.distancia_a_impresora(ANCLA_PUESTO)).is_equal(-1)


func test_sin_impresora_no_arranca_el_viaje() -> void:
	var impresora: Node = _impresora(_construccion())
	assert_bool(impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)).is_false()
	assert_bool(impresora.retiene(PUESTO_ID)).is_false()


# ── La máquina de fases: ida → recogida → vuelta → entregado ──────────────────────────────
func test_el_viaje_recorre_sus_cuatro_fases_y_entrega_a_tiempo() -> void:
	# Arrange — ida 3 min, recogida 2 min, vuelta 3 min = 8 min en total.
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	# Act / Assert — se comprueba fase a fase, en el minuto exacto en que cambia.
	assert_bool(impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)).is_true()
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_IDA))
	assert_float(impresora.restante_de(PUESTO_ID)).is_equal_approx(T_VIAJE_ESPERADO, 0.001)
	_tics(impresora, 3)   # minuto 3: llega a la impresora
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_RECOGIDA))
	_tics(impresora, 2)   # minuto 5: coge el papel y da media vuelta
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_VUELTA))
	assert_bool(impresora.con_papel(PUESTO_ID)).is_true()
	_tics(impresora, 2)   # minuto 7: todavía andando — el trámite sigue retenido
	assert_bool(impresora.retiene(PUESTO_ID)).is_true()
	_tics(impresora, 1)   # minuto 8: en su mesa
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_ENTREGADO))
	assert_bool(impresora.retiene(PUESTO_ID)).is_false()
	assert_float(impresora.restante_de(PUESTO_ID)).is_equal_approx(0.0, 0.001)


func test_un_tick_gigante_no_alarga_ni_acorta_el_viaje() -> void:
	# Arrange — el sobrante de cada fase se arrastra a la siguiente: el viaje dura lo que dura,
	# tanto a pasitos de 1 min como de un solo salto (determinismo frente al tamaño del delta).
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	# Act — un único tick de exactamente t_viaje.
	impresora.avanzar(T_VIAJE_ESPERADO)
	# Assert
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_ENTREGADO))
	assert_bool(impresora.con_papel(PUESTO_ID)).is_true()


func test_un_tick_de_menos_no_entrega() -> void:
	# Arrange
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	# Act — un pelo antes de llegar.
	impresora.avanzar(T_VIAJE_ESPERADO - 0.5)
	# Assert — sigue reteniendo: el trámite NO puede cerrarse.
	assert_bool(impresora.retiene(PUESTO_ID)).is_true()


func test_no_se_arranca_un_segundo_viaje_sobre_uno_en_curso() -> void:
	# Arrange — invariante de "una sola incorporación": el aviso se repite en cada tick de Flujo y no
	# puede acumular viajes.
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	_tics(impresora, 2)
	# Act
	var segundo: bool = impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	# Assert — el segundo se rechaza y el primero sigue su curso, sin reiniciarse.
	assert_bool(segundo).is_false()
	assert_float(impresora.restante_de(PUESTO_ID)).is_equal_approx(T_VIAJE_ESPERADO - 2.0, 0.001)


func test_transicion_invalida_no_cambia_la_fase() -> void:
	# Arrange — la tabla de transiciones es la guardia: saltar de IDA a ENTREGADO no existe.
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	# Act
	var aplicada: bool = impresora._transicionar(PUESTO_ID, ImpresoraScript.FASE_ENTREGADO)
	# Assert — avisa y no cambia nada (un dato corrupto no rompe la simulación).
	assert_bool(aplicada).is_false()
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_IDA))


# ── Edge case del GDD: impresora demolida a mitad de viaje ────────────────────────────────
func test_impresora_demolida_a_media_ida_vuelve_con_las_manos_vacias() -> void:
	# Arrange
	var construccion: Node = _construccion()
	var impresora_id: StringName = _colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	_tics(impresora, 1)   # va de camino
	# Act — el jugador la demuele con el funcionario a medio pasillo.
	impresora.impresora_demolida(impresora_id)
	# Assert — da media vuelta SIN papel; el trámite se cierra igual, no se cuelga para siempre.
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_VUELTA))
	assert_bool(impresora.con_papel(PUESTO_ID)).is_false()
	_tics(impresora, DISTANCIA_IMPRESORA)
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_ENTREGADO))
	assert_bool(impresora.retiene(PUESTO_ID)).is_false()


func test_consumir_viaje_deja_la_ventanilla_limpia_para_el_siguiente() -> void:
	# Arrange
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	_tics(impresora, int(T_VIAJE_ESPERADO))
	# Act
	impresora.consumir_viaje(PUESTO_ID)
	# Assert — sin rastro: el siguiente ciudadano empieza su propio viaje desde cero.
	assert_bool(impresora.hay_viaje(PUESTO_ID)).is_false()
	assert_str(String(impresora.fase_de(PUESTO_ID))).is_equal(String(ImpresoraScript.FASE_SIN_VIAJE))
	assert_bool(impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)).is_true()


func test_la_ventanilla_cuenta_que_esta_a_por_el_documento() -> void:
	# Arrange (§Detailed Rules 5: mismo patrón que el "☕ DESCANSO").
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	# Act / Assert
	assert_str(impresora.texto_ventanilla(PUESTO_ID)).is_equal(ImpresoraScript.TEXTO_SIN_VIAJE)
	impresora.iniciar_viaje(PUESTO_ID, ANCLA_PUESTO)
	assert_str(impresora.texto_ventanilla(PUESTO_ID)).is_equal(
		ImpresoraScript.TEXTO_A_POR_EL_DOCUMENTO
	)
	_tics(impresora, int(T_VIAJE_ESPERADO))
	assert_str(impresora.texto_ventanilla(PUESTO_ID)).is_equal(ImpresoraScript.TEXTO_SIN_VIAJE)


# ── F2 · Mantenimiento POR USO: 2 € por turno en que la sala atiende ──────────────────────
## Reloj de mentira: devuelve el turno que le digamos. Sin él no se cuentan turnos (por diseño).
class RelojFalso extends Node:
	var minutos_juego: float = 0.0
	var _turno: int = 0

	func fijar_turno(turno: int) -> void:
		_turno = turno

	func turno_de(_min_dia: float) -> int:
		return _turno


func test_mantenimiento_cobra_un_turno_por_cada_turno_atendido() -> void:
	# Arrange — una impresora en la oficina, y la sala atiende en mañana Y en tarde.
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	var reloj: Node = auto_free(RelojFalso.new())
	impresora.usar_tiempo(reloj)
	# Act — el mismo turno anotado varias veces cuenta UNA (es un conjunto, no un contador de ticks).
	reloj.fijar_turno(TURNO_MANANA)
	impresora.registrar_atencion(PUESTO_ID)
	impresora.registrar_atencion(PUESTO_ID)
	reloj.fijar_turno(TURNO_TARDE)
	impresora.registrar_atencion(PUESTO_ID)
	# Assert — 2 turnos × 2 €.
	assert_int(impresora.turnos_usados_de(construccion.sala_de_elemento(PUESTO_ID))).is_equal(2)
	assert_float(impresora.coste_mantenimiento_uso()).is_equal_approx(2.0 * EUR_POR_TURNO, 0.001)


func test_sala_cerrada_no_paga_mantenimiento() -> void:
	# Arrange — impresora instalada pero la sala no ha atendido a nadie en todo el día.
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	impresora.usar_tiempo(auto_free(RelojFalso.new()))
	# Act / Assert — regla explícita del GDD: sala cerrada = 0 €.
	assert_float(impresora.coste_mantenimiento_uso()).is_equal_approx(0.0, 0.001)


func test_el_nuevo_dia_registra_el_gasto_y_reinicia_la_cuenta() -> void:
	# Arrange
	var construccion: Node = _construccion()
	_colocar_impresora(construccion, CELDA_IMPRESORA)
	var impresora: Node = _impresora(construccion)
	var reloj: Node = auto_free(RelojFalso.new())
	impresora.usar_tiempo(reloj)
	var economia: Node = auto_free(EconomiaFalsa.new())
	impresora.usar_economia(economia)
	reloj.fijar_turno(TURNO_MANANA)
	impresora.registrar_atencion(PUESTO_ID)
	# Act
	impresora._al_nuevo_dia()
	# Assert — se le registra el gasto a Economía (que es quien mueve dinero) y el día empieza a 0.
	assert_float(economia.registrado).is_equal_approx(EUR_POR_TURNO, 0.001)
	assert_float(impresora.coste_mantenimiento_uso()).is_equal_approx(0.0, 0.001)


## Economía de mentira: solo apunta cuánto le han registrado.
class EconomiaFalsa extends Node:
	var registrado: float = 0.0

	func registrar_mantenimiento(euros: float) -> void:
		registrado += euros
