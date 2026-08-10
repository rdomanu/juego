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
## ── LOS SEMIEJES: CUÁNTO MIDE LA BASE, NO SOLO DÓNDE ESTÁ (2026-08-04, muebles DE PARED) ──────
## El centro de la base basta para CENTRAR un mueble en su celda. No basta para ARRIMARLO a la
## pared (estanterías): para eso hay que saber además cuánto FONDO tiene, y eso son dos números
## más — los semiejes del rectángulo de suelo que pisa, uno por eje del plano cuadrado.
##
## Salen de la misma silueta, sin medir nada a ojo. Los dos bordes INFERIORES del paralelogramo de
## la base son, exactamente, el borde SUR y el borde ESTE del rectángulo de suelo (los otros dos
## quedan ocultos tras el propio mueble), y en la proyección 2:1 cada uno de ellos es una recta con
## invariante conocida:
##   · borde SUR  (fila `v` constante):  `y − x/2` es constante a lo largo de él;
##   · borde ESTE (columna `u` constante): `y + x/2`, ídem.
## Y ninguna otra parte de la silueta puede pasarse de esas dos rectas hacia abajo (nada se dibuja
## por debajo del suelo que pisa). Así que basta recorrer el CONTORNO INFERIOR (por columna, el
## píxel opaco más bajo) y quedarse con el MÁXIMO de cada invariante: eso ES la recta del borde.
## La distancia del centro a cada borde, deshecha la proyección, da el semieje.
##
## Es la misma idea que el centro: reconstruir del dibujo lo que el render sabía del modelo 3D.
##
## ── COSTE ─────────────────────────────────────────────────────────────────────────────────────
## Se escanea el PNG UNA vez por textura y se cachea por `resource_path` (`_cache_base`). Un
## mostrador de 100×74 son ~7.400 lecturas de píxel una sola vez en toda la partida (el barrido de
## cada columna sale por el primer píxel opaco que encuentra subiendo desde abajo). Nada de esto
## ocurre en `_process`.

## Alfa por encima del cual un píxel cuenta como "mueble".
##
## Subido de 0,05 a 0,50 el 2026-08-10, tras re-renderizar el catálogo con SUPERMUESTREO: la
## reducción LANCZOS deja un halo de píxeles muy tenues alrededor de la silueta, y con 0,05 ese
## halo contaba como mueble. Efecto medido en `comodidad_estanteria_suelta_90`: los semiejes
## sumaban 18,50 contra un semiancho de 16,50 — 2 px de desvío, fuera de la tolerancia de la
## invariante geométrica (`anclaje_arrimado_test`), o sea que el mueble se arrimaba mal.
## Con el umbral a 0,50 el desvío cae a 0,50 px, y a 0,75 sería exacto; se elige 0,50 por dejar
## margen a piezas con bordes legítimamente translúcidos.
## La medida debe describir el MUEBLE, no el halo con el que se dibuja.
const UMBRAL_ALFA: float = 0.50

