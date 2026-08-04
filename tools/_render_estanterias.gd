extends "res://tools/render_mobiliario.gd"
## _render_estanterias — DEFINITIVO (2026-08-04): renderiza las estanterías del pack decididas por
## el usuario en design/art/mapa-integracion-mobiliario.md (3ª tanda) a `assets/sprites/
## mobiliario/`. Aprobado por el usuario tras la pasada de propuesta (mismo fichero, ver historial
## git) — este pase reproduce esos PNG píxel a píxel, solo cambia el destino.
##
## Hereda TODO el pipeline de `render_mobiliario.gd` (cámara bit-idéntica: 30° elevación,
## ortográfica, mismo `_ancla_de`/`_radio_de`/_montar_receta`/`_escalar`/`_componer`) — solo añade
## DOS recetas nuevas (el resto de `_recetas()` del padre solo entra en el cálculo de cámara para
## que el encuadre sea IDÉNTICO al de una pasada completa) y las guarda en `SALIDA` (heredado del
## padre, `res://assets/sprites/mobiliario/`).
##
## ── OBJ_007 (estantería con carpetas/libros) ──────────────────────────────────────────────────
## Entera, sin despiece: las 38 piezas de su cluster en `catalogo_objetos_manifest.json`
## (`Object_153`..`Object_217`, ver el volcado de la sesión).
##
## ── OBJ_022 (2 estanterías haciendo esquina) — DESPIECE MANUAL ────────────────────────────────
## El despiece automático "por volumen" (`catalogo_despiece_manifest.json`) NO tiene entrada para
## OBJ_022 (las dos estanterías comparten firma de tamaño con el conjunto completo, así que el
## método por volumen no las separó). Despiece a mano con `tools/_diag_obj022.gd` (AABB de las 34
## piezas del cluster): las 34 piezas se agrupan en DOS estanterías idénticas, una GIRADA 90°
## respecto a la otra, que es justo lo que se espera de una L de esquina:
##   · Brazo Z (16 piezas, x fijo ≈ −9,9, se extiende en z de 0,16 a 1,02 m): panel lateral
##     `Object_881` (tamaño local 0,157×1,045×0,845) + libros/carpetas.
##   · Brazo X (18 piezas, z fijo ≈ 0,01–0,17, se extiende en x de −9,84 a −8,99 m): panel lateral
##     `Object_903` — MISMO volumen que `Object_881` (0,13881 m³) con X/Z intercambiados: es la
##     MISMA pieza de panel, rotada 90°. Confirma que OBJ_022 = un único diseño de estantería
##     usado DOS veces para formar la esquina, no dos muebles distintos.
## Se toma el brazo X (18 piezas, el más poblado de libros) como la estantería SUELTA: el jugador
## coloca DOS para reconstruir la esquina él mismo (pedido del usuario, mapa-integracion, 3ª tanda).
##
## Escritura: `assets/sprites/mobiliario/` (`SALIDA`, heredado del padre) — CERO cambios en el
## catálogo (.tres) ni en el código de juego, eso es otra tarea (ver mapa-integracion-mobiliario.md).

const ID_OBJ007 := "comodidad_estanteria"
const ID_OBJ022_SUELTA := "comodidad_estanteria_suelta"

## OBJ_007 entero — 38 piezas (catalogo_objetos_manifest.json, cluster "OBJ_007").
static var NOMBRES_OBJ007 := PackedStringArray([
	"Object_153", "Object_155", "Object_156", "Object_158", "Object_159", "Object_161",
	"Object_162", "Object_164", "Object_165", "Object_167", "Object_168", "Object_170",
	"Object_171", "Object_173", "Object_174", "Object_176", "Object_177", "Object_179",
	"Object_180", "Object_182", "Object_183", "Object_185", "Object_187", "Object_189",
	"Object_191", "Object_193", "Object_195", "Object_197", "Object_199", "Object_201",
	"Object_203", "Object_205", "Object_207", "Object_209", "Object_211", "Object_213",
	"Object_215", "Object_217",
])

