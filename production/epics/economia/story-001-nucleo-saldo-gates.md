# Story 001: Núcleo de Economía — nodo, config data-driven, saldo y gates

> **Epic**: Economía / Presupuesto
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**GDD**: `design/gdd/economy-budget.md` (E1 saldo único · E4 gate de gasto voluntario · E8 data-driven; Tuning Knobs)
**Requirement**: `TR-economy-004` (gates "¿puedo construir/contratar?" expuestos a Construcción/Personal)

**ADR Governing Implementation**: ADR-0001 *(primario)* · ADR-0002 *(sec.)*
**ADR Decision Summary**: Economía es un sistema **Core** → **nodo del mundo** (arquitectura §3.4: los Core
se instancian en la escena principal, NO son autoloads — los autoloads son solo los 5 Foundation). Gates
`puede_pagar()`/`cobrar()`/`abonar()` según el control-manifest (gasto voluntario solo si
`puede_pagar()==true`). Todos los valores de tuning son data-driven (E8).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: lógica pura + un Resource de config (patrón `ConfigTiempo` ya rodado). El bus se INYECTA
(`usar_bus()`, patrón de `tiempo.gd`) para testear sin el autoload real.

**Control Manifest Rules (Core)**:
- Required: gates `puede_pagar()`/`cobrar()`/`abonar()`; todo valor de juego data-driven (config/catálogo);
  tipado estático; determinismo.
- Forbidden: hardcodear cifras de juego; que otro sistema mute el saldo directamente (solo la API).
- Cross-cutting: capas — Core puede llamar a Foundation (Datos/Tiempo/bus), nunca al revés.

---

## Acceptance Criteria

- [ ] **AC-1**: existe `src/core/economia/economia.gd` (`class_name Economia extends Node`) con
      `saldo_eur: float` que arranca en `caja_inicial_eur` del config (AC-E17: editar el `.tres` a 5000 sin
      tocar código → nueva partida arranca con 5000).
- [ ] **AC-2**: existe `ConfigEconomia` (`src/core/economia/config_economia.gd`, Resource) con los 9 knobs
      del GDD (`caja_inicial_eur` 3000 · `interes_deuda_diario` 0.02 · `deuda_max_eur` 1000 ·
      `importe_prestamo_eur` 1500 · `penalizacion_fija_prestamo` 30 · `pct_ingreso_prestamo` 0.20 ·
      `num_prestamos_max` 3 · `ventana_gracia_insolvencia_horas` 12 · `umbral_holgura_ui` 500) y su `.tres`
      en `datos/config/economia.tres` **generado por herramienta** (`tools/build_config_economia.gd`).
      Clamp defensivo con aviso (todos ≥ 0; `num_prestamos_max` entero ≥ 0) — patrón ConfigTiempo.
- [ ] **AC-3 (gate, AC-E07)**: `puede_pagar(coste)` false si `saldo < coste`; `cobrar(500)` con saldo 400 →
      **rechazado**, saldo sigue 400, devuelve false.
- [ ] **AC-4 (gate, AC-E08)**: `cobrar(500)` con saldo 600 → true, saldo 100.
- [ ] **AC-5**: `abonar(x)` suma; `cobrar`/`abonar` emiten **`saldo_cambiado(saldo)`** por el bus inyectado.
- [ ] **AC-6 (enmienda del bus)**: la señal `saldo_cambiado` del EventBus pasa de `int` a **`float`** (el
      dinero tiene decimales — GDD F2: DNI a sat 50 = 3,6 €). Se actualiza el test del bus que usaba 3000.

---

## Implementation Notes

- `usar_bus(bus)` + auto-resolución en `_ready` (patrón exacto de `tiempo.gd`); sin bus → no emite (fallback).
- `aplicar_config(config)` inyectable (firma `Resource` + validación por preload — gotcha `class_name` en frío).
- El saldo SOLO muta por la API (`cobrar`/`abonar` y los flujos internos de stories posteriores).
- La enmienda `saldo_cambiado: int → float` es una ampliación menor documentada del epic event-bus cerrado
  (mismo trato que `velocidad_cambiada`): actualizar doc comment + el assert del test de señales (3000 → 3000.0).

## Out of Scope

- Ingresos DGP (002), cierre diario (003), préstamos (004), estados/insolvencia (005), save (006), HUD (007).
- La instanciación en `Main.tscn` (007 — aquí el nodo se testea con `.new()`).

## QA Test Cases

*Logic — `tests/unit/economia/economia_nucleo_test.gd`. Fixtures con config inyectado, bus espía propio.*

- `test_saldo_inicial_viene_del_config` (AC-1/AC-E17: config custom 5000 → saldo 5000).
- `test_cobrar_sin_caja_se_rechaza_y_no_muta` (AC-E07).
- `test_cobrar_con_caja_descuenta` (AC-E08).
- `test_abonar_suma_y_emite_saldo_cambiado` (espía del bus propio).
- `test_config_fuera_de_rango_clampa_con_aviso` (knob negativo → 0 + warning).
- `test_tres_real_existe_y_carga_defaults` (datos/config/economia.tres con los 9 valores semilla).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economia/economia_nucleo_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: Foundation completa (Datos para el patrón config; EventBus para la señal).
- Unlocks: 002–007 (todas usan el nodo, el config y los gates).

## Notas de gotchas del proyecto

Preload por ruta en tests; lambdas→Arrays; tipado estático; el `.tres` SOLO por herramienta; clamps con
aviso (patrón Datos/Tiempo).
