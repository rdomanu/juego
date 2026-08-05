extends "res://tools/render_mobiliario.gd"
## _render_props_nuevos — DESECHABLE, fase de PROPUESTA (2026-08-05, v2).
##
## Renderiza los 7 modelos nuevos de `capturas/fuentes/props_poly/` (cafetera/vending/impresora/
## television/fuente_agua/taquilla/archivador — ver `mapeo-fuentes.md`), candidatos a sustituir a
## las comodidades "caja gris". Cada modelo es un `.glb` SUELTO, ajeno a `isometric_office.glb`, así
## que este script NO llama a `super._ready()` (que solo carga el pack de oficina) — arma su propia
## recolección por modelo, con SU PROPIA cámara (mismo pipeline bit-idéntico 30°/45° ortográfica que
## `render_mobiliario.gd`, MARGEN=1.15), igual que `tools/_render_puertas_escala_pared.gd`.
##
## ── v1 → v2: POR QUÉ CAMBIA EL CRITERIO DE ESCALA ────────────────────────────────────────────────
## v1 forzaba la HUELLA de cada pieza a llenar 1 celda entera (`ANCHO_ROMBO`=80px, la regla que usa
## `render_mobiliario.gd` para mobiliario que SÍ ocupa su celda de verdad: mostrador/estantería/
## sofá). Resultado, verificado en la hoja v1: piezas pequeñas (taquilla, cafetera) se inflaban
## hasta llenar la celda igual que un escritorio, se solapaban con sus vecinas y salían gigantes
## frente al muñeco — esa regla es para MOBILIARIO DE SALA, no para electrodomésticos de tamaño de
## comodidad (que en el juego real, ver `radio`/`papelera`/`dispensador_agua`, se renderizan a su
## tamaño NATURAL, sin forzar su huella).
##
## Además, la propia AABB en bruto de estos modelos resultó NO fiable ni para las piezas que
## `mapeo-fuentes.md` daba por buenas: `cafetera` mide 1,83 m de alto en su AABB pero la imagen es
## una cafetera de sobremesa normal — unidades rotas, igual que vending/fuente_agua.
##
## v2 calibra por ALTURA REAL frente al muñeco de referencia del proyecto (`girl` 44 px ~ 1,70 m,
## ver `tools/_hoja_estanterias.gd`): cada pieza declara la altura REAL que debería tener en el
## juego (criterio del usuario, NO la AABB del modelo) y el factor de escala sale de medir cuántos
## píxeles ocupa su render en bruto y forzarlo a `objetivo_m * (44/1,70)` px. Esto bypassa el
## problema de las unidades del `.glb` por completo: no importa si el modelo mide "1,83" o "183" en
## sus propias unidades, solo importa cuántos PÍXELES ocupa su silueta ya renderizada.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) — fase de PROPUESTA.

const CARPETA_ORIGEN := "res://capturas/fuentes/props_poly/"
const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/e2e2376e-13c2-4add-ad50-5abb00a96123/scratchpad/"

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## El muñeco de referencia de TODA la hoja de propuesta: `girl` 44px ~ 1,70 m real (convención del
## proyecto, ver `tools/_hoja_estanterias.gd`). De aquí sale el ÚNICO px/metro de esta pasada.
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M

## Un modelo por fila: `id` (nombre de salida) y `altura_objetivo_m` — la altura REAL que debería
## tener la pieza en el juego (decisión del usuario, NO la AABB del `.glb`: ver la cabecera).
const MODELOS: Array[Dictionary] = [
	{"id": "cafetera", "altura_objetivo_m": 0.45},     # sobremesa
	{"id": "vending", "altura_objetivo_m": 2.00},       # máquina expendedora alta
	{"id": "impresora", "altura_objetivo_m": 0.50},     # sobremesa
	{"id": "television", "altura_objetivo_m": 0.60},    # aparato, no mueble
	{"id": "fuente_agua", "altura_objetivo_m": 1.20},   # dispensador de pie bajo
	{"id": "taquilla", "altura_objetivo_m": 1.80},      # taquilla de pie
	{"id": "archivador", "altura_objetivo_m": 1.30},    # archivador de pie
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render -- mismo criterio que el padre.

	var todas: Dictionary = {}
	for modelo: Dictionary in MODELOS:
		_cargar(contenedor, modelo, todas)

	_ejecutar(todas)


## Carga UN `.glb` suelto y vuelca sus `MeshInstance3D` en `todas` con el prefijo `<id>__` (mismo
## formato que `_recopilar_instancias` del padre, para reutilizar `_ancla_de`/`_radio_de`/
## `_montar_receta` sin tocarlos). v2 YA NO pre-escala el nodo raíz (la corrección de unidades de
## v1 queda sustituida por la calibración por altura, post-render -- ver la cabecera).
func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> void:
	var id: String = modelo["id"]
	var ruta: String = "%s%s.glb" % [CARPETA_ORIGEN, id]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[PROPS NUEVOS] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var total := 0
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		total += 1
	print("[PROPS NUEVOS] %s: %d MeshInstance3D cargadas" % [id, total])


func _nombres_de(todas: Dictionary, id: String) -> PackedStringArray:
	var prefijo: String = id + "__"
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _ejecutar(todas: Dictionary) -> void:
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

	print("[PROPS NUEVOS] px/metro de esta pasada = %.4f (muñeco %.0fpx ~ %.2fm)" % [
		PX_POR_METRO, ALTO_MUNECO_PX, ALTO_MUNECO_M
	])

	for modelo: Dictionary in MODELOS:
		var id: String = modelo["id"]
		var altura_objetivo_m: float = modelo["altura_objetivo_m"]
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[PROPS NUEVOS] %s: receta vacía -- se salta" % id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° -- define la escala de ESTA pieza por ALTURA REAL frente al muñeco (ver la
		# cabecera: bypassa las unidades del .glb, que no son fiables).
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var alto_bruto_px: int = _medir_alto(imagen_0)
		var objetivo_px: float = altura_objetivo_m * PX_POR_METRO
		var escala_pieza: float = objetivo_px / float(maxi(alto_bruto_px, 1))
		print("[PROPS NUEVOS] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm->%.1fpx -> factor=%.4f" % [
			id, radio, imagen_0.get_width(), imagen_0.get_height(), alto_bruto_px, altura_objetivo_m, objetivo_px, escala_pieza
		])

		# 2) Las 4 rotaciones, MISMO factor.
		var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
		for rot: int in [90, 180, 270]:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			escalados.append(_escalar(bruto, escala_pieza))

		for i: int in ROTACIONES.size():
			var img: Image = escalados[i]["imagen"]
			print("[PROPS NUEVOS]   rot %d°: %dx%dpx (ratio alto/muñeco44px = %.2f)" % [
				ROTACIONES[i], img.get_width(), img.get_height(), float(img.get_height()) / ALTO_MUNECO_PX
			])

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [SALIDA_SCRATCH, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ruta)
			if err != OK:
				push_error("[PROPS NUEVOS] save_png '%s' fallo (error %d)" % [ruta, err])
		print("[PROPS NUEVOS] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, SALIDA_SCRATCH, id])

	print("[PROPS NUEVOS] hecho.")
	get_tree().quit()


## El ALTO en píxeles de la silueta opaca de una imagen en bruto: fila opaca más alta a fila opaca
## más baja (reutiliza el escaneo de `AnclajeSprite`, mismo umbral de alfa).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[PROPS NUEVOS] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1
