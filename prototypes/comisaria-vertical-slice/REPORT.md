# Vertical Slice Report — Comisario — 2026-07-22

> Prototipo desechable (`prototypes/comisaria-vertical-slice/`). El código de Producción se
> escribirá **desde cero** en `src/` — nunca importa de aquí. Este informe cierra la fase de
> Pre-Producción y habilita el paso a Producción.

## Pregunta de validación

> ¿Un jugador desde cero siente que *gestionar el flujo de ciudadanos por una Oficina de Denuncias,
> siendo subinspector,* es entretenido ~3–5 min, sin guía — y podemos construir ese bucle a un ritmo
> razonable? (**diversión** + **viabilidad**).

**Respuesta: SÍ a ambas partes.**

---

## Resumen ejecutivo — Veredicto: **PROCEED** ✅

El prototipo demuestra el **bucle central completo** de *Comisario* de punta a punta y valida que es
**divertido y construible**. Las decisiones de arquitectura (EventBus, RNG sembrado, simulación en paso
fijo, navegación 2D mesh, guardado diferido) se han ejercitado en la práctica y funcionan. El **riesgo
técnico nº1** (docenas de NPCs navegando a 60 FPS) queda **despejado con amplio margen**. Se recomienda
pasar a Producción y reimplementar desde cero usando este prototipo solo como referencia de diseño.

---

## Validación del bucle core

**Ciclo demostrado:** llega el ciudadano → coge sitio (asiento o cola con barandillas) → un agente en un
puesto le atiende (el trámite avanza con el reloj) → se cobra → el reloj y el ciclo día/noche mandan →
construyes puestos y asignas agentes con el presupuesto → cumples el objetivo → **asciendes**.

| Sistema (mínimo en el slice) | Estado |
|---|---|
| Tiempo (reloj, Pausa/1×/2×/3×, turnos, día/noche) | ✅ |
| Demanda (tasa + RNG sembrado; de noche solo denuncias) | ✅ |
| Flujo / cola (FIFO, asientos fijos + cola con barandillas + desborde) | ✅ |
| Datos (DNI + denuncia; tarifas por tipo) | ✅ |
| Construcción (puestos con presupuesto, rotación, borrar, barandillas construibles) | ✅ |
| Personal (3 agentes asignables; puesto sin agente = cerrado; salario diario) | ✅ |
| Economía (presupuesto, cobro por trámite, salarios, reembolso demolición) | ✅ |
| Espera / satisfacción (métrica de espera media) | ✅ (mínimo) |
| Objetivo → Ascenso (rangos, overlay, pausa) | ✅ |
| UI/HUD (compacto, modos de edición) | ✅ |

**Recortado a propósito (→ Producción, ya en los GDD):** 2 servicios separados Documentación/ODAC con sus
salas de espera; paredes/salas construibles de verdad; 13 tipos de denuncia; reclamaciones; dilemas de
influencia; ascenso completo (evaluación de jefes); arte real.

---

## Feel / sensación

- El bucle **"ves la cola crecer → construyes y asignas → la cola baja"** es legible y satisfactorio: el
  clásico *momento tycoon*. El jugador lo entendió y lo explotó sin guía.
- El **ciclo día/noche** cambia la afluencia y la oferta (de noche cierra el DNI) de forma perceptible.
- El **ascenso** da un remate y una razón para volver.
- **Señal fuerte de inmersión:** el jugador (principiante) pidió espontáneamente más realismo (rotar mesas,
  lado funcionario/ciudadano, cola en zigzag con barandillas, 2 salas, paredes…). Que imagine el juego real
  jugando a la maqueta es exactamente lo que un prototipo exitoso provoca.
- Arte placeholder (formas/colores): suficiente para validar; el arte real es trabajo de Producción.

---

## Hallazgos técnicos

- **Rendimiento (spike QQ-02): PASA HOLGADO.** Medido en headless (simulación pura, sin render/vsync):
  **80 NPCs → ~145 FPS · 150 NPCs → ~145 FPS.** El presupuesto de 60 FPS son 16,6 ms/frame; la simulación
  de 150 NPCs usa ~7 ms → margen amplio. Con render + vsync mantiene 60 sólido. **La navegación mesh
  (`NavigationServer2D`/`NavigationAgent2D`) NO es cuello de botella; el plan B `AStarGrid2D` NO es
  necesario.**
