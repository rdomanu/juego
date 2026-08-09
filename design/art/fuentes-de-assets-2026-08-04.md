# Fuentes de assets para "darle una vuelta a todo lo visual" — investigación 2026-08-04

**Encargo**: localizar fuentes de assets (UI, iconos, mobiliario/props, entorno urbano) que casen
con el estilo ya fijado — low-poly prerenderizado a sprites, personajes "CUTES" de J-Toastie
(poly.pizza), mobiliario del pack "Isometric office", paleta apagada estilo Big Pharma (ver
`plan-calidad-visual.md`). Licencias admisibles: **CC0, CC BY, MIT**. Nada de "solo uso personal"
ni NoDerivatives (recoloreamos y re-renderizamos los assets 3D a sprites propios).

**Nota de encaje de estilo (1-5)**: 5 = mismo lenguaje visual low-poly/atlas plano que nuestros
CUTES + oficina isométrica, encaja sin re-trabajo grande. 1 = estilo incompatible o requiere
reconstrucción casi total.

No se ha descargado nada. No se ha tocado `src/` ni `assets/`.

---

## 1. UI / Menús

| Fuente | URL | Licencia | Qué contiene útil | Encaje |
|---|---|---|---|---|
| **Kenney — UI Pack** | https://kenney.nl/assets/ui-pack | CC0 1.0 | 430+ piezas: botones, paneles, sliders, barras, 2 fuentes TTF, 6 SFX de UI. Base genérica para HUD/menús. | 4 — vector plano limpio, recoloreable a la paleta apagada; no trae "expediente ministerial" pero sirve de esqueleto (9-slice de paneles y botones). |
| **Kenney — Pixel UI Pack** | https://www.kenney.nl/assets/pixel-ui-pack | CC0 1.0 | 750 assets estilo pixel-art. | 2 — es pixel-art, no plano/vectorial; choca con el low-poly prerenderizado. Descartar salvo iconos puntuales. |
| **Kenney — UI Pack (RPG Expansion) / UI Pack Adventure** | https://kenney.nl/assets/ui-pack-rpg-expansion / https://kenney.nl/assets/ui-pack-adventure | CC0 1.0 | Marcos ornamentados, pergaminos, iconos de inventario. | 1 — estética fantasía/RPG, no pega con oficina de comisaría española. |
| **Kenney — Board Game Icons / Board Game Info** | https://kenney.nl/assets/board-game-icons | CC0 1.0 | 250 iconos de tablero, contadores, marcadores — útiles como base de "fichas" o indicadores de estado. | 3 — plano y limpio pero muy genérico de boardgame, no de gestión. |
| **wenrexa — Free UI KIT White (serie #1, #3, #5...)** | https://wenrexa.itch.io/uikit5 | CC0 1.0 (confirmada en la ficha de itch.io) | Paneles minimalistas blancos, botones, ventanas — estilo flat "software" más cercano a un panel de gestión/expediente que Kenney UI Pack. | 4 — el tono "formulario/software" encaja bien con la idea de "expediente ministerial"; hay que verificar variante de color en cada entrega de la serie. |
| **itch.io — tag `cc0` + `user-interface`** (colección) | https://itch.io/game-assets/assets-cc0/tag-user-interface | Variable, filtrar por CC0 en cada ficha | Bolsa amplia de kits sueltos (marcos de retrato, prompts de mando, botones simples) — cantera para piezas puntuales que falten al kit principal. | 3 — calidad y estilo dispares, hay que curar uno a uno; no es una fuente "de una pieza". |
| **itch.io — Interface Icon Pack for Games and Software (150+ icons)** | (vía itch.io, buscar "Interface Icon Pack for Games and Software") | Verificar en ficha (histórico: uso libre con atribución) | 150+ iconos de interfaz de software (engranaje, guardar, cerrar, configuración) — para la barra de sistema del HUD. | 3 — útil como complemento de iconos de sistema, no de mobiliario visual del panel. |

**Lectura**: no existe un pack CC0 "tycoon-ready" fabricado a medida (como sí hay para mobiliario).
La ruta realista es **Kenney UI Pack como esqueleto estructural** (9-slice, botones, barras — probado
y sin fricción de licencia) + **recolor a nuestra paleta apagada** + posiblemente **wenrexa UI KIT**
para el tono "formulario/expediente" que pide la referencia de Two Point.

---

## 2. Iconos / Avisos

| Fuente | URL | Licencia | Qué contiene útil | Encaje |
|---|---|---|---|---|
| **game-icons.net** | https://game-icons.net/ | **CC BY 3.0** (requiere atribución — hay pantalla de créditos pendiente, así que es viable) | 4180+ iconos SVG/PNG. Categoría **Office** (29 iconos: objetos de escritorio) y **GUI** (142 iconos: interfaz genérica). Incluye **ID Card** (`delapouite/id-card`) directamente útil para trámite DNI. Buscar también "stamp", "folder", "envelope", "police", "handcuffs" dentro del catálogo — no confirmado cada uno individualmente pero el catálogo es lo bastante grande para cubrir sello/carpeta/aviso. | 5 — SVG monocromo vectorial, se recolorea y escala sin pérdida a cualquier paleta; es el estándar de facto para iconografía de juego con atribución. |
| **Kenney — Game Icons + Game Icons Expansion** | https://kenney.nl/assets/game-icons / https://kenney.nl/assets/game-icons-expansion | CC0 1.0 | 105 + 60 iconos genéricos de juego (monedas, corazones, flechas, engranajes). | 3 — útil para iconos de sistema (dinero, alerta genérica) pero no cubre trámites específicos (DNI/pasaporte/denuncia). |
| **Kenney — Input Prompts** | https://kenney-assets.itch.io/input-prompts | CC0 1.0 | 1280+ iconos de teclado/ratón — para tooltips de controles si se documentan atajos. | 2 — fuera del alcance de "avisos de trámite", solo aplicable a UI de controles. |
| **Icons8 "Bureaucracy" set** | https://icons8.com/icons/set/bureaucracy | **Licencia comercial/atribución variable — VERIFICAR antes de usar** (Icons8 mezcla planes gratuitos con atribución obligatoria y planes de pago; no confirmado CC0/CC BY puro) | Set temático de burocracia (sellos, formularios, archivadores) — el más "a medida" para trámites, pero licencia dudosa. | 3 potencial, pero **NO USAR sin confirmar la licencia exacta del set concreto** — riesgo de que sea "free with attribution + link back" no compatible con nuestro modelo de créditos. |

**Lectura**: game-icons.net es la columna vertebral (CC BY, catálogo enorme, estilo vectorial plano
que se recolorea perfecto) — cubre el aviso genérico y buena parte del glifo de trámite (ID Card
confirmado). Los iconos *muy* específicos (pasaporte español, denuncia) probablemente no existen
tal cual en ningún banco CC y habrá que componerlos a partir de piezas de game-icons.net (carpeta +
sello + documento) en vez de buscar un icono ya hecho.

---

## 3. Objetos / Mobiliario

| Fuente | URL | Licencia | Qué contiene útil | Encaje |
|---|---|---|---|---|
| **poly.pizza — piezas sueltas J-Toastie** (mismo autor de CUTES) | https://poly.pizza (buscar por autor J-Toastie) | **Mixta: CC0 y CC BY según modelo** — confirmado que J-Toastie publica ambas licencias distintas por pieza (p.ej. el City Pack es mayoritariamente CC BY); **hay que comprobar la licencia de CADA modelo individual antes de usarlo**, no asumir CC0 porque los CUTES lo sean. Incluye **Air Conditioner** y **Coffee Machine** ya del mismo autor. | 5 — mismo lenguaje de modelado y paleta que los CUTES; cero fricción de estilo al re-renderizar con la misma cámara/luz. Es la primera fuente a mirar para huecos puntuales. |
| **poly.pizza — catálogo abierto (multi-autor)** | https://poly.pizza/search/... | Filtrar por CC0 en cada ficha (el buscador permite filtro de licencia) | Confirmados en la búsqueda: **Printer** (Mikael Ganehag Brorsson), **Coffee Machine** (Zsky), **Vending Machine** (Anastasiia Ku) — cubren 3 de los huecos pedidos (impresora, café, vending) en low-poly suelto. | 4 — hay que homogeneizar nivel de detalle/paleta entre autores distintos (regla de post-proceso ya prevista en el plan de calidad), pero la geometría base es compatible. |
| **Kenney — Furniture Kit** | https://kenney.nl/assets/furniture-kit | CC0 1.0 | 140 assets: sillas (oficina, acolchada, redondeada), mesas, estanterías, cocina (nevera, fregadero), lámparas, sofás. Incluye **renders isométricos en 4 ángulos y topdown** ya generados — directamente aprovechable como referencia de encuadre. Cubre **nevera, sillas de oficina, lámparas**. | 4 — geometría muy simple/cúbica (estilo Kenney "cubitos"), algo menos orgánica que los CUTES/Isometric office; sirve mejor para props secundarios que para piezas hero. |
| **KayKit — Furniture Bits** (Kay Lousberg) | https://kaylousberg.itch.io/furniture-bits | **CC0** | 50+ modelos de mobiliario para interiores/decoración, atlas de gradiente único (1024×1024, reescalable a 128×128) — filosofía de "atlas de color plano" muy cercana a la nuestra. | 5 — el uso de un atlas de gradiente plano es literalmente la misma técnica que buscamos para homogeneizar "grano" entre packs; muy buen candidato para sillas de oficina/archivadores/taquillas genéricas. |
| **KayKit — City Builder Bits** | https://kaylousberg.itch.io/city-builder-bits | CC0 | Piezas de construcción de ciudad a escala de edificio (no de mobiliario interior) — más relevante para el bloque 4 (Entorno) que para mobiliario de comisaría. | 3 para interiores / 4 para exterior — ver bloque 4. |
| **KayKit — Restaurant Bits** | https://kaylousberg.itch.io/restaurant-bits | CC0 | 140+ props de cocina/hostelería — candidato para **máquina de café**, **nevera**, mostrador de bar (reutilizable como base del "mostrador de recepción"). No confirmado en la búsqueda si incluye vending; sí confirmado que es el mismo universo estético que Furniture Bits (mismo autor, mismo atlas). | 4 — mismo autor/atlas que Furniture Bits, coherencia asegurada si se combinan ambos packs de KayKit. |
| **Quaternius — Ultimate House Interior Pack / LowPoly House Interior Pack** | https://poly.pizza/bundle/Ultimate-House-Interior-Pack-2SXnFbwFzm | CC0 | 80-120+ modelos: puertas, ventanas, cocina, baño — relevante sobre todo para **puertas/ventanas del edificio** (carencia señalada en el plan de calidad, Fase 3) más que para mobiliario de oficina puro. | 4 — low-poly limpio, generoso en piezas de "andamio" (puertas/ventanas) que hoy nos faltan. |
| **misticwatermelon — Melon's Low Poly Office** | https://misticwatermelon.itch.io/melons-low-poly-office | Verificar en ficha (no confirmada como CC0/CC BY en la búsqueda — **revisar antes de usar**) | Pack de oficina low-poly adicional; potencial cantera de props de oficina genéricos. | Sin evaluar (licencia no confirmada) — no priorizar hasta verificar. |
| **digitalsin / "Low Poly Office Essentials"** | https://digitalsin.itch.io/low-poly-office-essentials | "Pay what you want" — **licencia de uso no confirmada como CC0/CC BY/MIT explícita en la búsqueda; revisar ficha antes de usar** | 45+ props: monitor retro, teclado, silla de oficina, mesa, **archivador con cajones que abren**, lámpara de pie, carpeta, taza de café, personaje sin riggear. El archivador con cajones es justo la pieza "taquilla/archivador" que falta. | 4 potencial, pendiente de confirmar licencia exacta antes de tocar el asset. |

**Huecos NO cubiertos por ninguna fuente encontrada con licencia clara**: equipamiento
específicamente **policial** (celdas con barrotes, mostrador de recepción tipo comisaría, taquillas
de vestuario). Las búsquedas de "police station props free low poly CC0" devuelven sobre todo
marketplaces de pago (CGTrader, TurboSquid, Sketchfab con licencias por modelo, no packs CC
verificados). **Recomendación realista**: componer estas piezas a partir de KayKit Furniture Bits
(taquillas ≈ armarios altos) + Kenney Furniture Kit (mostrador ≈ combinación de mesa alta + panel)
en vez de buscar más un pack "policial" dedicado que probablemente no existe en CC0/CC BY.

---

## 4. Entorno (exterior/urbano)

| Fuente | URL | Licencia | Qué contiene útil | Encaje |
|---|---|---|---|---|
| **Kenney — City Kit (Commercial)** | https://kenney.nl/assets/city-kit-commercial | CC0 1.0 | 50+ modelos: fachadas comerciales, toldos, remates de edificio, rótulos — compatible con City Kit (Roads). Buen candidato para la fachada de la propia comisaría vista desde fuera. | 4 — low-poly modular, mismo lenguaje "cubitos" que Kenney Furniture; combina bien si el exterior se trata con un poco menos de detalle que el interior. |
| **Kenney — City Kit (Roads)** | https://kenney.nl/assets/city-kit-roads | CC0 1.0 | Calzada, aceras, cruces, marcas viales modulares. | 4 — pieza base imprescindible para cualquier calle; sin esto no hay "exterior" navegable. |
| **Kenney — City Kit (Suburban)** | https://kenney.nl/assets/city-kit-suburban | CC0 1.0 | 40 modelos de casas + variaciones de color, vallas, entradas de coche. Confirmado que incluye vallas y árboles de acompañamiento. | 3 — más "barrio residencial" que "calle de comisaría urbana"; útil como fondo lejano, no como primer plano. |
| **Kenney — Car Kit** | https://kenney.nl/assets/car-kit | CC0 1.0 | 45+ modelos: sedán, furgoneta, **ambulancia** (confirmado) — la ambulancia es plantilla directa para recolorear un **coche de policía** (misma silueta de vehículo de emergencia con barra de luces). Incluye ruedas sueltas y escombros. | 5 — es literalmente la base que necesitamos: silueta de vehículo de emergencia lista para reskinear a blanco/azul CNP. |
| **Kenney — Nature Kit** | https://kenney.nl/assets/nature-kit | CC0 1.0 | 330 props de exterior: árboles, setos, rocas, elementos de jardín/calle para vestir aceras y accesos. No confirmado en la búsqueda si incluye farola/banco/boca de riego específicos — **revisar el listado completo del pack al descargar**. | 4 — volumen enorme y mismo "cubito" que el resto de Kenney, coherencia asegurada; hay que comprobar item a item qué mobiliario urbano concreto trae. |
| **KayKit — City Builder Bits** | https://kaylousberg.itch.io/city-builder-bits | CC0 | Piezas de construcción urbana a escala de edificio/manzana, pensadas para RTS/city-builder — otro ángulo de "calle" más orgánico que Kenney. | 4 — mismo atlas plano que el resto de KayKit; buena opción si se prefiere ese acabado sobre el de Kenney para el exterior. |

**Lectura**: el bloque de entorno es el mejor cubierto de los cuatro — Kenney solo (City Kit Roads +
Commercial + Car Kit + Nature Kit) da una calle completa y navegable en CC0 puro, sin mezclar
fuentes ni dudas de licencia. La pieza más valiosa encontrada es el **Car Kit → ambulancia como base
del coche de policía** (mismo tipo de silueta, ya pensado para reskinear).

---

## RECOMENDACIÓN: por dónde empezar

**Top 3 acciones concretas** (criterio: mayor hueco cerrado por menor riesgo de licencia/estilo):

1. **Bajar Kenney — Car Kit (CC0) y recolorear la ambulancia a coche de policía CNP.** Cierra de
   golpe el vehículo que falta en el bloque Entorno con cero riesgo de licencia y una silueta ya
   pensada para vehículo de emergencia — el ítem de mayor impacto/menor esfuerzo de toda la lista.

2. **Bajar KayKit — Furniture Bits + Restaurant Bits (ambos CC0, mismo autor y mismo atlas de
   gradiente) para cerrar de una vez impresora, máquina de café, nevera, vending y archivador/
   taquilla.** Al compartir atlas entre los dos packs, se evita el problema de "grano" desigual
   que ya señaló la auditoría de calidad — es la fuente que más huecos de mobiliario cierra con
   una sola descarga coherente.

3. **Adoptar game-icons.net (CC BY) como banco único de iconografía de trámites/avisos** y
   dar de alta la pantalla de créditos pendiente ahora — es la pieza de infraestructura legal que
   el plan de calidad ya marca como obligación antes de build público, y desbloquea in mediatamente
   los iconos de los 17 trámites sin depender de un pack "a medida" que no existe.

*(UI/Menús queda deliberadamente fuera del top 3: Kenney UI Pack + wenrexa UI KIT son suficientes
como esqueleto, pero requieren trabajo de diseño propio — recolor y composición del "expediente
ministerial" — antes de aportar valor visible; no es una descarga que cierre un hueco por sí sola.)*
