# ¿Se puede hacer este tycoon bonito y sin fallos? — Investigación, veredicto y plan

**Fecha**: 2026-08-03 · **Encargo del usuario**: *"investigación en profundidad acerca de cómo
hacer un juego tycoon con el estilo que tenemos: funcional, atractivo y bien estructurado, sin
fallos […] igual con Opus 5 o Fable no se puede hacer y estamos intentando algo que no se puede"*.
**Listón elegido por el usuario**: **Big Pharma** (Twice Circled, 2015) — hecho por una persona,
con jugabilidad, bonito y bien diseñado.

**Fuentes**: investigación web con fuentes citadas (`investigacion/investigacion-web-tycoon.md`) +
auditoría fría medida con Python de nuestro estado real (`investigacion/auditoria-visual.md`).
Este documento las cruza y da el veredicto. Léelo entero: son 5 minutos.

---

## 1. El veredicto, sin rodeos

**Sí se puede — y la evidencia es fuerte.** Pero con tres condiciones que hasta ahora no
cumplíamos, y que explican TODOS los fallos que has visto:

1. **Los fallos que hemos sufrido son los fallos ESTÁNDAR del género, no una señal de
   incapacidad.** La cámara descalibrada, los muebles que no encajan en su celda, las anclas
   desviadas y la gente "suelta" de su mesa aparecen documentados en las wikis de modding de
   Prison Architect, The Sims y Stonehearth — juegos profesionales. La cita que resume la
   investigación: *"la diferencia no es si estos fallos aparecen — es si el equipo tiene un
   mecanismo para que dejen de aparecer una vez corregidos"*.

2. **Lo que nos faltaba no era talento ni herramienta: era la ESPECIFICACIÓN CERRADA.** Big
   Pharma lo hizo una persona sola… dirigiendo el arte contra una especificación cerrada, nunca
   "a ver qué sale". Nosotros producíamos piezas sueltas y las juzgábamos a ojo una a una — el
   método que la literatura señala como LA causa de la inconsistencia. La especificación es lo
   que hemos empezado a construir a golpes estos dos días (cámara fija verificada con cubo,
   huella exacta, anclas medidas, kits de módulos) y lo que este plan termina de cerrar.

3. **Lo que Fable/Opus no puede hacer es sustituir TU ojo — y no le hace falta.** En el modelo
   Big Pharma, tú eres el diseñador que decide y aprueba mirando; yo soy la programación y la
   maquinaria de medir; los packs CC + nuestra herramienta de render son "el artista freelance".
   Cada fallo que tu ojo cazó estos días (cámara torcida, mesa gigante, celdas invadidas) quedó
   medido, corregido y convertido en regla EL MISMO DÍA. Ese circuito es exactamente el que usan
   los equipos profesionales — ya funciona; lo que faltaba era ponerlo POR DELANTE de la
   producción en vez de por detrás.

**Límite honesto**: no vamos a tener arte dibujado a mano a medida ni animaciones lujosas. Nuestro
estilo es "low-poly pre-renderizado limpio" — el MISMO método con el que se hicieron RollerCoaster
Tycoon y Theme Hospital. Es un estilo probado, bonito y alcanzable; el plan lo abraza en vez de
pelearse con él.

---

## 2. El diagnóstico: qué está bien, qué está mal, qué falta

### Lo que YA está bien (y no es poco)

- **La jugabilidad completa**: 709 tests en verde — flujo de ciudadanos, personal, economía,
  paciencia, construcción, guardado. Un tycoon FUNCIONAL. (Esto es lo difícil; los juegos que
  admiras lo tienen encima de años de trabajo.)
- **NPCs que andan y se sientan** en 8 direcciones, con género y piel variados en policías.
- **La rejilla 80×40 es la convención canónica exacta del género** (2:1 dimétrica) — no una
  elección rara nuestra.
