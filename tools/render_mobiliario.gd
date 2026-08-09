extends Node3D
## RenderMobiliario — sprites de mobiliario ESCALADOS A LA REJILLA DEL JUEGO, desde el pack
## `isometric_office.glb`.
##
## Hermano de `render_catalogo_objetos.gd` (mismo modelo, misma cámara isométrica: 26,565°/45°,
## ortográfica, mismas luces) pero con un objetivo distinto: aquél es un CATÁLOGO para hojear
## (cada miniatura se ajusta a SU PROPIO marco, así que un armario y un ratón pueden salir con la
## misma altura de miniatura — perfecto para navegar, inservible para jugar). Este renderiza
## sprites que tienen que CASAR con el rombo de 80×40 px de `Proyeccion`: todas las piezas
## comparten la MISMA escala mundo→píxel, calibrada UNA vez y reutilizada tal cual para el resto
## — así un objeto pequeño de verdad (un monitor) sale pequeño en pantalla, no "normalizado".
##
## ── CÓMO SE USA ──────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderMobiliario.tscn
## No headless (GPU). Escribe en `assets/sprites/mobiliario/<id_salida>_<rotación>.png`, 4
## rotaciones por receta (yaw 0/90/180/270° alrededor del CENTRO del propio conjunto).
##
## ── RECETAS DE ESTA PASADA (ver design/art/mapa-integracion-mobiliario.md) ─────────────────────
## `mostrador_atencion` ← OBJ_021 entero (31 piezas: el escritorio con su cajonera, monitor,
## teclado y ratón, tal y como está montado en el catálogo — ver en `mesa_atencion.gd` qué piezas
## de CÓDIGO deja de dibujar cuando este sprite existe, porque ya vienen incluidas aquí).
##
## `comodidad_equipo_informatico` ← SOLO los 2 monitores del cluster OBJ_042 (8 piezas:
## Object_1192-1195 y Object_1197-1200). El despiece automático
## (`catalogo_despiece_manifest.json`, método "volumen") NO separó la silla de los monitores: sus
## 3 sub-grupos son una taza (SUB_042_1), un ratón (SUB_042_2) y "todo lo demás" (SUB_042_0: silla
## + teclado + LOS DOS MONITORES, juntos). Selección a mano, verificada con
## `tools/_diag_obj042.gd` (mide el AABB de cada pieza del cluster): los 8 nombres de arriba son
## los dos únicos grupos ELEVADOS (y del pivote ≈ 1,036, muy por encima de la silla y el teclado,
## que están a y ≈ 0,78-0,84) y con el tamaño combinado de un monitor (cada grupo de 4 piezas
## forma una caja de ~0,5×0,4×0,3 m — bezel + pantalla + trasera + brazo VESA).
##
## ── LA ESCALA: CÓMO SE CALIBRA CONTRA LA REJILLA ────────────────────────────────────────────────
## `Proyeccion` dibuja rombos de `ANCHO_ROMBO`×`ALTO_ROMBO` = 80×40 px por celda. Para una pieza de
## 1×1 celda, la huella proyectada de una caja `PiezaIso` a escala `e` mide EXACTAMENTE
## `ANCHO_ROMBO × e` px de ancho (`PiezaIso._huella()`, lineal en `escala`), así que no hace falta
## reproducir esa geometría aquí: basta el producto (ver `_ejecutar`).
##
## `ESCALA_OBJETIVO_MOSTRADOR` = 0,92 — el mostrador debe leerse como un mueble que CASI llena su
## celda (deja apenas el pasillo justo, no el 0,78 conservador de la caja de código del primer
## render: visto en el juego, quedaba pequeño para lo ancho que es un escritorio de verdad).
## DESACOPLADA a propósito de `MesaAtencionScript.ESCALA_MESA` (que se queda en 0,78, sin tocar):
## esa constante sigue gobernando SOLO la caja de repuesto que dibuja `mesa_atencion.gd` cuando
## el sprite no existe, un dibujo aparte con su propio criterio.
##
## El mostrador real se renderiza SIN forzar su tamaño de antemano: se mide cuánto ocupa su
## render "en bruto" (a la escala de cámara fija de esta pasada, ver `_radio_de`/`_colocar_
## camara`) y se calcula el factor de reducción que deja su ancho en `ANCHO_ROMBO ×
## ESCALA_OBJETIVO_MOSTRADOR` px. Ese MISMO factor —y no uno recalculado pieza a pieza— se aplica
## luego a las 4 rotaciones del mostrador Y A TODAS LAS DEMÁS RECETAS de la misma pasada: así se
## conserva el tamaño relativo real entre todas (un monitor es mucho más pequeño que un
## escritorio, un sofá de 3 plazas es más largo que un escritorio…), en vez de que cada una se
## normalice a su propio marco.
##
## ── EL ANCLA: DÓNDE "PISA" EL MUEBLE EN LA CELDA ────────────────────────────────────────────────
## El nodo que coloca el sprite en el juego pone su origen en el CENTRO del rombo de la celda
## (`Proyeccion.centro_iso`, el mismo punto donde `PiezaIso` ancla sus piezas). Ese punto NO es el
## centro del renderizado (que incluye la altura del mueble) NI el píxel más bajo de la silueta
## (que es la esquina del rombo MÁS CERCANA a cámara — con volumen, esa esquina cae medio
## `ALTO_ROMBO`×escala POR DEBAJO del centro; es la misma cuenta que hace `PiezaIso._huella()`
## con sus cuatro vértices). Por eso el ancla se calcula analíticamente, no se adivina mirando la
## imagen: se centra el conjunto en (0,0,0) tomando el centro X/Z de su AABB al nivel del SUELO
## (el Y MÍNIMO, no el centro), se apunta la cámara ahí y, en ortográfica, `look_at` dibuja SIEMPRE
## el punto al que mira en el centro exacto del framebuffer — así se conoce su píxel exacto tras
## recortar y reescalar, sin medir nada a ojo (`_renderizar_bruto`/`_escalar`). Las 4 rotaciones de
## una misma receta se componen luego sobre un lienzo COMÚN —mismo tamaño, mismo píxel de ancla en
## las 4— para que quien las use aplique un único `sprite.offset` constante (`_componer`).

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const SALIDA := "res://assets/sprites/mobiliario/"

## CORREGIDO 2026-08-02: el rombo 2:1 de `Proyeccion` exige sin(elevación)=0,5 -> 30,0° exactos;
## los 26,565° (`atan(1/2)`, heredados de `render_catalogo_objetos.gd`, que NO necesita casar con
## la rejilla del juego) tumbaban los bordes de base a pendiente ~0,447 y el mobiliario montaba en
## celdas ajenas — aviso del usuario 2026-08-02. Verificar con el cubo de calibración (más abajo)
## antes de re-renderizar nada: pendiente 0,500±0,01 en los dos bordes de base.
const ELEVACION_GRADOS: float = 30.0
## Se renderiza GRANDE y se reduce después (mismo criterio que el resto de la herramientas de
## render): perder detalle al achicar se nota mucho menos que renderizar ya pequeño.
##
## 512 → 2048 (2026-08-09, veredicto del usuario: *"en lugar de línea recta pura sale con el efecto
## sierra"*, y tras el MSAA: *"se ha mejorado pero muy poco, solo un 4%"*). El MSAA del viewport
## apenas hace nada con el renderer en modo Compatibility que usa este proyecto. Lo que SÍ da
## bordes lisos siempre es el SUPERMUESTREO: renderizar a 4× de lado (16× de píxeles) y dejar que
## la reducción LANCZOS de `_escalar` promedie — cada píxel final nace de la media de 16, que es
## exactamente lo que hace un antialiasing de verdad. Y no toca el arte: es el mismo render, solo
## que muestreado más fino.
const TAM_RENDER: int = 2048
## Aire alrededor del objeto al encuadrar la cámara, para que ningún borde roce el marco.
const MARGEN: float = 1.15
## Cuánto de su celda debe ocupar el mostrador en el sprite final — ver la cabecera ("LA ESCALA").
const ESCALA_OBJETIVO_MOSTRADOR: float = 0.92
## Las 4 rotaciones que pide cada receta (el juego rota mobiliario con R en incrementos de 90°).
const ROTACIONES: Array[int] = [0, 90, 180, 270]

