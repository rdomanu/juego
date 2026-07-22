# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: ¿es divertido y construible el bucle core de la Oficina de Denuncias?
# Date: 2026-07-22
extends Node2D
## Mundo del slice (Escalón 3 A+B+C): varios PUESTOS construibles (fantasma/rotación/presupuesto),
## ASIENTOS fijos (te sientas si hay hueco), y COLA CON BARANDILLAS que traza el jugador (postes →
## recorrido; capacidad = longitud/separación; si se llena, desborde a la entrada). Atención FIFO.

const PersonaScript := preload("res://personas/persona.gd")
const DemandaScript := preload("res://demanda/demanda.gd")
const PuestoScript := preload("res://puestos/puesto.gd")
const AgenteScript := preload("res://agentes/agente.gd")

enum Modo { NORMAL, PUESTO, BARANDILLA, DEMOLER, AGENTE }

const NUM_AGENTES: int = 3
const SALARIO_DIA: int = 60
var COLORES_AGENTE := [Color(0.20, 0.50, 0.35), Color(0.45, 0.30, 0.55), Color(0.55, 0.35, 0.20)]

# Suelo caminable (rectángulo). Coordenadas de pantalla.
var SUELO := PackedVector2Array([
	Vector2(80, 120), Vector2(1080, 120), Vector2(1080, 600), Vector2(80, 600)
])
const MURO_POS := Vector2(600, 120)
const MURO_SIZE := Vector2(70, 300)
var MURO_OUTLINE := PackedVector2Array([
	Vector2(600, 120), Vector2(670, 120), Vector2(670, 420), Vector2(600, 420)
])

const POS_ENTRADA := Vector2(150, 560)
const POS_PUESTO_INICIAL := Vector2(960, 240)
const POS_SALIDA := Vector2(150, 560)

const DUR_DNI: float = 12.0
const DUR_DENUNCIA: float = 18.0
const COLOR_DNI := Color(0.20, 0.45, 0.85)
const COLOR_DENUNCIA := Color(0.90, 0.55, 0.20)

# Espera: ASIENTOS fijos, luego cola (barandillas o zigzag de respaldo), luego desborde a la entrada.
const NUM_ASIENTOS: int = 12
var _asientos: Array[Vector2] = []
var _asientos_libres: Array[bool] = []
var _asiento_de: Dictionary = {}
var _fila: Array = []                 # personas de pie, en orden

const SEP_COLA: float = 34.0          # separación entre personas en la cola de barandillas
var _postes: Array[Vector2] = []      # recorrido de la cola trazado por el jugador (>=2 postes = activo)

# Cola en zigzag (respaldo si no hay barandillas).
const FILA_CABEZA := Vector2(490, 440)
const FILA_POR_FILA: int = 10
const FILA_SEP_X: float = 40.0
const FILA_SEP_Y: float = 48.0

# Construcción
const COSTE_PUESTO: int = 500
const REEMBOLSO_PUESTO: int = 250   # demoler devuelve el 50% (GDD Construcción F4)
const REJILLA: float = 40.0
const ANCHO_P: float = 68.0
const ALTO_P: float = 44.0
var DIRS_P := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]

var _region: NavigationRegion2D
var _demanda: Node
var _cola: Array = []                 # orden de llegada (FIFO) → orden de atención
var _puestos: Array = []

var _modo: int = Modo.NORMAL
var _fantasma_pos: Vector2 = Vector2.ZERO
var _fantasma_valido: bool = false
var _fantasma_orientacion: int = 0
var _demoler_puesto: Node = null
var _demoler_poste: int = -1
var _agentes: Array = []
var _agente_sel: Node = null

var _espera_total: float = 0.0
var _atendidos: int = 0
var _ultima_espera: float = 0.0

const RANGOS := ["Subinspector", "Inspector", "Inspector Jefe", "Comisario"]
const OBJETIVO_PASO: int = 25
var _rango: int = 0
var _objetivo: int = OBJETIVO_PASO

# Spike de rendimiento (QQ-02): genera muchos NPCs y mide FPS.
const TOPE_ESTRES: int = 80
var _estres: bool = false
var _npcs_vivos: int = 0
var _frames_estres: int = 0

