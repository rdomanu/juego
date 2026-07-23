# build_config_personal.gd — herramienta DEV (patrón build_config_demanda.gd): materializa el `.tres` de
# ConfigPersonal con los valores semilla del GDD staff-agents (§Tuning Knobs / F1-F5). NUNCA escribir el
# `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_personal.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/personal.tres"
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores semilla del GDD -> instancia limpia.
	var config: Resource = ConfigPersonalScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_personal: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_personal: OK -> %s" % RUTA_DESTINO)
	quit(0)
