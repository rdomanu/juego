# Prompt de traspaso — Sesión POST-ARQUITECTURA (marcar ADRs Accepted → `/architecture-review` → …)

> Copia todo lo de abajo (desde "===") como primer mensaje de la sesión nueva.
> Actualizado el 2026-07-22 tras completar `/create-architecture` (architecture.md v1.0) + los 4 ADRs (Proposed) + el libro de normas.

===

Continúa el proyecto **"Comisario"** (tycoon de gestión de una comisaría del CNP español; **Godot 4.6 + GDScript, 2D top-down**; plantilla CCGS; repo `rdomanu/juego`, rama `main`, trunk-based). **El diseño MVP está COMPLETO y REVISADO** (12/12 GDD `/design-review` APPROVED; `/review-all-gdds` CONCERNS sin blockers; `/gate-check` Systems Design → Technical Setup **PASS**). **La ARQUITECTURA está COMPLETA:** `docs/architecture/architecture.md` **v1.0** (TD sign-off: APPROVED WITH CONDITIONS) + **4 ADRs escritos (estado `Proposed`)** + el libro de normas `docs/registry/architecture.yaml` poblado (12 reglas). Etapa = `Technical Setup`.

## Reglas fijas de trabajo (IMPORTANTES)
- **Habla en español.** Modo de revisión: **LEAN**.
- **Los subagentes FALLAN** ("API Error: Usage credits required for 1M context") → haz TODO en el hilo principal (aplica manualmente las lentes de technical-director / lead-programmer / godot-specialist). **Internet SÍ funciona** (WebSearch/WebFetch) — úsalo para verificar dudas técnicas.
- Cuando corresponda tier **Sonnet, usa SIEMPRE Sonnet 5, NUNCA 4.6** (subagentes con `model: sonnet`, skills del tier Sonnet, overrides).
- **Contexto 1M** (Opus 4.8): no cortes por "contexto cargado".
- **Protocolo colaborativo:** Pregunta→Opciones→Decisión→Borrador→Aprobación; usa `AskUserQuestion` para aprobar; pide permiso antes de escribir.
- **⚠️ EL USUARIO ES PRINCIPIANTE en gamedev/programación.** En cada decisión técnica: (1) explícala **en lenguaje llano con analogías** (p.ej. bus de eventos = "tablón de anuncios", orden de handlers = "cierre de caja", paso fijo = "metrónomo"); (2) **verifica los puntos delicados con WebSearch** y cita las fuentes; (3) da una **recomendación clara** ("(recomendado)"); (4) usa opciones que incluyan "explícame algo antes" y "parar por hoy". **Él decide a nivel "¿tiene sentido para mi juego?"; el CÓDIGO lo llevas tú.** Tranquilízale con eso.

## Primer paso obligatorio (leer para recuperar contexto)
1. `production/session-state/active.md` (estado vivo).
2. `docs/architecture/architecture.md` (el plano maestro).
3. Los 4 ADRs: `docs/architecture/adr-0001-bus-de-eventos.md`, `adr-0002-guardado-serializacion.md`, `adr-0003-formato-catalogo.md`, `adr-0004-rejilla-navegacion-2d.md`.
4. `docs/registry/architecture.yaml` (el "libro de normas" — 12 reglas que ningún ADR/story puede contradecir).
5. `design/registry/entities.yaml` (registro de valores del juego).
6. **La biblioteca de Godot 4.6 YA está verificada** (2026-07-22) en `docs/engine-reference/godot/` (módulos: navigation, tilemap-2d, save-load, patterns, rendering, ui) — LÉELA antes de decidir APIs.

