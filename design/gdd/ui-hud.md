# UI / HUD de Gestión

> **Status**: Designed
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / ux-designer / art-director — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-21
> **Last Verified**: 2026-07-21
> **Implements Pillar**: Pilar 4 — "Tu comisaría, tus decisiones" + Pilar 2 — "La comisaría está viva" + Pilar 1 — "Realismo con alma"

## Overview

El sistema de **UI/HUD de Gestión** es la **mesa de mando** desde la que el jugador ve y dirige toda la
comisaría. Es una **capa de presentación**: **no posee ningún valor de juego** —el saldo lo posee Economía, la
satisfacción Paciencia, las colas Flujo…—, sino que **lee** el estado y los eventos de todos los sistemas, los
**pinta** de forma legible, y **traduce** los clics en órdenes que envía al sistema dueño (contratar → Personal,
construir → Construcción, reconfigurar un puesto → ODAC, ajustar el horario → Documentación). Se organiza en dos
capas: un **HUD persistente** (siempre visible: reloj/fecha, velocidad, saldo, satisfacción, avisos) y
**paneles/modos contextuales** que se abren bajo demanda (construcción, personal, detalle de un puesto o una
persona). Todo lo que muestra lo **lee de config** (nombres, iconos, umbrales) — **nunca hardcodea** cifras.

A nivel de diseño, es el sistema que hace **jugable** todo lo demás (Pilar 4, "tus decisiones"): sin él, los
sistemas existen pero el jugador no puede leerlos ni actuar. Su trabajo es de **arquitectura de información**:
decidir qué está *siempre* a la vista (lo que necesitas para no perder: dinero, tiempo, colas que crecen) frente
a lo que se consulta *cuando hace falta* (el mercado de agentes, el detalle de una sala), y **avisar** de lo
urgente (hora punta, sala hacinada, saldo en rojo, evento de la División) sin saturar. Bien hecho, el jugador
**lee el estado de un vistazo y actúa sin fricción**; es también donde la comisaría **se ve viva** (Pilar 2:
gente con ánimo, puestos activos) con un estilo **sobrio de expediente/dosier** (Pilar 1) y **respaldo
daltónico** (nunca solo color).

## Player Fantasy

**La fantasía:** *"Estoy al mando en la mesa del subinspector: de un vistazo sé cómo va mi comisaría, y con un
clic entro en cualquier rincón de ella."*

El jugador debe sentirse **al mando** (Pilar 4). El HUD persistente le da el **pulso** de la comisaría sin
apartar la vista (hora, dinero, satisfacción, la cola que crece), y una **barra de pantallas tipo tycoon** le
deja **saltar entre las facetas de su mando** como quien abre las carpetas de su despacho: **Comisaría** (la
planta: construir y colocar), **Empleados** (contratar, ver a su gente), **Valoraciones** (cómo lo está
haciendo: satisfacción, reclamaciones, objetivo), **Despacho del Comisario** (dinero, la valoración de tus
jefes, las peticiones especiales que te llegan). Cada pantalla es un "departamento" de tu rol, y moverse entre
ellas es **fluido y sin fricción** — la interfaz no estorba, **desaparece** y deja ver el trabajo.

La emoción no es la de un menú aburrido, sino la del **control**: *"veo que Documentación está en rojo, entro,
abro una ventanilla, vuelvo a la vista general y sigo"*. **Referencias:** la gestión **limpia y por pestañas**
de *Two Point Hospital* y *Football Manager* (entras a cada faceta sin perderte) y los **menús de despliegue**
de *Prison Architect*. **Evitamos:** la UI recargada o el menú-laberinto; cada pantalla tiene **un trabajo
claro** y el HUD nunca miente ni satura (Pilar 1, sobrio).

