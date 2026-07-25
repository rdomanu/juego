# Retrospectiva: Sprint 2 — "La comisaría se construye y se llena (Core B)"

**Periodo**: 2026-07-24 → 2026-07-25 (ventana planificada hasta 2026-07-31)
**Generada**: 2026-07-25 · **Modo**: LEAN
**Veredicto**: 🏁 **Sprint completado al 100 % con 6 días de margen. CORE 5/5.**

> Primera retrospectiva del proyecto (el Sprint 1 se cerró sin una). La tabla de tendencia usa los
> datos del plan del Sprint 1 y del registro de sesión.

---

## Métricas

| Métrica | Planificado | Real | Delta |
|---------|-------------|------|-------|
| Tareas del sprint (C2-1…C2-7) | 7 | 7 | **0 — 100 %** |
| Stories implementadas | ~13-15 (6-7 Construcción + 7-8 Flujo) | **15** (7 + 8) | +0/+2 |
| Esfuerzo (sesiones) | ~2,7 estimadas · 2,5 disponibles | ~2 | **−0,7** |
| Días de calendario | 8 | **2** | −6 |
| Commits del sprint | — | 15 | — |
| Tests automáticos | — | **264 → 342** (+78) | — |
| Suites de test | — | 58 | — |
| Bugs encontrados | — | 8 (todos en demo con ventana) | — |
| Bugs escapados al cierre | 0 | **0** | 0 |
| Trabajo no planificado aceptado | 0 | **6 entregables** | +6 |
| Erratas de GDD cazadas y propagadas | — | 7 | — |

## Tendencia de velocidad

| Sprint | Tareas planificadas | Completadas | Tasa | Stories |
|--------|--------------------|-------------|------|---------|
| 1 | 5 (C1-1…C1-5) | 5 | 100 % | 14 |
| *(entre sprints)* | — | epic Personal | — | 7 |
| **2 (actual)** | 7 | 7 | **100 %** | **15** |

**Tendencia: creciente y sostenida.** Dos sprints seguidos al 100 % y cerrados con ~6 días de
adelanto sobre la ventana. La velocidad real (~7-8 stories por sesión de trabajo) se mantiene estable
entre sprints, lo que hace que las estimaciones en "sesiones" sean fiables — y conservadoras.

---

## Qué fue bien

- **La comisaría VIVE.** El objetivo del sprint ("el saldo sube por primera vez") se cumplió y se
  superó: hay ciudadanos entrando, esperando, siendo atendidos y pagando, con el layout construido a
  ratón por el jugador. Es el primer build que se parece a un juego y no a una demo técnica.
- **El bucle "ventana abierta → feedback → arreglo → re-verificar" es el acelerador del proyecto.**
  Los 8 bugs del sprint se encontraron ahí, ninguno en producción y ninguno escapó al cierre. Más
  importante: de esa mesa salieron **3 reglas de diseño reales** que ningún test habría sugerido
  (aforo de pie, "en camino no se tramita", horario de Documentación).
- **El riesgo técnico nº1 se disolvió.** Navegación 2D post-cutoff + docenas de NPCs: 0 incidentes de
  rendimiento, sin necesidad del plan B (`AStarGrid2D`). El spike QQ-02 del vertical slice hizo su
  trabajo meses antes.
- **Los tests cazaron 7 contradicciones del propio diseño** (F6 `floor` vs su tabla, AC-T26 con el
  turno equivocado, `tasa_base_odac` con dos valores, valle nocturno que no cuadraba con su fórmula…).
  Escribir el test **antes** convierte el GDD en algo verificable, no en literatura.
- **Determinismo intacto bajo dos enmiendas de diseño.** La prueba reina A-vs-B (partida guardada y
  recargada vs partida continua) siguió pasando después de meter camino real y horario — incluidas las
  tres recalibraciones del camino.
- **Documentación viva, no burocracia.** Cada enmienda del usuario acabó en su GDD con el *por qué*, y
  los datos compartidos entre sistemas quedaron registrados para que no vuelvan a divergir.

## Qué fue mal

- **El trabajo no planificado fue ~30 % del epic Flujo** y entró sin renegociar el plan: panel de
  personal, ventanilla TIE, 2 enmiendas de diseño, 3 calibraciones del camino, policías y rótulos
  visibles. Salió bien (el sprint tenía margen), pero fue suerte estructural, no gestión.
- **Un fallo de diseño invisible costó una demo entera**: los trámites TIE no tenían ventanilla que
  los atendiese, así que esos ciudadanos esperaban *para siempre* — el "misterio de las 22:00". No
  había ninguna alerta de "hay demanda de un servicio que nadie puede atender"; se descubrió mirando
  la pantalla.
- **Las erratas del GDD se acumularon hasta el final** (7 anotadas a lo largo de dos sprints, todas
  propagadas en la última tarea, C2-7). Vivían en el fichero de estado de sesión, que no es un backlog.
- **Dos bugs del mismo tipo se repitieron**: los NPCs pintados debajo de las salas (z_index) y los
  placeholders tragándose los clics eran ambos "capas de UI y mundo mal separadas". No hay todavía una
  regla escrita de orden de capas.
- **El feedback estético se está perdiendo.** El usuario cerró el sprint con *"hay que pulir cosas de
  diseño"* y no existe una lista donde apuntarlo: hoy se difumina en el fichero de sesión.

## Bloqueadores encontrados

