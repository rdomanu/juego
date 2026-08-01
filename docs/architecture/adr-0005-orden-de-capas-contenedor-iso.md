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

## Alternativas descartadas

- `z_index` por hijo: funciona, pero desperdiga la decisión por cada llamada y ya demostró ser
  frágil entre capas de escena distintas (saga del policía de julio).
- "Acordarse del orden bueno": es exactamente lo que ha fallado dos veces.
