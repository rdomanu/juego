extends Node
## Datos — el catálogo data-driven del juego cargado e indexado por `id` (autoload "Datos", el 3º).
##
## Al arrancar carga TODOS los `.tres` de `res://datos/<carpetas>` (una carpeta por tipo) y los indexa en
## diccionarios anidados `{ tipo -> { id -> Resource } }`. Los sistemas resuelven definiciones por `id` con
## `Datos.obtener(tipo, id)` — la fuente única de "qué cosas existen" en la comisaría (R0 data-driven, R1
## definición≠instancia). Es capa Foundation SIN lógica de juego: solo carga y lookup read-only.
##
## Regla rectora (control-manifest Foundation / ADR-0003): lo que devuelve `obtener` es una PLANTILLA
## COMPARTIDA read-only — los consumidores NUNCA la mutan; crean sus instancias de partida aparte (R1).
##
## VALIDA en carga (Story 003): tras indexar, `validar()` comprueba integridad referencial (refs colgantes),
## ids únicos (duplicados detectados en `_indexar`), clamp de rangos numéricos e invariante de solvencia R5.
## Modo desarrollo = fallo ruidoso (push_error); modo jugador = degradación segura + log (push_warning). El
## catálogo sigue siendo read-only en juego; la ÚNICA mutación permitida es el clamp de rangos EN CARGA
## (`_validar_clamp`), documentada como excepción. NO llama a otros sistemas por nombre (regla de capas).
##
## Story: production/epics/datos/story-002-autoload-carga-lookup.md (carga/lookup) +
##        production/epics/datos/story-003-validacion-en-carga.md (validación)
## TR-data-001 (catálogo desde fuente externa) · TR-data-002 (def read-only) · TR-data-003 (validación en
## carga) · TR-data-004 (lookup por id) · ADR-0003 (formato del catálogo .tres) · control-manifest §Foundation

# ── Scripts del esquema (Story 001) por RUTA LITERAL ─────────────────────────────────────
# Se preload-an por RUTA (no por `class_name`) a propósito: en headless "en frío" (GdUnit4 discovery,
# CI), el registro global de `class_name` puede no haber resuelto aún las clases del esquema, así que
# `res is TramiteDoc` fallaría con "identifier not declared". La constante preload-ada por ruta no
# depende de ese registro y es estable. (Mismo gotcha que el `extends` por ruta de la Story 001.)
const AtencionScript := preload("res://src/foundation/datos/esquema/atencion.gd")
const TramiteDocScript := preload("res://src/foundation/datos/esquema/tramite_doc.gd")
const DenunciaODACScript := preload("res://src/foundation/datos/esquema/denuncia_odac.gd")
const TipoPuestoScript := preload("res://src/foundation/datos/esquema/tipo_puesto.gd")
const TipoSalaScript := preload("res://src/foundation/datos/esquema/tipo_sala.gd")
const TipoAgenteScript := preload("res://src/foundation/datos/esquema/tipo_agente.gd")
const CostesScript := preload("res://src/foundation/datos/esquema/costes.gd")
const EscenarioScript := preload("res://src/foundation/datos/esquema/escenario.gd")

## Raíz del catálogo en disco (empaquetado en `res://`, read-only al exportar — ADR-0003).
const RUTA_CATALOGO := "res://datos/"

## Carpetas del catálogo que se recorren al cargar (una por familia de definición — ADR-0003 decisión 2).
## El TIPO real de cada resource se determina por su script (ver `_clave_tipo`), no por la carpeta: la
## carpeta solo acota dónde buscar `.tres`.
const CARPETAS: Array[String] = [
	"tramites", "denuncias", "puestos", "salas", "agentes", "costes", "escenarios",
]

## Claves `StringName` de tipo usadas para indexar y en la API pública `obtener`/`obtener_todos`.
## Coinciden con el `class_name` de cada script del esquema (contrato con los consumidores y los tests).
const TIPO_TRAMITE_DOC := &"TramiteDoc"
const TIPO_DENUNCIA_ODAC := &"DenunciaODAC"
const TIPO_TIPO_PUESTO := &"TipoPuesto"
const TIPO_TIPO_SALA := &"TipoSala"
const TIPO_TIPO_AGENTE := &"TipoAgente"
const TIPO_COSTES := &"Costes"
const TIPO_ESCENARIO := &"Escenario"