## Pedido del usuario (2026-08-02): variante del mostrador a ESCALA DE 2 CELDAS (el mueble real de
## una ventanilla de dos puestos), archivos aparte (`mostrador_atencion2_<rot>.png`). CORREGIDO
## 2026-08-02 (2ª vez, mismo día): el primer intento reescalaba el mostrador de 1 módulo con un
## multiplicador (`MULTIPLICADOR_MOSTRADOR2` ≈×1,63) -- crecía también en ALTURA y quedaba enorme
## junto a los muñecos de 44 px, rechazado por el usuario. 2º intento (mismo día): DOS MÓDULOS
## REALES de OBJ_021 en fila -- RECHAZADO por el usuario 2026-08-03, se veía como "dos mesas juntas"
## con un ESCALÓN visible en la costura (los módulos no casan, cada uno con su propio despiece de
## madera). CORREGIDO 2026-08-03 (3er intento, el bueno): UNA SOLA instancia de OBJ_021 -- sin la
## silla horneada, como siempre -- cuyo CUERPO DE MADERA (`_nombres_obj021_solo_mueble`, 18 piezas)
## se estira ANISÓTROPAMENTE solo en X (`FACTOR_LARGO_MOSTRADOR2`, alto y fondo intactos) alrededor
## de un pivote fijo en el borde donde ya se apoya el equipo (`PIVOTE_X_CUERPO_MOSTRADOR`); los
## accesorios (monitor/teclado/ratón/teléfono) NO se estiran, se quedan en su transformada original
## -- al no moverse el pivote, ya caen bien colocados "hacia el extremo donde ya estaban", sin
## recolocarlos a mano. Una pieza única no puede tener costura ni escalón. Su lado largo de base
## debe medir EXACTAMENTE 2,00 celdas -- ver `_guardar_receta_a_escala` (paso 5 de `_ejecutar`).
const ID_MOSTRADOR_2CELDAS := "mostrador_atencion2"

## REGLA GENERAL (usuario, 2026-08-02): la base de CUALQUIER sprite multi-celda debe medir
## EXACTAMENTE su `superficie` de catálogo en celdas. `sofa_descanso` (superficie=3 en
## `datos/comodidades/sofa_descanso.tres`) usa el sprite `asiento_sofa3` (ver
## `construccion.gd::ASIENTO_SOFA3`, SOLO LECTURA) — se sobrescribe con esta regla (ver
## `MULTIPLICADOR_SOFA3`). `sillas_office` (superficie=2) NO tiene sprite propio todavía (no está
## en ninguna receta de este fichero ni en `_sprites_comodidad()` de `construccion.gd`) — no hay
## nada que reescalar para ella.

## Cubo de calibración (BoxMesh 1×1×1), NO es un sprite de juego — ver `_renderizar_cubo_calibracion`.
const SALIDA_CUBO_CALIBRACION := "res://tools/_calibracion_cubo.png"

const ID_MOSTRADOR := "mostrador_atencion"
const ID_EQUIPO_INFORMATICO := "comodidad_equipo_informatico"
const ID_SOFA_DESCANSO := "comodidad_sofa_descanso"
const ID_PAPELERA := "comodidad_papelera"
const ID_DISPENSADOR := "comodidad_dispensador_agua"
const ID_RADIO := "comodidad_radio"
const ID_ASIENTO_SOFA3 := "asiento_sofa3"
const ID_SILLA_ESPERA := "silla_espera"
const ID_SILLA_FUNCIONARIO := "silla_funcionario"

## El aparato de la RADIO (OBJ_038, `Object_1045`) no está sobre nada en la escena de origen — el
## usuario lo quiere "encima de un mueble bajo". Se reutiliza la cajonera del propio escritorio
## (`Object_833`, ya medida y verificada: tapa a Y=0,675, centro X=-9,1105, Z=0,794) como ese
## mueble bajo, y se desplaza SOLO el aparato para que su base caiga centrada en esa tapa. La
## cajonera se renderiza EN SU SITIO (delta cero) — solo el aparato lleva desplazamiento.
const DESPLAZAMIENTO_RADIO := Vector3(-0.488, 0.128, -7.730)

## El TELÉFONO (OBJ_046, 3 piezas) no vive junto al escritorio en la escena de origen — está
## posado en OTRA mesa, a su propia altura. Medido con `tools/_diag_obj042.gd` (AABB de las 31
## piezas de OBJ_021 + las 3 de OBJ_046):
##  · La bandeja del escritorio (`Object_829`, el cuerpo grande del tablero) tiene su cara de
##    arriba en Y = 0,695 (top de su AABB: pos.y -0,025 + size.y 0,720) y ocupa X ∈ [-9,368,
##    -7,778], Z ∈ [0,384, 1,134] — el monitor/teclado/papeles YA puestos en el escritorio llenan
##    la franja X ∈ [-9,31, -8,03], así que la esquina delantera-derecha (X alto, Z bajo) queda
##    libre.
##  · El teléfono, en su posición nativa, apoya en Y = 0,781 y su AABB combinado (3 piezas) centra
##    en X = -3,0915, Z = 8,748.
## El desplazamiento que lo lleva a esa esquina, con 0,08 m de margen a los dos bordes: mueve el
## centro X/Z del teléfono a (-7,778 - 0,08 - anchura/2, 0,384 + 0,08 + fondo/2) y baja su base a
## la superficie del escritorio (0,695 - 0,781). Es una primera colocación "a regla" (esquina +
## margen), no medida pieza a pieza contra el resto de objetos del tablero — se corrige mirando el
## sprite si queda montado sobre el monitor o volando del borde.
const DESPLAZAMIENTO_TELEFONO := Vector3(-4.841, -0.086, -8.176)

## SOLO para `mostrador_atencion2` (usuario 2026-08-03, 2º retoque: la atención pasa al CENTRO).
##
## IDENTIFICACIÓN VERIFICADA por render de diagnóstico (flotando cada grupo +3/+5/+7 m en Y, uno
## por uno, y mirando qué sube en la imagen -- descarta el primer vistazo a ojo, que había
## confundido monitor con teléfono): en rot 0, el PIVOTE (`PIVOTE_X_CUERPO_MOSTRADOR`, el borde SIN
## estirar donde ya vivían monitor/teclado/ratón/teléfono) cae ARRIBA-DERECHA en pantalla -- el
## extremo EMPUJADO por el estirón (el otro extremo del cuerpo, vacío, hacia -X) cae ARRIBA-
## IZQUIERDA. El usuario define OESTE = arriba-izquierda en pantalla en rot 0 -- por tanto OESTE es
## el extremo ESTIRADO (vacío) y ESTE es el extremo del PIVOTE (donde ya estaba todo el equipo).
##
## Decisión previa (SUSTITUIDA, ver historial git): monitor+teclado+ratón a la mitad OESTE
## (el extremo estirado). Rechazada/reemplazada por el usuario 2026-08-03: la atención pasa al
## CENTRO del mostrador de dos puestos -- el teléfono SÍ puede quedarse en un extremo (ESTE, el
## pivote; sigue sin desplazamiento propio, ver `desplazamientos_telefono`). La pantalla sigue
## mirando al NORTE (regla fija): esta traslación es solo en X, ninguna pieza rota, así que la
## orientación del monitor no cambia.
##
## Cálculo (mismo cluster rígido monitor+teclado+ratón, delta común a los tres para no romper su
## colocación relativa entre ellos):
##   centro_x monitor (sin desplazar) = (-8,5795-8,0337)/2 = -8,3066
##   borde ESTE (pivote, sin estirar) = -7,7778
##   borde OESTE (estirado, `FACTOR_LARGO_MOSTRADOR2`=2,00) = -7,7778 + (-9,3681-(-7,7778))×2,00
##                                                          = -10,9584
##   centro del cuerpo estirado ("centro del mostrador") = (-10,9584 + -7,7778) / 2 = -9,3681
##   delta = objetivo - centro_x_original = -9,3681 - (-8,3066) = -1,0615
## Solo X (Y/Z intactos: mismo alto sobre el tablero, misma profundidad -- el estirón tampoco los
## toca). Si se retoca `FACTOR_LARGO_MOSTRADOR2` se mueve el borde OESTE y por tanto el centro --
## recalcular igual.
const DESPLAZAMIENTO_EQUIPO_MOSTRADOR2 := Vector3(-1.0615, 0.0, 0.0)

