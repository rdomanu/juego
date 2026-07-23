# Smoke standalone (Story 007 — epic save-manager) · AC-SM02/SM03.
#
# Arranca el juego REAL en headless con los 5 autoloads (EventBus → RNGService → Datos → Tiempo → SaveManager)
# y ejerce UN guardar_partida() + UN cargar_partida() reales sobre el singleton SaveManager, sobre user://.
# Imprime marcadores inequívocos (SMOKE_...) para que el runner del smoke los detecte, y borra el .save al final
# (no deja archivos). Sale con exit 0 si guardar Y cargar devuelven true; 1 en cualquier otro caso.
#
# Uso: godot --headless --path <repo> --script res://tests/smoke_save_manager.gd
# NO es un test de GdUnit (es un SceneTree standalone): valida el arranque + el ciclo con el AUTOLOAD real,
# algo que la suite (que usa instancias preload-adas para aislarse) no cubre por diseño.
extends SceneTree

const RUTA_SMOKE: String = "user://smoke_test.save"


func _initialize() -> void:
	# Esperar a que TODOS los _ready de los autoloads hayan corrido (se procesan en el primer frame del árbol).
	# process_frame se emite tras el primer procesado del árbol → los autoloads ya están listos.
	await process_frame

	var save_manager: Node = root.get_node_or_null("SaveManager")
	if save_manager == null:
		print("SMOKE_FAIL: el autoload SaveManager no está en /root (¿registro en project.godot?)")
		quit(1)
		return

	# AC-SM03: un guardar + un cargar reales con el singleton (grupo Persist real: RNGService + Tiempo).
	var guardado_ok: bool = save_manager.guardar_partida(RUTA_SMOKE)
	print("SMOKE_GUARDAR: %s" % ("true" if guardado_ok else "false"))

	var cargado_ok: bool = save_manager.cargar_partida(RUTA_SMOKE)
	print("SMOKE_CARGAR: %s" % ("true" if cargado_ok else "false"))

	# Limpieza: no dejar el .save (ni un .tmp por si acaso) del smoke en user://.
	_borrar(RUTA_SMOKE)
	_borrar(RUTA_SMOKE + ".tmp")

	if guardado_ok and cargado_ok:
		print("SMOKE_OK: arranque limpio + guardar/cargar true (singleton real)")
		quit(0)
	else:
		print("SMOKE_FAIL: guardar=%s cargar=%s" % [guardado_ok, cargado_ok])
		quit(1)


func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
