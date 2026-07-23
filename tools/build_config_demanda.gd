# build_config_demanda.gd — herramienta DEV (patrón build_config_economia.gd): materializa el `.tres` de
# ConfigDemanda con los valores semilla del GDD demand-generation (§Tuning Knobs / F1-F3). NUNCA escribir
# el `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_demanda.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/demanda.tres"
const ConfigDemandaScript := preload("res://src/core/demanda/config_demanda.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores semilla del GDD (el perfil ODAC uniforme se rellena
	# en su _init) -> instancia limpia.
	var config: Resource = ConfigDemandaScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_demanda: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_demanda: OK -> %s" % RUTA_DESTINO)
	quit(0)
