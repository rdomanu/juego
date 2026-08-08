# Plan Maestro de UI — Comisario

> **Status**: Decidido — pendiente prompt aprobado
> **Author**: ux-designer
> **Last Updated**: 2026-08-07
> **Qué es esto**: el paso previo a encargarle el arte de UI a Summer con un prompt detallado. Aquí se
> decide **qué existe, dónde vive y por qué**, ANTES de dibujar nada. No es un spec por pantalla
> (`design/ux/[pantalla].md`) ni un GDD — es el mapa de arquitectura de información que los specs y el
> prompt de Summer van a citar.
> **Qué NO es**: no fija estilo visual final (art-director), no es el prompt de Summer (ver
> `design/ux/prompt-summer-ui.md`, redactado a partir de las decisiones de abajo), no reemplaza
> `design/gdd/ui-hud.md` (que ya fija las zonas a nivel de sistema — este documento las hereda y las baja
> a decisiones concretas de layout).

---

## 0. Decisiones tomadas (2026-08-07 — respuesta del usuario a la Sección 6)

| # | Pregunta | Decisión |
|---|----------|----------|
| 1 | Alcance del sistema de pestañas | **Sistema visual COMPLETO**, con identidad de **Policía Nacional Española** (azul CNP, guiños de placa) — no solo la barra de construcción |
| 2 | Personal/Horario: ¿modal o pantalla completa? | **Ventana flotante (modal)** para decisiones rápidas (Personal, Horario tal como son hoy); **pantalla completa** reservada para gestión compleja de niveles altos (futuro — Brigadas, Jefatura Superior…) |
| 3 | ¿Barra superior nueva? | **Sí** — información arriba (reloj/dinero/velocidad/satisfacción/objetivo), herramientas abajo (construcción) |
| 4 | ¿Bandeja de avisos entra ya en el arte? | **Sí** — se reserva sitio y se pide el asset en este mismo encargo, aunque el sistema de eventos/quejas no esté implementado todavía, **para no duplicar el pedido de arte más adelante** |
| 5 | Tono visual | **Tycoon simpático** (tipo *Two Point Hospital*), **NO** "dosier sobrio e institucional" |

**Nota de reconciliación (flag, no se edita aquí):** la decisión 5 **diverge** de lo que hoy dice
`design/gdd/ui-hud.md` §"Visual/Audio Requirements" (*"institucional, sobrio, tipo expediente/dosier"*) y
de la referencia de tono de `feedback-juice.md` (*"autenticidad contenida, no espectáculo"*). Es una
decisión de UX tomada explícitamente por el usuario en esta sesión; **no se reescribe el GDD desde aquí**
(fuera del alcance de este agente) — queda anotado para que `game-designer`/`art-director` concilien la
redacción del GDD con este tono en la próxima revisión.

---

## 1. Inventario funcional — qué tiene que servir la UI (presente y futuro)

Fuente: `design/gdd/systems-index.md`, GDDs referenciados, y el HUD provisional actual
(`src/main/modo_construccion.gd`, captura base de este análisis).

### A. Construcción (modo Construcción, UI8)

| Elemento | Detalle | Fuente |
|---|---|---|
| Salas | Dibujar por arrastre; catálogo con nombre+precio | `construction-layout.md`; patrón #2 (`interaction-patterns.md`) |
| Muebles/objetos | Colocación puntual; **obligatorios vs. opcionales** por sala (checklist) | `construction-layout.md`, `impresora-documentos-tramite.md` (patrón del asterisco) |
| Muros y suelos | Pintar pared/suelo, puerta, ventana | ya en código (`modo_construccion.gd`) |
| Zonas | Marcar sala de espera / oficina / puesto | ya en código |
| Herramientas | Demoler (con reembolso), rotar objeto (`R`), alternar modo (`B`) | `construction-layout.md`, UI8 |

### B. Gestión

| Elemento | Detalle | Fuente |
|---|---|---|
| Personal (`P`) | Plantilla, mercado, contratar/despedir, día libre | `staff-agents.md`, UI10 |
| Horario (`H`) | Slider de horario de Documentación + peonada | `documentation.md`, UI11 |
| Guardar/Cargar (`F5`/`F9`) | Sistema #20 (Guardado y Carga) | `pulido-backlog.md` U6 |
| Reconfigurar puesto ODAC | Contextual, clic derecho sobre el puesto | `odac.md`, patrón #8 |
| Asignar agente a puesto | Arrastrar agente → puesto | UI9, patrón #5 |

### C. Información permanente (debe estar siempre visible)

