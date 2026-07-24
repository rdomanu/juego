# Story 006 (epic personal) — nómina efectiva a Economía + persistencia · TR-staff-001 ·
# ADR-0002/0001. Tipo: Integration. DETERMINISTA: RNGService re-sembrado por test; JSON real con
# full_precision (como SaveManager tras el hallazgo del epic Demanda). Economía REAL (saldo 3000,
# knobs por defecto: sin deuda ni préstamos, la nómina es el único gasto).
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal aislado con knobs de ausencia a medida y la dotación de puestos estándar.
func _personal(base_ausencia: float = 0.0, k_salud: float = 0.0) -> Node:
	var config: Resource = ConfigPersonalScript.new()
	config.base_ausencia = base_ausencia
	config.k_salud = k_salud
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(config)
	personal.registrar_puesto(&"doc_1", &"puesto_doc_general")
	personal.registrar_puesto(&"doc_2", &"puesto_doc_general")
	personal.registrar_puesto(&"odac_1", &"puesto_odac")
	return personal


## Economía real con defaults (saldo 3000; sin otros flujos del cierre).
func _economia() -> Node:
	var eco: Node = auto_free(EconomiaScript.new())
	eco.aplicar_config(ConfigEconomiaScript.new())
	return eco


## Mundo A "rico" para los saves: Oficial al mando (doc_1), titular que CAE (doc_2, Salud 1),
## cubridora firme — tras `_al_nuevo_dia` hay baja + cobertura activas (knobs 1.0/0.5).
func _mundo_con_cobertura() -> Node:
	var personal: Node = _personal(1.0, 0.5)
	var oficial: RefCounted = AgenteScript.new(
		"Óscar Delgado", &"ag_doc", AgenteScript.RANGO_OFICIAL, 4, 4, 5, 4, 4
	)
	personal.plantilla.append(oficial)
	personal.asignar(oficial, &"doc_1")
	var titular: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, 1, 3)
	personal.plantilla.append(titular)
	personal.asignar(titular, &"doc_2")
	var cubridora: RefCounted = AgenteScript.new("Lucía Ortega", &"ag_doc", AgenteScript.RANGO_POLICIA, 2, 4, 5, 2)
	personal.plantilla.append(cubridora)
	personal._al_nuevo_dia()
	return personal


# ── AC-PE07: Economía cobra la nómina EFECTIVA (F1), no el salario base del hook ──────────
func test_nomina_efectiva_sustituye_al_hook() -> void:
	# Arrange — el hook provisional TAMBIÉN fijado (130 € base): debe perder contra los efectivos.
	RNGService.sembrar(1)
	var eco: Node = _economia()
	var tipos: Array[StringName] = [&"ag_doc", &"ag_odac"]
	eco.fijar_plantilla(tipos)
	var personal: Node = _personal()
	personal.usar_economia(eco)
	var crack: RefCounted = AgenteScript.new("Lucía Ortega", &"ag_doc", AgenteScript.RANGO_POLICIA, 5, 5, 5, 5)
	var media: RefCounted = AgenteScript.new("Ana Ruiz", &"ag_odac", AgenteScript.RANGO_POLICIA, 3, 3, 3, 3)
	personal.plantilla.append(crack)
	personal.plantilla.append(media)
	personal._actualizar_nomina()

	# Act — el cierre diario de Economía (su prio 20) cobra.
	eco._al_nuevo_dia()

	# Assert — F1: crack 60×1.5=90 · media 70×1.0=70 → 160 efectivos (ni 130 base ni nada más).
	assert_float(personal.salario_dia(crack)).is_equal_approx(90.0, 0.0001)
	assert_float(personal.salario_dia(media)).is_equal_approx(70.0, 0.0001)
	assert_float(eco.saldo_eur).is_equal_approx(2840.0, 0.0001)


