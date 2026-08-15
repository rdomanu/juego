# ADR-0005 — Orden de capas FIJO dentro de un contenedor isométrico

**Estado**: Aceptada (2026-08-01) · **Decidida por**: el usuario, tras el segundo bug de orden de
dibujo en las ventanillas ("la silla está encima de todo").

## Contexto

Un contenedor isométrico agrupa varios visuales que comparten celda o grupo de celdas (el ejemplo
canónico: la ventanilla = silla del funcionario + policía sentado + mostrador + silla del
ciudadano). Dentro de un mismo `Node2D`, Godot pinta a los hijos EN ORDEN, así que el orden de
inserción ES el orden de capas.

Este orden se ha roto ya DOS veces por la misma causa — añadir o reordenar hijos ad hoc
(`add_child` al final, `move_child` sueltos) al integrar una pieza nueva:
1. Julio: el policía se dibujaba encima de su mesa (saga de 4 intentos hasta el orden bueno).
2. 2026-08-01: la silla de sprite nueva quedó por encima de la mesa Y del policía.

## Decisión

**El orden de capas de un contenedor isométrico es FIJO, con nombre, y lo gestiona un único
mecanismo** — nunca `add_child`/`move_child` sueltos repartidos por el código:

```
CAPA_FONDO           (0)  → muebles de apoyo sobre los que se está: sillas, banquetas
CAPA_PERSONAJE       (1)  → el muñeco/sprite del personaje
CAPA_FRENTE          (2)  → el mueble que da a cámara y tapa: mostrador, mesa
CAPA_FRENTE_SUR      (3)  → lo que está DELANTE del mueble, entre él y la cámara (2026-08-03)
CAPA_FRENTE_SUR_ALTO (4)  → la mitad ALTA de esa pieza cuando el personaje va en medio (respaldo)
```

En palabras del usuario (la regla de la ventanilla): *"la silla, luego encima el policía, y luego
la mesa tapando al policía y a la silla"*. El lado del ciudadano usa las mismas capas (su silla al
fondo, él encima; la mesa queda al norte y no los tapa porque está en otra celda más lejana).

Cada contenedor con más de un visual apilado expone constantes de capa y una función de inserción
que coloca al hijo en su sitio según su capa. Quien integra una pieza nueva DECLARA su capa; el
orden resultante sale solo.

## Consecuencias

- **Todo lo nuevo** (muebles del pack, personajes, decorados) entra por el mecanismo de capas. Está
  PROHIBIDO añadir un hijo visual a un contenedor compartido sin declarar su capa (regla dura en
  `.claude/docs/technical-preferences.md`).
- Las transiciones dinámicas (cambio de titular del puesto, cambio sprite↔fallback) reordenan por
  capa, no por índices mágicos.
- La verificación visual de una composición nueva se hace con fotomontaje que replica el ORDEN DE
  CAPAS real del árbol (no solo los offsets) antes de tocar el juego.

## Enmienda 2026-08-03 — el lado SUR y el que no cuelga del contenedor

Tercera rotura de la misma familia, con captura del usuario: **la silla de espera y el ciudadano
del lado sur salían DETRÁS del mostrador** ("parecen incrustados en la mesa"). Dos causas, dos
respuestas — las dos dentro del mecanismo:

