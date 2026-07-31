extends Node3D
## Catálogo visual del pack de mobiliario `isometric_office.glb`.
##
## El GLB trae ~748 `MeshInstance3D` con nombres genéricos (`Object_042`…). Esta herramienta no
## sirve para el juego: sirve para que una PERSONA reconozca a ojo qué es cada malla ("esta es la
## mesa, esta la silla") antes de decidir qué piezas usar y cómo montarlas.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderCatalogoOficina.tscn
##
## No headless: renderizar necesita GPU. Abre una ventana un rato (son cientas de mallas) y se
## cierra sola con `get_tree().quit()`. Escribe en `res://capturas/NPC/Oficina/catalogo/`:
##   · `NNNN_NombreDelNodo.png` — una miniatura por MALLA ÚNICA (128 px de lado mayor).
##   · `catalogo_manifest.json` — datos crudos de las ~748 INSTANCIAS (nombre, padres, malla,
##     posición y AABB), pensado para reconstruir después muebles hechos de varias piezas vecinas.
##   · `index.html` — hoja de contactos para mirar en el navegador.
##
## ── LOS MISMOS PATRONES QUE `render_sprites.gd` ────────────────────────────────────────────────
## SubViewport transparente, cámara ORTOGRÁFICA a 26,565° (= `atan(1/2)`, el rombo 2:1 del juego)
## y 45° de acimut, dos `await RenderingServer.frame_post_draw` antes de capturar, recorte del aire
## transparente y reescalado con LANCZOS desde un render grande. Ver ese archivo para el porqué de
## cada número; aquí solo cambia QUÉ se pone delante de la cámara: una pieza de mobiliario sola en
## vez de un personaje animado.
##
## ── DEDUPLICACIÓN ──────────────────────────────────────────────────────────────────────────────
## Muchas piezas se repiten (sillas, plantas…) porque el GLB reutiliza el mismo recurso `Mesh` en
## varios nodos. Se agrupan por IDENTIDAD del recurso (`Mesh.get_instance_id()`) — no por nombre,
## que aquí no significa nada — y de cada grupo solo se renderiza la PRIMERA instancia encontrada,
## con su rotación/escala (para que la miniatura se vea como aparece en la escena) pero sin su
## traslación (para que quede centrada en el render).

## Dónde está el modelo de origen y dónde sale el catálogo.
const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
const SALIDA := "res://capturas/NPC/Oficina/catalogo/"

