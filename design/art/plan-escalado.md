# Plan de escalado — proporciones de Comisario

> Estado: v1 (2026-08-05). Formaliza una convención que YA se usaba en el pipeline de render
> (`tools/render_props_poly.gd`, `tools/_componer_props_soporte.gd`) pero que no estaba escrita en
> ningún sitio como referencia de diseño. Este documento es la fuente de verdad para "¿qué tamaño en
> píxeles debe tener X si mide Y metros en la vida real?".

## Cómo se hizo esta auditoría (léelo antes de confiar en los números)

Para los 7 objetos que vienen del pipeline `render_props_poly.gd` (cafetera, vending, impresora,
television, fuente_agua, taquilla, archivador) el "píxel medido" de la tabla del punto 3 **no es un
conteo de píxeles del PNG** — es la `altura_objetivo_m` que ese mismo script declara en su código y que
fuerza al renderizar (ver la cita del punto 5). Como el propio pipeline calcula el factor de escala
para que el render final ocupe exactamente esa altura, leer el código es tan fiable como medir el PNG
(y más barato).

Para el resto de mobiliario (mostrador, sillas, sofás, estanterías, papelera, dispensador, radio,
equipo informático) el pipeline que los generó (`tools/render_mobiliario.gd`) **no calibra por altura
real declarada**: calibra por HUELLA en planta (que el mostrador ocupe el 0,92 de una celda de
rejilla, ver `ESCALA_OBJETIVO_MOSTRADOR`). No hay ninguna cifra en el código de la que se pueda leer
"esto mide tantos metros de alto" — la altura es lo que sale una vez encajada la huella, no algo que
el pipeline controle. Auditar estos de verdad requiere contar píxeles del PNG.

Preparé un script para eso (`Image.load_from_file` + barrido de filas con alfa>0, patrón
`extends SceneTree`) pero **no pude ejecutarlo en esta sesión**: este agente no tiene una herramienta
de ejecución de procesos (no hay `Bash`/consola disponible, solo lectura/escritura de archivos). El
script quedó guardado en el scratchpad de la sesión, sin tocar `tools/`, con el comando exacto para
correrlo cuando alguien con esa herramienta (tú, o `technical-artist`) lo lance.

**Actualización (mismo día, 2026-08-05):** el coordinador ejecutó el script en su entorno y devolvió
la salida completa. Todas las filas que decían PENDIENTE en la tabla del punto 3 ya están rellenadas
con esa medición real de píxeles — no con una estimación de código. Los 7 valores que sí venían de
código (taquilla, vending, fuente_agua, cafetera, impresora, archivador, television) coinciden
exactamente con lo medido, lo que confirma que ese atajo metodológico era válido.

Y, aunque se ejecute el script: el alto útil de un sprite isométrico incluye la profundidad de la
base (el "escalón" de perspectiva de la peana), así que incluso una medición automática es
**orientativa**. El juez final sigue siendo la foto de fotomontaje con el muñeco al lado, no una
tabla de píxeles. Esta tanda de datos ya deja un ejemplo claro de ese efecto: los muebles con huella
más ancha (`mostrador_atencion2`, `asiento_sofa3`) miden bruscamente más alto que su versión de 1
celda pese a compartir la misma altura real de objeto — casi con toda seguridad es profundidad de
base, no el mueble creciendo. Se señala de forma cualitativa en el veredicto de esas filas, sin
inventar un porcentaje de descuento (ver nota abajo).

---

## 1. La ley del ancla

Todo en el juego se mide contra el muñeco de referencia (`girl_44px_*`, `assets/sprites/personajes/`):
**44 px = 1,70 m**. De ahí sale la única constante de conversión del proyecto:

```
PX_POR_METRO = 44 / 1.70 ≈ 25,882
px = metros × 25,882
```

Esto no es una propuesta nueva: ya vive en `tools/render_props_poly.gd` (líneas ~30-34, constantes
`ALTO_MUNECO_PX`, `ALTO_MUNECO_M`, `PX_POR_METRO`) y se reutiliza tal cual en
`tools/_componer_props_soporte.gd`. Este documento solo le pone nombre y lo convierte en referencia
de consulta para cualquier objeto nuevo.

### Tabla rápida de conversión

| Metros | Píxeles (redondeado) |
|---|---|
| 0,50 m | 13 px |
| 0,75 m | 19 px |
| 1,00 m | 26 px |
| 1,50 m | 39 px |
| 1,80 m | 47 px |
| 2,00 m | 52 px |
| 2,50 m | 65 px |
| 2,70 m | 70 px |

