extends "res://tools/render_mobiliario.gd"
## _render_monitor_unico — DESECHABLE (2026-08-07). Renderiza SOLO el monitor individual de
## OBJ_021 (`NOMBRES_MONITOR` = Object_851..854, ya identificado y documentado en
## `render_mobiliario.gd`) para el bloque MEDIA -- el usuario pidió una pantalla INDIVIDUAL que no
## asome por encima de la mampara (el `comodidad_equipo_informatico` son 2 pantallas gemelas,
## demasiado altas). MISMO pipeline/cámara que el padre. 4 rotaciones, calibrado por ALTURA real
## de un monitor de oficina (~0,35 m -> con presencia ~14 px, criterio análogo a `crt_antiguo`).
##
## Escribe SOLO al scratchpad -- PROHIBIDO tocar assets/sprites/mobiliario/.

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const ID_SALIDA := "monitor_unico"
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25
const ALTURA_OBJETIVO_M: float = 0.35


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("[MONITOR UNICO] no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return
	var contenedor := Node3D.new()
	add_child(contenedor)
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	contenedor.visible = false
	var todas: Dictionary = _recopilar_instancias(modelo)
	_ejecutar_monitor(todas)


func _ejecutar_monitor(todas: Dictionary) -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)
	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)
	var grupo := Node3D.new()
	mundo.add_child(grupo)

	var receta: Dictionary = {"id_salida": ID_SALIDA, "nombres": NOMBRES_MONITOR}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)

	var objetivo_px: float = ALTURA_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA
	grupo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var imagen_0: Image = bruto_0["imagen"]
	var alto_bruto: int = _medir_alto(imagen_0)
	var escala: float = objetivo_px / float(maxi(alto_bruto, 1))
	print("[MONITOR UNICO] radio=%.3f bruto=%dx%d alto_silueta=%d objetivo=%.2fpx factor=%.4f" % [
		radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto, objetivo_px, escala
	])

	var escalados: Array[Dictionary] = [_escalar(bruto_0, escala)]
	for rot: int in [90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		escalados.append(_escalar(bruto, escala))

	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, ID_SALIDA, ROTACIONES[i]]
		(imagenes[i] as Image).save_png(ruta)
		var img: Image = imagenes[i] as Image
		print("[MONITOR UNICO]   %s_%d.png: %dx%d px -> %s" % [ID_SALIDA, ROTACIONES[i], img.get_width(), img.get_height(), ruta])

	print("[MONITOR UNICO] hecho.")
	get_tree().quit()


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if _fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if _fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


func _fila_opaca(imagen: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false
