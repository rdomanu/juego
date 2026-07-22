extends SceneTree
## build_config_tiempo.gd — HERRAMIENTA DEV (no runtime): genera el `.tres` de config del reloj desde código.
##
## Instancia un `ConfigTiempo` con los valores DEFAULT del GDD (F1/F3) y lo guarda con `ResourceSaver.save()`
## en `res://datos/config/tiempo.tres`. Así se evita escribir el `.tres` a mano (uids/`ext_resource` frágiles —
## misma regla que `build_catalogo.gd` / ADR-0003). Este script vive en `tools/` (dev tooling), NUNCA se ejecuta
## en runtime del juego.
##
## Uso (headless, una vez / al cambiar los valores semilla):
##   godot --headless --path <repo> --script res://tools/build_config_tiempo.gd
##
## Comprueba el código de retorno de `ResourceSaver.save` y termina con exit code ≠0 si falla, para que el
## CI/usuario detecte una generación fallida.
##
## Story: production/epics/tiempo/story-002-escala-configurable.md · TR-time-001 · ADR-0001 / ADR-0002
## Fuente de los valores: `src/foundation/tiempo/config_tiempo.gd` (defaults @export) = GDD F1/F3.

const ConfigTiempoScript := preload("res://src/foundation/tiempo/config_tiempo.gd")

const RUTA_CONFIG := "res://datos/config/tiempo.tres"


func _init() -> void:
	print("build_config_tiempo: generando la config del reloj en '%s'..." % RUTA_CONFIG)
	_asegurar_carpeta()

	# ConfigTiempo con los defaults del @export (GDD F1/F3): escala 4.0, límites 420/900/1380, 4 jornadas/mes,
	# delta_max 0.5. NO se sobrescribe ningún campo → los defaults del esquema son la fuente única.
	var config: Resource = ConfigTiempoScript.new()

	var err: int = ResourceSaver.save(config, RUTA_CONFIG)
	if err != OK:
		push_error("build_config_tiempo: FALLO al guardar '%s' (error %d)." % [RUTA_CONFIG, err])
		quit(1)
		return

	print("  guardado: %s" % RUTA_CONFIG)
	print("build_config_tiempo: OK — config del reloj generada.")
	quit(0)


## Crea `res://datos/config/` si falta (DirAccess). Idempotente. No toca las carpetas del catálogo existente.
func _asegurar_carpeta() -> void:
	var base: DirAccess = DirAccess.open("res://")
	if base == null:
		push_error("build_config_tiempo: no se pudo abrir 'res://'.")
		quit(1)
		return
	base.make_dir_recursive("datos/config")
