# Story 002: Ingresos — retorno DGP e ingreso instantáneo por trámite

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (E2 ingresos · E7 retorno data-driven · F1/F2; AC-E01..E04)
**Requirement**: `TR-economy-001` (ingreso instantáneo al oír `tramite_completado`)

**ADR Governing Implementation**: ADR-0001
**ADR Decision Summary**: ingreso **instantáneo** al oír `tramite_completado` (señal de aviso del bus);
Economía **posee la fórmula** F1, Datos posee los parámetros (`retorno_dgp_min/max` en `Costes`), Paciencia
posee la satisfacción (aquí **provisional**: `sat_cierre_doc` fija en 50 = `sat_inicial`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pura aritmética + una conexión de señal. Lee del catálogo real vía `Datos.obtener`.

**Control Manifest Rules (Core)**:
- Required: valores del catálogo por `id` (read-only); ingreso instantáneo al oír `tramite_completado`.
- Forbidden: `randi()`/`randf()` global (aquí no hay azar); mutar definiciones del catálogo.

---

## Acceptance Criteria

*Valores exactos del GDD:*

- [x] **AC-E01**: `dni` (tarifa 12) con `sat=50` → `saldo += 3,6` (12 × 0.30) al instante, y
      `ingreso_doc_dia += 3,6`.
- [x] **AC-E02**: `retorno_dgp(0) == 0.15`; `retorno_dgp(100) == 0.45` (params del catálogo `costes_global`).
- [x] **AC-E03**: `sat=150` → clamp a 100 → retorno 0.45 (nunca fuera de [min, max]).
- [x] **AC-E03b**: el retorno usa `sat_cierre_doc` (fija toda la jornada): cambiarla a mitad de jornada con
      `fijar_sat_cierre()` NO afecta a los ingresos ya acreditados, y hasta que se llame, TODOS los trámites
      aplican el mismo retorno.
- [x] **AC-E04**: un `tramite_completado` con id de **DenunciaODAC** (p. ej. `lesiones`) → el saldo **NO**
      cambia (ODAC no genera ingreso) y **sin warnings espurios** del catálogo.

---

## Implementation Notes

- `retorno_dgp(sat) = min + (max − min) × clamp(sat, 0, 100) / 100` con `retorno_dgp_min/max` leídos de
  `Datos.obtener(&"Costes", &"costes_global")` (una vez, cacheado).
- **`sat_cierre_doc: float = 50.0`** (provisional = `sat_inicial`, Paciencia #10) + `fijar_sat_cierre(v)`
  (la llamará Paciencia al `nuevo_dia` con prioridad 10 — ANTES del cierre de Economía a 20 ✓ ADR-0001).
- **Distinguir Doc vs ODAC sin warnings**: al `_ready` cachear los ids de `Datos.obtener_todos(&"TramiteDoc")`
  en un Dictionary local → el handler comprueba pertenencia O(1) SIN llamar `obtener` con ids de denuncia
  (que haría `push_warning` por cada denuncia atendida). Documentarlo.
- Handler: `_al_tramite_completado(id, agente)` conectado a la señal del bus (firma real del bus manda).
- `ingreso_doc_dia` se acumula aquí; su reset es del cierre (003). Emite `saldo_cambiado`.

## Out of Scope

- Reset diario y cobros (003); mordida de préstamos sobre `ingreso_doc_dia` (004); Paciencia real (su epic).

## QA Test Cases

*Logic — `tests/unit/economia/economia_ingresos_test.gd`. Bus espía propio; emitir `tramite_completado`
manualmente; catálogo real (los valores 12/0.15/0.45 son los del `.tres`).*

- `test_dni_a_sat50_abona_3_60` (AC-E01, `is_equal_approx`).
- `test_retorno_extremos_015_y_045` (AC-E02).
- `test_sat_fuera_de_rango_clampa` (AC-E03).
- `test_retorno_constante_intra_jornada` (AC-E03b).
- `test_denuncia_odac_no_genera_ingreso` (AC-E04).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_ingresos_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (economia_ingresos_test.gd 5/5; suite 173/173, 2026-07-23)

## Dependencies

- Depends on: **Story 001** (nodo/config/saldo) + catálogo real (Datos, Complete).
- Unlocks: 003 (usa `ingreso_doc_dia`), 004 (la mordida % la usa), 007 (el saldo visible se mueve).

## Notas de gotchas del proyecto

Preload por ruta; floats con `is_equal_approx`; el bus espía es instancia propia (aislamiento).

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
