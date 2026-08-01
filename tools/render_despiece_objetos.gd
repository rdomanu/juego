extends Node3D
## Despiece de los clusters de mobiliario de `render_catalogo_objetos.gd` (v2) — v2.1.
##
## v2 agrupó las ~700 piezas del pack en 53 clusters de mobiliario usando un epsilon
## PROPORCIONAL del 3 % de la diagonal de cada pieza. Funciona de maravilla para "silla
## despiezada en ruedas+asiento+respaldo -> 1 silla", pero es DEMASIADO generoso para
## mobiliario en batería: una isla de 2-3 escritorios pegados (con su silla, monitor y
## cajonera cada uno) sale como UN solo cluster. El usuario necesita cada escritorio como
## pieza suelta (para poder colocarlos como quiera), y las sillas aparte de las mesas.
##
## Esta herramienta NO vuelve a agrupar desde cero: reproduce EXACTAMENTE los 53 clusters de
## v2 (mismas constantes `UMBRAL_ARQUITECTURA` / `EPSILON_PROPORCION`, mismo algoritmo) y lo
## verifica contra `catalogo_objetos_manifest.json` pieza por pieza antes de tocar nada — si no
## coincide 1:1, para con un error en vez de arriesgarse a nombrar mal un sub-objeto. Sobre
## CADA cluster ya formado, vuelve a agrupar sus miembros con un criterio mucho más estricto:
## solapamiento REAL (no "tocarse por los pelos") de sus AABB en el mundo. Si un cluster se
## parte en 2+ sub-objetos, se renderiza cada uno; si no se parte, no se toca su PNG existente.
##
## ── CÓMO SE AGRUPA EL DESPIECE ─────────────────────────────────────────────────────────────────
## Cada pieza se infla un pequeño porcentaje (`EPSILON_DESPIECE`) de SU PROPIA diagonal — igual
## idea que v2, pero con un número mucho más pequeño — y dos piezas quedan juntas si sus AABB
## infladas se solapan con volumen ESTRICTAMENTE positivo en los 3 ejes (no basta con tocarse:
## dos mesas que se rozan de canto, sin overlap real, NO se unen). Si ese epsilon único no basta
## para separar las islas de escritorios (mesas grandes que de verdad casi se tocan), se activa
## `USAR_INTERSECCION_VOLUMEN_GRANDES`: las piezas "grandes" (diagonal > `UMBRAL_PIEZA_GRANDE_M`,
## normalmente los tableros de mesa) dejan de inflarse (inflado 0, solo cuentan si de verdad
## interpenetran), mientras que las piezas pequeñas (monitor, teclado, cajonera, silla) SIGUEN
## con su epsilon — así un monitor apoyado en la mesa (que sí se solapa/empotra un poco con el
## tablero) se sigue enganchando a "su" mesa, pero dos tableros que solo se rozan de lado no.
##
## ── CALIBRACIÓN: `SOLO_ANALIZAR` ───────────────────────────────────────────────────────────────
## Igual que en v2: con `SOLO_ANALIZAR = true` la herramienta reproduce los 53 clusters, calcula
## el despiece de cada uno e IMPRIME, por cada cluster que se subdivide, el tamaño/posición de
## cada sub-grupo — sin renderizar nada (segundos, no minutos). Así se prueban los dos
## centinelas pedidos por el usuario (una silla de oficina entera / una isla de escritorios
## partida en mesas) solo mirando la consola, antes de gastar tiempo en render.
##
## ── CÓMO SE USA ────────────────────────────────────────────────────────────────────────────────
##   godot --path <proyecto> res://tools/RenderDespieceObjetos.tscn
## No headless (SubViewport 3D necesita GPU, igual que v1/v2).
##
## Escribe en `res://capturas/NPC/Oficina/catalogo/` (mismas carpetas que v2, NO las borra):
##   · `objetos/SUB_NNN_K.png` — sub-objeto K del cluster OBJ_NNN que se subdividió.
##   · `index_objetos.html` — REGENERADO: sección nueva "DESPIECE de grupos múltiples" arriba
##     del todo; el resto de la hoja (rejilla de clusters + arquitectura) queda IGUAL que la
##     escribía v2 (mismos datos, mismo orden, mismo CSS).
##   · `catalogo_despiece_manifest.json` — composición de cada sub-objeto (solo clusters que se
##     subdividieron; los que no, no aparecen).
##
## No modifica NI re-renderiza ningún `OBJ_NNN.png` / `ARQ_NNN.png` existente: v2 queda intacto.
const SOLO_ANALIZAR: bool = false

