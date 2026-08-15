# SOMBRA DE CONTACTO — la textura radial y la proyección al suelo, sin escena ni fisica.
# Tipo: Logic. DETERMINISTA: aritmetica pura + una imagen generada por codigo; sin reloj ni RNG.
#
# Decision visual cerrada con el usuario (2026-08-14): alfa maximo 0,30 en el centro, color casi
# negro (10,10,15) y caida `ALFA_PICO * (1 - r^2)^EXPONENTE_CAIDA`. La elipse se define en el PLANO
# LOGICO DEL SUELO y se proyecta a pantalla con la MISMA transformada que usa `Proyeccion` para todo
# lo que esta pegado al suelo (ver la cabecera de `sombra_contacto.gd`).
#
# Lo que protege este test:
#   1. La textura se genera UNA vez y se cachea (misma instancia en llamadas sucesivas).
#   2. La formula de caida: el centro sale al maximo (~1.0, antes de escalar por ALFA_PICO) y fuera
#      del circulo (una esquina del lienzo) cae exactamente a 0.
#   3. `crear_sprite` proyecta el circulo de la textura a la elipse del suelo con la transformada de
#      `Proyeccion` (eje u -> (1, 0.5), eje v -> (-1, 0.5)) y escala el ALFA_PICO por `modulate`.
extends GdUnitTestSuite

const SombraContactoScript := preload("res://src/foundation/proyeccion/sombra_contacto.gd")


# ── 1. La textura se cachea ─────────────────────────────────────────────────────────────────────

func test_la_textura_es_la_misma_instancia_en_dos_llamadas() -> void:
	var primera: ImageTexture = SombraContactoScript.textura()
	var segunda: ImageTexture = SombraContactoScript.textura()
	assert_object(segunda).override_failure_message(
		"la textura deberia generarse UNA vez y cachearse, no una por llamada"
	).is_same(primera)


# ── 2. La formula de caida ──────────────────────────────────────────────────────────────────────

## El centro del lienzo (r ~ 0) tiene que dar el PICO de la curva: `(1 - 0)^EXPONENTE = 1.0`, el
## valor SIN escalar por `ALFA_PICO` (eso lo aplica `crear_sprite` via `modulate`, no la textura).
func test_el_centro_de_la_textura_da_el_pico_de_la_curva() -> void:
	var imagen: Image = SombraContactoScript.textura().get_image()
	var lado: int = SombraContactoScript.LADO_TEXTURA
	var centro: int = lado / 2
	var alfa_centro: float = imagen.get_pixel(centro, centro).a
	assert_float(alfa_centro).override_failure_message(
		"el centro de la textura deberia rozar el pico de la curva (1.0), dio %.4f" % alfa_centro
	).is_equal_approx(1.0, 0.01)


## Una ESQUINA del lienzo cuadrado queda FUERA del circulo unidad (su distancia al centro es
## `sqrt(2) * RADIO_TEXTURA`, mayor que `RADIO_TEXTURA`): tiene que caer a cero EXACTO, no solo bajo.
func test_una_esquina_del_lienzo_cae_a_cero_exacto() -> void:
	var imagen: Image = SombraContactoScript.textura().get_image()
	assert_float(imagen.get_pixel(0, 0).a).override_failure_message(
		"una esquina (fuera del circulo unidad) deberia dar alfa 0 exacto"
	).is_equal(0.0)


# ── 3. La proyeccion al suelo ───────────────────────────────────────────────────────────────────

## El PICO de la curva (alfa 1.0 en la textura) se escala por `ALFA_PICO` con `modulate`, no
## reescribiendo la textura — asi la MISMA textura sirve para cualquier sombra del juego.
func test_el_sprite_escala_el_pico_por_alfa_pico_del_modulate() -> void:
	var sprite: Sprite2D = SombraContactoScript.crear_sprite(Vector2(20.0, 20.0))
	auto_free(sprite)
	assert_float(sprite.modulate.a).is_equal_approx(SombraContactoScript.ALFA_PICO, 0.001)


