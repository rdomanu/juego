extends "res://tools/render_mobiliario.gd"
## _render_conjunto_ventanillas — DESECHABLE (2026-08-07). SEGUNDO INTENTO, esta vez en 3D REAL:
## el intento anterior componía en 2D (mesa PNG + aparato PNG, anclado con heurísticas de píxel —
## `tools/_componer_bloques_ventanilla.gd`) y el usuario lo rechazó: "el CRT sale flotando/
## descentrado" y "el monitor tapa la mampara" (debía ser al revés). Aquí el CRT/monitor se coloca
## como una pieza 3D DE VERDAD encima del tablero, en la MISMA escena que la mesa —posición real,
## oclusión real por el renderer, nada de adivinar un punto de anclaje sobre un PNG ya aplanado.
##
## ── CÓMO SE DECIDIÓ LA GEOMETRÍA (sin mirar el render, con `_diag3d_ventanillas.gd`) ────────────
## Los dos GLB son una ÚNICA malla fusionada cada uno (sin nombres de pieza que discriminen
## cajonera/mampara/hueco de piernas), así que la ubicación de cada rasgo se dedujo por VÉRTICES:
##  · `mesa_ventanilla_media_v2_vacia`: los vértices con y_max=0,6705 (la mampara, más alta que el
##    tablero) caen SOLO en el cuadrante Z<centro (mitad "cruda -Z"); en la mitad Z>centro el tope
##    es y_max=0,4006 (tablero raso, sin mampara -- el lado "de trabajo"). El encargo pide la
##    mampara en el LADO CIUDADANO (sur); para que la mitad -Z (donde vive) caiga al sur en la
##    vista final, la mesa se monta con un giro interno de 180° (`mesa_media_180` ya lo hacía en el
##    intento 2D -- se reutiliza el mismo giro, solo cambia CÓMO se ancla el aparato encima).
##  · `mesa_ventanilla_basica_v3_vacia`: el tablero mide y_max=0,4822 EN LOS 4 CUADRANTES (una losa
##    plana, sin mampara) -- no hay ninguna asimetría norte/sur real en la geometría (la cajonera es
##    una asimetría de ANCHO/X, no de fondo/Z: más vértices en X>centro = el lado de la cajonera,
##    ver el diagnóstico). Sin mampara que obligue una orientación, se deja SIN giro interno (mismo
##    criterio que el intento 2D, `mesa_basica_0`) y el CRT se planta en la mitad -Z, elegida como
##    "norte" por convención para que las dos mesas usen el MISMO signo de eje.
##  · `crt_antiguo` (180° interno) y `monitor_unico` (0° interno, de `_render_monitor_unico.gd`):
##    MISMOS giros que validó el intento 2D -- esa parte nunca falló, la pantalla ya caía mirando
##    al norte en las dos piezas (ver sus propias cabeceras). Lo único que cambia es el ANCLAJE.
##
## ── LA ESCALA: RATIO, NO METROS ABSOLUTOS ────────────────────────────────────────────────────────
## Cada mueble de esta pasada se calibra por un criterio DISTINTO (la mesa por ANCHO -> 58px de
## `_render_mesa_ventanilla_lote.gd`; el CRT/monitor por ALTURA real -> `render_props_poly`/
## `_render_crt_antiguo.gd`/`_render_monitor_unico.gd`, formula px=m×25,882×1,25). Para que el
## aparato salga proporcional a la mesa DENTRO de la misma escena 3D (y no que cada uno "parezca
## bien" solo en su propio render aislado), se renderiza primero cada pieza SOLA con su propia
## cámara (igual que su script original) para sacar su factor de escala YA APROBADO (F = px_salida /
## px_bruto), y el aparato se monta en la escena con un `Node3D.scale` = F_aparato / F_mesa: al
## calibrar el CONJUNTO por el ancho de la mesa (mismo 58px de siempre), el aparato cae EXACTAMENTE
## en su tamaño real ya aprobado, sin inventar una escala nueva.
##
## Escribe SOLO al scratchpad -- PROHIBIDO tocar assets/sprites/mobiliario/.

const CARPETA_ORIGEN := "res://capturas/fuentes/mesa_ventanilla_summer/"
const CARPETA_SCRATCH := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

const ALTO_MUNECO_PX: float = 44.0
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = ALTO_MUNECO_PX / ALTO_MUNECO_M
const FACTOR_PRESENCIA: float = 1.25
const OBJ_PX_M: float = PX_POR_METRO * FACTOR_PRESENCIA  # 32.3529 px/m con presencia

const ANCHO_OBJETIVO_MESA_PX: float = 58.0

