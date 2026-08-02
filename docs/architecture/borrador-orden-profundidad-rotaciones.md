# BORRADOR — pendiente de decisión del usuario

**Orden de profundidad y ventanillas rotables**

Estado: **BORRADOR, NO decidido, NO implementado.** Este documento no modifica ADR-0005 ni ningún
código; es la investigación y la propuesta para que el usuario decida cómo seguir.

Fecha: 2026-08-02 · Motor: Godot 4.6 · Redactado por: godot-specialist
Relacionado con: `docs/architecture/adr-0005-orden-de-capas-contenedor-iso.md`

---

## 1. El problema: la oclusión depende del ángulo

Hoy el orden de dibujo de una ventanilla (silla del funcionario, funcionario/policía, mostrador,
silla del ciudadano) es **fijo**: lo decide el mecanismo `_insertar_en_capa` de
`src/main/npcs_flujo.gd` con tres capas con nombre (`CAPA_FONDO`, `CAPA_PERSONAJE`, `CAPA_FRENTE`,
ADR-0005). Ese orden se eligió mirando la ventanilla en SU ÚNICA orientación actual: el funcionario
al norte, el ciudadano al sur.

El usuario lo señaló con razón (2026-08-02): *"el ángulo visual es el que manda"*. Si un día se gira
esa ventanilla 180° (el funcionario pasa a estar al sur, más cerca de cámara, y el ciudadano al
norte, más lejos), lo que antes estaba **detrás** pasa a estar **delante** — y las capas fijas no se
enteran, porque no miran la posición, solo un número que alguien escribió a mano para UN único caso.
El resultado, en palabras del usuario: la silla taparía al policía y el policía a la mesa, **justo al
revés** de lo que se ve hoy.

Conclusión de partida: un mecanismo que "sabe" quién va delante porque alguien lo escribió así no
escala a rotaciones. Hace falta un mecanismo que **calcule** quién va delante mirando dónde está cada
cosa en la pantalla, en cada momento — eso es exactamente lo que hace el algoritmo del pintor (§3) y
lo que Godot ofrece nativo con `y_sort_enabled` (§4).

---

## 2. Cómo se dibuja hoy la ventanilla

La ventanilla ocupa **tres celdas en fila** en el plano lógico cuadrado (el "plano del arquitecto"
oculto, ver `src/foundation/proyeccion/proyeccion.gd`):

```
[ funcionario ]  ← celda norte  (celda_puesto + (0,-1), vía MesaAtencion.CELDA_FUNCIONARIO)
[   MOSTRADOR  ]  ← la celda del puesto en el modelo (Flujo/Construcción)
[  ciudadano   ]  ← celda sur   (celda_puesto + (0, 1), vía NPCsFlujo._frente_del_puesto)
```

- `src/main/npcs_flujo.gd::_asegurar_visual_puesto` (líneas ~1302-1385) crea, por puesto, un
  contenedor `Node2D` llamado `"Puesto_<id>"` y cuelga de él la silla del funcionario, el mostrador
  (`MesaAtencionScript.construir()`) y el muñeco del policía, cada uno con `_insertar_en_capa(...)`
  y un rol de capa (`CAPA_FONDO`/`PERSONAJE`/`FRENTE`, líneas 116-118 y 1339-1342).
- `_insertar_en_capa` (líneas 124-136) no mira posiciones: marca cada hijo con el metadato
  `capa_iso` y los reordena por ese número. Es la única vía permitida (ADR-0005) — está prohibido
  un `add_child`/`move_child` suelto.
- El orden cambia según la POSE, no según el ángulo: sentado, el mostrador va al FRENTE (tapa
  piernas y silla); de pie, el policía va al FRENTE (es más alto que el mostrador y se le ve
  entero) — swap gestionado en `_reconstruir_cuerpo_policia` (líneas 1504-1526).
- El mostrador (`src/main/mesa_atencion.gd`) ancla sus piezas por su **punto de apoyo** (el sitio
  donde tocan el suelo), no por su esquina: `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` (líneas 113-114)
  son offsets de PANTALLA ya proyectados (`Proyeccion.MEDIO_ANCHO`/`MEDIO_ALTO`), y los sprites de
  mobiliario cargan un `ANCLA_FRACCION_*` que centra la textura exactamente en ese punto (líneas
  136-139, 189-191). Este detalle es la base de la propuesta del §5: los orígenes YA están donde
  tienen que estar para que un ordenamiento automático funcione.
