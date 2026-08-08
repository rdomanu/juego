# Spec — Tarjetas de la barra de construcción y de la paleta del diseñador (2026-08-08)

> **Encargo**: feedback literal del usuario — *"los nombres no se ven, los objetos están desviados"*.
> Dos familias de tarjeta, dos archivos: `src/main/modo_construccion.gd`
> (`_construir_boton_con_icono`) y `src/main/modo_disenador_entorno.gd` (`_boton_herramienta`).
> Las dos comparten el mismo arte de 9-slice del kit (`assets/ui/kit/tarjeta_normal.png` y estados,
> `TarjetaObjeto` en `assets/ui/theme_comisario.tres`) — **esta spec NO toca el theme ni pide arte
> nuevo**, todo se resuelve con tamaños y layout en código.

---

## 0. Causa raíz encontrada (antes de entrar en cada familia)

Los dos síntomas reportados tienen **dos causas distintas**, no una sola:

**A) "Los nombres no se ven"** → la banda de rótulo se calcula como una **proporción del alto total
del botón** (`FRACCION_BANDA_INFERIOR = 0.22` en construcción; en la paleta ni siquiera hay banda,
el rótulo comparte fila con el icono). Una proporción no garantiza píxeles suficientes para una
fuente de tamaño fijo — 22% de 84px son ~18px, insuficiente para una sola línea de un nombre largo
a fuente 10, y ni hablar de dos. **Fix: sustituir la proporción por una banda de ALTO FIJO en
píxeles**, dimensionada para el número de líneas que se decide soportar, no para "lo que sobre".

**B) "Los objetos están desviados"** (miniaturas asomando por el borde izquierdo en la paleta) → el
contenedor interno (`contenido`, un `HBoxContainer`) se ancla con
`set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` al rect COMPLETO del botón (0→112,
0→48), **ignorando el `content_margin` de 8px** que el `StyleBoxTexture` del tema ya reserva para
que nada se dibuje sobre el borde del 9-slice. En la paleta, el rótulo usa
`size_flags_horizontal = SIZE_EXPAND_FILL`: al reclamar todo el ancho sobrante, empuja al icono
(tamaño fijo, sin expandir) contra el borde IZQUIERDO literal del rect (x=0) en vez de dejarlo
centrado con 8px de aire — de ahí que la miniatura "asome". En la barra de construcción el mismo
patrón existe (mismo `PRESET_FULL_RECT`) pero no se nota porque el icono es el único hijo de su
fila y queda centrado por promedio; aun así es **técnicamente el mismo defecto**, latente.
**Fix: envolver `contenido` en un `MarginContainer` con margen 8px (el mismo valor que
`content_margin_*` de `sb_tarj_n`/`sb_tarj_h`/`sb_tarj_s`/`sb_tarj_b` en el `.tres`) en vez de
anclarlo directo al rect completo del botón.**

Estas dos causas explican por qué el arreglo no es "subir el tamaño de fuente" ni "centrar mejor a
ojo": son dos bugs de layout con un fix concreto cada uno.

---

## 1. Familia A — Tarjeta de construcción (`src/main/modo_construccion.gd`)

### 1.1 Dimensiones

| | Antes | Después |
|---|---|---|
| Tarjeta (`_anadir_herramienta` → sala/mueble/demoler) | 84×84 | **84×120** |
| Pestaña de categoría (`_construir_pestana_categoria`) | 112×74 | **sin cambios** |

**Por qué solo crece la tarjeta y no la pestaña**: los nombres largos reportados
("Oficina de Documentación" 24 car., "Sala de Espera — Documentación" 31 car.,
"Ventanilla Documentación (150 €)" ~33 car. con el coste ya concatenado — ver
`datos/salas/*.tres` y `datos/puestos/*.tres`) son de **tarjeta**, no de pestaña (las pestañas son
categorías cortas: "🏗 Salas", "🪑 Muebles"...). Ampliar solo lo que está roto.

