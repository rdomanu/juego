# AvisosComisario — el MAPEO señal→aviso (F3, 2026-08-18). Hermano de `avisos_comisario_test.gd`
# (partido por el límite de ~16 KB del escáner de GdUnit4): aquí se audita QUÉ señal del bus produce
# QUÉ toast, con qué severidad y con qué texto REAL — el contrato que documenta la tabla de
# `design/ux/menu-avisos-spec.md` y la cabecera de `design/ux/maquetas-menu-2026-08/maqueta_avisos.py`.
#
# Tipo: Logic/UI. DETERMINISTA — bus FALSO inyectado (mismas señales que `EventBus`), sin reloj real
# y sin tocar ningún sistema Core.
extends GdUnitTestSuite

const AvisosComisarioScript := preload("res://src/ui/avisos_comisario.gd")


## Doble del bus: SOLO las señales que la pila escucha (mismas firmas que `event_bus.gd`) más tres
## de las que NO debe escuchar, para poder probar el silencio.
class BusFalso extends Node:
	signal entro_en_deuda(saldo: float)
	signal salio_de_deuda(saldo: float)
	signal insolvencia(saldo: float, prestamos_restantes: int)
	signal gracia_iniciada(minutos: float)
	signal game_over(motivo: StringName)
	signal reclamacion_generada(origen: StringName)
	signal prestamo_pedido(usados: int, vivos: int)
	signal parte_personal(resumen: Dictionary)
	signal aviso_division(evento_id: StringName, nombre: String, activo: bool)
	signal incidencia_personal(texto: String, puesto: StringName)
	# Las que NO llevan toast (ya se ven en el HUD o son demasiado frecuentes):
	signal cambio_de_turno(turno: int)
	signal saldo_cambiado(nuevo_saldo: float)
	signal nivel_demanda_cambiado(nivel: StringName)


## Doble de Personal: lo justo para traducir "doc_1" → "DNI 1".
class PersonalFalso extends Node:
	func tipo_de_puesto(_puesto_id: StringName) -> StringName:
		return &"puesto_doc_general"

	func servicio_de_puesto(_puesto_id: StringName) -> String:
		return "Documentacion"

	func puestos_de_servicio(_servicio: StringName) -> Array:
		return [&"doc_1", &"doc_2"]


var _bus: Node = null
var _avisos: CanvasLayer = null


func before_test() -> void:
	_bus = auto_free(BusFalso.new())
	add_child(_bus)
	_avisos = auto_free(AvisosComisarioScript.new())
	add_child(_avisos)
	_avisos.configurar(_bus)


func _severidad(indice: int = 0) -> String:
	return String(_avisos._pila.get_child(indice).get_meta("severidad"))


func _titulo(indice: int = 0) -> String:
	var etiqueta: Label = _avisos._pila.get_child(indice).find_child("Titulo", true, false) as Label
	return "" if etiqueta == null else etiqueta.text


func _detalle(indice: int = 0) -> String:
	var etiqueta: Label = _avisos._pila.get_child(indice).find_child("Detalle", true, false) as Label
	return "" if etiqueta == null else etiqueta.text


# ── CRÍTICOS (persistentes) ──────────────────────────────────────────────────────────────────────
func test_entrar_en_deuda_saca_el_critico_de_la_maqueta_con_su_saldo() -> void:
	_bus.entro_en_deuda.emit(-1240.0)
	assert_int(_avisos.avisos_visibles()).is_equal(1)
	assert_str(_severidad()).is_equal("critico")
	assert_str(_titulo()).is_equal("Saldo en números rojos")
	# El dato REAL con el formato de dinero de toda la UI (miles con punto, sin céntimos).
	assert_str(_detalle()).is_equal(
		"-1.240 € · gasto voluntario bloqueado hasta salir de deuda"
	)
	assert_bool(_avisos._pila.get_child(0).get_meta("persistente")).is_true()


func test_la_insolvencia_cuenta_cuantos_salvavidas_quedan() -> void:
	_bus.insolvencia.emit(-2000.0, 2)
	assert_str(_severidad()).is_equal("critico")
	assert_str(_detalle()).is_equal("-2.000 € · te quedan 2 préstamos del Comisario")


func test_la_insolvencia_sin_prestamos_lo_dice_con_palabras() -> void:
	_bus.insolvencia.emit(-2000.0, 0)
	assert_str(_detalle()).is_equal("-2.000 € · no te queda ningún préstamo del Comisario")


func test_la_ventana_de_gracia_cuenta_los_minutos_con_coma_castellana() -> void:
	_bus.gracia_iniciada.emit(22.5)
	assert_str(_severidad()).is_equal("critico")
	assert_str(_titulo()).is_equal("Ventana de gracia en marcha")
	assert_str(_detalle()).is_equal("22,5 min de juego para volver a números negros")


func test_los_minutos_redondos_no_arrastran_decimales() -> void:
	_bus.gracia_iniciada.emit(30.0)
	assert_str(_detalle()).is_equal("30 min de juego para volver a números negros")


func test_el_game_over_traduce_el_motivo_tecnico() -> void:
	_bus.game_over.emit(&"insolvencia")
	assert_str(_severidad()).is_equal("critico")
	assert_str(_titulo()).is_equal("Fin de la partida")
	assert_str(_detalle()).is_equal(
		"Motivo: insolvencia sin salvavidas — te echan de la comisaría"
	)


# ── AVISOS (autodesvanecidos) ────────────────────────────────────────────────────────────────────
func test_salir_de_deuda_es_un_aviso_no_un_critico() -> void:
	_bus.salio_de_deuda.emit(340.0)
	assert_str(_severidad()).is_equal("aviso")
	assert_str(_titulo()).is_equal("De vuelta a números negros")
	assert_str(_detalle()).is_equal("340 € · gasto voluntario desbloqueado")


