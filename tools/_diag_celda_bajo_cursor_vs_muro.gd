extends SceneTree
## DIAGNÓSTICO DESECHABLE (headless, sin GPU) — BUG2 playtest 2026-08-06: "las cuadrículas al
## construir no cuadran" / "el resaltado se desvía de la rejilla, cada vez más por fila".
##
## HIPÓTESIS (ver `src/main/paredes_salas.gd::tramo_bajo_punto`, comentario 2026-08-06): el picking
## de SUELO puro (`Construccion.celda_de_punto` / `celda_bajo_cursor`, sin altura) confunde un punto
## sobre la CARA VISIBLE de una pared (que sube `ParedesSalas.ALTO_PARED` px en pantalla) con la
## celda de DETRÁS de esa pared. El fix de ayer (`tramo_bajo_punto`, point-in-quad) SOLO se enchufó
## en `ModoConstruccion._celda_lado_de_muro_en` — usado nada más por pintar pared / puerta-ventana /
## demoler sobre un muro YA CONSTRUIDO. `Construccion.celda_bajo_cursor()` (la que alimenta el
## resaltado EN VIVO de `_process` para TODAS las demás herramientas — sala nueva, puesto, asiento,
## comodidad, pincel de muro NUEVO) sigue sin el fix: NO hay quad, NO hay altura.
##
## Este diagnóstico NO necesita ratón ni GPU: reconstruye el mismo QUAD que `TramoPared._draw` (y
## que ya usa `tramo_bajo_punto`) para una pared conocida y comprueba con matemática pura cuántas
## FILAS de diferencia hay entre "la celda que el jugador cree pisar" (un punto sobre la cara visible
## de esa pared) y "la celda que devuelve el picking de suelo puro" para ese mismo punto de pantalla.
## Repite la prueba para VARIAS filas para demostrar que el desfase es CONSTANTE en celdas de
## rejilla lógica (1 fila por cada `ALTO_PARED` px de altura mirada) pero se PERCIBE como progresivo
## porque cuantas más paredes hay entre el cursor y la cámara, más a menudo el puntero cae sobre
## una cara en vez de sobre suelo limpio.
##
## Ejecutar (motor CERRADO, no en paralelo con la partida en curso). ⚠️ Hace falta `--path`, Y las
## dependencias se cargan con `load()` DIFERIDO dentro de `_initialize()` (nunca `preload`/`const` a
## nivel de script): `--script` compila el script del bucle principal ANTES de que el motor registre
## los autoloads (`Datos` incluido) como identificador global -- un `preload` de `construccion.gd`
## en cabecera dispara esa compilación demasiado pronto ("Identifier not found: Datos") y, como el
## fallo ocurre en carga (antes de que corra ninguna función nuestra), nadie llega a llamar a
## `quit()`: la sonda se "cuelga" de verdad, no es un bug de lógica. Con `load()` dentro de
## `_initialize()` (que el motor llama YA con los autoloads en pie) la misma clase compila bien.
##   godot --headless --path <ruta-al-proyecto> --script res://tools/_diag_celda_bajo_cursor_vs_muro.gd
## "PASA" si el punto sobre la cara de la pared, llevado por picking de SUELO puro, cae en una fila
## distinta de la fila real del muro (demuestra el defecto); "FALLA" si por algún motivo coincidiera
## (indicaría que la hipótesis NO es la causa y hay que seguir buscando).
##
## FIX (2026-08-06): además de "viejo" (picking de suelo puro, el bug), imprime "nuevo" — la MISMA
## cuenta que hace `ModoConstruccion._celda_bajo_cursor_consciente_de_muros()` (quad de
## `tramo_bajo_punto` → `Construccion.celda_y_lado_de_clave`, con el mismo fallback a suelo si no
## hay pared) — y "esperado" (la celda cuyo NORTE es la cara pinchada). Con el fix aplicado,
## nuevo == esperado en las tres filas; viejo sigue fallando (documenta el ANTES sin repetir la
## sesión de motor).
##
## RONDA 2 (2026-08-06, "sigue desviado, no tanto como antes" jugando con zoom/pan): el bloque de
## arriba llama a `paredes.tramo_bajo_punto(punto)`/`_celda_lado_de_muro_en` DIRECTO, puenteando la
## ADQUISICIÓN del punto (`get_global_mouse_position()`), que es justo donde vive el segundo bug
## (la CanvasLayer del fantasma no seguía a la cámara — ver el fix en `modo_construccion.gd::
## _crear_ui`/`_process`, 2026-08-06). Puenteando la adquisición, esta sonda NUNCA podía reproducir
## ese bug — pasaba SIEMPRE, aunque el juego real siguiera desviado. `_probar_camino_real_con_camara`
## (más abajo) tapa ese agujero: monta un `Camera2D` de verdad con PAN y ZOOM ≠ 1 (mismo
## `ANCHOR_MODE_FIXED_TOP_LEFT` que `Main._crear_camara`), un `ModoConstruccion` real colgado del
## MISMO árbol que la cámara (`configurar()` ANTES de `add_child` — el orden real de `main.gd`;
## invertido revienta `_crear_ui` con `_construccion` aún nulo, gotcha ya sufrido en el test de
## GdUnit de esta misma tanda), inyecta el punto de PANTALLA con un `InputEventMouseMotion` de
## verdad por `root.push_input()` (actualiza el ratón trackeado del Viewport SIN DisplayServer, vale
## para headless) y llama a `_celda_bajo_cursor_consciente_de_muros()` -- la función de producción
## exacta, cero atajos. El punto de pantalla se calcula por la fórmula INVERSA de la que ya usa y
## documenta `Main._cambiar_zoom` (`mundo = pantalla·zoom + posición` → `pantalla = (mundo -
## posición) / zoom`), así que si el motor calcula la transformada igual que la fórmula documentada,
## la ida (mundo → pantalla, aquí) y la vuelta (pantalla → mundo, dentro del wrapper real) se
## cancelan y `esperado` sigue siendo la misma celda de siempre -- SIN cámara igual que CON ella.
##
## ⚠️ NOTA: esta ronda 2 solo puede demostrar que la PICKING (selección de celda) sobrevive a la
## cámara -- lo que YA se sospechaba correcto, porque `get_global_mouse_position()` deshace la
## cámara sola. El bug real de "cursor desviado con zoom" era de DIBUJO (la `CanvasLayer` del
## fantasma no seguía la cámara al pintar el rombo verde), no de picking -- eso NO es observable
## sin GPU/ventana; lo prueba `tools/_diag_picking_visual.gd` (sonda visual, con cámara forzada
## igual que aquí, ver su propia cabecera tras el fix de hoy).

