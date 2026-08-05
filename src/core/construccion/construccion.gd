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
## La paleta de pintura (30 colores data-driven) — de aquí sale el BLANCO por defecto de las paredes.
const PaletaPinturaScript := preload("res://src/core/construccion/paleta_pintura.gd")

## Id especial del asiento básico (no vive en el catálogo — MVP; Comodidades #15 lo formalizará).
const ASIENTO_BASICO := &"asiento_basico"

## La puerta del edificio, por donde entra todo el mundo (misma celda que usan Flujo y Personal).
## Las puertas de las SALAS ya no salen de aquí: las coloca el jugador (quick-spec §3, 2026-08-04).
const CELDA_PUERTA_EDIFICIO := Vector2i(0, 6)
## Centinela de "esta sala no tiene puerta" (ninguna celda del edificio es negativa).
const CELDA_NULA_PUERTA := Vector2i(-1, -1)
## Los cuatro vecinos de una celda, con el lado por el que se sale hacia cada uno. En 4 direcciones
## a proposito: por una esquina en diagonal no se pasa, igual que en la vida real.
const VECINOS_4: Array = [
	[&"izquierda", Vector2i(-1, 0)], [&"derecha", Vector2i(1, 0)],
	[&"arriba", Vector2i(0, -1)], [&"abajo", Vector2i(0, 1)],
]

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var coste_por_celda: float = 20.0
var densidad_asientos: float = 0.7
var densidad_de_pie: float = 0.5
var pct_reembolso: float = 0.5
var area_min_sala: int = 4
var coste_mover: float = 0.0
var coste_asiento_basico: float = 25.0
var coste_muro: float = 15.0
var edificio_columnas: int = 24
var edificio_filas: int = 13

# ── El modelo lógico del layout (única fuente de verdad) ─────────────────────────────────────
## Salas construidas: `sala_id -> {tipo: StringName (id de TipoSala), rect: Rect2i}`.
var _salas: Dictionary[StringName, Dictionary] = {}
## Elementos construidos: `elemento_id -> {catalogo: StringName, celda: Vector2i (ANCLA),
## sala: StringName, coste_pagado: float, orientacion: int}`. El cuerpo (las celdas que ocupa de
## verdad) NO se guarda: se recalcula del catálogo con `_celdas_de` (asiento 1, mostrador 2, sofá 3…).
var _elementos: Dictionary[StringName, Dictionary] = {}
## MUROS LIBRES (2026-07-30): se pintan donde el jugador quiera, independientes de las salas.
##
## Un muro vive en la ARISTA entre dos celdas, no dentro de una celda: así no come superficie útil
## y dos salas pegadas pueden compartir tabique (mismo criterio que ya usa el dibujo de paredes).
## Clave: `"v:x:y"` = arista IZQUIERDA de la celda (x,y), o sea entre (x-1,y) y (x,y).
##        `"h:x:y"` = arista de ARRIBA de la celda (x,y), o sea entre (x,y-1) y (x,y).
## Con esas dos familias se puede describir cualquier tabique de la rejilla sin ambigüedad: cada
## arista tiene UNA sola clave posible, así que no hay muros duplicados por construcción.
var _muros: Dictionary[String, StringName] = {}
## Las aristas que son EL EDIFICIO en sí: la fachada y su puerta de acceso. Se levantan solas, no
## se pagan y NO SE PUEDEN DEMOLER — son el plano de la comisaría, no obra del jugador (petición
## del usuario 2026-07-30: *"deberíamos poner unos muros fijos que no se pueden modificar que es
## exactamente el diseño de la comisaría... poniendo además una puerta de acceso donde entren y
## salgan los npc"*). Viven en `_muros` como cualquier otro tabique —así el recinto, el paso y el
## dibujo los tratan igual sin ningún caso especial— y esta lista solo marca cuáles son intocables.
var _muros_fijos: Dictionary[String, bool] = {}
## ── PINTURA (2026-08-04) ────────────────────────────────────────────────────────────────────
## Color de cada TRAMO DE PARED pintado, por su clave de arista (el mismo convenio col:row de
## `clave_de_muro`, así que es la misma llave que ya usan `_muros` y `_muros_fijos` — cero
## traducciones). Lo que NO está aquí se dibuja con `COLOR_PARED_POR_DEFECTO` (azul suave de la
## paleta clara): desde hoy el
## color por tipo de sala MUERE en las paredes (decisión del usuario, quick-spec §2).
var _color_muros: Dictionary[String, Color] = {}
## Color de cada CELDA DE SUELO pintada. Lo que no está aquí cae al tinte de su sala
## (`_color_de_sala`), que sigue siendo quien da el color de fondo de una zona sin pintar.
## Pertenece a la CELDA, no a la sala: demoler la sala no borra la pintura del suelo, igual que
## derribar un tabique no repinta la habitación.
var _color_suelos: Dictionary[Vector2i, Color] = {}
## ACABADO de cada CELDA DE SUELO pintada (2026-08-05 · quick-spec §3d, tarea 4): `&"baldosa"`
## (juntas + variación de tono, lo de siempre) o `&"liso"` (color plano, como el suelo crema del
## arranque). Vive PAREJA a `_color_suelos` (misma clave, se escriben siempre juntos en
## `pintar_suelo`/`pintar_sala_suelo`/`pintar_edificio_suelos`) — lo que no está aquí nunca se pinta,
## así que no hay desincronización posible. Petición del usuario: *"los colores del suelo siempre son
## baldosas cuando se pinta, se debería poner esa textura que hay ahora como suelo baldosa o liso
## como está al inicio la sala de la comisaria"*.
var _acabado_suelos: Dictionary[Vector2i, StringName] = {}

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
## Bug corregido 2026-07-29 (petición del usuario jugando: "el sofá de 3 plazas debe ocupar 3 huecos,
## ahora solo ocupa 1, se amontonan"): `celda` es solo el ANCLA — la HUELLA entera (`_celdas_de`)
## tiene que caer DENTRO DE LA MISMA sala que el ancla (ni salirse del edificio ni pisar la sala de al
## lado) y estar libre de otros elementos (CO4).
## Un PUESTO mide 2×3 = 6 celdas desde el 2026-08-03 (mostrador + silla del funcionario + silla del
## ciudadano), así que esta misma regla es la que exige que LAS SEIS estén libres y en la MISMA sala
## — sin código nuevo: la huella sale del catálogo.
func validar_elemento(
	id_catalogo: StringName, celda: Vector2i, ignorar: StringName = &"",
	orientacion: int = HORIZONTAL
) -> bool:
	return _validar_elemento_con(id_catalogo, celda, ignorar, orientacion, HUELLA_COMPLETA)


## La validación de arriba a un ESCALÓN de huella concreto. Solo la usan la migración de saves
## (`migrar_huella_puestos`) y el trazado de oficio (`construir_de_oficio_elemento`), que necesitan
## preguntar si un puesto que no cabe con sus 6 celdas cabe al menos con su mostrador, o con su sola
## celda de trabajo. El jugador siempre construye y mueve con la huella COMPLETA.
func _validar_elemento_con(
	id_catalogo: StringName, celda: Vector2i, ignorar: StringName, orientacion: int,
	nivel: int
) -> bool:
	var sala_id: StringName = sala_en(celda)
	if sala_id == &"":
		return false   # fuera de toda sala (los elementos viven dentro de salas — CO4)
	# Una pieza de TECHO sí tiene que estar dentro de la sala, pero NO le importa lo que haya en el
	# suelo: se cuelga encima. (`_celda_ocupada` ya ignora a las de techo en el otro sentido, así que
	# tampoco impide colocar nada debajo de ellas.)
	var de_techo: bool = es_de_techo(id_catalogo)
	for c: Vector2i in _celdas_de(id_catalogo, celda, orientacion, nivel):
		if sala_en(c) != sala_id:
			return false   # la huella no cabe entera: se sale de la sala (CO4)
		if not de_techo and _celda_ocupada(c, ignorar):
			return false   # pisa algo que ya está en el suelo (CO4)
		# UNA PUERTA NO SE TAPIA CON UN MUEBLE (2026-08-04). Antes la puerta era automatica y podia
		# APARTARSE sola a otra celda libre; desde que la pone el jugador (quick-spec §3) es un tramo
		# de pared REAL, y un tramo no se mueve: si dejaramos poner una mesa delante, el hueco por el
		# que se entra quedaria bloqueado sin que nada avisara. Asi que la regla es simple y honesta:
		# en una celda con puerta no se coloca nada.
		if es_celda_de_puerta(c):
			return false
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
			"iluminacion":
				# Una lámpara vale en CUALQUIER sala (petición del usuario 2026-07-29: "no veo tampoco
				# la instalación de luces para la noche"). Es la única familia sin sala propia, y por
				# eso existe: lo que compra el jugador es VER, no un multiplicador de ningún sistema.
				return true
			_:
				return tipo_sala.tipo == "oficina"
	var tipo_puesto: Resource = Datos.obtener(&"TipoPuesto", id_catalogo)
	if tipo_puesto == null:
		return false   # Datos ya avisó
	return id_catalogo in tipo_sala.puestos_admitidos


## La sala que contiene una celda (&"" si ninguna). Determinista: las salas nunca solapan.
func sala_en(celda: Vector2i) -> StringName:
	for sala_id: StringName in _salas:
		# Por el CONJUNTO de celdas, no por el rectangulo: desde la fase B una sala puede tener forma
		# no rectangular, y entonces su caja envolvente incluye huecos que NO son suyos.
		if _salas[sala_id].get("celdas", {}).has(celda):
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


## ¿Hay ya un elemento CUYA HUELLA cubra esta celda? (`ignorar` excluye a uno — para revalidar al
## moverlo). Un sofá de superficie 3 ocupa sus 3 celdas para este chequeo, no solo su ancla
## (petición del usuario 2026-07-29), y un puesto sus 6: la silla del funcionario está tan reservada
## como el mostrador — ahí no se pone una papelera.
func _celda_ocupada(celda: Vector2i, ignorar: StringName = &"") -> bool:
	for elemento_id: StringName in _elementos:
		if elemento_id == ignorar:
			continue
		var elemento: Dictionary = _elementos[elemento_id]
		if es_de_techo(elemento["catalogo"]):
			continue   # cuelga del techo: no ocupa suelo, así que no estorba a nadie
		if celda in _huella_de(elemento):
			return true
	return false


## ── LA HUELLA DEL PUESTO: 2×3 = 6 CELDAS (decisión de diseño 2026-08-03) ────────────────────────
## Petición del usuario: *"vamos a tratar los 3 elementos como 1 solo: la silla del ciudadano, la
## mesa y la silla del policía; 6 cuadrículas en total, 2×3 — 2 a lo ancho (el ancho de la mesa) y 3
## de fondo: silla-mesa-silla"*. Una ventanilla no es un mueble suelto: es un PUESTO ENTERO, y lo que
## reserva en la rejilla es el bloque completo. Así el jugador no puede meter una papelera en la silla
## del funcionario ni pegar dos ventanillas espalda contra espalda.
##
##       ┌───────┬───────┐   fila DETRÁS  (norte): la silla del funcionario
##       │       │       │
##       ├───────┼───────┤   fila del ANCLA: EL MOSTRADOR (2 celdas de ancho)  ← celda de trabajo
##       │ ancla │       │
##       ├───────┼───────┤   fila DELANTE (sur): la silla / el hueco del ciudadano
##       │       │       │
##       └───────┴───────┘
##
## El dato vive en el CATÁLOGO, no aquí: `TipoPuesto.superficie` (= 2, el ancho del mostrador) ×
## `TipoPuesto.fondo_detras` + 1 + `TipoPuesto.fondo_delante` (= 1 + 1 + 1 = 3 filas). Lo que NO
## declara fondo (el sofá de 3, las comodidades de 1) se comporta EXACTAMENTE igual que antes: una
## sola fila, que es el caso 0/0. La huella es una propiedad del objeto, igual que su precio.
##
## El ANCLA sigue siendo la **CELDA DE TRABAJO** (`celda_de_trabajo`): la de siempre, la que devuelve
## `posicion_de` y la única que miran Flujo y Personal — el funcionario atiende desde la celda de
## ARRIBA (norte) y el ciudadano espera en la de ABAJO (sur). Ampliar la huella NO movió esa
## invariante: por eso este cambio no toca ni una línea de Flujo ni de Personal.
##
## ⚠️ DOS CONJUNTOS DE CELDAS DISTINTOS — no confundirlos:
##   · **COLOCACIÓN** (`celdas_de_elemento`, las 6): lo que el puesto RESERVA. La validación exige
##     las 6 libres y en la misma sala, la demolición las libera y `elemento_en` responde en las 6.
##   · **OBSTÁCULO** (`celdas_obstaculo_de`, las 2 del mostrador): lo que BLOQUEA EL PASO. Las filas
##     de las sillas tienen que seguir siendo PISABLES o el funcionario y el ciudadano no podrían
##     llegar andando a sentarse — el mueble que estorba es la mesa, no la silla de nadie.
## La navegación (`NPCsFlujo._bakear_navegacion`) recorta la segunda, NUNCA la primera.
##
## Se rota como cualquier otra pieza (R): girar mueve el bloque entero en rígido (`_paso_de` da el eje
## largo del mostrador y `_perpendicular_de` el del fondo).
##
## ── LOS TRES ESCALONES DE LA HUELLA (política de migración y de trazado de oficio) ──────────────
## Un puesto que NO cabe con sus 6 celdas no desaparece ni se mueve solo: BAJA UN ESCALÓN. Están
## ordenados de MÁS a MENOS huella a propósito (`maxi` sobre ellos = "recorta al menos hasta aquí").
const HUELLA_COMPLETA: int = 0   ## Lo que dice el catálogo: mostrador + fila del funcionario + fila del ciudadano.
const HUELLA_SIN_FONDO: int = 1  ## Solo el mostrador (2 celdas): el bloque no cabe, el mueble sí.
const HUELLA_MINIMA: int = 2     ## Solo la celda de trabajo (1 celda): el suelo — una ventanilla nunca se pierde.
## Los escalones en el orden en que se prueban (de más huella a menos).
const NIVELES_HUELLA: Array[int] = [HUELLA_COMPLETA, HUELLA_SIN_FONDO, HUELLA_MINIMA]
## Clave del escalón en la ficha de un elemento colocado. NO se serializa: se vuelve a deducir del
## layout en cada carga (`migrar_huella_puestos`), así que no puede quedar obsoleta.
const CLAVE_NIVEL_HUELLA := "huella_nivel"
## Los dos campos de fondo del catálogo. Se leen con `in` para que añadirlos mañana a `Comodidad`
## —una cabina de fotos con su banqueta, por ejemplo— funcione sin tocar este archivo.
const CAMPO_FONDO_DETRAS := &"fondo_detras"
const CAMPO_FONDO_DELANTE := &"fondo_delante"


## Superficie (celdas) de un id de catálogo A LO LARGO de su eje largo. `Comodidad.superficie` y
## `TipoPuesto.superficie` comparten el mismo campo (el mostrador vale 2, el sofá 3, casi todo lo
## demás 1); el asiento básico no vive en el catálogo (MVP) y siempre ocupa 1. Id inexistente → 1
## (validar_elemento ya avisa por su cuenta; no se duplica aquí).
func _superficie_de(id_catalogo: StringName) -> int:
	if id_catalogo == ASIENTO_BASICO:
		return 1
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
	if comodidad != null:
		return maxi(comodidad.superficie, 1)
	var tipo_puesto: Resource = Datos.obtener_silencioso(&"TipoPuesto", id_catalogo)
	if tipo_puesto != null:
		return maxi(tipo_puesto.superficie, 1)
	return 1


## El FONDO de un id de catálogo: cuántas filas reserva DETRÁS (`.x`, el lado del funcionario) y
## DELANTE (`.y`, el lado del ciudadano) de su propia fila. `(0,0)` = pieza de una sola fila, que es
## todo lo que no sea un puesto (y era el comportamiento único hasta el 2026-08-03).
func _fondo_de(id_catalogo: StringName) -> Vector2i:
	if id_catalogo == ASIENTO_BASICO:
		return Vector2i.ZERO
	var ficha: Resource = Datos.obtener_silencioso(&"TipoPuesto", id_catalogo)
	if ficha == null:
		ficha = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
	if ficha == null:
		return Vector2i.ZERO
	var detras: int = 0
	var delante: int = 0
	if CAMPO_FONDO_DETRAS in ficha:
		detras = maxi(int(ficha.get(CAMPO_FONDO_DETRAS)), 0)
	if CAMPO_FONDO_DELANTE in ficha:
		delante = maxi(int(ficha.get(CAMPO_FONDO_DELANTE)), 0)
	return Vector2i(detras, delante)


## ¿Esta pieza del catálogo va colgada del TECHO? Una pieza de techo (un fluorescente, un foco) no
## ocupa suelo: se puede poner encima de un mostrador o de un sofá, porque no está en medio. La
## lámpara de pie NO lo es. Petición del usuario 2026-07-30. El dato vive en el catálogo (`Comodidad
## .en_techo`), no aquí: si mañana hay un ventilador de techo, basta con marcarlo en su `.tres`.
func es_de_techo(id_catalogo: StringName) -> bool:
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
	return comodidad != null and comodidad.en_techo


