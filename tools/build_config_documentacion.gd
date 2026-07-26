# build_config_documentacion.gd — herramienta DEV (patrón build_config_paciencia.gd): materializa el
# `.tres` de ConfigDocumentacion con los valores del GDD documentation.md (§Tuning Knobs). NUNCA
# escribir el `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_documentacion.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/documentacion.tres"
const ConfigDocumentacionScript := preload("res://src/feature/documentacion/config_documentacion.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores del GDD (los que fija la División) -> instancia limpia.
	var config: Resource = ConfigDocumentacionScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_documentacion: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_documentacion: OK -> %s" % RUTA_DESTINO)
	quit(0)
