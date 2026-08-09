extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — LOS 4 ENGANCHES VISUALES DEL VIAJE DEL PAPEL
## (GDD impresora-documentos-tramite.md), forzando un trámite CON papel (denuncia ODAC) de punta a
## punta con el mundo real (Construcción + Personal + Flujo + ImpresoraDocumentos + NPCsFlujo) y
## capturando 3 momentos:
##   1) IDA     — el funcionario ya se levantó (FASE_IDA): el muñeco camina hacia la impresora Y la
##                ficha "🖨 a por el documento" ya está en su ventanilla (los dos enganches a la vez).
##   2) RECOGIDA — el muñeco ha llegado a la impresora y se queda quieto ("en_impresora") mientras el
##                modelo cuenta `t_recogida_min`; la ficha sigue en la ventanilla.
##   3) VUELTA  — el modelo ya dice FASE_VUELTA: el muñeco camina de regreso a su mostrador.
##
## El 4º enganche (demolición) NO se fotografía aquí (no hay nada que VER distinto: es un cableado de
## Construcción→ImpresoraDocumentos ya cubierto por el test de integración
## `test_demoler_la_impresora_a_media_atencion_no_deja_el_tramite_colgado`); esta sonda se limita a lo
## que pide la tarea, tres PNG del viaje.
##
## Recetas de fixture calcadas de `tests/integration/impresora/viaje_del_papel_test.gd` (mundo REAL,
## probado) — mismas celdas, mismo trámite con papel. Knobs de la IMPRESORA a sus DEFAULTS de
## producción (aviso 5 min, recogida 1 min, 0,375 celdas/min) a propósito: `Flujo._ready()` se
## auto-suscribe al reloj global `Tiempo` (no hay forma de aislarlo de él en este árbol), así que el
## modelo avanza en tiempo REAL y no por ticks manuales — con los defaults, el tramo de la IDA dura
## más en tiempo real que el paseo visual del muñeco, así que este SIEMPRE llega a la impresora antes
## de que el modelo pase a la vuelta (composición limpia para la foto). Se borra tras usarlo — no es
## parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const ConfigFlujoScript := preload("res://src/core/flujo/config_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const ImpresoraScript := preload("res://src/core/impresora/impresora_documentos.gd")
const ConfigImpresoraScript := preload("res://src/core/impresora/config_impresora.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(900, 560)
const COLUMNAS: int = 14
const FILAS: int = 9
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"

# ── Fixture (calcado de viaje_del_papel_test.gd) ─────────────────────────────────────────────
const SALA_ODAC := &"sala_odac"
const RECT_ODAC := Rect2i(0, 0, 8, 4)
const SALA_ESPERA_ODAC := &"sala_espera_odac"
const RECT_ESPERA_ODAC := Rect2i(0, 5, 4, 3)
const PUESTO_ODAC := &"puesto_odac"
const ID_ODAC := &"odac_1"
const ANCLA_ODAC := Vector2i(1, 1)
const CELDA_IMPRESORA := Vector2i(4, 1)   # 3 celdas de la celda de trabajo -> viaje visible
const DENUNCIA := &"hurto_robo"           # lleva papel (P2: TODAS las denuncias ODAC)
const SERVICIO_ODAC := &"ODAC"
const MINUTO_LLEGADA := 511.0
## Tope de PHYSICS FRAMES reales por espera de fase (~60 s a 60 fps) — solo para que un fallo se vea
## como fallo (bucle cortado) y no como un cuelgue.
const TOPE_FRAMES: int = 3600

var _veredictos: Array[bool] = []


func _ready() -> void:
	# El muñeco anda por PHYSICS FRAMES reales (`_mover_paso` lee `Tiempo.multiplicador_velocidad`
	# del autoload global, NO inyectado) — sin esto el caminante nace pero no se mueve nunca.
	Tiempo.fijar_velocidad(Tiempo.Velocidad.X1)

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
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)

	var personal: Node = PersonalScript.new()
	mundo.add_child(personal)
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.k_cansancio_rendimiento = 0.0

	var construccion: Node = ConstruccionScript.new()
	mundo.add_child(construccion)
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.usar_personal(personal)
	construccion.edificio_columnas = COLUMNAS
	construccion.edificio_filas = FILAS
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	construccion.montar_visual(TAM_CELDA, origen, profundo)
	construccion.levantar_fachada()
	construccion.construir_de_oficio_sala(SALA_ODAC, RECT_ODAC)
	construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_ESPERA_ODAC)
	construccion.construir_de_oficio_elemento(PUESTO_ODAC, ANCLA_ODAC, ID_ODAC)
	construccion.construir_de_oficio_elemento(ImpresoraScript.ID_CATALOGO, CELDA_IMPRESORA)

	var impresora: Node = ImpresoraScript.new()
	mundo.add_child(impresora)
	impresora.aplicar_config(ConfigImpresoraScript.new())   # defaults de producción (ver cabecera)
	impresora.usar_construccion(construccion)

	var flujo: Node = FlujoScript.new()
	mundo.add_child(flujo)
	var config_flujo: Resource = ConfigFlujoScript.new()
	config_flujo.velocidad_camino_celdas_min = 0.0   # aísla el viaje del PAPEL del paseo del ciudadano
	config_flujo.k_equipamiento = 0.0
	flujo.aplicar_config(config_flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(construccion)
	flujo.usar_impresora(impresora)
	flujo.registrar_puesto_flujo(ID_ODAC, PUESTO_ODAC)

	var agente: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_odac", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(agente)
	personal.asignar(agente, ID_ODAC)

	var npcs: Node2D = NPCsFlujoScript.new()
	mundo.add_child(npcs)
	npcs.configurar(flujo, construccion, personal, TAM_CELDA, origen, COLUMNAS, FILAS, profundo)
	npcs.usar_impresora(impresora)
	paredes.configurar(construccion, TAM_CELDA, origen)
	paredes.fijar_modo_altura(&"bajitas")   # muros bajos: que se vea el viaje completo en la foto

	# Deja que la navegación bakee (gotcha de 1er physics frame) antes de admitir a nadie.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var persona: RefCounted = flujo.admitir(PersonaScript.new(SERVICIO_ODAC, DENUNCIA, MINUTO_LLEGADA))
	flujo.encolar(persona)
	npcs.spawn(persona)

	# El modelo avanza SOLO por el reloj real (Flujo ya está suscrito a `Tiempo` desde su `_ready`,
	# más arriba); aquí solo se ESPERA a que cada fase llegue y se deja un pequeño margen de frames
	# para que la animación del muñeco esté asentada antes de disparar el obturador.
	var en_ida: bool = await _esperar_fase(impresora, ImpresoraScript.FASE_IDA)
	print("[DIAG IMPRESORA VIAJE] llegó a FASE_IDA=%s" % en_ida)
	for _i: int in range(60):   # ~1s: el muñeco ya nació y va de camino a la impresora
		await get_tree().physics_frame
	await _capturar(sub, npcs, impresora, "impresora_viaje_1_ida.png", "1_IDA")

	var en_recogida: bool = await _esperar_fase(impresora, ImpresoraScript.FASE_RECOGIDA)
	print("[DIAG IMPRESORA VIAJE] llegó a FASE_RECOGIDA=%s" % en_recogida)
	for _i: int in range(10):   # margen corto: con los defaults el muñeco ya habrá llegado y parado
		await get_tree().physics_frame
	await _capturar(sub, npcs, impresora, "impresora_viaje_2_recogida.png", "2_RECOGIDA")

	var en_vuelta: bool = await _esperar_fase(impresora, ImpresoraScript.FASE_VUELTA)
	print("[DIAG IMPRESORA VIAJE] llegó a FASE_VUELTA=%s" % en_vuelta)
	for _i: int in range(30):   # a medio camino de vuelta, todavía visible andando
		await get_tree().physics_frame
	await _capturar(sub, npcs, impresora, "impresora_viaje_3_vuelta.png", "3_VUELTA")

	var fallos: int = 0
	for v: bool in _veredictos:
		if not v:
			fallos += 1
	print("[DIAG IMPRESORA VIAJE] RESUMEN: %d captura(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


## Espera (en PHYSICS FRAMES reales) a que el puesto ODAC entre en `fase` — el modelo avanza solo,
## empujado por el reloj global `Tiempo` (Flujo ya está suscrito). Corta a `TOPE_FRAMES` para que un
## fallo se vea como fallo y no como un cuelgue; devuelve si se llegó a ver la fase.
func _esperar_fase(impresora: Node, fase: StringName) -> bool:
	for _i: int in range(TOPE_FRAMES):
		if impresora.fase_de(ID_ODAC) == fase:
			return true
		await get_tree().physics_frame
	return false


## Captura un PNG y, con lo que ya se puede leer desde fuera (sin tocar privados: el rótulo de la
## ventanilla y si hay un viaje cosmético vivo), imprime el veredicto de ese momento.
func _capturar(sub: SubViewport, npcs: Node, impresora: Node, archivo: String, etiqueta: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var contenedor: Node2D = npcs._visual_de_puesto.get(ID_ODAC)
	var texto_rotulo: String = contenedor.get_node("Estado").text if contenedor != null else "<sin contenedor>"
	var hay_muneco: bool = npcs._camino_impresora.has(ID_ODAC)
	var fase: StringName = impresora.fase_de(ID_ODAC)
	var retiene: bool = impresora.retiene(ID_ODAC)
	var ok: bool = texto_rotulo == ImpresoraScript.TEXTO_A_POR_EL_DOCUMENTO and retiene
	if etiqueta == "3_VUELTA":
		# En la vuelta el muñeco cosmético puede haber cerrado ya si el modelo tarda más que el
		# paseo (o viceversa) — lo que importa es que el modelo esté en VUELTA (o ya haya cerrado el
		# trámite del todo) y que, si el viaje cosmético sigue vivo, sea justo el de la vuelta.
		ok = fase == ImpresoraScript.FASE_VUELTA or fase == ImpresoraScript.FASE_ENTREGADO or fase == ImpresoraScript.FASE_SIN_VIAJE
	_veredictos.append(ok)
	var ruta: String = CARPETA_SALIDA + archivo
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	print("[DIAG IMPRESORA VIAJE %s] fase=%s retiene=%s rotulo='%s' muneco_vivo=%s save=%d -> %s  VEREDICTO: %s" % [
		etiqueta, fase, retiene, texto_rotulo, hay_muneco, err, ruta, "PASA" if ok else "FALLA"
	])
