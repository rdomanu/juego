extends "res://tools/render_mobiliario.gd"
## SONDA DESECHABLE (2026-08-09) — PLUMA LIMPIA para la barrera de seguridad.
##
## El modelo generado (barrera_seguridad.glb) trae la textura de franjas ROTA (parches que no
## siguen el eje — veredicto del usuario) y una cabina correcta. Esta sonda rendera SOLO la pluma,
## construida como caja 3D por segmentos rojo/blanco de MATERIAL PLANO (ley Summer: "rellenos
## planos tolerados"; la pieza definitiva puede regenerarse con Summer más adelante) con la MISMA
## cámara/luces del pipeline (patrón copiado de `_render_bancos_barrera.gd`) — así el sprite tiene
## el volumen e iluminación del resto del catálogo.
## Salida: capturas/fuentes/barrera_summer/renders/pluma_limpia_{0,90,180,270}.png

const SALIDA_PLUMA := "res://capturas/fuentes/barrera_summer/renders/"

## v2 (2026-08-09, "rehacer > parchear"): la BARRERA ENTERA en 3D — motor (base de piedra +
## cuerpo + tapa, colores muestreados del modelo generado: 82/135/144 gris) + pluma por
## segmentos. La cirugía 2D sobre el render del modelo dejaba mordiscos y muñones en las
## junturas; construida como grupo 3D las 4 rotaciones salen perfectas por construcción.
## Diseño 1 del usuario: caja ~1,9m con pluma montada a ~1,0m (en juego: caja 72px, pluma 34px).
const LARGO_M: float = 6.0
const SECCION_M: float = 0.14
const SEGMENTOS: int = 12
const ALTURA_PLUMA_M: float = 1.0

const ROJO := Color(0.784, 0.173, 0.157)
const BLANCO := Color(0.961, 0.961, 0.961)
const GRIS_CUERPO := Color(0.322, 0.322, 0.322)
const GRIS_TAPA := Color(0.529, 0.529, 0.522)
const GRIS_PIEDRA := Color(0.565, 0.545, 0.533)


func _caja(grupo: Node3D, tam: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tam
	mi.mesh = malla
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	grupo.add_child(mi)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA_PLUMA))

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

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# (v3: el motor 3D por cajas salía NEGRO con esta iluminación — descartado; la cabina de la
	# pieza final vuelve a ser la del MODELO generado, recortada en 2D. Aquí solo la pluma.)
	# ── PLUMA: segmentos alternos a ALTURA_PLUMA_M ──
	var paso: float = LARGO_M / float(SEGMENTOS)
	for i: int in SEGMENTOS:
		var caja := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(paso, SECCION_M, SECCION_M)
		caja.mesh = malla
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ROJO if i % 2 == 0 else BLANCO
		mat.roughness = 1.0
		caja.material_override = mat
		caja.position = Vector3(
			-LARGO_M * 0.5 + paso * (float(i) + 0.5), ALTURA_PLUMA_M, 0.0
		)
		grupo.add_child(caja)
	# tapa del extremo (gris, como la del modelo original)
	var tapa := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.height = 0.10
	cil.top_radius = SECCION_M * 0.62
	cil.bottom_radius = SECCION_M * 0.62
	tapa.mesh = cil
	var mat_tapa := StandardMaterial3D.new()
	mat_tapa.albedo_color = Color(0.63, 0.63, 0.65)
	mat_tapa.roughness = 1.0
	tapa.material_override = mat_tapa
	tapa.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	tapa.position = Vector3(LARGO_M * 0.5 + 0.05, ALTURA_PLUMA_M, 0.0)
	grupo.add_child(tapa)

	_colocar_camara(LARGO_M * 0.66)

	for rot: int in [0, 90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		var imagen: Image = bruto["imagen"]
		var ruta: String = "%spluma_limpia_%d.png" % [SALIDA_PLUMA, rot]
		imagen.save_png(ProjectSettings.globalize_path(ruta))
		print("[PLUMA] -> %s (%dx%d)" % [ruta, imagen.get_width(), imagen.get_height()])
	print("[PLUMA] hecho.")
	get_tree().quit()
