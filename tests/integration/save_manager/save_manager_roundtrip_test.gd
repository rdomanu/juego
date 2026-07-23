# Story 006 (epic save-manager) — round-trip END-TO-END con autoloads REALES (disco user://) · TR-save-001/002 · TR-time-008 · ADR-0002/0001.
# Tipo: Integration. La prueba definitiva del epic: instancias REALES de RNGService y Tiempo (preload por ruta),
# un ciclo completo guardar → ALTERAR → cargar a través de JSON REAL en disco debe dejar todo idéntico:
#   - AC-RT01: el reloj vuelve a minutos_juego == 930.0 (15:30, Tarde) y la misma semana/mes/anio.
#   - AC-RT02: tras cargar, Tiempo.velocidad_actual == PAUSA (aunque se alterara a X3 antes).
#   - AC-RT03: la SECUENCIA FUTURA del RNG tras cargar == la capturada al guardar (determinismo a través del
#              int64-como-String por el JSON en disco — el punto que más fácil se rompe si el int64 pierde precisión).
#   - AC-RT04: el teardown borra el archivo (y su .tmp) → user:// queda limpio.
#
# AISLAMIENTO (punto clave de la story): el runner de GdUnit corre con los AUTOLOADS reales vivos en /root, y
# RNGService/Tiempo se auto-añaden al grupo "Persist" en su _ready. Si usáramos los métodos públicos
# guardar_partida/cargar_partida (que hacen get_tree().get_nodes_in_group("Persist")), el manager tocaría TAMBIÉN
# los autoloads reales del runner → contaminaría el RNG y el reloj reales y rompería otras suites. Por eso este test
# usa los métodos INTERNOS testeables `_recolectar_de([instancias_del_test])` / `_distribuir_a([...], dict)` con la
# LISTA INYECTADA de nuestras instancias preload-adas (exactamente para lo que existen), y reproduce a mano el
# pipeline JSON REAL a disco (stringify → user:// → leer → parse) para probar el determinismo end-to-end sin tocar
# los autoloads reales. En teardown quitamos las instancias del grupo y del árbol (aislamiento total).
extends GdUnitTestSuite

const RngScript := preload("res://src/foundation/rng_service/rng_service.gd")
const TiempoScript := preload("res://src/foundation/tiempo/tiempo.gd")
const SaveManagerScript := preload("res://src/foundation/save_manager/save_manager.gd")

const RUTA_ROUNDTRIP: String = "user://test_roundtrip.save"

## Estado de reloj conocido, inequívocamente en turno Tarde. 930 = 15:30 (NO 14:30 — errata del GDD: 14:30 cae
## en MAÑANA según la tabla de turnos; 15:30 es Tarde real).
const MINUTOS_TARDE: float = 930.0
const SEMANA_CONOCIDA: int = 3
const MES_CONOCIDO: int = 2
const ANIO_CONOCIDO: int = 1

const SEMILLA: int = 2024
## Valores a consumir del RNG ANTES de guardar (avanza su state lejos de la semilla).
const CONSUMIR_ANTES: int = 4
## Longitud de la secuencia futura que se compara para probar el determinismo (AC-RT03).
const SECUENCIA_FUTURA: int = 6

var _manager: Node
var _rng: Node
var _tiempo: Node


# ── Fixture / teardown ─────────────────────────────────────────────────────────────────────
## Monta el escenario con instancias REALES por preload de ruta, añadidas al árbol del test y al grupo "Persist"
## (sus _ready ya las auto-añaden al grupo; forzamos add_to_group por robustez si el orden de _ready variara).
## El manager es también una instancia preload-ada (no el autoload).
func before_test() -> void:
	_manager = auto_free(SaveManagerScript.new())
	add_child(_manager)

	_rng = auto_free(RngScript.new())
	_tiempo = auto_free(TiempoScript.new())
	# Inyectar un bus null en Tiempo NO es necesario: su _ready resuelve /root/EventBus (autoload real vivo en el
	# runner) o cae a fallback seguro. Al no avanzar el reloj en este test, no se emiten cruces. Añadir al árbol
	# dispara sus _ready (RNGService y Tiempo → add_to_group("Persist")).
	add_child(_rng)
	add_child(_tiempo)
	# Robustez: garantizar la pertenencia al grupo aunque el orden de _ready cambiara en el futuro.
	_rng.add_to_group("Persist")
	_tiempo.add_to_group("Persist")


