class_name Construccion extends Node
## Construcción — la forma física de la comisaría (sistema Core; NODO del mundo, NO autoload — arq. §3.4).
##
## Story 001 del epic: el núcleo — config data-driven (`ConfigConstruccion`), el MODELO LÓGICO del
## layout (salas = rectángulos de celdas, elementos = puestos/asientos de 1 celda) y la VALIDACIÓN de
## colocación (F6: dentro del edificio ∧ sin solapes ∧ área ≥ mínimo ∧ elemento en sala compatible).
## El modelo es la ÚNICA fuente de verdad; la capa visual (TileMapLayer/escenas, story 006) lo refleja
## y el ratón (story 007) lo consulta — la lógica NUNCA depende de nodos visuales (ADR-0004).
##
## Lee de Datos los tipos (`TipoSala.puestos_admitidos`, costes) por id, read-only (ADR-0003). El
## asiento básico no está en el catálogo (MVP — Comodidades #15): es el id especial `ASIENTO_BASICO`
## con su coste en config.
## Story 002: CONSTRUIR Y PAGAR — F1 (coste de sala = base del catálogo + coste_por_celda × área) y
## F2 (coste del elemento = catálogo / config) con el gate E4 de Economía (`cobrar` — gasto
## voluntario: sin caja se rechaza, no te endeudas construyendo). Guarda `coste_pagado` (F4).
## Story 003: los PUENTES — construir un puesto lo registra en Personal (`registrar_puesto`, API de
## personal-003), el AFORO (F3, enmienda flujo-005: sentados + de pie por área) y F5
## `puestos_utiles` (informativo, sin tope duro — CO7). Getters read-only para Flujo.
## Story 004: DEMOLER Y MOVER (CO8) — reembolso F4 (`coste_pagado × pct_reembolso` vía `abonar`),
## demolición de sala EN CASCADA con API en 2 pasos (`contenido_de_sala` para que la UI confirme +
## `demoler_sala`), y mover gratis con revalidación (el gesto no pasa por el gate si cuesta 0 — no es
## gasto). AC-CO13 (puesto atendiendo) DIFERIDO a Flujo.
## Story 005: PAUSA (CO12 — nada escucha el reloj: construir en Pausa funciona por construcción) y
## PERSISTENCIA (ADR-0002: save/load del layout con Vector2i→[x,y]; "cargar sitúa" — 0 señales, sin
## cobros; re-registra los puestos en Personal. ⚠️ ORDEN: Construcción carga ANTES que Personal).
## Story 006: la CAPA VISUAL (`montar_visual` — TileMapLayer de salas con color por servicio +
## puestos/asientos como PackedScene placeholder instanciadas con map_to_local; el VISUAL refleja el
## MODELO en cada cambio, nunca al revés) y la API DE OFICIO (`construir_de_oficio_*`: el montaje
## inicial viene pagado por la DGP — coste 0, decisión ratificada; ids compat doc_1/doc_2/odac_1).
##
## Story: production/epics/construccion/story-001-nucleo-rejilla-validacion.md · TR-construction-001/002 · ADR-0004

## Ruta del config de tuning (generado por tools/build_config_construccion.gd; fallback a defaults).
const RUTA_CONFIG := "res://datos/config/construccion.tres"
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")

## Id especial del asiento básico (no vive en el catálogo — MVP; Comodidades #15 lo formalizará).
const ASIENTO_BASICO := &"asiento_basico"

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var coste_por_celda: float = 20.0
var densidad_asientos: float = 0.7
var densidad_de_pie: float = 0.5
var pct_reembolso: float = 0.5
var area_min_sala: int = 4
var coste_mover: float = 0.0
var coste_asiento_basico: float = 25.0
var edificio_columnas: int = 24
var edificio_filas: int = 13

# ── El modelo lógico del layout (única fuente de verdad) ─────────────────────────────────────
## Salas construidas: `sala_id -> {tipo: StringName (id de TipoSala), rect: Rect2i}`.
var _salas: Dictionary[StringName, Dictionary] = {}
## Elementos construidos (puestos y asientos, 1 celda): `elemento_id -> {catalogo: StringName,
## celda: Vector2i, sala: StringName, coste_pagado: float}`.
var _elementos: Dictionary[StringName, Dictionary] = {}
## Contador para generar ids únicos (se serializa en la story 005 para no pisar ids al cargar).
var _contador_ids: int = 0

## Economía inyectada (gate E4 de construcción — story 002). En runtime la enchufa Main.
var _economia: Node = null
## El bus (story com-001): por él llega el cierre del día en que se cobra el mantenimiento.
var _bus: Node = null
## Personal inyectado (el puente `registrar_puesto`/`quitar_puesto` — story 003).
var _personal: Node = null
## Gate de demolición (AC-CO13, story flujo-006): callable que responde si un PUESTO puede
## demolerse YA (Main lo cablea a `Flujo.puede_demoler_puesto` — no está atendiendo). Sin cablear
## → demolición directa (compat tests y asientos, que no atienden).
var _puede_demoler: Callable = Callable()
## Puestos cuya demolición ESPERA al fin de su atención (compromiso de servicio — Flujo reintenta
## vía `reintentar_demoliciones_pendientes` al completar cada atención).
var _demoliciones_pendientes: Array[StringName] = []
## Hook de cambio de layout (story flujo-008): Main lo cablea para re-bakear la navegación de los
## NPCs y re-sincronizar los puestos de Flujo. Sin cablear → no-op (tests).
var _hook_layout: Callable = Callable()


## Cablea el hook de cambio de layout (se dispara en cada mutación del modelo, nunca por frame).
func fijar_hook_layout(hook: Callable) -> void:
	_hook_layout = hook


func _ready() -> void:
	if _bus == null:
		usar_bus(get_node_or_null("/root/EventBus"))
	_cargar_config()
	# Contrato de persistencia (ADR-0002): el SaveManager recoge por el grupo, clave = node.name.
	add_to_group("Persist")


## Inyecta Economía (dependency injection → testeable). Sin ella, construir avisa y no cobra.
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta Personal (dependency injection → testeable). Sin él, los puestos no se registran (aviso).
func usar_personal(personal: Node) -> void:
	_personal = personal


## Inyecta el bus y registra el cobro del mantenimiento en el dispatcher ordenado con **prioridad 16**
## (Paciencia 10 → Documentación 15 → **Construcción 16** → Economía 20): el gasto tiene que estar
## anotado antes de que Economía cierre las cuentas del día. Story com-001.
func usar_bus(bus: Node) -> void:
	_bus = bus
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 16, _al_nuevo_dia)


