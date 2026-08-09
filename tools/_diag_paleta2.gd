extends Node2D
## SONDA GPU DESECHABLE (2026-08-08, encargo del usuario "en el city kit hay más casas... submenú:
## casas, carreteras, árboles y jardín, objetos" + "coches... que quepan cada uno en su carril").
## Mismo patrón que `_diag_ui_comparativa.gd`: instancia `Main.tscn` completo (necesita `--disenador`
## en el cmdline del PROCESO -- `-- --disenador` -- para que `Main` monte `ModoDisenadorEntorno`).
##
## Tres capturas al scratchpad de la sesión:
##  1. `paleta_casas.png` -- la paleta del diseñador con la pestaña 🏠 Casas activa (las 21).
##  2. `paleta_carreteras.png` -- la misma paleta con la pestaña 🛣 Carreteras activa (las 5).
##  3. `carriles_ingame.png` -- COMPOSICIÓN DE CARRILES: 3 `carretera_recta` en línea + 2
##     `coche_sedan` anclados con el mecanismo REAL del juego (`ModoDisenadorEntorno._colocar_pieza_en`
##     -> `_refrescar_pieza_visual` -> `AnclajeSprite.aplicar` + `Proyeccion.centro_iso`, exactamente
##     lo que usa un jugador colocando piezas a mano), uno rotación 90 (heading ESTE) y otro 270
##     (heading OESTE), en la celda transversal siguiente (offset 1 -- el único incremento posible
##     con el sistema de piezas por celda). Antes de capturar, MIDE con el mismo
##     `AnclajeSprite.semiejes_base` que usa el juego para anclar props si los dos footprints
##     (elipses de contacto en pantalla) se tocan o no, e imprime el número exacto -- SIN maquillar
##     el resultado si no caben (encargo explícito: "si NO caben, di el número").
##
## Se borra tras usarla -- no es parte del pipeline final.

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/1f7d5694-02c7-4fc1-9a44-a8546d82445c/scratchpad/"
const MainEscena := preload("res://src/main/Main.tscn")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")


func _ready() -> void:
	var main: Node2D = MainEscena.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	if main._modo_disenador_entorno == null:
		print("[DIAG PALETA2] SIN --disenador: Main no montó ModoDisenadorEntorno -- aborta")
		main.queue_free()
		get_tree().quit()
		return
	var modo: Node2D = main._modo_disenador_entorno

	# ── 1) y 2) LA PALETA, pestañas Casas / Carreteras ────────────────────────────────────────────
	modo.alternar()   # activa el modo -- _mostrar_categoria(&"casas") ya corrió en _crear_ui()
	modo.set_process(false)   # gotcha de _diag_ux_pintura.gd: no dejar que el ratón real pise el preview
	await get_tree().process_frame
	await _capturar("paleta_casas.png")

	modo._mostrar_categoria(&"carreteras")
	await get_tree().process_frame
	await _capturar("paleta_carreteras.png")

	# ── 3) CARRILES: 3 carretera_recta en línea + 2 coche_sedan anclados con el mecanismo real ─────
	# Celdas FUERA del rect jugable (24x13) -- zona vacía del scatter, columna muy negativa.
	# CORRECCIÓN 2026-08-08 (el usuario cazó la composición anterior "al revés"): con la carretera
	# corriendo por el eje X, los coches van a rotación 0/180 -- la base del modelo del carkit está
	# girada 90° respecto a la convención de la brújula (a rotación 90/270 los sedanes apuntaban a
	# los ARCENES, no a los carriles). Y cada loseta mide ~3,8 celdas de lado: se colocan cada 4
	# celdas para que se lean como tramo, no como una masa solapada.
	# COMPOSICIÓN NORTE-SUR (veredicto del usuario 2026-08-08: "los coches tienen que estar en
	# posición de morro y maletero norte-sur"): la calle corre por el eje Y (carretera_recta a
	# rotación 0) y los coches van a 0 (Sur) y 180 (Norte) -- en isométrico esas dos vistas enseñan
	# el tres-cuartos frontal/trasero y la dirección se LEE de un vistazo (las vistas de flanco
	# puro, 90/270, confundían al ojo aunque estuvieran alineadas con la calle).
	# UNA sola loseta bajo los coches y a rotación 90 (orden del usuario: "todo tiene que apuntar
	# norte-sur; cambia solo la orientación de la carretera y deja a los coches como están"):
	# a rotación 0 el ASFALTO del tile corre Este-Oeste; la vista N-S es la de 90.
	var fila_base: int = 36
	var col_carretera: int = -58
	modo._fijar_herramienta(&"carretera_recta")
	modo._orientacion = 90
	modo._colocar_pieza_en(Vector2i(col_carretera, fila_base + 5))

	# Un coche por carril: carril oeste (col-1) bajando al Sur, carril este (col+1) subiendo al
	# Norte -- separación 2 celdas, la única entera que cabe (ver _auditar_carriles).
	var celda_coche_a := Vector2i(col_carretera - 1, fila_base + 5)
	var celda_coche_b := Vector2i(col_carretera + 1, fila_base + 5)
	modo._fijar_herramienta(&"coche_sedan")
	modo._orientacion = 0
	modo._colocar_pieza_en(celda_coche_a)
	modo._orientacion = 180
	modo._colocar_pieza_en(celda_coche_b)

	# MEDICIÓN honesta con el MISMO `AnclajeSprite.semiejes_base` que ancla los props reales -- sobre
	# los sprites YA colocados (`_nodos_pieza`, mismo diccionario privado que usa `_refrescar_pieza_visual`).
	_auditar_carriles(modo, celda_coche_a, celda_coche_b)
	# Verificación de identidad (2026-08-08, caza del "los coches no giran"): qué rotación quedó
	# GUARDADA y qué PNG exacto está usando cada sprite colocado -- sin interpretar poses a ojo.
	for celda: Vector2i in [celda_coche_a, celda_coche_b]:
		var sp: Sprite2D = modo._nodos_pieza.get(celda) as Sprite2D
		print("[DIAG PALETA2] IDENTIDAD %s: rotacion_guardada=%s textura=%s" % [
			celda, modo._piezas[celda].get("rotacion"),
			sp.texture.resource_path if sp != null and sp.texture != null else "SIN SPRITE"
		])

	modo._fijar_herramienta(&"")
	await get_tree().process_frame

	# `global_position` del sprite YA colocado (no reconstruir el cálculo a mano -- mismo gotcha que
	# documenta `_diag_escala_casas_20260808.gd`: sumar `_origen` otra vez encima de una posición que
	# YA lo incluye descuadra la cámara).
	var sprite_a: Sprite2D = modo._nodos_pieza.get(celda_coche_a) as Sprite2D
	var sprite_b: Sprite2D = modo._nodos_pieza.get(celda_coche_b) as Sprite2D
	var centro_mundo: Vector2 = (sprite_a.global_position + sprite_b.global_position) * 0.5
	# `Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT` (ver `Main._cambiar_zoom`, comentario "FIX cursor
	# desviado"): `position` es el punto de MUNDO que cae en la esquina SUPERIOR IZQUIERDA de la
	# pantalla, no el centro -- `mundo = pantalla/zoom + posición`. Para centrar `centro_mundo` en
	# pantalla: `posición = centro_mundo − (tamaño_viewport/2)/zoom`.
	var zoom := Vector2(1.0, 1.0)
	main._camara.zoom = zoom
	main._camara.position = centro_mundo - (get_viewport().get_visible_rect().size * 0.5) / zoom
	modo._capa_ui.visible = false   # lienzo limpio para la captura de la composición
	await get_tree().process_frame
	await _capturar("carriles_ingame.png")

	print("[DIAG PALETA2] hecho.")
	get_tree().quit()


