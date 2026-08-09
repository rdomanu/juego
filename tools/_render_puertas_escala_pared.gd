extends "res://tools/render_mobiliario.gd"
## _render_puertas_escala_pared — DESECHABLE, fase de PROPUESTA (2026-08-04, quick-spec
## `construccion-pintura-puertas-preview-2026-08-04.md` §3b).
##
## Decisión del usuario: las piezas de puerta/ventana del pack están a escala arquitectónica REAL
## y no adaptadas a la pared enana del juego — hay que escalarlas para que CASEN con la pared, no
## con la rejilla de mobiliario. Candidatos de esta pasada:
##   · PUERTA candidato 1: KayKit `door_A.gltf` (CON hoja — es lo que el usuario quiere ver).
##   · PUERTA candidato 2: KayKit `door_B.gltf` (CON hoja).
##   · PUERTA candidato 3: ARQ_004 (`Object_43`, `isometric_office.glb`) — marco de madera, sin hoja.
##   · VENTANA candidato: ARQ_009 (`Object_795`, `isometric_office.glb`) — marco alargado, "de suelo
##     a techo".
##
## ── CÁMARA: mismo pipeline bit-idéntico que `render_mobiliario.gd` (30°/45°, ortográfica, mismas
## luces) — PERO LA CALIBRACIÓN ES DISTINTA. `render_mobiliario.gd` ajusta el ANCHO de una pieza
## contra el mostrador (mobiliario que "vive en su celda"). Aquí no hay celda: una puerta/ventana se
## planta contra un TRAMO DE PARED, y ese tramo lo dibuja `ParedesSalas` como un rectángulo recto en
## pantalla de `ALTO_PARED` = 34 px (sin cámara 3D, código puro — ver `paredes_salas.gd`). Así que lo
## que hay que casar es la ALTURA en px de la SILUETA YA RENDERIZADA de cada pieza (que sí pasa por
## la cámara isométrica, con su escorzo por la elevación de 30° ya incluido) contra esos 34 px —
## MEDIDO sobre el propio render, no calculado a ciegas con el coseno de la elevación (mismo
## criterio que el resto de la herramienta: medir el PNG, no adivinar).
##
## Cada candidato tiene SU PROPIA cámara (radio propio + `MARGEN`, ver `_ejecutar`): a diferencia de
## `render_mobiliario.gd` (una cámara fija para TODA la pasada, necesaria para que el tamaño relativo
## entre piezas de una misma escena se conserve), aquí cada pieza se calibra de forma INDEPENDIENTE
## contra `ALTO_PARED` — el tamaño relativo entre una puerta y una ventana no importa aquí porque
## nunca conviven en el mismo tramo.
##
## La escala de referencia se mide en la rotación 0° (la cara que se plantaría contra la pared en la
## hoja, `_hoja_puertas_escala.gd`) y se aplica IGUAL a las otras tres rotaciones (mismo criterio que
## `escala_final` en `render_mobiliario.gd`: una única medida, aplicada sin recalcular).
##
## ⚠️ Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA, cero cambios al
## juego hasta el OK del usuario.

const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")

const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

const RUTA_DOOR_A := "res://capturas/fuentes/kaykit_restaurant/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/door_A.gltf"
const RUTA_DOOR_B := "res://capturas/fuentes/kaykit_restaurant/KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/door_B.gltf"

const ID_DOOR_A := "doorA_kaykit_pared"
const ID_DOOR_B := "doorB_kaykit_pared"
const ID_ARQ004 := "arq004_marco_pared"
const ID_ARQ009 := "arq009_ventana_pared"

## El objetivo de TODAS las piezas de esta pasada: el alto real de la pared del juego (34 px hoy).
## Tomado de `ParedesSalas` en vez de repetir el número — si cambia allí, esta herramienta lo sigue
## sin tocar nada aquí (misma regla que usa el resto del proyecto contra constantes compartidas).
const ALTO_OBJETIVO_PX: float = ParedesSalasScript.ALTO_PARED


