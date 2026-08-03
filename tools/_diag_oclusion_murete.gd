extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — reproduce en el motor, con el código REAL
## (`Construccion` + `ParedesSalas` + `NPCsFlujo`, sin mocks), los DOS casos de la captura del
## usuario (2026-08-03): "lo que está DETRÁS de una pared frontal bajita se dibuja POR ENCIMA".
##
##  (a) VENTANILLA: el mostrador del puesto pegado al borde este/sur de su sala se dibuja por
##      encima del murete frontal (el contenedor "Puesto_X" cuelga de la capa de NPCs, z 2).
##  (b) DISPENSADOR: comodidad de 1 celda en la sala de descanso, tras el muro que la separa de
##      ODAC. Dos variantes: muro COMPARTIDO (salas pegadas) y MURO LIBRE con hueco entre salas.
##
## Cada caso se monta en su propio SubViewport con el MISMO orden de árbol que Main
## (`ParedesSalas` ANTES que `Construccion`, `NPCsFlujo` después) y se guarda un PNG al scratchpad.
## Además IMPRIME el reparto de cada arista (pasada fondo/frente) y el z efectivo de cada pieza:
## la captura dice QUÉ se ve mal, el volcado dice POR QUÉ.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(720, 540)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/75e951ac-fc51-440b-b566-49ccd66ebf86/scratchpad/"

## Sufijo de los PNG de esta pasada ("antes"/"despues"): lo pasa el runner por línea de comandos
## (`-- antes`), para no pisar la captura de referencia al re-capturar tras el arreglo.
var _sufijo: String = "antes"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg != "":
			_sufijo = arg
	await _caso_ventanilla_divisorio()
	await _caso_sofa_paredes()
	await _caso_ventanilla(true)
	await _caso_ventanilla(false)
	await _caso_dispensador(false)
	await _caso_dispensador(true)
	await _caso_divisorio()
	await _caso_general()
	print("[DIAG OCLUSION] hecho (%s) -- ver %soclusion_*_%s.png" % [_sufijo, CARPETA_SALIDA, _sufijo])
	get_tree().quit()


## Un SubViewport montado como lo monta Main: fondo opaco + `ParedesSalas` ANTES que `Construccion`.
## Devuelve [sub, mundo, construccion, paredes].
func _montar(foco: Vector2, zoom: float) -> Array:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	# El fondo va en SU PROPIA CanvasLayer: la cámara transforma la capa 0 entera (incluidas las
	# raíces de canvas de Construcción), y un ColorRect ahí dentro se movería con ella.
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	# ⚠️ ENCUADRE CON CÁMARA, no transformando un Node2D padre: las capas visuales de `Construccion`
	# (`Salas`/`Elementos`) cuelgan de un nodo NO-CanvasItem, así que son RAÍCES de canvas y NO
	# heredan la transformada de ningún padre (mismo gotcha documentado en `npcs_flujo.configurar`).
	# La cámara sí las mueve: actúa sobre la transformada de canvas del viewport entero.
	var camara := Camera2D.new()
	camara.zoom = Vector2(zoom, zoom)
	camara.position = ProyeccionScript.proyectar(foco * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()
	var mundo := Node2D.new()
	sub.add_child(mundo)
	# LA BOLSA DE PROFUNDIDAD, montada como la monta Main (`_mundo_profundo`): paredes + mobiliario +
	# ventanillas ordenados por su Y de base. Sin esto el diagnóstico no reproduciría el juego.
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
	return [sub, mundo, construccion, paredes, profundo]


func _capturar(sub: SubViewport, nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%soclusion_%s_%s.png" % [CARPETA_SALIDA, nombre, _sufijo]
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG OCLUSION] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG OCLUSION] %s -> %s" % [nombre, ruta])
	sub.queue_free()


