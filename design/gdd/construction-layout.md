# Construcción y Distribución

> **Status**: Reviewed (/design-review 2026-07-22 APPROVED)
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / systems-designer / qa-lead — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 4 — "Tu comisaría, tus decisiones" + Pilar 2 — "La comisaría está viva"

## Overview

El sistema de **Construcción y Distribución** es con el que **das forma física a tu comisaría**: sobre una
**rejilla 2D** de una planta, **dibujas las salas** del tamaño que quieras —las oficinas de Documentación y
ODAC y sus salas de espera—, **colocas los puestos** de atención y los **objetos** (asientos, mostradores),
y lo **pagas** todo con tu presupuesto. Es construcción **libre estilo Theme Hospital**: haces las salas
grandes o pequeñas a tu gusto —puedes **sobredimensionar** o **hacinar**, con sus consecuencias—, y **no
hay cupos rígidos**: el único límite es el **espacio del edificio** y el **dinero** (cada puesto que abres
necesita un agente que pagar). Esta capa es la que **habilita** todo lo demás: un puesto **construido** es
donde *Personal* coloca un agente y *Flujo* atiende; una sala de espera con **asientos** es donde la gente
aguarda (su **aforo** lo dan los asientos, no un número fijo); y una sala amueblada con **comodidades**
(papelera, vending, equipo informático…) es una sala que trata mejor a quien espera o a quien atiende. Lee
de *Datos* los tipos de puesto/sala, sus costes y la superficie de los puestos; opera con *Economía* el
gate "¿puedo pagarlo?" y el descuento al colocar.

A nivel de diseño, **la comisaría es TU diseño** (Pilar 4): dos jugadores con el mismo presupuesto montan
oficinas distintas, y esa **expresión** es parte del placer. El corazón es la decisión espacial y
económica: *"¿hago la sala de espera amplia y cómoda o aprieto para meter otra ventanilla? ¿invierto ahora
en un puesto más o ahorro para el de ODAC?"* Y como el edificio **cobra forma ante tus ojos** —paredes,
mostradores, gente que lo llena—, la comisaría se siente **viva y propia** (Pilar 2). Sin esta capa no hay
**dónde** atender —*Flujo* no mueve una cola sin puestos, *Personal* no tiene dónde poner a nadie— ni una
**obra** en la que gastar el presupuesto: la construcción es lo que convierte un solar vacío en **tu
comisaría**.

