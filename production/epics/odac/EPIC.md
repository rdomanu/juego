# Epic: ODAC / Denuncias

> **Layer**: Feature
> **GDD**: design/gdd/odac.md
> **Architecture Module**: ODAC #9 (configurador de la operativa de denuncias)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories odac`
> **Manifest Version**: 2026-07-22

## Overview

ODAC (Oficina de Denuncias y Atención al Ciudadano) recibe las **denuncias de la ciudadanía** —de un
hurto o una estafa a lo más grave: VioGén, desaparecidos, agresiones— y las tramita **24 horas al día**.
A diferencia de Documentación, **ODAC no cobra un euro**: es pura obligación (Pilar 1). Su "producto" no
es dinero sino **reputación**: atender rápido, sin dejar a nadie tirado y **priorizando lo urgente** sube
la satisfacción de la comisaría, que a su vez alimenta el retorno DGP de Documentación.

Lo que ODAC **posee** es la operativa del servicio: el **orden de prioridad** (las Prioritarias —VioGén,
desaparecidos, agresión sexual, atraco— se atienden **antes** que las Normales) y la **reconfiguración
en caliente** de los puestos (cambiar sobre la marcha qué denuncias atiende cada ventanilla, 4 modos).
Aporta además el `peso_prioridad` con el que Paciencia #10 pondera su media de satisfacción, y **recibe
la carga de las reclamaciones** que genera un mal servicio — trabajo autoinfligido que no paga nadie.

**La tensión de diseño que activa este epic:** ODAC solo cuesta. Es el contrapeso moral del juego — el
jugador puede desatenderlo para ganar más dinero, y pagarlo en reputación.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Bus de eventos + tick + orden determinista | Configura la prioridad de Flujo (F7) y la reconfiguración por **API pública**; el desempate sigue siendo determinista | LOW |
| ADR-0003: Formato del catálogo (.tres) | Los 13 tipos de denuncia, su prioridad y sus duraciones salen del **catálogo** | LOW |
| ADR-0002: Guardado / serialización | El modo de cada puesto reconfigurado se serializa (grupo `Persist`) | LOW |

**Engine Risk del epic: LOW.** Lógica y configuración sobre sistemas ya cerrados.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-odac-001 | Configura prioridad (Flujo F7) + reconfiguración en caliente de puestos (4 modos) | ADR-0001 ✅ · ADR-0003 ✅ |
| TR-odac-002 | Aporta `peso_prioridad` a Paciencia; recibe carga de `reclamacion` | ADR-0001 ✅ |

**Requisitos sin ADR: ninguno.**

## Interfaces que hereda (ya implementadas en Core)

- `Flujo.reconfigurar_puesto(puesto_id, tipos)` — solo tipos `reconfigurable`; ya implementado y testeado
  en flujo-006, **a la espera de dueño**: este epic define los 4 modos que lo usan.
- Prioridad ODAC en la selección F7 de Flujo (FIFO + prioridad), ya operativa.
- Operativa 24 h (ODAC no cierra por horario) — ya respetada por el horario provisional de Doc.
- Cross-facts registrados: `peso_prioridad_prioritaria` 2.5 · `prob_reclamacion` 0.4 · el tipo
  `tramite_reclamacion` (30 min, Normal, sin tarifa) · `mult_nocturno_odac` 0.5.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/odac.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Los 4 modos de reconfiguración son operables por el jugador y se guardan en la partida

## Next Step

Run `/create-stories odac` to break this epic into implementable stories.
