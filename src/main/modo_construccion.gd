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

## Gemelo de `ModoDisenadorEntorno.activado_cambiado` (mismo contrato exacto): Main la escucha para
## ocultar su HUD inferior mientras este modo está activo (evita el solape barra-de-construcción ↔
## HUD, 2026-08-08). Puente hasta que la fase 2 mueva esa información arriba (decisión del usuario:
## "información ARRIBA, herramientas ABAJO") — cuando eso pase, esta señal deja de hacer falta.
signal activado_cambiado(activo: bool)

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
## **MAYÚS = LA SALA ENTERA — o EL EDIFICIO ENTERO sobre la fachada/el pasillo (2026-08-05).** Clic
## normal pinta el tramo/celda señalado; con MAYÚS pulsada pinta todas las paredes (o todo el suelo)
## de la sala. Si el tramo NO pertenece a ninguna sala —un muro suelto en mitad del edificio, el
## suelo de un pasillo—, MAYÚS ya no se limita a lo señalado: sobre un tramo de FACHADA pinta TODAS
## las paredes de la comisaría (`pintar_edificio_muros`) y sobre una celda de suelo sin sala pinta
## TODAS sus baldosas (`pintar_edificio_suelos`) — orden del usuario: *"MAYÚS también debe poder
## pintar TODAS las paredes de la comisaría"*. Un muro suelto que NO es fachada (uno levantado por
## el jugador en mitad de la nada) sigue sin ampliarse: no hay "edificio" que adivinar ahí, solo un
## tabique aislado.
const HERRAMIENTA_PINTAR_PARED := &"pintar_pared"
const HERRAMIENTA_PINTAR_SUELO := &"pintar_suelo"

## ── LAS 5 CATEGORÍAS DE LA BARRA (2026-08-07 · kit de Summer, `plan-maestro-ui.md` Apéndice B) ──
## Progressive disclosure (Hick's Law, principio 3 de `plan-maestro-ui.md`): 20+ botones sueltos →
## 5 pestañas + tarjetas contextuales. `KitUIComisario.ICONO_POR_CATEGORIA` trae el pictograma de
## cada una — este array es el ÚNICO sitio que fija el ORDEN y el rótulo (data-driven: añadir una
## categoría el día de mañana es añadir una fila aquí, no tocar el layout).
const CATEGORIAS: Array[Dictionary] = [
	{"id": &"salas", "nombre": "Salas"},
	{"id": &"muebles", "nombre": "Muebles"},
	{"id": &"muros_suelos", "nombre": "Muros y suelos"},
	{"id": &"zonas", "nombre": "Zonas"},
	{"id": &"herramientas", "nombre": "Herramientas"},
]
## Cuánto se desplaza la fila de tarjetas por cada clic en ◀/▶ (Apéndice B: "paginación por flechas
## visibles, no solo scroll de rueda").
const PASO_PAGINACION_TARJETAS: float = 260.0
const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")
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
## `ParedesSalas` (2026-08-06 · quick-spec §3f): SOLO para el picking por quad de
## `_celda_lado_de_muro_en` — este fichero sigue sin leer geometría de dibujo por su cuenta, le
## pregunta a quien ya la calculó (ADR-0004). Opcional (`null` en las herramientas de diagnóstico que
## no lo inyectan): sin él, el picking cae al de suelo de siempre (`_lado_mas_cercano`).
var _paredes_salas: Node = null

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
## Estado de MAYÚS en el último frame (2026-08-05, tarea 2): entra en la misma guarda que
## celda/herramienta/arrastre/lado — sin esto, pulsar o soltar MAYÚS sin mover el ratón no
## refrescaría el fantasma de MAYÚS (la guarda de `_process` no vería ningún cambio).
var _mayus_anterior: bool = false

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
## `CanvasLayer` APARTE para el fantasma (`_preview_*`), separada de `capa`/"UIConstruccion" (barra
## de herramientas + atenuador): su `.transform` se iguala cada frame a `get_canvas_transform()`
## (ver `_process`) para que el fantasma seleccionado SIGA a la cámara del juego (zoom/pan,
## 2026-08-04) igual que el resto del tablero -- fix del bug "cursor desviado" jugando con zoom, ver
## el comentario largo en `_crear_ui`. La barra/atenuador se quedan SIN esta transformada a
## propósito (overlay de pantalla fija).
var _capa_preview: CanvasLayer
## Contenedor MADRE de toda la barra de construcción (pestañas + fila de tarjetas + submenús de
## pincel): UN solo nodo que `_actualizar_visibilidad` enciende/apaga entero, igual que hacía la
## `HFlowContainer` de antes — el nombre se conserva por eso, aunque ya no es un flow (2026-08-07,
## rediseño con el kit de Summer: `design/ux/plan-maestro-ui.md` §2 y Apéndice B).
var _fila_herramientas: Control
## La fila de PESTAÑAS de categoría (Salas·Muebles·Muros y suelos·Zonas·Herramientas) + el hueco
## elástico + el botón Demoler anclado al borde derecho (Apéndice B: "ancla el borde de pantalla,
## Fitts's Law" — aquí el borde derecho DEL PANEL, que es lo que el wireframe pedía).
var _fila_pestanas: HBoxContainer
## La fila de tarjetas de la categoría ACTIVA, dentro de un `ScrollContainer` con flechas propias
## (Apéndice B: "paginación por flechas visibles, no solo scroll de rueda" — regla del proyecto de
## no depender solo de hover/rueda). TODAS las tarjetas viven SIEMPRE colgadas de aquí; las de las
## categorías no activas van OCULTAS (`_mostrar_categoria` solo alterna `visible` — un `BoxContainer`
## ignora a los hijos ocultos en el layout). Nada de descolgar nodos: una tarjeta sin padre no se
## libera al morir el modo (eran los 56 huérfanos por instancia que cazó gdUnit en la suite).
var _scroll_tarjetas: ScrollContainer
var _fila_tarjetas: HBoxContainer
var _boton_pagina_izq: Button
var _boton_pagina_der: Button
## La casilla "Con paredes" (2026-07-30) vive dentro de la categoría "Muros y suelos" — un control
## que no es una herramienta seleccionable, así que no pasa por `_anadir_herramienta`.
var _casilla_con_paredes: CheckBox
## Lo que se lee en una categoría sin tarjetas todavía (hoy, "Herramientas": el hueco ya existe en
## el layout para cuando llegue algo que meter ahí — Sección 2 de `plan-maestro-ui.md`, "escala sin
## rediseño"). Mejor un aviso honesto que una pestaña que parece rota.
var _lbl_categoria_vacia: Label
var _lbl_estado: Label
var _boton_modo: Button
## El PanelContainer raíz de la barra: SOLO visible con el modo activo (opción A del veredicto
## 2026-08-09 — la franja colapsada gris desapareció; abrir/cerrar vive en la píldora
## "Construir (B)" de la fila de acciones del HUD, además de la tecla B de siempre).
var _panel_raiz: PanelContainer
## Los botones de HERRAMIENTA de verdad (tarjetas + Demoler) — id → `Button`. Las 5 PESTAÑAS de
## categoría NO viven aquí (no son una `_herramienta`, cambian qué tarjetas se ven): esas están en
## `_pestanas_categoria`.
var _botones_herramienta: Dictionary = {}
## categoría (StringName) → Array[Button] de sus tarjetas, en el orden en que se registraron. La
## fuente de verdad de "qué tarjetas tiene cada pestaña" — `_mostrar_categoria` solo alterna `visible`.
var _tarjetas_por_categoria: Dictionary = {}
## categoría (StringName) → su botón de pestaña, para poder marcar cuál está activa.
var _pestanas_categoria: Dictionary = {}
## herramienta (StringName) → su categoría, la vuelta de `_tarjetas_por_categoria` — para que
## `activar_con_herramienta` (menú contextual de una sala, atajo de "pedir puerta"…) pueda saltar a
## la pestaña correcta en vez de dejar la tarjeta resaltada en una fila que no se está viendo.
var _categoria_de_herramienta: Dictionary = {}
## La categoría que se ve ahora mismo en la fila de tarjetas. Arranca en "salas" (la primera del
## wireframe): es la que más se usa nada más entrar en el modo.
var _categoria_activa: StringName = &"salas"
var _preview_caja: PreviewIso
## El fantasma de MAYÚS del pincel de pintura (quick-spec §3d, tarea 2): todos los tramos/celdas que
## se van a teñir de un vistazo, antes de soltar el clic. Ver `PreviewMayusPintura`.
var _preview_mayus: PreviewMayusPintura
## El velo de zonas del modo construcción (quick-spec §3d, tarea 3): una sala, un color. Ver
## `VeloZonas`. Vive y muere con el modo, igual que `_rejilla`.
var _velo_zonas: VeloZonas
## El fantasma con el SPRITE REAL del mueble (quick-spec 2026-08-04 §4), hermano de `_preview_caja`:
## solo uno de los dos está visible a la vez — la caja para las comodidades sin arte (12 de 16) y
## este `Sprite2D` para las que sí tienen render (comodidades con sprite, el sofá y los puestos).
## UN solo nodo cacheado (nunca se crea uno nuevo por frame): se reutiliza cambiando `texture` +
## `offset`/`centered` (vía `AnclajeSprite.aplicar`) solo cuando la guarda de celda/herramienta/
## rotación de `_process` deja pasar — ver `_mostrar_fantasma_sprite`.
var _preview_sprite: Sprite2D
## El triángulo azul de ORIENTACIÓN (2026-08-06), hermano de `_preview_sprite`/`_preview_caja`: ver
## `PreviewOrientacion`. Solo visible con un ELEMENTO en mano (`_refrescar_preview_elemento`).
var _preview_triangulo: PreviewOrientacion
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
## Acabado elegido para el pincel de SUELO (2026-08-05 · quick-spec §3d, tarea 4): `&"baldosa"`
## (junta + variación, lo de siempre) o `&"liso"` (color plano, como el suelo crema del arranque). Al
## pincel de PARED no le importa — un muro no tiene acabado.
var _acabado_pincel: StringName = &"baldosa"
## El conmutador de acabado, hermano de `_rejilla_paleta`: aparece SOLO con el pincel de suelo en la
## mano (ni con el de pared ni con el resto de herramientas).
var _boton_acabado: Button
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

	## Alto del QUAD que sube desde la línea (2026-08-05 · quick-spec §3d, tarea 1): 0 = línea plana
	## a ras de suelo (comportamiento de siempre); > 0 = el TRAMO ENTERO, de suelo a remate — el
	## selector "tipo Sims" que pidió el usuario. Mismo criterio de altura que `TramoPared._draw`
	## (sube restando de Y en pantalla): el selector ocupa la MISMA silueta que la pared de verdad.
	var linea_alto: float = 0.0

	func _draw() -> void:
		if poligono.size() >= 3:
			# Relleno translúcido + borde casi opaco: se distingue sobre cualquier color de sala
			# (mismo criterio de contraste que tenía el StyleBox del Panel anterior).
			draw_colored_polygon(poligono, Color(color.r, color.g, color.b, 0.30))
			var cerrado: PackedVector2Array = poligono.duplicate()
			cerrado.append(poligono[0])
			draw_polyline(cerrado, Color(color.r, color.g, color.b, 0.95), 3.0, true)
		if grosor <= 0.0:
			return
		if linea_alto <= 0.0:
			draw_line(
				linea_desde, linea_hasta, Color(color.r, color.g, color.b, 0.85), grosor, true
			)
			return
		# EL TRAMO ENTERO (tarea 1): un quad que sube igual que `TramoPared`, de esquina a esquina y
		# de suelo a remate — antes esto era solo la línea de arriba, que junto a una pared de 65 px
		# de alto se leía como "un trozo pequeño y difícil de posicionar" (informe del usuario).
		var subir := Vector2(0.0, -linea_alto)
		var quad := PackedVector2Array([
			linea_desde, linea_hasta, linea_hasta + subir, linea_desde + subir,
		])
		draw_colored_polygon(quad, Color(color.r, color.g, color.b, 0.40))
		var contorno: PackedVector2Array = quad.duplicate()
		contorno.append(quad[0])
		draw_polyline(contorno, Color(color.r, color.g, color.b, 0.95), 3.0, true)

	## Pinta una huella cerrada (una sala, un elemento). Borra cualquier línea anterior.
	func pintar_poligono(vertices: PackedVector2Array, nuevo_color: Color) -> void:
		poligono = vertices
		grosor = 0.0
		linea_alto = 0.0
		color = nuevo_color
		queue_redraw()

	## Pinta un tramo de arista (pincel de muro/puerta/ventana/pintura). `alto > 0` dibuja el TRAMO
	## ENTERO que sube (tarea 1); `alto == 0` (por defecto) la línea plana de siempre.
	func pintar_linea(
		desde: Vector2, hasta: Vector2, ancho: float, nuevo_color: Color, alto: float = 0.0
	) -> void:
		poligono = PackedVector2Array()
		linea_desde = desde
		linea_hasta = hasta
		grosor = ancho
		linea_alto = alto
		color = nuevo_color
		queue_redraw()


