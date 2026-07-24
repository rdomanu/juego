# build_config_construccion.gd — herramienta DEV (patrón build_config_personal.gd): materializa el
# `.tres` de ConfigConstruccion con los valores semilla del GDD construction-layout (§Tuning Knobs).
# NUNCA escribir el `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_construccion.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/construccion.tres"
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores semilla del GDD -> instancia limpia.
	var config: Resource = ConfigConstruccionScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_construccion: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_construccion: OK -> %s" % RUTA_DESTINO)
	quit(0)
