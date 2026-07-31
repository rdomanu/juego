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
	# LAS DOS SILLAS de la ventanilla: la del funcionario detrás y la del ciudadano delante. Van al
	# final para que se dibujen por encima del tablero, que es lo que corresponde: están fuera de la
	# mesa, no dentro.
	var suya: Node2D = silla(HACIA_FUNCIONARIO.normalized() * 20.0)
	suya.name = "SillaFuncionario"
	suya.position = HACIA_FUNCIONARIO
	raiz.add_child(suya)
	var del_ciudadano: Node2D = silla(HACIA_CIUDADANO.normalized() * 20.0)
	del_ciudadano.name = "SillaCiudadano"
	del_ciudadano.position = HACIA_CIUDADANO
	raiz.add_child(del_ciudadano)
	return raiz


static func _pieza(nombre: String, pos: Vector2, alto: float, escala: float, color: Color) -> Node2D:
	var p: Node2D = PiezaIsoScript.new()
	p.name = nombre
	p.position = pos
	p.configurar(1, 1, alto, color, escala)
	return p
