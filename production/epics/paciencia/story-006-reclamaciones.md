# Story 006: Reclamaciones — quien se va cabreado te da trabajo

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (PS13, contadores; Edge Cases de recursión)
**Requirement**: `TR-patience-004` (genera `reclamacion` en ODAC con prob/RNG; **sin recursión**;
empate llamada-vs-abandono → gana la llamada)
**Governing ADRs**: ADR-0002 (primario — **RNG determinista y serializado**), ADR-0001, ADR-0003
**ADR Decision Summary**: toda tirada aleatoria pasa por **RNGService** (nunca `randf` propio) y su
estado lo serializa RNGService, no Paciencia. El tipo `tramite_reclamacion` está en el catálogo.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (aleatoriedad + riesgo de bucle infinito)
**Engine Notes**: gotcha registrado — si un método propio se llama como una utilidad global (`randf`),
hay que cualificar con `self.`; aquí directamente **no se usa `randf`**.

**Control Manifest Rules (Feature)**:
- Required: `RNGService` para `prob_reclamacion`; determinismo por semilla. — ADR-0002
- Required: la reclamación entra en ODAC como un trámite normal **por la API de Flujo**, con el tipo del
  catálogo (30 min, Normal, sin tarifa). — ADR-0003
- Forbidden: que una reclamación abandonada genere otra reclamación (**recursión** — corta el bucle).

---

## Acceptance Criteria

- [ ] **AC-PS15** `[Unit]` — GIVEN un abandono THEN `reclamaciones_jornada += 1` y `reclamaciones_mes += 1`.
- [ ] **AC-PS16** `[Integration]` — GIVEN abandono de Documentación y `prob_reclamacion = 1.0` (test)
      THEN aparece un trámite `reclamacion` (30 min, Normal) en la **cola de ODAC**.
- [ ] **AC-PS17** `[Integration]` — GIVEN una `reclamacion` que abandona en ODAC THEN suma al contador
      pero **NO** genera otra (sin recursión).
- [ ] **AC-PS18** `[Unit]` — GIVEN abandono de una **Prioritaria de ODAC** THEN la hoja se marca **grave**.
- [ ] **AC-PS20** `[Unit]` — GIVEN `nuevo_mes` THEN `reclamaciones_mes` se **evalúa y resetea a 0**.

---

## Implementation Notes

- **Corte de recursión**: marcar la persona/ficha generada como `es_reclamacion`. Al abandonar, si ya lo
  es → cuenta pero no engendra. Es la regla que evita la bola de nieve infinita.
- **Carga autoinfligida**: la reclamación ocupa un puesto de ODAC 30 min y **no paga tarifa** — el
  castigo real de la mala gestión no es un número en un panel, es tiempo de ventanilla perdido.
- `prob_reclamacion` 0.4 (cross-fact registrado). Los tests fuerzan 1.0 / 0.0 para ser deterministas.
- `nuevo_mes` es evento ordenado; registrar el handler con su prioridad (patrón de Personal/Economía).
- **Graves** (AC-PS18): abandono de una denuncia Prioritaria → bandera aparte en el contador; será KPI de
  la valoración de jefes (#28, fuera del MVP) y se muestra separado en el HUD.

---

## Test Cases

`tests/integration/paciencia/paciencia_reclamaciones_test.gd`
- `test_abandono_suma_a_los_dos_contadores` (AC-PS15)
- `test_abandono_doc_con_prob_uno_encola_reclamacion_en_odac` (AC-PS16)
- `test_reclamacion_abandonada_no_genera_otra` (AC-PS17 — el anti-bucle)
- `test_abandono_de_prioritaria_marca_grave` (AC-PS18)
- `test_nuevo_mes_resetea_el_contador_mensual` (AC-PS20)
- `test_misma_semilla_mismas_reclamaciones` (determinismo del RNG)

---

## Out of Scope

- La reconfiguración de puestos de ODAC (epic ODAC #9).
- El HUD de contadores (008).
