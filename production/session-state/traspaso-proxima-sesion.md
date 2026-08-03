# Prompt de traspaso — sesión siguiente (actualizado 2026-08-03, cierre por contexto)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN. **Listón de calidad elegido por el usuario: BIG PHARMA** (tycoon iso hecho por 1 persona — "tiene jugabilidad, es bonito y diseño bien hecho").

═══ MODO DE TRABAJO (orden del usuario — ES LO PRIMERO) ═══
TÚ (Fable 5) SOLO COORDINAS, DIRIGES Y REVISAS. El trabajo va a subagentes por dificultad:
- model: sonnet (Sonnet 5) — caso normal: papeleo, docs, exploración, herramientas derivadas de otras que funcionan, integraciones con patrón claro, renders con receta, tests de una cosa.
- model: opus (Opus 5) — solo DE VERDAD difícil: arquitectura, bug que ya resistió un intento, refactor cruza-sistemas, razonar sobre orden de dibujo/concurrencia.
Paralelo solo si no tocan los mismos archivos. NO delegar: decisiones de diseño con el usuario, balance, el veredicto final, el corazón del juego.

⚠️ GESTIÓN DE AGENTES (afinada a base de dolor esta sesión):
- Se quedan SIN TURNO constantemente; MUCHOS queman el primer turno entero SOLO LEYENDO. En el prompt SIEMPRE: "plan YA APROBADO, NO pidas aprobación, ejecuta YA", "NO commit", prioridades explícitas, "texto final telegráfico".
- Al reanudar (SendMessage): receta masticada de pasos numerados + "sin releer nada". Si tras 2 reanudaciones no ejecuta, LO HACES TÚ (los remates de 1-5 líneas, anclas, imports y montajes los hizo el coordinador más rápido que otra vuelta de agente).
- SIEMPRE verificar su informe contra el DISCO (git status/diff, mtimes, Read de PNGs). "Terminado" sin archivos nuevos = no terminado. Informes con ancla "(0.5, ...)" = centro de encuadre = MAL (ver ley del auto-anclaje).

═══ PRIMER PASO DE LA SESIÓN ═══
1. Lee production/session-state/active.md y ESTE archivo entero.
2. `git status` — hay TRABAJO EN VUELO SIN COMMITEAR de 3 agentes que se pausaron por contexto (detalle en "EN VUELO"). NO lo pises: primero inspecciona qué dejó cada uno (diffs por archivo) y decide si se termina o se rehace.
3. Suite completa + arranque headless para saber el estado real del árbol mixto (puede NO estar verde con el WIP — no pasa nada, se documenta y se termina el WIP; verde exigido solo para commitear).
4. Saluda al usuario en llano: dónde estamos (3 tareas en vuelo + cola) y qué toca.

═══ ESTADO AL CERRAR ═══
- Commiteado y PUSHEADO hasta `041284c`. En ese commit: suite **713/713 Exit 0** verificada por el coordinador + arranque headless limpio (único warning esperado: puesto_tie del trazado inicial en escalón de huella).
- SIN COMMITEAR (WIP de los 3 agentes en vuelo + una reversión del coordinador):
  · src/main/mesa_atencion.gd — reversión DESVIO_CENTRADO_MESA_LARGO a Vector2.ZERO (el 0,38 NW fue un error decidido a ojo) + posibles inicios del auto-anclaje.
  · src/main/paredes_salas.gd + src/main/modo_construccion.gd — agente de PUERTAS (función compartida de dibujo por tipo + flag de jamba, a medio).
  · src/main/npc_ciudadano.gd + src/main/npcs_flujo.gd + src/main/icono_prohibido.gd (NUEVO) — agente de ACCESOS (señal 🚫 creada, teletransporte a medio matar, faltaba diag+test).
  · tools/_diag_oclusion_murete.gd — agente del test de esquina (ampliación del volcado, a medio).
  · Sin trackear inofensivo: tools/_diag_* varios, _check_trazado.gd (sonda de un agente, borrable), tools/_calibracion_cubo.png.