## La HUELLA de un elemento: TODAS las celdas que reserva. La celda de colocación es el ANCLA; el
## cuerpo (el mueble) se extiende desde ella `superficie - 1` celdas hacia +X (o hacia +Y si está
## girado), y el FONDO añade filas paralelas detrás y delante (el puesto: la silla del funcionario y
## la del ciudadano). Sin formas en L: la huella siempre es un rectángulo.
##
## SIEMPRE se recalcula desde el catálogo, nunca se guarda (ver `save`/`load_state`) — así no puede
## desincronizarse del dato si la huella del catálogo cambia de valor entre partidas.
##
## `nivel` recorta por escalones (ver `HUELLA_COMPLETA`/`HUELLA_SIN_FONDO`/`HUELLA_MINIMA`): lo usan
## la migración de saves y el trazado de oficio para preguntar "¿y si cabe con menos?".
##
## ORDEN GARANTIZADO: primero la fila del ancla (`celdas[0]` es SIEMPRE la celda de trabajo), después
## las filas de detrás y por último las de delante. Hay código y tests que dependen de `celdas[0]`.
func _celdas_de(
	id_catalogo: StringName, celda_ancla: Vector2i, orientacion: int = HORIZONTAL,
	nivel: int = HUELLA_COMPLETA
) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var paso: Vector2i = _paso_de(orientacion)
	var largo: int = 1 if nivel == HUELLA_MINIMA else _superficie_de(id_catalogo)
	for i: int in range(largo):
		celdas.append(celda_ancla + paso * i)
	if nivel != HUELLA_COMPLETA:
		return celdas   # escalón recortado: solo el mueble (o solo la celda de trabajo)
	var fondo: Vector2i = _fondo_de(id_catalogo)
	if fondo == Vector2i.ZERO:
		return celdas   # pieza de una sola fila (todo lo que no es un puesto)
	var perpendicular: Vector2i = _perpendicular_de(orientacion)
	for fila: int in range(1, fondo.x + 1):        # DETRÁS: el lado del funcionario
		for i: int in range(largo):
			celdas.append(celda_ancla - perpendicular * fila + paso * i)
	for fila: int in range(1, fondo.y + 1):        # DELANTE: el lado del ciudadano
		for i: int in range(largo):
			celdas.append(celda_ancla + perpendicular * fila + paso * i)
	return celdas


## El vector de UNA celda en la dirección en la que crece el cuerpo de un elemento según su
## orientación (`HORIZONTAL` → este, `VERTICAL` → sur) — fuente única de esta cuenta: la comparten
## la reserva de celdas del modelo (arriba) y el ancla visual de los sprites multi-celda
## (`_crear_pieza`, vía `Proyeccion.delta_ultima_celda`).
func _paso_de(orientacion: int) -> Vector2i:
	return Vector2i(0, 1) if orientacion == VERTICAL else Vector2i(1, 0)


## El vector de UNA celda hacia DELANTE (el lado del ciudadano); hacia detrás es el mismo en negativo.
## Es `_paso_de` girado 90° en el mismo sentido, así que rotar una pieza con fondo la gira ENTERA y
## rígida: en `HORIZONTAL` el mostrador crece al este y su fondo va norte/sur (el ciudadano al SUR,
## que es justo donde lo planta Flujo: `celda + (0,1)`); en `VERTICAL`, mostrador al sur y fondo
## este/oeste.
func _perpendicular_de(orientacion: int) -> Vector2i:
	return Vector2i(-1, 0) if orientacion == VERTICAL else Vector2i(0, 1)


## La HUELLA de un elemento YA COLOCADO (lo que RESERVA: las 6 celdas de un puesto), a partir de su
## ficha del modelo. Punto ÚNICO por el que pasa todo el que pregunta qué sitio ocupa algo puesto:
## así el escalón de huella recortada (un puesto que no cabía entero) se respeta a la vez en la
## validación, en la demolición y en el clic.
func _huella_de(elemento: Dictionary) -> Array[Vector2i]:
	return _celdas_de(
		elemento["catalogo"], elemento["celda"], elemento.get("orientacion", HORIZONTAL),
		int(elemento.get(CLAVE_NIVEL_HUELLA, HUELLA_COMPLETA))
	)


## El CUERPO de un elemento YA COLOCADO: el mueble en sí, sin las filas del fondo. Es lo que BLOQUEA
## EL PASO — a una silla se llega andando, a través del mostrador no. `maxi` con `HUELLA_SIN_FONDO`
## porque los escalones van de más a menos huella: quita el fondo, y si el elemento ya venía más
## recortado (huella mínima), respeta lo suyo.
func _cuerpo_de(elemento: Dictionary) -> Array[Vector2i]:
	var nivel: int = int(elemento.get(CLAVE_NIVEL_HUELLA, HUELLA_COMPLETA))
	return _celdas_de(
		elemento["catalogo"], elemento["celda"], elemento.get("orientacion", HORIZONTAL),
		maxi(nivel, HUELLA_SIN_FONDO)
	)


## Las celdas que un elemento colocado RESERVA (COLOCACIÓN): las 6 de un puesto, las 3 de un sofá, la
## 1 de una papelera. Nada se puede construir encima de ellas y la demolición las libera todas.
## ⚠️ Para la NAVEGACIÓN NO es esta: es `celdas_obstaculo_de` (las sillas se pisan).
func celdas_de_elemento(elemento_id: StringName) -> Array[Vector2i]:
	if not _elementos.has(elemento_id):
		return []
	return _huella_de(_elementos[elemento_id])


## Las celdas que un elemento colocado BLOQUEA FÍSICAMENTE (OBSTÁCULO): el mueble, sin las filas del
## fondo. Es lo que recorta la navegación (`NPCsFlujo._bakear_navegacion`) — bloquear las 6 de un
## puesto dejaría al funcionario y al ciudadano sin forma de llegar andando a sus sillas.
func celdas_obstaculo_de(elemento_id: StringName) -> Array[Vector2i]:
	if not _elementos.has(elemento_id):
		return []
	return _cuerpo_de(_elementos[elemento_id])


## Cómo está girado un elemento colocado (`HORIZONTAL` si no consta — saves antiguos).
func orientacion_de(elemento_id: StringName) -> int:
	if not _elementos.has(elemento_id):
		return HORIZONTAL
	return _elementos[elemento_id].get("orientacion", HORIZONTAL)


## ¿El rectángulo cabe entero en el edificio? (CO1: toda construcción ocurre dentro).
func _dentro_del_edificio(rect: Rect2i) -> bool:
	return (
		rect.position.x >= 0 and rect.position.y >= 0
		and rect.end.x <= edificio_columnas and rect.end.y <= edificio_filas
	)


# ── Registro directo en el modelo (SIN validar ni cobrar — lo usan la story 002 y los tests) ──

## Da de alta una sala YA validada y pagada (guarda `coste_pagado` — reembolso F4). Devuelve su id.
## `id_forzado` permite ids compat (`doc_1`... los usará el montaje inicial de la 006).
## `con_paredes`: 0 = lo que diga el tipo · 1 = forzar CON paredes · -1 = forzar SIN paredes.
func _crear_sala(
	tipo_sala_id: StringName, rect: Rect2i, coste_pagado: float = 0.0, id_forzado: StringName = &"",
	con_paredes: int = 0
) -> StringName:
	var sala_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(&"sala")
	var tipo: Resource = Datos.obtener_silencioso(&"TipoSala", tipo_sala_id)
	_salas[sala_id] = {
		"celdas": _celdas_del_rect(rect),
		"tipo": tipo_sala_id, "rect": rect, "coste_pagado": coste_pagado,
	}
	# Las paredes son OPCIONALES por sala. El tipo pone el valor de partida (la de descanso nace
	# cerrada por intimidad; el resto, en planta diafana) y `con_paredes` permite forzarlo desde la UI.
	# Se LEVANTAN MUROS DE VERDAD, no un flag: es lo unico que se ve y lo unico que bloquea.
	# De oficio (coste_pagado 0 = montaje inicial de la DGP) los muros tampoco se cobran.
	var cerrar: bool = bool(tipo.paredes_por_defecto) if tipo != null else false
	if con_paredes != 0:
		cerrar = con_paredes > 0
	if cerrar:
		for arista: Array in _aristas_del_perimetro(sala_id):
			if coste_pagado > 0.0:
				construir_muro(arista[0], arista[1])
			else:
				_muros[clave_de_muro(arista[0], arista[1])] = TABIQUE
	_refrescar_visual()
	return sala_id


## Celdas -> JSON (lista de pares [x, y]).
func _celdas_a_json(celdas: Dictionary) -> Array:
	var salida: Array = []
	for celda: Vector2i in celdas:
		salida.append([celda.x, celda.y])
	return salida


## JSON -> celdas. Sin datos validos, se reconstruyen del rect (compatibilidad con saves previos a
## la fase B, donde toda sala era un rectangulo).
func _celdas_desde_json(datos: Variant, rect: Rect2i) -> Dictionary[Vector2i, bool]:
	var celdas: Dictionary[Vector2i, bool] = {}
	if datos is Array and not (datos as Array).is_empty():
		for par: Variant in datos:
			if par is Array and (par as Array).size() == 2:
				celdas[Vector2i(int(par[0]), int(par[1]))] = true
	if celdas.is_empty():
		return _celdas_del_rect(rect)
	return celdas


## Las celdas de un rectángulo, como diccionario (búsqueda O(1)).
##
## FASE B de los muros libres (2026-07-30): una sala pasa de ser SOLO un rectángulo a ser un
## CONJUNTO DE CELDAS, para que pueda tener cualquier forma cuando las zonas se marquen dentro de lo
## que el jugador haya cerrado con muros. El `rect` se conserva como CAJA ENVOLVENTE —lo siguen
## usando el centro de sala que cronometra los caminos, el dibujo y la validación de solapes—, así
## que la migración es aditiva: una sala rectangular tiene exactamente las celdas de su rect y todo
## lo de antes sigue dando el mismo resultado.
func _celdas_del_rect(rect: Rect2i) -> Dictionary[Vector2i, bool]:
	var celdas: Dictionary[Vector2i, bool] = {}
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			celdas[Vector2i(x, y)] = true
	return celdas


## Las celdas que ocupa una sala (vacío si no existe). Lo consultan el aforo, el coste y el dibujo:
## desde la fase B es ESTO —y no el área del rectángulo— lo que define cuánto mide una sala.
func celdas_de_sala(sala_id: StringName) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not _salas.has(sala_id):
		return resultado
	for celda: Vector2i in _salas[sala_id].get("celdas", {}):
		resultado.append(celda)
	return resultado


## Cuántas celdas mide una sala. Sustituye a `rect.get_area()` en aforo y coste: con formas no
## rectangulares el área de la caja envolvente MIENTE (cuenta huecos que no son de la sala).
func area_de_sala(sala_id: StringName) -> int:
	if not _salas.has(sala_id):
		return 0
	return _salas[sala_id].get("celdas", {}).size()


# ── FASE C: zonas dentro de lo que has cerrado con muros (2026-07-30) ────────────────────────

## Las celdas del RECINTO al que pertenece `origen`: todo lo que se puede alcanzar desde ahí sin
## cruzar un muro y sin salirse del edificio.
##
## Es el corazón del modelo que pidió el usuario (*"la construcción de las paredes debe ser libre y
## luego dentro poner las zonas"*): primero levantas tabiques, y el hueco que queda encerrado ES la
## zona. No hay que dibujar ningún rectángulo — la forma la decide lo que hayas construido.
##
## El perímetro del edificio cuenta como muro implícito, así que sin ningún tabique TODO el interior
## es un único recinto. Cada muro que levantas lo subdivide.
##
## Relleno por inundación en 4 direcciones (nada de diagonales: por una esquina no se pasa).
func recinto_de(origen: Vector2i) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	if not _celda_en_edificio(origen):
		return celdas
	var vistas: Dictionary[Vector2i, bool] = {}
	var pila: Array[Vector2i] = [origen]
	while not pila.is_empty():
		var celda: Vector2i = pila.pop_back()
		if vistas.has(celda):
			continue
		vistas[celda] = true
		celdas.append(celda)
		for paso: Array in VECINOS_4:
			if hay_muro(celda, paso[0]):
				continue                      # ese lado esta tabicado: por ahi no se sigue
			var vecina: Vector2i = celda + (paso[1] as Vector2i)
			if _celda_en_edificio(vecina) and not vistas.has(vecina):
				pila.append(vecina)
	return celdas


## CUÁNTAS CUADRÍCULAS hay que recorrer para ir de una celda a otra, esquivando muros.
##
## Petición del usuario (2026-07-30): *"los tiempos hay que poner una formula, tantas cuadriculas por
## X para saber lo que dura en recorrer su puesto de trabajo y por lo tanto cuanto tiempo tiene que
## entrar antes"*. Justo eso: esta función da las CUADRÍCULAS y quien pregunta las multiplica por sus
## minutos por celda.
##
## Es un recorrido en anchura (BFS) sobre la rejilla, cruzando solo por donde `deja_pasar` — o sea,
## por hueco libre o por PUERTA. Devuelve **-1 si no hay camino** (por ejemplo, un espacio cerrado sin
## puerta): quien pregunta decide qué hacer con ese caso, en vez de recibir un número inventado.
##
## Antes de esto los tres cronómetros del juego medían en LÍNEA RECTA, así que en cuanto una pared
## obligaba a rodear el reloj mentía. Se calcula sobre el MODELO (rejilla y muros), nunca sobre la
## navegación visual: es determinista y funciona igual en headless.
func distancia_en_celdas(origen: Vector2i, destino: Vector2i) -> int:
	if not _celda_en_edificio(origen) or not _celda_en_edificio(destino):
		return -1
	if origen == destino:
		return 0
	var distancia: Dictionary[Vector2i, int] = {origen: 0}
	var cola: Array[Vector2i] = [origen]
	var cabeza: int = 0
	while cabeza < cola.size():
		var celda: Vector2i = cola[cabeza]
		cabeza += 1
		var d: int = distancia[celda]
		for paso: Array in VECINOS_4:
			if not deja_pasar(celda, paso[0]):
				continue                       # tabique o ventana: por ahi no se pasa
			var vecina: Vector2i = celda + (paso[1] as Vector2i)
			if not _celda_en_edificio(vecina) or distancia.has(vecina):
				continue
			if vecina == destino:
				return d + 1
			distancia[vecina] = d + 1
			cola.append(vecina)
	return -1   # incomunicado: no hay forma de llegar


## Convierte en ZONA (sala) el recinto que contiene esa celda, cobrándolo. Devuelve el id de la sala
## nueva, o `&""` si no se pudo: recinto demasiado pequeño, tipo inexistente, sin caja, o el recinto
## pisa una sala que ya existe (primero hay que demolerla — no se solapan zonas en silencio).
func designar_zona(origen: Vector2i, tipo_sala_id: StringName) -> StringName:
	if Datos.obtener(&"TipoSala", tipo_sala_id) == null:
		return &""   # Datos ya avisó
	var celdas: Array[Vector2i] = recinto_de(origen)
	if celdas.size() < area_min_sala:
		push_warning("Construccion: recinto demasiado pequeno (%d celdas) -> no se designa" % celdas.size())
		return &""
	for celda: Vector2i in celdas:
		if sala_en(celda) != &"":
			push_warning("Construccion: el recinto pisa una sala existente -> demolela antes")
			return &""
	var tipo: Resource = Datos.obtener(&"TipoSala", tipo_sala_id)
	var coste: float = (
		_clamp_coste(float(tipo.coste_construccion_eur), tipo_sala_id)
		+ coste_por_celda * float(celdas.size())
	)
	if not _pagar(coste):
		return &""
	return _crear_sala_con_celdas(tipo_sala_id, celdas, coste)


## Da de alta una sala con una FORMA CUALQUIERA (fase C). El `rect` que se guarda es su caja
## envolvente —lo siguen usando el centro de sala de los cronómetros y el dibujo—, pero lo que manda
## para el aforo, el coste y a quién pertenece cada celda es el conjunto.
func _crear_sala_con_celdas(
	tipo_sala_id: StringName, celdas: Array[Vector2i], coste_pagado: float
) -> StringName:
	var sala_id: StringName = _nuevo_id(&"sala")
	var mapa: Dictionary[Vector2i, bool] = {}
	var caja: Rect2i = Rect2i(celdas[0], Vector2i.ONE)
	for celda: Vector2i in celdas:
		mapa[celda] = true
		caja = caja.merge(Rect2i(celda, Vector2i.ONE))
	var tipo: Resource = Datos.obtener_silencioso(&"TipoSala", tipo_sala_id)
	_salas[sala_id] = {
		"celdas": mapa, "tipo": tipo_sala_id, "rect": caja, "coste_pagado": coste_pagado,
	}
	_refrescar_visual()
	return sala_id


## ── MUERE LA PUERTA AUTOMÁTICA (2026-08-04 · quick-spec §3) ─────────────────────────────────────
## Hasta hoy, toda sala nacía con un `"puerta"` en su diccionario: una celda del perímetro elegida
## sola (la más cercana al acceso del edificio) que el DIBUJO pintaba como hueco. Ese hueco era una
## mentira útil que dejó de serlo: en el MODELO la arista seguía siendo tabique macizo, así que se
## veía un vano por el que en realidad no se pasaba, y el jugador nunca decidía dónde entrar.
##
## Ahora **una sala amurallada es un recinto cerrado** y la puerta la elige el jugador con el pincel
## (`fijar_tipo_de_muro(&"puerta")`), que es lo único que abre paso de verdad (`deja_pasar`). Una
## sala sin puerta ya no rompe nada: los NPC sin camino esperan quietos con su señal 🚫 (mecánica de
## accesos, 2026-08-03).
##
## Consecuencia: `puerta_de_sala` deja de ser un dato GUARDADO y pasa a DERIVARSE de los muros
## reales (ver abajo). Una fuente de verdad menos que pueda mentir — el mismo remedio que ya se
## aplicó al flag `paredes` de las salas.


# ── MUROS LIBRES (2026-07-30) ────────────────────────────────────────────────────────────────

## Los tres tipos de tabique (fase D, 2026-07-30). Todos SON pared a efectos de recinto —una puerta
## cierra la habitación igual que un muro—, pero solo la puerta deja PASAR (fase E).
## ── ORIENTACIÓN DE LOS ELEMENTOS (rotar con R, 2026-07-30) ─────────────────────────────────
## Petición del usuario: *"debe poder rotarse un objeto con la R por ejemplo"*. Un elemento de
## varias celdas (el sofá de 3, el mostrador) crece desde su ancla en UNA dirección; girar es
## elegir cuál. `HORIZONTAL` (crece hacia +X) es el valor de SIEMPRE, así que todo lo construido
## antes de hoy —y todos los tests— siguen comportándose exactamente igual sin tocar nada.
const HORIZONTAL: int = 0
const VERTICAL: int = 1


const TABIQUE := &"muro"
const PUERTA := &"puerta"
const VENTANA := &"ventana"


## Qué hay en esa arista: `TABIQUE`, `PUERTA`, `VENTANA`, o `&""` si no hay nada.
func tipo_de_muro(celda: Vector2i, lado: StringName) -> StringName:
	return _muros.get(clave_de_muro(celda, lado), &"")


