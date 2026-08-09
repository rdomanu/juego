extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — CAPAS ODAC: MUÑECOS Y SILLA CONTRA LA MEDIA PARED
## (2026-08-05, bug reportado tras subir ALTO_PARED de 34 a 65 px en dab56de; ampliado el
## 2026-08-06 con el CAMBIO ESTRUCTURAL de "los muñecos andantes entran en la bolsa de y-sort").
##
## Reproduce: sala de espera del servicio ODAC ("sala_espera_odac"), CON PAREDES, con una silla de
## espera pegada por DENTRO a la pared FRONTAL (sur) y DOS muñecos de pie:
##   · DENTRO  (celda 3,5, última fila interior) — debe quedar PARCIALMENTE TAPADO por la media
##     pared: las piernas ocultas, el torso y la cabeza asomando por encima del pretil;
##   · FUERA   (celda 3,6, primera fila ya fuera de la sala) — debe verse ENTERO, por DELANTE de esa
##     misma pared.
## Imprime los NÚMEROS de orden (y-sort) de los tres contra el tramo sur, con veredicto PASA/FALLA
## (±3 px de holgura), y guarda la captura. Se borra tras usarlo (mismo criterio que el resto de
## `tools/_diag_*`).
##
## Plantilla: `tools/_diag_ux_pintura.gd` (SubViewport + save_png). No se monta `ModoConstruccion`
## aquí — no hace falta para este diagnóstico, así que no aplica el gotcha de `set_process(false)`.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const MunecoScript := preload("res://src/main/muneco.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(700, 560)
const COLUMNAS: int = 10
const FILAS: int = 10

const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/3d17fabd-3e64-4077-8e28-18435fc15bba/scratchpad/"

## La sala de espera del servicio ODAC (id de catálogo real, no el despacho): Rect2i(2,2,5,4) ->
## fila interior sur = 5 (rect.end.y - 1 = 6 - 1), gridline sur = 6.
const RECT_SALA := Rect2i(2, 2, 5, 4)
## La SILLA: columna 4 (ni esquina ni borde, para no mezclar el caso con la geometría de una esquina).
const CELDA_SILLA := Vector2i(4, 5)
## Los MUÑECOS: columna 3, para no empatar en Y con la silla (dos piezas en la misma celda tendrían
## el MISMO punto de orden y el desempate lo decidiría el orden de árbol, que aquí no se está
## probando). Dentro = última fila interior; fuera = la primera fila ya al otro lado del muro sur.
const CELDA_MUNECO_DENTRO := Vector2i(3, 5)
const CELDA_MUNECO_FUERA := Vector2i(3, 6)
## Holgura del veredicto numérico (misma que usa el test de regresión).
const TOLERANCIA_PX: float = 3.0

var _sub: SubViewport
var _construccion: Node
var _paredes: Node2D
var _sala_espera: StringName
## La capa de muñecos, montada COMO EN EL JUEGO desde el 2026-08-06: dentro de la bolsa de y-sort
## compartida, con `position = origen` (espejo de `NPCsFlujo._capa_escena`, ver su `configurar`).
var _capa_npcs: Node2D
var _origen: Vector2


func _ready() -> void:
	_montar()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_imprimir_numeros()
	_guardar("capas_odac_despues_estructural.png")
	get_tree().quit()


func _montar() -> void:
	_sub = SubViewport.new()
	_sub.size = TAM_RENDER
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	_sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	var mundo := Node2D.new()
	_sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	_paredes = ParedesSalasScript.new()
	profundo.add_child(_paredes)

	var eco: Node = EconomiaScript.new()
	mundo.add_child(eco)
	eco.aplicar_config(ConfigEconomiaScript.new())
	eco.abonar(500000.0)
	_construccion = ConstruccionScript.new()
	mundo.add_child(_construccion)
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	_construccion.usar_economia(eco)
	_construccion.edificio_columnas = COLUMNAS
	_construccion.edificio_filas = FILAS

	_origen = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(TAM_RENDER))
	_construccion.montar_visual(TAM_CELDA, _origen, profundo)
	_construccion.levantar_fachada()

	_sala_espera = _construccion.construir_de_oficio_sala(&"sala_espera_odac", RECT_SALA)
	_construccion.fijar_paredes_de_sala(_sala_espera, true)

	# LA SILLA: pegada por DENTRO a la pared frontal (sur) de la sala de espera.
	var id_silla: StringName = _construccion.construir_de_oficio_elemento(
		_construccion.ASIENTO_BASICO, CELDA_SILLA
	)
	print("[DIAG CAPAS ODAC] silla construida id=%s en celda=%s" % [id_silla, CELDA_SILLA])

	_paredes.configurar(_construccion, TAM_CELDA, _origen)
	_construccion.fijar_hook_layout(Callable(_paredes, "actualizar"))
	_paredes.actualizar()

	# LOS MUÑECOS. ⚠️ CAMBIO ESTRUCTURAL 2026-08-06: ya NO van en una capa propia de z_index 2 por
	# encima de cualquier pared — cuelgan de la BOLSA de y-sort, con `y_sort_enabled` propio y
	# `position = origen`, exactamente igual que `NPCsFlujo._capa_escena` en el juego. Estáticos a
	# propósito: no hace falta que anden para medir el orden.
	_capa_npcs = Node2D.new()
	_capa_npcs.name = "Escena_stub"
	_capa_npcs.position = _origen
	_capa_npcs.y_sort_enabled = true
	profundo.add_child(_capa_npcs)
	for celda: Vector2i in [CELDA_MUNECO_DENTRO, CELDA_MUNECO_FUERA]:
		var muneco: Node2D = MunecoScript.construir(Color(0.20, 0.21, 0.30), true)
		# `centro_iso` PELADO: la capa ya lleva el origen (mismo criterio que `colocar_muneco`).
		muneco.position = ProyeccionScript.centro_iso(celda)
		_capa_npcs.add_child(muneco)