## Mismo ángulo que `render_sprites.gd`: `atan(0.5)` en grados, el que encaja con el rombo 2:1.
const ELEVACION_GRADOS: float = 26.565
## Se renderiza grande y se reduce después (conserva mejor el detalle que renderizar pequeño).
const TAM_RENDER: int = 256
## Lado MAYOR del PNG final, ya recortado el aire transparente.
const TAM_FINAL: int = 128
## Aire alrededor de la pieza en el encuadre: 10 %.
const MARGEN: float = 1.10

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("RenderCatalogoOficina: no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return

	# Árbol de SOLO DATOS: para leer nombres, jerarquía, mallas y transformadas. No se ve ni se
	# renderiza — vive fuera del SubViewport.
	var contenedor := Node3D.new()
	add_child(contenedor)
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	# Este árbol es SOLO DATOS (nombres, jerarquía, transformadas, mallas) — nunca debería
	# aparecer en ningún render. Se apaga por si acaso (ver el porqué real dos líneas más abajo).
	contenedor.visible = false

	var instancias: Array[Dictionary] = _recolectar_instancias(modelo, contenedor)
	var mallas_unicas: Array[Dictionary] = _deduplicar(instancias)
	print("[CATALOGO] %d instancias, %d mallas únicas" % [instancias.size(), mallas_unicas.size()])

	# SubViewport para renderizar UNA pieza a la vez, con fondo transparente (igual que el hermano).
	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# ⚠️ AISLAMIENTO REAL: por defecto un SubViewport COMPARTE el `World3D` (el "mundo" de
	# renderizado 3D) de su padre — `own_world_3d` es `false` de fábrica. Sin esta línea, la
	# oficina ENTERA que se instancia arriba (`contenedor`, las ~748 mallas, solo para leer datos)
	# se registra en ESE MISMO mundo compartido y la cámara de aquí dentro la ve también, aunque
	# `contenedor` no sea su padre ni esté "dentro" de este SubViewport. Por eso los primeros
	# renders salían con pared, pilar y suelo de fondo detrás de piezas diminutas: no eran restos
	# de la malla anterior sin liberar — era la oficina real de fondo, colándose por el mundo
	# compartido. El hermano (`render_sprites.gd`) nunca lo sufrió porque no mete NADA más en el
	# árbol del visor principal; aquí sí, así que aquí hace falta pedir un mundo propio.
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

	var pieza := MeshInstance3D.new()
	mundo.add_child(pieza)

	# Fire-and-forget: esta corrutina hace TODO (renderiza, escribe manifest y HTML, y llama a
	# `get_tree().quit()` al final) para garantizar el orden — igual que `_renderizar_todas()` en
	# el hermano.
	_ejecutar(instancias, mallas_unicas, pieza)


## Cadena de nombres desde la raíz del modelo (`modelo`) hasta el padre inmediato de `nodo`, sin
## incluir el `contenedor` que montamos aquí (que no significa nada del contenido).
func _padres_de(nodo: Node, contenedor: Node) -> Array[String]:
	var cadena: Array[String] = []
	var actual: Node = nodo.get_parent()
	while actual != null and actual != contenedor:
		cadena.push_front(String(actual.name))
		actual = actual.get_parent()
	return cadena


## Recorre el árbol y registra, por cada `MeshInstance3D`, lo que hace falta para deduplicar,
## renderizar y documentar: nombre, cadena de padres, la malla, su transformada global y su AABB
## en el mundo (posición real dentro de la oficina, sin centrar).
func _recolectar_instancias(modelo: Node3D, contenedor: Node) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		var malla: Mesh = mi.mesh
		var caja := AABB()
		var overrides: Array[Material] = []
		if malla != null:
			caja = mi.global_transform * malla.get_aabb()
			for s: int in malla.get_surface_count():
				overrides.append(mi.get_surface_override_material(s))
		lista.append({
			"nombre": String(mi.name),
			"padres": _padres_de(mi, contenedor),
			"malla": malla,
			"transform": mi.global_transform,
			"aabb": caja,
			"material_override": mi.material_override,
			"overrides": overrides,
		})
	return lista


## Agrupa las instancias por IDENTIDAD de su recurso `Mesh`. Cada grupo se queda con los datos de
## la PRIMERA instancia encontrada (nombre, orientación, materiales) — es la que se renderiza.
func _deduplicar(instancias: Array[Dictionary]) -> Array[Dictionary]:
	var mallas_unicas: Array[Dictionary] = []
	var indice_por_id: Dictionary = {}
	for i: int in instancias.size():
		var entrada: Dictionary = instancias[i]
		var malla: Mesh = entrada["malla"]
		if malla == null:
			entrada["malla_indice"] = -1
			continue
		var id: int = malla.get_instance_id()
		if not indice_por_id.has(id):
			indice_por_id[id] = mallas_unicas.size()
			mallas_unicas.append({
				"malla": malla,
				"nombre": entrada["nombre"],
				"transform_base": entrada["transform"],
				"material_override": entrada["material_override"],
				"overrides": entrada["overrides"],
				"conteo": 0,
				"indices_instancias": [] as Array[int],
			})
		var idx: int = indice_por_id[id]
		entrada["malla_indice"] = idx
		mallas_unicas[idx]["conteo"] += 1
		(mallas_unicas[idx]["indices_instancias"] as Array[int]).append(i)
	return mallas_unicas


## Renderiza el catálogo entero, escribe manifest + HTML y cierra. Todo en una corrutina para que
## el orden quede garantizado: nada se escribe hasta que el último PNG está guardado.
func _ejecutar(
	instancias: Array[Dictionary], mallas_unicas: Array[Dictionary], pieza: MeshInstance3D
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))

	var anomalias_render_vacio: Array[int] = []
	var anomalias_sin_superficies: Array[int] = []

	for i: int in mallas_unicas.size():
		var entrada: Dictionary = mallas_unicas[i]
		var malla: Mesh = entrada["malla"]
		var base: Basis = (entrada["transform_base"] as Transform3D).basis

		pieza.mesh = malla
		pieza.material_override = entrada.get("material_override")
		var overrides: Array = entrada.get("overrides", [])
		var num_superficies: int = malla.get_surface_count()
		if num_superficies == 0:
			anomalias_sin_superficies.append(i)
		for s: int in num_superficies:
			pieza.set_surface_override_material(s, overrides[s] if s < overrides.size() else null)

		# La caja SIN trasladar (con la rotación/escala de la primera instancia aplicada) y su
		# centro: la pieza se desplaza ese centro al revés para quedar en el origen.
		var caja_mesh: AABB = malla.get_aabb()
		var caja_sin_centrar: AABB = Transform3D(base, Vector3.ZERO) * caja_mesh
		var centro: Vector3 = caja_sin_centrar.get_center()
		pieza.transform = Transform3D(base, -centro)
		var caja_centrada := AABB(caja_sin_centrar.position - centro, caja_sin_centrar.size)

		_encuadrar_pieza(caja_centrada)
		# Dos frames de espera: uno para que se apliquen malla/transformada/cámara, otro para que
		# el SubViewport ya lo haya dibujado. Con uno solo sale la pieza o el encuadre anterior.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var cruda: Image = _sub.get_texture().get_image()
		var usado: Rect2i = cruda.get_used_rect()
		if usado.size.x <= 0 or usado.size.y <= 0:
			anomalias_render_vacio.append(i)
		var imagen: Image = _recortar(cruda)
		var nombre_archivo: String = "%04d_%s.png" % [i, _sanear(entrada["nombre"])]
		_guardar_128(imagen, SALIDA + nombre_archivo)

		entrada["archivo"] = nombre_archivo
		entrada["tamano"] = caja_centrada.size

		if (i + 1) % 25 == 0 or i == mallas_unicas.size() - 1:
			print("[CATALOGO] %d/%d mallas renderizadas" % [i + 1, mallas_unicas.size()])

	var anomalias_sin_malla: Array[int] = []
	for i: int in instancias.size():
		if instancias[i]["malla"] == null:
			anomalias_sin_malla.append(i)

	var anomalias := {
		"instancias_sin_malla": anomalias_sin_malla,
		"mallas_sin_superficies": anomalias_sin_superficies,
		"mallas_render_vacio": anomalias_render_vacio,
	}
	print("[CATALOGO] anomalías -> sin malla: %d | sin superficies: %d | render vacío: %d" % [
		anomalias_sin_malla.size(), anomalias_sin_superficies.size(), anomalias_render_vacio.size()
	])
	if not anomalias_sin_malla.is_empty():
		print("[CATALOGO] instancias sin malla (índices): %s" % [anomalias_sin_malla])
	if not anomalias_sin_superficies.is_empty():
		print("[CATALOGO] mallas sin superficies (índices de malla única): %s" % [
			anomalias_sin_superficies
		])
	if not anomalias_render_vacio.is_empty():
		print("[CATALOGO] mallas con render vacío (índices de malla única): %s" % [
			anomalias_render_vacio
		])

	_escribir_manifest(instancias, mallas_unicas, anomalias)
	_escribir_html(mallas_unicas, instancias.size())
	print("[CATALOGO] hecho: %d PNG + manifest + index.html en %s" % [mallas_unicas.size(), SALIDA])
	get_tree().quit()