═══ LA SESIÓN DE HOY EN 60 SEGUNDOS (para entender el porqué de todo) ═══
El usuario estuvo a punto de DEJAR EL PROYECTO ("las mesas son enormes… no damos una"). Se respondió con: investigación profunda (2 docs con fuentes: pipeline visual de tycoons + cómo hacer un tycoon; síntesis con veredicto SÍ-SE-PUEDE en design/art/plan-calidad-visual.md y design/investigacion/sintesis-como-hacer-un-tycoon.md) → plan de 5 fases con listón Big Pharma → y una tarde entera de ciclos feedback-arreglo con él mirando el juego. La ventanilla quedó FIRMADA como escena patrón… y luego el mostrador volvió a descuadrarse de su huella, sobrevivió a DOS intentos de arreglo a ojo, y el usuario dio la clave final (ver LEY Nº1). Sus palabras exactas al borde del cierre: "llevamos horas y es algo sumamente sencillo: un objeto no puede salir de sus celdas — sabes los límites del objeto y los límites de las celdas".

═══ LAS LEYES NUEVAS DE ESTA SESIÓN (grabadas también en memoria persistente) ═══
1. **AUTO-ANCLAJE POR LÍMITES (la clave del usuario, ORDEN DIRECTA)**: la colocación de TODO sprite de mobiliario se CALCULA de sus límites medidos — el juego escanea una vez los píxeles opacos del sprite (cachea por textura), localiza la esquina sur de su base y la aterriza EXACTA en la esquina sur de su huella lógica. PROHIBIDA la cadena de constantes a mano (ANCLA_FRACCION_* + delta + desvíos): se desfasaba con cada re-render y causó el bucle de horas. Las posiciones de PERSONAS/SILLAS sí siguen en constantes (composición aprobada).
2. **VERIFICACIÓN EN MOTOR, no en montajes**: los fotomontajes de Python DIVERGIERON del árbol real dos veces. Toda verificación visual va en escenas tools/_diag_*.gd con el CÓDIGO REAL del juego + captura PNG + TEST NUMÉRICO impreso por consola (esquina sur base vs esquina sur huella, PASA/FALLA ±3 px). El ojo solo ilustra; el número juzga.
3. **Capturas del juego**: el coordinador captura la ventana él mismo (PowerShell PrintWindow con flag 2 — funciona sin traer la ventana al frente; procesos 'Godot_v4.6-stable_win64'). Los pantallazos del usuario a Downloads/borrar*.PNG fallan en silencio a menudo — COMPROBAR SIEMPRE el mtime antes de analizar.
4. **UNA sola ventana del juego**: taskkill de ambos exes ANTES de relanzar (hubo 2 instancias a la vez y el usuario miraba la vieja — crisis entera por eso).
5. **.ctex FRESCO**: tras CUALQUIER render, --import y comprobar mtime .ctex > PNG en el acto (mordió otra vez con el sofá).
6. **Hojas para el usuario**: anclas derivadas EN el propio script desde el PNG (nunca constantes ni fracciones impresas por herramientas) + test de esquina estampado; ajustes de tamaño SIEMPRE con foto antes/después JUNTO A LOS MUÑECOS de 44 px y CON LAS CELDAS DIBUJADAS (lo pidió explícito).
7. **MundoProfundo** (implementado, commit aa050d9): bolsa única de y-sort donde muros POR TRAMO + mobiliario + contenedores de ventanilla compiten por Y de base. z_index solo para lo que no se entrelaza: suelo −2/−1, rótulos 1-2, gente 2, luces 3. Dato de motor verificado: y-sort anidado se funde en un solo pool; z_index manda sobre y-sort; a igual z gana orden de árbol. ADR-0005 (capas del puesto) sigue vigente DENTRO del contenedor.
8. **Muros modelo Sims**: traseras (N/O) enteras; frontales (S/E) bajitas por encima del mobiliario; un muro divisorio entre dos salas se decide por TRAMO en la bolsa (ya no por clasificación global).

═══ EN VUELO — LAS 3 TAREAS PAUSADAS (retomarlas con agentes nuevos, brief completo aquí) ═══

