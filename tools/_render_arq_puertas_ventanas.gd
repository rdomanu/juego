extends "res://tools/render_mobiliario.gd"
## _render_arq_puertas_ventanas — DESECHABLE, fase de PROPUESTA (2026-08-04).
##
## Renderiza 4 candidatos de "arquitectura" del pack (`catalogo_objetos_manifest.json`,
## sección `arquitectura`) para la hoja de comparación puertas/ventanas pedida por el coordinador:
##   · ARQ_004 (`Object_43`)   — marco de puerta de madera clara, sin hoja.
##   · ARQ_009 (`Object_795`)  — marco de puerta metálico/gris oscuro, sin hoja.
##   · ARQ_022 (`Object_1043`) — persiana/estor enrollable negro, desplegado (candidato a "ventana").
##   · ARQ_023 (`Object_1057`) — segmento de pared verde con hueco rectangular tipo ventana interior.
##
## Mismo pipeline BIT-IDÉNTICO que `render_mobiliario.gd`/`_render_estanterias.gd` (cámara fija
## 30°/ortográfica, escala calibrada contra el mostrador — ver `ESCALA_OBJETIVO_MOSTRADOR`), así
## que estos sprites casan en tamaño con el resto del mobiliario YA en `assets/sprites/mobiliario/`
## y con la rejilla del juego (`Proyeccion.ANCHO_ROMBO`/`ALTO_ROMBO`).
##
## ⚠️ Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA, cero cambios al
## juego hasta el OK del usuario.

const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

const ID_ARQ004 := "arq004_marco_madera"
const ID_ARQ009 := "arq009_marco_metal"
const ID_ARQ022 := "arq022_persiana"
const ID_ARQ023 := "arq023_panel_ventana"


func _ejecutar(todas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)
	# Recetas del padre (SOLO para que el encuadre de cámara/escala sea IDÉNTICO al de una pasada
	# completa de mobiliario) + las 4 nuevas de esta propuesta.
	var recetas: Array[Dictionary] = _recetas()
	recetas.append({"id_salida": ID_ARQ004, "nombres": PackedStringArray(["Object_43"])})
	recetas.append({"id_salida": ID_ARQ009, "nombres": PackedStringArray(["Object_795"])})
	recetas.append({"id_salida": ID_ARQ022, "nombres": PackedStringArray(["Object_1043"])})
	recetas.append({"id_salida": ID_ARQ023, "nombres": PackedStringArray(["Object_1057"])})

	var anclas: Dictionary = {}
	var radio_max := 0.0
	for receta: Dictionary in recetas:
		var ancla: Vector3 = _ancla_de(receta, todas)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(receta, todas, ancla))
	var tam_camara: float = radio_max * 2.0 * MARGEN
	print("[ARQ] radio máximo (con TODAS las recetas del padre): %.3f m -> cámara %.3f m" % [
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
	print("[ARQ] calibración: mostrador bruto=%dpx -> factor=%.4f" % [ancho_bruto, escala_final])

	# 2) Los 4 candidatos, 4 rotaciones cada uno, guardados AL SCRATCHPAD (no a assets/).
	for id_salida: String in [ID_ARQ004, ID_ARQ009, ID_ARQ022, ID_ARQ023]:
		var receta: Dictionary = _receta_por_id(recetas, id_salida)
		_montar_receta(grupo, receta, todas, anclas[id_salida])
		var escalados: Array[Dictionary] = []
		for rot: int in ROTACIONES:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			print("[ARQ] %s @ %d°: bruto %dx%d px" % [
				id_salida, rot, (bruto["imagen"] as Image).get_width(), (bruto["imagen"] as Image).get_height()
			])
			escalados.append(_escalar(bruto, escala_final))
		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA_SCRATCH, id_salida, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[ARQ] save_png '%s' fallo (error %d)" % [ruta, err])
		var ancla_final: Vector2 = compuesto["ancla"]
		var ancho_final: int = compuesto["ancho"]
		var alto_final: int = compuesto["alto"]
		print("[ARQ] %s: lienzo %dx%d px, ancla=(%.1f,%.1f) fracción=(%.3f,%.3f) -> %s%s_{0,90,180,270}.png" % [
			id_salida, ancho_final, alto_final, ancla_final.x, ancla_final.y,
			ancla_final.x / float(ancho_final), ancla_final.y / float(alto_final), SALIDA_SCRATCH, id_salida
		])

	print("[ARQ] hecho.")
	get_tree().quit()


func _receta_por_id(recetas: Array[Dictionary], id_salida: String) -> Dictionary:
	for receta: Dictionary in recetas:
		if receta["id_salida"] == id_salida:
			return receta
	push_error("ARQ: receta no encontrada: %s" % id_salida)
	return {}
