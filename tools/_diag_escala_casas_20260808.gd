extends Node2D
## SONDA GPU DESECHABLE (2026-08-08, ley 12 — "las casas son muy pequeñas comparadas con coches/
## personas/comisaría"): verifica en el motor real las casas re-renderizadas por ANCHO DE PARCELA
## (`tools/render_entorno_urbano.gd`, `ANCHO_CASA_BARRIO` en `entorno_exterior.gd`).
##
## Dos capturas al scratchpad de la sesión:
##  1. `escala_barrio_general.png` -- el `Main.tscn` real, cámara centrada en la PRIMERA casa
##     colocada por el scatter procedural (localizada recorriendo `Decor`), zoom que enseña varias
##     manzanas de contexto.
##  2. `escala_composicion.png` -- casa_o + coche_sedan + un `Muneco` real + un tramo de la fachada
##     real de la comisaría, los cuatro en el MISMO encuadre, para la verificación de escala relativa
##     (ley 12: mesa 2 celdas < coche 3+ celdas < casa 6-8 celdas).
##
## Se borra tras usarla -- no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/1f7d5694-02c7-4fc1-9a44-a8546d82445c/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")
const MunecoScript := preload("res://src/main/muneco.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40


func _ready() -> void:
	await _caso_barrio_general()
	await _caso_composicion_escala()
	print("[DIAG ESCALA CASAS] hecho.")
	get_tree().quit()


## ── CASO 1: el juego real, cámara sobre la primera casa colocada por el scatter procedural ──────
func _caso_barrio_general() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var decor: Node2D = main._mundo_profundo.get_node("Decor")
	var casas: Array[Sprite2D] = []
	for hijo: Node in decor.get_children():
		if hijo is Sprite2D and (hijo as Sprite2D).texture != null:
			var ruta: String = (hijo as Sprite2D).texture.resource_path
			if ruta.contains("/casa_"):
				casas.append(hijo as Sprite2D)
	print("[DIAG ESCALA CASAS] casas del scatter encontradas en Decor: %d" % casas.size())
	for casa: Sprite2D in casas:
		print("[DIAG ESCALA CASAS]   %s en pos=%s" % [casa.texture.resource_path.get_file(), casa.global_position])

	# 🐛 CORREGIDO 2026-08-08: `_clamp_posicion_camara` (`Main`) restringe la posición al rectángulo de
	# cobertura calculado para el ZOOM MÍNIMO SOPORTADO (`EntornoExterior.ZOOM_MIN_CAMARA` = 0,5) --
	# con 0,45 (por debajo de ese mínimo, fuera de lo que el juego real permite via `_cambiar_zoom`)
	# el área "visible" en mundo supera el margen de la cámara y el clamp deja la cámara PEGADA a la
	# esquina `_limite_camara_min` (la fachada de la comisaría), ignorando la posición deseada -- la
	# 1ª captura de esta sonda salía siempre sobre el interior del edificio, nunca sobre una casa del
	# barrio. Esta sonda es una captura DESECHABLE (no simula el juego real), así que se asigna la
	# posición DIRECTA, sin pasar por el clamp de `Main` -- el zoom se sube a 0,5 (el mínimo real del
	# juego) para quedarse dentro de lo que la UI normal permitiría.
	main._camara.zoom = Vector2(0.5, 0.5)
	if not casas.is_empty():
		main._camara.position = casas[0].global_position - Vector2(200.0, 250.0)
	else:
		main._camara.position = Vector2.ZERO
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "escala_barrio_general.png")
	print("[DIAG ESCALA CASAS] -> escala_barrio_general.png")

	main.queue_free()
	await get_tree().process_frame


## ── CASO 2: composición controlada casa + coche + muñeco + fachada real, mismo encuadre ─────────
func _caso_composicion_escala() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(1200, 800)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(sub.size)
	capa_fondo.add_child(fondo)

	var camara := Camera2D.new()
	sub.add_child(camara)
	camara.make_current()

	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)

	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)
	construccion.levantar_fachada()
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))

	var entorno := EntornoExteriorScript.new()
	mundo.add_child(entorno)
	entorno.configurar(TAM_CELDA, Vector2.ZERO, 24, 13, profundo)

	# Casa grande (casa_o, 8 celdas) + coche sedán, plantados a mano cerca de la fachada oeste para
	# que quepan los 4 elementos en un solo encuadre.
	var celda_casa := Vector2i(-14, 3)
	var celda_coche := Vector2i(-9, 8)
	entorno._colocar_prop(EntornoExteriorScript.textura_de_pieza("casa_o", 0), celda_casa)
	entorno._colocar_prop(EntornoExteriorScript.textura_de_pieza("coche_sedan", 90), celda_coche)

	# El muñeco real (mismas piezas/escala que el juego), de pie junto al coche.
	var muneco: Node2D = MunecoScript.construir(
		MunecoScript.AZUL_UNIFORME, false, MunecoScript.PIEL,
		MunecoScript.AZUL_PANTALON, MunecoScript.NEGRO_BOTA
	)
	muneco.position = ProyeccionScript.centro_iso(Vector2i(-9, 9))
	profundo.add_child(muneco)

	await get_tree().process_frame
	# Encuadre: entre la casa (oeste) y un tramo de fachada sur (este, ya la levanta
	# `construccion.levantar_fachada()`), con el coche y el muñeco en medio.
	camara.zoom = Vector2(1.0, 1.0)
	camara.position = ProyeccionScript.centro_iso(Vector2i(-4, 7)) + Vector2(0.0, -80.0)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + "escala_composicion.png")
	print("[DIAG ESCALA CASAS] -> escala_composicion.png (casa_o en %s, coche_sedan en %s, muñeco junto al coche)" % [celda_casa, celda_coche])
