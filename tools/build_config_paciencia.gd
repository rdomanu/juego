# build_config_paciencia.gd — herramienta DEV (patrón build_config_flujo.gd): materializa el `.tres`
# de ConfigPaciencia con los valores semilla del GDD patience-satisfaction (§Tuning Knobs). NUNCA
# escribir el `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_paciencia.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/paciencia.tres"
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores semilla del GDD -> instancia limpia.
	var config: Resource = ConfigPacienciaScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_paciencia: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_paciencia: OK -> %s" % RUTA_DESTINO)
	quit(0)