## El tipo de una arista dada ya por su CLAVE (la capa visual recorre `muros()`, que devuelve claves,
## y necesita saber cual es puerta para no recortarla de la navegacion).
func tipo_muro_de_clave(clave: String) -> StringName:
	return _muros.get(clave, &"")


## ¿Se puede PASAR por esa arista? Solo por donde no hay nada... o por una puerta.
##
## Esta es la distinción que hace que el sistema funcione: para decidir QUÉ ESPACIO ENCIERRAS
## (`recinto_de`) una puerta cuenta como pared —si no, la habitación se escaparía por su propia
## puerta y no sería una habitación—; pero para MOVERSE, la puerta se cruza. Son dos preguntas
## distintas y por eso hay dos funciones.
func deja_pasar(celda: Vector2i, lado: StringName) -> bool:
	var tipo: StringName = tipo_de_muro(celda, lado)
	return tipo == &"" or tipo == PUERTA


## Convierte un tabique YA construido en puerta o ventana (o al revés, con `TABIQUE`). No cuesta: el
## gasto fue levantar el muro; abrir un hueco en él es parte de esa misma obra.
func fijar_tipo_de_muro(celda: Vector2i, lado: StringName, tipo: StringName) -> bool:
	var clave: String = clave_de_muro(celda, lado)
	if clave == "" or not _muros.has(clave):
		return false   # no hay muro que convertir: primero se levanta la pared
	if _muros_fijos.has(clave):
		return false   # la fachada no se toca: ni se tapia su puerta ni se abren huecos nuevos
	if tipo != TABIQUE and tipo != PUERTA and tipo != VENTANA:
		push_warning("Construccion: tipo de muro desconocido ('%s')" % tipo)
		return false
	_muros[clave] = tipo
	_refrescar_visual()
	return true


## La clave de la arista entre `celda` y su vecina en la dirección `lado`. Normaliza a propósito:
## el tabique entre (3,5) y (4,5) es EL MISMO se mire desde la izquierda o desde la derecha, así que
## las dos formas de nombrarlo devuelven la misma clave. Sin esto se podrían pintar dos muros
## encima, uno "de cada sala", y borrar uno dejaría el otro.
func clave_de_muro(celda: Vector2i, lado: StringName) -> String:
	match lado:
		&"izquierda":
			return "v:%d:%d" % [celda.x, celda.y]
		&"derecha":
			return "v:%d:%d" % [celda.x + 1, celda.y]
		&"arriba":
			return "h:%d:%d" % [celda.x, celda.y]
		&"abajo":
			return "h:%d:%d" % [celda.x, celda.y + 1]
		_:
			push_warning("Construccion: lado de muro desconocido ('%s')" % lado)
			return ""


## ── PINTURA POR CARA (2026-08-06 · quick-spec §3f) ──────────────────────────────────────────
## Una arista separa DOS celdas, y desde hoy cada una tiene SU PROPIO color: pedido del usuario
## (*"si le doy a mayús solo pinta el interior... no las 2 caras, por fuera y por dentro"*).
## Convenio fijo, documentado solo aquí: **"b" es la cara de la celda de MAYOR coordenada** — la
## celda `(x,y)` que la propia clave YA codifica literalmente (ver la tabla de arriba): la SUR en
## una arista horizontal, la ESTE en una vertical. **"a" es la de MENOR coordenada** (norte/oeste).
## Con esto una arista tiene siempre dos caras nombrables sin ambigüedad y sin mirar qué sala hay a
## cada lado — las claves de `_color_muros` pasan a ser "clave_de_arista:a"/"...:b".
const SUFIJO_CARA_A := ":a"
const SUFIJO_CARA_B := ":b"


## La CARA de un muro que mira hacia `celda`, en el lado `lado` — la clave que usa `_color_muros`.
## Es `clave_de_muro(celda, lado)` con el sufijo que le corresponde a ESA celda (ver la cabecera de
## `SUFIJO_CARA_A`/`_B`): `&"arriba"` y `&"izquierda"` dejan a `celda` del lado de MAYOR coordenada
## (la propia `celda` es la "b" — `clave_de_muro` la usa tal cual, sin sumar nada); `&"abajo"` y
## `&"derecha"` la dejan del lado de MENOR coordenada ("a" — `clave_de_muro` suma 1 para nombrar la
## arista, así que `celda` queda al otro lado). "" si `lado` no es uno de los cuatro válidos (mismo
## criterio de error que `clave_de_muro`).
func clave_de_cara(celda: Vector2i, lado: StringName) -> String:
	var clave_arista: String = clave_de_muro(celda, lado)
	if clave_arista == "":
		return ""
	var es_b: bool = lado == &"arriba" or lado == &"izquierda"
	return clave_arista + (SUFIJO_CARA_B if es_b else SUFIJO_CARA_A)


## Reconstruye un par (celda, lado) VÁLIDO para una clave de arista — el inverso de `clave_de_muro`,
## para volver de una clave suelta (o de un tramo ya dibujado, ver `ParedesSalas.tramo_bajo_punto`)
## a la pareja que exige el resto de la API de muros (`pintar_muro_en`, `demoler_muro`,
## `fijar_tipo_de_muro`, `hay_muro`...). No es la ÚNICA pareja válida —cada arista se nombra desde
## sus dos celdas— pero es estable: la celda literal de la clave (la cara "b") con el lado que "mira
## hacia atrás" (arriba/izquierda), que es justo como la construyen `_unidad_h`/`_unidad_v` de
## `ParedesSalas` al generar su `clave_modelo`. Devuelve `[Vector2i.ZERO, &""]` si la clave no tiene
## el formato esperado.
func celda_y_lado_de_clave(clave: String) -> Array:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return [Vector2i.ZERO, &""]
	var x: int = int(partes[1])
	var y: int = int(partes[2])
	if partes[0] == "h":
		return [Vector2i(x, y), &"arriba"]
	if partes[0] == "v":
		return [Vector2i(x, y), &"izquierda"]
	return [Vector2i.ZERO, &""]


## La celda LITERAL de una clave de arista ("T:x:y" → `Vector2i(x,y)`, sin más — ver la cabecera de
## `SUFIJO_CARA_A`/`_B`): es la celda del lado "b" de esa arista. "" o formato inesperado →
## `Vector2i.ZERO` (no debería darse: solo se llama con claves que ya vienen de `_muros`).
func _celda_b_de_arista(clave: String) -> Vector2i:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return Vector2i.ZERO
	return Vector2i(int(partes[1]), int(partes[2]))


## La CARA INTERIOR de un tramo de FACHADA: la "a" o la "b", la que caiga en una celda DENTRO del
## edificio (`_celda_en_edificio`) — para la fachada norte/oeste es la "b" (su celda literal ya es
## la primera fila/columna de dentro), para la sur/este es la "a" (la literal es la primera fuera,
## la calle). La usa `pintar_edificio_muros` para no teñir nunca la calle. Se asume —invariante del
## propio perímetro del edificio— que EXACTAMENTE una de las dos cae dentro; si ninguna lo hiciera
## (una clave que no fuera de verdad fachada) se devuelve la "a" como respaldo conservador.
func _cara_interior_de_fachada(clave: String) -> String:
	if _celda_en_edificio(_celda_b_de_arista(clave)):
		return clave + SUFIJO_CARA_B
	return clave + SUFIJO_CARA_A


## ¿Hay muro en esa arista?
func hay_muro(celda: Vector2i, lado: StringName) -> bool:
	return _muros.has(clave_de_muro(celda, lado))


## Todas las aristas con muro, para que la capa visual las dibuje (solo lectura).
func muros() -> Array[String]:
	var resultado: Array[String] = []
	for clave: String in _muros:
		resultado.append(clave)
	return resultado


## ¿Esta arista es parte del edificio (fachada o puerta de acceso)? Las fijas no se demuelen ni se
## convierten: son el plano de la comisaría.
func es_muro_fijo(clave: String) -> bool:
	return _muros_fijos.has(clave)


## LEVANTA LA FACHADA: cierra el edificio entero por su perímetro y abre la puerta de acceso.
##
## Es IDEMPOTENTE y no cuesta dinero: se puede llamar al empezar la partida y otra vez después de
## cargar, y el resultado es el mismo. Al cargar hace falta precisamente para volver a marcar como
## FIJAS unas aristas que en el save eran tabiques corrientes.
##
## La puerta ocupa `alto_puerta` celdas seguidas en el lado IZQUIERDO, centrada en la fila de
## `CELDA_PUERTA_EDIFICIO` — que es por donde ya llegaba la gente desde la calle, así que el
## recorrido de siempre sigue valiendo. Al ser PUERTA, `deja_pasar` la deja cruzar y la navegación
## no la recorta: es el ÚNICO hueco por el que se entra y se sale.
##
## ⚠️ No cambia los RECINTOS: el modelo ya trataba el perímetro del edificio como muro implícito
## (ver `recinto_de`), así que declararlo explícito no altera ninguna zona ya designada.
func levantar_fachada(alto_puerta: int = 2) -> void:
	var fila_puerta: int = CELDA_PUERTA_EDIFICIO.y
	var puertas: Dictionary[String, bool] = {}
	for i: int in range(maxi(alto_puerta, 1)):
		puertas["v:0:%d" % (fila_puerta + i)] = true
	var claves: Array[String] = []
	for x: int in edificio_columnas:
		claves.append("h:%d:0" % x)                    # fachada de arriba (al fondo)
		claves.append("h:%d:%d" % [x, edificio_filas]) # fachada de abajo (la de delante)
	for y: int in edificio_filas:
		claves.append("v:0:%d" % y)                    # fachada izquierda (donde va la puerta)
		claves.append("v:%d:%d" % [edificio_columnas, y])
	for clave: String in claves:
		_muros_fijos[clave] = true
		_muros[clave] = PUERTA if puertas.has(clave) else TABIQUE
	_refrescar_visual()


## Levanta un muro en esa arista, cobrándolo (gate E4 de Economía, igual que todo lo que se
## construye). Devuelve si se levantó: `false` si ya había uno, si la arista cae fuera del edificio
## o si no hay caja. Sin dinero no se construye — no se entra en números rojos por levantar tabiques.
func construir_muro(celda: Vector2i, lado: StringName) -> bool:
	var clave: String = clave_de_muro(celda, lado)
	if clave == "" or _muros.has(clave):
		return false
	if not _arista_dentro_del_edificio(clave):
		return false
	if not _pagar(coste_muro):
		return false
	_muros[clave] = TABIQUE
	_refrescar_visual()
	return true


## Derriba un muro, devolviendo el mismo porcentaje que el resto de demoliciones (F4).
func demoler_muro(celda: Vector2i, lado: StringName) -> bool:
	var clave: String = clave_de_muro(celda, lado)
	if not _muros.has(clave):
		return false
	if _muros_fijos.has(clave):
		return false   # la fachada del edificio no se derriba: es el plano, no obra tuya
	_muros.erase(clave)
	# La pintura se va con la pared: si mañana levantas otro tabique en esa misma arista, nace BLANCO
	# como cualquier pared nueva — no hereda el color del que derribaste. Se borran LAS DOS CARAS
	# (2026-08-06): una pared demolida no deja ninguna cara pintada colgando en el diccionario.
	_color_muros.erase(clave + SUFIJO_CARA_A)
	_color_muros.erase(clave + SUFIJO_CARA_B)
	_abonar(coste_muro * pct_reembolso)
	_refrescar_visual()
	return true


# ── PINTURA DE PAREDES Y SUELOS (2026-08-04 · quick-spec §2) ─────────────────────────────────
## El jugador pinta con un PINCEL: un clic pinta el tramo (o la celda) que señala; con MAYÚS, la
## SALA ENTERA (`pintar_sala_muros`/`pintar_sala_suelo`) o, sobre fachada/pasillo, EL EDIFICIO
## ENTERO (`pintar_edificio_muros`/`pintar_edificio_suelos`, 2026-08-05). Aquí vive solo el
## MODELO — quién decide el color y cuándo se pulsa MAYÚS es cosa de la UI (`ModoConstruccion`), y
## quién lo dibuja, de la capa visual (ADR-0004).
##
## Una regla de diseño que no se negocia:
##   · **El cristal de una VENTANA no se pinta.** Pintar un tramo que es ventana pinta su muro y sus
##     jambas; el cristal conserva su color propio. Eso se resuelve en el DIBUJO (`paredes_salas`),
##     no aquí: el modelo guarda el color del tramo pase lo que pase con su tipo, así que convertir
##     una ventana en tabique (y al revés) no pierde la pintura.
##
## **La FACHADA SÍ se pinta** (2026-08-05, orden del usuario: *"las paredes del edificio también se
## deben poder pintar"*). Hasta hoy `_muros_fijos` bloqueaba tanto la pintura como la demolición del
## plano del edificio; desde hoy solo bloquea lo segundo — pintar no es obra, es decoración.
## `_muros_fijos` SIGUE existiendo para lo que de verdad no se toca: no se demuele (`demoler_muro`)
## ni se le abren huecos nuevos (`fijar_tipo_de_muro`).

## El color de una pared construida y no pintada: AZUL SUAVE de la paleta clara (demo del usuario
## con Summer, 2026-08-05; hasta hoy era blanco). El blanco sigue siendo el primero de la paleta
## del pincel: el jugador puede volver a él repintando. Muere el color por tipo de sala EN LAS
## PAREDES — el suelo lo conserva como fondo de zona.
const COLOR_PARED_POR_DEFECTO: Color = Color(0.72, 0.78, 0.88, 1.0)
## El color del suelo sin pintar y sin sala: CREMA de la paleta clara. Hasta hoy compartía el
## blanco de la pared; se separa en constante propia para que pared y suelo diverjan sin pisarse.
const COLOR_SUELO_POR_DEFECTO: Color = Color(0.87, 0.84, 0.78, 1.0)

## ── ACABADO DEL SUELO (2026-08-05 · quick-spec §3d, tarea 4) ────────────────────────────────────
## `&"baldosa"` = lo de siempre (junta + variación de tono, `_pintar_baldosa`). `&"liso"` = color
## PLANO, sin junta ni variación — como el suelo crema del arranque de la comisaría. Se elige junto
## al color, por celda, con el pincel de suelo (`ModoConstruccion`).
const ACABADO_BALDOSA := &"baldosa"
const ACABADO_LISO := &"liso"


## Pinta AMBAS CARAS de un tramo, dado por su clave de arista — el camino "sin celda de referencia"
## (lo usan los tests y cualquier llamador que no sepa desde qué celda se mira la pared). Devuelve
## si se pintó: `false` si ahí no hay pared que pintar. La FACHADA se pinta igual que cualquier otro
## tramo (2026-08-05): pintarla no es demolerla ni abrirle un hueco, así que `_muros_fijos` no entra
## aquí.
##
## ⚠️ PINTURA POR CARA (2026-08-06 · quick-spec §3f): desde hoy cada CARA de un muro guarda su
## propio color — `pintar_muro_en` pinta solo la del lado que se señala. Esta función (la de clave
## suelta, sin celda) pinta las DOS a la vez: es el comportamiento explícito de "no tengo una celda
## de referencia, tiño el tramo entero", el mismo que tenían todas las paredes antes de esta fecha.
func pintar_muro(clave: String, color: Color) -> bool:
	if not _muros.has(clave):
		return false   # no hay pared: primero se levanta (para eso está el pincel de muro)
	_color_muros[clave + SUFIJO_CARA_A] = color
	_color_muros[clave + SUFIJO_CARA_B] = color
	_refrescar_visual()
	return true


## Pinta SOLO la CARA del lado de `celda` (azúcar para la UI, que piensa en celda + lado igual que
## el pincel de muro y el de puertas). La cara del OTRO lado —la que da a la celda vecina— no se
## toca: es el pedido del usuario (*"si le doy a mayús solo pinta el interior... no las 2 caras, por
## fuera y por dentro"*) llevado también al clic suelto (2026-08-06).
func pintar_muro_en(celda: Vector2i, lado: StringName, color: Color) -> bool:
	var clave: String = clave_de_muro(celda, lado)
	if clave == "" or not _muros.has(clave):
		return false   # no hay pared: primero se levanta (para eso está el pincel de muro)
	_color_muros[clave_de_cara(celda, lado)] = color
	_refrescar_visual()
	return true


## El color de la CARA del lado de `celda`: el pintado, o el color por defecto si esa cara nunca se
## pintó. Es la lectura PRECISA (por cara) — la que necesita el dibujo (`ParedesSalas`) para saber
## de qué lado mira, y la que necesita la UI para leer solo lo que el jugador señala.
func color_cara_de(celda: Vector2i, lado: StringName) -> Color:
	var cara: String = clave_de_cara(celda, lado)
	if cara == "":
		return COLOR_PARED_POR_DEFECTO
	return _color_muros.get(cara, COLOR_PARED_POR_DEFECTO)


## El color de la CARA VISIBLE de un tramo, dado solo por su clave de arista (sin celda de
## referencia): la cara "b" — la de la celda SUR en una arista horizontal, la de la celda ESTE en
## una vertical (ver la cabecera de `SUFIJO_CARA_A`/`_B`). Es EXACTAMENTE el criterio con el que la
## cámara isométrica de este juego mira cualquier tramo (sur-este), así que es lo que usa el dibujo
## genérico (`ParedesSalas._color_de_tramo`) para cualquier arista, perímetro de sala o muro suelto
## por igual — la fachada norte/oeste cae en su cara INTERIOR sin ningún caso especial (la celda
## sur/este de esas dos aristas YA ES la primera fila/columna de dentro del edificio).
func color_cara_visible_de(clave: String) -> Color:
	return _color_muros.get(clave + SUFIJO_CARA_B, COLOR_PARED_POR_DEFECTO)


## El color de un tramo de pared, dado por su CLAVE de arista (compat, 2026-08-04 → 2026-08-06):
## como una clave sola no dice desde qué celda se mira, se resuelve con la CARA VISIBLE
## (`color_cara_visible_de` — ver ahí el criterio). Lo sigue usando el dibujo genérico y los tests
## que no operan celda a celda.
func color_muro_de(clave: String) -> Color:
	return color_cara_visible_de(clave)


