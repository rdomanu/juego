# Prompt para Summer — Kit de UI de Comisario

> **Status**: Draft — para revisión del usuario ANTES de gastar nada
> **Author**: ux-designer
> **Last Updated**: 2026-08-07
> **Basado en**: `design/ux/plan-maestro-ui.md` (Sección 0, decisiones 2026-08-07)
> **Actualización 2026-08-07 (aprobación del usuario, con 1 cambio):** el color BASE de los paneles pasa
> de **crema a BLANCO**; el acento azul CNP y el resto de la especificación quedan igual. Todas las
> referencias a "crema" de más abajo son la versión anterior — ya corregidas a blanco en este documento.
> **Regla de gasto** ([[reparto-summer-arte]]): NINGUNA de las generaciones de abajo se lanza sin que el
> usuario diga OK **a esa pieza en concreto** (son de pago). Este documento es el borrador a aprobar, no
> dispara nada por sí solo. Tras el OK, cada pieza generada se audita (paleta, 9-slice limpio, sin texto
> incrustado) y se enseña antes de integrarla al `Theme` de Godot.

---

## 1. Especificación común — aplica a TODAS las piezas

Se repite al principio de cada prompt individual para que cada generación salga coherente aunque se
lancen en tandas distintas y en sesiones separadas.

**Paleta:**
- Base: **BLANCO** (actualizado 2026-08-07, antes crema) + el azul suave ya usado en fachada/pintura del
  juego. El crema queda disponible solo como guiño secundario opcional (p. ej. un detalle interior muy
  sutil), nunca como color de fondo de un panel — la base de todo panel/marco es blanca.
- Acento (nuevo, decisión 1+5): **azul marino CNP** más saturado que el azul suave del juego, reservado
  para lo interactivo/identitario (pestaña activa, marco de ventana, botón primario, cabecera).
- Semántica de estado (transversal a todo el kit, respaldo NO-color obligatorio): verde=válido/ok,
  ámbar=aviso, rojo=crítico/bloqueado — siempre acompañado de forma/icono, nunca solo el color
  (`accessibility-requirements.md`).

**Tono:** tycoon simpático, referencia directa ***Two Point Hospital*** — formas redondeadas, ligero
relieve/profundidad tipo botón "pulsable", nada de gris institucional ni aspecto de expediente. Amigable
pero no infantil.

**Identidad CNP (decisión 1):** guiños estilizados — azul marino, silueta genérica de placa/insignia,
tipografía institucional pero amable. **PROHIBIDO** reproducir el escudo oficial exacto de la Policía
Nacional o de España, ni cualquier emblema oficial real reconocible — es una **interpretación estilizada
de ficción**, no el símbolo real (derechos de imagen de símbolos del Estado).

**Reglas técnicas de adopción (todas las piezas):**
- **PNG con canal alfa** (transparencia real); nunca fondo blanco/color sólido salvo que sea la pieza en sí.
- **Pensado para 9-slice:** esquinas y bordes claramente diferenciados del centro (el centro debe ser
  liso o un patrón que repita sin costura) — para recortar en Godot como `StyleBoxTexture` de 9 partes.
- **Sin texto incrustado en ninguna imagen** — todo texto (nombres, precios, cifras) lo pinta Godot en
  tiempo real con la fuente del juego.
- **Resolución de trabajo alta:** generar cada pieza a un detalle 2×–4× el tamaño de uso en pantalla, para
  que no se vea borrosa al escalar ni al hacer 9-slice de los bordes (referencia de viewport: 1600×900).
- **Esquinas/bordes definidos en píxeles enteros**, sin sombra difusa que se salga del borde de la pieza
  (dificulta el recorte 9-slice limpio).

---

## 2. Piezas a generar

Cada pieza = una tanda de aprobación de gasto independiente. Los tamaños en px son **de referencia de uso
en pantalla** (para que Summer sepa la proporción y el nivel de detalle que hace falta), no la resolución
exacta de generación (ver regla de "resolución de trabajo alta" arriba).

### Pieza 1 — Barra superior persistente

**Uso:** franja fija, ancho completo, siempre visible arriba de la pantalla (decisión 3). Contiene reloj/
fecha/velocidad, saldo, satisfacción global, objetivo/ascenso.

