# Estado de sesión — activo

*Última actualización: 2026-07-18*

## Tarea actual
Pre-producción del juego **"Comisario"** (tycoon de gestión de comisarías del CNP). Concepto
recién definido vía `/brainstorm`.

## Hecho en esta sesión
- ✅ Instalada la plantilla Claude Code Game Studios (aplanada en la raíz).
- ✅ Git propio + GitHub `rdomanu/juego` (rama main).
- ✅ Motor Godot 4.6 + GDScript instalado (`C:\Users\manur\Godot\`, atajo `godot` en PATH) y configurado (`/setup-engine`).
- ✅ Concepto del juego escrito en `design/gdd/game-concept.md`.

## Decisiones clave
- Tycoon realista (no caricatura), 2D cenital/isométrico, PC, un jugador.
- Núcleo = flujo de personas por el edificio; progresión = escalera de carrera (Subinspector → Comisario → toda España).
- Tiempo real con pausa + ciclo día/noche y turnos.
- MVP = solo la Oficina de Denuncias.
- Ruta elegida: **prototipo primero** (validar que el flujo es divertido antes de GDDs extensos).

## Siguiente paso
`/prototype` del flujo de la Oficina de Denuncias. Después `/art-bible` → `/map-systems` → `/design-system`.

## Preguntas abiertas
- ¿El flujo de una sola oficina es divertido por sí solo? (lo resuelve el prototipo)
- Equilibrio del sistema de presión/influencia (diseño cuidadoso pendiente).