## Mismo modelo de origen que v1/v2.
const MODELO := "res://capturas/NPC/Oficina/isometric_office.glb"
## Los SUB_NNN_K.png van en la MISMA carpeta que los OBJ_NNN.png de v2 (piezas del mismo
## catálogo). El HTML y los manifests, junto a los de v1/v2.
const SALIDA := "res://capturas/NPC/Oficina/catalogo/objetos/"
const SALIDA_RAIZ := "res://capturas/NPC/Oficina/catalogo/"
const MANIFEST_V2 := SALIDA_RAIZ + "catalogo_objetos_manifest.json"

## Mismos patrones de cámara/render que v1/v2 — el catálogo tiene que verse uniforme.
const ELEVACION_GRADOS: float = 26.565
const TAM_RENDER: int = 256
const TAM_FINAL: int = 128
const MARGEN: float = 1.10

## ── DEBEN SER IGUALES QUE EN v2 ────────────────────────────────────────────────────────────────
## Imprescindibles para reproducir EXACTAMENTE sus 53 clusters de mobiliario antes de
## despiezarlos. Si algún día se recalibra v2, hay que igualar estos dos números aquí Y volver a
## generar `catalogo_objetos_manifest.json` — `_ready()` lo comprueba y para con error si no
## coinciden con los que efectivamente produjeron ese manifest.
const UMBRAL_ARQUITECTURA: float = 1.8
const EPSILON_PROPORCION: float = 0.03

## ── CALIBRACIÓN DEL DESPIECE ───────────────────────────────────────────────────────────────────
## Ver el informe de calibración con los dos centinelas (silla entera / isla de escritorios
## partida) para el porqué de estos valores concretos.
const EPSILON_DESPIECE: float = 0.03
const UMBRAL_PIEZA_GRANDE_M: float = 1.0
const USAR_INTERSECCION_VOLUMEN_GRANDES: bool = true

var _sub: SubViewport
var _camara: Camera3D


