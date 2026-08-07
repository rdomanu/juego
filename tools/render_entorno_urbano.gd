extends "res://tools/render_mobiliario.gd"
## RenderEntornoUrbano — sprites de PROPS de `EntornoExterior` (2026-08-07, feedback de playtest:
## "no hay vida, el recinto es inexistente" -- reforma 3 "VIDA").
##
## Mismo pipeline que `render_props_poly.gd`/`_render_kaykit_poly.gd` (cámara/luces/recorte
## heredados de `render_mobiliario.gd`): calibración por ALTURA REAL declarada, nunca por la AABB
## cruda del `.glb`. Aplica el FACTOR DE PRESENCIA de `_render_kaykit_poly.gd`
## (`design/art/plan-escalado.md` §1) -- `objetivo_px = altura_m × PX_POR_METRO × 1,25` -- misma
## regla que ya usan las piezas que compiten visualmente con los muñecos cabezones del juego. Esta
## es la fórmula que fija el informe del encargo: "escala px = m × 25,88 × 1,25".
##
## Fuentes:
##  · `capturas/fuentes/biblioteca_summer/` (árbol, seto, farola -- biblioteca pública Summer,
##    gratis, ya importados).
##  · `capturas/fuentes/kenney_carkit/extracted/Models/GLB format/` (coche patrulla + 2 turismos de
##    visita -- CC0, ya importados; PROHIBIDOS tractores/camiones del mismo kit).
##
## Salida: `assets/sprites/entorno/<id>_<rot>.png`, 4 rotaciones por pieza (yaw 0/90/180/270°) --
## árbol/seto/farola usarán solo la 0° en el juego (piezas sin frente marcado), los coches usan las
## 4 para orientarse en su plaza/calle.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## Mismo ancla de conversión que el resto de pipelines 3D->sprite del proyecto: muñeco `girl` 44px
## ~ 1,70m real.
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
## Factor de presencia (`_render_kaykit_poly.gd`, `design/art/plan-escalado.md` §1): +25% sobre la
## escala métrica real -- la fórmula del encargo, "escala px = m × 25,88 × 1,25".
const FACTOR_PRESENCIA: float = 1.25

const SALIDA_ENTORNO := "res://assets/sprites/entorno/"

const CARPETA_SUMMER := "res://capturas/fuentes/biblioteca_summer/"
const CARPETA_CARKIT := "res://capturas/fuentes/kenney_carkit/extracted/Models/GLB format/"
## Casas completas del pack "City Kit Suburban" (Kenney, CC0) -- 2026-08-07, mejora del material:
## los edificios vecinos sueltos usan casas YA HECHAS en vez de cajas con tejado por código.
const CARPETA_SUBURBAN := "res://capturas/fuentes/kenney_suburban/Models/GLB format/"
## Kit de carreteras (Kenney, CC0) -- 2026-08-07, doctrina "todo es asset, nada por código": la
## calzada/acera de la calle de acceso usan piezas de este kit en vez de rectángulos pintados.
const CARPETA_ROADS := "res://capturas/fuentes/kenney_roads/Models/GLB format/"