func _ready() -> void:
	# El `_ready` del padre (`render_mobiliario.gd`) SOLO carga `isometric_office.glb` — aquí hacen
	# falta DOS fuentes más (los `.gltf` sueltos de KayKit), así que este `_ready` NO llama a super:
	# arma su propia recolección de piezas ("todas", mismo formato que `_recopilar_instancias`) y
	# llama directo a `_ejecutar`.
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render — mismo criterio que el padre.

	var escena_oficina: PackedScene = load(MODELO)
	if escena_oficina == null:
		push_error("[PUERTAS PARED] no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return
	var modelo_oficina: Node3D = escena_oficina.instantiate()
	contenedor.add_child(modelo_oficina)
	var todas: Dictionary = _recopilar_instancias(modelo_oficina)

	_cargar_modelo_externo(contenedor, RUTA_DOOR_A, "DA_", todas)
	_cargar_modelo_externo(contenedor, RUTA_DOOR_B, "DB_", todas)

	_ejecutar(todas)


## Carga un `.gltf` SUELTO (no forma parte de `isometric_office.glb` — los packs de KayKit viven
## aparte, en `capturas/fuentes/`) y añade sus `MeshInstance3D` al diccionario compartido `todas`,
## en el MISMO formato que usa `_recopilar_instancias` (así el resto de la herramienta heredada de
## `render_mobiliario.gd` — `_ancla_de`/`_radio_de`/`_montar_receta`— no necesita saber de dónde
## vino cada pieza). Las claves llevan `prefijo` para no chocar ni con los nombres `Object_NNN` del
## modelo de oficina ni entre los dos modelos de KayKit (cada `.gltf` puede reutilizar nombres de
## nodo genéricos como "Cube" o "mesh").
func _cargar_modelo_externo(contenedor: Node3D, ruta: String, prefijo: String, todas: Dictionary) -> void:
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[PUERTAS PARED] no se pudo cargar %s" % ruta)
		return
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	var total := 0
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas[prefijo + String(mi.name)] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[PUERTAS PARED] %s: %d MeshInstance3D cargadas (prefijo '%s')" % [ruta.get_file(), total, prefijo])


## Todas las claves de `todas` que empiezan por `prefijo` — la receta de un modelo externo cargado
## por `_cargar_modelo_externo` (se coge TODO el modelo, no una selección de piezas como con
## `isometric_office.glb`: un `.gltf` de KayKit ya es un objeto autocontenido).
func _nombres_con_prefijo(todas: Dictionary, prefijo: String) -> PackedStringArray:
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar(todas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var recetas: Array[Dictionary] = [
		{"id_salida": ID_DOOR_A, "nombres": _nombres_con_prefijo(todas, "DA_")},
		{"id_salida": ID_DOOR_B, "nombres": _nombres_con_prefijo(todas, "DB_")},
		{"id_salida": ID_ARQ004, "nombres": PackedStringArray(["Object_43"])},
		{"id_salida": ID_ARQ009, "nombres": PackedStringArray(["Object_795"])},
	]

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

	print("[PUERTAS PARED] objetivo de altura para TODAS las piezas: %.1f px (ParedesSalas.ALTO_PARED)" % ALTO_OBJETIVO_PX)

	for receta: Dictionary in recetas:
		var id_salida: String = receta["id_salida"]
		var nombres: PackedStringArray = receta["nombres"]
		if nombres.is_empty():
			push_warning("[PUERTAS PARED] %s: receta vacía (no se encontraron piezas) — se salta" % id_salida)
			continue

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° (la cara que se planta contra la pared en la hoja) — define la escala de
		# ESTA pieza. El resto de rotaciones comparten el mismo factor, sin recalcular.
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var alto_bruto_0: int = (bruto_0["imagen"] as Image).get_height()
		var ancho_bruto_0: int = (bruto_0["imagen"] as Image).get_width()
		var escala_pieza: float = ALTO_OBJETIVO_PX / float(maxi(alto_bruto_0, 1))
		print("[PUERTAS PARED] %s: %d piezas, radio=%.3f m, bruto 0°=%dx%dpx -> factor=%.4f" % [
			id_salida, nombres.size(), radio, ancho_bruto_0, alto_bruto_0, escala_pieza
		])

		# 2) Las 4 rotaciones, MISMO factor — se miden ANTES de componer (el lienzo compartido de
		# `_componer` puede añadir relleno transparente si otra rotación es más alta/ancha, y ese
		# relleno NO debe contar como "alto de la pieza").
		var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
		for rot: int in [90, 180, 270]:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			escalados.append(_escalar(bruto, escala_pieza))

		for i: int in ROTACIONES.size():
			var img: Image = escalados[i]["imagen"]
			var alto: int = img.get_height()
			print("[PUERTAS PARED]   rot %d°: %dx%dpx -- alto vs objetivo (%.1f): delta=%+.1f px" % [
				ROTACIONES[i], img.get_width(), alto, ALTO_OBJETIVO_PX, float(alto) - ALTO_OBJETIVO_PX
			])

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA_SCRATCH, id_salida, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[PUERTAS PARED] save_png '%s' fallo (error %d)" % [ruta, err])
		print("[PUERTAS PARED] %s: guardado -> %s%s_{0,90,180,270}.png" % [id_salida, SALIDA_SCRATCH, id_salida])

	print("[PUERTAS PARED] hecho.")
	get_tree().quit()