- **Motor:** Godot 4.6.stable.official, renderer **Compatibility** (`gl_compatibility`) — elegido para 2D
  (arranque seguro en Windows; `technical-preferences` lo autoriza).
- **Decisiones de arquitectura validadas en la práctica:** EventBus autoload + señales cross-system;
  RNGService sembrado; Tiempo en `_physics_process` (paso fijo → determinismo); navegación con el *gotcha*
  del 1er physics frame aplicado, avoidance OFF, colisión personas↔personas OFF / personas↔entorno ON;
  gate de gasto en Economía; construcción por rejilla con snap.
- **Aprendizajes técnicos (para Producción):**
  - `class_name` no se resuelve en headless "en frío" (sin abrir editor) → usar `preload(...).new()`.
  - `PackedVector2Array` con `Vector2(...)` no puede ser `const` → `var`.
  - `ColorRect` de fondo a pantalla completa con `mouse_filter = STOP` se traga los clics → `IGNORE`.
  - Las anclas de `Control` dentro de un `CanvasLayer` son poco fiables → posicionar a mano en `_process`.
  - Validar en headless (`--headless --quit-after N`) **antes** de abrir la ventana ahorra muchísimas
    iteraciones (0 errores de compilación garantizados antes de que el jugador mire).

---

## Velocity log

**Todo el vertical slice se construyó en 1 sesión (2026-07-22):**

- **Escalón 0** — Proyecto Godot inicializado (aislado en `prototypes/`) + autoloads Foundation
  (EventBus/RNGService/Tiempo) + HUD del reloj con velocidades y atajos. *(Verificado por el usuario.)*
- **Escalón 1** — Un ciudadano navega a un puesto (navegación real), es atendido, cobra y se va. *(Riesgo
  nº1 validado con 1 NPC.)*
- **Escalón 2** — Demanda + cola (asientos → zigzag), DNI + denuncia, métrica de espera. *(+ correcciones
  de feel del usuario: cola en fila/zigzag, puesto libera al terminar, sin empujones.)*
- **Escalón 3** — Construir puestos (fantasma, rejilla, rotación, lados funcionario/ciudadano) + colas con
  barandillas construibles + borrar/demoler + agentes asignables con salario.
- **Escalón 4** — Día/noche altera la oferta (DNI cierra de noche) + objetivo → ascenso (overlay).
- **Escalón 5** — Spike de rendimiento (test de estrés + FPS), medido: PASA.

**Ritmo:** muy alto — el bucle completo en una sesión. El método (Claude valida en headless y lanza la
ventana en segundo plano; el jugador solo mira/juega) mantuvo la iteración rápida pese a que los subagentes
de estudio estaban caídos (todo en el hilo principal).

---

## Próximos pasos recomendados

1. `/gate-check pre-production` → avanzar la etapa a **Production** (este REPORT es la evidencia de playtest
   con verdict PROCEED que pide el gate).
2. `/create-epics` (Foundation y Core) → un epic por módulo de arquitectura.
3. `/create-stories [epic]` → historias implementables por epic.
4. `/sprint-plan` → primer sprint con la velocidad observada.
5. **Producción reimplementa desde cero en `src/`** (nunca importa de `prototypes/`); el slice es solo
   referencia de diseño.

**Backlog capturado del slice para Producción** (además de lo ya en los GDD): 2 salas Doc/ODAC con sus
salas de espera · paredes/salas construibles (con colisión) · **barandillas como obstáculo de navegación**
(re-bake del navmesh al colocarlas — pedido por el jugador, diferido) · arte real (art bible) · 13 tipos de
denuncia · reclamaciones · dilemas de influencia · ascenso completo.

---

## Lecciones aprendidas

- Un prototipo throwaway con estándares relajados **pero respetando las capas de arquitectura donde importa**
  (determinismo, navegación real) produce un spike **representativo** y valida las decisiones técnicas de
  verdad.
- Con un jugador principiante muy involucrado, el mayor riesgo del slice fue el **scope creep** (pedir cada
  vez más realismo). Se gestionó re-anclando la idea **prototipo ≠ juego**: lo pulido se guarda para
  Producción, el prototipo solo valida.
- Si se repitiera: fijar antes y por escrito la lista de "esto es del prototipo / esto es de Producción"
  para que el jugador tenga el marco desde el principio.