## ── HACIA DÓNDE DA LA ESPALDA UN MUEBLE (y por qué NO hay una tabla global) ────────────────────
## La rotación del render (0/90/180/270°) NO dice por sí sola hacia dónde mira un mueble: dice
## cuánto se ha GIRADO respecto de cómo venía puesto en la escena 3D de origen, y cada cluster del
## catálogo venía puesto como le dio la gana al autor del modelo. MEDIDO el 2026-08-04 sobre los
## PNG ya renderizados (con `semiejes_base`, o sea sin suponer nada):
##
##   · `comodidad_estanteria` (OBJ_007) a 0°: base de 7,5 × 36,5 px → es LARGA en el eje Y y
##     delgada en el X, luego su cara grande mira al este/oeste. En el PNG los estantes se ven en la
##     cara ANCHA de la derecha, que en la proyección es la cara ESTE → a 0° mira al ESTE.
##   · `comodidad_estanteria_suelta` (OBJ_022) a 0°: base de 28,5 × 6,5 px → larga en X, luego mira
##     al norte/sur; los estantes se ven en la cara ancha de la IZQUIERDA, que es la cara SUR → a 0°
##     mira al SUR. **Noventa grados de diferencia con la otra**, y no es un error de nadie: son dos
##     clusters distintos del mismo catálogo 3D.
##
## Lo que SÍ es universal (y por eso vive aquí) es el CICLO: girar +90° en el render mueve la
## espalda un paso de esta lista. Verificado con las dos estanterías a la vez, 8 PNG: la grande va
## oeste → sur → este → norte y la pequeña norte → oeste → sur → este; la misma vuelta empezando en
## sitios distintos.
##
## Así que un mueble de pared declara UN dato —hacia dónde da la espalda a 0°— y las otras tres
## rotaciones salen de aquí. Y ese dato no se cree a ciegas: `eje_corto()` mide de los píxeles por
## qué eje es delgado el mueble, que tiene que ser el eje de la espalda. Si alguien re-renderiza el
## arte girado, la comprobación salta (test `anclaje_arrimado_test`).
const CICLO_ESPALDA: Array[Vector2i] = [
	Vector2i(0, -1),   # norte
	Vector2i(-1, 0),   # oeste
	Vector2i(0, 1),    # sur
	Vector2i(1, 0),    # este
]

## Centro de la base ya medido, por `resource_path` de la textura. Las texturas sin ruta en disco
## (generadas en memoria) no se cachean: no tienen clave estable.
static var _cache_centro: Dictionary[String, Vector2] = {}

## Semiejes de la base ya medidos, por `resource_path`. Caché APARTE de la del centro a propósito
## (2026-08-04): el arrimado a pared se añadió sin tocar una línea del camino del centro, que estaba
## en uso y verificado. Se paga una segunda pasada de píxeles por textura, y solo por las texturas
## de los muebles DE PARED — que son los únicos que preguntan por los semiejes.
static var _cache_semiejes: Dictionary[String, Vector2] = {}

## Caché de `centros_de_asiento`, con clave "<ruta>#<plazas>": la medida depende de cuántas plazas
## se pidan, así que la textura sola no basta como clave.
static var _cache_asientos: Dictionary[String, PackedVector2Array] = {}
## Celdas de huella por textura (ver `celdas_de_huella`) — medir la silueta descomprime la imagen,
## así que se cachea igual que el centro y los semiejes.
static var _cache_celdas: Dictionary[String, int] = {}


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


## Los SEMIEJES de la base: la MITAD de lo que mide, en cada eje, el rectángulo de suelo que pisa el
## mueble — `x` a lo largo del eje X del plano cuadrado (este/oeste) e `y` a lo largo del eje Y
## (norte/sur), en píxeles de ESE plano (no del PNG). Un mueble que llenara una celda entera daría
## `(20, 20)` con `TAM_CELDA` = 40.
##
## Para qué existe: los muebles DE PARED (estanterías) no se centran en su celda, se arriman al
## borde trasero — y cuánto hay que empujarlos depende de su FONDO, que es esto. Ver
## `desvio_arrimado`. Cacheado.
static func semiejes_base(textura: Texture2D) -> Vector2:
	if textura == null:
		push_error("AnclajeSprite: textura nula")
		return Vector2.ZERO
	var clave: String = textura.resource_path
	if clave != "" and _cache_semiejes.has(clave):
		return _cache_semiejes[clave]
	var semiejes: Vector2 = _medir_semiejes_base(textura)
	if clave != "":
		_cache_semiejes[clave] = semiejes
	return semiejes


