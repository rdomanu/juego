# Prompt de traspaso — sesión siguiente (actualizado 2026-08-02)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN.

═══ MODO DE TRABAJO (orden del usuario — ES LO PRIMERO) ═══
TÚ (Fable 5) SOLO COORDINAS, DIRIGES Y REVISAS. El trabajo va a subagentes, y el modelo del subagente se elige POR LA DIFICULTAD DE LA TAREA:
- model: sonnet (Sonnet 5) — el caso normal: papeleo, documentación, exploración, inventarios, herramientas derivadas de otras que ya funcionan, integraciones con patrón claro, tests de una cosa.
- model: opus (Opus 5) — solo cuando es DE VERDAD difícil: arquitectura, un bug que ya resistió un intento, refactor que cruza sistemas, razonar sobre concurrencia/orden de ejecución.

Lanza EN PARALELO los que no toquen los mismos archivos. NO delegues: decisiones de diseño con el usuario, balance, el veredicto final de si algo vale, y lo que toque el corazón del juego.

⚠️ VERIFICA SIEMPRE TÚ MISMO — suite completa + arranque headless + MIRAR los PNG/composites con Read — sin fiarte del informe de ningún subagente. Los agentes se quedan SIN TURNO constantemente, casi siempre justo antes de verificar; el patrón que funciona: mirar el disco (ls/mtimes/tamaños/Read de imágenes), reanudar con SendMessage con instrucción TELEGRÁFICA ("textos de UNA línea") y prioridades explícitas ("código > composite > suite") por si el turno aprieta; si un agente quema un turno entero solo LEYENDO, reanudarlo con la receta masticada y orden de implementar YA. En el prompt de cada agente: "plan YA APROBADO, NO pidas aprobación, ejecuta" y "NO hagas commit". Los commits los haces TÚ tras verificar (mensajes largos con git commit -F).

═══ PRIMER PASO ═══
1. Lee production/session-state/active.md (cierre al final) y ESTE archivo entero.
2. Verifica el estado: suite completa + arranque headless (comandos abajo). Al cerrar la sesión anterior TODO estaba commiteado y pusheado hasta `35a1e5e`, con 698/0 y arranque limpio — no debería haber sorpresas, pero se comprueba igual.
3. ⚠️ VEREDICTO PENDIENTE DEL USUARIO: se le dejó el juego abierto EN PAUSA con la ventanilla recién ANCLADA A LA REJILLA (cada elemento en su celda; el ciudadano por fin sentado SOBRE su silla). Pregúntale qué le pareció. Cabo suelto conocido: al anclar a celdas enteras, el policía sentado queda hacia el EXTREMO derecho del mostrador (el escritorio es visualmente ancho y él está en el centro exacto de su celda norte). Si al usuario le chirría, la solución de fondo es la que él mismo apuntó — MOSTRADOR DE 2 CELDAS — y eso es DECISIÓN DE MODELO (huella, validaciones de colocación, salas, saves): se diseña con él, no se parchea con píxeles. Podría ser lo primero de la sesión.

═══ ESTADO VERIFICADO AL CERRAR ═══
Suite 698 casos / 0 fallos / Exit code 0 de GdUnit — verificada por el hilo principal tras CADA cambio · arranque headless limpio (también con `--pausa`) · árbol limpio (solo tools/_diag_* sin trackear, desechables) · pusheado hasta `35a1e5e`.

Commits clave de las 2 últimas sesiones: a720398/df673f8 licencias · d98614f/e650e76/43e9c4c catálogos y despiece · 53c4933 pipeline animado · a8cd135 policías EN EL JUEGO · 001097b orientación policías · 4fbe12b art bible §5 CERRADO · 5a2b05f diseño impresora CERRADO · a7369b9 mostrador+pantallas · b8bdcf5 2ª tanda muebles + --pausa · 955332e ADR-0005 · f06bd5f capas de la ventanilla (mecanismo ADR-0005 en código) · 131b2b1 rotación de sillas (con asiento VACÍO) · 35a1e5e ANCLAJE A REJILLA.

