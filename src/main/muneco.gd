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


## ── LA PALETA, SACADA DE LA REFERENCIA REAL (2026-07-31) ──────────────────────────────────────
## Muestreada píxel a píxel sobre `design/art/referencias/policia_recortado.png`, que es el render
## del uniforme del CNP verificado. No son colores inventados: son los del uniforme.
##
## ⚠️ PERO ACLARADOS A PROPÓSITO. El azul real del polo es casi negro (#242331). A tamaño de juego,
## sobre un suelo oscuro, un muñeco casi negro **desaparece**: se convierte en una mancha sin forma.
## Así que se sube el tono lo justo para que la silueta se lea, conservando que SIGA leyéndose como
## azul marino y no como azul medio. Es la primera vez que este proyecto tiene que elegir entre
## fidelidad y legibilidad — y a este tamaño gana la legibilidad, siempre.
const AZUL_UNIFORME := Color(0.20, 0.21, 0.30)      # real #242331, aclarado para que se vea
const AZUL_PANTALON := Color(0.16, 0.17, 0.25)      # real #1e1d29, un punto más oscuro que el polo
const NEGRO_BOTA := Color(0.13, 0.13, 0.14)         # real #323031
const PIEL := Color(0.64, 0.45, 0.40)               # real #a47366, cara y antebrazos
## La franja clara del pecho: es el "POLICÍA NACIONAL" serigrafiado. A este tamaño no se puede leer,
## pero la MANCHA clara sí se ve, y es lo que dice "este lleva algo escrito en el pecho".
const ROTULO_PECHO := Color(0.86, 0.87, 0.90)
## Qué fracción del brazo es MANGA. El polo es de manga corta, así que el antebrazo va descubierto —
## un detalle diminuto que a tamaño de juego se nota, porque parte el brazo en dos tonos.
const FRACCION_MANGA: float = 0.42
## Qué fracción de la pierna es BOTA (son de media caña).
const FRACCION_BOTA: float = 0.42


## Monta un muñeco completo y lo devuelve. `color` es el del torso (el del servicio, en los
## ciudadanos; el del uniforme, en los policías); la cabeza sale de aclararlo, que es la convención
## que ya venía de los rectángulos anteriores.
##
## ⚠️ Todo Control decorativo del mundo IGNORA el ratón: si no, se traga los clics del modo
## construcción (gotcha ya registrado en el proyecto).
static func construir(
	color: Color, con_gorra: bool = false, color_piel: Color = PIEL,
	color_pantalon: Color = Color(0, 0, 0, 0), color_calzado: Color = NEGRO_BOTA
) -> Node2D:
	var pantalon: Color = color.darkened(0.3) if color_pantalon.a == 0.0 else color_pantalon
	var raiz := Node2D.new()
	# Las piernas van las PRIMERAS para que el torso las tape por delante: sin eso se ve el corte
	# entre pierna y cadera cuando la pierna se adelanta.
	raiz.add_child(_pierna("PiernaIzq", -SEPARACION_PIERNAS, pantalon, color_calzado, 0.0))
	raiz.add_child(_pierna("PiernaDer", SEPARACION_PIERNAS, pantalon.darkened(0.12), color_calzado, 0.08))
	# Los brazos, TAMBIÉN antes del torso: uno de los dos queda por detrás del cuerpo y así el
	# muñeco tiene algo de volumen en vez de parecer un recortable plano.
	raiz.add_child(_brazo("BrazoIzq", -ANCHO_TORSO * 0.5, color, color_piel, 0.0))
	raiz.add_child(_brazo("BrazoDer", ANCHO_TORSO * 0.5, color.darkened(0.12), color_piel, 0.1))
	raiz.add_child(_caja(
		"Torso", Vector2(-ANCHO_TORSO * 0.5, Y_CADERA - ALTO_TORSO),
		Vector2(ANCHO_TORSO, ALTO_TORSO), color
	))
	if con_gorra:
		# El rótulo del pecho: solo para quien lleva uniforme (un ciudadano no lleva nada escrito).
		raiz.add_child(_caja(
			"Rotulo", Vector2(-0.5, Y_CADERA - ALTO_TORSO + 3.0), Vector2(5.0, 2.0), ROTULO_PECHO
		))
	var y_cabeza: float = Y_CADERA - ALTO_TORSO - ALTO_CABEZA
	raiz.add_child(_caja(
		"Cabeza", Vector2(-ANCHO_CABEZA * 0.5, y_cabeza), Vector2(ANCHO_CABEZA, ALTO_CABEZA),
		color_piel
	))
	if con_gorra:
		# La gorra es lo que distingue al funcionario de un vistazo, incluso a tamaño diminuto: es
		# lo primero que sobrevive cuando el muñeco se ve pequeño (art bible: la silueta manda).
		# Dos piezas, copa y VISERA, porque la visera es lo que la hace inconfundiblemente una gorra
		# de béisbol y no un gorro cualquiera.
		raiz.add_child(_caja(
			"Gorra", Vector2(-ANCHO_CABEZA * 0.5, y_cabeza - 3.0),
			Vector2(ANCHO_CABEZA, 3.5), color.darkened(0.35)
		))
		raiz.add_child(_caja(
			"Visera", Vector2(-ANCHO_CABEZA * 0.5 - 1.5, y_cabeza - 0.5),
			Vector2(ANCHO_CABEZA + 3.0, 1.5), color.darkened(0.5)
		))
	return raiz


