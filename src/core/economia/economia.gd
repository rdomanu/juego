class_name Economia extends Node
## Economia — la caja de la comisaría (sistema Core; NODO del mundo, NO autoload — arquitectura §3.4).
##
## Story 001 del epic: el núcleo — saldo único (`saldo_eur`, E1), config data-driven (`ConfigEconomia`,
## E8) y los GATES de gasto voluntario (`puede_pagar`/`cobrar`/`abonar`, E4) que usarán Construcción y
## Personal. El saldo SOLO muta por esta API (y por los flujos internos de stories posteriores: ingresos
## DGP, cierre diario, préstamos).
##
## El bus se INYECTA (`usar_bus()`, patrón de tiempo.gd): en runtime se auto-resuelve al autoload
## `EventBus`; los tests pasan su propia instancia (aislamiento). Sin bus no emite (fallback seguro).
##
## Story: production/epics/economia/story-001-nucleo-saldo-gates.md · TR-economy-004 · ADR-0001/0002

## Ruta del config de tuning (generado por tools/build_config_economia.gd; fallback a defaults si falta).
const RUTA_CONFIG := "res://datos/config/economia.tres"
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

## La caja (E1): estado mutable de partida. Arranca en `caja_inicial_eur` al aplicar el config.
var saldo_eur: float = 0.0

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var interes_deuda_diario: float = 0.02
var deuda_max_eur: float = 1000.0
var importe_prestamo_eur: float = 1500.0
var penalizacion_fija_prestamo: float = 30.0
var pct_ingreso_prestamo: float = 0.20
var num_prestamos_max: int = 3
var ventana_gracia_insolvencia_horas: float = 12.0
var umbral_holgura_ui: float = 500.0

## El EventBus al que se emiten los avisos (inyectable; auto-resuelto en _ready). Puede ser null en tests.
var _bus: Node = null

# ── Ingresos (Story 002 · TR-economy-001 · GDD E2/E7, F1/F2) ────────────────────────────────
## Satisfacción de cierre de Documentación de la JORNADA ANTERIOR (0-100), la que alimenta el retorno
## DGP (E7: fija toda la jornada → ingreso estable intra-jornada). PROVISIONAL: arranca en 50
## (= `sat_inicial`, Paciencia #10); cuando exista Paciencia la fijará vía `fijar_sat_cierre()` al
## `nuevo_dia` (prioridad 10, ANTES del cierre de Economía a 20 — ADR-0001).
var sat_cierre_doc: float = 50.0
## Ingresos de Documentación acreditados HOY (F6). Los reinicia el cierre diario (story 003) y los
## muerde la penalización de préstamos (F8, story 004).
var ingreso_doc_dia: float = 0.0

## Cachés del catálogo (se llenan una vez, lazy): params del retorno DGP y tarifas por id de TramiteDoc.
## El dict de tarifas permite distinguir Doc vs ODAC en O(1) SIN llamar `Datos.obtener` con ids de
## denuncia (que haría push_warning por cada denuncia atendida — ruido espurio).
var _retorno_min: float = 0.15
var _retorno_max: float = 0.45
var _tarifas_por_id: Dictionary = {}
var _cache_catalogo_listo: bool = false

# ── Cierre diario (Story 003 · TR-economy-002 · GDD E3/E5/E6, F3/F4/F5/F6) ──────────────────
## Plantilla contratada PROVISIONAL (ids de TipoAgente del catálogo): la fijará Personal en su epic
## (con `salario_dia_efectivo` = base × prima, Personal F1; MVP provisional = salario base). Hook.
var _plantilla: Array[StringName] = []
## Horas extra acumuladas HOY (las registra Horarios/Personal en el futuro; Economía solo el coste E3).
var _horas_extra_dia: float = 0.0
## Coste de la peonada por hora (cacheado del catálogo `costes_global`).
var _peonada_eur_hora: float = 15.0

