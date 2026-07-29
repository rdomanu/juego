# Story 004: Ver quién está de café — y notarlo en la cola

> **Epic**: Bienestar #13
> **Status**: Complete
> **Layer**: Presentation (+ Feature para el multiplicador de rendimiento)
> **Type**: Visual/UI (+ Logic para `mult_cansancio_rendimiento`)
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-29 — escrita a posteriori (implementada en `bb4b7bd` y `6442505`)

## Context

> **Nota de proceso**: esta story se redacta DESPUÉS de la implementación, al cerrar el epic
> Bienestar #13 — no hay diseño previo a picar como en la 001, lo que sigue documenta lo que YA se
> construyó y YA se testeó, para dejar rastro formal.

**GDD**: pendiente (el epic nace de una petición directa del usuario, 2026-07-28) ·
`design/gdd/flow-queues.md` (FL5, desplazamiento cosmético) · `design/gdd/staff-agents.md`
**Governing ADRs**: ADR-0001 (la capa visual LEE a Personal/Construcción, nunca los muta), ADR-0003
(el multiplicador es un knob del `.tres`), ADR-0004 (capa cosmética, refresco por DIFF)

**Engine**: Godot 4.6 | **Risk**: LOW — capa visual sobre NPCs existentes + una multiplicación de
fórmula; sin API de motor nueva.

**Control Manifest Rules**:
- Required: `k_cansancio_rendimiento` sale del `.tres`, nunca hardcodeado. — ADR-0003
- Required: el visual LEE el estado de `Personal`/`Construcción` y jamás decide nada (FL5). — ADR-0001
- Required: refresco por **DIFF** (firma), no por frame. — ADR-0004
- Forbidden: que el HUD o el rótulo del puesto muten cansancio, cola o dinero.

---

## Decisiones de diseño (tomadas durante la implementación)

