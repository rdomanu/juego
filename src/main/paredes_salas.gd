class_name ParedesSalas extends Node2D
## ParedesSalas — las salas se VEN como habitaciones, no como rectángulos de color en el suelo.
##
## Petición del usuario (2026-07-30): *"la sala de descanso tiene que ir con paredes, si no todo el
## mundo ve a los funcionarios descansando, es raro"* + *"el diseño de la comisaría como theme
## hospital"*. Fase VISUAL (el usuario eligió expresamente "que se vean primero"): dibuja el
## perímetro de cada sala con un hueco en la puerta, pero **NO bloquea el paso** — eso es una fase
## posterior aparte (colisión/navegación), que este nodo no toca.
##
## Solo LEE Construcción (rect + tipo + puerta de cada sala) y el catálogo de Datos para el color —
## nunca escribe en el modelo (ADR-0004: el visual refleja el modelo, jamás al revés).
##
## Rendimiento (regla del proyecto — cero redibujado por frame): sin `_process`. `actualizar()` la
## llama Main desde el hook de cambio de layout (`_al_cambiar_layout`, disparado por
## `Construccion._refrescar_visual` en cada construcción/demolición/movimiento/carga — nunca por
## frame) y compara una FIRMA de lo dibujado; si no cambió, ni se recalculan tramos ni se llama a
## `queue_redraw()`. Mismo patrón DIFF que `npcs_flujo._firma` / `luces_objetos._firma`.

## Grosor de la línea de pared, en píxeles (encargo: "gruesa, 3-4 px"). Con el isométrico se usa
## para las jambas y como respaldo si algún tramo llegara sin altura.
const GROSOR_PARED: float = 4.0
## ── PAREDES CON ALTURA (ISOMÉTRICO, 2026-07-30) ────────────────────────────────────────────────
## Alto de la cara de una pared, en píxeles. 34 px: más alto que un muñeco (22 px) para que se lea
## como pared y no como bordillo, y menos que el alto del rombo (40) para que no ahogue el dibujo.
const ALTO_PARED: float = 34.0
## Grosor del remate superior de la pared (la franja clara de arriba, que es lo que da la sensación
## de espesor — se ve claramente en `capturas/entorno.PNG`).
const GROSOR_REMATE: float = 3.0
## Alto de una pared CERCANA a la cámara. 10 px: se ve el pretil y las esquinas enlazan, pero no
## llega ni a la cintura de un muñeco (22 px), así que no tapa a nadie de dentro de la sala.
const ALTO_PARED_CERCANA: float = 10.0
## Largo de cada jamba (marco corto de puerta) — sobrio, sin arte elaborado (andamio hasta el art bible).
const LARGO_JAMBA: float = 10.0
## Mismo centinela que `Construccion.CELDA_NULA_PUERTA` (-1,-1), referenciado por VALOR: el proyecto
## tipa estas inyecciones como `Node` genérico (mismo criterio que `luces_objetos.gd` /
## `modo_construccion.gd`), así que no se tipa `_construccion` como `Construccion` para leer su
## constante directamente.
const CELDA_SIN_PUERTA := Vector2i(-1, -1)
## Color de los MUROS LIBRES (2026-07-30 — Fase A del modelo Prison Architect: paredes primero,
## zonas después). Gris de obra NEUTRO a propósito: a diferencia de `_color_de_pared`, un muro libre
## no pertenece a ninguna sala, así que no toma el tono de ningún servicio.
const COLOR_MURO_LIBRE := Color(0.55, 0.55, 0.52)
## Color de la FACHADA del edificio (2026-07-30): los muros fijos que son la comisaría en sí. Tono
## de LADRILLO, distinto del gris de obra de un tabique que has levantado tú — de un vistazo se
## distingue lo que es estructura (y no se puede tocar) de lo que has construido.
const COLOR_FACHADA := Color(0.62, 0.44, 0.36)
## Grosor de la línea de VENTANA (FASE D, 2026-07-30): más fina que `GROSOR_PARED` — se lee como
## cristal, no como pared maciza.
const GROSOR_VENTANA: float = 2.0
## Color de una VENTANA (tono claro/azulado, a propósito distinto del gris neutro del tabique — se
## lee como cristal: se ve a través pero NO se pasa, fase E).
const COLOR_VENTANA := Color(0.62, 0.80, 0.95, 0.85)
## Fracción de cada extremo del tramo que sigue pintándose como pared cuando es una PUERTA — el resto
## (el centro) queda como hueco. 0.25 dueño de cada lado deja un hueco del 50% de la celda, ancho de
## sobra para que se lea "por aquí se pasa".
const PROPORCION_STUB_PUERTA: float = 0.25

