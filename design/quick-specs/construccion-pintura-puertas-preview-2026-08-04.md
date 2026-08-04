# Quick Spec — Decisiones del usuario 2026-08-04 (construcción: pintura, puertas, preview, estanterías)

Decisiones dictadas por el usuario en sesión (literal resumido). Fuente de verdad para las
historias de esta tanda. Complementa: mapa-integracion-mobiliario.md, ADR-0004 (capa visual),
regla de imagen-antes-del-OK.

## 1. Estanterías (A=OBJ_007, B=OBJ_022 suelta, C=dos sueltas en esquina) — APROBADAS

- Entran las tres formas. Son muebles DE PARED: "se deben poder poner pegadas a la pared".
- **Arrimado a pared**: nada de centrarlas en la celda — se anclan al EXTREMO de su celda según
  su orientación, de modo que NO quede hueco entre pared y estantería ("quedaría mal y poco
  realista"). Verificación numérica obligatoria (borde trasero de la base vs línea de pared).
- La esquina C son simplemente dos B bien encajadas; el encaje fino queda cubierto por el
  arrimado a pared.
- Precio/aporte: pendiente de proponer números al usuario (balance = decide él).

## 2. Paredes y suelos: color BLANCO por defecto + herramienta de pintar

- Al construir una pared, su color por defecto es BLANCO (muere el color fijo por tipo de sala
  en las paredes).
- Herramienta tipo PINCEL en construcción: pinta el tramo de pared clicado con el color elegido.
- Con MAYÚS pulsada, el pincel pinta LA HABITACIÓN ENTERA (todos los tramos de esa sala).
- LO MISMO PARA EL SUELO: pintable por celda con el pincel; con MAYÚS, todo el suelo de la sala.
- **Paleta**: repertorio de ~30 colores fácilmente elegibles (elección concreta de la paleta
  delegada por el usuario: "o los que veas"). Data-driven.
- Persistencia: los colores pintados se guardan y cargan con la partida.

## 3. Flujo de sala: la puerta la elige el jugador, SIN predeterminado

- Al poner paredes a una sala, el paso siguiente es ELEGIR LA UBICACIÓN DE LA PUERTA.
- No se deja ninguna puerta predeterminada (muere el hueco automático).
- Nota de seguridad: una sala sin puerta ya no rompe nada — los NPC esperan con la señal 🚫
  (mecánica de accesos 2026-08-03) hasta que la puerta se abra.

## 4. Preview de objetos estilo tycoon (fantasma transparente)

- Al colocar un objeto, ANTES de comprarlo/colocarlo se ve su sprite real semitransparente en la
  posición del cursor, como quedaría en la habitación (no la caja genérica actual).
- Colocación del fantasma con el auto-anclaje (AnclajeSprite), validez con el tinte
  verde/rojo ya existente.
