# Story 003: La peonada — alargar la tarde cuesta dinero (F1/F2)

> **Epic**: Documentación
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — creada

## Context

**GDD**: `design/gdd/documentation.md` (DO4, DO5, DO6, DO12 · F1, F2)
**Requirement**: `TR-doc-001` (la operativa del servicio: qué cuesta ampliar el horario)

**Governing ADRs**: ADR-0001 (primario — el coste se registra en Economía por su API, no se toca el saldo),
ADR-0003 (secundario — `peonada_eur_hora` sale del catálogo `costes_global`)
**ADR Decision Summary**: Documentación **no mueve dinero**: calcula las horas extra y se las **registra a
Economía** (`registrar_horas_extra`), que las cobra en su cierre diario junto al resto de gastos.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Feature)**:
- Required: registrar la prioridad en los eventos ordenados — la peonada del día debe quedar registrada
  **antes** de que Economía cobre en `nuevo_dia` (Economía = prioridad 20; Paciencia ya usa la 10). — ADR-0001
- Required: `peonada_eur_hora` (15) se **lee del catálogo**, nunca se duplica aquí. — ADR-0003
- Forbidden: tocar el saldo directamente. — ADR-0001

---

## ⚠️ Decisión de diseño aplicada en esta story (aprobada por el usuario 2026-07-26)

**La peonada cambia de significado.** Hoy (horario provisional de Flujo) el juego cobra peonada por los
*minutos trabajados después del cierre* — los rezagados. El GDD dice otra cosa y **manda el GDD**:

| | Qué es | Qué cuesta |
|---|---|---|
| **DO4 · Peonada** | Ampliar el horario con el slider (voluntario, pagado) | **Dinero**: 15 €/h × horas extra × nº agentes de Doc. La motivación **no baja** |
| **DO5 · Rezagados** | Terminar a quien ya cogió número, pasado el cierre | **Moral**, no euros: el agente **se desmotiva** |

→ Se **retira** el hook `fijar_hook_horas_extra` de Flujo (minutos tras el cierre → €) y se sustituye por el
cálculo del slider. **Efecto en partida:** si nunca tocas el slider, la peonada desaparece de tus gastos.

**Efecto de moral en el MVP (DO6, "efecto ligero/gancho"):** margen 0 + agente que termina fuera de horario
→ **−1 de motivación** a ese agente (suelo 1). La motivación ya modula rapidez (F2 de Personal) y trato, así
que se nota de verdad. El modelo pleno sigue siendo Bienestar #13/#15.

---

## Acceptance Criteria

*De `design/gdd/documentation.md`, acotados a esta story:*

- [x] **AC-DC04** `[Unit]` — GIVEN cierre 18:00 (3,5 h extra), 2 agentes de Doc y `peonada_eur_hora = 15`
      THEN `coste_peonada_dia = 105 €` (F1).
- [x] **AC-DC05** `[Integration]` — GIVEN peonada activa THEN el resultado del día es el esperado por F2:
      con demanda **ALTA** el ingreso extra supera el coste; con **BAJA**, se pierde dinero (**permitido**).
- [x] **AC-DC06** `[Integration]` — GIVEN peonada (voluntaria y pagada) THEN la **motivación NO baja** de los
      agentes que la cubren.
- [x] **AC-DC08** `[Integration]` — GIVEN `margen = 0` y cola al cierre THEN los agentes que terminan fuera
      de horario **se desmotivan** (−1, suelo 1) y **no se cobra peonada** por esos minutos.
- [x] `[Integration]` — GIVEN el cierre del día THEN Economía recibe las horas extra **antes** de calcular el
      balance (orden determinista), y con cierre base (14:30) recibe **0**.
- [x] `[Integration]` — GIVEN el nivel de demanda de Demanda THEN Documentación lo expone
      (**BAJA/MEDIA/ALTA**) como brújula de la decisión (DO12) — sin recalcularlo.

---

## Implementation Notes

- **F1**: `coste_peonada_dia = peonada_eur_hora × horas_extra × num_agentes_doc`. Documentación calcula
  `horas_extra × num_agentes_doc` (horas-agente) y llama a `Economia.registrar_horas_extra(horas_agente)`
  — Economía ya multiplica por `peonada_eur_hora` en su cierre. **No se duplica el precio aquí.**
- **`num_agentes_doc`**: agentes asignados a puestos cuyo `TipoPuesto.servicio == "Documentacion"`, vía
  Personal/Flujo (`agente_de(puesto_id)`). Un puesto sin dotar no cuenta: nadie cobra peonada por no venir.
- **Cuándo se registra**: al `nuevo_dia`, prioridad **15** (después de Paciencia 10, **antes** de Economía 20).
  Registrar la peonada del día que termina, no la del que empieza.
- **Retirada del hook**: quitar de `flujo.gd` el conteo `minutos_extra` en `_avanzar_atenciones`,
  `fijar_hook_horas_extra` y `_hook_horas_extra`, y su cableado en `main.gd`. Los tests de Flujo que lo
  cubrían (AC-FL24) se **actualizan** para reflejar la regla nueva: **fuera de horario ya no genera euros**.
  *(Es el único sitio donde esta story toca tests existentes, y es intencionado — el GDD lo manda.)*
- **Desmotivación (DO5/DO6)**: al detectar que un agente de Doc completa una atención con la hora ya pasada
  del cierre → `agente.motivacion = max(1, motivacion − 1)` **una vez por agente y día** (no por trámite: si
  no, un día malo lo dejaría a 1 en cinco minutos). Guardar el conjunto de agentes ya penalizados hoy y
  vaciarlo al `nuevo_dia`.