# ── Validación de colocación (F6 — determinista, sin ambigüedad) ─────────────────────────────

## F6 (salas): dentro del edificio ∧ no solapa NINGUNA sala ∧ área ≥ `area_min_sala` (CO1/CO3).
## Un tipo de sala inexistente en el catálogo avisa y es inválido (patrón Datos).
func validar_sala(tipo_sala_id: StringName, rect: Rect2i) -> bool:
	if Datos.obtener(&"TipoSala", tipo_sala_id) == null:
		return false   # Datos ya avisó
	if not _dentro_del_edificio(rect):
		return false
	if rect.get_area() < area_min_sala:
		return false
	for sala: Dictionary in _salas.values():
		if rect.intersects(sala["rect"]):
			return false   # no solapa (adyacente compartiendo borde SÍ vale — intersects es estricto)
	return true


## F6 (elementos, CO4): la celda cae en una sala COMPATIBLE (puesto → su `puestos_admitidos`;
## asiento → sala de tipo "espera") y está libre de otros elementos. Id de catálogo inexistente →
## inválido con aviso. `ignorar` excluye un elemento de los chequeos (mover_elemento se valida a sí
## mismo sin contarse — story 004).
func validar_elemento(id_catalogo: StringName, celda: Vector2i, ignorar: StringName = &"") -> bool:
	var sala_id: StringName = sala_en(celda)
	if sala_id == &"":
		return false   # fuera de toda sala (los elementos viven dentro de salas — CO4)
	if _celda_ocupada(celda, ignorar):
		return false   # no solapan (CO4)
	var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
	if id_catalogo == ASIENTO_BASICO:
		if tipo_sala.tipo != "espera":
			return false
		# F3 (story 003): el asiento por encima del tope físico por área NO cabe — se rechaza.
		return _asientos_en(sala_id, ignorar) < _plazas_max_de(sala_id)
	# Comodidades #15 (story com-001) + Bienestar #13 (bien-005): cada familia va donde tiene sentido
	# — una tele en la sala de espera, un equipo informático donde trabaja la gente, un sofá en la
	# sala de descanso. Cruzarlas no se permite: un sofá en la sala de espera sería otra cosa.
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
	if comodidad != null:
		match comodidad.familia:
			"ciudadano":
				return tipo_sala.tipo == "espera"
			"descanso":
				return tipo_sala.tipo == "descanso"
			_:
				return tipo_sala.tipo == "oficina"
	var tipo_puesto: Resource = Datos.obtener(&"TipoPuesto", id_catalogo)
	if tipo_puesto == null:
		return false   # Datos ya avisó
	return id_catalogo in tipo_sala.puestos_admitidos


## La sala que contiene una celda (&"" si ninguna). Determinista: las salas nunca solapan.
func sala_en(celda: Vector2i) -> StringName:
	for sala_id: StringName in _salas:
		if (_salas[sala_id]["rect"] as Rect2i).has_point(celda):
			return sala_id
	return &""


# ── Comodidades #15 (story com-001): lo que hay COLOCADO en cada sala ────────────────────────

## Suma de aportes de una familia de comodidades en una sala. Construcción **solo suma**: qué hace ese
## número con la paciencia o con el reloj de la atención lo decide cada sistema con SU fórmula
## (ADR-0001) — aquí no vive ningún multiplicador de nadie.
func aporte_de_sala(sala_id: StringName, familia: String) -> float:
	var total: float = 0.0
	for elemento_id: StringName in _elementos:
		if _elementos[elemento_id]["sala"] != sala_id:
			continue
		var comodidad: Resource = Datos.obtener_silencioso(
			&"Comodidad", _elementos[elemento_id]["catalogo"]
		)
		if comodidad != null and comodidad.familia == familia:
			total += comodidad.aporte
	return total


## Confort de una sala de espera (familia "ciudadano"): lo consume Paciencia #10.
func confort_de_sala(sala_id: StringName) -> float:
	return aporte_de_sala(sala_id, "ciudadano")


## Rendimiento instalado en una sala (familia "funcionario"): lo consume Flujo #4.
func equipamiento_de_sala(sala_id: StringName) -> float:
	return aporte_de_sala(sala_id, "funcionario")


# ── Bienestar #13 (story bien-005): lo que hay montado en la sala de DESCANSO ────────────────

## Calidad instalada en la sala de descanso (familia "descanso"): lo consume Personal, que decide con
## SU fórmula cuánto acorta la pausa (ADR-0001 — aquí no vive el multiplicador de nadie). Sumado de
## TODAS las salas de descanso: la comisaría tiene una, pero si hay dos el jugador no pierde lo puesto.
func descanso_instalado() -> float:
	var total: float = 0.0
	for sala_id: StringName in salas_de_tipo("descanso"):
		total += aporte_de_sala(sala_id, "descanso")
	return total


## Plazas de descanso: cuánta gente cabe A LA VEZ tomándose el café. Es la suma de las `plazas` de los
## objetos donde uno se sienta (sofá 3, sillas 2; la nevera mejora el café pero no es sitio donde
## sentarse). **No incluye la plaza base de la sala** — esa la pone Personal, que es quien conoce su
## propio knob: aquí solo se cuenta lo que el jugador ha comprado.
func plazas_de_descanso() -> int:
	var total: int = 0
	for sala_id: StringName in salas_de_tipo("descanso"):
		for elemento_id: StringName in _elementos:
			if _elementos[elemento_id]["sala"] != sala_id:
				continue
			var comodidad: Resource = Datos.obtener_silencioso(
				&"Comodidad", _elementos[elemento_id]["catalogo"]
			)
			if comodidad != null and comodidad.familia == "descanso":
				total += comodidad.plazas
	return total


## Confort MEDIO de las salas de espera de un servicio (0 si no tiene ninguna). Media y no suma: dos
## salas a medio montar no valen lo mismo que una bien montada, y con una sola sala —el caso normal—
## el número es exactamente el suyo. Una sala "Comun" cuenta para ambos servicios.
func confort_de_servicio(servicio: StringName) -> float:
	var total: float = 0.0
	var salas: int = 0
	for sala_id: StringName in _salas:
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala == null or tipo_sala.tipo != "espera":
			continue
		if tipo_sala.servicio != String(servicio) and tipo_sala.servicio != "Comun":
			continue
		total += confort_de_sala(sala_id)
		salas += 1
	if salas == 0:
		return 0.0
	return total / float(salas)


