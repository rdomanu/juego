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
## Story: production/epics/save-manager/story-002-recoleccion-persist.md
##        production/epics/save-manager/story-003-escritura-segura.md · ADR-0002 · TR-save-001

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


# ── Privados ────────────────────────────────────────────────────────────────────────────────
## Borra `ruta` si existe (usa la ruta absoluta del SO globalizada). Silencioso: si no existe, no hace nada.
func _borrar_si_existe(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