## Piezas de OBJ_021 (el escritorio) SIN la silla horneada (ver el aviso dentro de `_recetas`, en
## `ID_MOSTRADOR`, sobre por qué se excluye) -- 27 piezas: cuerpo del escritorio, cajonera,
## organizador de papeles, monitor, teclado y ratón. Es la receta completa de `mostrador_atencion`
## (1 celda); `mostrador_atencion2` (2 celdas) reutiliza el CUERPO de este mismo conjunto
## (`_nombres_obj021_solo_mueble`, sin monitor/teclado/ratón) estirado en X -- ver su cabecera.
## `static var` y no `const`: en Godot 4.6 el parser no acepta una llamada al constructor de
## `PackedStringArray` como expresión constante ("Assigned value ... isn't a constant expression"),
## a diferencia de `Vector3(...)` (sí aceptado, ver `DESPLAZAMIENTO_TELEFONO`) -- se inicializa una
## vez al cargar el script, coste nulo aquí.
static var NOMBRES_OBJ021_SIN_SILLA := PackedStringArray([
	"Object_829", "Object_831", "Object_833", "Object_835", "Object_837", "Object_838",
	"Object_840", "Object_842", "Object_844", "Object_845", "Object_846", "Object_848",
	"Object_849", "Object_851", "Object_852", "Object_853", "Object_854",
	"Object_861", "Object_863", "Object_865",
	"Object_867", "Object_869", "Object_871", "Object_873", "Object_875", "Object_877",
	"Object_879",
])
## El TELÉFONO (OBJ_046, 3 piezas), traído a la esquina delantera-derecha del tablero -- ver
## `DESPLAZAMIENTO_TELEFONO`. NO forma parte de `NOMBRES_OBJ021_SIN_SILLA` (viene de otro cluster
## del GLB) -- se añade aparte SOLO al módulo A de cualquier receta que lo quiera.
static var NOMBRES_TELEFONO := PackedStringArray(["Object_1169", "Object_1170", "Object_1171"])

## El MONITOR de OBJ_021, identificado con `tools/_diag_obj021_piezas.gd` (2026-08-02): 4 piezas,
## mismo patrón de malla que la silla horneada del cluster (base+brazo/cuello+pantalla+respaldo --
## ver el aviso de `Object_856..859` en `_recetas`), elevadas sobre el tablero (y ∈ [0,693, 1,116],
## muy por encima de los 0,695 del tablero) y centradas en x≈-8,5 z≈0,79 -- coincide con el bulto
## visible en `capturas/NPC/Oficina/catalogo/objetos/OBJ_021.png`.
static var NOMBRES_MONITOR := PackedStringArray(["Object_851", "Object_852", "Object_853", "Object_854"])
## El TECLADO: 2 piezas, planas (0,011-0,017 m de alto) y del tamaño justo (≈0,43×0,19 m) sobre el
## tablero, DELANTE del monitor (z=0,53 contra z≈0,79 del monitor -- más cerca de cámara/usuario).
static var NOMBRES_TECLADO := PackedStringArray(["Object_848", "Object_849"])
## El RATÓN: 3 piezas diminutas (cuerpo+botón+rueda, ≈0,05×0,07 m) junto al teclado, entre éste y
## el monitor.
static var NOMBRES_RATON := PackedStringArray(["Object_837", "Object_838", "Object_840"])

## `mostrador_atencion2` (usuario 2026-08-03, 3er intento): el cuerpo de madera se estira en X
## alrededor de un pivote FIJO -- el borde del cuerpo en +X, donde YA se apoyan monitor/teclado/
## ratón/teléfono (medido con `tools/_diag_obj021_ejes.gd`: `_nombres_obj021_solo_mueble` -- 18
## piezas, cuerpo SIN accesorios -- da xmax=-7,7778 en las coordenadas crudas del GLB; el propio
## `Object_829`, el tablero grande, ya delimitaba esa huella: size.x=1,590 m, con `Object_829`
## empezando en xmin=-9,3681). Ese borde NO se mueve al estirar -- así el equipo queda "hacia el
## extremo donde ya estaba" sin recolocar nada a mano (ver `_transform_efectiva`, `escala_x`/
## `pivote_x`); el cuerpo crece hacia el otro extremo (-X), vacío, para el segundo puesto.
const PIVOTE_X_CUERPO_MOSTRADOR: float = -7.7778

## Estirón del cuerpo (SOLO en X -- alto y fondo intactos) sobre su ancho crudo de 1,590 m. Valor
## de partida aprobado por el usuario (2026-08-03, "~×2,05"); el mismo multiplicador de celda-exacta
## que ya usa el mostrador de 1 módulo (`MULTIPLICADOR_MOSTRADOR1`, paso 5 de `_ejecutar`) se aplica
## DESPUÉS y por igual a las dos piezas del render, así que -- proyección ortográfica, estiramiento
## puramente en un eje de mundo -- el lado largo final debe escalar de forma exactamente
## proporcional a este factor (1,00 celda del módulo × este factor). Verificar SIEMPRE con Python
## sobre el PNG ya guardado (lado largo = 2,00±0,05 celdas, mismo criterio que
## `MULTIPLICADOR_MOSTRADOR1`) y reajustar aquí si no cae en el sitio -- NO tocar la cámara.
## AJUSTADO 2026-08-03 tras medir con Python: ×2,05 daba lado_largo=2,056 (rot 0) -- 0,006 por
## encima de la tolerancia ±0,05 -- bajado a ×2,00 (la proyección ortográfica hace el estirón
## puramente lineal: medido≈factor, ver la cabecera), releído y confirmado dentro de tolerancia.
const FACTOR_LARGO_MOSTRADOR2: float = 2.00

## El CUERPO DE MADERA de OBJ_021 -- escritorio SIN monitor/teclado/ratón (ni silla, ya excluida en
## `NOMBRES_OBJ021_SIN_SILLA`) -- 18 piezas: tablero, cajonera, organizador de papeles. Es el grupo
## que `mostrador_atencion2` ESTIRA en X (ver `FACTOR_LARGO_MOSTRADOR2`); el teléfono tampoco entra
## aquí (no forma parte de `NOMBRES_OBJ021_SIN_SILLA`, ver `NOMBRES_TELEFONO`) porque va en el grupo
## de ACCESORIOS (sin estirar) junto con monitor/teclado/ratón -- ver `_recetas`.
static func _nombres_obj021_solo_mueble() -> PackedStringArray:
	var excluir: Dictionary = {}
	for n: String in NOMBRES_MONITOR:
		excluir[n] = true
	for n: String in NOMBRES_TECLADO:
		excluir[n] = true
	for n: String in NOMBRES_RATON:
		excluir[n] = true
	var resultado := PackedStringArray()
	for n: String in NOMBRES_OBJ021_SIN_SILLA:
		if not excluir.has(n):
			resultado.append(n)
	return resultado


