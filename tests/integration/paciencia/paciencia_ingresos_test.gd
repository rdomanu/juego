# Story paciencia-005 — la reputación se convierte en DINERO. Tipo: Integration.
# DETERMINISTA: Economía REAL con su catálogo; el sat se fija cerrando jornadas de verdad.
# Cierra el bucle central del juego: atender bien hoy -> cobrar más mañana.
extends GdUnitTestSuite

const PacienciaScript := preload("res://src/feature/paciencia/paciencia.gd")
const ConfigPacienciaScript := preload("res://src/feature/paciencia/config_paciencia.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")


func _mundo() -> Dictionary:
	var economia: Node = auto_free(EconomiaScript.new())
	var paciencia: Node = auto_free(PacienciaScript.new())
	paciencia.aplicar_config(ConfigPacienciaScript.new())
	paciencia.usar_economia(economia)
	return {"economia": economia, "paciencia": paciencia}


## Una visita de Documentación ya terminada, con el "recibo" de espera que corresponda.
func _visita(sistema: Node, atendida: bool, paciencia_al_llamar: float = 100.0) -> RefCounted:
	var persona: RefCounted = PersonaFlujoScript.new(PersonaScript.new(&"Documentacion", &"dni", 480), 1)
	persona.estado = (
		PersonaFlujoScript.ESTADO_RESUELTA if atendida else PersonaFlujoScript.ESTADO_ABANDONANDO
	)
	sistema._paciencia_al_llamar[persona] = paciencia_al_llamar
	return persona


# ── AC-PS14 · El retorno lo fija el sat de AYER y no cambia dentro del día ───────────────
func test_retorno_usa_el_sat_de_ayer_y_no_cambia_intradia() -> void:
	var mundo: Dictionary = _mundo()
	var economia: Node = mundo["economia"]
	var paciencia: Node = mundo["paciencia"]
	# Arranque: sat 50 (sat_inicial) → retorno 0.30, el valor de partida del GDD.
	assert_float(economia.retorno_dgp(economia.sat_cierre_doc)).is_equal_approx(0.30, 0.001)
	# Durante el día de hoy la comisaría va FATAL (todo abandonos)...
	for i: int in 5:
		paciencia.anotar_visita(_visita(paciencia, false))
	# ...y aun así el retorno de HOY sigue siendo el de ayer: el ingreso no baila intradía.
	assert_float(economia.retorno_dgp(economia.sat_cierre_doc)).is_equal_approx(0.30, 0.001)
	# Solo al cerrar la jornada el desastre se cobra: mañana se ingresa al mínimo.
	paciencia.cerrar_jornada()
	assert_float(economia.sat_cierre_doc).is_equal(0.0)
	assert_float(economia.retorno_dgp(economia.sat_cierre_doc)).is_equal_approx(0.15, 0.001)


# ── El bucle completo: atender bien paga ─────────────────────────────────────────────────
func test_atender_bien_hoy_paga_mas_manana() -> void:
	var mundo: Dictionary = _mundo()
	var economia: Node = mundo["economia"]
	var paciencia: Node = mundo["paciencia"]
	# Jornada impecable: atendidos al momento (sin espera) → 80 de media.
	for i: int in 4:
		paciencia.anotar_visita(_visita(paciencia, true))
	paciencia.cerrar_jornada()
	assert_float(economia.sat_cierre_doc).is_equal(80.0)
	# retorno = 0.15 + 0.30 × 0.80 = 0.39 (frente al 0.30 de partida).
	assert_float(economia.retorno_dgp(economia.sat_cierre_doc)).is_equal_approx(0.39, 0.001)


func test_una_jornada_mala_cobra_menos_que_una_buena() -> void:
	var buena: Dictionary = _mundo()
	for i: int in 3:
		buena["paciencia"].anotar_visita(_visita(buena["paciencia"], true))
	buena["paciencia"].cerrar_jornada()
	var mala: Dictionary = _mundo()
	for i: int in 3:
		mala["paciencia"].anotar_visita(_visita(mala["paciencia"], true, 0.0))   # esperaron hasta el límite
	mala["paciencia"].cerrar_jornada()
	var retorno_bueno: float = buena["economia"].retorno_dgp(buena["economia"].sat_cierre_doc)
	var retorno_malo: float = mala["economia"].retorno_dgp(mala["economia"].sat_cierre_doc)
	assert_float(retorno_malo).is_less(retorno_bueno)


# ── Sin Paciencia cableada, Economía sigue funcionando (compatibilidad) ─────────────────
func test_sin_paciencia_economia_mantiene_su_default() -> void:
	var economia: Node = auto_free(EconomiaScript.new())
	assert_float(economia.sat_cierre_doc).is_equal(50.0)
	assert_float(economia.retorno_dgp(economia.sat_cierre_doc)).is_equal_approx(0.30, 0.001)


func test_paciencia_sin_economia_no_peta() -> void:
	var suelta: Node = auto_free(PacienciaScript.new())
	suelta.aplicar_config(ConfigPacienciaScript.new())
	suelta.anotar_visita(_visita(suelta, true))
	suelta.cerrar_jornada()
	assert_float(suelta.sat_cierre_de(&"Documentacion")).is_equal(80.0)
