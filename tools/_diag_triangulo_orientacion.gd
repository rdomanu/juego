extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — EL TRIÁNGULO DE ORIENTACIÓN DEL FANTASMA (2026-08-06,
## `src/main/modo_construccion.gd`: `PreviewOrientacion`/`_colocar_triangulo_orientacion`).
##
## Monta un `ModoConstruccion` REAL sobre una `Construccion` real (sin mocks), con un muñeco de
## 44 px de referencia y la REJILLA del modo encendida, y verifica el vértice (ápice) del triángulo
## azul en las 4 direcciones canónicas del plano cuadrado:
##
##   · SUR/OESTE (2 casos): recorridas por el camino REAL del juego —
##     `_modo._orientacion` HORIZONTAL/VERTICAL + `R` (aquí, `_refrescar_preview_elemento` end-to-end,
##     mismo disparador que usa `_process`) sobre un sofá de 2 celdas (el único elemento con sprite
##     que sí gira de verdad con R). Hoy son las DOS únicas direcciones alcanzables desde el juego —
##     `_orientacion` solo tiene 2 estados (ver el aviso en `_frente_de_orientacion`).
##   · NORTE/ESTE (2 casos): `_colocar_triangulo_orientacion` llamada DIRECTAMENTE con esas dos
##     direcciones — la función no lee `_orientacion` por su cuenta, así que esto prueba que la
##     GEOMETRÍA generaliza a las 4 direcciones canónicas aunque el atajo R de hoy solo alcance 2.
##
## EL JUEZ ES UN NÚMERO: la posición en pantalla del ÁPICE (`_preview_triangulo._puntos[0]`) contra
## la MISMA fórmula recalculada aquí de forma independiente (celda/huella/frente/margen/largo, nunca
## leyendo un resultado que el propio triángulo ya haya escrito) — delta ≤ 3 px es el veredicto
## (tolerancia pactada de la tarea).
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(560, 480)

## Carpeta del scratchpad de ESTA sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

## Tolerancia pactada en la tarea: ±3 px.
const TOLERANCIA_PX: float = 3.0

## La celda ancla y una huella fija de 2×1 (sofá horizontal) para las 4 capturas — así las 4 son
## comparables entre sí (mismo tamaño de pieza, solo cambia hacia dónde mira).
const CELDA_ANCLA := Vector2i(3, 3)
const HUELLA := Vector2i(2, 1)

## La escala del muñeco de referencia (convención del proyecto: 44 px == 1,70 m).
const ALTO_MUNECO_PX: int = 44

var _veredictos: Dictionary[String, bool] = {}


## `Construccion.HORIZONTAL`/`VERTICAL` son 0/1 fijos (ver la cabecera de esa constante en
## `construccion.gd`) — mismo criterio que `_diag_preview_fantasma.gd`: se usan los literales
## documentados antes de montar ninguna instancia real.
func _orientacion_horizontal() -> int:
	return 0


func _orientacion_vertical() -> int:
	return 1


func _ready() -> void:
	await _caso_real(_orientacion_horizontal(), "sur_horizontal_R")
	await _caso_real(_orientacion_vertical(), "oeste_vertical_R")
	await _caso_directo(Vector2i(0, -1), "norte_directo")
	await _caso_directo(Vector2i(1, 0), "este_directo")
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG TRIANGULO] RESUMEN: %d caso(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


## Una sala de descanso (admite el sofá) con margen generoso en las 4 direcciones alrededor de
## `CELDA_ANCLA`, sin cámara (mundo == pantalla, mismo criterio que el resto de sondas de este
## fichero para `ModoConstruccion`), con un muñeco de 44 px de referencia y la rejilla del modo
## ENCENDIDA (pedido de la tarea: "con la rejilla de celdas visible").
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
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)

	var construccion: Node = ConstruccionScript.new()
	mundo.add_child(construccion)
	construccion.aplicar_config(ConfigConstruccionScript.new())
	# Origen con margen: la sala de 8×8 (celda ancla (3,3) centrada) no queda pegada al borde.
	construccion.montar_visual(TAM_CELDA, Vector2(200.0, 60.0), profundo)
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(0, 0, 8, 8)
	)
	construccion.fijar_paredes_de_sala(sala, false)

	# El muñeco de referencia, de pie junto a la celda ancla (no encima: para no tapar el triángulo).
	var muneco: Node2D = MunecoScript.construir_sprite("civil_h1", ALTO_MUNECO_PX)
	muneco.position = construccion.centro_en_pantalla(CELDA_ANCLA + Vector2i(-2, 2))
	profundo.add_child(muneco)

	var modo: Node = ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)   # inyección ANTES de add_child (regla del fichero)
	mundo.add_child(modo)   # dispara _ready(): crea la UI, la rejilla y el velo de zonas
	# GOTCHA CONOCIDO (`_diag_ux_pintura.gd`): `_process` de ModoConstruccion pisaría el estado
	# forzado a mano leyendo el ratón REAL del SubViewport — se congela.
	modo.set_process(false)
	modo._activo = true
	modo._es_sala = false
	# La REJILLA del modo, encendida a mano (sin pasar por `_actualizar_visibilidad()`, que también
	# reactivaría la barra de herramientas entera y taparía el encuadre — mismo criterio que
	# `_diag_preview_fantasma.gd`).
	modo._rejilla.visible = true
	modo._atenuador.visible = true
	modo._dialogo_cascada.hide()
	return [sub, construccion, modo]


