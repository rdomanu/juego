# Story 003: El uso de los objetos — vending, fuente y revistero

> **Epic**: Comodidades #15
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-28 — creada

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F1 — `mult_comodidad`, el drenaje que esta story
también pausa) + `design/gdd/construction-layout.md` (elementos colocables) — sigue sin GDD propio,
igual que 001/002.
**Requirement**: `TR-patience-001` (el hueco de Comodidades) — sin TR propio: epic post-MVP.
**Origen**: **petición del usuario (2026-07-28)** — *"la gente tiene que acercarse a la máquina de
vending y consumir algo, sacar de beneficio 1 euro por ejemplo"*. Hasta esta story, los objetos de la
familia "ciudadano" eran decorado puro: subían `mult_comodidad` con solo estar instalados. Esta story
hace que ALGUNOS se **usen de verdad**: la persona deja la cola un rato, va al objeto, recupera
paciencia (y a veces deja dinero) y vuelve.

**Governing ADRs**: ADR-0002 (primario — el azar de "¿se levanta?" viene SIEMPRE de RNGService,
determinista), ADR-0001 (cada sistema cobra por su propia API: Economía por `registrar_consumicion`,
Paciencia nunca toca el saldo), ADR-0003 (usable/ingreso/recuperación/minutos son campos del catálogo)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules**:
- Required: el azar de si alguien se levanta a por algo viene SIEMPRE de `RNGService`, nunca de un
  `randf()` global — determinismo de la partida. — ADR-0002
- Required: el dinero de la consumición entra por la API de Economía (`registrar_consumicion`);
  Paciencia solo la llama, nunca toca `saldo_eur` directamente. — ADR-0001
- Forbidden: hardcodear el importe cobrado o los minutos que recupera cada objeto — viven en el
  `.tres` de cada `Comodidad` (`usable`, `ingreso_por_uso_eur`, `recupera_paciencia`,
  `minutos_de_uso`). — ADR-0003

### Catálogo — quién se usa y quién solo ambienta

| id | usable | €/uso | recupera | minutos del gesto |
|---|---|---|---|---|
| `vending` | sí | 1,0 | 15 | 3,0 (default del esquema) |
| `fuente_agua` | sí | 0,0 | 10 | 2,0 |
| `revistero` | sí | 0,0 | 8 | 2,0 |
| `television` | no | — | — | solo confort ambiental |
| `radio` (hilo musical) | no | — | — | solo confort ambiental |

---

## Acceptance Criteria

- [x] **AC-CM13** `[Integration]` — GIVEN el catálogo THEN el vending es usable (1 €, +15 paciencia),
      la fuente y el revistero son usables y **gratis** (+10 y +8), y la tele y el hilo musical **no**
      son usables (solo aportan confort de ambiente).
- [x] **AC-CM14** `[Integration]` — GIVEN una sala de espera con una tele y un vending instalados THEN
      `Construccion.usables_de_servicio(servicio)` devuelve **solo** el vending (la tele no es un
      destino al que ir).
- [x] **AC-CM15** `[Integration]` — GIVEN una persona que se pone a usar el vending WHEN termina su
      consumición THEN recupera **+15** de paciencia, Economía anota **+1 €** en
      `ingreso_comodidades_dia` (y el saldo sube) y deja de estar "en uso".
- [x] **AC-CM16** `[Unit]` — GIVEN una persona usando una comodidad THEN mientras dura el gesto su
      paciencia **no se consume** (no está "sufriendo la cola", está entretenida).
- [x] **AC-CM17** `[Unit]` — GIVEN un gesto que termina a mitad del tick THEN los minutos que sobran se
      devuelven para que cuenten como espera normal de ese mismo tick (no se pierden ni se duplican).
- [x] **AC-CM18** `[Unit]` — GIVEN una persona con la barra ya llena (100) WHEN vuelve de usar una
      comodidad THEN su paciencia **no supera el tope** de 100.
- [x] **AC-CM19** `[Integration]` — GIVEN la fuente de agua (gratis) WHEN alguien la usa THEN recupera
      paciencia pero Economía **no** recibe ningún ingreso.
- [x] **AC-CM20** `[Unit]` — GIVEN un recién llegado (paciencia 100, por encima del umbral 75) THEN
      **nunca** se levanta a una comodidad, aunque la tirada de azar fuese favorable.
- [x] **AC-CM21** `[Integration]` — GIVEN alguien por debajo del umbral (75) THEN, con la tirada de
      `RNGService` (determinista), se levanta y va a la **mejor** comodidad usable de su servicio.
- [x] **AC-CM22** `[Unit]` — GIVEN varias comodidades usables instaladas a la vez (revistero +8,
      vending +15) THEN se elige la que **más** paciencia devuelve.
- [x] **AC-CM23** `[Unit]` — GIVEN solo una tele instalada (confort ambiental, no usable) THEN nadie se
      levanta: no hay ningún objeto al que ir.
- [x] **AC-CM24** `[Integration]` — GIVEN Paciencia **sin Construcción inyectada** THEN nunca se genera
      ningún gesto de uso — degradación elegante, igual que el resto de Comodidades.
- [x] **AC-CM25** `[Integration]` — GIVEN una persona usando el vending WHEN se guarda y se recarga la
      partida THEN sigue "en la máquina" con los minutos de gesto que le quedaban.

