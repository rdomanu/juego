# Epic: Documentación

> **Layer**: Feature
> **GDD**: design/gdd/documentation.md
> **Architecture Module**: Documentación #8 (configurador de la operativa de Doc)
> **Status**: In Progress
> **Stories**: 5 — creadas el 2026-07-26
> **Manifest Version**: 2026-07-22

## Overview

Documentación es el servicio de tramitación de **DNI, Pasaporte y TIE**: la faceta de Secretaría del
edificio y, en el MVP, **la única fuente de ingresos** de la comisaría. No inventa el flujo ni la gente
(eso son Flujo #4 y Demanda #5): lo que **posee** es la **operativa del servicio** — su **horario de
apertura** (base 08:00–14:30, ampliable con un slider hasta las 20:00 pagando **peonada** por las horas
extra), su **política de cita** (el MVP arranca sin cita) y la **última admisión** (hasta qué minuto se
da número antes de cerrar). Es un **Feature configurador**: fija los horarios que **Flujo ejecuta** al
abrir y cerrar los puestos y la ventana que **Demanda respeta** al generar llegadas.

**Deuda que este epic salda:** el horario de Documentación vive hoy **provisionalmente dentro de Flujo**
(knobs `apertura_doc_min` 480 / `cierre_doc_min` 870, enmienda del usuario del 2026-07-25). Este epic se
lo lleva a su dueño legítimo y convierte lo fijo en **configurable por el jugador** — el slider de
horario es la primera decisión económica de verdad: más horas = más ingresos = más peonada.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden determinista | Configura a Flujo/Demanda por **API pública** y eventos del bus; nada de mutar el estado de otro sistema | LOW |
| ADR-0003: Formato del catálogo (.tres) | Horarios, tarifas y eventos de la División salen del **catálogo**, nunca hardcodeados | LOW |
| ADR-0002: Guardado / serialización | El horario elegido por el jugador y los eventos activos se serializan (grupo `Persist`) | LOW |

**Engine Risk del epic: LOW.** Sin APIs post-cutoff de Godot: es lógica de simulación, configuración y
eventos sobre cimientos ya rodados.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-doc-001 | Configura horario / última admisión que Flujo **ejecuta** y Demanda **respeta** | ADR-0001 ✅ · ADR-0003 ✅ |
| TR-doc-002 | Eventos de la División (estacionales) que amplían horario | ADR-0001 ✅ · ADR-0003 ✅ |

**Requisitos sin ADR: ninguno.**

## Interfaces que hereda (ya implementadas en Core)

- `Flujo.puerta_doc_abierta()` + knobs `apertura_doc_min`/`cierre_doc_min` — **a migrar a este epic**.
- `Flujo.fijar_hook_horas_extra()` → `Economia.registrar_horas_extra` (peonada, ya cableado).
- Cross-facts registrados: `apertura_doc_min` 480 y `cierre_doc_min` 870 son **el mismo hecho** que
  `ventana_doc_inicio/fin` de Demanda (`design/registry/entities.yaml`) — si cambia uno, cambia el otro.
- `margen_ultima_admision_min` 15 (registro, propiedad de este GDD).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/documentation.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- **El horario provisional se ha retirado de Flujo** y los tests de Flujo siguen en verde
- El registro de entidades refleja el nuevo dueño de los cross-facts de horario

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | El servicio y su reloj — núcleo, config y F3 | Logic | Ready | ADR-0003 |
| 002 | La mudanza — el horario deja de vivir prestado en Flujo | Integration | Ready | ADR-0001 |
| 003 | La peonada — alargar la tarde cuesta dinero (F1/F2) | Integration | Ready | ADR-0001 |
| 004 | Los eventos de la División + guardar el servicio | Integration | Ready | ADR-0003 |
| 005 | El panel del servicio — el slider de horario (HITO VISIBLE) | UI | Ready | ADR-0001 |

**Cobertura de los 16 AC del GDD:** 001 → AC-DC01/07/10 · 002 → AC-DC02/03/13 · 003 → AC-DC04/05/06/08 ·
004 → AC-DC09/10/11/16 · 005 → AC-DC14/15. **AC-DC12** (trámite → ingreso) ya está implementado y
testeado por Economía/Flujo; se re-verifica en la demo de la 005.

**Decisiones de diseño aprobadas por el usuario (2026-07-26), aplicadas en las stories:**
1. **La peonada cambia de significado** (story 003): se cobra por **ampliar el horario** (DO4), no por los
   minutos de rezagados; terminar a los rezagados pasa a costar **moral, no euros** (DO5). El hook
   provisional de Flujo se retira.
2. **"Desmotiva" en el MVP** = efecto ligero **real**: −1 de motivación (suelo 1, una vez por agente y día).
   El modelo pleno sigue en Bienestar #13/#15.
3. **Los eventos de la División son deterministas por mes** (no aleatorios): vacaciones (meses 7–8) y
   colapso de extranjería (mes 2).

## Next Step

Run `/story-readiness production/epics/documentacion/story-001-servicio-reloj-config.md` →
`/dev-story` para implementar. Las stories van **en orden**: cada una depende de la anterior.