# ── Préstamos del Comisario (Story 004 · TR-economy-003 · GDD E9, F8) ───────────────────────
## Strikes: préstamos pedidos EN TODA LA PARTIDA (fija el límite y el game over; NUNCA baja — devolver
## no recupera el salvavidas gastado).
var prestamos_usados: int = 0
## Préstamos SIN saldar (0..usados): los que generan la penalización diaria F8.
var prestamos_vivos: int = 0

# ── Estado financiero e insolvencia (Story 005 · TR-economy-003 · GDD E5/E9, States) ────────
## Estados DERIVADOS del saldo (nunca almacenados como verdad; se recalculan al aplicar cada movimiento).
enum EstadoFinanciero { POSITIVO = 0, ROJOS = 1, INSOLVENCIA = 2 }

## Guarda anti-duplicado de transiciones (patrón de los cruces de Tiempo): solo se emite al CAMBIAR.
var _estado_anterior: int = EstadoFinanciero.POSITIVO
## true mientras el modal del Comisario espera la decisión del jugador (juego en pausa).
var _esperando_decision: bool = false
## Ventana de gracia activa (tras rechazar el rescate) y sus minutos de JUEGO restantes.
var en_gracia: bool = false
var gracia_restante_min: float = 0.0
## true tras el game over (la partida terminó; los movimientos dejan de procesar transiciones).
var partida_terminada: bool = false

## El reloj del juego (inyectable; auto-resuelto al autoload `Tiempo` en _ready). Economía lo usa SOLO
## para pausar/reanudar en el rescate (Core → Foundation permitido). Puede ser null en tests.
var _tiempo: Node = null

# ── Ciclo mensual (Story 006 · TR-economy-002 · GDD E6, F7) ─────────────────────────────────
## Acumuladores del mes en curso: ingresos operativos (retorno DGP) y gastos (todo lo del cierre diario,
## recargo y penalizaciones incluidos). Los préstamos (inyección/devolución) son FINANCIACIÓN, no cuentan.
var ingresos_mes: float = 0.0
var gastos_mes: float = 0.0
## Último balance mensual cerrado (F7): `ingresos_mes − gastos_mes`. Lo consumirá Ascensos (futuro).
var balance_mes: float = 0.0


func _ready() -> void:
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	if _tiempo == null:
		_tiempo = get_node_or_null("/root/Tiempo")
	_conectar_bus()
	_cargar_config()
	# Cobro diario y cierre mensual van por el DISPATCHER (orden crítico ADR-0001: nuevo_dia →
	# Paciencia 10 · Economía 20; nuevo_mes → Economía 10 · Paciencia 20 · Demanda 30).
	# Solo en runtime real (árbol); los tests llaman los métodos directos (patrón del proyecto).
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 20, _al_nuevo_dia)
		_bus.registrar_ordenado(&"nuevo_mes", 10, _al_nuevo_mes)
	# Contrato de persistencia (ADR-0002): el SaveManager recoge por el grupo, clave = node.name.
	add_to_group("Persist")


## Inyecta el EventBus (dependency injection → testeable sin el autoload real) y engancha los handlers.
func usar_bus(bus: Node) -> void:
	if _bus != null and _bus.tramite_completado.is_connected(_al_tramite_completado):
		_bus.tramite_completado.disconnect(_al_tramite_completado)
	_bus = bus
	_conectar_bus()


## Conecta los handlers de escucha al bus actual (idempotente; sin bus no hace nada).
func _conectar_bus() -> void:
	if _bus != null and not _bus.tramite_completado.is_connected(_al_tramite_completado):
		_bus.tramite_completado.connect(_al_tramite_completado)


# ── Gates de gasto voluntario (E4 — la API que usan Construcción/Personal) ──────────────────

## ¿Hay caja para un gasto voluntario de `coste`? (E4: nunca te endeudas construyendo/contratando.
## En números rojos —saldo < 0— siempre es false, lo que implementa el bloqueo de E5.)
func puede_pagar(coste: float) -> bool:
	return saldo_eur >= coste and coste >= 0.0


## Gasto VOLUNTARIO: descuenta `coste` solo si pasa el gate. Devuelve si se aplicó. Emite `saldo_cambiado`.
func cobrar(coste: float) -> bool:
	if not puede_pagar(coste):
		return false
	saldo_eur -= coste
	_emitir_saldo()
	return true


