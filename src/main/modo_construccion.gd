class_name ModoConstruccion extends Node2D
## ModoConstruccion — el ANDAMIO de interacción del modo construcción (story const-007).
##
## Herramientas de ratón sobre el modelo de Construcción: preview fantasma verde/rojo (F6 en vivo,
## con TEXTO además del color — daltónicos), dibujar salas arrastrando (área y coste en vivo, F1),
## colocar elementos con clic (paga por el gate E4) y demoler con confirmación de cascada.
##
## Reglas (control-manifest, Presentation): la UI LEE el estado y ORDENA por la API pública de
## Construcción (`validar_*`/`construir_*`/`demoler_*`) — NUNCA muta el modelo ni el saldo
## directamente. El dibujo del preview corre en `_process` con guarda de celda (cero trabajo si el
## cursor no cambia de celda). Este andamio NO es la UI real (condición 3 del gate: /ux-design
## antes del panel definitivo — UI/HUD #11 lo sustituirá).
##
## Story: production/epics/construccion/story-007-modo-construccion-raton.md · TR-construction-002 · ADR-0004/0001

const COLOR_VALIDO := Color(0.4, 1.0, 0.4, 0.4)
const COLOR_INVALIDO := Color(1.0, 0.35, 0.35, 0.4)
const COLOR_DEMOLER := Color(1.0, 0.6, 0.2, 0.4)
const COLOR_BOTON_ACTIVO := Color(1.0, 0.85, 0.35)
## ── FANTASMA CON SPRITE REAL (quick-spec 2026-08-04 §4) ────────────────────────────────────────
## Alfa del fantasma cuando lleva el SPRITE de verdad del mueble en vez de la caja gris genérica:
## más alto que el de la caja (`COLOR_VALIDO`/`COLOR_INVALIDO`, alfa 0.4) porque un sprite con
## detalle fino (líneas de un monitor, patas de una silla) se pierde antes que un polígono liso al
## mismo alfa — a 0.4 el ordenador de sobremesa se leía como una mancha, no como "esto es lo que vas
## a comprar". Verde-blanco (no verde puro) para no confundirlo con el tinte plano de la caja: sigue
## siendo un mueble, no un rectángulo de validación.
const ALFA_FANTASMA_SPRITE: float = 0.55
const TINTE_FANTASMA_VALIDO := Color(0.78, 1.0, 0.82, ALFA_FANTASMA_SPRITE)
const TINTE_FANTASMA_INVALIDO := Color(1.0, 0.35, 0.35, ALFA_FANTASMA_SPRITE)
## Hueco reservado para la barra de info de Main (abajo del todo): esta barra se apoya ENCIMA.
const HUECO_BARRA_INFO := 84.0
## Grosor del resalte de ARISTA del pincel de muro (2026-07-30): más fino que la caja de una celda
## entera — así el jugador ve claramente que apunta a un LADO, no a la celda completa.
const GROSOR_PREVIEW_MURO := 10.0
## Cuánto se queda congelado el resalte de la arista tras un clic, en segundos (2026-08-03). Es el
## ACUSE DE RECIBO del clic: verde = hecho, rojo = no se puede. Sin él, el fantasma vuelve al color
## normal en el mismo frame y un clic rechazado se ve exactamente igual que uno que no ha ocurrido —
## que es justo lo que hizo pensar al usuario que la puerta "no se dejaba poner".
const DURACION_DESTELLO: float = 0.4
## Lo que se lee arriba cuando una sala acaba de quedarse amurallada (ver `pedir_puerta_de_sala`).
const TEXTO_PEDIR_PUERTA := "Coloca la puerta de la sala: clic en el tramo de pared que quieras (Esc = sin puerta)"

## ── EL PINCEL DE PINTURA (2026-08-04 · quick-spec §2) ──────────────────────────────────────────
## Dos herramientas hermanas —una para PAREDES y otra para SUELOS— que comparten una sola paleta de
## 30 muestras (`PaletaPintura`). Son dos botones y no uno con submodo porque el gesto es distinto:
## el de pared apunta a una ARISTA (como el pincel de muro o el de puertas) y el de suelo a una
## CELDA (como colocar un mueble), y el fantasma tiene que dibujar una cosa u otra. Con un solo botón
## en dos submodos habría que enseñar en algún sitio cuál de los dos está activo — dos botones ya lo
## dicen ellos solos, que es el patrón que sigue el resto de esta barra.
##
## **MAYÚS = LA SALA ENTERA.** Clic normal pinta el tramo/celda señalado; con MAYÚS pulsada pinta
## todas las paredes (o todo el suelo) de la sala. Si el tramo NO pertenece a ninguna sala —un muro
## suelto en mitad del edificio, el suelo de un pasillo— MAYÚS pinta solo lo señalado: no hay sala
## que extender, y adivinar un "recinto" sería pintar cosas que el jugador no ha visto.
const HERRAMIENTA_PINTAR_PARED := &"pintar_pared"
const HERRAMIENTA_PINTAR_SUELO := &"pintar_suelo"
## Lado (en píxeles) de cada muestra de color de la rejilla de la paleta.
const LADO_MUESTRA := Vector2(26.0, 20.0)

## ── LA CUADRÍCULA DEL MODO (2026-08-05 · quick-spec §3c; ver la clase `RejillaConstruccion`) ────
## Blanco a alfa muy bajo: se lee sobre cualquier color de suelo (el tinte de una sala, una celda
## pintada de terracota) sin competir con el fantasma verde/rojo, que es lo que el ojo tiene que
## seguir mientras coloca. Con el atenuador del modo (negro al 18 %) por encima, queda como una
## trama técnica de plano — que es exactamente lo que es.
const COLOR_REJILLA_CONSTRUCCION := Color(1.0, 1.0, 1.0, 0.14)
## Grosor de la línea de la rejilla, en píxeles (1 px: una trama, no un dibujo).
const GROSOR_REJILLA_CONSTRUCCION: float = 1.0

## La paleta (30 colores data-driven). Preload por el mismo convenio que `TramoParedScript` en
## `paredes_salas.gd`: un `const …Script` en vez de depender del registro global del `class_name`.
const PaletaPinturaScript := preload("res://src/core/construccion/paleta_pintura.gd")
## Solo para leer su API PÚBLICA de sprite del mostrador (`RUTA_SPRITES_MOBILIARIO`,
## `ID_SPRITE_MOSTRADOR_2`, `ROT_MOSTRADOR`, `hay_sprite_mostrador`) — ver la cabecera del fantasma
## de sprite real más abajo. Este fichero solo LEE `mesa_atencion.gd` (orden de la tarea).
const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")

var _construccion: Node = null
var _tam_celda: int = 40

# ── Estado de la interacción ─────────────────────────────────────────────────────────────────
var _activo: bool = false
## Herramienta en mano: &"" ninguna · &"demoler" · un id de TipoSala/TipoPuesto/ASIENTO_BASICO.
var _herramienta: StringName = &""
var _es_sala: bool = false
var _arrastrando: bool = false
var _celda_inicio: Vector2i = Vector2i.ZERO
## Guardas del refresco del preview (solo se redibuja al CAMBIAR de celda/herramienta — cero alloc
## por frame con el cursor quieto).
var _celda_anterior: Vector2i = Vector2i(-999, -999)
## Hacia dónde crece el cuerpo de la pieza que llevas en la mano (rotar con R, 2026-07-30).
## Arranca en HORIZONTAL, que es como se colocaba todo hasta hoy.
var _orientacion: int = 0
var _herramienta_anterior: StringName = &"-"
var _arrastre_anterior: bool = false
## Lado resaltado por el pincel de muro en el último frame (para que la guarda del preview también
## redibuje al cambiar de LADO dentro de la misma celda, no solo al cambiar de celda).
var _lado_anterior: StringName = &"-"

# ── Pincel de MURO (2026-07-30 — modelo Prison Architect): arrastrar pinta/demuele una fila entera
## de tabiques seguidos, celda a celda, sin tener que hacer clic uno a uno.
## ¿Hay un arrastre de muro en curso? Independiente de `_arrastrando` (el rectángulo de SALA).
var _arrastrando_muro: bool = false
## Eje al que se ha CLAVADO el trazo actual de muro ("h" o "v"; "" = aun no se ha pulsado). Lo fija
## la primera arista del arrastre y no cambia hasta soltar: es lo que hace el trazo predecible.
var _eje_arrastre_muro: String = ""
## Si la PROXIMA sala que dibujes nace con paredes o en planta diafana (peticion del usuario
## 2026-07-30). Arranca en false: la mayoria de las zonas se quieren delimitadas, no aisladas.
var _nueva_sala_con_paredes: bool = false
## La coordenada que queda fija en ese trazo (la fila si es horizontal, la columna si es vertical).
var _fija_arrastre_muro: int = 0
## Principio y final del trazo actual, en el eje libre. Con esto se reconstruye la linea entera.
var _desde_arrastre_muro: int = 0
var _hasta_arrastre_muro: int = 0
## true = el arrastre CONSTRUYE (botón izquierdo); false = DEMUELE (botón derecho — "clic derecho
## quita un muro", igual que hace la herramienta de demoler con elementos/salas).
var _construyendo_arrastre_muro: bool = true
## Última arista YA pintada/demolida en este arrastre: si el ratón sigue sobre el mismo tramo entre
## dos eventos de movimiento, no se repite la orden (cero llamadas de más por frame).
var _arista_arrastre_anterior: String = ""
## Segundos que le quedan al acuse de recibo del último clic (ver `DURACION_DESTELLO`). Mientras
## corre, `_process` NO repinta el fantasma: si no, el color de respuesta duraría un solo frame.
var _destello_restante: float = 0.0

