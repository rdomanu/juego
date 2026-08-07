# Lado de acción — estándar de orientación de mobiliario

**Estado: DRAFT — para revisión del usuario.**

Origen: la silla del ciudadano de la ventanilla se integró DOS veces mal orientada (270 = de
lado, 180 = respaldo hacia el lado equivocado) porque cada pieza se orientaba a ojo, mirando la
silueta del modelo en vez de mirando cómo se USA. Este documento fija la regla que evita que se
repita, y se apoya en el trabajo ya hecho: la REGLA DE HUELLA EXACTA y la validación con rejilla
de `mapa-integracion-mobiliario.md`, y el triángulo azul de orientación que ya existe en
`src/main/modo_construccion.gd` (`_frente_de_orientacion`, 2026-08-06) — hoy ese triángulo ya
apunta "el lado del ciudadano" para el mobiliario colocable; este documento formaliza esa idea
como regla general para TODO objeto con acción, no solo el caso que lo motivó.

## 1. Definición

**Lado de acción** = la cara del objeto por la que un muñeco lo usa. No es la cara "bonita" del
render, ni la que el artista dibujó de frente por costumbre: es la cara desde la que un personaje
se sienta, se planta, o mira.

> **Regla de oro: la orientación de un objeto en escena se define por dónde queda su lado de
> acción respecto al usuario (muñeco), nunca por la estética de la pieza vacía.**

Consecuencia directa del incidente de la ventanilla: una silla vacía "mirando bien" a ojo puede
seguir estando mal si nadie comprobó hacia dónde cae el asiento respecto al respaldo. La única
comprobación válida es: "si pongo un muñeco encima/delante, ¿queda donde el diseño dice que
tiene que quedar la interacción?".

Un objeto puede no tener lado de acción (ver categoría "decorativos sin acción" en la tabla) — en
ese caso esta regla no aplica y basta con la orientación estética libre.

## 2. Tabla por categoría

Catálogo real auditado en `datos/comodidades/*.tres` y `assets/sprites/mobiliario/` (2026-08-07).

### Asientos — acción = el asiento, opuesta al respaldo

El usuario SE SIENTA en la silla mirando hacia el lado de acción (el respaldo queda siempre
detrás del muñeco, nunca de lado ni de frente).

| Objeto | Origen | Nota |
|---|---|---|
| `silla_espera_madera`, `silla_espera_azul`, `silla_espera_comoda` | `datos/comodidades/` | Sillas de la sala de espera (familia `ciudadano`) |
| `silla_oficina` | `datos/comodidades/` | Silla del funcionario, comodidad comprable |
| `sillas_office` (2 plazas) | `datos/comodidades/` | Mesa de la sala de descanso — 2 sillas, 2 lados de acción independientes |
| `sofa_descanso` (3 plazas) | `datos/comodidades/` | Multi-celda; las 3 plazas comparten el MISMO lado de acción (todo el frente del sofá) |
| Silla del funcionario en la ventanilla | auto, código (`mesa_atencion.gd`) | Ya corregida — ver ley de verificación |
| Silla del ciudadano en la ventanilla | auto, código (`mesa_atencion.gd`), sprite `silla_espera_*` | El incidente que motiva este documento — ya corregida |

### Máquinas de pie — acción = frontal de uso, de pie

El usuario está DE PIE frente al objeto, no sentado. El lado de acción es la cara donde está el
panel/expositor/grifo que se acciona.

| Objeto | Origen | Nota |
|---|---|---|
| `vending` | `datos/comodidades/` | `usable=true`, el ciudadano va hasta él |
| `dispensador_agua` | `datos/comodidades/` | Familia `descanso`; visualmente de pie aunque hoy `usable=false` en datos (candidato a activarse) |
| `maquina_cafe` | `datos/comodidades/` | Familia `descanso`, `usable` implícito por diseño de la sala |
| `revistero` | `datos/comodidades/` | `usable=true`, el ciudadano se acerca a coger una revista — mismo patrón que un expositor de pie |

### Aparatos con pantalla — acción = la pantalla, mira al usuario

El lado de acción es la cara donde está la pantalla/panel de salida. Da igual si el uso es
"caminar hasta él" o "disfrutarlo desde el asiento" (ambiental): la pantalla tiene que orientarse
hacia donde está o se sienta el usuario.

| Objeto | Origen | Nota |
|---|---|---|
| `equipo_informatico` | `datos/comodidades/` | Familia `funcionario`; la pantalla mira al funcionario que lo usa, no al ciudadano |
| `television` | `datos/comodidades/` | Se disfruta desde el asiento (ambiental, `usable=false`) — pantalla orientada hacia las sillas de espera, no hacia la pared |
| `impresora_dni` | `datos/comodidades/` | Familia `funcionario`, panel/salida hacia el trabajador |
| `impresora_documentos` | `datos/comodidades/` | Familia `funcionario`; de aquí sale la denuncia/resguardo — panel hacia el trabajador que la opera |