| Bloqueador | Duración | Resolución | Prevención |
|---|---|---|---|
| Subagentes que se paraban a pedir aprobación (protocolo colaborativo) | Recurrente durante el epic Flujo | Relanzar con "plan YA APROBADO, no pidas aprobación"; luego el usuario ordenó trabajar en hilo principal | **Regla vigente: Opus 5 implementa y coordina en hilo principal**, sin delegar |
| `SendMessage` no funciona en este entorno | Puntual | Continuar un agente = lanzar uno nuevo con el plan pegado | Irrelevante con la regla anterior |
| Trámites TIE sin ventanilla capaz (nadie los atendía) | 1 demo | Ventanilla `tie_1` + 4º agente en el montaje inicial | Aviso de "demanda sin servicio capaz" (ver acción 2) |

## Precisión de las estimaciones

| Tarea | Estimado | Real | Variación | Causa probable |
|---|---|---|---|---|
| C2-5 (implementar epic Flujo) | 1,2 ses. | ~1,5 ses. | **+25 %** | 6 entregables no planificados del feedback en ventana |
| C2-2 (implementar epic Construcción) | 0,8 ses. | ~0,8 ses. | 0 % | Estimación limpia |
| C2-7 (erratas del GDD) | 0,1 ses. | ~0,1 ses. | 0 % | Creció en alcance (7 correcciones, no 4) pero no en tiempo |
| **Sprint completo** | 2,7 ses. | ~2 ses. | **−26 %** | Las tareas de cierre y documentación se estimaron altas |

**Precisión global: 3 de 4 tareas dentro de ±20 %.** El patrón es claro: **la implementación pura se
estima bien; lo que se desvía es el trabajo que nace de enseñar el juego** (feedback → arreglos). No es
un problema de estimar mejor, es una partida presupuestaria que falta.

## Análisis de carryover

Ninguno. Las 7 tareas se cerraron dentro del sprint y no hay nada arrastrado del Sprint 1.

## Deuda técnica

- TODO: **7** · FIXME: **0** · HACK: **0** — estable y bajo para 15 stories nuevas.
- **Deuda declarada y consciente** (no es descuido, está documentada y con dueño futuro):
  - Todo el visual es **andamio** → lo sustituye UI/HUD #11 tras `/ux-design`.
  - El **horario de Documentación vive provisionalmente en Flujo** → se muda a Documentación #8.
  - El **panel de personal** es un andamio con tecla P → lo sustituye la UI real.
- Riesgo a vigilar: si UI/HUD #11 se retrasa mucho, el andamio se vuelve "el diseño" por inercia.

## Seguimiento de acciones anteriores

No aplica — no hubo retrospectiva del Sprint 1. **Esta es la línea base.**

## Acciones para la próxima iteración

| # | Acción | Dueño | Prioridad | Fecha |
|---|--------|-------|-----------|-------|
| 1 | **Presupuestar el feedback**: cada epic con hito visible lleva una tarea explícita de "rondas de demo y ajustes" (~0,3 ses.), en vez de absorberlo en la implementación | Producer / hilo principal | **Alta** | Al planificar el Sprint 3 |
| 2 | **Aviso de "demanda sin servicio capaz"**: si llega un tipo de trámite que ningún puesto construido puede atender, avisar en el HUD en vez de dejar gente esperando eternamente | Flujo + UI | **Alta** | Sprint 3 |
| 3 | **Backlog de pulido visual** (`design/ux/pulido-backlog.md`): apuntar el feedback estético **cuando se dice**, con las palabras del usuario, para que llegue entero a `/ux-design` | Hilo principal | **Alta** | Antes de la próxima demo |
| 4 | **Erratas del GDD al momento**: cuando un test cace una discrepancia GDD↔código, corregir el GDD en esa misma story (coste marginal ~2 min) en vez de anotarla para el final | Hilo principal | Media | Continuo |
| 5 | **Regla escrita de capas**: documentar en el control manifest el orden de dibujo mundo/UI y el `MOUSE_FILTER_IGNORE` de los decorativos (los dos bugs repetidos del sprint) | Hilo principal | Media | Antes de la 1ª story de UI |

## Mejoras de proceso

1. **La demo en ventana pasa de "extra simpático" a gate obligatorio de todo hito visible.** Es donde
   aparecen los bugs y donde nacen las mejores reglas de diseño. Sin sign-off en ventana, un epic con
   parte visible no se cierra.
2. **Verificación dirigida en headless para la UI.** Montar la escena real, forzar el estado y leer los
   textos resultantes (lo que se hizo con el panel de personal) detecta errores que la suite no cubre y
   que sin eso solo se ven a ojo. Convertirlo en patrón para toda UI nueva.
3. **Una decisión de diseño del usuario se implementa y se propaga el mismo día** (código + GDD +
   registro). Las dos enmiendas de este sprint sobrevivieron intactas porque se documentaron con su
   *por qué*, no solo con su *qué*.

## Resumen

Sprint excelente: **7/7 tareas, 15 stories, 0 bugs escapados, 6 días de margen y la capa Core del MVP
cerrada al completo (5/5)**. El juego pasó de sistemas correctos-pero-invisibles a algo que se puede
enseñar y entender mirándolo.

**Lo más importante a cambiar**: dejar de tratar el feedback de las demos como trabajo "extra" que se
cuela en la implementación. Es la actividad de mayor valor del proyecto — de ahí salieron tres reglas
de diseño y ocho bugs — así que merece su propia línea en el plan, no el margen de otra tarea.
