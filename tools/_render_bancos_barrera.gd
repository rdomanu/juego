extends "res://tools/render_mobiliario.gd"
## _render_bancos_barrera — DESECHABLE. Render de evaluación (hoja de veredicto del usuario, NO
## integración) de 5 bancos de espera candidatos + 1 barrera de seguridad, cada uno ya importado
## dentro de `res://` en `capturas/fuentes/bancos_espera/` y `capturas/fuentes/barrera_summer/`.
##
## Mismo pipeline que `render_entorno_urbano.gd`/`_render_kaykit_poly.gd` (cámara/luces/recorte
## heredados de `render_mobiliario.gd`, ver su cabecera): calibración por ALTURA REAL declarada o
## por ANCHO objetivo en celdas, nunca por la AABB cruda del `.glb` — y SIEMPRE escala uniforme
## (X=Y), ley del proyecto, prohibida la deformación.
##
## Encargo (ver la tarea): los 5 bancos se calibran por ALTURA REAL 0,85 m (respaldo de banco
## público) × factor de presencia 1,25 — igual que `_render_kaykit_poly.gd`. La barrera se calibra
## por ANCHO objetivo = 6,0 celdas (480 px) a 0°, misma familia de escala que las carreteras de
## `render_entorno_urbano.gd` (el brazo cubre una calle de 6 celdas).
##
## Escribe SOLO en `capturas/fuentes/bancos_espera/renders/` y `capturas/fuentes/barrera_summer/
## renders/` — NUNCA en `assets/sprites/`, esto es solo evaluación.

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## Mismo ancla de conversión que el resto de pipelines 3D->sprite del proyecto: muñeco `girl` 44px
## ~ 1,70m real.
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
## Factor de presencia (`_render_kaykit_poly.gd`, `design/art/plan-escalado.md` §1): +25% sobre la
## escala métrica real.
const FACTOR_PRESENCIA: float = 1.25

const CARPETA_BANCOS := "res://capturas/fuentes/bancos_espera/"
const CARPETA_BARRERA := "res://capturas/fuentes/barrera_summer/"
const SALIDA_BANCOS := "res://capturas/fuentes/bancos_espera/renders/"
const SALIDA_BARRERA := "res://capturas/fuentes/barrera_summer/renders/"

## Los 5 bancos candidatos: por ALTURA REAL declarada 0,85 m (respaldo de banco público) × factor
## de presencia — se MIDE el ancho resultante a 0° y se reporta en celdas, sin forzarlo.
## RECETA v4 (2026-08-09, definitiva): la escala se ancla al SOFÁ DE 3 PLAZAS que ya existe en el
## juego (`asiento_sofa3`, 108x72 px) -- un banco de 3 plazas es su hermano y tiene que medir lo
## mismo. Es además la escala con la que el usuario aprobó el arte en la hoja de veredicto. Las dos
## cuentas "teóricas" anteriores (N rombos y (N+1) medios rombos) daban bancos 1,5-2,2x más grandes
## que ese hermano, y en el juego aplastaban a los muñecos.
## RECETA v3 (2026-08-09): la escala se corrige a la REGLA DEL PASO DE CELDA -- un mueble de N
## celdas EN FILA mide (N+1) medias celdas de ancho de rombo, porque dos celdas contiguas distan
## medio rombo (40px), no uno entero. Con la cuenta ingenua (N rombos) los bancos salian 1,5x
## demasiado grandes y aplastaban a los muñecos (visto in-game).
## RECETA v2 (2026-08-09, verificación de Fable sobre la 1ª pasada): calibrar por ALTURA (0,85 m)
## daba bancos de 0,36-0,45 celdas — el propio encargo (encargo-bancos-espera.md) pide huella de
## ANCHO 2-3 celdas con 1 plaza/celda, así que el ancho manda y el alto sale de la proporción
## natural (escala uniforme, ley del proyecto). Fuera `banco_desgastado_graveyard` y
## `banco_urbano_retro` (verificados a ojo en la pasada 1: sin textura / geometría revuelta).
## RECETA v5 (2026-08-10, veredicto del usuario sobre `hoja_bancos_escala.png`): **×0,75 sobre la
## v4**. La v4 ancló la familia al `asiento_sofa3` POR ANCHO (108 px) y la ALTURA se disparó: el
## banco de aeropuerto quedó en 101 px, o sea 2,24 veces el alto de un ciudadano de pie (45 px) y
## 30 px más que el propio sofá de 3 plazas con el mismo ancho. El usuario lo cazó a ojo ("los
## bancos están bastante grandes") y eligió la opción B de la hoja de tamaños: al 75 % el banco de
## aeropuerto cae a 76 px, casi clavado al sofá que él ya había aprobado.
## La escala se aplica AQUÍ y se re-renderiza desde el .glb -- NUNCA encogiendo el PNG, que
## emborrona el borde y tira por tierra el supermuestreo.
## RECETA v6 (2026-08-10, veredicto del usuario sobre `hoja_hilera_bancos.png`, opción B): el banco
## LLENA su huella de celdas ENTERAS, para que al encadenar varios NO queden huecos entre ellos
## ("me gusta más para hacer hileras"). Regla del proyecto fijada ese mismo día: la huella es
## siempre un número entero de celdas, aunque sobre sitio.
##
## Los números NO se ajustan a ojo: se mide el largo real de la base EN EL PLANO DEL SUELO (misma
## cuenta que `AnclajeSprite.semiejes_base` — el ancho en píxeles de PANTALLA está deformado por la
## proyección a 45° y no vale, lo cazó el usuario) y se escala para que dé celdas exactas:
##   medio/pro: medían 1,56 celdas con 1,0125 -> 2,00 celdas con 1,2981 (×1,282)
##   madera:    medía  1,01 celdas con 0,6750 -> 1,00 celdas con 0,6683 (×0,990)
const MODELOS_BANCOS: Array[Dictionary] = [
	{"id": "banco_espera_medio", "ruta": CARPETA_BANCOS + "banco_espera_medio.glb", "ancho_objetivo_celdas": 1.2981},
	{"id": "banco_espera_pro", "ruta": CARPETA_BANCOS + "banco_espera_pro.glb", "ancho_objetivo_celdas": 1.2981},
	{"id": "banco_madera_summer", "ruta": CARPETA_BANCOS + "banco_madera_summer.glb", "ancho_objetivo_celdas": 0.6683},
]

