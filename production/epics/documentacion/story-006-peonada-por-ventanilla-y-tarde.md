# Story 006: Peonada por ventanilla + el goteo de la tarde

> **Epic**: Documentación
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-28 — creada

## Context

**GDD**: `design/gdd/documentation.md` (DO4, DO10, DO12 · F1, F2) + `design/gdd/demand-generation.md` (F2, DG6)
**Requirement**: `TR-doc-001` (la operativa del servicio)
**Origen**: **feedback del usuario en la demo (2026-07-28)** — *"en temporada baja no es rentable abrir
todos los puestos pero sí unos pocos, y en temporada alta sí es rentable abrir todos"*.

**Governing ADRs**: ADR-0001 (primario — Documentación ordena por API pública), ADR-0003 (el goteo de
tarde es un knob del catálogo)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Feature)**:
- Required: Documentación **ordena** a Flujo por API pública; nunca toca sus puestos por dentro. — ADR-0001
- Required: el goteo de tarde es un knob del `.tres` de Demanda, no un número en el código. — ADR-0003
- Forbidden: duplicar el horario — el cierre por puesto lo **deriva** Documentación, no lo inventa Flujo.

---

## El problema que resuelve

Tras las stories 001–005, la peonada es **todo o nada**: si amplías el horario, se cobra por **todas**
las ventanillas de Doc dotadas (hoy 3), aunque solo quieras dejar una de guardia. Y, por el otro lado,
**por la tarde no llega nadie nuevo** (el perfil intradía de Demanda solo tiene peso de 8 a 14:30), así
que ampliar solo sirve para vaciar cola. Juntas, las dos cosas hacen que la decisión de horario sea casi
siempre "no ampliar".

**Las dos piezas de esta story** (aprobadas por el usuario 2026-07-28):
1. **La peonada se paga por ventanilla que se queda**, no por plantilla → *"dejo una de guardia"* pasa a
   ser jugable, y con la estacionalidad (DG13) el ciclo baja/alta funciona solo.
2. **Un goteo pequeño de demanda de tarde**: poco a propósito — el goteo **solo** no paga una ventanilla;
   lo que la paga es el goteo **más la cola que arrastras** (temporada alta).

---

## Acceptance Criteria

- [x] **AC-DC17** `[Integration]` — GIVEN 3 ventanillas de Doc dotadas y el cierre ampliado a 18:00 con
      **solo una** marcada para la tarde THEN la peonada es la de **1 agente** (52,5 €), no la de 3.
- [x] **AC-DC18** `[Integration]` — GIVEN una ventanilla marcada para la tarde y otra no THEN, pasado el
      cierre base, la primera **sigue atendiendo** y la segunda **cierra** (los funcionarios se van).
- [x] **AC-DC19** `[Integration]` — GIVEN que **ninguna** ventanilla se queda por la tarde THEN el
      servicio se comporta como en jornada base: peonada **0** y la puerta deja de dar número a la hora
      de siempre (no se fabrica demanda que nadie va a atender).
- [x] **AC-DC20** `[Integration]` — GIVEN el servicio abierto por la tarde THEN Demanda genera el
      **goteo** de esas franjas; con el horario base, las franjas de tarde aportan **0**.
- [x] **AC-DC21** `[Unit]` — GIVEN el perfil base de Documentación THEN sigue sumando **1.0**
      (AC-DM03a de Demanda **no se rompe**): el goteo es un knob **aditivo** aparte.
- [x] **AC-DC22** `[Integration]` — GIVEN una partida guardada con ventanillas de tarde marcadas WHEN se
      carga THEN se restauran (y el horario por puesto se vuelve a empujar a Flujo).
- [x] `[UI]` — el panel **H** lista las ventanillas de Doc con su interruptor *"sigue por la tarde"* y el
      coste de cada una; el total coincide con lo que Economía descuenta.

---

## Implementation Notes

- **Personal**: `puestos_de_servicio(servicio) -> Array[StringName]` (orden de registro, estable) y
  `tipo_de_puesto(puesto_id)` — API pública de lectura.
- **Flujo**: `fijar_cierre_de_puesto(puesto_id, cierre_min)` — cierre propio de un puesto (`0` = sigue el
  global). `_gestionar_horario_doc` usa el cierre efectivo de cada puesto. Sin llamadas, todo igual.
- **Documentación**:
  - `_puestos_tarde: Dictionary[StringName, bool]` + `fijar_puesto_de_tarde()` / `puesto_de_tarde()`.
    **Por defecto TODAS se quedan** (es el comportamiento actual: ampliar el horario amplía el servicio;
    el jugador afina quitando).
  - `hora_cierre_efectiva()` = el cierre elegido **si alguna ventanilla se queda**; si no, el base. De ahí
    cuelgan `horas_extra`, `hora_ultima_admision` y `estado_servicio` — así, quitar todas las ventanillas
    de la tarde equivale a no haber ampliado.
  - `num_agentes_doc()` cuenta solo las ventanillas **dotadas Y de tarde**.
  - **Sin Personal inyectado** (tests unitarios) no hay ventanillas que consultar → manda el horario
    elegido, exactamente como antes de esta story.
  - `save()`/`load_state()` incluyen la lista de ventanillas de tarde.