- El contenedor `"Puesto_<id>"` entero cuelga de `_capa_escena`, que **ya tiene**
  `y_sort_enabled = true` (línea 354) — así que hoy YA conviven dos mecanismos: y-sort automático
  entre el bloque "Puesto_X" y el resto de NPCs sueltos (ciudadanos caminando, etc.), y capas fijas
  a mano DENTRO de "Puesto_X". El problema del usuario vive en la segunda parte.
- Precedente en el propio proyecto: `src/core/construccion/construccion.gd` (línea 1850) ya usa
  `_capa_elementos.y_sort_enabled = true` para ordenar mobiliario de las salas, y funciona sin
  capas a mano.

---

## 3. Cómo lo resuelven los juegos isométricos: el algoritmo del pintor

En llano, con una analogía: imagina un pintor de verdad delante de un lienzo. Para que un cuadro se
lea con profundidad, pinta primero lo que está MÁS LEJOS (las montañas del fondo) y va pintando
capas cada vez más cerca — el árbol de en medio tapa un trozo de montaña porque se pinta ENCIMA, y
la persona en primer plano tapa un trozo del árbol por la misma razón. El pintor nunca decide "la
montaña va detrás porque yo lo digo": lo decide el ORDEN en que moja el pincel, de lejos a cerca.

Un juego isométrico hace lo mismo cada fotograma, pero en vez de "lejos/cerca" físico usa un truco:
en esta proyección, cuanto más ABAJO se dibuja algo en la pantalla, más "delante" está en la escena
(más cerca de la cámara). Así que el algoritmo es: coger todos los objetos, ordenarlos por su
posición vertical en pantalla (de menor Y = más arriba/lejos, a mayor Y = más abajo/cerca), y
pintarlos en ese orden. El objeto que se pinta el último queda encima de todos los anteriores con
los que se solape. Es el mismo truco que usa el suelo de una ventanilla real: lo que está apoyado
más adelante, tapa lo que está más atrás — no importa el ángulo desde el que gires la sala, la regla
"lo de más adelante tapa a lo de más atrás" sigue siendo cierta. Por eso el algoritmo del pintor
resuelve solo el problema de la rotación: no hay que memorizar "quién va delante en cada ángulo",
basta con recalcular la posición en pantalla de cada pieza y dejar que la Y decida.

---

## 4. El mecanismo nativo de Godot 4.6: `CanvasItem.y_sort_enabled`

Verificado contra la documentación oficial 4.6 (no la doc genérica "stable"/training data, que
puede no reflejar 4.6 con exactitud — VERSION.md avisa de que 4.4-4.6 introdujeron cambios que el
conocimiento base del modelo no cubre).

**Fuente**: https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html
(propiedad `y_sort_enabled`, consultada 2026-08-02)

Cita textual de la doc:

> `bool y_sort_enabled = false`
> If true, this and child CanvasItem nodes with a higher Y position are rendered in front of nodes
> with a lower Y position. If false, this and child CanvasItem nodes are rendered normally in scene
> tree order.
> With Y-sorting enabled on a parent node ('A') but disabled on a child node ('B'), the child node
> ('B') is sorted but its children ('C1', 'C2', etc.) render together on the same Y position as the
> child node ('B'). This allows you to organize the render order of a scene without changing the
> scene tree.
> Nodes sort relative to each other only if they are on the same `z_index`.

Reglas exactas, traducidas y con sus consecuencias para nosotros:

1. **Se activa por nodo** (`CanvasItem.y_sort_enabled`, por defecto `false`) y afecta a "este nodo y
   sus hijos": ordena los HIJOS DIRECTOS del nodo que lo tiene activado, comparando su posición Y
   (la del origen del nodo, en el sistema de coordenadas del padre con y-sort — es decir, su punto
   de anclaje, no una caja englobante).
