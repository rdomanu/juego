class_name KitUIComisario
## KitUIComisario — el punto único de acceso al kit de arte de UI (piloto Summer, 2026-08-07).
##
## Nadie en `src/main` debe escribir una ruta `"res://assets/ui/..."` a mano ni un hex de color de
## acento suelto: todo pasa por aquí (mismo criterio que `PaletaPintura` para los colores de pintura
## y `RUTA_SPRITES_MOBILIARIO` en `mesa_atencion.gd` para los sprites de mueble). Así, cuando Summer
## entregue el resto del kit (marco de pantalla completa, más iconos…) solo hay que tocar ESTE
## fichero, nunca los `modo_*.gd` que lo consumen.
##
## Procedencia: `design/ux/prompt-summer-ui.md` (piloto aprobado 2026-08-07) — piezas troceadas con
## `tools/_trocear_ui_kit.py` a `assets/ui/kit/`. Ver la cabecera de ese script para el detalle del
## recorte/troquelado (fondo magenta o "damero falso" según la hoja de origen).
##
## `theme_type_variation` que trae el `Theme` (`assets/ui/theme_comisario.tres`) — CADA botón que
## use una de estas variaciones necesita `toggle_mode = true` para que Godot aplique el estilo
## "pressed" como estado de SELECCIONADO (no hay estado nativo de "seleccionado" en un Button):
const VARIANTE_PESTANA := &"PestanaConstruccion"
const VARIANTE_TARJETA := &"TarjetaObjeto"
const VARIANTE_BOTON_DEMOLER := &"BotonDemoler"
const VARIANTE_PILDORA_PRIMARIA := &"PildoraPrimaria"
const VARIANTE_PILDORA_SECUNDARIA := &"PildoraSecundaria"
const VARIANTE_VENTANA_MODAL := &"VentanaModal"
const VARIANTE_BARRA_SUPERIOR := &"BarraSuperior"
## Los 3 módulos ilustrados de la barra superior, ahora 9-slice REAL vía `StyleBoxTexture` del tema
## (reconstrucción total del HUD, 2026-08-08) -- sustituyen al `TextureRect` a tamaño nativo del
## piloto Fase 2. Ver la cabecera larga de `sb_mod_reloj` en `theme_comisario.tres` para las
## márgenes medidas y el límite de alto conocido (el icono ocupa casi el 100% del alto nativo).
const VARIANTE_MODULO_RELOJ := &"ModuloReloj"
const VARIANTE_MODULO_VELOCIDAD := &"ModuloVelocidad"
const VARIANTE_MODULO_SALDO := &"ModuloSaldo"
const VARIANTE_TOAST_INFO := &"ToastInfo"
const VARIANTE_TOAST_AVISO := &"ToastAviso"
const VARIANTE_TOAST_CRITICO := &"ToastCritico"
const VARIANTE_TOAST_QUEJA := &"ToastQueja"

const RUTA_TEMA := "res://assets/ui/theme_comisario.tres"
const RUTA_ICONOS := "res://assets/ui/kit/"

## Los 16 pictogramas del piloto (2 lotes de 8, `design/ux/prompt-summer-ui.md` Pieza 8). El id es
## la clave estable que usa el CÓDIGO; el nombre de archivo es un detalle de `tools/_trocear_ui_kit.py`.
const ICONOS: Dictionary[StringName, String] = {
	# Lote A — construcción y mundo
	&"plano": "icono_plano.png", &"sillon": "icono_sillon.png", &"muro": "icono_muro.png",
	&"pin": "icono_pin.png", &"llave_inglesa": "icono_llave_inglesa.png",
	&"rodillo": "icono_rodillo.png", &"papelera": "icono_papelera.png",
	&"candado": "icono_candado.png",
	# Lote B — gestión y HUD
	&"personal": "icono_personal.png", &"reloj": "icono_reloj.png",
	&"disquete": "icono_disquete.png", &"carpeta": "icono_carpeta.png",
	# ⚠️ pedido como "moneda" en el encargo a Summer; lo que salió es una insignia con
	# estrella, no una moneda -- se deja con el id que ya pactamos (nadie más lo usa
	# todavía) pero queda anotado por si hace falta pedir una moneda de verdad más tarde.
	&"moneda": "icono_moneda.png", &"velocimetro": "icono_velocimetro.png",
	&"campana": "icono_campana.png", &"queja": "icono_queja.png",
}