## ── EL TRIÁNGULO DE ORIENTACIÓN DEL FANTASMA (2026-08-06) ───────────────────────────────────────
## Un triángulo azul en el suelo, DELANTE del objeto que llevas en la mano, apuntando hacia su
## FRENTE (`ModoConstruccion._frente_de_orientacion`) — para que se vea hacia dónde va a mirar el
## mueble ANTES de soltar el clic, y que gire con él al pulsar R.
##
## Vive en la MISMA `CanvasLayer` que el resto del fantasma (`UIConstruccion`), hermano de
## `PreviewIso`/`Sprite2D` — NO es un hijo de la bolsa y-sort de `MundoProfundo` (ADR-0005 no aplica
## aquí: no hay sillas/mesas con las que intercalarse, es UI de colocación por encima de todo lo
## demás del modo, igual que el resto de `_preview_*`). Solo visible con un ELEMENTO en la mano
## (nunca con sala/muro/puerta/pincel, y nunca fuera del modo construcción).
class PreviewOrientacion extends Node2D:
	const COLOR_RELLENO := Color(0.25, 0.55, 1.0, 0.85)
	const COLOR_BORDE := Color(0.05, 0.25, 0.65, 0.95)
	var _puntos: PackedVector2Array = PackedVector2Array()

	## Los tres vértices YA proyectados a pantalla (ápice, base A, base B — el orden no importa para
	## rellenar, pero `[0]` es el que usan los diagnósticos como "la punta").
	func pintar(puntos: PackedVector2Array) -> void:
		_puntos = puntos
		queue_redraw()

	func _draw() -> void:
		if _puntos.size() < 3:
			return
		draw_colored_polygon(_puntos, COLOR_RELLENO)
		var cerrado: PackedVector2Array = _puntos.duplicate()
		cerrado.append(_puntos[0])
		draw_polyline(cerrado, COLOR_BORDE, 2.0, true)


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


## ── EL FANTASMA DE MAYÚS DEL PINCEL DE PINTURA (2026-08-05 · quick-spec §3d, tarea 2) ────────────
## Con el pincel de pintura en la mano y MAYÚS pulsada, ANTES de soltar el clic, el jugador tiene que
## ver TODO lo que se va a teñir — no solo el tramo/celda que señala el cursor: *"al hacer mayus para
## las paredes debería poder verse una vista previa para ver como queda antes de pintar"* (usuario).
##
## Guarda una lista YA CALCULADA de polígonos (tramos de pared o celdas de suelo, ya proyectados a
## pantalla) y los pinta todos en un único `_draw()`. La recalcula `_process` — con la misma guarda
## de celda/arista/MAYÚS que ya usa el resto del preview (`_mayus_anterior`) — así que nunca se
## reconstruye por frame: solo al cambiar el objetivo apuntado o al pulsar/soltar MAYÚS.
class PreviewMayusPintura extends Node2D:
	const ALFA_RELLENO: float = 0.35
	const ALFA_BORDE: float = 0.9
	var _poligonos: Array[PackedVector2Array] = []
	var _color: Color = Color.WHITE

	## Sustituye la lista de polígonos a pintar (tramos o celdas) por otra, ya proyectada a pantalla.
	func fijar(poligonos: Array[PackedVector2Array], nuevo_color: Color) -> void:
		_poligonos = poligonos
		_color = nuevo_color
		queue_redraw()

	## Apaga el fantasma: MAYÚS suelta, cambio de herramienta, o nada que abarcar (muro suelto que no
	## es fachada bajo el pincel de pared, por ejemplo).
	func limpiar() -> void:
		if _poligonos.is_empty():
			return
		_poligonos = []
		queue_redraw()

	func _draw() -> void:
		var relleno := Color(_color.r, _color.g, _color.b, ALFA_RELLENO)
		var borde := Color(_color.r, _color.g, _color.b, ALFA_BORDE)
		for poligono: PackedVector2Array in _poligonos:
			draw_colored_polygon(poligono, relleno)
			var cerrado: PackedVector2Array = poligono.duplicate()
			cerrado.append(poligono[0])
			draw_polyline(cerrado, borde, 2.0, true)


## ── EL VELO DE ZONAS EN MODO CONSTRUCCIÓN (2026-08-05 · quick-spec §3d, tarea 3) ──────────────────
## Con el modo activo, cada sala se cubre con una capa TRASLÚCIDA del color de su tipo (el mismo tono
## que usa el suelo como fondo — `Construccion.color_de_zona`) para que su extensión EXACTA se lea de
## un vistazo: *"las distintas zonas... deben marcarse de alguna manera para distinguirlas... que se
## pueda ver el tamaño de cada sala"* (usuario, 2026-08-05). En juego normal (modo apagado) no existe:
## vive y muere con el modo, igual que `RejillaConstruccion` (mismo criterio de capa — ver `z_index`
## y visibilidad en `_actualizar_visibilidad`).
##
## Rendimiento: los polígonos se recalculan SOLO cuando la FIRMA del layout cambia (mismo patrón DIFF
## que `ParedesSalas._firma_actual`) — `refrescar()` comprueba la firma primero y sale sin tocar nada
## si es idéntica a la última vez. `_process` la llama una vez por frame mientras el modo está activo
## (comprobar una firma corta —un puñado de salas— es barato), pero el trabajo real —reconstruir los
## polígonos— solo ocurre cuando algo cambió de verdad.
class VeloZonas extends Node2D:
	const ALFA_VELO: float = 0.22
	var _poligonos: Array[PackedVector2Array] = []
	var _colores: Array[Color] = []
	var _firma: String = ""

	func refrescar(construccion: Node) -> void:
		var firma: String = _firma_de(construccion)
		if firma == _firma:
			return
		_firma = firma
		_reconstruir(construccion)

	## Las salas construidas, en los tres tipos válidos (mismo patrón que `ParedesSalas._todas_las_salas`:
	## no existe un getter único en Construcción, así que se combinan los tres).
	func _salas_construidas(construccion: Node) -> Array:
		return (
			construccion.salas_de_tipo("espera") + construccion.salas_de_tipo("oficina")
			+ construccion.salas_de_tipo("descanso")
		)

	func _firma_de(construccion: Node) -> String:
		var partes: PackedStringArray = PackedStringArray()
		for sala_id: StringName in _salas_construidas(construccion):
			var rect: Rect2i = construccion.rect_de_sala(sala_id)
			partes.append("%s:%d,%d,%d,%d:%d" % [
				sala_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
				construccion.area_de_sala(sala_id),
			])
		return ",".join(partes)

	func _reconstruir(construccion: Node) -> void:
		_poligonos = []
		_colores = []
		for sala_id: StringName in _salas_construidas(construccion):
			var color: Color = construccion.color_de_zona(sala_id)
			for celda: Vector2i in construccion.celdas_de_sala(sala_id):
				_poligonos.append(PackedVector2Array([
					construccion.esquina_en_pantalla(celda.x, celda.y),
					construccion.esquina_en_pantalla(celda.x + 1, celda.y),
					construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1),
					construccion.esquina_en_pantalla(celda.x, celda.y + 1),
				]))
				_colores.append(color)
		queue_redraw()

	func _draw() -> void:
		for i: int in _poligonos.size():
			var c: Color = _colores[i]
			draw_colored_polygon(_poligonos[i], Color(c.r, c.g, c.b, ALFA_VELO))


var _dialogo_cascada: ConfirmationDialog
var _sala_a_demoler: StringName = &""
## La cuadrícula del modo (2026-08-05): se enciende y se apaga con el modo, nada más.
var _rejilla: RejillaConstruccion


## Inyección de dependencias (la llama Main ANTES de add_child). `paredes_salas` es OPCIONAL
## (2026-08-06 · quick-spec §3f): las herramientas de diagnóstico que instancian este nodo suelto
## siguen llamando con dos argumentos, y sin ella el picking de pared cae al de suelo de siempre.
func configurar(construccion: Node, tam_celda: int, paredes_salas: Node = null) -> void:
	_construccion = construccion
	_tam_celda = tam_celda
	_paredes_salas = paredes_salas


func _ready() -> void:
	_crear_ui()
	_crear_velo_zonas()
	_crear_rejilla()
	_actualizar_visibilidad()


## Monta el velo de zonas (ver `VeloZonas`): AÑADIDO ANTES que `_rejilla` en el árbol a propósito
## —mismo z_index (−1), y a igualdad de z manda el orden de la escena— para que la cuadrícula quede
## por ENCIMA del tinte y sus líneas se sigan leyendo con claridad sobre cualquier color de zona.
func _crear_velo_zonas() -> void:
	if _construccion == null:
		return   # sin modelo inyectado (tests/herramientas sueltas) no hay salas que tintar
	_velo_zonas = VeloZonas.new()
	_velo_zonas.name = "VeloZonas"
	_velo_zonas.z_index = -1
	_velo_zonas.visible = false
	add_child(_velo_zonas)
	_velo_zonas.refrescar(_construccion)


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
				# por ejemplo"*; ampliada 2026-08-06: *"que se pudiera posicionar en las 4
				# posiciones y que se viera si está dada la vuelta o de lado correctamente"*). Cicla
				# las 4 orientaciones REALES (`Construccion.ORIENTACIONES_CICLO`, 0→90→180→270→0) —
				# ya no un simple alterna H/V. Se fuerza el redibujado del fantasma poniendo la
				# guarda de celda en un imposible — si no, el preview solo se refresca al MOVER el
				# ratón y girar sin moverse no se vería.
				if _activo and not _es_sala and _herramienta != &"" and _herramienta != &"demoler":
					_orientacion = _siguiente_orientacion(_orientacion)
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
		_herramienta, _rect_entre(_celda_inicio, _celda_bajo_cursor_consciente_de_muros()),
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
	var par: Array = _celda_lado_de_muro_en(punto_mundo)
	if _construccion.hay_muro(par[0], par[1]):
		_construccion.demoler_muro(par[0], par[1])
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
	var par: Array = _celda_lado_de_muro_en(punto_mundo)
	var celda: Vector2i = par[0]
	var lado: StringName = par[1]
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
	_preview_mayus.limpiar()   # el clic ya ocurrió: no compite con el fantasma de "lo que se pintaría"
	_colocar_caja_arista(celda, lado, color)
	_preview_texto.text = texto
	_destello_restante = DURACION_DESTELLO


# ── EL PINCEL DE PINTURA (2026-08-04) ────────────────────────────────────────────────────────

