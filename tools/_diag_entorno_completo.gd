extends Node2D
## SONDA GPU (no headless) — "ENTORNO COMPLETO" (2026-08-07): verifica en el motor real que, con la
## cámara en las 4 esquinas del clamp al zoom MÁS ALEJADO permitido (`Main.ZOOM_MIN`), no se ve el
## vacío `Main.COLOR_FONDO` en ningún borde de la ventana — el caso literal que pidió el usuario
## ("que se vea toda la comisaría alrededor... que al moverse no se vean cosas vacías fuera, solo
## entorno, como en Theme Hospital").
##
## Instancia la escena REAL (`Main.tscn`) y deja que arranque el juego entero (así se prueba el
## clamp/cobertura de PRODUCCIÓN, no una réplica reducida): para cada esquina fuerza
## `_camara.zoom`/`_camara.position` directamente (acceso a campos "privados" por convención, no por
## enforcement — mismo patrón que otras sondas con `_modo`/`_construccion`), espera dos frames y hace
## una captura + un muestreo de píxeles del BORDE de la imagen: si alguno es del color de fondo vacío,
## FALLA. Al final, una captura general (zoom 1.0, cámara centrada) para el vistazo humano.
##
## Se borra tras usarlo — no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")

## Tolerancia por canal al comparar contra `Main.COLOR_FONDO` — floja a propósito: cualquier
## variación real de entorno (calle/césped/manzanas) está MUY lejos de este gris azulado oscuro.
const TOLERANCIA_CANAL: float = 0.03

var _main: Node2D


func _ready() -> void:
	_main = MainEscena.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	var visible: Vector2 = get_viewport().get_visible_rect().size / _main.ZOOM_MIN
	var minimo: Vector2 = _main._limite_camara_min
	var maximo: Vector2 = _main._limite_camara_max
	var esquinas: Dictionary = {
		"noroeste": minimo,
		"noreste": Vector2(maximo.x - visible.x, minimo.y),
		"suroeste": Vector2(minimo.x, maximo.y - visible.y),
		"sureste": maximo - visible,
	}
	print(
		"[DIAG ENTORNO COMPLETO] limite_min=%s limite_max=%s zoom_min=%s visible_a_zoom_min=%s"
		% [minimo, maximo, _main.ZOOM_MIN, visible]
	)

	var resultados: Array[bool] = []
	for nombre: String in ["noroeste", "noreste", "suroeste", "sureste"]:
		resultados.append(await _probar_esquina(nombre, esquinas[nombre]))

	# Captura general: cámara centrada, zoom 1.0 (la vista "normal" de arranque) — para que se vea
	# la comisaría con su entorno completo alrededor.
	_main._camara.zoom = Vector2.ONE
	_main._camara.position = _main._clamp_posicion_camara(
		Vector2.ZERO, get_viewport().get_visible_rect().size
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_guardar("entorno_completo_general.png")

	var pasa_todo: bool = not resultados.has(false)
	print("[DIAG ENTORNO COMPLETO] RESUMEN: %d/%d esquinas PASA -> %s" % [
		resultados.count(true), resultados.size(), "PASA" if pasa_todo else "FALLA",
	])
	get_tree().quit()


func _probar_esquina(nombre: String, posicion: Vector2) -> bool:
	_main._camara.zoom = Vector2(_main.ZOOM_MIN, _main.ZOOM_MIN)
	_main._camara.position = posicion
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	var vacios: Array[Vector2i] = _muestrear_borde(imagen)
	var pasa: bool = vacios.is_empty()
	print("[DIAG ENTORNO COMPLETO] esquina=%s pos=%s pixeles_vacios_en_borde=%d -> %s" % [
		nombre, posicion, vacios.size(), "PASA" if pasa else "FALLA",
	])
	if not vacios.is_empty():
		print("[DIAG ENTORNO COMPLETO]   primeros vacíos: %s" % [vacios.slice(0, mini(8, vacios.size()))])
	_guardar("entorno_completo_%s.png" % nombre)
	return pasa


## Muestrea el BORDE del ÁREA DE JUEGO (perímetro, cada `paso` píxeles) y devuelve los que coinciden
## con `Main.COLOR_FONDO` (el vacío) — el juez numérico antes de mirar la foto.
##
## La barra del HUD (`Main.ALTO_BARRA_HUD`, abajo) queda FUERA del muestreo a propósito: es una
## `CanvasLayer` de UI con su propio estilo de panel (fondo del tema de Godot, no `COLOR_FONDO`),
## ajena por completo al entorno/cámara que prueba esta sonda — auditar su estilo es otro tema, no
## el de este encargo ("que no se vean cosas vacías fuera, solo entorno").
func _muestrear_borde(imagen: Image) -> Array[Vector2i]:
	var w: int = imagen.get_width()
	var h_juego: int = imagen.get_height() - int(_main.ALTO_BARRA_HUD)
	var paso: int = 4
	# 🐛 Hallazgo de esta sonda (2026-08-07): la columna/fila EXACTA del borde del framebuffer
	# (`get_texture().get_image()`) devuelve un gris ligeramente distinto de `COLOR_FONDO`
	# (0.137,0.137,0.133 vs 0.13,0.14,0.16 — verificado con `_check_color.gd` a mano) en una banda
	# de ~10 px, IDÉNTICO en las 4 esquinas con contenido de mundo totalmente distinto detrás — un
	# artefacto de captura del borde del viewport, no del mundo (las 4 capturas, miradas a ojo, no
	# tienen NINGÚN hueco). Se deja un margen de seguridad (`margen`) para no confundir ese
	# artefacto con un hueco real de cobertura — un hueco real sería una banda ANCHA y consistente
	# con el color de fondo EXACTO, no unos pocos px de un gris ligeramente distinto.
	var margen: int = 12
	var vacios: Array[Vector2i] = []
	for x: int in range(margen, w - margen, paso):
		_probar_pixel(imagen, Vector2i(x, margen), vacios)
		_probar_pixel(imagen, Vector2i(x, h_juego - 1 - margen), vacios)
	for y: int in range(margen, h_juego - margen, paso):
		_probar_pixel(imagen, Vector2i(margen, y), vacios)
		_probar_pixel(imagen, Vector2i(w - 1 - margen, y), vacios)
	return vacios


func _probar_pixel(imagen: Image, punto: Vector2i, vacios: Array[Vector2i]) -> void:
	var color: Color = imagen.get_pixel(punto.x, punto.y)
	var fondo: Color = _main.COLOR_FONDO
	if (
		absf(color.r - fondo.r) < TOLERANCIA_CANAL
		and absf(color.g - fondo.g) < TOLERANCIA_CANAL
		and absf(color.b - fondo.b) < TOLERANCIA_CANAL
	):
		vacios.append(punto)


func _guardar(nombre: String) -> void:
	var ruta: String = CARPETA_SALIDA + nombre
	var err: Error = get_viewport().get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG ENTORNO COMPLETO] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG ENTORNO COMPLETO] -> %s" % ruta)