## Minutos operativos de un puesto ODAC al día para el chequeo R5 (GDD F8): supuesto CONSERVADOR de
## ~16 h/día (dotación de ~2 de los 3 turnos; la operativa 24h real la fijan Personal/Horarios). 16×60=960.
## Es un parámetro de la comprobación de solvencia, NO un dato de partida.
const MINUTOS_OPERATIVOS := 960

## Servicio (String de `TipoPuesto.servicio` / `Atencion.servicio`) que cuenta para la capacidad R5 de ODAC.
const SERVICIO_ODAC := "ODAC"

## Índice del catálogo: `{ &"TramiteDoc": { &"dni": <Resource>, ... }, &"DenunciaODAC": {...}, ... }`.
## Clave externa = tipo (StringName); clave interna = `id` de la definición (StringName); valor = la
## definición cargada (misma referencia siempre → fuente única, R1/TR-data-004). Se llena en `_ready`.
var _por_tipo: Dictionary = {}

## Modo de operación de la validación (Story 003 / ADR-0003): en desarrollo un error de integridad se
## reporta ruidoso (push_error) y NO se degrada el catálogo; en modo jugador se DEGRADA con log
## (push_warning) — se descarta la referencia colgante, gana el primer id duplicado, etc. Por defecto sigue
## a `OS.is_debug_build()`; los tests lo fijan a `false` para ejercitar la degradación determinista.
var modo_desarrollo: bool = OS.is_debug_build()

## Avisos acumulados durante la INDEXACIÓN (hoy: ids duplicados detectados en `_indexar`). `validar()` los
## incorpora a su lista de mensajes. Se limpia al reindexar (`_cargar_catalogo`).
var _avisos_carga: Array[String] = []


## Carga e indexa TODO el catálogo al arrancar. `Datos` es el 3º autoload (tras RNGService): al terminar
## este `_ready`, cualquier sistema posterior puede resolver definiciones por `id`.
##
## Tras indexar, VALIDA el catálogo (Story 003): en `modo_desarrollo` los mensajes "ERROR: " (integridad)
## van a `push_error` y los "WARNING: " a `push_warning`; en modo jugador TODO va a `push_warning` (la
## degradación segura ya se aplicó dentro de `validar`). NO se hace `assert` ni se aborta el proceso: un
## crash aquí mataría el runner de tests y el arranque del juego. R5 no se evalúa aquí (`validar()` sin
## `demanda_max_odac`); su verificación con demanda real la dispara Demanda cuando exista.
func _ready() -> void:
	_cargar_catalogo()
	var problemas: Array[String] = validar()
	for msg: String in problemas:
		if modo_desarrollo and msg.begins_with("ERROR: "):
			push_error(msg)
		else:
			push_warning(msg)


## Devuelve la definición del `tipo` con ese `id`, o `null` si no existe (con `push_warning`, sin romper).
## SIEMPRE la MISMA referencia read-only (fuente única, R1): el llamante NUNCA la muta (control-manifest).
## `tipo` es una de las constantes TIPO_* (p. ej. `&"TramiteDoc"`).
func obtener(tipo: StringName, id: StringName) -> Resource:
	var por_id: Dictionary = _por_tipo.get(tipo, {})
	if not por_id.has(id):
		push_warning("Datos.obtener: no existe id '%s' en tipo '%s' -> null" % [id, tipo])
		return null
	return por_id[id]


## Devuelve TODAS las definiciones de `tipo` (una copia del Array de valores; las definiciones en sí son
## las referencias compartidas read-only). Si el tipo no existe / está vacío, devuelve un Array vacío.
func obtener_todos(tipo: StringName) -> Array:
	var por_id: Dictionary = _por_tipo.get(tipo, {})
	return por_id.values()