func _ready() -> void:
	var datos_v2: Dictionary = _cargar_manifest_v2()
	if datos_v2.is_empty():
		return
	if (
		absf(float(datos_v2.get("umbral_arquitectura_m", -1.0)) - UMBRAL_ARQUITECTURA) > 0.0001
		or absf(float(datos_v2.get("epsilon_proporcion", -1.0)) - EPSILON_PROPORCION) > 0.0001
	):
		push_error((
			"RenderDespieceObjetos: %s se generó con UMBRAL_ARQUITECTURA=%.4f / "
			+ "EPSILON_PROPORCION=%.4f, pero esta herramienta tiene %.4f / %.4f. Iguala las "
			+ "constantes (o vuelve a ejecutar v2) antes de despiezar."
		) % [
			MANIFEST_V2, float(datos_v2.get("umbral_arquitectura_m", -1.0)),
			float(datos_v2.get("epsilon_proporcion", -1.0)), UMBRAL_ARQUITECTURA, EPSILON_PROPORCION
		])
		get_tree().quit(1)
		return

	var escena: PackedScene = load(MODELO)
	if escena == null:
		push_error("RenderDespieceObjetos: no se pudo cargar %s" % MODELO)
		get_tree().quit(1)
		return

	var contenedor := Node3D.new()
	add_child(contenedor)
	var modelo: Node3D = escena.instantiate()
	contenedor.add_child(modelo)
	# Solo datos: nunca debe aparecer en un render (misma lección que v1/v2).
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
		print("[DESPIECE] aviso: %d instancias sin malla, ignoradas" % nulas)

	var arquitectura: Array[Dictionary] = []
	var mobiliario: Array[Dictionary] = []
	for it: Dictionary in instancias:
		if float(it["lado_mayor"]) >= UMBRAL_ARQUITECTURA:
			arquitectura.append(it)
		else:
			mobiliario.append(it)

	var clusters: Array = _agrupar(mobiliario, EPSILON_PROPORCION)

	# ── Verificación cruzada contra el manifest de v2: cada cluster recalculado tiene que
	# coincidir EXACTAMENTE (mismo conjunto de nombres de pieza) con uno de v2, o paramos. Así
	# el SUB_NNN_K que generemos apunta siempre al OBJ_NNN correcto.
	var mapa_firmas: Dictionary = {}
	for c: Dictionary in (datos_v2["clusters"] as Array):
		var nombres: Array[String] = []
		for inst: Dictionary in (c["instancias"] as Array):
			nombres.append(String(inst["nombre"]))
		nombres.sort()
		mapa_firmas["|".join(nombres)] = {"id": String(c["id"]), "archivo": String(c["archivo"])}

	var ids_clusters: Array[Dictionary] = []
	for miembros: Array[Dictionary] in clusters:
		var firma: String = _firma(miembros)
		if not mapa_firmas.has(firma):
			push_error((
				"RenderDespieceObjetos: un cluster recalculado (%d piezas) no coincide con "
				+ "ningún cluster de %s. ¿Cambió el .glb, o v2 se ejecutó con otras constantes? "
				+ "Piezas: %s"
			) % [miembros.size(), MANIFEST_V2, firma])
			get_tree().quit(1)
			return
		ids_clusters.append(mapa_firmas[firma])
	if clusters.size() != int(datos_v2["total_clusters"]):
		push_error("RenderDespieceObjetos: %d clusters recalculados vs %d en %s — no coinciden 1:1." % [
			clusters.size(), int(datos_v2["total_clusters"]), MANIFEST_V2
		])
		get_tree().quit(1)
		return

	var mapa_arq: Dictionary = {}
	for a: Dictionary in (datos_v2["arquitectura"] as Array):
		mapa_arq[String(a["nombre"])] = {"id": String(a["id"]), "archivo": String(a["archivo"])}
	var ids_arq: Array[Dictionary] = []
	for it: Dictionary in arquitectura:
		var nombre: String = String(it["nombre"])
		if not mapa_arq.has(nombre):
			push_error("RenderDespieceObjetos: pieza de arquitectura '%s' no está en %s." % [
				nombre, MANIFEST_V2
			])
			get_tree().quit(1)
			return
		ids_arq.append(mapa_arq[nombre])
	if arquitectura.size() != int(datos_v2["total_arquitectura"]):
		push_error("RenderDespieceObjetos: %d arquitectura recalculada vs %d en %s — no coinciden." % [
			arquitectura.size(), int(datos_v2["total_arquitectura"]), MANIFEST_V2
		])
		get_tree().quit(1)
		return

	print("[DESPIECE] reproducidos %d clusters + %d arquitectura -- coincide 1:1 con %s" % [
		clusters.size(), arquitectura.size(), MANIFEST_V2
	])

	# ── Despiece de cada cluster ────────────────────────────────────────────────────────────────
	# Fase 3 (solape estricto de volumen) primero; si su resultado TODAVÍA deja dos copias de la
	# misma malla grande (p. ej. dos tableros de mesa) dentro de un mismo sub-grupo — caso de las
	# mesas en "L" que de verdad interpenetran en AABB — se sustituye por el plan B (semillas por
	# malla repetida) para ESE cluster.
	var resumen_despiece: Array[Dictionary] = []
	for i: int in clusters.size():
		var miembros: Array[Dictionary] = clusters[i]
		var subgrupos: Array = _agrupar_despiece(miembros)
		var metodo: String = "volumen"
		var semilla: Dictionary = _malla_grande_repetida_en(miembros)
		if String(semilla["recurso"]) != "" and _subgrupo_contiene_repetida(subgrupos, String(semilla["recurso"])):
			subgrupos = _despiece_plan_b(miembros, String(semilla["recurso"]))
			metodo = "plan_b(forma %s x%d)" % [String(semilla["recurso"]), int(semilla["count"])]
		resumen_despiece.append({
			"id": ids_clusters[i]["id"], "archivo": ids_clusters[i]["archivo"],
			"miembros": miembros, "subgrupos": subgrupos, "metodo": metodo,
		})

	_imprimir_analisis_despiece(resumen_despiece)

	if SOLO_ANALIZAR:
		print(
			"[DESPIECE] SOLO_ANALIZAR=true -> no se renderiza nada. Ajusta EPSILON_DESPIECE / "
			+ "UMBRAL_PIEZA_GRANDE_M / USAR_INTERSECCION_VOLUMEN_GRANDES arriba y repite."
		)
		get_tree().quit()
		return

	# SubViewport aislado: misma lección que v1/v2 (own_world_3d, si no el `contenedor` entero
	# — invisible o no — se cuela en el World3D compartido).
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

	await _ejecutar(clusters, ids_clusters, arquitectura, ids_arq, resumen_despiece, grupo)


## Lee y parsea `catalogo_objetos_manifest.json` (el manifest que escribió v2). Devuelve `{}` (y
## ya ha llamado a `get_tree().quit(1)`) si no se puede leer o no es JSON válido.
func _cargar_manifest_v2() -> Dictionary:
	var ruta: String = ProjectSettings.globalize_path(MANIFEST_V2)
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error((
			"RenderDespieceObjetos: no se pudo leer %s (error %d). Ejecuta primero "
			+ "render_catalogo_objetos.gd (v2) — este despiece parte de su manifest."
		) % [ruta, FileAccess.get_open_error()])
		get_tree().quit(1)
		return {}
	var texto: String = archivo.get_as_text()
	archivo.close()
	var datos: Variant = JSON.parse_string(texto)
	if datos == null or typeof(datos) != TYPE_DICTIONARY:
		push_error("RenderDespieceObjetos: %s no es JSON válido." % ruta)
		get_tree().quit(1)
		return {}
	return datos


