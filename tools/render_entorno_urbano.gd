extends "res://tools/render_mobiliario.gd"
## RenderEntornoUrbano — sprites de PROPS de `EntornoExterior` (2026-08-07, feedback de playtest:
## "no hay vida, el recinto es inexistente" -- reforma 3 "VIDA").
##
## Mismo pipeline que `render_props_poly.gd`/`_render_kaykit_poly.gd` (cámara/luces/recorte
## heredados de `render_mobiliario.gd`): calibración por ALTURA REAL declarada, nunca por la AABB
## cruda del `.glb`. Aplica el FACTOR DE PRESENCIA de `_render_kaykit_poly.gd`
## (`design/art/plan-escalado.md` §1) -- `objetivo_px = altura_m × PX_POR_METRO × 1,25` -- misma
## regla que ya usan las piezas que compiten visualmente con los muñecos cabezones del juego. Esta
## es la fórmula que fija el informe del encargo: "escala px = m × 25,88 × 1,25".
##
## Fuentes:
##  · `capturas/fuentes/biblioteca_summer/` (árbol, seto, farola -- biblioteca pública Summer,
##    gratis, ya importados).
##  · `capturas/fuentes/kenney_carkit/extracted/Models/GLB format/` (coche patrulla + 2 turismos de
##    visita -- CC0, ya importados; PROHIBIDOS tractores/camiones del mismo kit).
##
## Salida: `assets/sprites/entorno/<id>_<rot>.png`, 4 rotaciones por pieza (yaw 0/90/180/270°) --
## árbol/seto/farola usarán solo la 0° en el juego (piezas sin frente marcado), los coches usan las
## 4 para orientarse en su plaza/calle.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
## `const …Script` en vez del registro global de `class_name` -- convenio del proyecto (ver
## `paredes_salas.gd`, cabecera de `ParedesSalasScript` en `npcs_flujo.gd`).
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")

## Mismo ancla de conversión que el resto de pipelines 3D->sprite del proyecto: muñeco `girl` 44px
## ~ 1,70m real.
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
## Factor de presencia (`_render_kaykit_poly.gd`, `design/art/plan-escalado.md` §1): +25% sobre la
## escala métrica real -- la fórmula del encargo, "escala px = m × 25,88 × 1,25".
const FACTOR_PRESENCIA: float = 1.25

const SALIDA_ENTORNO := "res://assets/sprites/entorno/"

const CARPETA_SUMMER := "res://capturas/fuentes/biblioteca_summer/"
const CARPETA_CARKIT := "res://capturas/fuentes/kenney_carkit/extracted/Models/GLB format/"
## Casas completas del pack "City Kit Suburban" (Kenney, CC0) -- 2026-08-07, mejora del material:
## los edificios vecinos sueltos usan casas YA HECHAS en vez de cajas con tejado por código.
const CARPETA_SUBURBAN := "res://capturas/fuentes/kenney_suburban/Models/GLB format/"
## Kit de carreteras (Kenney, CC0) -- 2026-08-07, doctrina "todo es asset, nada por código": la
## calzada/acera de la calle de acceso usan piezas de este kit en vez de rectángulos pintados.
const CARPETA_ROADS := "res://capturas/fuentes/kenney_roads/Models/GLB format/"
## Building Kit (Kenney, CC0) -- 2026-08-08, encargo de playtest 3/3: "muros, ventanas, puertas y
## demás para montar p.ej. la garita" -- primer lote a la paleta del diseñador (prefijo `bk_`, ver
## `PIEZAS_BUILDING_KIT` más abajo). 79 GLB en el kit completo; este lote es un SET INICIAL de 10
## piezas (muro recto, muro esquina, ventana, puerta, columna, escaleras, suelo + 3 detalles).
const CARPETA_BUILDING := "res://capturas/fuentes/kenney_building_kit/Models/GLB format/"