## ¿La CARA VISIBLE de ese tramo tiene color propio? (mismo criterio que `color_muro_de` — lee SOLO
## la cara "b"; para preguntar por una cara concreta, combina `clave_de_cara(celda,lado)` con
## `_color_muros.has(...)`). Lo usan los tests y el volcado del diagnóstico para distinguir "blanco
## pintado a mano" de "blanco por defecto".
func muro_pintado(clave: String) -> bool:
	return _color_muros.has(clave + SUFIJO_CARA_B)


## Pinta las caras INTERIORES de todas las paredes de una sala (el gesto de MAYÚS + clic). Recorre
## el perímetro real de la sala —que con formas no rectangulares no es un rectángulo (fase C)— y de
## cada tramo que exista pinta SOLO la cara que da a ESTA sala: `clave_de_cara(arista[0], arista[1])`,
## donde `arista[0]` es SIEMPRE la celda de la sala (invariante de `_aristas_del_perimetro`). La cara
## del otro lado (el pasillo, la calle, la sala vecina) no se toca — pedido explícito del usuario
## (quick-spec §3f): *"si le doy a mayús solo pinta el interior... no las 2 caras"*. Fachada incluida
## (2026-08-05: pintar ya no es obra) — su cara interior es una cara como cualquier otra a estos
## efectos. Devuelve cuántos tramos se pintaron.
func pintar_sala_muros(sala_id: StringName, color: Color) -> int:
	if not _salas.has(sala_id):
		return 0
	var pintados: int = 0
	for arista: Array in _aristas_del_perimetro(sala_id):
		var clave: String = clave_de_muro(arista[0], arista[1])
		if not _muros.has(clave):
			continue
		_color_muros[clave_de_cara(arista[0], arista[1])] = color
		pintados += 1
	if pintados > 0:
		_refrescar_visual()
	return pintados


## Los TRAMOS de pared que existen de verdad en el perímetro de una sala, como claves de arista (el
## mismo formato que `muros()`/`clave_de_muro`) — la lista EXACTA que pintaría `pintar_sala_muros`.
## La usa el fantasma de MAYÚS del pincel de pintura (quick-spec §3d, tarea 2): antes de soltar el
## clic, el jugador ve CADA tramo que se va a teñir, no solo el que señala el cursor.
func claves_muros_de_sala(sala_id: StringName) -> Array[String]:
	var claves: Array[String] = []
	if not _salas.has(sala_id):
		return claves
	for arista: Array in _aristas_del_perimetro(sala_id):
		var clave: String = clave_de_muro(arista[0], arista[1])
		if _muros.has(clave):
			claves.append(clave)
	return claves


## Pinta TODOS los tramos de pared del EDIFICIO, fachada incluida (2026-08-05: MAYÚS+clic sobre un
## tramo de fachada — orden del usuario: *"MAYÚS también debe poder pintar TODAS las paredes de la
## comisaría"*). Es a TODO el edificio lo que `pintar_sala_muros` es a UNA sala, con la MISMA regla
## de caras (quick-spec §3f, 2026-08-06): un TABIQUE (nada que separe de la calle) se pinta por sus
## DOS caras —no pertenece a una sola sala, así que no hay "interior" que privilegiar—; la FACHADA
## solo se pinta por su cara INTERIOR (`_cara_interior_de_fachada`) — la calle se queda con el color
## por defecto. Devuelve cuántos tramos se pintaron.
func pintar_edificio_muros(color: Color) -> int:
	var pintados: int = 0
	for clave: String in _muros:
		if es_muro_fijo(clave):
			_color_muros[_cara_interior_de_fachada(clave)] = color
		else:
			_color_muros[clave + SUFIJO_CARA_A] = color
			_color_muros[clave + SUFIJO_CARA_B] = color
		pintados += 1
	if pintados > 0:
		_refrescar_visual()
	return pintados


## Pinta UNA CELDA de suelo, con su ACABADO (`ACABADO_BALDOSA` por defecto — retrocompatible: el
## código y los tests de antes de esta fecha que no pasan `acabado` siguen pintando baldosa, que es
## lo que pintaban siempre). Devuelve si se pintó: `false` si la celda cae fuera del edificio (en la
## calle no se pinta nada). NO exige que haya sala: el suelo del pasillo también es suelo.
func pintar_suelo(celda: Vector2i, color: Color, acabado: StringName = ACABADO_BALDOSA) -> bool:
	if not _celda_en_edificio(celda):
		return false
	_color_suelos[celda] = color
	_acabado_suelos[celda] = _acabado_valido(acabado)
	_refrescar_visual()
	return true


## Normaliza un acabado a uno de los dos válidos; cualquier otro valor cae a `ACABADO_BALDOSA` con
## aviso — red de seguridad para un dato que puede venir de fuera (UI o un save corrupto).
func _acabado_valido(acabado: StringName) -> StringName:
	if acabado == ACABADO_BALDOSA or acabado == ACABADO_LISO:
		return acabado
	push_warning("Construccion: acabado de suelo desconocido ('%s') -> baldosa" % acabado)
	return ACABADO_BALDOSA


## El color del suelo de una celda: el pintado, o —si nunca se pintó— el TINTE DE SU SALA, que es el
## fondo de zona de siempre. Una celda sin pintar y sin sala devuelve el crema por defecto (no se
## dibuja: el suelo desnudo lo pinta la rejilla de Main).
func color_suelo_de(celda: Vector2i) -> Color:
	if _color_suelos.has(celda):
		return _color_suelos[celda]
	var sala_id: StringName = sala_en(celda)
	if sala_id == &"":
		return COLOR_SUELO_POR_DEFECTO
	var tipo_sala: Resource = Datos.obtener_silencioso(&"TipoSala", _salas[sala_id]["tipo"])
	if tipo_sala == null:
		return COLOR_SUELO_POR_DEFECTO
	return _color_de_sala(tipo_sala)


## El color de ZONA de una sala YA CONSTRUIDA: el mismo tono que usa el suelo como fondo por defecto
## (`_color_de_sala`, privado — este es el wrapper público). Lo consume el VELO DE ZONAS del modo
## construcción (quick-spec §3d, tarea 3): *"que haya una capa semitransparente donde se pueda ver
## el tamaño de cada sala"* — la UI necesita leer el mismo tinte sin duplicar la paleta.
func color_de_zona(sala_id: StringName) -> Color:
	if not _salas.has(sala_id):
		return COLOR_SUELO_POR_DEFECTO
	var tipo_sala: Resource = Datos.obtener_silencioso(&"TipoSala", _salas[sala_id]["tipo"])
	if tipo_sala == null:
		return COLOR_SUELO_POR_DEFECTO
	return _color_de_sala(tipo_sala)


## ¿Esa celda tiene suelo pintado a mano? (lo mismo que `muro_pintado`, para el suelo).
func suelo_pintado(celda: Vector2i) -> bool:
	return _color_suelos.has(celda)


## El ACABADO del suelo de una celda: el pintado, o `ACABADO_BALDOSA` si nunca se eligió uno
## (retrocompatible: un save de antes de esta fecha, o una celda pintada antes de esta fecha, se lee
## como baldosa — lo de siempre, sin sorpresas). Lo consulta el dibujo (`_refrescar_visual`).
func acabado_suelo_de(celda: Vector2i) -> StringName:
	return _acabado_suelos.get(celda, ACABADO_BALDOSA)


## Pinta TODO el suelo de una sala (MAYÚS + clic con el pincel de suelo), con su ACABADO. Devuelve
## cuántas celdas.
func pintar_sala_suelo(sala_id: StringName, color: Color, acabado: StringName = ACABADO_BALDOSA) -> int:
	if not _salas.has(sala_id):
		return 0
	var acabado_valido: StringName = _acabado_valido(acabado)
	var pintadas: int = 0
	for celda: Vector2i in _salas[sala_id].get("celdas", {}):
		_color_suelos[celda] = color
		_acabado_suelos[celda] = acabado_valido
		pintadas += 1
	if pintadas > 0:
		_refrescar_visual()
	return pintadas


## Pinta TODAS las celdas de suelo del EDIFICIO (2026-08-05: MAYÚS+clic de suelo sobre una celda SIN
## sala — orden del usuario: *"todas las baldosas del edificio"*), con su ACABADO. Mismo criterio que
## `pintar_suelo` (`_celda_en_edificio`): los límites del bucle SON esa definición (`0 <= x <
## edificio_columnas`, `0 <= y < edificio_filas`), así que en la calle no se pinta nada por
## construcción. Devuelve cuántas celdas se pintaron.
func pintar_edificio_suelos(color: Color, acabado: StringName = ACABADO_BALDOSA) -> int:
	var acabado_valido: StringName = _acabado_valido(acabado)
	var pintadas: int = 0
	for x: int in edificio_columnas:
		for y: int in edificio_filas:
			_color_suelos[Vector2i(x, y)] = color
			_acabado_suelos[Vector2i(x, y)] = acabado_valido
			pintadas += 1
	if pintadas > 0:
		_refrescar_visual()
	return pintadas


## Una arista es válida si separa dos celdas de las que AL MENOS UNA está dentro del edificio: así se
## puede cerrar el borde exterior (la fachada) pero no pintar muros en mitad de la calle.
func _arista_dentro_del_edificio(clave: String) -> bool:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return false
	var x: int = int(partes[1])
	var y: int = int(partes[2])
	var a: Vector2i = Vector2i(x - 1, y) if partes[0] == "v" else Vector2i(x, y - 1)
	var b: Vector2i = Vector2i(x, y)
	return _celda_en_edificio(a) or _celda_en_edificio(b)


## ¿Esa celda cae dentro de la rejilla del edificio?
func _celda_en_edificio(celda: Vector2i) -> bool:
	return (
		celda.x >= 0 and celda.y >= 0
		and celda.x < edificio_columnas and celda.y < edificio_filas
	)


## ¿Esta sala tiene paredes dibujadas? (2026-07-30) Delimitar una zona y AISLARLA son dos cosas
## distintas: Documentacion, ODAC y la sala de espera se leen bien en planta diafana; la de descanso
## necesita cerrarse para que no se vea a los funcionarios de cafe desde la cola.
func sala_con_paredes(sala_id: StringName) -> bool:
	# 🐛 2026-07-30, el usuario: "las construye con paredes pero hay un bug que no se muestran esas
	# paredes". La causa era tener DOS FUENTES DE VERDAD: un flag `paredes` en la sala (que se ponia al
	# crearla) y los muros REALES (que solo aparecian al usar el boton del menu). La sala nacia con el
	# flag puesto y sin un solo muro construido.
	# Ahora esto se DERIVA de la realidad: una sala "tiene paredes" si TODAS las aristas de su
	# perimetro tienen muro. Sin flag que pueda mentir.
	if not _salas.has(sala_id):
		return false
	var aristas: Array = _aristas_del_perimetro(sala_id)
	if aristas.is_empty():
		return false
	for arista: Array in aristas:
		if not hay_muro(arista[0], arista[1]):
			return false
	return true


## Pone o quita las paredes de una sala YA construida. De momento es gratis y solo cambia como se
## ve: las paredes todavia NO bloquean el paso (esa es una fase aparte que el usuario decidira).
func fijar_paredes_de_sala(sala_id: StringName, con_paredes: bool) -> void:
	if not _salas.has(sala_id):
		push_warning("Construccion: paredes de una sala inexistente ('%s') -> ignorado" % sala_id)
		return
	# Levanta o derriba MUROS DE VERDAD en todo el perimetro — los mismos que pintarias a mano, con su
	# coste y su comportamiento. Ya no hay ningun flag: `sala_con_paredes` lee la realidad.
	for arista: Array in _aristas_del_perimetro(sala_id):
		if con_paredes:
			construir_muro(arista[0], arista[1])
		else:
			demoler_muro(arista[0], arista[1])
	_refrescar_visual()


## Las aristas EXTERIORES de una sala: por cada celda del borde, los lados que dan fuera de la sala.
##
## Se calcula sobre el CONJUNTO de celdas, no sobre el rectangulo, para que funcione igual con una
## sala en forma de L designada dentro de muros (fase C).
func _aristas_del_perimetro(sala_id: StringName) -> Array:
	var salida: Array = []
	if not _salas.has(sala_id):
		return salida
	var suyas: Dictionary = _salas[sala_id].get("celdas", {})
	for celda: Vector2i in suyas:
		for paso: Array in VECINOS_4:
			var vecina: Vector2i = celda + (paso[1] as Vector2i)
			if not suyas.has(vecina):
				salida.append([celda, paso[0]])   # esa vecina no es de la sala: ahi hay borde
	return salida


## Cuantos tramos de muro hacen falta para cerrar una sala, y lo que costaria. Lo consulta la UI para
## avisar ANTES de gastar: cerrar una sala grande son muchos tramos a 15 EUR.
func coste_de_cerrar_sala(sala_id: StringName) -> Array:
	var tramos: int = 0
	for arista: Array in _aristas_del_perimetro(sala_id):
		if not hay_muro(arista[0], arista[1]):
			tramos += 1
	return [tramos, float(tramos) * coste_muro]


## La celda INTERIOR que toca la puerta de esa sala (`CELDA_NULA_PUERTA` si no tiene ninguna).
##
## DERIVADO de los muros reales desde 2026-08-04 (ya no hay campo guardado — ver "muere la puerta
## automática"): es la primera celda del perímetro cuya arista hacia fuera es de tipo `PUERTA`. Si la
## sala tiene varias puertas devuelve una —la primera en el orden estable del perímetro—; quien
## necesite todas usa `puertas_de_sala`.
func puerta_de_sala(sala_id: StringName) -> Vector2i:
	var todas: Array[Vector2i] = puertas_de_sala(sala_id)
	return todas[0] if not todas.is_empty() else CELDA_NULA_PUERTA


## Todas las celdas del perímetro de la sala que tienen una puerta abierta hacia fuera. Orden
## estable: el de `_aristas_del_perimetro` (celdas en orden de alta, lados en orden de `VECINOS_4`).
func puertas_de_sala(sala_id: StringName) -> Array[Vector2i]:
	var salida: Array[Vector2i] = []
	for arista: Array in _aristas_del_perimetro(sala_id):
		if tipo_de_muro(arista[0], arista[1]) == PUERTA and not (arista[0] in salida):
			salida.append(arista[0])
	return salida


## ¿Esta sala está amurallada y SIN NINGUNA PUERTA? Es el disparador del paso "ahora elige dónde va
## la puerta" del modo construcción (quick-spec §3): amurallar deja un recinto cerrado, y la UI tiene
## que pedir el gesto que falta. Una sala sin paredes no cuenta — no hay pared donde abrir nada.
func sala_amurallada_sin_puerta(sala_id: StringName) -> bool:
	return sala_con_paredes(sala_id) and puertas_de_sala(sala_id).is_empty()


## ¿Esta celda tiene una puerta en alguno de sus lados? Lo consulta la validación de colocación:
## **una puerta no se puede tapiar** con un mueble, o el jugador se dejaría la sala sin entrada sin
## que nada se lo dijera (la puerta ya no puede apartarse sola: es un tramo de pared del jugador).
func es_celda_de_puerta(celda: Vector2i) -> bool:
	for paso: Array in VECINOS_4:
		if tipo_de_muro(celda, paso[0]) == PUERTA:
			return true
	return false


## Da de alta un elemento YA validado y pagado (guarda `coste_pagado` — lo necesita el reembolso F4).
## `nivel`: el escalón de huella con el que entra (COMPLETA salvo saves viejos / trazado apretado).
func _crear_elemento(
	id_catalogo: StringName, celda: Vector2i, coste_pagado: float, id_forzado: StringName = &"",
	orientacion: int = HORIZONTAL, nivel: int = HUELLA_COMPLETA
) -> StringName:
	var elemento_id: StringName = id_forzado if id_forzado != &"" else _nuevo_id(id_catalogo)
	_elementos[elemento_id] = {
		"catalogo": id_catalogo, "celda": celda, "sala": sala_en(celda), "coste_pagado": coste_pagado,
		"orientacion": orientacion,
	}
	if nivel != HUELLA_COMPLETA:
		_elementos[elemento_id][CLAVE_NIVEL_HUELLA] = nivel
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
## `con_paredes`: 0 = lo que diga el tipo de sala · 1 = con paredes · -1 = sin paredes. Lo decide el
## jugador con un interruptor en la barra de construccion (peticion del usuario 2026-07-30: "cuando
## construyo una sala nueva deberia poder construirse con o sin paredes").
func construir_sala(tipo_sala_id: StringName, rect: Rect2i, con_paredes: int = 0) -> StringName:
	var ampliable: StringName = sala_ampliable(tipo_sala_id, rect)
	if ampliable != &"":
		var coste_ampliar: float = coste_ampliacion(ampliable, rect)
		if not _pagar(coste_ampliar):
			return &""
		# La caja envolvente se fusiona (merge) Y el conjunto de celdas se UNE: si solo se tocara el
		# rect, la sala ampliada diria que mide mas de lo que de verdad ocupa (fase B).
		_salas[ampliable]["rect"] = (_salas[ampliable]["rect"] as Rect2i).merge(rect)
		var suyas: Dictionary = _salas[ampliable].get("celdas", {})
		for celda: Vector2i in _celdas_del_rect(rect):
			suyas[celda] = true
		_salas[ampliable]["celdas"] = suyas
		_salas[ampliable]["coste_pagado"] = float(_salas[ampliable]["coste_pagado"]) + coste_ampliar
		_refrescar_visual()
		return ampliable
	if not validar_sala(tipo_sala_id, rect):
		return &""
	var coste: float = coste_sala(tipo_sala_id, rect)
	if not _pagar(coste):
		return &""
	return _crear_sala(tipo_sala_id, rect, coste, &"", con_paredes)


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
func construir_elemento(
	id_catalogo: StringName, celda: Vector2i, orientacion: int = HORIZONTAL
) -> StringName:
	if not validar_elemento(id_catalogo, celda, &"", orientacion):
		return &""
	var coste: float = coste_elemento(id_catalogo)
	if not _pagar(coste):
		return &""
	return _alta_elemento(id_catalogo, celda, coste, &"", orientacion)