**Nota aparte — `radio`**: no tiene pantalla, pero comparte con la TV el patrón "se disfruta desde
el asiento sin acercarse". No hay una cara "de uso" real (es sonido ambiente, sin controles que
mirar), así que se trata como **decorativo/exento** salvo que el arte real tenga una cara
claramente frontal (rejilla de altavoz) que convenga orientar hacia la sala — a decidir cuando
tenga sprite propio.

### Mesas de trabajo / atención — acción = el lado del trabajador (caso doble: ventanilla)

Regla base: el lado de acción de un escritorio es el lado donde se SIENTA quien trabaja en él.

| Objeto | Origen | Nota |
|---|---|---|
| `escritorio_trabajo` | `datos/comodidades/` | Un solo lado de acción: el del funcionario que se sienta a trabajar. Sin ciudadano implicado |
| Mostrador de ventanilla (`mesa_atencion.gd`, sprites `mostrador_atencion*`) | código, ya construido | **Caso doble**: tiene DOS lados de acción simultáneos — trabajo al NORTE (`CELDA_FUNCIONARIO`, el funcionario sentado detrás) y atención al SUR (`CELDA_CIUDADANO`, el ciudadano sentado delante). Ambos lados son "acción" a la vez porque el mueble sirve a los dos roles enfrentados. Ya resuelto y verificado en código — documentado aquí como referencia del patrón, no como pendiente |

### Decorativos sin acción — exentos

No hay gesto de uso que orientar. La orientación es libre / estética (se gira para que encaje
contra la pared o la esquina, no para "mirar" a nadie).

| Objeto | Origen | Nota |
|---|---|---|
| `estanteria`, `estanteria_pequena`, `estanteria_esquina` | `datos/comodidades/` | Contra pared; orientación por encaje, no por acción |
| `papelera` | `datos/comodidades/` | — |
| `fluorescente`, `lampara_pie`, `foco_led` | `datos/comodidades/` | Iluminación — familia `iluminacion`, exenta por diseño (ver `comodidad.gd`) |
| `nevera` | `datos/comodidades/` | Ambiental (`aporte` de calidad de café), sin `usable` hoy — reevaluar si algún día se abre con gesto |
| `prensa_diaria` | `datos/comodidades/` | Ambiental en la sala de descanso, sin `usable` hoy (distinto de `revistero`, que sí es de uso) |
| `radio` | `datos/comodidades/` | Ver nota en "Aparatos con pantalla" arriba |

## 3. Convención de vistas

Las vistas renderizadas de un objeto se nombran y se eligen **por dónde apunta el lado de acción
en pantalla**, no por los grados internos del modelo 3D de origen:

- **acción-al-sur** — el lado de acción mira hacia abajo en pantalla (hacia la cámara/el jugador). Es la vista por defecto de casi todo: una silla de espera acción-al-sur es la que usa un muñeco de pie mirando "hacia nosotros".
- **acción-al-este** / **acción-al-oeste** — el lado de acción mira hacia uno de los lados.
- **acción-al-norte** — el lado de acción mira "hacia el fondo" de la pantalla (de espaldas al jugador). Poco frecuente pero real (ej.: el lado NORTE del mostrador de ventanilla, donde se sienta el funcionario mirando hacia el ciudadano que está al sur).

