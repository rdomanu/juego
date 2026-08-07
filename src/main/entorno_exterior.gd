class_name EntornoExterior extends Node2D
## EntornoExterior — el marco NO JUGABLE alrededor del edificio (24×13): acera + calzada frente a
## la puerta oeste, el recinto/aparcamiento del control de acceso y el césped del futuro parque.
##
## Diseño: `design/art/entorno-exterior.md` (fase 1 — "mínima": calle + control + aparcamiento
## pintado, SIN props 3D todavía). Esta pieza es SOLO el suelo por código + los anclajes con nombre
## donde colgarán garita, barrera, coches, farolas y árboles en fases siguientes.
##
## ── CAPA (ADR-0005 — declarar SIEMPRE dónde cuelga un visual nuevo) ─────────────────────────────
## Esta capa NO entra en `MundoProfundo` (la bolsa de y-sort de lo que se apoya en el suelo JUGABLE
## — paredes, mobiliario, ventanillas, muñecos que andan; ver `Main._instanciar_mundo`): es FONDO
## PURO, fuera del rect 24×13, y no compite por profundidad con nada de dentro. Cuelga DIRECTAMENTE
## de `Main`, con `z_index = Z_CAPA` — más negativo que el suelo interior (`Main._crear_suelo`,
## z −3), así que queda SIEMPRE por debajo/detrás del edificio, se mueva la cámara como se mueva.
##
## ── LAS TRES GARANTÍAS DE "NO JUGABLE" (verificadas, no solo prometidas) ────────────────────────
##  1. SIN PICKING: nada en el juego pregunta por una celda de ESTA capa — el clic de construcción
##     (`Construccion.celda_de_punto`) y el menú contextual solo miran el modelo de Construcción,
##     que no sabe que este nodo existe.
##  2. SIN COLISIÓN: el `TileSet` de aquí NUNCA añade una capa de física (`add_physics_layer`) — sin
##     eso, Godot no genera cuerpo alguno para las celdas pintadas.
##  3. SIN NAVEGACIÓN: el polígono navegable lo bakea `NPCsFlujo._bakear_navegacion` en un
##     rectángulo FIJO (columnas [−2, `COLUMNAS`), filas [0, `FILAS`)) que este fichero no toca. Las
##     zonas de aquí caen FUERA de ese rectángulo — **salvo `RECT_RECINTO`**, cuyas dos columnas más
##     pegadas al edificio (−2 y −1) SÍ coinciden a propósito con la franja peatonal que YA existe
##     (`NPCsFlujo._punto_calle`, la cola exterior de siempre): es el mismo sitio donde la gente ya
##     entraba desde antes de este fichero, ahora con acera pintada debajo. El resto de zonas
##     (control, acera, calzada, césped) vive en columnas ≤ −3, fuera del rectángulo bakeado.
##
## ── EL RECORRIDO, EN CELDAS DEL PLANO LÓGICO (columna 0 = borde oeste del edificio) ──────────────
## CALLE (acera+calzada) → CONTROL (garita+barrera) → RECINTO (aparcamiento) → puerta (0, FILA_PUERTA).
## Todo alineado en la misma banda de filas, centrada en la puerta real
## (`NPCsFlujo.CELDA_PUERTA_EDIFICIO = Vector2i(0, 6)` — `FILA_PUERTA` de aquí DEBE coincidir).
##
## ── SIN randf() (regla del proyecto) ─────────────────────────────────────────────────────────────
## La variación de tono de cada baldosa sale de un HASH determinista de su celda
## (`_variacion_de_celda`, misma familia de fórmula que `Construccion._variacion_de_celda`): la
## misma celda pinta siempre igual, se recargue lo que se recargue.
##
## Nada de esto corre en `_process`: se construye UNA vez en `configurar()`, llamada por `Main`
## justo antes de `_crear_suelo()` (fondo antes que figura).