## Rendimiento instalado en la sala donde vive ese puesto (0 si el puesto no existe).
func equipamiento_de_puesto(puesto_id: StringName) -> float:
	if not _elementos.has(puesto_id):
		return 0.0
	return equipamiento_de_sala(_elementos[puesto_id]["sala"])


## Lo que cuesta cada jornada tener encendido todo lo instalado (los objetos sin consumo suman 0).
func mantenimiento_dia() -> float:
	var total: float = 0.0
	for elemento_id: StringName in _elementos:
		var comodidad: Resource = Datos.obtener_silencioso(
			&"Comodidad", _elementos[elemento_id]["catalogo"]
		)
		if comodidad != null:
			total += float(comodidad.coste_mantenimiento_dia_eur)
	return total


## Handler del `nuevo_dia` (prioridad 16: tras la peonada de Documentación 15 y ANTES de que Economía
## pase la factura en la 20). Le REGISTRA el gasto a Economía; el saldo no se toca aquí (ADR-0001).
func _al_nuevo_dia() -> void:
	var coste: float = mantenimiento_dia()
	if coste > 0.0 and _economia != null and _economia.has_method("registrar_mantenimiento"):
		_economia.registrar_mantenimiento(coste)


## El id de CATÁLOGO de un elemento colocado (`&""` si no existe). Con él se le pregunta a Datos qué
## es ese objeto: un puesto, un asiento o una comodidad.
func catalogo_de_elemento(elemento_id: StringName) -> StringName:
	if not _elementos.has(elemento_id):
		return &""
	return _elementos[elemento_id]["catalogo"]


## Los objetos USABLES instalados en las salas de espera de un servicio (story com-003): a estos la
## gente se levanta a ir. Orden estable de construcción. Lo consume Paciencia #10.
func usables_de_servicio(servicio: StringName) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for elemento_id: StringName in _elementos:
		var sala_id: StringName = _elementos[elemento_id]["sala"]
		if not _salas.has(sala_id):
			continue
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala == null or tipo_sala.tipo != "espera":
			continue
		if tipo_sala.servicio != String(servicio) and tipo_sala.servicio != "Comun":
			continue
		var comodidad: Resource = Datos.obtener_silencioso(
			&"Comodidad", _elementos[elemento_id]["catalogo"]
		)
		if comodidad != null and comodidad.usable:
			resultado.append(elemento_id)
	return resultado


## Las salas construidas de un tipo ("espera" / "oficina" / "descanso"), en orden de construcción.
func salas_de_tipo(tipo: String) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for sala_id: StringName in _salas:
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala != null and tipo_sala.tipo == tipo:
			resultado.append(sala_id)
	return resultado


## ¿Existe alguna sala construida de este tipo ("espera" / "oficina" / "descanso")? Lo consulta
## Personal para saber si hay sala de descanso (Bienestar #13).
func hay_sala_de_tipo(tipo: String) -> bool:
	for sala_id: StringName in _salas:
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala != null and tipo_sala.tipo == tipo:
			return true
	return false


## El tipo de sala (id del catálogo) con el que se construyó, o `&""` si la sala no existe. Lo
## consume el menú contextual del clic derecho (2026-07-28) para saber con qué pincel se amplía.
func tipo_de_sala(sala_id: StringName) -> StringName:
	if not _salas.has(sala_id):
		return &""
	return _salas[sala_id]["tipo"]


## ¿Hay ya un elemento en esta celda? (`ignorar` excluye a uno — para revalidar al moverlo).
func _celda_ocupada(celda: Vector2i, ignorar: StringName = &"") -> bool:
	for elemento_id: StringName in _elementos:
		if elemento_id != ignorar and _elementos[elemento_id]["celda"] == celda:
			return true
	return false


## ¿El rectángulo cabe entero en el edificio? (CO1: toda construcción ocurre dentro).
func _dentro_del_edificio(rect: Rect2i) -> bool:
	return (
		rect.position.x >= 0 and rect.position.y >= 0
		and rect.end.x <= edificio_columnas and rect.end.y <= edificio_filas
	)


# ── Registro directo en el modelo (SIN validar ni cobrar — lo usan la story 002 y los tests) ──

## Da de alta una sala YA validada y pagada (guarda `coste_pagado` — reembolso F4). Devuelve su id.
## `id_forzado` permite ids compat (`doc_1`... los usará el montaje inicial de la 006).
func _crear_sala(
	tipo_sala_id: StringName, rect: Rect2i, coste_pagado: float = 0.0, id_forzado: StringName = &""
) -> StringName:
	var sala_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(&"sala")
	_salas[sala_id] = {"tipo": tipo_sala_id, "rect": rect, "coste_pagado": coste_pagado}
	_refrescar_visual()
	return sala_id


## Da de alta un elemento YA validado y pagado (guarda `coste_pagado` — lo necesita el reembolso F4).
func _crear_elemento(
	id_catalogo: StringName, celda: Vector2i, coste_pagado: float, id_forzado: StringName = &""
) -> StringName:
	var elemento_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(id_catalogo)
	_elementos[elemento_id] = {
		"catalogo": id_catalogo, "celda": celda, "sala": sala_en(celda), "coste_pagado": coste_pagado,
	}
	_refrescar_visual()
	return elemento_id


## Genera un id único y estable (`prefijo_N`). El contador se persiste (story 005).
func _nuevo_id(prefijo: StringName) -> StringName:
	_contador_ids += 1
	return StringName("%s_%d" % [prefijo, _contador_ids])


# ── Costes y construcción (Story 002 · TR-construction-004 · GDD CO6/CO9, F1/F2) ─────────────

## F1: `coste_base (catálogo TipoSala) + coste_por_celda × área` — sobredimensionar tiene precio.
## Las oficinas pueden tener base 0 (su coste real son los puestos). Tipo inexistente → 0 con aviso.
func coste_sala(tipo_sala_id: StringName, rect: Rect2i) -> float:
	var tipo: Resource = Datos.obtener(&"TipoSala", tipo_sala_id)
	if tipo == null:
		return 0.0
	var base: float = _clamp_coste(float(tipo.coste_construccion_eur), tipo_sala_id)
	return base + coste_por_celda * float(rect.get_area())


## F2: el coste del elemento — asiento básico de config; puestos del catálogo. Id inexistente → 0.
func coste_elemento(id_catalogo: StringName) -> float:
	if id_catalogo == ASIENTO_BASICO:
		return coste_asiento_basico
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
	if comodidad != null:
		return _clamp_coste(float(comodidad.coste_construccion_eur), id_catalogo)
	var tipo: Resource = Datos.obtener(&"TipoPuesto", id_catalogo)
	if tipo == null:
		return 0.0
	return _clamp_coste(float(tipo.coste_construccion_eur), id_catalogo)


