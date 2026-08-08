class_name EntornoExterior extends Node2D
## EntornoExterior — el marco NO JUGABLE alrededor del edificio (24×13): acera + calzada frente a
## la puerta SUR (2026-08-08: era la oeste), el recinto/aparcamiento del control de acceso y el
## barrio disperso alrededor.
##
## Diseño: `design/art/entorno-exterior.md`. Esta pieza es SOLO el suelo por código + los props
## reales (assets 3D→sprite) que le dan vida — anclajes con nombre para garita/barrera aparte.
##
## ── REFORMA 2026-08-07 (feedback de playtest: "muy raro, solo cuadrados de colores, no hay vida" +
## "el recinto de la comisaría es inexistente") ──────────────────────────────────────────────────
## Referencia elegida por el usuario: `capturas/entorno.PNG` (Two Point Campus) — recinto tipo
## CAMPUS: césped como base, camino claro que conecta entrada→control→puerta, setos recortados
## bordeando el césped por dentro de la tapia, árboles sueltos, coches en sus plazas. Fuera del
## recinto: barrio SUAVE (verde con variación + un puñado de casas sueltas, no una cuadrícula densa
## de "manzanas").
##
## DOCTRINA DE ESTA REFORMA (orden del usuario, "puedes usar más recursos de renderizado... prefiero
## que uses más creación con IA en vez de simular con código"): **todo lo que tenga forma reconocible
## es un ASSET renderizado** (`tools/render_entorno_urbano.gd` → `assets/sprites/entorno/`), nunca
## una figura dibujada a mano (`Polygon2D`/`draw_*`). El código SOLO decide DÓNDE colocar cada pieza
## (rejilla + hash determinista) y sigue pintando RELLENOS PLANOS de color (césped/camino/calzada/
## aparcamiento) como base bajo esos assets — la única geometría que dibuja este fichero es esa
## baldosa lisa, exactamente como ya hacía la fase 1.
##
## Piezas usadas (ver `tools/render_entorno_urbano.gd` para la calibración de cada una):
##  · `capturas/fuentes/biblioteca_summer/`: `arbol_urbano` (árbol de calle, disperso fuera del
##    recinto), `seto` (bordeando la tapia por dentro), `farola` (anclajes de siempre).
##  · `capturas/fuentes/kenney_carkit/`: `police`/`sedan`/`suv` → coches de las 5 plazas.
##  · `capturas/fuentes/kenney_suburban/` (CC0): 5 tipos de casa (`casa_a/d/g/k/o`) para el barrio
##    disperso, `fence-low` (`valla_baja`, la tapia del recinto POR TRAMOS), `path-short`
##    (`camino_recinto`), `driveway-short` (`entrada_casa`), `tree-large/tree-small` (árboles a
##    juego con las casas).
##  · `capturas/fuentes/kenney_roads/` (CC0): `road-straight`/`road-side` → detalle de la calle de
##    acceso oeste.
##  · DESCARTADO tras evaluación: `metro_street_corner.glb` (candidato del usuario, PBR realista) —
##    ver el informe de la tarea: choca de estilo con el low-poly Kenney y es una escala de rascacielos
##    urbano, no de barrio de casas bajas alrededor de una comisaría pequeña. Se queda renderizado
##    como evidencia (`TEST_metro_corner_*.png`) pero SIN colocar en el juego.
##
## ── CAPA (ADR-0005 — declarar SIEMPRE dónde cuelga un visual nuevo) ─────────────────────────────
## Esta capa NO entra en `MundoProfundo`: es FONDO PURO, fuera del rect 24×13, `z_index = Z_CAPA`
## (más negativo que el suelo interior). Dentro de esta capa hay DOS bolsas:
##  · `_capa_overlays_planas`: los assets CASI PLANOS (camino/calzada/acera/entrada de casa) — se
##    pintan sobre el relleno de color, sin competir por profundidad con nada (son parte del suelo).
##  · `_capa_decor`: los assets CON ALTURA (valla, seto, árboles, casas, coches, farolas) —
##    `y_sort_enabled = true` para que no se solapen mal entre ellos (encargo: "orden de dibujo
##    interno por y").
##
## ── LAS TRES GARANTÍAS DE "NO JUGABLE" (verificadas, no solo prometidas) ────────────────────────
##  1. SIN PICKING: nada en el juego pregunta por una celda de ESTA capa.
##  2. SIN COLISIÓN: el `TileSet` de aquí NUNCA añade una capa de física, y los `Sprite2D` de los
##     props no llevan `CollisionShape2D`/`Area2D`.
##  3. SIN NAVEGACIÓN: el polígono navegable lo bakea `NPCsFlujo._bakear_navegacion` en un rectángulo
##     FIJO que este fichero no toca — salvo `RECT_RECINTO`, ver la nota original más abajo.
##
## ── EL RECORRIDO, EN CELDAS DEL PLANO LÓGICO (fila 13 = borde sur del edificio) ──────────────────
## CALLE (acera+calzada) → CONTROL (garita+barrera) → RECINTO (césped+camino+aparcamiento) → puerta.
##
## ── SIN randf() (regla del proyecto) ─────────────────────────────────────────────────────────────
## Toda variación (tono de baldosa, qué celda lleva árbol, qué candidato es casa) sale de un HASH
## determinista de la celda (`_hash_celda`) — la misma celda/candidato da siempre el mismo resultado.
##
## Nada de esto corre en `_process`: se construye UNA vez en `configurar()`.

# ── Paleta apagada (design/art/entorno-exterior.md §4) ──────────────────────────────────────────
## Calzada: asfalto oscuro desaturado.
const COLOR_CALZADA := Color(0.24, 0.25, 0.27)
## Acera: hormigón claro, apagado.
const COLOR_ACERA := Color(0.56, 0.57, 0.58)
## Las 5 plazas de aparcamiento son asfalto (mismo material que la calzada).
const COLOR_APARCAMIENTO := COLOR_CALZADA
## Césped: verde MUY desaturado (art-bible §6 rechaza el verde "folleto turístico") — es la base de
## TODO el recinto (2026-08-07: sustituye al hormigón beige de fase 1, ver la cabecera) y del barrio.
const COLOR_CESPED := Color(0.34, 0.40, 0.33)
## Camino del recinto (losas claras, bajo el asset `camino_recinto`) — el trazado entrada→control→
## puerta que pide la referencia. Más cálido/claro que la acera para leerse como paseo de jardín.
const COLOR_CAMINO := Color(0.70, 0.67, 0.60)
## Líneas de plaza: blancas para visita, azul institucional CNP muy atenuado para patrulla.
const COLOR_LINEA_VISITA := Color(0.88, 0.88, 0.85, 0.9)
const COLOR_LINEA_PATRULLA := Color(0.30, 0.42, 0.62, 0.9)

## z_index de TODO lo de esta capa: más negativo que el suelo interior (`Main._crear_suelo`, −3).
const Z_CAPA: int = -5

## ── COBERTURA TOTAL DEL PERÍMETRO (sin cambios en esta reforma — geometría pura) ────────────────
const COLUMNAS_JUGABLE: int = 24
const FILAS_JUGABLE: int = 13
const ZOOM_MIN_CAMARA: float = 0.5
const VENTANA_REFERENCIA := Vector2(1600.0, 900.0)
const COLCHON_EXTRA_ISO: float = 300.0

## Cuántas variaciones de tono por color (apagadas a propósito).
const VARIACIONES: int = 3
const AMPLITUD_VARIACION: float = 0.035
## Amplitud extra de "parche" de césped (patches de 6×6 celdas con un tono ligeramente distinto —
## encargo: "verde con variación", no una alfombra lisa). Más floja que `AMPLITUD_VARIACION` porque
## se SUMA a la variación de baldosa normal.
const AMPLITUD_PARCHE_CESPED: float = 0.028
const LADO_PARCHE_CESPED: int = 6

## Grosor (en px del plano lógico cuadrado) de las líneas pintadas de una plaza de aparcamiento.
const GROSOR_LINEA_APARCAMIENTO: float = 3.0