## Abona `cantidad` a la caja (ingresos, reembolsos, inyecciones). Emite `saldo_cambiado`.
func abonar(cantidad: float) -> void:
	saldo_eur += cantidad
	_emitir_saldo()


# ── Ingresos: retorno DGP e ingreso instantáneo (Story 002 — F1/F2) ─────────────────────────

## La fórmula del retorno DGP (F1, propiedad de Economía; params del catálogo `costes_global`):
## `retorno = min + (max − min) × clamp(sat, 0, 100) / 100`. Salida siempre en [min, max] (0.15–0.45).
func retorno_dgp(sat: float) -> float:
	_asegurar_cache_catalogo()
	return _retorno_min + (_retorno_max - _retorno_min) * clampf(sat, 0.0, 100.0) / 100.0


## Fija la `sat` de cierre que aplicará el retorno a partir de ahora (la llama Paciencia al nuevo_dia).
func fijar_sat_cierre(sat: float) -> void:
	sat_cierre_doc = sat


## Ingreso INSTANTÁNEO al oír `tramite_completado` (E2, F2): solo los trámites de Documentación
## generan euros (`ingreso = tarifa × retorno_DGP(sat_cierre_doc)`); una DenunciaODAC no está en el
## caché de tarifas → no ingresa (AC-E04) y no dispara warnings del catálogo.
func _al_tramite_completado(tramite_id: StringName, _agente) -> void:
	_asegurar_cache_catalogo()
	if not _tarifas_por_id.has(tramite_id):
		return
	var ingreso: float = float(_tarifas_por_id[tramite_id]) * retorno_dgp(sat_cierre_doc)
	ingreso_doc_dia += ingreso
	ingresos_mes += ingreso
	abonar(ingreso)


## Llena los cachés del catálogo una vez (lazy — el nodo puede usarse sin árbol en tests).
func _asegurar_cache_catalogo() -> void:
	if _cache_catalogo_listo:
		return
	_cache_catalogo_listo = true
	var costes: Resource = Datos.obtener(&"Costes", &"costes_global")
	if costes != null:
		_retorno_min = costes.retorno_dgp_min
		_retorno_max = costes.retorno_dgp_max
	else:
		push_warning("Economia: sin 'costes_global' en el catalogo -> retorno DGP con defaults")
	if costes != null:
		_peonada_eur_hora = costes.peonada_eur_hora
	for tramite: Resource in Datos.obtener_todos(&"TramiteDoc"):
		_tarifas_por_id[tramite.id] = tramite.tarifa_eur


# ── Cierre de cuentas diario (Story 003 — F6: recargo → gastos → reset) ─────────────────────

## Fija la plantilla contratada (PROVISIONAL — hook de Personal; ver var). Los salarios salen del
## catálogo (`TipoAgente.salario_dia_eur`) por id.
func fijar_plantilla(ids: Array[StringName]) -> void:
	_plantilla = ids.duplicate()


## Acumula horas extra del día (F4; quién y cuándo las genera lo posee Horarios/Personal — futuro).
func registrar_horas_extra(horas: float) -> void:
	_horas_extra_dia += maxf(horas, 0.0)


## El cierre de cuentas al `nuevo_dia` (prioridad 20), en el ORDEN DETERMINISTA de F6:
## (1) RECARGO sobre la deuda de APERTURA (antes de los gastos de hoy — así el déficit que crea la
##     nómina de hoy no genera recargo hasta mañana, AC-E09/E10c);
## (2) GASTOS obligatorios (salarios + peonadas + penalización de préstamos) — se descuentan AUNQUE
##     dejen el saldo en negativo (E5: la nómina no pasa por el gate);
## (3) REINICIO de los acumuladores del día.
func _al_nuevo_dia() -> void:
	_asegurar_cache_catalogo()
	# (1) Recargo de deuda (F5) — solo si la APERTURA ya era negativa.
	var recargo: float = 0.0
	if saldo_eur < 0.0:
		recargo = absf(saldo_eur) * interes_deuda_diario
		saldo_eur -= recargo
	# (2) Gastos del día (F3 + F4 + F8) — obligatorios, sin gate.
	var gastos: float = _gasto_salarios_dia() \
		+ _peonada_eur_hora * _horas_extra_dia \
		+ _penalizacion_prestamos_dia()
	saldo_eur -= gastos
	gastos_mes += recargo + gastos
	# (3) Reinicio de acumuladores.
	ingreso_doc_dia = 0.0
	_horas_extra_dia = 0.0
	_emitir_saldo()


