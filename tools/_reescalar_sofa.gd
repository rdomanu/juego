extends "res://tools/render_mobiliario.gd"
## _reescalar_sofa — decisión del usuario 2026-08-03: *"mira el tamaño tan grande que tiene el
## sofá con respecto a los npcs — hay que hacerlo más pequeño; si ves que 3 celdas son muchas,
## lo puedes reducir a 2"*. El sofá de 3 plazas (asiento_sofa3) pasa de lado largo 3,00 celdas a
## **2,00 celdas** (escala uniforme: al encoger de largo baja también de alto, que es lo pedido).
##
## Mismo patrón que `_reescalar_dispensador.gd` (ver su cabecera): hereda TODO el pipeline del
## padre, calibra la cámara con las MISMAS recetas (encuadre bit-idéntico) y guarda SOLO la pieza
## objetivo con su multiplicador nuevo.
##
## El padre usa `MULTIPLICADOR_SOFA3 = 3.00 / 1.525` (el sofá mide 1,525 celdas al natural).
## Para 2 celdas: `2.00 / 1.525`. ⚠️ Cuando este cambio se consolide, actualizar TAMBIÉN
## `MULTIPLICADOR_SOFA3` en el padre para que una pasada completa no lo deshaga.
const MULTIPLICADOR_SOFA2: float = 2.00 / 1.525


func _ejecutar(todas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var recetas: Array[Dictionary] = _recetas()

	var anclas: Dictionary = {}
	var radio_max := 0.0
	for receta: Dictionary in recetas:
		var ancla: Vector3 = _ancla_de(receta, todas)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(receta, todas, ancla))
	var tam_camara: float = radio_max * 2.0 * MARGEN

	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)
	_colocar_camara(tam_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	var crudos: Dictionary = {}

	_montar_receta(grupo, _receta_por_id(recetas, ID_MOSTRADOR), todas, anclas[ID_MOSTRADOR])
	grupo.rotation = Vector3.ZERO
	crudos[ID_MOSTRADOR] = {0: await _renderizar_bruto()}

	var receta_sofa: Dictionary = _receta_por_id(recetas, ID_ASIENTO_SOFA3)
	_montar_receta(grupo, receta_sofa, todas, anclas[ID_ASIENTO_SOFA3])
	var por_rotacion: Dictionary = {}
	for rot: int in ROTACIONES:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		por_rotacion[rot] = await _renderizar_bruto()
		print("[REESCALAR_SOFA] %s @ %d°: bruto listo" % [ID_ASIENTO_SOFA3, rot])
	crudos[ID_ASIENTO_SOFA3] = por_rotacion

	var referencia: Dictionary = crudos[ID_MOSTRADOR][0]
	var ancho_bruto: int = (referencia["imagen"] as Image).get_width()
	var ancho_objetivo: float = Proyeccion.ANCHO_ROMBO * ESCALA_OBJETIVO_MOSTRADOR
	var escala_final: float = ancho_objetivo / float(maxi(ancho_bruto, 1))
	print("[REESCALAR_SOFA] calibración: factor=%.4f" % escala_final)

	_guardar_receta_a_escala(crudos, ID_ASIENTO_SOFA3, ID_ASIENTO_SOFA3, escala_final * MULTIPLICADOR_SOFA2)

	print("[REESCALAR_SOFA] hecho.")
	get_tree().quit()


func _receta_por_id(recetas: Array[Dictionary], id_salida: String) -> Dictionary:
	for receta: Dictionary in recetas:
		if receta["id_salida"] == id_salida:
			return receta
	push_error("REESCALAR_SOFA: receta no encontrada: %s" % id_salida)
	return {}