## Cada pieza: `id` (nombre de salida), `ruta` del `.glb` de origen, y UNA de las dos calibraciones:
##  · `altura_objetivo_m` -- para piezas con volumen vertical real (casas, coches, farola, seto,
##    árboles, valla): escala por ALTURA REAL × factor de presencia, midiendo el ALTO de la
##    silueta en bruto (ver la cabecera del fichero).
##  · `ancho_objetivo_celdas` -- para piezas CASI PLANAS (camino, calzada, acera, entrada de casa):
##    calibrar por altura sería frágil (una losa de unos pocos cm de grosor da una silueta minúscula
##    y ruidosa) -- en su lugar se mide el ANCHO de la silueta en bruto y se fuerza a que ocupe
##    exactamente `ancho_objetivo_celdas × Proyeccion.ANCHO_ROMBO` px, que es la huella real de la
##    pieza en la rejilla isométrica del juego (80 px = 1 celda de ancho de rombo).
##  · `longitud_objetivo_m` -- SOLO para los coches (2026-08-07, encargo "los coches ocupan MÍNIMO 3
##    celdas; la mesa ocupa 2 y un coche es más grande"). Calibrar un coche por ALTURA (como el resto
##    de piezas con volumen) da un resultado demasiado pequeño: el kit Kenney low-poly es "achaparrado"
##    a propósito (estilo cartoon) y su alto real NO guarda la proporción alto:largo de un coche real.
##    Igual que `ancho_objetivo_celdas`, este modo mide el ANCHO de la silueta en bruto a 0°, pero el
##    objetivo sale de METROS × la misma conversión px/metro × factor de presencia que `altura_objetivo_m`.
##    ⚠️ ESTE NÚMERO **NO ES el largo real del coche en metros** -- con la cámara isométrica a yaw 45°
##    el "ancho en bruto" de un coche mide una combinación de su largo y su ancho, Y ADEMÁS
##    `AnclajeSprite.semiejes_base` (la medida que de verdad importa: es la que usa el JUEGO para
##    anclar cada prop) mide el CONTORNO INFERIOR de la silueta, que en un coche con guardabarros/
##    parachoques queda por debajo de la huella "de caja" que asume esa función -- las dos cosas
##    juntas hacen que la huella medida en celdas no coincida con la aritmética ingenua de arriba.
##    ⚠️ GOTCHA DE ESTA MISMA TAREA: `load()` desde `--headless --script` (fuera del editor) devuelve
##    el PNG CACHEADO en `.godot/imported/` si ya existía uno -- un re-render que SOBRESCRIBE el
##    archivo en disco NO invalida ese caché por sí solo. Los dos primeros intentos de esta tarea
##    midieron sin querer la MISMA imagen vieja cacheada (ninguno de los cambios de arriba se estaba
##    viendo) y llevaron el número a un exceso absurdo (13,8-19,1 m -> 9-11 celdas reales). El PASO
##    OBLIGATORIO antes de medir: `godot --headless --path <proyecto> --import` (reimporta todo y
##    sale) SIEMPRE después de un re-render, antes de volver a medir con
##    `tools/_diag_medir_coches.gd`. Con el caché ya limpio, estos tres valores (una REGLA DE TRES
##    empírica sobre la medida real, mismo método que `MULTIPLICADOR_MOSTRADOR1`/`MULTIPLICADOR_SOFA3`
##    de `render_mobiliario.gd`) dan una huella de ~3,2-3,6 celdas de largo -- verificado en el motor
##    (intento 3 de 3, con el `--import` de por medio).
##
## Las 5 casas (ids fijos casa_a/d/g/k/o -- el catálogo, la paleta del diseñador, `ANCHO_CASA_BARRIO`
## de `entorno_exterior.gd` y los layouts guardados dependen de estos 5 ids y de sus anchos de
## parcela EXACTOS: 6/6/7/7/8 -- NUNCA cambiar) -- 2026-08-08, RECALIBRADO por ANCHO DE PARCELA (ley
## 12, feedback "las casas son muy pequeñas comparadas con coches/personas/comisaría" -- calibrar por
## ALTURA daba casas de 1-2 plantas que seguían leyéndose como maquetas junto a un coche de 3+
## celdas). Usan `ancho_objetivo_celdas` (el mismo modo que ya usaban camino/calzada/acera, ver la
## cabecera de `MODELOS`): la silueta se fuerza a ocupar exactamente N celdas de ancho de rombo en
## pantalla -- pequeña 6, mediana 7, grande 8.
##
## ⚠️ REHECHO 2026-08-08 (2ª vez, mismo día) -- LEY DEL PROYECTO "PROHIBIDA la escala NO uniforme en
## sprites" (`technical-preferences.md`): el primer intento de este mismo día añadió un TECHO de
## altura en metros que recortaba la escala Y por debajo de la X para que ninguna casa se "disparara"
## -- deformaba la silueta (casa_k llegó a aplanarse ~3,8×, casa_a/d/g/o algo menos pero todas
## estiradas). Se ELIMINA ese mecanismo por completo (`altura_techo_m`/`_escalar_xy`/`escala_pieza_y`
## ya no existen en este fichero): las 5 casas usan ahora la MISMA escala uniforme (X=Y) que el resto
## del catálogo -- la altura que salga de la proporción NATURAL de cada modelo, sin recortar nada.
## Cuando un modelo del kit da una altura desproporcionada con escala uniforme (torre en vez de casa
## baja), la corrección es SUSTITUIR el modelo por otra letra del abecedario (a..u) del mismo kit --
## nunca deformar. Reparto final (medido con el modo `SOLO_MEDICION` de este fichero, ver más abajo,
## contra la banda ~130-230px = ~2-3,5×`ParedesSalas.ALTO_PARED` que pide la tarea):
## banda que pedía el encargo original resultó INALCANZABLE con escala uniforme -- el ANCHO ya está
## fijo en 6-8 celdas (480-640px, la MISMA unidad que calibra coches/camino), y NINGUNA de las 21
## letras baja de ratio(alto/ancho)=0,67 -- el mínimo posible con ese ancho da ~320px de alto, ya
## 4,9x `ParedesSalas.ALTO_PARED` (que además es una pared "bajita" a propósito, ver su cabecera, no
## una referencia de altura real). Criterio aplicado en su lugar: las 5 letras de MENOR ratio del kit
## entero (las más "casa baja", menos "torre") -- confirmado a ojo con
## `tools/_diag_escala_casas_20260808.gd` (ver el informe):
##   casa_a (6 celdas) -> letra a (ratio 0,7475 -- sin cambio, ya era de las más bajas)
##   casa_d (6 celdas) -> letra m (ratio 0,6697 -- sustituye a 'd'=0,8656, la más baja de las 21)
##   casa_g (7 celdas) -> letra g (ratio 0,7175 -- sin cambio, 2ª más baja de las 21)
##   casa_k (7 celdas) -> letra i (ratio 0,7318 -- sustituye a 'k'=1,2394, la peor "torre" del kit)
##   casa_o (8 celdas) -> letra n (ratio 0,7526 -- sustituye a 'o'=0,9620)
##
## `valla_baja`/`valla_estandar`: las DOS candidatas para la tapia del recinto (`fence-low.glb` vs
## `fence.glb`) -- se renderizan las dos y se decide cuál se usa mirando el PNG (ver el informe),
## sin gastar una segunda pasada de render si hay que cambiar de opinión.
##
## `TEST_metro_corner`: pieza de EVALUACIÓN (candidato del usuario, `metro_street_corner.glb`,
## realista PBR) -- se renderiza para comparar su estilo contra el low-poly Kenney con evidencia,
## NO para usarla necesariamente en el juego (ver el informe, veredicto).
##
## ── LAS 16 CASAS RESTANTES DEL KIT (2026-08-08, encargo "hay como 20 casas... se puede poner un
## submenú: casas y que salgan las 20") ─────────────────────────────────────────────────────────
## Ids NUEVOS letter-true (prefijo `casa_kit_` para no chocar con los 5 ids viejos casa_a/d/g/k/o,
## que NUNCA se tocan -- ver la nota de arriba): las 16 letras del kit que las 5 casas originales
## no usan (a/g/i/m/n ya están servidas). Mismo modo `ancho_objetivo_celdas` (escala UNIFORME, ley
## del proyecto) que el resto del catálogo -- `ancho = clampi(roundi(360.0 / (80.0 × ratio)), 4, 8)`
## sobre el `ratio(alto/ancho)` medido con `SOLO_MEDICION` (ver esa nota, log de esta tarea):
##   id            | letra | ratio  | ancho (celdas) | alto final previsto
##   casa_kit_b    |   b   | 0.7546 |       6         | 362.2px
##   casa_kit_c    |   c   | 0.8764 |       5         | 350.6px
##   casa_kit_d    |   d   | 0.8656 |       5         | 346.2px
##   casa_kit_e    |   e   | 1.0040 |       4         | 321.3px
##   casa_kit_f    |   f   | 0.8412 |       5         | 336.5px
##   casa_kit_h    |   h   | 0.8025 |       6         | 385.2px
##   casa_kit_j    |   j   | 0.8281 |       5         | 331.2px
##   casa_kit_k    |   k   | 1.2394 |       4         | 396.6px
##   casa_kit_l    |   l   | 0.9916 |       5         | 396.6px
##   casa_kit_o    |   o   | 0.9620 |       5         | 384.8px
##   casa_kit_p    |   p   | 1.0075 |       4         | 322.4px
##   casa_kit_q    |   q   | 0.8233 |       5         | 329.3px
##   casa_kit_r    |   r   | 1.1462 |       4         | 366.8px
##   casa_kit_s    |   s   | 1.0228 |       4         | 327.3px
##   casa_kit_t    |   t   | 0.9074 |       5         | 362.9px
##   casa_kit_u    |   u   | 0.9020 |       5         | 360.8px
## Todas caen dentro (o muy cerca) de la banda ~320-400px que ya daban las 5 originales -- ninguna
## sale "torre" con este reparto de anchos (a diferencia de lo que habría pasado con un ancho fijo
## de 6-8 para las 21, ver la nota de arriba sobre `casa_k`→letra `i`).
## ⚠️ MODO TEMPORAL DE SOLO MEDICIÓN (2026-08-08, paso 3 de la receta de rehacer las 5 casas por
## escala uniforme): con `SOLO_MEDICION = true`, `_ready()` NO monta ni renderiza el catálogo --
## en su lugar mide la proporción bruta (alto/ancho de la silueta a 0°) de TODAS las letras
## `building-type-*` del kit suburbano (ver `LETRAS_SUBURBAN`) y para cada una imprime la altura
## final prevista con parcela de 6/7/8 celdas (misma fórmula que usa `_ejecutar` para
## `ancho_objetivo_celdas`: `alto_final = ancho_celdas × Proyeccion.ANCHO_ROMBO × (alto_bruto /
## ancho_bruto)`). NO escribe ningún PNG. Volver a `false` cuando se decida el reparto final --
## no forma parte del pipeline normal, es una sonda de calibración de un solo uso.
const SOLO_MEDICION: bool = false

## Las 21 letras del kit "City Kit Suburban" (a..u) -- candidatas para las 5 casas cuando
## `SOLO_MEDICION` está activo (ver `capturas/fuentes/kenney_suburban/Models/GLB format/`).
const LETRAS_SUBURBAN: Array[String] = [
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
	"l", "m", "n", "o", "p", "q", "r", "s", "t", "u",
]

