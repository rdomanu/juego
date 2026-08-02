# Investigación de diseño — Cómo hacer un tycoon (mitad "Diseño")

> Encargo: investigar cómo se planifica, corrige y diseña un juego tycoon de gestión,
> con foco en economía/balance y fallos de diseño típicos. Proyecto de referencia:
> **Comisario** (tycoon de gestión de comisaría, Godot 4.6, núcleo ya implementado:
> flujo de ciudadanos con paciencia, puestos/personal/horarios, economía, construcción,
> día/noche; 709 tests).
>
> Estado: COMPLETO (6/6 secciones + 12 mandamientos + semáforo Comisario).
> Esta es la mitad "Diseño" de la investigación (bucle, economía/balance, progresión, fallos típicos,
> diseño de la información, tamaño de contenido). La mitad "Planificación/producción" (cómo trocear el
> trabajo, cadencia de sprints, gestión de alcance para un solo dev) la cubre otro agente por separado.

---

## 1. El bucle núcleo de los tycoon que funcionan

1. **El bucle mínimo del género se resume en observar → decidir → construir/ajustar → ver consecuencia,
   descrito de forma explícita en literatura de diseño como "construir → ganar → mejorar → construir
   más"** — cada vuelta del bucle tiene que cerrar en minutos, no en horas, para que el "una partida
   más"/"un ajuste más" psicológico se dispare. — [Medium, "Idle vs Incremental vs Tycoon: Understanding
   the core mechanics"](https://medium.com/tindalos-games/idle-vs-incremental-vs-tycoon-understanding-the-core-mechanics-f12d62f4b9f7)
