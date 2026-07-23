# Story 002: El mercado de fichajes (candidatos, contratar, despedir)

> **Epic**: Personal / Agentes
> **Status**: Implemented — 7/7 tests en verde (pendiente `/story-done`)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24

## Context

**GDD**: `design/gdd/staff-agents.md` (PA4, PA6, F1, F5 + edges de contratación/mercado)
**Requirement**: `TR-staff-001` (mercado con RNG sembrado)
**Governing ADRs**: ADR-0002 (primario — toda la aleatoriedad por `RNGService` sembrado), ADR-0001 (secundario)
**ADR Decision Summary**: candidatos deterministas por semilla (`randi_rango`); el gate de gasto es de Economía (E4).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. Nunca `randi()` global (footgun registrado: cualificar con RNGService).

**Control Manifest Rules (Core)**:
- Required: aleatoriedad (mercado) por `RNGService` sembrado. — ADR-0002
- Required: **Economía**: gasto voluntario solo con `puede_pagar()` (gate E4). — ADR-0001
- Forbidden: `randi()`/`randf()` global.

---

## Acceptance Criteria

- [ ] **AC-PE06** `[Unit]` — GIVEN la misma `semilla` WHEN se genera el mercado THEN los candidatos son **idénticos** (F5 determinista: nombres, atributos, rangos, salarios).
- [ ] **AC-PE05** `[Integration]` — GIVEN caja insuficiente WHEN se intenta contratar THEN se **rechaza** (gate E4); el candidato NO entra en plantilla.
- [ ] *(edge GDD)* — GIVEN el mercado agotado/recién refrescado THEN "sin candidatos" es un estado válido, no un error.
- [ ] *(edge GDD)* — GIVEN más agentes que puestos THEN se permite (banquillo); el único límite es la nómina.
- [ ] *(PA6)* — GIVEN un agente despedido THEN sale de la plantilla, libera su puesto y deja de contar en nómina; coste de despido 0 (MVP).

---

## Implementation Notes

- **F5 — generación de candidato** (todo vía RNGService, orden de llamadas FIJO → determinista):
  cada atributo = **media redondeada de 2 tiradas** `randi_rango(1,5)` (distribución triangular →
  sesgo al centro, cracks raros — implementa el `sesgo_candidatos` del GDD);
  `nombre` = elegido del pool de config (`randi_rango` sobre el Array; Open Q5 del GDD: pool fijo MVP);
  `tipo` = alterna/tirada entre `ag_doc`/`ag_odac`; `salario_dia` sale de F1 (story 001).
- **⚠️ Decisión propuesta (el GDD no lo fija — aprobar al implementar):** el mercado puede ofrecer
  **Oficiales** con `prob_candidato_oficial` (knob, semilla 0.2; Mando = misma tirada sesgada). Sin esto
  no habría forma de fichar al Oficial de las stories 005+.
- **⚠️ Decisión propuesta (F5 ambigua — aprobar al implementar):** al **contratar** se retira SOLO el
  contratado (el resto del mercado sigue); la **regeneración completa** es por calendario
  (`refresco_mercado_jornadas`, contando `nuevo_dia`). "Se refresca al contratar" del GDD se interpreta
  como "el hueco no se repone hasta el refresco".
- **Contratar**: `contratar(indice_candidato) -> bool` — gate `_economia.puede_pagar(salario_dia)`
  (inyección `usar_economia(eco)`, patrón usar_bus; en tests, una Economía real con saldo controlado).
  **Sin coste puntual** (Open Q4 del GDD: MVP solo nómina) → el gate NO cobra, solo comprueba (y en
  números rojos `puede_pagar` ya devuelve false — E5). El contratado entra a plantilla como `&"libre"`.
- **Despedir**: `despedir(agente) -> void` — libera puesto si tenía, sale de plantilla. (Si está
  atendiendo, el compromiso de servicio es contrato de Flujo — nota, no bloquea.)
- Señal de aviso al bus (enmienda menor, proponer al implementar): `agente_contratado` /
  `agente_despedido` para Feedback — **opcional MVP** (el HUD 007 hace pull).

---

## Out of Scope

- Story 003: asignar a puestos. · Story 006: que la nómina real llegue a Economía. · UI del mercado (UI/HUD #11, con UX previo — condición del gate).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-PE06**: Given `RNGService.sembrar(42)` → generar mercado (4 candidatos) → re-sembrar(42) → regenerar → Then listas idénticas campo a campo. Edge: semilla distinta → mercado distinto.
- **Sesgo al centro**: Given semilla fija y 400 candidatos → Then la frecuencia de atributo 3 > la de 1 y la de 5 (triangular); atributos siempre en [1,5].
- **AC-PE05**: Given Economía real con saldo 10 y candidato de salario 60 → `contratar` → Then false, plantilla sin cambios. Given saldo 3000 → Then true y el candidato pasa a plantilla (estado libre) y sale del mercado.
- **Mercado vacío**: Given 4 contrataciones seguidas → Then mercado vacío y `contratar` sobre índice inválido devuelve false con aviso (sin crash).
- **Refresco**: Given `refresco_mercado_jornadas=3` → simular 3 `nuevo_dia` → Then el mercado se regenera completo (determinista con la semilla en curso).
- **Despido**: Given agente asignado a un puesto → `despedir` → Then fuera de plantilla y el puesto sin dotar.
- **Banquillo**: Given 5 contratados y 3 puestos → Then los 5 en plantilla (2 libres), sin error.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/personal/personal_mercado_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (7 tests; suite total 236/236, exit 0 — 2026-07-24)

---

## Dependencies

- Depends on: Story 001 (Agente + F1) — DONE antes de empezar.
- Unlocks: Story 003 (asignación).