---

## 2. Medidas de arquitectura

| Elemento | Medida real | px | Por qué |
|---|---|---|---|
| Pared interior — edificio público | 2,70 m | 70 px | Los edificios públicos/oficinas (CTE y normativas similares) se construyen con techos más altos que una vivienda: hueco extra para climatización/instalaciones y, visualmente, "se siente" más institucional. Es la diferencia entre que la comisaría lea como oficina de verdad y no como un piso con mostradores metidos con calzador. |
| Pared interior — vivienda (referencia, NO se usa en la comisaría) | 2,50 m | 65 px | Altura mínima habitual en normativa de habitabilidad residencial. Se anota aquí solo para que quede claro por qué la comisaría NO usa esta cifra — si algún interior "doméstico" apareciera en el juego (casa de un NPC, por ejemplo), esta sería su referencia, no 2,70 m. |
| Puerta (hoja) | 2,03–2,10 m | 53–54 px | Cubre las dos convenciones habituales (puerta normalizada ~2,03 m / puerta europea 2,00–2,10 m). Para consistencia visual entre sprites, fijar 2,10 m (54 px) como valor único del proyecto salvo que se pida una puerta "baja" a propósito. |
| Ventana — antepecho (alto del alféizar desde el suelo) | ~1,00 m | 26 px | Altura típica para que una persona de pie vea al exterior sin agacharse ni tener el cristal a la altura de la cabeza. |
| Ventana — dintel (parte superior) | 2,10 m | 54 px | A propósito, coincide con la altura de puerta: en arquitectura real puertas y ventanas suelen alinear su línea superior (el "dintel corrido") — ayuda a que las paredes del juego lean como una fachada coherente en vez de aberturas puestas a ojo. |
| Mostrador de atención | 1,10 m | 28 px | Altura de barra de pie para atención al público (ligeramente por encima de una mesa de trabajo de 0,75 m: el ciudadano está de pie, el funcionario puede estar sentado detrás). |
| Rodapié | 0,07–0,10 m | 2–3 px | Aviso de "píxel mínimo": a 25,88 px/m, cualquier elemento menor a ~4 cm cae por debajo de 1 px. El rodapié es el caso límite del proyecto — en la práctica se dibuja como una franja de 1-2 px, no como una medida literal, o se pierde en el import. Cualquier detalle futuro más fino que esto (molduras, tiradores) necesita el mismo criterio: redondear a un mínimo dibujable, no perseguir el decimal. |

---

## 3. Tabla de objetos del catálogo

Leyenda de veredicto: **OK** (±10%, por construcción de código) · **REVISAR** (desviación real o
duda de diseño detectada) · **PENDIENTE** (pipeline por huella, sin dato de altura en código — hace
falta correr el script de medición) · **SIN SPRITE** (no existe todavía).

