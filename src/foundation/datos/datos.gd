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
## NO valida (referencias colgantes, ids duplicados, clamp de rangos, R5) — eso es la Story 003
## (`validar()`). NO muta nada. NO llama a otros sistemas por nombre (regla de capas).
##
## Story: production/epics/datos/story-002-autoload-carga-lookup.md
## TR-data-001 (catálogo desde fuente externa) · TR-data-002 (def read-only) · TR-data-004 (lookup por id)
## ADR-0003 (formato del catálogo .tres) · control-manifest §Foundation

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

## Índice del catálogo: `{ &"TramiteDoc": { &"dni": <Resource>, ... }, &"DenunciaODAC": {...}, ... }`.
## Clave externa = tipo (StringName); clave interna = `id` de la definición (StringName); valor = la
## definición cargada (misma referencia siempre → fuente única, R1/TR-data-004). Se llena en `_ready`.
var _por_tipo: Dictionary = {}


## Carga e indexa TODO el catálogo al arrancar. `Datos` es el 3º autoload (tras RNGService): al terminar
## este `_ready`, cualquier sistema posterior puede resolver definiciones por `id`. La validación de
## integridad se añade en la Story 003; aquí solo se carga e indexa.
func _ready() -> void:
	_cargar_catalogo()


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


# ── Carga (privado) ──────────────────────────────────────────────────────────────────────
## Recorre las carpetas del catálogo, carga cada `.tres` con `load()` y lo indexa por tipo+id.
func _cargar_catalogo() -> void:
	_por_tipo.clear()
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
	# Nota: la detección de id DUPLICADO es responsabilidad de la validación (Story 003); aquí un
	# duplicado simplemente sobrescribe. No es el caso del catálogo MVP (ids únicos por tipo).
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