## Los 3 anchos de parcela reales del catálogo (`MODELOS`, ids casa_a/d=6, casa_g/k=7, casa_o=8) --
## la tabla de `SOLO_MEDICION` prueba los tres para cada letra candidata.
const ANCHOS_PARCELA_A_PROBAR: Array[float] = [6.0, 7.0, 8.0]

const MODELOS: Array[Dictionary] = [
	{"id": "arbol_urbano", "ruta": CARPETA_SUMMER + "arbol_urbano.glb", "altura_objetivo_m": 4.5},
	{"id": "seto", "ruta": CARPETA_SUMMER + "seto.glb", "altura_objetivo_m": 0.8},
	{"id": "farola", "ruta": CARPETA_SUMMER + "farola.glb", "altura_objetivo_m": 4.0},
	{"id": "coche_policia", "ruta": CARPETA_CARKIT + "police.glb", "longitud_objetivo_m": 4.8},
	{"id": "coche_sedan", "ruta": CARPETA_CARKIT + "sedan.glb", "longitud_objetivo_m": 5.3},
	{"id": "coche_suv", "ruta": CARPETA_CARKIT + "suv.glb", "longitud_objetivo_m": 5.6},
	{"id": "casa_a", "ruta": CARPETA_SUBURBAN + "building-type-a.glb", "ancho_objetivo_celdas": 6.0},
	{"id": "casa_d", "ruta": CARPETA_SUBURBAN + "building-type-m.glb", "ancho_objetivo_celdas": 6.0},
	{"id": "casa_g", "ruta": CARPETA_SUBURBAN + "building-type-g.glb", "ancho_objetivo_celdas": 7.0},
	{"id": "casa_k", "ruta": CARPETA_SUBURBAN + "building-type-i.glb", "ancho_objetivo_celdas": 7.0},
	{"id": "casa_o", "ruta": CARPETA_SUBURBAN + "building-type-n.glb", "ancho_objetivo_celdas": 8.0},
	{"id": "valla_baja", "ruta": CARPETA_SUBURBAN + "fence-low.glb", "altura_objetivo_m": 1.2},
	{"id": "valla_estandar", "ruta": CARPETA_SUBURBAN + "fence.glb", "altura_objetivo_m": 1.5},
	{"id": "camino_recinto", "ruta": CARPETA_SUBURBAN + "path-short.glb", "ancho_objetivo_celdas": 1.0},
	{"id": "entrada_casa", "ruta": CARPETA_SUBURBAN + "driveway-short.glb", "ancho_objetivo_celdas": 1.0},
	{"id": "planter", "ruta": CARPETA_SUBURBAN + "planter.glb", "altura_objetivo_m": 0.6},
	{"id": "tree_grande", "ruta": CARPETA_SUBURBAN + "tree-large.glb", "altura_objetivo_m": 5.0},
	{"id": "tree_pequeno", "ruta": CARPETA_SUBURBAN + "tree-small.glb", "altura_objetivo_m": 3.0},
	{"id": "calzada_recta", "ruta": CARPETA_ROADS + "road-straight.glb", "ancho_objetivo_celdas": 2.0},
	{"id": "acera_recta", "ruta": CARPETA_ROADS + "road-side.glb", "ancho_objetivo_celdas": 1.0},
	{
		"id": "TEST_metro_corner", "ruta": CARPETA_SUMMER + "metro_street_corner.glb",
		"altura_objetivo_m": 9.0,
	},
	## Carreteras Kenney Roads (2026-08-08, encargo del usuario) -- LEY DE ESCALA: "1 coche de
	## nuestra escala por carril" -- medido con `AnclajeSprite.semiejes_base` (el MISMO mecanismo con
	## el que el juego ancla props, no PIL sobre el PNG en bruto: la cámara isométrica mezcla largo y
	## ancho en cualquier bbox de píxeles, ver la nota `por_longitud` más arriba) sobre
	## `coche_sedan_90.png`: semiejes=(63.75, 37.75)px -> footprint 3.19 x 1.89 celdas -- el eje corto
	## (1,89 celdas) ES el ancho transversal (el otro eje, 3,19, es el largo ya calibrado y documentado
	## arriba). 2 carriles = 2 x 1,89 = 3,78 celdas -> `ancho_objetivo_celdas = 3.8`. Todas estas
	## piezas son CASI PLANAS (calzada Kenney con la línea central pintada en la textura, no en el
	## volumen) -- mismo modo `ancho_objetivo_celdas` que `calzada_recta`/`acera_recta`, ver la
	## cabecera de `MODELOS`. Solo cablear a la paleta cuando otro lote lo pida (este render SOLO deja
	## los PNG listos + el registro de textura en `entorno_exterior.gd`, ver su cabecera).
	## ANCHO 6.0 (decisión del usuario 2026-08-08, tras ver las opciones 4,4/4,8/5,2 con los coches
	## encima: "ponlo en 6 celdas, así cuadra todo a celdas completas"): a 3,8 los coches pisaban el
	## arcén (~20% del tile es arcén); a 6,0 la calle casa con la rejilla entera y las 5 piezas del
	## kit comparten LA MISMA escala (regla del usuario: toda la familia en proporción).
	##
	## ⚠️ BUG DE PLAYTEST 1/3 (usuario, 2026-08-08, mismo día): "la curva sobresale ~1 celda por
	## lado respecto a la recta" -- CAUSA verificada en el log: `carretera_recta` mide 446px de
	## silueta EN BRUTO y `carretera_curva` 315px; al forzar cada pieza a los MISMOS 480px con su
	## PROPIO factor (`objetivo_px / medido_bruto_px`, el modo `ancho_objetivo_celdas` normal, ver la
	## cabecera de `MODELOS`), la curva salía con un factor 1,52 contra el 1,08 de la recta -- el
	## asfalto de la curva quedaba un 40% más "gordo" que el de la recta aunque las dos declaren
	## `ancho_objetivo_celdas=6.0`. FIX -- "factor_de": SOLO `carretera_recta` se autocalibra (mide su
	## propio bruto contra `ancho_objetivo_celdas`); las otras 4 declaran `"factor_de":
	## "carretera_recta"` y en `_ejecutar` HEREDAN ese mismo factor ya calculado (`escalas_familia`,
	## ver ahí) en vez de recalcular el suyo -- así las 5 comparten EXACTAMENTE el mismo px/unidad-de-
	## mundo, la regla del usuario ("todo el kit en la misma proporción") aplicada de verdad. Efecto
	## secundario ACEPTADO: solo `carretera_recta` llena los 480px (6,0 celdas) exactos; las otras 4
	## salen a lo que dé su propia silueta con ESE factor (curva más estrecha que 6 celdas de ancho
	## bruto) -- es la huella REAL de esa pieza a la escala común, no un objetivo propio.
	##
	## ⚠️ BUG DE PLAYTEST 2/3: "varios módulos de recta seguidos no se acoplan, se ven los bordes" --
	## INVESTIGADO con `tools/_diag_carretera_estructura.gd` (desechable, en el repo): las 5 mallas de
	## origen son la MISMA losa plana `AABB size=(1.0, 0.02, 1.0)` -- un grosor real de 0,02 m, nada
	## de textura. Ese grosor asoma como un "canto" (cara lateral) que sobresale unos pocos px MÁS
	## ALLÁ de la silueta IDEAL de la cara de arriba (que, siendo plana, tiene que proyectar un rombo
	## PERFECTO 2:1 -- la misma ley de `Proyeccion.ANCHO_ROMBO`/`ALTO_ROMBO` que ya valida el "cubo de
	## calibración" de `render_mobiliario.gd`) -- medido en `carretera_recta_0.png`: bbox 480×244px
	## contra el 480×240px ideal, 4px de sobra repartidos en las DOS puntas del EJE DE LA VÍA (no en
	## las puntas laterales/arcén, que miden exactas). Ese sobrante no es solo estética: el juego NO
	## usa el ancla que este render calcula en 3D -- `AnclajeSprite._medir_centro_base` (motor)
	## RECONSTRUYE el ancla puramente del PNG (min_x/max_x/max_y), asumiendo esa misma silueta 2:1
	## perfecta (ver su cabecera) -- con el canto, `max_y` cae unos px más abajo del vértice sur REAL
	## y el ancla reconstruido queda descuadrado esos mismos px -- exactamente la clase de error que,
	## acumulado tramo a tramo, se ve como "no se acopla". FIX: recortar (alfa=0) todo lo que quede
	## FUERA del rombo IDEAL 2:1 de cada sprite YA escalado -- `_recortar_a_rombo`, llamado desde
	## `_ejecutar` solo para `RECORTAR_CANTOS_VIA`.
	##
	## ⚠️ BUG DE PLAYTEST 3/3 (veredicto del usuario sobre `carreteras_v2.png`, tras 1/3+2/3 ya
	## corregidos): "la curva sigue mal: la línea tiene que continuar la línea siguiente, el arcén
	## tiene que seguir igual y la calzada lo mismo, tiene que ser una prolongación". CAUSA
	## (diagnóstico del coordinador, confirmado): el fix de 2/3 medía el centro del rombo de LAS DOS
	## COLUMNAS MÁS EXTREMAS DEL CONTENIDO de cada sprite -- válido para `carretera_recta` (su asfalto
	## llena casi toda la loseta 1×1) pero NO para `carretera_curva` (su malla es una cuña/arco que
	## solo cubre PARTE de la loseta, ver `capturas/fuentes/kenney_roads/Previews/road-bend.png`): el
	## centro de SU CONTENIDO no coincide con el centro de la LOSETA que comparte con las demás piezas
	## de la familia, así que al colocarla en rejilla (ancla = centro de la loseta, no del dibujo) su
	## asfalto quedaba desplazado -- línea/arcén/calzada no continuaban de un tramo al siguiente. FIX:
	## `region_familia` (ver `_ejecutar`) -- las 5 piezas recortan su frame RAW (antes de escalar) al
	## MISMO rectángulo, fijado por `carretera_recta` en rotación 0 (su recorte automático -- llena
	## casi toda la loseta -- YA es, de hecho, el recorte de la loseta 1×1 completa); el ancla de cada
	## rotación sale del PIPELINE (dónde proyecta el punto (0,0,0), SIEMPRE el mismo para las 5 --
	## mismo AABB, misma cámara), NUNCA remedida del contenido -- `_recortar_a_rombo` (bug 2/3) ahora
	## recibe ese ancla como centro, no la remide. Resultado: las 5 comparten exactamente el mismo
	## lienzo y el mismo punto de anclaje -- intercambiables celda a celda; el asfalto de la curva
	## queda en su posición REAL dentro de la loseta (no recentrado en su propio dibujo), así que casa
	## con la recta contigua. Las caras de los arcenes (blancas, DENTRO del rombo) no se tocan -- son
	## arte, se quedan.
	{"id": "carretera_recta", "ruta": CARPETA_ROADS + "road-straight.glb", "ancho_objetivo_celdas": 6.0},
	{
		"id": "carretera_curva", "ruta": CARPETA_ROADS + "road-bend.glb", "ancho_objetivo_celdas": 6.0,
		"factor_de": "carretera_recta",
	},
	{
		"id": "carretera_cruce", "ruta": CARPETA_ROADS + "road-crossroad-line.glb",
		"ancho_objetivo_celdas": 6.0, "factor_de": "carretera_recta",
	},
	{
		"id": "carretera_interseccion_t", "ruta": CARPETA_ROADS + "road-intersection-line.glb",
		"ancho_objetivo_celdas": 6.0, "factor_de": "carretera_recta",
	},
	{
		"id": "carretera_paso_cebra", "ruta": CARPETA_ROADS + "road-crossing.glb",
		"ancho_objetivo_celdas": 6.0, "factor_de": "carretera_recta",
	},
	## Las 16 casas restantes del kit (ver la tabla de la cabecera, "LAS 16 CASAS RESTANTES DEL KIT").
	{"id": "casa_kit_b", "ruta": CARPETA_SUBURBAN + "building-type-b.glb", "ancho_objetivo_celdas": 6.0},
	{"id": "casa_kit_c", "ruta": CARPETA_SUBURBAN + "building-type-c.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_d", "ruta": CARPETA_SUBURBAN + "building-type-d.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_e", "ruta": CARPETA_SUBURBAN + "building-type-e.glb", "ancho_objetivo_celdas": 4.0},
	{"id": "casa_kit_f", "ruta": CARPETA_SUBURBAN + "building-type-f.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_h", "ruta": CARPETA_SUBURBAN + "building-type-h.glb", "ancho_objetivo_celdas": 6.0},
	{"id": "casa_kit_j", "ruta": CARPETA_SUBURBAN + "building-type-j.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_k", "ruta": CARPETA_SUBURBAN + "building-type-k.glb", "ancho_objetivo_celdas": 4.0},
	{"id": "casa_kit_l", "ruta": CARPETA_SUBURBAN + "building-type-l.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_o", "ruta": CARPETA_SUBURBAN + "building-type-o.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_p", "ruta": CARPETA_SUBURBAN + "building-type-p.glb", "ancho_objetivo_celdas": 4.0},
	{"id": "casa_kit_q", "ruta": CARPETA_SUBURBAN + "building-type-q.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_r", "ruta": CARPETA_SUBURBAN + "building-type-r.glb", "ancho_objetivo_celdas": 4.0},
	{"id": "casa_kit_s", "ruta": CARPETA_SUBURBAN + "building-type-s.glb", "ancho_objetivo_celdas": 4.0},
	{"id": "casa_kit_t", "ruta": CARPETA_SUBURBAN + "building-type-t.glb", "ancho_objetivo_celdas": 5.0},
	{"id": "casa_kit_u", "ruta": CARPETA_SUBURBAN + "building-type-u.glb", "ancho_objetivo_celdas": 5.0},

	## ── BUILDING KIT (Kenney, CC0) -- 2026-08-08, encargo de playtest 3/3 ─────────────────────────
	## SET INICIAL de 10 piezas (de las 79 del kit) para montar estructuras modulares en la paleta
	## del diseñador (muros/ventanas/puertas/etc. -- p.ej. la garita del control de acceso).
	## `altura_objetivo_m` = 2,8m para TODA la familia "de muro" (muro/esquina/ventana/puerta/
	## columna/escaleras) -- MISMO modo que ya usan `valla_baja`/`valla_estandar` (independiente,
	## sin `factor_de`: el kit "Building Kit" es MODULAR por diseño, todas sus piezas comparten la
	## MISMA altura real de base en el `.glb` de origen, así que calibrar cada una por su PROPIA
	## altura bruta al MISMO objetivo de 2,8m ya las deja a la misma escala mundo->px sin necesitar
	## compartir un factor -- a diferencia del kit "roads", cuyas piezas NO comparten proporción
	## bruta:contenido, ver la nota `factor_de` más arriba). 2,8m cae en la banda "~2,6-3m" del
	## encargo -- una planta de altura razonable junto al muñeco de 44px~1,70m.
	## `bk_suelo` usa `ancho_objetivo_celdas=1.0` (mismo modo/valor que `camino_recinto`/
	## `entrada_casa`): es una losa CASI PLANA, calibrar por altura daría una silueta minúscula.
	## Los 3 detalles (`bk_muro_bajo`/`bk_borde`/`bk_tuberia`) llevan su PROPIA altura estimada
	## (más bajas que un muro completo) -- valores de partida, a confirmar visualmente contra el
	## muñeco en la captura de la sonda (`tools/_probe_playtest_20260808.gd`).
	{"id": "bk_muro", "ruta": CARPETA_BUILDING + "wall.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_muro_esquina", "ruta": CARPETA_BUILDING + "wall-corner.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_ventana", "ruta": CARPETA_BUILDING + "wall-window-square.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_puerta", "ruta": CARPETA_BUILDING + "door-rotate-square-a.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_columna", "ruta": CARPETA_BUILDING + "column.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_escaleras", "ruta": CARPETA_BUILDING + "stairs-open.glb", "altura_objetivo_m": 2.8},
	{"id": "bk_suelo", "ruta": CARPETA_BUILDING + "floor.glb", "ancho_objetivo_celdas": 1.0},
	{"id": "bk_muro_bajo", "ruta": CARPETA_BUILDING + "wall-low.glb", "altura_objetivo_m": 1.4},
	{"id": "bk_borde", "ruta": CARPETA_BUILDING + "border.glb", "altura_objetivo_m": 0.8},
	{"id": "bk_tuberia", "ruta": CARPETA_BUILDING + "detail-pipe.glb", "altura_objetivo_m": 2.0},
]


