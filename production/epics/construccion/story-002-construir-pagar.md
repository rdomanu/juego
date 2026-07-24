# Story 002: Construir y pagar — F1/F2 con el gate E4 de Economía

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO6, CO9, F1, F2 + edges de caja y clamp)
**Requirement**: `TR-construction-004` *(parcial — la construcción que después se provee a Flujo/Personal)*
**Governing ADRs**: ADR-0004 (primario), ADR-0001 (secundario — Economía posee el dinero; gasto voluntario solo con `puede_pagar`)
**ADR Decision Summary**: construir es GASTO VOLUNTARIO → pasa por el gate E4 (`puede_pagar` + `cobrar`);
la construcción es instantánea al confirmar (CO9). Economía inyectable (patrón `usar_economia` de Personal).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff en esta story.

**Control Manifest Rules (Core)**:
- Required: gates `puede_pagar()`/`cobrar()` de Economía para gasto voluntario. — ADR-0001
- Required: valores SIEMPRE del catálogo/config (F1 base de Datos + knob; F2 `coste_construccion_eur`). — ADR-0003
- Forbidden: endeudarse construyendo (si no hay caja, se rechaza).

---

## Acceptance Criteria

- [ ] **AC-CO04** `[Unit]` — GIVEN sala 3×3 THEN coste `380`; 5×4 → `600` (F1: base 200 + 20/celda).
- [ ] **AC-CO05** `[Integration]` — GIVEN `saldo < coste` WHEN se construye THEN **rechazado**, saldo intacto (E4).
- [ ] **AC-CO06** `[Integration]` — GIVEN `saldo=600` WHEN se construye un `doc_general` (500) THEN `saldo=100`.
- [ ] **AC-CO18** `[Unit]` — GIVEN un coste negativo (corrupto) THEN se **clampa a ≥ 0**.

---

## Implementation Notes

- **`coste_sala(tipo_sala_id, rect) -> float`** (F1): `coste_base (Datos TipoSala) + coste_por_celda ×
  área`; las OFICINAS (áreas lógicas) pueden tener base 0 — su coste real son los puestos. Clamp ≥ 0 con
  aviso si el dato del catálogo viene corrupto (AC-CO18, patrón Datos).
- **`coste_elemento(id_catalogo) -> float`** (F2): `coste_construccion_eur` del catálogo (`doc_general`
  500 · `tie` 500 · `odac` 600 · asiento ~25 según catálogo/config). Clamp ≥ 0.
- **`construir_sala(tipo, rect) -> StringName`** y **`construir_elemento(id_catalogo, celda) ->
  StringName`**: validar (story 001) → coste → gate `_economia.puede_pagar(coste)` → `_economia.cobrar(
  coste, ...)` → registrar en el modelo GUARDANDO `coste_pagado` (lo necesita el reembolso F4, story 004).
  Devuelven el id creado o `&""` si rechazo (regla de juego → silencioso; dato corrupto → aviso).
- `usar_economia(economia)` inyectable (patrón Personal); sin Economía → construir avisa y no aplica gate
  (solo tests).
- Sin señales nuevas del bus en esta story (los eventos de Feedback llegarán con su epic).

---

## Out of Scope

- Story 003: registrar el puesto en Personal (aquí solo existe en el modelo).
- Story 004: demoler/mover. · Story 006/007: visual y ratón.

---

## QA Test Cases

*Escritos por el hilo principal (modo lean) desde qa-plan-sprint-2.*

- **AC-CO04**: Given catálogo real → coste_sala(espera 3×3) == 380.0; 5×4 == 600.0 (frontera exacta:
  floats con is_equal_approx).
- **AC-CO05**: Given Economía real saldo 100 → construir doc_general (500) → &"" y saldo sigue 100.0;
  el modelo NO registra nada.
- **AC-CO06**: Given Economía real saldo 600 → construir doc_general → id válido y saldo 100.0.
- **AC-CO18**: Given un TipoSala/TipoPuesto con coste negativo (instancia corrupta inyectada) → coste 0
  con aviso (push_warning esperado).
- **Sala válida + pago**: construir sala de espera 3×3 con saldo 3000 → saldo 2620 y la sala consta en
  el modelo con su rect.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/construccion/construccion_pagar_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (validación y modelo) — DONE antes de empezar.
- Unlocks: Story 003 (puentes a Personal) y 004 (demoler).
