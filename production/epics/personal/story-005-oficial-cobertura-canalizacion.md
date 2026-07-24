# Story 005: El Oficial — cobertura automática y canalización (F6/F7)

> **Epic**: Personal / Agentes
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24 — cerrada (commit 6296a52; ver Cierre — ⚠️ errata F6 del GDD)

## Context

**GDD**: `design/gdd/staff-agents.md` (PA8, PA9, F6, F7 + edges del Oficial)
**Requirement**: `TR-staff-003` *(parcial — la reacción del mando a las ausencias)*
**Governing ADRs**: ADR-0001 (primario — avisos por el bus; corre dentro del handler ordenado de la 004)
**ADR Decision Summary**: la cobertura/canalización ocurre en el MISMO `nuevo_dia` prio 30, justo tras marcar ausentes — un solo hueco del dispatcher, sin nuevas prioridades.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff.

**Control Manifest Rules (Core)**:
- Required: los avisos cross-system van por señales del bus; Personal nunca llama a la UI. — ADR-0001
- Forbidden: azar fuera de RNGService (aquí NO hay azar nuevo: la cobertura es determinista por reglas).

---

## Acceptance Criteria

- [x] **AC-PE14** `[Integration]` — GIVEN Oficial (Mando 4) y 2 bajas con agentes libres compatibles THEN **cubre 2** (`floor(Mando/2)`); con Mando 1 → cubre 1 (F6). *(Implementado `ceil(Mando/2)` — ver Cierre.)*
- [x] **AC-PE15** `[Integration]` — GIVEN **sin** Oficial y una baja THEN el puesto queda **vacante** (sin cobertura automática — cierre del AC iniciado en la 004).
- [x] **AC-PE16** `[Integration]` — GIVEN Oficial y N incidencias del servicio THEN se **agrupan en 1 aviso** (parte del día); sin Oficial → **N avisos** individuales (PA9).
- [x] **AC-PE17** `[Integration]` — GIVEN Oficial sin agentes libres que reasignar THEN **escala** al jugador (la incidencia va marcada como "requiere decisión"; no cubre — F7).

---

## Implementation Notes

- **Cobertura (F6)**, dentro de `_al_nuevo_dia` tras marcar ausentes, POR SERVICIO: si hay Oficial
  asignado en el servicio Y **presente** (no ausente él mismo — edge del GDD): presupuesto de cobertura
  `floor(Mando/2)`; por cada puesto vacante (en orden estable de registro): buscar agente **libre**
  compatible (`puestos_operables`) → estado `&"cubriendo"` + ocupar el puesto (el titular ausente
  conserva la titularidad; al reincorporarse, el cubridor vuelve a `&"libre"` — el reingreso de la 004
  debe deshacer coberturas ANTES de reincorporar).
  **⚠️ Simplificación MVP (aprobar al implementar):** solo se reasignan agentes LIBRES; el "mueve de
  otro puesto menos crítico" del GDD F6 queda como tuning futuro (necesita una noción de criticidad que
  hoy no existe).
- **Canalización (F7)**: acumular las incidencias del día por servicio. CON Oficial → **una** emisión
  agrupada con el resumen `{servicio, ausencias, cubiertas, escaladas}`; las cubiertas cuentan como
  autoresueltas (el GDD pide `autoresueltas ≈ Mando` — con F6 cubriendo `floor(Mando/2)` el orden de
  magnitud casa; calibración = playtest, Open Q6). SIN Oficial → una emisión individual por incidencia
  (lo hace la 004).
- **Enmienda del bus (proponer al implementar):** señal `parte_personal(resumen: Dictionary)` para el
  aviso agrupado (complementa la `incidencia_personal` individual de la 004). Oyentes: UI (bandeja),
  Feedback. Set exacto a aprobar como las enmiendas anteriores.
- **Escalada (F7)**: vacante sin candidato o presupuesto agotado → incidencia con `escalada=true`
  (el jugador decidirá: reasignar a mano, peonada — futuro—, o dejar vacante).

---

## Out of Scope

- La UI de la bandeja de incidencias (UI/HUD #11 — condición del gate: UX antes).
- La peonada como respuesta a la escalada (Horarios #13, V-Slice).
- Mover agentes de puestos "menos críticos" (tuning futuro de F6).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean). Ausencias forzadas con knobs boundary (prob 0/1) → determinista.*

- **AC-PE14**: Given Oficial Mando 4 en Doc + 2 titulares ausentes + 2 libres ag_doc → Then 2 puestos cubiertos (`puesto_dotado` true, cubridores en estado cubriendo). Given Mando 1 → solo 1 cubierto.
- **AC-PE15**: Given mismo escenario SIN Oficial → Then 0 coberturas, puestos vacantes.
- **AC-PE16**: Given bus espía, Oficial y 3 ausencias en Doc → Then exactamente 1 `parte_personal` (con ausencias=3) y 0 individuales de ese servicio; sin Oficial → 3 `incidencia_personal`.
- **AC-PE17**: Given Oficial Mando 5 y 1 baja SIN libres compatibles → Then 0 coberturas y el parte lleva `escaladas=1`.
- **Oficial ausente**: Given el propio Oficial ausente → Then no cubre (las bajas del servicio quedan vacantes) — edge del GDD.
- **Reincorporación deshace cobertura**: Given titular vuelve al día siguiente → Then el cubridor pasa a libre y el titular recupera su puesto.
- **Cobertura respeta compatibilidad**: Given libre ag_odac y vacante doc → Then NO se usa (puestos_operables manda).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/personal/personal_oficial_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde — 8/8 PASS.

---

## Dependencies

- Depends on: Story 004 (ausencias marcadas) — DONE antes de empezar.
- Unlocks: Story 006 (persistencia del estado completo).

---

## Cierre (2026-07-24)

Implementada en hilo principal; test 8/8 a la primera. **⚠️ ERRATA del GDD cazada:** el texto de F6
dice `floor(Mando/2)`, pero su propia tabla de salida (Mando 1–2 → 1 · 3–4 → 2 · 5 → 3) y AC-PE14
("Mando 1 → cubre 1") corresponden a **`ceil(Mando/2)`** — implementado fiel a la TABLA (con floor un
Oficial de Mando 1 cubriría 0). *Backlog: corregir el texto de F6 en staff-agents.md.* Simplificación
MVP **ratificada**: solo cubren agentes LIBRES. Enmienda del bus `parte_personal(resumen)` aplicada.
Diseño: coberturas en `_coberturas` SEPARADO de `_asignaciones` (el titular ausente conserva su
entrada; el cubridor trabaja de prestado con `puesto_id` propio vacío) — el gate FL4 y los
modificadores responden por el agente OPERATIVO.
