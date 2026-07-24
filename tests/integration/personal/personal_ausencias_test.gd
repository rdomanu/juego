# Story 004 (epic personal) — ausencias del día al `nuevo_dia` (prio 30) · TR-staff-003 ·
# ADR-0001/0002. Tipo: Integration. DETERMINISTA: RNGService re-sembrado por test; knobs de ausencia
# artificiales (0 / 0.5 / 1.0 — boundary values intencionales, excepción permitida). Solo el test de
# Pausa mete nodos al árbol (physics real con multiplicador 0 → la medianoche es imposible).
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal aislado (sin árbol) con knobs de ausencia artificiales y la dotación estándar.
func _personal(base_ausencia: float, k_salud: float = 0.0) -> Node:
	var config: Resource = ConfigPersonalScript.new()
	config.base_ausencia = base_ausencia
	config.k_salud = k_salud
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(config)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	return personal


## Un policía de Documentación con la Salud pedida, metido directamente EN PLANTILLA (sin mercado —
## el mercado consumiría tiradas del RNG y ensuciaría el contrato determinista del test).
func _contratado(personal: Node, nombre: String, salud: int = 3) -> RefCounted:
	var agente: RefCounted = AgenteScript.new(nombre, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, salud, 3)
	personal.plantilla.append(agente)
	return agente


# ── AC-PE13: misma semilla + misma plantilla → mismos ausentes ────────────────────────────
func test_ausencias_deterministas_misma_semilla() -> void:
	# Arrange — 6 agentes con Salud variada (base 0.5 / k 0.1 → prob entre 0.3 y 0.7).
	var nombres: Array = ["Ana", "Carlos", "Lucía", "Javier", "María", "Pablo"]
	var saludes: Array = [1, 2, 3, 4, 5, 3]

	# Act — DOS pasadas con instancias nuevas pero semilla y plantilla idénticas.
	var pasadas: Array = []
	for pasada: int in range(2):
		var personal: Node = _personal(0.5, 0.1)
		for i: int in range(nombres.size()):
			_contratado(personal, String(nombres[i]), int(saludes[i]))
		RNGService.sembrar(42)
		personal._al_nuevo_dia()
		var ausentes: Array = []
		for agente: RefCounted in personal.plantilla:
			if agente.estado == AgenteScript.ESTADO_AUSENTE:
				ausentes.append(agente.nombre)
		pasadas.append(ausentes)

	# Assert — la lista de ausentes es EXACTAMENTE la misma (AC-PE13).
	assert_array(pasadas[0]).is_equal(pasadas[1])


# ── Forzado determinista (boundary): prob 1.0 → siempre ausente; prob 0.0 → nunca ─────────
func test_prob_extrema_siempre_y_nunca() -> void:
	# Arrange
	RNGService.sembrar(7)
	var seguro: Node = _personal(1.0)
	var nunca: Node = _personal(0.0)
	var cae: RefCounted = _contratado(seguro, "Ana Ruiz")
	var aguanta: RefCounted = _contratado(nunca, "Carlos Vega")

	# Act
	seguro._al_nuevo_dia()
	nunca._al_nuevo_dia()

	# Assert
	assert_str(String(cae.estado)).is_equal("ausente")
	assert_str(String(aguanta.estado)).is_equal("libre")


# ── AC-PE15 (parte): sin Oficial, la baja deja el puesto SIN DOTAR conservando titularidad ─
func test_ausencia_quita_dotacion_conserva_titularidad() -> void:
	# Arrange — titular de doc_1, sin Oficial; ausencia forzada (prob 1.0).
	RNGService.sembrar(11)
	var personal: Node = _personal(1.0)
	var agente: RefCounted = _contratado(personal, "Ana Ruiz")
	personal.asignar(agente, &"doc_1")

	# Act
	personal._al_nuevo_dia()

	# Assert — el puesto queda VACANTE para Flujo (gate FL4) pero el titular no pierde su plaza.
	assert_bool(personal.puesto_dotado(&"doc_1")).is_false()
	assert_object(personal.agente_de(&"doc_1")).is_same(agente)
	assert_str(String(agente.puesto_id)).is_equal("doc_1")
	assert_str(String(agente.estado)).is_equal("ausente")
	# Y la baja no se "cura" reasignando (rechazo de REGLA, silencioso — hoy no trabaja).
	assert_bool(personal.asignar(agente, &"doc_2")).is_false()
	assert_str(String(agente.puesto_id)).is_equal("doc_1")


