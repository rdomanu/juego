# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. El juego arranca sin crash (a la vista Comisaría, o al menú si existe)
2. Se puede empezar una partida nueva
3. La interfaz responde a los inputs de ratón sin congelarse

## Core Mechanic (update per sprint)

<!-- Añadir el mecánico principal de cada sprint según se implemente -->
<!-- Bucle objetivo del vertical slice de Comisario: -->
4. [Bucle base] Llega un ciudadano → hace cola → un puesto lo atiende → se cobra el trámite → el reloj avanza
5. [Tiempo] Pausa / 1× / 2× / 3× cambian la velocidad de la simulación; en Pausa nada se simula pero la UI responde

## Data Integrity

6. Guardar partida completa sin error (cuando exista el guardado — ADR-0002)
7. Cargar partida restaura el estado correcto y arranca en Pausa, sin eventos retroactivos (ADR-0002)
8. Una misma semilla de RNG produce la misma partida (determinismo — ADR-0002)

## Performance

9. Sin caídas visibles de FPS en el hardware objetivo (objetivo 60 FPS)
10. Docenas de NPCs navegando a la vez mantienen 60 FPS (spike QQ-02 — ADR-0004)
11. Sin crecimiento de memoria en 5 minutos de juego (cuando exista el bucle base)
