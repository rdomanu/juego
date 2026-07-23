# Story 009 (EXTRA): Esqueleto visible — `Main.tscn` + TileMapLayer + HUD reloj

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/UI
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/time-system.md` (UI Requirements — hora HH:MM, fecha Mes·Semana N, turno, controles de velocidad; atajos Espacio/1/2/3; Visual/Audio Requirements)
**Requirement**: — *(esta es la story EXTRA de integración visible; no traza un TR nuevo: hace visible lo que H1–H7 ya construyeron)*

**ADR Governing Implementation**: ADR-0001 *(el dibujo/HUD corre en `_process`, tiempo real; la lógica del reloj en `_physics_process`)*
**ADR Decision Summary**: el **dibujado** (UI/HUD/cámara) corre en `_process` y **lee** el reloj (fuente única); **nunca lo muta**. La UI ordena la velocidad llamando a `Tiempo.fijar_velocidad(...)` y presenta lo que lee. Esta story hace **visible** el reloj en una escena mínima — es el primer "abrir la ventana" al usuario.

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM *(primer trabajo de escena/UI del proyecto; riesgo = gotchas de escena, no de API)*
**Engine Notes**:
- **`TileMapLayer`** (NO `TileMap`, deprecado en 4.3): suelo con `set_cell(coords: Vector2i, source_id, atlas_coords)`. Ver `docs/engine-reference/godot/modules/tilemap-2d.md`.
- HUD: `CanvasLayer` + `Control`; `Label` para hora/fecha/turno; `Button` para velocidad.
- Atajos de teclado: `Espacio`/`1`/`2`/`3` (definir en el InputMap o `_unhandled_input`).
- **Gotcha del prototipo**: los `Button` roban el foco y el `Espacio` activa el botón enfocado en vez de pausar → poner **`focus_mode = Control.FOCUS_NONE`** en los botones de velocidad para que `Espacio` llegue al handler global.

**Control Manifest Rules (Presentation-lite)**:
- Required: el HUD **lee** el reloj (getters) y **ordena** la velocidad (`fijar_velocidad`), **NUNCA** muta `minutos_juego` ni estado interno del reloj; HUD lee en `_process` con `@onready var x = %Nodo` (unique names); usar `TileMapLayer` (no `TileMap`).
- Forbidden: **nunca** que la UI escriba en el reloj salvo por la API pública de velocidad; nunca meter lógica de simulación en `_process`; nunca `TileMap`.
- Cross-cutting: dejar CLARO que esto **no es jugable** y el HUD es **provisional** (no es el `hud.md` de UX).

---

## Acceptance Criteria

*Visual/UI — evidencia por captura + sign-off (ADVISORY). No hay AC-T del GDD asociados; los criterios verifican que lo ya construido se ve y responde:*

- [x] Existe `Main.tscn` (+ `main.gd`) registrada como **main scene** en `project.godot`; al lanzar, abre una ventana sin errores en consola.
- [x] Se ve una **rejilla de suelo** (`TileMapLayer`) — solo visual, **sin construcción** (no se colocan/borran celdas con el ratón).
- [x] El **HUD** muestra, actualizándose en vivo: **hora HH:MM**, **fecha "Mes · Semana N"** (+ año), **turno** (Mañana/Tarde/Noche).
- [x] Hay **botones de velocidad** Pausa / 1× / 2× / 3× (el activo resaltado) y **atajos** `Espacio` (pausa/reanuda), `1`/`2`/`3` (velocidades) que llaman a `Tiempo.fijar_velocidad(...)`.
- [x] Al correr el reloj, la hora avanza; al pulsar Pausa/Espacio, se congela; al cambiar de velocidad, la hora corre más rápido — **visible**.
- [x] El HUD reacciona a `EventBus.cambio_de_turno` / `cambio_dia_noche` / `velocidad_cambiada` (p. ej. actualiza el turno / resalta el botón activo).

---

## Implementation Notes

- **`Main.tscn`**: raíz `Node2D` (o `Node`) `Main` con `main.gd`. Instancia el autoload `Tiempo` ya existe (autoload); `Main` solo lo **lee**. Contiene:
  - Un **`TileMapLayer`** de suelo: rellenar una rejilla NxM con `set_cell(Vector2i(x,y), source_id, atlas_coords)` en `_ready` (un `TileSet` mínimo con un tile de suelo). Solo estética; sin interacción de ratón.
  - Un **`CanvasLayer`** con un `Control` HUD (`hud.gd` o dentro de `main.gd`).
- **HUD lee en `_process`** (dibujo, tiempo real — ADR-0001): `@onready var _lbl_hora = %LabelHora` (nodos con **unique name** `%`), y en `_process` actualizar los textos desde los getters de `Tiempo` (`hhmm(minutos_del_dia)`, `mes`/`semana`/`anio`, `turno`). **Nunca** escribir en el reloj.
- **Botones de velocidad**: 4 `Button` (Pausa/1×/2×/3×) con **`focus_mode = FOCUS_NONE`** (gotcha: si no, `Espacio` activa el botón enfocado en vez de pausar). `pressed` → `Tiempo.fijar_velocidad(v)`. Resaltar el activo (leyendo la velocidad actual o vía `velocidad_cambiada`).
- **Atajos**: `Espacio`=pausa/reanuda; `1`/`2`/`3`=velocidades. Vía InputMap (acciones) o `_unhandled_input`. El HUD **ordena**, no muta.
- **Reacción a eventos**: conectar `EventBus.cambio_de_turno`, `cambio_dia_noche`, `velocidad_cambiada` para refrescar el HUD (o simplemente refrescar todo en `_process`; conectar los eventos es más limpio para el resaltado del botón y el toast de turno).
- **Registrar main scene** en `project.godot`: `[application] run/main_scene="res://Main.tscn"` (o la ruta donde se ubique, p. ej. `res://src/main/Main.tscn` — decidir ubicación al implementar, coherente con la estructura del repo).
- **Al terminar la story se ABRE LA VENTANA al usuario** (decisión 2026-07-22): esta es la primera vez que el usuario ve el juego correr. Lanzar Godot con ventana (no headless) para el sign-off.