## Nómina del día (F3): Σ salario base del catálogo por cada agente de la plantilla. Un id huérfano se
## salta con aviso (tolerancia, patrón Datos).
func _gasto_salarios_dia() -> float:
	var total: float = 0.0
	for id in _plantilla:
		var agente: Resource = Datos.obtener(&"TipoAgente", id)
		if agente == null:
			push_warning("Economia: TipoAgente '%s' no existe -> se salta su salario" % id)
			continue
		total += agente.salario_dia_eur
	return total


# ── Ciclo mensual y persistencia (Story 006 — E6/F7 · ADR-0002) ─────────────────────────────

## Cierre del mes (`nuevo_mes`, prioridad 10): fija el balance F7 y reinicia los acumuladores.
## El balance lo consumirá Ascensos (objetivo de eficiencia — fuera del MVP; aquí solo el número).
func _al_nuevo_mes() -> void:
	balance_mes = ingresos_mes - gastos_mes
	ingresos_mes = 0.0
	gastos_mes = 0.0


## Contrato ADR-0002: SOLO estado no derivado (el estado financiero se deriva del saldo; la plantilla la
## posee Personal —futuro— y la re-fija el arranque). Tipos JSON-safe (floats/ints/bool).
func save() -> Dictionary:
	return {
		"saldo_eur": saldo_eur,
		"prestamos_usados": prestamos_usados,
		"prestamos_vivos": prestamos_vivos,
		"ingreso_doc_dia": ingreso_doc_dia,
		"ingresos_mes": ingresos_mes,
		"gastos_mes": gastos_mes,
		"balance_mes": balance_mes,
		"en_gracia": en_gracia,
		"gracia_restante_min": gracia_restante_min,
		"sat_cierre_doc": sat_cierre_doc,
		"horas_extra_dia": _horas_extra_dia,
	}


## "Cargar sitúa, no reproduce": restaura tal cual, SIN señales ni cobros retroactivos. Clave ausente →
## conserva el valor actual (tolerancia, patrón SaveManager). Sincroniza la guarda de transiciones para
## que el primer movimiento tras cargar no re-emita la entrada en deuda.
func load_state(d: Dictionary) -> void:
	saldo_eur = d.get("saldo_eur", saldo_eur)
	prestamos_usados = d.get("prestamos_usados", prestamos_usados)
	prestamos_vivos = d.get("prestamos_vivos", prestamos_vivos)
	ingreso_doc_dia = d.get("ingreso_doc_dia", ingreso_doc_dia)
	ingresos_mes = d.get("ingresos_mes", ingresos_mes)
	gastos_mes = d.get("gastos_mes", gastos_mes)
	balance_mes = d.get("balance_mes", balance_mes)
	en_gracia = d.get("en_gracia", en_gracia)
	gracia_restante_min = d.get("gracia_restante_min", gracia_restante_min)
	sat_cierre_doc = d.get("sat_cierre_doc", sat_cierre_doc)
	_horas_extra_dia = d.get("horas_extra_dia", _horas_extra_dia)
	_esperando_decision = false
	_estado_anterior = estado()


# ── Préstamos del Comisario (Story 004 — E9/F8) ─────────────────────────────────────────────

## Pide un préstamo al Comisario (E9): inyecta `importe_prestamo_eur` al instante y gasta un STRIKE.
## Permitido también en positivo (uso preventivo — Edge Case del GDD: su decisión y su coste).
## Rechazado si ya se agotaron los strikes (`usados ≥ max`). Emite `prestamo_pedido` + `saldo_cambiado`.
func pedir_prestamo() -> bool:
	if prestamos_usados >= num_prestamos_max:
		return false
	prestamos_usados += 1
	prestamos_vivos += 1
	saldo_eur += importe_prestamo_eur
	# TODO(#16 Presión e Influencia): hook "−valoración de jefes" al pedir (métrica futura, GDD E9).
	if _bus != null:
		_bus.prestamo_pedido.emit(prestamos_usados, prestamos_vivos)
	_emitir_saldo()
	return true


