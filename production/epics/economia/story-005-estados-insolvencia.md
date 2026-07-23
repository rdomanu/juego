# Story 005: Estados financieros e insolvencia — rojos, suelo, gracia y game over

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (E5 · E9 rescate · States and Transitions; AC-E13/E14/E14a..e)
**Requirement**: `TR-economy-003` (estado financiero derivado + rescate con pausa/modal/ventana de gracia)

**ADR Governing Implementation**: ADR-0001
**ADR Decision Summary**: el estado financiero se **deriva** del saldo al aplicar cada movimiento (nunca
salto retroactivo). Las transiciones emiten señales de aviso por el bus (nuevas, ampliación documentada):
`entro_en_deuda` / `salio_de_deuda` / `insolvencia` / `gracia_iniciada` / `game_over`. El **modal** de
rescate es responsabilidad de la UI futura: Economía **pausa el juego** (`Tiempo.fijar_velocidad(PAUSA)` —
Core→Foundation permitido), emite `insolvencia`, y expone la decisión como API
(`aceptar_rescate()` / `rechazar_rescate()`).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM *(máquina de estados con timer de tiempo de juego)*
**Engine Notes**: la ventana de gracia cuenta en **minutos de juego** (12 h = 720 min) — Economía se
suscribe al tick de Tiempo (`Tiempo.suscribir_tick(...)`, hook de la story 007 de Tiempo) o descuenta con
el delta de juego que reciba; verificar la firma real del hook al implementar.

**Control Manifest Rules (Core)**:
- Required: transiciones al cruzar 0 / `−deuda_max_eur` evaluadas al aplicar cada movimiento; gasto
  voluntario bloqueado en rojos; determinismo (el timer usa tiempo de JUEGO, nunca reloj real).
- Forbidden: estado financiero almacenado que pueda desincronizarse (se deriva); reloj real del sistema.

---

## Acceptance Criteria

- [x] **AC (estados)**: `estado()` deriva POSITIVO (`saldo ≥ 0`) / ROJOS (`−1000 < saldo < 0`) /
      INSOLVENCIA (`saldo ≤ −1000`); al entrar/salir de rojos se emiten `entro_en_deuda`/`salio_de_deuda`
      una vez por transición.
- [x] **AC-E14**: cruzar el suelo con `usados < 3` → el juego se **pausa** y se emite `insolvencia`
      (la UI futura mostrará el modal); NO game over.
- [x] **AC-E14a**: `aceptar_rescate()` → préstamo inyectado (+1500, +strike, +vivo) y sale del suelo.
- [x] **AC-E14b**: `rechazar_rescate()` → emite `gracia_iniciada` y arranca la ventana (720 min de juego);
      si expira sin salir del suelo → préstamo **automático** con aviso.
- [x] **AC-E14c**: si durante la gracia el saldo sube por encima de −1000 → rescate **cancelado** (no gasta
      préstamo), vuelve a ROJOS.
- [x] **AC-E13**: cruzar el suelo con `usados = 3` → **`game_over`** (sin modal ni gracia).
- [x] **AC-E14d**: `num_prestamos_max = 0` → primer cruce del suelo = game over inmediato.
- [x] **AC-E14e**: 3 préstamos preventivos gastados en positivo → el cruce posterior del suelo = game over.

---

## Implementation Notes

- Evaluar transición en un único punto (`_tras_movimiento()`) llamado por toda mutación del saldo.
- Señales nuevas en `event_bus.gd` (ampliación documentada): `entro_en_deuda(saldo: float)`,
  `salio_de_deuda(saldo: float)`, `insolvencia(saldo: float, prestamos_restantes: int)`,
  `gracia_iniciada(minutos: float)`, `game_over(motivo: StringName)`.
- La pausa del rescate llama a `Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)`; en tests, Tiempo es
  instancia inyectada o se verifica vía espía (decidir al implementar; NUNCA el autoload real en unit).
- La gracia con `en_gracia: bool` + `gracia_restante_min: float`; se descuenta con el delta de juego del
  tick; al expirar → `pedir_prestamo()` automático + reanudar. El recargo diario sigue corriendo (E5).
- El bloqueo de gasto voluntario en rojos ya lo da el gate (saldo<0 → `puede_pagar` false); assert explícito.

## Out of Scope

- El modal/UI real (epic UI #11 con `design/ux/hud.md`); la valoración de jefes (#16); save de la gracia (006).

## QA Test Cases

*Logic — `tests/unit/economia/economia_insolvencia_test.gd`. Tiempo/bus espías propios; gracia simulada
inyectando deltas de juego.*

- `test_transiciones_emiten_deuda_una_vez` · `test_suelo_con_prestamos_pausa_y_emite_insolvencia` (AC-E14)
- `test_aceptar_rescate_inyecta_y_sale_del_suelo` (AC-E14a) · `test_gracia_expira_inyecta_automatico` (AC-E14b)
- `test_gracia_remontada_cancela_rescate` (AC-E14c) · `test_suelo_sin_prestamos_game_over` (AC-E13)
- `test_max_cero_game_over_inmediato` (AC-E14d) · `test_preventivos_agotados_game_over` (AC-E14e)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_insolvencia_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (economia_insolvencia_test.gd 8/8; suite 173/173, 2026-07-23)

## Dependencies

- Depends on: **004** (pedir_prestamo para el rescate) + **003** (el recargo que hunde) + Tiempo (pausa/tick).
- Unlocks: 006 (serializa el estado de gracia), 007 (color del HUD por estado).

## Notas de gotchas del proyecto

NUNCA reloj real (la gracia es tiempo de juego inyectable); espías con Arrays; preload por ruta; una
emisión por transición (guarda de estado anterior, patrón de los cruces de Tiempo).

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