## Construye una sala (CO3/CO6/CO9): valida F6 → cobra por el gate E4 → alta en el modelo. Devuelve
## el id creado o `&""` (rechazo de REGLA — inválido o sin caja — silencioso: la UI lo pinta en rojo).
## ENMIENDA 007 (feedback del usuario en el sign-off): dibujar PEGADO o solapado a una sala del
## MISMO tipo la AMPLÍA (misma sala, rect unido, cobra solo las celdas nuevas) en vez de crear otra.
func construir_sala(tipo_sala_id: StringName, rect: Rect2i) -> StringName:
	var ampliable: StringName = sala_ampliable(tipo_sala_id, rect)
	if ampliable != &"":
		var coste_ampliar: float = coste_ampliacion(ampliable, rect)
		if not _pagar(coste_ampliar):
			return &""
		_salas[ampliable]["rect"] = (_salas[ampliable]["rect"] as Rect2i).merge(rect)
		_salas[ampliable]["coste_pagado"] = float(_salas[ampliable]["coste_pagado"]) + coste_ampliar
		_refrescar_visual()
		return ampliable
	if not validar_sala(tipo_sala_id, rect):
		return &""
	var coste: float = coste_sala(tipo_sala_id, rect)
	if not _pagar(coste):
		return &""
	return _crear_sala(tipo_sala_id, rect, coste)


## ¿El rectángulo AMPLÍA una sala existente del mismo tipo? Exige que la UNIÓN siga siendo un
## rectángulo EXACTO (CO3: las salas son rectángulos — un dibujo en "L" no amplía, crea sala aparte),
## que aporte celdas nuevas, quepa en el edificio y no pise otras salas. Devuelve el id o `&""`.
func sala_ampliable(tipo_sala_id: StringName, rect: Rect2i) -> StringName:
	if not _dentro_del_edificio(rect):
		return &""
	for sala_id: StringName in _salas:
		var sala: Dictionary = _salas[sala_id]
		if sala["tipo"] != tipo_sala_id:
			continue
		var actual: Rect2i = sala["rect"]
		var union: Rect2i = actual.merge(rect)
		var interseccion: int = actual.intersection(rect).get_area()
		if union.get_area() != actual.get_area() + rect.get_area() - interseccion:
			continue   # la unión no es rectangular exacta (haría una L)
		if union.get_area() == actual.get_area():
			continue   # todo cae dentro de la sala: nada que ampliar
		if not _dentro_del_edificio(union):
			continue
		var choca: bool = false
		for otra_id: StringName in _salas:
			if otra_id != sala_id and union.intersects(_salas[otra_id]["rect"]):
				choca = true
				break
		if not choca:
			return sala_id
	return &""


## Coste de la ampliación (F1 SIN base — la sala ya está "abierta"): solo las celdas NUEVAS.
func coste_ampliacion(sala_id: StringName, rect: Rect2i) -> float:
	if not _salas.has(sala_id):
		return 0.0
	var actual: Rect2i = _salas[sala_id]["rect"]
	var celdas_nuevas: int = actual.merge(rect).get_area() - actual.get_area()
	return coste_por_celda * float(celdas_nuevas)


## Construye un elemento (CO4/CO6/CO9): valida → cobra → alta guardando `coste_pagado` (F4). Si es
## un PUESTO, lo registra en Personal (puente de la story 003 — API `registrar_puesto` ya existente).
func construir_elemento(id_catalogo: StringName, celda: Vector2i) -> StringName:
	if not validar_elemento(id_catalogo, celda):
		return &""
	var coste: float = coste_elemento(id_catalogo)
	if not _pagar(coste):
		return &""
	return _alta_elemento(id_catalogo, celda, coste)


## Alta común (construir normal y de oficio): registra en el modelo + puente a Personal si es puesto.
func _alta_elemento(
	id_catalogo: StringName, celda: Vector2i, coste_pagado: float, id_forzado: StringName = &""
) -> StringName:
	var elemento_id: StringName = _crear_elemento(id_catalogo, celda, coste_pagado, id_forzado)
	# Solo los PUESTOS se registran en Personal (son plazas de trabajo). Ni los asientos ni las
	# comodidades lo son: una máquina de vending no es una vacante que cubrir.
	# 🐛 Bug cazado por `comodidades_uso_test` (2026-07-28): antes bastaba con "no ser asiento", así
	# que cada tele o vending entraba en Personal como puesto fantasma — habría aparecido en el panel
	# de plantilla pidiendo un agente que jamás lo iba a atender.
	if Datos.obtener_silencioso(&"TipoPuesto", id_catalogo) != null:
		if _personal != null:
			_personal.registrar_puesto(elemento_id, id_catalogo)
		else:
			push_warning("Construccion: puesto '%s' construido SIN Personal inyectado" % elemento_id)
	return elemento_id


# ── Montaje de oficio (Story 006 — SOLO arranque; decisión ratificada: la DGP entrega pagado) ─

## Construye una sala del montaje inicial: valida pero NO cobra (coste_pagado 0 — demolerla no
## "regala" reembolso). Si la validación falla es un BUG del layout inicial → aviso ruidoso.
func construir_de_oficio_sala(
	tipo_sala_id: StringName, rect: Rect2i, id_forzado: StringName = &""
) -> StringName:
	if not validar_sala(tipo_sala_id, rect):
		push_warning("Construccion: montaje de oficio INVALIDO (sala '%s' en %s)" % [tipo_sala_id, rect])
		return &""
	return _crear_sala(tipo_sala_id, rect, 0.0, id_forzado)


## Construye un elemento del montaje inicial (coste 0; `id_forzado` para los ids compat doc_1...).
func construir_de_oficio_elemento(
	id_catalogo: StringName, celda: Vector2i, id_forzado: StringName = &""
) -> StringName:
	if not validar_elemento(id_catalogo, celda):
		push_warning("Construccion: montaje de oficio INVALIDO ('%s' en %s)" % [id_catalogo, celda])
		return &""
	return _alta_elemento(id_catalogo, celda, 0.0, id_forzado)


## El gate E4 (CO6): `cobrar` de Economía ya comprueba `puede_pagar` — sin caja devuelve false y el
## saldo queda intacto. Sin Economía inyectada (tests unitarios) → construye gratis con aviso.
func _pagar(coste: float) -> bool:
	if _economia == null:
		push_warning("Construccion: construyendo SIN gate de Economia (no inyectada)")
		return true
	return _economia.cobrar(coste)