**A) AUTO-ANCLAJE POR LÍMITES + mesa fuera de su huella (OPUS — es LA prioridad, el usuario espera esto)**
Bug vivo: el mostrador de 2 celdas se dibuja ~media celda a la IZQUIERDA de su huella (celda derecha con hueco — palabras del usuario). Dos arreglos a ojo fallaron; DESVIO_CENTRADO_MESA_LARGO ya revertido a ZERO. El agente anterior había empezado: ampliar tools/_diag_oclusion_murete.gd con el test de esquina numérico (volcado consola: esquina sur huella esperada vs esquina sur base real del sprite, delta px, PASA/FALLA ±3). ENCARGO COMPLETO: implementar el auto-anclaje por límites (LEY Nº1) en la capa visual (mesa_atencion.gd construir() para ambos mostradores + desvío de comodidades en construccion.gd + sofá), borrar la cadena de anclas a mano de los SPRITES, validar CADA pieza con el test numérico del diag, capturas de ventanilla+sofá+comodidades con rejilla, headless + integración. OJO: DESVIO_CENTRADO_MESA (profundidad, 0,28 norte) re-evaluarlo tras el auto-anclaje (puede sobrar o re-expresarse documentado). Sospecha pendiente de confirmar con el instrumento: el corrido de "media celda" puede venir de semántica centro-vs-esquina en el punto (sx) de la fila inferior del PNG.

**B) PUERTAS: colocación libre + puertas fantasma (OPUS)**
Bugs del usuario jugando: (a) la puerta solo se deja colocar en UNA zona blanca de la pared; (b) clics "rechazados" en otros tramos SE REGISTRAN EN SILENCIO y materializan puertas después (pista clave del usuario). El agente anterior dejó a medio en paredes_salas.gd + modo_construccion.gd: "función compartida de dibujo por tipo + flag de jamba". ENCARGO: puerta colocable en cualquier tramo válido (criterio documentado), clic inválido NO registra nada y da feedback (resaltado rojo con lo existente), morir el estado fantasma; verificación en motor: _diag_puertas con 3 puertas por el MISMO camino del clic + clic inválido con volcado antes/después idéntico; test de regresión antifantasma en tests/integration/construccion/; headless + integración.

**C) ACCESOS: sin saltos + señal 🚫 (SONNET)**
Diseño del usuario: si no hay camino (sala amurallada sin puerta), NADIE se teletransporta (hoy hay un fallback que planta al muñeco en el destino); el bloqueado espera QUIETO con señal de prohibido sobre la cabeza (código, estilo etiquetas; re-evaluar camino cada pocos segundos; desaparece al desbloquear); la PACIENCIA sigue corriendo (no tocar Paciencia — el abandono natural es la consecuencia). El agente dejó: src/main/icono_prohibido.gd CREADO, npc_ciudadano/npcs_flujo a medio (iba por MAX_REINTENTOS_CAMINO), faltaban _diag_bloqueo (2 capturas: bloqueado fuera con señal → abre paso → entra sin señal), test de regresión (sin camino ⇒ posición no cambia), headless + integración. Gotcha: el 1er physics frame de navegación miente (docs/engine-reference/godot/modules/navigation.md).

═══ COLA DESPUÉS (por orden) ═══
1. Cerrar el ciclo en vuelo → suite completa → COMMIT (mensajes largos con -F, Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>) → ventana única en pausa + captura propia → aviso al usuario.
2. **Comisaría inicial NUEVA** (decisión del usuario, pendiente desde ayer): plano CON él (salas para puestos 2×3 + impresora obligatoria en Documentación y ODAC + sala de descanso + 2 salas de espera). Le llevas el plano dibujado sobre rejilla. Esto además elimina el escalón de puesto_tie.
3. ⭐ **IMPRESORA DE DOCUMENTOS** (diseño 100% cerrado en design/gdd/impresora-documentos-tramite.md — leerlo entero): la mecánica estrella pendiente (comodidad 600 €, 2 €/turno de uso, obligatoria por sala, viaje del papel con T_AVISO). Modelo+tests con Opus, visual con el auto-anclaje ya de serie.
4. Fase 2 del plan visual (design/art/plan-calidad-visual.md): la "ventanilla perfecta" quedó FIRMADA por el usuario — tras el auto-anclaje, congelar esa escena como hero asset. Luego Fase 3 (suelos/paredes con arte + comisaría nueva vestida) → Playtest 0 (persona ajena — el paso más señalado por la investigación).
5. Pendientes menores: pantalla de créditos (obligación CC BY antes de builds públicos) · iconos de trámite · 2º modelo de ciudadano · U9 resto · sillas y pantallas "se juzgan en escena" (kit v2) · OBJ_000 mostrador curvo reservado para seguridad de la entrada · limpiar tools/_diag_* y _check_trazado.gd cuando estorben.