## Coloca la cámara en el ángulo isométrico del juego y ajusta el tamaño ortográfico a lo que
## OCUPA REALMENTE la pieza vista desde ahí — no al lado mayor de su caja en el mundo. Un mueble
## alargado (una mesa larga, una estantería) visto en diagonal puede proyectar más que cualquiera
## de sus ejes por separado, así que se proyectan las 8 esquinas de la caja sobre los ejes de la
## cámara (derecha/arriba) y se usa esa medida.
func _encuadrar_pieza(caja: AABB) -> void:
	var centro: Vector3 = caja.get_center()
	var radio: float = caja.size.length()
	var yaw: float = deg_to_rad(45.0)
	var pitch: float = deg_to_rad(ELEVACION_GRADOS)
	var distancia: float = maxf(radio, 0.01) * 3.0
	_camara.position = centro + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)
	) * distancia
	_camara.look_at(centro, Vector3.UP)

	var vista: Transform3D = _camara.global_transform.affine_inverse()
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for esquina: Vector3 in _esquinas_de(caja):
		var local: Vector3 = vista * esquina
		minimo.x = minf(minimo.x, local.x)
		minimo.y = minf(minimo.y, local.y)
		maximo.x = maxf(maximo.x, local.x)
		maximo.y = maxf(maximo.y, local.y)
	var ancho: float = maximo.x - minimo.x
	var alto: float = maximo.y - minimo.y
	_camara.size = maxf(maxf(ancho, alto) * MARGEN, 0.05)


