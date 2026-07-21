# Feedback y Juice

> **Status**: Reviewed (/design-review 2026-07-22 APPROVED)
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / art-director / audio-director / qa-lead — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" + Pilar 1 — "Realismo con alma"

## Overview

El sistema de **Feedback y Juice** es la capa que hace que la comisaría **responda**: escucha los **eventos** de
todos los sistemas (un trámite que se completa, alguien que abandona, la caja que entra, un ascenso) y dispara la
**respuesta sensorial** que los hace **legibles y satisfactorios** — un **número flotante** de +€ que sube sobre
la ventanilla, el **emote de ánimo** de un ciudadano, un **destello sobrio** al cumplir el objetivo, y el
**cambio de *mood*** ambiental según el estado de la jornada (mañana ajetreada y cálida, noche fría y quieta —
art bible §2). Es una capa **data-driven**: un **vocabulario de respuestas** (*evento → animación + color +
sonido + intensidad*) que **no posee** ningún dato de juego, solo **reacciona** a lo que los sistemas emiten y
**se apoya** en el HUD (#11) y en el art bible.

A nivel de diseño, es lo que separa un juego que *funciona* de uno que **se siente bien** (Pilar 2, "la
comisaría está viva"): sin él, las cifras cambian en silencio; con él, cada acción tiene **peso y respuesta** —la
satisfacción táctil del **tycoon** (números que suben, remates al lograr algo)— pero con la **contención** del
tono (Pilar 1, art bible §1.2: *"autenticidad contenida, no espectáculo"*). Tomamos la **estructura** de feedback
de los grandes tycoons (*Two Point Hospital*, *Prison Architect*) y le quitamos el **tono caricaturesco**: aquí
el juice es **sobrio, institucional y creíble**, nunca un parque de atracciones. Su regla de oro: **realzar sin
estorbar** — el feedback comunica, no tapa el trabajo ni satura.

## Player Fantasy

**La fantasía:** *"Mi comisaría responde: cada trámite, cada euro, cada decisión se nota — y se siente bien
llevarla bien."*

El jugador debe sentir un mundo **receptivo**. No basta con que las cifras cambien: quiere **verlas y oírlas**
cambiar. La emoción central es la **satisfacción de la buena gestión hecha tangible** — la cadencia de una
mañana redonda, con los trámites cerrándose uno tras otro, los **+€ subiendo** en ámbar sobre las ventanillas,
la sala en verde, y al cerrar la jornada el **remate sobrio** del objetivo cumplido: un instante de **orgullo
institucional** (art bible §2, "ascenso/logro"), no una fiesta de confeti.

Pero el feedback también **avisa**: el juice no es solo premio, es **información que se siente**. La cola que se
pone roja y **late**, el **golpe seco y apagado** de alguien que se marcha, el **frío** que cae sobre la sala al
entrar la noche — todo comunica **de un vistazo y de un oído** cómo va la partida, sin leer un número. Ese doble
canal (**recompensa + aviso**) hace la gestión **legible y con peso**.

**Referencias:** la sensación de que **"todo responde"** de los grandes tycoons (*Two Point Hospital*, *Prison
Architect*) y la **vida ambiental** de *Cities: Skylines*. **Tomamos** su estructura de respuesta; **evitamos**
su celebración caricaturesca — aquí el logro es **digno y contenido** (Pilar 1).

**Momento ancla:** última hora de una buena mañana. Un DNI se cierra: **+3,60 €** sube en ámbar y se desvanece;
el ciudadano sale con un **emote verde**. La barra del objetivo da su último tramo y suena un **acorde breve y
sobrio** — lo has logrado. Nada explota; solo **sabes**, con el cuerpo, que hoy has llevado bien tu comisaría.

## Detailed Design

### Core Rules

**Modelo general**
- **FB1. Data-driven:** escucha un **bus de eventos** (→ ADR de implementación); cada evento mapea a una
  respuesta en la tabla `vocabulario_feedback`. No posee datos de juego.
- **FB2. 4 canales:** (a) visual puntual · (b) audio · (c) ambiental/mood · (d) HUD (#11).
- **FB3. Doble propósito:** recompensa **y** aviso.

**Feedback puntual**
- **FB4. Números flotantes:** **+€ ámbar** sobre la ventanilla al `tramite_completado`, sube y se desvanece. Los
  **costes NO flotan** (se ven en HUD/balance) — decisión MVP.
- **FB5. Emotes de ánimo:** sobre la persona (cambio de umbral 🟢🟡🔴, desenlace satisfecho/abandona). Color art
  bible §4.
- **FB6. Pulse/destello sobrio:** cuando algo reclama atención (cola roja, saldo rojo, puesto sin agente).
  Contenido, no estroboscópico.
- **FB7. Remate de logro:** objetivo/ascenso → flourish sobrio (destello dorado + acorde breve). El "más grande",
  aún contenido.

**Feedback ambiental (art bible §2)**
- **FB8. Mood por estado** (tinte/iluminación global): MVP = **mañana** (cálido) · **noche** (frío azulado) ·
  **fracaso** (rojos, fluorescente parpadeante) · **menús** (sala de control). Transición suave. *(Dilema y
  ascenso = hooks → Influencia #16 / ascensos.)*
- **FB9. Vida ambiental mínima:** idle básico (la gente se mueve/espera) para que la sala "respire". Lo
  elaborado, post-MVP.

**Presupuesto y contención**
- **FB10. Anti-saturación (juice budget):** límite de efectos simultáneos; muchos eventos → priorizar/agrupar
  (críticos ganan; menores se agregan, p.ej. "+€ ×5"). Nunca tapar el trabajo.
- **FB11. Intensidad por importancia** (baja/media/alta) escala la respuesta; cotidiano discreto, grave notorio,
  **siempre sobrio**.
- **FB12. Accesibilidad:** nada crítico **solo** por color o solo por sonido (respaldo forma/icono/texto);
  **audio desactivable** sin perder info.
- **FB13. Respeta la Pausa:** el mood se congela; los puntuales en curso terminan suave; no se generan nuevos por
  tiempo.

**Vocabulario de feedback (semilla — evento → canales · intensidad):**

| Evento (dueño) | Canales | Intensidad |
|----------------|---------|:----------:|
| `tramite_completado` +€ (Economía/Flujo) | +€ flotante ámbar + cue suave | Baja |
| cambio de ánimo / abandono (Paciencia) | emote sobre persona; abandono = golpe seco apagado | Baja/Media |
| reclamación / **grave** (Paciencia) | icono hoja + toast HUD / pulse rojo + cue de aviso | Media / **Alta** |
| cola desbordada · hacinamiento (Flujo/Paciencia) | pulse rojo en la sala + deriva de mood a "fracaso" | Media/Alta |
| saldo en rojo (Economía) | HUD rojo + cue | Alta |
| contratar · colocar · demoler (Personal/Construcción) | pop visual + click sobrio | Baja |
| hora punta · evento estacional (Demanda/Doc) | toast + aviso ambiental sutil | Media |
| día ↔ noche (Tiempo) | transición de mood ambiental | Media |
| objetivo cumplido · ascenso (Objetivo/#18) | remate dorado + acorde | Alta |

> **Telegrafiar el origen (legibilidad del bucle Doc→ODAC):** cuando una `reclamacion` aparece en ODAC por el
> bucle de Paciencia (PS13: alguien abandonó **Documentación** y va a formalizarla), su toast/aviso **indica el
> origen** (p. ej. *"reclamación por espera en Documentación"*) — para que el jugador entienda **por qué** la
> cola de ODAC crece, en vez de percibirlo como una saturación inexplicable. *(Cierra el recomendado de la
> revisión de Paciencia #10.)*

### States and Transitions

- **Mood ambiental** ∈ {Mañana, Noche, Fracaso, Menús} (MVP) + {Dilema, Ascenso} como hooks futuros. Lo dispara
  el estado de juego (Tiempo día/noche, mala gestión, entrar en menús); transición **fade** suave.
- **Efecto puntual** ∈ {en cola, reproduciéndose, desvaneciéndose, terminado}; **pool con límite** (FB10) que
  descarta/agrega el excedente.

### Interactions with Other Systems

*(Feedback es **read-only**: escucha eventos, no envía órdenes.)*

| Sistema | Evento que escucha → respuesta |
|---------|--------------------------------|
| **Tiempo #1** | día/noche → **mood**; Pausa → congela |
| **Economía #3** | ingreso → **+€ flotante**; saldo rojo → aviso |
| **Flujo #4** | `tramite_completado` → +€; cola desbordada → pulse |
| **Paciencia #10** | ánimo/abandono/reclamación/hacinamiento → emotes/avisos/mood |
| **Personal #6** | contratar/ausencia → pop/toast |
| **Construcción #7** | colocar/mover/demoler → pop sonoro |
| **Documentación #8 / ODAC #9** | eventos de servicio/prioridad → toasts |
| **Demanda #5** | hora punta / estacional → aviso ambiental |
| **Objetivo / Ascensos #18** | logro → **remate** *(hook)* |
| **UI/HUD #11** | Feedback **resalta** elementos del HUD y dispara **toasts** (se apoya en su capa) |
| **Art bible / Audio** | *referencia* de mood/color (§2/§4) y cues (audio mínimo) |

## Formulas

> Feedback **no posee matemática de gameplay**; sus "fórmulas" son **curvas de temporización e intensidad** de
> la presentación. Todo es tuning de *feel*.

### F1 · Número flotante (+€): subida + desvanecimiento

`y(t) = y0 − v_subida × t` · `alpha(t) = 1 − (t / duracion_flotante)`

| Variable | Default | Descripción |
|----------|---------|-------------|
| `duracion_flotante` | 1.2 s | Cuánto vive el número antes de desaparecer |
| `v_subida` | ~30 px/s | Velocidad a la que asciende (easing suave) |

### F2 · Intensidad → parámetros de respuesta

| Intensidad | escala | duración | volumen | Uso |
|------------|:------:|:--------:|:-------:|-----|
| **Baja** | 1.0 | corta | bajo | Lo cotidiano (+€, pop de colocar) |
| **Media** | 1.15 | media | medio | Avisos (reclamación, hora punta) |
| **Alta** | 1.3 | mayor | mayor (aún **sobrio**) | Crítico/logro (saldo rojo, ascenso) |

### F3 · Juice budget (anti-saturación)

`efectos_activos ≤ max_efectos_simultaneos` · si se excede → descartar los de **menor intensidad** o **agregar**:
N eventos iguales dentro de `ventana_agregacion_ms` → un solo "**×N**".

| Variable | Default | Descripción |
|----------|---------|-------------|
| `max_efectos_simultaneos` | 12 | Techo de efectos puntuales a la vez |
| `ventana_agregacion_ms` | 400 | Ventana para fusionar iguales (p. ej. +€ ×N) |

### F4 · Transición de mood (crossfade)

`mood(t) = lerp(mood_anterior, mood_nuevo, clamp(t / duracion_transicion_mood, 0, 1))` — fade **suave**, sin cortes.

| Variable | Default | Descripción |
|----------|---------|-------------|
| `duracion_transicion_mood` | 1.5 s | Cuánto tarda el ambiente en pasar de un estado a otro |

## Edge Cases

- **Si llega una avalancha de eventos:** actúa el **juice budget** (F3) — se descartan los de menor intensidad o
  se **agregan** (+€ ×N); los **críticos** siempre pasan. Nunca se tapa el trabajo.
- **Si dos moods compiten** (p. ej. "fracaso" durante la "noche"): gana el de **mayor prioridad** (fracaso >
  noche > mañana > menús); no se mezclan tintes de forma ilegible.
- **Si el audio está desactivado:** todo feedback **crítico conserva su canal visual** (FB12) — no se pierde
  información por jugar en silencio.
- **Si un efecto apunta a un elemento que ya no existe** (la persona se fue, la ventanilla se demolió): el efecto
  **no se lanza / se cancela**, sin errores ni efectos "huérfanos".
- **Si el juego va a 2×/3×:** los efectos puntuales usan **tiempo real** (siguen legibles) y el budget **agrega
  más agresivamente**; el mood transiciona en tiempo real. *A alta velocidad, menos ruido, no más.*
- **Si coinciden un logro y un aviso grave** (objetivo cumplido + reclamación grave): **ambos** se muestran
  (información distinta), priorizados por intensidad; no se cancelan.
- **Si el rendimiento cae** (muchos efectos): **degradación elegante** — se recortan partículas/efectos
  secundarios antes que bajar de 60 FPS; el feedback esencial (números, avisos) se mantiene.
- **Si el `vocabulario_feedback` no tiene entrada para un evento:** simplemente **no hay feedback** para ese
  evento (sin crash); queda como hueco a rellenar, no como error.
- **Si el juego está en Pausa:** el mood y los efectos temporizados se **congelan**; al reanudar, continúan. No
  se generan nuevos por tiempo.
- **Guardado:** Feedback **no guarda estado** (es efímero); al **cargar**, arranca **sin efectos pendientes** y
  con el **mood** que corresponda al estado cargado.
- **Accesibilidad (daltónico):** ningún feedback crítico depende **solo** del color (respaldo
  forma/icono/texto/posición) — art bible §4.

## Dependencies

**Depende de (upstream — escucha sus eventos, read-only):**

| Sistema | Tipo | Eventos que escucha |
|---------|------|---------------------|
| **Tiempo #1** | Hard | día/noche (mood), pausa, velocidad ✅ GDD |
| **Economía #3** | Hard | ingreso (+€), saldo rojo ✅ GDD |
| **Flujo #4** | Hard | `tramite_completado`, cola desbordada ✅ GDD |
| **Paciencia #10** | Hard | cambio de ánimo, abandono, reclamación/grave, hacinamiento ✅ GDD |
| **Personal #6** | Soft | contratación, ausencia ✅ GDD |
| **Construcción #7** | Soft | colocar/mover/demoler ✅ GDD |
| **Documentación #8 / ODAC #9** | Soft | eventos de servicio, prioridad ✅ GDD |
| **Demanda #5** | Soft | hora punta, evento estacional ✅ GDD |
| **UI/HUD #11** | Hard | se **apoya** en su capa (toasts, resaltes del HUD) ✅ GDD |
| **Art bible** | Hard | mood (§2) y color semántico (§4) ✅ |
| **Objetivo / Ascensos #18 · Audio direction** | Soft | logro → remate; cues de audio *(hooks/futuros)* |

**Dependen de este sistema (downstream):**

| Sistema | Tipo | Qué recibe |
|---------|------|-----------|
| **El jugador** | — | percibe el *game feel* (no es un sistema) |
| *(Ningún sistema de juego)* | — | Feedback es la **capa final de pulido**: los sistemas **emiten** sus eventos igual, escuche Feedback o no |

**Consistencia bidireccional:** varios GDD ya nombran a **Feedback/Audio #12** como quien **sonoriza/realza** sus
eventos (Paciencia, Demanda, UI/HUD). Feedback **no posee** valores ni **emite órdenes**; solo reacciona. La
ambición del juice se ajusta a la **capa final** (recortable sin romper gameplay — Edge: degradación elegante).

## Tuning Knobs

### Knobs propios de Feedback y Juice

| Knob | Default | Rango seguro | Efecto | Owner |
|------|---------|--------------|--------|-------|
| `duracion_flotante` (F1) | 1.2 s | 0.6–2.5 | Vida del número +€ | Feedback |
| `v_subida_flotante` (F1) | 30 px/s | 10–60 | Velocidad de ascenso del número | Feedback |
| `max_efectos_simultaneos` (F3) | 12 | 4–30 | Techo del juice budget (anti-saturación) | Feedback |
| `ventana_agregacion_ms` (F3) | 400 | 100–1000 | Ventana para fusionar iguales (+€ ×N) | Feedback |
| `duracion_transicion_mood` (F4) | 1.5 s | 0.5–4 | Crossfade entre moods | Feedback |
| `escala_intensidad` (F2) | 1.0 | 0.5–1.5 | Escala global de la respuesta (baja=más sobrio) | Feedback |
| **`reducir_movimiento`** (accesibilidad) | off | on/off | Minimiza animaciones/parpadeos; los estados críticos pasan a **indicadores estáticos** (nunca se pierde info) | Feedback |
| **`reducir_parpadeo`** (fotosensibilidad) | off | on/off | Sustituye parpadeos por resaltes fijos | Feedback |
| **`audio_feedback`** / `volumen_feedback` | on / 0.8 | on-off / 0–1 | Cues de audio (desactivable sin perder info, FB12) | Feedback |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto en Feedback |
|------|-----------|--------------------|
| Paleta de mood por estado (§2) | Art bible | Tinte/iluminación de cada mood |
| Color semántico (§4: ámbar/verde/rojo…) | Art bible | Colores de números, emotes, pulses |
| Umbrales de ánimo (66/33) | Paciencia #10 | Cuándo cambia el emote de una persona |
| Definiciones de eventos | Cada sistema | Qué dispara cada respuesta |

**Interacciones entre knobs:** `max_efectos_simultaneos` × `ventana_agregacion_ms` gobiernan cuánto "ruido"
tolera la escena; `escala_intensidad` × `reducir_movimiento` marcan el **techo de sobriedad** (y la accesibilidad).

**Restricciones:** el juice **siempre sobrio** (Pilar 1); `reducir_movimiento`/`reducir_parpadeo`/audio-off
**nunca** deben eliminar información crítica (respaldo estático obligatorio, FB12); ningún efecto debe bajar de
**60 FPS** (degradación elegante).

## Visual/Audio Requirements

- **Estilo:** art bible §1–4 — **sobrio, institucional**; juice **contenido** (§1.2). Formas héroe = lo
  accionable; el resto se retira.
- **Números flotantes (+€):** **ámbar** (§4), tipografía de oficina; sube + desvanece (F1). Nada de monedas cartoon.
- **Emotes de ánimo:** iconos **sobrios** (✓ ⏳ ⚠ / cara neutra) sobre la persona, con **color + forma**
  (daltónico, §4).
- **Pulses/destellos:** halo/borde que **late** en rojo/ámbar sobre el elemento; **contenido**, no
  estroboscópico (respeta `reducir_parpadeo`).
- **Partículas:** **mínimas** (un leve brillo al colocar); nada de explosiones.
- **Mood ambiental** (art bible §2, vía CanvasModulate/luz): mañana cálida · noche fría azulada · fracaso rojos
  fluorescentes · menús sala de control. **Crossfade** suave (F4). ⚠️ verificar el **glow reworkeado de 4.6**
  para el dorado del ascenso / azul nocturno.
- **Remate de logro:** destello **dorado sobrio** + galón/placa iluminado (art bible §2 "ascenso/logro").
- **Audio (mínimo — preferencia fija):** biblioteca **corta** de cues sobrios — +€ (suave, sin *cha-ching*
  cómico), aviso (tono grave apagado), abandono (golpe seco), logro (acorde breve digno), clicks de UI. Mezcla
  **discreta**; todo **desactivable** (FB12). *(El ambiente de comisaría lo lleva el diseño de sonido general —
  futuro.)*

📌 **Asset Spec** — Tras el art bible (faltan §5–7), `/asset-spec system:feedback-juice` para números, emotes,
pulses, partículas y la lista de cues.

## UI Requirements

- Feedback **no tiene pantallas propias**: **decora** el mundo y el HUD (#11).
- **Opciones de accesibilidad** en la pantalla de **Ajustes** (parte de UI #11): `reducir_movimiento`,
  `reducir_parpadeo`, `audio_feedback`/`volumen_feedback`.

📌 **UX Flag — Feedback y Juice**: las opciones de accesibilidad de feedback se ubican en la pantalla de
**Ajustes**; se detallan con `/ux-design` junto al resto de UI en Pre-Producción.

## Acceptance Criteria

**Números y emotes (FB4–FB5, F1)**
- **AC-FB01** `[Integration]` — GIVEN `tramite_completado` (+3,60 €) THEN aparece un **+€ ámbar** sobre la ventanilla que sube y se desvanece en ~1,2 s.
- **AC-FB02** `[Integration]` — GIVEN una persona cruza el umbral 66 THEN su emote pasa de 🟢 a 🟡 (**color + forma**).
- **AC-FB03** `[Integration]` — GIVEN un abandono THEN emote de marcha + **golpe seco** (si audio on).

**Pulses, avisos, logro (FB6–FB7)**
- **AC-FB04** `[Integration]` — GIVEN `saldo<0` THEN el HUD financiero **late en rojo** + cue de alerta.
- **AC-FB05** `[Integration]` — GIVEN reclamación **grave** THEN pulse rojo + cue (intensidad **Alta**).
- **AC-FB06** `[Visual]` — GIVEN objetivo cumplido THEN **remate dorado sobrio** + acorde breve (sin confeti).

**Mood ambiental (FB8, F4)**
- **AC-FB07** `[Integration]` — GIVEN día→noche THEN el mood hace **crossfade a "noche"** (frío azulado) en ~1,5 s.
- **AC-FB08** `[Integration]` — GIVEN "fracaso" y "noche" a la vez THEN prevalece el de **mayor prioridad** (fracaso).

**Juice budget (FB10, F3)**
- **AC-FB09** `[Unit]` — GIVEN más de `max_efectos_simultaneos` (12) THEN se descartan/agregan; los **críticos pasan**.
- **AC-FB10** `[Unit]` — GIVEN 5 `tramite_completado` en <400 ms THEN se agregan en un "**+€ ×5**".

**Accesibilidad (FB12)**
- **AC-FB11** `[Integration]` — GIVEN `audio_feedback=off` THEN todo aviso crítico **conserva su canal visual**.
- **AC-FB12** `[Integration]` — GIVEN `reducir_movimiento=on` THEN los parpadeos pasan a **indicadores estáticos**, sin perder info.
- **AC-FB13** `[Unit]` — GIVEN modo daltónico THEN ningún feedback crítico depende **solo del color** (icono/forma/texto).

**Robustez, pausa, rendimiento (FB13, Edge)**
- **AC-FB14** `[Integration]` — GIVEN Pausa THEN el mood y los efectos temporizados se **congelan**; no se generan nuevos.
- **AC-FB15** `[Integration]` — GIVEN un efecto sobre un elemento inexistente THEN **no se lanza** (sin huérfanos/errores).
- **AC-FB16** `[Integration]` — GIVEN un evento sin entrada en `vocabulario_feedback` THEN **no hay feedback** (sin crash).
- **AC-FB17** `[Perf]` — GIVEN una avalancha de efectos THEN se **recortan secundarios** antes de bajar de **60 FPS**.
- **AC-FB18** `[Unit]` — GIVEN cargar partida THEN arranca **sin efectos pendientes** y con el **mood** del estado cargado.

## Open Questions

| # | Pregunta | Dominio | Cuándo se resuelve | Estado |
|---|----------|---------|--------------------|--------|
| 1 | **Valores semilla de *feel*** (`duracion_flotante 1.2`, `max_efectos 12`, `ventana_agregacion 400`, `duracion_transicion_mood 1.5`, `escala_intensidad`) — ¿satisfactorio sin saturar? | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Glow reworkeado en Godot 4.6** — verificar la nueva API antes de apoyar el dorado del ascenso / azul nocturno en glow (VERSION.md marca 4.6 HIGH risk) | Técnico (godot-specialist) | Fase de arquitectura / implementación | Abierta |
| 3 | **Biblioteca de audio**: qué cues exactos (+€, aviso, abandono, logro, clicks) y su fuente (crear/licenciar) | Audio direction (sin GDD aún) | Al diseñar audio / producción | Diferida |
| 4 | **Vida ambiental**: nivel exacto de idle en MVP vs post-MVP (el arte 2D es el mayor riesgo de esfuerzo del concepto) | Arte / playtest | Producción | Abierta |
| 5 | **Moods futuros** (dilema, ascenso — art bible §2): se activan al existir Influencia #16 y el sistema de ascensos | Influencia #16 / Ascensos #18 | Al diseñar esos sistemas | Diferida |
| 6 | **Remate de objetivo/ascenso**: qué evento exacto lo dispara y su intensidad (depende del sistema de objetivo/ascenso) | Objetivo / Ascensos #18 | Al diseñar el objetivo | Abierta |
| 7 | **Bus de eventos**: cómo emiten/escuchan los sistemas los eventos que consume Feedback (patrón de señales/bus) | Arquitectura (ADR) | Fase de arquitectura | Abierta |