## Salda un préstamo vivo devolviendo el principal (E9): exige caja literal (`saldo ≥ importe`) y algún
## préstamo vivo. `vivos −= 1` (deja de pesar en F8); el strike NO se recupera. Emite `saldo_cambiado`.
func saldar_prestamo() -> bool:
	if prestamos_vivos <= 0 or saldo_eur < importe_prestamo_eur:
		return false
	prestamos_vivos -= 1
	saldo_eur -= importe_prestamo_eur
	_emitir_saldo()
	return true


## Penalización diaria por préstamos vivos (F8): `vivos × (fija + pct × ingreso_doc_dia)`.
## Se evalúa en el paso (2) del cierre, ANTES del reset de `ingreso_doc_dia` (orden F6).
func _penalizacion_prestamos_dia() -> float:
	return prestamos_vivos * (penalizacion_fija_prestamo + pct_ingreso_prestamo * ingreso_doc_dia)


# ── Config (E8 — data-driven, patrón ConfigTiempo) ──────────────────────────────────────────

## Aplica un ConfigEconomia (inyectable en tests, sin tocar disco). Clamp defensivo con aviso: todos los
## knobs ≥ 0 (`num_prestamos_max` entero ≥ 0) — un dato corrupto no rompe la economía (Edge Cases del GDD).
## Fija el saldo inicial en `caja_inicial_eur` (nueva partida; cargar partida lo sobreescribe después).
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigEconomiaScript):
		push_warning("Economia: config invalido -> defaults")
		config = ConfigEconomiaScript.new()
	saldo_eur = _clamp_knob(config.caja_inicial_eur, "caja_inicial_eur")
	interes_deuda_diario = _clamp_knob(config.interes_deuda_diario, "interes_deuda_diario")
	deuda_max_eur = _clamp_knob(config.deuda_max_eur, "deuda_max_eur")
	importe_prestamo_eur = _clamp_knob(config.importe_prestamo_eur, "importe_prestamo_eur")
	penalizacion_fija_prestamo = _clamp_knob(config.penalizacion_fija_prestamo, "penalizacion_fija_prestamo")
	pct_ingreso_prestamo = _clamp_knob(config.pct_ingreso_prestamo, "pct_ingreso_prestamo")
	num_prestamos_max = int(_clamp_knob(float(config.num_prestamos_max), "num_prestamos_max"))
	ventana_gracia_insolvencia_horas = _clamp_knob(
		config.ventana_gracia_insolvencia_horas, "ventana_gracia_insolvencia_horas")
	umbral_holgura_ui = _clamp_knob(config.umbral_holgura_ui, "umbral_holgura_ui")


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Economia: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón Datos/Tiempo).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Economia: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor


## Inyecta el reloj (dependency injection → testeable sin el autoload real). Solo reasigna.
func usar_tiempo(tiempo: Node) -> void:
	_tiempo = tiempo


# ── Estado financiero e insolvencia (Story 005 — E5/E9, States and Transitions) ─────────────

## Estado financiero DERIVADO del saldo (States del GDD): POSITIVO / ROJOS / INSOLVENCIA.
func estado() -> int:
	if saldo_eur >= 0.0:
		return EstadoFinanciero.POSITIVO
	if saldo_eur > -deuda_max_eur:
		return EstadoFinanciero.ROJOS
	return EstadoFinanciero.INSOLVENCIA