# ── Nodos de UI (construidos por código, patrón del HUD del esqueleto) ───────────────────────
var _atenuador: ColorRect
## HFlowContainer (no HBox): con los nombres del catálogo la fila supera el ancho de la ventana y
## los últimos botones (Asiento, Demoler) quedaban FUERA de pantalla — el flow envuelve en filas.
var _fila_herramientas: HFlowContainer
var _lbl_estado: Label
var _boton_modo: Button
var _botones_herramienta: Dictionary = {}
var _preview_caja: PreviewIso
## El fantasma con el SPRITE REAL del mueble (quick-spec 2026-08-04 §4), hermano de `_preview_caja`:
## solo uno de los dos está visible a la vez — la caja para las comodidades sin arte (12 de 16) y
## este `Sprite2D` para las que sí tienen render (comodidades con sprite, el sofá y los puestos).
## UN solo nodo cacheado (nunca se crea uno nuevo por frame): se reutiliza cambiando `texture` +
## `offset`/`centered` (vía `AnclajeSprite.aplicar`) solo cuando la guarda de celda/herramienta/
## rotación de `_process` deja pasar — ver `_mostrar_fantasma_sprite`.
var _preview_sprite: Sprite2D
var _preview_texto: Label
## Rejilla de muestras de color del pincel (5 por fila = una familia de la paleta por fila). Solo
## visible con un pincel de pintura en la mano — es el SUBMENÚ del pincel, no una barra permanente.
var _rejilla_paleta: GridContainer
## Los 30 botones-muestra, en el orden de `PaletaPintura.COLORES` (para resaltar el seleccionado).
var _muestras: Array[Button] = []
## Índice del color elegido dentro de `PaletaPintura.COLORES`. Arranca en 0 = blanco puro, que es
## además el color por defecto de toda pared: pintar sin elegir nada NO cambia nada de sitio.
var _indice_color: int = 0
## El color elegido, ya resuelto (cacheado: el fantasma lo pide cada vez que se repinta y no tiene
## sentido reconstruir la paleta entera para leer una entrada).
var _color_pincel: Color = Color.WHITE
## Texturas del fantasma de sprite, por ruta de PNG (regla de rendimiento de la tarea: "no
## recargues texturas cada frame"). Se rellena la primera vez que hace falta cada una; después,
## puro lookup — ni siquiera `ResourceLoader.exists` se repite dos veces con la misma ruta.
var _cache_texturas_fantasma: Dictionary[String, Texture2D] = {}


## El fantasma de construcción, dibujado a mano.
##
## ISOMÉTRICO (2026-07-30): antes era un `Panel` —un rectángulo recto de pantalla—, que sobre una
## rejilla cuadrada coincidía exactamente con las celdas. En rombos ya no: la huella de una sala de
## 5×4 es un ROMBO grande, y un rectángulo recto encima marcaría un trozo de suelo que no es el que
## vas a comprar. Como el fantasma es justamente lo que promete dónde va a caer la obra, tiene que
## dibujar la forma de verdad. Es el mismo criterio que usa Two Point Campus (captura de
## referencia del usuario, `capturas/construccion.PNG`): la huella translúcida sigue el suelo.
class PreviewIso extends Node2D:
	## Vértices de la huella a rellenar (vacío = no se pinta relleno).
	var poligono: PackedVector2Array = PackedVector2Array()
	## Extremos del tramo a pintar como línea gruesa (pincel de muro). `grosor <= 0` = sin línea.
	var linea_desde: Vector2 = Vector2.ZERO
	var linea_hasta: Vector2 = Vector2.ZERO
	var grosor: float = 0.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		if poligono.size() >= 3:
			# Relleno translúcido + borde casi opaco: se distingue sobre cualquier color de sala
			# (mismo criterio de contraste que tenía el StyleBox del Panel anterior).
			draw_colored_polygon(poligono, Color(color.r, color.g, color.b, 0.30))
			var cerrado: PackedVector2Array = poligono.duplicate()
			cerrado.append(poligono[0])
			draw_polyline(cerrado, Color(color.r, color.g, color.b, 0.95), 3.0, true)
		if grosor > 0.0:
			draw_line(
				linea_desde, linea_hasta, Color(color.r, color.g, color.b, 0.85), grosor, true
			)

	## Pinta una huella cerrada (una sala, un elemento). Borra cualquier línea anterior.
	func pintar_poligono(vertices: PackedVector2Array, nuevo_color: Color) -> void:
		poligono = vertices
		grosor = 0.0
		color = nuevo_color
		queue_redraw()

	## Pinta un tramo de arista (el pincel de muro). Borra cualquier huella anterior.
	func pintar_linea(desde: Vector2, hasta: Vector2, ancho: float, nuevo_color: Color) -> void:
		poligono = PackedVector2Array()
		linea_desde = desde
		linea_hasta = hasta
		grosor = ancho
		color = nuevo_color
		queue_redraw()


## ── LA CUADRÍCULA, SOLO AL CONSTRUIR (2026-08-05 · quick-spec §3c) ──────────────────────────────
## Orden del usuario tras comparar con la demo de Summer: *"en juego normal el suelo va limpio; la
## rejilla de celdas solo se muestra con el modo construcción activo"*. Hasta hoy la rejilla que se
## veía era el BORDE pintado dentro de cada tile del suelo de `Main` (visible siempre, se estuviera
## construyendo o no) más las juntas marcadas de las baldosas de `Construccion`; las dos se han
## limpiado. Esta es la rejilla ÚTIL: la que te dice dónde va a caer lo que estás colocando.
##
## Es un `Node2D` en coordenadas de MUNDO (hijo directo de `ModoConstruccion`, que también lo es),
## no un `Control` de la `CanvasLayer` de la barra: tiene que estar clavada sobre el suelo y moverse
## con la cámara y el zoom (2026-08-04) como cualquier otra cosa del tablero.
##
## Rendimiento (regla del proyecto — cero trabajo por frame): las líneas se calculan UNA vez al
## configurarla y se guardan; `_draw` es una sola llamada a `draw_multiline`, y solo ocurre cuando
## el nodo se hace visible.
class RejillaConstruccion extends Node2D:
	## Los extremos de todas las líneas, por parejas (formato de `draw_multiline`).
	var _puntos: PackedVector2Array = PackedVector2Array()
	var _color: Color = Color.WHITE
	var _grosor: float = 1.0

	## Calcula la rejilla entera del edificio a partir de los VÉRTICES reales de la proyección (los
	## mismos que usan las paredes), así que encaja al píxel con los rombos del suelo.
	func construir(
		construccion: Node, columnas: int, filas: int, color: Color, grosor: float
	) -> void:
		_color = color
		_grosor = grosor
		_puntos = PackedVector2Array()
		for fila: int in range(filas + 1):
			_puntos.append(construccion.esquina_en_pantalla(0, fila))
			_puntos.append(construccion.esquina_en_pantalla(columnas, fila))
		for columna: int in range(columnas + 1):
			_puntos.append(construccion.esquina_en_pantalla(columna, 0))
			_puntos.append(construccion.esquina_en_pantalla(columna, filas))
		queue_redraw()

	func _draw() -> void:
		if _puntos.is_empty():
			return
		draw_multiline(_puntos, _color, _grosor, true)
var _dialogo_cascada: ConfirmationDialog
var _sala_a_demoler: StringName = &""
## La cuadrícula del modo (2026-08-05): se enciende y se apaga con el modo, nada más.
var _rejilla: RejillaConstruccion


## Inyección de dependencias (la llama Main ANTES de add_child).
func configurar(construccion: Node, tam_celda: int) -> void:
	_construccion = construccion
	_tam_celda = tam_celda


func _ready() -> void:
	_crear_ui()
	_crear_rejilla()
	_actualizar_visibilidad()


## Monta la cuadrícula del modo construcción sobre el suelo (ver `RejillaConstruccion`).
##
## z_index −1 = LA CAPA DEL SUELO: por encima del suelo liso de `Main` (z −2) y del tinte de las
## salas de `Construccion` (z −1, que se dibuja antes por orden de árbol — `Construccion` entra en
## la escena antes que este nodo), y por DEBAJO de todo lo que se apoya en el suelo (paredes,
## mobiliario y gente viven en z 0 o más). O sea: la rejilla se pinta SOBRE el suelo y POR DEBAJO de
## las cosas, que es donde la espera quien la usa para medir.
func _crear_rejilla() -> void:
	if _construccion == null:
		return   # sin modelo inyectado (tests/herramientas sueltas) no hay edificio que cuadricular
	_rejilla = RejillaConstruccion.new()
	_rejilla.name = "RejillaConstruccion"
	_rejilla.z_index = -1
	_rejilla.visible = false
	add_child(_rejilla)
	_rejilla.construir(
		_construccion, _construccion.edificio_columnas, _construccion.edificio_filas,
		COLOR_REJILLA_CONSTRUCCION, GROSOR_REJILLA_CONSTRUCCION
	)