## Clampa un coste del catálogo a ≥ 0 con aviso (AC-CO18 — dato corrupto no revienta ni "paga").
func _clamp_coste(valor: float, id_origen: StringName) -> float:
	if valor < 0.0:
		push_warning("Construccion: coste negativo en '%s' (%f) -> 0" % [id_origen, valor])
		return 0.0
	return valor


# ── Aforo, puestos útiles y getters para Flujo (Story 003 · TR-construction-004 · F3/F5) ─────

## F3 (ENMIENDA flujo-005, petición del usuario): aforo de una sala de espera = SENTADOS
## (`min(asientos colocados, floor(área × densidad_asientos))`) + DE PIE (`floor(área ×
## densidad_de_pie)`) — sin asientos se entra igual, de pie; lo que no cabe espera fuera (F6 de
## Flujo). El asiento será confort cuando llegue Paciencia #10. Sala inexistente → 0 con aviso.
func aforo_de_sala(sala_id: StringName) -> int:
	if not _salas.has(sala_id):
		push_warning("Construccion: aforo de una sala inexistente ('%s') -> 0" % sala_id)
		return 0
	var sentados: int = mini(_asientos_en(sala_id), _plazas_max_de(sala_id))
	var area: int = (_salas[sala_id]["rect"] as Rect2i).get_area()
	var de_pie: int = int(floor(float(area) * densidad_de_pie))
	return sentados + de_pie


## F3 agregado (para el F6 de Flujo — story flujo-005): aforo TOTAL de espera de un servicio =
## suma del aforo de TODAS sus salas de espera (una sala "Comun" cuenta para ambos servicios —
## comparte asientos). Sin salas de espera del servicio → 0 (Flujo manda a la cola exterior).
func aforo_de_servicio(servicio: StringName) -> int:
	var total: int = 0
	for sala_id: StringName in _salas:
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala == null or tipo_sala.tipo != "espera":
			continue
		if tipo_sala.servicio == String(servicio) or tipo_sala.servicio == "Comun":
			total += aforo_de_sala(sala_id)
	return total


## Asientos colocados en una sala (`ignorar` excluye a uno — para revalidar al moverlo).
func _asientos_en(sala_id: StringName, ignorar: StringName = &"") -> int:
	var total: int = 0
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		if elemento_id != ignorar and elemento["catalogo"] == ASIENTO_BASICO and elemento["sala"] == sala_id:
			total += 1
	return total


## Tope físico de plazas por área (F3): `floor(área × densidad_asientos)`.
func _plazas_max_de(sala_id: StringName) -> int:
	var area: int = (_salas[sala_id]["rect"] as Rect2i).get_area()
	return int(floor(float(area) * densidad_asientos))


## F5 (informativo, CO7 — NO es un tope): cuántos puestos justifica la demanda pico. La UI futura lo
## mostrará como brújula; construir de más es legal (agentes ociosos). Throughput ≤ 0 → 0 con aviso.
func puestos_utiles(tasa_llegadas_pico: float, throughput_hora_puesto: float) -> int:
	if throughput_hora_puesto <= 0.0:
		push_warning("Construccion: puestos_utiles con throughput <= 0 -> 0")
		return 0
	return ceili(tasa_llegadas_pico / throughput_hora_puesto)


## El elemento que ocupa una celda (&"" si ninguno) — lo usa la herramienta de demolición (007).
func elemento_en(celda: Vector2i) -> StringName:
	for elemento_id: StringName in _elementos:
		if _elementos[elemento_id]["celda"] == celda:
			return elemento_id
	return &""


## Reembolso TOTAL de demoler una sala en cascada (sala + contenido, F4) — para el diálogo de
## confirmación de la UI (paso 1 de la cascada). No muta nada.
func reembolso_de_sala(sala_id: StringName) -> float:
	if not _salas.has(sala_id):
		return 0.0
	var total: float = float(_salas[sala_id]["coste_pagado"]) * pct_reembolso
	for elemento_id: StringName in contenido_de_sala(sala_id):
		total += float(_elementos[elemento_id]["coste_pagado"]) * pct_reembolso
	return total


## ¿Hay caja para este coste? (el preview pinta "sin caja" en rojo SIN intentar construir — 007).
## Sin Economía inyectada → true (tests).
func puede_pagar(coste: float) -> bool:
	if _economia == null:
		return true
	return _economia.puede_pagar(coste)


## Celda de un elemento (getter para Flujo/visual). Inexistente → (-1,-1) con aviso.
func posicion_de(elemento_id: StringName) -> Vector2i:
	if not _elementos.has(elemento_id):
		push_warning("Construccion: posicion de un elemento inexistente ('%s')" % elemento_id)
		return Vector2i(-1, -1)
	return _elementos[elemento_id]["celda"]


## Los puestos construidos de un servicio ("Documentacion"/"ODAC"/"Seguridad"), en orden estable de
## construcción (getter para Flujo).
func puestos_de_servicio(servicio: String) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for elemento_id: StringName in _elementos:
		var catalogo: StringName = _elementos[elemento_id]["catalogo"]
		if catalogo == ASIENTO_BASICO:
			continue
		var tipo: Resource = Datos.obtener(&"TipoPuesto", catalogo)
		if tipo != null and tipo.servicio == servicio:
			resultado.append(elemento_id)
	return resultado


## El id de catálogo de un elemento construido (`&""` si no existe) — para re-registrar puestos
## en Flujo tras un cambio de layout (story flujo-008).
func catalogo_de(elemento_id: StringName) -> StringName:
	if not _elementos.has(elemento_id):
		return &""
	return _elementos[elemento_id]["catalogo"]


## Las salas de espera que sirven a un servicio (propias + "Comun"), en orden estable — los NPCs
## visibles (story flujo-008) buscan asiento/hueco en ellas.
func salas_de_espera_de(servicio: StringName) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for sala_id: StringName in _salas:
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
		if tipo_sala == null or tipo_sala.tipo != "espera":
			continue
		if tipo_sala.servicio == String(servicio) or tipo_sala.servicio == "Comun":
			resultado.append(sala_id)
	return resultado


## El rectángulo de una sala (celdas). Inexistente → Rect2i() vacío con aviso.
func rect_de_sala(sala_id: StringName) -> Rect2i:
	if not _salas.has(sala_id):
		push_warning("Construccion: rect de una sala inexistente ('%s')" % sala_id)
		return Rect2i()
	return _salas[sala_id]["rect"]


