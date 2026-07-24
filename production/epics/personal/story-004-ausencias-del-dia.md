# Story 004: Ausencias del día (nuevo_dia, prioridad 30)

> **Epic**: Personal / Agentes
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24 — cerrada (commit 6296a52; ver Cierre)

## Context

**GDD**: `design/gdd/staff-agents.md` (PA7, PA11, F4 + edges de ausencia/pausa)
**Requirement**: `TR-staff-003` (ausencias evaluadas al `nuevo_dia`, RNG determinista)
**Governing ADRs**: ADR-0001 (primario — evento ordenado `nuevo_dia`: **Personal = prioridad 30**, tras Paciencia 10 y Economía 20, antes de Demanda 40), ADR-0002 (secundario — tirada por RNGService)
**ADR Decision Summary**: las ausencias corren en el hueco 30 del dispatcher. Consecuencia de diseño (documentar): la nómina (Economía, prio 20) se cobra ANTES de evaluar ausencias → **el ausente cobra su día** (baja pagada — realista y simple).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff.

**Control Manifest Rules (Core)**:
- Required: `registrar_ordenado(&"nuevo_dia", 30, ...)` — el hueco que ADR-0001 reservó a Personal.
- Required: tirada de ausencia por `RNGService` sembrado (orden de evaluación FIJO = orden de plantilla → determinista). — ADR-0002
- Forbidden: evaluar ausencias en el tick o en Pausa — SOLO al `nuevo_dia` (PA11).

---

## Acceptance Criteria

- [x] **AC-PE13** `[Unit]` — GIVEN RNG sembrado WHEN se evalúan las ausencias del día THEN el resultado es **determinista** (misma semilla + misma plantilla → mismos ausentes).
- [x] **AC-PE15 (parte)** `[Integration]` — GIVEN **sin** Oficial y una baja THEN el puesto queda **vacante**: `puesto_dotado()` pasa a false (pérdida de capacidad real para Flujo).
- [x] **AC-PE19** `[Integration]` — GIVEN el juego en **Pausa** THEN **no** se evalúan ausencias (nada corre fuera del `nuevo_dia`; en Pausa el reloj no avanza → no hay medianoche).
- [x] *(PA7/States)* — GIVEN un ausente WHEN llega el `nuevo_dia` siguiente THEN se **reincorpora** (vuelve a su puesto → `&"asignado"`).

---

## Implementation Notes

- **`_al_nuevo_dia()`** (prio 30), en este orden: (1) **reincorporar** a los ausentes de ayer (estado →
  asignado; su puesto seguía reservado para ellos), (2) recorrer la plantilla en **orden estable** y por
  agente tirar `RNGService.randf() < prob_ausencia(agente)` (F4, story 001) — el orden fijo mantiene el
  determinismo, (3) marcar ausentes (estado `&"ausente"`; su puesto deja de estar dotado SIN
  desasignarlo — la titularidad se conserva), (4) delegar la cobertura/canalización (story 005; aquí,
  sin Oficial, no hay cobertura automática).
- `puesto_dotado()` (story 003) ya contempla el estado: ausente → false.
- **Enmienda del bus (proponer al implementar, patrón `nivel_demanda_cambiado`)**: señal de aviso
  `incidencia_personal(texto: String, puesto: StringName)` — una por ausencia (la agrupación con
  Oficial la introduce la 005). Oyentes: UI/HUD (bandeja), Feedback.
- La Pausa no necesita código aquí: en Pausa el reloj no cruza medianoche → el dispatcher no dispara
  (misma garantía que Demanda DG9). El test lo verifica igualmente.

---

## Out of Scope

- Story 005: cobertura del Oficial (estado cubriendo) y agrupación de incidencias.
- Story 006: serializar el estado de ausencia del día.
- La fatiga dinámica (diferida a Bienestar #13/#15 — PA10).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-PE13**: Given plantilla de 6 agentes (Salud variada) y `sembrar(42)` → evaluar → guardar lista de ausentes → re-sembrar(42) y re-evaluar sobre plantilla idéntica → Then misma lista. Edge: semilla distinta → puede diferir.
- **Forzado determinista**: Given un agente con Salud tal que `prob_ausencia = 1.0` (vía knobs artificiales: `base_ausencia=1.0`) → Then SIEMPRE ausente; con `prob = 0` → nunca. (Boundary values intencionales.)
- **AC-PE15 (parte)**: Given agente asignado a doc_1, sin Oficial, ausencia forzada → Then `puesto_dotado(doc_1)` false y el agente sigue siendo titular (no desasignado).
- **Reincorporación**: Given ausente hoy → siguiente `_al_nuevo_dia` (con prob 0) → Then estado asignado y `puesto_dotado(doc_1)` true.
- **AC-PE19**: Given mundo real en árbol (Tiempo local en PAUSA) → 30 physics frames → Then 0 evaluaciones (patrón del test de Pausa de Demanda).
- **Señal**: Given 2 ausencias forzadas y bus espía → Then 2 emisiones de `incidencia_personal` (sin Oficial: avisos individuales).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/personal/personal_ausencias_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde — 7/7 PASS (incluye test extra de prioridad 30 con espías 29/31).

---

## Dependencies

- Depends on: Story 003 (asignaciones y gate) — DONE antes de empezar.
- Unlocks: Story 005 (el Oficial reacciona a las bajas).

---

## Cierre (2026-07-24)

Implementada en hilo principal; test 7/7 a la primera. **2 micro-decisiones fuera de story,
RATIFICADAS por el usuario: la baja del día no se "cura"** — (a) `asignar` rechaza a un ausente
(rechazo de regla, silencioso) y (b) `desasignar` a un ausente le quita la plaza pero conserva
`&"ausente"` hasta la reincorporación (cierran el exploit de re-dotar el puesto reasignando al
enfermo). Enmienda del bus `incidencia_personal(texto, puesto)` aplicada.
