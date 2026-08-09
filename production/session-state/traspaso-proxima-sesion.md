# Prompt de traspaso — sesión siguiente (actualizado 2026-08-09, sesión Fable maratón)

Copiar y pegar tal cual como primer mensaje de la sesión nueva.

---

Continúa el proyecto "Comisario" (tycoon de gestión de una comisaría del CNP; Godot 4.6 + GDScript, 2D ISOMÉTRICO; plantilla CCGS; repo rdomanu/juego, rama main). ETAPA = PRODUCCIÓN. Listón: BIG PHARMA, tono TYCOON SIMPÁTICO (Two Point Hospital). El usuario es PRINCIPIANTE con ojo de diseñador — sus "se ve raro" aciertan SIEMPRE (ayer cazó, TODOS reales: muros solapados, casas descuadradas, bancos gigantes, papel pegado a la cara, ciudadanos de espaldas, ventanillas que no rotan, barrera cortada solo en 2 de 4 vistas, bordes en sierra, y que yo estaba "mezclando código de diseño con el diseño del kit" — tenía razón).

═══ ORGANIZACIÓN (orden del usuario — LO PRIMERO) ═══
- **FABLE (tú)**: dirige, coordina, revisa y VERIFICA CONTRA DISCO. Micro-ediciones permitidas. Las capturas del juego las haces tú. Lo MUY complejo (arquitectura, bug estructural) lo puede hacer Fable directamente.
- **SONNET 5**: ejecuta lo normal como subagente. **OPUS**: solo lo de verdad difícil.
- **SUMMER**: TODO el arte generado (cero diseño visual por código; rellenos planos tolerados). /mcp lo reconecta el usuario. ~0,54$/pieza con OK del usuario.
- **EL USUARIO**: visto bueno a TODO lo visual CON IMAGEN antes de darlo por bueno + autoriza gastos.
- ⚠️ **AUDITAR TODA CAPTURA ANTES DE ENSEÑARLA** (ley del usuario 2026-08-08): "si me das una imagen del HUD tiene que ser perfecta de videojuego bueno, nada de nombres superpuestos o salidos del recuadro". Abrir la imagen, hacer zoom a cada texto y arreglar ANTES de enseñar.
- ⚠️ AGENTES SE ATASCAN cada ~25-40 tool-uses sin informe → reanudar con SendMessage. Verificar SIEMPRE su informe contra disco. Autorización de escritura EXPLÍCITA en el prompt + prohibido borrar archivos ajenos + un solo Godot a la vez + qué NO tocar.

═══ HECHO EN LA SESIÓN 2026-08-09 (16 commits, 2191608..e0a7e9b, TODO PUSHEADO) ═══
1. **Suite**: cazada la contaminación entre suites (el test del diseñador pausaba el autoload `Tiempo` y no lo restauraba → NPCs congelados en otras suites). 949→**974 tests, todos verdes**.
2. **Carreteras**: fusión total asfalto-asfalto (afeitado de extremos por color medido con PIL).
3. **HUD**: velocidad uniforme (⏸ era un emoji de color del sistema → "II"), saldo con formato de spec ("3.000 €"), banda del PNG saneada.
4. **Franja CONSTRUIR**: opción A del usuario — píldora del kit en la fila de acciones, franja gris eliminada, hueco 84→60 sincronizado.
5. **Diseñador (F12)**: paleta rehecha (anclaje real, ya no tapa la pantalla), botón "🌍 Base visible/oculta", botón "⬇ Importar entorno" (convierte el procedural en piezas editables del usuario).
6. **Alineación a la cuadrícula**: `AnclajeSprite.celdas_de_huella`/`desvio_rejilla` — huella par (casa 6, coche 2→redondeado, carretera 6) se corre media celda; impar (farola) sigue centrada.
7. **Building Kit REHECHO**: 10→21 piezas (4 puertas, 4 ventanas, 4 esquinas incl. CURVA, muro medio/bajo…). La puerta era la pieza EQUIVOCADA (`door-rotate-*` = hoja suelta; lo correcto es `wall-doorway-*` = pared con hueco). Sin retoques a mano + doble resolución.
8. **Bordes lisos**: `TAM_RENDER` 512→**2048** (supermuestreo ×4). Contorno suavizado del 42% al **99%**.
9. **Barrera**: diseño 1 del usuario, integrada en la paleta; arreglado el corte en 180/270 (los recortes de cabina estaban escritos a mano y se comían 38px).
10. **Ciudadanos**: ya no atienden de espaldas (van de PERFIL) y el papel va EN LA MANO, balanceándose con el paso y respetando capas. Bug en cascada resuelto: el cuerpo se cogía como `get_child(0)` y el papel se colaba en esa posición.
11. **Ventanillas**: giran ENTERAS con R (mostrador + silla del funcionario + sitio del ciudadano), siguiendo el frente que da el MODELO.
12. **Bancos multi-plaza**: 3 tiers (80/150/240 €), una plaza por celda, aforo por plazas. Verificado con 3 NPCs sentados a la vez. Quick-spec en `design/quick-specs/bancos-espera-multiplaza-2026-08-09.md`.

