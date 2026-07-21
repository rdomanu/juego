# Generación de Demanda

> **Status**: In Design
> **Author**: manu.rdo + Claude (hilo principal; lentes systems-designer / game-designer — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-19
> **Last Verified**: 2026-07-19
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" + Pilar 4 — "Tu comisaría, tus decisiones"

## Overview

El sistema de **Generación de Demanda** es el **grifo** del juego: decide **cuánta gente entra en la
comisaría, cuándo y a qué viene**. Crea cada **Persona** —ciudadanos a por el DNI, el pasaporte o el
TIE, y denunciantes de ODAC— a partir de la **población** del escenario (Pozuelo, 90.000 hab.), la
**hora y el turno** del reloj y el **día de la semana**, y la entrega a **Flujo**, que la encola y la
atiende. No mueve a nadie ni lleva colas (eso es Flujo): solo **produce la afluencia**. El modelo es
una **tasa base por habitante/día modulada por franja** (mañana/tarde/noche, hora punta, picos de
ciertos días) con una **aleatoriedad acotada de semilla determinista** —para que cada partida sea
reproducible—, y siempre **calibrada al invariante R5 de Datos**: la demanda máxima sostenida nunca
supera la capacidad máxima construible, así que nunca hay un **colapso irresoluble**, solo colas que
exigen buena gestión. Lee de *Datos* (población, catálogo de trámites/denuncias con su `prioridad` y
`requiere/admite_cita`, y los topes) y de *Tiempo* (hora, turno, `es_de_noche`, `nuevo_dia`, día de
semana); de noche **baja** la afluencia de Documentación (cerrada) y ODAC mantiene un **goteo** (franja 00:00–07:00 reducida por `mult_nocturno_odac`;
≈10 denunciantes en Pozuelo, escalable con la población).

A nivel de diseño, **Demanda es el motor de la presión que el jugador siente** (Pilares 2 y 4): la
**hora punta** que llena la sala de espera, la **noche** que la vacía, y el **crecimiento** que —al
ascender— te obliga a ampliar puestos y personal. El prototipo dejó dos lecciones que este sistema
encarna: **el volumen es el principal motor de diversión** (poca gente = pantalla muerta; demasiada
de golpe = agobio injusto) y **demanda ≠ capacidad** (construir no atrae más gente, solo la atiende
más rápido). Sin esta capa no hay colas que crezcan, ni trámites que cobrar, ni jornada que
optimizar: la demanda es lo que convierte un edificio vacío en **una comisaría con pulso**.

> **Regla de propiedad:** Demanda **posee** el *volumen* y el *timing* de las llegadas (cuántas
> Personas, cuándo y de qué trámite/denuncia) y las **crea**. **Lee** de *Datos* (`poblacion`,
> catálogo, `prioridad`, `requiere/admite_cita`, `tope_construible`) y de *Tiempo* (hora, turno,
> `es_de_noche`, `nuevo_dia`, día de semana). **No posee**: el *ciclo* de la Persona una vez creada
> —movimiento, colas, atención— (→ **Flujo #4**), la *paciencia/abandono* (→ **Paciencia #10**), ni
> los *horarios* de apertura (→ Documentación/ODAC + Tiempo). *(La **cita previa** como regulador que
> autolimita la demanda es el sistema **#14**, Vertical Slice; el MVP arranca **sin cita**.)*

## Player Fantasy

**Encuadre (indirecto):** el jugador nunca "usa" la Demanda; la vive como el **clima** de su
comisaría — un pulso con vida propia que aprende a **leer y anticipar**. La fantasía que aporta este
sistema es la de un **mundo que respira con ritmo reconocible** (Pilar 2), y la satisfacción de
**adelantarse a él** (Pilar 4).

Se vive en dos capas:

- **Infraestructura que se vive (la comisaría respira sola):** aunque no toques nada, entra gente por
  su cuenta, en **oleadas que cambian con la hora**. La sala de Documentación se llena por la mañana,
  afloja por la tarde y de noche solo cae el goteo de denuncias de ODAC. El jugador no maneja esta
  capa: la **contempla**, como quien mira subir y bajar la marea.
- **Leer y anticipar (lo más parecido a control):** la demanda tiene un **ritmo aprendible** —abre a
  las 9:00, hay hora punta, ciertos días cargan más—, y el jugador que lo **lee** se prepara: abre la
  segunda ventanilla *antes* de la avalancha, no cuando la cola ya llega a la puerta. La demanda
  **premia al previsor**; no castiga con sorpresas imposibles.

**El momento a anclar:** la **calma antes de la avalancha**. Son las 8:55, Documentación abre a las
9:00 y la sala está casi vacía; el reloj corre. El jugador que ha aprendido el ritmo ya tiene dos
ventanillas listas y ve entrar la oleada con una sonrisa —*"os estaba esperando"*—; el que no, ve la
cola dispararse y corre a reaccionar. Ese pulso **predecible pero vivo** —saber que viene, prepararte
y verlo llegar— es lo que Demanda regala.

**Referencia de sensación:** el flujo de "clientes" que llega en oleadas por horas de *Two Point
Hospital* y *Prison Architect*; la sensación de sistema vivo con ritmo diario de los tycoon de
gestión. **Anti-fantasía:** NO es **caos aleatorio injusto** —nada de avalanchas imposibles surgidas
de la nada que arruinan sin aviso (por eso el azar es **acotado** y todo se calibra a **R5**)—; y NO
es una **manguera monótona** —una afluencia plana y constante mataría el pulso—: la vida está en la
**variación por hora y día**. El jugador nunca debe sentir *"me han echado encima una marea imposible
de golpe"*.

*(Nota de proceso: `creative-director` no consultado —modo LEAN + subagentes caídos—; lente creativa
aplicada en el hilo principal. Revisar en `/design-review`.)*

## Detailed Design

### Core Rules

**DG1 · La salida es la Persona.** Demanda **crea instancias de Persona** con un `servicio` objetivo
(Documentacion u ODAC) y un **trámite/denuncia** concreto (`id` de Datos), y las **entrega a Flujo**
(evento `persona_generada`). Demanda no las mueve ni las encola (eso es Flujo, FL1); solo las
**produce**. Los tipos existentes los define **Datos**; Demanda no inventa trámites.

**DG2 · Volumen base por población.** La demanda diaria de cada servicio se deriva de la `poblacion`
del escenario por una **tasa base** (llegadas por 1.000 hab/día), separada por servicio:
`demanda_dia_servicio = poblacion × tasa_base_servicio` (ver Formulas). Las tasas base se **calibran a
R5** (Datos): la demanda máxima sostenida nunca supera la capacidad máxima construible.

**DG3 · Modulación por franja (el perfil intradía y semanal).** La tasa instantánea = tasa base ×
**multiplicador de franja** (por turno/hora) × **multiplicador de día de semana**. Documentación
concentra su demanda en su ventana diurna con **pico a la apertura**; ODAC reparte a lo largo de 24 h
con un **valle nocturno** (goteo). *(Los multiplicadores son tuning; ver Formulas/Tuning.)*

**DG4 · Mezcla de trámites (qué viene cada Persona).** Al crear una Persona, su trámite se elige de
una **distribución de probabilidad** sobre el catálogo del servicio (p. ej. DNI más frecuente que TIE;
entre denuncias, VioGén poco frecuente pero **Prioritaria**). La mezcla es **configurable** por
servicio y respeta el catálogo de Datos (`prioridad`, `requiere/admite_cita`).

**DG5 · Aleatoriedad acotada y determinista.** Las llegadas concretas se reparten con **azar acotado**
a partir de una **semilla** fija por partida: dos ejecuciones desde la misma semilla producen
**exactamente la misma secuencia** (determinismo, exigencia del proyecto). Un **tope de ráfaga**
(`max_llegadas_por_tick`) impide avalanchas imposibles surgidas de golpe (anti-fantasía). El azar
**varía el patrón**, nunca rompe R5.

**DG6 · Respeto del horario de apertura.** Demanda **solo genera llegadas de un servicio dentro de su
ventana de apertura**: Documentación no genera ciudadanos fuera de **08:00–14:30** (base; ampliable con
peonada — Documentación) (la gente conoce el horario — realista y evita frustración); ODAC, 24 h, siempre genera (con el valle nocturno). *(La
ventana la posee Documentación/ODAC + Tiempo; Demanda la consulta — provisional.)*

**DG7 · Calibración a R5 (nunca colapso irresoluble).** La demanda máxima sostenida de cada servicio
se mantiene **≤ capacidad máxima construible** (topes de Datos: Doc ≤8+2, ODAC ≤4). Es una restricción
de calibración: las tasas se ajustan **contra** `tope_construible`, no al revés. Los **picos** pueden
superar la capacidad *instantánea* (crean cola), pero nunca la *sostenida* (que sería irresoluble).

**DG8 · Crecimiento por progresión (arranque bajo → sube).** La `tasa_base` **escala con el nivel de
escenario/rango**: el MVP (Pozuelo, Nivel 1, Subinspector) arranca en una demanda **baja-media** que
deja aprender; niveles superiores la suben. El **perfil de crecimiento** lo posee Demanda; el
**disparador** (ascender de escenario) lo posee Ascensos #18.

**DG9 · La Pausa congela la generación.** En Pausa (Tiempo) **no se generan llegadas**; la generación
**consume el avance del reloj** (`delta`), igual que Flujo. Al reanudar, continúa de forma
determinista.

**DG10 · Sin cita en el MVP (demanda no autolimitada).** Con `requiere_cita=false` (Datos R5), la
afluencia **no se recorta por agenda**: puede exceder la capacidad instantánea y la válvula es la
**paciencia/abandono** (Flujo+#10), no un tope de demanda. La **cita previa** como regulador es el
sistema **#14** (Vertical Slice).

**DG11 · Eventos de demanda estacionales (picos multi-día por tipo).** Además del perfil regular,
ciertos periodos disparan **picos temporales** que inclinan la mezcla y suben la tasa de tipos
concretos durante **varios días**: el **inicio de vacaciones** dispara `pasaporte` (Documentación) y
`permiso_viaje` (ODAC), pudiendo **saturar ODAC** puntualmente. Estos picos pueden **superar la
capacidad instantánea** (crean cola/espera = reto), pero **nunca la sostenida** (respetan R5 — DG7); se
drenan. *(Catálogo de eventos = tuning; se cierra en playtest — Open Questions.)*

**DG12 · Nivel de demanda de Documentación (BAJA / MEDIA / ALTA).** Demanda expone una **señal derivada**
del volumen actual de Documentación, en tres tramos, que informa la decisión de **peonada** (abrir a las
08:00 / alargar): **BAJA** (poca demanda — la peonada no se cubre, pierde dinero), **MEDIA** (la peonada
da algo de beneficio pero puede haber días en negativo — **la más difícil de gestionar**) y **ALTA** (la
peonada se cubre siempre — pero es muy difícil dar abasto). Demanda **provee la señal**; el **€ de
rentabilidad** de la peonada lo posee **Economía/Horarios** (que la peonada **no sea siempre beneficio**
es un objetivo de diseño explícito). *(Umbrales = tuning; ver UI y Open Questions.)*

**DG13 · Perfil estacional anual (calendario mensual).** El **mes** (de Tiempo, `nuevo_mes`) fija un
**multiplicador estacional** `mult_estacional[mes]` sobre la demanda de Documentación, **determinista** (no
aleatorio): **Jun/Jul/Ago y Diciembre → ALTA** (×~1.5, verano/Navidad: pasaportes y viajes); **Ene/Feb →
BAJA** (×~0.6); **resto → MEDIA** (×1.0). Se aplica **encima** del perfil intradía/semanal (F2) y **por
debajo** de los eventos puntuales (DG11, que la División comunica). El nivel **BAJA/MEDIA/ALTA** (DG12) que
ve el jugador **deriva** de este multiplicador + la variación → sabe cuándo la peonada compensa
(Documentación). *(Multiplicadores = tuning; el reloj provee el mes. Calendario propuesto por el usuario
2026-07-21; a validar en playtest.)*

### States and Transitions

Demanda **no tiene estado mutable de instancias** (las Personas, una vez creadas, son de Flujo). Su
"estado" es: el **reloj que lee** (Tiempo), un **acumulador interno** de fracciones de llegada
pendientes, y el **estado del RNG** (semilla). Lo que transiciona es el **régimen de demanda**,
derivado de la hora:

| Régimen (derivado del reloj) | Franja | Documentación | ODAC | Nota |
|---|---|---|---|---|
| **Apertura / hora punta** | 08:00–~10:00 | **Pico** (cola acumulada esperando a abrir) | Normal | El momento del Player Fantasy |
| **Mañana** | ~10:00–14:30 | Alta, decreciendo hacia el cierre | Normal | |
| **Documentación cerrada (día)** | 14:30–23:00 | **0** (fuera de ventana, DG6) | Normal | Solo ODAC genera |
| **Noche** | 23:00–07:00 (`es_de_noche`) | **0** | Tarde-noche aguanta hasta ~00:00; **valle 00:00–07:00** (× `mult_nocturno_odac`; ≈10 en Pozuelo) | ODAC 24 h; la "noche muerta" la da que Doc cierra |

- Las transiciones de régimen las **dispara el reloj** (`cambio_de_turno`, cruces de hora); Demanda
  solo **lee** la hora y aplica el multiplicador correspondiente.
- El **día de la semana** (de Tiempo) aplica un multiplicador aparte (p. ej. lunes más cargado) —
  ortogonal al régimen intradía.
- En **Pausa** ningún régimen genera (DG9).

### Interactions with Other Systems

| Sistema | Qué fluye (Demanda ↔ él) | Dueño de la interfaz |
|---|---|---|
| **Tiempo** | *pull* hora/turno/`es_de_noche`/día-semana + `delta`; *push* `cambio_de_turno`, `nuevo_dia`; Pausa congela | Tiempo provee; Demanda consume ✅ GDD |
| **Datos y Configuración** | *lee* `poblacion`, catálogo de trámites/denuncias, `prioridad`, `requiere/admite_cita`, `tope_construible` | Datos posee los valores ✅ GDD |
| **Flujo de Personas y Colas #4** | *entrega* la Persona creada (`persona_generada`: servicio + trámite) | Demanda crea; Flujo la encola y mueve ✅ GDD |
| **Documentación #8** | *consulta* la ventana de apertura (08:00–14:30) y la política de cita | Documentación posee su horario *(provisional)* |
| **ODAC #9** | *consulta* la operativa 24 h y el goteo nocturno; mezcla de tipos de denuncia | ODAC posee su operativa *(provisional)* |
| **Paciencia y Satisfacción #10** | *(indirecto)* la demanda no atendida a tiempo abandona (lo ejecutan Flujo+Paciencia) | Paciencia posee la curva *(provisional)* |
| **Economía #3** | *(indirecto)* más demanda atendida → más ingresos (vía Flujo → `"trámite completado"`) | Economía posee el ingreso ✅ GDD |
| **Cita previa #14** *(V-Slice)* | *(futuro)* autolimitaría la afluencia con agenda | #14 posee la regulación |
| **Ascensos #18** *(futuro)* | *dispara* el crecimiento de `tasa_base` al subir de escenario/rango | Ascensos dispara |
| **UI / HUD #11** | *expone* el nivel de afluencia / aviso de hora punta *(opcional)* | UI presenta |

## Formulas

> Tiempos en **minutos/horas de juego**. Modelo **determinista por semilla** (exigencia del proyecto).
> Todos los números son **semilla provisional** a validar en el 1er playtest. Prefijo `F#`.

### F1 · Demanda diaria por servicio (volumen base)

`demanda_dia_servicio = poblacion × (tasa_base_servicio / 1000)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `poblacion` | int | 90000 (Pozuelo) | Habitantes del escenario (Datos) |
| `tasa_base_servicio` | float | 0.1–2.0 /1000 hab·día | Llegadas por 1.000 hab/día del servicio (**tuning**, escala con el nivel — DG8) |
| `demanda_dia_servicio` | float | ≥ 0 | Llegadas totales del servicio en un día |

**Semillas MVP (Pozuelo, Nivel 1 — deliberadamente bajas: gran parte de la demanda real va a
cita/online/otras sedes, DG8):**
- **Documentación** `tasa_base=0.5` → `90000 × 0.5/1000 = **45 trámites/día**` (repartidos en la ventana
  08:00–14:30).
- **ODAC** `tasa_base=0.4` → **~36 denuncias/día** (repartidas en 24 h; **menos gente que Documentación**,
  y trámites más largos) — dentro del rango 30–60/día que Datos F8 asumió.

### F2 · Llegadas esperadas por hora (perfil intradía + día de semana)

`llegadas_esperadas_hora(t) = demanda_dia_servicio × peso_hora(t) × mult_dia_semana(dia)`

donde `Σ peso_hora(t)` sobre las horas de apertura del servicio = **1.0** (distribución normalizada).

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `peso_hora(t)` | float | 0–1 | Fracción de la demanda diaria en la hora `t` (perfil, tuning) |
| `mult_dia_semana` | float | 0.5–1.5 · **default 1.0** | Multiplicador por jornada. *(Con el calendario semanal de Tiempo #1 cada jornada = 1 semana → representa la **carga media** de esa semana; antes "lunes 1.3/sábado 0.6".)* |

**Perfil semilla Documentación** (front-loaded, pico a la apertura 08:00 — DG3): 08–09 **0.30** · 09–10 0.22 ·
10–11 0.16 · 11–12 0.12 · 12–13 0.10 · 13–14 0.07 · 14–14:30 0.03 → suma 1.0. *(Ventana base **08:00–14:30 =
390 min**; ampliar el cierre más allá de 14:30 —hasta 20:00— es decisión de Documentación con **peonada**.)*
**Perfil semilla ODAC** (bajo y bastante estable; la **tarde/noche temprana aguanta** —21:00 ≈ 20:00— y
decae hacia 00:00): el grueso se reparte 07:00–00:00; en la franja **00:00–07:00** el peso horario se
**reduce por `mult_nocturno_odac`** (default 0.5, tuning) → **≈ 10 atenciones en Pozuelo** *(consecuencia
derivada, no un número fijo: con otra `poblacion` el mismo multiplicador da proporcionalmente más/menos)*.
*La sensación de "noche muerta" la da sobre todo que **Documentación cierra** (Doc = 0 de noche), no que
ODAC pare.*

**Ejemplo (Doc, 45/día, lunes ×1.3):** hora **08–09** (pico) → `45 × 0.30 × 1.3 ≈ **17,6 llegadas**` en esa hora.
Con 2 puestos (cap 8/h) → `ρ ≈ 2,2`: la cola crece en el pico y se drena después → **presión
gestionable ampliando** (el momento del Player Fantasy).

### F3 · Mezcla de trámites (a qué viene cada Persona)

`tramite = elegir_ponderado(P(tramite | servicio))` con RNG sembrado (F4).

| Servicio | Distribución semilla `P(tramite)` |
|----------|-----------------------------------|
| **Documentación** | `dni` **0.45** · `pasaporte` 0.35 · `tie` 0.20 (DNI y Pasaporte los más comunes; TIE menos) |
| **ODAC** | `hurto_robo` 0.18 · `estafa` 0.15 · `perdida_sustraccion` 0.12 · `ciberestafa` 0.10 · `danos` 0.09 · `lesiones` 0.07 · `amenazas` 0.07 · `okupacion` 0.05 · `permiso_viaje` 0.04 · `robo_violencia` 0.04 · `viogen` **0.04** · `desaparecidos` 0.03 · `agresion_sexual` 0.02 *(4 Prioritarias raras = 0.13 · 9 Normales = 0.87)* |

Sumas = 1.0 por servicio. Pesos **tuning**; respetan el catálogo de Datos (`prioridad`, `admite_cita`).
Los **eventos estacionales** (DG11) inclinan temporalmente la mezcla: en vacaciones sube `pasaporte`
(Documentación) y `permiso_viaje` (ODAC).

### F4 · Generación determinista por tick (el algoritmo)

Modelo de **acumulador** alimentado por el reloj, con RNG sembrado:

```
por cada tick (avance de reloj Δh, solo si NO en Pausa y el servicio está en su ventana DG6):
  acumulador += llegadas_esperadas_hora(t) × Δh          # F2
  generadas = 0
  mientras acumulador ≥ 1  y  generadas < max_llegadas_por_tick:
      tramite = elegir_ponderado(P(tramite|servicio), rng)   # F3
      crear Persona(servicio, tramite) → entregar a Flujo    # DG1
      acumulador -= 1 ;  generadas += 1
```

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `Δh` | float | ≥ 0 | Horas de juego avanzadas en el tick (de `delta` × escala) |
| `acumulador` | float | ≥ 0 | Fracción de llegada pendiente (se conserva entre ticks) |
| `max_llegadas_por_tick` | int | 1–10 · **default 3** | Tope de ráfaga anti-avalancha (DG5) |
| `rng` | — | semilla fija | Generador sembrado → secuencia reproducible |

**Salida:** 0…`max_llegadas_por_tick` Personas por tick. **Determinismo:** misma semilla + misma
secuencia de `Δh` → mismas llegadas y mismos trámites. El residuo fraccional del acumulador evita
perder demanda por redondeo.

### F5 · Chequeo de calibración a R5 (lado demanda)

`demanda_max_sostenida_servicio ≤ capacidad_max_servicio` *(capacidad = Flujo F3; invariante = Datos R5)*

- **Documentación:** 45/día sostenida « **260/día** (capacidad máx, 10 puestos) ✔. Incluso el pico
  horario (~17,6/h) es puntual y se drena; la demanda *sostenida* nunca satura la capacidad máxima.
- **ODAC:** ~36/día « **128/día** (capacidad máx, 4 puestos) ✔ — dentro del chequeo de Datos F8. Los
  **picos estacionales** (DG11) pueden superar la capacidad *instantánea* de ODAC (saturación temporal =
  reto), pero no la *sostenida* → no rompe R5.

*(Demanda aporta el **lado demanda**; Datos posee el invariante R5 y Flujo el lado capacidad. Si se
sube `tasa_base` o `poblacion`, revalidar contra los topes — ver Tuning.)*

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre reglas (DG1–DG10) y fórmulas
(F1–F5).*

- **Si Documentación está fuera de su ventana de apertura** (antes de 08:00 o tras 14:30): Demanda
  **no genera** ciudadanos de Documentación y su **acumulador no crece** (tasa=0, DG6). *No se acumula
  demanda "fantasma" que estalle al abrir; el pico de apertura ya lo modela el perfil front-loaded
  (F2).*

- **Si Documentación cierra con demanda del día sin materializar** (acumulador fraccional > 0): ese
  acumulador se **reinicia a 0** al cierre; la demanda no atendida del día **no se arrastra** al
  siguiente. *La gente que no vino hoy no "se guarda"; cada día genera su propia afluencia. Evita un
  pico artificial acumulado al abrir.*

- **Si el acumulador supera `max_llegadas_por_tick` en un tick** (llega mucha demanda de golpe): se
  generan hasta el tope y **el excedente se conserva** en el acumulador para los ticks siguientes (se
  suaviza la ráfaga, no se pierde demanda). *Anti-avalancha (DG5) sin perder volumen. Si el acumulador
  crece sin drenar nunca (mal tuning: tasa sostenida > tope), se registra aviso.*

- **Si un tick trae un `Δh` grande** (alta velocidad 3× o tirón de lag): Demanda usa el **`delta` ya
  clampado por Tiempo** (`delta_max_por_frame`), así que un alt-tab **no** dispara una avalancha; a 3×
  legítimo, más `Δh` = más llegadas proporcionalmente, y el tope de ráfaga las reparte. *Coherente con
  el clamp anti-salto de Tiempo.*

- **Si la distribución de mezcla `P(tramite)` no suma 1.0** (dato corrupto): se **normaliza** (cada
  peso ÷ suma) antes de elegir; si todos son 0, se reparte **uniforme** con aviso. *Un dato mal
  ponderado no debe romper la elección de trámite.*

- **Si `tasa_base = 0` o `poblacion = 0`:** `demanda_dia = 0` → **no se genera nadie** para ese
  servicio. No es error (útil para debug o escenarios sin un servicio). *Un grifo cerrado es una
  configuración válida.*

- **Si todos los puestos de un servicio están cerrados/sin dotar y Demanda sigue generando** (sin
  cita, DG10): la gente **llega igual**, se encola y —si nadie la atiende— abandona (Flujo +
  Paciencia). Demanda **no deja de generar** por falta de puestos. *Realista: el ciudadano viene
  aunque no lo atiendas; es la señal de "te falta capacidad", no un bug.*

- **Si el tuning sube `tasa_base`/`poblacion` por encima de la capacidad máxima construible**
  (violación de R5): la validación de **Datos emite WARNING en carga** (no Demanda en runtime); el
  diseño exige recalibrar tasas o topes. *La demanda se calibra contra `tope_construible`, no al revés
  (DG7); Datos es el guardián del invariante.*

- **Si un tick cruza un límite de franja/turno/día** (p. ej. de 10:59 a 11:01): las
  `llegadas_esperadas_hora` se evalúan con la **hora al final del avance** del tick (coherente con
  cómo Tiempo detecta cruces). *Con `Δh` pequeño el efecto es despreciable; la regla fija el
  determinismo.*

- **Si se guarda la partida a mitad de generación:** se serializan el **acumulador**, el **estado del
  RNG** y la **semilla**; al cargar, la secuencia futura continúa **idéntica** y la partida arranca en
  **Pausa** (Tiempo). *Cargar no altera la secuencia determinista; sin llegadas retroactivas.*

- **Si la demanda nocturna de ODAC es tan baja que el acumulador tarda mucho en llegar a 1:** correcto
  por diseño — las denuncias nocturnas salen **espaciadas** (el goteo), y el residuo se conserva. *El
  valle nocturno es intencional (F2), no un fallo.*

## Dependencies

**Este sistema depende de:**

| Sistema | Tipo | Interfaz (qué lee/consume) |
|---------|------|-----------------------------|
| **Tiempo** | Hard | *pull* hora/turno/`es_de_noche`/día-semana + `delta`; *push* `cambio_de_turno`, `nuevo_dia`; Pausa congela ✅ GDD |
| **Datos y Configuración** | Hard | *lee* `poblacion`, catálogo de trámites/denuncias, `prioridad`, `requiere/admite_cita`, `tope_construible` (calibración R5) ✅ GDD |
| **Documentación #8** | Hard | *lee* la **ventana de apertura** (08:00–14:30) y la política de cita — para saber cuándo generar (DG6) *(provisional)* |
| **ODAC #9** | Hard | *lee* la operativa **24 h** y el goteo nocturno; ajusta la mezcla de tipos de denuncia *(provisional)* |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz (qué recibe de Demanda) |
|---------|------|----------------------------------|
| **Flujo de Personas y Colas #4** | Hard | *recibe* la Persona creada (`persona_generada`: servicio + trámite) para encolarla ✅ GDD |
| **Paciencia y Satisfacción #10** | Soft | *(indirecto)* la demanda no atendida a tiempo abandona (lo ejecutan Flujo+Paciencia) ✅ GDD. **Nota:** un abandono de Documentación puede inyectar carga extra en ODAC (`reclamacion`, PS13) — la mete **Paciencia**, no el generador de Demanda |
| **Economía #3** | Soft | *(indirecto)* más demanda atendida → más ingresos, vía Flujo → `"trámite completado"` ✅ GDD |
| **Cita previa #14** *(V-Slice)* | Hard | *(futuro)* autolimitaría la afluencia con agenda (regulador de R5) |
| **Ascensos #18** *(futuro)* | Hard | *(futuro)* dispara el crecimiento de `tasa_base` al subir de escenario/rango (DG8) |
| **UI / HUD #11** | Soft | *expone* el nivel de afluencia / aviso de hora punta *(opcional)* |

> **Consistencia bidireccional:** **Flujo ✅** ya lista Demanda como dependencia (recibe las
> Personas), y **Tiempo ✅ / Datos ✅ / Paciencia ✅** ya registran sus dependientes.
> Documentación/ODAC añadirán la referencia inversa al escribirse *(provisional)*. Registrado en `systems-index.md`.

## Tuning Knobs

### Knobs propios de Demanda

| Knob | Default (semilla) | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|-------------------|--------------|-------------|-------|
| `tasa_base_doc` (llegadas/1000 hab·día) | 0.5 | 0 – 2.0, **sujeto a R5** | ↑ más ciudadanos de Documentación (más presión e ingreso potencial) / ↓ menos | Demanda |
| `tasa_base_odac` (llegadas/1000 hab·día) | 0.5 | 0 – 2.0, **sujeto a R5** | ↑ más denuncias (más carga ODAC, sin ingreso) / ↓ menos | Demanda |
| `perfil_hora[servicio]` (pesos por hora) | F2 (Doc front-loaded; ODAC plano+valle) | Σ = 1.0 por servicio | Concentra el pico (↑ pico apertura = más tensión) o lo aplana (manguera monótona) | Demanda |
| `mult_nocturno_odac` | 0.5 | 0.2 – 1.0 | Reduce el peso horario de ODAC en 00:00–07:00. ↑ noche más viva (≈ día) / ↓ valle más profundo. **Escala con la población** (reutilizable en otros escenarios); ≈10 en Pozuelo es la salida derivada, no el input | Demanda |
| `mult_dia_semana[dia]` | 1.0 (lunes ~1.3; sábado ~0.6) | 0.5 – 1.5 | ↑ ese día carga más (picos semanales) / ↓ más flojo | Demanda |
| `mezcla[servicio]` = `P(tramite)` | F3 (DNI 0.45…; ODAC 13 tipos, Prioritarias 0.13) | Σ = 1.0 por servicio | Cambia la carga por tipo (↑ Prioritarias = más urgencias en ODAC; ↑ Pasaporte = trámites más largos) | Demanda |
| `max_llegadas_por_tick` | 3 | 1 – 10 | ↑ ráfagas más bruscas (riesgo de avalancha) / ↓ llegadas más suavizadas | Demanda |
| `factor_crecimiento_nivel` (DG8) | 1.0 (Nivel 1) | ≥ 1.0 | ↑ niveles superiores con más demanda (progresión) / — | Demanda / Ascensos |
| `semilla_rng` | por partida | cualquier entero | Cambia el patrón concreto de llegadas (no el volumen) — determinismo | Demanda |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto sobre la demanda |
|------|-----------|-------------------------|
| `poblacion` | Datos → Datos/Demanda | Multiplica el volumen (F1); **sujeto a R5** |
| `tope_construible` (por servicio) | Datos/Construcción | El techo de capacidad contra el que se calibra la demanda (R5) |
| ventana de apertura (08:00–14:30) | Documentación/Horarios + Tiempo | Cuándo genera Documentación (DG6) |
| `escala_tiempo` | Tiempo | El ritmo real al que la demanda se materializa |

**Interacciones entre knobs (clave):**
- **`tasa_base` × `poblacion` × `tope_construible` gobiernan R5.** Subir tasa o población, o bajar
  topes, puede violar R5 → Datos avisa en carga. **Cámbialos juntos.**
- **`perfil_hora` decide *dónde* duele:** un perfil muy front-loaded crea el pico de apertura
  (tensión); uno plano la reparte (menos drama). Es la palanca del "pulso".
- **`mezcla` cambia el *tipo* de carga:** más `pasaporte`/`tie` (15 min) sube el tiempo de servicio
  medio → menos throughput real (Flujo F2); más `viogen` sube las Prioritarias en ODAC.
- **`max_llegadas_por_tick`** solo actúa en ráfagas; con demanda baja es inerte.

**Restricciones:** `Σ perfil_hora = 1.0` y `Σ mezcla = 1.0` por servicio; `tasa_base ≥ 0`; todo
escenario **sujeto a R5** (lo verifica Datos en carga).

## Visual/Audio Requirements

Demanda **no produce arte propio**: es lógica de simulación. La representación visible de las Personas
que genera (siluetas por rol) la posee **Flujo + art bible**; el feedback de sus eventos lo sonoriza
**Feedback/Audio**. Lo que Demanda **declara** es el *ritmo* que esos sistemas traducen:
- **El pulso de afluencia** —oleada de apertura, valle nocturno, picos estacionales (DG11)— es lo que
  Feedback/Audio convierten en **densidad de gente y ambiente**: mañana bulliciosa vs. noche silenciosa
  (art bible §2, *mood* por estado; recuérdese que la calma nocturna la da sobre todo el cierre de
  Documentación).
- **Aviso opcional de "hora punta"** o de **evento estacional** (visual/sonoro sutil) cuando la tasa
  instantánea supera un umbral — lo presentan UI/Feedback.
- **Assets propios:** N/A (Demanda no tiene iconos ni sonidos propios).

## UI Requirements

Demanda **no tiene pantalla propia**; alimenta el HUD (la UI la posee **UI/HUD #11**):
- **Indicador "Demanda de Documentos Nacionales" (BAJA / MEDIA / ALTA)** —la señal de DG12—, **siempre
  visible**: es la brújula del jugador para decidir la **peonada** (abrir a las 08:00 / alargar). Con
  respaldo daltónico (icono/texto además del color): **BAJA** (peonada no rentable), **MEDIA** (peonada
  ajustada, riesgo de días en negativo — la más difícil), **ALTA** (peonada siempre rentable, difícil
  dar abasto).
- **Indicador de afluencia instantánea / aviso de hora punta** (opcional): ayuda a **anticipar** la
  oleada (núcleo del Player Fantasy).
- **Aviso de evento estacional** (DG11): p. ej. "temporada de vacaciones — suben Pasaporte y permisos de
  viaje".
- **(Herramienta de diseño, no UI de jugador):** visor de `tasa_base`, perfil y mezcla por servicio para
  tuning.
- La UI **nunca hardcodea** estos textos/umbrales; los lee del catálogo/config.

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.* Al
> menos un criterio por regla (DG1–DG12) y por fórmula (F1–F5).

**Volumen y perfil (DG2, DG3, F1, F2)**
- **AC-DM01** `[Unit]` — GIVEN `poblacion=90000`, `tasa_base_doc=0.5` WHEN F1 THEN `demanda_dia_doc=45`.
- **AC-DM02** `[Unit]` — GIVEN `tasa_base_odac=0.4` WHEN F1 THEN `demanda_dia_odac=36` (< Documentación).
- **AC-DM03** `[Unit]` — GIVEN perfil Doc y 45/día, hora **08–09** (pico), lunes ×1.3 WHEN F2 THEN `Σ pesos=1.0` y llegadas esperadas ≈ **17,6**.
- **AC-DM04** `[Unit]` — GIVEN perfil ODAC (36/día) y `mult_nocturno_odac=0.5` WHEN se suma 00:00–07:00 THEN ≈ **10 atenciones** en Pozuelo; con otra `poblacion` escala proporcional (no hardcode).

**Generación determinista (DG1, DG4, DG5, F3, F4)**
- **AC-DM05** `[Integration]` — GIVEN una llegada WHEN se genera THEN la Persona tiene `servicio` + `tramite` (id de Datos) y se entrega a Flujo (`persona_generada`).
- **AC-DM06** `[Unit]` — GIVEN la misma `semilla_rng` y la misma secuencia de `Δh` WHEN se ejecuta dos veces THEN la secuencia de llegadas y trámites es **idéntica** (determinismo).
- **AC-DM07** `[Unit]` — GIVEN `acumulador≥5` y `max_llegadas_por_tick=3` WHEN un tick THEN se generan **3** y el excedente (≥2) **queda** en el acumulador.
- **AC-DM08** `[Unit]` — GIVEN N grande de generaciones Doc con semilla fija WHEN se cuentan THEN las proporciones ≈ **dni 0.45 / pasaporte 0.35 / tie 0.20** (±tolerancia).

**Horario y pausa (DG6, DG9)**
- **AC-DM09** `[Integration]` — GIVEN las 15:00 (Doc cerrada) WHEN se generan llegadas THEN **no** se crean ciudadanos de Documentación; ODAC **sí** genera.
- **AC-DM10** `[Unit]` — GIVEN el cierre de Documentación (14:30) con acumulador Doc fraccional WHEN cierra THEN el acumulador Doc se **reinicia a 0** (no arrastra).
- **AC-DM11** `[Integration]` — GIVEN el juego en **Pausa** WHEN pasa `delta` THEN **no** se genera ninguna Persona (el acumulador no crece).

**Calibración R5 y crecimiento (DG7, DG8, F5)**
- **AC-DM12** `[Unit]` — GIVEN semillas MVP (Doc 45, ODAC 36) y capacidades máx (Doc 260, ODAC 128) WHEN se valida R5 THEN `demanda_dia ≤ capacidad_max` (se cumple, sin warning).
- **AC-DM13** `[Unit]` — GIVEN `factor_crecimiento_nivel=1.5` WHEN se aplica THEN la `tasa_base` efectiva sube ×1.5 (más demanda al ascender).

**Eventos estacionales y nivel de demanda (DG11, DG12)**
- **AC-DM14** `[Integration]` — GIVEN un evento "vacaciones" activo WHEN se genera THEN sube la proporción/tasa de `pasaporte` (Doc) y `permiso_viaje` (ODAC) frente al perfil regular.
- **AC-DM15** `[Unit]` — GIVEN los umbrales de DG12 y un volumen de Documentación X WHEN se clasifica THEN devuelve **BAJA / MEDIA / ALTA** según el tramo correcto.

**Sin cita, normalización y robustez (DG10, Edge Cases)**
- **AC-DM16** `[Integration]` — GIVEN `requiere_cita=false` y llegadas > capacidad WHEN transcurre el tiempo THEN la generación **no se autolimita** (sigue creando; la cola crece).
- **AC-DM17** `[Unit]` — GIVEN una mezcla con pesos `[2,1,1]` (no suma 1) WHEN se procesa THEN se **normaliza** a `[0.5,0.25,0.25]` antes de elegir.
- **AC-DM18** `[Unit]` — GIVEN un save con acumulador + estado RNG WHEN se carga THEN se restauran y la secuencia futura continúa **idéntica**; arranca en **Pausa**.
- **AC-DM19** `[Unit]` — GIVEN `tasa_base=0` o `poblacion=0` WHEN F1 THEN `demanda_dia=0` y **no se genera nadie** (config válida).

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | **Valores semilla de `tasa_base`** (Doc 0.5 / ODAC 0.4) — validar que la presión es divertida (ni muerta ni imposible) con la capacidad de arranque. Comparte con Datos Open Q#2/#7 | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Perfil intradía** (cuánto pico a la apertura) y **multiplicadores de día de semana** (¿lunes ×1.3?) | Demanda + playtest | 1er playtest MVP | Abierta |
| 3 | **Mezcla de trámites/denuncias**: ¿DNI 0.45 / Pas 0.35 / TIE 0.20 refleja bien la realidad? ¿VioGén 5% da suficientes Prioritarias sin saturar las Normales de ODAC? | Demanda + ODAC | GDD ODAC / playtest | Abierta |
| 4 | **Curva de crecimiento por nivel** (`factor_crecimiento_nivel`): cómo escala la demanda al ascender de escenario | Demanda + Ascensos #18 | GDD Ascensos | Abierta |
| 5 | **¿La demanda nocturna de ODAC (`mult_nocturno_odac`, ≈10 en Pozuelo) se siente viva o muerta? ¿Qué default de multiplicador?** Comparte con la Open Question de Tiempo sobre la noche | Diseño / playtest | 1er playtest MVP | Abierta |
| 6 | **Fuente y serialización de la semilla RNG** (aleatoria por partida vs. fija; cómo se guarda) — parte del ADR de arquitectura/guardado | Arquitectura (technical-director) | Fase de arquitectura (ADR) | Abierta |
| 7 | **Ventana de apertura de Documentación**: base **08:00–14:30**, ampliable a 20:00 con peonada (advisory de Tiempo 08:00 aplicado) — horas exactas a validar | Documentación + Tiempo | GDD Documentación | ✅ Resuelta |
| 8 | **Catálogo de eventos estacionales (DG11)**: cuáles (vacaciones → Pasaporte/permiso_viaje…), cuántos días duran y cuánto suben cada tipo; ¿cuánto pueden saturar ODAC sin volverse injustos? | Demanda + ODAC + playtest | 1er playtest MVP | Abierta |
| 9 | **Umbrales BAJA/MEDIA/ALTA (DG12)** y su vínculo con la **rentabilidad de la peonada**: calibrar para que la peonada **NO sea siempre beneficio** (MEDIA = decisión difícil, días en negativo posibles) | Demanda + Economía/Horarios | GDD Horarios / playtest | Abierta |
| 10 | **Detenidos (#17) como demanda ODAC futura**: llegan 24 h (también de noche), ocupan un **puesto ODAC ~180 min** (papeleo, derechos, toma de declaración, reseña, aviso al juzgado, comparecencia de policías, abogado); menos si es trivial, no mucho más. **NO es MVP** — se incorpora con #17 | ODAC #9 / Detenidos #17 | GDD #17 (V-Slice) | Abierta |
