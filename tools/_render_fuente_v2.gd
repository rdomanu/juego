extends "res://tools/render_mobiliario.gd"
## _render_fuente_v2 — DESECHABLE, fase de PROPUESTA (2026-08-05).
##
## Corrige el feedback 3c del usuario: "Fuente de agua: medidas de ORIGEN (la reescalada a 1,20 m
## se ve pequeña -- recuperar la proporción original del modelo)". `fuente_agua.glb` tiene
## unidades rotas (AABB de 3,95 m "en bruto", ver `capturas/fuentes/props_poly/mapeo-fuentes.md`)
## así que "medidas de origen" no se puede tomar LITERAL (el número en bruto no es de fiar) --
## se prueban DOS alturas candidatas más ALTAS que el 1,20 m descartado (que el propio criterio de
## `_render_props_nuevos.gd` ya identificó como "dispensador de pie BAJO"; el usuario pide más
## esbelto) y se elige a ojo cuál casa mejor con un dispensador de oficina real junto al muñeco de
## 44 px. Mismo pipeline de calibración por altura que `_render_props_nuevos.gd` v2 (bypassa las
## unidades rotas midiendo píxeles del render en bruto, no el AABB) -- ver su cabecera.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const CARPETA_ORIGEN := "res://capturas/fuentes/props_poly/"
const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M

const ID := "fuente_agua"
## Candidatas a probar (usuario: "prueba 1,5 y 1,6"). La ganadora se copia además con el nombre
## final SIN sufijo (`fuente_agua_v2_<rot>.png`) para que la hoja v3 la use directo.
const ALTURAS_CANDIDATAS: Array[Dictionary] = [
	{"sufijo": "150", "altura_m": 1.50},
	{"sufijo": "160", "altura_m": 1.60},
]
## Ganadora (rellenar tras comparar visualmente -- ver el informe). Si queda vacío, no se copia
## ninguna a `fuente_agua_v2_<rot>.png` (hay que elegir a mano y relanzar, o copiar el PNG bueno).
const SUFIJO_GANADOR := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var ruta: String = "%s%s.glb" % [CARPETA_ORIGEN, ID]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[FUENTE V2] no se pudo cargar %s" % ruta)
		get_tree().quit(1)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var todas: Dictionary = {}
	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [ID, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[FUENTE V2] %s: %d MeshInstance3D cargadas" % [ID, total])

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

	var nombres := PackedStringArray(todas.keys())
	var receta: Dictionary = {"id_salida": ID, "nombres": nombres}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)

	grupo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var imagen_0: Image = bruto_0["imagen"]
	var alto_bruto_px: int = _medir_alto(imagen_0)
	print("[FUENTE V2] radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx)" % [
		radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px
	])

	var brutos: Array[Dictionary] = [bruto_0]
	for rot: int in [90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		brutos.append(await _renderizar_bruto())

	for candidata: Dictionary in ALTURAS_CANDIDATAS:
		var sufijo: String = candidata["sufijo"]
		var altura_objetivo_m: float = candidata["altura_m"]
		var objetivo_px: float = altura_objetivo_m * PX_POR_METRO
		var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
		print("[FUENTE V2] candidata %sm (sufijo %s): objetivo=%.1fpx -> factor=%.4f" % [
			altura_objetivo_m, sufijo, objetivo_px, escala_pieza
		])

		var escalados: Array[Dictionary] = []
		for bruto: Dictionary in brutos:
			escalados.append(_escalar(bruto, escala_pieza))
		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta_salida: String = "%s%s_v2_%s_%d.png" % [SALIDA_SCRATCH, ID, sufijo, ROTACIONES[i]]
			(imagenes[i] as Image).save_png(ruta_salida)
			if sufijo == SUFIJO_GANADOR:
				var ruta_final: String = "%s%s_v2_%d.png" % [SALIDA_SCRATCH, ID, ROTACIONES[i]]
				(imagenes[i] as Image).save_png(ruta_final)
		print("[FUENTE V2] %sm: guardado -> %s%s_v2_%s_{0,90,180,270}.png" % [altura_objetivo_m, SALIDA_SCRATCH, ID, sufijo])

	if SUFIJO_GANADOR != "":
		print("[FUENTE V2] ganadora (sufijo %s) copiada también como %s%s_v2_{0,90,180,270}.png" % [SUFIJO_GANADOR, SALIDA_SCRATCH, ID])

	print("[FUENTE V2] hecho.")
	get_tree().quit()


## Copiado de `_render_props_nuevos.gd::_medir_alto` (misma razón: herramientas desechables, sin
## acoplarlas entre sí).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[FUENTE V2] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
