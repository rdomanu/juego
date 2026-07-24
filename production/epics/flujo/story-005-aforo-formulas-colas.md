# Story 005: La sala respira — aforo y cola exterior (F6) + matemáticas de colas (F2-F5)

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic *(mixta con Integration — el aforo viene de Construcción)*
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL6, FL7, F2, F3, F4, F5, F6)
**Requirement**: `TR-flow-002` *(parcial — el detalle dentro/fuera de la cola)* + fórmulas para UI/R5
**Governing ADRs**: ADR-0001 (primario — determinismo; la espera se ESTIMA, no se simula)
**ADR Decision Summary**: F2-F5 son funciones PURAS (matemática de colas para la UI y el sanity R5);
el aforo real viene de los ASIENTOS de Construcción (no del `aforo_espera` de referencia del catálogo).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Core)**:
- Required: el aforo lo posee Construcción (`aforo_de_sala` por asientos) — Flujo solo compara
  ocupación vs aforo, no lo recalcula. — capas ADR-0001
- Forbidden: tope artificial de la cola exterior (FL7: crece sin límite; la válvula es Paciencia).

---

## Acceptance Criteria

- [ ] **AC-FL12** `[Unit]` — GIVEN `aforo_espera=40` y `ocupacion_dentro=39` THEN `hay_plaza_dentro=true`; con `ocupacion=40` → **false**.
- [ ] **AC-FL13** `[Integration]` — GIVEN sala Doc a aforo WHEN llega la siguiente THEN va a **Esperando (fuera)**; WHEN se libera una plaza THEN entra **la primera de la cola exterior** por orden de turno.
- [ ] **AC-FL14** `[Integration]` — GIVEN `requiere_cita=false` y llegadas > capacidad WHEN transcurre el tiempo THEN la cola **crece sin tope de Flujo** (no hay bloqueo; la válvula es abandono).
- [ ] **AC-FL19** `[Unit]` — GIVEN `minutos_operativos=390` y `duracion_efectiva_media=15` THEN `throughput_puesto=26` (F2).
- [ ] **AC-FL20** `[Unit]` — GIVEN 2 puestos a 26 THEN `capacidad_servicio=52`; a tope Doc (8+2) → **≈260** (F3).
- [ ] **AC-FL21** `[Unit]` — GIVEN llegadas 8/h y 1 puesto (cap 4/h) THEN `ρ=2`; con un 2.º → `ρ=1` (F4).
- [ ] **AC-FL22** `[Unit]` — GIVEN 8 delante y 1 puesto (dur 15) THEN `espera_estimada=120`; 2 puestos → **60**; 0 puestos → **indefinida** (F5).

---

## Implementation Notes

- **Aforo (F6/FL6)**: al admitir (001) o al liberarse plaza: si `ocupacion_dentro(servicio) <
  aforo(servicio)` → Esperando (dentro); si no → Esperando (fuera). El aforo del servicio =
  `_construccion.aforo_de_sala(sala de espera del servicio)` — resolver la sala de espera por
  servicio (getter en Construcción o por convención de tipo; decidir al implementar con lo que ya
  expone). Al liberar plaza (Llamada o Abandonando): entra el PRIMERO de fuera por `numero_turno`.
- **F2-F5 puras**: `throughput_puesto(min_operativos, dur_media)` · `capacidad_servicio(...)` ·
  `factor_carga(tasa, capacidad)` (capacidad 0 → -1.0 como centinela "sin servicio" con doc: la UI
  lo mostrará como texto, nunca ∞) · `espera_estimada(delante, puestos, dur_media)` (0 puestos →
  -1.0 centinela "indefinida"). `minutos_operativos` es ENTRADA provisional (Documentación/Horarios
  #8 la poseerá).
- Nada de esto corre en el tick por frame salvo la clasificación dentro/fuera al admitir/liberar
  (barata); las fórmulas las llamará la UI bajo demanda.

---

## Out of Scope

- El abandono real (Paciencia #10 — aquí solo el hueco que deja al liberarse plaza, vía la 006).
- El HUD de colas/espera (UI/HUD #11).

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean).*

- **AC-FL12**: hay_plaza con 39/40 → true; 40/40 → false (boundary exacto).
- **AC-FL13**: Given sala espera pequeña de Construcción REAL (3 asientos) y 4 admisiones → Then 3
  dentro + 1 fuera (por turno); al pasar una a Llamada → la 4.ª entra (orden de turno respetado con
  5.º y 6.º llegados después).
- **AC-FL14**: 20 admisiones con 1 puesto → la cola crece a 18+ sin error ni tope; el último tick
  atiende al mismo ritmo (sin freno — patrón DM16).
- **AC-FL19..22**: los 4 valores exactos del GDD (26 · 52/260 · 2→1 · 120/60/-1) con
  is_equal_approx; centinelas de capacidad 0 documentados (sin división por cero).

---

## Test Evidence

**Story Type**: Logic (+Integration del aforo)
**Required evidence**: `tests/unit/flujo/flujo_formulas_test.gd` + aforo en
`tests/integration/flujo/flujo_aforo_test.gd` — deben existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (ciclo completo — liberar plaza al llamar) — DONE antes de empezar.
- Unlocks: Story 006 (gestión en caliente sobre el flujo completo).
