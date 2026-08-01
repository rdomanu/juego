extends Node3D
## Catálogo de OBJETOS ENSAMBLADOS del pack `isometric_office.glb` — v2 de `render_catalogo_oficina.gd`.
##
## El catálogo v1 (`render_catalogo_oficina.gd`) renderiza cada `MeshInstance3D` por separado, y
## en este pack los muebles vienen DESPIEZADOS: una silla es ruedas + asiento + respaldo +
## reposabrazos, cada uno su propio nodo. Mirando el catálogo v1 no se reconoce "la silla" — se
## ven sus piezas sueltas. Esta v2 los vuelve a juntar SIN TOCAR v1: agrupa por PROXIMIDAD
## ESPACIAL (qué piezas se tocan en la escena original) y renderiza cada grupo entero, en su
## postura y colocación original, como una miniatura.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderCatalogoObjetos.tscn
##
## No headless (GPU). Escribe en `res://capturas/NPC/Oficina/catalogo/`:
##   · `objetos/OBJ_NNN.png` — un cluster de mobiliario ensamblado (128 px de lado mayor).
##   · `objetos/ARQ_NNN.png` — piezas de ARQUITECTURA (paredes, suelos…), renderizadas SOLAS,
##     igual que en v1 — se excluyen del ensamblado a propósito (ver más abajo el porqué).
##   · `index_objetos.html` — hoja de contactos: clusters primero, arquitectura al final.
##   · `catalogo_objetos_manifest.json` — qué instancias componen cada cluster.
##
## ── POR QUÉ SE EXCLUYE LA ARQUITECTURA DEL AGRUPADO ────────────────────────────────────────────
## Agrupar "lo que se toca" funciona de maravilla para muebles… y fatal para una pared: una pared
## TOCA todo lo que se apoya en ella. Sin excluirlas, un solo cluster se comería media sala (la
## pared engancha la mesa, la mesa engancha la silla de al lado, esa silla engancha la papelera…).
## La regla (pedida así, literal): cualquier malla cuyo AABB en el mundo mida, en su lado MÁS
## LARGO, por encima de `UMBRAL_ARQUITECTURA` metros, se trata aparte y se renderiza SOLA — igual
## que v1 — en vez de dejarla participar en el agrupado. El valor se calibró mirando la
## distribución real de tamaños de este pack (ver el comentario junto a la constante).
##
## ── CÓMO SE AGRUPA ─────────────────────────────────────────────────────────────────────────────
## Componentes conexas de un grafo: dos piezas de mobiliario quedan en el mismo grupo si sus AABB
## en el mundo, INFLADAS cada una un PORCENTAJE de su propia diagonal (`EPSILON_PROPORCION`; para
## que dos piezas que se tocan por los pelos — la unión asiento/respaldo de una silla real casi
## nunca es perfecta — sí se enganchen), se solapan. Es una unión-búsqueda (union-find) sobre
## ~700 piezas: O(n²) comparaciones de AABB, que a este tamaño es instantáneo — no hace falta
## ninguna estructura espacial más lista.
##
## ── CALIBRACIÓN RÁPIDA: `SOLO_ANALIZAR` ────────────────────────────────────────────────────────
## Agrupar y comprobar el histograma de tamaños es barato (milisegundos); renderizar 250+ PNG no
## lo es (minutos). Con `SOLO_ANALIZAR = true` la herramienta agrupa, IMPRIME el histograma y
## cierra sin renderizar nada — así se puede tocar `UMBRAL_ARQUITECTURA` / `EPSILON_PROPORCION` y
## reintentar en segundos hasta que el reparto tenga sentido (decenas de clusters, no un
## mega-cluster que se come media sala, no 700 clusters de una pieza).
const SOLO_ANALIZAR: bool = false

## Mismo modelo de origen que v1.
const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
## Los PNG de esta herramienta van en su propia subcarpeta; el HTML y el manifest, junto a los
## de v1 (mismo nivel que `index.html` / `catalogo_manifest.json`).
const SALIDA := "res://capturas/NPC/Oficina/catalogo/objetos/"
const SALIDA_RAIZ := "res://capturas/NPC/Oficina/catalogo/"

## Mismos patrones que v1 (y que `render_sprites.gd`): ángulo isométrico del juego, render grande
## reducido con LANCZOS, 10 % de margen.
const ELEVACION_GRADOS: float = 26.565
const TAM_RENDER: int = 256
const TAM_FINAL: int = 128
const MARGEN: float = 1.10