var _construccion: Node = null
var _tam_celda: int = 40
var _desplazamiento: Vector2 = Vector2.ZERO
## Firma de lo último dibujado ("sala:rect:tipo:puerta" por sala, unidas): si no cambia entre dos
## llamadas a `actualizar()`, no se toca nada (ni cálculo ni `queue_redraw`).
var _firma: String = ""
## Tramos de pared cacheados por `_recalcular_tramos()` — `_draw()` SOLO los pinta; el trabajo de
## consultar a Construcción ocurre una vez por cambio de layout, nunca dentro de `_draw()`.
var _tramos: Array[Dictionary] = []
## Jambas (el detalle de puerta) cacheadas igual que los tramos.
var _jambas: Array[Dictionary] = []


func _draw() -> void:
	# Los tramos ya vienen ordenados de FONDO a FRENTE por `_recalcular_tramos` — en isométrico el
	# orden de pintado ES la profundidad, y una pared del fondo pintada después taparía a la de
	# delante.
	for tramo: Dictionary in _tramos:
		var desde: Vector2 = tramo["desde"]
		var hasta: Vector2 = tramo["hasta"]
		var color: Color = tramo["color"]
		var alto: float = tramo.get("alto", ALTO_PARED)
		if alto <= 0.0:
			draw_line(desde, hasta, color, tramo.get("grosor", GROSOR_PARED) as float, true)
			continue
		# TODAS las paredes suben; lo que cambia es CUÁNTO (ver `_cara_de_arista`).
		var subir := Vector2(0.0, -alto)
		draw_colored_polygon(
			PackedVector2Array([desde, hasta, hasta + subir, desde + subir]), color
		)
		# Remate claro en el canto de arriba (el espesor) y línea oscura abajo, que la asienta.
		draw_line(desde + subir, hasta + subir, color.lightened(0.35), GROSOR_REMATE, true)
		draw_line(desde, hasta, color.darkened(0.4), 1.5, true)
	for jamba: Dictionary in _jambas:
		draw_line(
			jamba["desde"] as Vector2, jamba["hasta"] as Vector2, jamba["color"] as Color,
			GROSOR_PARED, true
		)


## Engancha las referencias y hace el primer dibujado. La comisaría inicial (`_montar_comisaria_
## inicial`) ya tiene salas construidas ANTES de que Main cablee el hook de layout (mismo caso ya
## documentado en `Main._actualizar_etiquetas_salas`), así que este primer `actualizar()` es
## necesario para que esas salas de arranque no se queden sin pared hasta la primera compra.
func configurar(construccion: Node, tam_celda: int, desplazamiento: Vector2) -> void:
	_construccion = construccion
	_tam_celda = tam_celda
	_desplazamiento = desplazamiento
	# Por ENCIMA del suelo/salas: la capa de Construcción (TileMapLayer "Salas" + "Elementos") cuelga
	# de un Node que NO es CanvasItem, así que esos nodos son raíces de canvas con z_index 0 por
	# defecto (mismo razonamiento ya documentado en `Main._crear_capa_etiquetas_sala`). Con z_index 0
	# aquí TAMBIÉN, el desempate entre iguales lo decide el ORDEN EN EL ÁRBOL: Main añade este nodo
	# DESPUÉS de instanciar Construcción y montar la comisaría inicial, así que las paredes se pintan
	# encima del relleno de sala. Por DEBAJO de la gente/etiquetas (z_index 1) y de las luces
	# (z_index 2) por tener un z_index menor — ahí el orden en el árbol ya no importa.
	# 🐛 Corregido 2026-07-30 (el usuario: "las paredes no las puedo poner en mitad de una sala, solo
	# en los bordes"). SÍ se podían poner —el modelo lo permitía y hay test que lo prueba—, pero NO SE
	# VEÍAN: con z_index 0 el suelo de las salas (TileMapLayer) se dibuja ENCIMA, así que un muro
	# interior quedaba tapado y solo asomaban los del borde, donde el suelo ya termina. Es el mismo
	# problema que ya tuvieron los NPCs ("se dibujan DEBAJO de las salas al cruzarlas").
	# Orden de capas: suelo (0) < PAREDES (1) < gente (2) < luces (3).
	z_index = 1
	actualizar()


