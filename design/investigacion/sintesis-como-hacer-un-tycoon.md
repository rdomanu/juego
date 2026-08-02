# Cómo se hace un tycoon — síntesis de la investigación y hoja de ruta de Comisario

**Fecha**: 2026-08-03 · **Encargo del usuario**: *"investigar cómo hacer un juego tycoon: cómo
planificarlo, las herramientas, correcciones, principales fallos y cómo solucionarlos, diseños"*.

**Anexos con todas las fuentes** (mismo directorio): `investigacion-diseno-tycoon.md` (el diseño:
bucle, economía, progresión, fallos del género) e `investigacion-produccion-tycoon.md` (la
producción: planificación, herramientas, playtesting, lanzamiento). Este documento es el cruce de
ambos con NUESTRO estado real — los semáforos de aquí salen de contrastar contra nuestros GDDs,
no de suponer.

---

## 1. Las cinco lecciones que más nos importan

1. **"Un tycoon no es divertido hasta que las piezas encajan" — y eso es normal, no una señal de
   fracaso.** El caso extremo: Tavern Keeper, 11 años y 3 motores por no fijar alcance; el caso
   rápido: Game Dev Tycoon, ~5 meses. La diferencia no fue el talento — fue el alcance cerrado y
   aceptar que el juego "parece flojo" más tiempo del que uno esperaría. Nos pasó esta semana con
   el arte: la sensación de "no llega" es parte del proceso documentado del género.

