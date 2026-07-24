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
## personal-003), el AFORO por asientos (F3: min(asientos, floor(área × densidad))) y F5
## `puestos_utiles` (informativo, sin tope duro — CO7). Getters read-only para Flujo.
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
## Personal inyectado (el puente `registrar_puesto`/`quitar_puesto` — story 003).
var _personal: Node = null


func _ready() -> void:
	_cargar_config()


## Inyecta Economía (dependency injection → testeable). Sin ella, construir avisa y no cobra.
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta Personal (dependency injection → testeable). Sin él, los puestos no se registran (aviso).
func usar_personal(personal: Node) -> void:
	_personal = personal


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
## inválido con aviso.
func validar_elemento(id_catalogo: StringName, celda: Vector2i) -> bool:
	var sala_id: StringName = sala_en(celda)
	if sala_id == &"":
		return false   # fuera de toda sala (los elementos viven dentro de salas — CO4)
	if _celda_ocupada(celda):
		return false   # no solapan (CO4)
	var tipo_sala: Resource = Datos.obtener(&"TipoSala", _salas[sala_id]["tipo"])
	if id_catalogo == ASIENTO_BASICO:
		if tipo_sala.tipo != "espera":
			return false
		# F3 (story 003): el asiento por encima del tope físico por área NO cabe — se rechaza.
		return _asientos_en(sala_id) < _plazas_max_de(sala_id)
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


## ¿Hay ya un elemento en esta celda?
func _celda_ocupada(celda: Vector2i) -> bool:
	for elemento: Dictionary in _elementos.values():
		if elemento["celda"] == celda:
			return true
	return false


## ¿El rectángulo cabe entero en el edificio? (CO1: toda construcción ocurre dentro).
func _dentro_del_edificio(rect: Rect2i) -> bool:
	return (
		rect.position.x >= 0 and rect.position.y >= 0
		and rect.end.x <= edificio_columnas and rect.end.y <= edificio_filas
	)


# ── Registro directo en el modelo (SIN validar ni cobrar — lo usan la story 002 y los tests) ──

## Da de alta una sala YA validada y pagada. Devuelve su id. `id_forzado` permite ids compat
## (`doc_1`... los usará el montaje inicial de la 006).
func _crear_sala(tipo_sala_id: StringName, rect: Rect2i, id_forzado: StringName = &"") -> StringName:
	var sala_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(&"sala")
	_salas[sala_id] = {"tipo": tipo_sala_id, "rect": rect}
	return sala_id


## Da de alta un elemento YA validado y pagado (guarda `coste_pagado` — lo necesita el reembolso F4).
func _crear_elemento(
	id_catalogo: StringName, celda: Vector2i, coste_pagado: float, id_forzado: StringName = &""
) -> StringName:
	var elemento_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(id_catalogo)
	_elementos[elemento_id] = {
		"catalogo": id_catalogo, "celda": celda, "sala": sala_en(celda), "coste_pagado": coste_pagado,
	}
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
	var tipo: Resource = Datos.obtener(&"TipoPuesto", id_catalogo)
	if tipo == null:
		return 0.0
	return _clamp_coste(float(tipo.coste_construccion_eur), id_catalogo)


## Construye una sala (CO3/CO6/CO9): valida F6 → cobra por el gate E4 → alta en el modelo. Devuelve
## el id creado o `&""` (rechazo de REGLA — inválido o sin caja — silencioso: la UI lo pinta en rojo).
func construir_sala(tipo_sala_id: StringName, rect: Rect2i) -> StringName:
	if not validar_sala(tipo_sala_id, rect):
		return &""
	if not _pagar(coste_sala(tipo_sala_id, rect)):
		return &""
	return _crear_sala(tipo_sala_id, rect)


## Construye un elemento (CO4/CO6/CO9): valida → cobra → alta guardando `coste_pagado` (F4). Si es
## un PUESTO, lo registra en Personal (puente de la story 003 — API `registrar_puesto` ya existente).
func construir_elemento(id_catalogo: StringName, celda: Vector2i) -> StringName:
	if not validar_elemento(id_catalogo, celda):
		return &""
	var coste: float = coste_elemento(id_catalogo)
	if not _pagar(coste):
		return &""
	var elemento_id: StringName = _crear_elemento(id_catalogo, celda, coste)
	if id_catalogo != ASIENTO_BASICO:
		if _personal != null:
			_personal.registrar_puesto(elemento_id, id_catalogo)
		else:
			push_warning("Construccion: puesto '%s' construido SIN Personal inyectado" % elemento_id)
	return elemento_id


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

## F3: aforo de una sala de espera = `min(asientos colocados, floor(área × densidad_asientos))`.
## Sala inexistente → 0 con aviso. Sin asientos → 0 (Flujo mandará a la cola exterior — su edge).
func aforo_de_sala(sala_id: StringName) -> int:
	if not _salas.has(sala_id):
		push_warning("Construccion: aforo de una sala inexistente ('%s') -> 0" % sala_id)
		return 0
	return mini(_asientos_en(sala_id), _plazas_max_de(sala_id))


## Asientos colocados en una sala.
func _asientos_en(sala_id: StringName) -> int:
	var total: int = 0
	for elemento: Dictionary in _elementos.values():
		if elemento["catalogo"] == ASIENTO_BASICO and elemento["sala"] == sala_id:
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


# ── Config (patrón Economía/Demanda/Personal: aplicar con clamp defensivo + fallback) ────────

## Copia los knobs del config con clamp defensivo y aviso. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigConstruccionScript):
		push_warning("Construccion: config invalido -> defaults")
		config = ConfigConstruccionScript.new()
	coste_por_celda = _clamp_knob(config.coste_por_celda, "coste_por_celda")
	densidad_asientos = clampf(config.densidad_asientos, 0.0, 1.0)
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