# ── Validación en carga (Story 003 · TR-data-003 · ADR-0003) ─────────────────────────────
## Valida el catálogo ya indexado y devuelve la lista de problemas (vacía si todo OK). Cada mensaje lleva
## prefijo "ERROR: " (integridad — un dato roto) o "WARNING: " (aviso de diseño — clamp, id duplicado, R5,
## servicio inoperable). NO usa azar ni reloj (determinista).
##
## `demanda_max_odac` es la estimación de demanda máxima de ODAC/día (la posee Demanda). SOLO si es > 0 se
## evalúa el invariante de solvencia R5 (AC-D12/D13): con 0 (por defecto) R5 no se comprueba, porque la
## fórmula de demanda vive fuera de Datos. El resto de chequeos corren siempre.
##
## Efecto secundario permitido (ÚNICA excepción al read-only del catálogo, y SOLO en carga): `_validar_clamp`
## ajusta in situ los campos numéricos fuera de rango de las definiciones. Documentado en su helper.
##
## Modo dev vs jugador: en `modo_desarrollo == false` (jugador) una referencia colgante se DESCARTA de su
## lista (degradación segura); en modo dev NO se descarta (solo se reporta ERROR para que el fallo sea
## ruidoso). El clamp y los warnings de diseño ocurren igual en ambos modos.
func validar(demanda_max_odac: int = 0) -> Array[String]:
	var msgs: Array[String] = []
	# Avisos ya detectados durante la indexación (ids duplicados). Se incorporan primero.
	msgs.append_array(_avisos_carga)
	_validar_integridad(msgs)
	_validar_clamp(msgs)
	_validar_servicios(msgs)
	_validar_r5(msgs, demanda_max_odac)
	return msgs


# ── Carga (privado) ──────────────────────────────────────────────────────────────────────
## Recorre las carpetas del catálogo, carga cada `.tres` con `load()` y lo indexa por tipo+id.
func _cargar_catalogo() -> void:
	_por_tipo.clear()
	_avisos_carga.clear()
	for carpeta: String in CARPETAS:
		_cargar_carpeta(RUTA_CATALOGO.path_join(carpeta))


## Carga todos los `.tres` de una carpeta y los indexa. Ausencia de la carpeta = aviso, no error (la
## carga del resto continúa; el catálogo lo puebla el script-herramienta `tools/build_catalogo.gd`).
func _cargar_carpeta(ruta: String) -> void:
	if not DirAccess.dir_exists_absolute(ruta):
		push_warning("Datos: carpeta de catálogo ausente '%s' (¿se generó el catálogo?)" % ruta)
		return
	for archivo: String in DirAccess.get_files_at(ruta):
		# En export los `.tres` se reempaquetan como `.remap`; `get_files_at` los lista así. Se normaliza
		# la extensión y se filtra a solo recursos de texto para no cargar `.uid`/`.import` u otros.
		if not (archivo.ends_with(".tres") or archivo.ends_with(".tres.remap")):
			continue
		var ruta_archivo: String = ruta.path_join(archivo.trim_suffix(".remap"))
		var recurso: Resource = load(ruta_archivo)
		if recurso == null:
			push_warning("Datos: no se pudo cargar '%s'" % ruta_archivo)
			continue
		_indexar(recurso)


## Determina el tipo de una definición por su script y la indexa en `_por_tipo[tipo][id]`.
## ⚠️ Las clases HIJAS (TramiteDoc/DenunciaODAC) se comprueban ANTES que la base Atencion: `res is
## AtencionScript` es `true` también para las hijas (herencia), así que probar la base primero las
## clasificaría mal. `Atencion` es abstracta (nunca se instancia como `.tres` suelto): si llegara una,
## se avisa y se ignora.
func _indexar(recurso: Resource) -> void:
	var tipo: StringName = _clave_tipo(recurso)
	if tipo == &"":
		push_warning("Datos: recurso de tipo desconocido ignorado '%s'" % recurso.resource_path)
		return
	var id: StringName = recurso.get(&"id")
	if id == &"":
		push_warning("Datos: recurso sin 'id' ignorado '%s'" % recurso.resource_path)
		return
	if not _por_tipo.has(tipo):
		_por_tipo[tipo] = {}
	# Detección de id DUPLICADO (Story 003, AC-D07 / degradación de Edge Cases): los `id` son únicos por
	# tipo (R3). Si ya hay una definición con este id en el tipo, GANA LA PRIMERA (no se sobrescribe) y se
	# apila un aviso que `validar()` reportará. Así el lookup es determinista y el catálogo queda usable.
	if _por_tipo[tipo].has(id):
		_avisos_carga.append(
			"WARNING: id duplicado '%s' en tipo '%s' (gana la primera definición, se ignora la segunda)"
			% [id, tipo]
		)
		return
	_por_tipo[tipo][id] = recurso


