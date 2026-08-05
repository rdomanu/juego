extends Node2D
## DEMO COMPARATIVA DESECHABLE — sala real (Construccion + ParedesSalas + MundoProfundo) con los 7
## props nuevos (renders v2 del scratchpad) colocados de forma natural: los 4 ALTOS arrimados a
## pared (mismo mecanismo que las estanterías — AnclajeSprite.desvio_arrimado, verificado en px), un
## mostrador del catálogo como mesa y los 3 de SOBREMESA encima, a la altura real del tablero
## (medida de la masa opaca del PNG, no a ojo), y un ciudadano de pie de escala.
##
## No toca assets/ ni el catálogo: los 7 PNG se cargan del scratchpad con `Image.load_from_file` +
## `ImageTexture` (no son recursos importados). Se borra tras usarlo — no es parte del pipeline.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(1000, 700)

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

## La sala: 6×4, paredes reales, puerta en el muro sur (lejos de los muebles).
const RECT_SALA := Rect2i(1, 1, 6, 4)
const CELDA_PUERTA := Vector2i(6, 4)   # arista "abajo" de esta celda = muro sur

const ESPALDA_NORTE := Vector2i(0, -1)
const ESPALDA_OESTE := Vector2i(-1, 0)
const ESPALDA_SUR := Vector2i(0, 1)

## Margen del test de arrimado, en píxeles de pantalla — misma regla que `_diag_estanterias_arrimadas.gd`.
const TOLERANCIA_PX: float = 3.0

## Los 4 ALTOS: prefijo del render -> [celda, espalda].
const ALTOS := {
	"vending": [Vector2i(3, 1), ESPALDA_NORTE],
	"taquilla": [Vector2i(4, 1), ESPALDA_NORTE],
	"archivador": [Vector2i(1, 2), ESPALDA_OESTE],
	"fuente_agua": [Vector2i(1, 3), ESPALDA_OESTE],
}

## El mostrador de SOBREMESA: 2 celdas, cuerpo hacia el este, contra el muro sur.
const CELDA_MOSTRADOR := Vector2i(3, 4)
const RUTA_MOSTRADOR := "res://assets/sprites/mobiliario/mostrador_atencion2_0.png"

## Los 3 de sobremesa, en el orden en que se reparten sobre el tablero.
const SOBREMESA := ["cafetera", "impresora", "television"]

const CELDA_CIUDADANO := Vector2i(4, 2)

var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
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

	var camara := Camera2D.new()
	sub.add_child(camara)
	camara.make_current()

	var mundo := Node2D.new()
	sub.add_child(mundo)

	# Rejilla TENUE de fondo, por detrás de todo (z muy negativo): solo decoración de referencia.
	var rejilla := Node2D.new()
	mundo.add_child(rejilla)
	_dibujar_rejilla(rejilla)

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

	# ── LA SALA REAL (patrón `_montar` de `_diag_oclusion_murete.gd`) ──────────────────────────
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_espera_doc", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	var ok_puerta: bool = construccion.fijar_tipo_de_muro(CELDA_PUERTA, &"abajo", construccion.PUERTA)
	print("[DEMO PROPS] sala='%s' rect=%s puerta_sur_en=%s ok=%s" % [
		sala, RECT_SALA, CELDA_PUERTA, ok_puerta
	])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)

	var origen: Vector2 = profundo.global_position

	# ── LOS 4 ALTOS, ARRIMADOS A PARED ─────────────────────────────────────────────────────────
	for prefijo: String in ALTOS:
		var datos: Array = ALTOS[prefijo]
		var celda: Vector2i = datos[0]
		var espalda: Vector2i = datos[1]
		var sprite: Sprite2D = _plantar_alto(profundo, prefijo, celda, espalda)
		_test_arrimado(sprite, origen, celda, espalda, prefijo)

	# ── EL MOSTRADOR (sobremesa) + LOS 3 PROPS ENCIMA, A LA ALTURA MEDIDA DEL TABLERO ──────────
	var raiz_mostrador: Node2D = _plantar_mostrador(profundo, CELDA_MOSTRADOR)
	_plantar_sobremesa(raiz_mostrador)

	# ── EL CIUDADANO DE PIE, DE ESCALA ─────────────────────────────────────────────────────────
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", 44)
	muneco.position = ProyeccionScript.centro_iso(CELDA_CIUDADANO)
	profundo.add_child(muneco)

	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DEMO PROPS] ARRIMADO: %d pieza(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])

	# ── CAPTURA 1 — vista general de la sala ───────────────────────────────────────────────────
	camara.zoom = Vector2(2.0, 2.0)
	camara.position = ProyeccionScript.proyectar(Vector2(4.0, 2.5) * float(TAM_CELDA))
	await _capturar(sub, CARPETA_SCRATCH + "demo_props_pipeline.png")

	# ── CAPTURA 2 — zoom a la zona del mostrador con los sobremesa ─────────────────────────────
	camara.zoom = Vector2(4.2, 4.2)
	camara.position = ProyeccionScript.proyectar(Vector2(3.5, 4.0) * float(TAM_CELDA))
	await _capturar(sub, CARPETA_SCRATCH + "demo_props_pipeline_mostrador.png")

	print("[DEMO PROPS] hecho.")
	get_tree().quit()