## Vuelca las paredes ya convertidas en nodos (`TramoPared`): cuántos hay y con qué alturas. Desde el
## paso a y-sort (2026-08-03) ya no hay "pasadas": todos los tramos viven en la misma bolsa, con
## z_index 0, y lo que decide quién tapa a quién es la Y de su punto de orden (su `position`).
func _volcar_paredes(paredes: Node, etiqueta: String) -> void:
	var altos: Dictionary = {}
	for hijo: Node in paredes.get_children():
		var alto: float = float(hijo.get("_alto"))
		altos[alto] = int(altos.get(alto, 0)) + 1
	print("[DIAG %s] paredes: %d tramos, z=%d, altos=%s" % [
		etiqueta, paredes.get_child_count(), (paredes as CanvasItem).z_index, altos
	])


## Vuelca el z EFECTIVO de cada pieza del puesto (z propio + el de sus ancestros con
## `z_as_relative`), que es lo que de verdad compite contra el z de las paredes.
func _volcar_puesto(npcs: Node2D, puesto_id: StringName, etiqueta: String) -> void:
	var contenedor: Node2D = npcs._visual_de_puesto[puesto_id]
	# La POSICIÓN se imprime a propósito (2026-08-03): al mover los contenedores a la bolsa de
	# profundidad hay que poder demostrar que solo cambió el ORDEN de dibujo, jamás dónde está nadie.
	# `global` debe seguir siendo exactamente `Proyeccion.centro_iso(celda)` (+ el origen del suelo).
	print("[DIAG %s] NPCsFlujo z=%d | contenedor z=%d (efectivo %d) padre='%s' local=%s global=%s" % [
		etiqueta, npcs.z_index, contenedor.z_index, _z_efectivo(contenedor),
		contenedor.get_parent().name, contenedor.position, contenedor.global_position,
	])
	for hijo: Node in contenedor.get_children():
		if hijo is CanvasItem:
			print("[DIAG %s]   hijo '%s' z=%d (efectivo %d) capa_iso=%s" % [
				etiqueta, hijo.name, (hijo as CanvasItem).z_index, _z_efectivo(hijo as CanvasItem),
				str(hijo.get_meta(&"capa_iso")) if hijo.has_meta(&"capa_iso") else "-",
			])


func _z_efectivo(item: CanvasItem) -> int:
	var z: int = item.z_index
	var padre: Node = item.get_parent()
	while padre is CanvasItem and item.z_as_relative:
		item = padre as CanvasItem
		z += item.z_index
		padre = item.get_parent()
	return z


