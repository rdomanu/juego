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
## Hueco reservado para la barra de info de Main (abajo del todo): esta barra se apoya ENCIMA.
const HUECO_BARRA_INFO := 84.0
## Grosor del resalte de ARISTA del pincel de muro (2026-07-30): más fino que la caja de una celda
## entera — así el jugador ve claramente que apunta a un LADO, no a la celda completa.
const GROSOR_PREVIEW_MURO := 10.0

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

# ── Nodos de UI (construidos por código, patrón del HUD del esqueleto) ───────────────────────
var _atenuador: ColorRect
## HFlowContainer (no HBox): con los nombres del catálogo la fila supera el ancho de la ventana y
## los últimos botones (Asiento, Demoler) quedaban FUERA de pantalla — el flow envuelve en filas.
var _fila_herramientas: HFlowContainer
var _lbl_estado: Label
var _boton_modo: Button
var _botones_herramienta: Dictionary = {}
var _preview_caja: PreviewIso
var _preview_texto: Label


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
var _dialogo_cascada: ConfirmationDialog
var _sala_a_demoler: StringName = &""


## Inyección de dependencias (la llama Main ANTES de add_child).
func configurar(construccion: Node, tam_celda: int) -> void:
	_construccion = construccion
	_tam_celda = tam_celda


func _ready() -> void:
	_crear_ui()
	_actualizar_visibilidad()


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
	if _arrastrando_muro and evento is InputEventMouseMotion:
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
		elif _arrastrando_muro and not _construyendo_arrastre_muro:
			_aplicar_linea_muro()   # se construye AL SOLTAR, no mientras arrastras
			_arrastrando_muro = false
			_eje_arrastre_muro = ""   # el trazo termina: el proximo elige su propio eje
	elif boton.button_index == MOUSE_BUTTON_LEFT:
		if boton.pressed:
			_al_pulsar(punto_mundo)
		else:
			if _arrastrando_muro and _construyendo_arrastre_muro:
				_aplicar_linea_muro()   # se construye AL SOLTAR, no mientras arrastras
				_arrastrando_muro = false
				_eje_arrastre_muro = ""   # el trazo termina: el proximo elige su propio eje
			_al_soltar()


func _al_pulsar(punto_mundo: Vector2) -> void:
	if _herramienta == &"":
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
	_construccion.construir_sala(
		_herramienta, _rect_entre(_celda_inicio, _construccion.celda_bajo_cursor()),
		1 if _nueva_sala_con_paredes else -1
	)


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
## `fijar_tipo_de_muro` es quien decide si hay algo que convertir: si esa arista no tiene tabique
## avisa y no hace nada — aquí se traduce ese resultado a un mensaje legible en vez de fallar en
## silencio.
func _convertir_arista_en(punto_mundo: Vector2, tipo: StringName) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var lado: StringName = _lado_mas_cercano(punto_mundo, celda)
	if _construccion.fijar_tipo_de_muro(celda, lado, tipo):
		_lbl_estado.text = "Puerta abierta" if tipo == &"puerta" else "Ventana abierta"
	else:
		_lbl_estado.text = "Primero levanta la pared ahí"


## Cancela por capas: primero el arrastre (sala O muro), luego suelta la herramienta, luego sale del modo.
func _cancelar() -> void:
	if _arrastrando or _arrastrando_muro:
		_arrastrando = false
		# Al CANCELAR o salir del modo el trazo se DESCARTA (no se construye): es lo que
		# espera quien pulsa Escape o cambia de herramienta a media linea.
		_arrastrando_muro = false
		_eje_arrastre_muro = ""   # el trazo termina: el proximo elige su propio eje
	elif _herramienta != &"":
		_fijar_herramienta(&"", false)
	else:
		_alternar_modo()


func _alternar_modo() -> void:
	_activo = not _activo
	_arrastrando = false
	# Al CANCELAR o salir del modo el trazo se DESCARTA (no se construye): es lo que
	# espera quien pulsa Escape o cambia de herramienta a media linea.
	_arrastrando_muro = false
	_eje_arrastre_muro = ""   # el trazo termina: el proximo elige su propio eje
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


func _fijar_herramienta(id: StringName, es_sala: bool) -> void:
	_herramienta = id
	_es_sala = es_sala
	for boton_id: StringName in _botones_herramienta:
		(_botones_herramienta[boton_id] as Button).modulate = (
			COLOR_BOTON_ACTIVO if boton_id == id else Color.WHITE
		)


# ── Preview fantasma (dibujo en _process con guarda de celda — ADR-0001) ─────────────────────
func _process(_delta: float) -> void:
	if not _activo or _herramienta == &"":
		_preview_caja.visible = false
		_preview_texto.visible = false
		_celda_anterior = Vector2i(-999, -999)
		_lado_anterior = &"-"
		return
	var celda: Vector2i = _construccion.celda_bajo_cursor()
	# El LADO solo importa para el pincel de muro (los demás previews cubren la celda entera); se
	# calcula aquí una única vez y se reutiliza tanto en la guarda como en el propio preview. Live
	# poll (`get_global_mouse_position`) vale para un FANTASMA (no muta el modelo) — el gotcha de
	# "usa el punto del evento" es para las ACCIONES (pintar/demoler de verdad), no para dibujar.
	var lado: StringName = &"-"
	if (
		_herramienta == &"muro" or _herramienta == &"demoler"
		or _herramienta == &"puerta" or _herramienta == &"ventana"
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
	if _herramienta == &"demoler":
		_refrescar_preview_demoler(celda, lado)
	elif _herramienta == &"muro":
		_refrescar_preview_muro(celda, lado)
	elif _herramienta == &"puerta" or _herramienta == &"ventana":
		_refrescar_preview_puerta_ventana(celda, lado)
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
	_colocar_caja(celda, huella, COLOR_VALIDO if valido and con_caja else COLOR_INVALIDO)
	var pista: String = "  ·  R para girar" if superficie > 1 else ""
	_preview_texto.text = "%.0f € · %s%s" % [
		coste, "Válido" if valido and con_caja else ("Sin caja" if valido else "No válido"), pista,
	]


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
	_boton_modo.modulate = COLOR_BOTON_ACTIVO if _activo else Color.WHITE
	_lbl_estado.text = (
		"Elige herramienta · clic coloca · arrastra dibuja salas · clic dcho/Esc cancela"
		if _activo else "Modo construcción apagado"
	)
	if not _activo:
		_preview_caja.visible = false
		_preview_texto.visible = false
