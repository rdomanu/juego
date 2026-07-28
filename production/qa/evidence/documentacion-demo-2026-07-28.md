# Evidencia — documentacion: PANEL DEL HORARIO, PEONADA POR VENTANILLA Y GOTEO DE TARDE

> **Stories**: production/epics/documentacion/story-005-panel-horario-demo.md (UI — ADVISORY) +
> production/epics/documentacion/story-006-peonada-por-ventanilla-y-tarde.md (Integration — nacida de
> esta misma demo)
> **Fecha**: 2026-07-28 · **Suite**: 535/535, exit 0 · **Arranque headless**: limpio, exit 0
> **Estado**: ✅ **SIGN-OFF CONCEDIDO** por el usuario

## Qué se entrega

- **Panel del horario (tecla H)**: slider de cierre con la **peonada calculada en vivo** conforme se
  mueve (qué cuesta alargar la tarde, ventanilla a ventanilla), estado del servicio
  (ABIERTA/CERRANDO/CERRADA) y el **margen de última admisión** (hasta qué minuto se da número antes de
  cerrar, para que nadie se quede con la puerta cerrada en la cara).
- **Ventanillas que se quedan por la tarde**: la decisión de ampliar horario ya no es todo-o-nada por
  plantilla — el jugador elige, ventanilla por ventanilla, cuál se queda de guardia y paga la peonada
  **solo por esas**.
- **Semáforo de demanda con consejo** e icono, para decidir si ampliar horario compensa ese día.
- **Bandeja de comunicados de la División**: los avisos deterministas por mes (vacaciones → pasaporte,
  colapso de extranjería → TIE) que amplían la ventana de un trámite concreto.
- Detrás, las stories 001-004: el servicio y su reloj, la mudanza del horario (ya no vive prestado en
  Flujo), la peonada como coste real y los eventos de la División con guardado.

## Checklist de la demo

| # | Verificación | Resultado |
|---|--------------|-----------|
| D1 | El slider mueve el cierre y **la peonada se recalcula en vivo** al arrastrarlo | ✅ |
| D2 | Se ve qué ventanillas quedan de guardia por la tarde y cuáles no | ✅ |
| D3 | El margen de última admisión se entiende sin explicación aparte | ✅ |
| D4 | Los comunicados de la División aparecen en su mes y se leen en la bandeja | ✅ |
| D5 | El estado del servicio (ABIERTA/CERRANDO/CERRADA) es coherente con el reloj | ✅ |

## Ajustes que salieron de la propia demo (story 006)

Viendo el panel en marcha, dos cosas no cuadraban y se corrigieron en la misma sesión:

1. **La peonada pasó a pagarse POR VENTANILLA, no por plantilla.** Antes, ampliar el horario era
   todo-o-nada: se pagaba la peonada de toda la plantilla aunque solo hiciera falta dejar una
   ventanilla de guardia. Con el jugador viéndolo en pantalla, la decisión real que quería tomar era
   "dejo esta ventanilla y esta otra, las demás cierran a su hora" — así que el coste y el efecto se
   movieron a nivel de ventanilla. Si al final del día no queda ninguna de guardia, el servicio se
   comporta como si no se hubiera ampliado, aunque el slider siga movido.
2. **Se añadió el goteo de demanda de tarde** (`perfil_hora_doc_tarde`). El perfil de Demanda original
   solo repartía llegadas hasta las 14:00 (AC-DM03a, suma 1.0) — es decir, ampliar el horario no traía
   gente **nueva** por la tarde, solo servía para vaciar la cola ya acumulada. Se añadió un goteo
   pequeño y aditivo (no renormaliza el resto del día, para no tocar los 45/día ya calibrados) que da
   una razón adicional, aunque modesta, para quedarse abierto.

## Sign-off

- **Sign-off del usuario: ✅ CONCEDIDO (2026-07-28)** — *"me parece muy bien"*.

## ⚠️ Nota de calibración pendiente (no bloquea el sign-off)

El goteo de tarde se añadió **a propósito pequeño** (no se diseñó para pagar una ventanilla él solo,
sino para sumarse a la cola acumulada). Queda pendiente de más partidas comprobar **si ese goteo, sumado
a la cola que se acumula durante el día, es suficiente para que la peonada de una ventanilla de tarde
compense de verdad** en distintos escenarios de demanda (BAJA/MEDIA/ALTA). Si no compensa, la palanca ya
existe (`perfil_hora_doc_tarde` es un knob aditivo, no hay que tocar la fórmula) — es cuestión de subir
el valor, no de rediseñar el sistema.
