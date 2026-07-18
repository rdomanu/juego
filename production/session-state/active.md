# Estado de sesión — activo

*Última actualización: 2026-07-18*

## Tarea actual
**Prototipo de concepto** del juego "Comisario" — validar si gestionar el flujo de ciudadanos
es divertido. Fase: **playtest** (jugador probando el prototipo HTML).

## Hipótesis del prototipo
Si el jugador organiza puestos y asigna agentes para atender la cola de ciudadanos (Documentación
+ ODAC), sentirá la satisfacción de optimizar el flujo. Señal: ajusta activamente su oficina ≥3
veces en ~5 min para bajar la cola, en vez de mirar pasivamente.

## Prototipo
- Ruta: **HTML** (un archivo, sin instalar). Ubicación: `prototypes/comisaria-flujo-concept/prototype.html`
- Incluye: 2 oficinas con salas de espera separadas (Documentación‑Secretaría / ODAC‑Policía Judicial),
  puestos de ODAC reconfigurables por tipo de denuncia (permisos de viaje / estafas / pérdidas),
  paciencia de los ciudadanos, objetos de sala (cafetera, vending, revistas, aire, asientos) que
  frenan la pérdida de paciencia y algunos dan ingresos, presupuesto, agentes, ciclo de días con
  demanda creciente, objetivo (llegar al Día 6 con satisfacción ≥60% → ascenso).

## Hecho en esta sesión
- ✅ Plantilla CCGS instalada + GitHub `rdomanu/juego` + Godot 4.6 configurado.
- ✅ Concepto en `design/gdd/game-concept.md`.
- ✅ Prototipo HTML construido.

## Conocimiento de dominio capturado (para /map-systems)
- La comisaría se divide en **brigadas**: Seguridad Ciudadana (Zetas), Policía Judicial (de ella cuelga
  la ODAC), Información, Policía Científica, Extranjería y Fronteras. **Documentación** cuelga de la
  **Secretaría** (no de una brigada); a nivel nacional tiene división propia. Las brigadas son el
  esqueleto natural de la escalera de carrera.

## Siguiente paso
Playtest del prototipo → debrief (¿enganchó?) → REPORT.md con veredicto PROCEDE/PIVOTA/DESCARTA.
Si PROCEDE: `/art-bible` → `/map-systems` → `/design-system`.