2. **La regla de Sid Meier: no simules nada que no genere una decisión interesante del jugador.**
   Es EL guardarraíl contra el fallo de producción nº1 (perderse simulando detalles — "simular
   hasta el café"). Cada sistema nuevo de Comisario debería pasar ese filtro antes de escribirse.

3. **El fallo de diseño nº1 del género: el sumidero atrasado.** A mitad de partida sobra el
   dinero, nada duele, la tensión muere. El remedio: costes recurrentes que escalan solos con el
   tamaño de tu operación (nómina ✓ ya lo tenemos), mantenimiento (la impresora ya lo introduce:
   2 €/turno de uso — patrón a generalizar), y calibrar cada sumidero contra los ingresos del
   tramo donde aparece.

4. **El paso que todos posponen y que más caro sale posponer: playtestear con un DESCONOCIDO.**
   Los 709 tests demuestran que el juego hace lo que diseñamos; ningún test demuestra que sea
   divertido o comprensible para alguien que lo ve por primera vez. Toda la evidencia de
   producción apunta aquí como nuestro siguiente gran paso.

5. **Sin caos controlado, la gestión se convierte en un solitario resuelto.** Lo que engancha a
   largo plazo en RimWorld o Prison Architect es un generador de tensión (eventos, incidentes,
   presión) que nace del propio sistema. Nuestro MVP tiene variación de demanda acotada — no es
   lo mismo, y está bien PARA ESTA FASE (los sistemas #16 Presión y #22 Incidentes ya están en
   el roadmap), pero hay que saber que ese motor aún no existe.

---

## 2. El semáforo de Comisario — los 12 mandamientos del género

Contrastado contra nuestros GDDs reales (detalle completo y fuentes en el anexo de diseño).
**Balance: 6 verdes · 3 amarillos · 2 rojos · 1 sin verificar.**

| # | Mandamiento | Nuestro estado |
|---|---|:--:|
| 1 | El sumidero crece al ritmo del grifo | 🟡 sin coste creciente por unidad ni mantenimiento general (la impresora lo estrena) |
| 2 | Sumideros calibrados al ritmo de ingreso de su tramo | 🟢 la caja inicial está calibrada con honestidad ejemplar |
| 3 | Costes recurrentes que escalan con la operación | 🟢 nómina + deuda: nuestro punto económico más sólido |
| 4 | Balance con hoja de cálculo + playtest real | 🟡 valores etiquetados "a validar en playtest"… que aún no se ha hecho |
| 5 | Buscar la estrategia dominante activamente | 🔴 **ODAC es coste puro sin contrapeso duro** — el jugador óptimo lo dotaría al mínimo |
| 6 | Vigilar exploits entre sistemas | 🟢 hay evidencia real de este ejercicio (guardas anti-recursión, órdenes deterministas) |
| 7 | Caos como consecuencia del sistema | 🔴 **no existe generador de tensión activo** (conocido: roadmap #16/#22) |
| 8 | Dosificar contenido al ritmo del jugador | 🟡 dentro de una sesión, el MVP no estrena nada nuevo (ascensos = 48 jornadas) |
| 9 | Posibilidad creíble de fracasar | 🟢 game over real e insolvencia bien diseñados (fallo blando ≠ derrota) |
| 10 | Diagnóstico visual en el espacio, 2-3 colores | 🟢 la paciencia por persona ya es el patrón de Two Point |
| 11 | Avisos con porqué + vista agregada | ⚪ verificar cuando toquemos UI/HUD |
| 12 | Motor de contenido barato de repetir | 🟢 los Escenarios parametrizados (Pozuelo→Parla→Madrid) son un acierto de libro |

**Los dos rojos, en llano:**

- **🔴 Mandamiento 5 — la estrategia dominante latente de ODAC.** Hoy, un jugador que juegue a
  ganar montaría el mínimo ODAC legal y todo Documentación (que es lo único que da dinero). El
  freno previsto (la valoración de los jefes) aún no tiene dientes mecánicos. **Es una decisión
  de diseño para el usuario** — opciones típicas del género: multas/consecuencias por denuncias
  mal atendidas, la valoración de jefes con efectos económicos reales, o ingresos indirectos por
  reputación. Conviene decidirlo ANTES de que el primer playtest lo descubra por las malas.
- **🔴 Mandamiento 7 — sin generador de caos.** No es un error: es una ausencia priorizada
  conscientemente (roadmap). Se anota para que nadie confunda "demanda variable" con el motor de
  tensión que sostiene el enganche.

---

## 3. El plan de producción tipo (10 pasos) y dónde estamos

Del anexo de producción, el orden que la evidencia sugiere — con nuestro estado:

1. Prototipos desechables del bucle nuclear → **HECHO** (prototipo HTML validado + simulación con tests).
2. Balance en hoja de cálculo externa → **A MEDIAS**: nuestros datos son data-driven
   (catálogo `.tres` generado), pero el balance no se itera aún en una hoja externa.
3. Tick fijo desacoplado del framerate + guardado snapshot → **HECHO** (sistema de Tiempo con
   GDD propio, saves idempotentes — verificado esta semana con la migración de huellas).
4. Panel de debug temprano → **HECHO** (panel DEV con F1 en editor).
5. Sistemas core conectados hasta que "hagan clic" → **CASI**: conectados y con tests; falta
   confirmar que "hacen clic" JUGANDO (ver paso 6).
6. **Playtesting cualitativo con desconocidos → NUESTRO SIGUIENTE GRAN PASO.** No existe ni un
   artefacto de playtest con alguien ajeno en todo el árbol de producción.
7. Recorte activo de minucias (filtro Sid Meier) → adoptado como regla desde hoy.
8. Telemetría mínima ("¿dónde se aburre la gente?") → prematuro; anotado para después del paso 6.
9. Demo/Next Fest solo cuando el gancho esté validado en privado → futuro.
10. Early Access como playtesting a escala, no como "ya casi está" → futuro.

---

## 4. Qué cambia en nuestra hoja de ruta (integración con el plan visual)

El plan visual de 5 fases (`design/art/plan-calidad-visual.md`) sigue vigente tal cual. Esta
investigación le añade tres cosas:

1. **Nuevo hito "Playtest 0"** después de la Fase 3 del plan visual (comisaría nueva vestida):
   sentar a UNA persona ajena al proyecto delante del juego, observar sin ayudar, y anotar dónde
   se pierde y dónde se aburre. Barato, y toda la evidencia dice que es lo que más información da
   por hora invertida. (No hace falta esperar al arte perfecto: hace falta que no despiste.)
2. **Decisión de diseño pendiente con el usuario: el contrapeso de ODAC** (rojo del mandamiento
   5). Se llevará como siempre: propuesta con números y opciones, el usuario decide.
3. **Dos reglas de proceso adoptadas desde ya**: el filtro de Sid Meier para cada sistema nuevo
   ("¿qué decisión interesante genera esto?"), y los 12 mandamientos como checklist de revisión
   de diseño (la impresora, por ejemplo, ya cumple 1, 3 y 12: mantenimiento recurrente por uso y
   patrón repetible).

**La respuesta a la pregunta de fondo, otra vez y con más evidencia**: todo lo que nos falta
aparece en la literatura como problema CONOCIDO con solución CONOCIDA, y los casos comparables
(Big Pharma, Game Dev Tycoon) los resolvieron equipos de una persona. El camino existe; lo que
toca es andarlo por orden: Fase 1 del plan visual → ventanilla perfecta → comisaría nueva →
Playtest 0.