**Prompt:**
> Panel de barra superior horizontal para un HUD de videojuego tycoon de gestión, estilo *Two Point
> Hospital*, tono simpático y limpio. Fondo BLANCO con borde inferior azul marino CNP. Debe incluir,
> como zonas visualmente separadas dentro de la misma barra (de izquierda a derecha): (1) un bloque de
> reloj/calendario, (2) tres botones redondos pequeños de velocidad tipo ⏸ 1× 2× 3× con su propio marco
> de botón "pulsable" en normal/activo, (3) un bloque de "saldo" con forma de placa o insignia estilizada
> como icono decorativo, (4) un bloque de "satisfacción" con hueco para una barra de progreso, (5) un
> bloque de "objetivo" con hueco para otra barra de progreso. Cada bloque tiene un fondo ligeramente
> distinto (tarjeta dentro de la barra) para que se lean como módulos separados. Sin texto ni números
> dibujados — todo hueco vacío listo para que el motor del juego superponga cifras. 9-slice friendly:
> altura de referencia ~52 px de uso, bordes de 6-8 px bien definidos.

**Tamaño de uso:** ancho completo (1600 px ref.) × ~52 px alto.

---

### Pieza 2 — Pestañas de categoría (barra inferior de Construcción, y reutilizable para la barra de
pestañas de pantallas superior si el estilo encaja)

**Uso:** pestañas grandes icono+texto: Salas · Muebles · Muros y suelos · Zonas · Herramientas (decisión
del wireframe conceptual, `plan-maestro-ui.md` Apéndice B).

**Prompt:**
> Botón de pestaña rectangular grande para un HUD de tycoon simpático (ref. Two Point Hospital), con hueco
> central para un icono grande y una etiqueta de texto corta debajo (ambos huecos vacíos, sin dibujar
> icono ni texto reales). Pedir **4 estados** del mismo botón en la misma composición, claramente
> etiquetados en el propio lienzo de trabajo (no en el PNG final): (a) **normal** — fondo azul suave; (b)
> **hover** — fondo azul suave con borde resaltado; (c) **activo/seleccionado** — fondo azul marino CNP
> más saturado + un pequeño puntero/triangulo en el borde inferior apuntando hacia abajo; (d)
> **bloqueado** — versión grisácea desaturada con un pequeño candado en la esquina. Esquinas redondeadas,
> ligero relieve "pulsable". 9-slice friendly.

**Tamaño de uso:** ~170×50 px por pestaña.

---

### Pieza 3 — Tarjeta de objeto (catálogo de construcción)

**Uso:** tarjeta con miniatura de objeto + precio, para las categorías de Construcción (Salas, Muebles,
Muros y suelos, Zonas).

**Prompt:**
> Marco de tarjeta cuadrada para catálogo de tienda dentro de un tycoon simpático (ref. Two Point
> Hospital). Hueco central grande para una miniatura de objeto (vacío, fondo celeste suave contrastando
> con el marco), y una banda inferior separada para el precio (hueco vacío, sin cifra). Pedir **4
> estados**: (a) **normal**; (b) **hover** — borde resaltado; (c) **seleccionada** — anillo/borde azul
> marino CNP grueso alrededor de toda la tarjeta, más un pequeño badge de check en la esquina
> superior-derecha; (d) **bloqueada/sin fondos** — miniatura atenuada (fondo gris en vez de celeste),
> banda de precio en rojo, badge de aspa en la esquina superior-derecha. Esquinas redondeadas, 9-slice
> friendly en el marco (no en la zona de miniatura, que debe quedar lisa para pegar la imagen del objeto
> encima).

**Tamaño de uso:** ~92×74 px por tarjeta.

---

### Pieza 4 — Botón "Demoler" destacado

**Uso:** acción fija anclada al borde derecho de la barra de construcción, siempre visible, fuera de las
pestañas de categoría (alta frecuencia + acción destructiva).

**Prompt:**
> Botón rectangular destacado en rojo/rosado (color de acción destructiva, coherente con la semántica del
> kit), estilo tycoon simpático, con hueco para icono (papelera o mazo, a elección de Summer dentro del
> tono) + etiqueta corta debajo. Pedir 2 estados: normal y hover/pulsado (ligeramente más oscuro/hundido).
> Mismo lenguaje visual de esquinas redondeadas y relieve que la Pieza 2, pero en la paleta de alerta, no
> en azul.

**Tamaño de uso:** ~150×50 px.

---

### Pieza 5 — Marco de ventana flotante (modal)

**Uso:** panel emergente para decisiones rápidas — Personal, Horario, ficha de agente/puesto, confirmar
demolición, etc. (decisión 2: modal para "rápido"; NO para gestión compleja de rango alto).

