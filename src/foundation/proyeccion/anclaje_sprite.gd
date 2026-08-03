class_name AnclajeSprite
## AnclajeSprite — dónde se clava un sprite de MOBILIARIO dentro de su huella, CALCULADO de los
## límites medidos del PNG. Ni una constante a mano.
##
## ── LA LEY (usuario, 2026-08-03) ───────────────────────────────────────────────────────────────
## *"Un objeto no puede salir de sus celdas — sabes los límites del objeto y los límites de las
## celdas."* Hasta hoy cada mueble traía su `ANCLA_FRACCION_*` escrita a mano en el código
## (`mesa_atencion.gd`, `construccion.gd`): una fracción del ancho/alto del PNG medida a ojo sobre
## la imagen y copiada al fichero. Cada re-render del arte dejaba esas fracciones desfasadas sin
## que nada lo delatara, y encima se apilaban "desvíos" de corrección igual de manuales
## (`DESVIO_CENTRADO_MESA*`) que tapaban unos errores con otros. Tres arreglos seguidos del
## mostrador de 2 celdas fallaron por esa cadena. Este fichero la sustituye entera: el juego MIDE
## el PNG al cargarlo y deduce el ancla. Si el arte cambia, el ancla cambia sola.
##
## ── QUÉ SE MIDE, Y POR QUÉ ESO BASTA ──────────────────────────────────────────────────────────
## De la silueta opaca del PNG se sacan TRES números: la columna opaca más a la izquierda
## (`min_x`), la más a la derecha (`max_x`) y la FILA opaca más baja (`max_y`). Con la proyección
## 2:1 de `Proyeccion` eso determina por completo la BASE del mueble (el rectángulo de suelo que
## pisa), sin necesidad de distinguir qué píxel es "mueble" y qué píxel es "altura":
##
##  · Un mueble es, para la cámara, una caja: su silueta es la base más esa misma base subida su
##    altura. Subir NO cambia la x de nada, así que los extremos horizontales de la silueta son,
##    exactamente, los vértices OESTE y ESTE de la base. → el CENTRO horizontal de la base es
##    `(min_x + max_x + 1) / 2`.
##  · La fila más baja es el vértice SUR de la base (nada del mueble se dibuja por debajo del
##    suelo que pisa). → la Y del vértice sur es `max_y + 1` (el borde inferior de esa fila: el
##    píxel `n` cubre el intervalo continuo `[n, n+1)`).
##  · Y la altura del rombo de la base es SIEMPRE la mitad de su anchura (eso ES el 2:1). Un
##    rectángulo de suelo de lados `a`×`b` proyecta un paralelogramo de `a+b` de ancho y `(a+b)/2`
##    de alto, mida lo que mida cada lado. → del vértice sur al centro de la base hay
##    `(max_x + 1 - min_x) / 4` píxeles hacia arriba.
##
## ── LA SEMÁNTICA DEL "PUNTO SUR" (la ambigüedad que causó el bug — decidida y documentada) ─────
## El intento anterior tomaba como punto sur el CENTRO de la fila opaca más baja. Parece lo mismo
## y no lo es: esa fila mide varios píxeles de ancho (el rombo se estrecha hasta la punta pero el
## rasterizado no llega a 1 px), y su centro sí cae bajo el vértice… **solo si la base es
## CUADRADA**. La del mostrador no lo es (2,00 celdas de largo por ~0,44 de fondo): su vértice sur
## está muy escorado hacia el ESTE respecto del centro de la base, y usar su x como si fuera el
## centro metía el mueble media celda de lado. Por eso aquí la x del punto sur NO se usa: solo se
## usa su **Y** (la más baja), y la x sale de los extremos horizontales, que no dependen de la
## forma del rectángulo. Es la misma cuenta analítica que hace el render al elegir su ancla
## (`tools/render_mobiliario.gd`: centro X/Z de la AABB al nivel del suelo), reconstruida desde
## los píxeles.
##
## ── DÓNDE ATERRIZA ────────────────────────────────────────────────────────────────────────────
## El centro de la base se planta en el CENTRO DE LA HUELLA lógica (las `celdas` reservadas por el
## modelo). Con eso el mueble queda dentro de sus celdas por construcción y centrado en ellas: es
## la lectura literal de la ley del usuario.
##
## Como el nodo que lleva el sprite se coloca en la ÚLTIMA celda del cuerpo (convención de todo el
## proyecto — `Proyeccion.delta_ultima_celda`), el ancla que se devuelve es el píxel del PNG que
## corresponde al centro de ESA celda: el centro de la base más medio `delta_ultima_celda`. Con 1
## celda el delta es cero y el ancla es, sin más, el centro de la base.
##
## ── COSTE ─────────────────────────────────────────────────────────────────────────────────────
## Se escanea el PNG UNA vez por textura y se cachea por `resource_path` (`_cache_centro`). Un
## mostrador de 100×74 son ~7.400 lecturas de píxel una sola vez en toda la partida, y los barridos
## salen por la primera fila/columna que encuentran opaca. Nada de esto ocurre en `_process`.