## Recalcula las paredes SOLO si el layout cambió de verdad (patrón DIFF de firma). Main lo llama
## desde `_al_cambiar_layout` — el mismo hook que ya usan el re-bake de navegación de los NPCs y las
## etiquetas de sala — nunca desde un `_process`.
func actualizar() -> void:
	if _construccion == null:
		return
	var firma: String = _firma_actual()
	if firma == _firma:
		return
	_firma = firma
	_recalcular_tramos()
	queue_redraw()


## Las salas construidas, en los TRES tipos válidos (mismo patrón que usa Main para "todas las
## salas": no existe un getter único en Construcción, así que se combinan los tres — const-006).
func _todas_las_salas() -> Array[StringName]:
	return (
		_construccion.salas_de_tipo("espera") + _construccion.salas_de_tipo("oficina")
		+ _construccion.salas_de_tipo("descanso")
	)


## Una línea por sala: rect + tipo (color) + puerta. Si ninguna cambió, la firma entera es idéntica.
func _firma_actual() -> String:
	var partes: PackedStringArray = PackedStringArray()
	for sala_id: StringName in _todas_las_salas():
		var rect: Rect2i = _construccion.rect_de_sala(sala_id)
		var puerta: Vector2i = _construccion.puerta_de_sala(sala_id)
		# El "P"/"-" final es si esa sala lleva paredes: las paredes son OPCIONALES por sala (decision
		# del usuario 2026-07-30), asi que ponerlas o quitarlas tiene que disparar un redibujado.
		partes.append("%s:%d,%d,%d,%d:%s:%d,%d:%s" % [
			sala_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			_construccion.tipo_de_sala(sala_id), puerta.x, puerta.y,
			"P" if _construccion.sala_con_paredes(sala_id) else "-",
		])
	# Los MUROS LIBRES (2026-07-30) entran en la firma: pintar o demoler uno tiene que disparar el
	# redibujado igual que construir/demoler una sala. Se ORDENAN antes de unir — `Construccion.muros()`
	# no promete un orden estable entre llamadas, y sin orden estable la firma podría "cambiar" (y
	# redibujar de más) aunque el CONJUNTO de muros sea idéntico al de la vez anterior.
	# FASE D (2026-07-30): el TIPO de cada muro (tabique/puerta/ventana) entra en la firma junto a su
	# clave — sin esto, convertir un tabique en puerta con `fijar_tipo_de_muro` no cambia el CONJUNTO
	# de claves (la arista sigue siendo la misma), así que la firma quedaría idéntica y el cambio
	# jamás se pintaría.
	var muros: Array[String] = _construccion.muros()
	muros.sort()
	var muros_con_tipo: PackedStringArray = PackedStringArray()
	for clave: String in muros:
		muros_con_tipo.append(clave + ":" + String(_construccion.tipo_muro_de_clave(clave)))
	partes.append("MUROS:" + ",".join(muros_con_tipo))
	return "|".join(partes)


