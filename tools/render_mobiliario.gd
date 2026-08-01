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

## Mismo ángulo que `render_catalogo_objetos.gd` / `render_sprites.gd`: `atan(1/2)` en grados, el
## que hace que un suelo 3D encaje con el rombo 2:1 del juego.
const ELEVACION_GRADOS: float = 26.565
## Se renderiza GRANDE y se reduce después (mismo criterio que el resto de la herramientas de
## render): perder detalle al achicar se nota mucho menos que renderizar ya pequeño.
const TAM_RENDER: int = 512
## Aire alrededor del objeto al encuadrar la cámara, para que ningún borde roce el marco.
const MARGEN: float = 1.15
## Cuánto de su celda debe ocupar el mostrador en el sprite final — ver la cabecera ("LA ESCALA").
const ESCALA_OBJETIVO_MOSTRADOR: float = 0.92
## Las 4 rotaciones que pide cada receta (el juego rota mobiliario con R en incrementos de 90°).
const ROTACIONES: Array[int] = [0, 90, 180, 270]

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

## Las recetas de esta pasada. Cada una es un subconjunto de nombres `Object_NNN` del GLB (ver la
## cabecera para de dónde sale cada lista). `desplazamientos` (opcional): nombre -> Vector3 que se
## SUMA al origen de su transformada de mundo antes de centrar la receta — para piezas que, como
## el teléfono, no están ya donde hace falta en la escena de origen.
##
## FUNCIÓN y no `const`: el parser de GDScript no acepta un `Array[Dictionary]` anidado con
## `Vector3`/`PackedStringArray` como expresión constante ("Assigned value for constant isn't a
## constant expression") — se construye en cada arranque, que aquí es gratis (se llama una vez).
static func _recetas() -> Array[Dictionary]:
	return [
		{
			"id_salida": ID_MOSTRADOR,
			"nombres": PackedStringArray([
				"Object_829", "Object_831", "Object_833", "Object_835", "Object_837", "Object_838",
				"Object_840", "Object_842", "Object_844", "Object_845", "Object_846", "Object_848",
				"Object_849", "Object_851", "Object_852", "Object_853", "Object_854",
				# NO Object_856/857/858/859: es la SILLA horneada en el cluster (base+pistón+asiento+
				# respaldo — 4 piezas, mismo patrón de 4 mallas que el monitor 851-854), visible al
				# rotar 180°/270° en el primer render. Se excluye a propósito: el funcionario se
				# sienta en la silla roja de OBJ_042 (2ª tanda), no en esta — con las dos habría dos
				# sillas apiladas en cada ventanilla. Ver aviso del usuario 2026-08-01.
				"Object_861", "Object_863", "Object_865",
				"Object_867", "Object_869", "Object_871", "Object_873", "Object_875", "Object_877",
				"Object_879",
				# El teléfono (OBJ_046), traído a la esquina delantera-derecha del tablero — ver
				# `DESPLAZAMIENTO_TELEFONO` arriba.
				"Object_1169", "Object_1170", "Object_1171",
			]),
			"desplazamientos": {
				"Object_1169": DESPLAZAMIENTO_TELEFONO,
				"Object_1170": DESPLAZAMIENTO_TELEFONO,
				"Object_1171": DESPLAZAMIENTO_TELEFONO,
			},
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
			# Pieza única, sin rotación propia (base identidad). Su eje LARGO (1,90 m) corre en Z
			# de mundo, que es el mismo eje que usa `Proyeccion`/`Construccion` para VERTICAL (ver
			# la cabecera del fichero: "como el render usa X y Z donde la rejilla usa X e Y") — así
			# que la rotación 0° de este render YA es la pose VERTICAL del asiento, y la de 90° es
			# la HORIZONTAL. `Construccion` elige entre esas dos, nunca 180/270.
			"id_salida": ID_ASIENTO_SOFA3,
			"nombres": PackedStringArray(["Object_384"]),
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


## La transformada de mundo de una pieza YA CON su `desplazamiento` de receta aplicado (suma al
## origen — ver `DESPLAZAMIENTO_TELEFONO`). Sin desplazamiento para esa pieza, es la transformada
## tal cual viene del GLB.
func _transform_efectiva(n: String, todas: Dictionary, desplazamientos: Dictionary) -> Transform3D:
	var t: Transform3D = (todas[n] as Dictionary)["transform"]
	var delta: Vector3 = desplazamientos.get(n, Vector3.ZERO)
	return Transform3D(t.basis, t.origin + delta)


## El ancla de una receta: el centro X/Z de su AABB conjunta, AL NIVEL DEL SUELO (el Y mínimo, no
## el centro) — el punto donde el mueble "pisa" la celda. Ver la cabecera.
func _ancla_de(nombres: PackedStringArray, todas: Dictionary, desplazamientos: Dictionary) -> Vector3:
	var caja := AABB()
	var primera := true
	for n: String in nombres:
		if not todas.has(n):
			push_warning("RenderMobiliario: no se encontró la pieza %s en el GLB" % n)
			continue
		var t: Transform3D = _transform_efectiva(n, todas, desplazamientos)
		var c: AABB = t * (todas[n]["malla"] as Mesh).get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false
	var centro: Vector3 = caja.get_center()
	return Vector3(centro.x, caja.position.y, centro.z)


## La distancia MÁXIMA de cualquier esquina de cualquier pieza de la receta al ancla — sirve para
## fijar el tamaño de cámara que la contiene entera. Es invariante a rotar alrededor del propio
## ancla en Y (que es justo lo único que hace esta herramienta con el objeto), así que basta
## calcularla UNA vez por receta, no una vez por rotación.
func _radio_de(
	nombres: PackedStringArray, todas: Dictionary, desplazamientos: Dictionary, ancla: Vector3
) -> float:
	var radio := 0.0
	for n: String in nombres:
		if not todas.has(n):
			continue
		var t: Transform3D = _transform_efectiva(n, todas, desplazamientos)
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


## Monta las piezas de una receta en `grupo`, YA centradas en el ancla (que queda en el origen
## local de `grupo` — así rotar `grupo.rotation.y` gira el conjunto alrededor de su propio ancla).
func _montar_receta(
	grupo: Node3D, nombres: PackedStringArray, todas: Dictionary, desplazamientos: Dictionary,
	ancla: Vector3
) -> void:
	_limpiar_grupo(grupo)
	for n: String in nombres:
		if not todas.has(n):
			continue
		var t: Transform3D = _transform_efectiva(n, todas, desplazamientos)
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
		var nombres: PackedStringArray = receta["nombres"]
		var desplazamientos: Dictionary = receta.get("desplazamientos", {})
		var ancla: Vector3 = _ancla_de(nombres, todas, desplazamientos)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(nombres, todas, desplazamientos, ancla))
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

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# 2) Renderiza las 4 rotaciones de cada receta y las guarda EN BRUTO (sin escalar aún: la
	# escala final se decide después de ver el mostrador a 0°).
	var crudos: Dictionary = {}
	for receta: Dictionary in recetas:
		var id_salida: String = receta["id_salida"]
		var nombres: PackedStringArray = receta["nombres"]
		var desplazamientos: Dictionary = receta.get("desplazamientos", {})
		_montar_receta(grupo, nombres, todas, desplazamientos, anclas[id_salida])
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

	print("[MOBILIARIO] hecho.")
	get_tree().quit()