## ── ALINEACIÓN A LA CUADRÍCULA (2026-08-09, encargo del usuario) ────────────────────────────────
## *"Las casas tienen que colocarse en los bordes de las celdas, ahora empiezan en mitad de una
## celda"* / *"los muros y puertas no se ajustan a las cuadrículas"* / *"si algo ocupa 1,94, amplíalo
## a 2"*.
##
## LA CAUSA: colocar un sprite pone el CENTRO de su base en el CENTRO de la celda señalada. Para una
## pieza de 1 celda es lo correcto (una farola se centra en su celda, y así debe seguir). Pero una
## casa mide 6 celdas y un coche 2: con un número PAR de celdas, el centro de la pieza cae por
## geometría en el BORDE entre dos celdas, no en el centro de ninguna — clavarlo en el centro de una
## celda la descuadra media celda y sus bordes caen partiendo celdas por la mitad.
##
## LA REGLA: la huella se REDONDEA a celdas enteras (1,94 → 2 celdas; ese es el "amplíalo a 2") y,
## si el resultado es PAR, el ancla se corre media celda en ese eje para que los bordes de la pieza
## caigan sobre bordes de celda. Impar → sin desvío (sigue centrada, como la farola).
## Todo MEDIDO del PNG: ninguna pieza declara su huella a mano (misma ley que el resto del fichero).

## Cuántas CELDAS mide el ROMBO de la base en pantalla, redondeado al entero más cercano (mínimo 1).
##
## Se mide del ANCHO de la silueta (`min_x`..`max_x`), que es el dato más fiable del PNG: para una
## base de a×b celdas, ese ancho vale exactamente `(a+b)` rombos (ver la cabecera). NO se usan aquí
## los `semiejes_base`: separar a de b exige suponer una caja perfecta y en piezas grandes con
## tejado (las casas) el reparto se despista — para la ALINEACIÓN solo hace falta la paridad de la
## suma, que el ancho da directamente y sin suposiciones.
static func celdas_de_huella(textura: Texture2D) -> int:
	if textura == null:
		return 1
	var clave: String = textura.resource_path
	if clave != "" and _cache_celdas.has(clave):
		return _cache_celdas[clave]
	var ancho_px: float = _medir_ancho_silueta(textura)
	var celdas: int = maxi(1, int(roundf(ancho_px / float(Proyeccion.ANCHO_ROMBO))))
	if clave != "":
		_cache_celdas[clave] = celdas
	return celdas


## El desplazamiento EN PANTALLA que alinea la pieza a la cuadrícula: media celda cuando su huella
## mide un número PAR de celdas (sus bordes caen entonces sobre bordes de celda), cero cuando es
## impar (la pieza sigue centrada en su celda, como la farola). Se SUMA al punto de pantalla de la
## celda señalada.
static func desvio_rejilla(textura: Texture2D) -> Vector2:
	if celdas_de_huella(textura) % 2 != 0:
		return Vector2.ZERO
	var medio: float = float(Proyeccion.TAM_CELDA) * 0.5
	return Proyeccion.proyectar(Vector2(medio, medio))


## El ancho en píxeles de la silueta opaca (misma medida que usa `_medir_centro_base`).
static func _medir_ancho_silueta(textura: Texture2D) -> float:
	var img: Image = textura.get_image()
	if img == null:
		return 0.0
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
		return 0.0
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if _columna_opaca(img, px, alto):
			max_x = px
			break
	return float(max_x - min_x + 1)


## Por qué EJE es DELGADO el mueble, medido de sus píxeles: `Vector2i(1,0)` si lo es en X (este/
## oeste), `Vector2i(0,1)` si lo es en Y (norte/sur). Un mueble de pared da la espalda por su lado
## delgado — es lo que lo hace "de pared" —, así que esto es el CONTRASTE con el que se comprueba
## que la espalda declarada de un mueble no se ha quedado desfasada tras un re-render.
static func eje_corto(textura: Texture2D) -> Vector2i:
	var semiejes: Vector2 = semiejes_base(textura)
	return Vector2i(1, 0) if semiejes.x <= semiejes.y else Vector2i(0, 1)