## CASOS SUR/OESTE: el camino REAL — `_orientacion` H/V + `_refrescar_preview_elemento`
## (`_construccion.COMODIDAD_SOFA_DESCANSO`, el único elemento con sprite que SÍ gira con R).
func _caso_real(orientacion: int, etiqueta: String) -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[1]
	var modo: Node = piezas[2]
	modo._herramienta = construccion.COMODIDAD_SOFA_DESCANSO
	modo._orientacion = orientacion
	modo._preview_caja.visible = true
	modo._preview_texto.visible = true
	modo._preview_sprite.visible = false
	modo._refrescar_preview_elemento(CELDA_ANCLA)
	var frente: Vector2i = modo._frente_de_orientacion(orientacion)
	# La huella REAL que calculó `_refrescar_preview_elemento` (superficie del sofá, orientada):
	# no se asume `HUELLA` a ciegas — se relee del catálogo con la misma llamada que usa el propio
	# preview, así el veredicto compara contra lo que de verdad se dibujó.
	var superficie: int = modo._superficie_de_herramienta()
	var huella: Vector2i = (
		Vector2i(1, superficie) if orientacion == construccion.VERTICAL else Vector2i(superficie, 1)
	)
	await _verificar_y_capturar(sub, construccion, modo, CELDA_ANCLA, huella, frente, etiqueta)


## CASOS NORTE/ESTE: `_colocar_triangulo_orientacion` llamada DIRECTAMENTE con `frente` sintético —
## no pasa por `_orientacion` (que hoy solo alcanza sur/oeste), prueba la GEOMETRÍA para las otras
## dos direcciones canónicas con la MISMA huella fija (`HUELLA`) que usan los casos reales.
func _caso_directo(frente: Vector2i, etiqueta: String) -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[1]
	var modo: Node = piezas[2]
	modo._herramienta = construccion.COMODIDAD_SOFA_DESCANSO
	modo._preview_caja.visible = true
	modo._preview_texto.visible = true
	modo._preview_sprite.visible = false
	modo._colocar_caja(CELDA_ANCLA, HUELLA, modo.COLOR_VALIDO)
	modo._colocar_triangulo_orientacion(CELDA_ANCLA, HUELLA, frente)
	await _verificar_y_capturar(sub, construccion, modo, CELDA_ANCLA, HUELLA, frente, etiqueta)


## La fórmula del ápice, RECALCULADA aquí de forma independiente (mismos primitivos que
## `_colocar_triangulo_orientacion`: celda/huella/frente/consts de margen — nunca un resultado que
## el propio triángulo ya haya escrito).
func _apice_esperado(construccion: Node, modo: Node, celda: Vector2i, huella: Vector2i, frente: Vector2i) -> Vector2:
	var frente_f := Vector2(frente)
	var centro_huella: Vector2 = (Vector2(celda) + Vector2(huella) * 0.5) * float(TAM_CELDA)
	var semiancho: float = (
		(float(huella.x) if frente.x != 0 else float(huella.y)) * 0.5 * float(TAM_CELDA)
	)
	var base_centro: Vector2 = (
		centro_huella + frente_f * (semiancho + modo.MARGEN_TRIANGULO_ORIENTACION)
	)
	var apice_cuadrado: Vector2 = base_centro + frente_f * modo.LARGO_TRIANGULO_ORIENTACION
	return construccion.esquina_en_pantalla(0, 0) + ProyeccionScript.proyectar(apice_cuadrado)


func _verificar_y_capturar(
	sub: SubViewport, construccion: Node, modo: Node,
	celda: Vector2i, huella: Vector2i, frente: Vector2i, etiqueta: String
) -> void:
	var esperado: Vector2 = _apice_esperado(construccion, modo, celda, huella, frente)
	var visible: bool = modo._preview_triangulo.visible
	var puntos: PackedVector2Array = modo._preview_triangulo._puntos
	if not visible or puntos.size() < 3:
		push_error("[DIAG TRIANGULO %s] el triángulo no está visible o no tiene puntos" % etiqueta)
		_veredictos[etiqueta] = false
		sub.queue_free()
		return
	var real: Vector2 = puntos[0]   # el ápice, por convención de `_colocar_triangulo_orientacion`
	var delta: Vector2 = real - esperado
	var pasa: bool = delta.length() <= TOLERANCIA_PX
	print("[DIAG TRIANGULO %s] frente=%s celda=%s huella=%s" % [etiqueta, frente, celda, huella])
	print("[DIAG TRIANGULO %s]   apice: real=%s esperado=%s delta=%s (|%.2f| px)  VEREDICTO: %s" % [
		etiqueta, real, esperado, delta, delta.length(), "PASA" if pasa else "FALLA",
	])
	_veredictos[etiqueta] = pasa
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%striangulo_%s.png" % [CARPETA_SALIDA, etiqueta]
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG TRIANGULO %s] save_png '%s' fallo (error %d)" % [etiqueta, ruta, err])
	else:
		print("[DIAG TRIANGULO %s] -> %s" % [etiqueta, ruta])
	sub.queue_free()