## Pinta la PARED señalada por el punto DEL EVENTO. Con `con_mayus`, la sala entera — o, si el tramo
## es de FACHADA, el edificio entero (2026-08-05).
##
## La sala se deduce de la celda clicada (`sala_en`), no de la arista: una arista separa DOS celdas y
## preguntar por las dos daría dos salas candidatas. Con la celda donde de verdad has pinchado, el
## resultado es el que espera cualquiera — pintas desde dentro de la habitación que quieres pintar.
## Si esa celda no es de ninguna sala, hay dos casos: el tramo es FACHADA → MAYÚS pinta TODO el
## edificio; si no (un muro suelto en mitad de la nada), MAYÚS pinta SOLO ese tramo, igual que antes.
func _pintar_pared_en(punto_mundo: Vector2, con_mayus: bool) -> void:
	var par: Array = _celda_lado_de_muro_en(punto_mundo)
	var celda: Vector2i = par[0]
	var lado: StringName = par[1]
	var clave: String = _construccion.clave_de_muro(celda, lado)
	# BUG DE LA FACHADA SUR/ESTE (2026-08-08): el picking siempre resuelve la celda LITERAL "b" de la
	# arista (`_celda_lado_de_muro_en` -> `celda_y_lado_de_clave`), que para la fachada norte/oeste
	# cae DENTRO de la sala pero para la sur/este cae en la CALLE. Buscar la sala con esa celda a
	# pelo devolvía "" en la fachada sur/este aunque el clic sí cayera en la pared de una sala real, y
	# el MAYÚS se escapaba al caso "sin sala" -> pintaba el EDIFICIO ENTERO en vez de solo esa sala
	# (ver la cabecera de `Construccion.celda_interior_de_arista`). Con la celda interior, la sala se
	# encuentra igual en los cuatro lados.
	var sala_id: StringName = _construccion.sala_en(_construccion.celda_interior_de_arista(clave))
	if con_mayus and sala_id != &"":
		var pintados: int = _construccion.pintar_sala_muros(sala_id, _color_pincel)
		var texto: String = (
			"Sala pintada: %d tramos" % pintados if pintados > 0
			else "Esa sala no tiene paredes que pintar"
		)
		_lbl_estado.text = texto
		_destellar_arista(celda, lado, COLOR_VALIDO if pintados > 0 else COLOR_INVALIDO, texto)
		return
	if con_mayus and sala_id == &"" and _construccion.es_muro_fijo(clave):
		var pintados: int = _construccion.pintar_edificio_muros(_color_pincel)
		var texto: String = "Edificio pintado: %d tramos" % pintados
		_lbl_estado.text = texto
		_destellar_arista(celda, lado, COLOR_VALIDO, texto)
		return
	if _construccion.pintar_muro_en(celda, lado, _color_pincel):
		_lbl_estado.text = "Pared pintada"
		_destellar_arista(celda, lado, COLOR_VALIDO, "Pared pintada")
		return
	# El "no" se explica, igual que en el pincel de puertas: sin pared no hay nada que pintar.
	var motivo := "Ahí no hay pared que pintar"
	_lbl_estado.text = motivo
	_destellar_arista(celda, lado, COLOR_INVALIDO, motivo)


## Pinta el SUELO de la celda señalada. Con `con_mayus`, todo el suelo de su sala; si la celda no es
## de ninguna sala pero SÍ cae dentro del edificio (un pasillo), pinta TODAS las baldosas del
## edificio (2026-08-05); fuera del edificio no hay nada que extender.
## Pinta el suelo con el color Y EL ACABADO elegidos en el pincel (`_acabado_pincel` — tarea 4:
## &"baldosa"/&"liso", conmutador en el HUD).
func _pintar_suelo_en(punto_mundo: Vector2, con_mayus: bool) -> void:
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	var sala_id: StringName = _construccion.sala_en(celda)
	if con_mayus and sala_id != &"":
		var pintadas: int = _construccion.pintar_sala_suelo(sala_id, _color_pincel, _acabado_pincel)
		_lbl_estado.text = "Suelo de la sala pintado: %d celdas" % pintadas
		_destellar_celda(celda, COLOR_VALIDO, _lbl_estado.text)
		return
	if con_mayus and sala_id == &"" and _celda_en_edificio(celda):
		var pintadas: int = _construccion.pintar_edificio_suelos(_color_pincel, _acabado_pincel)
		_lbl_estado.text = "Edificio pintado: %d celdas" % pintadas
		_destellar_celda(celda, COLOR_VALIDO, _lbl_estado.text)
		return
	if _construccion.pintar_suelo(celda, _color_pincel, _acabado_pincel):
		_lbl_estado.text = "Suelo pintado"
		_destellar_celda(celda, COLOR_VALIDO, "Suelo pintado")
		return
	_lbl_estado.text = "Fuera del edificio"
	_destellar_celda(celda, COLOR_INVALIDO, "Fuera del edificio")


## Igual que `_destellar_arista` pero sobre la CELDA entera (el pincel de suelo pinta celdas).
func _destellar_celda(celda: Vector2i, color: Color, texto: String) -> void:
	_preview_caja.visible = true
	_preview_texto.visible = true
	_preview_mayus.limpiar()   # el clic ya ocurrió: no compite con el fantasma de "lo que se pintaría"
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


## Alterna el ACABADO del pincel de suelo entre baldosa y liso (2026-08-05 · quick-spec §3d, tarea
## 4). Mismo patrón que `_elegir_color`: fuerza el redibujado del fantasma sin esperar a que el
## ratón cambie de celda.
func _alternar_acabado() -> void:
	_acabado_pincel = (
		_construccion.ACABADO_LISO if _acabado_pincel == _construccion.ACABADO_BALDOSA
		else _construccion.ACABADO_BALDOSA
	)
	_refrescar_boton_acabado()
	_celda_anterior = Vector2i(-999, -999)


## El texto del conmutador de acabado, con el estado actual y la acción del clic.
func _refrescar_boton_acabado() -> void:
	if _boton_acabado == null:
		return
	_boton_acabado.text = (
		"🧱 Acabado: Baldosa (clic → Liso)" if _acabado_pincel == &"baldosa"
		else "◻ Acabado: Liso (clic → Baldosa)"
	)


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
	activado_cambiado.emit(_activo)


## **Entra en modo construcción con una herramienta YA en la mano** (menú contextual de la sala,
## 2026-07-28): el jugador pide "ampliar esta sala" o "añadir una ventanilla" y aparece directamente
## con el pincel correcto, sin tener que buscarlo en la barra. Ampliar una sala **no es una acción
## aparte**: es dibujar con la herramienta de ESE tipo de sala pegado a la que ya existe (Construcción
## fusiona y cobra solo las celdas nuevas — enmienda const-007).
func activar_con_herramienta(id: StringName, es_sala: bool) -> void:
	_activo = true
	_arrastrando = false
	_actualizar_visibilidad()
	activado_cambiado.emit(_activo)
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
	# El conmutador de ACABADO (tarea 4) es aún más específico que la paleta: solo el pincel de
	# SUELO tiene acabado — un muro no lo tiene.
	if _boton_acabado != null:
		_boton_acabado.visible = _activo and id == HERRAMIENTA_PINTAR_SUELO
	# Si la herramienta que se acaba de poner en la mano vive en OTRA pestaña (p. ej.
	# `activar_con_herramienta` desde el menú contextual de una sala, o `pedir_puerta_de_sala`), la
	# barra SALTA a esa categoría — si no, la tarjeta se resalta en una fila que no se está viendo,
	# y el jugador no entiende por qué "no pasa nada" al mirar la barra.
	if _categoria_de_herramienta.has(id) and _categoria_de_herramienta[id] != _categoria_activa:
		_mostrar_categoria(_categoria_de_herramienta[id])
	# EL SELECCIONADO SE MARCA CON EL ESTADO "PRESSED" DEL KIT (2026-08-07), no con un tinte de
	# `modulate`: `TarjetaObjeto`/`BotonDemoler` traen su propio arte de "seleccionada" (anillo azul
	# marino + badge de check, `tarjeta_seleccionada.png`) — un tinte por encima lo desharía. Este
	# bucle es la ÚNICA fuente de verdad de qué botón está `button_pressed`: si Godot autoalternó
	# alguno al hacer clic (comportamiento nativo de `toggle_mode`), aquí se sobrescribe siempre.
	for boton_id: StringName in _botones_herramienta:
		(_botones_herramienta[boton_id] as Button).button_pressed = boton_id == id


