Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript,
2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN.

═══ MODO DE TRABAJO (orden del usuario, 2026-08-01 — ES LO PRIMERO) ═══
TÚ (Fable 5) SOLO COORDINAS Y REVISAS. El trabajo va a subagentes, y el modelo del subagente se
elige POR LA DIFICULTAD DE LA TAREA:
 · `model: sonnet` (Sonnet 5) — el caso normal: papeleo, documentación, exploración del repo,
   inventarios, diagnósticos acotados, tests de una sola cosa, cambios mecánicos.
 · `model: opus` (Opus 5) — solo cuando es DE VERDAD difícil: arquitectura, un bug que ya resistió
   un intento, refactor que cruza sistemas, o razonar sobre concurrencia y orden de ejecución.
Lanza EN PARALELO los que no toquen los mismos archivos.
NO delegues: decisiones de diseño con el usuario, balance, el veredicto final de si algo vale, y lo
que toque el corazón del juego.
⚠️ VERIFICA SIEMPRE TÚ MISMO — suite completa + arranque headless — sin fiarte del informe de un
subagente. En el prompt de cada agente: "plan YA APROBADO, NO pidas aprobación, ejecuta" y "NO hagas
commit". Los subagentes SE QUEDAN SIN TURNO escribiendo documentos largos: trocea (un documento por
agente) y comprueba que TERMINARON mirando los archivos, no el informe.

═══ LA TAREA DE ESTA SESIÓN ═══
DARLE CAÑA A LOS DISEÑOS. El estilo ya está decidido: **LOW-POLY** (con el tono Two Point). Hay un
pipeline 3D→sprites YA FUNCIONANDO y assets descargados esperando.

ORDEN PROPUESTO (confírmalo con el usuario antes de arrancar):
 1. **El catálogo visual de la oficina.** `capturas/NPC/Oficina/isometric_office.glb` trae 748 mallas
    llamadas `Object_1023` — así no hay forma de saber qué es cada cosa. Escribir una variante del
    renderizador que saque UNA MINIATURA DE CADA MALLA, montar una hoja de contactos y que el usuario
    elija a dedo: "esta es la mesa, esta la silla, esta la planta". MIRAR, no suponer.
 2. **Sustituir el mobiliario placeholder** por esos sprites. Hoy los muebles son cajas isométricas
    dibujadas por código (`PiezaIso`, `mesa_atencion.gd`); el sitio donde se enchufan ya está aislado.
 3. **Los policías.** Ya están descargados: `capturas/NPC/Policias/Hombres/police_officer_portrait.glb`
    y `capturas/NPC/Policias/Mujeres/police_officer_in_uniform.glb`. Pasarlos por el renderizador y
    montarlos como hoy están los ciudadanos.
 4. **Cerrar §5 del art bible**: personajes SIN CARA vs CARA MÍNIMA. Con los sprites ya a 44 px en
    pantalla es mirar y decidir.

═══ ESTADO VERIFICADO AL CERRAR ═══
Suite 698 casos / 0 fallos / exit 0 · arranque headless limpio · árbol limpio y pusheado (a408d61).

═══ LO QUE YA FUNCIONA Y NO HAY QUE REHACER ═══
· **`tools/render_sprites.gd`** — el pipeline completo. Convierte cualquier modelo 3D con esqueleto
  en 8 direcciones × 8 fotogramas de andar + 8 de sentado, en dos tamaños.
    godot --path <proyecto> res://tools/RenderSprites.tscn
  Cambiar de modelo = cambiar la constante MODELO y PREFIJO. LEE SU CABECERA antes de tocarlo: tiene
  documentadas las cinco cuentas que costó acertar (ángulo 26,565°, cámara ortográfica, la
  orientación medida desde los pies, el balanceo sobre el eje del personaje, y el factor de escala
  común a todas las poses).
· El juego en ISOMÉTRICO entero: proyección, suelos, paredes con altura, orden por profundidad,
  clic→celda, fachada fija con puerta, rotar objetos con R, luces de techo.
· Los CIUDADANOS con sprite 3D: andan, giran a 8 direcciones y se sientan.
· Los FUNCIONARIOS con el muñeco de piezas (`src/main/muneco.gd`) — sigue válido y sirve de
  comparación. Se sustituye cuando haya sprites de policía.
· ODAC #9 cerrado (última pieza del MVP): 4 modos de reconfiguración, panel con tecla O.
· Ficha de ventanilla (clic izquierdo sobre una): quién la lleva, eficacia descompuesta, qué atiende,
  y el horario/peonada de Documentación.
· Bienestar #13: implementado y con su último hueco cerrado (descanso in situ).

═══ LO QUE NO SE TOCA ═══
El MODELO no conoce la proyección ni el arte: Flujo, Personal, Paciencia, Economía, Demanda,
Documentación, ODAC, Construcción, persistencia. LOS 698 TESTS DEBEN SEGUIR EN VERDE. Si un cambio
tuyo obliga a tocar un test de Core, párate: probablemente estás metiendo píxeles en el modelo, y eso
viola el ADR-0004 ("el visual REFLEJA el modelo, jamás al revés").

═══ PENDIENTE Y BLOQUEANTE: LAS LICENCIAS ═══
⚠️ Regla del proyecto: **ningún asset de terceros entra en `assets/` sin su fila en `CREDITS.md`.**
· Los dos policías: el usuario dice que son de Sketchfab y **CC BY**, pero FALTA el nombre del autor
  y el enlace, que es justo lo que la licencia obliga a citar. **PÍDESELO** (la línea que genera
  Sketchfab, como la de "girl" que ya está registrada).
· El paquete de oficina: **no se sabe ni la licencia**. Preguntar antes de usarlo.