**Por qué cabe sin problema de presupuesto vertical**: a diferencia de la paleta (ver §2), esta
barra NO tiene un alto fijo tipo `ALTO_BARRA` — el `PanelContainer` raíz usa
`grow_vertical = GROW_DIRECTION_BEGIN` y se dimensiona por contenido (ver `_crear_ui`, líneas
~1902-1918). Puede crecer 36px sin chocar con ningún techo ni sin arriesgar recortar nada; el único
efecto lateral es que la barra ocupa un poco más de alto de pantalla, aceptable.

**Cambio derivado obligatorio**: `_scroll_tarjetas.custom_minimum_size` (línea ~1963) pasa de
`Vector2(0.0, 96.0)` a **`Vector2(0.0, 124.0)`** (120 de tarjeta + 4px de aire) — si no se toca,
la fila de tarjetas más altas se recorta contra el `ScrollContainer`.

### 1.2 Zonas internas

Dentro del margen de contenido de 8px (nuevo `MarginContainer`, ver §0-B), queda un interior de
68×104px (84-16 × 120-16). Se reparte en dos zonas de **alto fijo**, no proporcional:

```
┌─────────────────────┐  ↑
│                      │  │
│   ZONA ICONO         │  68px  (cuadrada; TextureRect o icono KitUIComisario,
│   (68×68)            │  │      STRETCH_KEEP_ASPECT_CENTERED — nunca deformado)
│                      │  ↓
├─────────────────────┤  ← separación 4px
│  Rótulo, hasta       │  32px  (2 líneas, fuente 10, alineado ARRIBA)
│  2 líneas            │  ↓
└─────────────────────┘
```

- **Zona icono**: 68×68px fijo (antes: proporción `1.0 - FRACCION_BANDA_INFERIOR` de un contenedor
  expansivo). `custom_minimum_size` del `TextureRect`/hueco sube de 24×24 a **32×32** (la zona
  disponible es más generosa, un icono de 24px quedaría perdido). Sigue centrado con
  `STRETCH_KEEP_ASPECT_CENTERED` + `EXPAND_IGNORE_SIZE` — sin cambios ahí.
- **Banda de rótulo**: **32px fijos**, no proporcionales. Origen del número: fuente 10 × 2 líneas
  (~13px de alto de línea cada una en Kenney Future ≈ 26px) + 6px de aire (3px arriba/abajo).
  Si el programador prefiere no hardcodear el número, la fórmula equivalente en tiempo real es:
  `ceil(theme.default_font.get_height(10) * 2) + 6`. Cualquiera de las dos formas es válida; la
  constante es más simple, la fórmula es más robusta si el kit cambia de fuente algún día.
- **Nombres largos (2+ líneas de sobra)**: NO se usa `TextServer.OVERRUN_TRIM_ELLIPSIS` — sigue sin
  estar confirmado en `docs/engine-reference/godot/` para 4.6 (misma razón que ya documenta el
  código actual). En su lugar: `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` — **API confirmada**
  en `docs/engine-reference/godot/modules/ui.md` línea 73 (Godot 4.6) — corta por palabra completa,
  nunca a la mitad de una palabra, y `clip_contents = true` (ya existe) recorta limpio cualquier
  3ª línea que no quepa. `vertical_alignment` pasa de `CENTER` a **`TOP`**: así, si el nombre no
  cabe en 2 líneas, el recorte se come SIEMPRE la parte de ABAJO (limpio), nunca un semi-carácter
  arriba y otro abajo como pasaría centrado.
- **Nombre completo siempre disponible**: `tooltip_text = texto` ya existe — se mantiene como
  canal SECUNDARIO (no el único). El rótulo visible en la tarjeta sigue siendo el canal primario;
  el tooltip es un extra, no un requisito para identificar la tarjeta (evita depender de hover-only,
  ver §3).
- **Caso límite reconocido, no resuelto aquí**: con nombres de ~31-33 caracteres
  ("Sala de Espera — Documentación", "Ventanilla Documentación (150 €)") es posible que 2 líneas a
  68px de ancho sigan sin bastar y se recorte una porción — es un resultado ACEPTADO para esta
  spec (identificación primaria por icono + rótulo parcial + tooltip de respaldo). Si se quiere
  garantía de cero recorte, la solución de fondo es otra (ver §4, badge de precio/nombre separado
  del patrón *Two Point* ya documentado) — fuera de alcance de este arreglo puntual.

