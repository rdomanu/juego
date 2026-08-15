class_name SombraContacto
## SombraContacto — la elipse de sombra de contacto que se dibuja bajo muebles y NPCs.
##
## Decisión visual cerrada con el usuario (2026-08-14): alfa máximo 0,30 en el centro, color casi
## negro (10,10,15) y una caída suave `ALFA_PICO · (1 − r²)^EXPONENTE_CAIDA` — el exponente > 1
## aplana el centro (una base real no proyecta un pico puntiagudo) sin llegar a la dureza de un
## borde recortado en seco.
##
## ── LA GEOMETRÍA: SE DIBUJA EN EL SUELO, NO EN PANTALLA ──────────────────────────────────────────
## La sombra NO es un círculo de pantalla: es un CÍRCULO UNIDAD del PLANO LÓGICO DEL SUELO (el mismo
## plano cuadrado de `Proyeccion` — ver la cabecera de ese fichero para la distinción completa entre
## "plano lógico" y "plano de pantalla"), que se PROYECTA con la MISMA transformada que cualquier
## otra cosa pegada al suelo: 1 píxel lógico del eje u (este) mueve la pantalla `(1, MEDIO_ALTO /
## MEDIO_ANCHO)` y 1 píxel lógico del eje v (sur) la mueve `(−1, MEDIO_ALTO / MEDIO_ANCHO)` — ver
## `Proyeccion.transformada`, que es LITERALMENTE esta misma cuenta para el suelo (TileMapLayer). Por
## eso un mueble ANCHO por el eje este proyecta una sombra ancha EN LA DIRECCIÓN CORRECTA del rombo
## isométrico, en vez de un círculo de pantalla ciego a la perspectiva.
##
## No depende de nada del juego (solo de `Proyeccion`, que ya vive en `foundation/`): cualquier capa
## puede pedir una sombra sin invertir la dirección de dependencias (regla de motor).
##
## `class_name` NO resuelve siempre en headless "en frío" (gotcha conocido del proyecto): quien
## consuma esta clase desde otro script debe preloadearla con un alias (`SombraContactoScript`),
## como ya hacen los consumidores de `AnclajeSprite`/`Proyeccion`.

## Alfa en el CENTRO de la sombra (r = 0). Decisión cerrada con el usuario — no se toca sin su OK.
const ALFA_PICO: float = 0.30
## Color de la sombra: casi negro con un pelín de azul, NUNCA negro puro — mismo criterio que
## `Muneco.COLOR_OJOS` (a tamaño de juego el negro puro "agujerea" la imagen en vez de leerse como
## sombra).
const COLOR_SOMBRA := Color8(10, 10, 15)
## Exponente de la caída del alfa: `alfa(r) = ALFA_PICO · (1 − r²)^EXPONENTE_CAIDA`. Cerrado con el
## usuario — no es 1.0 (una caída lineal en r² se ve como un disco con borde duro) ni mucho mayor
## (se perdería el cuerpo de la sombra y quedaría solo un halo).
const EXPONENTE_CAIDA: float = 1.2
## Radio de la sombra de un NPC, en píxeles LÓGICOS del plano del suelo (no de pantalla): un círculo
## bajo los pies, ni tan grande que parezca una peana ni tan pequeño que se pierda bajo el personaje.
const RADIO_NPC: float = 8.0
## Semieje MÍNIMO (px lógicos, por eje) de la sombra de un MUEBLE. Cazado en el juego real
## (2026-08-14, sonda `_diag_sombras`): `semiejes_base` mide el rect de APOYO —las patas—, y una
## silla de madera pisa solo (5,25 × 5,25) y la estantería suelta 2,75 de fondo: sombras fieles a
## las patas e INVISIBLES de puro pequeñas. La sombra debe leer el BULTO del mueble, no sus patitas
## — en la hoja de decisión que aprobó el usuario la silla llevaba ~10. El largo medido se respeta
## (el banco sigue en sus 19,25): solo se levanta el eje que se queda corto. Los NPC NO pasan por
## aquí (su `RADIO_NPC` aprobado es 8 y las piernas de un muñeco sí son su bulto).
const SEMIEJE_MINIMO_MUEBLE: float = 9.0

## Lado de la textura generada, en píxeles. 64 da resolución de sobra para que la caída no se note a
## escalones a la escala de juego (una celda mide 40 px lógicos).
const LADO_TEXTURA: int = 64
## Radio del círculo dentro de esa textura (mitad del lado): el resto del lienzo queda transparente.
const RADIO_TEXTURA: float = LADO_TEXTURA / 2.0

## La textura radial, generada por código UNA vez y CACHEADA — nunca en `_process` (regla de motor:
## cero asignaciones en el camino caliente). Es BLANCA con alfa = `(1 − r²)^EXPONENTE_CAIDA` puro
## (sin `ALFA_PICO` todavía): el color y el tope de alfa de verdad los pone `modulate` en el sprite
## que la usa (`crear_sprite`), así que esta MISMA textura sirve para cualquier sombra del juego sin
## regenerarse.
static var _textura_cache: ImageTexture = null


## La textura cacheada — se genera la primera vez que se pide. Misma instancia en llamadas
## sucesivas (verificado por test): no hay que regenerar el `Image` en cada mueble o NPC nuevo.
static func textura() -> ImageTexture:
	if _textura_cache == null:
		_textura_cache = _generar_textura()
	return _textura_cache


