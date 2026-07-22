# Interaction Pattern Library

> **Status**: In Design
> **Author**: usuario + ux-designer
> **Last Updated**: 2026-07-22
> **Template**: Interaction Pattern Library
> **Input**: Ratón (primario) + teclado (atajos mínimos). Sin gamepad, sin táctil (ver `technical-preferences.md`).

---

## Overview

Biblioteca de patrones de interacción de **Comisario**, consolidada de los GDD (Construcción #7, UI/HUD #11,
Flujo #4, Personal #6, ODAC #9, Tiempo #1, Feedback #12). Regla transversal: **ratón-first, sin acciones
solo-hover** — toda acción tiene un clic; el hover solo añade detalle opcional (mantiene abierta la puerta a
mando/táctil sin rediseñar). Accesibilidad: los estados se comunican con **color + icono/forma/texto**
(ver `design/accessibility-requirements.md`). Estos patrones son la referencia común para todas las
pantallas; los specs por pantalla los referencian por nombre en lugar de reinventarlos.

---

## Pattern Catalog

| # | Patrón | Categoría | Usado en |
|---|--------|-----------|----------|
| 1 | Paneo y zoom de cámara | Navegación | Vista de la comisaría (todas) |
| 2 | Dibujar sala por arrastre | Construcción | Modo Construcción (#7) |
| 3 | Preview fantasma | Feedback | Construcción, colocación (#7) |
| 4 | Colocar puesto/objeto | Construcción | Modo Construcción (#7) |
| 5 | Seleccionar y asignar agente | Input | Modo Asignación, Funcionarios (#6) |
| 6 | Modos sobre la vista | Navegación | Construcción / Asignación (#11) |
| 7 | HUD persistente + pestañas | Navegación | HUD, 5 tabs (#11) |
| 8 | Reconfigurar puesto ODAC | Input | Puesto ODAC (#9) |
| 9 | Control de velocidad del tiempo | Input | HUD (#1/#11) |
| 10 | Avisos (toasts) | Feedback | HUD (#11/#12) |
| 11 | Indicador de estado con respaldo | Data Display | Global (demanda, paciencia, prioridad) |
| 12 | Detalle al pasar el ratón (hover) | Overlay | Global (fichas, puestos, iconos) |

---

## Patterns

### 1. Paneo y zoom de cámara

**Categoría**: Navegación · **Usado en**: la vista de la comisaría (base de todas las pantallas de juego).

**Descripción**: mover y acercar/alejar la vista 2D top-down del edificio para inspeccionar salas, colas y puestos.

**Especificación**:
- **Paneo**: arrastrar (mantener botón y mover) o llevar el cursor a los bordes de la pantalla. `Camera2D`.
- **Zoom**: rueda del ratón (acerca hacia el cursor); límites de zoom para no perder contexto ni pixelar.
- **Feedback**: movimiento suave (en `_process`, tiempo real); el zoom respeta un mín/máx.
- **Accesibilidad**: no depende de hover; sin información crítica oculta por el nivel de zoom.

**Cuándo usar**: siempre que el jugador necesite recorrer el edificio.
**Cuándo NO**: en pantallas modales/paneles a pantalla completa (ahí no hay mundo que recorrer).

---

### 2. Dibujar sala por arrastre

**Categoría**: Construcción · **Usado en**: modo Construcción (#7).

**Descripción**: crear una sala de tamaño libre arrastrando un rectángulo sobre la rejilla.

**Especificación**:
- **Entrada**: pulsar en una celda (esquina A), arrastrar hasta la celda opuesta (esquina B), soltar para confirmar.
- **Durante el arrastre**: se resalta el rectángulo de celdas y se muestra el **coste por área en vivo** (F1).
- **Validación**: usa el **Preview fantasma** (patrón 3) — verde válido / rojo inválido (solapamiento o fuera de límites).
- **Cancelar**: `ESC` o botón derecho durante el arrastre.
- **Accesibilidad**: el coste y la validez se muestran con número + color + icono/texto, no solo por color.

**Cuándo usar**: crear/ampliar salas.
**Cuándo NO**: colocar un elemento puntual (usar patrón 4).

---

### 3. Preview fantasma

**Categoría**: Feedback · **Usado en**: toda colocación en Construcción (#7).

**Descripción**: un elemento semitransparente sigue el cursor mostrando **dónde** quedaría y **si es válido**, antes de confirmar.

**Especificación**:
- **Comportamiento**: fantasma pegado al cursor, ajustado a la celda (`local_to_map`/`map_to_local`).
- **Validez**: **verde** = válido / **rojo** = inválido (F6), **con icono/texto de respaldo** (daltónicos).
- **Confirmar**: clic (si es válido). **Cancelar**: `ESC`/botón derecho.
- **Accesibilidad**: nunca solo color — un icono ✓/✗ y/o texto acompaña al color.

**Cuándo usar**: cualquier colocación/dibujo en la rejilla.
**Cuándo NO**: acciones que no ocupan espacio en la rejilla (p. ej. cambiar una pestaña).

---

### 4. Colocar puesto/objeto

**Categoría**: Construcción · **Usado en**: modo Construcción (#7).

**Descripción**: situar un puesto o mueble puntual dentro de una sala.

**Especificación**:
- **Entrada**: elegir el tipo en la paleta → clic en la celda destino (con Preview fantasma).
- **Colocación**: `PackedScene` instanciada (`instantiate()`) posicionada con `map_to_local(celda)` — no es un tile.
- **Gate**: antes de confirmar, Economía valida el coste (`puede_pagar`); si no hay saldo, el fantasma indica "sin fondos".
- **Accesibilidad**: la paleta usa icono + etiqueta; el bloqueo por coste se comunica con texto, no solo color.

**Cuándo usar**: añadir puestos/objetos.
**Cuándo NO**: crear el volumen de una sala (usar patrón 2).

---

### 5. Seleccionar y asignar agente

**Categoría**: Input · **Usado en**: modo Asignación y pestaña Funcionarios (#6).

**Descripción**: consultar la ficha de un agente y asignarlo a un puesto.

**Especificación**:
- **Seleccionar**: clic en el agente (en el mundo o en la lista) → abre su ficha (atributos ⚡🤝❤️🔥 + 🎖️, con icono + texto).
- **Asignar**: clic en el agente y luego en el puesto, o arrastrar del uno al otro; el puesto válido se resalta (gate FL4).
- **Feedback**: confirmación visual de la asignación; un puesto incompatible se marca no-válido (color + icono/texto).
- **Accesibilidad**: los atributos se leen con estrellas + icono + texto; nada depende solo del color.

**Cuándo usar**: dotar puestos, revisar plantilla, contratar del mercado.
**Cuándo NO**: reconfigurar *qué atiende* un puesto (eso es el patrón 8).

---

### 6. Modos sobre la vista

**Categoría**: Navegación · **Usado en**: Construcción y Asignación (#11).

**Descripción**: activar un "modo" que cambia lo que hace el clic sobre el mundo (construir, asignar) sin salir de la vista de la comisaría.

**Especificación**:
- **Entrar**: botón de modo (Construcción/Asignación) en el HUD. El cursor/HUD indica claramente el modo activo.
- **Actuar**: dentro del modo, el clic hace la acción del modo (dibujar, colocar, asignar).
- **Salir**: `ESC` o volver a pulsar el botón de modo → vuelve al modo normal (inspección).
- **Accesibilidad**: el modo activo se señala con etiqueta de texto + icono, no solo con un cambio de color.

**Cuándo usar**: separar edición (construir/asignar) de la observación normal.
**Cuándo NO**: acciones puntuales que no cambian el significado del clic (usar botones directos).

---

### 7. HUD persistente + pestañas

**Categoría**: Navegación · **Usado en**: HUD y las 5 pestañas (#11).

**Descripción**: barra de estado siempre visible + navegación por pestañas a las pantallas de gestión.

**Especificación**:
- **HUD persistente** (`Control` + `CanvasLayer`): reloj/fecha, velocidad, saldo, satisfacción, objetivo, avisos.
- **Pestañas**: Comisaría · Funcionarios · Servicios · Valoraciones · Despacho del Comisario; clic para cambiar.
- **Desbloqueo por rango** (data-driven): las pantallas de rango superior no se muestran hasta desbloquearse (ni como "próximamente").
- **Accesibilidad**: pestaña activa marcada con texto/subrayado + color; respeta `escala_ui` sin recortar el HUD.

**Cuándo usar**: acceder a cualquier pantalla de gestión.
**Cuándo NO**: acciones contextuales sobre un elemento del mundo (usar clic directo / modo).

---

### 8. Reconfigurar puesto ODAC

**Categoría**: Input · **Usado en**: puesto ODAC (#9).

**Descripción**: cambiar en caliente qué tipo de denuncias atiende un puesto ODAC (4 modos).

**Especificación**:
- **Entrada**: clic en el puesto → menú contextual con los modos de atención admitidos (`atenciones_admitidas`).
- **Efecto**: cambia el conjunto que el puesto puede llamar; no rompe la atención en curso (compromiso de servicio).
- **Feedback**: el puesto muestra su modo actual con icono + etiqueta.
- **Accesibilidad**: los modos se distinguen por icono + texto, no solo color.

**Cuándo usar**: equilibrar prioridad/carga de ODAC como válvula manual.
**Cuándo NO**: asignar el agente al puesto (patrón 5).

---

### 9. Control de velocidad del tiempo

**Categoría**: Input · **Usado en**: HUD (#1/#11).

**Descripción**: pausar y ajustar la velocidad de la simulación.

**Especificación**:
- **Entrada**: botones Pausa / 1× / 2× / 3× en el HUD **y** atajos `Espacio` (pausa/reanudar), `1`/`2`/`3` (velocidades).
- **Efecto**: en Pausa la simulación se congela pero la gestión (construir, asignar, navegar UI) sigue disponible.
- **Feedback**: la velocidad activa se resalta (icono + texto); el estado de pausa es inequívoco.
- **Accesibilidad**: control por teclado disponible; nada depende solo del color del botón.

**Cuándo usar**: siempre disponible durante el juego.
**Cuándo NO**: en modales que ya pausan el juego (ahí el control queda inactivo).

---

### 10. Avisos (toasts)

**Categoría**: Feedback · **Usado en**: HUD (#11/#12).

**Descripción**: notificaciones no bloqueantes de eventos (trámite, abandono, reclamación, logro).

**Especificación**:
- **Comportamiento**: aparecen apilados en una zona fija; **máximo `max_avisos_visibles` (5)** a la vez; se desvanecen solos (~`duracion_toast` 4 s).
- **Acción**: clic en un aviso → lleva a su origen (p. ej. la cola de ODAC que crece); el aviso **telegrafía el origen** (ej. "reclamación por espera en Documentación").
- **No bloquean**: nunca interrumpen la partida (a diferencia de un modal como el rescate de insolvencia).
- **Accesibilidad**: icono + texto (no solo color); con `reducir_movimiento` (diferido) aparecerían sin animación.

**Cuándo usar**: informar de eventos sin exigir respuesta inmediata.
**Cuándo NO**: decisiones que exigen respuesta (usar un modal, p. ej. insolvencia o un dilema).

---

### 11. Indicador de estado con respaldo

**Categoría**: Data Display · **Usado en**: global (nivel de demanda, paciencia, prioridad de denuncia, ánimo).

**Descripción**: comunicar un estado/nivel de un vistazo, legible para cualquiera.

**Especificación**:
- **Forma**: semáforo o barra (verde→ámbar→rojo) **siempre con icono + texto** además del color; los umbrales son propios de UI (accesibilidad).
- **Ejemplos**: demanda BAJA/MEDIA/ALTA; paciencia de la cola; Prioritarias destacadas arriba en ODAC.
- **Accesibilidad**: **nunca solo color** (AC-UI22/AC-FB13); al bajar un estado crítico puede reforzar con parpadeo/opacidad (fijo si `reducir_movimiento`).

**Cuándo usar**: cualquier estado que el jugador deba leer rápido.
**Cuándo NO**: valores exactos que requieren cifra (mostrar el número directamente).

---

### 12. Detalle al pasar el ratón (hover)

**Categoría**: Overlay · **Usado en**: global (fichas, puestos, iconos, indicadores).

**Descripción**: mostrar información extra **opcional** al posar el cursor, sin que sea nunca la única vía.

**Especificación**:
- **Comportamiento**: al hover, aparece un tooltip/panel con detalle (desglose de un indicador, datos del puesto/agente).
- **Regla dura**: el hover **nunca** dispara acciones ni contiene información imprescindible — **toda acción y todo dato crítico también por clic** (sin hover-only).
- **Accesibilidad**: la misma info es alcanzable por clic (compatible con mando/táctil futuros); el tooltip respeta `escala_ui`.

**Cuándo usar**: enriquecer con detalle secundario.
**Cuándo NO**: como único medio para una acción o un dato necesario (viola la regla sin hover-only).

---

## Gaps & Patterns Needed

- **Modal de decisión** (rescate de insolvencia; futuros dilemas de Influencia #16): patrón bloqueante que exige respuesta. Esbozado en Economía/UI; se formalizará al diseñar su pantalla (spec dedicado) — fuera del alcance de esta biblioteca base.
- **Wireframes por pantalla**: esta biblioteca define *cómo se interactúa*; el layout concreto del HUD y de las 5 pestañas es de `hud.md` / specs por pantalla (ui-hud OQ1, pendiente).

## Open Questions

- **Autopausa al perder el foco de la ventana**: ¿on u off por defecto? (Tiempo OQ) → decisión de UX menor, a fijar en implementación de la UI.
- **Config de servicios híbrida** (ui-hud OQ3): ¿basta la reconfiguración contextual del puesto (patrón 8) o conviene duplicarla en la pestaña Servicios? → 1er playtest.
- **Valores de sensación** (`duracion_toast`, límites de zoom, velocidad de paneo): a afinar en el 1er playtest.
