# Story 006: El solar visible — TileMapLayer, escenas y montaje inicial "de oficio"

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core (instanciación) + Presentation (capa visual del esqueleto)
> **Type**: UI
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO1, CO2, CO11, Visual Requirements) + §Interactions
**Requirement**: `TR-construction-001` (rejilla = TileMapLayer) + `TR-construction-003` (puestos/objetos = PackedScene, no tiles)
**Governing ADRs**: ADR-0004 (primario — ⚠️ post-cutoff), ADR-0001 (secundario — la UI lee, nunca muta)
**ADR Decision Summary**: una capa `TileMapLayer` por función (suelo ya existe en Main; se añade
`salas/paredes`); salas pintadas con `set_cell` iterando el rect; puestos/objetos = `PackedScene`
instanciadas con `instantiate()` y posicionadas con `map_to_local(celda)` — NUNCA lógica en tiles.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (post-cutoff: `TileMapLayer` — verificar CADA llamada contra
`docs/engine-reference/godot/modules/tilemap-2d.md` antes de usarla)
**Engine Notes**: `TileMap` DEPRECADO — prohibido. `set_cell(coords, source_id, atlas_coords)`;
`map_to_local` devuelve el CENTRO de la celda.

**Control Manifest Rules (Core/Presentation)**:
- Required: TileMapLayer por función; puestos = PackedScene con `instantiate()`. — ADR-0004
- Required: color por servicio CON respaldo de texto/forma (daltónicos). — art bible §mood
- Forbidden: lógica de puesto en un tile; `TileMap`. — ADR-0004

---

## Acceptance Criteria

- [ ] La capa visual refleja el MODELO (001): salas pintadas en un `TileMapLayer` propio (color por
      servicio Doc/ODAC/espera + etiqueta de texto), puestos y asientos como escenas placeholder
      (formas/colores, cero arte) posicionadas con `map_to_local`.
- [ ] **El montaje inicial pasa a estar CONSTRUIDO de verdad**: oficina Doc + `doc_1`/`doc_2` + sala de
      espera Doc con asientos + oficina ODAC + `odac_1` — el registro a mano de `main.gd`
      (registrar_puesto directo) se retira en favor del layout real. **⚠️ Decisión propuesta (aprobar al
      implementar): el layout inicial viene pagado "de oficio"** (coste 0 al arranque — la DGP entrega
      la comisaría montada) → saldo 3000 € y nómina 190 € INTACTOS (cero cambio de balance).
- [ ] **Main reordenado**: Construcción se instancia ANTES que Personal (invariante de carga — story 005);
      los 3 agentes se asignan a los puestos del layout real; suite completa en verde (sin regresiones).
- [ ] Demoler en el modelo borra el visual (celdas de sala restauradas, escena liberada con
      `queue_free`) — el visual NUNCA diverge del modelo (una sola fuente de verdad).

---

## Implementation Notes

- Nodo visual DENTRO de Construccion (o hermano controlado por él): `TileMapLayer` "Salas" con un
  TileSet generado por código (patrón del suelo de Main: tile plano por servicio — Doc azulado, ODAC
  naranja apagado, espera neutra; paleta sobria del art bible §mood provisional).
- Escenas placeholder por código (patrón del prototipo): `puesto.tscn`-equivalente generado en código
  (ColorRect/Polygon2D + Label del tipo) — el arte real llegará tras el art bible (condición 2 del gate;
  NO adelantar arte).
- El montaje inicial se define como DATOS (layout por defecto en código de Main o config), se construye
  por la API real (`construir_sala`/`construir_elemento` con **coste 0 "de oficio"** — flag interno
  `gratis:=true` SOLO para el arranque) y produce los ids compat `doc_1`/`doc_2`/`odac_1`.
- Evidencia: captura del solar montado (el sign-off del usuario se hace UNA vez, con la 007 — misma
  ventana).

---

## Out of Scope

- El ratón, el preview fantasma y el modo construcción interactivo (007).
- Arte real, VFX de obra, audio (art bible + Feedback #12).

---

## QA Test Cases

*Manual (tipo UI) + humo automatizado.*

- **Humo**: arranque headless de Main limpio; suite completa exit 0 (los tests de Main/Personal/HUD no
  se resienten del reordenado Construcción→Personal).
- **Manual (captura para el doc de evidencia; sign-off conjunto en 007)**: Setup: lanzar ventana.
  Verify: salas visibles con color+etiqueta, 2 ventanillas Doc + 1 ODAC + asientos en la espera;
  "Plantilla: 3 · Nómina: 190 €/día" y saldo 3000 intactos. Pass: se distingue cada sala sin leer
  código y el balance de arranque no cambió.

---

## Test Evidence

**Story Type**: UI (ADVISORY)
**Required evidence**: captura en `production/qa/evidence/construccion-hud-[fecha].md` (doc compartido
con la 007; sign-off del usuario al cierre de la 007).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (persistencia y orden de carga) — DONE antes de empezar.
- Unlocks: Story 007 (el modo construcción interactivo sobre esta capa visual).
