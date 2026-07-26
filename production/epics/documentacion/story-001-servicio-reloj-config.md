# Story 001: El servicio y su reloj — núcleo, config y F3

> **Epic**: Documentación
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — creada

## Context

**GDD**: `design/gdd/documentation.md` (DO1, DO3, DO5, DO8, DO11 · F1 parcial, F3)
**Requirement**: `TR-doc-001` (configura horario / última admisión que Flujo ejecuta y Demanda respeta)
— *parte pura: el objeto y sus fórmulas; el cableado real es la 002*

**Governing ADRs**: ADR-0003 (primario — catálogo), ADR-0001 (secundario — capas)
**ADR Decision Summary**: los valores del servicio (apertura, cierre base, rango autorizado, margen de
última admisión) viven en un `ConfigDocumentacion` (`.tres` del catálogo), **nunca hardcodeados**;
Documentación es un nodo de la capa Feature que no muta a nadie — solo calcula y expone su horario.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a — aritmética de minutos del día y lectura del catálogo. Sin API post-cutoff.

**Control Manifest Rules (Feature)**:
- Required: `class_name Documentacion extends Node` con `aplicar_config(config)` + clamps con aviso
  (patrón Economía/Flujo/Paciencia). Valores SOLO del catálogo. — ADR-0003
- Required: lee definiciones del catálogo por `id` (read-only) vía `Datos.obtener(...)`. — ADR-0003
- Forbidden: **nunca mutar lo que devuelve `Datos.obtener`** (plantilla compartida). — ADR-0003
- Forbidden: leer el reloj del sistema; la hora entra siempre como parámetro o por `usar_tiempo`. — ADR-0001

---

## Acceptance Criteria

*De `design/gdd/documentation.md`, acotados a esta story:*

- [x] **AC-DC01** `[Unit]` — GIVEN el catálogo THEN los trámites de Doc son **DNI**(12/12), **Pasaporte**(15/30),
      **TIE**(15/18) leídos de Datos (no inventados aquí).
- [x] **AC-DC07** `[Unit]` — GIVEN cierre 14:30 y `margen_ultima_admision_min = 15` THEN
      `hora_ultima_admision = 14:15` (F3).
- [x] **AC-DC10** `[Unit]` — GIVEN **sin** evento de la División activo WHEN se pide cerrar más tarde de
      las **20:00** THEN se limita a 20:00 (el rango lo fija la División).
- [x] `[Unit]` — GIVEN cierre 18:00 THEN `horas_extra() = 3.5`; GIVEN cierre 14:30 THEN `horas_extra() = 0.0`
      (F1, parte pura — el coste en euros es la 003).
- [x] `[Unit]` — GIVEN una hora del día THEN `estado_servicio(min_dia)` devuelve
      **Cerrado / Abierto / Cerrando** según las transiciones del GDD.

---

## Implementation Notes

- **Ruta**: `src/feature/documentacion/documentacion.gd` (`class_name Documentacion extends Node`) —
  2º sistema de la capa Feature, misma convención que `src/feature/paciencia/`.
- **F3**: `hora_ultima_admision_min = hora_cierre_min − margen_ultima_admision_min`.
- **F1 (parte pura)**: `horas_extra = max(0, hora_cierre_min − cierre_base_min) / 60.0`.
- **`fijar_hora_cierre(min: int)`** — la orden del jugador. Clampa a `[cierre_base_min, tope_autorizado()]`
  **con aviso** si se sale (patrón del proyecto). `tope_autorizado()` = `slider_max_min` (1200 = 20:00) o el
  del evento de la División activo cuando exista (la 004 lo enchufa; aquí es un `var` con default).
- **`estado_servicio(min_dia: float) -> StringName`**: `CERRADO` fuera de `[apertura, cierre)`;
  `ABIERTO` dentro y antes de la última admisión; `CERRANDO` entre la última admisión y el cierre.
  Función **pura** (recibe la hora, no la busca) → testeable sin reloj.
- **`ConfigDocumentacion`** (`config_documentacion.gd` + `tools/build_config_documentacion.gd` →
  `datos/config/documentacion.tres`), knobs de esta story:
  `apertura_base_min` 480 · `cierre_base_min` 870 · `slider_min_min` 480 · `slider_max_min` 1200 ·
  `margen_ultima_admision_min` 15 (rango 0–30) · `peonada_activa_por_defecto` false.
