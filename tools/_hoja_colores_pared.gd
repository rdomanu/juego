extends Node2D
## HOJA DE COLORES DE PARED — mockup DESECHABLE (2026-08-04) para que el usuario ELIJA una paleta
## antes de diseñar la personalización de color de pared por sala. Hoy el color es fijo por TIPO de
## sala (`paredes_salas.gd:_color_de_pared`, ~línea 549); esto NO implementa la personalización, solo
## la enseña aplicada a seis salas reales para decidir sobre algo concreto, no sobre una paleta suelta.
##
## Seis salas idénticas (3×3, con puerta automática), cada una pintada con un candidato A-F (tonos
## apagados de tycoon, estilo Big Pharma). Se borra tras decidir — no es parte del pipeline final.
##
## ── CÓMO SE LOGRÓ EL COLOR POR SALA SIN TOCAR `paredes_salas.gd` ───────────────────────────────
## `_color_de_pared(sala_id)` es un método de INSTANCIA normal (ni `static` ni `const`) y las dos
## llamadas que tiene (líneas 253 y 517) son autollamadas implícitas (`_color_de_pared(...)`, sin
## calificar) — así que despachan por la clase REAL del objeto, no por dónde vive el método. Una
## SUBCLASE local que lo sobreescriba basta: no hace falta tocar el fichero original ni recurrir a
## `modulate` por tramo. Si en algún punto de la implementación real ese método pasara a `static` o a
## una función suelta (no debería, pero queda dicho), este camino se rompería y sí tocaría lo que
## pide el punto 7 del encargo: modular por tramo después del dibujo.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(1150, 750)

## Carpeta del scratchpad de esta sesión (fuera del repo).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"


## SUBCLASE LOCAL: mismo dibujo que `ParedesSalas`, un único método sobreescrito. `colores_por_sala`
## mapea sala_id -> Color; una sala sin entrada cae a un gris de emergencia (no debería pasar aquí,
## las seis se registran antes de `configurar()`).
class HojaParedesSalas extends ParedesSalasScript:
	var colores_por_sala: Dictionary = {}

	func _color_de_pared(sala_id: StringName) -> Color:
		return colores_por_sala.get(sala_id, Color(0.5, 0.5, 0.5))


## La paleta candidata (2026-08-04, propuesta por el usuario): tonos apagados, saturación contenida.
## A = azul actual — la que ya se ve en el juego hoy, como referencia; B-F son las alternativas.
const PALETA := {
	"A": Color(0.30, 0.38, 0.55),   # azul actual (referencia)
	"B": Color(0.36, 0.46, 0.36),   # verde salvia
	"C": Color(0.55, 0.36, 0.28),   # terracota
	"D": Color(0.55, 0.47, 0.24),   # mostaza
	"E": Color(0.42, 0.40, 0.38),   # gris cálido
	"F": Color(0.42, 0.26, 0.30),   # burdeos
}
const ETIQUETAS: Array[String] = ["A", "B", "C", "D", "E", "F"]

## Huella de cada sala (misma para las seis) y separación entre ellas, en celdas del plano lógico.
const LADO_SALA: int = 3
const HUECO: int = 2
const PASO: int = LADO_SALA + HUECO   # 5
const COLUMNAS: int = 3
const FILAS: int = 2


func _ready() -> void:
	await _construir_hoja()
	print("[HOJA COLORES] hecho -> %shoja_colores_pared.png" % CARPETA_SALIDA)
	get_tree().quit()