# ── El recorrido: columna eje + zonas (Rect2i en celdas del plano lógico) ───────────────────────
## REORIENTACIÓN 2026-08-08 (feedback del usuario: la entrada pasa de la fachada oeste, lado corto,
## a la fachada SUR, lado largo, centrada). Todo este bloque era una banda horizontal que salía por
## el oeste a la altura de `FILA_PUERTA`; ahora es una banda VERTICAL que sale por el sur a la
## columna de `COLUMNA_PUERTA` (11, la misma que `Construccion.CELDA_PUERTA_EDIFICIO.x`). El álgebra
## es la misma con los ejes intercambiados: "profundidad" (antes X, alejándose del edificio hacia el
## oeste) pasa a ser Y (alejándose hacia el sur); "banda lateral" (antes Y) pasa a ser X.
const COLUMNA_PUERTA: int = 11
const SEMI_ANCHO_RECORRIDO: int = 3
const ALTO_BANDA_RECORRIDO: int = SEMI_ANCHO_RECORRIDO * 2 + 1

const RECT_RECINTO := Rect2i(COLUMNA_PUERTA - SEMI_ANCHO_RECORRIDO, FILAS_JUGABLE, ALTO_BANDA_RECORRIDO, 8)
const RECT_CONTROL := Rect2i(COLUMNA_PUERTA - 1, FILAS_JUGABLE + 8, 3, 1)
const RECT_ACERA := Rect2i(COLUMNA_PUERTA - SEMI_ANCHO_RECORRIDO, FILAS_JUGABLE + 9, ALTO_BANDA_RECORRIDO, 1)
const RECT_CALZADA := Rect2i(COLUMNA_PUERTA - SEMI_ANCHO_RECORRIDO, FILAS_JUGABLE + 10, ALTO_BANDA_RECORRIDO, 2)
const RECT_CESPED := Rect2i(COLUMNA_PUERTA - 8, FILAS_JUGABLE + 2, 5, 7)

## EL CAMINO DEL RECINTO (2026-08-07, "caminos claros que conectan entrada-control-puerta"): UNA
## sola columna (la de la puerta) dentro de `RECT_RECINTO`, entre el césped y las plazas — un
## paseo, no una segunda explanada (ajuste tras revisar la captura: con más de una columna el camino
## ocupaba TODO el ancho del recinto y se comía el césped que pedía la referencia).
const PATH_RECINTO := Rect2i(COLUMNA_PUERTA, FILAS_JUGABLE, 1, 8)

# ── Perímetro completo del edificio (acera que rodea el edificio por norte/este/oeste — el sur ya
# lleva el recorrido completo de arriba, con el recinto/control/acera/calzada) ──────────────────
const GROSOR_ACERA_PERIMETRAL: int = 2
const RECT_ACERA_NORTE := Rect2i(
	-GROSOR_ACERA_PERIMETRAL, -GROSOR_ACERA_PERIMETRAL,
	COLUMNAS_JUGABLE + 2 * GROSOR_ACERA_PERIMETRAL, GROSOR_ACERA_PERIMETRAL
)
const RECT_ACERA_OESTE := Rect2i(-GROSOR_ACERA_PERIMETRAL, 0, GROSOR_ACERA_PERIMETRAL, FILAS_JUGABLE)
const RECT_ACERA_ESTE := Rect2i(COLUMNAS_JUGABLE, 0, GROSOR_ACERA_PERIMETRAL, FILAS_JUGABLE)

const RECT_NAV_PEATONAL := Rect2i(0, 0, COLUMNAS_JUGABLE, FILAS_JUGABLE + 2)
const RECT_ACERA_NAV_OESTE := Rect2i(0, FILAS_JUGABLE, COLUMNA_PUERTA - SEMI_ANCHO_RECORRIDO, 2)
const RECT_ACERA_NAV_ESTE := Rect2i(
	COLUMNA_PUERTA + SEMI_ANCHO_RECORRIDO + 1, FILAS_JUGABLE,
	COLUMNAS_JUGABLE - (COLUMNA_PUERTA + SEMI_ANCHO_RECORRIDO + 1), 2
)

## Todas las zonas YA resueltas por sus propios `RECT_*` — el relleno de verde exterior
## (`_pintar_verde_exterior`) y el scatter de props las saltan para no repintar/colocar encima.
const ZONAS_CERCANAS: Array[Rect2i] = [
	RECT_CALZADA, RECT_ACERA, RECT_RECINTO, RECT_CONTROL, RECT_CESPED,
	RECT_ACERA_NORTE, RECT_ACERA_OESTE, RECT_ACERA_ESTE,
]

## Las 5 plazas (3 patrulla + 2 visita), apiladas norte a sur dentro de `RECT_RECINTO` (2026-08-08:
##
## ── PLAZAS A 3 CELDAS DE FONDO (2026-08-07, "los coches ocupan MÍNIMO 3 celdas; la mesa ocupa 2 y
## un coche es más grande") ────────────────────────────────────────────────────────────────────────
## Antes cada plaza medía 1×2. El re-render de `tools/render_entorno_urbano.gd` (calibrado por
## LARGO real, no por altura) mide ahora ~3,2 celdas de largo por ~1,6-2,1 de ancho
## (`tools/_diag_medir_coches.gd`, verificado en el motor) -- el fondo de la plaza crece a 3 para
## que el coche no sobresalga por el camino/la fachada. El ANCHO se queda en 1 celda a propósito
## (no 2): ensanchar el recinto entero para dar 2 celdas a cada una de las 5 plazas es un rediseño
## de layout mayor (RECT_RECINTO, el trazado de la valla, el camino) fuera de esta tarea -- un coche
## de hasta 2,1 celdas de ancho en una plaza de 1 se sale un poco a los lados de su línea pintada
## (igual que en una plaza de calle real, donde el coche nunca calza justo la marca), efecto
## aceptado por ahora.
## rotación de ejes de la reforma: antes iban de oeste a este a lo largo de X, ahora van de norte
## a sur a lo largo de Y — mismo patrón, mismo `RECT_RECINTO`, banda lateral en X en vez de Y).
const PLAZAS_APARCAMIENTO: Array[Dictionary] = [
	{"id": &"visita_1", "tipo": &"visita", "rect": Rect2i(12, 19, 3, 1), "celda_ancla": Vector2i(13, 19)},
	{"id": &"visita_2", "tipo": &"visita", "rect": Rect2i(12, 18, 3, 1), "celda_ancla": Vector2i(13, 18)},
	{"id": &"patrulla_1", "tipo": &"patrulla", "rect": Rect2i(12, 17, 3, 1), "celda_ancla": Vector2i(13, 17)},
	{"id": &"patrulla_2", "tipo": &"patrulla", "rect": Rect2i(12, 16, 3, 1), "celda_ancla": Vector2i(13, 16)},
	{"id": &"patrulla_3", "tipo": &"patrulla", "rect": Rect2i(12, 15, 3, 1), "celda_ancla": Vector2i(13, 15)},
]

## Anclas con nombre para garita/barrera (sin sprite propio todavía — fuera del alcance de esta
## reforma, que es "vida" del entorno, no el control de acceso).
const ANCLA_GARITA := Vector2i(COLUMNA_PUERTA, FILAS_JUGABLE + 8)
const ANCLA_BARRERA := Vector2i(COLUMNA_PUERTA, FILAS_JUGABLE + 7)
const ANCLAS_FAROLAS: Array[Vector2i] = [
	Vector2i(COLUMNA_PUERTA - 3, FILAS_JUGABLE + 7), Vector2i(COLUMNA_PUERTA + 3, FILAS_JUGABLE + 7),
	Vector2i(COLUMNA_PUERTA, FILAS_JUGABLE + 2),
]
const ANCLA_BANCO := Vector2i(COLUMNA_PUERTA - 6, FILAS_JUGABLE + 5)
const ANCLAS_FAROLAS_PERIMETRO: Array[Vector2i] = [
	Vector2i(6, -2), Vector2i(18, -2), Vector2i(COLUMNAS_JUGABLE + 1, 3), Vector2i(COLUMNAS_JUGABLE + 1, 9),
	Vector2i(-2, 3), Vector2i(-2, 9),
	Vector2i(6, FILAS_JUGABLE + 1), Vector2i(18, FILAS_JUGABLE + 1),
]

