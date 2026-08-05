extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — la dirección de arte del suelo del 2026-08-05
## (quick-spec §3c): **suelo limpio, rodapié en la pared y cuadrícula solo al construir**.
##
## Monta UNA sala amurallada con una PUERTA real y la fotografía DOS veces, sin tocar el modelo
## entre una foto y otra — solo el interruptor del modo construcción:
##   (a) `suelo_limpio_juego.png`        — juego normal: baldosa sin juntas marcadas, rodapié en la
##                                         base de los muros, SIN rejilla por ningún lado;
##   (b) `suelo_limpio_construccion.png` — modo construcción: la MISMA sala con la cuadrícula encima.
##
## EL JUEZ es el volcado numérico impreso antes de cada captura (alto del atlas de baldosa, tramos
## con rodapié, líneas de la rejilla y si está visible): la foto ilustra, el número decide.
##
## ⚠️ No se instancia `ModoConstruccion` entero (arrastra su barra de UI, su paleta y sus diálogos a
## un `SubViewport` de diagnóstico): se usa su clase interna `RejillaConstruccion`, que es justo la
## pieza nueva, montada con el mismo z_index y el mismo color que le pone el modo de verdad.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(760, 560)
## La sala de la foto: 6×4 celdas, amurallada por los cuatro lados (dos traseras + dos frontales).
const RECT_SALA := Rect2i(1, 1, 6, 4)
## Dónde va la puerta (tramo norte de la sala): la foto tiene que enseñar que el rodapié NO la cruza.
const CELDA_PUERTA := Vector2i(3, 1)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"


func _ready() -> void:
	await _caso_suelo_limpio()
	get_tree().quit()


## Un SubViewport con la sala amurallada (fondo opaco + cámara encuadrándola) y la rejilla del modo
## construcción ya montada pero APAGADA. Devuelve [sub, construccion, paredes, rejilla].
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
	# cuelgan de un nodo NO-CanvasItem (mismo gotcha documentado en `_diag_modos_pared.gd`).
	var camara := Camera2D.new()
	camara.zoom = Vector2(2.0, 2.0)
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
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	construccion.fijar_tipo_de_muro(CELDA_PUERTA, &"arriba", construccion.PUERTA)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))
	# La pieza nueva del modo construcción, con su z y su color reales (ver `_crear_rejilla`).
	var rejilla: Node2D = ModoConstruccionScript.RejillaConstruccion.new()
	rejilla.z_index = -1
	rejilla.visible = false
	mundo.add_child(rejilla)
	rejilla.construir(
		construccion, construccion.edificio_columnas, construccion.edificio_filas,
		ModoConstruccionScript.COLOR_REJILLA_CONSTRUCCION,
		ModoConstruccionScript.GROSOR_REJILLA_CONSTRUCCION
	)
	return [sub, construccion, paredes, rejilla]


## Las dos fotos: juego normal (rejilla apagada) y modo construcción (rejilla encendida).
func _caso_suelo_limpio() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[1]
	var paredes: Node = piezas[2]
	var rejilla: Node2D = piezas[3]
	for caso: Array in [["juego", false], ["construccion", true]]:
		rejilla.visible = bool(caso[1])
		_volcar(construccion, paredes, rejilla, String(caso[0]))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ruta: String = "%ssuelo_limpio_%s.png" % [CARPETA_SALIDA, caso[0]]
		var err: Error = sub.get_texture().get_image().save_png(ruta)
		if err != OK:
			push_error("[DIAG SUELO LIMPIO] save_png '%s' fallo (error %d)" % [ruta, err])
		else:
			print("[DIAG SUELO LIMPIO] %s -> %s" % [caso[0], ruta])
	sub.queue_free()
	print("[DIAG SUELO LIMPIO] hecho -- ver %ssuelo_limpio_{juego,construccion}.png" % CARPETA_SALIDA)


## El juez numérico de cada foto: el atlas de baldosa (alto = 1 sola fila desde que murió el zócalo
## del suelo), cuántos tramos de muro llevan rodapié y cuántas líneas tiene la rejilla + si se ve.
func _volcar(construccion: Node, paredes: Node, rejilla: Node2D, caso: String) -> void:
	var atlas: Texture2D = construccion._textura_de_celda(Color(0.4, 0.5, 0.6))
	var con_rodapie: int = 0
	var sin_rodapie: int = 0
	for tramo: Dictionary in paredes._tramos:
		if (tramo.get("rodapie", Color.TRANSPARENT) as Color).a > 0.0:
			con_rodapie += 1
		else:
			sin_rodapie += 1
	print("[DIAG SUELO LIMPIO] caso=%s atlas=%dx%d (filas=%d) tramos_con_rodapie=%d sin=%d rejilla_visible=%s lineas=%d" % [
		caso, atlas.get_width(), atlas.get_height(),
		atlas.get_height() / construccion._tam_celda, con_rodapie, sin_rodapie,
		rejilla.visible, rejilla._puntos.size() / 2
	])
