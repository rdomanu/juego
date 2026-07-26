# Evidencia — paciencia-008: SE VE EL CABREO (ánimo, medidor y la marcha)

> **Story**: production/epics/paciencia/story-008-animo-visible-demo.md (Visual/Feel — ADVISORY)
> **Fecha**: 2026-07-26 · **Suite**: 423/423, exit 0 · **Arranque headless**: limpio, exit 0
> **Estado**: ✅ **SIGN-OFF CONCEDIDO** por el usuario

## Qué se entrega

- **Barra de paciencia sobre cada ciudadano que espera**: un fondo oscuro (lo que cabía) y un relleno
  que **se vacía** conforme se le acaba la paciencia; el color refuerza el tramo (🟢 >66 · 🟡 33-66 ·
  🔴 <33) y el **azul** marca a quien el jugador ha colado. Al vaciarse del todo, la persona se va:
  lo que se ve es exactamente lo que va a pasar. Se oculta en cuanto la llaman.
- **HUD de satisfacción**: `Satisfacción: N/100 (ayer N)` — la media de hoy construyéndose junto al
  cierre de ayer, que es **el que fija el dinero de hoy** — con su escala visible.
- **Contador de reclamaciones** del día y del mes, con las graves en rojo.
- **Aviso de trámites sin ventanilla capaz** (acción #2 del retro): `⚠ Nadie puede atender: tie ×3`.
- Detrás, las stories 001-007: la gente se cansa, se marcha, puntúa su visita, la media del día se
  cierra al amanecer y **fija el retorno DGP del día siguiente**, y los cabreados generan
  reclamaciones que ocupan ventanilla en ODAC sin pagar nada.

## Checklist de la demo

| # | Verificación | Resultado |
|---|--------------|-----------|
| M1 | Cada ciudadano esperando muestra su ánimo y se ve **cambiar** con el tiempo | ✅ |
| M2 | Alguien **se marcha** al agotarse su paciencia, de forma legible | ✅ |
| M3 | El HUD muestra la satisfacción de hoy junto a la de ayer, y las reclamaciones | ✅ |
| M4 | **Se nota la diferencia** entre gestionar bien y gestionar mal | ✅ |
| M5 | FPS ≥ 60 con la sala llena de indicadores | ✅ sin tirones percibidos |

## Rondas de feedback (todas corregidas antes del sign-off)

1. **La barra no se leía**: *"justo cuando la barra baja y se empieza a poner en rojo se van; debe ser
   más intuitivo, que cuando se vacíe la barra se vayan"*. El indicador era de **tamaño fijo** y solo
   cambiaba de color, así que no se veía venir nada → rehecho como barra que **se vacía**.
2. **Faltaban accesos**: *"no hay panel de guardado, ni de personal accesible como el de construir"*.
   El guardado existía en el código pero **no había forma de invocarlo desde el juego**: la partida no
   se podía guardar → botonera visible (Personal / Guardar / Cargar) con sus teclas.
3. **Panel de calibración** (F1), *"solo para el desarrollador"* → 13 knobs con su rango a la vista,
   termómetro en vivo y botón de **fijar en el catálogo**. No se instancia en un build exportado.
4. **Enmienda**: *"si están de camino a la sala de espera, ese camino no debe gastar paciencia"* → los
   minutos del paseo se descuentan antes de empezar a esperar.
5. **Mecánica nueva**: colar con el botón derecho (menú contextual) a costa de la paciencia del resto.
   El clic no funcionaba al principio — se leía el puntero del sistema y no el punto del clic.

## Sign-off

- **Sign-off del usuario: ✅ CONCEDIDO (2026-07-26)** — *"paciencia está bien de momento, veo que baja
  mucho la barra pero entiendo que con mejoras en la sala podría subir la paciencia por lo que lo
  dejamos así"*.
- **Valor de `tolerancia_base_min`: 30 (sin cambios)** — el usuario decide NO tocarlo.

## ⚠️ Nota de balance que hay que recordar (dependencia de diseño)

El sign-off viene **con una condición implícita**: el usuario acepta que la barra baje deprisa
**porque cuenta con que las mejoras de sala la suban** (Comodidades #15: mejores asientos, vending,
revistas, TV). Es decir:

> **El balance actual de la paciencia da por hecho un sistema que todavía no existe.**

Consecuencias que hay que tener presentes:
- Si **Comodidades #15 no llega**, el juego se queda más duro de lo que el usuario ha aprobado, y
  `tolerancia_base_min` tendría que subir para compensar.
- Cuando Comodidades llegue, **hay que revisar este número otra vez**: si la sala bien montada da
  mucha paciencia extra, 30 puede acabar siendo demasiado generoso de partida.
- El hueco de la fórmula ya existe (`mult_comodidad`, hoy fijo en 1.0), así que el sistema encaja sin
  tocar el balance existente. Epic esbozado en `production/epics/comodidades/`.