## CRT (ver `_render_crt_antiguo.gd`): 130px brutos = la porción "monitor" (sin la torre, misma
## cámara/margen -> bruto IDÉNTICO reutilizando el mismo pipeline aquí) -> objetivo 0,40 m.
const CRT_MONITOR_RAW_PX: float = 130.0
const CRT_MONITOR_OBJETIVO_M: float = 0.40
const CRT_MONITOR_OBJETIVO_PX: float = CRT_MONITOR_OBJETIVO_M * OBJ_PX_M

## Monitor único (`_render_monitor_unico.gd`): antes 0,35 m -- el usuario lo vio "muy pequeño para
## un monitor de sobremesa real", este encargo pide subirlo a ~0,55 m (altura TOTAL del conjunto
## base+brazo+pantalla, mismo criterio de medida que el 0,35 anterior -- `_medir_alto` del bruto).
const MONITOR_UNICO_OBJETIVO_M: float = 0.55

## AABB de las mesas -- medidas con `tools/_diag3d_ventanillas.gd` (impresas en el informe de esta
## pasada). Los cuerpos son losas rígidas de 1 sola malla: leer el AABB en vez de recalcularlo aquí
## no cambia nada (misma malla, mismo import) y deja el número trazable a su fuente.
const BASICA_TABLERO_TOP: float = 0.482196  # y_max, igual en los 4 cuadrantes -- losa plana
## Mitad ELEGIDA como "norte" (sin mampara que lo imponga, ver la cabecera): el extremo Z MÍNIMO.
const BASICA_Z_EDGE_NORTE: float = -0.265081  # pos.z (mínimo)

## Media: el lado "de trabajo" (Z>centro, SIN mampara) tiene tablero a y_max=0,4006 -- medido con
## el mismo diagnóstico (cuadrantes (-1,1)/(1,1)). Tras el giro interno de 180°, esa mitad cruda
## +Z es la que cae al NORTE en la vista final (ver la cabecera).
const MEDIA_TABLERO_TOP_NORTE: float = 0.4006
const MEDIA_Z_EDGE_NORTE_CRUDO: float = 0.269426  # pos.z + size.z (máximo), lado sin mampara

const ROTACION_INTERNA_CRT := 180.0
const ROTACION_INTERNA_MONITOR := 0.0
const ROTACION_INTERNA_MESA_BASICA := 0.0
const ROTACION_INTERNA_MESA_MEDIA := 180.0

var _todas_basica: Dictionary = {}
var _todas_crt: Dictionary = {}
var _todas_media: Dictionary = {}
var _todas_monitor: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_SCRATCH)
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.visible = false

	_cargar_glb(contenedor, CARPETA_ORIGEN + "mesa_ventanilla_basica_v3_vacia.glb", "mesa_basica", _todas_basica)
	_cargar_glb(contenedor, CARPETA_ORIGEN + "crt_antiguo.glb", "crt", _todas_crt)
	_cargar_glb(contenedor, CARPETA_ORIGEN + "mesa_ventanilla_media_v2_vacia.glb", "mesa_media", _todas_media)

	var escena_oficina: PackedScene = load(MODELO)
	var raiz_oficina: Node3D = escena_oficina.instantiate()
	contenedor.add_child(raiz_oficina)
	var todas_oficina: Dictionary = _recopilar_instancias(raiz_oficina)
	for n: String in NOMBRES_MONITOR:
		if todas_oficina.has(n):
			_todas_monitor["monitor__%s" % n] = todas_oficina[n]

	_ejecutar_conjuntos()


func _cargar_glb(contenedor: Node3D, ruta: String, id: String, todas: Dictionary) -> void:
	var escena: PackedScene = load(ruta)
	if escena == null:
		push_error("[CONJUNTO] no se pudo cargar %s" % ruta)
		return
	var raiz: Node3D = escena.instantiate()
	contenedor.add_child(raiz)
	for hijo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			continue
		var overrides: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		todas["%s__%s" % [id, mi.name]] = {
			"malla": mi.mesh, "transform": mi.global_transform,
			"material_override": mi.material_override, "overrides": overrides,
		}


func _nombres_de(todas: Dictionary, prefijo: String) -> PackedStringArray:
	var resultado := PackedStringArray()
	for clave: String in todas.keys():
		if (clave as String).begins_with(prefijo):
			resultado.append(clave)
	return resultado