## Las recetas de esta pasada. Cada una es un subconjunto de nombres `Object_NNN` del GLB (ver la
## cabecera para de dónde sale cada lista). `desplazamientos` (opcional): nombre -> Vector3 que se
## SUMA al origen de su transformada de mundo antes de centrar la receta — para piezas que, como
## el teléfono, no están ya donde hace falta en la escena de origen.
##
## FUNCIÓN y no `const`: el parser de GDScript no acepta un `Array[Dictionary]` anidado con
## `Vector3`/`PackedStringArray` como expresión constante ("Assigned value for constant isn't a
## constant expression") — se construye en cada arranque, que aquí es gratis (se llama una vez).
static func _recetas() -> Array[Dictionary]:
	# NO Object_856/857/858/859: es la SILLA horneada en el cluster (base+pistón+asiento+respaldo —
	# 4 piezas, mismo patrón de 4 mallas que el monitor 851-854), visible al rotar 180°/270° en el
	# primer render. Se excluye a propósito (ya no está en `NOMBRES_OBJ021_SIN_SILLA`): el
	# funcionario se sienta en la silla roja de OBJ_042 (2ª tanda), no en esta — con las dos habría
	# dos sillas apiladas en cada ventanilla. Ver aviso del usuario 2026-08-01.
	var nombres_mostrador: PackedStringArray = NOMBRES_OBJ021_SIN_SILLA.duplicate()
	nombres_mostrador.append_array(NOMBRES_TELEFONO)
	var desplazamientos_telefono: Dictionary = {
		"Object_1169": DESPLAZAMIENTO_TELEFONO,
		"Object_1170": DESPLAZAMIENTO_TELEFONO,
		"Object_1171": DESPLAZAMIENTO_TELEFONO,
	}
	# Los ACCESORIOS de `mostrador_atencion2` (monitor+teclado+ratón+teléfono): grupo aparte del
	# cuerpo, SIN `escala_x` (quedan tal cual estaban -- ver la cabecera del fichero). El teléfono
	# usa el MISMO desplazamiento que en `mostrador_atencion` (ya cae en el pivote, la mitad ESTE);
	# monitor+teclado+ratón llevan `DESPLAZAMIENTO_EQUIPO_MOSTRADOR2` (los tres, el mismo, para
	# moverse en bloque al CENTRO del mostrador sin romper su colocación relativa) -- ver la
	# cabecera de esa constante para la identificación verificada por render y la cuenta del centrado.
	var nombres_accesorios_mostrador: PackedStringArray = NOMBRES_MONITOR.duplicate()
	nombres_accesorios_mostrador.append_array(NOMBRES_TECLADO)
	nombres_accesorios_mostrador.append_array(NOMBRES_RATON)
	nombres_accesorios_mostrador.append_array(NOMBRES_TELEFONO)
	var desplazamientos_accesorios_mostrador2: Dictionary = {
		"Object_1169": DESPLAZAMIENTO_TELEFONO,
		"Object_1170": DESPLAZAMIENTO_TELEFONO,
		"Object_1171": DESPLAZAMIENTO_TELEFONO,
		"Object_851": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2, "Object_852": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2,
		"Object_853": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2, "Object_854": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2,
		"Object_848": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2, "Object_849": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2,
		"Object_837": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2, "Object_838": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2,
		"Object_840": DESPLAZAMIENTO_EQUIPO_MOSTRADOR2,
	}
	return [
		{
			"id_salida": ID_MOSTRADOR,
			"nombres": nombres_mostrador,
			"desplazamientos": desplazamientos_telefono,
		},
		{
			# `mostrador_atencion2`: el mostrador de DOS PUESTOS — UNA sola instancia de OBJ_021
			# (ver la cabecera del fichero: 3er intento, el bueno, tras el escalón visible de los DOS
			# módulos). Dos grupos, NO dos copias del mueble: "cuerpo" (el tablero+cajonera+
			# organizador, `_nombres_obj021_solo_mueble`, 18 piezas) ESTIRADO en X con `escala_x`/
			# `pivote_x` — ver `_transform_efectiva` — y "accesorios" (monitor+teclado+ratón+
			# teléfono) SIN estirar, tal cual estaban. Comparten el MISMO multiplicador de escala que
			# el mostrador de 1 celda (`MULTIPLICADOR_MOSTRADOR1`, paso 5 de `_ejecutar`): el cuerpo
			# ya sale a ~2,00 celdas por construcción (`FACTOR_LARGO_MOSTRADOR2` ≈ ×2 el ancho de 1
			# módulo), sin necesidad de un multiplicador aparte.
			# RETOQUE 2026-08-03 (tras aprobar la pieza estirada): identificado por render de
			# diagnóstico (flotando cada grupo en Y) que el PIVOTE cae en la mitad ESTE en pantalla
			# (no oeste, como se supuso a ojo la primera vez). 2º retoque, mismo día: la atención
			# pasa al CENTRO -- monitor+teclado+ratón se mueven en bloque al centro del mostrador
			# (`DESPLAZAMIENTO_EQUIPO_MOSTRADOR2`) y el teléfono se queda en el pivote (mitad ESTE,
			# su desplazamiento de siempre), en un extremo, como pide el usuario.
			"id_salida": ID_MOSTRADOR_2CELDAS,
			"grupos": [
				{
					"nombres": _nombres_obj021_solo_mueble(),
					"desplazamientos": {},
					"offset": Vector3.ZERO,
					"escala_x": FACTOR_LARGO_MOSTRADOR2,
					"pivote_x": PIVOTE_X_CUERPO_MOSTRADOR,
				},
				{
					"nombres": nombres_accesorios_mostrador,
					"desplazamientos": desplazamientos_accesorios_mostrador2,
					"offset": Vector3.ZERO,
				},
			],
		},
		{
			"id_salida": ID_EQUIPO_INFORMATICO,
			"nombres": PackedStringArray([
				"Object_1192", "Object_1193", "Object_1194", "Object_1195",
				"Object_1197", "Object_1198", "Object_1199", "Object_1200",
			]),
		},
		# ── 2ª TANDA (2026-08-01) — design/art/mapa-integracion-mobiliario.md ─────────────────────
		{
			# OBJ_011: sofá de 1 plaza -> comodidad `sofa_descanso` (superficie=3 en datos/, SIN
			# TOCAR: el sprite se ancla como pieza suelta en la celda ancla, no se estira a 3 celdas
			# — ver el aviso en `construccion.gd` sobre por qué NO es el mismo sprite que
			# `asiento_sofa3`).
			"id_salida": ID_SOFA_DESCANSO,
			"nombres": PackedStringArray(["Object_387", "Object_388"]),
		},
		{
			# OBJ_040: papelera, pieza única.
			"id_salida": ID_PAPELERA,
			"nombres": PackedStringArray(["Object_1055"]),
		},
		{
			# OBJ_002 vía su despiece: SOLO SUB_002_0 (la unidad del dispensador — base, cuerpo,
			# grifo, botellón). Excluido SUB_002_1 (`Object_943`, una papelera pegada al lado —
			# visualmente idéntica a OBJ_040, confirmado con Read: "sin lo que tuviera pegado").
			"id_salida": ID_DISPENSADOR,
			"nombres": PackedStringArray(["Object_23", "Object_24", "Object_25", "Object_26", "Object_28"]),
		},
		{
			# OBJ_038 (el aparato negro -> comodidad `radio`) HORNEADO sobre la cajonera del
			# escritorio (`Object_833`, ya usada y verificada en `mostrador_atencion`) — ver
			# `DESPLAZAMIENTO_RADIO`.
			"id_salida": ID_RADIO,
			"nombres": PackedStringArray(["Object_833", "Object_1045"]),
			"desplazamientos": {"Object_1045": DESPLAZAMIENTO_RADIO},
		},
		{
			# ARQ_007: el sofá de 3 plazas (mal archivado como "arquitectura" por tamaño — lado
			# mayor 1,90 m, por encima de `UMBRAL_ARQUITECTURA` de `render_catalogo_objetos.gd`).
			# Su eje LARGO (1,90 m) corre en Z de mundo, que es el mismo eje que usa
			# `Proyeccion`/`Construccion` para VERTICAL (ver la cabecera del fichero: "como el
			# render usa X y Z donde la rejilla usa X e Y") — así que la rotación 0° de este render
			# YA es la pose VERTICAL del asiento, y la de 90° es la HORIZONTAL. `Construccion`
			# elige entre esas dos, nunca 180/270.
			#
			# BUG (usuario + coordinador, 2026-08-03): faltaba el cojín de respaldo de la PRIMERA
			# plaza (rot 90/180 dejaban un hueco atravesable hasta el asiento). El "despiece por
			# volumen" del catálogo (ver `catalogo_objetos_manifest.json`) partió el sofá en DOS
			# clusters: `ARQ_007` (`Object_384`, cuerpo+brazos+2 de los 3 cojines de respaldo
			# horneados en la misma malla) y, SEPARADO, `OBJ_010` (`Object_385`, 1 pieza) — la
			# clasificación por tamaño lo mandó a "objetos" en vez de agruparlo con `ARQ_007`. La
			# receta original solo tiraba de `ARQ_007` y se dejaba fuera `Object_385`. Confirmado
			# con `tools/_diag_arq007.gd` (desechable): en un radio de 2,5 m alrededor del sofá,
			# las ÚNICAS DOS piezas del `.glb` son `Object_384` y `Object_385` (ninguna firma de
			# forma —tamaño local, ver `_firma_forma` de `render_despiece_objetos.gd`— de ninguna
			# de las dos se repite en NINGÚN otro punto del modelo) — no hay una tercera instancia
			# perdida en otra parte, así que "añadir la semilla que falta" es sumar `Object_385` a
			# esta receta. Verificado visualmente con `_reescalar_sofa.tscn`: con las dos piezas,
			# rot 90/180 muestran los TRES cojines de respaldo, sin hueco.
			"id_salida": ID_ASIENTO_SOFA3,
			"nombres": PackedStringArray(["Object_384", "Object_385"]),
		},
		{
			# La silla de espera "canónica": de OBJ_023/024/030/032 (misma silla, 4 copias — sin
			# mallas compartidas en este GLB exportado, cada copia va horneada aparte, así que
			# "más repetida" no se puede contar por índice de malla; comprobado con
			# `catalogo_manifest.json`: los 4 aparecen exactamente una vez cada uno y son las
			# ÚNICAS 4 piezas de 2 mallas con esta altura en las 253 clusters — visualmente
			# IDÉNTICAS con Read). Se usa la de menor id, OBJ_023, como representante.
			"id_salida": ID_SILLA_ESPERA,
			"nombres": PackedStringArray(["Object_931", "Object_932"]),
		},
		{
			# La silla ROJA de OBJ_042 (`Object_1071`, la única pieza de SUB_042_0 que no era ni
			# monitor ni teclado — ver la cabecera y `_diag_obj042.gd`): el funcionario sentado.
			"id_salida": ID_SILLA_FUNCIONARIO,
			"nombres": PackedStringArray(["Object_1071"]),
		},
	]

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("RenderMobiliario: no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return
	# El modelo completo se carga FUERA del SubViewport, solo para leer datos (igual que
	# `render_catalogo_objetos.gd`): nunca debe aparecer en un render.
	var contenedor := Node3D.new()
	add_child(contenedor)
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	contenedor.visible = false
	var todas: Dictionary = _recopilar_instancias(modelo)
	_ejecutar(todas)


## Vuelca cada `MeshInstance3D` del modelo en un diccionario `nombre -> {malla, transform,
## material_override, overrides}`, indexado por nombre para que las recetas puedan pescar sus
## piezas por nombre sin recorrer el árbol una vez por receta.
func _recopilar_instancias(modelo: Node3D) -> Dictionary:
	var todas: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas[String(mi.name)] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
	return todas


## Los GRUPOS de piezas de una receta: normalmente uno solo (el caso de toda la vida — `nombres` +
## `desplazamientos` planos), pero una receta puede declarar varios GRUPOS -- cada uno con su
## propio `offset` UNIFORME sumado a todas sus piezas -- para componer varias INSTANCIAS del mismo
## conjunto base en posiciones distintas dentro de un único sprite (ver `mostrador_atencion2`: dos
## módulos de OBJ_021 en fila -- mismo nombre de pieza, dos transformadas distintas, algo que el
## diccionario plano `desplazamientos` -- una entrada por NOMBRE -- no puede expresar).
static func _grupos_de(receta: Dictionary) -> Array[Dictionary]:
	if receta.has("grupos"):
		# NO asignación directa (`var x: Array[Dictionary] = receta["grupos"]`): viniendo de un
		# valor `Variant` de `Dictionary`, Godot 4.6 la rechaza en tiempo de ejecución ("Trying to
		# assign an array of type Array to a variable of type Array[Dictionary]") aunque los
		# elementos SÍ sean todos `Dictionary` -- hay que reconstruir el array tipado a mano.
		var reconstruido: Array[Dictionary] = []
		for g: Variant in (receta["grupos"] as Array):
			reconstruido.append(g as Dictionary)
		return reconstruido
	var grupo_unico: Array[Dictionary] = [{
		"nombres": receta["nombres"],
		"desplazamientos": receta.get("desplazamientos", {}),
		"offset": Vector3.ZERO,
	}]
	return grupo_unico


## La transformada de mundo de una pieza YA CON su `desplazamiento` de receta aplicado (suma al
## origen — ver `DESPLAZAMIENTO_TELEFONO`), el `offset` UNIFORME de su grupo (ver `_grupos_de`,
## ZERO salvo en recetas multi-instancia) Y, opcionalmente, un ESTIRÓN anisótropo en X.
##
## `escala_x`/`pivote_x` (opcionales, 1.0/0.0 = sin efecto): estira la pieza SOLO a lo largo del
## eje X de MUNDO, alrededor del punto `pivote_x` (ese punto no se mueve; el resto se aleja/acerca
## `escala_x` veces) -- para `mostrador_atencion2` (usuario 2026-08-03, ver la cabecera del
## fichero): el cuerpo de madera se estira así, los accesorios NO (quedan con `escala_x`=1.0 por
## defecto). Es la transformada afín A=diag(escala_x,1,1) aplicada en coordenadas de MUNDO tras
## sumar `delta`, compuesta a la IZQUIERDA de la transformada de la pieza -- por eso toca tanto el
## origen como la columna X de cada eje de la base (`b.x.x`/`b.y.x`/`b.z.x`, las tres componentes X
## de las tres columnas), no solo el origen: una pieza con rotación horneada también debe estirarse
## en mundo-X, no en su X local. Las piezas de OBJ_021 no llevan rotación horneada (basis identidad,
## verificado con `tools/_diag_obj021_ejes.gd`), pero la fórmula es general por si se reutiliza con
## una pieza rotada.
func _transform_efectiva(
	n: String, todas: Dictionary, desplazamientos: Dictionary, offset: Vector3 = Vector3.ZERO,
	escala_x: float = 1.0, pivote_x: float = 0.0
) -> Transform3D:
	var t: Transform3D = (todas[n] as Dictionary)["transform"]
	var delta: Vector3 = desplazamientos.get(n, Vector3.ZERO) + offset
	var origen: Vector3 = t.origin + delta
	if escala_x == 1.0:
		return Transform3D(t.basis, origen)
	origen.x = pivote_x + (origen.x - pivote_x) * escala_x
	var base: Basis = t.basis
	base.x.x *= escala_x
	base.y.x *= escala_x
	base.z.x *= escala_x
	return Transform3D(base, origen)


## El ancla de una receta: el centro X/Z de su AABB conjunta -- de TODOS sus grupos (ver
## `_grupos_de`) -- AL NIVEL DEL SUELO (el Y mínimo, no el centro) — el punto donde el mueble
## "pisa" la celda. Ver la cabecera.
func _ancla_de(receta: Dictionary, todas: Dictionary) -> Vector3:
	var caja := AABB()
	var primera := true
	for g: Dictionary in _grupos_de(receta):
		var nombres: PackedStringArray = g["nombres"]
		var desplazamientos: Dictionary = g.get("desplazamientos", {})
		var offset: Vector3 = g.get("offset", Vector3.ZERO)
		var escala_x: float = g.get("escala_x", 1.0)
		var pivote_x: float = g.get("pivote_x", 0.0)
		for n: String in nombres:
			if not todas.has(n):
				push_warning("RenderMobiliario: no se encontró la pieza %s en el GLB" % n)
				continue
			var t: Transform3D = _transform_efectiva(n, todas, desplazamientos, offset, escala_x, pivote_x)
			var c: AABB = t * (todas[n]["malla"] as Mesh).get_aabb()
			caja = c if primera else caja.merge(c)
			primera = false
	var centro: Vector3 = caja.get_center()
	return Vector3(centro.x, caja.position.y, centro.z)


## La distancia MÁXIMA de cualquier esquina de cualquier pieza de CUALQUIER grupo de la receta
## (ver `_grupos_de`) al ancla — sirve para fijar el tamaño de cámara que la contiene entera. Es
## invariante a rotar alrededor del propio ancla en Y (que es justo lo único que hace esta
## herramienta con el objeto), así que basta calcularla UNA vez por receta, no una vez por
## rotación.
func _radio_de(receta: Dictionary, todas: Dictionary, ancla: Vector3) -> float:
	var radio := 0.0
	for g: Dictionary in _grupos_de(receta):
		var nombres: PackedStringArray = g["nombres"]
		var desplazamientos: Dictionary = g.get("desplazamientos", {})
		var offset: Vector3 = g.get("offset", Vector3.ZERO)
		var escala_x: float = g.get("escala_x", 1.0)
		var pivote_x: float = g.get("pivote_x", 0.0)
		for n: String in nombres:
			if not todas.has(n):
				continue
			var t: Transform3D = _transform_efectiva(n, todas, desplazamientos, offset, escala_x, pivote_x)
			var c: AABB = t * (todas[n]["malla"] as Mesh).get_aabb()
			for esquina: Vector3 in _esquinas_de(c):
				radio = maxf(radio, (esquina - ancla).length())
	return radio


## Las 8 esquinas de una AABB, a mano (mismo patrón que `render_catalogo_objetos.gd`).
func _esquinas_de(caja: AABB) -> Array[Vector3]:
	var esquinas: Array[Vector3] = []
	var p: Vector3 = caja.position
	var s: Vector3 = caja.size
	for i: int in 8:
		esquinas.append(Vector3(
			p.x + s.x * float(i & 1),
			p.y + s.y * float((i >> 1) & 1),
			p.z + s.z * float((i >> 2) & 1)
		))
	return esquinas


## Vacía el `grupo` de forma SÍNCRONA antes de montar la siguiente receta.
func _limpiar_grupo(grupo: Node3D) -> void:
	for hijo: Node in grupo.get_children():
		grupo.remove_child(hijo)
		hijo.free()


## Añade una malla al `grupo`, con su transformada relativa al ANCLA (no a la del mundo) y sus
## materiales (override + por superficie) — mismo patrón que `render_catalogo_objetos.gd`.
func _montar_pieza(
	grupo: Node3D, malla: Mesh, transformada: Transform3D, material_override: Variant, overrides: Array
) -> void:
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.transform = transformada
	pieza.material_override = material_override
	for s: int in malla.get_surface_count():
		pieza.set_surface_override_material(s, overrides[s] if s < overrides.size() else null)
	grupo.add_child(pieza)


## Monta las piezas de TODOS los grupos de una receta (ver `_grupos_de`) en `grupo`, YA centradas
## en el ancla (que queda en el origen local de `grupo` — así rotar `grupo.rotation.y` gira el
## conjunto entero alrededor de su propio ancla, aunque tenga varios grupos/instancias).
func _montar_receta(grupo: Node3D, receta: Dictionary, todas: Dictionary, ancla: Vector3) -> void:
	_limpiar_grupo(grupo)
	for g: Dictionary in _grupos_de(receta):
		var nombres: PackedStringArray = g["nombres"]
		var desplazamientos: Dictionary = g.get("desplazamientos", {})
		var offset: Vector3 = g.get("offset", Vector3.ZERO)
		var escala_x: float = g.get("escala_x", 1.0)
		var pivote_x: float = g.get("pivote_x", 0.0)
		for n: String in nombres:
			if not todas.has(n):
				continue
			var t: Transform3D = _transform_efectiva(n, todas, desplazamientos, offset, escala_x, pivote_x)
			var it: Dictionary = todas[n]
			_montar_pieza(
				grupo, it["malla"], Transform3D(t.basis, t.origin - ancla),
				it.get("material_override"), it.get("overrides", [])
			)


## Cámara FIJA para TODA la pasada (nunca se recoloca por objeto ni por rotación — es lo que
## garantiza que todas las recetas comparten la misma escala mundo→píxel). `tam_mundo` es lo que
## abarca el encuadre, en metros; con el SubViewport cuadrado, es la misma cifra en horizontal y
## en vertical.
func _colocar_camara(tam_mundo: float) -> void:
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = maxf(tam_mundo, 0.05) * 3.0
	_camara.position = Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)
	) * distancia
	_camara.look_at(Vector3.ZERO, Vector3.UP)
	_camara.size = maxf(tam_mundo, 0.05)


