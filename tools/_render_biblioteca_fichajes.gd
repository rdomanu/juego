extends "res://tools/render_mobiliario.gd"
## _render_biblioteca_fichajes — DESECHABLE (2026-08-06). Renderiza los 3 fichajes de la
## biblioteca gratis de Summer (`capturas/fuentes/biblioteca_summer/`) a escala de juego:
## `escritorio_trabajo.glb`, `silla_oficina.glb`, `vending_nueva.glb`. 4 rotaciones cada uno.
##
## Mismo pipeline que `_render_mesa_ventanilla_lote.gd`/`_render_fuente_agua_160.gd (cámara/luces/
## entorno heredados de `render_mobiliario.gd`, calibración por ALTURA REAL con el FACTOR DE
## PRESENCIA ×1,25 -- `design/art/plan-escalado.md` §1: px = metros × 25,882 × 1,25).
##
## Cada pieza declara su MODO de calibración:
##  - "ancho": calibra por el ANCHO de la silueta (huella de mobiliario con footprint fijo en
##    celdas -- mismo criterio que `_render_mesa_ventanilla_lote.gd`, la huella domina la
##    silueta isométrica de un mueble bajo y ancho, forzar el alto lo subescala).
##  - "alto": calibra por el ALTO de la silueta (aparato/mueble suelto sin huella fija -- mismo
##    criterio que `_render_fuente_agua_160.gd`/`render_props_poly.gd`).
##
## `escritorio_trabajo`: medido con `_diag_biblioteca_footprint.gd` -- AABB planta x=0,709m
## z=0,697m, ratio 1,017 (prácticamente CUADRADO, <1,3) -> huella 1x1 celda, ancho objetivo 29px
## (decisión del encargo, no derivada de `ESCALA_OBJETIVO_MOSTRADOR`: ese 0,92 es para el
## mostrador de referencia, un mueble mucho más grande -- este escritorio interno es compacto).
##
## Escribe SOLO al scratchpad de esta sesión -- PROHIBIDO tocar `assets/sprites/mobiliario/`
## (fichaje, no integración: audita primero Summer/el usuario, integra después otro encargo).

const CARPETA_ORIGEN := "res://capturas/fuentes/biblioteca_summer/"
const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25

## Un modelo por fila. `modo`="ancho": `objetivo_px` es el ancho de silueta buscado (footprint
## fijo). `modo`="alto": `objetivo_px` se CALCULA de `altura_m * PX_POR_METRO * FACTOR_PRESENCIA`
## (no se escribe a mano, para que quede trazado el metro real detrás del pixel).
const MODELOS: Array[Dictionary] = [
	{"id": "escritorio_trabajo", "archivo": "escritorio_trabajo.glb", "modo": "ancho", "objetivo_px": 58.0, "celdas_footprint": 2},
	{"id": "silla_oficina", "archivo": "silla_oficina.glb", "modo": "alto", "altura_m": 1.00, "celdas_footprint": 1},
	{"id": "vending_nueva", "archivo": "vending_nueva.glb", "modo": "alto", "altura_m": 1.83, "celdas_footprint": 1},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = CARPETA_ORIGEN + (modelo["archivo"] as String)
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[BIBLIOTECA] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[BIBLIOTECA] %s: %d MeshInstance3D cargadas" % [id, total])


func _nombres_de(todas: Dictionary, id: String) -> PackedStringArray:
	var prefijo: String = id + "__"
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar(todas: Dictionary) -> void:
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

	print("[BIBLIOTECA] px/metro base = %.4f, factor presencia = %.2f -> efectivo = %.4f" % [
		PX_POR_METRO, FACTOR_PRESENCIA, PX_POR_METRO * FACTOR_PRESENCIA
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var modo: String = modelo["modo"]
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[BIBLIOTECA] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var alto_bruto_px: int = _medir_alto(imagen_0)
		var ancho_bruto_px: int = _medir_ancho(imagen_0)

		var objetivo_px: float
		var criterio: String
		if modo == "ancho":
			objetivo_px = modelo["objetivo_px"]
			criterio = "ANCHO"
		else:
			var altura_m: float = modelo["altura_m"]
			objetivo_px = altura_m * PX_POR_METRO * FACTOR_PRESENCIA
			criterio = "ALTO (%.2fm)" % altura_m

		var medida_bruta: int = ancho_bruto_px if modo == "ancho" else alto_bruto_px
		var escala_pieza: float = objetivo_px / float(maxi(medida_bruta, 1))
		print("[BIBLIOTECA] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx, ancho silueta=%dpx), CALIBRA POR %s -> objetivo=%.2fpx -> factor=%.4f" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px, ancho_bruto_px,
			criterio, objetivo_px, escala_pieza
		])

		var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
		for rot: int in [90, 180, 270]:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			escalados.append(_escalar(bruto, escala_pieza))

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		var ancla_final: Vector2 = compuesto["ancla"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[BIBLIOTECA] save_png '%s' fallo (error %d)" % [ruta, err])
			var img: Image = imagenes[i] as Image
			var ancho_medido: int = _medir_ancho(img)
			var alto_medido: int = _medir_alto(img)
			var medida_final: int = ancho_medido if modo == "ancho" else alto_medido
			var dif: float = absf(float(medida_final) - objetivo_px)
			print("[BIBLIOTECA]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto_util=%dpx, ancho_util=%dpx, |dif vs objetivo %s|=%.1fpx -> %s" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, ancho_medido, criterio, dif,
				"PASA" if dif <= 3.0 else "FALLA"
			])
		print("[BIBLIOTECA] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, CARPETA_SCRATCH, id])

	print("[BIBLIOTECA] hecho.")
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


func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	var max_x := -1
	for px: int in range(ancho):
		if _columna_opaca(imagen, px, alto):
			if min_x < 0:
				min_x = px
			max_x = px
	if min_x < 0:
		return ancho
	return max_x - min_x + 1


func _fila_opaca(imagen: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false


func _columna_opaca(imagen: Image, px: int, alto: int) -> bool:
	for py: int in range(alto):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false
