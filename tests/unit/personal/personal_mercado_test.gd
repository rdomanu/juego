# Story 002 (epic personal) — mercado de fichajes F5 + contratar/despedir · TR-staff-001 · ADR-0002.
# Tipo: Logic. DETERMINISTA: cada test re-siembra el autoload RNGService (semilla fija).
# Aislamiento: nodo con .new() sin árbol; Economía REAL inyectada (instancia propia) para el gate E4.
extends GdUnitTestSuite

const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")


# ── Helpers de fixture ───────────────────────────────────────────────────────────────────
## Personal fresco con Economía real inyectada (saldo inicial 3000 del config default de Economía).
## Devuelve [personal, economia].
func _mundo() -> Array:
	var economia: Node = auto_free(EconomiaScript.new())
	economia.aplicar_config(ConfigEconomiaScript.new())
	var personal: Node = auto_free(PersonalScript.new())
	personal.aplicar_config(ConfigPersonalScript.new())
	personal.usar_economia(economia)
	return [personal, economia]


## Codifica un candidato para comparar mercados completos.
func _codificar(personal: Node, candidato: RefCounted) -> String:
	return "%s|%s|%s|%d%d%d%d|%d|%.2f" % [
		candidato.nombre, candidato.tipo_id, candidato.rango, candidato.rapidez, candidato.trato,
		candidato.salud, candidato.motivacion, candidato.mando, personal.salario_dia(candidato),
	]


func _codificar_mercado(personal: Node) -> Array[String]:
	var codigos: Array[String] = []
	for candidato: RefCounted in personal.mercado:
		codigos.append(_codificar(personal, candidato))
	return codigos


# ── AC-PE06: misma semilla → mercado IDÉNTICO (F5 determinista) ───────────────────────────
func test_mercado_determinista_por_semilla() -> void:
	# Arrange / Act — dos generaciones con la misma semilla, en instancias distintas.
	var mundo_a: Array = _mundo()
	RNGService.sembrar(42)
	mundo_a[0].generar_mercado()
	var mercado_a: Array[String] = _codificar_mercado(mundo_a[0])
	var mundo_b: Array = _mundo()
	RNGService.sembrar(42)
	mundo_b[0].generar_mercado()
	var mercado_b: Array[String] = _codificar_mercado(mundo_b[0])

	# Assert — 4 candidatos idénticos campo a campo; con otra semilla, difiere.
	assert_int(mercado_a.size()).is_equal(4)
	assert_array(mercado_b).is_equal(mercado_a)
	RNGService.sembrar(99)
	mundo_b[0].generar_mercado()
	assert_bool(_codificar_mercado(mundo_b[0]) != mercado_a).is_true()


# ── F5: la distribución está sesgada al centro (el 3 abunda; el 1 y el 5 escasean) ────────
func test_sesgo_al_centro() -> void:
	# Arrange — 100 mercados × 4 candidatos × 4 atributos = 1600 tiradas con semilla fija.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	RNGService.sembrar(7)
	var frecuencia: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

	# Act
	for i: int in range(100):
		personal.generar_mercado()
		for candidato: RefCounted in personal.mercado:
			for atributo: int in [candidato.rapidez, candidato.trato, candidato.salud, candidato.motivacion]:
				frecuencia[atributo] = int(frecuencia[atributo]) + 1

	# Assert — triangular: el centro domina a los extremos; todo en [1,5].
	assert_bool(int(frecuencia[3]) > int(frecuencia[1])).is_true()
	assert_bool(int(frecuencia[3]) > int(frecuencia[5])).is_true()
	var total: int = 0
	for valor: int in frecuencia.values():
		total += valor
	assert_int(total).is_equal(1600)


