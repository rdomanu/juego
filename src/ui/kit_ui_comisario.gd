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
## Rojo SUAVE de fondo (250,227,225) — el panel de un coste que duele sin ser un error: la tarjeta
## "COSTE TOTAL DE PEONADA HOY" de la pantalla de Horario (F3, `maqueta_horario.py::ROJO_SUAVE`).
## El texto de encima va en `MOD_COLOR_ROJO`, que sobre este fondo sí contrasta.
const MOD_COLOR_ROJO_SUAVE := Color(0.980, 0.890, 0.882, 1.0)
## Ámbar OSCURECIDO, SOLO para texto de cuerpo sobre `MOD_COLOR_PANEL` (F3, 2026-08-17): el ámbar de
## aviso (240,158,44) sobre panel claro no llega al contraste mínimo de
## `design/ux/accessibility-requirements.md`; esta variante (181,112,15) sí. El punto de un chip o
## el relleno de una barra siguen usando `MOD_COLOR_AMBAR` (formas grandes, no texto).
const MOD_COLOR_AMBAR_TEXTO := Color(0.710, 0.439, 0.059, 1.0)
## Azul CLARO distinto del acento (92,156,235) para el estado "cubriendo" de un agente (F3): tiene
## que leerse como "está, pero de prestado" sin confundirse con el azul de acento de la propia UI.
const MOD_COLOR_AZUL_CUBRIENDO := Color(0.361, 0.612, 0.922, 1.0)
## Grises de relleno neutro de la maqueta: `GRIS_SUAVE` (231,233,237) para un botón deshabilitado y
## `GRIS_MUY_SUAVE` (243,245,248) para el hueco de una tarjeta que está siendo arrastrada o el velo
## de un slot no válido durante un arrastre.
const MOD_COLOR_GRIS_SUAVE := Color(0.906, 0.914, 0.929, 1.0)
const MOD_COLOR_GRIS_MUY_SUAVE := Color(0.953, 0.961, 0.973, 1.0)

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
		# Ancla al centro con offsets simétricos: fijar `position` a mano se deshace cuando el botón
		# recibe su tamaño real (el ancla mueve el punto de referencia y el icono acababa en la
		# esquina inferior derecha — cazado en captura contra la maqueta v3).
		rect.set_anchors_preset(Control.PRESET_CENTER)
		rect.offset_left = -10.0
		rect.offset_top = -10.0
		rect.offset_right = 10.0
		rect.offset_bottom = 10.0
		boton.add_child(rect)
	return boton


# ── Botón PASTILLA de texto (F3, pantalla Personal — `maqueta_personal.py::boton_pill`) ──────────
## Los 4 estilos de la maqueta. Son `StringName` y no un enum para que el llamante los escriba tal
## cual sin importar la clase (mismo criterio que los ids de `ICONOS`).
const MOD_BOTON_PRIMARIO := &"primario"          # acento macizo + texto blanco (acción principal)
const MOD_BOTON_SECUNDARIO := &"secundario"      # tarjeta blanca + borde línea + tinta
const MOD_BOTON_PELIGRO := &"peligro"            # tarjeta blanca + borde línea + texto ROJO (despedir)
const MOD_BOTON_DESHABILITADO := &"deshabilitado" # gris suave + texto gris (y `disabled = true`)


