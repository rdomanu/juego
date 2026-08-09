# Quick Spec — Bancos de espera multi-plaza (2026-08-09)

**Encargo del usuario**: *"bancos de espera de 2-3 celdas, 1 NPC por celda"* (2026-08-08), con el
arte ya aprobado el 2026-08-09 (*"los bancos ok"*): tres tiers renderizados en 4 vistas —
`banco_espera_medio` (aeropuerto, 3 plazas), `banco_espera_pro` (premium azul, 3 plazas) y
`banco_madera_summer` (2 plazas, tier básico).

## 1. Overview

Hoy un asiento de sala de espera es **una celda = una silla = un NPC** (`Construccion.ASIENTO_BASICO`,
id especial fuera del catálogo). Esta spec añade el **banco**: un mueble que ocupa 2-3 celdas y ofrece
**una plaza sentada por celda**, para que la sala de espera se lea como una sala de espera de verdad
(gente en fila en un banco) en vez de sillas sueltas repartidas.

## 2. Lo que YA existe y se reutiliza (nada nuevo donde no hace falta)

| Pieza | Estado |
|---|---|
| Muebles multi-celda (`Comodidad.superficie`) | ✅ Ya funciona (el sofá de descanso vale 3) |
| Campo `Comodidad.plazas` | ✅ Ya existe en el esquema… pero **solo lo lee la sala de descanso** (`plazas_de_descanso`) |
| Reserva de plaza por celda (`NPCsFlujo._plaza_de`) | ✅ Ya es un dict celda → NPC |
| Sprites de 4 vistas por pieza | ✅ Los tres bancos, renderizados y aprobados |
| Postura de sentado del NPC | ✅ `Muneco` ya tiene sprites `_sit_` por dirección |

**El hueco real**: en la sala de ESPERA, "ser un asiento" se decide comparando el catálogo con
`ASIENTO_BASICO`. Un banco no es ese id, así que hoy sería un mueble decorativo en el que nadie se
sienta.

## 3. Reglas detalladas

1. **Un banco es una `Comodidad`** de familia `ciudadano` con `superficie` = `plazas` = 2 ó 3.
   No se inventa un tipo nuevo: es el mismo camino de catálogo que la silla tapizada.
2. **Cada celda del banco es una plaza.** El NPC que la reserva se sienta ahí; dos NPCs no comparten
   celda (lo garantiza el `_plaza_de` que ya existe).
3. **Sentarse**: un NPC está sentado si su plaza reservada cae en una celda de un mueble con
   `plazas > 0` (o del `ASIENTO_BASICO` de siempre). Sustituye a la comparación contra un id fijo.
4. **Aforo de la sala** (`_plazas_max_de`, tope por área): un banco cuenta **tantas plazas como
   celdas ocupa**, no una. Si no, un banco de 3 se colocaría como si fuera una silla y la sala
   admitiría el triple de gente sentada de la que cabe físicamente.
5. **Orientación**: el banco gira con R como cualquier mueble de 4 vistas; los NPCs sentados miran
   hacia donde mira el banco (mismo criterio que la silla de la ventanilla).
6. **Precio por tier** (provisional, en línea con las sillas 25/60/120 €):
   básico **80 €** (2 plazas), medio **150 €** (3), pro **240 €** (3, más confort).
   Aporte de confort: 2 / 3,5 / 5 por plaza-equivalente.

## 4. Edge cases

- **Banco parcialmente ocupado**: normal — cada celda se reserva por su cuenta.
- **Demoler un banco con gente sentada**: mismo camino que hoy con una silla ocupada (la reserva se
  libera al demoler; el NPC pasa a hueco de pie en el siguiente reparto).
- **Banco que no cabe entero**: `validar_elemento` ya lo rechaza — no hay banco a medias.
- **Save viejo**: no hay bancos guardados, así que nada que migrar. Un save con `ASIENTO_BASICO`
  sigue funcionando igual (regla 3 lo incluye explícitamente).

## 5. Dependencias

`Construccion` (catálogo, huella, aforo) · `NPCsFlujo` (reparto de plazas, postura) · `Comodidad`
(esquema, sin cambios) · arte ya aprobado.

## 6. Tuning knobs

`densidad_asientos` (ya existe, tope de plazas por área) · precio y `aporte` por tier en los `.tres`.

## 7. Criterios de aceptación

- [ ] AC1 — Un banco de 3 celdas colocado en una sala de espera admite **3 NPCs sentados a la vez**,
      uno por celda.
- [ ] AC2 — Un NPC cuya plaza cae en una celda de banco se dibuja **sentado** (no de pie).
- [ ] AC3 — El aforo de la sala cuenta el banco como **3 plazas**, no como 1.
- [ ] AC4 — El `ASIENTO_BASICO` de siempre sigue comportándose exactamente igual (sin regresión).
- [ ] AC5 — Los tres bancos aparecen en la barra de construcción con su precio y sus plazas.
