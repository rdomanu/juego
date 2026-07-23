extends Node
## SaveManager — orquestador de guardado/carga de la partida (autoload "SaveManager", registro en Story 007).
##
## VA SIN `class_name` a propósito: el autoload se registrará como `SaveManager` y un `class_name SaveManager`
## homónimo colisionaría con el nombre global del singleton (mismo footgun que `event_bus.gd`/`rng_service.gd`/
## `tiempo.gd`). El helper `SerialUtil` (Story 001) SÍ lleva `class_name` porque no es autoload.
##
## RECOLECCIÓN (Story 002): recorre el grupo genérico "Persist", pide a cada nodo su `save() -> Dictionary` y
## ensambla un dict raíz `{"version": N, <node.name>: <save()>, ...}`. NO conoce ningún sistema por nombre en
## código (respeta las capas — ADR-0001): solo lee el `name` del nodo del grupo como clave del sub-dict.
##
## ESCRITURA SEGURA (Story 003): serializa con `JSON.stringify`, escribe a un `.tmp` y renombra al final para
## no corromper el save previo si algo falla a mitad. `user://` obligatorio (`res://` es solo-lectura al exportar).
##
## LECTURA + VERSIÓN (Story 004): `cargar_partida` lee el archivo, parsea el JSON de forma segura, valida que es
## un `Dictionary` con `"version"` y lo pasa por el hook `_migrar` (identidad para la versión actual; rechaza una
## versión FUTURA que no sabe leer). Un save corrupto/inválido → `false` + log, NUNCA crashea (seguro por diseño).
##
## DISTRIBUCIÓN TOLERANTE (Story 005): reparte el dict migrado a los nodos del grupo "Persist" — por `node.name`
## busca su sub-dict y llama a `load_state`. Si falta la entrada de un nodo, ese nodo mantiene defaults + aviso y
## los demás cargan igual (un save nunca se invalida en bloque). El manager NO re-dispara eventos: "cargar sitúa,
## no reproduce" lo garantizan los propios sistemas en su `load_state`.
##
## Story: production/epics/save-manager/story-002-recoleccion-persist.md
##        production/epics/save-manager/story-003-escritura-segura.md
##        production/epics/save-manager/story-004-lectura-parseo-version.md
##        production/epics/save-manager/story-005-distribucion-tolerante.md · ADR-0002 · TR-save-001 · TR-data-006

## Versión del FORMATO del save (no de un sistema). Sube cuando el formato cambie de forma incompatible;
## el rechazo de versiones mayores y la migración son la Story 004.
const VERSION_ACTUAL: int = 1


# ── Recolección (Story 002) ─────────────────────────────────────────────────────────────────
## Método público: saca la lista del árbol (grupo "Persist") y delega en el método interno testeable.
func _recolectar() -> Dictionary:
	return _recolectar_de(get_tree().get_nodes_in_group("Persist"))


## Método interno TESTEABLE (recibe la lista por parámetro → sin árbol de escena ni autoload).
## Ensambla el dict raíz: `{"version": VERSION_ACTUAL}` + una entrada por nodo (clave `node.name` → `save()`).
##
## `has_method("save")` defensivo: un nodo que se una al grupo "Persist" sin implementar el contrato se IGNORA
## en vez de petar (red de seguridad; NO sustituye la disciplina de que todo nodo Persist DEBE tener `save()`).
## Grupo vacío → devuelve exactamente `{"version": VERSION_ACTUAL}` (sin entradas espurias).
func _recolectar_de(nodos: Array) -> Dictionary:
	var raiz: Dictionary = {"version": VERSION_ACTUAL}
	for n in nodos:
		if n.has_method("save"):
			raiz[n.name] = n.save()
		# else: nodo en el grupo sin contrato save() -> se ignora (defensivo).
	return raiz


