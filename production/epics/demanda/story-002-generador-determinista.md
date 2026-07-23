# Story 002: Generador determinista por tick (acumulador + mezcla)

> **Epic**: Generación de Demanda
> **Status**: Complete (cierre del epic con sign-off, 2026-07-24)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/demand-generation.md` (DG1, DG4, DG5, F3, F4)
**Requirement**: `TR-demand-002` (RNG sembrado determinista — mezcla ponderada) + `TR-demand-001` *(parcial — el acumulador alimentado por delta)*
*(Texto de los requisitos en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0002 (primario — toda aleatoriedad por `RNGService` sembrado), ADR-0001 (secundario — el generador se conectará al tick en la 003)
**ADR Decision Summary**: ADR-0002 — la mezcla ponderada usa `RNGService.elegir_ponderado` (sembrado, serializable); misma semilla → misma secuencia. ADR-0001 — la simulación consume `delta_juego`, nunca el reloj real.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. Gotcha del proyecto: en tests, las lambdas capturan locales **por valor** → usar un `Array` para contar. `RefCounted` se libera solo (las fichas no necesitan `free()`).

**Control Manifest Rules (Core)**:
- Required: **Demanda: toda aleatoriedad (mezcla ponderada) por `RNGService` sembrado** (`elegir_ponderado`). — ADR-0002
- Forbidden: **nunca `randi()`/`randf()` global**. — ADR-0002
- Required: tipado estático; valores de la mezcla en config (`demanda.tres`), no en código.

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM06** `[Unit]` — GIVEN la misma `semilla_rng` y la misma secuencia de `Δh` WHEN se ejecuta dos veces THEN la secuencia de llegadas Y de trámites es **idéntica** (determinismo).
- [ ] **AC-DM07** `[Unit]` — GIVEN `acumulador≥5` y `max_llegadas_por_tick=3` WHEN un tick THEN se generan exactamente **3** y el excedente (≥2) **queda** en el acumulador (no se pierde demanda).
- [ ] **AC-DM08** `[Unit]` — GIVEN N grande de generaciones Doc con semilla fija WHEN se cuentan los trámites THEN proporciones ≈ **dni 0.45 / pasaporte 0.35 / tie 0.20** (± tolerancia).
- [ ] **AC-DM17** `[Unit]` — GIVEN una mezcla con pesos `[2,1,1]` (no suma 1) WHEN se procesa THEN se **normaliza** a `[0.5,0.25,0.25]` antes de elegir *(lo hace `elegir_ponderado` — verificar que Demanda NO lo duplica y que el resultado es correcto)*.

---

## Implementation Notes

*Derivadas de ADR-0002 + F4 del GDD:*

- **La ficha Persona** (decisión del usuario 2026-07-23: clase tipada mínima): `src/core/demanda/persona.gd` —
  `class_name Persona extends RefCounted` con `servicio: StringName` (&"documentacion"/&"odac"), `tramite_id: StringName` (id del catálogo Datos) y `minuto_llegada: float` (minutos de juego al crearla). **Cero lógica** — es la "ficha de papel" que Flujo envolverá después en su nodo con movimiento (el movimiento es capa cosmética, ADR-0004: la lógica nunca lee el sprite).
- **El algoritmo (F4)**, en `demanda.gd`, como método **puro respecto a la escena** (sin bus todavía):
  ```
  procesar_avance(delta_min: float, min_dia: float) -> Array[Persona]:
    por servicio (doc/odac, si su densidad > 0):
      _acumulador[servicio] += densidad_por_minuto(min_dia, servicio) × delta_min
      mientras _acumulador ≥ 1.0 y generadas < max_llegadas_por_tick:
        tramite = RNGService.elegir_ponderado(mezcla[servicio])   # F3
        crear Persona(servicio, tramite, minutos_juego) → añadir al resultado
        _acumulador -= 1.0 ; generadas += 1
  ```
- Acumuladores **separados por servicio** (`_acumulador_doc`, `_acumulador_odac`) — el residuo fraccional se conserva entre ticks (no se pierde demanda por redondeo; el goteo nocturno de ODAC sale espaciado por diseño).
- El **tope de ráfaga** `max_llegadas_por_tick` (config, default 3) se aplica **por tick global** (suma de ambos servicios) — anti-avalancha DG5; el excedente espera al siguiente tick. Si el acumulador crece sin drenar nunca (mal tuning), `push_warning` (edge case del GDD).
- **La mezcla** viene de config: `mezcla_doc: Dictionary[StringName, float]` = {dni 0.45, pasaporte 0.35, tie 0.20}; `mezcla_odac` = los 13 tipos de F3 (hurto_robo 0.18 … agresion_sexual 0.02). Los ids deben existir en el catálogo (los tests usan el catálogo real de `datos/`).
- **No reimplementar la normalización**: `elegir_ponderado` ya normaliza pesos defensivamente (Foundation, story rng-002). AC-DM17 se cumple por composición — el test lo verifica end-to-end con la mezcla.
- Recordar el footgun registrado: si algún método local se llamara como una utilidad global de Godot, cualificar con `self.` (aquí no debería aplicar — no nombrar nada `randf`/`randi`).

---

## Out of Scope

- Story 003: cuándo se llama a `procesar_avance` (tick de Tiempo), la ventana horaria en runtime, la emisión de `persona_generada` al bus, la Pausa.
- Story 005: modificar la mezcla/tasa por eventos estacionales.
- Story 006: serializar los acumuladores.

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-DM06**: Given `RNGService.sembrar(42)` y secuencia fija de deltas [p. ej. 60 ticks × 1 min a las 08:xx] → When se ejecuta 2 veces (re-sembrando) → Then ambas corridas producen el mismo nº de fichas, en el mismo orden, con los mismos `tramite_id` (comparar Arrays elemento a elemento).
- **AC-DM07**: Given `_acumulador_doc = 5.0` forzado (o densidad artificial alta) y tope 3 → When un `procesar_avance` → Then devuelve 3 fichas y el acumulador queda ≥ 2.0. Edge: siguiente tick drena el resto.
- **AC-DM08**: Given semilla fija y 2000 elecciones Doc → Then |frecuencia − peso| < 0.03 para dni/pasaporte/tie. *(Determinista con semilla fija → el test no es flaky.)*
- **AC-DM17**: Given mezcla artificial {a:2, b:1, c:1} → When 2000 elecciones → Then frecuencias ≈ 0.5/0.25/0.25 (±0.03) — la normalización defensiva de RNGService actúa.
- Edge (ficha): cada Persona lleva `servicio` correcto y un `tramite_id` que **existe** en `Datos.obtener(...)` (validar contra catálogo real).
- Edge (tope global): con ambos servicios acumulando, el total generado en un tick ≤ `max_llegadas_por_tick`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/demanda/demanda_generador_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (7 tests; suite total 197/197, exit 0 — 2026-07-23)

---

## Dependencies

- Depends on: Story 001 (config + densidad_por_minuto) — DONE antes de empezar.
- Unlocks: Story 003 (conexión al tick y al bus).