| Objeto | Medida real típica | px objetivo | Sprite actual | Desviación | Veredicto |
|---|---|---|---|---|---|
| Mostrador ventanilla (`mostrador_atencion`) | 1,10 m (altura de barra) | 28 px | **medido**: canvas 60×59, alto útil 51 px (~1,97 m) | +82% | **REVISAR** — incluye monitor/organizador sobre la barra (el objetivo 1,10 m no es 1:1 comparable con el bbox total) más profundidad de base; confirmar con fotomontaje si el plano de la barra sola queda cerca de 28 px |
| Mostrador ventanilla 2 celdas (`mostrador_atencion2`) | 1,10 m | 28 px | **medido**: canvas 100×74, alto útil 72 px (~2,78 m) | +157% | **REVISAR** — mucho más alto que la versión de 1 celda pese a compartir altura real de objeto; probablemente la huella más ancha infla el alto aparente por profundidad de base isométrica (ver aviso metodológico), pero conviene comparar visualmente contra `mostrador_atencion_0` |
| Mesa de trabajo | 0,75 m | 19 px | **no existe sprite en el catálogo** | — | SIN SPRITE |
| Silla — asiento (altura de anclaje, no bbox) | 0,45 m | 12 px | — (referencia interna, no se mide como sprite) | — | — |
| Silla de espera (`silla_espera`), alto total objetivo | ~0,90 m | 23 px | **medido**: canvas 34×44, alto útil 34 px (~1,31 m) | +48% | **REVISAR** — descontando algo de profundidad de base sigue por encima de lo esperado para una silla de espera |
| Silla de funcionario (`silla_funcionario`), alto total objetivo | ~0,90 m (ver nota) | 23 px | **medido**: canvas 37×52, alto útil 47 px (~1,82 m) | +104% | **REVISAR** — la desviación más alta de todo el mobiliario "normal"; ni el reposacabezas alto ni la profundidad de base explican por sí solos casi duplicar la altura objetivo |
| Sofá (`comodidad_sofa_descanso`) | 0,85 m *(asumido, sin cifra pedida — confirmar)* | 22 px | **medido**: canvas 46×44, alto útil 37 px (~1,43 m) | +68% | **REVISAR** — un sofá tiene bastante profundidad de asiento, así que parte de esto es esperable, pero conviene confirmar visualmente |
| Sofá 2 celdas (`asiento_sofa3`) | 0,85 m *(asumido)* | 22 px | **medido**: canvas 109×81, alto útil 72 px (~2,78 m) | +227% | **REVISAR** — el mayor outlier de toda la tabla; mismo patrón que `mostrador_atencion2` (huella muy alargada ⇒ sospecha de profundidad de base, no de un sofá real de 2,78 m) |
| Estantería grande (`comodidad_estanteria`) | 1,80 m | 47 px | **medido**: canvas 41×81, alto útil 81 px (~3,13 m) | +72% | **REVISAR (prioridad alta)** — el valor medido SUPERA la altura de pared fijada en la sección 2 (2,70 m / 70 px); aun descontando profundidad de base, una estantería que roza o supera el techo es un problema de escala real, no solo de medición |
| Estantería pequeña suelta (`comodidad_estanteria_suelta`) | 0,90 m *(asumido)* | 23 px | **medido**: canvas 32×58, alto útil 58 px (~2,24 m) | +152% | **REVISAR** — muy por encima de "pequeña"; ver nota sobre la suposición de 0,90 m |
| Estantería pequeña esquina (`comodidad_estanteria_esquina`) | 0,90 m *(asumido — confirmar, ver nota)* | 23 px | **medido**: canvas 65×75, alto útil 58 px (~2,24 m) | +152% | **REVISAR** — mide EXACTAMENTE igual que `comodidad_estanteria_suelta` (58 px); ver nota |
| Taquilla (`taquilla`) | 1,80 m | 47 px | 1,80 m en código → 47 px; **confirmado por medición**: canvas 20×48, alto útil 47 px | 0% | **OK** |
| Vending (`vending`) | 1,83–1,93 m | 47–50 px | 2,00 m en código → 52 px; **confirmado por medición**: canvas 31×53, alto útil 52 px | +4% sobre el límite superior del rango | **OK** (justo en el borde alto) |
| Fuente de agua (`fuente_agua`) | **1,60 m** (decisión del usuario, 2026-08-05) | 41 px | 1,20 m en código (valor ANTERIOR a la decisión) → 31 px; **confirmado por medición**: canvas 11×32, alto útil 31 px | **-24%** | **REVISAR** — pendiente re-render a 1,60 m |
| Cafetera sobremesa (`cafetera`) | 0,45 m | 12 px | 0,45 m en código → 12 px; **confirmado por medición**: canvas 9×13, alto útil 12 px | 0% | **OK** |
| Mueble soporte de cafetera/impresora (cajonera) | 0,675 m (altura de tapa, código) | 17 px | Compuesto solo en el scratchpad (fase v3, "preservados para integración") — no está en `assets/`, no medible todavía | — | PENDIENTE DE INTEGRACIÓN |
| Impresora de oficina de pie | 1,20 m | 31 px | Sprite actual es solo el aparato de sobremesa (0,50 m en código) → 13 px; **confirmado por medición**: canvas 13×14, alto útil 13 px | **-58%** | **REVISAR** — falta componerlo con el mueble soporte |
| Archivador (`archivador`) | 1,32 m | 34 px | 1,30 m en código → 34 px; **confirmado por medición**: canvas 20×35, alto útil 34 px | ~0% | **OK** |
| Televisión (`television`) | ~0,60 m (diagonal de pantalla, según el catálogo) | — | 0,60 m en código como ALTURA del aparato → 16 px; **confirmado por medición**: canvas 14×17, alto útil 16 px | ver nota | **REVISAR** — posible confusión de unidades |
| Radio (`comodidad_radio`) | 0,20 m *(asumido, dispositivo suelto)* | 5 px | **medido**: canvas 36×47, alto útil 46 px (~1,78 m) — **NO COMPARABLE directamente**: el sprite hornea el aparato SOBRE su cajonera de apoyo (igual que la cafetera), así que 46 px es aparato+mueble, no el dispositivo solo | — | **REVISAR** — recalcular el objetivo como radio + mueble soporte antes de juzgar la desviación |
| Dispensador de agua (`comodidad_dispensador_agua`) | — | — | **medido**: canvas 25×70, alto útil 69 px (~2,67 m) | — | **DUPLICADO A RESOLVER** — casi el doble de alto que el objetivo de "fuente de agua" (41 px); otro argumento para no dar los dos por buenos a la vez |