## Alta común (construir normal y de oficio): registra en el modelo + puente a Personal si es puesto.
func _alta_elemento(
	id_catalogo: StringName, celda: Vector2i, coste_pagado: float, id_forzado: StringName = &"",
	orientacion: int = HORIZONTAL, nivel: int = HUELLA_COMPLETA
) -> StringName:
	var elemento_id: StringName = _crear_elemento(
		id_catalogo, celda, coste_pagado, id_forzado, orientacion, nivel
	)
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
## Si un PUESTO del trazado de oficio no cabe con sus 6 celdas (2026-08-03), BAJA UN ESCALÓN —primero
## a su mostrador de 2, y si tampoco, a su sola celda de trabajo— en vez de desaparecer: misma
## política que los saves (`migrar_huella_puestos`), y así una comisaría recién entregada nunca pierde
## una ventanilla por una celda. Cada escalón avisa: un trazado inicial apretado es un dato de diseño,
## no un detalle interno.
func construir_de_oficio_elemento(
	id_catalogo: StringName, celda: Vector2i, id_forzado: StringName = &"",
	orientacion: int = HORIZONTAL
) -> StringName:
	if validar_elemento(id_catalogo, celda, &"", orientacion):
		return _alta_elemento(id_catalogo, celda, 0.0, id_forzado, orientacion)
	if _es_puesto(id_catalogo):
		for nivel: int in NIVELES_HUELLA:
			if nivel == HUELLA_COMPLETA:
				continue   # ya se ha probado arriba
			if not _validar_elemento_con(id_catalogo, celda, &"", orientacion, nivel):
				continue
			push_warning(
				"Construccion: el puesto '%s' en %s no cabe con su huella completa (2x3) -> montado en el escalon %d"
				% [id_catalogo, celda, nivel]
			)
			return _alta_elemento(id_catalogo, celda, 0.0, id_forzado, orientacion, nivel)
	push_warning("Construccion: montaje de oficio INVALIDO ('%s' en %s)" % [id_catalogo, celda])
	return &""


## ¿Este id de catálogo es un PUESTO (mostrador)? Ni los asientos ni las comodidades lo son.
func _es_puesto(id_catalogo: StringName) -> bool:
	return Datos.obtener_silencioso(&"TipoPuesto", id_catalogo) != null


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
	var area: int = area_de_sala(sala_id)   # celdas REALES, no el area de la caja envolvente
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
	var area: int = area_de_sala(sala_id)   # celdas REALES, no el area de la caja envolvente
	return int(floor(float(area) * densidad_asientos))


## F5 (informativo, CO7 — NO es un tope): cuántos puestos justifica la demanda pico. La UI futura lo
## mostrará como brújula; construir de más es legal (agentes ociosos). Throughput ≤ 0 → 0 con aviso.
func puestos_utiles(tasa_llegadas_pico: float, throughput_hora_puesto: float) -> int:
	if throughput_hora_puesto <= 0.0:
		push_warning("Construccion: puestos_utiles con throughput <= 0 -> 0")
		return 0
	return ceili(tasa_llegadas_pico / throughput_hora_puesto)


## El elemento cuya HUELLA cubre una celda (&"" si ninguno) — lo usa la herramienta de demolición
## (007). Un clic en CUALQUIER celda de un sofá de 3 lo encuentra, no solo en su ancla; y en un puesto
## responde también desde la celda de cualquiera de sus dos sillas: la ventanilla es UNA sola cosa, así
## que se selecciona y se demuele como una sola cosa.
func elemento_en(celda: Vector2i) -> StringName:
	var en_suelo: StringName = &""
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		if not (celda in _huella_de(elemento)):
			continue
		# Si en esa celda hay una pieza de TECHO y algo en el suelo, gana la de techo: es la que está
		# dibujada encima y a la que el jugador está apuntando. Si no, la del suelo.
		if es_de_techo(elemento["catalogo"]):
			return elemento_id
		en_suelo = elemento_id
	return en_suelo


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


## La CELDA DE TRABAJO de un puesto: donde se atiende. Es la celda ANCLA, la misma de toda la vida —
## el funcionario se pone en la de arriba (norte) y el ciudadano espera en la de abajo (sur). Que el
## puesto reserve 2×3 celdas desde el 2026-08-03 NO cambia esta invariante: las otras cinco son sitio
## reservado, y Flujo y Personal siguen preguntando solo por esta.
func celda_de_trabajo(puesto_id: StringName) -> Vector2i:
	return posicion_de(puesto_id)


## El ESCALÓN de huella con el que está colocado un elemento (`HUELLA_COMPLETA` para todo lo normal).
## Lo consulta la capa visual para saber cuánto mueble tiene que dibujar.
func nivel_de_huella(elemento_id: StringName) -> int:
	if not _elementos.has(elemento_id):
		return HUELLA_COMPLETA
	return int(_elementos[elemento_id].get(CLAVE_NIVEL_HUELLA, HUELLA_COMPLETA))


## ¿Este puesto se quedó con UNA SOLA celda (la de trabajo)? Es el escalón más bajo — la excepción de
## un save o un trazado donde no cabe ni el mostrador. La capa visual lo usa para dibujar el mostrador
## de 1 celda en vez del de 2 (`MesaAtencion.construir`). Falso para todo lo demás: un asiento o una
## comodidad nunca son "legado".
func es_huella_legado(elemento_id: StringName) -> bool:
	return nivel_de_huella(elemento_id) == HUELLA_MINIMA


## MIGRACIÓN IDEMPOTENTE de la huella de los puestos, **v2: 2×3** (2026-08-03) — mismo patrón que
## `levantar_fachada`: se puede llamar mil veces seguidas y el resultado es exactamente el mismo.
##
## ⚠️ CLAVE: **el save NUNCA ha guardado la huella**, solo el ANCLA (ver `save`). Así que "migrar" no
## es convertir un dato viejo: es VOLVER A DEDUCIR, con el catálogo de hoy y el layout que hay, cuánto
## ocupa cada puesto. Por eso un save de cuando el mostrador medía 1 celda y otro de cuando medía 2 son
## el MISMO JSON y pasan por aquí exactamente igual.
##
## POLÍTICA (la más simple que no rompe partidas) — el puesto BAJA ESCALONES hasta que quepa:
##   1. `HUELLA_COMPLETA` (2×3): el bloque entero cabe en su sala y libre → se expande. Lo normal.
##   2. `HUELLA_SIN_FONDO` (2×1): las filas de las sillas chocan (otro puesto pegado, un armario, el
##      borde de la sala) pero el mostrador sí cabe → se queda con el mostrador.
##   3. `HUELLA_MINIMA` (1×1): ni eso → se queda con su celda de trabajo.
## Un puesto en un escalón bajo SE JUEGA IGUAL que ayer: misma celda de trabajo, mismo funcionario,
## mismo ciudadano. Lo único que pierde es sitio reservado. Descartadas: recolocarlo (le mueve la
## ventanilla sin avisar) y rotarlo (el fondo caería sobre la celda del ciudadano, que es peor).
##
## El escalón NO se serializa: se vuelve a deducir en cada carga, así que si el jugador demuele el
## estorbo, el puesto recupera su huella entera él solo la próxima vez que se cargue la partida.
##
## Se hace en DOS PASADAS a propósito: primero se borran todas las marcas y luego se decide, para que
## el resultado dependa solo del estado del save (anclas, orientaciones, salas y catálogo) y no de qué
## marcas hubiera puestas antes — que es lo que hace la operación idempotente. Dentro de la 2ª pasada
## el orden es el de inserción del save, que es estable: dos puestos que se estorban reparten siempre
## igual (el primero que cabe se queda el sitio).
func migrar_huella_puestos() -> void:
	var puestos: Array[StringName] = []
	for elemento_id: StringName in _elementos:
		if _es_puesto(_elementos[elemento_id]["catalogo"]):
			puestos.append(elemento_id)
			_elementos[elemento_id].erase(CLAVE_NIVEL_HUELLA)
	for puesto_id: StringName in puestos:
		var nivel: int = _nivel_que_cabe(puesto_id)
		if nivel != HUELLA_COMPLETA:
			_elementos[puesto_id][CLAVE_NIVEL_HUELLA] = nivel


## El escalón MÁS ALTO de huella con el que un elemento ya colocado cabe donde está: cabe si todas sus
## celdas están en la misma sala que su ancla y ninguna la ocupa OTRO elemento. Si no cabe con ninguno
## (p. ej. su ancla se quedó fuera de toda sala tras editar el layout) se queda con el mínimo — un
## puesto del save nunca se descarta en silencio.
func _nivel_que_cabe(elemento_id: StringName) -> int:
	var elemento: Dictionary = _elementos[elemento_id]
	for nivel: int in NIVELES_HUELLA:
		if _validar_elemento_con(
			elemento["catalogo"], elemento["celda"], elemento_id,
			elemento.get("orientacion", HORIZONTAL), nivel
		):
			return nivel
	return HUELLA_MINIMA


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
	if not validar_elemento(
		elemento["catalogo"], celda_destino, elemento_id,
		elemento.get("orientacion", HORIZONTAL)
	):
		return false
	if coste_mover > 0.0 and not _pagar(coste_mover):
		return false
	elemento["celda"] = celda_destino
	elemento["sala"] = sala_en(celda_destino)
	# Se acaba de revalidar con la huella ENTERA del catálogo: si el puesto venía de un escalón
	# recortado, lo recupera (el jugador lo ha llevado a un sitio donde sí caben sus 6 celdas).
	elemento.erase(CLAVE_NIVEL_HUELLA)
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
## DECISIÓN (bug superficie, 2026-07-29): el CUERPO de un elemento (sofá de 3 celdas, etc.) tampoco
## se guarda — solo su celda ANCLA, igual que siempre. `_celdas_de` lo recalcula en cada consulta
## leyendo `superficie` del catálogo vigente. Guardar las 3 celdas sería redundante (se derivan de la
## ancla + el catálogo) y crearía la posibilidad de que se desincronizaran si el catálogo cambia de
## valor entre partidas; recalcular es menos dato y no puede quedar obsoleto.
func save() -> Dictionary:
	var salas: Array = []
	for sala_id: StringName in _salas:
		var sala: Dictionary = _salas[sala_id]
		var rect: Rect2i = sala["rect"]
		salas.append({
			"id": String(sala_id), "tipo": String(sala["tipo"]),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"coste_pagado": sala["coste_pagado"],
			# La PUERTA ya no se guarda (2026-08-04): es un tramo de pared del jugador y viaja en la lista
			# de muros con su tipo, como cualquier otro. Un save viejo puede traer el campo `puerta` del
			# hueco automatico: se ignora al cargar — ese hueco ya no existe.
			# Las celdas REALES de la sala (fase B): con formas no rectangulares no se pueden deducir del
			# rect, que es solo la caja envolvente. Se guardan como pares [x,y], igual que el resto.
			"celdas": _celdas_a_json(sala.get("celdas", {})),
		})
	var elementos: Array = []
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		elementos.append({
			"id": String(elemento_id), "catalogo": String(elemento["catalogo"]),
			"celda": [elemento["celda"].x, elemento["celda"].y],
			"coste_pagado": elemento["coste_pagado"],
			# Como esta girado (rotar con R, 2026-07-30). Los saves de antes no lo traen y al cargar
			# se les da HORIZONTAL, que es como se colocaba TODO hasta hoy: una partida vieja se ve
			# exactamente igual que antes.
			"orientacion": elemento.get("orientacion", HORIZONTAL),
		})
	# Los muros libres se guardan como la lista de sus claves de arista: es el dato minimo del que se
	# reconstruye todo, y al ser texto plano viaja por el JSON del SaveManager sin conversiones.
	var muros_json: Array = []
	for clave: String in _muros:
		# Desde la fase D cada arista guarda TAMBIEN que es (tabique / puerta / ventana), asi que se
		# serializa como par [clave, tipo]. Antes bastaba la clave suelta.
		muros_json.append([clave, String(_muros[clave])])
	# PINTURA (2026-08-04): los colores se guardan como HEX de 6 digitos, no como Color — el save es
	# JSON puro (ADR-0002) y un Color no viaja por JSON. Solo se guarda lo PINTADO A MANO: un tramo
	# blanco por defecto no ocupa una linea del save (y al cargar vuelve a salir blanco solo).
	var colores_muros: Array = []
	for clave: String in _color_muros:
		colores_muros.append([clave, PaletaPinturaScript.a_hex(_color_muros[clave])])
	# ACABADO (2026-08-05 · quick-spec §3d, tarea 4): 4º campo por celda, `"baldosa"`/`"liso"`. Un
	# save de ANTES de esta fecha (o cargado por un test viejo) solo trae los 3 primeros — se lee
	# como baldosa al cargar (ver `load_state`), que es lo que esa celda pintaba de verdad entonces.
	var colores_suelos: Array = []
	for celda: Vector2i in _color_suelos:
		colores_suelos.append([
			celda.x, celda.y, PaletaPinturaScript.a_hex(_color_suelos[celda]),
			String(_acabado_suelos.get(celda, ACABADO_BALDOSA)),
		])
	return {
		"salas": salas, "elementos": elementos, "contador_ids": _contador_ids,
		"muros": muros_json,
		"colores_muros": colores_muros, "colores_suelos": colores_suelos,
	}


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
	_muros.clear()
	_color_muros.clear()
	_color_suelos.clear()
	_acabado_suelos.clear()
	for entrada: Variant in d.get("muros", []):
		# Se admiten los DOS formatos: la clave suelta (saves de la fase A, todos tabiques) y el par
		# [clave, tipo] de la fase D. Asi una partida guardada esta manana sigue cargando.
		var clave: String = ""
		var tipo: StringName = TABIQUE
		if entrada is String:
			clave = entrada
		elif entrada is Array and (entrada as Array).size() == 2:
			clave = String(entrada[0])
			var t := StringName(String(entrada[1]))
			if t == PUERTA or t == VENTANA:
				tipo = t
		if clave == "" or not _arista_dentro_del_edificio(clave):
			push_warning("Construccion: muro corrupto en el save -> descartado")
			continue
		_muros[clave] = tipo
	# PINTURA (2026-08-04 → CARAS 2026-08-06). Va DESPUES de los muros a proposito: un color solo se
	# restaura si ese tramo existe de verdad en el save (si no, seria pintura de una pared derribada
	# esperando a reaparecer — la familia de bug de las "puertas fantasma"). Formato NUEVO (por cara):
	# [clave_arista + ":a"/":b", hex] — 4 trozos al partir por ":". Formato VIEJO (por tramo, saves de
	# ANTES de esta fecha): [clave_arista, hex] — 3 trozos, SIN sufijo de cara; se MIGRA copiando el
	# mismo color a las DOS caras (es justo lo que esa pared enseñaba entonces: un solo color, se
	# mirara por donde se mirase).
	for entrada: Variant in d.get("colores_muros", []):
		if not (entrada is Array) or (entrada as Array).size() != 2:
			push_warning("Construccion: color de muro corrupto en el save -> descartado")
			continue
		var clave_guardada: String = String(entrada[0])
		var partes_clave: PackedStringArray = clave_guardada.split(":")
		var color_guardado: Color = PaletaPinturaScript.desde_hex(String(entrada[1]))
		if partes_clave.size() == 4:
			var clave_arista: String = "%s:%s:%s" % [partes_clave[0], partes_clave[1], partes_clave[2]]
			if not _muros.has(clave_arista):
				continue   # esa pared ya no esta: su pintura no se queda guardada
			_color_muros[clave_guardada] = color_guardado
		elif partes_clave.size() == 3:
			if not _muros.has(clave_guardada):
				continue   # esa pared ya no esta: su pintura no se queda guardada
			_color_muros[clave_guardada + SUFIJO_CARA_A] = color_guardado
			_color_muros[clave_guardada + SUFIJO_CARA_B] = color_guardado
		else:
			push_warning("Construccion: color de muro corrupto en el save -> descartado")
	# El suelo pintado, celda a celda: [x, y, hex] o [x, y, hex, acabado] (2026-08-05, tarea 4). Se
	# descarta lo que caiga fuera del edificio. Un array de 3 (save de ANTES del acabado, o de un
	# test viejo) es tan válido como uno de 4 — RETROCOMPATIBLE: esa celda se lee como
	# `ACABADO_BALDOSA`, que es lo que pintaba de verdad antes de que existiera el concepto (nunca
	# había otra cosa que baldosa).
	for entrada: Variant in d.get("colores_suelos", []):
		if not (entrada is Array) or (entrada as Array).size() < 3:
			push_warning("Construccion: color de suelo corrupto en el save -> descartado")
			continue
		var celda_color := Vector2i(int(entrada[0]), int(entrada[1]))
		if not _celda_en_edificio(celda_color):
			continue
		_color_suelos[celda_color] = PaletaPinturaScript.desde_hex(String(entrada[2]))
		var acabado: StringName = ACABADO_BALDOSA
		if (entrada as Array).size() >= 4:
			acabado = _acabado_valido(StringName(String(entrada[3])))
		_acabado_suelos[celda_color] = acabado
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
		# El campo `puerta` de los saves viejos (el hueco automatico) se IGNORA a proposito: desde
		# 2026-08-04 la puerta de una sala es un tramo de pared de tipo PUERTA y llega en la lista de
		# muros. Las puertas que el jugador abrio de verdad sobreviven; el hueco que nunca dejo pasar,
		# no — que es justo lo que se queria quitar.
		_salas[StringName(String(datos.get("id", "")))] = {
			"tipo": tipo_sala, "rect": rect, "coste_pagado": float(datos.get("coste_pagado", 0.0)),
			# Si el save es viejo (o viene corrupto) se rellenan desde el rect: una sala guardada ANTES de
			# la fase B era rectangular por definicion, asi que sus celdas son justo las de su rect.
			"celdas": _celdas_desde_json(datos.get("celdas", []), rect),
		}
	for datos: Variant in d.get("elementos", []):
		if not (datos is Dictionary):
			push_warning("Construccion: elemento corrupto en el save -> descartado")
			continue
		var catalogo: StringName = StringName(String(datos.get("catalogo", "")))
		var celda_datos: Variant = datos.get("celda", [])
		var es_asiento: bool = catalogo == ASIENTO_BASICO
		# 🐛 BUG GRAVE corregido 2026-07-29: aquí se exigía que todo lo que no fuera asiento fuese un
		# `TipoPuesto`… y las COMODIDADES no lo son. Resultado: **todo lo comprado en Comodidades #15
		# (vending, tele, fuente, equipos, y ahora los muebles de descanso) se PERDÍA al cargar la
		# partida** — el jugador podía gastarse miles de euros, guardar, cargar y encontrarse las
		# salas vacías. Es el mismo error que ya se cazó el 2026-07-28 en el gate de colocación
		# (`_puede_colocar`): "no ser asiento" NO implica "ser puesto". Lo destapó el test de
		# persistencia del sofá de 3 celdas.
		var es_comodidad: bool = Datos.obtener_silencioso(&"Comodidad", catalogo) != null
		var catalogo_valido: bool = es_asiento or es_comodidad \
				or Datos.obtener(&"TipoPuesto", catalogo) != null
		if not catalogo_valido or not (celda_datos is Array) or celda_datos.size() != 2:
			push_warning("Construccion: elemento '%s' invalido en el save -> descartado" % datos.get("id", "?"))
			continue
		var elemento_id: StringName = StringName(String(datos.get("id", "")))
		var celda := Vector2i(int(celda_datos[0]), int(celda_datos[1]))
		_elementos[elemento_id] = {
			"catalogo": catalogo, "celda": celda, "sala": sala_en(celda),
			"coste_pagado": float(datos.get("coste_pagado", 0.0)),
			"orientacion": VERTICAL if int(datos.get("orientacion", HORIZONTAL)) == VERTICAL else HORIZONTAL,
		}
		# Solo los PUESTOS se registran en Personal: ni un asiento ni una máquina de vending son una
		# vacante que cubrir. (Antes bastaba con `not es_asiento` porque las comodidades ni llegaban
		# hasta aquí — se descartaban arriba. Ahora que sí llegan, hay que excluirlas explícitamente.)
		if not es_asiento and not es_comodidad:
			if _personal != null:
				_personal.registrar_puesto(elemento_id, catalogo)
			else:
				push_warning("Construccion: puesto '%s' cargado SIN Personal inyectado" % elemento_id)
	_contador_ids = maxi(int(d.get("contador_ids", 0)), 0)
	# Los mostradores del save pueden venir de cuando medían 1 celda: se expanden a 2 si caben, y el
	# que no cabe se queda legado. Idempotente (cargar dos veces da lo mismo) — ver la función.
	migrar_huella_puestos()
	_refrescar_visual()


