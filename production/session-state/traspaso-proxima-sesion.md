# Prompt de traspaso — sesión siguiente (actualizado 2026-08-05, reinicio por integración MCP de Summer Engine)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN. Listón de calidad: BIG PHARMA. El usuario es PRINCIPIANTE con ojo de diseñador — sus "se ve raro" aciertan SIEMPRE.

═══ MODO DE TRABAJO (orden del usuario — ES LO PRIMERO) ═══
TÚ (Fable 5) SOLO COORDINAS, DIRIGES Y REVISAS. Trabajo a subagentes: sonnet lo normal, opus solo lo DE VERDAD difícil (arquitectura, bug resistente, cruza-sistemas). Paralelo solo si no tocan los mismos archivos. NO delegar: decisiones de diseño con el usuario, balance, veredicto final.
⚠️ GESTIÓN DE AGENTES (dolor acumulado de 2 sesiones): queman el 1er turno LEYENDO o pidiendo permiso → en el prompt SIEMPRE: "plan YA APROBADO, ejecuta YA", "NO commit", "informe telegráfico", puerto GdUnit propio (6007 el coordinador; 6008+ los agentes), scratchpad de la sesión NUEVA. Al reanudar: receta numerada masticada + "sin releer nada". Tras 2 reanudaciones sin ejecutar → lo haces tú. SIEMPRE verificar su informe contra el DISCO (git status/diff, mtimes, Read de PNGs). "Terminado" sin archivos = NO terminado. La morralla vieja sin trackear en tools/ (silla_espera, zoom, overlay...) se ignora.

═══ NOVEDAD GORDA: SUMMER ENGINE INTEGRADO POR MCP ═══
El usuario instaló Summer Engine (IDE de IA sobre Godot; docs.summerengine.com) y se conectó por MCP a Claude Code (setup ya ejecutado: `npx summer-engine setup claude-code`; 58 tools summer_*; puerto 6550; requiere LA APP ABIERTA con el proyecto cargado). Este reinicio es justamente para cargar esa conexión.

**PRIMER PASO TRAS ARRANCAR**: ToolSearch "summer" → si aparecen las tools, prueba INOFENSIVA: summer_get_scene_tree o summer_play + summer_screenshot, y confirma al usuario que la línea directa funciona. Si no aparecen: la app de Summer está cerrada — pídele que la abra con el proyecto.

**Lo aprendido en las 2 pruebas (documentado en active.md)**:
- Prueba 1 (suelo de baldosas): BIEN — código decente respetando leyes del proyecto; adoptado (commit 38ea5b0) tras auditoría + suite.
- Prueba 2 (7 props): SOLO se atascó en bucles de planificación (3 intentos, 2 rescates); DIRIGIDO con instrucción masticada ejecutó perfecto. Conclusión pactada con el usuario: **Summer = ejecutor dirigido** (como un subagente más), NUNCA autónomo. Nuestro pipeline sigue siendo el canon para trabajo integrado en el juego.
- REGLAS SUMMER (pactadas): commit ANTES de cada sesión con su app abierta · NUNCA dos editores a la vez sobre el proyecto · generación de pago (summer_generate_*) SOLO con OK del usuario caso a caso · TODO lo suyo pasa auditoría (git diff + suite) antes de darse por bueno · vigilar su churn en project.godot/Main.tscn (mete uids/unique_id y borra comentarios — revertir con git checkout si no aporta) · su biblioteca summer_search_assets/summer_import_asset es GRATIS (cantera extra).
- Su setup instaló un PACK DE SKILLS genéricos (make-game, fps-controller, prop-model...) — casi todos orientados a 3D/otros géneros: usar SOLO si encaja; el flujo CCGS del repo manda.

