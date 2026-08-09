extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — monta UNA ventanilla con el CÓDIGO REAL del juego
## (`NPCsFlujo._asegurar_visual_puesto` + `_reconstruir_cuerpo_policia` + `colocar_muneco`, con
## `MesaAtencion` de verdad) sobre una rejilla de rombos dibujada, vuelca por consola la posición
## LOCAL y GLOBAL de cada nodo visual junto al valor ESPERADO calculado directo de las constantes,
## y guarda una captura PNG del viewport.
##
## Por qué así y no un fotomontaje: el bug del 2026-08-03 es una DIVERGENCIA entre lo que dicen las
## constantes y lo que el árbol real dibuja, así que cualquier reconstrucción por fuera del motor
## lo taparía. Aquí se instancia el nodo REAL `NPCsFlujo` (con stubs mínimos de flujo/construcción/
## personal, que `_asegurar_visual_puesto` solo usa para `es_huella_legado`) y se llaman SUS
## funciones — cero copias de código de colocación.
##
## Uso:  godot --path <repo> res://tools/_diag_ventanilla2.tscn -- <etiqueta>
## Se borra tras usarlo — no es parte del pipeline final.

const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")
const NPCScript := preload("res://src/main/npc_ciudadano.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const CELDA_PUESTO := Vector2i(2, 2)
const PUESTO_ID: StringName = &"P_DIAG"
## El origen de la rejilla, elegido para que la ventanilla quede centrada en la ventana de 1600×900.
const POS_SUELO := Vector2(800.0, 350.0)
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/75e951ac-fc51-440b-b566-49ccd66ebf86/scratchpad/"
const NOMBRE_OFICIAL := "Ana Torres"


## Stub de Construcción: `_asegurar_visual_puesto` solo le pregunta si el puesto es huella legado.
class ConstruccionStub extends Node:
	func es_huella_legado(_elemento_id: StringName) -> bool:
		return false


## La rejilla de rombos del suelo, para juzgar A OJO si cada elemento cae en SU celda.
class Rejilla extends Node2D:
	var celdas: Array[Vector2i] = []
	var destacadas: Array[Vector2i] = []

	func _draw() -> void:
		for celda: Vector2i in celdas:
			var rombo: PackedVector2Array = Proyeccion.rombo_de_celda(celda)
			var color: Color = (
				Color(0.30, 0.32, 0.30) if celda in destacadas else Color(0.20, 0.21, 0.20)
			)
			draw_colored_polygon(rombo, color)
		for celda: Vector2i in celdas:
			var rombo: PackedVector2Array = Proyeccion.rombo_de_celda(celda)
			var cerrado := PackedVector2Array(rombo)
			cerrado.append(rombo[0])
			draw_polyline(cerrado, Color(0.45, 0.47, 0.45), 1.0)


var _flujo_visual: NPCsFlujo = null
var _muneco_ciudadano: Node2D = null


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.10, 0.10, 0.12)
	fondo.size = Vector2(1600, 900)
	fondo.z_index = -20
	add_child(fondo)

	var rejilla := Rejilla.new()
	rejilla.position = POS_SUELO
	rejilla.z_index = -10
	for x: int in range(0, 6):
		for y: int in range(0, 6):
			rejilla.celdas.append(Vector2i(x, y))
	# Las TRES celdas de la ventanilla + la 2ª celda del mostrador, en un gris más claro.
	rejilla.destacadas = [
		CELDA_PUESTO, CELDA_PUESTO + Vector2i(1, 0),
		CELDA_PUESTO + Vector2i(0, -1), CELDA_PUESTO + Vector2i(0, 1),
	]
	add_child(rejilla)

	_flujo_visual = NPCsFlujoScript.new()
	_flujo_visual.name = "NPCsFlujo"
	var construccion := ConstruccionStub.new()
	construccion.name = "ConstruccionStub"
	add_child(construccion)
	add_child(_flujo_visual)
	_flujo_visual.configurar(null, construccion, null, Proyeccion.TAM_CELDA, POS_SUELO, 24, 13)
	# Sin modelo detrás: el bucle de simulación no puede correr.
	_flujo_visual.set_physics_process(false)
	_flujo_visual.set_process(false)

	# ── EL CÓDIGO REAL DEL JUEGO ────────────────────────────────────────────────────────────────
	_flujo_visual._asegurar_visual_puesto(PUESTO_ID, CELDA_PUESTO)
	var contenedor: Node2D = _flujo_visual._visual_de_puesto[PUESTO_ID]
	# El titular sentado (misma llamada que hace `_actualizar_visual_puesto` al cambiar de dueño).
	var policia: Node2D = contenedor.get_node("Policia") as Node2D
	_flujo_visual._reconstruir_cuerpo_policia(contenedor, policia, NOMBRE_OFICIAL)
	# PRUEBA A/B del alzado del sentado (2º argumento de la línea de órdenes): `sin_alzado` anula
	# `ALZADO_SENTADO_FUNCIONARIO` para ver si sigue haciendo falta ahora que el policía está en SU
	# celda. No toca el juego: solo este diagnóstico.
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	if argumentos.size() > 1 and argumentos[1] == "sin_alzado":
		policia.position = MesaAtencionScript.CELDA_FUNCIONARIO
	# La ciudadana a la que atienden: muñeco igual que el de `npc_ciudadano._crear_muneco`, colocado
	# por `colocar_muneco` desde el CENTRO DE LA CELDA SUR (que es lo que le da el modelo) y marcado
	# como "en el frente del puesto" — el camino exacto del juego.
	_muneco_ciudadano = Node2D.new()
	_muneco_ciudadano.name = "MunecoCiudadano"
	if MunecoScript.hay_sprites(NPCScript.PREFIJO_SPRITE, NPCScript.ALTO_SPRITE):
		_muneco_ciudadano.add_child(
			MunecoScript.construir_sprite(NPCScript.PREFIJO_SPRITE, NPCScript.ALTO_SPRITE)
		)
	else:
		_muneco_ciudadano.add_child(MunecoScript.construir(Color(0.35, 0.55, 0.9)))
	_muneco_ciudadano.set_meta(&"sentado", true)
	_flujo_visual.registrar_muneco(_muneco_ciudadano)
	_flujo_visual.marcar_frente_de_puesto(_muneco_ciudadano, true)
	var frente: Vector2 = Proyeccion.centro_cuadrado(CELDA_PUESTO + Vector2i(0, 1))
	_flujo_visual.colocar_muneco(_muneco_ciudadano, frente)

	await RenderingServer.frame_post_draw
	_volcar(contenedor)
	await RenderingServer.frame_post_draw
	_capturar()
	get_tree().quit()


