# Prompt de traspaso — sesión siguiente (actualizado 2026-08-08, cierre del ciclo entorno+UI+diseñador)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN. Listón: BIG PHARMA. El usuario es PRINCIPIANTE con ojo de diseñador — sus "se ve raro" aciertan SIEMPRE (este ciclo cazó: silla al revés ×2, farolas cortadas por capas, escala de coches y casas, monitor al ciudadano, CRT flotando... TODOS reales).

═══ ORGANIZACIÓN (orden del usuario — LO PRIMERO) ═══
- **FABLE 5 (tú)**: SOLO diriges, coordinas, revisas y verificas contra DISCO. Micro-ediciones permitidas (una constante, un cableado). Las capturas del juego las haces tú.
- **SONNET 5**: ejecuta todo lo normal como subagente. **OPUS**: solo lo de verdad difícil (arquitectura, bugs estructurales).
- **SUMMER**: TODO el arte. ⚠️ DOCTRINA AMPLIADA 2026-08-07 (memoria reparto-summer-arte): **PROHIBIDO diseñar elementos visuales por código** — todo con forma sale de asset (biblioteca gratis Summer, packs Kenney/KayKit CC0/CC BY ya descargados en capturas/fuentes/, o generación de pago con OK del usuario POR PIEZA). Solo se toleran rellenos planos de superficie como base. Plan Pro CONTRATADO (generación 3D ≈0,54$/pieza ≈3% cupo mes; imágenes más baratas; biblioteca y packs GRATIS).
- **EL USUARIO**: visto bueno a TODO lo visual con imagen ANTES de integrar + autoriza cada gasto.

⚠️ GESTIÓN DE AGENTES (dolor confirmado otra vez): se paran cada ~20-30 tool-uses SIN informe → reanudar con SendMessage: receta numerada + "sin narrar" + "sin releer". Verificar SIEMPRE su informe contra DISCO. Cazado este ciclo: un agente marcó "corregido" en un doc algo que NO había corregido; otro BORRÓ un archivo untracked ajeno (_check_trazado.gd, irrecuperable) → en TODO prompt: "PROHIBIDO borrar/sobrescribir archivos que no crees tú" (memoria agentes-no-borrar-preexistente). Los technical-artist/ux NO tienen MCP de Summer: las descargas de biblioteca/generaciones las haces TÚ y les dejas los GLB en capturas/fuentes/.

═══ REGLA DE ORO DEL MOTOR (pantalla gris del 07-08) ═══
UN SOLO GODOT A LA VEZ. Nunca imports/tests/sondas con el juego del usuario abierto, ni dos agentes con motor. Si la caché se corrompe (pantalla gris, .ctex ausentes): borrar los *.tmp huérfanos de .godot/imported/ (los de fuentes Kenney atascaron el importador con segfault 139) y --headless --import completo (~5 min, ~6300 ctex). SIEMPRE --import tras crear PNGs nuevos (load() sirve el .ctex cacheado — gotcha documentado en tools/render_entorno_urbano.gd). El usuario a veces CIERRA las ventanas negras de consola creyéndolas basura — son los tests; avisado, pero vigilar procesos killed.

═══ ESTADO GIT ═══
17 commits en el ciclo 06-08/08 hasta `05d590e` (modo diseñador). SIN PUSHEAR desde `700e365` — PUSH pendiente al empezar si el usuario quiere. Cabezas del ciclo: 9a5b72b rotación 4 posiciones+triángulo+impresora DNI · 855b2f6 viaje visual impresora · 61c090e nevera+lámpara · 18f882d agua unificada · 36e0cc3+ebbed1f+1adba83 los 3 fixes del cursor (¡la fórmula del zoom estaba INVERTIDA!) + ruido TramiteDoc · b8da661+098256e+05d590e entorno (base → reforma con assets → modo diseñador+capas+coches 3celdas+farolas nocturnas) · a05eec1 MEGA-LOTE catálogo 11→16 (ventanilla tier básico EN JUEGO) · 9cf1bb5+84db7de saga silla (225°+estándar lado-de-accion) · b250f2f ciudad+cámara pan/clamp.

