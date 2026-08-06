# build_config_impresora.gd — herramienta DEV (patrón build_config_documentacion.gd): materializa el
# `.tres` de ConfigImpresora con los valores del GDD impresora-documentos-tramite.md (§Tuning Knobs,
# aprobados por el usuario 2026-08-01). NUNCA escribir el `.tres` a mano (regla del proyecto). Uso:
#   godot --headless --path <repo> --script res://tools/build_config_impresora.gd
# Exit 0 si guarda bien; 1 si falla. NO es código runtime (vive en tools/).
extends SceneTree

const RUTA_DESTINO := "res://datos/config/impresora.tres"
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://datos/config")
	# Los defaults de la clase YA SON los valores del GDD (aviso 5 min, recogida 1 min, 0,375
	# celdas/min) -> instancia limpia, igual que build_config_documentacion.
	var config: Resource = ConfigImpresoraScript.new()
	var error: Error = ResourceSaver.save(config, RUTA_DESTINO)
	if error != OK:
		push_error("build_config_impresora: fallo al guardar '%s' (error %d)" % [RUTA_DESTINO, error])
		quit(1)
		return
	print("build_config_impresora: OK -> %s" % RUTA_DESTINO)
	quit(0)
