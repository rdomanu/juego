extends "res://tools/render_mobiliario.gd"
## _render_kaykit_poly2 — DESECHABLE (2026-08-06). SEGUNDA tanda de renders KayKit, correcciones
## del usuario tras ver `hoja_nevera_AB.png`/`hoja_lamparas.png`/`hoja_mesa_trabajo.png`:
##
##  1) `fridge_A` RETINTADA A BLANCO (electrodoméstico, tiradores/detalles en gris) -- por
##     MATERIAL/TEXTURA en el render (`ShaderMaterial` que remapea la LUMINANCIA de la textura
##     original por un umbral: zonas claras del panel -> blanco, zonas oscuras -- ranuras,
##     tiradores, sombreado horneado -- -> gris), NO un filtro de color plano encima del PNG ya
##     recortado.
##  2) `table_medium` RECHAZADA ("es una mesa de revistas/centro", cierto -- huella y altura de
##     mesa auxiliar, no de trabajo). Sus vistas YA renderizadas NO se tocan/borran (quedan de
##     mesita de sala de espera). Candidatas nuevas para "mesa de trabajo": `kitchentable_A` y
##     `kitchentable_B` (`capturas/fuentes/kaykit_restaurant/`), altura de comedor real.
##
## Mismo pipeline y misma calibración (ALTURA REAL × FACTOR_PRESENCIA) que `_render_kaykit_poly.gd`
## -- ver su cabecera. Escribe SOLO al scratchpad de esta sesión.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const CARPETA_RESTAURANT := "res://capturas/fuentes/kaykit_restaurant/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/"

## Retinte "electrodoméstico blanco" -- HISTORIAL DE 2 INTENTOS FALLIDOS con `ShaderMaterial` a
## mano, sustituido por un 3er enfoque más seguro (auditoría del usuario, 2026-08-06, comparación
## ×8 zoom + conteo de píxeles opacos contra el render verde original,
## `tools/_compare_fridge_zoom*.png` del scratchpad):
##  · intento 1: `render_mode blend_mix` -- metía el material en la cola de TRANSPARENCIA (orden
##    por distancia a cámara, no por Z real) -- la puerta se "desaparecía" tras el cuerpo.
##  · intento 2: `cull_back`/`cull_disabled` a mano -- la SILUETA exterior salía IDÉNTICA a la
##    verde (0,00% de diferencia en píxeles opacos, confirmado con `numpy`), pero la CARA que se
##    ve seguía siendo la interior "a rayas" (z-fighting entre la puerta y el hueco del cuerpo,
##    invisible en el material original porque las dos caras compartían el mismo verde -- con el
##    blanco/gris del remapeo, cada cara sale de un tono distinto y el z-fighting se vuelve
##    visible). Reescribir a mano el `render_mode` (cull/blend/profundidad) de un
##    `ShaderMaterial` nuevo es apostar a adivinar la configuración exacta del material original.
##
## SOLUCIÓN (la usada): NO tocar cull/blend/profundidad -- se DUPLICA el material original de
## KayKit tal cual (`Material.duplicate()`, todas sus flags intactas) y se le CAMBIA SOLO
## `albedo_texture` por una copia de la textura del atlas RETINTADA PÍXEL A PÍXEL en la CPU
## (remapeo de luminancia → blanco/gris, mismo criterio que los intentos anteriores, pero ahora
## es un swap de textura sobre el material de siempre, no una reinterpretación de sus flags de
## render). Como el resto del material (cull, depth, blend) es EXACTAMENTE el original, la puerta
## vuelve a comportarse como en el verde -- solo cambia de color.
func _construir_textura_blanca(original: Texture2D) -> ImageTexture:
	var img: Image = original.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var datos: PackedByteArray = img.get_data()
	var salida := PackedByteArray()
	salida.resize(datos.size())
	const TONO_BLANCO := Vector3(0.93, 0.94, 0.96) * 255.0
	const TONO_GRIS := Vector3(0.38, 0.39, 0.42) * 255.0
	const UMBRAL_BAJO := 0.30 * 255.0
	const UMBRAL_ALTO := 0.75 * 255.0
	var i := 0
	while i < datos.size():
		var r: int = datos[i]
		var g: int = datos[i + 1]
		var b: int = datos[i + 2]
		var luminancia: float = 0.299 * r + 0.587 * g + 0.114 * b
		var t: float = clampf((luminancia - UMBRAL_BAJO) / maxf(UMBRAL_ALTO - UMBRAL_BAJO, 1.0), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)  # smoothstep, mismo suavizado que los intentos con shader
		salida[i] = int(lerpf(TONO_GRIS.x, TONO_BLANCO.x, t))
		salida[i + 1] = int(lerpf(TONO_GRIS.y, TONO_BLANCO.y, t))
		salida[i + 2] = int(lerpf(TONO_GRIS.z, TONO_BLANCO.z, t))
		salida[i + 3] = datos[i + 3]
		i += 4
	var nueva: Image = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, salida)
	return ImageTexture.create_from_image(nueva)

