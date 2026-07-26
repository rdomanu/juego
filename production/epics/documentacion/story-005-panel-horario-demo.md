# Story 005: El panel del servicio — el slider de horario (HITO VISIBLE)

> **Epic**: Documentación
> **Status**: Ready
> **Layer**: Presentation (UI del sistema Feature)
> **Type**: UI
> **Estimate**: M-L (~3 h + ronda de demo)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — creada

## Context

**GDD**: `design/gdd/documentation.md` (UI Requirements · DO11, DO12 · Visual/Audio Requirements)
**Requirement**: `TR-doc-001` (la cara visible: el jugador configura el horario)
**UX**: `design/ux/hud.md` + `design/ux/pulido-backlog.md` (estilo expediente/dosier, barra inferior tycoon)

**Governing ADRs**: ADR-0001 (primario — la UI lee estado y **emite órdenes** al dueño, jamás muta)
**ADR Decision Summary**: el panel **no calcula ni guarda nada**: pide los números a `Documentacion`
(`horas_extra`, `coste_peonada_estimado`, `estado_servicio`, `nivel_demanda`) y le manda la orden
`fijar_hora_cierre` / `fijar_margen`. Toda la validación vive en el dueño.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `HSlider` + `Label`; refresco en `_process` (tiempo real, funciona a 2×/3× y en Pausa).

**Control Manifest Rules (Presentation)**:
- Required: la UI lee estado y emite órdenes; **nunca** muta estado de juego. — ADR-0001
- Required: **ratón-first, sin interacciones hover-only**. — `technical-preferences.md`
- Required: `@onready`/referencias cacheadas, no `$Path` en `_process`.
- Required (bugs reales del Sprint 2): todo `Control` decorativo → `mouse_filter = MOUSE_FILTER_IGNORE` ·
  todo `Button` → `focus_mode = FOCUS_NONE` (si no, la barra espaciadora vuelve a pulsarlo en vez de pausar)
  · barra anclada abajo → `grow_vertical = GROW_DIRECTION_BEGIN` · textos del catálogo → `HFlowContainer`.
- Forbidden: la lógica nunca llama a la UI (el aviso de la División llega por el bus). — ADR-0001
- Forbidden: guardar estado de juego en la UI. — ADR-0002

---

## Acceptance Criteria

*De `design/gdd/documentation.md`, acotados a esta story:*

- [ ] **AC-DC14** `[UI]` — GIVEN el nivel de demanda THEN es **visible** (BAJA/MEDIA/ALTA) con
      **semáforo + icono + texto** (respaldo daltónico, no solo color) y cambia según el mes.
- [ ] **AC-DC15** `[UI]` — GIVEN el juego en **Pausa** WHEN se mueve el slider o el margen THEN se permite y
      se aplica; el reloj **no avanza** (gestión en pausa, DO11).
- [ ] `[UI]` — GIVEN el slider THEN muestra **en vivo** la hora de cierre, las horas extra y el
      **coste de peonada del día** mientras se arrastra, antes de soltar.
- [ ] `[UI]` — GIVEN el estado del servicio THEN el HUD muestra **ABIERTA / CERRANDO / CERRADA** con su hora
      de última admisión (texto siempre, color como refuerzo).
- [ ] `[UI]` — GIVEN un evento de la División activo THEN aparece un **comunicado oficial** en el panel y el
      slider **permite llegar hasta las 21:30**; sin evento, tope 20:00.
- [ ] `[UI]` — GIVEN el panel abierto THEN se cierra con la misma tecla y con Esc, y no se traga los clics
      del mundo al cerrarse.

---

## Implementation Notes

- **Tecla `H`** (horario) abre/cierra el panel — patrón de `P` (personal) y `B` (construir).
  Registrar la acción en `project.godot` junto a las demás y añadir el botón a la botonera del HUD.
