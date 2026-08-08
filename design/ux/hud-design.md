# HUD Design — Comisario (reconstrucción total)

> **Status**: Spec cerrada — implementable sin decisiones pendientes
> **Author**: ux-designer
> **Fecha**: 2026-08-08
> **Nota de nombre de archivo**: `design/CLAUDE.md` cita `design/ux/hud.md` como ruta canónica del
> HUD; este documento se llama `hud-design.md` por encargo explícito de esta tarea. Es EL plano del
> HUD (sustituye a cualquier boceto anterior); si en el futuro se quiere alinear el nombre con la
> convención, es un `git mv`, no un rediseño.
> **Reemplaza**: todo el HUD provisional de `src/main/main.gd` (`_crear_hud`, `ALTO_BARRA_HUD`,
> reloj/velocidad/saldo/demanda/personal/colas que hoy viven abajo) y cualquier barra superior a
> medias ya empezada. **NO toca** `src/main/modo_construccion.gd` (barra de construcción, tecla B) —
> se usa tal cual, solo se reubica la franja de acciones que vive justo encima de ella.
> **Tono**: tycoon simpático (referencia *Two Point Hospital*), decisión ya cerrada en
> `design/ux/plan-maestro-ui.md` §0. **Kit**: `assets/ui/kit/` + `assets/ui/theme_comisario.tres`
> (Kenney Future, un solo peso — sin variante bold, ver §1.4). Sin arte nuevo: todo lo de abajo se
> construye con las piezas ya entregadas.

---

## 0. Resumen ejecutivo (léelo si solo vas a leer una sección)

- **Arriba**: una sola franja de 52px, fondo `barra_superior_fondo.png`, con 7 grupos de datos en fila
  (reloj+turno · velocidad · saldo · satisfacción+reclamaciones · demanda+llegadas · plantilla+nómina ·
  Documentación) + 140px reservados a la derecha para la brújula de depuración. El módulo de
  "objetivo" (`barra_superior_modulo_objetivo.png`) **ya existe pero NO entra en esta versión** — el
  sistema de objetivo/ascenso no está cerrado (ver §0 nota).
- **Abajo**: dos franjas apiladas. La de más abajo es la barra de construcción (sin tocar, tecla B).
  Justo encima, una franja nueva de 60px, siempre visible, con 5 píldoras de acción alineadas a la
  derecha: Personal(P) · Horario(H) · Guardar(F5) · Cargar(F9) · Paredes(Home).
- **Nunca solo color**: todo estado usa color + palabra/glifo, reutilizando la convención ya asentada
  en los GDD del proyecto (🔴🟡🟢, ⏸▶▶▶) — no hace falta arte nuevo para esto.
- **Objetivo/ascenso**: fuera de alcance de esta versión (arte reservado, ver §1.3).

---

## 1. Barra superior

### 1.1 Estructura general

- **Contenedor**: `Panel` con `theme_type_variation = "BarraSuperior"` (ya existe en el theme,
  `assets/ui/theme_comisario.tres` línea 269 — `StyleBoxTexture` de `barra_superior_fondo.png`).