## Piezas normales (sin retinte): id de salida, ruta del `.gltf`, altura real objetivo en metros.
const MODELOS_NORMALES: Array[Dictionary] = [
	{"id": "kaykit_kitchentable_A", "ruta": CARPETA_RESTAURANT + "kitchentable_A.gltf", "altura_objetivo_m": 0.75},
	{"id": "kaykit_kitchentable_B", "ruta": CARPETA_RESTAURANT + "kitchentable_B.gltf", "altura_objetivo_m": 0.75},
]
## La pieza RETINTADA: misma altura objetivo que la nevera original (1,80 m), mismo `.gltf`
## `fridge_A`, pero con el material blanco aplicado a CADA `MeshInstance3D` al cargar.
const MODELO_BLANCO: Dictionary = {
	"id": "kaykit_fridge_A_blanca", "ruta": CARPETA_RESTAURANT + "fridge_A.gltf", "altura_objetivo_m": 1.80
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS_NORMALES:
		_cargar(contenedor, modelo, todas, false)
	_cargar(contenedor, MODELO_BLANCO, todas, true)

	var modelos_todos: Array[Dictionary] = MODELOS_NORMALES.duplicate()
	modelos_todos.append(MODELO_BLANCO)
	_ejecutar_kaykit(todas, modelos_todos)


## Carga UN `.gltf`. Si `retintar` es true, cada `MeshInstance3D` recibe una COPIA de su propio
## material activo (`get_active_material`, cull/blend/depth intactos) con `albedo_texture`
## sustituida por la versión retintada (`_construir_textura_blanca`) -- cacheada por `Material`
## de origen (`_cache_blanco`, a nivel de instancia) para no reconstruir la textura 1024×1024 tres
## veces cuando cuerpo+2 puertas comparten el mismo material "restaurant" del atlas.
var _cache_blanco: Dictionary = {}


func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary, retintar: bool) -> void:
	var id: String = modelo["id"]
	var ruta: String = modelo["ruta"]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[KAYKIT POLY 2] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var material_final: Material = null
		var overrides: Array[Material] = []
		if retintar:
			var original: Material = mi.get_active_material(0)
			var clave: int = original.get_instance_id() if original != null else 0
			if _cache_blanco.has(clave):
				material_final = _cache_blanco[clave]
			else:
				var base := original as BaseMaterial3D
				if base == null:
					push_error("[KAYKIT POLY 2] %s: material activo no es BaseMaterial3D, no se puede retintar" % mi.name)
					material_final = original
				else:
					var duplicado := base.duplicate() as BaseMaterial3D
					duplicado.albedo_texture = _construir_textura_blanca(base.albedo_texture)
					material_final = duplicado
				_cache_blanco[clave] = material_final
		else:
			for s: int in mi.mesh.get_surface_count():
				overrides.append(mi.get_surface_override_material(s))
			material_final = mi.material_override
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": material_final,
			"overrides": overrides,
		}
		total += 1
	print("[KAYKIT POLY 2] %s: %d MeshInstance3D cargadas (%s)%s" % [
		id, total, ruta, " -- RETINTADO BLANCO (material duplicado, cull/blend originales intactos)" if retintar else ""
	])


func _nombres_de(todas: Dictionary, id: String) -> PackedStringArray:
	var prefijo: String = id + "__"
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar_kaykit(todas: Dictionary, modelos: Array[Dictionary]) -> void:
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

	print("[KAYKIT POLY 2] px/metro = %.4f × factor de presencia %.2f" % [PX_POR_METRO, FACTOR_PRESENCIA])

	for modelo: Dictionary in modelos:
		var id: String = modelo["id"]
		var altura_objetivo_m: float = modelo["altura_objetivo_m"]
		var objetivo_px: float = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[KAYKIT POLY 2] %s: receta vacía -- se salta" % id)
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
		var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
		print("[KAYKIT POLY 2] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.1fpx -> factor=%.4f" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px, objetivo_px, escala_pieza
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
				push_error("[KAYKIT POLY 2] save_png '%s' fallo (error %d)" % [ruta, err])
			var alto_medido: int = _medir_alto(imagenes[i] as Image)
			print("[KAYKIT POLY 2]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx, |dif|=%.1fpx -> %s)" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, objetivo_px, absf(float(alto_medido) - objetivo_px),
				"PASA" if absf(float(alto_medido) - objetivo_px) <= 3.0 else "FALLA"
			])
		print("[KAYKIT POLY 2] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, CARPETA_SCRATCH, id])

	print("[KAYKIT POLY 2] hecho.")
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
		push_warning("[KAYKIT POLY 2] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