const SALA := &"sala_documentacion"
## Filas de prueba: cuantas más paredes "detrás" del cursor, más veces se dispara el defecto en una
## sesión de juego real — no porque el desfase crezca en sí, sino porque hay más ocasiones de que el
## punto caiga sobre una cara en vez de sobre suelo limpio. Se prueba con 1, 3 y 6 tramos de por medio.
const FILAS_DE_PRUEBA: Array[int] = [1, 3, 6]


## `_initialize()`, NO `_init()`: `_init()` corre en el CONSTRUCTOR del `SceneTree`, ANTES de que el
## motor añada los autoloads (`Datos` incluido) bajo `root` -- por eso la sonda se colgaba (fallo de
## compilación en cascada por "Identifier not found: Datos", y el `_init()` roto nunca llegaba a
## `quit()`, dejando el bucle principal vivo para siempre). Mismo patrón que `_diag_impresora_dni.gd`.
func _initialize() -> void:
	# `load()` (no `preload`/`const`) A PROPÓSITO -- ver la cabecera de este fichero.
	var ConstruccionScript: GDScript = load("res://src/core/construccion/construccion.gd")
	var ConfigConstruccionScript: GDScript = load("res://src/core/construccion/config_construccion.gd")
	var ParedesSalasScript: GDScript = load("res://src/main/paredes_salas.gd")

	# SEGUNDO gotcha de esta sonda (el primero fue el compile-order de arriba): el autoload `Datos`
	# YA está registrado como identificador global aquí, pero su `_ready()` (el que rellena el
	# catálogo -- `_cargar_catalogo()`) todavía NO ha corrido: los autoloads se añaden al árbol antes
	# de `_initialize()`, pero `_ready()` no se dispara hasta el primer barrido de notificaciones del
	# bucle principal, que en modo `--script` es DESPUÉS de este punto. Sin esto, `TipoSala` sale
	# vacío y ni la sala ni sus muros llegan a crearse (confirmado con sonda: 0 tipos antes, 5
	# después). `root.get_node("Datos")` evita escribir el identificador "Datos" en ESTE fichero
	# (que sí se compila pronto, antes del registro -- el mismo problema del primer gotcha).
	root.get_node("Datos").call("_cargar_catalogo")

	# Tipado explícito `Variant` (no `:=`): `ConstruccionScript` es un `GDScript` genérico (viene de
	# `load()`, no de `preload` con `class_name` -- ver la cabecera), así que `.new()` no tiene tipo
	# estático que inferir; este proyecto trata los warnings como error y `:=` aquí lo dispararía.
	var construccion: Variant = ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(40, Vector2.ZERO)
	# QUINTO gotcha (el más sutil): "una sala por fila, apiladas" solo es cierto en el COMENTARIO --
	# el código original creaba UNA sola sala de `FILAS_DE_PRUEBA[-1] + 2` filas de alto.
	# `_aristas_del_perimetro` solo pone muro en el CONTORNO de la sala, así que esa sala única solo
	# tenía tramo NORTE en su fila 0 (techo) y SUR en su última fila -- CERO tramos interiores en las
	# filas 1/3/6 (confirmado con sonda: `paredes._tramos` traía `h:*:0` y `h:*:8`, nunca `h:*:1`,
	# `h:*:3` ni `h:*:6`), así que `tramo_bajo_punto` nunca podía acertar y la sonda no demostraba
	# nada. Arreglo: una sala DE VERDAD por fila (tira de 1 celda de alto), separadas por huecos, cada
	# una con su propio tramo norte exactamente en su fila.
	for fila: int in FILAS_DE_PRUEBA:
		var rect := Rect2i(0, fila, 4, 1)
		# TERCER gotcha de esta sonda: `_crear_sala` devuelve un ID DE INSTANCIA autogenerado
		# ("sala_N"), no el `SALA` (tipo de sala) que se le pasa como argumento --
		# `fijar_paredes_de_sala` necesita ESE id de instancia, si no, avisa "sala inexistente" y no
		# levanta ni un muro.
		var sala_id: StringName = construccion._crear_sala(SALA, rect)
		# CUARTO gotcha: `con_paredes=true` LEVANTA muros (`false` los DERRIBA) -- el original pasaba
		# `false`, así que nunca había ni un solo muro que `tramo_bajo_punto` pudiera acertar.
		construccion.fijar_paredes_de_sala(sala_id, true)

	var paredes: Variant = ParedesSalasScript.new()
	# `configurar()` (la API real de `ParedesSalas` -- no existe `usar_construccion`, causa de que
	# esta sonda se colgara: el error de compilación al arrancar dejaba el bucle principal vivo sin
	# que nadie llamara a `quit()`) ya hace el primer `actualizar()` por dentro.
	paredes.configurar(construccion, 40, Vector2.ZERO)

	var fallos_bug_no_reproducido: int = 0
	var fallos_fix: int = 0
	for fila: int in FILAS_DE_PRUEBA:
		# El tramo NORTE de la celda (1, fila): de esquina (1,fila) a (2,fila), subiendo ALTO_PARED.
		var desde: Vector2 = construccion.esquina_en_pantalla(1, fila)
		var hasta: Vector2 = construccion.esquina_en_pantalla(2, fila)
		var medio_arriba: Vector2 = (desde + hasta) / 2.0 + Vector2(0.0, -ParedesSalasScript.ALTO_PARED * 0.5)
		# 1) Lo que YA arregló ayer el picking por quad: identifica la cara de verdad.
		var tramo: Dictionary = paredes.tramo_bajo_punto(medio_arriba)
		var acierta_quad: bool = not tramo.is_empty()
		# 2) Lo que SIGUE usando `celda_bajo_cursor` (aquí, su gemela sin mouse: `celda_de_punto`,
		#    mismo camino matemático — ver la cabecera de `Construccion.celda_de_punto`): picking de
		#    SUELO puro sobre el MISMO punto de pantalla.
		var celda_suelo: Vector2i = construccion.celda_de_punto(medio_arriba)
		var desfase_filas: int = fila - celda_suelo.y
		var demuestra_el_bug: bool = acierta_quad and desfase_filas != 0
		if not demuestra_el_bug:
			fallos_bug_no_reproducido += 1
		# 3) El FIX: misma cuenta que `ModoConstruccion._celda_bajo_cursor_consciente_de_muros()`.
		var esperado := Vector2i(1, fila)
		var celda_nueva: Vector2i = celda_suelo
		if acierta_quad:
			var par: Array = construccion.celda_y_lado_de_clave(String(tramo["clave_modelo"]))
			if par[1] != &"":
				celda_nueva = par[0]
		var fix_ok: bool = celda_nueva == esperado
		if not fix_ok:
			fallos_fix += 1
		print(
			(
				"[DIAG CELDA/MURO] fila_muro=%d viejo(suelo_puro)=%s nuevo(consciente_de_muros)=%s "
				+ "esperado=%s desfase_viejo=%d -> viejo=%s fix=%s"
			)
			% [
				fila, celda_suelo, celda_nueva, esperado, desfase_filas,
				"BUG (viejo se desvia %d fila(s))" % desfase_filas if demuestra_el_bug else "sin desvio",
				"PASA (nuevo == esperado)" if fix_ok else "FALLA (nuevo != esperado)",
			]
		)
	print("[DIAG CELDA/MURO] RESUMEN: bug_viejo_reproducido=%d/%d fix_correcto=%d/%d -> %s" % [
		FILAS_DE_PRUEBA.size() - fallos_bug_no_reproducido, FILAS_DE_PRUEBA.size(),
		FILAS_DE_PRUEBA.size() - fallos_fix, FILAS_DE_PRUEBA.size(),
		"OK" if fallos_fix == 0 else "REVISAR",
	])

	var fallos_camara: int = await _probar_camino_real_con_camara(construccion, paredes)
	print("[DIAG CELDA/MURO] RESUMEN RONDA 2 (cámara pan+zoom, camino real): %d/%d filas OK -> %s" % [
		FILAS_DE_PRUEBA.size() - fallos_camara, FILAS_DE_PRUEBA.size(),
		"OK" if fallos_camara == 0 else "REVISAR",
	])
	quit()