- **Anclaje**: `PRESET_TOP_WIDE`, `grow_vertical = GROW_DIRECTION_END`, altura fija **52px**
  (referencia de uso ya pedida a Summer en `prompt-summer-ui.md` Pieza 1: *"altura de referencia ~52
  px de uso"*). Ancho completo de la ventana.
- **Fila interna**: `HBoxContainer` dentro de un `MarginContainer` (margen 12px izquierda, 8px arriba/
  abajo, 0px derecha — el margen derecho lo controla el spacer de §1.2) — mismo criterio de
  `MarginContainer` que protege el `content_margin` del 9-slice (ver memoria de este agente,
  `feedback_margen_contenido_manual_children`).
- **Separación entre grupos**: 8px normal, **16px** entre "familias" distintas (después de Velocidad,
  después de Saldo, después de Documentación) — agrupación por proximidad (Gestalt), ayuda a leer la
  fila de un vistazo sin marco visual extra.
- **Altura de cada chip/módulo**: 40px, centrado verticalmente en la franja de 52px (6px de aire arriba
  y abajo).

### 1.2 Los 7 grupos, en orden, con ancho fijo

| # | Grupo | Ancho | Fondo | Icono |
|---|-------|------:|-------|-------|
| 1 | Reloj · fecha · turno | 150px | `barra_superior_modulo_reloj.png` (9-slice) | ya dibujado en el módulo (reloj+estrella) |
| 2 | Velocidad (Pausa/1×/2×/3×) | 135px | `barra_superior_modulo_velocidad.png` (9-slice) | ya dibujado (⏸ ▶ ▶▶) + 1 píldora añadida |
| 3 | Saldo + estado | 145px | `barra_superior_modulo_saldo.png` (9-slice) | ya dibujado (insignia/placa) |
| 4 | Satisfacción + reclamaciones | 155px | ninguno (fondo plano de la barra) | `icono_queja.png` (28px) |
| 5 | Demanda + llegadas hoy | 140px | ninguno | `icono_velocimetro.png` (28px) |
| 6 | Plantilla + nómina | 140px | ninguno | `icono_personal.png` (28px) |
| 7 | Documentación (cola/atendiendo/puerta) | 155px | ninguno | `icono_carpeta.png` (28px) |
| — | *(spacer elástico, `SIZE_EXPAND_FILL`)* | resto | — | — |
| — | Reserva brújula de depuración | 140px | — | — |

**Suma de contenido a 1280px** (ancho mínimo soportado): 12 (margen izq.) + 150+135+145+155+140+140+155
(chips) + separaciones (8×3 + 16×3 = 72) + spacer mínimo + 140 (brújula) + 12 (margen der.) ≈ 1232px de
contenido fijo → **48px de margen de seguridad** a 1280px antes de recortar nada. A resoluciones mayores
(1600×900 es la de referencia del proyecto) el spacer absorbe todo el ancho extra: los chips **no**
crecen, no se re-centran, no cambian de tamaño — evita que el texto salte de línea de forma impredecible
al redimensionar.

**Por qué el módulo de Objetivo no entra**: el sistema de objetivo/ascenso sigue con una pregunta
abierta en `design/gdd/ui-hud.md` (OQ5, "qué muestra exactamente la barra de progreso"). Meter el
módulo ahora con datos inventados violaría la regla del propio GDD ("si un sistema no existe, su
sección no se muestra" — Edge Case de `ui-hud.md`). El arte ya está pagado y aprobado; se integra en
cuanto el sistema de objetivo cierre su spec, en el mismo hueco (justo antes de la reserva de brújula),
sin tocar nada de lo demás.

### 1.3 Contenido de cada grupo

**[1] Reloj · fecha · turno** (150×40, sobre el módulo reloj)
- Línea 1 (grande): hora `HH:MM`, fuente 15px, color navy `#1C3352` (= `COLOR_TEXTO_PRINCIPAL` del
  theme, `Color(0.11,0.2,0.32,1)`), alineado a la izquierda del hueco de texto del módulo (el icono
  reloj+estrella ya viene dibujado a la izquierda, ocupa ~34px).
- Línea 2 (pequeña): fecha+turno compacto, fuente 10px, mismo navy al 70% (reutilizar
  `COLOR_TENUE_HUD_CLARO` ya definido en `main.gd`, `Color(0.11,0.2,0.32,0.65)` — no inventar un color
  nuevo). Formato: `"Sem N · Turno T"` (usa `Tiempo.semana` + `Tiempo.turno_de(...)`, ver §5).
- `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` + `clip_contents = true` en la línea 2 por si el
  texto no cabe (mismo patrón que `spec-tarjetas-2026-08-08.md`).

**[2] Velocidad** (135×40, sobre el módulo velocidad — LEE ANTES DE IMPLEMENTAR, hay un ajuste)
- El PNG trae **3** círculos ya dibujados (⏸ / ▶ / ▶▶) pero el juego tiene **4** estados
  (`Tiempo.Velocidad`: PAUSA/X1/X2/X3). Decisión: los 3 círculos existentes mapean a Pausa/1×/2× tal
  cual (el doble-chevron = "acelerado" cubre 2×); se añade una **4ª píldora pequeña** (28×28,
  `PildoraSecundaria`/`PildoraPrimaria` del theme según esté activa o no) inmediatamente a la derecha
  del módulo con el texto `"3×"` (fuente 11px) — no hace falta arte nueva, la píldora ya existe y a
  ese tamaño se ve como un botón redondo más de la misma familia.
- **Indicador de activo** (nunca solo color, y los 3 círculos son UNA sola imagen plana sin estado
  "pulsado" propio): un triángulo pequeño (▾, glifo de texto navy 8px, o un `Polygon2D` de 6×4px) bajo
  el círculo/píldora actualmente seleccionado — **mismo lenguaje visual** que ya se pidió para la
  pestaña activa de construcción (`prompt-summer-ui.md` Pieza 2: *"pequeño puntero/triángulo en el
  borde inferior"*), así que es coherencia, no un patrón nuevo.
- Los 3 círculos y la píldora son 4 `Button`/`TextureButton` con `flat = true` (sin fondo propio,
  transparentes) posicionados encima de sus zonas del PNG — el PNG es decorativo, el clic lo dan los
  controles reales.

**[3] Saldo + estado** (145×40, sobre el módulo saldo)
- Línea 1 (grande): `"1.240 €"`, fuente 16px (el mayor tamaño de toda la barra — el dato más
  importante del juego). Color navy normal; si `saldo < 0`, color rojo `Color(0.75,0.2,0.18,1)` (el
  mismo rojo que ya usa `TarjetaObjeto/colors/font_disabled_color` en el theme — reutilizar, no
  inventar un rojo nuevo) **+ contorno navy 1px** (`font_outline_color` + `outline_size = 1`) — el
  fondo del módulo es khaki/crema claro y un rojo saturado sin contorno ronda el 4:1 de contraste
  (insuficiente para texto normal, aceptable con el contorno de refuerzo, mismo criterio que la nota
  de WCAG ya registrada en la memoria de este agente sobre ámbar-sobre-crema).
- Línea 2 (pequeña, 10px): la palabra de estado — `"Holgado"` (saldo≥`umbral_holgura_ui`, verde) /
  `"Justo"` (0≤saldo<umbral, ámbar) / `"Negativo"` (saldo<0, rojo) — el texto ES el respaldo no-color
  (F1 de `ui-hud.md`, la UI no posee el umbral, lo lee de Economía).

**[4] Satisfacción + reclamaciones** (155×40, fondo plano — sin módulo de arte)
- `icono_queja.png` a la izquierda (28×28, círculo blanco+navy ya viene así de fábrica).
- Línea 1: banda de color + texto, ej. `"🟢 Satisfacción 72%"` — reutiliza literalmente el vocabulario
  de bandas ya definido en `ui-hud.md` F3 (🔴/🟡/🟢, umbrales `umbral_sat_bajo`/`umbral_sat_alto`); el
  emoji-círculo es el mismo patrón de respaldo no-color que usan los propios GDD del proyecto (no es
  un icono nuevo, es texto).
- Línea 2: `"Reclamaciones: 3 (1 grave)"` — si `reclamaciones_graves_jornada > 0`, esta línea en rojo +
  negrita simulada (ver §1.4, no hay peso bold real); si es 0, se omite el paréntesis.

**[5] Demanda + llegadas hoy** (140×40, fondo plano)
- `icono_velocimetro.png` a la izquierda (28×28) — encaja bien semánticamente con un nivel de
  intensidad (mismo patrón #11 de `interaction-patterns.md`, semáforo con respaldo de texto).
- Línea 1: `"Demanda: ALTA"` (texto del nivel, `Demanda.nivel_demanda()`, ya viene en `StringName`
  legible tipo BAJA/MEDIA/ALTA — sin inventar traducción).
- Línea 2: `"Llegadas hoy: 24"` (`Demanda.llegadas_hoy`).

**[6] Plantilla + nómina** (140×40, fondo plano)
- `icono_personal.png` a la izquierda (28×28).
- Línea 1: `"Plantilla: 8/10"` (agentes libres+cubriendo / plantilla total, o el criterio que ya usa el
  panel de Personal — no se inventa un cálculo nuevo aquí, se reutiliza el que exponga `Personal`).
- Línea 2: `"Nómina: 640 €/día"` (suma de `Personal.salario_dia(agente)` de la plantilla, ya calculable
  con lo que expone `personal.gd`).

**[7] Documentación (cola/atendiendo/puerta)** (155×40, fondo plano)
- `icono_carpeta.png` a la izquierda (28×28).
- Línea 1: `"Doc: 5 en cola"` (`Flujo.personas_en_cola(&"documentacion")`, o el `StringName` real del
  servicio en `Datos`).
- Línea 2: `"2 atendiendo · Puerta 07"` — el campo "puerta" (número de turno que se está llamando/
  mostrando en la entrada de Documentación) **no está localizado en este análisis** (no aparece un
  getter claro en `flujo.gd`/`documentacion.gd` con ese nombre) — ver hueco marcado en §5, a confirmar
  con quien implemente antes de cerrar el binding real. Si no existe ese dato hoy, la línea 2 se
  reduce a `"2 atendiendo"` sin bloquear el resto del HUD (Edge Case: dato vacío → se omite el
  fragmento, nunca un hueco en blanco ni un placeholder roto).

### 1.4 Tipografía — nota dura

`assets/fonts/kenney_future.ttf` es un **único peso** (no hay variante bold en `assets/fonts/`). La
jerarquía visual (número principal vs. etiqueta secundaria) se hace con **tamaño** (15-16px vs. 10-11px)
y **opacidad/color** (navy 100% vs. navy 65% vía `COLOR_TENUE_HUD_CLARO`), nunca con negrita real. Si en
algún punto se quiere simular negrita, usar `font_outline_size` pequeño (1px) del mismo color que el
relleno — efecto "más grueso" barato, ya usado en el proyecto (`_preview_texto` en
`modo_construccion.gd` usa outline). No se pide una fuente bold nueva para este spec — de necesitarse,
es una pieza de asset aparte con su propio OK de gasto, fuera de este documento.

### 1.5 Colores medidos de los PNG (aproximados — a ojo, no con cuentagotas)

| Elemento | Color aprox. | Uso |
|---|---|---|
| Fondo barra / módulos claros | `#FAFAF8`–`#FFFFFF` | fondo general, texto navy encima |
| Módulo reloj | `#D3E6F5` (azul pastel) | fondo chip 1 |
| Módulo velocidad | `#BFE0DE` (verde-azulado pastel) | fondo chip 2 |
| Módulo saldo | `#EDE3AC` (crema/khaki) | fondo chip 3 |
| Módulo objetivo *(reservado, no usado aún)* | `#DCD3EE` (lavanda pastel) | — |
| Navy CNP (texto/iconos) | `#1C3352` (= theme `Color(0.11,0.2,0.32,1)`) | todo texto/icono por defecto |
| Rojo crítico | `#BF332E` (= theme `Color(0.75,0.2,0.18,1)`) | saldo negativo, reclamación grave |
| Borde/pie navy de la barra | `#1D3557` aprox. | borde inferior de `barra_superior_fondo.png` |

Todos los fondos medidos son **pastel claro** → texto navy por defecto tiene contraste alto de fábrica
(oscuro sobre claro), no necesita contorno salvo el caso ya señalado (rojo sobre khaki, §1.3-[3]). Antes
de cerrar el theme, verificar estos tonos con cuentagotas real sobre el PNG (esto es una estimación
visual, no una medición de píxel).

### 1.6 Comportamiento en distintos anchos de ventana

- **1280px (mínimo soportado)**: layout tal cual §1.2, spacer central en su mínimo (~48px de aire).
- **1600×900 (resolución de referencia del proyecto)**: el spacer crece, todo lo demás igual — ningún
  chip cambia de tamaño ni de contenido.
- **Por debajo de 1280px**: no soportado por `technical-preferences.md`; si ocurriera igualmente
  (ventana redimensionada a mano), degradación de emergencia en este orden — 1º se oculta la línea 2
  (secundaria) de los grupos 5 y 6 (Demanda/Plantilla, los menos urgentes de leer al segundo), 2º si
  sigue sin caber, esos dos grupos completos se colapsan a icono+número sin etiqueta. Los grupos
  1/2/3 (reloj/velocidad/saldo) y 4/7 (satisfacción/reclamaciones, Documentación) **nunca** se ocultan
  — son los datos de los que depende no perder la partida.
- **Redimensión en caliente**: anclas, no cálculo manual de posición — igual que el resto del kit.

---

## 2. Barra/botonera inferior de acciones

### 2.1 Estructura

Dos franjas apiladas en la parte baja de la pantalla, **independientes**:

```
┌───────────────────────────────────────────────────────────────────────┐
│                    (franja de ACCIONES — nueva, 60px)                  │
├───────────────────────────────────────────────────────────────────────┤
│              (barra de construcción, tecla B — SIN TOCAR)              │
└───────────────────────────────────────────────────────────────────────┘
```

- La barra de construcción (`modo_construccion.gd`) sigue **anclada a `PRESET_BOTTOM_WIDE`,
  `grow_vertical = GROW_DIRECTION_BEGIN`** tal cual está — no se toca su código de layout.
- La franja de acciones se ancla también `PRESET_BOTTOM_WIDE` / `GROW_DIRECTION_BEGIN`, pero con
  `offset_bottom` desplazado hacia arriba exactamente la altura de la barra de construcción **cuando
  está colapsada** (solo el botón "🔨 Construir (B)" + `_lbl_estado`, sin categorías/tarjetas
  desplegadas) — es decir, la franja de acciones vive en el hueco que hoy reserva
  `HUECO_BARRA_INFO`/`ALTO_BARRA_HUD` (ambas constantes, hoy en 84px cada una, deben actualizarse al
  nuevo valor de **60px** de esta franja — mismo criterio, dos constantes que tienen que quedar
  sincronizadas, ver nota en el propio código de `modo_construccion.gd` línea ~1938-1943).
- **Por qué nunca se solapan**: al pulsar B, la barra de construcción **crece hacia arriba** desde su
  propio borde inferior (ya es así hoy) — pero la franja de acciones está POR ENCIMA de esa base, en
  su propio hueco reservado y fijo; cuando la barra de construcción se expande, crece [encima de su
  propia franja colapsada], no encima de la franja de acciones. Verificar con captura (regla del
  proyecto) que al desplegar una categoría con 3 filas de tarjetas (el peor caso ya documentado en
  `spec-tarjetas-2026-08-08.md` §2.1, `ALTO_BARRA` 352px) la barra de construcción no llega a tapar la
  franja de acciones — si el catálogo crece más, la barra de construcción ya tiene su propio
  `ScrollContainer` vertical documentado como opción de fondo (misma spec, §2.1), así que el techo
  puede tratarse ahí sin tocar la franja de acciones.

### 2.2 Contenido de la franja de acciones (60px de alto)

- `HBoxContainer` alineado a la **derecha** (mismo criterio de Fitts's Law que ya usa "Demoler" en la
  barra de construcción: el borde de pantalla es el blanco más fácil de acertar con el ratón, y estas
  5 acciones son de alta frecuencia).
- 5 píldoras, en este orden (izquierda→derecha dentro del grupo alineado a la derecha), agrupadas por
  familia con separación mayor entre familias (16px) que dentro de la familia (8px):

| Píldora | Icono | Tamaño | Estilo | Atajo visible |
|---|---|---|---|---|
| Personal | `icono_personal.png` | ~118×40 | `PildoraPrimaria` (abre modal) | `"Personal (P)"` en el propio texto |
| Horario | `icono_reloj.png` *(reutilizado, ver nota)* | ~110×40 | `PildoraPrimaria` | `"Horario (H)"` |
| *(gap 16px — familia gestión → familia guardado)* |
| Guardar | `icono_disquete.png` | ~110×40 | `PildoraSecundaria` | `"Guardar (F5)"` |
| Cargar | `icono_carpeta.png` | ~105×40 | `PildoraSecundaria` | `"Cargar (F9)"` |
| *(gap 16px — familia guardado → familia vista)* |
| Paredes | `icono_muro.png` | ~150×40 *(texto variable, ver §3)* | `PildoraSecundaria` | `"Paredes: Auto (Home)"` |

- **Nota sobre el icono de Horario**: el set de 16 iconos entregado no incluye un pictograma
  específico de "horario" distinto del reloj genérico (`icono_reloj.png`) — se reutiliza el mismo
  icono que en la Pieza 8 original se pidió como dos conceptos separados pero Summer entregó como uno
  solo. Es una reutilización aceptable: el icono es refuerzo decorativo, el texto `"Horario (H)"` es
  el identificador real (regla del proyecto: nunca solo icono, siempre + texto).
- **Atajos visibles, no en tooltip**: se escriben literalmente en el texto de cada píldora (más
  accesible que un tooltip que exige hover) — el tooltip (`tooltip_text`) puede añadirse como refuerzo
  con la descripción larga, pero NO es el único canal.
- Todas las píldoras son `Button` con contenido manual envuelto en `MarginContainer` (mismo fix de
  causa raíz que `spec-tarjetas-2026-08-08.md` §0-B — icono a la izquierda, texto a la derecha, en un
  `HBoxContainer` dentro del margen).
- **Feedback de Guardar/Cargar**: reutilizar el patrón ya existente en el propio código
  (`_avisar_accion`, visto en `modo_construccion.gd`) para un mensaje transitorio de confirmación
  ("Guardado ✓" / "Partida cargada") — no se pide un sistema de toasts nuevo para esto (los toasts son
  Pieza 7, reservada para el sistema de avisos, fuera de alcance aquí).

---

## 3. Estados

Regla transversal del proyecto (repetida en todos los GDD y en `accessibility-requirements.md`):
**color + forma/icono/texto, nunca solo color.** Aplicado a los 4 estados pedidos:

| Estado | Señal visual | Dónde |
|---|---|---|
| **Saldo negativo** | Cifra en rojo `#BF332E` + contorno navy 1px + palabra `"Negativo"` en la línea 2 del chip Saldo (§1.3-[3]) | Chip Saldo |
| **Sin plantilla** (0 agentes libres/cubriendo, o plantilla vacía) | Cifra `"0/N"` en rojo + línea 2 cambia de `"Nómina: — €/día"` a `"⚠ Sin cobertura"` (el glifo ⚠ es texto, mismo patrón que usan los GDD del proyecto con 🔴/🟡/🟢 — no requiere icono nuevo) | Chip Plantilla |
| **Cola saturada** (ocupación de la sala de espera al límite del aforo real, o cola exterior > 0) | Banda semáforo delante del número (`🔴`/`🟡`/`🟢`, mismo patrón #11 de `interaction-patterns.md`) + si hay cola exterior, se añade una fracción `"5 en cola (+2 fuera)"` — el umbral concreto lo posee Flujo/Construcción (aforo real), la UI solo pinta la banda, no lo calcula | Chip Documentación |
| **Partida sin guardar** (hay cambios desde el último guardado) | La píldora "Guardar" añade un punto `"•"` al final del texto — `"Guardar (F5) •"` — y su color pasa de `PildoraSecundaria` (blanco) a un tinte ámbar sutil vía `modulate`; el punto desaparece y el `modulate` vuelve a blanco justo después de guardar. El PUNTO (presencia/ausencia) es el respaldo no-color, el tinte es refuerzo | Píldora Guardar, franja de acciones |

---

## 4. Qué se elimina del HUD viejo sin sustituto

- **Todo el bloque provisional de la barra inferior** que hoy mezcla reloj/velocidad/saldo/demanda/
  personal/colas (comentario de cabecera de `main.gd`: *"HUD provisional de barra inferior (reloj/
  velocidad/saldo/demanda/personal/colas)"*) — desaparece de abajo por completo. Ninguno de esos 6
  datos se queda abajo; todos pasan arriba según §1.
- **`ALTO_BARRA_HUD`** (`main.gd`, 84px) y **`HUECO_BARRA_INFO`** (`modo_construccion.gd`, 84px) — se
  sustituyen por el nuevo alto de 60px de la franja de acciones (§2.1); las dos constantes deben
  quedar sincronizadas al mismo valor, igual que hoy.
- **Cualquier texto/hint suelto** que cuelgue directamente de `_capa_hud` fuera de un contenedor
  reconocible (p. ej. avisos de acción posicionados a mano con `.position` en vez de vivir dentro de
  un panel) — se elimina; los hints de construcción (p. ej. *"Elige el hueco donde va, dentro de la
  sala"*) se quedan **solo** dentro del propio panel de construcción (`_lbl_estado`), que no se toca.
- **`COLOR_TENUE_HUD`/`COLOR_TENUE_HUD_CLARO`** (`main.gd`) — se conservan como constantes (siguen
  siendo útiles y ya están calibradas), pero se **reasignan de alcance**: dejan de ser "el color
  secundario de todo el HUD" y pasan a ser específicamente para los hints transitorios de construcción
  (`_avisar_accion`); el HUD persistente nuevo usa su propia paleta de este documento (§1.5), que
  coincide en el navy pero no depende de esas constantes concretas.
- **Cualquier emoji/glifo usado como sustituto de icono real** donde SÍ existe arte del kit (reloj,
  saldo) se sustituye por el arte real (`barra_superior_modulo_reloj.png`,
  `_saldo.png`) — el emoji-texto se mantiene únicamente como respaldo de accesibilidad en los sitios
  donde NO hay arte dedicado (satisfacción, estados de alerta), nunca como icono principal si hay
  arte disponible.

---

## 5. Contrato de datos — lo que Main necesita leer para construir el HUD nuevo

Sin leer el HUD viejo: esta tabla basta para construir la clase nueva. `campo` = getter/propiedad real
localizada en el código; `origen` = autoload/nodo dueño; `refresco` = cuándo releerlo.

| Campo | Tipo | Origen | Refresco |
|---|---|---|---|
| `Tiempo.minutos_juego` | `float` | `Tiempo` (foundation) | `_process` (tiempo real), derivar HH:MM cada frame |
| `Tiempo.semana` / `Tiempo.mes` / `Tiempo.anio` | `int` | `Tiempo` | en `EventBus.nuevo_dia` / `nuevo_mes` (cambian poco, no hace falta cada frame) |
| `Tiempo.turno_de(minutos_juego)` | `int` | `Tiempo` (función pura) | junto con la hora, en `_process`, o en `EventBus.cambio_de_turno(turno)` |
| `Tiempo.velocidad_actual` / `Tiempo.multiplicador_velocidad` | `enum Velocidad` / `int` (0=Pausa,1,2,3) | `Tiempo` | en `EventBus.velocidad_cambiada(indice)` (evento discreto, no hace falta poll) |
| `Economia.saldo_eur` | `float` | `Economia` (core) | en `EventBus.saldo_cambiado(nuevo_saldo)` |
| `Economia.umbral_holgura_ui` | `float` (knob, default 500) | `Economia` | una vez al construir el HUD (no cambia en caliente) |
| `Paciencia.sat_global()` | `float` (función) | `Paciencia` (feature) | `_process` o en un tick propio — no hay señal dedicada de satisfacción, es poll |
| `Paciencia.reclamaciones_jornada` / `reclamaciones_graves_jornada` | `int` | `Paciencia` | en `EventBus.reclamacion_generada(origen)` |
| `umbral_sat_bajo` / `umbral_sat_alto` | `float` (knobs UI, 40/70) | propios de la UI (F3, `ui-hud.md`) | fijos, no cambian en caliente |
| `Demanda.nivel_demanda()` | `StringName` (BAJA/MEDIA/ALTA) | `Demanda` (core) | en `EventBus.nivel_demanda_cambiado(nivel)` |
| `Demanda.llegadas_hoy` | `int` | `Demanda` | en `EventBus.persona_generada(persona)` o poll en `_process` (contador simple) |
| `Personal.plantilla` | `Array[Agente]` | `Personal` (core) | tras contratar/despedir/día libre (no hay señal dedicada localizada — poll al abrir/cerrar el panel de Personal, o exponer una señal nueva si se quiere tiempo real) |
| Nómina total | `float`, calculado sumando `Personal.salario_dia(agente)` sobre `plantilla` | `Personal` (función `salario_dia` ya existe) | mismo momento que `plantilla` |
| `Flujo.personas_en_cola(servicio)` | `int` | `Flujo` (core) | `_process` o poll periódico (no es una señal discreta, cambia constantemente) |
| `Flujo.atendiendo_total()` | `int` (total, no por servicio) | `Flujo` | igual que arriba — **si se necesita SOLO Documentación, hace falta un getter por servicio que hoy no está confirmado**, ver siguiente fila |
| "Puerta Doc" (nº de turno llamado/mostrado en la entrada) | — | **no localizado** en `flujo.gd`/`documentacion.gd` en este análisis | **a confirmar con quien implemente** — si no existe, la línea 2 del chip Documentación se reduce a `"N atendiendo"` sin ese dato (Edge Case ya cubierto en §1.3-[7]) |
| Estado "dirty"/sin guardar | `bool` | no localizado — probablemente vive en `SaveManager` o hay que añadirlo | a confirmar; si no existe hoy, es una bandera nueva y pequeña (se marca `true` en cualquier mutación de estado relevante, `false` tras guardar) |

**Nota de refresco general**: el patrón ya usado en el HUD viejo es `_process` (tiempo real, sin coste
relevante a esta escala) — se mantiene igual para los campos que cambian constantemente (reloj, colas,
saldo si no se quiere depender de que ninguna mutación olvide emitir la señal). Los campos con señal de
`EventBus` dedicada (saldo, velocidad, demanda, reclamación, turno) pueden pintarse **solo** al recibir
el evento si se prefiere evitar poll — cualquiera de las dos vías es válida, es una decisión de
rendimiento del programador, no de UX.

---

## 6. Wireframe ASCII

### Arriba (52px, ancho completo)

```
┌──────────────┬─────────────┬─────────────┬───────────────┬─────────────┬─────────────┬───────────────┬──────────────────────┬──────────┐
│ 🕐⭐ 14:32     │ ⏸ ▶ ▶▶ (3×) │ 🛡 1.240 €   │ 💬 🟢 Sat. 72%│ 🎚 Demanda: │ 👥 Plantilla:│ 📁 Doc: 5 en  │  (spacer elástico)    │ brújula  │
│ Sem2·T1        │  activo: ▾  │  Holgado     │ Reclam: 3(1!) │ ALTA        │ 8/10         │ cola          │                        │ 140px    │
│                │             │              │               │ Lleg.hoy:24 │ Nóm:640€/día │ 2 atend·P07   │                        │ (dev)    │
└──────────────┴─────────────┴─────────────┴───────────────┴─────────────┴─────────────┴───────────────┴──────────────────────┴──────────┘
  150px           135px         145px          155px           140px         140px          155px              resto                 140px
```

### Abajo (dos franjas apiladas)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                     [👤 Personal (P)] [🕐 Horario (H)]                │
│                                          [💾 Guardar (F5)•] [📁 Cargar (F9)]  [🧱 Paredes: Auto (Home)] │  ← franja de acciones, 60px
├────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [🔨 Construir (B)]   Elige el hueco donde va, dentro de la sala...                                    │  ← barra de construcción (sin tocar)
│  (se expande hacia arriba con pestañas+tarjetas al pulsar B — no toca la franja de arriba)            │
└────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Repaso de accesibilidad (checklist del rol)

- [x] **Usable con teclado**: los atajos (P/H/F5/F9/Home, 1/2/3/Espacio) ya cubren toda acción del HUD
  sin ratón. *(Nota heredada de `spec-tarjetas-2026-08-08.md`: las píldoras/chips deben llevar
  `focus_mode` alcanzable por Tab si se quiere navegación completa por teclado — mismo hallazgo
  pendiente que las tarjetas de construcción, no se resuelve aquí, se hereda la misma nota.)*
- [x] **Usable con gamepad**: no aplica (`technical-preferences.md`: sin soporte de mando).
- [x] **Texto legible al tamaño mínimo**: 10px es el piso, igual que el resto del kit ya aprobado.
- [x] **Funcional sin depender solo del color**: cubierto en cada punto de §3 (texto/glifo + color, nunca
  solo color).
- [x] **Sin parpadeo sin aviso**: ningún elemento de este spec parpadea; si se añade un "latido" al
  chip de Documentación en cola saturada en el futuro, debe respetar `reducir_movimiento` (diferido,
  como el resto de accesibilidad avanzada del proyecto).
- [x] **Subtítulos**: no aplica, sin diálogo hablado en el HUD.
- [x] **La UI escala en las resoluciones soportadas**: comportamiento definido en §1.6 para 1280–1600px+;
  por debajo de 1280px no está soportado por el proyecto.

---

## 8. Fuera de alcance (anotado, no resuelto aquí)

- Módulo de Objetivo/ascenso (arte ya existe, sistema no cerrado — §1.2).
- Bandeja de avisos/toasts (Pieza 7 del kit, reservada — sistema de eventos/quejas aún no implementado
  del todo, `plan-maestro-ui.md` decisión 4).
- Navegación por pestañas completa (Comisaría/Funcionarios/Servicios/Valoraciones/Despacho) — este
  documento es solo el HUD persistente (arriba) + acciones (abajo), no las 5 pantallas de gestión.
- Foco por teclado (`focus_mode`) de las píldoras/chips nuevos — mismo hallazgo pendiente que las
  tarjetas de construcción/paleta, anotado para una tarea de accesibilidad aparte.
- Campo "puerta Doc" y bandera "sin guardar" — no localizados en el código actual, marcados en §5 para
  confirmar antes de cerrar el binding real (no bloquean el resto del HUD, tienen degradación definida).