2. **NO es recursivo por defecto.** Si un hijo con y-sort tiene a su vez hijos que NO tienen
   `y_sort_enabled` propio, esos nietos se pintan siempre juntos, "en bloque", a la profundidad del
   hijo — Godot lo dice explícitamente: organiza el orden sin tocar el árbol, pero un subgrupo sin
   y-sort propio actúa como una unidad rígida. **Esto es clave para el diseño del §5**: las piezas
   que deban reordenarse ENTRE SÍ (silla / personaje / mostrador) tienen que ser hijas DIRECTAS del
   MISMO contenedor con y-sort — si alguna cuelga anidada dentro de otra, deja de competir por
   orden con las demás.
3. **Solo desempata entre nodos del mismo `z_index`.** Si dos piezas tienen `z_index` distinto, el
   `z_index` manda primero y el y-sort solo decide el orden DENTRO de cada `z_index`. Hoy todas las
   piezas de un "Puesto_X" heredan el `z_index = 2` de `_capa_escena` sin override individual, así
   que están a salvo — pero es una invariante a vigilar si algo empieza a poner `z_index` local.
4. **No se ha encontrado ningún cambio de esta API entre 4.3 y 4.6** — revisadas las guías oficiales
   de migración 4.4→4.5 y 4.5→4.6
   (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html,
   https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html): ninguna
   menciona `y_sort_enabled`. Es una API de bajo nivel, estable desde antes del corte de
   conocimiento del modelo (existía ya como nodo dedicado `YSort` en Godot 3.x, fusionado en
   `CanvasItem` en 4.x — cambio anterior a 4.3, ya cubierto por el entrenamiento).
5. Dato relacionado (no aplica directo a nuestros `Node2D`, pero confirma que Godot trata el
   "punto de anclaje para y-sort" como un concepto de primera clase): `TileMapLayer` expone
   **`y_sort_origin`**, un desplazamiento vertical en píxeles por tile para afinar SU punto de
   comparación — fuente: https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilemaps.html
   (sección "Rendering" del inspector de `TileMapLayer`). No lo necesitamos porque nuestras piezas
   ya son `Node2D`/`Sprite2D` individuales con offset propio (ver §2), pero es la prueba de que
   "mover el punto de comparación en vez de reordenar a mano" es un patrón que el propio motor
   reconoce y expone.

**[pendiente de verificar]**: la doc no dice explícitamente qué pasa si dos nodos tienen EXACTAMENTE
la misma Y (empate) — no hay garantía documentada de estabilidad por orden de inserción. Ver §7.

---

## 5. Cómo se aplicaría a nuestra ventanilla

La pieza que ya tenemos a favor: **los sprites anclan por su punto de apoyo** (§2 — silla, mostrador
y personaje usan `Vector2.ZERO` local = el punto donde tocan el suelo, gracias a los offsets
`ANCLA_FRACCION_*`/`CELDA_FUNCIONARIO`/`CELDA_CIUDADANO`, ya expresados en coordenadas de PANTALLA
isométricas). Eso es exactamente lo que pide la regla 1 del §4: y-sort compara el origen del nodo, y
nuestros orígenes YA están puestos en el punto físicamente correcto para que la comparación tenga
sentido. La propuesta:

- Las piezas de un puesto (silla del funcionario, personaje del funcionario, mostrador, silla del
  ciudadano) pasan a ser **hijas DIRECTAS** de un contenedor `"Puesto_<id>"` con
  `y_sort_enabled = true`, en vez de recibir un `capa_iso` fijo.
