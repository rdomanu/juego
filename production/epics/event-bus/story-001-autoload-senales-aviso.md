# Story 001: EventBus autoload + señales de aviso cross-system

> **Epic**: EventBus
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `docs/architecture/architecture.md` §3.2 (Bus de eventos) — *módulo de infraestructura sin GDD propio*
**Requirement**: `TR-bus-001`
*(Texto del requisito en `docs/architecture/tr-registry.yaml` — leer fresco al revisar.)*

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick de simulación y orden determinista
**ADR Decision Summary**: se adopta un **bus de eventos autoload** (`EventBus`) para la comunicación
cross-system desacoplada: `signal.emit()` para emitir, `.connect(Callable)` para escuchar. El bus **solo
retransmite**; nunca contiene lógica de juego ni llama a los sistemas por nombre.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: patrones estándar 4.x (autoload + `signal.emit()` + `.connect(Callable)`); sin APIs
post-cutoff. Verificado en `modules/patterns.md` + doc oficial (Event Bus singleton). Usar la sintaxis de
señal moderna: `signal.connect(callable)`, **nunca** `connect("sig", obj, "metodo")` (deprecada).

**Control Manifest Rules (Foundation)**:
- Required: comunicación cross-system vía `EventBus` autoload; la **lista central de señales** vive
  documentada en `event_bus.gd`. Orden de autoloads: `EventBus → RNGService → Datos → Tiempo → SaveManager`
  (EventBus el primero).
- Forbidden: la Foundation **nunca** llama a los sistemas por nombre; **nunca** usar el bus para TODO
  ("signal spaghetti") — lo cercano (un puesto y su agente) va por señal directa nodo→nodo.
- Guardrail: las señales de aviso usan `emit` nativo (barato).

---

## Acceptance Criteria

*Derivados de ADR-0001 (Decision, Key Interfaces) y del contrato EventBus de `architecture.md` §API Boundaries:*

- [x] Existe `event_bus.gd` (`extends Node`) registrado como autoload **"EventBus"**, y es el **primero** en
      el orden de autoloads.
- [x] Declara la lista central de **señales de aviso** documentada, con sus firmas tipadas:
  - `tramite_completado(tramite_id: StringName, agente)`
  - `abandono(persona)`
  - `persona_generada(persona)`
  - `cambio_de_turno(turno: int)`
  - `cambio_dia_noche(es_de_noche: bool)`
  - `saldo_cambiado(nuevo_saldo: int)`
  - `reclamacion_generada(origen: StringName)`
  - `nuevo_dia`, `nuevo_mes` (señales de notificación; su disparo ordenado es la Story 002)
- [x] Un oyente conectado con `.connect(Callable)` recibe la señal al emitirla, con los argumentos correctos.
- [x] **Invariante**: el script del bus no contiene lógica de juego ni referencias a sistemas concretos
      (Economía, Flujo…); solo declara señales y (Story 002) el dispatcher.
- [x] Tipado estático en toda firma de señal.

---

## Implementation Notes

*Derivadas de ADR-0001 (Key Interfaces) + control-manifest:*

```gdscript
extends Node   # event_bus.gd — Autoload "EventBus" (el PRIMERO en el orden de autoloads)

# --- Señales de aviso (orden entre oyentes indiferente) ---
signal tramite_completado(tramite_id: StringName, agente)
signal abandono(persona)
signal persona_generada(persona)
signal cambio_de_turno(turno: int)
signal cambio_dia_noche(es_de_noche: bool)
signal saldo_cambiado(nuevo_saldo: int)
signal reclamacion_generada(origen: StringName)

# --- Señales de notificación (se emiten tras el orden crítico → Story 002) ---
signal nuevo_dia
signal nuevo_mes
```

- Registrar el autoload en `project.godot` (Project Settings → Autoload) con nombre exacto `EventBus`,
  el primero de la lista.