## Los asientos colocados en una sala, en orden estable de construcción (para sentar NPCs).
func asientos_de_sala(sala_id: StringName) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		if elemento["catalogo"] == ASIENTO_BASICO and elemento["sala"] == sala_id:
			resultado.append(elemento_id)
	return resultado


# ── Demoler y mover (Story 004 · TR-construction-004 · GDD CO8, F4) ──────────────────────────

## Demuele un elemento (CO8): abona el reembolso F4 (`coste_pagado × pct_reembolso`), libera su
## celda y, si era un puesto, lo retira de Personal (`quitar_puesto` — su agente al banquillo).
## AC-CO13 (terminar la atención en curso) es contrato con Flujo al integrar — DIFERIDO.
func demoler_elemento(elemento_id: StringName) -> bool:
	if not _elementos.has(elemento_id):
		push_warning("Construccion: demoler un elemento inexistente ('%s') -> ignorado" % elemento_id)
		return false
	var elemento: Dictionary = _elementos[elemento_id]
	if elemento["catalogo"] != ASIENTO_BASICO and not _gate_demolicion(elemento_id):
		# AC-CO13: puesto ATENDIENDO → la demolición queda PENDIENTE (compromiso de servicio);
		# Flujo la reintenta al terminar la atención. Aún no se demuele ni se reembolsa.
		if not (elemento_id in _demoliciones_pendientes):
			_demoliciones_pendientes.append(elemento_id)
		return false
	_demoliciones_pendientes.erase(elemento_id)
	_abonar(float(elemento["coste_pagado"]) * pct_reembolso)
	if elemento["catalogo"] != ASIENTO_BASICO and _personal != null:
		_personal.quitar_puesto(elemento_id)
	_elementos.erase(elemento_id)
	_refrescar_visual()
	return true


## ¿El gate AC-CO13 deja demoler este puesto YA? Sin callable cableado → sí (compat).
func _gate_demolicion(elemento_id: StringName) -> bool:
	if not _puede_demoler.is_valid():
		return true
	return bool(_puede_demoler.call(elemento_id))


## Cablea el gate de demolición (AC-CO13). Main: `fijar_puede_demoler(flujo.puede_demoler_puesto)`.
func fijar_puede_demoler(gate: Callable) -> void:
	_puede_demoler = gate


## ¿Hay demoliciones esperando a que termine una atención? (chequeo barato para el tick de Flujo).
func hay_demoliciones_pendientes() -> bool:
	return not _demoliciones_pendientes.is_empty()


## Reintenta las demoliciones pendientes (las llama Flujo al completar atenciones). Devuelve los
## ids que SÍ cayeron (Flujo los retira de su registro); las que sigan frenadas se re-encolan
## solas (demoler_elemento las vuelve a apuntar).
func reintentar_demoliciones_pendientes() -> Array[StringName]:
	var pendientes: Array[StringName] = _demoliciones_pendientes.duplicate()
	_demoliciones_pendientes.clear()
	var demolidos: Array[StringName] = []
	for elemento_id: StringName in pendientes:
		if not _elementos.has(elemento_id):
			continue   # ya no existe (p. ej. cayó en una cascada) — nada que hacer
		if demoler_elemento(elemento_id):
			demolidos.append(elemento_id)
	return demolidos


## El contenido de una sala (ids de sus elementos, orden estable de construcción). Es el paso 1 de
## la demolición en cascada: la UI lo lista y CONFIRMA antes de llamar a `demoler_sala` (la API no
## pregunta — Edge "cascada con confirmación").
func contenido_de_sala(sala_id: StringName) -> Array[StringName]:
	var resultado: Array[StringName] = []
	for elemento_id: StringName in _elementos:
		if _elementos[elemento_id]["sala"] == sala_id:
			resultado.append(elemento_id)
	return resultado


## Paso 2 de la cascada: demuele el contenido (reembolsando CADA elemento por su `coste_pagado`) y
## después la sala (reembolsando el suyo). Libera todas sus celdas.
## AC-CO13 (story flujo-006): si ALGÚN puesto de la sala está atendiendo (gate), la cascada entera
## se rechaza con aviso — sin salas a medio demoler ni pendientes huérfanos; el jugador reintenta.
func demoler_sala(sala_id: StringName) -> bool:
	if not _salas.has(sala_id):
		push_warning("Construccion: demoler una sala inexistente ('%s') -> ignorado" % sala_id)
		return false
	for elemento_id: StringName in contenido_de_sala(sala_id):
		if _elementos[elemento_id]["catalogo"] != ASIENTO_BASICO and not _gate_demolicion(elemento_id):
			push_warning("Construccion: la sala '%s' tiene un puesto atendiendo -> cascada rechazada" % sala_id)
			return false
	for elemento_id: StringName in contenido_de_sala(sala_id):
		demoler_elemento(elemento_id)
	_abonar(float(_salas[sala_id]["coste_pagado"]) * pct_reembolso)
	_salas.erase(sala_id)
	_refrescar_visual()
	return true


## Mueve un elemento a otra celda (CO8): revalida SIN contarse a sí mismo (misma regla CO4 — un
## `odac` no se muda a la oficina de Doc) y conserva id y `coste_pagado`. Con `coste_mover` 0 el
## gesto es gratis y NO pasa por el gate (no es gasto — reorganizar no penaliza, Pilar 4); con coste
## > 0 sí se cobra. Personal ni se entera: el registro del puesto no cambia.
func mover_elemento(elemento_id: StringName, celda_destino: Vector2i) -> bool:
	if not _elementos.has(elemento_id):
		push_warning("Construccion: mover un elemento inexistente ('%s') -> ignorado" % elemento_id)
		return false
	var elemento: Dictionary = _elementos[elemento_id]
	if not validar_elemento(elemento["catalogo"], celda_destino, elemento_id):
		return false
	if coste_mover > 0.0 and not _pagar(coste_mover):
		return false
	elemento["celda"] = celda_destino
	elemento["sala"] = sala_en(celda_destino)
	_refrescar_visual()
	return true


## Abona un reembolso vía Economía (F4). Sin Economía inyectada (tests unitarios) → no-op con aviso.
func _abonar(cantidad: float) -> void:
	if _economia == null:
		push_warning("Construccion: reembolso SIN Economia inyectada -> se pierde")
		return
	_economia.abonar(cantidad)


# ── Persistencia (Story 005 · TR-construction-004 · ADR-0002) ────────────────────────────────