# ── PROPS: rutas de los sprites renderizados (`tools/render_entorno_urbano.gd`) ──────────────────
const CARPETA_PROPS := "res://assets/sprites/entorno/"
## Las 4 rotaciones que trae cada pieza renderizada (`tools/render_entorno_urbano.gd`), en el orden
## del CICLO (R en el diseñador avanza por este mismo orden). Usada por `textura_de_pieza` para
## resolver cualquier entero de rotación a uno de los 4 PNG que existen de verdad.
const ORIENTACIONES_VALIDAS: Array[int] = [0, 90, 180, 270]
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const TEX_ARBOL_URBANO := preload("res://assets/sprites/entorno/arbol_urbano_0.png")
const TEX_SETO := preload("res://assets/sprites/entorno/seto_0.png")
const TEX_FAROLA := preload("res://assets/sprites/entorno/farola_0.png")
const TEX_COCHE_POLICIA_0 := preload("res://assets/sprites/entorno/coche_policia_0.png")
const TEX_COCHE_POLICIA_90 := preload("res://assets/sprites/entorno/coche_policia_90.png")
const TEX_COCHE_SEDAN_0 := preload("res://assets/sprites/entorno/coche_sedan_0.png")
const TEX_COCHE_SEDAN_90 := preload("res://assets/sprites/entorno/coche_sedan_90.png")
const TEX_COCHE_SUV_0 := preload("res://assets/sprites/entorno/coche_suv_0.png")
const TEX_COCHE_SUV_90 := preload("res://assets/sprites/entorno/coche_suv_90.png")
const TEX_VALLA_0 := preload("res://assets/sprites/entorno/valla_baja_0.png")
const TEX_VALLA_90 := preload("res://assets/sprites/entorno/valla_baja_90.png")
const TEX_CAMINO_RECINTO := preload("res://assets/sprites/entorno/camino_recinto_0.png")
const TEX_ENTRADA_CASA := preload("res://assets/sprites/entorno/entrada_casa_0.png")
const TEX_TREE_GRANDE := preload("res://assets/sprites/entorno/tree_grande_0.png")
const TEX_TREE_PEQUENO := preload("res://assets/sprites/entorno/tree_pequeno_0.png")
const TEX_CALZADA_RECTA_0 := preload("res://assets/sprites/entorno/calzada_recta_0.png")
const TEX_CALZADA_RECTA_90 := preload("res://assets/sprites/entorno/calzada_recta_90.png")
const TEX_ACERA_RECTA_0 := preload("res://assets/sprites/entorno/acera_recta_0.png")
const TEX_ACERA_RECTA_90 := preload("res://assets/sprites/entorno/acera_recta_90.png")
const TEX_PLANTER := preload("res://assets/sprites/entorno/planter_0.png")

## Las 5 fachadas de casa (tipos a/d/g/k/o, ver `render_entorno_urbano.gd`) para el barrio disperso,
## en el MISMO orden que `ANCHO_CASA_BARRIO` (índice a índice — nunca reordenar uno sin el otro).
const TEX_CASAS: Array[Texture2D] = [
	preload("res://assets/sprites/entorno/casa_a_0.png"),
	preload("res://assets/sprites/entorno/casa_d_0.png"),
	preload("res://assets/sprites/entorno/casa_g_0.png"),
	preload("res://assets/sprites/entorno/casa_k_0.png"),
	preload("res://assets/sprites/entorno/casa_o_0.png"),
]
## El ancho de parcela (celdas) con el que se calibró cada casa en `tools/render_entorno_urbano.gd`
## (ley 12, "casa pequeña ~6 / mediana ~7 / grande ~8"). Usado para dimensionar la huella de reserva
## de CADA candidato (`_colocar_casas_barrio`) -- antes la reserva era un cuadrado fijo de 7×7 que
## no distinguía tipo ni comprobaba contra OTRAS casas ya colocadas (bug latente: con la escala vieja
## nunca se notó, con casas 2-3× más anchas sí solapaban).
const ANCHO_CASA_BARRIO: Array[int] = [6, 6, 7, 7, 8]

## ── EL CATÁLOGO COMPLETO DE `ModoDisenadorEntorno` (2026-08-08, encargo "hay como 20 casas...
## submenú: casas, carreteras, árboles y jardín, objetos") ──────────────────────────────────────
## Estos dos arrays son SOLO un índice de ids -- `textura_de_pieza` (ya genérica, `id`+`rotación` →
## PNG en disco) resuelve cada uno sin necesitar un `const TEX_...` explícito por pieza; es la MISMA
## función que ya sirve el fantasma/paleta del diseñador y el layout congelado. `ModoDisenadorEntorno`
## los consume para construir sus pestañas 🏠 Casas / 🛣 Carreteras -- fuente ÚNICA de verdad de qué
## ids existen en cada grupo (nunca se duplica la lista a mano en dos sitios).
## Las 21 casas del kit "City Kit Suburban": las 5 originales (`casa_a/d/g/k/o`, NUNCA se tocan --
## ver la cabecera de `tools/render_entorno_urbano.gd`) + las 16 nuevas letter-true `casa_kit_*`
## (prefijo para no chocar con los ids viejos), en el orden alfabético de LETRA del kit (a..u) --
## `casa_d`→letra m, `casa_k`→letra i, `casa_o`→letra n (ver la sustitución documentada en la
## cabecera de `tools/render_entorno_urbano.gd`), el resto id=letra.
const CASAS_TODAS: Array[StringName] = [
	&"casa_a", &"casa_kit_b", &"casa_kit_c", &"casa_kit_d", &"casa_kit_e", &"casa_kit_f",
	&"casa_g", &"casa_kit_h", &"casa_k", &"casa_kit_j", &"casa_kit_k", &"casa_kit_l",
	&"casa_d", &"casa_o", &"casa_kit_o", &"casa_kit_p", &"casa_kit_q", &"casa_kit_r",
	&"casa_kit_s", &"casa_kit_t", &"casa_kit_u",
]
## Las 5 piezas del kit "Roads" (Kenney, CC0) renderizadas a escala de carril (ver la cabecera de
## `tools/render_entorno_urbano.gd`, nota "LEY DE ESCALA"). CASI PLANAS (línea central pintada en la
## textura, no en el volumen) -- `ModoDisenadorEntorno.PIEZAS_PLANAS` las trata igual que
## `camino_recinto`/`entrada_casa`.
const CARRETERAS_TODAS: Array[StringName] = [
	&"carretera_recta", &"carretera_curva", &"carretera_cruce", &"carretera_interseccion_t",
	&"carretera_paso_cebra",
]
## El set inicial del "Building Kit" (Kenney, CC0) -- 2026-08-08, encargo de playtest 3/3: "muros,
## ventanas, puertas y demás para montar p.ej. la garita". 10 de las 79 piezas del kit (ver la
## cabecera de `tools/render_entorno_urbano.gd`, bloque "BUILDING KIT", para la calibración de
## cada una). `bk_suelo` es CASI PLANA -- `ModoDisenadorEntorno.PIEZAS_PLANAS` la trata igual que
## `camino_recinto`/`entrada_casa`; el resto tiene volumen (van a `_capa_decor`/y-sort).
const CONSTRUCCION_TODAS: Array[StringName] = [
	&"bk_muro", &"bk_muro_esquina", &"bk_ventana", &"bk_puerta", &"bk_columna", &"bk_escaleras",
	&"bk_suelo", &"bk_muro_bajo", &"bk_borde", &"bk_tuberia",
]

## Las 4 direcciones cardinales del plano lógico, para recorrer vecinos de una celda.
const VECINOS_4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