═══ LO QUE YA ESTÁ EN EL JUEGO (no rehacer) ═══
- POLICÍAS (pareja J-Toastie, CC BY 3.0): andan (animación propia muestreada), 8 direcciones bien orientadas (calibradas contra girl), sentados en su ventanilla mirando al ciudadano, piel unificada, género determinista por hash del nombre. muneco.gd de piezas = fallback, NO borrar.
- MOBILIARIO del pack "Isometric office" (CC BY 4.0): mostrador OBJ_021 (con teléfono, monitor de espaldas al ciudadano), pantallas = equipo_informatico, papelera, dispensador, radio sobre mueblecito, sofá 3 plazas ARQ_007 = sofa_descanso (H/V), silla de espera OBJ_023, silla ROJA de OBJ_042 = funcionario. Desvío de comodidades generalizado (diccionario id → {rotación, ancla} en construccion.gd, fallback a caja gris).
- LA VENTANILLA, con sus tres reglas ya en código:
  · ADR-0005 (orden de capas): CAPA_FONDO=silla < CAPA_PERSONAJE < CAPA_FRENTE, vía `NPCsFlujo._insertar_en_capa` (metadato capa_iso). De pie las asignaciones se invierten (el muñeco es más alto que el mostrador). PROHIBIDO add_child/move_child suelto en contenedor compartido (Forbidden Pattern).
  · REGLA DE REJILLA (usuario 2026-08-02): todo elemento ancla al CENTRO de su celda, de 1 en 1 — `MesaAtencion.CELDA_FUNCIONARIO/CELDA_CIUDADANO` es LA única fuente de verdad (de pie, sentado y silla coinciden). Nada de ajustes de píxel a mano.
  · Rotaciones de silla elegidas con el asiento VACÍO: funcionario 180 (abre hacia el ciudadano), espera 270 (abre hacia la mesa).
- Arranque EN PAUSA: `godot --path <proyecto> -- --pausa`. El usuario SIEMPRE pide los hitos visibles así ("ábrelo en pausa cuando esté verificado"); Espacio reanuda.

═══ LA TAREA SIGUIENTE (orden propuesto; confírmalo con el usuario) ═══
1. Veredicto del usuario sobre la rejilla (ver PRIMER PASO) y, si procede, diseñar con él el mostrador de 2 celdas (modelo: huella 2, validaciones, trazado inicial, saves — con tests).
2. ⭐ IMPLEMENTAR LA MECÁNICA DE LA IMPRESORA — diseño 100% CERRADO en design/gdd/impresora-documentos-tramite.md (leerlo ENTERO): comodidad nueva "impresora de documentos" (visual OBJ_008 entero, 600 €, mantenimiento 2 €/TURNO en que su sala atiende — ODAC 24h=6€/día, TIE mañana=2, con peonada=4 —, aporte 2.0); OBJETOS OBLIGATORIOS por sala (Documentación: 1 puesto + 1 impresora; ODAC: igual — validación de Construcción; trazado inicial automático la coloca DETRÁS del puesto, nunca hacia el ciudadano; saves viejos → patrón idempotente tipo fachada); VIAJE DEL PAPEL (T_AVISO=5 min antes del final el funcionario va a la impresora accesible más cercana, coge papel, vuelve, entrega; el trámite no cierra ni el ciudadano se va hasta la entrega; duración desde el MODELO por distancia_en_celdas — ADR-0004; la paciencia no drena; reusar la invariante decidir_entrada). Trámites con papel: TODAS las denuncias + EXPEDICIÓN de TIE. impresora_dni queda de confort. Trabajo de MODELO+tests+visual: valorar OPUS para el modelo (cruza Flujo+Personal+Construcción), sonnet para visual y datos.
3. Estanterías OBJ_007/OBJ_022 para estancias de trabajo: OBJ_022 son 2 en esquina → DESPIEZAR en 1 suelta (semillas por malla repetida) y el jugador monta la esquina con 2. Decidir con el usuario si decoración o comodidad con números.
4. Resto del mapa: design/art/mapa-integracion-mobiliario.md es LA FUENTE DE VERDAD (decisiones del usuario fila a fila + reglas de rejilla/validación + ideas futuras).

═══ LO QUE NO SE TOCA ═══
El MODELO no conoce la proyección ni el arte (ADR-0004): Flujo, Personal, Paciencia, Economía, Demanda, Documentación, ODAC, Construcción-modelo, persistencia. LOS 698 TESTS SIGUEN EN VERDE O NO HAY COMMIT. La impresora y el posible mostrador de 2 celdas AÑADEN modelo (con tests nuevos), no rompen el existente.

═══ REGLAS Y LECCIONES YA FIJADAS (ley del proyecto) ═══
- ADR-0005 capas + Forbidden Pattern en technical-preferences.md.
- REGLA DE REJILLA del usuario (en el mapa de integración): celdas enteras, de 1 en 1; quien se sienta coincide con su silla.
- VALIDACIÓN VISUAL con composites de Python de los PNG reales ANTES de tocar el juego, y con tres matices que costaron un aviso del usuario cada uno: replicar el ORDEN DE CAPAS real del árbol (no solo offsets) · juzgar la dirección de un asiento con el asIENTO VACÍO (un muñeco encima tapa justo lo que hay que mirar) · juzgar alineación con la REJILLA de rombos dibujada (80×40). El guión de composites vive en scratchpads temporales: si hace falta, se reescribe en minutos.
- Cambiar la huella de un objeto es decisión de MODELO; los problemas de píxeles se arreglan con píxeles.
- "Se ve raro" del usuario → pedirle CAPTURA (Downloads/borrar.PNG, la sobreescribe cada vez).

═══ LICENCIAS (en regla, mantener) ═══
CREDITS.md al día: "girl" (Karma🔥, CC BY 4.0) · pareja J-Toastie (CC BY 3.0) EN USO, la mujer "— modificado (tono de piel)" · "Isometric office" (Companion_Cube, CC BY 4.0) EN USO, SOLO GEOMETRÍA (texturas incrustadas de pósters/fotos NO se usan; el usuario pidió no mencionar la procedencia televisiva del pack) · restore50 ×2 descartados (0 huesos, medido). Regla: fila en CREDITS ANTES de entrar en assets/; "En uso" al entrar. ⚠️ PENDIENTE ESTRUCTURAL: falta la pantalla de créditos del juego (CC BY exige que las atribuciones aparezcan en ella) — necesaria antes de cualquier build público.

═══ OTROS PENDIENTES (no urgentes) ═══
Sign-off Bienestar #13 (production/qa/evidence/bienestar-13-signoff.md) · U9 trazado de muros ("va mejor, no del todo bien" — preguntar qué falla) · ODAC "a medida" sin botones en panel O · impresora de DNI sin asset (buscar en otra fuente CC) · OBJ_011 (sillón 1 plaza) renderizado en el banquillo · ideas futuras del usuario en el mapa: OBJ_000 = seguridad de la entrada (conecta con puesto_seguridad desactivado en datos/), OBJ_006 = despacho Judicial, 9 piezas de decoración de pared, patrón "mantenimiento por turno de uso" generalizable · tools/_diag_* sin trackear, limpiar cuando estorben · falda de girl (Blender).

═══ HERRAMIENTAS DE ARTE (commiteadas; leer cabeceras antes de tocar) ═══
- tools/render_sprites.gd — personajes SIN animación propia (girl): posa huesos por fórmula (5 cuentas caras documentadas: 26.565°, ortográfica, frente medido desde los pies, balanceo sobre eje del personaje, escala común).
- tools/render_sprites_animado.gd — personajes CON animaciones embebidas (policías): muestrea Armature|Walk/Idle, sentado trucado (pierna entera −85° + cuerpo bajado), corrección de frente por modelo, recolor de piel, carga por GLTFDocument (SIN --import).
- tools/render_mobiliario.gd — muebles por RECETA de los manifiestos (4 rotaciones, escala calibrada al rombo 80×40, imprime el ANCLA). OJO: const anidadas con Vector3 no son constante válida en GDScript → static func.
- tools/render_catalogo_oficina/objetos/despiece — catálogos del pack (748 mallas / 53+29 ensamblados / despiece por interpenetración + SEMILLAS POR MALLA REPETIDA).
- tools/diagnostico_orientacion.gd — hoja girl-vs-X en 8 direcciones con flechas de rumbo.
- Hojas para el usuario (capturas/NPC/Oficina/catalogo/, FUERA de git): index.html, index_objetos.html, index_integracion.html. Manifiestos: catalogo_manifest, catalogo_objetos_manifest, catalogo_despiece_manifest, inventario_construibles.json, clasificacion_objetos.json. Abrir: cmd //c start chrome "C:\\ruta\\archivo.html".

