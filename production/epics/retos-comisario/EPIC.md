# Epic: Retos del Comisario (eventos con nombre y apellidos)

> **Layer**: Feature
> **GDD**: *pendiente* — emparenta con `design/gdd/staff-agents.md` (plantilla) y con los eventos de la
> División ya implementados en `design/gdd/documentation.md` (DO7)
> **Architecture Module**: *nuevo* — eventos de gestión (post-MVP)
> **Status**: Esbozado — **no planificado**; a la espera de decisión de alcance del usuario
> **Origen**: petición del usuario 2026-07-28

## Overview

El **Comisario** (tu superior, la voz que ya te rescata cuando quiebras — Economía E9) te manda
**marrones con nombre y apellidos**: problemas que no puedes rechazar y que tienes que **encajar como
puedas**. No son penalizaciones numéricas invisibles: son **personas y decisiones**.

## El reto que pidió el usuario (2026-07-28) — literal

> *"como reto del comisario o bien evento aleatorio se podría poner la incorporación en un puesto de
> una persona con atributos muy malos, para darle algo de dificultad. por ejemplo te llega un mensaje
> del comisario y te dice que **ha cambiado de sitio a un funcionario porque no trabaja y quiere
> castigarlo en ese puesto durante unos meses**, hay que lidiar con eso y ver como se soluciona, ¿se
> abre otra mesa con más personal para cubrir eso? ¿se opta por tener la misma gente aunque no rinda
> ese funcionario?..."*

**El funcionario castigado**: llega impuesto, con atributos **muy malos** (rapidez/trato bajos), se
queda **unos meses** y **no se puede despedir** (lo ha puesto el Comisario). Su sueldo sale de tu
presupuesto.

**Las salidas que el jugador puede buscar** — y que son justo el interés del reto:
1. **Tragar**: dejarlo en la ventanilla y comerse la cola más lenta y la satisfacción más baja.
2. **Compensar**: montar otra ventanilla y contratar a alguien para absorber lo que él no hace
   (cuesta dinero de construcción **y** nómina).
3. **Esconderlo**: ponerlo donde menos daño haga (¿un puesto de poco tránsito? ¿ODAC en vez de Doc?) —
   *requiere que los puestos tengan cargas distintas, que ya pasa.*
4. *(Con Bienestar #13)* Vigilarlo: si además es de los que se van una hora de café, el marrón es doble.

## Otros retos del mismo saco (candidatos)

- **Inspección de la División**: aviso con N jornadas de antelación; si ese día la satisfacción está
  bajo X, sanción.
- **Baja larga de un titular**: se va tu mejor agente 3 meses; ¿cubres con el Oficial o contratas?
- **Recorte de presupuesto**: el retorno DGP baja un mes por decisión política.
- **Traslado forzoso al revés**: te quitan a un agente bueno para otra comisaría.

## Lo que ya existe (por qué esto es más barato de lo que parece)

- **`Agente`** ya tiene atributos 1-5 y `_tirada_sesgada()` para generarlos: un agente "muy malo" es
  `AgenteScript.new(nombre, tipo, rango, 1, 1, …)`.
- **Personal** ya sabe **incorporar** (`incorporar()`, la API de arranque del mundo), asignar a un
  puesto y despedir — habría que añadir un **flag de "no despedible"** con fecha de fin.
- **El bus + dispatcher ordenado** ya reparte `nuevo_mes` con prioridades: activar y caducar el castigo
  es exactamente lo que hace Documentación con los eventos de la División (story doc-004).
- **El catálogo es data-driven**: los retos serían `.tres` como los `EventoDivision`.
- **La UI de comunicados ya existe** (bandeja de la División en el panel H): un mensaje del Comisario
  entra por el mismo sitio.

## Preguntas de diseño abiertas (para el usuario)

- **¿Aleatorio o guionizado?** *Recomendación: **guionizado por hitos** al principio (el primer marrón
  siempre a la misma altura, para que todos lo vivan) y aleatorio después.* Los eventos de la División
  ya se decidieron deterministas por mes: conviene ser coherente.
- **¿Se puede rechazar?** *Recomendación: no — un marrón que se puede rechazar no es un marrón. Lo que
  sí puede haber es margen para **negociar** (aceptas al castigado a cambio de una plaza extra).*
- **¿Cuánto dura el castigo?** El usuario dice "unos meses" — 2-3 meses de campaña parece el rango.
- **¿El castigado se puede reformar?** ¿Sube su motivación si lo tratas bien (Bienestar #13)?
  *Sería un final feliz muy bonito para el arco.*

## Next Step

Decisión de alcance del usuario. **No está en ningún sprint.** Depende de nada crítico: se puede hacer
en cuanto se quiera, y gana mucho si va **después** de Bienestar #13 (el castigado caradura).