**1. Una ventanilla parada sin explicación parece un BUG.** Con el rótulo ámbar tostado
("☕ DESCANSO" + minutos que le quedan) y el nombre del titular todavía puesto —solo que ahora no
hay nadie detrás del mostrador— pasa a leerse como una decisión de gestión ("¿monto la sala de
descanso? ¿contrato a alguien que cubra?") en vez de un fallo. El ámbar es a propósito: ni rojo
(alarma) ni verde (todo bien) — es un aviso que se resuelve solo.

**2. Sin sala construida, no se pinta a nadie de café.** Los que descansan se dibujan DENTRO de la
sala de descanso, con su taza; sin ella, esos agentes desaparecen del mapa — se entienden en la
calle. Esa ausencia también informa, igual que un puesto sin dotar no tiene muñeco.

**3. El cansancio ralentiza ANTES de mandar a nadie a descansar.** `mult_cansancio_rendimiento = 1 +
0,25 × (cansancio/100)`: barra a tope, un 25 % más lento por trámite; a media barra, un 12,5 %.
Progresivo A PROPÓSITO — la cola se alarga antes del café, así el jugador VE VENIR el problema en
vez de encontrárselo de golpe. Se aplica FUERA del clamp de F2: F2 mide lo bueno que es el agente
(ahí el tope tiene sentido); el cansancio es una condición pasajera que se suma encima.

**4. Dos avisos, no uno.** "Café" (ámbar, vuelven solos) y "nadie puede atender" (rojo, falta gente
contratada) piden soluciones distintas, así que no comparten texto. Si coinciden los dos, manda el
rojo — es la alarma más urgente.

---

## Acceptance Criteria

- [x] **AC-BI25** `[Visual]` — GIVEN un agente en descanso THEN su rótulo es ámbar "☕ DESCANSO" +
      minutos restantes, mostrador VACÍO (muñeco oculto) pero el NOMBRE del titular sigue visible.
- [x] **AC-BI26** `[Visual]` — GIVEN varios agentes de café THEN se pintan dentro de la sala de
      descanso con su taza, repartidos en fila sin salirse del rectángulo de la sala.
- [x] **AC-BI27** `[Visual]` — GIVEN ninguna sala de descanso construida THEN no se pinta ningún
      muñeco de café (se han ido a la calle).
- [x] **AC-BI28** `[Visual]` — GIVEN que el número de agentes de café no cambia entre frames THEN la
      capa de descansos no repuebla nodos (firma por conteo).
- [x] **AC-BI29** `[Unit]` — GIVEN cansancio a 100 THEN `mult_cansancio_rendimiento(agente)` es 1,25;
      a 50, es 1,125 (progresivo, no de golpe).
- [x] **AC-BI30** `[Unit]` — GIVEN `modificador_produccion_de(puesto)` THEN el cansancio multiplica
      FUERA del resultado ya clampado de F2, nunca dentro del propio clamp.
- [x] **AC-BI31** `[Unit]` — GIVEN un agente que vuelve de su descanso (cansancio a 0) THEN su
      rendimiento vuelve a ser el del principio de la jornada.
- [x] **AC-BI32** `[Unit]` — GIVEN `Personal.puestos_en_descanso()` THEN devuelve las ventanillas de
      quien está de café ahora, vacío si nadie lo está.
- [x] **AC-BI33** `[Visual]` — GIVEN al menos un puesto de café y ningún huérfano de personal THEN el
      HUD muestra aviso ÁMBAR propio ("☕ N ventanilla(s) de descanso · M esperando"), distinto del
      aviso ROJO de "nadie puede atender".
- [x] **AC-BI34** `[Visual]` — GIVEN huérfanos de personal Y café a la vez THEN el HUD prioriza el
      aviso ROJO — el ámbar no compite con la alarma más urgente.

---

## Implementation Notes

- **Rótulo y mostrador** (`src/main/npcs_flujo.gd`): estado nuevo `&"descansando"` en
  `ROTULO_ESTADO`/`COLOR_ESTADO` (ámbar `Color(0.85, 0.7, 0.45)`); `_rotulo_extra` guarda la 2.ª línea
  ("☕ N min") por puesto. `_actualizar_visual_puesto()` gana el parámetro `extra`, mismo patrón por
  DIFF (metas `dotado`/`nombre`/`estado`/`extra` — cero toques si nada cambió). `policia.visible` se
  apaga con `estado == &"descansando"`; `lbl_nombre` se fuerza visible en ese estado.
- **Sala de descanso** (`src/main/npcs_flujo.gd`): `_capa_descansos` (Node2D hijo) +
  `_refrescar_descansos()` (junto a `_refrescar_puestos()` en `_physics_process`), repuebla solo si
  cambia la FIRMA (`"%d" % descansando.size()`) — cero trabajo por frame si nadie se ha movido.
  `_sala_de_descanso()` usa `Construccion.salas_de_tipo("descanso")` (método nuevo, filtra `_salas`
  por `TipoSala.tipo`); sin sala, `&""` y no se pinta nada. `_crear_muneco_policia()` reutiliza el
  torso+cabeza de los mostradores.
- **Rendimiento** (`src/core/personal/personal.gd` + `config_personal.gd`): knob
  `k_cansancio_rendimiento` (default 0,25, clamp `[0, 2]`). `mult_cansancio_rendimiento(agente)` es
  fórmula pura (`1.0 + k * cansancio/100`); `modificador_produccion_de(puesto)` la multiplica
  DESPUÉS de `modificador_produccion(agente)` (donde vive el clamp de F2) — nunca dentro de él.
  `puestos_en_descanso()` filtra `_asignaciones` por `agente_descansando_en(puesto) != null`.
- **HUD** (`src/main/main.gd`, `_refrescar_etiquetas`): tres ramas — sin huérfanos ni café (vacío),
  huérfanos presentes (rojo, prioridad), o solo café (ámbar + cola de Documentación/ODAC si la hay).
- **Nota honesta — 4 tests rotos, NO maquillados**: el cansancio progresivo hace que el 2.º trámite
  dure más que el 1.º, y rompió tests de Flujo/Paciencia que contaban minutos exactos con `Personal`
  (`flujo_aforo`, `flujo_camino`, `flujo_gestion_caliente`, `flujo_horario`, `flujo_puestos`,
  `flujo_save_determinismo`, `paciencia_tick_abandono`). Corrección: APAGAR la variable en sus
  fixtures (`personal.k_cansancio_rendimiento = 0.0`) para aislar lo que cada test mide — el mismo
  patrón que ya usaban con `velocidad_camino_celdas_min = 0.0`. El único ajuste real fue
  `test_atender_cansa_y_el_cafe_se_pide_al_acabar_el_tramite` (14→20 ticks: agotado tarda ~15 min en
  un DNI, no 12). Lección de método: si una variable nueva se cuela en tests que no la medían, se
  aísla en el fixture — no se maquilla el resultado.

---

## Out of Scope

- Mejoras de la sala de descanso en sí (aforo, calidad) → **Comodidades #15**.
- Audio/juice del café (sonido de taza, animación de sentarse) → **Feedback y Juice #12**.
- Arte final de los muñecos → **art bible**, todo el visual actual es andamio declarado.
- La demo en ventana con sign-off del usuario → siguiente paso, ver "Test Evidence".

---

## QA Test Cases

**Automático** — `tests/integration/personal/personal_descanso_test.gd`:
- `test_un_agente_agotado_atiende_mas_despacio` — AC-BI29, AC-BI30 (barra a tope → ×1,25 sobre el
  `modificador_produccion_de` ya clampado por F2).
- `test_el_bajon_es_progresivo_no_de_golpe` — AC-BI29 (media barra → ×1,125).
- `test_al_volver_del_cafe_rinde_como_al_principio` — AC-BI31.
- `test_el_hud_puede_saber_quien_esta_de_cafe` — AC-BI32 (vacío → `&"doc_1"` → vacío al volver).

**Manual (Visual, pendiente de demo)** — AC-BI25..23, AC-BI33..29: agente cansado SIN sala de
descanso (nadie se pinta) → construirla → ver la taza dentro, el rótulo ámbar y el nombre puesto con
el mostrador vacío → cruzar un huérfano de personal con uno de café y ver que el HUD prioriza el rojo.

---

## Test Evidence

**Story Type**: mixta — Logic (`[Unit]`, BLOCKING) + Visual/UI (`[Visual]`, ADVISORY).

**Logic**: [x] Completo — `tests/integration/personal/personal_descanso_test.gd`, 4 tests nuevos en
verde. SUITE 577/577, exit 0, arranque headless limpio (commit `6442505`).

**Visual**: [ ] Pendiente de demo — `production/qa/evidence/bienestar-004-demo-<fecha>.md`
(checklist AC-BI25..23, AC-BI33, AC-BI34 + captura + sign-off) no existe todavía; es el siguiente
paso antes de cerrar el epic del todo.

---

## Dependencies

- Depends on: Story 001 (barra de cansancio, `bien-001`), y las stories 002 (`bien-002`, precio de la
  hora extra) y 003 (`bien-003`, sala de descanso real) — implementadas, sin story doc formal propia.
- Unlocks: cierre del epic **Bienestar #13**, condicionado a la demo pendiente arriba.