## Icono por CATEGORÍA de la barra de construcción (Sección 2 de `plan-maestro-ui.md`).
const ICONO_POR_CATEGORIA: Dictionary[StringName, StringName] = {
	&"salas": &"plano", &"muebles": &"sillon", &"muros_suelos": &"muro",
	&"zonas": &"pin", &"herramientas": &"llave_inglesa",
}

## Acento azul marino CNP, muestreado de la propia pieza (`ventana_cabecera.png`, cabecera) — para
## que cualquier color pintado a mano en código (textos, bordes de fallback) case con el kit en vez
## de inventarse un azul distinto cada vez.
const COLOR_ACENTO_NAVY := Color(0.094, 0.278, 0.451, 1.0)
## Fondo PLANO de las franjas inferiores (fila de acciones del HUD y barra de construcción — ambas
## lo comparten para quedar cosidas sin costura). Relleno plano DELIBERADO (ley Summer 2026-08-06:
## "cero diseño visual por código; rellenos planos tolerados") en el matiz navy del kit, oscurecido
## para que las píldoras navy contrasten encima; antes las dos franjas caían en el gris por defecto
## del motor (veredicto del usuario 2026-08-09, opción A). Si algún día Summer dibuja una pieza de
## barra inferior, se sustituye aquí sin tocar a los consumidores.
const COLOR_FONDO_BARRA_INFERIOR := Color(0.10, 0.13, 0.20, 1.0)
const COLOR_TEXTO_PRINCIPAL := Color(0.11, 0.2, 0.32, 1.0)
## Semántica de estado (transversal, `accessibility-requirements.md`): SIEMPRE con forma/icono al
## lado, nunca solo el color -- estas constantes son el respaldo de color, no la única señal.
const COLOR_INFO := Color(0.58, 0.73, 0.87, 1.0)
const COLOR_AVISO := Color(0.94, 0.68, 0.30, 1.0)
const COLOR_CRITICO := Color(0.98, 0.25, 0.28, 1.0)

## Los 4 módulos ilustrados de la barra superior (Fase 2 del HUD, 2026-08-08 -- decisión del usuario
## "información ARRIBA, herramientas ABAJO"). `barra_superior_fondo.png` es el fondo 9-slice de la
## variante `VARIANTE_BARRA_SUPERIOR` (arriba); estos 4 son piezas SUELTAS que `main.gd` coloca como
## `TextureRect` encima, en fila, cada una con sus propios Labels/botones por delante. Mismo criterio
## que `ICONOS`: el id es la clave que usa el código, el nombre de archivo es detalle de Summer. Ojo:
## los ids NO comparten espacio de nombres con `ICONOS` -- `&"reloj"` aquí es el módulo GRANDE de la
## barra (234×98), no el pictograma pequeño `icono_reloj.png`.
const MODULOS_BARRA_SUPERIOR: Dictionary[StringName, String] = {
	&"reloj": "barra_superior_modulo_reloj.png",
	&"velocidad": "barra_superior_modulo_velocidad.png",
	&"saldo": "barra_superior_modulo_saldo.png",
	&"objetivo": "barra_superior_modulo_objetivo.png",
}

static var _tema_cache: Theme = null
static var _iconos_cache: Dictionary[StringName, Texture2D] = {}
static var _modulos_barra_cache: Dictionary[StringName, Texture2D] = {}


## El `Theme` del kit, cacheado a nivel de clase (varias pantallas lo comparten: `ModoConstruccion`,
## `ModoDisenadorEntorno`… un solo `load()` para todo el proceso, no uno por pantalla).
static func tema() -> Theme:
	if _tema_cache == null:
		_tema_cache = load(RUTA_TEMA) as Theme
	return _tema_cache


