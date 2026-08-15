class_name CapaSombras
extends Node2D
## CapaSombras — el ÚNICO lienzo donde se pintan TODAS las sombras de contacto del juego.
##
## ── POR QUÉ UNA CAPA ÚNICA Y NO UN Sprite2D POR MUEBLE (2026-08-14, cazado con sondas) ──────────
## El primer intento colgaba un `Sprite2D` de sombra de cada mueble/muñeco. Los nodos existían,
## con propiedades y textura perfectas… y NO SE RENDERIZABAN: todo CanvasItem creado DURANTE LA
## CARGA como descendiente de `MundoProfundo` (la bolsa y-sort) queda permanentemente sin pintar
## en este árbol (no lo cura ni reparentar, ni `queue_redraw`, ni `visible` off/on; un
## `duplicate()` del mismo nodo sí pinta). No se pudo reproducir en escena mínima — es una
## interacción del árbol real que no merece más arqueología. La solución es NO vivir ahí: esta capa
## cuelga de `Main`, HERMANA de la bolsa, en el territorio donde el suelo y la tinta pintan siempre.
##
## ── DÓNDE ENCAJA EN LA ESCALERA DE Z (ver `construccion.gd::montar_visual`) ─────────────────────
## suelo (−3) < tinta de salas (−2) < ESTA CAPA (−1, empatada con la rejilla de obra, que solo
## existe en modo construcción) < bolsa y-sort (0). El `z_index` manda sobre el y-sort, así que
## TODA sombra queda garantizada debajo de cualquier mueble, muñeco o muro — que es exactamente lo
## que hace una sombra de contacto — sin declarar capa por hijo (el ADR-0005 rige el INTERIOR de
## los contenedores de puesto; esta capa vive fuera de la bolsa y no compite con él).
##
## ── REGISTRO ────────────────────────────────────────────────────────────────────────────────────
## Nadie crea nodos de sombra: los interesados se REGISTRAN (con weakref, se purgan solos al morir):
## - `registrar_mueble(ancla, desplaz, semiejes)`: dibuja una elipse fija en
##   `ancla.global_position + desplaz` mientras el ancla viva y esté visible.
## - `registrar_muneco(visual)`: dibuja la elipse de NPC en la posición de SUELO que
##   `NPCsFlujo.colocar_muneco` deja en la meta `pos_suelo_sombra` (el destino SIN el bote del
##   paso: el cuerpo bota, la sombra queda pegada al suelo), solo si la meta `sombra_visible` está
##   a `true` (sentado o muñeco de piezas → sin sombra).
##
## Regla de motor (cero asignaciones en el camino caliente): los registros se guardan en arrays
## que se purgan IN SITU con swap-remove dentro del propio `_draw()` — nada se realoja por frame.

const SombraContactoScript := preload("res://src/foundation/proyeccion/sombra_contacto.gd")

## Cada entrada: { peso: WeakRef (al ancla Node2D), desplaz: Vector2, semiejes: Vector2 }
var _muebles: Array[Dictionary] = []
## Cada entrada: WeakRef al visual (Node2D) de un muñeco andante.
var _munecos: Array[WeakRef] = []


func _ready() -> void:
	z_index = -1
	# PRECALIENTA la textura FUERA de la fase de dibujo: si la primera llamada a `textura()`
	# ocurriera dentro de `_draw`, el ImageTexture nacería en plena pasada de render.
	SombraContactoScript.textura()


func _process(_delta: float) -> void:
	# Los NPC se mueven cada frame: se redibuja todo (una sola llamada de lienzo, ~30-60 elipses).
	queue_redraw()


## Registra la sombra fija de un mueble: elipse de `semiejes` (px lógicos del plano del suelo, ya
## con su mínimo aplicado — ver `SombraContacto.semiejes_para_mueble`) centrada en
## `ancla.global_position + desplaz`. El registro muere solo cuando muere el ancla.
func registrar_mueble(ancla: Node2D, desplaz: Vector2, semiejes: Vector2) -> void:
	_muebles.append({ peso = weakref(ancla), desplaz = desplaz, semiejes = semiejes })


## Registra la sombra móvil de un muñeco andante (ver la cabecera: metas `pos_suelo_sombra` y
## `sombra_visible`, escritas por `NPCsFlujo.colocar_muneco`).
func registrar_muneco(visual: Node2D) -> void:
	_munecos.append(weakref(visual))


## Cuántos registros VIVOS quedan (para tests; purga los muertos al contar).
func numero_registrados() -> Vector2i:
	_purgar()
	return Vector2i(_muebles.size(), _munecos.size())


func _draw() -> void:
	var i: int = _muebles.size() - 1
	while i >= 0:
		var ancla: Node2D = _muebles[i].peso.get_ref() as Node2D
		if ancla == null or not ancla.is_inside_tree():
			# swap-remove sin realojar el array; el movido venía del final y YA está procesado
			# (se itera de atrás hacia delante), así que se decrementa igual.
			_muebles[i] = _muebles[_muebles.size() - 1]
			_muebles.resize(_muebles.size() - 1)
		else:
			if ancla.is_visible_in_tree():
				SombraContactoScript.dibujar(
					self, ancla.global_position + _muebles[i].desplaz, _muebles[i].semiejes
				)
		i -= 1
	i = _munecos.size() - 1
	while i >= 0:
		var visual: Node2D = _munecos[i].get_ref() as Node2D
		if visual == null or not visual.is_inside_tree():
			_munecos[i] = _munecos[_munecos.size() - 1]
			_munecos.resize(_munecos.size() - 1)
		else:
			if (
				visual.is_visible_in_tree()
				and bool(visual.get_meta(&"sombra_visible", false))
				and visual.has_meta(&"pos_suelo_sombra")
			):
				SombraContactoScript.dibujar(
					self, visual.get_meta(&"pos_suelo_sombra") as Vector2,
					Vector2.ONE * SombraContactoScript.RADIO_NPC
				)
		i -= 1


func _purgar() -> void:
	var j: int = _muebles.size() - 1
	while j >= 0:
		var ancla: Node2D = _muebles[j].peso.get_ref() as Node2D
		if ancla == null or not ancla.is_inside_tree():
			_muebles[j] = _muebles[_muebles.size() - 1]
			_muebles.resize(_muebles.size() - 1)
		j -= 1
	j = _munecos.size() - 1
	while j >= 0:
		var visual: Node2D = _munecos[j].get_ref() as Node2D
		if visual == null or not visual.is_inside_tree():
			_munecos[j] = _munecos[_munecos.size() - 1]
			_munecos.resize(_munecos.size() - 1)
		j -= 1