## El color de la sombra es el declarado, sin mezclas ni improvisaciones.
func test_el_sprite_usa_el_color_declarado() -> void:
	var sprite: Sprite2D = SombraContactoScript.crear_sprite(Vector2(20.0, 20.0))
	auto_free(sprite)
	var color: Color = SombraContactoScript.COLOR_SOMBRA
	assert_bool(Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b).is_equal_approx(color)).is_true()


## 🔒 EL CASO DEL ENCARGO: el borde derecho del circulo unidad de la textura (punto local `(32, 0)`,
## el radio exacto) tiene que proyectarse al punto del EJE U del suelo: `(sx, sx/2)` — la MISMA
## direccion `(1, 0.5)` que usa `Proyeccion` para el este. Y el de arriba, `(0, 32)` (eje V, el sur),
## a `(-sy, sy/2)` — la direccion `(-1, 0.5)` del sur. Con semiejes distintos (24 y 16) para que un
## acierto por simetria no disfrace un eje mal puesto.
func test_el_transform_proyecta_los_ejes_del_suelo() -> void:
	var semiejes := Vector2(24.0, 16.0)
	var sprite: Sprite2D = SombraContactoScript.crear_sprite(semiejes)
	auto_free(sprite)
	var radio: float = SombraContactoScript.RADIO_TEXTURA
	var punto_este: Vector2 = sprite.transform * Vector2(radio, 0.0)
	var punto_sur: Vector2 = sprite.transform * Vector2(0.0, radio)
	assert_bool(punto_este.is_equal_approx(Vector2(semiejes.x, semiejes.x * 0.5))).override_failure_message(
		"el eje ESTE de la textura deberia caer en (%.1f, %.1f), dio %s"
		% [semiejes.x, semiejes.x * 0.5, punto_este]
	).is_true()
	assert_bool(punto_sur.is_equal_approx(Vector2(-semiejes.y, semiejes.y * 0.5))).override_failure_message(
		"el eje SUR de la textura deberia caer en (%.1f, %.1f), dio %s"
		% [-semiejes.y, semiejes.y * 0.5, punto_sur]
	).is_true()


## El nombre del nodo es SIEMPRE "Sombra" (identidad para depurar; el juego ya no busca por él —
## las sombras del juego las pinta `CapaSombras`, ver su cabecera).
func test_el_sprite_se_llama_sombra() -> void:
	var sprite: Sprite2D = SombraContactoScript.crear_sprite(Vector2(10.0, 10.0))
	auto_free(sprite)
	assert_str(sprite.name).is_equal("Sombra")


# ── 4. El suelo mínimo de los muebles ───────────────────────────────────────────────────────────

## `semiejes_base` mide las PATAS (una silla de madera pisa 5,25×5,25; la estantería suelta 2,75 de
## fondo) y esa sombra era invisible de puro pequeña — cazado en el juego real (2026-08-14). El
## mínimo LEVANTA solo el eje corto y RESPETA el largo medido.
func test_semiejes_para_mueble_levanta_solo_el_eje_corto() -> void:
	var minimo: float = SombraContactoScript.SEMIEJE_MINIMO_MUEBLE
	# Un banco: largo real 19.25 (se respeta), fondo 6.25 (sube al minimo)
	var banco: Vector2 = SombraContactoScript.semiejes_para_mueble(Vector2(19.25, 6.25))
	assert_float(banco.x).is_equal_approx(19.25, 0.001)
	assert_float(banco.y).is_equal_approx(minimo, 0.001)
	# Una silla de patas finas: los dos ejes suben al minimo
	var silla: Vector2 = SombraContactoScript.semiejes_para_mueble(Vector2(5.25, 5.25))
	assert_that(silla).is_equal(Vector2(minimo, minimo))
