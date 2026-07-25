# Story 004: F3 — la satisfacción del día y su cierre

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F3, F5)
**Requirement**: `TR-patience-003` (cierre de satisfacción al `nuevo_dia`)
**Governing ADRs**: ADR-0001 (primario — evento ordenado `nuevo_dia`)
**ADR Decision Summary**: `nuevo_dia` es un evento **ordenado** (`disparar_ordenado`): Paciencia debe
cerrar su media **ANTES** de que Economía cobre, porque Economía usa `sat_cierre_doc` para el retorno.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (orden de handlers entre sistemas)
**Engine Notes**: n/a.

**Control Manifest Rules (Feature)**:
- Required: registrar el handler de `nuevo_dia` con **prioridad menor que la de Economía** (Economía
  cobra en prio 20 → Paciencia cierra en **prio 10**). El orden es determinista por diseño. — ADR-0001
- Required: Paciencia **posee** la escala 0-100; ningún otro sistema la calcula. — arquitectura
- Forbidden: dividir sin guarda (jornada sin visitas → mantener el valor anterior, nunca NaN).

---

## Acceptance Criteria

- [ ] **AC-PS10** `[Unit]` — GIVEN 1.ª jornada sin datos THEN `sat_cierre_doc = sat_cierre_odac = 50`.
- [ ] **AC-PS11** `[Integration]` — GIVEN varias visitas WHEN `nuevo_dia` THEN `sat_cierre` = media
      ponderada de sus puntuaciones y el acumulador se **resetea**.
- [ ] **AC-PS12** `[Unit]` — GIVEN ODAC con una VioGén (peso 2.5) y una Normal (1.0) THEN la media
      **pondera 2.5:1**.
- [ ] **AC-PS13** `[Integration]` — GIVEN jornada sin visitas de ODAC WHEN `nuevo_dia` THEN
      `sat_cierre_odac` = el anterior (**sin división por cero**).

---

## Implementation Notes

- `satisfaccion_servicio = Σ(puntuacion_i × peso_i) / Σ(peso_i)` **por servicio** (Doc y ODAC llevan
  acumuladores separados: numerador y denominador, no una lista de visitas — memoria constante).
- **Pesos**: Doc siempre 1.0; ODAC = `peso_prioridad` del tipo de denuncia (Normal 1.0 / Prioritaria
  2.5, cross-fact ya registrado, propiedad de ODAC #9). Mientras ODAC #9 no exista, el peso se lee del
  **catálogo de denuncias** (`prioridad` del tipo) — interfaz provisional, documentar como tal.
- `sat_inicial` 50 (cross-fact registrado) para la primera jornada.
- **F5 `sat_global`** (media ponderada por volumen de visitas) es **solo para el HUD**: Economía nunca
  la usa. Implementar como getter derivado, sin estado propio.
- Exponer `sat_actual_de(servicio)` (la media viva de hoy, para el HUD) y `sat_cierre_de(servicio)`
  (la de ayer, la que manda en el dinero).

---

## Test Cases

`tests/integration/paciencia/paciencia_cierre_jornada_test.gd`
- `test_primera_jornada_sin_datos_sat_50` (AC-PS10)
- `test_cierre_calcula_media_y_resetea_acumulador` (AC-PS11)
- `test_odac_pondera_prioritaria_2_5_a_1` (AC-PS12)
- `test_jornada_sin_visitas_mantiene_el_sat_anterior` (AC-PS13)
- `test_paciencia_cierra_antes_de_que_economia_cobre` (orden de prioridades, con espías 9/11/21)

---

## Out of Scope

- Que ese `sat` mueva el dinero (005).