## Botón de texto en forma de pastilla (radio = mitad del alto), los cuatro estilos de la maqueta
## `maqueta_personal.png`. `con_flecha` añade el triángulo "▾" DIBUJADO (`GlifoModerno`), nunca el
## carácter unicode: la fuente del sistema no lo trae y sale como tofu (cazado en la iteración 2 de
## la maqueta). Siempre `focus_mode = FOCUS_NONE` (gotcha del proyecto: si no, la barra espaciadora
## "pulsa" el botón enfocado en vez de pausar el juego).
##
## Ejemplo:
##     var b := KitUIComisario.moderno_boton_pastilla("Mover a", KitUIComisario.MOD_BOTON_SECUNDARIO, 34.0, true)
##     b.pressed.connect(_abrir_desplegable)
static func moderno_boton_pastilla(
	texto: String, estilo_id: StringName = MOD_BOTON_SECUNDARIO, alto: float = 30.0,
	con_flecha: bool = false, tam_fuente: int = 12
) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size.y = alto
	boton.add_theme_font_size_override("font_size", tam_fuente)
	boton.add_theme_font_override("font", moderno_fuente(true))
	var color_fondo: Color = MOD_COLOR_TARJETA
	var color_texto: Color = MOD_COLOR_TINTA
	var con_borde: bool = false
	match estilo_id:
		MOD_BOTON_PRIMARIO:
			color_fondo = MOD_COLOR_ACENTO
			color_texto = Color.WHITE
		MOD_BOTON_PELIGRO:
			color_texto = MOD_COLOR_ROJO
			con_borde = true
		MOD_BOTON_DESHABILITADO:
			color_fondo = MOD_COLOR_GRIS_SUAVE
			color_texto = MOD_COLOR_GRIS
			boton.disabled = true
		_:
			con_borde = true
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.set_corner_radius_all(int(alto / 2.0))
	estilo.content_margin_left = 14.0
	estilo.content_margin_right = 14.0 + (18.0 if con_flecha else 0.0)   # hueco reservado a la flecha
	estilo.content_margin_top = 4.0
	estilo.content_margin_bottom = 4.0
	if con_borde:
		estilo.set_border_width_all(1)
		estilo.border_color = MOD_COLOR_LINEA
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("pressed", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	boton.add_theme_color_override("font_color", color_texto)
	boton.add_theme_color_override("font_hover_color", color_texto)
	boton.add_theme_color_override("font_pressed_color", color_texto)
	boton.add_theme_color_override("font_disabled_color", MOD_COLOR_GRIS)
	if con_flecha:
		# `Button` NO es un contenedor (gotcha del proyecto): el hijo se ancla a mano. Centro-derecha
		# con offsets simétricos — el mismo patrón que el icono de `moderno_boton_icono`.
		var flecha: Control = moderno_glifo(GlifoModerno.Tipo.TRIANGULO_ABAJO, color_texto, 10.0)
		flecha.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		flecha.offset_left = -20.0
		flecha.offset_top = -5.0
		flecha.offset_right = -10.0
		flecha.offset_bottom = 5.0
		boton.add_child(flecha)
	return boton


## Borde DISCONTINUO redondeado (el hueco "arrastra aquí" de un puesto vacante, F3): un `Control`
## decorativo que se cuelga como hijo de la tarjeta/panel y se dibuja encima de su rectángulo
## completo. `StyleBoxFlat` no sabe hacer bordes a trazos — de ahí el `_draw()` propio. El color y el
## grosor son mutables en caliente (`borde.color = ...; borde.queue_redraw()`), mismo patrón "dato
## reactivo" que `moderno_actualizar_barra_progreso`.
##
## Ejemplo (dentro de un `PanelContainer`, que estira a TODOS sus hijos al rectángulo del panel):
##     slot.add_child(KitUIComisario.moderno_borde_punteado())
static func moderno_borde_punteado(
	color: Color = MOD_COLOR_GRIS, radio: float = MOD_RADIO_PEQUENO, grosor: float = 2.0
) -> Control:
	var borde := BordePunteadoModerno.new()
	borde.color = color
	borde.radio = radio
	borde.grosor = grosor
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return borde


## Pastilla partida en N opciones (toggle Función/Sala del panel de construcción): una fila de
## `Button` en `toggle_mode` dentro de una ÚNICA pastilla exterior BLANCA -- la opción activa lleva
## fondo `MOD_COLOR_ACENTO_SUAVE` con texto `MOD_COLOR_ACENTO` (azul suave), el resto texto tinta
## sobre transparente.
##
## Estilo corregido el 2026-08-17 contra la maqueta aprobada (`menu_v3_completo.png`): antes la
## pastilla exterior era gris (`MOD_COLOR_PANEL`), los segmentos tenían 2px de hueco entre ellos y el
## activo era azul MACIZO con texto blanco. La maqueta pide justo lo contrario: pastilla blanca, los
## dos segmentos JUNTOS (separación 0) y el activo en azul suave. La API (parámetros, nombres de los
## botones hijos `"Opcion_<id>"`) NO cambia -- su único consumidor, `ModoConstruccion._crear_ui`,
## sigue funcionando sin tocarlo. `opciones` es
## `[{"id": StringName, "texto": String, "habilitado": bool, "tooltip": String}]` (las tres últimas
## claves opcionales); devuelve la pastilla exterior con cada botón colgado como hijo con nombre
## `"Opcion_" + id` -- el llamante conecta `pressed` y alterna `button_pressed` a mano (este kit no
## sabe qué debe pasar al elegir una opción, solo construye el control).
static func toggle_segmentado(opciones: Array[Dictionary], alto: float = 38.0) -> PanelContainer:
	var pastilla := moderno_pastilla(MOD_COLOR_TARJETA, alto)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)   # segmentos JUNTOS (maqueta v3)
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
		estilo_activo.bg_color = MOD_COLOR_ACENTO_SUAVE
		boton.add_theme_stylebox_override("normal", estilo_normal)
		boton.add_theme_stylebox_override("hover", estilo_normal)
		boton.add_theme_stylebox_override("disabled", estilo_normal)
		boton.add_theme_stylebox_override("pressed", estilo_activo)
		boton.add_theme_color_override("font_color", MOD_COLOR_TINTA)
		boton.add_theme_color_override("font_pressed_color", MOD_COLOR_ACENTO)
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
## AMPLIACIÓN 2026-08-17 (veredicto del usuario "manda la maqueta"): los 6 pictogramas de LÍNEA que
## faltaban -- PLANO/SILLON/MURO/PIN/LLAVE (las 5 categorías del panel de construcción) y LUPA (el
## buscador), más PERSONA/DOCUMENTO para los chips de Plantilla/Documentación del HUD. Sustituyen a
## los PNG del kit viejo de Summer (`ICONOS`), que a 16-20px al lado de la tipografía moderna se leen
## como manchas oscuras (auditado en captura el 2026-08-16). Todos se dibujan con trazo ~1.8px sobre
## un lienzo cuadrado normalizado por `size`, así el MISMO glifo sirve a 16px (categoría) y a 22px
## (módulo del HUD) sin retocar números.
class GlifoModerno extends Control:
	enum Tipo {
		RELOJ, PAUSA, PLAY1, PLAY2, PLAY3,
		PLANO, SILLON, MURO, PIN, LLAVE, LUPA, PERSONA, DOCUMENTO,
		PARED_ENTERA, PARED_BAJA, PARED_AUTO,
		## Flecha "▾" MACIZA de un desplegable (F3, pantalla Personal). Se DIBUJA porque el glifo
		## unicode ▾ no está en la fuente del sistema y sale como tofu (cazado en la maqueta). Los
		## valores nuevos van SIEMPRE al final: nadie lo serializa, pero el orden es contrato de
		## `GLIFO_POR_CATEGORIA` y de los tests.
		TRIANGULO_ABAJO,
	}
	## Grosor de trazo común de los glifos de línea (la maqueta compone con líneas de 2px a 24px de
	## lienzo; 1.8 es el equivalente a 16-18px sin que el trazo empaste).
	const TRAZO: float = 1.8
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
			Tipo.PLANO:
				_dibujar_plano()
			Tipo.SILLON:
				_dibujar_sillon()
			Tipo.MURO:
				_dibujar_muro()
			Tipo.PIN:
				_dibujar_pin()
			Tipo.LLAVE:
				_dibujar_llave()
			Tipo.LUPA:
				_dibujar_lupa()
			Tipo.PERSONA:
				_dibujar_persona()
			Tipo.DOCUMENTO:
				_dibujar_documento()
			Tipo.PARED_ENTERA:
				_dibujar_pared(1.0, false)
			Tipo.PARED_BAJA:
				_dibujar_pared(0.5, false)
			Tipo.PARED_AUTO:
				_dibujar_pared(0.5, true)
			Tipo.TRIANGULO_ABAJO:
				_dibujar_triangulo_abajo()

	## El rectángulo útil del lienzo: cuadrado centrado con 1px de aire para que el trazo no se coma
	## el borde (todos los glifos nuevos parten de aquí -- un solo sitio donde ajustar el encuadre).
	func _marco() -> Rect2:
		var lado: float = minf(size.x, size.y) - 2.0
		return Rect2((size - Vector2(lado, lado)) * 0.5, Vector2(lado, lado))

	## PLANO (categoría "Salas"): rectángulo con 2 líneas internas -- un plano de planta esquemático.
	func _dibujar_plano() -> void:
		var m: Rect2 = _marco()
		var caja := Rect2(m.position + Vector2(0.0, m.size.y * 0.12), Vector2(m.size.x, m.size.y * 0.76))
		draw_rect(caja, color, false, TRAZO)
		var x_tabique: float = caja.position.x + caja.size.x * 0.42
		draw_line(
			Vector2(x_tabique, caja.position.y), Vector2(x_tabique, caja.position.y + caja.size.y * 0.55),
			color, TRAZO, true
		)
		var y_tabique: float = caja.position.y + caja.size.y * 0.58
		draw_line(
			Vector2(x_tabique, y_tabique), Vector2(caja.position.x + caja.size.x, y_tabique),
			color, TRAZO, true
		)

	## SILLÓN (categoría "Muebles"): silla DE PERFIL en 5 trazos -- respaldo, asiento y dos patas.
	func _dibujar_sillon() -> void:
		var m: Rect2 = _marco()
		var izq: float = m.position.x + m.size.x * 0.24
		var der: float = m.position.x + m.size.x * 0.86
		var alto_respaldo: float = m.position.y + m.size.y * 0.10
		var y_asiento: float = m.position.y + m.size.y * 0.58
		var y_suelo: float = m.position.y + m.size.y * 0.92
		draw_line(Vector2(izq, alto_respaldo), Vector2(izq, y_asiento), color, TRAZO, true)   # respaldo
		draw_line(Vector2(izq, y_asiento), Vector2(der, y_asiento), color, TRAZO, true)       # asiento
		draw_line(Vector2(izq, y_suelo), Vector2(izq, y_asiento), color, TRAZO, true)         # pata tras
		draw_line(Vector2(der, y_asiento), Vector2(der, y_suelo), color, TRAZO, true)         # pata del
		# Cojín: un trazo corto pegado al respaldo, lo que hace legible que es un asiento y no una "L".
		draw_line(
			Vector2(izq, m.position.y + m.size.y * 0.44),
			Vector2(m.position.x + m.size.x * 0.58, m.position.y + m.size.y * 0.44), color, TRAZO, true
		)

	## MURO (categoría "Muros y suelos"): 3 hiladas de ladrillo con las juntas verticales alternadas.
	func _dibujar_muro() -> void:
		var m: Rect2 = _marco()
		var alto_hilada: float = m.size.y * 0.24
		var y0: float = m.position.y + m.size.y * 0.14
		for i in 3:
			var y: float = y0 + i * alto_hilada
			draw_line(Vector2(m.position.x, y), Vector2(m.position.x + m.size.x, y), color, TRAZO, true)
			# Junta vertical: centrada en las hiladas pares, a un tercio en las impares (aparejo).
			var x: float = m.position.x + (m.size.x * 0.5 if i % 2 == 0 else m.size.x * 0.28)
			draw_line(Vector2(x, y), Vector2(x, y + alto_hilada), color, TRAZO, true)
		var y_base: float = y0 + 3.0 * alto_hilada
		draw_line(
			Vector2(m.position.x, y_base), Vector2(m.position.x + m.size.x, y_base), color, TRAZO, true
		)

	## PIN (categoría "Zonas"): gota de mapa -- arco superior + dos lados que caen a la punta + punto.
	func _dibujar_pin() -> void:
		var m: Rect2 = _marco()
		var radio: float = m.size.x * 0.32
		var centro := Vector2(m.position.x + m.size.x * 0.5, m.position.y + m.size.y * 0.36)
		draw_arc(centro, radio, PI * 0.78, PI * 2.22, 20, color, TRAZO, true)
		var punta := Vector2(centro.x, m.position.y + m.size.y * 0.95)
		var izq := centro + Vector2(-radio, radio * 0.62)
		var der := centro + Vector2(radio, radio * 0.62)
		draw_line(izq, punta, color, TRAZO, true)
		draw_line(der, punta, color, TRAZO, true)
		draw_circle(centro, maxf(1.4, radio * 0.28), color)

	## LLAVE (categoría "Herramientas"): llave inglesa esquemática -- boca en "C" + mango en diagonal.
	func _dibujar_llave() -> void:
		var m: Rect2 = _marco()
		var radio: float = m.size.x * 0.26
		var centro_boca := Vector2(m.position.x + m.size.x * 0.30, m.position.y + m.size.y * 0.28)
		draw_arc(centro_boca, radio, PI * -0.55, PI * 1.10, 18, color, TRAZO, true)
		draw_line(
			centro_boca + Vector2(radio * 0.5, radio * 0.5),
			Vector2(m.position.x + m.size.x * 0.86, m.position.y + m.size.y * 0.90), color, TRAZO, true
		)

	## LUPA (buscador): círculo + mango en diagonal hacia abajo-derecha.
	func _dibujar_lupa() -> void:
		var m: Rect2 = _marco()
		var radio: float = m.size.x * 0.30
		var centro := Vector2(m.position.x + m.size.x * 0.42, m.position.y + m.size.y * 0.40)
		draw_arc(centro, radio, 0.0, TAU, 24, color, TRAZO, true)
		var desde: Vector2 = centro + Vector2(radio, radio) * 0.72
		draw_line(desde, Vector2(m.position.x + m.size.x * 0.92, m.position.y + m.size.y * 0.92),
			color, TRAZO, true)

	## PERSONA (chip Plantilla del HUD): cabeza (círculo) + hombros (arco) -- calcado del mockup
	## ejecutable `maqueta_hud_v3.py` (`d.ellipse` + `d.arc` 180-360).
	func _dibujar_persona() -> void:
		var m: Rect2 = _marco()
		var radio_cabeza: float = m.size.x * 0.22
		var centro_cabeza := Vector2(m.position.x + m.size.x * 0.5, m.position.y + m.size.y * 0.30)
		draw_arc(centro_cabeza, radio_cabeza, 0.0, TAU, 20, color, TRAZO, true)
		var centro_hombros := Vector2(centro_cabeza.x, m.position.y + m.size.y * 0.94)
		draw_arc(centro_hombros, m.size.x * 0.34, PI, TAU, 20, color, TRAZO, true)

	## DOCUMENTO (chip Documentación del HUD): hoja vertical + 2 renglones.
	func _dibujar_documento() -> void:
		var m: Rect2 = _marco()
		var caja := Rect2(
			m.position + Vector2(m.size.x * 0.24, m.size.y * 0.08),
			Vector2(m.size.x * 0.52, m.size.y * 0.84)
		)
		draw_rect(caja, color, false, TRAZO)
		for i in 2:
			var y: float = caja.position.y + caja.size.y * (0.34 + 0.24 * i)
			draw_line(
				Vector2(caja.position.x + caja.size.x * 0.22, y),
				Vector2(caja.position.x + caja.size.x * 0.78, y), color, TRAZO * 0.7, true
			)

	## Pared en DIAGONAL isométrica (botón Paredes del HUD; referencia pedida por el usuario
	## 2026-08-17: el icono de muro de Los Sims). El MODO vigente lo cuenta el propio dibujo:
	## `altura` 1.0 = enteras, 0.5 = bajitas; con `techo_punteado`, la coronación de la pared entera
	## se insinúa a trazos sobre la bajita (= Auto: "bajitas ahora, enteras cuando toque").
	func _dibujar_pared(altura: float, techo_punteado: bool) -> void:
		var m: Rect2 = _marco()
		var base_a := m.position + Vector2(m.size.x * 0.04, m.size.y * 0.58)
		var base_b := m.position + Vector2(m.size.x * 0.96, m.size.y * 0.94)
		var alto_muro: float = m.size.y * 0.52
		var subida := Vector2(0.0, alto_muro * altura)
		draw_line(base_a, base_b, color, TRAZO, true)
		draw_line(base_a, base_a - subida, color, TRAZO, true)
		draw_line(base_b, base_b - subida, color, TRAZO, true)
		draw_line(base_a - subida, base_b - subida, color, TRAZO, true)
		if techo_punteado:
			var corona := Vector2(0.0, alto_muro)
			var ca := base_a - corona
			var cb := base_b - corona
			for i in 3:
				var t0: float = i / 3.0 + 0.06
				var t1: float = i / 3.0 + 0.24
				draw_line(ca.lerp(cb, t0), ca.lerp(cb, t1), color, TRAZO, true)

	## Triángulo MACIZO apuntando abajo — la flecha de un desplegable, calcada de
	## `maqueta_personal.py::triangulo_abajo` (mismas proporciones: base arriba, punta al 65 % del
	## radio hacia abajo).
	func _dibujar_triangulo_abajo() -> void:
		var m: Rect2 = _marco()
		var centro: Vector2 = m.position + m.size * 0.5
		var r: float = m.size.x * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(centro.x - r, centro.y - r * 0.45),
			Vector2(centro.x + r, centro.y - r * 0.45),
			Vector2(centro.x, centro.y + r * 0.65),
		]), color)

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