- **Demanda**: knob nuevo `perfil_hora_doc_tarde: Dictionary[int, float]` — **aditivo** sobre el perfil
  base (que sigue sumando 1.0). Semilla: `15:0.06 · 16:0.05 · 17:0.04 · 18:0.03 · 19:0.02 · 20:0.015 ·
  21:0.01` ≈ **9 personas/día** si abres hasta las 20:00 con demanda media.
- **Main**: el handler del horario empuja también el **cierre por puesto**.
- **Panel H**: una fila por ventanilla con `CheckBox` (`focus_mode = FOCUS_NONE`), su tipo y su coste.

---

## Out of Scope

- **La cita previa** (elegir "con cita / sin cita", huecos de tarde reservables): es el sistema **#14**,
  del Vertical Slice. Esta story es la versión sin cita de la misma decisión.
- Cerrar ventanillas dentro del horario base para ahorrar: **no ahorra nada** (el salario se paga igual);
  el ahorro solo existe en horas extra, y eso es lo que hace que esta decisión sea *la* decisión.

---

## QA Test Cases

`tests/integration/documentacion/documentacion_peonada_test.gd` (amplía) y
`tests/unit/demanda/demanda_volumen_test.gd` (goteo)

- **AC-DC17**: 3 ventanillas, solo 1 de tarde → `coste_peonada_estimado() == 52.5`
  - Edge cases: ninguna de tarde → 0 € · las 3 → 157,5 € · una sin dotar no cuenta
- **AC-DC18**: pasado el cierre base, la de tarde sigue Libre y la otra queda Cerrada
- **AC-DC19**: sin ventanillas de tarde, `hora_cierre_efectiva() == cierre_base_min` y la puerta cierra
  a la hora de siempre
- **AC-DC20**: `llegadas_esperadas_hora(16:00, DOC)` > 0 con la ventana ampliada y **== 0** con la base
- **AC-DC21**: Σ `perfil_hora_doc` sigue siendo 1.0
- **AC-DC22**: round-trip por JSON con dos ventanillas marcadas

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: tests ampliados en verde + suite completa + demo en ventana con el usuario
(temporada baja vs alta).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (el panel donde viven los interruptores)
- Unlocks: cierre del epic (C3-9)

## Cierre (2026-07-28)

Implementada en hilo principal (Opus 5). **Suite 497/497, exit 0** (+12); arranque headless limpio.

- **Personal**: `puestos_de_servicio()` y `tipo_de_puesto()` (API pública de lectura).
- **Flujo**: `fijar_cierre_de_puesto()` / `cierre_de_puesto()` y `_gestionar_horario_doc` respetando el
  cierre propio de cada ventanilla.
- **Documentación**: `puestos_de_doc()`, `puesto_de_tarde()`, `fijar_puesto_de_tarde()`,
  `hay_puestos_de_tarde()`, **`hora_cierre_efectiva()`** (de la que ahora cuelgan horas extra, última
  admisión y estado), `num_agentes_doc()` solo con las de tarde y `coste_peonada_por_ventanilla()`.
- **Demanda**: `perfil_hora_doc_tarde` (knob aditivo del `.tres`, regenerado).
- **Panel H**: lista de ventanillas con casilla, tipo del catálogo y coste por fila.
- **GDD actualizados al momento** (acción #4 del retro): `documentation.md` DO4 + F1 + F2 y
  `demand-generation.md` F2. Registro: `perfil_hora_doc_tarde` dado de alta, YAML validado.

**Decisiones de implementación (más allá de los AC):**
- **Se guarda la EXCEPCIÓN, no la norma** (`_puestos_sin_tarde`): una ventanilla recién construida hace
  la tarde como el resto sin que nadie tenga que acordarse de darla de alta, y un save antiguo carga
  con todas trabajando. Menos estado que mantener y menos formas de que se desincronice.
- **`hora_cierre_efectiva()` es el eje del cambio**: si no queda nadie de tarde, el servicio se comporta
  como si no hubieras ampliado (peonada 0, la puerta cierra a su hora y Demanda no fabrica gente para
  una tarde que no existe) — **pero el slider no se mueve**: el jugador sigue viendo su elección.
- **Sin Personal inyectado, manda el horario elegido**: los tests unitarios no montan una comisaría
  entera, y sin ventanillas que consultar la respuesta correcta es la de antes de esta story. Eso es lo
  que mantuvo verdes los 40 tests previos del epic sin tocarlos.
- **El goteo es aditivo, no redistributivo**: renormalizar el perfil habría bajado la demanda de la
  mañana (los 45/día están calibrados contra R5) y habría roto AC-DM03a de Demanda. La lectura de
  diseño también es mejor: no es que la gente venga más tarde, es que **viene gente que hoy no viene**.
- 🐛 *Un test propio falló y era el fixture, no el código*: el mundo de prueba replicaba el cableado de
  Main **antes** de esta story (empujaba el horario global pero no el de cada ventanilla). Actualizado
  para que siga siendo un espejo fiel de Main.
