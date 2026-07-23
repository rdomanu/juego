# Story 004: Nivel de demanda BAJA / MEDIA / ALTA

> **Epic**: Generación de Demanda
> **Status**: Complete (cierre del epic con sign-off, 2026-07-24)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/demand-generation.md` (DG12; UI Requirements — el indicador siempre visible)
**Requirement**: `TR-demand-003` (señal derivada BAJA/MEDIA/ALTA expuesta a UI/Documentación)
*(Texto del requisito en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0001 (señal de aviso en el bus — orden indiferente)
**ADR Decision Summary**: los avisos cross-system van como `signal` nativas del EventBus; la lista central de señales vive documentada en `event_bus.gd`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff.

**Control Manifest Rules (Core)**:
- Required: comunicación cross-system vía EventBus (`signal.emit()`); señal nueva = **enmienda documentada del bus** (mismo procedimiento que `saldo_cambiado` en Economía).
- Required: umbrales **en config** (`demanda.tres`), nunca hardcodeados; la UI leerá texto/umbral de config (GDD UI Requirements).

---

## ⚠️ Enmienda del bus (aprobar con el usuario al implementar)

Añadir a `event_bus.gd` (sección avisos, con doc comment):

```gdscript
## Demanda (story demanda-004): el nivel derivado de demanda de Documentación cambió de tramo.
## nivel ∈ {&"BAJA", &"MEDIA", &"ALTA"} — DG12; brújula futura de la peonada.
signal nivel_demanda_cambiado(nivel: StringName)
```

Revisar que los tests existentes del bus no fijen el número de señales (si lo hacen, alinear).

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM15** `[Unit]` — GIVEN los umbrales de DG12 y un volumen de Documentación X WHEN se clasifica THEN devuelve **BAJA / MEDIA / ALTA** según el tramo correcto.
- [ ] *(derivado)* La señal `nivel_demanda_cambiado` se emite **solo cuando el nivel cambia** de tramo (no en cada recálculo), y existe un getter `nivel_demanda() -> StringName` para lectura pull (UI).

---

## Implementation Notes

- **Métrica clasificada**: la `demanda_dia_doc` **efectiva** de la jornada (incluye `factor_crecimiento_nivel`; desde la 005 incluirá también `mult_estacional` — el nivel que ve el jugador deriva del multiplicador, DG13).
- **Umbrales provisionales en config** (Open Q9, tuning): `umbral_nivel_bajo = 40`, `umbral_nivel_alto = 60`. Regla de bordes (fijarla elimina ambigüedad): `d < 40 → BAJA`; `d ≥ 60 → ALTA`; resto → `MEDIA`. Con las semillas: base 45 → **MEDIA**; verano ×1.5 = 67.5 → **ALTA**; ene-feb ×0.6 = 27 → **BAJA** (los tres tramos son alcanzables — bonito para el playtest).
- **Cuándo recalcular**: al aplicar config/arrancar y en `_al_nuevo_dia` (prio 40, handler de la 003); la 005 añadirá el recálculo tras `nuevo_mes`. Si el tramo cambió → `_bus.nivel_demanda_cambiado.emit(nivel)`.
- Constantes de nivel como `StringName` (`&"BAJA"`…): comparables baratas y serializables como String (006).
- **No emitir en `load_state`** (se restaura sin señal — "cargar sitúa, no reproduce"; se implementa en la 006 pero se deja diseñado aquí).

---

## Out of Scope

- Story 005: los multiplicadores que mueven el nivel entre tramos a lo largo del año.
- Story 007: pintar el indicador en el HUD (con respaldo daltónico texto+color).
- La **rentabilidad €** de la peonada: la posee Economía/Horarios (no MVP de este epic).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-DM15**: Given umbrales 40/60 → When se clasifica d=27 / d=45 / d=67.5 → Then BAJA / MEDIA / ALTA. Edge de bordes: d=40 → MEDIA (≥ bajo), d=60 → ALTA (≥ alto), d=39.999 → BAJA.
- **Señal solo al cambiar**: Given nivel MEDIA → When se recalcula con el mismo volumen 3 veces → Then 0 emisiones; When el volumen pasa a 67.5 → Then exactamente 1 emisión con `&"ALTA"` (capturar con Array).
- **Getter**: `nivel_demanda()` devuelve el tramo vigente sin recalcular efectos laterales.
- Edge: umbrales corruptos (bajo ≥ alto) → clamp con `push_warning` (patrón `_clamp_knob` de Economía).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/demanda/demanda_nivel_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (6 tests — 2026-07-23). Enmienda del bus aplicada (`nivel_demanda_cambiado`).

---

## Dependencies

- Depends on: Story 003 (cableado del bus + handler `nuevo_dia`) — DONE antes de empezar.
- Unlocks: Story 005 (estacionalidad reevalúa el nivel), Story 007 (HUD lo muestra).