# ── Paleta apagada (design/art/entorno-exterior.md §4: "más apagado que el interior, para no robar
# atención") ──────────────────────────────────────────────────────────────────────────────────────
## Calzada: asfalto oscuro desaturado.
const COLOR_CALZADA := Color(0.24, 0.25, 0.27)
## Acera: hormigón claro, pero MÁS apagado que el suelo crema del interior (`Main.COLOR_SUELO`).
const COLOR_ACERA := Color(0.56, 0.57, 0.58)
## Explanada del recinto (entre control y puerta): hormigón, un punto más cálido que la acera para
## distinguirse de un vistazo sin competir.
const COLOR_RECINTO := Color(0.52, 0.51, 0.50)
## Las 5 plazas de aparcamiento son asfalto (mismo material que la calzada).
const COLOR_APARCAMIENTO := COLOR_CALZADA
## Césped del futuro parque: verde MUY desaturado (art-bible §6 rechaza el verde "folleto turístico").
const COLOR_CESPED := Color(0.34, 0.40, 0.33)
## Líneas de plaza: blancas para visita, azul institucional CNP muy atenuado para patrulla — un
## acento de color, no un segundo foco (el coche patrulla sigue siendo EL acento fuerte, §4).
const COLOR_LINEA_VISITA := Color(0.88, 0.88, 0.85, 0.9)
const COLOR_LINEA_PATRULLA := Color(0.30, 0.42, 0.62, 0.9)

## z_index de TODO lo de esta capa: más negativo que el suelo interior (`Main._crear_suelo`, −3), así
## que el edificio y su suelo SIEMPRE tapan a esto. (−4 queda libre para una futura sub-capa; −6 o
## menos quedaría para las fachadas de fondo de la fase 4 del diseño, aún sin construir.)
const Z_CAPA: int = -5

## Cuántas variaciones de tono por color (apagadas a propósito: `AMPLITUD_VARIACION`, ver abajo).
const VARIACIONES: int = 3
const AMPLITUD_VARIACION: float = 0.035

## Grosor (en px del plano lógico cuadrado) de las líneas pintadas de una plaza de aparcamiento.
const GROSOR_LINEA_APARCAMIENTO: float = 3.0

# ── El recorrido: fila eje + zonas (Rect2i en celdas del plano lógico; columnas negativas = oeste
# del edificio, filas negativas = norte) ────────────────────────────────────────────────────────────
## La fila de la puerta real del edificio (`Main._abrir_puerta_de_oficio`/`_montar_comisaria_inicial`
## deja la puerta de fachada en (0,6)) — DEBE seguir coincidiendo con
## `NPCsFlujo.CELDA_PUERTA_EDIFICIO.y`; si esa constante cambia, esta también.
const FILA_PUERTA: int = 6
## Medio ancho (en filas) de la banda del recorrido: filas [FILA_PUERTA−3, FILA_PUERTA+3] = 7 filas.
const SEMI_ANCHO_RECORRIDO: int = 3
## Alto (en filas) de esa banda, ya sumado — para no repetir `* 2 + 1` en cada `Rect2i` de abajo.
const ALTO_BANDA_RECORRIDO: int = SEMI_ANCHO_RECORRIDO * 2 + 1

## RECINTO: la explanada + aparcamiento, pegada al edificio (columnas −8..−1). Sus dos columnas más
## al este (−2, −1) coinciden con la franja peatonal que ya bakea `NPCsFlujo` — ver la nota de
## capa/navegación de la cabecera.
const RECT_RECINTO := Rect2i(-8, FILA_PUERTA - SEMI_ANCHO_RECORRIDO, 8, ALTO_BANDA_RECORRIDO)
## CONTROL: el cuello de botella de la garita+barrera, UNA columna (−9), banda más estrecha (3
## filas) — es un FILTRO, no una plaza abierta.
const RECT_CONTROL := Rect2i(-9, FILA_PUERTA - 1, 1, 3)
## ACERA: pegada al control por el oeste, la vereda peatonal de la calle.
const RECT_ACERA := Rect2i(-10, FILA_PUERTA - SEMI_ANCHO_RECORRIDO, 1, ALTO_BANDA_RECORRIDO)
## CALZADA: el tramo corto de calle (2 columnas), lo más al oeste del recorrido.
const RECT_CALZADA := Rect2i(-12, FILA_PUERTA - SEMI_ANCHO_RECORRIDO, 2, ALTO_BANDA_RECORRIDO)
## CÉSPED: flanco NORTE del recinto/control (filas −2..2) — no cruza la banda del recorrido
## (filas 3..9), así que ni coches ni peatones lo atraviesan nunca.
const RECT_CESPED := Rect2i(-9, -2, 7, 5)

