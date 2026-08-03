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
CAPA_FONDO      (0)  → muebles de apoyo sobre los que se está: sillas, banquetas
CAPA_PERSONAJE  (1)  → el muñeco/sprite del personaje
CAPA_FRENTE     (2)  → el mueble que da a cámara y tapa: mostrador, mesa
CAPA_FRENTE_SUR (3)  → lo que está DELANTE del mueble, entre él y la cámara (2026-08-03)
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

## Alternativas descartadas

- `z_index` por hijo: funciona, pero desperdiga la decisión por cada llamada y ya demostró ser
  frágil entre capas de escena distintas (saga del policía de julio).
- "Acordarse del orden bueno": es exactamente lo que ha fallado dos veces.