## FILTRO PERMANENTE de ids a renderizar (2026-08-08, paso 5 de la receta de rehacer las casas):
## vacío = todos (comportamiento de siempre); con ids dentro, `_ready()` solo carga/renderiza esos --
## así una pasada de recalibrado de las 5 casas no toca (ni reescribe en disco) los PNG de coches/
## vallas/etc. Se deja permanente por utilidad futura (recalibrar un solo grupo sin re-render completo).
const SOLO_IDS: Array[String] = [
	"carretera_recta", "carretera_curva", "carretera_cruce", "carretera_interseccion_t",
	"carretera_paso_cebra",
]

## Las 5 piezas cuyo sprite final se recorta al rombo IDEAL 2:1 -- ver el bug 2/2 documentado en la
## cabecera de `MODELOS` (nota del kit roads). Deliberadamente NO incluye `calzada_recta`/
## `acera_recta` (mismas mallas, mismo canto, pero fuera del encargo de esta tarea -- quedan para un
## lote aparte si se retoman, ver `entorno_exterior.gd::_pintar_overlay_calle`, hoy sin llamar).
const RECORTAR_CANTOS_VIA: Array[String] = [
	"carretera_recta", "carretera_curva", "carretera_cruce", "carretera_interseccion_t",
	"carretera_paso_cebra",
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA_ENTORNO))

	if SOLO_MEDICION:
		await _medir_candidatos_casa()
		return

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render.

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		if not SOLO_IDS.is_empty() and not SOLO_IDS.has(modelo["id"]):
			continue
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