## Carga un render externo del scratchpad (no importado): `Image.load_from_file` + `ImageTexture`.
func _cargar_scratch(prefijo: String, rotacion: int) -> Texture2D:
	var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, prefijo, rotacion]
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_error("[DEMO PROPS] no se pudo cargar '%s'" % ruta)
		return null
	return ImageTexture.create_from_image(img)


## Qué rotación (0° o 90°) de este render deja el eje CORTO alineado con la pared pedida —
## `desvio_arrimado` necesita que el mueble dé la espalda por su lado delgado (ver
## `AnclajeSprite.eje_corto`). 180° comparte eje con 0° y 270° con 90°, así que basta probar dos.
func _rotacion_para_pared(prefijo: String, espalda: Vector2i) -> int:
	var eje_deseado: Vector2i = Vector2i(1, 0) if espalda.y == 0 else Vector2i(0, 1)
	for rot: int in [0, 90]:
		var tex: Texture2D = _cargar_scratch(prefijo, rot)
		if tex != null and AnclajeSpriteScript.eje_corto(tex) == eje_deseado:
			return rot
	push_warning("[DEMO PROPS] '%s': ninguna rotación mide el eje corto %s -- uso 0°" % [prefijo, eje_deseado])
	return 0


## Planta un mueble DE PARED de 1 celda, arrimado a su espalda (mismo patrón que
## `_diag_estanterias_arrimadas._plantar_a_mano`, pero cargando el render del scratchpad).
func _plantar_alto(profundo: Node2D, prefijo: String, celda: Vector2i, espalda: Vector2i) -> Sprite2D:
	var rot: int = _rotacion_para_pared(prefijo, espalda)
	var tex: Texture2D = _cargar_scratch(prefijo, rot)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i.ZERO, 1)
	sprite.position = AnclajeSpriteScript.desvio_arrimado(tex, espalda)
	var caja := Node2D.new()
	caja.add_child(sprite)
	var raiz := Node2D.new()
	raiz.name = prefijo
	raiz.position = ProyeccionScript.centro_iso(celda)
	raiz.add_child(caja)
	profundo.add_child(raiz)
	print("[DEMO PROPS] %s: PNG rot=%d %dx%d celda=%s espalda=%s desvío=%s" % [
		prefijo, rot, tex.get_width(), tex.get_height(), celda, espalda, sprite.position,
	])
	return sprite


## El test numérico del arrimado (calco de `_diag_estanterias_arrimadas._test_arrimado`): compara
## el borde TRASERO real de la base contra la línea de pared esperada. ±3 px = PASA.
func _test_arrimado(
	sprite: Sprite2D, origen: Vector2, celda: Vector2i, espalda: Vector2i, etiqueta: String
) -> void:
	if sprite == null or sprite.texture == null:
		push_error("[DEMO PROPS %s] SIN sprite -- test no aplicable" % etiqueta)
		_veredictos[etiqueta] = false
		return
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(sprite.texture)
	var semieje_fondo: float = semiejes.y if espalda.x == 0 else semiejes.x
	var centro_pantalla: Vector2 = (
		sprite.global_position + sprite.offset + AnclajeSpriteScript.centro_base(sprite.texture)
	)
	var centro_cuadrado: Vector2 = ProyeccionScript.desproyectar(centro_pantalla - origen)
	var trasero_cuadrado: Vector2 = centro_cuadrado + Vector2(espalda) * semieje_fondo
	var real: Vector2 = origen + ProyeccionScript.proyectar(trasero_cuadrado)
	var linea_cuadrado: Vector2 = (
		ProyeccionScript.centro_cuadrado(celda) + Vector2(espalda) * (TAM_CELDA * 0.5)
	)
	var esperado: Vector2 = origen + ProyeccionScript.proyectar(linea_cuadrado)
	var delta: Vector2 = real - esperado
	var pasa: bool = absf(delta.x) <= TOLERANCIA_PX and absf(delta.y) <= TOLERANCIA_PX
	print("[DEMO PROPS ARRIMADO %s] celda=%s espalda=%s fondo=%.2f px | ESPERADO=%s REAL=%s | DELTA=%s (|%.2f| px) -> %s" % [
		etiqueta, celda, espalda, semieje_fondo * 2.0, esperado, real, delta, delta.length(),
		"PASA" if pasa else "FALLA",
	])
	_veredictos[etiqueta] = pasa


