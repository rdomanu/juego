# Story 001: El solar — núcleo, config y validación de colocación (F6)

> **Epic**: Construcción y Distribución
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/construction-layout.md` (CO1, CO2, CO3, CO4, F6 + edges de colocación)
**Requirement**: `TR-construction-001` *(parcial — modelo lógico de la rejilla; la capa visual
`TileMapLayer` llega en la 006)* + `TR-construction-002` *(parcial — la validación; el ratón llega en la 007)*
**Governing ADRs**: ADR-0004 (primario — rejilla y validación por celdas), ADR-0003 (secundario — tipos del catálogo por id)
**ADR Decision Summary**: la rejilla se modela por celdas `Vector2i`; la validación de colocación es
determinista (límites del edificio + solapamiento + área mínima). La LÓGICA no depende de nodos visuales.

**Engine**: Godot 4.6 | **Risk**: LOW (esta story es modelo puro; el TileMapLayer visual es de la 006)
**Engine Notes**: sin API post-cutoff aquí — `Rect2i`/`Vector2i` estables.

**Control Manifest Rules (Core)**:
- Required: validar colocación con límites del edificio + solapamiento; salas = iterar `Vector2i`. — ADR-0004
- Required: leer `TipoPuesto`/`TipoSala` del catálogo por id, read-only (`Datos.obtener`). — ADR-0003
- Forbidden: lógica en tiles; `TileMap` (deprecado). — ADR-0004

---

## Acceptance Criteria

- [ ] **AC-CO01** `[Unit]` — GIVEN una sala dentro del edificio, sin solapar, área ≥ mínimo WHEN se valida THEN **válida**; si solapa o sale del edificio → **inválida** (F6).
- [ ] **AC-CO03** `[Unit]` — GIVEN un área < `area_min` WHEN se dibuja THEN **rechazada** (CO3).
- [ ] *(AC-CO02, parte de regla)* — GIVEN un tipo de puesto WHEN se valida su celda THEN solo es válido **dentro de una sala cuyo `puestos_admitidos` lo incluya** (CO4); fuera de sala o en sala ajena → inválido.

---

## Implementation Notes

- **Nodo `Construccion`** (`class_name Construccion extends Node`, nodo del mundo — arq. §3.4, patrón
  Economía/Demanda/Personal) + **`ConfigConstruccion`** (Resource) + `tools/build_config_construccion.gd`
  → `datos/config/construccion.tres`. Knobs: `coste_por_celda` 20 · `densidad_asientos` 0.7 ·
  `pct_reembolso` 0.5 · `area_min_sala` 4 (2×2) · `coste_mover` 0 · `edificio_columnas`/`edificio_filas`
  (⚠️ decisión propuesta: el tamaño del edificio vive en ConfigConstruccion en el MVP; migrará a
  `Escenario` cuando haya multi-comisaría). `aplicar_config` con clamps + fallback (patrón del proyecto).
- **Modelo LÓGICO del layout** (sin nodos visuales): `_salas: {sala_id -> {tipo_sala_id, rect: Rect2i}}`
  y `_elementos: {elemento_id -> {tipo, id_catalogo, celda: Vector2i, sala_id, coste_pagado}}`. Ids
  generados con contador propio; los del montaje inicial serán `doc_1`/`doc_2`/`odac_1` (compat — 006).
- **`validar_sala(tipo_sala_id, rect) -> bool`** (F6): dentro del edificio ∧ no solapa NINGUNA sala ∧
  `rect.get_area() >= area_min_sala`. **`validar_elemento(id_catalogo, celda) -> bool`**: celda dentro de
  una sala compatible (`TipoSala.puestos_admitidos` para puestos; sala de espera para asientos) ∧ celda
  libre de otros elementos. Deterministas, sin estado oculto.
- Tipos de catálogo por id (`Datos.obtener(&"TipoSala"/&"TipoPuesto", id)`); id inexistente → inválido
  con aviso (patrón Datos).

---

## Out of Scope

- Story 002: pagar/cobrar (aquí NO se muta saldo ni se construye — solo validación y modelo).
- Story 006: la capa visual (TileMapLayer/escenas). · Story 007: ratón y preview.

---

## QA Test Cases

*Escritos por el hilo principal (modo lean) desde qa-plan-sprint-2.*

- **AC-CO01**: Given edificio 24×13 y sala existente en Rect2i(0,0,3,3) → validar sala (5,5,3,3) → true;
  validar (2,2,3,3) (solapa) → false; validar (22,11,4,4) (se sale) → false.
- **AC-CO03**: Given area_min_sala=4 → validar sala 1×3 (área 3) → false; 2×2 (área 4) → true (frontera).
- **AC-CO02 (regla)**: Given sala_documentacion en (0,0,4,4) y sala_odac en (6,0,4,4) → validar
  `doc_general` en celda (1,1) → true; en (7,1) → false; en celda sin sala → false.
- **Solape de elementos**: Given `doc_general` ya en (1,1) → validar otro en (1,1) → false.
- **Config**: knobs negativos → clamp con aviso; .tres real carga y valida (patrón Economía/Demanda).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/construccion/construccion_validacion_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (primera del epic; Foundation completa).
- Unlocks: Story 002 (construir y pagar).