## Cada pieza: `id` (nombre de salida), `ruta` del `.glb` de origen, y UNA de las dos calibraciones:
##  · `altura_objetivo_m` -- para piezas con volumen vertical real (casas, coches, farola, seto,
##    árboles, valla): escala por ALTURA REAL × factor de presencia, midiendo el ALTO de la
##    silueta en bruto (ver la cabecera del fichero).
##  · `ancho_objetivo_celdas` -- para piezas CASI PLANAS (camino, calzada, acera, entrada de casa):
##    calibrar por altura sería frágil (una losa de unos pocos cm de grosor da una silueta minúscula
##    y ruidosa) -- en su lugar se mide el ANCHO de la silueta en bruto y se fuerza a que ocupe
##    exactamente `ancho_objetivo_celdas × Proyeccion.ANCHO_ROMBO` px, que es la huella real de la
##    pieza en la rejilla isométrica del juego (80 px = 1 celda de ancho de rombo).
##  · `longitud_objetivo_m` -- SOLO para los coches (2026-08-07, encargo "los coches ocupan MÍNIMO 3
##    celdas; la mesa ocupa 2 y un coche es más grande"). Calibrar un coche por ALTURA (como el resto
##    de piezas con volumen) da un resultado demasiado pequeño: el kit Kenney low-poly es "achaparrado"
##    a propósito (estilo cartoon) y su alto real NO guarda la proporción alto:largo de un coche real.
##    Igual que `ancho_objetivo_celdas`, este modo mide el ANCHO de la silueta en bruto a 0°, pero el
##    objetivo sale de METROS × la misma conversión px/metro × factor de presencia que `altura_objetivo_m`.
##    ⚠️ ESTE NÚMERO **NO ES el largo real del coche en metros** -- con la cámara isométrica a yaw 45°
##    el "ancho en bruto" de un coche mide una combinación de su largo y su ancho, Y ADEMÁS
##    `AnclajeSprite.semiejes_base` (la medida que de verdad importa: es la que usa el JUEGO para
##    anclar cada prop) mide el CONTORNO INFERIOR de la silueta, que en un coche con guardabarros/
##    parachoques queda por debajo de la huella "de caja" que asume esa función -- las dos cosas
##    juntas hacen que la huella medida en celdas no coincida con la aritmética ingenua de arriba.
##    ⚠️ GOTCHA DE ESTA MISMA TAREA: `load()` desde `--headless --script` (fuera del editor) devuelve
##    el PNG CACHEADO en `.godot/imported/` si ya existía uno -- un re-render que SOBRESCRIBE el
##    archivo en disco NO invalida ese caché por sí solo. Los dos primeros intentos de esta tarea
##    midieron sin querer la MISMA imagen vieja cacheada (ninguno de los cambios de arriba se estaba
##    viendo) y llevaron el número a un exceso absurdo (13,8-19,1 m -> 9-11 celdas reales). El PASO
##    OBLIGATORIO antes de medir: `godot --headless --path <proyecto> --import` (reimporta todo y
##    sale) SIEMPRE después de un re-render, antes de volver a medir con
##    `tools/_diag_medir_coches.gd`. Con el caché ya limpio, estos tres valores (una REGLA DE TRES
##    empírica sobre la medida real, mismo método que `MULTIPLICADOR_MOSTRADOR1`/`MULTIPLICADOR_SOFA3`
##    de `render_mobiliario.gd`) dan una huella de ~3,2-3,6 celdas de largo -- verificado en el motor
##    (intento 3 de 3, con el `--import` de por medio).
##
## Las 5 casas (tipos a/d/g/k/o -- variedad de fachada dentro del abecedario a..u del pack) llevan
## una altura ESCALONADA (6,0-8,0 m) a propósito: "elige 4-5 tipos variados" -- sin poder abrir cada
## `.glb` a mano en el visor, escalonar la altura objetivo por tipo da variedad de silueta (una
## planta baja / planta y media / dos plantas) sin arriesgar a que las 5 salgan idénticas de tamaño.
##
## `valla_baja`/`valla_estandar`: las DOS candidatas para la tapia del recinto (`fence-low.glb` vs
## `fence.glb`) -- se renderizan las dos y se decide cuál se usa mirando el PNG (ver el informe),
## sin gastar una segunda pasada de render si hay que cambiar de opinión.
##
## `TEST_metro_corner`: pieza de EVALUACIÓN (candidato del usuario, `metro_street_corner.glb`,
## realista PBR) -- se renderiza para comparar su estilo contra el low-poly Kenney con evidencia,
## NO para usarla necesariamente en el juego (ver el informe, veredicto).
const MODELOS: Array[Dictionary] = [
	{"id": "arbol_urbano", "ruta": CARPETA_SUMMER + "arbol_urbano.glb", "altura_objetivo_m": 4.5},
	{"id": "seto", "ruta": CARPETA_SUMMER + "seto.glb", "altura_objetivo_m": 0.8},
	{"id": "farola", "ruta": CARPETA_SUMMER + "farola.glb", "altura_objetivo_m": 4.0},
	{"id": "coche_policia", "ruta": CARPETA_CARKIT + "police.glb", "longitud_objetivo_m": 4.8},
	{"id": "coche_sedan", "ruta": CARPETA_CARKIT + "sedan.glb", "longitud_objetivo_m": 5.3},
	{"id": "coche_suv", "ruta": CARPETA_CARKIT + "suv.glb", "longitud_objetivo_m": 5.6},
	{"id": "casa_a", "ruta": CARPETA_SUBURBAN + "building-type-a.glb", "altura_objetivo_m": 6.0},
	{"id": "casa_d", "ruta": CARPETA_SUBURBAN + "building-type-d.glb", "altura_objetivo_m": 6.5},
	{"id": "casa_g", "ruta": CARPETA_SUBURBAN + "building-type-g.glb", "altura_objetivo_m": 7.0},
	{"id": "casa_k", "ruta": CARPETA_SUBURBAN + "building-type-k.glb", "altura_objetivo_m": 7.5},
	{"id": "casa_o", "ruta": CARPETA_SUBURBAN + "building-type-o.glb", "altura_objetivo_m": 8.0},
	{"id": "valla_baja", "ruta": CARPETA_SUBURBAN + "fence-low.glb", "altura_objetivo_m": 1.2},
	{"id": "valla_estandar", "ruta": CARPETA_SUBURBAN + "fence.glb", "altura_objetivo_m": 1.5},
	{"id": "camino_recinto", "ruta": CARPETA_SUBURBAN + "path-short.glb", "ancho_objetivo_celdas": 1.0},
	{"id": "entrada_casa", "ruta": CARPETA_SUBURBAN + "driveway-short.glb", "ancho_objetivo_celdas": 1.0},
	{"id": "planter", "ruta": CARPETA_SUBURBAN + "planter.glb", "altura_objetivo_m": 0.6},
	{"id": "tree_grande", "ruta": CARPETA_SUBURBAN + "tree-large.glb", "altura_objetivo_m": 5.0},
	{"id": "tree_pequeno", "ruta": CARPETA_SUBURBAN + "tree-small.glb", "altura_objetivo_m": 3.0},
	{"id": "calzada_recta", "ruta": CARPETA_ROADS + "road-straight.glb", "ancho_objetivo_celdas": 2.0},
	{"id": "acera_recta", "ruta": CARPETA_ROADS + "road-side.glb", "ancho_objetivo_celdas": 1.0},
	{
		"id": "TEST_metro_corner", "ruta": CARPETA_SUMMER + "metro_street_corner.glb",
		"altura_objetivo_m": 9.0,
	},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA_ENTORNO))

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render.

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


