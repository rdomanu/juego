# Story 003: Serialización del RNG (`save`/`load_state`)

> **Epic**: RNGService
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

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

- [x] `save() -> Dictionary` devuelve `{"semilla": String, "estado": String}`. Semilla y estado son
      **int64**; se guardan como **texto** para sobrevivir un round-trip por JSON **sin perder precisión**
      (JSON parsea los números como float/double, que no representa exacto los enteros > 2^53 — y el estado
      del PCG suele serlo).
- [x] `load_state(d: Dictionary) -> void` restaura semilla y estado del generador (parsea el texto a int).
- [x] **Round-trip determinista**: tras `load_state(guardado)`, la **secuencia futura** de números es idéntica
      a la que habría salido en el punto de guardado (misma continuación).
- [x] El nodo `RNGService` pertenece al grupo `Persist` (se marca en `_ready`).
- [x] Tipado estático.

---

## Implementation Notes

*Derivadas de ADR-0002 + contrato de arquitectura:*

```gdscript
func _ready() -> void:
    add_to_group("Persist")

func save() -> Dictionary:
    # int64 -> String para no perder precisión en el round-trip por JSON (ver AC).
    return {"semilla": str(_rng.seed), "estado": str(_rng.state)}

func load_state(d: Dictionary) -> void:
    _rng.seed = int(str(d.get("semilla", "0")))
    _rng.state = int(str(d.get("estado", "0")))
```

- `RandomNumberGenerator.state` captura la **posición interna** del generador; restaurarlo hace que la
  siguiente llamada devuelva exactamente lo que habría devuelto sin guardar.
- `str(...)`/`int(str(...))` preserva el int64 exacto a través de JSON; `int(str(d.get(..., "0")))` es
  defensivo ante claves ausentes o valores ya numéricos.
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
  - Then: `g` tiene las claves `"semilla"` y `"estado"`, ambas **String**; `g["semilla"] == "2024"`.
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

**Status**: [x] **Creado y PASA** — `tests/integration/rng_service/rng_service_serializacion_test.gd`,
4/4 test cases, 0 fallos, GdUnit4 headless (2026-07-22). Suite total del proyecto: 23/23, exit 0.

**Implementación:** `save()`/`load_state()` + `_ready()` (grupo `Persist`) en `rng_service.gd`. **Decisión:**
semilla/estado se guardan como **String** (no int) para preservar el int64 exacto en el round-trip por JSON
(JSON parsea números como float → pierde precisión > 2^53; el estado del PCG suele serlo). Verificado con el
test AC-3 (round-trip vía JSON). Falta el cierre formal con `/story-done`.

---

## Dependencies

- Depends on: **Story 001** (el generador sembrado).
- Unlocks: que **SaveManager** pueda persistir el azar → determinismo al cargar en Demanda/Personal/Paciencia.

## Cierre (2026-07-22)

Cierre formal aprobado por el usuario. Verificación QA read-only (subagente Opus, 2026-07-22): todos los
AC CUMPLIDOS con evidencia archivo:línea; mapeo 1:1 QA Test Case → función de test; 0 desviaciones de ADR
y control-manifest (Foundation). Suite del proyecto 32/32 en verde (re-verificada de forma independiente
en el hilo principal). Informe completo en la sesión (no persistido).
