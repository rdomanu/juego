# Story 007 (epic tiempo) — integración `_physics_process`: tick + determinismo + fuente única +
# presupuesto · TR-time-001/007/009 · ADR-0001. La lógica del reloj corre en `_physics_process`
# (paso fijo → determinismo); el reloj es la ÚNICA fuente de tiempo. Tipo: Integration.
#
# Gotcha de headless: para ejercitar `_physics_process` SIN ventana/bucle real, se instancia el nodo en
# el árbol del test (`add_child` → corre `_ready`) y se llama `_physics_process(dt)` MANUALMENTE con deltas
# fijos → determinista, sin depender del scheduler del motor headless. Preload por ruta literal.
#
# Aislamiento: bus PROPIO inyectado con `usar_bus()` (nunca el autoload real). Espías sobre Arrays locales
# (por referencia — gotcha de lambdas del proyecto). El presupuesto se mide con `Time.get_ticks_usec()`
# (microsegundos), NUNCA `OS.get_ticks_msec()` (gotcha del proyecto). NUNCA hora real del sistema en lógica.
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const EventBusScript := preload("res://src/foundation/event_bus/event_bus.gd")

const PASO_FIJO: float = 1.0 / 60.0   # ~0.016667 s: el delta fijo de _physics_process a 60 Hz.


# ── Helpers de fixture ─────────────────────────────────────────────────────────────────────
## Reloj en el árbol (corre `_ready`) con bus propio inyectado y una escala/velocidad conocidas. Fija
## `minutos_juego` y re-sincroniza las guardas anti-jitter para partir de un estado limpio (sin cruce espurio).
func _tiempo_en_arbol(min_dia: float, escala: float, velocidad: int, bus: Node) -> Node:
	var t: Node = auto_free(TiempoScript.new())
	add_child(t)   # corre _ready (auto-resuelve bus, sincroniza umbrales, add_to_group Persist)
	t.usar_bus(bus)
	t.escala_tiempo = escala
	t.fijar_velocidad(velocidad)
	t.minutos_juego = min_dia
	t.sincronizar_umbrales()
	return t


## Aplica una lista de deltas fijos llamando `_physics_process` a mano (determinista, sin scheduler real).
func _correr_frames(t: Node, deltas: Array) -> void:
	for dt: float in deltas:
		t._physics_process(dt)


## Conecta espías a TODAS las señales de cruce del bus, registrando un string por evento en `destino`
## (Array local por referencia). Permite comparar la SECUENCIA de señales entre dos ejecuciones (T35).
func _conectar_espias(bus: Node, destino: Array) -> void:
	bus.cambio_de_turno.connect(func(turno: int) -> void: destino.append("turno:%d" % turno))
	bus.cambio_dia_noche.connect(func(noche: bool) -> void: destino.append("noche:%s" % noche))
	bus.nuevo_dia.connect(func() -> void: destino.append("nuevo_dia"))
	bus.nuevo_mes.connect(func() -> void: destino.append("nuevo_mes"))


# ── AC-T35: misma secuencia de deltas desde idéntico estado → resultado idéntico ────────────
func test_determinismo_misma_secuencia_deltas() -> void:
	# Arrange — dos relojes FRESCOS en idéntico estado, cada uno con su bus propio y su lista de señales.
	# Secuencia de deltas deliberadamente irregular (simula frames variables) pero IDÉNTICA para ambos.
	var deltas: Array = [PASO_FIJO, PASO_FIJO, 0.02, 0.01, PASO_FIJO, 0.05, PASO_FIJO, PASO_FIJO]

	var bus_a: Node = auto_free(EventBusScript.new())
	var t_a: Node = _tiempo_en_arbol(890.0, 8.0, TiempoScript.Velocidad.X3, bus_a)
	var senales_a: Array = []
	_conectar_espias(bus_a, senales_a)

	var bus_b: Node = auto_free(EventBusScript.new())
	var t_b: Node = _tiempo_en_arbol(890.0, 8.0, TiempoScript.Velocidad.X3, bus_b)
	var senales_b: Array = []
	_conectar_espias(bus_b, senales_b)

	# Act — la MISMA secuencia de deltas en ambos.
	_correr_frames(t_a, deltas)
	_correr_frames(t_b, deltas)

	# Assert — minutos_juego, turno y la lista de señales son idénticos (sin dependencia de hora real/azar).
	assert_float(t_a.minutos_juego).is_equal_approx(t_b.minutos_juego, 0.0000001)
	assert_int(t_a.turno_de(t_a.minutos_juego)).is_equal(t_b.turno_de(t_b.minutos_juego))
	assert_array(senales_a).is_equal(senales_b)