**Prompt:**
> Marco de ventana emergente (modal) para un tycoon simpático (ref. Two Point Hospital), fondo BLANCO
> con cabecera superior en azul marino CNP que incluya un hueco de icono + hueco de título (vacíos) y un
> botón de cerrar (X) en la esquina superior derecha con su propio estado normal/hover. El cuerpo del
> panel es una zona lisa grande y vacía (para que el juego meta contenido variable: lista de personal,
> slider de horario, etc.). Sombra suave alrededor de todo el marco para que se lea "flotando" sobre el
> fondo del juego. Muy importante: **centro completamente liso y recortable en 9-slice** (bordes/esquina
> con decoración, centro sin ningún elemento que no repita limpio).

**Tamaño de uso:** marco escalable, referencia de uso 480×360 px mínimo hasta 900×640 px máximo (debe
funcionar estirado en ambos extremos — de ahí la exigencia de 9-slice limpio).

---

### Pieza 6 — Plantilla de pantalla completa (gestión de niveles altos, futuro)

**Uso:** fondo/marco para una pantalla de gestión compleja a pantalla completa (Brigadas, Jefatura
Superior... — sistemas aún sin implementar, decisión 2 reserva este formato para cuando lleguen).

**Prompt:**
> Fondo de pantalla completa para una vista de gestión compleja de un tycoon simpático (ref. Two Point
> Hospital / Football Manager), con una cabecera superior en el mismo lenguaje que la Pieza 5 (cabecera
> azul marino CNP con hueco de título) y una franja lateral izquierda estrecha para una lista de
> sub-secciones (huecos vacíos apilados). El resto del lienzo es zona de contenido lisa. Mismo lenguaje de
> esquinas y relieve que el resto del kit, para que se sienta parte de la misma familia visual aunque se
> use mucho más tarde.

**Tamaño de uso:** pantalla completa, referencia 1600×900 px.

---

### Pieza 7 — Bandeja lateral de avisos (toasts)

**Uso:** columna de notificaciones apilables, lateral, con 3 niveles de severidad + un toast específico de
"queja de ciudadano" (decisión 4: se pide YA para reservar sitio en el layout, aunque el sistema de
eventos/quejas no esté implementado todavía — **para no duplicar este encargo cuando se implemente**).

**Prompt:**
> Tarjeta de notificación (toast) horizontal y estrecha para un tycoon simpático (ref. Two Point
> Hospital), con hueco de icono a la izquierda y hueco de texto de una o dos líneas a la derecha. Pedir
> **3 variantes de severidad** claramente distintas por color Y por forma de borde (no solo color): (a)
> **info** — borde/acento azul suave, esquina superior sin marca; (b) **aviso** — borde/acento ámbar, con
> un pequeño triángulo de exclamación decorativo en la esquina; (c) **crítico** — borde/acento rojo, con
> un pequeño icono de alerta más marcado y un halo sutil (para permitir un "latido" animado en el motor,
> sin que la imagen en sí parpadee). Pedir además una variante específica **"queja de ciudadano"**: mismo
> formato que "aviso", pero con un hueco de retrato circular pequeño a la izquierda (para la cara del
> ciudadano que se queja) en vez del icono genérico. Fondo BLANCO, 9-slice friendly en el marco de cada
> toast.

**Tamaño de uso:** ~340×64 px por toast; columna vertical apilable en el lateral de la pantalla.

---

### Pieza 8 — Iconografía base (16 pictogramas)

**Uso:** set de iconos monocromos/dos tonos consistentes entre sí, para pestañas, botones y avisos de todo
el kit. Se pide en **2 lotes de 8** (no 16 sueltos) para que Summer mantenga el mismo lápiz/estilo dentro
de cada lote y sea más barato de iterar si un lote no sale bien.

**Lote A — Construcción y mundo (8):** sala · silla (mueble) · muro · pintura (bote/brocha) · zona
(marcador de ubicación) · demoler (mazo o papelera) · candado (bloqueado) · dinero (moneda o billete
estilizado).

**Lote B — Gestión y HUD (8):** personal (silueta de agente) · horario (reloj con manecillas) · guardar
(disquete o carpeta) · cargar (flecha hacia carpeta) · reloj (hora actual, distinto del icono de horario)
· velocidad (flecha doble / rayo) · aviso (triángulo exclamación) · queja (globo de diálogo con signo de
interrogación o ceño).