## El `Control` decorativo que dibuja el borde a trazos de `moderno_borde_punteado` (F3): tramos
## rectos discontinuos + las cuatro esquinas en arco CONTINUO (misma aproximación que la maqueta
## `maqueta_personal.py::rect_punteado`, donde PIL tampoco tiene "dashed rounded rect" nativo).
class BordePunteadoModerno extends Control:
	var color: Color = Color(0.478, 0.533, 0.612, 1.0)
	var radio: float = 14.0
	var grosor: float = 2.0
	## Largo del trazo y del hueco, en píxeles (los de la maqueta: 6 y 5).
	var guion: float = 6.0
	var hueco: float = 5.0

	func _draw() -> void:
		var r: float = minf(radio, minf(size.x, size.y) * 0.5)
		# Media pluma de margen: dibujar justo en 0 / `size` recorta el trazo a la mitad.
		var margen: float = grosor * 0.5
		_tramo_horizontal(r, margen)
		_tramo_horizontal(r, size.y - margen)
		_tramo_vertical(r, margen)
		_tramo_vertical(r, size.x - margen)
		# Esquinas: arco continuo de 90° (un trazo corto que no merece partirse).
		var pasos: int = 6
		draw_arc(Vector2(r, r), r, PI, PI * 1.5, pasos, color, grosor, true)
		draw_arc(Vector2(size.x - r, r), r, PI * 1.5, TAU, pasos, color, grosor, true)
		draw_arc(Vector2(size.x - r, size.y - r), r, 0.0, PI * 0.5, pasos, color, grosor, true)
		draw_arc(Vector2(r, size.y - r), r, PI * 0.5, PI, pasos, color, grosor, true)

	func _tramo_horizontal(r: float, y: float) -> void:
		var x: float = r
		while x < size.x - r:
			var siguiente: float = minf(x + guion, size.x - r)
			draw_line(Vector2(x, y), Vector2(siguiente, y), color, grosor, true)
			x = siguiente + hueco

	func _tramo_vertical(r: float, x: float) -> void:
		var y: float = r
		while y < size.y - r:
			var siguiente: float = minf(y + guion, size.y - r)
			draw_line(Vector2(x, y), Vector2(x, siguiente), color, grosor, true)
			y = siguiente + hueco