### 1.3 `BotonDemoler` y pestañas — nota de alcance

`BotonDemoler` usa la MISMA fábrica (`_construir_boton_con_icono`) a 84×84 hoy → pasa a 84×120
igual que el resto (comparte función). "Demoler" es una palabra corta: sobra banda, queda pegada
arriba por el alineado `TOP` — sin problema funcional, solo un pelín de aire de más debajo del
texto. Aceptado.

Las **pestañas** (`_construir_pestana_categoria`, 112×74) siguen usando la ruta antigua de
proporción (`FRACCION_BANDA_INFERIOR`) — no se tocan, sus rótulos son cortos y no están en el
reporte de bug.

---

## 2. Familia B — Paleta del diseñador (`src/main/modo_disenador_entorno.gd`)

### 2.1 Dimensiones

| | Antes | Después |
|---|---|---|
| Tarjeta con miniatura (`_boton_herramienta`, pieza con sprite) | 112×48 | **128×56** |
| Tarjeta de texto (superficies + goma, sin sprite) | 112×48 | **128×56** (mismo tamaño, para que la rejilla quede uniforme) |
| `TAMANO_MINIATURA_PALETA` | 40×40 | **36×36** |

**Por qué el ancho crece exactamente 16px (112→128)**: son los mismos 2×8px del margen de
contenido que el fix de §0-B empieza a respetar. Hoy el layout usa (incorrectamente) los 112px
completos porque ignora el margen; al corregir el anclaje, el interior útil real pasa a ser 96px si
no se compensa. Sumar 16px al ancho de tarjeta deja el interior útil en 112px — el mismo espacio
que tenía "a ojo" antes del fix, sin la fuga sobre el borde.

**Por qué el alto crece solo 8px (48→56), no más**: la paleta SÍ tiene techo fijo —
`ALTO_BARRA = 340` (comentario en el código: ya se subió una vez de 260→340 por falta de sitio).
Cálculo del presupuesto vertical actual (elementos fijos de `raiz`, un `VBoxContainer` con
separación por defecto ~4px entre 5 hijos):

```
título (1 línea, fuente 16)          ≈ 24px
fila_pestañas (botones 48px)         =  48px
fila de tarjetas (HFlowContainer)    =  ??? ← lo que se reparte aquí
fila_acciones (botones 48px)         =  48px
lbl_estado (1 línea, fuente 16)      ≈ 24px
4 separaciones × 4px                 =  16px
─────────────────────────────────────────────
Presupuesto para la rejilla de tarjetas ≈ 336 - 160 = 176px
```

Con tarjeta de 56px + 8px de separación vertical entre filas: 3 filas =
`3×56 + 2×8 = 184px` — **se pasa del presupuesto por 8px**. La categoría con más piezas
("🏠 Casas", 21 ids) es la candidata a necesitar 3 filas según el ancho real de ventana en juego
(dato que esta spec no puede calcular sin abrir el juego).

**Cambio derivado obligatorio**: subir `ALTO_BARRA` de **340 a 352** (+12px) — dos líneas de
código, mismo criterio que el ajuste anterior (260→340) documentado en el propio archivo. Con
352, el presupuesto para la rejilla sube a 188px, que sí cubre las 184px de un peor caso de 3
filas con 4px de margen.

**Verificación obligatoria antes de cerrar la tarea** (regla del proyecto,
`.claude/docs/coding-standards.md` — *"For UI changes, verify with screenshots"*): captura de la
pestaña "🏠 Casas" (la más numerosa) con la ventana a su resolución real, confirmando que todas
las filas caben dentro de `ALTO_BARRA` sin recortarse contra el borde superior de la barra ni tapar
el HUD del juego. Si el recuento de filas real supera lo calculado aquí, subir `ALTO_BARRA` el
resto que haga falta (mismo patrón, no hay que rediseñar nada más) — o, si el catálogo sigue
creciendo con futuras piezas, considerar envolver `fila` en un `ScrollContainer` vertical (como ya
hace la barra de construcción con `_scroll_tarjetas`) en vez de seguir subiendo `ALTO_BARRA` sin
límite. Esa decisión de scroll vertical queda fuera de esta spec puntual — solo se deja anotada
para cuando `ALTO_BARRA` empiece a doler otra vez.

