# Story 006: Compromiso de servicio y gestión en caliente

> **Epic**: Flujo de Personas y Colas
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/flow-queues.md` (FL8, FL9, FL10, States B notas + Edge Cases de cierre) +
`construction-layout.md` AC-CO13 (el diferido)
**Requirement**: `TR-flow-003` *(parcial — reglas de interrupción)* + cierre del hueco AC-CO13
**Governing ADRs**: ADR-0001 (primario — el compromiso de servicio es regla de simulación; la Pausa
congela por construcción)
**ADR Decision Summary**: nada se interrumpe a medias: cerrar/reconfigurar/demoler ESPERAN al fin de
la atención en curso. La Pausa no necesita código (Tiempo no empuja el tick).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Core)**:
- Required: en Pausa el jugador SÍ gestiona (abrir/cerrar/asignar) — solo la simulación se congela. — FL8
- Forbidden: expulsar a una Persona en Llamada/atención (compromiso de servicio — regla dura).

---

## Acceptance Criteria

- [ ] **AC-FL15** `[Unit]` — GIVEN una atención con 5 min restantes y turnos por asignar WHEN el juego está en **Pausa** THEN la atención **no avanza** y **no se asignan** nuevos turnos (FL8).
- [ ] **AC-FL25** `[Unit]` — GIVEN una atención con 5 min restantes WHEN se pausa y luego se reanuda THEN continúa con **5 min exactos** (sin reinicio ni pérdida).
- [ ] **AC-FL16** `[Integration]` — GIVEN `puesto_odac` atendiendo `viogen` WHEN se reconfigura a solo `estafa` THEN la atención de `viogen` **NO se interrumpe** y la **próxima** llamada solo considera `estafa` (FL9).
- [ ] **AC-FL17** `[Integration]` — GIVEN un puesto Atendiendo WHEN el jugador lo **cierra** THEN **termina** la atención en curso, **luego** pasa a Cerrado, y **no llama a nuevas** (FL10).
- [ ] **AC-FL18** `[Integration]` — GIVEN una Persona en **Llamada** o **En atención** con la paciencia agotada WHEN se evalúa el abandono THEN **NO abandona** (compromiso de servicio).
- [ ] **AC-FL24** `[Integration]` — GIVEN Documentación en su hora de cierre con cola ya admitida WHEN cierra THEN **vacía la cola admitida** (hook de peonada) y **cierra la puerta a nuevas** (última admisión).
- [ ] **AC-CO13** `[Integration]` — GIVEN un puesto **atendiendo** WHEN se demuele THEN **termina** la atención y luego se demuele (cierra el diferido de Construcción).

---

## Implementation Notes

- **Cerrar en caliente (FL10/AC-FL17)**: `cerrar_puesto(id)` con atención en curso → marca
  `cierre_pendiente`; al emitir `tramite_completado` el puesto pasa a Cerrado en vez de Libre.
- **Reconfigurar (FL9/AC-FL16)**: `reconfigurar_puesto(id, atenciones)` — SOLO si el TipoPuesto es
  `reconfigurable` (catálogo); cambia el filtro para la PRÓXIMA llamada (override local sobre las
  `atenciones_admitidas` del tipo; la operativa completa la poseerá ODAC #9).
- **Compromiso (AC-FL18)**: `forzar_abandono(persona) -> bool` — la API que Paciencia #10 llamará:
  en Esperando (fuera/dentro) → estado Abandonando + emitir `abandono(persona)` (señal YA en el bus)
  + liberar plaza; en Llamada/En atención → false (no abandona). Paciencia NO existe aún: en este
  epic nadie la llama salvo los tests (interfaz provisional documentada).
- **AC-CO13 (enmienda a Construcción)**: `demoler_elemento` consulta a Flujo si el puesto está
  Atendiendo (`usar_flujo(nodo)` inyectable en Construcción, o consulta vía Personal... decidir la
  dirección LIMPIA al implementar respetando capas: propuesta — Construcción pregunta a un callable
  `puede_demoler` que Main cablea a Flujo; sin cableado → demuele directo, compat tests). Con
  atención en curso → demolición PENDIENTE que se ejecuta al terminar (mismo mecanismo que el
  cierre pendiente).
- **Cierre de Documentación (AC-FL24)**: ⚠️ decisión propuesta (aprobar al implementar): en el MVP
  Flujo detecta el cruce del cierre Doc (870 min, patrón `_detectar_cierre_doc` de Demanda) y
  aplica: puertas cerradas a NUEVAS admisiones Doc (las fichas de Demanda ya no llegan — Demanda ya
  corta el grifo a las 14:30; esto cubre a las que estaban en camino) + la cola ADMITIDA se sigue
  atendiendo hasta vaciarse (la peonada/coste extra es hook de Economía F4 vía
  `registrar_horas_extra` — SOLO el hook, Horarios #13 lo hará bien). Migrar a Documentación #8.

---

## Out of Scope

- La curva/umbral de paciencia (Paciencia #10 — aquí solo `forzar_abandono`).
- La peonada real y horarios (Documentación #8 / Horarios #13 — aquí el hook).

---

## QA Test Cases

*Del qa-plan-sprint-2 (hilo principal, modo lean).*

- **AC-FL15/25**: mundo real en árbol (Tiempo PAUSA, patrón DM11): atención a 5 min → 30 frames →
  sigue en 5.0 exactos y 0 llamadas nuevas; reanudar a 1× → termina a los 5 min de juego.
- **AC-FL16**: puesto_odac real atendiendo viogen → reconfigurar a [estafa] → la atención acaba y
  emite; la siguiente llamada con cola [viogen, estafa] toma estafa.
- **AC-FL17**: cerrar durante atención → emite al terminar → estado Cerrado → cola compatible no
  vacía y 0 llamadas nuevas.
- **AC-FL18**: forzar_abandono en Esperando → true + señal abandono + libera plaza (entra el de
  fuera); en Llamada y En atención → false, 0 señales.
- **AC-FL24**: cruce de 870 con 3 admitidas Doc y 1 puesto → se atienden las 3 (horas extra
  registradas en Economía vía el hook) y no se admite ninguna nueva tras el cruce.
- **AC-CO13**: demoler_elemento (Construcción real cableada) sobre puesto Atendiendo → NO
  desaparece aún; al emitir tramite_completado → demolido + reembolso + agente al banquillo.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flujo/flujo_gestion_caliente_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (flujo completo con aforo) — DONE antes de empezar.
- Unlocks: Story 007 (persistencia del estado completo).