## Las 8 esquinas de una AABB, calculadas a mano (sin depender de un nombre de método concreto).
func _esquinas_de(caja: AABB) -> Array[Vector3]:
	var esquinas: Array[Vector3] = []
	var p: Vector3 = caja.position
	var s: Vector3 = caja.size
	for i: int in 8:
		esquinas.append(Vector3(
			p.x + s.x * float(i & 1),
			p.y + s.y * float((i >> 1) & 1),
			p.z + s.z * float((i >> 2) & 1)
		))
	return esquinas


## Quita el aire transparente de alrededor (igual que `render_sprites.gd`).
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)


## Reduce al lado mayor pedido (LANCZOS, desde el render grande) y guarda el PNG.
func _guardar_128(imagen: Image, ruta_res: String) -> void:
	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var mayor: int = maxi(ancho, alto)
	var escala: float = float(TAM_FINAL) / float(maxi(mayor, 1))
	var copia: Image = imagen.duplicate()
	copia.resize(
		maxi(1, roundi(float(ancho) * escala)),
		maxi(1, roundi(float(alto) * escala)),
		Image.INTERPOLATE_LANCZOS
	)
	copia.save_png(ProjectSettings.globalize_path(ruta_res))


## Nombre de archivo seguro: fuera los caracteres que Windows no admite en rutas.
func _sanear(nombre: String) -> String:
	var limpio: String = nombre
	for c: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		limpio = limpio.replace(c, "_")
	return limpio


## Escapa lo mínimo para meter texto arbitrario dentro de HTML sin romper la etiqueta.
func _escapar_html(texto: String) -> String:
	return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