**SIN COMMITEAR (lo primero de la sesión)**: el LOTE DE UI completo — assets/ui/kit/ (41 piezas troceadas del arte Summer aprobado "azul policía fondo blanco") + theme_comisario.tres + fuente Kenney + src/ui/kit_ui_comisario.gd + barra de construcción NUEVA por pestañas (modo_construccion.gd) + fix solape HUD↔diseñador (main.gd oculta HUD con señal activado_cambiado) + paleta diseñador con Theme y botones ≥48px + CREDITS + 2 tests nuevos SIN ejecutar. Estado: import hecho, arranque limpio verificado; FALTA: suite completa + verificación VISUAL (B=barra nueva; márgenes 9-slice del .tres son ESTIMADOS — ajustar a ojo; --disenador+F12 oculta HUD) + veredicto del usuario → COMMIT. Bordes "regulares" conocidos: hovers con halo dentado, posible defringe en iconos a 28px, icono_moneda es una insignia.

═══ LA GRAN NOVEDAD: MODO DISEÑADOR DE ENTORNO ═══
El usuario DISEÑA ÉL el entorno como un builder (lo pidió y le encanta). Lanzar: `"...console.exe" --path /c/Users/manur/juego -- --disenador` → F12 abre/cierra editor (pausa el juego, oculta HUD tras el fix) → paleta (5 casas, 2 vallas, camino, entrada, 3 árboles, seto, farola, jardinera, 3 coches, brochas césped/asfalto/acera, goma) → clic coloca, R rota, arrastre pinta → **F8 GUARDA** a user://entorno_disenado.json. CONGELADO: cuando diga "ya tenemos el entorno" → copiar ese JSON a res://datos/entorno_layout.json (EntornoExterior lo carga como entorno FIJO sustituyendo el scatter) + commit. user:// de Godot en Windows: C:\Users\manur\AppData\Roaming\Godot\app_userdata\Comisario\ (verificar nombre exacto). La GARITA también la montará él (piezas Building Kit — cuando se añadan a la paleta o aparte).

