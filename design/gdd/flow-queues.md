# Flujo de Personas y Colas

> **Status**: Reviewed (/design-review 2026-07-22 APPROVED)
> **Author**: manu.rdo + Claude (hilo principal; lentes systems-designer / game-designer / qa-lead — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" + Pilar 4 — "Tu comisaría, tus decisiones"

## Overview

El sistema de **Flujo de Personas y Colas** es el motor del juego: gobierna el recorrido de **cada
persona** que entra en la comisaría —ciudadanos a por el DNI, denunciantes y (más adelante) detenidos— a
través de un ciclo común: **entrada → coger turno → sala de espera → puesto libre → atención → salida**.
Lleva las **colas** de cada servicio, decide **a quién le toca** y en **qué puesto**, avanza la atención
con el reloj durante la **duración efectiva** del trámite —la base `duracion_min` de *Datos*, que la
**formación del agente** puede acortar— y, al terminar cada trámite, **emite el evento que el resto del
juego escucha** (Economía abona el retorno DGP; Paciencia deja de contar la espera). Lee de *Datos* la
duración y qué atiende cada puesto, y del *Tiempo* el paso del reloj —**en Pausa todo el flujo se
congela**—, pero no inventa cuánta gente llega ni cuánto aguanta: solo la **mueve, la encola y la
atiende**.

A nivel de diseño es **el bucle central que el jugador siente y optimiza** (Pilares 2 y 4). No arrastras a
la gente una a una: **organizas** —abres un puesto, asignas un agente, repartes las salas— y el flujo
responde. La comisaría se vuelve *legible* como un organismo vivo: ves la cola de Documentación hincharse
en la hora punta, detectas el **cuello de botella** y sientes el alivio al desatascarlo con una ventanilla
más. El prototipo confirmó que **este flujo es divertido por sí solo** y dejó una lección que este sistema
encarna: **capacidad ≠ demanda** —abrir más puestos no trae más gente, solo atiende más rápido a la que ya
viene—, así que el reto no es construir sin fin, sino **ajustar la capacidad a la demanda**. Sin esta capa
no hay colas que crezcan, ni trámites que cobrar, ni espera que impaciente: es el **cuello de botella del
que dependen** Documentación, ODAC, Paciencia y Economía.

> **Regla de propiedad:** Flujo **posee** el *movimiento* de las personas, las *colas*, la *asignación*
> persona→puesto y el *ciclo de atención* (incluido el evento `"trámite completado"`). **Lee** de *Datos*
> (`duracion_min`, `tipo_puesto`, `atenciones_admitidas`), del *Tiempo* (`delta`, estado de pausa) y de
> **Personal** los *modificadores del agente* que atiende (rendimiento → **duración efectiva**; trato →
> **factor de trato** (satisfacción) al cerrar), cuyo origen es **Formación y Cursos (#29)** *(2 ramas —producción y
> atención— de 3 niveles; sin GDD aún → provisional)*. **No posee**: *cuánta* gente llega ni cuándo (→
> **Demanda #5**), la *curva de paciencia/abandono* (→ **Paciencia #10**), los *horarios* de apertura (→
> Documentación/ODAC + Tiempo), ni la *progresión de formación* del personal (→ Personal #6 / Formación
> #29). *(Demanda, Paciencia y Formación sin GDD aún → interfaces provisionales.)*

## Player Fantasy

**Fantasía:** ser el **director del tráfico humano** de la comisaría — quien convierte la marea de gente
que entra en un servicio que fluye, lee la sala de un vistazo y decide dónde poner el siguiente puesto o
agente para que nadie se atasque. La satisfacción de un **sistema que funciona como un reloj gracias a ti**.

El flujo se vive en dos capas:

- **Control directo (desatascar):** cuando la cola crece, actúas — abres otra ventanilla, reasignas un
  agente, (más adelante) mandas formar a alguien o abres la cita previa — y ves la cola **deshelarse**. Es
  la fantasía del gestor competente: detectar el cuello de botella y resolverlo, con efecto visible e
  inmediato sobre el flujo.
- **Infraestructura que se vive (la comisaría respira):** aunque no toques nada, la gente entra, coge
  turno, espera, es atendida y se marcha. El edificio bulle solo: ves a las personas moverse, las salas
  llenarse, los puestos trabajar. La comisaría está *viva* (Pilar 2) — no "usas" esta capa, la *contemplas*
  como quien mira un hormiguero ordenado.

**El momento a anclar:** hora punta de la mañana. Entran ocho personas de golpe, la sala de espera de
Documentación se llena y solo tienes una ventanilla abierta: la cola se estira hasta la puerta y la
paciencia de las caras empieza a cambiar de color. Sientes el pinchazo —¿abro otro puesto y pago el agente,
aguanto, o reasigno a alguien?— y, cuando abres la segunda ventanilla y la cola **empieza a bajar a ojos
vista**, llega el subidón: *"lo he arreglado yo"*. Ese pulso —ver el atasco, entenderlo, resolverlo y **ver
el resultado moverse**— es el corazón del juego.

**Referencia de sensación:** el flujo de "clientes" de *Two Point Hospital* y *Prison Architect* — verlos
recorrer tu edificio y optimizar su ruta —, con la lectura de un vistazo de la cola de los juegos de
gestión. **Anti-fantasía:** NO es micromanejo — **no diriges a cada persona a mano** (se mueven solas);
diriges el *sistema*, no a los individuos. Y NO es un caos ingobernable: siempre hay una palanca (abrir
puesto, reasignar, cita previa) para recuperar el control; la frustración de "no puedo hacer nada" está
prohibida (Pilar 4).

## Detailed Design

### Core Rules

**FL1 · Unidad del flujo: la Persona.** Cada visitante es una **instancia de Persona** con: un `servicio`
objetivo (Documentacion u ODAC), un **trámite/denuncia** concreto (`id` de Datos: `dni`/`pasaporte`/`tie` o
un tipo de denuncia), un **número de turno**, un **estado** (ver States) y su **paciencia** (la posee
Paciencia #10). **Demanda #5** la crea al llegar; Flujo la mueve hasta que sale. Datos define su trámite;
Flujo no inventa tipos.

**FL2 · Un turno por servicio (cola lógica).** Al entrar, la Persona **coge número** de la cola de su
**servicio** (una cola por servicio: Documentación, ODAC). Orden base **FIFO por número**; ODAC respeta
**prioridad** (`Prioritaria` antes que `Normal` — VioGén primero, Datos F2). Documentación es FIFO puro (sin
prioridad en MVP).

**FL3 · Asignación puesto→persona (el puesto tira de la cola).** Un puesto libre, **abierto y con agente**,
toma de la cola de su servicio a la **primera Persona que pueda atender** según sus `atenciones_admitidas`
(Datos): un `puesto_tie` solo llama a gente de TIE; un `puesto_doc_general` a DNI/Pasaporte; un `puesto_odac`
a las denuncias que tenga configuradas. Si ninguna Persona en cola es compatible, el puesto espera. **El
jugador no asigna personas a puestos** — asigna **agentes** a puestos; el emparejamiento persona↔puesto es
automático (anti-micromanejo, Pilar 4).

**FL4 · Requisitos para atender.** Un puesto atiende solo si: (a) está **construido** (Construcción), (b)
está **abierto**, (c) tiene un **agente asignado** capaz de operarlo (`puestos_operables`, Personal), y (d)
hay una Persona compatible en cola. Sin agente, no atiende aunque esté abierto.

**FL5 · Ciclo de atención.** Al tomar a una Persona: esta va al puesto (desplazamiento **breve y visible**,
no relevante para el balance) y empieza la **atención**, que dura la **duración efectiva**:
`duracion_efectiva = duracion_min (Datos) × modificador_produccion(agente)` (lo computa **Personal** desde ⚡Rapidez; Formación #29 lo mejora; default 1.0). Al
terminar, Flujo **emite `"trámite completado"`** con el trámite y el agente (Economía cobra; Satisfacción
aplica el bonus de atención); la Persona pasa a **Resuelta** y **sale**; el puesto queda **libre** y llama al
siguiente.

**FL6 · Salas de espera: aforo interior + cola exterior.** Cada servicio tiene su **sala de espera** con
`aforo_espera` (Datos: Doc **40**, ODAC **10**). Las Personas esperan **dentro** hasta el aforo. Si la sala
está **a aforo**, quien llega espera en una **cola exterior** (entrada/calle) y **entra en cuanto se libera
una plaza**, respetando el orden de turno. *(Esperar fuera cuenta como espera; su efecto sobre la paciencia
lo posee Paciencia #10 — provisional.)*

**FL7 · Sin cita en el MVP (demanda no autolimitada).** Con `requiere_cita=false` (Datos R5), la afluencia
**no se autolimita**: la cola puede crecer y la válvula es la **paciencia/abandono** (Personas que se
marchan sin ser atendidas), no un atasco irresoluble. La **cita previa** como regulador es el sistema **#14
(Vertical Slice)**; su flag ya existe.

**FL8 · La Pausa congela el flujo.** En Pausa (Tiempo): no llegan Personas, no avanzan desplazamientos ni
atenciones, no corre el turno ni la paciencia. El jugador **sí** puede gestionar (abrir/cerrar puestos,
asignar agentes). Al reanudar, todo sigue donde estaba (determinismo).

**FL9 · Reconfiguración de puestos en caliente (ODAC).** Un `puesto_odac` (`reconfigurable=true`, Datos)
puede cambiar **en marcha** qué denuncias atiende; afecta a **a quién puede llamar** desde ese momento (no
interrumpe la atención en curso). Los puestos no reconfigurables (Documentación) no cambian. *(La operativa
de reconfiguración la posee ODAC #9.)*

**FL10 · Abrir/cerrar puestos.** El jugador abre o cierra un puesto. **Cerrar no expulsa** a la Persona en
atención (la termina — regla de cierre de servicio, ver Edge Cases); solo deja de llamar a nuevas. *(Los
horarios que abren/cierran automáticamente los poseen Documentación/Horarios; Flujo solo ejecuta el estado
abierto/cerrado.)*

### States and Transitions

**A. Estados de la Persona** (los mueve Flujo; el abandono lo dispara Paciencia #10)

| Estado | Descripción | Entra desde | Sale a |
|--------|-------------|-------------|--------|
| **Llegando** | Entra al edificio y va a coger número | (creada por Demanda #5) | Esperando (dentro/fuera) |
| **Esperando (fuera)** | Cola exterior porque el aforo está lleno (FL6) | Llegando / aforo lleno | Esperando (dentro) / Abandonando |
| **Esperando (dentro)** | En la sala de espera, con turno; corre la paciencia | Llegando / Esperando (fuera) | Llamada / Abandonando |
| **Llamada** | Un puesto compatible la ha tomado; va hacia él | Esperando (dentro) | En atención |
| **En atención** | Siendo atendida; dura `duracion_efectiva` (FL5) | Llamada | Resuelta |
| **Resuelta** | Trámite hecho; sale del edificio | En atención | (despawn) |
| **Abandonando** | Se marcha sin ser atendida (paciencia agotada) | Esperando (fuera/dentro) | (despawn) |

**Transiciones clave:**
- **Llegando → Esperando (dentro)** si hay aforo; **→ Esperando (fuera)** si la sala está llena.
- **Esperando (fuera) → Esperando (dentro)** cuando se libera una plaza, respetando el orden de turno.
- **Esperando (dentro) → Llamada** cuando un puesto compatible libre la toma (FIFO; ODAC por prioridad).
- **Esperando (fuera/dentro) → Abandonando** si la paciencia llega a 0 → emite `"abandono"` (Satisfacción −,
  oportunidad perdida).
- **🔒 Compromiso de servicio:** una vez en **Llamada** o **En atención**, la Persona **ya no abandona** — se
  la atiende hasta el final aunque el puesto cierre o acabe el horario (regla de cierre, ver Edge Cases).

**B. Estados del Puesto**

| Estado | Descripción | Transiciones |
|--------|-------------|--------------|
| **Cerrado** | No operativo (jugador u horario) | → Abierto sin agente (abrir) |
| **Abierto sin agente** | Abierto pero sin agente → **no atiende** (FL4) | → Libre (asignar agente) · → Cerrado |
| **Libre** | Abierto + agente, sin Persona | → Atendiendo (toma Persona compatible) · → Abierto sin agente (quitar agente) · → Cerrado |
| **Atendiendo** | Procesando un trámite (`duracion_efectiva`) | → Libre (al terminar y emitir `"trámite completado"`) |

**Notas:**
- **Cerrar / quitar agente durante Atendiendo:** la atención en curso **se termina** primero (compromiso de
  servicio), luego el puesto pasa a Cerrado / Abierto-sin-agente. Genera **peonada** si termina fuera de
  horario (Economía F4).
- **Reconfigurar (ODAC):** no es un estado propio; cambia el filtro `atenciones_admitidas` estando **Libre**
  (o afecta a la próxima llamada). No interrumpe una atención en curso (FL9).
- En **Pausa** ninguna transición ocurre (FL8).

### Interactions with Other Systems

| Sistema | Qué fluye (Flujo ↔ él) | Dueño de la interfaz |
|---------|------------------------|----------------------|
| **Tiempo** | *pull* `delta` (mueve gente, avanza atención) + estado **pausa** (congela todo) | Tiempo provee; Flujo consume |
| **Datos y Configuración** | *lee* `duracion_min`, `tipo_puesto`, `atenciones_admitidas`, `aforo_espera`, `prioridad`, `reconfigurable` por `id` | Datos posee los valores |
| **Generación de Demanda #5** | *recibe* las Personas creadas (cuántas / cuándo / qué trámite) y las encola | Demanda decide el volumen; Flujo las mueve *(provisional)* |
| **Paciencia y Satisfacción #10** | *provee* el estado/tiempo de espera; *recibe* la orden de **abandono** al agotarse la paciencia; *emite* `"trámite completado"` (bonus atención) y `"abandono"` | Paciencia posee la curva y el umbral; Flujo ejecuta la salida *(provisional)* |
| **Personal / Agentes #6** | *lee* el agente asignado a cada puesto (gate FL4) y sus modificadores | Personal posee la dotación |
| **Construcción y Distribución #7** | *opera sobre* los puestos y salas colocados (posición, aforo) | Construcción posee la colocación física |
| **Documentación #8** | *ejecuta* apertura/cierre por horario y el flujo de DNI/Pasaporte/TIE | Documentación posee horarios y política de cita |
| **ODAC / Denuncias #9** | *ejecuta* el flujo de denuncias, la **prioridad** y la **reconfiguración** de puestos | ODAC posee su operativa |
| **Economía / Presupuesto #3** | *emite* `"trámite completado"` (trámite + agente) → Economía abona el retorno DGP | Flujo emite; Economía acredita ✅ (GDD) |
| **Formación y Cursos #29** | *lee* (vía Personal) `modificador_produccion` (→ duración efectiva) y `factor_trato` del agente | Formación posee los valores *(provisional)* |
| **UI / HUD #11** | *expone* colas, número de turno, estado de puestos, y las Personas con su estado | UI presenta |
| **Feedback y Juice #12** | *emite* eventos (llegada, llamada de turno, trámite completado, abandono) para sonido/animación | Flujo provee; Feedback reacciona |

## Formulas

> Las fórmulas de Flujo son **matemática de colas operativa**, no curvas de progresión.
> Modelo **determinista** (coding-standards del proyecto): la espera se **estima**, no se
> simula estocásticamente; la cola estocástica real emerge de Demanda #5. Duraciones en
> **minutos de juego** (día = 1440; Tiempo). Prefijo `F#` como en los GDD hermanos.

### F1 · Duración efectiva de atención

`duracion_efectiva = duracion_min × modificador_produccion(agente)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `duracion_min` | int | 12–60 (Datos F1/F2) | Duración base del trámite/denuncia, en min de juego |
| `modificador_produccion` | float | **[0.5, 1.3]** · **default 1.0** | Lo computa **Personal** desde ⚡Rapidez del agente (Personal F2); Formación #29 lo baja más. **>1.0 = agente lento**, <1.0 = rápido, 1.0 = estándar |
| `duracion_efectiva` | float | ≥ 1 min | Minutos de juego que ocupa el puesto atendiendo |

**Salida:** entre `duracion_min × 0.5` (crack muy formado) y `duracion_min × 1.3` (novato torpe);
1.0 = estándar.
**Ejemplo:** DNI (12) estándar → `12 × 1.0 = 12 min`; con un agente rápido → `12 × 0.76 ≈ 9,1 min`;
con uno lento → `12 × 1.26 ≈ 15,1 min`. *(Los valores exactos del modificador los posee Formación #29 →
provisional; Flujo solo aplica el factor. La rama de atención/satisfacción NO entra aquí: viaja
en el evento `"trámite completado"` y la consume Paciencia/Satisfacción #10.)*

### F2 · Throughput de un puesto (trámites/día)

`throughput_puesto = minutos_operativos_puesto / duracion_efectiva_media`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `minutos_operativos_puesto` | int | 0–1440 | Min de juego que el puesto está **abierto y dotado** en el día *(propiedad de Documentación/Horarios + Tiempo; provisional)* |
| `duracion_efectiva_media` | float | ≥ 1 | Media de `duracion_efectiva` de los trámites que atiende, ponderada por la mezcla de demanda *(mezcla = Demanda #5)* |
| `throughput_puesto` | float | ≥ 0 | Trámites que ese puesto despacha en un día |

**Salida y ejemplos** *(refina el *sanity check* de Datos F8 usando `duracion_efectiva` en
lugar de `duracion_min`)*:
- **Documentación** (ventana **08:00–14:30 = 390 min**, `dur ≈ 15` conservador): `390 / 15 =
  **26 trámites/día**` por puesto. *(DNI a 12 min rinde algo más; 15 es cota conservadora. Ventana base;
  ampliable con peonada — Documentación #8.)*
- **ODAC** (operativo ~16 h = **960 min**, `dur ≈ 30` —media ponderada de las 13 denuncias, Demanda F3 =
  29,75): `960 / 30 = **32 denuncias/día**` por puesto. *(Coincide con el chequeo R5 de Datos F8 y con F3 abajo.)*

### F3 · Capacidad de un servicio (trámites/día) — lado capacidad de R5

`capacidad_servicio = Σ throughput_puesto` (de todos los puestos **abiertos y dotados** del servicio)
`capacidad_max_servicio = num_puestos_max × throughput_puesto` (a tope de construcción)

**Ejemplos a tope de construcción** (topes de Datos F7):
- **Documentación:** (8 `doc_general` + 2 `tie`) × 26 = **≈ 260 trámites/día** en su ventana de 6,5 h.
- **ODAC:** 4 × 32 = **≈ 128 denuncias/día** (24 h con dotación ~16 h; dur. media ponderada ~30, mezcla Demanda F3).

**Conexión con R5 (Datos posee el invariante):** Flujo aporta el **lado capacidad**; Demanda #5
aporta `demanda_max_servicio`; Datos verifica `capacidad_max_servicio ≥ demanda_max_servicio`.
Con la estimación actual (ODAC ~30–60/día) → **absorbe con margen** ✔. *(Flujo no recalcula R5;
solo expone la capacidad que Datos consume.)*

### F4 · Factor de carga (ρ) y estabilidad de la cola

`ρ = tasa_llegadas / capacidad` *(misma unidad de tiempo en numerador y denominador)*

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `tasa_llegadas` | float | ≥ 0 | Personas/hora que llegan a ese servicio *(Demanda #5; provisional)* |
| `capacidad` | float | ≥ 0 | Trámites/hora de los puestos activos = `puestos_activos × (60 / duracion_efectiva_media)` |
| `ρ` (rho) | float | ≥ 0 | Factor de carga |

**Lectura (el "cuello de botella" que el jugador siente, Pilares 2/4):**
- `ρ < 1` → la cola es **estable**, la espera converge.
- `ρ ≥ 1` → la cola **crece**; sin cita (FL7) la única válvula es la **paciencia/abandono**
  (#10), nunca un atasco irresoluble.
- **`capacidad = 0`** (ningún puesto abierto y dotado): `ρ` es **indefinido (∞)** — nadie atiende, la cola
  solo crece y se drena por abandono. *Es el edge "todos los puestos cerrados": no es una división por cero
  real, sino la señal de "abre/dota un puesto" (Pilar 4). La UI lo muestra como "sin servicio", no como un
  número.*

**Ejemplo (la hora punta del Player Fantasy):** 1 ventanilla de Documentación despacha
`60/15 = 4/h`; si llegan **8/h**, `ρ = 8/4 = 2` → la cola se estira. El jugador **abre una 2.ª
ventanilla** → capacidad `8/h`, `ρ = 1` → la cola **deja de crecer y empieza a bajar**. *(Esta es
la palanca de "lo he arreglado yo".)*

### F5 · Estimación de tiempo de espera (para UI y percepción de paciencia)

`espera_estimada = (personas_delante / puestos_compatibles_activos) × duracion_efectiva_media`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `personas_delante` | int | ≥ 0 | Personas por delante en la cola compatible (mismo `servicio`, orden de F7) |
| `puestos_compatibles_activos` | int | ≥ 0 | Puestos **Libres/Atendiendo** que pueden atender su trámite (`atenciones_admitidas`) |
| `duracion_efectiva_media` | float | ≥ 1 | De F2 |
| `espera_estimada` | float | ≥ 0 min | Estimación determinista, no simulación estocástica |

**Salida:** minutos de juego. **Ejemplo:** 8 personas delante, 1 puesto, `dur 15` → `8 × 15 =
120 min`; al abrir un 2.º puesto → `8/2 × 15 = 60 min`. *(Estimación legible: supone que los
puestos se liberan de forma pareja. Si `puestos_compatibles_activos = 0`, la espera es
"indefinida" → señal de servicio cerrado/sin dotar. El **umbral y la curva reales de abandono**
los posee Paciencia #10; Flujo solo provee esta estimación.)*

### F6 · Aforo de sala y desbordamiento a cola exterior (FL6)

`hay_plaza_dentro = (ocupacion_dentro < aforo_espera)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `ocupacion_dentro` | int | 0–`aforo_espera` | Personas en estado *Esperando (dentro)* de ese servicio |
| `aforo_espera` | int | Doc **40** · ODAC **10** (Datos F4) | Capacidad interior de la sala |

**Regla:** al llegar (FL6), si `hay_plaza_dentro` → *Esperando (dentro)*; si no → *Esperando
(fuera)*. Al liberarse una plaza (alguien pasa a *Llamada* o abandona), entra el **primero de la
cola exterior** por orden de turno (F7). *(El **dimensionado** de `aforo_espera` lo posee
Datos/Construcción vía la regla F8 de Datos —`aforo ≈ Σ puestos × (60/dur_media)`—; Flujo solo
comprueba ocupación vs aforo, no lo recalcula.)*

### F7 · Regla de selección de cola (a quién llama un puesto libre, FL2/FL3)

Un puesto **Libre** elige, de su cola de servicio, la persona **compatible** con la **clave de
orden mínima**:

`compatible(persona, puesto) = tramite(persona) ∈ atenciones_admitidas(puesto)`
`clave_orden(persona) = (rango_prioridad, numero_turno)` → se elige el **mínimo**

| Componente | Valores | Descripción |
|-----------|---------|-------------|
| `rango_prioridad` | Prioritaria = 0 · Normal = 1 | ODAC ordena por prioridad (VioGén=Prioritaria primero, Datos F2); Documentación no tiene prioridad → todos = 1 |
| `numero_turno` | int creciente | Contador FIFO por servicio, asignado al coger número (FL2) |

**Resultado:** Documentación = **FIFO puro** (todos rango 1 → gana el `numero_turno` menor). ODAC
= **prioridad y luego FIFO** (todas las Prioritarias antes que las Normales; dentro de cada grupo,
por turno). Si **ninguna** persona en cola es compatible, el puesto **espera** (no adelanta a una
incompatible). *(Empates de `numero_turno` imposibles: el contador es único por servicio.)*

**Notas de frontera (qué NO calcula Flujo):** `tasa_llegadas` y la mezcla de trámites
(**Demanda #5**), la **curva/umbral de abandono** (**Paciencia #10**), `minutos_operativos_puesto`
y los horarios (**Documentación/Horarios + Tiempo**), y el valor exacto de `modificador_produccion`
(**Formación #29**). Todos entran como **entradas provisionales** hasta que sus GDD existan.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre el espacio de reglas
(FL1–FL10) y fórmulas (F1–F7).*

- **Si la sala está a aforo y siguen llegando personas:** entran a **cola exterior**, que en el
  MVP **no tiene tope** — puede crecer sin límite; la única válvula es la **paciencia/abandono**
  (#10), nunca un bloqueo. *Coherente con FL7 "sin cita": la demanda se acota por abandono, no por
  un muro. (La cita previa #14 sería el tope real, fuera del MVP.)*

- **Si el jugador cierra un puesto (o le quita el agente) mientras atiende o con una llamada ya
  emitida:** el puesto **termina** a la persona en atención Y a la que venía de camino (estado
  *Llamada*) —**compromiso de servicio** (FL10, States)— y **solo entonces** pasa a Cerrado / Sin
  agente; deja de llamar a **nuevas**. No re-encola a nadie. *Evita el caso raro de re-encolado y
  respeta que en Llamada/En atención ya no se abandona. Si termina fuera de horario, genera peonada
  (Economía F4).*

- **🔑 Si un servicio llega a su hora de cierre con gente ya con número/en cola (regla de última
  admisión):** **no se expulsa a nadie** — se **cierra la puerta a nuevas llegadas** (dejan de
  coger número) y el personal **vacía la cola ya admitida** hasta terminarla (genera peonada,
  Economía F4). *Evita dejar gente tirada (fallo visto en el prototipo HTML) y castigar la
  satisfacción injustamente. Flujo posee "vaciar la cola"; la "última admisión" (a partir de qué
  hora no se da número) la posee Documentación/Horarios → provisional.*

- **Si dos o más puestos quedan libres a la vez y compiten por la misma primera persona
  compatible:** la toma **un solo puesto**, resuelto por **desempate determinista** (menor
  `id`/índice de puesto). Los demás siguen buscando la siguiente compatible. *Impide que dos
  puestos "tomen" a la misma Persona; el orden fijo garantiza determinismo (misma partida → mismo
  resultado).*

- **Si todos los puestos de un servicio están cerrados o sin agente y hay cola:** nadie es llamado;
  la cola **crece y se drena por abandono** (paciencia). **No es un estado de error** — es la señal
  de que el jugador debe abrir/dotar. *La "frustración de no poder hacer nada" está prohibida
  (Pilar 4): siempre hay palanca (abrir/asignar), pero el juego no la fuerza.*

- **Si llega gente de un trámite para el que no hay ningún puesto construido/dotado** (p. ej.
  clientes de TIE sin `puesto_tie`): **cogen número y esperan**, pero nadie compatible los llama →
  esperan hasta **abandonar**. *No es error a nivel de instancia (Datos ya avisa en carga si un
  `servicio_activo` no tiene `TipoPuesto`); es realimentación de "te falta un puesto".*

- **Si se reconfigura un puesto ODAC (FL9) mientras hay cola:** el cambio de `atenciones_admitidas`
  afecta **a la próxima llamada**, no a la atención en curso; las personas en cola que dejan de ser
  compatibles **siguen esperando** a otro puesto compatible. Si el jugador deja un tipo de denuncia
  **sin ningún puesto** que lo atienda, esas personas esperan hasta abandonar. *La reconfiguración
  no expulsa; una mala reconfiguración se paga en abandonos, no en un crash.*

- **Si ODAC se satura de denuncias Prioritarias (VioGén) y las Normales no avanzan (inanición):** en
  el MVP **no hay anti-inanición** (aging) — las Normales esperan tras todas las Prioritarias y, si
  la presión es alta, **abandonan**. *Con el volumen realista de VioGén el caso es raro; se acepta
  en MVP y se marca como Open Question si el playtest muestra Normales de ODAC crónicamente
  tiradas.*

- **Si el juego se pausa a mitad de una atención o desplazamiento:** todo se **congela** y al
  reanudar continúa con el **tiempo restante exacto** (no se reinicia ni se pierde progreso). *FL8 +
  determinismo: Pausa nunca acelera ni resetea el ciclo de atención.*

- **Si `modificador_produccion` llega con un valor inválido** (≤ 0 por dato corrupto de Personal/Formación):
  `duracion_efectiva` se **clampa a un mínimo seguro** (`≥ 1 min`); la atención nunca es instantánea
  ni negativa. *Mismo patrón de clamp que Datos (`duracion_min ≥ 1`) y Tiempo (`escala_tiempo`).*

- **Si un servicio tiene `aforo_espera = 0`** (sin sala de espera construida): nadie espera dentro;
  **todos van a cola exterior**. Funcional pero indeseable. *Flujo lo tolera; Datos/Construcción
  avisan del dimensionado. No rompe el flujo.*

- **Si se guarda la partida con colas y atenciones en curso:** al cargar se **restaura** el estado
  de cada Persona (estado, `numero_turno`, posición) y de cada Puesto (a quién atiende, tiempo
  restante), y la partida **arranca en Pausa** (Tiempo). No se re-disparan eventos retroactivos.
  *Cargar sitúa, no reproduce — coherente con Tiempo y Economía.*

## Dependencies

*Dirección + naturaleza (Hard = Flujo no cumple su función sin ello; Soft = lo mejora). `✅ GDD` =
diseñado; *(provisional)* = sin GDD aún, contrato definido aquí.*

**Este sistema depende de:**

| Sistema | Tipo | Interfaz (qué lee/consume) |
|---------|------|-----------------------------|
| **Tiempo** | Hard | *pull* `delta` (mueve gente, avanza atención) + estado **pausa** (congela todo) ✅ GDD |
| **Datos y Configuración** | Hard | *lee* `duracion_min`, `tipo_puesto`, `atenciones_admitidas`, `aforo_espera`, `prioridad`, `reconfigurable` por `id` ✅ GDD |
| **Generación de Demanda #5** | Hard | *recibe* las Personas creadas (cuántas/cuándo/qué trámite) para encolarlas *(provisional)* |
| **Personal / Agentes #6** | Hard | *lee* el agente asignado a cada puesto (gate FL4) y sus modificadores *(provisional)* |
| **Construcción y Distribución #7** | Hard | *opera sobre* los puestos y salas colocados (posición, `aforo_espera`, existencia) *(provisional)* |
| **Paciencia y Satisfacción #10** | Hard\* | *provee* estado/tiempo de espera; *recibe* la orden de **abandono** al agotarse la paciencia. \*Sin ella, default seguro: nadie abandona *(provisional)* |
| **Documentación #8 / ODAC #9** | Hard | *ejecutan* apertura/cierre por horario, la **última admisión**, la **prioridad** y la **reconfiguración**; Flujo solo aplica el estado resultante *(provisional; relación mutua — ver nota)* |
| **Formación y Cursos #29** | Soft | *lee* (vía Personal) `modificador_produccion` → `duracion_efectiva` (F1). Default 1.0 sin ella *(provisional)* |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz (qué recibe de Flujo) |
|---------|------|--------------------------------|
| **Economía / Presupuesto #3** | Hard | *escucha* `"trámite completado"` (trámite + agente) → abona el retorno DGP al instante ✅ GDD |
| **Paciencia y Satisfacción #10** | Hard | *recibe* `"trámite completado"` (bonus de atención) y `"abandono"` (satisfacción −) *(provisional; relación mutua)* |
| **Documentación #8 / ODAC #9** | Hard | *usan* el motor de flujo para tramitar sus Personas (colas, atención) *(provisional; relación mutua)* |
| **UI / HUD #11** | Hard | *expone* colas, `numero_turno`, estado de puestos, y cada Persona con su estado y `espera_estimada` (F5) |
| **Feedback y Juice #12** | Soft | *emite* eventos (llegada, llamada de turno, trámite completado, abandono) para sonido/animación |
| **Guardado y Carga** | Hard | *serializa/restaura* el estado de colas, puestos y Personas (Edge Cases) |

> **Nota — relaciones mutuas:** con **Documentación/ODAC** y **Paciencia**, la dependencia es
> **bidireccional**. Flujo es el *motor* (mueve, encola, atiende); Documentación/ODAC *configuran su
> comportamiento* (horarios, última admisión, prioridad, reconfiguración) y Paciencia *decide el
> abandono*. Flujo **posee** el ciclo de la Persona y el evento `"trámite completado"`; los demás
> **parametrizan** ese ciclo. Se resuelve limpiamente al escribir sus GDD.

> **Consistencia bidireccional:** estas dependencias están registradas en `systems-index.md`. Todos los
> **dependientes del MVP** (Economía, Paciencia, Documentación, ODAC, UI, Feedback) ya están escritos y
> listan la relación con Flujo; los **upstream** (Tiempo, Datos, Demanda, Personal, Construcción) también.
> Solo Guardado #20 (futuro) queda por añadirla al redactarse.

## Tuning Knobs

> **Flujo es un motor, no un panel de balance.** Casi todo lo que "se siente" (la dificultad del
> cuello de botella) se tunea en **otros sistemas**; Flujo los consume. Por eso se separan los
> **knobs propios** (pocos, cosméticos o de política MVP) de los **referenciados** (dueño externo,
> no se duplican).

### Knobs propios de Flujo

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `duracion_desplazamiento_seg` (caminar a coger número / al puesto / salir) | ~1–2 s de juego | 0 – 5 s | **Cosmético** (no cuenta para el balance, FL5). ↑ se ve más "vivo" pero más lento / ↓ más ágil; 0 = teleport | Flujo |
| `habilitar_aging_odac` (anti-inanición de Normales tras Prioritarias) | **false** (MVP) | {false, true} | true = las Normales suben de prioridad al esperar mucho (evita inanición); MVP off (Edge Cases) | Flujo / ODAC |
| `tope_cola_exterior` | **0 = sin tope** (MVP) | 0 (∞) – N | >0 pondría un muro a la afluencia; MVP sin tope (la válvula es paciencia, FL7). La cita #14 es el tope "de verdad" | Flujo / Demanda |

*(Regla **no tunable** —fija por determinismo—: el desempate entre puestos que compiten por la misma
Persona es siempre por **menor `id` de puesto** (Edge Cases). No se expone como knob.)*

### Knobs referenciados (dueño externo — Flujo los lee, **no** los duplica)

| Knob | Dónde vive | Efecto sobre el flujo |
|------|-----------|-----------------------|
| `duracion_min` (por trámite/denuncia) | Datos → Documentación/ODAC | Entra en `duracion_efectiva` (F1) → throughput (F2) y espera (F5) |
| `modificador_produccion` | Formación #29 | Acorta `duracion_efectiva` (F1); sube el throughput |
| `aforo_espera` (Doc 40 / ODAC 10) | Datos → Construcción/Paciencia | Cuándo se desborda a cola exterior (F6) |
| `atenciones_admitidas` · `prioridad` · `reconfigurable` | Datos → ODAC | A quién puede llamar cada puesto y en qué orden (F7) |
| perfil de `tasa_llegadas` (volumen, picos, mezcla) | Demanda #5 | El numerador de ρ (F4) — **el principal driver del reto** |
| curva/umbral de paciencia y abandono | Paciencia #10 | Cuánto aguanta la cola antes de drenarse |
| `minutos_operativos` · horarios · última admisión | Documentación/Horarios + Tiempo | La ventana de servicio en el throughput (F2) |
| `escala_tiempo` (default 4) | Tiempo | El ritmo al que todo el flujo transcurre |
| `tope_construible` (por servicio) | Datos/Construcción | El techo de `capacidad_max_servicio` (F3) — cuánto puede aliviar el jugador |

**Interacciones entre knobs (clave de diseño):**
- **El reto del cuello de botella NO se tunea en Flujo.** Lo gobiernan `tasa_llegadas` (Demanda)
  contra `capacidad` (= `tope_construible` × throughput, que depende de `duracion_min` y
  `minutos_operativos`). Flujo solo hace que ese balance **se sienta y se lea** (F4).
- **`aforo_espera` vs `tasa_llegadas`** deciden con qué frecuencia se ve la **cola exterior** (F6):
  un aforo generoso la oculta; uno justo la muestra antes.
- **`escala_tiempo` (Tiempo)** multiplica la percepción de todo: a mayor escala, las colas crecen y
  se vacían más rápido en tiempo real.
- **`habilitar_aging_odac`** solo importa si Demanda mete muchas Prioritarias; con volumen bajo de
  VioGén es inerte.

**Restricción:** los knobs referenciados mantienen su rango en el GDD dueño; Flujo no los
sobrescribe. `duracion_desplazamiento_seg ≥ 0`; `tope_cola_exterior ≥ 0` (0 = sin tope).

## Visual/Audio Requirements

*Flujo declara feedback; lo sonoriza/anima **Feedback/Juice #12**. Estilo del **art bible**: vista
cenital, claridad funcional, "la gente cuenta la historia", geometría ortogonal, respaldo daltónico
(icono/forma/texto, nunca solo color).*

| Evento (Flujo) | Visual | Audio | Prioridad |
|---|---|---|---|
| **Llegada** de una Persona | Silueta por rol entra por la puerta (denunciante = carpeta/papel; ciudadano = neutro — art bible §3) y va a coger número | — *(sin sonido)* | Media |
| **Espera** (dentro/fuera) | Color de **paciencia** verde→ámbar→rojo con respaldo (opacidad + parpadeo al bajar); la **cola exterior** se ve en la calle cuando el aforo está lleno | Murmullo ambiente | **Alta** (legibilidad del cuello de botella) |
| **Llamada de turno** | La Persona se levanta y camina al puesto (desplazamiento corto, FL5); el puesto lo indica | **"Ping" de turno** (aviso de ventanilla, muy institucional) | Media-alta |
| **En atención** | Persona sentada en el puesto; puesto en **verde** (atendiendo); indicador de progreso de `duracion_efectiva` | Tecleo/sello suave | Media |
| **Trámite completado** | Persona se levanta y sale satisfecha; ✓/destello sutil | Sello + tintineo (ata "buen servicio") *(el ingreso lo sonoriza Economía)* | Media |
| **Abandono** | Persona se marcha con postura molesta; ✗/icono | Portazo/suspiro sobrio | **Alta** (feedback de fallo) |
| **Estado de puesto** | **verde** atendiendo · **azul** libre · **ámbar** sin agente · **gris** cerrado (art bible §4) | — | Siempre visible |
| **Cola desbordada** (hora punta) | Cola en **rojo** que se estira hacia la puerta (estado "fracaso/agobio" del art bible §2) | Ambiente más denso | **Alta** |

*Siluetas legibles por **rol + color + accesorio** (no por la cara, invisible en cenital).
Trámites/denuncias SIEMPRE con **icono + etiqueta** además del color (daltónicos). VioGén
(Prioritaria) se distingue con marca de urgencia (rojo + icono), no solo por orden.*

> 📌 **Asset Spec** — Con estos requisitos definidos, tras aprobar el art bible se puede ejecutar
> `/asset-spec system:flow-queues` para generar descripciones y prompts de los assets del flujo
> (siluetas de ciudadano/denunciante, panel de turno, estados de puesto por color, VFX de
> completado/abandono).

## UI Requirements

*Flujo **expone los datos**; la pantalla la posee **UI/HUD #11**. La UI nunca hardcodea (lee
nombres/iconos de Datos). Dirigida por **ratón** (clic), sin interacciones solo-hover (preferencias
técnicas → gamepad futuro).*

**Lo que Flujo expone para mostrar:**
- **Por servicio (cola):** nº de personas en cola, **número de turno** llamado (panel tipo pantalla
  de oficina — muy temático), y **`espera_estimada`** (F5).
- **Cola exterior:** cuántas Personas esperan fuera (aforo lleno, F6).
- **Por puesto:** estado (abierto/cerrado · con/sin agente · atendiendo) con el **color** del art
  bible, a quién atiende y el progreso de la atención.
- **Por Persona:** su estado (Esperando dentro/fuera · Llamada · En atención) y su **trámite** (icono
  + etiqueta + color).

**Controles del jugador que Flujo ejecuta** (la orden viene de UI):
- **Abrir / cerrar** un puesto (clic). *(Cerrar respeta el compromiso de servicio — Edge Cases.)*
- **Asignar / quitar** agente a un puesto *(compartido con Personal #6)*.
- **Reconfigurar** un `puesto_odac` — qué denuncias atiende *(operativa de ODAC #9; FL9)*.

**Anti-micromanejo (Pilar 4):** el jugador **no** dirige personas a puestos — asigna **agentes** y
abre **puestos**; el emparejamiento persona↔puesto es automático (FL3). La UI refuerza esto: se
actúa sobre puestos/agentes, nunca sobre individuos en cola.

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.*
> Al menos un criterio por regla (FL1–FL10) y por fórmula (F1–F7).

**Unidad y colas (FL1, FL2, F7)**
- **AC-FL01** `[Unit]` — GIVEN Demanda crea una Persona de `dni` WHEN entra THEN tiene `servicio=Documentacion`, `tramite=dni`, un `numero_turno`, estado inicial **Llegando** y una referencia de paciencia.
- **AC-FL02** `[Unit]` — GIVEN dos Personas del mismo servicio WHEN cogen número THEN reciben `numero_turno` **consecutivos crecientes** (contador único por servicio).
- **AC-FL03** `[Unit]` — GIVEN cola de Documentación con turnos {3,1,2} WHEN un puesto llama THEN sirve en orden **1,2,3** (FIFO puro, menor `numero_turno`).
- **AC-FL04** `[Unit]` — GIVEN cola ODAC con Normal(turno 1) y Prioritaria(turno 2) WHEN un puesto llama THEN sirve **la Prioritaria primero** (F7: rango 0 antes que 1).
- **AC-FL05** `[Unit]` — GIVEN un `puesto_tie` y una cola que solo contiene DNI/Pasaporte WHEN evalúa THEN **no llama a nadie** (ninguna compatible → espera).

**Asignación y atención (FL3, FL4, FL5, F1)**
- **AC-FL06** `[Integration]` — GIVEN `puesto_doc_general` Libre y cola [tie, dni, pasaporte] WHEN llama THEN toma **`dni`** (primera compatible por turno), **no** `tie`.
- **AC-FL07** `[Integration]` — GIVEN puesto **abierto sin agente** y cola compatible WHEN evalúa THEN **NO atiende** (FL4).
- **AC-FL08** `[Integration]` — GIVEN puesto abierto **con agente** y cola compatible WHEN llama THEN pasa a **Atendiendo**.
- **AC-FL09** `[Unit]` — GIVEN `dni` (12) y `modificador_produccion=1.0` THEN `duracion_efectiva=12`; con `0.7` → **8,4** (F1).
- **AC-FL10** `[Unit]` — GIVEN `modificador_produccion=0` (corrupto) WHEN F1 THEN `duracion_efectiva` se clampa a **1 min** (nunca instantánea/negativa).
- **AC-FL11** `[Integration]` — GIVEN una atención en curso WHEN cumple `duracion_efectiva` THEN se emite **`"trámite completado"`** (trámite+agente) **una vez**, la Persona pasa a **Resuelta** y sale, y el puesto queda **Libre**.

**Aforo y desbordamiento (FL6, F6)**
- **AC-FL12** `[Unit]` — GIVEN `aforo_espera=40` y `ocupacion_dentro=39` THEN `hay_plaza_dentro=true`; con `ocupacion=40` → **false**.
- **AC-FL13** `[Integration]` — GIVEN sala Doc a aforo (40) WHEN llega la 41ª THEN va a **Esperando (fuera)**; WHEN se libera una plaza THEN entra **la primera de la cola exterior** por orden de turno.

**Sin cita, pausa, reconfiguración, abrir/cerrar, compromiso (FL7–FL10)**
- **AC-FL14** `[Integration]` — GIVEN `requiere_cita=false` y llegadas > capacidad WHEN transcurre el tiempo THEN la cola **crece sin tope de Flujo** (no hay bloqueo; la válvula es abandono).
- **AC-FL15** `[Unit]` — GIVEN una atención con 5 min restantes y turnos por asignar WHEN el juego está en **Pausa** THEN la atención **no avanza** y **no se asignan** nuevos turnos (FL8).
- **AC-FL16** `[Integration]` — GIVEN `puesto_odac` atendiendo `viogen` WHEN se reconfigura a solo `estafa` THEN la atención de `viogen` **NO se interrumpe** y la **próxima** llamada solo considera `estafa` (FL9).
- **AC-FL17** `[Integration]` — GIVEN un puesto Atendiendo WHEN el jugador lo **cierra** THEN **termina** la atención en curso, **luego** pasa a Cerrado, y **no llama a nuevas** (FL10).
- **AC-FL18** `[Integration]` — GIVEN una Persona en **Llamada** o **En atención** con la paciencia agotada WHEN se evalúa el abandono THEN **NO abandona** (compromiso de servicio).

**Capacidad y espera (F2, F3, F4, F5)**
- **AC-FL19** `[Unit]` — GIVEN `minutos_operativos=390` y `duracion_efectiva_media=15` THEN `throughput_puesto=26` trámites/día (F2).
- **AC-FL20** `[Unit]` — GIVEN 2 puestos a 26 THEN `capacidad_servicio=52`; a tope Doc (8+2 puestos) → **≈260** (F3).
- **AC-FL21** `[Unit]` — GIVEN llegadas 8/h y 1 puesto (cap 4/h) THEN `ρ=2` (cola crece); WHEN se abre un 2.º (cap 8/h) THEN `ρ=1` (estable) (F4).
- **AC-FL22** `[Unit]` — GIVEN 8 personas delante y 1 puesto (dur 15) THEN `espera_estimada=120`; con 2 puestos → **60**; con 0 puestos → **indefinida** (F5).

**Edge cases críticos y determinismo**
- **AC-FL23** `[Integration]` — GIVEN dos puestos Libres simultáneos y **una** sola Persona compatible WHEN ambos evalúan THEN la toma **exactamente uno** (menor `id`); el otro sigue Libre (sin doble asignación).
- **AC-FL24** `[Integration]` — GIVEN Documentación en su hora de cierre con cola ya admitida WHEN cierra THEN **vacía la cola admitida** (genera peonada) y **cierra la puerta a nuevas** (última admisión).
- **AC-FL25** `[Unit]` — GIVEN una atención con 5 min restantes WHEN se pausa y luego se reanuda THEN continúa con **5 min exactos** (sin reinicio ni pérdida).
- **AC-FL26** `[Unit]` — GIVEN un save con una cola de N y una atención con `t` restante WHEN se carga THEN se restauran N, estados y `t`, y arranca en **Pausa**; sin eventos retroactivos.
- **AC-FL27** `[Unit]` — GIVEN la misma secuencia de llegadas/acciones desde idéntico estado WHEN se ejecuta dos veces THEN colas, asignaciones y eventos son **idénticos** (determinismo; sin dependencia de reloj real ni semillas).

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | **Última admisión**: a partir de qué hora exacta Documentación deja de dar número al acercarse el cierre (Flujo vacía la cola admitida; la hora la fija Documentación). Comparte con Economía Open Q#7 | Documentación + Horarios | GDD Documentación | Abierta |
| 2 | **Anti-inanición en ODAC**: ¿hace falta `aging` si el playtest muestra denuncias Normales crónicamente tiradas tras las Prioritarias (VioGén)? MVP arranca sin él (Edge Cases) | ODAC + playtest | 1er playtest MVP | Abierta |
| 3 | **Valores de `modificador_produccion`**: lo computa **Personal** desde ⚡Rapidez (Personal F2); **Formación #29** lo mejora **por skill** (no 2 ramas). Valores de mejora → GDD #29 | Personal + Formación #29 | GDD Formación | Abierta |
| 4 | **Perfil de `tasa_llegadas`**: volumen, picos intradía/semanales y **mezcla de trámites** — el numerador de ρ (F4) y de `duracion_efectiva_media` (F2). Comparte con Datos Open Q#2 | Demanda #5 | GDD Demanda | Abierta |
| 5 | **Curva/umbral de paciencia y abandono**: cuánto aguanta la cola; ¿esperar **fuera** penaliza más que dentro (FL6)? | Paciencia y Satisfacción #10 | GDD Paciencia | Abierta |
| 6 | **`minutos_operativos` por puesto**: ventana real de servicio (Doc **08:00–14:30 = 390 min**; ODAC ~16 h supuesto en Datos F8) — confirmar con la dotación por turno | Documentación/ODAC + Horarios + Tiempo | GDDs respectivos | Abierta |
| 7 | **Peonadas en el MVP**: ¿el mecanismo de hora extra (que dispara la última admisión y el cierre en caliente) existe ya en el MVP o solo con Horarios #13? Comparte con Economía Open Q#8 | Horarios/Personal + Economía | GDD Documentación/Horarios | Abierta |
| 8 | **Persona en Llamada si su puesto se cae**: se decidió "completa la llamada" (no re-encola, Edge Cases); validar que se siente bien vs re-encolar | Diseño + playtest | 1er playtest MVP | Abierta |
| 9 | **Duración del desplazamiento cosmético** (`duracion_desplazamiento_seg`): valor que se ve "vivo" sin ralentizar; no afecta al balance (FL5) | Feedback/UX + playtest | 1er playtest MVP | Abierta |
