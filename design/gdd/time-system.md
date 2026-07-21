# Sistema de Tiempo (reloj, día/noche, turnos)

> **Status**: Reviewed (/design-review 2026-07-19 APPROVED; **re-revisión 2026-07-22 tras calendario semanal: APPROVED**)
> **Author**: manu.rdo + Claude (game-designer / systems-designer)
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" (sostiene el Pilar 4 — "Tus decisiones")

## Summary

El Sistema de Tiempo es el reloj maestro del juego: hace avanzar la jornada en **tiempo real con
pausa y velocidades**, la divide en turnos (mañana, tarde, noche) y marca el ciclo día/noche. Casi
todos los demás sistemas —flujo de colas, demanda, horarios, paciencia— leen su hora para saber qué
hacer. Su función de diseño es **dar ritmo**: que la oficina se sienta viva y que la jornada genere
presión.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Ninguna (es la base)`

## Overview

El Sistema de Tiempo es el corazón que marca el pulso de la comisaría. El juego transcurre en
**tiempo real con pausa**: un reloj interno avanza la hora del día a una escala configurable (varios
minutos de juego por cada segundo real), y el jugador puede **pausar y cambiar la velocidad** (p. ej.
1×/2×/3×), como un director que controla el ritmo de su jornada. Ese reloj gobierna tres capas que
todo lo demás consulta: la **hora del día** (que abre y cierra servicios como Documentación), las
**fases o turnos** (mañana → tarde → noche) y el **ciclo día/noche** (de noche baja la afluencia de
ciudadanos y sube la criminalidad). A nivel de datos es la capa base sin dependencias —Flujo, Demanda,
Paciencia, Horarios y casi todos los sistemas se enganchan a sus eventos—, pero a nivel de sensación
es lo que hace que la comisaría esté *viva*: el prototipo confirmó que **el ritmo al que corre el
reloj es el principal motor de diversión**, la diferencia entre una oficina que bulle y una pantalla
vacía. Existe porque sin un tiempo compartido y bien acompasado no hay colas que crezcan, ni jornada
que optimizar, ni tensión de "llegar a la hora de cierre": el tiempo es lo que convierte una lista de
ciudadanos en **una jornada que gestionar**.

## Player Fantasy

**Fantasía:** ser quien marca el pulso de la comisaría — un director en la sala de mando que puede
*parar el mundo para pensar*, acelerarlo cuando todo fluye, y sentir cómo la jornada avanza con vida
propia.

El tiempo se vive en dos capas:

- **Control directo (poder de director):** pausar es tu botón de respirar — congelas la sala, lees la
  situación, reorganizas puestos y agentes con calma, y reanudas. Acelerar (2×/3×) es el placer de ver
  tu comisaría bien engrasada zumbar sin cuellos de botella. La fantasía aquí es de *dominio sereno*:
  nunca vas a rebufo del reloj; tú decides cuándo correr y cuándo pensar.
- **Infraestructura que se vive (la comisaría respira):** aunque no toques nada, el día pasa y la
  comisaría cambia de piel. La mañana abre con la avalancha de Documentación; la tarde afloja; cae la
  noche, se apagan las ventanillas de DNI, el ambiente se vuelve más tenso y empiezan a entrar
  denuncias de madrugada. El jugador no "usa" esta capa: la *siente*, como quien nota que en su
  edificio ya es de noche.

**El momento a anclar:** son las 14:20, faltan diez minutos para que cierre Documentación y aún hay
ocho personas en cola. El reloj corre. El jugador siente la presión —¿abro otra ventanilla y pago la
peonada, o los dejo marchar insatisfechos?— y esa tensión de "llegar a la hora" es lo que convierte
una cola en una *decisión*. El tiempo no es un cronómetro de fondo: es el que pone en juego cada
decisión de gestión.

**Referencia de sensación:** el control de velocidad/pausa de los tycoon de gestión (Prison Architect,
Two Point Hospital, RimWorld) — la sensación de "dios del ritmo" que observa su sistema vivo y decide
cuándo intervenir. **Anti-referencia:** NO debe sentirse como un reloj de examen que agobia sin dejarte
pausar a pensar; la pausa siempre está para desactivar el estrés injusto.

## Detailed Design

### Core Rules

**1. Modelo de tiempo**
1. El juego transcurre en **tiempo real con pausa**. Un reloj interno mantiene la hora del día
   (HH:MM), la **semana** de campaña y la fecha (**Mes · Semana N**, ver regla 7).
2. El tiempo solo avanza **hacia delante**. No se puede rebobinar ni fijar una hora arbitraria.
3. El reloj avanza **acumulando tiempo real (`delta`)**, no contando fotogramas, para ser idéntico a
   60 FPS o si baja el rendimiento (determinismo).

**2. Velocidades y pausa**
1. Cuatro estados de velocidad: **Pausa, 1×, 2×, 3×**.
2. En **Pausa** el tiempo se congela del todo (no llega gente, no decae la paciencia, no corre la
   hora), pero el jugador **sí puede interactuar**: construir, asignar agentes, abrir/cerrar puestos,
   consultar información. Es el "botón de pensar".
3. **1× / 2× / 3×** multiplican la velocidad del reloj (y de todo lo que depende del tiempo). 1× es el
   ritmo base; 3× para horas tranquilas.
4. Cambiar de velocidad es **instantáneo** y sin coste ni penalización.
5. Al **empezar una partida nueva**, la velocidad es **1×** (no Pausa), para que la comisaría arranque
   viva. Al **cargar** una partida guardada, arranca en **Pausa (0×)** —sea cual sea la velocidad con
   que se guardó— para que el jugador se sitúe. *(Tuning.)*

**3. Escala del reloj**
1. A 1×, el reloj avanza a una **escala configurable** de minutos-de-juego por segundo-real
   (`escala_tiempo`). Es el **mando maestro del ritmo** y el valor más sensible del juego (el
   prototipo demostró que de él depende sentir la oficina viva o vacía). El valor y su cálculo se
   fijan en **Fórmulas** y **Tuning Knobs**.
2. 2× y 3× multiplican esa escala base por 2 y por 3.

**4. Estructura del día (turnos)**
1. Cada día se divide en tres **turnos de 8 horas**, según el **horario a turnos real del CNP** (el de
   los servicios 24h como ODAC y Seguridad Ciudadana). Límites por defecto (*tuning*):
   - **Mañana:** 07:00 – 15:00
   - **Tarde:** 15:00 – 23:00
   - **Noche:** 23:00 – 07:00 (del día siguiente)
2. El turno es un dato **derivado de la hora**: el sistema siempre sabe en qué turno está y **avisa
   cuando cambia**.
3. Los turnos son la **estructura gruesa del día**; no abren/cierran servicios ni asignan personal por
   sí mismos. Los **horarios finos de trabajo** —horario a turnos (24h rotativo), **complementario**
   (L–V 08:00–14:30 y 14:30–20:00, el más común, p. ej. Documentación) y **guardias** (localizables de
   noche para Judicial/Científica/Extranjería)— son propiedad del **GDD de Horarios y Personal**, que
   leen este reloj. El Tiempo solo provee hora/turno/fecha. *(Ver Interacciones.)*

**5. Ciclo día/noche**
1. El sistema expone un estado binario **`es_de_noche`**, derivado de la hora: de noche durante el
   turno **Noche (23:00–07:00)**, de día el resto. *(MVP: coincide con el turno Noche; más adelante
   cabría una transición visual amanecer/anochecer sin cambiar esta regla.)*
2. El día/noche gobierna el **ambiente** (luz, sonido) y es un dato que otros usan para modular su
   comportamiento (la Demanda baja de noche; la criminalidad sube). El Sistema de Tiempo **solo provee
   el estado**; no calcula criminalidad ni demanda.

**6. Horas de baja actividad (no vacías)**
1. El reloj se simula **continuo las 24h**; **no hay salto automático** que elimine horas. Es
   deliberado: **ODAC (24h)** mantiene actividad de noche, y la noche será jugable para otras unidades
   (Seguridad Ciudadana) en el futuro. Saltarla lo rompería.
2. El problema de ritmo del prototipo se resuelve con dos palancas, no saltando tiempo: (a) la noche
   **nunca está del todo muerta** — ODAC recibe un goteo de denuncias *(la franja 00:00–07:00 se reduce
   por `mult_nocturno_odac`; ≈10 denunciantes en Pozuelo, escalable con la población — propiedad del GDD
   de Generación de Demanda)*; y (b) el jugador dispone de
   **3×** para adelantar las franjas tranquilas.
3. *(Candidato a Open Question:)* si en playtest la noche aún se siente lenta, se evaluará una ayuda
   **opcional y a petición** de "adelantar hasta la próxima apertura de Documentación" (nunca
   automática) que respete el goteo nocturno de ODAC.

**7. Fin de jornada / avance del calendario (modelo semanal)**
1. Cada **jornada de 24 h** (al cruzar **las 00:00**) **representa una semana** del calendario: avanza la
   **Semana** (el evento de fin de jornada sigue siendo `nuevo_dia`). **4 semanas = 1 mes**
   (`jornadas_por_mes = 4`, tuning); **48 jornadas = 1 año**. *(Decisión de ritmo 2026-07-21: comprime el
   calendario para vivir la estacionalidad en una sesión — estilo RimWorld/Stardew; a 3× un año ≈ 96 min.)*
2. La fecha se muestra como **"Mes · Semana N"** (N = 1..4). Al completar la 4ª semana de un mes avanza el
   **mes** (`nuevo_mes`) y la Semana vuelve a 1; al completar Diciembre, avanza el **año**.
3. El sistema expone **Mes**, **Semana (1–4)** y **año** para que otros gestionen ciclos (Economía cierra el
   **objetivo mensual** cada `nuevo_mes` = 4 jornadas; Demanda aplica el **perfil estacional** por mes,
   DG13). *(El "día de la semana L–D" se difumina —cada jornada ES una semana—; la variación intra-semana la
   representa `mult_dia_semana` de Demanda como carga media de esa jornada.)*

### States and Transitions

El Sistema de Tiempo tiene **una máquina de estados que controla el jugador** (la velocidad) y
**estados derivados del reloj** que transicionan solos.

**A. Estados de velocidad (los controla el jugador)**

| Estado | Entrada | Salida | Comportamiento |
|--------|---------|--------|----------------|
| **Pausa** | Pulsar Pausa / tecla dedicada; **al cargar una partida guardada**; *(opcional/futuro)* un evento importante pide autopausa | Elegir cualquier velocidad de juego | Reloj y simulación **congelados**; gestión permitida |
| **1×** | Seleccionar 1×; por defecto al **empezar partida nueva**; al reanudar si 1× era la última | Cambiar a otra velocidad o Pausa | Reloj a **escala base** |
| **2×** | Seleccionar 2× | Cambiar a otra velocidad o Pausa | Reloj a **2×** la escala base |
| **3×** | Seleccionar 3× | Cambiar a otra velocidad o Pausa | Reloj a **3×** la escala base |

**Reglas de transición:**
- Se puede pasar de **cualquier estado a cualquier otro directamente** (no hay que subir 1×→2×→3× en
  orden). Es un selector, no una rueda secuencial. *(La UI puede añadir +/− para subir/bajar de marcha.)*
- **Reanudar desde Pausa** vuelve a la **última velocidad de juego usada** (pausas en 3× → reanudas en
  3×). *(Tuning: podría forzarse 1×.)* Tras **cargar** una partida (que arranca en Pausa) no hay
  velocidad previa en la sesión: reanudar va a **1×**.
- *(Opcional/futuro)* **Autopausa** ante ciertos eventos (dilema de influencia, fin de objetivo) si el
  jugador la activa en opciones. **No es del MVP**; se deja como gancho.

**B. Estados derivados del reloj (automáticos)**

No los controla el jugador: se calculan de la hora y transicionan solos, **emitiendo un aviso** al
cruzar el límite.

| Estado | Rango (default *tuning*) | Transición | Aviso |
|--------|--------------------------|------------|-------|
| Turno **Mañana** | 07:00 – 15:00 | A las 15:00 → Tarde | `cambio_de_turno(Tarde)` |
| Turno **Tarde** | 15:00 – 23:00 | A las 23:00 → Noche | `cambio_de_turno(Noche)` |
| Turno **Noche** | 23:00 – 07:00 | A las 07:00 → Mañana | `cambio_de_turno(Mañana)` |
| **Día** (`es_de_noche=false`) | 07:00 – 23:00 | A las 23:00 → Noche | `cambio_dia_noche(noche)` |
| **Noche** (`es_de_noche=true`) | 23:00 – 07:00 | A las 07:00 → Día | `cambio_dia_noche(dia)` |

**Notas:**
- En **Pausa** ninguna de estas transiciones ocurre (el reloj no corre).
- Los cambios se emiten **una sola vez** al cruzar el límite, aunque el juego vaya a 3× (no se "saltan"
  por ir rápido → ver Edge Cases).
- La **fecha** (semana → **Mes · Semana N**, regla 7) avanza al cruzar **00:00**, con su propio aviso
  `nuevo_dia`.

### Interactions with Other Systems

**Principio rector — fuente única de tiempo:** el Sistema de Tiempo es **la única fuente de la hora**.
Ningún otro sistema mantiene su propio reloj; todos leen este. Así se evita la desincronización. El
Tiempo **no depende de nadie**: solo recibe *input del jugador* (velocidad/pausa) y *carga de partida*.

**Qué consumen los demás (el Tiempo provee, ellos deciden qué hacer):**

| Sistema | Qué lee del Tiempo | Mecanismo | Reparto |
|---------|--------------------|-----------|---------|
| **Flujo y Colas** | tiempo transcurrido (mover gente, avanzar atención); pausa lo congela | *pull* `delta` + estado pausa | Tiempo provee; Flujo consume |
| **Generación de Demanda** | turno, `es_de_noche`, hora, **semana/mes** → perfil de llegadas (incl. estacional) | *push* (`cambio_de_turno`, `nuevo_dia`, `nuevo_mes`) + *pull* hora | Tiempo da el reloj; Demanda define **cuánta** gente |
| **Paciencia y Satisfacción** | tiempo de juego transcurrido para decaer; pausa la congela | *pull* `delta` + estado pausa | Tiempo provee; Paciencia define la curva |
| **Documentación** | hora → abre/cierra (horario complementario) | *pull* hora + *push* `hora_cambiada` | Tiempo da la hora; Documentación define **su** horario |
| **ODAC** | hora/turno (24h; dotación por turno) | *pull* + *push* `cambio_de_turno` | Tiempo provee; ODAC define su operativa |
| **Horarios y Peonadas** | hora, **semana/mes**, turno → asignación y coste de horas extra | *pull* + *push* | Tiempo da reloj/fecha; Horarios define patrones (con calendario semanal) y costes |
| **Economía / Presupuesto** | día/mes → ciclo de presupuesto | *push* `nuevo_dia` / `nuevo_mes` | Tiempo da la fecha; Economía define el ciclo |
| **Presión e Influencia** | fecha → temporizadores de dilemas (p. ej. "coche 3–4 días") | *push* `nuevo_dia` + *pull* | Tiempo provee; Influencia define eventos |
| **UI / HUD** | hora, turno, fecha, velocidad, pausa → mostrarlos | *pull* + *push* (todas las señales) | Tiempo provee; UI presenta |
| **Feedback / Audio** | `cambio_dia_noche`, `cambio_de_turno` → ambiente (luz/sonido) | *push* | Tiempo provee estado; Audio/VFX reaccionan |
| **Guardado y Carga** | serializa/restaura el estado del reloj (hora, día, fecha; al cargar arranca en Pausa) | *pull* al guardar / *set* al cargar | Guardado serializa; Tiempo expone getters/restauración |

**Lo único que entra al Tiempo:**
- **Input del jugador** (vía UI): comandos de velocidad/pausa. Su único control externo.
- **Carga de partida:** re-sitúa el reloj en el punto guardado. *(No contradice "solo avanza hacia
  delante": cargar no es rebobinar la partida en curso, es reanudar otra.)*

*(La lista concreta de señales —`hora_cambiada`, `cambio_de_turno`, `cambio_dia_noche`, `nuevo_dia`,
`nuevo_mes`, `velocidad_cambiada`, `juego_pausado`/`reanudado`— se recoge en Tuning Knobs; el "cómo"
técnico irá a un ADR.)*

## Formulas

> `escala_tiempo` es el valor más sensible del juego (driver nº1 del ritmo). **Default = 4**; rango
> seguro **3–12**. Retuneable en playtest.

### F1 · `escala_tiempo` — velocidad base del reloj

Define cuántos minutos de juego avanza el reloj por cada segundo real a velocidad 1×. La duración real
de un día se deriva de ella:

```
duracion_dia_real = MINUTOS_DIA / escala_tiempo / multiplicador_velocidad
```

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `MINUTOS_DIA` | int (const) | 1440 | Minutos de juego en un día de 24 h |
| `escala_tiempo` | float | 3.0 – 12.0 | Min de juego por segundo real a 1× (**default 4**) |
| `multiplicador_velocidad` | int | 1, 2, 3 | Factor de velocidad (Pausa = 0 detiene el reloj) |
| `duracion_dia_real` | float | ~40 s – 8 min | Duración real de un día de 24 h |

**Rango de salida:** entre 40 s (escala 12, 3×) y 8 min (escala 3, 1×). No se clampa; el rango seguro
de `escala_tiempo` es la protección.

**Ejemplo (default `escala_tiempo` = 4):**

| Velocidad | Cálculo | Duración de un día (24 h) |
|-----------|---------|----------------------------|
| 1× | 1440 / 4 / 1 = 360 s | **6 min 00 s** |
| 2× | 1440 / 4 / 2 = 180 s | **3 min 00 s** |
| 3× | 1440 / 4 / 3 = 120 s | **2 min 00 s** |

Ventana de Documentación (390 min de juego, 08:00–14:30) a 1×: `390 / 4 = 97,5 s ≈ 1 min 38 s`.

**Por qué 4:** a 1× la jornada dura ~6 min, así que caben varios días en una sesión de 30–90 min, pero
el "pico" de la mañana (Documentación abierta) respira ~1 min 22 s a 1× —suficiente para gestionar la
cola con tensión sin agobiar—, y el jugador puede pausar para pensar y usar 3× en las horas tranquilas.
Por debajo de 3 la comisaría se siente en cámara lenta (el fallo del prototipo); por encima de 12 no da
tiempo a reaccionar a los eventos.

### F2 · Avance del reloj por frame

```
minutos_juego += escala_tiempo × multiplicador_velocidad × delta_real
```

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `escala_tiempo` | float | 3.0 – 12.0 | Ver F1 |
| `multiplicador_velocidad` | int | 0, 1, 2, 3 | 0 = Pausa (incremento nulo) |
| `delta_real` | float | 0 – ~0.5 s | Segundos reales desde el último frame (del motor) |
| `minutos_juego` | float | [0, 1440) | Posición en el día; `mod 1440` al cruzar 00:00 (dispara `nuevo_dia`) |

**Rango de salida:** incremento por frame siempre ≥ 0 (Pausa = 0). El acumulador se mantiene en
[0, 1440) con módulo 1440 al cruzar medianoche.

**Ejemplo (1 frame de 1/60 s a 2×, escala 4):** `Δ = 4 × 2 × (1/60) = 0,133 min ≈ 8 s de juego por
frame`. En 1 s real a 2× → `4 × 2 = 8` min de juego. ✔

*(Implementación: acumular en float antes de convertir a HH:MM evita errores de truncado. El "cómo"
—Autoload, `_process` vs `_physics_process`— irá a un ADR.)*

### F3 · Auxiliares

**Hora ↔ minutos del día:**
```
minutos_del_dia = hora × 60 + minuto
hora   = floor(minutos_del_dia / 60)
minuto = minutos_del_dia mod 60
```
Ejemplo: `minutos_del_dia = 567` → 09:27.

**Turno según minutos del día** (origen 00:00):

| Turno | Inicio | Fin | Rango en minutos |
|-------|--------|-----|------------------|
| Mañana | 07:00 | 15:00 | `[420, 900)` |
| Tarde | 15:00 | 23:00 | `[900, 1380)` |
| Noche | 23:00 | 07:00 | resto: `[1380, 1440) ∪ [0, 420)` |

```
turno = MAÑANA  si 420 ≤ min_dia < 900
        TARDE   si 900 ≤ min_dia < 1380
        NOCHE   en cualquier otro caso