### Notas de la auditoría

- **Patrón "huella ancha ⇒ alto aparente inflado"**: `mostrador_atencion2` (+157%) y `asiento_sofa3`
  (+227%) son, con diferencia, los dos valores más disparados de toda la tabla — y los dos comparten
  huella alargada (2 celdas) frente a su versión de 1 celda, que se desvía mucho menos
  (`mostrador_atencion` +82%; no hay versión de 1 celda del sofá para comparar). Es la prueba más
  clara de la advertencia metodológica de este documento: cuanto más ancho/profundo es un objeto en
  planta, más profundidad de base isométrica arrastra su silueta hacia arriba en el sprite, sin que el
  objeto real sea más alto. No se aplica un descuento numérico (no hay fórmula fiable para separarlo)
  — pero al leer el veredicto de estas dos filas, una parte real de esa desviación probablemente no es
  un error de escala.
- **Silla de funcionario**: el sprite muestra visualmente un respaldo alto con alerones/reposacabezas
  (estética "silla de oficina tipo gaming"), no una silla de espera simple. Es razonable que supere
  los 0,90 m genéricos — propongo un objetivo específico de 1,00–1,10 m para esta pieza en vez de
  compartir la cifra genérica de "silla". Aun con ese objetivo más generoso (27 px), la medición
  (47 px) sigue un +74% por encima — la profundidad de base no cubre esa distancia. Es la pieza de
  mobiliario "normal" que más urge revisar.
- **Estanterías «pequeñas» (`_suelta` y `_esquina`)**: la medición las deja EXACTAMENTE iguales (58 px,
  ~2,24 m cada una) y muy por encima del objetivo asumido de 0,90 m — más cerca, de hecho, del rango
  de la estantería «grande» (81 px) que de una pieza pequeña. Esto contradice la suposición de la v1
  de este documento: probablemente no son variantes «pequeñas» en absoluto, o el nombre de archivo no
  refleja su tamaño real. Antes de retocar cualquiera de las tres, conviene decidir qué tamaño se
  quería para cada una.
- **Estantería grande — alerta de altura de techo**: 81 px (~3,13 m) supera la pared de 2,70 m/70 px
  fijada en la sección 2. Aunque parte del exceso sea profundidad de base, una estantería que iguala o
  supera la altura de la pared es la desviación con más impacto de jugabilidad de toda la tabla
  (clipping visual con el techo) — prioridad alta sobre el resto de REVISAR.
- **Radio**: el sprite hornea el aparato SOBRE su cajonera de apoyo (mismo patrón que la cafetera con
  su mueble soporte, ver comentario `ID_RADIO` en `render_mobiliario.gd`). Comparar sus 46 px medidos
  contra un objetivo de "solo el dispositivo" (5 px) no es una comparación válida — el objetivo
  correcto sería dispositivo + mueble soporte combinados, que este plan todavía no ha fijado.
- **Fuente de agua**: el 05-08-2026 se decidió subir su altura objetivo a 1,60 m, pero el sprite en
  `assets/sprites/mobiliario/fuente_agua_*.png` sigue siendo el render con el valor anterior
  (1,20 m, `render_props_poly.gd` línea ~43; confirmado por medición directa: 31 px). Es una
  desviación esperable y ya conocida, no un fallo de proceso — simplemente falta re-renderizar con la
  nueva cifra.
- **Impresora de oficina de pie**: el commit `643cbf7` ("chore(tools): renders props v3 (fuente 1,60m
  + sobremesa con cajonera) preservados para integracion") ya generó una versión compuesta
  (aparato + cajonera) en el scratchpad, pero **no está integrada en `assets/`**. El sprite que hoy
  vive en el catálogo es solo el aparato de sobremesa suelto (0,50 m, confirmado por medición: 13 px)
  — de ahí el -58%. Este plan confirma numéricamente que la composición pendiente es necesaria, no
  opcional.