## Estado serializable del layout (contrato `Persist`; clave = node.name). SOLO estado no derivado:
## la sala de cada elemento se re-deriva de su celda, los aforos de los asientos, y los costes de
## catálogo/config no se guardan (solo `coste_pagado`, que es histórico). Vector2i/Rect2i → arrays
## de ints (limitación JSON — ADR-0002).
func save() -> Dictionary:
	var salas: Array = []
	for sala_id: StringName in _salas:
		var sala: Dictionary = _salas[sala_id]
		var rect: Rect2i = sala["rect"]
		salas.append({
			"id": String(sala_id), "tipo": String(sala["tipo"]),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"coste_pagado": sala["coste_pagado"],
		})
	var elementos: Array = []
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		elementos.append({
			"id": String(elemento_id), "catalogo": String(elemento["catalogo"]),
			"celda": [elemento["celda"].x, elemento["celda"].y],
			"coste_pagado": elemento["coste_pagado"],
		})
	return {"salas": salas, "elementos": elementos, "contador_ids": _contador_ids}


## Restaura el layout desde un Dictionary (p. ej. parseado de JSON). Defensivo (ADR-0002: la entrada
## corrupta se DESCARTA con aviso, nunca invalida el save) y SIN señales ni dinero ("cargar sitúa"):
## ni cobros ni reembolsos — el saldo ya viene en el save de Economía. Re-registra los puestos en
## Personal (retirando antes los del estado anterior — el puente no acumula huérfanos).
## ⚠️ ORDEN: Construcción debe cargar ANTES que Personal (sus asignaciones referencian estos puestos).
func load_state(d: Dictionary) -> void:
	if _personal != null:
		for elemento_id: StringName in _elementos:
			if _elementos[elemento_id]["catalogo"] != ASIENTO_BASICO:
				_personal.quitar_puesto(elemento_id)
	_salas.clear()
	_elementos.clear()
	for datos: Variant in d.get("salas", []):
		if not (datos is Dictionary):
			push_warning("Construccion: sala corrupta en el save -> descartada")
			continue
		var tipo_sala: StringName = StringName(String(datos.get("tipo", "")))
		var rect_datos: Variant = datos.get("rect", [])
		if Datos.obtener(&"TipoSala", tipo_sala) == null \
				or not (rect_datos is Array) or rect_datos.size() != 4:
			push_warning("Construccion: sala '%s' invalida en el save -> descartada" % datos.get("id", "?"))
			continue
		var rect := Rect2i(
			int(rect_datos[0]), int(rect_datos[1]), int(rect_datos[2]), int(rect_datos[3])
		)
		_salas[StringName(String(datos.get("id", "")))] = {
			"tipo": tipo_sala, "rect": rect, "coste_pagado": float(datos.get("coste_pagado", 0.0)),
		}
	for datos: Variant in d.get("elementos", []):
		if not (datos is Dictionary):
			push_warning("Construccion: elemento corrupto en el save -> descartado")
			continue
		var catalogo: StringName = StringName(String(datos.get("catalogo", "")))
		var celda_datos: Variant = datos.get("celda", [])
		var es_asiento: bool = catalogo == ASIENTO_BASICO
		if (not es_asiento and Datos.obtener(&"TipoPuesto", catalogo) == null) \
				or not (celda_datos is Array) or celda_datos.size() != 2:
			push_warning("Construccion: elemento '%s' invalido en el save -> descartado" % datos.get("id", "?"))
			continue
		var elemento_id: StringName = StringName(String(datos.get("id", "")))
		var celda := Vector2i(int(celda_datos[0]), int(celda_datos[1]))
		_elementos[elemento_id] = {
			"catalogo": catalogo, "celda": celda, "sala": sala_en(celda),
			"coste_pagado": float(datos.get("coste_pagado", 0.0)),
		}
		if not es_asiento:
			if _personal != null:
				_personal.registrar_puesto(elemento_id, catalogo)
			else:
				push_warning("Construccion: puesto '%s' cargado SIN Personal inyectado" % elemento_id)
	_contador_ids = maxi(int(d.get("contador_ids", 0)), 0)
	_refrescar_visual()


# ── Capa visual (Story 006 · TR-construction-001/003 — el visual REFLEJA el modelo) ──────────
## Solo presentación: TileMapLayer para las salas (color por servicio + tono por tipo) y escenas
## placeholder para puestos/asientos (`PackedScene` + `instantiate()` + `map_to_local` — NUNCA
## lógica en tiles, ADR-0004). Sin `montar_visual` (tests headless), todo esto queda inerte.

var _capa_salas: TileMapLayer = null
var _capa_elementos: Node2D = null
var _tam_celda: int = 40
## `tipo_sala_id -> source_id` del TileSet generado por código (un tile plano por tipo de sala).
var _fuentes_tileset: Dictionary = {}
var _escena_puesto: PackedScene = null
var _escena_asiento: PackedScene = null


## Crea la capa visual (la llama Main tras add_child): TileMapLayer "Salas" + Node2D "Elementos",
## alineados con el suelo del esqueleto (`desplazamiento` = posición del suelo; `tam_celda` = 40).
func montar_visual(tam_celda: int, desplazamiento: Vector2) -> void:
	_tam_celda = tam_celda
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(tam_celda, tam_celda)
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		var fuente := TileSetAtlasSource.new()
		fuente.texture = _textura_de_celda(_color_de_sala(tipo_sala))
		fuente.texture_region_size = Vector2i(tam_celda, tam_celda)
		fuente.create_tile(Vector2i.ZERO)
		_fuentes_tileset[tipo_sala.id] = tileset.add_source(fuente)
	_capa_salas = TileMapLayer.new()
	_capa_salas.name = "Salas"
	_capa_salas.tile_set = tileset
	_capa_salas.position = desplazamiento
	add_child(_capa_salas)
	_capa_elementos = Node2D.new()
	_capa_elementos.name = "Elementos"
	_capa_elementos.position = desplazamiento
	add_child(_capa_elementos)
	_escena_puesto = _empaquetar_placeholder(int(tam_celda * 0.8), Color(0.16, 0.18, 0.22), true)
	_escena_asiento = _empaquetar_placeholder(int(tam_celda * 0.4), Color(0.45, 0.42, 0.35), false)
	_refrescar_visual()


## La celda de la rejilla bajo el cursor (manifiesto ADR-0004: `local_to_map` del TileMapLayer).
## Sin capa visual montada (headless/tests) → (-1,-1).
func celda_bajo_cursor() -> Vector2i:
	if _capa_salas == null:
		return Vector2i(-1, -1)
	return _capa_salas.local_to_map(_capa_salas.get_local_mouse_position())


