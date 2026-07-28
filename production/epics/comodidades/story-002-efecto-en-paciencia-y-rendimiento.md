# Story 002: El efecto — aguantan más y atienden antes

> **Epic**: Comodidades #15
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-28 — creada

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F1 — `mult_comodidad`, rango 0.6–1.0) +
`design/gdd/flow-queues.md` (F1 — duración efectiva de la atención)
**Governing ADRs**: ADR-0001 (cada sistema posee SU fórmula), ADR-0003 (los knobs, del `.tres`)

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: **cada sistema convierte a su manera**. Construcción dice *cuánto confort hay*; Paciencia
  decide *qué le hace eso a la paciencia* (es su F1) y Flujo *qué le hace al reloj de la atención*
  (es su F1). Construcción no calcula multiplicadores de nadie. — ADR-0001
- Forbidden: hardcodear el `k` de conversión o el suelo (van a los `.tres` respectivos). — ADR-0003

---

## Acceptance Criteria

- [x] **AC-CM07** `[Unit]` — GIVEN confort 6 en la sala y `k_confort = 0.02` THEN
      `mult_comodidad = 0.88` → con tolerancia base 30, la gente aguanta **~34 min** en vez de 30.
- [x] **AC-CM08** `[Unit]` — GIVEN una sala llena de comodidades (confort 20) THEN `mult_comodidad`
      toca su **suelo 0.6** (aguantan 50 min) y **no baja más**: por muy bien montada que esté la sala,
      nadie espera eternamente.
- [x] **AC-CM09** `[Integration]` — GIVEN sin comodidades THEN `mult_comodidad = 1.0` y **el balance de
      hoy no cambia ni un minuto** (compatibilidad total con lo ya calibrado).
- [x] **AC-CM10** `[Unit]` — GIVEN un puesto en una oficina con rendimiento 10 y `k_equipamiento = 0.02`
      THEN la duración efectiva baja un **20 %** (suelo 0.8): un DNI de 12 min pasa a **9,6**.
- [x] **AC-CM11** `[Integration]` — GIVEN el equipamiento THEN se multiplica **sobre** el modificador
      del agente (F1 de Flujo), no lo sustituye — un agente rápido con buen equipo va aún más rápido.
- [x] **AC-CM12** `[Integration]` — GIVEN Paciencia/Flujo **sin Construcción inyectada** THEN todo
      sigue como antes (1.0): los tests previos no se tocan.

---

## Implementation Notes

- **Paciencia** (`ConfigPaciencia`): knobs `k_confort` (0.02) y `mult_comodidad_min` (0.6).
  `mult_comodidad_de(servicio)` = `clamp(1 - k_confort × confort_de_servicio(servicio), min, 1.0)`;
  sin Construcción → 1.0. F1 pasa a usarlo **por servicio** en vez del knob fijo.
  ⚠️ El knob viejo `mult_comodidad` (fijo 1.0) queda como **fallback** cuando no hay Construcción.
- **Flujo** (`ConfigFlujo`): knobs `k_equipamiento` (0.02) y `mult_equipamiento_min` (0.8).
  `duracion_efectiva` pasa a ser `max(1, base × mod_agente × mult_equipamiento(puesto))`.
- **Construcción** ya expone los aportes (story 001): aquí solo se **consumen**.

---

## Out of Scope

- Comprar los objetos desde el menú del clic derecho → **story 003**.
- Reequilibrar `tolerancia_base_min` a la luz de las comodidades → decisión del usuario tras la demo
  *(es la deuda registrada en el sign-off de Paciencia: se aceptó 30 contando con este epic)*.

---

## QA Test Cases

`tests/unit/comodidades/comodidades_efecto_test.gd`
- **AC-CM07**: confort 6 → 0.88 · minutos hasta agotarse ≈ 34,1
- **AC-CM08**: confort 20 → 0.6 exacto; confort 50 → sigue 0.6 (suelo)
- **AC-CM09**: sin Construcción → 1.0 y 30 min clavados
- **AC-CM10**: rendimiento 10 → dni 12 min → 9,6
- **AC-CM11**: agente rápido (mod 0.76) + equipo (0.84) → 12 × 0.76 × 0.84 = 7,66
- **AC-CM12**: Flujo sin Construcción → 12,0 (como hoy)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/comodidades/comodidades_catalogo_test.gd` (el efecto se testea junto al catálogo).

**Status**: [x] suite completa **528/528, exit 0** (verificada en el hilo principal el 2026-07-28)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003

## Cierre (2026-07-28) — stories 001 y 002

Implementadas en hilo principal (Opus 5). **Suite 515/515, exit 0** (+18); arranque headless limpio.
Test común: `tests/integration/comodidades/comodidades_catalogo_test.gd` **18/18 a la primera**.

- **Catálogo**: esquema `Comodidad` + carpeta `datos/comodidades/` con los **8 objetos**; `datos.gd`
  indexa el tipo y `build_catalogo.gd` los genera (**40 recursos**, antes 32).
- **Construcción**: valida cada familia en su tipo de sala, `confort_de_sala`, `equipamiento_de_sala`,
  `confort_de_servicio` (media), `equipamiento_de_puesto`, `mantenimiento_dia()` y el cobro en
  `nuevo_dia` **prioridad 16**.
- **Economía**: `registrar_mantenimiento()` + `_mantenimiento_dia` en gastos y en el save.
- **Paciencia**: `mult_comodidad_de(servicio)` y `tasa_drenaje`/`drenar`/`minutos_hasta_agotar` con el
  multiplicador de comodidad como parámetro opcional.
- **Flujo**: `mult_equipamiento(puesto)` dentro de `duracion_efectiva`.
- **UI**: el menú del clic derecho sobre la sala ya ofrece los objetos que ESA sala admite, con precio,
  mantenimiento y aporte; la cabecera muestra el confort (o el equipamiento) instalado.

**Decisiones de implementación (más allá de los AC):**
- **`Datos.obtener_silencioso()` nuevo**: preguntar *"¿este id es una comodidad?"* es una consulta
  legítima cuyo `null` no es un error. Con `obtener` normal, cada validación de colocación habría
  escupido un `push_warning` — la consola se habría vuelto inútil justo donde hace falta leerla.
- **Los multiplicadores NO viven en Construcción**: ella solo suma aportes. Paciencia convierte confort
  en aguante (F1 es suya) y Flujo convierte rendimiento en minutos (F1 es suya) — ADR-0001. Si algún
  día cambia una de las dos curvas, la otra no se entera.
- **El aporte del catálogo es un número abstracto**, no "minutos" ni "%": así el mismo dato sirve a dos
  fórmulas distintas sin mentir en ninguna de las dos.
- **Parámetro opcional en vez de firma nueva** (`tasa_drenaje(mult_hac, mult_com = -1.0)`): los ~40
  tests de Paciencia siguen llamando igual y midiendo lo mismo. El −1 significa "no me lo han dicho"
  → knob de siempre.
- **La media, no la suma, en `confort_de_servicio`**: si fuera suma, construir salas vacías subiría el
  confort. Con una sola sala —el caso normal— el número es exactamente el suyo.
