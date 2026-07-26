# Story 004: Los eventos de la División + guardar el servicio

> **Epic**: Documentación
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — creada

## Context

**GDD**: `design/gdd/documentation.md` (DO2, DO7, DO8 · Edge Cases de evento activo y guardado)
**Requirement**: `TR-doc-002` (eventos de la División —estacionales— que amplían horario) + `TR-doc-001`
(la parte de persistencia del horario configurado)

**Governing ADRs**: ADR-0003 (primario — el catálogo de eventos), ADR-0002 (secundario — serialización),
ADR-0001 (el aviso viaja por el bus)
**ADR Decision Summary**: los eventos son **datos del catálogo** (`.tres`), no código; el estado del
servicio (horario elegido, margen, evento activo) se serializa por el grupo `Persist`; el aviso al jugador
sale por el **bus de eventos**, nunca llamando a la UI.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: los `.tres` se generan con `tools/build_catalogo.gd` en headless (crear `.tres` a mano es
frágil por los `uid`/`ext_resource` — regla del proyecto desde el epic Datos).

**Control Manifest Rules (Feature)**:
- Required: `save()` / `load_state()` + grupo `"Persist"`. — ADR-0002
- Required: leer el catálogo por `id`, read-only. — ADR-0003
- Forbidden: **nunca mutar** el recurso que devuelve `Datos.obtener` — el evento **activo** es estado propio
  (id + fin), no el recurso del catálogo. — ADR-0003
- Forbidden: la lógica no llama a la UI — el aviso se **emite** al bus. — ADR-0001

---

## Acceptance Criteria

*De `design/gdd/documentation.md`, acotados a esta story:*

- [ ] **AC-DC09** `[Integration]` — GIVEN el evento "periodo vacacional" activo THEN se **autoriza** ampliar
      hasta las **21:30**; el jugador decide si amplía (la División habilita, no obliga).
- [ ] **AC-DC10** `[Integration]` — GIVEN que el evento **termina** con el horario ampliado por encima de
      20:00 THEN el cierre vuelve al tope ordinario (20:00) con aviso.
- [ ] **AC-DC11** `[Integration]` — GIVEN el MVP (`requiere_cita = false`) THEN la demanda de Doc **no se
      autolimita**; si un trámite del catálogo pidiera cita, se trata **como sin cita con aviso**.
- [ ] **AC-DC16** `[Unit]` — GIVEN un save con horario configurado + margen + evento activo WHEN se carga
      THEN se restauran los tres, y el horario restaurado se vuelve a empujar a Flujo y Demanda.
- [ ] `[Integration]` — GIVEN el cambio de mes THEN el evento correspondiente se activa/desactiva y se
      **anuncia por el bus** una sola vez (sin repetir el aviso cada tick).

---

## Implementation Notes

- **Esquema nuevo del catálogo**: `src/foundation/datos/esquema/evento_division.gd`
  (`class_name EventoDivision extends Resource`): `id`, `nombre`, `descripcion`,
  `meses: Array[int]` (en qué meses del calendario está activo), `tramite_destacado: StringName`,
  `cierre_max_min: int` (tope autorizado mientras dure). Solo `@export` tipados, cero lógica.
  Indexar en `datos.gd` como un tipo más y generarlo en `tools/build_catalogo.gd`.
- **Los 2 eventos del MVP** (DO7):
  | id | nombre | meses | trámite | tope |
  |---|---|---|---|---|
  | `vacaciones` | Periodo vacacional | 7, 8 | `pasaporte` | 1290 (21:30) |
  | `colapso_extranjeria` | Colapso en extranjería | 2 | `tie` | 1290 (21:30) |
  *(El catálogo crece en playtest/V-Slice — DO7 dice explícitamente "1–2 eventos simples para validar el
  mecanismo".)*
- **Activación**: al `nuevo_mes` (y al cargar partida) se busca el evento cuyo `meses` contenga el mes actual.
  **Determinista, sin RNG** (decisión del usuario 2026-07-26). Al activarse: `tope_autorizado()` pasa a
  `cierre_max_min`; al desactivarse, vuelve a `slider_max_min` y **el cierre actual se re-clampa con aviso**.
- **Aviso**: señal nueva en el bus `aviso_division(evento_id: StringName, nombre: String, activo: bool)`,
  documentada en `event_bus.gd` con emisor (Documentación) y oyentes (UI, Feedback). Se emite **solo al
  cambiar** (guarda anti-duplicado, patrón `nivel_demanda_cambiado` de Demanda).
- **Persistencia** (ADR-0002): `save()` devuelve `{hora_cierre_min, margen_ultima_admision_min,
  evento_activo_id}`; `load_state()` los aplica **clampando igual que en partida** (un save manipulado no
  puede abrir hasta las 03:00) y vuelve a empujar el horario a Flujo/Demanda. Nodo en el grupo `"Persist"`.
- **Política de cita (DO8)**: dejar escrito y testeado que el MVP va **sin cita** y que un
  `requiere_cita = true` en el catálogo se degrada a "sin cita" con `push_warning` (el hueco de #14).

---

## Out of Scope

- El aviso **en pantalla** (bandeja de comunicados de la División) → **story 005**.
- Eventos aleatorios, campañas de DNI, jornada ininterrumpida → catálogo futuro (playtest / V-Slice).
- La cita previa real → sistema **#14**.

---

## QA Test Cases

`tests/integration/documentacion/documentacion_eventos_persistencia_test.gd`

- **AC-DC09**: la División autoriza, no obliga
  - Given: mes 7 (vacaciones), horario en el cierre base
  - When: llega el `nuevo_mes` y se consulta el tope
  - Then: `tope_autorizado() = 1290`, el cierre **sigue** en 870 hasta que el jugador lo cambie
  - Edge cases: `fijar_hora_cierre(1290)` ahora se acepta; `fijar_hora_cierre(1350)` se clampa a 1290
- **AC-DC10**: al acabar el evento se recoge la ampliación
  - Given: evento activo y cierre puesto a 21:30
  - When: el mes cambia a uno sin evento
  - Then: `tope_autorizado() = 1200` y el cierre baja a 1200 con aviso
  - Edge cases: si el cierre era 18:00 (por debajo del tope ordinario) no se toca
- **AC-DC11**: el MVP va sin cita
  - Given: el catálogo del MVP
  - When: se consulta la política
  - Then: `requiere_cita_activa() = false` para los tres trámites
  - Edge cases: un trámite con `requiere_cita = true` → se trata como sin cita + aviso
- **AC-DC16**: el save recuerda el servicio
  - Given: cierre 1080, margen 5, evento `vacaciones` activo
  - When: `save()` → JSON → `load_state()` en una instancia nueva
  - Then: los tres valores vuelven y Flujo/Demanda reciben el horario restaurado
  - Edge cases: save con `hora_cierre_min = 1400` (manipulado) → se clampa al tope autorizado ·
    save sin la clave (partida vieja) → valores por defecto, sin romper
- **Aviso una sola vez**
  - Given: un espía del bus en `aviso_division`
  - When: se activa el evento y luego pasan 10 ticks
  - Then: exactamente **1** aviso de activación
  - Edge cases: al desactivarse, exactamente 1 aviso con `activo = false`
    *(⚠️ contador del espía en un `Array`, nunca un `int` — las lambdas capturan por valor)*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/documentacion/documentacion_eventos_persistencia_test.gd`
— debe existir y pasar (incluye el round-trip por JSON, patrón de las stories de persistencia previas)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003
- Unlocks: Story 005