═══ COLA (por orden) ═══
1. **Verificar + commitear el lote de UI** (arriba). El usuario estaba probándolo al cerrar la sesión anterior — preguntarle su veredicto del solape y la barra ANTES de nada.
2. **CASAS A ESCALA DE PARCELA** (feedback: "muy pequeñas comparadas con coches/personas/comisaría"): re-render 2-3× (~6-8 celdas de ancho; una casa >> un coche de 3,19 celdas). El layout del usuario guarda celda+rotación → sus casas colocadas se re-escalan solas.
3. **Retoques estética entorno** (mis reparos anotados, confirmar con el usuario): vallas naranjas Kenney cantan → apagar tono · árboles poca variedad/saturados · 2 coches verdes iguales en el parking · losetas de calzada/acera aplazadas (parecían "paneles solares" mal orientadas — retomar o descartar).
4. **Sesión de diseño del usuario** → congelado del entorno (ver arriba).
5. **UI fases 2-3**: aplicar barra superior nueva + bandeja de avisos + ventana modal en el juego real (arte YA generado en assets/ui/kit/, falta cablearlo a reloj/dinero/velocidad + Personal/Horario) + pieza 6 (plantilla pantalla completa, sin generar). ⚠️ El arte de avisos EXISTE — cuando se implementen eventos/quejas NO regenerarlo (decisión usuario).
6. **Quick-spec mejora de ventanilla POR BLOQUE** (básica→media→pro, mesa+sillas juntas, "ya veremos la utilidad de cada una") — el arte de los 3 tiers YA está en assets (ventanilla_{basica,media,pro}_*, sillas espera madera/azul/comoda con vistas de acción 225°). + implementar la mecánica del spec DECIDIDO de la impresora DNI (design/quick-specs/impresora-dni-quick-spec.md: cola FIFO por máquina, por sala, obligatoria 2200€, malus enfado clamp 1.0-1.3).
7. **Viaje del papel**: el policía ATRAVIESA la mesa camino de la impresora (ruta cosmética sin obstáculos) + vuelta con PAPEL visible + gesto de entrega + ciudadano sale con el papel (pedidos del usuario, en active.md).
8. **Ventanas en fachada** (decisión SÍ del usuario: solo ventanas, fachada sigue indemolible; construccion.gd fijar_tipo_de_muro/_muros_fijos) + algunas de serie en el plano inicial nuevo.
9. **Deuda de verificación**: sillas de sala de espera con muñeco SENTADO (comparten mecanismo con la ventanilla, riesgo del mismo bug de 45°) · migración lado-de-accion (16 objetos pendientes, design/art/lado-de-accion.md) · evaluación Building Kit para PAREDES interiores (kit descargado, comparativa pared actual vs kit pendiente) · warning "transicion invalida esperando_dentro→esperando_dentro" (benigno, flujo.gd:230) · sonda 4 esquinas con falso FALLA (artefacto de borde de viewport).
10. Viejas: tinte de salas · precios definitivos (estanterías + los 5 provisionales nuevos: escritorio 350, silla_oficina 90, sillas espera 25/60/120) · plano de la comisaría inicial NUEVA con el usuario · Playtest 0 · pantalla de créditos CC BY antes de builds públicos.

═══ ENTORNO Y COMANDOS (verificados) ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Suite completa (fiarse SOLO del "Exit code:"; ~3 min; 905/905 en 05d590e): "...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode  (6007 tú; 6008+ agentes)
- Arranque check: --headless --quit-after 300 + grep errores (warnings conocidos: puesto_tie escalón · transicion esperando_dentro).
- Sondas GPU: "...console.exe" --path /c/Users/manur/juego res://tools/_diag_X.tscn (se cierran solas; PNGs al scratchpad de la sesión ACTIVA).
- Capturas de la ventana del juego: PowerShell con PrintWindow (recrear script; el CopyFromScreen captura lo que TAPA la ventana — no usar; NUNCA capturar pantalla completa: salió el navegador personal del usuario y hubo que borrarlo).
- Abrir imágenes/HTML al usuario: powershell Start-Process 'archivo' (¡cd al scratchpad ANTES, y volver — un cd dejó git fuera del repo!).
- Summer MCP: cloud OK sin app (search gratis, generate de pago con OK). Los thumbs de generación → Read para auditar ANTES de enseñar.
- Pipelines en tools/: render_props_poly (aparatos por ALTO) · render_mobiliario (muebles por ANCHO de huella) · render_entorno_urbano (entorno, coches por LONGITUD) · _render_conjunto_ventanillas (composición EN 3D — para aparatos sobre muebles, la 2D falló) · _trocear_ui_kit.py (PIL, magenta→alfa).

═══ LEYES (todas vigentes + nuevas del ciclo) ═══
1-10 de siempre (AnclajeSprite · verificación en motor con número · imagen antes del OK · una ventana · .ctex fresco · capturas el coordinador · y-sort MundoProfundo con muñecos andantes E props verticales del entorno (05d590e) · muros Sims · determinismo · puertas por hueco). NUEVAS: **11. Lado de acción** (design/art/lado-de-accion.md): la orientación de un objeto la define dónde queda su cara de USO respecto al muñeco; asientos se verifican SENTANDO al muñeco con recorte ampliado, jamás con la silla vacía; a veces hacen falta vistas a 45° (las sillas de ventanilla usan 225°). **12. Escala relativa**: mesa 2 celdas < coche 3+ celdas < casa 6-8 celdas (parcela). **13. Cero diseño por código** (ver organización). **14. En prompts de agentes**: prohibido borrar archivos ajenos + sin MCP para subagentes.