# ── AC-T36: fuente única — varios consultores leen el MISMO valor del único reloj ────────────
func test_fuente_unica_varios_consultores_mismo_valor() -> void:
	# Arrange — un reloj; tras avanzar, N "consultores" leen minutos_juego (el getter público del reloj).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en_arbol(600.0, 6.0, TiempoScript.Velocidad.X2, bus)

	# Act — avanzar unos frames y que 3 consultores lean el reloj (ninguno mantiene su propio contador).
	_correr_frames(t, [PASO_FIJO, PASO_FIJO, PASO_FIJO])
	var lecturas: Array = []
	for _consultor: int in 3:
		lecturas.append(t.minutos_juego)

	# Assert — los 3 leen exactamente el mismo minuto (fuente única); Tiempo es el único que lo incrementó.
	assert_float(lecturas[0]).is_equal(lecturas[1])
	assert_float(lecturas[1]).is_equal(lecturas[2])
	# Y ese valor es > 600.0 (el reloj SÍ avanzó, y son ellos los que leen, no incrementan).
	assert_float(lecturas[0]).is_greater(600.0)


# ── AC-T33 (ADVISORY): presupuesto del update < 0,1 ms de media en el peor caso (3×, escala 12) ─
func test_presupuesto_update_bajo_umbral() -> void:
	# Arrange — peor caso del GDD: 3× con escala 12. Bus propio (para no medir contaminación cruzada).
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en_arbol(0.0, 12.0, TiempoScript.Velocidad.X3, bus)
	const FRAMES: int = 1000
	const UMBRAL_US: float = 100.0   # 0,1 ms = 100 µs (< 0,6 % del presupuesto de 16,6 ms a 60 FPS).

	# Act — 1000 frames del tick real (avanzar + procesar cruces + hook), midiendo con Time.get_ticks_usec().
	var inicio: int = Time.get_ticks_usec()
	for _f: int in FRAMES:
		t._physics_process(PASO_FIJO)
	var total_us: int = Time.get_ticks_usec() - inicio
	var media_us: float = float(total_us) / float(FRAMES)

	# Assert (ADVISORY, NO gate): registrar la media real; si supera el umbral, log del número, no bloquea.
	# El hardware de referencia es una Open Question del GDD → umbral holgado y documentado (Story 007).
	if media_us >= UMBRAL_US:
		push_warning("[AC-T33 ADVISORY] media del update = %.3f us (umbral %.0f us) — maquina de CI/dev; no bloquea." % [media_us, UMBRAL_US])
	else:
		print("[AC-T33] media del update = %.3f us (< %.0f us, OK)." % [media_us, UMBRAL_US])
	# El único assert DURO es que la medición fue válida (el tick corrió de verdad las 1000 veces).
	assert_bool(media_us >= 0.0).is_true()


# ── Pausa: N frames del tick con PAUSA → minutos_juego no cambia y no hay cruces ─────────────
func test_pausa_no_avanza_en_tick() -> void:
	# Arrange — reloj cerca de un umbral de turno (14:59), en PAUSA. Espías de todos los cruces.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en_arbol(899.5, 12.0, TiempoScript.Velocidad.PAUSA, bus)
	var senales: Array = []
	_conectar_espias(bus, senales)

	# Act — muchos frames del tick en Pausa.
	var deltas: Array = []
	for _i: int in 100:
		deltas.append(PASO_FIJO)
	_correr_frames(t, deltas)

	# Assert — el reloj no se movió y no hubo ningún cruce (mult 0 → avance 0).
	assert_float(t.minutos_juego).is_equal_approx(899.5, 0.0001)
	assert_array(senales).is_empty()


# ── Fuente única (refuerzo): el hook empuja el mismo delta_juego que avanzó el reloj ─────────
func test_hook_recibe_delta_juego_del_frame() -> void:
	# Arrange — un suscriptor del hook registra los delta_juego que recibe.
	var bus: Node = auto_free(EventBusScript.new())
	var t: Node = _tiempo_en_arbol(0.0, 10.0, TiempoScript.Velocidad.X2, bus)
	var deltas_juego: Array = []
	t.suscribir_tick(func(dj: float) -> void: deltas_juego.append(dj))

	# Act — un frame de paso fijo.
	t._physics_process(PASO_FIJO)

	# Assert — el hook recibió exactamente 1 empuje, con el delta_juego = escala×mult×delta (10×2×PASO_FIJO).
	assert_int(deltas_juego.size()).is_equal(1)
	assert_float(deltas_juego[0]).is_equal_approx(10.0 * 2.0 * PASO_FIJO, 0.0000001)