| Elemento | Detalle | Fuente |
|---|---|---|
| Reloj/fecha/velocidad | *Mes·Semana N*, ⏸/1×/2×/3× | `time-system.md`, UI1 |
| Saldo € + banda de color | 🔴/🟡/🟢 según `umbral_holgura_ui` | `economy-budget.md`, F1 |
| Satisfacción global | Banda 🔴/🟡/🟢 | `patience-satisfaction.md`, F3 |
| Progreso objetivo/ascenso | Barra de progreso | UI1/F4 *(hook — sistema de objetivo aún no cerrado)* |
| Demanda | Nivel BAJA/MEDIA/ALTA | `demand-generation.md` |
| Colas / plantilla | En cola por servicio, plantilla al completo/incompleta | `flow-queues.md`, `staff-agents.md` |

### D. Avisos / notificaciones (UI14, patrón #10)

| Elemento | Detalle | Fuente |
|---|---|---|
| Toasts | Hora punta, sala hacinada, saldo en rojo, reclamación (**grave** aparte), evento de la División, objetivo cumplido | UI14, `feedback-juice.md` (vocabulario) |
| Deep-link | Clic en el aviso → salta a su origen en el mundo | Patrón #10 |
| Telegrafiar origen | Ej. *"reclamación por espera en Documentación"* — para que el bucle Doc→ODAC se entienda | `feedback-juice.md` |
| Prioridad | **Crítico** (saldo rojo, reclamación grave) vs. **informativo** (hora punta, logro) — nunca tapan el juego | UI14, FB10/FB11 |

### E. Futuro conocido — la arquitectura debe soportarlo SIN rediseño

