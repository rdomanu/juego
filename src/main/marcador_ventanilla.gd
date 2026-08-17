class_name MarcadorVentanilla
extends Node2D
## MarcadorVentanilla — el REALCE en el mundo de la ventanilla cuya ficha está abierta (F3,
## 2026-08-18; `design/ux/maquetas-menu-2026-08/maqueta_ventanilla.py::marcador_mundo`).
##
## ── POR QUÉ UNA CAPA SUELTA Y NO UN HIJO DEL MUEBLE ─────────────────────────────────────────────
## El gotcha histórico del proyecto (ver la cabecera larga de `CapaSombras`): TODO `CanvasItem`
## colgado de la bolsa y-sort (`MundoProfundo`) entra en el reparto de capas del ADR-0005, y los
## nacidos durante la carga ni siquiera se pintan. Un halo de selección no es "parte del mueble":
## es UI dibujada sobre el mundo. Por eso vive aquí, HERMANO de la bolsa (igual que `CapaSombras`),
## con `z_index` alto para quedar por encima de la mesa que realza — así el jugador ve el rombo
## aunque la ventanilla esté tapada por una pared o por un muñeco.
##
## ── CONTRATO ────────────────────────────────────────────────────────────────────────────────────
## Nadie le pasa ids de elemento ni celdas: recibe CENTROS YA PROYECTADOS a coordenadas de mundo
## (`Construccion.centro_en_pantalla`) y una etiqueta. Así no depende de Construcción y se puede
## probar con dos puntos a mano (regla del proyecto: inyección antes que singleton).
##
## Se dibuja QUIETO (sin parpadeo ni pulso): `.claude/rules/ui-code.md` pide que toda animación
## respete las preferencias de movimiento del jugador, y un marcador que late no aporta nada que no
## diga ya el contorno.

## Por encima de todo lo que se apoya en el suelo (la bolsa y-sort trabaja alrededor de z 0).
const Z_MARCADOR: int = 400
## Semiejes del rombo de una celda (los del plano isométrico: `Proyeccion.ANCHO_ROMBO`/`ALTO_ROMBO`).
const SEMIANCHO_CELDA: float = 40.0
const SEMIALTO_CELDA: float = 20.0
## Relleno y contorno del halo (acento azul del kit moderno, con sus alfas de la maqueta).
const COLOR_ACENTO := Color(0.184, 0.424, 0.878, 1.0)
const ALFA_RELLENO: float = 0.16
const ALFA_CONTORNO: float = 0.85
const GROSOR_CONTORNO: float = 2.0
## Pastilla flotante con el nombre visible ("DNI 1"), encima de la celda más alta del mueble.
const ALTO_ETIQUETA: float = 26.0
const PAD_ETIQUETA: float = 10.0
const TAM_FUENTE_ETIQUETA: int = 13
const SEPARACION_ETIQUETA: float = 34.0

## Centros (en coordenadas de mundo) de las celdas que ocupa la ventanilla realzada.
var _centros: Array[Vector2] = []
## Nombre visible de la ventanilla ("DNI 1"); vacío = sin pastilla.
var _etiqueta: String = ""
## Fuente de la pastilla (la del kit moderno; se inyecta para no acoplar esta capa al kit).
var _fuente: Font = null


func _ready() -> void:
	z_index = Z_MARCADOR


## Enciende el marcador sobre esas celdas (centros de mundo) con esa etiqueta. Volver a llamarlo
## con otra ventanilla mueve el realce; no hace falta apagarlo antes.
func resaltar(centros: Array[Vector2], etiqueta: String, fuente: Font = null) -> void:
	_centros = centros
	_etiqueta = etiqueta
	if fuente != null:
		_fuente = fuente
	visible = not _centros.is_empty()
	queue_redraw()


## Apaga el marcador (al cerrar la ficha). Idempotente.
func limpiar() -> void:
	_centros = []
	_etiqueta = ""
	visible = false
	queue_redraw()


## ¿Está encendido? (para tests y sondas — nada de leer estado privado desde fuera).
func esta_encendido() -> bool:
	return visible and not _centros.is_empty()


func _draw() -> void:
	if _centros.is_empty():
		return
	var relleno: Color = Color(COLOR_ACENTO.r, COLOR_ACENTO.g, COLOR_ACENTO.b, ALFA_RELLENO)
	var contorno: Color = Color(COLOR_ACENTO.r, COLOR_ACENTO.g, COLOR_ACENTO.b, ALFA_CONTORNO)
	var mas_alto: Vector2 = _centros[0]
	for centro: Vector2 in _centros:
		var rombo: PackedVector2Array = _rombo(centro)
		draw_colored_polygon(rombo, relleno)
		# El contorno se cierra a mano (`draw_polyline` no une el último punto con el primero).
		var cerrado: PackedVector2Array = rombo.duplicate()
		cerrado.append(rombo[0])
		draw_polyline(cerrado, contorno, GROSOR_CONTORNO, true)
		if centro.y < mas_alto.y:
			mas_alto = centro
	_dibujar_etiqueta(mas_alto)


## El rombo isométrico de una celda centrado en `centro`.
func _rombo(centro: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		centro + Vector2(-SEMIANCHO_CELDA, 0.0),
		centro + Vector2(0.0, -SEMIALTO_CELDA),
		centro + Vector2(SEMIANCHO_CELDA, 0.0),
		centro + Vector2(0.0, SEMIALTO_CELDA),
	])


## La pastilla con el nombre visible, flotando sobre la celda más al fondo del mueble.
func _dibujar_etiqueta(centro: Vector2) -> void:
	if _etiqueta == "" or _fuente == null:
		return
	var ancho_texto: float = _fuente.get_string_size(
		_etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAM_FUENTE_ETIQUETA
	).x
	var ancho: float = ancho_texto + PAD_ETIQUETA * 2.0
	var caja := Rect2(
		centro + Vector2(-ancho / 2.0, -SEPARACION_ETIQUETA - ALTO_ETIQUETA),
		Vector2(ancho, ALTO_ETIQUETA)
	)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_ACENTO
	estilo.set_corner_radius_all(int(ALTO_ETIQUETA / 2.0))
	draw_style_box(estilo, caja)
	# La línea base del texto: centrada a ojo dentro de la pastilla (el ascendente de Segoe UI a
	# 13 px cae ~4 px por debajo del centro geométrico).
	draw_string(
		_fuente, caja.position + Vector2(PAD_ETIQUETA, ALTO_ETIQUETA * 0.5 + TAM_FUENTE_ETIQUETA * 0.36),
		_etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAM_FUENTE_ETIQUETA, Color.WHITE
	)
