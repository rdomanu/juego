# Story 003: En el tick del reloj — ventana, pausa y entrega al bus

> **Epic**: Generación de Demanda
> **Status**: Complete (cierre del epic con sign-off, 2026-07-24)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-23

## Context

**GDD**: `design/gdd/demand-generation.md` (DG1, DG6, DG9, DG10 + Edge Cases de ventana/pausa/reset)
**Requirement**: `TR-demand-001` (genera Personas → `persona_generada` a Flujo; acumulador alimentado por `delta`)
*(Texto del requisito en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0001 (primario — bus + tick empujado por Tiempo + eventos ordenados), ADR-0002 (secundario — el RNG ya sembrado sigue siendo la única fuente de azar)
**ADR Decision Summary**: ADR-0001 — Tiempo **empuja** el tick (`suscribir_tick`) en orden fijo Tiempo→Demanda→Flujo→Paciencia; los avisos cross-system van por señales del bus (`persona_generada` **ya existe** en `event_bus.gd:24` — verificado 2026-07-23, sin enmienda); `nuevo_dia` va por registro ordenado — **Demanda = prioridad 40**.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. En tests de integración: instanciar Tiempo y Demanda reales como nodos hijos del test, avanzar con `Tiempo.avanzar(delta)` inyectado (nunca reloj real); capturar señales con un `Array` (lambdas capturan por valor).

**Control Manifest Rules (Core)**:
- Required: **simulación en `_physics_process` vía tick que Tiempo empuja** (`delta_juego` = minutos de juego; 0 en Pausa → no se empuja). — ADR-0001
- Required: **eventos ordenados por `registrar_ordenado`** — `nuevo_dia`: Demanda **prio 40** (tras Paciencia 10, Economía 20, Personal 30). — ADR-0001
- Forbidden: el bus nunca conoce a Demanda; Demanda nunca llama a Flujo/UI por nombre — solo emite. — ADR-0001

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM05** `[Integration]` — GIVEN una llegada WHEN se genera THEN la Persona lleva `servicio` + `tramite_id` (id del catálogo Datos) y se entrega por el bus (`persona_generada`).
- [ ] **AC-DM09** `[Integration]` — GIVEN las 15:00 (Doc cerrada) WHEN avanza el tiempo THEN **no** se crean ciudadanos de Documentación; ODAC **sí** genera.
- [ ] **AC-DM10** `[Unit]` — GIVEN el cierre de Documentación (14:30) con acumulador Doc fraccional WHEN se cruza el cierre THEN el acumulador Doc se **reinicia a 0** (la demanda del día no se arrastra).
- [ ] **AC-DM11** `[Integration]` — GIVEN el juego en **Pausa** WHEN pasan frames THEN **no** se genera ninguna Persona y el acumulador no crece.
- [ ] **AC-DM16** `[Integration]` — GIVEN llegadas > capacidad (nadie atiende) WHEN transcurre el tiempo THEN la generación **no se autolimita** — sigue creando (la válvula será Paciencia, no Demanda).

---

## Implementation Notes

*Derivadas de ADR-0001 + patrón Economía (inyección):*

- **Cableado inyectable** (testeable sin autoloads reales): `usar_bus(bus: Node)` y `usar_tiempo(tiempo: Node)` (patrón exacto de `economia.gd`). En runtime, Main enchufa `EventBus` y `Tiempo` (story 007).
- **Suscripción al tick**: `tiempo.suscribir_tick(_al_tick)`. Nota de orden ADR-0001: Demanda debe suscribirse **antes** que Flujo/Paciencia cuando existan (hoy es la única — dejar comentario).
- **`_al_tick(delta_min: float)`**: consulta la hora a Tiempo (`minutos_juego` → min del día), llama `procesar_avance(delta_min, min_dia)` (story 002) y por cada ficha: `_bus.persona_generada.emit(ficha)` + `llegadas_hoy += 1` (contador para HUD/007). En Pausa Tiempo **no empuja** el tick → DG9 sale por construcción (el test lo verifica igualmente).
- **Ventana de Documentación (DG6)**: fuera de [`ventana_doc_inicio`, `ventana_doc_fin`) la densidad Doc es 0 → el acumulador **ni crece** (ya lo devuelve `densidad_por_minuto`, story 001). No hay demanda "fantasma" acumulada.
- **Reset al cierre (edge del GDD)**: detectar el **cruce** de `ventana_doc_fin` comparando min_dia del tick anterior vs. actual (patrón de cruces de Tiempo: nunca `==`, robusto a saltos) → `_acumulador_doc = 0.0`.
- **ODAC 24 h**: nunca se resetea su acumulador (el residuo nocturno se conserva — el goteo espaciado es intencional).
- **`registrar_ordenado(&"nuevo_dia", 40, _al_nuevo_dia)`**: resetear `llegadas_hoy` (contador de HUD). *(El decremento de eventos estacionales se añade aquí en la 005; el recálculo del nivel en la 004.)*
- **DG10**: Demanda **no mira** colas, capacidad ni saldo — prohibido autolimitar. El test AC-DM16 lo fija.
- **Edge Δh grande**: el `delta` ya llega clampado por Tiempo (`delta_max_por_frame`) — no re-clampar aquí; a 3× llegan más minutos por tick y el tope de ráfaga reparte.
- **Edge cruce de franja**: la hora se evalúa **al final del avance** del tick (coherente con cómo Tiempo procesa cruces) — documentarlo en el código.

---

## Out of Scope

- Story 004: nivel BAJA/MEDIA/ALTA y su señal.
- Story 005: estacionalidad/eventos (este handler de `nuevo_dia` se ampliará ahí).
- Story 006: serializar acumuladores y contador.
- Story 007: instancia real en Main + HUD (aquí todo va con nodos inyectados en tests).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-DM05**: Given Demanda + Tiempo reales y bus real (autoload EventBus), hora 08:30, densidad alta → When avanza 1 h de juego → Then el listener del test (Array capturado) recibió ≥1 ficha; cada ficha: `servicio == &"documentacion"` u `&"odac"`, `tramite_id` existe en `Datos.obtener(...)`, `minuto_llegada` dentro del avance.
- **AC-DM09**: Given hora 15:00 → When avanza 1 h → Then 0 fichas Doc y ≥0 fichas ODAC (con densidad ODAC forzada alta para no depender del goteo: subir `tasa_base_odac` vía `aplicar_config` en el test); el acumulador Doc sigue en 0.
- **AC-DM10**: Given 14:00 con acumulador Doc fraccional (>0) → When se cruza 14:30 → Then `_acumulador_doc == 0.0` (exponer read-only para test o verificar por conducta: al reabrir a las 08:00 del día siguiente no hay ráfaga extra).
- **AC-DM11**: Given Pausa (multiplicador 0) → When 60 `_physics_process` → Then 0 fichas y acumuladores sin crecer. Al reanudar, continúa determinista.
- **AC-DM16**: Given nadie escucha/atiende y densidad alta → When avanzan 3 h → Then el total generado ≈ el esperado por F2 (±tope de ráfaga), sin frenarse.
- Edge (orden `nuevo_dia`): registrar un espía con prio 39 y otro 41 → el reset de Demanda corre entre ambos (verifica prio 40).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/demanda/demanda_tick_ventana_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (6 tests; suite total 203/203, exit 0 — 2026-07-23)

---

## Dependencies

- Depends on: Story 002 (generador) — DONE antes de empezar.
- Unlocks: Story 004 (nivel), 005 (estacionalidad), 006 (persistencia).