## MULTIPLICADORES sobre `escala_final` (la escala YA CALIBRADA de 1 celda del paso 4) para las
## piezas multi-celda cuya base debe medir EXACTAMENTE su `superficie` de catálogo -- receta del
## usuario 2026-08-02: "el multiplicador se aplica SOBRE la escala calibrada de 1 celda de cada
## receta", medido con Python (fuera de Godot: `PIL`+`numpy`, umbral alfa>10/255) sobre el PNG YA
## GUARDADO por el paso 4, NO con una medida geométrica dentro de Godot -- una pieza compuesta (el
## mostrador: monitor/cajonera/teléfono a media altura) puede hacer que "el píxel más a la
## izquierda de toda la silueta" pertenezca a un saliente que no está al nivel del suelo, e
## infla la medida sin motivo real (bug visto y descartado durante esta misma sesión).
##
## Medida S(vértice más bajo)→W/E(esquina más a la izq/dcha, su y más baja) con
## `L = (|ΔX|/(ANCHO_ROMBO/2) + |ΔY|/(ALTO_ROMBO/2)) / 2` (misma cuenta que `Proyeccion`, 1,0 =
## una arista de 1 celda):
##   `mostrador_atencion_0.png` (escala_final, ESCALA_OBJETIVO_MOSTRADOR=0,92): L=1,225 -> mult=1,00/1,225
##   `asiento_sofa3_0.png` (escala_final, sin reescalar): lado largo L=1,525 -> mult=3,00/1,525
## Si se vuelve a medir y no cae en el sitio (±0,05 celdas), reajustar estas constantes con una
## regla de tres sobre la medida real y volver a lanzar — NO tocar la cámara (el cubo ya la valida).
## `MULTIPLICADOR_MOSTRADOR1` corrige el mostrador de 1 CELDA (el que queda para puestos "legado"
## de partidas guardadas viejas, ver `mesa_atencion.gd`): su huella medía 1,225 celdas -- contra la
## regla de huella exacta -- así que se recorta con este multiplicador para que quede en 1,00 (pedido
## del usuario 2026-08-02, última pieza pendiente). REUTILIZADO tal cual para `mostrador_atencion2`:
## ya NO hay un `MULTIPLICADOR_MOSTRADOR2` aparte. Pasó por DOS diseños rechazados antes de llegar
## aquí -- ver la cabecera del fichero -- primero un estirón ×1,63 de TODO el mueble (crecía en
## altura), luego DOS módulos de OBJ_021 en fila (costura con escalón visible). El diseño actual
## (2026-08-03) es UNA sola instancia con el cuerpo estirado en X (`FACTOR_LARGO_MOSTRADOR2`,
## `PIVOTE_X_CUERPO_MOSTRADOR`) y los accesorios sin tocar: el cuerpo ya sale en ~2,00 celdas por
## construcción con este mismo multiplicador, sin reescalar aparte.
const MULTIPLICADOR_MOSTRADOR1: float = 1.00 / 1.225
const MULTIPLICADOR_SOFA3: float = 2.00 / 1.525  # usuario 2026-08-03: sofa a 2 celdas

