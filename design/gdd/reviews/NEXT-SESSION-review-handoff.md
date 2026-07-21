# Prompt de traspaso — Sesión de REVISIÓN + ARQUITECTURA (MVP "Comisario")

> Copia todo lo de abajo (desde "===") como primer mensaje de la sesión nueva.
> Guardado el 2026-07-21 tras cerrar el diseño MVP 12/12 (commit `07a008a`).

===

Continúa el proyecto **"Comisario"** (tycoon de gestión de una comisaría del CNP español; Godot 4.6 + GDScript; plantilla CCGS; repo `rdomanu/juego`, rama `main`, trunk-based). **El diseño del MVP está COMPLETO: 12/12 sistemas GDD escritos y consistentes** (commit `07a008a`). Ahora toca la **fase de REVISIÓN + ARQUITECTURA (Ruta A)**.

## Reglas fijas de trabajo (IMPORTANTES)
- **Habla en español.**
- **Modo de revisión: LEAN.**
- **Los subagentes FALLAN** con "API Error: Usage credits required for 1M context" → haz **TODO en el hilo principal** aplicando las lentes de los agentes manualmente (design-reviewer, systems-designer, game-designer, qa-lead, technical-director, etc.). No intentes delegar en subagentes.
- **Modelo:** cuando corresponda el tier Sonnet, usa **Sonnet 5**, nunca Sonnet 4.6.
- **Contexto 1M disponible** (Opus 4.8): **NO** cortes la sesión ni sugieras empezar otra por "contexto cargado".
- **Protocolo colaborativo:** Pregunta → Opciones → Decisión → Borrador → Aprobación. Pide "¿Puedo escribir en [archivo]?" antes de editar. Aprobación por sección con `AskUserQuestion` (nunca texto plano para aprobar).
- El usuario es **principiante en gamedev**, aprende haciendo.

## Primer paso obligatorio
Lee `production/session-state/active.md` (estado vivo) y `design/gdd/systems-index.md` (índice, 12/12 diseñados). El registro de verdad de valores cruzados es `design/registry/entities.yaml`. El art bible (núcleo §1–4) está en `design/art/art-bible.md`.

## Ruta A (secuencia)
1. **`/design-review [gdd]`** por GDD — **esto sí es independiente aquí** (esta sesión no escribió los GDD). Corre uno por uno.
2. **`/review-all-gdds`** — revisión holística de teoría de diseño cruzada.
3. **`/gate-check pre-production`** — ¿listos para producir?
4. **`/create-architecture`** — ADRs (bus de eventos, guardado/serialización, glow reworkeado de Godot 4.6, TileMapLayer para la rejilla).
5. Implementación (Godot) = **1er build jugable**. *(El usuario pidió que se le AVISE al llegar a la prueba jugable — el MVP completo como Subinspector, sin ascensos.)*

## Orden de revisión recomendado (por centralidad/riesgo)
**Primero, RE-revisar** (se tocaron después de su revisión previa, 2026-07-21):
- **Economía #3** — se concretó el contrato `sat` = `sat_cierre_doc` (media cerrada de la jornada anterior).
- **Tiempo #1** — calendario reescrito a **semanal** (jornada 24h = 1 semana, `jornadas_por_mes=4`, "Mes·Semana N").
- **Datos #2** — se añadió el tipo `tramite_reclamacion` (ODAC, 30 min, Normal, sin tarifa).

**Después, PRIMERA revisión** (9 pendientes), empezando por los más centrales:
`patience-satisfaction` → `flow-queues` → `odac` → `demand-generation` → `staff-agents` → `construction-layout` → `documentation` → `ui-hud` → `feedback-juice`.

## Puntos de riesgo a mirar en cada GDD (todos con "valores semilla a validar en playtest")
- **Tiempo #1** (`time-system.md`): coherencia del modelo semanal (F1/AC-T20/AC-T22), `escala_tiempo=4` provisional.
- **Datos #2** (`data-config.md`): 13 denuncias (todas `admite_cita=true`, diferido a Cita #14); `tramite_reclamacion` recién añadido; topes/aforos como referencia de dimensionado.
- **Economía #3** (`economy-budget.md`): `retorno_dgp` usa `sat_cierre_doc`; valores de préstamo/rescate seed; objetivo mensual (Open Q).
- **Flujo #4** (`flow-queues.md`): invariante R5 (capacidad ≥ demanda); atribución de `modificador_produccion` (Personal+Formación); throughput Doc 26 / ODAC 32.
- **Demanda #5** (`demand-generation.md`): mezcla de 13 tipos (Σ=1.0); `mult_nocturno_odac` (0.5, escalable); perfil estacional DG13; RNG sembrado determinista.
- **Personal #6** (`staff-agents.md`): fórmula de salario (base×prima); fatiga/turnos DIFERIDOS a #13/#15; ausencias RNG.
- **Construcción #7** (`construction-layout.md`): construcción libre estilo Theme Hospital; puestos ILIMITADOS (manda la demanda); objetos → #15.
- **Documentación #8** (`documentation.md`): slider de horario 08:00–14:30→20:00 + peonada; última admisión (motivación); División.
- **ODAC #9** (`odac.md`): prioridad (VioGén/Prioritarias); reconfiguración en caliente; `peso_prioridad 2.5`; aging DIFERIDO; carga de `reclamacion` autoinfligida (no toca R5 base).
- **Paciencia y Satisfacción #10** (`patience-satisfaction.md`) — **el más central**: `sat` por servicio con **cierre diario** → dinero del día siguiente; **hoja de reclamaciones** (contador + bucle Doc→ODAC, `prob_reclamacion 0.4`); paciencia base común + hacinamiento; `sat_inicial=50`.
- **UI/HUD #11** (`ui-hud.md`): HUD persistente + **5 tabs** (Comisaría·Funcionarios·Servicios·Valoraciones·Despacho); pantallas **desbloqueables por rango** (lo de rango superior NO se enseña); la UI solo lee+emite órdenes; layout fino → `/ux-design`.
- **Feedback y Juice #12** (`feedback-juice.md`): juice **tipo tycoon pero sobrio** (art bible §1.2, anti-caricatura); mood por estado (art bible §2); **audio mínimo**; verificar **glow 4.6**; accesibilidad (nunca solo color/sonido).

## Sistemas fuera del MVP (capturados como hooks, NO diseñar ahora)
Horarios/Peonadas #13, Cita previa #14, Comodidades de sala #15, Presión e Influencia #16, Detenidos/abogados #17, Ascensos #18, Brigadas #19, Comisarías/mapa #26, Valoración de jefes #28, Formación #29.

## Recordatorio
Godot 4.6 es posterior al conocimiento base del LLM (~4.3): **verifica APIs 4.4–4.6 vía web** antes de escribir GDScript o afirmar comportamiento del motor (ver `docs/engine-reference/godot/VERSION.md`).