func _ready() -> void:
	_crear_suelo_navegable()
	_crear_asientos()
	_crear_puesto(POS_PUESTO_INICIAL)
	_crear_agentes()
	_asignar_agente(_agentes[0], _puestos[0])   # el 1er puesto arranca con un agente
	queue_redraw()
	EventBus.nuevo_dia.connect(_on_nuevo_dia)
	var d := DemandaScript.new()
	d.generar.connect(_on_generar)
	add_child(d)
	_demanda = d
	if DisplayServer.get_name() == "headless":
		_estres = true   # en headless (medición por terminal) el spike arranca solo

func _crear_agentes() -> void:
	for i in NUM_AGENTES:
		var ag := AgenteScript.new()
		ag.configurar(COLORES_AGENTE[i % COLORES_AGENTE.size()])
		_agentes.append(ag)
		add_child(ag)
	_recolocar_agentes()

func _pos_disponible(indice: int) -> Vector2:
	return Vector2(760.0 + float(indice) * 40.0, 560.0)   # "personal disponible" (abajo-derecha)

func _recolocar_agentes() -> void:
	var libre_idx := 0
	for ag in _agentes:
		if not is_instance_valid(ag):
			continue
		if ag.puesto != null and is_instance_valid(ag.puesto):
			ag.position = ag.puesto.pos_funcionario()
		else:
			ag.position = _pos_disponible(libre_idx)
			libre_idx += 1

func _asignar_agente(ag: Node, pu: Node) -> void:
	if pu.agente != null and pu.agente != ag:      # el puesto ya tenía otro → ese queda libre
		pu.agente.puesto = null
	if ag.puesto != null and ag.puesto != pu and is_instance_valid(ag.puesto):  # el agente venía de otro puesto
		ag.puesto.agente = null
		ag.puesto.queue_redraw()
	ag.puesto = pu
	pu.agente = ag
	pu.queue_redraw()
	_recolocar_agentes()

func _liberar_agente(ag: Node) -> void:
	if ag.puesto != null and is_instance_valid(ag.puesto):
		ag.puesto.agente = null
		ag.puesto.queue_redraw()
	ag.puesto = null
	_recolocar_agentes()

func _on_nuevo_dia() -> void:
	var asignados := agentes_asignados()
	if asignados > 0:
		Economia.cobrar(SALARIO_DIA * asignados)   # salario de los que trabajan

func _crear_suelo_navegable() -> void:
	_region = NavigationRegion2D.new()
	var navpoly := NavigationPolygon.new()
	navpoly.agent_radius = 14.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(SUELO)
	src.add_obstruction_outline(MURO_OUTLINE)
	NavigationServer2D.bake_from_source_geometry_data(navpoly, src)
	_region.navigation_polygon = navpoly
	add_child(_region)

func _crear_asientos() -> void:
	var base := Vector2(200, 190)
	for f in 3:
		for c in 4:
			_asientos.append(base + Vector2(c * 72.0, f * 62.0))
			_asientos_libres.append(true)

func _crear_puesto(pos: Vector2, orientacion: int = 0) -> void:
	var pu := PuestoScript.new()
	pu.position = pos
	pu.orientacion = orientacion
	_puestos.append(pu)
	add_child(pu)

# --- Modos de edición ---
func activar_modo_puesto() -> void:
	_modo = Modo.NORMAL if _modo == Modo.PUESTO else Modo.PUESTO
	queue_redraw()

func activar_modo_barandilla() -> void:
	_modo = Modo.NORMAL if _modo == Modo.BARANDILLA else Modo.BARANDILLA
	queue_redraw()

func en_modo_puesto() -> bool:
	return _modo == Modo.PUESTO

func en_modo_barandilla() -> bool:
	return _modo == Modo.BARANDILLA

func activar_modo_demoler() -> void:
	_modo = Modo.NORMAL if _modo == Modo.DEMOLER else Modo.DEMOLER
	queue_redraw()

func en_modo_demoler() -> bool:
	return _modo == Modo.DEMOLER

func activar_modo_agente() -> void:
	_modo = Modo.NORMAL if _modo == Modo.AGENTE else Modo.AGENTE
	if _modo != Modo.AGENTE:
		_deseleccionar_agente()
	queue_redraw()

func en_modo_agente() -> bool:
	return _modo == Modo.AGENTE

func _agente_bajo(m: Vector2) -> Node:
	for ag in _agentes:
		if is_instance_valid(ag) and ag.position.distance_to(m) < 16.0:
			return ag
	return null

func _seleccionar_agente(ag: Node) -> void:
	_deseleccionar_agente()
	_agente_sel = ag
	if ag != null:
		ag.set_sel(true)

