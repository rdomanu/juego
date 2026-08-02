extends Node
## MesaAtencion — la mesa de una ventanilla, con su ordenador y sus papeles.
##
## Encargo del usuario (2026-07-31): *"diseña la mesa de trabajo para que se vea una mesa para
## atender a la gente, que sale ahora un cuadrado en una cuadrícula; pon un ordenador apuntando al
## policía y algunos papeles"*.
##
## ── CÓMO ESTÁ MONTADA ─────────────────────────────────────────────────────────────────────────
## Todo son cajas isométricas (`PiezaIso`) apiladas. La mesa es un cuerpo bajo y ancho, y encima de
## su tablero se colocan las cosas: el ordenador del lado del funcionario y los papeles del lado del
## ciudadano, que es exactamente como está una ventanilla de verdad.
##
##   ┌ (arriba-derecha) ── el FUNCIONARIO ── ordenador, teclado
##   │
##   │   ▧ TABLERO
##   │
##   └ (abajo-izquierda) ── el CIUDADANO ── papeles, para firmar
##
## ── EL DETALLE QUE MÁS SE NOTA ────────────────────────────────────────────────────────────────
## La pantalla **mira al policía**, así que desde la cámara del juego se ve el DORSO del monitor,
## no la pantalla. Es lo correcto y además es lo que uno reconoce al instante de cualquier
## ventanilla: al ciudadano nunca se le enseña la pantalla. Se marca con un canto claro en el borde
## de arriba para que se lea "monitor" y no "caja".

const PiezaIsoScript := preload("res://src/foundation/proyeccion/pieza_iso.gd")

## Alto del cuerpo de la mesa. Por debajo de la cintura del muñeco (28 px de alto) para que el
## funcionario se vea de medio cuerpo por encima, como en una ventanilla.
const ALTO_MESA: float = 14.0
## Cuánto de su celda ocupa la mesa. 0.78: un mueble ancho, pero que deja ver el suelo alrededor —
## si llenara el rombo entero, el funcionario de la casilla de atrás parecería subido encima.
const ESCALA_MESA: float = 0.78
const COLOR_TABLERO := Color(0.45, 0.36, 0.28)      # madera de oficina

## El monitor: alto, estrecho y oscuro. Va del lado del funcionario.
const ALTO_MONITOR: float = 11.0
const ESCALA_MONITOR: float = 0.20
const COLOR_MONITOR := Color(0.13, 0.14, 0.17)
## Desplazamiento hacia el lado del FUNCIONARIO, en píxeles de pantalla, SOLO para la decoración
## que va ENCIMA del tablero (teclado/monitor/papeles del mostrador de código — ver `construir()`).
## Media casilla en el eje Y de la rejilla, que proyectada es arriba y a la derecha (ver
## `Proyeccion`). NO es la posición de la silla ni de quien se sienta — para eso, ver
## `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` más abajo (regla de rejilla, 2026-08-02).
const DECOR_HACIA_FUNCIONARIO := Vector2(14.0, -7.0)
## Y el del CIUDADANO, al otro lado: abajo y a la izquierda.
const DECOR_HACIA_CIUDADANO := Vector2(-13.0, 6.5)

const ALTO_TECLADO: float = 1.5
const ESCALA_TECLADO: float = 0.26
const COLOR_TECLADO := Color(0.22, 0.23, 0.26)

## Los papeles: casi planos, claros, y DOS montones ligeramente descolocados — un solo rectángulo
## perfecto en medio de la mesa se lee como una baldosa, no como papeles.
const ALTO_PAPEL: float = 1.0
const ESCALA_PAPEL: float = 0.17
const COLOR_PAPEL := Color(0.90, 0.89, 0.84)


## ── LA SILLA (2026-08-01) ──────────────────────────────────────────────────────────────────────
## Petición del usuario: *"en los puestos de atención debe haber 1 silla en cada puesto y en la sala
## de espera también"*. Y tiene sentido más allá de lo decorativo: si los personajes se sientan (ya
## tienen su pose), hace falta algo debajo o parecen flotando.
##
## Dos piezas: el asiento y el respaldo. Con el respaldo se lee "silla" incluso a tamaño diminuto;
## sin él, es un taburete o una caja.
const ALTO_ASIENTO_SILLA: float = 7.0
const ALTO_RESPALDO: float = 11.0
const ESCALA_SILLA: float = 0.42
const COLOR_SILLA := Color(0.30, 0.32, 0.38)


