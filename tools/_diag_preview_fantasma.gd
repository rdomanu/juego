extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — preview fantasma con SPRITE REAL (quick-spec
## 2026-08-04 §4, `src/main/modo_construccion.gd`).
##
## Monta el `ModoConstruccion` REAL sobre una `Construccion` real (sin mocks), fuerza la herramienta
## en la mano y llama directamente a `_refrescar_preview_elemento` (mismo camino que dispara
## `_process` al cambiar de celda/herramienta — se evita el ratón por determinismo del diagnóstico,
## no se sustituye ninguna otra pieza del código). Para cada caso:
##
##   1. Captura PNG del fantasma sobre la sala (scratchpad).
##   2. EL JUEZ ES UN NÚMERO: compara la posición final en pantalla del `Sprite2D` del fantasma
##      (`_preview_sprite.position` + `.offset`, lo que de verdad tiene puesto el nodo) contra la
##      MISMA cuenta que usaría el objeto real al construirse (`Construccion.centro_en_pantalla` +
##      `Proyeccion.delta_ultima_celda` + `AnclajeSprite.ancla_px`, calculada aquí de forma
##      INDEPENDIENTE, no leyendo ningún campo que el propio fantasma ya haya rellenado). Delta =
##      0 px (±tolerancia de coma flotante) es el veredicto.
##
## Casos: comodidad válida (celda dentro de su sala) · comodidad inválida (celda fuera de toda sala,
## fantasma rojo pero SIGUE siendo el sprite real, no la caja) · sofá en las dos rotaciones (H/V,
## confirma que el fantasma gira con R) · puesto (mostrador de 2 celdas, confirma que NO gira con R —
## mismo comportamiento que el objeto ya construido).
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(480, 360)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## "Delta 0 px" con margen de coma flotante (multiplicaciones/divisiones de `AnclajeSprite`), nunca
## de un redondeo real de píxel — si esto llegara a fallar por 1 px de verdad, es un bug, no ruido.
const TOLERANCIA_PX: float = 0.01

var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
	await _caso_comodidad(true)
	await _caso_comodidad(false)
	await _caso_sofa(_orientacion_horizontal())
	await _caso_sofa(_orientacion_vertical())
	await _caso_puesto()
	await _caso_sin_sprite()
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG FANTASMA] RESUMEN: %d test(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


## `Construccion.HORIZONTAL`/`VERTICAL` son 0/1 fijos (ver la cabecera de esa constante) pero se leen
## de una instancia real montada más abajo — aquí solo hace falta el valor para pasarlo a los casos
## que lo necesitan antes de montar nada, así que se usan los literales documentados (0/1), con el
## mismo comentario de advertencia que ya lleva `Construccion.HORIZONTAL` sobre no intercambiarlos.
func _orientacion_horizontal() -> int:
	return 0


func _orientacion_vertical() -> int:
	return 1


## Un `SubViewport` SIN cámara: mismo criterio que `ModoConstruccion` documenta en la cabecera de su
## fantasma ("sin cámara, las coordenadas de mundo y de pantalla coinciden -> puede vivir en la
## CanvasLayer") — con cámara, comparar `_preview_sprite` (CanvasLayer, no la transforma una cámara)
## contra el mundo (que sí) mediría el zoom, no el ancla. Devuelve [sub, mundo, construccion, modo].
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
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	# Origen con margen (40,40): que la sala no quede pegada al borde del encuadre.
	construccion.montar_visual(TAM_CELDA, Vector2(80.0, 80.0))
	var modo := ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)   # inyección ANTES de add_child (regla del fichero)
	sub.add_child(modo)
	# LA CAUSA REAL DEL "BYTE A BYTE IGUAL" (hallazgo del coordinador): este diagnóstico fuerza el
	# estado del fantasma A MANO (sin ratón, por determinismo) y luego `_capturar` hace DOS
	# `await RenderingServer.frame_post_draw` para dejar renderizar a la GPU. Con `modo` vivo en el
	# árbol, su `_process` (ADR-0001) corre en esos frames de espera Y LEE EL RATÓN DE VERDAD —
	# `celda_bajo_cursor()` sobre un `SubViewport` sin puntero propio da una celda arbitraria (la
	# MISMA en todos los casos, porque el origen del suelo es siempre (80,80)), y como
	# `_celda_anterior` sigue en su valor inicial (-999,-999) la guarda de celda lo deja pasar:
	# `_process` REESCRIBE el fantasma que acabo de forzar, con el MISMO resultado espurio en todos
	# los casos — de ahí el "MD5 idéntico" (no es (b): el tinte rojo síse aplicaba; el problema era
	# que ni el válido ni el inválido llegaban a fotografiarse, los tapaba este tercer estado).
	# `set_process(false)`: solo este diagnóstico conduce el fantasma a mano, así que no hace falta
	# que seguir vivo entre frame y frame.
	modo.set_process(false)
	# ARTEFACTO DEL DIAGNÓSTICO, no del juego: `_dialogo_cascada` (`ConfirmationDialog`, un `Window`)
	# se crea sin `popup()` — en la ventana de verdad del juego eso lo deja invisible, pero un
	# `Window` anidado dentro de un `SubViewport` se fuerza a modo EMBEBIDO y Godot lo pinta igual
	# (un icono/marco por defecto en la esquina). Se oculta aquí, a mano, solo para la captura — no
	# toca nada de `modo_construccion.gd`.
	modo._dialogo_cascada.hide()
	return [sub, mundo, construccion, modo]