func _construir_hoja() -> void:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	# Fondo en su propia CanvasLayer (la cámara no debe moverlo) — mismo patrón que los diag existentes.
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)

	# Extensión total de la rejilla de 6 salas, en celdas (última sala termina en +LADO_SALA, sin el
	# hueco de después).
	var ancho_total: int = 1 + COLUMNAS * PASO - HUECO
	var alto_total: int = 1 + FILAS * PASO - HUECO
	var foco := Vector2(float(ancho_total) / 2.0 + 0.5, float(alto_total) / 2.0 + 0.5)
	var camara := Camera2D.new()
	camara.zoom = Vector2.ONE
	camara.position = ProyeccionScript.proyectar(foco * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()

	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)

	var paredes := HojaParedesSalas.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)
	construccion.levantar_fachada()

	# Seis salas idénticas (3×3), en rejilla 3×2, cada una con puerta automática y su color candidato.
	var ids: Array[StringName] = []
	var centros: Array[Vector2i] = []
	for fila: int in range(FILAS):
		for columna: int in range(COLUMNAS):
			var indice: int = fila * COLUMNAS + columna
			var x: int = 1 + columna * PASO
			var y: int = 1 + fila * PASO
			var rect := Rect2i(x, y, LADO_SALA, LADO_SALA)
			var sala: StringName = construccion.construir_de_oficio_sala(
				&"sala_documentacion", rect, StringName("sala_%s" % ETIQUETAS[indice])
			)
			if sala == &"":
				push_error("[HOJA COLORES] sala '%s' NO se pudo construir en %s" % [ETIQUETAS[indice], rect])
				continue
			construccion.fijar_paredes_de_sala(sala, true)
			ids.append(sala)
			centros.append(Vector2i(x + LADO_SALA / 2, y + LADO_SALA / 2))
			paredes.colores_por_sala[sala] = PALETA[ETIQUETAS[indice]]

	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)

	# Rejilla tenue de referencia sobre toda la extensión + contorno remarcado de cada huella (para
	# leer las 6 de un vistazo aunque dos candidatos queden parecidos).
	_marcar_rejilla_completa(mundo, ancho_total, alto_total)
	for i: int in range(ids.size()):
		var x: int = 1 + (i % COLUMNAS) * PASO
		var y: int = 1 + (i / COLUMNAS) * PASO
		_marcar_borde_sala(mundo, Rect2i(x, y, LADO_SALA, LADO_SALA), Color(1.0, 1.0, 1.0, 0.5))

	# Etiquetas A..F, grandes, centradas sobre cada sala.
	for i: int in range(ids.size()):
		var etiqueta := Label.new()
		etiqueta.text = ETIQUETAS[i]
		etiqueta.add_theme_font_size_override("font_size", 40)
		etiqueta.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
		etiqueta.add_theme_constant_override("outline_size", 6)
		var punto: Vector2 = ProyeccionScript.centro_iso(centros[i])
		etiqueta.position = punto - Vector2(20.0, 60.0)
		mundo.add_child(etiqueta)

	# Muñeco de pie junto a la sala A, como referencia de escala humana (misma familia de sprite que
	# usa el juego: "girl" 44px).
	var muneco: Node2D = MunecoScript.construir_sprite("girl", 44)
	var celda_muneco := Vector2i(1 + LADO_SALA, 1 + LADO_SALA / 2)   # calle a la derecha de la sala A
	muneco.position = ProyeccionScript.centro_iso(celda_muneco)
	mundo.add_child(muneco)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%shoja_colores_pared.png" % CARPETA_SALIDA
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[HOJA COLORES] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[HOJA COLORES] guardado -> %s" % ruta)


## Rejilla tenue de referencia: una línea por cada gridline de la extensión completa de la hoja.
func _marcar_rejilla_completa(mundo: Node2D, ancho: int, alto: int) -> void:
	var color := Color(1.0, 1.0, 1.0, 0.08)
	for x: int in range(ancho + 1):
		var linea := Line2D.new()
		linea.z_index = 5
		linea.width = 1.0
		linea.default_color = color
		linea.points = PackedVector2Array([
			ProyeccionScript.esquina_iso(x, 0), ProyeccionScript.esquina_iso(x, alto),
		])
		mundo.add_child(linea)
	for y: int in range(alto + 1):
		var linea := Line2D.new()
		linea.z_index = 5
		linea.width = 1.0
		linea.default_color = color
		linea.points = PackedVector2Array([
			ProyeccionScript.esquina_iso(0, y), ProyeccionScript.esquina_iso(ancho, y),
		])
		mundo.add_child(linea)


## Contorno remarcado de la huella de una sala.
func _marcar_borde_sala(mundo: Node2D, rect: Rect2i, color: Color) -> void:
	var borde := Line2D.new()
	borde.z_index = 6
	borde.width = 2.0
	borde.default_color = color
	borde.closed = true
	borde.points = PackedVector2Array([
		ProyeccionScript.esquina_iso(rect.position.x, rect.position.y),
		ProyeccionScript.esquina_iso(rect.end.x, rect.position.y),
		ProyeccionScript.esquina_iso(rect.end.x, rect.end.y),
		ProyeccionScript.esquina_iso(rect.position.x, rect.end.y),
	])
	mundo.add_child(borde)