func test_la_reclamacion_nombra_su_origen_en_castellano() -> void:
	_bus.reclamacion_generada.emit(&"Documentacion")
	assert_str(_severidad()).is_equal("aviso")
	assert_str(_titulo()).is_equal("Nueva reclamación")
	# El texto exacto de la maqueta, con el id técnico del bus ya traducido (con tilde).
	assert_str(_detalle()).is_equal("Documentación · por una espera larga")


func test_un_origen_desconocido_sale_tal_cual_sin_inventarse_nada() -> void:
	_bus.reclamacion_generada.emit(&"Trafico")
	assert_str(_detalle()).is_equal("Trafico · por una espera larga")


func test_el_prestamo_avisa_de_cuantos_salvavidas_quedan() -> void:
	_bus.prestamo_pedido.emit(2, 1)
	assert_str(_severidad()).is_equal("aviso")
	assert_str(_titulo()).is_equal("Préstamo del Comisario concedido")
	assert_str(_detalle()).is_equal("2 pedidos · te queda 1 salvavidas")


func test_el_primer_prestamo_se_dice_en_singular() -> void:
	_bus.prestamo_pedido.emit(1, 2)
	assert_str(_detalle()).is_equal("1 pedido · te quedan 2 salvavidas")


# ── El parte del Oficial: sube de INFO a AVISO si requiere decisión ──────────────────────────────
func test_el_parte_con_bajas_sin_cubrir_sube_a_aviso() -> void:
	_bus.parte_personal.emit({
		"servicio": "Documentación", "ausencias": 3, "cubiertas": 1, "escaladas": 2,
	})
	assert_str(_severidad()).is_equal("aviso")
	assert_str(_titulo()).is_equal("Parte del Oficial · Documentación")
	assert_str(_detalle()).is_equal("3 ausencias · 1 cubiertas · 2 sin cubrir · requiere decisión")


func test_el_parte_todo_cubierto_se_queda_en_info() -> void:
	_bus.parte_personal.emit({
		"servicio": "Documentación", "ausencias": 2, "cubiertas": 2, "escaladas": 0,
	})
	assert_str(_severidad()).is_equal("info")
	assert_str(_detalle()).is_equal("2 ausencias · 2 cubiertas · todo cubierto")


# ── INFO ─────────────────────────────────────────────────────────────────────────────────────────
func test_el_comunicado_de_la_division_es_info_y_dice_que_autoriza() -> void:
	_bus.aviso_division.emit(&"vuelta_al_cole", "Vuelta al cole", true)
	assert_str(_severidad()).is_equal("info")
	assert_str(_titulo()).is_equal("Comunicado de la División")
	assert_str(_detalle()).is_equal(
		"Vuelta al cole · autoriza ampliar el horario más allá del tope ordinario"
	)


func test_al_apagarse_el_comunicado_avisa_de_que_vuelve_el_tope() -> void:
	_bus.aviso_division.emit(&"vuelta_al_cole", "Vuelta al cole", false)
	assert_str(_titulo()).is_equal("Fin del comunicado")
	assert_str(_detalle()).is_equal("Vuelta al cole · vuelve el tope de horario ordinario")


func test_la_incidencia_de_plantilla_nombra_el_puesto_como_el_jugador_lo_ve() -> void:
	var personal: Node = auto_free(PersonalFalso.new())
	add_child(personal)
	_avisos.usar_personal(personal)
	_bus.incidencia_personal.emit("Elena Ortiz se va a descansar (15 min)", &"doc_1")
	assert_str(_severidad()).is_equal("info")
	assert_str(_titulo()).is_equal("Elena Ortiz se va a descansar (15 min)")
	assert_str(_detalle()).is_equal("Deja DNI 1")


func test_sin_personal_inyectado_la_incidencia_sale_con_el_id_tecnico() -> void:
	_bus.incidencia_personal.emit("Carlos Vega no ha venido hoy (baja)", &"doc_2")
	assert_str(_detalle()).is_equal("Deja doc_2")


func test_una_incidencia_sin_puesto_no_pinta_detalle() -> void:
	_bus.incidencia_personal.emit("Carlos Vega no ha venido hoy (baja)", &"")
	assert_str(_detalle()).is_equal("")


# ── Silencio deliberado ──────────────────────────────────────────────────────────────────────────
func test_lo_que_ya_se_ve_en_el_hud_no_genera_ningun_toast() -> void:
	# Turno, saldo y nivel de demanda tienen indicador PERMANENTE en el HUD: un toast por cada uno
	# sería ruido (y el de saldo, varios por minuto).
	_bus.cambio_de_turno.emit(1)
	_bus.saldo_cambiado.emit(1500.0)
	_bus.nivel_demanda_cambiado.emit(&"ALTA")
	assert_int(_avisos.avisos_visibles()).is_equal(0)
	assert_int(_avisos.avisos_en_espera()).is_equal(0)


func test_configurar_dos_veces_no_duplica_el_aviso() -> void:
	_avisos.configurar(_bus)   # segunda llamada: debe ser inofensiva
	_bus.entro_en_deuda.emit(-100.0)
	assert_int(_avisos.avisos_visibles()).is_equal(1)


func test_sin_bus_el_sistema_sigue_vivo_para_la_api_directa() -> void:
	var sueltos: CanvasLayer = auto_free(AvisosComisarioScript.new())
	add_child(sueltos)
	sueltos.configurar(null)
	sueltos.avisar_evento(AvisosComisarioScript.SEV_INFO, "A mano", "")
	assert_int(sueltos.avisos_visibles()).is_equal(1)