## Firma de un cluster: nombres de sus piezas, ordenados y unidos — identifica un cluster sin
## depender del orden en que se haya recalculado.
func _firma(miembros: Array[Dictionary]) -> String:
	var nombres: Array[String] = []
	for it: Dictionary in miembros:
		nombres.append(String(it["nombre"]))
	nombres.sort()
	return "|".join(nombres)


## Une por proximidad — IDÉNTICO al `_agrupar` de v2 (necesario para reproducir sus 53
## clusters de mobiliario exactamente antes de despiezarlos).
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


## El radio de inflado de UNA pieza para el despiece: proporcional a su propia diagonal, salvo
## que sea "grande" (diagonal > `UMBRAL_PIEZA_GRANDE_M`) y `USAR_INTERSECCION_VOLUMEN_GRANDES`
## esté activo — en ese caso, inflado 0 (solo cuenta si de verdad interpenetra a otra pieza).
func _radio_inflado_despiece(caja: AABB) -> float:
	var diagonal: float = caja.size.length()
	if USAR_INTERSECCION_VOLUMEN_GRANDES and diagonal > UMBRAL_PIEZA_GRANDE_M:
		return 0.0
	return diagonal * EPSILON_DESPIECE


## Solapamiento REAL: volumen estrictamente positivo en los 3 ejes — no basta con tocarse (dos
## cajas con un borde exactamente coincidente, overlap 0, NO cuentan). A propósito no se usa
## `AABB.intersects()` (que sí cuenta el simple contacto) para este paso: es justo la diferencia
## que separa "mesas en batería que se rozan" de "monitor que se apoya en su mesa".
func _solapan_estrictamente(a: AABB, b: AABB) -> bool:
	var a_fin: Vector3 = a.position + a.size
	var b_fin: Vector3 = b.position + b.size
	return (
		a.position.x < b_fin.x and b.position.x < a_fin.x
		and a.position.y < b_fin.y and b.position.y < a_fin.y
		and a.position.z < b_fin.z and b.position.z < a_fin.z
	)


## Despiece de UN cluster: sus miembros, reagrupados con el criterio estricto de arriba. Mismo
## union-find que `_agrupar`, pero con inflado adaptativo por pieza y solape estricto.
func _agrupar_despiece(miembros: Array[Dictionary]) -> Array:
	var n: int = miembros.size()
	var padre: Array[int] = []
	var infladas: Array[AABB] = []
	for i: int in n:
		padre.append(i)
		var caja: AABB = miembros[i]["aabb"]
		infladas.append(caja.grow(_radio_inflado_despiece(caja)))
	for i: int in n:
		for j: int in range(i + 1, n):
			if _solapan_estrictamente(infladas[i], infladas[j]):
				_unir(padre, i, j)
	var grupos: Dictionary = {}
	for i: int in n:
		var raiz: int = _buscar(padre, i)
		if not grupos.has(raiz):
			grupos[raiz] = [] as Array[int]
		(grupos[raiz] as Array[int]).append(i)
	var resultado: Array = []
	for clave: int in grupos.keys():
		var indices: Array[int] = grupos[clave]
		var grupo_dicts: Array[Dictionary] = []
		for idx: int in indices:
			grupo_dicts.append(miembros[idx])
		resultado.append(grupo_dicts)
	return resultado


## ── PLAN B: semillas por malla repetida ────────────────────────────────────────────────────────
## Cuando dos (o más) unidades de mobiliario idénticas están tan pegadas que sus tableros/cuerpos
## de verdad interpenetran en AABB (mesas en "L", p. ej.), NINGÚN umbral de solape las separa —
## el solape es real, no un artefacto de proximidad. La señal fiable en ese caso es otra: la
## malla de la pieza más grande del cluster aparece 2+ veces (dos tableros == dos mesas). Cada
## instancia de esa malla repetida es la semilla de una unidad; el resto de piezas del cluster
## (monitor, teclado, cajonera…) se asigna a la semilla cuyo CENTRO está más cerca (vecino más
## próximo, un único paso — no hace falta iterar tipo k-means: las semillas ya están fijas).
##
## Firma de FORMA de una pieza: tamaño de su malla en espacio LOCAL (sin transformada), redondeado
## a el cm — no el `resource_path`. Se comprobó con este mismo pack que el importador de glTF NO
## comparte recurso de malla entre copias idénticas (cada mesa exportada es un `ArrayMesh_xxxxx`
## distinto aunque sea el mismo molde) — comparar por `resource_path` nunca encontraría una
## "malla repetida". El tamaño LOCAL sí es idéntico entre copias del mismo mueble, da igual dónde
## esté colocado o rotado cada una.
func _firma_forma(it: Dictionary) -> String:
	var s: Vector3 = (it["malla"] as Mesh).get_aabb().size
	return "%.2f_%.2f_%.2f" % [s.x, s.y, s.z]