═══ COLA PENDIENTE (por orden sugerido) ═══
1. **RE-RENDER GENERAL DEL CATÁLOGO con el supermuestreo** ← lo siguiente que iba a hacer. `TAM_RENDER` ya está a 2048; falta EJECUTAR los pipelines para que todo el arte viejo tenga bordes lisos: `tools/render_entorno_urbano.gd` (⚠️ vaciar `SOLO_IDS` para que entren todas), `tools/render_mobiliario.gd` y los `_render_*` de props. Verificar tamaños con PIL antes/después: la escala NO debe cambiar, solo la nitidez.
2. **AMPLIACIÓN ESTE**: propuesta 24→32 columnas (número SIN confirmar por el usuario), zona nueva sombreada y bloqueada. Toca `construccion` (fachada/límites), `entorno_exterior`, `main`.
3. **Veredicto pendiente**: borde ONDULADO del kit de UI (¿dibujado a mano o líneas rectas?).
4. **Sesión de DISEÑO del usuario** con la paleta (ahora ya usable) → al "ya tenemos el entorno", congelar: copiar `user://entorno_disenado.json` a `res://datos/entorno_layout.json`. Después: NPCs solo por aceras + spawns donde él diga.
5. **Fase 3 UI**: ventana modal + bandeja de avisos + 5 pantallas de gestión + focus_mode teclado.
6. **Defectos conocidos, medidos y NO ocultos**:
   - Muros del kit: dientes residuales de **2px** en las uniones (el módulo tiene grosor; su silueta mezcla cara superior y frontal). Si molesta: rehacer paredes con el sistema del juego (`ParedesSalas`), que es la referencia que dio el usuario.
   - Rótulos de tarjetas TRUNCADOS en la barra de construcción ("OFICINA DE DOCUMEN…") — va contra la ley "nada fuera del recuadro".
   - Paleta del diseñador: píldora "CASA K" cortada por el borde derecho y "CARGADO:" pegado al borde.
   - Carreteras: hairline de 1px y falta CABLEAR la colocación/conexión real de calzada+acera.
7. Viejas: tinte de salas · precios definitivos · plano comisaría inicial nuevo · Playtest 0 · créditos CC BY.