1. **La silla de espera era NIETA del contenedor** (hija de "Mesa", añadida "al final para que se
   dibuje encima del tablero"). Un nieto está FUERA del mecanismo de capas: su orden lo decidía el
   orden interno de "Mesa", y ese nodo entero se permuta con el policía al sentarse. Con el
   mostrador de 2 celdas —que se dibuja desplazado a su celda este y cuyo PNG cae 82 px a la
   izquierda del ancla, tapando la celda sur entera— eso dejaba silla y piernas ocultas. **Regla
   que se añade**: en un contenedor con capas, todo visual apilado es HIJO DIRECTO con capa
   declarada; nada de nietos "colados" dentro de otra pieza. La silla pasa a `CAPA_FRENTE_SUR`.
2. **El ciudadano no cuelga del contenedor** (vive en la capa global de muñecos, donde el y-sort le
   ordena contra todo lo demás y donde se le copia su posición cada frame). Recolocarlo en el
   contenedor solo mientras le atienden sería entrar y salir de padre en cada llamada. Para este
   caso —y solo para él— se admite la alternativa que este ADR descartaba: **`z_index` de ESTADO**,
   subido mientras la persona está en el frente del puesto (`en_atencion`) y devuelto a 0 al salir
   (`NPCsFlujo.Z_FRENTE_PUESTO` / `marcar_frente_de_puesto`). Se admite porque cumple lo que le
   faltaba al z_index suelto: la decisión está en UN sitio, depende de un ESTADO del modelo (no del
   orden de creación de nodos) y es reversible. El y-sort sigue ordenando dentro de cada grupo de
   z_index, así que el ciudadano que camina por el mapa no se ve afectado.
3. **"La silla delante de quien se sienta" — probado y DESCARTADO por evidencia.** Sobre el papel
   toca: el ciudadano se sienta mirando a la mesa (de espaldas a cámara), así que su respaldo es lo
   más cercano al espectador. Montado (z de la silla 2 > z 1 del ciudadano) y mirado en el
   fotomontaje, el resultado es que **la silla BORRA a la persona**: el sprite de `silla_espera`
   está renderizado con asiento y respaldo macizos y encima del muñeco solo deja asomar el pelo.
   Regla de proceso que confirma esto: *un orden de capas se decide MIRANDO el fotomontaje, no
   razonando la geometría* — la misma regla que ya obligó a juzgar las sillas con el asiento vacío.
4. **La solución buena: OCLUSIÓN PARCIAL con la silla PARTIDA** (decidida el mismo día, tras el
   descarte anterior). La silla de espera se renderiza en DOS sprites de la misma pieza —
   `silla_espera_asiento_270` (patas + asiento) y `silla_espera_respaldo_270` (solo respaldo)—
   anclados en el MISMO punto 3D (la base del asiento), y el muñeco va EN MEDIO:

   **mostrador (capa 2) < asiento (capa 3, z 0) < ciudadano (z 1) < respaldo (capa 4, z 2)**

   Así el respaldo le tapa solo la zona lumbar, que es lo que pasa de verdad, y la persona se
   sigue viendo. El respaldo necesita capa PROPIA (`CAPA_FRENTE_SUR_ALTO`) además del z: dos hijos
   con la misma capa quedarían en orden indefinido dentro del contenedor. La silla ENTERA se queda
   para todos los demás usos (esperas normales), donde no hay nadie entre las dos mitades.
   Mientras los PNG no existan, `MesaAtencion.hay_silla_espera_partida()` es false y se dibuja la
   silla entera por debajo del sentado — el cableado no rompe nada al esperar al arte.

## Enmienda 2026-08-03 (bis) — el arrime no puede cruzar la frontera de celdas

El "arrime al borde" se implementó como MEDIO paso de celda, y medio paso deja el centro de la
silla justo EN la frontera: media silla invade la celda del mostrador, contra la regla de rejilla.
La cuenta correcta es `arrime = 0,5 pasos − medio fondo de la silla`, con el fondo medido sobre la
BASE del PNG y pasado a celdas (`ancho_base_px / ANCHO_ROMBO`). Medidos: silla de espera 31 px
(0,3875 celdas) y silla del funcionario 33 px (0,4125) ⇒ arrimes de **0,306** y **0,294** pasos.
Vive en `MesaAtencion` (`FONDO_BASE_SILLA_*_PX` → `ARRIME_*` → `CELDA_FUNCIONARIO`/
`CELDA_CIUDADANO` → `DESVIO_DIBUJO_CIUDADANO`), una sola cadena para silla y persona: quien se
sienta va SIEMPRE donde su silla.

## Enmienda 2026-08-14 — sombras de contacto: FUERA del contenedor (y de la bolsa)

Las sombras de contacto (elipse difuminada bajo mobiliario y NPCs, decisión visual cerrada con el
usuario) NO se dibujan como hijos del contenedor de puesto ni de ningún visual. Se intentó primero
(con una `CAPA_SOMBRA = −1` de este mecanismo) y se descubrió un gotcha del árbol real, cazado con
sondas y muestreo de píxeles: **un CanvasItem creado durante la carga como descendiente de
`MundoProfundo` (la bolsa y-sort) queda permanentemente sin renderizar** — propiedades y textura
perfectas, cero píxeles, incurable (ni reparentar, ni `queue_redraw`, ni `visible` off/on; un
`duplicate()` del mismo nodo sí pinta). No reproducible en escena mínima.

La solución vive fuera del alcance de este ADR: `CapaSombras` (hermana de la bolsa, `z_index = −1`)
pinta TODAS las sombras del juego en un único `_draw()` desde un registro (ver su cabecera). Como
el `z_index` manda sobre el y-sort, toda sombra queda por debajo de cualquier cosa de pie sin
declarar capa. Este ADR sigue rigiendo, intacto, el orden de los hijos VISIBLES del contenedor;
la sombra del mostrador se registra en la capa única con el contenedor como ancla.

## Alternativas descartadas

- `z_index` por hijo: funciona, pero desperdiga la decisión por cada llamada y ya demostró ser
  frágil entre capas de escena distintas (saga del policía de julio).
- "Acordarse del orden bueno": es exactamente lo que ha fallado dos veces.
