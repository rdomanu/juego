# Architecture Review Report

- **Date:** 2026-07-22
- **Engine:** Godot 4.6 + GDScript · 2D top-down
- **GDDs Reviewed:** 12 (vía el Technical Requirements Baseline de `architecture.md`, destilado de los 12 GDD y verificado por 13× `/consistency-check` + `/review-all-gdds` + `/gate-check`)
- **ADRs Reviewed:** 4 (ADR-0001…0004)
- **Mode:** LEAN — hilo principal (subagentes caídos por "1M context"), lentes de *technical-director* y *godot-specialist* aplicadas manualmente. Módulos de motor verificados: `patterns.md`, `save-load.md`, `tilemap-2d.md`, `navigation.md`, `deprecated-apis.md`, `breaking-changes.md`.

---

## Traceability Summary

- **Total requirements:** 56 (baseline de `architecture.md`, ahora con IDs estables en `tr-registry.yaml`)
- ✅ **Covered:** 56
- ⚠️ **Partial:** 0
- ❌ **Gaps:** 0

**Cobertura: 100 %.** Cada requisito técnico tiene una ruta: un ADR lo gobierna, o ya está especificado en su GDD (se implementa en stories), o es la incógnita de rendimiento QQ-02 (spike en el vertical slice, no un ADR).

### Cobertura por destino

| Destino | # TR | TR-IDs |
|---------|------|--------|
| **ADR-0001** (bus + tick + orden) | 15 | TR-bus-001/002, TR-time-001/003/004/005/006, TR-flow-004, TR-economy-001/002, TR-demand-001, TR-patience-002/003, TR-odac-002, TR-feedback-001 |
| **ADR-0002** (guardado + RNG) | 13 | TR-save-001/002/003, TR-time-008, TR-data-006, TR-flow-006, TR-staff-001*/003*, TR-construction-004, TR-patience-004, TR-demand-002, TR-ui-005 |
| **ADR-0003** (formato catálogo `.tres`) | 6 | TR-data-001/002/003/004/005, TR-doc-002† |
| **ADR-0004** (rejilla + navegación 2D) | 4 | TR-construction-001/002/003, TR-flow-005 |
| **Diseño de sistema** (GDD → stories, sin ADR) | 15 | TR-time-002/007, TR-economy-003/004, TR-flow-001/002/003, TR-demand-003, TR-staff-002, TR-doc-001, TR-odac-001, TR-patience-001, TR-ui-001/002/003/004, TR-feedback-002 |
| **Spike de rendimiento** (QQ-02, sin ADR) | 3 | TR-time-009, TR-flow-005‡, TR-feedback-003 |

\* Los TR de Personal reparten cobertura: la parte de **serialización + RNG** la cubre ADR-0002; la parte de **lógica** (asignación, gate) es diseño de sistema.
† TR-doc-002 (eventos estacionales que amplían el catálogo) toca el catálogo (ADR-0003) y el bus (ADR-0001); su lógica es diseño de sistema.
‡ TR-flow-005 aparece en dos destinos: la **API** de navegación la fija ADR-0004; el **presupuesto de 60 FPS con docenas de NPCs** es el spike QQ-02.

### Coverage Gaps

**Ninguno.** No hay requisitos sin ruta arquitectónica.

---

## Cross-ADR Conflicts

**Ninguno bloqueante.** Los 4 ADRs cubren dominios disjuntos (comunicación / persistencia / datos / rejilla-navegación) y encajan entre sí.

- **Propiedad de datos:** sin solapes. Los ADRs Foundation no reclaman estado de juego (ese lo poseen los sistemas Core/Feature, definido en sus GDD); `state_ownership` del registro está vacío por diseño.
- **Contratos de integración:** coherentes. ADR-0002 (carga) asume el catálogo cargado (ADR-0003) y el arranque en Pausa + `RNGService` (ADR-0001); ambas dependencias quedan ahora explícitas.
- **Presupuesto de rendimiento:** ningún ADR reclama un presupuesto de ms concreto → sin conflicto de suma. El único hot path (navegación) se valida en QQ-02.
- **Patrón:** `event_bus` para cross-system (ADR-0001) y `direct_call` vía grupo `Persist` (ADR-0002) son mecanismos para propósitos distintos, coherentes con los `forbidden_patterns`.

### Known conflict-prone areas (de `consistency-failures.md`)

Los 2 conflictos históricos son de **diseño** (propagación de valores dentro de un GDD: throughput ODAC; identificadores retirados en ODAC), ambos **Resueltos**. **Ninguno es de arquitectura.** Lección aplicable: al propagar un cambio de valor/ID, hacer grep del valor **viejo** en todas las secciones del GDD, no solo donde se define.

---

## ADR Dependency Order

Grafo de dependencias (`Depends On`), sin ciclos:

```
Foundation (sin dependencias):
  1. ADR-0001  Bus de eventos, tick y orden determinista
  2. ADR-0003  Formato del catálogo (.tres)

Dependen de la Foundation:
  3. ADR-0002  Guardado + RNG        (requiere ADR-0001 + ADR-0003)
  4. ADR-0004  Rejilla + navegación  (requiere ADR-0001)
```

- **Ciclos:** ninguno.
- **Dependencias no resueltas:** ninguna — los 4 ADRs quedan `Accepted` en esta sesión (2026-07-22), respetando el orden del grafo (0001/0003 antes que 0002/0004).
- **Corrección aplicada:** ADR-0002 ahora lista ADR-0003 en `Depends On` (su `load_state` requiere el catálogo cargado). Antes solo listaba ADR-0001.