## Alfa por encima del cual un píxel cuenta como "mueble". 0,05 deja fuera el borde antialiaseado
## casi transparente del recorte y nada más (verificado: los PNG de mobiliario no traen sombra
## suave que se derrame por el lienzo — su silueta es el mueble).
const UMBRAL_ALFA: float = 0.05

## Centro de la base ya medido, por `resource_path` de la textura. Las texturas sin ruta en disco
## (generadas en memoria) no se cachean: no tienen clave estable.
static var _cache_centro: Dictionary[String, Vector2] = {}


## El píxel del PNG que debe caer sobre el nodo del sprite, sabiendo que ese nodo vive en el centro
## de la ÚLTIMA celda del cuerpo (`Proyeccion.delta_ultima_celda(paso, celdas)` desde la celda
## ancla del modelo). Es lo que hay que meter, cambiado de signo, en `Sprite2D.offset`.
##
## Ejemplo (mostrador de 2 celdas, cuerpo hacia el este):
## [codeblock]
## var sprite := Sprite2D.new()
## sprite.texture = load("res://assets/sprites/mobiliario/mostrador_atencion2_0.png")
## AnclajeSprite.aplicar(sprite, Vector2i(1, 0), 2)   # centered=false + offset ya puestos
## [/codeblock]
static func ancla_px(textura: Texture2D, paso: Vector2i, celdas: int) -> Vector2:
	return centro_base(textura) + Proyeccion.delta_ultima_celda(paso, celdas) * 0.5


## Deja el `Sprite2D` anclado por su base: `centered = false` y el `offset` que toca. Es la ÚNICA
## forma admitida de colocar un sprite de mobiliario (nada de fracciones de ancla escritas a mano).
static func aplicar(sprite: Sprite2D, paso: Vector2i, celdas: int) -> void:
	sprite.centered = false
	if sprite.texture == null:
		push_error("AnclajeSprite: sprite '%s' sin textura — no se puede anclar" % sprite.name)
		return
	sprite.offset = -ancla_px(sprite.texture, paso, celdas)


## El CENTRO de la base del mueble, en píxeles continuos del PNG (ver la cabecera). Cacheado.
static func centro_base(textura: Texture2D) -> Vector2:
	if textura == null:
		push_error("AnclajeSprite: textura nula")
		return Vector2.ZERO
	var clave: String = textura.resource_path
	if clave != "" and _cache_centro.has(clave):
		return _cache_centro[clave]
	var centro: Vector2 = _medir_centro_base(textura)
	if clave != "":
		_cache_centro[clave] = centro
	return centro


## Vacía la caché de medidas. Solo para tests y herramientas que recargan texturas en caliente.
static func limpiar_cache() -> void:
	_cache_centro.clear()


## El barrido de píxeles de verdad. Tres extremos de la silueta opaca (`min_x`, `max_x`, `max_y`) y
## la cuenta de la cabecera. Devuelve el centro del lienzo si la textura sale vacía (nada que
## medir), para no propagar un NaN.
static func _medir_centro_base(textura: Texture2D) -> Vector2:
	var img: Image = textura.get_image()
	if img == null:
		push_error("AnclajeSprite: textura '%s' sin imagen legible" % textura.resource_path)
		return Vector2.ZERO
	if img.is_compressed():
		img.decompress()
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	var min_x: int = -1
	for px: int in range(ancho):
		if _columna_opaca(img, px, alto):
			min_x = px
			break
	if min_x < 0:
		push_warning("AnclajeSprite: textura '%s' totalmente transparente" % textura.resource_path)
		return Vector2(float(ancho) * 0.5, float(alto) * 0.5)
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if _columna_opaca(img, px, alto):
			max_x = px
			break
	var max_y: int = 0
	for py: int in range(alto - 1, -1, -1):
		if _fila_opaca(img, py, ancho):
			max_y = py
			break
	# Anchura del rombo de la base = anchura de la silueta; su ALTO es la mitad, así que del vértice
	# sur al centro hay un cuarto de esa anchura hacia arriba (ver la cabecera).
	var anchura: float = float(max_x + 1 - min_x)
	return Vector2(
		(float(min_x) + float(max_x) + 1.0) * 0.5,
		float(max_y) + 1.0 - anchura * 0.25
	)


static func _columna_opaca(img: Image, px: int, alto: int) -> bool:
	for py: int in range(alto):
		if img.get_pixel(px, py).a > UMBRAL_ALFA:
			return true
	return false


static func _fila_opaca(img: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if img.get_pixel(px, py).a > UMBRAL_ALFA:
			return true
	return false