# ── PA7/States: al `nuevo_dia` siguiente el ausente se reincorpora (titular Y banquillo) ──
func test_reincorporacion_al_dia_siguiente() -> void:
	# Arrange — un titular y un libre, ambos de baja hoy (prob 1.0).
	RNGService.sembrar(3)
	var personal: Node = _personal(1.0)
	var titular: RefCounted = _contratado(personal, "Ana Ruiz")
	var banquillo: RefCounted = _contratado(personal, "Carlos Vega")
	personal.asignar(titular, &"doc_1")
	personal._al_nuevo_dia()
	assert_str(String(titular.estado)).is_equal("ausente")
	assert_str(String(banquillo.estado)).is_equal("ausente")

	# Act — mañana nadie enferma (prob 0): cada uno vuelve a lo suyo.
	personal.base_ausencia = 0.0
	personal._al_nuevo_dia()

	# Assert — el titular a SU puesto (dotado otra vez), el del banquillo a libre.
	assert_str(String(titular.estado)).is_equal("asignado")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()
	assert_str(String(banquillo.estado)).is_equal("libre")


# ── Señal: una emisión de `incidencia_personal` por baja (sin Oficial: avisos individuales) ─
func test_incidencia_personal_una_por_baja() -> void:
	# Arrange — 2 bajas forzadas y bus espía (lambdas capturan por valor → Array).
	RNGService.sembrar(5)
	var personal: Node = _personal(1.0)
	var bus: Node = auto_free(EventBusScript.new())
	personal.usar_bus(bus)
	var avisos: Array = []
	bus.incidencia_personal.connect(
		func(texto: String, puesto: StringName) -> void: avisos.append([texto, puesto])
	)
	var ana: RefCounted = _contratado(personal, "Ana Ruiz")
	_contratado(personal, "Carlos Vega")
	personal.asignar(ana, &"doc_1")

	# Act
	personal._al_nuevo_dia()

	# Assert — 2 emisiones en orden de plantilla: la titular con su puesto, el libre con &"".
	assert_int(avisos.size()).is_equal(2)
	assert_bool(String(avisos[0][0]).contains("Ana Ruiz")).is_true()
	assert_str(String(avisos[0][1])).is_equal("doc_1")
	assert_bool(String(avisos[1][0]).contains("Carlos Vega")).is_true()
	assert_str(String(avisos[1][1])).is_equal("")


# ── Orden ADR-0001: las ausencias corren en el hueco 30 del dispatcher (entre 29 y 31) ────
func test_nuevo_dia_ausencias_en_prioridad_30() -> void:
	# Arrange — bus inyectado; Personal se registra SOLO al entrar al árbol (_ready); espías 29/31.
	RNGService.sembrar(9)
	var bus: Node = auto_free(EventBusScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	personal.usar_bus(bus)
	add_child(personal)   # _ready: carga el .tres real y registra el hueco 30
	personal.base_ausencia = 1.0   # tras _ready (la carga del config pisaría el knob)
	personal.k_salud = 0.0
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = _contratado(personal, "Ana Ruiz")
	personal.asignar(agente, &"doc_1")
	var estados: Array = []
	bus.registrar_ordenado(&"nuevo_dia", 29, func() -> void: estados.append(String(agente.estado)))
	bus.registrar_ordenado(&"nuevo_dia", 31, func() -> void: estados.append(String(agente.estado)))

	# Act
	bus.disparar_ordenado(&"nuevo_dia")

	# Assert — el espía 29 aún lo ve asignado; el 31 ya de baja (Personal corrió en el 30).
	assert_array(estados).is_equal(["asignado", "ausente"])


# ── AC-PE19: en Pausa (mundo REAL en el árbol) no se evalúa nada — no hay medianoche ──────
func test_pausa_no_evalua_ausencias() -> void:
	# Arrange — reloj de verdad cableado al MISMO bus que dispararía el `nuevo_dia`; una plantilla
	# que caería SEGURO (prob 1.0) si el dispatcher llegara a disparar.
	RNGService.sembrar(13)
	var bus: Node = auto_free(EventBusScript.new())
	var tiempo: Node = auto_free(TiempoScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	tiempo.usar_bus(bus)
	personal.usar_bus(bus)
	var avisos: Array = []
	bus.incidencia_personal.connect(
		func(_texto: String, puesto: StringName) -> void: avisos.append(puesto)
	)
	add_child(tiempo)
	add_child(personal)
	personal.base_ausencia = 1.0
	personal.k_salud = 0.0
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	var agente: RefCounted = _contratado(personal, "Ana Ruiz")
	personal.asignar(agente, &"doc_1")
	tiempo.fijar_velocidad(TiempoScript.Velocidad.PAUSA)

	# Act — 30 frames de physics REALES con el juego en Pausa.
	for i: int in range(30):
		await get_tree().physics_frame

	# Assert — nadie evaluado: sigue asignado, el puesto dotado y cero incidencias.
	assert_str(String(agente.estado)).is_equal("asignado")
	assert_bool(personal.puesto_dotado(&"doc_1")).is_true()
	assert_int(avisos.size()).is_equal(0)
