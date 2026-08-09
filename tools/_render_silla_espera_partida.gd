extends Node3D
## HERRAMIENTA DE UN SOLO USO (GPU, no headless) — parte la silla de espera (OBJ_023,
## `ID_SILLA_ESPERA` de `render_mobiliario.gd`: "Object_931"=cojín, "Object_932"=chasis de tubo)
## en DOS sprites, SOLO rotación 270 (la que usa el frente de la ventanilla, ver
## `MesaAtencion.ROT_SILLA_ESPERA`):
##   - `silla_espera_asiento_270.png`: chasis (Object_932, ENTERO) + la mitad BAJA del cojín
##     (Object_931, triángulos cuyo centroide Y de mundo < UMBRAL_Y_MUNDO -- el asiento).
##   - `silla_espera_respaldo_270.png`: la mitad ALTA del cojín (Object_931, centroide Y >=
##     UMBRAL_Y_MUNDO -- el respaldo).
##
## POR QUÉ SE CORTA ASÍ (no por nombre de malla): confirmado con `_diag_silla_espera_render.gd`
## (renders flotando cada malla por separado) que OBJ_023 NO separa asiento/respaldo por malla --
## separa por MATERIAL: `Object_931` es TODO el cojín beige (asiento+respaldo fundidos en una
## sola superficie continua) y `Object_932` es el chasis de tubo negro (4 patas + los 2 tirantes
## traseros que sostienen el respaldo). El umbral de corte se determinó con
## `_diag_silla_espera_corte.gd` (histograma de triángulos de `Object_931` por altura de mundo,
## 24 bins): el grueso del cojín-ASIENTO (normal mirando hacia ARRIBA, |ny|~0.7-0.9, ancho X
## completo) vive en Y_mundo ∈ [0.1746, 0.2745]; a partir de ahí la malla se adelgaza (huella
## mucho más estrecha, muy pocos triángulos: zona de transición del pliegue) y el cojín-RESPALDO
## (normal mirando hacia delante/atrás, huella de nuevo ancha en Z) no coge masa relevante hasta
## Y_mundo ~0.41-0.65. `UMBRAL_Y_MUNDO = 0.32` cae en la zona de transición (poca malla a
## cualquier lado -- la costura queda oculta bajo el muñeco sentado, que es la persona real
## encargada de tapar la unión, ver `mesa_atencion.gd` §"LA SILLA DE ESPERA, PARTIDA EN DOS"),
## deliberadamente por encima del final del asiento (~0.275) para no comerse ni una esquina del
## borde de la superficie de sentado.
##
## EL CHASIS (`Object_932`) SE DEJA ENTERO en `asiento` (nunca se corta): sus dos tirantes
## traseros suben hasta ~0.445 (por encima del umbral), pero son tubo negro fino que en la
## práctica queda oculto tras la espalda del muñeco sentado -- igual que en la silla ENTERA de
## siempre, donde ese chasis nunca se dibuja por separado del asiento.
##
## LA CLAVE DEL ENCAJE (pedido del usuario): las DOS piezas comparten el MISMO punto de ancla 3D
## (el ancla de la silla ENTERA -- centro X/Z de su AABB conjunta al nivel del suelo, MISMA
## fórmula que `render_mobiliario.gd::_ancla_de`) y la MISMA cámara/escala que ya usa
## `silla_espera_270.png` -- así que, en vez de RECALCULAR esa escala (arriesga desajustarse un
## pelo del pipeline real), se CALIBRA EMPÍRICAMENTE contra el PNG ya existente: se renderiza la
## silla ENTERA (las 2 mallas sin cortar) con una cámara cualquiera pero FIJA, se mide su recorte
## en píxeles y se compara con el recorte de `silla_espera_270.png` (alpha>0) -- el cociente es el
## factor de escala que hace que TODO lo demás (asiento, respaldo) salga exactamente al mismo
## tamaño de mundo→píxel que el sprite ya en uso. Verificación de que la calibración es correcta:
## la silla ENTERA recompuesta con ese factor debe medir lo mismo que el PNG existente (impreso
## por este script) Y superponerse encima sin apenas diferencia (columna aparte, con Python).
##
## Escribe SOLO en `assets/sprites/mobiliario/silla_espera_{asiento,respaldo}_270.png`. No toca
## ninguna otra receta ni el PNG de la silla entera. Herramienta desechable -- se borra al
## terminar la tarea.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const SALIDA := "res://assets/sprites/mobiliario/"
const REFERENCIA_SILLA_ENTERA := "res://assets/sprites/mobiliario/silla_espera_270.png"

