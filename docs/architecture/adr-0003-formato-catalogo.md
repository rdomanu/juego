# ADR-0003: Formato del catálogo de datos del desarrollador (.tres Resource)

## Status
Accepted

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Datos / contenido estático) |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/modules/save-load.md`; `design/gdd/data-config.md`; verificación web 2026-07-22 (Godot Custom Resources; "Data-driven: JSON or custom resources?"; comparativa JSON/ConfigFile/Resources) |
| **Post-Cutoff APIs Used** | `duplicate_deep()` (4.5) — solo si se copian Resources anidados (evitado por diseño); `class_name`/`@export` (4.x estable) |
| **Verification Required** | (1) `load()`/`preload()` del catálogo funciona; (2) la validación en carga detecta referencias colgantes/ids duplicados/violación de R5 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | El sistema de Datos #2 (esquema + validación en carga) y todos los sistemas que leen el catálogo |
| **Blocks** | El epic de Datos y cualquier sistema que resuelva definiciones por `id` |
| **Ordering Note** | Foundation. Aceptar antes de codificar Datos. ADR-0002 depende de que el catálogo esté cargado antes de `load_state`. |

## Context

### Problem Statement
El **catálogo de definiciones** —contenido **fijo del desarrollador**: 3 trámites, 13 denuncias, tipos de
puesto/sala/agente, costes y el escenario de Pozuelo— necesita un **formato de almacenamiento** y un
mecanismo de **carga + validación**. Es distinto del save de partida (ADR-0002, JSON): el catálogo no lo
edita el jugador, va empaquetado en el juego.

### Constraints
- El catálogo vive en `res://` (empaquetado, de solo lectura al exportar) → el jugador no lo modifica →
  **el riesgo de seguridad de `.tres` no aplica** aquí.
- **Datos R1:** una definición es una plantilla **read-only**; las instancias las poseen otros sistemas y
  la referencian por `id`.
- **Datos R3:** integridad referencial (todo `id` referenciado existe) e `id` únicos por tipo.
- **Datos R5:** invariante de solvencia por escenario (validado en carga → *warning* no bloqueante).
- **4.5:** copiar Resources **anidados** requiere `duplicate_deep()` (y hubo issues) → conviene **evitar anidar**.
- `entities.yaml` sigue siendo el **registro de diseño** (fuente de verdad para `/consistency-check`),
  distinto del catálogo que carga el juego.

### Requirements
- Definiciones **tipadas**, creables/editables en el editor — Datos R0/R2.
- Carga con `load()`/`preload()`; **validación en carga** (R3, clamp de rangos, R5) — Datos R3/R5.
- **Lookup por `id`** en runtime — TR-data-004.
- Tolerar catálogos que evolucionan entre versiones de save (coordinado con ADR-0002) — TR-data-006.

## Decision

**El catálogo se implementa como Custom Resources (`.tres`, texto) con clases tipadas; las definiciones se
referencian entre sí por `id` (StringName), nunca anidando Resources.**

1. **Clases tipadas** (`class_name` + `@export`), con la jerarquía del GDD (Datos R2):
   `Atencion` (base) → `TramiteDoc` / `DenunciaODAC`; más `TipoPuesto`, `TipoSala`, `TipoAgente`,
   `Costes`, `Escenario`.
2. **Un `.tres` por definición**, organizados en carpetas (`res://datos/tramites/`, `/denuncias/`,
   `/puestos/`, `/salas/`, `/agentes/`, `/escenarios/`).
3. **Referencias por `id`** (`StringName`), **no** por Resource anidado. Ej.:
   `TipoPuesto.atenciones_admitidas: Array[StringName]` = lista de ids, no de Resources. Esto permite
   validar integridad (R3), tolerar catálogos que cambian, y **evita el problema de Resources anidados**
   (`duplicate_deep` 4.5).
