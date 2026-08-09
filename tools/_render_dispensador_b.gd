extends Node3D
## HERRAMIENTA DE UN SOLO USO (GPU, no headless) — re-renderiza `comodidad_dispensador_agua`
## (OBJ_002/SUB_002_0, `render_mobiliario.gd::ID_DISPENSADOR`: "Object_23","Object_24",
## "Object_25","Object_26","Object_28") al TAMAÑO B elegido por el usuario: ×1.28 sobre su escala
## MUNDO→PÍXEL actual (la misma pieza 3D, más grande en pantalla -- no un simple upscale del PNG:
## se renderiza de nuevo desde el modelo, igual que el resto de esta herramienta, para no perder
## nitidez -- ver la cabecera de `render_mobiliario.gd`, "se renderiza GRANDE y se reduce
## después").
##
## MISMA TÉCNICA que `_render_silla_espera_partida.gd`: el factor exacto NO se recalcula desde
## cero (arriesga desajustarse un pelo del resto del pipeline) -- se CALIBRA EMPÍRICAMENTE contra
## los 4 PNG YA EXISTENTES (misma cámara/ancla que ellos, comparando el ancho de su recorte
## alfa>0), y ENCIMA de ese factor de calibración se aplica el ×1.28 pedido.
##
## Ancla: el ESTÁNDAR de esta herramienta para piezas de una sola pieza (no partidas) -- centro
## X/Z de la AABB conjunta al nivel del SUELO (Y mínimo), la MISMA fórmula que
## `render_mobiliario.gd::_ancla_de` usa para TODAS las recetas de un solo grupo (papelera, radio,
## sofá...). Se imprime también el desplazamiento a la "esquina sur" vía
## `(sx+(Lv−Lu)×20, ys−(Lu+Lv)×10)` -- la fórmula de corrección que usa esta pasada para piezas
## partidas -- para verificar cuánto se separa del centro en este caso (footprint casi cuadrado:
## la diferencia debería ser pequeña).
##
## Escribe SOLO en `assets/sprites/mobiliario/comodidad_dispensador_agua_{0,90,180,270}.png`.
## Herramienta desechable.

const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const SALIDA := "res://assets/sprites/mobiliario/"
const ID_SALIDA := "comodidad_dispensador_agua"
const NOMBRES := ["Object_23", "Object_24", "Object_25", "Object_26", "Object_28"]

const ELEVACION_GRADOS: float = 30.0
const TAM_RENDER: int = 512
const MARGEN: float = 1.15
const ROTACIONES: Array[int] = [0, 90, 180, 270]
const FACTOR_TAMANO_B: float = 1.28