## ── CASO 1 (2026-08-03) — EL CASO DEL USUARIO: LA VENTANILLA CONTRA EL MURO DIVISORIO ──────────
## *"coloco una ventanilla pegada al muro divisorio Documentación/ODAC y la mesa se dibuja ENCIMA
## del muro que le debería tapar la base"*. Es el caso que tumbó el arreglo por z globales: con un
## único z por pasada, el divisorio o tapa al mobiliario de las DOS salas o de NINGUNA.
##
## Montaje: Documentación al NORTE (filas 1-4), ODAC al SUR (filas 5-8), pegadas — la arista de la
## fila 5 es el divisorio, y las dos salas con paredes. Dentro se plantan DOS ventanillas para ver
## los dos comportamientos en la MISMA foto:
##
##   · `tie_1`, anclada en (3,4): su MOSTRADOR queda pegado al divisorio por el norte. (La huella
##     2×3 no cabe —la fila del ciudadano caería en ODAC—, así que Construcción la monta en el
##     escalón `HUELLA_SIN_FONDO`: reserva solo el mostrador, pero DIBUJA la ventanilla entera. Es
##     exactamente la situación de la captura del usuario.)
##   · `doc_1`, anclada en (5,3): huella COMPLETA, con su fila de ciudadano pegada al divisorio —
##     el caso legal de "ventanilla lo más al sur posible".
##
## LO QUE DEBE VERSE: el muro divisorio TAPA LA BASE del mostrador de `tie_1` (está delante de él) y
## el muñeco del ciudadano sentado al otro lado se dibuja POR ENCIMA del muro (la gente va en su
## propia capa, z 2). En `doc_1`, el mismo muro le recorta la base a su silla sur y NADA se parte por
## la mitad.
func _caso_ventanilla_divisorio() -> void:
	var piezas: Array = _montar(Vector2(3.6, 4.4), 3.4)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	var profundo: Node2D = piezas[4]
	construccion.levantar_fachada()
	var doc: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 6, 4)
	)
	var odac: StringName = construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(1, 5, 6, 4))
	construccion.fijar_paredes_de_sala(doc, true)
	construccion.fijar_paredes_de_sala(odac, true)
	construccion.construir_de_oficio_elemento(&"puesto_tie", Vector2i(3, 4), &"tie_1")
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(5, 3), &"doc_1")
	print("[DIAG C1] tie_1 nivel_huella=%d (0=completa, 1=solo mostrador) | doc_1 nivel_huella=%d" % [
		construccion.nivel_de_huella(&"tie_1"), construccion.nivel_de_huella(&"doc_1")
	])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var npcs: Node2D = NPCsFlujoScript.new()
	mundo.add_child(npcs)
	npcs.configurar(null, construccion, null, TAM_CELDA, Vector2.ZERO, 24, 13, profundo)
	npcs.set_physics_process(false)
	npcs._asegurar_visual_puesto(&"tie_1", Vector2i(3, 4))
	npcs._actualizar_visual_puesto(&"tie_1", true, "Marta", &"libre", "")
	npcs._asegurar_visual_puesto(&"doc_1", Vector2i(5, 3))
	npcs._actualizar_visual_puesto(&"doc_1", true, "Luis", &"libre", "")
	_plantar_ciudadano_atendido(npcs, Vector2i(3, 5))
	_plantar_ciudadano_atendido(npcs, Vector2i(5, 4))
	_volcar_paredes(paredes, "C1")
	_volcar_puesto(npcs, &"tie_1", "C1")
	await _capturar(sub, "c1_ventanilla_divisorio")


## ── CASO 3 (2026-08-03) — EL SOFÁ CONTRA SUS DOS PAREDES, EN UNA SOLA FOTO ─────────────────────
## Sala de descanso con paredes y un sofá de 2 celdas arrimado por DENTRO a cada uno de los dos lados
## que importan:
##   · contra la pared TRASERA (norte, 34 px): el sofá está DELANTE de ella → se ve entero, la pared
##     hace de fondo. (Era el bug "el sofá se dibuja por debajo de su pared norte".)
##   · contra la pared FRONTAL del perímetro (sur, 17 px): la pared está delante del sofá → le TAPA
##     LA BASE y el mueble se lee dentro del recinto, no sangrando fuera. (Era el bug del sofá que
##     "se salía" por encima del murete.)
## Las dos cosas las decide ahora la MISMA regla (profundidad), no dos capas distintas.
func _caso_sofa_paredes() -> void:
	# Dos fotos del MISMO montaje, una por pared, para que el detalle se vea de cerca (a la escala
	# humana de 2026-08-03 un sofá mide poco más de media celda: en plano general no se juzga nada).
	await _foto_sofa(Vector2(3.6, 2.6), 5.0, "c3a_sofa_pared_trasera")
	await _foto_sofa(Vector2(3.6, 6.6), 5.0, "c3b_sofa_pared_frontal")


func _foto_sofa(foco: Vector2, zoom: float, nombre: String) -> void:
	var piezas: Array = _montar(foco, zoom)
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	var descanso: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(2, 2, 5, 5)
	)
	construccion.fijar_paredes_de_sala(descanso, true)
	for celda: Vector2i in [Vector2i(3, 2), Vector2i(3, 6)]:
		if construccion.construir_de_oficio_elemento(&"sofa_descanso", celda) == &"":
			push_error("[DIAG C3] sofá NO colocado en %s" % celda)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	_volcar_paredes(paredes, nombre)
	await _capturar(sub, nombre)


