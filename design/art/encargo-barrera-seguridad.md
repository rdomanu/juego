# Encargo — Barrera de seguridad de la entrada (2026-08-08)

Pedido del usuario (literal): "una barrera de seguridad que ocupe el ancho de una carretera
entera, de este estilo pero adaptado a poly: https://www.turbosquid.com/es/3d-models/industrial-barrier-6m-3d-1227084
— así se puede construir en la entrada".

Autorización de gasto: dada (encargo directo del usuario; generación 3D ≈0,54$).

## Especificación de generación (disparar cuando Summer reconecte)

- **Pieza**: `barrera_seguridad` — barrera de pluma industrial (boom barrier) como la referencia:
  cabina/pilar compacto a un lado + brazo horizontal abatible con franjas rojas y blancas +
  apoyo en el extremo libre. Adaptada a LOW-POLY estilizado (mismo lenguaje que el carkit
  Kenney y los muñecos cabezones — nada de detalle industrial fino).
- **Prompt base**: "industrial boom barrier gate, 6 meter arm, red and white striped arm,
  compact pillar housing with small support post at far end, low-poly stylized game asset,
  clean flat colors" (ajustar al estilo de la biblioteca si hay variantes).
- **Escala**: el brazo debe cubrir el ANCHO COMPLETO de la carretera del juego = 6 celdas
  (misma familia de escala que las carreteras a 6,0; calibrar por LONGITUD del brazo con el
  pipeline de entorno, factor de familia de carreteras como referencia).
- **Vistas**: 4 rotaciones reales con el pipeline propio (las "4 vistas" de la IA no son
  rotaciones — lección documentada). Conforme a la brújula: 0=S, 90=O, 180=N, 270=E.
- **Destino**: pieza colocable en la paleta del diseñador (categoría Objetos o Construcción),
  para que el usuario la monte en el control de entrada (las anclas ANCLA_GARITA/ANCLA_BARRERA
  del recinto ya existen en entorno_exterior.gd como referencia de composición).
- GLB original a capturas/fuentes/barrera_summer/ + CREDITS al día (generación propia Summer).

## Estado

- [ ] Summer reconectado (BLOQUEADO 2026-08-08: MCP summer-engine caído; el usuario reconecta con /mcp)
- [ ] Buscar antes en biblioteca gratis ("boom barrier", "gate barrier", "parking barrier")
- [ ] Generación si no hay nada (idempotencyKey: comisario-barrera-seguridad-v1)
- [ ] Render 4 vistas + composición sobre carretera de 6 celdas con coche y muñeco
- [ ] Veredicto del usuario → paleta
