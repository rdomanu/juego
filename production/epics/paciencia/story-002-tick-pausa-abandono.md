# Story 002: El tick, la Pausa y EL ABANDONO — la gente se va

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (PS2, PS6, F1; Edge Cases del empate)
**Requirement**: `TR-patience-002` (escucha eventos de Flujo; ordena el abandono al llegar a 0)
**Governing ADRs**: ADR-0001 (primario — orden del tick y determinismo)
**ADR Decision Summary**: Paciencia se suscribe al tick **DESPUÉS de Flujo** (orden del ADR: Tiempo →
Demanda → Flujo → Paciencia) y **ordena** el abandono por la API pública de Flujo; jamás toca el estado
de una persona por su cuenta.

**Engine**: Godot 4.6 | **Risk**: **MEDIUM** — es la story que mete a Paciencia dentro del bucle de
simulación; aquí es donde se puede romper el determinismo.
**Engine Notes**: la simulación corre en `_physics_process` vía el tick de Tiempo; nunca en `_process`.

**Control Manifest Rules (Feature)**:
- Required: `Tiempo.suscribir_tick(...)` en `_ready` (solo en árbol), **después** de Flujo. — ADR-0001
- Required: el abandono se ejecuta con `Flujo.forzar_abandono(persona)` — API creada para esto en
  flujo-006. Paciencia **no** muta colas ni estados. — ADR-0001
- Forbidden: iterar y mutar el diccionario de paciencias dentro del mismo bucle (recoger y aplicar
  después — gotcha ya visto en Flujo con `_puestos_a_retirar`).

---

## Acceptance Criteria

- [ ] **AC-PS04** `[Integration]` — GIVEN una persona esperando WHEN es **llamada a puesto** THEN su
      paciencia se **congela** (no drena ni abandona) hasta que termina el trámite.
- [ ] **AC-PS19** `[Integration]` — GIVEN empate llamada-vs-abandono en el mismo tick THEN gana la
      **llamada** y **no** hay hoja de reclamación.
- [ ] **AC-PS22** `[Unit]` — GIVEN Pausa WHEN pasa tiempo real THEN la paciencia **no** drena.

---

## Implementation Notes

- **Enganche**: alta de paciencia al entrar en cola (evento/consulta de Flujo), baja al resolverse.
  Recorrer solo las personas en estado `esperando_dentro` / `esperando_fuera`.
- **Congelación (PS04)**: los estados `llamada` y `en_atencion` NO drenan. Ojo: con la enmienda
  "EN CAMINO no se tramita" (flujo-004), `llamada` puede durar varios minutos mientras la persona
  camina — **esos minutos tampoco drenan**: ya la han llamado, su espera terminó.
- **El empate (PS19) sale gratis**: `Flujo.forzar_abandono` ya devuelve `false` si la persona está en
  `llamada`/`en_atencion` (regla dura implementada y testeada en flujo-006). Paciencia **debe respetar
  ese `false`**: si es `false`, no cuenta abandono ni genera reclamación. Es el orden del tick el que
  garantiza que la llamada de Flujo ocurre antes.
- **Pausa (PS22)**: no hace falta lógica propia — el tick de Tiempo no entrega minutos en Pausa. El test
  debe verificarlo con el reloj real en el árbol (patrón `demanda_tick_ventana_test`).
- **Determinismo**: el orden de recorrido debe ser estable (por `numero_turno`, nunca por orden de
  diccionario) — si dos personas llegan a 0 en el mismo tick, siempre abandona antes la de menor turno.

---

## Test Cases

`tests/integration/paciencia/paciencia_tick_abandono_test.gd`
- `test_llamada_congela_la_paciencia` (AC-PS04)
- `test_en_camino_no_drena` (enmienda del camino — caso nuevo, no estaba en el GDD)
- `test_empate_llamada_vence_al_abandono_y_no_hay_hoja` (AC-PS19)
- `test_pausa_no_drena` (AC-PS22, con reloj real en árbol)
- `test_dos_a_cero_el_mismo_tick_abandona_antes_el_de_menor_turno` (determinismo)
- `test_abandono_libera_plaza_y_entra_el_de_fuera` (integración con FL6)

---

## Out of Scope

- Contar reclamaciones y generarlas en ODAC (006) — aquí el abandono ocurre, pero no genera papeleo.
- La puntuación de la visita abandonada (003).