## ── LOS DOS NÚMEROS QUE HAY QUE CALIBRAR ───────────────────────────────────────────────────────
## `UMBRAL_ARQUITECTURA`: la distribución real (748 instancias, ver informe) tiene el 96 % de las
## piezas por debajo de 1,8 m de lado mayor, y a partir de ahí aparece un grupo bien diferenciado
## de paneles modulares de pared (~0,9×1,8 m, con medidas EXACTAS repetidas una docena de veces —
## sin duda piezas de un mismo molde de pared, no muebles) y, más arriba, tres mallas de ~10×10 m
## que son el suelo/paredes/techo de la sala entera. 1,8 m corta justo antes de ese grupo modular.
## Efecto secundario conocido: algún mueble grande de verdad (p. ej. un módulo de escritorio con
## cajonera, ~2,1 m) cae también del lado de "arquitectura". No se pierde — sale igualmente en su
## propia miniatura, solo que en la sección de abajo en vez de entre los muebles. Se documenta en
## el informe, no se pretende una separación perfecta con un solo número.
const UMBRAL_ARQUITECTURA: float = 1.8

## `EPSILON_PROPORCION`: inflado PROPORCIONAL a la diagonal de CADA pieza (no una cantidad fija).
## Un epsilon fijo resultó ser el problema, no la solución: con 0,05 m, 0,02 m e incluso 0,005 m
## el cluster más grande se quedó CLAVADO en 73 piezas — no era un margen mal calibrado, eran
## filas de mobiliario realmente tocándose (mesas en batería, etc.) que ningún epsilon fijo
## separa sin también despedazar sillas pequeñas. Proporcional sí distingue: una rueda diminuta
## se pega a su silla con un margen minúsculo, una mesa grande no llega a alcanzar a la vecina.
const EPSILON_PROPORCION: float = 0.03

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("RenderCatalogoObjetos: no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return

	var contenedor := Node3D.new()
	add_child(contenedor)
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	# Solo datos: nunca debe aparecer en un render (ver la lección de v1 sobre `own_world_3d`
	# más abajo — esto es cinturón, aquello es el cinturón Y los tirantes).
	contenedor.visible = false

	var nulas: int = 0
	var instancias: Array[Dictionary] = []
	for hijo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi.mesh == null:
			nulas += 1
			continue
		var malla: Mesh = mi.mesh
		var t: Transform3D = mi.global_transform
		var caja: AABB = t * malla.get_aabb()
		var overrides: Array[Material] = []
		for s: int in malla.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		instancias.append({
			"nombre": String(mi.name),
			"malla": malla,
			"transform": t,
			"aabb": caja,
			"lado_mayor": maxf(caja.size.x, maxf(caja.size.y, caja.size.z)),
			"material_override": mi.material_override,
			"overrides": overrides,
		})
	if nulas > 0:
		print("[OBJETOS] aviso: %d instancias sin malla, ignoradas" % nulas)

	var caja_escena := AABB()
	var primera := true
	for it: Dictionary in instancias:
		var c: AABB = it["aabb"]
		caja_escena = c if primera else caja_escena.merge(c)
		primera = false
	print("[OBJETOS] escena completa: %.2f x %.2f x %.2f m (centro %.2f, %.2f, %.2f)" % [
		caja_escena.size.x, caja_escena.size.y, caja_escena.size.z,
		caja_escena.get_center().x, caja_escena.get_center().y, caja_escena.get_center().z
	])

	var arquitectura: Array[Dictionary] = []
	var mobiliario: Array[Dictionary] = []
	for it: Dictionary in instancias:
		if float(it["lado_mayor"]) >= UMBRAL_ARQUITECTURA:
			arquitectura.append(it)
		else:
			mobiliario.append(it)
	print("[OBJETOS] %d instancias -> %d arquitectura (lado mayor >= %.2f m) | %d mobiliario" % [
		instancias.size(), arquitectura.size(), UMBRAL_ARQUITECTURA, mobiliario.size()
	])

	var clusters: Array = _agrupar(mobiliario, EPSILON_PROPORCION)
	_imprimir_histograma(clusters, mobiliario.size())

	if SOLO_ANALIZAR:
		print(
			"[OBJETOS] SOLO_ANALIZAR=true -> no se renderiza nada. Ajusta UMBRAL_ARQUITECTURA / "
			+ "EPSILON_PROPORCION arriba y vuelve a ejecutar."
		)
		get_tree().quit()
		return

	# SubViewport aislado: MISMA lección aprendida en v1. Por defecto comparte el `World3D` del
	# padre, y `contenedor` (la oficina entera, solo para datos) se colaría en cada captura.
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

	# Contenedor REUTILIZABLE de piezas: se vacía a mano (remove_child + free, sin `queue_free`,
	# para que no quede NINGUNA duda de timing) antes de montar cada pieza u objeto siguiente.
	var grupo := Node3D.new()
	mundo.add_child(grupo)

	_ejecutar(arquitectura, clusters, grupo)


## Une por proximidad: dos piezas de `mobiliario` quedan en el mismo grupo si sus AABB, cada una
## inflada un PORCENTAJE de su PROPIA diagonal (no una cantidad fija — ver el porqué junto a
## `EPSILON_PROPORCION`), se solapan. Devuelve una lista de grupos; cada grupo es un
## `Array[Dictionary]` con las instancias que lo componen.
func _agrupar(mobiliario: Array[Dictionary], proporcion: float) -> Array:
	var n: int = mobiliario.size()
	var padre: Array[int] = []
	var infladas: Array[AABB] = []
	for i: int in n:
		padre.append(i)
		var caja: AABB = mobiliario[i]["aabb"]
		infladas.append(caja.grow(caja.size.length() * proporcion))
	for i: int in n:
		for j: int in range(i + 1, n):
			if infladas[i].intersects(infladas[j]):
				_unir(padre, i, j)
	var grupos: Dictionary = {}
	for i: int in n:
		var raiz: int = _buscar(padre, i)
		if not grupos.has(raiz):
			grupos[raiz] = [] as Array[int]
		(grupos[raiz] as Array[int]).append(i)
	var resultado: Array = []
	for clave: int in grupos.keys():
		var miembros: Array[int] = grupos[clave]
		var grupo_dicts: Array[Dictionary] = []
		for idx: int in miembros:
			grupo_dicts.append(mobiliario[idx])
		resultado.append(grupo_dicts)
	return resultado


## `find` con compresión de camino.
func _buscar(padre: Array[int], x: int) -> int:
	var raiz: int = x
	while padre[raiz] != raiz:
		raiz = padre[raiz]
	var actual: int = x
	while padre[actual] != raiz:
		var siguiente: int = padre[actual]
		padre[actual] = raiz
		actual = siguiente
	return raiz


## `union` simple (sin rango — a este tamaño no hace falta optimizar más).
func _unir(padre: Array[int], a: int, b: int) -> void:
	var ra: int = _buscar(padre, a)
	var rb: int = _buscar(padre, b)
	if ra != rb:
		padre[ra] = rb


## El histograma que decide si `UMBRAL_ARQUITECTURA` / `EPSILON_PROPORCION` están bien puestos.
func _imprimir_histograma(clusters: Array, total_piezas: int) -> void:
	var tamanos: Array[int] = []
	for c: Array in clusters:
		tamanos.append(c.size())
	tamanos.sort()
	var n: int = tamanos.size()
	print("[OBJETOS] %d clusters de mobiliario (de %d piezas no-arquitectura)" % [n, total_piezas])
	if n == 0:
		return
	var b1 := 0
	var b2 := 0
	var b3 := 0
	var b4 := 0
	var b5 := 0
	var b6 := 0
	for t: int in tamanos:
		if t == 1:
			b1 += 1
		elif t <= 3:
			b2 += 1
		elif t <= 7:
			b3 += 1
		elif t <= 15:
			b4 += 1
		elif t <= 31:
			b5 += 1
		else:
			b6 += 1
	print("[OBJETOS] histograma -> =1: %d | 2-3: %d | 4-7: %d | 8-15: %d | 16-31: %d | >=32: %d" % [
		b1, b2, b3, b4, b5, b6
	])
	var mediana: float
	if n % 2 == 1:
		mediana = float(tamanos[n / 2])
	else:
		mediana = float(tamanos[n / 2 - 1] + tamanos[n / 2]) / 2.0
	print("[OBJETOS] mediana: %.1f piezas/cluster | mayor: %d piezas | menor: %d piezas" % [
		mediana, tamanos[n - 1], tamanos[0]
	])


## Vacía el contenedor de piezas de forma SÍNCRONA (sin `queue_free`) antes de montar el
## siguiente objeto — nada de la captura anterior debe seguir vivo en el frame que viene.
func _limpiar_grupo(grupo: Node3D) -> void:
	for hijo: Node in grupo.get_children():
		grupo.remove_child(hijo)
		hijo.free()


## Añade una malla al `grupo`, con su transformada y sus materiales (override + por superficie).
func _montar_pieza(
	grupo: Node3D, malla: Mesh, transformada: Transform3D, material_override: Variant, overrides: Array
) -> void:
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.transform = transformada
	pieza.material_override = material_override
	for s: int in malla.get_surface_count():
		pieza.set_surface_override_material(s, overrides[s] if s < overrides.size() else null)
	grupo.add_child(pieza)


## Renderiza UNA pieza sola (arquitectura), con su base (rotación/escala) pero sin traslación,
## centrada en el origen — igual patrón que v1.
func _renderizar_una(it: Dictionary, grupo: Node3D) -> Dictionary:
	_limpiar_grupo(grupo)
	var malla: Mesh = it["malla"]
	var base: Basis = (it["transform"] as Transform3D).basis
	var caja_mesh: AABB = malla.get_aabb()
	var caja_sin_centrar: AABB = Transform3D(base, Vector3.ZERO) * caja_mesh
	var centro: Vector3 = caja_sin_centrar.get_center()
	_montar_pieza(
		grupo, malla, Transform3D(base, -centro), it.get("material_override"), it.get("overrides", [])
	)
	var caja_centrada := AABB(caja_sin_centrar.position - centro, caja_sin_centrar.size)
	_encuadrar_pieza(caja_centrada)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cruda: Image = _sub.get_texture().get_image()
	var usado: Rect2i = cruda.get_used_rect()
	var vacio: bool = usado.size.x <= 0 or usado.size.y <= 0
	return {"imagen": _recortar(cruda), "tamano": caja_centrada.size, "vacio": vacio}


## Renderiza un CLUSTER entero: todas sus piezas, con sus transformadas RELATIVAS ENTRE SÍ
## intactas (solo se desplaza el conjunto para que su centro caiga en el origen) — así el mueble
## sale tal y como estaba montado en la escena original.
func _renderizar_cluster(miembros: Array[Dictionary], grupo: Node3D) -> Dictionary:
	_limpiar_grupo(grupo)
	var caja := AABB()
	var primera := true
	for it: Dictionary in miembros:
		var t: Transform3D = it["transform"]
		var malla: Mesh = it["malla"]
		var caja_mundo: AABB = t * malla.get_aabb()
		caja = caja_mundo if primera else caja.merge(caja_mundo)
		primera = false
	var centro: Vector3 = caja.get_center()
	for it: Dictionary in miembros:
		var t: Transform3D = it["transform"]
		var malla: Mesh = it["malla"]
		_montar_pieza(
			grupo, malla, Transform3D(t.basis, t.origin - centro),
			it.get("material_override"), it.get("overrides", [])
		)
	var caja_centrada := AABB(caja.position - centro, caja.size)
	_encuadrar_pieza(caja_centrada)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cruda: Image = _sub.get_texture().get_image()
	var usado: Rect2i = cruda.get_used_rect()
	var vacio: bool = usado.size.x <= 0 or usado.size.y <= 0
	return {"imagen": _recortar(cruda), "tamano": caja_centrada.size, "vacio": vacio}


## Los `k` nombres de las piezas más VOLUMINOSAS de un cluster — para poder rastrear en el GLB
## qué es cada objeto ensamblado sin abrir el manifest entero.
func _top_nombres(miembros: Array[Dictionary], k: int) -> PackedStringArray:
	var ordenado: Array[Dictionary] = miembros.duplicate()
	ordenado.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: AABB = a["aabb"]
		var vb: AABB = b["aabb"]
		return (va.size.x * va.size.y * va.size.z) > (vb.size.x * vb.size.y * vb.size.z)
	)
	var nombres := PackedStringArray()
	for i: int in mini(k, ordenado.size()):
		nombres.append(String(ordenado[i]["nombre"]))
	return nombres