## Reconstruye `_tramos` y `_jambas` desde cero leyendo el modelo. Es la parte "cara" (recorre el
## perímetro celda a celda de cada sala), pero solo corre cuando `actualizar()` ya detectó un cambio
## real — nunca por frame.
func _recalcular_tramos() -> void:
	_tramos.clear()
	_jambas.clear()
	# Solo las salas que TIENEN paredes (decision del usuario 2026-07-30): "hay a veces que no quiero
	# paredes y solo quiero delimitar las salas... no me importa que no tengan paredes documentacion y
	# odac ni tampoco la sala de espera pero si la de descanso". Delimitar una zona y AISLARLA son dos
	# cosas distintas: Documentacion, ODAC y las esperas se leen bien en planta diafana; la de descanso
	# se cierra porque su razon de ser es que no se vea a los funcionarios de cafe desde la cola.
	var salas: Array[StringName] = []
	for sala_id: StringName in _todas_las_salas():
		if _construccion.sala_con_paredes(sala_id):
			salas.append(sala_id)
	# 1) Las unidades de perímetro que son HUECO DE PUERTA, de TODAS las salas — con prioridad
	#    absoluta sobre cualquier pared: una puerta nunca queda tapiada, ni siquiera por la pared de
	#    la sala vecina si esa pared cae exactamente sobre el mismo tramo compartido.
	var huecos: Dictionary = {}
	for sala_id: StringName in salas:
		var clave: String = _clave_de_puerta(sala_id)
		if clave != "":
			huecos[clave] = true
	# 2) Cada sala aporta las unidades de SU perímetro (celda a celda), salvo las de hueco. La
	#    PRIMERA sala que reclama una unidad se la queda — así dos salas pegadas que comparten un
	#    tramo de pared lo pintan UNA sola vez (se evita el doble trazo en vez de solaparlo).
	var duenio: Dictionary = {}      # clave de unidad -> color de quien la reclamó primero
	var geometria: Dictionary = {}   # clave de unidad -> {"desde": Vector2, "hasta": Vector2}
	for sala_id: StringName in salas:
		var color: Color = _color_de_pared(sala_id)
		for unidad: Dictionary in _unidades_de_perimetro(sala_id):
			var clave: String = unidad["clave"]
			if huecos.has(clave) or duenio.has(clave):
				continue
			duenio[clave] = color
			geometria[clave] = unidad
	for clave: String in geometria:
		var unidad: Dictionary = geometria[clave]
		var tramo: Dictionary = {
			"desde": unidad["desde"], "hasta": unidad["hasta"], "color": duenio[clave],
		}
		tramo.merge(_cara_de_arista(unidad["detras"]))
		_tramos.append(tramo)
	# 3) Las jambas: un detalle sutil por cada puerta real (celda distinta de CELDA_SIN_PUERTA).
	for sala_id: StringName in salas:
		_jambas.append_array(_jambas_de_puerta(sala_id))
	# 4) Los MUROS LIBRES (2026-07-30 — Fase A: paredes primero, zonas después): mismo grosor y
	#    estilo que las paredes de sala, pero con su propio color neutro — no pertenecen a ninguna
	#    sala. Si un muro libre cae justo en el mismo tramo físico que ya pintó una pared de sala
	#    (`duenio`), NO se repinta encima — `Construccion.clave_de_muro` usa un convenio col:row para
	#    las aristas horizontales que NO coincide textualmente con el de este fichero (row:col,
	#    heredado de `_unidad_h`); `_clave_equivalente_en_paredes` traduce entre los dos para comparar
	#    la MISMA arista física. Los huecos de puerta NO se comprueban aquí a propósito: un muro libre
	#    es una entidad real del modelo (ADR-0004 — el visual refleja el modelo), así que si el
	#    jugador construye uno sobre el hueco de una puerta, SE VE (aunque sea una rareza jugable).
	for clave_construccion: String in _construccion.muros():
		if duenio.has(_clave_equivalente_en_paredes(clave_construccion)):
			continue
		var geo: Dictionary = _geometria_de_muro_libre(clave_construccion)
		if geo.is_empty():
			continue
		# FASE D (2026-07-30): puertas y ventanas se DIBUJAN distinto de un tabique — el visual
		# refleja el tipo del modelo (ADR-0004), no solo si hay o no arista.
		var tipo: StringName = _construccion.tipo_muro_de_clave(clave_construccion)
		var fija: bool = _construccion.es_muro_fijo(clave_construccion)
		var cara: Dictionary = _cara_de_arista(geo["detras"], fija)
		if tipo == _construccion.PUERTA:
			_agregar_puerta_libre(
				geo["desde"], geo["hasta"], cara, COLOR_FACHADA if fija else COLOR_MURO_LIBRE
			)
		elif tipo == _construccion.VENTANA:
			# La ventana tambien SUBE (es pared), pero en color cristal translucido: se ve a traves,
			# no se pasa (fase E). Si esta recortada por la regla de la camara, queda la linea fina.
			var ventana: Dictionary = {
				"desde": geo["desde"], "hasta": geo["hasta"],
				"color": COLOR_VENTANA, "grosor": GROSOR_VENTANA,
			}
			ventana.merge(cara)
			_tramos.append(ventana)
		else:
			var libre: Dictionary = {
				"desde": geo["desde"], "hasta": geo["hasta"],
				"color": COLOR_FACHADA if fija else COLOR_MURO_LIBRE,
			}
			libre.merge(cara)
			_tramos.append(libre)
	# 5) ORDEN POR PROFUNDIDAD (ISOMÉTRICO, 2026-07-30). Todas las paredes salen de UN solo `_draw`,
	#    así que aquí el orden de la lista ES el orden de dibujo: lo que se pinta después, tapa. Se
	#    ordenan de FONDO a FRENTE por el punto más bajo de su base — sin esto, una pared del fondo
	#    calculada más tarde se pintaría encima de una que está delante de ella, y el dibujo se
	#    leería del revés. (`_tramos` se recalcula solo al cambiar el layout, nunca por frame, así
	#    que ordenar aquí no cuesta nada en partida.)
	_tramos.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return maxf(a["desde"].y, a["hasta"].y) < maxf(b["desde"].y, b["hasta"].y)
	)