- **Política de cita (DO8)**: `requiere_cita_activa() -> bool` devuelve **false** en el MVP; si un trámite
  del catálogo trae `requiere_cita = true`, se **trata como sin cita con aviso** (la cita previa es #14).
- **Restricciones a respetar en el clamp**: `slider_min ≤ apertura_base` · `cierre_base ≤ slider_max` ·
  `margen ∈ [0, 30]`.
- **Nada de reloj propio**: este nodo no se suscribe al tick en esta story (lo hace la 002).

---

## Out of Scope

- Empujar el horario a Flujo/Demanda y retirar los knobs prestados → **story 002**.
- El coste en euros de la peonada y el efecto de moral → **story 003**.
- Los eventos de la División y el guardado → **story 004**.
- El slider y el panel visible → **story 005**.

---

## QA Test Cases

`tests/unit/documentacion/documentacion_horario_test.gd`

- **AC-DC01**: los trámites salen del catálogo
  - Given: el catálogo real cargado (`Datos`)
  - When: se piden los trámites de Documentación
  - Then: `dni` 12 min/12 € · `pasaporte` 15/30 · `tie` 15/18
  - Edge cases: id inexistente → `null` + aviso, sin romper la simulación
- **AC-DC07**: última admisión (F3)
  - Given: cierre 870, margen 15
  - When: se pide `hora_ultima_admision()`
  - Then: 855 (14:15)
  - Edge cases: margen 0 → 870 (admite hasta el cierre) · margen 30 → 840 · margen 45 → se clampa a 30 con aviso
- **AC-DC10**: el tope de la División
  - Given: sin evento activo (tope 1200)
  - When: `fijar_hora_cierre(1290)` (21:30)
  - Then: el cierre queda en 1200 (20:00) y se avisa
  - Edge cases: `fijar_hora_cierre(600)` (por debajo del cierre base) → se clampa a 870
- **Horas extra (F1 parte pura)**
  - Given: cierre 1080 (18:00) / cierre 870
  - When: `horas_extra()`
  - Then: 3.5 / 0.0
  - Edge cases: nunca negativa
- **Estado del servicio**
  - Given: apertura 480, cierre 870, margen 15
  - When: `estado_servicio(400 / 600 / 860 / 900)`
  - Then: `cerrado / abierto / cerrando / cerrado`
  - Edge cases: exactamente 480 → abierto · exactamente 855 → cerrando · exactamente 870 → cerrado
- **Config fuera de rango** (patrón del proyecto)
  - Given: un `.tres` con `margen = 99` y `cierre_base > slider_max`
  - When: `aplicar_config`
  - Then: valores clampados + `push_warning`, nunca un estado imposible

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/documentacion/documentacion_horario_test.gd` — debe existir y pasar

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Core completo)
- Unlocks: Story 002

## Cierre (2026-07-26)

Implementada en hilo principal (Opus 5). **Suite 445/445, exit 0** (+22 respecto a los 423 del cierre
de Paciencia); test propio **22/22**.

- `src/feature/documentacion/documentacion.gd` (`class_name Documentacion`): `tope_autorizado()`,
  `fijar_hora_cierre` / `fijar_margen_ultima_admision` (clamp + aviso + señal `horario_cambiado`),
  **F3** `hora_ultima_admision()`, **F1 pura** `horas_extra()` / `hay_horas_extra()`,
  `estado_servicio()` + `admite_a_esa_hora()`, y los trámites/cita leídos del catálogo.
- `config_documentacion.gd` + `tools/build_config_documentacion.gd` → `datos/config/documentacion.tres`
  (6 knobs de la División).
- Test `tests/unit/documentacion/documentacion_horario_test.gd` **22/22**.

**Decisiones de implementación (más allá de los AC):**
- **La señal `horario_cambiado` se emite solo si el horario cambia de verdad** (guarda anti-duplicado,
  patrón `nivel_demanda_cambiado` de Demanda): en la 002 la escucharán Flujo y Demanda, y un slider
  arrastrado emite decenas de valores intermedios — sin la guarda, cada píxel del ratón reconfiguraría
  dos sistemas.
- **El cierre base nunca puede caer antes de la apertura** (`clamp` con mínimo `apertura + 1`): una
  jornada de 0 minutos no es un horario, es un bug silencioso que dejaría la comisaría sin ingresos.
- **`hora_ultima_admision()` nunca cae antes de la apertura**: un margen absurdo no puede cerrar la
  puerta antes de abrirla.
- **`estado_servicio` normaliza la hora con `fposmod`**: el reloj del juego acumula minutos sin parar
  (el día 3 a las 10:00 son 4.920 min), y la función se usará desde la UI con el valor crudo.
- **Cita (DO8)**: `requiere_cita()` devuelve **false** siempre en el MVP y **avisa** si el catálogo
  pidiera cita — el hueco de #14 queda marcado sin que nadie pueda quedarse sin atender por una cita
  que el juego todavía no sabe dar.
- 🐛 *El test cazó una expectativa mía mal calculada* (no un fallo del código): al sanearse el cierre
  base a 481, un `slider_max` de 600 ya era válido. El caso se reescribió con 400 para que compruebe
  de verdad la restricción `slider_max ≥ cierre_base`.
