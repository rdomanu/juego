class_name TramoPared extends Node2D
## TramoPared — UN solo tramo de pared (o una jamba) como nodo propio, para que el MOTOR lo ordene
## por profundidad contra el mobiliario, mueble a mueble, en vez de por un número de capa global.
##
## ── POR QUÉ UN NODO POR TRAMO (2026-08-03, sustituye a `CapaParedes`) ───────────────────────────
## Hasta hoy las paredes se pintaban en DOS pasadas (`ParedesFondo` z 0 / `ParedesFrente` z 1), cada
## una un único `_draw()` con todos sus tramos dentro. Con un z GLOBAL por pasada, un muro DIVISORIO
## entre dos salas no tiene orden correcto posible: es la pared de delante de la sala de arriba (debe
## taparle la base a lo que tenga arrimado) y la pared de atrás de la de abajo (debe quedar detrás de
## lo que ella tenga arrimado). Un solo número no puede ser las dos cosas — el trade-off que el
## usuario rechazó con su caso real (la ventanilla pegada al divisorio Documentación/ODAC).
##
## La solución es la del género (algoritmo del pintor, ver
## `docs/architecture/borrador-orden-profundidad-rotaciones.md` §3): que cada tramo COMPITA por
## profundidad como un objeto más de la escena. Para eso tiene que ser un `CanvasItem` propio dentro
## de la bolsa de y-sort compartida (`Main`/`MundoProfundo`), y su `position` tiene que ser el punto
## por el que quiere ser comparado: el CENTRO DE SU BASE (`pieza["orden"]`, lo calcula
## `ParedesSalas`). Ese punto cae SIEMPRE entre el centro de la celda de detrás y el de la de
## delante, así que el muro sale detrás del mobiliario de la sala de delante y delante del de la de
## atrás — las dos cosas a la vez, sin elegir.
##
## Este nodo NO lee el modelo ni decide alturas ni colores: eso sigue siendo trabajo exclusivo de
## `ParedesSalas` (la única que conoce a Construcción — ADR-0004). Aquí solo se pinta lo que llega.

## Grosor por defecto si la pieza llega sin "grosor" (red de seguridad — `ParedesSalas` siempre lo
## rellena en las jambas; los tramos con altura no lo usan).
const GROSOR_POR_DEFECTO: float = 4.0
## Grosor del remate superior de la pared (la franja clara de arriba — da la sensación de espesor).
## Puramente de DIBUJO (no de geometría/modelo), así que vive aquí y no en `ParedesSalas`.
const GROSOR_REMATE: float = 3.0
## ── EL RODAPIÉ, PIEZA DEL MURO (2026-08-05 · quick-spec §3c) ────────────────────────────────────
## Orden del usuario tras comparar con la demo de Summer: *"rodapié (zócalo) más pequeño y EN LA
## PARED, no en el suelo"*. Antes se pintaba dentro de la baldosa del suelo (una tira de 6 px en la
## celda que tocaba pared); hoy es una franja en la BASE de la cara del muro, dibujada por el mismo
## nodo que el muro. Que sea el MISMO nodo y no una pieza aparte es deliberado:
##   · el orden de profundidad sale gratis y es exacto (comparten `position`, o sea el punto de
##     orden del tramo) — dos nodos con la misma Y no tienen desempate garantizado en el y-sort;
##   · los tres MODOS DE ALTURA (auto/todas/bajitas) lo respetan solos: el rodapié se apoya en la
##     base, que no se mueve con la altura;
##   · una PUERTA se dibuja en dos muñones con un hueco en medio, así que el rodapié NO cruza el
##     hueco sin ninguna regla extra: solo existe donde existe muro.
## Alto en píxeles de la franja de rodapié (encargo: "2-3 px de alto en pantalla").
const ALTO_RODAPIE: float = 3.0
## Tope de seguridad: en un tramo muy bajo el rodapié no puede comerse la pared entera.
const FRACCION_MAX_RODAPIE: float = 0.5
## Cuánto se oscurece el propio color del rodapié para su línea de canto (la arista superior, la
## que lo separa del paño de pared y lo hace legible incluso sobre una pared blanca).
const OSCURECIDO_CANTO_RODAPIE: float = 0.22

## Los dos extremos de la base, ya en coordenadas LOCALES (relativas al punto de orden). Se guardan
## así —y no en mundo— porque la `position` del nodo ES el punto de orden: dibujar en absoluto lo
## pintaría desplazado justo esa cantidad.
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE
var _alto: float = 0.0
var _grosor: float = GROSOR_POR_DEFECTO
## Color del rodapié de este tramo. TRANSPARENTE = este tramo no lleva rodapié (la fachada de
## ladrillo, el cristal de una ventana, las jambas): lo decide `ParedesSalas`, nunca este nodo.
var _rodapie: Color = Color.TRANSPARENT


## Carga la pieza (un tramo o una jamba de `ParedesSalas`) y se coloca en su punto de orden. Único
## punto de entrada: así ningún tramo se queda con datos viejos por olvidar el `queue_redraw()`.
func fijar(pieza: Dictionary) -> void:
	position = pieza["orden"] as Vector2
	_desde = (pieza["desde"] as Vector2) - position
	_hasta = (pieza["hasta"] as Vector2) - position
	_color = pieza["color"] as Color
	_alto = float(pieza.get("alto", 0.0))
	_grosor = float(pieza.get("grosor", GROSOR_POR_DEFECTO))
	_rodapie = pieza.get("rodapie", Color.TRANSPARENT) as Color
	queue_redraw()


func _draw() -> void:
	# Sin altura (jambas y tramos degenerados): una línea de suelo, no una cara que sube.
	if _alto <= 0.0:
		draw_line(_desde, _hasta, _color, _grosor, true)
		return
	# TODAS las paredes suben; lo que cambia entre una trasera y una frontal es CUÁNTO (lo decide
	# `ParedesSalas._cara_de_arista`).
	var subir := Vector2(0.0, -_alto)
	draw_colored_polygon(
		PackedVector2Array([_desde, _hasta, _hasta + subir, _desde + subir]), _color
	)
	_dibujar_rodapie()
	draw_line(_desde + subir, _hasta + subir, _color.lightened(0.35), GROSOR_REMATE, true)
	draw_line(_desde, _hasta, _color.darkened(0.4), 1.5, true)


## La franja de rodapié en la BASE del paño (ver la nota de arriba). Se dibuja DESPUÉS del paño de
## pared —lo tapa— y ANTES del remate y de la línea de contacto con el suelo, que sigue quedando
## por encima haciendo de sombra de apoyo. Sin rodapié (color transparente) no cuesta nada.
func _dibujar_rodapie() -> void:
	if _rodapie.a <= 0.0:
		return
	var alto: float = minf(ALTO_RODAPIE, _alto * FRACCION_MAX_RODAPIE)
	if alto <= 0.0:
		return
	var sube := Vector2(0.0, -alto)
	draw_colored_polygon(
		PackedVector2Array([_desde, _hasta, _hasta + sube, _desde + sube]), _rodapie
	)
	draw_line(
		_desde + sube, _hasta + sube, _rodapie.darkened(OSCURECIDO_CANTO_RODAPIE), 1.0, true
	)
