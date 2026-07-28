# Evidencia — comodidades: MENÚ DE LA SALA, COMPRA DE OBJETOS Y USO REAL DEL VENDING

> **Stories**: production/epics/comodidades/story-001-catalogo-y-confort-de-sala.md (Integration) +
> story-002-efecto-en-paciencia-y-rendimiento.md (Integration) +
> story-003-uso-de-los-objetos.md (Integration)
> **Fecha**: 2026-07-28 · **Suite**: 535/535, exit 0 · **Arranque headless**: limpio, exit 0
> **Estado**: ✅ **SIGN-OFF CONCEDIDO** por el usuario

## Qué se entrega

- **Menú contextual del clic derecho sobre la sala**: entrada para comprar y colocar comodidades
  (asientos, vending, revistero, radio, tele, papeleras) y equipamiento del funcionario, con su coste y
  su mantenimiento diario a la vista.
- **Compra de objetos**: se cobra por la API de Economía (gate E4), se coloca en la sala elegida y
  aporta confort (aguanta más) o rendimiento (atiende antes) según la familia del objeto.
- **Uso real del vending** (y del resto de objetos usables — fuente, revistero): la persona deja la
  cola, se acerca al objeto, recupera paciencia y, si el objeto cobra, deja dinero en caja. Se probó en
  marcha, no solo por test: se vio a gente levantarse, usar la máquina y volver a la cola.

## Checklist de la demo

| # | Verificación | Resultado |
|---|--------------|-----------|
| CM1 | El clic derecho sobre la sala abre el menú y permite comprar/colocar un objeto | ✅ |
| CM2 | El coste se descuenta del saldo y el objeto queda colocado en la celda elegida | ✅ |
| CM3 | Se ve a gente levantarse, ir al vending, usar la máquina y volver a esperar | ✅ |
| CM4 | El vending deja dinero en caja al usarse (ingreso de comodidades) | ✅ |
| CM5 | La fuente y el revistero se usan igual pero gratis (recuperan paciencia sin cobrar) | ✅ |

## Ajustes que salieron de ver el sistema en marcha (lo más valioso de esta demo)

Viendo la sala funcionando en tiempo real, con gente usando el vending una y otra vez, salieron dos
correcciones directas del propio usuario:

1. **Tope de 2 viajes por visita.** El usuario, observando: *"hay muchos que lo hacen varias veces, eso
   no es normal, vas 1 vez o 2 como mucho, he visto a 1 hasta 4 veces"*. Sin tope, la tirada de
   `RNGService` podía volver a activarse cada tick para la misma persona, y en una visita larga eso se
   traducía en 3 o 4 viajes a la máquina — algo que no pasa en una comisaría real. Se añadió un **tope
   de 2 viajes por visita**: a partir del segundo uso, esa persona ya no vuelve a levantarse aunque la
   tirada le sea favorable.
2. **Rasgo `prob_consumidor` por persona (0.45).** El usuario señaló: *"no todos consumen por lo que
   sea; no todos los que baje la paciencia quieren tomar algo, al igual que el agua"*. Antes, cualquiera
   por debajo del umbral de paciencia tenía la misma probabilidad de levantarse a por algo. Ahora cada
   persona lleva un rasgo que se decide **una sola vez, al generarse, y para siempre**: es de las que
   consumen (con probabilidad 0.45) o no lo es. Quien no es consumidor nunca se levanta a usar nada,
   por muy baja que tenga la paciencia — igual que en la vida real, no todo el mundo bebe agua o compra
   algo solo porque está esperando.

## Sign-off

- **Sign-off del usuario: ✅ CONCEDIDO (2026-07-28)** — *"lo dejamos así"*.

## Nota

Ambos ajustes (tope de viajes y rasgo `prob_consumidor`) nacieron **de ver el sistema jugado**, no del
diseño original de las stories 001-003 — quedan registrados aquí como la fuente de verdad de por qué
existen, junto con el cierre formal del epic en `production/epics/comodidades/EPIC.md`.