## ── SPRITE DEL MOSTRADOR: 1 CELDA (legado) Y 2 CELDAS (2026-08-02) ────────────────────────────
## Igual que el muñeco del policía (`muneco.gd::hay_sprites`): si hay un render 3D del pack de
## oficina para el mostrador (`tools/render_mobiliario.gd`), se dibuja ESE en vez de las cajas de
## código. El sprite ya trae su propio monitor, teclado, ratón y teléfono montados encima, así que
## Tablero/Teclado/Monitor/Papeles/Papeles2 SOBRAN con él puesto — se decidió MIRANDO el render (un
## papel no pinta nada sobre un escritorio de madera que ya trae su propio teléfono). Las SILLAS
## siguen siendo de código: no vinieron en este render.
##
## DOS sprites, no uno, desde que el puesto pasó a ocupar 2 celdas de verdad (ver la cabecera de
## `Construccion` — "LA HUELLA DEL PUESTO: 2 CELDAS"): `ID_SPRITE_MOSTRADOR_2` para el caso normal
## y `ID_SPRITE_MOSTRADOR` (el de 1 celda de siempre) SOLO para la excepción de huella legado — un
## puesto de una partida guardada que no cabe en 2 celdas de hoy (`Construccion.es_huella_legado`).
## `construir()` elige uno u otro con `es_legado`.
const RUTA_SPRITES_MOBILIARIO := "res://assets/sprites/mobiliario/"
const ID_SPRITE_MOSTRADOR := "mostrador_atencion"
const ID_SPRITE_MOSTRADOR_2 := "mostrador_atencion2"
## Solo 0° por ahora: los puestos de atención SIEMPRE se construyen con la misma orientación fija
## (`CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` no dependen de `orientacion` — `Construccion._crear_
## pieza` ni se la pasa a los puestos), así que no hace falta elegir entre las 4 rotaciones
## renderizadas. 0° es la que se vio, mirando las 4: el monitor de espaldas a cámara (nunca se le
## enseña la pantalla al ciudadano, ver la cabecera del fichero) y sin nada raro en el encuadre.
const ROT_MOSTRADOR: int = 0
## Dónde cae el ANCLA (el centro del rombo de la celda, el mismo punto que usa
## `Proyeccion.centro_iso`) dentro del PNG, como fracción de su ancho/alto — la imprime
## `render_mobiliario.gd` al renderizar. Re-renderizados los DOS el 2026-08-02 (60×60 el de 1
## celda, 120×120 el de 2 celdas): comparten la MISMA fracción — dato definitivo confirmado por
## quien los renderizó; si algún día divergen, basta con separar esta constante en dos.
const ANCLA_FRACCION_MOSTRADOR := Vector2(0.501, 0.747)

## ── ANCLAS DE CELDA DE LA VENTANILLA (2026-08-02) ────────────────────────────────────────────
## Regla del usuario, viendo el juego: *"la mesa debe ocupar 1 o 2 cuadrículas, las sillas 1, y
## todos los elementos deben ocupar de 1 en 1 cuadrícula; no coincide donde se sientan los
## ciudadanos con donde está la silla; las sillas no están en la misma línea que la mesa"*.
##
## Sustituye a los ajustes de píxel a mano de la calibración anterior (`HACIA_FUNCIONARIO_SPRITE`/
## `HACIA_CIUDADANO_SPRITE`, borrados): esos números no caían en el centro de ninguna celda ni
## coincidían con el punto donde el juego sienta de verdad a la gente. La ventanilla son TRES
## celdas en fila en el plano LÓGICO cuadrado (ver `NPCsFlujo._asegurar_visual_puesto`): el
## funcionario detrás (norte), el mostrador en medio (la celda del puesto en el modelo) y el
## ciudadano delante (sur, `NPCsFlujo._frente_del_puesto` = `centro_de_celda(celda + Vector2i(0,
## 1))`). Cada silla —y quien se sienta en ella— ancla al CENTRO de SU celda, no a un número
## suelto: el salto de pantalla de una celda a la vecina en ese eje es
## `Vector2(±Proyeccion.MEDIO_ANCHO, ∓Proyeccion.MEDIO_ALTO)` (la misma cuenta de
## `Proyeccion.centro_iso`/`proyectar`, ver ese fichero). ES el mismo offset que ya usaba
## `NPCsFlujo._POLICIA_DETRAS` para el policía DE PIE — aquí se convierte en la ÚNICA fuente de
## verdad, para que de pie, sentado, silla y ciudadano coincidan siempre en el mismo punto.
const CELDA_FUNCIONARIO := Vector2(Proyeccion.MEDIO_ANCHO, -Proyeccion.MEDIO_ALTO)   # norte, detrás
const CELDA_CIUDADANO := Vector2(-Proyeccion.MEDIO_ANCHO, Proyeccion.MEDIO_ALTO)     # sur, delante