## La espalda de un mueble tras girarlo `rotacion` grados en el render, sabiendo hacia dónde daba la
## espalda a 0°. Es recorrer `CICLO_ESPALDA` — ver el comentario largo de esa constante.
static func espalda_girada(espalda_a_cero: Vector2i, rotacion: int) -> Vector2i:
	var desde: int = CICLO_ESPALDA.find(espalda_a_cero)
	if desde < 0:
		push_error("AnclajeSprite: '%s' no es una dirección de espalda" % espalda_a_cero)
		return Vector2i.ZERO
	return CICLO_ESPALDA[posmod(desde + int(roundf(rotacion / 90.0)), CICLO_ESPALDA.size())]


## La inversa: QUÉ rotación hay que pedirle al arte para que un mueble dé la espalda a la pared que
## se quiere. Es lo que traduce "esta estantería va contra la pared norte" a "carga el PNG de 270°",
## sin que nadie tenga que apuntarse a mano qué rotación es cuál en cada mueble.
static func rotacion_para_espalda(espalda_a_cero: Vector2i, deseada: Vector2i) -> int:
	var desde: int = CICLO_ESPALDA.find(espalda_a_cero)
	var hasta: int = CICLO_ESPALDA.find(deseada)
	if desde < 0 or hasta < 0:
		push_error("AnclajeSprite: espalda no válida (%s -> %s)" % [espalda_a_cero, deseada])
		return 0
	return posmod(hasta - desde, CICLO_ESPALDA.size()) * 90


## El DESPLAZAMIENTO en pantalla que ARRIMA un mueble de pared al borde trasero de su celda, a
## sumar a la posición del sprite DESPUÉS de anclarlo con `aplicar()`. `espalda` es hacia dónde da
## la espalda ESTE PNG (`espalda_girada`).
##
## ── LA CUENTA (usuario 2026-08-04: *"que no quede hueco entre la pared y la estantería"*) ──────
## `aplicar()` deja el centro de la base en el centro de la celda, así que entre el borde trasero
## del mueble y la línea de la pared queda un hueco de:
##
##     recorrido = TAM_CELDA/2 − semieje_del_fondo
##                 └ del centro de la celda a su borde   └ del centro del mueble a su espalda
##
## y arrimarlo es, exactamente, recorrer ese hueco en la dirección de la espalda. El semieje que se
## usa es el del EJE por el que se arrima: el de Y si la espalda mira al norte o al sur, el de X si
## mira al este o al oeste. Todo en el plano lógico cuadrado; el resultado se proyecta al final, una
## sola vez.
##
## Ni un número mágico: `TAM_CELDA` es del modelo y el semieje sale de los píxeles del propio PNG,
## así que si el arte cambia de fondo el arrimado se recalcula solo.
##
## `recorrido` se recorta a 0 por abajo: un mueble MÁS HONDO que su celda ya se sale por los dos
## lados y empujarlo solo lo sacaría más. Espalda inválida → 0 con aviso (no se arrima nada).
static func desvio_arrimado(textura: Texture2D, espalda: Vector2i) -> Vector2:
	if CICLO_ESPALDA.find(espalda) < 0:
		push_error("AnclajeSprite: '%s' no es una dirección de espalda" % espalda)
		return Vector2.ZERO
	var semiejes: Vector2 = semiejes_base(textura)
	var semieje_fondo: float = semiejes.y if espalda.x == 0 else semiejes.x
	var recorrido: float = maxf(Proyeccion.TAM_CELDA * 0.5 - semieje_fondo, 0.0)
	return Proyeccion.proyectar(Vector2(espalda) * recorrido)