## Busca, entre las piezas "grandes" (diagonal > `UMBRAL_PIEZA_GRANDE_M`) de un cluster, la forma
## (por tamaño local) con más volumen que aparezca 2+ veces. Si no hay ninguna, `firma` viene
## vacía (el cluster no encaja en este plan; se deja como decidió la fase 3, y se documenta).
func _malla_grande_repetida_en(miembros: Array[Dictionary]) -> Dictionary:
	var conteo: Dictionary = {}
	var volumen: Dictionary = {}
	for it: Dictionary in miembros:
		var caja: AABB = it["aabb"]
		if caja.size.length() <= UMBRAL_PIEZA_GRANDE_M:
			continue
		var firma: String = _firma_forma(it)
		conteo[firma] = int(conteo.get(firma, 0)) + 1
		var vol: float = caja.size.x * caja.size.y * caja.size.z
		volumen[firma] = maxf(float(volumen.get(firma, 0.0)), vol)
	var mejor_firma: String = ""
	var mejor_count: int = 0
	var mejor_vol: float = -1.0
	for firma: String in conteo.keys():
		var c: int = int(conteo[firma])
		if c >= 2 and float(volumen[firma]) > mejor_vol:
			mejor_firma = firma
			mejor_count = c
			mejor_vol = volumen[firma]
	return {"recurso": mejor_firma, "count": mejor_count}


## ¿Algún sub-grupo del resultado de la fase 3 sigue conteniendo 2+ piezas con la firma de forma
## `firma`? Si sí, esa fase no separó las unidades reales — hace falta el plan B.
func _subgrupo_contiene_repetida(subgrupos: Array, firma: String) -> bool:
	for sg: Array[Dictionary] in subgrupos:
		var c: int = 0
		for it: Dictionary in sg:
			if _firma_forma(it) == firma:
				c += 1
		if c >= 2:
			return true
	return false


## Reparte TODAS las piezas de `miembros` entre las N instancias con firma de forma
## `firma_semilla` (las semillas), cada una por vecino-más-cercano de centroide. Devuelve N
## grupos que cubren el cluster entero (cada semilla cae en su propio grupo, distancia 0 a sí
## misma).
func _despiece_plan_b(miembros: Array[Dictionary], firma_semilla: String) -> Array:
	var centros_semilla: Array[Vector3] = []
	for it: Dictionary in miembros:
		if _firma_forma(it) == firma_semilla:
			centros_semilla.append((it["aabb"] as AABB).get_center())
	var grupos: Array[Array] = []
	for i: int in centros_semilla.size():
		grupos.append([] as Array[Dictionary])
	for it: Dictionary in miembros:
		var centro: Vector3 = (it["aabb"] as AABB).get_center()
		var mejor: int = 0
		var mejor_d: float = INF
		for s: int in centros_semilla.size():
			var d: float = centro.distance_squared_to(centros_semilla[s])
			if d < mejor_d:
				mejor_d = d
				mejor = s
		(grupos[mejor] as Array[Dictionary]).append(it)
	var resultado: Array = []
	for g: Array in grupos:
		resultado.append(g)
	return resultado


## `find` con compresión de camino (copiado de v2).
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


## `union` simple (copiado de v2).
func _unir(padre: Array[int], a: int, b: int) -> void:
	var ra: int = _buscar(padre, a)
	var rb: int = _buscar(padre, b)
	if ra != rb:
		padre[ra] = rb


## Imprime, por cada cluster que se subdivide, el tamaño/centro de cada sub-grupo — para
## calibrar `EPSILON_DESPIECE` / `UMBRAL_PIEZA_GRANDE_M` / `USAR_INTERSECCION_VOLUMEN_GRANDES`
## mirando solo la consola (los dos centinelas: silla entera / isla de escritorios partida).
func _imprimir_analisis_despiece(resumen: Array[Dictionary]) -> void:
	var subdivididos: int = 0
	var total_sub: int = 0
	for r: Dictionary in resumen:
		var subgrupos: Array = r["subgrupos"]
		if subgrupos.size() < 2:
			continue
		subdivididos += 1
		total_sub += subgrupos.size()
		var partes: Array[String] = []
		for sg: Array[Dictionary] in subgrupos:
			var caja: AABB = _caja_mundo_cluster(sg)
			partes.append("%dpz %.2fx%.2fx%.2f@(%.1f,%.1f)" % [
				sg.size(), caja.size.x, caja.size.y, caja.size.z,
				caja.get_center().x, caja.get_center().z
			])
		print("[DESPIECE] %s [%s] (%d pz) -> %d sub: %s" % [
			r["id"], r.get("metodo", "volumen"), (r["miembros"] as Array).size(), subgrupos.size(),
			" | ".join(partes)
		])
	print((
		"[DESPIECE] resumen: %d/%d clusters subdivididos -> %d sub-objetos "
		+ "(EPSILON_DESPIECE=%.3f, UMBRAL_PIEZA_GRANDE_M=%.2f, USAR_INTERSECCION_VOLUMEN_GRANDES=%s)"
	) % [
		subdivididos, resumen.size(), total_sub, EPSILON_DESPIECE, UMBRAL_PIEZA_GRANDE_M,
		str(USAR_INTERSECCION_VOLUMEN_GRANDES)
	])