## La celda que contiene un punto del MUNDO. ⚠️ Úsala (y no `celda_bajo_cursor`) siempre que la
## acción venga de un CLIC: `celda_bajo_cursor` lee el puntero del sistema *en ese instante*, no el
## punto donde se hizo clic — el bug del clic derecho del 2026-07-26, ya escrito en el manifiesto.
func celda_de_punto(punto_mundo: Vector2) -> Vector2i:
	if _capa_salas == null:
		return Vector2i(-1, -1)
	return _capa_salas.local_to_map(_capa_salas.to_local(punto_mundo))


## El centro de una celda en coordenadas de MUNDO (`map_to_local` — para posicionar previews).
func centro_de_celda(celda: Vector2i) -> Vector2:
	if _capa_salas == null:
		return Vector2.ZERO
	return _capa_salas.to_global(_capa_salas.map_to_local(celda))


## Redibuja TODO el visual desde el modelo (se llama en cada cambio de layout, nunca por frame —
## el layout cambia por acciones puntuales del jugador, no en el tick).
func _refrescar_visual() -> void:
	# Hook de cambio de layout (story flujo-008): Main re-bakea la navegación y re-sincroniza los
	# puestos de Flujo SOLO aquí (nunca por frame). Se avisa aunque no haya capa visual montada.
	if _hook_layout.is_valid():
		_hook_layout.call()
	if _capa_salas == null:
		return
	_capa_salas.clear()
	for hijo: Node in _capa_elementos.get_children():
		hijo.free()
	for sala_id: StringName in _salas:
		var tipo_id: StringName = _salas[sala_id]["tipo"]
		if not _fuentes_tileset.has(tipo_id):
			continue
		var rect: Rect2i = _salas[sala_id]["rect"]
		for x: int in range(rect.position.x, rect.end.x):
			for y: int in range(rect.position.y, rect.end.y):
				_capa_salas.set_cell(Vector2i(x, y), _fuentes_tileset[tipo_id], Vector2i.ZERO)
		# Etiqueta de la sala (respaldo daltónico: texto además del color).
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", tipo_id)
		var etiqueta := Label.new()
		etiqueta.text = tipo_sala.nombre if tipo_sala != null else String(tipo_id)
		etiqueta.add_theme_font_size_override("font_size", 10)
		etiqueta.modulate = Color(1, 1, 1, 0.75)
		etiqueta.position = _capa_salas.map_to_local(rect.position) - Vector2(_tam_celda, _tam_celda) / 2.0 + Vector2(3, 1)
		_capa_elementos.add_child(etiqueta)
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		var es_asiento: bool = elemento["catalogo"] == ASIENTO_BASICO
		var escena: PackedScene = _escena_asiento if es_asiento else _escena_puesto
		var instancia: Node2D = escena.instantiate()
		instancia.position = _capa_salas.map_to_local(elemento["celda"])
		if not es_asiento:
			var tipo_puesto: Resource = Datos.obtener(&"TipoPuesto", elemento["catalogo"])
			var texto: Label = instancia.get_node("Etiqueta")
			texto.text = tipo_puesto.nombre if tipo_puesto != null else String(elemento["catalogo"])
		_capa_elementos.add_child(instancia)


## Color placeholder por tipo de sala: azul institucional (Doc) / naranja apagado (ODAC) / gris
## (Común); las ESPERAS, más apagadas que las oficinas (art bible §mood provisional).
func _color_de_sala(tipo_sala: Resource) -> Color:
	var base := Color(0.30, 0.38, 0.55)
	if tipo_sala.servicio == "ODAC":
		base = Color(0.55, 0.40, 0.22)
	elif tipo_sala.servicio == "Comun":
		base = Color(0.35, 0.37, 0.40)
	if tipo_sala.tipo == "espera":
		base = base.lerp(Color(0.22, 0.24, 0.27), 0.45)
	return base


## Tile plano con borde de rejilla (patrón del suelo de Main).
func _textura_de_celda(color: Color) -> ImageTexture:
	var imagen := Image.create(_tam_celda, _tam_celda, false, Image.FORMAT_RGBA8)
	imagen.fill(color)
	var linea: Color = color.darkened(0.3)
	for i: int in _tam_celda:
		imagen.set_pixel(i, 0, linea)
		imagen.set_pixel(0, i, linea)
	return ImageTexture.create_from_image(imagen)


## Construye una PackedScene placeholder por código (caja centrada + etiqueta opcional). Escenas
## de verdad (TR-construction-003) — el arte real llegará tras el art bible (condición 2 del gate).
func _empaquetar_placeholder(lado: int, color: Color, con_etiqueta: bool) -> PackedScene:
	var raiz := Node2D.new()
	var caja := ColorRect.new()
	caja.name = "Caja"
	caja.size = Vector2(lado, lado)
	caja.position = -caja.size / 2.0
	caja.color = color
	# Gotcha: un ColorRect por defecto SE TRAGA los clics (mouse_filter STOP) → los clics sobre un
	# puesto/asiento nunca llegaban a la herramienta de demoler. El placeholder es decorativo: IGNORE.
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja)
	caja.owner = raiz
	if con_etiqueta:
		var etiqueta := Label.new()
		etiqueta.name = "Etiqueta"
		etiqueta.add_theme_font_size_override("font_size", 9)
		etiqueta.position = Vector2(-lado / 2.0, lado / 2.0 + 1)
		raiz.add_child(etiqueta)
		etiqueta.owner = raiz
	var escena := PackedScene.new()
	escena.pack(raiz)
	raiz.free()
	return escena


# ── Config (patrón Economía/Demanda/Personal: aplicar con clamp defensivo + fallback) ────────

## Copia los knobs del config con clamp defensivo y aviso. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigConstruccionScript):
		push_warning("Construccion: config invalido -> defaults")
		config = ConfigConstruccionScript.new()
	coste_por_celda = _clamp_knob(config.coste_por_celda, "coste_por_celda")
	densidad_asientos = clampf(config.densidad_asientos, 0.0, 1.0)
	densidad_de_pie = clampf(config.densidad_de_pie, 0.0, 1.0)
	pct_reembolso = clampf(config.pct_reembolso, 0.0, 1.0)
	area_min_sala = maxi(config.area_min_sala, 1)
	coste_mover = _clamp_knob(config.coste_mover, "coste_mover")
	coste_asiento_basico = _clamp_knob(config.coste_asiento_basico, "coste_asiento_basico")
	edificio_columnas = maxi(config.edificio_columnas, 1)
	edificio_filas = maxi(config.edificio_filas, 1)


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Construccion: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón del proyecto).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Construccion: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor
