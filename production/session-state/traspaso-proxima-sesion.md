# Prompt de traspaso — sesión siguiente (escrito 2026-08-01, madrugada/mañana)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN.

═══ MODO DE TRABAJO (orden del usuario — ES LO PRIMERO) ═══
TÚ (Fable 5) SOLO COORDINAS Y REVISAS. El trabajo va a subagentes, y el modelo del subagente se elige POR LA DIFICULTAD DE LA TAREA:
- model: sonnet (Sonnet 5) — el caso normal: papeleo, documentación, exploración, inventarios, herramientas derivadas de otras que ya funcionan, integraciones con patrón claro, tests de una cosa.
- model: opus (Opus 5) — solo cuando es DE VERDAD difícil: arquitectura, un bug que ya resistió un intento, refactor que cruza sistemas, razonar sobre concurrencia/orden de ejecución.

Lanza EN PARALELO los que no toquen los mismos archivos. NO delegues: decisiones de diseño con el usuario, balance, el veredicto final de si algo vale, y lo que toque el corazón del juego.

⚠️ VERIFICA SIEMPRE TÚ MISMO — suite completa + arranque headless + MIRAR los PNG con Read — sin fiarte del informe de ningún subagente. Esta sesión los agentes se quedaron SIN TURNO más de DIEZ veces, casi siempre justo antes de verificar; el patrón que funcionó: mirar el disco (ls/mtimes/tamaños/Read de imágenes), reanudar con SendMessage con instrucción TELEGRÁFICA ("textos de UNA línea") y prioridades explícitas por si el turno aprieta. En el prompt de cada agente: "plan YA APROBADO, NO pidas aprobación, ejecuta" y "NO hagas commit". Los commits los haces TÚ tras verificar.

═══ ⚠️ PRIMER PASO OBLIGATORIO: EL FIX EN VUELO ═══
Al cerrar la sesión anterior quedó UN AGENTE TRABAJANDO en el fix de las ventanillas (feedback del usuario con captura): (1) orden de capas — la silla del funcionario salía POR ENCIMA de la mesa y del policía; el orden correcto es silla → policía → mesa tapando a ambos, implementado como MECANISMO del ADR-0005 (capas con nombre CAPA_FONDO/PERSONAJE/FRENTE + una función de inserción, no move_child sueltos); (2) orientación de las DOS sillas — la del funcionario mira al SUR (hacia el ciudadano), la del ciudadano al NORTE (hacia la mesa, respaldo hacia cámara); rotación elegida MIRANDO fotomontajes de Python que repliquen EL ORDEN DE CAPAS REAL del árbol, no solo offsets.

Comprueba en qué estado quedó: `git status` (si hay cambios sin commitear en mesa_atencion.gd / npcs_flujo.gd / construccion.gd, el fix llegó a medias o entero sin commit), busca composites recientes en los scratchpads, y verifica TÚ: composites con Read + suite completa + arranque. Si está bien → commit (feat(arte), mensaje largo con -F) + push + LANZA EL JUEGO EN PAUSA para el usuario. Si está a medias → agente sonnet nuevo con el ADR-0005 y este párrafo como spec.

═══ ESTADO VERIFICADO AL CERRAR ═══
Suite 698 casos / 0 fallos / Exit code 0 de GdUnit — verificada por el hilo principal en CADA pasada de la sesión · arranque headless limpio (también con `--pausa`) · pusheado hasta `955332e`.

Commits de la sesión (todos pusheados): a720398/df673f8 licencias · d98614f/e650e76 catálogos v1/v2 · 53c4933 pipeline animado · a8cd135 policías EN EL JUEGO · 001097b fix orientación policías · 43e9c4c despiece por semillas · 4fbe12b art bible §5 CERRADO · 8e21b8a/c3307e3/5a2b05f diseño mobiliario+impresora · a7369b9 mostrador+pantallas · b8bdcf5 2ª tanda muebles + --pausa · 955332e ADR-0005.

═══ LO QUE YA ESTÁ EN EL JUEGO (no rehacer) ═══
- POLICÍAS de verdad (pareja J-Toastie, CC BY 3.0): andan (animación propia muestreada), 8 direcciones BIEN orientadas (corregidas midiendo contra girl), se sientan en su ventanilla mirando al ciudadano, piel de la mujer igualada a la del hombre, género determinista por hash del nombre. El muñeco de piezas sigue como fallback (muneco.gd, NO borrar).
- MOBILIARIO del pack "Isometric office" (CC BY 4.0): mostrador OBJ_021 en todas las ventanillas (con teléfono OBJ_046 encima, monitor de espaldas al ciudadano, 0.92 de celda), pantallas dobles = equipo_informatico, papelera, dispensador, radio sobre mueblecito, sofá 3 plazas ARQ_007 = sofa_descanso (multi-celda H/V), silla de espera OBJ_023 (asientos + lado ciudadano), silla ROJA de OBJ_042 = funcionario. Desvío de comodidades GENERALIZADO en construccion.gd (diccionario id → {rotación, ancla}, fallback a caja gris).
- Arranque EN PAUSA: `godot --path <proyecto> -- --pausa` (main.gd). El usuario pide lanzar así los hitos visibles para no perderse el inicio; Espacio reanuda.

═══ LA TAREA SIGUIENTE (orden propuesto; confírmalo con el usuario) ═══
1. Rematar el fix en vuelo (ver PRIMER PASO) y que el usuario dé el OK visual en el juego.
2. ⭐ IMPLEMENTAR LA MECÁNICA DE LA IMPRESORA — el diseño está 100% CERRADO en design/gdd/impresora-documentos-tramite.md (leerlo ENTERO): comodidad nueva "impresora de documentos" (visual OBJ_008 entero, 600 €, mantenimiento 2 €/TURNO en que su sala atiende — ODAC 24h=6€/día, TIE mañana=2, con peonada=4 —, aporte 2.0); OBJETOS OBLIGATORIOS por sala (Documentación: 1 puesto + 1 impresora; ODAC: igual — validación de Construcción + trazado inicial automático la coloca DETRÁS del puesto, nunca hacia el ciudadano; saves viejos → patrón idempotente tipo fachada); VIAJE DEL PAPEL (T_AVISO=5 min antes del final del trámite el funcionario va a la impresora accesible más cercana, coge papel, vuelve, entrega; el trámite no cierra ni el ciudadano se va hasta la entrega; duración desde el MODELO por distancia_en_celdas, ADR-0004; paciencia no drena; reusar la invariante decidir_entrada para no duplicar viajes). Trámites con papel: TODAS las denuncias + EXPEDICIÓN de TIE. impresora_dni queda de confort. Es trabajo de MODELO+tests+visual: historia seria; valorar agente opus para el modelo si cruza Flujo+Personal+Construcción, sonnet para visual y datos.
3. Estanterías OBJ_007/OBJ_022 para estancias de trabajo: OBJ_022 son 2 en esquina → DESPIEZAR en 1 suelta (semillas por malla repetida, tools/render_despiece_objetos.gd) y el jugador monta la esquina con 2. Falta decidir con el usuario si son decoración o comodidad con números.
4. Resto del mapa: design/art/mapa-integracion-mobiliario.md es LA FUENTE DE VERDAD de qué va dónde (decisiones del usuario fila a fila, ideas futuras incluidas).

═══ LO QUE NO SE TOCA ═══
El MODELO no conoce la proyección ni el arte (ADR-0004): Flujo, Personal, Paciencia, Economía, Demanda, Documentación, ODAC, Construcción-modelo, persistencia. LOS 698 TESTS SIGUEN EN VERDE O NO HAY COMMIT. La mecánica de la impresora AÑADE modelo nuevo (con sus tests nuevos), no rompe el existente.

═══ REGLAS NUEVAS DE ESTA SESIÓN (ya son ley) ═══
- ADR-0005: orden de capas FIJO en contenedores isométricos (silla → personaje → mesa), como mecanismo con capas de nombre. PROHIBIDO add_child/move_child suelto en contenedor compartido (Forbidden Pattern en technical-preferences.md). Los fotomontajes de verificación replican el ORDEN DE CAPAS real, no solo alturas.
- Los composites de Python con los PNG reales (pegar capas con los offsets del juego y MIRAR con Read) son EL instrumento para calibrar composiciones ANTES de tocar el juego. Los usó el fix del policía ahogado y cazaron el bug al primer intento.
- Cambiar la huella de un objeto (1→2 celdas) es decisión de MODELO, no un arreglo visual. Los problemas de píxeles se arreglan con píxeles (escala/offsets).

═══ LICENCIAS (en regla, mantener) ═══
CREDITS.md al día: "girl" (Karma🔥, CC BY 4.0, ciudadanos) · pareja "Male/Female Officer" (J-Toastie, CC BY 3.0) EN USO — la mujer "— modificado (tono de piel)" · "Isometric office" (Companion_Cube, CC BY 4.0) EN USO, SOLO GEOMETRÍA (sus texturas incrustadas de pósters/cuadros NO se usan; no mencionar la procedencia televisiva del pack: el usuario pidió no referenciarla) · restore50 ×2 en descartados (0 huesos, medido). Regla: ningún asset sin fila ANTES de entrar en assets/; estado "En uso" al entrar. ⚠️ PENDIENTE ESTRUCTURAL: el juego NO tiene pantalla de créditos aún y CC BY exige que las atribuciones aparezcan en ella — hay que crearla antes de cualquier build público.

═══ OTROS PENDIENTES (no urgentes) ═══
- Bienestar #13 sin sign-off (production/qa/evidence/bienestar-13-signoff.md, 7 puntos) — el usuario debe mirarlo en ventana.
- U9: trazado de muros "va mejor, no del todo bien" — preguntar QUÉ falla.
- ODAC modo "a medida": botones en ficha de ventanilla pero no en panel O.
- Impresora de DNI: sin asset (el pack no trae nada que dé el pego; buscar en otra fuente CC).
- OBJ_011 (sillón 1 plaza): renderizado y en el banquillo — no hay mueble de 1 plaza en el juego.
- Ideas de futuro del usuario registradas en el mapa: OBJ_000 mostrador curvo = seguridad de la entrada (conecta con puesto_seguridad que EXISTE en datos/ desactivado); OBJ_006 escritorio en L = despacho sin atención (grupo Judicial); 9 piezas de decoración de pared; patrón "mantenimiento por turno de uso" generalizable a otras comodidades.
- tools/_diag_*.gd/tscn: diagnósticos desechables sin trackear — limpiar cuando estorben.

═══ HERRAMIENTAS DE ARTE (todas commiteadas, leer cabeceras antes de tocar) ═══
- tools/render_sprites.gd — personajes SIN animación propia (girl): posa huesos por fórmula. Las 5 cuentas caras documentadas (26.565°, ortográfica, frente medido desde los pies, balanceo sobre eje del personaje, factor de escala común).
- tools/render_sprites_animado.gd — personajes CON animaciones embebidas (policías): muestrea Armature|Walk/Idle, sentado trucado (sin rodillas: pierna entera −85° + cuerpo bajado), corrección de frente por modelo, recolor de piel, carga por GLTFDocument (SIN --import).
- tools/render_mobiliario.gd — muebles por RECETA (composición de piezas de los manifiestos, 4 rotaciones, escala calibrada contra el rombo 80×40, imprime el ANCLA de cada sprite). OJO: const anidadas con Vector3 NO son expresión constante en GDScript → static func _recetas().
- tools/render_catalogo_oficina.gd / render_catalogo_objetos.gd / render_despiece_objetos.gd — catálogos del pack: por malla (748), por objeto ensamblado (53+29 ARQ) y despiece (interpenetración estricta + SEMILLAS POR MALLA REPETIDA: si la malla grande se repite N veces hay N muebles y cada pieza suelta va a su semilla más cercana).
- tools/diagnostico_orientacion.gd — hoja girl-vs-X en 8 direcciones con flechas de rumbo; calibrar orientación de cualquier personaje nuevo en un minuto.
- Hojas para el usuario (capturas/NPC/Oficina/catalogo/, FUERA de git): index.html (por malla), index_objetos.html (ensamblados + despiece), index_integracion.html (construibles del juego ↔ candidatos del pack). Manifiestos JSON con composición y transformadas: catalogo_manifest, catalogo_objetos_manifest, catalogo_despiece_manifest + inventario_construibles.json + clasificacion_objetos.json. Abrir con: cmd //c start chrome "C:\\ruta\\index.html".

═══ ENTORNO Y COMANDOS ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Tests (fíate SOLO del "Exit code:" de GdUnit, NO del exit del shell):
"...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode
- Arranque: añade --quit-after 300 y grepea "error|SCRIPT" (vacío = limpio).
- Ventana normal: nohup "...console.exe" --path /c/Users/manur/juego > /dev/null 2>&1 & (NUNCA pipe a tail)
- Ventana EN PAUSA (hitos visibles, lo pide el usuario): añade `-- --pausa` antes de la redirección.
- Renders: godot --path <proyecto> res://tools/<Herramienta>.tscn (VENTANA, no headless: necesita GPU).

