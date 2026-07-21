# Personal / Agentes

> **Status**: In Design
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / systems-designer — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-21
> **Last Verified**: 2026-07-21
> **Implements Pillar**: Pilar 2 — "La comisaría está viva" (agentes con nombre) + Pilar 4 — "Tu comisaría, tus decisiones"

## Overview

El sistema de **Personal / Agentes** gobierna la **plantilla** de la comisaría: a quién **contratas**,
cómo lo **asignas** y cómo **gestionas** al equipo que atiende al público. Cada agente es un **individuo
con nombre**, un **tipo** (Documentación u ODAC — qué puestos opera), un **rango** (Policía o **Oficial**;
tú eres el **Subinspector** que los dirige) y **cuatro atributos** que definen lo bueno que es:
**⚡ Rapidez** (velocidad de tramitación), **🤝 Trato** (atención al ciudadano), **❤️ Salud** (resistencia
a faltar) y **🔥 Motivación** (moral). Contratas de un **mercado de candidatos variados** —mejores
atributos cuestan **más salario**, y nadie es perfecto— y los **asignas** a puestos que puedan operar, lo
que **habilita** que ese puesto atienda (el gate de *Flujo*). Al día se paga la **nómina** (*Economía*), y
de vez en cuando un agente **no acude** (ausencia): ahí entra el **Oficial** (máx. 1 por servicio), el
mando que **cubre** las bajas y **canaliza** las incidencias para que no te lluevan de una en una. Lee de
*Datos* (tipos, salario base, `puestos_operables`) y de *Economía* (gate de contratación y cobro de
salarios); provee a *Flujo* el **agente de cada puesto** y sus **modificadores** (Rapidez → duración
efectiva, Trato → satisfacción al cerrar).

A nivel de diseño, **Personal es tu equipo, y cada decisión sobre él pesa** (Pilar 4). El corazón es una
tensión de recursos: *"¿ficho al crack caro o a varios medianos baratos? ¿al especialista rapidísimo pero
seco, o al equilibrado? ¿pago un Oficial para que la oficina se autogestione, o me ahorro la nómina y
cargo yo con los marrones?"* Y como los agentes tienen **nombre, cara y atributos**, la comisaría se
siente **viva** (Pilar 2): no gestionas fichas anónimas, sino a **Ana, la funcionaria rapidísima de DNI**,
o al **Oficial que te tapa los agujeros**. Sin esta capa no hay quien atienda los puestos —*Flujo* no
mueve una cola sin un agente detrás— ni la presión de una nómina que hay que justificar: el personal es lo
que convierte los puestos vacíos en un **servicio con gente que lo saca adelante**.

