# Story 006: Máquina de velocidad Pausa/1×/2×/3× + `velocidad_cambiada`

> **Epic**: Sistema de Tiempo
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 2 — velocidades y pausa; States/Transitions A — estados de velocidad que controla el jugador; Edge Cases — cambiar de marcha no pierde/gana tiempo, reanudar vuelve a la última velocidad)
**Requirement**: `TR-time-002` (velocidades {Pausa,1×,2×,3×}; Pausa congela la simulación pero permite gestión)

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick y orden determinista *(primario)*
**ADR Decision Summary**: la velocidad es la **única máquina de estados que controla el jugador**. Es un **selector directo** (cualquier estado → cualquier otro, no una rueda secuencial). El multiplicador se **deriva** del estado (Pausa→0, 1×→1, 2×→2, 3×→3) y alimenta `avanzar()` (F2). Al cambiar de velocidad, el Tiempo emite un aviso `velocidad_cambiada` en el EventBus para que la UI/HUD reaccione (cross-system: la UI la consumirá).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: enum + var de estado. **Esta story AÑADE `velocidad_cambiada(indice: int)` al EventBus** (`event_bus.gd`).

**Control Manifest Rules (Foundation)**:
- Required: 4 estados {PAUSA, X1, X2, X3}; **selector directo** (cualquiera → cualquiera); multiplicador **derivado** del estado (Pausa→0); cambiar de velocidad **no altera** `minutos_juego` ya transcurrido; reanudar desde Pausa vuelve a la **última velocidad de juego** (tras cargar sin previa → 1×); emitir `velocidad_cambiada` **una vez por acción**.
- Forbidden: **nunca** almacenar el multiplicador desincronizado del estado (derivarlo siempre); nunca recalcular/perder tiempo ya transcurrido al cambiar de marcha.
- Cross-cutting: la ampliación del EventBus es una **modificación menor documentada** de un epic cerrado (ver Implementation Notes) — cross-system, coordinada.

---

## Acceptance Criteria

*De GDD Core Rules 2 + States/Transitions A + Edge Cases. Valores transcritos exactos de los AC-T del GDD:*

- [x] **AC-T04** *(desde la máquina de velocidad)*: GIVEN Pausa (mult 0) WHEN cualquier `delta_real>0` THEN `minutos_juego` **no cambia** (el multiplicador derivado de PAUSA es 0). *(El acumulador es H1; aquí se verifica que PAUSA → mult 0 alimenta correctamente ese avance nulo.)*
- [x] **AC-T30**: GIVEN 3× con `minutos_juego=500.0` WHEN el jugador cambia a 1× THEN `minutos_juego` **sigue en 500,0** (ni pierde ni gana) y los frames siguientes van a 1×.
- [x] **AC-T31**: GIVEN estaba en 3×, pulsa Pausa y reanuda WHEN se reanuda THEN vuelve a **3×** (la última velocidad de juego). *(Excepción: tras cargar, que arranca en Pausa sin velocidad previa, reanudar va a **1×**.)*
- [x] **AC-T32**: GIVEN cualquier velocidad WHEN el jugador selecciona otra (incluida Pausa) THEN se emite **`velocidad_cambiada`** con el nuevo valor, **una vez por acción**.

---

## Implementation Notes

**DECISIÓN aprobada (2026-07-22)**: se **añade la señal `velocidad_cambiada(indice: int)` al `EventBus`** (`src/foundation/event_bus/event_bus.gd`). Es una **ampliación menor y documentada** de un epic Foundation ya cerrado (EventBus, Complete): una señal de aviso más, coherente con las existentes (`cambio_de_turno(turno: int)`, etc.), que la UI/HUD (H9 y el HUD real de UX) consumirá. Documentar el añadido en el comentario de la señal (emisor: Tiempo; oyentes: UI/HUD, Feedback).

> **Nota de firma**: el troceo y el GDD la nombran `velocidad_cambiada`; se tipa como `velocidad_cambiada(indice: int)` (índice del enum de velocidad) por coherencia con el resto de señales tipadas del bus y para que el HUD sepa qué botón resaltar. Registrado como decisión (no contradice el GDD, que lista la señal sin firma explícita).