func _deseleccionar_agente() -> void:
	if _agente_sel != null and is_instance_valid(_agente_sel):
		_agente_sel.set_sel(false)
	_agente_sel = null

func _clic_agente(m: Vector2) -> void:
	if _agente_sel != null:
		var pu := _puesto_bajo(m)
		if pu != null:
			_asignar_agente(_agente_sel, pu)
		else:
			_liberar_agente(_agente_sel)   # clic fuera de un puesto → a disponibles
		_deseleccionar_agente()
	else:
		var ag := _agente_bajo(m)
		if ag != null:
			_seleccionar_agente(ag)

func _process(_dt: float) -> void:
	if _modo == Modo.PUESTO or _modo == Modo.BARANDILLA:
		_fantasma_pos = _snap(get_global_mouse_position())
		_fantasma_valido = _colocacion_valida(_fantasma_pos)
		queue_redraw()
	elif _modo == Modo.DEMOLER:
		var m := get_global_mouse_position()
		_demoler_puesto = _puesto_bajo(m)
		_demoler_poste = _poste_bajo(m) if _demoler_puesto == null else -1
		queue_redraw()

func _snap(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x / REJILLA) * REJILLA, roundf(p.y / REJILLA) * REJILLA)

func _colocacion_valida(pos: Vector2) -> bool:
	if pos.x < 110.0 or pos.x > 1050.0 or pos.y < 155.0 or pos.y > 570.0:
		return false
	var muro := Rect2(MURO_POS - Vector2(24, 24), MURO_SIZE + Vector2(48, 48))
	if muro.has_point(pos):
		return false
	if _modo == Modo.PUESTO:
		for pu in _puestos:
			if is_instance_valid(pu) and pu.position.distance_to(pos) < 74.0:
				return false
	return true

func _puesto_bajo(m: Vector2) -> Node:
	for pu in _puestos:
		if is_instance_valid(pu) and pu.position.distance_to(m) < 40.0:
			return pu
	return null

func _poste_bajo(m: Vector2) -> int:
	for i in _postes.size():
		if _postes[i].distance_to(m) < 14.0:
			return i
	return -1

func _demoler_en(m: Vector2) -> void:
	var pu := _puesto_bajo(m)
	if pu != null:
		_borrar_puesto(pu)
		return
	var idx := _poste_bajo(m)
	if idx >= 0:
		_postes.remove_at(idx)
		_reordenar_fila()
		queue_redraw()

func _borrar_puesto(pu: Node) -> void:
	if pu.agente != null and is_instance_valid(pu.agente):
		pu.agente.puesto = null           # el agente vuelve a disponibles
	_puestos.erase(pu)
	Economia.abonar(REEMBOLSO_PUESTO)   # devuelve el 50%
	pu.queue_free()
	_demoler_puesto = null
	_recolocar_agentes()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _modo == Modo.NORMAL:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if _modo == Modo.PUESTO and kc == KEY_R:
			_fantasma_orientacion = (_fantasma_orientacion + 1) % 4
			queue_redraw()
		elif _modo == Modo.BARANDILLA and kc == KEY_Z:
			if not _postes.is_empty():
				_postes.remove_at(_postes.size() - 1)
				_reordenar_fila()
				queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_deseleccionar_agente()
			_modo = Modo.NORMAL
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if _modo == Modo.PUESTO:
				if _fantasma_valido and Economia.puede_pagar(COSTE_PUESTO):
					Economia.cobrar(COSTE_PUESTO)
					_crear_puesto(_fantasma_pos, _fantasma_orientacion)
			elif _modo == Modo.BARANDILLA:
				if _fantasma_valido:
					_postes.append(_fantasma_pos)
					_reordenar_fila()
					queue_redraw()
			elif _modo == Modo.DEMOLER:
				_demoler_en(get_global_mouse_position())
			elif _modo == Modo.AGENTE:
				_clic_agente(get_global_mouse_position())

