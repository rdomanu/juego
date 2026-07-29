# Epic: Cansancio y sala de descanso (#13 Bienestar)

> **Layer**: Feature
> **GDD**: *pendiente* — hoy solo existe el gancho en `design/gdd/documentation.md` (DO6) y el
> `motivacion` estático de `design/gdd/staff-agents.md`
> **Architecture Module**: Horarios/Bienestar #13/#15 (Vertical Slice, **fuera del MVP 12**)
> **Status**: **Implementado 4/4 stories — PENDIENTE de demo en ventana y sign-off del usuario**
> **Origen**: petición del usuario 2026-07-28

> **Nota de proceso (2026-07-29)**: este epic se implementó **antes** de escribir sus stories. La 001
> se redactó al empezar; las **002, 003 y 004 se escribieron a posteriori** (2026-07-29) documentando
> los commits `f738c53`, `3a4322a` y `bb4b7bd`+`6442505`. Los AC de las tres describen lo que YA se
> cumple, verificado contra el diff real y contra tests que existen y pasan. **Lo único que falta para
> cerrar el epic es la demo en ventana con el usuario y su sign-off.**

## Stories

| # | Story | Tipo | AC | Commit | Estado |
|---|---|---|---|---|---|
| 001 | [La barra de cansancio y el patrón de cada uno](story-001-barra-de-cansancio.md) | Logic | AC-BI01–06 | `a4eb42c` | ✅ Complete |
| 002 | [El precio de la hora extra lo elige el jugador](story-002-el-precio-de-la-peonada.md) | Integration | AC-BI07–14 | `f738c53` | ✅ Complete |
| 003 | [La sala de descanso — se levantan de verdad](story-003-la-sala-de-descanso.md) | Integration | AC-BI15–24 | `3a4322a` | ✅ Complete |
| 004 | [Ver quién está de café — y notarlo en la cola](story-004-verlo-en-pantalla.md) | Visual/UI + Logic | AC-BI25–34 | `bb4b7bd`, `6442505` | 🔸 Lógica ✅ · **visual pendiente de demo** |

**Estado de la suite al documentar (2026-07-29)**: 591/591, 75 archivos, exit 0. Arranque headless limpio.

## Overview

Los funcionarios **se cansan** y **se van a descansar**. Cuando la barra de cansancio de un agente se
agota, se levanta de su puesto y va a la **sala de descanso**; mientras está allí, su ventanilla no
atiende. El jugador tiene que **cuadrar los descansos con la cola**: si todos descansan a la vez a las
11:00, la sala de espera revienta.

Es la pieza que **cierra el círculo de la peonada**: hoy alargar la tarde solo cuesta dinero; con
cansancio, alargar también **consume a la gente**.

## Especificación que dio el usuario (2026-07-28) — literal, no interpretada

> *"hay que tener en cuenta el cansancio de los funcionarios, deberíamos tener una sala de descanso,
> cuando la barra de cansancio del funcionario se agote se levantan y se van a descansar, calcula que
> más o menos y lo que debería ser es de **30 minutos por jornada**, hay algunos que hacen **15 y 15**,
> otros **30 minutos enteros** e incluso hay funcionarios que **se van 1 hora aun sabiendo que no se
> puede**"*

De ahí salen las reglas base:

| Regla | Valor | Nota |
|---|---|---|
| Descanso **de derecho** por jornada | **30 min** | Es el "café" reglamentario del funcionario |
| Patrón **cumplidor A** | 15 + 15 | Dos pausas cortas |
| Patrón **cumplidor B** | 30 seguidos | Una pausa larga |
| Patrón **caradura** | **60 min** | Se pasa del tiempo **a sabiendas** — es el conflicto de gestión |
| Disparador | la **barra de cansancio** llega a 0 | No es un horario fijo: es un estado |

**La decisión de juego que crea:** ¿te comes el atasco mientras están de café, o **contratas a alguien
más** para cubrir los descansos? Y con los caraduras: ¿les dices algo (¿coste de moral?) o dejas correr?

## Preguntas de diseño abiertas (para el usuario)

- **¿Quién es caradura?** ¿Un atributo del agente (ej. Motivación baja → se pasa) o azar por jornada?
  *Recomendación: derivado de la **Motivación** — así el atributo que ya existe gana un efecto visible,
  y encaja con la desmotivación por salir tarde que YA implementa Documentación #8 (DO5).*
- **¿El cansancio sube con qué?** ¿Minutos atendiendo, personas atendidas, o cola encima?
  *Recomendación: minutos atendiendo (simple y legible), acelerado por las horas extra de la peonada.*
- **¿La sala de descanso es obligatoria?** ¿Sin ella descansan igual (en el pasillo, peor) o no pueden?
  *Recomendación: sin sala descansan igual pero recuperan más despacio — así no bloquea la partida
  inicial, pero construirla se nota.*
- **¿Se puede negar el descanso?** Sería la palanca "exprimir" del sistema, hermana de la última
  admisión de Documentación (más trámites hoy, menos moral mañana).

## Lo que ya existe (por qué esto NO parte de cero)

- **`Agente.motivacion` (1-5)** ya modula rapidez (F2) y trato (F3) de Personal — el enganche está.
- **Documentación #8 ya desmotiva** a quien sale tarde (−1, suelo 1, una vez al día): mismo patrón.
- **Construcción ya sabe** de tipos de sala con aforo y de elementos colocables: una `sala_descanso`
  es un `TipoSala` más en el catálogo.
- **Flujo ya sabe cerrar un puesto sin interrumpir** la atención en curso (`cierre_pendiente`): irse a
  descansar es exactamente eso — se termina al que se está atendiendo y **luego** se levanta.

## Lo que falta

1. **Catálogo**: `sala_descanso` (TipoSala) + knobs de cansancio (minutos de aguante, recuperación).
2. **Personal**: barra de cansancio por agente, patrón de descanso (15+15 / 30 / 60), estado
   "descansando", y la vuelta al puesto.
3. **Flujo**: el puesto queda sin dotar mientras su agente descansa (ya sabe hacerlo: gate FL4).
4. **UI**: ver quién está de café y cuánto le queda; aviso cuando una ventanilla se queda sola.

## Next Step

Decisión de alcance del usuario. **No está en ningún sprint.** Si entra, sería un epic de ~5-6 stories
y conviene hacerlo **después** de Comodidades #15 (comparten la idea de "salas que no atienden pero
importan").