═══ GOTCHAS NUEVOS DE ESTA SESIÓN (los caros — leer antes de tocar arte) ═══
- 🔑 **EL PASO ENTRE CELDAS CONTIGUAS ES 40px (MEDIO rombo), NO 80.** El rombo mide 80 de vértice a vértice, pero un paso de celda avanza la mitad. Esta sola confusión causó: muros solapados, bancos 2× gigantes y casas descuadradas. Un mueble de N celdas EN FILA mide `(N+1)×40` px de ancho de rombo.
- 🔑 **ESCALA DE FAMILIA: anclar a una pieza que YA existe en el juego**, no a cuentas teóricas. Los bancos se arreglaron anclándolos al `asiento_sofa3` (108×72 px); las carreteras, a la recta. Tres intentos teóricos fallaron antes.
- 🔑 **NO retocar el arte a posteriori.** Afeitar cantos o corregir pendientes moviendo columnas de píxeles ENTERAS destruye el suavizado del render y deja mordiscos. El usuario lo cazó: *"si en el kit ya viene bien no entiendo por qué lo editas"*. La nitidez se consigue con RESOLUCIÓN.
- 🔑 **MSAA no sirve** con el renderer en modo Compatibility de este proyecto; lo que funciona es supermuestreo (`TAM_RENDER` grande + reducción LANCZOS).
- 🔑 **Medir el suavizado sobre el PERÍMETRO, no sobre el área** — dividir por el área da porcentajes ridículos ("4%") que no significan nada. (Le di ese dato malo al usuario y hubo que rectificar.)
- **Nunca coger un hijo por índice** (`get_child(0)`): si algo reordena por capas (el papel del NPC), esa referencia apunta a otra cosa. Buscar por meta (`prefijo`, `direccion`).
- `set_pressed_no_signal` en toggles: asignar `button_pressed` re-dispara `toggled` y reentra.
- **El diseñador VETA el rect jugable 24×13** a propósito → si el arrastre "no funciona", probablemente se está arrastrando sobre el edificio.
- Las orientaciones de `Construccion` son **GRADOS** (0/90/180/270), no índices.
- Los puestos solo se construyen DENTRO de salas (CO4) — para sondas, crear sala primero.
- `Main._camara` usa `ANCHOR_MODE_FIXED_TOP_LEFT`: para centrar, restar media ventana (y el clamp pisa posiciones fuera de cobertura).
- Editar listas GDScript con `replace` de Python: comprobar que no queda `] = [` (parse error que deja Godot colgado con ventana en blanco → `taskkill`).
- `PRESET_BOTTOM_WIDE` + `position`/`size` a mano = UI que solo cuadra en una resolución. Usar contenedores que crezcan con su contenido.
- Sonda in-game: mtime y caché de importación → `touch` + `--import` tras cambiar PNGs.

═══ ENTORNO Y COMANDOS ═══
Godot: `C:\Users\manur\Godot\Godot_v4.6-stable_win64_console.exe`
- Suite (~4 min, fiarse SOLO del Exit code): `"...console.exe" --headless --path /c/Users/manur/juego -s -d --remote-debug tcp://127.0.0.1:6007 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode` (6007 tú; 6008+ agentes)
- Arranque: `--headless --quit-after 300` + grep errores (tolerados: transicion invalida, puesto_tie, JSON de un test de datos corruptos).
- Sondas GPU: `"...console.exe" --path "C:/Users/manur/juego" res://tools/_diag_X.tscn` (+ `-- --disenador` si toca la paleta). Útiles de hoy: `_diag_rejilla_piezas` (rejilla dibujada encima), `_diag_bancos`, `_diag_ventanilla_rota`, `_diag_ciudadano_papel`, `_diag_arrastre_real`.
- Juego para el usuario: `"C:\Users\manur\Godot\Godot_v4.6-stable_win64.exe" --path "C:/Users/manur/juego" -- --disenador`
- Abrir imágenes: `powershell Start-Process 'ruta_absoluta'` (SIN cd).

═══ REGLAS FIJAS ═══
ESPAÑOL llano (leer MEMORY.md ENTERA). NUNCA ofrecer parar. Commits por hito sin permiso (Conventional Commits, `-F`, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`), verde exigido (suite + arranque). Hitos visibles → foto AUDITADA antes del OK. **Push solo con OK del usuario**. Traspaso al cerrar SIEMPRE.

═══ AL EMPEZAR ═══
1. Lee este archivo ENTERO y el checkpoint final de `production/session-state/active.md`.
2. `git status`/`log`: quedó limpio y pusheado hasta **e0a7e9b** — verifica que sigue así.
3. Saluda en llano: estado, la cola de arriba, y qué veredictos esperan al usuario (columnas de la ampliación Este, borde ondulado del kit).