## La textura de un icono por id (`ICONOS`), cacheada. `null` si el id no existe en el catálogo —
## quien llama decide qué hacer (la mayoría, simplemente no pone icono).
static func icono(id: StringName) -> Texture2D:
	if _iconos_cache.has(id):
		return _iconos_cache[id]
	var nombre_archivo: String = ICONOS.get(id, "")
	if nombre_archivo == "":
		push_warning("KitUIComisario.icono: id desconocido '%s'" % id)
		return null
	var textura: Texture2D = load(RUTA_ICONOS + nombre_archivo) as Texture2D
	_iconos_cache[id] = textura
	return textura


## La textura de un módulo de la barra superior (`MODULOS_BARRA_SUPERIOR`), cacheada -- mismo patrón
## y mismo contrato que `icono()` (null silencioso + warning con un id desconocido, nunca revienta).
static func modulo_barra_superior(id: StringName) -> Texture2D:
	if _modulos_barra_cache.has(id):
		return _modulos_barra_cache[id]
	var nombre_archivo: String = MODULOS_BARRA_SUPERIOR.get(id, "")
	if nombre_archivo == "":
		push_warning("KitUIComisario.modulo_barra_superior: id desconocido '%s'" % id)
		return null
	var textura: Texture2D = load(RUTA_ICONOS + nombre_archivo) as Texture2D
	_modulos_barra_cache[id] = textura
	return textura


# ══ KIT MODERNO — panel de construcción v2 (2026-08-15) ═══════════════════════════════════════════
## Segunda paleta visual, EN PARALELO a la del piloto de Summer de arriba (`VARIANTE_*`/`ICONOS`): el
## lenguaje "Two Point Campus / Sims 4" de las maquetas aprobadas
## (`design/ux/maquetas-menu-2026-08/menu_v2_moderno.png` y `menu_v3_completo.png`) — panel claro,
## tarjetas blancas con sombra suave, esquinas muy redondeadas, un único acento azul. Lo estrena el
## panel de construcción (F1, `ModoConstruccion._crear_ui`); ver `design/ux/menu-construccion-spec.md`.
##
## Prefijo `MOD_`/`moderno_` a propósito: NO sustituye al kit del piloto (los modales siguen en la
## paleta navy/pixel-art de arriba) -- conviven mientras el resto de pantallas no migre. El HUD
## superior SÍ migró aquí (F2, 2026-08-16, `design/ux/maquetas-menu-2026-08/menu_v3_completo.png`):
## `HudComisario._construir_panel_superior`/`_construir_panel_acciones` son ahora consumidores de
## este kit moderno, igual que `ModoConstruccion`.
##
## LA FUENTE MODERNA (decisión del usuario 2026-08-16: "menu_v3_completo.png es la buena" — y esa
## maqueta está compuesta en Segoe UI): `moderno_tema()` carga Segoe UI como `SystemFont` y quien
## monte una pantalla moderna lo aplica a su raíz (`panel.theme = KitUIComisario.moderno_tema()`)
## para que TODO herede la tipografía de golpe. `SystemFont` vale porque el proyecto es SOLO
## Windows (technical-preferences); si algún día se portea, se sustituye aquí por una fuente
## empaquetada (un solo sitio). El kit viejo (`tema()`, Kenney Future) sigue intacto para el HUD
## pixel mientras no migre (F2).
##
## Colores muestreados de la maqueta (`design/ux/maquetas-menu-2026-08/maqueta_menu_v2.py`).
const MOD_COLOR_PANEL := Color(0.933, 0.953, 0.976, 1.0)          # panel claro (238,243,249)
const MOD_COLOR_TARJETA := Color(1.0, 1.0, 1.0, 1.0)               # tarjetas blancas
const MOD_COLOR_TINTA := Color(0.141, 0.188, 0.259, 1.0)           # texto principal (36,48,66)
const MOD_COLOR_GRIS := Color(0.478, 0.533, 0.612, 1.0)            # texto secundario (122,136,156)
const MOD_COLOR_LINEA := Color(0.871, 0.898, 0.933, 1.0)           # línea/raíl (222,229,238)
const MOD_COLOR_ACENTO := Color(0.184, 0.424, 0.878, 1.0)          # acento azul policía (47,108,224)
const MOD_COLOR_ACENTO_SUAVE := Color(0.910, 0.941, 0.996, 1.0)    # azul suave (232,240,254)
const MOD_COLOR_VERDE := Color(0.133, 0.627, 0.369, 1.0)           # estado válido/positivo (34,160,94)
const MOD_COLOR_AMBAR := Color(0.941, 0.620, 0.173, 1.0)           # aviso (240,158,44)
const MOD_COLOR_ROJO := Color(0.886, 0.345, 0.322, 1.0)            # inválido/negativo (226,88,82)
## Verde suave para insignias circulares (marcador "€" del HUD superior, F2 2026-08-16) — mismo verde
## que `MOD_COLOR_VERDE` pero aclarado a fondo de insignia (226,244,234), calcado del mockup ejecutable
## `design/ux/maquetas-menu-2026-08/maqueta_hud_v3.py`.
const MOD_COLOR_VERDE_SUAVE := Color(0.886, 0.957, 0.918, 1.0)