═══ DOCUMENTOS CLAVE NUEVOS DE HOY ═══
- design/art/plan-calidad-visual.md — veredicto + plan 5 fases (listón Big Pharma). Anexos en design/art/investigacion/.
- design/investigacion/sintesis-como-hacer-un-tycoon.md — 12 mandamientos del género con semáforo de Comisario (2 ROJOS: contrapeso de ODAC pendiente de decisión del usuario; generador de caos en roadmap). Anexos al lado.
- design/ux/referencia-menus-construccion.md — patrones de UI de las capturas Two Point del usuario (para cuando toque UI).
- docs/architecture/borrador-orden-profundidad-rotaciones.md — su Fase 1 YA IMPLEMENTADA (MundoProfundo); el resto (rotaciones de ventanilla) sigue pendiente de diseño con el usuario.

═══ ENTORNO Y COMANDOS (verificados hoy) ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Suite (fiarse SOLO de "Exit code:" de GdUnit; la suite del archivo se corta tras el 1er FAIL):
"...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode
- Arranque check: --headless --path ... --quit-after 300 + grep -iE "error|SCRIPT" (filtrar el warning conocido de puesto_tie).
- Ventana pausa: taskkill ambos exes → nohup "...console.exe" --path /c/Users/manur/juego -- --pausa > /dev/null 2>&1 &
- Captura propia: PowerShell PrintWindow flag 2 sobre el proceso 'Godot_v4.6-stable_win64' (snippet en el historial; GetClientRect + Bitmap + PrintWindow(h, dc, 2)). Esperar ~15-20 s tras lanzar para saltarse el splash.
- Render de una pieza: patrón tools/_reescalar_dispensador.gd / _reescalar_sofa.gd (heredan render_mobiliario.gd, cámara bit-idéntica, guardan solo su pieza). Escenas .tscn de 5 líneas al lado.
- Diag en motor: "...console.exe" --path /c/Users/manur/juego res://tools/_diag_oclusion_murete.tscn (ventana GPU; escribe PNGs al scratchpad de la sesión).

═══ GOTCHAS VIVOS (además de los históricos del traspaso anterior, que siguen valiendo) ═══
- Los muebles del pack a ESCALA REAL no se estiran a N celdas: se COMPONEN módulos a escala de personaje (mostrador = 1 mesa estirada SOLO a lo largo con accesorios sin deformar; el de 2 módulos tenía costura y lo rechazó el usuario).
- Sofá: superficie=2 (usuario), 3 cojines; la receta perdió un respaldo por las SEMILLAS de mallas repetidas (arreglado — vigilar en futuros despieces).
- El "ancla" que imprime render_mobiliario es el CENTRO DEL ENCUADRE, NO sirve (fue causa de media docena de desalineados). Con el auto-anclaje esto muere.
- Los NPC sit sprites: oficial sentado se ALZA +25 px (ALZADO_SENTADO_FUNCIONARIO — cabeza a la altura del monitor, elegido por el usuario entre −25/−33).
- Arrimes de ventanilla: la cuenta vive en mesa_atencion.gd (fondo de silla medido; ciudadano con RETROCESO 0,25 pedido por el usuario). El marco de referencia de los arrimes ya mordió una vez (se mide desde la celda de la PERSONA; en local del contenedor es 1−arrime).
- production/session-state/active.md está TRACKEADO (pese a lo que diga directory-structure).

═══ REGLAS FIJAS (sin cambios) ═══
ESPAÑOL, llano, usuario PRINCIPIANTE (aprende haciendo y tiene OJO de diseñador — sus "se ve raro" aciertan SIEMPRE; la clave del auto-anclaje fue suya). NUNCA ofrecer parar. Hitos visibles → ventana en pausa + AHORA TAMBIÉN captura propia de verificación. TODO lo que deba leer va en el MENSAJE FINAL del turno. Commits por hito sin permiso, Conventional Commits, -F. Diseño/balance los decide él con propuestas en imagen (A/B/C con muñecos y celdas). Feedback comportamiento mismo día; estético a design/ux/pulido-backlog.md (OJO: A1/A2/A4 de ese backlog están desfasados). Sus reglas se blindan como mecanismo, no como parche.

═══ AL EMPEZAR ═══
Haz el PRIMER PASO y saluda en llano: dónde estamos (la clave del auto-anclaje que él mismo dio, las 3 tareas en vuelo, la cola) y qué toca: rematar el auto-anclaje y enseñarle la mesa POR FIN clavada en sus celdas, con el test numérico en verde.