- **Televisión**: `render_props_poly.gd` usa 0,60 m como la ALTURA del aparato. Pero el catálogo de
  este encargo describe la televisión por su "diagonal ~0,60 m", que es una magnitud distinta. Para un
  televisor 16:9, altura ≈ diagonal × 0,49 → con diagonal 0,60 m la altura real esperable sería
  ~0,29 m (≈8 px), la MITAD de lo que hoy está codificado (confirmado por medición: 16 px). Antes de
  dar por buena esta pieza hace falta confirmar cuál de las dos lecturas es la correcta.
- **Dispensador de agua vs. fuente de agua**: existen dos sprites distintos para lo que parece el
  mismo concepto de mueble (`comodidad_dispensador_agua`, pipeline antiguo por huella, medido en 69 px
  / ~2,67 m, y `fuente_agua`, pipeline nuevo por altura, objetivo 41 px). El dispensador mide casi el
  doble que el objetivo de la fuente — otro argumento a favor de decidir cuál de los dos es el
  definitivo y retirar el otro, en vez de arreglar ambos por separado.
- **Fuera de alcance de esta tabla**: `comodidad_papelera` (medido 21 px, ~0,81 m) y
  `comodidad_equipo_informatico` (medido 28 px, ~1,08 m) existen como sprites pero no tenían una
  medida real de referencia en este encargo — no se les ha inventado un objetivo. Quedan aquí solo
  como dato de referencia; si se quieren auditar de verdad, hace falta decidir primero su medida real
  típica.

---

## 4. Especificaciones de futuros assets

### ⭐ Impresora de DNI (nueva)

Descripción literal del usuario (2026-08-05): *"una impresora grande azul de una cuadrícula pero
grande, que puede llegar a 1,50 de altura y ancha, NO la impresora de mesa normal"*.

| Campo | Valor |
|---|---|
| Altura real | 1,50 m → **39 px** |
| Huella | 1 celda de rejilla, cuerpo ANCHO dentro de esa celda (no una torre estrecha como la impresora de mesa) |
| Color | Azul dominante |
| Detalle | Panel frontal con textura de cuadrícula (rejilla de ranuras/paneles), aspecto de máquina grande de oficina — se diferencia a propósito de la impresora de sobremesa normal (12 px, ver tabla del punto 3) |
| Objeto de referencia a NO confundir | `impresora_*.png` actual (aparato de sobremesa, 0,50 m) — la impresora de DNI es una pieza nueva y distinta, no un reescalado de esa |

### Impresora normal de documentos (de oficina, grande — de pie)

Mencionada por el usuario junto a la de DNI, como una impresora de oficina "también grande". Reutiliza
el objetivo ya fijado en la fila "Impresora de oficina de pie" del punto 3: **1,20 m → 31 px**,
de pie, compuesta con su mueble soporte (cajonera, 0,675 m de tapa). No se le da spec aparte porque
es el mismo objeto que ya está pendiente de composición — evita duplicar la pieza como se hizo con la
fuente de agua/dispensador.

---

## 5. Regla de producción

Todo render 3D→sprite nuevo declara su **altura real en metros** y el pipeline la fuerza a píxeles —
nunca al revés (nunca "a ojo cuántos píxeles ocupa" y luego se inventa a qué altura corresponde). Así
ya funciona `tools/render_props_poly.gd`, que es el canon a seguir:

> "CALIBRACIÓN POR ALTURA REAL (NO por la AABB rota de los .glb): PX_POR_METRO = 44/1.70 ≈ 25.882
> (muñeco `girl` del proyecto, 44 px ≈ 1.70 m). Cada pieza declara la altura REAL que debe tener en el
> juego; el factor de escala sale de medir cuántos píxeles ocupa su render en bruto y forzarlo a
> `altura_objetivo_m * (44/1.70)` px." — `tools/render_props_poly.gd`, líneas ~16-20

El pipeline más antiguo, `tools/render_mobiliario.gd` (mostrador, sillas, sofás, estanterías,
papelera, dispensador, radio, equipo informático), calibra al revés: por HUELLA en planta
(`ESCALA_OBJETIVO_MOSTRADOR = 0.92`, que el mostrador ocupe el 92% de una celda de rejilla), sin
declarar nunca una altura real objetivo. Es el motivo por el que la mitad de la tabla del punto 3
quedó en PENDIENTE — no hay ninguna cifra de altura que auditar en el código, solo en el PNG. **Para
cualquier mueble nuevo (y, si se retoca, para los de esta lista), usar el criterio de
`render_props_poly.gd` (altura real declarada), no el de `render_mobiliario.gd` (huella).** La huella
sigue siendo útil para que el objeto no se salga de su celda en planta, pero la ALTURA debe fijarse
siempre contra el muñeco, nunca como efecto colateral de encajar el ancho.