## Reescala y guarda las 4 rotaciones de una receta YA RENDERIZADA (en `crudos`), aplicando
## `escala` (normalmente `escala_final * MULTIPLICADOR_*`) directamente — sin volver a medir nada
## dentro de Godot (ver la cabecera de `MULTIPLICADOR_MOSTRADOR1`). Guarda en `id_salida` (puede
## coincidir con `id_receta` — sobrescribe sus PNG — o ser uno nuevo).
func _guardar_receta_a_escala(
	crudos: Dictionary, id_receta: String, id_salida: String, escala: float
) -> void:
	if not crudos.has(id_receta):
		push_warning("RenderMobiliario: no se pudo escalar %s (falta el bruto)" % id_receta)
		return
	var escalados: Array[Dictionary] = []
	for rot: int in ROTACIONES:
		escalados.append(_escalar(crudos[id_receta][rot], escala))
	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [SALIDA, id_salida, ROTACIONES[i]]
		imagenes[i].save_png(ProjectSettings.globalize_path(ruta))
	var ancla: Vector2 = compuesto["ancla"]
	var ancho: int = compuesto["ancho"]
	var alto: int = compuesto["alto"]
	print((
		"[MOBILIARIO] %s: lienzo %dx%d px, ancla en (%.1f, %.1f) = fraccion (%.3f, %.3f), factor=%.4f"
	) % [
		id_salida, ancho, alto, ancla.x, ancla.y, ancla.x / float(ancho), ancla.y / float(alto), escala
	])