## Casas del barrio disperso: candidatos en una rejilla gruesa con jitter (no alineados a ojo),
## filtrados por hash y por no invadir ninguna zona reservada NI la huella de otra casa ya colocada.
## 2026-08-08 (ley 12, casas 2-3× más anchas -- ver `ANCHO_CASA_BARRIO`): `ESPACIADO_CASA_BARRIO`
## sube 24->30 y `MAX_CASAS_BARRIO` baja 5->4 para que el barrio "respire" con el tamaño nuevo (antes
## la reserva de cada casa era un cuadrado fijo de 7×7 que ni distinguía tipo ni chocaba con otras
## casas -- con casas de hasta 8 celdas de ancho eso ya no alcanza, ver `_colocar_casas_barrio`).
const ESPACIADO_CASA_BARRIO: int = 30
const JITTER_CASA_BARRIO: int = 8
const PROBABILIDAD_CASA_BARRIO: int = 3
const MAX_CASAS_BARRIO: int = 4
## Aire extra (celdas) sumado al semiancho de CADA tipo de casa al construir su huella de reserva --
## separa una casa de la siguiente/zona sin que se toquen borde con borde.
const MARGEN_RESERVA_CASA: int = 1

## Árboles sueltos dispersos por el verde exterior (fuera del recinto): 1 de cada
## `ESPACIADO_ARBOL_DISPERSO` celdas válidas -- sparse a propósito, "árboles dispersos", no un
## bosque.
const ESPACIADO_ARBOL_DISPERSO: int = 70

## Árboles dentro del recinto (césped + franja norte): más densos que fuera, 1 de cada N celdas de
## césped libre (sin camino, sin plaza).
const ESPACIADO_ARBOL_RECINTO: int = 8

## ── ENTORNO FIJO (2026-08-07 — "¿podría hacerlo yo con esos objetos, como si fuera un builder?")
## ────────────────────────────────────────────────────────────────────────────────────────────────
## Si `res://datos/entorno_layout.json` existe, SUSTITUYE el scatter procedural entero (barrio de
## casas, valla+seto del recinto, árboles/farolas/parterres del recinto, coches y el verde con
## parches) por lo que el usuario compuso a mano con `ModoDisenadorEntorno`. Lo que NO cambia nunca
## (fijo en código, con o sin layout): la calle, las aceras, el recinto/césped/camino base y las 5
## plazas de aparcamiento pintadas -- ese es el ESQUELETO de circulación (`ANCLA_GARITA`, el
## recorrido que bakea `NPCsFlujo`) del que depende el juego, y no es lo que el usuario pidió poder
## tocar (pidió el "barrio disperso" y el decorado, no el trazado de acceso a la comisaría).
##
## El flujo de congelado (ver `ModoDisenadorEntorno`): el diseñador guarda en
## `user://entorno_disenado.json`; cuando el usuario dice "ya tenemos el entorno", alguien copia ese
## archivo a `res://datos/entorno_layout.json` (mismo esquema exacto -- ver `leer_layout`) y a partir
## de ahí CUALQUIER partida arranca con ese entorno fijo. Ese paso de copia es MANUAL a propósito.
const RUTA_LAYOUT_FIJO := "res://datos/entorno_layout.json"

## Los tipos de superficie que pinta el pincel del diseñador, y su color -- LOS MISMOS planos que ya
## usa el resto de este fichero (nunca se inventa un color nuevo para el layout fijo).
const COLOR_POR_TIPO_SUPERFICIE: Dictionary[StringName, Color] = {
	&"cesped": COLOR_CESPED, &"asfalto": COLOR_CALZADA, &"acera": COLOR_ACERA,
}

var _tam_celda: int = 40
var _origen: Vector2 = Vector2.ZERO
var _capa_suelo: TileMapLayer = null
var _capa_marcas: Node2D = null
## Assets CASI PLANOS (camino/calzada/acera/entrada de casa) -- sin y-sort, son parte del suelo.
var _capa_overlays_planas: Node2D = null
## Assets CON ALTURA (valla/seto/árboles/casas/coches/farolas) -- CON y-sort (encargo: "orden de
## dibujo interno por y para que no se solapen mal"). Hijo de `_mundo_profundo` cuando lo hay (ver
## `configurar`); si no, cae al patrón viejo (hijo de esta capa, fondo puro) -- SOLO por compatibilidad
## con tests/herramientas sueltas que no montan un `Main` completo.
var _capa_decor: Node2D = null
## Estado de los dos interruptores de visibilidad procedural (ver `_refrescar_visibilidad_procedural`).
var _scatter_visible: bool = true
var _base_visible: bool = true
var _fuentes: Dictionary[String, int] = {}
## Huellas (rect lógico) de las casas del barrio YA colocadas -- 2026-08-08: antes esta bolsa se
## declaraba pero NUNCA se rellenaba (bug latente sin notar mientras las casas eran pequeñas): ni
## dos casas se comprobaban entre sí, ni el scatter de árboles sueltos las esquivaba de verdad. Ahora
## SÍ se rellena en `_colocar_casas_barrio` y la consulta `_celda_reservada` (así el árbol disperso de
## `_pintar_verde_exterior` tampoco planta uno encima de una casa).
var _huellas_casas_barrio: Array[Rect2i] = []
## Las ANCLAS de pantalla (el pie del poste) de cada farola colocada -- procedural o del layout fijo
## -- para que `LucesObjetos.usar_farolas` las encienda de noche con el mismo mecanismo que las
## comodidades interiores. Ver `puntos_farolas`.
var _puntos_farolas: Array[Vector2] = []


