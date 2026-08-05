extends "res://tools/render_mobiliario.gd"
## _render_cajonera_soporte — DESECHABLE, fase de PROPUESTA (2026-08-05).
##
## CAMBIO DE PLAN (ver `_render_props_soporte.gd`): la fusión 3D cajonera+aparato en la MISMA
## escena, con un factor de escala derivado analíticamente para las piezas de `props_poly`, dio
## resultados MEDIBLEMENTE mal calibrados (auto-verificación del propio script: alto compuesto
## ~1,25-1,30x el esperado) Y, visualmente, arrastró geometría de las piezas de `props_poly` que
## no encajaba (paneles enormes de fondo en las 3 composiciones -- probable geometría auxiliar de
## esos `.glb` sueltos, no algo que merezca más presupuesto de esta pasada de PROPUESTA).
##
## Plan B (orden del coordinador, "móntalo a tu manera... aparato encima a la altura del tablero,
## un solo PNG resultante"): en vez de fusionar mallas en 3D, se renderiza la cajonera SOLA (una
## pieza, sin problema de unidades: `isometric_office.glb` YA está en metros reales) con el MISMO
## criterio v2 (calibración por altura real, `_render_props_nuevos.gd`) y se compone en 2D con los
## PNG de aparato YA EXISTENTES (que el usuario no objetó en tamaño, solo en falta de soporte) --
## ver `_componer_props_soporte.gd`, que hace el aplanado final a un solo PNG por rotación.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M

const NOMBRE_CAJONERA := "Object_833"
## Misma pieza, mismo dato ya verificado que usa `ID_RADIO` -- ver `render_mobiliario.gd`.
const ALTURA_TAPA_M: float = 0.675


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("[CAJONERA SOPORTE] no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var todas: Dictionary = {}
	for hijo: Node in raiz.find_children(NOMBRE_CAJONERA, "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas[NOMBRE_CAJONERA] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		break
	if todas.is_empty():
		push_error("[CAJONERA SOPORTE] no se encontró %s" % NOMBRE_CAJONERA)
		get_tree().quit(1)
		return

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

	var receta: Dictionary = {"id_salida": "cajonera", "nombres": PackedStringArray([NOMBRE_CAJONERA])}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)

	grupo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var alto_bruto_px: int = _medir_alto(bruto_0["imagen"])
	var objetivo_px: float = ALTURA_TAPA_M * PX_POR_METRO
	var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
	print("[CAJONERA SOPORTE] radio=%.3f m, bruto 0°=%dpx alto -> objetivo=%.2fm (%.1fpx) -> factor=%.4f" % [
		radio, alto_bruto_px, ALTURA_TAPA_M, objetivo_px, escala_pieza
	])

	var brutos: Array[Dictionary] = [bruto_0]
	for rot: int in [90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		brutos.append(await _renderizar_bruto())

	var escalados: Array[Dictionary] = []
	for bruto: Dictionary in brutos:
		escalados.append(_escalar(bruto, escala_pieza))
	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%scajonera_sola_%d.png" % [SALIDA_SCRATCH, ROTACIONES[i]]
		(imagenes[i] as Image).save_png(ruta)
	print("[CAJONERA SOPORTE] guardado -> %scajonera_sola_{0,90,180,270}.png" % SALIDA_SCRATCH)
	print("[CAJONERA SOPORTE] hecho.")
	get_tree().quit()


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