**Prompt (repetir por lote, cambiando la lista):**
> Set de 8 pictogramas simples y consistentes entre sí para el HUD de un tycoon simpático (ref. Two Point
> Hospital), mismo grosor de trazo y mismo estilo de "icono redondeado con relieve sutil" en los 8, sobre
> fondo transparente, en una cuadrícula clara para poder recortarlos individualmente. Paleta: azul marino
> CNP como color principal del trazo/relieve, sin colores dispares entre iconos del mismo lote. Iconos
> pedidos: [lista del lote]. Deben leerse bien a tamaño pequeño (~24-32 px de uso final) — formas simples,
> sin detalle fino que se pierda al escalar.

**Tamaño de uso:** ~28×28 px cada icono en las pestañas/botones; ~20×20 px en los toasts.

---

## 3. "Estados" como requisito transversal, no como pieza aparte

El encargo original menciona *"estados (normal/hover/activo/bloqueado)"* como un ítem propio — **no se
pide como una pieza separada** porque no es una imagen en sí misma: son **variantes de las Piezas 2, 3, 4
y 5** (cada prompt de arriba ya pide explícitamente sus estados aplicables). Pedirlo aparte generaría un
lote sin objeto concreto que dibujar.

---

## 4. Plan de adopción — cómo se trocea lo generado

