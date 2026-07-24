# Story 007: Modo construcción con ratón — preview fantasma 🎉 (HITO VISIBLE)

> **Epic**: Construcción y Distribución
> **Status**: Complete
> **Layer**: Core (entrada) + Presentation (preview/overlay)
> **Type**: UI
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24 — cerrada con SIGN-OFF del usuario tras 4 rondas de feedback (ver Cierre)

## Context

**GDD**: `design/gdd/construction-layout.md` (CO3, CO8, States "Planificando", Visual/UI Requirements)
**Requirement**: `TR-construction-002` (ratón↔celda: `local_to_map`/`map_to_local`, preview fantasma + validación)
**Governing ADRs**: ADR-0004 (primario — ⚠️ post-cutoff), ADR-0001 (secundario — la UI ordena por API pública, nunca muta el modelo directamente)
**ADR Decision Summary**: la celda bajo el cursor = `local_to_map(get_local_mouse_position())` del
TileMapLayer; el preview valida EN VIVO con `validar_sala`/`validar_elemento` (001) y solo confirma si
es válido; construir/demoler pasan SIEMPRE por la API (002/004) — la UI no toca el modelo.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (post-cutoff: conversión ratón↔celda de `TileMapLayer` —
verificar contra `docs/engine-reference/godot/modules/tilemap-2d.md`)
**Engine Notes**: mouse-driven puro pero SIN hover-only (technical-preferences: que un gamepad futuro
no exija rediseño); teclas de modo como atajo.

**Control Manifest Rules (Presentation)**:
- Required: la UI lee estado y ordena por API pública; dibujo en `_process`. — ADR-0001
- Required: verde/rojo SIEMPRE con texto/icono además del color (daltónicos).
- Forbidden: que la UI mute el modelo o el saldo directamente (todo por construir_/demoler_/mover_).

---

## Acceptance Criteria

*(Historia de interacción; evidencia ADVISORY con sign-off del usuario.)*

- [x] **Modo construcción on/off** (botón del HUD + atajo B): al entrar, overlay/atenuación del mundo;
      al salir, todo vuelve.
- [x] **Colocar elemento**: seleccionar tipo (mini-barra provisional con nombre y coste LEÍDOS de
      Datos) → preview fantasma sigue al cursor celda a celda, **verde/rojo según F6 EN VIVO** (+ texto
      "Válido"/"No válido"/"Sin caja") → clic confirma SOLO si es válido → cobra (gate E4) y aparece.
- [x] **Dibujar sala**: arrastrar rectángulo con **área y coste en vivo** (F1); soltar confirma si
      válido (AC-CO03 visible: área < mínimo en rojo). *(+ ENMIENDA: pegado al mismo tipo = AMPLIAR.)*
- [x] **Demoler**: herramienta de demolición con clic; sala con contenido → **confirmación de cascada**
      (nº de elementos + reembolso total antes de ejecutar — AC-CO12 visible).
- [x] Suite completa en verde y **sign-off del usuario con la ventana abierta** (colocó/demolió con el
      saldo a la vista a lo largo de 4 rondas de prueba).

---

## Implementation Notes

- Entrada por `_unhandled_input` (patrón Main): clic izq = confirmar, clic dcho/Esc = cancelar
  herramienta. Celda = `local_to_map(get_local_mouse_position())` del TileMapLayer de salas.
- Preview = nodo semitransparente reutilizado (NO instanciar por frame — cero alloc en _process);
  refresco del color/texto solo al CAMBIAR de celda (guarda de celda anterior, patrón cruces).
- La mini-barra de construcción es ANDAMIO provisional (condición 3 del gate: la UI real espera a
  /ux-design) — botones sencillos con focus_mode NONE (gotcha del Espacio), lista de tipos LEÍDA del
  catálogo (nunca hardcodear costes/nombres).
- Guion de demo (regla de la sesión — ABRIR VENTANA): en Pausa (CO12), colocar una 3ª ventanilla Doc
  (saldo baja 500), asignarle... (la asignación desde UI NO existe aún — solo mostrar el puesto
  registrado en el HUD de plantilla); demolerla (reembolso +250); dibujar una sala pequeña y ver el
  coste en vivo. Validación previa headless + suite completa ANTES de abrir la ventana.

---

## Out of Scope

- El panel de construcción REAL y bandejas (UI/HUD #11 con /ux-design previo — condición 3 del gate).
- Asignar agentes desde la UI (epic UI futuro). · Mover con ratón (API existe — atajo de UI futuro,
  decisión propuesta: diferir el gesto de mover a UI/HUD #11).
- Arte/VFX/audio de obra (art bible + Feedback).

---

## QA Test Cases

*Manual (tipo UI) — evidencia + sign-off. El humo automatizado lo cubren las stories 001-005.*

- **Manual 1 — preview honesto**: Setup: modo construcción, seleccionar `doc_general`. Verify: verde
  SOLO dentro de la oficina Doc en celda libre; rojo (con texto) al solapar, salir del edificio o sin
  caja. Pass: el color+texto coinciden SIEMPRE con lo que pasa al hacer clic.
- **Manual 2 — pagar y reembolsar**: colocar ventanilla (saldo −500 visible) → demolerla (saldo +250).
  Pass: números exactos en el HUD.
- **Manual 3 — sala en vivo**: arrastrar 3×3 → "9 celdas · 380 €" en vivo; 1×2 → rojo por área mínima.
- **Manual 4 — cascada**: demoler la oficina Doc → aviso con contenido y reembolso total; cancelar NO
  demuele; confirmar demuele todo (y los agentes quedan al banquillo en el HUD de plantilla).
- **Automatizado (humo)**: suite completa → Exit code 0.

---

## Test Evidence

**Story Type**: UI (ADVISORY) — requiere **sign-off del usuario**.
**Required evidence**: `production/qa/evidence/construccion-hud-[fecha].md` + PNG + sign-off explícito
(doc compartido con la 006).
**Status**: [x] `construccion-hud-2026-07-24.md` + PNG — **SIGN-OFF ✅ del usuario (2026-07-24)**.

---

## Dependencies

- Depends on: Story 006 (capa visual + montaje inicial) — DONE antes de empezar.
- Unlocks: cierre del epic Construcción → `/create-stories flujo` (C2-4).

---

## Cierre (2026-07-24)

Implementada en hilo principal (`src/main/modo_construccion.gd` + 5 getters en Construcción).
**4 rondas de feedback del usuario con la ventana abierta, todas corregidas antes del sign-off**
(detalladas en la evidencia): (1) barra invisible — bug de anclas `grow_vertical` (toda barra
anclada abajo debe crecer HACIA ARRIBA); (2) HUD tapando el mundo → **rediseño a barra inferior
estilo tycoon** (petición del usuario); (3) botones Asiento/Demoler fuera de pantalla →
`HFlowContainer` (toolbars con textos de catálogo: SIEMPRE flow/scroll); (4) placeholders
tragándose los clics → `MOUSE_FILTER_IGNORE` en Controls decorativos del mundo. **ENMIENDA de
diseño ratificada (petición del usuario): dibujar pegado/solapado a una sala del MISMO tipo la
AMPLÍA** (unión rectangular exacta, cobra solo celdas nuevas; en "L" o tipo distinto → sala aparte)
— implementada en Construcción (002) con 2 tests. Suite final **297/297, exit 0**.