## La AABB en el mundo que ocupa un cluster/sub-grupo entero (sin centrar — el tamaño no cambia
## con la traslación). Usada tanto para el render como para el HTML/manifest sin renderizar.
func _caja_mundo_cluster(miembros: Array[Dictionary]) -> AABB:
	var caja := AABB()
	var primera := true
	for it: Dictionary in miembros:
		var t: Transform3D = it["transform"]
		var malla: Mesh = it["malla"]
		var caja_mundo: AABB = t * malla.get_aabb()
		caja = caja_mundo if primera else caja.merge(caja_mundo)
		primera = false
	return caja


## La AABB (sin traslación, solo base) de UNA pieza de arquitectura — igual que calcula
## `_renderizar_una` en v2, pero sin renderizar (solo para reportar tamaño en el HTML).
func _caja_pieza_arquitectura(it: Dictionary) -> AABB:
	var malla: Mesh = it["malla"]
	var base: Basis = (it["transform"] as Transform3D).basis
	return Transform3D(base, Vector3.ZERO) * malla.get_aabb()


## Vacía el contenedor de piezas de forma SÍNCRONA antes de montar el siguiente objeto (copiado
## de v2).
func _limpiar_grupo(grupo: Node3D) -> void:
	for hijo: Node in grupo.get_children():
		grupo.remove_child(hijo)
		hijo.free()


## Añade una malla al `grupo`, con su transformada y sus materiales (copiado de v2).
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


## Renderiza un sub-objeto (grupo de piezas con sus transformadas relativas intactas, solo se
## desplaza el conjunto para centrarlo) — mismo patrón que `_renderizar_cluster` de v2.
func _renderizar_cluster(miembros: Array[Dictionary], grupo: Node3D) -> Dictionary:
	_limpiar_grupo(grupo)
	var caja: AABB = _caja_mundo_cluster(miembros)
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


## Los `k` nombres de las piezas más voluminosas de un grupo (copiado de v2).
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


