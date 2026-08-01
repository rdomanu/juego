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
## Desplazamiento hacia el lado del FUNCIONARIO, en píxeles de pantalla. Media casilla en el eje Y
## de la rejilla, que proyectada es arriba y a la derecha (ver `Proyeccion`).
const HACIA_FUNCIONARIO := Vector2(14.0, -7.0)
## Y el del CIUDADANO, al otro lado: abajo y a la izquierda.
const HACIA_CIUDADANO := Vector2(-13.0, 6.5)

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


## ── SPRITE DEL MOSTRADOR (2026-08-01) ─────────────────────────────────────────────────────────
## Igual que el muñeco del policía (`muneco.gd::hay_sprites`): si hay un render 3D del pack de
## oficina para el mostrador (`tools/render_mobiliario.gd`, receta `mostrador_atencion` = OBJ_021
## SIN la silla que traía horneada — el funcionario usa la suya propia, de OBJ_042, en otra
## pasada), se dibuja ESE en vez de las cajas de código. El sprite ya trae su propio monitor,
## teclado, ratón y teléfono montados encima, así que Tablero/Teclado/Monitor/Papeles/Papeles2
## SOBRAN con él puesto — se decidió MIRANDO el render (un papel no pinta nada sobre un
## escritorio de madera que ya trae su propio teléfono). Las SILLAS siguen siendo de código: no
## vinieron en este render.
const RUTA_SPRITES_MOBILIARIO := "res://assets/sprites/mobiliario/"
## Solo 0° por ahora: los puestos de atención SIEMPRE se construyen con la misma orientación fija
## (`HACIA_FUNCIONARIO`/`HACIA_CIUDADANO` no dependen de `orientacion` — `Construccion._crear_
## pieza` ni se la pasa a los puestos), así que no hace falta elegir entre las 4 rotaciones
## renderizadas. 0° es la que se vio, mirando las 4: el monitor de espaldas a cámara (nunca se le
## enseña la pantalla al ciudadano, ver la cabecera del fichero) y sin nada raro en el encuadre.
const ROT_MOSTRADOR: int = 0
## Dónde cae el ANCLA (el centro del rombo de la celda, el mismo punto que usa
## `Proyeccion.centro_iso`) dentro del PNG, como fracción de su ancho/alto — la imprime
## `render_mobiliario.gd` al renderizar (no se adivina: sale de centrar la cámara 3D en el punto
## donde el mueble "pisa" el suelo, ver la cabecera de esa herramienta). Actualizada 2026-08-01 al
## re-renderizar con `ESCALA_OBJETIVO_MOSTRADOR` = 0,92 (antes 0,78) — el lienzo cambia de tamaño y
## la fracción con él; el número viejo (0,503; 0,765) quedaba corto.
const ANCLA_FRACCION_MOSTRADOR := Vector2(0.497, 0.771)

## ── EL SITIO SE MUEVE CUANDO EL MOSTRADOR ES SPRITE (2026-08-01) ────────────────────────────────
## `HACIA_FUNCIONARIO`/`HACIA_CIUDADANO` (arriba) se calibraron contra la caja de código, de solo
## 14 px de alto. El escritorio 3D real —reescalado además a `ESCALA_OBJETIVO_MOSTRADOR` = 0,92,
## ver `render_mobiliario.gd`— es mucho más alto (72 px de lienzo) y su propio monitor tapa
## CUALQUIER COSA sentada en el punto de siempre: comprobado componiendo con Python
## (`silla_funcionario` + el sprite sentado del policía + el mostrador, los tres con su ancla real)
## ANTES de tocar un solo número aquí — el policía desaparecía entero detrás del monitor.
##
## Calibrado igual, a ojo sobre el composite: subiendo el funcionario de 8 en 8 px hasta que asoma
## medio cuerpo por encima del monitor (para en -20, no en -7) y bajando al ciudadano hasta que su
## silla queda ENTERA delante del mostrador, sin remeter bajo el cajón (para en +40, no en +6,5).
## Composite final: `composite_sandwich_v1`/`ciudadano_y40` en el scratchpad de la sesión.
##
## Con la caja de código (sin sprite de mostrador) NO hace falta nada de esto — sigue siendo tan
## bajita como siempre, así que ahí se mantienen las constantes originales sin tocar.
const HACIA_FUNCIONARIO_SPRITE := Vector2(14.0, -20.0)
const HACIA_CIUDADANO_SPRITE := Vector2(-13.0, 40.0)


