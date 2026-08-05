extends Node2D
## _componer_props_soporte — DESECHABLE, fase de PROPUESTA (2026-08-05).
##
## Aplana `cajonera_sola_<rot>.png` (`_render_cajonera_soporte.gd`) + cada aparato de sobremesa YA
## RENDERIZADO (`cafetera_0.png`/`impresora_0.png`/`television_0.png`, de `_render_props_nuevos.gd`
## v2 -- sin tocar, el usuario no objetó su TAMAÑO, solo la falta de soporte) en UN SOLO PNG por
## rotación -- precedente `ID_RADIO` ("aparato horneado sobre la cajonera EN EL MISMO sprite").
##
## CÓMO SE ALINEAN dos PNG que vienen de pasadas de render DISTINTAS (cajonera: pipeline propio de
## `render_mobiliario.gd`, aparato: pipeline v2 de `_render_props_nuevos.gd`) pero AMBOS calibrados
## contra la MISMA convención `PX_POR_METRO` (44 px = 1,70 m, el muñeco de referencia del proyecto)
## y la MISMA cámara isométrica fija (30°/45°, ver la cabecera de `render_mobiliario.gd`):
##   1. `AnclajeSprite.centro_base(textura)` mide, de los píxeles de CADA PNG por separado, el punto
##      donde ese objeto "pisa el suelo" -- exactamente el mismo cálculo analítico que usa el JUEGO
##      para anclar cualquier sprite de mobiliario, sin medir nada a ojo.
##   2. Alinear los dos centros HORIZONTALMENTE (mismo X) centra el aparato sobre la cajonera.
##   3. El desplazamiento VERTICAL es constante y NO depende de la rotación (una cámara isométrica a
##      elevación fija mapea "arriba en el mundo" a "arriba en pantalla" igual para las 4 rotaciones
##      -- girar el objeto sobre su eje Y no cambia esa relación): `ALTURA_TAPA_M * PX_POR_METRO` px
##      hacia arriba, la altura real de la tapa de la cajonera (0,675 m, la misma cifra que usa
##      `DESPLAZAMIENTO_RADIO` en `render_mobiliario.gd`).
##
## Los PNG NO son recursos importados (viven en el scratchpad): se cargan con
## `Image.load_from_file()` + `ImageTexture.create_from_image()`, no con `load()`.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const ALTURA_TAPA_M: float = 0.675
const ROTACIONES: Array[int] = [0, 90, 180, 270]

const APARATOS: Array[String] = ["cafetera", "impresora", "television"]

## Margen extra alrededor del lienzo compuesto (aire para que ninguna pieza se recorte).
const MARGEN_LIENZO_PX: int = 8


func _ready() -> void:
	for id: String in APARATOS:
		for rot: int in ROTACIONES:
			_componer_uno(id, rot)
	print("[COMPONER PROPS SOPORTE] hecho.")
	get_tree().quit()


func _cargar(ruta: String) -> Image:
	var img: Image = Image.load_from_file(ruta)
	if img == null:
		push_error("[COMPONER PROPS SOPORTE] no se pudo cargar '%s'" % ruta)
	return img


func _componer_uno(id: String, rot: int) -> void:
	var ruta_cajonera: String = "%scajonera_sola_%d.png" % [CARPETA_SCRATCH, rot]
	var ruta_aparato: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id, rot]
	var img_cajonera: Image = _cargar(ruta_cajonera)
	var img_aparato: Image = _cargar(ruta_aparato)
	if img_cajonera == null or img_aparato == null:
		return

	var tex_cajonera: ImageTexture = ImageTexture.create_from_image(img_cajonera)
	var tex_aparato: ImageTexture = ImageTexture.create_from_image(img_aparato)
	var centro_cajonera: Vector2 = AnclajeSpriteScript.centro_base(tex_cajonera)
	var centro_aparato: Vector2 = AnclajeSpriteScript.centro_base(tex_aparato)

	# Punto de anclaje COMÚN del compuesto (arbitrario, dentro del lienzo): el centro de base de la
	# cajonera. El aparato se desplaza para que SU centro de base caiga `ALTURA_TAPA_M*PX_POR_METRO`
	# px por encima de ese mismo punto (mismo X, Y restado -- ver la cabecera).
	var desplazamiento_vertical_px: float = ALTURA_TAPA_M * PX_POR_METRO
	var destino_aparato: Vector2 = centro_cajonera - Vector2(0.0, desplazamiento_vertical_px)
	var offset_aparato: Vector2 = destino_aparato - centro_aparato  # a sumar a cada píxel del aparato

	# Lienzo: suficientemente grande para las dos imágenes en sus posiciones relativas, con margen.
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

	var ruta_salida: String = "%s%s_soporte_%d.png" % [CARPETA_SCRATCH, id, rot]
	var err: Error = lienzo.save_png(ruta_salida)
	if err != OK:
		push_error("[COMPONER PROPS SOPORTE] save_png '%s' fallo (error %d)" % [ruta_salida, err])
	else:
		print("[COMPONER PROPS SOPORTE] %s_%d: cajonera %dx%d + aparato %dx%d -> %dx%d -> %s" % [
			id, rot, img_cajonera.get_width(), img_cajonera.get_height(),
			img_aparato.get_width(), img_aparato.get_height(), ancho, alto, ruta_salida
		])