## RONDA 2 (ver la cabecera del fichero): mismo edificio ya construido (`construccion`/`paredes`,
## reutilizados -- las salas por fila de `_initialize` ya están de pie), pero esta vez con una
## `Camera2D` de verdad, PAN y ZOOM ≠ 1, y el punto de pantalla entregado por el CAMINO REAL
## (`InputEventMouseMotion` -> `_celda_bajo_cursor_consciente_de_muros()`), no puenteado. Devuelve
## el número de filas que NO coinciden con lo esperado (0 = todo bien).
func _probar_camino_real_con_camara(construccion: Variant, paredes: Variant) -> int:
	# `load()`, no la clase global `ParedesSalas` a secas: mismo motivo que el resto del fichero
	# (evitar CUALQUIER identificador especial escrito a nivel de script en el fichero que compila
	# `--script`, aunque `class_name` se resuelva por un camino distinto al de los autoloads -- no
	# vale la pena arriesgarse sin poder ejecutar y comprobar).
	var ModoConstruccionScript: GDScript = load("res://src/main/modo_construccion.gd")
	var ParedesSalasScript: GDScript = load("res://src/main/paredes_salas.gd")

	# Cámara con PAN y ZOOM ≠ 1 A PROPÓSITO -- si la picking dependiera (mal) de que zoom=1/pos=0,
	# esto lo dispara. Valores arbitrarios, deliberadamente "feos" (no medio-píxel, no cuadrados).
	var camara := Camera2D.new()
	camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camara.zoom = Vector2(1.65, 1.65)
	camara.position = Vector2(-137.0, 58.0)
	root.add_child(camara)

	# `configurar()` ANTES de `add_child()` -- el orden REAL de `Main._ready` (ver la cabecera):
	# invertido, `_ready()` -> `_crear_ui()` lee `_construccion` todavía nulo y revienta.
	var modo: Variant = ModoConstruccionScript.new()
	modo.configurar(construccion, 40, paredes)
	root.add_child(modo)   # dispara _ready(): crea la UI real (barra, atenuador, capa de fantasma)

	# ⚠️ SEXTO gotcha (este SÍ es del ARNÉS, no del juego -- separado a propósito, ver el informe):
	# en modo `--script`, `root.add_child()` durante `_initialize()` NO deja a los hijos
	# "is_inside_tree()" hasta el SIGUIENTE frame -- `camara.make_current()` y `root.push_input()`
	# revientan con "Condition '!is_inside_tree()' is true" si se llaman en el MISMO frame, y
	# `get_global_mouse_position()` (dentro del wrapper real) devuelve (0,0) en silencio en vez de
	# fallar fuerte -- por eso las 3 filas caían siempre en la MISMA celda (1,1): no era la cámara
	# desviando el picking, era el arnés preguntando por un ratón sin viewport todavía. Un
	# `await process_frame` basta -- confirmado por el mismo patrón ya documentado para `Datos`
	# (autoload) en la cabecera de este fichero: cosas que dependen de que el árbol esté "vivo de
	# verdad" no lo están todavía dentro de `_initialize()` en frío.
	await process_frame
	camara.make_current()

	var fallos: int = 0
	for fila: int in FILAS_DE_PRUEBA:
		var desde: Vector2 = construccion.esquina_en_pantalla(1, fila)
		var hasta: Vector2 = construccion.esquina_en_pantalla(2, fila)
		var punto_mundo: Vector2 = (
			(desde + hasta) / 2.0 + Vector2(0.0, -float(ParedesSalasScript.ALTO_PARED) * 0.5)
		)
		# 🐛 SÉPTIMO gotcha (éste SÍ era del JUEGO, no del arnés -- ver el fix con fecha de hoy en
		# `Main._cambiar_zoom`): la fórmula de aquí estaba escrita al revés, copiando el comentario
		# viejo (también incorrecto) de `main.gd`. Comprobado contra `get_canvas_transform()` real
		# del motor: con `ANCHOR_MODE_FIXED_TOP_LEFT`, mundo = pantalla/zoom + posición -> pantalla =
		# (mundo - posición) * zoom (MULTIPLICAR, no dividir).
		var punto_pantalla: Vector2 = (punto_mundo - camara.position) * camara.zoom

		# 🐛 OCTAVO gotcha (ARNÉS): `root.push_input(evento)` NO actualiza el ratón trackeado del
		# Viewport en modo `--script` headless (confirmado con sonda aparte: se queda en (0,0)
		# SIEMPRE, pase lo que pase en `evento.position` -- por eso las 3 filas daban la MISMA celda
		# sin importar el punto). `Input.parse_input_event()` SÍ lo actualiza (confirmado: (0,0) ->
		# (111,222) tras un `await process_frame`) -- es el camino GLOBAL del singleton `Input`, no
		# el de la cola de eventos del Viewport, y sí sobrevive sin `DisplayServer`.
		var evento := InputEventMouseMotion.new()
		evento.position = punto_pantalla
		evento.global_position = punto_pantalla
		Input.parse_input_event(evento)
		await process_frame

		var celda_obtenida: Vector2i = modo._celda_bajo_cursor_consciente_de_muros()
		var esperado := Vector2i(1, fila)
		var ok: bool = celda_obtenida == esperado
		if not ok:
			fallos += 1
		print(
			"[DIAG CELDA/MURO][CAMARA zoom=%.2f pos=%s] fila=%d punto_mundo=%s punto_pantalla=%s celda_obtenida=%s esperado=%s -> %s"
			% [
				camara.zoom.x, camara.position, fila, punto_mundo, punto_pantalla,
				celda_obtenida, esperado, "PASA" if ok else "FALLA",
			]
		)
	return fallos