## La barrera: por ANCHO objetivo = 6,0 celdas (480 px) a 0° — el brazo debe cubrir una calle de 6
## celdas, misma familia de escala que las carreteras de `render_entorno_urbano.gd`.
const MODELO_BARRERA: Dictionary = {
	"id": "barrera_seguridad", "ruta": CARPETA_BARRERA + "barrera_seguridad.glb", "ancho_objetivo_celdas": 6.0,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA_BANCOS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA_BARRERA))

	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false  # nunca debe aparecer en un render.

	var todas: Dictionary = {}
	var fallos: Array[String] = []
	for modelo: Dictionary in MODELOS_BANCOS:
		if not _cargar(contenedor, modelo, todas):
			fallos.append(String(modelo["id"]))
	if not _cargar(contenedor, MODELO_BARRERA, todas):
		fallos.append(String(MODELO_BARRERA["id"]))

	if not fallos.is_empty():
		push_error("[BANCOS/BARRERA] no se pudieron cargar (glb null, probar --import): %s" % ", ".join(fallos))

	await _ejecutar(todas)


## Carga UN `.glb` suelto (ya importado dentro de `res://`) y vuelca sus `MeshInstance3D` en
## `todas` con el prefijo `<id>__` — mismo formato que `render_entorno_urbano.gd::_cargar`. Devuelve
## `false` si `load()` fue null (glb sin importar) para que `_ready` pueda reportarlo.
func _cargar(contenedor: Node3D, modelo: Dictionary, todas: Dictionary) -> bool:
	var id: String = modelo["id"]
	var ruta: String = modelo["ruta"]
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[BANCOS/BARRERA] no se pudo cargar %s" % ruta)
		return false
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
	print("[BANCOS/BARRERA] %s: %d MeshInstance3D cargadas (%s)" % [id, total, ruta])
	if total == 0:
		push_warning("[BANCOS/BARRERA] %s: 0 piezas -- silueta vendrá vacía" % id)
	return true


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

	print("[BANCOS/BARRERA] px/metro = %.4f (muñeco %.0fpx ~ %.2fm) x factor de presencia %.2f" % [
		PX_POR_METRO, ALTO_MUNECO_PX, ALTO_MUNECO_M, FACTOR_PRESENCIA
	])

	var todos_modelos: Array[Dictionary] = MODELOS_BANCOS.duplicate()
	todos_modelos.append(MODELO_BARRERA)

	var vacios: Array[String] = []

	for modelo: Dictionary in todos_modelos:
		var id: String = modelo["id"]
		var salida: String = SALIDA_BARRERA if id == String(MODELO_BARRERA["id"]) else SALIDA_BANCOS
		var por_ancho: bool = modelo.has("ancho_objetivo_celdas")
		var nombres: PackedStringArray = _nombres_de(todas, id)
		if nombres.is_empty():
			push_warning("[BANCOS/BARRERA] %s: receta vacía -- se salta" % id)
			vacios.append(id)
			continue
		var receta: Dictionary = {"id_salida": id, "nombres": nombres}

		var ancla: Vector3 = _ancla_de(receta, todas)
		var radio: float = _radio_de(receta, todas, ancla)
		_montar_receta(grupo, receta, todas, ancla)
		_colocar_camara(radio * 2.0 * MARGEN)

		# 1) Bruto a 0° -- define la escala de ESTA pieza. Bancos: por ALTURA REAL x factor de
		# presencia. Barrera: por el ANCHO de su huella en la rejilla (6,0 celdas).
		grupo.rotation = Vector3.ZERO
		var bruto_0: Dictionary = await _renderizar_bruto()
		var imagen_0: Image = bruto_0["imagen"]
		var objetivo_px: float
		var medido_bruto_px: int
		var escala_pieza: float
		if por_ancho:
			var ancho_celdas: float = modelo["ancho_objetivo_celdas"]
			objetivo_px = ancho_celdas * float(Proyeccion.ANCHO_ROMBO)
			medido_bruto_px = _medir_ancho(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[BANCOS/BARRERA] %s: radio=%.3f m, bruto 0°=%dx%dpx (ancho silueta=%dpx), objetivo=%.2f celdas->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				ancho_celdas, objetivo_px, escala_pieza
			])
		else:
			var altura_objetivo_m: float = modelo["altura_objetivo_m"]
			objetivo_px = altura_objetivo_m * PX_POR_METRO * FACTOR_PRESENCIA
			medido_bruto_px = _medir_alto(imagen_0)
			escala_pieza = objetivo_px / float(maxi(medido_bruto_px, 1))
			print("[BANCOS/BARRERA] %s: radio=%.3f m, bruto 0°=%dx%dpx (alto silueta=%dpx), objetivo=%.2fm×%.2f->%.1fpx -> factor=%.4f" % [
				id, radio, imagen_0.get_width(), imagen_0.get_height(), medido_bruto_px,
				altura_objetivo_m, FACTOR_PRESENCIA, objetivo_px, escala_pieza
			])

		if medido_bruto_px <= 1:
			vacios.append(id)

		# 2) Las 4 rotaciones, MISMO factor de escala UNIFORME (X=Y, ley del proyecto).
		var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
		for rot: int in [90, 180, 270]:
			grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
			var bruto: Dictionary = await _renderizar_bruto()
			escalados.append(_escalar(bruto, escala_pieza))

		var compuesto: Dictionary = _componer(escalados)
		var imagenes: Array[Image] = compuesto["imagenes"]
		var ancla_final: Vector2 = compuesto["ancla"]

		for i: int in ROTACIONES.size():
			var ruta: String = "%s%s_%d.png" % [salida, id, ROTACIONES[i]]
			var err: Error = (imagenes[i] as Image).save_png(ProjectSettings.globalize_path(ruta))
			if err != OK:
				push_error("[BANCOS/BARRERA] save_png '%s' fallo (error %d)" % [ruta, err])
			var alto_medido: int = _medir_alto(imagenes[i] as Image)
			var ancho_medido: int = _medir_ancho(imagenes[i] as Image)
			var ancho_celdas_medido: float = float(ancho_medido) / float(Proyeccion.ANCHO_ROMBO)
			print("[BANCOS/BARRERA]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), alto medido=%dpx, ancho medido=%dpx (%.3f celdas)" % [
				id, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
				ancla_final.x, ancla_final.y, alto_medido, ancho_medido, ancho_celdas_medido
			])
		print("[BANCOS/BARRERA] %s: guardado -> %s%s_{0,90,180,270}.png" % [id, salida, id])

	if not vacios.is_empty():
		push_warning("[BANCOS/BARRERA] piezas con silueta vacía o receta vacía: %s" % ", ".join(vacios))

	print("[BANCOS/BARRERA] hecho.")
	get_tree().quit()


## El ALTO en píxeles de la silueta opaca de una imagen (mismo criterio que
## `render_entorno_urbano.gd::_medir_alto`).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[BANCOS/BARRERA] silueta totalmente transparente")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


## El ANCHO en píxeles de la silueta opaca (mismo criterio que
## `render_entorno_urbano.gd::_medir_ancho`).
func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	for px: int in range(ancho):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			min_x = px
			break
	if min_x < 0:
		push_warning("[BANCOS/BARRERA] silueta totalmente transparente")
		return ancho
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			max_x = px
			break
	return max_x - min_x + 1