# ── Capa visual (Story 006 · TR-construction-001/003 — el visual REFLEJA el modelo) ──────────
## Solo presentación: TileMapLayer para las salas (color por servicio + tono por tipo) y escenas
## placeholder para puestos/asientos (`PackedScene` + `instantiate()` + `map_to_local` — NUNCA
## lógica en tiles, ADR-0004). Sin `montar_visual` (tests headless), todo esto queda inerte.

var _capa_salas: TileMapLayer = null
var _capa_elementos: Node2D = null
var _tam_celda: int = 40
## `tipo_sala_id -> source_id` del TileSet generado por código (un ATLAS de baldosas por tipo de
## sala; ver `_textura_de_celda`).
var _fuentes_tileset: Dictionary = {}
## `hex del color -> source_id` del atlas de baldosas de SUELO PINTADO (2026-08-04). Se crean bajo
## demanda —solo los colores que el jugador use de verdad— y se cachean: repintar la misma sala 20
## veces no genera 20 texturas. Se vacía en cada `montar_visual` (el TileSet se rehace ahí).
var _fuentes_color: Dictionary[String, int] = {}
## `hex del color -> source_id` del atlas de suelo LISO (2026-08-05 · quick-spec §3d, tarea 4) — el
## mismo patrón que `_fuentes_color` pero con una textura de color PLANO, sin junta ni variación de
## tono. Se vacía en cada `montar_visual`, igual que su hermana.
var _fuentes_color_liso: Dictionary[String, int] = {}
## ── SUELOS CON ASPECTO DE BALDOSA (2026-08-05) ──────────────────────────────────────────────
## El suelo no es un color plano por celda: cada celda se dibuja con una BALDOSA con una junta
## finísima en sus bordes y una variación de tono sutil por celda (determinista: hasheada de sus
## coordenadas — estable al mover la cámara o al redibujar). Todo se genera por código (sin assets
## externos) y se cachea por color: el atlas de una baldosa se crea una vez y se reutiliza para
## todas las celdas de ese color. El color elegido por el jugador sigue siendo el tono base
## dominante — junta y variación solo modulan por encima (`pintar_suelo`/`color_suelo_de`).
##
## ── LIMPIEZA DEL SUELO (2026-08-05 · quick-spec §3c) ────────────────────────────────────────
## Feedback del usuario comparando con la demo de Summer: *"suelo y paredes MÁS LIMPIOS: menos
## ruido visual que la baldosa actual con juntas marcadas"*. Tres decisiones, con sus números:
##
##   · La JUNTA baja de 2 px a **1 px** y su contraste de `darkened(0.30)` (+ desaturado a gris)
##     a un simple `darkened(0.06)`: a zoom normal casi desaparece y el suelo se lee como una
##     superficie continua con textura leve, no como una rejilla de azulejos de baño.
##   · La VARIACIÓN de tono por celda baja de ±7 % a **±3,5 %** — sigue rompiendo el color plano,
##     pero ya no se distingue "esa baldosa es más clara" de un vistazo.
##   · El DEGRADADO diagonal de cada baldosa baja de ±4 % a **±2 %**. Es el que más ruido metía
##     de los tres: al repetirse celda a celda dibujaba un patrón de claro/oscuro que marcaba la
##     rejilla incluso sin juntas.
##
## Y **MUERE EL ZÓCALO DEL SUELO**: la tira de rodapié pintada dentro de la baldosa (y sus 16
## filas de máscara de "qué lados tocan pared") se retira entera. El rodapié se muda a la BASE DEL
## MURO, que es donde está en la vida real — lo dibuja `ParedesSalas`/`TramoPared` (orden del
## usuario: *"rodapié más pequeño y EN LA PARED, no en el suelo"*). Consecuencia directa: el atlas
## de una baldosa pasa de `VARIACIONES × 16` a `VARIACIONES × 1`, y la coordenada de atlas de una
## celda ya no depende de los muros que la rodean (una celda del suelo vuelve a ser independiente
## de lo que se construya a su alrededor).
##
## Cuántas variaciones de tono tiene el atlas de una baldosa (eje X del atlas). La variación es
## sutil a propósito: modula el color elegido, nunca lo sustituye.
const VARIACIONES_BALDOSA: int = 6
## Amplitud de la variación de tono por celda (0.035 = ±3,5 % de claro/oscuro sobre el color base).
const AMPLITUD_VARIACION_BALDOSA: float = 0.035
## Ancho de la junta/lechada en píxeles dentro de la baldosa (borde exterior de cada lado).
const ANCHO_JUNTA: int = 1
## Cuánto se oscurece el color base para la junta. Muy bajo a propósito (ver la nota de limpieza):
## la junta insinúa el despiece de la baldosa, no lo dibuja.
const CONTRASTE_JUNTA: float = 0.06
## Amplitud del degradado diagonal de cada baldosa (luz arriba-izquierda → sombra abajo-derecha).
const AMPLITUD_DEGRADADO_BALDOSA: float = 0.02
## Alto en píxeles de las cajas placeholder (isométrico, 2026-07-30). Un mostrador se lee como
## mueble alto —a la altura del pecho de un muñeco de 22 px— y un asiento como algo bajo.
const ALTO_MOSTRADOR: float = 16.0
const ALTO_ASIENTO: float = 7.0
## Ámbar del punto con el que se marca una luz de techo: el color universal de "aquí hay una luz".
const COLOR_LUZ_TECHO := Color(1.0, 0.82, 0.35)
## z_index del rótulo de cada sala, RELATIVO a "Elementos" (que va a 0, dentro de la bolsa de y-sort
## compartida). 1 = por encima de cualquier pared y por debajo de la gente (`NPCsFlujo`, z 2) y de
## sus rótulos (`Z_ROTULOS_PUESTO`, z 2). Ver el porqué junto a su asignación en `_refrescar_visual`.
const Z_ETIQUETA_SALA: int = 1
## Color de las sillas de la sala de espera: gris de mobiliario institucional, un punto más cálido
## que las de las ventanillas para que las dos zonas se distingan de un vistazo.
const COLOR_SILLA_ESPERA := Color(0.38, 0.36, 0.34)
## La silla la construye la misma pieza que usan las ventanillas: una sola definición de "silla".
const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")

## ── SPRITES DE COMODIDADES DE 1 CELDA (2026-08-01, generalizado en la 2ª tanda) ─────────────────
## Cada comodidad de 1 celda con sprite propio sustituye a la caja gris genérica; la que no está en
## este diccionario se queda con su caja de siempre — no hace falta tocar nada para añadir una
## nueva comodidad sin sprite, ni para las que YA tienen sprite pero superficie > 1 (esas van por
## el camino especial de `_pieza_comodidad`, ver más abajo: `sofa_descanso`).
##
## Por comodidad, UN solo dato: `rotacion` (de las 4 que renderiza `render_mobiliario.gd`; todas a
## 0° por ahora — una comodidad no tiene "frente" al que mirar, a diferencia del mostrador de la
## ventanilla, así que cualquiera vale y se deja la de calibración).
##
## El `ancla` que había aquí (fracción del ancho/alto del PNG, una por comodidad, escrita a mano)
## se BORRÓ el 2026-08-03 con el auto-anclaje: la calcula `AnclajeSprite` midiendo los límites
## opacos del propio PNG. Ley del usuario: *"un objeto no puede salir de sus celdas — sabes los
## límites del objeto y los límites de las celdas"*. Añadir una comodidad con sprite ya no pide
## medir nada: basta con renderizarla y ponerla en esta lista.
const RUTA_SPRITES_MOBILIARIO := "res://assets/sprites/mobiliario/"
const COMODIDAD_EQUIPO_INFORMATICO := &"equipo_informatico"
const COMODIDAD_PAPELERA := &"papelera"
const COMODIDAD_DISPENSADOR_AGUA := &"dispensador_agua"
const COMODIDAD_RADIO := &"radio"
## `sofa_descanso` (superficie=3 en datos/, SIN TOCAR) NO está en este diccionario: va por
## `_pieza_sprite_asiento_sofa3`, con su propio sprite `asiento_sofa3` y rotación H/V — ver el
## aviso junto a `ASIENTO_SOFA3` sobre por qué no es el mismo sprite que se renderizó como
## `comodidad_sofa_descanso` (OBJ_011, un sofá de 1 plaza: quedó renderizado pero SIN USAR, a la
## espera de que el usuario le busque un destino de 1 celda de verdad).
const COMODIDAD_SOFA_DESCANSO := &"sofa_descanso"

## ── LAS ESTANTERÍAS: MUEBLES **DE PARED** (2026-08-04) ──────────────────────────────────────────
## Orden del usuario (quick-spec construccion-pintura-puertas-preview-2026-08-04 §1): *"se anclan al
## EXTREMO de su celda según su orientación, de modo que NO quede hueco entre la pared y la
## estantería — quedaría mal y poco realista"*. Es el primer mueble del juego que NO se centra en su
## celda, así que la capa visual estrena un concepto: `de_pared`.
##
## POR QUÉ EL FLAG VIVE AQUÍ Y NO EN EL `.tres`: "arrimarse a la pared" no cambia NADA del modelo
## —la estantería sigue ocupando su celda entera, sigue costando lo mismo y sigue estorbando igual
## al que pasa—; solo cambia dónde se PINTA su sprite dentro de esa celda. Es exactamente el tipo de
## dato que ya vive en este diccionario (el otro es la rotación del PNG). Meterlo en `comodidad.gd`
## metería una decisión de dibujo en el esquema de datos que comparten Paciencia, Flujo y Economía.
##
## `sprite`: el PREFIJO del PNG cuando no coincide con el id de catálogo. La estantería pequeña se
## cataloga como `estanteria_pequena` (nombre de jugador) pero su arte salió del render como
## `comodidad_estanteria_suelta_*` (OBJ_022, el brazo suelto de la esquina) — se declara el puente
## aquí en vez de renombrar unos PNG ya aprobados.
##
## `espalda_0`: hacia dónde da la ESPALDA el mueble en su PNG de 0°. Es el ÚNICO dato del arte que
## hay que declarar, y no se elige a ojo: sale de medir la base de los PNG (ver el comentario largo
## de `AnclajeSprite.CICLO_ESPALDA`, con los números). Las dos estanterías salieron del catálogo 3D
## giradas 90° la una respecto de la otra, así que no hay una tabla común: la grande da la espalda
## al OESTE a 0° y la pequeña al NORTE. Lo verifica un test contra el eje delgado medido.
const COMODIDAD_ESTANTERIA := &"estanteria"
const COMODIDAD_ESTANTERIA_PEQUENA := &"estanteria_pequena"

## ── LA ESTANTERÍA DE ESQUINA (2026-08-04, informe del hueco en el rincón) ──────────────────────
## Las dos sueltas (arriba) puestas por el jugador en dos celdas contiguas dejan ~1 celda de hueco
## en el rincón — son dos piezas de 1 celda cada una, no una pieza pensada para el ángulo. Solución:
## el CLUSTER ENTERO de OBJ_022 (los dos brazos juntos, sin despiece — `_render_estanterias.gd`,
## `NOMBRES_OBJ022_COMPLETA`) como mueble propio, `superficie = 2` en su `.tres` (dato de diseño, no
## medido: el modelo de `_celdas_de` NO soporta huellas en L — "Sin formas en L: la huella siempre
## es un rectángulo" — así que reserva 2 celdas EN LÍNEA, y el dibujo de la L, que sí es angular,
## sobresale visualmente hacia la celda diagonal que NO reserva. Limitación documentada y aceptada:
## es la única huella posible sin ampliar el modelo a formas no rectangulares).
##
## DOS DESVÍOS del patrón de mueble de pared de una sola arista (ver el bloque de arriba), medidos
## contra el PNG ya renderizado, no supuestos:
##  1. ROTACIÓN FIJA — un mueble de una arista necesita una cara distinta por pared (H→norte,
##     V→oeste); esta pieza YA muestra las DOS paredes en su misma pose (el rincón abierto mirando a
##     cámara) — medido: 0° es la ÚNICA rotación de las 4 que enseña el hueco de la L (90°/270° solo
##     enseñan una cara plana, un brazo tapa al otro; 180° enseña el rincón CERRADO, la parte de
##     atrás). `rotacion_sprite_comodidad` lo detecta por `espalda_extra_0` (ver abajo) y devuelve
##     siempre `datos["rotacion"]` (0), pase lo que pase con la R — la R solo decide hacia qué lado
##     crece la SEGUNDA celda reservada (`_paso_de`), no qué PNG se carga.
##  2. ARRIMADO A DOS PAREDES — `AnclajeSprite.semiejes_base` asume una base RECTANGULAR CONVEXA (ver
##     su cabecera); una L es CÓNCAVA y esa medida se rompe (comprobado: 0°/180° son el MISMO objeto
##     girado 180° y deberían medir igual, y dan 1,538 y 0,963 celdas — no es ruido, es la premisa
##     rota). Por eso esta pieza usa `AnclajeSprite.desvio_arrimado_esquina` (empuja el centro de la
##     base el medio celda COMPLETO en las dos direcciones, directo al vértice del rincón) en vez de
##     `desvio_arrimado` (que resta el fondo medido de una sola arista).
## `espalda_extra_0` es la MARCA de las dos desviaciones: solo la declara esta pieza.
const COMODIDAD_ESTANTERIA_ESQUINA := &"estanteria_esquina"

## A qué pared se arrima un mueble de pared en cada estado de la R. El modelo solo tiene DOS
## (`HORIZONTAL`/`VERTICAL`), así que de las cuatro paredes se llegan a dos, y se eligen las dos
## TRASERAS de la vista isométrica — norte y oeste. No es capricho: son las que quedan al fondo del
## dibujo, así que el mueble se ve DE FRENTE (con sus libros) y la pared no se le pone delante. Las
## otras dos existen en el arte y en la cuenta, pero enseñarían el panel trasero. Cuál de los cuatro
## PNG hace falta para cada una lo deduce `AnclajeSprite.rotacion_para_espalda`.
const ESPALDA_HORIZONTAL := Vector2i(0, -1)   # pared NORTE
const ESPALDA_VERTICAL := Vector2i(-1, 0)     # pared OESTE
static func _sprites_comodidad() -> Dictionary:
	return {
		COMODIDAD_EQUIPO_INFORMATICO: {"rotacion": 0},
		COMODIDAD_PAPELERA: {"rotacion": 0},
		COMODIDAD_DISPENSADOR_AGUA: {"rotacion": 0},
		COMODIDAD_RADIO: {"rotacion": 0},
		COMODIDAD_ESTANTERIA: {"rotacion": 0, "espalda_0": Vector2i(-1, 0)},
		COMODIDAD_ESTANTERIA_PEQUENA: {
			"sprite": "estanteria_suelta", "rotacion": 0, "espalda_0": Vector2i(0, -1),
		},
		COMODIDAD_ESTANTERIA_ESQUINA: {
			"sprite": "estanteria_esquina", "rotacion": 0,
			"espalda_0": ESPALDA_HORIZONTAL, "espalda_extra_0": ESPALDA_VERTICAL,
		},
	}


## ¿Es esta comodidad un mueble DE PARED (se arrima al borde trasero de su celda)? Lo es justo la
## que declara `espalda_0`: sin saber por dónde da la espalda no hay arrimado que valga, así que el
## dato ES la marca. Las que no lo declaran se siguen centrando en su celda, como toda la vida.
static func es_comodidad_de_pared(id_catalogo: StringName) -> bool:
	return _sprites_comodidad().get(id_catalogo, {}).has("espalda_0")