| Elemento | Detalle | Fuente | Estado |
|---|---|---|---|
| Niveles/tiers de comisaría (Usera…) | Más población/`tope_construible`/servicios activos | `data-config.md`, Escalado #26 | Full Vision |
| Impresora de documentos (viaje físico) | Sin cola de impresora en MVP; sí checklist obligatorio de sala (asterisco) | `impresora-documentos-tramite.md` | MVP (recién cerrado, sin UI aún) |
| Judicial / Detenidos y Abogados (#17) | Atestados, comparecencia, llamada a abogado | `systems-index.md` #17 | Vertical Slice |
| Presión e Influencia — dilemas (#16) | Modal de decisión bloqueante; peticiones especiales en Despacho del Comisario | UI13; gap ya anotado en `interaction-patterns.md` ("Gaps & Patterns Needed") | Vertical Slice |
| Valoración de jefes (#28) / Ascensos (#18) | Progreso de ascenso, ventana anual (enero) | `systems-index.md` | Vertical Slice |
| Fatiga / bienestar / motivación dinámica del funcionario | "Enfado"/fatiga sube con el trabajo, sala de descanso la baja | `systems-index.md` (nota "Fatiga, descanso y bienestar") — **sin GDD propio aún** | Vertical Slice |
| Brigadas (#19) y pantallas que cambian con el rango | P. ej. Jefatura Superior transforma el Despacho | UI5, `systems-index.md` #19 | Vertical Slice |

**Nota honesta:** no existe hoy un sistema cerrado llamado "tiers de ventanilla" — lo más parecido son (a)
los niveles de comisaría (`data-config.md`, tabla arriba) y (b) el checklist de objetos obligatorios por
sala (`impresora-documentos-tramite.md`). Se listan ambos para no inventar un tercero.

---

## 2. Arquitectura de información — qué va en cada zona y por qué

Punto de partida: `ui-hud.md` ya fija estas zonas a nivel de sistema (UI1/UI4/UI8/UI14); aquí se
concreta el layout y se explica el porqué de cada decisión.

| Zona | Contenido | Por qué |
|---|---|---|
| **Barra superior** (persistente, ancho completo) — ✅ **CONFIRMADA (decisión 3)** | Reloj/fecha/velocidad · saldo+banda · satisfacción global · objetivo · barra de pestañas (Comisaría/Funcionarios/Servicios/Valoraciones/Despacho) | UI1 los agrupa como "siempre visible" — hoy **no existe** como franja propia (todo vive abajo, ver captura base); centralizarlos arriba libera la barra inferior para que sea *solo* construcción, y es el patrón que citan las propias referencias del usuario (Two Point, Football Manager) |
| **Barra inferior** (solo visible en Modo Construcción, UI8) | Pestañas por categoría (Salas·Muebles·Muros y suelos·Zonas·Herramientas) + tarjetas de objeto con miniatura+precio | Progressive disclosure (Hick's Law): 20+ botones sueltos → 5 categorías + tarjetas contextuales. Reduce carga de decisión sin ocultar nada |
| **Dock de gestión** (esquina fija, siempre visible) | Personal (P) · Horario (H) · Guardar (F5) · Cargar (F9) — abren **ventana flotante (modal)** — ✅ **CONFIRMADO (decisión 2)** | Accesos de alta frecuencia y decisión rápida; NO se mezclan con la paleta de construcción (dominios distintos). La **pantalla completa** (plantilla aparte) queda reservada para gestión compleja de rango alto (Brigadas, Jefatura Superior — futuro, sin implementar aún) |
| **Bandeja de avisos** (lateral, apilable) — ✅ **ENTRA EN ESTE ENCARGO (decisión 4)** | Toasts con icono+color+texto, 3 niveles (info/aviso/crítico), máx. `max_avisos_visibles` (5), deep-link al pinchar | UI14; se pide el arte YA aunque el sistema de eventos/quejas no esté implementado, para no duplicar el encargo cuando llegue — el lateral no compite con la vista central del edificio ni con la barra de construcción |
| **Modales / paneles contextuales** | Ficha de agente, detalle de puesto/sala, reconfigurar ODAC | UI7; se abren sobre la vista, `Esc`/clic fuera cierra (ya es el patrón #8); comparten el mismo marco de **ventana flotante** que Personal/Horario |

**Cómo escala sin rediseño:**
- La barra de pestañas superior y el `registro_pantallas` ya son data-driven y desbloqueables por rango
  (UI5) → una pantalla nueva (Judicial, Jefatura Superior) es **añadir un registro**, no rehacer el layout.
- La barra de construcción lee su catálogo de Datos (#2) → una categoría nueva (si algún día hiciera
  falta) es **un dato**, no una categoría hardcodeada.
- La bandeja de avisos lee del `vocabulario_feedback` (data-driven, FB1) → un aviso nuevo (impresora
  atascada, funcionario enfadado) es **una entrada en el vocabulario**, no una zona nueva.
- El Despacho del Comisario ya reserva hueco para #16/#28 como secciones que **aparecen cuando su
  sistema existe** (UI13, Edge Case ya escrito) — nada que rediseñar cuando lleguen.

---

## 3. Principios de diseño (no negociables para el prompt de Summer)

- **Sencillo de interpretar**: cada zona tiene un trabajo, nunca dos cosas compitiendo por el mismo hueco.
- **Tono tycoon simpático** — ✅ **decisión 5**: referencia directa *Two Point Hospital*, NO el tono
  "dosier sobrio/institucional" que citaba `ui-hud.md` (ver nota de reconciliación en la Sección 0).
  Colores más vivos que la paleta base del juego se permiten en el **acento** de la UI (azul CNP), no en
  el escenario/mundo.
- **Ratón + teclado, sin mando ni táctil** (`technical-preferences.md`) — atajos como refuerzo, nunca
  única vía.
- **Sin interacciones solo-hover** (regla fija del proyecto) — todo lo crítico también por clic.
- **Paleta clara del juego**: base **BLANCA** (actualizado 2026-08-07, antes crema — ver
  `prompt-summer-ui.md`) + azul suave, coherente con la fachada/pintura ya resueltas.
- **Legible a 1600×900** (resolución de referencia de las capturas actuales) sin recortes ni scroll oculto.
- **Accesibilidad de fábrica** (`accessibility-requirements.md`): color + icono/forma/texto siempre; nada
  crítico parpadea sin aviso; layout responsivo con `escala_ui`.

---

## 4. Apéndice A — Inventario del Kenney UI Pack v2.0 (insumo, no vinculante)

Ruta: `capturas/fuentes/kenney_ui/extracted/` · Licencia **CC0 1.0** (`License.txt`, sin atribución obligatoria).

- **5 temas de color** (paletas de botón): Blue, Yellow, Red, Green, Grey — cada uno en **PNG y SVG**, en
  dos resoluciones (`Default` ≈1×, `Double` ≈2×).
- **Contenido por tema**: botones rectangulares/redondos/cuadrados en 5 acabados (flat, gloss, gradient,
  line, border), con y sin efecto "depth" (relieve pulsado); checkboxes cuadrados/redondos; sliders
  horizontales/verticales; flechas básicas/decorativas en 4 direcciones (+ variante pequeña); iconos
  básicos (check/cross/circle/square, normal y outline); estrellas de favorito (3 variantes); fuente
  **Kenney Future** (2 pesos, `.ttf`).
- **Lo que FALTA en este pack** (para el look "panel/marco" de un tycoon):
  - **Paneles/marcos de fondo (9-slice)** — no hay ninguno; solo botones y controles sueltos.
  - **Pictogramas temáticos** — no hay iconos de casa/silla/muro/zona/herramienta/candado/papelera para
    las categorías o estados; solo formas genéricas (check/cross/circle/square).
  - Ambos están disponibles gratis en otros packs UI de Kenney (CC0) de la biblioteca de Summer — a pedir
    cuando se redacte el prompt.
- **Ya cubierto sin arte nuevo**: las miniaturas de mobiliario pueden salir de sprites **reales** del
  juego ya existentes en `assets/sprites/mobiliario/` (archivador, cafetera, fuente de agua, sofá de
  descanso, taquilla, papelera, radio…) — no hacen falta placeholders para esas tarjetas.

---

## 5. Apéndice B — Wireframe conceptual de la barra de construcción (insumo, no vinculante)

Concepto (a validar/redibujar por Summer, no construido con Kenney):

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Construir (B) · Muebles → Cafetera (60 €) · clic coloca · Esc cancela   │  ← línea de estado
├───────┬─────────┬───────────────┬─────────┬───────────────┤   ⋮   ┌────┤
│ Salas │ Muebles*│ Muros y suelos│  Zonas  │ Herramientas  │       │Demo│  ← pestañas (icono+texto)
├───────┴─────────┴───────────────┴─────────┴───────────────┴───────┴────┤
│ ◀ [Archivador][Cafetera*][Fuente][Sofá][Taquilla][Papelera][Radio] ▶   │  ← tarjetas: miniatura+precio
└─────────────────────────────────────────────────────────────────────────┘
```

**Decisiones de diseño clave:**
- Pestañas grandes con icono + texto (nunca solo icono) — progressive disclosure, Hick's Law.
- Pestaña activa marcada con color **y** un indicador no-color (puntero/badge) — regla de accesibilidad.
- Tarjeta seleccionada con anillo/borde + badge, no solo un cambio de color de fondo.
- Estado "sin fondos" en una tarjeta: miniatura atenuada + banda de precio en rojo + icono de aviso —
  nunca solo el color de la banda.
- Paginación por flechas visibles (no solo scroll de rueda) — coherente con "sin hover-only".
- Acción "Demoler" anclada al borde derecho, siempre visible fuera de las pestañas (Fitts's Law: el
  borde de pantalla es el blanco más fácil de acertar; acción destructiva de alta frecuencia).

Existe un boceto de referencia (`ui_fotomontaje_barra.html`, con placeholders de Kenney + sprites reales)
hecho durante la exploración inicial — es **material de trabajo interno**, no la maqueta aprobada; el
encargo real de arte a Summer se redacta después de cerrar la Sección 6.

---

## 6. Preguntas para el usuario — ✅ RESPONDIDAS (2026-08-07, ver Sección 0)

*(Se conservan literales como registro; las respuestas están en la Sección 0 y ya se propagaron a las
secciones 2 y 3. El siguiente paso es `design/ux/prompt-summer-ui.md`.)*

1. **¿Entra ya la navegación por pestañas completa** (Comisaría/Funcionarios/Servicios/Valoraciones/
   Despacho, UI4) en este encargo de arte, o de momento solo se rediseña la barra inferior de
   Construcción y los accesos rápidos (P/H/F5/F9) siguen como están? — cambia si el prompt a Summer pide
   5 iconos de pestaña o solo los de construcción.
2. **Personal y Horario, ¿modal/panel rápido (como ahora) o pantalla completa dentro de las pestañas**
   (Funcionarios/Servicios)? — pregunta ya abierta en `ui-hud.md` (OQ3); hay que cerrarla porque un modal
   necesita marco de panel y una pantalla de pestaña necesita fondo completo (arte distinto).
3. **¿Añadimos ya una barra superior persistente** (reloj/dinero/velocidad/satisfacción/objetivo), que
   hoy no existe (todo vive abajo), o seguimos concentrando todo en la parte inferior por ahora?
4. **¿La bandeja de avisos (toasts) entra en este primer encargo de arte** (aunque el sistema de eventos
   aleatorios/quejas no esté implementado del todo), para reservarle sitio en el layout desde ya, o se
   deja fuera y se le hace hueco más adelante sin tocar el resto?
5. **Tono visual**: ¿"expediente/dosier" sobrio e institucional tal como pide `ui-hud.md` (colores
   apagados, sin cartoon), o algo más hacia el "tycoon simpático" (Two Point Hospital) que muestran las
   capturas de referencia del usuario? Es la decisión que más condiciona el prompt de Summer.
