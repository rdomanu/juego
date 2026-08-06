# Quick Design Spec — Impresora de DNI (mecánica compartida, cola FIFO)

> **Status**: Decidido — listo para implementación (4 decisiones fijadas por el usuario, 2026-08-06)
> **Author**: systems-designer (subagente)
> **Created**: 2026-08-06
> **Extiende**: [impresora-documentos-tramite.md](../gdd/impresora-documentos-tramite.md) (DISEÑO CERRADO,
> implementado en `src/core/impresora/`) — reutiliza su patrón de viaje/fases, pero **no lo modifica**.
> **Toca (numéricamente, sin editar aquí)**: `datos/comodidades/impresora_dni.tres`.
> **No toca**: `src/`, `tools/` (dominio de otro agente en curso).

## Overview

La impresora de DNI es una comodidad **GRANDE** (huella 2×1), de **colocación libre** por el jugador —a
diferencia de la impresora de documentos pequeña, que se coloca automáticamente detrás del puesto—, y
**COMPARTIDA por varios puestos de Documentación**. Extiende el patrón ya implementado del "viaje del
papel" (el funcionario se levanta, va, coge el documento, vuelve) a los trámites de **DNI y Pasaporte**,
que hoy **no** disparan ese viaje. La diferencia clave frente al sistema base es que aquí, al ser un
recurso compartido entre muchas mesas, aparece **cola FIFO visible**: si la máquina está ocupada, el
funcionario espera de pie, y esa espera tiene coste — un funcionario que se ha desesperado en la cola
rinde peor en su siguiente trámite. El **ratio impresoras : puestos** se convierte así en una decisión de
capacidad real del jugador (1:10 atasca, 3-4:10 fluye), simétrica a la lógica de dotar de personal.

## Player Fantasy

*"Mi sala de Documentación es una oficina de verdad: se ve a la gente ir a por el DNI recién impreso, y
si escatimo en impresoras, se nota — hay cola, hay caras largas, y mi equipo va más lento."* El jugador
**ve** el cuello de botella antes de que un informe se lo diga: una fila de funcionarios plantados junto a
la máquina es una señal ambiental inmediata (Pilar 2, "la comisaría está viva") de que toca invertir. Es
la misma tensión de capacidad que ya vive en Personal (¿ficho más gente?) trasladada al **equipamiento**:
¿compro una impresora más, o dejo que la cola se coma la eficiencia?

## Detailed Rules

