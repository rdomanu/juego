# ADR-0001: Bus de eventos, tick de simulación y orden determinista

## Status
Accepted

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/modules/patterns.md`, `.../breaking-changes.md`, `.../deprecated-apis.md`, `.../current-best-practices.md`; verificación web 2026-07-22 (docs.godotengine.org — Idle and Physics Processing; GDQuest Event Bus singleton) |
| **Post-Cutoff APIs Used** | None (patrones estándar 4.x: autoload, `signal.emit()`, `.connect(Callable)`, `_physics_process`) |
| **Verification Required** | (1) el orden por prioridad es determinista en runtime; (2) `_physics_process` entrega `delta` fijo e independiente de los FPS de dibujado (confirmado en la doc oficial: delta estable ~0.016667); (3) el clamp anti-salto funciona tras alt-tab |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (es la base de la capa Foundation) |
| **Enables** | ADR-0002 (guardado/serialización — serializa el estado del tick/RNG y usa el mismo modelo de eventos), ADR-0004 (rejilla/navegación — la navegación corre en el tick de simulación) |
| **Blocks** | Prácticamente todos los epics de gameplay (Core/Feature/Presentation): sin bus ni tick no hay comunicación ni simulación |
| **Ordering Note** | Primer ADR a Aceptar. Debe estar `Accepted` antes de escribir cualquier código de sistema. |

## Context

### Problem Statement
Los 12 sistemas del MVP deben comunicarse sin acoplarse entre sí (un cambio en uno no debe obligar a
tocar los demás). Tres necesidades concretas lo fuerzan: (1) muchos eventos son de "aviso"
(`tramite_completado`, `abandono`, día/noche) y los escuchan varios sistemas lejanos en el árbol de
nodos; (2) unos pocos eventos (`nuevo_dia`, `nuevo_mes`) exigen que sus oyentes se ejecuten en un **orden
fijo** (Paciencia debe cerrar `sat` antes de que Economía lo cobre); (3) la simulación debe ser
**determinista** ("misma partida = mismo resultado", exigencia del proyecto) y compatible con la
navegación 2D de NPCs. Esta decisión es la base sobre la que se construye todo lo demás, así que hay que
tomarla primero.

### Constraints
- **Motor:** Godot 4.6. El orden de ejecución de los `connect` entre autoloads distintos **no está
  garantizado** (verificado en `patterns.md`) → un `signal.connect` suelto no basta para eventos ordenados.
- **Determinismo:** el proyecto exige reproducibilidad (coding-standards; AC de determinismo en todos los GDD).
- **Capas estrictas** (arquitectura §Principios): la Foundation no puede depender de Core/Feature.
- **Rendimiento:** objetivo 60 FPS / 16,6 ms; el hot path crítico es la navegación (no el bus).

### Requirements
- Comunicación cross-system desacoplada (bus) — TR-bus-001.
- Orden de handlers determinista para `nuevo_dia`/`nuevo_mes` — TR-bus-002.
- Un único reloj-fuente que dispara los eventos de tiempo una sola vez por cruce, en orden — TR-time-003/004.
- Simulación determinista alimentada por un `delta` estable, compatible con `NavigationAgent2D` — TR-time-001.

## Decision

Se adopta un **bus de eventos autoload** (`EventBus`) con **dos mecanismos de emisión** y un **bucle de
simulación de paso fijo**:

1. **Eventos de aviso (la mayoría)** → `signal` nativas del EventBus, emitidas con `signal.emit()` y
   escuchadas con `.connect(Callable)`. El orden entre oyentes es indiferente.

2. **Eventos ordenados (`nuevo_dia`, `nuevo_mes`)** → **registro con prioridad**. Cada sistema se registra
   con `EventBus.registrar_ordenado(evento, prioridad, callable)`; al disparar, el bus invoca los callables
   en orden de prioridad ascendente. **El bus no conoce los sistemas** (solo guarda una lista de callables
   ordenada) → respeta las capas. Órdenes fijados:
   - `nuevo_dia`: Paciencia (10, cierra `sat`) → Economía (20, cobra cierre) → Personal (30, ausencias) → Demanda (40, reset del día).
   - `nuevo_mes`: Economía (10, balance) → Paciencia (20, evalúa/resetea reclamaciones) → Demanda (30, perfil estacional).

3. **Tick de simulación** → toda la lógica de juego corre en `_physics_process` (paso fijo, 60 Hz por
   defecto). Tiempo calcula `delta_juego = delta_fijo × escala × mult` (0 en Pausa) y **empuja** el tick a
   los sistemas de simulación en orden fijo (Tiempo → Demanda → Flujo → Paciencia). El **dibujado** (UI,
   Feedback, cámara) corre en `_process` (tiempo real). Esto da determinismo (paso fijo) y es lo que
   `NavigationAgent2D` necesita.

### Architecture Diagram
```
  _physics_process (60 Hz FIJO)          EventBus (autoload, Foundation)
  ┌──────────────────────────┐           ┌───────────────────────────────────┐
  │ Tiempo -> delta_juego     │──emit───▶ │ signals nativas (aviso):          │
  │   | (empuja tick en orden)│           │   tramite_completado, abandono,   │
  │ Demanda -> Flujo -> Pacien.│          │   cambio_de_turno, persona_generada│
  └──────────────────────────┘           │                                   │
  _process (dibujo, variable)            │ registro con prioridad (ordenados):│
  ┌──────────────────────────┐           │   registrar_ordenado(ev, prio, cb) │
  │ UI/HUD · Feedback · cámara│◀──lee──── │   disparar_ordenado("nuevo_dia")   │
  └──────────────────────────┘           └───────────────────────────────────┘
        Foundation NO depende de los sistemas: el bus solo guarda callables.