# ── Preview fantasma (dibujo en _process con guarda de celda — ADR-0001) ─────────────────────
func _process(delta: float) -> void:
	# FIX "cursor desviado" con cámara zoom/pan (ver el comentario largo en `_crear_ui`): la
	# `CanvasLayer` del fantasma sigue la transformada mundo→pantalla de la cámara ACTUAL cada
	# frame -- una asignación de `Transform2D` (struct, sin alloc), no un recorrido de nada; barato
	# incluso a 60 fps con el modo construcción activo.
	if _capa_preview != null:
		_capa_preview.transform = get_canvas_transform()
	# EL VELO DE ZONAS (tarea 3): se refresca mientras el modo está activo, tenga o no herramienta en
	# la mano — es una lectura del layout, no del pincel. `refrescar()` comprueba su propia firma
	# antes de hacer ningún trabajo real (ver `VeloZonas`): con el layout quieto, esto es un puñado
	# de comparaciones de texto por frame, no una reconstrucción.
	if _activo and _velo_zonas != null:
		_velo_zonas.refrescar(_construccion)
	if not _activo or _herramienta == &"":
		_preview_caja.visible = false
		_preview_sprite.visible = false
		_preview_triangulo.visible = false
		_preview_texto.visible = false
		_preview_mayus.limpiar()
		_celda_anterior = Vector2i(-999, -999)
		_lado_anterior = &"-"
		_mayus_anterior = false
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
	var celda: Vector2i = _celda_bajo_cursor_consciente_de_muros()
	# El LADO solo importa para el pincel de muro (los demás previews cubren la celda entera); se
	# calcula aquí una única vez y se reutiliza tanto en la guarda como en el propio preview. Live
	# poll (`get_global_mouse_position`) vale para un FANTASMA (no muta el modelo) — el gotcha de
	# "usa el punto del evento" es para las ACCIONES (pintar/demoler de verdad), no para dibujar.
	var lado: StringName = &"-"
	if _herramienta == &"muro":
		# El pincel de MURO traza tabiques NUEVOS: ahí no hay quad que pinchar todavía, así que se
		# queda con el picking de suelo de siempre.
		lado = _lado_mas_cercano(get_global_mouse_position(), celda)
	elif (
		_herramienta == &"demoler" or _herramienta == &"puerta" or _herramienta == &"ventana"
		or _herramienta == HERRAMIENTA_PINTAR_PARED
	):
		# Estos cuatro apuntan a un muro YA CONSTRUIDO: el picking por quad (2026-08-06) acierta la
		# CARA VISIBLE de verdad, no la celda de suelo que quedaría detrás de una pared alta — mismo
		# criterio que usa la acción real (`_celda_lado_de_muro_en`), así el fantasma no miente.
		var par: Array = _celda_lado_de_muro_en(get_global_mouse_position())
		celda = par[0]
		lado = par[1]
	# MAYÚS entra en la guarda (2026-08-05, tarea 2): sin esto, pulsar/soltar MAYÚS sobre la MISMA
	# celda no dispararía ningún redibujado — la guarda solo miraba celda/herramienta/arrastre/lado.
	var mayus: bool = Input.is_key_pressed(KEY_SHIFT)
	if (
		celda == _celda_anterior and _herramienta == _herramienta_anterior
		and _arrastrando == _arrastre_anterior and lado == _lado_anterior
		and mayus == _mayus_anterior
	):
		return
	_celda_anterior = celda
	_herramienta_anterior = _herramienta
	_arrastre_anterior = _arrastrando
	_lado_anterior = lado
	_mayus_anterior = mayus
	_preview_caja.visible = true
	_preview_texto.visible = true
	# Por defecto, apagado: solo `_refrescar_preview_elemento` lo enciende cuando la herramienta en
	# mano tiene sprite real (quick-spec §4) — así cualquier otra herramienta (muro, puerta, pincel,
	# sala) hereda el apagado sin tener que tocar sus propias funciones una por una.
	_preview_sprite.visible = false
	# Mismo criterio para el triángulo de orientación: solo `_refrescar_preview_elemento` lo enciende.
	_preview_triangulo.visible = false
	if _herramienta == &"demoler":
		_refrescar_preview_demoler(celda, lado)
		_preview_mayus.limpiar()
	elif _herramienta == &"muro":
		_refrescar_preview_muro(celda, lado)
		_preview_mayus.limpiar()
	elif _herramienta == &"puerta" or _herramienta == &"ventana":
		_refrescar_preview_puerta_ventana(celda, lado)
		_preview_mayus.limpiar()
	elif _herramienta == HERRAMIENTA_PINTAR_PARED:
		_refrescar_preview_pintar_pared(celda, lado, mayus)
	elif _herramienta == HERRAMIENTA_PINTAR_SUELO:
		_refrescar_preview_pintar_suelo(celda, mayus)
	elif _es_sala and _arrastrando:
		_refrescar_preview_sala(_rect_entre(_celda_inicio, celda))
		_preview_mayus.limpiar()
	else:
		_refrescar_preview_elemento(celda)
		_preview_mayus.limpiar()


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
## rojo cuando no. Avisa también de qué va a hacer MAYÚS: la sala entera, o —sobre la fachada— el
## edificio entero (2026-08-05).
##
## PREVIEW DEL MAYÚS (2026-08-05 · quick-spec §3d, tarea 2): con MAYÚS pulsada, además del tramo
## señalado, se enciende `_preview_mayus` con CADA tramo que se va a teñir — la sala entera, o el
## edificio si el tramo es de fachada — para que el jugador vea el alcance del gesto ANTES de
## soltar el clic: *"al hacer mayus para las paredes debería poder verse una vista previa"*.
func _refrescar_preview_pintar_pared(celda: Vector2i, lado: StringName, mayus: bool) -> void:
	var clave: String = _construccion.clave_de_muro(celda, lado)
	var hay_pared: bool = _construccion.tipo_de_muro(celda, lado) != &""
	var es_fachada: bool = _construccion.es_muro_fijo(clave)
	# Misma celda INTERIOR que usa `_pintar_pared_en` (ver su comentario del 2026-08-08): sin esto el
	# texto decía "MAYÚS pinta TODO el edificio" en la fachada sur/este aunque el gesto real (y el
	# fantasma de abajo, que YA usaba esta prioridad sala-primero) fuera a pintar solo la sala.
	var sala_id: StringName = _construccion.sala_en(_construccion.celda_interior_de_arista(clave))
	_colocar_caja_arista(celda, lado, _color_pincel if hay_pared else COLOR_INVALIDO)
	var motivo: String = "Clic pinta el tramo · MAYÚS pinta la sala"
	if not hay_pared:
		motivo = "Ahí no hay pared que pintar"
	elif sala_id != &"":
		motivo = "Clic pinta el tramo · MAYÚS pinta la sala"
	elif es_fachada:
		motivo = "Clic pinta el tramo · MAYÚS pinta TODO el edificio"
	else:
		motivo = "Clic pinta el tramo (muro suelto: MAYÚS no amplía)"
	_preview_texto.text = "🖌 Pared · " + motivo
	if not (mayus and hay_pared):
		_preview_mayus.limpiar()
		return
	if sala_id != &"":
		_mostrar_fantasma_muros(_construccion.claves_muros_de_sala(sala_id))
	elif es_fachada:
		_mostrar_fantasma_muros(_construccion.muros())
	else:
		_preview_mayus.limpiar()   # muro suelto que no es fachada: MAYÚS no amplía nada (ver el motivo)


## Rellena `_preview_mayus` con el QUAD de cada tramo de la lista de claves, todos a la altura
## `ParedesSalas.ALTO_PARED` — la misma que usa el selector de la tarea 1: el fantasma de MAYÚS es
## "muchos selectores a la vez", no una figura de dibujo distinta.
func _mostrar_fantasma_muros(claves: Array[String]) -> void:
	var quads: Array[PackedVector2Array] = []
	for clave: String in claves:
		var quad: PackedVector2Array = _quad_de_clave_muro(clave, ParedesSalas.ALTO_PARED)
		if not quad.is_empty():
			quads.append(quad)
	_preview_mayus.fijar(quads, _color_pincel)


## El QUAD de pantalla de un tramo de pared dado por su CLAVE de arista (convenio
## `Construccion.clave_de_muro`: "v:col:row" / "h:col:row"), a la altura `alto` — mismo criterio que
## `TramoPared._draw` (sube restando de Y). Duplicado A PROPÓSITO de
## `ParedesSalas._geometria_de_muro_libre` (privado): esta función es puramente informativa (un
## fantasma, no dibuja pared de verdad), mismo patrón que ya usa el resto de este fichero para
## espejar cálculos privados de otros sistemas.
func _quad_de_clave_muro(clave: String, alto: float) -> PackedVector2Array:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return PackedVector2Array()
	var x: int = int(partes[1])
	var y: int = int(partes[2])
	var desde: Vector2
	var hasta: Vector2
	if partes[0] == "v":
		desde = _construccion.esquina_en_pantalla(x, y)
		hasta = _construccion.esquina_en_pantalla(x, y + 1)
	elif partes[0] == "h":
		desde = _construccion.esquina_en_pantalla(x, y)
		hasta = _construccion.esquina_en_pantalla(x + 1, y)
	else:
		return PackedVector2Array()
	var subir := Vector2(0.0, -alto)
	return PackedVector2Array([desde, hasta, hasta + subir, desde + subir])


## Fantasma del pincel de SUELO: la celda entera con el color elegido. Con MAYÚS pulsada enciende
## `_preview_mayus` con TODAS las celdas reales de la sala (`celdas_de_sala` — respeta formas no
## rectangulares, fase C) si la celda pertenece a una; si no pertenece a ninguna pero sigue dentro
## del edificio (un pasillo), con TODAS las celdas del edificio (2026-08-05) — es lo que va a pintar
## ese clic, y el jugador ve el alcance del gesto antes de hacerlo.
func _refrescar_preview_pintar_suelo(celda: Vector2i, mayus: bool) -> void:
	var sala_id: StringName = _construccion.sala_en(celda)
	if mayus and sala_id != &"":
		_colocar_caja(celda, Vector2i.ONE, _color_pincel)   # el tramo señalado, referencia rápida
		_mostrar_fantasma_suelo(_construccion.celdas_de_sala(sala_id))
		_preview_texto.text = "🖌 Suelo (%s) · toda la sala (%d celdas)" % [
			_nombre_acabado(_acabado_pincel), _construccion.area_de_sala(sala_id),
		]
		return
	var dentro: bool = _celda_en_edificio(celda)
	if mayus and sala_id == &"" and dentro:
		var celdas_edificio: Array[Vector2i] = []
		for x: int in _construccion.edificio_columnas:
			for y: int in _construccion.edificio_filas:
				celdas_edificio.append(Vector2i(x, y))
		_colocar_caja(celda, Vector2i.ONE, _color_pincel)
		_mostrar_fantasma_suelo(celdas_edificio)
		_preview_texto.text = "🖌 Suelo (%s) · TODO el edificio (%d celdas)" % [
			_nombre_acabado(_acabado_pincel),
			_construccion.edificio_columnas * _construccion.edificio_filas,
		]
		return
	_preview_mayus.limpiar()
	_colocar_caja(celda, Vector2i.ONE, _color_pincel if dentro else COLOR_INVALIDO)
	if not dentro:
		_preview_texto.text = "🖌 Suelo · fuera del edificio"
		return
	_preview_texto.text = (
		"🖌 Suelo (%s) · clic pinta la celda · MAYÚS pinta la sala" % _nombre_acabado(_acabado_pincel)
		if sala_id != &"" else
		"🖌 Suelo (%s) · clic pinta la celda · MAYÚS pinta TODO el edificio" % _nombre_acabado(_acabado_pincel)
	)


## Rellena `_preview_mayus` con el QUAD de cada celda de suelo de la lista (mismo criterio que
## `_colocar_caja`: el rombo que forman sus cuatro esquinas de rejilla proyectadas).
func _mostrar_fantasma_suelo(celdas: Array[Vector2i]) -> void:
	var quads: Array[PackedVector2Array] = []
	for celda: Vector2i in celdas:
		quads.append(PackedVector2Array([
			_construccion.esquina_en_pantalla(celda.x, celda.y),
			_construccion.esquina_en_pantalla(celda.x + 1, celda.y),
			_construccion.esquina_en_pantalla(celda.x + 1, celda.y + 1),
			_construccion.esquina_en_pantalla(celda.x, celda.y + 1),
		]))
	_preview_mayus.fijar(quads, _color_pincel)


## El nombre legible del acabado (tarea 4), para el texto de ayuda del HUD.
func _nombre_acabado(acabado: StringName) -> String:
	return "Baldosa" if acabado == _construccion.ACABADO_BALDOSA else "Liso"


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


## EL PAR (celda, lado) DE UNA PARED YA EXISTENTE bajo un punto (2026-08-06 · quick-spec §3f).
## Prueba PRIMERO el picking por QUAD (`ParedesSalas.tramo_bajo_punto`, point-in-polygon sobre el
## MISMO quad que se dibuja): así un clic sobre la CARA VISIBLE de una pared de 65 px acierta esa
## pared y no la celda de suelo de detrás, que es donde caía antes el picking por planta
## (`_lado_mas_cercano` sobre `celda_de_punto`) — bug reportado por el usuario, la pintura por cara
## solo tiene sentido si el clic acierta la cara que de verdad se ve. Si el quad no acierta nada
## (no hay pared ahí, o `_paredes_salas` no está inyectado — herramientas de diagnóstico) cae al
## picking de suelo de SIEMPRE, que sigue siendo válido para "aquí no hay pared todavía".
##
## Lo usan los pinceles que apuntan a un muro YA CONSTRUIDO (pintar pared, puerta/ventana, demoler);
## el pincel de MURO (que traza tabiques NUEVOS donde no hay nada que pinchar todavía) sigue usando
## el picking de suelo directamente, sin pasar por aquí.
func _celda_lado_de_muro_en(punto_mundo: Vector2) -> Array:
	if _paredes_salas != null and _paredes_salas.has_method("tramo_bajo_punto"):
		var tramo: Dictionary = _paredes_salas.tramo_bajo_punto(punto_mundo)
		if not tramo.is_empty():
			var par: Array = _construccion.celda_y_lado_de_clave(String(tramo["clave_modelo"]))
			if par[1] != &"":
				return par
	var celda: Vector2i = _construccion.celda_de_punto(punto_mundo)
	return [celda, _lado_mas_cercano(punto_mundo, celda)]


## EL PICKING EN VIVO, CONSCIENTE DE MUROS (bug reportado 2026-08-06 — "es difícil jugar con el
## cursor desviado"). `Construccion.celda_bajo_cursor()` es picking de SUELO puro: un punto sobre
## la CARA VISIBLE de un muro (que sube `ParedesSalas.ALTO_PARED` px en pantalla) cae en la celda
## de DETRÁS de esa pared — el mismo defecto que ya arregló `_celda_lado_de_muro_en` para pintar
## pared / puerta-ventana / demoler, pero SOLO ahí. Aquí se reutiliza exactamente esa misma
## función (mismo quad, mismo criterio "gana el tramo más cercano a cámara") para el resto de
## herramientas que leen el cursor EN VIVO — sala nueva/arrastre/AMPLIAR (`_process` y
## `_al_soltar`), puesto, asiento, comodidad y el pincel de muro nuevo — así el resaltado y la
## acción apuntan siempre a la celda que el jugador VE, no a la que hay detrás de un muro alto.
## Sin pared bajo el punto, cae al picking de suelo de siempre (mismo resultado que
## `celda_bajo_cursor()`: `_celda_lado_de_muro_en` ya usa `celda_de_punto`, matemáticamente
## equivalente — ver la cabecera de esa función en `construccion.gd`).
func _celda_bajo_cursor_consciente_de_muros() -> Vector2i:
	var par: Array = _celda_lado_de_muro_en(get_global_mouse_position())
	return par[0]


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