```
Noche es el "caso restante" porque cruza medianoche. Ejemplo: `min_dia = 1395` (23:15) → NOCHE.

*(Ilustrativo — propiedad del GDD de Documentación:)* un servicio decide si está abierto leyendo el
reloj, p. ej. Documentación: `en_horario = (480 ≤ min_dia < 870)` → 08:00–14:30.

## Edge Cases

Formato: **Si [condición]: [qué pasa exactamente]. [por qué].**

- **Si el reloj cruza un límite de turno/día/noche a alta velocidad (un frame lo pasa de largo, p. ej.
  de 899,5 a 900,6):** el evento (`cambio_de_turno`, etc.) se dispara igualmente **una vez**,
  detectando el *cruce* del umbral, no la igualdad exacta con el minuto. *Nunca se compara "hora == X";
  se comprueba "hora anterior < X ≤ hora nueva".*
- **Si un frame trae un `delta_real` grande (tirón de lag) que cruza varios límites de golpe (p. ej.
  pasa de 22:59 a 00:02, cruzando 23:00 y 00:00):** se disparan **todos** los eventos cruzados, **en
  orden** (`cambio_de_turno` → `cambio_dia_noche` → `nuevo_dia`). *Determinismo: Demanda y Economía no
  pueden perderse un cambio de día.*
- **Si la ventana pierde el foco o hay un parón largo (alt-tab, arrastrar la ventana, breakpoint):**
  `delta_real` se **limita a un máximo por frame** (p. ej. 0,5 s) antes de avanzar el reloj, así que al
  volver **el tiempo NO da un salto** de minutos/horas: reanuda suave. *Evita que un alt-tab de 30 s
  adelante horas de juego.* *(Opción de tuning: además, autopausa al perder el foco.)*
- **Si es medianoche (00:00), que cae dentro del turno Noche (23:00–07:00):** se dispara `nuevo_dia`
  (avanza la fecha: semana/mes, regla 7) **pero NO `cambio_de_turno`** (sigue siendo Noche). *La fecha y el
  turno son independientes; un mismo instante puede cambiar el día sin cambiar el turno.*
- **Si se carga una partida guardada:** el reloj se **fija** al estado guardado (hora, día, fecha) y la
  partida **arranca en Pausa (0×)** —sea cual sea la velocidad guardada— para dar tiempo a situarse;
  **no se disparan eventos retroactivos**. Los sistemas leen el estado actual al cargar. *Cargar no es
  "reproducir" el tiempo, solo situarlo.*
- **Si el juego está en Pausa:** ningún evento de tiempo se dispara (el reloj no corre). Al
  **reanudar**, se retoma la **última velocidad de juego** usada. *La pausa nunca "pierde" ni "acumula"
  eventos.*
- **Si el jugador cambia de velocidad (p. ej. 1×→3×):** solo cambia el multiplicador para los
  siguientes frames; **no se recalcula ni se pierde/gana tiempo** ya transcurrido. *Cambiar de marcha
  es instantáneo y neutro.*
- **Si `escala_tiempo` llega con un valor inválido (≤ 0, o fuera de 3–12 por mal dato/mod):** se
  **clampa al rango seguro [3, 12]** y se registra un aviso; nunca se permite un reloj congelado (0) o
  hacia atrás (negativo). *Un dato corrupto no debe romper el motor del juego.*
- **Si el jitter de float acerca el acumulador a un límite ya cruzado:** cada límite se dispara **una
  sola vez por cruce**, guardando el "último límite disparado". *Evita eventos duplicados por
  imprecisión decimal.*
- *(Nota de diseño, no es fallo del reloj):* **si el jugador puede jugar toda la partida a 3× sin
  problemas**, es señal de que la **dificultad/demanda de otros sistemas está baja** (ajuste de
  Demanda/Paciencia), no un defecto del Sistema de Tiempo.

## Dependencies

**Este sistema depende de:** *Nada.* Es la capa **Foundation raíz**. Solo recibe **input del jugador**
(velocidad/pausa vía UI/Input) y **estado de carga** (Guardado lo restaura). Ninguno es dependencia de
diseño: el reloj es autónomo y testeable en aislamiento.

**Dependen de este sistema:**

| Sistema | Dirección | Tipo | Naturaleza |
|---------|-----------|------|------------|
| Flujo de Personas y Colas | depende del Tiempo | Hard | Avanza movimiento/atención con el `delta`; Pausa lo congela |
| Generación de Demanda | depende del Tiempo | Hard | Perfil de llegadas por turno/hora/`es_de_noche`; escucha `cambio_de_turno`, `nuevo_dia` |
| Paciencia y Satisfacción | depende del Tiempo | Hard | Decaimiento por tiempo de juego transcurrido; Pausa lo congela |
| Documentación | depende del Tiempo | Hard | Abre/cierra leyendo la hora (horario complementario) |
| ODAC | depende del Tiempo | Hard | Dotación por turno; abierta 24h |
| Horarios y Peonadas | depende del Tiempo | Hard | Asignación y coste de horas extra por hora, turno y semana |
| Economía / Presupuesto | depende del Tiempo | Hard | Ciclo de presupuesto por día/mes (`nuevo_dia`/`nuevo_mes`) |
| Presión e Influencia | depende del Tiempo | Hard | Temporizadores de dilemas por fecha |
| UI / HUD | depende del Tiempo | Hard | Muestra hora, turno, fecha, velocidad, pausa |
| Feedback / Audio | depende del Tiempo | Soft | Ambiente día/noche y avisos de turno (mejora, no imprescindible) |
| Guardado y Carga | depende del Tiempo | Hard | Serializa/restaura el estado del reloj |

**Consistencia bidireccional:** estas dependencias están registradas en `design/gdd/systems-index.md`.
Los GDD dependientes del MVP ya escritos (Flujo, Demanda, Paciencia, Documentación, ODAC, Economía, UI)
listan "depende de: Sistema de Tiempo" en su propia sección de Dependencias. Los aún no escritos
(Horarios #13, Presión e Influencia #16, Guardado #20) lo harán al redactarse.

## Tuning Knobs

| Parámetro | Default | Rango seguro | Si ↑ (sube) | Si ↓ (baja) |
|-----------|---------|--------------|-------------|-------------|
| `escala_tiempo` (min-juego/seg-real a 1×) | **4** | 3–12 | Día más corto/rápido: más días/sesión, menos margen para reaccionar | Día más largo: más control y "chicha", riesgo de cámara lenta |
| `multiplicadores_velocidad` (marchas) | {1, 2, 3} | hasta 1–4 marchas | Marcha extra 4× para saltar tiempos muertos; riesgo de jugar todo en turbo | Menos capacidad de acelerar horas tranquilas |
| `inicio_mañana` | 07:00 (420) | 00:00 – `inicio_tarde` | Mañana empieza más tarde (Noche más larga) | Mañana antes (Noche más corta) |
| `inicio_tarde` | 15:00 (900) | `inicio_mañana` – `inicio_noche` | Mañana más larga, Tarde más corta | Mañana más corta, Tarde más larga |
| `inicio_noche` | 23:00 (1380) | `inicio_tarde` – 24:00 | Tarde más larga, Noche empieza más tarde | Noche antes, día operativo más corto |
| `velocidad_inicio` (partida nueva) | 1× | {Pausa, 1×, 2×, 3×} | (→Pausa) arranca en calma; el jugador elige cuándo empezar | (1×) la comisaría arranca viva ya |
| `velocidad_al_cargar` | Pausa | {Pausa, 1×} | (→1×) al cargar arranca en marcha (menos margen para situarse) | (Pausa) arranca parado para reorientarse |
| `delta_max_por_frame` (clamp anti-salto) | 0,5 s | 0,1 – 1,0 s | Permite saltos de tiempo mayores tras un parón (riesgo de "salto") | Reanuda más suave; tras stalls largos el reloj puede ir con retraso |
| `reanudar_en` | última velocidad | {última, 1×} | *(enum)* forzar 1× tras pausa | *(enum)* |
| `autopausa_al_perder_foco` | off | {off, on} | (on) pausa al minimizar/alt-tab; no pierdes progreso ausente | (off) el juego sigue con `delta` clampado |
| `jornadas_por_mes` (semanas/mes) | **4** | 1–8 | ↑ meses/estaciones más largos (año más lento) | ↓ calendario más rápido (año más corto). 48 jornadas/año a default 4 |

**Restricción:** los límites de turno deben cumplir `inicio_mañana < inicio_tarde < inicio_noche`,
todos en [0, 1440) y sin turnos de longitud cero.

**Interacciones entre knobs:** `escala_tiempo` × `multiplicadores` definen la velocidad efectiva;
mover los límites de turno **reconfigura las ventanas de Demanda** (afecta al GDD de Demanda). *(Los
horarios de cada servicio —Documentación 08:00–14:30, etc.— NO son knobs de este sistema: viven en sus
GDDs.)*

## Visual/Audio Requirements

| Evento | Visual | Audio | Prioridad |
|--------|--------|-------|-----------|
| Transición día↔noche | Cambio gradual de iluminación/paleta ambiente (cálida de día → tenue/fría de noche), según art bible | Ambiente vira (día: bullicio; noche: más silencio) | Media |
| Cambio de turno | Toast breve + parpadeo del indicador de turno | "Tick"/aviso sutil | Baja |
| Cambio de velocidad | Botón activo resaltado | Clic corto | Baja |
| Pausa | Atenuación sutil + rótulo "PAUSA" | Silencio/aviso corto | Media (claridad) |

*(El reloj en sí es dato; esto es ambiente. La paleta día/noche se especifica en el art bible.)*

> 📌 **Asset Spec** — Con estos requisitos definidos, tras aprobar el art bible se puede ejecutar
> `/asset-spec system:time-system` para generar descripciones y prompts de los assets ambientales
> (paleta día/noche, icono de turno, iconos de velocidad/pausa).

## UI Requirements

| Información | Dónde | Frecuencia | Condición |
|-------------|-------|------------|-----------|
| Hora actual (HH:MM) | HUD (barra superior) | cada tick | siempre visible |
| Fecha **Mes · Semana N** (+ año) | HUD | al cambiar de semana/mes | siempre |
| Turno actual (Mañana/Tarde/Noche) + icono día/noche | HUD | al cambiar de turno | siempre |
| Controles de velocidad: **Pausa / 1× / 2× / 3×** (el activo resaltado) | HUD | al pulsar | siempre |
| Aviso breve (toast) al cambiar de turno o día/noche | HUD (transitorio) | en el evento | opcional/tuning |

**Interacción:** dirigida por ratón (clic en los botones). **Atajos de teclado** como acelerador:
`Espacio` = Pausa/reanudar; `1`/`2`/`3` = velocidades. *(Sin interacciones solo-hover, por si se añade
gamepad más adelante — ver preferencias técnicas.)*

> 📌 **UX Flag — Sistema de Tiempo**: este sistema aporta HUD (reloj + controles de velocidad/pausa).
> En Pre-Producción, ejecutar `/ux-design` para el HUD (reloj y barra de velocidad) **antes** de
> escribir epics. Las stories de UI deben citar `design/ux/hud.md`, no este GDD directamente.

## Cross-References

| Este documento referencia | GDD destino *(previsto)* | Elemento | Naturaleza |
|---------------------------|--------------------------|----------|------------|
| Goteo nocturno de ODAC (`mult_nocturno_odac`, ≈10 en Pozuelo, 00:00–07:00) como razón para no saltar la noche | `demand-generation.md` ✅ | tasa de llegada nocturna | Data dependency |
| Ventana 08:00–14:30 como ejemplo ilustrativo | `documentation.md` ✅ | horario de apertura | Rule dependency (ilustrativa) |

*Nota: `demand-generation.md` y `documentation.md` ya existen y son consistentes con estas referencias
(verificado en `/consistency-check`); `/review-all-gdds` hará la verificación cruzada holística.*

## Acceptance Criteria

Formato Given-When-Then. Tipo de test sugerido: `[Unit]` (lógica pura) · `[Integration]` (una señal
llega a un sistema oyente).

**Avance del reloj (F2)**
- **AC-T01** `[Unit]` — GIVEN 1× con `escala_tiempo=4` WHEN update con `delta_real=1.0 s` THEN `minutos_juego` sube exactamente 4,0 min (±0,001).
- **AC-T02** `[Unit]` — GIVEN 2× (`escala=4`) WHEN `delta_real=1.0 s` THEN sube 8,0 min.
- **AC-T03** `[Unit]` — GIVEN 3× (`escala=4`) WHEN `delta_real=1.0 s` THEN sube 12,0 min.
- **AC-T04** `[Unit]` — GIVEN Pausa (mult 0) WHEN cualquier `delta_real>0` THEN `minutos_juego` no cambia (incremento 0).
- **AC-T05** `[Unit]` — GIVEN 1× (`escala=4`) WHEN se acumulan 360,0 s de `delta_real` THEN el reloj recorre 1440 min y vuelve a 00:00 del día siguiente.

**Conversión hora ↔ minutos (F3)**
- **AC-T06** `[Unit]` — GIVEN `minutos_del_dia=567` WHEN a HH:MM THEN `09:27`.
- **AC-T07** `[Unit]` — GIVEN hora=14, min=30 WHEN a minutos del día THEN `870`.
- **AC-T08** `[Unit]` — GIVEN `minutos_del_dia=0` WHEN a HH:MM THEN `00:00` (nunca `24:00`).

**Cálculo de turno (F3)**
- **AC-T09** `[Unit]` — GIVEN `420` (07:00) WHEN calcular turno THEN `MAÑANA`.
- **AC-T10** `[Unit]` — GIVEN `900` (15:00) WHEN calcular turno THEN `TARDE`.
- **AC-T11** `[Unit]` — GIVEN `1395` (23:15) WHEN calcular turno THEN `NOCHE`.
- **AC-T12** `[Unit]` — GIVEN `200` (03:20) WHEN calcular turno THEN `NOCHE` (cubre `[1380,1440)∪[0,420)`).

**Estado `es_de_noche`**
- **AC-T13** `[Unit]` — GIVEN `1381` (23:01) THEN `es_de_noche=true`.
- **AC-T14** `[Unit]` — GIVEN `419` (06:59) THEN `es_de_noche=true`.
- **AC-T15** `[Unit]` — GIVEN `420` (07:00) THEN `es_de_noche=false`.

**Señales de turno y día/noche**
- **AC-T16** `[Unit]` — GIVEN `899.7` (Mañana) a 3× WHEN el update pasa a `900.3` (cruza 15:00) THEN se emite `cambio_de_turno(TARDE)` una sola vez y el turno registrado es TARDE.
- **AC-T17** `[Unit]` — GIVEN `1379.8` (Tarde) WHEN pasa a `1380.5` (cruza 23:00) THEN se emiten `cambio_de_turno(NOCHE)` y `cambio_dia_noche(noche)`, una vez cada uno, en ese orden.
- **AC-T18** `[Unit]` — GIVEN `419.8` (Noche) WHEN pasa a `420.5` (cruza 07:00) THEN se emiten `cambio_de_turno(MAÑANA)` y `cambio_dia_noche(dia)`, una vez cada uno, en ese orden.
- **AC-T19** `[Integration]` — GIVEN un sistema oyente suscrito a `cambio_de_turno` WHEN el reloj cruza 15:00 THEN el oyente recibe exactamente una notificación con `TARDE` antes del siguiente frame.

**Medianoche / nuevo día / nuevo mes**
- **AC-T20** `[Unit]` — GIVEN `1439.8` WHEN pasa a `0.3` (cruza 00:00) THEN se emite `nuevo_dia` una vez y avanza **1 semana** (Semana +1; al pasar de Semana 4 → mes +1, regla 7).
- **AC-T21** `[Unit]` — GIVEN cruce de 00:00 en turno Noche THEN se emite `nuevo_dia` pero NO `cambio_de_turno` (sigue NOCHE).
- **AC-T22** `[Unit]` — GIVEN la **Semana 4** de un mes a 23:59 WHEN cruza medianoche THEN se emiten `nuevo_dia` y `nuevo_mes`, el mes +1 y la Semana vuelve a **1**.
- **AC-T22b** `[Unit]` — GIVEN el **mes 12 (Diciembre) · Semana 4** a 23:59 WHEN cruza medianoche THEN se emiten `nuevo_dia` y `nuevo_mes`, avanza el **año +1**, el mes vuelve a **1** y la Semana a **1** (48 jornadas = 1 año).

**Edge cases**
- **AC-T23** `[Unit]` — GIVEN `1379.0` (22:59, Tarde) WHEN un `delta_real` grande lleva el acumulador a `1441.0` (cruza 23:00 y 00:00 en el mismo frame) THEN se disparan en orden `cambio_de_turno(NOCHE)` → `cambio_dia_noche(noche)` → `nuevo_dia`, una vez cada uno.
- **AC-T24** `[Unit]` — GIVEN el escenario de AC-T23 WHEN se recogen las señales THEN ninguna se omite ni se duplica (sin duplicados por jitter de float).
- **AC-T25** `[Unit]` — GIVEN `delta_max_por_frame=0.5 s`, 1× (`escala=4`) WHEN el motor entrega `delta_real=30.0 s` (alt-tab) THEN el reloj solo avanza `4×1×0.5=2.0` min, no 120,0 min.
- **AC-T26** `[Unit]` — GIVEN partida guardada a las 14:30, día 5, turno Tarde WHEN se carga THEN muestra 14:30, día 5, Tarde, sin emitir señales de cambio de turno/día-noche/nuevo_dia.
- **AC-T27** `[Unit]` — GIVEN partida guardada con velocidad 3× WHEN se carga THEN la velocidad activa es **Pausa (0×)**, sea cual sea la guardada; el reloj no avanza hasta que el jugador elija velocidad.
- **AC-T28** `[Unit]` — GIVEN se configura `escala_tiempo=0` (o ≤0) WHEN se procesa THEN queda en `3.0` (mínimo) y se registra aviso en el log.
- **AC-T29** `[Unit]` — GIVEN se configura `escala_tiempo=15` (fuera de 3–12) WHEN se procesa THEN queda en `12.0` (máximo) y se registra aviso.

**Velocidad y pausa**
- **AC-T30** `[Unit]` — GIVEN 3× con `minutos_juego=500.0` WHEN el jugador cambia a 1× THEN `minutos_juego` sigue en 500,0 (ni pierde ni gana) y los frames siguientes van a 1×.
- **AC-T31** `[Unit]` — GIVEN estaba en 3×, pulsa Pausa y reanuda WHEN se reanuda THEN vuelve a 3× (la última velocidad de juego). *(Excepción: tras cargar, que arranca en Pausa sin velocidad previa, reanudar va a 1×.)*
- **AC-T32** `[Unit]` — GIVEN cualquier velocidad WHEN el jugador selecciona otra (incluida Pausa) THEN se emite `velocidad_cambiada` con el nuevo valor, una vez por acción.

**Calidad transversal**
- **AC-T33** `[Unit]` — GIVEN el reloj a 3× con `escala=12` (peor caso) WHEN se mide el `_process` del reloj durante 1000 frames THEN el tiempo medio del update es < 0,1 ms (< 0,6 % del presupuesto de 16,6 ms a 60 FPS). *(Hardware de referencia a fijar en implementación — ver Open Questions.)*
- **AC-T34** `[Unit]` — GIVEN un config con `escala_tiempo=6`, `inicio_mañana=360`, `inicio_tarde=840`, `inicio_noche=1320` WHEN se inicializa leyendo ese config (sin tocar código) THEN el reloj usa esos valores exactos; ningún límite de turno ni `escala_tiempo` está incrustado en el código.
- **AC-T35** `[Unit]` — GIVEN la misma secuencia de deltas aplicada dos veces desde idéntico estado WHEN se ejecutan THEN `minutos_juego`, turno y señales son idénticos (sin dependencia de fecha/hora real del sistema ni semillas aleatorias).
- **AC-T36** `[Integration]` — GIVEN Flujo, Demanda y Documentación activos WHEN cada uno consulta la hora THEN los tres devuelven el mismo `minutos_del_dia` del Sistema de Tiempo (ninguno mantiene su propio contador).

## Open Questions

| Pregunta | Dueño | Plazo | Estado |
|----------|-------|-------|--------|
| ¿La noche se siente viva con goteo de ODAC + 3×, o hace falta la ayuda opcional "adelantar hasta próxima apertura"? | Diseño/playtest | 1er playtest MVP | Abierta |
| Valor final de `escala_tiempo` (default 4 provisional) | Diseño/balance | 1er playtest MVP | Abierta |
| ¿Autopausa al perder foco: on u off por defecto? | UX | Implementación UI | Abierta |
| ¿La partida nueva debería arrancar también en Pausa (como la carga) o mantener 1×? | Diseño | 1er playtest MVP | Abierta |
| Confirmar `delta_max_por_frame` (0,5 s) en pruebas de rendimiento reales | Programación | Implementación | Abierta |
| Hardware de referencia para el AC de rendimiento (AC-T33): ¿en qué máquina/target se mide el `< 0,1 ms`? | Programación | Implementación (spike de rendimiento) | Abierta |