| Pieza | Cómo se importa a Godot | Notas |
|---|---|---|
| 1 — Barra superior | `StyleBoxTexture` (9-slice) de fondo + `TextureButton` por cada botón de velocidad recortado del mismo lienzo | Los huecos de texto se cubren con `Label`/`RichTextLabel` reales por encima |
| 2 — Pestañas | 1 `Texture2D` por estado × pestaña (o un único `StyleBox` con `theme_override` por estado si Summer entrega los 4 estados ya separados en el lienzo) | El icono de cada pestaña sale de la Pieza 8, superpuesto — no va dibujado dentro del fondo de la pestaña |
| 3 — Tarjeta | `StyleBoxTexture` 9-slice para el marco; la miniatura del objeto se pega ENCIMA (sprites reales de `assets/sprites/mobiliario/` u otro catálogo) | El precio se pinta con `Label` sobre la banda inferior |
| 4 — Demoler | `TextureButton` normal/hover, tamaño fijo (no necesita 9-slice, es un botón de tamaño constante) | — |
| 5 — Marco modal | `StyleBoxTexture` 9-slice, `margin_*` calculados de los bordes decorados del PNG | Reutilizable para TODOS los modales (Personal, Horario, ficha de agente, confirmaciones) — una sola pieza, muchos usos |
| 6 — Pantalla completa | `StyleBoxTexture` 9-slice para el fondo general + recorte aparte de la cabecera | Sin uso inmediato (futuro) — se integra cuando exista la primera pantalla de rango alto |
| 7 — Toasts | `StyleBoxTexture` 9-slice por severidad (3) + 1 variante "queja" con `TextureRect` circular para el retrato | Se instancia en una `VBoxContainer` lateral apilable, con animación de entrada/salida (Feedback #12) |
| 8 — Iconos | Recorte directo a `Texture2D` individuales, uno por concepto | Nombrado canónico igual que el resto de assets (`icon_[concepto].png`) + entrada en `CREDITS` |

**Regla general:** todo lo que sea "marco/fondo" se pide y se trocea como **9-slice** (`StyleBoxTexture`
con `texture_margin_left/top/right/bottom`); todo lo que sea "icono/pictograma" se pide y se recorta como
**textura simple** sin 9-slice (se escala entera).

### Criterio de aceptación por pieza (antes de integrar, con foto — `[[fotomontaje-antes-de-ensenar-hito]]`)

- [ ] Canal alfa presente y limpio (sin halo de fondo blanco residual en los bordes).
- [ ] Esquinas/bordes del 9-slice recortables sin costura visible al estirar (probar en Godot con
      `texture_margin` antes de dar el OK final).
- [ ] Sin texto incrustado en la imagen.
- [ ] Paleta coherente con el resto del kit ya aprobado (mismo azul CNP, misma base blanca).
- [ ] Legible al tamaño de uso real (icono a ~28 px, tarjeta a ~92 px) — probar con una captura a escala,
      no solo mirar el PNG a tamaño grande.
- [ ] Los 4 estados pedidos (si aplica) se distinguen también SIN color (forma/icono/badge), no solo por
      el tinte.
- [ ] Ningún guiño a la Policía Nacional reproduce el escudo oficial exacto (revisión rápida visual).

---

## 5. Estimación de generaciones del encargo completo

| Pieza | Generaciones estimadas | Motivo |
|---|:---:|---|
| 1 — Barra superior | 1 | Un solo lienzo con sus módulos internos |
| 2 — Pestañas (4 estados) | 1 | Los 4 estados se piden en la misma composición |
| 3 — Tarjeta (4 estados) | 1 | Ídem |
| 4 — Demoler (2 estados) | 1 | Pieza pequeña y acotada |
| 5 — Marco modal | 1 | — |
| 6 — Plantilla pantalla completa | 1 | — |
| 7 — Bandeja de avisos (3 niveles + queja) | 1–2 | Puede necesitar una segunda pasada si el toast "queja" (con retrato circular) no sale coherente con los otros 3 en la misma tanda |
| 8 — Iconografía (2 lotes de 8) | 2 | Un lote = una generación, para mantener consistencia de trazo dentro de cada lote |
| **Total** | **9–10 generaciones** | Sin contar reintentos por calidad (histórico: alguna pieza puede necesitar una 2ª pasada si no pasa el criterio de aceptación) |

---

## 6. Abierto / pendiente de tu OK

- [x] Prompt aprobado por el usuario (2026-08-07) con 1 cambio: base blanca en vez de crema (aplicado en
      todo el documento — ver nota de actualización al principio).
- [ ] ¿Lanzamos las 9 piezas en el orden de la tabla, o priorizamos primero las que ya tienen uso
      inmediato (1–4, la barra de construcción) y dejamos 5–7 (modal, pantalla completa, avisos) para una
      segunda tanda, ya que su sistema aún no está implementado?

---

## 7. Pieza piloto — texto final en inglés, listo para pegar en el generador

Primera pieza a generar para validar el estilo antes de lanzar el resto: **Pieza 2 (pestañas de
categoría) + Pieza 3 (tarjeta de objeto)**, combinadas en una sola imagen/generación piloto, cada una con
sus 4 estados, ya con la base blanca aprobada.

```
UI kit pilot piece — category tabs + item card (Comisario, a police-station management tycoon game)

Style: friendly management-tycoon UI, direct visual reference Two Point Hospital — rounded corners,
subtle "pressable" depth/relief, cheerful and approachable, NOT a somber/institutional dossier look.

Palette: WHITE as the base color for every panel background. Soft pastel blue as the game's existing
secondary tone. Navy CNP blue (a more saturated police-navy blue) as the accent color for anything
interactive or identity-related (active tab, selection ring, primary buttons). A very subtle cream tone
may appear only as a tiny secondary interior detail, never as a panel's base fill.

Format requirements (apply to the whole image):
- PNG with real alpha transparency; no solid background behind the shapes themselves (transparent
  canvas).
- Every panel/frame must be 9-slice friendly: corners and edges clearly distinct from the center, and
  the center area flat/seamlessly tileable, so it can be sliced into a 3x3 grid and stretched in a game
  engine without visible seams.
- NO text, numbers, or labels baked into the image anywhere — leave empty placeholder space where text
  will be drawn later by the game engine.
- Render at high working resolution (2-4x the on-screen usage size noted below) so edges stay crisp
  after 9-slice stretching and scaling.
- Crisp, well-defined pixel edges; no soft drop-shadow that bleeds past the asset's own border (it would
  break clean 9-slice cropping).

PART A — Category tab button (on-screen size reference: ~170x50 px)
A large rectangular tab button with an empty circular/square placeholder area for a big icon, and empty
space below it for a short text label (both placeholders left blank, no icon or text drawn). Rounded
corners, slight pressable relief. Provide the SAME button in 4 clearly separated states, laid out side by
side in the same image:
1. Normal — soft blue background.
2. Hover — soft blue background with a highlighted/brighter border.
3. Active/selected — saturated navy CNP blue background, plus a small downward-pointing triangle/pointer
   notch on the bottom edge of the tab.
4. Locked/disabled — desaturated grey version of the tab, with a small padlock icon in the corner.

PART B — Item card (on-screen size reference: ~92x74 px)
A small square card frame for a shop/catalog item. Large empty placeholder area in the center for an item
thumbnail (leave it blank, with a soft light-blue fill distinct from the white card frame around it — do
not draw an actual object). Separate empty band at the bottom for a price (blank, no digits). Provide the
SAME card in 4 clearly separated states, laid out side by side in the same image:
1. Normal — plain white card frame.
2. Hover — white card frame with a highlighted border.
3. Selected — thick navy CNP blue ring/border around the entire card, plus a small checkmark badge in the
   top-right corner.
4. Locked/insufficient funds — thumbnail area shown desaturated/grey (instead of light blue), price band
   tinted red, plus a small "X" badge in the top-right corner.

Overall: both parts (A and B) should read as part of the same visual family — same corner rounding, same
relief style, same navy-blue accent — even though they're different UI elements.
```
