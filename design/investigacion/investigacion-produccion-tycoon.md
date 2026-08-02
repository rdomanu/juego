# Investigación de producción — Tycoons hechos por equipos de 1-3 personas

> Encargo: cómo planificarlo, las herramientas, correcciones, principales fallos y cómo
> solucionarlos. Esta mitad cubre PRODUCCIÓN Y TÉCNICA (la otra mitad, arte, se investiga aparte).
> Metodología: búsquedas web (postmortems, devlogs, GDC, foros), 4-8 hallazgos accionables por
> tema, cada uno con su fuente.

---

## 1. Planificación: cuánto tardan de verdad, en qué orden construyen, qué recortan

1. **El caso extremo que hay que conocer: los tycoons "no son divertidos hasta que encajan todas
   las piezas".** Patrick Klug (Greenheart Games, los creadores de *Game Dev Tycoon*) tardó **más
   de 11 años** en sacar *Tavern Keeper* a Early Access, pasó por **6 versiones distintas del
   juego** y **cambió de motor 3 veces**. Su cita literal: *"los juegos de gestión no funcionan
   como los demás géneros: normalmente todo encaja al final, así que eso lo hace cada vez más
   difícil"*. Los primeros 7 años, dice, "no fueron divertidos". Esto no es un fallo de
   planificación — es una propiedad estructural del género: un tycoon con 3 sistemas a medias no
   se "siente" ni la mitad de bien que el mismo tycoon con 3 sistemas completos que se retroalimentan.
   [PC Gamer — "It wasn't fun for the first 7 years"](https://www.pcgamer.com/games/sim/it-wasnt-fun-for-the-first-7-years-says-maker-of-fantasy-sim-tavern-keeper-which-spent-more-than-a-decade-in-development/) ·
   [PC Gamer — "taking 10 years to make his upcoming inn sim"](https://www.pcgamer.com/games/life-sim/my-kids-werent-born-yet-and-now-theyre-in-primary-school-learning-how-to-make-their-own-games-game-dev-tycoon-studio-head-talks-taking-10-years-to-make-his-upcoming-inn-sim-tavern-keeper/)

2. **La consecuencia práctica de (1): no midas el progreso de un tycoon por "¿ya es divertido?"
   demasiado pronto.** Mídelo por "¿ya están los sistemas clave conectados entre sí?". La
   diversión en este género emerge de la interacción de sistemas (economía + demanda + agentes +
   satisfacción), no de un sistema aislado pulido al 100%. Esto **no** es excusa para no
   playtestear pronto (ver sección 5) — es un aviso de que el resultado de esos playtests tempranos
   será "flojo/plano" incluso si vas bien encaminado, y hay que saber diferenciar "flojo porque
   faltan piezas" de "flojo porque el diseño no funciona". [PC Gamer, ídem](https://www.pcgamer.com/games/life-sim/my-kids-werent-born-yet-and-now-theyre-in-primary-school-learning-how-to-make-their-own-games-game-dev-tycoon-studio-head-talks-taking-10-years-to-make-his-upcoming-inn-sim-tavern-keeper/)

3. **Los casos rápidos existen y comparten un patrón: alcance deliberadamente pequeño.**
   *Game Dev Tycoon* (Greenheart Games, 2 hermanos) pasó de los primeros conceptos (oct. 2011) a
   una primera versión pública en Windows Store en solo un año, y a la versión completa en
   diciembre de 2012 — con una empresa formada apenas 5 meses antes del lanzamiento. Es un tycoon
   deliberadamente simple (una sola curva de progresión, sin agentes individuales moviéndose por un
   mapa), lo que explica la velocidad. [Wikipedia — Game Dev Tycoon](https://en.wikipedia.org/wiki/Game_Dev_Tycoon) ·
   [Greenheart Games — About](https://www.greenheartgames.com/about/)

4. **"80% hecho" en un tycoon suele significar "80% más de trabajo por delante".**
   *Project Highrise* (SomaSim, equipo pequeño) tenía previsto salir en mayo y acabó saliendo en
   septiembre del mismo año, precisamente por esto — cita del propio estudio en su artículo de
   postmortem de diseño. Para planificación esto se traduce en: **añade siempre colchón al final
   del proyecto, no solo en cada sprint** (el colchón por sprint no cubre este efecto acumulado).
   [Game Developer — "Capturing the essence of skyscraper management in Project Highrise"](https://www.gamedeveloper.com/design/capturing-the-essence-of-skyscraper-management-in-i-project-highrise-i-)

5. **Recortar minucias de simulación es una decisión de diseño explícita, no una derrota.**
   El mismo equipo de *Project Highrise* decidió conscientemente **no** simular el mantenimiento
   detallado y aleatorio de un rascacielos real — lo abstrajeron a un sistema de desgaste no
   aleatorio para que el foco del jugador siguiera estando en construir y expandir, no en apagar
   fuegos de mantenimiento. Es el mismo principio que en la sección 2 (Sid Meier: "tira las partes
   no divertidas de la simulación"), aplicado en fase de planificación, no de corrección a
   posteriori. [Game Developer, ídem](https://www.gamedeveloper.com/design/capturing-the-essence-of-skyscraper-management-in-i-project-highrise-i-)

6. **Early Access no es el final del desarrollo — puede ser la mitad, y hay que planificarlo así.**
   *Rise of Industry* (Dapper Penguin Studios, equipo indie pequeño) entró en Early Access en
   febrero de 2018 y no llegó a la versión 1.0 hasta mayo de 2019 — **15 meses de Early Access**,
   sin contar el desarrollo previo en alpha/pre-alpha en itch.io. Planificar "Early Access" como un
   hito de "ya casi está" es un error de calendario habitual del género.
   [Wikipedia — Rise of Industry](https://en.wikipedia.org/wiki/Rise_of_Industry)

7. **Las estimaciones de un solo-dev sobre "cuánto falta" suelen fallar por mucho, incluso viniendo
   de quien mejor conoce el proyecto.** El desarrollador de *Software Inc.* (un solo-dev) declaró
   que, tras 6 meses, el juego ya estaba "jugable y casi completo en funciones" y calculó que le
   quedarían unos 2 años más para terminarlo — el juego lleva desde entonces **muchos más años** en
   Early Access. La lección de planificación no es "no estimes", es "no publiques ni prometas fecha
   de salida basada en la primera estimación post-prototipo": revisa la estimación cada hito, no
   solo al principio. [Steam — Software Inc.](https://store.steampowered.com/app/362620/Software_Inc/)

8. **El prototipo desechable antes que el "vertical slice" pulido, en este género concreto.**
   Tynan Sylvester (*RimWorld*, solo-dev al inicio) no llegó al diseño final probando una única
   idea pulida: prototipó repetidamente (su prototipo previo, *Starship Architect*, era un juego
   distinto) hasta encontrar el bucle que funcionaba, y su charla de GDC defiende explícitamente
   *no planificar de más* y dejar huecos deliberados en el diseño. Para un tycoon con sistemas que
   solo "hacen clic" al combinarse (hallazgo 1), un vertical slice único y pulido desde el minuto
   uno es más difícil de lograr que en otros géneros — varios prototipos baratos y desechables para
   validar UN sistema o UNA interacción a la vez encajan mejor con esa realidad.
   [GDC Vault — "RimWorld: Contrarian, Ridiculous, and Impossible Game Design Methods"](https://www.gdcvault.com/play/1024232/-RimWorld-Contrarian-Ridiculous-and) ·
   [Game Developer — video resumen de la charla](https://www.gamedeveloper.com/design/video-how-i-rimworld-i-found-success-through-ridiculous-contrarian-design)

---

## 2. Fallos de producción típicos del género y sus remedios documentados

1. **Feature creep en tycoons/sims tiene una causa raíz específica: el propio desarrollador es su
   público más entusiasta.** Cliff Harris (Positech Games, *Democracy*, *Gratuitous Space
   Battles*) lo describe así: el interés personal necesario para motivar a un dev indie es el mismo
   que genera "feature creep" masivo — como no hay un jefe que diga "no, eso no entra", la línea
   entre "el juego que yo jugaría sin parar" y "el juego que quiero hacer" desaparece. **Remedio
   documentado**: ponerse tú mismo en el papel del "jefe que dice que no" — una lista de alcance
   fijada por escrito actúa como ese límite externo que un indie no tiene de forma natural.
   [Cliffski's Blog — "Learn from the veterans"](https://www.positech.co.uk/cliffsblog/2013/09/05/learn-from-the-veterans/)

2. **"Simular hasta el café": la filosofía de diseño de Sid Meier es el remedio canónico.** Su
   principio de diseño — tirar las partes de la simulación que no generan decisiones interesantes
   y quedarse solo con las que sí — viene motivado por una observación muy concreta: en
   simulaciones muy detalladas y opacas, **o el diseñador se divierte programando el detalle, o el
   ordenador "se divierte" ejecutándolo, pero el jugador no**. Aplicado a un tycoon: cada sistema
   nuevo de simulación debe justificarse por la decisión de juego que habilita, no por el realismo
   que añade. [Game Developer — "Analysis: Sid Meier's Key Design Lessons"](https://www.gamedeveloper.com/game-platforms/analysis-sid-meier-s-key-design-lessons)

3. **El balance de un tycoon con muchos sistemas interconectados es, según quien los ha hecho,
   "muy difícil" de forma estructural, no por falta de habilidad.** Cliff Harris señala
   explícitamente que *Democracy 3* y *Gratuitous Space Battles* — ambos con muchas variables
   cruzadas — son "muy difíciles de balancear". **Remedio documentado en la práctica del género**:
   externalizar los números a hojas de cálculo controladas por fórmulas (ver sección 4) para poder
   iterar el balance sin recompilar ni tocar código, y así permitirse muchas más pasadas de ajuste
   de las que el calendario permitiría si cada cambio de número fuera un cambio de código.
   [Cliffski's Blog, ídem](https://www.positech.co.uk/cliffsblog/2013/09/05/learn-from-the-veterans/)

4. **Rehacer sistemas enteros varias veces antes de que "hagan clic" es un patrón repetido, no una
   excepción.** El caso más extremo documentado es de nuevo *Tavern Keeper*: 6 versiones del juego
   y 3 motores distintos en 11 años, porque "puede llevar mucho tiempo refinar sistemas hasta que
   se vuelven divertidos" cuando se trabaja sobre una IP y un diseño nuevos. El propio estudio
   señala como aprendizaje que, con la experiencia acumulada, tuvieron "muy pocos cambios" en los
   últimos años de desarrollo — es decir, el patrón de reescritura se concentra al principio del
   proyecto, cuando el diseño todavía no está validado, y remite según se acumula validación real.
   [PC Gamer — ídem](https://www.pcgamer.com/games/sim/it-wasnt-fun-for-the-first-7-years-says-maker-of-fantasy-sim-tavern-keeper-which-spent-more-than-a-decade-in-development/) ·
   [GamesRadar+ — "After 11 grueling years and 6 different versions"](https://www.gamesradar.com/games/simulation/after-11-grueling-years-and-6-different-versions-of-the-game-management-sim-devs-decide-theyve-finally-made-something-that-doesnt-suck-tavern-keeper-wasnt-fun-for-ages/)

5. **El feature creep no es solo "demasiadas mecánicas": el propio Game Developer (antes
   Gamasutra) lo trata como riesgo #1 de "casi todo proyecto de juego"** porque los requisitos
   cambian durante el desarrollo casi por definición. La literatura del sector propone matarlo
   "sin decir nunca que no" — es decir, en vez de vetar ideas nuevas de golpe (lo que genera
   fricción y resentimiento en equipos, y auto-sabotaje en solo-devs), **aparcarlas en una lista de
   "v2" visible** en vez de descartarlas: el impulso de añadir se satisface por escrito sin tocar el
   calendario actual. [Game Developer — "Killing Feature Creep Without Ever Saying No"](https://www.gamedeveloper.com/production/killing-feature-creep-without-ever-saying-no) ·
   [Game Developer — "Beating Feature Creep"](https://www.gamedeveloper.com/business/beating-feature-creep)

6. **Playtestear tarde es el fallo #1 reportado específicamente por developers indie, según el
   único estudio académico encontrado sobre el tema (10 entrevistas a estudios indie).** La
   restricción documentada no es "no querer testear", es estructural: acceso limitado a
   participantes, sesgo de muestra (amigos y familia no son el público objetivo) y falta de datos
   de usuario en fases tempranas — problemas que afectan más a un indie/solo-dev que a un estudio
   grande con presupuesto de UX research. **Remedio**: los propios estudios entrevistados
   compensan con testeo cualitativo temprano (observar, no solo encuestar) en vez de intentar
   replicar la escala cuantitativa de un estudio AAA. [arXiv 2411.17183 — "Pre-Release
   Experimentation in Indie Game Development: An Interview Survey"](https://arxiv.org/abs/2411.17183)

7. **Bug de economía en cascada — ejemplo documentado real, no hipotético.** En *Car Tycoon*, un
   bug hacía que las fábricas compradas con préstamo en ciertos mapas **nunca empezaran a
   producir**, lo que provocaba una caída brusca de ingresos con la deuda del préstamo siguiendo
   intacta — una espiral económica negativa causada por un fallo de estado, no de diseño de
   balance. Es el ejemplo canónico de por qué los sistemas económicos con deuda/interés compuesto
   necesitan tests automatizados de "no quiebra imposible de recuperar" antes de confiar en el
   playtesting manual para detectarlo (ver también sección 3). [Wikipedia — Car Tycoon](https://en.wikipedia.org/wiki/Car_Tycoon)

---

## 3. Arquitectura de simulación (conceptos, no código)

1. **Desacoplar el "tiempo de simulación" del "tiempo de frame" es el patrón base de cualquier
   simulación determinista.** La arquitectura recomendada avanza el tiempo de simulación en
   incrementos fijos e iguales (ticks) *independientemente* de cuánto tarde cada actualización en
   tiempo real — y, si es posible, independiente también del reloj del sistema. Un simulador
   "acoplado a frames" (que avanza según el delta-time del frame) tiene un límite estructural de
   determinismo por mucho que se ajuste el tick rate, porque los frames en sí no son deterministas
   (dependen de la carga de la máquina). Para un tycoon esto importa sobre todo por el guardado y
   por la velocidad de simulación (x1/x2/x3), que en Godot típicamente se implementa variando
   *cuántos ticks lógicos* se ejecutan por frame, no la duración del tick.
   [developersvoice.com — "Architecting a Game Loop in C#"](https://developersvoice.com/blog/csharp/architecting-real-time-simulation-loops-in-csharp/) ·
   [Jakub's tech blog — "Reliable fixed timestep & inputs"](https://jakubtomsu.github.io/posts/input_in_fixed_timestep/)

2. **Cuando el tick de simulación y el frame de render no coinciden, se interpola visualmente entre
   dos estados de simulación** en vez de renderizar el estado "crudo" — así el movimiento se ve
   fluido aunque la lógica avance a paso fijo más lento. Es la técnica estándar en juegos con
   simulación de red (donde el patrón nació) y se aplica igual en local: la lógica de negocio
   (colas, producción, dinero) corre a tick fijo; la posición dibujada de un agente caminando por el
   mapa se interpola entre su posición del tick anterior y el actual. [SnapNet — "Netcode
   Architectures Part 1: Lockstep"](https://www.snapnet.dev/blog/netcode-architectures-part-1-lockstep/)

3. **Guardar partida en un tycoon es, en la inmensa mayoría de los casos observados en el sector,
   una foto fija del estado ("snapshot"), no un registro de eventos reproducibles.** El patrón de
   *event sourcing* (guardar cada acción como evento y reconstruir el estado reproduciéndolas) es
   potente para *undo*, auditoría o telemetría, pero como mecanismo de guardado principal de una
   simulación de cientos de agentes tiene un coste que crece con las horas jugadas (hay que
   "re-simular" todo desde el evento cero, o mantener snapshots periódicos de todas formas) y
   arrastra riesgo de *drift* si algún cálculo no es perfectamente determinista entre versiones del
   juego. La práctica estándar de la industria (fuera del género tycoon también) es usar snapshots
   como mecanismo principal, y reservar el registro de eventos para necesidades puntuales
   (telemetría, historial de decisiones, no el save/load crítico). [Kurrent — "Snapshots in Event
   Sourcing"](https://www.kurrent.io/blog/snapshots-in-event-sourcing/) · [Microservices.io —
   "Pattern: Event sourcing"](https://microservices.io/patterns/data/event-sourcing.html)

4. **LOD de simulación: no toda la IA necesita pensar cada tick.** Las técnicas documentadas para
   escalar de 10 a 1000+ agentes sin que el framerate se resienta combinan tres cosas: *time-slicing*
   (repartir las actualizaciones de IA entre varios frames en vez de recalcular todo cada frame),
   *LOD de complejidad* (un agente lejos de la cámara o irrelevante para el jugador usa una versión
   más barata de su lógica), y *cacheo de resultados de pathfinding* para rutas repetidas — muy
   relevante en un tycoon donde decenas de empleados/clientes recorren las mismas rutas del mapa una
   y otra vez. [GameAIPro — "Pathfinding Architecture Optimizations" (Steve Rabin & Nathan
   Sturtevant)](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter17_Pathfinding_Architecture_Optimizations.pdf)

5. **El pathfinding es, con diferencia, el mayor sumidero de CPU en una simulación con muchos
   agentes**, especialmente cuando hay que recalcular rutas para cientos de unidades. La
   recomendación estándar es A* como algoritmo base, combinado con las técnicas del punto anterior
   (cache + LOD) en vez de recalcular desde cero cada vez que el mapa cambia ligeramente.
   [GameAIPro, ídem](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter17_Pathfinding_Architecture_Optimizations.pdf)

6. **El bug clásico "espiral económica" nace casi siempre de un estado que se queda a medias, no de
   una fórmula mal calculada.** Como en el caso de *Car Tycoon* (sección 2, hallazgo 7): una compra
   financiada con deuda que queda en un estado intermedio (comprado pero nunca activado) rompe el
   supuesto que el sistema económico da por hecho ("todo lo que genera deuda también genera
   ingreso"). La lección de arquitectura es tratar las transacciones económicas compuestas (compra +
   activación + primera producción) como una única operación atómica verificable, no como pasos
   independientes que pueden quedar a medias tras un guardado, una excepción o un cambio de escena.
   [Wikipedia — Car Tycoon](https://en.wikipedia.org/wiki/Car_Tycoon)

---

## 4. Herramientas internas que construyen y consideran rentables

1. **La consola/panel de debug es la herramienta más citada de forma transversal como "línea de
   vida" del desarrollo**, descrita literalmente como "tu sistema de alerta temprana". No es solo
   para el desarrollador: un panel de debug bien hecho permite que un tester (amigo, streamer,
   jugador de una demo) genere reportes de bug mucho más útiles y detallados, porque puede exponer
   estado interno (qué estaba haciendo el agente X, qué cola tenía Y elementos) sin que el
   probador necesite saber programar. [Wayline — "Unlock Your Game Dev Superpowers: Why a Robust
   Debug Console is a Must-Have"](https://www.wayline.io/blog/game-dev-debug-console-guide)

2. **La tubería "hoja de cálculo → JSON/datos del motor" es prácticamente universal en el diseño de
   sistemas y balance, no una rareza.** La práctica más citada: el diseño y el balance de números
   viven en Google Sheets como "fuente de la verdad", con un script (Apps Script o similar) que
   exporta a un formato que el motor consume — así el diseñador itera fórmulas y curvas sin tocar
   código ni esperar una recompilación, algo crítico en un tycoon donde el balance es, como se vio
   en la sección 2, el problema más difícil y el que más iteraciones necesita.
   [StraySpark — "Game Economy Balancing With Spreadsheets: A Practical Guide for Indie
   Developers"](https://www.strayspark.studio/blog/game-economy-balancing-spreadsheets) ·
   [Wayline — "The Spreadsheet Revolution"](https://www.wayline.io/blog/spreadsheet-revolution-indie-game-dev)

3. **"Prácticamente todo diseñador tiene una hoja de balance que empezó en Google Sheets"** —
   confirmado también desde el lado de estudios más grandes (Hutch Games, mobile), lo que indica
   que la práctica no es un atajo de indie con pocos recursos sino el flujo de trabajo estándar del
   oficio de diseño de sistemas, independientemente del tamaño del equipo.
   [Medium — "Spreadsheet Tools in Game Design" (Guillem Orpinell)](https://medium.com/@urpi/spreadsheet-tools-in-game-design-57511eac68c) ·
   [Hutch Games — "For the love of spreadsheets"](https://www.hutch.io/blog/tech/tech-blog-game-changer/)

4. **Telemetría mínima viable: no hace falta un sistema de analítica complejo desde el primer día.**
   La recomendación documentada para equipos indie es empezar con un puñado de eventos concretos
   (inicio/fin de sesión, hitos de progreso, abandono en un punto del flujo) en vez de instrumentar
   todo el juego — el objetivo es encontrar fricción de onboarding y problemas de ritmo antes del
   lanzamiento, no construir un dashboard completo. [gamineai.com — "The First 10 Telemetry Events
   Every Indie Game Should Ship — And Why"](https://gamineai.com/blog/the-first-10-telemetry-events-every-indie-game-should-ship-and-why)

5. **La telemetría de "dónde se atasca la gente" se construye como un embudo (funnel), no como un
   mapa de calor genérico.** El patrón documentado: definir una secuencia lineal de pasos esperados
   (ej. tutorial → primer cliente atendido → primer empleado contratado) y medir en qué paso se cae
   la gente; un embudo con caída fuerte en un paso concreto es mucho más accionable que estadísticas
   agregadas de toda la sesión. Los mapas de calor por coordenadas se reservan para localizar
   *dónde* dentro de un nivel/mapa ocurre el atasco, una vez que el embudo ya dijo *en qué paso*.
   [Track Player Drop-Off Points with Game Telemetry](https://salivity.github.io/game-development/article/track-player-drop-off-points-with-game-telemetry)

6. **Honestidad sobre este hallazgo**: no se ha encontrado, en esta pasada de búsqueda, una cita
   directa de un desarrollador de tycoon nombrando explícitamente "esta herramienta interna fue la
   más rentable de todas". Lo que sí es un patrón repetido y consistente entre las fuentes
   consultadas es que **panel de debug** y **tubería de datos externalizados (hoja de cálculo →
   motor)** son las dos herramientas que aparecen citadas una y otra vez como las de mayor
   apalancamiento para equipos pequeños — la primera por ahorrar tiempo de investigación de bugs, la
   segunda por multiplicar cuántas pasadas de balance caben en el calendario. Tratar esto como
   "patrón fuertemente sugerido por la literatura", no como una cita literal de ROI medido.

---

## 5. Playtesting para un tycoon

1. **Cadencia habitual entre developers indie: ciclos cortos (fin de semana a una semana),
   alternados con rachas de un mes de testeo intensivo seguidas de pausas para implementar
   funciones grandes.** No es una cadencia fija semanal universal — se ajusta al ritmo de "cuánto
   hay nuevo que valga la pena testear", que en un tycoon (por el hallazgo 1 de la sección 1) puede
   significar rachas largas sin nada muy testeable seguidas de una ráfaga cuando varios sistemas
   convergen. [Kokutech — "Playtest Your Indie Game: A Developer's Guide"](https://www.kokutech.com/blog/gamedev/tips/development/guide-for-prototype-testing-for-indie-game-devs)

2. **"Ojos frescos" es una necesidad estructural, no un lujo, y afecta más al solo-dev que a un
   equipo.** Un desarrollador que lleva meses con el juego (y los amigos que llevan testeándolo
   desde el principio) dejan de poder experimentarlo como alguien nuevo — lo que a ellos les parece
   intuitivo puede confundir o aburrir a un jugador real. La recomendación es rotar probadores
   nuevos activamente, no reciclar siempre a los mismos. [Kokutech, ídem](https://www.kokutech.com/blog/gamedev/tips/development/guide-for-prototype-testing-for-indie-game-devs)

3. **"En cuanto haya un concepto jugable, ponlo en manos de otra persona"** — la recomendación es
   probar pronto y a menudo, no esperar a tener algo presentable. El coste de enseñar algo feo es
   mucho menor que el coste de descubrir tarde que una mecánica no gusta. [Kokutech, ídem](https://www.kokutech.com/blog/gamedev/tips/development/guide-for-prototype-testing-for-indie-game-devs) ·
   [Game Developer — "6 steps to a successful playtesting process for an indie developer"](https://www.gamedeveloper.com/programming/6-steps-to-a-successful-playtesting-process-for-an-indie-developer)

4. **Playtesting con streamers: ver a otra persona jugar en directo revela fallos de forma mucho
   más rápida que leer un cuestionario.** Ver dónde alguien duda, hace clic donde no debería, o se
   pierde, aporta una señal que un formulario post-partida no captura (la persona suele racionalizar
   su confusión a posteriori). Es la vía de testeo con desconocidos más accesible para un solo-dev
   sin presupuesto de UX research. [Quora — "Who do solo indie game developers get to beta test
   their games?"](https://www.quora.com/Who-do-solo-indie-game-developers-get-to-beta-test-their-games)

5. **El único estudio académico encontrado sobre experimentación pre-lanzamiento en indies (10
   estudios entrevistados) confirma que el testeo indie es mayoritariamente cualitativo, no
   cuantitativo — y que esto es una limitación de recursos, no una elección.** Su marco de 5 partes
   para diseñar un experimento de playtest es: (1) definir el objetivo, (2) diseñar la estrategia,
   (3) elegir qué objeto/versión del juego se prueba, (4) definir la estrategia de muestreo de
   probadores, (5) definir la estrategia de ejecución. Útil como checklist antes de cada ronda de
   playtest, en vez de improvisar cada vez. [arXiv 2411.17183](https://arxiv.org/abs/2411.17183)

6. **Steam Next Fest NO debe ser el primer testeo del juego — debe ser la confirmación pública de
   algo ya validado en privado.** El dato más fuerte encontrado en el análisis de resultados de
   Next Fest es que el número de wishlists *antes* del festival predice con mucha fuerza
   (correlación de Spearman 0.825) las wishlists ganadas *durante* el festival — "si no tienes
   nada, el festival dobla la nada". Esto implica: el trabajo de validación (jugabilidad, claridad,
   gancho) tiene que estar resuelto por playtesting privado *antes* de gastar el "momento Next
   Fest", porque el festival amplifica el estado en que ya estás, no lo corrige.
   [Second Stage — "Steam Next Fest: The Data Behind What Actually Drives Wishlists"](https://secondstage.io/2026/04/steam-next-fest-the-data-behind-what-actually-drives-wishlists)

7. **Descargar la demo no es, ni de lejos, el principal factor de conversión a wishlist en Next
   Fest — entre el 68% y el 88% de las wishlists provienen de gente que ni siquiera jugó la demo.**
   Esto redefine qué hay que testear con playtesters reales frente a qué hay que testear con
   feedback de "solo mirar" (capturas, tráiler, texto de la ficha de Steam): la demo se juega y se
   testea con un grupo pequeño y comprometido; la ficha de Steam (arte de cabecera, descripción,
   capturas) se testea con feedback rápido de mucha más gente, porque es lo que realmente convierte
   en volumen. [presskit.gg — "Analyzing Steam Next Fest Results"](https://presskit.gg/field-guides/analyzing-next-fest-results)

---

## 6. Lanzamiento pequeño (Early Access, demo, wishlists, precio)

1. **Early Access es, en la práctica observada, la norma y no la excepción para tycoons hechos por
   equipos pequeños — y varios lo justifican explícitamente como sustituto de un equipo de QA que
   no pueden pagar.** El desarrollador de *Software Inc.* lo dice sin rodeos: eligió Early Access
   porque "necesitaré feedback, ya que es imposible descubrir yo solo todos los fallos de diseño y
   problemas". *Rise of Industry* (EA feb. 2018 → 1.0 mayo 2019, ~15 meses) fue elogiado
   explícitamente por su "total apertura" y "gran disposición a escuchar feedback de jugadores"
   durante ese periodo. [Steam — Software Inc.](https://store.steampowered.com/app/362620/Software_Inc/) ·
   [Wikipedia — Rise of Industry](https://en.wikipedia.org/wiki/Rise_of_Industry)

2. **Entrar en Early Access no obliga a enseñarlo todo de golpe — se puede (y según Greenheart
   Games, conviene) pulir primero el tramo inicial del juego y aplicar lo aprendido antes de
   destapar el resto.** Es la estrategia explícita de *Tavern Keeper* al entrar en EA en noviembre
   de 2025 tras 11 años de desarrollo privado: no lanzaron "todo lo que tenían hecho", sino que
   decidieron pulir la primera parte del juego primero. Para un solo-dev, esto reduce la superficie
   de feedback a gestionar en la primera ronda de EA. [PC Gamer — "Even in early access, Tavern
   Keeper already feels like the fantasy pub sim of my dreams"](https://www.pcgamer.com/games/sim/even-in-early-access-tavern-keeper-already-feels-like-the-fantasy-pub-sim-of-my-dreams/)

3. **Steam Next Fest en cifras recientes: la mediana de una demo gana ~806 wishlists durante el
   festival; el percentil 70 llega a 1.839; el percentil 95 necesita 13.461; el líder del ranking
   llegó a 57.074.** Las descargas de demo en Next Fest se mueven mayoritariamente entre 2.000 y
   30.000, con la mediana en la franja de 5.000-8.000. Sirve como referencia realista de expectativas
   para un estudio de 1-3 personas: los resultados "top" son atípicos, no el escenario a planificar.
   [Second Stage, ídem](https://secondstage.io/2026/04/steam-next-fest-the-data-behind-what-actually-drives-wishlists) ·
   [Gamosy — "Steam Next Fest Survival Guide"](https://gamosy.com/blog/steam-next-fest-guide)

4. **Objetivo de wishlists antes del lanzamiento: la vara de medir de referencia del sector
   (actualizada 2026) marca 5.000 como nivel "Bronce", 8.000 "Plata", 50.000 "Oro" y 90.000
   "Diamante"; ~7.000 es lo habitual para aparecer en la lista "Popular Upcoming" de Steam.** Las
   ventas de la primera semana suelen rondar el 15-20% del número de wishlists acumuladas al
   lanzamiento (rango documentado 10-25%). Esto permite retro-calcular un objetivo de wishlists a
   partir de un objetivo de ventas de primera semana, útil para fijar metas de marketing realistas
   con antelación. [steamforecast.app — "How Many Wishlists Before Steam Launch?"](https://steamforecast.app/guides/how-many-wishlists-before-steam-launch) ·
   [How To Market A Game — "How many wishlists should I have when I launch my game?"](https://howtomarketagame.com/2022/09/26/how-many-wishlists-should-i-have-when-i-launch-my-game/)

5. **Precio típico del género: los tycoons/sims indie en Steam se agrupan mayoritariamente entre
   9,99 € y 20 €, con una concentración fuerte alrededor de 14,99-15 €.** *Game Dev Tycoon* se
   posiciona en el extremo alto (20 €) pese a ser un juego de alcance relativamente modesto —
   indicando que una marca/IP ya reconocida (su primer título fue un éxito viral) permite sostener
   un precio más alto que el alcance técnico por sí solo justificaría. Referencia útil: fijar precio
   por alcance real + comparables directos, no solo por "cuánto trabajo ha costado".
   [gg.deals — Tycoon games](https://gg.deals/games/tycoon/) ·
   [Steam — Game Dev Tycoon](https://store.steampowered.com/app/239820/Game_Dev_Tycoon/)

---

## El plan de producción tipo de un tycoon solo-dev

Síntesis de los seis apartados anteriores, en el orden en que la evidencia sugiere abordarlos:

1. **Prototipos desechables del bucle nuclear** (no un vertical slice pulido) — valida UNA
   interacción de sistemas a la vez (ej. "cola de clientes + un empleado + un recurso"), tira el
   código si no funciona. *(Secciones 1.8, 2.4)*
2. **Diseño de sistemas y balance en hoja de cálculo externa desde el principio**, no en el motor —
   así el balance (el problema más difícil del género, sección 2.3) se puede iterar sin tocar
   código. *(Sección 4.2-4.3)*
3. **Arquitectura de simulación a tick fijo, desacoplada del framerate**, con guardado por
   snapshot, decidida ANTES de que haya muchos sistemas dependiendo de ella — cambiarla a mitad de
   proyecto es mucho más caro que decidirla bien al principio. *(Sección 3.1-3.3)*
4. **Panel de debug / consola de comandos como herramienta temprana**, no como algo que se añade
   "cuando haga falta" — reduce el coste de cada ronda de playtest y de cada bug reportado por
   terceros. *(Sección 4.1)*
5. **Conectar 2-3 sistemas core hasta que "hagan clic" entre sí**, aceptando que el resultado
   parezca "flojo" más tiempo del esperado — es la naturaleza del género, no una señal de fallo.
   *(Sección 1.1-1.2)*
6. **Playtesting cualitativo temprano y frecuente con desconocidos** (streamers, comunidades,
   amigos-de-amigos), en ciclos cortos alternados con rachas de implementación — no esperar a tener
   algo "presentable". *(Sección 5.1-5.5)*
7. **Recortar minucias de simulación de forma activa** en cuanto un sistema no genere decisiones
   interesantes para el jugador — aplicar el filtro de Sid Meier / Project Highrise antes de que el
   sistema se vuelva difícil de arrancar por lo enredado que está con el resto. *(Sección 2.2, 2.5;
   1.5)*
8. **Telemetría mínima + embudo de abandono** antes de mostrar el juego más ampliamente, para poder
   medir objetivamente "dónde se aburre la gente" en vez de depender solo de impresión subjetiva.
   *(Sección 4.4-4.5)*
9. **Playtesting privado que valide el gancho ANTES de gastar el "momento Next Fest"** — festival,
   demo pública y wishlists son un amplificador de lo que ya funciona, no una herramienta de
   corrección de diseño. *(Sección 5.6-5.7)*
10. **Early Access como continuación del playtesting a escala, no como "ya casi está"** —
    presupuestando meses (no semanas) adicionales tras la entrada en EA, y decidiendo
    conscientemente enseñar solo una porción pulida del contenido en vez de todo lo construido
    hasta la fecha. *(Sección 1.6, 6.1-6.2)*

---

## Dónde está Comisario en ese plan

Evaluación honesta contra el estado actual del repositorio (16 documentos de diseño en
`design/gdd/`, 3 sprints registrados en `production/sprints/`, ningún hito formal aún en
`production/milestones/`, jugabilidad núcleo implementada con 709 tests según el encargo):

- **Paso 1 (prototipos desechables del bucle nuclear) — hecho.** El proyecto ya tiene simulación
  núcleo implementada y validada con tests, lo cual va más allá de un prototipo desechable: implica
  que ya hay al menos un bucle que "funciona" técnicamente.
- **Paso 2 (balance en hoja de cálculo externa) — estado a verificar, no evaluado en esta
  investigación** (fuera del alcance de esta mitad — corresponde comprobarlo contra
  `design/gdd/economy-budget.md` y `design/gdd/data-config.md`, que ya existen como documentos).
- **Paso 3 (arquitectura a tick fijo + snapshot) — estado a verificar.** Existen documentos de
  diseño dedicados a `time-system.md`, lo que sugiere que la decisión de arquitectura temporal ya
  se ha abordado a nivel de diseño; si aún no se ha revisado contra los criterios de la sección 3
  de este informe (tick fijo desacoplado del framerate, snapshot vs eventos), es el primer punto de
  chequeo técnico recomendado antes de seguir avanzando, porque cambiarlo después es caro (ver
  síntesis, punto 3).
- **Paso 4 (panel de debug) — estado a verificar** contra `tools/` (fuera del alcance de esta
  investigación, pero es una comprobación barata: ¿existe ya una consola/panel de depuración
  accesible en tiempo de ejecución?).
- **Paso 5 (sistemas core conectados) — parcialmente hecho.** Con 16 documentos de diseño de
  sistemas distintos (agentes de personal, demanda, colas, paciencia/satisfacción, construcción,
  economía...) y jugabilidad núcleo con tests, el proyecto ya está en la fase donde varios sistemas
  existen — el hito relevante ahora es confirmar que ya "hacen clic" entre sí jugando, no solo que
  cada uno pasa sus tests por separado (un test unitario valida el sistema aislado; no valida que
  la combinación se sienta bien, que es precisamente el reto documentado en la sección 1).
- **Paso 6 (playtesting cualitativo con desconocidos) — es, con alta probabilidad, el siguiente
  paso pendiente más importante.** No se ha encontrado ningún artefacto de playtesting (informes,
  sesiones, feedback documentado) en el árbol de producción explorado. Según toda la evidencia de
  la sección 5, este es exactamente el punto del plan donde un solo-dev con simulación núcleo ya
  validada por tests debería estar entrando — los tests confirman que el sistema hace lo que se
  diseñó que hiciera, pero ningún test automatizado puede confirmar que sea *divertido* o
  *comprensible* para alguien que lo ve por primera vez.
- **Pasos 7-10 (recorte activo de minucias, telemetría, Next Fest, Early Access) — prematuros
  todavía.** Son pasos de la fase de pulido/lanzamiento; no tiene sentido invertir tiempo ahí antes
  de validar con playtesting real que el bucle nuclear ya conectado (paso 5) engancha a alguien que
  no sea el propio desarrollador.

**En una frase**: la mitad de producción/técnica de Comisario está fuerte en cimientos
(simulación con tests, documentación de diseño extensa, sistemas conectados) y floja en el paso que
casi todas las fuentes de este informe señalan como el que más se posterga y el que más caro sale
posponer — playtesting real con alguien que no sea el propio desarrollador.