## ¿Hay un sprite renderizado del mostrador?
static func hay_sprite_mostrador() -> bool:
	return ResourceLoader.exists(_ruta_sprite_mostrador())


static func _ruta_sprite_mostrador() -> String:
	return "%smostrador_atencion_%d.png" % [RUTA_SPRITES_MOBILIARIO, ROT_MOSTRADOR]


## Dónde se sienta el FUNCIONARIO ahora mismo — el punto de siempre con la caja de código, el
## reajustado (ver arriba) si el mostrador ya es el sprite 3D. Úsala en vez de `HACIA_FUNCIONARIO`
## a secas para CUALQUIER COSA que tenga que sentarse o pintarse en ese sitio (la silla, el
## muñeco): así no hay dos números que puedan desincronizarse.
static func hacia_funcionario_actual() -> Vector2:
	return HACIA_FUNCIONARIO_SPRITE if hay_sprite_mostrador() else HACIA_FUNCIONARIO


## Lo mismo que `hacia_funcionario_actual()`, para el lado del CIUDADANO.
static func hacia_ciudadano_actual() -> Vector2:
	return HACIA_CIUDADANO_SPRITE if hay_sprite_mostrador() else HACIA_CIUDADANO


## El mostrador de sprite: un `Sprite2D` anclado por el mismo punto que las piezas de código (el
## centro de la celda, `Vector2.ZERO` en local) — no por su esquina ni por su centro geométrico.
static func _pieza_sprite_mostrador() -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Tablero"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	var textura: Texture2D = load(_ruta_sprite_mostrador())
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
const ANCLA_FRACCION_SILLA_FUNCIONARIO := Vector2(0.493, 0.846)
const ANCLA_FRACCION_SILLA_ESPERA := Vector2(0.495, 0.815)


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


## Monta la mesa completa. Se coloca en el CENTRO de la celda del puesto y todo va en local.
static func construir() -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Mesa"
	if hay_sprite_mostrador():
		raiz.add_child(_pieza_sprite_mostrador())
	else:
		raiz.add_child(_pieza("Tablero", Vector2.ZERO, ALTO_MESA, ESCALA_MESA, COLOR_TABLERO))
		# Todo lo que va ENCIMA se sube el alto de la mesa: si no, quedaría metido dentro del tablero.
		var encima := Vector2(0.0, -ALTO_MESA)
		# Del lado del funcionario: teclado delante y monitor detrás (él lo mira de frente).
		raiz.add_child(_pieza(
			"Teclado", encima + HACIA_FUNCIONARIO * 0.55, ALTO_TECLADO, ESCALA_TECLADO, COLOR_TECLADO
		))
		raiz.add_child(_pieza(
			"Monitor", encima + HACIA_FUNCIONARIO, ALTO_MONITOR, ESCALA_MONITOR, COLOR_MONITOR
		))
		# Del lado del ciudadano: los papeles que viene a firmar.
		raiz.add_child(_pieza(
			"Papeles", encima + HACIA_CIUDADANO, ALTO_PAPEL, ESCALA_PAPEL, COLOR_PAPEL
		))
		raiz.add_child(_pieza(
			"Papeles2", encima + HACIA_CIUDADANO + Vector2(6.0, 2.0), ALTO_PAPEL, ESCALA_PAPEL,
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
	# LA POSICIÓN usa `hacia_ciudadano_actual()`, NO la constante a secas: con el mostrador de
	# sprite (mucho más alto que la caja de código) el sitio de siempre queda tapado por su propio
	# monitor — ver el aviso junto a `HACIA_FUNCIONARIO_SPRITE`.
	var hacia_ciudadano: Vector2 = hacia_ciudadano_actual()
	var del_ciudadano: Node2D = silla_espera_o_defecto(hacia_ciudadano.normalized() * 20.0)
	del_ciudadano.name = "SillaCiudadano"
	del_ciudadano.position = hacia_ciudadano
	raiz.add_child(del_ciudadano)
	return raiz


static func _pieza(nombre: String, pos: Vector2, alto: float, escala: float, color: Color) -> Node2D:
	var p: Node2D = PiezaIsoScript.new()
	p.name = nombre
	p.position = pos
	p.configurar(1, 1, alto, color, escala)
	return p