```

### Key Interfaces
```gdscript
extends Node   # event_bus.gd — Autoload "EventBus"
# 1) Señales de aviso (orden indiferente)
signal tramite_completado(tramite_id: StringName, agente)
signal abandono(persona)
signal cambio_de_turno(turno: int)
signal cambio_dia_noche(es_de_noche: bool)
signal persona_generada(persona)
signal saldo_cambiado(nuevo_saldo: int)
signal reclamacion_generada(origen: StringName)
# 2) Eventos ordenados (registro con prioridad)
func registrar_ordenado(evento: StringName, prioridad: int, cb: Callable) -> void
func disparar_ordenado(evento: StringName) -> void   # invoca callables por prioridad ascendente
# Señales "notificacion" tras el orden critico (para no-criticos: UI/Feedback):
signal nuevo_dia
signal nuevo_mes
# Invariante: EventBus SOLO emite/retransmite; NUNCA contiene logica de juego ni llama a sistemas por nombre.
# Garantia: disparar_ordenado invoca en orden de prioridad estable y determinista.
```

## Alternatives Considered

### Alternative 1: Señales directas nodo→nodo, sin bus central
- **Description**: cada sistema mantiene referencias a los que le interesan y conecta señales directamente.
- **Pros**: sin indirección; fácil de rastrear en relaciones cercanas.
- **Cons**: acoplamiento fuerte entre sistemas lejanos; los nodos instanciados en runtime (las Personas de
  Flujo) no pueden conectarse fácilmente a sistemas globales; Feedback (que escucha a casi todos) se
  volvería un plato de espaguetis de referencias.
- **Rejection Reason**: rompe el desacople que exige un proyecto de 12 sistemas; contradice el principio de
  arquitectura nº3. *(Sí se usan señales directas para relaciones cercanas —un puesto y su agente—, pero no como mecanismo cross-system.)*

### Alternative 2: Orden vía orquestador en la escena raíz
- **Description**: un nodo `Main` conoce el orden y llama a los sistemas en secuencia para `nuevo_dia`.
- **Pros**: el orden se lee de un vistazo en un solo sitio; muy depurable.
- **Cons**: el orquestador acopla su código a todos los sistemas por nombre; añadir un sistema obliga a
  editar el orquestador; dos mecanismos distintos (orquestador para orden, bus para el resto).
- **Rejection Reason**: el registro con prioridad logra el mismo determinismo manteniendo **un solo
  mecanismo** (el bus) y sin que nadie tenga que conocer a los demás. Es más extensible.

### Alternative 3: Dispatcher hardcodeado dentro del EventBus (llama a los sistemas por nombre)
- **Description**: el EventBus, al recibir `nuevo_dia`, llama `Paciencia.cerrar_jornada()`, etc.
- **Pros**: simple de escribir.
- **Cons**: la Foundation (el bus) pasaría a **depender** de Core/Feature → **viola las capas estrictas**
  (principio nº4) y el propósito mismo de tener un bus (desacople).
- **Rejection Reason**: violación directa de un principio de arquitectura; se registra como patrón prohibido.

## Consequences

### Positive
- Los 12 sistemas se comunican sin conocerse → añadir/quitar un sistema no rompe a los demás.
- El orden crítico (`nuevo_dia`) es explícito, determinista y testeable, sin acoplar la Foundation.
- Un único mecanismo (el bus) para toda la comunicación cross-system → menos superficie que aprender.
- El paso fijo (`_physics_process`) da determinismo gratis y encaja con `NavigationAgent2D`.

### Negative
- **Descubribilidad:** con un bus, rastrear "quién escucha este evento" exige buscar en el código → se
  mitiga manteniendo la **lista central de señales documentada** en `event_bus.gd`.
- Los eventos ordenados necesitan que cada sistema recuerde **registrar su prioridad** (un paso más que un
  `connect` normal) → se documenta en el control-manifest.

### Risks
- **Riesgo:** un sistema olvida registrar su prioridad → su handler no corre en `nuevo_dia`.
  **Mitigación:** test de integración que verifica que los 4 handlers de `nuevo_dia` corren en orden.
- **Riesgo:** dos sistemas registran la misma prioridad → orden ambiguo.
  **Mitigación:** prioridades espaciadas (10/20/30/40) y documentadas; el bus rompe empates por orden de registro (determinista dentro de una misma partida).
- **Riesgo:** "signal spaghetti" si el bus se usa para todo. *(Advertencia confirmada por la comunidad Godot.)*
  **Mitigación:** regla en el manifest — el bus es solo para eventos cross-system; lo cercano va por señal directa.
- **Riesgo:** dependencias circulares entre autoloads cuelgan el arranque. *(Advertencia confirmada por la comunidad Godot.)*
  **Mitigación:** el EventBus no depende de ningún otro autoload; solo retransmite.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| time-system.md | Emitir eventos de cruce (turno, día/noche, nuevo_dia, nuevo_mes) una sola vez y en orden | El bus + `disparar_ordenado`; Tiempo es el origen |
| economy-budget.md | Cobrar al `nuevo_dia` usando el `sat_cierre` que Paciencia acaba de congelar | Prioridad: Paciencia (10) antes que Economía (20) |
| patience-satisfaction.md | Cerrar `sat` de la jornada al `nuevo_dia` antes de que se cobre | Prioridad 10 en `nuevo_dia` |
| flow-queues.md | Emitir `tramite_completado`/`abandono`; simular con `delta` en paso fijo | Señales de aviso + tick en `_physics_process` |
| feedback-juice.md | FB1: escuchar un bus de eventos (read-only) para el vocabulario evento→respuesta | El EventBus es ese bus |
| demand-generation.md | Generar Personas por acumulador de `delta`; determinismo | Tick de simulación de paso fijo |
| staff-agents.md | Ausencias evaluadas al `nuevo_dia` (deterministas) | Prioridad 30 en `nuevo_dia` |

## Performance Implications
- **CPU**: `disparar_ordenado` corre 1×/jornada (`nuevo_dia`) → coste trivial. Las señales de aviso frecuentes usan `emit` nativo (barato). El tick de simulación corre 60×/s; su coste dominante es la navegación (ver QQ-02), no el bus.
- **Memory**: despreciable (unas listas de `Callable`).
- **Load Time**: nulo (autoload ligero).
- **Network**: N/A (single-player).

## Migration Plan
N/A — proyecto nuevo, aún sin código. Este ADR define el patrón desde cero.

## Validation Criteria
- Test de integración: al `nuevo_dia`, los handlers corren en orden 10→20→30→40 (Paciencia→Economía→Personal→Demanda).
- Test de determinismo: la misma secuencia de `delta` desde idéntico estado produce el mismo resultado (sin depender del reloj real).
- Verificar en runtime que `_physics_process` entrega un `delta` fijo aunque los FPS de dibujado varíen.

## Related Decisions
- **ADR-0002** (guardado/serialización) — serializa el estado del tick y del RNG; reutiliza el patrón de eventos.
- **ADR-0004** (rejilla + navegación 2D) — la navegación corre dentro de este tick de simulación.
- `docs/architecture/architecture.md` §Flujo de datos (D1, D2) y §Principios.