const ELEVACION_GRADOS: float = 30.0
const TAM_RENDER: int = 512
const MARGEN: float = 1.15
const ROTACION: int = 270

const UMBRAL_Y_MUNDO: float = 0.32

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	var contenedor := Node3D.new()
	add_child(contenedor)
	contenedor.add_child(modelo)
	contenedor.visible = false

	var por_nombre: Dictionary = {}
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		por_nombre[String(hijo.name)] = hijo as MeshInstance3D
	var mi_cojin: MeshInstance3D = por_nombre["Object_931"]
	var mi_chasis: MeshInstance3D = por_nombre["Object_932"]

	# 1) Ancla compartida: AABB conjunta (cojín + chasis) al nivel del suelo -- misma fórmula que
	# `render_mobiliario.gd::_ancla_de`, receta de un solo grupo.
	var caja_cojin: AABB = mi_cojin.global_transform * mi_cojin.mesh.get_aabb()
	var caja_chasis: AABB = mi_chasis.global_transform * mi_chasis.mesh.get_aabb()
	var caja: AABB = caja_cojin.merge(caja_chasis)
	var centro: Vector3 = caja.get_center()
	var ancla := Vector3(centro.x, caja.position.y, centro.z)
	var radio := 0.0
	for esquina: Vector3 in _esquinas_de(caja):
		radio = maxf(radio, (esquina - ancla).length())
	var tam_mundo: float = radio * 2.0 * MARGEN
	print("[SILLA PARTIDA] ancla=%.4f,%.4f,%.4f radio=%.4f tam_mundo=%.4f" % [
		ancla.x, ancla.y, ancla.z, radio, tam_mundo
	])

	# 2) Corta Object_931 en asiento/respaldo por altura de mundo (ver cabecera).
	var partes: Dictionary = _cortar_por_altura(mi_cojin, UMBRAL_Y_MUNDO)
	var cojin_asiento: ArrayMesh = partes["bajo"]
	var cojin_respaldo: ArrayMesh = partes["alto"]
	print("[SILLA PARTIDA] cojín cortado en Y_mundo=%.3f: %d tris asiento / %d tris respaldo" % [
		UMBRAL_Y_MUNDO, partes["n_bajo"], partes["n_alto"]
	])

	# 3) Escenario de render (mismo patrón que render_mobiliario.gd).
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
	_colocar_camara(tam_mundo)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# 3a) Silla ENTERA (sin cortar) a esta misma cámara -- referencia para calibrar la escala
	# contra `silla_espera_270.png` ya existente (ver cabecera).
	var bruto_completa: Dictionary = await _renderizar_pieza(grupo, [
		{"mi": mi_cojin, "malla": mi_cojin.mesh},
		{"mi": mi_chasis, "malla": mi_chasis.mesh},
	], ancla)
	var factor_escala: float = _calibrar_contra_referencia(bruto_completa)
	print("[SILLA PARTIDA] factor de calibración (vs silla_espera_270.png existente) = %.5f" % factor_escala)

	# 3b) Asiento: chasis ENTERO + mitad baja del cojín.
	var bruto_asiento: Dictionary = await _renderizar_pieza(grupo, [
		{"mi": mi_chasis, "malla": mi_chasis.mesh},
		{"mi": mi_cojin, "malla": cojin_asiento},
	], ancla)
	_guardar(bruto_asiento, factor_escala, "silla_espera_asiento")

	# 3c) Respaldo: SOLO la mitad alta del cojín.
	var bruto_respaldo: Dictionary = await _renderizar_pieza(grupo, [
		{"mi": mi_cojin, "malla": cojin_respaldo},
	], ancla)
	_guardar(bruto_respaldo, factor_escala, "silla_espera_respaldo")

	# 3d) La silla entera recompuesta con el MISMO factor -- para el chequeo de superposición
	# (columna aparte en Python, comparando contra el PNG real). DIAGNÓSTICO: va a `tools/`, no a
	# `assets/sprites/mobiliario/` (no es un sprite del juego).
	_guardar(bruto_completa, factor_escala, "_diag_silla_espera_completa_recalibrada", "res://tools/")

	print("[SILLA PARTIDA] hecho.")
	get_tree().quit()