## Los NÚMEROS: el punto de orden (y-sort) del tramo SUR de la sala contra la silla y los dos
## muñecos. El ojo ilustra, el número juzga.
func _imprimir_numeros() -> void:
	var desplazamiento_y: float = _origen.y
	var orden_tramo_silla: float = _orden_tramo_sur(CELDA_SILLA.x)
	var orden_tramo_munecos: float = _orden_tramo_sur(CELDA_MUNECO_DENTRO.x)
	if is_nan(orden_tramo_silla) or is_nan(orden_tramo_munecos):
		push_error("[DIAG CAPAS ODAC] no se encontro algun tramo sur esperado")
		return

	# La silla: el nodo raíz que crea `_crear_pieza` cuelga de `_construccion._capa_elementos`,
	# posicionado en `Proyeccion.centro_iso(celda_ancla)` (LOCAL a esa capa, que a su vez está en
	# `desplazamiento` — el mismo origen que usan las paredes, así que basta sumarlo para comparar).
	var silla_y_mundo: float = NAN
	for hijo: Node in _construccion._capa_elementos.get_children():
		if hijo is Node2D and (hijo as Node2D).position.is_equal_approx(
			ProyeccionScript.centro_iso(CELDA_SILLA)
		):
			silla_y_mundo = (hijo as Node2D).position.y + desplazamiento_y
			break
	var dentro_y: float = ProyeccionScript.centro_iso(CELDA_MUNECO_DENTRO).y + desplazamiento_y
	var fuera_y: float = ProyeccionScript.centro_iso(CELDA_MUNECO_FUERA).y + desplazamiento_y

	print("[DIAG CAPAS ODAC] ALTO_PARED=%.2f  ALTO_PARED_FRENTE=%.2f"
		% [_paredes.ALTO_PARED, _paredes.ALTO_PARED_FRENTE])
	print("[DIAG CAPAS ODAC] tramo SUR col %d (silla):   orden.y=%.2f"
		% [CELDA_SILLA.x, orden_tramo_silla])
	print("[DIAG CAPAS ODAC] tramo SUR col %d (munecos): orden.y=%.2f"
		% [CELDA_MUNECO_DENTRO.x, orden_tramo_munecos])
	print("[DIAG CAPAS ODAC] silla %s          y_mundo=%.2f" % [CELDA_SILLA, silla_y_mundo])
	print("[DIAG CAPAS ODAC] muneco DENTRO %s  y_mundo=%.2f" % [CELDA_MUNECO_DENTRO, dentro_y])
	print("[DIAG CAPAS ODAC] muneco FUERA  %s  y_mundo=%.2f" % [CELDA_MUNECO_FUERA, fuera_y])

	# Y-sort ASCENDENTE: quien tiene MAYOR y se dibuja DESPUÉS, o sea ENCIMA.
	_veredicto("silla DENTRO tapada por el murete", orden_tramo_silla - silla_y_mundo)
	_veredicto(
		"muneco DENTRO tapado por el murete (piernas ocultas)", orden_tramo_munecos - dentro_y
	)
	_veredicto(
		"muneco FUERA entero por delante del murete", fuera_y - orden_tramo_munecos
	)
	print("[DIAG CAPAS ODAC] capa de munecos: z_index=%d (bolsa y-sort compartida, ya NO z 2)"
		% _capa_npcs.z_index)


## El `orden.y` del tramo sur de la sala en una columna dada (NAN si no está).
func _orden_tramo_sur(columna: int) -> float:
	var clave_esperada: String = "h:%d:%d" % [columna, RECT_SALA.end.y]
	for tramo: Dictionary in _paredes._tramos:
		if tramo.has("clave_modelo") and String(tramo["clave_modelo"]) == clave_esperada:
			return (tramo["orden"] as Vector2).y
	return NAN


## PASA si `margen` (lo que gana el que DEBE quedar encima) supera la tolerancia.
func _veredicto(caso: String, margen: float) -> void:
	var estado: String = "PASA" if margen >= TOLERANCIA_PX else "FALLA"
	print("[DIAG CAPAS ODAC] [%s] %s -> margen %.2f px (min %.2f)"
		% [estado, caso, margen, TOLERANCIA_PX])


func _guardar(nombre: String) -> void:
	var ruta: String = CARPETA_SALIDA + nombre
	var err: Error = _sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG CAPAS ODAC] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG CAPAS ODAC] -> %s" % ruta)