## Dibuja la elipse de sombra SOBRE UN LIENZO ajeno (llamar SOLO desde el `_draw()` de ese
## lienzo): el círculo unidad de la textura proyectado al suelo, centrado en `centro` (coordenadas
## locales del lienzo) con los semiejes dados. Es el camino que usa `CapaSombras` — el lienzo único
## que pinta todas las sombras del juego (ver su cabecera: por qué NO se usan nodos por mueble).
static func dibujar(lienzo: CanvasItem, centro: Vector2, semiejes_suelo: Vector2) -> void:
	var eje_u: Vector2 = Vector2(1.0, Proyeccion.MEDIO_ALTO / Proyeccion.MEDIO_ANCHO)
	var eje_v: Vector2 = Vector2(-1.0, Proyeccion.MEDIO_ALTO / Proyeccion.MEDIO_ANCHO)
	lienzo.draw_set_transform_matrix(Transform2D(
		eje_u * (semiejes_suelo.x / RADIO_TEXTURA), eje_v * (semiejes_suelo.y / RADIO_TEXTURA),
		centro
	))
	lienzo.draw_texture(
		textura(), Vector2(-RADIO_TEXTURA, -RADIO_TEXTURA),
		Color(COLOR_SOMBRA.r, COLOR_SOMBRA.g, COLOR_SOMBRA.b, ALFA_PICO)
	)
	lienzo.draw_set_transform_matrix(Transform2D.IDENTITY)


## Un `Sprite2D` con la sombra ya lista, del tamaño que le corresponde a `semiejes_suelo` — los
## semiejes de la base EN EL PLANO LÓGICO DEL SUELO, en píxeles (la misma unidad y el mismo orden de
## ejes que devuelve `AnclajeSprite.semiejes_base`: `x` a lo largo del este/oeste, `y` a lo largo del
## norte/sur; para un NPC, `Vector2(RADIO_NPC, RADIO_NPC)`). Centrado en `(0,0)` local: quien lo
## cuelgue lo coloca en el centro geométrico de la huella que proyecta sombra.
##
## LA PROYECCIÓN (ver la cabecera): el círculo unidad de la textura —de radio `RADIO_TEXTURA` en
## local, porque `Sprite2D` nace `centered = true`— se estira a la elipse de semiejes
## `semiejes_suelo` del plano del suelo y ESA elipse se proyecta a pantalla con la transformada de
## `Proyeccion`. El `Transform2D` del sprite es, literalmente, esa transformada con las columnas
## escaladas por `semiejes_suelo / RADIO_TEXTURA` (para que el radio 32 de la textura se convierta en
## el semieje que toca) y origen en `(0,0)` (el centrado ya lo pone quien coloca el sprite).
##
## ⚠️ GOTCHA DEL ÁRBOL REAL (2026-08-14, cazado con sondas): un CanvasItem creado DURANTE LA CARGA
## como descendiente de `MundoProfundo` (la bolsa y-sort) queda permanentemente SIN RENDERIZAR en
## este juego (propiedades perfectas, cero píxeles; incurable). Por eso el juego NO usa este sprite
## para sus sombras — usa `CapaSombras` (fuera de la bolsa) con `dibujar()`. Este constructor queda
## para tests y para usos fuera de la bolsa.
static func crear_sprite(semiejes_suelo: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sombra"
	sprite.texture = textura()
	sprite.modulate = Color(COLOR_SOMBRA.r, COLOR_SOMBRA.g, COLOR_SOMBRA.b, ALFA_PICO)
	var eje_u: Vector2 = Vector2(1.0, Proyeccion.MEDIO_ALTO / Proyeccion.MEDIO_ANCHO)
	var eje_v: Vector2 = Vector2(-1.0, Proyeccion.MEDIO_ALTO / Proyeccion.MEDIO_ANCHO)
	sprite.transform = Transform2D(
		eje_u * (semiejes_suelo.x / RADIO_TEXTURA), eje_v * (semiejes_suelo.y / RADIO_TEXTURA),
		Vector2.ZERO
	)
	return sprite


## Los semiejes que le tocan a la sombra de un MUEBLE a partir de su medida de apoyo
## (`AnclajeSprite.semiejes_base`): la medida real, pero nunca por debajo de
## `SEMIEJE_MINIMO_MUEBLE` en ninguno de los dos ejes (ver esa constante).
static func semiejes_para_mueble(semiejes_apoyo: Vector2) -> Vector2:
	return Vector2(
		maxf(semiejes_apoyo.x, SEMIEJE_MINIMO_MUEBLE),
		maxf(semiejes_apoyo.y, SEMIEJE_MINIMO_MUEBLE)
	)


static func _generar_textura() -> ImageTexture:
	var imagen := Image.create(LADO_TEXTURA, LADO_TEXTURA, false, Image.FORMAT_RGBA8)
	for y: int in LADO_TEXTURA:
		for x: int in LADO_TEXTURA:
			# Centro del PÍXEL (convención del proyecto — ver `AnclajeSprite._medir_semiejes_base`):
			# el píxel `n` cubre `[n, n+1)`, así que su centro está en `n + 0.5`.
			var dx: float = (float(x) + 0.5 - RADIO_TEXTURA) / RADIO_TEXTURA
			var dy: float = (float(y) + 0.5 - RADIO_TEXTURA) / RADIO_TEXTURA
			var r2: float = dx * dx + dy * dy
			var alfa: float = pow(1.0 - r2, EXPONENTE_CAIDA) if r2 < 1.0 else 0.0
			imagen.set_pixel(x, y, Color(1.0, 1.0, 1.0, alfa))
	return ImageTexture.create_from_image(imagen)