═══ ENTORNO Y COMANDOS ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Tests (fíate SOLO del "Exit code:" de GdUnit):
"...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode
- Arranque: añade --quit-after 300 y grepea "error|SCRIPT" (vacío = limpio).
- Ventana EN PAUSA (así se entregan los hitos visibles): nohup "...console.exe" --path /c/Users/manur/juego -- --pausa > /dev/null 2>&1 &  (NUNCA pipe a tail)
- Renders: godot --path <proyecto> res://tools/<Herramienta>.tscn (VENTANA, no headless).

═══ GOTCHAS (todos han mordido de verdad) ═══
- Tras RE-renderizar PNGs ya importados: mirar mtime de los .ctex en .godot/imported/ (más viejos que el PNG = el juego enseña el sprite ANTIGUO sin avisar) y recontar .import (las herramientas los borran a veces) → --import + `git status -- datos/` + revertir lo reescrito.
- grep -c cuenta LÍNEAS, no matches (HTML minificado engaña) → contar con Python.
- El AnimationPlayer vivo machaca poses manuales cada frame → stop()/override antes de posar.
- Tras posar, RE-encuadrar la cámara al AABB posado (PNG de 123 bytes = en blanco).
- En rigs sin rodillas el hueso "pie" es la pierna entera → frente girado → constante de corrección + diagnostico_orientacion contra girl.
- poly.pizza descarga sin cuenta; los zips de Sketchfab no traen license.txt.
- Una pose de esqueleto se define ENTERA. Autoloads no existen en -s (cuelga). Ratón: posición del EVENTO. Controls decorativos → MOUSE_FILTER_IGNORE. Lambdas capturan por valor (contador = Array). GDScript: ni concatenación adyacente ni "%.*f". Nunca reconstruir por frame contenedores con controles. Anclar paneles a mano, no PRESET_*. git checkout -- no revierte archivos nuevos. GdUnit corta la suite del archivo tras el primer FAIL ("ERROR Parse JSON" es un test intencionado). Assets 3D en bruto fuera de git.

═══ MÉTODO: LO QUE MÁS VALOR DA ═══
MEDIR > SUPONER. Ejemplos reales: skins=0 medido con Python desechó dos modelos muertos; la pared verde repetida delató las miniaturas contaminadas; las 4 pruebas de sentado idénticas delataron el AnimationPlayer vivo; los composites con rejilla cazaron el desalineado antes de tocar el juego. Con el usuario: si dice "se ve raro" dos veces, CAPTURA; sus reglas ("1 puesto = 1 funcionario", "capas fijas", "todo a la cuadrícula") se blindan como mecanismo/documento, no como parche. Y a los agentes: prioridades explícitas, textos de una línea, y sus informes se creen solo después de mirar el disco.

═══ REGLAS FIJAS ═══
- ESPAÑOL, modo LEAN, usuario PRINCIPIANTE en gamedev (llano, con analogías).
- NUNCA ofrecer "parar por hoy" ni cortar por contexto.
- Hitos VISIBLES: avisar y ABRIR LA VENTANA EN PAUSA (`-- --pausa`).
- TODO lo que deba leer el usuario va en el MENSAJE FINAL del turno.
- Commits por hito sin pedir permiso; Conventional Commits; mensajes largos con -F; Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>.
- Feedback de COMPORTAMIENTO: mismo día. ESTÉTICO: design/ux/pulido-backlog.md. Erratas/ampliaciones del GDD: AL MOMENTO.
- Diseño y balance los decide el usuario; se le llevan propuestas con números para su OK (la impresora se cerró así: propuesta 2 €/día → él la mejoró a 2 €/turno de uso).

═══ HERRAMIENTAS DEL JUEGO ═══
H=horario · P=personal · O=ODAC · B=construir · R=rotar · F5/F9=guardar/cargar · F1=panel DEV (solo editor) · Espacio=pausa · 1/2/3=velocidad · CLIC IZQ en VENTANILLA=ficha · CLIC DER en SALA=menú (comodidades) · CLIC DER en CIUDADANO=ficha y colar. Jornada ≈6 min a 1x. Con `-- --pausa` arranca congelado a las 07:30 hasta Espacio.

═══ AL EMPEZAR ═══
Haz el PRIMER PASO (leer estado + verificar suite/arranque + preguntar el veredicto de la rejilla), y salúdame en llano recordándome dónde estamos y qué toca decidir.
