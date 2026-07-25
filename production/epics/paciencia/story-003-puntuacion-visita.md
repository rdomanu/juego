# Story 003: F2 — cuánto puntúa cada visita

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~1-2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F2)
**Requirement**: `TR-patience-003` *(parcial — la pieza que alimenta la media de jornada)*
**Governing ADRs**: ADR-0001 (secundario), ADR-0003 (knobs del catálogo)
**ADR Decision Summary**: F2 es **pura**. El `factor_trato` lo posee **Personal** (`factor_trato_de`);
Paciencia lo consume, no lo recalcula.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Feature)**:
- Required: `factor_trato` se LEE de Personal; sin Personal inyectado → **1.0 neutro** (patrón de
  dependencias blandas ya usado en Flujo). — ADR-0001
- Forbidden: hardcodear `puntuacion_base` o `k_espera` (config).

---

## Acceptance Criteria

- [ ] **AC-PS06** `[Unit]` — GIVEN atendida sin espera y trato neutro (1.0) THEN `puntuacion = 80`.
- [ ] **AC-PS07** `[Unit]` — GIVEN atendida al límite (consumió ~100 de paciencia) + trato 0.7 THEN
      `puntuacion ≈ 28`.
- [ ] **AC-PS08** `[Unit]` — GIVEN un abandono THEN `puntuacion_visita = 0`.
- [ ] **AC-PS09** `[Unit]` — GIVEN `base × factores = 105` THEN **clamp → 100**.

---

## Implementation Notes

- `puntuacion_atendida = clamp(puntuacion_base × factor_espera × factor_trato, 0, 100)` con
  `factor_espera = 1 − k_espera × (paciencia_consumida / 100)`.
- `paciencia_consumida = 100 − paciencia_al_ser_llamada` → hay que **guardar la paciencia en el momento
  de la llamada** (cuando se congela, story 002), no la del final del trámite: lo que molesta es la
  espera, no lo que dura el trámite.
- Knobs nuevos: `puntuacion_base` 80 · `k_espera` 0.5.
- Comprobar los tres ejemplos del GDD a mano: `80×1.0×1.0=80` · `80×0.75×1.0=60` · `80×0.5×0.7=28` ·
  `80×1.0×1.3=104 → 100`.
- El **peso** de cada visita (Doc 1.0 / ODAC `peso_prioridad`) NO se aplica aquí: es de la media (004).

---

## Test Cases

`tests/unit/paciencia/paciencia_puntuacion_test.gd`
- `test_atendida_sin_espera_trato_neutro_puntua_80` (AC-PS06)
- `test_atendida_al_limite_con_mal_trato_puntua_28` (AC-PS07)
- `test_abandono_puntua_cero` (AC-PS08)
- `test_puntuacion_por_encima_de_cien_se_clampa` (AC-PS09)
- `test_sin_personal_inyectado_trato_neutro`

---

## Out of Scope

- La media de la jornada y su cierre (004).