## El DESPLAZAMIENTO que arrima una pieza DE ESQUINA (toca DOS paredes a la vez — la estantería en L,
## `Construccion._sprites_comodidad`, clave `espalda_extra_0`) al VÉRTICE que comparten esas dos
## paredes — no al punto medio de una arista (eso es `desvio_arrimado`, para una sola pared).
##
## POR QUÉ NO REUTILIZA `semiejes_base` (medido 2026-08-04, pieza `estanteria_esquina`): esa medida
## asume una base RECTANGULAR CONVEXA (ver su cabecera: "recorrer el CONTORNO INFERIOR... y ninguna
## otra parte de la silueta puede pasarse de esas dos rectas hacia abajo"). Una pieza en L es
## CÓNCAVA — el hueco de la esquina MUERDE la silueta —, así que esa premisa no se cumple: medido
## contra el PNG real, 0° y 180° (el MISMO objeto, solo girado 180°, tendría que dar el mismo
## semieje) dan 1,538 y 0,963 celdas respectivamente — prueba de que la medida no vale para esta
## pieza, no un matiz. Así que el arrimado de esquina NO resta ningún fondo propio: empuja el CENTRO
## de la base el MEDIO CELDA COMPLETO en las DOS direcciones a la vez, directo al vértice — que es
## justo donde cae el propio rincón de la L (la pieza está construida alrededor de ese vértice, no
## de un rectángulo con fondo). No depende de la textura (a propósito: no hay silueta que medir
## aquí, solo la geometría de la celda), por eso no la recibe como parámetro.
static func desvio_arrimado_esquina(espalda_a: Vector2i, espalda_b: Vector2i) -> Vector2:
	if CICLO_ESPALDA.find(espalda_a) < 0 or CICLO_ESPALDA.find(espalda_b) < 0:
		push_error("AnclajeSprite: esquina con espalda no válida (%s, %s)" % [espalda_a, espalda_b])
		return Vector2.ZERO
	return Proyeccion.proyectar((Vector2(espalda_a) + Vector2(espalda_b)) * (Proyeccion.TAM_CELDA * 0.5))


## Dónde están DE VERDAD los asientos de un mueble, medidos sobre su propio PNG. Devuelve un punto
## por plaza, en píxeles del PNG (mismo sistema que `centro_base`).
##
## Por qué se mide y no se calcula (2026-08-10, el usuario: "no encaja perfecto la persona que se
## sienta con el lugar exacto del asiento"): repartir las plazas uniformemente a lo largo del eje da
## puntos plausibles pero no los del dibujo — los cojines de un banco no están equiespaciados en
## pantalla, porque la perspectiva isométrica acerca unos y aleja otros, y además los reposabrazos
## comen ancho. Aquí cada plaza se busca en SU franja de columnas:
##   · la X es el centro de la franja ocupada;
##   · la Y es la fila MÁS ANCHA de la mitad inferior de esa franja, que es la banda del cojín (el
##     respaldo queda por encima y es más estrecho, las patas por debajo y más estrechas todavía).
## Cacheado por textura+plazas: es un escaneo de píxeles, jamás en `_process`.
static func centros_de_asiento(textura: Texture2D, plazas: int) -> PackedVector2Array:
	if textura == null or plazas <= 0:
		return PackedVector2Array()
	var clave: String = "%s#%d" % [textura.resource_path, plazas]
	if textura.resource_path != "" and _cache_asientos.has(clave):
		return _cache_asientos[clave]
	var img: Image = textura.get_image()
	if img == null:
		push_error("AnclajeSprite: textura '%s' sin imagen legible" % textura.resource_path)
		return PackedVector2Array()
	if img.is_compressed():
		img.decompress()
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	var min_x: int = -1
	var max_x: int = -1
	for px: int in range(ancho):
		if _columna_opaca(img, px, alto):
			if min_x < 0:
				min_x = px
			max_x = px
	if min_x < 0:
		return PackedVector2Array()
	var salida := PackedVector2Array()
	var util: float = float(max_x + 1 - min_x)
	for i: int in plazas:
		var x0: int = min_x + int(floor(util * float(i) / float(plazas)))
		var x1: int = min_x + int(ceil(util * float(i + 1) / float(plazas)))
		salida.append(_asiento_en_franja(img, x0, maxi(x1, x0 + 1), alto))
	if textura.resource_path != "":
		_cache_asientos[clave] = salida
	return salida