## Una pierna: pantalón arriba y BOTA abajo, colgando de la cadera. `tono` desempata levemente la
## pierna de atrás para que no se confundan cuando se cruzan.
static func _pierna(nombre: String, x: float, color_tela: Color, color_bota: Color, tono: float) -> Node2D:
	var pivote := Node2D.new()
	pivote.name = nombre
	pivote.position = Vector2(x, Y_CADERA)
	var largo_bota: float = ALTO_PIERNA * FRACCION_BOTA
	pivote.add_child(_caja(
		"Tela", Vector2(-ANCHO_PIERNA * 0.5, 0.0),
		Vector2(ANCHO_PIERNA, ALTO_PIERNA - largo_bota), color_tela.darkened(tono)
	))
	pivote.add_child(_caja(
		"Bota", Vector2(-ANCHO_PIERNA * 0.5 - 0.5, ALTO_PIERNA - largo_bota),
		Vector2(ANCHO_PIERNA + 1.0, largo_bota), color_bota.darkened(tono)
	))
	return pivote


## Un brazo: MANGA CORTA arriba y antebrazo de piel abajo. Es un detalle diminuto que a tamaño de
## juego se nota mucho, porque parte el brazo en dos tonos y da la lectura de "va en manga corta".
static func _brazo(nombre: String, x: float, color_manga: Color, color_piel: Color, tono: float) -> Node2D:
	var pivote := Node2D.new()
	pivote.name = nombre
	pivote.position = Vector2(x, Y_HOMBRO)
	var largo_manga: float = ALTO_BRAZO * FRACCION_MANGA
	pivote.add_child(_caja(
		"Manga", Vector2(-ANCHO_BRAZO * 0.5, 0.0), Vector2(ANCHO_BRAZO, largo_manga),
		color_manga.darkened(tono)
	))
	pivote.add_child(_caja(
		"Antebrazo", Vector2(-ANCHO_BRAZO * 0.5, largo_manga),
		Vector2(ANCHO_BRAZO, ALTO_BRAZO - largo_manga), color_piel.darkened(tono)
	))
	return pivote


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


static func _caja(nombre: String, pos: Vector2, tam: Vector2, color: Color) -> ColorRect:
	var caja := ColorRect.new()
	caja.name = nombre
	caja.position = pos
	caja.size = tam
	caja.color = color
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caja
