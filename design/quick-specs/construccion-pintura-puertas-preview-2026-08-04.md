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

## 3b. Arte de puertas y ventanas (decisión 2026-08-04, 2ª tanda)

- Las piezas del pack están a escala arquitectónica real y NO adaptadas a la pared enana del
  juego — hay que ADAPTARLAS en tamaño y posición a la pared (orden del usuario).
- Identificación del usuario sobre la hoja: ARQ_004 (A) = puerta, adaptar a la pared.
  ARQ_009 (B) = **ventana alargada** que debe ocupar la pared de arriba a abajo, bien adaptada
  en tamaño y posición. ARQ_023 (C) = pared con ventana incrustada en L — redundante con
  nuestras paredes, descartada. ARQ_022 (D) = **pantalla de presentaciones para reuniones**
  (no es ventana) — apartada como futuro prop de sala de reuniones.
- Vía preferente: si KayKit u otro kit del mismo estilo trae puertas/ventanas que encajen
  mejor, usarlas ("si ves que se pueden coger del kaykit mejor hazlo o lo que tú veas").
  Decisión final con hoja a escala real de la pared antes del OK.

## 3c. Dirección de arte del suelo/pared (usuario, 2026-08-05, tras comparar con la demo de Summer)

Feedback literal comparando ambas demos ("me gusta bastante más el diseño que ha hecho summer"):
- **Suelo y paredes MÁS LIMPIOS**: menos ruido visual que la baldosa actual con juntas marcadas.
- **RODAPIÉ (zócalo): más pequeño y EN LA PARED, no en el suelo** — muere la tira de zócalo
  pintada dentro de la baldosa; nace un rodapié fino en la base del muro (paredes_salas).
- **CUADRÍCULA solo al construir**: en juego normal el suelo va limpio; la rejilla de celdas
  solo se muestra con el modo construcción activo.
- **Fuente de agua: medidas de ORIGEN** (la reescalada a 1,20 m se ve pequeña — recuperar la
  proporción original del modelo).
- **La mesa con los 3 aparatos encima: demasiado y desordenado** — no amontonar; cada aparato
  de sobremesa con su soporte propio (precedente de la radio con mesita horneada) o colocación
  con sentido, no todos sobre el mismo mueble.

## 4. Preview de objetos estilo tycoon (fantasma transparente)

- Al colocar un objeto, ANTES de comprarlo/colocarlo se ve su sprite real semitransparente en la
  posición del cursor, como quedaría en la habitación (no la caja genérica actual).
- Colocación del fantasma con el auto-anclaje (AnclajeSprite), validez con el tinte
  verde/rojo ya existente.