## CRITERIO DE ACEPTACIÓN Nº1 (usuario, 2026-08-02): un `BoxMesh` 1×1×1 por el MISMO pipeline
## (cámara/luces/entorno) que el mobiliario real, para verificar de forma ANALÍTICA que la cámara
## reproduce el rombo 2:1 de `Proyeccion` antes de gastar el resto del render en el mobiliario. Su
## base (el cuadrado inferior del cubo) tiene que proyectar con los dos bordes que bajan del
## vértice más cercano a cámara a pendiente 0,500±0,01 — se mide con Python fuera de Godot (no es
## un sprite de juego, se guarda en `SALIDA_CUBO_CALIBRACION`, junto a la herramienta). Reutiliza
## el `_sub`/`_camara` ya montados de `_ejecutar` y los deja tal y como estaban (recoloca la cámara
## al salir es responsabilidad de quien llama, igual que con cualquier otra receta).
func _renderizar_cubo_calibracion(mundo: Node3D) -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	var pieza := MeshInstance3D.new()
	pieza.mesh = caja
	pieza.position = Vector3(0.0, 0.5, 0.0)  # el cubo está centrado en su propio origen: subir
	# medio metro deja su cara de ABAJO (el "suelo") justo en el ancla (0,0,0), igual que
	# `_montar_receta` centra cada pieza real respecto al Y MÍNIMO de su AABB.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.35, 0.35)
	pieza.material_override = mat
	var grupo := Node3D.new()
	grupo.add_child(pieza)
	mundo.add_child(grupo)

	var radio: float = Vector3(0.5, 1.0, 0.5).length()  # mitad de la diagonal del cubo, desde el ancla
	_colocar_camara(radio * 2.0 * MARGEN)
	var bruto: Dictionary = await _renderizar_bruto()
	var imagen: Image = bruto["imagen"]
	var ancla: Vector2 = bruto["ancla"]
	imagen.save_png(ProjectSettings.globalize_path(SALIDA_CUBO_CALIBRACION))
	print("[MOBILIARIO] cubo de calibración: %dx%d px, ancla en (%.1f, %.1f) -> %s" % [
		imagen.get_width(), imagen.get_height(), ancla.x, ancla.y, SALIDA_CUBO_CALIBRACION
	])

	mundo.remove_child(grupo)
	grupo.free()


## Captura el frame actual, recorta el aire transparente y calcula el píxel del ANCLA dentro de
## la imagen recortada. Como la cámara siempre mira a (0,0,0) —el ancla, tras `_montar_receta`—
## y la proyección es ortográfica, ese punto cae SIEMPRE en el centro exacto del framebuffer
## (`TAM_RENDER/2`, `TAM_RENDER/2`) antes de recortar; recortar solo desplaza ese origen por la
## esquina del `used_rect`.
func _renderizar_bruto() -> Dictionary:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cruda: Image = _sub.get_texture().get_image()
	var usado: Rect2i = cruda.get_used_rect()
	var centro := Vector2(TAM_RENDER / 2.0, TAM_RENDER / 2.0)
	if usado.size.x <= 0 or usado.size.y <= 0:
		push_warning("RenderMobiliario: render vacío")
		return {"imagen": cruda, "ancla": centro}
	var recortada: Image = cruda.get_region(usado)
	var ancla: Vector2 = centro - Vector2(usado.position)
	return {"imagen": recortada, "ancla": ancla}


## Reescala una imagen (LANCZOS, desde el render grande) y escala su ancla EN LA MISMA proporción.
func _escalar(entrada: Dictionary, factor: float) -> Dictionary:
	var imagen: Image = entrada["imagen"]
	var ancla: Vector2 = entrada["ancla"]
	var copia: Image = imagen.duplicate()
	var nuevo_ancho: int = maxi(1, roundi(float(imagen.get_width()) * factor))
	var nuevo_alto: int = maxi(1, roundi(float(imagen.get_height()) * factor))
	copia.resize(nuevo_ancho, nuevo_alto, Image.INTERPOLATE_LANCZOS)
	return {"imagen": copia, "ancla": ancla * factor}