## El mostrador del catálogo (2 celdas, cuerpo este), arrimado por dentro al muro sur. Devuelve su
## raíz (para colgarle encima los 3 de sobremesa, DESPUÉS del sprite, y que se dibujen por delante).
func _plantar_mostrador(profundo: Node2D, primera_celda: Vector2i) -> Node2D:
	var tex: Texture2D = load(RUTA_MOSTRADOR)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 2)
	sprite.position = AnclajeSpriteScript.desvio_arrimado(tex, ESPALDA_SUR)
	var caja := Node2D.new()
	caja.name = "Caja"
	caja.add_child(sprite)
	var raiz := Node2D.new()
	raiz.name = "Mostrador"
	# Convención del proyecto: el nodo vive en el centro de la ÚLTIMA celda del cuerpo.
	var ultima: Vector2i = primera_celda + Vector2i(1, 0) * (2 - 1)
	raiz.position = ProyeccionScript.centro_iso(ultima)
	raiz.add_child(caja)
	profundo.add_child(raiz)
	print("[DEMO PROPS] mostrador: PNG %dx%d celdas=%s..%s desvío=%s" % [
		tex.get_width(), tex.get_height(), primera_celda, ultima, sprite.position,
	])
	return raiz


## Mide, POR COLUMNA, la fila opaca más alta del PNG del mostrador (nada a ojo). El PNG trae YA un
## monitor propio de fábrica (bulto estrecho que sobresale por encima del cuerpo) y, al ser el
## mostrador un cuerpo LARGO visto en isométrico, su borde superior no es una línea horizontal: cae
## en PENDIENTE (más alto -menor fila- hacia un extremo, más bajo hacia el otro). Un solo número
## global para "la altura del tablero" está mal en los dos frentes a la vez -- primera pasada: usar
## la fila opaca más alta del PNG entero cogía el TOPE DEL MONITOR (los 3 aparatos salían flotando);
## segunda pasada: una MEDIANA global aplicada a las tres columnas dejaba el aparato del extremo
## fuera de la silueta real de esa columna (la pendiente lo dejaba flotando igual, solo que menos).
## Aquí se mide la fila-tope de CADA columna y se guarda entera: quien coloca un aparato en una
## columna X pide `_fila_en(X)`, que sí sigue la pendiente real de esa columna, amortiguada con la
## MEDIANA de una ventana de columnas vecinas (10 px a cada lado) para no colarse por el hueco
## estrecho del monitor si cae justo ahí.
func _medir_superficie_tablero(textura: Texture2D) -> Dictionary:
	var img: Image = textura.get_image()
	if img.is_compressed():
		img.decompress()
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	var min_x: int = ancho
	var max_x: int = -1
	var filas_por_columna: Array[int] = []
	filas_por_columna.resize(ancho)
	for px: int in range(ancho):
		var top: int = -1
		for py: int in range(alto):
			if img.get_pixel(px, py).a > 0.05:
				top = py
				break
		filas_por_columna[px] = top
		if top >= 0:
			min_x = mini(min_x, px)
			max_x = maxi(max_x, px)
	print("[DEMO PROPS] superficie del tablero: PNG %dx%d | silueta x∈[%d,%d] | fila-tope en el extremo izq=%d, centro=%d, extremo der=%d (pendiente medida, no un solo número)" % [
		ancho, alto, min_x, max_x,
		filas_por_columna[min_x] if max_x >= min_x else -1,
		filas_por_columna[int((min_x + max_x) * 0.5)] if max_x >= min_x else -1,
		filas_por_columna[max_x] if max_x >= min_x else -1,
	])
	return {"min_x": min_x, "max_x": max_x, "filas_por_columna": filas_por_columna}