═══ GOTCHAS (los 🆕 son de esta sesión) ═══
- 🆕 Tras RE-renderizar PNGs ya importados: mirar mtime de los .ctex en .godot/imported/ — si son más viejos que el PNG, el juego enseña el sprite ANTIGUO sin avisar. Y las herramientas pueden BORRAR los .import al reescribir: recontar y re-importar.
- 🆕 grep -c cuenta LÍNEAS con match, no matches: un HTML minificado de 3 líneas con 265 <img> da "3". Contar con Python.
- 🆕 El AnimationPlayer vivo MACHACA las poses manuales del esqueleto en cada frame: stop() (ojo keep_state) o set_bone_global_pose_override antes de posar a mano.
- 🆕 Tras posar, RE-encuadrar la cámara al AABB posado: con el encuadre de la figura de pie, la figura sentada cae fuera (PNG de 123 bytes = en blanco).
- 🆕 En rigs sin rodillas, el hueso "pie" puede ser la pierna ENTERA: medir el frente con él sale girado → constante de corrección por modelo + calibrar con diagnostico_orientacion contra girl.
- 🆕 poly.pizza descarga SIN cuenta (CDN estático en el HTML de la ficha); los zips de Sketchfab NO traen license.txt: la atribución la da el usuario o la página.
- Todo PNG nuevo para el juego necesita --import; DESPUÉS `git status -- datos/` y revertir lo que el editor haya reescrito (ya tumbó un test una vez).
- Una pose de esqueleto se define ENTERA (si no, restos heredados: "andan de rodillas").
- Nunca reconstruir por frame un contenedor con controles interactivos; anclar paneles a bordes A MANO (no PRESET_*); Controls decorativos → MOUSE_FILTER_IGNORE; botones → FOCUS_NONE.
- Los assets 3D en bruto NO van a git (capturas/ ignorado); van los sprites y las herramientas.
- Autoloads no existen en scripts -s (se CUELGA): para probar modelo, test GdUnit desechable.
- Ratón sobre el mundo: posición DEL EVENTO (celda_de_punto), NUNCA get_global_mouse_position().
- Lambdas capturan por VALOR (contador de test = Array). GDScript: ni concatenación adyacente ni "%.*f". git checkout -- no revierte archivos nuevos. GdUnit corta la suite del archivo tras el primer FAIL (el "ERROR Parse JSON" es un test intencionado).

═══ MÉTODO: LO QUE MÁS VALOR DIO (otra vez) ═══
MEDIR > SUPONER, con ejemplos frescos: los policías de Sketchfab eran estatuas (skins=0 medido con Python en el chunk JSON del GLB, verificado por el hilo principal ANTES de decidir); las miniaturas contaminadas se cazaron porque LA MISMA pared verde salía en fotos de objetos distintos; las 4 pruebas de sentado idénticas = pose no aplicada (AnimationPlayer vivo); el policía "ahogado" se arregló con FOTOMONTAJES de los PNG reales iterados en Python, no en el juego. Y cuando el usuario dice "se ve raro": pedirle CAPTURA (borrar.PNG resolvió en un minuto lo que la descripción no concretaba). Si un agente informa "todo bien" pero no dice QUÉ miró: no se lo cree nadie — se mira el disco.

═══ REGLAS FIJAS ═══
- ESPAÑOL, modo LEAN, usuario PRINCIPIANTE en gamedev (explica en llano, con analogías).
- NUNCA ofrecerle "parar por hoy" ni cortar por contexto.
- En hitos VISIBLES: avísale y ABRE LA VENTANA (en PAUSA con `-- --pausa`).
- TODO lo que deba leer va en el MENSAJE FINAL del turno.
- Commits por hito sin pedir permiso; mensajes largos con git commit -F <archivo>; Conventional Commits; Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>.
- Feedback de COMPORTAMIENTO: mismo día. ESTÉTICO: design/ux/pulido-backlog.md. Erratas/ampliaciones del GDD: AL MOMENTO.
- El usuario decide diseño y balance; propuestas con números se le presentan para OK (así se cerró la impresora: propuesta 2 €/día → él la mejoró a 2 €/turno de uso).

═══ HERRAMIENTAS DEL JUEGO ═══
H=horario · P=personal · O=ODAC · B=construir · R=rotar objeto · F5/F9=guardar/cargar · F1=panel DEV (solo editor) · Espacio=pausa · 1/2/3=velocidad · CLIC IZQ en VENTANILLA=ficha · CLIC DER en SALA=menú (comodidades se colocan desde aquí) · CLIC DER en CIUDADANO=ficha y colar. Una jornada ≈6 min reales a 1x. Arranque con `-- --pausa` = congelado a las 07:30 hasta Espacio.

═══ PRIMER PASO ═══
Lee production/session-state/active.md (el cierre está al final) y ESTE archivo entero, haz el PRIMER PASO OBLIGATORIO (el fix en vuelo), verifica el estado (suite + arranque), y salúdame en llano recordándome dónde estamos y qué toca decidir.
