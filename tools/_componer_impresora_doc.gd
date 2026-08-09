extends Node2D
## _componer_impresora_doc — DESECHABLE, fase de PROPUESTA (2026-08-05).
##
## Aplana `cajonera_doc_<rot>.png` (`_render_impresora_doc.gd`, este scratchpad) + el sprite YA
## RENDERIZADO de la impresora de sobremesa (`assets/sprites/mobiliario/impresora_<rot>.png`,
## SOLO LECTURA — el mismo modelo de `capturas/fuentes/props_poly/impresora.glb`, 0,50 m real) en
## UN SOLO PNG por rotación — precedente `ID_RADIO` / `_componer_props_soporte.gd` ("aparato
## horneado sobre la cajonera EN EL MISMO sprite").
##
## Mismo método de alineación que el precedente: `AnclajeSprite.centro_base()` mide dónde "pisa el
## suelo" cada PNG por separado (ambos calibrados contra la MISMA convención PX_POR_METRO = 44px/
## 1,70m y la MISMA cámara isométrica fija 30°/45°), se centran horizontalmente y se desplaza el
## aparato verticalmente `ALTURA_TAPA_M * PX_POR_METRO` px hacia arriba (0,675 m, la tapa de la
## cajonera — constante fija, no depende de la rotación en cámara isométrica de elevación fija).
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"
const CARPETA_APARATO := "res://assets/sprites/mobiliario/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const ALTURA_TAPA_M: float = 0.675
const ROTACIONES: Array[int] = [0, 90, 180, 270]

## Margen extra alrededor del lienzo compuesto (aire para que ninguna pieza se recorte).
const MARGEN_LIENZO_PX: int = 8


func _ready() -> void:
	for rot: int in ROTACIONES:
		_componer_uno(rot)
	print("[COMPONER IMPRESORA DOC] hecho.")
	get_tree().quit()


func _cargar_scratch(ruta: String) -> Image:
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_error("[COMPONER IMPRESORA DOC] no se pudo cargar '%s'" % ruta)
	return img


## El aparato viene de `res://assets/sprites/mobiliario/`, un recurso IMPORTADO del proyecto — se
## carga con `load()` (no `Image.load_from_file()`, que es para los PNG sueltos del scratchpad).
func _cargar_aparato(rot: int) -> Image:
	var ruta: String = "%simpresora_%d.png" % [CARPETA_APARATO, rot]
	var tex: Texture2D = load(ruta)
	if tex == null:
		push_error("[COMPONER IMPRESORA DOC] no se pudo cargar '%s'" % ruta)
		return null
	return tex.get_image()


func _componer_uno(rot: int) -> void:
	var ruta_cajonera: String = "%scajonera_doc_%d.png" % [CARPETA_SCRATCH, rot]
	var img_cajonera: Image = _cargar_scratch(ruta_cajonera)
	var img_aparato: Image = _cargar_aparato(rot)
	if img_cajonera == null or img_aparato == null:
		return

	var tex_cajonera: ImageTexture = ImageTexture.create_from_image(img_cajonera)
	var tex_aparato: ImageTexture = ImageTexture.create_from_image(img_aparato)
	var centro_cajonera: Vector2 = AnclajeSpriteScript.centro_base(tex_cajonera)
	var centro_aparato: Vector2 = AnclajeSpriteScript.centro_base(tex_aparato)

	# Punto de anclaje COMÚN del compuesto: el centro de base de la cajonera. El aparato se
	# desplaza para que SU centro de base caiga `ALTURA_TAPA_M*PX_POR_METRO` px por encima de ese
	# mismo punto (mismo X, Y restado).
	var desplazamiento_vertical_px: float = ALTURA_TAPA_M * PX_POR_METRO
	var destino_aparato: Vector2 = centro_cajonera - Vector2(0.0, desplazamiento_vertical_px)
	var offset_aparato: Vector2 = destino_aparato - centro_aparato

	var min_x: float = minf(0.0, offset_aparato.x)
	var min_y: float = minf(0.0, offset_aparato.y)
	var max_x: float = maxf(float(img_cajonera.get_width()), offset_aparato.x + float(img_aparato.get_width()))
	var max_y: float = maxf(float(img_cajonera.get_height()), offset_aparato.y + float(img_aparato.get_height()))
	var ancho: int = ceili(max_x - min_x) + MARGEN_LIENZO_PX * 2
	var alto: int = ceili(max_y - min_y) + MARGEN_LIENZO_PX * 2
	var origen := Vector2i(MARGEN_LIENZO_PX - roundi(min_x), MARGEN_LIENZO_PX - roundi(min_y))

	var lienzo := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	lienzo.blit_rect(img_cajonera, Rect2i(Vector2i.ZERO, img_cajonera.get_size()), origen)
	var destino_aparato_px := Vector2i(origen) + Vector2i(roundi(offset_aparato.x), roundi(offset_aparato.y))
	lienzo.blend_rect(img_aparato, Rect2i(Vector2i.ZERO, img_aparato.get_size()), destino_aparato_px)

	var alto_util_px: int = _medir_alto(lienzo)
	var ruta_salida: String = "%simpresora_doc_v1_%d.png" % [CARPETA_SCRATCH, rot]
	var err: Error = lienzo.save_png(ruta_salida)
	if err != OK:
		push_error("[COMPONER IMPRESORA DOC] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[COMPONER IMPRESORA DOC] %d: cajonera %dx%d + aparato %dx%d -> %dx%d, alto util silueta=%dpx (%.3fm) -> %s" % [
			rot, img_cajonera.get_width(), img_cajonera.get_height(),
			img_aparato.get_width(), img_aparato.get_height(), ancho, alto,
			alto_util_px, float(alto_util_px) / PX_POR_METRO, ruta_salida
		])


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