# ── PA4/PA6: contratar y despedir re-fijan la nómina (sin coste puntual — Open Q4) ────────
func test_contratar_y_despedir_refijan_nomina() -> void:
	# Arrange — mercado determinista de 1 candidato.
	RNGService.sembrar(7)
	var eco: Node = _economia()
	var personal: Node = _personal()
	personal.usar_economia(eco)
	personal.n_candidatos = 1
	personal.generar_mercado()
	var candidato: RefCounted = personal.mercado[0]
	var salario: float = personal.salario_dia(candidato)

	# Act / Assert 1 — contratar NO cobra (el cobro es del cierre); el cierre descuenta SU salario.
	assert_bool(personal.contratar(0)).is_true()
	assert_float(eco.saldo_eur).is_equal_approx(3000.0, 0.0001)
	eco._al_nuevo_dia()
	assert_float(eco.saldo_eur).is_equal_approx(3000.0 - salario, 0.0001)

	# Act / Assert 2 — despedir deja la nómina a 0: el siguiente cierre no descuenta nada.
	personal.despedir(candidato)
	var saldo_tras: float = eco.saldo_eur
	eco._al_nuevo_dia()
	assert_float(eco.saldo_eur).is_equal_approx(saldo_tras, 0.0001)


# ── AC-PE21 (round-trip): save → JSON real → load — todo idéntico campo a campo ───────────
func test_roundtrip_json_campo_a_campo() -> void:
	# Arrange — mundo A rico (baja + cobertura) + mercado de 2 + refresco a mitad de ciclo.
	RNGService.sembrar(4242)
	var a: Node = _mundo_con_cobertura()
	assert_str(String(a.plantilla[2].estado)).is_equal("cubriendo")   # sanity del fixture
	a.n_candidatos = 2
	a.generar_mercado()
	a._jornadas_desde_refresco = 2

	# Act — por disco imaginario: JSON con full_precision (como SaveManager) y mundo B nuevo.
	var json: String = JSON.stringify(a.save(), "", true, true)
	var b: Node = _personal(1.0, 0.5)
	b.load_state(JSON.parse_string(json))

	# Assert — plantilla campo a campo.
	assert_int(b.plantilla.size()).is_equal(3)
	for i: int in range(3):
		var original: RefCounted = a.plantilla[i]
		var cargado: RefCounted = b.plantilla[i]
		assert_str(cargado.nombre).is_equal(original.nombre)
		assert_str(String(cargado.tipo_id)).is_equal(String(original.tipo_id))
		assert_str(String(cargado.rango)).is_equal(String(original.rango))
		assert_int(cargado.rapidez).is_equal(original.rapidez)
		assert_int(cargado.trato).is_equal(original.trato)
		assert_int(cargado.salud).is_equal(original.salud)
		assert_int(cargado.motivacion).is_equal(original.motivacion)
		assert_int(cargado.mando).is_equal(original.mando)
		assert_str(String(cargado.estado)).is_equal(String(original.estado))
		assert_str(String(cargado.puesto_id)).is_equal(String(original.puesto_id))
	# Mercado y ciclo de refresco.
	assert_int(b.mercado.size()).is_equal(2)
	assert_str(b.mercado[0].nombre).is_equal(a.mercado[0].nombre)
	assert_int(b._jornadas_desde_refresco).is_equal(2)
	# El gate FL4 revive: doc_1 dotado por su Oficial titular; doc_2 por la COBERTURA restaurada.
	assert_bool(b.puesto_dotado(&"doc_1")).is_true()
	assert_bool(b.puesto_dotado(&"doc_2")).is_true()
	assert_object(b.agente_de(&"doc_2")).is_same(b.plantilla[2])