## EL JUEZ: compara `preview_sprite.position + .offset` contra la MISMA cuenta calculada aquí de
## forma independiente (no lee nada que el propio fantasma ya haya escrito, salvo la textura que
## cargó — el resto son fórmulas propias). `celda` es el ancla; `paso`/`celdas` los que se espera que
## use el fantasma según la herramienta/orientación de ese caso.
func _verificar_ancla(
	construccion: Node, modo: Node, celda: Vector2i, paso: Vector2i, celdas: int, etiqueta: String
) -> void:
	var sprite: Sprite2D = modo._preview_sprite
	if not sprite.visible or sprite.texture == null:
		push_error("[DIAG FANTASMA %s] el fantasma NO es un sprite (sigue siendo la caja)" % etiqueta)
		_veredictos[etiqueta] = false
		return
	var pos_esperada: Vector2 = (
		construccion.centro_en_pantalla(celda) + ProyeccionScript.delta_ultima_celda(paso, celdas)
	)
	var offset_esperado: Vector2 = -AnclajeSpriteScript.ancla_px(sprite.texture, paso, celdas)
	var delta_pos: Vector2 = sprite.position - pos_esperada
	var delta_offset: Vector2 = sprite.offset - offset_esperado
	# El punto que de verdad cae en pantalla es `position + offset` (o `global_position + offset` con
	# la CanvasLayer en el origen, que es el caso aquí): es el que importa para "cae EXACTO".
	var delta_total: Vector2 = (sprite.position + sprite.offset) - (pos_esperada + offset_esperado)
	var pasa: bool = (
		absf(delta_pos.x) <= TOLERANCIA_PX and absf(delta_pos.y) <= TOLERANCIA_PX
		and absf(delta_offset.x) <= TOLERANCIA_PX and absf(delta_offset.y) <= TOLERANCIA_PX
	)
	print("[DIAG FANTASMA %s] celda=%s paso=%s celdas=%d" % [etiqueta, celda, paso, celdas])
	print("[DIAG FANTASMA %s]   position: fantasma=%s esperado=%s delta=%s" % [
		etiqueta, sprite.position, pos_esperada, delta_pos,
	])
	print("[DIAG FANTASMA %s]   offset:   fantasma=%s esperado=%s delta=%s" % [
		etiqueta, sprite.offset, offset_esperado, delta_offset,
	])
	print("[DIAG FANTASMA %s]   DELTA TOTAL (position+offset) = %s (|%.4f| px)  VEREDICTO: %s" % [
		etiqueta, delta_total, delta_total.length(), "PASA" if pasa else "FALLA",
	])
	_veredictos[etiqueta] = pasa