2. **RimWorld se diseñó explícitamente como "generador de historias", no como juego de supervivencia
   puro** — Tynan Sylvester (creador) explicó en su charla de GDC 2017 que forzar al equipo a pensar el
   juego como *story generator* abrió mecanismos de diseño completamente distintos a pensar "qué sistema
   de supervivencia añado". El **"Storyteller" es un director de IA** que analiza el estado actual del
   jugador y elige qué evento disparar según lo que juzga que generará la narrativa más interesante — no
   tira eventos al azar, los selecciona activamente para maximizar drama. El juego ofrece tres
   Storytellers preconfigurados: **Cassandra Classic** (tensión creciente y liberación clásica), **Phoebe
   Chillax** (más aire entre eventos) y **Randy Random** (caos puro, sin narrativa). Esto demuestra que
   el **caos "controlado" es, literalmente, un algoritmo de ritmo dramático**, no aleatoriedad bruta. —
   [GDC Vault, "RimWorld: Contrarian, Ridiculous, and Impossible Game Design Methods"](https://www.gdcvault.com/play/1024232/-RimWorld-Contrarian-Ridiculous-and);
   [slides PDF oficial](https://media.gdcvault.com/gdc2017/Presentations/Sylvester_Tynan_RimWorld_Contrarian_Ridiculous.pdf)
3. **Prison Architect usa los disturbios (riots) como "modo de crisis" que transforma temporalmente el
   género del juego** — durante un disturbio, el constructor de prisiones se convierte en un simulador
   de asedio: hay que dirigir a la policía antidisturbios para reducir a los reclusos violentos mientras
   los bomberos apagan incendios. Una reseña lo describe así: "los retos caóticos son divertidos y te
   dejan mejor preparado para la siguiente crisis" — el objetivo central del juego (mantener a los presos
   dóciles pero contentos para evitar disturbios mientras generas beneficio) crea la tensión permanente
   de fondo, y el disturbio es la "factura" que se cobra cuando la gestión falla. Es caos **consecuencia**
   del sistema, no caos inyectado desde fuera. — [Game Informer, reseña Prison Architect](https://gameinformer.com/games/prison_architect/b/pc/archive/2015/10/06/prison-architect-review-game-informer.aspx)
4. **El "compulsion loop" (bucle de compulsión) es el término formal de diseño para lo que engancha a
   "una partida más"**: una cadena habitual de acciones con recompensa diseñada para generar una
   respuesta neuroquímica de repetición — tareas simples → recompensa inmediata → motivación para
   reiniciar el ciclo. Es la misma arquitectura psicológica detrás de sistemas de niveles, logros y
   contenido desbloqueable en tycoon: cada elemento existe para dar una sensación continua de progreso
   que sostenga el enganche a largo plazo. — [Wikipedia, "Compulsion loop"](https://en.wikipedia.org/wiki/Compulsion_loop);
   [Make Tech Easier, "Compulsion Loops and Dopamine Hits"](https://www.maketecheasier.com/why-games-are-designed-addictive/)
5. **Two Point Hospital diseñó su bucle de sesión explícitamente para funcionar tanto en sesiones cortas
   como en sesiones de horas** — el diseñador principal declaró en entrevista que gran parte del trabajo
   de balance de cifras se centró en que el juego "sea divertido y funcione tanto para partidas cortas
   como para sesiones de horas seguidas", en vez de optimizar solo para un tipo de sesión. Esto es
   diseño de macro-bucle deliberado: el mismo bucle de 30s (atender pacientes, ver colas) tiene que
   sostener tanto una sesión de 15 minutos como una de 3 horas sin volverse repetitivo ni agotador. —
   [PCGamesN, entrevista desarrolladores Two Point Hospital](https://www.pcgamesn.com/two-point-hospital/two-point-hospital-developer-interview)
6. **Multi-sistema como riesgo de diseño reconocido, no solo como virtud** — un análisis de diseño de
   Prison Architect señala que en un juego construido como colección de sistemas interconectados (como
   todo tycoon serio), **un problema en un solo sistema puede contaminar el resto**, lo que hace más
   difícil ver si el juego "está funcionando" durante el desarrollo — el bucle núcleo debe poder probarse
   aislado (prototipo mínimo) antes de acoplarlo a los demás sistemas, precisamente porque una vez
   acoplados es mucho más caro diagnosticar de dónde viene un problema de diversión. — [Game Developer,
   "What Prison Architect Teaches About Layered Game Design"](https://www.gamedeveloper.com/design/what-prison-architect-teaches-about-layered-game-design)

**Síntesis del tema:** el bucle núcleo que funciona no es "observar → decidir → construir" a secas —
es ese bucle **con un generador de tensión activo** (Storyteller de RimWorld, disturbios de Prison
Architect) que rompe la monotonía de gestionar un sistema que, sin fricción externa, tiende a
estabilizarse solo. El caos controlado no es ruido: es la variable de diseño que evita que la gestión
se convierta en un solitario resuelto una vez el jugador entiende el sistema.

## 2. Economía y balance — el fallo nº1 del género

**El fallo nº1 documentado en literatura de diseño económico es el desequilibrio grifo/sumidero
("faucet/sink"): si el grifo supera al sumidero durante demasiado tiempo, el dinero deja de significar
nada y la tensión desaparece.** Esto es exactamente "a mitad de partida sobra el dinero" que preguntaba
el encargo — tiene nombre técnico y una familia de soluciones conocida.

1. **Todo sistema económico de un juego es un grafo de grifos (fuentes) y sumideros (destinos); el
   fallo más común es que el ritmo del grifo supere al del sumidero de forma sostenida** — la solución
   estándar de la industria es modelar el ratio explícitamente: un objetivo de referencia citado en
   guías de balance es que el **grifo total sea ~1.1–1.3× el sumidero** en cada tramo de progresión (una
   sensación de acumulación lenta, no de desborde ni de sequía). — [Lost Garden, "Value chains — A method
   for creating and balancing faucet-and-drain game economies"](https://lostgarden.com/2021/12/12/value-chains/)
2. **El síntoma de "dinero sin sentido a mitad de partida" casi siempre es un problema de sumidero, no de
   grifo**: cuando el contenido de gasto se agota (ya construiste/compraste todo lo relevante) pero el
   grifo sigue activo, el dinero se acumula sin fricción y dejas de sentir escasez — el diagnóstico
   correcto no es "bajar los ingresos" sino "abrir sumideros nuevos al ritmo del contenido". —
   [DEV Community, "Idle Game Economy Design: What Your Currency Sinks Actually Eat"](https://dev.to/sam_novak_574b07811e18495/idle-game-economy-design-what-your-currency-sinks-actually-eat-1non)
3. **Balancear con hoja de cálculo antes que con intuición** es la práctica estándar en estudios indie de
   simulación: se modela cada fuente y cada gasto en una tabla, se proyecta la acumulación de dinero a lo
   largo de la partida, y se ajustan los multiplicadores hasta que la curva se comporte como se quiere
   —antes de tocar una sola línea de código de balance. — [StraySpark Studio, "Game Economy Balancing With
   Spreadsheets: A Practical Guide for Indie Developers"](https://www.strayspark.studio/blog/game-economy-balancing-spreadsheets)
4. **Cliff Harris (Positech — *Democracy*, *Kudos*, *Big Pharma*, *Production Line*) itera el balance
   jugando su propio juego, revisando datos de foro y rehaciendo hojas de cálculo de forma recurrente**;
   su conclusión repetida en el blog es que el público de simulación/tycoon está mucho más pendiente de
   la **mecánica, el balance y las features** que del apartado gráfico — el balance no es un detalle de
   pulido, es el producto. — [Cliffski's Blog, "Balancing lots of things"](https://www.positech.co.uk/cliffsblog/2009/09/09/balancing-lots-of-things/)
5. **Precio relativo al ritmo de ingreso, no a un número absoluto**: una heurística citada para dosificar
   compras grandes es anclarlas a **5–20 horas** de ingreso al ritmo del momento en que se desbloquean —
   es decir, cada sumidero grande se calibra contra la curva de ingresos de *ese* tramo de la partida, no
   contra una cifra fija pensada de antemano. — [DEV Community, "Idle Game Economy Design"](https://dev.to/sam_novak_574b07811e18495/idle-game-economy-design-what-your-currency-sinks-actually-eat-1non)
6. **Prison Architect es un caso de estudio de sumidero mal calibrado, no de grifo**: la comunidad
   documenta un exploit de "1 millón en 3 minutos" (comprar acciones/préstamo bancario, subir el valor de
   la prisión, recomprar acciones más baratas, cancelar el préstamo) y otro de fuerza bruta con talleres
   de madera/matrículas que generan ingresos muy por encima de cualquier gasto disponible en el juego —
   en ambos casos el problema no es que el grifo sea generoso, es que **no hay suficientes sumideros
   grandes y permanentes** que absorban ese dinero durante el resto de la partida. —
   [Introversion Forums, "Money Cheat (1 MILLION in 3 minutes)"](https://forums.introversion.co.uk/viewtopic.php?t=18163);
   [Prison Architect Fandom, "Finance"](https://prison-architect.fandom.com/wiki/Finance)
7. **La deuda con interés y los costes recurrentes (nómina, mantenimiento) son el sumidero "de fondo" que
   nunca se agota** — a diferencia de un sumidero de un solo uso (comprar un edificio), un coste que se
   repite cada ciclo (día/semana) escala automáticamente con el tamaño de la operación del jugador: cuanto
   más construyes y contratas, más sumidero recurrente generas tú mismo. Es la técnica de balance más
   robusta contra la inflación de caja porque no requiere que el diseñador prediga cuánto contenido
   comprará el jugador. — mismo patrón descrito en [Lost Garden, "Value chains"](https://lostgarden.com/2021/12/12/value-chains/)
   y confirmado como mecánica activa en juegos de gestión con nómina diaria (Prison Architect, Two Point
   Hospital, RimWorld).
8. **Costes crecientes por unidad adicional** (el 2º almacén cuesta más que el 1º, el 5º empleado del
   mismo tipo cuesta más que el 2º) es la técnica de balance más citada para evitar que "construir más de
   lo mismo" sea la estrategia dominante indefinidamente sin fricción — combina bien con retorno
   decreciente (ver hallazgo de Formación en la sección 4) para que expandirse siga siendo una decisión y
   no un clic sin coste de oportunidad. — patrón estándar de diseño económico citado en
   [Medium, "Designing Game Economies: Inflation, Resource Management, and Balance"](https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670).

**Síntesis del tema:** el género no falla por "poner poco dinero", falla por **no fabricar sumideros al
mismo ritmo que fabrica contenido nuevo para gastar en él**. Un tycoon 1.0 sano necesita: (a) un sumidero
recurrente que escale con el tamaño de la operación del jugador (nómina/mantenimiento), (b) sumideros de
un solo uso calibrados contra el ritmo de ingreso del tramo en que aparecen, y (c) costes crecientes por
unidad repetida para que "más de lo mismo" siga costando pensar.

## 3. Progresión y dosificación de contenido

1. **Two Point Hospital abandonó deliberadamente la progresión lineal de Theme Hospital** — Theme
   Hospital encadenaba niveles en una secuencia fija; Two Point Hospital cambió a una estructura **no
   lineal**, donde el jugador **desbloquea hospitales nuevos y puede llevar varios a la vez**. Esto
   convierte la campaña en un menú de contenido con orden flexible en vez de un pasillo, lo que da
   autonomía (SDT) sin renunciar a la dosificación por metas. — [GamesBeat / Game Developer, "How Two
   Point Studios carved its simulation game niche"](https://www.gamedeveloper.com/business/how-two-point-studios-carved-its-simulation-game-niche)
2. **La introducción de mecánicas nuevas debe ir "lo bastante rápido para no aburrir, lo bastante lenta
   para no abrumar"** — literatura de diseño de progresión formula el patrón en tres fases de dominio
   por mecánica (Principiante → Moderado → Experto) que se solapan con la llegada de la siguiente
   mecánica: el jugador nunca está sin nada nuevo que aprender, pero tampoco recibe una mecánica nueva
   antes de haber asimilado la anterior. Es la base formal del "algo nuevo cada X minutos" que preguntaba
   el encargo. — [Game Developer, "The Use of Gameplay Progression in Game Design"](https://www.gamedeveloper.com/design/the-use-of-gameplay-progression-in-game-design)
3. **Las recompensas "prácticas" (que cambian cómo se juega) sostienen la progresión mejor que las
   puramente cosméticas** — nuevos modos, mejoras y contenido desbloqueable jugable son citados como el
   "gancho" más eficaz para que el jugador siga adelante, precisamente porque cada desbloqueo abre
   decisiones nuevas (autonomía) en vez de solo decorar lo ya existente. — [GameDesignSkills, "Game
   Progression and Progression Systems"](https://gamedesignskills.com/game-design/game-progression/)
4. **Software Inc. (Coredumping, desarrollador solo) usa Early Access explícitamente como motor de
   dosificación de contenido**: el estudio declara que su filosofía es priorizar "calidad integral y
   refinamiento iterativo sobre un lanzamiento apresurado", incorporando feedback de comunidad en cada
   actualización — con ~269.000 copias vendidas y una puntuación media de 94.2/100 en ~7.600 reseñas, es
   evidencia de que **un solo desarrollador puede sostener un tycoon comercialmente viable dosificando
   contenido en el tiempo** en vez de intentar entregarlo todo en el 1.0. — [Grokipedia / VORYTHIC,
   datos de Software Inc.](https://vorythic.com/games/2856/software-inc)
5. **El "midgame aburrido" en progresión (no solo en economía) tiene la misma causa raíz que el
   desequilibrio de sumideros**: cuando el contenido nuevo (recompensa práctica) se agota antes que la
   sesión, el jugador entra en una meseta sin objetivos legibles. La crítica documentada a Game Dev
   Tycoon (definición de "éxito" poco clara en fases avanzadas, ver hallazgo #7 de la sección 4) es el
   mismo patrón aplicado a metas en vez de a dinero: **sin un objetivo visible y cambiante en cada fase,
   la sensación de progreso se apaga aunque el sistema siga funcionando técnicamente.** — [Pop Mythology,
   reseña Game Dev Tycoon](https://www.popmythology.com/game-dev-tycoon-review/)
6. **Sandbox vs. campaña no son mutuamente excluyentes — es una elección de "quién dosifica el reto"**:
   un análisis de por qué muchos city builders decepcionan en el tramo medio señala que, al estar
   pensados como **sandbox infinito**, los estudios no invierten esfuerzo en explicar ni en escalar retos
   pasado el arranque — el jugador queda solo dosificando su propio contenido, y sin una campaña o
   sistema de misiones que le proponga metas nuevas, tiende a derivar hacia el modo puramente creativo
   (que es válido, pero deja de ser "tycoon" en el sentido de reto de gestión). — [Discusión Steam /
   gamepressure sobre dificultad en city builders](https://steamcommunity.com/app/949230/discussions/0/3877095833482220275)

**Síntesis del tema:** dosificar contenido bien es, en el fondo, el mismo problema que dosificar
sumideros bien (sección 2): **el ritmo de "algo nuevo que hacer" tiene que mantenerse por encima del
ritmo al que el jugador agota lo ya disponible**, ya sea en forma de mecánica nueva, edificio nuevo,
misión nueva o simplemente un objetivo distinto. La campaña/misiones (Two Point Hospital) es una forma de
garantizar ese ritmo desde fuera; el sandbox puro delega esa responsabilidad al propio jugador, y el
riesgo de "midgame aburrido" aumenta en proporción a cuánto delega.

## 4. Fallos de diseño típicos del género y cómo se corrigieron

1. **Estrategia dominante que rompe el juego — RollerCoaster Tycoon (IA de invitados).** Los invitados
   pueden "decidir" que un camino concreto es la salida del parque aunque no lo sea, y se quedan
   caminando en círculos o pidiendo ayuda para "encontrar la salida"; los jugadores descubrieron que
   **bloqueando la salida real con carteles de "prohibido el paso"** los invitados que querían irse se
   quedaban indefinidamente dentro del parque (gastando más dinero) en vez de marcharse — una estrategia
   explotable que nace de un fallo de pathfinding, no de una regla económica, y que ningún parche del
   juego original llegó a cerrar del todo. Lección: **una IA de agente mal especificada puede convertirse
   en el sumidero/grifo más rentable del juego**, por accidente. — [RCT Fandom, "Guests and Staff" /
   discusión de comunidad sobre invitados que no encuentran la salida](https://rct.fandom.com/wiki/Guests_and_Staff)
2. **Estrategia dominante económica — Prison Architect (talleres de madera).** La guía de la comunidad
   documenta que **una granja forestal + talleres de matrículas/serrería** genera del orden de 50.000$ de
   exportación en un mapa grande, muy por encima de cualquier otro ingreso del juego — una vez descubierta,
   no hay razón de diseño para construir nada más para ganar dinero. Es el patrón clásico de **balance
   transitivo roto**: una opción no es "mejor con matices", es estrictamente mejor en todos los ejes. —
   [Prison Architect Fandom, "Finance"](https://prison-architect.fandom.com/wiki/Finance)
3. **Exploit de bucle infinito de dinero — Prison Architect (acciones + préstamo bancario).** Documentado
   por la comunidad: pedir un préstamo bancario para inflar la caja sin tocar el valor de la prisión,
   vender todas las acciones, maximizar el préstamo, recomprar acciones más baratas y cancelar el
   préstamo con el remanente genera dinero infinito. Es el ejemplo de manual de **frustra balance roto**:
   dos sistemas (mercado de acciones + préstamos) diseñados de forma independiente que, combinados,
   generan un bucle sin coste. La lección de proceso es que **los exploits de bucle casi nunca aparecen
   dentro de un solo sistema — aparecen en la intersección de dos sistemas que se diseñaron por
   separado**. — [Introversion Forums, "Money Cheat (1 MILLION in 3 minutes)"](https://forums.introversion.co.uk/viewtopic.php?t=18163)
4. **Información ilegible — SimCity 2000 vs. SimCity 3000/4 (asesores).** El primer sistema de asesores
   de SimCity 2000 fue mal recibido porque los asesores solo **soltaban un aviso breve y se quejaban**,
   sin dar suficiente contexto para actuar; SimCity 3000 lo corrigió dándoles **nombre propio y
   explicaciones más detalladas del problema concreto de su área**, aunque introdujo un fallo nuevo:
   cada asesor optimiza para SU departamento sin ver el conjunto, así que puede recomendar algo bueno
   para transporte pero malo para la ciudad entera. Lección doble: (a) un aviso sin explicación del
   "por qué" no es feedback útil, es ruido; (b) *feedback* por silo (un asesor por sistema) sin una vista
   agregada puede generar consejos contradictorios entre sí. — [SimCity Fandom, "Advisor"](https://simcity.fandom.com/wiki/Advisor);
   [SimCity Fandom, "SimCity:Advisors"](https://simcity.fandom.com/wiki/SimCity:Advisors)
5. **Micro-gestión tediosa sin automatización — patrón recurrente citado en foros de simulación
   (Automation: The Car Company Tycoon, gestión de turnos de tripulación en sims navales).** La queja
   documentada es "tener que asignar manualmente cada turno/tripulante sin ninguna opción de rotación
   automática por IA" — el género vive en tensión permanente entre **dar control total (tedioso a
   escala) y automatizar (arriesga que "el juego se juegue solo")**; los desarrolladores citan de forma
   explícita el miedo a que añadir más automatización aumente la complejidad de desarrollo, de cómputo y
   de comprensión del jugador a la vez, lo que explica por qué muchos tycoon dejan la automatización como
   *feature* tardía (desbloqueable) en vez de por defecto desde el minuto uno. — [Steam Community,
   discusión sobre micro-gestión en simulación de gestión](https://steamcommunity.com/app/494840/discussions/0/4509877334877392751)
6. **Dificultad plana / "midgame aburrido" — patrón transversal en constructores de ciudades.** La
   crítica documentada en discusión de comunidad sobre el género es literal: **"una vez que echas a
   andar tu economía, te vuelves insanamente rico y el juego pierde el factor diversión"** — muchos city
   builders están pensados como sandbox infinito y no invierten esfuerzo en explicar ni en escalar el
   reto después del arranque, lo que empuja a una parte de la base de jugadores a abandonar la vertiente
   de "reto" del juego y jugarlo puramente en modo creativo. La corrección documentada más citada
   (Transport Fever 2) es **extender el "endgame"** con retos de escala creciente en vez de dejar que la
   dificultad se aplane tras el arranque. — [gamepressure.com / discusión Steam sobre dificultad city
   builder](https://steamcommunity.com/app/949230/discussions/0/3877095833482220275)
7. **Definición de "éxito" poco clara en el late-game — Game Dev Tycoon.** Reseñas críticas señalan que
   el juego tiene una **definición inconsistente de qué es "tener éxito"**, lo que hace que el objetivo
   del jugador en las fases avanzadas se vuelva difuso — sin un objetivo legible en el late-game, el
   jugador no sabe si está progresando o solo manteniendo el statu quo, y varias reseñas lo describen
   directamente como una experiencia que se vuelve "monótona". Lección: **el objetivo visible debe seguir
   existiendo (y cambiar) en cada fase**, no solo en el arranque. — [Pop Mythology, reseña de Game Dev
   Tycoon](https://www.popmythology.com/game-dev-tycoon-review/)
8. **Falta de posibilidad real de fracaso — SimTower, corregido por Project Highrise.** SomaSim (los
   creadores de *Project Highrise*, sucesor espiritual de *SimTower*) señalan explícitamente en
   entrevista que en *SimTower* **era difícil fracasar de verdad**, y diseñaron *Project Highrise* a
   propósito para que **unas pocas decisiones malas puedan hundir tu rascacielos** — la corrección de
   diseño fue introducir consecuencia real (riesgo de fallo) donde antes solo había progresión sin
   fricción. Conecta directamente con el punto 6: sin la posibilidad creíble de perder, la "victoria"
   deja de significar nada a mitad de partida. — [GameGrin, entrevista Project Highrise](https://www.gamegrin.com/articles/project-highrise-interview/)

**Síntesis del tema:** los fallos más caros del género se agrupan en tres familias — (1) **una opción
estrictamente mejor en todos los ejes** (transitiva rota: talleres de Prison Architect, salida bloqueada
de RCT), (2) **dos sistemas correctos por separado que combinados generan un bucle sin fricción**
(acciones+préstamo de Prison Architect — el más peligroso porque es el más difícil de anticipar en
diseño aislado de un sistema), y (3) **ausencia de consecuencia/reto sostenido pasado el arranque**
(SimTower, city builders genéricos, Game Dev Tycoon). Las tres se detectan con la misma herramienta:
jugar (o simular en hoja de cálculo) hasta el final buscando "¿qué única cosa haría siempre, en cada
partida, si jugara para ganar lo más rápido posible?" — si la respuesta es siempre la misma, hay un
problema de diseño.

## 5. Diseño de la información — que el jugador sepa POR QUÉ

1. **Two Point Hospital resuelve "por qué me va mal" con capas de visualización (overlays), no con
   texto**: el juego ofrece **doce modos de visualización distintos** accesibles desde una pestaña de
   datos — modo de "atractivo" (verde = objetos atractivos, marrón = poco atractivos), modo de
   "temperatura" (azul/rojo = mal, amarillo = objetivo) y modo de "higiene", entre otros. La regla
   implícita de diseño es: **cada overlay traduce un número invisible en un color que se lee de un
   vistazo sobre el propio plano del edificio**, en vez de obligar al jugador a abrir un panel de
   estadísticas separado del espacio físico que está gestionando. — [Two Point Hospital Fandom,
   "Visualisation Modes"](https://two-point-hospital.fandom.com/wiki/Visualisation_Modes)
2. **Prison Architect traduce la calidad de una sala en una sola cifra legible por sala (Room Grading,
   escala 1–10, o 0–15 con DLC)**, visible desde un menú de logística dedicado (*Logistics → Room
   Quality*), y esa cifra se puede mejorar añadiendo objetos concretos (TV, mesa de billar, ventanas...)
   — el jugador no tiene que inferir por qué una celda "funciona peor": el número se lo dice, y la lista
   de objetos que lo mejoran le dice qué hacer al respecto. Es el patrón **"diagnóstico + receta" en el
   mismo panel**, no solo diagnóstico. — [Prison Architect Wiki, "Room Grading"](https://prisonarchitect.paradoxwikis.com/Room_Grading)
3. **La evolución de los asesores de SimCity (2000 → 3000) es el caso de estudio inverso — de "sin
   contexto" a "con contexto, pero sin visión de conjunto"**: SimCity 2000 fue criticado porque los
   asesores solo emitían quejas breves sin más explicación; SimCity 3000 les dio nombre propio y
   explicaciones más detalladas de *su* área concreta, pero cada asesor optimiza solo para su
   departamento, así que pueden chocar entre sí (uno recomienda algo bueno para transporte que es malo
   para la ciudad entera). La lección es doble: **un aviso sin razón no sirve, y varios avisos correctos
   mirando solo su propio silo pueden ser colectivamente contradictorios** — el diseño de información
   necesita tanto detalle local como una vista agregada que lo contextualice. — [SimCity Fandom,
   "Advisor"](https://simcity.fandom.com/wiki/Advisor) / ["SimCity:Advisors"](https://simcity.fandom.com/wiki/SimCity:Advisors)
4. **El apilamiento de notificaciones sin priorizar es un fallo de UI documentado de forma transversal en
   diseño de juegos**: cuando varias alertas llegan seguidas y se apilan una encima de otra, pueden tapar
   botones críticos y volverlos inoperables — la recomendación estándar es **priorizar qué se muestra
   según los pilares del juego y la necesidad real del jugador en ese momento**, en vez de mostrar todo lo
   que ocurre por orden de llegada. — [Data Calculus, "Designing In-Game Notifications and Alerts for
   UI/UX"](https://datacalculus.com/en/blog/computer-games/uiux-designer/designing-in-game-notifications-and-alerts-for-uiux)
5. **Patrón transversal del género para "diagnosticar en segundos": color sobre el espacio físico +
   umbrales de 3 niveles.** Tanto los modos de visualización de Two Point Hospital (verde/amarillo/rojo
   por zona) como la calificación de sala de Prison Architect (una cifra sobre la sala) comparten el
   mismo principio operativo: **el problema se pinta encima de dónde ocurre, no en una lista aparte**, y
   se reduce a pocos niveles de severidad (2-3 colores) en vez de a una cifra exacta que el jugador tenga
   que interpretar. Es la traducción práctica de la regla de oro "el jugador debe poder diagnosticar su
   problema en segundos": si hace falta leer un párrafo o comparar varias cifras para saber qué hacer, el
   diseño de información ha fallado. — síntesis cruzada de [Two Point Hospital Fandom](https://two-point-hospital.fandom.com/wiki/Visualisation_Modes)
   y [Prison Architect Wiki](https://prisonarchitect.paradoxwikis.com/Room_Grading).

**Síntesis del tema:** el patrón ganador del género no es "más datos", es **menos datos mejor situados**:
color codificado sobre el espacio físico (no en un panel aparte), pocos niveles de severidad (2-3, no una
escala continua), y — cuando hay un "asesor" o sistema de avisos — que explique el *porqué* concreto de
*su* área sin pretender sustituir una vista agregada del conjunto.

## 6. Tamaño de contenido de un tycoon 1.0 comercial pequeño

1. **Two Point Hospital (juego base, sin DLC) lanzó con un puñado de hospitales de campaña** que se
   multiplicaron después vía expansiones — contando **todas** las expansiones de historia (Bigfoot,
   Pebberley Island, Close Encounters, Off The Grid, Culture Shock, A Stitch in Time, Speedy Recovery), el
   total sube a **36 hospitales en 12 regiones**, a razón de 3 hospitales por DLC — es decir, el contenido
   de un 1.0 comercial de este calibre (estudio con equipo, no solo dev) es una fracción de esa cifra
   final; el resto se construyó **después del lanzamiento**, vía DLCs sucesivos, no de una vez. —
   [Two Point Hospital Fandom, "Hospitals"](https://two-point-hospital.fandom.com/wiki/Hospitals)
2. **La duración objetivo de "campaña principal" de un tycoon de este tamaño ronda las 20-25 horas**: el
   dato agregado de tiempo hasta completar la historia principal de Two Point Hospital se sitúa en
   **~24 horas**, con **~126 horas** si se busca el 100% (tres estrellas en todos los hospitales +
   contenido opcional) — la brecha entre ambas cifras (24h vs. 126h) es el propio diseño de rejugabilidad:
   el mismo contenido de campaña se estira 5× solo con un sistema de puntuación por estrellas que invita a
   volver a un hospital ya "terminado". — [GGDB, "How long is Two Point Hospital?"](https://ggdb.pro/time-to-beat/two-point-hospital)
3. **Big Pharma (desarrollador esencialmente en solitario, Tim Wicksteed / Twice Circled) lanzó con "más
   de tres docenas" de escenarios** (objetivos del tipo "gana X en Y años" o "entrega Z unidades de un
   fármaco concreto"), además del modo sandbox libre — es una referencia útil de **cuánto contenido de
   "misiones/retos" puede sostener en solitario un solo diseñador** sin que sea un sandbox vacío ni un
   generador procedural: unas cuantas decenas de escenarios curados a mano, reutilizando el mismo motor
   de simulación (máquinas + ingredientes + cinta transportadora) para cada uno. — [Nintendo Life,
   reseña Big Pharma](https://www.nintendolife.com/reviews/switch-eshop/big_pharma)
4. **Project Highrise (estudio pequeño, SomaSim) segmenta su contenido en 4 tipos de edificio
   (oficina, residencial, comercial, hotel) con un puñado de niveles de sala por tipo** (p. ej. oficina
   pequeña/mediana/grande/HQ; restaurante de puesto ambulante hasta gourmet; habitación de hotel
   individual/doble/suite) — no docenas de variantes por categoría, sino **3-5 escalones de progresión
   por categoría de sala**, cada uno con requisitos de desbloqueo propios. Es una plantilla de alcance
   razonable para un solo sistema de contenido: pocas categorías, pocos escalones por categoría, mucha
   combinatoria entre ellas. — [Project Highrise Fandom, "Tenants"](https://projecthighrise.fandom.com/wiki/Tenants);
   [guía de comunidad "Room sizes"](https://steamcommunity.com/sharedfiles/filedetails/?id=760435368)
5. **Software Inc. (un solo desarrollador, Kenneth Otto Larsen / Coredumping) sostiene ~269.000 copias
   vendidas y 94.2/100 de valoración media con un alcance construido en capas sobre Early Access** —
   evidencia de que el contenido de un tycoon comercialmente viable hecho por una persona no necesita
   igualar el volumen de un estudio: puede crecer **después** del lanzamiento inicial, en vez de intentar
   llegar completo al 1.0. — [VORYTHIC, datos Software Inc.](https://vorythic.com/games/2856/software-inc)

**Síntesis del tema, para calibrar alcance de un solo dev:** el patrón que se repite en los cuatro
ejemplos (Two Point Hospital con DLC escalonados, Big Pharma con "unas cuantas decenas" de escenarios
curados, Project Highrise con 4 categorías × 3-5 escalones, Software Inc. creciendo en Early Access) es
el mismo: **un 1.0 pequeño no necesita mucho contenido de partida, necesita un motor de contenido barato
de repetir** (un tipo de sala/máquina/escenario parametrizable) para poder añadir más unidades después sin
rediseñar el sistema. La cifra concreta razonable para un 1.0 de un solo dev, extrapolando estos casos:
**del orden de una decena de tipos de "sala/puesto" jugables, 20-40 escenarios/misiones curados o un
sandbox con metas claras, y 15-25 horas de contenido de campaña** antes de apoyarse en rejugabilidad
(puntuación, dificultad creciente) para estirar la duración total.


*(pendiente)*

## Los 12 mandamientos de diseño de un tycoon

1. **El sumidero debe crecer al mismo ritmo que el grifo.** Si el dinero deja de doler, la gestión deja
   de importar — el fallo nº1 del género no es "poca economía", es sumidero atrasado (sección 2).
2. **Todo sumidero grande se calibra contra el ritmo de ingreso del tramo en que aparece**, no contra una
   cifra fija pensada de antemano (sección 2).
3. **Prioriza costes recurrentes que escalan solos con el tamaño de tu operación** (nómina, mantenimiento,
   interés de deuda) sobre sumideros de un solo uso — son el sumidero más robusto porque no requieren que
   el diseñador prediga cuánto contenido comprará el jugador (sección 2).
4. **Balancea con hoja de cálculo antes que a ojo, y valida con playtest real** — la intuición sirve para
   proponer valores, no para confirmarlos (sección 2).
5. **Busca activamente tu estrategia dominante**: pregúntate "¿qué haría siempre, en cada partida, si
   jugara para ganar lo más rápido posible?" — si la respuesta es siempre la misma, hay un fallo de
   balance transitivo que tarde o temprano encontrará el jugador (sección 4).
6. **Los exploits más peligrosos nacen en la intersección de dos sistemas diseñados por separado**, no
   dentro de un sistema aislado — revisa combinaciones, no solo sistemas en su cápsula (sección 4).
7. **El caos debe ser consecuencia del sistema (o un director de ritmo activo), no ruido aleatorio
   inyectado desde fuera** — sin él, la gestión se estabiliza y se convierte en un solitario resuelto
   (sección 1).
8. **Dosifica contenido nuevo al mismo ritmo al que el jugador agota lo que ya tiene** — el "midgame
   aburrido" es, en el fondo, el mismo problema que el sumidero atrasado, aplicado a objetivos en vez de a
   dinero (secciones 2 y 3).
9. **Dale al jugador consecuencia real: la posibilidad creíble de fracasar** — sin riesgo, "ganar" deja de
   significar nada a mitad de partida; pero distingue fallo blando (se reintenta) de derrota terminal
   (game over), para que el castigo sea proporcional (sección 4).
10. **Pinta el problema encima del espacio donde ocurre, con pocos niveles de severidad (2-3 colores)**,
    nunca solo en un panel de texto aparte — es la base del diagnóstico en segundos (sección 5).
11. **Si das un "asesor" o sistema de avisos, que explique el porqué concreto de su área Y ofrezca
    también una vista agregada** — un aviso sin razón es ruido, y varios avisos correctos por silo pueden
    ser colectivamente contradictorios (sección 5).
12. **Un 1.0 pequeño no necesita mucho contenido de partida: necesita un motor de contenido barato de
    repetir** (una plantilla de sala/misión/escenario parametrizable) para poder añadir más unidades
    después sin rediseñar el sistema — así es como los tycoon pequeños (e incluso de un solo dev) crecen
    de forma sostenible (sección 6).

## Semáforo Comisario — honestidad, sin peloteo

> Contrastado contra `design/gdd/economy-budget.md`, `design/gdd/patience-satisfaction.md`,
> `design/gdd/demand-generation.md` y `design/gdd/systems-index.md` (estado real de los documentos en el
> momento de escribir esto). Leyenda: 🟢 cumple · 🟡 parcial / pendiente de validar · 🔴 riesgo real o no
> cumplido todavía · ⚪ no verificado (no leí el documento que lo confirmaría).

| # | Mandamiento | Semáforo | Por qué |
|---|-------------|:--:|---------|
| 1 | Sumidero crece al ritmo del grifo | 🟡 | La nómina (E3) sí escala con la dotación, pero no hay **coste creciente por unidad repetida** (el 2º puesto de Documentación cuesta lo mismo que el 1º, `coste_construccion_eur` es fijo por tipo en Datos) ni mantenimiento recurrente de mobiliario (el "deterioro/mantenimiento" de Comodidades #15 está diferido, `Not Started`). Los "nuevos canales al ascender" (subvenciones, bonus DGP) son **Open Question #6** en `economy-budget.md`: previstos, no resueltos. |
| 2 | Sumidero grande calibrado al ritmo de ingreso del tramo | 🟢 | `caja_inicial_eur` (3000) está calibrada explícitamente contra el gasto de arranque real (~2 puestos Doc + 1 ODAC + 2 salas) **incluyendo** el matiz de que ODAC es obligatorio y no genera ingreso — el propio documento corrige un cálculo optimista inicial ("el neto de arranque no es ~110€/día, es ~40€/día") antes de fijar el valor. Buena práctica, con la honestidad añadida de marcarlo "a validar en playtest" (Open Question #3). |
| 3 | Coste recurrente que escala con el tamaño de tu operación | 🟢 | Nómina diaria = suma de `salario_dia_efectivo` de cada agente contratado (E3/F3); el recargo de deuda escala con el tamaño de la deuda (F5); la penalización de préstamos vivos tiene un componente % que auto-escala con tus ingresos del día (F8, documentado explícitamente como diseño deliberado: "en días malos pesa menos, no te remata"). Es el punto más sólido del sistema económico actual. |
| 4 | Balance con hoja de cálculo + playtest real | 🟡 | El proceso está bien declarado — casi todos los valores semilla llevan la etiqueta "provisional, a validar en playtest" y hay Open Questions dedicadas — pero según la documentación disponible **el playtest real de balance con datos de juego aún no se ha ejecutado**: lo que existe hoy son 709 tests automatizados (verifican que la lógica/fórmulas hacen lo que dicen las Acceptance Criteria), que es distinto de validar que los *valores* se sienten bien jugando. |
| 5 | Buscar activamente la estrategia dominante | 🔴 | **Documentación es la única fuente de ingreso del MVP; ODAC "no genera ingreso (obligación; rinde reputación, no euros)"** (E2, confirmado en `economy-budget.md` y `patience-satisfaction.md`). No hay evidencia en los GDDs de que se haya hecho el ejercicio explícito de estrés: la estrategia obvia de un jugador optimizador — maximizar puestos/personal de Documentación y dotar ODAC al mínimo posible — no tiene hoy un contrapeso económico duro; su único freno es la "valoración de jefes" (#28), que en el MVP es solo un *hook* sin mecánica de consecuencia definida. Riesgo real, no hipotético, y coincide exactamente con el patrón de Prison Architect (sección 4, hallazgo 2). |
| 6 | Vigilar exploits en la intersección de sistemas | 🟢 | Hay evidencia clara de que este ejercicio SÍ se hizo: el bucle Paciencia↔ODAC (PS13) lleva una guarda explícita "sin recursión" (una `reclamacion` que abandona en ODAC no genera otra reclamación); el sistema de préstamos (E9) tiene 12+ edge cases documentados y un orden determinista de aplicación (F6: recargo → gastos → reinicio) precisamente para evitar ambigüedad en la intersección deuda↔nómina↔préstamos. |
| 7 | Caos como consecuencia del sistema, no ruido | 🔴 | El único "caos" del MVP es la variación de demanda por franja horaria, y está diseñada **deliberadamente acotada** ("nunca hay un colapso irresoluble", calibrada al invariante R5) — es variación predecible, no un generador de tensión activo tipo Storyteller de RimWorld o disturbios de Prison Architect. Los sistemas que aportarían eso (#16 Presión e Influencia, #22 Sala 091/Incidentes) están **en el roadmap pero "Not Started"** (Vertical Slice / Alpha). No es un error de diseño — es una ausencia conocida y priorizada — pero hoy no está cumplido. |
| 8 | Dosificar contenido nuevo al ritmo de agotamiento del jugador | 🟡 | Coherente con el alcance declarado del MVP ("probar si el bucle central es divertido"), pero **tal cual está diseñado hoy, dentro de una sola sesión el MVP no añade nada nuevo**: Ascensos (#18) exige 1 año completo de juego (48 jornadas) + valoración ≥75% + curso; Comodidades, Formación, Horarios y Cita previa son todas "Vertical Slice, Not Started". El riesgo de "midgame aburrido" (sección 3) es real en cuanto una sesión de playtest supere la primera media hora sin nada de esa capa. |
| 9 | Consecuencia real: posibilidad creíble de fracasar | 🟢 | Es uno de los puntos mejor resueltos: hay **game over real y terminal** (insolvencia con préstamos agotados → "te echan de la comisaría"), explícitamente distinto de fallar el objetivo mensual (blando, se reintenta). El propio documento declara la anti-fantasía a evitar ("NO es un simulador de quiebra cruel donde un mal día te borra la partida") — exactamente el equilibrio que Project Highrise buscó corrigiendo a SimTower (sección 4, hallazgo 8). |
| 10 | Diagnóstico visual en el espacio, pocos niveles de severidad | 🟢 | Paciencia usa exactamente 3 niveles de color **por persona, visibles en la sala** (🟢>66% / 🟡33-66% / 🔴<33%, PS5) — es el mismo patrón que el "heat mode" de Two Point Hospital, aplicado a personas; el estado financiero de Economía también usa color por umbral (holgado/justo/números rojos). No verificado si existe además un overlay **agregado** de planta (p. ej. "qué sala está más hacinada de un vistazo") — no leí `ui-hud.md` a fondo. |
| 11 | Asesor con porqué + vista agregada | ⚪ | No verificado — no leí `ui-hud.md` ni `feedback-juice.md` en detalle en esta sesión; no puedo afirmar si Comisario tiene o planea algo equivalente a un "asesor". Recomendación: revisar esto específicamente la próxima vez que se toque UI/HUD. |
| 12 | Motor de contenido barato de repetir | 🟢 | Es uno de los aciertos de arquitectura de diseño más claros del proyecto: `Escenario` (Datos F7) está pensado explícitamente como plantilla extensible — cada comisaría nueva (Pozuelo → Parla → distritos de Madrid → Centro, sistema #26) es una instancia de `Escenario` parametrizada por población/criminalidad real, con la demanda ya escalando por escenario y el invariante R5 validado por escenario, "sin rework" según la propia nota de diseño. El catálogo de trámites/denuncias también es 100% data-driven. |

**Balance del semáforo:** 6 🟢 · 3 🟡 · 2 🔴 · 1 ⚪. Los dos rojos son los que más importan según la
prioridad del encargo (economía y fallos de diseño): **(5) ODAC como coste puro sin contrapeso duro** es
una estrategia dominante latente que vale la pena resolver *antes* de que el playtest la confirme por las
malas, y **(7) ausencia de un generador de caos/tensión activo** es esperable en esta fase (está en el
roadmap), pero conviene no confundir "variación de demanda acotada" con el "caos controlado" que de verdad
sostiene el enganche a largo plazo en RimWorld o Prison Architect.