# ── AC-PE21 (determinismo): tras cargar, la historia futura es EXACTAMENTE la misma ───────
func test_determinismo_tras_cargar() -> void:
	# Arrange — Salud variada (prob 0.3-0.7) y 2 días de historia antes de la foto.
	RNGService.sembrar(4242)
	var a: Node = _personal(0.5, 0.1)
	var saludes: Array = [1, 2, 3, 4, 5]
	for i: int in range(5):
		var agente: RefCounted = AgenteScript.new(
			"Agente %d" % i, &"ag_doc", AgenteScript.RANGO_POLICIA, 3, 3, int(saludes[i]), 3
		)
		a.plantilla.append(agente)
	a.n_candidatos = 3
	a._al_nuevo_dia()
	a._al_nuevo_dia()

	# Act — foto (Personal por JSON + RNG) → 3 días más en A vs cargar en B y repetir.
	var foto_personal: Dictionary = JSON.parse_string(JSON.stringify(a.save(), "", true, true))
	var foto_rng: Dictionary = RNGService.save()
	var secuencia_a: Array = _tres_dias(a)
	var b: Node = _personal(0.5, 0.1)
	b.n_candidatos = 3
	b.load_state(foto_personal)
	RNGService.load_state(foto_rng)
	var secuencia_b: Array = _tres_dias(b)

	# Assert — ausencias y mercados idénticos día a día (incluye un refresco de mercado en medio).
	assert_array(secuencia_b).is_equal(secuencia_a)


## 3 días de simulación: por día, [lista de ausentes, nombres del mercado].
func _tres_dias(personal: Node) -> Array:
	var registro: Array = []
	for dia: int in range(3):
		personal._al_nuevo_dia()
		var ausentes: Array = []
		for agente: RefCounted in personal.plantilla:
			if agente.estado == AgenteScript.ESTADO_AUSENTE:
				ausentes.append(agente.nombre)
		var nombres_mercado: Array = []
		for candidato: RefCounted in personal.mercado:
			nombres_mercado.append(candidato.nombre)
		registro.append([ausentes, nombres_mercado])
	return registro


# ── ADR-0002: cargar sitúa, no reproduce — cero señales retroactivas ──────────────────────
func test_carga_sin_senales() -> void:
	# Arrange — un save con baja y cobertura (avisos en potencia) y espías de TODAS las señales.
	RNGService.sembrar(9)
	var a: Node = _mundo_con_cobertura()
	var foto: Dictionary = a.save()
	var b: Node = _personal(1.0, 0.5)
	var bus: Node = auto_free(EventBusScript.new())
	b.usar_bus(bus)
	var emisiones: Array = []
	bus.incidencia_personal.connect(func(_t: String, _p: StringName) -> void: emisiones.append("incidencia"))
	bus.parte_personal.connect(func(_r: Dictionary) -> void: emisiones.append("parte"))

	# Act
	b.load_state(foto)

	# Assert — silencio total, pero el estado SÍ está situado (la baja sigue siendo baja).
	assert_int(emisiones.size()).is_equal(0)
	assert_str(String(b.plantilla[1].estado)).is_equal("ausente")


# ── Id huérfano: el agente corrupto se descarta con log, el save NUNCA se invalida ────────
func test_agente_huerfano_descartado() -> void:
	# Arrange — save a mano con un tipo inexistente (el push_warning es intencional).
	var personal: Node = _personal()
	var foto: Dictionary = {
		"plantilla": [
			{
				"nombre": "Ana Ruiz", "tipo": "ag_doc", "rango": "policia", "rapidez": 3,
				"trato": 3, "salud": 3, "motivacion": 3, "mando": 0, "estado": "libre", "puesto": "",
			},
			{
				"nombre": "Fantasma", "tipo": "ag_inexistente", "rango": "policia", "rapidez": 3,
				"trato": 3, "salud": 3, "motivacion": 3, "mando": 0, "estado": "libre", "puesto": "",
			},
		],
	}

	# Act
	personal.load_state(foto)

	# Assert — el resto de la plantilla carga con normalidad.
	assert_int(personal.plantilla.size()).is_equal(1)
	assert_str(personal.plantilla[0].nombre).is_equal("Ana Ruiz")