# ── Escritura segura (Story 003) ────────────────────────────────────────────────────────────
## Guarda la partida en `ruta` (por defecto `user://savegame.save`) mediante temp+rename para no corromper
## el save previo. El parámetro `ruta` deja la puerta abierta a slots futuros sin cambiar la API.
##
## Devuelve `true` si el guardado se completó; `false` (con `push_error`) ante cualquier fallo de I/O, SIN
## crashear, SIN dejar un `.tmp` colgando y SIN tocar el save final si algo falló antes del rename.
##
## Flujo: stringify(_recolectar) → escribir al `.tmp` (comprobando el bool de store_string, 4.4+) → cerrar →
## renombrar `.tmp`→final. El archivo FINAL solo se toca en el rename, y solo tras un `.tmp` escrito con éxito.
func guardar_partida(ruta := "user://savegame.save") -> bool:
	var texto: String = JSON.stringify(_recolectar())
	var ruta_tmp: String = ruta + ".tmp"

	# 1) Abrir el temporal. `FileAccess.open` devuelve null ante ruta inválida/no escribible (no excepción).
	var f: FileAccess = FileAccess.open(ruta_tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager.guardar_partida: no se pudo abrir '%s' (error %d)" % [ruta_tmp, FileAccess.get_open_error()])
		return false

	# 2) Escribir. `store_string` devuelve bool desde 4.4 → comprobarlo NO es opcional (regla del manifest).
	var ok: bool = f.store_string(texto)
	f.close()
	if not ok:
		push_error("SaveManager.guardar_partida: store_string falló al escribir '%s' (disco lleno/permisos)" % ruta_tmp)
		_borrar_si_existe(ruta_tmp)   # no dejar un .tmp corrupto colgando.
		return false

	# 3) Renombrar temp→final. En Windows `rename_absolute` NO sobrescribe un destino existente → borrarlo antes.
	#    El save final solo se toca AQUÍ y solo tras un .tmp válido; cualquier fallo previo lo deja intacto (AC-ES04).
	if FileAccess.file_exists(ruta):
		_borrar_si_existe(ruta)
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(ruta_tmp), ProjectSettings.globalize_path(ruta))
	if err != OK:
		push_error("SaveManager.guardar_partida: rename '%s'->'%s' falló (error %d)" % [ruta_tmp, ruta, err])
		_borrar_si_existe(ruta_tmp)   # no dejar el .tmp colgando; el final ya se borró arriba, pero el rename no lo pisó.
		return false

	return true


# ── Lectura + parseo + versión (Story 004) ──────────────────────────────────────────────────
## Carga la partida desde `ruta` (por defecto `user://savegame.save`): lee el archivo, parsea el JSON de forma
## SEGURA (JSON son datos, nunca ejecuta código — a diferencia de un `.tres` manipulado), valida que es un
## `Dictionary` con `"version"`, lo pasa por el hook de migración `_migrar` y —si todo va bien— lo DISTRIBUYE a
## los nodos del grupo "Persist" (Story 005). Devuelve `true` solo si la carga se completó.
##
## Un save inexistente / corrupto / de versión futura NO se carga y NO crashea: se avisa (`push_warning` para lo
## esperable —falta el archivo—, `push_error` para lo anómalo —parseo fallido, sin versión, versión futura—) y se
## devuelve `false`. El parámetro `ruta` deja la puerta abierta a slots futuros sin cambiar la API.
##
## Flujo: existe? → abrir → leer → `JSON.parse_string` (puede ser null) → typeof == Dictionary → tiene "version"? →
## `_migrar` (identidad/rechazo) → `_distribuir` → true. Los int64 del RNG (semilla/estado) llegan como String y NO
## se tocan aquí: se pasan crudos dentro de su sub-dict a `RNGService.load_state`, que hace `int(str(...))`.
func cargar_partida(ruta := "user://savegame.save") -> bool:
	# 1) ¿Existe el archivo? Ausencia = caso esperable (partida nueva, slot vacío) → warning, no error.
	if not FileAccess.file_exists(ruta):
		push_warning("SaveManager.cargar_partida: no existe '%s' -> no se carga" % ruta)
		return false

	# 2) Abrir en lectura. `FileAccess.open` devuelve null si no es legible (no lanza) → comprobar.
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("SaveManager.cargar_partida: no se pudo abrir '%s' (error %d)" % [ruta, FileAccess.get_open_error()])
		return false

	# 3) Leer todo el texto y cerrar.
	var texto: String = f.get_as_text()
	f.close()

	# 4) Parsear el JSON. `JSON.parse_string` devuelve null ante texto inválido (NO lanza en 4.x). SEGURO por diseño:
	#    JSON son datos, jamás ejecuta código (a diferencia de `load()` de un `.tres` manipulado).
	var parseado: Variant = JSON.parse_string(texto)

	# 5) El resultado debe ser un objeto JSON (Dictionary). null / número / array → save inválido.
	if typeof(parseado) != TYPE_DICTIONARY:
		push_error("SaveManager.cargar_partida: '%s' no es un objeto JSON valido -> no se carga" % ruta)
		return false
	var dict: Dictionary = parseado

	# 6) Un save reconocible SIEMPRE trae "version". Sin ella no sabemos qué formato es → rechazo.
	if not dict.has("version"):
		push_error("SaveManager.cargar_partida: '%s' no tiene 'version' -> no se carga" % ruta)
		return false

	# 7) Hook de migración. Un dict VACÍO tras `_migrar` es el marcador de rechazo (versión futura no legible).
	var version: int = int(dict["version"])
	var migrado: Dictionary = _migrar(dict, version)
	if migrado.is_empty():
		return false   # `_migrar` ya avisó (versión mayor que la actual -> RECHAZADO).

	# 8) Distribución tolerante a los nodos del grupo "Persist" (Story 005).
	_distribuir(migrado)
	return true


