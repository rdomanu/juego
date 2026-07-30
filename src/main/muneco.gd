extends Node
## Muneco — el muñeco de PIEZAS SUELTAS que anda de verdad.
##
## Nace del encargo del usuario (2026-07-31), después de ver el primer sprite realista deslizándose
## tieso por el suelo: *"dios qué feo, no hay ningún tipo de animación al caminar ni nada"*.
##
## ── LA IDEA, EN LLANO ──────────────────────────────────────────────────────────────────────────
## En vez de un dibujo entero, el muñeco se monta con **piezas sueltas** —dos piernas, dos brazos,
## torso, cabeza y, si es policía, gorra— y el código las mueve. Como un muñeco de papel recortado y
## sujeto con encuadernadores: no se redibuja nada, se GIRA cada pieza sobre su articulación.
##
## Por qué así y no con fotogramas dibujados:
##  · **No cuesta ni un píxel de arte.** Son las mismas formas de colores que ya había.
##  · Un ciclo de andar dibujado a mano son ~8 fotogramas × 8 direcciones = 64 dibujos. Solo para
##    caminar. Aquí es una fórmula.
##  · Es de donde sale la gracia de Two Point: no dibujan realismo, **exageran el movimiento de
##    formas simples**.
##  · Y no se tira: el día que llegue el arte 3D pre-renderizado, se sustituye pieza a pieza sin
##    tocar una línea del juego.
##
## ── EL CICLO DE ANDAR ─────────────────────────────────────────────────────────────────────────
## Todo cuelga de una sola `fase`, que sale del CAMINO RECORRIDO (no del reloj — ver
## `NPCsFlujo.colocar_muneco`). Con esa fase:
##  · las **piernas** se abren y cierran en oposición (una adelante, la otra atrás);
##  · los **brazos** hacen lo contrario que la pierna de su lado, que es como anda una persona de
##    verdad (brazo izquierdo con pierna derecha);
##  · el **cuerpo bota** una vez por cada pie, no una por zancada.
##
## Y un `andando` de 0 a 1 apaga la animación cuando se para, para que no se quede congelado a media
## zancada como un maniquí de escaparate.

## Medidas del muñeco, en píxeles. Total 28 de alto: se lee a la escala del juego (el rombo de una
## celda mide 80×40) sin comerse la casilla del vecino.
const ALTO_PIERNA: float = 9.0
const ANCHO_PIERNA: float = 4.0
const SEPARACION_PIERNAS: float = 3.0
const ALTO_TORSO: float = 13.0
const ANCHO_TORSO: float = 12.0
const ALTO_CABEZA: float = 6.0
const ANCHO_CABEZA: float = 8.0
const ALTO_BRAZO: float = 9.0
const ANCHO_BRAZO: float = 3.0
## Alturas de las articulaciones, medidas desde los PIES (que están en y = 0).
const Y_CADERA: float = -ALTO_PIERNA
const Y_HOMBRO: float = Y_CADERA - ALTO_TORSO + 2.0

## Cuánto se abren las piernas en lo alto del paso, en radianes (~26°). Es la amplitud que hace que
## se lea "está andando" sin que parezca que va haciendo el paso de la oca.
const AMPLITUD_PIERNA: float = 0.45
## Los brazos se mueven MENOS que las piernas: al andar tranquilo se balancean, no reman.
const AMPLITUD_BRAZO: float = 0.28
## Cuánto sube el cuerpo en lo alto del paso.
const ALTURA_BOTE: float = 1.6
## Lo rápido que arranca y para la animación al echar a andar o pararse. 0.15 por frame ≈ un cuarto
## de segundo: ni un frenazo seco ni una parada de tres pasos.
const SUAVIZADO: float = 0.15