- **El mood de luz día/noche ya existe** (amanecer cálido, mediodía neutro, noche azulada, luces
  que se encienden a las 21:00) — la auditoría lo destaca como la pieza de atmósfera que NO es
  placeholder.
- **El proceso de calibración nuevo** (cubo, huella exacta, anclas medidas, fotomontaje con test
  numérico) — construido esta semana a base de tus avisos.

### Fallos activos de arte (medidos, con gravedad)

| Fallo | Gravedad | Estado |
|---|---|---|
| **Hueco de 25-35 px entre la gente y su mueble** ("gente suelta") — suma de sentar en el centro exacto de la celda + muebles que no llenan la suya | ALTA | Arreglo conocido, 2 vías, se decide contigo (§4, Fase 1) |
| **Un solo modelo de ciudadano** clonado (todas las salas de espera son la misma chica repetida) | ALTA | Buscar 2º modelo CC compatible |
| Radio, dispensador y pantallas **sobredimensionados** frente a la persona | MEDIA | Re-render con ratio humano (proceso ya existe) |
| **Estilos que no casan**: ciudadanos con ~3× más detalle que policías; sofá mucho más "plano" que el resto | MEDIA | Post-proceso común (regla mecánica, §4) |
| Sillas posiblemente algo altas | MEDIA | Verificar con captura antes de tocar |

### Lo que FALTA (no son fallos: es lo aún no construido)

| Carencia | Gravedad | Estado |
|---|---|---|
| Suelo, paredes, puertas y ventanas **sin arte** (polígonos de color) | ALTA | En backlog desde julio; especificación en art bible §4 |
| **UI de "expediente ministerial" 0% implementada** (los paneles son controles grises por defecto) | ALTA | ¡La especificación YA está aprobada (art bible §7) + referencia de tus capturas de Two Point! |
| Iconos de los 17 trámites | MEDIA | Especificado, sin producir |
| Pantalla de título / menú / créditos | ALTA para enseñar el juego | Los créditos son además obligación legal CC-BY antes de build público |

**La lectura importante**: la columna "Estado" dice casi siempre "arreglo conocido" o
"especificación ya aprobada". No hay NI UN problema sin solución identificada. "No damos una" era
en realidad "estamos a mitad de construir el sistema que hace que se dé una" — y la mitad que
falta es la más mecánica.

---

## 3. Los 10 principios del género (la vara de medir de ahora en adelante)

De la investigación (fuentes en el anexo). Marcado nuestro cumplimiento HOY:

1. ✅ Proyección y rejilla fijadas una vez (80×40 canónica; cámara 30° verificada con cubo).
2. ✅ Cada sprite con UN pivote coherente (anclas derivadas de la base medida — desde ayer).
3. ❌ **El punto de asiento/interacción debe ser un DATO del mueble** (como los "slots" de The
   Sims) — hoy la gente se sienta en el centro de su celda, sin que el mueble opine.
4. ❌ **Las poses de interacción se pre-componen** (Theme Hospital fusionaba doctor+silla en UN
   sprite) — nuestra arma secreta pendiente: podemos hornear "policía sentado en su silla" como
   una sola pieza perfecta.
5. ✅ Ningún mueble se estira: kits de módulos (desde ayer: el mostrador son 2 módulos).
6. 🟡 Orden de dibujo con desempate explícito (capas fijas hoy; migración a y-sort ya diseñada
   en borrador, pendiente de decidir).
7. 🟡 Sprites propios por dirección (los tenemos ×4 rotaciones; falta ancla por rotación en
   todas las piezas — el sofá ya la tiene).
8. ❌ La oclusión del sentado como estado deliberado (pendiente, ligado al 4).
9. 🟡 Escala verificada contra kit de referencia (tenemos el cubo para la BASE; falta el kit de
   ALTURAS: persona+silla+mesa+puerta en una hoja).
10. 🟡 Consistencia por reglas mecánicas escritas (art bible existe; faltan las reglas de
    paleta/detalle/post-proceso comunes).

