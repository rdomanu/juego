# Requisitos de Accesibilidad — Comisario

> **Estado:** Definido · **Última actualización:** 2026-07-22 · **Alcance:** MVP
> **Motor:** Godot 4.6 (Control estándar + dual-focus 4.6; AccessKit disponible desde 4.5)

## Decisión de alcance (2026-07-22)

El MVP es una **validación jugable para el propio autor**, que de momento será el único jugador y
**no tiene necesidades de accesibilidad**. Por tanto, **no se invierte en features de accesibilidad
asistivas ni configurables en el MVP**. Se conservan únicamente las reglas de diseño que **también
mejoran la legibilidad para cualquier jugador y no cuestan trabajo extra** (ya están integradas en los
GDD como parte de cómo se dibuja la interfaz). El resto queda **diferido a post-MVP**, diseñado de forma
que se pueda añadir después sin rehacer. Resuelve la pregunta abierta **ui-hud OQ7** para el MVP.

> Esto no es un recorte de calidad: es **priorización**. Invertir en features asistivas antes de saber si
> el juego es divertido sería esfuerzo prematuro.

## Nivel comprometido para el MVP: "Legibilidad de fábrica"

### ✅ Se MANTIENE (coste cero, mejora la claridad para el propio jugador)

| Regla | Por qué se conserva (más allá de accesibilidad) |
|-------|--------------------------------------------------|
| **Nunca solo color** — los estados importantes (validez de colocación, nivel de demanda BAJA/MEDIA/ALTA, paciencia, prioridad de denuncia, atributos de agente) se comunican con **color + icono/forma/texto** | Se lee la pantalla **más rápido de un vistazo** — buen diseño de tycoon. Ya es regla en 10 GDD |
| **Todo por clic; sin acciones "solo-hover"** (el hover solo añade detalle opcional) | Deja la puerta abierta a **mando/táctil** sin rediseñar; evita interacciones frágiles |
| **Atajos de teclado básicos:** Espacio = pausa · 1/2/3 = velocidades | Comodidad de control; ya definido en Tiempo/UI |
| **Audio no imprescindible** — ninguna información crítica llega **solo** por sonido (audio mínimo, de refuerzo) | El juego se entiende con el audio apagado |

Estas reglas son **restricciones de diseño**, no funcionalidades aparte: se cumplen al construir la UI, no
añaden trabajo. Vinculan con `control-manifest.md` (capa Presentation) y con los AC de UI/Feedback
(AC-UI22, AC-FB13).

### ⏸️ DIFERIDO a post-MVP (no se implementa ahora; se diseña sin cerrar la puerta)

| Feature diferida | Cómo se deja la puerta abierta |
|------------------|-------------------------------|
| **Panel de opciones de accesibilidad** (`escala_ui`, `reducir_movimiento` como ajustes configurables) | En el MVP quedan con **valores por defecto fijos**; no se construye el panel. Los knobs ya existen en los GDD |
| **Remapeo de teclas** | Usar el **InputMap** de Godot para las acciones desde el principio → añadir remapeo luego es trivial |
| **Paletas de color para daltonismo** configurables | El **respaldo no-color de fábrica** (icono/forma/texto) ya cubre lo esencial |
| **Lector de pantalla / AccessKit** | Usar **nodos `Control` estándar** de Godot (integran AccessKit desde 4.5) → la base queda disponible si algún día se activa |

## Revisión

**Reconsiderar este alcance antes de cualquier publicación pública**, que ampliaría la audiencia más allá
del autor. En ese momento, promover las features diferidas según el público objetivo (baseline sugerido de
partida: WCAG-AA para la UI).

## Referencias

- `design/gdd/ui-hud.md` (UI2, AC-UI22, `escala_ui`, OQ7) · `design/gdd/feedback-juice.md` (FB12, AC-FB13, `reducir_movimiento`)
- `docs/architecture/control-manifest.md` (Presentation: ratón-first sin hover-only; dual-focus 4.6)
- Reglas de respaldo no-color presentes en: documentation, construction-layout, demand-generation, odac, flow-queues, staff-agents, patience-satisfaction.
