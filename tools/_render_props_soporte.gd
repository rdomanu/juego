extends "res://tools/render_mobiliario.gd"
## _render_props_soporte — DESECHABLE, fase de PROPUESTA (2026-08-05).
##
## Corrige el feedback 3c del usuario: "la mesa con los 3 aparatos encima: demasiado y
## desordenado -- cada aparato de sobremesa con su soporte propio (precedente de la radio con
## mesita horneada)". `ID_RADIO` (ver `render_mobiliario.gd` línea ~366) ya resolvió EXACTAMENTE
## este mismo problema para OBJ_038 horneando el aparato sobre la cajonera del escritorio
## (`Object_833`, pack `isometric_office.glb`) -- este script repite la misma receta para
## cafetera/impresora/television, que viven en `.glb` SUELTOS de `capturas/fuentes/props_poly/`
## (mismo problema de unidades rotas que `_render_props_nuevos.gd` v2, ver su cabecera).
##
## ── EL PROBLEMA A RESOLVER: DOS FUENTES A ESCALAS DISTINTAS EN LA MISMA ESCENA ─────────────────
## `Object_833` (cajonera) viene YA en metros reales de verdad (todo `isometric_office.glb` está
## calibrado contra la rejilla del juego -- ver la cabecera de `render_mobiliario.gd`). Los `.glb`
## de `props_poly` NO (unidades rotas, ver `_render_props_nuevos.gd`). No basta con la corrección
## v2 (un factor de REESCALADO DE IMAGEN 2D, calibrado contra un encuadre de cámara que ES PROPIO
## de cada pieza aislada) porque aquí las dos piezas van en la MISMA imagen: hace falta un factor
## de escala 3D real, aplicado a la MALLA, antes de fotografiar el conjunto con una única cámara.
##
## Ese factor SÍ se puede derivar de los mismos números que v2 ya calcula (altura objetivo, alto
## en píxeles del render en bruto, radio de encuadre), porque la cámara ortográfica de
## `_colocar_camara` fija `size = tam_mundo` sobre un lienzo de `TAM_RENDER` px -- es decir,
## `alto_bruto_px = altura_silueta_unidades_crudas * TAM_RENDER / (radio_bruto * 2 * MARGEN)`.
## El cociente `altura_silueta/radio_bruto` es ADIMENSIONAL (no depende de qué unidad arbitraria
## use el `.glb`, solo de la PROPORCIÓN real de la pieza -- confirmado por
## `mapeo-fuentes.md`: los "unidades rotas" documentados son un escalado DE NODO uniforme, o sea
## isótropo, no una distorsión de forma). De ahí sale, despejando:
##   `escala_3d = altura_objetivo_m * K / (alto_bruto_px * radio_bruto)`,  `K = TAM_RENDER/(2*MARGEN)`
## un factor que SÍ se puede aplicar directamente a la `Transform3D` cruda de la pieza (escalado
## isótropo `basis * escala_3d`) para que, mezclada con `Object_833` en la MISMA escena 3D, salga
## a su tamaño real correcto -- sin tocar la cámara final hasta tener las dos piezas ya en la
## misma unidad.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const CARPETA_ORIGEN := "res://capturas/fuentes/props_poly/"
const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## `K` de la cabecera: px por (radio_bruto) de encuadre, constante para TODA pasada de este
## pipeline (mismos `TAM_RENDER`/`MARGEN` que `render_mobiliario.gd`).
const K_ENCUADRE: float = TAM_RENDER / (2.0 * MARGEN)

## La pieza de soporte: la cajonera del escritorio, MISMA que usa `ID_RADIO` (ver
## `render_mobiliario.gd`, comentario de `DESPLAZAMIENTO_RADIO`) -- "ya medida y verificada: tapa
## a Y=0,675, centro X=-9,1105, Z=0,794". Reutilizada tal cual, sin remedir: es el precedente
## exacto que pide el usuario ("de la radio con mesita horneada").
const NOMBRE_CAJONERA := "Object_833"
const CENTRO_TAPA_CAJONERA := Vector3(-9.1105, 0.675, 0.794)

