# Story 007: Persistencia y el determinismo con abandonos

> **Epic**: Paciencia y Satisfacción
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — implementada + test 5/5, prueba reina incluida

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

- [x] **AC-PS21** `[Unit]` — GIVEN save a mitad de jornada WHEN se carga THEN paciencias, acumulador de
      satisfacción y contadores se **restauran**; arranca en Pausa.
- [x] **AC-PS23** `[Unit]` — GIVEN misma semilla + misma secuencia de esperas WHEN se ejecuta dos veces
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

## Cierre (2026-07-26)

Implementada en hilo principal (Opus 5). **La prueba reina pasó a la primera.**

- `save()` / `load_state()` + grupo `Persist`: barras, acumuladores del día, cierres y contadores de
  quejas. El RNG **no** se duplica (lo serializa RNGService — ADR-0002).
- **Reenganche por clave estable** (`servicio#turno`): al cargar, Flujo crea `PersonaFlujo` NUEVAS, así
  que guardar referencias a objetos no serviría de nada. Las barras esperan en un buffer y cada una
  se reengancha en cuanto se vuelve a ver a su dueña, dentro de `registrar` (único punto de alta).
- `flujo.gd`: getter nuevo **`personas_en_puestos()`**. Quien está en ventanilla ya no está en ninguna
  cola, así que sin este getter era invisible para Paciencia y, tras cargar, habría perdido su barra —
  y con ella el "recibo" de su espera, puntuando la visita como si hubiera esperado lo indecible.
- Test `paciencia_save_determinismo_test.gd` **5/5**. Suite total **410/410, exit 0**.

**AC-PS23, la prueba reina:** partida A (10 ticks → guardar → cargar en un mundo nuevo → 30 ticks) vs
partida B (40 ticks del tirón) → **misma secuencia exacta de abandonos**. Es la garantía de que meter
un sistema entero en el bucle de simulación no ha roto el determinismo del juego.

**Efecto colateral bueno:** el test de la 001 usaba una ficha de Demanda suelta como clave. Al exigir
ahora `servicio()` + turno, el test se alineó con el **contrato real** (una `PersonaFlujo`). Era una
laxitud que habría escondido problemas más adelante.