## ¿Hay un sprite renderizado para este mostrador (`ID_SPRITE_MOSTRADOR` o `ID_SPRITE_MOSTRADOR_2`)?
static func hay_sprite_mostrador(id_sprite: String) -> bool:
	return ResourceLoader.exists(_ruta_sprite_mostrador(id_sprite))


static func _ruta_sprite_mostrador(id_sprite: String) -> String:
	return "%s%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, id_sprite, ROT_MOSTRADOR]


## El mostrador de sprite: un `Sprite2D` anclado por el mismo punto que las piezas de código (el
## centro de la celda, `Vector2.ZERO` en local) — no por su esquina ni por su centro geométrico.
static func _pieza_sprite_mostrador(id_sprite: String) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Tablero"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	var textura: Texture2D = load(_ruta_sprite_mostrador(id_sprite))
	sprite.texture = textura
	sprite.offset = Vector2(
		-textura.get_width() * ANCLA_FRACCION_MOSTRADOR.x,
		-textura.get_height() * ANCLA_FRACCION_MOSTRADOR.y
	)
	raiz.add_child(sprite)
	return raiz


## ── SILLAS DE SPRITE (2026-08-01, 2ª tanda) ──────────────────────────────────────────────────
## La roja de OBJ_042 para el funcionario; la de espera (OBJ_023, la más repetida del pack —ver
## `render_mobiliario.gd`— la misma en TODAS las esperas, ventanillas incluidas) para el ciudadano
## y para `Construccion.ASIENTO_BASICO`. Mismo patrón que el mostrador: si no hay sprite, la silla
## de código de siempre.
const ID_SPRITE_SILLA_FUNCIONARIO := "silla_funcionario"
const ID_SPRITE_SILLA_ESPERA := "silla_espera"
## Cada silla, su PROPIA rotación — NO la misma para las dos: cada mueble tiene su frente en un
## sitio distinto de la escena de origen (ver `render_mobiliario.gd`). Elegidas MIRANDO las 4 con
## la silla VACÍA y flechas de referencia sobre la imagen (2º aviso del usuario 2026-08-02: la
## primera elección se hizo con un muñeco sentado ENCIMA que tapaba el asiento — así se coló el
## error; regla nueva: la dirección de un asiento se juzga con el asiento vacío):
##  · Funcionario: 180° — el asiento abre hacia ABAJO-IZQUIERDA de pantalla, hacia el ciudadano
##    (la misma dirección a la que da la cara de cajones del mostrador); el respaldo queda
##    arriba-derecha, a la espalda del policía, que se sienta mirando al sur.
##  · Espera: 270° — el asiento abre hacia ARRIBA-DERECHA, hacia la mesa; el respaldo queda hacia
##    cámara, a la espalda del ciudadano.
const ROT_SILLA_FUNCIONARIO: int = 180
const ROT_SILLA_ESPERA: int = 270
## Anclas actualizadas 2026-08-02 (nuevo re-render de todo el mobiliario — dato definitivo).
const ANCLA_FRACCION_SILLA_FUNCIONARIO := Vector2(0.493, 0.824)
const ANCLA_FRACCION_SILLA_ESPERA := Vector2(0.495, 0.797)


static func hay_sprite_silla_funcionario() -> bool:
	return ResourceLoader.exists(_ruta_sprite_silla(ID_SPRITE_SILLA_FUNCIONARIO, ROT_SILLA_FUNCIONARIO))


