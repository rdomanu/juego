extends SceneTree
## DESECHABLE — diagnóstico de AABB en bruto de los 7 modelos nuevos de `capturas/fuentes/props_poly/`
## (cafetera/vending/impresora/television/fuente_agua/taquilla/archivador), ANTES de decidir factores
## de escala para el render de propuesta. Headless (no dibuja nada, solo instancia y mide).
##
## `global_transform` exige `is_inside_tree()` — se añaden TODOS los modelos al árbol y se espera UN
## `process_frame` antes de medir (en `_initialize` no basta con `add_child`: la notificación de
## entrada al árbol no está resuelta hasta el primer frame).

const CARPETA := "res://capturas/fuentes/props_poly/"
const MODELOS := ["cafetera", "vending", "impresora", "television", "fuente_agua", "taquilla", "archivador"]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var root: Window = get_root()
	var raices: Dictionary = {}
	for nombre: String in MODELOS:
		var ruta: String = CARPETA + nombre + ".glb"
		var escena: PackedScene = load(ruta)
		if escena == null:
			print("[DIAG] %s: NO SE PUDO CARGAR" % nombre)
			continue
		var raiz: Node3D = escena.instantiate()
		root.add_child(raiz)
		raices[nombre] = raiz

	await process_frame

	for nombre: String in MODELOS:
		if not raices.has(nombre):
			continue
		var raiz: Node3D = raices[nombre]
		var caja := AABB()
		var primera := true
		var total_mallas := 0
		for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := hijo as MeshInstance3D
			if mi.mesh == null:
				continue
			var c: AABB = mi.global_transform * mi.mesh.get_aabb()
			caja = c if primera else caja.merge(c)
			primera = false
			total_mallas += 1
		if primera:
			print("[DIAG] %s: SIN MeshInstance3D" % nombre)
		else:
			print("[DIAG] %s: %d mallas, AABB pos=%s size=%s -> alto(Y)=%.4f  ancho(X)=%.4f  fondo(Z)=%.4f" % [
				nombre, total_mallas, caja.position, caja.size, caja.size.y, caja.size.x, caja.size.z
			])
		root.remove_child(raiz)
		raiz.free()

	quit()