### 2.2 Zonas internas

La paleta mantiene el layout **horizontal** (icono a la izquierda, rótulo a la derecha) — NO se
cambia al patrón vertical de la Familia A. Motivo: con techo de altura fijo (`ALTO_BARRA`), un
layout vertical (icono arriba, rótulo abajo, como en construcción) necesitaría más alto por tarjeta
del que hay presupuesto; el layout horizontal ya es el más compacto en altura de los dos posibles.

Dentro del margen de contenido de 8px (`MarginContainer` nuevo, fix de causa raíz §0-B), interior
112×40px (128-16 × 56-16):

```
┌────────┬──────────────────────┐
│ ICONO  │  RÓTULO               │  40px de alto
│ 36×36  │  hasta 2 líneas       │  (icono centrado en los 40px,
│        │  alineado ARRIBA      │   con 2px de aire arriba/abajo)
└────────┴──────────────────────┘
  36px  6px    ≈70px
```

- **Icono**: `TAMANO_MINIATURA_PALETA` baja de 40×40 a **36×36** — sigue centrado con
  `STRETCH_KEEP_ASPECT_CENTERED`, sigue siendo el sprite REAL de la pieza (nunca se pierde ese
  requisito del usuario: "una imagen del objeto... con el diseño que tiene"). Tamaño fijo
  (`size_flags_horizontal` SIN `SIZE_EXPAND_FILL`) — el que antes empujaba al icono contra el
  borde era precisamente el rótulo expansivo sin margen (causa raíz §0-B); con el margen
  restaurado, el icono queda centrado en su columna de 36px con 8px de aire real a la izquierda.
- **Rótulo**: columna de ≈70px de ancho (112 interior − 36 icono − 6 separación).
  `autowrap_mode` pasa de `AUTOWRAP_OFF` a **`TextServer.AUTOWRAP_WORD_SMART`** (misma API
  confirmada que en la Familia A). `vertical_alignment` pasa de sin-especificar (CENTER por
  defecto) a **`TOP`** — mismo motivo: si el nombre no cabe en 2 líneas, el recorte
  (`clip_contents = true`, sin cambios) se come la parte de abajo, no una tira arriba y otra abajo.
  `horizontal_alignment` sigue en `CENTER`. Fuente sigue en 10.
- **Nombres reales que esto cubre**: con 2 líneas de ~10-11 caracteres cada una a fuente 10 en
  70px, nombres como "▭ Entrada de casa" (18 car.), "🚓 Coche patrulla" (17 car.),
  "🛣 Paso de cebra" (16 car.) — los más largos del catálogo de la paleta (`NOMBRES_PIEZA`,
  `NOMBRES_SUPERFICIE`) — deberían caber sin recorte o con recorte mínimo. Verificar con la misma
  captura del punto anterior.
- **Tarjetas sin sprite** (superficies + goma, líneas 683-686 del archivo): siguen usando
  `Button.text` nativo + `clip_text = true` (Godot `Button` no expone `autowrap_mode`, es
  propiedad de `Label`/`RichTextLabel` — no aplica aquí). Sus nombres son cortos ("🟩 Césped",
  "⬛ Asfalto", "⬜ Acera", "🧹 Borrar", máx. 8 caracteres) y caben de sobra en una línea a fuente 11
  — no forman parte del defecto reportado, solo se les sube `custom_minimum_size` a 128×56 para que
  la rejilla quede visualmente uniforme (todas las tarjetas del mismo alto).
- **Tooltip**: `tooltip_text = texto` ya existe — mismo criterio que la Familia A, canal
  secundario, no único.

---

## 3. Accesibilidad (checklist del proyecto)

Repaso contra la checklist estándar de este rol (`ux-designer`) y contra
`.claude/rules/ui-code.md` / `technical-preferences.md`:

- **Usable solo con teclado** — ⚠️ **NO se cumple hoy, y esta spec NO lo arregla** (fuera del
  alcance pedido: "no toques los .gd"). Las dos fábricas de botón (`_construir_boton_con_icono` y
  `_boton_herramienta`) fijan `focus_mode = Control.FOCUS_NONE`, así que ninguna tarjeta es
  alcanzable con Tab/teclado — toda la selección de herramienta depende del ratón. Es un hallazgo
  independiente del bug reportado (nombres/desviación); se deja anotado aquí para que quede
  registrado y no se pierda, con recomendación de abrir una tarea aparte cuando corresponda tocar
  input de estas dos barras.
- **Usable solo con mando** — No aplica: el proyecto no da soporte a mando
  (`technical-preferences.md`: *Gamepad Support: None*).
- **Texto legible al tamaño mínimo** — Se mantiene fuente 10 en ambas familias (el piso ya
  establecido en el kit para Kenney Future); esta spec no reduce ningún tamaño de fuente por debajo
  de lo que ya había.
- **Funcional sin depender solo del color** — Sin cambios: el estado seleccionado/bloqueado de una
  tarjeta ya se distingue por ARTE distinto (`tarjeta_normal`/`hover`/`seleccionada`/`bloqueada`,
  cuatro texturas separadas en el tema), no solo por un tinte de color. Se mantiene.
- **Sin contenido parpadeante** — No aplica, no hay parpadeo en estas tarjetas.
- **Subtítulos** — No aplica, no hay diálogo hablado en esta pantalla.
- **La UI escala en todas las resoluciones soportadas** — Ambas familias usan tamaños en píxeles
  fijos, coherente con el resto del kit actual (que tampoco escala hoy) — esta spec no introduce
  una regresión nueva, pero tampoco resuelve el escalado general de UI del proyecto, que sigue
  siendo una laguna abierta más amplia que este arreglo puntual.
- **Nada hover-only** (`technical-preferences.md`, nota de plataforma) — Respetado: en ambas
  familias el nombre completo vive en el `tooltip_text` como EXTRA, pero el rótulo visible en la
  propia tarjeta (recortado a 2 líneas, nunca vacío) sigue siendo el canal primario de
  identificación sin necesidad de pasar el ratón por encima.

---

## 4. Lista de cambios por archivo:función (para implementar sin decidir nada)

### `src/main/modo_construccion.gd`

- **Constante nueva** (sustituye/complementa a `FRACCION_BANDA_INFERIOR`, que se queda tal cual
  para el camino de pestaña): añadir `ALTO_ZONA_ICONO_TARJETA := 68.0`,
  `SEPARACION_ICONO_ROTULO_TARJETA := 4.0`, `ALTO_BANDA_ROTULO_TARJETA := 32.0`,
  `TAMANO_MINIMO_ICONO_TARJETA := Vector2(32.0, 32.0)`.
- **`_construir_boton_con_icono`** (línea ~2130): 
  - `boton.custom_minimum_size` pasa de `Vector2(84.0, 84.0)` a un tamaño configurable por
    parámetro con default `Vector2(84.0, 120.0)` — necesita un nuevo parámetro (p. ej.
    `tamano: Vector2 = Vector2(84.0, 120.0)`) para que `_construir_pestana_categoria` pueda seguir
    pidiendo 112×74 sin heredar el cambio.
  - Envolver `contenido` en un `MarginContainer` (margen 8px los 4 lados) en vez de anclarlo con
    `PRESET_FULL_RECT` directo al botón — ESTE es el fix de causa raíz §0-B, aplica a las dos
    familias.
  - Camino de la tarjeta (no pestaña): la zona de icono deja de usar
    `size_flags_stretch_ratio = 1.0 - FRACCION_BANDA_INFERIOR` — pasa a `custom_minimum_size.y =
    ALTO_ZONA_ICONO_TARJETA`, `size_flags_vertical = Control.SIZE_FILL` (fijo, no expansivo).
    `TextureRect.custom_minimum_size` sube de `Vector2(24,24)` a `TAMANO_MINIMO_ICONO_TARJETA`.
  - La etiqueta: `size_flags_stretch_ratio = FRACCION_BANDA_INFERIOR` se sustituye por
    `custom_minimum_size.y = ALTO_BANDA_ROTULO_TARJETA`, `size_flags_vertical = SIZE_FILL`.
    `autowrap_mode` de `AUTOWRAP_OFF` a `TextServer.AUTOWRAP_WORD_SMART`. `vertical_alignment` de
    `VERTICAL_ALIGNMENT_CENTER` a `VERTICAL_ALIGNMENT_TOP`.
  - Camino de pestaña (`variante == VARIANTE_PESTANA` o llamada desde
    `_construir_pestana_categoria`): sin cambios, sigue usando `FRACCION_BANDA_INFERIOR` como hoy.