## Compone una lista de imágenes (las 4 rotaciones de UNA receta, ya escaladas) sobre un lienzo
## COMÚN, del tamaño justo para que ninguna se recorte, con el ancla en el MISMO píxel en las 4.
## Así quien consuma los sprites usa un único `sprite.offset` para las 4 rotaciones.
func _componer(entradas: Array[Dictionary]) -> Dictionary:
	var izq := 0.0
	var derecha := 0.0
	var arriba := 0.0
	var abajo := 0.0
	for e: Dictionary in entradas:
		var imagen: Image = e["imagen"]
		var ancla: Vector2 = e["ancla"]
		izq = maxf(izq, ancla.x)
		arriba = maxf(arriba, ancla.y)
		derecha = maxf(derecha, float(imagen.get_width()) - ancla.x)
		abajo = maxf(abajo, float(imagen.get_height()) - ancla.y)
	var ancho: int = maxi(1, ceili(izq + derecha))
	var alto: int = maxi(1, ceili(arriba + abajo))
	var ancla_final := Vector2(izq, arriba)
	var lienzos: Array[Image] = []
	for e: Dictionary in entradas:
		var imagen: Image = e["imagen"]
		var ancla: Vector2 = e["ancla"]
		var lienzo := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
		var destino := Vector2i(roundi(ancla_final.x - ancla.x), roundi(ancla_final.y - ancla.y))
		lienzo.blit_rect(imagen, Rect2i(Vector2i.ZERO, imagen.get_size()), destino)
		lienzos.append(lienzo)
	return {"imagenes": lienzos, "ancho": ancho, "alto": alto, "ancla": ancla_final}


## Renderiza TODAS las recetas (4 rotaciones cada una), calibra la escala contra la rejilla y
## guarda los PNG. Todo en una corrutina para que el orden quede garantizado.
func _ejecutar(todas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var recetas: Array[Dictionary] = _recetas()

	# 1) El ancla de cada receta y el radio máximo de TODAS — de ahí sale la cámara fija de la
	# pasada entera (ver la cabecera: es lo que garantiza una única escala mundo→píxel).
	var anclas: Dictionary = {}
	var radio_max := 0.0
	for receta: Dictionary in recetas:
		var ancla: Vector3 = _ancla_de(receta, todas)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(receta, todas, ancla))
	var tam_camara: float = radio_max * 2.0 * MARGEN
	print("[MOBILIARIO] radio máximo de las recetas: %.3f m -> cámara fija a %.3f m" % [
		radio_max, tam_camara
	])

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
	_colocar_camara(tam_camara)

	# 1.5) CRITERIO DE ACEPTACIÓN Nº1 (ver la cabecera de `_renderizar_cubo_calibracion`): antes de
	# gastar el resto del render en el mobiliario real, se comprueba que la cámara reproduce el
	# rombo 2:1. `_colocar_camara` queda tocada por el cubo (encuadre propio) — se repone el de la
	# pasada real justo después.
	await _renderizar_cubo_calibracion(mundo)
	_colocar_camara(tam_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# 2) Renderiza las 4 rotaciones de cada receta y las guarda EN BRUTO (sin escalar aún: la
	# escala final se decide después de ver el mostrador a 0°).
	var crudos: Dictionary = {}
	for receta: Dictionary in recetas:
		var id_salida: String = receta["id_salida"]
		_montar_receta(grupo, receta, todas, anclas[id_salida])
		var por_rotacion: Dictionary = {}
		for rot: int in ROTACIONES:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			por_rotacion[rot] = bruto
			var imagen: Image = bruto["imagen"]
			print("[MOBILIARIO] %s @ %d°: bruto %dx%d px" % [
				id_salida, rot, imagen.get_width(), imagen.get_height()
			])
		crudos[id_salida] = por_rotacion

	# 3) Calibración: el mostrador a 0° define la escala de TODA la pasada (ver la cabecera).
	var referencia: Dictionary = (crudos.get(ID_MOSTRADOR, {}) as Dictionary).get(0, {})
	if referencia.is_empty():
		push_error("RenderMobiliario: no se pudo calibrar (falta el render del mostrador a 0°)")
		get_tree().quit(1)
		return
	var ancho_bruto: int = (referencia["imagen"] as Image).get_width()
	var ancho_objetivo: float = Proyeccion.ANCHO_ROMBO * ESCALA_OBJETIVO_MOSTRADOR
	var escala_final: float = ancho_objetivo / float(maxi(ancho_bruto, 1))
	print("[MOBILIARIO] calibración: mostrador bruto=%dpx -> objetivo=%.1fpx (80×%.2f) -> factor=%.4f" % [
		ancho_bruto, ancho_objetivo, ESCALA_OBJETIVO_MOSTRADOR, escala_final
	])

	# 4) Escala TODO con el MISMO factor, compone cada receta sobre su lienzo común y guarda.
	for receta: Dictionary in recetas:
		var id_salida: String = receta["id_salida"]
		var escalados: Array[Dictionary] = []
		for rot: int in ROTACIONES:
			escalados.append(_escalar(crudos[id_salida][rot], escala_final))
		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA, id_salida, ROTACIONES[i]]
			imagenes[i].save_png(ProjectSettings.globalize_path(ruta))
		var ancla_final: Vector2 = compuesto["ancla"]
		var ancho_final: int = compuesto["ancho"]
		var alto_final: int = compuesto["alto"]
		print("[MOBILIARIO] %s: lienzo %dx%d px, ancla en (%.1f, %.1f) = fracción (%.3f, %.3f)" % [
			id_salida, ancho_final, alto_final, ancla_final.x, ancla_final.y,
			ancla_final.x / float(ancho_final), ancla_final.y / float(alto_final)
		])

	# 5) Piezas cuya base debe medir EXACTAMENTE su `superficie` de catalogo en celdas (usuario
	# 2026-08-02) -- MISMO bruto ya renderizado en el paso 2, otra escala cada una (independiente
	# del `escala_final` compartido del paso 4, que salia a 0,92 celdas "a ojo", no a 1,00 exacto).
	# `mostrador_atencion`: SOBRESCRIBE su propio 1-celda (el que queda para puestos "legado" de
	# saves viejos, ver `mesa_atencion.gd`). `mostrador_atencion2`: geometría de DOS MÓDULOS reales
	# (ver `_recetas`), su PROPIO bruto -- ya NO el de `ID_MOSTRADOR` reescalado (ver el aviso en
	# `ID_MOSTRADOR_2CELDAS` y en `MULTIPLICADOR_MOSTRADOR1`) -- con el MISMO multiplicador que el
	# mostrador de 1 celda: cada módulo ya sale a 1,00 celda por construcción, así que el conjunto
	# de dos sale en ~2,00 sin multiplicador aparte. `asiento_sofa3` (sofa_descanso, superficie=3):
	# SOBRESCRIBE sus propios PNG -- es el unico sprite que ya usa el juego para esa comodidad (ver
	# construccion.gd::ASIENTO_SOFA3, SOLO LECTURA, no se toca). `sillas_office` (superficie=2) NO
	# tiene receta ni sprite propio todavia -- no hay nada que reescalar.
	_guardar_receta_a_escala(crudos, ID_MOSTRADOR, ID_MOSTRADOR, escala_final * MULTIPLICADOR_MOSTRADOR1)
	_guardar_receta_a_escala(
		crudos, ID_MOSTRADOR_2CELDAS, ID_MOSTRADOR_2CELDAS, escala_final * MULTIPLICADOR_MOSTRADOR1
	)
	_guardar_receta_a_escala(crudos, ID_ASIENTO_SOFA3, ID_ASIENTO_SOFA3, escala_final * MULTIPLICADOR_SOFA3)

	print("[MOBILIARIO] hecho.")
	get_tree().quit()
