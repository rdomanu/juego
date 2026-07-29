# Story 002: El precio de la hora extra lo elige el jugador

> **Epic**: Bienestar #13
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-29 — escrita a posteriori (implementada en f738c53)

## Context

**Nota de proceso**: esta story se escribe DESPUÉS de la implementación, al cerrar el epic Bienestar #13. El trabajo ya estaba hecho y testeado en el commit `f738c53` (2026-07-28) antes de redactar este documento. Los Acceptance Criteria de abajo describen lo que YA se cumple, verificado contra el diff real y la suite de tests.

**GDD**: pendiente (mismo origen que la story 001 — petición directa del usuario, 2026-07-28) · `production/epics/bienestar/EPIC.md`
**Governing ADRs**: ADR-0001 (Personal posee el cansancio; la conversión pago→cansancio es suya), ADR-0003 (los knobs y su rango, del `.tres`, nunca hardcodeados)

**Engine**: Godot 4.6 | **Risk**: LOW — aritmética (`lerp`/`clamp`) y una señal más; sin API de motor.

---

## Decisiones de diseño (cerradas 2026-07-28)

**La petición literal:** *"el pago por hora de peonadas se podría cambiar con un slider... por defecto cansa 1,5 pero si se paga más esa penalización va bajando. habría que calcular cuál es el coste máximo, para evitar pagarles 1000 euros por hora"*.

**1. El techo de 30 €/h sale de los números del propio juego, no es un redondo cualquiera:**

| Concepto | Cálculo | Resultado |
|---|---|---|
| Salario ordinario de un `ag_doc` | 60 €/día ÷ 6,5 h | **9,23 €/hora** |
| Lo que genera atendiendo | ~5 DNI/h × 12 € × retorno DGP (~0,30) | ~18 €/h |
| Con buena mezcla de trámites | | **20–30 €/h** |

