# Control Manifest

> **Engine**: Godot 4.6 + GDScript (2D top-down · Forward+ / D3D12 en Windows)
> **Last Updated**: 2026-07-22
> **Manifest Version**: 2026-07-22
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004 (todos Accepted)
> **Status**: Active — regenerar con `/create-control-manifest` cuando cambie un ADR

`Manifest Version` es la fecha de generación. Las stories incrustan esta fecha al crearse;
`/story-readiness` la compara con este campo para detectar stories escritas contra reglas obsoletas.

Esta hoja es la referencia rápida del programador, extraída de los ADRs Accepted, `technical-preferences.md`
y la biblioteca de motor. Para el *porqué* de cada regla, ver el ADR referenciado. **TD-MANIFEST omitido — modo LEAN.**

---

## Foundation Layer Rules

*Aplica a: EventBus, SaveManager, RNGService, Tiempo, Datos, inicialización del juego.*

### Required Patterns
- **Comunicación cross-system vía `EventBus` autoload** — `signal.emit()` para emitir, `.connect(Callable)` para escuchar. La lista central de señales vive documentada en `event_bus.gd`. — ADR-0001
- **Eventos ordenados (`nuevo_dia`/`nuevo_mes`) por registro con prioridad** — cada sistema llama `EventBus.registrar_ordenado(evento, prioridad, cb)`; el disparo (`EventBus.disparar_ordenado(evento)`) invoca por prioridad ascendente. `nuevo_dia`: Paciencia(10)→Economía(20)→Personal(30)→Demanda(40). `nuevo_mes`: Economía(10)→Paciencia(20)→Demanda(30). — ADR-0001
- **La simulación corre en `_physics_process` (paso fijo, 60 Hz); el dibujo en `_process` (tiempo real)** — Tiempo calcula `delta_juego = delta_fijo × escala × mult` (0 en Pausa) y **empuja** el tick en orden fijo: Tiempo→Demanda→Flujo→Paciencia. — ADR-0001
- **Detección de eventos de tiempo por CRUCE de umbral (no `==`); clamp de `delta` por frame** (anti-salto tras alt-tab/lag). — ADR-0001
- **Guardado en JSON + `FileAccess` dentro de `user://`** — patrón `save() -> Dictionary` / `load_state(d: Dictionary)` por sistema; marcar cada nodo persistente con el grupo `"Persist"`; `SaveManager` recorre `get_tree().get_nodes_in_group("Persist")`. — ADR-0002
- **Escritura de save segura**: escribir en archivo temporal y **renombrar** (`temp` → `savegame.save`); **comprobar el `bool` de retorno de `store_*`** (devuelve `bool` desde 4.4). — ADR-0002
- **Serializar el estado del `RNGService` (estado + semilla)**; toda aleatoriedad de juego pasa por `RNGService` sembrado. — ADR-0002
- **`Vector2i` (celdas del layout) → `{"x":.., "y":..}`** al serializar (JSON no serializa `Vector2i`/`Color`/`Rect2`). — ADR-0002
- **Al cargar: el catálogo (Datos) ya debe estar cargado; Tiempo queda en Pausa; NO se re-disparan eventos** ("cargar sitúa, no reproduce"); un `id` huérfano se migra/descarta con log, nunca invalida el save. Campo `"version"` en el save para migraciones. — ADR-0002
- **Catálogo = Custom Resources (`.tres`) tipados** (`class_name` + `@export`), cargados con `load()`/`preload()`; jerarquía `Atencion` → `TramiteDoc`/`DenunciaODAC`, más `TipoPuesto`/`TipoSala`/`TipoAgente`/`Costes`/`Escenario`. Un `.tres` por definición, en carpetas por tipo. — ADR-0003
- **Referencias entre definiciones por `id` (`StringName`), nunca anidando Resources**; Datos indexa por `id` y **valida en carga** (refs colgantes, ids únicos, clamp de rangos, invariante R5 → warning). `Datos.obtener(tipo, id)` devuelve la definición **read-only**. — ADR-0003
- **Orden de autoloads**: `EventBus → RNGService → Datos → Tiempo → SaveManager` (Datos valida el catálogo en su `_ready`; Tiempo arranca en Pausa). — ADR-0002 / ADR-0003

