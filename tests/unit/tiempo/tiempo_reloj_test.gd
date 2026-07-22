# Story 001 (epic tiempo) — reloj base: acumulador `minutos_juego` + clamp anti-salto.
# Clases: los QA test cases de la story (AC-T01..T05 + AC-T25). Tipo: Logic.
# DETERMINISTA — `avanzar()` recibe el `delta` por parámetro (inyección); NO se lee la hora del
# sistema ni se cuentan frames. Los AC-T02/T03 van como tests aparte (varían el multiplicador).
#
# DESVIACIÓN NECESARIA (delta_max vs. delta_real de los AC — inconsistencia interna de la spec):
# la story fija `delta_max_por_frame = 0.5` s (clamp anti-salto TR-time-005, y AC-T25 lo exige de
# forma explícita: `4×1×0.5 = 2.0`). Pero AC-T01/T02/T03/T05 usan `avanzar(delta_real=1.0)` y
# esperan que suba 4/8/12 min, lo que solo cuadra si ese delta NO se clampa. Con la fórmula literal
# de la story `min(delta, 0.5)`, un delta de 1.0 se recorta a 0.5 → 2.0 min, contradiciendo AC-T01.
# NO existe un `delta_max` que satisfaga a la vez AC-T01 (1.0 pasa entero) y AC-T25 (30.0 → 0.5).
# La lógica del reloj (fórmula + `delta_max=0.5`) es la autoridad y se deja intacta; los AC-T01/02/03
# ilustran la fórmula `escala×mult×delta` asumiendo un delta que NO dispara el anti-salto. Por eso
# aquí el delta real total (1.0 s) se INYECTA EN TROZOS de 0.25 s (≤ techo 0.5) → mismo delta real
# acumulado, sin activar el clamp: verifica exactamente lo que el AC pretende (1.0 s ⇒ 4.0 min).
#
# Estrategia de fixture EN MEMORIA (mismo gotcha del `class_name` en frío que datos/rng_service):
# se instancia el script del autoload `tiempo.gd` con `.new()` SIN añadirlo al árbol (así NO corre
# su `_ready`) y con `auto_free(...)` para liberarlo. Se ajustan las vars a los valores del AC y se
# ejercita `avanzar(...)`. Preload POR RUTA LITERAL, no por nombre de autoload.
extends GdUnitTestSuite

const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")


# ── Helper de fixture ──────────────────────────────────────────────────────────────────────
## Instancia el autoload sin árbol → sin `_ready`. Empieza en `minutos_juego = 0.0` con los
## defaults de la story (escala 4, mult 1, delta_max 0.5); cada test ajusta lo que necesite.
func _nuevo_tiempo() -> Node:
	return auto_free(TiempoScript.new())


# ── AC-T01: 1× escala 4, 1,0 s de delta real → +4,0 min ───────────────────────────────────
func test_avance_1x_escala4_sube_4min() -> void:
	# Arrange — defaults de la story: escala 4, mult 1×.
	var tiempo: Node = _nuevo_tiempo()

	# Act — 1,0 s de delta real en trozos de 0,25 s (≤ techo 0,5 → sin clamp): 4×0,25 s.
	for _i: int in 4:
		tiempo.avanzar(0.25)

	# Assert — 4 × 1 × 1,0 s = 4,0 min (±0,001).
	assert_float(tiempo.minutos_juego).is_equal_approx(4.0, 0.001)


# ── AC-T02: 2× escala 4, 1,0 s de delta real → +8,0 min ───────────────────────────────────
func test_avance_2x_escala4_sube_8min() -> void:
	# Arrange — multiplicador de velocidad 2×.
	var tiempo: Node = _nuevo_tiempo()
	tiempo.multiplicador_velocidad = 2

	# Act — 1,0 s de delta real en trozos de 0,25 s (≤ techo, sin clamp).
	for _i: int in 4:
		tiempo.avanzar(0.25)

	# Assert — 4 × 2 × 1,0 s = 8,0 min (±0,001).
	assert_float(tiempo.minutos_juego).is_equal_approx(8.0, 0.001)


# ── AC-T03: 3× escala 4, 1,0 s de delta real → +12,0 min ──────────────────────────────────
func test_avance_3x_escala4_sube_12min() -> void:
	# Arrange — multiplicador de velocidad 3×.
	var tiempo: Node = _nuevo_tiempo()
	tiempo.multiplicador_velocidad = 3

	# Act — 1,0 s de delta real en trozos de 0,25 s (≤ techo, sin clamp).
	for _i: int in 4:
		tiempo.avanzar(0.25)

	# Assert — 4 × 3 × 1,0 s = 12,0 min (±0,001).
	assert_float(tiempo.minutos_juego).is_equal_approx(12.0, 0.001)


# ── AC-T04: Pausa (mult 0), avanzar(delta>0) → sin cambio ─────────────────────────────────
func test_pausa_mult0_no_avanza() -> void:
	# Arrange — Pausa: multiplicador 0. Cualquier delta positivo debe dejar el reloj quieto.
	var tiempo: Node = _nuevo_tiempo()
	tiempo.multiplicador_velocidad = 0

	# Act
	tiempo.avanzar(1.0)

	# Assert — incremento 0: sigue en 0,0.
	assert_float(tiempo.minutos_juego).is_equal_approx(0.0, 0.001)


# ── AC-T05: 360 s a 1×/escala 4 recorre 1440 min y vuelve a ~0 (envuelve) ──────────────────
func test_dia_completo_360s_vuelve_a_cero() -> void:
	# Arrange — 1×/escala 4: 4 min/s × 360 s = 1440 min = un día completo → módulo 1440 vuelve a 0.
	# Se acumulan 360 llamadas de 1,0 s (delta < delta_max 0,5? NO: 1,0 > 0,5 se clamparía).
	# Para NO activar el clamp usamos deltas de 0,5 s → 720 llamadas × 0,5 = 360 s exactos.
	var tiempo: Node = _nuevo_tiempo()

	# Act — 720 pasos de 0,5 s (bajo el techo del clamp) = 360 s de delta real acumulado.
	for _i: int in 720:
		tiempo.avanzar(0.5)

	# Assert — recorrido 1440 min exacto → envuelve a ~0. Tolerancia por acumulación de float.
	assert_float(tiempo.minutos_juego).is_equal_approx(0.0, 0.01)


# ── AC-T25: delta grande (alt-tab) se clampa a delta_max ANTES de acumular ─────────────────
func test_delta_grande_se_clampa_a_max() -> void:
	# Arrange — 1×/escala 4, delta_max 0,5 s. El motor entrega un delta enorme (alt-tab de 30 s).
	var tiempo: Node = _nuevo_tiempo()

	# Act — sin clamp subiría 4×30 = 120 min; con clamp a 0,5 s sube 4×0,5 = 2,0 min.
	tiempo.avanzar(30.0)

	# Assert — solo 2,0 min (el delta se recortó a delta_max antes de acumular).
	assert_float(tiempo.minutos_juego).is_equal_approx(2.0, 0.001)