- **`_construir_pestana_categoria`** (línea ~2190): pasa explícitamente `tamano =
  Vector2(112.0, 74.0)` al llamar a `_construir_boton_con_icono` para no heredar el nuevo default
  de 84×120.
- **`_crear_ui`** (línea ~1963): `_scroll_tarjetas.custom_minimum_size` de `Vector2(0.0, 96.0)` a
  `Vector2(0.0, 124.0)`.

### `src/main/modo_disenador_entorno.gd`

- **`TAMANO_MINIATURA_PALETA`** (línea ~647): de `Vector2(40.0, 40.0)` a `Vector2(36.0, 36.0)`.
- **Constante nueva**: `TAMANO_TARJETA_PALETA := Vector2(128.0, 56.0)`.
- **`ALTO_BARRA`** (línea ~136): de `340.0` a `352.0`.
- **`_boton_herramienta`** (línea ~663):
  - `boton.custom_minimum_size` de `Vector2(112.0, 48.0)` a `TAMANO_TARJETA_PALETA` — en AMBOS
    caminos de la función (con sprite y sin sprite/fallback de texto, líneas ~668 y ~683-686), para
    que la rejilla quede uniforme.
  - Envolver `contenido` (el `HBoxContainer`) en un `MarginContainer` (margen 8px) en vez de
    `PRESET_FULL_RECT` directo — fix de causa raíz §0-B, el que corrige la miniatura desviada.
  - Etiqueta: `autowrap_mode` de `AUTOWRAP_OFF` a `TextServer.AUTOWRAP_WORD_SMART`.
    `vertical_alignment` — no está seteado hoy (CENTER por defecto) — añadir
    `VERTICAL_ALIGNMENT_TOP` explícito.
  - `rect.custom_minimum_size` (la miniatura) sigue leyendo de `TAMANO_MINIATURA_PALETA` — sin
    tocar la línea, el cambio ya viene de la constante.

### Ningún archivo de arte ni `assets/ui/theme_comisario.tres`

- El `content_margin` de 8px de `TarjetaObjeto` en el `.tres` (líneas 85-88) **ya es correcto y
  compartido** por las dos familias a sus tamaños nuevos — no necesita tocarse. El bug nunca fue el
  valor del margen, fue que el código no lo respetaba al anclar `contenido`.

---

## 5. Fuera de alcance — recomendación para más adelante

`design/ux/referencia-menus-construccion.md` §3 documenta que el tycoon de referencia (*Two Point*)
resuelve precio/estado con una **banda de color separada del nombre** (banda verde con el precio,
asterisco de obligatorio, estrella de favorito — todo fuera de la zona de texto del nombre). Si el
catálogo de Comisario sigue creciendo y los nombres con coste concatenado ("Ventanilla
Documentación (150 €)") siguen sin caber ni en 2 líneas, la solución de fondo no es seguir subiendo
el alto de tarjeta — es **separar el precio del nombre en un elemento visual propio** (badge/banda),
como ya hace la referencia. Eso es una pieza de UI nueva (necesita su propio diseño + posible arte),
fuera del alcance de este arreglo puntual de layout.

También queda anotado, fuera de alcance: el hallazgo de accesibilidad de `focus_mode = FOCUS_NONE`
(§3) — ninguna tarjeta de estas dos barras es alcanzable por teclado hoy.