### Forbidden Approaches
- **Nunca la Foundation llama a los sistemas por nombre** (EventBus/SaveManager/RNG/Tiempo/Datos) — usar señales, callables registrados (`registrar_ordenado`) o el grupo `"Persist"`. Acoplar hacia arriba viola las capas y anula el desacople. — ADR-0001
- **Nunca usar el EventBus para TODO ("signal spaghetti")** — es solo para eventos cross-system entre nodos distantes; las relaciones cercanas (un puesto y su agente) usan **señal directa nodo→nodo**. — ADR-0001
- **Nunca guardar el save de partida como custom Resource** (`.tres`/`.res`/`.tscn`) ni cargarlo con `load()`/`ResourceLoader` — cargar un Resource ejecuta su `_init` → código arbitrario en saves manipulados; además issue de `ResourceSaver` en 4.6. — ADR-0002
- **Nunca guardar en `res://`** (solo lectura al exportar) — siempre `user://`. — ADR-0002
- **Nunca olvidar serializar el RNG** (rompería el determinismo al cargar). — ADR-0002

### Performance Guardrails
- **Tiempo**: update `< 0,1 ms` por frame (AC-T33). — ADR-0001
- **EventBus**: `disparar_ordenado` corre 1×/jornada (coste trivial); las señales de aviso usan `emit` nativo. — ADR-0001

---

## Core Layer Rules

*Aplica a: Economía, Flujo, Demanda, Personal, Construcción (la simulación viva).*

### Required Patterns
- **Rejilla = `TileMapLayer`** (una capa por función: `suelo`, `paredes/salas`). Celda bajo cursor = `local_to_map(get_local_mouse_position())`; validar colocación con `get_cell_source_id` (solapamiento) + límites del edificio (`get_used_rect` o tamaño del `Escenario`); salas = iterar `Vector2i` esquina a esquina + `set_cell`. — ADR-0004
- **Puestos/objetos = `PackedScene` instanciadas con `instantiate()`** y posicionadas con `map_to_local(celda)` — son nodos con lógica, **no** tiles del mapa. — ADR-0004
- **Navegación = `NavigationRegion2D` + `NavigationPolygon` (bakeado) + `NavigationAgent2D`** hijo de cada Persona (`CharacterBody2D`). Mover en `_physics_process`: si `not is_navigation_finished()`, ir hacia `get_next_path_position()` con `velocity = direction * vel; move_and_slide()`. — ADR-0004
- **Fijar el primer `target_position` tras `await get_tree().physics_frame`** (el NavigationServer se sincroniza en el 1er physics frame), **nunca en `_ready()`**. — ADR-0004
- **Re-bake de la `NavigationPolygon` solo al cambiar el layout** (construir/demoler), nunca por frame. — ADR-0004
- **Avoidance desactivado/mínimo** (Experimental en 4.6) → movimiento con `velocity` directa + `move_and_slide()` (sin `velocity_computed`, que solo se usa con avoidance activo). El solapamiento visual leve es aceptable (cosmético). — ADR-0004
- **Economía**: ingreso instantáneo al oír `tramite_completado`; cobros al `nuevo_dia` en su prioridad (20); gates `puede_pagar()`/`cobrar()`/`abonar()` (gasto voluntario solo si `puede_pagar()==true`). — ADR-0001
- **Demanda/Personal**: toda aleatoriedad (mezcla ponderada, mercado, ausencias) por `RNGService` sembrado (`randi_rango`/`elegir_ponderado`). — ADR-0002

### Forbidden Approaches
- **La lógica de balance NUNCA lee la posición/movimiento del sprite de un NPC** para decidir (colas, selección, espera, abandono) — el movimiento es una capa **cosmética**; el tiempo de desplazamiento se contabiliza en la lógica (Flujo FL5). — ADR-0004
- **Nunca usar `TileMap`** (deprecado desde 4.3) → `TileMapLayer`. — ADR-0004
- **Nunca fijar `target_position` en `_ready()`; nunca re-bake la NavigationPolygon por frame.** — ADR-0004
- **Nunca meter la lógica de un puesto en un tile** (los puestos son nodos/escenas; el TileMap es suelo/paredes). — ADR-0004
- **Nunca usar `randi()`/`randf()` global** — toda aleatoriedad de juego pasa por `RNGService`. — ADR-0002

### Performance Guardrails
- **Flujo (navegación)**: 60 FPS con docenas de NPCs es el **riesgo técnico nº1** → **spike de rendimiento obligatorio (QQ-02)** antes de escalar el volumen; plan B = `AStarGrid2D`. — ADR-0004

---

## Feature Layer Rules

*Aplica a: Documentación, ODAC, Paciencia (configuran/parametrizan el Core).*

