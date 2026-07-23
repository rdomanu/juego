# Story 004: Préstamos del Comisario — strikes, penalización híbrida y devolución

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (E9 préstamo del Comisario · F6/F8; AC-E11/E12/E12b/E14f/E14g/E14h)
**Requirement**: `TR-economy-003` (parte de préstamos del estado financiero)

**ADR Governing Implementation**: ADR-0001
**ADR Decision Summary**: dos contadores — **`prestamos_usados`** (histórico, fija el límite y el game
over; NUNCA baja) y **`prestamos_vivos`** (los que pesan a diario). Penalización diaria híbrida
(fija + % de `ingreso_doc_dia`) integrada en el paso (2) del cierre (003). Señal de aviso
**`prestamo_pedido`** nueva en el EventBus (ampliación menor documentada).

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: knobs del config (importe 1500 · fija 30 · pct 0.20 · max 3); determinismo del cierre.
- Forbidden: que devolver un préstamo "recupere" el strike (`prestamos_usados` no baja NUNCA).

---

## Acceptance Criteria

*Valores exactos del GDD:*

- [x] **AC-E11**: `pedir_prestamo()` con `usados=0` → `saldo += 1500`, `usados=1`, `vivos=1`, se emite
      `prestamo_pedido` y queda el hook "−valoración de jefes" (comentario/TODO al sistema futuro #16).
- [x] **AC (límite)**: con `usados == num_prestamos_max` → `pedir_prestamo()` se **rechaza** (false).
- [x] **AC-E12**: `vivos=2`, `ingreso_doc_dia=230` → penalización al cierre `= 2×(30+0.20×230) = 152`.
- [x] **AC-E12b**: `vivos=1`, `ingreso_doc_dia=0` → penalización `= 30` (solo la fija; la mordida auto-escala).
- [x] **AC-E14f**: `usados=2, vivos=2, saldo=1600` → `saldar_prestamo()` → `saldo=100`, `vivos=1`,
      `usados=2` (el strike NO se recupera).
- [x] **AC-E14g**: saldado un préstamo → el siguiente cierre ya NO aplica su penalización.
- [x] **AC-E14h**: `saldo=1400 (<1500)` o `vivos=0` → `saldar_prestamo()` se **rechaza**, saldo intacto.
- [x] **AC (preventivo)**: pedir en positivo se permite y gasta strike igualmente (Edge Case del GDD).

---

## Implementation Notes

- `pedir_prestamo() -> bool` / `saldar_prestamo() -> bool` (la devolución NO pasa por el gate `puede_pagar`
  — exige literalmente `saldo ≥ importe`, GDD E9; en rojos no se puede saldar porque saldo < 0 < 1500).
- `_penalizacion_prestamos_dia() -> float` = `vivos × (fija + pct × ingreso_doc_dia)` — sustituye el hook 0
  de la 003; se calcula ANTES del reset de `ingreso_doc_dia` (orden F6 del cierre).
- **Bus**: añadir `signal prestamo_pedido(usados: int, vivos: int)` a `event_bus.gd` (ampliación menor
  documentada, mismo trato que `velocidad_cambiada`). El hook de valoración de jefes es un comentario TODO
  (#16), NO una señal todavía.
- `saldar` emite `saldo_cambiado`; ambos mantienen el invariante `vivos ≤ usados ≤ max` (assert defensivo).

## Out of Scope

- Rescate por insolvencia/modal/gracia (005) — aquí el préstamo es solo la acción voluntaria y su coste.

## QA Test Cases

*Logic — `tests/unit/economia/economia_prestamos_test.gd`.*

- `test_pedir_prestamo_inyecta_y_cuenta_strike` (AC-E11, con espía de `prestamo_pedido`)
- `test_pedir_al_limite_se_rechaza` · `test_penalizacion_hibrida_dos_vivos` (AC-E12)
- `test_penalizacion_dia_sin_ingresos_solo_fija` (AC-E12b) · `test_saldar_no_recupera_strike` (AC-E14f)
- `test_saldado_deja_de_penalizar` (AC-E14g) · `test_saldar_sin_caja_o_sin_vivos_se_rechaza` (AC-E14h)
- `test_preventivo_en_positivo_gasta_strike`

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_prestamos_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (economia_prestamos_test.gd 7/7; suite 173/173, 2026-07-23)

## Dependencies

- Depends on: **003** (su penalización vive dentro del cierre) + **002** (`ingreso_doc_dia`).
- Unlocks: **005** (el rescate de insolvencia usa `pedir_prestamo`).

## Notas de gotchas del proyecto

Preload por ruta; floats con tolerancia; el bus espía propio verifica `prestamo_pedido` sin tocar el autoload.

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
