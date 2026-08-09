extends "res://tools/render_mobiliario.gd"
## _render_impresora_dni — DESECHABLE, fase de PROPUESTA (2026-08-06).
##
## Render de las 4 rotaciones reales (0/90/180/270°) de la impresora de DNI nueva de Summer
## (`capturas/fuentes/impresora_dni_summer/impresora_dni_workstation.glb`, ~14 MB, un único
## `MeshInstance3D` llamado "node_0" fusionado -- confirmado con `tools/_diag_impresora_dni.gd`,
## desechable también, sin hijos que separar cuerpo/baliza).
##
## Reusa el pipeline de cámara/luces/entorno de `render_mobiliario.gd` (extends, mismo patrón que
## `render_props_poly.gd`) y su propia carga de UN `.glb` suelto (mismo patrón que
## `render_props_poly._cargar`, aquí simplificado a una sola pieza).
##
## ── CALIBRACIÓN: POR ANCHO, NO POR ALTO (desviación documentada del canon) ──────────────────────
## El canon del proyecto (`design/art/plan-escalado.md` §5, `render_props_poly.gd`) calibra SIEMPRE
## por ALTURA real declarada. Aquí no se puede: el modelo es una única malla fusionada (cuerpo +
## baliza del poste, sin nodos separados -- ver el diagnóstico), así que no hay forma de medir
## "solo el alto del cuerpo" en el render bruto (la silueta completa incluye la baliza, que no
## tiene una altura nominal dada). El encargo SÍ da un número explícito y verificable para el
## ANCHO del cuerpo (58 px, ancho ≈ el eje que NO lleva la baliza), así que la calibración de este
## script fuerza el ANCHO de la silueta a 0°, no el alto -- mismo espíritu que el canon (declarar un
## objetivo en píxeles y forzar el factor de escala a partir de él), aplicado al único eje medible
## sin ambigüedad para esta pieza en concreto. El alto resultante (cuerpo + baliza) se imprime solo
## a título informativo, NO como criterio de PASA/FALLA.
##
## `ANCHO_OBJETIVO_M`/`ALTO_OBJETIVO_M` documentan las dimensiones nominales del encargo (1,80 ×
## 0,80 × 1,10 m) para referencia -- el AABB real del `.glb` (0,695 × 0,516 × 0,895 m, ejes
## x/z/y) NO coincide en proporción (la pieza real es más estrecha y alta que la caja nominal:
## trae brazo de cámara/pantalla por encima del cuerpo, coherente con "más la baliza del poste por
## encima" del encargo) -- se escala UNIFORMEMENTE (nunca se deforma la malla), así que solo UN eje
## puede casar exacto con su objetivo; se elige el ancho por ser el dato explícito de verificación.
##
## Escribe SOLO al scratchpad de la sesión (NO `assets/`) -- fase de PROPUESTA/presentación.

const RUTA_GLB := "res://capturas/fuentes/impresora_dni_summer/impresora_dni_workstation.glb"
const SALIDA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

## Misma ley del ancla que el resto del proyecto (`design/art/plan-escalado.md` §1).
const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M  # ≈ 25.882

## FACTOR DE PRESENCIA (usuario, 2026-08-06, `plan-escalado.md` §1): mobiliario/objetos
## interactivos se exageran ×1.25 frente a la escala métrica exacta para no leer "enanos" junto a
## los muñecos cabezones del juego.
const FACTOR_PRESENCIA: float = 1.25

## Dimensiones NOMINALES del encargo (referencia/documentación -- ver la cabecera sobre por qué
## solo el ancho se usa como objetivo de calibración real).
const ANCHO_OBJETIVO_M: float = 1.80
const FONDO_OBJETIVO_M: float = 0.80
const ALTO_OBJETIVO_M: float = 1.10  # SOLO el cuerpo, sin la baliza (sin cifra propia en el encargo)

const ANCHO_OBJETIVO_PX: float = ANCHO_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA
const ALTO_OBJETIVO_PX_INFORMATIVO: float = ALTO_OBJETIVO_M * PX_POR_METRO * FACTOR_PRESENCIA