**3 de 10 al empezar la semana; 5,5 de 10 hoy; el plan cierra los 10.**

---

## 4. El plan — por fases, cada una con su "foto de salida"

**Regla transversal (ya en vigor)**: nada se te enseña sin fotomontaje previo con muñecos +
rejilla + test numérico. Tú apruebas IMÁGENES, no descripciones. Y la especificación va SIEMPRE
por delante de producir contenido.

### Fase 1 — Cerrar el contrato visual (la especificación de Big Pharma)
- **El kit de referencia de escala**: UNA hoja con persona de pie + sentada + silla + mesa +
  puerta + papelera, con los ratios humanos objetivo impresos. Todo asset futuro se compara
  contra esa hoja ANTES de entrar. (Es el estándar de la industria; nos faltaba.)
- **Arrimar a la gente a sus muebles**: decidir contigo entre (a) el punto de asiento se desplaza
  hacia el borde de la celda que mira al mueble, o (b) los muebles crecen hasta el borde de su
  celda. Te llevo las dos variantes EN UNA IMAGEN y señalas.
- Re-render de radio/dispensador/pantallas a ratio humano + regla de post-proceso común para
  igualar el "grano" entre packs.
- *Foto de salida*: la hoja del kit de referencia con todo dentro de rango, aprobada por ti.

### Fase 2 — La ventanilla perfecta (la escena héroe)
- Aplicar TODO a una sola escena: ventanilla + espera. Si hace falta, pre-componer el "sentado"
  como hacía Theme Hospital (personaje+silla horneados juntos).
- Esa imagen aprobada se convierte en el **"hero asset"**: el patrón contra el que se compara
  todo lo que venga después.
- *Foto de salida*: el fotomontaje de la ventanilla que TÚ firmes como "así sí".

### Fase 3 — El escenario (que el fondo deje de ser andamio)
- Suelo con textura de baldosa/moqueta, paredes/puertas/ventanas con arte (tileset según art
  bible §4) — es el fondo permanente de la cámara: el salto visual más grande por euro invertido.
- La **comisaría inicial nueva** que ya decidiste (salas para puestos de 2 celdas + impresora
  obligatoria + descanso + 2 esperas), construida ya con el kit validado.
- *Foto de salida*: captura del juego con la comisaría nueva vestida.

### Fase 4 — La interfaz "expediente ministerial"
- HUD y 4 paneles según art bible §7 (ya aprobado por ti) + los patrones de tus capturas de Two
  Point (tarjetas con precio, categorías, checklist de obligatorios) + iconos de trámites.
- *Foto de salida*: el panel de construcción nuevo, en imagen, antes de programarlo.

### Fase 5 — El envoltorio
- Pantalla de título + menú + **créditos** (obligación CC-BY) + segundo modelo de ciudadano.
- *Foto de salida*: arrancar el juego desde el título como lo haría un desconocido.

**En paralelo, sin esperar al arte**: la mecánica de la impresora (diseño cerrado) y el resto de
jugabilidad siguen su curso — el juego funcional no se para por el vestido.

---

## 5. Qué cambia desde hoy (el resumen del resumen)

- **Antes**: producir pieza → mirarla sola → integrarla → descubrir el fallo en el juego → tú te
  quemas. **Ahora**: especificación → producir → medir contra el kit → fotomontaje con test →
  TU ojo → juego.
- Tu papel es el del diseñador de Big Pharma: decidir y aprobar imágenes. Explicar, lo justo:
  "se ve raro" + captura basta — traducirlo a números es trabajo mío.
- Cada fallo nuevo que aparezca (aparecerán: le pasan a Prison Architect) muere convertido en
  regla, como los cuatro de esta semana.

*Anexos: `investigacion/investigacion-web-tycoon.md` (fuentes citadas) y
`investigacion/auditoria-visual.md` (todas las medidas, reproducibles con su script).*