> **Regla de propiedad:** Construcción **posee** la *rejilla*, la *colocación* (posición y **tamaño libre**
> de salas, posición de puestos y objetos), la *superficie física* y el **aforo derivado de los asientos**.
> **Lee** de *Datos* (`TipoPuesto`/`TipoSala`, `coste_construccion_eur`, superficie de puestos) y **opera
> con** *Economía* (gate E4 + descuento del coste). **Provee** a *Flujo*/*Personal* la **existencia y
> posición** de cada puesto y el **aforo** de cada sala de espera; y a *Paciencia #10*/*Flujo #4* el
> **confort** y el **equipamiento** agregados de las **comodidades** instaladas (`confort_de_sala`,
> `equipamiento_de_sala`, `confort_de_servicio`, `equipamiento_de_puesto`, `usables_de_servicio` —
> **Comodidades #15, implementado**: ver CO13–CO17). Construcción solo **coloca y suma**; qué hace cada
> sistema con ese número es SUYO (Paciencia con `mult_comodidad`, Flujo con `mult_equipamiento`). **No
> posee**: *qué atiende* un puesto (→ Datos), *quién lo opera* (→ Personal #6), el *ciclo de atención* (→
> Flujo #4), ni la *calidad/deterioro de los propios asientos* más allá de 1 plaza —un tema **distinto** de
> las comodidades, que sigue **diferido**, sin dueño asignado. *(Reconciliación con Datos: `tope_construible`
> → **límite físico del edificio**; `aforo_espera` 40/10 → **referencia**, el aforo real lo dan los
> asientos. R5 se mantiene por el espacio.)*

## Player Fantasy

**Fantasía:** ser el **arquitecto-gestor de tu comisaría** — quien coge un solar vacío y un presupuesto y lo
convierte, sala a sala, en un edificio que funciona **a su manera**. El orgullo de *"esta comisaría la he
diseñado yo"* (Pilar 4).

Se vive en dos capas:

- **Control directo (construir y distribuir):** el placer **táctil** de dibujar una sala arrastrando,
  colocar las ventanillas, sembrar los asientos, y **reorganizar** cuando algo no cuadra. Es la fantasía
  del diseñador que **optimiza su espacio**: apretar para meter otra ventanilla, o dar aire a la sala de
  espera; cada celda es una decisión con coste.
- **Infraestructura que se vive (tu diseño se puebla):** al darle a jugar, tu plano **cobra vida** — entra
  la gente y se sienta en **tus** asientos, hace cola ante **tus** ventanillas, tus agentes ocupan **tus**
  puestos. Ves tu edificio **funcionar**, y eso es profundamente satisfactorio.

**El momento a anclar:** el **primer montaje que respira**. Tienes el solar vacío; dibujas la oficina de
Documentación, plantas dos ventanillas, trazas la sala de espera y la llenas de bancos… y al reanudar,
**ves entrar a la primera oleada y sentarse en lo que acabas de construir**. Su gemelo: la cola desborda,
así que **reformas** —amplías la espera, metes otra ventanilla— y ves el flujo **desatascarse**. *"Lo he
hecho yo."*

**Referencia de sensación:** el trazado de salas de *Theme Hospital / Two Point Hospital* y la construcción
modular cenital de *Prison Architect* — la sensación de **arquitecto-gestor**. **Anti-fantasía:** NO es
**construcción rígida** (por eso salas de tamaño libre, sin cupos); NO es un **puzzle de encaje frustrante**
(siempre puedes reorganizar barato); NO es **obra tediosa** (construir es fluido, sin micromanejo de
obreros en el MVP). El jugador nunca debe sentir *"no puedo montar mi comisaría como quiero"*.

*(Nota de proceso: `creative-director` no consultado —modo LEAN + subagentes caídos—; lente creativa
aplicada en el hilo principal.)*

## Detailed Design

### Core Rules

**CO1 · La rejilla y el edificio.** La comisaría es una **rejilla 2D** de celdas dentro de un **edificio de
tamaño fijo** (Pozuelo: una planta de N×M celdas). Toda construcción ocurre dentro del edificio. La
**entrada/seguridad** es presencia fija (ambientación, Datos F3).

**CO2 · Elementos construibles (tres clases).**
- **Salas (área de tamaño libre):** oficinas (Documentación, ODAC — áreas lógicas que agrupan puestos) y
  salas de espera (Doc, ODAC).
- **Puestos (1 celda):** ventanillas de atención (`doc_general`, `tie`, `odac`), dentro de su oficina.
- **Objetos (1 celda):** asientos (→ aforo; MVP asiento básico = 1 plaza), mostradores, decoración, y
  **comodidades** (papelera, revistero, hilo musical, fuente de agua, vending, televisión, equipo
  informático, impresora de DNI moderna — **Comodidades #15, implementado**; reglas de familia y
  colocación en CO13).

**CO3 · Dibujar una sala (tamaño libre).** Se elige un tipo de sala y se **arrastra** un rectángulo de
celdas. Reglas: **dentro del edificio**, **no solapa** con otra sala, **tamaño ≥ mínimo**. Coste al
confirmar (Formulas). **Sobredimensionar o hacinar es libre** (con consecuencias — Comodidades/Paciencia).

**CO4 · Colocar puestos y objetos dentro.** Un puesto se coloca **dentro de la oficina de su servicio**
(`doc_general`/`tie` en `sala_documentacion`; `odac` en `sala_odac`). Un asiento, dentro de una sala de
espera. Ocupan celdas; **no solapan**.

> **📝 NOTA DE DISEÑO (usuario, 2026-07-30, jugando en isométrico):** *"la mesa de atención debe ser
> como 3 casillas: 1 donde está el policía, otra la mesa y otra la silla con el ciudadano; ahora veo
> encima de la mesa al funcionario"*. Ya corregido en el **visual** (hilo principal, mismo día): el
> muñeco del funcionario se dibuja **una celda detrás** del mostrador (el ciudadano ya se dibujaba una
> celda delante). Con eso la ventanilla **se LEE** como tres casillas en fila —
> **funcionario / mesa / ciudadano**— aunque el **modelo** de esta regla (CO4) no cambia: el puesto
> sigue ocupando **1 sola celda** (`superficie = 1`, CO2). Si el modelo debe **reservar de verdad**
> esas tres celdas o basta con la lectura visual actual queda **abierto** — ver Open Questions #8.

**CO5 · Aforo por asientos.** El **aforo** de una sala de espera = **nº de asientos colocados** (no un
valor fijo). El **tamaño** de la sala limita cuántos caben. El `aforo_espera` de Datos (40/10) es
**referencia** de aforo típico. *(Calidad/deterioro de asientos → Comodidades #15.)*

**CO6 · Coste y gate (Economía).** Cada elemento cuesta su coste al confirmar (Formulas: sala = base + por
celda; puestos/objetos = su `coste_construccion_eur` de Datos). Solo si `saldo ≥ coste` (**gate Economía
E4**). No te endeudas construyendo.

**CO7 · Puestos ilimitados; la demanda manda (no hay cupo).** **No hay tope** de puestos por servicio:
puedes poner los que quieras (como en Theme Hospital, 100 ventanillas si te apetece). Pero el **límite útil
lo marca la DEMANDA**: poner más puestos de los que la demanda llena = **agentes ociosos** (pagas salario
sin atender → desperdicio), y poner menos = colas/abandono. El **presupuesto** (salarios) y el **espacio
finito** del edificio son límites blandos; el verdadero es la **utilidad** (F5). *Encarna el aprendizaje
del prototipo: **capacidad ≠ demanda**. El `tope_construible` de Datos deja de ser cupo → referencia del
dimensionado del edificio para R5.*

**CO8 · Mover y demoler (reorganización libre).** El jugador puede **mover** un elemento (reubicar,
barato/gratis) y **demoler** (recupera un **%** del coste). Reorganizar es parte del juego (Pilar 4).
Demoler un puesto/sala **en uso**: respeta el **compromiso de servicio** (termina la atención en curso,
como Flujo).

**CO9 · Construcción instantánea (MVP).** Al confirmar y pagar, el elemento **aparece construido**
(instantáneo, con posible obra cosmética corta). **Sin gestión de obreros/materiales** en el MVP (→
futuro).

**CO10 · Existencia vs operación.** Construcción posee la **existencia y posición** de cada puesto; su
estado **abierto/cerrado** lo lleva Flujo; su **agente**, Personal. Un puesto sin oficina válida no es
operable.

**CO11 · La entrada es fija.** La entrada (por donde llega la gente) y el puesto de seguridad son **fijos**
(ambientación, no construibles/gestionados en MVP — Datos F3).

**CO12 · Pausa.** Se puede construir/reorganizar **en Pausa** (la construcción no depende del reloj;
gestión permitida en pausa, como Tiempo).

**CO13 · Comodidades: dos familias, cada una en su tipo de sala (Comodidades #15, implementado).** Una
comodidad es un elemento de **1 celda**, del mismo catálogo, dividido en dos familias que **solo** se
colocan en su tipo de sala compatible (F6, igual mecanismo que CO4 con los puestos):
- **ciudadano** → **solo** en salas de tipo "espera". Aporta **confort** (efecto en la paciencia, F1a de
  *Paciencia y Satisfacción #10*): papelera, revistero, hilo musical, fuente de agua, vending, televisión.
- **funcionario** → **solo** en salas que **no** son de espera (donde están los puestos). Aporta
  **rendimiento**, que acelera la atención (F1 de *Flujo de Personas y Colas #4*): equipo informático,
  impresora de DNI moderna.

Colocar una comodidad en la familia equivocada de sala **se rechaza**: una televisión no pinta nada en la
oficina, y un equipo informático no sirve de nada en la sala de espera.

**CO14 · Coste, gate y demolición (igual que cualquier elemento).** Una comodidad se compra y coloca como
un asiento o un puesto: cuesta su `coste_construccion_eur` de catálogo, pasa por el **mismo gate de
Economía (E4**, CO6/F2), y se demuele/reembolsa con el **mismo %** (CO8/F4). No hay reglas de coste
especiales por ser comodidad.

**CO15 · Mantenimiento diario (solo lo que consume).** Los aparatos que consumen (hilo musical, fuente de
agua, vending, televisión, equipo informático, impresora de DNI) tienen un **coste de mantenimiento
diario** en €; la papelera y el revistero no consumen y se pagan **una sola vez**. Construcción **suma**
el mantenimiento de TODO lo instalado y se lo **registra a Economía** en el cierre del día: el bus dispara
`nuevo_dia` en orden determinista (ADR-0001) y Construcción se registra en la **prioridad 16**, entre la
peonada de **Documentación (15)** y el cobro de **Economía (20)** — el gasto tiene que estar anotado antes
de que Economía cierre las cuentas de la jornada.

**CO16 · Las comodidades NO son puestos de trabajo.** Una comodidad **no** se registra en *Personal* ni
genera una **vacante** que cubrir — a diferencia de un puesto, nadie la "opera". *(Nace de un bug real
cazado por los tests el 2026-07-28: al construirlas se registraban como puestos fantasma, y el panel de
plantilla pedía un agente para "atender" una máquina de vending. Solo entra en Personal lo que el catálogo
marca como `TipoPuesto`; asientos y comodidades quedan fuera.)*

**CO17 · Interfaz expuesta a otros sistemas.** Construcción **suma** lo instalado y lo expone; el efecto
de esa suma (cuánta paciencia compra, cuánto acelera la atención) lo posee cada sistema consumidor con SU
propia fórmula:
- `confort_de_sala(sala)` / `equipamiento_de_sala(sala)` — suma del `aporte` de las comodidades de esa
  familia instaladas en esa sala.
- `confort_de_servicio(servicio)` — la **media** (no la suma) del confort de todas las salas de espera de
  ese servicio, incluidas las que no tienen nada instalado (cuentan 0). *Por qué media y no suma:* evita
  que amueblar de lujo **una sola** sala pequeña maquille como si toda la oficina fuera cómoda; para subir
  la media hace falta invertir en **todas** las salas de espera del servicio.
- `equipamiento_de_puesto(puesto)` — el equipamiento de la sala donde vive ese puesto.
- `usables_de_servicio(servicio)` — los objetos `usable = true` (vending, fuente, revistero) instalados en
  las salas de espera de ese servicio; a estos la gente se levanta a ir (Paciencia #10, PS14/15).

Lo consumen: *Paciencia y Satisfacción #10* (`confort_de_servicio` → `mult_comodidad`, F1a) y *Flujo de
Personas y Colas #4* (`equipamiento_de_puesto` → `mult_equipamiento`, F1).

### States and Transitions

**Estados de un elemento construible** (Construcción lleva existencia/posición; abierto/cerrado y agente
son de Flujo/Personal):

| Estado | Descripción | Sale a |
|--------|-------------|--------|
| **Planificando (fantasma)** | El jugador dibuja/coloca en modo preview (válido/inválido resaltado) | Construido (confirmar + pagar) · Cancelado |
| **Construido** | Colocado y pagado; ocupa celdas; operable (abrir/dotar aparte) | Movido (reubicar) · Demolido (recupera %) |
| **Demolido** | Retirado; **libera** las celdas | *(fuera)* |

- **Validación en Planificando:** resalta **verde** (colocación válida) o **rojo** (solapa / fuera del
  edificio / sin oficina / sin caja). Solo confirma si es válido.
- **Demoler/mover un puesto Atendiendo:** termina la atención en curso primero (compromiso de servicio,
  Flujo).

### Interactions with Other Systems

| Sistema | Qué fluye (Construcción ↔ él) | Dueño de la interfaz |
|---|---|---|
| **Datos y Configuración** | *lee* `TipoPuesto`/`TipoSala` (coste, superficie de puestos, `puestos_admitidos`), `Escenario` (edificio/límite físico) | Datos posee los valores ✅ GDD |
| **Economía #3** | gate **"¿puedo construir?"** (E4) + descuenta el coste al colocar; **demoler devuelve un %** | Economía posee el dinero ✅ GDD |
| **Flujo #4** | *provee* la **existencia y posición** de puestos y el **aforo** (por asientos) de las salas, y el **equipamiento** de cada puesto (`equipamiento_de_puesto`, CO17) | Construcción provee; Flujo opera ✅ GDD |
| **Personal #6** | *provee* los **puestos** donde Personal asigna agentes (comodidades **excluidas**, CO16) | Construcción provee ✅ GDD |
| **Documentación #8 / ODAC #9** | sus oficinas y puestos | ellos poseen su operativa *(provisional)* |
| **Comodidades #15** ✅ implementado | Construcción **coloca** las comodidades (dos familias, CO13) y expone el agregado (CO17); el mantenimiento diario se registra a Economía (CO15) | Construcción coloca y suma; Paciencia #10/Flujo #4 poseen el efecto de esa suma |
| **Paciencia #10** | el **aforo** (hacinamiento) y el **confort** de servicio (`confort_de_servicio`, CO17) afectan la espera | Paciencia posee la curva (F1/F1a, implementado) |
| **UI / HUD #11** | menú de construcción, herramientas de dibujo/colocación | UI presenta |
| **Feedback #12** | *emite* eventos (construir, demoler, colocar) | Feedback reacciona |
| **Guardado y Carga** | *serializa/restaura* el **layout** (rejilla, salas, puestos, objetos) | Guardado serializa |

## Formulas

> Números **semilla provisional** a validar en playtest. El coste por área hace que **sobredimensionar
> tenga precio** (desincentivo natural, en vez de un tope rígido). Prefijo `F#`.

### F1 · Coste de una sala (por área)

`coste_sala = coste_base_sala + coste_por_celda × area_celdas`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `coste_base_sala` | float | 200 (Datos `coste_construccion_sala_espera`) | Coste de "abrir" la sala |
| `coste_por_celda` | float | 20 (tuning) | Coste por celda de área (hace pagar el tamaño) |
| `area_celdas` | int | ≥ `area_min` | Nº de celdas del rectángulo dibujado |

**Salida y ejemplos:** sala de espera 3×3 (9 celdas) → `200 + 20×9 = **380€**`; 5×4 (20 celdas) → `200 +
20×20 = **600€**`. *(Sobredimensionar cuesta; hacinar ahorra suelo pero perjudica la paciencia —
Comodidades/Paciencia.)* Las **oficinas** (áreas lógicas) pueden tener `coste_base=0` (su coste real son
los puestos que contienen).

### F2 · Coste de un puesto u objeto

`coste_elemento = coste_construccion_eur (Datos)`

**Valores (Datos F3/F4 + Comodidades):** `doc_general` 500 · `tie` 500 · `odac` 600 · **asiento básico ~25**
*(Comodidades #15; MVP semilla)*. Se descuenta al confirmar (gate E4). **Ejemplo montaje inicial:** oficina
Doc (base 0) + 2×`doc_general` (1000) + sala espera 3×3 (380) + 8 asientos (200) ≈ **1580€** de una oficina
básica.

### F3 · Aforo de una sala de espera (sentados + de pie)

`aforo_sala = sentados + de_pie`
`sentados = min( plazas_asientos_colocadas , plazas_max_por_area )`
`de_pie   = floor( area_celdas × densidad_de_pie )`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `plazas_asientos_colocadas` | int | ≥ 0 | Suma de plazas de los asientos puestos (MVP: asiento básico = 1) |
| `plazas_max_por_area` | int | ≥ 0 | `floor(area_celdas × densidad_asientos)` — cuántos asientos caben |
| `densidad_asientos` | float | 0.7 (tuning) | Asientos por celda (deja hueco para pasillos) |
| `densidad_de_pie` | float | 0.5 (tuning) | Plazas DE PIE por celda (1 por cada 2 celdas) |

**Salida:** sala 5×4 (20 celdas), densidad 0.7 → caben `floor(20×0.7)=14` asientos; con 10 asientos
colocados → 10 sentados **+ `floor(20×0.5)=10` de pie = aforo 24**; si intentas 20 asientos → tope 14
sentados + 10 de pie. Sala **sin ningún asiento** → aforo = solo de pie (9 celdas → 4). *(El
`aforo_espera` 40/10 de Datos es la referencia del aforo típico a tope de construcción histórico.)*

> **🔧 ENMIENDA DE DISEÑO (usuario, 2026-07-24 — aplicada en código y aquí en C2-7):** una sala de espera
> **sin asientos NO deja a la gente en la calle** — se entra igual, **de pie**. Antes `aforo_sala` era solo
> los asientos, así que una sala recién construida tenía aforo 0 y nadie entraba, lo que no se parecía a
> ninguna sala de espera real. Los asientos pasan a ser **confort** (su valor se cobrará cuando llegue
> Paciencia #10), no el permiso para entrar. El tope físico de ASIENTOS (CO7) no cambia. El valor semilla
> `densidad_de_pie` **0.5 está pendiente de ratificar en playtest** (ver Open Questions).

### F4 · Reembolso al demoler

`reembolso = coste_pagado × pct_reembolso`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `coste_pagado` | float | ≥ 0 | Lo que costó el elemento |
| `pct_reembolso` | float | 0.5 (tuning) | Fracción devuelta al demoler |

**Salida:** demoler un `doc_general` (500) → **+250€**. **Mover** un elemento = **gratis** (o coste
simbólico) — reorganizar no penaliza (Pilar 4).

### F5 · Puestos útiles según la demanda (no hay tope)

`puestos_utiles_servicio ≈ ceil( tasa_llegadas_pico / throughput_hora_puesto )`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `tasa_llegadas_pico` | float | ≥ 0 | Llegadas/hora en hora punta (**Demanda F2**) |
| `throughput_hora_puesto` | float | ≥ 0 | `60 / duracion_efectiva_media` (**Flujo F2**) |
| `puestos_utiles` | int | ≥ 0 | Puestos que la demanda pico **justifica** |

**Salida:** más puestos que `puestos_utiles` = **agentes ociosos** (pagas salario sin atender →
desperdicio); menos = colas/abandono. **Ejemplo Doc:** pico ~17,6/h (Demanda F2), throughput 4/h → **~5
puestos útiles** en hora punta. **Pon los que quieras** (ilimitado); la demanda te enseña el punto óptimo.
*R5: el edificio se dimensiona para caber ≥ `puestos_utiles`.*

### F6 · Validez de colocación (booleano)

`colocacion_valida = dentro_edificio ∧ ¬solapa ∧ area ≥ area_min ∧ (si es puesto → dentro de oficina de su servicio)`

**Salida:** true → se puede confirmar (resalte verde); false → bloqueado (rojo). *Determinista; sin
ambigüedad.*

### F7 · Coste y mantenimiento de una comodidad (Comodidades #15, implementado)

`coste_elemento = coste_construccion_eur (catálogo Comodidad)` — mismo gate E4 que F2.
`mantenimiento_dia = Σ coste_mantenimiento_dia_eur` de TODO lo instalado que consume (CO15).

**Catálogo (SEMILLA, a validar en playtest):**

| Comodidad | Familia | Aporte | Coste construcción | Mantenimiento/día |
|---|---|---|---|---|
| Papelera | ciudadano (confort) | 1 | 60 € | — (no consume) |
| Revistero | ciudadano (confort) | 2 | 150 € | — (no consume) |
| Hilo musical | ciudadano (confort) | 3 | 250 € | 1 € |
| Fuente de agua | ciudadano (confort) | 3 | 400 € | 2 € |
| Máquina de vending | ciudadano (confort) | 5 | 1.200 € | 3 € |
| Televisión | ciudadano (confort) | 6 | 900 € | 4 € |
| Equipo informático | funcionario (rendimiento) | 4 | 1.500 € | 2 € |
| Impresora de DNI moderna | funcionario (rendimiento) | 6 | 2.200 € | 3 € |

**Salida y ejemplo:** instalar 1 papelera + 1 máquina de vending cuesta `60 + 1.200 = 1.260 €` al
construirlas; su mantenimiento diario es `0 + 3 = 3 €` (la papelera no consume, se pagó entera una vez).
Ese 3 € lo suma `mantenimiento_dia()` y Construcción se lo registra a Economía en su prioridad 16 (CO15).

### F8 · Agregados que expone Construcción (Comodidades #15, implementado)

`confort_de_sala(sala) = Σ aporte` de las comodidades familia **ciudadano** instaladas en esa sala
`equipamiento_de_sala(sala) = Σ aporte` de las comodidades familia **funcionario** instaladas en esa sala
`confort_de_servicio(servicio) = media( confort_de_sala )` de las salas de espera de ese servicio
`equipamiento_de_puesto(puesto) = equipamiento_de_sala` de la sala donde vive ese puesto

**Salida y ejemplo:** Documentación tiene 2 salas de espera; una con 1 televisión (aporte 6) y otra vacía
(aporte 0) → `confort_de_servicio = (6+0)/2 = 3` (la **media**, no `6`). *Amueblar de lujo solo una sala no
basta: hay que invertir en las dos para que suba la media que consume Paciencia (F1a).* `equipamiento_de_puesto`
de un `doc_general` en una sala con un equipo informático (aporte 4) → `4`, que Flujo consume en su F1.

**Nota de frontera:** el **coste base** de puestos/salas lo posee **Datos**; el **catálogo y coste de las
comodidades** (F7) también vive en **Datos** (`Comodidad`); la **calidad/deterioro de los propios
asientos** (más allá de 1 plaza —un tema distinto de las comodidades, que sí están implementadas) sigue
**diferida**, sin dueño asignado; el **dimensionado del edificio** para cumplir R5, **Datos/Construcción**
conjuntamente.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre CO1–CO12 y F1–F6.*

- **Si la colocación es inválida** (solapa, fuera del edificio, puesto fuera de su oficina, área < mínimo):
  **no se confirma** (resalte **rojo**, F6); el jugador reubica. *No se coloca nada roto.*
- **Si se intenta construir sin caja** (`saldo < coste`): se **rechaza** (gate E4); el saldo no baja. *No
  te endeudas construyendo.*
- **Si se demuele un puesto que está atendiendo:** **termina** la atención en curso y **luego** se demuele
  (compromiso de servicio, como Flujo); reembolsa su %. *No se corta un trámite a medias.*
- **🔑 Si se demuele una sala/oficina que contiene puestos u objetos:** demolición **en cascada con
  confirmación** — se demuelen también su contenido, reembolsando el % de cada elemento. *Evita puestos
  huérfanos; un aviso confirma antes de borrar toda la sala.*
- **Si se intenta mover un puesto fuera de su oficina compatible** (un `odac` a la oficina de Doc): se
  **rechaza**. *Un puesto solo vive en la oficina de su servicio (CO4).*
- **Si una sala de espera no tiene asientos:** su **aforo = 0** → todos esperan en la **cola exterior**
  (Flujo lo tolera; edge de Flujo `aforo=0`). *Funcional pero indeseable; el jugador debe poner asientos.*
- **Si el edificio está lleno** (no quedan celdas libres): no se puede colocar más (resalte rojo); el
  jugador **demuele/reorganiza** o lo deja. *No es error; el espacio es finito.*
- **Si el jugador pone más puestos de los útiles** (más que `puestos_utiles`, F5): **permitido**
  (ilimitado) — pero son **agentes ociosos** (pagas salario sin atender). *No es error; es su decisión, y
  la demanda se lo enseña (capacidad ≠ demanda).*
- **Si se intenta colocar un asiento por encima del aforo físico** (más plazas que `plazas_max_por_area`):
  se **rechaza** el asiento sobrante (no cabe, F3). *El tamaño de la sala limita las plazas.*
- **Si se mueve un elemento (reubicar):** es **gratis/barato** y no interrumpe (salvo el compromiso de
  servicio si es un puesto atendiendo). *Reorganizar no penaliza (Pilar 4).*
- **Si un coste llega fuera de rango** (dato corrupto, negativo): se **clampa a ≥ 0**. *Mismo patrón de
  clamp que Datos.*
- **Si se guarda la partida:** se serializa el **layout completo** (rejilla, áreas de salas, puestos,
  objetos, posiciones); al cargar se **restaura** tal cual y arranca en Pausa. *El plano es estado de
  partida; se persiste íntegro.*
- **Si se intenta colocar una comodidad de familia "ciudadano" fuera de una sala de espera** (p. ej. una
  televisión en la oficina): **se rechaza** (mismo mecanismo que CO4 con los puestos). *Cada familia vive
  donde tiene sentido; una tele no pinta nada donde trabajan los funcionarios.*
- **Si se intenta colocar una comodidad de familia "funcionario" en una sala de espera** (p. ej. un equipo
  informático): **se rechaza**. *El rendimiento se instala donde se atiende, no donde se espera.*
- **Si se demuele una comodidad:** se reembolsa su % como cualquier objeto (F4/CO14); no hay "atención en
  curso" que respetar porque una comodidad nunca atiende a nadie. *Demoler una comodidad es tan simple
  como demoler un asiento.*
- **Si una comodidad no consume** (papelera, revistero): su mantenimiento diario es **0**; se pagó entera
  al construirla. *No todo lo instalado genera gasto recurrente — solo lo que se enchufa.*
- **Si el jugador espera que una comodidad libere una vacante de Personal:** **no ocurre** — las
  comodidades nunca se registran como puesto (CO16). *Fue un bug real (2026-07-28): antes de corregirlo,
  construir una comodidad la daba de alta en Personal como si fuera un puesto vacío, y el panel de
  plantilla pedía un agente para "atender" una máquina de vending.*
- **Si un servicio tiene varias salas de espera y solo una lleva comodidades instaladas:**
  `confort_de_servicio` es la **media** de todas esas salas (la vacía cuenta 0), no la suma. *Evita que
  amueblar una sola sala pequeña maquille como si toda la oficina fuera cómoda.*

## Dependencies

**Este sistema depende de:**

| Sistema | Tipo | Interfaz (qué lee/consume) |
|---------|------|-----------------------------|
| **Datos y Configuración** | Hard | *lee* `TipoPuesto`/`TipoSala` (coste, superficie de puestos, `puestos_admitidos`), `Escenario` (edificio/límite físico) ✅ GDD |
| **Economía #3** | Hard | gate **"¿puedo construir?"** (E4) + descuenta el coste al colocar + **reembolsa %** al demoler ✅ GDD |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz (qué recibe de Construcción) |
|---------|------|--------------------------------------|
| **Flujo de Personas y Colas #4** | Hard | *recibe* la **existencia y posición** de puestos y el **aforo** (por asientos) de las salas ✅ GDD |
| **Personal / Agentes #6** | Hard | *recibe* los **puestos** donde asigna agentes ✅ GDD |
| **Documentación #8 / ODAC #9** | Hard | sus **oficinas y puestos** los coloca Construcción *(provisional)* |
| **Comodidades #15** *(V-Slice)* | Hard | *(futuro)* coloca los **objetos** (asientos/mobiliario) a los que #15 da calidad/deterioro *(diferido)* |
| **Paciencia y Satisfacción #10** | Soft | *(indirecto)* el **aforo** y la comodidad de la sala afectan la espera *(provisional)* |
| **UI / HUD #11** | Hard | *expone* el menú de construcción y las herramientas de dibujo/colocación |
| **Feedback #12** | Soft | *emite* eventos (construir, demoler, colocar) |
| **Guardado y Carga** | Hard | *serializa/restaura* el **layout** (rejilla, salas, puestos, objetos) |

> **Consistencia bidireccional:** **Datos ✅**, **Economía ✅**, **Flujo ✅**, **Personal ✅**, **Documentación ✅**,
> **ODAC ✅**, **Paciencia ✅**, **UI ✅** y **Feedback ✅** ya registran/reflejan la relación con Construcción
> (todos escritos). Solo Comodidades #15 y Guardado #20 (futuros) quedan. Registrado en `systems-index.md`.

## Tuning Knobs

### Knobs propios de Construcción

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `coste_por_celda` (sala, F1) | 20 | ≥ 0 | ↑ sobredimensionar sale caro (salas ajustadas) / ↓ salas grandes casi gratis | Construcción |
| `coste_base_sala` (F1) | 200 (Datos) | ≥ 0 | ↑ abrir cualquier sala cuesta más / ↓ más barato | Construcción / Economía |
| `densidad_asientos` (F3) | 0.7 | 0 – 1 | ↑ caben más asientos por celda (salas más eficientes) / ↓ necesitas más espacio por plaza | Construcción |
| `densidad_de_pie` (F3) | 0.5 | 0 – 1 | ↑ más gente de pie por celda (salas más aguantadoras, peor confort) / ↓ la sala se llena antes y la cola sale a la calle | Construcción |
| `pct_reembolso` (demoler, F4) | 0.5 | 0 – 1 | ↑ reorganizar casi gratis (más libertad) / ↓ demoler duele (más planificación) | Construcción / Economía |
| `area_min_sala` (CO3) | ~2×2 | ≥ 1 celda | ↑ salas mínimas mayores / ↓ permite salas diminutas | Construcción |
| `coste_asiento_basico` (F2) | 25 | ≥ 0 | ↑ el aforo cuesta más / ↓ más barato *(afina Comodidades #15)* | Construcción / #15 |
| `coste_mover` (CO8) | 0 (gratis) | ≥ 0 | ↑ reubicar penaliza / ↓ libre | Construcción |
| `tamaño_edificio` (celdas, Pozuelo) | dimensionado para R5 | ≥ caber `puestos_utiles` | ↑ más sitio (menos presión espacial) / ↓ reto espacial (Theme Hospital "terreno difícil") | Datos / Construcción |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto sobre Construcción |
|------|-----------|---------------------------|
| `coste_construccion_eur` (puestos 500/500/600) | Datos → Economía | Coste de cada puesto (F2) |
| superficie de puestos (1 celda) | Datos | Cuánto ocupa un puesto en la rejilla |
| `tope_construible` (reinterpretado) | Datos | Referencia del **dimensionado del edificio** para R5 (ya no es cupo) |

**Interacciones entre knobs (clave):**
- **`coste_por_celda` × `tamaño_edificio`** definen la **presión espacial y económica**: un edificio
  pequeño con celdas caras = reto de optimización (Theme Hospital).
- **`densidad_asientos` y `densidad_de_pie` × área de sala** definen el **aforo** (F3): salas eficientes vs. amplias; los asientos son confort, el aforo de pie es lo que evita la cola en la calle.
- **`pct_reembolso` × `coste_mover`** definen **cuánto cuesta reorganizar**: bajos = libertad total (Pilar
  4); altos = planificar bien de entrada.
- **`tamaño_edificio` es el nuevo "tope"**: debe caber ≥ `puestos_utiles` (F5) para cumplir R5; encogerlo
  es la palanca de dificultad espacial por comisaría (#26).

**Restricciones:** `coste_por_celda, coste_base_sala, coste_asiento_basico, coste_mover ≥ 0`; `pct_reembolso
∈ [0,1]`; `densidad_asientos ∈ (0,1]`; `densidad_de_pie ∈ [0,1]`; `tamaño_edificio` ≥ caber `puestos_utiles` (R5).

## Visual/Audio Requirements

*Estilo art bible: vista cenital, geometría ortogonal/rejilla, gris azulado de fondo, lo accionable
destaca, respaldo daltónico (icono/texto además del color).*

| Elemento/Evento | Visual | Audio | Prioridad |
|---|---|---|---|
| **Modo construcción** | Overlay de **rejilla** de celdas; el mundo se atenúa un poco para destacar la construcción | Ambiente sutil de "modo plano" | Media |
| **Preview fantasma** | Elemento semitransparente que sigue el cursor; **verde** válido / **rojo** inválido (F6) + icono/texto (daltónicos) | — | **Alta** (claridad) |
| **Dibujar sala** | Rectángulo que se expande al **arrastrar**, con **área y coste en vivo** | Sonido sutil al fijar esquinas | Media |
| **Elementos construidos** | Puestos (mostradores), oficinas/esperas (suelo+paredes con **color por servicio** Doc/ODAC), asientos, entrada — art bible institucional | — | Siempre |
| **Construir** (confirmar) | El elemento **aparece** (pop breve / obra cosmética corta) | "Colocado" satisfactorio (thunk/sello) | Media |
| **Demoler** | El elemento **desaparece**; libera celdas | Sonido de retirada | Baja |
| **Inválido / sin caja** | Resalte **rojo** + coste en rojo | Buzz sobrio | Media |

> 📌 **Asset Spec** — Tras aprobar el art bible, `/asset-spec system:construction-layout` para tiles de
> rejilla, suelos/paredes por servicio, mostradores de puesto, asiento básico, y VFX de construir/demoler.

## ⚠️ CAMBIO DE PROYECCIÓN aprobado 2026-07-30 — A ISOMÉTRICO

> **Usuario**: *"quiero un theme hospital con la misma visualización"* · *"realista pero jugón"* ·
> *"lo veo muy pixel"* (descartando el pixel art) · *"quiero una experiencia tycoon total"*.

**Verificado antes de decidir**: Theme Hospital es **isométrico** ("gráficos 3D isométricos, mismo
punto de vista que Theme Park"), con sprites **pre-renderizados desde 3D**. Este GDD se escribió para
una rejilla **cenital cuadrada**.

### Lo que NO se toca (y por qué se puede hacer esto)

**El modelo entero.** La rejilla de celdas, los muros en las aristas, las zonas por recinto, el aforo,
los costes, los cronómetros por cuadrículas, la persistencia — nada de eso conoce la proyección. Los
**643 tests siguen valiendo**.

Esto es consecuencia directa del **ADR-0004**: *"el visual REFLEJA el modelo, jamás al revés"*. Sin esa
disciplina, cambiar de proyección a estas alturas sería rehacer el juego.

### Lo que hay que rehacer (capa visual)

| Pieza | Qué cambia |
|---|---|
| **Proyección celda↔píxel** | De cuadrado a rombo isométrico (2:1). Es la función raíz de todo lo demás |
| **Suelos de sala** | `TileMapLayer` en modo isométrico en vez de cuadrado |
| **Paredes** | Dejan de ser franjas sobre la arista: pasan a ser **caras con altura** |
| **Personajes y mostradores** | Sprites isométricos, anclados por la BASE (no por el centro) |
| **Orden de dibujo** | NUEVO: en isométrico lo que está más abajo tapa a lo que está detrás. Hoy no existe |
| **Clic → celda** | La conversión inversa de la proyección; de ella vive todo el modo construcción |
| **Rótulos, barras, luces** | Reposicionar sobre la nueva proyección |

### Problema conocido a resolver en la conversión

**Las paredes taparán a la gente.** Theme Hospital lo resuelve **bajando las paredes del lado más
cercano a la cámara**. Hay que decidirlo explícitamente: es la diferencia entre ver tu comisaría y ver
una fila de muros.

### Orden acordado

1. **Primero la proyección**, con los rectángulos de colores que ya existen — para comprobar que todo
   sigue funcionando en isométrico sin arte de por medio.
2. **Después el arte**, en 3D pre-renderizado.

Se hace AHORA porque el arte todavía no existe: **no se tira nada**. Cada semana que pasara habría más
capa visual que convertir, y si se hiciera con 100 sprites cenitales ya producidos, se tirarían los 100.

---

## Ampliación aprobada 2026-07-30 — MUROS LIBRES Y ZONAS

> **Origen**: el usuario, jugando: *"ya he puesto paredes pero debe poder ponerse de manera libre como
> theme hospital por ejemplo"* y, al aclararlo: *"la construcción de las paredes debe ser libre y luego
> dentro poner las zonas además de las puertas y ventanas"*.

**Qué decía este GDD hasta hoy**: las paredes existían **solo como decorado** — la tabla de arriba las
cita como *"oficinas/esperas (suelo+paredes con color por servicio)"*, y el Asset Spec pendiente habla
de *"suelos/paredes por servicio"*. Nunca fueron una mecánica: no se construían, no tenían puertas y no
bloqueaban el paso. El modelo era **"sala = rectángulo que dibujas"**, el de Theme Hospital.

**Nota de implementación (2026-07-30)**: ni siquiera la parte decorativa se había hecho. Se implementó
el suelo de color pero no las paredes, así que las salas se leían como alfombras y no como
habitaciones. Eso era una parte del plan visual sin terminar, no una decisión de diseño.

**Verificado en el código de CorsixTH** (la reimplementación libre de Theme Hospital) antes de decidir:
allí una habitación **es un rectángulo** (`Room:Room(x, y, w, h, ...)`), las paredes son estructuras del
mapa y **lo único que coloca el jugador es la puerta** (y ventanas opcionales; una puerta por sala, ni
en fachada ni pegada a una esquina). Es decir: el modelo que pide el usuario **no es el de Theme
Hospital**, es el de **Prison Architect** — muros libres primero, zonas designadas después.

**Decisión del usuario, con el coste sobre la mesa** (26 usos del rectángulo en 7 archivos de `src/` y
18 archivos de tests): se adopta el modelo de muros libres. Es una **ampliación de alcance**, no un
olvido de implementación.

### Modelo nuevo, por fases

| Fase | Qué | Estado |
|---|---|---|
| **A** | **Herramienta de muros**: se pintan libremente, arista a arista, con coste por tramo (`coste_muro`, 15 €). Las salas siguen siendo rectángulos y todo lo demás sigue funcionando — fase ADITIVA. | En curso |
| **B** | **La zona deja de ser un rectángulo**: pasa a ser un conjunto de celdas cualquiera. Aquí se migran aforo (hoy por área), coste (por celdas), el centro de sala que cronometra los caminos, el dibujo del suelo y los tests. | Pendiente |
| **C** | **Zonas dentro de lo cerrado**: detectar recintos cerrados por muros y designar qué es cada uno. Desaparecen las paredes automáticas de sala. | Pendiente |
| **D** | **Puertas y ventanas** colocadas en los muros. | Pendiente |
| **E** | **Los muros bloquean el paso**: navegación real. Aquí cerrar una sala pasa a COSTAR tiempo (la gente rodea) a cambio de intimidad — la disyuntiva que hace interesante la decisión. | Pendiente |

### Decisiones de modelo ya tomadas

- **El muro vive en la ARISTA entre dos celdas**, no dentro de una celda. Así no come superficie útil,
  dos salas pegadas comparten tabique, y el aforo y el coste por área **no cambian**. La alternativa
  (muro = celda) obligaba a redibujar la comisaría inicial y dejaba sin interior una sala de 2×2, que
  es el mínimo permitido (`area_min_sala = 4`).
- **Clave normalizada por arista**: el tabique entre (3,5) y (4,5) es el mismo mirado desde cualquiera
  de las dos celdas, así que las dos formas de nombrarlo dan la misma clave. Sin esa normalización se
  podrían apilar dos muros invisibles en la misma arista y borrar uno dejaría el otro.
- **Los muros cuestan dinero** (15 € el tramo, reembolso al derribar como el resto). Gratis, cerrarlo
  todo sería siempre la jugada obvia y no habría decisión.

---

## UI Requirements

*Construcción es muy UI. La pantalla la posee **UI/HUD #11**; ratón (arrastrar/clic), sin hover-only.*

- **Barra/menú de construcción:** categorías **Salas · Puestos · Objetos**, cada tipo con **icono, nombre y
  coste** (lee de Datos).
- **Herramientas:** **dibujar sala** (arrastrar rectángulo), **colocar** puesto/objeto (clic), **mover**,
  **demoler**.
- **Indicadores en vivo:** **área** y **coste** del elemento en curso, **validez** (verde/rojo, F6),
  **saldo restante** tras la compra.
- **Confirmación de demolición** de sala no vacía (cascada + reembolso — Edge Cases).
- **Modo construcción on/off** (entrar puede pausar el tiempo, opcional — coherente con "gestión en
  Pausa").
- La UI **nunca hardcodea** costes/nombres: los lee de Datos.

> **📌 UX Flag — Construcción y Distribución:** UI compleja (barra de construcción, herramientas de dibujo,
> previews, demolición). En Pre-Producción, ejecutar `/ux-design` para el modo construcción **antes** de
> escribir epics; las stories citan `design/ux/[pantalla].md`.

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.*

**Rejilla y colocación (CO1–CO4, F6)**
- **AC-CO01** `[Unit]` — GIVEN una sala dentro del edificio, sin solapar, área ≥ mínimo WHEN se valida THEN **válida**; si solapa o sale del edificio → **inválida** (F6).
- **AC-CO02** `[Integration]` — GIVEN un `doc_general` WHEN se coloca en `sala_documentacion` THEN válido; en `sala_odac` → **rechazado** (CO4).
- **AC-CO03** `[Unit]` — GIVEN un área < `area_min` WHEN se dibuja THEN **rechazada** (CO3).

**Coste y gate (CO6, F1, F2)**
- **AC-CO04** `[Unit]` — GIVEN sala 3×3 THEN coste `380`; 5×4 → `600` (F1).
- **AC-CO05** `[Integration]` — GIVEN `saldo < coste` WHEN se construye THEN **rechazado**, saldo intacto (E4).
- **AC-CO06** `[Integration]` — GIVEN `saldo=600` WHEN se construye un `doc_general` (500) THEN `saldo=100`.

**Aforo (CO5, F3)**
- **AC-CO07** `[Unit]` — GIVEN sala 5×4 (densidad 0.7) THEN caben **14** plazas; 10 asientos → aforo **10**; intentar 20 → tope **14**.
- **AC-CO08** `[Integration]` — GIVEN una sala de espera **sin asientos** THEN `aforo=0` → Flujo manda a todos a la cola exterior.

**Sin topes / puestos útiles (CO7, F5)**
- **AC-CO09** `[Integration]` — GIVEN `puestos_utiles=5` WHEN el jugador pone 10 puestos THEN **permitido** (5 ociosos), no error.
- **AC-CO10** `[Unit]` — GIVEN demanda pico 17,6/h y throughput 4/h THEN `puestos_utiles = ceil(17.6/4) = 5` (F5).

**Mover/demoler (CO8, F4)**
- **AC-CO11** `[Unit]` — GIVEN demoler `doc_general` (500), `pct_reembolso=0.5` THEN reembolso **250**.
- **AC-CO12** `[Integration]` — GIVEN una oficina con 2 puestos WHEN se demuele THEN **cascada con confirmación**: reembolsa los 2 puestos + la sala.
- **AC-CO13** `[Integration]` — GIVEN un puesto **atendiendo** WHEN se demuele THEN **termina** la atención y luego se demuele.
- **AC-CO14** `[Integration]` — GIVEN un puesto construido WHEN se **mueve** THEN es **gratis** y queda reubicado.

**Existencia, pausa, robustez (CO10, CO12, Edge)**
- **AC-CO15** `[Integration]` — GIVEN un puesto **construido** THEN Flujo/Personal pueden usarlo (gate FL4); **sin construir**, no existe.
- **AC-CO16** `[Integration]` — GIVEN el juego en **Pausa** WHEN se construye/reorganiza THEN se permite (CO12).
- **AC-CO17** `[Unit]` — GIVEN un save del **layout** WHEN se carga THEN se restauran rejilla, salas, puestos y objetos.
- **AC-CO18** `[Unit]` — GIVEN un coste negativo (corrupto) THEN se **clampa a ≥ 0**.

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | **Valores semilla** (`coste_por_celda 20`, `densidad_asientos 0.7`, **`densidad_de_pie 0.5`**, `pct_reembolso 0.5`, `coste_asiento 25`) | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Tamaño del edificio de Pozuelo** (celdas): dimensionar para R5 (caber `puestos_utiles` + esperas + entrada) | Datos + Construcción | 1er playtest | Abierta |
| 3 | **Reconciliación con Datos** — `tope_construible` → referencia de dimensionado (no cupo); `aforo_espera` 40/10 → referencia (aforo real por asientos). **APLICADA** en Datos F7/F4 (verificado en `/consistency-check` 5ª, 2026-07-21). | Datos | — | ✅ Resuelta |
| 4 | **Catálogo de objetos** (`TipoObjeto`) y su detalle (calidad/deterioro/limpieza) | Datos + Comodidades #15 | GDD #15 | Abierta |
| 5 | **¿Construcción instantánea o con obra/tiempo?** MVP instantáneo; validar si la obra aporta o estorba | Diseño / playtest | 1er playtest | Abierta |
| 6 | **Edificios de forma difícil / distinta por comisaría** (reto espacial Theme Hospital) — capturado en #26 | Escalado #26 | GDD #26 | Abierta |
| 7 | **Ampliar edificio / múltiples plantas** (futuro) | Escalado #26 | GDD #26 | Abierta |
| 8 | **¿Reservar de verdad las 3 celdas de la ventanilla (funcionario / mesa / ciudadano) o dejarlo solo visual?** (usuario, 2026-07-30, jugando: *"la mesa de atención debe ser como 3 casillas: 1 donde está el policía, otra la mesa y otra la silla con el ciudadano; ahora veo encima de la mesa al funcionario"*). Hoy el puesto ocupa **1 celda** (CO2/CO4, `superficie=1`); la lectura de 3 casillas es solo el offset visual del sprite (funcionario 1 celda detrás del mostrador, ciudadano 1 celda delante). **Opción A — reservar de verdad** (`superficie=3` orientada): nadie podría construir un asiento/objeto en la celda donde "debería" estar el funcionario — la ventanilla ocupa en el modelo lo que parece ocupar en pantalla. **Opción B — mantenerlo solo visual** (como hoy): más barato en superficie/coste, no toca la validación de colocación (F6) ni los tests existentes — pero, en teoría, cabría un objeto justo en esa celda "reservada" solo por el sprite. Cambiar a A implica tocar coste por superficie, F6 y varios tests. | usuario | — | Abierta |