## (a) La ventanilla del layout REAL con las paredes de la sala ENCENDIDAS (el jugador las pone
## desde la UI: `fijar_paredes_de_sala`). `este` = el caso TIE, puesto en la última columna de
## `sala_documentacion` (su mostrador cae sobre el murete ESTE); si no, puesto en la última fila
## útil (murete SUR justo delante).
func _caso_ventanilla(este: bool) -> void:
	var celda: Vector2i = Vector2i(6, 2) if este else Vector2i(3, 3)
	var foco: Vector2 = Vector2(celda) + Vector2(0.5, 1.0)
	var piezas: Array = _montar(foco, 2.4)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	var profundo: Node2D = piezas[4]
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_documentacion", Rect2i(1, 1, 6, 4)
	)
	construccion.fijar_paredes_de_sala(sala, true)
	var puesto: StringName = construccion.construir_de_oficio_elemento(
		&"puesto_tie", celda, &"tie_1"
	)
	print("[DIAG A-%s] puesto='%s' huella_legado=%s" % [
		"este" if este else "sur", puesto, construccion.es_huella_legado(&"tie_1")
	])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var npcs: Node2D = NPCsFlujoScript.new()
	mundo.add_child(npcs)
	npcs.configurar(null, construccion, null, TAM_CELDA, Vector2.ZERO, 24, 13, profundo)
	npcs.set_physics_process(false)
	npcs._asegurar_visual_puesto(&"tie_1", celda)
	npcs._actualizar_visual_puesto(&"tie_1", true, "Marta", &"libre", "")
	_plantar_ciudadano_atendido(npcs, celda + Vector2i(0, 1))
	_volcar_paredes(paredes, "A-" + ("este" if este else "sur"))
	_volcar_puesto(npcs, &"tie_1", "A-" + ("este" if este else "sur"))
	await _capturar(sub, "a_ventanilla_" + ("este" if este else "sur"))


## (b) Dispensadores de agua en la sala de DESCANSO, tras el muro que la separa de ODAC.
##
## `con_hueco` = false — CONTROL: las dos salas PEGADAS. El muro divisorio es la arista SUR del
##   descanso, y `_cara_de_arista` la ve "cercana" (detrás hay sala) → pasada FRENTE, z 1, bajita.
## `con_hueco` = true — EL CASO DEL BUG: una fila vacía entre las dos salas y ODAC con sus paredes
##   puestas. Su muro NORTE tiene detrás el HUECO (no una sala) → `_cara_de_arista` lo manda a la
##   pasada FONDO (alto completo, z 0), y ahí empata con el mobiliario, que va después en el árbol.
func _caso_dispensador(con_hueco: bool) -> void:
	if con_hueco:
		await _caso_dispensador_cuatro_lados()
		return
	var piezas: Array = _montar(Vector2(4.0, 5.9), 3.6)
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	var rect_descanso := Rect2i(1, 1, 4, 5) if con_hueco else Rect2i(1, 2, 6, 4)
	var descanso: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", rect_descanso
	)
	construccion.fijar_paredes_de_sala(descanso, true)
	# Con hueco: ODAC al ESTE, separada por la columna 5 vacía. Su muro OESTE (columna 6) tiene
	# detrás el hueco, así que `_cara_de_arista` lo manda a FONDO (34 px, z 0).
	var odac: StringName = construccion.construir_de_oficio_sala(
		&"sala_odac", Rect2i(6, 1, 4, 5) if con_hueco else Rect2i(1, 6, 6, 3)
	)
	if con_hueco:
		construccion.fijar_paredes_de_sala(odac, true)
	# Dispensadores pegados por DENTRO del descanso al muro divisorio (columna 4 con hueco; última
	# fila del descanso si las salas están pegadas).
	for i: int in range(1, 5):
		var celda := Vector2i(4, i) if con_hueco else Vector2i(i + 1, 5)
		var id: StringName = construccion.construir_de_oficio_elemento(&"dispensador_agua", celda)
		if id == &"":
			push_error("[DIAG B] dispensador NO colocado en %s" % celda)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var etiqueta: String = "B-" + ("fondo" if con_hueco else "pegado")
	print("[DIAG %s] descanso='%s' rect=%s paredes=%s | odac='%s'" % [
		etiqueta, descanso, construccion.rect_de_sala(descanso),
		construccion.sala_con_paredes(descanso), odac,
	])
	var capa: Node2D = construccion.get_node("Elementos")
	for hijo: Node in capa.get_children():
		if hijo is Node2D and not (hijo is Label):
			print("[DIAG %s]   elemento '%s' pos=%s z_ef=%d" % [
				etiqueta, hijo.name, (hijo as Node2D).position, _z_efectivo(hijo as CanvasItem)
			])
	_volcar_paredes(paredes, etiqueta)
	await _capturar(sub, "b_dispensador_fondo" if con_hueco else "b_dispensador_pegado")


