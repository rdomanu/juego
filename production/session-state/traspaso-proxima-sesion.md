# Prompt de traspaso — sesión siguiente (actualizado 2026-08-06, cierre del lote impresora+bugs+reparto Summer)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN. Listón de calidad: BIG PHARMA. El usuario es PRINCIPIANTE con ojo de diseñador — sus "se ve raro" aciertan SIEMPRE.

═══ ORGANIZACIÓN DEL EQUIPO (orden del usuario — ES LO PRIMERO) ═══
- **FABLE 5 (tú)**: SOLO coordinas, diriges, revisas y verificas contra DISCO. No implementas salvo micro-ediciones (cableados de una línea, arreglos de sondas).
- **SONNET 5**: ejecuta lo normal (features, bugs acotados, tests, docs) como subagente.
- **OPUS**: solo lo DE VERDAD difícil (arquitectura, bug estructural, mecánica que cruza sistemas). Hoy hizo la impresora y el cambio de capas — bien usado.
- **SUMMER ENGINE**: TODO EL DISEÑO VISUAL (decisión del usuario 2026-08-06, en memoria persistente `reparto-summer-arte`). Flujo por pieza: tú redactas el prompt de generación con la spec → pides al usuario el OK DE GASTO (cada generación es de pago) → generas por MCP (summer_generate_*; el login CLI YA está hecho: funciona SIN la app abierta — verificado con summer_search_assets) → auditas (git status, escala, fondo) → hoja con muñeco de 44 px → visto bueno del usuario → integras (recorte, FACTOR DE PRESENCIA, AnclajeSprite, nombre canónico comodidad_*, CREDITS). Su biblioteca (summer_search_assets) es GRATIS. La app de Summer solo hace falta para su editor en vivo (summer_play/screenshot/replace_text).
- **EL USUARIO**: da el visto bueno a TODO lo visual (imagen antes del OK, ley de siempre) y autoriza cada gasto de generación.

⚠️ GESTIÓN DE AGENTES (dolor acumulado de 3 sesiones): queman el 1er turno LEYENDO y se PARAN cada ~20 tool-uses → en el prompt SIEMPRE "plan YA APROBADO, ejecuta YA", "NO commit", "informe telegráfico", puerto GdUnit propio (6007 tú; 6008+ agentes, distintos si van en paralelo), scratchpad de la sesión NUEVA. Al reanudar: receta numerada + "sin releer nada" + "sin narrar". Verificar SIEMPRE su informe contra el DISCO. Agentes en paralelo: prohibirles explícitamente los archivos del otro (hoy funcionó con 3 a la vez: impresora/capas/navegación).

═══ ESCALADO Y ARTE (nuevo de hoy — design/art/plan-escalado.md es LA REFERENCIA) ═══
- Ancla: muñeco 44 px = 1,70 m ⇒ PX_POR_METRO ≈ 25,88.
- **FACTOR DE PRESENCIA = 1,25** (usuario eligió "B" con hoja A/B/C): objetos/mobiliario = metros × 25,88 × 1,25 (los muñecos cabezones hacen que la escala métrica pura se vea enana). Personajes y arquitectura SIN factor (pared 65 px = medida de su referencia; frontales bajitas a 32,5).
- GOTCHA IA: las "4 direcciones" que genera Summer en 2D son EL MISMO ángulo con variaciones — para rotaciones tira de ESPEJO desde la mejor vista (piezas simétricas) o pide a Summer el MODELO 3D y rótalo con tools/render_props_poly.gd (rotaciones reales). La 1ª pieza integrada (fotocopiadora, comodidad_impresora_documentos_*) va por espejo.
- Los muebles viejos desproporcionados (estanterías ~3,1 m, dispensador ~2,7 m, sillas/sofás — tabla en plan-escalado.md §3) se irán REHACIENDO CON SUMMER al factor nuevo.

