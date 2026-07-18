# Estado de sesión — activo

*Última actualización: 2026-07-19*

## Tarea actual
**Prototipo de concepto** del juego "Comisario" — veredicto **PROCEDE** (el flujo es divertido,
confirmado en playtest). Decidiendo si cerrar el prototipo y pasar al diseño real.

## Prototipo
- Ruta HTML: `prototypes/comisaria-flujo-concept/prototype.html` (v2: reloj real, horarios, tiempos
  reales DNI 12/Pasaporte 15/TIE 15 min, puestos DNI/Pasaporte vs TIE separados, día/noche).
- **Veredicto: PROCEDE** — "me ha parecido divertido" (hipótesis confirmada).

## Hecho en esta sesión
- ✅ Plantilla CCGS instalada + GitHub `rdomanu/juego` + Godot 4.6 configurado.
- ✅ Concepto en `design/gdd/game-concept.md`.
- ✅ Prototipo HTML construido y validado (2 iteraciones).

## Conocimiento de dominio capturado (para /map-systems y GDDs)
**Estructura por brigadas** (comisaría local): Seguridad Ciudadana (Zetas), Policía Judicial (de ella
cuelga la ODAC), Información, Policía Científica, Extranjería y Fronteras. **Documentación** cuelga de
la **Secretaría** (no de una brigada); a nivel nacional tiene división propia. Las brigadas = esqueleto
de la escalera de carrera.

**Trámites de Documentación**: DNI 12€ / 12 min · Pasaporte 30€ / 15 min · TIE 18€ / 15 min. Los puestos
de TIE y de DNI/Pasaporte son DISTINTOS (un puesto de TIE no hace DNI).

**Sistema de Horarios y peonadas** (idea a diseñar como sistema propio):
- Horario normal de Documentación: 09:00–14:30.
- Peonada de tarde opcional: 16:00–20:00 (coste extra). Sábados a veces (coste extra).
- Toda hora después de las 14:30 = +15€/hora por funcionario trabajando (horas extra).
- Horarios configurables por servicio (p. ej. TIE desde 08:00, DNI desde 09:30).
- Se cruza con el ciclo día/noche (de noche cierra Documentación y sube la criminalidad → más denuncias).

**ODAC**: puestos especializados por tipo de denuncia, reconfigurables en caliente (permisos de viaje,
estafas y lesiones, pérdidas/sustracciones, VioGén prioritaria…). Los denunciantes tienen paciencia;
objetos de sala (cafetera, vending, revistas, aire, asientos) la frenan y algunos dan ingresos.

## Siguiente paso
Escribir REPORT.md del prototipo → luego diseñar de verdad: `/art-bible` (look 2D isométrico) →
`/map-systems` → `/design-system` (empezando por Documentación y ODAC, incluyendo Horarios y peonadas).