## Carga UN `.glb` suelto (ya importado dentro de `res://`) y vuelca sus `MeshInstance3D` en
## `todas` con el prefijo `<id>__` -- mismo formato que `render_props_poly.gd::_cargar`.
func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = modelo["ruta"]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[ENTORNO URBANO] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[ENTORNO URBANO] %s: %d MeshInstance3D cargadas (%s)" % [id, total, ruta])


func _nombres_de(todas: Dictionary, id: String) -> PackedStringArray:
	var prefijo: String = id + "__"
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar(todas: Dictionary) -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	print("[ENTORNO URBANO] px/metro = %.4f (muñeco %.0fpx ~ %.2fm) x factor de presencia %.2f" % [
		PX_POR_METRO, ALTO_MUNECO_PX, ALTO_MUNECO_M, FACTOR_PRESENCIA
	])

	# FACTOR ÚNICO DE FAMILIA (bug 1/3 del playtest 2026-08-08, ver la cabecera de `MODELOS`): las
	# piezas que declaran "factor_de" NO se autocalibran -- heredan aquí el `escala_pieza` YA
	# calculado de la pieza referenciada (procesada antes en `MODELOS`, siempre -- `carretera_recta`
	# va primero en la lista). Se rellena SOLO con el factor de las piezas que SÍ se autocalibran.
	var escalas_familia: Dictionary = {}

	# RECORTE CRUDO COMPARTIDO (bug 3/3, veredicto del usuario sobre `carreteras_v2.png`: "la curva
	# no prolonga la línea/el arcén/la calzada" -- ver la cabecera de `MODELOS`): las 5 piezas roads
	# usan el MISMO rectángulo de recorte en el frame RAW (antes de escalar), fijado por
	# `carretera_recta` en rotación 0 (la primera de la familia -- su contenido llena casi toda la
	# loseta 1x1, así que su recorte automático YA es, de hecho, el recorte de la loseta completa).
	# Antes de esto, cada pieza se recortaba (`_renderizar_bruto` -> `get_used_rect()`) a SU PROPIO
	# contenido opaco: para la curva (cuyo asfalto solo cubre parte de la loseta, ver el informe
	# anterior) eso descentraba su ancla respecto al centro REAL de la loseta que comparten las 5 --
	# el motivo de que la línea/el arcén/la calzada no continuaran de un tramo al siguiente. Con un
	# recorte FIJO compartido, las 5 quedan en el MISMO lienzo, con su contenido en su posición REAL
	# dentro de la loseta -- intercambiables celda a celda.
	var region_familia := Rect2i()

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		if not SOLO_IDS.is_empty() and not SOLO_IDS.has(id):
			continue
		var por_ancho: bool = modelo.has("ancho_objetivo_celdas")
		var por_longitud: bool = modelo.has("longitud_objetivo_m")
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[ENTORNO URBANO] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° -- define la escala de ESTA pieza. Piezas con volumen (altura_objetivo_m):
		# por ALTURA REAL x factor de presencia. Piezas casi planas (ancho_objetivo_celdas): por el
		# ANCHO de su huella en la rejilla -- ver la cabecera de `MODELOS`.
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var objetivo_px: float
		var medido_bruto_px: int
		var escala_pieza: float
		if por_ancho:
			var ancho_celdas: float = modelo["ancho_objetivo_celdas"]
			objetivo_px = ancho_celdas * float(Proyeccion.ANCHO_ROMBO)
			medido_bruto_px = _medir_ancho(imagen_0)
			var factor_de: String = String(modelo.get("factor_de", ""))
			if factor_de != "" and escalas_familia.has(factor_de):
				# Hereda el factor de la pieza de referencia -- ver `escalas_familia` arriba y la
				# cabecera de `MODELOS` (bug 1/2). NO se recalcula el propio -- por diseño, esta
				# pieza puede salir con menos/más de `ancho_celdas` celdas de ancho real: comparte
				# escala mundo->px con el resto de la familia en vez de forzar su propio objetivo.
				escala_pieza = escalas_familia[factor_de]
				var alto_bruto_0h: int = _medir_alto(imagen_0)
				print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx) -> FACTOR DE FAMILIA heredado de '%s'=%.4f (ancho final=%.1fpx, alto final=%.1fpx)" % [
					id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
					factor_de, escala_pieza, float(medido_bruto_px) * escala_pieza,
					float(alto_bruto_0h) * escala_pieza
				])
			else:
				escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
				escalas_familia[id] = escala_pieza
				var alto_bruto_0: int = _medir_alto(imagen_0)
				print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx), objetivo=%.2f celdas->%.1fpx -> factor=%.4f (alto final previsto=%.1fpx)" % [
					id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
					ancho_celdas, objetivo_px, escala_pieza, float(alto_bruto_0) * escala_pieza
				])
		elif por_longitud:
			# Ver la cabecera de `MODELOS`: mismo mecanismo que `ancho_objetivo_celdas` (mide el ANCHO
			# de la silueta en bruto), pero el objetivo sale de METROS REALES x la conversión
			# px/metro x factor de presencia -- la MISMA escala que usan el resto de piezas con volumen
			# -- en vez de celdas de rejilla.
			var longitud_m: float = modelo["longitud_objetivo_m"]
			objetivo_px = longitud_m * PX_POR_METRO * FACTOR_PRESENCIA
			medido_bruto_px = _medir_ancho(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx), objetivo=%.2fm->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				longitud_m, objetivo_px, escala_pieza
			])
		else:
			var altura_objetivo_m: float = modelo["altura_objetivo_m"]
			objetivo_px = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
			medido_bruto_px = _medir_alto(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[ENTORNO URBANO] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm×%.2f->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				altura_objetivo_m, FACTOR_PRESENCIA, objetivo_px, escala_pieza
			])

		# 2) Las 4 rotaciones, MISMO factor de escala UNIFORME (X=Y, ley del proyecto: PROHIBIDA la
		# escala no uniforme) -- `_escalar` es de `render_mobiliario.gd`, el padre de este script.
		# Piezas de la familia roads (bug 3/3, ver `region_familia` arriba): las 4 rotaciones se
		# recortan al MISMO rectángulo crudo compartido (`_renderizar_bruto_recorte_fijo`) en vez de
		# auto-detectar el contenido de cada una -- conserva la posición real dentro de la loseta.
		var escalados: Array[Dictionary] = []
		if RECORTAR_CANTOS_VIA.has(id):
			for rot: int in [0, 90, 180, 270]:
				grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
				var bruto_familia: Dictionary
				if region_familia.size.x <= 0:
					# Solo la primera vez (carretera_recta, rot=0): su recorte automático fija la
					# región de TODA la familia -- ver la cabecera de `region_familia`.
					bruto_familia = await _renderizar_bruto()
					var centro_raw := Vector2(TAM_RENDER / 2.0, TAM_RENDER / 2.0)
					region_familia = Rect2i(
						Vector2i(centro_raw - (bruto_familia["ancla"] as Vector2)),
						(bruto_familia["imagen"] as Image).get_size()
					)
				else:
					bruto_familia = await _renderizar_bruto_recorte_fijo(region_familia)
				escalados.append(_escalar(bruto_familia, escala_pieza))
		else:
			escalados.append(_escalar(bruto_0, escala_pieza))
			for rot: int in [90, 180, 270]:
				grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
				var bruto: Dictionary = await _renderizar_bruto()
				escalados.append(_escalar(bruto, escala_pieza))

		# 1.5) RECORTE DEL CANTO (bug 2/3 del playtest 2026-08-08, ver la cabecera de `MODELOS` y
		# `RECORTAR_CANTOS_VIA`): las 5 mallas del kit roads son una losa con grosor real (0,02 m) que
		# asoma como canto más allá del rombo IDEAL 2:1 de la cara de arriba -- se recorta (alfa=0)
		# aquí, en las 4 rotaciones YA escaladas, ANTES de componer sobre el lienzo común. El centro
		# del rombo es el ANCLA YA CONOCIDA de cada rotación (propagada por el pipeline, NUNCA
		# remedida del contenido -- bug 3/3: el centro del CONTENIDO de la curva no es el centro de
		# la loseta) y el ancho es el de la FAMILIA (`objetivo_px`, la loseta completa de
		# `carretera_recta` -- 480px -- no el contenido de cada pieza).
		if por_ancho and RECORTAR_CANTOS_VIA.has(id):
			for k: int in escalados.size():
				var img: Image = escalados[k]["imagen"]
				var centro_ancla: Vector2 = escalados[k]["ancla"]
				var recortada: Image = _recortar_a_rombo(img, centro_ancla, objetivo_px)
				# 1.6) AFEITADO DE EXTREMOS (encargo 2026-08-08, "siguen con la marca cuando se
				# unen, no se fusionan"): además del canto FUERA del rombo (1.5), el render deja
				# DENTRO, pegado a cada borde por el que la vía continúa, una franja oscura de
				# sombreado y un desvanecido de antialias que no llega opaco al borde -- al juntar
				# dos losetas eso se ve como costura oscura con rendija. Se sanea extendiendo el
				# perfil transversal de la vía hasta el borde exacto (ver `_afeitar_extremos_via`).
				escalados[k]["imagen"] = _afeitar_extremos_via(recortada, centro_ancla, objetivo_px)
			print("[ENTORNO URBANO]   %s: cantos recortados al rombo ideal 2:1 + extremos de via saneados en las 4 rotaciones" % id)

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		var ancla_final: Vector2 = compuesto["ancla"]

		# 1.75) ANCLA INVISIBLE (bug 3/3, 2º hallazgo -- compartir lienzo+ancla en el PIPELINE del
		# render (1.5, arriba) NO basta: el JUEGO no lee ese ancla, la RECONSTRUYE del PNG con
		# `AnclajeSprite._medir_centro_base` (min_x/max_x/max_y de los píxeles opacos, asumiendo que
		# ESA silueta ES el rombo 2:1 completo -- así ancla CUALQUIER prop del juego, sin excepción
		# para esta familia). Para la curva (su malla es una cuña/arco que NO llena la loseta, ver
		# `capturas/fuentes/kenney_roads/Previews/road-bend.png`) esa reconstrucción mide otro centro
		# -- verificado con Python: `carretera_curva_180` da min_x=141 contra min_x=1 de la recta, un
		# descuadre de 70px que es EXACTAMENTE el cruce/salto que se veía en la 2ª verificación de
		# esta tarea. FIX: 3 píxeles casi invisibles (alfa justo por encima de
		# `AnclajeSprite.UMBRAL_ALFA`=0,05 -- imperceptibles en juego) en los 3 puntos EXACTOS que
		# esa fórmula usa (izquierda/derecha/abajo del rombo IDEAL de la loseta completa, sacados del
		# ancla YA CONOCIDA -- `ancla_final`/`objetivo_px` -- no remedidos) para las 5 piezas de
		# `RECORTAR_CANTOS_VIA` -- así `_medir_centro_base` reconstruye el MISMO centro real para las
		# 5, sea cual sea su contenido visible.
		if por_ancho and RECORTAR_CANTOS_VIA.has(id):
			for imagen: Image in imagenes:
				_marcar_ancla_invisible(imagen, ancla_final, objetivo_px)
			print("[ENTORNO URBANO]   %s: ancla invisible marcada (izq/dcha/abajo del rombo de familia)" % id)

		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA_ENTORNO, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ProjectSettings.globalize_path(ruta))
			if err != OK:
				push_error("[ENTORNO URBANO] save_png '%s' fallo (error %d)" % [ruta, err])
			var alto_medido: int = _medir_alto(imagenes[i] as Image)
			print("[ENTORNO URBANO]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx (objetivo=%.1fpx)" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, objetivo_px
			])
		print("[ENTORNO URBANO] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, SALIDA_ENTORNO, id])

	print("[ENTORNO URBANO] hecho.")
	get_tree().quit()


## El ALTO en píxeles de la silueta opaca de una imagen: fila opaca más alta a fila opaca más
## baja (mismo criterio que `render_props_poly.gd::_medir_alto`, reutiliza `AnclajeSprite`).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[ENTORNO URBANO] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


## El ANCHO en píxeles de la silueta opaca: columna opaca más a la izquierda a columna opaca más
## a la derecha -- para piezas CASI PLANAS (`ancho_objetivo_celdas`), ver la cabecera de `MODELOS`.
func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	for px: int in range(ancho):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			min_x = px
			break
	if min_x < 0:
		push_warning("[ENTORNO URBANO] silueta totalmente transparente")
		return ancho
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			max_x = px
			break
	return max_x - min_x + 1


## Como `_renderizar_bruto` (`render_mobiliario.gd`) pero recortando SIEMPRE al `recorte` dado en
## vez de auto-detectar el contenido opaco (`get_used_rect()`) -- ver `region_familia` en
## `_ejecutar` (bug 3/3): las piezas cuyo contenido NO llena la loseta entera (la curva) perderían
## su posición real dentro de ella si cada una se recortara a su propio dibujo.
func _renderizar_bruto_recorte_fijo(recorte: Rect2i) -> Dictionary:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cruda: Image = _sub.get_texture().get_image()
	var centro := Vector2(TAM_RENDER / 2.0, TAM_RENDER / 2.0)
	var recortada: Image = cruda.get_region(recorte)
	var ancla: Vector2 = centro - Vector2(recorte.position)
	return {"imagen": recortada, "ancla": ancla}


## Recorta (alfa=0) todo píxel de `imagen` que quede FUERA del rombo IDEAL 2:1 centrado en
## `centro` (el ANCLA ya conocida de esta rotación, propagada por el pipeline -- ver la llamada en
## `_ejecutar`, bug 3/3: NUNCA remedida del contenido, que para piezas como la curva no está
## centrado en la loseta), de ancho EXACTO `ancho_ideal` (el de la FAMILIA -- `objetivo_px`, la
## loseta completa de `carretera_recta` -- no el contenido de cada pieza) y alto `ancho_ideal / 2`
## (ley 2:1 de `Proyeccion.ANCHO_ROMBO`/`ALTO_ROMBO`, la misma que valida el cubo de calibración de
## `render_mobiliario.gd`). Ver el bug 2/3 en la cabecera de `MODELOS`: esto elimina el canto
## (grosor real de 0,02 m de la losa) que sobresale del rombo puro de la cara de arriba.
func _recortar_a_rombo(imagen: Image, centro: Vector2, ancho_ideal: float) -> Image:
	var semiancho: float = ancho_ideal * 0.5
	var semialto: float = ancho_ideal * 0.25
	var copia: Image = imagen.duplicate()
	var ancho_img: int = copia.get_width()
	var alto_img: int = copia.get_height()
	for py: int in range(alto_img):
		var dy: float = (float(py) + 0.5) - centro.y
		if absf(dy) >= semialto:
			for px: int in range(ancho_img):
				var c: Color = copia.get_pixel(px, py)
				if c.a > 0.0:
					copia.set_pixel(px, py, Color(c.r, c.g, c.b, 0.0))
			continue
		for px: int in range(ancho_img):
			var dx: float = (float(px) + 0.5) - centro.x
			if absf(dx) / semiancho + absf(dy) / semialto > 1.0:
				var c: Color = copia.get_pixel(px, py)
				if c.a > 0.0:
					copia.set_pixel(px, py, Color(c.r, c.g, c.b, 0.0))
	return copia


## Profundidad (en coordenadas de rombo 0..1) de la franja que se SANEA en cada extremo de vía --
## cubre el canto oscuro (~4-6px en la loseta de 480px) y el desvanecido del antialias del render
## 3D. 0,03 de rombo ≈ 14px horizontales de loseta (~0,18 celdas): invisible sobre asfalto plano,
## suficiente para tragarse la marca entera.
const AFEITADO_EXTREMOS_UV: float = 0.03
## La muestra "sana" se toma un poco MÁS ADENTRO que la franja saneada -- si se muestreara al
## mismo borde de la franja se copiaría parte del propio canto que se está eliminando.
const AFEITADO_MUESTRA_UV: float = 0.05


## ¿Es `c` un color de CALZADA (asfalto o línea central clara)? Umbrales medidos con PIL sobre los
## PNG reales de las 5 piezas (2026-08-08, tarea "fusión de losetas"): asfalto (122,129,157), línea
## central clara (163-183, azulada); quedan FUERA la franja oscura del borde de la vía (≤104 de
## rojo), la banda blanca del arcén (255) y el vacío. El tono NO varía con la rotación (cara
## superior con luz cenital -- medido en las 4 rotaciones de `carretera_recta`).
func _es_color_de_calzada(c: Color) -> bool:
	if c.a < 0.8:
		return false
	return c.r >= 0.43 and c.r <= 0.75 and c.b <= 0.95 and c.b > c.r


## Los 4 bordes del rombo por los que la VÍA de esta pieza CONTINÚA hacia la loseta vecina
## (`[NO, SE, NE, SO]` en pantalla), detectados muestreando 5 puntos junto a cada borde (a 0,12 de
## profundidad, coordenada transversal 0,3..0,7): un borde es "vía" si ≥4 de las 5 muestras son
## color de calzada. Sin config por pieza -- verificado con PIL sobre los PNG actuales: la recta
## conecta NO+SE, la curva NO+SO, el cruce los 4, la T tres, y el paso de cebra NO+SE (sus franjas
## blancas viven en el centro de la loseta, no en la zona de muestreo).
func _bordes_de_via(imagen: Image, centro: Vector2, ancho_ideal: float) -> Array[bool]:
	var semiancho: float = ancho_ideal * 0.5
	var semialto: float = ancho_ideal * 0.25
	var profundidad: float = 0.12
	# Por borde: [u fijo, v fijo] -- el valor negativo marca la coordenada que BARRE (0,3..0,7).
	var franjas: Array = [
		[profundidad, -1.0],        # NO (u≈0): u fijo, v barre
		[1.0 - profundidad, -1.0],  # SE (u≈1)
		[-1.0, profundidad],        # NE (v≈0): v fijo, u barre
		[-1.0, 1.0 - profundidad],  # SO (v≈1)
	]
	var bordes: Array[bool] = [false, false, false, false]
	for b: int in 4:
		var aciertos: int = 0
		for t: float in [0.3, 0.4, 0.5, 0.6, 0.7]:
			var u: float = franjas[b][0] if (franjas[b][0] as float) >= 0.0 else t
			var v: float = franjas[b][1] if (franjas[b][1] as float) >= 0.0 else t
			var px: int = clampi(roundi(centro.x + (u - v) * semiancho), 0, imagen.get_width() - 1)
			var py: int = clampi(
				roundi(centro.y + (u + v - 1.0) * semialto), 0, imagen.get_height() - 1
			)
			if _es_color_de_calzada(imagen.get_pixel(px, py)):
				aciertos += 1
		bordes[b] = aciertos >= 4
	return bordes


## AFEITADO DE EXTREMOS (encargo 2026-08-08: "las carreteras siguen con la marca cuando se unen,
## no se fusionan" -- objetivo: fusión TOTAL asfalto-asfalto): el render 3D deja, DENTRO del rombo
## y pegado a cada borde por el que la vía continúa, (a) una franja oscura de canto/sombreado y
## (b) un desvanecido de antialias que no llega opaco al borde -- dos losetas juntas muestran una
## costura oscura con rendija transparente. Se sanea EXTENDIENDO el perfil transversal de la vía
## hasta el borde exacto del rombo: todo píxel a menos de `AFEITADO_EXTREMOS_UV` de un borde-vía
## copia el color del punto homólogo a `AFEITADO_MUESTRA_UV` de profundidad (misma coordenada
## transversal) -- asfalto empalma con asfalto, banda con banda y línea con línea. Los bordes SIN
## vía no se tocan (el antialias del arcén contra el césped se conserva). NO se alfa nada: alfar
## dejaría una rendija de suelo visible porque las losetas vecinas NO se solapan.
func _afeitar_extremos_via(imagen: Image, centro: Vector2, ancho_ideal: float) -> Image:
	var bordes: Array[bool] = _bordes_de_via(imagen, centro, ancho_ideal)
	if not (bordes[0] or bordes[1] or bordes[2] or bordes[3]):
		return imagen
	var semiancho: float = ancho_ideal * 0.5
	var semialto: float = ancho_ideal * 0.25
	var copia: Image = imagen.duplicate()
	var ancho_img: int = copia.get_width()
	var alto_img: int = copia.get_height()
	for py: int in range(alto_img):
		for px: int in range(ancho_img):
			var dx: float = (float(px) + 0.5) - centro.x
			var dy: float = (float(py) + 0.5) - centro.y
			var u: float = (dx / semiancho + dy / semialto + 1.0) * 0.5
			var v: float = (dy / semialto - dx / semiancho + 1.0) * 0.5
			if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
				continue   # fuera del rombo ideal: territorio de `_recortar_a_rombo`
			var nu: float = u
			var nv: float = v
			if bordes[0] and u < AFEITADO_EXTREMOS_UV:
				nu = AFEITADO_MUESTRA_UV
			elif bordes[1] and u > 1.0 - AFEITADO_EXTREMOS_UV:
				nu = 1.0 - AFEITADO_MUESTRA_UV
			if bordes[2] and v < AFEITADO_EXTREMOS_UV:
				nv = AFEITADO_MUESTRA_UV
			elif bordes[3] and v > 1.0 - AFEITADO_EXTREMOS_UV:
				nv = 1.0 - AFEITADO_MUESTRA_UV
			if is_equal_approx(nu, u) and is_equal_approx(nv, v):
				continue
			var sx: int = clampi(roundi(centro.x + (nu - nv) * semiancho), 0, ancho_img - 1)
			var sy: int = clampi(
				roundi(centro.y + (nu + nv - 1.0) * semialto), 0, alto_img - 1
			)
			copia.set_pixel(px, py, imagen.get_pixel(sx, sy))
	return copia


## Estampa 3 píxeles casi invisibles (alfa justo por encima de `AnclajeSprite.UMBRAL_ALFA`) en los
## puntos izquierdo/derecho/abajo del rombo IDEAL de la loseta completa (centrado en `ancla`, ancho
## `ancho_ideal`) -- ver el bug 3/3 (2º hallazgo) en `_ejecutar`: hace que
## `AnclajeSprite._medir_centro_base` (el juego) reconstruya el centro REAL de la loseta para
## piezas cuyo contenido visible no llega a esos puntos (la curva). No pisa un píxel YA opaco (si
## el contenido real ya llega ahí -- caso de `carretera_recta` -- no cambia nada visible).
func _marcar_ancla_invisible(imagen: Image, ancla: Vector2, ancho_ideal: float) -> void:
	var alfa_marca := 0.06
	var semiancho: float = ancho_ideal * 0.5
	var semialto: float = ancho_ideal * 0.25
	var ancho_img: int = imagen.get_width()
	var alto_img: int = imagen.get_height()
	var puntos: Array[Vector2i] = [
		Vector2i(clampi(roundi(ancla.x - semiancho), 0, ancho_img - 1), clampi(roundi(ancla.y), 0, alto_img - 1)),
		Vector2i(clampi(roundi(ancla.x + semiancho - 1.0), 0, ancho_img - 1), clampi(roundi(ancla.y), 0, alto_img - 1)),
		Vector2i(clampi(roundi(ancla.x), 0, ancho_img - 1), clampi(roundi(ancla.y + semialto - 1.0), 0, alto_img - 1)),
	]
	for p: Vector2i in puntos:
		var c: Color = imagen.get_pixel(p.x, p.y)
		if c.a <= AnclajeSpriteScript.UMBRAL_ALFA:
			c.a = alfa_marca
			imagen.set_pixel(p.x, p.y, c)


## Modo de SOLO MEDICIÓN (ver `SOLO_MEDICION`): carga cada letra de `LETRAS_SUBURBAN` una a una
## (cámara recolocada por pieza, igual que el bucle real de `_ejecutar`), mide su silueta bruta a 0°
## y calcula la altura final prevista con los 3 anchos de parcela reales -- SIN guardar ningún PNG.
## `id_receta`/`_ancla_de`/`_radio_de`/`_montar_receta` se reutilizan tal cual (mismo mecanismo que
## `_cargar`+`_ejecutar`, ver sus cabeceras) para no duplicar la lógica de encuadre/ancla.
func _medir_candidatos_casa() -> void:
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	print("[MEDICION CASAS] ALTO_PARED=%.1fpx -- banda razonable ~2-3,5x (~%.0f-%.0fpx)" % [
		ParedesSalasScript.ALTO_PARED, ParedesSalasScript.ALTO_PARED * 2.0, ParedesSalasScript.ALTO_PARED * 3.5
	])
	for letra: String in LETRAS_SUBURBAN:
		var ruta: String = CARPETA_SUBURBAN + "building-type-%s.glb" % letra
		var escena: PackedScene = load(ruta)
		if escena == null:
			push_warning("[MEDICION CASAS] no se pudo cargar %s" % ruta)
			continue
		var raiz: Node3D = escena.instantiate()
		contenedor.add_child(raiz)

		var todas: Dictionary = {}
		var nombres := PackedStringArray()
		for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := hijo as MeshInstance3D
			if mi.mesh == null:
				continue
			var overrides: Array[Material] = []
			for s: int in mi.mesh.get_surface_count():
				overrides.append(mi.get_surface_override_material(s))
			var nombre: String = "pieza__%s" % mi.name
			todas[nombre] = {
				"malla": mi.mesh, "transform": mi.global_transform,
				"material_override": mi.material_override, "overrides": overrides,
			}
			nombres.append(nombre)
		if nombres.is_empty():
			push_warning("[MEDICION CASAS] %s: sin MeshInstance3D" % letra)
			contenedor.remove_child(raiz)
			raiz.free()
			continue

		var receta: Dictionary = {"id_salida": "medicion_%s" % letra, "nombres": nombres}
		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var ancho_bruto: int = _medir_ancho(imagen_0)
		var alto_bruto: int = _medir_alto(imagen_0)
		var ratio: float = float(alto_bruto) / float(maxi(ancho_bruto, 1))

		var linea: String = "[MEDICION CASAS] %s: bruto=%dx%dpx (silueta %dx%dpx), ratio(alto/ancho)=%.4f" % [
			letra, imagen_0.get_width(), imagen_0.get_height(), ancho_bruto, alto_bruto, ratio
		]
		for ancho_celdas: float in ANCHOS_PARCELA_A_PROBAR:
			var alto_final: float = ancho_celdas * float(Proyeccion.ANCHO_ROMBO) * ratio
			linea += " | %.0fcel->%.1fpx(%.2fxALTO_PARED)" % [
				ancho_celdas, alto_final, alto_final / ParedesSalasScript.ALTO_PARED
			]
		print(linea)

		contenedor.remove_child(raiz)
		raiz.free()

	print("[MEDICION CASAS] hecho -- ningún PNG escrito.")
	get_tree().quit()
