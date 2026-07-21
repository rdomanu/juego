# Godot Patterns — Event Bus & Architecture

Last verified: 2026-07-22 (via docs.godotengine.org + GDQuest) | Engine: Godot 4.6

Patrones de arquitectura para Comisario. El más importante: el **bus de eventos**, que Feedback #12 (FB1) y muchos sistemas necesitan ("un trámite completado", "abandono", "nuevo_dia"…).

## Event Bus (Autoload Singleton con signals)

Un **singleton autoload que solo emite signals**, para que sistemas **distantes** se comuniquen sin referencias directas (desacople).

### 1. Script del bus
```gdscript
# event_bus.gd  (extends Node)
extends Node

# Tiempo #1
signal nuevo_dia
signal nuevo_mes
signal cambio_de_turno(turno)
signal cambio_dia_noche(es_de_noche)
# Flujo #4
signal tramite_completado(tramite_id, agente)
signal abandono(persona)
# Economía #3
signal saldo_cambiado(nuevo_saldo)
# Paciencia #10
signal reclamacion_generada(origen)
# ... (una signal por evento cross-system del proyecto)
```

### 2. Registrar como Autoload
Project Settings → Autoload → añadir `event_bus.gd` con nombre p. ej. `EventBus`. Queda accesible globalmente sin instanciar.

### 3. Emitir (desde cualquier sistema)
```gdscript
EventBus.tramite_completado.emit(tramite_id, agente)   # Godot 4: SignalName.emit()
# (equivalente antiguo: EventBus.emit_signal("tramite_completado", ...))
```

### 4. Escuchar (conectar)
```gdscript
func _ready() -> void:
    EventBus.tramite_completado.connect(_on_tramite_completado)   # Callable-based (Godot 4)

func _on_tramite_completado(tramite_id, agente) -> void:
    ...
```

### Cuándo usar el bus vs signals directas
- **Usar el bus:** nodos **distantes** en el árbol, o UI/Feedback que reacciona a eventos de muchos sistemas, o nodos instanciados en runtime (las Personas de Flujo).
- **Signals directas (nodo→nodo):** cuando hay una relación directa y cercana (un puesto y su agente). No todo debe pasar por el bus.

### Cautions
- **Discoverability:** con el bus, para rastrear quién escucha un evento hay que buscar en todo el código. Mantén las signals **bien nombradas y documentadas** (una lista central en el propio `event_bus.gd`).
- **No "signal spaghetti":** el bus es para eventos **cross-system**, no para todo.

## Orden de handlers (crítico para Comisario)
Cuando **varios sistemas escuchan el MISMO evento** (`nuevo_dia`: Paciencia cierra `sat`, Economía cobra salarios/recargo, Tiempo avanza el calendario), el **orden de ejecución de los handlers debe ser determinista**. Godot ejecuta los `connect` en el orden en que se conectaron (no garantizado entre autoloads distintos). → **ADR del bus de eventos** debe fijar el orden (p. ej. un dispatcher que llame a los sistemas en secuencia explícita, o prioridades). *(Nota de la revisión holística `/review-all-gdds` 2026-07-22.)*

## Otros patrones (LOW risk, en training data)
- **`@onready var x = %NodoUnico`** para referencias cacheadas (no `$Path` en `_process`, coste por frame).
- **Tipado estático** (`var n: int`, `Array[Tipo]`) — el compilador de GDScript optimiza; el proyecto lo exige (coding-standards).
- **Inyección de dependencias sobre singletons** donde se pueda (coding-standards: testeable). El bus de eventos es la excepción justificada (desacople global).