## Procesa las transiciones de estado tras CADA movimiento del saldo (único punto — determinismo; nunca
## salto retroactivo). Solo emite al CAMBIAR de estado (guarda anti-duplicado, patrón cruces de Tiempo).
func _procesar_transiciones() -> void:
	if partida_terminada:
		return
	var nuevo: int = estado()
	# Salir del suelo durante la gracia CANCELA el rescate sin gastar préstamo (premia remontar, E9).
	if en_gracia and nuevo != EstadoFinanciero.INSOLVENCIA:
		en_gracia = false
		gracia_restante_min = 0.0
	if nuevo == _estado_anterior:
		return
	var anterior: int = _estado_anterior
	_estado_anterior = nuevo
	match nuevo:
		EstadoFinanciero.ROJOS:
			# Solo al ENTRAR desde positivo (INSOLVENCIA→ROJOS es "volver a rojos", sin re-alarma).
			if anterior == EstadoFinanciero.POSITIVO and _bus != null:
				_bus.entro_en_deuda.emit(saldo_eur)
		EstadoFinanciero.POSITIVO:
			if _bus != null:
				_bus.salio_de_deuda.emit(saldo_eur)
		EstadoFinanciero.INSOLVENCIA:
			_al_cruzar_suelo()


## Al tocar el suelo (`saldo ≤ −deuda_max_eur`, E9): con préstamos → PAUSA + señal `insolvencia` (la UI
## futura muestra el modal; la decisión entra por aceptar/rechazar_rescate). Sin préstamos → GAME OVER.
func _al_cruzar_suelo() -> void:
	_pausar_juego()
	var restantes: int = num_prestamos_max - prestamos_usados
	if restantes <= 0:
		_declarar_game_over()
		return
	_esperando_decision = true
	if _bus != null:
		_bus.insolvencia.emit(saldo_eur, restantes)


## El jugador ACEPTA el rescate del modal: se inyecta el préstamo (con su strike) y el juego se reanuda.
func aceptar_rescate() -> bool:
	if not _esperando_decision:
		return false
	_esperando_decision = false
	var inyectado: bool = pedir_prestamo()
	_reanudar_juego()
	return inyectado


## El jugador RECHAZA el rescate: arranca la ventana de gracia (minutos de JUEGO) y el juego se reanuda
## para intentar remontar por sus medios. Emite `gracia_iniciada`.
func rechazar_rescate() -> bool:
	if not _esperando_decision:
		return false
	_esperando_decision = false
	en_gracia = true
	gracia_restante_min = ventana_gracia_insolvencia_horas * 60.0
	if _bus != null:
		_bus.gracia_iniciada.emit(gracia_restante_min)
	_reanudar_juego()
	return true


## Descuenta la ventana de gracia con el DELTA DE JUEGO (lo enchufa el tick de Tiempo en runtime — la 007
## del epic lo cablea; los tests lo llaman directo). Al expirar aún en el suelo → préstamo AUTOMÁTICO con
## aviso; si ni eso es posible (strikes agotados durante la gracia) → game over.
func avanzar_gracia(delta_min: float) -> void:
	if not en_gracia or partida_terminada:
		return
	gracia_restante_min -= maxf(delta_min, 0.0)
	if gracia_restante_min > 0.0:
		return
	en_gracia = false
	gracia_restante_min = 0.0
	if estado() == EstadoFinanciero.INSOLVENCIA and not pedir_prestamo():
		_declarar_game_over()


## Derrota terminal (E9): te echan de la comisaría. Pausa definitiva + señal `game_over`.
func _declarar_game_over() -> void:
	partida_terminada = true
	_pausar_juego()
	if _bus != null:
		_bus.game_over.emit(&"insolvencia_sin_prestamos")


## Pausa/reanuda el reloj del juego (Core → Foundation permitido). Sin reloj inyectado: no-op (tests).
func _pausar_juego() -> void:
	if _tiempo != null:
		_tiempo.fijar_velocidad(0)


func _reanudar_juego() -> void:
	if _tiempo != null and not partida_terminada:
		_tiempo.reanudar()


## Emite `saldo_cambiado(saldo_eur)` por el bus inyectado (si lo hay) y procesa las transiciones de
## estado (único punto de choque de todo movimiento del saldo).
func _emitir_saldo() -> void:
	if _bus != null:
		_bus.saldo_cambiado.emit(saldo_eur)
	_procesar_transiciones()