## Renderiza los sub-objetos de los clusters que se subdividieron, escribe manifest + HTML.
func _ejecutar(
	clusters: Array, ids_clusters: Array[Dictionary], arquitectura: Array[Dictionary],
	ids_arq: Array[Dictionary], resumen_despiece: Array[Dictionary], grupo: Node3D
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))

	var despiece_por_cluster: Array[Dictionary] = []
	var total_subobjetos: int = 0
	for r: Dictionary in resumen_despiece:
		var subgrupos: Array = r["subgrupos"]
		if subgrupos.size() < 2:
			continue
		# Orden determinista: sub-objeto más voluminoso primero.
		subgrupos.sort_custom(func(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
			var ca: AABB = _caja_mundo_cluster(a)
			var cb: AABB = _caja_mundo_cluster(b)
			return (ca.size.x * ca.size.y * ca.size.z) > (cb.size.x * cb.size.y * cb.size.z)
		)
		var numero: String = String(r["id"]).replace("OBJ_", "")
		var subobjetos: Array[Dictionary] = []
		for k: int in subgrupos.size():
			var sub_miembros: Array[Dictionary] = subgrupos[k]
			var resultado: Dictionary = await _renderizar_cluster(sub_miembros, grupo)
			var id_sub: String = "SUB_%s_%d" % [numero, k]
			var nombre_archivo: String = id_sub + ".png"
			_guardar_miniatura(resultado["imagen"], SALIDA + nombre_archivo)
			subobjetos.append({
				"id": id_sub, "archivo": "objetos/" + nombre_archivo,
				"num_piezas": sub_miembros.size(), "tamano": resultado["tamano"],
				"piezas_top": _top_nombres(sub_miembros, 3), "instancias": sub_miembros,
			})
			if resultado["vacio"]:
				print("[DESPIECE] aviso: render vacío en %s" % id_sub)
		despiece_por_cluster.append({
			"id_original": r["id"], "archivo_original": r["archivo"],
			"num_piezas_original": (r["miembros"] as Array).size(),
			"tamano_original": _caja_mundo_cluster(r["miembros"]).size,
			"metodo": r.get("metodo", "volumen"),
			"subobjetos": subobjetos,
		})
		total_subobjetos += subobjetos.size()
		print("[DESPIECE] %s [%s] (%d piezas) -> %d sub-objetos renderizados" % [
			r["id"], r.get("metodo", "volumen"), (r["miembros"] as Array).size(), subobjetos.size()
		])

	_escribir_manifest_despiece(despiece_por_cluster)

	# Datos para regenerar el RESTO de la hoja (rejilla de clusters + arquitectura) igual que v2
	# — sin volver a renderizar ninguno de esos PNG, ya existen.
	var info_clusters: Array[Dictionary] = []
	for i: int in clusters.size():
		var miembros: Array[Dictionary] = clusters[i]
		var info: Dictionary = ids_clusters[i]
		info_clusters.append({
			"id": info["id"], "archivo": info["archivo"], "num_piezas": miembros.size(),
			"tamano": _caja_mundo_cluster(miembros).size, "piezas_top": _top_nombres(miembros, 3),
		})
	var info_arq: Array[Dictionary] = []
	for i: int in arquitectura.size():
		var it: Dictionary = arquitectura[i]
		var info: Dictionary = ids_arq[i]
		info_arq.append({
			"id": info["id"], "archivo": info["archivo"], "nombre": it["nombre"],
			"tamano": _caja_pieza_arquitectura(it).size,
		})

	_escribir_html(despiece_por_cluster, info_clusters, info_arq)
	print("[DESPIECE] hecho: %d/%d clusters subdivididos -> %d sub-objetos en total" % [
		despiece_por_cluster.size(), clusters.size(), total_subobjetos
	])
	get_tree().quit()


## Coloca la cámara isométrica y ajusta el tamaño ortográfico (copiado de v1/v2).
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


## Las 8 esquinas de una AABB, a mano (copiado de v1/v2).
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


## Quita el aire transparente de alrededor (copiado de v1/v2).
func _recortar(imagen: Image) -> Image:
	var usado: Rect2i = imagen.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return imagen
	return imagen.get_region(usado)


## Reduce al lado mayor pedido (LANCZOS) y guarda el PNG (copiado de v1/v2).
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


## Escapa lo mínimo para meter texto arbitrario dentro de HTML (copiado de v1/v2).
func _escapar_html(texto: String) -> String:
	return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


## Escribe `catalogo_despiece_manifest.json`: solo los clusters que se SUBDIVIDIERON, con la
## composición completa de cada sub-objeto.
func _escribir_manifest_despiece(despiece: Array[Dictionary]) -> void:
	var lista: Array = []
	for d: Dictionary in despiece:
		var subobjetos_json: Array = []
		for s: Dictionary in (d["subobjetos"] as Array[Dictionary]):
			var instancias_json: Array = []
			for it: Dictionary in (s["instancias"] as Array[Dictionary]):
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
			var tam: Vector3 = s["tamano"]
			subobjetos_json.append({
				"id": s["id"], "archivo": s["archivo"], "num_piezas": s["num_piezas"],
				"tamano": [tam.x, tam.y, tam.z],
				"piezas_top": Array(s["piezas_top"] as PackedStringArray),
				"instancias": instancias_json,
			})
		var tam_o: Vector3 = d["tamano_original"]
		lista.append({
			"id_original": d["id_original"], "archivo_original": d["archivo_original"],
			"num_piezas_original": d["num_piezas_original"],
			"tamano_original": [tam_o.x, tam_o.y, tam_o.z],
			"metodo": d.get("metodo", "volumen"),
			"num_subobjetos": subobjetos_json.size(),
			"subobjetos": subobjetos_json,
		})

	var datos := {
		"generado": Time.get_datetime_string_from_system(),
		"modelo_origen": MODELO,
		"manifest_v2_origen": MANIFEST_V2,
		"epsilon_despiece": EPSILON_DESPIECE,
		"umbral_pieza_grande_m": UMBRAL_PIEZA_GRANDE_M,
		"usar_interseccion_volumen_grandes": USAR_INTERSECCION_VOLUMEN_GRANDES,
		"total_clusters_subdivididos": lista.size(),
		"despiece": lista,
	}

	var ruta: String = ProjectSettings.globalize_path(SALIDA_RAIZ + "catalogo_despiece_manifest.json")
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("RenderDespieceObjetos: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()


## Construye la celda HTML de UN sub-objeto (o del original en la sección de despiece).
func _celda_html(archivo: String, id_txt: String, num_piezas: int, tamano: Vector3, piezas_top: PackedStringArray, extra_clase: String, etiqueta_extra: String) -> String:
	var top_txt: String = ", ".join(piezas_top) if piezas_top.size() > 0 else ""
	var pie: String = (
		"<div class=\"piezas\">%s</div>" % _escapar_html(top_txt) if top_txt != ""
		else ("<div class=\"etiqueta\">%s</div>" % _escapar_html(etiqueta_extra) if etiqueta_extra != "" else "")
	)
	return (
		"<div class=\"celda%s\">" % (" " + extra_clase if extra_clase != "" else "")
		+ "<div class=\"miniatura\"><img src=\"%s\" alt=\"%s\" loading=\"lazy\"></div>" % [
			_escapar_html(archivo), _escapar_html(id_txt)
		]
		+ "<div class=\"nombre\">%s <span class=\"conteo\">×%d piezas</span></div>" % [id_txt, num_piezas]
		+ "<div class=\"dimensiones\">%.2f × %.2f × %.2f</div>" % [tamano.x, tamano.y, tamano.z]
		+ pie
		+ "</div>"
	)


## Escribe `index_objetos.html`: sección nueva de despiece arriba del todo, seguida del RESTO de
## la hoja idéntico a como lo escribía v2 (misma rejilla de clusters, misma de arquitectura).
func _escribir_html(
	despiece: Array[Dictionary], info_clusters: Array[Dictionary], info_arq: Array[Dictionary]
) -> void:
	# ---- sección nueva: despiece ----
	var bloques_despiece: PackedStringArray = []
	for d: Dictionary in despiece:
		var tam_o: Vector3 = d["tamano_original"]
		var celda_original: String = _celda_html(
			d["archivo_original"], d["id_original"], int(d["num_piezas_original"]), tam_o,
			PackedStringArray(), "original", "original (sin despiezar)"
		)
		var celdas_sub: PackedStringArray = []
		for s: Dictionary in (d["subobjetos"] as Array[Dictionary]):
			celdas_sub.append(_celda_html(
				s["archivo"], s["id"], int(s["num_piezas"]), s["tamano"],
				s["piezas_top"] as PackedStringArray, "", ""
			))
		bloques_despiece.append(
			"<div class=\"despiece-grupo\">" + celda_original
			+ "<div class=\"flecha\">&rarr;</div>"
			+ "<div class=\"subobjetos\">" + "".join(celdas_sub) + "</div>"
			+ "</div>"
		)

	# ---- resto de la hoja: IGUAL que v2 ----
	var orden: Array[Dictionary] = info_clusters.duplicate()
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

	var orden_arq: Array[Dictionary] = info_arq.duplicate()
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
		".etiqueta{font-size:10px;color:#e0a15c;margin-top:2px;}",
		(
			".despiece-lista{display:flex;flex-direction:column;gap:0;}"
		),
		(
			".despiece-grupo{display:flex;align-items:center;gap:16px;flex-wrap:wrap;"
			+ "padding:16px 0;border-bottom:1px solid #444;}"
		),
		".celda.original{background:#3a2f22;border:1px solid #e0a15c;width:150px;flex:0 0 auto;}",
		".flecha{font-size:24px;color:#7fd0ff;flex:0 0 auto;}",
		".subobjetos{display:flex;flex-wrap:wrap;gap:12px;flex:1 1 auto;}",
		".subobjetos .celda{width:150px;flex:0 0 auto;}",
	]

	var resumen_despiece_txt: String = "Sin clusters de mobiliario que se subdividieran."
	if despiece.size() > 0:
		var total_sub: int = 0
		for d: Dictionary in despiece:
			total_sub += (d["subobjetos"] as Array).size()
		resumen_despiece_txt = "%d de %d clusters de mobiliario se subdividieron en %d sub-objetos." % [
			despiece.size(), info_clusters.size(), total_sub
		]

	var html: String = (
		"<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"
		+ "<title>Catálogo — objetos ensamblados (Oficina)</title><style>"
		+ "\n".join(css) + "</style></head><body>"
		+ "<h1>Catálogo de objetos ensamblados — Oficina</h1>"
		+ "<h2>DESPIECE de grupos múltiples</h2>"
		+ "<p class=\"resumen\">%s Epsilon de despiece: %.3f. Umbral de pieza grande: %.2f m "
		% [resumen_despiece_txt, EPSILON_DESPIECE, UMBRAL_PIEZA_GRANDE_M]
		+ "(intersección de volumen real para piezas grandes: %s).</p>" % (
			"sí" if USAR_INTERSECCION_VOLUMEN_GRANDES else "no"
		)
		+ "<div class=\"despiece-lista\">" + "".join(bloques_despiece) + "</div>"
		+ "<p class=\"resumen\">%d objetos (clusters de mobiliario) + %d piezas de arquitectura." % [
			info_clusters.size(), info_arq.size()
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
		push_error("RenderDespieceObjetos: no se pudo escribir %s (error %d)" % [
			ruta, FileAccess.get_open_error()
		])
		return
	archivo.store_string(html)
	archivo.close()