- Su orden de dibujo sale SOLO de su posición Y de pantalla — la misma cuenta que ya hace
  `Proyeccion.centro_iso`/`Proyeccion.profundidad` (esta última, en
  `src/foundation/proyeccion/proyeccion.gd` líneas 132-137, YA es literalmente "la Y proyectada,
  expuesta con nombre propio" — existe en el proyecto, hoy sin usar para esto).
- `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` dejan de ser dos constantes fijas (norte/sur) y pasan a
  depender de la ORIENTACIÓN del puesto: el mismo offset relativo, rotado 90°/180°/270° según hacia
  dónde mire la ventanilla (matemáticamente, girar el vector `(MEDIO_ANCHO, -MEDIO_ALTO)` en el
  plano LÓGICO antes de proyectar — no hace falta inventar nada nuevo, `Vector2.rotated()` o
  permutar componentes basta).
- Las capas fijas de ADR-0005 (silla < personaje < mostrador) **dejan de ser una regla escrita a
  mano y pasan a ser el resultado que el y-sort reproduce SOLO** para la orientación actual (Norte)
  — es decir, no se pierde nada de lo que funciona hoy, se deja de tener que mantenerlo a mano.

### Tabla de oclusión en las 4 orientaciones

Con la proyección del proyecto (`Proyeccion.proyectar`, `iso.y = (cuad.x + cuad.y) / TAM_CELDA *
MEDIO_ALTO`), mover al funcionario una celda en cualquier dirección cardinal cambia su profundidad
relativa así (offset respecto al mostrador, en celdas lógicas → Y de pantalla en px, con
`MEDIO_ALTO = 20`):

| Orientación (dónde queda el funcionario respecto al mostrador) | Profundidad Y relativa del funcionario | Profundidad Y relativa del ciudadano | Orden CORRECTO fondo→frente (y-sort) | Orden que aplica HOY (ADR-0005, fijo) | ¿Coincide? |
|---|---|---|---|---|---|
| **Norte** (la única que existe hoy) | −20 (atrás) | +20 (delante) | funcionario → mostrador → ciudadano | silla func. → policía → mostrador (sentado) | **Sí** — es el caso para el que ADR-0005 se diseñó |
| **Oeste** | −20 (atrás) | +20 (delante) | funcionario → mostrador → ciudadano | mismo orden fijo, sin cambios | **Sí**, por simetría con Norte (mismo Y, aunque el ciudadano hace cola por el lado este en vez del sur) |
| **Sur** (el giro de 180° que señaló el usuario) | +20 (delante) | −20 (atrás) | ciudadano → mostrador → funcionario | el código seguiría aplicando silla → policía → **mostrador delante del policía** | **NO** — con capas fijas el mostrador tapa al funcionario cuando debería ser al revés: la cita del usuario, confirmada por la cuenta |
| **Este** | +20 (delante) | −20 (atrás) | ciudadano → mostrador → funcionario | mismo orden fijo que hoy | **NO**, mismo fallo que Sur, por simetría |

Nota curiosa (y útil) que sale de la cuenta: en esta proyección concreta, Norte y Oeste dan la MISMA
profundidad relativa (ambas "detrás"), y Sur y Este dan la misma profundidad relativa (ambas
"delante") — no son la misma escena (el ciudadano queda a un lado distinto de la pantalla), pero la
pregunta "¿quién tapa a quién?" tiene la misma respuesta en cada pareja. Solo hay DOS familias de
comportamiento, no cuatro — lo que simplifica bastante la migración y su verificación visual.

---

## 6. Plan de migración prudente

1. **Fase 0 — replicar sin cambiar nada visible.** Convertir SOLO el mecanismo interno de
   `"Puesto_<id>"`: piezas hijas directas + y-sort, en vez de `capa_iso`, manteniendo la orientación
   Norte (la única que existe). Verificar con fotomontaje/captura que el resultado es
   PÍXEL A PÍXEL igual al actual, antes de tocar nada más — es la misma disciplina que ya pide
   ADR-0005 para cualquier composición nueva.
   - El caso "de pie" (el policía se ve entero por encima del mostrador aunque su punto de anclaje
     esté a la misma profundidad relativa que hoy) es la parte que un y-sort ingenuo NO resuelve
     solo (ver §7) — hace falta un pequeño ajuste de profundidad de datos, no de árbol, y tocará
     tunearlo mirando la pantalla en esta fase.
2. **Fase 1 — generalizar los offsets.** `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` y
   `_frente_del_puesto` pasan a depender de una orientación explícita del puesto, reutilizando la
   rotación de vectores ya disponible en Godot/`Proyeccion` (sin rotaciones activas todavía en el
   juego — solo se deja el código listo).
3. **Fase 2 — activar rotaciones y probar las 4 orientaciones.** Exponer la orientación como dato
   editable del puesto (mismo patrón que ya usa `Construccion` para otros muebles rotables, p. ej.
   `ROT_ASIENTO_SOFA3_VERTICAL`/`HORIZONTAL`). Verificar la tabla del §5 en el juego real, con
   fotomontaje de las 4 orientaciones.
4. **Fase 3 — cerrar ADR-0005.** Con la migración probada, decidir si se retira o se reescribe como
   "caso particular documentado que el y-sort reproduce solo para Norte" (dejar constancia formal,
   no solo borrarlo).

---

## 7. Riesgos y empates

- **Empates exactos de Y**: la doc de `y_sort_enabled` no garantiza explícitamente el criterio de
  desempate cuando dos nodos coinciden exactamente en profundidad
  **[pendiente de verificar empíricamente en 4.6]**. Mitigación ya usada en el proyecto: cuando dos
  cuerpos deben coincidir a propósito en la misma celda, `NPCsFlujo._sitio_apretujado` (líneas
  680-688) les da un desvío sub-celda DETERMINISTA (no aleatorio) para que nunca queden
  perfectamente superpuestos — el mismo patrón serviría aquí si hiciera falta.
- **"De pie" vs "sentado" (altura de sprite mayor que el mueble)**: hoy ADR-0005 resuelve esto
  con un swap de capa según la POSE, no según la posición — el policía de pie y el mostrador
  comparten prácticamente la misma profundidad de anclaje, y quién tapa a quién depende de qué tan
  alto es cada uno, no de quién está "más adelante" en la rejilla. Un y-sort por punto de anclaje
  NO resuelve esto solo — necesitará un pequeño desplazamiento de profundidad deliberado por pieza
  (datos, no árbol) para las poses donde el personaje deba leerse por encima del mueble. Es la
  única parte de ADR-0005 que no es "pura rotación" y que sobrevive como ajuste fino.
- **Personajes que se mueven entre celdas** (el ciudadano caminando de la calle a la ventanilla, el
  reservado por llamada anticipada dos casillas atrás): NO son un riesgo nuevo — ya cuelgan sueltos
  de `_capa_escena` (que ya tiene y-sort) y `colocar_muneco` ya actualiza su posición cada
  `_physics_process`, así que su profundidad ya se recalcula sola hoy. Es la parte que YA funciona
  sin ADR-0005.
- **No recursividad del y-sort** (regla 2, §4): si en el futuro alguien anida un sub-grupo dentro de
  `"Puesto_<id>"` (p. ej. para animar la silla y el personaje como una unidad), ese sub-grupo se
  comportará como un bloque rígido a la profundidad de SU propio origen — hay que mantener las
  piezas que compiten por orden entre sí como hijas DIRECTAS del mismo contenedor con y-sort activo.
- **`z_index` distinto entre piezas**: el y-sort solo desempata dentro del mismo `z_index` (regla 3,
  §4). Hoy ninguna pieza de un puesto tiene `z_index` propio; si se añade alguno habrá que
  revisarlo.

---

## 8. Preguntas abiertas para el usuario

1. ¿Se migra la Fase 0 (replicar el "Puesto_X" actual con y-sort, sin cambiar la orientación) ya,
   para dejar el terreno preparado, o se aplaza hasta que haya una necesidad real de girar una
   ventanilla?
2. ¿Qué decide la orientación de una ventanilla en el modo construcción? ¿el jugador la gira a mano
   (como otros muebles rotables), o depende del lado del edificio/pared donde se coloque?
3. El ajuste fino de profundidad para el caso de pie/sentado (§7): ¿se investiga y tunea ahora en la
   Fase 0, o se deja pendiente hasta que existan rotaciones de verdad que lo pongan a prueba?
4. ¿Se retira ADR-0005 en cuanto se decida la migración, o se mantiene vigente (como red de
   seguridad) hasta que la Fase 0 esté probada en pantalla?
5. Alcance: ¿la migración a y-sort se limita a la ventanilla, o se aprovecha para unificar bajo el
   mismo mecanismo otros contenedores iso del juego (ya hay precedente en
   `Construccion._capa_elementos` y en el propio `NPCsFlujo._capa_escena`, ambos con y-sort activo
   a nivel superior desde antes de este documento)?