func _draw() -> void:
	draw_rect(Rect2(SUELO[0], SUELO[2] - SUELO[0]), Color(0.72, 0.76, 0.82), false, 3.0)
	draw_rect(Rect2(MURO_POS, MURO_SIZE), Color(0.38, 0.40, 0.46))
	draw_circle(POS_ENTRADA, 12.0, Color(0.30, 0.66, 0.42))
	for a in _asientos:
		draw_rect(Rect2(a - Vector2(11, 11), Vector2(22, 22)), Color(0.62, 0.64, 0.70))
	_dibujar_barandillas()
	if _postes.size() < 2:
		draw_circle(FILA_CABEZA, 5.0, Color(0.58, 0.60, 0.66))   # inicio del zigzag de respaldo

	if _modo == Modo.PUESTO or _modo == Modo.BARANDILLA:
		_dibujar_rejilla()
	if _modo == Modo.PUESTO:
		var horizontal: bool = (_fantasma_orientacion % 2 == 1)
		var w: float = ALTO_P if horizontal else ANCHO_P
		var h: float = ANCHO_P if horizontal else ALTO_P
		var c: Color = Color(0.30, 0.80, 0.30, 0.5) if _fantasma_valido else Color(0.85, 0.25, 0.25, 0.5)
		draw_rect(Rect2(_fantasma_pos - Vector2(w, h) * 0.5, Vector2(w, h)), c)
		var f: Vector2 = DIRS_P[_fantasma_orientacion]
		draw_circle(_fantasma_pos - f * 20.0, 8.0, Color(0.15, 0.32, 0.58, 0.75))
	elif _modo == Modo.BARANDILLA:
		var c: Color = Color(0.30, 0.80, 0.30, 0.7) if _fantasma_valido else Color(0.85, 0.25, 0.25, 0.7)
		if not _postes.is_empty():
			draw_line(_postes[_postes.size() - 1], _fantasma_pos, Color(0.5, 0.5, 0.55, 0.6), 2.0)
		draw_circle(_fantasma_pos, 6.0, c)
	elif _modo == Modo.DEMOLER:
		if _demoler_puesto != null and is_instance_valid(_demoler_puesto):
			draw_circle(_demoler_puesto.position, 42.0, Color(0.90, 0.20, 0.20, 0.35))   # puesto a borrar
		elif _demoler_poste >= 0 and _demoler_poste < _postes.size():
			draw_circle(_postes[_demoler_poste], 11.0, Color(0.90, 0.20, 0.20, 0.65))    # poste a borrar
	elif _modo == Modo.AGENTE:
		draw_rect(Rect2(Vector2(745, 542), Vector2(NUM_AGENTES * 40 + 12, 36)), Color(0.30, 0.50, 0.40, 0.25))  # personal disponible

func _dibujar_barandillas() -> void:
	if _postes.is_empty():
		return
	var col_bar := Color(0.45, 0.42, 0.38)
	for i in range(1, _postes.size()):
		draw_line(_postes[i - 1], _postes[i], col_bar, 3.0)
	for i in _postes.size():
		var c := Color(0.85, 0.6, 0.2) if i == 0 else col_bar   # el poste 0 = cabeza (naranja)
		draw_circle(_postes[i], 5.0, c)

func _dibujar_rejilla() -> void:
	var g := Color(0.45, 0.47, 0.52, 0.30)
	var x := 80.0
	while x <= 1080.0:
		draw_line(Vector2(x, 120.0), Vector2(x, 600.0), g, 1.0)
		x += REJILLA
	var y := 120.0
	while y <= 600.0:
		draw_line(Vector2(80.0, y), Vector2(1080.0, y), g, 1.0)
		y += REJILLA

# --- Recorrido de la cola (barandillas) ---
func _longitud_recorrido() -> float:
	var total := 0.0
	for i in range(1, _postes.size()):
		total += _postes[i - 1].distance_to(_postes[i])
	return total

func capacidad_cola() -> int:
	if _postes.size() < 2:
		return 0
	return int(_longitud_recorrido() / SEP_COLA) + 1

func _pos_en_recorrido(dist: float) -> Vector2:
	if _postes.size() == 1:
		return _postes[0]
	var restante := dist
	for i in range(1, _postes.size()):
		var seg := _postes[i - 1].distance_to(_postes[i])
		if seg <= 0.0:
			continue
		if restante <= seg:
			return _postes[i - 1].lerp(_postes[i], restante / seg)
		restante -= seg
	return _postes[_postes.size() - 1]

func _pos_fuera(k: int) -> Vector2:
	return Vector2(115.0, 540.0 - float(k) * 32.0)   # desborde apilado en la entrada

## Posición de una persona de pie según su índice en la fila.
func _pos_espera_pie(indice: int) -> Vector2:
	if _postes.size() >= 2:
		var cap := capacidad_cola()
		if indice < cap:
			return _pos_en_recorrido(float(indice) * SEP_COLA)
		return _pos_fuera(indice - cap)
	return _pos_fila_zigzag(indice)