## Radio de esquina de una tarjeta grande (ficha, tarjeta de catálogo). La maqueta pide "14-20"; 16
## es el punto medio.
const MOD_RADIO_TARJETA: float = 16.0
## Radio de esquina de piezas más pequeñas (botones de categoría, chips).
const MOD_RADIO_PEQUENO: float = 14.0


## Tarjeta blanca con sombra suave (StyleBoxFlat: `shadow_size` ~8, alfa ~0.10, `shadow_offset`
## (0,3) -- valores literales de la maqueta), el bloque base de la pieza nueva: rejilla de objetos,
## ficha del seleccionado, fondo del buscador. `seleccionada` añade el borde de acento de 3px (regla
## de la maqueta: "borde acento 3px + leve realce") -- es SOLO el refuerzo visual; quien la usa debe
## seguir marcando la selección con estado real (`Button.button_pressed`), nunca con este borde a
## solas, por accesibilidad (daltonismo -- el proyecto exige forma/estado además de color).
## La fuente del lenguaje moderno, cacheada. `negrita` = el peso seminegrita (600) con el que la
## maqueta compone nombres, precios y botones; el resto va en regular.
static var _fuente_moderna: SystemFont = null
static var _fuente_moderna_negrita: SystemFont = null

static func moderno_fuente(negrita: bool = false) -> Font:
	if negrita:
		if _fuente_moderna_negrita == null:
			_fuente_moderna_negrita = SystemFont.new()
			_fuente_moderna_negrita.font_names = PackedStringArray(["Segoe UI"])
			_fuente_moderna_negrita.font_weight = 600
		return _fuente_moderna_negrita
	if _fuente_moderna == null:
		_fuente_moderna = SystemFont.new()
		_fuente_moderna.font_names = PackedStringArray(["Segoe UI"])
	return _fuente_moderna


## El Theme de las pantallas modernas, cacheado: fuente Segoe UI por defecto para TODO control que
## cuelgue de la raíz que lo reciba. Los tamaños/pesos concretos siguen siendo overrides puntuales.
static var _tema_moderno: Theme = null

static func moderno_tema() -> Theme:
	if _tema_moderno == null:
		_tema_moderno = Theme.new()
		_tema_moderno.default_font = moderno_fuente()
		_tema_moderno.default_font_size = 13
	return _tema_moderno


static func moderno_tarjeta(
	seleccionada: bool = false, radio: float = MOD_RADIO_TARJETA, color_fondo: Color = MOD_COLOR_TARJETA
) -> PanelContainer:
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.set_corner_radius_all(int(radio))
	estilo.shadow_size = 8
	estilo.shadow_color = Color(0.02, 0.03, 0.06, 0.10)
	estilo.shadow_offset = Vector2(0.0, 3.0)
	if seleccionada:
		estilo.set_border_width_all(3)
		estilo.border_color = MOD_COLOR_ACENTO
	panel.add_theme_stylebox_override("panel", estilo)
	return panel