═══ ESTADO GIT ═══
Commiteado y PUSHEADO hasta `b36a13c`. Cadena reciente: 38ea5b0 suelo baldosas (Summer, adoptado) · 139adde spec puertas/ventanas 2ª tanda · cb80e08 21 aspectos de ciudadano · 87186a8 zoom+modos pared · 18fee90 estantería esquina L. Suite en b36a13c: 771/771 verificada.
SIN COMMITEAR (intencionado): carpeta demo/ (diorama de la prueba 2 de Summer — se borra al integrar props) · sprites de Summer en assets/sprites/mobiliario/{taquilla,vending,archivador,fuente_agua,cafetera,impresora,television}_*.png SIN prefijo comodidad_ (decidir: borrar y re-render con nombres canónicos al integrar) · tests/*.uid sueltos · morralla vieja de tools/ · + LO QUE DEJEN LOS 2 AGENTES EN VUELO (siguiente sección).

═══ EN VUELO AL REINICIAR — 2 AGENTES (verificar su obra en DISCO antes de nada) ═══
Si el reinicio los mató a medias, INSPECCIONA qué dejaron (git status/diff) y decide terminar o relanzar con estos briefs:

**A) SUELO LIMPIO + RODAPIÉ EN PARED + REJILLA SOLO AL CONSTRUIR (Opus)** — dirección de arte del usuario (spec 3c) tras preferir la estética de la demo de Summer: (1) baldosas MUCHO más sutiles (juntas 1px contraste bajo, variación ±3-4%, suelo "limpio"), ELIMINAR el zócalo del suelo y sus 16 máscaras del atlas (construccion.gd, sistema de 38ea5b0); (2) RODAPIÉ fino (2-3px) en la BASE del muro interior (paredes_salas.gd; fachada no; huecos de puerta no; respetar modos auto/todas/bajitas); (3) rejilla de celdas SOLO con modo construcción activo (overlay en modo_construccion.gd). Tests de pintura a actualizar sin debilitar. Diag _diag_suelo_limpio con 2 capturas (juego normal limpio vs construcción con rejilla) al scratchpad. VALIDACIÓN: enseñar capturas al usuario ANTES de commit.

**B) PROPS v3 (Sonnet)** — corregir los 2 defectos que señaló el usuario: (1) fuente_agua a proporción de ORIGEN (~1,5-1,6m, la de 1,2m "se ve pequeña") → fuente_agua_v2_*; (2) cafetera/impresora/tele CON SOPORTE HORNEADO en el sprite (precedente radio+mesita; buscar mueble bajo en pack oficina o KayKit) → *_soporte_*; (3) hoja_props_v3.png (rejilla + 7 definitivos + muñeco 44px). Todo al scratchpad, NADA a assets. VALIDACIÓN: hoja al usuario, y tras su OK → integración al catálogo (comodidades .tres con precios provisionales estilo 130/80/200, arrimado "de pared" para los 4 altos, sprites canónicos comodidad_* a assets, borrar los de Summer y demo/).

═══ DECISIONES PENDIENTES DEL USUARIO (preguntar cuando toque, no de golpe) ═══
1. PUERTA: hoja a escala de pared enseñada (scratchpad sesión e2e2376e: hoja_puertas_escala.png) — ¿door_A KayKit clara / door_B oscura / ambas? El marco ARQ_004 descartable (se lee como rayita).
2. VENTANA: ARQ_009 de suelo a techo — ¿tal cual (12px, rendija) o ensanchada?
3. PROPS v3: aprobar hoja cuando exista.
4. Las 5 MEJORAS DEL GUION propuestas (sin luz verde aún): (1) excepción en CLAUDE.md "plan ya aprobado ⇒ ejecutar sin pedir permiso" [mata la causa raíz de agentes quemando turnos]; (2) .claude/docs/protocolo-agentes.md permanente; (3) captura_ventana.ps1 → tools/ + base común de diags; (4) plantilla de traspaso; (5) design/ux/decisiones-pendientes.md como archivo vivo.
5. Precios definitivos de estanterías (130/80/200 provisionales OK de palabra).

═══ COLA DESPUÉS (por orden) ═══
1. Cerrar A y B en vuelo → enseñar → commit → ventana en pausa + captura propia.
2. Integrar ARTE DE PUERTAS/VENTANAS en los tramos (tras decisión 1-2): paredes_salas dibuja el sprite de puerta/ventana elegido a escala de pared, compatible con pintura. La pantalla ARQ_022 apartada (futura sala de reuniones).
3. Integración PROPS al catálogo (tras decisión 3).
4. Deuda: tests del suelo de baldosas (38ea5b0 entró sin tests propios).
5. ⭐ IMPRESORA DE DOCUMENTOS (design/gdd/impresora-documentos-tramite.md — GDD cerrado, la mecánica estrella). Modelo+tests Opus.
6. Comisaría inicial NUEVA (plano CON el usuario) · Fase 3 plan visual (suelos/paredes con arte — el suelo limpio ES parte) · Playtest 0 · créditos CC BY antes de builds públicos · UI con Kenney (kit en capturas/fuentes/kenney_ui; OJO no trae paneles 9-slice, solo botones/sliders/iconos+2 TTF) · coche policía Kenney Car Kit (trae police.glb dedicado) · limpiar morralla tools/ y demo/.

═══ ENTORNO Y COMANDOS (verificados) ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Suite completa (fiarse SOLO del "Exit code:" de GdUnit): "...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode  [~3 min; 771/771 en b36a13c]
- Arranque check: --headless --path ... --quit-after 300 + grep -iE "error|SCRIPT" filtrando el warning conocido puesto_tie (huella 2x3 → escalón).
- Ventana pausa: taskkill ambos exes (Godot_v4.6-stable_win64_console.exe y Godot_v4.6-stable_win64.exe) → nohup "...console.exe" --path /c/Users/manur/juego -- --pausa &
- Captura propia: script PowerShell PrintWindow flag 2 (scratchpad sesión 97b28cec: captura_ventana.ps1 — MOVER A tools/ si se aprueba mejora 3). Esperar ~20s tras lanzar.
- Diag/hoja en motor: "...console.exe" --path /c/Users/manur/juego res://tools/_diag_X.tscn (ventana GPU, se cierra sola). PNGs al scratchpad de la sesión ACTIVA.
- Import tras renders: --headless --import y comprobar mtime .ctex > PNG (LEY — mordió 3 veces ya, incluida la prueba de Summer).
- Abrir imágenes al usuario: powershell Start-Process 'ruta.png' (así se le enseñan las hojas).

═══ LEYES DEL PROYECTO (TODAS siguen vigentes; en memoria persistente + aquí) ═══
1. AUTO-ANCLAJE POR LÍMITES (AnclajeSprite en src/foundation/proyeccion/): todo sprite de mobiliario se coloca midiendo sus píxeles; PROHIBIDAS anclas a mano en sprites. Personas/sillas sí van por constantes aprobadas. Arrimado "de pared": semiejes_base/eje_corto/desvio_arrimado_esquina (la esquina L tiene pose fija — base cóncava, la R no la rota).
2. VERIFICACIÓN EN MOTOR con test numérico impreso (PASA/FALLA ±3px) + captura. El ojo ilustra; el número juzga.
3. TODO tema visual (tamaño/posición/objeto nuevo o mejorado): IMAGEN previa con celdas y muñecos de 44px ANTES del OK del usuario. Nada entra al juego sin que él lo vea en foto.
4. UNA ventana del juego (taskkill antes de relanzar). 5. .ctex fresco. 6. Capturas del juego las hace el coordinador (PrintWindow), no el usuario.
7. MundoProfundo: bolsa única y-sort (muros POR TRAMO + mobiliario + contenedores); z_index solo para no-entrelazados. 8. Muros modelo Sims + modos auto/todas/bajitas (botón HUD + tecla). 9. Determinismo: nada de randf en visuales; hash por celda/nombre.
10. Puertas: el jugador las coloca (sin hueco automático); tramo = puerta; se entra POR el hueco (verificado con trayectorias). Ventanas no dejan pasar. Pintura: paredes blancas por defecto + pincel paleta 30 (paleta_pintura.gd) + MAYÚS=sala + suelo por celda.

═══ REGLAS FIJAS ═══
ESPAÑOL llano con orden y detalle (memoria persistente completa en MEMORY.md — leerla). NUNCA ofrecer parar. Commits por hito sin permiso (Conventional Commits, -F, Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>), verde exigido para commitear. Hitos visibles → ventana en pausa + captura propia. El traspaso al cerrar sesión se actualiza SIEMPRE (este archivo + active.md).

═══ AL EMPEZAR ═══
1. Lee production/session-state/active.md (cola completa) y ESTE archivo entero.
2. git status → inspecciona qué dejaron los 2 agentes en vuelo (sección EN VUELO).
3. ToolSearch "summer" → prueba inofensiva de la conexión MCP y confirma al usuario.
4. Saluda en llano: estado de la conexión Summer, qué quedó de los 2 agentes, y las decisiones que esperan (hojas de suelo limpio y props v3 si existen → enseñárselas primero).