## AISLAMIENTO: quitar las instancias del grupo "Persist" y del árbol para no contaminar otras suites (los
## autoloads reales del runner siguen en el grupo; NUNCA los tocamos). Borrar el archivo de test y su .tmp.
func after_test() -> void:
	if is_instance_valid(_rng):
		_rng.remove_from_group("Persist")
	if is_instance_valid(_tiempo):
		_tiempo.remove_from_group("Persist")
	# auto_free ya libera las instancias al final del test; remover del grupo antes evita la ventana en la que
	# seguirían visibles para un get_nodes_in_group de otra suite.
	_borrar(RUTA_ROUNDTRIP)
	_borrar(RUTA_ROUNDTRIP + ".tmp")


## Borra `ruta` si existe (ruta absoluta del SO globalizada).
func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Consume `n` enteros del RNG (avanza su state) y los devuelve. Se acumulan por COPIA en un Array nuevo
## (los int son valores; el Array es local a la llamada → sin captura mutable compartida).
func _generar(rng: Node, n: int) -> Array:
	var out: Array = []
	for _i in n:
		out.append(rng.randi_rango(0, 1_000_000))
	return out


## GUARDAR REAL a disco usando SOLO la lista inyectada de instancias del test (NO get_nodes_in_group → NO toca
## los autoloads reales). Reproduce el pipeline de `guardar_partida`: _recolectar_de(lista) → JSON.stringify →
## escribir a user://. Devuelve true si el archivo se escribió.
func _guardar_lista(ruta: String, nodos: Array) -> bool:
	var raiz: Dictionary = _manager._recolectar_de(nodos)
	var texto: String = JSON.stringify(raiz)
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return false
	var ok: bool = f.store_string(texto)
	f.close()
	return ok


## CARGAR REAL desde disco usando SOLO la lista inyectada (NO get_nodes_in_group). Reproduce el pipeline de
## `cargar_partida`: leer user:// → JSON.parse_string → _distribuir_a(lista, dict). Devuelve true si distribuyó.
func _cargar_lista(ruta: String, nodos: Array) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return false
	var texto: String = f.get_as_text()
	f.close()
	var parseado: Variant = JSON.parse_string(texto)
	if typeof(parseado) != TYPE_DICTIONARY:
		return false
	_manager._distribuir_a(nodos, parseado as Dictionary)
	return true


# ── AC-RT01: round-trip del reloj idéntico a través de JSON en disco ─────────────────────────
func test_roundtrip_reloj_identico() -> void:
	# Arrange — reloj a estado conocido (15:30 Tarde) + calendario concreto.
	_tiempo.minutos_juego = MINUTOS_TARDE
	_tiempo.semana = SEMANA_CONOCIDA
	_tiempo.mes = MES_CONOCIDO
	_tiempo.anio = ANIO_CONOCIDO
	var lista: Array = [_rng, _tiempo]

	# Act — guardar → ALTERAR el reloj → cargar (a través de JSON real en disco).
	assert_bool(_guardar_lista(RUTA_ROUNDTRIP, lista)).is_true()
	_tiempo.minutos_juego = 0.0
	_tiempo.semana = 1
	_tiempo.mes = 1
	_tiempo.anio = 99
	assert_bool(_cargar_lista(RUTA_ROUNDTRIP, lista)).is_true()

	# Assert — el reloj volvió al estado guardado (round-trip idéntico).
	assert_float(_tiempo.minutos_juego).is_equal(MINUTOS_TARDE)
	assert_int(_tiempo.semana).is_equal(SEMANA_CONOCIDA)
	assert_int(_tiempo.mes).is_equal(MES_CONOCIDO)
	assert_int(_tiempo.anio).is_equal(ANIO_CONOCIDO)


