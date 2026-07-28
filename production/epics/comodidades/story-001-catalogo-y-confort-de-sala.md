# Story 001: El catálogo de objetos y el confort de la sala

> **Epic**: Comodidades #15
> **Status**: Complete
> **Layer**: Feature (catálogo + Construcción)
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-28 — creada

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F1 · `mult_comodidad`) + `design/gdd/construction-layout.md`
(elementos colocables) — el GDD propio del sistema se hará con `/reverse-document` si el epic crece.
**Requirement**: `TR-patience-001` (el hueco `mult_comodidad`) — sin TR propio: es un epic post-MVP.
**Governing ADRs**: ADR-0003 (primario — los objetos son catálogo), ADR-0001, ADR-0002

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: los `.tres` se generan con `tools/build_catalogo.gd` (nunca a mano).

**Control Manifest Rules**:
- Required: definiciones del catálogo read-only vía `Datos.obtener` — nunca mutar lo que devuelve. — ADR-0003
- Required: Construcción cobra por la API de Economía (gate E4), jamás toca el saldo. — ADR-0001
- Forbidden: números de balance en el código (aportes y costes salen del `.tres`). — ADR-0003

---

## Decisiones de diseño (cerradas con el usuario 2026-07-28)

1. **El confort es POR SALA**, no por asiento: una tele la disfruta todo el que espera ahí. Mucho más
   fácil de entender al jugarlo y de explicar en pantalla.
2. **Dos familias de objetos**, mismo catálogo:
   - **Comodidad del ciudadano** (sala de *espera*) → aporta **confort** → la gente aguanta más.
   - **Equipamiento del funcionario** (sala con *puestos*) → aporta **rendimiento** → atienden antes.
3. **Mantenimiento solo para lo que consume**: la radio, la tele, el vending, la fuente y los equipos
   informáticos tienen coste diario; la papelera y el revistero se pagan una vez y ya. *Así hay dos
   tipos de compra: la barata para siempre y la potente que te sangra cada día.*

### Catálogo semilla

| id | nombre | familia | € compra | €/día | aporte |
|---|---|---|---|---|---|
| `papelera` | Papelera | ciudadano | 60 | 0 | confort 1 |
| `revistero` | Revistero | ciudadano | 150 | 0 | confort 2 |
| `radio` | Hilo musical | ciudadano | 250 | 1 | confort 3 |
| `fuente_agua` | Fuente de agua | ciudadano | 400 | 2 | confort 3 |
| `vending` | Máquina de vending | ciudadano | 1.200 | 3 | confort 5 |
| `television` | Televisión | ciudadano | 900 | 4 | confort 6 |
| `equipo_informatico` | Equipo informático nuevo | funcionario | 1.500 | 2 | rendimiento 4 |
| `impresora_dni` | Impresora de DNI moderna | funcionario | 2.200 | 3 | rendimiento 6 |

---

## Acceptance Criteria

- [x] **AC-CM01** `[Integration]` — GIVEN el catálogo THEN existen los 8 objetos con su coste, su
      mantenimiento y su aporte, y `Datos` los indexa como tipo `Comodidad`.
- [x] **AC-CM02** `[Integration]` — GIVEN una sala de espera WHEN se coloca un objeto de ciudadano
      THEN se cobra su precio (gate E4) y el **confort de la sala** sube por su aporte.
- [x] **AC-CM03** `[Integration]` — GIVEN un objeto de **funcionario** WHEN se intenta colocar en una
      sala de **espera** THEN se rechaza (y al revés: una tele no va en la oficina).
- [x] **AC-CM04** `[Integration]` — GIVEN objetos con mantenimiento WHEN cierra el día THEN Economía
      recibe la suma diaria **antes** de calcular el balance, y sin objetos recibe 0.
- [x] **AC-CM05** `[Integration]` — GIVEN un objeto demolido THEN deja de aportar confort y deja de
      costar mantenimiento (y reembolsa como cualquier elemento).
- [x] **AC-CM06** `[Unit]` — GIVEN varias salas de espera de un servicio THEN
      `confort_de_servicio(servicio)` es la **media** de sus salas (con una sola sala, la suya).

---

## Implementation Notes

- **Esquema**: `src/foundation/datos/esquema/comodidad.gd` (`class_name Comodidad extends Resource`):
  `id`, `nombre`, `descripcion`, `familia` (`@export_enum("ciudadano","funcionario")`),
  `coste_construccion_eur`, `coste_mantenimiento_dia_eur`, `aporte` (float), `superficie` (1).
  Carpeta `datos/comodidades/`, indexado en `datos.gd` como `TIPO_COMODIDAD`.
- **Construcción**:
  - `validar_elemento` acepta el tipo nuevo: familia `ciudadano` → solo salas `espera`; familia
    `funcionario` → solo salas con puestos (`tipo != "espera"`).
  - `coste_elemento` lee el coste del catálogo (ya hace lo mismo con los puestos).
  - `confort_de_sala(sala_id)` / `equipamiento_de_sala(sala_id)`: suma de aportes de esa familia.
  - `confort_de_servicio(servicio)`: **media** de las salas de espera de ese servicio (0 si no hay).
  - `equipamiento_de_puesto(puesto_id)`: el de la sala donde vive el puesto.
  - `mantenimiento_dia()`: suma de `coste_mantenimiento_dia_eur` de todo lo colocado.
  - Se registra en `nuevo_dia` con **prioridad 16** (tras Documentación 15, antes de Economía 20) y
    llama a `Economia.registrar_mantenimiento(eur)`.
- **Economía**: `registrar_mantenimiento(eur)` + `_mantenimiento_dia` sumado a los gastos del día y
  reseteado en el cierre — mismo patrón exacto que las horas extra de la peonada.

---

## Out of Scope

- Que el confort **haga efecto** en la paciencia y el rendimiento → **story 002**.
- Comprarlos desde el menú del clic derecho → **story 003**.

---

## QA Test Cases

`tests/integration/comodidades/comodidades_catalogo_test.gd`
- **AC-CM01**: los 8 objetos existen con sus valores exactos · edge: id inexistente → null + aviso
- **AC-CM02**: colocar una tele en la sala de espera cobra 900 € y sube el confort en 6
- **AC-CM03**: tele en oficina → rechazada; equipo informático en sala de espera → rechazado
- **AC-CM04**: 1 radio + 1 tele → 5 €/día a Economía en el cierre · sin objetos → 0
- **AC-CM05**: demoler la tele baja el confort y el mantenimiento
- **AC-CM06**: dos salas de espera de Doc (confort 6 y 0) → `confort_de_servicio` = 3

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/comodidades/comodidades_catalogo_test.gd` en verde + suite.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002