═══ ESTADO GIT ═══
Commiteado hasta `847b73e` (SIN pushear desde `b36a13c` — hay 4 commits locales: 0014d8e docs · dab56de paleta clara+UX Sims+pared 65 · 0628e65 pintura por caras+picking quad · 847b73e impresora+navegación+capas+sprite Summer). Suite en 847b73e: **834/834 Exit 0** verificada + arranque limpio. PUSHEAR al empezar si el usuario quiere.
Untracked intencionado: morralla vieja de tools/ (se ignora) · sondas de hoy (_diag_capas_odac, _diag_impresora_visual, _diag_alturas_pared, _diag_ux_pintura, _hoja_*_impresora*, _render/_componer_impresora_doc — desechables, borrar cuando se quiera) · sprites de Summer sin prefijo en assets/sprites/mobiliario ({taquilla,vending,archivador,fuente_agua,cafetera,impresora,television}_*.png — los 7 props ANTIGUOS, pendiente decidir integración/borrado) · demo/ (diorama viejo, borrable) · _check_trazado.gd (raíz; lo usa de referencia el trazado — decidir si va a tools/) · packs kaykit/kenney en capturas/fuentes.

═══ LO HECHO HOY (2026-08-06 — leer active.md para el detalle) ═══
1. **Paleta clara de la demo de Summer aplicada** (suelo crema, paredes azul suave por defecto, suelo base crema) — vía summer_replace_text (MCP).
2. **Pared a 65 px** = proporción MEDIDA de la referencia del usuario (demo/captura_demo_props.png: pared/muñeco = 1,48×).
3. **Fachada pintable** (sigue indestructible) + **MAYÚS pinta todo el edificio** (paredes y suelos) + **UX tipo Sims**: selector de arista a tramo completo, preview fantasma del MAYÚS con el color del pincel, velo de zonas solo en construcción, acabado del suelo baldosa/liso por celda persistente.
4. **Pintura por CARA de muro** (MAYÚS pinta solo el interior de la sala; el clic pinta la cara del lado apuntado; migración de saves) + **picking por quad dibujado** (bug real: con pared alta se seleccionaba la arista de 2-3 filas más al norte).
5. **⭐ MECÁNICA DE LA IMPRESORA COMPLETA** (Opus): src/core/impresora/, viaje del papel solapado, 2 €/turno de uso, requisitos por sala (comodidades_obligatorias/puestos_minimos), colocación automática detrás del puesto, salas nuevas la compran (600 €). 38 tests.
6. **Bug navegación de raíz**: Construccion.version_layout invalida rutas cacheadas (atravesaban muros recién puestos). Regresión 5 casos.
7. **Bug capas de raíz** (Opus, estructural): muñecos andantes EN la bolsa y-sort (muere "gente siempre encima"); rótulos/barras/🚫/☕ a Z_ROTULO_FLOTANTE. La silla que asoma el respaldo por el murete NO es bug (aceptado por el usuario).
8. **1ª pieza del reparto Summer**: fotocopiadora generada por Summer, integrada a 39 px con espejos, cableada, en CREDITS.

═══ COLA (por orden) ═══
1. **Enganches visuales de la impresora** (los dejó listos el Opus, sin cablear): muñeco del funcionario que va y vuelve (npcs_flujo; API fase_de/impresora_de/restante_de — patrón sondeo por tick como el café) · ficha de ventanilla "🖨 a por el documento" (texto_ventanilla(), patrón del "☕ DESCANSO" en mesa_atencion.gd) · demolición de impresora desde la UI (impresora_demolida() existe sin llamar) · tools/build_config_impresora.gd para datos/config/impresora.tres (hoy caen defaults: aviso 5 min, recogida 1 min, 0,375 celdas/min).
2. **Playtest del usuario del lote entero** (pintura por caras + MAYÚS + impresora en juego real) — ventana en pausa + captura; puede salir lista de "se ve raro".
3. **Producción de assets con Summer** (flujo nuevo, por prioridad del inventario): impresora de DNI (spec: 1,50 m, ancha, AZUL, 1 celda, panel de cuadrícula; .tres YA existe a 2.200 €) · mesa de trabajo (0,75 m) · re-render fuente de agua 1,60 m · lámparas/nevera/máquina café (hoy cajas de código) · decidir taquilla+archivador (arte sin objeto) y duplicado dispensador vs fuente_agua · rehacer los REVISAR del plan de escalado.
4. Decisiones visuales pendientes del usuario (viejas): tinte de las salas (¿mantener o todo claro con el velo?) · hoja props v3 (enseñada sin veredicto) · puerta A/B · ventana tal cual/ensanchada · precios definitivos estanterías.
5. Deuda: tests del suelo de baldosas (38ea5b0) · sondas desechables de tools/ (limpiar) · pantalla de créditos CC BY antes de builds públicos · plano de la comisaría inicial NUEVA con el usuario · Playtest 0 · UI con Kenney.