**30 €/h es donde la hora extra deja de dar beneficio**: por encima pagas por el privilegio de que trabajen, no por su rendimiento. El suelo, 15 €/h, es la peonada reglamentaria que ya existía (Documentación #8, doc-003).

**2. El tope evita cifras absurdas; no impide una mala decisión.** Dentro de `[15, 30]` el jugador puede perder dinero si quiere — el sistema no juzga la decisión económica, solo pone un límite.

**3. Pagar más cansa menos — la conversión vive en Personal, no en Documentación.** Documentación decide y comunica *cuánto se paga*; **Personal** decide *qué le hace eso al cuerpo del agente*, porque el cansancio es su estado (ADR-0001). El puente es `generosidad_peonada()` (0-1: 0 = convenio pelado, 1 = techo), que Personal traduce con `lerp` entre el recargo completo (1,5) y ninguno (1,0).

**4. El coste ya no vive en el catálogo.** El viejo caché perezoso `_peonada_eur_hora` (leído de `costes_global`) se retira: dos fuentes para el mismo número era riesgo, no ventaja.

---

## Acceptance Criteria

- [x] **AC-BI07** `[Unit]` — GIVEN el rango por defecto `[15, 30]` THEN `peonada_eur_hora` arranca en **15** con `generosidad_peonada() == 0.0`; al subirlo a 30, `generosidad_peonada() == 1.0`.
- [x] **AC-BI08** `[Unit]` — GIVEN un valor fuera de rango (1000 o 1) THEN `fijar_peonada_eur_hora()` clampa al techo o al suelo (con aviso): nadie paga 1000 €/h ni menos del convenio.
- [x] **AC-BI09** `[Unit]` — GIVEN un cierre con 3,5 h extra y 2 agentes THEN `coste_peonada_estimado()` escala con el precio: 105 € a 15 €/h, **210 €** (el doble) a 30 €/h.
- [x] **AC-BI10** `[Integration]` — GIVEN un cambio de precio THEN `peonada_cambiada(eur_hora, generosidad)` se emite una vez por valor distinto; fijar el mismo valor dos veces no repite el aviso.
- [x] **AC-BI11** `[Integration]` — GIVEN una partida guardada con un precio elegido THEN `save()`/`load_state()` lo conservan, saneado al rango vigente por si un reequilibrado lo estrecha.
- [x] **AC-BI12** `[Unit]` — GIVEN generosidad 0 / 0,5 / 1 THEN `Personal.mult_cansancio_efectivo()` es **1,5 / 1,25 / 1,0** (`lerp` entre recargo completo y ninguno).
- [x] **AC-BI13** `[Unit]` — GIVEN generosidad 1,0 (pago al techo) THEN una hora de peonada cansa **exactamente igual** que una hora normal — misma barra de cansancio acumulada.
- [x] **AC-BI14** `[Unit]` — GIVEN una generosidad fuera de `[0,1]` (5,0 o -3,0) THEN se clampa sin romper la fórmula (nunca cansa menos de 1,0 ni más de 1,5).

---

## Implementation Notes

- **`ConfigDocumentacion`**: knobs `peonada_eur_hora` (15,0, arranque), `peonada_eur_hora_min` (15,0, convenio), `peonada_eur_hora_max` (30,0, techo razonado arriba). Todos `@export` (ADR-0003).
- **`Documentacion`**: `fijar_peonada_eur_hora(eur)` clampa al rango vigente (avisa si corrigió) y emite `peonada_cambiada` solo si cambió de verdad; `generosidad_peonada()` = `(peonada_eur_hora - min) / (max - min)` clampado (rango degenerado → 1.0). **Retirado** el caché del catálogo (`_peonada_eur_hora` / `_cache_catalogo_listo` / `_asegurar_catalogo()`): `coste_peonada_estimado()` y `coste_peonada_por_ventanilla()` leen ahora `peonada_eur_hora` directo. Se serializa en `save()`.
- **`Personal`**: `_generosidad_peonada` (privado, default 0,0) + `fijar_generosidad_peonada()` (clamp 0-1) + `mult_cansancio_efectivo()` = `lerpf(mult_cansancio_horas_extra, 1.0, _generosidad_peonada)`. `cansar()` usa `mult_cansancio_efectivo()` en vez del knob fijo cuando `en_horas_extra` es `true`.
- **`Economia`**: `fijar_peonada_eur_hora(euros)` sobrescribe el valor de partida del catálogo.
- **`Main`**: conecta `_documentacion.peonada_cambiada` a `_al_cambiar_peonada`, que reparte el dato a Economía y a Personal — **el único canal** por el que viaja el precio, como `horario_cambiado`.
- **Panel H**: slider nuevo con el efecto en llano ("cansa un 25 % más" / "cansa como una hora normal"), no el multiplicador crudo.

---

## Out of Scope

- Reequilibrar el rango `[15, 30]` a la luz de la demo → decisión del usuario tras jugar con él.
- La sala de descanso y el disparador de "se levanta a descansar" → story 003 (ya en `3a4322a`).
- Verlo en pantalla (quién está de café, HUD de cansancio) → story 004 (ya en `bb4b7bd`/`6442505`).

---

## QA Test Cases

`tests/integration/documentacion/documentacion_peonada_test.gd`
- **AC-BI07** `test_el_precio_arranca_en_el_convenio_y_se_puede_subir_hasta_el_tope`
- **AC-BI08** `test_nadie_puede_pagar_mil_euros_la_hora_ni_bajar_del_convenio`
- **AC-BI09** `test_pagar_mas_sale_mas_caro_en_la_cuenta_del_dia`
- **AC-BI10** `test_el_precio_avisa_a_quien_le_afecta`
- **AC-BI11** `test_el_precio_elegido_sobrevive_al_guardado`

`tests/unit/personal/personal_cansancio_test.gd`
- **AC-BI12** `test_con_el_pago_minimo_la_hora_extra_cansa_lo_maximo`, `test_a_medio_camino_el_recargo_es_intermedio`
- **AC-BI13** `test_pagando_el_tope_la_hora_extra_cansa_como_una_normal`
- **AC-BI14** `test_la_generosidad_se_clampa_a_su_rango`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/documentacion/documentacion_peonada_test.gd` (5 tests nuevos) + `tests/unit/personal/personal_cansancio_test.gd` (4 tests nuevos).

**Status**: [x] Passing — **suite completa 559/559, exit 0** (9 tests nuevos de esta story; verificado en el commit `f738c53`, 2026-07-28). Arranque headless limpio.

---

## Dependencies

- Depends on: Story 001 (la barra de cansancio y `mult_cansancio_horas_extra` que aquí se reescala)
- Unlocks: Story 003 (sala de descanso) y Story 004 (verlo en pantalla) — ambas ya implementadas