## Distancia entre los DOS centros de anclaje en pantalla vs. la suma de sus semiejes transversales
## (el "hueco" que hace falta para que las dos elipses de contacto no se toquen) -- MISMA fórmula de
## elipse normalizada que usa el motor para overlap 2D. Si el resultado normalizado < 1, las dos
## elipses SE SOLAPAN; se imprime el hueco que falta en px y en celdas (TAM_CELDA=40, misma unidad
## que ya usó `tools/_diag_medir_coches.gd` para hablar de "carriles").
func _auditar_carriles(modo: Node2D, celda_a: Vector2i, celda_b: Vector2i) -> void:
	var sprite_a: Sprite2D = modo._nodos_pieza.get(celda_a) as Sprite2D
	var sprite_b: Sprite2D = modo._nodos_pieza.get(celda_b) as Sprite2D
	if sprite_a == null or sprite_b == null:
		print("[DIAG PALETA2] AUDITORÍA CARRILES: no se encontraron los sprites colocados -- aborta medición")
		return
	var semi_a: Vector2 = AnclajeSpriteScript.semiejes_base(sprite_a.texture)
	var semi_b: Vector2 = AnclajeSpriteScript.semiejes_base(sprite_b.texture)
	# `semiejes_base` mide en el plano LÓGICO cuadrado (TAM_CELDA=40px/celda -- ver su cabecera, "por
	# TAM_CELDA, en píxeles del plano cuadrado"), NO en pantalla isométrica -- el delta entre anclas
	# tiene que vivir en el MISMO plano (`centro_cuadrado`, no `centro_iso`) para que la comparación
	# sea dimensionalmente correcta.
	var centro_a: Vector2 = ProyeccionScript.centro_cuadrado(celda_a)
	var centro_b: Vector2 = ProyeccionScript.centro_cuadrado(celda_b)
	var delta: Vector2 = centro_b - centro_a
	var distancia_px: float = delta.length()
	# Elipse normalizada: sqrt((dx/(ra.x+rb.x))^2 + (dy/(ra.y+rb.y))^2) -- 1.0 = tocándose exactas.
	var suma_x: float = semi_a.x + semi_b.x
	var suma_y: float = semi_a.y + semi_b.y
	var normalizado: float = sqrt(pow(delta.x / suma_x, 2.0) + pow(delta.y / suma_y, 2.0))
	print("[DIAG PALETA2] AUDITORÍA CARRILES: coche A celda=%s semiejes=%s | coche B celda=%s semiejes=%s" % [
		celda_a, semi_a, celda_b, semi_b
	])
	print("[DIAG PALETA2]   distancia entre anclas=%.1fpx (delta=%s) | elipse normalizada=%.4f (>=1.0 = NO se tocan)" % [
		distancia_px, delta, normalizado
	])
	if normalizado < 1.0:
		# Escalar el delta actual hasta normalizado=1.0 da la distancia MÍNIMA que haría falta.
		var distancia_necesaria: float = distancia_px / normalizado
		var hueco_px: float = distancia_necesaria - distancia_px
		print("[DIAG PALETA2]   ⚠ SE SOLAPAN. Haría falta %.1fpx más de separación (%.2f celdas de %d px) -- distancia actual %.1fpx, necesaria %.1fpx" % [
			hueco_px, hueco_px / float(ProyeccionScript.TAM_CELDA), ProyeccionScript.TAM_CELDA,
			distancia_px, distancia_necesaria
		])
	else:
		var sobra_px: float = distancia_px - (distancia_px / normalizado)
		print("[DIAG PALETA2]   ✓ NO se tocan. Margen sobrante=%.1fpx" % sobra_px)


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.save_png(CARPETA_SALIDA + nombre)
	print("[DIAG PALETA2] -> " + nombre)
