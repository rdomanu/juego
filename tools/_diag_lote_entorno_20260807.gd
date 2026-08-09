extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — lote 2026-08-07: fix de capas del entorno exterior
## (farolas/props CON ALTURA compiten por profundidad con las paredes) + modo diseñador de entorno
## (roundtrip guardar/cargar). Se borra tras usarlo — no es parte del pipeline final.
##
## 4 capturas al scratchpad de la sesión + un juez NUMÉRICO impreso por consola antes de cada foto.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const EntornoExteriorScript := preload("res://src/main/entorno_exterior.gd")
const LucesObjetosScript := preload("res://src/main/luces_objetos.gd")
const ModoDisenadorEntornoScript := preload("res://src/main/modo_disenador_entorno.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
const TAM_RENDER := Vector2i(1000, 700)
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/215a563b-bfbe-4c01-85e5-a766c08242b0/scratchpad/"
const RUTA_SCRATCH_DISENADOR := "user://_diag_entorno_disenado.json"

var _sub: SubViewport
var _camara: Camera2D
var _mundo: Node2D
var _profundo: Node2D
var _entorno: Node
var _luces: Node2D


func _ready() -> void:
	await _montar_escena_base()
	await _caso_capas_dia()
	await _caso_capas_noche()
	await _caso_disenador()
	print("[DIAG LOTE] hecho.")
	get_tree().quit()


func _montar_escena_base() -> void:
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

	_camara = Camera2D.new()
	_sub.add_child(_camara)
	_camara.make_current()

	_mundo = Node2D.new()
	_sub.add_child(_mundo)
	_profundo = Node2D.new()
	_profundo.name = "MundoProfundo"
	_profundo.y_sort_enabled = true
	_mundo.add_child(_profundo)

	var paredes := ParedesSalasScript.new()
	_profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	_mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, _profundo)
	construccion.levantar_fachada()
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))

	# EL FIX DE CAPAS: `_entorno` recibe `_profundo` -- sus props CON ALTURA (farolas incluidas)
	# cuelgan de ÉL, no del fondo puro. Ver `EntornoExterior.configurar`.
	_entorno = EntornoExteriorScript.new()
	_mundo.add_child(_entorno)
	_entorno.configurar(TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, _profundo)

	_luces = LucesObjetosScript.new()
	_mundo.add_child(_luces)
	_luces.configurar(null, null)   # sin Construccion/Tiempo: solo probamos farolas a mano
	_luces.usar_farolas(_entorno.puntos_farolas())


## ── CASO 1 (día): la farola SURESTE del perímetro ((18, FILAS+1), justo al sur de la fachada) --
## el caso EXACTO del bug reportado ("una farola pegada al sur del muro se dibujaba siempre
## detrás") -- encuadrada junto al tramo de fachada sur para que se vea si la tapa o no.
func _caso_capas_dia() -> void:
	var celda_farola := Vector2i(18, FILAS + 1)
	_encuadrar_en(celda_farola)
	# Juez numérico: la farola tiene que estar en la MISMA bolsa y-sort que las paredes (z=0, hija
	# de `_profundo`), NO en el fondo (`Z_CAPA` negativo).
	var decor: Node2D = _profundo.get_node("Decor")
	print("[DIAG LOTE] CASO 1 (capas/día): Decor.z_index=%d (esperado 0) · Decor es hija de MundoProfundo=%s · farolas=%d" % [
		decor.z_index, decor.get_parent() == _profundo, _entorno.puntos_farolas().size()
	])
	var pasa: bool = decor.z_index == 0 and decor.get_parent() == _profundo
	print("[DIAG LOTE] CASO 1: %s" % ("PASA" if pasa else "FALLA"))
	await _capturar("capas_dia_farola_sur.png")


func _caso_capas_noche() -> void:
	for luz: PointLight2D in _luces._luces_farolas:
		luz.energy = 1.0
		luz.visible = true
	print("[DIAG LOTE] CASO 2 (noche): %d farolas encendidas a energy=1.0" % _luces._luces_farolas.size())
	await _capturar("capas_noche_farolas_encendidas.png")


func _encuadrar_en(celda: Vector2i) -> void:
	_camara.zoom = Vector2(1.1, 1.1)
	_camara.position = ProyeccionScript.centro_iso(celda) + Vector2(0.0, -60.0)


## ── MODO DISEÑADOR: coloca 3 piezas + pinta 1 superficie POR CÓDIGO, guarda, crea una instancia
## NUEVA (simula "reabrir el modo") y carga -- compara los diccionarios entero por entero.
func _caso_disenador() -> void:
	if FileAccess.file_exists(RUTA_SCRATCH_DISENADOR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_SCRATCH_DISENADOR))

	var origen: Node2D = ModoDisenadorEntornoScript.new()
	origen.configurar(TAM_CELDA, Vector2.ZERO, _profundo)
	_mundo.add_child(origen)

	origen._fijar_herramienta(&"casa_a")
	origen._orientacion = 90
	origen._colocar_pieza_en(Vector2i(-30, 10))
	origen._fijar_herramienta(&"farola")
	origen._orientacion = 0
	origen._colocar_pieza_en(Vector2i(-26, 10))
	origen._fijar_herramienta(&"coche_sedan")
	origen._orientacion = 90
	origen._colocar_pieza_en(Vector2i(-22, 10))
	origen._fijar_herramienta(&"cesped")
	origen._pintar_o_borrar_en(Vector2i(-30, 12))

	_encuadrar_barrio_disenador()
	await _capturar("disenador_antes_de_guardar.png")

	var ok_guardar: bool = origen.guardar_en_disco(RUTA_SCRATCH_DISENADOR)
	origen.queue_free()
	await get_tree().process_frame

	var destino: Node2D = ModoDisenadorEntornoScript.new()
	destino.configurar(TAM_CELDA, Vector2.ZERO, _profundo)
	_mundo.add_child(destino)
	var ok_cargar: bool = destino.cargar_desde_disco(RUTA_SCRATCH_DISENADOR)

	var piezas_ok: bool = (
		destino._piezas.size() == 3
		and destino._piezas.get(Vector2i(-30, 10), {}).get("id") == &"casa_a"
		and destino._piezas.get(Vector2i(-30, 10), {}).get("rotacion") == 90
		and destino._piezas.get(Vector2i(-26, 10), {}).get("id") == &"farola"
		and destino._piezas.get(Vector2i(-22, 10), {}).get("id") == &"coche_sedan"
	)
	var superficies_ok: bool = (
		destino._superficies.size() == 1
		and destino._superficies.get(Vector2i(-30, 12)) == &"cesped"
	)
	var pasa: bool = ok_guardar and ok_cargar and piezas_ok and superficies_ok
	print("[DIAG LOTE] CASO 3 (roundtrip diseñador): guardar=%s cargar=%s piezas_ok=%s superficies_ok=%s" % [
		ok_guardar, ok_cargar, piezas_ok, superficies_ok
	])
	print("[DIAG LOTE] ROUNDTRIP: %s" % ("PASA" if pasa else "FALLA"))

	await _capturar("disenador_despues_de_recargar.png")
	if FileAccess.file_exists(RUTA_SCRATCH_DISENADOR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_SCRATCH_DISENADOR))


func _encuadrar_barrio_disenador() -> void:
	_camara.zoom = Vector2(0.55, 0.55)
	_camara.position = ProyeccionScript.centro_iso(Vector2i(-26, 11))


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = CARPETA_SALIDA + nombre
	var err: Error = _sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG LOTE] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG LOTE] -> %s" % ruta)
