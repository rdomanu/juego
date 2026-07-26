# Epic: Comodidades de la sala de espera (#15)

> **Layer**: Feature
> **GDD**: *pendiente* — hoy vive como `mult_comodidad` en `design/gdd/patience-satisfaction.md` (F1)
> **Architecture Module**: Comodidades #15 (Vertical Slice, **fuera del MVP 12**)
> **Status**: Esbozado — **no planificado**; a la espera de decisión de alcance del usuario
> **Origen**: petición del usuario 2026-07-26

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

## Preguntas de diseño abiertas (para el usuario)

- ¿El confort es **por sala** (una tele beneficia a toda la sala) o **por asiento** (butaca cómoda
  solo a quien se sienta en ella)? *Recomendación: por sala, mucho más simple de entender y de jugar.*
- ¿Tienen **coste de mantenimiento** diario? Daría una decisión económica real (invertir vs. gastar).
- ¿Un tope de confort por sala, o se puede llenar la sala de teles?

## Next Step

Decisión de alcance del usuario: si entra al MVP (sería un epic pequeño, ~4-5 stories) o se queda
para después del MVP. **No está en ningún sprint.**