## Las 5 plazas (3 patrulla + 2 visita, diseño §2/§5), de oeste a este dentro de `RECT_RECINTO`.
## `celda_ancla`: la celda donde clavar el futuro sprite del coche (fila sur de la plaza, mirando al
## pasillo) — misma idea que `AnclajeSprite`, para cuando el coche exista.
const PLAZAS_APARCAMIENTO: Array[Dictionary] = [
	{"id": &"visita_1", "tipo": &"visita", "rect": Rect2i(-7, 7, 1, 2), "celda_ancla": Vector2i(-7, 8)},
	{"id": &"visita_2", "tipo": &"visita", "rect": Rect2i(-6, 7, 1, 2), "celda_ancla": Vector2i(-6, 8)},
	{"id": &"patrulla_1", "tipo": &"patrulla", "rect": Rect2i(-5, 7, 1, 2), "celda_ancla": Vector2i(-5, 8)},
	{"id": &"patrulla_2", "tipo": &"patrulla", "rect": Rect2i(-4, 7, 1, 2), "celda_ancla": Vector2i(-4, 8)},
	{"id": &"patrulla_3", "tipo": &"patrulla", "rect": Rect2i(-3, 7, 1, 2), "celda_ancla": Vector2i(-3, 8)},
]

## Anclas con nombre para props futuros — misma técnica que `AnclajeSprite` del mobiliario: cuando
## el PNG exista, se posiciona con `punto_pantalla_de_ancla(celda)` y se ancla con
## `AnclajeSprite.aplicar(sprite, paso, celdas)` igual que cualquier mueble. NINGUNA de estas celdas
## se pinta ni se instancia todavía (fase 1 es solo suelo).
const ANCLA_GARITA := Vector2i(-9, 6)
## La barrera cae en el borde ENTRE control y recinto (columna −8, el primer paso ya dentro): el
## brazo corta el paso norte-sur de esa columna hasta que se levanta.
const ANCLA_BARRERA := Vector2i(-8, 6)
const ANCLAS_FAROLAS: Array[Vector2i] = [Vector2i(-8, 3), Vector2i(-8, 9), Vector2i(-3, 6)]
const ANCLAS_ARBOLES: Array[Vector2i] = [
	Vector2i(-8, -1), Vector2i(-4, -1), Vector2i(-8, 1), Vector2i(-4, 1),
]
const ANCLA_BANCO := Vector2i(-6, 0)

var _tam_celda: int = 40
var _origen: Vector2 = Vector2.ZERO
var _capa_suelo: TileMapLayer = null
var _capa_marcas: Node2D = null
var _fuentes: Dictionary[String, int] = {}