const TOLERANCIA_PX: float = 3.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA_SCRATCH)

	var escena: PackedScene = load(RUTA_GLB)
	if escena == null:
		push_error("[IMPRESORA DNI] no se pudo cargar %s" % RUTA_GLB)
		get_tree().quit(1)
		return
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)

	var todas: Dictionary = {}
	var nombres := PackedStringArray()
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas[mi.name] = {
			"malla": mi.mesh,
			"transform": mi.global_transform,
			"material_override": mi.material_override,
			"overrides": overrides,
		}
		nombres.append(mi.name)
	print("[IMPRESORA DNI] %d MeshInstance3D cargadas: %s" % [nombres.size(), nombres])
	if nombres.is_empty():
		push_error("[IMPRESORA DNI] el GLB no trajo ninguna malla")
		get_tree().quit(1)
		return

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

	var receta: Dictionary = {"id_salida": "impresora_dni", "nombres": nombres}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)
	print("[IMPRESORA DNI] ancla=%s radio=%.4f m -> cámara %.4f m" % [ancla, radio, radio * 2.0 * MARGEN])

	# 1) Bruto a 0° -- define la escala por ANCHO (ver la cabecera).
	grupo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var imagen_0: Image = bruto_0["imagen"]
	var ancho_bruto_px: int = _medir_ancho(imagen_0)
	var alto_bruto_px: int = _medir_alto(imagen_0)
	var escala_pieza: float = ANCHO_OBJETIVO_PX / float(maxi(ancho_bruto_px, 1))
	print(
		"[IMPRESORA DNI] bruto 0°=%dx%dpx (silueta ancho=%dpx alto=%dpx), objetivo ancho=%.2fm->%.2fpx -> factor=%.4f"
		% [
			imagen_0.get_width(), imagen_0.get_height(), ancho_bruto_px, alto_bruto_px,
			ANCHO_OBJETIVO_M, ANCHO_OBJETIVO_PX, escala_pieza
		]
	)

	# 2) Las 4 rotaciones, MISMO factor.
	var escalados: Array[Dictionary] = [_escalar(bruto_0, escala_pieza)]
	for rot: int in [90, 180, 270]:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		escalados.append(_escalar(bruto, escala_pieza))

	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	var ancla_final: Vector2 = compuesto["ancla"]

	for i: int in ROTACIONES.size():
		var ruta: String = "%simpresora_dni_%d.png" % [SALIDA_SCRATCH, ROTACIONES[i]]
		var err: Error = (imagenes[i] as Image).save_png(ruta)
		if err != OK:
			push_error("[IMPRESORA DNI] save_png '%s' falló (error %d)" % [ruta, err])
		else:
			print("[IMPRESORA DNI] guardado -> %s" % ruta)

	# 3) VERIFICACIÓN con número impreso -- ancho final (0°) vs objetivo, PASA/FALLA ±3 px.
	var imagen_final_0: Image = imagenes[0]
	var ancho_final_px: int = _medir_ancho(imagen_final_0)
	var alto_final_px: int = _medir_alto(imagen_final_0)
	var desvio_ancho: float = float(ancho_final_px) - ANCHO_OBJETIVO_PX
	var veredicto: String = "PASA" if absf(desvio_ancho) <= TOLERANCIA_PX else "FALLA"
	print("[IMPRESORA DNI] ── VERIFICACIÓN ──────────────────────────────────────────")
	print("[IMPRESORA DNI]   lienzo final: %dx%d px, ancla en (%.1f, %.1f)" % [
		compuesto["ancho"], compuesto["alto"], ancla_final.x, ancla_final.y
	])
	print(
		"[IMPRESORA DNI]   ANCHO cuerpo (0°): medido=%dpx objetivo=%.1fpx desvío=%+.1fpx (tol ±%.0fpx) -> %s"
		% [ancho_final_px, ANCHO_OBJETIVO_PX, desvio_ancho, TOLERANCIA_PX, veredicto]
	)
	print(
		"[IMPRESORA DNI]   ALTO total (0°, cuerpo+baliza, INFORMATIVO): medido=%dpx | objetivo SOLO cuerpo=%.1fpx (sin cifra de baliza en el encargo)"
		% [alto_final_px, ALTO_OBJETIVO_PX_INFORMATIVO]
	)
	print("[IMPRESORA DNI] hecho.")
	get_tree().quit()


## El ALTO en píxeles de la silueta opaca (mismo patrón que `render_props_poly._medir_alto`).
func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		push_warning("[IMPRESORA DNI] silueta totalmente transparente (alto)")
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if AnclajeSpriteScript._fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


## El ANCHO en píxeles de la silueta opaca: columna opaca más a la izquierda a la más a la derecha
## (mismo escaneo por columna que usa `AnclajeSprite._medir_centro_base`, aquí solo para medir, no
## para anclar).
func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	for px: int in range(ancho):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			min_x = px
			break
	if min_x < 0:
		push_warning("[IMPRESORA DNI] silueta totalmente transparente (ancho)")
		return ancho
	var max_x: int = min_x
	for px: int in range(ancho - 1, min_x, -1):
		if AnclajeSpriteScript._columna_opaca(imagen, px, alto):
			max_x = px
			break
	return max_x - min_x + 1