## Coloca el selector del preview cubriendo el TRAMO DE PARED ENTERO (2026-08-05 · quick-spec §3d,
## tarea 1): la arista de `celda` en el lado `lado`, de esquina a esquina y de suelo a remate — el
## mismo quad que dibujaría `TramoPared` ahí, solo que translúcido. Lo comparten el pincel de muro,
## el de puerta/ventana y el de pintura de pared (los tres apuntan al mismo concepto de "arista"):
## unificado en esta única función, como pide la tarea.
##
## Antes esto dibujaba una LÍNEA fina a ras de suelo (`GROSOR_PREVIEW_MURO` de grosor): al lado de
## una pared real —que sube `ParedesSalas.ALTO_PARED` px en pantalla— esa línea se leía como "un
## trozo pequeño, difícil de posicionar" (informe literal del usuario). La altura de referencia es
## SIEMPRE la trasera completa (`ALTO_PARED`, no la frontal recortada): el selector es una promesa de
## "aquí va a haber pared", no una réplica exacta del modo de vista auto/todas/bajitas en curso.
func _colocar_caja_arista(celda: Vector2i, lado: StringName, color: Color) -> void:
	# ISOMÉTRICO: la arista deja de ser un lado horizontal o vertical de un cuadrado y pasa a ser
	# uno de los cuatro lados en diagonal del rombo. Se resalta como el TRAMO completo, de vértice a
	# vértice, que es exactamente el tramo de muro que se va a construir/pintar/convertir.
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
	_preview_caja.pintar_linea(desde, hasta, GROSOR_PREVIEW_MURO, color, ParedesSalas.ALTO_PARED)
	_preview_texto.position = (
		(desde + hasta) / 2.0 + Vector2(-60.0, -ParedesSalas.ALTO_PARED - 14.0)
	)


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
	# La huella del fantasma gira con la pieza (R): el mismo EJE que va a reservar el modelo (0°/180°
	# comparten huella, 90°/270° la traspuesta — `Construccion._paso_de`).
	var huella: Vector2i = (
		Vector2i(1, superficie) if _eje_vertical_de(_orientacion)
		else Vector2i(superficie, 1)
	)
	# EL TRIÁNGULO DE ORIENTACIÓN (2026-08-06): siempre que hay un ELEMENTO en mano, independiente
	# de si tiene sprite real o cae a la caja gris — es un dato de COLOCACIÓN (hacia dónde va a mirar
	# el objeto), no del arte. Gira con R porque `_orientacion` ya fuerza el redibujado del preview
	# (ver el atajo KEY_R en `_unhandled_input`).
	_colocar_triangulo_orientacion(celda, huella, _frente_de_orientacion(_orientacion))
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
	&"equipo_informatico", &"papelera", &"radio", &"lampara_pie",
]

## Comodidades con VISTA REAL por orientación (2026-08-06, 4 estados): el PNG que toca es
## literalmente el grado de `_orientacion` — mismo criterio que `rotacion_directa` en
## `Construccion._sprites_comodidad()` (privado, duplicado a propósito). Hoy solo la fotocopiadora
## (`comodidad_impresora_documentos_{0,90,180,270}.png`, las 4 vistas de Summer); el resto del
## catálogo con sprite sigue en una sola pose fija (`COMODIDADES_CON_SPRITE`, sin cambios).
const COMODIDADES_ROTACION_DIRECTA: Array[StringName] = [
	&"impresora_documentos", &"impresora_dni", &"nevera", &"dispensador_agua",
	# Lote "tier básico" (2026-08-07) — ver `Construccion._sprites_comodidad()`, duplicado a
	# propósito.
	&"escritorio_trabajo", &"silla_oficina", &"silla_espera_madera", &"silla_espera_azul",
	&"silla_espera_comoda", &"vending",
]

