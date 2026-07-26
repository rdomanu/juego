# Story 004: F3 — la satisfacción del día y su cierre

> **Epic**: Paciencia y Satisfacción
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — implementada + test 10/10 en verde

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

- [x] **AC-PS10** `[Unit]` — GIVEN 1.ª jornada sin datos THEN `sat_cierre_doc = sat_cierre_odac = 50`.
- [x] **AC-PS11** `[Integration]` — GIVEN varias visitas WHEN `nuevo_dia` THEN `sat_cierre` = media
      ponderada de sus puntuaciones y el acumulador se **resetea**.
- [x] **AC-PS12** `[Unit]` — GIVEN ODAC con una VioGén (peso 2.5) y una Normal (1.0) THEN la media
      **pondera 2.5:1**.
- [x] **AC-PS13** `[Integration]` — GIVEN jornada sin visitas de ODAC WHEN `nuevo_dia` THEN
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

## Cierre (2026-07-26)

Implementada en hilo principal (Opus 5).

- **F3**: acumuladores por servicio (suma ponderada + peso total → **memoria constante** aunque pasen
  400 personas al día), `sat_actual_de` (la media viva de hoy), `sat_cierre_de` (la de ayer, la que
  manda en el dinero) y `cerrar_jornada`.
- **F5** `sat_global`: media ponderada por VOLUMEN de visitas — solo HUD; Economía cobra por servicio.
- **Pesos**: Doc 1.0; ODAC lee la `prioridad` del catálogo real → Prioritaria pesa **2.5**. Tipo
  desconocido → 1.0 (nunca se infla un peso por un dato que falta).
- **Handler ordenado** `nuevo_dia` **prioridad 10**, por delante de Economía (20): el cierre fija el
  `sat_cierre` ANTES de que se cobre con él. El orden ya estaba previsto en un comentario de Economía.
- Knobs nuevos: `sat_inicial` 50 · `peso_prioridad_prioritaria` 2.5 (cross-facts del registro).
- Test `paciencia_cierre_jornada_test.gd` **10/10**, incluido el del ORDEN (espías en prio 9/11/20).

**🐛 Bug cazado al implementar (no estaba en ningún AC):** el bucle de abandonos llamaba a `olvidar()`
nada más echar a la persona — es decir, **borraba el peor dato de la jornada justo antes de contarlo**.
La satisfacción habría salido sistemáticamente inflada y ningún test de los AC lo habría visto. Ahora
quien se marcha queda en estado Abandonando y la recoge `_purgar_terminadas`, que **anota su 0** en la
media antes de soltarla.

**Decisión más allá de los AC:** `sat_actual_de` de un servicio sin visitas hoy devuelve **el cierre de
ayer**, no un 0 — mientras no haya datos nuevos, lo que sabemos es lo de ayer (y evita que el HUD
enseñe un 0 alarmante cada amanecer).