## La fila-tope EN una columna (`x`, entero de PNG), amortiguada con la mediana de una ventana de
## columnas vecinas -- para no meterse por el hueco estrecho del monitor de fábrica si `x` cae ahí.
func _fila_en(filas_por_columna: Array, x: int, min_x: int, max_x: int, ventana: int = 10) -> int:
	var muestras: Array[int] = []
	for dx: int in range(-ventana, ventana + 1):
		var cx: int = clampi(x + dx, min_x, max_x)
		var v: int = filas_por_columna[cx]
		if v >= 0:
			muestras.append(v)
	if muestras.is_empty():
		return 0
	muestras.sort()
	return muestras[muestras.size() / 2]


## Los 3 props de sobremesa, anclados con `AnclajeSprite` sobre la superficie MEDIDA del mostrador
## (dentro de su silueta, no al lado, y siguiendo su pendiente real): uno a un tercio del tablero,
## otro al centro, otro a dos tercios -- para que se lean sentados ENCIMA, con solape visual, y no
## apelotonados en una esquina.
func _plantar_sobremesa(raiz_mostrador: Node2D) -> void:
	var sprite_mostrador: Sprite2D = raiz_mostrador.get_node("Caja/Sprite") as Sprite2D
	var datos: Dictionary = _medir_superficie_tablero(sprite_mostrador.texture)
	var min_x: int = datos["min_x"]
	var max_x: int = datos["max_x"]
	var filas_por_columna: Array = datos["filas_por_columna"]
	# Base de pantalla del PNG (pixel local (0,0) del mostrador, YA con su offset de ancla y su
	# desvío de arrimado aplicados): sumar aquí cualquier píxel local (x, fila) da el punto de
	# pantalla real donde cae ese píxel del tablero.
	var base_pantalla: Vector2 = sprite_mostrador.global_position + sprite_mostrador.offset

	var fracciones: Array[float] = [1.0 / 3.0, 0.5, 2.0 / 3.0]
	for i: int in range(SOBREMESA.size()):
		var prefijo: String = SOBREMESA[i]
		var tex: Texture2D = _cargar_scratch(prefijo, 0)
		var x_local: int = min_x + int(round(float(max_x - min_x) * fracciones[i]))
		var fila: int = _fila_en(filas_por_columna, x_local, min_x, max_x)
		var punto_superficie: Vector2 = base_pantalla + Vector2(float(x_local), float(fila))
		var centro_item: Vector2 = AnclajeSpriteScript.centro_base(tex)
		var item_sprite := Sprite2D.new()
		item_sprite.name = "Sprite"
		item_sprite.texture = tex
		item_sprite.centered = false
		item_sprite.offset = -centro_item
		var item_raiz := Node2D.new()
		item_raiz.name = prefijo
		item_raiz.position = punto_superficie - raiz_mostrador.global_position
		item_raiz.add_child(item_sprite)
		raiz_mostrador.add_child(item_raiz)   # DESPUÉS de "Caja": se dibuja por delante del tablero.
		print("[DEMO PROPS] sobremesa '%s': PNG %dx%d en x_local=%d fila=%d (fracción %.2f) -> superficie=%s (local=%s)" % [
			prefijo, tex.get_width(), tex.get_height(), x_local, fila, fracciones[i], punto_superficie, item_raiz.position,
		])


## Rejilla TENUE de referencia (solo decorativa), por detrás de toda la escena.
func _dibujar_rejilla(mundo: Node2D) -> void:
	var contorno := Node2D.new()
	contorno.z_index = -100
	mundo.add_child(contorno)
	for x: int in range(0, 9):
		for y: int in range(0, 8):
			var borde := Line2D.new()
			borde.width = 1.0
			borde.default_color = Color(1.0, 1.0, 1.0, 0.08)
			borde.closed = true
			borde.points = PackedVector2Array([
				ProyeccionScript.esquina_iso(x, y), ProyeccionScript.esquina_iso(x + 1, y),
				ProyeccionScript.esquina_iso(x + 1, y + 1), ProyeccionScript.esquina_iso(x, y + 1),
			])
			contorno.add_child(borde)


func _capturar(sub: SubViewport, ruta: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DEMO PROPS] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DEMO PROPS] captura -> %s" % ruta)
