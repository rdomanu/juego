# Story 003: La sala de descanso — se levantan de verdad

> **Epic**: Bienestar #13
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-29 — escrita a posteriori (implementada en 3a4322a)

## Context

**GDD**: pendiente (el epic nace de una petición directa del usuario, 2026-07-28) ·
`design/gdd/staff-agents.md` (atributos del agente) · `design/gdd/documentation.md` (DO6, peonada)
**Governing ADRs**: ADR-0001 (Personal posee el estado de sus agentes; Flujo solo consulta el gate FL4
que ya existía), ADR-0002 (persistencia defensiva — dato corrupto se descarta, nunca invalida el save),
ADR-0003 (los knobs y el tipo de sala salen del catálogo, nunca del código)

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM — sin API de motor nueva, pero integra tres sistemas
(Personal, Flujo, Construcción) más el reloj; el riesgo real es de ORDEN de llamadas, no de arquitectura.

**Nota de proceso**: story redactada DESPUÉS de implementar y testear (no siguió `story-readiness →
dev-story`), al cerrar el epic. Documenta el commit `3a4322a` tal cual quedó.

**Control Manifest Rules**:
- Required: el tipo de sala y sus knobs salen del `.tres`, nunca del código. — ADR-0003
- Required: el descanso es estado de **Personal**; Flujo solo LLAMA y consulta el gate FL4 que ya
  existía — sin caso especial nuevo. — ADR-0001
- Forbidden: tocar el gate FL4 (`puesto_dotado`) para el caso "descansando".

---

## Decisiones de diseño

**1. El estado `DESCANSANDO` basta — no se toca Flujo.** El gate FL4 (`puesto_dotado`) ya exigía
`ASIGNADO` para que la ventanilla atienda. Ponerlo en `DESCANSANDO` hace que ese gate falle solo: deja de
atender **sin añadir ni una línea a Flujo**. Reutiliza el mismo gate que ya usaban las ausencias.

**2. Sin sala construida, descansan igual — pero peor.** Recomendado en el `EPIC.md`: la sala no es
obligatoria (la partida arranca sin ella), pero `mult_pausa_sin_sala` (1.5) alarga la pausa un 50 % — se
van a la calle y tardan más en volver. Construirla se nota en el tiempo parado, no en si se puede jugar.

**3. El café se pide AL TERMINAR el trámite, nunca a media atención.** Compromiso de servicio: nadie se
levanta con alguien delante a medio despachar. `_avanzar_atenciones` comprueba `necesita_descanso`
**después** de cerrar la atención, reusando el mismo patrón que `cierre_pendiente`.

**4. Atender cansa; esperar cliente no.** El tick de Flujo llama a `Personal.cansar` solo sobre puestos
`EN_ATENCION`. En horas extra cansa más, con el `mult_cansancio_efectivo()` que la story 002 ya dejó
testeado — esta story solo lo **conecta**: `_en_horas_extra_doc()` compara el reloj contra
`cierre_base_doc_min` (que Documentación empuja vía `Main`) y se lo pasa a `cansar`.

---

## Acceptance Criteria

- [x] **AC-BI15** `[Data]` — GIVEN el catálogo THEN existe el tipo de sala `descanso` y el recurso
      `sala_descanso` (300 €, servicio `Comun` — una sola sala para toda la comisaría, no una por
      departamento) y el catálogo pasa a **41 recursos**.
- [x] **AC-BI16** `[Integration]` — GIVEN un agente `ASIGNADO` con la barra llena THEN
      `enviar_a_descansar(agente)` lo pone en estado `descansando` y, SIN tocar Flujo,
      `puesto_dotado(su_puesto)` pasa a `false` (el gate FL4 ya exigía `ASIGNADO`).
- [x] **AC-BI17** `[Integration]` — GIVEN un agente descansando THEN el tick propio de Personal
      (`_al_tick`) descuenta sus minutos de café y, al llegar a 0, lo devuelve a `ASIGNADO` con el
      `cansancio` a **0**; si mientras tanto perdió su puesto, vuelve `LIBRE`, no a un puesto ajeno.
- [x] **AC-BI18** `[Unit]` — GIVEN los tres patrones de la story 001 THEN `enviar_a_descansar` respeta su
      duración (15 / 30 / 60 min) y, una vez gastadas sus pausas del día, no se le vuelve a mandar a
      descansar aunque se agote otra vez.
- [x] **AC-BI19** `[Integration]` — GIVEN NO hay sala de descanso construida THEN la pausa se alarga
      ×`mult_pausa_sin_sala` (1.5 → 30 min pasan a 45); GIVEN sí la hay THEN la pausa es la normal.
- [x] **AC-BI20** `[Unit]` — GIVEN un agente que no está `ASIGNADO` (desasignado o `null`) THEN
      `enviar_a_descansar` no hace nada y devuelve `0.0`.
- [x] **AC-BI21** `[Unit]` — GIVEN el juego en Pausa (el reloj no empuja el tick) THEN nadie vuelve del
      café: el contador solo baja con `delta_juego_min > 0`.
- [x] **AC-BI22** `[Integration]` — GIVEN Flujo atendiendo THEN quien despacha se cansa y quien espera
      cliente con la ventanilla vacía NO; y el aviso de descanso se dispara **al cerrar** el trámite,
      nunca a media atención.
- [x] **AC-BI23** `[Integration]` — GIVEN el cambio de jornada (`_al_nuevo_dia`) THEN el cansancio y el
      cupo de pausas de TODA la plantilla se reinician a 0, y a quien le pilló el cambio de día en la
      sala de descanso se le devuelve su puesto (`ASIGNADO`), no se arrastra la pausa al día siguiente.