## Hacia qué pared da la espalda esta comodidad estando girada así. `Vector2i.ZERO` = no es de pared.
static func espalda_comodidad(id_catalogo: StringName, orientacion: int) -> Vector2i:
	if not es_comodidad_de_pared(id_catalogo):
		return Vector2i.ZERO
	return ESPALDA_VERTICAL if orientacion == VERTICAL else ESPALDA_HORIZONTAL


## La rotación del PNG que le toca a una comodidad según cómo esté girada en el modelo. Un mueble de
## pared (una sola arista) pide la que le deje la espalda contra SU pared; el resto del catálogo no
## tiene "frente" que enseñar, así que gire como gire usa siempre la misma (la de calibración).
##
## Una pieza DE ESQUINA (`espalda_extra_0`) es la MISMA excepción por otro motivo: YA enseña sus DOS
## paredes en una sola pose (medido: es la ÚNICA de las 4 rotaciones del render que abre el rincón a
## cámara — ver el aviso largo junto a `COMODIDAD_ESTANTERIA_ESQUINA`), así que tampoco cambia de PNG
## con la R — la R solo decide hacia qué celda crece la segunda reserva del modelo.
static func rotacion_sprite_comodidad(datos: Dictionary, orientacion: int) -> int:
	if not datos.has("espalda_0") or datos.has("espalda_extra_0"):
		return int(datos["rotacion"])
	var deseada: Vector2i = ESPALDA_VERTICAL if orientacion == VERTICAL else ESPALDA_HORIZONTAL
	return AnclajeSprite.rotacion_para_espalda(datos["espalda_0"], deseada)


## ── EL SOFÁ DE 3 PLAZAS, MULTI-CELDA (2026-08-01) ───────────────────────────────────────────────
## `sofa_descanso` (comodidad, `superficie` = 3 en datos/ — la ÚNICA pieza "de sentarse" de todo el
## catálogo que reserva más de 1 celda) sustituye su caja gris genérica —hoy ya elongada 3×1/1×3
## según `orientacion`, ver el `else` de `_crear_pieza`— por `asiento_sofa3` (ARQ_007, el sofá de 3
## plazas de verdad; estaba mal archivado como "arquitectura" en el catálogo por su tamaño).
##
## DOS rotaciones, no cuatro: el eje LARGO del sofá (1,90 m) corre en Z de mundo en su render a 0°,
## que es el mismo eje que usa `Proyeccion`/`Construccion` para VERTICAL (`render_mobiliario.gd`
## explica por qué: "el render usa X y Z donde la rejilla usa X e Y") — así que el par 0°/180° es
## la pose VERTICAL y el par 90°/270° la HORIZONTAL. Dentro de cada par, CUÁL de las dos se elige
## se decide por el asiento VACÍO (mismo criterio que las sillas, más arriba): tiene que abrir
## hacia ABAJO-IZQUIERDA de pantalla, hacia la sala — 180°/90° lo hacen, 0°/270° enseñan el
## RESPALDO de espaldas a cámara (comprobado mirando los 4 PNG el 2026-08-02, 2ª pasada: la
## primera elección —0° para VERTICAL— enseñaba el respaldo, no el asiento; corregido a 180°).
const ASIENTO_SOFA3 := "asiento_sofa3"
const ROT_ASIENTO_SOFA3_VERTICAL: int = 180
const ROT_ASIENTO_SOFA3_HORIZONTAL: int = 90
## Aquí vivían `ANCLA_FRACCION_ASIENTO_SOFA3_VERTICAL` (0.284, 0.728) y `..._HORIZONTAL`
## (0.697, 0.728) — una fracción de ancla a mano por rotación, porque el encuadre de 90°/270° no es
## el mismo que el de 0°/180°. BORRADAS el 2026-08-03: el auto-anclaje (`AnclajeSprite`) mide cada
## PNG por separado, así que la diferencia entre encuadres sale sola y no hay que mantener dos
## números. (No confundir con dónde se SIENTA la gente en el sofá: eso no vive aquí.)
## Dónde cae en pantalla la esquina (0,0) de la rejilla. Lo fija Main al montar el visual. Con la
## proyección isométrica NO es la esquina de arriba a la izquierda del dibujo, sino el vértice
## SUPERIOR del rombo grande (desde ahí el tablero se abre hacia los dos lados).
var _origen: Vector2 = Vector2.ZERO


## Crea la capa visual (la llama Main tras add_child): TileMapLayer "Salas" + Node2D "Elementos",
## alineados con el suelo del esqueleto (`desplazamiento` = posición del suelo; `tam_celda` = 40).
##
## `capa_profunda` (2026-08-03, orden de profundidad estructural): el nodo con `y_sort_enabled` del
## que debe colgar "Elementos" para que su mobiliario COMPITA POR PROFUNDIDAD con las paredes
## (`ParedesSalas` → `TramoPared`) y con los contenedores de las ventanillas (`NPCsFlujo`), en vez de
## ordenarse solo contra sí mismo. Lo crea `Main` ("MundoProfundo") y se lo pasa a los tres sistemas;
## cada uno sigue siendo dueño de SUS nodos —Construcción no sabe qué más hay ahí dentro, ni falta
## que le hace—. Verificado en el motor 4.6: un nodo con y-sort colgado de otro con y-sort mete a sus
## hijos en la MISMA bolsa de ordenación, no en una aparte.
##
## Si llega `null` (tests/herramientas que montan el visual sueltos), "Elementos" cuelga de este nodo
## como toda la vida: sigue ordenándose por profundidad entre sus propios muebles, sin paredes.
func montar_visual(
	tam_celda: int, desplazamiento: Vector2, capa_profunda: Node2D = null
) -> void:
	_tam_celda = tam_celda
	_origen = desplazamiento
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(tam_celda, tam_celda)
	_fuentes_color.clear()   # el TileSet se rehace aquí: los tiles de suelo pintado también
	_fuentes_color_liso.clear()   # y los del acabado liso (2026-08-05, tarea 4), igual que los de baldosa
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		var fuente := TileSetAtlasSource.new()
		fuente.texture = _textura_de_celda(_color_de_sala(tipo_sala))
		fuente.texture_region_size = Vector2i(tam_celda, tam_celda)
		_crear_tiles_de_atlas(fuente)
		_fuentes_tileset[tipo_sala.id] = tileset.add_source(fuente)
	_capa_salas = TileMapLayer.new()
	_capa_salas.name = "Salas"
	_capa_salas.tile_set = tileset
	# ISOMÉTRICO (2026-07-30): el TileSet sigue siendo CUADRADO de 40×40; lo que lo convierte en
	# rombos es la transformada del nodo. Se hace así, y no con un TileSet isométrico nativo, por
	# dos razones: (1) el suelo está PINTADO en el terreno, así que deformarlo con él es justo lo
	# correcto —una celda cuadrada deformada por esta matriz da el rombo exacto de 80×40—, y (2)
	# `local_to_map`/`to_local` siguen contestando en celdas del plano cuadrado, así que el clic
	# del modo construcción sigue funcionando sin tocar una línea. Ver `Proyeccion.transformada`.
	_capa_salas.transform = Proyeccion.transformada(desplazamiento)
	# ── LA ESCALERA DEL SUELO (2026-08-05 · quick-spec §3c) ──────────────────────────────────────
	# La tinta de sala baja de −1 a **−2** y el suelo liso de `Main` de −2 a −3, para dejar libre el
	# escalón −1: ahí va la CUADRÍCULA del modo construcción (`ModoConstruccion.RejillaConstruccion`),
	# que tiene que verse SOBRE el suelo de las salas (si no, la rejilla útil para construir
	# desaparecía justo dentro de las habitaciones, que es donde se construye). Medido con el diag
	# `_diag_suelo_limpio.gd`: con las dos a −1 la tinta ganaba y la rejilla solo se veía en el
	# solar vacío. El orden RELATIVO no cambia ni la invariante de abajo: suelo < tinta < rejilla <
	# paredes/mobiliario (0).
	#
	# 🐛 FIX (2026-08-03, muro divisorio): la TINTA de sala baja por debajo de cualquier
	# pared (que están en 0 y 1) y por encima del suelo liso de Main. Antes empataba
	# a z 0 con `ParedesFondo` y, al ir `ParedesSalas` antes que `Construccion` en el árbol, el suelo
	# de una sala se pintaba ENCIMA de las paredes de esa pasada: el muro divisorio entre dos salas
	# desaparecía tragado por el suelo de la sala vecina. Ver el comentario largo en `Main._crear_suelo`.
	_capa_salas.z_index = -2
	add_child(_capa_salas)
	_capa_elementos = Node2D.new()
	_capa_elementos.name = "Elementos"
	# Los elementos (mostradores, asientos, rótulos) están DE PIE sobre el suelo, no pintados en
	# él: esta capa NO lleva la transformada — si la llevara saldrían tumbados. Cada hijo se coloca
	# ya proyectado con `centro_en_pantalla()`, y se queda derecho.
	_capa_elementos.position = desplazamiento
	# Orden de dibujo por PROFUNDIDAD (nuevo con el isométrico): dentro de esta capa, lo que está
	# más abajo en pantalla se pinta encima de lo que está detrás. Sin esto, un mostrador del fondo
	# taparía al de delante según el orden en que se construyeron, que no significa nada.
	_capa_elementos.y_sort_enabled = true
	if capa_profunda != null:
		capa_profunda.add_child(_capa_elementos)
	else:
		add_child(_capa_elementos)
	_refrescar_visual()


## La celda de la rejilla bajo el cursor. Sin capa visual montada (headless/tests) → (-1,-1).
##
## ISOMÉTRICO (2026-07-30): sigue apoyándose en `local_to_map` del TileMapLayer, que ahora
## deshace la proyección solo (la transformada del nodo la incluye) — por eso este código no
## cambió al pasar a rombos.
func celda_bajo_cursor() -> Vector2i:
	if _capa_salas == null:
		return Vector2i(-1, -1)
	return _capa_salas.local_to_map(_capa_salas.get_local_mouse_position())


## La celda que contiene un punto de PANTALLA. ⚠️ Úsala (y no `celda_bajo_cursor`) siempre que la
## acción venga de un CLIC: `celda_bajo_cursor` lee el puntero del sistema *en ese instante*, no el
## punto donde se hizo clic — el bug del clic derecho del 2026-07-26, ya escrito en el manifiesto.
##
## ISOMÉTRICO (2026-07-30): pasa a ser matemática pura (`Proyeccion`) en vez de preguntarle al
## TileMapLayer. Da EXACTAMENTE el mismo resultado (la transformada del nodo sale de la misma
## fórmula, y hay test que lo comprueba), pero además funciona en headless — antes devolvía
## (-1,-1) sin capa montada, y eso hacía indemostrable por test todo el modo construcción.
func celda_de_punto(punto_pantalla: Vector2) -> Vector2i:
	return Proyeccion.celda_de_iso(punto_pantalla - _origen)


## El centro de una celda en el PLANO LÓGICO CUADRADO (el de la rejilla vista desde arriba).
##
## ⚠️ Esto NO es un punto de pantalla — para dibujar, usa `centro_en_pantalla()`. Este es el punto
## que entienden la NAVEGACIÓN y las distancias: la gente sigue andando por un plano cuadrado con
## celdas de 40 px, que es contra lo que están calibradas las velocidades y los cronómetros. La
## conversión a isométrico (2026-07-30) deliberadamente NO tocó este plano: ver la explicación
## larga en `src/foundation/proyeccion/proyeccion.gd`.
func centro_de_celda(celda: Vector2i) -> Vector2:
	return Proyeccion.centro_cuadrado(celda)


## El centro del rombo de una celda, en coordenadas de PANTALLA. Para colocar cualquier cosa que
## se DIBUJE (mostradores, asientos, rótulos, luces, muñecos).
func centro_en_pantalla(celda: Vector2i) -> Vector2:
	return _origen + Proyeccion.centro_iso(celda)


## El vértice de la rejilla en la intersección (columna, fila), en PANTALLA. Las paredes viven en
## las ARISTAS entre celdas, así que se dibujan de vértice a vértice.
func esquina_en_pantalla(columna: int, fila: int) -> Vector2:
	return _origen + Proyeccion.esquina_iso(columna, fila)


## Un punto de PANTALLA llevado al plano lógico cuadrado. Es la inversa de `centro_en_pantalla` sin
## redondear a celda: `celda_de_punto` te dice EN QUÉ celda has pinchado, y esta, en qué punto
## exacto DENTRO de ella — que es lo que necesita el pincel de muros para saber a qué arista
## apuntas.
func punto_cuadrado_de(punto_pantalla: Vector2) -> Vector2:
	return Proyeccion.desproyectar(punto_pantalla - _origen)


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
		# El suelo se pinta celda a celda por el CONJUNTO real, no recorriendo el rectangulo (fase B):
		# con una sala de forma no rectangular, el rect es solo la caja envolvente y pintarlo entero
		# coloreria huecos que no son de la sala.
		for celda: Vector2i in _salas[sala_id].get("celdas", {}):
			_capa_salas.set_cell(celda, _fuentes_tileset[tipo_id], _atlas_coord_de_celda(celda))
		# Etiqueta de la sala (respaldo daltónico: texto además del color).
		var tipo_sala: Resource = Datos.obtener(&"TipoSala", tipo_id)
		var etiqueta := Label.new()
		etiqueta.text = tipo_sala.nombre if tipo_sala != null else String(tipo_id)
		etiqueta.add_theme_font_size_override("font_size", 10)
		etiqueta.modulate = Color(1, 1, 1, 0.75)
		# ISOMÉTRICO: el rótulo va sobre el vértice de ARRIBA de la caja que envuelve la sala (que en
		# rombos es la esquina más alta del dibujo, no la de arriba-izquierda de un rectángulo).
		etiqueta.position = Proyeccion.esquina_iso(rect.position.x, rect.position.y) + Vector2(-22, 2)
		# El rótulo es INFORMACIÓN, no un mueble: sale del empate por profundidad (2026-08-03). Cae
		# justo sobre la esquina norte de la sala, donde ahora hay una pared de fondo de 34 px que le
		# gana por Y (la base del muro está más abajo que el texto) y se lo comería. Un z propio lo
		# saca de la bolsa de y-sort entera —el z manda sobre el y-sort— y lo deja por encima de
		# cualquier pared (0) y por debajo de la gente (2). Mismo criterio que `Z_ROTULOS_PUESTO`.
		etiqueta.z_index = Z_ETIQUETA_SALA
		_capa_elementos.add_child(etiqueta)
	# SUELO PINTADO (2026-08-04): segunda pasada, DESPUÉS del tinte de zona, para que la pintura del
	# jugador mande sobre el color de sala (que pasa a ser solo el fondo por defecto). Va aparte y no
	# dentro del bucle de salas porque una celda pintada NO tiene por qué pertenecer a ninguna sala:
	# el suelo de un pasillo también se pinta, y así se dibuja igual.
	for celda: Vector2i in _color_suelos:
		# ACABADO (2026-08-05, tarea 4): &"liso" usa el atlas de color plano, &"baldosa" el de
		# siempre (junta + variación). La elección es POR CELDA, igual que el color.
		var fuente_id: int = (
			_fuente_de_color_liso(_color_suelos[celda]) if acabado_suelo_de(celda) == ACABADO_LISO
			else _fuente_de_color(_color_suelos[celda])
		)
		_capa_salas.set_cell(celda, fuente_id, _atlas_coord_de_celda(celda))
	for elemento_id: StringName in _elementos:
		var elemento: Dictionary = _elementos[elemento_id]
		var es_asiento: bool = elemento["catalogo"] == ASIENTO_BASICO
		# El cuerpo crece hacia +X desde la celda ancla (misma convención que la validación de
		# colocación y que `_celdas_de`). Corregido 2026-07-29 ("el sofá sigue ocupando 1 lugar"):
		# el MODELO ya reservaba las 3 celdas, pero el DIBUJO era de 1 — y lo que el jugador juzga
		# es el dibujo (ADR-0004: el visual REFLEJA el modelo).
		var celdas: int = 1
		if not es_asiento:
			var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", elemento["catalogo"])
			if comodidad != null:
				celdas = maxi(comodidad.superficie, 1)
		# Los PUESTOS no se pintan aquí (2026-07-30): su mostrador lo dibuja el contenedor de la
		# ventanilla en `npcs_flujo._asegurar_visual_puesto`, junto al policía — y ahí, encima de él,
		# para que la mesa le tape las piernas como tapa a cualquiera que esté detrás de un
		# mostrador. Pintándolo aquí (en otra capa, más al fondo) el policía salía dibujado ENCIMA
		# de su propia mesa, que es lo que reportó el usuario.
		if Datos.obtener_silencioso(&"TipoPuesto", elemento["catalogo"]) != null:
			continue
		var orientacion: int = elemento.get("orientacion", HORIZONTAL)
		# La posición ya la fija `_crear_pieza` (ancla del modelo; el sprite, si lo hay, se desplaza
		# DENTRO a la última celda de su cuerpo — ver la cabecera de esa función).
		var instancia: Node2D = _crear_pieza(
			es_asiento, celdas, orientacion, es_de_techo(elemento["catalogo"]), elemento["catalogo"],
			elemento["celda"]
		)
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


## El `source_id` del tile de un COLOR de suelo pintado, creándolo la primera vez que hace falta.
## Devuelve -1 sin capa montada (headless): `_refrescar_visual` ya ha salido antes de llegar aquí.
func _fuente_de_color(color: Color) -> int:
	if _capa_salas == null or _capa_salas.tile_set == null:
		return -1
	var hex: String = PaletaPinturaScript.a_hex(color)
	if _fuentes_color.has(hex):
		return _fuentes_color[hex]
	var fuente := TileSetAtlasSource.new()
	fuente.texture = _textura_de_celda(color)
	fuente.texture_region_size = Vector2i(_tam_celda, _tam_celda)
	_crear_tiles_de_atlas(fuente)
	_fuentes_color[hex] = _capa_salas.tile_set.add_source(fuente)
	return _fuentes_color[hex]


