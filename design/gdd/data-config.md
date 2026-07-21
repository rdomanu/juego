# Datos y Configuración

> **Status**: Designed (pendiente de /design-review)
> **Author**: manu.rdo + Claude (systems-designer)
> **Last Updated**: 2026-07-19
> **Last Verified**: 2026-07-19
> **Implements Pillar**: Infraestructura del principio "valores data-driven, nunca hardcoded" (sostiene el Pilar 4 — "Tu comisaría, tus decisiones")
>
> **Nota de proceso**: redactado y **revisado** en modo *lean* (hilo principal; los subagentes de estudio fallan con el error "1M context"). `/design-review` del 2026-07-19: veredicto **NEEDS REVISION (leve)**; ítems abordados en esta misma sesión — Escenario semilla completado (`servicios_activos`, `rango_requerido`), aforo Doc reconciliado a 40, R5/cita aclarada, registro `entities.yaml` ampliado, AC afinados. Historial en `design/gdd/reviews/data-config-review-log.md`.

## Overview

El sistema de **Datos y Configuración** es el catálogo data-driven del juego: la capa Foundation (sin
lógica propia) donde se definen, **fuera del código**, *qué cosas existen* en la comisaría y *con qué
forma y qué valores*. Es un diccionario de **definiciones** —tipos de trámite (DNI, Pasaporte, TIE),
tipos de denuncia de ODAC, tipos de puesto y sala, tipos de agente, y las tablas de costes— que todos
los demás sistemas leen como su fuente de verdad. Su regla rectora es el principio del proyecto *"los
valores de juego son data-driven, nunca hardcodeados"*: ningún precio, duración ni coste vive incrustado
en la lógica; todo se declara aquí y se ajusta sin tocar programación.

A nivel técnico es infraestructura pura, pero **el jugador nota lo que habilita**: que haya *variedad*
de trámites y denuncias que atender (no una cola monótona), que cada puesto, sala y agente tenga un
*coste y una función distinguibles* que hacen que construir y contratar sean decisiones reales, y que el
juego pueda **rebalancearse y crecer** (añadir un nuevo trámite o tipo de sala) editando datos en vez de
reescribir sistemas. Sin esta capa no habría un lenguaje común de "cosas del juego": cada sistema
inventaría el suyo y se desincronizarían.

**Regla de propiedad (alcance híbrido):** este documento es la **fuente única del esquema y del catálogo
con valores semilla**. Los GDDs de dominio (Economía, Documentación, ODAC, Personal, Construcción) **no
duplican** esos números: documentan el *porqué*, los *rangos seguros* y el *tuning* de los campos de su
competencia, y **apuntan** a este catálogo. Los valores compartidos se registran en
`design/registry/entities.yaml` con `source: design/gdd/data-config.md`.

> **Fuera de alcance (→ ADR):** el *formato* de los datos (Godot Resource `.tres` vs JSON vs otra
> fuente) y el *mecanismo de carga* no se deciden aquí; son una decisión de arquitectura futura. Este
> GDD respeta las constantes ya fijadas por el Sistema de Tiempo y no redefine ninguna.

## Player Fantasy

**Encuadre: indirecto.** El jugador nunca "usa" ni ve los datos; siente lo que hacen posible. Datos y
Configuración es infraestructura, así que su fantasía es la de los sistemas a los que da forma, no una
propia. Lo que esta capa garantiza emocionalmente es **variedad legible y decisiones con peso**:

- **"Cada persona que entra quiere algo concreto."** Que un ciudadano venga a por el DNI, otro a renovar
  el pasaporte y otro a poner una denuncia por hurto —cada uno con su duración y su trámite— es lo que
  convierte la sala de espera en *una comisaría viva* (Pilar 2) y no en una cola anónima. Esa diversidad
  nace del catálogo.
- **"Mis piezas son distintas, así que colocarlas es decidir."** Que un puesto de TIE no haga DNI, que
  una sala cueste lo que cuesta, que contratar a un agente tenga un precio y una función definidos: son
  los datos los que hacen que construir y asignar sean **elecciones reales** y no relleno (Pilar 4). Si
  todo fuese intercambiable y gratis, no habría decisión.
- **"El mundo puede crecer sin romperse."** El jugador percibe una comisaría que se amplía de forma
  coherente —nuevos trámites, nuevos tipos de sala al ascender— porque añadir contenido es añadir una
  definición, no reprogramar. Sostiene la promesa de progresión "de subinspector a toda España".

**Anti-fantasía:** los datos deben quedar **entre bastidores**. El jugador nunca debe sentir que maneja
una hoja de cálculo: ve trámites, personas y salas con nombre e icono, no filas de una tabla. *(La
comodidad de "tunear sin tocar código" es un beneficio para ti como diseñador, no una fantasía del
jugador.)*

## Detailed Design

### Core Rules

**R0 · Principio data-driven.** Todo valor de juego —precio, duración, coste, aforo, población— se
declara como *dato* en el catálogo; ningún sistema lo hardcodea. Los sistemas localizan definiciones por
su `id`.

**R1 · Definición ≠ Instancia.** Una *definición* es una **plantilla de solo lectura** (un "tipo"). Las
*instancias* en juego (un puesto concreto colocado, un ciudadano concreto, un agente contratado) las
poseen otros sistemas y **referencian una definición por `id`**. Datos **nunca** guarda estado mutable de
partida.

**R2 · Tipos de definición del catálogo (MVP).** Base común **`Atención`** =
`{id, nombre, servicio, duracion_min, tipo_puesto, icono}`; de ella derivan dos:

| Tipo | Deriva de | Campos propios | Semilla |
|------|-----------|----------------|---------|
| **`TramiteDoc`** (ingresos) | Atención | `tarifa_eur`, `requiere_cita` (bool) | DNI, Pasaporte, TIE |
| **`DenunciaODAC`** (obligación) | Atención | `prioridad` (Normal/Prioritaria), `admite_cita` (bool) — **sin** tarifa | permisos de viaje, estafas, lesiones, pérdidas/sustracciones, **VioGén (Prioritaria)**, daños, amenazas, hurtos/robos |

| Tipo | Campos clave |
|------|--------------|
| **`TipoPuesto`** (estación) | `id, nombre, servicio, atenciones_admitidas[] (ids), reconfigurable (bool), coste_construccion_eur, plazas_agente, superficie, icono` |
| **`TipoSala`** (contenedor) | `id, nombre, servicio\|Comun, puestos_admitidos[], aforo_espera, coste_construccion_eur, superficie, icono` |
| **`TipoAgente`** (personal) | `id, puesto_organico, unidad, escala_rango, salario_dia_eur, tipo_horario (turnos\|complementario\|guardia), puestos_operables[]` |
| **`Costes`** (transversal) | Solo parámetros **transversales**: `peonada_eur_hora (≈15)` y los del retorno DGP (`retorno_dgp_min/max`, ver nota). **Los salarios NO viven aquí** (están en `TipoAgente.salario_dia_eur`); los costes de construcción, en `TipoPuesto`/`TipoSala`. |
| **`Escenario`** (el "nivel") | `id, nombre, nivel (categoría: "Nivel 1 — Comisaría Local"…), poblacion, tope_construible (topes por servicio), rango_requerido, servicios_activos[]` |

*Valores concretos → sección Formulas. Comodidades de sala = fuera del MVP (el esquema es extensible para
añadirlas luego).*