# ── AC-PE05: sin caja, contratar se RECHAZA (gate E4); con caja, entra a plantilla ────────
func test_contratar_con_gate_de_caja() -> void:
	# Arrange — mercado generado; Economía casi sin saldo.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var economia: Node = mundo[1]
	RNGService.sembrar(11)
	personal.generar_mercado()
	economia.saldo_eur = 10.0

	# Act / Assert — rechazado: plantilla vacía y el candidato SIGUE en el mercado.
	assert_bool(personal.contratar(0)).is_false()
	assert_int(personal.plantilla.size()).is_equal(0)
	assert_int(personal.mercado.size()).is_equal(4)

	# Con caja → contratado: sale del mercado, entra libre a plantilla (sin cobro puntual — Open Q4).
	economia.saldo_eur = 3000.0
	assert_bool(personal.contratar(0)).is_true()
	assert_int(personal.plantilla.size()).is_equal(1)
	assert_int(personal.mercado.size()).is_equal(3)
	assert_str(String(personal.plantilla[0].estado)).is_equal("libre")
	assert_float(economia.saldo_eur).is_equal_approx(3000.0, 0.0001)


# ── Edge: mercado agotado = estado válido; índice inválido no revienta ────────────────────
func test_mercado_vacio_es_valido() -> void:
	# Arrange — contratar los 4 candidatos (con caja de sobra).
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	RNGService.sembrar(13)
	personal.generar_mercado()
	for i: int in range(4):
		assert_bool(personal.contratar(0)).is_true()

	# Act / Assert — mercado vacío; contratar de nuevo avisa y devuelve false (sin crash).
	assert_int(personal.mercado.size()).is_equal(0)
	assert_bool(personal.contratar(0)).is_false()
	assert_int(personal.plantilla.size()).is_equal(4)


# ── F5: el mercado se regenera completo por calendario (contratar NO repone el hueco) ─────
func test_refresco_por_calendario() -> void:
	# Arrange — refresco cada 3 jornadas (config default); un hueco por contratación.
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	RNGService.sembrar(21)
	personal.generar_mercado()
	personal.contratar(0)
	var restantes: Array[String] = _codificar_mercado(personal)
	assert_int(restantes.size()).is_equal(3)

	# Act / Assert — 2 medianoches: el hueco NO se repone (mismos 3 candidatos).
	personal._al_nuevo_dia()
	personal._al_nuevo_dia()
	assert_array(_codificar_mercado(personal)).is_equal(restantes)

	# 3ª medianoche → regeneración completa (4 candidatos frescos, contador a cero).
	personal._al_nuevo_dia()
	assert_int(personal.mercado.size()).is_equal(4)
	assert_bool(_codificar_mercado(personal) != restantes).is_true()


# ── PA6: despedir saca de plantilla, limpia su puesto y es gratis (MVP) ───────────────────
func test_despedir_saca_de_plantilla() -> void:
	# Arrange — un contratado con puesto anotado a mano (la asignación real es la story 003).
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	var economia: Node = mundo[1]
	RNGService.sembrar(17)
	personal.generar_mercado()
	personal.contratar(0)
	var agente: RefCounted = personal.plantilla[0]
	agente.puesto_id = &"doc_1"
	agente.estado = AgenteScript.ESTADO_ASIGNADO

	# Act
	personal.despedir(agente)

	# Assert — fuera de plantilla, referencia de puesto limpia, saldo intacto (coste 0).
	assert_int(personal.plantilla.size()).is_equal(0)
	assert_str(String(agente.puesto_id)).is_equal("")
	assert_float(economia.saldo_eur).is_equal_approx(3000.0, 0.0001)
	# Edge: despedir a un desconocido avisa y no rompe.
	personal.despedir(AgenteScript.new("Nadie", &"ag_doc"))
	assert_int(personal.plantilla.size()).is_equal(0)


# ── Edge: banquillo permitido — contratar más agentes que puestos existentes ──────────────
func test_banquillo_permitido() -> void:
	# Arrange / Act — 4 contratados sin ningún puesto registrado (no existen hasta la 003/007).
	var mundo: Array = _mundo()
	var personal: Node = mundo[0]
	RNGService.sembrar(19)
	personal.generar_mercado()
	for i: int in range(4):
		personal.contratar(0)

	# Assert — los 4 en plantilla, todos libres; el único limitador es la nómina.
	assert_int(personal.plantilla.size()).is_equal(4)
	for agente: RefCounted in personal.plantilla:
		assert_str(String(agente.estado)).is_equal("libre")