static func hay_sprite_silla_espera() -> bool:
	return ResourceLoader.exists(_ruta_sprite_silla(ID_SPRITE_SILLA_ESPERA, ROT_SILLA_ESPERA))


static func _ruta_sprite_silla(id_silla: String, rotacion: int) -> String:
	return "%s%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, id_silla, rotacion]


## Una silla de sprite, anclada por el mismo punto que `silla()`: el sitio donde se sienta quien
## la usa (`Vector2.ZERO` en local), no su esquina.
static func _pieza_sprite_silla(id_silla: String, rotacion: int, ancla_fraccion: Vector2) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Silla"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	var textura: Texture2D = load(_ruta_sprite_silla(id_silla, rotacion))
	sprite.texture = textura
	sprite.offset = Vector2(
		-textura.get_width() * ancla_fraccion.x, -textura.get_height() * ancla_fraccion.y
	)
	raiz.add_child(sprite)
	return raiz


## La silla del FUNCIONARIO: sprite si lo hay, si no la de código de siempre.
static func silla_funcionario_o_defecto(hacia_atras: Vector2, color: Color = COLOR_SILLA) -> Node2D:
	if hay_sprite_silla_funcionario():
		return _pieza_sprite_silla(
			ID_SPRITE_SILLA_FUNCIONARIO, ROT_SILLA_FUNCIONARIO, ANCLA_FRACCION_SILLA_FUNCIONARIO
		)
	return silla(hacia_atras, color)


## La silla de ESPERA: sprite si lo hay, si no la de código de siempre. La usan el lado del
## ciudadano en la ventanilla Y `Construccion` para `ASIENTO_BASICO` (misma silla en los dos
## sitios, a propósito: es la MISMA silla de espera del edificio).
static func silla_espera_o_defecto(hacia_atras: Vector2, color: Color = COLOR_SILLA_ESPERA_DEFECTO) -> Node2D:
	if hay_sprite_silla_espera():
		return _pieza_sprite_silla(ID_SPRITE_SILLA_ESPERA, ROT_SILLA_ESPERA, ANCLA_FRACCION_SILLA_ESPERA)
	return silla(hacia_atras, color)


## Color de la silla de código de espera cuando no hay sprite — mismo tono que usaba
## `Construccion.COLOR_SILLA_ESPERA` antes de esta pasada (gris institucional cálido).
const COLOR_SILLA_ESPERA_DEFECTO := Color(0.38, 0.36, 0.34)


## Una silla mirando hacia `hacia_atras` (el respaldo se pone a ese lado). El vector va en píxeles
## de pantalla, así que se usan las mismas constantes de lado que la mesa.
static func silla(hacia_atras: Vector2, color: Color = COLOR_SILLA) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Silla"
	raiz.add_child(_pieza("Asiento", Vector2.ZERO, ALTO_ASIENTO_SILLA, ESCALA_SILLA, color))
	# El respaldo: más alto, más estrecho y desplazado al lado contrario de quien se sienta.
	raiz.add_child(_pieza(
		"Respaldo", hacia_atras * 0.30 - Vector2(0.0, ALTO_ASIENTO_SILLA),
		ALTO_RESPALDO, ESCALA_SILLA * 0.55, color.darkened(0.15)
	))
	return raiz


