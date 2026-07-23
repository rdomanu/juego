# Story 003: Cierre de cuentas diario — recargo → gastos → reset (prioridad 20)

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (E3 gastos · E5 deuda con recargo · E6 ciclo · F3/F4/F5/F6;
AC-E05/E06/E09/E10/E10b/E10c)
**Requirement**: `TR-economy-002` (cobros al `nuevo_dia` en orden determinista recargo→gastos→reset)

**ADR Governing Implementation**: ADR-0001
**ADR Decision Summary**: Economía se registra al evento ordenado con
**`EventBus.registrar_ordenado(&"nuevo_dia", 20, ...)`** (orden crítico: Paciencia 10 cierra `sat` ANTES de
que Economía cobre a 20). Dentro del handler, el orden interno es fijo (F6): **(1) recargo sobre la deuda de
APERTURA → (2) gastos del día → (3) reinicio de acumuladores**.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: lógica pura; el dispatcher del bus ya existe (epic event-bus Complete).

**Control Manifest Rules (Core)**:
- Required: cobros al `nuevo_dia` en su prioridad (20); salarios/peonada del catálogo por `id`; determinismo.
- Forbidden: cobrar con `.emit`/conexión simple (saltaría el orden crítico); hardcodear salarios/peonada.

---

## Acceptance Criteria

*Valores exactos del GDD:*

- [x] **AC-E05**: plantilla `[ag_doc, ag_doc, ag_odac]` (60+60+70 del catálogo) → al cierre `saldo −= 190`.
- [x] **AC-E06**: 3 h extra registradas con `peonada_eur_hora=15` (catálogo) → `gasto_peonada = 45`.
- [x] **AC-E09**: saldo apertura +50, nómina 190 → cierre deja `saldo = −140` **sin recargo ese día** (la
      apertura era positiva) y el gasto voluntario queda bloqueado (gate false).
- [x] **AC-E10**: apertura −500, sin obligaciones, interés 0.02 → recargo 10 → `saldo = −510`.
- [x] **AC-E10b**: dos cierres consecutivos desde −500 sin obligaciones → −510 → **−520,20** (compuesto).
- [x] **AC-E10c**: apertura +20, nómina 190 → recargo 0 → `saldo = −170`; el recargo de esos −170 es del día
      siguiente (orden F6: recargo ANTES de gastos).
- [x] **AC (reset)**: tras el cierre, `ingreso_doc_dia = 0` y las horas extra acumuladas se reinician.

---

## Implementation Notes

- Registro: en `_ready` (árbol real) `EventBus.registrar_ordenado(&"nuevo_dia", 20, _al_nuevo_dia)`; en
  tests se llama `_al_nuevo_dia()` directo (patrón de las stories de Tiempo) o vía `disparar_ordenado` del
  bus espía.
- **Plantilla provisional** (Personal no existe): `fijar_plantilla(ids: Array[StringName])`; salario por id
  = `Datos.obtener(&"TipoAgente", id).salario_dia_eur` (el `salario_dia_efectivo` con prima de Personal F1
  llegará con su epic — hook documentado; MVP provisional = base del catálogo).
- **Peonadas** (Horarios no existe): `registrar_horas_extra(horas: float)` acumula `_horas_extra_dia`;
  gasto = `peonada_eur_hora` (de `Costes` en el catálogo) × horas. Economía solo aplica el coste (E3).
- Paso (2) suma también `penalizacion_prestamos_dia` — hasta la 004, esa función devuelve 0 (hook).
- Los gastos obligatorios se descuentan AUNQUE dejen el saldo negativo (E5 — no pasan por el gate).

## Out of Scope

- Penalización de préstamos real (004); estados/señales de deuda (005); balance mensual (006).

## QA Test Cases

*Logic — `tests/unit/economia/economia_cierre_test.gd`. Determinista; valores del catálogo real.*

- `test_nomina_estandar_descuenta_190` (AC-E05) · `test_tres_horas_extra_son_45` (AC-E06)
- `test_entrar_en_rojos_sin_recargo_el_primer_dia` (AC-E09) · `test_recargo_sobre_apertura` (AC-E10)
- `test_recargo_compuesto_dos_dias` (AC-E10b) · `test_orden_recargo_antes_de_gastos` (AC-E10c)
- `test_reset_de_acumuladores_al_cierre`

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_cierre_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (economia_cierre_test.gd 7/7; suite 173/173, 2026-07-23)

## Dependencies

- Depends on: **001** (saldo/config) + **002** (`ingreso_doc_dia` que aquí se reinicia).
- Unlocks: 004 (inserta su penalización en el paso 2), 005 (estados tras el cierre), 006 (acumuladores de mes).

## Notas de gotchas del proyecto

Floats con `is_equal_approx` (−520,20 exige tolerancia); preload por ruta; el orden interno del cierre es
un solo método secuencial (no señales internas) para blindar el determinismo.

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