- **Mantener la lista de señales documentada** en el propio archivo (mitiga la baja descubribilidad del
  patrón bus — quién escucha qué).
- No añadir aquí ninguna función de juego. El dispatcher ordenado (`registrar_ordenado`/`disparar_ordenado`)
  es de la Story 002 (vive en este mismo autoload, pero se implementa y prueba aparte).

---

## Out of Scope

*Lo manejan historias vecinas — no implementar aquí:*

- **Story 002**: el dispatcher de eventos ordenados por prioridad (`registrar_ordenado`/`disparar_ordenado`)
  y la emisión de `nuevo_dia`/`nuevo_mes` tras el orden crítico.
- **Epic Tiempo**: quién **emite** estas señales (Tiempo es el origen de las de tiempo) y el tick de
  simulación en `_physics_process`.
- **Epics consumidores**: quién **escucha** cada señal (Economía, Paciencia, Feedback…).

---

## QA Test Cases

*Escritos por el hilo principal (QA Lead omitido en LEAN; subagentes caídos). El programador implementa
contra estos casos.*

- **AC-1**: el autoload existe y expone las señales de aviso.
  - Given: el autoload `EventBus` cargado en el árbol.
  - When: se conecta un `Callable` espía a `tramite_completado` y se emite
    `EventBus.tramite_completado.emit(&"dni", null)`.
  - Then: el espía se invoca exactamente 1 vez y recibe `tramite_id == &"dni"`.
  - Edge cases: emitir sin oyentes no falla; conectar 2 oyentes → ambos reciben; desconectar un oyente →
    ya no recibe.
- **AC-2**: las firmas de señal aceptan los tipos declarados.
  - Given: el autoload `EventBus`.
  - When: se emiten `cambio_de_turno.emit(1)`, `cambio_dia_noche.emit(true)`, `saldo_cambiado.emit(3000)`.
  - Then: los espías reciben los valores tipados correctos (turno==1, es_de_noche==true, nuevo_saldo==3000).
  - Edge cases: emisión repetida en el mismo frame → cada emisión llega una vez.
- **AC-3** *(estructural / revisión de código)*: el bus no contiene lógica de juego.
  - Setup: abrir `event_bus.gd`.
  - Verify: solo declara señales (+ dispatcher de Story 002); no importa/referencia sistemas de gameplay
    ni contiene cálculos de juego.
  - Pass condition: 0 referencias a Economía/Flujo/Demanda/etc.; el archivo es puro tablón de anuncios.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/event_bus/event_bus_signals_test.gd` — debe existir y pasar
  (emisión↔recepción de señales con oyente espía; determinismo de entrega).

**Status**: [x] **Creado y PASA** — `tests/integration/event_bus/event_bus_signals_test.gd`, 3/3 test cases,
0 fallos, GdUnit4 headless con Godot 4.6.stable (2026-07-22). Además verificado con un chequeo standalone
(`VERIFY-EVENTBUS: PASS`) antes de instalar GdUnit4.

**Implementación:** `src/foundation/event_bus/event_bus.gd` (autoload `EventBus`, el primero) +
`project.godot` de Producción creado. Falta el cierre formal con `/story-done`.

---

## Dependencies

- Depends on: None (es el primer ladrillo de todo el proyecto).
- Unlocks: Story 002 (dispatcher ordenado); y, de hecho, casi todos los epics (usan estas señales).

## Cierre (2026-07-22)

Cierre formal aprobado por el usuario. Verificación QA read-only (subagente Opus, 2026-07-22): todos los
AC CUMPLIDOS con evidencia archivo:línea; mapeo 1:1 QA Test Case → función de test; 0 desviaciones de ADR
y control-manifest (Foundation). Suite del proyecto 32/32 en verde (re-verificada de forma independiente
en el hilo principal). Informe completo en la sesión (no persistido).
Sugerencia QA a backlog (no bloqueante): añadir asserts para "desconectar oyente → ya no recibe" y "emisión repetida en el mismo frame".
