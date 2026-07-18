# Estado de sesión — activo

*Última actualización: 2026-07-19*

## Tarea actual
Pre-producción de **"Comisario"**. Índice de sistemas creado. Siguiente: escribir GDDs por sistema
(empezando por Sistema de Tiempo) con `/design-system`.

## Hecho en esta sesión
- ✅ Plantilla CCGS instalada + GitHub `rdomanu/juego` + Godot 4.6 configurado.
- ✅ Concepto (`design/gdd/game-concept.md`).
- ✅ Prototipo HTML validado — PROCEDE (`prototypes/comisaria-flujo-concept/REPORT.md`).
- ✅ Art bible núcleo visual 1-4 (`design/art/art-bible.md`).
- ✅ Índice de sistemas — 27 sistemas (`design/gdd/systems-index.md`).

## Decisiones/datos clave nuevos
- **Rangos reales del CNP** para los ascensos (Subinspector → Inspector → Inspector Jefe → Comisario →
  Comisario Principal), con divisas de la Orden INT/430/2014. **Regla firme**: las divisas se hacen con
  la **imagen real filtrada**, NO dibujadas. (Verificar posible reforma "Policía de Primera Clase /
  Inspector Principal" antes de arte final.)
- Orden de diseño MVP: Tiempo → Datos → Economía → Flujo y Colas → Demanda → Personal → Construcción →
  Documentación → ODAC → Paciencia → UI/HUD → Feedback.

## Limitación técnica de la sesión
- Los **subagentes fallan** (créditos de contexto 1M no activos). El hilo principal (Opus) redacta todo
  directamente. Para usar el estudio de agentes en paralelo: `/model` → Opus 4.8 contexto estándar, o
  `/usage-credits`.

## Siguiente paso
`/design-system Sistema de Tiempo` (o `/map-systems next`) para el primer GDD.
El usuario quería revisar el índice de sistemas con calma antes de avanzar.
