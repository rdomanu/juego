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
## ── TONOS DE PIEL (feedback del usuario, 2026-07-31) ─────────────────────────────────────────
## *"el tono de piel de la gente debe ser más blanco, parecen sudamericanos o bien árabes, deben ser
## europeos, tanto los policías como los que van al DNI; para TIEs sí está bien ese tono de piel
## para distinguir"*.
##
## El render de referencia salió con una piel bastante tostada (#a47366) por la luz cálida de
## estudio, no porque el uniforme la pida. Se aclara al tono europeo medio.
##
## Y no es UN tono, son CUATRO: una cola de gente toda del mismo color exacto se lee como clones.
## Se reparten de forma determinista por el número de turno de cada persona, así que el mismo
## ciudadano siempre tiene la misma cara y al guardar y cargar no cambia de piel.
const PIELES_EUROPEAS: Array[Color] = [
	Color(0.91, 0.78, 0.69),
	Color(0.87, 0.72, 0.62),
	Color(0.95, 0.83, 0.75),
	Color(0.82, 0.67, 0.57),
]
## El tono de quien viene a por el TIE (la tarjeta de identidad de EXTRANJERO). Decisión del usuario
## para que la cola se lea de un vistazo.
##
## 📌 Nota de oficio, por si algún día se quiere revisar: a tamaño de juego la cara son 3-4 píxeles,
## así que el color de piel es una señal DÉBIL. La fuerte —y la que ya funcionaba— es el COLOR DEL
## TORSO (`COLOR_TIE` frente a `COLOR_DOC`), que ocupa diez veces más. La piel suma, pero el que de
## verdad distingue la cola es el torso.
const PIEL_TIE := Color(0.64, 0.45, 0.40)           # el tono del render original
## Por defecto (policías y quien no diga otra cosa): el primero de los europeos.
const PIEL := Color(0.91, 0.78, 0.69)


## El tono de piel de una persona, repartido de forma determinista por su número de turno: la cola
## se ve variada pero cada uno mantiene SIEMPRE el suyo.
static func piel_de(numero_turno: int) -> Color:
	return PIELES_EUROPEAS[posmod(numero_turno, PIELES_EUROPEAS.size())]
## La franja clara del pecho: es el "POLICÍA NACIONAL" serigrafiado. A este tamaño no se puede leer,
## pero la MANCHA clara sí se ve, y es lo que dice "este lleva algo escrito en el pecho".
const ROTULO_PECHO := Color(0.86, 0.87, 0.90)
## Qué fracción del brazo es MANGA. El polo es de manga corta, así que el antebrazo va descubierto —
## un detalle diminuto que a tamaño de juego se nota, porque parte el brazo en dos tonos.
const FRACCION_MANGA: float = 0.42
## Qué fracción de la pierna es BOTA (son de media caña).
const FRACCION_BOTA: float = 0.42
## Color de los ojos. Casi negro, no negro puro: a este tamaño el negro puro hace agujeros.
const COLOR_OJOS := Color(0.12, 0.10, 0.10)


## ── PRUEBA: MUÑECO DE SPRITE 3D PRE-RENDERIZADO (2026-07-31) ──────────────────────────────────
## Alternativa al muñeco de piezas: en vez de rectángulos, un sprite salido de renderizar un modelo
## 3D desde 8 ángulos (`tools/render_sprites.gd`). Es el camino de Theme Hospital y RollerCoaster
## Tycoon, y su ventaja es la coherencia: **es la misma persona girada**, no ocho dibujos parecidos.
##
## Convive con el de piezas a propósito, para poder compararlos en la misma pantalla. Si el archivo
## del sprite no está, se cae al muñeco de piezas sin romper nada.
const RUTA_SPRITES := "res://assets/sprites/personajes/"
## Cuántos ángulos se renderizaron.
const DIRECCIONES_SPRITE: int = 8
## Y cuántos fotogramas tiene el ciclo de andar de cada ángulo.
const FOTOGRAMAS_SPRITE: int = 8