## Renderiza TODO (arquitectura suelta + clusters), escribe manifest + HTML y cierra. Todo en una
## corrutina para que el orden quede garantizado, igual que v1.
func _ejecutar(arquitectura: Array[Dictionary], clusters: Array, grupo: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))

	var renders_arquitectura: Array[Dictionary] = []
	for i: int in arquitectura.size():
		var it: Dictionary = arquitectura[i]
		var resultado: Dictionary = await _renderizar_una(it, grupo)
		var nombre_archivo: String = "ARQ_%03d.png" % i
		_guardar_miniatura(resultado["imagen"], SALIDA + nombre_archivo)
		renders_arquitectura.append({
			"id": nombre_archivo.get_basename(),
			"archivo": "objetos/" + nombre_archivo,
			"nombre": it["nombre"],
			"tamano": resultado["tamano"],
		})
		if resultado["vacio"]:
			print("[OBJETOS] aviso: render vacío en arquitectura %s (%s)" % [nombre_archivo, it["nombre"]])

	var renders_clusters: Array[Dictionary] = []
	for i: int in clusters.size():
		var miembros: Array[Dictionary] = clusters[i]
		var resultado: Dictionary = await _renderizar_cluster(miembros, grupo)
		var nombre_archivo: String = "OBJ_%03d.png" % i
		_guardar_miniatura(resultado["imagen"], SALIDA + nombre_archivo)
		renders_clusters.append({
			"id": nombre_archivo.get_basename(),
			"archivo": "objetos/" + nombre_archivo,
			"num_piezas": miembros.size(),
			"tamano": resultado["tamano"],
			"piezas_top": _top_nombres(miembros, 3),
			"instancias": miembros,
		})
		if resultado["vacio"]:
			print("[OBJETOS] aviso: render vacío en cluster %s (%d piezas)" % [nombre_archivo, miembros.size()])
		if (i + 1) % 20 == 0 or i == clusters.size() - 1:
			print("[OBJETOS] %d/%d clusters renderizados" % [i + 1, clusters.size()])

	_escribir_manifest(renders_arquitectura, renders_clusters)
	_escribir_html(renders_arquitectura, renders_clusters)
	print("[OBJETOS] hecho: %d PNG arquitectura + %d PNG clusters en %s" % [
		renders_arquitectura.size(), renders_clusters.size(), SALIDA
	])
	get_tree().quit()