## Vuelca posiciones REALES vs ESPERADAS. Lo esperado se recalcula aquí desde cero con las
## constantes públicas (`ARRIME_*`, `DESVIO_*`) siguiendo la regla ESCRITA en `mesa_atencion.gd`:
## «cada uno en el CENTRO DE SU CELDA, arrimado `ARRIME` pasos hacia el mostrador», más el
## desvío de centrado de la atención. Si el árbol no cuadra con esto, el árbol miente.
func _volcar(contenedor: Node2D) -> void:
	var paso_sur: Vector2 = (
		Proyeccion.centro_iso(CELDA_PUESTO + Vector2i(0, 1)) - Proyeccion.centro_iso(CELDA_PUESTO)
	)
	var paso_norte: Vector2 = -paso_sur
	var esp_ciudadano: Vector2 = (
		paso_sur + paso_norte * MesaAtencionScript.ARRIME_CIUDADANO
		+ MesaAtencionScript.DESVIO_CENTRADO_ATENCION
	)
	var esp_funcionario: Vector2 = (
		paso_norte + paso_sur * MesaAtencionScript.ARRIME_FUNCIONARIO
		+ MesaAtencionScript.DESVIO_CENTRADO_ATENCION
	)
	var esp_tablero: Vector2 = (
		Proyeccion.delta_ultima_celda(Vector2i(1, 0), 2) + MesaAtencionScript.DESVIO_CENTRADO_MESA
	)

	print("========== DIAG VENTANILLA 2 ==========")
	print("celda puesto=%s  contenedor.global=%s  pos_suelo=%s" % [
		CELDA_PUESTO, contenedor.global_position, POS_SUELO
	])
	print("Proyeccion: MEDIO_ANCHO=%.3f MEDIO_ALTO=%.3f  paso_sur=%s paso_norte=%s" % [
		Proyeccion.MEDIO_ANCHO, Proyeccion.MEDIO_ALTO, paso_sur, paso_norte
	])
	print("CONSTANTES: FONDO_SILLA_ESPERA=%.5f FONDO_SILLA_FUNC=%.5f RETROCESO_CIUDADANO=%.3f" % [
		MesaAtencionScript.FONDO_SILLA_ESPERA, MesaAtencionScript.FONDO_SILLA_FUNCIONARIO,
		MesaAtencionScript.RETROCESO_CIUDADANO
	])
	print("            ARRIME_CIUDADANO=%.5f ARRIME_FUNCIONARIO=%.5f" % [
		MesaAtencionScript.ARRIME_CIUDADANO, MesaAtencionScript.ARRIME_FUNCIONARIO
	])
	print("            DESVIO_CENTRADO_ATENCION=%s DESVIO_CENTRADO_MESA=%s" % [
		MesaAtencionScript.DESVIO_CENTRADO_ATENCION, MesaAtencionScript.DESVIO_CENTRADO_MESA
	])
	print("            CELDA_CIUDADANO=%s  CELDA_FUNCIONARIO=%s" % [
		MesaAtencionScript.CELDA_CIUDADANO, MesaAtencionScript.CELDA_FUNCIONARIO
	])
	print("            DESVIO_DIBUJO_CIUDADANO=%s" % [MesaAtencionScript.DESVIO_DIBUJO_CIUDADANO])
	print("--- ÁRBOL REAL (hijos de %s, en orden de dibujo) ---" % contenedor.name)
	for hijo: Node in contenedor.get_children():
		if hijo is not Node2D:
			continue
		var n: Node2D = hijo as Node2D
		var capa: String = str(n.get_meta(&"capa_iso")) if n.has_meta(&"capa_iso") else "-"
		print("  %-22s capa=%s z=%d  local=%s  global=%s" % [
			n.name, capa, n.z_index, n.position, n.global_position
		])
		for nieto: Node in n.get_children():
			if nieto is Sprite2D:
				var s: Sprite2D = nieto as Sprite2D
				var origen: Vector2 = s.global_position + s.offset
				print("      sprite %-14s rect_global=(%.1f, %.1f)-(%.1f, %.1f)  tam=%s" % [
					s.texture.resource_path.get_file(), origen.x, origen.y,
					origen.x + s.texture.get_width(), origen.y + s.texture.get_height(),
					s.texture.get_size()
				])
	print("--- CIUDADANA (capa de muñecos, fuera del contenedor) ---")
	print("  MunecoCiudadano        z=%d  global=%s" % [
		_muneco_ciudadano.z_index, _muneco_ciudadano.global_position
	])
	print("--- ESPERADO (recalculado de las constantes, local al contenedor) ---")
	_comparar("SillaCiudadano/asiento", contenedor, "SillaCiudadano", esp_ciudadano)
	_comparar("SillaCiudadanoRespaldo", contenedor, "SillaCiudadanoRespaldo", esp_ciudadano)
	_comparar("SillaFuncionario", contenedor, "SillaFuncionario", esp_funcionario)
	_comparar("Mesa", contenedor, "Mesa", Vector2.ZERO)
	var tablero: Node2D = contenedor.get_node_or_null("Mesa/Tablero") as Node2D
	if tablero != null:
		_linea("Mesa/Tablero", tablero.position, esp_tablero)
	var esp_muneco: Vector2 = contenedor.global_position + esp_ciudadano
	_linea("MunecoCiudadano(global)", _muneco_ciudadano.global_position, esp_muneco)
	print("=======================================")


func _comparar(etiqueta: String, contenedor: Node2D, ruta: String, esperado: Vector2) -> void:
	var n: Node2D = contenedor.get_node_or_null(ruta) as Node2D
	if n == null:
		print("  %-24s AUSENTE" % etiqueta)
		return
	_linea(etiqueta, n.position, esperado)


func _linea(etiqueta: String, real: Vector2, esperado: Vector2) -> void:
	var d: Vector2 = real - esperado
	var marca: String = "OK " if d.length() < 0.01 else "*** DESVIADO ***"
	print("  %-24s real=(%.3f, %.3f)  esperado=(%.3f, %.3f)  delta=(%.3f, %.3f)  %s" % [
		etiqueta, real.x, real.y, esperado.x, esperado.y, d.x, d.y, marca
	])


func _capturar() -> void:
	var etiqueta: String = "captura"
	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	if argumentos.size() > 0:
		etiqueta = argumentos[0]
	var imagen: Image = get_viewport().get_texture().get_image()
	var ruta: String = "%sventanilla2_%s.png" % [CARPETA_SALIDA, etiqueta]
	var error: int = imagen.save_png(ruta)
	print("[DIAG VENTANILLA 2] captura -> %s (err=%d)" % [ruta, error])