## ¿Hay sprites de este personaje? (basta con mirar el primero).
static func hay_sprites(prefijo: String, alto: int) -> bool:
	return ResourceLoader.exists("%s%s_%dpx_0_0.png" % [RUTA_SPRITES, prefijo, alto])


## Monta un muñeco hecho de SPRITE. El nodo se ancla por la BASE, igual que el de piezas: los pies
## en (0,0), que es el punto de la celda donde pisa.
static func construir_sprite(prefijo: String, alto: int) -> Node2D:
	var raiz := Node2D.new()
	# SOMBRA DE CONTACTO (2026-08-14): NO es un hijo de este nodo — la pinta la capa única
	# `CapaSombras` (un CanvasItem nacido en la carga dentro de la bolsa y-sort no se renderiza,
	# gotcha cazado con sondas). `NPCsFlujo.colocar_muneco` deja en el VISUAL las metas
	# `pos_suelo_sombra` (el destino SIN el bote del paso) y `sombra_visible` (false sentado).
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	raiz.add_child(sprite)
	raiz.set_meta(&"prefijo", prefijo)
	raiz.set_meta(&"alto_sprite", alto)
	raiz.set_meta(&"direccion", 0)
	raiz.set_meta(&"fotograma", 0)
	raiz.set_meta(&"sentado", false)
	_poner_sprite(raiz, 0, 0)
	return raiz


## Cambia el sprite al de esa dirección y ese fotograma del ciclo, y lo recoloca sobre sus pies.
##
## El ancla se recalcula en CADA cambio porque cada imagen viene recortada a su contenido: de perfil
## ocupa menos que de frente, y con una pierna adelantada más que con los pies juntos. Sin
## recalcular, el personaje daría un salto lateral en cada paso.
static func _poner_sprite(
	muneco: Node2D, direccion: int, fotograma: int, sentado: bool = false
) -> void:
	var sprite: Sprite2D = muneco.get_node_or_null("Sprite")
	if sprite == null:
		return
	var dir: int = posmod(direccion, DIRECCIONES_SPRITE)
	var alto: int = int(muneco.get_meta(&"alto_sprite"))
	var prefijo: String = muneco.get_meta(&"prefijo")
	# SENTADO es una sola imagen por dirección (sentado no se mueve), así que no lleva fotograma.
	var ruta: String = (
		"%s%s_%dpx_sit_%d.png" % [RUTA_SPRITES, prefijo, alto, dir] if sentado
		else "%s%s_%dpx_%d_%d.png" % [
			RUTA_SPRITES, prefijo, alto, dir, posmod(fotograma, FOTOGRAMAS_SPRITE)
		]
	)
	if not ResourceLoader.exists(ruta):
		return
	var textura: Texture2D = load(ruta)
	sprite.texture = textura
	sprite.offset = Vector2(-textura.get_width() / 2.0, -float(textura.get_height()))


## Avanza el ciclo de andar de un muñeco de sprite. `fase` es la MISMA que mueve al muñeco de
## piezas, así que los dos caminan al mismo ritmo y con el mismo criterio: el paso va con el CAMINO
## RECORRIDO, no con el reloj. Parado se queda en el fotograma 0 (de pie).
static func animar_sprite(
	muneco: Node2D, fase: float, andando: float, sentado: bool = false
) -> void:
	var f: int = 0
	if andando > 0.1 and not sentado:
		f = posmod(roundi(fase / TAU * FOTOGRAMAS_SPRITE), FOTOGRAMAS_SPRITE)
	if int(muneco.get_meta(&"fotograma", -1)) == f 			and bool(muneco.get_meta(&"sentado", false)) == sentado:
		return   # ni el fotograma ni la postura cambian: no se recarga la textura por nada
	muneco.set_meta(&"fotograma", f)
	muneco.set_meta(&"sentado", sentado)
	_poner_sprite(muneco, int(muneco.get_meta(&"direccion", 0)), f, sentado)