## Coloca la cámara isométrica y ajusta el tamaño ortográfico a lo que OCUPA REALMENTE la caja
## vista desde ese ángulo (proyecta las 8 esquinas sobre los ejes de la cámara) — copiado de v1.
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


## Las 8 esquinas de una AABB, a mano (copiado de v1).
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


## Quita el aire transparente de alrededor (copiado de v1).
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)


## Reduce al lado mayor pedido (LANCZOS, desde el render grande) y guarda el PNG (copiado de v1).
func _guardar_miniatura(imagen: Image, ruta_res: String) -> void:
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


## Escapa lo mínimo para meter texto arbitrario dentro de HTML sin romper la etiqueta.
func _escapar_html(texto: String) -> String:
	return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


## Escribe `catalogo_objetos_manifest.json`: por cluster, sus instancias completas; por pieza de
## arquitectura, su referencia de imagen.
func _escribir_manifest(arquitectura: Array[Dictionary], clusters: Array[Dictionary]) -> void:
	var lista_arq: Array = []
	for a: Dictionary in arquitectura:
		var tam: Vector3 = a["tamano"]
		lista_arq.append({
			"id": a["id"],
			"archivo": a["archivo"],
			"nombre": a["nombre"],
			"tamano": [tam.x, tam.y, tam.z],
		})

	var lista_clusters: Array = []
	for c: Dictionary in clusters:
		var instancias_json: Array = []
		for it: Dictionary in (c["instancias"] as Array[Dictionary]):
			var t: Transform3D = it["transform"]
			var malla: Mesh = it["malla"]
			instancias_json.append({
				"nombre": it["nombre"],
				"malla_recurso": String(malla.resource_path),
				"posicion_global": [t.origin.x, t.origin.y, t.origin.z],
				"base": {
					"x": [t.basis.x.x, t.basis.x.y, t.basis.x.z],
					"y": [t.basis.y.x, t.basis.y.y, t.basis.y.z],
					"z": [t.basis.z.x, t.basis.z.y, t.basis.z.z],
				},
			})
		var tam: Vector3 = c["tamano"]
		lista_clusters.append({
			"id": c["id"],
			"archivo": c["archivo"],
			"num_piezas": c["num_piezas"],
			"tamano": [tam.x, tam.y, tam.z],
			"piezas_top": Array(c["piezas_top"] as PackedStringArray),
			"instancias": instancias_json,
		})

	var datos := {
		"generado": Time.get_datetime_string_from_system(),
		"modelo_origen": MODELO,
		"umbral_arquitectura_m": UMBRAL_ARQUITECTURA,
		"epsilon_proporcion": EPSILON_PROPORCION,
		"total_arquitectura": arquitectura.size(),
		"total_clusters": clusters.size(),
		"arquitectura": lista_arq,
		"clusters": lista_clusters,
	}

	var ruta: String = ProjectSettings.globalize_path(SALIDA_RAIZ + "catalogo_objetos_manifest.json")
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("RenderCatalogoObjetos: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()


## Escribe `index_objetos.html`: clusters primero (huella descendente), arquitectura al final.
func _escribir_html(arquitectura: Array[Dictionary], clusters: Array[Dictionary]) -> void:
	var orden: Array[Dictionary] = clusters.duplicate()
	orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Vector3 = a["tamano"]
		var tb: Vector3 = b["tamano"]
		return (ta.x * ta.y * ta.z) > (tb.x * tb.y * tb.z)
	)
	var celdas: PackedStringArray = []
	for c: Dictionary in orden:
		var tam: Vector3 = c["tamano"]
		var top_txt: String = ", ".join(c["piezas_top"] as PackedStringArray)
		celdas.append(
			"<div class=\"celda\">"
			+ "<div class=\"miniatura\"><img src=\"%s\" alt=\"%s\" loading=\"lazy\"></div>" % [
				_escapar_html(c["archivo"]), _escapar_html(c["id"])
			]
			+ "<div class=\"nombre\">%s <span class=\"conteo\">×%d piezas</span></div>" % [
				c["id"], int(c["num_piezas"])
			]
			+ "<div class=\"dimensiones\">%.2f × %.2f × %.2f</div>" % [tam.x, tam.y, tam.z]
			+ "<div class=\"piezas\">%s</div>" % _escapar_html(top_txt)
			+ "</div>"
		)

	var orden_arq: Array[Dictionary] = arquitectura.duplicate()
	orden_arq.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Vector3 = a["tamano"]
		var tb: Vector3 = b["tamano"]
		return (ta.x * ta.y * ta.z) > (tb.x * tb.y * tb.z)
	)
	var celdas_arq: PackedStringArray = []
	for a: Dictionary in orden_arq:
		var tam: Vector3 = a["tamano"]
		celdas_arq.append(
			"<div class=\"celda\">"
			+ "<div class=\"miniatura\"><img src=\"%s\" alt=\"%s\" loading=\"lazy\"></div>" % [
				_escapar_html(a["archivo"]), _escapar_html(a["nombre"])
			]
			+ "<div class=\"nombre\">%s</div>" % _escapar_html(a["nombre"])
			+ "<div class=\"dimensiones\">%.2f × %.2f × %.2f</div>" % [tam.x, tam.y, tam.z]
			+ "</div>"
		)

	var css: PackedStringArray = [
		"body{font-family:sans-serif;background:#222;color:#eee;margin:0;padding:24px;}",
		"h1{font-size:20px;margin:0 0 4px 0;}",
		"h2{font-size:16px;margin:32px 0 4px 0;border-top:1px solid #444;padding-top:16px;}",
		".resumen{color:#aaa;margin:0 0 20px 0;}",
		".rejilla{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;}",
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
		".piezas{font-size:10px;color:#7fbf7f;margin-top:2px;word-break:break-all;}",
	]

	var html: String = (
		"<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"
		+ "<title>Catálogo — objetos ensamblados (Oficina)</title><style>"
		+ "\n".join(css) + "</style></head><body>"
		+ "<h1>Catálogo de objetos ensamblados — Oficina</h1>"
		+ "<p class=\"resumen\">%d objetos (clusters de mobiliario) + %d piezas de arquitectura." % [
			clusters.size(), arquitectura.size()
		]
		+ " Umbral de arquitectura: %.2f m de lado mayor. Epsilon de agrupado: %.2f m.</p>" % [
			UMBRAL_ARQUITECTURA, EPSILON_PROPORCION
		]
		+ "<div class=\"rejilla\">" + "".join(celdas) + "</div>"
		+ "<h2>Arquitectura (excluida del ensamblado)</h2>"
		+ "<p class=\"resumen\">Piezas cuyo lado más largo supera el umbral: paredes, suelos, "
		+ "techos, paneles modulares… No se agrupan porque tocan casi todo lo demás.</p>"
		+ "<div class=\"rejilla\">" + "".join(celdas_arq) + "</div>"
		+ "</body></html>"
	)

	var ruta: String = ProjectSettings.globalize_path(SALIDA_RAIZ + "index_objetos.html")
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("RenderCatalogoObjetos: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(html)
	archivo.close()
