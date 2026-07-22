# Architecture Traceability Index

- **Last Updated:** 2026-07-22
- **Engine:** Godot 4.6 + GDScript
- **Source:** `/architecture-review` 2026-07-22 (verdict PASS). IDs estables en `tr-registry.yaml`.

## Coverage Summary

- **Total requirements:** 56
- **Covered:** 56 (100 %)
- **Partial:** 0
- **Gaps:** 0

Leyenda de cobertura: **ADR-000X** = gobernado por ese ADR · **Diseño** = especificado en el GDD, se implementa en stories sin ADR · **Spike QQ-02** = incógnita de rendimiento (vertical slice).

## Full Matrix

| TR-ID | GDD / Fuente | Sistema | Requisito (resumen) | Cobertura | Estado |
|-------|-------------|---------|---------------------|-----------|--------|
| TR-time-001 | time-system.md | Tiempo | Reloj por tiempo real (delta), no frames | ADR-0001 | ✅ |
| TR-time-002 | time-system.md | Tiempo | Velocidades Pausa/1x/2x/3x | ADR-0001 + Diseño | ✅ |
| TR-time-003 | time-system.md | Tiempo | Cruce de umbral (no ==) → evento 1 vez | ADR-0001 | ✅ |
| TR-time-004 | time-system.md | Tiempo | Orden determinista al cruzar umbrales | ADR-0001 | ✅ |
| TR-time-005 | time-system.md | Tiempo | Clamp de delta (anti-salto alt-tab) | ADR-0001 | ✅ |
| TR-time-006 | time-system.md | Tiempo | Emite señales globales de tiempo | ADR-0001 | ✅ |
| TR-time-007 | time-system.md | Tiempo | Fuente única de tiempo | Diseño | ✅ |
| TR-time-008 | time-system.md | Tiempo | Serializar reloj; carga en Pausa | ADR-0002 | ✅ |
| TR-time-009 | time-system.md | Tiempo | Update < 0,1 ms (AC-T33) | Spike QQ-02 | ✅ |
| TR-data-001 | data-config.md | Datos | Catálogo data-driven desde fuente externa | ADR-0003 | ✅ |
| TR-data-002 | data-config.md | Datos | Definición read-only ≠ instancia (por id) | ADR-0003 | ✅ |
| TR-data-003 | data-config.md | Datos | Validación en carga (refs, ids, clamp, R5) | ADR-0003 | ✅ |
| TR-data-004 | data-config.md | Datos | Lookup por id en runtime | ADR-0003 | ✅ |
| TR-data-005 | data-config.md | Datos | Formato catálogo .tres vs JSON (Q#8) | ADR-0003 | ✅ |
| TR-data-006 | data-config.md | Datos | Tolerancia a id huérfano entre versiones | ADR-0002 + ADR-0003 | ✅ |
| TR-bus-001 | architecture.md | Bus (infra) | Bus de eventos global (autoload+signals) | ADR-0001 | ✅ |
| TR-bus-002 | architecture.md | Bus (infra) | Orden de handlers determinista | ADR-0001 | ✅ |
| TR-save-001 | architecture.md | Save (infra) | JSON en user://; save()/load_state() | ADR-0002 | ✅ |
| TR-save-002 | architecture.md | Save (infra) | Serializar estado del RNG + semilla | ADR-0002 | ✅ |
| TR-save-003 | architecture.md | Save (infra) | Vector2i → [x,y] (limitación JSON) | ADR-0002 | ✅ |
| TR-economy-001 | economy-budget.md | Economía | saldo_eur mutable; ingreso al tramite_completado | ADR-0001 | ✅ |
| TR-economy-002 | economy-budget.md | Economía | Cobros al nuevo_dia en orden determinista | ADR-0001 | ✅ |
| TR-economy-003 | economy-budget.md | Economía | Estado financiero + rescate insolvencia | Diseño | ✅ |
| TR-economy-004 | economy-budget.md | Economía | Gates ¿puedo construir/contratar? | Diseño | ✅ |
| TR-flow-001 | flow-queues.md | Flujo | Persona con máquina de 7 estados | Diseño | ✅ |
| TR-flow-002 | flow-queues.md | Flujo | Colas por servicio (FIFO+prioridad), desempate | Diseño | ✅ |
| TR-flow-003 | flow-queues.md | Flujo | Emparejamiento puesto→persona; atención con delta | Diseño | ✅ |
| TR-flow-004 | flow-queues.md | Flujo | Emite tramite_completado y abandono | ADR-0001 | ✅ |
| TR-flow-005 | flow-queues.md | Flujo | Muchos NPCs navegando (API + rendimiento) | ADR-0004 + Spike QQ-02 | ✅ |
| TR-flow-006 | flow-queues.md | Flujo | Serializar colas/puestos/personas | ADR-0002 | ✅ |
| TR-demand-001 | demand-generation.md | Demanda | persona_generada; acumulador por delta | ADR-0001 | ✅ |
| TR-demand-002 | demand-generation.md | Demanda | RNG sembrado determinista (mezcla ponderada) | ADR-0002 | ✅ |
| TR-demand-003 | demand-generation.md | Demanda | Señal BAJA/MEDIA/ALTA a UI/Doc | Diseño | ✅ |
| TR-staff-001 | staff-agents.md | Personal | Instancias Agente; mercado con RNG sembrado | ADR-0002 + Diseño | ✅ |
| TR-staff-002 | staff-agents.md | Personal | Provee modificador_produccion/factor_trato + gate FL4 | Diseño | ✅ |
| TR-staff-003 | staff-agents.md | Personal | Ausencias al nuevo_dia (RNG determinista) | ADR-0001 + ADR-0002 | ✅ |
| TR-construction-001 | construction-layout.md | Construcción | Rejilla = TileMapLayer | ADR-0004 | ✅ |
| TR-construction-002 | construction-layout.md | Construcción | Ratón↔celda (local_to_map) + validación | ADR-0004 | ✅ |
| TR-construction-003 | construction-layout.md | Construcción | Puestos/objetos = PackedScene, no tiles | ADR-0004 | ✅ |
| TR-construction-004 | construction-layout.md | Construcción | Provee aforo a Flujo/Personal; serializa layout | ADR-0002 + Diseño | ✅ |
| TR-doc-001 | documentation.md | Documentación | Configura horario que Flujo ejecuta/Demanda respeta | Diseño | ✅ |
| TR-doc-002 | documentation.md | Documentación | Eventos de la División (estacionales) | ADR-0001 + ADR-0003 | ✅ |
| TR-odac-001 | odac.md | ODAC | Prioridad + reconfiguración en caliente (4 modos) | Diseño | ✅ |
| TR-odac-002 | odac.md | ODAC | Aporta peso_prioridad; recibe reclamacion | ADR-0001 + Diseño | ✅ |
| TR-patience-001 | patience-satisfaction.md | Paciencia | Barra por persona; drena con delta; Pausa congela | Diseño | ✅ |
| TR-patience-002 | patience-satisfaction.md | Paciencia | Escucha Flujo; ordena abandono al llegar a 0 | ADR-0001 | ✅ |
| TR-patience-003 | patience-satisfaction.md | Paciencia | Cierre de sat al nuevo_dia (ingreso estable) | ADR-0001 | ✅ |
| TR-patience-004 | patience-satisfaction.md | Paciencia | Genera reclamacion (prob, RNG); empate → gana llamada | ADR-0001 + ADR-0002 | ✅ |
| TR-ui-001 | ui-hud.md | UI/HUD | Presentación pura: lee, no muta; emite órdenes | Diseño | ✅ |
| TR-ui-002 | ui-hud.md | UI/HUD | HUD persistente; pantallas desbloqueables por rango | Diseño | ✅ |
| TR-ui-003 | ui-hud.md | UI/HUD | Camera2D pan/zoom; modos Construcción/Asignación | Diseño | ✅ |
| TR-ui-004 | ui-hud.md | UI/HUD | Ratón-first sin hover-only; accesibilidad | Diseño | ✅ |
| TR-ui-005 | ui-hud.md | UI/HUD | No guarda estado de juego; sí preferencias UI | ADR-0002 | ✅ |
| TR-feedback-001 | feedback-juice.md | Feedback | Escucha el bus (read-only); vocabulario data-driven | ADR-0001 | ✅ |
| TR-feedback-002 | feedback-juice.md | Feedback | Flotantes/emotes; mood CanvasModulate+Light2D | Diseño | ✅ |
| TR-feedback-003 | feedback-juice.md | Feedback | Juice budget; degradación < 60 FPS; 2x/3x | Spike QQ-02 | ✅ |

## Known Gaps

**Ninguno.** 56/56 requisitos con ruta arquitectónica.

## Superseded Requirements

**Ninguno.** Ningún GDD ha cambiado tras escribirse su ADR (los 4 ADRs se escribieron con los 12 GDD ya congelados y consistentes).

## History

| Fecha | Cobertura | Notas |
|-------|-----------|-------|
| 2026-07-22 | 100 % (56/56) | Índice inicial. 4 ADRs Accepted. Verdict PASS. |