## Pastilla (radio = mitad de la altura): fondo del buscador, un chip de estado, un toggle
## segmentado. `alto` fija el radio real -- una pastilla de 38px de alto pide radio 19, no un número
## suelto copiado de la maqueta.
static func moderno_pastilla(color_fondo: Color = MOD_COLOR_TARJETA, alto: float = 38.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.set_corner_radius_all(int(alto / 2.0))
	panel.add_theme_stylebox_override("panel", estilo)
	panel.custom_minimum_size.y = alto
	return panel


## Chip de estado: un punto de color + texto, en una pastilla. El texto va SIEMPRE junto al punto
## (regla de accesibilidad transversal del proyecto, daltónicos): el color es refuerzo, nunca la
## única señal.
static func moderno_chip_estado(texto: String, color_punto: Color) -> PanelContainer:
	var pastilla := moderno_pastilla(MOD_COLOR_PANEL, 28.0)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 6)
	pastilla.add_child(fila)
	var punto := Panel.new()
	punto.custom_minimum_size = Vector2(8.0, 8.0)
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_punto := StyleBoxFlat.new()
	estilo_punto.bg_color = color_punto
	estilo_punto.set_corner_radius_all(4)
	punto.add_theme_stylebox_override("panel", estilo_punto)
	fila.add_child(punto)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", MOD_COLOR_TINTA)
	etiqueta.add_theme_font_size_override("font_size", 12)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(etiqueta)
	return pastilla


## Barra de progreso hecha con dos `Panel` anidados (StyleBoxFlat -- NUNCA el tema por defecto de
## `ProgressBar`, pedido explícito de la tarea): un raíl (`MOD_COLOR_LINEA`) de fondo y un relleno
## que ocupa `fraccion` (clamp 0-1) del ancho, en `color`. Devuelve el `Control` raíz; para
## actualizarla más tarde (dato reactivo -- la ficha cambia de objeto sin reconstruir nada) usa
## `moderno_actualizar_barra_progreso` sobre el MISMO nodo devuelto aquí.
static func moderno_barra_progreso(
	fraccion: float, color: Color, ancho: float = 140.0, alto: float = 8.0
) -> Control:
	var raiz := Control.new()
	raiz.custom_minimum_size = Vector2(ancho, alto)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := Panel.new()
	rail.name = "Rail"
	rail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_rail := StyleBoxFlat.new()
	estilo_rail.bg_color = MOD_COLOR_LINEA
	estilo_rail.set_corner_radius_all(int(alto / 2.0))
	rail.add_theme_stylebox_override("panel", estilo_rail)
	raiz.add_child(rail)
	var relleno := Panel.new()
	relleno.name = "Relleno"
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relleno.position = Vector2.ZERO
	relleno.size = Vector2(ancho * clampf(fraccion, 0.0, 1.0), alto)
	var estilo_relleno := StyleBoxFlat.new()
	estilo_relleno.bg_color = color
	estilo_relleno.set_corner_radius_all(int(alto / 2.0))
	relleno.add_theme_stylebox_override("panel", estilo_relleno)
	raiz.add_child(relleno)
	return raiz