## Hook de migración del formato del save. En el MVP:
## - `version == VERSION_ACTUAL` → identidad (devuelve el dict tal cual).
## - `version > VERSION_ACTUAL`  → RECHAZO: no sabemos leer un formato del futuro → devuelve `{}` (marcador de
##   rechazo que el caller traduce a `false`) tras avisar. DECISIÓN APROBADA 3.
## - `version < VERSION_ACTUAL`  → aquí irán las migraciones hacia adelante; ninguna definida aún (identidad).
##
## El marcador de rechazo `{}` es inequívoco: un save legítimo SIEMPRE trae al menos `"version"`, así que su dict
## migrado nunca está vacío; solo el rechazo produce un `{}`.
func _migrar(dict: Dictionary, version: int) -> Dictionary:
	if version == VERSION_ACTUAL:
		return dict                     # identidad (MVP: sin migraciones)
	if version > VERSION_ACTUAL:
		push_error("SaveManager: save version %d > actual %d -> RECHAZADO (sin migracion hacia adelante)" % [version, VERSION_ACTUAL])
		return {}                       # marcador de rechazo -> el caller devuelve false
	# version < VERSION_ACTUAL: futuras migraciones hacia adelante (identidad por ahora; ninguna definida).
	return dict


# ── Distribución tolerante (Story 005) ──────────────────────────────────────────────────────
## Método público (del árbol): saca los nodos del grupo "Persist" y delega en el interno testeable.
## Simétrico a `_recolectar` (Story 002): la RECOLECCIÓN lee `node.name`→`save()`; la DISTRIBUCIÓN busca
## `node.name` en el dict y le pasa el sub-dict a `load_state`. El manager NO conoce ningún sistema por nombre.
func _distribuir(dict: Dictionary) -> void:
	_distribuir_a(get_tree().get_nodes_in_group("Persist"), dict)


## Método interno TESTEABLE (recibe la lista de nodos por parámetro → sin árbol de escena ni autoload).
## Por cada nodo del grupo: si tiene `load_state` y el dict trae su entrada (`node.name`), le pasa SU sub-dict.
##
## TOLERANTE (TR-data-006): si un nodo NO tiene entrada en el save (save viejo / sistema nuevo), mantiene sus
## defaults + `push_warning`, PERO los demás cargan igual — un save NUNCA se invalida en bloque por una entrada
## faltante. `has_method("load_state")` defensivo (AC-DT03): un nodo del grupo sin el contrato se IGNORA sin petar.
##
## El manager NO re-dispara eventos (AC-DT04): no emite señales, no llama a `disparar_ordenado`, no fuerza ticks.
## "Cargar sitúa, no reproduce" lo garantizan los SISTEMAS en su propio `load_state` (Tiempo fuerza Pausa +
## `sincronizar_umbrales` sin emitir; RNGService solo restaura estado). El manager es fontanería pura de reparto.
func _distribuir_a(nodos: Array, dict: Dictionary) -> void:
	for n in nodos:
		if not n.has_method("load_state"):
			continue   # defensivo (AC-DT03): nodo del grupo sin contrato load_state -> se ignora.
		if dict.has(n.name):
			n.load_state(dict[n.name])   # AC-DT01: SU sub-dict por nombre.
		else:
			# AC-DT02: sin entrada -> defaults + aviso; NUNCA invalida la carga de los demás.
			push_warning("SaveManager: no hay estado guardado para '%s' -> mantiene defaults" % n.name)


# ── Privados ────────────────────────────────────────────────────────────────────────────────
## Borra `ruta` si existe (usa la ruta absoluta del SO globalizada). Silencioso: si no existe, no hace nada.
func _borrar_si_existe(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
