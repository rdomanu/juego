# Story 007: Persistencia y el determinismo con abandonos

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (Edge Cases de guardado)
**Requirement**: `TR-patience-001..004` *(cierre transversal)*
**Governing ADRs**: ADR-0002 (primario — save/load + `Persist`; RNG serializado por RNGService)
**ADR Decision Summary**: cada sistema serializa SU estado, en tipos JSON-safe; cargar arranca en Pausa
y no emite señales.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (es la red de seguridad de todo el epic)
**Engine Notes**: `StringName` → `String` al guardar.

**Control Manifest Rules (Feature)**:
- Required: `save()` / `load_state()` + grupo `"Persist"`; **NUNCA** duplicar el estado del RNG (lo
  serializa RNGService). — ADR-0002
- Required: las paciencias se guardan por clave estable de persona (turno + servicio), no por
  referencia de objeto. — ADR-0002

---

## Acceptance Criteria

- [ ] **AC-PS21** `[Unit]` — GIVEN save a mitad de jornada WHEN se carga THEN paciencias, acumulador de
      satisfacción y contadores se **restauran**; arranca en Pausa.
- [ ] **AC-PS23** `[Unit]` — GIVEN misma semilla + misma secuencia de esperas WHEN se ejecuta dos veces
      THEN los abandonos son **idénticos**.

---

## Implementation Notes

- Guardar: paciencia por persona, `sat_actual`/acumuladores por servicio, `sat_cierre` por servicio,
  `reclamaciones_jornada`, `reclamaciones_mes`, graves, y la marca `es_reclamacion` de las fichas vivas.
- **La prueba reina, ampliada**: el test A-vs-B de flujo-007 (partida guardada y recargada vs partida
  continua) debe repetirse **con Paciencia activa y abandonos ocurriendo**. Si A ≠ B, hay estado que no
  se está guardando o un orden no determinista.
- Ojo con la reconstrucción de referencias al cargar: las personas las restaura Flujo; Paciencia debe
  **reengancharse** a ellas por su clave, igual que Personal reconstruye asignaciones.
- Correr este test también en las stories anteriores (no dejarlo para el final): es la red que avisa de
  que algo se ha colado mal en el orden del tick.

---

## Test Cases

`tests/integration/paciencia/paciencia_save_determinismo_test.gd`
- `test_guardar_y_cargar_restaura_paciencias_y_contadores` (AC-PS21)
- `test_carga_arranca_en_pausa_sin_emitir_senales` (patrón ADR-0002)
- `test_misma_semilla_mismos_abandonos` (AC-PS23)
- `test_a_vs_b_con_abandonos_y_reclamaciones` (**la prueba reina** — misma secuencia de eventos)

---

## Out of Scope

- Lo visible (008).
