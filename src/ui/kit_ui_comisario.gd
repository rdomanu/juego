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