## LOS ASIENTOS DE ESPERA POR TIER, COMO TARJETAS (2026-08-08 — playtest: "no puedo elegir... los
## distintos asientos"). Hasta hoy `silla_espera_azul`/`silla_espera_comoda` eran `Comodidad`s del
## catálogo, correctas y con sprite (`COMODIDADES_ROTACION_DIRECTA`, arriba), pero SOLO se podían
## comprar desde el menú contextual de una sala YA construida (`Main._anadir_comodidades_al_menu`)
## — nunca aparecían aquí, en la barra de construcción, que es donde el jugador esperaba encontrar
## "los distintos asientos" (el único asiento en la barra era el genérico `ASIENTO_BASICO`, un
## mueble DISTINTO — ni el mismo id ni el mismo arte). `silla_espera_madera` NO entra en esta lista
## a propósito: no la pidió el usuario y ya hay un asiento barato en la barra (`ASIENTO_BASICO`,
## 25 €) que cubre ese hueco de precio.
const ASIENTOS_ESPERA_EN_BARRA: Array[StringName] = [&"silla_espera_azul", &"silla_espera_comoda"]


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
		# Colapsado a EJE (`_eje_vertical_de`): el sofá solo tiene DOS vistas renderizadas (fallback
		# de 2 vistas de la tarea de las 4 orientaciones) — mismo criterio que
		# `Construccion._rotacion_asiento_sofa3` (privada, espejado aquí a propósito).
		var rot: int = (
			_construccion.ROT_ASIENTO_SOFA3_VERTICAL if _eje_vertical_de(orientacion)
			else _construccion.ROT_ASIENTO_SOFA3_HORIZONTAL
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
	# COMODIDADES CON 4 VISTAS REALES (2026-08-06): el PNG que toca es literalmente el grado de
	# `orientacion` — mismo criterio que `rotacion_directa` en `Construccion._sprites_comodidad()`
	# (privado, espejado aquí a propósito, igual que el resto de esta sección).
	if COMODIDADES_ROTACION_DIRECTA.has(herramienta):
		var ruta_rot: String = "%scomodidad_%s_%d.png" % [
			_construccion.RUTA_SPRITES_MOBILIARIO, String(herramienta), orientacion,
		]
		if ResourceLoader.exists(ruta_rot):
			return {
				"textura": _textura_cacheada(ruta_rot), "paso": _paso_de_orientacion(orientacion),
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
		# TIER VISUAL (2026-08-08 — catálogo incompleto: "no puedo elegir los puestos medio o pro"):
		# si el id del propio `TipoPuesto` (p. ej. "ventanilla_media"/"ventanilla_pro") tiene su
		# PROPIO PNG de mostrador, la tarjeta y el fantasma lo usan; si no (los tres puestos de
		# siempre — doc general, TIE, ODAC — que se llaman por su SERVICIO, no por tier), cae al
		# básico de SIEMPRE (`ID_SPRITE_MOSTRADOR_2`) — cero cambio para ellos. Mismo criterio, y a
		# propósito espejado, que `MesaAtencion.construir(es_legado, id_sprite_tier)`.
		var id_sprite: String = MesaAtencionScript.ID_SPRITE_MOSTRADOR_2
		var ruta_tier: String = "%s%s_%d.png" % [
			MesaAtencionScript.RUTA_SPRITES_MOBILIARIO, String(herramienta), MesaAtencionScript.ROT_MOSTRADOR,
		]
		if ResourceLoader.exists(ruta_tier):
			id_sprite = String(herramienta)
		var ruta3: String = "%s%s_%d.png" % [
			MesaAtencionScript.RUTA_SPRITES_MOBILIARIO, id_sprite, MesaAtencionScript.ROT_MOSTRADOR,
		]
		if ResourceLoader.exists(ruta3):
			return {"textura": _textura_cacheada(ruta3), "paso": Vector2i(1, 0), "celdas": celdas}
		return vacio
	return vacio


## La orientación SIGUIENTE del ciclo de la R (2026-08-06, 4 estados reales):
## `Construccion.ORIENTACIONES_CICLO` en orden — 0→90→180→270→0. Si `actual` no está en el ciclo
## (dato corrupto de una herramienta de diagnóstico, o un save a medio migrar) cae a HORIZONTAL, la
## misma ley defensiva que usa `Construccion._orientacion_migrada`.
func _siguiente_orientacion(actual: int) -> int:
	var ciclo: Array[int] = _construccion.ORIENTACIONES_CICLO
	var indice: int = ciclo.find(actual)
	if indice == -1:
		return _construccion.HORIZONTAL
	return ciclo[(indice + 1) % ciclo.size()]


## Espeja `Construccion._paso_de` (privada): hacia dónde crece el cuerpo de la pieza según su
## orientación. SOLO depende del EJE (`_eje_vertical_de`, no de si está "dada la vuelta"): 0°/180°
## crecen al este, 90°/270° al sur — mismo duplicado a propósito que el resto de esta sección.
func _paso_de_orientacion(orientacion: int) -> Vector2i:
	return Vector2i(0, 1) if _eje_vertical_de(orientacion) else Vector2i(1, 0)


## ¿Esta orientación crece por el eje vertical (paso sur)? Espeja `Construccion._es_eje_vertical`
## (privada) — mismo duplicado a propósito que el resto de esta sección.
func _eje_vertical_de(orientacion: int) -> bool:
	return orientacion == _construccion.VERTICAL or orientacion == _construccion.VERTICAL_GIRADO


## El FRENTE de la pieza en mano —hacia dónde MIRA, "el lado del ciudadano"— espejando
## `Construccion._perpendicular_de` (privada): mismo duplicado a propósito que el de arriba. Es el
## vector que usa el triángulo de orientación (`_colocar_triangulo_orientacion`).
##
## 4 ESTADOS REALES (2026-08-06): las 4 orientaciones del ciclo de R dan las 4 direcciones
## canónicas, una cada una — SUR(0)/OESTE(90)/NORTE(180)/ESTE(270), el mismo mapeo que
## `Construccion._perpendicular_de`. El triángulo (`PreviewOrientacion`/
## `_colocar_triangulo_orientacion`) ya aceptaba cualquiera de las 4 desde que se creó — esta
## función es la que ahora las alcanza todas de verdad, no solo dos.
func _frente_de_orientacion(orientacion: int) -> Vector2i:
	if orientacion == _construccion.VERTICAL:
		return Vector2i(-1, 0)          # 90°: oeste
	if orientacion == _construccion.HORIZONTAL_GIRADO:
		return Vector2i(0, -1)          # 180°: norte
	if orientacion == _construccion.VERTICAL_GIRADO:
		return Vector2i(1, 0)           # 270°: este
	return Vector2i(0, 1)               # 0° (HORIZONTAL): sur


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


## EL TRIÁNGULO DE ORIENTACIÓN (2026-08-06): un triángulo azul en el suelo, DELANTE de la huella del
## objeto en mano, apuntando hacia `frente` (una de las 4 direcciones canónicas del plano lógico
## cuadrado — `Vector2i(1,0)`/`(-1,0)`/`(0,1)`/`(0,-1)`; el llamante decide cuál con
## `_frente_de_orientacion`). Se calcula ENTERO en el plano CUADRADO (mismo criterio que la huella
## de `_colocar_caja`) y se proyecta al final, una sola vez por refresco.
const MARGEN_TRIANGULO_ORIENTACION: float = 6.0
const BASE_TRIANGULO_ORIENTACION: float = 14.0
const LARGO_TRIANGULO_ORIENTACION: float = 16.0

func _colocar_triangulo_orientacion(celda: Vector2i, huella: Vector2i, frente: Vector2i) -> void:
	var frente_f := Vector2(frente)
	# Perpendicular a `frente` en el plano cuadrado (gira 90° el mismo vector): el eje de la BASE
	# del triángulo, a lo largo del borde delantero de la huella.
	var lateral := Vector2(-frente_f.y, frente_f.x)
	var centro_huella: Vector2 = (Vector2(celda) + Vector2(huella) * 0.5) * float(_tam_celda)
	# El semiancho de la huella EN EL EJE de `frente` (el que hay que recorrer desde el centro para
	# llegar al borde delantero): si `frente` es este/oeste, ese eje es `huella.x`; si es norte/sur,
	# `huella.y` — es la misma cuenta que separa `_paso_de`/`_perpendicular_de` por ejes en Construcción.
	var semiancho_frente: float = (
		(float(huella.x) if frente.x != 0 else float(huella.y)) * 0.5 * float(_tam_celda)
	)
	var base_centro: Vector2 = (
		centro_huella + frente_f * (semiancho_frente + MARGEN_TRIANGULO_ORIENTACION)
	)
	var apice: Vector2 = base_centro + frente_f * LARGO_TRIANGULO_ORIENTACION
	var base_a: Vector2 = base_centro + lateral * (BASE_TRIANGULO_ORIENTACION * 0.5)
	var base_b: Vector2 = base_centro - lateral * (BASE_TRIANGULO_ORIENTACION * 0.5)
	_preview_triangulo.pintar(PackedVector2Array([
		_punto_en_pantalla(apice), _punto_en_pantalla(base_a), _punto_en_pantalla(base_b),
	]))
	_preview_triangulo.visible = true


## Un punto del plano CUADRADO llevado a PANTALLA, en el mismo sistema de coordenadas que ya usan
## `_construccion.centro_en_pantalla`/`esquina_en_pantalla` (mundo == pantalla, sin cámara — ver la
## cabecera de `_crear_ui`). `esquina_en_pantalla(0, 0)` es exactamente el `_origen` PRIVADO de
## `Construccion` (`_origen + Proyeccion.esquina_iso(0,0)` y `esquina_iso(0,0) == proyectar(ZERO) ==
## ZERO`) — se lee así, sin tocar ese fichero, mismo criterio de duplicado a propósito que el resto
## de este archivo.
func _punto_en_pantalla(punto_cuadrado: Vector2) -> Vector2:
	return _construccion.esquina_en_pantalla(0, 0) + Proyeccion.proyectar(punto_cuadrado)


func _rect_entre(a: Vector2i, b: Vector2i) -> Rect2i:
	var origen := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var fin := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(origen, fin - origen + Vector2i.ONE)


# ── UI del andamio (barra inferior por código; botones con focus_mode NONE — gotcha Espacio) ─
func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	capa.name = "UIConstruccion"
	capa.layer = 1   # explícito (el valor por defecto de Godot) — ver `_capa_preview` más abajo.
	add_child(capa)
	# Atenuador del mundo en modo construcción (deja pasar el ratón).
	_atenuador = ColorRect.new()
	_atenuador.color = Color(0.0, 0.0, 0.0, 0.18)
	_atenuador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atenuador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_atenuador)

	# 🐛 FIX (bug "cursor desviado", jugado con cámara pan/zoom, 2026-08-06): el fantasma vivía en
	# `capa` (arriba), una `CanvasLayer` normal — transform IDENTIDAD siempre, ajena a la cámara del
	# juego (`Main._camara`, con zoom y pan desde 2026-08-04). Sus posiciones se calculan en MUNDO
	# (`Construccion.esquina_en_pantalla`/`_punto_en_pantalla`, el mismo espacio que usa
	# `TramoPared` y el resto del tablero, que SÍ cuelga del canvas base afectado por la cámara). Con
	# la cámara en zoom=1/pos=0 mundo==pantalla y no se notaba (de ahí el comentario viejo, ahora
	# borrado, "sin cámara, mundo y pantalla coinciden"); en cuanto se hace zoom o pan, el fantasma
	# se queda pintado en coordenadas de MUNDO dentro de un lienzo que las trata como PANTALLA
	# directa — de ahí el desvío, CRECIENTE con la distancia al punto de anclaje de la cámara (es un
	# error de ESCALA, no solo de origen). La selección de celda (`_celda_lado_de_muro_en` vía
	# `get_global_mouse_position()`, que SÍ deshace la cámara) siempre acertó la celda correcta —
	# esto es puramente el DIBUJO del rombo/caja verde, no la lógica de picking (por eso mi fix de
	# antes, el de los muros, ayudó con las paredes pero no arregló "el cursor se ve desviado": son
	# dos bugs distintos, éste bastante más viejo).
	#
	# FIX: `_capa_preview`, una `CanvasLayer` APARTE (layer 2, por ENCIMA de `capa`/atenuador —
	# sigue tapando el atenuador igual que antes) cuya `.transform` se iguala cada frame a
	# `get_canvas_transform()` (ver `_process`, justo al principio) — la MISMA transformada mundo→
	# pantalla que ya usa el resto del tablero (paredes, mobiliario), así el fantasma la hereda sin
	# tocar ni una coordenada de las que ya se calculaban. El atenuador y la barra de herramientas
	# (`capa`) se quedan SIN esta transformada a propósito: son overlay de pantalla fija, no deben
	# moverse ni escalar con el zoom.
	_capa_preview = CanvasLayer.new()
	_capa_preview.name = "PreviewFantasma"
	_capa_preview.layer = 2
	add_child(_capa_preview)

	# El fantasma de MAYÚS del pincel de pintura (tarea 2), ANTES que `_preview_caja` en el árbol
	# para quedar POR DEBAJO de él (el resaltado del tramo/celda señalado se sigue leyendo encima
	# del relleno de "todo lo que se va a pintar").
	_preview_mayus = PreviewMayusPintura.new()
	_capa_preview.add_child(_preview_mayus)
	# Preview fantasma POR ENCIMA del atenuador (feedback del usuario: no se veía dónde iba a caer).
	# Borde grueso + relleno translúcido: se distingue sobre cualquier color de sala.
	_preview_caja = PreviewIso.new()
	_preview_caja.visible = false
	_capa_preview.add_child(_preview_caja)
	# El fantasma de SPRITE REAL (quick-spec §4), hermano de la caja de arriba — mismo criterio de
	# capa (por encima del atenuador, por debajo del texto que se añade a continuación).
	_preview_sprite = Sprite2D.new()
	_preview_sprite.visible = false
	_capa_preview.add_child(_preview_sprite)
	# El triángulo de ORIENTACIÓN, POR ENCIMA del sprite/caja (tarea de hoy): apunta hacia el FRENTE
	# del objeto en mano — ver `PreviewOrientacion` y `_colocar_triangulo_orientacion`.
	_preview_triangulo = PreviewOrientacion.new()
	_preview_triangulo.visible = false
	_capa_preview.add_child(_preview_triangulo)
	_preview_texto = Label.new()
	_preview_texto.visible = false
	_preview_texto.add_theme_font_size_override("font_size", 13)
	_preview_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_texto.add_theme_constant_override("outline_size", 4)
	_capa_preview.add_child(_preview_texto)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Gotcha de anclas (el bug del "menú invisible"): anclada abajo, la barra debe CRECER HACIA
	# ARRIBA; sin esto se dibuja POR DEBAJO del borde de la pantalla. Se apoya en el borde REAL de
	# la pantalla (2026-08-09, opción A): cuando esta barra está abierta la fila de acciones del
	# HUD se oculta (`_al_activar_construccion`), así que reservarle hueco solo dejaba una franja
	# de mundo colándose por debajo.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	# El TEMA del kit (2026-08-07): se aplica al PANEL, no a cada botón suelto — así hereda el
	# `default_font`/`default_font_size` (Kenney Future) TODO lo que cuelgue de aquí sin tocarlo
	# nodo a nodo. Las piezas con arte propio (pestañas/tarjetas/demoler) piden ADEMÁS su
	# `theme_type_variation` explícita (ver `_construir_pestana_categoria`/`_construir_tarjeta`).
	panel.theme = KitUIComisarioScript.tema()
	# Mismo relleno plano deliberado que la fila de acciones del HUD (opción A del veredicto
	# 2026-08-09, ver `KitUIComisario.COLOR_FONDO_BARRA_INFERIOR`): cosidas sin costura, y fuera
	# el gris por defecto del motor.
	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = KitUIComisarioScript.COLOR_FONDO_BARRA_INFERIOR
	panel.add_theme_stylebox_override("panel", estilo_fondo)
	capa.add_child(panel)
	_panel_raiz = panel
	_panel_raiz.visible = false   # colapsado = invisible; lo gobierna `_actualizar_visibilidad`
	var caja := VBoxContainer.new()
	panel.add_child(caja)
	var fila_superior := HBoxContainer.new()
	fila_superior.add_theme_constant_override("separation", 8)
	caja.add_child(fila_superior)
	_boton_modo = Button.new()
	# Sin el emoji 🔨 (2026-08-09): renderiza como emoji de COLOR del sistema e ignora el tema —
	# el mismo gotcha que el ⏸ del módulo de velocidad del HUD.
	_boton_modo.text = "Construir (B)"
	_boton_modo.focus_mode = Control.FOCUS_NONE
	_boton_modo.pressed.connect(_alternar_modo)
	fila_superior.add_child(_boton_modo)
	_lbl_estado = Label.new()
	_lbl_estado.add_theme_font_size_override("font_size", 11)
	_lbl_estado.modulate = Color(1, 1, 1, 0.7)
	fila_superior.add_child(_lbl_estado)

	# ── LA BARRA NUEVA: PESTAÑAS DE CATEGORÍA + TARJETAS (2026-08-07) ────────────────────────────
	_fila_herramientas = VBoxContainer.new()
	caja.add_child(_fila_herramientas)

	_fila_pestanas = HBoxContainer.new()
	_fila_pestanas.add_theme_constant_override("separation", 6)
	_fila_herramientas.add_child(_fila_pestanas)
	for categoria: Dictionary in CATEGORIAS:
		_fila_pestanas.add_child(
			_construir_pestana_categoria(categoria["id"], categoria["nombre"])
		)
	var hueco_elastico := Control.new()
	hueco_elastico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hueco_elastico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila_pestanas.add_child(hueco_elastico)
	# DEMOLER anclado al borde derecho, FUERA de las pestañas (Apéndice B, Fitts's Law): acción
	# destructiva de alta frecuencia, siempre en el mismo sitio pase lo que pase la categoría activa.
	_anadir_herramienta("Demoler", &"demoler", false, &"", &"papelera")
	_fila_pestanas.add_child(_botones_herramienta[&"demoler"])

	var fila_tarjetas_paginada := HBoxContainer.new()
	fila_tarjetas_paginada.add_theme_constant_override("separation", 4)
	_fila_herramientas.add_child(fila_tarjetas_paginada)
	_boton_pagina_izq = Button.new()
	_boton_pagina_izq.text = "◀"
	_boton_pagina_izq.focus_mode = Control.FOCUS_NONE
	_boton_pagina_izq.pressed.connect(
		func() -> void: _paginar_tarjetas(-PASO_PAGINACION_TARJETAS)
	)
	fila_tarjetas_paginada.add_child(_boton_pagina_izq)
	_scroll_tarjetas = ScrollContainer.new()
	_scroll_tarjetas.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_tarjetas.custom_minimum_size = Vector2(0.0, 124.0)
	_scroll_tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_tarjetas_paginada.add_child(_scroll_tarjetas)
	_fila_tarjetas = HBoxContainer.new()
	_fila_tarjetas.add_theme_constant_override("separation", 6)
	_scroll_tarjetas.add_child(_fila_tarjetas)
	_boton_pagina_der = Button.new()
	_boton_pagina_der.text = "▶"
	_boton_pagina_der.focus_mode = Control.FOCUS_NONE
	_boton_pagina_der.pressed.connect(
		func() -> void: _paginar_tarjetas(PASO_PAGINACION_TARJETAS)
	)
	fila_tarjetas_paginada.add_child(_boton_pagina_der)

	_lbl_categoria_vacia = Label.new()
	_lbl_categoria_vacia.text = "Todavía no hay nada aquí — vuelve pronto"
	_lbl_categoria_vacia.add_theme_font_size_override("font_size", 12)
	_lbl_categoria_vacia.modulate = Color(1, 1, 1, 0.6)
	_lbl_categoria_vacia.visible = false
	_fila_herramientas.add_child(_lbl_categoria_vacia)

	# Los tipos se LEEN del catálogo — la UI nunca hardcodea costes/nombres (regla del GDD).
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		_anadir_herramienta(tipo_sala.nombre, tipo_sala.id, true, &"salas", &"plano")
	for tipo_puesto: Resource in Datos.obtener_todos(&"TipoPuesto"):
		if tipo_puesto.servicio == "Seguridad":
			continue   # la entrada/seguridad es fija (CO11) — no construible en el MVP
		# MINIATURA DEL SPRITE REAL (2026-08-08, petición del usuario, estilo tycoon): reutiliza
		# `_sprite_de_herramienta` — la MISMA resolución que ya pinta el fantasma de colocación — en
		# vez de duplicar la lógica de qué PNG toca. Orientación 0 fija (la tarjeta enseña el mueble,
		# no la rotación que el jugador vaya a elegir con R); `celdas`=1 no afecta a qué textura sale,
		# solo al `paso` del ancla que aquí no se usa. `icono_id` "sillon" se conserva como FALLBACK
		# (ver `_anadir_herramienta`) para el caso sin sprite propio.
		_anadir_herramienta(
			"%s (%d €)" % [tipo_puesto.nombre, tipo_puesto.coste_construccion_eur], tipo_puesto.id,
			false, &"muebles", &"sillon", _sprite_de_herramienta(tipo_puesto.id, 0, 1).get("textura")
		)
	_anadir_herramienta(
		"Asiento (%.0f €)" % _construccion.coste_asiento_basico, _construccion.ASIENTO_BASICO,
		false, &"muebles", &"sillon",
		_sprite_de_herramienta(_construccion.ASIENTO_BASICO, 0, 1).get("textura")
	)
	# LOS ASIENTOS DE ESPERA POR TIER (2026-08-08, ver la cabecera de `ASIENTOS_ESPERA_EN_BARRA`):
	# el catálogo manda el nombre y el precio (misma regla que el bucle de `TipoPuesto` de arriba),
	# la miniatura sale del mismo `_sprite_de_herramienta` que ya pinta el fantasma de colocación —
	# el mismo camino que YA usa `Main._al_elegir_del_menu_sala` para colocar estas comodidades
	# (`activar_con_herramienta` con un id de `Comodidad`), así que construirlas desde aquí no es un
	# camino nuevo, es la MISMA acción con una segunda puerta de entrada.
	for id_asiento: StringName in ASIENTOS_ESPERA_EN_BARRA:
		var comodidad_asiento: Resource = Datos.obtener_silencioso(&"Comodidad", id_asiento)
		if comodidad_asiento == null:
			continue   # red de seguridad: un id de la lista sin `.tres` en el catálogo no rompe la UI
		_anadir_herramienta(
			"%s (%d €)" % [comodidad_asiento.nombre, comodidad_asiento.coste_construccion_eur],
			id_asiento, false, &"muebles", &"sillon",
			_sprite_de_herramienta(id_asiento, 0, 1).get("textura")
		)
	# Muro LIBRE (2026-07-30 — Fase A del modelo Prison Architect): se pinta por arista, no por
	# celda, así que no es "es_sala" (no dibuja un rectángulo) ni un elemento normal (no ocupa celda).
	_anadir_herramienta(
		"Muro (%.0f €)" % _construccion.coste_muro, &"muro", false, &"muros_suelos", &"muro"
	)
	# PUERTA y VENTANA (FASE D, 2026-07-30): no levantan tabique nuevo, CONVIERTEN uno ya construido
	# — por eso no llevan un coste propio en el rótulo (el gasto fue el muro; abrir el hueco es
	# gratis, ver `Construccion.fijar_tipo_de_muro`).
	_anadir_herramienta("Puerta", &"puerta", false, &"muros_suelos", &"muro")
	_anadir_herramienta("Ventana", &"ventana", false, &"muros_suelos", &"muro")
	# PINCEL DE PINTURA (2026-08-04): gratis, como abrir un hueco — pintar no es obra, es acabado.
	# Dos botones (pared / suelo) porque el gesto es distinto: arista contra celda (ver la cabecera).
	_anadir_herramienta(
		"Pintar pared", HERRAMIENTA_PINTAR_PARED, false, &"muros_suelos", &"rodillo"
	)
	_anadir_herramienta(
		"Pintar suelo", HERRAMIENTA_PINTAR_SUELO, false, &"muros_suelos", &"rodillo"
	)
	# FASE C (2026-07-30): marcar ZONAS dentro de lo que has cerrado con muros. Un boton por tipo de
	# sala del catalogo, con el prefijo "zona:" en el id para distinguirlo del pincel que DIBUJA la
	# sala como rectangulo (que sigue existiendo: son dos formas validas de construir).
	for tipo_sala: Resource in Datos.obtener_todos(&"TipoSala"):
		_anadir_herramienta(
			"Zona: %s" % tipo_sala.nombre, StringName("zona:" + String(tipo_sala.id)), false,
			&"zonas", &"pin"
		)
	_casilla_con_paredes = CheckBox.new()
	_casilla_con_paredes.text = "Con paredes"
	_casilla_con_paredes.focus_mode = Control.FOCUS_NONE
	_casilla_con_paredes.tooltip_text = "Si esta marcado, la sala que dibujes nacera cerrada con muros"
	_casilla_con_paredes.toggled.connect(func(activo: bool) -> void: _nueva_sala_con_paredes = activo)
	_fila_herramientas.add_child(_casilla_con_paredes)
	# "Herramientas" nace vacía a propósito (Sección 2 de `plan-maestro-ui.md`: el hueco ya existe
	# en el layout para cuando llegue algo que meter ahí) — no se registra ninguna tarjeta aquí.
	_mostrar_categoria(&"salas")

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

	# ── EL CONMUTADOR DE ACABADO DEL PINCEL DE SUELO (2026-08-05 · quick-spec §3d, tarea 4) ────────
	# Botón simple, junto a la paleta (mismo sitio que el submenú del pincel): alterna entre baldosa
	# y liso, y solo se ve con el pincel de SUELO en la mano (`_fijar_herramienta`).
	_boton_acabado = Button.new()
	_boton_acabado.focus_mode = Control.FOCUS_NONE
	_boton_acabado.visible = false
	_boton_acabado.pressed.connect(_alternar_acabado)
	caja.add_child(_boton_acabado)
	_refrescar_boton_acabado()

	_dialogo_cascada = ConfirmationDialog.new()
	_dialogo_cascada.title = "Demolición en cascada"
	_dialogo_cascada.confirmed.connect(func() -> void: _construccion.demoler_sala(_sala_a_demoler))
	capa.add_child(_dialogo_cascada)


## Registra una herramienta seleccionable. `categoria` la cuelga de esa pestaña (vacía = no entra en
## ninguna fila de tarjetas — hoy solo Demoler, que vive anclada fuera de las pestañas). `icono_id`
## es una clave de `KitUIComisario.ICONOS`; `&""` = sin icono (fila de texto solo, fallback honesto
## si algún día se añade una herramienta sin pictograma todavía). `textura_miniatura` (2026-08-08):
## un sprite REAL (`Texture2D`) que sustituye al pictograma de `icono_id` — usada por los MUEBLES
## (ver el bucle de `TipoPuesto`/`ASIENTO_BASICO` en `_crear_ui`, resuelta con `_sprite_de_herramienta`,
## la MISMA función que ya pinta el fantasma de colocación). `icono_id` se conserva como FALLBACK si
## `textura_miniatura` es `null` (una herramienta sin arte propio, p.ej. `ASIENTO_BASICO`) — nunca al
## revés: si hay sprite real, manda sobre el pictograma genérico.
func _anadir_herramienta(
	texto: String, id: StringName, es_sala: bool, categoria: StringName = &"",
	icono_id: StringName = &"", textura_miniatura: Texture2D = null
) -> void:
	var variante: StringName = (
		KitUIComisarioScript.VARIANTE_BOTON_DEMOLER if id == &"demoler"
		else KitUIComisarioScript.VARIANTE_TARJETA
	)
	var boton := _construir_boton_con_icono(texto, icono_id, variante, textura_miniatura)
	boton.pressed.connect(func() -> void: _fijar_herramienta(id, es_sala))
	_botones_herramienta[id] = boton
	if categoria != &"":
		if not _tarjetas_por_categoria.has(categoria):
			_tarjetas_por_categoria[categoria] = []
		(_tarjetas_por_categoria[categoria] as Array).append(boton)
		_categoria_de_herramienta[id] = categoria
		# La tarjeta se cuelga YA de la fila (oculta hasta que `_mostrar_categoria` active su
		# pestaña) — ver la nota de `_scroll_tarjetas`: sin nodos sueltos no hay huérfanos.
		boton.visible = false
		_fila_tarjetas.add_child(boton)


## Fracción de la altura del botón que ocupa la BANDA INFERIOR clara del arte (`tarjeta_normal.png`/
## `pestana_normal.png`, `assets/ui/kit/` — medida a ojo sobre el PNG fuente por el usuario 2026-08-08:
## "la banda ocupa el ~22% inferior"). Repartida como `size_flags_stretch_ratio` de un `VBoxContainer`
## (proporción, NO píxeles fijos): vale igual a 84×84 (tarjeta) que a 112×74 (pestaña) — las dos
## formas que usa este mismo botón — y sigue valiendo si el kit cambia de tamaño en disco otra vez.
const FRACCION_BANDA_INFERIOR: float = 0.22

## Zonas de alto FIJO en píxeles para el camino de TARJETA (84×120, no pestaña -- ver
## `_construir_boton_con_icono`): sustituyen a `FRACCION_BANDA_INFERIOR` en ese camino porque una
## proporción del alto total no garantiza píxeles suficientes para una fuente de tamaño fijo (bug
## "los nombres no se ven" -- `design/ux/spec-tarjetas-2026-08-08.md` §0-A, §1.2). El camino de
## PESTAÑA (112×74, `_construir_pestana_categoria`) sigue usando `FRACCION_BANDA_INFERIOR` sin
## cambios -- sus rótulos son cortos y no forman parte de este bug.
const ALTO_ZONA_ICONO_TARJETA: float = 68.0
const SEPARACION_ICONO_ROTULO_TARJETA: float = 4.0
const ALTO_BANDA_ROTULO_TARJETA: float = 32.0
const TAMANO_MINIMO_ICONO_TARJETA := Vector2(32.0, 32.0)

## Un botón "en blanco" (sin `text`/`icon` propios de `Button` — ver la nota de la cabecera del
## archivo sobre por qué NO se usa `Button.icon`/alineación vertical nativa: la referencia de motor
## de esta versión no confirma esa API en 4.6, así que el icono+rótulo se dibuja a mano encima con
## un `VBoxContainer` hijo, `mouse_filter = IGNORE` para que el clic siga siendo del `Button`).
##
## RÓTULOS EN LA BANDA INFERIOR (auditoría 2026-08-08): antes icono+rótulo compartían un único
## `VBoxContainer` centrado en TODO el contenido — con un nombre largo, el rótulo crecía hacia arriba
## y pisaba el icono/pestaña (los dos flecos cazados en la captura del usuario). Ahora el contenido se
## reparte en DOS zonas de altura proporcional (`FRACCION_BANDA_INFERIOR`): la zona CUADRADA superior
## para el icono/miniatura, la banda clara inferior para el rótulo — cada una la porción del arte que
## ya trae dibujada para eso. `textura_miniatura` (sprite real, p.ej. el mueble en mano) manda sobre
## `icono_id` (pictograma de `KitUIComisario`) cuando ambos llegan — ver la cabecera de
## `_anadir_herramienta`.
func _construir_boton_con_icono(
	texto: String, icono_id: StringName, variante: StringName, textura_miniatura: Texture2D = null,
	tamano: Vector2 = Vector2(84.0, 120.0)
) -> Button:
	var boton := Button.new()
	boton.text = ""
	boton.focus_mode = Control.FOCUS_NONE
	boton.toggle_mode = true   # el estado "pressed" del tema ES el arte de "seleccionada/activa"
	boton.theme_type_variation = variante
	boton.custom_minimum_size = tamano
	boton.tooltip_text = texto   # nombre completo siempre disponible, aunque el rótulo se recorte
	# `clip_contents` en el BOTÓN, no solo en `contenido` (diagnóstico 2026-08-08, sonda
	# `_diag_tarjeta_rects`): con un nombre largo (p.ej. "Oficina de Documentación", 4 líneas
	# envueltas a 68px de ancho), el `Label.get_combined_minimum_size()` de la etiqueta reporta la
	# altura de las 4 líneas (57px), NO el suelo de `ALTO_BANDA_ROTULO_TARJETA` (32px) -- ese suelo
	# es un MÍNIMO, no un TECHO. Ese mínimo mayor se propaga hacia arriba (`contenido` 129px,
	# `margen` 145px) y, como los anclajes de `margen` solo pueden CRECER para respetar el mínimo de
	# su hijo (nunca encoger por debajo), `margen` acaba más alto que el propio `boton` (120px) y el
	# rótulo se dibuja fuera de la tarjeta, sobre el fondo del juego. Sin `clip_contents` aquí no hay
	# nada que recorte ese desbordamiento -- es el límite REAL de la tarjeta, coincide con el arte.
	boton.clip_contents = true
	# Camino de PESTAÑA (112×74) vs camino de TARJETA (84×120): la pestaña sigue con la banda
	# proporcional de siempre (`FRACCION_BANDA_INFERIOR`), la tarjeta pasa a zonas de alto fijo
	# (`design/ux/spec-tarjetas-2026-08-08.md` §4) — sus rótulos largos son los del bug reportado.
	var es_pestana: bool = variante == KitUIComisarioScript.VARIANTE_PESTANA

	# Envuelve el contenido en un margen de 8px (mismo valor que `content_margin_*` de
	# `sb_tarj_n`/`sb_tarj_h`/`sb_tarj_s`/`sb_tarj_b` en `theme_comisario.tres`) en vez de anclarlo
	# directo al rect completo del botón — fix de causa raíz §0-B: sin este margen, un hijo expansivo
	# empuja contra el borde literal del 9-slice en vez de dejar aire.
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 8)
	margen.add_theme_constant_override("margin_right", 8)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	boton.add_child(margen)

	var contenido := VBoxContainer.new()
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.clip_contents = true   # cinturón de seguridad: nada se dibuja fuera de la tarjeta
	contenido.add_theme_constant_override(
		"separation", 2 if es_pestana else int(SEPARACION_ICONO_ROTULO_TARJETA)
	)
	margen.add_child(contenido)

	# ZONA CUADRADA superior: icono/miniatura, centrada y con aspecto preservado (nunca deformada).
	var textura: Texture2D = textura_miniatura
	if textura == null and icono_id != &"":
		textura = KitUIComisarioScript.icono(icono_id)
	if textura != null:
		var rect := TextureRect.new()
		rect.texture = textura
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if es_pestana:
			rect.custom_minimum_size = Vector2(24.0, 24.0)
			rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rect.size_flags_stretch_ratio = 1.0 - FRACCION_BANDA_INFERIOR
		else:
			# Zona de alto FIJO (68px, no proporcional): el suelo de 32×32 evita que un icono
			# pequeño se pierda en una zona más generosa; el alto real de la zona lo fija
			# `custom_minimum_size.y` + `SIZE_FILL` (no expansivo) para que sean siempre 68px.
			rect.custom_minimum_size = TAMANO_MINIMO_ICONO_TARJETA
			rect.custom_minimum_size.y = ALTO_ZONA_ICONO_TARJETA
			rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rect.size_flags_vertical = Control.SIZE_FILL
		contenido.add_child(rect)
	else:
		# Sin icono ni miniatura (hoy no ocurre — ver la cabecera de `_anadir_herramienta` — pero deja
		# el rótulo cayendo en la banda de todos modos, no centrado en todo el botón).
		var hueco := Control.new()
		hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if es_pestana:
			hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
			hueco.size_flags_stretch_ratio = 1.0 - FRACCION_BANDA_INFERIOR
		else:
			hueco.custom_minimum_size = TAMANO_MINIMO_ICONO_TARJETA
			hueco.custom_minimum_size.y = ALTO_ZONA_ICONO_TARJETA
			hueco.size_flags_vertical = Control.SIZE_FILL
		contenido.add_child(hueco)

	# LA BANDA INFERIOR clara del arte: el rótulo, SOLO ahí. `autowrap` (WORD_SMART en el camino de
	# tarjeta, OFF sin cambios en pestaña) + `clip_contents` (no `TextServer.OVERRUN_TRIM_ELLIPSIS`:
	# no está confirmado en `docs/engine-reference/godot/` para 4.6 — regla del proyecto de no
	# adivinar API post-cutoff sin verificar, así que el corte es plano, sin puntos suspensivos) en
	# vez de dejarlo desbordar sobre el icono o fuera de la tarjeta.
	var etiqueta := Label.new()
	etiqueta.name = "RotuloBoton"   # localizable con find_child: _mostrar_categoria le cambia el color
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 10)
	# COLOR EXPLÍCITO (2026-08-08, bug "las letras están en blanco y no se ven"): un Label HIJO no
	# hereda los font_color por estado del Button (esos solo pintan su texto nativo) — sin esto sale
	# con el blanco por defecto de Godot, invisible sobre pestaña/tarjeta claras. Navy del kit salvo
	# sobre el arte rojo de Demoler (ahí blanco, como su variante del theme). La pestaña ACTIVA
	# (arte azul marino) se pasa a blanco en _mostrar_categoria.
	etiqueta.add_theme_color_override(
		"font_color",
		Color.WHITE if variante == KitUIComisarioScript.VARIANTE_BOTON_DEMOLER
		else KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL
	)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.clip_contents = true
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if es_pestana:
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_OFF
		etiqueta.size_flags_vertical = Control.SIZE_EXPAND_FILL
		etiqueta.size_flags_stretch_ratio = FRACCION_BANDA_INFERIOR
	else:
		# Banda de alto FIJO (32px, no proporcional -- la causa raíz de "los nombres no se ven").
		# `TOP`: si el nombre no cabe en 2 líneas, el recorte se come SIEMPRE la parte de abajo,
		# nunca un semi-carácter arriba y otro abajo como pasaría centrado.
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.y = ALTO_BANDA_ROTULO_TARJETA
		etiqueta.size_flags_vertical = Control.SIZE_FILL
	contenido.add_child(etiqueta)
	return boton