## Monta la mesa completa. Se coloca en el CENTRO de la celda de TRABAJO (el ancla del modelo) y
## todo va en local. `es_legado`: el puesto es una huella legado de 1 celda
## (`Construccion.es_huella_legado`) — usa el sprite/tablero de 1 celda, sin desplazar; si no (el
## caso normal desde 2026-08-02), usa el de 2 celdas y desplaza SOLO el "Tablero" a la ÚLTIMA
## celda de su cuerpo: regla verificada por composites — un sprite a rotación 0 ancla en la celda
## ESTE de su cuerpo, no en la celda del modelo (`Proyeccion.delta_ultima_celda`, la MISMA cuenta
## que usa `Construccion` para sus comodidades multi-celda — no es un caso especial del
## mostrador). "Mesa" en sí se queda en el ancla del modelo (silla/policía siguen anclando ahí vía
## `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO`, sin tocar); con 1 celda el delta es cero, así que el
## camino legado no necesita su propio `if` de posición.
static func construir(es_legado: bool = false) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Mesa"
	# Superficie del cuerpo en celdas: 2 el caso normal (catálogo, `TipoPuesto.superficie`), 1 la
	# excepción de huella legado (`Construccion.SUPERFICIE_LEGADO`) — mismos números, sin importar
	# la constante para no acoplar este script de piezas visuales al core.
	var superficie: int = 1 if es_legado else 2
	var id_sprite: String = ID_SPRITE_MOSTRADOR if es_legado else ID_SPRITE_MOSTRADOR_2
	if hay_sprite_mostrador(id_sprite):
		var tablero: Node2D = _pieza_sprite_mostrador(id_sprite)
		tablero.position = Proyeccion.delta_ultima_celda(Vector2i(1, 0), superficie)
		raiz.add_child(tablero)
	else:
		raiz.add_child(_pieza("Tablero", Vector2.ZERO, ALTO_MESA, ESCALA_MESA, COLOR_TABLERO))
		# Todo lo que va ENCIMA se sube el alto de la mesa: si no, quedaría metido dentro del tablero.
		var encima := Vector2(0.0, -ALTO_MESA)
		# Del lado del funcionario: teclado delante y monitor detrás (él lo mira de frente).
		raiz.add_child(_pieza(
			"Teclado", encima + DECOR_HACIA_FUNCIONARIO * 0.55, ALTO_TECLADO, ESCALA_TECLADO, COLOR_TECLADO
		))
		raiz.add_child(_pieza(
			"Monitor", encima + DECOR_HACIA_FUNCIONARIO, ALTO_MONITOR, ESCALA_MONITOR, COLOR_MONITOR
		))
		# Del lado del ciudadano: los papeles que viene a firmar.
		raiz.add_child(_pieza(
			"Papeles", encima + DECOR_HACIA_CIUDADANO, ALTO_PAPEL, ESCALA_PAPEL, COLOR_PAPEL
		))
		raiz.add_child(_pieza(
			"Papeles2", encima + DECOR_HACIA_CIUDADANO + Vector2(6.0, 2.0), ALTO_PAPEL, ESCALA_PAPEL,
			COLOR_PAPEL.darkened(0.08)
		))
	# LA SILLA DEL CIUDADANO va aquí dentro, AL FINAL para que se dibuje por encima del tablero
	# (código o sprite) — está delante de la mesa, no dentro, pero el orden de dibujo de un solo
	# lado (mesa → silla) no tiene ningún tercero (policía) de por medio, así que basta con el
	# orden interno de este nodo.
	#
	# LA SILLA DEL FUNCIONARIO **NO** vive aquí — aviso del usuario 2026-08-01, viendo el juego:
	# *"la silla, luego encima el policía, y luego la mesa tapando al policía y a la silla"*. Con
	# la silla como hija de "Mesa", todo el bloque Mesa (tablero + silla) se moja junto al
	# intercambiar mesa↔policía en `npcs_flujo._reconstruir_cuerpo_policia`, y la silla salía
	# SIEMPRE por encima del policía sentado (el bug que reportó). Ahora es HERMANA de "Mesa" y
	# "Policia" en el contenedor del puesto —la monta `_asegurar_visual_puesto`, SIEMPRE la
	# primera— así puede quedarse fija al fondo mientras mesa y policía se intercambian entre sí.
	#
	# LA POSICIÓN usa `CELDA_CIUDADANO` (centro de la celda sur, regla de rejilla 2026-08-02) — es
	# el MISMO punto al que `NPCsFlujo._frente_del_puesto` manda al ciudadano ya sentado, así que
	# silla y ciudadano SIEMPRE coinciden (ver el comentario junto a la constante, arriba).
	var del_ciudadano: Node2D = silla_espera_o_defecto(CELDA_CIUDADANO.normalized() * 20.0)
	del_ciudadano.name = "SillaCiudadano"
	del_ciudadano.position = CELDA_CIUDADANO
	raiz.add_child(del_ciudadano)
	return raiz


static func _pieza(nombre: String, pos: Vector2, alto: float, escala: float, color: Color) -> Node2D:
	var p: Node2D = PiezaIsoScript.new()
	p.name = nombre
	p.position = pos
	p.configurar(1, 1, alto, color, escala)
	return p
