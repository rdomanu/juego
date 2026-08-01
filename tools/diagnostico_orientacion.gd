extends SceneTree
## Diagnóstico de ORIENTACIÓN (2026-08-01): feedback del usuario con el juego abierto — "la
## orientación de cómo se sientan, cómo andan y demás de los policías es errónea; la de los
## ciudadanos está bien". Herramienta de UNA vez, headless (pura `Image`, sin GPU): compone, para
## cada índice 0..7 del ciclo de direcciones, una fila con [flecha del rumbo del MUNDO que el juego
## le asigna a ese índice, ya proyectada a pantalla con `Proyeccion` — la MISMA cuenta que usa
## `Muneco.orientar_sprite`/`colocar_muneco`, no una deducción] + [girl_88px_i_0 — la referencia
## correcta] + [oficial_h_88px_i_0 — el andar] + [oficial_h_88px_sit_i — el sentado].
##
## Uso: godot --headless --path <proyecto> -s res://tools/diagnostico_orientacion.gd
##
## El rumbo del MUNDO para el índice `i` es el que hace que `Muneco.orientar_sprite` (o su
## equivalente en `construir_sprite_sentado`) devuelva exactamente `i`: `atan2(y,x) == i * TAU/8`,
## o sea el vector unitario `(cos(i*45°), sin(i*45°))`. Se proyecta a pantalla con
## `Proyeccion.proyectar` — la misma traducción mundo→pantalla que usa TODO el juego.

const RUTA_SPRITES := "res://assets/sprites/personajes/"
const SALIDA := "res://capturas/NPC/Policias/candidatos/diagnostico_orientacion.png"
const DIRECCIONES := 8
const COL_ANCHO := 240
const FILA_ALTO := 300
const MARGEN := 10
const ALTO_OBJETIVO := 240.0   # a qué alto (px) se escala cada personaje para leerlo bien
const COLOR_FLECHA := Color(0.9, 0.15, 0.15)
const COLOR_FONDO := Color(0.93, 0.93, 0.93)
const COLOR_FONDO_ALT := Color(0.86, 0.86, 0.86)


func _initialize() -> void:
	var columnas: int = 4
	var ancho: int = MARGEN + columnas * (COL_ANCHO + MARGEN)
	var alto: int = MARGEN + DIRECCIONES * (FILA_ALTO + MARGEN)
	var canvas := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(1, 1, 1, 1))

	for i: int in DIRECCIONES:
		var y0: int = MARGEN + i * (FILA_ALTO + MARGEN)
		_rellenar(canvas, Rect2i(0, y0, ancho, FILA_ALTO), COLOR_FONDO if i % 2 == 0 else COLOR_FONDO_ALT)

		# Columna 0: la flecha del rumbo del MUNDO para este índice, YA proyectada a pantalla.
		var mundo: Vector2 = Vector2(cos(float(i) * TAU / DIRECCIONES), sin(float(i) * TAU / DIRECCIONES))
		var pantalla: Vector2 = Proyeccion.proyectar(mundo * 100.0).normalized()
		var centro_flecha := Vector2(MARGEN + COL_ANCHO * 0.5, y0 + FILA_ALTO * 0.5)
		_flecha(canvas, centro_flecha, pantalla, 80.0, COLOR_FLECHA)

		# Columnas 1-3: girl (referencia), oficial_h andando, oficial_h sentado.
		_blit_sprite(canvas, "girl_88px_%d_0.png" % i, Rect2i(MARGEN + (COL_ANCHO + MARGEN), y0, COL_ANCHO, FILA_ALTO))
		_blit_sprite(canvas, "oficial_h_88px_%d_0.png" % i, Rect2i(MARGEN + 2 * (COL_ANCHO + MARGEN), y0, COL_ANCHO, FILA_ALTO))
		_blit_sprite(canvas, "oficial_h_88px_sit_%d.png" % i, Rect2i(MARGEN + 3 * (COL_ANCHO + MARGEN), y0, COL_ANCHO, FILA_ALTO))
		print("[DIAG] fila %d: mundo=%s -> pantalla(normalizada)=%s (angulo=%.1f grados)" % [
			i, mundo, pantalla, rad_to_deg(atan2(pantalla.y, pantalla.x))
		])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/NPC/Policias/candidatos/"))
	var err: Error = canvas.save_png(ProjectSettings.globalize_path(SALIDA))
	if err != OK:
		push_error("diagnostico_orientacion: no se pudo guardar %s (error %d)" % [SALIDA, err])
	else:
		print("[DIAG] hoja diagnóstica escrita en %s" % SALIDA)
	quit()


func _rellenar(canvas: Image, rect: Rect2i, color: Color) -> void:
	var relleno := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	relleno.fill(color)
	canvas.blit_rect(relleno, Rect2i(Vector2i.ZERO, rect.size), rect.position)


## Carga un sprite ya recortado, lo escala (NEAREST: son píxeles de un render, no se quiere que se
## difuminen) a `ALTO_OBJETIVO` de alto conservando proporción, y lo pega centrado y anclado por la
## BASE dentro de `celda` — el mismo criterio de anclaje que usa el juego (los pies abajo).
func _blit_sprite(canvas: Image, nombre: String, celda: Rect2i) -> void:
	var ruta: String = ProjectSettings.globalize_path(RUTA_SPRITES + nombre)
	if not FileAccess.file_exists(ruta):
		push_warning("diagnostico_orientacion: no existe %s" % ruta)
		return
	var img := Image.new()
	if img.load(ruta) != OK:
		push_warning("diagnostico_orientacion: no se pudo cargar %s" % ruta)
		return
	var escala: float = ALTO_OBJETIVO / float(img.get_height())
	var w: int = maxi(1, roundi(img.get_width() * escala))
	var h: int = maxi(1, roundi(img.get_height() * escala))
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	var pos := Vector2i(
		celda.position.x + (celda.size.x - w) / 2,
		celda.position.y + celda.size.y - h - 12
	)
	canvas.blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(w, h)), pos)


## Una flecha centrada en `centro`, apuntando hacia `direccion` (ya normalizada, en espacio de
## PANTALLA), de longitud `largo`. Trazo + cabeza en dos aletas a ±150°.
func _flecha(canvas: Image, centro: Vector2, direccion: Vector2, largo: float, color: Color) -> void:
	if direccion.length_squared() < 0.0001:
		return
	var mitad: Vector2 = direccion * (largo * 0.5)
	var punta: Vector2 = centro + mitad
	var cola: Vector2 = centro - mitad
	_linea(canvas, cola, punta, color, 3)
	var aleta1: Vector2 = punta - direccion.rotated(deg_to_rad(150.0)) * (largo * 0.28)
	var aleta2: Vector2 = punta - direccion.rotated(deg_to_rad(-150.0)) * (largo * 0.28)
	_linea(canvas, punta, aleta1, color, 3)
	_linea(canvas, punta, aleta2, color, 3)


func _linea(canvas: Image, desde: Vector2, hasta: Vector2, color: Color, grosor: int) -> void:
	var pasos: int = maxi(1, roundi(desde.distance_to(hasta)))
	var w: int = canvas.get_width()
	var h: int = canvas.get_height()
	for s: int in range(pasos + 1):
		var p: Vector2 = desde.lerp(hasta, float(s) / float(pasos))
		for ox: int in range(-grosor, grosor + 1):
			for oy: int in range(-grosor, grosor + 1):
				var px: int = int(p.x) + ox
				var py: int = int(p.y) + oy
				if px >= 0 and px < w and py >= 0 and py < h:
					canvas.set_pixel(px, py, color)