> **Nota sobre `tarifa_eur`:** es la **tasa oficial** del trámite (p. ej. DNI 12€). Realismo: esa tasa
> **no la ingresa la comisaría**, va a la **Dirección General de la Policía (DGP)**. Lo que recibe la
> comisaría es una **asignación por desempeño**:
> `ingreso_comisaria = tarifa_eur × retorno_DGP(satisfacción)`, con un **suelo fijo** que la DGP retiene
> siempre (mejor servicio → más retorno; peor → la DGP se queda más). La fórmula y sus rangos son de
> **Economía**; la satisfacción que la alimenta, de **Paciencia y Satisfacción (#10)**. Datos solo posee
> la **tasa base**.

**R3 · Integridad referencial.** Toda referencia por `id` entre definiciones (`atenciones_admitidas`,
`puestos_admitidos`, `puestos_operables`) debe apuntar a un `id` existente. Los `id` son únicos por tipo.

**R4 · Unidad de tiempo.** Las duraciones se expresan en **minutos de juego** (misma unidad que
`minutos_por_dia`=1440 del Sistema de Tiempo). Datos **no redefine** ninguna constante de Tiempo.

**R5 · Invariante de solvencia (anti-colapso).** Para cada `Escenario`, el catálogo debe cumplir que **la
capacidad máxima construible pueda absorber la demanda máxima sostenida de su `poblacion` con buena
gestión** — nunca debe existir un estado irresoluble:
- **Documentación (MVP, sin cita):** con `requiere_cita=false` (config MVP) la demanda **no** se
  autolimita por cita; se acota por **paciencia/abandono** (el ciudadano no atendido a tiempo se marcha →
  ingreso perdido, **no** un atasco irresoluble). La cita previa como válvula que sí acota la demanda es
  el **sistema #14 "Cita previa vs sin cita" (Vertical Slice)**; su flag ya existe en el esquema para
  activarla entonces.
- **ODAC (sin cita general):** el catálogo garantiza `demanda_max_ODAC(poblacion) ≤
  capacidad_max_ODAC(Escenario)` a nivel de servicio aceptable. La fórmula de llegadas de ODAC (GDD
  Demanda) se **calibra contra** `tope_construible`, no al revés.
- **Válvulas de alivio sin obra** (propiedad de Demanda/ODAC → Open Questions): priorización,
  peonadas/refuerzo de agentes, reconfiguración en caliente, y `admite_cita`/derivación para denuncias no
  urgentes.

### States and Transitions

El catálogo es **estático en tiempo de ejecución**: las definiciones se cargan una vez (al iniciar/cargar
escenario), se **validan** y no cambian durante la partida. No hay máquina de estados de las definiciones.
Precisiones de frontera:

| Aspecto | Quién posee el estado |
|---------|-----------------------|
| Plantilla (campos de la definición) | **Datos** — solo lectura en juego |
| Puesto abierto/cerrado, con/sin agente, atendiendo a X | Flujo / Construcción / Personal (instancia) |
| Qué atiende *ahora* un puesto ODAC reconfigurable | ODAC/Flujo (instancia) — Datos solo declara el *conjunto permitido* (`atenciones_admitidas`, `reconfigurable`) |
| Definición bloqueada→disponible por rango | **Ascensos** dispara; Datos solo aporta el flag `rango_requerido` |

**Ciclo de vida del dato (fuera de partida):** *edición del catálogo → carga → **validación**
(integridad referencial, rangos, invariante de solvencia) → disponible para los sistemas.* Un fallo de
validación se resuelve según **Edge Cases**.

### Interactions with Other Systems

**Regla de propiedad (híbrida, recordatorio):** Datos posee el **esquema + valores semilla**; cada
dominio documenta *porqué/rangos* y **apunta** aquí. Sin duplicar números.

| Sistema | Qué lee del catálogo | Qué tunea/posee el dominio |
|---------|----------------------|-----------------------------|
| **Economía** | `tarifa_eur`, costes de construcción, salarios, `peonada_eur_hora`, params retorno DGP | rangos de €, ciclo de presupuesto, **fórmula de retorno DGP** |
| **Flujo y Colas** | `duracion_min`, `tipo_puesto`, `atenciones_admitidas` | reglas de cola/atención |
| **Demanda** | `poblacion`, catálogo de trámites/denuncias, `prioridad`, `requiere/admite_cita`, `tope_construible` | **tasas de llegada (calibradas al invariante R5)** |
| **Personal** | `TipoAgente` (salario, horario, `puestos_operables`) | dotación, patrones de horario |
| **Construcción** | `TipoPuesto`/`TipoSala` (coste, superficie), `Escenario.tope_construible` | colocación y aplicación del tope físico |
| **Documentación** | trámites `servicio=Documentacion`, `requiere_cita` | horarios de apertura, política de cita |
| **ODAC** | denuncias, `prioridad`, `reconfigurable`, `admite_cita` | operativa y válvulas de alivio |
| **Paciencia y Satisfacción** | (indirecto) duraciones → tiempos de espera | curva de paciencia; **satisfacción** que alimenta el retorno DGP |
| **UI / HUD** | `nombre`, `icono` de cada definición | presentación |

**Motores de presión y ritmo (propiedad de otros sistemas — Datos solo aporta los datos base):**
- **Demanda** posee el *perfil de crecimiento* (arranque bajo → sube con la progresión) y los *picos*
  intradía/semanales (p. ej. hora punta del lunes), **calibrados al invariante R5** para no crear
  colapsos irresolubles.
- **Economía** posee el *ritmo de ingresos/gasto* para que ampliar puestos/personal sea **gradual**
  (nunca "máximo en 5 minutos"), y la **asignación de presupuesto de la DGP**: las tasas oficiales
  (`tarifa_eur`) van a la Dirección General de la Policía; la comisaría recibe un **retorno por
  desempeño** con un **suelo fijo** que la DGP siempre retiene (mejor servicio → más retorno; peor → la
  DGP se queda más).
- **Paciencia y Satisfacción (#10)** posee la **satisfacción** que alimenta ese retorno; **ODAC es fuente
  de satisfacción** (rinde reputación, no €). El modelo exacto (tarifa vs volumen vs retorno DGP) →
  Open Questions.

**Consistencia entre GDDs:** las referencias cruzadas (p. ej. Demanda ↔ `tope_construible`) se registran
en `entities.yaml`; cada GDD dependiente listará "depende de: Datos" al escribirse *(provisional hasta
entonces)*.

## Formulas

> En este GDD, "Formulas" son sobre todo las **tablas de catálogo con valores semilla**. Todos los
> números son **tunables** y su *rango/porqué* lo poseen los GDDs de dominio (Economía, Demanda,
> Documentación, ODAC); aquí viven las **definiciones y sus valores por defecto**. Se afinan en playtest.
> Duraciones en **minutos de juego** (día = 1440; ver Sistema de Tiempo).

### F1 · Trámites de Documentación (`TramiteDoc`)

`tarifa_eur` = tasa **oficial** (va a la DGP); el ingreso real de la comisaría se calcula con el retorno
DGP (ver F8). Valores del prototipo.

| id | nombre | duracion_min | tarifa_eur | tipo_puesto | requiere_cita |
|----|--------|-------------:|-----------:|-------------|:-------------:|
| `dni` | DNI | 12 | 12 | `puesto_doc_general` | false\* |
| `pasaporte` | Pasaporte | 15 | 30 | `puesto_doc_general` | false\* |
| `tie` | TIE | 15 | 18 | `puesto_tie` | false\* |

\* MVP arranca **sin cita** (`requiere_cita=false`): la demanda de Documentación se acota por
paciencia/abandono, no por cita (ver R5). La cita previa como válvula es el **sistema #14 (Vertical
Slice)**; el flag ya existe en el esquema. La política por trámite la posee Documentación.

### F2 · Denuncias de ODAC (`DenunciaODAC`)

Sin tarifa (obligación). Criterio: urgente/violento = **Prioritaria**; administrativo/patrimonial = Normal.
**Directriz del usuario (2026-07-21): TODAS las denuncias admiten cita** (`admite_cita=true`; a materializar
en **Cita previa #14** — MVP arranca **sin cita**). *(Catálogo ampliado 2026-07-21 a 13 tipos: +Desaparecidos,
+Agresión sexual, +Robo con violencia, +Okupación, +Ciberestafa. Los `admite_cita=false` heredados de
viogen/lesiones/amenazas se unificarán a true con #14.)*

| id | nombre | duracion_min | prioridad | admite_cita |
|----|--------|-------------:|-----------|:-----------:|
| `viogen` | Violencia de género (VioGén) | 60 | **Prioritaria** | false |
| `lesiones` | Lesiones | 30 | Normal | false |
| `estafa` | Estafas | 30 | Normal | true |
| `hurto_robo` | Hurtos / robos | 30 | Normal | true |
| `amenazas` | Amenazas | 25 | Normal | false |
| `danos` | Daños | 20 | Normal | true |
| `perdida_sustraccion` | Pérdidas / sustracciones | 15 | Normal | true |
| `permiso_viaje` | Permisos de viaje | 15 | Normal | true |
| `desaparecidos` | Desaparecidos | 60 | **Prioritaria** | true |
| `agresion_sexual` | Agresión sexual | 60 | **Prioritaria** | true |
| `robo_violencia` | Robo con violencia / atraco | 35 | **Prioritaria** | true |
| `okupacion` | Okupación de vivienda | 30 | Normal | true |
| `ciberestafa` | Ciberestafa / delito informático | 35 | Normal | true |

**Atención especial (origen interno, NO denuncia ciudadana):**

| id | nombre | duracion_min | prioridad | admite_cita | origen |
|----|--------|-------------:|-----------|:-----------:|--------|
| `reclamacion` | Hoja de reclamaciones | 30 | Normal | false | **Paciencia #10 (PS13)** |

*(`reclamacion` la **genera Paciencia**, no el generador de Demanda: cuando un ciudadano abandona Documentación,
con `prob_reclamacion` (0.4) acude a ODAC a formalizar la hoja → un trámite de **30 min, sin tarifa** en la cola
de ODAC. Carga **autoinfligida** —Documentación mal gestionada contamina ODAC—; **no** altera la demanda base de
ODAC ni el invariante R5. Sin recursión. Ver Paciencia PS12/PS13.)*

### F3 · Tipos de Puesto (`TipoPuesto`)

`superficie` en celdas de rejilla 2D (**indicativa** — Construcción posee el modelo espacial).

| id | nombre | servicio | atenciones_admitidas | reconfigurable | plazas_agente | superficie | coste_eur |
|----|--------|----------|----------------------|:--:|:--:|:--:|--:|
| `puesto_doc_general` | Ventanilla Documentación | Documentacion | `[dni, pasaporte]` | false | 1 | 1 | 500 |
| `puesto_tie` | Puesto TIE | Documentacion | `[tie]` | false | 1 | 1 | 500 |
| `puesto_odac` | Puesto ODAC | ODAC | `[todas las denuncias]` | **true** | 1 | 1 | 600 |
| `puesto_seguridad` | Entrada / Seguridad | Seguridad | — | false | 1 | 1 | 400 |

> **Nota — Entrada/Seguridad en el MVP:** `puesto_seguridad` y `ag_seguridad` (F5) existen en el catálogo
> por **realismo/ambientación** y para el futuro, pero en Pozuelo (MVP) el jugador es **jefe de ODAC y de
> Documentación, no de Seguridad Ciudadana** (brigada aparte). Por eso *Seguridad* **no está en
> `servicios_activos`** del Escenario (F7): el arco de entrada + su agente son **presencia fija no
> gestionada** — sin coste para el jugador, sin construcción/contratación y sin eventos. Su simulación
> real (arco de seguridad, "más policías → menos hechos aleatorios", coste) se difiere a un sistema futuro
> (Open Question #5). El `coste_eur`/`salario` de estas definiciones son sus valores **cuando** ese
> sistema se active, no un gasto del MVP.

### F4 · Tipos de Sala (`TipoSala`)

`aforo_espera` = capacidad **máxima** de la sala (regla en F8). Los **asientos reales** que la llenan son
*comodidades* (banco de madera 8 plazas → mejorables hasta el aforo, con calidad y deterioro →
mantenimiento): **sistema #15 Comodidades (Vertical Slice)**, diferido. *(**Construcción #7:** con
construcción libre, `aforo_espera` 40/10 pasa a ser **referencia** del aforo típico; el aforo **real** lo
dan los asientos colocados en la sala de tamaño libre — Construcción F3.)* Las oficinas de servicio son
**áreas lógicas** que agrupan puestos (footprint = el de sus puestos).

| id | nombre | tipo | puestos_admitidos | aforo_espera | coste_eur |
|----|--------|------|-------------------|:--:|--:|
| `sala_espera_doc` | Sala de Espera — Documentación | espera | — | 40 | 200 |
| `sala_espera_odac` | Sala de Espera — ODAC | espera | — | 10 | 200 |
| `sala_documentacion` | Oficina de Documentación | área lógica | `[puesto_doc_general, puesto_tie]` | — | — |
| `sala_odac` | Oficina de ODAC | área lógica | `[puesto_odac]` | — | — |

> **`superficie` de las salas:** las **oficinas** (áreas lógicas) tienen footprint = el de sus puestos;
> las **salas de espera** tienen superficie **indicativa** que posee Construcción (rejilla) — no se fija
> aquí como semilla. El esquema (R2) conserva el campo `superficie` para cuando Construcción lo dimensione.

### F5 · Tipos de Agente (`TipoAgente`)

| id | puesto_organico | unidad | escala_rango | tipo_horario | puestos_operables | salario_dia_eur |
|----|-----------------|--------|--------------|--------------|-------------------|--:|
| `ag_doc` | Funcionario de Documentación | Secretaría | Básica | complementario | `[puesto_doc_general, puesto_tie]` | 60 |
| `ag_odac` | Instructor de ODAC | Policía Judicial | Básica/Subinspección | turnos | `[puesto_odac]` | 70 |
| `ag_seguridad` | Agente de Seguridad (Entrada) | Seguridad Ciudadana | Básica | turnos | `[puesto_seguridad]` | 65 |

### F6 · Costes transversales (`Costes`) — tuning: Economía

| parámetro | valor semilla | nota |
|-----------|--------------:|------|
| `peonada_eur_hora` | 15 | hora extra fuera de horario base, por funcionario |
| `retorno_dgp_min` | 0.15 | fracción que vuelve a la comisaría con satisfacción 0 (**suelo fijo**) |
| `retorno_dgp_max` | 0.45 | fracción con satisfacción 100% (la DGP retiene siempre ≥55%) |

### F7 · Escenario MVP — Oficina de Denuncias de Pozuelo

| campo | valor semilla | nota |
|-------|--------------:|------|
| `poblacion` | 90000 | Pozuelo de Alarcón |
| `nivel` | Nivel 1 — Comisaría Local | tiers superiores (p. ej. Usera) = más población/tope/servicios |
| `servicios_activos` | `[Documentacion, ODAC]` | servicios que el jugador **gestiona** en el MVP. *Seguridad* NO se incluye (entrada = ambientación fija; ver nota en F3) |
| `rango_requerido` | Subinspección — **Subinspector** *(inicial)* | rango de inicio del jugador; el Escenario MVP no está bloqueado por rango |
| `tope_construible` (puestos) | Doc-general ≤8 · TIE ≤2 · ODAC ≤4 · Entrada =1 (fija, no construible en MVP) | dimensionado para cumplir R5. **Construcción #7 lo reinterpreta como referencia del dimensionado del edificio, NO cupo rígido (puestos ilimitados; la demanda decide cuántos son útiles)** |
| salas de espera | `sala_espera_doc` (aforo 40) · `sala_espera_odac` (aforo 10) | |
| `superficie` | indicativa | Construcción define la rejilla (≈1 celda/puesto + esperas + entrada) |

> **Escalado futuro:** niveles superiores de comisaría se añaden como **nuevas definiciones `Escenario`**
> (más `poblacion`, mayor `tope_construible`, más servicios). Lo gobiernan **Ascensos (#18)** y
> **Escalado a Comisarías (#26)**. El esquema ya lo soporta sin cambios.

### F8 · Fórmulas derivadas (referencia — dueño externo) y chequeos

- **Ingreso efectivo** *(Economía)*: `ingreso_comisaria = tarifa_eur × retorno_DGP(sat)`, con
  `retorno_DGP(sat) = retorno_dgp_min + (retorno_dgp_max − retorno_dgp_min) × (clamp(sat,0,100)/100)`.
  *Ej.: a 50 % de satisfacción, el DNI rinde `12 × 0.30 = 3,6 €` a la comisaría.* *(Fórmula propiedad de
  Economía F1; el `clamp` protege ante satisfacción fuera de [0,100].)*
- **Regla de aforo de sala de espera**: `aforo_espera ≈ Σ puestos_del_servicio × (60 / duración_media_min)`,
  donde `Σ puestos_del_servicio` = **todos** los puestos del servicio que comparten esa sala (a tope de
  construcción) y `duración_media_min` es un tiempo de servicio representativo (conservador).
  *Comprobado Documentación (10 puestos: 8 doc-general + 2 TIE, dur ≈15): `10 × (60/15) = 40` ✔.*
  *Comprobado ODAC (4 puestos, dur ≈28): `4 × (60/28) ≈ 9 → aforo 10` ✔.*
- **Capacidad de un puesto/día** *(sanity)*: `≈ minutos_operativos / duracion_min`.
- **Invariante R5**: `capacidad_max_ODAC(Escenario) ≥ demanda_max_ODAC(poblacion)`.

**Chequeo R5 (a mano):** duración media ponderada ODAC ≈ 30 min (mezcla de 13 denuncias, Demanda F3 = 29,75);
se asume un puesto ODAC **operativo ~16 h/día** (supuesto conservador: dotación de ~2 de los 3 turnos; la
operativa 24h real la fijan Personal/Horarios) ≈
`960/30 ≈ 32` denuncias/día → 4 puestos ≈ **~128/día** frente a una demanda plausible de **~30–60/día con
picos** para 90.000 hab → **absorbe con margen** ✔. *(Supuesto: tasa de denuncias abstracta ~0,4–0,7 por 1.000 hab/día;
muchas gestionadas online en la realidad. La fórmula de demanda la posee Demanda, calibrada a este tope.)*

**Chequeo de pacing (a mano):** ~2 puestos de Documentación a 50 % de satisfacción ≈ **~230 €/día** de
ingreso; 2 agentes ≈ **120 €/día** de salario → neto **~110 €/día**. Ahorrar un puesto nuevo (500 €) ≈
**4–5 días de juego** → expansión **gradual** (no "máximo en 5 minutos") ✔.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Mecanismo principal: **validación en
carga** del catálogo (los datos son estáticos; se validan una vez). Modo desarrollo = fallo ruidoso;
modo jugador = degradación segura + log.*

- **Si un sistema pide un `id` de definición que no existe:** en carga, la validación lo detecta y
  **aborta la carga** (desarrollo) o **omite esa referencia con log** (jugador). En runtime los `id` ya
  están validados, así que una búsqueda nunca debería fallar; si falla, se devuelve *definición nula
  segura* y se registra. *El catálogo se valida antes de jugar, no a mitad de partida.*
- **Si hay una referencia colgante entre definiciones** (un `TipoPuesto.atenciones_admitidas` o una
  `TipoSala.puestos_admitidos` apunta a un `id` inexistente): la **validación de integridad referencial**
  falla en carga (desarrollo) o **descarta la referencia inválida + log** (jugador), dejando el resto del
  catálogo usable. *Un dato mal enlazado no debe tumbar toda la comisaría.*
- **Si hay un `id` duplicado dentro de un mismo tipo:** la validación lo rechaza; **falla la carga**
  (desarrollo) o **gana la primera definición + log** (jugador). *Los `id` son únicos por tipo (R3); un
  duplicado es ambiguo.*
- **Si un valor numérico llega fuera de rango** (`duracion_min ≤ 0`, `tarifa_eur < 0`, `aforo_espera < 0`,
  `coste_construccion_eur < 0`, `retorno_dgp` fuera de [0,1]): se **clampa a un mínimo seguro**
  (`duracion_min ≥ 1`; €, aforo y coste `≥ 0`; retorno a [0,1]) y se registra aviso. *Un dato corrupto no
  debe producir tiempos nulos, dinero negativo ni retornos imposibles (igual que el clamp de
  `escala_tiempo` en Tiempo).*
- **Si un `Escenario` NO cumple el invariante R5** (la demanda máxima teórica de su `poblacion` supera la
  capacidad máxima construible de ODAC): la validación emite un **WARNING de diseño** en carga (no rompe
  el juego) señalando el escenario y la holgura negativa. *Es exactamente el "colapso irresoluble" que
  queremos impedir; el aviso obliga a re-dimensionar `tope_construible` o duraciones antes de publicar.*
- **Si un servicio activo del `Escenario` no tiene ningún `TipoPuesto` que lo atienda** (o falta su sala):
  **WARNING**; ese servicio queda **inoperable** hasta corregir el catálogo. *Un servicio sin puesto es
  contenido muerto.*
- **Si se intenta reconfigurar un puesto a una atención que no admite** (fuera de `atenciones_admitidas`,
  o un puesto con `reconfigurable=false`): la acción **se rechaza** (ODAC/Flujo no la permiten); el
  conjunto permitido es dato, no negociable en runtime. *La reconfiguración en caliente solo opera dentro
  de lo declarado.*
- **Si una definición tiene `rango_requerido` superior al rango actual del jugador:** la definición
  **existe pero no está disponible** para construir/contratar; Construcción/Personal la muestran
  **bloqueada**, no es un error. *La progresión desbloquea contenido; el dato solo declara el requisito
  (lo dispara Ascensos).*
- **Si una partida guardada referencia un `id` que ya no existe** (el catálogo se editó entre guardado y
  carga): al cargar, la instancia huérfana se **migra si hay equivalente, o se descarta con log**;
  **nunca invalida el save completo**. *Data-driven + guardado por `id` exige tolerancia a catálogos que
  evolucionan entre versiones.*
- **Si el catálogo está vacío o falta un tipo entero** (p. ej. ningún `TramiteDoc`): **falla la carga**
  (desarrollo) o **arranca en estado degradado con log** (jugador). *Sin definiciones no hay juego; mejor
  un fallo claro que un comportamiento silencioso indefinido.*

## Dependencies

**Este sistema depende de:** *Nada.* Es capa **Foundation raíz**, como el Sistema de Tiempo. Única
relación con Tiempo: comparte la **unidad "minutos de juego"** (`minutos_por_dia`=1440) como convención;
**no lee el reloj** ni redefine sus constantes → *no es dependencia de diseño*.

**Dependen de este sistema** (leen el catálogo por `id`):

| Sistema | Tipo | Qué lee del catálogo (interfaz) |
|---------|------|----------------------------------|
| **Economía / Presupuesto** | Hard | `tarifa_eur`, costes de construcción, `salario_dia_eur`, `peonada_eur_hora`, `retorno_dgp_min/max` |
| **Flujo de Personas y Colas** | Hard | `duracion_min`, `tipo_puesto`, `atenciones_admitidas` |
| **Generación de Demanda** | Hard | `poblacion`, catálogo de `TramiteDoc`/`DenunciaODAC`, `prioridad`, `requiere/admite_cita`, `tope_construible` |
| **Personal / Agentes** | Hard | `TipoAgente` (`salario_dia_eur`, `tipo_horario`, `puestos_operables`, `escala_rango`) |
| **Construcción y Distribución** | Hard | `TipoPuesto`/`TipoSala` (coste, `superficie`, `puestos_admitidos`), `Escenario.tope_construible` |
| **Documentación** | Hard | trámites `servicio=Documentacion`, `requiere_cita` |
| **ODAC / Denuncias** | Hard | `DenunciaODAC`, `prioridad`, `reconfigurable`, `admite_cita` |
| **Paciencia y Satisfacción** | Soft | duraciones (indirecto, alimentan tiempos de espera) |
| **UI / HUD** | Hard | `nombre`, `icono` de cada definición |
| **Guardado y Carga** | Hard | referencias por `id`; tolerancia a catálogo cambiante entre versiones (ver Edge Cases) |
| **Ascensos (#18)** *(futuro)* | Hard | `rango_requerido`; alta de nuevas definiciones al ascender |
| **Comodidades de sala (#15)** *(futuro)* | Hard | `aforo_espera` (techo); catálogo de asientos/objetos con calidad y deterioro |
| **Escalado a Comisarías (#26)** *(futuro)* | Hard | nuevas definiciones `Escenario` (niveles superiores) |

**Consistencia bidireccional:** estas relaciones quedan registradas en `design/gdd/systems-index.md`.
Cuando se escriba el GDD de cada dependiente, deberá listar "depende de: Datos y Configuración" en su
sección de Dependencies. *(Ninguno tiene GDD aún → la referencia inversa queda provisional.)*

## Tuning Knobs

> El **mando más grueso** es el propio catálogo: **añadir/quitar definiciones** (un nuevo trámite, tipo
> de denuncia, puesto o escenario) es tuning sin código. Abajo, los campos ajustables por definición.
> *Owner* = GDD que posee el rango/porqué; Datos guarda el valor por defecto.

| Knob (campo) | Default (semilla) | Rango seguro | Si ↑ / Si ↓ | Owner |
|--------------|-------------------|--------------|-------------|-------|
| `duracion_min` (trámite/denuncia) | F1/F2 (12–60) | 1 – 1440 | ↑ atención más lenta, colas más largas, menos throughput / ↓ más rápido | Documentación / ODAC |
| `tarifa_eur` (tasa oficial) | 12 / 30 / 18 | ≥ 0 | ↑ base de ingreso mayor (realista: tasa oficial fija) / ↓ menor | Economía |
| `retorno_dgp_min` · `retorno_dgp_max` | 0.15 · 0.45 | [0,1], `min ≤ max` | **↑ dinero más fácil** / ↓ más difícil (driver del "dinero no trivial") | Economía |
| `coste_construccion_eur` | 500/500/600/400/200 | ≥ 0 | ↑ expansión más cara/lenta / ↓ más rápida | Economía / Construcción |
| `salario_dia_eur` | 60 / 70 / 65 | ≥ 0 | ↑ personal más caro (gasto fijo) / ↓ más barato | Economía / Personal |
| `peonada_eur_hora` | 15 | ≥ 0 | ↑ horas extra caras / ↓ baratas | Economía / Horarios |
| `aforo_espera` | 40 / 10 (regla F8) | ≥ 0 | ↑ más gente espera sin marcharse / ↓ colapso de espera antes | Construcción / Paciencia |
| `tope_construible` (por servicio) | Doc≤8·TIE≤2·ODAC≤4·Ent1 | ≥ 1, **sujeto a R5** | ↑ más capacidad máxima (presión más aliviable) / ↓ riesgo de violar R5 | Datos / Construcción |
| `poblacion` (Escenario) | 90000 | > 0, **sujeto a R5** | ↑ más demanda (Demanda escala) / ↓ menos | Datos / Demanda |
| `prioridad` (denuncia) | Normal / Prioritaria | enum | Prioritaria = se atiende antes | ODAC |
| `requiere_cita` / `admite_cita` | false / según F2 | bool | true = amortigua demanda (válvula R5) | Documentación / ODAC |
| `reconfigurable` (puesto) | ODAC=true, resto false | bool | true = puesto polivalente en caliente | ODAC / Datos |

**Interacciones entre knobs (cuidado):**
- **`duracion_min` × `tope_construible` × `poblacion` gobiernan el invariante R5.** Subir duraciones o
  población, o bajar topes, puede **violar R5** → la validación avisa (ver Edge Cases). Cámbialos juntos.
- **`tarifa_eur` × `retorno_dgp_*` definen el ingreso efectivo.** El driver real del "que el dinero no sea
  fácil" es **`retorno_dgp_*`**, no la tasa (que es oficial y fija por realismo).
- **`aforo_espera` está ligado por la regla F8** a `tope_construible` × `duracion_min`; si cambias esos,
  recalcula el aforo.
- **`coste_construccion` × `salario` × ingreso definen el pacing de expansión** (objetivo: gradual).

**Restricciones:** `retorno_dgp_min ≤ retorno_dgp_max` en [0,1]; `tope_construible ≥ 1`; `duracion_min ≥
1`; todo `Escenario` debe cumplir **R5** (lo verifica la validación en carga).

## Visual/Audio Requirements

El catálogo **no produce arte**, pero **declara** los campos visuales que otros consumen:
- **`icono`** (clave/ruta) en cada definición: 3 trámites, 8 tipos de denuncia, 4 tipos de puesto, salas
  (2 esperas + oficinas), 3 tipos de agente, y el escenario/nivel. Estilo según el **art bible** (2D
  limpio, serio, no caricatura).
- Datos solo guarda la **referencia** al icono; la especificación de cada asset se genera aparte.
- **Audio:** N/A directo (los datos no suenan). Los eventos que *usan* estos datos (atender, construir,
  contratar) los sonoriza **Feedback/Audio**.

> 📌 **Asset Spec** — Con estos iconos identificados, tras aprobar el art bible se puede ejecutar
> `/asset-spec system:data-config` para generar descripciones y prompts de los iconos del catálogo.

## UI Requirements

El catálogo **no tiene pantalla propia**; alimenta a otras UI con datos legibles:
- **Menú de construcción** (elegir puesto/sala): `nombre`, `icono`, `coste_construccion_eur`, `superficie`.
- **Menú de contratación** (elegir agente): `nombre`, `icono`, `salario_dia_eur`, `tipo_horario`.
- **Colas y puestos:** etiqueta del trámite/denuncia (`nombre`, `icono`, `prioridad`).
- La UI **nunca hardcodea** estos textos/números: los lee del catálogo. Las claves de `nombre` serán la
  base de la **localización (i18n)** futura.

> **📌 UX Flag — Datos y Configuración**: los menús de construcción/contratación y las etiquetas de cola
> que consumen este catálogo se diseñan con `/ux-design` en Pre-Producción, **antes** de escribir epics.
> Las stories de UI citan `design/ux/[pantalla].md`, no este GDD.

## Acceptance Criteria

> *Nota: `qa-lead` no consultado por el error "1M context"; se aplicó su lente manualmente en el
> `/design-review` (2026-07-19) y se afinaron AC-D03/D12/D16/D18/D20.* Tipo: `[Unit]` (validación/lógica
> pura) · `[Integration]` (un sistema resuelve una definición del catálogo).

**Carga y principio data-driven (R0)**
- **AC-D01** `[Unit]` — GIVEN el catálogo de F1 WHEN se carga THEN existen `dni`(12 min, 12 €),
  `pasaporte`(15, 30) y `tie`(15, 18) con esos valores exactos.
- **AC-D02** `[Unit]` — GIVEN se edita en el dato `tarifa_eur` de `dni` a 15 (sin tocar código) WHEN se
  recarga THEN el catálogo devuelve 15 (ningún valor está incrustado en código).
- **AC-D03** `[Integration]` — GIVEN Economía, Flujo, Demanda, Documentación, ODAC y Construcción activos
  WHEN cada uno resuelve la definición `dni` por `id` THEN los seis obtienen valores **iguales** (mismo
  `duracion_min`, `tarifa_eur`, etc.) que los del catálogo único (igualdad de valor verificable, sin
  divergencias entre sistemas).

**Modelo trámite vs denuncia (R2)**
- **AC-D04** `[Unit]` — GIVEN `dni` THEN tiene `tarifa_eur=12` y **no** tiene `prioridad`.
- **AC-D05** `[Unit]` — GIVEN `viogen` THEN `prioridad=Prioritaria`, `admite_cita=false` y **no** tiene
  `tarifa_eur`.

**Integridad referencial (R3)**
- **AC-D06** `[Unit]` — GIVEN un `TipoPuesto.atenciones_admitidas` con un `id` inexistente WHEN se valida
  THEN se reporta referencia colgante señalando el `id`.
- **AC-D07** `[Unit]` — GIVEN dos definiciones con el mismo `id` en un tipo WHEN se valida THEN se reporta
  `id` duplicado.
- **AC-D08** `[Unit]` — GIVEN `sala_documentacion.puestos_admitidos=[puesto_doc_general, puesto_tie]` WHEN
  se valida THEN ambos existen y la validación pasa.

**Rangos y clamp (Edge Cases)**
- **AC-D09** `[Unit]` — GIVEN `duracion_min=0` WHEN se procesa THEN se clampa a 1 y se registra aviso.
- **AC-D10** `[Unit]` — GIVEN `retorno_dgp_min=-0.2` y `retorno_dgp_max=1.5` WHEN se procesan THEN quedan
  0.0 y 1.0 con aviso.
- **AC-D11** `[Unit]` — GIVEN `coste_construccion_eur=-100` WHEN se procesa THEN se clampa a 0 y aviso.

**Invariante de solvencia (R5)**
- **AC-D12** `[Unit]` — GIVEN Pozuelo (ODAC ≤4, dur. media ≈30 → `capacidad_max_ODAC≈128/día`) y una
  **estimación de demanda máxima `D` como entrada** WHEN se valida R5 THEN el validador avisa **sii**
  `capacidad_max_ODAC < D`; con `D=30–60/día` (estimación actual) **pasa sin warning**.
- **AC-D13** `[Unit]` — GIVEN un `Escenario` con demanda_max > capacidad_max_ODAC WHEN se valida THEN se
  emite **WARNING de diseño** identificando el escenario, **sin abortar la carga**.

**Reconfiguración y estado (R1)**
- **AC-D14** `[Integration]` — GIVEN `puesto_odac` (`reconfigurable=true`) WHEN se reconfigura a atender
  solo `viogen` THEN se permite; WHEN se intenta ponerlo a atender `dni` (fuera de `atenciones_admitidas`)
  THEN se rechaza.
- **AC-D15** `[Integration]` — GIVEN `puesto_doc_general` (`reconfigurable=false`) WHEN se intenta
  reconfigurar THEN se rechaza.

**Escenario, nivel y disponibilidad**
- **AC-D16** `[Unit]` — GIVEN Pozuelo THEN `poblacion=90000`, `nivel="Nivel 1 — Comisaría Local"`,
  `servicios_activos=[Documentacion, ODAC]`, topes Doc ≤8 / TIE ≤2 / ODAC ≤4 / Entrada 1.
- **AC-D17** `[Unit]` — GIVEN una definición con `rango_requerido` > rango actual WHEN Construcción lista
  opciones THEN aparece **bloqueada** (no construible), y **no es error**.

**Aforo (F8) y guardado tolerante**
- **AC-D18** `[Unit]` — GIVEN `sala_espera_doc` con los 10 puestos de Documentación (8 doc-general + 2
  TIE) de duración ≈15 WHEN se aplica la regla F8 THEN `aforo_espera=40`.
- **AC-D19** `[Unit]` — GIVEN un save que referencia un `id` que ya no existe WHEN se carga THEN la
  instancia huérfana se descarta con log y **el resto del save carga** (no se invalida el save completo).

**Calidad transversal**
- **AC-D20a** `[Unit]` — GIVEN todo el catálogo MVP WHEN se valida en carga THEN **no hay referencias
  colgantes** (toda referencia por `id` resuelve a una definición existente).
- **AC-D20b** `[Unit]` — GIVEN todo el catálogo MVP WHEN se valida THEN **no hay `id` duplicados** dentro
  de ningún tipo.
- **AC-D20c** `[Unit]` — GIVEN todo el catálogo MVP WHEN se valida THEN **ningún valor numérico queda
  fuera de rango** tras el clamp (`duracion_min ≥ 1`; €/aforo/coste `≥ 0`; `retorno_dgp` en [0,1]).
- **AC-D20d** `[Unit]` — GIVEN todo el catálogo MVP WHEN se valida THEN **todos los `Escenario` cumplen
  R5** (o emiten su WARNING de diseño) y **todo `servicio_activo` tiene al menos un `TipoPuesto`** que lo
  atiende (si no, WARNING de servicio inoperable).

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | Modelo exacto del bucle **satisfacción → retorno DGP** (¿modula tarifa, volumen o subvención?) y valores `retorno_dgp_min/max` | Economía + Satisfacción (#10) | GDD Economía/Satisfacción | Abierta |
| 2 | **Perfil de demanda evolutiva**: crecimiento por progresión + picos intradía/semanales (hora punta del lunes), calibrado a R5 | Demanda | GDD Demanda | Abierta |
| 3 | **Ritmo económico**: que ampliar sea gradual ("dinero no fácil"), pacing ~4–5 días/ampliación; y **rentabilidad de las peonadas** (¿válvula que protege satisfacción + renta según mezcla de trámites + bonus DGP por servicio, **no** beneficio plano?) | Economía + playtest | 1er playtest MVP | Abierta |
| 4 | **Comodidades de sala** (#15): asientos con **calidad + deterioro + mantenimiento** (banco madera 8 → mejorable hasta aforo) | Comodidades #15 (V. Slice) | GDD #15 | Abierta |
| 5 | **Seguridad interna**: arco de seguridad + "más policías → menos **hechos aleatorios**"; sistema de hechos aleatorios | Sistema futuro (a mapear) | — | Abierta |
| 6 | **Válvulas de alivio de ODAC sin obra** (priorización, peonadas, reconfiguración, cita/derivación no urgentes): cuáles y cómo | ODAC + Demanda | GDDs ODAC/Demanda | Abierta |
| 7 | **Valores semilla a validar en playtest** (duraciones ODAC, costes, salarios, retorno DGP, topes, aforos) | Balance / playtest | 1er playtest MVP | Abierta |
| 8 | **Formato de datos** (Godot Resource `.tres` vs JSON) y mecanismo de validación en carga | Arquitectura (technical-director) | Fase de arquitectura (ADR) | Abierta |
| 9 | **Niveles superiores de comisaría** (Usera…): parámetros de cada tier (`poblacion`, `tope_construible`, servicios) | Ascensos #18 / Escalado #26 | GDDs #18/#26 | Abierta |