Este es exactamente el mapeo que ya usa `_frente_de_orientacion` en `modo_construccion.gd para el
ciclo de rotación con R: 0°=SUR, 90°=OESTE, 180°=NORTE, 270°=ESTE. La diferencia que introduce
este documento es de PROPÓSITO, no de mecánica: esos cuatro grados ya no se leen como "el modelo
gira tantos grados" sino como "la acción cae en tal cardinal".

**Regla del pipeline**: si las 4 vistas cardinales que da el modelo de origen (0/90/180/270 tal
cual venía modelado) dejan el lado de acción en diagonal en vez de en un cardinal limpio (caso
típico de muebles "de esquina" en un mundo isométrico a 30°), el pipeline de render
(`render_mobiliario.gd` y equivalentes) DEBE aplicar el giro extra de 45° que haga falta ANTES de
hornear el sprite, para que la vista final cataloge en un cardinal real. Los grados del modelo 3D
de origen son un detalle interno de la herramienta; lo que se cataloga y se nombra siempre es la
vista por su acción (acción-al-sur/-este/-norte/-oeste), nunca "grado 37" o similar.

## 4. Ley de verificación (extiende la ley de hojas)

Toda hoja de verificación de un objeto CON lado de acción debe enseñar al muñeco **usándolo** en
cada una de sus vistas, no el mueble vacío:

- Asientos → el muñeco SENTADO, con el respaldo detrás y el asiento hacia el lado de acción.
- Máquinas de pie → el muñeco DE PIE frente al panel/expositor de uso.
- Aparatos con pantalla → el muñeco (sentado o de pie, según el objeto) mirando hacia la pantalla.
- Mesas/atención → el muñeco trabajador sentado a SU lado; en el caso doble (ventanilla), los DOS
  muñecos (funcionario y ciudadano) a la vez, cada uno en su lado.

**Una silla vacía no se aprueba jamás** — es literalmente el error que motivó este documento: una
silla vacía "parece" bien orientada porque el ojo completa la escena con un muñeco imaginario, y
ese muñeco imaginario no siempre coincide con el real. La rejilla dibujada del fotomontaje (ya
exigida por `mapa-integracion-mobiliario.md`) sigue aplicando para el encaje de celdas; esta ley
añade la comprobación de la ACCIÓN encima de esa rejilla, no en su lugar.

Objetos decorativos sin acción (categoría 5 de la tabla) quedan exentos de esta ley — su hoja de
verificación sigue las reglas normales de huella/encaje, sin muñeco de uso.

## 5. Metadato

Propuesta: campo `lado_accion` en `Comodidad` (`src/foundation/datos/esquema/comodidad.gd`),
enum de 5 valores: `"ninguno"` (default, decorativos), `"asiento"`, `"frontal"` (máquinas de pie),
`"pantalla"`, `"doble"` (caso mesa de atención — reservado, hoy la ventanilla es código a medida
sin pasar por `Comodidad`, así que este valor queda documentado pero sin consumidor inmediato).

**Este documento NO decide el nombre exacto ni el tipo de dato del campo** (String vs enum vs
Vector2i con la dirección cardinal por defecto) — es una decisión de `godot-gdscript-specialist`
sobre `comodidad.gd`; aquí se fija el CONCEPTO y su tabla de valores, no la implementación.

Consumidores previstos de este metadato:

- **`modo_construccion.gd`** — el triángulo azul de orientación (`_preview_triangulo` /
  `_colocar_triangulo_orientacion`) ya apunta al "frente" de la pieza en mano; con este campo
  puede validarse en tiempo de diseño que ese frente coincide con el `lado_accion` declarado, en
  vez de confiar en que quien integró el sprite lo alineó bien a ojo.
- **`mesa_atencion.gd`** y cualquier mueble compuesto futuro con caso doble — referencia de
  patrón para declarar los dos lados sin inventar una solución nueva cada vez.
- **Colocación de NPCs** (`npcs_flujo.gd` y quien decida dónde se sienta/coloca un personaje) —
  hoy cada mueble tiene su propia lógica de celda de uso escrita a mano; el metadato es el punto
  único de verdad que esa lógica podría leer en vez de asumir la orientación.

## 6. Migración

Catálogo auditado el 2026-08-07. 18 objetos tienen lado de acción y requieren auditoría contra
esta ley; 2 ya están verificados (el caso que motivó el documento), 16 pendientes. Los 10
objetos decorativos quedan exentos (no se listan como pendientes).

### Verificados

- [x] Silla del ciudadano — ventanilla (`mesa_atencion.gd`) — corregida DE VERDAD 2026-08-07 con
      vista intermedia de 45° (`ID_SPRITE_SILLA_ESPERA_VENTANILLA`, 225°, verificada con muñeco
      sentado — ver la cabecera de esa constante). Las DOS correcciones previas (180 vs 270, ambas
      cardinales) seguían siendo "de esquina" y el usuario lo cazó dos veces en el juego real; el
      motivo era estructural (§3, "regla del pipeline") y solo se resolvió con las 8 vistas.
      ⚠️ Sala de espera / "Asiento (25 €)" (`ID_SPRITE_SILLA_ESPERA`, 180°) NO se tocaron — mismo
      riesgo teórico sin verificar con captura, ver el informe de esta pasada.
- [x] Silla del funcionario — ventanilla (`mesa_atencion.gd`) — corregida en el mismo arreglo
- [x] Mostrador de ventanilla (caso doble, norte/sur) — verificado en código con la rejilla de
      `mapa-integracion-mobiliario.md`

### Pendientes — asientos (6)

- [ ] `silla_espera_madera`
- [ ] `silla_espera_azul`
- [ ] `silla_espera_comoda`
- [ ] `silla_oficina`
- [ ] `sillas_office` (2 plazas — 2 lados de acción a comprobar)
- [ ] `sofa_descanso` (3 plazas, 1 lado de acción compartido)

### Pendientes — máquinas de pie (4)

- [ ] `vending`
- [ ] `dispensador_agua`
- [ ] `maquina_cafe`
- [ ] `revistero`

### Pendientes — aparatos con pantalla (4)

- [ ] `equipo_informatico`
- [ ] `television`
- [ ] `impresora_dni`
- [ ] `impresora_documentos`

### Pendientes — mesas de trabajo (2)

- [ ] `escritorio_trabajo`
- [ ] Escritorio en L / OBJ_006 (idea registrada en `mapa-integracion-mobiliario.md`, aún no
      integrado — auditar antes de integrar, no después)

### Fuera de alcance de esta migración (sprites sueltos sin `Comodidad` asociada)

Hay assets nuevos en `assets/sprites/mobiliario/` (`archivador_*`, `cafetera_*`, `impresora_*`,
`fuente_agua_*`) sin `.tres` en `datos/comodidades/` todavía — están fuera de esta lista porque
no hay definición de catálogo que auditar; cuando se den de alta como `Comodidad`, entran a esta
migración con la categoría que les toque (probablemente `cafetera_*`/`fuente_agua_*` duplican o
sustituyen a `maquina_cafe`/`dispensador_agua` — a confirmar con el usuario, no asumido aquí).