## Este diagnóstico llama a `_refrescar_preview_elemento` DIRECTAMENTE (determinismo: sin ratón que
## mover) en vez de dejar que lo dispare `_process`. Pero `_process` no solo despacha: ANTES pone
## `_preview_caja.visible = true` / `_preview_texto.visible = true` / `_preview_sprite.visible =
## false` (el reseteo del que depende la caja para encenderse en el camino SIN sprite — ver la
## cabecera de esa asignación en `modo_construccion.gd`). Sin repetir aquí ese mismo reseteo, el
## caso de control (comodidad sin sprite) saldría con la caja apagada por saltarse ese paso, no por
## ningún bug del código bajo prueba — lo que este diagnóstico haría sería mentir sobre dónde está
## el fallo. Se llama justo antes de cada `_refrescar_preview_elemento` de este fichero.
func _simular_guard_process(modo: Node) -> void:
	modo._preview_caja.visible = true
	modo._preview_texto.visible = true
	modo._preview_sprite.visible = false
	# NO se llama a `_actualizar_visibilidad()`: además de refrescar el rótulo de la barra, ENCIENDE
	# la fila entera de herramientas (`_fila_herramientas.visible = true`), que con ~15 botones más
	# la paleta tapa el encuadre entero de este diagnóstico (pensado para mirar el fantasma, no la
	# barra). Se apaga a mano solo lo que hace falta ver: el atenuador (fondo) y el propio fantasma.
	modo._atenuador.visible = true


## `modo` (opcional): si se pasa, se muestrea el PÍXEL DE VERDAD del fantasma (el centro de su caja
## de textura en pantalla) ANTES de guardar/liberar — la única forma honesta de demostrar que algo
## se dibujó donde se dice, en vez de fiarse de mirar el PNG a ojo (que ya nos ha engañado una vez:
## dos capturas iguales byte a byte no se detectan mirándolas por encima si las dos están vacías).
func _capturar(sub: SubViewport, nombre: String, modo: Node = null) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sub.get_texture().get_image()
	if modo != null and modo._preview_sprite.visible and modo._preview_sprite.texture != null:
		var sprite: Sprite2D = modo._preview_sprite
		var centro: Vector2 = (
			sprite.position + sprite.offset + Vector2(sprite.texture.get_size()) * 0.5
		)
		var px := Vector2i(centro.round())
		if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height():
			print("[DIAG FANTASMA] %s: pixel en el CENTRO del fantasma %s = %s" % [
				nombre, px, img.get_pixel(px.x, px.y)
			])
		else:
			print("[DIAG FANTASMA] %s: el centro del fantasma %s cae FUERA del encuadre %dx%d" % [
				nombre, px, img.get_width(), img.get_height()
			])
	var ruta: String = "%s%s.png" % [CARPETA_SALIDA, nombre]
	var err: Error = img.save_png(ruta)
	if err != OK:
		push_error("[DIAG FANTASMA] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG FANTASMA] %s -> %s" % [nombre, ruta])
	sub.queue_free()


## CASO comodidad (`equipo_informatico`, sprite de 1 celda): `valida` = true la coloca DENTRO de
## `sala_documentacion` (familia "funcionario" → sala tipo "oficina", ver `equipo_informatico.tres`);
## false la deja fuera de toda sala (`sala_en` = "" → `validar_elemento` = false). En los DOS casos
## el fantasma debe seguir siendo el SPRITE real (solo cambia el tinte) — es justo lo que exige la
## tarea: "tinte verde-blanco si válido, ROJO si no", nunca "caja si inválido".
func _caso_comodidad(valida: bool) -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var modo: Node = piezas[3]
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala, false)
	# INVÁLIDA A LA VISTA (corregido — antes (20,20) caía en pantalla=(80,900), fuera del encuadre de
	# 360 px de alto: la captura "inválida" no fotografiaba nada nuevo y por eso salió BYTE A BYTE
	# IGUAL que la válida — dos fotos del mismo "aquí no hay nada", no del fantasma en dos estados).
	# (7,2): misma fila, tres columnas al ESTE del borde de la sala (columnas 1-5) — sigue siendo
	# "fuera de toda sala" (`sala_en` = "") y su proyección cae bien dentro del lienzo.
	var celda: Vector2i = Vector2i(2, 2) if valida else Vector2i(7, 2)
	modo._activo = true
	modo._es_sala = false
	modo._herramienta = &"equipo_informatico"
	modo._orientacion = _orientacion_horizontal()
	_simular_guard_process(modo)
	modo._refrescar_preview_elemento(celda)
	var etiqueta: String = "comodidad_" + ("valida" if valida else "invalida")
	var esperado_valido: bool = construccion.validar_elemento(&"equipo_informatico", celda, &"", 0)
	if esperado_valido != valida:
		push_error(
			"[DIAG FANTASMA %s] el montaje del caso no dio la validez esperada (valido=%s)"
			% [etiqueta, esperado_valido]
		)
	var tinte_esperado: Color = (
		modo.TINTE_FANTASMA_VALIDO if valida else modo.TINTE_FANTASMA_INVALIDO
	)
	var tinte_ok: bool = modo._preview_sprite.modulate.is_equal_approx(tinte_esperado)
	var caja_apagada: bool = not modo._preview_caja.visible
	print("[DIAG FANTASMA %s] validar_elemento=%s modulate=%s (esperado=%s, ok=%s) caja.visible=%s" % [
		etiqueta, esperado_valido, modo._preview_sprite.modulate, tinte_esperado, tinte_ok,
		modo._preview_caja.visible,
	])
	_veredictos[etiqueta + "_tinte_y_caja"] = tinte_ok and caja_apagada
	_verificar_ancla(construccion, modo, celda, Vector2i(1, 0), 1, etiqueta)
	await _capturar(sub, "preview_" + etiqueta, modo)