**R1 · Objeto.** `impresora_dni` es un mueble de **huella 2×1** (grande, como pidió el usuario), de
**colocación libre** por el jugador en cualquier celda de suelo válida de **su sala de Documentación**
(ámbito de la cola: **por sala**, decisión tomada — ver Decisiones Tomadas #1) — no se auto-coloca "detrás
del puesto" como la impresora de documentos pequeña, porque no pertenece a un puesto: pertenece a la sala.

**R1b · Obligatoriedad y precio (decisión tomada, ver Decisiones Tomadas #2).** La impresora de DNI es
**OBLIGATORIA**: toda sala de Documentación necesita **mínimo 1** para poder construirse/ampliarse —mismo
mecanismo de "requisitos mínimos de sala" ya implementado en el sistema base (`impresora-documentos-tramite.md`,
P1)—. A diferencia de la impresora de documentos pequeña (600 €, precio bajado precisamente por ser
obligatoria), la de DNI **mantiene su precio actual de 2.200 €** por decisión explícita del usuario, que
**anula** para este objeto la regla general "obligatoria ≈ no debe ser un lujo". Implicación de diseño:
abrir o ampliar una sala de Documentación exige **2.200 € más** que abrir/ampliar ODAC — una inversión
gorda y deliberada, coherente con ser el objeto más caro y más grande del catálogo de comodidades.

**R2 · Trámites cubiertos.** Cubre exactamente los dos trámites de Documentación que el sistema base
(P2 de `impresora-documentos-tramite.md`) dejó **fuera**: **DNI** (12 min) y **Pasaporte** (15 min). ODAC
(denuncias) y la expedición de TIE siguen usando la impresora de documentos pequeña, sin cambios. Los dos
sistemas son **disjuntos por tipo de trámite** — ningún trámite dispara los dos viajes.

**R3 · Disparo del viaje.** Igual que el sistema base: cuando al trámite le quedan `T_AVISO_dni` minutos
de juego, el funcionario inicia el viaje a la impresora de DNI **libre más cercana** dentro de su sala
(mismo criterio de paso `distancia_en_celdas` que el resto de viajes). Si el trámite "acabaría"
antes de que vuelva, queda en fase **ESPERANDO_DOCUMENTO** (reutiliza la fase ya implementada).

**R4 · Máquina ocupada → cola FIFO.** Si al llegar la máquina elegida está en uso, el funcionario se
**pone a la cola de ESA máquina** (cola **por máquina**, no una cola única compartida entre todas —
decisión tomada, ver Decisiones Tomadas #3) y espera de pie, visible, en orden de llegada. Sin favoritismo: **no existe** la
mecánica de "colar" (esa es exclusiva de la paciencia de ciudadanos, `patience-satisfaction.md` PS-colado)
para esta cola de personal — sería confuso mezclar los dos sistemas de espera. Empates de llegada
simultánea se resuelven por una clave secundaria determinista (id del agente), igual que el patrón de
empate de Paciencia (AC-PS19).

**R5 · Servicio y vuelta.** Cada uso de la máquina tarda `t_recogida_dni` minutos (imprimir + recoger).
Al terminar, el funcionario deja la máquina libre para el siguiente de la cola y inicia el viaje de vuelta
a su mesa (mismo patrón que el sistema base).

**R6 · Consecuencia de esperar (NUEVO gancho, ver Formulas F4).** Un funcionario que esperó más de
`T_TOLERANCIA_FUNC` minutos en la cola aplica un **malus temporal** (`mult_enfado_funcionario`) a la
duración de su **siguiente** trámite — se le nota el cabreo una vez, luego se le pasa. Esto **no existe
hoy** en ningún GDD (Personal `PA10` deja la Motivación como atributo base estático, sin fatiga dinámica —
ver Dependencies); se propone como el mínimo necesario para que "cola visible" tenga **consecuencia de
juego**, no solo estética.

## Formulas

### F1 · Tiempo de viaje de ida (reutiliza el patrón base)

`t_viaje_ida = distancia_celdas / velocidad_celdas_por_min`

| Símbolo | Tipo | Rango | Descripción |
|---|---|---|---|
| `distancia_celdas` | float | ≥ 0 | Distancia en el plano, mesa → impresora elegida (Construcción) |
| `velocidad_celdas_por_min` | float | > 0 | Velocidad de viaje del funcionario; **reutiliza el knob ya existente** de Flujo (viajes al café / al papel) — valor exacto fuera del alcance de este spec, lo calibra el agente de `src/` |
| `t_viaje_ida` | float | ≥ 0 min | Minutos de juego del trayecto de ida |

**Salida:** no acotada por arriba (una impresora mal colocada puede estar arbitrariamente lejos); en la
práctica, acotada por el tamaño de la sala. **Ejemplo ilustrativo** (valores de muestra, no calibrados):
`distancia_celdas = 4`, `velocidad_celdas_por_min = 1.0` → `t_viaje_ida = 4 min` (ida+vuelta ≈ 8 min).

> ⚠️ **Aviso de balance:** el trámite de DNI dura solo **12 min** (frente a los 15-30 min de ODAC/TIE que
> ya absorbían el viaje base). Un ida+vuelta de varios minutos pesa **proporcionalmente mucho más** aquí.
> Colocar la impresora de DNI **cerca** de las mesas que sirve importa más que en el sistema base — es
> precisamente la palanca que da sentido a la colocación libre (regla del usuario).

### F2 · Utilización de la cola compartida (ρ) — la fórmula del ratio

`ρ = (N_puestos / t_tramite_prom) × t_recogida_dni / N_impresoras`

| Símbolo | Tipo | Rango | Descripción |
|---|---|---|---|
| `N_puestos` | int | ≥ 0 | Puestos que tramitan DNI/Pasaporte en la sala de Documentación (ámbito decidido: por sala) |
| `t_tramite_prom` | float | min | Duración media ponderada de los trámites que imprimen aquí — DNI 12 min / Pasaporte 15 min → **≈13 min** con mezcla típica 70/30 |
| `t_recogida_dni` | float | min | Tiempo de servicio de la máquina por uso (tuning, ver Knobs) |
| `N_impresoras` | int | ≥ 1 | Impresoras de DNI construidas en la sala (mínimo 1, obligatoria — R1b) |
| `ρ` | float | ≥ 0, sin techo | Utilización del recurso. `ρ ≥ 1` = la cola **crece sin límite** (inestable); `ρ` bajo = fluido |

**Salida:** `ρ ∈ [0, ∞)`, no clampada — un `ρ ≥ 1` es una señal de diseño real ("has infradotado"), no un
error a ocultar. **Ejemplo con `t_recogida_dni = 1.5 min`, `N_puestos = 10`, `t_tramite_prom = 13 min`**
(`λ_total = 10/13 ≈ 0.769` trámites/min):

| `N_impresoras` | ρ | Lectura |
|---|---|---|
| 1 | **1.15** | inestable — la cola crece sin parar (esto es el "1 para 10 mesas, problemas" del usuario) |
| 2 | 0.58 | zona intermedia — se nota, no rompe |
| 3 | **0.38** | fluido |
| 4 | **0.29** | muy fluido, casi siempre libre |

### F3 · Tiempo medio de espera en cola (Wq, aproximación M/M/c de Sakasegawa)

`Wq ≈ ( ρ^(√(2×(N_impresoras+1))) / (N_impresoras × (1 − ρ)) ) × t_recogida_dni`  — válida solo si `ρ < 1`

| Símbolo | Tipo | Rango | Descripción |
|---|---|---|---|
| `ρ` | float | [0, 1) | Utilización (F2); fuera de este rango la cola es inestable, `Wq → ∞` |
| `N_impresoras` | int | ≥ 1 | Nº de máquinas (servidores) |
| `t_recogida_dni` | float | min | Tiempo de servicio |
| `Wq` | float | ≥ 0 min | Espera media antes de llegar a la máquina |

**Salida:** no acotada (crece hacia infinito cuando `ρ → 1`); es exactamente el comportamiento que se
quiere modelar (la cola "se dispara"). **Ejemplo (misma base que F2):**

| `N_impresoras` | ρ | `Wq` (aprox.) |
|---|---|---|
| 1 | 1.15 | **inestable — no aplica la fórmula; la cola crece sin límite** |
| 2 | 0.58 | ≈ 0.46 min (≈ 28 s) |
| 3 | 0.38 | ≈ 0.05 min (≈ 3 s) |
| 4 | 0.29 | ≈ 0.01 min (≈ 0.6 s) |

Estos números confirman el objetivo del usuario con los knobs por defecto (F. Tuning Knobs): **1:10 se
atasca de verdad**, **2:10 se nota pero aguanta**, **3-4:10 es fluido**.

> ⚠️ **Nota de implementación (afecta a los números, no a la intención):** F3 asume la **cola única
> compartida** (el modelo M/M/c clásico: un funcionario que llega va a la primera máquina libre de
> cualquiera de las `N_impresoras`). La regla R4 de este spec usa en cambio **colas separadas por
> máquina** (más simple de visualizar e implementar — la fila junto a "esa" impresora). Con colas
> separadas, la espera real será **algo mayor** que la tabla de arriba (es un resultado conocido de teoría
> de colas: varias filas separadas rinden peor que una fila única que alimenta al primer hueco libre —
> "por qué el banco tiene una sola fila serpenteante"). Los valores de F3 son, por tanto, el **mejor caso
> teórico**; útiles para fijar el orden de magnitud y calibrar `t_recogida_dni`, no como cifra exacta.

### F4 · Malus de eficiencia por enfado (NUEVO gancho — no existe hoy, ver Dependencies)

`mult_enfado_funcionario = clamp( 1 + k_enfado × max(0, t_espera_real − T_TOLERANCIA_FUNC) , 1.0 , 1.3 )`

| Símbolo | Tipo | Rango | Descripción |
|---|---|---|---|
| `t_espera_real` | float | ≥ 0 min | Minutos que ESE funcionario esperó en la cola esta vez |
| `T_TOLERANCIA_FUNC` | float | min (tuning) | Espera que aguanta sin inmutarse |
| `k_enfado` | float | (tuning) | Cuánto penaliza cada minuto de espera de más |
| `mult_enfado_funcionario` | float | **[1.0, 1.3]** | Multiplica `duracion_efectiva` de su **siguiente** trámite (se aplicaría junto a `modificador_produccion` de Personal F2) |

**Salida acotada a `[1.0, 1.3]`** — el mismo techo superior que ya usa Personal F2 (`modificador_produccion
∈ [0.5, 1.3]`), para no crear un multiplicador "más roto" que el peor fichaje posible del juego, y para
que el efecto **se disipe** tras un trámite (no se acumula: es un malus de un solo uso, ver Edge Cases).
**Ejemplo con `T_TOLERANCIA_FUNC = 1 min`, `k_enfado = 0.15`:**

- Escenario 1 impresora (`Wq` inestable, esperas reales largas, p. ej. 6 min): `1 + 0.15×(6−1) = 1.75` →
  clamp → **1.3** (30 % más lento en su siguiente trámite — se nota).
- Escenario 3 impresoras (`Wq ≈ 3 s ≈ 0.05 min`, por debajo de la tolerancia): `max(0, 0.05−1) = 0` →
  **1.0** (sin penalización — coherente con "fluido").

**Nota de bucle de realimentación (systems-designer):** este malus crea un **bucle positivo** (autoalimentado):
poca dotación → cola → enfado → trámites más lentos → cola aún más larga. Es **intencional** (es
exactamente la consecuencia que pide el diseño), pero está **amortiguado a propósito** en dos puntos para
que no sea una espiral de la muerte: (a) el clamp a 1.3 le pone techo, y (b) el malus **se consume en un
solo trámite** y no se acumula entre viajes sucesivos. Sin estos dos frenos, el bucle podría degenerar en
una sala completamente paralizada tras un pico de demanda.

## Edge Cases

- **Si se intenta construir o ampliar una sala de Documentación sin al menos 1 impresora de DNI**: se
  **rechaza** en el momento de construir (gate de Construcción, mismo mecanismo que el sistema base P1 —
  R1b). *Es obligatoria; no hay sala de Documentación válida sin ella.*
- **Si un save ANTIGUO (partida guardada antes de esta mecánica) tiene una sala de Documentación sin
  ninguna impresora de DNI**: la sala queda marcada **incompleta** al cargar (mismo espíritu que el aviso
  de la fachada/impresora base para saves viejos, pero **sin auto-colocación**: al ser un objeto 2×1 de
  colocación libre, plantarlo automáticamente podría chocar con mobiliario ya existente). Mientras esté
  incompleta, **sus puestos no tramitan DNI/Pasaporte** (siguen operando denuncias/TIE si la sala fuera
  mixta) hasta que el jugador coloque manualmente al menos una impresora. *Simple, seguro, y coherente con
  "no se auto-coloca" (R1): se avisa y se bloquea la función, no se inventa una posición.*
- **Si la impresora elegida se demuele mientras el funcionario está de camino o en la cola**: vuelve con
  las manos vacías (mismo patrón que el sistema base) y se reevalúa como "sin impresora accesible" del
  punto anterior. *Coherencia con la regla ya cerrada de la impresora de documentos.*
- **Si todas las impresoras de DNI del ámbito están ocupadas y llegan varios funcionarios a la vez**: cada
  uno se une a la cola de la máquina que le tocó por "más cercana" (R4); dos llegadas al mismo instante a
  la misma cola se ordenan por una clave secundaria determinista (id de agente), nunca por azar no
  sembrado. *Determinismo intacto, mismo patrón que Paciencia PS19.*
- **Si el turno/servicio cierra con un funcionario a mitad de cola o de camino**: termina el ciclo
  (compromiso de servicio, mismo patrón que Personal PA5/PA6 con atenciones en curso) — no se le corta el
  viaje a medias por el cierre de jornada.
- **Si la cola de una máquina crece mucho (visual)**: se cae en el mismo problema de "muñecos apilados" de
  cualquier fila; se recomienda un tope de posiciones visibles (p. ej. 5-6) con contador "+N esperando" —
  **flag a UX**, no es una decisión de sistemas.
- **Si `mult_enfado_funcionario` se calcularía repetidamente en cadena** (el funcionario encadena dos
  esperas largas seguidas sin un trámite neutro entre medias): el malus **no se acumula multiplicativamente
  entre viajes** — cada cálculo parte de `1.0` y se clampa de nuevo a `[1.0, 1.3]` en cada uso (no
  `mult_anterior × mult_nuevo`). *Frena el bucle positivo de F4, ver nota de realimentación.*
- **Si `t_espera_real` es negativo o corrupto** (dato imposible): se clampa a `0` antes de F4 — mismo
  patrón defensivo que el resto del proyecto (clamps de Personal/Paciencia/Tiempo).
- **Si hay varias salas de Documentación en el edificio**: la cola **no se comparte entre salas** — el
  ámbito es siempre la sala (decisión tomada, #1). Cada sala resuelve su propia cola con sus propias
  impresoras. *Evita viajes absurdos cruzando la comisaría.*

## Dependencies

**Este sistema depende de (upstream):**

| Sistema | Tipo | Interfaz |
|---|---|---|
| **Impresora de documentos** ([impresora-documentos-tramite.md](../gdd/impresora-documentos-tramite.md)) | Hard | Reutiliza el patrón de fases (viaje → `ESPERANDO_DOCUMENTO`) y `distancia_en_celdas`; **no lo modifica**, es un objeto y una cola nuevos y distintos |
| **Documentación** (`documentation.md`, DO1) | Hard | *lee* `duracion_min`/tarifa de DNI (12 min/12€) y Pasaporte (15 min/30€) — los dos trámites que disparan esta mecánica |
| **Personal / Agentes** (`staff-agents.md`, F2) | Hard | *lee* `modificador_produccion`; **propone extender** su pipeline con `mult_enfado_funcionario` (F4, NUEVO) — hoy Personal PA10 solo tiene Motivación como atributo base estático, **sin** fatiga/enfado dinámico; este spec es el primer gancho de ese tipo |
| **Flujo de Personas y Colas** (`flow-queues.md`, F1) | Hard | *lee* `duracion_efectiva = duracion_min × modificador_produccion`; **propone** que pase a `× mult_enfado_funcionario` cuando aplique — cambio a proponer al dueño de Flujo, no aplicado aquí |
| **Construcción y Distribución** (`construction-layout.md`) | Hard | Huella 2×1, colocación libre (no automática), medición de `distancia_celdas` y accesibilidad |
| **Economía / Presupuesto** (`economy-budget.md`) | Hard | Coste de construcción y mantenimiento — ver choque con `datos/comodidades/impresora_dni.tres` abajo |

**Dependen de este sistema (downstream):**

| Sistema | Tipo | Qué recibe |
|---|---|---|
| **Paciencia y Satisfacción** (`patience-satisfaction.md`) | Soft (indirecto) | Un trámite más lento por `mult_enfado_funcionario` alarga la espera del **ciudadano** en el puesto → drena más su paciencia (F1 de Paciencia) — efecto indirecto vía Flujo, no una lectura directa |
| **UI/HUD** | Soft | Visualiza la cola de funcionarios (fila junto a la máquina) y, opcional, un indicador de "impresora saturada" por sala |

**Cambios pendientes en `datos/comodidades/impresora_dni.tres`** (decididos aquí, NO editados en este
documento — a aplicar al implementar):

- **Se sustituye** el bonus pasivo actual (coherente hoy con el patrón `mult_equipamiento` de Flujo F1,
  citado en `patience-satisfaction.md`) por el mecanismo **activo** de este spec (viaje + cola + F4).
  Decisión tomada (#4): no conviven los dos efectos sobre el mismo objeto.
  - `descripcion` ("el documento sale en la mitad de tiempo") queda **obsoleta** y necesita reescribirse
    para reflejar la mecánica nueva (viaje del funcionario + cola compartida), no un bonus de velocidad.
  - `aporte = 6.0` deja de alimentar `mult_equipamiento` (Flujo F1) — su función pasa a expresarse vía los
    knobs propios de esta mecánica (F. Tuning Knobs: `T_AVISO_dni`, `t_recogida_dni`), no vía `aporte`. Si
    el esquema `Comodidad` sigue exigiendo un `aporte` numérico por compatibilidad, su valor y su
    interpretación deben revisarse al implementar (posible campo muerto o repropuesto).
- **`coste_construccion_eur = 2200` se mantiene** — excepción explícita del usuario a la regla "obligatoria
  ≈ 600 €" (R1b, Decisiones Tomadas #2). No requiere cambio en el `.tres`.
- `coste_mantenimiento_dia_eur = 3` — sin decisión tomada aquí; se deja como está salvo que el balance de
  implementación indique lo contrario (fuera de alcance de este spec).

## Tuning Knobs

| Knob | Default propuesto | Rango seguro | Si ↑ / Si ↓ | Owner |
|---|---|---|---|---|
| `T_AVISO_dni` (F. Detailed Rules R3) | **3 min** | 1–5 min | ↑ el viaje se inicia antes (más margen, menos `ESPERANDO_DOCUMENTO`) / ↓ más apurado, más riesgo de alargar el trámite visible | Impresora DNI |
| `t_recogida_dni` (F2/F3) | **1.5 min** | 0.5–3 min | ↑ cada uso ocupa más la máquina (satura antes con menos puestos) / ↓ la máquina rota más rápido, aguanta más puestos por unidad | Impresora DNI |
| `T_TOLERANCIA_FUNC` (F4) | **1 min** | 0–3 min | ↑ el funcionario aguanta más cola sin cabrearse (malus más raro) / ↓ se enfada con casi cualquier espera | Impresora DNI |
| `k_enfado` (F4) | **0.15 / min** | 0.05–0.30 | ↑ cada minuto de espera de más penaliza mucho (bucle más agresivo) / ↓ apenas se nota | Impresora DNI |
| tope superior de `mult_enfado_funcionario` (F4) | **1.3** (fijo, igual que Personal F2) | no tocar sin tocar también Personal F2 | mantiene el enfado dentro del peor caso ya existente de un mal fichaje | Personal (referenciado) |
| `N_impresoras` construidas (decisión del jugador, mínimo 1 obligatorio — R1b) | ≥ 1 | ≥ 1 | El **ratio real de partida** frente a `N_puestos`: 1:10 objetivo-atasco, 3-4:10 objetivo-fluido (ver F2/F3) | Jugador |
| Ámbito de la cola compartida | **sala** (fijo, decidido) | — | Ratio legible por habitación; no se comparte entre salas | Decidido (#1) |

**Restricciones:** `t_recogida_dni, T_AVISO_dni, T_TOLERANCIA_FUNC, k_enfado ≥ 0`;
`mult_enfado_funcionario ∈ [1.0, 1.3]`; `ρ` no se clampa (es una señal, no un valor de juego).

## Acceptance Criteria

- **AC-DNI01** `[Unit]` — GIVEN `N_impresoras=1`, `N_puestos=10`, knobs por defecto THEN `ρ ≥ 1` (F2) y la
  cola de esa máquina **crece sin límite** durante una simulación de jornada (no se estabiliza).
- **AC-DNI02** `[Unit]` — GIVEN `N_impresoras=3`, `N_puestos=10`, knobs por defecto THEN `ρ < 0.4` (F2) y
  `Wq` medio de la cola < `T_TOLERANCIA_FUNC` (F3) — fluido, malus de enfado raro.
- **AC-DNI03** `[Unit]` — GIVEN `N_impresoras=4`, `N_puestos=10` THEN `Wq` medio ≈ 0 (F3) — impresoras
  casi siempre libres.
- **AC-DNI04** `[Unit]` — GIVEN un funcionario con `t_espera_real = 6 min`, `T_TOLERANCIA_FUNC = 1`,
  `k_enfado = 0.15` THEN `mult_enfado_funcionario` se clampa a **1.3** (F4).
- **AC-DNI05** `[Unit]` — GIVEN `t_espera_real ≤ T_TOLERANCIA_FUNC` THEN `mult_enfado_funcionario = 1.0`
  (sin penalización).
- **AC-DNI06** `[Integration]` — GIVEN un funcionario penalizado por F4 WHEN completa su siguiente trámite
  THEN el malus **no se aplica** a un tercer trámite salvo que vuelva a esperar de más (no se acumula).
- **AC-DNI07** `[Integration]` — GIVEN la impresora de DNI demolida mientras un funcionario está de camino
  o en cola THEN vuelve con las manos vacías y se re-evalúa como "sin impresora accesible".
- **AC-DNI08** `[Integration]` — GIVEN dos funcionarios que llegan a la vez a la misma cola libre THEN el
  orden resultante es **determinista** (misma semilla/estado → mismo orden) reproducible entre partidas.
- **AC-DNI09** `[Integration]` — GIVEN se intenta construir o ampliar una sala de Documentación **sin**
  ninguna impresora de DNI THEN se **rechaza** (gate de Construcción, R1b — obligatoria).
- **AC-DNI10** `[Integration]` — GIVEN un save antiguo con una sala de Documentación sin impresora de DNI
  WHEN se carga THEN la sala queda **marcada incompleta** y sus puestos **no** tramitan DNI/Pasaporte
  hasta que el jugador coloque manualmente al menos una (sin auto-colocación).

## Decisiones Tomadas (2026-08-06)

1. **Ámbito de la cola compartida: POR SALA** (recomendación del systems-designer, aceptada). El ratio
   1:10 / 3-4:10 se lee de un vistazo por habitación de Documentación; la cola nunca se comparte entre
   salas distintas del mismo edificio (Edge Cases, R1/R3).

2. **La impresora de DNI es OBLIGATORIA por sala de Documentación, manteniendo el precio de 2.200 €**
   (decisión explícita del usuario — **anula** para este objeto la regla general "obligatoria ≈ 600 €" que
   sí aplica a la impresora de documentos pequeña). Implicación de diseño: abrir o ampliar una sala de
   Documentación exige 2.200 € más que abrir/ampliar ODAC — inversión gorda y deliberada (R1b). Como no
   puede haber sala de Documentación sin ella, el caso "cero impresoras" solo puede darse en **saves
   antiguos** (previos a esta mecánica): se resuelve marcando la sala como **incompleta** al cargar (sin
   auto-colocación, por ser un objeto 2×1 de colocación libre) — sus puestos no tramitan DNI/Pasaporte
   hasta que el jugador coloque una manualmente (Edge Cases, AC-DNI09/10).

3. **Cola POR MÁQUINA** (recomendación del systems-designer, aceptada) — no una cola única compartida que
   enruta al hueco libre más próximo. Más simple de implementar y de visualizar (R4); los tiempos de F3
   quedan documentados como "mejor caso teórico" frente a esta implementación real.

4. **El bonus pasivo actual del `.tres` ("sale en la mitad de tiempo", vía `mult_equipamiento`) SE
   SUSTITUYE por la mecánica activa de viaje + cola** (recomendación del systems-designer, aceptada). Al
   implementar, `descripcion` y `aporte` de `datos/comodidades/impresora_dni.tres` necesitan retoque
   (ver Dependencies) para dejar de describir/alimentar el bonus pasivo retirado.
