# Story 005 (epic save-manager) — distribución tolerante: sub-dicts vía `load_state` · TR-save-001 · TR-data-006 · ADR-0002.
# Tipo: Logic. Distribución PURA con el método interno testeable `_distribuir_a(nodos, dict)` — lista inyectada,
# sin árbol de escena ni autoload real. Nodos-espía con `name` + `load_state` que registra lo recibido; espía del
# EventBus (instancia propia, NO el autoload) para blindar que el manager NO re-dispara eventos (AC-DT04).
#
# Simetría con la recolección (Story 002): la clave es `node.name`. Tolerancia (TR-data-006): una entrada faltante
# → warning + defaults, los demás cargan igual; NUNCA se invalida el save en bloque.
extends GdUnitTestSuite

const SaveManagerScript := preload("res://src/foundation/save_manager/save_manager.gd")
const EspiaScript := preload("res://tests/unit/save_manager/persist_espia.gd")
const EventBusEspiaScript := preload("res://tests/unit/save_manager/event_bus_espia.gd")


# ── Helpers de fixture ──────────────────────────────────────────────────────────────────────
## Crea un nodo-espía Persist con `name` fijado (el manager lo lee como clave del sub-dict).
func _espia(nombre: String) -> Node:
	var e: Node = auto_free(EspiaScript.new())
	e.name = nombre   # fijar name ANTES de distribuir (el método interno no lo mete en el árbol).
	return e


# ── AC-DT01: cada nodo recibe SU sub-dict por nombre ────────────────────────────────────────
func test_distribuye_subdict_por_nombre() -> void:
	# Arrange — 2 espías con nombres de autoload estables; dict con una entrada para cada uno.
	var manager: Node = auto_free(SaveManagerScript.new())
	var rng: Node = _espia("RNGService")
	var tiempo: Node = _espia("Tiempo")
	var sub_rng: Dictionary = {"semilla": "2024", "estado": "99"}
	var sub_tiempo: Dictionary = {"minutos_juego": 930.0, "semana": 3}
	var dict: Dictionary = {"version": 1, "RNGService": sub_rng, "Tiempo": sub_tiempo}
	# Act
	manager._distribuir_a([rng, tiempo], dict)
	# Assert — cada espía fue llamado UNA vez con SU sub-dict exacto.
	assert_bool(rng.load_state_llamado).is_true()
	assert_bool(tiempo.load_state_llamado).is_true()
	assert_dict(rng.estado_recibido).is_equal(sub_rng)
	assert_dict(tiempo.estado_recibido).is_equal(sub_tiempo)
	assert_int(rng.load_state_veces).is_equal(1)
	assert_int(tiempo.load_state_veces).is_equal(1)


# ── AC-DT02: una entrada faltante NO invalida la carga de los demás ─────────────────────────
func test_entrada_faltante_no_invalida() -> void:
	# Arrange — dict con SOLO "RNGService"; "Tiempo" no tiene entrada.
	var manager: Node = auto_free(SaveManagerScript.new())
	var rng: Node = _espia("RNGService")
	var tiempo: Node = _espia("Tiempo")
	var sub_rng: Dictionary = {"semilla": "7", "estado": "42"}
	var dict: Dictionary = {"version": 1, "RNGService": sub_rng}
	# Act — no crashea aunque falte "Tiempo" (push_warning intencionado).
	manager._distribuir_a([rng, tiempo], dict)
	# Assert — rng cargó su sub-dict; tiempo NO fue llamado (mantiene defaults).
	assert_bool(rng.load_state_llamado).is_true()
	assert_dict(rng.estado_recibido).is_equal(sub_rng)
	assert_bool(tiempo.load_state_llamado).is_false()
	assert_int(tiempo.load_state_veces).is_equal(0)


# ── AC-DT03: un nodo del grupo sin `load_state` se ignora (defensivo) ───────────────────────
func test_nodo_sin_load_state_se_ignora() -> void:
	# Arrange — un Node pelado (sin load_state) + un espía válido.
	var manager: Node = auto_free(SaveManagerScript.new())
	var sin_contrato: Node = auto_free(Node.new())
	sin_contrato.name = "SinContrato"
	var rng: Node = _espia("RNGService")
	var sub_rng: Dictionary = {"semilla": "1", "estado": "2"}
	var dict: Dictionary = {"version": 1, "SinContrato": {"lo": "que", "sea": true}, "RNGService": sub_rng}
	# Act — el nodo sin load_state se ignora sin petar; el válido carga igual.
	manager._distribuir_a([sin_contrato, rng], dict)
	# Assert — rng cargó; el pelado no recibió nada (no tiene con qué) y no rompió la distribución.
	assert_bool(rng.load_state_llamado).is_true()
	assert_dict(rng.estado_recibido).is_equal(sub_rng)


# ── AC-DT04: el manager NO re-dispara eventos (EventBus a 0 emisiones) ──────────────────────
func test_manager_no_emite_eventos() -> void:
	# Arrange — espía del bus (instancia propia) + espías Persist cuyo load_state NO emite nada.
	var manager: Node = auto_free(SaveManagerScript.new())
	var bus_espia: Node = auto_free(EventBusEspiaScript.new())
	add_child(bus_espia)
	var rng: Node = _espia("RNGService")
	var tiempo: Node = _espia("Tiempo")
	var dict: Dictionary = {
		"version": 1,
		"RNGService": {"semilla": "2024", "estado": "99"},
		"Tiempo": {"minutos_juego": 930.0, "semana": 3},
	}
	# Act — distribución completa.
	manager._distribuir_a([rng, tiempo], dict)
	# Cleanup ANTES de assertar (si un assert falla, el espía no queda conectado).
	bus_espia.desconectar()
	# Assert — el manager no re-disparó NADA: el bus quedó en 0 emisiones.
	assert_int(bus_espia.emisiones).is_equal(0)
	# Sanidad: los espías SÍ cargaron (la distribución de verdad ocurrió, no es un 0 trivial).
	assert_bool(rng.load_state_llamado).is_true()
	assert_bool(tiempo.load_state_llamado).is_true()


# ── Extra: el espía del bus REALMENTE cuenta (si algo emite, el contador sube) ──────────────
# Blinda el AC-DT04: verifica que un 0 en el test anterior significa "no emitió", no "el espía no escucha".
func test_espia_bus_cuenta_emisiones_reales() -> void:
	# Arrange
	var bus_espia: Node = auto_free(EventBusEspiaScript.new())
	add_child(bus_espia)
	# Act — emitir una señal cualquiera del bus directamente.
	bus_espia.bus.cambio_de_turno.emit(1)
	# Cleanup antes de assertar.
	var emisiones: int = bus_espia.emisiones
	bus_espia.desconectar()
	# Assert — el espía registró la emisión (el contador NO es un falso 0).
	assert_int(emisiones).is_equal(1)
