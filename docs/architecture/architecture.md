# Comisario — Arquitectura Maestra

## Estado del documento

- **Versión:** 1.0
- **Última actualización:** 2026-07-22
- **Motor:** Godot 4.6 + GDScript · 2D top-down · Forward+ (D3D12 en Windows)
- **GDD cubiertos:** los 12 del MVP (Tiempo #1, Datos #2, Economía #3, Flujo #4, Demanda #5, Personal #6, Construcción #7, Documentación #8, ODAC #9, Paciencia #10, UI/HUD #11, Feedback #12)
- **ADRs referenciados:** ninguno aún (todos son "ADR nuevo requerido" — ver §Required ADRs)
- **Technical Director Sign-Off:** 2026-07-22 — **APPROVED WITH CONDITIONS** (escribir + aceptar ADR-0001/0002/0003 antes de codificar gameplay; correr el spike de rendimiento QQ-02 en el vertical slice)
- **Lead Programmer Feasibility:** N/A — gate LP-FEASIBILITY omitido (modo LEAN; no es PHASE-GATE)

> **Nota de proceso:** redactado en el hilo principal (los subagentes de estudio fallan con "API Error:
> Usage credits required for 1M context"), aplicando manualmente las lentes de *technical-director* y
> *lead-programmer*. Modo de revisión: **LEAN**.

---

## Resumen del knowledge gap del motor (Fase 0d)

**Motor:** Godot 4.6 (enero 2026). El conocimiento base del LLM llega a ~4.3 → 4.4/4.5/4.6 son
post-cutoff. **Biblioteca de referencia verificada 2026-07-22** en `docs/engine-reference/godot/`.

**Hallazgo clave:** la mayoría de los cambios HIGH-risk de Godot 4.6 son de **3D** (Jolt, IK, glow 3D,
tonemapping/AgX, SSR) → **NO afectan a Comisario**, que es 2D puro. Los dominios 2D que sí usa el
proyecto están todos verificados.

| Dominio 2D usado | Estado 4.6 (verificado) | Riesgo residual |
|---|---|---|
| Rejilla de construcción | `TileMapLayer` (`TileMap` **deprecado** desde 4.3) | Bajo (API verificada) |
| Navegación de NPCs | `NavigationServer2D` **dedicado** (4.5) + `NavigationAgent2D` | Medio (rendimiento con muchos agentes → spike) |
| Guardado de partida | **JSON/ConfigFile en `user://`**, NO custom Resources (seguridad + issue `ResourceSaver` 4.6) | Bajo (patrón verificado) |
| Mood ambiental 2D | **CanvasModulate + Light2D**; glow 2D real **descartado** | Ninguno (decisión tomada) |
| UI | Dual-focus 4.6 (ratón separado de teclado); ratón-first sin hover-only | Bajo (a validar en UX) |
| Ficheros | `FileAccess.store_*` devuelve `bool` (4.4, antes `void`) | Bajo (nota de implementación) |
| Backend Windows | D3D12 por defecto (antes Vulkan) | Ninguno (transparente para 2D) |

**No hay dominios HIGH-risk sin resolver.** Los puntos post-cutoff se marcan con ⚠️ a lo largo del documento.

---

## Technical Requirements Baseline (Fase 0b)

Extraídos de los 12 GDD del MVP. ~70 requisitos técnicos, todos con destino a un ADR o cubiertos por una
decisión ya tomada. Códigos de dominio: **[TIM]** reloj · **[EVT]** bus de eventos · **[DAT]** datos ·
**[SAV]** guardado · **[SIM]** simulación · **[RNG]** aleatoriedad determinista · **[NAV]** navegación 2D ·
**[REN]** render/UI · **[PERF]** rendimiento · **[API]** contrato entre módulos.

### Foundation — Tiempo (#1)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-time-001 | Reloj acumula tiempo real (`delta`), no frames → mismo resultado a cualquier FPS | [TIM][SIM] |
| TR-time-002 | Velocidades {Pausa,1×,2×,3×}; Pausa congela simulación pero permite gestión | [TIM] |
| TR-time-003 | Detección de **cruce** de umbral (no `==`) → cada evento se emite 1 vez | [TIM][EVT] |
| TR-time-004 | Orden determinista al cruzar varios umbrales (turno→día/noche→nuevo_dia) | [EVT] |
| TR-time-005 | Clamp de `delta` por frame (anti-salto tras alt-tab/lag) | [TIM] |
| TR-time-006 | Emite señales globales (cambio_de_turno, cambio_dia_noche, nuevo_dia, nuevo_mes…) | [EVT] |
| TR-time-007 | Fuente **única** de tiempo (nadie más mantiene reloj) | [API] |
| TR-time-008 | Serializar reloj/fecha; al cargar arranca en Pausa, sin eventos retroactivos | [SAV] |
| TR-time-009 | Update < 0,1 ms (AC-T33) | [PERF] |

### Foundation — Datos (#2)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-data-001 | Catálogo data-driven (TramiteDoc, DenunciaODAC, TipoPuesto/Sala/Agente, Escenario) desde fuente externa | [DAT] |
| TR-data-002 | Definición (read-only) ≠ Instancia (la poseen otros, referencian por `id`) | [DAT][API] |
| TR-data-003 | Validación en carga: integridad referencial, ids únicos, clamp de rangos, invariante R5 | [DAT] |
| TR-data-004 | Lookup de definición por `id` en runtime | [DAT] |
| TR-data-005 | Formato del catálogo `.tres` vs JSON (Open Q#8) → **decisión de arquitectura** | [DAT] |
| TR-data-006 | Tolerancia a catálogo cambiante entre versiones de save (id huérfano→migra/descarta+log) | [SAV] |

### Foundation — infraestructura implícita (sin GDD)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-bus-001 | Bus de eventos global (autoload + signals) para comunicación cross-system desacoplada | [EVT] |
| TR-bus-002 | **Orden de handlers determinista** cuando varios sistemas escuchan el mismo evento (nuevo_dia/nuevo_mes) | [EVT] |
| TR-save-001 | Guardado JSON/ConfigFile en `user://` (NO custom Resources); patrón `save()`/`load_state()` por sistema | [SAV] |
| TR-save-002 | Serializar estado del **RNG** + semilla (determinismo al cargar) | [SAV][RNG] |
| TR-save-003 | `Vector2i` (celdas del layout) → descomponer a `[x,y]` (limitación JSON) | [SAV] |

### Core — Economía (#3), Flujo (#4), Demanda (#5), Personal (#6), Construcción (#7)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-economy-001 | `saldo_eur` mutable; ingreso instantáneo al oír `tramite_completado` | [SIM][EVT] |
| TR-economy-002 | Cobros al `nuevo_dia` en **orden determinista** (recargo→gastos→reset) | [EVT][SIM] |
| TR-economy-003 | Estado financiero derivado + rescate con pausa/modal/ventana de gracia (timer de juego) | [SIM][TIM] |
| TR-economy-004 | Gates "¿puedo construir/contratar?" expuestos a Construcción/Personal | [API] |
| TR-flow-001 | Instancia **Persona** con máquina de estados (7 estados) | [SIM] |
| TR-flow-002 | Colas por servicio (FIFO + prioridad ODAC); selección/desempate determinista | [SIM] |
| TR-flow-003 | Emparejamiento automático puesto→persona; ciclo de atención avanza con `delta` | [SIM][TIM] |
| TR-flow-004 | Emite `tramite_completado` y `abandono` | [EVT] |
| TR-flow-005 | **Muchos NPCs navegando a la vez** → `NavigationAgent2D` + spike de rendimiento | [NAV][PERF] |
| TR-flow-006 | Serializar colas/puestos/personas (estado, turno, posición, tiempo restante) | [SAV] |
| TR-demand-001 | Genera Personas → `persona_generada` a Flujo; acumulador alimentado por `delta` | [SIM][EVT] |
| TR-demand-002 | **RNG sembrado** determinista (mezcla ponderada, normalización defensiva) | [RNG] |
| TR-demand-003 | Señal derivada BAJA/MEDIA/ALTA expuesta a UI/Documentación | [API] |
| TR-staff-001 | Instancias Agente (atributos, rango, asignación); mercado con RNG sembrado | [SIM][RNG] |
| TR-staff-002 | Provee `modificador_produccion`/`factor_trato` y gate FL4 a Flujo | [API] |
| TR-staff-003 | Ausencias evaluadas al `nuevo_dia` (RNG determinista) | [EVT][RNG] |
| TR-construction-001 | **Rejilla 2D = `TileMapLayer`** (⚠️ `TileMap` deprecado) | [REN] |
| TR-construction-002 | Ratón↔celda (`local_to_map`/`map_to_local`) para preview fantasma + validación | [REN][SIM] |
| TR-construction-003 | Puestos/objetos = escenas (`PackedScene`) instanciadas, no tiles | [REN][SIM] |
| TR-construction-004 | Provee existencia/posición/aforo a Flujo/Personal; serializa layout | [API][SAV] |

### Feature — Documentación (#8), ODAC (#9), Paciencia (#10)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-doc-001 | Configura horario/última admisión que Flujo **ejecuta** y Demanda **respeta** | [API] |
| TR-doc-002 | Eventos de la División (estacionales) que amplían horario | [EVT][DAT] |
| TR-odac-001 | Configura prioridad (Flujo F7) + reconfiguración en caliente de puestos (4 modos) | [API][SIM] |
| TR-odac-002 | Aporta `peso_prioridad` a Paciencia; recibe carga de `reclamacion` | [API][EVT] |
| TR-patience-001 | Barra de paciencia por persona; drena con `delta`; Pausa congela; hacinamiento acelera | [TIM][SIM] |
| TR-patience-002 | Escucha eventos de Flujo; ordena abandono (`persona_abandona`) al llegar a 0 | [EVT] |
| TR-patience-003 | Cierre de satisfacción al `nuevo_dia`; Economía usa `sat_cierre` **anterior** (ingreso estable intra-jornada) | [EVT][SIM] |
| TR-patience-004 | Genera `reclamacion` en ODAC (prob, RNG); sin recursión; empate llamada-vs-abandono → gana llamada | [EVT][RNG][SIM] |

### Presentation — UI/HUD (#11), Feedback (#12)
| ID | Requisito | Dominio |
|----|-----------|---------|
| TR-ui-001 | Capa **pura de presentación**: lee estado/eventos, **no muta**; emite órdenes al dueño (que valida) | [API][REN] |
| TR-ui-002 | HUD persistente (`Control`+`CanvasLayer`); data-driven; registro de pantallas desbloqueable por rango | [REN][DAT] |
| TR-ui-003 | Cámara `Camera2D` pan/zoom; modos Construcción/Asignación (arrastrar) | [REN] |
| TR-ui-004 | Ratón-first, **sin hover-only** (⚠️ dual-focus 4.6); accesibilidad (color+icono+texto; `escala_ui`) | [REN] |
| TR-ui-005 | No guarda estado de juego; sí preferencias de UI | [SAV] |
| TR-feedback-001 | Escucha el **bus de eventos** (read-only); vocabulario evento→respuesta data-driven | [EVT] |
| TR-feedback-002 | Números flotantes/emotes/pulses (Tween/AnimationPlayer); **mood = CanvasModulate+Light2D** (glow 2D descartado) | [REN] |
| TR-feedback-003 | Juice budget (pool con límite); degradación elegante < 60 FPS; efectos en tiempo real (2×/3×) | [PERF][TIM] |

### Las 6 decisiones transversales (columna vertebral → ADRs)

1. **Bus de eventos** [EVT] — comunicación desacoplada + **orden determinista de handlers** (nuevo_dia:
   Paciencia cierra `sat` → Economía cobra → Tiempo avanza fecha). *Toca los 12 sistemas.* → **ADR-0001**
2. **Guardado / serialización** [SAV] — JSON en `user://`, `save()`/`load_state()` por sistema, serializar
   el RNG. *Todos los que tienen estado mutable.* → **ADR-0002**
3. **Formato del catálogo de datos** [DAT] — `.tres` (Resource) vs JSON. *Datos + lectores del catálogo.*
   → **ADR-0003**
4. **Rejilla + navegación 2D** [REN][NAV] — `TileMapLayer` + `NavigationAgent2D`. *Construcción + Flujo.*
   → **ADR-0004**
5. **Determinismo global** [RNG] — servicio de RNG sembrado central, serializable. *Demanda/Personal/
   Paciencia.* → cubierto por ADR-0002 (serialización del RNG) + principio de arquitectura.
6. **Presupuesto de rendimiento** [PERF] — 60 FPS con docenas de NPCs (riesgo técnico nº1) → spike antes
   de escalar volumen. *Flujo.* → nota de riesgo + Open Question (no ADR).

---

## Mapa de capas (Fase 1)

```
┌───────────────────────────────────────────────────────────────────────┐
│  PRESENTATION   UI/HUD #11  ·  Feedback y Juice #12                    │  ← lee estado, no muta
├───────────────────────────────────────────────────────────────────────┤
│  FEATURE        Documentación #8  ·  ODAC #9  ·  Paciencia #10         │  ← configuran/parametrizan Core
├───────────────────────────────────────────────────────────────────────┤
│  CORE           Economía #3 · Flujo #4 · Demanda #5 ·                  │  ← la simulación viva
│                 Personal #6 · Construcción #7                          │
├───────────────────────────────────────────────────────────────────────┤
│  FOUNDATION     Tiempo #1 · Datos #2 · ▸EventBus · ▸SaveManager · ▸RNG │  ← infraestructura; sin deps de diseño
├───────────────────────────────────────────────────────────────────────┤
│  PLATFORM       Godot 4.6 · GDScript · 2D · Forward+ (D3D12 Windows)   │  ← el motor
└───────────────────────────────────────────────────────────────────────┘
```

**Regla de oro (una capa solo depende de las de abajo):** Presentation → Feature → Core → Foundation →
Platform. La UI **nunca** es leída por la lógica; la lógica **nunca** llama a la UI (se comunican por el bus).

▸ = **módulos de infraestructura nuevos** (sin GDD porque son técnicos): `EventBus`, `SaveManager` y
`RNGService` — la parte de la Foundation que la arquitectura *añade* a lo diseñado.

**Chequeo de motor en Foundation/Core (APIs post-cutoff):**
| Módulo | API de motor | Riesgo | Verificado en |
|--------|-------------|--------|---------------|
| Construcción | `TileMapLayer` (`TileMap` deprecado) | ⚠️ post-cutoff | `modules/tilemap-2d.md` |
| Flujo | `NavigationServer2D`/`NavigationAgent2D` (dedicado 4.5; gotcha 1er physics frame) | ⚠️ post-cutoff | `modules/navigation.md` |
| SaveManager | `FileAccess.store_*`→`bool` (4.4); `user://`; JSON | ⚠️ post-cutoff | `modules/save-load.md` |
| EventBus | Autoload + `signal.emit()`/`.connect(callable)` | ✅ estable | `modules/patterns.md` |
| Tiempo | `_process`/`_physics_process`, `delta` | ✅ estable (training) | — |
| Datos | `Resource`/`.tres` (`duplicate_deep()` 4.5 si anida) | ⚠️ leve | `modules/save-load.md` |

---

## Propiedad de módulos (Fase 2)

| Módulo | **Posee** (dueño único) | **Expone** (leen/llaman otros) | **Consume** | APIs de motor |
|--------|------|--------|---------|-----------|
| **Tiempo #1** | reloj, fecha, velocidad, turno | getters de hora/turno/fecha; señales de tiempo | input jugador; carga | `_process`, `delta` |
| **Datos #2** | catálogo de definiciones | lookup por `id` | (fuente externa) | `Resource`/`load` |
| **▸EventBus** | las señales cross-system | `emit`/`connect`; dispatcher de orden | — | Autoload, `signal` |
| **▸SaveManager** | orquestación de save/load | `guardar()`/`cargar()`; grupo "Persist" | `save()` de cada sistema | `FileAccess`, `JSON` |
| **▸RNGService** | estado del RNG + semilla | `randi()`/`randf()` sembrados; serialización | semilla de partida | `RandomNumberGenerator` |
| **Economía #3** | `saldo_eur`, préstamos, estado financiero | saldo, gates E4, balance | `tramite_completado`, `nuevo_dia`, `sat_cierre_doc`, catálogo | — |
| **Flujo #4** | Personas, colas, ciclo de atención | estado de colas/puestos; `tramite_completado`/`abandono` | `delta`+pausa, catálogo, Personas de Demanda, agente de Personal, aforo de Construcción | `NavigationAgent2D`, `CharacterBody2D` |
| **Demanda #5** | volumen/timing de llegadas | `persona_generada`; señal BAJA/MEDIA/ALTA | reloj, catálogo, ventana de Doc/ODAC, RNG | — |
| **Personal #6** | plantilla, atributos, asignación, Oficial | agente por puesto, `modificador_produccion`/`factor_trato`, gate FL4 | catálogo, gate Economía, `nuevo_dia`, RNG | — |
| **Construcción #7** | rejilla, layout, salas/puestos/objetos, aforo | existencia/posición de puestos, aforo | catálogo, gate Economía | `TileMapLayer`, `PackedScene` |
| **Documentación #8** | horario, última admisión, eventos División | config de horario a Flujo/Demanda | catálogo, nivel de Demanda, Paciencia | — |
| **ODAC #9** | prioridad, reconfiguración, `peso_prioridad` | modo de puesto, peso a Paciencia | catálogo, Flujo (ejecuta) | — |
| **Paciencia #10** | escala `sat` 0–100, curva de paciencia, reclamaciones | `sat_cierre_doc`; escala a ODAC; contador reclamaciones | eventos de Flujo, `delta`, `nuevo_dia`, aforo, `factor_trato`, RNG | — |
| **UI/HUD #11** | pantallas, cámara, avisos, preferencias UI | (nada de juego) | estado de **todos** (lee); emite órdenes | `Control`, `CanvasLayer`, `Camera2D` |
| **Feedback #12** | vocabulario evento→respuesta, mood, pool de efectos | (nada) | **bus de eventos** (read-only), art bible | `CanvasModulate`, `Light2D`, `Tween`, `AnimationPlayer` |

**Diagrama de dependencias (quién lee/escucha a quién):**
```
        UI #11 ──lee──▶ (todos)        Feedback #12 ──escucha bus──▶ (eventos de todos)
          │ órdenes                              ▲
          ▼                                      │ emiten eventos
   Doc #8 · ODAC #9 ──configuran──▶ Flujo #4 ◀── Demanda #5 (persona_generada)
                                      │  ▲            │
              Paciencia #10 ◀─eventos─┘  └─agente─ Personal #6 ─gate─▶ Economía #3
                    │ sat_cierre_doc                    │              ▲ tramite_completado
                    └──────────────────────────────────┼──────────────┘
   Construcción #7 ─existencia/aforo─▶ Flujo   (todos) ─────▶ EventBus / SaveManager / RNG
                                          Tiempo #1 · Datos #2 (Foundation, leídos por todos)
```

---

## Flujo de datos (Fase 3)

### 3.1 · Bucle de simulación por frame

> **🔧 Decisión D1 — La simulación corre en `_physics_process` (paso fijo), no en `_process`.**
> `_physics_process` se ejecuta a tasa **fija** (60 Hz por defecto) pase lo que pase con los FPS de
> dibujado. Poner ahí la simulación da **(a) determinismo** (`delta` constante → "misma partida = mismo
> resultado", exigencia del proyecto) y **(b)** es lo que `NavigationAgent2D` necesita para mover NPCs. El
> **dibujado** (UI, juice, cámara) va en `_process` (tiempo real, suave). Satisface TR-time-001 mejor que
> un `_process` de `delta` variable. → alimenta ADR-0001.

```
                    ┌─ 60 veces/seg (FIJO) ──────────────────────────────────┐
   _physics_process │  Tiempo #1: delta_juego = 1/60 × escala × mult          │  ← si Pausa: delta_juego = 0
   (SIMULACIÓN)     │     │  (si cruza umbral → dispara eventos, ver 3.2)      │
                    │     ▼                                                    │
                    │  Demanda #5: acumulador += llegadas(delta_juego)         │
                    │     │  → crea Persona → EventBus.persona_generada         │
                    │     ▼                                                    │
                    │  Flujo #4: mueve NPCs (NavigationAgent2D), avanza         │
                    │     atención (delta_juego); al terminar → tramite_completado│
                    │     ▼                                                    │
                    │  Paciencia #10: drena barras (delta_juego)               │
                    └────────────────────────────────────────────────────────┘

                    ┌─ cada frame de dibujo (VARIABLE, p.ej. 144 FPS) ────────┐
   _process         │  UI/HUD #11: refresca HUD, cámara pan/zoom               │
   (PRESENTACIÓN)   │  Feedback #12: números flotantes, mood (Tween, tiempo real)│
                    └────────────────────────────────────────────────────────┘
```

**Orden dentro del tick de simulación** (determinista): Tiempo → Demanda → Flujo → Paciencia. Lo garantiza
que Tiempo **empuja** el tick (llama en secuencia), no que cada nodo corra por su cuenta. En **Pausa**,
`delta_juego = 0` → nada se simula; la UI (en `_process`) sigue viva.

### 3.2 · Bus de eventos y orden de handlers

- **Evento cross-system** (nodos lejanos, muchos oyentes) → **EventBus** (autoload + signals).
- **Relación directa cercana** (un puesto y su agente) → señal directa nodo→nodo (no todo pasa por el bus).

**Orden de handlers** (TR-bus-002): cuando varios sistemas escuchan `nuevo_dia`, el orden importa y Godot no
lo garantiza entre autoloads. Solución: **dispatcher explícito**.

```
  MEDIANOCHE (Tiempo cruza 00:00)
        │  dispatcher determinista (orden documentado):
   1. Tiempo         avanza la fecha (semana/mes/año)
   2. Paciencia #10  cierra sat_cierre_<servicio> de la jornada que acaba   ── PS8
   3. Economía #3    cobra cierre: recargo → salarios/peonada/préstamos → reset ── F6
   4. Personal #6    evalúa ausencias del nuevo día (RNG sembrado)          ── PA7
   5. Demanda #5     resetea acumuladores del día
        │
        ▼
   EventBus.nuevo_dia.emit()  →  oyentes NO críticos (UI refresca, Feedback) — orden indiferente
```

*Por qué:* Paciencia congela `sat` **antes** de que Economía lo use; Economía cierra caja antes de arrancar
el día; las ausencias se resuelven al iniciar el día. (`nuevo_mes`: Economía balance → Paciencia
evalúa/resetea reclamaciones → Demanda aplica perfil estacional.)

> **🔧 Decisión D2 — Dispatcher explícito para eventos ordenados; `signal.emit()` suelto para el resto.**
> Los eventos con orden crítico (`nuevo_dia`, `nuevo_mes`) pasan por un método dispatcher que llama a los
> sistemas en secuencia. Los eventos "de aviso" (`tramite_completado`, `abandono`, día/noche) son
> `signal.emit()` normales. → núcleo del ADR-0001.

### 3.3 · Guardado y carga

```
  GUARDAR (SaveManager.guardar)                CARGAR (SaveManager.cargar)
  ─────────────────────────────                ─────────────────────────────
  1. recorre sistemas "Persist"                1. FileAccess.get_as_text (user://)
     → cada uno devuelve save()->Dictionary    2. JSON.parse → Dictionary raíz
  2. ensambla { version, rng, tiempo,          3. Datos ya cargado (catálogo) — necesario:
       economia, flujo, personal,                 las instancias referencian ids
       construccion, paciencia, ... }          4. por sistema: load_state(dict)
  3. JSON.stringify                               (incluye estado del RNG + semilla)
  4. FileAccess.WRITE → user://savegame.save   5. Tiempo → PAUSA; sin eventos retroactivos
                                               6. UI → vista Comisaría
```
- **Formato:** JSON en `user://` (NUNCA custom Resources — seguridad + issue `ResourceSaver` 4.6). ⚠️ `FileAccess.store_*` devuelve `bool` en 4.6. → núcleo del ADR-0002.
- **`Vector2i` del layout** (celdas) → guardar como `[x, y]` (JSON no serializa `Vector2i`).
- **RNG:** se serializa su estado + semilla → secuencia futura idéntica al cargar (determinismo).
- **Cargar = situar, no reproducir:** se restaura el estado y se arranca en Pausa; no se re-disparan cobros ni llegadas pasadas.

### 3.4 · Orden de inicialización (arranque)

```
  1. AUTOLOADS (Project Settings → Autoload, en este orden):
       EventBus → RNGService → Datos → Tiempo → SaveManager
       (Datos carga y VALIDA el catálogo en su _ready; Tiempo arranca parado)
  2. Cargar Escenario (Pozuelo) desde Datos → validar invariante R5
  3. Instanciar el mundo: Construcción (layout), Personal (plantilla inicial), Flujo, Demanda…
  4a. PARTIDA NUEVA: estado inicial (caja 3000, sat_inicial 50, semilla RNG nueva) → velocidad 1×
  4b. CARGAR PARTIDA: SaveManager.cargar (§3.3) → velocidad Pausa
  5. Sistemas conectan sus handlers al EventBus
```
*Regla:* la Foundation (EventBus, RNG, Datos, Tiempo) existe **antes** que cualquier sistema Core; el
catálogo se valida **antes** de instanciar nada que lo referencie.

---

## Contratos entre módulos / API Boundaries (Fase 4)

Pseudocódigo GDScript (tipado estático, como exige el proyecto). Tipos de Godot usados (`Signal`,
`Callable`, `Vector2i`, `Dictionary`, `RandomNumberGenerator`, `FileAccess`): **verificados** para 4.6.

**EventBus** (autoload) — el tablón de anuncios del juego
```gdscript
extends Node   # event_bus.gd, autoload "EventBus"
# --- Señales cross-system (emisor entre paréntesis) ---
signal nuevo_dia                              # (Tiempo, tras dispatcher)
signal nuevo_mes                              # (Tiempo, tras dispatcher)
signal cambio_de_turno(turno: int)           # (Tiempo)
signal cambio_dia_noche(es_de_noche: bool)   # (Tiempo)
signal persona_generada(persona)             # (Demanda -> Flujo)
signal tramite_completado(tramite_id: StringName, agente)  # (Flujo -> Economia, Paciencia, Feedback)
signal abandono(persona)                      # (Flujo/Paciencia -> Feedback, contador)
signal saldo_cambiado(nuevo_saldo: int)      # (Economia -> UI, Feedback)
signal reclamacion_generada(origen: StringName)  # (Paciencia -> ODAC, Feedback)
# Invariante: SOLO emite/retransmite; NUNCA contiene logica de juego.
# Garantia: los handlers ordenados (nuevo_dia/nuevo_mes) se invocan por dispatcher, no por connect suelto.
```

**RNGService** (autoload) — aleatoriedad determinista y serializable
```gdscript
func sembrar(semilla: int) -> void
func randi_rango(desde: int, hasta: int) -> int
func randf() -> float
func elegir_ponderado(pesos: Array[float]) -> int   # Demanda F3, Personal F5
func save() -> Dictionary        # estado + semilla
func load_state(d: Dictionary) -> void
# Invariante: TODA aleatoriedad de juego pasa por aqui (nadie usa randi() global).
# Garantia: misma semilla + misma secuencia de llamadas -> mismos resultados (determinismo).
```

**SaveManager** (autoload) + contrato `save()`/`load_state()`
```gdscript
func guardar(ruta := "user://savegame.save") -> bool
func cargar(ruta := "user://savegame.save") -> bool
# Cada sistema persistente implementa (patron, no herencia obligatoria):
#   func save() -> Dictionary
#   func load_state(d: Dictionary) -> void
# Invariante caller: Datos (catalogo) debe estar cargado antes de load_state.
# Garantia: tras cargar, el juego queda en Pausa y sin eventos retroactivos.
```

**Tiempo #1** — la fuente única del tiempo
```gdscript
# Lectura (pull):
func minutos_del_dia() -> int          # 0..1439
func turno() -> int                    # MANANA/TARDE/NOCHE
func es_de_noche() -> bool
func fecha() -> Dictionary             # { mes, semana, anio }
func esta_en_pausa() -> bool
var delta_juego: float                 # min de juego avanzados este physics-tick (0 si Pausa)
# Comandos (desde UI):
func set_velocidad(v: int) -> void     # 0=Pausa,1,2,3
# Invariante: nadie mas mantiene un reloj propio; todos leen de aqui (TR-time-007).
# Garantia: los eventos de cruce se emiten UNA vez y en orden determinista (TR-time-003/004).
```

**Datos #2** — el catálogo (solo lectura en runtime)
```gdscript
func obtener(tipo: StringName, id: StringName) -> Resource   # o Dictionary, segun ADR-0003
func obtener_todos(tipo: StringName) -> Array
func validar() -> Array[String]        # [] si OK; lista de warnings/errores si no
# Invariante caller: NUNCA mutar lo devuelto (es una plantilla compartida).
# Garantia: todo id referenciado existe (validado en carga); rangos clampados.
```

**Gates de Economía #3** — el guardián del gasto
```gdscript
func puede_pagar(coste: int) -> bool           # gate E4 (Construccion/Personal preguntan antes)
func cobrar(coste: int) -> void                # gasto voluntario (ya validado por puede_pagar)
func abonar(cantidad: int) -> void             # ingreso (lo llama al oir tramite_completado)
# Invariante caller: gasto voluntario solo si puede_pagar()==true.
# Garantia: los gastos obligatorios (nomina) pueden dejar saldo negativo (deuda); los voluntarios no.
```

**Flujo #4** — el motor de colas
```gdscript
func encolar(persona) -> void                  # lo llama Demanda via persona_generada
# Expone por bus: tramite_completado, abandono. Lee agente (Personal), aforo (Construccion), delta (Tiempo).
# Invariante: una Persona en "Llamada"/"En atencion" ya NO abandona (compromiso de servicio).
# Garantia: emparejamiento persona<->puesto automatico y determinista (desempate por menor id).
```

**Chequeo de motor (Fase 4):** todos los tipos usados están verificados para 4.6. Notas ⚠️: la UI (detalle
en `/ux-design`) debe contar con el **dual-focus** de 4.6 (ratón separado de teclado) y ser **ratón-first
sin hover-only**; `FileAccess.store_*` devuelve `bool`.

---

## Auditoría de ADRs + trazabilidad (Fase 5)

**Auditoría:** no existe ningún ADR previo en `docs/architecture/` → **los 4 son "ADR nuevo requerido"**.
Sin conflictos con decisiones anteriores (no las hay) ni incompatibilidades de motor (todo verificado
contra 4.6).

**Matriz de trazabilidad (cada requisito técnico tiene una ruta):**

| Destino | Requisitos técnicos cubiertos |
|---------|-------------------------------|
| **ADR-0001** (bus + tick + orden) | TR-bus-001/002, TR-time-001…006/009, TR-flow-004, TR-economy-001/002, TR-demand-001, TR-patience-002/003, TR-odac-002, TR-feedback-001 · **D1**, **D2** |
| **ADR-0002** (guardado + RNG) | TR-save-001/002/003, TR-time-008, TR-data-006, TR-flow-006, TR-staff (save+RNG), TR-construction-004, TR-patience-003/004, TR-demand-002, TR-ui-005 |
| **ADR-0003** (formato catálogo) | TR-data-001…005 |
| **ADR-0004** (rejilla + navegación 2D) | TR-construction-001/002/003, TR-flow-005 |
| **Diseño de sistema** (ya en GDD → stories, sin ADR) | TRs internos [SIM]: TR-flow-001/002/003, TR-economy-003/004, TR-staff-002, TR-doc-*, TR-odac-001, TR-patience-001, TR-ui-001…004, TR-feedback-002/003 |
| **Open Question de rendimiento** (spike, sin ADR) | TR-flow-005(PERF), TR-time-009(PERF), TR-feedback-003(PERF) |

**Cobertura: 100 % — 0 requisitos sin ruta.** Cada TR va a un ADR, o ya está especificado en su GDD (se
implementa en stories), o es una incógnita de rendimiento a validar con un spike.

---

## ADRs requeridos (Fase 6)

**🔴 Obligatorios ANTES de escribir código (Foundation):**
1. **ADR-0001 — Bus de eventos, tick de simulación y orden determinista.** Autoload+signals, dispatcher
   para el orden de handlers (D2), bucle de simulación en `_physics_process` (D1). *Base de toda la comunicación.*
2. **ADR-0002 — Guardado y serialización (JSON en `user://`) + RNG determinista.** Patrón
   `save()`/`load_state()`, serializar el estado del RNG, `Vector2i`→`[x,y]`. *Base del determinismo y la persistencia.*
3. **ADR-0003 — Formato del catálogo de datos (`.tres` Resource vs JSON).** Resuelve Datos Open Q#8.

**🟡 Antes de construir Construcción/Flujo:**
4. **ADR-0004 — Rejilla (`TileMapLayer`) + navegación 2D (`NavigationAgent2D`).**

**Aplazables:** ninguno crítico. El presupuesto de rendimiento no es un ADR → es un **spike** en el vertical
slice (QQ-02).

---

## Principios de arquitectura

1. **Data-driven, nunca hardcodeado** — todo valor de juego vive en el catálogo (Datos); el código lee por `id`.
2. **Determinismo por diseño** — toda aleatoriedad pasa por `RNGService` sembrado; la simulación corre en
   paso fijo (`_physics_process`); misma partida → mismo resultado.
3. **Desacople por bus de eventos** — los sistemas hablan por señales cross-system, no por referencias
   directas; la UI **lee y ordena, no muta**; la lógica nunca llama a la UI.
4. **Capas estrictas** — Presentation → Feature → Core → Foundation; nunca al revés.
5. **Cargar = situar, no reproducir** — se restaura el estado y se arranca en Pausa; sin eventos retroactivos.

---

## Open Questions (arquitectura)

| ID | Resumen | Prioridad | Se resuelve en |
|----|---------|-----------|----------------|
| QQ-01 | Formato del catálogo: `.tres` vs JSON | Media | ✅ RESUELTA — ADR-0003 (`.tres` Resource tipado) |
| QQ-02 | **Spike de rendimiento de navegación 2D** (docenas de NPCs a 60 FPS) — riesgo técnico nº1 del concepto | **Alta** | vertical slice / spike |
| QQ-03 | Semilla RNG: aleatoria por partida vs fija; cómo se serializa | Media | ADR-0002 |
| QQ-04 | ¿Separar el bucle de simulación en un ADR-0005 propio, o mantenerlo dentro de ADR-0001? | Baja | al escribir ADR-0001 |

---

## Sign-off del Technical Director (Fase 7b)

Gate **TD-ARCHITECTURE** aplicado como auto-revisión (modo LEAN → **LP-FEASIBILITY omitido**).

| # | Criterio | Resultado |
|---|----------|-----------|
| 1 | ¿Cada requisito técnico del baseline cubierto por una decisión? | ✅ Sí — trazabilidad 100 %, 0 gaps |
| 2 | ¿Dominios HIGH-risk del motor abordados o marcados como Open Question? | ✅ Sí — los HIGH-risk de 4.6 son 3D (no aplican); 2D verificados; rendimiento de nav → QQ-02 |
| 3 | ¿API boundaries limpios, mínimos e implementables? | ✅ Sí — 7 contratos tipados con invariantes y garantías |
| 4 | ¿ADR gaps de Foundation resueltos antes de implementar? | ⚠️ Identificados, no escritos — los 3 ADRs Foundation son el paso inmediato siguiente |

**Veredicto: APPROVED WITH CONDITIONS.** La arquitectura es técnicamente sólida y completa. **Condiciones:**
(a) escribir y aceptar ADR-0001/0002/0003 (Foundation) antes de la primera línea de código de gameplay;
(b) correr el spike de rendimiento de navegación (QQ-02) en el vertical slice antes de escalar el volumen de
NPCs. Ninguna es un defecto de la arquitectura: son el trabajo planificado que sigue.