## Glifo VECTORIAL por categoría de la barra de construcción -- gemelo moderno de
## `ICONO_POR_CATEGORIA` (que apunta a los PNG del piloto de Summer): mismas 5 claves, pero
## resolviendo a un `GlifoModerno.Tipo`. Vive aquí, después de la clase, porque un `const` no puede
## referenciar una clase interna declarada más abajo en el mismo archivo.
const GLIFO_POR_CATEGORIA: Dictionary[StringName, int] = {
	&"salas": GlifoModerno.Tipo.PLANO,
	&"muebles": GlifoModerno.Tipo.SILLON,
	&"muros_suelos": GlifoModerno.Tipo.MURO,
	&"zonas": GlifoModerno.Tipo.PIN,
	&"herramientas": GlifoModerno.Tipo.LLAVE,
}


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
## `tam_fuente` en 0 (por defecto) lo deduce del diámetro (40 % del lado, la proporción de los avatares
## de `maqueta_personal.py::avatar_inicial`): así el MISMO helper sirve al avatar de 32 px de una
## tarjeta y al de 64 px de la ficha sin que la letra se quede enana (F3, 2026-08-17).
static func moderno_circulo_simbolo(
	simbolo: String, color_fondo: Color, color_texto: Color, lado: float = 32.0,
	tam_fuente: int = 0
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
	# El `maxf(14, ...)` conserva EXACTAMENTE el tamaño de antes (14) en las insignias pequeñas ya
	# existentes del HUD (lado 32 → 12.8 sería un cambio silencioso de aspecto en pantalla ajena).
	etiqueta.add_theme_font_size_override(
		"font_size", tam_fuente if tam_fuente > 0 else int(maxf(14.0, lado * 0.4))
	)
	etiqueta.add_theme_color_override("font_color", color_texto)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(etiqueta)
	return circulo


# ── SLIDER moderno (F3, pantalla de Horario — `maqueta_horario.py::control_grande`) ───────────────
## Alto del raíl de un slider moderno y lado del tirador (la maqueta: raíl de 10 px, tirador de 22).
const MOD_ALTO_RAIL_SLIDER: float = 10.0
const MOD_LADO_GRABBER_SLIDER: float = 22.0

static var _grabbers_cache: Dictionary[String, ImageTexture] = {}


## Viste un `Slider` (H o V) con el lenguaje moderno de la maqueta: raíl fino redondeado del color de
## línea, tramo recorrido macizo en `color_relleno` (acento o ámbar según lo que mida el control) y
## tirador CIRCULAR blanco con aro del mismo color. `focus_mode = FOCUS_NONE` siempre (gotcha del
## proyecto: si no, la barra espaciadora "pulsa" el control enfocado en vez de pausar el juego).
##
## El tirador es una textura generada por código (`_textura_grabber`) porque el tema de un `Slider`
## pide un `Texture2D` para el grabber, no un `StyleBox`; el kit no depende de ningún PNG nuevo.
##
## ⚠️ Nombres de ítem de tema de `Slider` (`slider`/`grabber_area`/`grabber`/`center_grabber`): son
## los de la API estable desde 4.0, pero el proyecto va pinado a Godot 4.6 — si algún día un slider
## sale con el raíl gordo del tema por defecto, verificar estos nombres contra
## `docs/engine-reference/godot/` antes de tocar nada más.
static func moderno_estilizar_slider(
	slider: Slider, color_relleno: Color = MOD_COLOR_ACENTO,
	alto_rail: float = MOD_ALTO_RAIL_SLIDER, lado_grabber: float = MOD_LADO_GRABBER_SLIDER
) -> void:
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.y = maxf(slider.custom_minimum_size.y, lado_grabber)
	var rail := StyleBoxFlat.new()
	rail.bg_color = MOD_COLOR_LINEA
	rail.set_corner_radius_all(int(alto_rail / 2.0))
	rail.content_margin_top = alto_rail / 2.0
	rail.content_margin_bottom = alto_rail / 2.0
	var recorrido: StyleBoxFlat = rail.duplicate()
	recorrido.bg_color = color_relleno
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", recorrido)
	slider.add_theme_stylebox_override("grabber_area_highlight", recorrido)
	var tirador: ImageTexture = _textura_grabber(color_relleno, int(lado_grabber))
	slider.add_theme_icon_override("grabber", tirador)
	slider.add_theme_icon_override("grabber_highlight", tirador)
	slider.add_theme_icon_override("grabber_disabled", tirador)
	# Sin esto el tema por defecto baja el tirador con `grabber_offset` y queda descolgado del raíl.
	slider.add_theme_constant_override("center_grabber", 1)
	slider.add_theme_constant_override("grabber_offset", 0)


## Círculo blanco con aro de color, generado a mano y CACHEADO por color+tamaño (varios sliders
## comparten tirador). El borde se suaviza por distancia al centro: un círculo a pelo con `set_pixel`
## sale con el canto de sierra y se nota mucho a 22 px.
static func _textura_grabber(
	color_aro: Color, lado: int = int(MOD_LADO_GRABBER_SLIDER), grosor: float = 3.0
) -> ImageTexture:
	var clave: String = "%s_%d_%.1f" % [color_aro.to_html(false), lado, grosor]
	if _grabbers_cache.has(clave):
		return _grabbers_cache[clave]
	var imagen: Image = Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var centro: float = lado / 2.0
	var radio_exterior: float = centro - 0.5
	var radio_interior: float = radio_exterior - grosor
	for y: int in lado:
		for x: int in lado:
			var distancia: float = Vector2(x + 0.5 - centro, y + 0.5 - centro).length()
			var alfa: float = clampf(radio_exterior - distancia + 0.5, 0.0, 1.0)
			var mezcla: float = clampf(distancia - radio_interior + 0.5, 0.0, 1.0)
			var color: Color = MOD_COLOR_TARJETA.lerp(color_aro, mezcla)
			color.a = alfa
			imagen.set_pixel(x, y, color)
	var textura: ImageTexture = ImageTexture.create_from_image(imagen)
	_grabbers_cache[clave] = textura
	return textura


# ── CASILLA de verificación moderna (F3, pantalla de Horario — `maqueta_horario.py::casilla`) ──────
## Casilla cuadrada de esquinas redondeadas: vacía = solo borde gris; marcada = maciza de acento con
## la "V" blanca. Se DIBUJA (`CasillaModerna._draw`) en vez de usar un `CheckBox`, porque el icono de
## un `CheckBox` sale del tema global (pixel-art del kit viejo) y desentonaría con la pantalla
## moderna. Es un `Button` en `toggle_mode`: el estado real vive en `button_pressed` (nunca solo el
## color) y la señal es la nativa `toggled`.
##
## Ejemplo:
##     var c := KitUIComisario.moderno_casilla(doc.puesto_de_tarde(id))
##     c.toggled.connect(func(activa: bool) -> void: _ordenar_tarde(id, activa))
static func moderno_casilla(marcada: bool, lado: float = 20.0) -> Button:
	var casilla := CasillaModerna.new()
	# Los colores se INYECTAN: una clase interna de GDScript no ve las constantes de la clase que la
	# contiene, y cualificarlas con el `class_name` desde dentro es justo lo que falla en headless frío.
	casilla.color_marcada = MOD_COLOR_ACENTO
	casilla.color_marca = MOD_COLOR_TARJETA
	casilla.toggle_mode = true
	casilla.button_pressed = marcada
	casilla.focus_mode = Control.FOCUS_NONE
	casilla.custom_minimum_size = Vector2(lado, lado)
	casilla.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	casilla.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	casilla.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	casilla.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return casilla


## El `Button` que se dibuja como la casilla de la maqueta. Vive aquí (y no en la pantalla) para que
## cualquier pantalla moderna futura tenga la MISMA casilla sin copiar el `_draw`.
class CasillaModerna extends Button:
	## Color del borde de una casilla VACÍA (190,196,208) — el de la maqueta, más oscuro que el color
	## de línea del kit para que un cuadrado hueco de 20 px se vea sobre tarjeta blanca.
	var color_borde: Color = Color(0.745, 0.769, 0.816, 1.0)
	## Relleno de la casilla marcada y color de la "V" (los inyecta `moderno_casilla`).
	var color_marcada: Color = Color(0.184, 0.424, 0.878, 1.0)
	var color_marca: Color = Color(1.0, 1.0, 1.0, 1.0)
	const RADIO := 5

	func _init() -> void:
		toggled.connect(func(_activa: bool) -> void: queue_redraw())

	func _draw() -> void:
		var caja := Rect2(Vector2.ZERO, size)
		var estilo := StyleBoxFlat.new()
		estilo.set_corner_radius_all(RADIO)
		if button_pressed:
			estilo.bg_color = color_marcada
		else:
			estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			estilo.set_border_width_all(2)
			estilo.border_color = color_borde
		draw_style_box(estilo, caja)
		if not button_pressed:
			return
		# La "V" de la maqueta: dos trazos con los mismos puntos relativos (0.22/0.55 → 0.42/0.75 →
		# 0.80/0.25) para que la marca se vea igual a cualquier tamaño de casilla.
		var p0 := Vector2(size.x * 0.22, size.y * 0.55)
		var p1 := Vector2(size.x * 0.42, size.y * 0.75)
		var p2 := Vector2(size.x * 0.80, size.y * 0.25)
		draw_line(p0, p1, color_marca, 2.0, true)
		draw_line(p1, p2, color_marca, 2.0, true)


## Formato de dinero de TODA la UI ("1.240 €"): miles con punto y SIN decimales — los céntimos no
## existen de cara al jugador. Nació como `HudComisario._formato_euros` (spec §1.3-[3]); promovido
## aquí el 2026-08-17 al necesitarlo también el panel de Personal (fuente única, como los colores).
static func formato_euros(valor: float) -> String:
	var negativo: bool = valor < 0.0
	var texto: String = str(int(roundf(absf(valor))))
	var con_miles: String = ""
	while texto.length() > 3:
		con_miles = "." + texto.substr(texto.length() - 3) + con_miles
		texto = texto.substr(0, texto.length() - 3)
	con_miles = texto + con_miles
	return ("-" if negativo else "") + con_miles + " €"