## El `source_id` del tile de ACABADO LISO (2026-08-05 · quick-spec §3d, tarea 4) de un color,
## creándolo la primera vez que hace falta. Mismo patrón que `_fuente_de_color` (baldosa), pero con
## una textura sin junta ni variación de tono: un color PLANO, como el suelo crema del arranque —
## petición del usuario: *"esa textura que hay ahora como suelo baldosa o liso como está al inicio
## la sala de la comisaria"*.
func _fuente_de_color_liso(color: Color) -> int:
	if _capa_salas == null or _capa_salas.tile_set == null:
		return -1
	var hex: String = PaletaPinturaScript.a_hex(color)
	if _fuentes_color_liso.has(hex):
		return _fuentes_color_liso[hex]
	var fuente := TileSetAtlasSource.new()
	fuente.texture = _textura_lisa_de_celda(color)
	fuente.texture_region_size = Vector2i(_tam_celda, _tam_celda)
	_crear_tiles_de_atlas(fuente)
	_fuentes_color_liso[hex] = _capa_salas.tile_set.add_source(fuente)
	return _fuentes_color_liso[hex]


## El atlas LISO de un color: las mismas `VARIACIONES_BALDOSA` posiciones que el atlas de baldosa
## (para compartir `_crear_tiles_de_atlas`/`_atlas_coord_de_celda` sin ningún caso especial), pero
## con la MISMA imagen de color plano repetida en las seis — sin junta, sin degradado y sin
## variación de tono: el acabado &"liso" no cambia de una celda a otra, a propósito (es justo lo que
## lo distingue de la baldosa).
func _textura_lisa_de_celda(color: Color) -> ImageTexture:
	var atlas := Image.create(
		_tam_celda * VARIACIONES_BALDOSA, _tam_celda, false, Image.FORMAT_RGBA8
	)
	var plano := Image.create(_tam_celda, _tam_celda, false, Image.FORMAT_RGBA8)
	plano.fill(color)
	for variacion: int in VARIACIONES_BALDOSA:
		atlas.blit_rect(plano, Rect2i(0, 0, _tam_celda, _tam_celda), Vector2i(variacion * _tam_celda, 0))
	return ImageTexture.create_from_image(atlas)


## Genera el ATLAS de baldosas para un color: una TIRA de `VARIACIONES_BALDOSA` baldosas de
## `_tam_celda` px (eje X: variación de tono, determinista por celda). Se genera UNA vez por color
## y se cachea en `_fuentes_tileset`/`_fuentes_color` — nunca por frame.
##
## Las 16 filas de máscara de zócalo murieron el 2026-08-05 con el zócalo del suelo (quick-spec
## §3c): el atlas es hoy 16 veces más pequeño y no depende de los muros que rodean a cada celda.
func _textura_de_celda(color: Color) -> ImageTexture:
	var atlas := Image.create(
		_tam_celda * VARIACIONES_BALDOSA, _tam_celda, false, Image.FORMAT_RGBA8
	)
	for variacion: int in VARIACIONES_BALDOSA:
		var baldosa := _pintar_baldosa(color, variacion)
		atlas.blit_rect(
			baldosa, Rect2i(0, 0, _tam_celda, _tam_celda), Vector2i(variacion * _tam_celda, 0)
		)
	return ImageTexture.create_from_image(atlas)


## Pinta UNA baldosa de `_tam_celda` px: el color elegido como base dominante, un degradado muy
## suave de claro (arriba-izquierda) a oscuro (abajo-derecha), una variación de tono determinista
## por celda y una junta de 1 px de bajo contraste en los cuatro bordes. Los tres efectos son
## deliberadamente tenues — ver la nota de LIMPIEZA DEL SUELO junto a las constantes.
func _pintar_baldosa(color: Color, variacion: int) -> Image:
	var imagen := Image.create(_tam_celda, _tam_celda, false, Image.FORMAT_RGBA8)
	# Variación de tono determinista por celda: el índice llega ya hasheado de las coordenadas.
	# El color elegido manda SIEMPRE: la variación solo lo aclara/oscurece un ±3,5 % como mucho.
	var factor: float = (
		float(variacion) / float(VARIACIONES_BALDOSA - 1) - 0.5
	) * 2.0 * AMPLITUD_VARIACION_BALDOSA
	var base: Color = color.lightened(factor) if factor >= 0.0 else color.darkened(-factor)
	# Degradado diagonal (luz desde arriba-izquierda, sombra abajo-derecha).
	for y: int in _tam_celda:
		for x: int in _tam_celda:
			var t: float = float(x + y) / float(2 * _tam_celda)
			imagen.set_pixel(x, y, base
				.lightened(AMPLITUD_DEGRADADO_BALDOSA * (1.0 - t))
				.darkened(AMPLITUD_DEGRADADO_BALDOSA * t))
	# Junta: una línea de 1 px apenas más oscura que la baldosa, en los cuatro bordes. Ya no se
	# desatura hacia gris (eso la convertía en una rejilla marcada): solo insinúa el despiece.
	var junta: Color = base.darkened(CONTRASTE_JUNTA)
	for i: int in ANCHO_JUNTA:
		for x: int in _tam_celda:
			imagen.set_pixel(x, i, junta)
			imagen.set_pixel(x, _tam_celda - 1 - i, junta)
		for y: int in _tam_celda:
			imagen.set_pixel(i, y, junta)
			imagen.set_pixel(_tam_celda - 1 - i, y, junta)
	return imagen


## Crea los tiles del atlas en una fuente: `VARIACIONES_BALDOSA` variaciones, en las coordenadas
## (variación, 0). Se crean TODOS de una vez para que `_refrescar_visual` pueda apuntar a
## cualquiera sin crear tiles en caliente.
func _crear_tiles_de_atlas(fuente: TileSetAtlasSource) -> void:
	for variacion: int in VARIACIONES_BALDOSA:
		fuente.create_tile(Vector2i(variacion, 0))


## La coordenada del atlas para una celda: X = variación de tono (hash determinista de la celda),
## Y = 0 (fila única desde que murió el zócalo del suelo). Determinista y estable: la misma celda
## se dibuja SIEMPRE igual, se mueva la cámara o se redibuje lo que se redibuje; al repintar la
## celda con otro color solo cambia la fuente (el color), no esta coordenada.
func _atlas_coord_de_celda(celda: Vector2i) -> Vector2i:
	return Vector2i(_variacion_de_celda(celda), 0)


## Variación de tono de una celda: un hash entero determinista de sus coordenadas. Estable bajo
## redibujos y cámara (no depende de RNG ni del orden de iteración).
func _variacion_de_celda(celda: Vector2i) -> int:
	var h: int = celda.x * 73856093 ^ celda.y * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return posmod(h, VARIACIONES_BALDOSA)


## (2026-08-05 · quick-spec §3c) Aquí vivía `_mascara_zocalo_de_celda`: qué lados de la celda
## tocaban pared, para elegir la fila del atlas donde iba pintada la tira de zócalo. Murió con el
## zócalo del suelo — el rodapié es hoy una pieza del MURO (`ParedesSalas`/`TramoPared`), así que
## el suelo ya no necesita saber nada de los muros que lo rodean.


## Construye la pieza placeholder de un elemento: una CAJA ISOMÉTRICA (`PiezaIso`) que ocupa sus
## `celdas` reales sobre la rejilla, más la etiqueta del nombre si es un puesto.
##
## ISOMÉTRICO (2026-07-30, tras el aviso del usuario *"los objetos deben seguir la dirección de las
## cuadrículas, ahora mismo se superponen y se ponen en horizontal"*): antes esto era un `ColorRect`
## —un rectángulo RECTO de pantalla—, que sobre la rejilla cuadrada coincidía con la celda pero
## sobre rombos apuntaba a una dirección que no existe en el juego. Ahora la huella se calcula
## proyectando las celdas de verdad, así que un sofá de 3 celdas se estira en DIAGONAL siguiendo el
## suelo y dos piezas contiguas encajan en vez de solaparse.
##
## Sigue siendo placeholder (TR-construction-003): el arte real llegará tras el art bible.
func _crear_pieza(
	es_asiento: bool, celdas: int, orientacion: int, de_techo: bool, id_catalogo: StringName,
	celda_ancla: Vector2i
) -> Node2D:
	var raiz := Node2D.new()
	# El nodo raíz ancla SIEMPRE en la celda del MODELO — correcto para un asiento (1 celda) y para
	# la caja de código (`PiezaIso`, que YA crece desde ahí hacia +X/+Y, ver su cabecera). Un
	# sprite multi-celda corrige la SUYA propia más abajo con `Proyeccion.delta_ultima_celda` (regla
	# GENÉRICA verificada por composites, 2026-08-02: un sprite a rotación 0 ancla en la ÚLTIMA
	# celda de su cuerpo, no en la celda del modelo) — así la etiqueta y cualquier otro hijo futuro
	# de `raiz` se quedan en el ancla lógica sin que el desplazamiento del sprite los arrastre.
	raiz.position = Proyeccion.centro_iso(celda_ancla)
	# UN ASIENTO es UNA SILLA de verdad, con respaldo (petición del usuario 2026-08-01): sale por
	# otro camino y no llega a crear la caja. El respaldo va DETRÁS de quien se sienta: como la
	# gente mira al norte (a las ventanillas), el respaldo cae al sur — abajo a la izquierda en
	# pantalla. Sprite si lo hay (`silla_espera`, la MISMA silla de espera que usa el lado del
	# ciudadano en la ventanilla — ver `mesa_atencion.gd`), si no la de código de siempre.
	if es_asiento and not de_techo:
		raiz.add_child(MesaAtencionScript.silla_espera_o_defecto(Vector2(-20.0, 10.0), COLOR_SILLA_ESPERA))
		return raiz
	var sprites_comodidad: Dictionary = _sprites_comodidad()
	if not de_techo and id_catalogo == COMODIDAD_SOFA_DESCANSO and _hay_sprite_asiento_sofa3(orientacion):
		var sprite_pieza: Node2D = _pieza_sprite_asiento_sofa3(orientacion, celdas)
		sprite_pieza.position = Proyeccion.delta_ultima_celda(_paso_de(orientacion), celdas)
		raiz.add_child(sprite_pieza)
	elif (
		not de_techo and sprites_comodidad.has(id_catalogo)
		and _hay_sprite_comodidad(id_catalogo, orientacion)
	):
		# `celdas_visual`: para casi todo el catálogo es `celdas` (el sprite SÍ se estira/ancla a lo
		# largo de las celdas reservadas — sofá, mostrador…). La ESTANTERÍA DE ESQUINA es la
		# excepción (2026-08-04): reserva 2 celdas EN LÍNEA porque el modelo no soporta huellas en L
		# (ver el aviso largo de `COMODIDAD_ESTANTERIA_ESQUINA`), pero su ARTE es un rincón que pisa
		# la celda ANCLA, no un mueble que se reparte entre las dos — anclarlo con `celdas` real lo
		# correría media celda de más hacia la reserva. Se ancla como si fuera de 1 celda; lo que
		# RESERVA sigue siendo 2 (`_celdas_de`, sin tocar) — son dos cuentas distintas a propósito,
		# mismo patrón que ya separa huella de colocación y huella de obstáculo en los puestos.
		var celdas_visual: int = 1 if id_catalogo == COMODIDAD_ESTANTERIA_ESQUINA else celdas
		var sprite_pieza: Node2D = _pieza_sprite_comodidad(
			id_catalogo, sprites_comodidad[id_catalogo], _paso_de(orientacion), celdas_visual,
			orientacion
		)
		sprite_pieza.position = Proyeccion.delta_ultima_celda(_paso_de(orientacion), celdas_visual)
		raiz.add_child(sprite_pieza)
	else:
		var caja := PiezaIso.new()
		caja.name = "Caja"
		# La huella crece en +X o en +Y según cómo esté girada la pieza (rotar con R, 2026-07-30) —
		# es el MISMO eje que reserva el modelo en `_celdas_de`, así que lo que se ve es lo que se
		# ocupa.
		var ancho: int = 1 if orientacion == VERTICAL else celdas
		var largo: int = celdas if orientacion == VERTICAL else 1
		if de_techo:
			# Una luz se marca con un PUNTO ÁMBAR, no con una caja: cuelga del techo, no ocupa suelo y
			# no debe tapar lo que haya debajo (petición del usuario 2026-07-30).
			caja.configurar(1, 1, 0.0, COLOR_LUZ_TECHO, 1.0, true)
		else:
			caja.configurar(ancho, largo, ALTO_MOSTRADOR, Color(0.30, 0.33, 0.40))
		raiz.add_child(caja)
	if not es_asiento:
		var etiqueta := Label.new()
		etiqueta.name = "Etiqueta"
		etiqueta.add_theme_font_size_override("font_size", 9)
		# Justo DEBAJO de la huella: el nodo está en el centro del rombo, cuyo vértice de abajo cae
		# medio alto de rombo más abajo.
		etiqueta.position = Vector2(-30.0, Proyeccion.MEDIO_ALTO + 1.0)
		# Gotcha: un Control decorativo del mundo SE TRAGA los clics por defecto → los clics sobre
		# un puesto no llegaban a la herramienta de demoler. Decorativo: IGNORE.
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(etiqueta)
	return raiz


## ¿Hay un sprite renderizado para esta comodidad, en la rotación que le toca a esta `orientacion`?
## Solo las que están en `_sprites_comodidad()` lo comprueban siquiera — cualquier otro id cae
## siempre a la caja gris. (`orientacion` solo importa a las que declaran `rotacion_vertical`; el
## default deja la llamada de siempre funcionando igual.)
func _hay_sprite_comodidad(id_catalogo: StringName, orientacion: int = HORIZONTAL) -> bool:
	var datos: Dictionary = _sprites_comodidad()[id_catalogo]
	return ResourceLoader.exists(
		_ruta_sprite_comodidad(id_catalogo, rotacion_sprite_comodidad(datos, orientacion))
	)


## La ruta del PNG. El nombre del fichero sale del PREFIJO declarado en `_sprites_comodidad()`
## (`sprite`), que por defecto es el propio id de catálogo — ver el bloque de las estanterías.
func _ruta_sprite_comodidad(id_catalogo: StringName, rotacion: int) -> String:
	var datos: Dictionary = _sprites_comodidad().get(id_catalogo, {})
	var prefijo: String = String(datos.get("sprite", String(id_catalogo)))
	return "%scomodidad_%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, prefijo, rotacion]


## La comodidad de sprite: un `Sprite2D` anclado por el mismo punto que la `PiezaIso` que sustituye
## (el centro del rombo de la celda donde cuelga el nodo, `Vector2.ZERO` en local) — mismo patrón
## que `MesaAtencionScript._pieza_sprite_mostrador`. `datos` es la entrada de `_sprites_comodidad()`
## para este id (solo `rotacion`: el ancla la mide `AnclajeSprite`). `paso`/`celdas` son los mismos
## con los que el llamante calcula `Proyeccion.delta_ultima_celda` para posicionar el nodo — el
## auto-anclaje los necesita para saber cuánto hay del centro de la huella al de la última celda.
##
## ARRIMADO A PARED (2026-08-04): las comodidades marcadas `de_pared` (las estanterías) no se quedan
## centradas — tras anclarlas, el sprite se corre hasta que el borde TRASERO de su base cae sobre la
## línea de la celda por la que da la espalda. Ese corrimiento lo calcula `AnclajeSprite` midiendo
## el fondo del propio PNG (ni un número a mano), y sigue a la rotación: girar el mueble con la R
## cambia qué pared es la de atrás y el arrimado se recalcula solo.
##
## Se aplica al `Sprite2D` y NO al nodo `Caja` a propósito: la `Caja` marca la celda LÓGICA del
## mueble, que es lo que ordena la profundidad (y-sort) y lo que leen los tests de huella. Lo que se
## mueve es el dibujo dentro de su celda, que es justo lo que pidió el usuario.
func _pieza_sprite_comodidad(
	id_catalogo: StringName, datos: Dictionary, paso: Vector2i, celdas: int,
	orientacion: int = HORIZONTAL
) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Caja"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var rotacion: int = rotacion_sprite_comodidad(datos, orientacion)
	sprite.texture = load(_ruta_sprite_comodidad(id_catalogo, rotacion))
	AnclajeSprite.aplicar(sprite, paso, celdas)
	if sprite.texture == null:
		raiz.add_child(sprite)
		return raiz
	if datos.has("espalda_extra_0"):
		# DE ESQUINA — toca dos paredes a la vez: al vértice, no a la mitad de una arista (ver el
		# aviso largo de `COMODIDAD_ESTANTERIA_ESQUINA` y la cabecera de `desvio_arrimado_esquina`).
		sprite.position = AnclajeSprite.desvio_arrimado_esquina(
			AnclajeSprite.espalda_girada(datos["espalda_0"], rotacion),
			AnclajeSprite.espalda_girada(datos["espalda_extra_0"], rotacion),
		)
	elif datos.has("espalda_0"):
		sprite.position = AnclajeSprite.desvio_arrimado(
			sprite.texture, AnclajeSprite.espalda_girada(datos["espalda_0"], rotacion)
		)
	raiz.add_child(sprite)
	return raiz


## ¿Hay sprite del sofá de 3 plazas para esta `orientacion`? Ver `_rotacion_asiento_sofa3`.
func _hay_sprite_asiento_sofa3(orientacion: int) -> bool:
	return ResourceLoader.exists(_ruta_sprite_asiento_sofa3(orientacion))


func _rotacion_asiento_sofa3(orientacion: int) -> int:
	return ROT_ASIENTO_SOFA3_HORIZONTAL if orientacion == HORIZONTAL else ROT_ASIENTO_SOFA3_VERTICAL


func _ruta_sprite_asiento_sofa3(orientacion: int) -> String:
	return "%s%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, ASIENTO_SOFA3, _rotacion_asiento_sofa3(orientacion)]


## El sofá de sprite, en la rotación que toca según `orientacion` (H/V, rotar con R) — mismo patrón
## de ancla que el resto: la mide `AnclajeSprite` del PNG de ESA rotación, así que los dos encuadres
## (0°/180° y 90°/270°, que no coinciden) se resuelven solos. `celdas` = la superficie de catálogo.
func _pieza_sprite_asiento_sofa3(orientacion: int, celdas: int) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Caja"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(_ruta_sprite_asiento_sofa3(orientacion))
	AnclajeSprite.aplicar(sprite, _paso_de(orientacion), celdas)
	raiz.add_child(sprite)
	return raiz


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
	coste_muro = maxf(config.coste_muro, 0.0)
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