## Traduce una clave de `Construccion.muros()` (convenio "v:col:row" / "h:col:row") a la clave
## EQUIVALENTE de este fichero, para poder comparar contra `duenio` (que usa "v:col:row" para
## verticales — mismo orden, coincide — pero "h:row:col" para horizontales, heredado de `_unidad_h`/
## `_clave_de_puerta`). Solo se intercambian los dos números en el caso "h"; devuelve "" si la clave
## no tiene el formato esperado (nunca debería pasar — `Construccion` es la única que las genera).
func _clave_equivalente_en_paredes(clave_construccion: String) -> String:
	var partes: PackedStringArray = clave_construccion.split(":")
	if partes.size() != 3:
		return ""
	if partes[0] == "v":
		return clave_construccion   # mismo convenio col:row en los dos ficheros — no hace falta tocar
	return "h:%s:%s" % [partes[2], partes[1]]   # "h": Construccion guarda col:row; aquí es row:col


## La geometría (en píxeles de MUNDO) de una arista con la clave de `Construccion.muros()`
## ("v:col:row" o "h:col:row" — ver `Construccion.clave_de_muro`). `{}` si la clave es inválida.
func _geometria_de_muro_libre(clave: String) -> Dictionary:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return {}
	var a: int = int(partes[1])
	var b: int = int(partes[2])
	if partes[0] == "v":
		# "v:col:row" — arista del eje Y en la columna `a`, del borde de fila `b` al `b + 1`.
		# (En pantalla ya no es vertical: baja hacia la IZQUIERDA. El nombre "v" se conserva
		# porque es la clave del MODELO, que no sabe nada de proyecciones.)
		return {
			"desde": _esquina(a, b), "hasta": _esquina(a, b + 1),
			"detras": Vector2i(a - 1, b),
		}
	if partes[0] == "h":
		# "h:col:row" — arista del eje X en la fila `b`, de la columna `a` a la `a + 1`.
		# (En pantalla baja hacia la DERECHA.)
		return {
			"desde": _esquina(a, b), "hasta": _esquina(a + 1, b),
			"detras": Vector2i(a, b - 1),
		}
	return {}