- [x] **AC-BI24** `[Integration]` — GIVEN se guarda y se recarga la partida THEN el `cansancio`, las
      `pausas_gastadas` y los minutos de café que le quedaban a quien estaba descansando sobreviven
      exactos — guardar y cargar ya no es un chute de energía gratis.

---

## Implementation Notes

- **Catálogo**: `datos/salas/sala_descanso.tres` (`TipoSala`, `tipo = "descanso"`, `servicio = "Comun"`,
  `coste_construccion_eur = 300`, sin puestos operables). `tipo_sala.gd` amplía su `@export_enum` a
  `("espera", "oficina", "descanso")`. `tools/build_catalogo.gd` genera 5 `TipoSala` → `TOTAL_ESPERADO = 41`.
- **`construccion.gd`**: `hay_sala_de_tipo(tipo: String) -> bool` — genérico (sirve para cualquier tipo
  de sala futuro), lo consulta `Personal`.
- **`personal.gd`** (el estado vive aquí, ADR-0001): `usar_construccion`/`usar_tiempo` inyectan
  dependencias (`usar_tiempo` se suscribe a `tiempo.suscribir_tick(_al_tick)` una sola vez);
  `hay_sala_descanso()` asume `true` sin Construcción inyectada; `enviar_a_descansar(agente) -> float`
  exige `ESTADO_ASIGNADO`, aplica `mult_pausa_sin_sala` si no hay sala, pone `ESTADO_DESCANSANDO` y
  guarda el restante en `_descansando` (`Dictionary[Agente, float]`); `_al_tick(delta_juego_min)`
  descuenta con `_vueltos_del_descanso` como buffer reutilizado (cero allocs); `minutos_de_descanso_
  restantes`/`agente_descansando_en` son lectura para el HUD; `_reiniciar_cansancio()` es el nuevo paso
  (1) de `_al_nuevo_dia`; la persistencia añade `cansancio`/`pausas_gastadas`/`descanso_restante` a
  `_agente_a_dict`/`_agente_desde_dict` y `ESTADO_DESCANSANDO` a los estados conocidos del save.
- **`config_personal.gd`**: knob nuevo `mult_pausa_sin_sala` (1.5, clamp `[1.0, 5.0]`).
- **`flujo.gd`**: `_avanzar_atenciones` llama `_personal.cansar(agente, delta_min,
  _en_horas_extra_doc())` sobre quien está `EN_ATENCION`, y al cerrar el trámite comprueba
  `necesita_descanso` → `enviar_a_descansar`. `cierre_base_doc_min`/`fijar_cierre_base_doc`/
  `_en_horas_extra_doc()` son el enganche con la peonada de la story 002.
- **`main.gd`**: cablea `_personal.usar_construccion(_construccion)`, `_personal.usar_tiempo(Tiempo)` y,
  en `_al_cambiar_horario_doc`, `_flujo.fijar_cierre_base_doc(...)`.

---

## Out of Scope

- **Verlo en pantalla** (HUD de quién está de café, ralentización visible del rendimiento) — ya
  implementado en commits posteriores (`bb4b7bd`, `6442505`), pendiente su propia story a posteriori.
- **Negar el descanso** (la palanca de "exprimir" del epic) — pregunta abierta del `EPIC.md`, no
  implementada.
- **Aforo de la sala de descanso**: cualquier número de agentes puede estar "descansando" a la vez, sin
  contención — igual que Comodidades con el aforo de sus objetos.
- **Coste de moral por caraduras repetidos** — el patrón ya existe (motivación baja → `caradura`), pero
  no hay penalización adicional por reincidir.

---

## QA Test Cases

`tests/integration/personal/personal_descanso_test.gd`

- **AC-BI16**: `test_al_agotarse_la_barra_se_va_y_el_puesto_deja_de_estar_dotado`
- **AC-BI17**: `test_vuelve_a_su_puesto_con_la_barra_a_cero`,
  `test_si_le_quitan_el_puesto_mientras_descansa_no_se_lo_devuelven`
- **AC-BI18**: `test_el_cumplidor_se_va_dos_veces_y_menos_rato`,
  `test_el_caradura_tiene_la_ventanilla_parada_una_hora`
- **AC-BI19**: `test_sin_sala_de_descanso_la_pausa_se_alarga`, `test_con_sala_construida_la_pausa_es_la_normal`
- **AC-BI20**: `test_no_se_puede_mandar_a_descansar_a_quien_no_esta_en_su_puesto`
- **AC-BI21**: `test_en_pausa_del_juego_nadie_vuelve_del_cafe`
- **AC-BI22**: `test_atender_cansa_y_el_cafe_se_pide_al_acabar_el_tramite`, `test_estar_de_brazos_cruzados_no_cansa`
- **AC-BI23**: `test_al_empezar_el_dia_la_barra_vuelve_a_cero_y_se_renuevan_los_cafes`
- **AC-BI24**: `test_el_cansancio_sobrevive_al_guardado`, `test_quien_estaba_de_cafe_sigue_de_cafe_al_cargar`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/personal/personal_descanso_test.gd` — los 14 tests de esta
story en verde (el archivo tiene hoy 18: los 4 restantes son de la story 004, añadidos por commits
posteriores y fuera del alcance de este documento).

**Status**: [x] Passing

---

## Dependencies

- Depends on: Story 001 (barra de cansancio, patrón por motivación, `cansar`/`necesita_descanso`) ·
  Story 002 (el precio de la hora extra — `mult_cansancio_horas_extra`/`fijar_generosidad_peonada`, que
  esta story conecta de verdad con Flujo)
- Unlocks: Story 004 (verlo en pantalla — HUD y ralentización del rendimiento; ya implementada,
  pendiente su propia story a posteriori) · cierre formal del epic Bienestar #13
