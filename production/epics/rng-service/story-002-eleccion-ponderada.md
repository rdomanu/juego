# Story 002: Elección ponderada (`elegir_ponderado`)

> **Epic**: RNGService
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija `/dev-story` al empezar)

## Context

**GDD**: `docs/architecture/architecture.md` §API Boundaries → RNGService — *módulo de infraestructura sin GDD*
**Requirement**: base de `TR-demand-002` (RNG sembrado determinista, **mezcla ponderada, normalización
defensiva**). También la usa Personal (mercado, F5). El requisito vive en su epic; aquí se provee el mecanismo.

**ADR Governing Implementation**: ADR-0002: Guardado/serialización + RNG determinista
**ADR Decision Summary**: toda la aleatoriedad de juego pasa por el `RNGService` sembrado; incluye la
elección ponderada que Demanda usa para decidir el tipo de cada visita.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: solo aritmética + `randf()` del RNG sembrado; sin APIs de motor post-cutoff.

**Control Manifest Rules (Foundation / Core)**:
- Required: Demanda/Personal obtienen su aleatoriedad ponderada vía `RNGService.elegir_ponderado(...)`.
- Forbidden: nunca `randi()`/`randf()` global; nunca normalizar "por fuera" con otra fuente de azar.
- Cross-cutting: tipado estático; determinismo.

---

## Acceptance Criteria

*Derivados del contrato de arquitectura (`elegir_ponderado`) y de TR-demand-002 (normalización defensiva):*

- [ ] `elegir_ponderado(pesos: Array[float]) -> int` devuelve un **índice válido** en [0, `pesos.size()`-1].
- [ ] La probabilidad de cada índice es **proporcional a su peso** (usa la **suma real** de los pesos →
      **normalización defensiva**: no exige que sumen 1).
- [ ] Un índice con **peso 0 nunca se elige**.
- [ ] **Determinista**: misma semilla + mismos pesos → misma secuencia de elecciones (usa el RNG sembrado).
- [ ] **Edge definido**: lista vacía o suma de pesos ≤ 0 → devuelve **-1** (sin elección válida) con
      `push_warning`; pesos negativos se tratan como 0 (defensivo).

---

## Implementation Notes

*Derivadas de ADR-0002 + patrón determinista sembrado (Demanda F4):*

```gdscript
func elegir_ponderado(pesos: Array[float]) -> int:
    var total: float = 0.0
    for p in pesos:
        if p > 0.0:
            total += p
    if total <= 0.0:
        push_warning("elegir_ponderado: sin pesos positivos -> -1")
        return -1
    var r: float = randf() * total        # usa el MISMO RNG sembrado (Story 001)
    var acumulado: float = 0.0
    for i in pesos.size():
        var p: float = pesos[i]
        if p <= 0.0:
            continue
        acumulado += p
        if r < acumulado:
            return i
    return pesos.size() - 1                # salvaguarda por errores de coma flotante
```

- Reutiliza `randf()` de la Story 001 → una sola fuente de azar (determinismo).
- La salvaguarda final (`return size-1`) cubre el caso en que `r` roce el total por redondeo.

---

## Out of Scope

- **Story 001**: el autoload y los envoltorios `sembrar`/`randi_rango`/`randf`.
- **Story 003**: serialización del estado del RNG.
- **Epic Demanda**: la mezcla concreta de 13 tipos y su normalización a partir del catálogo (aquí solo el
  mecanismo genérico de elección ponderada).

---

## QA Test Cases

*Escritos por el hilo principal (QA Lead omitido en LEAN). Casos deterministas (evitar tests de distribución
estadística, que serían flaky): usar pesos degenerados + determinismo.*

- **AC-1 (peso único)**: `elegir_ponderado([0.0, 0.0, 1.0])` devuelve **siempre 2** (con cualquier semilla).
  - Given: `sembrar(1)` (y repetir con `sembrar(999)`).
  - When: 50 llamadas con esos pesos.
  - Then: todas devuelven 2.
- **AC-2 (peso 0 nunca se elige)**: con `[1.0, 0.0, 1.0]`, ninguna elección es 1.
  - Given: `sembrar(42)`.
  - When: 200 llamadas.
  - Then: todos los resultados ∈ {0, 2}.
- **AC-3 (normalización defensiva)**: pesos que no suman 1 se aceptan; `[0.0, 5.0]` → siempre 1.
  - Given: `sembrar(3)`.
  - When: 50 llamadas.
  - Then: todas devuelven 1 (la suma real 5.0 se usa como total).
- **AC-4 (determinismo)**: misma semilla + mismos pesos → misma secuencia.
  - Given: dos instancias sembradas con 777; pesos `[1.0, 1.0, 1.0]`.
  - When: 20 elecciones en cada una.
  - Then: las dos secuencias de índices coinciden exactamente.
- **AC-5 (edge)**: `elegir_ponderado([])` y `elegir_ponderado([0.0, 0.0])` devuelven **-1**.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_service/rng_service_ponderada_test.gd` — debe existir y pasar (degenerados +
  peso 0 + normalización + determinismo + edge -1).

**Status**: [x] **Creado y PASA** — `tests/unit/rng_service/rng_service_ponderada_test.gd`, 5/5 test cases,
0 fallos, GdUnit4 headless (2026-07-22). Suite total del proyecto: 19/19, exit 0.

**Implementación:** `elegir_ponderado` añadido a `rng_service.gd`.
**🐛 Bug capturado por el test (determinismo):** dentro de la función, `randf()` sin cualificar resolvía a la
**función GLOBAL** de Godot (`@GlobalScope.randf()`, RNG sin sembrar) en vez del método sembrado → a≠b.
Arreglado con `self.randf()`. Lección: un método del autoload con el mismo nombre que una utilidad global
(`randf`/`randi`) es un footgun; cualificar las llamadas internas. Falta el cierre formal con `/story-done`.

---

## Dependencies

- Depends on: **Story 001** (usa `randf()` y el generador sembrado).
- Unlocks: la mezcla ponderada de **Demanda** (13 tipos) y el mercado de **Personal**.