## Dibuja el HUECO de una PUERTA en un muro libre (FASE D, 2026-07-30): dos tramos cortos de pared en
## los extremos del tramo —para que la arista siga leyéndose como el mismo tabique— dejando un hueco
## central por el que se pasa, más dos jambas cortas marcando el marco (mismo recurso `_jamba` que ya
## usan las puertas de sala). A diferencia de una puerta de sala, un muro libre no pertenece a
## ninguna habitación — no hay un "lado de dentro" que priorizar—, así que las dos jambas apuntan al
## MISMO lado (perpendicular al tabique): es un detalle decorativo, no una pista de navegación.
func _agregar_puerta_libre(
	desde: Vector2, hasta: Vector2, cara: Dictionary, color: Color = COLOR_MURO_LIBRE
) -> void:
	var direccion: Vector2 = hasta - desde
	var inicio_hueco: Vector2 = desde + direccion * PROPORCION_STUB_PUERTA
	var fin_hueco: Vector2 = hasta - direccion * PROPORCION_STUB_PUERTA
	var izq: Dictionary = {"desde": desde, "hasta": inicio_hueco, "color": color}
	izq.merge(cara)
	_tramos.append(izq)
	var der: Dictionary = {"desde": fin_hueco, "hasta": hasta, "color": color}
	der.merge(cara)
	_tramos.append(der)
	var perpendicular: Vector2 = direccion.normalized().rotated(PI / 2.0) * LARGO_JAMBA
	_jambas.append(_jamba(inicio_hueco, perpendicular, color))
	_jambas.append(_jamba(fin_hueco, perpendicular, color))


## Las unidades (una por celda) del perímetro de una sala: 4 lados, sin duplicar las esquinas — el
## mismo criterio de "en_borde" que usa `Construccion._puerta_automatica`.
func _unidades_de_perimetro(sala_id: StringName) -> Array[Dictionary]:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var unidades: Array[Dictionary] = []
	for x: int in range(rect.position.x, rect.end.x):
		unidades.append(_unidad_h(rect.position.y, x))
		unidades.append(_unidad_h(rect.end.y, x))
	for y: int in range(rect.position.y, rect.end.y):
		unidades.append(_unidad_v(rect.position.x, y))
		unidades.append(_unidad_v(rect.end.x, y))
	return unidades


## Info de la puerta de una sala (`{}` si no tiene una puerta válida en su perímetro). Determinismo
## en las ESQUINAS (una celda de esquina toca DOS lados a la vez, p. ej. `rect.position` toca el
## lado IZQUIERDO y el de ARRIBA): se prioriza IZQUIERDA > DERECHA > ARRIBA > ABAJO. Documentado
## aquí porque lo pide la tarea — al jugador le da igual (el hueco cae en la esquina de cualquier
## forma), pero el código necesita una única respuesta estable.
func _info_puerta(sala_id: StringName) -> Dictionary:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var puerta: Vector2i = _construccion.puerta_de_sala(sala_id)
	if puerta == CELDA_SIN_PUERTA:
		return {}
	if puerta.x == rect.position.x:
		return {"lado": "izquierda", "rect": rect, "puerta": puerta}
	if puerta.x == rect.end.x - 1:
		return {"lado": "derecha", "rect": rect, "puerta": puerta}
	if puerta.y == rect.position.y:
		return {"lado": "arriba", "rect": rect, "puerta": puerta}
	if puerta.y == rect.end.y - 1:
		return {"lado": "abajo", "rect": rect, "puerta": puerta}
	return {}   # la puerta no cae en el perímetro (dato corrupto) -> sin hueco ni jambas aquí


## La unidad de perímetro que ocupa la puerta de la sala (`""` si no tiene puerta válida).
func _clave_de_puerta(sala_id: StringName) -> String:
	var info: Dictionary = _info_puerta(sala_id)
	if info.is_empty():
		return ""
	var rect: Rect2i = info["rect"]
	var puerta: Vector2i = info["puerta"]
	match info["lado"]:
		"izquierda":
			return "v:%d:%d" % [rect.position.x, puerta.y]
		"derecha":
			return "v:%d:%d" % [rect.end.x, puerta.y]
		"arriba":
			return "h:%d:%d" % [rect.position.y, puerta.x]
		_:
			return "h:%d:%d" % [rect.end.y, puerta.x]   # "abajo"