## El botón de una PESTAÑA de categoría (no es una `_herramienta`: cambia qué tarjetas se ven).
func _construir_pestana_categoria(id: StringName, nombre: String) -> Button:
	var icono_id: StringName = KitUIComisarioScript.ICONO_POR_CATEGORIA.get(id, &"")
	var boton := _construir_boton_con_icono(
		nombre, icono_id, KitUIComisarioScript.VARIANTE_PESTANA, null, Vector2(112.0, 74.0)
	)
	boton.pressed.connect(func() -> void: _mostrar_categoria(id))
	_pestanas_categoria[id] = boton
	return boton


## Cambia qué fila de tarjetas se ve. NO reinstancia ni descuelga nada: todas las tarjetas son
## hijas fijas de `_fila_tarjetas` (ver `_anadir_herramienta`) y aquí solo se alterna su `visible`
## (los `BoxContainer` ignoran a los hijos ocultos, así que el layout queda igual que recolgando).
func _mostrar_categoria(categoria: StringName) -> void:
	_categoria_activa = categoria
	var tarjetas: Array = _tarjetas_por_categoria.get(categoria, [])
	for hijo: Node in _fila_tarjetas.get_children():
		hijo.visible = tarjetas.has(hijo)
	_lbl_categoria_vacia.visible = tarjetas.is_empty()
	_scroll_tarjetas.visible = not tarjetas.is_empty()
	_scroll_tarjetas.scroll_horizontal = 0
	# La casilla "Con paredes" es del MISMO sitio que el pincel de muro/puerta/ventana: solo tiene
	# sentido con la categoría "Muros y suelos" activa (2026-08-07 — antes vivía suelta en la barra
	# entera, sin relación visible con lo que decide).
	if _casilla_con_paredes != null:
		_casilla_con_paredes.visible = categoria == &"muros_suelos"
	for id: StringName in _pestanas_categoria:
		var activa: bool = id == categoria
		var pestana: Button = _pestanas_categoria[id] as Button
		pestana.button_pressed = activa
		# El rótulo hijo no hereda font_pressed_color del Button (ver _construir_boton_con_icono):
		# blanco sobre el arte azul marino de la pestaña activa, navy sobre las claras.
		var rotulo: Label = pestana.find_child("RotuloBoton", true, false) as Label
		if rotulo != null:
			rotulo.add_theme_color_override(
				"font_color",
				Color.WHITE if activa else KitUIComisarioScript.COLOR_TEXTO_PRINCIPAL
			)