═══ ENTORNO Y COMANDOS (verificados hoy) ═══
Godot: C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe
- Suite completa (fiarse SOLO del "Exit code:" de GdUnit; ~3,5 min; 834/834 en 847b73e): "...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode
- Arranque check: --headless --path ... --quit-after 300 + grep -iE "error|SCRIPT" (warning conocido: puesto_tie huella 2x3 → escalón).
- Diag/hoja en motor: "...console.exe" --path /c/Users/manur/juego res://tools/_diag_X.tscn (ventana GPU, se cierra sola; PNGs al scratchpad de la sesión ACTIVA).
- Import tras renders: --headless --import y comprobar mtime .ctex > PNG (LEY).
- Abrir imágenes al usuario: powershell Start-Process 'ruta.png'.
- Summer MCP: cloud (search/generate/check_job) funciona SIN la app (login CLI hecho); editor en vivo (play/screenshot/replace_text/scene_tree) EXIGE la app abierta con el proyecto. summer_replace_text multilinea FALLA en archivos CRLF (main.gd lo es) → old_text de UNA línea. Reglas pactadas: commit antes de sesión con su app · nunca dos editores · generación de pago SOLO con OK del usuario POR PIEZA · todo lo suyo se audita.
- Sondas que monten ModoConstruccion: set_process(false) o el _process pisa el estado forzado (documentado en _diag_ux_pintura.gd).

═══ LEYES DEL PROYECTO (TODAS vigentes) ═══
1. AUTO-ANCLAJE POR LÍMITES (AnclajeSprite): sprites de mobiliario se colocan midiendo sus píxeles; PROHIBIDAS anclas a mano. 2. VERIFICACIÓN EN MOTOR con número impreso (PASA/FALLA ±3px) + captura. 3. TODO tema visual: IMAGEN con celdas y muñeco de 44 px ANTES del OK del usuario. 4. UNA ventana del juego. 5. .ctex fresco. 6. Capturas del juego las hace el coordinador. 7. MundoProfundo: bolsa única y-sort — muros por tramo + mobiliario + contenedores + DESDE HOY los muñecos andantes; info flotante (rótulos/barras/🚫/☕) en Z_ROTULO_FLOTANTE 6; escalera documentada en npcs_flujo.gd. 8. Muros modelo Sims + modos auto/todas/bajitas. 9. Determinismo: nada de randf en visuales; hash por celda/nombre. 10. Puertas: el jugador las coloca; se entra POR el hueco. Pintura: POR CARA de muro (azul suave por defecto) + pincel paleta 30 + MAYÚS=sala (caras interiores) / edificio + suelo por celda con acabado baldosa/liso.

═══ REGLAS FIJAS ═══
ESPAÑOL llano con orden y detalle (memoria persistente en MEMORY.md — leerla). NUNCA ofrecer parar. Commits por hito sin permiso (Conventional Commits, -F, Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>), verde exigido. Hitos visibles → foto al usuario. El traspaso al cerrar se actualiza SIEMPRE (este archivo + active.md).

═══ AL EMPEZAR ═══
1. Lee production/session-state/active.md (cierre 2026-08-06 al final) y ESTE archivo entero.
2. git status (debe estar limpio de tracked salvo lo untracked intencionado listado arriba) — pregunta al usuario si pushear los 4 commits locales.
3. Saluda en llano: estado, la cola (enganches visuales de la impresora primero), y las decisiones que le esperan.