## Construye TODO el visual (una sola vez — nunca por frame). `mundo_profundo` es la bolsa de
## profundidad de `Main` (ADR-0005): si se pasa, los props CON ALTURA de esta capa (`_capa_decor`)
## cuelgan de ahí para COMPETIR por profundidad con las paredes/mobiliario/gente del edificio -- ver
## la nota larga más abajo, junto a la creación de `_capa_decor`. `null` (por defecto) preserva el
## comportamiento histórico para tests/herramientas que no montan un `Main` completo.
## `ruta_layout_fijo` (por defecto `RUTA_LAYOUT_FIJO`) es un parámetro de INYECCIÓN, no una constante
## leída a ciegas dentro del cuerpo (`coding-standards.md`: "preferir inyección de dependencias...
## para que se pueda testear") -- así un test puede apuntar a un archivo de scratch en vez de tocar
## el `res://datos/entorno_layout.json` real (que además, en un run de verdad, congelaría el entorno
## para TODAS las partidas siguientes si un test se dejara algo a medio escribir).
func configurar(
	tam_celda: int, origen: Vector2, columnas: int, filas: int, mundo_profundo: Node2D = null,
	ruta_layout_fijo: String = RUTA_LAYOUT_FIJO
) -> void:
	_tam_celda = tam_celda
	_origen = origen
	_avisar_si_invade_lo_jugable(columnas, filas)
	_avisar_si_no_coincide_con_main(columnas, filas)
	z_index = Z_CAPA
	_capa_suelo = TileMapLayer.new()
	_capa_suelo.name = "SueloExterior"
	_capa_suelo.tile_set = _crear_tileset()
	_capa_suelo.transform = Proyeccion.transformada(origen)
	_capa_suelo.z_index = Z_CAPA
	add_child(_capa_suelo)

	# ── 1) RELLENOS PLANOS del ESQUELETO fijo (calle/recinto/plazas -- ver la cabecera de "ENTORNO
	# FIJO": esto se pinta SIEMPRE, con o sin layout de usuario) ─────────────────────────────────
	_pintar_rect(RECT_CALZADA, COLOR_CALZADA)
	_pintar_rect(RECT_ACERA, COLOR_ACERA)
	_pintar_rect(RECT_CESPED, COLOR_CESPED)
	_pintar_rect(RECT_RECINTO, COLOR_CESPED)
	_pintar_rect(PATH_RECINTO, COLOR_CAMINO)
	_pintar_rect(RECT_CONTROL, COLOR_CAMINO)
	_pintar_rect(RECT_ACERA_NORTE, COLOR_ACERA)
	_pintar_rect(RECT_ACERA_OESTE, COLOR_ACERA)
	_pintar_rect(RECT_ACERA_ESTE, COLOR_ACERA)
	_pintar_rect(RECT_ACERA_NAV_OESTE, COLOR_ACERA)
	_pintar_rect(RECT_ACERA_NAV_ESTE, COLOR_ACERA)
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		_pintar_rect(plaza["rect"], COLOR_APARCAMIENTO)

	_capa_marcas = Node2D.new()
	_capa_marcas.name = "MarcasAparcamiento"
	_capa_marcas.z_index = Z_CAPA
	add_child(_capa_marcas)
	_dibujar_marcas_aparcamiento()

	# ── 2) ASSETS -- overlays planos primero, decor con altura después (ver la cabecera) ─────────
	_capa_overlays_planas = Node2D.new()
	_capa_overlays_planas.name = "OverlaysPlanas"
	_capa_overlays_planas.z_index = Z_CAPA
	add_child(_capa_overlays_planas)
	_capa_decor = Node2D.new()
	_capa_decor.name = "Decor"
	_capa_decor.y_sort_enabled = true
	if mundo_profundo != null:
		# 🐛 FIX (2026-08-07, capas — el usuario: una farola/casa/coche del entorno pegada al SUR del
		# edificio se dibujaba SIEMPRE detrás del muro, aunque estuviera "más abajo" en pantalla (lo
		# que en isométrico debería taparlo a ÉL). Causa raíz: TODO `EntornoExterior` vivía a
		# `z_index = Z_CAPA` (−5), muy por debajo del z=0 de `MundoProfundo` (paredes/mobiliario/
		# gente) -- el z_index GANA SIEMPRE al orden por Y, así que ningún prop de esta capa podía
		# dibujarse jamás delante de un muro. `_capa_decor` entra como hijo de `MundoProfundo` (se
		# deja su `z_index` en el 0 por defecto: cualquier otro valor volvería a ganarle SIEMPRE al
		# orden por Y) -- mismo patrón que ya usan `ParedesSalas`/`Construccion`/`NPCsFlujo`: un
		# contenedor con `y_sort_enabled` propio colgado del bag exterior hace que SUS hijos compitan
		# EN el bag exterior (verificado en el motor 4.6, ver el comentario largo de
		# `Main._instanciar_mundo`). Las SUPERFICIES (`_capa_suelo`/`_capa_marcas`/
		# `_capa_overlays_planas`) se QUEDAN en el fondo -- son parte del suelo, no compiten con nada.
		mundo_profundo.add_child(_capa_decor)
	else:
		_capa_decor.z_index = Z_CAPA
		add_child(_capa_decor)

	var fijo: Dictionary = leer_layout(ruta_layout_fijo)
	if not fijo.is_empty():
		_pintar_overlay_camino()
		_aplicar_layout_fijo(fijo)
	else:
		_pintar_verde_exterior()
		_pintar_overlay_camino()
		_colocar_casas_barrio()
		_colocar_valla_y_seto()
		_colocar_props_recinto()
		_colocar_coches()


## El punto de PANTALLA de una celda de esta capa.
func punto_pantalla_de_ancla(celda: Vector2i) -> Vector2:
	return _origen + Proyeccion.centro_iso(celda)


## El `TileMapLayer` de suelo, para que sondas/tests puedan leer `get_used_cells()`.
func capa_suelo() -> TileMapLayer:
	return _capa_suelo


## Las anclas de pantalla (pie de poste) de todas las farolas colocadas -- procedurales o del layout
## fijo. `Main` se las pasa a `LucesObjetos.usar_farolas()` para que alumbren de noche con el mismo
## mecanismo que las comodidades interiores (ver la cabecera de `LucesObjetos`).
func puntos_farolas() -> Array[Vector2]:
	return _puntos_farolas


## Oculta/enseña el SCATTER PROCEDURAL de props (2026-08-08, encargo "poder diseñar sin la morralla
## procedural delante"): SOLO los props con forma (`_capa_decor` -- casas/coches/árboles/farolas/
## vallas/setos/jardineras) y sus overlays casi planos (`_capa_overlays_planas` -- camino del
## recinto/entrada de casa). El suelo base (césped/calzada/acera/recinto, `_capa_suelo`) y las
## líneas de aparcamiento (`_capa_marcas`) se quedan SIEMPRE visibles -- son el esqueleto fijo de
## circulación, no "morralla" (el congelado, `RUTA_LAYOUT_FIJO`, ya sustituye el scatter entero;
## esto es solo un lienzo limpio TEMPORAL mientras se diseña, ver `ModoDisenadorEntorno.alternar`).
func fijar_scatter_visible(visible_scatter: bool) -> void:
	_scatter_visible = visible_scatter
	_refrescar_visibilidad_procedural()


## Interruptor del ENTORNO BASE entero (2026-08-09, feedback "quiero hacer de nuevo el entorno y
## no me deja borrar lo que había"): además del scatter, esconde las líneas de aparcamiento
## (`_capa_marcas`). El asfalto del suelo (`_capa_suelo`) no se toca: el usuario lo repinta con la
## brocha de césped del diseñador (escribe sobre el mismo tilemap). Lo fija el diseñador (botón
## "🌍 Base"), viaja guardado en el layout y `_aplicar_layout_fijo` lo respeta en el congelado.
func fijar_base_visible(visible_base: bool) -> void:
	_base_visible = visible_base
	_refrescar_visibilidad_procedural()


## Los dos interruptores son independientes y comparten capas: el scatter (diseñador activo) y la
## base (elección del usuario) — una capa se ve solo si NINGUNO de los dos la esconde.
func _refrescar_visibilidad_procedural() -> void:
	var decor_visible: bool = _scatter_visible and _base_visible
	if _capa_decor != null:
		_capa_decor.visible = decor_visible
	if _capa_overlays_planas != null:
		_capa_overlays_planas.visible = decor_visible
	if _capa_marcas != null:
		_capa_marcas.visible = _base_visible