- **Fichero**: `src/main/panel_horario.gd`, mismo patrón que `panel_personal.gd`.
- **Contenido del panel** (orden de lectura):
  1. **Estado**: "Documentación: ABIERTA · última admisión 14:15 · cierra 14:30"
  2. **Slider de cierre** (`HSlider`, paso 15 min, de `cierre_base` a `tope_autorizado()`): al moverlo,
     etiqueta en vivo "Cierre 18:00 · +3,5 h extra · **peonada 105 €/día**"
  3. **Margen de última admisión** (0–30 min, paso 5) con su explicación en una línea:
     *"margen alto = tu gente sale a su hora · margen 0 = más trámites, pero se desmotivan"*
  4. **Semáforo de demanda**: 🟢 BAJA / 🟡 MEDIA / 🔴 ALTA con **texto e icono** (nunca solo color)
     + la lectura útil: *"con demanda BAJA ampliar suele salir a pérdidas"*
  5. **Bandeja de la División**: el comunicado del evento activo (membrete sobrio) o "sin comunicados"
- **El coste se pide, no se calcula**: `documentacion.coste_peonada_estimado()` con el valor tentativo del
  slider (función con parámetro opcional para previsualizar sin aplicar).
- **Aviso de la División**: conectar `EventBus.aviso_division` → muestra el comunicado (y una línea en el
  HUD). La UI **escucha**, no pregunta cada frame.
- **Pulido estético** que no entre aquí → `design/ux/pulido-backlog.md` (regla de fase: el feedback de
  comportamiento se implementa el mismo día; el estético se anota).

---

## Ronda de demo (tarea C3-8)

Guion propuesto para la ventana:
1. Abrir con `H` **en pausa** y mover el slider: ver el coste de la peonada subir en vivo → **AC-DC15**.
2. Poner el cierre a las 18:00, quitar la pausa y ver que a las 14:30 **no se van** — siguen atendiendo.
3. Ver el gasto de la peonada en el cierre del día (saldo) y compararlo con lo que entró de más.
4. Bajar el margen a 0 y ver el aviso de "sale tarde" al cerrar.
5. `F5` / `F9` para comprobar que el horario elegido sobrevive.

**Sin sign-off del usuario esta story no se cierra.**

---

## Out of Scope

- Iconos definitivos / arte del comunicado (art bible pendiente) → placeholders sobrios + backlog de pulido.
- El icono de "a qué viene cada ciudadano" (U8, ya anotado en el backlog de pulido).
- Cualquier regla nueva de horario: aquí solo se **enseña y se ordena**, la lógica ya está en 001–004.

---

## QA Test Cases

*Story de UI → verificación manual con evidencia firmada.*

- **AC-DC14**: el semáforo de demanda
  - Setup: abrir el panel con `H` en un mes de demanda MEDIA y avanzar hasta un mes ALTA
  - Verify: el nivel cambia y siempre se lee **texto + icono**, no solo el color
  - Pass condition: un jugador daltónico podría leer el nivel sin distinguir el color
- **AC-DC15**: gestión en pausa
  - Setup: pausar (barra espaciadora), abrir `H`, mover slider y margen
  - Verify: los valores cambian y el reloj sigue parado; al quitar la pausa el horario nuevo ya rige
  - Pass condition: ninguna orden se pierde ni se aplica dos veces
- **Coste en vivo**
  - Setup: arrastrar el slider de 14:30 a 20:00 con 2 agentes de Doc
  - Verify: la etiqueta pasa por 0 € → … → 165 € (5,5 h × 15 × 2) **antes de soltar**
  - Pass condition: el número coincide con el que Economía descuenta esa noche
- **Estado del servicio**
  - Setup: dejar correr el día con margen 15
  - Verify: ABIERTA → CERRANDO (a las 14:15) → CERRADA (a las 14:30)
  - Pass condition: el texto y la hora que muestra coinciden con lo que hace la simulación
- **Evento de la División**
  - Setup: llegar al mes 7 (vacaciones)
  - Verify: aparece el comunicado y el slider llega a 21:30
  - Pass condition: al salir del mes, el tope vuelve a 20:00 y el cierre se recoge con aviso
- **Higiene de UI** (bugs reales del Sprint 2)
  - Setup: abrir y cerrar el panel varias veces; pulsar la barra espaciadora tras usar un botón
  - Verify: los clics del mundo funcionan al cerrar; la barra espaciadora **pausa** (no repulsa el botón)
  - Pass condition: cero clics tragados, cero foco pegado

---

## Test Evidence

**Story Type**: UI (hito visible)
**Required evidence**: `production/qa/evidence/doc-005-panel-horario-2026-07-XX.md` con el recorrido del
guion y el **sign-off literal del usuario**.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (eventos y persistencia ya disponibles para enseñarlos)
- Unlocks: cierre del epic (C3-9)