## Construye TODO el visual (una sola vez — nunca por frame). `columnas`/`filas` son las del rect
## JUGABLE (`Main.COLUMNAS`/`Main.FILAS`): solo se usan para el aviso de más abajo, nunca para
## decidir dónde pintar (las zonas ya están fijas en los `RECT_*` de arriba).
func configurar(tam_celda: int, origen: Vector2, columnas: int, filas: int) -> void:
	_tam_celda = tam_celda
	_origen = origen
	_avisar_si_invade_lo_jugable(columnas, filas)
	z_index = Z_CAPA
	_capa_suelo = TileMapLayer.new()
	_capa_suelo.name = "SueloExterior"
	_capa_suelo.tile_set = _crear_tileset()
	_capa_suelo.transform = Proyeccion.transformada(origen)
	_capa_suelo.z_index = Z_CAPA
	add_child(_capa_suelo)
	_pintar_rect(RECT_CALZADA, COLOR_CALZADA)
	_pintar_rect(RECT_ACERA, COLOR_ACERA)
	_pintar_rect(RECT_RECINTO, COLOR_RECINTO)
	_pintar_rect(RECT_CESPED, COLOR_CESPED)
	# El control se pinta con el mismo hormigón que el recinto: es el mismo pavimento, solo que
	# más estrecho por la garita/barrera que lo flanquea (fase 2).
	_pintar_rect(RECT_CONTROL, COLOR_RECINTO)
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		_pintar_rect(plaza["rect"], COLOR_APARCAMIENTO)
	_capa_marcas = Node2D.new()
	_capa_marcas.name = "MarcasAparcamiento"
	_capa_marcas.z_index = Z_CAPA
	add_child(_capa_marcas)
	_dibujar_marcas_aparcamiento()


## El punto de PANTALLA de una celda de esta capa (misma cuenta que `Construccion.centro_en_pantalla`
## — para cuando un prop real cuelgue de una de las `ANCLA_*`).
func punto_pantalla_de_ancla(celda: Vector2i) -> Vector2:
	return _origen + Proyeccion.centro_iso(celda)


## El `TileMapLayer` de suelo, para que sondas/tests puedan leer `get_used_cells()` sin duplicar la
## lista de celdas pintadas en dos sitios.
func capa_suelo() -> TileMapLayer:
	return _capa_suelo


## Regresión de rect: ninguna zona de este fichero puede tocar el rect jugable, y ninguna plaza
## puede salirse del recinto. Aviso ruidoso (no silencioso) — misma política que el resto del
## proyecto ante un plano inicial roto.
func _avisar_si_invade_lo_jugable(columnas: int, filas: int) -> void:
	var rect_jugable := Rect2i(0, 0, columnas, filas)
	for rect: Rect2i in [RECT_RECINTO, RECT_CONTROL, RECT_ACERA, RECT_CALZADA, RECT_CESPED]:
		if rect.intersects(rect_jugable):
			push_error("EntornoExterior: la zona %s invade el rect jugable %s" % [rect, rect_jugable])
	for plaza: Dictionary in PLAZAS_APARCAMIENTO:
		if not RECT_RECINTO.encloses(plaza["rect"]):
			push_error("EntornoExterior: la plaza '%s' se sale de RECT_RECINTO" % plaza["id"])


func _pintar_rect(rect: Rect2i, color: Color) -> void:
	var fuente_id: int = _fuente_de(color)
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		for y: int in range(rect.position.y, rect.position.y + rect.size.y):
			var celda := Vector2i(x, y)
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


## `VARIACIONES` baldosas de color plano, apenas aclaradas/oscurecidas (`AMPLITUD_VARIACION`) —
## mismo espíritu que `Construccion._pintar_baldosa`, sin degradado ni junta: aquí el suelo tiene que
## leerse LISO y discreto, no como una textura del interior (nunca debe robar atención — §4).
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


## Variación de tono determinista por celda (SIN `randf`, regla del proyecto): mismo hash entero que
## `Construccion._variacion_de_celda` — la misma celda pinta SIEMPRE igual, se recargue lo que se
## recargue.
static func _variacion_de_celda(celda: Vector2i) -> int:
	var h: int = celda.x * 73856093 ^ celda.y * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return posmod(h, VARIACIONES)


## Las líneas pintadas de las 5 plazas: un divisorio en el borde OESTE de cada plaza (color de SU
## tipo) + uno final en el borde ESTE de la última, para cerrar el conjunto por los dos lados.
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


## Una línea PINTADA EN EL SUELO (no un mueble de pie — por eso se proyecta a mano en vez de colgar
## de un nodo con `Proyeccion.transformada`, igual que hace `NPCsFlujo._bakear_navegacion` con las
## franjas de muro): un cuadrilátero fino en el plano lógico cuadrado, con sus 4 vértices ya
## proyectados a pantalla y el `_origen` de esta capa ya sumado.
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
