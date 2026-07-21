# Paciencia y Satisfacción

> **Status**: Reviewed (/design-review 2026-07-22 APPROVED)
> **Author**: manu.rdo + Claude (hilo principal; lentes systems-designer / game-designer / qa-lead / economy-designer — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" + Pilar 4 — "Tu comisaría, tus decisiones" + Pilar 1 — "Realismo con alma"

## Overview

El sistema de **Paciencia y Satisfacción** es el que convierte la **espera** en **consecuencia**. Tiene dos
caras acopladas: **(1) la paciencia**, una barra individual que lleva **cada persona** que espera en la sala
—empieza llena al coger turno y **se drena con el tiempo de espera**; si llega a 0, la persona **se marcha**
(abandono, ejecutado por *Flujo*) dejando un mal recuerdo—; y **(2) la satisfacción**, un indicador agregado
de la comisaría, **`sat` de 0 a 100**, que sube cuando la gente sale **atendida y a tiempo** (y con buen
**trato** del agente) y baja con cada **abandono**, cola desbordada o sala hacinada. En el **MVP**, esa `sat`
se "cobra" sobre todo vía *Economía* (**retorno DGP**: sat 0 → vuelve el 15 % de la tasa; sat 100 → el 45 %)
y el **objetivo de eficiencia** que dispara el ascenso; *ODAC* la nutre con su reputación; y más adelante será
además la base de la **valoración de tus jefes** (#28, capa de progresión). Paciencia **posee** la escala 0–100
y la curva de paciencia; **no** posee el tiempo de espera (lo calcula *Flujo* F5) ni el reloj (*Tiempo*): solo
los **consume**.

A nivel de diseño, es el sistema que hace que **gestionar bien importe** (Pilares 2 y 4): sin él, las colas
serían un número abstracto sin coste; con él, cada persona que espera es un **personaje vivo** con un ánimo que
se lee de un vistazo (Pilar 2, "la comisaría está viva"), y cada decisión de priorización, dotación o
construcción **se traduce en satisfacción** —y esta, en dinero y reputación—. Es el **puente** entre *"cómo de
bien llevas la comisaría"* y *"cuánto rinde"*: el marcador que el jugador vigila para saber si va ganando o
perdiendo.

## Player Fantasy

**La fantasía:** *"Leo el ánimo de mi comisaría de un vistazo, y soy yo quien decide si la sala respira o
estalla."*

El jugador debe sentir la **sala de espera como un termómetro vivo**. No mira un número: mira **caras y barras**
que van del verde al rojo. La emoción central es la **tensión gestionable de la hora punta** —ver los ánimos
agriarse y llegar *justo a tiempo* con una segunda ventanilla, una repriorización o un agente de refuerzo— y el
**alivio con orgullo** cuando la sala se vacía sin que nadie se haya marchado enfadado. Es la cara
"tranquilidad/Submission" del juego (vigilar y ajustar) que de golpe se vuelve "Challenge" cuando la cola se
dispara.

Al otro lado está el **miedo a la espiral**: un abandono baja la satisfacción, la satisfacción baja el retorno
DGP, tienes menos dinero para dotar más puestos… y la sala empeora. Que **hacer esperar a la gente tenga peso
humano** —un señor mayor a por el DNI, una víctima que ya lo está pasando mal— conecta con el **Pilar 1**
("realismo con alma"): no es "un cliente perdido", es **alguien** que se fue mal atendido.

**Referencias que clavan la sensación:** *Two Point Hospital* (pacientes que se impacientan; medidor de
felicidad legible de un vistazo), *Prison Architect* (necesidades que atender antes de que revienten), *Theme
Hospital*. **Tomamos:** el feedback de ánimo **inmediato y visible** (Pilar 2) que convierte una métrica en
drama humano. **Evitamos:** la caricatura (anti-pilar) — aquí el descontento es **sobrio y realista**, no
cómico.

**Momento ancla:** hora punta, la sala se llena; un DNI lleva 20 min y su barra parpadea en ámbar. Abres la
segunda ventanilla justo a tiempo: la cola avanza, los ánimos se recuperan y el marcador —que rozaba el rojo—
respira. *Nadie se ha ido. Esta vez.*

## Detailed Design

### Core Rules

**Paciencia (por persona)**
- **PS1.** Al **coger turno**, la persona recibe `paciencia = paciencia_max` (barra 0–100, base **común**).
  Arranca al estar esperando, no al generarse.
- **PS2.** Mientras **espera** (en cola, sin ser llamada), la paciencia **drena** a `tasa_drenaje`/min de juego.
  La tasa base se **modifica** por: **hacinamiento** (aforo de la sala superado → drena más rápido),
  **comodidades** de la sala (#15; MVP = neutro) y, opcional, la hora punta.
- **PS3.** Al ser **llamada a un puesto** (Flujo la asigna), la paciencia se **congela**: ya no drena ni puede
  abandonar. *(Ser atendida = a salvo.)*
- **PS4.** Si la paciencia llega a **0** antes de ser llamada, la persona **abandona**: Flujo la retira de la
  cola (`persona_abandona`) y genera una **visita de puntuación mínima**.
- **PS5.** **Umbrales de ánimo** (solo feedback visible, Pilar 2): 🟢 Contento (>66 %), 🟡 Impaciente
  (33–66 %), 🔴 Al límite (<33 %). El abandono es a 0.

**Puntuación de visita — el puente paciencia → satisfacción**
- **PS6.** Cuando una persona **se va**, genera `puntuacion_visita` (0–100):
  - **Atendida:** base alta, **penalizada por lo que esperó** (relativo a su paciencia) y **modulada por el
    🤝Trato** del agente (Personal `factor_trato`).
  - **Abandonada:** `puntuacion_visita = 0` (peor desenlace).
  - **En ODAC:** la puntuación se **pondera por `peso_prioridad`** (knob de ODAC F1, 1.0 / 2.5): atender bien
    una Prioritaria puntúa más; dejar marchar una Prioritaria hunde más.

**Satisfacción por servicio (agregado 0–100) + cierre diario**
- **PS7.** Cada servicio (Documentación, ODAC) lleva una `satisfaccion_<servicio>` = **media de las
  puntuaciones de visita de la jornada en curso** (`sat_actual`, visible en HUD construyéndose).
- **PS8.** Al **cierre de jornada** (`nuevo_dia`) se **congela** la media: `sat_cierre_<servicio>`.
- **PS9.** **Ingresos estables:** durante toda una jornada, Economía usa el `sat_cierre_<servicio>` **de la
  jornada anterior** como entrada de `retorno_dgp` → el multiplicador de ingresos es **fijo durante el día**,
  solo cambia al pasar de jornada.
- **PS10.** **Primera jornada / sin datos:** ambos servicios arrancan con `sat_inicial = **50**` (Documentación
  y ODAC) — "empezamos por algo", retorno medio, ni premio ni castigo hasta que haya una jornada cerrada.
- **PS11.** `sat_global` = media ponderada por volumen de visitas — **solo HUD/valoración**; Economía cobra por
  servicio (Doc), no la global.

**Hoja de reclamaciones (contador de eficiencia + bucle ODAC)**
- **PS12.** Cada **abandono** (paciencia = 0) presenta una **hoja de reclamaciones**: `reclamaciones_jornada += 1`
  y se acumula en `reclamaciones_mes`. Es un **contador de eficiencia** (cuantas menos, mejor) que alimenta el
  **objetivo de eficiencia** del MVP (dispara el ascenso) y la futura **valoración de jefes #28** —**independiente**
  de la `sat` (dinero)—. Los abandonos de **Prioritarias de ODAC** (VioGén, desaparecidos…) cuentan como
  **reclamación grave** (marcadas aparte / peso extra). Al `nuevo_mes` se evalúa el acumulado y se resetea.
- **PS13.** **Formalizar en ODAC (el bucle).** Con probabilidad `prob_reclamacion` (default 0.4), quien abandona
  **Documentación** acude a **ODAC** a formalizar la hoja → genera un trámite **`reclamacion`** (Normal, **30 min**,
  **sin tarifa**) en la cola de ODAC, que puede **saturarla** (Doc mal gestionada contamina ODAC). **Sin recursión:**
  una `reclamacion` que abandona en ODAC suma al contador pero **no** genera otra; los abandonos **de ODAC** cuentan
  pero no formalizan (ya estaban allí). Atender una `reclamacion` suma a `satisfaccion_odac` como una visita normal.
  *(Carga **autoinfligida**: no altera la demanda base de ODAC ni el invariante R5 —es un recargo que te ganas por
  gestionar mal Documentación.)*

### States and Transitions

**Paciencia (por persona):**

| Estado | Entra al… | Sale al… | ¿Drena? |
|--------|-----------|----------|---------|
| **Esperando** | coger turno | ser llamada · o paciencia=0 | **Sí** |
| **Atendida** (congelada) | ser llamada a puesto | fin del trámite → visita puntuada | No |
| **Abandonada** | paciencia = 0 | al instante → visita puntuada (mín) | — |

**Servicio (por jornada):** `Acumulando (jornada en curso)` → **`nuevo_dia`** → `Cerrada (sat_cierre fija los
ingresos de la jornada siguiente)`. El ciclo se repite cada jornada (= 1 semana de calendario, Tiempo #1).

### Interactions with Other Systems

| Sistema | Qué fluye | Dueño de la interfaz |
|---------|-----------|----------------------|
| **Flujo #4** | Flujo avisa "coge turno" (arranca barra) y "llamada a puesto" (congela); **ejecuta el abandono** cuando Paciencia marca 0 (`persona_abandona`) | Flujo posee la cola; **Paciencia posee la barra** |
| **Tiempo #1** | El reloj **drena** la paciencia (min de juego); `nuevo_dia` **cierra** la media de la jornada | Tiempo posee el reloj/eventos |
| **Economía #3** | Lee `sat_cierre_doc` (jornada anterior) como `sat` de `retorno_dgp` (min 0.15 / max 0.45) | Economía posee la fórmula; **Paciencia posee `sat`** ✅ reconciliado (Economía E7/F1 ya lo cita) |
| **ODAC #9** | ODAC aporta puntuaciones **ponderadas por `peso_prioridad`**; Paciencia le da la **escala 0–100** (`satisfaccion_odac`/reputación). **Bucle (PS13):** un abandono de Documentación puede **inyectar un trámite `reclamacion`** (30 min) en la cola de ODAC vía Flujo | **Paciencia posee la escala** y **genera** las reclamaciones; ODAC posee los pesos y las tramita |
| **Objetivo de eficiencia (MVP) / Valoración #28** | Consumen el contador `reclamaciones` (PS12): cuantas menos, mejor evaluación / ascenso | Paciencia **produce** el contador; el objetivo/#28 lo consume |
| **Personal #6** | El **🤝Trato** del agente modula `puntuacion_visita` (`factor_trato`) | Personal posee el atributo |
| **Construcción #7 / Comodidades #15** | **Aforo** superado → +drenaje (hacinamiento); comodidades → −drenaje (#15) | Construcción posee el aforo; #15 las comodidades |
| **Documentación #8** | Horario y última admisión → cuánta gente espera y cuánto | Documentación posee el horario |
| **UI #11 / Feedback #12** | Leen ánimo por persona y `sat` para pintar | UI/Feedback pintan |

*(Comodidades = neutro hasta #15. La reconciliación con Economía —`sat` = media cerrada de la jornada
anterior— **aplicada** (Economía E7/F1, 2026-07-21).)*

## Formulas

> Números **semilla provisional** (a validar en playtest). Prefijo `F#`. F4 es referenciada (dueña: Economía).

### F1 · Drenaje de paciencia

`paciencia(t+Δ) = paciencia(t) − tasa_drenaje_efectiva × Δ_min`
`tasa_drenaje_efectiva = (100 / tolerancia_base_min) × mult_hacinamiento × mult_comodidad × mult_horapunta`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `paciencia` | float | 0–100 | Barra individual; abandona a 0 |
| `tolerancia_base_min` | float | 15–60 · **default 30** | Minutos que aguanta una persona en condiciones neutras (tuning) |
| `mult_hacinamiento` | float | 1.0–~2.0 | 1.0 si `ocupacion ≤ aforo`; si no, `1 + k_hacinamiento × (ocupacion−aforo)/aforo` |
| `mult_comodidad` | float | 0.6–1.0 · **MVP 1.0** | #15 lo baja (<1 = más paciencia); neutro hasta Comodidades |
| `mult_horapunta` | float | 1.0–1.3 · **MVP 1.0** | Opcional; la hora punta puede crispar más (tuning) |

**Salida:** minutos hasta abandonar = `100 / tasa_drenaje_efectiva`. **Ejemplo:** neutro → `100/(100/30) = 30 min`;
con hacinamiento ×1.5 → `100/(3.33×1.5) ≈ 20 min`.

### F2 · Puntuación de visita

`puntuacion_atendida = clamp(puntuacion_base × factor_espera × factor_trato, 0, 100)`
`factor_espera = 1 − k_espera × (paciencia_consumida / 100)` · `puntuacion_abandono = 0`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `puntuacion_base` | float | **80** (tuning) | Puntuación de una atención neutra sin espera |
| `factor_espera` | float | 0.5–1.0 | Cuanta más paciencia gastó esperando, menos puntúa (`k_espera` default 0.5) |
| `factor_trato` | float | 0.5–1.5 | El 🤝Trato del agente (Personal `factor_trato`); Trato 3 = 1.0 |

**Salida (0–100):** atendida rápida + buen trato → `80×1.0×1.3=104 → 100`; espera media + trato normal →
`80×0.75×1.0 = 60`; al límite + mal trato → `80×0.5×0.7 = 28`; **abandono → 0**.
**ODAC:** al promediar, cada visita pesa por `peso_prioridad` (una Prioritaria cuenta como 2.5 visitas → premia/castiga más).

### F3 · Satisfacción del servicio (media de jornada) + cierre

`satisfaccion_servicio = Σ(puntuacion_visita_i × peso_i) / Σ(peso_i)` sobre las visitas de la jornada

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `peso_i` | float | Doc **1.0** · ODAC `peso_prioridad` (1.0 / 2.5) | Cuánto cuenta esa visita en la media |
| `satisfaccion_servicio` | float | 0–100 | Media viva de la jornada (`sat_actual`) |

**Cierre:** al `nuevo_dia`, `sat_cierre_<servicio> = sat_actual` final; se **resetea** el acumulador. **Sin visitas**
en la jornada → `sat_cierre` = el de la jornada anterior (no cambia). **1ª jornada** → `sat_inicial = 50`.

### F4 · sat → ingresos *(referenciada — dueña: Economía)*

`retorno_dgp = retorno_dgp_min + (retorno_dgp_max − retorno_dgp_min) × (sat_cierre_doc_ayer / 100)`

**Salida:** sat 0 → **0.15** · sat **50 → 0.30** (arranque) · sat 100 → **0.45**. *(Fórmula de Economía; Paciencia
solo aporta `sat_cierre_doc` de la jornada anterior.)*

### F5 · Satisfacción global *(HUD/valoración)*

`sat_global = Σ(satisfaccion_servicio × visitas_servicio) / Σ(visitas_servicio)`

**Salida (0–100):** media ponderada por volumen; **solo HUD** y futura valoración #28. Economía **no** la usa
(cobra por servicio).

## Edge Cases

- **Si la paciencia llega a 0 en el mismo tick en que un puesto la llamaría:** gana la **llamada** — las
  asignaciones de Flujo se evalúan **antes** que los abandonos dentro del tick, y **no** se presenta hoja de
  reclamaciones (no hubo abandono). *Evita el "se fue justo cuando le tocaba" (feel-bad); es determinista.*
- **Si alguien abandona:** genera la **visita de puntuación 0** *y* presenta una **hoja de reclamaciones**
  (PS12). Si abandonó **Documentación**, con `prob_reclamacion` (0.4) aparece además como trámite `reclamacion`
  en ODAC (PS13). Si era una **Prioritaria de ODAC**, la hoja es **grave**. *El abandono duele doble: baja la
  `sat` media y suma una reclamación.*
- **Si la ocupación supera el aforo de la sala:** `mult_hacinamiento` sube y **toda** la gente presente drena
  más rápido (F1). *Quién no cabe (esperar fuera / no generarse) lo decide Flujo/Construcción; aquí solo
  penalizamos a los presentes.*
- **Si a la persona la atienden pero el agente tiene Trato pésimo** (factor_trato 0.5) aunque esperara poco:
  `puntuacion = 80×1.0×0.5 = 40`. *Mal trato hunde la nota aunque no haya cola: el trato importa por sí solo.*
- **Si una jornada cierra sin ninguna visita de un servicio** (p. ej. ODAC toda la madrugada sin denuncias):
  `sat_cierre` = el de la jornada anterior (**no cambia**), evitando división por cero. *Un servicio ocioso no
  premia ni castiga.*
- **Si todas las visitas de la jornada fueron abandonos:** `sat_cierre = 0` → `retorno_dgp` mínimo (0.15) la
  jornada siguiente. *Castigo fuerte pero recuperable — nunca game over directo.*
- **Si `puntuacion_base × factores > 100` o `< 0`:** se aplica `clamp(…, 0, 100)`. La paciencia tampoco baja de
  0 ni sube de 100.
- **Si una `reclamacion` (PS13) abandona en la cola de ODAC:** suma al contador de reclamaciones pero **no**
  genera otra `reclamacion` (sin recursión). *Evita el bucle infinito de reclamaciones de reclamaciones.*
- **Si se guarda a mitad de jornada:** se serializan el **acumulador de la jornada** (Σ puntuaciones, Σ pesos,
  nº visitas), el `sat_cierre` anterior de cada servicio, los contadores `reclamaciones_jornada`/`_mes` y la
  **paciencia de cada persona en cola**. Al cargar, todo **continúa** (determinista, arranca en Pausa).
- **Si el juego está en Pausa:** el reloj no corre → la paciencia **no drena** (Tiempo posee la pausa).
  *Pausar para pensar no penaliza.*
- **Si el trámite en el puesto dura más que la paciencia que le quedaba:** irrelevante — al ser **llamada**, la
  paciencia se **congela** (PS3); una vez atendida no abandona, dure lo que dure la atención.
- **Si cambia la jornada con gente aún esperando:** el cierre promedia solo las visitas **completadas**; los que
  siguen en cola **conservan su barra** (no se resetea) y contarán en la jornada nueva cuando se vayan.
- **Si el aforo de la sala es 0 o no hay sala construida:** `mult_hacinamiento = 1.0` (desactivado, con aviso);
  la gente espera con **drenaje base**. *Un dato de aforo corrupto no debe romper el cálculo.*
- **Si `tolerancia_base_min` llega a 0 o negativo** (dato corrupto): se **clampa al mínimo seguro (15)** con
  aviso, evitando la división por cero en F1. *Igual patrón defensivo que el clamp de `escala_tiempo` (Tiempo)
  y los rangos de Datos.*
- **Si `sat_global` (F5) se calcula sin ninguna visita** (Σ visitas = 0, arranque de partida): muestra
  `sat_inicial` (50) o el último valor conocido; es **solo HUD**, no afecta a ingresos. *Sin división por cero
  en el marcador global.*

## Dependencies

**Este sistema depende de (upstream):**

| Sistema | Tipo | Interfaz de datos |
|---------|------|-------------------|
| **Flujo de Personas y Colas #4** | Hard | Recibe eventos `coge_turno` (arranca barra) y `llamada_a_puesto` (congela); Flujo **ejecuta** el abandono (`persona_abandona`) cuando Paciencia marca 0 y **encola** la `reclamacion` (PS13) ✅ GDD |
| **Tiempo #1** | Hard | El reloj **drena** la paciencia (min de juego); `nuevo_dia` **cierra** la media y `reclamaciones_jornada`; `nuevo_mes` **evalúa/resetea** `reclamaciones_mes`; en Pausa no drena ✅ GDD |
| **Datos y Configuración #2** | Hard | *lee* `aforo_sala_espera` (40/10, hacinamiento) y el tipo `reclamacion` (30 min, Normal, sin tarifa) ✅ GDD (añadido a Datos F2, 2026-07-21) |
| **Personal / Agentes #6** | Soft | *lee* el 🤝Trato (`factor_trato` 0.5–1.5, Personal F3) para F2; sin él, trato neutro (1.0) ✅ GDD |
| **Construcción #7** | Soft | *lee* el aforo de la sala construida (hacinamiento); sin sala → drenaje base ✅ GDD |

**Dependen de este sistema (downstream):**

| Sistema | Tipo | Qué consume |
|---------|------|-------------|
| **Economía #3** | Hard | `sat_cierre_doc` (jornada anterior) → `retorno_dgp` (dinero) ✅ GDD (Economía E7/F1 ya lo cita) |
| **ODAC #9** | Hard | Recibe la carga de `reclamacion` (PS13) y le da a Paciencia sus puntuaciones ponderadas por `peso_prioridad` ✅ GDD (ODAC F3/Deps ya lo citan) |
| **Comodidades de sala #15** | Soft | Modula `mult_comodidad` (baja el drenaje) — futuro |
| **Objetivo de eficiencia (MVP) / Valoración de jefes #28** | Hard/Soft | El contador `reclamaciones` (cuantas menos, mejor) → evaluación/ascenso |
| **Demanda #5** | Soft | ODAC recibe carga extra de Paciencia (reclamaciones), no del generador de demanda *(nota — Fase 5)* |
| **UI/HUD #11 · Feedback #12** | Soft | `sat` por servicio + global, ánimo por persona y contador de reclamaciones para pintar |

**Consistencia bidireccional:** Flujo cita "abandono lo ejecutan Flujo+Paciencia" ✅; Economía ya cita `sat_cierre_doc`
de Paciencia ✅; ODAC cita "la escala 0–100 la posee Paciencia" + la carga de `reclamacion` ✅; Datos añadió
`tramite_reclamacion` ✅; Demanda añadió la nota ✅; **Tiempo ya lista a Paciencia como dependiente ✅.**

## Tuning Knobs

### Knobs propios de Paciencia y Satisfacción

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `tolerancia_base_min` (F1) | 30 | 15–60 | ↑ la gente aguanta más cola (menos abandonos) / ↓ abandonan antes (más presión) | Paciencia |
| `k_espera` (F2) | 0.5 | 0–1 | ↑ esperar hunde más la nota / ↓ la espera casi no penaliza | Paciencia |
| `puntuacion_base` (F2) | 80 | 50–100 | ↑ satisfacción más generosa (dinero más fácil) / ↓ más exigente | Paciencia |
| `k_hacinamiento` (F1) | 1.0 | 0–2 | ↑ el exceso de aforo acelera mucho el drenaje / ↓ el hacinamiento apenas importa | Paciencia |
| `sat_inicial` (F3) | 50 | 0–100 | Arranque sin datos (50 → retorno 0.30, ni premio ni castigo) | Paciencia |
| `prob_reclamacion` (PS13) | 0.4 | 0–1 | ↑ más abandonos de Doc saturan ODAC (bucle más duro) / ↓ menos carga extra | Paciencia |
| `peso_reclamacion_grave` (PS12) | 3 | 1–5 | Cuánto pesa de más una reclamación grave (Prioritaria ODAC abandonada) en la valoración | Paciencia |
| `mult_horapunta` (F1) | 1.0 (MVP) | 1.0–1.3 | Opcional: la hora punta crispa más | Paciencia |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto sobre Paciencia |
|------|-----------|------------------------|
| `factor_trato` (0.5–1.5) | Personal #6 (F3) | Modula `puntuacion_visita` (F2) |
| `peso_prioridad` (1.0 / 2.5) | ODAC #9 | Pondera las visitas de ODAC en la media (F3) |
| `aforo_sala_espera` (40 / 10) | Datos/Construcción | Umbral de hacinamiento (F1) |
| `retorno_dgp_min/max` (0.15 / 0.45) | Datos/Economía | El mapeo `sat → dinero` (F4) |
| `mult_comodidad` (0.6–1.0) | Comodidades #15 | Baja el drenaje (futuro; MVP 1.0) |
| `duracion` de `reclamacion` (30 min) | Datos | Carga que mete cada reclamación en ODAC (PS13) |

**Interacciones entre knobs (clave):**
- **`tolerancia_base_min` × `k_hacinamiento`** definen cuánto aguanta la sala en un pico antes de que se dispare
  la cascada de abandonos.
- **`k_espera` × `puntuacion_base`** definen la **severidad** de la satisfacción (y por tanto del dinero).
- **`prob_reclamacion` × capacidad de ODAC (~128/día)** definen si el bucle de reclamaciones llega a **saturar**
  ODAC.
- **`sat_inicial` × `retorno_dgp`** definen el **arranque económico** (50 → 0.30).

*Nota: `peso_reclamacion_grave` (3) y `peso_prioridad` (2.5) son **deliberadamente distintos** — pesan cosas
diferentes (el **contador de eficiencia/reclamaciones** vs la **media de satisfacción de ODAC**) y se tunean
por separado; no es un descuido.*

**Restricciones:** `paciencia`, `sat`, `puntuacion_visita` ∈ [0,100]; `prob_reclamacion` ∈ [0,1]; `sat_inicial`
default 50; el cierre es siempre por **jornada** (= `nuevo_dia`).

## Visual/Audio Requirements

- **Estilo (art bible):** institucional y **sobrio**, legible; el descontento se **ve** pero **no es
  caricaturesco** (anti-pilar).
- **Ánimo por persona (Pilar 2):** cada persona esperando muestra su estado con **color** — 🟢 Contento /
  🟡 Impaciente / 🔴 Al límite — mediante un pequeño **aro/indicador de humor sobre la silueta**, legible a
  distancia de cámara sin pasar el ratón.
- **Marcador de satisfacción:** medidor 0–100 con banda de color y transición **suave** (no salta).
- **Abandono / reclamación:** al marcharse, gesto **sobrio** de fastidio + una **hoja de reclamaciones** que se
  archiva; nada alarmista.
- **Hacinamiento:** señal ambiental sutil cuando la sala supera el aforo (la sala "se nota" llena).
- **Audio (mínimo):** un cue **discreto** y opcional al abandono; el ambiente de sala lo cubre Feedback/Audio.
  Sin sonoridad recargada.

📌 **Asset Spec** — Tras aprobar el art bible, `/asset-spec system:patience-satisfaction` para los indicadores
de ánimo, el medidor y el icono de reclamación.

## UI Requirements

- **HUD de satisfacción:** medidor `sat` **por servicio** (Doc / ODAC) + **global**; muestra la **media de hoy
  construyéndose** y, junto a ella, el **`sat_cierre` de ayer** (el que fija los ingresos de hoy) → el jugador
  entiende *"lo de hoy fija el dinero de mañana"*.
- **Ánimo por persona:** color por umbral en la sala (ver Visual).
- **Contador de reclamaciones:** `reclamaciones_jornada` y `reclamaciones_mes` como **KPI de eficiencia** (las
  **graves** marcadas aparte).
- **Aviso de hacinamiento:** indicador cuando la ocupación supera el aforo.
- La UI **nunca hardcodea** textos/umbrales; los lee de config.

📌 **UX Flag — Paciencia y Satisfacción**: este sistema tiene UI (HUD de satisfacción/reclamaciones + indicador
de ánimo). En Pre-Producción, `/ux-design` para esas pantallas **antes** de escribir epics; las historias que
toquen esta UI deben citar `design/ux/[pantalla].md`, no el GDD.

## Acceptance Criteria

**Paciencia (PS1–PS5, F1)**
- **AC-PS01** `[Unit]` — GIVEN coge turno THEN `paciencia = 100`.
- **AC-PS02** `[Unit]` — GIVEN neutro (tolerancia 30, mults 1.0) WHEN espera 30 min sin ser llamada THEN `paciencia = 0` y **abandona**.
- **AC-PS03** `[Unit]` — GIVEN hacinamiento ×1.5 WHEN espera THEN abandona a **~20 min** (drena más rápido).
- **AC-PS04** `[Integration]` — GIVEN esperando WHEN es **llamada a puesto** THEN la paciencia se **congela** (no drena ni abandona) hasta el fin del trámite.
- **AC-PS05** `[Unit]` — umbrales de ánimo: 80 → 🟢, 50 → 🟡, 20 → 🔴.

**Puntuación de visita (PS6, F2)**
- **AC-PS06** `[Unit]` — GIVEN atendida sin espera, trato neutro (1.0) THEN `puntuacion = 80`.
- **AC-PS07** `[Unit]` — GIVEN atendida al límite (consumió ~100) + trato 0.7 THEN `puntuacion ≈ 28`.
- **AC-PS08** `[Unit]` — GIVEN abandono THEN `puntuacion_visita = 0`.
- **AC-PS09** `[Unit]` — GIVEN `base×factores = 105` THEN `clamp → 100`.

**Satisfacción y cierre diario (PS7–PS11, F3–F5)**
- **AC-PS10** `[Unit]` — GIVEN 1ª jornada sin datos THEN `sat_cierre_doc = sat_cierre_odac = 50`.
- **AC-PS11** `[Integration]` — GIVEN varias visitas WHEN `nuevo_dia` THEN `sat_cierre` = media ponderada de sus puntuaciones y el acumulador se **resetea**.
- **AC-PS12** `[Unit]` — GIVEN ODAC con una VioGén (peso 2.5) y una Normal (1.0) THEN la media **pondera 2.5:1**.
- **AC-PS13** `[Integration]` — GIVEN jornada sin visitas de ODAC WHEN `nuevo_dia` THEN `sat_cierre_odac` = el anterior (sin división por cero).
- **AC-PS14** `[Integration]` — GIVEN `sat_cierre_doc = 50` de ayer WHEN se cobran trámites hoy THEN `retorno_dgp = 0.30` **fijo toda la jornada** (no cambia intra-día).

**Reclamaciones (PS12, PS13)**
- **AC-PS15** `[Unit]` — GIVEN un abandono THEN `reclamaciones_jornada += 1` y `reclamaciones_mes += 1`.
- **AC-PS16** `[Integration]` — GIVEN abandono de Documentación y `prob_reclamacion = 1.0` (test) THEN aparece un trámite `reclamacion` (30 min, Normal) en la cola de ODAC.
- **AC-PS17** `[Integration]` — GIVEN una `reclamacion` que abandona en ODAC THEN suma al contador pero **NO** genera otra (sin recursión).
- **AC-PS18** `[Unit]` — GIVEN abandono de una **Prioritaria de ODAC** THEN la hoja se marca **grave**.
- **AC-PS19** `[Integration]` — GIVEN empate llamada-vs-abandono el mismo tick THEN gana la **llamada** y **no** hay hoja.
- **AC-PS20** `[Unit]` — GIVEN `nuevo_mes` THEN `reclamaciones_mes` se evalúa y **resetea a 0**.

**Guardado, pausa y determinismo**
- **AC-PS21** `[Unit]` — GIVEN save a mitad de jornada WHEN se carga THEN paciencias, acumulador y contadores se **restauran**; arranca en Pausa.
- **AC-PS22** `[Unit]` — GIVEN Pausa WHEN pasa tiempo real THEN la paciencia **no drena**.
- **AC-PS23** `[Unit]` — GIVEN misma semilla + misma secuencia de esperas WHEN se ejecuta dos veces THEN los abandonos son **idénticos**.

## Open Questions

| # | Pregunta | Dominio | Cuándo se resuelve | Estado |
|---|----------|---------|--------------------|--------|
| 1 | **Valores semilla** (`tolerancia_base_min 30`, `k_espera 0.5`, `puntuacion_base 80`, `k_hacinamiento 1.0`, `prob_reclamacion 0.4`, `peso_reclamacion_grave 3`, `sat_inicial 50`) — ¿dan una curva de presión divertida (ni muerta ni imposible)? | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Reconciliación Fase 5** — (a) Economía `retorno_dgp` usa `sat_cierre_doc` de la jornada anterior; (b) Datos +tipo `reclamacion` (ODAC, 30 min, Normal, sin tarifa); (c) ODAC nota carga variable + R5; (d) Demanda nota (carga de Paciencia, no del generador); (e) registro (`sat_inicial`, `prob_reclamacion`, `tramite_reclamacion`, referenced_by). | Consistencia (este proyecto) | — | ✅ Aplicada 2026-07-21 |
| 3 | **Objetivo / ascenso (decisión usuario 2026-07-22):** ascender a **Inspector** requiere **1 año de juego (48 jornadas) + valoración de jefes ≥ 75 % + curso de ascenso superado**, evaluado **solo en enero** (si no cumples, esperas al enero siguiente). Es **post-MVP** (#18 Ascensos + #28 Valoración + #29 Formación). **En el MVP:** la **valoración de jefes (#28)** es el **marcador visible** que alimentan `sat` + `reclamaciones` + reputación de ODAC → da consecuencia a ODAC ya en el MVP, aunque el ascenso efectivo llegue con #18. | Ascensos #18 / Valoración #28 / Formación #29 | Post-MVP (marcador ya en MVP) | ✅ Modelo decidido; sistemas post-MVP |
| 4 | **¿Atender bien una `reclamacion` mitiga algo** (mini +sat, o "cierra" la hoja) o solo cuenta como visita normal? | Diseño (Paciencia/ODAC) | Playtest MVP | Abierta |
| 5 | **`mult_horapunta`**: ¿se activa en MVP (la hora punta crispa más) o queda a 1.0 hasta tener datos? | Balance / playtest | 1er playtest MVP | Abierta |
| 6 | **Paciencia por tipo de persona** (víctimas, mayores, urgencias) — MVP usa base común; ¿merece matiz por perfil más adelante? | Diseño (Paciencia) | Post-MVP | Diferida |
| 7 | **Boca a boca**: ¿la reputación/satisfacción debería influir en la **demanda futura** (más/menos gente)? ¿o eso lo posee Demanda/#28? | Demanda #5 / Valoración #28 | Al diseñar #28 | Diferida |
