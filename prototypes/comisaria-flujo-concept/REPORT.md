# Concept Prototype Report: Flujo de Oficinas (Documentación + ODAC)

> **Date**: 2026-07-19
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

Si el jugador organiza puestos y asigna agentes para atender la cola de ciudadanos
(Documentación + ODAC), sentirá la satisfacción de optimizar el flujo. Señal medible: en ~5
minutos ajusta activamente su oficina (abre/cierra puestos, reasigna agentes, gestiona presupuesto
y horarios) para reducir la cola, en vez de mirar pasivamente.

---

## Riskiest Assumption Tested

La suposición más arriesgada del concepto: **que gestionar una cola de personas es divertido por
sí solo**, sin acción ni combate. Si esto no enganchaba, el juego entero se caía. **Se confirmó
que sí engancha** — el jugador no solo gestionó activamente, sino que fue proponiendo mecánicas
nuevas mientras jugaba (señal fuerte de implicación).

---

## Approach

Prototipo HTML de un solo archivo, abrible con doble clic (sin instalar nada), iterado en 4
versiones a lo largo de la sesión según el feedback del jugador.

**Path chosen:** HTML
**Reason for path:** La pregunta era "¿son interesantes las decisiones de gestión?" (una pregunta
de reglas/sistemas, no de *feel* de acción), así que el navegador no falsea el resultado. Además
permitía construirlo entero y que el jugador lo probara sin montar un proyecto de Godot.

**Shortcuts taken (intentional):**
- Arte = rectángulos y puntos de colores (sin isométrico ni personajes).
- Valores hardcodeados, sin guardado, sin menús, sin sonido.
- Una sola "oficina" (nivel de subinspector), sin la comisaría completa ni la escalera de carrera.

---

## Result

El jugador probó las 4 versiones y su veredicto fue directo: **"me ha parecido divertido"**.
Confirmó activamente la hipótesis gestionando puestos, tipos y horarios. Observaciones clave:

- **v1**: bucle base (2 áreas, agentes, presupuesto, paciencia, objetos de sala). El jugador lo
  encontró divertido; el volumen alto de gente fue lo que más "vida" le dio.
- **v2**: al añadir reloj real, horarios y tiempos realistas, el ritmo se percibió **bajo** —
  porque Documentación pasaba cerrada la mayor parte del reloj.
- **v3/v4**: se aclaró el concepto **demanda vs. capacidad** (más puestos NO traen más gente) y se
  añadió la política **cita previa vs. sin cita** + subida de demanda, recuperando el ritmo animado.

Durante el playtest, el jugador propuso espontáneamente varias mecánicas nuevas (ver "If Proceeding"),
lo que indica que el bucle central invita a pensar como gestor — justo el objetivo.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | N/A (HTML one-shot, luego 4 iteraciones de diseño) |
| Prototype duration | ~1 sesión |
| Playtesters | 1 interno (el diseñador/jugador) |
| Feel assessment | "Divertido"; el ritmo de llegada de gente es el principal driver de diversión; con horarios cerrados se sentía vacío hasta subir demanda + política sin cita |
| Hypothesis verdict | **CONFIRMED** |

---

## Recommendation: PROCEED

El prototipo confirmó la apuesta central: gestionar el flujo de ciudadanos es divertido por sí
solo, y el concepto genera de forma natural decisiones interesantes (dinero vs. obligación,
horarios vs. coste de peonadas, cita vs. volumen). Además, el ejercicio destapó varias mecánicas
valiosas que enriquecen el diseño. Se recomienda **proceder** al diseño formal del juego,
llevando estos aprendizajes a los GDDs.

---

## If Proceeding

- **Core tuning values discovered:**
  - Trámites de Documentación: **DNI 12€/12 min · Pasaporte 30€/15 min · TIE 18€/15 min**.
  - **Puestos separados**: DNI/Pasaporte y TIE son distintos (un puesto de TIE no hace DNI).
  - Horario base Documentación **09:00–14:30**; **peonada** de tarde 16:00–20:00 y apertura 08:00
    con **coste de horas extra ≈ 15€/hora por funcionario** para toda hora fuera de 09:00–14:30.
  - El **volumen de llegada** (demanda) es el principal driver de diversión; debe sentirse animado.

- **Assumptions confirmed:**
  - El bucle de "flujo de personas" tipo Two Point, aterrizado en la comisaría, es divertido.
  - La tensión **dinero (Documentación) vs. obligación (ODAC)** funciona como motor.
  - Empezar pequeño (una oficina, subinspector) es un buen MVP.

- **Assumptions disproved / matizadas:**
  - Meter horarios "realistas" sin más **mató el ritmo**; hay que compensar con volumen de demanda
    y/o política de atención. El realismo debe servir a la diversión (pilar 1), no frenarla.

- **Emergent mechanics (a formalizar en GDDs):**
  1. **Política de atención: cita previa vs. sin cita.** Con cita = flujo controlado a capacidad
     (tranquilo, menos ingresos); sin cita = alto volumen y caos (más ingresos, más riesgo).
  2. **Sistema de Horarios y peonadas.** Horarios configurables (idealmente por servicio: p. ej.
     TIE 08:00, DNI 09:30), turnos de tarde y sábados con coste de horas extra (15€/h/funcionario).
  3. **Puestos especializados y reconfigurables en caliente** (ODAC por tipo de denuncia:
     permisos de viaje, estafas y lesiones, pérdidas/sustracciones, VioGén prioritaria).
  4. **Paciencia de los ciudadanos** + **objetos de sala de espera** (cafetera, vending, revistas,
     aire acondicionado, asientos) que frenan su pérdida y algunos generan ingresos.
  5. **Ciclo día/noche**: de noche cierra Documentación y sube la criminalidad (más denuncias).
  6. **Estructura por brigadas** (Seguridad Ciudadana/Zetas, Policía Judicial→ODAC, Información,
     Científica, Extranjería; Documentación cuelga de Secretaría) como esqueleto de la escalera de carrera.

**Next steps:**
1. `/art-bible` — definir la identidad visual 2D isométrica (serio, no caricatura).
2. `/map-systems` — descomponer el juego en sistemas (incluyendo los emergentes de arriba).
3. `/design-system [sistema]` — GDD por sistema, empezando por Documentación y ODAC, usando estos
   valores en las secciones de Fórmulas y Tuning Knobs.
4. `/design-review design/gdd/game-concept.md` — validar el concepto con lo aprendido.

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  Que "realismo" y "diversión" pueden chocar: los horarios realistas, mal calibrados, vaciaron la
  pantalla. La solución no fue quitar realismo, sino añadir palancas (demanda, cita/sin cita) que
  lo convierten en decisión. Refuerza el pilar "Realismo con alma".

- **What surprised us that didn't show up in the brainstorm?**
  El propio jugador generó mecánicas de sistema (cita previa, peonadas, puestos por tipo) al jugar.
  El prototipo funcionó no solo como validación, sino como **motor de descubrimiento de diseño**.
  También quedó claro el concepto **demanda vs. capacidad**, que habrá que enseñar bien al jugador.

- **What would we test differently next time?**
  Fijar el ritmo/volumen "divertido" antes de añadir capas realistas (horarios), para no confundir
  "falta de realismo" con "falta de ritmo". Y limitar el nº de iteraciones sobre un prototipo
  desechable: cumplió su función tras confirmar la diversión.

---

> *Prototype code location: `prototypes/comisaria-flujo-concept/`*
> *This code is throwaway. Never refactor into production.*
