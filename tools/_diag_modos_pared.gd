extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — comprueba, con el código REAL (`ParedesSalas`), el
## nuevo MODO GLOBAL DE ALTURA (petición del usuario 2026-08-04: *"habría que poner la opción de ver
## o no ver las paredes, como en los Sims; ahora mismo están en algo intermedio pero se tiene que
## poder ver todas las paredes, o bien todas pequeñas"*).
##
## Monta UNA sala (documentación, 6×4, con sus 4 lados amurallados — dos traseras norte/oeste + dos
## frontales sur/este, así "auto" da mezcla real de verdad) y la fotografía en los TRES modos, sin
## tocar nada del modelo entre una captura y otra — solo `ParedesSalas.fijar_modo_altura`.
##
## EL JUEZ es el volcado numérico (cuántos tramos salen a `ALTO_PARED` vs `ALTO_PARED_FRENTE` en cada
## modo), impreso ANTES de cada captura: la foto ilustra, el número decide.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(720, 540)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

const MODOS: Array[StringName] = [&"auto", &"todas", &"bajitas"]


func _ready() -> void:
	await _caso_modos()
	get_tree().quit()


## Un SubViewport con la MISMA sala amurallada en los 4 lados (fondo opaco + cámara encuadrando la
## sala entera). Devuelve [sub, paredes].
func _montar() -> Array:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	# ⚠️ ENCUADRE CON CÁMARA, no transformando un Node2D padre: las capas visuales de `Construccion`
	# cuelgan de un nodo NO-CanvasItem (raíz de canvas, no hereda transformadas de ningún padre —
	# mismo gotcha de `_diag_oclusion_murete.gd`).
	var camara := Camera2D.new()
	camara.zoom = Vector2(2.2, 2.2)
	camara.position = ProyeccionScript.proyectar(Vector2(4.0, 3.0) * float(TAM_CELDA))
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
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 6, 4)
	)
	construccion.fijar_paredes_de_sala(sala, true)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	return [sub, paredes]


## Fotografía la MISMA sala en los tres modos, una captura por modo, con su volcado numérico antes.
func _caso_modos() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var paredes: Node = piezas[1]
	for modo: StringName in MODOS:
		paredes.fijar_modo_altura(modo)
		_volcar(paredes, modo)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ruta: String = "%smodo_pared_%s.png" % [CARPETA_SALIDA, modo]
		var err: Error = sub.get_texture().get_image().save_png(ruta)
		if err != OK:
			push_error("[DIAG MODOS PARED] save_png '%s' fallo (error %d)" % [ruta, err])
		else:
			print("[DIAG MODOS PARED] %s -> %s" % [modo, ruta])
	sub.queue_free()
	print("[DIAG MODOS PARED] hecho -- ver %smodo_pared_{auto,todas,bajitas}.png" % CARPETA_SALIDA)


## Cuenta, entre los `TramoPared` ya construidos, cuántos salen a `ALTO_PARED` (enteros) y cuántos a
## `ALTO_PARED_FRENTE` (bajitos) — el juez numérico del modo. Lo que no tiene esas dos alturas exactas
## (jambas de puerta, sin altura — línea de suelo) cae en "otros" y no cuenta para el veredicto.
func _volcar(paredes: Node, modo: StringName) -> void:
	var enteros: int = 0
	var bajitos: int = 0
	var otros: int = 0
	for hijo: Node in paredes.get_children():
		var alto: float = float(hijo.get("_alto"))
		if is_equal_approx(alto, ParedesSalasScript.ALTO_PARED):
			enteros += 1
		elif is_equal_approx(alto, ParedesSalasScript.ALTO_PARED_FRENTE):
			bajitos += 1
		else:
			otros += 1
	print("[DIAG MODOS PARED] modo=%s tramos=%d ENTEROS=%d BAJITOS=%d otros(jambas)=%d" % [
		modo, paredes.get_child_count(), enteros, bajitos, otros
	])