func _medir_alto(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_y := -1
	for py: int in range(alto):
		if _fila_opaca(imagen, py, ancho):
			min_y = py
			break
	if min_y < 0:
		return alto
	var max_y: int = min_y
	for py: int in range(alto - 1, min_y, -1):
		if _fila_opaca(imagen, py, ancho):
			max_y = py
			break
	return max_y - min_y + 1


func _medir_ancho(imagen: Image) -> int:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var min_x := -1
	var max_x := -1
	for px: int in range(ancho):
		if _columna_opaca(imagen, px, alto):
			if min_x < 0:
				min_x = px
			max_x = px
	if min_x < 0:
		return ancho
	return max_x - min_x + 1


func _fila_opaca(imagen: Image, py: int, ancho: int) -> bool:
	for px: int in range(ancho):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false


func _columna_opaca(imagen: Image, px: int, alto: int) -> bool:
	for py: int in range(alto):
		if imagen.get_pixel(px, py).a > 0.01:
			return true
	return false


## Render bruto de UNA receta sola (cámara propia, calibrada a su propio radio) -- reproduce
## exactamente el pipeline de su script original (`_render_mesa_ventanilla_lote.gd`/
## `_render_crt_antiguo.gd`/`_render_monitor_unico.gd`), así que el bruto es pixel-idéntico al que
## ya validaron esos scripts -- de ahí que se pueda reutilizar `CRT_MONITOR_RAW_PX` sin remedir.
func _bruto_solo(grupo: Node3D, todas: Dictionary, prefijo: String) -> Dictionary:
	var receta: Dictionary = {"id_salida": prefijo, "nombres": _nombres_de(todas, prefijo + "__")}
	var ancla: Vector3 = _ancla_de(receta, todas)
	var radio: float = _radio_de(receta, todas, ancla)
	_montar_receta(grupo, receta, todas, ancla)
	_colocar_camara(radio * 2.0 * MARGEN)
	grupo.rotation = Vector3.ZERO
	var bruto: Dictionary = await _renderizar_bruto()
	return {"bruto": bruto, "ancla": ancla, "radio": radio}


func _ejecutar_conjuntos() -> void:
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

	# ── PASO 1: cada pieza SOLA, para sacar su factor F = px_salida/px_bruto YA APROBADO ─────────
	var r_basica: Dictionary = await _bruto_solo(grupo, _todas_basica, "mesa_basica")
	var ancho_basica_bruto: int = _medir_ancho(r_basica["bruto"]["imagen"])
	var f_mesa_basica: float = ANCHO_OBJETIVO_MESA_PX / float(maxi(ancho_basica_bruto, 1))

	var r_media: Dictionary = await _bruto_solo(grupo, _todas_media, "mesa_media")
	var ancho_media_bruto: int = _medir_ancho(r_media["bruto"]["imagen"])
	var f_mesa_media: float = ANCHO_OBJETIVO_MESA_PX / float(maxi(ancho_media_bruto, 1))

	var r_crt: Dictionary = await _bruto_solo(grupo, _todas_crt, "crt")
	var f_crt: float = CRT_MONITOR_OBJETIVO_PX / CRT_MONITOR_RAW_PX

	var r_monitor: Dictionary = await _bruto_solo(grupo, _todas_monitor, "monitor")
	var alto_monitor_bruto: int = _medir_alto(r_monitor["bruto"]["imagen"])
	var monitor_objetivo_px: float = MONITOR_UNICO_OBJETIVO_M * OBJ_PX_M
	var f_monitor: float = monitor_objetivo_px / float(maxi(alto_monitor_bruto, 1))

	print("[CONJUNTO] F mesa_basica=%.5f (bruto %dpx) | F mesa_media=%.5f (bruto %dpx) | F crt=%.5f | F monitor=%.5f (bruto alto %dpx, objetivo %.2fpx)" % [
		f_mesa_basica, ancho_basica_bruto, f_mesa_media, ancho_media_bruto, f_crt, f_monitor,
		alto_monitor_bruto, monitor_objetivo_px
	])

	var escala_crt_relativa: float = f_crt / f_mesa_basica
	var escala_monitor_relativa: float = f_monitor / f_mesa_media
	print("[CONJUNTO] escala_crt_relativa (sobre malla cruda de la mesa)=%.4f | escala_monitor_relativa=%.4f" % [
		escala_crt_relativa, escala_monitor_relativa
	])

	# ── PASO 2: construir los 2 conjuntos 3D DE VERDAD (mesa + aparato, mismo Node3D) ─────────────
	var offset_z_basica: float = (BASICA_Z_EDGE_NORTE - r_basica["ancla"].z) * 0.5
	var offset_z_media_crudo: float = (MEDIA_Z_EDGE_NORTE_CRUDO - r_media["ancla"].z) * 0.5
	# La mesa media gira 180° interno -> el desplazamiento crudo (lado +Z, sin mampara) cae en -Z
	# de la escena final (ver la cabecera). El de la básica NO gira -> mismo signo tal cual.
	var offset_z_media_final: float = -offset_z_media_crudo
	print("[CONJUNTO] offset Z (norte, local a cada grupo): básica=%.4f | media=%.4f (crudo %.4f)" % [
		offset_z_basica, offset_z_media_final, offset_z_media_crudo
	])

	var grupo_basica := Node3D.new()
	_construir_conjunto_basica(grupo_basica, r_basica["ancla"], escala_crt_relativa, offset_z_basica)
	var grupo_media := Node3D.new()
	_construir_conjunto_media(grupo_media, r_media["ancla"], escala_monitor_relativa, offset_z_media_final)

	var activo: Node3D = grupo
	activo = await _renderizar_y_guardar(
		mundo, activo, grupo_basica, "mesa_basica_conjunto", f_mesa_basica, r_basica["radio"]
	)
	activo = await _renderizar_y_guardar(
		mundo, activo, grupo_media, "mesa_media_conjunto", f_mesa_media, r_media["radio"]
	)

	print("[CONJUNTO] hecho.")
	get_tree().quit()


## Pieza con su transformada YA CENTRADA en el ancla de SU PROPIA malla (mismo criterio que
## `_montar_pieza`: origen local = origen_mundo - ancla), para que un `Node3D` padre pueda rotarla/
## escalarla/moverla como bloque rígido sin arrastrar el desplazamiento original del GLB.
func _pieza_centrada(malla: Mesh, transform_mundo: Transform3D, ancla: Vector3, material_override: Variant, overrides: Array) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.transform = Transform3D(transform_mundo.basis, transform_mundo.origin - ancla)
	pieza.material_override = material_override
	for s: int in malla.get_surface_count():
		pieza.set_surface_override_material(s, overrides[s] if s < overrides.size() else null)
	return pieza


func _construir_conjunto_basica(grupo: Node3D, ancla_mesa: Vector3, escala_crt: float, offset_z: float) -> void:
	var mesa_pivot := Node3D.new()
	mesa_pivot.rotation_degrees.y = ROTACION_INTERNA_MESA_BASICA
	for clave: String in _nombres_de(_todas_basica, "mesa_basica__"):
		var it: Dictionary = _todas_basica[clave]
		mesa_pivot.add_child(_pieza_centrada(it["malla"], it["transform"], ancla_mesa, it.get("material_override"), it.get("overrides", [])))
	grupo.add_child(mesa_pivot)

	var ancla_crt: Vector3 = _ancla_de({"id_salida": "crt", "nombres": _nombres_de(_todas_crt, "crt__")}, _todas_crt)
	var crt_pivot := Node3D.new()
	crt_pivot.rotation_degrees.y = ROTACION_INTERNA_CRT
	crt_pivot.scale = Vector3.ONE * escala_crt
	crt_pivot.position = Vector3(0.0, BASICA_TABLERO_TOP, offset_z)
	for clave: String in _nombres_de(_todas_crt, "crt__"):
		var it: Dictionary = _todas_crt[clave]
		crt_pivot.add_child(_pieza_centrada(it["malla"], it["transform"], ancla_crt, it.get("material_override"), it.get("overrides", [])))
	grupo.add_child(crt_pivot)


func _construir_conjunto_media(grupo: Node3D, ancla_mesa: Vector3, escala_monitor: float, offset_z: float) -> void:
	var mesa_pivot := Node3D.new()
	mesa_pivot.rotation_degrees.y = ROTACION_INTERNA_MESA_MEDIA
	for clave: String in _nombres_de(_todas_media, "mesa_media__"):
		var it: Dictionary = _todas_media[clave]
		mesa_pivot.add_child(_pieza_centrada(it["malla"], it["transform"], ancla_mesa, it.get("material_override"), it.get("overrides", [])))
	grupo.add_child(mesa_pivot)

	var ancla_monitor: Vector3 = _ancla_de({"id_salida": "monitor", "nombres": _nombres_de(_todas_monitor, "monitor__")}, _todas_monitor)
	var monitor_pivot := Node3D.new()
	monitor_pivot.rotation_degrees.y = ROTACION_INTERNA_MONITOR
	monitor_pivot.scale = Vector3.ONE * escala_monitor
	monitor_pivot.position = Vector3(0.0, MEDIA_TABLERO_TOP_NORTE, offset_z)
	for clave: String in _nombres_de(_todas_monitor, "monitor__"):
		var it: Dictionary = _todas_monitor[clave]
		monitor_pivot.add_child(_pieza_centrada(it["malla"], it["transform"], ancla_monitor, it.get("material_override"), it.get("overrides", [])))
	grupo.add_child(monitor_pivot)


## Renderiza las 4 rotaciones del CONJUNTO YA MONTADO (mesa+aparato, un solo bloque rígido) con
## UNA cámara fija que encuadra el conjunto entero (mesa Y aparato -- así si algo asomara del borde
## se vería recortado por el margen, no oculto por un encuadre que solo mirase la mesa).
##
## CORREGIDO tras el 1er lanzamiento (mesa salía a 46px, no a los 58px de siempre): el aparato
## ENCIMA del tablero agranda el AABB conjunto (radio de cámara mayor que el de la mesa sola), la
## cámara se aleja para que quepa entero, y a más distancia el MISMO `f_mesa` (calibrado con el
## radio de la mesa SOLA) deja la mesa más pequeña de la cuenta -- el bruto encoge en proporción
## `radio_solo/radio_conjunto` respecto al bruto con el que se calibró `f_mesa`. Se corrige
## reescalando en sentido inverso: `f_mesa × (radio_conjunto/radio_solo)` devuelve la mesa a su
## 58px exactos pase lo que pase con la altura del aparato.
func _renderizar_y_guardar(
	mundo: Node3D, grupo_viejo: Node3D, grupo_nuevo: Node3D, id_salida: String, f_mesa: float,
	radio_mesa_sola: float
) -> Node3D:
	mundo.remove_child(grupo_viejo)
	mundo.add_child(grupo_nuevo)

	# Radio de cámara: el mayor entre las esquinas de TODOS los MeshInstance3D montados (mesa +
	# aparato ya transformados a espacio de `grupo_nuevo`), calculado a mano porque `_radio_de`
	# espera una `receta` plana de `todas`, no un árbol ya montado con pivotes/escalas propios.
	var radio := 0.0
	for hijo: Node in grupo_nuevo.get_children():
		radio = maxf(radio, _radio_arbol(hijo as Node3D, Transform3D.IDENTITY))
	_colocar_camara(radio * 2.0 * MARGEN)

	var f_corregido: float = f_mesa * (radio / maxf(radio_mesa_sola, 0.0001))
	print("[CONJUNTO] %s: radio_solo=%.4f radio_conjunto=%.4f -> f_mesa %.5f corregido a %.5f" % [
		id_salida, radio_mesa_sola, radio, f_mesa, f_corregido
	])

	grupo_nuevo.rotation = Vector3.ZERO
	var bruto_0: Dictionary = await _renderizar_bruto()
	var escalados: Array[Dictionary] = [_escalar(bruto_0, f_corregido)]
	for rot: int in [90, 180, 270]:
		grupo_nuevo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		escalados.append(_escalar(bruto, f_corregido))

	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	var ancla_final: Vector2 = compuesto["ancla"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [CARPETA_SCRATCH, id_salida, ROTACIONES[i]]
		var err: Error = (imagenes[i] as Image).save_png(ruta)
		if err != OK:
			push_error("[CONJUNTO] save_png '%s' fallo (error %d)" % [ruta, err])
		var img: Image = imagenes[i] as Image
		print("[CONJUNTO]   %s_%d.png: lienzo %dx%d px, ancla en (%.1f, %.1f), ancho_util=%dpx, alto_util=%dpx" % [
			id_salida, ROTACIONES[i], compuesto["ancho"], compuesto["alto"],
			ancla_final.x, ancla_final.y, _medir_ancho(img), _medir_alto(img)
		])
	print("[CONJUNTO] %s: guardado -> %s%s_{0,90,180,270}.png" % [id_salida, CARPETA_SCRATCH, id_salida])
	return grupo_nuevo


## Radio máximo (a las esquinas del AABB de cada `MeshInstance3D`) de un subárbol YA MONTADO,
## respecto al origen de `grupo_nuevo` -- acumula la transformada de cada `Node3D` intermedio
## (pivotes con su propia rotación/escala/posición) a mano, igual que `_global_transform_manual`
## de `_diag_crt_mesa_media.gd`, pero partiendo de un `Transform3D` base en vez de recorrer padres.
func _radio_arbol(nodo: Node3D, transform_acumulado: Transform3D) -> float:
	var t: Transform3D = transform_acumulado * nodo.transform
	var radio := 0.0
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
		var caja: AABB = t * (nodo as MeshInstance3D).mesh.get_aabb()
		for esquina: Vector3 in _esquinas_de(caja):
			radio = maxf(radio, esquina.length())
	for hijo: Node in nodo.get_children():
		if hijo is Node3D:
			radio = maxf(radio, _radio_arbol(hijo as Node3D, t))
	return radio