# Proyeccion no está disponible como autoload/class_name fuera del árbol de escena principal del
# juego -- se copian aquí sus dos constantes relevantes (MEDIO_ANCHO/MEDIO_ALTO), documentadas en
# `src/foundation/proyeccion/proyeccion.gd`, para la fórmula de la esquina sur (ver cabecera).
const MEDIO_ANCHO: float = 40.0
const MEDIO_ALTO: float = 20.0
const TAM_CELDA: float = 40.0

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

	var piezas: Array[MeshInstance3D] = []
	for n: String in NOMBRES:
		piezas.append(por_nombre[n])

	var caja := AABB()
	var primera := true
	for mi: MeshInstance3D in piezas:
		var c: AABB = mi.global_transform * mi.mesh.get_aabb()
		caja = c if primera else caja.merge(c)
		primera = false
	var centro: Vector3 = caja.get_center()
	var ancla := Vector3(centro.x, caja.position.y, centro.z)
	var radio := 0.0
	for esquina: Vector3 in _esquinas_de(caja):
		radio = maxf(radio, (esquina - ancla).length())
	var tam_mundo: float = radio * 2.0 * MARGEN
	print("[DISPENSADOR B] ancla=%.4f,%.4f,%.4f | AABB size=%.4f,%.4f,%.4f | radio=%.4f tam_mundo=%.4f" % [
		ancla.x, ancla.y, ancla.z, caja.size.x, caja.size.y, caja.size.z, radio, tam_mundo
	])

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
	for mi: MeshInstance3D in piezas:
		var t: Transform3D = mi.global_transform
		var pieza := MeshInstance3D.new()
		pieza.mesh = mi.mesh
		pieza.transform = Transform3D(t.basis, t.origin - ancla)
		pieza.material_override = mi.material_override
		for s: int in mi.mesh.get_surface_count():
			pieza.set_surface_override_material(s, mi.get_surface_override_material(s))
		grupo.add_child(pieza)

	var brutos: Dictionary = {}
	for rot: int in ROTACIONES:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var cruda: Image = _sub.get_texture().get_image()
		var usado: Rect2i = cruda.get_used_rect()
		var centro_px := Vector2(TAM_RENDER / 2.0, TAM_RENDER / 2.0)
		var recortada: Image = cruda.get_region(usado) if usado.size.x > 0 else cruda
		var ancla_px: Vector2 = centro_px - Vector2(usado.position)
		brutos[rot] = {"imagen": recortada, "ancla": ancla_px}
		print("[DISPENSADOR B] bruto @ %d°: %dx%d px" % [rot, recortada.get_width(), recortada.get_height()])

	# Calibración empírica contra los 4 PNG YA EXISTENTES (ver cabecera) -- promedio de los 4
	# anchos para no depender de una sola rotación.
	var suma_factor := 0.0
	for rot: int in ROTACIONES:
		var existente: Image = load("%s%s_%d.png" % [SALIDA, ID_SALIDA, rot]).get_image()
		var caja_ref: Rect2i = existente.get_used_rect()
		var ancho_mio: float = float((brutos[rot]["imagen"] as Image).get_width())
		var f: float = float(caja_ref.size.x) / ancho_mio
		print("[DISPENSADOR B] calibración @ %d°: mío=%dpx referencia=%dpx factor=%.5f" % [
			rot, int(ancho_mio), caja_ref.size.x, f
		])
		suma_factor += f
	var factor_calibracion: float = suma_factor / float(ROTACIONES.size())
	var factor_final: float = factor_calibracion * FACTOR_TAMANO_B
	print("[DISPENSADOR B] factor calibración medio=%.5f × TAMAÑO_B(%.2f) = factor final %.5f" % [
		factor_calibracion, FACTOR_TAMANO_B, factor_final
	])

	# Reescala y compone las 4 en un lienzo común (mismo patrón que `render_mobiliario.gd::_componer`).
	var escalados: Array[Dictionary] = []
	for rot: int in ROTACIONES:
		escalados.append(_escalar(brutos[rot], factor_final))
	var compuesto: Dictionary = _componer(escalados)
	var imagenes: Array[Image] = compuesto["imagenes"]
	for i: int in ROTACIONES.size():
		var ruta: String = "%s%s_%d.png" % [SALIDA, ID_SALIDA, ROTACIONES[i]]
		(imagenes[i] as Image).save_png(ProjectSettings.globalize_path(ruta))
	var ancla_final: Vector2 = compuesto["ancla"]
	var ancho_final: int = compuesto["ancho"]
	var alto_final: int = compuesto["alto"]
	print("[DISPENSADOR B] lienzo %dx%d px, ancla en (%.2f, %.2f) = fracción (%.4f, %.4f)" % [
		ancho_final, alto_final, ancla_final.x, ancla_final.y,
		ancla_final.x / float(ancho_final), ancla_final.y / float(alto_final)
	])

	# Medida de "pared" (alto de contenido alfa>0) sobre el resultado ya guardado, rotación 0.
	var alto_contenido: int = _alto_contenido(imagenes[0])
	print("[DISPENSADOR B] altura de contenido (alfa>0) @ 0° = %d px (aceptable 39-43)" % alto_contenido)

	# Fórmula de la esquina sur, a título informativo (ver cabecera) -- Lu,Lv = footprint en
	# CELDAS (AABB world size / TAM_CELDA), sx,ys = el ancla ESTÁNDAR ya calculada arriba (fracción
	# * lienzo, en la rotación 0 tras reescalar).
	var lu: float = caja.size.x / TAM_CELDA
	var lv: float = caja.size.z / TAM_CELDA
	var sx: float = ancla_final.x
	var sy: float = ancla_final.y
	var esquina_sur := Vector2(sx + (lv - lu) * 20.0, sy - (lu + lv) * 10.0)
	print("[DISPENSADOR B] (informativo) Lu=%.4f Lv=%.4f | ancla ESTÁNDAR=(%.2f,%.2f) | esquina_sur=(%.2f,%.2f) = fracción (%.4f,%.4f)" % [
		lu, lv, sx, sy, esquina_sur.x, esquina_sur.y,
		esquina_sur.x / float(ancho_final), esquina_sur.y / float(alto_final)
	])

	print("[DISPENSADOR B] hecho.")
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


func _escalar(entrada: Dictionary, factor: float) -> Dictionary:
	var imagen: Image = entrada["imagen"]
	var ancla: Vector2 = entrada["ancla"]
	var copia: Image = imagen.duplicate()
	var nuevo_ancho: int = maxi(1, roundi(float(imagen.get_width()) * factor))
	var nuevo_alto: int = maxi(1, roundi(float(imagen.get_height()) * factor))
	copia.resize(nuevo_ancho, nuevo_alto, Image.INTERPOLATE_LANCZOS)
	return {"imagen": copia, "ancla": ancla * factor}


func _componer(entradas: Array[Dictionary]) -> Dictionary:
	var izq := 0.0
	var derecha := 0.0
	var arriba := 0.0
	var abajo := 0.0
	for e: Dictionary in entradas:
		var imagen: Image = e["imagen"]
		var ancla: Vector2 = e["ancla"]
		izq = maxf(izq, ancla.x)
		arriba = maxf(arriba, ancla.y)
		derecha = maxf(derecha, float(imagen.get_width()) - ancla.x)
		abajo = maxf(abajo, float(imagen.get_height()) - ancla.y)
	var ancho: int = maxi(1, ceili(izq + derecha))
	var alto: int = maxi(1, ceili(arriba + abajo))
	var ancla_final := Vector2(izq, arriba)
	var lienzos: Array[Image] = []
	for e: Dictionary in entradas:
		var imagen: Image = e["imagen"]
		var ancla: Vector2 = e["ancla"]
		var lienzo := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
		var destino := Vector2i(roundi(ancla_final.x - ancla.x), roundi(ancla_final.y - ancla.y))
		lienzo.blit_rect(imagen, Rect2i(Vector2i.ZERO, imagen.get_size()), destino)
		lienzos.append(lienzo)
	return {"imagenes": lienzos, "ancho": ancho, "alto": alto, "ancla": ancla_final}


func _alto_contenido(imagen: Image) -> int:
	var usado: Rect2i = imagen.get_used_rect()
	return usado.size.y