## (b, decisivo) UNA sala de descanso con paredes y un dispensador arrimado por DENTRO a cada uno
## de sus cuatro lados. En una sola imagen se ve, para el MISMO objeto, cómo se comporta contra las
## dos aristas TRASERAS (norte/oeste, pasada FONDO, 34 px, z 0) y contra las dos FRONTALES
## (sur/este, pasada FRENTE, 17 px, z 1). Es el cuadro completo de la "escalera" para una comodidad.
func _caso_dispensador_cuatro_lados() -> void:
	var piezas: Array = _montar(Vector2(4.0, 4.0), 2.2)
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(2, 2, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala, true)
	# Norte (fila 2), sur (fila 6), oeste (col 2), este (col 6) — por DENTRO de la sala.
	for celda: Vector2i in [Vector2i(4, 2), Vector2i(4, 6), Vector2i(2, 4), Vector2i(6, 4)]:
		if construccion.construir_de_oficio_elemento(&"dispensador_agua", celda) == &"":
			push_error("[DIAG B4] dispensador NO colocado en %s" % celda)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	_volcar_paredes(paredes, "B-4lados")
	await _capturar(sub, "b_dispensador_4lados")


## (b, EL CASO DE LA CAPTURA) ODAC al NORTE, Descanso al SUR, PEGADAS. El muro divisorio es la
## arista compartida: `_cara_de_arista` mira lo que hay DETRÁS (al norte) y encuentra ODAC → sala →
## lo clasifica "cercana" → pasada FRENTE (17 px, z 1). Pero ese muro es la pared de ATRÁS de la
## sala de descanso, y los dispensadores de su primera fila están DELANTE de él: al ir la pasada
## frente a z 1 y el mobiliario a z 0, el muro se pinta ENCIMA de ellos.
func _caso_divisorio() -> void:
	var piezas: Array = _montar(Vector2(4.0, 6.2), 3.2)
	var sub: SubViewport = piezas[0]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(2, 2, 5, 4))
	var descanso: StringName = construccion.construir_de_oficio_sala(
		&"sala_descanso", Rect2i(2, 6, 5, 4)
	)
	construccion.fijar_paredes_de_sala(descanso, true)
	for x: int in range(3, 6):
		if construccion.construir_de_oficio_elemento(&"dispensador_agua", Vector2i(x, 6)) == &"":
			push_error("[DIAG B-div] dispensador NO colocado en (%d,6)" % x)
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	_volcar_paredes(paredes, "B-divisorio")
	await _capturar(sub, "b_divisorio")