═══ OTROS PENDIENTES ═══
· **Bienestar #13 sin sign-off**: guía de 7 puntos en `production/qa/evidence/bienestar-13-signoff.md`.
  Pendiente de que el usuario lo mire en la ventana y firme.
· Punto U9 del backlog: el trazado de muros "va mejor, no del todo bien" — preguntarle QUÉ falla.
· ODAC: el modo "a medida" tiene botones en la ficha de ventanilla pero no en el panel O.
· La falda del modelo "girl": es geometría, hace falta Blender u otro modelo.

═══ HERRAMIENTAS DEL JUEGO ═══
H=horario · P=personal · O=ODAC · B=construir · R=rotar objeto · F5/F9=guardar/cargar · F1=panel DEV ·
Espacio=pausa · 1/2/3=velocidad · CLIC IZQUIERDO sobre VENTANILLA=su ficha · CLIC DERECHO sobre SALA=
menú · CLIC DERECHO sobre CIUDADANO=ficha y colar. Una jornada ≈6 min reales a 1x.

═══ REGLAS FIJAS ═══
· ESPAÑOL, modo LEAN, usuario PRINCIPIANTE en gamedev (explica en llano, con analogías).
· NUNCA ofrecerle "parar por hoy" ni cortar por contexto.
· En hitos VISIBLES: avísale y ABRE LA VENTANA.
· TODO lo que deba leer va en el MENSAJE FINAL del turno.
· Commits por hito sin pedir permiso; mensajes largos con `git commit -F <archivo>`.
· Feedback de COMPORTAMIENTO: se implementa el mismo día. ESTÉTICO: a design/ux/pulido-backlog.md.
· Erratas y ampliaciones del GDD, AL MOMENTO.

═══ ENTORNO Y COMANDOS ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
· Tests (fíate SOLO del "Exit code:" de GdUnit, NO del exit del shell):
  "...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration
  --ignoreHeadlessMode
· Arranque: añade `--quit-after 300` y grepea "error|SCRIPT" (vacío = limpio).
· Ventana: nohup "...console.exe" --path /c/Users/manur/juego > /dev/null 2>&1 &   (NUNCA con pipe a tail)
· Renderizar sprites: "...console.exe" --path /c/Users/manur/juego res://tools/RenderSprites.tscn
· Catálogo: --script res://tools/build_catalogo.gd (50 recursos)

═══ GOTCHAS QUE YA HAN MORDIDO (los de arte son NUEVOS) ═══
· 🆕 **Todo PNG generado por herramienta necesita `--import` antes de que el juego lo vea.** Si no,
  `ResourceLoader.exists()` da false y el juego se cae al placeholder SIN AVISAR.
· 🆕 **Después de `--import`, comprobar `git status -- datos/`**: arranca el editor y ya reescribió un
  `.tres` de configuración una vez, tumbando un test que no tenía nada que ver.
· 🆕 **Una pose de esqueleto se define ENTERA**: todo hueso que toque alguna pose, las demás tienen
  que devolverlo a su sitio, o se heredan restos ("andan de rodillas").
· 🆕 **Nunca reconstruir por frame un contenedor con controles interactivos**: los botones se
  destruyen antes de que el clic se complete y no se puede pulsar nada.
· 🆕 **Anclar un panel a un borde con anclajes A MANO**, no con `PRESET_*_RIGHT`: ese preset ancla a
  un PUNTO y los offsets se miden desde ahí (panel de altura negativa = invisible).
· 🆕 **Los assets 3D en bruto NO van a git** (349 MB; ya en `.gitignore`). Lo que va son los sprites.
· Los autoloads (Tiempo, EventBus, Datos, SaveManager, RNGService) NO existen en un script `-s`:
  un diagnóstico así SE CUELGA. Para probar el modelo, escribe un test de GdUnit desechable.
· Para actuar sobre el mundo con el ratón usa la posición DEL EVENTO (`celda_de_punto`), NUNCA
  `get_global_mouse_position()`.
· Todo Control decorativo → MOUSE_FILTER_IGNORE; botones/CheckBox → focus_mode = FOCUS_NONE.
· Las lambdas capturan por VALOR → un contador de test debe ser Array, nunca int.
· GDScript no concatena strings adyacentes (hace falta `+`) ni admite "%.*f".
· Al insertar código con scripts de Python: el ancla debe ser EXACTA y COMPRUEBA QUE COMPILA.
· `git checkout --` NO revierte un archivo nuevo sin trackear.
· GdUnit corta la suite de un archivo tras el primer FAIL. El "ERROR Parse JSON... got 'esto'" es un
  test intencionado.

═══ MÉTODO: LO QUE MÁS VALOR HA DADO ═══
Cinco veces en la última sesión, MEDIR resolvió en un minuto lo que SUPONER no resolvía en veinte:
el funcionario invisible (`get_child_count()` = 0), el bucle de entradas (instrumentar la ventana
real), el rumbo de pantalla vs el del mundo (etiquetar las 8 direcciones y mirarlas), la pose
heredada (imprimir el flag en vivo) y los signos de cadera/rodilla (renderizar las 4 combinaciones).
**Cuando algo visual no cuadra: instrumenta, renderiza una hoja de contactos, MIRA.** Y si el usuario
repite el mismo síntoma más de dos veces, pídele una captura.

═══ PRIMER PASO ═══
Lee `production/session-state/active.md` (el cierre del 2026-08-01 está al final), verifica el estado
(suite + arranque), salúdame en llano recordándome dónde estamos, PÍDEME LA ATRIBUCIÓN DE LOS
POLICÍAS Y LA LICENCIA DE LA OFICINA, y propón el plan de la sesión de diseños.