## Construye un muñeco de sprite YA SENTADO y mirando a `mirando_hacia` (un vector del MUNDO, no de
## pantalla — mismo criterio que `orientar_sprite`, ver su comentario). Para elementos ESTÁTICOS que
## no andan (el policía fijo de su ventanilla: nace sentado y no se mueve, así que nunca pasa por
## `colocar_muneco`/`animar_sprite`, que son de quien camina). El render ya baja el cuerpo a la
## altura de una silla (`tools/render_sprites_animado.gd`, pose final 2026-08-01), así que aquí solo
## hace falta elegir la imagen `..._sit_N.png` que toca.
static func construir_sprite_sentado(prefijo: String, alto: int, mirando_hacia: Vector2) -> Node2D:
	var raiz: Node2D = construir_sprite(prefijo, alto)
	var rumbo: float = atan2(mirando_hacia.y, mirando_hacia.x)
	var indice: int = posmod(roundi(rumbo / TAU * DIRECCIONES_SPRITE), DIRECCIONES_SPRITE)
	raiz.set_meta(&"direccion", indice)
	raiz.set_meta(&"sentado", true)
	_poner_sprite(raiz, indice, 0, true)
	# Sentado no proyecta sombra de contacto propia (el asiento pone la suya) — y como este visual
	# nunca se registra en `CapaSombras` (solo se registran los andantes), no hay nada que apagar.
	return raiz


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
	# LOS OJOS. Dos puntos, y solo se ven cuando el muñeco viene HACIA la cámara: es lo que hace que
	# se sepa de un vistazo si alguien va o viene, sin dibujar un solo sprite nuevo. De espaldas se
	# ocultan y lo que queda es la nuca (la cabeza pelada), que es exactamente lo que verías.
	var ojos := Node2D.new()
	ojos.name = "Ojos"
	ojos.add_child(_caja("Izq", Vector2(-2.5, y_cabeza + 2.0), Vector2(1.5, 1.5), COLOR_OJOS))
	ojos.add_child(_caja("Der", Vector2(1.0, y_cabeza + 2.0), Vector2(1.5, 1.5), COLOR_OJOS))
	raiz.add_child(ojos)
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


## ── EL PAPEL (viaje de la impresora, GDD impresora-documentos-tramite.md) ────────────────────────
## El documento que trae el funcionario al volver y con el que sale el ciudadano. Un rectángulo BLANCO
## con un borde gris tenue — relleno plano tolerado, mismo criterio que las piezas `_caja` del resto
## del muñeco (son formas de un color, no texturas; el detalle que se lee a este tamaño es la
## SILUETA). El borde es OTRO rectángulo gris debajo, un pelo más grande por cada lado — el mismo
## truco de "borde por capas" que ya usa el juego en vez de un `Line2D` aparte.
const ANCHO_PAPEL: float = 7.0
const ALTO_PAPEL: float = 9.0
const COLOR_PAPEL := Color(0.96, 0.96, 0.94)
const COLOR_BORDE_PAPEL := Color(0.55, 0.55, 0.52)
## Dónde cuelga del muñeco, relativo a la raíz del visual.
##
## 🐛 CORREGIDO (2026-08-09, usuario: *"el papel que se les entrega va como pegado a la cara, debería
## ir en la mano con el juego del movimiento de las manos y respetar las capas"*). Estaba en y = −22
## y la CABEZA ocupa de −28 a −22 (`Y_CADERA − ALTO_TORSO − ALTO_CABEZA`): el papel caía justo sobre
## la cara. La MANO está al final del brazo, que cuelga del hombro (`Y_HOMBRO` = −20) y mide
## `ALTO_BRAZO` = 9 → y ≈ −11. Ahí va ahora, un pelo por encima para que se lea "agarrado" y no
## "colgando". La X sale del ancho del torso: el papel va por fuera del cuerpo, en el lado de la mano.
const POSICION_PAPEL := Vector2(ANCHO_TORSO * 0.5 + 1.0, Y_HOMBRO + ALTO_BRAZO - 2.0)
## Cuánto acompaña el papel al vaivén del brazo (radianes). El brazo oscila `AMPLITUD_BRAZO`; el
## papel va agarrado, así que se mueve con él pero atenuado — una mano que sujeta algo balancea menos.
const VAIVEN_PAPEL: float = 0.55
## Direcciones de sprite en las que el muñeco va DE ESPALDAS a la cámara (índice = rumbo i×45° desde
## el este hacia el sur, ver `orientar_sprite`): 5, 6 y 7 miran al norte. Con el personaje de
## espaldas su propio cuerpo tapa lo que lleva en la mano, así que el papel se dibuja DETRÁS —
## "si se gira se oculta el papel con el cuerpo", que es justo lo que pidió el usuario.
const DIRECCIONES_DE_ESPALDAS: Array[int] = [5, 6, 7]