---

## GDD Revision Flags (Architecture → Design)

**Ninguna.** Todos los cambios HIGH-risk de Godot 4.6 son de **3D** (Jolt, IK, glow 3D, tonemapping) y no afectan a este proyecto 2D. Los dominios 2D usados están verificados y los GDD ya se redactaron con el conocimiento correcto (p. ej. glow 2D real descartado → mood con CanvasModulate+Light2D). Sin asunciones de diseño que contradigan la realidad del motor.

---

## Engine Compatibility Issues

**Ninguno.** Engine consistente en los 4 ADRs (todos Godot 4.6). ADRs con sección *Engine Compatibility*: 4 / 4.

| ADR | API post-cutoff usada | Verificación | Estado |
|-----|----------------------|--------------|--------|
| 0001 | (ninguna — patrones estándar 4.x: autoload, `signal.emit()`, `.connect(Callable)`, `_physics_process`) | `patterns.md` | ✅ |
| 0002 | `FileAccess.store_*` → `bool` (4.4); `JSON.stringify`/`parse` | `save-load.md`, `breaking-changes.md` | ✅ |
| 0003 | evita `duplicate_deep` (4.5) referenciando por `id`; `class_name`/`@export` | `save-load.md`, `deprecated-apis.md` | ✅ |
| 0004 | `TileMapLayer` (no `TileMap`); `NavigationServer2D` (4.5); `NavigationAgent2D` avoidance **OFF** (Experimental 4.6) | `tilemap-2d.md`, `navigation.md` | ✅ |

- **Deprecated APIs:** ningún ADR usa API deprecada. Los sustitutos correctos están en uso (TileMapLayer, NavigationServer2D, `.connect(Callable)`).
- **Conflictos post-cutoff entre ADRs:** ninguno (dominios de API distintos).

### Engine Specialist Findings (lente *godot-specialist* manual)

1. **ADR-0004 — patrón de movimiento correcto.** El bucle `velocity = direction * vel; move_and_slide()` **sin** `velocity_computed` coincide con `navigation.md` (NavigationAgent2D sin avoidance). Usar `velocity_computed` **solo** si se activara el avoidance (que está OFF). ✅
2. **ADR-0004 — instanciación:** las `PackedScene` de puestos/objetos deben crearse con **`instantiate()`** (no `instance()`, deprecado en 4.0). → **nota para el control-manifest** (no cambia el ADR).
3. **ADR-0001 — tick fijo:** `_physics_process` entrega `delta` estable (~0.016667 a 60 Hz) independiente de los FPS de dibujo; la tasa se controla con `Engine.physics_ticks_per_second` (default 60, el asumido). ✅
4. Sin otros anti-patrones de Godot en los ADRs.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` v1.0 validado:

- **Sistemas en capas:** los 12 del MVP aparecen en el mapa de capas (Presentation/Feature/Core/Foundation). Los 15 sistemas post-MVP del índice no pertenecen al alcance MVP → correctamente ausentes.
- **Data flow:** cubre la comunicación cross-system (§3: bucle de simulación, bus + orden de handlers, save/load, orden de init).
- **API boundaries:** 7 contratos tipados soportan la integración de todos los sistemas.
- **Arquitectura huérfana:** `EventBus`/`SaveManager`/`RNGService` son módulos de infraestructura declarados explícitamente como "sin GDD porque son técnicos" → no son huérfanos.

---

## Verdict: ✅ PASS

Cobertura 100 % (56/56), cero conflictos cross-ADR, motor consistente, sin banderas de revisión de GDD. Las 2 observaciones menores detectadas eran de precisión de metadatos (no huecos de diseño) y **se corrigieron en esta sesión**:

1. **(aplicada)** ADR-0002 → añadido ADR-0003 a `Depends On`.
2. **(aplicada)** `architecture.md` → corregida la referencia inexistente `TR-patience-008` a `TR-patience-003/004`.

**Los 4 ADRs quedan `Accepted` (2026-07-22).**

### Blocking Issues

Ninguno.

### Nota para el control-manifest (no bloqueante)

- Instanciar `PackedScene` con `instantiate()` (no `instance()`).
- Recordar el *gotcha* de navegación: fijar `target_position` tras `await get_tree().physics_frame`; re-bake de la `NavigationPolygon` solo al cambiar el layout.

---

## Pre-Gate Checklist (comprobado 2026-07-22)

| Artefacto | Estado | Lo crea |
|-----------|--------|---------|
| `tests/unit/` + `tests/integration/` | ❌ | `/test-setup` |
| CI (`.github/workflows/tests.yml`) | ❌ | `/test-setup` |
| `design/ux/interaction-patterns.md` | ❌ | `/ux-design` |
| `design/accessibility-requirements.md` | ❌ | `/ux-design` |

## Immediate Actions (orden hasta el gate pre-production)

1. `/create-control-manifest` — hoja de reglas para programar (extrae Required/Forbidden/Guardrails de los 4 ADRs Accepted + libro de normas).
2. `/test-setup` — `tests/` + GdUnit4 + CI.
3. `/ux-design` — `interaction-patterns.md` + `accessibility-requirements.md`.
4. `/gate-check pre-production` → Pre-Production → `/vertical-slice` (1er build jugable; ahí corre el spike QQ-02).

**Rerun trigger:** re-ejecutar `/architecture-review` si se escribe un ADR nuevo o se revisa un GDD, para verificar que la cobertura sigue en 100 %.