═══ REGLAS FIJAS ═══
ESPAÑOL llano con orden y detalle (MEMORY.md — leerla). NUNCA ofrecer parar. Commits por hito sin permiso (Conventional Commits, -F, Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>), verde exigido (suite + arranque — ¡las DOS! un lote se commiteó sin arranque y explotó en la ventana del usuario). Hitos visibles → foto. Traspaso al cerrar SIEMPRE (este archivo + active.md).

═══ AL EMPEZAR ═══
1. Lee production/session-state/active.md (checkpoints del 06-08/08 al final) y ESTE archivo entero.
2. git status: debe haber SOLO el lote de UI sin commitear (más untracked intencionado: sondas _diag_*, morralla vieja, packs). Pregunta el veredicto del usuario sobre la UI nueva (la estaba probando) → suite + visual + commit del lote UI.
3. Pregunta si pushear los 17 commits.
4. Saluda en llano: estado, la cola (UI → casas grandes → su sesión de diseño → congelado), y qué decisiones le esperan.

═══ ÚLTIMO MINUTO (cierre real de la sesión, 2026-08-08) ═══
- Suite del lote UI: VERDE (Exit 0). Falta SOLO el veredicto visual del usuario sobre la UI
  nueva (¿solape resuelto con F12? ¿barra de pestañas a gusto?) → entonces commit del lote UI.
- EN VUELO al cerrar: agente re-renderizando las CASAS a escala de parcela (6-8 celdas, scatter
  reducido, huella del diseñador actualizada) — si no terminó, relanzar esa tarea con el mismo
  encargo (está descrito en la cola, punto 2). Verificar contra disco lo que dejara hecho
  (assets/sprites/entorno/casa_*.png re-renderizados o no, entorno_exterior.gd tocado o no).
- git: 18 commits sin pushear (hasta e14d443 docs del traspaso). El lote UI sigue sin commitear.
- APUNTE FINAL DEL USUARIO sobre las casas: "una casa es más pequeña que una sala" — usar
  también LAS SALAS de la comisaría como vara de medir (una casa ≥ una sala típica de 4-6
  celdas; parcela 6-8 celdas va bien encaminada). Verificarlo en la composición de escala.
- CIERRE REAL: CASAS HECHAS y verificadas en motor (6/6/7/7/8 celdas por tipo, alto 2,3-3,6×
  pared, scatter 4 casas sin solape, bug de exclusión mutua corregido; casa_k algo aplanada,
  revisar a ojo). SIN commitear (va con el lote UI o aparte). ⚠️ La suite da 911/911 con
  5 FAILURES: TODAS en tests/unit/ui/kit_ui_comisario_test.gd (el test del lote UI está roto
  o el tema no carga como espera — ARREGLAR ANTES de commitear el lote UI). Capturas de escala
  en el scratchpad de la sesión vieja: escala_composicion.png / escala_barrio_general.png.
- ⚠️ CORRECCIÓN URGENTE (el usuario cazó el fallo, mi auditoría lo dejó pasar): las CASAS
  re-escaladas están DEFORMADAS — el agente usó escala NO UNIFORME (factor X del ancho +
  factor Y recortado para "cuadrar la altura") y quedan achatadas/alargadas. PROHIBIDO
  deformar (ley de módulos). REHACER: escala UNIFORME calibrada por ancho de parcela
  (6/7/8 celdas) y la altura QUE SALGA — se juzga A OJO con composición (casa+coche+muñeco+
  comisaría), no contra un número de metros; si algún tipo de casa queda desproporcionado con
  escala uniforme, se cambia el MODELO por otro tipo del kit, no se deforma. Re-verificar
  después el scatter y los tests que se adaptaron.