## Un CIUDADANO siendo atendido en la celda sur del puesto, montado como lo monta el juego:
## muñeco de sprite en la capa global (`registrar_muneco`), marcado "en el frente del puesto"
## (`marcar_frente_de_puesto` → z de estado + arrime) y colocado con `colocar_muneco`. Sirve para
## comprobar en la misma foto las dos reglas ya aprobadas: MESA por debajo de la gente y RESPALDO
## de la silla por encima de quien se sienta.
func _plantar_ciudadano_atendido(npcs: Node2D, celda_sur: Vector2i) -> void:
	var visual := Node2D.new()
	visual.name = "MunecoCiudadano"
	visual.add_child(MunecoScript.construir_sprite_sentado(
		"girl", 44, Vector2(0.0, -1.0)
	))
	visual.set_meta(&"sentado", true)
	npcs.registrar_muneco(visual)
	npcs.marcar_frente_de_puesto(visual, true)
	npcs.colocar_muneco(visual, ProyeccionScript.centro_cuadrado(celda_sur))


## VISTA GENERAL — la comisaría inicial REAL (el trazado de `Main._montar_comisaria_inicial`) con
## las paredes de todas las salas encendidas y sus cuatro ventanillas plantadas. Sirve de red de
## seguridad contra regresiones: en una sola foto se ve la escalera entera (suelo < paredes de
## fondo < mobiliario < muretes < gente) sobre el layout de verdad, no sobre un caso de laboratorio.
func _caso_general() -> void:
	var piezas: Array = _montar(Vector2(7.0, 5.0), 1.0)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	var profundo: Node2D = piezas[4]
	construccion.levantar_fachada()
	var salas: Array[StringName] = []
	salas.append(construccion.construir_de_oficio_sala(&"sala_documentacion", Rect2i(1, 1, 6, 4)))
	salas.append(construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(1, 6, 6, 4)))
	salas.append(construccion.construir_de_oficio_sala(&"sala_odac", Rect2i(9, 1, 4, 3)))
	salas.append(construccion.construir_de_oficio_sala(&"sala_espera_odac", Rect2i(9, 5, 3, 3)))
	for sala: StringName in salas:
		construccion.fijar_paredes_de_sala(sala, true)
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(2, 2), &"doc_1")
	construccion.construir_de_oficio_elemento(&"puesto_doc_general", Vector2i(4, 2), &"doc_2")
	construccion.construir_de_oficio_elemento(&"puesto_tie", Vector2i(6, 2), &"tie_1")
	construccion.construir_de_oficio_elemento(&"puesto_odac", Vector2i(10, 2), &"odac_1")
	for x: int in range(2, 6):
		construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, Vector2i(x, 7))
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var npcs: Node2D = NPCsFlujoScript.new()
	mundo.add_child(npcs)
	npcs.configurar(null, construccion, null, TAM_CELDA, Vector2.ZERO, 24, 13, profundo)
	npcs.set_physics_process(false)
	for par: Array in [
		[&"doc_1", Vector2i(2, 2), "Marta"], [&"doc_2", Vector2i(4, 2), "Luis"],
		[&"tie_1", Vector2i(6, 2), "Ana"], [&"odac_1", Vector2i(10, 2), "Pablo"],
	]:
		npcs._asegurar_visual_puesto(par[0], par[1])
		npcs._actualizar_visual_puesto(par[0], true, par[2], &"libre", "")
		# Prueba de que NADIE se ha movido: la posición del contenedor debe ser, clavada, el centro
		# proyectado de su celda. (`tie_1` sale con mostrador de 1 celda a propósito: en (6,2) no cabe
		# su huella 2×3 y Construcción lo monta en el escalón mínimo — es el layout inicial del juego,
		# no un efecto de este cambio; el aviso lo canta el propio arranque headless.)
		_volcar_puesto(npcs, par[0], "GEN")
		print("[DIAG GEN]   esperado=%s (centro_iso de %s) nivel_huella=%d" % [
			ProyeccionScript.centro_iso(par[1]), par[1], construccion.nivel_de_huella(par[0])
		])
	_plantar_ciudadano_atendido(npcs, Vector2i(6, 3))
	await _capturar(sub, "general")