## Dos jambas cortas a los dos lados del hueco de la puerta (marco sobrio, nada de arte elaborado —
## andamio declarado hasta que llegue el art bible), apuntando hacia DENTRO de la sala.
func _jambas_de_puerta(sala_id: StringName) -> Array[Dictionary]:
	var info: Dictionary = _info_puerta(sala_id)
	if info.is_empty():
		return []
	var rect: Rect2i = info["rect"]
	var puerta: Vector2i = info["puerta"]
	var color: Color = _color_de_pared(sala_id)
	# ISOMÉTRICO: los puntos salen de `_esquina` y las direcciones "hacia dentro" pasan por
	# `_direccion` — en rombos, "hacia dentro" ya no es horizontal ni vertical en pantalla.
	if info["lado"] == "izquierda":
		var dentro: Vector2 = _direccion(Vector2(LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.position.x, puerta.y), dentro, color),
			_jamba(_esquina(rect.position.x, puerta.y + 1), dentro, color),
		]
	if info["lado"] == "derecha":
		var dentro: Vector2 = _direccion(Vector2(-LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.end.x, puerta.y), dentro, color),
			_jamba(_esquina(rect.end.x, puerta.y + 1), dentro, color),
		]
	if info["lado"] == "arriba":
		var dentro: Vector2 = _direccion(Vector2(0.0, LARGO_JAMBA))
		return [
			_jamba(_esquina(puerta.x, rect.position.y), dentro, color),
			_jamba(_esquina(puerta.x + 1, rect.position.y), dentro, color),
		]
	var dentro_abajo: Vector2 = _direccion(Vector2(0.0, -LARGO_JAMBA))   # "abajo"
	return [
		_jamba(_esquina(puerta.x, rect.end.y), dentro_abajo, color),
		_jamba(_esquina(puerta.x + 1, rect.end.y), dentro_abajo, color),
	]


## Mismo cálculo que el privado `Construccion._color_de_sala` (color base por servicio + tono por
## tipo), DUPLICADO aquí a propósito: es privado (prefijo `_`) y esta tarea tiene prohibido tocar
## `construccion.gd`. No es una paleta nueva — es la MISMA, solo oscurecida para que la pared
## "pertenezca" a su sala. Si esa paleta cambia allí, hay que replicar el cambio aquí también.
func _color_de_pared(sala_id: StringName) -> Color:
	var tipo_sala: Resource = Datos.obtener(&"TipoSala", _construccion.tipo_de_sala(sala_id))
	if tipo_sala == null:
		return Color(0.1, 0.1, 0.1)   # no debería pasar (Datos ya avisó) — gris de emergencia
	var base := Color(0.30, 0.38, 0.55)
	if tipo_sala.servicio == "ODAC":
		base = Color(0.55, 0.40, 0.22)
	elif tipo_sala.servicio == "Comun":
		base = Color(0.35, 0.37, 0.40)
	if tipo_sala.tipo == "espera":
		base = base.lerp(Color(0.22, 0.24, 0.27), 0.45)
	return base.darkened(0.4)


## Un tramo del eje X (grid-line en la fila `fila_gridline`, celda `celda_x`). En pantalla baja
## hacia la derecha; en el modelo sigue siendo la arista "h" de siempre.
func _unidad_h(fila_gridline: int, celda_x: int) -> Dictionary:
	return {
		"clave": "h:%d:%d" % [fila_gridline, celda_x],
		"desde": _esquina(celda_x, fila_gridline), "hasta": _esquina(celda_x + 1, fila_gridline),
		"detras": Vector2i(celda_x, fila_gridline - 1),
	}


## Un tramo del eje Y (grid-line en la columna `columna_gridline`, celda `celda_y`). En pantalla
## baja hacia la izquierda; en el modelo sigue siendo la arista "v" de siempre.
func _unidad_v(columna_gridline: int, celda_y: int) -> Dictionary:
	return {
		"clave": "v:%d:%d" % [columna_gridline, celda_y],
		"desde": _esquina(columna_gridline, celda_y), "hasta": _esquina(columna_gridline, celda_y + 1),
		"detras": Vector2i(columna_gridline - 1, celda_y),
	}