4. **Carga + validación** (parte de Datos #2): al arrancar, se cargan los `.tres`, se **indexan por `id`**
   en diccionarios, y se **valida** (referencias colgantes, ids duplicados, clamp de rangos, R5 → warning).
   Modo desarrollo = fallo ruidoso; modo jugador = degradación segura + log.
5. **Lookup:** `Datos.obtener(tipo, id)` devuelve la definición (**read-only**; los sistemas nunca la
   mutan → las instancias de partida son objetos aparte, Datos R1).
6. `entities.yaml` (registro de diseño) y el catálogo `.tres` (runtime) se mantienen **coherentes**;
   `/consistency-check` vigila el diseño, el catálogo es la implementación.

### Architecture Diagram
```
  res://datos/                          Datos #2 (carga + valida al arrancar)
   |- tramites/dni.tres  ──load()──▶       indexa por id -> { "dni": TramiteDoc, ... }
   |- denuncias/viogen.tres                valida: refs por id, ids unicos, clamp, R5(warning)
   |- puestos/puesto_odac.tres                     |
   |- escenarios/pozuelo.tres                      v
                                         Datos.obtener("TramiteDoc","dni") -> Resource (read-only)
   (referencias por id, NO Resources anidados)    los sistemas crean sus INSTANCIAS aparte (R1)
```

### Key Interfaces
```gdscript
class_name Atencion extends Resource
@export var id: StringName
@export var nombre: String
@export_enum("Documentacion","ODAC") var servicio: String
@export var duracion_min: int
@export var tipo_puesto: StringName
@export var icono: Texture2D

class_name TramiteDoc extends Atencion
@export var tarifa_eur: int
@export var requiere_cita: bool

class_name DenunciaODAC extends Atencion
@export_enum("Normal","Prioritaria") var prioridad: String
@export var admite_cita: bool

# Datos: lookup + validacion (referencias por id)
func obtener(tipo: StringName, id: StringName) -> Resource
func obtener_todos(tipo: StringName) -> Array
func validar() -> Array[String]      # [] si OK; lista de warnings/errores si no
# Invariante caller: nunca mutar lo devuelto (plantilla compartida).
# Garantia: todo id referenciado existe (validado en carga).
```

## Alternatives Considered

### Alternative 1: JSON en `res://`
- **Description**: el catálogo como archivos JSON de texto.
- **Pros**: editable fuera de Godot; transparente; fácil de generar por herramientas externas (útil para el
  "menú admin de tuning" futuro, #26).
- **Cons**: hay que **parsear** y **validar tipos a mano**; sin editor visual; una errata de sintaxis
  (coma/comilla) rompe la carga; más código.
- **Rejection Reason**: para catálogos tipados con herencia (`Atencion`→…), los Resources son la práctica
  recomendada y menos frágiles; el editor visual es más seguro para un equipo que aprende. *(El save de
  partida sí es JSON — ADR-0002 — porque ahí manda la seguridad y la legibilidad, no el tipado.)*

### Alternative 2: CSV / ConfigFile
- **Description**: tablas planas o pares clave-valor.
- **Pros**: muy simple para datos tabulares o localización.
- **Cons**: no modela bien la herencia (`Atencion`→`TramiteDoc`/`DenunciaODAC`) ni campos ricos (listas de ids).
- **Rejection Reason**: no encaja con la estructura del catálogo. *(CSV sí puede servir luego para i18n.)*

## Consequences

### Positive
- **Editor visual** (Inspector) → crear/editar fichas rellenando formularios, sin sintaxis frágil.
- **Tipado** → autocompletado y menos bugs; Godot valida tipos en el editor.
- **Sin parsear** → Godot carga los Resources directamente (más rápido y menos código que JSON).
- **Seguro** (contenido del desarrollador en `res://`) e idiomático (práctica recomendada verificada).

### Negative
- Formato propietario de Godot (menos editable fuera del editor; aun así es texto versionable en git).
- El "menú admin de tuning" futuro (#26, Full Vision) sería algo más de trabajo con `.tres` que con JSON — aceptable, es una fase lejana.
- Hay que mantener `entities.yaml` (diseño) y el catálogo `.tres` (runtime) coherentes (proceso).

### Risks
- **Riesgo:** referenciar Resources **anidados** dispararía el problema de `duplicate_deep` (4.5).
  **Mitigación:** referenciar **por `id`** (string), nunca anidar Resources (decisión 3).
- **Riesgo:** divergencia entre `entities.yaml` y el catálogo `.tres`.
  **Mitigación:** `/consistency-check` vigila el diseño; transcripción cuidada de los valores semilla.
- **Riesgo (teórico):** un `.tres` puede embeber un script.
  **Mitigación:** los `.tres` del catálogo son nuestros y no embeben scripts; no se cargan `.tres` de fuentes externas (eso es el save, y va en JSON — ADR-0002).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config.md | R0 data-driven; R2 jerarquía de tipos; R3 integridad referencial; R5 invariante | Clases tipadas + validación en carga; referencias por `id` |
| economy-budget.md | Leer `tarifa_eur`, costes, salarios, `retorno_dgp` por `id` | `Datos.obtener(...)` read-only |
| flow-queues.md | Leer `duracion_min`, `tipo_puesto`, `atenciones_admitidas` | Lookup por `id`; `atenciones_admitidas` = `Array[StringName]` |
| odac.md | Leer las 13 denuncias con `prioridad`, `reconfigurable` | `DenunciaODAC` tipada |
| construction-layout.md | Leer `TipoPuesto`/`TipoSala` (coste, superficie), `Escenario` | Resources tipados |

## Performance Implications
- **CPU**: carga en el arranque (puntual); los Resources **no se parsean** (ventaja sobre JSON).
- **Memory**: el catálogo completo en memoria (pequeño en el MVP).
- **Load Time**: trivial (pocos archivos).
- **Network**: N/A.

## Migration Plan
N/A — proyecto nuevo. Transcribir los valores semilla de `data-config.md` (F1–F7) y `entities.yaml` a los `.tres`.

## Validation Criteria
- Cargar el catálogo MVP **sin** referencias colgantes ni `id` duplicados (Datos AC-D20a/b).
- Editar un valor en un `.tres` (sin tocar código) y verlo reflejado en el juego (Datos AC-D02).
- Un `Escenario` que viola R5 emite **warning** sin abortar la carga (Datos AC-D13).
- Toda referencia por `id` resuelve a una definición existente.

## Related Decisions
- **ADR-0002** — el **save de partida** va en JSON (distinto del catálogo); coordina la tolerancia a `id` huérfano.
- `design/gdd/data-config.md` — el GDD que este ADR implementa.
- `docs/architecture/architecture.md` §Propiedad de módulos (Datos) y §Open Questions (QQ-01, ahora resuelta).