## Escribe `catalogo_manifest.json`: una entrada por cada una de las ~748 INSTANCIAS (nombre,
## padres, a qué malla única apunta, posición global, base de rotación/escala y AABB en el
## mundo) más el catálogo de mallas únicas. Pensado para reconstruir después muebles hechos de
## varias piezas vecinas, cruzando posiciones.
func _escribir_manifest(
	instancias: Array[Dictionary], mallas_unicas: Array[Dictionary], anomalias: Dictionary
) -> void:
	var lista_instancias: Array = []
	for i: int in instancias.size():
		var it: Dictionary = instancias[i]
		var t: Transform3D = it["transform"]
		var caja: AABB = it["aabb"]
		lista_instancias.append({
			"indice": i,
			"nombre": it["nombre"],
			"padres": it["padres"],
			"malla_indice": it.get("malla_indice", -1),
			"posicion_global": [t.origin.x, t.origin.y, t.origin.z],
			"base": {
				"x": [t.basis.x.x, t.basis.x.y, t.basis.x.z],
				"y": [t.basis.y.x, t.basis.y.y, t.basis.y.z],
				"z": [t.basis.z.x, t.basis.z.y, t.basis.z.z],
			},
			"aabb": {
				"posicion": [caja.position.x, caja.position.y, caja.position.z],
				"tamano": [caja.size.x, caja.size.y, caja.size.z],
			},
		})

	var lista_mallas: Array = []
	for i: int in mallas_unicas.size():
		var m: Dictionary = mallas_unicas[i]
		var tam: Vector3 = m.get("tamano", Vector3.ZERO)
		lista_mallas.append({
			"indice": i,
			"archivo": m.get("archivo", ""),
			"nombre_primera_instancia": m["nombre"],
			"conteo": m["conteo"],
			"indices_instancias": m["indices_instancias"],
			"tamano": [tam.x, tam.y, tam.z],
		})

	var datos := {
		"generado": Time.get_datetime_string_from_system(),
		"modelo_origen": MODELO,
		"total_instancias": instancias.size(),
		"total_mallas_unicas": mallas_unicas.size(),
		"anomalias": anomalias,
		"instancias": lista_instancias,
		"mallas_unicas": lista_mallas,
	}

	var ruta: String = ProjectSettings.globalize_path(SALIDA + "catalogo_manifest.json")
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("RenderCatalogoOficina: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()


## Escribe `index.html`: la hoja de contactos, ordenada por huella (x·z) descendente.
func _escribir_html(mallas_unicas: Array[Dictionary], total_instancias: int) -> void:
	var orden: Array[Dictionary] = mallas_unicas.duplicate()
	orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Vector3 = a.get("tamano", Vector3.ZERO)
		var tb: Vector3 = b.get("tamano", Vector3.ZERO)
		return (ta.x * ta.z) > (tb.x * tb.z)
	)

	var celdas: PackedStringArray = []
	for entrada: Dictionary in orden:
		var tam: Vector3 = entrada.get("tamano", Vector3.ZERO)
		var nombre: String = _escapar_html(entrada["nombre"])
		var etiqueta_conteo: String = ""
		if int(entrada["conteo"]) > 1:
			etiqueta_conteo = " <span class=\"conteo\">×%d</span>" % int(entrada["conteo"])
		var celda: String = (
			"<div class=\"celda\">"
			+ "<div class=\"miniatura\"><img src=\"%s\" alt=\"%s\" loading=\"lazy\"></div>" % [
				_escapar_html(String(entrada.get("archivo", ""))), nombre
			]
			+ "<div class=\"nombre\">%s%s</div>" % [nombre, etiqueta_conteo]
			+ "<div class=\"dimensiones\">%.2f × %.2f × %.2f</div>" % [tam.x, tam.y, tam.z]
			+ "</div>"
		)
		celdas.append(celda)

	var css: PackedStringArray = [
		"body{font-family:sans-serif;background:#222;color:#eee;margin:0;padding:24px;}",
		"h1{font-size:20px;margin:0 0 4px 0;}",
		".resumen{color:#aaa;margin:0 0 20px 0;}",
		".rejilla{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:12px;}",
		".celda{background:#333;border-radius:6px;padding:8px;text-align:center;}",
		(
			".miniatura{height:128px;display:flex;align-items:center;justify-content:center;"
			+ "border-radius:4px;background-color:#ddd;"
			+ "background-image:linear-gradient(45deg,#bbb 25%,transparent 25%),"
			+ "linear-gradient(-45deg,#bbb 25%,transparent 25%),"
			+ "linear-gradient(45deg,transparent 75%,#bbb 75%),"
			+ "linear-gradient(-45deg,transparent 75%,#bbb 75%);"
			+ "background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0;}"
		),
		".miniatura img{max-width:128px;max-height:128px;}",
		".nombre{font-size:12px;margin-top:6px;word-break:break-all;}",
		".conteo{color:#7fd0ff;font-weight:bold;}",
		".dimensiones{font-size:11px;color:#999;margin-top:2px;}",
	]

	var html: String = (
		"<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"
		+ "<title>Catálogo — mobiliario de oficina</title><style>"
		+ "\n".join(css) + "</style></head><body>"
		+ "<h1>Catálogo de mobiliario — Oficina</h1>"
		+ "<p class=\"resumen\">%d mallas únicas de %d instancias totales.</p>" % [
			mallas_unicas.size(), total_instancias
		]
		+ "<div class=\"rejilla\">" + "".join(celdas) + "</div>"
		+ "</body></html>"
	)

	var ruta: String = ProjectSettings.globalize_path(SALIDA + "index.html")
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("RenderCatalogoOficina: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(html)
	archivo.close()