## ── LECTURA DEL LAYOUT (compartida con `ModoDisenadorEntorno`, que escribe el MISMO esquema en
## `user://entorno_disenado.json`) ────────────────────────────────────────────────────────────────
## `{"version":1, "piezas":[{"id":String,"celda":[x,y],"rotacion":int}, ...],
##   "superficies":[{"celda":[x,y],"tipo":String}, ...]}`. Devuelve `{}` (sin avisar) si `ruta` no
## existe -- caso normal (no hay layout todavía); `push_error` + `{}` si existe pero está corrupto/no
## es el esquema esperado -- un layout inválido NUNCA debe tumbar el arranque del juego, solo cae al
## procedural (o, en el diseñador, se trata como "vacío").
static func leer_layout(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("EntornoExterior.leer_layout: no se pudo abrir '%s' (error %d)" % [ruta, FileAccess.get_open_error()])
		return {}
	var texto: String = f.get_as_text()
	f.close()
	var parseado: Variant = JSON.parse_string(texto)
	if typeof(parseado) != TYPE_DICTIONARY:
		push_error("EntornoExterior.leer_layout: '%s' no es un objeto JSON válido" % ruta)
		return {}
	return parseado


## La textura de una pieza del catálogo (`assets/sprites/entorno/<id>_<rotación>.png`), cacheada por
## ruta -- todas las piezas colocables (procedurales o del diseñador) tienen sus 4 rotaciones ya
## renderizadas (`tools/render_entorno_urbano.gd`). `null` + aviso si el id/rotación no existe (un
## layout guardado con un id viejo que ya no está en el catálogo no debe reventar la carga).
static var _cache_texturas_layout: Dictionary[String, Texture2D] = {}
static func textura_de_pieza(id: String, rotacion: int) -> Texture2D:
	var rot: int = rotacion if ORIENTACIONES_VALIDAS.has(rotacion) else 0
	var ruta: String = "%s%s_%d.png" % [CARPETA_PROPS, id, rot]
	if _cache_texturas_layout.has(ruta):
		return _cache_texturas_layout[ruta]
	if not ResourceLoader.exists(ruta):
		push_warning("EntornoExterior.textura_de_pieza: '%s' no existe -- pieza del layout ignorada" % ruta)
		return null
	var tex: Texture2D = load(ruta)
	_cache_texturas_layout[ruta] = tex
	return tex


## Aplica un layout FIJO ya parseado (ver `leer_layout`): pinta las superficies pintadas a mano y
## coloca cada pieza en su celda/rotación -- EN VEZ DE todo el scatter procedural (ver la cabecera
## "ENTORNO FIJO"). Nunca toca el esqueleto (calle/recinto/plazas), que ya se pintó antes de llamar
## aquí (ver `configurar`).
func _aplicar_layout_fijo(datos: Dictionary) -> void:
	# El layout manda también sobre la visibilidad del entorno base (2026-08-09): si el usuario
	# diseñó con la base oculta, el congelado la respeta (layouts viejos sin la clave → visible).
	fijar_base_visible(bool(datos.get("base_visible", true)))
	for entrada: Variant in datos.get("superficies", []):
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var celda: Vector2i = _celda_de_entrada(entrada)
		var tipo := StringName(String(entrada.get("tipo", "")))
		if COLOR_POR_TIPO_SUPERFICIE.has(tipo):
			_pintar_celda(celda, COLOR_POR_TIPO_SUPERFICIE[tipo])
	for entrada: Variant in datos.get("piezas", []):
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var celda: Vector2i = _celda_de_entrada(entrada)
		var id: String = String(entrada.get("id", ""))
		var rotacion: int = int(entrada.get("rotacion", 0))
		var textura: Texture2D = textura_de_pieza(id, rotacion)
		if textura == null:
			continue
		if id == "camino_recinto" or id == "entrada_casa":
			_colocar_overlay_plano(textura, celda)
		else:
			_colocar_prop(textura, celda)
			if id == "farola":
				_puntos_farolas.append(punto_pantalla_de_ancla(celda))


func _celda_de_entrada(entrada: Dictionary) -> Vector2i:
	var c: Variant = entrada.get("celda", [0, 0])
	if typeof(c) != TYPE_ARRAY or (c as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int((c as Array)[0]), int((c as Array)[1]))


func _avisar_si_invade_lo_jugable(columnas: int, filas: int) -> void:
	var rect_jugable := Rect2i(0, 0, columnas, filas)
	for rect: Rect2i in [
		RECT_RECINTO, RECT_CONTROL, RECT_ACERA, RECT_CALZADA, RECT_CESPED,
		RECT_ACERA_NORTE, RECT_ACERA_OESTE, RECT_ACERA_ESTE,
	]:
		if rect.intersects(rect_jugable):
			push_error("EntornoExterior: la zona %s invade el rect jugable %s" % [rect, rect_jugable])


func _avisar_si_no_coincide_con_main(columnas: int, filas: int) -> void:
	if columnas != COLUMNAS_JUGABLE or filas != FILAS_JUGABLE:
		push_error(
			"EntornoExterior: columnas/filas recibidas (%d×%d) no coinciden con COLUMNAS_JUGABLE/FILAS_JUGABLE (%d×%d) — la cobertura de cámara quedaría mal calculada"
			% [columnas, filas, COLUMNAS_JUGABLE, FILAS_JUGABLE]
		)
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		if not RECT_RECINTO.encloses(plaza["rect"]):
			push_error("EntornoExterior: la plaza '%s' se sale de RECT_RECINTO" % plaza["id"])


func _pintar_rect(rect: Rect2i, color: Color) -> void:
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		for y: int in range(rect.position.y, rect.position.y + rect.size.y):
			_pintar_celda(Vector2i(x, y), color)


func _pintar_celda(celda: Vector2i, color: Color) -> void:
	var fuente_id: int = _fuente_de(color)
	_capa_suelo.set_cell(celda, fuente_id, Vector2i(_variacion_de_celda(celda), 0))


func _fuente_de(color: Color) -> int:
	var hex: String = PaletaPintura.a_hex(color)
	if _fuentes.has(hex):
		return _fuentes[hex]
	var fuente := TileSetAtlasSource.new()
	fuente.texture = _textura_zona(color)
	fuente.texture_region_size = Vector2i(_tam_celda, _tam_celda)
	for variacion: int in VARIACIONES:
		fuente.create_tile(Vector2i(variacion, 0))
	var id: int = _capa_suelo.tile_set.add_source(fuente)
	_fuentes[hex] = id
	return id


## Un `TileSet` VACÍO: SIN `add_physics_layer` (garantía nº2 de la cabecera — cero colisión).
func _crear_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(_tam_celda, _tam_celda)
	return tileset


func _textura_zona(color: Color) -> ImageTexture:
	var atlas := Image.create(_tam_celda * VARIACIONES, _tam_celda, false, Image.FORMAT_RGBA8)
	for variacion: int in VARIACIONES:
		var factor: float = (
			float(variacion) / float(VARIACIONES - 1) - 0.5
		) * 2.0 * AMPLITUD_VARIACION
		var tono: Color = color.lightened(factor) if factor >= 0.0 else color.darkened(-factor)
		var baldosa := Image.create(_tam_celda, _tam_celda, false, Image.FORMAT_RGBA8)
		baldosa.fill(tono)
		atlas.blit_rect(baldosa, Rect2i(0, 0, _tam_celda, _tam_celda), Vector2i(variacion * _tam_celda, 0))
	return ImageTexture.create_from_image(atlas)


## El hash entero determinista de una celda (SIN `randf`, regla del proyecto) — fuente ÚNICA de toda
## variación por celda/candidato de este fichero.
static func _hash_celda(celda: Vector2i) -> int:
	var h: int = celda.x * 73856093 ^ celda.y * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	return h ^ (h >> 16)


static func _variacion_de_celda(celda: Vector2i) -> int:
	return posmod(_hash_celda(celda), VARIACIONES)


## ── COBERTURA DE CÁMARA (geometría pura, sin estado — testeable a secas) ────────────────────────

static func _centro_tablero_iso() -> Vector2:
	var esquinas: Array[Vector2] = [
		Proyeccion.proyectar(Vector2.ZERO),
		Proyeccion.proyectar(Vector2(COLUMNAS_JUGABLE, 0) * Proyeccion.TAM_CELDA),
		Proyeccion.proyectar(Vector2(COLUMNAS_JUGABLE, FILAS_JUGABLE) * Proyeccion.TAM_CELDA),
		Proyeccion.proyectar(Vector2(0, FILAS_JUGABLE) * Proyeccion.TAM_CELDA),
	]
	var minimo: Vector2 = esquinas[0]
	var maximo: Vector2 = esquinas[0]
	for esquina: Vector2 in esquinas:
		minimo = Vector2(minf(minimo.x, esquina.x), minf(minimo.y, esquina.y))
		maximo = Vector2(maxf(maximo.x, esquina.x), maxf(maximo.y, esquina.y))
	return (minimo + maximo) * 0.5


static func limites_iso_cubiertos() -> Rect2:
	var medio_lado: Vector2 = (
		VENTANA_REFERENCIA / (2.0 * ZOOM_MIN_CAMARA) + Vector2(COLCHON_EXTRA_ISO, COLCHON_EXTRA_ISO)
	)
	var centro: Vector2 = _centro_tablero_iso()
	return Rect2(centro - medio_lado, medio_lado * 2.0)


static func rect_cobertura_logico() -> Rect2i:
	var area: Rect2 = limites_iso_cubiertos()
	var esquinas_iso: Array[Vector2] = [
		area.position, area.position + Vector2(area.size.x, 0.0),
		area.position + area.size, area.position + Vector2(0.0, area.size.y),
	]
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for esquina: Vector2 in esquinas_iso:
		var logico: Vector2 = Proyeccion.desproyectar(esquina) / float(Proyeccion.TAM_CELDA)
		minimo = Vector2(minf(minimo.x, logico.x), minf(minimo.y, logico.y))
		maximo = Vector2(maxf(maximo.x, logico.x), maxf(maximo.y, logico.y))
	var desde := Vector2i(int(floor(minimo.x)), int(floor(minimo.y)))
	var hasta := Vector2i(int(ceil(maximo.x)), int(ceil(maximo.y)))
	return Rect2i(desde, hasta - desde)


## ¿Esa celda cae dentro de alguna `ZONAS_CERCANAS` o de la franja peatonal? Comprobación
## compartida por el relleno de verde y por todos los scatter de props (árboles/casas).
func _celda_reservada(celda: Vector2i) -> bool:
	if RECT_NAV_PEATONAL.has_point(celda):
		return true
	for zona: Rect2i in ZONAS_CERCANAS:
		if zona.has_point(celda):
			return true
	for huella: Rect2i in _huellas_casas_barrio:
		if huella.has_point(celda):
			return true
	return false


## ── EL VERDE EXTERIOR: base del barrio (2026-08-07, sustituye a la antigua rejilla de "manzanas
## urbanas") ───────────────────────────────────────────────────────────────────────────────────
## Recorre `rect_cobertura_logico()` entero; cada celda que no cae en una zona ya resuelta se pinta
## de césped con un parche de tono (`AMPLITUD_PARCHE_CESPED`, patches de `LADO_PARCHE_CESPED`
## celdas -- "verde con variación", no una alfombra lisa) y, con probabilidad
## `1/ESPACIADO_ARBOL_DISPERSO`, recibe un árbol suelto (`_colocar_arboles_dispersos` llama a este
## bucle por separado tras crear `_capa_decor` -- ver `configurar`).
func _pintar_verde_exterior() -> void:
	var cobertura: Rect2i = rect_cobertura_logico()
	for x: int in range(cobertura.position.x, cobertura.position.x + cobertura.size.x):
		for y: int in range(cobertura.position.y, cobertura.position.y + cobertura.size.y):
			var celda := Vector2i(x, y)
			if _celda_reservada(celda):
				continue
			_pintar_celda_verde(celda)


func _pintar_celda_verde(celda: Vector2i) -> void:
	var parche := Vector2i(
		int(floor(float(celda.x) / float(LADO_PARCHE_CESPED))),
		int(floor(float(celda.y) / float(LADO_PARCHE_CESPED)))
	)
	var factor: float = (float(posmod(_hash_celda(parche), 7)) - 3.0) * (AMPLITUD_PARCHE_CESPED / 3.0)
	var tono: Color = COLOR_CESPED.lightened(factor) if factor >= 0.0 else COLOR_CESPED.darkened(-factor)
	_pintar_celda(celda, tono)


## Las líneas pintadas de las 5 plazas (sin cambios respecto a fase 1 — no hay pieza equivalente en
## los kits usados, así que sigue siendo el relleno plano tolerado).
func _dibujar_marcas_aparcamiento() -> void:
	for i: int in PLAZAS_APARCAMIENTO.size():
		var plaza: Dictionary = PLAZAS_APARCAMIENTO[i]
		var rect: Rect2i = plaza["rect"]
		var color: Color = (
			COLOR_LINEA_PATRULLA if plaza["tipo"] == &"patrulla" else COLOR_LINEA_VISITA
		)
		_dibujar_linea_vertical(rect.position.x, rect.position.y, rect.position.y + rect.size.y, color)
		if i == PLAZAS_APARCAMIENTO.size() - 1:
			_dibujar_linea_vertical(
				rect.position.x + rect.size.x, rect.position.y, rect.position.y + rect.size.y, color
			)


func _dibujar_linea_vertical(columna_x: int, fila_desde: int, fila_hasta: int, color: Color) -> void:
	var a := Vector2(float(columna_x) * _tam_celda, float(fila_desde) * _tam_celda)
	var b := Vector2(float(columna_x) * _tam_celda, float(fila_hasta) * _tam_celda)
	var medio: float = GROSOR_LINEA_APARCAMIENTO * 0.5
	var poligono := Polygon2D.new()
	poligono.color = color
	poligono.polygon = PackedVector2Array([
		_origen + Proyeccion.proyectar(a + Vector2(-medio, 0.0)),
		_origen + Proyeccion.proyectar(a + Vector2(medio, 0.0)),
		_origen + Proyeccion.proyectar(b + Vector2(medio, 0.0)),
		_origen + Proyeccion.proyectar(b + Vector2(-medio, 0.0)),
	])
	poligono.z_index = Z_CAPA
	_capa_marcas.add_child(poligono)


## ── PROPS: helpers genéricos ─────────────────────────────────────────────────────────────────

## Coloca un asset de UNA celda, anclado por su base (`AnclajeSprite`, la misma técnica que el
## mobiliario del interior) en la bolsa de altura (`_capa_decor`, y-sort).
func _colocar_prop(textura: Texture2D, celda: Vector2i, empuje: Vector2 = Vector2.ZERO) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	sprite.position = punto_pantalla_de_ancla(celda) + empuje
	_capa_decor.add_child(sprite)
	return sprite


## Coloca un asset CASI PLANO (camino/calzada/acera/entrada de casa) en la bolsa plana (SIN
## y-sort — es parte del suelo, ver la cabecera).
func _colocar_overlay_plano(textura: Texture2D, celda: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	sprite.position = punto_pantalla_de_ancla(celda)
	_capa_overlays_planas.add_child(sprite)


## Como `_colocar_overlay_plano`, pero anclado a un punto LÓGICO continuo (no una celda entera) —
## para piezas de 2 celdas de ancho como `calzada_recta`, cuyo centro cae ENTRE dos columnas.
func _colocar_overlay_en_punto(textura: Texture2D, punto_logico: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	sprite.position = _origen + Proyeccion.proyectar(punto_logico)
	_capa_overlays_planas.add_child(sprite)


## ── EL CAMINO DEL RECINTO Y EL CORREDOR DE CONTROL ───────────────────────────────────────────
func _pintar_overlay_camino() -> void:
	for x: int in range(PATH_RECINTO.position.x, PATH_RECINTO.position.x + PATH_RECINTO.size.x):
		for y: int in range(PATH_RECINTO.position.y, PATH_RECINTO.position.y + PATH_RECINTO.size.y):
			_colocar_overlay_plano(TEX_CAMINO_RECINTO, Vector2i(x, y))
	for x: int in range(RECT_CONTROL.position.x, RECT_CONTROL.position.x + RECT_CONTROL.size.x):
		_colocar_overlay_plano(TEX_CAMINO_RECINTO, Vector2i(x, RECT_CONTROL.position.y))


## ── LA CALLE DE ACCESO (calzada + acera) CON PIEZAS DEL KIT DE CARRETERAS ───────────────────────
## ⚠️ DEFERRED (2026-08-07, informe de esta tarea): el asset SE RENDERIZÓ bien (`calzada_recta_*.png`
## mide 160×81 px, exactamente 2 celdas — ver el log del render) pero tiled fila a fila en el juego
## la orientación no casaba con la calle y se veía como paneles gigantes solapados ("solar panels").
## Sin tiempo para calibrar la rotación correcta esta sesión — se deja SIN LLAMAR (la calzada/acera
## se quedan con el relleno plano de color, que es correcto) y la función viva para retomarlo.
func _pintar_overlay_calle() -> void:
	var centro_x: float = float(RECT_CALZADA.position.x) + float(RECT_CALZADA.size.x) * 0.5
	for y: int in range(RECT_CALZADA.position.y, RECT_CALZADA.position.y + RECT_CALZADA.size.y):
		var punto := Vector2(centro_x * float(Proyeccion.TAM_CELDA), (float(y) + 0.5) * float(Proyeccion.TAM_CELDA))
		_colocar_overlay_en_punto(TEX_CALZADA_RECTA_90, punto)
	for y: int in range(RECT_ACERA.position.y, RECT_ACERA.position.y + RECT_ACERA.size.y):
		_colocar_overlay_plano(TEX_ACERA_RECTA_90, Vector2i(RECT_ACERA.position.x, y))


## ── LA TAPIA DEL RECINTO, POR TRAMOS (`valla_baja`) + EL SETO POR DENTRO ────────────────────────
## Traza el borde de la unión `RECT_CONTROL ∪ RECT_RECINTO ∪ RECT_CESPED`: cada arista donde una
## celda DE DENTRO toca una celda de FUERA recibe un tramo de valla — salvo la cara oeste del
## control (el HUECO DE ENTRADA, en `ANCLA_GARITA`/`ANCLA_BARRERA`) y la cara que toca el propio
## edificio (columna 0, ya amurallada por `ParedesSalas`/la fachada).
func _celdas_recinto_vallado() -> Dictionary:
	var celdas: Dictionary = {}
	for rect: Rect2i in [RECT_CONTROL, RECT_RECINTO, RECT_CESPED]:
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			for y: int in range(rect.position.y, rect.position.y + rect.size.y):
				celdas[Vector2i(x, y)] = true
	return celdas


func _colocar_valla_y_seto() -> void:
	var dentro: Dictionary = _celdas_recinto_vallado()
	var celdas_con_seto: Dictionary = {}
	for celda: Vector2i in dentro:
		for dir: Vector2i in VECINOS_4:
			var vecina: Vector2i = celda + dir
			if dentro.has(vecina):
				continue
			if vecina.y < FILAS_JUGABLE:
				continue  # cara que toca el edificio -- ya amurallada, no duplicar
			if RECT_CONTROL.has_point(celda) and dir == Vector2i(0, 1):
				continue  # HUECO DE ENTRADA -- el punto del control (ANCLA_GARITA/ANCLA_BARRERA)
			_instanciar_valla(celda, dir)
			if not RECT_CONTROL.has_point(celda):
				celdas_con_seto[celda] = true
	for celda: Vector2i in celdas_con_seto:
		_colocar_prop(TEX_SETO, celda)


func _instanciar_valla(celda: Vector2i, dir: Vector2i) -> void:
	var textura: Texture2D = TEX_VALLA_0 if dir.y != 0 else TEX_VALLA_90
	var empuje: Vector2 = AnclajeSpriteScript.desvio_arrimado(textura, dir)
	_colocar_prop(textura, celda, empuje)


## ── PROPS DEL RECINTO: árboles + farolas + algún parterre junto a la entrada ────────────────────
func _colocar_props_recinto() -> void:
	var celdas_plaza: Dictionary = {}
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		var rect: Rect2i = plaza["rect"]
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			for y: int in range(rect.position.y, rect.position.y + rect.size.y):
				celdas_plaza[Vector2i(x, y)] = true
	for rect: Rect2i in [RECT_CESPED, RECT_RECINTO]:
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			for y: int in range(rect.position.y, rect.position.y + rect.size.y):
				var celda := Vector2i(x, y)
				if PATH_RECINTO.has_point(celda) or celdas_plaza.has(celda):
					continue
				if posmod(_hash_celda(celda), ESPACIADO_ARBOL_RECINTO) == 0:
					var textura: Texture2D = TEX_TREE_GRANDE if posmod(_hash_celda(celda), 2) == 0 else TEX_TREE_PEQUENO
					_colocar_prop(textura, celda)
	for ancla: Vector2i in ANCLAS_FAROLAS:
		_colocar_prop(TEX_FAROLA, ancla)
		_puntos_farolas.append(punto_pantalla_de_ancla(ancla))
	for ancla: Vector2i in ANCLAS_FAROLAS_PERIMETRO:
		_colocar_prop(TEX_FAROLA, ancla)
		_puntos_farolas.append(punto_pantalla_de_ancla(ancla))
	# Dos parterres junto a la entrada (control), a lado y lado del camino -- toque de jardín de la
	# referencia (`capturas/entorno.PNG`).
	_colocar_prop(TEX_PLANTER, Vector2i(COLUMNA_PUERTA - 2, RECT_CONTROL.position.y))
	_colocar_prop(TEX_PLANTER, Vector2i(COLUMNA_PUERTA + 2, RECT_CONTROL.position.y))


## ── LOS COCHES DE LAS 5 PLAZAS ───────────────────────────────────────────────────────────────
func _colocar_coches() -> void:
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		var celda: Vector2i = plaza["celda_ancla"]
		var textura: Texture2D = (
			TEX_COCHE_POLICIA_90 if plaza["tipo"] == &"patrulla"
			else (TEX_COCHE_SEDAN_90 if posmod(_hash_celda(celda), 2) == 0 else TEX_COCHE_SUV_90)
		)
		_colocar_prop(textura, celda)


## ── EL BARRIO DISPERSO: 3-5 casas sueltas, repartidas con verde entre ellas ─────────────────────
## Candidatos en una rejilla gruesa (`ESPACIADO_CASA_BARRIO`) con jitter determinista (para no leer
## como una cuadrícula) y un filtro de hash (`PROBABILIDAD_CASA_BARRIO`) — el primer
## `MAX_CASAS_BARRIO` que no choca con ninguna zona reservada se queda, en orden determinista
## (recorrido fila a fila de los índices de bloque).
func _colocar_casas_barrio() -> void:
	var cobertura: Rect2i = rect_cobertura_logico()
	var bx0: int = int(floor(float(cobertura.position.x) / ESPACIADO_CASA_BARRIO)) - 1
	var bx1: int = int(ceil(float(cobertura.position.x + cobertura.size.x) / ESPACIADO_CASA_BARRIO)) + 1
	var by0: int = int(floor(float(cobertura.position.y) / ESPACIADO_CASA_BARRIO)) - 1
	var by1: int = int(ceil(float(cobertura.position.y + cobertura.size.y) / ESPACIADO_CASA_BARRIO)) + 1
	var colocadas := 0
	for bx: int in range(bx0, bx1):
		for by: int in range(by0, by1):
			if colocadas >= MAX_CASAS_BARRIO:
				return
			var h: int = _hash_celda(Vector2i(bx, by))
			if posmod(h, PROBABILIDAD_CASA_BARRIO) != 0:
				continue
			var jx: int = posmod(h >> 3, JITTER_CASA_BARRIO) - JITTER_CASA_BARRIO / 2
			var jy: int = posmod(h >> 9, JITTER_CASA_BARRIO) - JITTER_CASA_BARRIO / 2
			var celda := Vector2i(bx * ESPACIADO_CASA_BARRIO + jx, by * ESPACIADO_CASA_BARRIO + jy)
			# El TIPO se decide ANTES de construir la huella (2026-08-08, ley 12): cada casa mide lo
			# que mide (`ANCHO_CASA_BARRIO`, 6-8 celdas), así que su reserva tiene que ser DE ESE
			# tamaño -- un cuadrado fijo (el bug de antes) o bien reservaba de más para la pequeña o
			# de menos para la grande.
			var indice: int = posmod(h, TEX_CASAS.size())
			var ancho_celdas: int = ANCHO_CASA_BARRIO[indice]
			var radio: int = int(ceili(float(ancho_celdas) * 0.5)) + MARGEN_RESERVA_CASA
			var huella := Rect2i(
				celda - Vector2i(radio, radio), Vector2i(radio * 2 + 1, radio * 2 + 1)
			)
			if huella.intersects(RECT_NAV_PEATONAL):
				continue
			var choca := false
			for zona: Rect2i in ZONAS_CERCANAS:
				if huella.intersects(zona):
					choca = true
					break
			if not choca:
				for otra: Rect2i in _huellas_casas_barrio:
					if huella.intersects(otra):
						choca = true
						break
			if choca:
				continue
			var textura: Texture2D = TEX_CASAS[indice]
			_colocar_prop(textura, celda)
			_colocar_overlay_plano(TEX_ENTRADA_CASA, celda + Vector2i(0, radio))
			var celda_arbol := celda + Vector2i(radio + 1, -1)
			if not _celda_reservada(celda_arbol):
				_colocar_prop(TEX_TREE_PEQUENO, celda_arbol)
			_huellas_casas_barrio.append(huella)
			colocadas += 1