func _esquinas_de(caja: AABB) -> Array[Vector3]:
	var esquinas: Array[Vector3] = []
	var p: Vector3 = caja.position
	var s: Vector3 = caja.size
	for i: int in 8:
		esquinas.append(Vector3(
			p.x + s.x * float(i & 1), p.y + s.y * float((i >> 1) & 1), p.z + s.z * float((i >> 2) & 1)
		))
	return esquinas


func _colocar_camara(tam_mundo: float) -> void:
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = maxf(tam_mundo, 0.05) * 3.0
	_camara.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distancia
	_camara.look_at(Vector3.ZERO, Vector3.UP)
	_camara.size = maxf(tam_mundo, 0.05)


## Divide la malla de `mi_original` en dos `ArrayMesh` (mismo espacio LOCAL que la malla
## original, sin transformar -- para poder aplicarle luego la MISMA `global_transform`) según la
## altura de MUNDO del centroide de cada triángulo: "bajo" (< umbral) y "alto" (>= umbral).
func _cortar_por_altura(mi_original: MeshInstance3D, umbral_y_mundo: float) -> Dictionary:
	var t: Transform3D = mi_original.global_transform
	var malla: Mesh = mi_original.mesh
	var arrays: Array = malla.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n_tris: int = indices.size() / 3

	var v_bajo := PackedVector3Array()
	var n_bajo := PackedVector3Array()
	var uv_bajo := PackedVector2Array()
	var v_alto := PackedVector3Array()
	var n_alto := PackedVector3Array()
	var uv_alto := PackedVector2Array()
	var cuenta_bajo := 0
	var cuenta_alto := 0

	for i: int in n_tris:
		var i0: int = indices[i * 3]
		var i1: int = indices[i * 3 + 1]
		var i2: int = indices[i * 3 + 2]
		var p0w: Vector3 = t * verts[i0]
		var p1w: Vector3 = t * verts[i1]
		var p2w: Vector3 = t * verts[i2]
		var centro_y: float = (p0w.y + p1w.y + p2w.y) / 3.0
		var destino_v: PackedVector3Array = v_bajo if centro_y < umbral_y_mundo else v_alto
		var destino_n: PackedVector3Array = n_bajo if centro_y < umbral_y_mundo else n_alto
		var destino_uv: PackedVector2Array = uv_bajo if centro_y < umbral_y_mundo else uv_alto
		for idx: int in [i0, i1, i2]:
			destino_v.append(verts[idx])
			if normales.size() > 0:
				destino_n.append(normales[idx])
			if uvs.size() > 0:
				destino_uv.append(uvs[idx])
		if centro_y < umbral_y_mundo:
			cuenta_bajo += 1
		else:
			cuenta_alto += 1

	var mat: Variant = mi_original.material_override
	if mat == null:
		mat = mi_original.get_active_material(0)

	var malla_bajo := ArrayMesh.new()
	if v_bajo.size() > 0:
		var arr_bajo: Array = []
		arr_bajo.resize(Mesh.ARRAY_MAX)
		arr_bajo[Mesh.ARRAY_VERTEX] = v_bajo
		if n_bajo.size() > 0:
			arr_bajo[Mesh.ARRAY_NORMAL] = n_bajo
		if uv_bajo.size() > 0:
			arr_bajo[Mesh.ARRAY_TEX_UV] = uv_bajo
		malla_bajo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_bajo)
		malla_bajo.surface_set_material(0, mat)

	var malla_alto := ArrayMesh.new()
	if v_alto.size() > 0:
		var arr_alto: Array = []
		arr_alto.resize(Mesh.ARRAY_MAX)
		arr_alto[Mesh.ARRAY_VERTEX] = v_alto
		if n_alto.size() > 0:
			arr_alto[Mesh.ARRAY_NORMAL] = n_alto
		if uv_alto.size() > 0:
			arr_alto[Mesh.ARRAY_TEX_UV] = uv_alto
		malla_alto.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_alto)
		malla_alto.surface_set_material(0, mat)

	return {"bajo": malla_bajo, "alto": malla_alto, "n_bajo": cuenta_bajo, "n_alto": cuenta_alto}