## Actualiza en sitio una barra creada por `moderno_barra_progreso` -- busca su hijo `"Relleno"` por
## nombre, no guarda estado propio en quien llama. `color` en `Color(0,0,0,0)` (por defecto)
## conserva el color que ya tenía el relleno.
static func moderno_actualizar_barra_progreso(
	barra: Control, fraccion: float, color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var relleno: Panel = barra.get_node_or_null("Relleno") as Panel
	if relleno == null:
		return
	var ancho: float = barra.custom_minimum_size.x
	var alto: float = barra.custom_minimum_size.y
	relleno.size = Vector2(ancho * clampf(fraccion, 0.0, 1.0), alto)
	if color.a > 0.0:
		var estilo: StyleBoxFlat = relleno.get_theme_stylebox("panel") as StyleBoxFlat
		if estilo != null:
			estilo.bg_color = color


## Botón redondo de icono (Mover/Clonar/Demoler de la ficha, F1): pastilla circular con sombra y el
## pictograma centrado. `habilitado = false` lo deja atenuado y OBLIGA a un `tooltip` que explique
## por qué -- nunca un botón que no hace nada sin decir el motivo (mismo criterio que
## `ModoConstruccion._lbl_categoria_vacia`/los motivos de rechazo del pincel de puertas).
static func moderno_boton_icono(
	icono: Texture2D, tooltip: String, habilitado: bool = true, lado: float = 44.0
) -> Button:
	var boton := Button.new()
	boton.text = ""
	boton.custom_minimum_size = Vector2(lado, lado)
	boton.focus_mode = Control.FOCUS_NONE
	boton.disabled = not habilitado
	boton.tooltip_text = tooltip
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = MOD_COLOR_TARJETA if habilitado else MOD_COLOR_PANEL
	estilo.set_corner_radius_all(int(lado / 2.0))
	estilo.shadow_size = 6
	estilo.shadow_color = Color(0.02, 0.03, 0.06, 0.10)
	estilo.shadow_offset = Vector2(0.0, 2.0)
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	if icono != null:
		var rect := TextureRect.new()
		rect.texture = icono
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate = MOD_COLOR_TINTA if habilitado else MOD_COLOR_GRIS
		rect.custom_minimum_size = Vector2(20.0, 20.0)
		rect.set_anchors_preset(Control.PRESET_CENTER)
		rect.position = Vector2((lado - 20.0) / 2.0, (lado - 20.0) / 2.0)
		rect.size = Vector2(20.0, 20.0)
		boton.add_child(rect)
	return boton


## Pastilla partida en N opciones (toggle Función/Sala del panel de construcción): una fila de
## `Button` en `toggle_mode` dentro de una pastilla exterior -- la opción activa lleva fondo de
## acento y texto blanco, el resto texto tinta sobre transparente. `opciones` es
## `[{"id": StringName, "texto": String, "habilitado": bool, "tooltip": String}]` (las tres últimas
## claves opcionales); devuelve la pastilla exterior con cada botón colgado como hijo con nombre
## `"Opcion_" + id` -- el llamante conecta `pressed` y alterna `button_pressed` a mano (este kit no
## sabe qué debe pasar al elegir una opción, solo construye el control).
static func toggle_segmentado(opciones: Array[Dictionary], alto: float = 38.0) -> PanelContainer:
	var pastilla := moderno_pastilla(MOD_COLOR_PANEL, alto)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 2)
	pastilla.add_child(fila)
	var radio_interior: int = int((alto - 6.0) / 2.0)
	for opcion: Dictionary in opciones:
		var id: StringName = opcion.get("id", &"")
		var boton := Button.new()
		boton.name = "Opcion_%s" % id
		boton.text = String(opcion.get("texto", ""))
		boton.toggle_mode = true
		boton.focus_mode = Control.FOCUS_NONE
		boton.disabled = not bool(opcion.get("habilitado", true))
		if opcion.has("tooltip"):
			boton.tooltip_text = String(opcion["tooltip"])
		var estilo_normal := StyleBoxFlat.new()
		estilo_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		estilo_normal.set_corner_radius_all(radio_interior)
		# Aire horizontal dentro de cada opción: sin él, la pastilla activa queda pegada al texto
		# de la vecina (cazado en la primera captura del panel).
		estilo_normal.content_margin_left = 16.0
		estilo_normal.content_margin_right = 16.0
		estilo_normal.content_margin_top = 4.0
		estilo_normal.content_margin_bottom = 4.0
		var estilo_activo: StyleBoxFlat = estilo_normal.duplicate()
		estilo_activo.bg_color = MOD_COLOR_ACENTO
		boton.add_theme_stylebox_override("normal", estilo_normal)
		boton.add_theme_stylebox_override("hover", estilo_normal)
		boton.add_theme_stylebox_override("disabled", estilo_normal)
		boton.add_theme_stylebox_override("pressed", estilo_activo)
		boton.add_theme_color_override("font_color", MOD_COLOR_TINTA)
		boton.add_theme_color_override("font_pressed_color", Color.WHITE)
		boton.add_theme_color_override("font_disabled_color", MOD_COLOR_GRIS)
		boton.add_theme_font_size_override("font_size", 13)
		fila.add_child(boton)
	return pastilla


