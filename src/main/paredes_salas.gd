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

## Grosor de la línea de pared, en píxeles (encargo: "gruesa, 3-4 px").
const GROSOR_PARED: float = 4.0
## Largo de cada jamba (marco corto de puerta) — sobrio, sin arte elaborado (andamio hasta el art bible).
const LARGO_JAMBA: float = 10.0
## Mismo centinela que `Construccion.CELDA_NULA_PUERTA` (-1,-1), referenciado por VALOR: el proyecto
## tipa estas inyecciones como `Node` genérico (mismo criterio que `luces_objetos.gd` /
## `modo_construccion.gd`), así que no se tipa `_construccion` como `Construccion` para leer su
## constante directamente.
const CELDA_SIN_PUERTA := Vector2i(-1, -1)

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
	for tramo: Dictionary in _tramos:
		draw_line(
			tramo["desde"] as Vector2, tramo["hasta"] as Vector2, tramo["color"] as Color,
			GROSOR_PARED, true
		)
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
	z_index = 0
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
		_tramos.append({"desde": unidad["desde"], "hasta": unidad["hasta"], "color": duenio[clave]})
	# 3) Las jambas: un detalle sutil por cada puerta real (celda distinta de CELDA_SIN_PUERTA).
	for sala_id: StringName in salas:
		_jambas.append_array(_jambas_de_puerta(sala_id))


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
	if info["lado"] == "izquierda":
		var x: float = _gx(rect.position.x)
		return [
			_jamba(Vector2(x, _gy(puerta.y)), Vector2(LARGO_JAMBA, 0.0), color),
			_jamba(Vector2(x, _gy(puerta.y + 1)), Vector2(LARGO_JAMBA, 0.0), color),
		]
	if info["lado"] == "derecha":
		var x: float = _gx(rect.end.x)
		return [
			_jamba(Vector2(x, _gy(puerta.y)), Vector2(-LARGO_JAMBA, 0.0), color),
			_jamba(Vector2(x, _gy(puerta.y + 1)), Vector2(-LARGO_JAMBA, 0.0), color),
		]
	if info["lado"] == "arriba":
		var y: float = _gy(rect.position.y)
		return [
			_jamba(Vector2(_gx(puerta.x), y), Vector2(0.0, LARGO_JAMBA), color),
			_jamba(Vector2(_gx(puerta.x + 1), y), Vector2(0.0, LARGO_JAMBA), color),
		]
	var y: float = _gy(rect.end.y)   # "abajo"
	return [
		_jamba(Vector2(_gx(puerta.x), y), Vector2(0.0, -LARGO_JAMBA), color),
		_jamba(Vector2(_gx(puerta.x + 1), y), Vector2(0.0, -LARGO_JAMBA), color),
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


## Un tramo de línea horizontal (grid-line en la fila `fila_gridline`, celda `celda_x`).
func _unidad_h(fila_gridline: int, celda_x: int) -> Dictionary:
	var y: float = _gy(fila_gridline)
	return {
		"clave": "h:%d:%d" % [fila_gridline, celda_x],
		"desde": Vector2(_gx(celda_x), y), "hasta": Vector2(_gx(celda_x + 1), y),
	}


## Un tramo de línea vertical (grid-line en la columna `columna_gridline`, celda `celda_y`).
func _unidad_v(columna_gridline: int, celda_y: int) -> Dictionary:
	var x: float = _gx(columna_gridline)
	return {
		"clave": "v:%d:%d" % [columna_gridline, celda_y],
		"desde": Vector2(x, _gy(celda_y)), "hasta": Vector2(x, _gy(celda_y + 1)),
	}


## Un tramo de jamba: `desde` + un desplazamiento hacia dentro de la sala.
func _jamba(desde: Vector2, hacia_dentro: Vector2, color: Color) -> Dictionary:
	return {"desde": desde, "hasta": desde + hacia_dentro, "color": color}


## Coordenada X local de una columna de rejilla (grid-line o celda, en píxeles).
func _gx(columna: int) -> float:
	return _desplazamiento.x + float(columna) * _tam_celda


## Coordenada Y local de una fila de rejilla (grid-line o celda, en píxeles).
func _gy(fila: int) -> float:
	return _desplazamiento.y + float(fila) * _tam_celda