- **Brújula (DO12)**: `nivel_demanda() -> StringName` que **delega** en `Demanda.nivel_demanda()`
  (BAJA/MEDIA/ALTA). Documentación no recalcula nada; solo lo expone para la UI de la 005.
- **`coste_peonada_estimado()`**: el número que la UI enseñará en vivo mientras se arrastra el slider
  (`peonada_eur_hora × horas_extra × num_agentes_doc`) — aquí solo la función, la pantalla es la 005.

---

## Out of Scope

- Eventos de la División y guardado → **story 004**.
- El slider y el coste en pantalla → **story 005**.
- Moral dinámica completa (fatiga, recuperación, curvas) → Bienestar **#13/#15**, fuera del MVP.

---

## QA Test Cases

`tests/integration/documentacion/documentacion_peonada_test.gd`

- **AC-DC04**: la cuenta de la peonada (F1)
  - Given: cierre 1080 (18:00), 2 puestos de Doc dotados, `peonada_eur_hora = 15` del catálogo
  - When: `coste_peonada_estimado()`
  - Then: 105.0
  - Edge cases: 0 agentes → 0 € · cierre base → 0 € · 1 agente → 52,5 €
- **AC-DC05**: rentable o ruinosa según la demanda (F2)
  - Given: dos jornadas simuladas con el mismo horario ampliado, una con demanda ALTA y otra con BAJA
  - When: se cierra el día
  - Then: con ALTA el balance del día es mejor que sin ampliar; con BAJA es peor (**se permite perder**)
  - Edge cases: el juego no bloquea la decisión ruinosa, solo la telegrafía con el nivel
- **AC-DC06**: la peonada no desmotiva
  - Given: horario ampliado a 18:00 y agentes atendiendo dentro de esa ampliación
  - When: pasa el día
  - Then: la motivación de esos agentes es la misma que al empezar
- **AC-DC08**: los rezagados sí desmotivan, y gratis
  - Given: `margen = 0`, cierre 870, una atención que termina a las 880
  - When: se completa
  - Then: el agente pierde 1 de motivación (suelo 1) y las horas extra registradas siguen siendo 0
  - Edge cases: dos rezagados del mismo agente el mismo día → **−1 total**, no −2 · al día siguiente puede
    volver a penalizarse
- **Orden del cierre diario**
  - Given: espías registrados en `nuevo_dia` con prioridades 14 y 16
  - When: se dispara el evento
  - Then: Documentación registra las horas entre ambos, y Economía (20) las cobra ya contadas
  - Edge cases: cierre base → `registrar_horas_extra(0)` o ninguna llamada, nunca un valor negativo
- **Brújula de demanda**
  - Given: Demanda con nivel MEDIA
  - When: `nivel_demanda()`
  - Then: `MEDIA` (delegado, no recalculado) · sin Demanda inyectada → un valor neutro sin romper

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/documentacion/documentacion_peonada_test.gd` — debe existir y pasar.
Los tests de Flujo afectados por la retirada del hook se actualizan **en esta story** y quedan en verde.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (el horario ya vive en su dueño)
- Unlocks: Story 004

## Cierre (2026-07-26)

Implementada en hilo principal (Opus 5). **Suite 472/472, exit 0** (+16); test propio **16/16**;
arranque headless limpio.

- **Documentación**: `num_agentes_doc()`, **F1** `coste_peonada_estimado(cierre_tentativo = -1)`
  (con previsualización para el slider), `horas_agente_extra()`, `nivel_demanda()` delegado, cierre
  del día en el dispatcher **prioridad 15** (Paciencia 10 → **Doc 15** → Economía 20) y el efecto de
  moral escuchando `tramite_completado`.
- **Personal**: `agentes_dotados_en_servicio(servicio)` — API pública nueva de lectura.
- **Flujo**: **retirados** `fijar_hook_horas_extra`, `_hook_horas_extra` y el conteo de `minutos_extra`
  en `_avanzar_atenciones`, con la razón escrita en el código para que nadie los reponga.
- **Main**: cablea Economía/Personal/Demanda a Documentación y deja de cablear el hook.
- Test `tests/integration/documentacion/documentacion_peonada_test.gd` **16/16**.

**Decisiones de implementación (más allá de los AC):**
- **Documentación registra HORAS-AGENTE, no euros**: `horas_extra × agentes` va a
  `Economia.registrar_horas_extra`, y Economía pone el precio con su `peonada_eur_hora`. Así el euro
  por hora vive en un solo sitio (ADR-0003) y la peonada se cobra junto al resto de gastos del día.
- **Prioridad 15 y no otra**: si Documentación registrara después de Economía (20), la peonada del día
  se cobraría **un día tarde** — un desfase de esos es de los que no se notan hasta que no cuadra el
  balance del mes.
- **La desmotivación es por agente y día, no por trámite**: cinco rezagados seguidos no pueden dejar a
  un agente a 1 de motivación en una tarde. Se guarda la lista de "ya se llevó el disgusto hoy" y se
  vacía en el cierre.
- **Un puesto sin dotar no cuenta para la peonada**: nadie cobra horas extra por no venir.
- **El test de Flujo que medía la peonada se actualizó, no se borró**: ahora comprueba lo contrario
  (`_horas_extra_dia == 0.0`) — es la prueba de que Flujo ya no cobra por los rezagados.
- 🐛 *Un test propio falló por contar mal los ticks*: tras cerrar por horario, el puesto necesita **un
  tick para reabrir** antes de poder emparejar. Sin ese tick de margen, la atención del "día siguiente"
  no llegaba a completarse y parecía que la desmotivación no se aplicaba.