## Los 3 aparatos de sobremesa (misma `altura_objetivo_m` que ya usaba `_render_props_nuevos.gd` v2
## -- el usuario no se quejó del TAMAÑO del aparato en sí, solo de que estuvieran amontonados sin
## soporte propio).
const ITEMS: Array[Dictionary] = [
	{"id": "cafetera", "altura_objetivo_m": 0.45},
	{"id": "impresora", "altura_objetivo_m": 0.50},
	{"id": "television", "altura_objetivo_m": 0.60},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	var todas_cajonera: Dictionary = _cargar_cajonera(contenedor)
	if todas_cajonera.is_empty():
		push_error("[PROPS SOPORTE] no se encontró %s en el pack de oficina -- abortando" % NOMBRE_CAJONERA)
		get_tree().quit(1)
		return

	var todas_por_item: Dictionary = {}  # id -> {nombre_pieza -> {malla,transform,...}} (SIN prefijo, crudo)
	for item: Dictionary in ITEMS:
		var id: String = item["id"]
		todas_por_item[id] = _cargar_pieza_suelta(contenedor, id)

	_preparar_escenario()

	# ── FASE A: calibración -- una a una, aislada, mismo criterio que `_render_props_nuevos.gd` v2,
	# pero derivando un factor 3D (`escala_3d`) en vez de un reescalado de imagen. ────────────────
	var escalas_3d: Dictionary = {}  # id -> float
	for item: Dictionary in ITEMS:
		var id: String = item["id"]
		var altura_objetivo_m: float = item["altura_objetivo_m"]
		var piezas: Dictionary = todas_por_item[id]
		var nombres := PackedStringArray(piezas.keys())
		if nombres.is_empty():
			push_warning("[PROPS SOPORTE] %s: sin piezas -- se salta" % id)
			continue
		var receta_bruto: Dictionary = {"id_salida": id, "nombres": nombres}
		var ancla_bruto: Vector3 = _ancla_de(receta_bruto, piezas)
		var radio_bruto: float = _radio_de(receta_bruto, piezas, ancla_bruto)

		_montar_receta(_grupo_calib, receta_bruto, piezas, ancla_bruto)
		_colocar_camara(radio_bruto * 2.0 * MARGEN)
		var bruto: Dictionary = await _renderizar_bruto()
		var alto_bruto_px: int = _medir_alto(bruto["imagen"])

		var escala_3d: float = (altura_objetivo_m * K_ENCUADRE) / (float(alto_bruto_px) * radio_bruto)
		escalas_3d[id] = escala_3d
		# guardamos también el ancla/radio para la fase B (evita repetir _ancla_de/_radio_de).
		todas_por_item[id + "__ancla_bruto"] = ancla_bruto
		print("[PROPS SOPORTE] %s: radio_bruto=%.4f, alto_bruto=%dpx, objetivo=%.2fm -> escala_3d=%.5f" % [
			id, radio_bruto, alto_bruto_px, altura_objetivo_m, escala_3d
		])

	# ── FASE B: compone cajonera (metros reales) + aparato (reescalado a metros reales con
	# `escala_3d`, reposicionado con base en `CENTRO_TAPA_CAJONERA`) en UNA receta por aparato,
	# con una ÚNICA cámara compartida por las 3 (mismo criterio "cámara fija de la pasada" que
	# `_ejecutar` del padre). ─────────────────────────────────────────────────────────────────────
	var recetas_combo: Dictionary = {}  # id -> {"todas":Dictionary, "receta":Dictionary, "ancla":Vector3, "radio":float}
	var radio_max := 0.0
	for item: Dictionary in ITEMS:
		var id: String = item["id"]
		if not escalas_3d.has(id):
			continue
		var escala_3d: float = escalas_3d[id]
		var ancla_bruto: Vector3 = todas_por_item[id + "__ancla_bruto"]
		var piezas: Dictionary = todas_por_item[id]

		var todas_combo: Dictionary = {"cajonera__%s" % NOMBRE_CAJONERA: todas_cajonera[NOMBRE_CAJONERA]}
		var nombres_combo := PackedStringArray(["cajonera__%s" % NOMBRE_CAJONERA])
		for nombre: String in piezas.keys():
			var it: Dictionary = piezas[nombre]
			var t: Transform3D = it["transform"]
			var nuevo_basis: Basis = t.basis * escala_3d
			var nuevo_origen: Vector3 = CENTRO_TAPA_CAJONERA + (t.origin - ancla_bruto) * escala_3d
			var clave := "aparato__%s" % nombre
			todas_combo[clave] = {
				"malla": it["malla"],
				"transform": Transform3D(nuevo_basis, nuevo_origen),
				"material_override": it.get("material_override"),
				"overrides": it.get("overrides", []),
			}
			nombres_combo.append(clave)

		var receta: Dictionary = {"id_salida": "%s_soporte" % id, "nombres": nombres_combo}
		var ancla: Vector3 = _ancla_de(receta, todas_combo)
		var radio: float = _radio_de(receta, todas_combo, ancla)
		radio_max = maxf(radio_max, radio)
		recetas_combo[id] = {"todas": todas_combo, "receta": receta, "ancla": ancla, "radio": radio}

	var tam_camara: float = radio_max * 2.0 * MARGEN
	_colocar_camara(tam_camara)
	print("[PROPS SOPORTE] cámara fija compartida (3 composiciones): radio_max=%.4f -> %.4f m" % [radio_max, tam_camara])

	for item: Dictionary in ITEMS:
		var id: String = item["id"]
		if not recetas_combo.has(id):
			continue
		var datos: Dictionary = recetas_combo[id]
		var todas_combo: Dictionary = datos["todas"]
		var receta: Dictionary = datos["receta"]
		var ancla: Vector3 = datos["ancla"]

		var brutos: Array[Dictionary] = []
		for rot: int in ROTACIONES:
			_montar_receta(_grupo_final, receta, todas_combo, ancla)
			_grupo_final.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			brutos.append(await _renderizar_bruto())

		# CORRECCIÓN 2D FINAL (empírica): el `escala_3d` de la cabecera predice bien el ORDEN de
		# magnitud pero NO da alto exacto -- verificado, ~1,25-1,30x de más en las 3 piezas (probable
		# inflación de silueta por HUELLA en planta bajo cámara angulada 30°, no solo extrusión en Y
		# -- una silueta isométrica de un objeto ancho/profundo no es solo su altura Y, así que el
		# "silueta/radio" de la pieza aislada y el de la compuesta no son perfectamente intercambiables).
		# En vez de perseguir la fórmula 3D exacta (fuera de presupuesto de esta pasada de propuesta),
		# se mide el alto YA RENDERIZADO en 3D (relativo correcto cajonera:aparato, solo la escala
		# ABSOLUTA fina) y se corrige con el MISMO truco de reescalado 2D que usa el resto del pipeline
		# (`_escalar`, ver `_render_props_nuevos.gd` v2) para que el alto TOTAL del compuesto caiga
		# exacto en `tapa cajonera + altura_objetivo_m` del aparato.
		var alto_medido: int = _medir_alto(brutos[0]["imagen"])
		var alto_esperado_m: float = CENTRO_TAPA_CAJONERA.y + (item["altura_objetivo_m"] as float)
		var alto_predicho_m: float = float(alto_medido) * (datos["radio"] as float) / K_ENCUADRE
		var factor_correccion: float = alto_esperado_m / maxf(alto_predicho_m, 0.001)
		print("[PROPS SOPORTE] %s_soporte: alto medido=%dpx -> %.3fm (esperado ~%.3fm, tapa=%.3f+aparato=%.2f) -> correccion x%.4f" % [
			id, alto_medido, alto_predicho_m, alto_esperado_m, CENTRO_TAPA_CAJONERA.y, item["altura_objetivo_m"], factor_correccion
		])

		var escalados: Array[Dictionary] = []
		for bruto: Dictionary in brutos:
			escalados.append(_escalar(bruto, factor_correccion))

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_soporte_%d.png" % [SALIDA_SCRATCH, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[PROPS SOPORTE] save_png '%s' fallo (error %d)" % [ruta, err])
		print("[PROPS SOPORTE] %s: guardado -> %s%s_soporte_{0,90,180,270}.png" % [id, SALIDA_SCRATCH, id])

	print("[PROPS SOPORTE] hecho.")
	get_tree().quit()