## Mapea una definición a su clave de tipo comprobando su script (por RUTA, ver nota de los preload).
## HIJAS antes que la base (ver `_indexar`). Devuelve `&""` si no es ningún tipo del esquema.
func _clave_tipo(recurso: Resource) -> StringName:
	if recurso is TramiteDocScript:
		return TIPO_TRAMITE_DOC
	if recurso is DenunciaODACScript:
		return TIPO_DENUNCIA_ODAC
	if recurso is TipoPuestoScript:
		return TIPO_TIPO_PUESTO
	if recurso is TipoSalaScript:
		return TIPO_TIPO_SALA
	if recurso is TipoAgenteScript:
		return TIPO_TIPO_AGENTE
	if recurso is CostesScript:
		return TIPO_COSTES
	if recurso is EscenarioScript:
		return TIPO_ESCENARIO
	return &""


# ── Validación (privado) — helpers de `validar()` ────────────────────────────────────────
## Integridad referencial (R3 / AC-D06 / AC-D20a): toda referencia por `id` entre definiciones debe apuntar
## a un `id` existente en el índice de su tipo destino. Un campo de referencia VACÍO (`&""`) NO es colgante
## (no se valida). El mensaje SIEMPRE nombra el `id` colgante. En modo jugador (`modo_desarrollo == false`)
## la referencia inválida se DESCARTA in situ de su lista (o se borra la clave de `tope_construible`),
## dejando el resto del catálogo usable (degradación segura); en modo dev NO se descarta (solo ERROR ruidoso).
func _validar_integridad(msgs: Array[String]) -> void:
	var ids_atencion: Dictionary = _ids_de_tipos([TIPO_TRAMITE_DOC, TIPO_DENUNCIA_ODAC])
	var ids_puesto: Dictionary = _ids_de_tipo(TIPO_TIPO_PUESTO)

	# TipoPuesto.atenciones_admitidas -> ids de TramiteDoc ∪ DenunciaODAC.
	for puesto: Resource in obtener_todos(TIPO_TIPO_PUESTO):
		_validar_lista_ids(
			puesto, &"atenciones_admitidas", ids_atencion, "TipoPuesto", "atención", msgs
		)
	# TipoSala.puestos_admitidos -> ids de TipoPuesto.
	for sala: Resource in obtener_todos(TIPO_TIPO_SALA):
		_validar_lista_ids(sala, &"puestos_admitidos", ids_puesto, "TipoSala", "puesto", msgs)
	# TipoAgente.puestos_operables -> ids de TipoPuesto.
	for agente: Resource in obtener_todos(TIPO_TIPO_AGENTE):
		_validar_lista_ids(agente, &"puestos_operables", ids_puesto, "TipoAgente", "puesto", msgs)
	# Atencion.tipo_puesto (StringName suelto) -> id de TipoPuesto.
	for tipo_at: StringName in [TIPO_TRAMITE_DOC, TIPO_DENUNCIA_ODAC]:
		for atencion: Resource in obtener_todos(tipo_at):
			_validar_ref_simple(
				atencion, &"tipo_puesto", ids_puesto, String(tipo_at), "puesto", msgs
			)
	# Escenario.tope_construible: cada CLAVE (StringName) -> id de TipoPuesto.
	for esc: Resource in obtener_todos(TIPO_ESCENARIO):
		_validar_claves_tope(esc, ids_puesto, msgs)


## Comprueba cada `id` de una lista `Array[StringName]` (`campo`) contra `ids_validos`. Reporta los colgantes
## nombrándolos y, en modo jugador, los descarta de la lista in situ (reasigna la lista filtrada al campo).
func _validar_lista_ids(
	def: Resource, campo: StringName, ids_validos: Dictionary,
	tipo_origen: String, etiqueta_dest: String, msgs: Array[String]
) -> void:
	var lista: Array = def.get(campo)
	if lista == null:
		return
	var validos: Array[StringName] = []
	var id_origen: StringName = def.get(&"id")
	for ref: StringName in lista:
		if ref == &"":
			validos.append(ref)  # referencia vacía: no es colgante, se conserva
			continue
		if ids_validos.has(ref):
			validos.append(ref)
			continue
		msgs.append(
			"ERROR: referencia colgante en %s '%s': %s '%s' (en %s) no existe"
			% [tipo_origen, id_origen, etiqueta_dest, ref, campo]
		)
	# Degradación segura (solo modo jugador): reemplaza la lista por la filtrada.
	if not modo_desarrollo and validos.size() != lista.size():
		def.set(campo, validos)