func _pos_fila_zigzag(indice: int) -> Vector2:
	var fila: int = indice / FILA_POR_FILA
	var col: int = indice % FILA_POR_FILA
	if fila % 2 == 1:
		col = FILA_POR_FILA - 1 - col
	return FILA_CABEZA + Vector2(-col * FILA_SEP_X, fila * FILA_SEP_Y)

func _primer_asiento_libre() -> int:
	for i in _asientos_libres.size():
		if _asientos_libres[i]:
			return i
	return -1

func _on_generar(tipo: StringName) -> void:
	var dur: float = DUR_DNI if tipo == &"dni" else DUR_DENUNCIA
	var col: Color = COLOR_DNI if tipo == &"dni" else COLOR_DENUNCIA
	var p := PersonaScript.new()
	p.position = POS_ENTRADA
	p.se_fue.connect(_on_persona_se_fue)
	p.empezo_atencion.connect(_on_empezo_atencion)
	p.libera_puesto.connect(_on_libera_puesto)
	_cola.append(p)

	var idx := _primer_asiento_libre()
	var destino: Vector2
	if idx >= 0:
		_asientos_libres[idx] = false
		_asiento_de[p] = idx
		destino = _asientos[idx]
	else:
		_fila.append(p)
		destino = _pos_espera_pie(_fila.size() - 1)
	p.configurar(tipo, dur, col, destino, POS_SALIDA)
	add_child(p)
	_npcs_vivos += 1

func _physics_process(_delta: float) -> void:
	if _estres:
		var creados := 0
		while _npcs_vivos < TOPE_ESTRES and creados < 4:
			_on_generar(&"dni" if RNGService.randf() < 0.5 else &"denuncia")
			creados += 1
		_frames_estres += 1
		if _frames_estres % 60 == 0:
			print("ESTRES  npcs_vivos=%d  fps=%.1f" % [_npcs_vivos, Engine.get_frames_per_second()])
	for pu in _puestos:
		if is_instance_valid(pu) and pu.esta_disponible() and not _cola.is_empty():
			var siguiente = _cola.pop_front()
			if is_instance_valid(siguiente):
				_sacar_de_espera(siguiente)
				pu.asignar_persona(siguiente)

func _sacar_de_espera(persona: Node) -> void:
	if _asiento_de.has(persona):
		var idx: int = _asiento_de[persona]
		_asiento_de.erase(persona)
		_asientos_libres[idx] = true
		if not _fila.is_empty():
			var p2 = _fila.pop_front()
			if is_instance_valid(p2):
				_asientos_libres[idx] = false
				_asiento_de[p2] = idx
				p2.ir_a_espera(_asientos[idx])
			_reordenar_fila()
	else:
		_fila.erase(persona)
		_reordenar_fila()

func _reordenar_fila() -> void:
	for i in _fila.size():
		var p = _fila[i]
		if is_instance_valid(p):
			p.ir_a_espera(_pos_espera_pie(i))

func _on_libera_puesto(persona: Node) -> void:
	for pu in _puestos:
		if is_instance_valid(pu) and pu.atiende_a(persona):
			pu.liberar()
			break

func _on_persona_se_fue(persona: Node) -> void:
	_npcs_vivos -= 1
	for pu in _puestos:
		if is_instance_valid(pu) and pu.atiende_a(persona):
			pu.liberar()
			break

func _on_empezo_atencion(espera_min: float) -> void:
	_espera_total += espera_min
	_atendidos += 1
	_ultima_espera = espera_min
	if _atendidos >= _objetivo and _rango < RANGOS.size() - 1:
		_rango += 1
		_objetivo += OBJETIVO_PASO
		EventBus.ascenso.emit(RANGOS[_rango])

# --- API de lectura para el HUD ---
func en_cola() -> int:
	return _cola.size()

func de_pie() -> int:
	return _fila.size()

func espera_media() -> float:
	return _espera_total / float(_atendidos) if _atendidos > 0 else 0.0

func atendidos() -> int:
	return _atendidos

func num_puestos() -> int:
	return _puestos.size()

func num_agentes() -> int:
	return _agentes.size()

func agentes_asignados() -> int:
	var n := 0
	for ag in _agentes:
		if is_instance_valid(ag) and ag.puesto != null:
			n += 1
	return n

func rango_texto() -> String:
	return RANGOS[_rango]

func objetivo() -> int:
	return _objetivo

func activar_estres() -> void:
	_estres = not _estres

func en_estres() -> bool:
	return _estres

func npcs_vivos() -> int:
	return _npcs_vivos
