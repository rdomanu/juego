# Story 003: Validación en carga del catálogo

> **Epic**: Datos y Configuración
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `design/gdd/data-config.md` (R3 integridad, R5 solvencia, Edge Cases, AC-D06–D13/D20)
**Requirement**: `TR-data-003` (validación en carga: integridad referencial, ids únicos, clamp, invariante R5)

**ADR Governing Implementation**: ADR-0003: Formato del catálogo (.tres Resource)
**ADR Decision Summary**: al cargar, Datos **valida** (referencias colgantes, ids duplicados, clamp de rangos,
R5 → *warning*). **Modo desarrollo = fallo ruidoso; modo jugador = degradación segura + log.**

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pura lógica sobre los diccionarios indexados (Story 002). Sin APIs de motor.

**Control Manifest Rules (Foundation)**:
- Required: Datos **valida en carga** (refs colgantes, ids únicos, clamp de rangos, invariante R5 → warning);
  `Datos.obtener(...)` read-only.
- Cross-cutting: determinismo (la validación no usa azar); tipado estático.

---

## Acceptance Criteria

*De GDD R3/R5, Edge Cases y AC-D06–D13 / D20a–d:*

- [x] `validar() -> Array[String]` devuelve `[]` si el catálogo está OK, o una lista de mensajes
      (errores/warnings) describiendo cada problema.
- [x] **Integridad referencial (AC-D06/D20a)**: una referencia por `id` colgante en `atenciones_admitidas`,
      `puestos_admitidos` o `puestos_operables` se **reporta** señalando el `id` inexistente.
- [x] **Ids únicos (AC-D07/D20b)**: un `id` duplicado dentro de un tipo se **reporta**.
- [x] **Clamp de rangos (AC-D09/D10/D11/D20c)**: `duracion_min ≤ 0` → clampa a **1**; `€`/`aforo`/`coste`
      negativos → **0**; `retorno_dgp` fuera de `[0,1]` → clampa a `[0,1]`; siempre con **aviso**.
- [x] **Invariante R5 (AC-D12/D13/D20d)**: dada una **estimación de demanda máxima `D`** (entrada), se avisa
      **sii** `capacidad_max_ODAC(Escenario) < D`; es un **WARNING de diseño** que **no aborta** la carga.
- [x] **Servicio inoperable (AC-D20d)**: un `servicio_activo` del Escenario sin ningún `TipoPuesto` que lo
      atienda emite **WARNING**.
- [x] **Modo dev vs jugador**: en desarrollo un error de integridad **falla ruidoso** (aborta); en modo
      jugador **degrada con log** (descarta la referencia inválida, gana el primer `id` duplicado, etc.).

---

## Implementation Notes

- La validación corre desde `Datos._ready` (tras indexar, Story 002) y/o expuesta como `validar()`.
- Integridad: por cada lista de ids, comprobar que cada `id` existe en el índice del tipo destino.
- Clamp: recorrer definiciones y ajustar campos numéricos fuera de rango (registrar el aviso).
- **R5**: `capacidad_max_ODAC ≈ tope_construible[ODAC] × (minutos_operativos / duracion_media_odac)`
  (GDD F8: ~4 × 32 ≈ 128/día). La **estimación de `D`** entra como parámetro (la fórmula real de demanda la
  posee Demanda) → `validar(demanda_max_odac := 0)` o similar; con `D` = 30–60 (estimación actual), pasa.
- Un flag `modo_desarrollo` (o `OS.is_debug_build()`) decide ruidoso vs degradación.

## Out of Scope

- **Story 001/002/004**: esquema, carga/lookup, contenido.
- **AC-D14/D15** (rechazar reconfiguración fuera de lo admitido): comportamiento de **ODAC/Flujo** (leen el
  dato `atenciones_admitidas`/`reconfigurable`); Datos solo lo declara.
- **AC-D19** (save con `id` huérfano): **SaveManager epic** (tolerancia al cargar partida).

## QA Test Cases

*Logic — cada regla con un catálogo-fixture mínimo. Determinista.*

- **AC-1 (AC-D06)**: catálogo con `TipoPuesto.atenciones_admitidas=[&"no_existe"]` → `validar()` incluye un
  mensaje que menciona `no_existe`.
- **AC-2 (AC-D07)**: dos `TramiteDoc` con `id=&"dni"` → `validar()` reporta id duplicado.
- **AC-3 (AC-D09)**: `TramiteDoc.duracion_min=0` → tras validar, queda **1** y hay aviso.
- **AC-4 (AC-D10)**: `Costes.retorno_dgp_min=-0.2`, `retorno_dgp_max=1.5` → quedan **0.0** y **1.0** con aviso.
- **AC-5 (AC-D11)**: `coste_construccion_eur=-100` → queda **0** con aviso.
- **AC-6 (AC-D13, R5)**: un `Escenario` con `capacidad_max_ODAC < D` → `validar()` emite WARNING nombrando el
  escenario, **sin abortar** (devuelve la lista, no rompe).
- **AC-7 (limpio)**: un catálogo-fixture correcto → `validar()` devuelve `[]`.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/datos/datos_validacion_test.gd` — debe existir y pasar.

**Status**: [x] Creado y PASA (datos_validacion_test.gd 9/9; suite del proyecto 47/47, 2026-07-22)

## Dependencies

- Depends on: **Story 001** (clases) + **Story 002** (índice por id).
- Unlocks: Story 004 (el catálogo real debe validar limpio) y la confianza en todo el catálogo.

## Cierre (2026-07-22)

Implementada vía subagente godot-gdscript-specialist (Opus) con arquitectura aprobada por el orquestador;
code review independiente (Opus): APROBADO CON OBSERVACIONES, 0 bloqueantes. Suite 47/47, exit 0
(re-verificada en el hilo principal); el catálogo real valida limpio. Commit 143b2ca.
Las 2 observaciones de más valor del review se resolvieron ANTES del cierre: test de la rama
`modo_desarrollo=true` (reporta sin degradar) y test del caso negativo de R5 (capacidad suficiente → no
avisa). Backlog menor anotado (no bloqueante):
- El clamp cubre exactamente los campos del AC; `plazas_agente`/`superficie` sin clamp (dentro de spec).
- R5 usa media SIMPLE de duraciones (aproximación documentada; la fórmula ponderada la posee Demanda).
- La capacidad R5 se calcula una vez y se comparte entre escenarios (MVP = 1 escenario; deuda conocida).
- Los clamps mutan el catálogo también en modo dev (por diseño, documentado como única mutación en carga).
- Asserts `_contiene` por subcadena (aceptable con fixtures aislados).