## ── LA REGLA DE LAS PAREDES QUE TAPAN (ISOMÉTRICO, 2026-07-30) ─────────────────────────────────
##
## El problema, en llano: una pared con altura sube hacia ARRIBA en pantalla, así que tapa lo que
## tiene DETRÁS (más al fondo). Las paredes del fondo de una sala tapan la calle, y eso está bien;
## pero las del lado de la cámara tapan el INTERIOR de la sala, y entonces no ves ni a tu gente ni
## tus mostradores: ves una fila de muros.
##
## Cómo lo resuelven Theme Hospital y Two Point: las paredes del lado cercano a la cámara se
## dibujan MUCHO MÁS BAJAS que las del fondo. Siguen ahí —marcan el recinto, y en las esquinas
## enlazan con las altas— pero como no llegan ni a la cintura de un muñeco, no tapan a nadie.
##
## La regla, sin excepciones: **si lo que hay DETRÁS de esta pared es una sala, es una pared
## CERCANA y va baja; si no, va a altura completa**. Sale sola de la geometría, sin marcar nada a
## mano: las dos paredes del fondo de una sala tienen detrás la calle (→ altas, hacen de fondo) y
## las dos del frente tienen detrás la propia sala (→ bajas, hacen de pretil). Un muro suelto en
## mitad de la nada tiene detrás suelo vacío, así que va alto, que es lo que se espera de un
## tabique aislado.
##
## ⚠️ Se probó ANTES a dibujar la pared cercana por su cara EXTERIOR (colgando hacia ABAJO en
## pantalla, imitando la perspectiva 3D de Two Point). El usuario lo cazó al momento —*"unas salen
## bien y otras como apuntando debajo del suelo, raro"*— y tenía razón: eso funciona con una cámara
## 3D de verdad, que ve el muro por encima, pero en 2D plano una cara que baja se lee como una
## solapa colgando, y encima descuadra las esquinas donde se junta con una pared que sube. Bajar
## la altura es la solución 2D, y es exactamente lo que hacía Theme Hospital.
##
## Devuelve `{"alto": float}` — listo para fundirse en el diccionario del tramo.
func _cara_de_arista(detras: Vector2i, fija: bool = false) -> Dictionary:
	# La FACHADA del edificio (2026-07-30) se mide contra el EDIFICIO, no contra las salas: sus dos
	# lados del fondo (arriba e izquierda) tienen detrás la calle y van altos —son el telón de la
	# comisaría—, y los dos de delante tienen detrás el interior entero, así que van bajos. Sin esta
	# distinción, la fachada de abajo taparía la comisaría completa.
	var cercana: bool = (
		_celda_en_edificio(detras) if fija else _construccion.sala_en(detras) != &""
	)
	return {"alto": ALTO_PARED_CERCANA if cercana else ALTO_PARED}


## ¿Esa celda cae dentro de la rejilla del edificio? (espeja `Construccion._celda_en_edificio`,
## que es privada).
func _celda_en_edificio(celda: Vector2i) -> bool:
	return (
		celda.x >= 0 and celda.y >= 0
		and celda.x < _construccion.edificio_columnas and celda.y < _construccion.edificio_filas
	)


## Un tramo de jamba: `desde` + un desplazamiento hacia dentro de la sala.
func _jamba(desde: Vector2, hacia_dentro: Vector2, color: Color) -> Dictionary:
	return {"desde": desde, "hasta": desde + hacia_dentro, "color": color}


## El VÉRTICE de la rejilla en la intersección (columna, fila), en píxeles de PANTALLA.
##
## ISOMÉTRICO (2026-07-30): sustituye a las antiguas `_gx`/`_gy`, que devolvían una X y una Y por
## separado porque en vista cenital una línea de rejilla era una recta horizontal o vertical y
## bastaba con una coordenada. En rombos ya no: cada intersección es un punto de los dos ejes a la
## vez, y las paredes se dibujan en DIAGONAL siguiendo los lados del rombo.
func _esquina(columna: int, fila: int) -> Vector2:
	return _desplazamiento + Proyeccion.esquina_iso(columna, fila)


## Un vector de desplazamiento (no un punto) llevado del plano cuadrado a la pantalla. Se usa para
## las jambas, que apuntan "hacia dentro de la sala" — una dirección del PLANO, que en isométrico
## deja de ser horizontal o vertical en pantalla. Al ser la proyección lineal, se puede aplicar
## directamente al vector sin sumarle el origen.
func _direccion(en_plano: Vector2) -> Vector2:
	return Proyeccion.proyectar(en_plano)