### Required Patterns
- **Implementan `save()`/`load_state()` y se marcan con el grupo `"Persist"`** (estado mutable: config de puestos, sat, reclamaciones, paciencias). — ADR-0002
- **Registran su prioridad en los eventos ordenados** — Paciencia cierra `sat` al `nuevo_dia` (prioridad **10**) **antes** de que Economía cobre (20). — ADR-0001
- **Leen definiciones del catálogo por `id` (read-only)** vía `Datos.obtener(...)`; ODAC lee las 13 `DenunciaODAC` con `prioridad`. — ADR-0003
- **Paciencia genera `reclamacion` en ODAC con probabilidad vía `RNGService`** (sin recursión; empate llamada-vs-abandono → gana la llamada). — ADR-0001 / ADR-0002

### Forbidden Approaches
- **Nunca mutar lo que devuelve `Datos.obtener`** (es una plantilla compartida read-only) — las instancias de partida son objetos aparte. — ADR-0003
- **Nunca depender de la posición del sprite** para la lógica (heredado del Core). — ADR-0004

---

## Presentation Layer Rules

*Aplica a: UI/HUD, Feedback y Juice (rendering, cámara, avisos, mood).*

### Required Patterns
- **La UI lee estado y emite órdenes al dueño (que valida); NUNCA muta estado de juego.** — ADR-0001 (principio 3) / diseño
- **Feedback escucha el bus (read-only)**; vocabulario evento→respuesta data-driven. — ADR-0001
- **El dibujo va en `_process`** (tiempo real); los efectos siguen funcionando a 2×/3×. — ADR-0001
- **Mood ambiental = `CanvasModulate` + `Light2D`** (glow 2D real descartado); flotantes/emotes/pulses con `Tween`/`AnimationPlayer`. — `rendering.md` / feedback-juice.md
- **UI ratón-first, sin interacciones hover-only**; contar con el **dual-focus de 4.6** (ratón separado de teclado). — `technical-preferences.md` / `current-best-practices.md`
- **Referencias cacheadas `@onready var x = %Nodo`** (no `$Path` en `_process`). — `patterns.md`

### Forbidden Approaches
- **La lógica NUNCA llama a la UI** — se comunican por el bus. — ADR-0001 (principio 3)
- **Nunca guardar estado de juego en la UI** — solo preferencias de UI. — ADR-0002

---

## Global Rules (All Layers)

### Naming Conventions
| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Clases | PascalCase | `PlayerController` |
| Variables y funciones | snake_case | `move_speed`, `take_damage()` |
| Señales/eventos | snake_case, pasado | `health_changed`, `tramite_completado` |
| Archivos | snake_case (= clase) | `player_controller.gd` |
| Escenas/prefabs | PascalCase (= nodo raíz) | `PlayerController.tscn` |
| Constantes | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets
| Objetivo | Valor |
|----------|-------|
| Framerate | 60 FPS |
| Frame budget | 16,6 ms |
| Draw calls | *(por configurar — al fijar hardware objetivo)* |
| Memory ceiling | *(por configurar — al fijar hardware objetivo)* |

### Approved Libraries / Addons
- Ninguna aprobada aún (proyecto sin dependencias externas).

### Forbidden APIs (Godot 4.6)
Deprecadas / no verificadas para 4.6 — **usar el sustituto**. Fuente: `docs/engine-reference/godot/deprecated-apis.md`.
- `TileMap` → **`TileMapLayer`** (4.3)
- `Navigation2D`/`Navigation3D` → **`NavigationServer2D`/`3D`** (4.0)
- `instance()` / `PackedScene.instance()` → **`instantiate()`** (4.0)
- `connect("sig", obj, "metodo")` (string) → **`signal.connect(callable)`** (4.0)
- `yield()` → **`await signal`** (4.0)
- `duplicate()` para Resources anidados → **`duplicate_deep()`** (4.5) *(en este proyecto se evita anidando por `id`)*
- `$NodePath` en `_process()` → **`@onready var` cacheado**
- `OS.get_ticks_msec()` → **`Time.get_ticks_msec()`** (4.0)

### Cross-Cutting Constraints
- **Tipado estático obligatorio** (`var n: int`, `Array[Tipo]`) — lo exige `coding-standards.md`.
- **Data-driven, nunca hardcodeado** — todo valor de juego vive en el catálogo (Datos); el código lee por `id`.
- **Determinismo por diseño** — aleatoriedad por `RNGService` sembrado + simulación en paso fijo; misma partida → mismo resultado.
- **Capas estrictas** — Presentation → Feature → Core → Foundation → Platform; nunca al revés.
- **"Cargar = situar, no reproducir"** — restaurar estado y arrancar en Pausa; sin eventos retroactivos.
- **Herramientas**: para filtrar GDScript usar `glob: "*.gd"` — `rg --type gdscript` es un error (los `.gd` están bajo el tipo `gap`).