## Monta un muñeco completo y lo devuelve. `color` es el del torso (el del servicio, en los
## ciudadanos; el del uniforme, en los policías); la cabeza sale de aclararlo, que es la convención
## que ya venía de los rectángulos anteriores.
##
## ⚠️ Todo Control decorativo del mundo IGNORA el ratón: si no, se traga los clics del modo
## construcción (gotcha ya registrado en el proyecto).
static func construir(color: Color, con_gorra: bool = false) -> Node2D:
	var raiz := Node2D.new()
	# Las piernas van las PRIMERAS para que el torso las tape por delante: sin eso se ve el corte
	# entre pierna y cadera cuando la pierna se adelanta.
	raiz.add_child(_extremidad(
		"PiernaIzq", Vector2(-SEPARACION_PIERNAS, Y_CADERA), ANCHO_PIERNA, ALTO_PIERNA,
		color.darkened(0.35)
	))
	raiz.add_child(_extremidad(
		"PiernaDer", Vector2(SEPARACION_PIERNAS, Y_CADERA), ANCHO_PIERNA, ALTO_PIERNA,
		color.darkened(0.45)
	))
	# Los brazos, TAMBIÉN antes del torso: uno de los dos queda por detrás del cuerpo y así el
	# muñeco tiene algo de volumen en vez de parecer un recortable plano.
	raiz.add_child(_extremidad(
		"BrazoIzq", Vector2(-ANCHO_TORSO * 0.5, Y_HOMBRO), ANCHO_BRAZO, ALTO_BRAZO,
		color.darkened(0.2)
	))
	raiz.add_child(_extremidad(
		"BrazoDer", Vector2(ANCHO_TORSO * 0.5, Y_HOMBRO), ANCHO_BRAZO, ALTO_BRAZO,
		color.darkened(0.3)
	))
	raiz.add_child(_caja(
		"Torso", Vector2(-ANCHO_TORSO * 0.5, Y_CADERA - ALTO_TORSO),
		Vector2(ANCHO_TORSO, ALTO_TORSO), color
	))
	var y_cabeza: float = Y_CADERA - ALTO_TORSO - ALTO_CABEZA
	raiz.add_child(_caja(
		"Cabeza", Vector2(-ANCHO_CABEZA * 0.5, y_cabeza), Vector2(ANCHO_CABEZA, ALTO_CABEZA),
		color.lightened(0.35)
	))
	if con_gorra:
		# La gorra es lo que distingue al funcionario de un vistazo, incluso a tamaño diminuto: es
		# lo primero que sobrevive cuando el muñeco se ve pequeño (art bible: la silueta manda).
		raiz.add_child(_caja(
			"Gorra", Vector2(-ANCHO_CABEZA * 0.5 - 1.0, y_cabeza - 2.5),
			Vector2(ANCHO_CABEZA + 2.0, 3.0), color.darkened(0.25)
		))
	return raiz


## Mueve las piezas. `fase` avanza con el camino recorrido y `andando` va de 0 (parado) a 1
## (andando) — se pasa suavizado desde fuera para que arranque y pare sin tirones.
##
## Cero allocs: solo se tocan `rotation` y `position` de nodos que ya existen.
static func animar(muneco: Node2D, fase: float, andando: float) -> void:
	var vaiven: float = sin(fase) * andando
	var pierna_izq: Node2D = muneco.get_node_or_null("PiernaIzq")
	if pierna_izq == null:
		return   # muñeco de otra clase (o a medio construir): no se toca nada
	pierna_izq.rotation = vaiven * AMPLITUD_PIERNA
	(muneco.get_node("PiernaDer") as Node2D).rotation = -vaiven * AMPLITUD_PIERNA
	# Los brazos, al REVÉS que la pierna de su mismo lado: así es como anda una persona.
	(muneco.get_node("BrazoIzq") as Node2D).rotation = -vaiven * AMPLITUD_BRAZO
	(muneco.get_node("BrazoDer") as Node2D).rotation = vaiven * AMPLITUD_BRAZO


## Cuánto sube el cuerpo en este instante del paso. Va aparte porque lo aplica quien COLOCA al
## muñeco (el bote es un desplazamiento de todo el conjunto, no el giro de una pieza).
##
## `absf` y no `sin` a secas: se bota una vez por CADA PIE, o sea el doble de veces que zancadas.
static func bote(fase: float, andando: float) -> float:
	return absf(sin(fase)) * ALTURA_BOTE * andando


## Una extremidad: un pivote en la articulación con la pieza colgando hacia abajo. Girar el pivote
## mueve la extremidad entera desde el hombro o la cadera, que es lo que hace que parezca una
## articulación y no una pieza que se desliza.
static func _extremidad(
	nombre: String, articulacion: Vector2, ancho: float, largo: float, color: Color
) -> Node2D:
	var pivote := Node2D.new()
	pivote.name = nombre
	pivote.position = articulacion
	pivote.add_child(_caja("Pieza", Vector2(-ancho * 0.5, 0.0), Vector2(ancho, largo), color))
	return pivote


static func _caja(nombre: String, pos: Vector2, tam: Vector2, color: Color) -> ColorRect:
	var caja := ColorRect.new()
	caja.name = nombre
	caja.position = pos
	caja.size = tam
	caja.color = color
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caja