# ── AC-RT02: cargar arranca SIEMPRE en Pausa (aunque se alterara a X3) ───────────────────────
func test_carga_arranca_en_pausa() -> void:
	# Arrange — reloj conocido; guardar.
	_tiempo.minutos_juego = MINUTOS_TARDE
	var lista: Array = [_rng, _tiempo]
	assert_bool(_guardar_lista(RUTA_ROUNDTRIP, lista)).is_true()

	# Act — ALTERAR a X3 (velocidad de juego) y luego cargar.
	_tiempo.fijar_velocidad(TiempoScript.Velocidad.X3)
	assert_int(_tiempo.velocidad_actual).is_equal(TiempoScript.Velocidad.X3)   # sanidad: sí se alteró.
	assert_bool(_cargar_lista(RUTA_ROUNDTRIP, lista)).is_true()

	# Assert — tras cargar el reloj está en PAUSA (lo garantiza Tiempo.load_state, no el manager).
	assert_int(_tiempo.velocidad_actual).is_equal(TiempoScript.Velocidad.PAUSA)


# ── AC-RT03: la secuencia futura del RNG tras cargar es determinista a través del disco ──────
func test_rng_secuencia_futura_determinista() -> void:
	# Arrange — sembrar y consumir K valores para avanzar el state; reloj conocido (parte del mismo save).
	_rng.sembrar(SEMILLA)
	_generar(_rng, CONSUMIR_ANTES)
	_tiempo.minutos_juego = MINUTOS_TARDE
	var lista: Array = [_rng, _tiempo]

	# Guardar el estado ACTUAL a disco (JSON real). El state (int64) viaja como String.
	assert_bool(_guardar_lista(RUTA_ROUNDTRIP, lista)).is_true()

	# VERDAD DE REFERENCIA: la secuencia que el RNG produciría desde el punto guardado, SIN pasar por disco.
	# Se captura consumiendo M valores del propio RNG justo tras guardar (su state == el guardado).
	var secuencia_esperada: Array = _generar(_rng, SECUENCIA_FUTURA)

	# Act — ALTERAR: mover el state del RNG lejos del guardado; luego cargar desde el disco.
	_generar(_rng, 10)   # consumir más → state distinto del guardado.
	assert_bool(_cargar_lista(RUTA_ROUNDTRIP, lista)).is_true()

	# Tras cargar, el state restaurado (que viajó como String por el JSON) debe reproducir EXACTAMENTE la
	# secuencia esperada — la prueba end-to-end de que el int64-como-String preserva la precisión a través del disco.
	var secuencia_tras_cargar: Array = _generar(_rng, SECUENCIA_FUTURA)

	# Assert — determinismo: misma secuencia futura a través del disco.
	assert_array(secuencia_tras_cargar).is_equal(secuencia_esperada)


# ── AC-RT04: el teardown deja user:// limpio ────────────────────────────────────────────────
func test_teardown_limpia_archivo() -> void:
	# Arrange — crear el archivo de test.
	var lista: Array = [_rng, _tiempo]
	assert_bool(_guardar_lista(RUTA_ROUNDTRIP, lista)).is_true()
	assert_bool(FileAccess.file_exists(RUTA_ROUNDTRIP)).is_true()

	# Act — simular el borrado que hace el teardown (after_test lo repetirá; aquí se verifica que deja limpio).
	_borrar(RUTA_ROUNDTRIP)
	_borrar(RUTA_ROUNDTRIP + ".tmp")

	# Assert — el archivo (y su .tmp) ya no existen → user:// queda limpio.
	assert_bool(FileAccess.file_exists(RUTA_ROUNDTRIP)).is_false()
	assert_bool(FileAccess.file_exists(RUTA_ROUNDTRIP + ".tmp")).is_false()