> **Regla de propiedad:** Personal **posee** la *plantilla* (instancias de agente: identidad,
> **atributos**, rango, asignación y estado), la *contratación/despido*, la *asignación a puestos*, las
> *ausencias* y la figura del *Oficial* (cobertura + canalización). **Lee** de *Datos* (`TipoAgente`,
> salario **base**, `puestos_operables`) y de *Economía* (gate de gasto, salarios). **Provee** a *Flujo*
> el agente asignado y sus `modificador_produccion` / `bonus_satisfaccion`. **No posee**: el *ciclo de
> atención* (→ Flujo #4), los *valores de mejora* de los atributos (→ **Formación #29**, que Personal solo
> aplica), los *horarios/turnos rotativos* (→ **Horarios #13**; el MVP los simplifica), ni la
> *satisfacción* que consume el bonus de Trato (→ **Paciencia #10**). *(Turnos rotativos, vacaciones,
> guardias y la progresión por formación → diferidos; los ganchos —`tipo_horario` de Datos,
> modificadores— ya están puestos.)*

## Player Fantasy

**Fantasía:** ser el **jefe que monta su equipo y lo ve funcionar** — quien ficha con ojo, coloca a cada
uno donde brilla, y aprende a **delegar** cuando la oficina crece. El orgullo de *"este equipo lo he
armado yo"* (Pilares 2 y 4).

Se vive en dos capas:

- **Control directo (montar el equipo):** el placer de **fichar** en el mercado —sopesar ⚡Rapidez y
  🤝Trato contra lo que pide de nómina—, poner a la crack en el puesto que va atascado, y decidir **en
  quién delegas** (pagar un Oficial que te quite marrones). Es la fantasía del gestor que arma una máquina
  bien engrasada, pieza a pieza, con **coste de oportunidad** en cada decisión.
- **Infraestructura que se vive (tu gente trabaja):** una vez montado, el equipo **funciona solo** —
  atienden, cobran su nómina, y cuando alguien falta, el Oficial lo tapa. Ves a **los tuyos** —con nombre
  y cara— sacar la cola adelante. La comisaría bulle con **tu** gente, no con fichas anónimas.

**El momento a anclar:** el **fichaje que arregla el atasco**. La ventanilla de DNI va lenta y en el
mercado tienes a **una candidata rapidísima (⚡⚡⚡⚡⚡) pero cara** y a **un chico normalito barato**. Te la
juegas con la crack, la pones ahí, y ves la cola **empezar a bajar a ojos vista** porque despacha el
doble: *"buen fichaje."* Y su gemelo emocional: llevas tres días recibiendo avisos de bajas de uno en
uno; contratas un **Oficial** y de golpe la oficina **se cuida sola** — el alivio de haber **delegado
bien**.

**Referencia de sensación:** el mercado de fichajes de *Football Manager*, el *staff* con habilidades de
*Two Point Hospital*, los colonos con nombre de *RimWorld* — la sensación de **"mi equipo"**.
**Anti-fantasía:** NO es una **hoja de personal anónima** (todos con cara y nombre); NO es **micromanejo
forzado** (por eso existe el Oficial para delegar); y NO es **contratar sin decisión** —mejor = más caro y
**nadie es perfecto**, así que siempre hay un trade-off—. Gestionar una baja nunca debe sentirse como un
**castigo tedioso sin salida**: siempre hay palanca (cubrir, delegar, pagar peonada).

*(Nota de proceso: `creative-director` no consultado —modo LEAN + subagentes caídos—; lente creativa
aplicada en el hilo principal.)*

## Detailed Design

### Core Rules

**PA1 · La plantilla: instancias de Agente.** Cada agente contratado es una **instancia** con: `nombre`,
`tipo` (`ag_doc`/`ag_odac`, de Datos), `rango` (Policía/Oficial), cuatro **atributos** (Rapidez, Trato,
Salud, Motivación, escala **1–5**) y —si es Oficial— **Mando**. Referencia un `TipoAgente` de Datos
(salario base, `puestos_operables`, `tipo_horario`). Personal posee la instancia; Datos la plantilla-tipo.

**PA2 · Rango y jerarquía.** El jugador es el **Subinspector** (jefe; **no** es plantilla asalariada).
Bajo él: **Oficiales** (**máx. 1 por servicio** — 1 Documentación, 1 ODAC) y **Policías** (el resto). El
Oficial **atiende un puesto como un agente más** *y además* ejerce de **mando** de su servicio (PA8/PA9).

**PA3 · Atributos del agente.** Cuatro comunes + uno de Oficial:
- ⚡ **Rapidez** → `modificador_produccion` (Flujo F1): más rápido = menor duración efectiva.
- 🤝 **Trato** → `bonus_satisfaccion` (Flujo lo emite al cerrar; lo usan Paciencia/Economía).
- ❤️ **Salud** → **probabilidad de ausencia** (PA7): menos salud, falta más.
- 🔥 **Motivación** → modula **ligeramente** Rapidez+Trato (MVP: modificador global pequeño; moral
  dinámica → futuro, PA10).
- 🎖️ **Mando** (solo Oficial) → **calidad de la cobertura y la canalización** (PA8/PA9).

**Formación #29** sube estos atributos **por skill concreto** (formar Rapidez sube solo Rapidez), con
coste creciente y retorno decreciente (base variada → mejorable; formar **sube el salario** vía F1).
Personal **aplica** los valores; Formación los **posee**.

**PA4 · Contratación (mercado de candidatos).** Al abrir el menú de contratación se genera un conjunto de
**candidatos** (RNG **sembrado**) con atributos **variados** y un `salario_dia` **acorde** (mejor = más
caro; ver Formulas). **Nadie es perfecto** (candidatos top, raros y caros). Contratar exige caja (**gate
Economía E4**); el candidato pasa a la plantilla.

**PA5 · Asignación a puestos.** El jugador **asigna** un agente a un puesto que **pueda operar**
(`puestos_operables` de Datos). Un puesto **con agente** habilita la atención (**gate FL4 de Flujo**). **1
agente por puesto** (`plazas_agente=1`). Un agente puede estar **sin asignar** (en plantilla). Reasignable
en cualquier momento — sin interrumpir una atención en curso (compromiso de servicio de Flujo).

**PA6 · Salarios y despido.** Cada agente cuesta su `salario_dia` (**base × prima**, Formulas) al
`nuevo_dia` (Economía F3). **Despedir** saca al agente de la plantilla (deja de pagarse; libera su puesto).
En el MVP el despido **no tiene coste** (simple).

**PA7 · Ausencias (evento de personal).** Cada día, cada agente tiene una **probabilidad de no acudir**
(ausencia), **inversa a su Salud** (RNG sembrado, determinista). Un agente **ausente** no atiende ese día →
su puesto queda **vacante** (pérdida de capacidad) salvo cobertura.

**PA8 · El Oficial: cobertura automática.** Si el servicio tiene **Oficial**, ante una ausencia este
**reasigna automáticamente** a un agente disponible (sin asignar, o él mismo) para **cubrir** el puesto
vacante. **Cuánto cubre** (nº de bajas, capacidad recuperada) = **f(Mando)**. **Sin Oficial**, la cobertura
es **manual** (el jugador reasigna) o el puesto queda vacante.

**PA9 · El Oficial: canalización de incidencias.** Con **Oficial**, las incidencias del servicio
(ausencias, avisos) se **agrupan** en un aviso resumido y las triviales se **autoresuelven**; solo se
**escala** al jugador lo que exige decisión (p. ej. no hay a quién reasignar → ¿peonada? ¿puesto cerrado?).
**Sin Oficial**, cada incidencia es un **aviso individual**. Cuánto canaliza/autoresuelve = **f(Mando)**.

**PA10 · Motivación (MVP: atributo base).** En el MVP la Motivación es un **atributo base** (los más
motivados rinden algo más — modificador global pequeño a Rapidez/Trato), **sin dinámica**. La **fatiga
dinámica** (trabajar cansa → rinde más lento pero sigue; **día libre** resetea al 100 %, **sala de
descanso** recupera **parcial** sin sustituir al día libre; cadencia ~3–4 días : 1 libre) se **difiere a
Vertical Slice** (Bienestar, liga Horarios #13 + Comodidades #15) — modelo capturado en `systems-index.md`.
El gancho ya está puesto (Motivación modula el rendimiento).

**PA11 · Pausa y determinismo.** En **Pausa** no se evalúan eventos de personal. Las **ausencias** se
resuelven al **inicio del día** (`nuevo_dia`), deterministas por semilla (como Demanda F4).

**PA12 · Cobertura abstracta, sin turnos rotativos (MVP).** Como en la mayoría de tycoon, **1 agente cubre
su puesto** durante el horario del servicio (Documentación diurna; ODAC 24 h); **no hay turnos rotativos**
de personal (se **descartan** de momento). La gestión de **descanso** (días libres / sala) que recupera la
fatiga se **difiere** (Bienestar/#13/#15). *(Los turnos del reloj —mañana/tarde/noche— siguen siendo de
Tiempo, para demanda/ambiente; el `tipo_horario` de Datos queda como gancho.)*

### States and Transitions

**Estados del Agente** (Personal lleva plantilla/asignación/ausencia; el ciclo de *atención* lo lleva
Flujo):

| Estado | Descripción | Sale a |
|--------|-------------|--------|
| **En plantilla (libre)** | Contratado, sin puesto asignado | Asignado (asignar) · *(fuera)* Despido |
| **Asignado** | En un puesto, operativo (Flujo lo pone a *Atendiendo* cuando hay cola) | En plantilla (quitar) · Ausente (evento PA7) · Cubriendo (reasignado) · *(fuera)* Despido |
| **Ausente** | No acude ese día; su puesto queda vacante | Asignado (al reincorporarse, día siguiente) |
| **Cubriendo** | Reasignado temporalmente para tapar una baja (PA8) | Vuelve a su puesto al reincorporarse el titular |

- **Transición clave:** *Asignado → Ausente* al inicio del día si el RNG (según Salud) lo determina; si hay
  Oficial, dispara la **cobertura** (otro agente *libre*/*Asignado* → *Cubriendo*).
- En **Pausa**, ninguna transición de personal ocurre (PA11).

### Interactions with Other Systems

| Sistema | Qué fluye (Personal ↔ él) | Dueño de la interfaz |
|---|---|---|
| **Datos y Configuración** | *lee* `TipoAgente` (salario **base**, `puestos_operables`, `tipo_horario`, `escala_rango`) | Datos posee los valores ✅ GDD |
| **Economía #3** | *provee* el gate "¿puedo contratar?" (E4) y *paga* salarios al `nuevo_dia` (F3, base×prima) | Economía posee el dinero ✅ GDD |
| **Flujo #4** | *provee* el agente asignado a cada puesto (**gate FL4**) y sus `modificador_produccion` / `bonus_satisfaccion` | Personal provee; Flujo consume ✅ GDD |
| **Paciencia y Satisfacción #10** | *(indirecto)* el `bonus_satisfaccion` (Trato) sube la satisfacción al cerrar | Paciencia posee la curva *(provisional)* |
| **Formación y Cursos #29** | *sube* los atributos del agente (Personal aplica los valores) | Formación posee las mejoras *(provisional)* |
| **Construcción #7** | los **puestos** a los que se asignan agentes | Construcción posee la colocación *(provisional)* |
| **Documentación #8 / ODAC #9** | el agente **opera** sus puestos (horario del servicio) | ellos poseen su operativa *(provisional)* |
| **Horarios y Peonadas #13** *(V-Slice)* | *(futuro)* peonadas (horas extra); turnos rotativos **descartados** (modelo abstracto) | Horarios posee *(diferido)* |
| **Bienestar / Comodidades #15** *(V-Slice)* | *(futuro)* fatiga/descanso (día libre + sala de descanso) que recupera la Motivación | #13/#15 poseen *(diferido)* |
| **UI / HUD #11** | *expone* plantilla, mercado de contratación, atributos, avisos del Oficial | UI presenta |
| **Feedback #12** | *emite* eventos (fichaje, ausencia, cobertura, despido) | Feedback reacciona |

## Formulas

> Atributos en escala **1–5** (3 = medio). Números **semilla provisional** a validar en playtest. RNG
> **sembrado/determinista** en lo aleatorio (candidatos, ausencias). Prefijo `F#`.

### F1 · Salario diario efectivo (base × prima)

`salario_dia = salario_base(tipo) × (1 + k_calidad × (media_atributos − 3)/2) × prima_rango`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `salario_base(tipo)` | float | 60 (ag_doc) · 70 (ag_odac) | Salario base del tipo (**Datos**) |
| `media_atributos` | float | 1–5 | Media de Rapidez/Trato/Salud/Motivación |
| `k_calidad` | float | 0.5 | Cuánto encarece la calidad (tuning) |
| `prima_rango` | float | Policía 1.0 · Oficial ~1.3 | El Oficial cuesta más (mando) |

**Salida y ejemplos:** medio (media 3, Policía) → `60 × 1.0 = 60€`. Crack (media 5) → `60 × 1.5 = 90€`.
Mediocre (media 2) → `60 × 0.75 = 45€`. Oficial bueno (media 4) → `60 × 1.25 × 1.3 ≈ 98€`. *(Mejor = más
caro; nadie perfecto = raro y caro.)*

### F2 · Modificador de producción (Rapidez → duración efectiva)

`modificador_produccion = clamp( (1 − 0.1×(Rapidez−3)) × (1 − 0.05×(Motivación−3)) , 0.5 , 1.3 )`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `Rapidez` | int | 1–5 | Velocidad de tramitación |
| `Motivación` | int | 1–5 | Moral (MVP base) |
| salida | float | 0.5–1.3 | Multiplica `duracion_min` (Flujo F1) |

**Salida:** Rapidez 5/Mot 4 → `0.8×0.95 ≈ **0.76**` (24% más rápido). Rapidez 1/Mot 2 → `1.2×1.05 ≈ **1.26**`
(26% más lento). **Ejemplo:** DNI (12 min) con un crack → `12×0.76 ≈ 9,1 min`; con un torpe →
`12×1.26 ≈ 15,1 min`.

> **Rango extendido (decidido 2026-07-21):** `modificador_produccion ∈ [0.5, 1.3]` — un mal fichaje **rinde
> peor que el estándar** (>1.0), no solo "no mejor". Esto refina el rango que Flujo F1 asumió
> provisionalmente (`(0,1]`); Flujo F1 y el registro (`duracion_efectiva`) se actualizan a este rango.
> *(Formación #29 baja aún más el modificador —mejora.)*

### F3 · Bonus de satisfacción (Trato → satisfacción al cerrar)

`bonus_satisfaccion = k_trato × (Trato−3) × (1 + 0.1×(Motivación−3))`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `Trato` | int | 1–5 | Atención al ciudadano |
| `k_trato` | float | 5 (puntos) | Escala del bonus (tuning) |
| salida | float | ~−10…+10 | Puntos de satisfacción al cerrar (los usa Paciencia) |

**Salida:** Trato 5 → `+10`; Trato 3 → `0`; Trato 1 → `−10`. **Ejemplo:** un agente amable sube la
satisfacción del trámite → mejor retorno DGP (Economía F1). *(La escala real de satisfacción 0–100 la posee
**Paciencia #10**; aquí solo se define el aporte del Trato — provisional.)*

### F4 · Probabilidad de ausencia (Salud)

`prob_ausencia_dia = clamp( base_ausencia − k_salud×(Salud−3) , 0 , 1 )`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `Salud` | int | 1–5 | Resistencia a faltar |
| `base_ausencia` | float | 0.03 (3%) | Prob. base a Salud media (tuning) |
| `k_salud` | float | 0.02 | Pendiente por punto de Salud |

**Salida:** Salud 5 → `~1%`/día; Salud 3 → `3%`; Salud 1 → `~7%`/día. RNG **sembrado** (determinista).
*(La fatiga futura subiría esta probabilidad — Bienestar #13/#15.)*

### F5 · Generación de candidatos (mercado)

Cada candidato: cada atributo = tirada RNG **sembrada** con **distribución sesgada al centro** (medias
comunes, extremos **raros**) → los cracks escasean. Su `salario_dia` sale de F1. El mercado ofrece
`n_candidatos` (tuning, p. ej. 3–5) y **se refresca** cada X días o al contratar. *Determinista por
semilla (reproducible).*

### F6 · Cobertura del Oficial (Mando)

`bajas_cubiertas_dia = floor(Mando / 2)` reasignando agentes disponibles (libres primero; si no, mueve de
otro puesto menos crítico).

**Salida:** Mando 1–2 → cubre **1** baja/día; Mando 3–4 → **2**; Mando 5 → **3**. *Sin Oficial → 0
(cobertura manual).* Si no hay a quién reasignar, escala al jugador (F7). *(Valores a afinar en playtest.)*

### F7 · Canalización de incidencias (Mando)

Con Oficial, las incidencias del servicio del día se **agrupan en 1 aviso** y se **autoresuelven las
triviales**; el nº que autoresuelve sin molestarte crece con el Mando (`autoresueltas ≈ Mando`). **Sin
Oficial**, cada incidencia = 1 aviso individual (carga de microgestión). *(Cualitativo; se calibra en
playtest para que el Oficial "se note".)*

**Nota de frontera:** la escala real de satisfacción (F3) la posee **Paciencia #10**; los valores de mejora
de atributos, **Formación #29**; el coste efectivo (F1) lo cobra **Economía**. Todo lo demás (primas,
modificadores, ausencias, Mando) lo posee Personal.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre PA1–PA12 y F1–F7.*

- **Si el jugador intenta contratar sin caja** (`saldo < salario/coste`): la acción se **rechaza** (botón
  deshabilitado, gate Economía E4); no entra en plantilla. *E4: no te endeudas con gasto voluntario.*
- **Si se asigna un agente a un puesto que no puede operar** (fuera de `puestos_operables`): se
  **rechaza**. *Un `ag_doc` no opera un `puesto_odac` (Datos manda).*
- **Si se asigna un agente que ya estaba en otro puesto:** se **mueve** (se libera el puesto anterior) —
  pero **no se interrumpe** una atención en curso: la termina y luego se traslada (compromiso de servicio
  de Flujo). *Reasignar es fluido; nunca corta un trámite a medias.*
- **Si se despide (o se quita) un agente que está atendiendo:** **termina** la atención en curso y
  **luego** sale de la plantilla / queda libre; el puesto se queda sin dotar. *Igual que cerrar un puesto
  en Flujo (compromiso de servicio).*
- **Si todos los agentes de un servicio faltan el mismo día:** el servicio queda **sin dotar** → puestos
  vacantes → colas crecen/abandonan (como el edge "todos los puestos cerrados" de Flujo). Con **Oficial**,
  cubre hasta `bajas_cubiertas` (F6); el resto queda descubierto. *Señal de plantilla frágil (poca Salud o
  sin redundancia), no un bug.*
- **Si hay una ausencia pero el Oficial no tiene a quién reasignar** (ningún agente libre): el Oficial
  **escala** la incidencia al jugador (F7) — deja el puesto vacante o el jugador reasigna / paga peonada.
  *El Oficial no inventa personal; cuando no hay margen, decides tú.*
- **Si se intenta poner un 2.º Oficial en un servicio** (ya hay uno): se **rechaza** (**máx. 1 por
  servicio**, PA2). *La jerarquía es 1 Oficial por servicio.*
- **Si un atributo llega fuera de rango** (dato corrupto, `<1` o `>5`): se **clampa a [1,5]**; los
  modificadores derivados se clampan a sus rangos seguros (F2 `[0.5,1.3]`, F4 `[0,1]`). *Mismo patrón de
  clamp que Datos/Tiempo.*
- **Si contratas más agentes que puestos disponibles:** **permitido** — quedan **en plantilla sin
  asignar** (útiles para cubrir bajas). El **presupuesto** (salarios diarios) es el único limitador; no hay
  tope duro de plantilla. *Tener banquillo es una decisión válida (redundancia vs coste).*
- **Si el mercado de candidatos está vacío** (recién refrescado / agotado): el menú muestra "sin
  candidatos ahora, vuelve en X" — **no es error**. *El mercado se repone por ciclos (F5).*
- **Si el juego está en Pausa cuando tocaría una ausencia/cobertura:** no se resuelve nada (PA11); las
  ausencias se evalúan al **inicio del día** (`nuevo_dia`), deterministas por semilla. *Pausa nunca pierde
  ni adelanta eventos de personal.*
- **Si se guarda la partida:** se serializan la **plantilla** (agentes, atributos, rango, asignaciones,
  estados, ausencia del día), el **mercado** (candidatos) y el **estado del RNG/semilla**; al cargar se
  restauran y arranca en **Pausa**, sin re-disparar eventos. *Cargar sitúa, no reproduce (coherente con el
  resto).*

## Dependencies

**Este sistema depende de:**

| Sistema | Tipo | Interfaz (qué lee/consume) |
|---------|------|-----------------------------|
| **Datos y Configuración** | Hard | *lee* `TipoAgente` (salario **base**, `puestos_operables`, `tipo_horario`, `escala_rango`) ✅ GDD |
| **Economía #3** | Hard | gate **"¿puedo contratar?"** (E4) + cobra `salario_dia` (F3, base×prima) al `nuevo_dia` ✅ GDD |
| **Formación y Cursos #29** *(V-Slice)* | Soft | *lee* los **valores de mejora por skill específico** que suben los atributos (default sin mejora) *(provisional; relación mutua)* |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz (qué recibe de Personal) |
|---------|------|----------------------------------|
| **Flujo de Personas y Colas #4** | Hard | *recibe* el agente asignado a cada puesto (**gate FL4**) y sus `modificador_produccion` (F2) / `bonus_satisfaccion` (F3) ✅ GDD |
| **Paciencia y Satisfacción #10** | Soft | *recibe* (vía Flujo) el `bonus_satisfaccion` (Trato) que sube la satisfacción *(provisional)* |
| **Construcción y Distribución #7** | Hard | provee los **puestos** a los que Personal asigna agentes *(provisional)* |
| **Documentación #8 / ODAC #9** | Hard | los agentes **operan** sus puestos (horario del servicio) *(provisional)* |
| **Horarios y Peonadas #13** *(V-Slice)* | Soft | *(futuro)* peonadas (horas extra); turnos rotativos **descartados** *(diferido)* |
| **Bienestar / Comodidades #15** *(V-Slice)* | Soft | *(futuro)* fatiga/descanso (día libre + sala) que recupera la Motivación *(diferido)* |
| **UI / HUD #11** | Hard | *expone* plantilla, mercado de contratación, atributos, avisos del Oficial |
| **Feedback #12** | Soft | *emite* eventos (fichaje, ausencia, cobertura, despido) |
| **Guardado y Carga** | Hard | *serializa/restaura* la plantilla, el mercado y el estado del RNG |

> **Nota — relación mutua con Formación #29:** Personal **posee** los atributos del agente y su valor
> base; Formación **los mejora por skill específico** (Personal aplica los valores). En el MVP, Formación
> no existe → atributos base sin mejora. Se reconcilia al escribir #29.

> **Consistencia bidireccional:** **Flujo ✅**, **Datos ✅** y **Economía ✅** ya registran la relación con
> Personal; el resto la añadirá al escribirse *(provisional)*. Registrado en `systems-index.md`.

## Tuning Knobs

### Knobs propios de Personal

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `k_calidad` (prima de salario por atributos, F1) | 0.5 | 0 – 1.5 | ↑ los buenos cuestan mucho más (calidad cara) / ↓ la calidad casi no encarece | Personal |
| `prima_rango_oficial` (F1) | 1.3 | 1.0 – 2.0 | ↑ el Oficial cuesta más (delegar es caro) / ↓ Oficial barato | Personal |
| `k_rapidez` (Rapidez→duración, F2) | 0.1 | 0 – 0.15 | ↑ la Rapidez importa más (crack vs torpe se nota mucho) / ↓ aplana | Personal |
| `k_trato` (Trato→satisfacción, F3) | 5 | 0 – 15 | ↑ el Trato pesa más en la satisfacción / ↓ menos | Personal |
| `base_ausencia` · `k_salud` (F4) | 0.03 · 0.02 | ≥ 0 | ↑ más bajas (más presión de cobertura) / ↓ plantilla más fiable | Personal |
| `n_candidatos` · `refresco_mercado` (F5) | 3–5 · cada X días | ≥ 1 | ↑ más donde elegir (fichar fácil) / ↓ mercado escaso (fichar difícil) | Personal |
| `sesgo_candidatos` (rareza de cracks, F5) | centrado | — | ↑ cracks más raros (encontrar al bueno cuesta) / ↓ candidatos buenos comunes | Personal |
| `mando_cobertura` (F6: `floor(Mando/2)`) | ver F6 | — | ↑ el Oficial cubre más bajas (más valioso) / ↓ menos | Personal |
| `coste_despido` | **0** (MVP) | ≥ 0 | ↑ despedir penaliza (menos rotación) / ↓ despido libre | Personal |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto sobre Personal |
|------|-----------|-----------------------|
| `salario_dia` base (60/70) | Datos → Economía/Personal | Base de la nómina (F1) |
| `puestos_operables` · `plazas_agente` | Datos | Qué puestos opera un tipo y cuántos agentes por puesto (1) |
| gate de caja (E4) | Economía | Si puedes pagar la contratación |

**Interacciones entre knobs (clave):**
- **`k_calidad` × `prima_rango`** definen **cuánto duele la calidad**: si son altos, un buen equipo
  dispara la nómina → la decisión "crack vs medianos" se agudiza.
- **`base_ausencia`/`k_salud` × tamaño de plantilla** definen la **presión de cobertura**: muchas bajas +
  poca redundancia → el Oficial (y el banquillo) se vuelven necesarios.
- **`n_candidatos`/`sesgo`** definen **lo difícil que es fichar bien**: mercado escaso + cracks raros =
  cada buen fichaje es un logro.
- **`mando_cobertura`** define **cuánto vale el Oficial**: si cubre poco, no compensa su prima; si cubre
  mucho, delegar es rentable al crecer.

**Restricciones:** `k_calidad, prima_rango, base_ausencia, k_salud, coste_despido ≥ 0`; los modificadores
derivados se clampan (F2 `[0.5,1.3]`, F4 `[0,1]`).

## Visual/Audio Requirements

*Personal declara feedback; lo animan Feedback/Audio + art bible. Estilo: serio, siluetas legibles,
respaldo daltónico (icono + texto, no solo color).*

| Elemento/Evento | Visual | Audio | Prioridad |
|---|---|---|---|
| **Agente (identidad)** | **Retrato/silueta** con rol (uniforme: gorra/hombros — art bible §3) y **divisa de rango** (Policía 2 galones / Oficial 3 — imagen real filtrada, regla de assets del índice) | — | Siempre |
| **Atributos** | ⭐ (1–5) con icono ⚡🤝❤️🔥 (y 🎖️Mando en Oficiales); respaldo icono+texto (daltónicos) | — | En ficha/mercado |
| **Estado del agente** | color/icono: **verde** asignado · **azul** libre · **gris** ausente · **ámbar** cubriendo | — | Siempre visible |
| **Fichaje** (contratar) | destello positivo + el agente aparece en la plantilla | Tono positivo breve | Media |
| **Ausencia** | silla vacía / icono de baja en el puesto | Aviso sobrio | **Alta** (hay que reaccionar) |
| **Cobertura del Oficial** | animación del Oficial reasignando (flecha de un agente al puesto vacante) | Clic de "resuelto" | Media |
| **Aviso del Oficial (canalización)** | panel resumen ("faltan 2; cubierta 1") en vez de N avisos | Aviso único agrupado | Media |
| **Despido** | el agente sale de la plantilla (atenuación) | Tono neutro | Baja |

> 📌 **Asset Spec** — Tras aprobar el art bible, `/asset-spec system:staff-agents` para retratos de agente,
> divisas de rango, iconos de atributo y VFX de fichaje/ausencia/cobertura.

## UI Requirements

*Personal es muy UI. La pantalla la posee **UI/HUD #11**; dirigida por ratón, sin hover-only.*

- **Menú de contratación (mercado):** fichas de candidato con **retrato, tipo, rango, atributos (⭐) y
  salario/día**; botón **Contratar** (gate Economía, deshabilitado sin caja); indicador de refresco del
  mercado.
- **Panel de plantilla:** lista de agentes contratados con **estado** (asignado/libre/ausente/cubriendo),
  puesto, atributos y salario; acciones **Asignar / Quitar / Despedir**.
- **Asignación:** clic (o arrastrar) un agente a un puesto **que pueda operar** (los incompatibles se
  marcan no válidos).
- **Bandeja de incidencias:** con Oficial, **avisos agrupados** del servicio; sin Oficial, **avisos
  individuales** (ausencias, coberturas pendientes).
- **Ficha de agente:** detalle (nombre, rango, atributos; historial/formación → futuro).
- La UI **nunca hardcodea** textos/números: lee de Datos y de la instancia.

> **📌 UX Flag — Personal / Agentes:** este sistema aporta UI compleja (mercado de contratación, panel de
> plantilla, asignación, bandeja de incidencias). En Pre-Producción, ejecutar `/ux-design` para cada
> pantalla **antes** de escribir epics; las stories de UI citan `design/ux/[pantalla].md`.

## UI Requirements

[To be designed]

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.*

**Plantilla, rango, atributos (PA1–PA3, F2)**
- **AC-PE01** `[Unit]` — GIVEN un agente contratado THEN tiene `nombre`, `tipo`, `rango`, 4 atributos (1–5); si es Oficial, **Mando**.
- **AC-PE02** `[Integration]` — GIVEN un servicio con Oficial WHEN se intenta poner un 2.º THEN se **rechaza** (máx 1/servicio).
- **AC-PE03** `[Unit]` — GIVEN Rapidez 5/Mot 4 THEN `modificador_produccion ≈ 0.76`; Rapidez 1/Mot 2 → `≈ 1.26` (F2).

**Contratación y salarios (PA4, PA6, F1, F5)**
- **AC-PE04** `[Unit]` — GIVEN `ag_doc` (base 60) media atributos 5 THEN `salario_dia = 90`; media 2 → 45; Oficial media 4 → ~98 (F1).
- **AC-PE05** `[Integration]` — GIVEN caja insuficiente WHEN se intenta contratar THEN se **rechaza** (gate E4).
- **AC-PE06** `[Unit]` — GIVEN la misma `semilla` WHEN se genera el mercado THEN los candidatos son **idénticos** (F5 determinista).
- **AC-PE07** `[Integration]` — GIVEN 2 agentes contratados WHEN `nuevo_dia` THEN se descuenta la suma de sus `salario_dia` (base×prima).

**Asignación (PA5, F2)**
- **AC-PE08** `[Integration]` — GIVEN un `ag_doc` WHEN se asigna a `puesto_doc_general` THEN habilita atención (gate FL4); a `puesto_odac` → **rechazado**.
- **AC-PE09** `[Integration]` — GIVEN un agente ya asignado WHEN se reasigna a otro puesto THEN se **mueve** (libera el anterior) sin cortar una atención en curso.
- **AC-PE10** `[Integration]` — GIVEN un puesto operado por un agente rápido vs uno lento THEN la **duración efectiva** es menor con el rápido (Flujo usa F2).

**Atributos → efectos (F3, F4)**
- **AC-PE11** `[Unit]` — GIVEN Trato 5 THEN `bonus_satisfaccion = +10`; Trato 1 → −10 (F3).
- **AC-PE12** `[Unit]` — GIVEN Salud 5 THEN `prob_ausencia ≈ 1%`; Salud 1 → ~7% (F4).

**Ausencias y Oficial (PA7–PA9, F6, F7)**
- **AC-PE13** `[Unit]` — GIVEN RNG sembrado WHEN se evalúa la ausencia THEN es **determinista** (misma semilla → mismo resultado).
- **AC-PE14** `[Integration]` — GIVEN Oficial (Mando 4) y 2 bajas con agentes libres THEN **cubre 2**; con Mando 1 → cubre 1 (F6).
- **AC-PE15** `[Integration]` — GIVEN **sin** Oficial y una baja THEN el puesto queda **vacante** (sin cobertura automática).
- **AC-PE16** `[Integration]` — GIVEN Oficial y N incidencias del servicio THEN se **agrupan en 1 aviso**; sin Oficial → **N avisos** (PA9).
- **AC-PE17** `[Integration]` — GIVEN Oficial sin agentes libres que reasignar THEN **escala** al jugador (no cubre, F7).

**Motivación, pausa, robustez (PA10, PA11, Edge)**
- **AC-PE18** `[Unit]` — GIVEN el MVP THEN la Motivación es **atributo base** (modula F2 levemente), **sin** fatiga dinámica.
- **AC-PE19** `[Integration]` — GIVEN el juego en **Pausa** THEN **no** se evalúan ausencias (PA11).
- **AC-PE20** `[Unit]` — GIVEN un atributo fuera de [1,5] THEN se **clampa**; los modificadores derivados se clampan (F2 [0.5,1.3], F4 [0,1]).
- **AC-PE21** `[Unit]` — GIVEN un save con plantilla + mercado + RNG WHEN se carga THEN se **restaura** todo, arranca en **Pausa**, determinista.

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | **Valores semilla de personal** (`k_calidad 0.5`, `prima_rango 1.3`, `base_ausencia 3%`, Mando cobertura, pesos de atributos) | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Curva de Formación #29** (niveles 1–5, coste €+días creciente, retorno decreciente por skill) — capturada en el índice | Formación #29 + Economía | GDD #29 | Abierta |
| 3 | **Fatiga/descanso dinámico** (día libre reset, sala parcial, cadencia ~3–4:1) — diferido, capturado en el índice | Bienestar #13/#15 | GDD #13/#15 | Abierta |
| 4 | **¿Coste de contratación puntual** además del salario diario? MVP sin él; validar si aporta decisión | Economía + playtest | 1er playtest | Abierta |
| 5 | **Nombres y retratos de agentes**: ¿pool español realista generado o set fijo? | Arte / Narrativa | Pre-producción | Abierta |
| 6 | **El Oficial atiende Y gestiona**: cómo se reparte (atiende un puesto + gestiona en background); validar que **no es OP** | Personal + playtest | 1er playtest | Abierta |
| 7 | **Formar sube el salario** (F1): validar que el beneficio compensa la subida de nómina (que no **desincentive** formar) | Personal + Economía + playtest | 1er playtest | Abierta |
| 8 | **Balance nómina vs ingresos**: cuántos agentes sostiene el arranque (liga con el pacing de Economía Open Q#3) | Economía + playtest | 1er playtest | Abierta |
