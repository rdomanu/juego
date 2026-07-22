# Story 003: Serialización del RNG (`save`/`load_state`)

> **Epic**: RNGService
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija `/dev-story` al empezar)

## Context

**GDD**: `docs/architecture/architecture.md` §3.3 (Guardado) + §API RNGService — *módulo de infraestructura sin GDD*
**Requirement**: `TR-save-002` — serializar el **estado del RNG + la semilla** (determinismo al cargar). Es el
requisito propio del epic RNGService.

**ADR Governing Implementation**: ADR-0002: Guardado/serialización + RNG determinista
**ADR Decision Summary**: cada sistema con estado implementa `save() -> Dictionary` / `load_state(d)` y se
marca con el grupo `Persist`; el `RNGService` serializa su estado + semilla para que, al cargar, la
**secuencia futura sea idéntica** ("cargar sitúa, no reproduce").

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` expone `seed` y `state` (ambos `int`), directamente serializables a
JSON. La escritura a disco y el JSON los hace **SaveManager** (otro epic); aquí solo el `Dictionary`.

**Control Manifest Rules (Foundation)**:
- Required: **serializar el estado del `RNGService` (estado + semilla)**; patrón `save()`/`load_state()`;
  marcar el nodo con el grupo **`Persist`** (el `SaveManager` recorre ese grupo, **no** llama por nombre).
- Forbidden: **nunca olvidar serializar el RNG** (rompería el determinismo al cargar); `save()` devuelve
  **solo datos serializables** (números/texto/listas/dicts), nunca objetos.

---

## Acceptance Criteria

*Derivados de ADR-0002 (Decision punto 4, Validation Criteria "Determinismo") y del contrato `save/load_state`:*

- [ ] `save() -> Dictionary` devuelve `{"semilla": int, "estado": int}` (solo datos serializables).
- [ ] `load_state(d: Dictionary) -> void` restaura semilla y estado del generador.
- [ ] **Round-trip determinista**: tras `load_state(guardado)`, la **secuencia futura** de números es idéntica
      a la que habría salido en el punto de guardado (misma continuación).
- [ ] El nodo `RNGService` pertenece al grupo `Persist` (se marca en `_ready`).
- [ ] Tipado estático.

---

## Implementation Notes

*Derivadas de ADR-0002 + contrato de arquitectura:*

```gdscript
func _ready() -> void:
    add_to_group("Persist")

func save() -> Dictionary:
    return {"semilla": _rng.seed, "estado": _rng.state}

func load_state(d: Dictionary) -> void:
    _rng.seed = int(d.get("semilla", 0))
    _rng.state = int(d.get("estado", 0))
```

- `RandomNumberGenerator.state` captura la **posición interna** del generador; restaurarlo hace que la
  siguiente llamada devuelva exactamente lo que habría devuelto sin guardar.
- `int(d.get(..., 0))` es defensivo: JSON parsea números como `float`; se convierten a `int` al cargar.
- La orquestación (recorrer `Persist`, `JSON.stringify`, `FileAccess`, `user://`) es del **epic SaveManager**;
  esta story solo cumple el contrato `save()`/`load_state()` del RNG.

---

## Out of Scope

- **Story 001 / 002**: el generador sembrado y la elección ponderada.
- **Epic SaveManager**: guardar/cargar a disco, ensamblar el diccionario raíz, `user://`, versión del save.

---

## QA Test Cases

*Escritos por el hilo principal (QA Lead omitido en LEAN). Integration = round-trip de serialización.
Determinista.*

- **AC-1 (round-trip continúa la secuencia)**:
  - Given: `sembrar(2024)`; se consumen 3 números (`randi_rango`/`randf`) para avanzar el estado.
  - When: `var g = save()`; se generan 5 números → `seq_A`; luego `load_state(g)`; se generan otros 5 → `seq_B`.
  - Then: `seq_A == seq_B` (restaurar el estado reproduce la continuación exacta).
- **AC-2 (formato de `save`)**:
  - Given: `sembrar(2024)`.
  - When: `var g = save()`.
  - Then: `g` tiene las claves `"semilla"` y `"estado"`, ambas `int`; `g["semilla"] == 2024`.
- **AC-3 (serializable a JSON)**:
  - Given: `var g = save()`.
  - When: `JSON.stringify(g)` → `JSON.parse_string(...)` → `load_state(parseado)`.
  - Then: no falla; y la secuencia futura vuelve a coincidir con el punto de guardado (round-trip vía JSON).
- **AC-4 (grupo Persist)**:
  - Setup: añadir el `RNGService` al árbol.
  - Verify: `is_in_group("Persist")` es `true`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/rng_service/rng_service_serializacion_test.gd` — debe existir y pasar
  (round-trip directo + round-trip vía JSON + grupo Persist).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: **Story 001** (el generador sembrado).
- Unlocks: que **SaveManager** pueda persistir el azar → determinismo al cargar en Demanda/Personal/Paciencia.
