# Epic: Paciencia y Satisfacción

> **Layer**: Feature
> **GDD**: design/gdd/patience-satisfaction.md
> **Architecture Module**: Paciencia #10 (dueño de la escala `sat` 0–100)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories paciencia`
> **Manifest Version**: 2026-07-22

## Overview

Paciencia y Satisfacción es el sistema que **convierte la espera en consecuencia**. Tiene dos caras
acopladas: **(1) la paciencia**, una barra individual de cada persona que espera —empieza llena al coger
turno y se **drena con el tiempo**; si llega a 0 la persona **se marcha** (abandono, ejecutado por Flujo)
dejando mal recuerdo—; y **(2) la satisfacción**, el indicador agregado de la comisaría (**`sat` 0–100**),
que sube cuando la gente sale atendida, a tiempo y con buen **trato** del agente, y baja con cada
abandono, cola desbordada o sala hacinada.

En el MVP esa `sat` se cobra sobre todo vía Economía (**retorno DGP**: sat 0 → vuelve el 15 % de la tasa;
sat 100 → el 45 %) y en el objetivo de eficiencia que dispara el ascenso. Paciencia **posee** la escala
0–100 y la curva de paciencia; ODAC la nutre con su peso de prioridad.

**Por qué importa:** es el sistema que introduce el **fracaso posible**. Hoy la simulación no tiene
presión — nadie se va nunca. Con Paciencia, cada decisión de plantilla, horario y distribución de la
comisaría pasa a tener consecuencias visibles.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden determinista | Escucha eventos de Flujo y **ordena** el abandono por API; se suscribe al tick DESPUÉS de Flujo (orden del ADR: Tiempo → Demanda → Flujo → Paciencia) | LOW |
| ADR-0002: Guardado / serialización + RNG determinista | La barra de cada persona y la `sat` se serializan; la reclamación usa **RNGService** (nunca `randf` propio) | LOW |
| ADR-0003: Formato del catálogo (.tres) | El tipo `reclamacion` y los umbrales salen del catálogo | LOW |

**Engine Risk del epic: LOW.** Todo el riesgo es de **diseño y balance**, no de motor.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-patience-001 | Barra de paciencia por persona; drena con `delta`; Pausa congela; hacinamiento acelera | ADR-0001 ✅ |
| TR-patience-002 | Escucha eventos de Flujo; ordena abandono (`persona_abandona`) al llegar a 0 | ADR-0001 ✅ |
| TR-patience-003 | Cierre de satisfacción al `nuevo_dia`; Economía usa `sat_cierre` **anterior** (ingreso estable intra-jornada) | ADR-0001 ✅ |
| TR-patience-004 | Genera `reclamacion` en ODAC (prob, RNG); sin recursión; empate llamada-vs-abandono → gana llamada | ADR-0001 ✅ · ADR-0002 ✅ |

**Requisitos sin ADR: ninguno.**

## Interfaces que hereda (ya implementadas en Core)

- `Flujo.forzar_abandono(persona)` — **API creada expresamente para este sistema** en flujo-006:
  Esperando → Abandonando + señal `abandono` + libera plaza (entra el de fuera). **Regla dura ya
  implementada y testeada: en Llamada o En atención devuelve `false`** — quien ya fue llamado no abandona
  (resuelve el empate llamada-vs-abandono de TR-patience-004 a favor de la llamada).
- `Economia`: `sat_cierre_doc` de la jornada **anterior** (reconciliación de diseño ya cerrada — el
  ingreso no puede fluctuar dentro del día).
- `Personal.factor_trato_de(puesto)` 0.5–1.5 y `Construccion.aforo_de_servicio()` (hacinamiento).
- Cross-facts registrados: `sat_inicial` 50 · `prob_reclamacion` 0.4 · `peso_prioridad_prioritaria` 2.5 ·
  umbrales de ánimo **66/33** (consistentes con UI y Feedback).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/patience-satisfaction.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- El determinismo A-vs-B sigue pasando **con abandonos y reclamaciones activos**

## Next Step

Run `/create-stories paciencia` to break this epic into implementable stories.