## Comprueba una referencia `StringName` suelta (`campo`) contra `ids_validos`. Reporta si es colgante y, en
## modo jugador, la limpia a `&""` (degradación: la definición pierde el enlace pero sigue siendo usable).
func _validar_ref_simple(
	def: Resource, campo: StringName, ids_validos: Dictionary,
	tipo_origen: String, etiqueta_dest: String, msgs: Array[String]
) -> void:
	var ref: StringName = def.get(campo)
	if ref == &"":
		return  # referencia vacía: no es colgante
	if ids_validos.has(ref):
		return
	var id_origen: StringName = def.get(&"id")
	msgs.append(
		"ERROR: referencia colgante en %s '%s': %s '%s' (en %s) no existe"
		% [tipo_origen, id_origen, etiqueta_dest, ref, campo]
	)
	if not modo_desarrollo:
		def.set(campo, &"")


## Comprueba que cada CLAVE de `Escenario.tope_construible` es un `id` de TipoPuesto existente. Reporta las
## colgantes; en modo jugador borra la clave del diccionario (degradación).
func _validar_claves_tope(esc: Resource, ids_puesto: Dictionary, msgs: Array[String]) -> void:
	var topes: Dictionary = esc.get(&"tope_construible")
	if topes == null:
		return
	var id_esc: StringName = esc.get(&"id")
	var claves_colgantes: Array[StringName] = []
	for clave: StringName in topes.keys():
		if clave == &"":
			continue
		if ids_puesto.has(clave):
			continue
		msgs.append(
			"ERROR: referencia colgante en Escenario '%s': puesto '%s' (en tope_construible) no existe"
			% [id_esc, clave]
		)
		claves_colgantes.append(clave)
	if not modo_desarrollo:
		for clave: StringName in claves_colgantes:
			topes.erase(clave)


## Clamp de rangos numéricos (Edge Cases / AC-D09/D10/D11/D20c). ⚠️ ÚNICA MUTACIÓN permitida del catálogo,
## excepción al read-only y SOLO en carga: ajusta in situ los campos fuera de rango de las definiciones ya
## cargadas. Reglas: `duracion_min < 1` → 1; `tarifa_eur`/`aforo_espera`/`coste_construccion_eur`(puesto y
## sala)/`salario_dia_eur`/`peonada_eur_hora` negativos → 0; `retorno_dgp_min`/`retorno_dgp_max` fuera de
## [0,1] → clamp; si tras el clamp `min > max` → `min = max`. Siempre con WARNING nombrando la definición.
func _validar_clamp(msgs: Array[String]) -> void:
	# duracion_min >= 1 (todas las Atencion: TramiteDoc + DenunciaODAC).
	for tipo_at: StringName in [TIPO_TRAMITE_DOC, TIPO_DENUNCIA_ODAC]:
		for atencion: Resource in obtener_todos(tipo_at):
			_clamp_min_int(atencion, &"duracion_min", 1, String(tipo_at), msgs)
	# tarifa_eur >= 0 (solo TramiteDoc).
	for tramite: Resource in obtener_todos(TIPO_TRAMITE_DOC):
		_clamp_min_int(tramite, &"tarifa_eur", 0, "TramiteDoc", msgs)
	# TipoPuesto: coste_construccion_eur >= 0.
	for puesto: Resource in obtener_todos(TIPO_TIPO_PUESTO):
		_clamp_min_int(puesto, &"coste_construccion_eur", 0, "TipoPuesto", msgs)
	# TipoSala: aforo_espera >= 0, coste_construccion_eur >= 0.
	for sala: Resource in obtener_todos(TIPO_TIPO_SALA):
		_clamp_min_int(sala, &"aforo_espera", 0, "TipoSala", msgs)
		_clamp_min_int(sala, &"coste_construccion_eur", 0, "TipoSala", msgs)
	# TipoAgente: salario_dia_eur >= 0.
	for agente: Resource in obtener_todos(TIPO_TIPO_AGENTE):
		_clamp_min_int(agente, &"salario_dia_eur", 0, "TipoAgente", msgs)
	# Costes: peonada_eur_hora >= 0 y retorno_dgp_min/max en [0,1] con min <= max.
	for costes: Resource in obtener_todos(TIPO_COSTES):
		_clamp_min_float(costes, &"peonada_eur_hora", 0.0, "Costes", msgs)
		_clamp_retorno_dgp(costes, msgs)