## Un `Control` con `_draw()` propio -- pictogramas VECTORIALES del kit moderno (F2, reskin del HUD
## superior, 2026-08-16). Evita las dos trampas ya cazadas en este proyecto: un emoji (⏸/▶ arrastran
## la fuente COLOR del sistema, ignoran `modulate`/`font_color` -- fix ya documentado en
## `HudComisario._construir_modulo_velocidad`) o un PNG nuevo que Summer aún no ha entregado (reloj,
## play/pausa). `color` es mutable en caliente (`color = ...; queue_redraw()`), mismo patrón "dato
## reactivo" que `moderno_actualizar_barra_progreso`.
class GlifoModerno extends Control:
	enum Tipo { RELOJ, PAUSA, PLAY1, PLAY2, PLAY3 }
	var tipo: int = Tipo.RELOJ
	var color: Color = Color(0.141, 0.188, 0.259, 1.0)

	func _draw() -> void:
		match tipo:
			Tipo.RELOJ:
				_dibujar_reloj()
			Tipo.PAUSA:
				_dibujar_pausa()
			Tipo.PLAY1:
				_dibujar_play(1)
			Tipo.PLAY2:
				_dibujar_play(2)
			Tipo.PLAY3:
				_dibujar_play(3)

	## Círculo + manecillas (hora corta arriba, minutero más largo hacia la derecha) -- calcado del
	## mockup ejecutable (`maqueta_hud_v3.py`, `d0.ellipse` + 2 `d0.line`), sin depender de ningún PNG.
	func _dibujar_reloj() -> void:
		var radio: float = minf(size.x, size.y) * 0.5 - 1.5
		var centro: Vector2 = size * 0.5
		draw_arc(centro, radio, 0.0, TAU, 28, color, 1.8, true)
		draw_line(centro, centro + Vector2(0.0, -radio * 0.55), color, 1.8, true)
		draw_line(centro, centro + Vector2(radio * 0.42, radio * 0.18), color, 1.8, true)

	## Dos barras verticales -- el glifo "II" de pausa.
	func _dibujar_pausa() -> void:
		var ancho_barra: float = size.x * 0.16
		var alto_barra: float = size.y * 0.62
		var y: float = (size.y - alto_barra) * 0.5
		draw_rect(Rect2(size.x * 0.5 - ancho_barra - 2.0, y, ancho_barra, alto_barra), color)
		draw_rect(Rect2(size.x * 0.5 + 2.0, y, ancho_barra, alto_barra), color)

	## `n` triángulos "▶" en fila -- 1/2/3 según la velocidad (1×/2×/3×).
	func _dibujar_play(n: int) -> void:
		var lado: float = size.y * 0.6
		var paso: float = lado * 0.8
		var total: float = paso * (n - 1) + lado * 0.55
		var x0: float = (size.x - total) * 0.5
		var y_centro: float = size.y * 0.5
		for i in n:
			var cx: float = x0 + i * paso
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, y_centro - lado * 0.5),
				Vector2(cx, y_centro + lado * 0.5),
				Vector2(cx + lado * 0.55, y_centro),
			]), color)


## Fábrica de `GlifoModerno` -- tamaño cuadrado `lado`, sin recibir clics (decorativo, el `Button` que
## lo tapa encima es quien procesa el input, mismo criterio que los iconos de `_crear_chip_plano`).
static func moderno_glifo(tipo: int, color: Color = MOD_COLOR_TINTA, lado: float = 22.0) -> Control:
	var glifo := GlifoModerno.new()
	glifo.tipo = tipo
	glifo.color = color
	glifo.custom_minimum_size = Vector2(lado, lado)
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glifo


## Insignia circular con un símbolo corto centrado (el marcador "€" del saldo del HUD, F2). Genérico
## por si otra pantalla necesita el mismo patrón (círculo de acento + carácter).
static func moderno_circulo_simbolo(
	simbolo: String, color_fondo: Color, color_texto: Color, lado: float = 32.0
) -> Control:
	var circulo := PanelContainer.new()
	circulo.custom_minimum_size = Vector2(lado, lado)
	circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.set_corner_radius_all(int(lado / 2.0))
	circulo.add_theme_stylebox_override("panel", estilo)
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circulo.add_child(centro)
	var etiqueta := Label.new()
	etiqueta.text = simbolo
	etiqueta.add_theme_font_override("font", moderno_fuente(true))
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", color_texto)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(etiqueta)
	return circulo
