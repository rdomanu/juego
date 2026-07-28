# Epic: Comodidades de la sala de espera (#15)

> **Layer**: Feature
> **GDD**: *pendiente* — hoy vive como `mult_comodidad` en `design/gdd/patience-satisfaction.md` (F1)
> **Architecture Module**: Comodidades #15 (Vertical Slice, **fuera del MVP 12**)
> **Status**: In Progress — 3/3 stories implementadas; **falta el sign-off del usuario** en ventana
> **Origen**: petición del usuario 2026-07-26, **ampliada el 2026-07-28** (equipamiento del funcionario
> y el USO de los objetos)

## Overview

Objetos que **hacen la espera más llevadera**: mejores asientos, máquinas de vending, revistas,
televisión… El jugador los compra y los coloca en sus salas de espera; a cambio, **la gente aguanta
más minutos** antes de largarse. Es la palanca de "invertir dinero para comprar paciencia", frente a
la otra vía (contratar más agentes para atender antes).

**Cita del usuario (2026-07-26):** *"esa paciencia debe subir en minutos con las distintas mejoras,
mejoras en los asientos, máquinas de vending, revistas, televisiones… cosas que mejoren los tiempos
de espera."*

## Lo que YA está hecho (y por qué esto es barato)

- **La fórmula ya tiene el hueco**: F1 de Paciencia multiplica por `mult_comodidad` (rango 0.6–1.0;
  por debajo de 1 la gente aguanta más). Hoy está fijo en **1.0** y documentado como *"lo bajará
  Comodidades #15"*. **No hay que tocar la fórmula ni el balance existente.**
- **Construcción ya sabe colocar objetos en salas** (`ASIENTO_BASICO` es exactamente eso: un elemento
  del catálogo con coste, colocado en una celda y contado por sala).
- **El catálogo es data-driven** (ADR-0003): añadir objetos es escribir `.tres`, no código.

## Lo que falta

1. **Catálogo**: un tipo de elemento "comodidad" con `coste_construccion_eur`, `aporte_confort` y
   quizá un coste de mantenimiento diario (una tele consume; una revista no).
2. **Construcción**: exponerlos en la toolbar (ya es automática desde el catálogo) y un getter
   `confort_de_sala(sala_id)`.
3. **Paciencia**: derivar `mult_comodidad` por sala en vez de usar el 1.0 fijo, con tope (0.6: por muy
   bien montada que esté la sala, nadie espera eternamente).
4. **Diseño**: cuánto aporta cada objeto y cuánto cuesta — es una decisión de balance, no técnica.

## Ampliación pedida por el usuario (2026-07-28)

> *"también podría aparecer objetos o no sé cómo llamarlo, si quieres añadir **papeleras, una radio,
> material mejor para que vayan más rápido los funcionarios**, nuevos puestos..."*

Eso parte el epic en **dos familias de objetos**, que se compran igual pero afectan a cosas distintas:

| Familia | Ejemplos | A quién afecta | Por dónde entra en la simulación |
|---|---|---|---|
| **Comodidades del ciudadano** | asientos mejores, vending, revistas, radio, tele, papeleras | **La espera** | `mult_comodidad` de Paciencia F1 (hueco ya hecho, hoy 1.0) |
| **Equipamiento del funcionario** | mejor ordenador, impresora de DNI nueva, mesa decente | **El trabajo** | `modificador_produccion` de Personal F2 (Flujo ya multiplica por él) |

**La segunda es igual de barata que la primera**: Flujo ya calcula la duración de cada atención como
`duracion_min × modificador_produccion(agente del puesto)`. Un equipamiento sería un multiplicador más
en ese producto, **por puesto**. Y da una decisión económica distinta y complementaria: *"¿invierto en
que aguanten más (comodidades) o en que salgan antes (equipamiento)?"*.

**Acceso**: ya está preparado — el menú del clic derecho sobre la sala (2026-07-28) tiene la entrada
**"🛋 Comodidades"** puesta y **deshabilitada**, esperando a este epic.

## Preguntas de diseño abiertas — RESUELTAS (usuario, 2026-07-28, story 001)

- ¿Por sala o por asiento? → **Por sala.**
- ¿Mantenimiento diario? → **Solo para lo que consume** (radio, tele, vending, fuente, equipos); la
  papelera y el revistero se pagan una vez.
- ¿Tope de confort? → **Sí**, `mult_comodidad_min = 0.6` (story 002): por muy bien montada que esté la
  sala, nadie espera eternamente.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | El catálogo de objetos y el confort de la sala | Integration | Complete | ADR-0003 |
| 002 | El efecto — aguantan más y atienden antes | Integration | Complete | ADR-0001, ADR-0003 |
| 003 | El uso de los objetos — vending, fuente y revistero | Integration | Complete | ADR-0002 |

**Cobertura de los 25 AC:** 001 → AC-CM01..06 (catálogo + colocación) · 002 → AC-CM07..12 (el confort y
el equipamiento hacen efecto) · 003 → AC-CM13..25 (la gente se levanta, usa el objeto y vuelve; el
vending deja 1 € en caja — petición del usuario 2026-07-28).

## Next Step

**Código y tests completos (3/3 stories, suite en verde).** Falta la demo en ventana con el usuario y
su sign-off antes de marcar el epic **Complete** — incluida la decisión pendiente de si esto entra en
el MVP o queda como epic post-MVP ya construido. **No está en ningún sprint formal todavía.**
