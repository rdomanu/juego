# Story 002: La mudanza — el horario deja de vivir prestado en Flujo

> **Epic**: Documentación
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M-L (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — creada

## Context

**GDD**: `design/gdd/documentation.md` (DO3, DO5, DO10 · regla de propiedad)
**Requirement**: `TR-doc-001` (configura horario / última admisión que **Flujo ejecuta** y **Demanda respeta**)

**Governing ADRs**: ADR-0001 (primario — capas y API pública), ADR-0003 (secundario — catálogo)
**ADR Decision Summary**: un sistema **jamás muta el estado interno de otro**: Documentación **configura**
a Flujo y a Demanda llamando a su **API pública** (push), y ellos ejecutan. El horario deja de ser un knob
de `ConfigFlujo`/`ConfigDemanda` y pasa a ser un dato que su dueño empuja.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a — cableado de nodos y orden del tick, sin API de motor.

**Control Manifest Rules (Feature)**:
- Required: Documentación configura por **API pública**; nada de tocar campos de otro sistema desde fuera. — ADR-0001
- Required: el orden del tick sigue siendo determinista — Documentación se cablea en Main **antes** de que
  Flujo/Demanda arranquen su primer tick. — ADR-0001
- Forbidden: duplicar el horario en dos sitios "por si acaso" — **una sola fuente de verdad**. — ADR-0001

---

## Acceptance Criteria

*De `design/gdd/documentation.md`, acotados a esta story:*

- [x] **AC-DC02** `[Integration]` — GIVEN horario base 08:00–14:30 WHEN son las 15:00 THEN Flujo cierra los
      puestos de Doc y Demanda **no genera** trámites de Doc.
- [x] **AC-DC03** `[Integration]` — GIVEN el cierre ampliado a **18:00** THEN los puestos de Doc siguen
      abiertos hasta las 18:00 (Flujo ejecuta) y Demanda genera dentro de esa ventana.
- [x] **AC-DC13** `[Integration]` — GIVEN un puesto de Doc **sin agente** o **fuera de horario** THEN no
      atiende (sigue valiendo FL4 tras la mudanza).
- [x] `[Integration]` — GIVEN el margen de última admisión THEN **la puerta deja de dar número** en
      `hora_ultima_admision`, pero **lo ya admitido se termina siempre** (compromiso de servicio, FL24).
- [x] 🚦 **RED DE SEGURIDAD** — `tests/integration/flujo/flujo_horario_test.gd` (3 tests) y
      `tests/integration/demanda/demanda_tick_ventana_test.gd` (6 tests) siguen **en verde sin modificarlos**.
- [x] `[Integration]` — el horario **ya no vive en `ConfigFlujo` ni en `ConfigDemanda`**: grep de
      `apertura_doc_min`/`cierre_doc_min`/`ventana_doc_*` en los `.gd` de config → 0 resultados.

---

## Implementation Notes

**La regla que hace que la mudanza sea segura:** *Flujo y Demanda **sin** Documentación inyectada se
comportan exactamente como hoy* (mismos valores por defecto 480/870, margen 0). Por eso los tests viejos
siguen pasando tal cual: son la prueba de que no se rompió nada.

- **API nueva en Flujo**: `fijar_horario_doc(apertura_min: int, cierre_min: int, ultima_admision_min: int)`
  — guarda los tres valores y nada más. `_gestionar_horario_doc()` sigue igual (usa apertura/cierre).
- **`puerta_doc_abierta()` pasa a ser**: `min_dia >= apertura_doc_min and min_dia < ultima_admision_min`.
  Con `ultima_admision_min == cierre_doc_min` (default, sin Documentación) es **idéntico a hoy** salvo que
  ahora también respeta la apertura — a las 03:00 la puerta ya no admite Doc (arregla un agujero latente).
- **API nueva en Demanda**: `fijar_ventana_doc(inicio_min: int, fin_min: int)` — mismos campos que ya tiene,
  con la validación que ya existe (`fin <= inicio` → aviso + vuelta a 480/870).
- **Se retiran** los `@export` de `config_flujo.gd` (`apertura_doc_min`, `cierre_doc_min`) y de
  `config_demanda.gd` (`ventana_doc_inicio_min`, `ventana_doc_fin_min`), y sus comentarios "PROVISIONAL".
  Los `var` de `flujo.gd`/`demanda.gd` **se quedan** (son estado ejecutado) con sus defaults actuales.
  Regenerar `datos/config/flujo.tres` y `datos/config/demanda.tres` con sus tools.
- **Main**: instancia `Documentacion` (tras Datos/Economía, antes de Flujo/Demanda), `aplicar_config`,
  `usar_tiempo`, y **empuja el horario** al arrancar y cada vez que cambie (señal propia
  `horario_cambiado(apertura, cierre, ultima_admision)` → Main reenvía a Flujo y a Demanda).
- **Panel DEV (F1)**: los knobs "Documentación abre / cierra" pasan a apuntar a `Documentacion` en vez de a
  `Flujo` (`src/main/panel_admin.gd`, sección del horario) y a escribir `documentacion.tres`.
- **HUD**: la etiqueta "Doc: ABIERTA (cierra HH:MM)" pasa a leer la hora de Documentación y a distinguir
  **ABIERTA / CERRANDO / CERRADA** (el panel completo es la 005).
- **Registro de entidades** (`design/registry/entities.yaml`): `apertura_doc_min` y `cierre_doc_min` cambian
  de **owner** (Flujo/Demanda → **Documentación #8**), con `referenced_by` en Flujo y Demanda y las notas
  de "provisional" retiradas. Sigue siendo **el mismo hecho** que `ventana_doc_inicio/fin`.

---

## Out of Scope

- El coste de la peonada en euros y el efecto de moral → **story 003** (el hook actual se retira allí).
- Eventos de la División y guardado → **story 004**.
- El slider en pantalla → **story 005**.

---

## QA Test Cases

`tests/integration/documentacion/documentacion_configura_flujo_demanda_test.gd`

- **AC-DC02**: fuera de horario no hay servicio
  - Given: Documentación con horario base, Flujo y Demanda cableados, reloj a las 15:00
  - When: corre el tick
  - Then: los puestos de Doc quedan cerrados al vaciar su cola y Demanda genera **0** fichas de Doc
  - Edge cases: ODAC sigue funcionando 24 h (no le afecta el horario de Doc)
- **AC-DC03**: el cierre ampliado manda
  - Given: `fijar_hora_cierre(1080)` (18:00) empujado a Flujo y Demanda
  - When: el reloj marca las 16:00
  - Then: los puestos de Doc siguen abiertos y Demanda **sí** genera Doc
  - Edge cases: a las 18:01 se cierra la puerta a nuevas admisiones
- **AC-DC13**: sin agente no se atiende
  - Given: un puesto de Doc en horario pero sin dotar
  - When: hay cola
  - Then: no llama a nadie (no cambia respecto a hoy)
- **Última admisión efectiva**
  - Given: cierre 870, margen 15 → última admisión 855
  - When: llega una persona de Doc a las 856 y otra a las 850
  - Then: la de 850 se admite; la de 856 **no** (puerta cerrada), y la admitida **se termina** aunque pasen
    de las 870
  - Edge cases: margen 0 → se admite hasta 869
- **Fuente única**
  - Given: el proyecto tras la mudanza
  - When: se busca el horario en las configs de Flujo/Demanda
  - Then: no está — solo lo tiene `ConfigDocumentacion`
- 🚦 **Regresión obligatoria**: `flujo_horario_test.gd` y `demanda_tick_ventana_test.gd` en verde **sin editarlos**

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/documentacion/documentacion_configura_flujo_demanda_test.gd`
— debe existir y pasar, **y la suite completa debe seguir en verde** (423/423 + los nuevos)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (el objeto y sus fórmulas)
- Unlocks: Story 003

## Cierre (2026-07-26)

Implementada en hilo principal (Opus 5). **Suite 456/456, exit 0** (+11); arranque headless limpio.
🚦 **La red de seguridad aguantó**: `flujo_horario_test.gd` (3) y `demanda_tick_ventana_test.gd` (6)
**en verde sin tocar una línea**.

- **Flujo** (ejecuta): `fijar_horario_doc(apertura, cierre, ultima_admision)` con saneado defensivo,
  `ultima_admision_doc_min` nuevo, `puerta_doc_abierta()` = `[apertura, ultima_admision)`. Los knobs
  salen de `ConfigFlujo`.
- **Demanda** (respeta): `fijar_ventana_doc(inicio, fin)` con el saneado que antes vivía en
  `aplicar_config`. Los knobs salen de `ConfigDemanda`. `.tres` de ambos regenerados.
- **Main**: instancia `Documentacion` tras Demanda y `_al_cambiar_horario_doc` es **el único punto**
  por el que el horario viaja (empuje inicial + señal).
- **HUD**: la etiqueta de la puerta pasa a **ABIERTA / CERRANDO / CERRADA** con la hora de admisión.
- **Panel DEV (F1)**: sección del horario apuntando a Documentación (+ knob nuevo de margen).
- **Registro**: `apertura_doc_min` y `cierre_doc_min` cambian de dueño a Documentación #8 y se añade
  `margen_ultima_admision_min`. YAML validado.

**Decisiones de implementación (más allá de los AC):**
- **Demanda recibe la ÚLTIMA ADMISIÓN como fin de ventana, no el cierre.** Generar a alguien entre la
  última admisión y el cierre sería fabricar a una persona que se encontraría la puerta cerrada al
  llegar: demanda imposible de atender, abandono garantizado y el aviso rojo de "nadie puede atender"
  saltando sin culpa del jugador.
- **`puerta_doc_abierta()` ahora también comprueba la APERTURA** — antes solo miraba el cierre, así que
  a las 03:00 la puerta admitía trámites de Doc. No se notaba porque Demanda no genera a esa hora, pero
  colar a alguien de madrugada sí lo habría destapado.
- **El panel DEV llama a `refrescar_horario()`** tras escribir un knob: el panel escribe propiedades a
  pelo y se saltaría los `fijar_*`, así que sin esto la barra cambiaría el número pero no la comisaría.
- 🐛 **Un test ajeno se rompió y era señal, no ruido**: `flujo_atencion_test::test_pausa_congela_la_atencion`
  creaba su reloj **sin hora** (00:00) y, con la apertura ya comprobada, dejó de poder admitir. Es el
  gotcha conocido del proyecto ("un fixture sin reloj inyectado cree que son las 00:00"). Arreglado
  poniendo el reloj a las 08:20 con el porqué escrito: ese test mide la Pausa, no el horario.
- **`demanda_volumen_test`** se actualizó donde comprobaba los knobs retirados del `.tres` (el saneado
  de ventana imposible ahora se verifica sobre `fijar_ventana_doc`).

**⚠️ Hallazgo de diseño para la demo (C3-8), anotado y NO resuelto aquí:** el perfil intradía de
Demanda (`perfil_hora_doc`) solo tiene peso en las franjas 8–14 y **suma 1.0** (AC-DM03a de Demanda).
Es decir: **ampliar el horario no trae gente nueva por la tarde** — sirve para *vaciar la cola
acumulada*, que es exactamente lo que dice el GDD (DO4: *"la cola no baja al dar las 14:30, ¿alargo
para vaciarla?"*). Si en la demo se ve que con demanda ALTA no queda cola suficiente para que la
peonada compense, la palanca es añadir franjas de tarde como demanda **extra** (sin renormalizar, para
no tocar los 45/día calibrados) — es la Open Question nº1 del GDD (valores semilla).