## Carga `isometric_office.glb` (mismo `MODELO` del padre) y devuelve SOLO `Object_833` (la
## cajonera), indexado sin prefijo, para que la fase B lo combine bajo la clave `cajonera__...`.
func _cargar_cajonera(contenedor: Node3D) -> Dictionary:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("[PROPS SOPORTE] no se pudo cargar %s" % MODELO)
		return {}
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)
	for hijo: Node in raiz.find_children(NOMBRE_CAJONERA, "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		return {NOMBRE_CAJONERA: {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}}
	return {}


## Carga UN `.glb` suelto de `props_poly` y vuelca sus `MeshInstance3D` SIN prefijo (mismo formato
## que `_recopilar_instancias` del padre) -- una entrada por pieza del aparato `id`.
func _cargar_pieza_suelta(contenedor: Node3D, id: String) -> Dictionary:
	var ruta: String = "%s%s.glb" % [CARPETA_ORIGEN, id]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[PROPS SOPORTE] no se pudo cargar %s" % ruta)
		return {}
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)
	var piezas: Dictionary = {}
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		piezas[mi.name] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
	print("[PROPS SOPORTE] %s: %d MeshInstance3D cargadas" % [id, piezas.size()])
	return piezas


var _grupo_calib: Node3D
var _grupo_final: Node3D


## Monta el `SubViewport`/mundo/cámara UNA vez -- mismo montaje que `_ejecutar` del padre, pero
## reutilizado en dos fases (calibración con cámara variable por pieza, composición con cámara
## fija compartida).
func _preparar_escenario() -> void:
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

	_grupo_calib = Node3D.new()
	mundo.add_child(_grupo_calib)
	_grupo_final = Node3D.new()
	mundo.add_child(_grupo_final)


## El ALTO en píxeles de la silueta opaca de una imagen en bruto (idéntico a `_render_props_
## nuevos.gd::_medir_alto` -- copiado, no importado, para no acoplar dos herramientas desechables).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[PROPS SOPORTE] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