## Clampa un campo `int` a un mínimo `minimo` (mutación en carga). Reporta WARNING si tuvo que ajustar.
func _clamp_min_int(
	def: Resource, campo: StringName, minimo: int, tipo_origen: String, msgs: Array[String]
) -> void:
	var valor: int = def.get(campo)
	if valor >= minimo:
		return
	def.set(campo, minimo)
	msgs.append(
		"WARNING: %s '%s': %s=%d fuera de rango, clampado a %d"
		% [tipo_origen, def.get(&"id"), campo, valor, minimo]
	)


## Clampa un campo `float` a un mínimo `minimo` (mutación en carga). Reporta WARNING si tuvo que ajustar.
func _clamp_min_float(
	def: Resource, campo: StringName, minimo: float, tipo_origen: String, msgs: Array[String]
) -> void:
	var valor: float = def.get(campo)
	if valor >= minimo:
		return
	def.set(campo, minimo)
	msgs.append(
		"WARNING: %s '%s': %s=%s fuera de rango, clampado a %s"
		% [tipo_origen, def.get(&"id"), campo, valor, minimo]
	)


## Clampa `retorno_dgp_min`/`retorno_dgp_max` a [0,1] y garantiza `min <= max` (Edge Cases / AC-D10). Muta en
## carga; reporta WARNING por cada ajuste.
func _clamp_retorno_dgp(costes: Resource, msgs: Array[String]) -> void:
	var id_c: StringName = costes.get(&"id")
	var min_v: float = costes.get(&"retorno_dgp_min")
	var max_v: float = costes.get(&"retorno_dgp_max")
	var min_clamp: float = clampf(min_v, 0.0, 1.0)
	var max_clamp: float = clampf(max_v, 0.0, 1.0)
	if not is_equal_approx(min_clamp, min_v):
		costes.set(&"retorno_dgp_min", min_clamp)
		msgs.append(
			"WARNING: Costes '%s': retorno_dgp_min=%s fuera de [0,1], clampado a %s"
			% [id_c, min_v, min_clamp]
		)
	if not is_equal_approx(max_clamp, max_v):
		costes.set(&"retorno_dgp_max", max_clamp)
		msgs.append(
			"WARNING: Costes '%s': retorno_dgp_max=%s fuera de [0,1], clampado a %s"
			% [id_c, max_v, max_clamp]
		)
	# Invariante retorno_dgp_min <= retorno_dgp_max (Tuning Knobs / restricciones GDD).
	if min_clamp > max_clamp:
		costes.set(&"retorno_dgp_min", max_clamp)
		msgs.append(
			"WARNING: Costes '%s': retorno_dgp_min (%s) > retorno_dgp_max (%s), min ajustado a %s"
			% [id_c, min_clamp, max_clamp, max_clamp]
		)


## Servicio inoperable (Edge Cases / AC-D20d): cada `id` de `Escenario.servicios_activos` debe tener al menos
## un `TipoPuesto` con ese `servicio`. Si no, WARNING nombrando servicio y escenario. OJO tipos: `servicio`
## de TipoPuesto es String; `servicios_activos` es Array[StringName] → se compara `String(serv) == puesto.servicio`.
func _validar_servicios(msgs: Array[String]) -> void:
	var puestos: Array = obtener_todos(TIPO_TIPO_PUESTO)
	for esc: Resource in obtener_todos(TIPO_ESCENARIO):
		var servicios: Array = esc.get(&"servicios_activos")
		if servicios == null:
			continue
		var id_esc: StringName = esc.get(&"id")
		for serv: StringName in servicios:
			if not _hay_puesto_con_servicio(puestos, String(serv)):
				msgs.append(
					"WARNING: servicio inoperable '%s' en Escenario '%s': ningún TipoPuesto lo atiende"
					% [serv, id_esc]
				)


