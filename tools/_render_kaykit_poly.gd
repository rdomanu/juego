extends "res://tools/render_mobiliario.gd"
## _render_kaykit_poly — DESECHABLE (2026-08-06). Render de 5 piezas del pack KayKit local (CC BY,
## ya descargado en `capturas/fuentes/kaykit_restaurant/` y `capturas/fuentes/kaykit_furniture/`)
## para una hoja de ELECCIÓN del usuario -- NO integración. Mismo pipeline que
## `render_props_poly.gd` (cámara/luces/recorte heredados de `render_mobiliario.gd`, ver su
## cabecera): calibración por ALTURA REAL declarada, nunca por la AABB cruda del `.gltf`.
##
## NUEVO respecto a `render_props_poly.gd`: aplica el FACTOR DE PRESENCIA (`design/art/
## plan-escalado.md` §1, decisión del usuario 2026-08-06) -- `objetivo_px = altura_m ×
## PX_POR_METRO × 1,25` -- porque estas piezas compiten visualmente con los muñecos cabezones del
## juego, igual que la fotocopiadora de Summer (primera pieza que ya lo usa).
##
## Los `.gltf` de KayKit YA viven dentro de `res://` (carpetas `capturas/fuentes/kaykit_*`) y YA
## estaban importados (cada uno trae su `.gltf.import`) -- NO hizo falta copiar nada a una carpeta
## temporal nueva.
##
## Escribe SOLO al scratchpad de esta sesión -- NUNCA a `assets/sprites/mobiliario/` (la
## integración real queda pendiente de que el usuario elija variante en la hoja).

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## Mismo ancla de conversión que `render_props_poly.gd`: muñeco `girl` 44px ~ 1,70m real.
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
## Factor de presencia (plan-escalado.md §1, decisión usuario 2026-08-06): +25% sobre la escala
## métrica real para que el mobiliario no lea "enano" junto a los muñecos cabezones.
const FACTOR_PRESENCIA: float = 1.25

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const CARPETA_RESTAURANT := "res://capturas/fuentes/kaykit_restaurant/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/"
const CARPETA_FURNITURE := "res://capturas/fuentes/kaykit_furniture/KayKit_Furniture_Bits_1.0_FREE/Assets/gltf/"

## Cada pieza: `id` (nombre de salida en el scratchpad), `ruta` del `.gltf` de origen y
## `altura_objetivo_m` -- la altura REAL que tendría en el juego (ver informe de la tarea para la
## procedencia de cada cifra).
const MODELOS: Array[Dictionary] = [
	{"id": "kaykit_fridge_A", "ruta": CARPETA_RESTAURANT + "fridge_A.gltf", "altura_objetivo_m": 1.80},
	{"id": "kaykit_fridge_B", "ruta": CARPETA_RESTAURANT + "fridge_B.gltf", "altura_objetivo_m": 1.80},
	{"id": "kaykit_lamp_standing", "ruta": CARPETA_FURNITURE + "lamp_standing.gltf", "altura_objetivo_m": 1.70},
	{"id": "kaykit_lamp_table", "ruta": CARPETA_FURNITURE + "lamp_table.gltf", "altura_objetivo_m": 0.45},
	{"id": "kaykit_table_medium", "ruta": CARPETA_FURNITURE + "table_medium.gltf", "altura_objetivo_m": 0.75},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render.

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


## Carga UN `.gltf` suelto (ya importado dentro de `res://`) y vuelca sus `MeshInstance3D` en
## `todas` con el prefijo `<id>__` -- mismo formato que `render_props_poly.gd::_cargar`.
func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = modelo["ruta"]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[KAYKIT POLY] no se pudo cargar %s" % ruta)
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
	print("[KAYKIT POLY] %s: %d MeshInstance3D cargadas (%s)" % [id, total, ruta])


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

	print("[KAYKIT POLY] px/metro = %.4f (muñeco %.0fpx ~ %.2fm) × factor de presencia %.2f" % [
		PX_POR_METRO, ALTO_MUNECO_PX, ALTO_MUNECO_M, FACTOR_PRESENCIA
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var altura_objetivo_m: float = modelo["altura_objetivo_m"]
		var objetivo_px: float = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[KAYKIT POLY] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° -- define la escala de ESTA pieza por ALTURA REAL × factor de presencia.
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var alto_bruto_px: int = _medir_alto(imagen_0)
		var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
		print("[KAYKIT POLY] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm×%.2f->%.1fpx -> factor=%.4f" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px,
			altura_objetivo_m, FACTOR_PRESENCIA, objetivo_px, escala_pieza
		])

		# 2) Las 4 rotaciones, MISMO factor.
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
				push_error("[KAYKIT POLY] save_png '%s' fallo (error %d)" % [ruta, err])
			var alto_medido: int = _medir_alto(imagenes[i] as Image)
			print("[KAYKIT POLY]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx, |dif|=%.1fpx -> %s)" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, objetivo_px, absf(float(alto_medido) - objetivo_px),
				"PASA" if absf(float(alto_medido) - objetivo_px) <= 3.0 else "FALLA"
			])
		print("[KAYKIT POLY] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, CARPETA_SCRATCH, id])

	print("[KAYKIT POLY] hecho.")
	get_tree().quit()


## El ALTO en píxeles de la silueta opaca de una imagen: fila opaca más alta a fila opaca más
## baja (mismo criterio que `render_props_poly.gd::_medir_alto`, reutiliza `AnclajeSprite`).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[KAYKIT POLY] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
