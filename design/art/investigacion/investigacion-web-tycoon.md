# Investigación web — Cómo resuelven el arte los tycoon isométricos 2D reales

> Encargo: Art Director, proyecto "Comisario" (tycoon 2D isométrico, Godot 4.6,
> sprites pre-renderizados desde 3D low-poly, rejilla 2:1 de 80×40 px,
> personajes de 44 px). Objetivo: evidencia externa (postmortems, devlogs, GDC,
> docs técnicas, wikis de modding) de cómo los juegos reales resuelven los
> mismos problemas que estamos sufriendo ahora mismo: cámara descalibrada,
> muebles estirados, anclas desviadas de la rejilla, personajes "sueltos" del
> mostrador.
>
> Estado: COMPLETO (6/6 secciones + lista de 10 principios + fuentes).

---

## 1. Estructura del arte: pre-renderizado, cámara, pivote, escala maestra

1. **RollerCoaster Tycoon (Chris Sawyer, 1999)** modelaba cada objeto en 3D
   (Lightwave V5.6, Raydream Studio, trueSpace V2...) y lo **pre-renderizaba**
   a bitmaps ya congelados; muchos modelos tenían mucho más detalle del que
   se ve en pantalla porque se renderizaban muy pequeños — es decir, el
   3D de origen SIEMPRE era más "rico" que el sprite final, nunca al revés.
   Fuente: [chrissawyergames.com/feature3.htm](https://www.chrissawyergames.com/feature3.htm)
2. **La proyección estándar del género NO es isometría real (30°), es
   "dimétrica 2:1"**: por cada 2 px que te mueves en horizontal, bajas 1 px
   en vertical (~26.57°). Se eligió porque las líneas a 30° generan
   diagonales con aliasing feo en píxel art, y el 2:1 da una diagonal limpia
   y matemática simple para el tile. Fuentes:
   [the-pixel.art](https://the-pixel.art/articles/isometric-pixel-art/),
   [pikuma.com](https://pikuma.com/blog/isometric-projection-in-games),
   [gridmakerpro.com](https://gridmakerpro.com/grids/perspective/dimetric/)
3. **Los tamaños de tile estándar respetan siempre esa proporción 2:1**
   (32×16, 64×32...); la altura del tile es la mitad de su anchura por
   definición. Nuestra rejilla **80×40 cumple exactamente esa proporción
   canónica del género** — no es una elección rara, es la convención.
   Fuentes: [pixelparmesan.com](https://pixelparmesan.com/blog/fundamentals-of-isometric-pixel-art),
   [clintbellanger.net](https://clintbellanger.net/articles/isometric_intro/),
   [screamingbrainstudios.com](https://screamingbrainstudios.com/isometric-grids/)
4. **Convención de pivote: base/centro-inferior del sprite**, siempre. Es el
   punto que se ancla a la posición lógica de la celda y el que se usa para
   el orden de dibujo (en motores con sprite sorting explícito, el "sort
   point" se fija al pivote, nunca al centro del bounding box). Usar un
   pivote distinto por categoría de asset es la causa típica de que "un
   mueble se vea flotando" o "un personaje se hunda en el suelo". Fuente:
   [Unity Discussions — transparency sort axis](https://discussions.unity.com/t/help-needed-transparency-sort-axis-on-sprites-for-isometric-game/1585664)
5. **Prison Architect deliberadamente NO usa isometría real ni 3D
   pre-renderizado**: es una vista cenital inclinada ("tilted top-down"),
   elegida por motivos prácticos de alcance — los personajes sin
   extremidades no necesitan animación de piernas/brazos, lo que aceleró
   muchísimo la producción y facilitó el modding. Es una decisión de
   ALCANCE tomada dentro del propio lenguaje visual, no solo estética.
   Fuente: [discusión Steam — top-down vs isométrico](https://steamcommunity.com/app/233450/discussions/0/622955136054243996)
6. **La escala maestra se fija ANTES de producir ningún asset y no se toca
   después.** La práctica estándar en producción 3D (aplicable 1:1 a
   nuestro caso, "3D low-poly → sprite") es mantener un **kit de referencia
   de escala permanente**: una figura humana, una vara de medida conocida,
   un marco de puerta, una silla, una mesa — y comparar CADA asset nuevo
   contra ese kit antes de aprobarlo, nunca evaluarlo aislado. Fuente:
   [3dskillup.art — Consistent Scale Across 3D Assets](https://3dskillup.art/consistent-scale-across-3d-assets/)

---

## 2. Personajes + muebles: anclaje de "sentado", offsets, oclusión

**Este es el hallazgo más importante de todo el documento — coincide
exactamente con nuestro problema actual.**

1. **Theme Hospital (Bullfrog, 1997) — LA solución canónica al "personaje
   sentado pegado al mueble".** El juego NO intenta alinear en tiempo real
   dos sprites autónomos (doctor + silla) esperando que coincidan a ojo. En
   vez de eso: el doctor camina hasta un **"punto de entrada" definido por
   el propio mueble**, y al llegar, el motor **fusiona doctor + silla en UN
   solo sprite ya compuesto**, que es el que se anima. El jugador nunca ve
   la costura. Fuente:
   [GamesRadar — The making of Theme Hospital](https://www.gamesradar.com/the-making-of-theme-hospital-the-legendary-sim-that-paved-the-way-for-two-point-hospital/)
   → **Aplicación directa**: el problema de "personaje suelto a una celda
   del mostrador" no se arregla afinando offsets a ojo; se arregla
   pre-componiendo la pose de interacción (personaje+mueble) como una
   unidad visual única para ese estado concreto.
2. **The Sims — el punto de anclaje ("slot") vive en el MUEBLE, no en el
   personaje.** Cada objeto define sus propios "routing slots": posición,
   orientación/rotación y referencia de animación. El personaje no calcula
   dónde sentarse: **el mueble le dice** dónde y hacia dónde mirar, y el
   hueso raíz de la animación de sentarse apunta directamente a ese slot.
   Fuentes: [SimsWiki — SLOT](https://simswiki.info/wiki.php?title=SLOT),
   [Sims4Studio — create routing slots](https://sims4studio.com/thread/13970/create-objects-routing-slots-interactions)
3. **Prison Architect aplica el mismo principio a la ORIENTACIÓN**: cada
   objeto define sprites propios por cada una de las 4 direcciones que
   puede encarar (front/back/left/right) en vez de rotar automáticamente
   una única pieza de arte. Es el mismo "no confiar en el runtime para
   alinear algo que se puede definir a mano de antemano", aplicado a
   rotación en vez de a posición. Fuente:
   [RotateTypes Explained](https://prisonarchitect.paradoxwikis.com/RotateTypes_Explained)
4. **Stonehearth (colonia voxel isométrica)** define el punto de anclaje de
   cada modelo como una coordenada explícita relativa al origen local del
   propio modelo (0,0,0); la wiki de modding avisa expresamente de que si
   un modelo no está centrado siguiendo esa convención, "queda alineado de
   forma rara". Esto confirma que **el desajuste de anclaje es un fallo
   recurrente y conocido en todo el género**, no un síntoma de
   principiante. Fuente:
   [Stonehearth — modding guide (modeling)](https://stonehearth.github.io/modding_guide/modding_guide/basic/art/modeling/index.html)
5. **Consecuencia práctica para nuestro pipeline** (3D low-poly → sprite,
   igual que RCT/Theme Hospital): tenemos una ventaja que conviene explotar
   a fondo — el punto de anclaje se puede definir **en la propia escena 3D**
   (un null/empty en el asiento de la silla, a nivel de suelo bajo el
   personaje) y hornear la proyección en píxeles de ESE punto como metadato
   del sprite, en vez de calcular el offset a ojo después de exportar.
6. **La oclusión de un personaje sentado detrás de un mostrador/mueble alto
   se trata como un ESTADO autorizado, no como un efecto lateral del
   sorting genérico**: la técnica habitual (estilo Diablo 2 y similares) es
   que, al entrar en el estado "sentado/detrás", el objeto que ocluye
   cambia de alpha o el personaje cambia explícitamente de profundidad de
   dibujo — una regla deliberada para ese caso, no algo que se espera que
   "simplemente funcione" con la regla general de y-sort. Fuentes:
   [Isometric Occlusion — justindjohnson.com](https://justindjohnson.com/softdev/isometric-occlusion/),
   [GameDev.net — transparent walls in isometric view](https://gamedev.net/forums/topic/324328-transparent-walls-with-isometric-view/)

---

## 3. Orden de dibujo: painter's algorithm / y-sort, empates, objetos multi-celda

1. La regla base de todo juego iso 2D es ordenar por una clave de
   profundidad derivada de la celda (típicamente `x+y`), en un barrido
   "diagonal a diagonal". Pero **dentro de la misma diagonal (mismo
   `x+y`) el orden es ambiguo por definición** a menos que exista una
   regla de desempate explícita (capa/nivel-y, prioridad manual...). Los
   empates no son un bug de implementación: son una propiedad estructural
   del algoritmo. Fuentes:
   [GameDev.net — Isometric Tile Render Order](https://gamedev.net/forums/topic/719280-isometric-tile-render-order/5471970/),
   [mazebert.com — Isometric depth sorting](https://mazebert.com/forum/news/isometric-depth-sorting--id775/)
2. **Los objetos multi-celda (p.ej. un mostrador de 3 celdas) rompen el
   sorting simple por-celda** porque ocupan varias claves de profundidad a
   la vez. El painter's algorithm por sí solo NO tiene una ordenación
   global garantizada cuando los objetos se solapan parcialmente en más de
   un eje; la solución matemáticamente correcta es un **orden topológico**
   sobre un grafo de relaciones "A está detrás de B" objeto-a-objeto (no
   celda-a-celda). Fuentes:
   [Wikipedia — Painter's algorithm](https://en.wikipedia.org/wiki/Painter%27s_algorithm),
   [GameDev.net — Isometric Depth Sorting in O(n) or less](https://www.gamedev.net/forums/topic/579515-isometric-depth-sorting-in-on-or-less/)
3. **Simplificación estándar de producción** para evitar el problema
   general de sorting multi-celda: dar a cada objeto colocable un único
   "punto caliente" de ordenación (normalmente su celda frontal/inferior),
   y tratar el resto de celdas que ocupa como huecos de bloqueo sin efecto
   en el sorting. El orden se calcula UNA vez por objeto usando ese punto,
   no una vez por celda ocupada — evita la complejidad topológica en el
   caso común. (Síntesis a partir de la discusión de sorting topológico +
   el patrón de "celda ancla" visto en sistemas de colocación tipo Prison
   Architect / Sims.)
4. **La clave de orden debe salir siempre del mismo punto de referencia por
   sprite** — su pivote/base, nunca el centro del bounding box (coherente
   con el punto 1.4). Mezclar estrategias de sort-key entre categorías de
   objeto (unos por centro, otros por base) es la causa citada
   repetidamente de "objetos que se ordenan mal solo cuando se solapan
   parcialmente". Fuente:
   [Unity Discussions — Sprite Sort Point](https://discussions.unity.com/t/help-needed-transparency-sort-axis-on-sprites-for-isometric-game/1585664)
5. **Caso límite señalado una y otra vez en foros: objetos largos y finos
   en diagonal** (vallas, mostradores, colas de gente) — porque pueden
   estar legítimamente por delante de una celda vecina y por detrás de
   otra a lo largo de su propia longitud. Es exactamente el caso para el
   que existe el enfoque topológico, y exactamente donde el `x+y` simple
   falla — coincide punto por punto con nuestro problema de mostrador
   multi-celda.

---

## 4. Kits modulares: por qué los muebles multi-celda no se estiran

1. **Principio universal ("measure once")**: se fija UNA dimensión de
   módulo base, y cualquier otro módulo del kit es un múltiplo o fracción
   exacta de esa dimensión. Nunca se escala un módulo de forma no uniforme
   para rellenar un hueco — se autoriza un módulo NUEVO del tamaño que
   falta. Esto es, literalmente, el porqué de que un mueble no se deba
   "estirar": estirar rompe la unidad compartida que hace funcionar el kit.
   Fuente: [The Level Design Book — Modular kit design](https://book.leveldesignbook.com/process/blockout/metrics/modular)
2. **Corolario directo**: si cambias la granularidad de la rejilla del kit
   después de haber construido contenido sobre ella, tienes que
   reconstruir TODO lo que dependía de la rejilla vieja. Por eso la escala
   maestra (rejilla 80×40, personaje 44 px) debe fijarse primero y tratarse
   como inmutable una vez arrancada la producción — enlaza directamente con
   el punto 1.6. Misma fuente.
3. **Los mostradores/barras largas se construyen como una TIRADA de piezas
   discretas**: remate izquierdo + N piezas centrales repetibles + remate
   derecho — nunca como una única pieza continua escalada a la longitud
   necesaria. Es el patrón estándar con el que los kits modulares resuelven
   tiradas de longitud variable (barras, vallas, cintas transportadoras)
   sin estirar ningún asset individual. (Síntesis de la literatura de kits
   modulares + estructura habitual de packs "modular isometric assets" en
   itch.io + práctica general de kit-bashing.)
4. **Prison Architect refuerza la misma idea desde el lado de datos**: en
   vez de un objeto que escala, cada objeto colocable de su base de datos
   es una unidad de huella fija con su propio sprite autorado por cara;
   montar una tirada más larga significa colocar varios objetos discretos
   uno junto a otro, gobernados por las reglas de RotateType para que los
   bordes adyacentes encajen. Fuentes:
   [Objects.spritebank](https://prisonarchitect.paradoxwikis.com/Objects.spritebank),
   [RotateTypes Explained](https://prisonarchitect.paradoxwikis.com/RotateTypes_Explained)
5. **Disciplina de verificación recomendada por la misma fuente de kits
   modulares**: tras construir el kit, montar una escena de PRUEBA usando
   solo piezas del kit y recorrerla/inspeccionarla antes de tocar contenido
   de producción, específicamente para pillar errores de escala/alineación
   mientras son baratos de arreglar — es el mismo espíritu que las escenas
   de diagnóstico que ya existen en el proyecto (`tools/_diag_obj042.tscn`,
   `tools/_diag_textura.tscn`): esa práctica ya adoptada coincide con lo
   que la literatura recomienda como buena praxis, no es un parche
   improvisado.

---

## 5. Mezcla de packs de assets: riesgos y homogeneización

1. **El desajuste de escala es el riesgo #1 señalado al mezclar packs de
   fuentes distintas.** La solución estándar en pipelines 3D es el mismo
   "kit de referencia de escala" del punto 1.6 (figura humana + prop de
   altura conocida + puerta + silla + mesa): cada asset nuevo se compara
   codo con codo contra ese kit antes de aprobarse, nunca se evalúa aislado.
   Fuente: [3dskillup.art — Consistent Scale Across 3D Assets](https://3dskillup.art/consistent-scale-across-3d-assets/)
2. **Checklist práctico** de la misma fuente: fijar una convención de
   unidades única, verificar dimensiones reales de cada asset contra el kit
   de referencia, mantener densidad de textura (texel density) consistente,
   y validar transform/pivote **dentro del motor destino** (no solo en la
   herramienta de modelado) antes de dar por bueno el asset.
3. **Consenso de devs indie que mezclan/crean assets a mano** (hilo de
   itch.io): la consistencia se logra con REGLAS mecánicas, no con "buen
   ojo" caso a caso — (a) lienzo/canvas fijo por categoría de sprite, (b)
   paleta de color compartida y restringida, (c) una fórmula aplicada
   igual a todos los assets (p.ej. mismo grosor de contorno en todo), (d)
   dejarlo escrito en una guía de estilo desde el día uno para que no se
   desvíe según se van añadiendo piezas. Fuente:
   [itch.io — "How do indie developers keep their game's art style consisten?"](https://itch.io/t/6707598/how-do-indie-developers-keep-their-games-art-style-consisten)
4. Estudios con varios artistas resuelven el mismo problema comparando
   cada asset nuevo contra un único **"hero asset"** de referencia en cada
   punto de revisión — es el PROTOCOLO de revisión, no el ojo individual de
   cada artista, lo que mantiene coherente un pipeline mixto. (Fuente
   secundaria — blog especializado, tratar como orientativa, no como caso
   de estudio verificado: [nastyrodent.com](https://nastyrodent.com/stylized-3d-characters-art-direction-principles/))
5. Cuando los packs vienen de familias de estilo genuinamente distintas (no
   solo de escala distinta), el patrón de integración más seguro **no es
   intentar reconciliar la geometría/textura de origen**, sino unificar con
   un paso de POST-PROCESO compartido y aplicado por igual a todo: mismo
   contorno, mismo clamp de paleta/gradación de color, misma dirección de
   luz/rim light — así el ojo lee "un solo estilo" aunque las mallas de
   origen sean distintas. Coincide con la práctica del género de
   pre-renderizar todo bajo un único rig de iluminación fijo (ver sección
   1).

---

## 6. Casos reales de equipos pequeños / solo dev

1. **Big Pharma (Twice Circled, 2015)** — tycoon isométrico hecho por un
   estudio de **UNA sola persona** (Tim Wicksteed, diseño + programación),
   con ayuda solo de freelance para arte y audio. Prueba de que un tycoon
   isométrico visualmente coherente es alcanzable sin equipo de arte
   interno grande, siempre que el arte freelance se dirija contra una
   especificación cerrada (no contra "ya lo veremos"). Fuentes:
   [Wikipedia — Big Pharma (video game)](https://en.wikipedia.org/wiki/Big_Pharma_(video_game)),
   [Wikipedia — Twice Circled](https://en.wikipedia.org/wiki/Twice_Circled)
2. **Going Medieval (Foxy Voxel, ~9 personas, Serbia)** — eligió arte
   **voxel** específicamente porque los vóxeles son baratos de iterar y
   estructuralmente imposibles de desajustar en escala (todo se construye
   desde el mismo cubo unidad), renderizado en tiempo real desde cámara
   isométrica en vez de exigir una pasada de pre-render por asset/animación.
   Es una estrategia DISTINTA a la nuestra (3D pre-renderizado a sprite),
   pero el motivo de fondo — "elegir un método de producción que hace la
   consistencia el comportamiento POR DEFECTO, no algo que hay que vigilar
   a mano" — aplica igual. Fuentes:
   [foxyvoxel.io](https://foxyvoxel.io/),
   [ScreenRant — Foxy Voxel interview](https://screenrant.com/foxy-voxel-interview-going-medieval-early-access/)
3. **Rise of Industry** (equipo pequeño) va un paso más allá: no usa
   sprites pre-renderizados en absoluto, renderiza los modelos 3D reales en
   vivo desde una cámara fija de estilo isométrico. Cambia el pipeline "un
   render, muchos bitmaps pequeños" (RCT/Theme Hospital) por "autora una
   vez en 3D, deja que el motor lo proyecte cada frame" — esto elimina de
   raíz toda la clase de bugs de pivote/anclaje que estamos sufriendo,
   porque la posición/rotación se calcula en vivo en espacio 3D en vez de
   hornearse en offsets de píxeles. Se cita como modelo de referencia
   alternativo, aunque cambiar de pipeline ahora esté fuera de alcance.
   Fuente: [discusión Steam — "Is this 3D or sprites?"](https://steamcommunity.com/app/671440/discussions/0/2860219962101423819/)
4. **Hilo común a TODOS los casos pequeños encontrados**: ninguno intentó
   producir arte a medida bajo presión de tiempo SIN fijar antes una
   convención técnica rígida — cubo unidad para los equipos voxel, rig de
   cámara/luz fijo para los equipos de pre-render, rejilla dimétrica fija
   para los equipos de píxel art. La convención llega ANTES de producir
   contenido, no después de que ya existan assets sueltos. Es el mismo hilo
   que conecta la sección 1 ("escala maestra") y la sección 4 ("measure
   once").

---

## 10 principios de un tycoon isométrico profesional (lista de auditoría)

1. **La proyección y la rejilla son UNA decisión, tomada UNA vez, antes de
   producir ningún asset**: proporción 2:1 dimétrica (~26.57°), tamaño de
   celda y altura del personaje se fijan al principio y no se tocan después
   (RCT; Level Design Book, "measure once"). Nuestra rejilla 80×40 ya
   cumple la proporción canónica del género.
2. **Cada sprite se posiciona por UN pivote único y coherente** (base /
   centro-inferior) — nunca por el centro del bounding box, nunca mezclando
   convenciones entre categorías de asset (Unity Sprite Sort Point;
   convención general del género).
3. **El anclaje de una interacción (dónde se sienta, dónde se apoya, dónde
   entra) es un DATO que vive en el MUEBLE**, no una coincidencia calculada
   en tiempo de juego entre dos sprites independientes (The Sims: slots;
   Stonehearth: attach point del modelo).
4. **Las poses de interacción compleja se resuelven pre-componiendo
   personaje+mueble como una sola unidad visual para ese estado concreto**,
   en vez de alinear dos piezas independientes con matemática de offset
   (Theme Hospital: fusión doctor+silla en un único sprite).
5. **Ningún mueble se estira para ocupar varias celdas**: los elementos
   multi-celda son KITS — remate + módulo repetible + remate — montados,
   nunca escalados de forma no uniforme (Level Design Book; Prison
   Architect: objetos de huella fija).
6. **El orden de dibujo nunca se apoya solo en "y de la celda"**: los
   objetos multi-celda necesitan una regla de desempate explícita (punto
   caliente único por objeto, o un orden topológico) porque el painter's
   algorithm por sí solo no resuelve solapamientos parciales (GameDev.net;
   Wikipedia — Painter's algorithm).
7. **Cada objeto orientable define sus propios sprites por dirección**, no
   se rota automáticamente una sola pieza de arte esperando que cuele en
   todas las orientaciones (Prison Architect: RotateType).
8. **La oclusión de un personaje detrás de un mueble alto es un ESTADO
   deliberado y autorizado** (fundido/alpha o cambio explícito de
   profundidad al entrar en "sentado/detrás"), no un efecto colateral
   accidental del sorting genérico (técnica tipo Diablo 2).
9. **Al mezclar fuentes de assets, la escala se verifica SIEMPRE contra un
   kit de referencia fijo** (figura humana, silla, mesa, puerta) antes de
   aprobar la pieza — nunca a ojo, nunca aislada (3dskillup.art).
10. **La consistencia visual final se garantiza con reglas mecánicas
    aplicables a todo** (paleta cerrada, mismo grosor de contorno, mismo
    rig de luz/cámara de render, mismo lienzo por categoría), documentadas
    en un art bible desde el día uno — no con "buen ojo" caso a caso
    (consenso itch.io; práctica RCT/Theme Hospital de rig de render fijo).

---

### Cómo se relacionan estos principios con lo que ya nos ha dolido

- **Cámara descalibrada** → principio 1 (rejilla/proporción fijada una vez,
  nunca ajustada asset a asset).
- **Muebles estirados / gigantes** → principios 1, 5 y 9 (escala maestra +
  kits modulares + verificación contra kit de referencia, en vez de
  escalar a ojo hasta que "se vea bien").
- **Anclas desviadas de la rejilla** → principios 2 y 3 (pivote único +
  anclaje como dato del mueble, no coincidencia calculada a mano).
- **Personaje "suelto" a una celda del mostrador** → principio 4, el
  hallazgo central de la sección 2 (Theme Hospital): esa pose necesita
  tratarse como una composición dedicada personaje+mueble, no como dos
  sprites independientes que "deberían" alinearse solos.

Ninguno de estos cuatro fallos es exclusivo de un equipo pequeño o
principiante: **son, literalmente, los mismos problemas documentados en
juegos profesionales y en wikis de modding de juegos AAA del género**
(Prison Architect, Theme Hospital, Stonehearth, The Sims). La diferencia no
es si aparecen — es si el equipo tiene un mecanismo (anclaje en el mueble,
rejilla fija, kits modulares, escala maestra verificada) para que dejen de
aparecer una vez corregidos. Sí es posible hacer un tycoon isométrico
atractivo y sin fallos con un equipo pequeño — la evidencia (Big Pharma,
Going Medieval) lo confirma — siempre que la convención técnica se fije
ANTES de producir contenido y se defienda como regla, no como "ya lo
arreglaremos".

---

## Fuentes consultadas

**Pre-renderizado / cámara / escala maestra**
- Chris Sawyer Software Development — [RollerCoaster Tycoon graphics up close and personal](https://www.chrissawyergames.com/feature3.htm)
- [the-pixel.art — How Isometric Pixel Art Actually Works (the 2:1 Trick)](https://the-pixel.art/articles/isometric-pixel-art/)
- [pikuma.com — Isometric Projection in Game Development](https://pikuma.com/blog/isometric-projection-in-games)
- [gridmakerpro.com — Dimetric projection: the 2:1 grid at 26.57°](https://gridmakerpro.com/grids/perspective/dimetric/)
- [screamingbrainstudios.com — Isometric Grids Tutorial](https://screamingbrainstudios.com/isometric-grids/)
- [clintbellanger.net — Isometric Tiles Introduction](https://clintbellanger.net/articles/isometric_intro/)
- [pixelparmesan.com — Fundamentals of Isometric Pixel Art](https://pixelparmesan.com/blog/fundamentals-of-isometric-pixel-art)
- [3dskillup.art — Consistent Scale Across 3D Assets: Practical Guide](https://3dskillup.art/consistent-scale-across-3d-assets/)
- [Steam Community — Prison Architect: "Is this game top-down or Isometric?"](https://steamcommunity.com/app/233450/discussions/0/622955136054243996)

**Anclaje personaje-mueble / oclusión**
- [GamesRadar — The making of Theme Hospital](https://www.gamesradar.com/the-making-of-theme-hospital-the-legendary-sim-that-paved-the-way-for-two-point-hospital/)
- [SimsWiki — SLOT](https://simswiki.info/wiki.php?title=SLOT)
- [Sims4Studio — How to create object's routing slots for interactions](https://sims4studio.com/thread/13970/create-objects-routing-slots-interactions)
- [Prison Architect Wiki — RotateTypes Explained](https://prisonarchitect.paradoxwikis.com/RotateTypes_Explained)
- [Prison Architect Wiki — Objects.spritebank](https://prisonarchitect.paradoxwikis.com/Objects.spritebank)
- [Stonehearth — Modding guide: creating models](https://stonehearth.github.io/modding_guide/modding_guide/basic/art/modeling/index.html)
- [Justin D Johnson — Isometric Occlusion](https://justindjohnson.com/softdev/isometric-occlusion/)
- [GameDev.net — Transparent walls with isometric view](https://gamedev.net/forums/topic/324328-transparent-walls-with-isometric-view/)

**Orden de dibujo / sorting**
- [GameDev.net — Isometric Tile Render Order](https://gamedev.net/forums/topic/719280-isometric-tile-render-order/5471970/)
- [mazebert.com — Isometric depth sorting](https://mazebert.com/forum/news/isometric-depth-sorting--id775/)
- [GameDev.net — Isometric Depth Sorting in O(n) or less](https://www.gamedev.net/forums/topic/579515-isometric-depth-sorting-in-on-or-less/)
- [Wikipedia — Painter's algorithm](https://en.wikipedia.org/wiki/Painter%27s_algorithm)
- [Unity Discussions — Transparency Sort Axis on Sprites for Isometric Game](https://discussions.unity.com/t/help-needed-transparency-sort-axis-on-sprites-for-isometric-game/1585664)

**Kits modulares**
- [The Level Design Book — Modular kit design](https://book.leveldesignbook.com/process/blockout/metrics/modular)

**Mezcla de packs / consistencia**
- [itch.io — How do indie developers keep their game's art style consistent?](https://itch.io/t/6707598/how-do-indie-developers-keep-their-games-art-style-consisten)
- [nastyrodent.com — Stylized 3D Characters Done Right](https://nastyrodent.com/stylized-3d-characters-art-direction-principles/) *(fuente secundaria, orientativa)*

**Equipos pequeños / solo dev**
- [Wikipedia — Big Pharma (video game)](https://en.wikipedia.org/wiki/Big_Pharma_(video_game))
- [Wikipedia — Twice Circled](https://en.wikipedia.org/wiki/Twice_Circled)
- [foxyvoxel.io](https://foxyvoxel.io/)
- [ScreenRant — Foxy Voxel Interview: Going Medieval Early Access](https://screenrant.com/foxy-voxel-interview-going-medieval-early-access/)
- [Wikipedia — Going Medieval](https://en.wikipedia.org/wiki/Going_Medieval)
- [Steam Community — Rise of Industry: "Is this 3D or sprites?"](https://steamcommunity.com/app/671440/discussions/0/2860219962101423819/)

---

*Documento completo. Investigación realizada por el Art Director vía
WebSearch (2026-08-03) para el proyecto "Comisario".*