## True si algún `TipoPuesto` de `puestos` tiene `servicio == servicio_buscado` (String vs String).
func _hay_puesto_con_servicio(puestos: Array, servicio_buscado: String) -> bool:
	for puesto: Resource in puestos:
		if String(puesto.get(&"servicio")) == servicio_buscado:
			return true
	return false


## Invariante de solvencia R5 (Edge Cases / AC-D12/D13/D20d). SOLO se evalúa si `demanda_max_odac > 0` (la
## fórmula de demanda la posee Demanda; sin estimación no se comprueba). Para cada Escenario:
## `capacidad = capacidad_max_odac() × (MINUTOS_OPERATIVOS / duracion_media_odac())`; si
## `capacidad < demanda_max_odac` → WARNING de diseño nombrando el escenario, SIN abortar la carga.
func _validar_r5(msgs: Array[String], demanda_max_odac: int) -> void:
	if demanda_max_odac <= 0:
		return
	var dur_media: float = _duracion_media_odac()
	if dur_media <= 0.0:
		return  # sin denuncias cargadas no hay invariante que comprobar (evita división por cero)
	var tope_odac: int = _capacidad_max_odac()
	for esc: Resource in obtener_todos(TIPO_ESCENARIO):
		var capacidad: float = float(tope_odac) * (float(MINUTOS_OPERATIVOS) / dur_media)
		if capacidad < float(demanda_max_odac):
			msgs.append(
				"WARNING: Escenario '%s' viola R5: capacidad_max_ODAC≈%.1f/día < demanda estimada %d/día"
				% [esc.get(&"id"), capacidad, demanda_max_odac]
			)


## Capacidad R5 (nº de puestos): Σ de `Escenario.tope_construible` de los `TipoPuesto` cuyo `servicio` es
## ODAC. Se toma del PRIMER Escenario cargado (el MVP tiene uno). Helper de R5.
func _capacidad_max_odac() -> int:
	var puestos_odac: Array[StringName] = []
	for puesto: Resource in obtener_todos(TIPO_TIPO_PUESTO):
		if String(puesto.get(&"servicio")) == SERVICIO_ODAC:
			puestos_odac.append(puesto.get(&"id"))
	var total: int = 0
	for esc: Resource in obtener_todos(TIPO_ESCENARIO):
		var topes: Dictionary = esc.get(&"tope_construible")
		if topes == null:
			continue
		for id_puesto: StringName in puestos_odac:
			total += int(topes.get(id_puesto, 0))
		break  # MVP: un único Escenario
	return total


## Duración media (min) de las DenunciaODAC cargadas — media SIMPLE de sus `duracion_min`. Es una aproximación
## para el sanity-check R5; la fórmula fina (media PONDERADA por llegadas) la posee Demanda (GDD F3/F8). 0 si
## no hay denuncias.
func _duracion_media_odac() -> float:
	var denuncias: Array = obtener_todos(TIPO_DENUNCIA_ODAC)
	if denuncias.is_empty():
		return 0.0
	var suma: int = 0
	for denuncia: Resource in denuncias:
		suma += int(denuncia.get(&"duracion_min"))
	return float(suma) / float(denuncias.size())


## Devuelve un Dictionary-set `{ id: true }` con todos los `id` de un tipo (para pertenencia O(1)).
func _ids_de_tipo(tipo: StringName) -> Dictionary:
	var conjunto: Dictionary = {}
	var por_id: Dictionary = _por_tipo.get(tipo, {})
	for id: StringName in por_id.keys():
		conjunto[id] = true
	return conjunto


## Devuelve un Dictionary-set `{ id: true }` con la UNIÓN de los `id` de varios tipos.
func _ids_de_tipos(tipos: Array[StringName]) -> Dictionary:
	var conjunto: Dictionary = {}
	for tipo: StringName in tipos:
		var por_id: Dictionary = _por_tipo.get(tipo, {})
		for id: StringName in por_id.keys():
			conjunto[id] = true
	return conjunto