## Decisiones técnicas YA tomadas (los 4 ADRs — NO re-litigar)
1. **ADR-0001 (bus de eventos + tick + orden):** `EventBus` autoload con signals para eventos de aviso; **orden determinista** de `nuevo_dia`/`nuevo_mes` vía **registro con prioridad** (el bus NO conoce los sistemas: Paciencia 10 → Economía 20 → Personal 30 → Demanda 40); la **simulación corre en `_physics_process`** (paso fijo → determinismo + `NavigationAgent2D`); el dibujo en `_process`.
2. **ADR-0002 (guardado):** partida en **JSON + FileAccess en `user://`** (NO custom Resources: seguridad + issue ResourceSaver 4.6, verificado); patrón `save()`/`load_state()` por sistema vía **grupo `Persist`** (respeta "Foundation no llama por nombre"); **se serializa el RNG** (determinismo); `Vector2i`→`{x,y}`; cargar = arrancar en Pausa sin eventos retroactivos.
3. **ADR-0003 (formato del catálogo):** las definiciones (trámites, denuncias, puestos, salas, agentes, escenario) en **`.tres` Resources tipados** (editor visual, sin parsear — práctica recomendada verificada); **referencias por `id`, NO anidando Resources** (evita `duplicate_deep` 4.5); read-only (instancias aparte). *(El `.tres` es seguro AQUÍ porque es contenido del desarrollador, no del jugador.)* Resuelve Datos OpenQ#8.
4. **ADR-0004 (rejilla + navegación 2D):** cuadrícula = **`TileMapLayer`** (`TileMap` deprecado); caminar de NPCs = **`NavigationServer2D` + `NavigationAgent2D`** (mesh); **el avoidance de NavigationAgent2D es EXPERIMENTAL en 4.6 → desactivado/mínimo** (movimiento cosmético, Flujo FL5 → solapamiento visual leve OK); gotcha: fijar `target_position` **tras el 1er physics frame**; puestos/objetos = `PackedScene` (no tiles); **la lógica de balance NO depende de la posición del sprite** (protege el determinismo); plan B = `AStarGrid2D`.

## Qué queda (en orden) — para llegar al gate Pre-Production
1. **Marcar los 4 ADRs como `Accepted`** (ahora `Proposed`; una story que referencie un ADR `Proposed` se auto-bloquea).
2. **`/architecture-review`** — valida la cobertura ADR↔GDD y bootstrapea la matriz de trazabilidad + TR registry. **⚠️ HACER EN ESTA SESIÓN NUEVA (independiente del autor); NUNCA en la misma sesión que `/architecture-decision`.**
3. **`/create-control-manifest`** — la hoja de reglas (Required/Forbidden/Guardrails) para programar, extraída de los ADRs + el libro de normas.
4. **`/test-setup`** — scaffolding de `tests/unit/`, `tests/integration/`, runner GdUnit4 y workflow de CI.
5. **`/ux-design`** — `design/ux/interaction-patterns.md` + `design/ux/accessibility-requirements.md` (7 flags UX confluyen; ratón-first, dual-focus 4.6, daltónico).
6. **`/gate-check pre-production`** cuando 1–5 estén hechos → **Pre-Production** → **`/vertical-slice`** = **1er build jugable (AVISAR AL USUARIO — lo pidió expresamente)**. Ahí corre el **spike de rendimiento QQ-02**.

## Open Questions de arquitectura a vigilar
- **QQ-02 (Alta):** spike de rendimiento de navegación 2D (docenas de NPCs a 60 FPS) — riesgo técnico nº1 → se prueba en el vertical slice; plan B `AStarGrid2D`.
- **QQ-03 (Media):** semilla RNG (aleatoria por partida vs fija; cómo se serializa) → detalle al implementar ADR-0002.
- **QQ-04 (Baja):** ¿el bucle de simulación merece un ADR-0005 propio? → decidido: dentro de ADR-0001.
- (QQ-01 formato del catálogo → ✅ RESUELTA por ADR-0003.)

## Warnings de la revisión holística (`/review-all-gdds`) a tener presentes en implementación/playtest
- **W1:** carga cognitiva (~4-5 sistemas activos) → mitigado (Oficial/pausa/revelación progresiva); validar en playtest.
- **W2:** que la **valoración de jefes / ODAC pese de verdad** en el objetivo del MVP (si no, estrategia dominante Doc>ODAC). Decisión de balance clave al definir el objetivo del MVP.
