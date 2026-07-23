# Story 007: 💶 El saldo en el HUD del esqueleto — Economía se hace visible

> **Epic**: Economía / Presupuesto
> **Status**: Complete
> **Layer**: Core (presentación provisional)
> **Type**: Visual/UI
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/economy-budget.md` (UI Requirements — indicador de saldo con color por estado;
`umbral_holgura_ui`)
**Requirement**: — *(story de integración visible, como la 009 de Tiempo; el HUD real es del epic UI #11)*

**ADR Governing Implementation**: ADR-0001 (la UI lee y ordena, nunca muta; dibujo en `_process`)
**ADR Decision Summary**: `Main` **instancia el nodo `Economia`** como hijo (name `"Economia"` — la clave
de su save), cumpliendo la arquitectura §3.4 ("instanciar el mundo"). El HUD provisional muestra el saldo
escuchando `saldo_cambiado` con color por estado. Para que el hito SE VEA moverse (aún sin Demanda/Flujo),
`Main` fija la **plantilla inicial provisional** `[ag_doc, ag_doc, ag_odac]` (dotación estándar del GDD,
arquitectura §3.4 paso 4a) → cada medianoche la nómina de 190 € se descuenta A LA VISTA.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: mismo patrón del HUD del esqueleto (labels por código, `_process` para pull inicial,
señales para reaccionar).

**Control Manifest Rules (Presentation-lite)**:
- Required: el HUD LEE (`saldo_eur`, estado) y jamás muta; colores con respaldo textual (accesibilidad:
  nunca solo color — el estado se escribe también en texto).
- Forbidden: lógica de simulación en el HUD; adelantar UI del `hud.md` real (esto es andamio).

---

## Acceptance Criteria

*Visual/UI — evidencia por captura + sign-off del usuario (ADVISORY):*

- [ ] `Main` instancia `Economia` (name `"Economia"`) con el config real y la plantilla provisional
      `[ag_doc, ag_doc, ag_odac]`; el juego arranca sin errores.
- [ ] El HUD muestra **`saldo: 3000,00 €`** al arrancar (de `caja_inicial_eur` del `.tres`), actualizándose
      al vuelo con `saldo_cambiado`.
- [ ] Color + texto por estado: verde "holgado" (`saldo ≥ umbral_holgura_ui`), ámbar "justo"
      (`0 ≤ saldo < 500`), rojo "números rojos" (`saldo < 0`).
- [ ] Al cruzar una medianoche (velocidad 3× para verlo pronto), el saldo **baja 190 €** (nómina) a la vista.
- [ ] Sin errores en consola durante 1-2 min; suite completa sigue en verde.
- [ ] **Se abre la ventana al usuario** y se recoge su **sign-off** (evidencia en `production/qa/evidence/`).

---

## Implementation Notes

- `main.gd`: añadir la instanciación del mundo (de momento solo Economía) + un bloque de HUD financiero
  (label saldo con fuente grande + label de estado). Formato `%.2f €` o entero con céntimos — decidir y ser
  consistente.
- Colores del art bible §4 aún sin definir para esto → placeholder sobrio (verde/ámbar/rojo estándar) con
  el texto del estado al lado (accesibilidad baseline: nunca solo color).
- La plantilla provisional se documenta como HOOK de Personal (su epic la sustituirá por la dotación real).
- Captura automática de evidencia (patrón de la 009 de Tiempo, solo dev).

## Out of Scope

- Botones de préstamo/modal de rescate (UI #11 con `hud.md`); ingresos visibles (llegan con Demanda/Flujo);
  desgloses de gastos.

## QA Test Cases

*Visual/UI — walkthrough manual + captura (ADVISORY). Sin test automático del HUD; la lógica ya está
cubierta por 001-006.*

- Lanzar; ver saldo 3000 y estado "holgado"; poner 3×; cruzar medianoche → saldo 2810 y sigue "holgado";
  (opcional dev) forzar saldo bajo para ver "justo"/"números rojos".

## Test Evidence

**Story Type**: Visual/UI (ADVISORY — captura + sign-off del usuario)
**Required evidence**: `production/qa/evidence/economia-saldo-hud-[fecha].md` + PNG. Sign-off del usuario.

**Status**: [x] Evidencia FIRMADA: production/qa/evidence/economia-saldo-hud-2026-07-23.md + PNG. Sign-off usuario 2026-07-23.

## Dependencies

- Depends on: **001–006** (el módulo entero) + esqueleto visible (Tiempo 009, Complete).
- Unlocks: la base visible sobre la que Demanda/Flujo harán que el saldo SUBA (no solo baje).

## Notas de gotchas del proyecto

Botones ya existentes con `focus_mode NONE` (no tocar); el HUD lee en `_process`/señales; validar headless
antes de abrir la ventana al usuario.

## Cierre (2026-07-23)

Implementada en HILO PRINCIPAL (Fable; subagentes caidos por creditos 1M) + suite verificada tras cada
story. Commits d877995/3e61512/cf0fe45/bb50da3/1aa1217/137a6e3/088d6f2. Epic completo con suite 173/173
exit 0 y sign-off del usuario en la 007 (saldo vivo en el HUD, nomina -190 a medianoche).