**Qué NO es (dejarlo CLARO)**:
- **No es jugable**: no se construye, no llega gente, no hay economía. Solo el reloj corriendo sobre un suelo.
- **HUD provisional**: NO es el `design/ux/hud.md` (que aún no existe; la UX del HUD real se diseña con `/ux-design` antes del epic de UI/HUD #11). Este HUD es un andamio para **ver el reloj**, y se reemplazará.

## Out of Scope

- Construcción (colocar/borrar celdas con el ratón) — epic Construcción #7.
- El HUD real de UX (`hud.md`) — epic UI/HUD #11, tras `/ux-design`.
- Cámara pan/zoom, arte final, paleta día/noche animada (Visual/Audio del GDD es "Media/Baja" prioridad; aquí basta un cambio mínimo o nada).
- Audio/juice de los eventos — epic Feedback #12.

## QA Test Cases

*Visual/UI — evidencia ADVISORY (no bloqueante), no automatizable (el reloj corriendo es "feel"). Manual walkthrough + captura.*

- **Walkthrough manual**: lanzar `Main.tscn`; comprobar hora avanza, Espacio pausa, 1/2/3 cambian velocidad, el turno/fecha se actualizan, el botón activo se resalta.
- **Sin errores en consola** al lanzar y durante 1-2 minutos de ejecución.
- **Captura** del HUD con el reloj corriendo (hora, fecha, turno, controles visibles).

## Test Evidence

**Story Type**: Visual/UI (ADVISORY — screenshot + sign-off del usuario)
**Required evidence**: captura + doc de walkthrough en `production/qa/evidence/` (p. ej. `tiempo-esqueleto-[fecha].md` + PNG). Sign-off del usuario.

**Status**: [x] Evidencia creada y FIRMADA: `production/qa/evidence/tiempo-esqueleto-2026-07-23.md` + PNG (captura automática). Sign-off del usuario 2026-07-23.

## Dependencies

- Depends on: **Story 007** (el reloj corriendo en `_physics_process` — esta story lo hace visible). Implícitamente todo H1–H6 (config, conversiones, cruces, calendario, velocidad) para que el HUD tenga qué mostrar.
- Unlocks: el primer "ver el juego" del usuario; base de escena para futuros epics (Construcción instanciará sobre este `Main`/TileMapLayer).

## Notas de gotchas del proyecto

- `TileMapLayer`, **nunca** `TileMap` (deprecado). API en `modules/tilemap-2d.md` (`set_cell` con `Vector2i`).
- Botones de velocidad con **`focus_mode = FOCUS_NONE`** para no robar `Espacio` (gotcha del prototipo).
- El HUD **lee** el reloj (fuente única); **nunca** lo muta — solo ordena velocidad por la API pública.
- Validar primero en **headless** (que no pete al cargar la escena) y luego **lanzar la ventana** al usuario para el sign-off (flujo Godot del slice).

## Cierre (2026-07-23)

Implementada en el HILO PRINCIPAL (Fable — agentes inestables ese día; escena/HUD construidos por código,
mismo enfoque que validó el prototipo). Commit 3282e06. Headless limpio (0 errores/warnings) + suite
107/107 intacta. **Ventana abierta al usuario y SIGN-OFF recibido (2026-07-23)** — primera visual del
juego de producción. Evidencia: `production/qa/evidence/tiempo-esqueleto-2026-07-23.md` + PNG (captura
automática a los 2 s, solo en dev). Gotcha del prototipo aplicado (`focus_mode=FOCUS_NONE` en los botones
para que Espacio pause).