static func _asiento_en_franja(img: Image, x0: int, x1: int, alto: int) -> Vector2:
	var arriba: int = -1
	var abajo: int = -1
	var izq: int = -1
	var der: int = -1
	for px: int in range(x0, x1):
		for py: int in range(alto):
			if img.get_pixel(px, py).a > UMBRAL_ALFA:
				if arriba < 0 or py < arriba:
					arriba = py
				if py > abajo:
					abajo = py
				if izq < 0:
					izq = px
				der = px
				break
	if arriba < 0:
		return Vector2((x0 + x1) * 0.5, float(alto))
	# El cojín: la fila más ancha de la MITAD INFERIOR del trozo de mueble que hay en esta franja.
	var medio: int = arriba + (abajo - arriba) / 2
	var mejor_ancho: int = -1
	var mejor_y: float = float(abajo)
	for py: int in range(medio, abajo + 1):
		var primero: int = -1
		var ultimo: int = -1
		for px: int in range(x0, x1):
			if img.get_pixel(px, py).a > UMBRAL_ALFA:
				if primero < 0:
					primero = px
				ultimo = px
		if primero < 0:
			continue
		var w: int = ultimo - primero
		if w > mejor_ancho:
			mejor_ancho = w
			mejor_y = float(py)
	return Vector2((float(izq) + float(der) + 1.0) * 0.5, mejor_y)


## Vacía las cachés de medidas. Solo para tests y herramientas que recargan texturas en caliente.
static func limpiar_cache() -> void:
	_cache_asientos.clear()
	_cache_centro.clear()
	_cache_semiejes.clear()


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


## El barrido de los SEMIEJES: recorre el CONTORNO INFERIOR de la silueta (por columna, el píxel
## opaco más bajo) quedándose con el máximo de las dos invariantes de recta — `y − x/2` para el
## borde SUR de la base, `y + x/2` para el borde ESTE (ver la cabecera). Con esas dos rectas y el
## centro ya medido salen los dos semiejes. Textura vacía → `Vector2.ZERO` (no se arrima nada).
static func _medir_semiejes_base(textura: Texture2D) -> Vector2:
	var img: Image = textura.get_image()
	if img == null:
		push_error("AnclajeSprite: textura '%s' sin imagen legible" % textura.resource_path)
		return Vector2.ZERO
	if img.is_compressed():
		img.decompress()
	var ancho: int = img.get_width()
	var alto: int = img.get_height()
	# La razón 1/2 ES la proyección 2:1, escrita con las constantes para que siga cuadrando si
	# cambiaran.
	var pendiente: float = Proyeccion.MEDIO_ALTO / Proyeccion.MEDIO_ANCHO
	var borde_sur: float = -INF
	var borde_este: float = -INF
	for px: int in range(ancho):
		var fondo: int = -1
		for py: int in range(alto - 1, -1, -1):
			if img.get_pixel(px, py).a > UMBRAL_ALFA:
				fondo = py
				break
		if fondo < 0:
			continue
		# El punto de muestra: centro horizontal del píxel, borde INFERIOR de su fila (el píxel `n`
		# cubre el intervalo continuo `[n, n+1)`) — misma convención que la Y del vértice sur.
		var x_muestra: float = float(px) + 0.5
		var y_muestra: float = float(fondo) + 1.0
		borde_sur = maxf(borde_sur, y_muestra - x_muestra * pendiente)
		borde_este = maxf(borde_este, y_muestra + x_muestra * pendiente)
	if borde_sur == -INF:
		push_warning("AnclajeSprite: textura '%s' totalmente transparente" % textura.resource_path)
		return Vector2.ZERO
	var centro: Vector2 = centro_base(textura)
	# De la invariante a celdas: `y − x/2 = ALTO_ROMBO · v` y `y + x/2 = ALTO_ROMBO · u` (sale de
	# sustituir la proyección). La diferencia entre la del borde y la del centro es el semieje en
	# celdas; por `TAM_CELDA`, en píxeles del plano cuadrado.
	var por_celda: float = Proyeccion.TAM_CELDA / float(Proyeccion.ALTO_ROMBO)
	return Vector2(
		(borde_este - (centro.y + centro.x * pendiente)) * por_celda,
		(borde_sur - (centro.y - centro.x * pendiente)) * por_celda
	)