# ── Entrada (la UI ordena por la API pública; atajos: B modo · clic dcho/Esc cancela) ────────
func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not (evento as InputEventKey).echo:
		match (evento as InputEventKey).keycode:
			KEY_B:
				_alternar_modo()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _activo:
					_cancelar()
					get_viewport().set_input_as_handled()
			KEY_R:
				# ROTAR (petición del usuario, 2026-07-30: *"debe poder rotarse un objeto con la R
				# por ejemplo"*). Gira la pieza que llevas en la mano, no una ya colocada: cambia el
				# eje por el que crece su cuerpo. Se fuerza el redibujado del fantasma poniendo la
				# guarda de celda en un imposible — si no, el preview solo se refresca al MOVER el
				# ratón y girar sin moverse no se vería.
				if _activo and not _es_sala and _herramienta != &"" and _herramienta != &"demoler":
					_orientacion = (
						_construccion.HORIZONTAL if _orientacion == _construccion.VERTICAL
						else _construccion.VERTICAL
					)
					_celda_anterior = Vector2i(-999, -999)
					get_viewport().set_input_as_handled()
		return
	if not _activo:
		return
	# Arrastre del pincel de muro: cada evento de MOVIMIENTO pinta/demuele la arista bajo el punto
	# DEL EVENTO en ese instante — nunca `get_global_mouse_position()` (gotcha ya sufrido en este
	# proyecto: el clic derecho del 2026-07-26 se pintaba en el sitio equivocado por leer el puntero
	# del sistema en vez del punto donde ocurrió el evento).
	# ⚠️ `_herramienta == &"muro"` en la guarda (2026-08-03): sin esa condición, un trazo que se quedó
	# vivo (soltar el botón ENCIMA DE LA BARRA de herramientas se lleva el evento y este nodo nunca ve
	# el "soltar") seguía creciendo con CUALQUIER herramienta en la mano, y el siguiente clic lo
	# construía entero. Estado guardado "para luego" sin que el jugador lo viera: exactamente la
	# familia de bug de las puertas fantasma, aquí en el pincel de muro.
	if _arrastrando_muro and _herramienta == &"muro" and evento is InputEventMouseMotion:
		_pintar_arista_muro(_punto_mundo_del_evento((evento as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
		return
	if not (evento is InputEventMouseButton):
		return
	var boton := evento as InputEventMouseButton
	var punto_mundo: Vector2 = _punto_mundo_del_evento(boton.position)
	if boton.button_index == MOUSE_BUTTON_RIGHT:
		if boton.pressed:
			if _herramienta == &"muro":
				# "clic derecho... lo quita" (enunciado): empieza un arrastre que DEMUELE en vez de
				# cancelar la herramienta — el pincel de muro tiene su propio botón de borrar.
				_arrastrando_muro = true
				_construyendo_arrastre_muro = false
				_arista_arrastre_anterior = ""
				_pintar_arista_muro(punto_mundo)
			else:
				_cancelar()
		elif _hay_trazo_de_muro(false):
			_aplicar_linea_muro()   # se construye AL SOLTAR, no mientras arrastras
			_descartar_trazo_muro()
	elif boton.button_index == MOUSE_BUTTON_LEFT:
		if boton.pressed:
			# MAYÚS se lee DEL EVENTO (`shift_pressed`), no solo del teclado en vivo: es el estado del
			# modificador en el instante del clic —el mismo criterio de "usa el dato del evento" que ya
			# rige para la posición— y además hace el gesto reproducible desde un test/diagnóstico con
			# eventos sintéticos. El poll en vivo se conserva como respaldo por si el backend no
			# rellenara el modificador.
			_al_pulsar(punto_mundo, boton.shift_pressed or Input.is_key_pressed(KEY_SHIFT))
		else:
			if _hay_trazo_de_muro(true):
				_aplicar_linea_muro()   # se construye AL SOLTAR, no mientras arrastras
				_descartar_trazo_muro()
			_al_soltar()


func _al_pulsar(punto_mundo: Vector2, con_mayus: bool = false) -> void:
	if _herramienta == &"":
		return
	if _herramienta == HERRAMIENTA_PINTAR_PARED:
		_pintar_pared_en(punto_mundo, con_mayus)
		return
	if _herramienta == HERRAMIENTA_PINTAR_SUELO:
		_pintar_suelo_en(punto_mundo, con_mayus)
		return
	if _herramienta == &"muro":
		_arrastrando_muro = true
		_construyendo_arrastre_muro = true
		_arista_arrastre_anterior = ""
		_pintar_arista_muro(punto_mundo)
		return
	if _herramienta == &"puerta" or _herramienta == &"ventana":
		# FASE D (2026-07-30): clic SUELTO, sin arrastre — convierte la arista de tabique más cercana
		# al punto DEL EVENTO. No levanta muro nuevo (para eso está el pincel de muro): abre un hueco
		# en uno que ya exista.
		_convertir_arista_en(punto_mundo, _herramienta)
		return
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	# Zona: el hueco que hayas cerrado con muros SE CONVIERTE en sala. No se dibuja nada — basta con
	# pinchar dentro. (`celda_de_punto` sobre el punto DEL EVENTO, nunca el poll del cursor: gotcha ya
	# sufrido en este proyecto.)
	if String(_herramienta).begins_with("zona:"):
		var tipo_id := StringName(String(_herramienta).substr(5))
		var creada: StringName = _construccion.designar_zona(celda, tipo_id)
		if creada == &"":
			# Se dice POR QUE no se puede: un clic que no hace nada y no explica nada parece un bug.
			_lbl_estado.text = (
				"Aqui no: el hueco no esta cerrado del todo, es muy pequeno, "
				+ "ya es de otra sala, o no hay caja"
			)
		else:
			_lbl_estado.text = "Zona creada con %d celdas" % _construccion.area_de_sala(creada)
			# Una zona se marca DENTRO de muros que ya existen: si ese recinto no tiene ninguna puerta,
			# hace falta el mismo gesto que al amurallar a mano.
			_pedir_puerta_si_hace_falta(creada)
		return
	if _herramienta == &"demoler":
		_demoler_en(celda, punto_mundo)
	elif _es_sala:
		_arrastrando = true
		_celda_inicio = celda
	else:
		_construccion.construir_elemento(_herramienta, celda, _orientacion)


func _al_soltar() -> void:
	if not _arrastrando:
		return
	_arrastrando = false
	var creada: StringName = _construccion.construir_sala(
		_herramienta, _rect_entre(_celda_inicio, _construccion.celda_bajo_cursor()),
		1 if _nueva_sala_con_paredes else -1
	)
	# Si nació cerrada (la casilla "Con paredes", o un tipo que se cierra solo como la de descanso),
	# el paso siguiente es elegir dónde va la puerta — ya no viene ninguna puesta.
	_pedir_puerta_si_hace_falta(creada)


## Demoler con la cascada del GDD: un elemento directo; un MURO libre directo (prioridad entre
## elemento y sala — un tabique no tiene "contenido" que confirmar); una sala VACÍA directa; una
## sala con contenido pide CONFIRMACIÓN (paso 1 `contenido_de_sala` + reembolso; paso 2 al confirmar).
## `punto_mundo` (el punto DEL EVENTO — nunca el puntero en vivo) decide qué ARISTA de `celda` se
## comprueba, para que la herramienta general de demoler también sirva para quitar muros.
func _demoler_en(celda: Vector2i, punto_mundo: Vector2) -> void:
	var elemento_id: StringName = _construccion.elemento_en(celda)
	if elemento_id != &"":
		_construccion.demoler_elemento(elemento_id)
		return
	var lado: StringName = _lado_mas_cercano(punto_mundo, celda)
	if _construccion.hay_muro(celda, lado):
		_construccion.demoler_muro(celda, lado)
		return
	var sala_id: StringName = _construccion.sala_en(celda)
	if sala_id == &"":
		return
	var contenido: Array = _construccion.contenido_de_sala(sala_id)
	if contenido.is_empty():
		_construccion.demoler_sala(sala_id)
		return
	_sala_a_demoler = sala_id
	_dialogo_cascada.dialog_text = (
		"Demoler la sala y sus %d elementos.\nReembolso total: %.0f €"
		% [contenido.size(), _construccion.reembolso_de_sala(sala_id)]
	)
	_dialogo_cascada.popup_centered()


## Pincel de PUERTA/VENTANA (FASE D, 2026-07-30 — puertas y ventanas en los muros): convierte la
## arista de tabique más cercana al punto DEL EVENTO en `tipo` (`&"puerta"`/`&"ventana"`, mismos
## valores que `Construccion.PUERTA`/`VENTANA`). Reutiliza `_lado_mas_cercano` (el mismo cálculo que
## ya usa el pincel de muro) — nunca `get_global_mouse_position()` ni `celda_bajo_cursor()` para la
## ACCIÓN real (gotcha ya sufrido en este proyecto: eso es solo válido para el fantasma).
## ── CRITERIO DE VALIDEZ (fijado el 2026-08-03 tras el bug de las puertas fantasma) ─────────────
## Una puerta se puede abrir en **CUALQUIER tramo de pared que exista de verdad en el modelo y no
## sea fachada del edificio**. Y nada más: ni "solo en un lado", ni "no en las esquinas".
##
##   · *Tramo de pared real* — hay tabique (o ventana) en esa arista. Si no hay pared no hay nada que
##     convertir: para eso está el pincel de muro. Es la regla de siempre (`fijar_tipo_de_muro`).
##   · *No la fachada* — el perímetro del edificio es el plano de la comisaría, no obra del jugador
##     (`_muros_fijos`); su puerta de acceso ya viene puesta y no se tapia.
##   · **Las esquinas SÍ valen.** Una esquina es un VÉRTICE donde se juntan dos aristas, y una puerta
##     vive en una ARISTA: poner una en cualquiera de las dos que forman la esquina es legal y no
##     rompe nada (el recinto sigue cerrado — `recinto_de` trata la puerta como pared— y el paso se
##     abre — `deja_pasar` la cruza). Se comprobó en el motor: `tools/_diag_puertas.gd` abre las tres
##     puertas del caso en tramos distintos, y una de ellas pegada al extremo del muro.
##
## El clic SIEMPRE responde a la vista: verde si se abrió, rojo si no (`_destellar_arista`). Antes
## solo se escribía en la barra de estado de abajo —lejos del cursor, donde nadie mira mientras
## construye— y un clic aceptado se veía igual que uno rechazado.
func _convertir_arista_en(punto_mundo: Vector2, tipo: StringName) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var lado: StringName = _lado_mas_cercano(punto_mundo, celda)
	var nombre: String = "Puerta" if tipo == &"puerta" else "Ventana"
	if _construccion.fijar_tipo_de_muro(celda, lado, tipo):
		_lbl_estado.text = nombre + " abierta"
		_destellar_arista(celda, lado, COLOR_VALIDO, nombre + " abierta")
		return
	# El "no" se explica: sin pared no hay hueco que abrir, y la fachada no se toca.
	var motivo: String = (
		"La fachada no se toca" if _construccion.es_muro_fijo(_construccion.clave_de_muro(celda, lado))
		else "Primero levanta la pared ahí"
	)
	_lbl_estado.text = motivo
	_destellar_arista(celda, lado, COLOR_INVALIDO, motivo)


## Congela el resalte de una arista en `color` durante `DURACION_DESTELLO`, con su motivo escrito al
## lado del cursor. Es el acuse de recibo del clic: reutiliza el MISMO fantasma que ya dibuja el
## preview (ningún nodo ni ninguna UI nueva), solo que sin dejar que `_process` lo repinte todavía.
func _destellar_arista(celda: Vector2i, lado: StringName, color: Color, texto: String) -> void:
	_preview_caja.visible = true
	_preview_texto.visible = true
	_colocar_caja_arista(celda, lado, color)
	_preview_texto.text = texto
	_destello_restante = DURACION_DESTELLO


# ── EL PINCEL DE PINTURA (2026-08-04) ────────────────────────────────────────────────────────

## Pinta la PARED señalada por el punto DEL EVENTO. Con `con_mayus`, la sala entera.
##
## La sala se deduce de la celda clicada (`sala_en`), no de la arista: una arista separa DOS celdas y
## preguntar por las dos daría dos salas candidatas. Con la celda donde de verdad has pinchado, el
## resultado es el que espera cualquiera — pintas desde dentro de la habitación que quieres pintar.
## Si esa celda no es de ninguna sala (un muro suelto, un pasillo), MAYÚS pinta SOLO ese tramo.
func _pintar_pared_en(punto_mundo: Vector2, con_mayus: bool) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var lado: StringName = _lado_mas_cercano(punto_mundo, celda)
	var sala_id: StringName = _construccion.sala_en(celda)
	if con_mayus and sala_id != &"":
		var pintados: int = _construccion.pintar_sala_muros(sala_id, _color_pincel)
		var texto: String = (
			"Sala pintada: %d tramos" % pintados if pintados > 0
			else "Esa sala no tiene paredes que pintar"
		)
		_lbl_estado.text = texto
		_destellar_arista(celda, lado, COLOR_VALIDO if pintados > 0 else COLOR_INVALIDO, texto)
		return
	if _construccion.pintar_muro_en(celda, lado, _color_pincel):
		_lbl_estado.text = "Pared pintada"
		_destellar_arista(celda, lado, COLOR_VALIDO, "Pared pintada")
		return
	# El "no" se explica, igual que en el pincel de puertas: sin pared no hay nada que pintar, y la
	# fachada es ladrillo (no es obra tuya).
	var motivo: String = (
		"La fachada no se pinta"
		if _construccion.es_muro_fijo(_construccion.clave_de_muro(celda, lado))
		else "Ahí no hay pared que pintar"
	)
	_lbl_estado.text = motivo
	_destellar_arista(celda, lado, COLOR_INVALIDO, motivo)


## Pinta el SUELO de la celda señalada. Con `con_mayus`, todo el suelo de su sala (y si la celda no
## es de ninguna sala, solo esa celda — mismo criterio que la pared).
func _pintar_suelo_en(punto_mundo: Vector2, con_mayus: bool) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var sala_id: StringName = _construccion.sala_en(celda)
	if con_mayus and sala_id != &"":
		var pintadas: int = _construccion.pintar_sala_suelo(sala_id, _color_pincel)
		_lbl_estado.text = "Suelo de la sala pintado: %d celdas" % pintadas
		_destellar_celda(celda, COLOR_VALIDO, _lbl_estado.text)
		return
	if _construccion.pintar_suelo(celda, _color_pincel):
		_lbl_estado.text = "Suelo pintado"
		_destellar_celda(celda, COLOR_VALIDO, "Suelo pintado")
		return
	_lbl_estado.text = "Fuera del edificio"
	_destellar_celda(celda, COLOR_INVALIDO, "Fuera del edificio")


## Igual que `_destellar_arista` pero sobre la CELDA entera (el pincel de suelo pinta celdas).
func _destellar_celda(celda: Vector2i, color: Color, texto: String) -> void:
	_preview_caja.visible = true
	_preview_texto.visible = true
	_colocar_caja(celda, Vector2i.ONE, color)
	_preview_texto.text = texto
	_destello_restante = DURACION_DESTELLO


## Elige el color del pincel (una muestra de la rejilla) y resalta la muestra elegida.
func _elegir_color(indice: int) -> void:
	_indice_color = clampi(indice, 0, PaletaPinturaScript.COLORES.size() - 1)
	_color_pincel = PaletaPinturaScript.desde_hex(
		String(PaletaPinturaScript.COLORES[_indice_color]["hex"])
	)
	_refrescar_muestras()
	# Que el fantasma se repinte ya con el color nuevo, sin esperar a que el ratón cambie de celda.
	_celda_anterior = Vector2i(-999, -999)


## Marca visualmente cuál de las 30 muestras está elegida: borde blanco grueso en la elegida, borde
## oscuro fino en el resto (el color de la muestra no se toca — es el dato que hay que leer).
func _refrescar_muestras() -> void:
	for i: int in _muestras.size():
		var elegido: bool = i == _indice_color
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = PaletaPinturaScript.desde_hex(
			String(PaletaPinturaScript.COLORES[i]["hex"])
		)
		estilo.set_border_width_all(3 if elegido else 1)
		estilo.border_color = Color.WHITE if elegido else Color(0.0, 0.0, 0.0, 0.6)
		var muestra: Button = _muestras[i]
		for estado: String in ["normal", "hover", "pressed", "focus"]:
			muestra.add_theme_stylebox_override(estado, estilo)


## ¿Hay un trazo de muro VIVO que le corresponda a este botón? Un trazo solo cuenta si además la
## herramienta en la mano sigue siendo el pincel de muro — ver la guarda del movimiento.
func _hay_trazo_de_muro(construyendo: bool) -> bool:
	return (
		_arrastrando_muro and _herramienta == &"muro"
		and _construyendo_arrastre_muro == construyendo
	)


## TIRA EL TRAZO DE MURO A MEDIAS, sin construir nada. Punto único: el trazo se descarta al soltar
## (ya aplicado), al cancelar, al salir del modo, al cambiar de herramienta y si se perdió el evento
## de soltar. Ningún clic puede quedarse guardado esperando a materializarse más tarde.
func _descartar_trazo_muro() -> void:
	_arrastrando_muro = false
	_eje_arrastre_muro = ""   # el trazo termina: el proximo elige su propio eje
	_arista_arrastre_anterior = ""


## Cancela por capas: primero el arrastre (sala O muro), luego suelta la herramienta, luego sale del modo.
func _cancelar() -> void:
	if _arrastrando or _arrastrando_muro:
		_arrastrando = false
		# Al CANCELAR o salir del modo el trazo se DESCARTA (no se construye): es lo que
		# espera quien pulsa Escape o cambia de herramienta a media linea.
		_descartar_trazo_muro()
	elif _herramienta != &"":
		_fijar_herramienta(&"", false)
	else:
		_alternar_modo()


func _alternar_modo() -> void:
	_activo = not _activo
	_arrastrando = false
	# Al CANCELAR o salir del modo el trazo se DESCARTA (no se construye): es lo que
	# espera quien pulsa Escape o cambia de herramienta a media linea.
	_descartar_trazo_muro()
	_fijar_herramienta(&"", false)
	_actualizar_visibilidad()


## **Entra en modo construcción con una herramienta YA en la mano** (menú contextual de la sala,
## 2026-07-28): el jugador pide "ampliar esta sala" o "añadir una ventanilla" y aparece directamente
## con el pincel correcto, sin tener que buscarlo en la barra. Ampliar una sala **no es una acción
## aparte**: es dibujar con la herramienta de ESE tipo de sala pegado a la que ya existe (Construcción
## fusiona y cobra solo las celdas nuevas — enmienda const-007).
func activar_con_herramienta(id: StringName, es_sala: bool) -> void:
	_activo = true
	_arrastrando = false
	_actualizar_visibilidad()
	_fijar_herramienta(id, es_sala)


## ── EL PASO QUE SIGUE A AMURALLAR: ELIGE DÓNDE VA LA PUERTA (2026-08-04 · quick-spec §3) ───────
## Murió el hueco automático: una sala recién amurallada es un RECINTO CERRADO. Así que en cuanto se
## cierra una sala, el modo se pone SOLO la herramienta de puerta en la mano y lo dice arriba; el
## jugador hace clic en el tramo que quiera (vale cualquier pared real que no sea fachada, con su
## destello verde/rojo de siempre).
##
## No es un modo bloqueado ni un diálogo: si pulsa Esc o coge otra herramienta, la sala se queda sin
## puerta y no pasa nada — los NPC que no puedan entrar esperarán quietos con su señal 🚫 (mecánica
## de accesos, 2026-08-03), que es un aviso mucho más honesto que una puerta puesta a su espalda.
func pedir_puerta_de_sala() -> void:
	activar_con_herramienta(&"puerta", false)
	_lbl_estado.text = TEXTO_PEDIR_PUERTA


## Lo anterior, pero solo si esa sala se ha quedado CERRADA Y SIN PUERTA. Se pregunta al modelo
## (`sala_amurallada_sin_puerta`), nunca se adivina desde la UI: una sala puede quedar amurallada por
## caminos muy distintos (la casilla "Con paredes", el tipo que se cierra solo, marcar una zona
## dentro de muros que ya estaban) y todos merecen el mismo paso siguiente.
func _pedir_puerta_si_hace_falta(sala_id: StringName) -> void:
	if sala_id == &"" or not _construccion.sala_amurallada_sin_puerta(sala_id):
		return
	pedir_puerta_de_sala()


func _fijar_herramienta(id: StringName, es_sala: bool) -> void:
	# Cambiar de herramienta TIRA el trazo de muro a medias (2026-08-03). Los botones de la barra son
	# `Control`: se comen el clic, así que este nodo nunca ve el "soltar" y el trazo se quedaba vivo
	# con la herramienta nueva ya en la mano.
	_descartar_trazo_muro()
	_herramienta = id
	_es_sala = es_sala
	# La paleta es el SUBMENÚ del pincel: aparece con él y se va con él (no ocupa la barra el resto
	# del tiempo). Guarda de null porque `_fijar_herramienta` puede correr antes de que la UI exista.
	if _rejilla_paleta != null:
		_rejilla_paleta.visible = _activo and (
			id == HERRAMIENTA_PINTAR_PARED or id == HERRAMIENTA_PINTAR_SUELO
		)
	for boton_id: StringName in _botones_herramienta:
		(_botones_herramienta[boton_id] as Button).modulate = (
			COLOR_BOTON_ACTIVO if boton_id == id else Color.WHITE
		)


# ── Preview fantasma (dibujo en _process con guarda de celda — ADR-0001) ─────────────────────
func _process(delta: float) -> void:
	if not _activo or _herramienta == &"":
		_preview_caja.visible = false
		_preview_sprite.visible = false
		_preview_texto.visible = false
		_celda_anterior = Vector2i(-999, -999)
		_lado_anterior = &"-"
		_destello_restante = 0.0
		return
	# RED DE SEGURIDAD DEL TRAZO DE MURO (2026-08-03): si el botón ya no está físicamente pulsado y
	# aquí seguimos creyendo que hay arrastre, es que el evento de soltar se lo llevó otro (la barra
	# de herramientas, un diálogo, perder el foco de la ventana). El trazo se TIRA, no se construye:
	# nada que el jugador no haya visto puede acabar en el modelo.
	if _arrastrando_muro and not Input.is_mouse_button_pressed(
		MOUSE_BUTTON_LEFT if _construyendo_arrastre_muro else MOUSE_BUTTON_RIGHT
	):
		_descartar_trazo_muro()
		_celda_anterior = Vector2i(-999, -999)
	# Acuse de recibo del último clic: mientras dura, el fantasma se queda como se dejó (verde o rojo).
	if _destello_restante > 0.0:
		_destello_restante -= delta
		if _destello_restante > 0.0:
			return
		_celda_anterior = Vector2i(-999, -999)   # se acabó: que el preview normal vuelva a pintarse
	var celda: Vector2i = _construccion.celda_bajo_cursor()
	# El LADO solo importa para el pincel de muro (los demás previews cubren la celda entera); se
	# calcula aquí una única vez y se reutiliza tanto en la guarda como en el propio preview. Live
	# poll (`get_global_mouse_position`) vale para un FANTASMA (no muta el modelo) — el gotcha de
	# "usa el punto del evento" es para las ACCIONES (pintar/demoler de verdad), no para dibujar.
	var lado: StringName = &"-"
	if (
		_herramienta == &"muro" or _herramienta == &"demoler"
		or _herramienta == &"puerta" or _herramienta == &"ventana"
		or _herramienta == HERRAMIENTA_PINTAR_PARED
	):
		lado = _lado_mas_cercano(get_global_mouse_position(), celda)
	if (
		celda == _celda_anterior and _herramienta == _herramienta_anterior
		and _arrastrando == _arrastre_anterior and lado == _lado_anterior
	):
		return
	_celda_anterior = celda
	_herramienta_anterior = _herramienta
	_arrastre_anterior = _arrastrando
	_lado_anterior = lado
	_preview_caja.visible = true
	_preview_texto.visible = true
	# Por defecto, apagado: solo `_refrescar_preview_elemento` lo enciende cuando la herramienta en
	# mano tiene sprite real (quick-spec §4) — así cualquier otra herramienta (muro, puerta, pincel,
	# sala) hereda el apagado sin tener que tocar sus propias funciones una por una.
	_preview_sprite.visible = false
	if _herramienta == &"demoler":
		_refrescar_preview_demoler(celda, lado)
	elif _herramienta == &"muro":
		_refrescar_preview_muro(celda, lado)
	elif _herramienta == &"puerta" or _herramienta == &"ventana":
		_refrescar_preview_puerta_ventana(celda, lado)
	elif _herramienta == HERRAMIENTA_PINTAR_PARED:
		_refrescar_preview_pintar_pared(celda, lado)
	elif _herramienta == HERRAMIENTA_PINTAR_SUELO:
		_refrescar_preview_pintar_suelo(celda)
	elif _es_sala and _arrastrando:
		_refrescar_preview_sala(_rect_entre(_celda_inicio, celda))
	else:
		_refrescar_preview_elemento(celda)


func _refrescar_preview_demoler(celda: Vector2i, lado: StringName) -> void:
	_colocar_caja(celda, Vector2i.ONE, COLOR_DEMOLER)
	var elemento_id: StringName = _construccion.elemento_en(celda)
	var sala_id: StringName = _construccion.sala_en(celda)
	if elemento_id != &"":
		_preview_texto.text = "Demoler elemento"
	elif _construccion.hay_muro(celda, lado):
		_preview_texto.text = "Demoler muro"
	elif sala_id != &"":
		_preview_texto.text = "Demoler sala (+%.0f €)" % _construccion.reembolso_de_sala(sala_id)
	else:
		_preview_texto.text = "Nada que demoler"


# ── Pincel de MURO (2026-07-30 — modelo Prison Architect: paredes libres, luego zonas) ──────────

## Fantasma del pincel de muro: resalta la ARISTA (no la celda) y avisa si ya hay muro, si cae fuera
## del edificio o si no hay caja — mismo lenguaje visual verde/rojo que el resto de herramientas.
func _refrescar_preview_muro(celda: Vector2i, lado: StringName) -> void:
	var ya_hay: bool = _construccion.hay_muro(celda, lado)
	var en_edificio: bool = _arista_en_edificio(celda, lado)
	var con_caja: bool = _construccion.puede_pagar(_construccion.coste_muro)
	var valido: bool = not ya_hay and en_edificio and con_caja
	_colocar_caja_arista(celda, lado, COLOR_VALIDO if valido else COLOR_INVALIDO)
	var motivo: String = "Arrastra para tabique"
	if ya_hay:
		motivo = "Ya hay muro"
	elif not en_edificio:
		motivo = "Fuera del edificio"
	elif not con_caja:
		motivo = "Sin caja"
	_preview_texto.text = "%.0f € · %s" % [_construccion.coste_muro, motivo]


## Fantasma del pincel de puerta/ventana: resalta la ARISTA (mismo recuadro fino que el muro) y avisa
## si ahí no hay tabique que convertir o si ya es de ese tipo — mismo criterio que la acción real
## (`fijar_tipo_de_muro`), así el jugador ve el "no" antes de hacer clic en vano.
func _refrescar_preview_puerta_ventana(celda: Vector2i, lado: StringName) -> void:
	var tipo_actual: StringName = _construccion.tipo_de_muro(celda, lado)
	var hay_tabique: bool = tipo_actual != &""
	var ya_es: bool = tipo_actual == _herramienta
	var valido: bool = hay_tabique and not ya_es
	_colocar_caja_arista(celda, lado, COLOR_VALIDO if valido else COLOR_INVALIDO)
	var nombre: String = "Puerta" if _herramienta == &"puerta" else "Ventana"
	var motivo: String = "Clic para convertir"
	if not hay_tabique:
		motivo = "Primero levanta la pared ahí"
	elif ya_es:
		motivo = "Ya hay " + nombre.to_lower() + " ahí"
	_preview_texto.text = nombre + " · " + motivo


## Fantasma del pincel de PARED: resalta la arista con EL COLOR QUE VAS A APLICAR (no el verde/rojo
## genérico) cuando se puede pintar — así ves el color sobre la pared antes de soltar el clic — y en
## rojo cuando no. Avisa también de si MAYÚS va a pintar la sala entera.
func _refrescar_preview_pintar_pared(celda: Vector2i, lado: StringName) -> void:
	var clave: String = _construccion.clave_de_muro(celda, lado)
	var hay_pared: bool = _construccion.tipo_de_muro(celda, lado) != &""
	var es_fachada: bool = _construccion.es_muro_fijo(clave)
	var valido: bool = hay_pared and not es_fachada
	_colocar_caja_arista(celda, lado, _color_pincel if valido else COLOR_INVALIDO)
	var motivo: String = "Clic pinta el tramo · MAYÚS pinta la sala"
	if not hay_pared:
		motivo = "Ahí no hay pared que pintar"
	elif es_fachada:
		motivo = "La fachada no se pinta"
	elif _construccion.sala_en(celda) == &"":
		motivo = "Clic pinta el tramo (muro suelto: MAYÚS no amplía)"
	_preview_texto.text = "🖌 Pared · " + motivo


## Fantasma del pincel de SUELO: la celda entera con el color elegido. Con MAYÚS pulsada dibuja la
## huella de la SALA COMPLETA (su caja envolvente), que es lo que va a pintar ese clic — el jugador
## ve el alcance del gesto antes de hacerlo.
func _refrescar_preview_pintar_suelo(celda: Vector2i) -> void:
	var sala_id: StringName = _construccion.sala_en(celda)
	var mayus: bool = Input.is_key_pressed(KEY_SHIFT)
	if mayus and sala_id != &"":
		var rect: Rect2i = _construccion.rect_de_sala(sala_id)
		_colocar_caja(rect.position, rect.size, _color_pincel)
		_preview_texto.text = "🖌 Suelo · toda la sala (%d celdas)" % _construccion.area_de_sala(sala_id)
		return
	var dentro: bool = _celda_en_edificio(celda)
	_colocar_caja(celda, Vector2i.ONE, _color_pincel if dentro else COLOR_INVALIDO)
	if not dentro:
		_preview_texto.text = "🖌 Suelo · fuera del edificio"
		return
	_preview_texto.text = (
		"🖌 Suelo · clic pinta la celda · MAYÚS pinta la sala" if sala_id != &""
		else "🖌 Suelo · clic pinta la celda (sin sala: MAYÚS no amplía)"
	)


## Construye o demuele (según `_construyendo_arrastre_muro`) la arista más cercana al punto DEL
## EVENTO. La llaman tanto el clic inicial como cada evento de movimiento del arrastre; la guarda de
## "misma arista que la última vez" evita repetir la orden mientras el cursor sigue sobre el mismo
## tramo entre dos eventos (cero llamadas de más — regla del proyecto).
func _pintar_arista_muro(punto_mundo: Vector2) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var lado: StringName = _lado_mas_cercano(punto_mundo, celda)
	var clave: String = _construccion.clave_de_muro(celda, lado)
	if clave == "":
		return
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return
	# El arrastre se CLAVA a un eje: la primera arista decide la orientacion y la coordenada fija.
	# Desviarse en perpendicular se ignora, en vez de meter un tabique transversal.
	if _eje_arrastre_muro == "":
		_eje_arrastre_muro = partes[0]
		_fija_arrastre_muro = int(partes[2]) if partes[0] == "h" else int(partes[1])
		_desde_arrastre_muro = int(partes[1]) if partes[0] == "h" else int(partes[2])
	elif partes[0] != _eje_arrastre_muro:
		return
	# 🐛 2026-07-30, el usuario: "la linea recta queda un poco rara porque se mueve un poco, deberia
	# validar cuando se suelta el boton izq del raton y que dibuje lineas enteras". Antes se
	# CONSTRUIA tramo a tramo segun pasabas: cada trozo quedaba puesto y PAGADO al instante, asi que
	# el trazo "se movia" y no habia forma de corregirlo. Ahora esto solo ANOTA hasta donde llega la
	# linea; lo que se construye se decide al SOLTAR (`_aplicar_linea_muro`).
	_hasta_arrastre_muro = int(partes[1]) if partes[0] == "h" else int(partes[2])
	_refrescar_preview_linea_muro()


## Las aristas de la linea que se esta trazando ahora mismo, del principio al final del arrastre.
## Vacio si no hay trazo. Es lo que se previsualiza y lo que se aplicara al soltar.
func _aristas_de_la_linea() -> Array:
	var salida: Array = []
	if _eje_arrastre_muro == "":
		return salida
	var desde: int = mini(_desde_arrastre_muro, _hasta_arrastre_muro)
	var hasta: int = maxi(_desde_arrastre_muro, _hasta_arrastre_muro)
	for v: int in range(desde, hasta + 1):
		if _eje_arrastre_muro == "h":
			salida.append([Vector2i(v, _fija_arrastre_muro), &"arriba"])
		else:
			salida.append([Vector2i(_fija_arrastre_muro, v), &"izquierda"])
	return salida


## Aplica de una vez toda la linea trazada. Se llama AL SOLTAR el boton, nunca antes.
func _aplicar_linea_muro() -> void:
	var aristas: Array = _aristas_de_la_linea()
	if aristas.is_empty():
		return
	var puestos: int = 0
	var sin_caja: bool = false
	for arista: Array in aristas:
		if _construyendo_arrastre_muro:
			if _construccion.construir_muro(arista[0], arista[1]):
				puestos += 1
			elif not _construccion.hay_muro(arista[0], arista[1]):
				sin_caja = true   # no habia muro y aun asi fallo: se acabo el dinero
		else:
			if _construccion.demoler_muro(arista[0], arista[1]):
				puestos += 1
	if sin_caja:
		_lbl_estado.text = "Se acabo el dinero: puestos %d tramos de %d" % [puestos, aristas.size()]
	elif _construyendo_arrastre_muro:
		_lbl_estado.text = "%d tramos de muro" % puestos
	else:
		_lbl_estado.text = "%d tramos derribados" % puestos


## Mientras arrastras: dice cuantos tramos llevas y lo que van a costar. Sin esto no hay forma de
## saber el gasto de un trazo largo (cada tramo son `coste_muro` euros).
func _refrescar_preview_linea_muro() -> void:
	var aristas: Array = _aristas_de_la_linea()
	if aristas.is_empty():
		return
	if not _construyendo_arrastre_muro:
		_lbl_estado.text = "Derribar %d tramos" % aristas.size()
		return
	var nuevos: int = 0
	for arista: Array in aristas:
		if not _construccion.hay_muro(arista[0], arista[1]):
			nuevos += 1
	_lbl_estado.text = "%d tramos · %d €  (suelta para construir)" % [
		nuevos, roundi(float(nuevos) * _construccion.coste_muro),
	]


## El lado de `celda` (izquierda/derecha/arriba/abajo) más cercano a `punto_mundo`: compara la
## posición del ratón DENTRO de la celda contra sus 4 bordes y devuelve el más próximo. Así el
## pincel resalta la ARISTA que se va a construir, no la celda entera.
func _lado_mas_cercano(punto_mundo: Vector2, celda: Vector2i) -> StringName:
	# ISOMÉTRICO (2026-07-30): la cuenta de "¿a qué lado estoy más cerca?" solo tiene sentido en el
	# plano CUADRADO — en pantalla los cuatro lados son diagonales y las distancias no se comparan
	# igual. Así que primero se deshace la proyección y luego se hace la misma cuenta de siempre.
	var cuadrado: Vector2 = _construccion.punto_cuadrado_de(punto_mundo)
	var esquina := Vector2(float(celda.x), float(celda.y)) * float(_tam_celda)
	var local: Vector2 = (cuadrado - esquina) / float(_tam_celda)   # 0..1 dentro de la celda
	var dist_izquierda: float = local.x
	var dist_derecha: float = 1.0 - local.x
	var dist_arriba: float = local.y
	var dist_abajo: float = 1.0 - local.y
	var minimo: float = minf(minf(dist_izquierda, dist_derecha), minf(dist_arriba, dist_abajo))
	if minimo == dist_izquierda:
		return &"izquierda"
	if minimo == dist_derecha:
		return &"derecha"
	if minimo == dist_arriba:
		return &"arriba"
	return &"abajo"


## Duplicado A PROPÓSITO de `Construccion._arista_dentro_del_edificio` (privado — la tarea prohíbe
## tocar `construccion.gd`): SOLO para pintar el fantasma del color correcto en el borde del
## edificio. La autoridad real la sigue teniendo `construir_muro`, que vuelve a comprobarlo al
## construir de verdad — esto es puramente informativo (mismo criterio que `_superficie_de_herramienta`).
func _arista_en_edificio(celda: Vector2i, lado: StringName) -> bool:
	var vecino: Vector2i = celda
	match lado:
		&"izquierda":
			vecino = celda + Vector2i(-1, 0)
		&"derecha":
			vecino = celda + Vector2i(1, 0)
		&"arriba":
			vecino = celda + Vector2i(0, -1)
		&"abajo":
			vecino = celda + Vector2i(0, 1)
	return _celda_en_edificio(celda) or _celda_en_edificio(vecino)


## ¿Esa celda cae dentro de la rejilla del edificio? (mismo cálculo que `Construccion._celda_en_edificio`).
func _celda_en_edificio(celda: Vector2i) -> bool:
	return (
		celda.x >= 0 and celda.y >= 0
		and celda.x < _construccion.edificio_columnas and celda.y < _construccion.edificio_filas
	)


## Convierte una posición de PANTALLA (la que trae el evento) a coordenadas de MUNDO, con la
## transformada del canvas — mismo patrón que usa Main para el clic derecho del ciudadano (mismo
## gotcha: el punto tiene que salir DEL EVENTO, nunca de `get_global_mouse_position()`).
func _punto_mundo_del_evento(pos_pantalla: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * pos_pantalla


## Coloca la caja del preview cubriendo SOLO la arista `lado` de `celda` (grosor `GROSOR_PREVIEW_MURO`,
## centrado en la línea de rejilla) — reutiliza el mismo Panel/StyleBox que `_colocar_caja`, solo con
## otra geometría, así que no hace falta ningún nodo nuevo.
func _colocar_caja_arista(celda: Vector2i, lado: StringName, color: Color) -> void:
	# ISOMÉTRICO: la arista deja de ser un lado horizontal o vertical de un cuadrado y pasa a ser
	# uno de los cuatro lados en diagonal del rombo. Se resalta como una LÍNEA gruesa de vértice a
	# vértice, que es exactamente el tramo de muro que se va a construir.
	var desde: Vector2
	var hasta: Vector2
	match lado:
		&"izquierda":
			desde = _construccion.esquina_en_pantalla(celda.x, celda.y)
			hasta = _construccion.esquina_en_pantalla(celda.x, celda.y + 1)
		&"derecha":
			desde = _construccion.esquina_en_pantalla(celda.x + 1, celda.y)
			hasta = _construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1)
		&"arriba":
			desde = _construccion.esquina_en_pantalla(celda.x, celda.y)
			hasta = _construccion.esquina_en_pantalla(celda.x + 1, celda.y)
		_:   # "abajo"
			desde = _construccion.esquina_en_pantalla(celda.x, celda.y + 1)
			hasta = _construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1)
	_preview_caja.pintar_linea(desde, hasta, GROSOR_PREVIEW_MURO, color)
	_preview_texto.position = (desde + hasta) / 2.0 + Vector2(-60.0, -30.0)


func _refrescar_preview_sala(rect: Rect2i) -> void:
	# Enmienda 007: pegado/solapado a una sala del mismo tipo = AMPLIACIÓN (solo celdas nuevas).
	var ampliable: StringName = _construccion.sala_ampliable(_herramienta, rect)
	var coste: float
	var valido: bool
	var accion: String
	if ampliable != &"":
		coste = _construccion.coste_ampliacion(ampliable, rect)
		valido = true
		accion = "AMPLIAR sala"
	else:
		coste = _construccion.coste_sala(_herramienta, rect)
		valido = _construccion.validar_sala(_herramienta, rect)
		accion = "Sala nueva"
	var con_caja: bool = _construccion.puede_pagar(coste)
	_colocar_caja(rect.position, rect.size, COLOR_VALIDO if valido and con_caja else COLOR_INVALIDO)
	_preview_texto.text = "%s · %d celdas · %.0f € · %s" % [
		accion, rect.get_area(), coste,
		"Suelta para confirmar" if valido and con_caja else ("Sin caja" if valido else "No válido"),
	]


func _refrescar_preview_elemento(celda: Vector2i) -> void:
	var coste: float = _construccion.coste_elemento(_herramienta)
	var valido: bool = _construccion.validar_elemento(_herramienta, celda, &"", _orientacion)
	var con_caja: bool = _construccion.puede_pagar(coste)
	if _es_sala:
		# Herramienta de sala sin arrastrar aún: pista de uso sobre la celda.
		_colocar_caja(celda, Vector2i.ONE, COLOR_VALIDO)
		_preview_texto.text = "Arrastra para dibujar (pegado a una sala igual, la amplía)"
		return
	# Bug corregido 2026-07-29 (petición del usuario jugando: "el sofá ya sale con 3 huecos pero al
	# ponerlo para ver como ponerlo o donde solo aparece 1 cuadrado, una vez que se pone ya salen 3"):
	# el fantasma dibujaba SIEMPRE 1 celda aunque el objeto ocupe más. `validar_elemento` YA valida el
	# CUERPO entero (ancla + `superficie - 1` celdas hacia +X, misma convención que
	# `Construccion._celdas_de`) — si una sola celda del cuerpo no cabe, `valido` ya sale false; aquí
	# solo faltaba pintar la caja con el mismo ancho que va a ocupar de verdad.
	var superficie: int = _superficie_de_herramienta()
	# La huella del fantasma gira con la pieza (R): el mismo eje que va a reservar el modelo.
	var huella: Vector2i = (
		Vector2i(1, superficie) if _orientacion == _construccion.VERTICAL
		else Vector2i(superficie, 1)
	)
	var puede: bool = valido and con_caja
	# SPRITE REAL en vez de caja gris (quick-spec 2026-08-04 §4): si el catálogo tiene arte para esta
	# herramienta, el fantasma es el mueble de verdad, semitransparente y teñido de válido/inválido.
	# Si no (las comodidades que se quedan sin renderizar), la caja de siempre — cero cambio para ellas.
	var sprite_datos: Dictionary = _sprite_de_herramienta(_herramienta, _orientacion, superficie)
	if sprite_datos["textura"] != null:
		_mostrar_fantasma_sprite(celda, sprite_datos, puede)
	else:
		_colocar_caja(celda, huella, COLOR_VALIDO if puede else COLOR_INVALIDO)
	var pista: String = "  ·  R para girar" if superficie > 1 else ""
	_preview_texto.text = "%.0f € · %s%s" % [
		coste, "Válido" if puede else ("Sin caja" if valido else "No válido"), pista,
	]


## ── FANTASMA CON SPRITE REAL (quick-spec 2026-08-04 §4) ────────────────────────────────────────
## Comodidades de 1 celda con render propio: el MISMO conjunto que `Construccion._sprites_comodidad()`
## (privado — la tarea prohíbe tocar `construccion.gd`). Duplicado A PROPÓSITO, mismo patrón que ya
## usa `_superficie_de_herramienta` para espejar `Construccion._superficie_de`: si mañana se añade
## una comodidad con sprite nuevo, hace falta tocar las DOS listas (aquí y en `construccion.gd`) —
## el mismo coste que ya paga hoy cualquier comodidad nueva sin sprite (nada) o con sprite (un alta
## en cada sitio). Todas a rotación 0: ninguna comodidad de 1 celda tiene "frente".
const COMODIDADES_CON_SPRITE: Array[StringName] = [
	&"equipo_informatico", &"papelera", &"dispensador_agua", &"radio",
]


## Los datos para pintar el fantasma como sprite (`{"textura", "paso", "celdas"}`) o vacío
## (`textura == null`) si `herramienta` no tiene arte propio — entonces manda la caja de siempre.
## `celdas` es la MISMA superficie que ya calcula `_superficie_de_herramienta` (pasada por el
## llamante): ni un dato nuevo, la fuente de verdad sigue siendo el catálogo.
func _sprite_de_herramienta(herramienta: StringName, orientacion: int, celdas: int) -> Dictionary:
	var vacio: Dictionary = {"textura": null, "paso": Vector2i.ZERO, "celdas": 1}
	if _construccion == null:
		return vacio
	# El sofá de 3 plazas: DOS rotaciones según H/V (mismo criterio que
	# `Construccion._rotacion_asiento_sofa3`, privada — espejado aquí igual que el resto de esta
	# sección).
	if herramienta == _construccion.COMODIDAD_SOFA_DESCANSO:
		var rot: int = (
			_construccion.ROT_ASIENTO_SOFA3_HORIZONTAL if orientacion == _construccion.HORIZONTAL
			else _construccion.ROT_ASIENTO_SOFA3_VERTICAL
		)
		var ruta: String = "%s%s_%d.png" % [
			_construccion.RUTA_SPRITES_MOBILIARIO, _construccion.ASIENTO_SOFA3, rot,
		]
		if ResourceLoader.exists(ruta):
			return {
				"textura": _textura_cacheada(ruta), "paso": _paso_de_orientacion(orientacion),
				"celdas": celdas,
			}
		return vacio
	if COMODIDADES_CON_SPRITE.has(herramienta):
		var ruta2: String = "%scomodidad_%s_0.png" % [_construccion.RUTA_SPRITES_MOBILIARIO, String(herramienta)]
		if ResourceLoader.exists(ruta2):
			return {"textura": _textura_cacheada(ruta2), "paso": Vector2i(1, 0), "celdas": celdas}
		return vacio
	# PUESTOS (ventanilla): el mostrador de 2 celdas, en su ÚNICA rotación (0°) — el mostrador de
	# verdad NUNCA gira con la herramienta, ni siquiera con R (ver la cabecera de `MesaAtencion.
	# construir`: siempre `Vector2i(1, 0)`, `ID_SPRITE_MOSTRADOR_2`). El fantasma copia ese
	# comportamiento en vez de inventarse uno propio, porque es justo lo que va a construirse.
	#
	# DECISIÓN (documentada, quick-spec §4 lo autoriza expresamente: "mostrador + contorno de huella
	# vale"): el fantasma cubre el MOSTRADOR (2 celdas, lo único que `Construccion` reserva de
	# verdad en su modelo) y NO monta la ventanilla completa (funcionario+mostrador+ciudadano, las 6
	# celdas de `NPCsFlujo._asegurar_visual_puesto`) — esa composición vive en `npcs_flujo.gd`
	# (prohibido tocar en esta tarea) y solo se construye para un puesto YA DADO DE ALTA en el
	# modelo, no para uno que todavía es una herramienta en la mano. Montarla en el fantasma exigiría
	# duplicar sillas/arrimes/anclas de otro fichero entero para una vista previa — el mostrador solo
	# ya cumple la promesa del spec ("como quedaría el objeto real") sin ese acoplamiento.
	if Datos.obtener_silencioso(&"TipoPuesto", herramienta) != null:
		var ruta3: String = "%s%s_%d.png" % [
			MesaAtencionScript.RUTA_SPRITES_MOBILIARIO, MesaAtencionScript.ID_SPRITE_MOSTRADOR_2,
			MesaAtencionScript.ROT_MOSTRADOR,
		]
		if ResourceLoader.exists(ruta3):
			return {"textura": _textura_cacheada(ruta3), "paso": Vector2i(1, 0), "celdas": celdas}
		return vacio
	return vacio


## Espeja `Construccion._paso_de` (privada): hacia dónde crece el cuerpo de la pieza según su
## orientación (H → este, V → sur). Mismo duplicado a propósito que el resto de esta sección.
func _paso_de_orientacion(orientacion: int) -> Vector2i:
	return Vector2i(0, 1) if orientacion == _construccion.VERTICAL else Vector2i(1, 0)


## Carga perezosa y cacheada (regla de rendimiento de la tarea: nada de recargar texturas cada
## frame). La guarda de `_process` ya limita cuándo se llega hasta aquí (solo al cambiar de
## celda/herramienta/rotación) — esta caché evita además repetir la carga de disco entre dos
## herramientas distintas que compartan textura, o si la guarda deja pasar más de una vez seguida.
func _textura_cacheada(ruta: String) -> Texture2D:
	if not _cache_texturas_fantasma.has(ruta):
		_cache_texturas_fantasma[ruta] = load(ruta)
	return _cache_texturas_fantasma[ruta]


## Coloca el fantasma de SPRITE REAL exactamente donde `AnclajeSprite` anclaría el objeto de verdad
## (misma cuenta, cero anclas a mano — orden de la tarea): `raiz` de un mueble real vive en
## `centro_en_pantalla(celda_ancla)` y su sprite se desplaza `delta_ultima_celda(paso, celdas)` desde
## ahí (ver `Construccion._crear_pieza`/`MesaAtencion.construir`); aquí no hay nodo "raíz" aparte —
## se suman los dos directamente en la POSICIÓN de este único `Sprite2D`, y `AnclajeSprite.aplicar`
## pone el `offset`/`centered` que le tocan. Tinte verde-blanco válido / rojo inválido, igual criterio
## que la caja genérica, aplicado como `modulate` en vez de relleno de polígono.
func _mostrar_fantasma_sprite(celda: Vector2i, datos: Dictionary, puede: bool) -> void:
	_preview_caja.visible = false
	_preview_sprite.visible = true
	_preview_sprite.texture = datos["textura"]
	AnclajeSprite.aplicar(_preview_sprite, datos["paso"], datos["celdas"])
	_preview_sprite.position = (
		_construccion.centro_en_pantalla(celda)
		+ Proyeccion.delta_ultima_celda(datos["paso"], datos["celdas"])
	)
	_preview_sprite.modulate = TINTE_FANTASMA_VALIDO if puede else TINTE_FANTASMA_INVALIDO
	_preview_texto.position = (
		_construccion.esquina_en_pantalla(celda.x, celda.y) + Vector2(-60.0, -26.0)
	)


## Superficie (celdas hacia +X desde el ancla) de la herramienta en mano — para que el fantasma se
## dibuje con el mismo ancho que `Construccion` va a reservar de verdad. Espeja
## `Construccion._superficie_de` (privada, no invocable desde aquí) leyendo el MISMO catálogo
## (Datos): ningún dato nuevo, misma convención ya vigente para el elemento ya colocado.
func _superficie_de_herramienta() -> int:
	if _herramienta == _construccion.ASIENTO_BASICO:
		return 1
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", _herramienta)
	if comodidad != null:
		return maxi(comodidad.superficie, 1)
	var tipo_puesto: Resource = Datos.obtener_silencioso(&"TipoPuesto", _herramienta)
	if tipo_puesto != null:
		return maxi(tipo_puesto.superficie, 1)
	return 1


## Coloca la caja del preview cubriendo `tam` celdas desde `celda` (coordenadas de mundo). El color
## se aplica como relleno translúcido + BORDE casi opaco (visible sobre cualquier sala).
func _colocar_caja(celda: Vector2i, tam: Vector2i, color: Color) -> void:
	# ISOMÉTRICO: la huella de un bloque de celdas es el ROMBO que forman sus cuatro esquinas de
	# rejilla proyectadas — no un rectángulo recto.
	var arriba: Vector2 = _construccion.esquina_en_pantalla(celda.x, celda.y)
	var derecha: Vector2 = _construccion.esquina_en_pantalla(celda.x + tam.x, celda.y)
	var abajo: Vector2 = _construccion.esquina_en_pantalla(celda.x + tam.x, celda.y + tam.y)
	var izquierda: Vector2 = _construccion.esquina_en_pantalla(celda.x, celda.y + tam.y)
	_preview_caja.pintar_poligono(
		PackedVector2Array([arriba, derecha, abajo, izquierda]), color
	)
	# El texto, sobre el vértice más alto de la huella (es el punto que nunca tapa el propio rombo).
	_preview_texto.position = arriba + Vector2(-60.0, -26.0)


func _rect_entre(a: Vector2i, b: Vector2i) -> Rect2i:
	var origen := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var fin := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(origen, fin - origen + Vector2i.ONE)


# ── UI del andamio (barra inferior por código; botones con focus_mode NONE — gotcha Espacio) ─
func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	capa.name = "UIConstruccion"
	add_child(capa)
	# Atenuador del mundo en modo construcción (deja pasar el ratón).
	_atenuador = ColorRect.new()
	_atenuador.color = Color(0.0, 0.0, 0.0, 0.18)
	_atenuador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atenuador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_atenuador)

	# Preview fantasma POR ENCIMA del atenuador (feedback del usuario: no se veía dónde iba a caer).
	# Sin cámara, las coordenadas de mundo y de pantalla coinciden → puede vivir en la CanvasLayer.
	# Borde grueso + relleno translúcido: se distingue sobre cualquier color de sala.
	_preview_caja = PreviewIso.new()
	_preview_caja.visible = false
	capa.add_child(_preview_caja)
	# El fantasma de SPRITE REAL (quick-spec §4), hermano de la caja de arriba — mismo criterio de
	# capa (por encima del atenuador, por debajo del texto que se añade a continuación).
	_preview_sprite = Sprite2D.new()
	_preview_sprite.visible = false
	capa.add_child(_preview_sprite)
	_preview_texto = Label.new()
	_preview_texto.visible = false
	_preview_texto.add_theme_font_size_override("font_size", 13)
	_preview_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_texto.add_theme_constant_override("outline_size", 4)
	capa.add_child(_preview_texto)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Gotcha de anclas (el bug del "menú invisible"): anclada abajo, la barra debe CRECER HACIA
	# ARRIBA; sin esto se dibuja POR DEBAJO del borde de la pantalla. Y se apoya sobre la barra de
	# info de Main (hueco fijo — andamio; la UI real de /ux-design lo hará bien).
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -HUECO_BARRA_INFO
	panel.offset_bottom = -HUECO_BARRA_INFO
	capa.add_child(panel)
	var caja := VBoxContainer.new()
	panel.add_child(caja)
	var fila_superior := HBoxContainer.new()
	fila_superior.add_theme_constant_override("separation", 8)
	caja.add_child(fila_superior)
	_boton_modo = Button.new()
	_boton_modo.text = "🔨 Construir (B)"
	_boton_modo.focus_mode = Control.FOCUS_NONE
	_boton_modo.pressed.connect(_alternar_modo)
	fila_superior.add_child(_boton_modo)
	_lbl_estado = Label.new()
	_lbl_estado.add_theme_font_size_override("font_size", 11)
	_lbl_estado.modulate = Color(1, 1, 1, 0.7)
	fila_superior.add_child(_lbl_estado)

	_fila_herramientas = HFlowContainer.new()
	_fila_herramientas.add_theme_constant_override("h_separation", 6)
	_fila_herramientas.add_theme_constant_override("v_separation", 4)
	caja.add_child(_fila_herramientas)
	# Los tipos se LEEN del catálogo — la UI nunca hardcodea costes/nombres (regla del GDD).
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		_anadir_herramienta("▦ %s" % tipo_sala.nombre, tipo_sala.id, true)
	for tipo_puesto: Resource in Datos.obtener_todos(&"TipoPuesto"):
		if tipo_puesto.servicio == "Seguridad":
			continue   # la entrada/seguridad es fija (CO11) — no construible en el MVP
		_anadir_herramienta(
			"%s (%d €)" % [tipo_puesto.nombre, tipo_puesto.coste_construccion_eur], tipo_puesto.id, false
		)
	_anadir_herramienta(
		"Asiento (%.0f €)" % _construccion.coste_asiento_basico, _construccion.ASIENTO_BASICO, false
	)
	# Muro LIBRE (2026-07-30 — Fase A del modelo Prison Architect): se pinta por arista, no por
	# celda, así que no es "es_sala" (no dibuja un rectángulo) ni un elemento normal (no ocupa celda).
	_anadir_herramienta("🧱 Muro (%.0f €)" % _construccion.coste_muro, &"muro", false)
	# PUERTA y VENTANA (FASE D, 2026-07-30): no levantan tabique nuevo, CONVIERTEN uno ya construido
	# — por eso no llevan un coste propio en el rótulo (el gasto fue el muro; abrir el hueco es
	# gratis, ver `Construccion.fijar_tipo_de_muro`).
	_anadir_herramienta("🚪 Puerta", &"puerta", false)
	_anadir_herramienta("🪟 Ventana", &"ventana", false)
	# PINCEL DE PINTURA (2026-08-04): gratis, como abrir un hueco — pintar no es obra, es acabado.
	# Dos botones (pared / suelo) porque el gesto es distinto: arista contra celda (ver la cabecera).
	_anadir_herramienta("🖌 Pintar pared", HERRAMIENTA_PINTAR_PARED, false)
	_anadir_herramienta("🖌 Pintar suelo", HERRAMIENTA_PINTAR_SUELO, false)
	# FASE C (2026-07-30): marcar ZONAS dentro de lo que has cerrado con muros. Un boton por tipo de
	# sala del catalogo, con el prefijo "zona:" en el id para distinguirlo del pincel que DIBUJA la
	# sala como rectangulo (que sigue existiendo: son dos formas validas de construir).
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		_anadir_herramienta(
			"📍 Zona: %s" % tipo_sala.nombre, StringName("zona:" + String(tipo_sala.id)), false
		)
	var casilla := CheckBox.new()
	casilla.text = "Con paredes"
	casilla.focus_mode = Control.FOCUS_NONE
	casilla.tooltip_text = "Si esta marcado, la sala que dibujes nacera cerrada con muros"
	casilla.toggled.connect(func(activo: bool) -> void: _nueva_sala_con_paredes = activo)
	_fila_herramientas.add_child(casilla)
	_anadir_herramienta("❌ Demoler", &"demoler", false)

	# ── SUBMENÚ DEL PINCEL: la rejilla de 30 muestras ─────────────────────────────────────────
	# Va en una fila PROPIA debajo de las herramientas (no mezclada entre los botones): es el menú
	# contextual del pincel y solo aparece cuando llevas uno en la mano. 5 columnas = una FAMILIA de
	# la paleta por fila (neutros, azules, verdes, tierras, amarillos, rojos), que es como está
	# ordenada `PaletaPintura.COLORES` — la agrupación se lee sola, sin rótulos que ocupen sitio.
	_rejilla_paleta = GridContainer.new()
	_rejilla_paleta.columns = 5
	_rejilla_paleta.add_theme_constant_override("h_separation", 3)
	_rejilla_paleta.add_theme_constant_override("v_separation", 3)
	_rejilla_paleta.visible = false
	caja.add_child(_rejilla_paleta)
	for i: int in PaletaPinturaScript.COLORES.size():
		var muestra := Button.new()
		muestra.custom_minimum_size = LADO_MUESTRA
		muestra.focus_mode = Control.FOCUS_NONE
		muestra.tooltip_text = String(PaletaPinturaScript.COLORES[i]["nombre"])
		var indice: int = i   # captura por valor: sin esto los 30 botones comparten la última i
		muestra.pressed.connect(func() -> void: _elegir_color(indice))
		_rejilla_paleta.add_child(muestra)
		_muestras.append(muestra)
	_elegir_color(0)   # blanco puro: el color de partida, el mismo que trae toda pared nueva

	_dialogo_cascada = ConfirmationDialog.new()
	_dialogo_cascada.title = "Demolición en cascada"
	_dialogo_cascada.confirmed.connect(func() -> void: _construccion.demoler_sala(_sala_a_demoler))
	capa.add_child(_dialogo_cascada)


func _anadir_herramienta(texto: String, id: StringName, es_sala: bool) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func() -> void: _fijar_herramienta(id, es_sala))
	_fila_herramientas.add_child(boton)
	_botones_herramienta[id] = boton


func _actualizar_visibilidad() -> void:
	_fila_herramientas.visible = _activo
	_atenuador.visible = _activo
	# LA CUADRÍCULA VIVE Y MUERE CON EL MODO (2026-08-05 · quick-spec §3c). Este es el ÚNICO sitio
	# donde se enciende: `_alternar_modo` y `activar_con_herramienta` ya pasan por aquí.
	if _rejilla != null:
		_rejilla.visible = _activo
	if _rejilla_paleta != null and not _activo:
		_rejilla_paleta.visible = false   # fuera del modo construcción no hay pincel ni paleta
	_boton_modo.modulate = COLOR_BOTON_ACTIVO if _activo else Color.WHITE
	_lbl_estado.text = (
		"Elige herramienta · clic coloca · arrastra dibuja salas · clic dcho/Esc cancela"
		if _activo else "Modo construcción apagado"
	)
	if not _activo:
		_preview_caja.visible = false
		_preview_texto.visible = false