---

## Implementation Notes

- **Esquema `Comodidad`** (`src/foundation/datos/esquema/comodidad.gd`): 4 campos nuevos — `usable`
  (bool), `ingreso_por_uso_eur`, `recupera_paciencia`, `minutos_de_uso` (default 3.0). Solo
  ciudadano/usable; el equipamiento del funcionario (story 002) no se toca.
- **Construcción**: `usables_de_servicio(servicio) -> Array[StringName]` — los elementos instalados en
  salas de espera de ese servicio (o `Comun`) cuyo `Comodidad.usable == true`; orden estable de
  construcción. Reutiliza `catalogo_de_elemento()` (ya existía desde la 001).
- **Paciencia** (`_usando_comodidad: Dictionary[RefCounted, Dictionary]` → `{elemento, catalogo,
  restante}`), knobs nuevos en `ConfigPaciencia`: `prob_uso_comodidad_min` (0.04, probabilidad por
  minuto) y `umbral_uso_comodidad` (75.0). Orden del tick por persona: 1) `_consumir_camino` (el paseo
  a su sitio no es espera) → 2) `_consumir_uso_comodidad` (si ya está en la máquina, gasta el gesto; al
  terminar suma `recupera_paciencia` con tope 100 y, si `ingreso_por_uso_eur > 0`, llama a
  `_economia.registrar_consumicion`) → 3) si no estaba usando nada, `_quizas_ir_a_una_comodidad`
  (umbral + tirada de `RNGService` sobre `prob_uso_comodidad_min × minutos`, eligiendo con
  `_mejor_comodidad_usable`: el usable instalado con mayor `recupera_paciencia`) → 4) si nada de lo
  anterior aplica, `drenar` como antes de esta story.
- **Economía**: `registrar_consumicion(euros)` + `ingreso_comodidades_dia` — se resetea en el cierre
  del día, mismo patrón que `registrar_mantenimiento` (story 001).
- **Persistencia**: `save()`/`load_state()` de Paciencia guardan `usando` (id de catálogo) y
  `usando_restante` (minutos que faltan del gesto) por persona restaurable. Al cargar, Flujo crea
  `PersonaFlujo` **nuevas**, así que el elemento concreto se re-busca por catálogo entre lo instalado
  (`_elemento_usable_de_catalogo`); si el jugador demolió la máquina antes de guardar, el gesto termina
  igual sin destino visible — inofensivo.
- **NPCs** (capa visual, cosmético puro — FL5): `npcs_flujo.gd` expone `comodidad_de(persona)` leyendo
  `Paciencia.comodidad_en_uso()` para que el muñeco camine hasta la máquina y vuelva; no decide nada.

---

## Out of Scope

- **Aforo o cola de la máquina**: cualquier número de personas puede estar "usando" el mismo objeto a
  la vez; no hay contención. Si hiciera falta (una única máquina, turnos), es una historia aparte.
- **El paseo real por el suelo** hasta la celda de la máquina es puramente visual y vive en la capa de
  NPCs; esta story solo expone el dato (`comodidad_en_uso`) que esa capa consulta.
- **Comprar y colocar los objetos**: ya resuelto en las stories 001 (catálogo) y 002 (menú del clic
  derecho sobre la sala).
- **Reequilibrar** `tolerancia_base_min`, el umbral (75) o la probabilidad (0.04) a la luz de la demo:
  decisión de balance del usuario, pendiente de playtest.

---

## QA Test Cases

`tests/integration/comodidades/comodidades_uso_test.gd`

- **AC-CM13**: vending usable 1 €/+15 · tele y radio no usables · fuente y revistero usables y gratis
- **AC-CM14**: tele + vending instalados → `usables_de_servicio` devuelve solo el vending
- **AC-CM15**: usar el vending → +15 paciencia, +1 € en `ingreso_comodidades_dia`, deja de estar en uso
- **AC-CM16**: 1 min de un gesto de 3 → la barra no se mueve
- **AC-CM17**: gesto de 2 min con 5 min de tick → sobran 3 min para la cola
- **AC-CM18**: entra con 100, gesto de 1 min → sigue en 100 (no rebasa el tope)
- **AC-CM19**: usar la fuente → recupera paciencia pero `ingreso_comodidades_dia` sigue en 0
- **AC-CM20**: paciencia 100 (recién llegado) → no se levanta pese a una tirada favorable
- **AC-CM21**: paciencia 60 (bajo el umbral) con minutos altos → la tirada satura y se levanta
- **AC-CM22**: revistero (+8) y vending (+15) instalados → elige el vending
- **AC-CM23**: solo una tele instalada → nadie se levanta
- **AC-CM24**: Paciencia sin Construcción inyectada → `_quizas_ir_a_una_comodidad` siempre `false`
- **AC-CM25**: gesto guardado por JSON y recargado con una `PersonaFlujo` nueva → sigue en la máquina

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/comodidades/comodidades_uso_test.gd` en verde + suite
completa.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (el multiplicador de confort/equipamiento ya en marcha; esta story añade el
  USO, no lo sustituye)
- Unlocks: cierre del epic Comodidades (pendiente el sign-off del usuario en ventana)
