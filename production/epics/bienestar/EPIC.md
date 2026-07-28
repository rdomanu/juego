# Epic: Cansancio y sala de descanso (#13 Bienestar)

> **Layer**: Feature
> **GDD**: *pendiente* — hoy solo existe el gancho en `design/gdd/documentation.md` (DO6) y el
> `motivacion` estático de `design/gdd/staff-agents.md`
> **Architecture Module**: Horarios/Bienestar #13/#15 (Vertical Slice, **fuera del MVP 12**)
> **Status**: Esbozado — **no planificado**; a la espera de decisión de alcance del usuario
> **Origen**: petición del usuario 2026-07-28

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