## OBJ_022, brazo X (estantería suelta) — 18 piezas, ver la cabecera para la identificación.
static var NOMBRES_OBJ022_SUELTA := PackedStringArray([
	"Object_903", "Object_905", "Object_906", "Object_907", "Object_908",
	"Object_910", "Object_911", "Object_913", "Object_914",
	"Object_916", "Object_917", "Object_919", "Object_920",
	"Object_922", "Object_924", "Object_926", "Object_928", "Object_929",
])


func _ejecutar(todas: Dictionary) -> void:
	# Recetas del padre (para que el encuadre de cámara sea IDÉNTICO al de una pasada completa) +
	# las dos nuevas de esta propuesta.
	var recetas: Array[Dictionary] = _recetas()
	recetas.append({"id_salida": ID_OBJ007, "nombres": NOMBRES_OBJ007})
	recetas.append({"id_salida": ID_OBJ022_SUELTA, "nombres": NOMBRES_OBJ022_SUELTA})

	var anclas: Dictionary = {}
	var radio_max := 0.0
	for receta: Dictionary in recetas:
		var ancla: Vector3 = _ancla_de(receta, todas)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(receta, todas, ancla))
	var tam_camara: float = radio_max * 2.0 * MARGEN
	print("[ESTANTERIAS] radio máximo (con TODAS las recetas del padre): %.3f m -> cámara %.3f m" % [
		radio_max, tam_camara
	])

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
	_colocar_camara(tam_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# 1) El mostrador a 0° -- SOLO para calibrar `escala_final` con la MISMA fórmula que el padre.
	var receta_mostrador: Dictionary = _receta_por_id(recetas, ID_MOSTRADOR)
	_montar_receta(grupo, receta_mostrador, todas, anclas[ID_MOSTRADOR])
	grupo.rotation = Vector3.ZERO
	var bruto_mostrador: Dictionary = await _renderizar_bruto()
	var ancho_bruto: int = (bruto_mostrador["imagen"] as Image).get_width()
	var ancho_objetivo: float = Proyeccion.ANCHO_ROMBO * ESCALA_OBJETIVO_MOSTRADOR
	var escala_final: float = ancho_objetivo / float(maxi(ancho_bruto, 1))
	print("[ESTANTERIAS] calibración: mostrador bruto=%dpx -> factor=%.4f" % [ancho_bruto, escala_final])

	# 2) Las dos recetas nuevas, 4 rotaciones cada una, guardadas a assets/sprites/mobiliario/.
	for id_salida: String in [ID_OBJ007, ID_OBJ022_SUELTA]:
		var receta: Dictionary = _receta_por_id(recetas, id_salida)
		_montar_receta(grupo, receta, todas, anclas[id_salida])
		var escalados: Array[Dictionary] = []
		for rot: int in ROTACIONES:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			print("[ESTANTERIAS] %s @ %d°: bruto %dx%d px" % [
				id_salida, rot, (bruto["imagen"] as Image).get_width(), (bruto["imagen"] as Image).get_height()
			])
			escalados.append(_escalar(bruto, escala_final))
		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA, id_salida, ROTACIONES[i]]
			var ruta_absoluta: String = ProjectSettings.globalize_path(ruta)
			var err: Error = (imagenes[i] as Image).save_png(ruta_absoluta)
			if err != OK:
				push_error("[ESTANTERIAS] save_png '%s' fallo (error %d)" % [ruta_absoluta, err])
		var ancla_final: Vector2 = compuesto["ancla"]
		var ancho_final: int = compuesto["ancho"]
		var alto_final: int = compuesto["alto"]
		print("[ESTANTERIAS] %s: lienzo %dx%d px, ancla=(%.1f,%.1f) fracción=(%.3f,%.3f) -> %s%s_{0,90,180,270}.png" % [
			id_salida, ancho_final, alto_final, ancla_final.x, ancla_final.y,
			ancla_final.x / float(ancho_final), ancla_final.y / float(alto_final), SALIDA, id_salida
		])

	print("[ESTANTERIAS] hecho.")
	get_tree().quit()


func _receta_por_id(recetas: Array[Dictionary], id_salida: String) -> Dictionary:
	for receta: Dictionary in recetas:
		if receta["id_salida"] == id_salida:
			return receta
	push_error("ESTANTERIAS: receta no encontrada: %s" % id_salida)
	return {}