- **Enum**: `enum Velocidad { PAUSA = 0, X1 = 1, X2 = 2, X3 = 3 }`. El **multiplicador** se deriva: `PAUSA→0, X1→1, X2→2, X3→3` (los valores enteros del enum ya son el multiplicador salvo PAUSA=0, que también coincide). `multiplicador_velocidad = velocidad` funciona directamente (PAUSA=0).
- **Selector directo (GDD)**: `fijar_velocidad(v: Velocidad)` acepta ir de cualquier estado a cualquier otro. No hay rueda secuencial. La UI puede añadir +/− encima, pero la lógica es un set directo.
- **Última velocidad de juego**: guardar `ultima_velocidad_juego` (nunca PAUSA; default X1). Al **entrar** en Pausa, no se pisa. Al **reanudar** (`reanudar()`), volver a `ultima_velocidad_juego`. Tras cargar (H8) el estado es Pausa **sin** velocidad previa en la sesión → `ultima_velocidad_juego` = X1 por default, así reanudar va a 1× (AC-T31 excepción).
- **No perder tiempo (AC-T30)**: `fijar_velocidad` solo cambia el estado/mult para los **siguientes** frames; **no toca** `minutos_juego`. Cambiar de 3× a 1× con `minutos_juego=500.0` lo deja en 500,0.
- **Emisión (AC-T32)**: al cambiar de velocidad (incluida entrar/salir de Pausa), `EventBus.velocidad_cambiada.emit(velocidad)`, **una vez por acción**. Si se re-selecciona la misma velocidad, decidir al implementar si se re-emite (recomendado: solo emitir si **cambia** el valor, para "una vez por acción" real).
- **Integración con H1**: `avanzar()` (H1) usa `multiplicador_velocidad`; esta story es quien lo fija. Con la escala base de H2, X2/X3 multiplican esa escala (F1: 2× y 3× multiplican la escala base).
- **`self.` footgun**: sin métodos homónimos de globales aquí; patrón `self.` disponible si se añadiera.

## Out of Scope

- **H7**: llamar a `avanzar()` desde `_physics_process` con el mult que fija esta story.
- **Input real** (teclas Espacio/1/2/3, botones): la máquina expone `fijar_velocidad`/`reanudar`; el **binding** de teclas/botones es H9 (HUD) — aquí solo la lógica de estado.
- **Autopausa** ante eventos (GDD: opcional/futuro, no MVP) — gancho, no se implementa.
- **H8**: serializar cuál era la velocidad (nota: al cargar SIEMPRE arranca en Pausa, así que H8 no necesita restaurar la velocidad exacta, solo dejar `ultima_velocidad_juego` en default → reanudar 1×).

## QA Test Cases

*Logic — máquina de estados pura + espía del EventBus. Determinista. `tests/unit/tiempo/`.*

- **`test_pausa_deriva_mult_0`** (AC-T04): `fijar_velocidad(PAUSA)` → `multiplicador_velocidad == 0` → `avanzar()` no mueve `minutos_juego`.
- **`test_cambiar_velocidad_no_altera_minutos`** (AC-T30): `minutos_juego=500.0`, 3×→1× → sigue 500,0; mult pasa a 1.
- **`test_reanudar_vuelve_a_ultima_velocidad`** (AC-T31): 3× → Pausa → `reanudar()` → X3. Y variante: sin velocidad previa (default) → `reanudar()` → X1.
- **`test_cambio_velocidad_emite_una_vez`** (AC-T32): conectar espía a `EventBus.velocidad_cambiada`; `fijar_velocidad(X2)` → 1 emisión con X2. Cambiar a PAUSA → 1 emisión con PAUSA.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_velocidad_test.gd` — debe existir y pasar (BLOCKING).

**Status**: [x] Creado y PASA (tiempo_velocidad_test.gd 7/7; suite 107/107, 2026-07-23)

## Dependencies

- Depends on: **Story 002** (la escala base que los multiplicadores 2×/3× multiplican). *(Amplía el EventBus existente con `velocidad_cambiada`.)*
- Unlocks: **H7** (que usa el mult en `_physics_process`) y **H9** (el HUD que lee/ordena la velocidad y consume `velocidad_cambiada`).

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd`. Conectar un espía local a `EventBus.velocidad_cambiada` en el setup y desconectar en el teardown (aislamiento). **Nunca** hora real del sistema. Al añadir la señal al `event_bus.gd`, un test de que la señal existe con la firma esperada evita regresiones del contrato.

## Cierre (2026-07-23)

Implementada via subagente godot-gdscript-specialist (Opus) + verificacion independiente del hilo
principal (suite 107/107, exit 0). Commit d54246e. La senal velocidad_cambiada(indice:int) quedo anadida
al EventBus (ampliacion menor aprobada del epic cerrado).
