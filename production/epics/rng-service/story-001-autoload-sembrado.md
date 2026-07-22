# Story 001: RNGService autoload + envoltorios sembrados

> **Epic**: RNGService
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija `/dev-story` al empezar)

## Context

**GDD**: `docs/architecture/architecture.md` §API Boundaries → RNGService — *módulo de infraestructura sin GDD*
**Requirement**: principio transversal de **determinismo global** (ADR-0002). Sin TR propio específico:
**habilita** TR-demand-002 (mezcla ponderada sembrada), TR-staff-001/003 (mercado/ausencias), TR-patience-004
(reclamación por probabilidad). El TR propio del epic (TR-save-002) es la Story 003.

**ADR Governing Implementation**: ADR-0002: Guardado/serialización + RNG determinista
**ADR Decision Summary**: servicio central de RNG **sembrado**; toda la aleatoriedad de juego pasa por aquí
(nadie usa `randi()`/`randf()` global). Garantía: misma semilla + misma secuencia de llamadas → mismos
resultados.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` (con `seed`, `state`, `randi_range`, `randf`) es API estable, no
post-cutoff. Verificado en `modules/save-load.md`/`patterns.md`.

**Control Manifest Rules (Foundation)**:
- Required: toda aleatoriedad de juego pasa por `RNGService` sembrado (`randi_rango`/`elegir_ponderado`).
  Orden de autoloads: `EventBus → RNGService → Datos → Tiempo → SaveManager` (RNGService el **segundo**).
- Forbidden: **nunca** usar `randi()`/`randf()` global (rompe el determinismo).
- Cross-cutting: tipado estático; determinismo por diseño.

---

## Acceptance Criteria

*Derivados de ADR-0002 (Decision punto 4, Validation Criteria) y del contrato RNGService de `architecture.md`:*

- [ ] Existe `rng_service.gd` (`extends Node`) registrado como autoload **"RNGService"**, el **segundo** en el
      orden de autoloads (tras EventBus).
- [ ] `sembrar(semilla: int) -> void` fija la semilla del generador.
- [ ] `randi_rango(desde: int, hasta: int) -> int` devuelve un entero en el rango **[desde, hasta] inclusive**.
- [ ] `randf() -> float` devuelve un flotante en **[0.0, 1.0)**.
- [ ] **Determinismo**: dos `RNGService` con la misma semilla producen la **misma secuencia** de resultados
      ante la misma secuencia de llamadas.
- [ ] Tipado estático en toda firma.

---

## Implementation Notes

*Derivadas de ADR-0002 + contrato de arquitectura:*

```gdscript
extends Node   # rng_service.gd — Autoload "RNGService" (el 2º, tras EventBus)

var _rng := RandomNumberGenerator.new()

func sembrar(semilla: int) -> void:
    _rng.seed = semilla

func randi_rango(desde: int, hasta: int) -> int:
    return _rng.randi_range(desde, hasta)   # inclusivo en ambos extremos (API Godot 4)

func randf() -> float:
    return _rng.randf()                      # [0.0, 1.0)
```

- El estado interno (`_rng.state`) avanza con cada llamada → la reproducibilidad depende de sembrar y de
  llamar en el mismo orden. La **serialización** de ese estado es la Story 003.
- Al arrancar partida nueva, alguien (el bootstrap) llamará `sembrar(...)` con una semilla nueva; aquí solo
  se provee el mecanismo.

---

## Out of Scope

- **Story 002**: `elegir_ponderado` (elección ponderada con normalización).
- **Story 003**: `save()`/`load_state()` (serialización del estado + semilla).
- **Bootstrap del juego**: de dónde sale la semilla inicial de una partida nueva.

---

## QA Test Cases

*Escritos por el hilo principal (QA Lead omitido en LEAN). Determinista (sin reloj real).*

- **AC-1 (determinismo)**: misma semilla + misma secuencia → misma salida.
  - Given: dos instancias `a`, `b`; `a.sembrar(12345)`, `b.sembrar(12345)`.
  - When: se llaman en el mismo orden `randi_rango(1,100)` y `randf()` varias veces en cada una.
  - Then: cada par de resultados coincide exactamente.
  - Edge: semillas distintas (12345 vs 999) → las secuencias difieren (al menos un resultado distinto).
- **AC-2 (rango de `randi_rango`)**: los resultados caen en [desde, hasta].
  - Given: `sembrar(7)`.
  - When: 200 llamadas a `randi_rango(5, 10)`.
  - Then: todos los valores están en {5,6,7,8,9,10} (inclusive ambos extremos).
- **AC-3 (rango de `randf`)**: los resultados caen en [0.0, 1.0).
  - Given: `sembrar(7)`.
  - When: 200 llamadas a `randf()`.
  - Then: todos ≥ 0.0 y < 1.0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_service/rng_service_sembrado_test.gd` — debe existir y pasar (determinismo + rangos).

**Status**: [x] **Creado y PASA** — `tests/unit/rng_service/rng_service_sembrado_test.gd`, 4/4 test cases,
0 fallos, GdUnit4 headless con Godot 4.6.stable (2026-07-22). Suite total del proyecto: 14/14, exit 0.

**Implementación:** `src/foundation/rng_service/rng_service.gd` (autoload `RNGService`, el 2º tras EventBus,
registrado en `project.godot`). Falta el cierre formal con `/story-done`.

---

## Dependencies

- Depends on: None (Foundation; se construye junto con EventBus, antes que Core).
- Unlocks: Story 002 (ponderada) y Story 003 (serialización); y el determinismo de Demanda/Personal/Paciencia.
