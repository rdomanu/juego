# Story 001: La barra de cansancio y el patrón de cada uno

> **Epic**: Bienestar #13
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-29 — implementada y testeada (a4eb42c); AC verificados al cerrar el epic

## Context

**GDD**: pendiente (el epic nace de una petición directa del usuario, 2026-07-28) ·
`design/gdd/staff-agents.md` (atributos del agente, `motivacion` 1-5)
**Governing ADRs**: ADR-0003 (los knobs, del catálogo), ADR-0001 (Personal posee a sus agentes)

**Engine**: Godot 4.6 | **Risk**: LOW — aritmética y estado, sin API de motor.

**Control Manifest Rules**:
- Required: los valores salen del `.tres`, nunca del código. — ADR-0003
- Required: el cansancio es estado de **Personal** (los agentes son suyos); Flujo solo consulta el
  gate de dotación que ya existe. — ADR-0001
- Forbidden: azar sin RNGService. *(Aquí directamente no hay azar: ver decisión de diseño.)*

---

## Decisiones de diseño (cerradas 2026-07-28)

**La petición literal del usuario:** *"hay que tener en cuenta el cansancio de los funcionarios,
deberíamos tener una sala de descanso, cuando la barra de cansancio del funcionario se agote se
levantan y se van a descansar, calcula que más o menos y lo que debería ser es de 30 minutos por
jornada, hay algunos que hacen 15 y 15, otros 30 minutos enteros e incluso hay funcionarios que se
van 1 hora aun sabiendo que no se puede"*.

**1. El patrón sale de la MOTIVACIÓN, no de un dado.** Es la decisión importante del epic:

| Motivación | Patrón | Descanso | Quién es |
|---|---|---|---|
| **5** | `dos_cafes` | 2 × 15 min | El cumplidor: parte su media hora en dos |
| **3–4** | `un_cafe` | 1 × 30 min | La media hora de un tirón — lo reglamentario |
| **1–2** | `caradura` | 1 × **60 min** | Se toma el doble **a sabiendas** de que no puede |

Así el atributo `motivacion`, que hoy solo modula rapidez y trato en unas fórmulas invisibles, **se ve
en pantalla**. Y cierra un bucle con Documentación #8: hacer salir tarde a la gente (margen 0) baja su
motivación… y una motivación baja convierte a un cumplidor en un caradura. **Exprimir sale caro dos
veces.** Sin RNG: el mismo agente se comporta igual siempre, y el jugador puede *aprender* a leerlo.

**2. El cansancio sube solo mientras ATIENDE**, no mientras espera cliente. Estar de brazos cruzados
en una ventanilla vacía no cansa; despachar sin parar, sí. Además hace que la decisión de horario de
Documentación importe: una tarde de peonada con cola llena quema a la gente de verdad.

**3. El aguante se reparte entre las pausas**: quien hace dos pausas se agota a la mitad de camino.
Así los tres patrones consumen su presupuesto en una jornada normal, que es lo que pidió el usuario.

---

## Acceptance Criteria

- [x] **AC-BI01** `[Unit]` — GIVEN un agente que atiende THEN su cansancio sube
      `100 / minutos_aguante_efectivo` por minuto **de atención**; parado no sube nada.
- [x] **AC-BI02** `[Unit]` — GIVEN motivación 5 / 3 / 1 THEN su patrón es `dos_cafes` (2×15) /
      `un_cafe` (1×30) / `caradura` (1×60).
- [x] **AC-BI03** `[Unit]` — GIVEN el patrón `dos_cafes` (2 pausas) y `minutos_aguante` 180 THEN su
      aguante efectivo es **90 min** (se agota dos veces por jornada); con `un_cafe`, 180.
- [x] **AC-BI04** `[Unit]` — GIVEN el cansancio a 100 THEN `necesita_descanso(agente)` es `true` y
      `minutos_de_pausa(agente)` devuelve los de su patrón.
- [x] **AC-BI05** `[Unit]` — GIVEN un agente que ya ha gastado todas las pausas de su jornada THEN no
      vuelve a pedir descanso aunque su barra se agote otra vez (aguanta hasta el cierre).
- [x] **AC-BI06** `[Unit]` — GIVEN un `.tres` con valores fuera de rango THEN se clampan con aviso y
      el sistema queda en un estado válido (patrón del proyecto).

---

## Implementation Notes

- **Dónde vive**: `src/core/personal/personal.gd` (los agentes son suyos) + `ConfigPersonal`.
  El estado por agente va en el propio `Agente` (`cansancio`, `pausas_gastadas`), que ya se serializa.
- **Knobs nuevos** (`ConfigPersonal`): `minutos_aguante` (180) · `min_pausa_corta` (15) ·
  `min_pausa_normal` (30) · `min_pausa_caradura` (60) · `mult_cansancio_horas_extra` (1.5, lo usará
  la story 002 para que la peonada queme más).
- **Fórmulas puras** (sin reloj, sin árbol → testeables solas):
  - `patron_de(agente)` → `&"dos_cafes"` / `&"un_cafe"` / `&"caradura"` según motivación.
  - `pausas_de(agente)` → 2 / 1 / 1 · `minutos_de_pausa(agente)` → 15 / 30 / 60.
  - `aguante_efectivo(agente)` = `minutos_aguante / pausas_de(agente)`.
  - `cansar(agente, minutos)` → sube la barra con clamp a 100.
  - `necesita_descanso(agente)` = barra llena **y** le quedan pausas.
- **Nada de reloj aquí**: quién llama a `cansar` y cuándo es la story 002.

---

## Out of Scope

- Levantarse de verdad, el gate de Flujo y la vuelta al puesto → **story 002**.
- La sala de descanso y el castigo por no tenerla → **story 003**.
- Verlo en pantalla → **story 004**.

---

## QA Test Cases

`tests/unit/personal/personal_cansancio_test.gd`
- **AC-BI01**: 30 min atendiendo con aguante 180 → cansancio 16,7 · 0 min → sin cambio
- **AC-BI02**: motivación 5 → `dos_cafes` · 4 y 3 → `un_cafe` · 2 y 1 → `caradura`
- **AC-BI03**: aguante efectivo 90 con `dos_cafes`, 180 con `un_cafe` y con `caradura`
- **AC-BI04**: barra a 100 → necesita descanso; 99 → todavía no
- **AC-BI05**: gastadas las pausas del día → `necesita_descanso` false aunque la barra esté a tope
- **AC-BI06**: `minutos_aguante` 0 o negativo → clamp con aviso, sin división por cero

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/personal/personal_cansancio_test.gd` — debe existir y pasar.

**Status**: [x] Passing — `tests/unit/personal/personal_cansancio_test.gd`, 15 tests, dentro de la suite 591/591 exit 0 (verificado 2026-07-29)

---

## Dependencies

- Depends on: None
- Unlocks: Story 002
