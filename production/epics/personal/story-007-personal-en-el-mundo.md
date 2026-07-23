# Story 007: Personal en el mundo — tu equipo en el HUD 🎉 (HITO VISIBLE)

> **Epic**: Personal / Agentes
> **Status**: Ready
> **Layer**: Core (instanciación) + Presentation (HUD del esqueleto)
> **Type**: UI
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/staff-agents.md` (Player Fantasy — "mi equipo"; Visual: estado del agente siempre visible)
**Requirement**: `TR-staff-002` *(parcial — exposición del estado; el HUD real de plantilla/mercado es UI/HUD #11 con UX previo)*
**Governing ADRs**: ADR-0001 (primario — la UI lee y escucha; nunca muta)
**ADR Decision Summary**: el HUD del esqueleto hace pull de los getters + escucha las señales de personal; ninguna lógica en la UI.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: HUD por código (Labels en CanvasLayer, patrón reloj/saldo/llegadas).

**Control Manifest Rules (Presentation)**:
- Required: la UI lee estado y escucha el bus; nunca muta. Dibujo en `_process`. — ADR-0001
- Required: respaldo daltónico — texto además del color.

---

## Acceptance Criteria

*(Historia de instanciación + presentación; evidencia ADVISORY con sign-off del usuario.)*

- [ ] Personal instanciado en `Main` (name "Personal" = clave de save), cableado (bus/economía/config) y con los **puestos estándar registrados** (dotación del esqueleto).
- [ ] **La plantilla provisional de Economía se sustituye por agentes REALES**: los "2 ag_doc + 1 ag_odac" del hook `PLANTILLA_INICIAL` pasan a ser 3 Agentes con nombre y atributos, y la nómina que cobra Economía sale de sus salarios efectivos (F1). **⚠️ Decisión propuesta (aprobar al implementar):** plantilla inicial = 3 agentes de atributos medios (3/3/3/3) → nómina 60+60+70 = **190 €/día, idéntica a la actual** (cero cambio de balance en el arranque).
- [ ] El HUD muestra **"Plantilla: N · Nómina: X €/día"** y la **incidencia del día** si la hay ("Hoy falta: [nombre] ([puesto])" / "Plantilla al completo").
- [ ] Suite completa en verde (sin regresiones — en particular los tests del HUD/mundo de Tiempo, Economía y Demanda).

---

## Implementation Notes

- Main: instanciar tras Economía y Demanda; registrar los puestos abstractos estándar (p. ej. doc_1,
  doc_2 tipo `puesto_doc_general`; odac_1 tipo `puesto_odac`), crear la plantilla inicial (nombres del
  pool de config), asignarla a los puestos y retirar el hook `PLANTILLA_INICIAL`/`fijar_plantilla` en
  favor de `fijar_salarios_dia` (enmienda de la 006).
- HUD: bloque nuevo bajo el de Demanda — pull de `plantilla.size()` + suma de salarios; incidencias vía
  las señales de la 004/005 (o pull del parte del día — decidir al implementar, lo más simple).
- **HITO VISIBLE** (regla de la sesión): al terminar, avisar al usuario y **ABRIR LA VENTANA**. Guion de
  demo: ver la plantilla y la nómina en el HUD; acelerar a 3× y cruzar varias medianoches hasta ver una
  ausencia ("Hoy falta: …") — con `base_ausencia` 3 % y 3 agentes, ~1 baja cada ~11 días de juego; si
  la demo lo necesita, subir el knob en `personal.tres` EN VIVO para enseñarla y devolverlo (los knobs
  están para eso).
- Validación previa headless + suite completa antes de abrir la ventana.

---

## Out of Scope

- El **mercado de contratación en pantalla**, el panel de plantilla y la bandeja de incidencias: son
  **UI/HUD #11** y requieren `/ux-design` antes (condición 3 del gate de Producción).
- Contratar/despedir desde el HUD (misma razón — hoy solo por API/tests).
- Retratos, divisas de rango, VFX (art bible §3 + `/asset-spec` — condición 2 del gate).

---

## QA Test Cases

*Verificación manual (tipo UI) — evidencia + sign-off.*

- **Manual 1 — el equipo existe**: Setup: lanzar ventana. Verify: "Plantilla: 3 · Nómina: 190 €/día" en el HUD. Pass: números correctos y legibles, sin solapes.
- **Manual 2 — la nómina real**: Setup: cruzar una medianoche a 3×. Verify: el saldo baja 190 € (ahora calculados desde los agentes reales). Pass: mismo comportamiento económico que antes del cambio.
- **Manual 3 — una ausencia visible**: Setup: (si hace falta, knob de ausencia subido en vivo). Verify: "Hoy falta: [nombre]" aparece al cruzar la medianoche y desaparece al reincorporarse. Pass: el aviso se entiende sin explicación.
- **Automatizado (humo)**: suite completa → Exit code 0.

---

## Test Evidence

**Story Type**: UI (ADVISORY) — requiere **sign-off del usuario**.
**Required evidence**: `production/qa/evidence/personal-hud-[fecha].md` + PNG + sign-off explícito.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (nómina real + persistencia) — DONE antes de empezar.
- Unlocks: cierre del epic Personal → Sprint 2 (Construcción / Flujo).
