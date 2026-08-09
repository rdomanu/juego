extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — COMPARATIVA DE ALTURA DE PARED (2026-08-05).
##
## El usuario, viendo la referencia de Summer (`demo/captura_demo_props.png`): las paredes de la
## comisaría se ven CLARAMENTE más altas que las de hoy (`ParedesSalas.ALTO_PARED = 34.0`). Esta
## sonda NO decide el valor definitivo — solo saca la comparativa para que el usuario elija con la
## foto delante, contra un muñeco de referencia a escala real.
##
## LA ESCALA: convención del proyecto (`tools/render_props_poly.gd`), un muñeco `girl` de 44 px ==
## 1,70 m reales → `PX_POR_METRO = 44 / 1.70 ≈ 25,88`. Con esa regla, una pared de 2,50 m son ~65 px
## y una de 2,70 m son ~70 px — los dos valores "reales" que se comparan aquí contra el actual (34,
## que a esta escala son ~1,31 m: más bajo que el propio muñeco) y un intermedio (48, ~1,86 m).
##
## CÓMO SE VARÍA LA ALTURA: `ParedesSalas.ALTO_PARED` es un `const`, así que no se puede tocar en
## caliente desde este script — se cambia A MANO en `src/main/paredes_salas.gd` ENTRE ejecuciones
## (el propio nombre de archivo de salida se calcula del valor vigente, así que no hace falta pasar
## nada por línea de comandos). Cuatro ejecuciones = las cuatro capturas. El valor se deja en 34.0
## al terminar la comparativa: la decisión es del usuario, no de esta sonda.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(720, 540)

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"

## La escala del muñeco de referencia (misma convención que `render_props_poly.gd`): 44 px == 1,70 m.
const ALTO_MUNECO_PX: int = 44
const ALTO_MUNECO_M: float = 1.70
const PX_POR_METRO: float = float(ALTO_MUNECO_PX) / ALTO_MUNECO_M


func _ready() -> void:
	await _capturar_comparativa()
	get_tree().quit()


## Una sala CERRADA (documentación, 6×4, los 4 lados amurallados) con la fachada levantada, en modo
## `&"todas"` — así TODOS los tramos salen a `ALTO_PARED` sin distinción trasera/frontal: lo que se
## está midiendo es el número en sí, no la regla de paredes bajitas (que ya tiene su propia sonda,
## `_diag_modos_pared.gd`). Un muñeco de pie DENTRO, arrimado a la pared de fondo, da la escala.
func _montar() -> Array:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	# ⚠️ ENCUADRE CON CÁMARA, no transformando un Node2D padre: las capas visuales de `Construccion`
	# cuelgan de un nodo NO-CanvasItem (raíz de canvas, no hereda transformadas de ningún padre —
	# mismo gotcha ya documentado en `_diag_modos_pared.gd` / `_diag_oclusion_murete.gd`).
	var camara := Camera2D.new()
	camara.zoom = Vector2(2.0, 2.0)
	camara.position = ProyeccionScript.proyectar(Vector2(4.0, 3.0) * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 6, 4)
	)
	construccion.fijar_paredes_de_sala(sala, true)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	paredes.fijar_modo_altura(&"todas")   # TODOS los tramos a ALTO_PARED — el número puro, sin mezcla.
	# El muñeco de pie, arrimado por DENTRO a la pared de fondo (norte) — el mismo sitio donde se
	# juzga cualquier pared trasera en las sondas de ocupación (`_diag_oclusion_murete.gd`).
	# Muñeco ACTUAL del juego (civil J-Toastie), no el `girl` retirado — señalado por el usuario.
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = ProyeccionScript.centro_iso(Vector2i(4, 1))
	profundo.add_child(muneco)
	return [sub, paredes]


## Una única captura: la sala + el muñeco, con el `ALTO_PARED` que tenga VIGENTE el código en este
## momento (se cambia a mano entre ejecuciones — ver la cabecera). El nombre de archivo sale del
## propio valor, así que cada ejecución escribe su PNG sin pisar las anteriores.
func _capturar_comparativa() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var alto: float = ParedesSalasScript.ALTO_PARED
	var alto_m: float = alto / PX_POR_METRO
	print("[DIAG ALTURAS PARED] ALTO_PARED=%.1f px (~%.2f m a %.2f px/m) ALTO_PARED_FRENTE=%.1f px" % [
		alto, alto_m, PX_POR_METRO, ParedesSalasScript.ALTO_PARED_FRENTE
	])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%salturas_pared_%d.png" % [CARPETA_SALIDA, int(round(alto))]
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG ALTURAS PARED] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG ALTURAS PARED] ALTO_PARED=%.1f -> %s" % [alto, ruta])
	sub.queue_free()