## Carga UN `.glb` suelto (ya importado dentro de `res://`) y vuelca sus `MeshInstance3D` en
## `todas` con el prefijo `<id>__` -- mismo formato que `render_props_poly.gd::_cargar`.
func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = modelo["ruta"]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[ENTORNO URBANO] no se pudo cargar %s" % ruta)
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
	print("[ENTORNO URBANO] %s: %d MeshInstance3D cargadas (%s)" % [id, total, ruta])


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

	print("[ENTORNO URBANO] px/metro = %.4f (muñeco %.0fpx ~ %.2fm) x factor de presencia %.2f" % [
		PX_POR_METRO, ALTO_MUNECO_PX, ALTO_MUNECO_M, FACTOR_PRESENCIA
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var por_ancho: bool = modelo.has("ancho_objetivo_celdas")
		var por_longitud: bool = modelo.has("longitud_objetivo_m")
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[ENTORNO URBANO] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° -- define la escala de ESTA pieza. Piezas con volumen (altura_objetivo_m):
		# por ALTURA REAL x factor de presencia. Piezas casi planas (ancho_objetivo_celdas): por el
		# ANCHO de su huella en la rejilla -- ver la cabecera de `MODELOS`.
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var objetivo_px: float
		var medido_bruto_px: int
		var escala_pieza: float
		if por_ancho:
			var ancho_celdas: float = modelo["ancho_objetivo_celdas"]
			objetivo_px = ancho_celdas * float(Proyeccion.ANCHO_ROMBO)
			medido_bruto_px = _medir_ancho(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx), objetivo=%.2f celdas->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				ancho_celdas, objetivo_px, escala_pieza
			])
		elif por_longitud:
			# Ver la cabecera de `MODELOS`: mismo mecanismo que `ancho_objetivo_celdas` (mide el ANCHO
			# de la silueta en bruto), pero el objetivo sale de METROS REALES x la conversión
			# px/metro x factor de presencia -- la MISMA escala que usan el resto de piezas con volumen
			# -- en vez de celdas de rejilla.
			var longitud_m: float = modelo["longitud_objetivo_m"]
			objetivo_px = longitud_m * PX_POR_METRO * FACTOR_PRESENCIA
			medido_bruto_px = _medir_ancho(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx), objetivo=%.2fm->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				longitud_m, objetivo_px, escala_pieza
			])
		else:
			var altura_objetivo_m: float = modelo["altura_objetivo_m"]
			objetivo_px = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
			medido_bruto_px = _medir_alto(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm×%.2f->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
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
			var ruta: String = "%s%s_%d.png" % [SALIDA_ENTORNO, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ProjectSettings.globalize_path(ruta))
			if err != OK:
				push_error("[ENTORNO URBANO] save_png '%s' fallo (error %d)" % [ruta, err])
			var alto_medido: int = _medir_alto(imagenes[i] as Image)
			print("[ENTORNO URBANO]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx)" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, objetivo_px
			])
		print("[ENTORNO URBANO] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, SALIDA_ENTORNO, id])

	print("[ENTORNO URBANO] hecho.")
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
		push_warning("[ENTORNO URBANO] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


## El ANCHO en píxeles de la silueta opaca: columna opaca más a la izquierda a columna opaca más
## a la derecha -- para piezas CASI PLANAS (`ancho_objetivo_celdas`), ver la cabecera de `MODELOS`.
func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	for px: int in range(ancho):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			min_x = px
			break
	if min_x < 0:
		push_warning("[ENTORNO URBANO] silueta totalmente transparente")
		return ancho
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			max_x = px
			break
	return max_x - min_x + 1