## Monta un conjunto de piezas `[{mi, malla}]` (cada `malla` puede ser la original o un recorte
## de `_cortar_por_altura`, pero SIEMPRE con la `global_transform` de su `mi` original), rota el
## grupo a `ROTACION` alrededor del ancla y renderiza. Mismo patrón que
## `render_mobiliario.gd::_montar_receta`/`_renderizar_bruto`.
func _renderizar_pieza(grupo: Node3D, piezas: Array, ancla: Vector3) -> Dictionary:
	for hijo: Node in grupo.get_children():
		grupo.remove_child(hijo)
		hijo.free()
	for entrada: Dictionary in piezas:
		var mi_original: MeshInstance3D = entrada["mi"]
		var malla: Mesh = entrada["malla"]
		if malla.get_surface_count() == 0:
			continue
		var t: Transform3D = mi_original.global_transform
		var pieza := MeshInstance3D.new()
		pieza.mesh = malla
		pieza.transform = Transform3D(t.basis, t.origin - ancla)
		pieza.material_override = mi_original.material_override
		for s: int in malla.get_surface_count():
			pieza.set_surface_override_material(s, mi_original.get_surface_override_material(s))
		grupo.add_child(pieza)
	grupo.rotation = Vector3(0.0, deg_to_rad(float(ROTACION)), 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cruda: Image = _sub.get_texture().get_image()
	var usado: Rect2i = cruda.get_used_rect()
	var centro := Vector2(TAM_RENDER / 2.0, TAM_RENDER / 2.0)
	if usado.size.x <= 0 or usado.size.y <= 0:
		push_warning("SillaPartida: render vacío")
		return {"imagen": cruda, "ancla": centro}
	var recortada: Image = cruda.get_region(usado)
	var ancla_px: Vector2 = centro - Vector2(usado.position)
	return {"imagen": recortada, "ancla": ancla_px}


## Compara el recorte "silla entera, sin cortar" (`bruto`) contra `silla_espera_270.png` YA
## EXISTENTE (bbox de alfa>0) y devuelve el factor de escala que hace coincidir su ANCHURA -- ver
## la cabecera ("LA CLAVE DEL ENCAJE").
func _calibrar_contra_referencia(bruto: Dictionary) -> float:
	var imagen: Image = bruto["imagen"]
	var referencia: Image = load(REFERENCIA_SILLA_ENTERA).get_image()
	var caja_ref: Rect2i = referencia.get_used_rect()
	var ancho_mio: float = float(imagen.get_width())
	var alto_mio: float = float(imagen.get_height())
	var factor_ancho: float = float(caja_ref.size.x) / ancho_mio
	var factor_alto: float = float(caja_ref.size.y) / alto_mio
	print("[SILLA PARTIDA] mi recorte=%dx%d px | referencia (alfa>0)=%dx%d px | factor_ancho=%.5f factor_alto=%.5f" % [
		imagen.get_width(), imagen.get_height(), caja_ref.size.x, caja_ref.size.y, factor_ancho, factor_alto
	])
	return factor_ancho


## Reescala `bruto` por `factor` y guarda el PNG (sin componer varias rotaciones -- solo hace
## falta la 270, así que el lienzo final ES el recorte ya escalado, sin relleno extra).
## `carpeta`: por defecto `SALIDA` (`assets/sprites/mobiliario/`, los 2 sprites finales); el
## recompuesto de calibración (diagnóstico, NO es un sprite del juego) va a `res://tools/` -- ver
## la llamada en `_ready`, no debe ensuciar la carpeta de mobiliario real.
func _guardar(bruto: Dictionary, factor: float, id_salida: String, carpeta: String = SALIDA) -> void:
	var imagen: Image = bruto["imagen"]
	var ancla: Vector2 = bruto["ancla"]
	var copia: Image = imagen.duplicate()
	var nuevo_ancho: int = maxi(1, roundi(float(imagen.get_width()) * factor))
	var nuevo_alto: int = maxi(1, roundi(float(imagen.get_height()) * factor))
	copia.resize(nuevo_ancho, nuevo_alto, Image.INTERPOLATE_LANCZOS)
	var ancla_final: Vector2 = ancla * factor
	var ruta: String = "%s%s_%d.png" % [carpeta, id_salida, ROTACION]
	copia.save_png(ProjectSettings.globalize_path(ruta))
	print("[SILLA PARTIDA] %s: lienzo %dx%d px, ancla en (%.2f, %.2f) = fracción (%.4f, %.4f) -> %s" % [
		id_salida, nuevo_ancho, nuevo_alto, ancla_final.x, ancla_final.y,
		ancla_final.x / float(nuevo_ancho), ancla_final.y / float(nuevo_alto), ruta
	])