func _paginar_tarjetas(delta: float) -> void:
	_scroll_tarjetas.scroll_horizontal = int(
		clampf(_scroll_tarjetas.scroll_horizontal + delta, 0.0, 100000.0)
	)


func _actualizar_visibilidad() -> void:
	# Colapsado = barra INVISIBLE del todo (opción A, 2026-08-09): la píldora "Construir (B)" de
	# la fila de acciones del HUD es quien abre; ya no hay franja gris residente en pantalla.
	if _panel_raiz != null:
		_panel_raiz.visible = _activo
	_fila_herramientas.visible = _activo
	_atenuador.visible = _activo
	# LA CUADRÍCULA VIVE Y MUERE CON EL MODO (2026-08-05 · quick-spec §3c). Este es el ÚNICO sitio
	# donde se enciende: `_alternar_modo` y `activar_con_herramienta` ya pasan por aquí.
	if _rejilla != null:
		_rejilla.visible = _activo
	# EL VELO DE ZONAS VIVE Y MUERE CON EL MODO (2026-08-05, tarea 3): mismo criterio que la
	# cuadrícula. En juego normal (modo apagado) no hay velo — orden del usuario.
	if _velo_zonas != null:
		_velo_zonas.visible = _activo
	if _rejilla_paleta != null and not _activo:
		_rejilla_paleta.visible = false   # fuera del modo construcción no hay pincel ni paleta
	if _boton_acabado != null and not _activo:
		_boton_acabado.visible = false   # ídem el conmutador de acabado del pincel de suelo
	_boton_modo.modulate = COLOR_BOTON_ACTIVO if _activo else Color.WHITE
	_lbl_estado.text = (
		"Elige herramienta · clic coloca · arrastra dibuja salas · clic dcho/Esc cancela"
		if _activo else "Modo construcción apagado"
	)
	if not _activo:
		_preview_caja.visible = false
		_preview_texto.visible = false