Y como todo en el juego, estas pantallas **crecen con tu rango** (Pilar 3): ascender **desbloquea y transforma**
facetas —de un despacho de subinspector a la Jefatura Superior de la comunidad, con reuniones de jefes de
brigada— pero eso llega **con los ascensos** (#18/#19/#26); en el MVP el conjunto de pantallas es el **base**.

**Momento ancla:** un aviso rojo parpadea en el HUD ("sala hacinada"). Pinchas, saltas a la **vista de la
comisaría**, ves la cola de Documentación desbordada, entras en **Empleados**, arrastras un agente libre a la
segunda ventanilla y en dos clics vuelves a la vista general — la sala ya respira. *No has tocado una sola cifra
a mano: la interfaz hizo de puente.*

## Detailed Design

### Core Rules

**HUD persistente**
- **UI1.** Siempre visible: **barra superior** (reloj + fecha *Mes·Semana N* + velocidad ⏸/1×/2×/3× · **saldo €**
  + estado color · **satisfacción global** · progreso **objetivo/ascenso**) + **zona de avisos** + **barra de
  navegación de pantallas**.
- **UI2. Data-driven:** todo texto/icono/umbral se lee de config; la UI **nunca hardcodea** cifras/cadenas.
  **Respaldo daltónico** (color + icono/forma/texto, nunca solo color).
- **UI3. Solo lectura + órdenes:** la UI **no muta** estado; **lee** estado/eventos y **emite órdenes** al
  sistema dueño, que valida y aplica.

**Navegación por pantallas**
- **UI4. Tabs tycoon:** conmutan entre **Comisaría · Funcionarios · Servicios · Valoraciones · Despacho del
  Comisario** (una activa; el HUD persiste).
- **UI5. Registro data-driven y desbloqueable por rango (Pilar 3):** el set de pantallas es configurable; cada
  una puede estar bloqueada/desbloqueada por ascenso (MVP: las 5 base). Ascender **añade/transforma** pantallas
  (Jefatura Superior, reuniones de brigada — #18/#19/#26, futuro).

**Pantalla Comisaría (por defecto) + modos**
- **UI6. Vista Comisaría:** cenital; cámara **pan/zoom** (ratón); pinta puestos (estado), gente (**ánimo** por
  color), salas (ocupación/aforo).
- **UI7. Inspección contextual:** clic → panel con detalle y acciones: **puesto** (qué atiende, agente,
  throughput; ODAC: **reconfigurar prioridad**), **persona** (trámite, paciencia), **sala** (aforo, hacinamiento).
- **UI8. Modo Construcción** (toggle): dibujar salas, colocar puestos/objetos, demoler (reembolso); **presupuesto
  en vivo** + validación coste/saldo.
- **UI9. Modo Asignación** (arrastrar): un **funcionario** libre → un puesto (gate Flujo/Personal).

**Pantallas de gestión**
- **UI10. Funcionarios:** plantilla (atributos ⚡🤝❤️🔥/🎖️, estado, salario), **mercado de candidatos**
  (contratar), acciones (día libre, despedir), avisos del Oficial.
- **UI11. Servicios:** ajustes **globales** — **slider de horario de Documentación** (08:00–14:30 base → 20:00
  con **peonada**, última admisión) y nivel de demanda. *(Reconfigurar un puesto ODAC concreto = contextual, UI7.)*
- **UI12. Valoraciones:** satisfacción por servicio + global (**hoy vs cierre de ayer**), **reclamaciones**
  (jornada/mes, **graves** aparte), esperas, y el **objetivo de eficiencia** con progreso.
- **UI13. Despacho del Comisario:** resumen económico (balance del mes, préstamos/rescate), **valoración de
  jefes** (#28 — *hook MVP*), **peticiones especiales** (#16 — *hook*), progreso al **ascenso**.

**Avisos y pausa**
- **UI14. Zona de avisos:** hora punta, **sala hacinada**, **saldo en rojo**, evento de la División,
  **reclamación grave**, objetivo cumplido. Un aviso puede **deep-link** a la pantalla/elemento al pincharlo.
  Sobrios, no saturan.
- **UI15. Pausa navegable:** ⏸ congela el tiempo; la UI sigue usable (construir/planificar en pausa).

### States and Transitions

- **Pantalla activa** ∈ {Comisaría, Funcionarios, Servicios, Valoraciones, Despacho del Comisario} (+ futuras
  desbloqueables por rango). Cambio por clic en tab; el HUD persistente no cambia.
- **Sub-modo de Comisaría** ∈ {Inspección (default), Construcción, Asignación}. Toggle entre ellos; salir de un
  modo → vuelve a Inspección.
- **Panel contextual** ∈ {cerrado, abierto sobre un elemento}. `Esc` / clic fuera → cerrado.
- **Velocidad** ∈ {Pausa, 1×, 2×, 3×} (la posee Tiempo; la UI la refleja y la ordena). En Pausa la UI sigue
  navegable.

### Interactions with Other Systems

| Sistema | La UI **lee** (muestra) | La UI **envía** (orden) |
|---------|-------------------------|-------------------------|
| **Tiempo #1** | Reloj, fecha *Mes·Semana N*, velocidad | Cambiar velocidad, pausa |
| **Economía #3** | Saldo, estado, ingresos/gastos, balance mes | Pedir/saldar préstamo |
| **Flujo #4** | Colas, `numero_turno`, estado de puestos, `espera_estimada` | — (observa) |
| **Paciencia #10** | `sat` (servicio+global, hoy vs ayer), ánimo por persona, reclamaciones, hacinamiento | — (observa) |
| **Personal #6** | Plantilla, mercado, atributos, avisos del Oficial | Contratar, despedir, día libre, **asignar** a puesto |
| **Construcción #7** | Planta, presupuesto en vivo | Dibujar sala, colocar/mover/demoler puesto/objeto |
| **Documentación #8** | Horario, peonada, avisos División, demanda | Ajustar slider de horario / última admisión |
| **ODAC #9** | Colas por prioridad, reputación, config de puestos | **Reconfigurar** prioridad de un puesto |
| **Demanda #5** | Nivel de afluencia, hora punta, eventos | — (observa) |
| **Datos #2** | `nombre`/`icono` de cada definición | — (config) |
| **Ascensos #18 / Valoración #28 / Influencia #16** *(futuro)* | Valoración de jefes, peticiones, progreso ascenso | Aceptar/rechazar petición *(hook)* |

*(Provisional: #28/#16/#18 son hooks/placeholder en MVP. La UI **no posee** valores; todo lo lee de su dueño y
las órdenes las valida el sistema dueño.)*

## Formulas

> La UI **no posee fórmulas de gameplay**; solo **mapea** valores (propiedad de sus sistemas) a **bandas de
> color/estados de presentación**. Lo único propio son los **umbrales de color** (tuning de accesibilidad).

### F1 · Banda de color del estado financiero *(referenciada — dueño: Economía)*

`estado_color = 🔴 si saldo<0 · 🟡 (justo) si 0≤saldo<umbral_holgura_ui · 🟢 (holgado) si saldo≥umbral_holgura_ui`

| Variable | Rango | Origen |
|----------|-------|--------|
| `saldo` | € | Economía |
| `umbral_holgura_ui` | 500 € | Economía (ya en registro) |

### F2 · Color de ánimo por persona *(referenciada — dueño: Paciencia)*

`ánimo = 🟢 si paciencia>66 · 🟡 si 33≤paciencia≤66 · 🔴 si paciencia<33` — umbrales de **Paciencia PS5**.

### F3 · Banda de color de satisfacción *(umbrales propios de UI — accesibilidad)*

`banda_sat = 🔴 si sat<umbral_sat_bajo · 🟡 si umbral_sat_bajo≤sat<umbral_sat_alto · 🟢 si sat≥umbral_sat_alto`

| Variable | Default | Origen |
|----------|---------|--------|
| `umbral_sat_bajo` | 40 | **UI** (tuning) |
| `umbral_sat_alto` | 70 | **UI** (tuning) |

### F4 · Progreso de objetivo/ascenso *(display)*

`progreso_% = clamp(valor_actual / objetivo, 0, 1) × 100` — `valor_actual`/`objetivo` los posee el sistema de
**objetivo de eficiencia/ascenso**; la UI solo pinta la barra.

## Edge Cases

- **Si una pantalla/faceta pertenece a un rango superior** (p. ej. **Brigadas** es de Comisario): **no aparece
  en absoluto** siendo Subinspector — ni tab con candado ni "próximamente". Se **revela** al alcanzar el rango
  que la abre (UI5, Pilar 3: revelación progresiva). *No se teasea lo que no te toca.*
- **Si una faceta pertenece a un sistema aún no construido** (p. ej. valoración de jefes #28, peticiones #16):
  simplemente **no se muestra** su sección; aparece cuando su sistema exista. Sin "próximamente".
- **Si un dato real está vacío o a cero** (0 candidatos, 0 reclamaciones aún, sin jornada cerrada): se muestra
  el **estado vacío** claro ("no hay candidatos ahora", "0", "—" / "sin datos"), nunca un panel en blanco.
- **Si un valor sale fuera de rango** (saldo/sat): la **banda de color clampa** (F1/F3) y el número se muestra
  tal cual; la UI no rompe.
- **Si el jugador ordena algo inválido** (contratar sin dinero, construir sobre ocupado, asignar a puesto lleno):
  el **sistema dueño lo rechaza**; la UI muestra el **motivo** (tooltip/toast) y **no aplica nada**. *(La UI
  nunca decide por su cuenta: solo propone la orden.)*
- **Si llegan muchos avisos a la vez:** se **apilan/agrupan** con un límite visible + cola; nunca tapan el juego.
  Los no accionables caducan solos.
- **Si un aviso deep-linkea a un elemento que ya no existe** (la sala se demolió): el aviso se **descarta** con
  un "ya no disponible", sin saltar a la nada.
- **Si se cambia de pantalla con un panel contextual abierto:** el panel se **cierra** al cambiar de tab.
- **Si se redimensiona la ventana:** layout **responsivo** (anclas); el HUD no se corta ni solapa.
- **Si el juego está en Pausa:** la UI sigue **navegable**; las órdenes **instantáneas** (construir, asignar —
  según sus GDDs) **se aplican**; solo el **tiempo de juego** no corre.
- **Si el jugador es daltónico:** todo estado lleva **icono/forma/texto** además del color (UI2) — ninguna
  información depende solo del color.
- **Guardado:** la UI **no guarda estado de juego** (lo poseen los sistemas); sí recuerda **preferencias de UI**
  (última pantalla, posición de cámara). Al **cargar**, arranca en **Pausa** y en la vista **Comisaría**.

## Dependencies

**Depende de (upstream — lee su estado/eventos y le envía órdenes):**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Tiempo #1** | Hard | reloj, fecha *Mes·Semana N*, velocidad ↔ ordena velocidad/pausa ✅ GDD |
| **Economía #3** | Hard | saldo, estado, balance ↔ ordena préstamo ✅ GDD |
| **Datos #2** | Hard | `nombre`/`icono`/etiquetas de cada definición (config) ✅ GDD |
| **Flujo #4** | Hard | colas, `numero_turno`, estado de puestos, `espera_estimada` ✅ GDD |
| **Paciencia #10** | Hard | `sat` (servicio+global, hoy vs ayer), ánimo, reclamaciones, hacinamiento ✅ GDD |
| **Personal #6** | Hard | plantilla, mercado, atributos ↔ ordena contratar/despedir/día libre/**asignar** ✅ GDD |
| **Construcción #7** | Hard | planta, presupuesto ↔ ordena dibujar/colocar/mover/demoler ✅ GDD |
| **Documentación #8** | Hard | horario, peonada, avisos División ↔ ordena ajustar horario ✅ GDD |
| **ODAC #9** | Hard | colas por prioridad, reputación ↔ ordena **reconfigurar** puesto ✅ GDD |
| **Demanda #5** | Soft | nivel de afluencia, hora punta, eventos (observa) ✅ GDD |
| **Ascensos #18 / Valoración #28 / Influencia #16** | Soft | valoración de jefes, peticiones, progreso ascenso *(hooks — sistemas futuros; se **ocultan** hasta existir)* |

**Dependen de este sistema (downstream):**

| Sistema | Tipo | Qué recibe |
|---------|------|-----------|
| **Feedback y Juice #12** | Hard | se apoya en la UI: añade juice (animaciones, sonido, énfasis) sobre los eventos/elementos que la UI presenta |
| **UX specs** (`/ux-design`) | — | las pantallas de este GDD se detallan por pantalla en Pre-Producción (7 flags UX confluyen aquí) |

**Consistencia bidireccional:** todos los GDD de gameplay ya listan **"UI/HUD #11"** como dependiente ✅
(Tiempo/Economía/Datos/Flujo/Demanda/Personal/Construcción/Documentación/ODAC/Paciencia). La UI **no posee**
ningún valor; es la capa de presentación final.

## Tuning Knobs

### Knobs propios de UI/HUD

| Knob | Default | Rango seguro | Efecto | Owner |
|------|---------|--------------|--------|-------|
| `umbral_sat_bajo` / `umbral_sat_alto` (F3) | 40 / 70 | 0–100 | Bandas de color de la satisfacción (🔴/🟡/🟢) | UI |
| `max_avisos_visibles` | 5 | 3–10 | Cuántos avisos a la vez antes de encolar (anti-saturación) | UI |
| `duracion_toast_seg` | 4 | 2–10 | Cuánto dura en pantalla un aviso no accionable | UI |
| `escala_ui` | 1.0 | 0.8–1.5 | Escalado de texto/UI (**accesibilidad**) | UI |
| `zoom_min` / `zoom_max` | 0.5 / 2.0 | — | Límites de zoom de la cámara en la vista Comisaría | UI |
| `velocidad_pan_camara` | — | — | Sensibilidad del paneo con ratón | UI |
| `registro_pantallas` | 5 base | — | **Lista data-driven** de pantallas + su **rango de desbloqueo** (UI5, Pilar 3) | UI / Ascensos |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto en la UI |
|------|-----------|-----------------|
| `umbral_holgura_ui` (500 €) | Economía #3 | Umbral "justo/holgado" del estado financiero (F1) |
| Umbrales de ánimo (66 / 33) | Paciencia #10 (PS5) | Color de ánimo por persona (F2) |
| `nombre` / `icono` de cada definición | Datos #2 | Etiquetas y símbolos de puestos/trámites/agentes |

**Interacciones entre knobs:** `max_avisos_visibles` × `duracion_toast_seg` definen cuánto "ruido" tolera el
HUD; `escala_ui` × la resolución condicionan cuánto cabe en el HUD persistente sin recortar (Edge Case de
redimensión).

**Restricciones:** `umbral_sat_bajo < umbral_sat_alto`; `escala_ui` no debe recortar el HUD; el
`registro_pantallas` respeta el desbloqueo por rango (nada de rango superior visible).

## Visual/Audio Requirements

- **Estilo (art bible):** institucional, **sobrio**, tipo **expediente/dosier**; legible; **daltónico** (color +
  icono/forma/texto, nunca solo color).
- **Iconografía consistente** por sistema (⏱ tiempo, € dinero, 😊 satisfacción, 📄 reclamaciones, 🪑 puestos,
  👮 funcionarios) — un lenguaje visual único.
- **Estados por color + forma:** bandas de saldo/sat, ánimo por persona; **avisos urgentes** con parpadeo
  **sobrio** (no alarmista).
- **Transiciones** de pantalla **rápidas y suaves** (no estorban).
- **Audio (mínimo):** clicks de UI discretos + un cue **sutil** para avisos críticos (saldo rojo, reclamación
  grave). Los **eventos de juego** los sonoriza **Feedback #12**; la UI solo sus propias interacciones. Sin
  sonoridad recargada.

📌 **Asset Spec** — Tras el art bible, `/asset-spec system:ui-hud` para HUD, iconografía y bandas de color.

## UI Requirements

*(Este GDD **es** el sistema de UI; aquí se fija el **layout a nivel de zonas**; el detalle por pantalla lo
produce `/ux-design`.)*
- **HUD persistente:** barra superior (reloj/fecha/velocidad · saldo/estado · sat global · objetivo) · **zona de
  avisos** (esquina, apilable) · **barra de tabs**.
- **Pantallas** (Detailed Design): **Comisaría** (default, con modos Construcción/Asignación e inspección
  contextual) · **Funcionarios** · **Servicios** · **Valoraciones** · **Despacho del Comisario**.
- **Interacción:** ratón (clic, arrastrar, pan/zoom); **sin hover-only** (toda acción por clic). Atajos
  opcionales (pausa = espacio, velocidad = 1/2/3).
- **Responsivo** (anclas); respeta `escala_ui`.

📌 **UX Flag (fuerte) — UI/HUD de Gestión**: las **7 flags UX** ya emitidas (Construcción, Datos, Documentación,
Economía, ODAC, Paciencia, Flujo) **confluyen aquí**. En Pre-Producción, `/ux-design` **por pantalla** citando
este GDD; las historias de UI citan `design/ux/[pantalla].md`, no el GDD directamente.

## Acceptance Criteria

**HUD y data-driven (UI1–UI3)**
- **AC-UI01** `[UI]` — GIVEN el juego en marcha THEN el HUD persistente muestra reloj, fecha *Mes·Semana N*, velocidad, saldo, sat global y avisos, **siempre visible**.
- **AC-UI02** `[Unit]` — GIVEN un texto/umbral en config WHEN cambia THEN la UI lo refleja **sin recompilar** (no hardcode).
- **AC-UI03** `[Integration]` — GIVEN una orden de la UI (contratar) THEN la UI **no muta** estado; el sistema dueño valida y aplica **o rechaza con motivo**.

**Navegación y pantallas (UI4–UI5)**
- **AC-UI04** `[UI]` — GIVEN 5 tabs WHEN se clica una THEN se activa esa pantalla y el HUD **persiste**.
- **AC-UI05** `[Integration]` — GIVEN una pantalla de rango superior (Brigadas) y rango Subinspector THEN **NO aparece** (ni candado ni "próximamente").
- **AC-UI06** `[Integration]` — GIVEN un ascenso que desbloquea una pantalla THEN **aparece** en la barra de tabs.

**Comisaría y modos (UI6–UI9)**
- **AC-UI07** `[UI]` — GIVEN vista Comisaría WHEN pan/zoom con ratón THEN la cámara se mueve dentro de `zoom_min/max`.
- **AC-UI08** `[UI]` — GIVEN clic en un puesto THEN se abre el panel de inspección con su detalle/acciones.
- **AC-UI09** `[Integration]` — GIVEN modo Construcción WHEN se dibuja una sala que excede el saldo THEN se **rechaza con motivo**, sin aplicar.
- **AC-UI10** `[Integration]` — GIVEN modo Asignación WHEN se arrastra un funcionario a un puesto válido THEN Personal/Flujo lo **asigna**.

**Pantallas de gestión (UI10–UI13)**
- **AC-UI11** `[UI]` — GIVEN Funcionarios THEN muestra plantilla + mercado; contratar sin dinero → **rechazo con motivo**.
- **AC-UI12** `[UI]` — GIVEN Servicios THEN el slider de horario de Doc **ajusta la ventana** y muestra la peonada.
- **AC-UI13** `[UI]` — GIVEN Valoraciones THEN muestra sat (**hoy vs cierre ayer**), reclamaciones (jornada/mes, graves) y progreso del objetivo.
- **AC-UI14** `[Integration]` — GIVEN Despacho y #28/#16 **no construidos** THEN esas secciones **no se muestran** (ocultas, sin "próximamente").

**Color, avisos, pausa, guardado (F1–F4, UI14–UI15)**
- **AC-UI15** `[Unit]` — GIVEN saldo −10 / 300 / 800 THEN 🔴 / 🟡 / 🟢 (F1, umbral 500).
- **AC-UI16** `[Unit]` — GIVEN paciencia 70 / 50 / 20 THEN 🟢 / 🟡 / 🔴 (F2).
- **AC-UI17** `[Unit]` — GIVEN sat 30 / 55 / 80 THEN 🔴 / 🟡 / 🟢 (F3, umbrales 40/70).
- **AC-UI18** `[UI]` — GIVEN más de `max_avisos_visibles` avisos THEN se **apilan/encolan**; los no accionables caducan.
- **AC-UI19** `[Integration]` — GIVEN un aviso deep-link a una sala demolida THEN se **descarta** ("ya no disponible").
- **AC-UI20** `[Integration]` — GIVEN Pausa THEN la UI sigue **navegable** y las órdenes instantáneas se aplican; el tiempo **no corre**.
- **AC-UI21** `[Unit]` — GIVEN cargar partida THEN arranca en **Pausa** y vista **Comisaría**; recuerda preferencias de UI, **no** estado de juego.
- **AC-UI22** `[UI]` — GIVEN modo daltónico THEN cada estado lleva **icono/forma/texto** además del color.

## Open Questions

| # | Pregunta | Dominio | Cuándo se resuelve | Estado |
|---|----------|---------|--------------------|--------|
| 1 | **Layout/wireframe concreto de cada pantalla** (HUD, 5 tabs, paneles) — este GDD fija zonas; el detalle es de UX | UX (`/ux-design`) | Pre-Producción | Abierta |
| 2 | **Registro de pantallas por rango**: qué pantalla desbloquea/transforma cada ascenso (Jefatura Superior, Brigadas…) | Ascensos #18 / Brigadas #19 / Comisarías #26 | Al diseñar esos sistemas | Diferida |
| 3 | **Config de servicios híbrida**: ¿basta la reconfiguración ODAC contextual, o conviene duplicarla en la pantalla Servicios? | UX / playtest | 1er playtest MVP | Abierta |
| 4 | **Valores semilla de UI** (`umbral_sat` 40/70, `max_avisos_visibles` 5, `duracion_toast` 4, `escala_ui`, zoom) — ¿legibles y cómodos? | UX / playtest | 1er playtest MVP | Abierta |
| 5 | **Objetivo de eficiencia**: qué muestra exactamente la barra de progreso y su fórmula (depende del sistema de objetivo/ascenso) | Objetivo/Ascensos #18 | Al diseñar el objetivo | Abierta |
| 6 | **Peticiones especiales #16** en el Despacho: ¿modal, cola, con temporizador? Cómo se presenta el dilema | Presión e Influencia #16 | Al diseñar #16 | Diferida |
| 7 | **Accesibilidad**: ¿remapeo de teclas / modo daltónico configurable / lector de pantalla en MVP o después? | Accesibilidad | Pre-Producción / playtest | Abierta |
