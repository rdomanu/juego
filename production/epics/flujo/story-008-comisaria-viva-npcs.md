# Story 008: 🎉 LA COMISARÍA VIVE — NPCs navegando y demo integradora (HITO VISIBLE)

> **Epic**: Flujo de Personas y Colas
> **Status**: Complete
> **Layer**: Core (instanciación) + Presentation (NPCs cosméticos + HUD)
> **Type**: Visual/Feel (+UI)
> **Estimate**: M-L (~4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-25 — cerrada con el sign-off del epic Flujo (8/8)

## Context

**GDD**: `design/gdd/flow-queues.md` (FL5 desplazamiento cosmético; Player Fantasy "la comisaría respira")
**Requirement**: `TR-flow-005` (muchos NPCs navegando a la vez — NavigationAgent2D + spike)
**Governing ADRs**: ADR-0004 (primario — ⚠️ POST-CUTOFF: NavigationServer2D dedicado 4.5+;
verificar CADA llamada contra `docs/engine-reference/godot/modules/navigation.md`), ADR-0001
(secundario — lo cosmético NUNCA alimenta la lógica)
**ADR Decision Summary**: NavigationRegion2D + NavigationPolygon bakeado del layout +
NavigationAgent2D hijo de cada NPC (CharacterBody2D); avoidance OFF (Experimental en 4.6);
movimiento en `_physics_process` con `get_next_path_position` + `move_and_slide`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM-ALTO (el módulo más delicado del MVP) — **MITIGADO** por
el spike QQ-02 (150 NPCs ≈ 145 FPS, plan B AStarGrid2D innecesario)
**Engine Notes**: ⚠️ (1) NUNCA fijar `target_position` en `_ready` — tras el 1er physics frame
(`await get_tree().physics_frame`); (2) re-bake del NavigationPolygon SOLO al cambiar el layout
(construir/demoler), nunca por frame; (3) sin avoidance → `velocity` directa + `move_and_slide`
(NUNCA `velocity_computed`); (4) bake por código con
`NavigationServer2D.bake_from_source_geometry_data` (patrón validado en el slice, Escalón 1).

**Control Manifest Rules (Core/Presentation)**:
- Required: los 4 patrones de nav del manifiesto (arriba). — ADR-0004
- Forbidden: la lógica lee posición/movimiento del sprite para decidir (colas, selección, espera). — FL5
- Guardrail: **60 FPS con el volumen objetivo** — verificación de FPS en la demo (QQ-02 da margen).

---

## Acceptance Criteria

*(Historia Visual/Feel; evidencia ADVISORY con sign-off del usuario.)*

- [ ] Flujo instanciado en Main (name "Flujo", DESPUÉS de Demanda — orden del tick) y conectado:
      las fichas de `persona_generada` se admiten y nacen NPCs visibles en la entrada.
- [ ] Cada NPC (CharacterBody2D + NavigationAgent2D, placeholder de forma/color por servicio) CAMINA
      de verdad: entrada → sala de espera (a un asiento/hueco) → al ser llamado, a SU ventanilla →
      al resolverse, a la salida y despawn. El movimiento es COSMÉTICO: refleja el estado lógico con
      retardo visual, jamás lo decide.
- [ ] El polígono de navegación se bakea del layout REAL de Construcción y SOLO se re-bakea al
      construir/demoler (hook al refresco del layout).
- [ ] **HUD**: bloque de Flujo en la barra inferior ("En cola: N · Atendiendo: N" por servicio, o
      equivalente legible) — pull de getters, texto además de color.
- [ ] **Rendimiento ≥ 60 FPS** con el volumen del día pico (~36 llegadas/día en pantalla — muy por
      debajo del spike de 150) — verificado en la demo con el monitor de FPS.
- [ ] Suite completa en verde + **VENTANA + SIGN-OFF del usuario**: la comisaría que llevas
      esperando — gente entrando, sentándose en TUS bancos, atendida en TUS ventanillas por TUS
      agentes, y el **saldo SUBIENDO** en el HUD.

---

## Implementation Notes

- NPC = escena por código (patrón placeholder de Construcción): CharacterBody2D + NavigationAgent2D
  + ColorRect/Polygon2D (color por servicio: azul Doc / naranja ODAC) con `mouse_filter IGNORE`
  (gotcha registrado). Velocidad de paseo = knob de ConfigFlujo.
- El NPC OBSERVA a su PersonaFlujo: cambia de destino al cambiar el estado lógico (Esperando dentro
  → asiento libre o hueco de pie; Llamada → posicion_de(puesto) de Construcción vía
  `centro_de_celda`; Resuelta/Abandonando → entrada y `queue_free`). La atención EMPIEZA aunque el
  NPC aún camine (FL5: el viaje no descuenta trámite — cosmético puro, documentado).
- Bake: obstáculos = paredes de salas del layout (o edificio abierto en el MVP si el bake por
  outline de salas se complica — decisión al implementar: el slice validó `traversable +
  obstruction outlines`). Entrada/salida = punto fijo del edificio (CO11).
- Demo (guion de la sesión): 3× hasta las 07:55 → 1× para la apertura → VER entrar la primera
  oleada, sentarse, ser llamados, y el saldo subir con cada trámite. FPS visible (F3/monitor o
  contador en HUD dev).
- Validación previa headless + suite completa ANTES de abrir la ventana (regla del proyecto).

---

## Out of Scope

- Abandono real y caras de paciencia (Paciencia #10). · Juice/animaciones (Feedback #12). · Arte
  real (art bible). · El HUD definitivo (UI/HUD #11 con /ux-design).

---

## QA Test Cases

*Manual (Visual/Feel) — evidencia + sign-off. La lógica ya quedó BLOCKING en 001-007.*

- **Manual 1 — el ciclo entero a la vista**: Setup: ventana, 3× hasta 07:55, 1×. Verify: NPCs
  entran, van a la espera Doc, se sientan/esperan, uno va a la ventanilla al ser llamado, sale al
  terminar. Pass: el ciclo se entiende SIN explicación y coincide con el HUD.
- **Manual 2 — el saldo SUBE**: Verify: con cada trámite completado el saldo del HUD sube. Pass:
  primera vez en el proyecto que el dinero crece en pantalla.
- **Manual 3 — construcción en vivo**: con gente en pantalla, construir una 3.ª ventanilla y
  asignar... (asignación aún por API/tests — solo verificar que el re-bake no rompe a los NPCs en
  tránsito). Pass: nadie se queda atascado tras re-bakear.
- **Manual 4 — FPS**: monitor ≥60 sostenido en hora punta. Pass: sin caídas perceptibles.
- **Automatizado (humo)**: suite completa → Exit code 0; arranque headless limpio.

---

## Test Evidence

**Story Type**: Visual/Feel (ADVISORY) — requiere **sign-off del usuario**.
**Required evidence**: `production/qa/evidence/flujo-demo-[fecha].md` + PNG + sign-off explícito + FPS anotado.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (lógica completa y persistente) — DONE antes de empezar.
- Unlocks: cierre del epic Flujo → **CORE 5/5 COMPLETO** → C2-6/C2-7 y el sprint.

## Cierre (2026-07-25) — 🎉 HITO VISIBLE, sign-off del usuario

Implementada en hilo principal + subagentes Opus. **Evidencia**:
`production/qa/evidence/flujo-demo-2026-07-24.md` (checklist M1-M4 ✅ + captura + sign-off).

Flujo cableado en Main (tras Demanda — orden del tick), NPCs cosméticos con `NavigationAgent2D` sobre
una malla **bakeada del layout real** (re-bake SOLO al cambiar el layout), HUD de colas/atendiendo/FPS
y sincronización Construcción→Flujo. **FL5 respetado**: los muñecos LEEN el modelo y jamás lo mutan.

**4 rondas de feedback con la ventana abierta, todas corregidas antes del sign-off:**
1. **z_index** — gotcha NUEVO: las capas visuales que cuelgan de un nodo NO-CanvasItem son raíces de
   canvas aparte y se pintan DESPUÉS del bloque de Main → los NPCs salían debajo de las salas.
2. **"No veo quién atiende ni cómo contratar"** → policías visibles con nombre, rótulo de estado por
   puesto (CERRADO/SIN AGENTE/LIBRE/EN CAMINO/ATENDIENDO), HUD de la puerta de Doc, **ventanilla TIE
   inicial** (`tie_1` + 4º agente — sin ella los TIE esperaban PARA SIEMPRE: el "misterio de las
   22:00") y **panel de personal** (tecla P, opera en Pausa).
3. **Dos ciudadanos en el mismo asiento** (bug real, 2026-07-25): el hueco "de pie" se calculaba por
   turno sobre el rect de la sala, que **incluye las celdas de los bancos**. Fix: **una celda, una
   persona** — plazas reservadas, huecos de pie que excluyen bancos y se reparten desde un origen por
   turno, purga de plazas fantasma, y apretujamiento con desvío sub-celda solo cuando la sala está
   físicamente a tope (F3 admite ~1,2 pers./celda).
4. **El panel de personal no se leía de un vistazo**: resumen "Plantilla: N (en puesto · banquillo ·
   de baja) — Ventanillas cubiertas: X de Y" + nómina diaria + un chip por ventanilla con quién la
   cubre o VACANTE. El chip respeta el gate FL4 (titular de baja sin cobertura → gris, NO cuenta).

**Suite final: 342/342, exit 0** + arranque headless limpio. Pulido visual pendiente → UI/HUD #11 +
art bible (todo el visual actual es andamio declarado).
