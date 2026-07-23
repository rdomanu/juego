# Story 006: Balance mensual + serialización (`save()`/`load_state()` + Persist)

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (E6 ciclo · F7 balance; Edge "si se carga una partida";
AC-E16/E18/E19)
**Requirement**: `TR-economy-002` (ciclo mensual) · ADR-0002 (persistencia)

**ADR Governing Implementation**: ADR-0001 (nuevo_mes prioridad **10** de Economía) · ADR-0002 (Persist)
**ADR Decision Summary**: al `nuevo_mes` (vía `registrar_ordenado(&"nuevo_mes", 10, ...)`) se cierra
`balance_mes = ingresos_mes − gastos_mes` (lo consumirá Ascensos). Persistencia con el contrato ya rodado:
`save() -> Dictionary` / `load_state(d)` + grupo `"Persist"` (el SaveManager lo recoge por `node.name` =
`Economia`). **"Cargar sitúa, no reproduce"**: restaurar tal cual, sin cobros retroactivos ni señales.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core/Foundation)**:
- Required: grupo Persist + save/load_state; solo tipos JSON-safe en el dict; sin eventos durante la carga.
- Forbidden: serializar derivados (el `estado()` se deriva del saldo); re-disparar cobros al cargar.

---

## Acceptance Criteria

- [x] **AC-E16**: `ingresos_mes=3000`, `gastos_mes=2600` → al `nuevo_mes`, `balance_mes = +400` y los
      acumuladores del mes se reinician.
- [x] **AC (acumuladores)**: cada ingreso suma a `ingresos_mes`; cada cierre diario suma sus gastos a
      `gastos_mes` (recargo y penalizaciones incluidos — son gastos).
- [x] **AC-E18**: `load_state({saldo −300, usados 2, vivos 1, ...})` → se restauran tal cual, **0 señales**
      del bus durante la carga y sin cobros retroactivos.
- [x] **AC-E19**: la misma secuencia de movimientos aplicada dos veces desde el mismo estado → saldo final
      **idéntico** (determinismo end-to-end del módulo).
- [x] **AC (Persist)**: el nodo pertenece al grupo `"Persist"` tras `_ready` y su `save()` devuelve SOLO
      estado no derivado: `saldo_eur`, `prestamos_usados`, `prestamos_vivos`, `ingreso_doc_dia`,
      `ingresos_mes`, `gastos_mes`, `en_gracia`, `gracia_restante_min`, `sat_cierre_doc` *(provisional
      hasta Paciencia)*, `horas_extra_dia`.

---

## Implementation Notes

- `registrar_ordenado(&"nuevo_mes", 10, _al_nuevo_mes)` en `_ready` (Economía va a prioridad 10 en
  `nuevo_mes` según ADR-0001: Economía 10 → Paciencia 20 → Demanda 30).
- `balance_mes` queda expuesto como var (Ascensos futuro lo leerá); sin señal propia en el MVP.
- `load_state` con `get(...)` defensivo (clave ausente → conserva el valor actual + warning, patrón
  SaveManager); restaura la gracia SIN reactivar la pausa (cargar sitúa; Tiempo ya queda en Pausa por su
  propio load).
- El estado financiero NO se serializa (derivado del saldo al primer movimiento).

## Out of Scope

- Ascensos/objetivo mensual (su epic futuro) — aquí solo el número del balance.

## QA Test Cases

*Logic — `tests/unit/economia/economia_ciclo_save_test.gd`.*

- `test_balance_mensual_y_reset` (AC-E16) · `test_acumuladores_de_mes_suman_todo`
- `test_load_restaura_sin_senales_ni_cobros` (AC-E18, espías a 0) · `test_determinismo_misma_secuencia` (AC-E19)
- `test_grupo_persist_y_save_sin_derivados` (claves exactas del dict)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_ciclo_save_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (economia_ciclo_save_test.gd 5/5; suite 173/173, 2026-07-23)

## Dependencies

- Depends on: **002–005** (serializa el estado que ellas crean).
- Unlocks: 007 (el módulo completo, listo para verse); el SaveManager lo recoge sin tocar nada.

## Notas de gotchas del proyecto

Ints pequeños sin truco String (< 2^53); floats OK en JSON; espías a 0 emisiones durante load (patrón
SaveManager story 005).

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