## Un papel sostenido en la mano, listo para colgar de un muñeco. Quien lo cuelga (`NPCsFlujo.
## _poner_papel` para el funcionario, `NPCCiudadano._refrescar_papel` para el ciudadano) lo añade
## como ÚLTIMO hijo del visual — el orden del árbol ES el orden de dibujo, así que entra DELANTE de
## todo, igual que la taza.
static func papel() -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Papel"
	raiz.position = POSICION_PAPEL
	raiz.add_child(_caja(
		"Borde", Vector2(-ANCHO_PAPEL * 0.5 - 1.0, -ALTO_PAPEL * 0.5 - 1.0),
		Vector2(ANCHO_PAPEL + 2.0, ALTO_PAPEL + 2.0), COLOR_BORDE_PAPEL
	))
	raiz.add_child(_caja(
		"Hoja", Vector2(-ANCHO_PAPEL * 0.5, -ALTO_PAPEL * 0.5), Vector2(ANCHO_PAPEL, ALTO_PAPEL),
		COLOR_PAPEL
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


## ── HACIA DÓNDE MIRA (2026-07-31) ────────────────────────────────────────────────────────────
## Encargo del usuario: *"solo que camine y que cambie de dirección y se vea bien"*.
##
## En isométrico hay cuatro direcciones de marcha, y en pantalla se reducen a dos preguntas:
##   · ¿va hacia la IZQUIERDA o hacia la DERECHA?  → se espeja el muñeco entero
##   · ¿viene HACIA la cámara o se va de ESPALDAS? → se le ven los ojos, o no
##
## Con esas dos se cubren las cuatro direcciones **sin un solo dibujo nuevo**. Es el truco de
## siempre en los juegos 2D: no se dibujan cuatro personajes, se reutiliza uno.
##
## El rótulo del pecho también se oculta de espaldas — por detrás no se ve lo que pone delante.
## Elige la dirección de un muñeco de SPRITE a partir de hacia dónde se mueve **EN EL MUNDO**.
##
## ⚠️ Y "en el mundo", no "en pantalla" — que fue el fallo del primer intento: *"si van a la derecha
## el cuerpo gira a la izquierda y camina como hacia atrás"*. La causa es sutil pero es de las que
## se repiten, así que queda escrita:
##
##   El sprite se generó girando el MODELO en el espacio 3D, así que cada imagen corresponde a un
##   rumbo del MUNDO. En cambio la proyección isométrica DEFORMA los ángulos: dos rumbos del mundo
##   separados 90° pueden verse en pantalla separados 45°. Elegir el sprite por el ángulo de
##   pantalla mezcla los dos sistemas y sale un personaje que anda de espaldas.
##
## ── LA CUENTA, QUE AHORA ES TRIVIAL ───────────────────────────────────────────────────────────
## El renderizador ya no gira el modelo "un octavo cada vez" y que salga lo que salga: le pregunta
## al esqueleto hacia dónde miran los pies y lo gira para que **el sprite `i` sea el personaje
## mirando al rumbo `i × 45°` de la rejilla**, contado desde el este (+X) hacia el sur (+Y).
##
## Como el índice significa lo mismo en las dos partes, aquí basta con el ángulo del rumbo. Antes
## había que compensar un desfase que salía de suponer la orientación del modelo — y de ahí venían
## los ciudadanos entrando de lado.
static func orientar_sprite(muneco: Node2D, avance_mundo: Vector2) -> void:
	if avance_mundo.length_squared() < 0.0001:
		return
	var rumbo: float = atan2(avance_mundo.y, avance_mundo.x)
	var indice: int = posmod(
		roundi(rumbo / TAU * DIRECCIONES_SPRITE), DIRECCIONES_SPRITE
	)
	if int(muneco.get_meta(&"direccion", -1)) == indice:
		return   # ya está en esa dirección: no se recarga la textura por nada
	muneco.set_meta(&"direccion", indice)
	_poner_sprite(muneco, indice, int(muneco.get_meta(&"fotograma", 0)),
		bool(muneco.get_meta(&"sentado", false)))


## Coloca el papel que lleva un muñeco de SPRITE en la mano y lo hace acompañar al paso (2026-08-09,
## encargo del usuario). Tres cosas, todas pedidas:
##  1. En la MANO, no en la cara — la Y sale del brazo (ver `POSICION_PAPEL`), no de un número a ojo.
##  2. Con "el juego del movimiento de las manos": se balancea con la misma `fase` del paso que mueve
##     el resto del cuerpo, atenuado (`VAIVEN_PAPEL`), y solo mientras de verdad anda (`andando`).
##  3. RESPETANDO LAS CAPAS: de espaldas el papel pasa DETRÁS del cuerpo (primer hijo del visual en
##     vez del último) — el orden del árbol ES el orden de dibujo. Y el lado (izquierda/derecha) se
##     elige según hacia dónde mire, para que no salga flotando por delante del pecho.
##
## Se llama cada frame desde `NPCCiudadano._physics_process`; si el muñeco no lleva papel, no hace
## nada (cero coste).
static func colocar_papel(visual: Node2D, fase: float, andando: float) -> void:
	var papel: Node2D = visual.get_node_or_null("Papel") as Node2D
	if papel == null:
		return
	# La dirección la lleva el SPRITE DEL CUERPO, a quien orienta `orientar_sprite`. Se BUSCA por su
	# meta, no por el índice 0: en cuanto este mismo método manda el papel detrás, el papel PASA a ser
	# el primer hijo y leerlo como cuerpo hacía que la capa oscilara de un frame a otro (cazado con
	# la sonda in-game: el visual reportaba `cuerpo=Papel`).
	var direccion := 0
	for hijo: Node in visual.get_children():
		if hijo.has_meta(&"direccion"):
			direccion = int(hijo.get_meta(&"direccion"))
			break
	var de_espaldas: bool = DIRECCIONES_DE_ESPALDAS.has(direccion)
	# Lado: con el personaje mirando al oeste (índices 3..5) la mano visible es la otra.
	var a_la_izquierda: bool = direccion >= 3 and direccion <= 5
	papel.position = Vector2(
		-POSICION_PAPEL.x if a_la_izquierda else POSICION_PAPEL.x, POSICION_PAPEL.y
	)
	papel.rotation = sin(fase) * VAIVEN_PAPEL * andando
	# El papel es hijo del VISUAL (que contiene el sprite del cuerpo): moverlo al principio lo manda
	# detrás; al final, delante.
	var indice_destino: int = 0 if de_espaldas else visual.get_child_count() - 1
	if papel.get_index() != indice_destino:
		visual.move_child(papel, indice_destino)


static func orientar(muneco: Node2D, hacia_izquierda: bool, de_espaldas: bool) -> void:
	# Espejar con la escala: -1 en X da la vuelta a todo el conjunto de una vez, piezas incluidas.
	muneco.scale.x = -1.0 if hacia_izquierda else 1.0
	var ojos: Node2D = muneco.get_node_or_null("Ojos")
	if ojos != null:
		ojos.visible = not de_espaldas
	var rotulo: Node = muneco.get_node_or_null("Rotulo")
	if rotulo != null:
		(rotulo as CanvasItem).visible = not de_espaldas


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