## CASO sofá (`sofa_descanso`, sprite de 2 celdas, DOS rotaciones): confirma que el fantasma sigue el
## eje que marca la orientación en mano (tecla R) — el mismo eje que `Construccion` va a reservar.
func _caso_sofa(orientacion: int) -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var modo: Node = piezas[3]
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(1, 1, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala, false)
	var celda := Vector2i(2, 2)
	modo._activo = true
	modo._es_sala = false
	modo._herramienta = construccion.COMODIDAD_SOFA_DESCANSO
	modo._orientacion = orientacion
	_simular_guard_process(modo)
	modo._refrescar_preview_elemento(celda)
	var paso: Vector2i = Vector2i(0, 1) if orientacion == construccion.VERTICAL else Vector2i(1, 0)
	var etiqueta: String = "sofa_" + ("vertical" if orientacion == construccion.VERTICAL else "horizontal")
	_verificar_ancla(construccion, modo, celda, paso, 2, etiqueta)
	await _capturar(sub, "preview_" + etiqueta, modo)


## CASO puesto (`puesto_doc_general`, mostrador de 2 celdas): a propósito con `_orientacion =
## VERTICAL` para demostrar que el fantasma NO gira el mostrador (paso fijo este, `Vector2i(1,0)`) —
## mismo comportamiento que `MesaAtencion.construir`, que nunca recibe la orientación del elemento.
func _caso_puesto() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var modo: Node = piezas[3]
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 6, 5)
	)
	construccion.fijar_paredes_de_sala(sala, false)
	var celda := Vector2i(2, 2)
	modo._activo = true
	modo._es_sala = false
	modo._herramienta = &"puesto_doc_general"
	modo._orientacion = construccion.VERTICAL
	_simular_guard_process(modo)
	modo._refrescar_preview_elemento(celda)
	_verificar_ancla(construccion, modo, celda, Vector2i(1, 0), 2, "puesto_mostrador")
	await _capturar(sub, "preview_puesto", modo)


## CONTROL NEGATIVO: una comodidad SIN sprite propio (`revistero`, una de las 12 cajas grises) debe
## seguir mostrando la caja de siempre — ni un cambio de comportamiento para ella. Sin captura (no
## hay nada nuevo que fotografiar); solo el veredicto.
func _caso_sin_sprite() -> void:
	var piezas: Array = _montar()
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var modo: Node = piezas[3]
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala, false)
	modo._activo = true
	modo._es_sala = false
	modo._herramienta = &"revistero"
	modo._orientacion = _orientacion_horizontal()
	_simular_guard_process(modo)
	modo._refrescar_preview_elemento(Vector2i(2, 2))
	var sigue_siendo_caja: bool = modo._preview_caja.visible and not modo._preview_sprite.visible
	print("[DIAG FANTASMA revistero_sin_sprite] caja.visible=%s sprite.visible=%s -> %s" % [
		modo._preview_caja.visible, modo._preview_sprite.visible,
		"PASA" if sigue_siendo_caja else "FALLA",
	])
	_veredictos["revistero_sigue_caja"] = sigue_siendo_caja
	sub.queue_free()
