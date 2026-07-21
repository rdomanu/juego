# ODAC / Denuncias

> **Status**: Reviewed (/design-review 2026-07-22 APPROVED tras reconciliar la reputación con Paciencia #10)
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / systems-designer / qa-lead — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-22
> **Last Verified**: 2026-07-22
> **Implements Pillar**: Pilar 1 — "Realismo con alma" + Pilar 4 — "Tu comisaría, tus decisiones"

## Overview

El sistema de **ODAC** (Oficina de Denuncias y Atención al Ciudadano) es el servicio que **recibe las
denuncias de la ciudadanía** —de un hurto o una estafa a lo más grave: **VioGén, desaparecidos,
agresiones**— y las tramita **24 horas al día**. A diferencia de Documentación, ODAC **no cobra un euro**:
es **pura obligación** (Pilar 1). Su "producto" no es dinero, sino **reputación**: atender bien —rápido, sin
dejar a nadie tirado y **priorizando lo urgente**— sube la **satisfacción/reputación** de la comisaría, que
a su vez alimenta el **retorno DGP** de Documentación y la **valoración de tus jefes** (#28). Lo que ODAC
**posee** es la **operativa del servicio**: el **orden de prioridad** (las denuncias **Prioritarias**
—VioGén, desaparecidos, agresión sexual, atraco— se atienden **antes** que las Normales) y la
**reconfiguración en caliente** de los puestos (puedes cambiar sobre la marcha **qué denuncias atiende**
cada puesto, para especializar). Lee de *Datos* el catálogo de denuncias (13 tipos, prioridad,
`reconfigurable`); se apoya en los **agentes `ag_odac`** (Personal) sobre los **puestos ODAC** (Construcción);
y *Flujo* **ejecuta** la cola, la prioridad y la reconfiguración.

A nivel de diseño, ODAC es el **contrapeso moral** de Documentación (Pilares 1 y 4): mientras la ventanilla
de documentos **da de comer**, ODAC **cuesta** (salarios, sin ingreso) pero es lo que **justifica que esto
sea una comisaría** — y su buen servicio se traduce en la reputación que hace que todo lo demás rente más.
El corazón son sus **decisiones bajo presión**: *"entra una VioGén y tengo la cola llena de denuncias por
hurto — ¿reconfiguro un puesto para dedicarlo a lo urgente y dejo que las administrativas esperen? ¿aguanto
la noche con un solo puesto o refuerzo?"* Y como son **denuncias reales del CNP**, atender a una víctima **se
siente con peso** (Pilar 1). Sin esta capa no hay servicio público ni la reputación que sostiene la
comisaría: ODAC es **el deber que no se cobra pero se nota**.

> **Regla de propiedad:** ODAC **posee** la *operativa de denuncias*: el **orden de prioridad**, la
> **reconfiguración de puestos** (qué denuncias atiende cada uno) y la **generación de reputación/
> satisfacción** del servicio. **Lee** de *Datos* (catálogo de denuncias, `prioridad`, `reconfigurable`,
> `admite_cita`). **Flujo ejecuta** la cola, el orden por prioridad (F7) y la reconfiguración en caliente
> (FL9). ODAC **genera** satisfacción/reputación → **Paciencia #10** (que la posee) → retorno DGP y
> valoración #28. **No posee**: el *flujo de colas* (→ Flujo #4), la *generación* de denunciantes (→ Demanda
> #5), los *agentes* (→ Personal #6), los *puestos* (→ Construcción #7), los **detenidos/atestados/abogados**
> (→ **Detenidos #17**, V-Slice; un detenido ocupa un puesto ~180 min) ni la *cita previa* (→ **#14**).

## Player Fantasy

**Fantasía:** ser quien lleva el **servicio del deber** — el que se asegura de que, aunque no entre un euro,
**a nadie se le deja tirado** y **lo urgente se atiende primero**. La satisfacción de una comisaría que
**cumple** (Pilares 1 y 4).

Se vive en dos capas:

- **Control directo (priorizar y reconfigurar):** cuando entra una **VioGén** o un **desaparecido**, actúas
  — **reconfiguras un puesto** para dedicarlo a lo urgente, refuerzas la noche, reordenas. Es la fantasía
  del gestor que hace que **lo importante pase delante** sin que se hunda el resto.
- **Infraestructura que se vive (la ODAC nunca duerme):** 24 h, el **goteo nocturno** de madrugada, la
  gente que viene a denunciar a cualquier hora. El edificio atiende de día y de noche — la parte de la
  comisaría que **siempre está de guardia**.

**El momento a anclar:** la **VioGén en plena cola**. Tienes la sala llena de administrativas —hurtos,
daños, un permiso de viaje— y de repente entra una **VioGén (Prioritaria)**. Lo notas en el estómago: **hay
que atenderla ya**. Reconfiguras un puesto para dedicarlo, la VioGén **pasa delante**, y sientes que *"lo
importante se atendió"* — aunque sepas que las administrativas van a esperar (y alguna quizá se marche). Esa
tensión —**lo urgente vs. la cola**— es el corazón de ODAC.

**Referencia de sensación:** la **priorización de casos** de *This Is the Police*, y la gestión de
**urgencias vs. rutina** de *Two Point Hospital*. **Anti-fantasía:** NO es una **cola indiferente** (la
prioridad **importa** — una VioGén no hace fila detrás de un extravío); NO es **"todo da igual"** (atender
bien **rinde reputación**); y NO premia **ignorar lo urgente**. El jugador nunca debe sentir que da lo mismo
atender una VioGén que un daño menor.

*(Nota de proceso: `creative-director` no consultado —modo LEAN + subagentes caídos—; lente creativa
aplicada en el hilo principal. **Gancho Pilar 5:** ODAC es escenario de los dilemas de **Presión e
Influencia #16** —colar a un VIP, denuncia a domicilio— que dan +valoración de jefes a cambio de
−paciencia/−capacidad; el sistema es #16, V-Slice.)*

## Detailed Design

### Core Rules

**OD1 · Las denuncias del servicio.** ODAC tramita **13 tipos** (Datos F2): **4 Prioritarias** (VioGén,
Desaparecidos, Agresión sexual, Robo con violencia — 35–60 min) y **9 Normales** (15–35 min). Sin tarifa
(**obligación**). No inventa tipos; posee la operativa.

**OD2 · 24 horas, sin horario/última admisión.** ODAC está **siempre abierta** (a diferencia de
Documentación): sin slider de horario ni última admisión. La **dotación por turno** (cuántos puestos operan
a cada hora) la lleva Personal. De **noche la afluencia baja**: Demanda aplica un **multiplicador nocturno**
(`mult_nocturno_odac`, **escalable a cualquier población** — no un número fijo) que reduce la tasa de
llegadas de ODAC en la madrugada.

**OD3 · Orden de prioridad (Prioritarias primero).** Las **Prioritarias** se atienden **antes** que las
Normales (Flujo F7: clave `(rango_prioridad, numero_turno)`); dentro de cada grupo, **FIFO**. ODAC posee la
política; Flujo la ejecuta.

**OD4 · Reconfiguración en caliente de puestos.** El jugador cambia, **sobre la marcha**, qué denuncias
atiende cada `puesto_odac` (todas / un subconjunto / solo Prioritarias / una) — para **especializar**.
Afecta a la **próxima llamada**, no interrumpe la atención en curso (Flujo FL9). Es la **palanca de
gestión** de ODAC.

**OD5 · Especialización como válvula anti-inanición.** Sin *aging* en el MVP (Flujo edge), si las
Prioritarias saturan, las Normales podrían no atenderse. La **reconfiguración es la válvula**: dedicar un
puesto **solo a Normales** garantiza que se despachen; otro **solo a Prioritarias** las atiende rápido. El
jugador **equilibra**.

**OD6 · Producto: reputación/satisfacción (no €).** Cada denuncia atendida (bien, sin abandono, priorizando
lo urgente) genera **reputación/satisfacción** (Paciencia #10 la posee). La reputación alimenta el **retorno
DGP** de Documentación y la **valoración de jefes #28**. Un **abandono** (denunciante que se marcha) la
**daña**.

**OD7 · Peso de la prioridad en la reputación.** Atender/abandonar una **Prioritaria** (VioGén,
desaparecido) pesa **más** que una Normal: dejar tirada una VioGén es un golpe grande; atenderla bien, un
plus. *(El peso relativo lo define ODAC; la curva la posee Paciencia #10.)*

**OD8 · Requisitos de operación.** Un puesto ODAC atiende solo si: **construido** (Construcción) + **dotado**
(`ag_odac`, Personal) + la denuncia está en sus `atenciones_admitidas` (reconfiguración) (Flujo FL4).
Abierto = siempre (24 h).

**OD9 · Sin cita (realista).** Las denuncias **no usan cita** — en la Policía Nacional se denuncia sin cita
(Datos F2, decisión 2026-07-22): se atienden por **llegada + prioridad** (F7) y la demanda se acota por
**paciencia/abandono**. La **cita previa #14** aplica solo a **Documentación**; la **atención especial /
colarse** proviene de un **favor del comisario** → Presión e Influencia #16 (fuera del MVP).

**OD10 · Pausa.** En Pausa el jugador puede **reconfigurar** puestos (gestión en pausa); no corre el reloj ni
las atenciones.

**OD11 · Detenidos = futuro (#17).** El MVP tramita **denuncias de ciudadanos**.
Detenidos/atestados/comparecencia/abogado (un detenido ocupa un puesto ~180 min) → **Detenidos #17
(V-Slice)**. Gancho (24 h, puestos largos) ya puesto.

**OD12 · Escenario de dilemas de influencia (#16, futuro).** ODAC es donde se manifiestan los
**favores/dilemas** del Pilar 5 (colar a un VIP, denuncia a domicilio) — sistema **#16 (V-Slice)**; en el
MVP, solo gancho.

### States and Transitions

ODAC **no lleva estado de instancias** (las denuncias/Personas son de Flujo). Lo que ODAC gobierna es la
**configuración de cada puesto** (reconfiguración):

| Modo del puesto ODAC | Qué atiende | Uso típico |
|---|---|---|
| **Polivalente** (default) | Todas las denuncias | Arranque / poca carga |
| **Solo Prioritarias** | VioGén, desaparecidos, agresión sexual, atraco | Dedicar un puesto a lo urgente |
| **Solo Normales** | Las 9 administrativas | Garantizar que las administrativas avancen (anti-inanición) |
| **Subconjunto / una** | Los tipos que elija el jugador | Especialización fina |

- **Transición:** el jugador **reconfigura** (cambia el modo/subconjunto) en cualquier momento; afecta a la
  próxima llamada (FL9), no a la atención en curso. En **Pausa** se permite.
- El resto de estados (puesto Cerrado/Libre/Atendiendo; denunciante Esperando/Llamada…) son de
  **Flujo/Personal**.

### Interactions with Other Systems

| Sistema | Qué fluye | Dueño |
|---|---|---|
| **Datos** | *lee* catálogo de denuncias (13 tipos, `prioridad`, `reconfigurable`) | Datos ✅ GDD |
| **Flujo #4** | *configura* la reconfiguración (FL9) y confía la cola/orden por prioridad (F7); Flujo **ejecuta** | ODAC configura; Flujo ejecuta ✅ GDD |
| **Generación de Demanda #5** | *recibe* los denunciantes (multiplicador nocturno, mezcla de 13 tipos, eventos estacionales) | Demanda genera ✅ GDD |
| **Personal #6** | usa `ag_odac`; dotación por turno (24 h) | Personal posee la dotación ✅ GDD |
| **Construcción #7** | usa los **puestos ODAC** y la oficina | Construcción ✅ GDD |
| **Paciencia y Satisfacción #10** | *genera* **satisfacción/reputación** (con **peso extra** para Prioritarias); *recibe* de vuelta la carga de `reclamacion` (PS13) | Paciencia posee la curva ✅ GDD |
| **Economía #3** | **coste** (salarios), **sin ingreso**; la reputación mejora el retorno DGP (indirecto) | Economía ✅ GDD |
| **Valoración de jefes #28** *(futuro)* | la reputación de ODAC alimenta la valoración | #28 *(diferido)* |
| **Detenidos #17** *(V-Slice)* | *(futuro)* atestados/detenidos/abogado | #17 *(diferido)* |
| **Presión e Influencia #16** *(V-Slice)* | *(futuro)* dilemas/favores (colar VIP, domicilio) | #16 *(diferido)* |
| **UI / HUD #11** | reconfiguración de puestos, colas por prioridad, indicador de reputación | UI presenta |

## Formulas

> ODAC tiene **pocas fórmulas propias** (prioridad/reconfiguración las ejecuta Flujo; la escala de
> satisfacción la posee Paciencia). Las clave son la **reputación** (peso de prioridad) y el **chequeo de
> capacidad**. Números **semilla provisional**. Prefijo `F#`.

### F1 · Contribución de ODAC a la satisfacción (el peso de la prioridad)

ODAC **no calcula** su reputación con una fórmula aparte: la **satisfacción de ODAC (0–100) la calcula
Paciencia #10** (su F2/F3), igual que la de Documentación — cada denuncia genera una `puntuacion_visita`
(que **penaliza la espera** y el trato; abandono = 0) y la media se **pondera por prioridad**. Lo que ODAC
**posee y aporta** es el **peso relativo de la prioridad**:

`peso_prioridad(tipo) = Normal 1.0 · Prioritaria peso_prioridad_prioritaria (default 2.5)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `peso_prioridad(tipo)` | float | Normal **1.0** · Prioritaria **~2.5** (knob de ODAC) | Cuánto pesa esa denuncia en la media de satisfacción de ODAC (Paciencia F3) |

**Efecto (vía Paciencia F2/F3):** una **VioGén** bien atendida cuenta **2.5×** en la media (atenderla bien la
sube mucho; **dejarla abandonar cuenta como una visita de puntuación 0 con peso 2.5** → la hunde mucho). Una
**Normal** cuenta 1×. *Así "priorizar lo urgente" pesa más, sin que ODAC necesite una segunda fórmula de
reputación.*

> **Reconciliación (2026-07-22):** se **retiraron** las fórmulas propias de ODAC `reputacion_aporte` /
> `reputacion_penalizacion` y sus knobs `base_reputacion` / `base_abandono` — eran un **modelo paralelo** al
> de Paciencia. Ahora hay **una sola escala 0–100** (la de Paciencia, que penaliza la espera); ODAC solo
> aporta `peso_prioridad`. *(Decisión del usuario al revisar ODAC #9.)*

### F2 · Capacidad ODAC y chequeo R5 (referenciado)

`throughput_puesto_odac = minutos_operativos / duracion_efectiva_media` (**Flujo F2**)

**Chequeo:** con dotación ~16 h (960 min) y **duración media ponderada ≈ 30 min** (las Prioritarias de 60
min son **poco frecuentes** —VioGén/desaparecidos/agresión sexual 2–4% cada una—, así que la media ponderada
por la mezcla apenas sube pese a los 13 tipos: **cálculo con la mezcla de Demanda F3 = 29,75 min**):
`960/30 ≈ **32/día**` por puesto → 4 puestos ≈ **128/día**. Demanda ODAC ~36/día → **absorbe con margen** ✔
(R5, ×3,5). *(La duración media ponderada la fija la **mezcla** de Demanda F3; a validar en playtest.)*

**Fórmulas/valores referenciados (dueño externo):**
- **Multiplicador nocturno** `mult_nocturno_odac` (reduce la tasa de ODAC de madrugada; escalable por
  población) → **Demanda #5**.
- **Orden por prioridad** `clave = (rango_prioridad, numero_turno)` → **Flujo F7**.
- **Satisfacción 0–100** que consume la reputación → **Paciencia #10**.
- **Carga por reclamaciones** `tramite_reclamacion` (30 min, sin tarifa): la **inyecta Paciencia** (PS13) cuando
  un ciudadano abandona Documentación y acude a formalizar la hoja. Es carga **variable y autoinfligida** —**no**
  altera la demanda base ni el chequeo R5 de arriba— pero **come capacidad** de puestos ODAC → **Paciencia #10 / Datos**.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre OD1–OD12 y F1–F3.*

- **Si las Prioritarias saturan y las Normales no avanzan (inanición):** las Normales esperan tras todas las
  Prioritarias y, si la presión es alta, **abandonan** (sin *aging* en MVP). La **válvula** es reconfigurar
  un puesto **solo a Normales** (OD5). *No es error; es la decisión de gestión central de ODAC.*
- **Si se reconfigura un puesto a un conjunto vacío** (que no atienda nada): se **rechaza** (un puesto debe
  atender **≥1 tipo**). *Un puesto que no llama a nadie es un error de configuración, no una opción válida.*
- **Si tras reconfigurar ningún puesto atiende un tipo** (p. ej. nadie atiende VioGén): esas denuncias
  **esperan hasta abandonar** → **golpe de reputación** (F2, ×2.5 si es Prioritaria). *Realimentación de
  "has dejado un hueco crítico", no un bug.*
- **Si entran varias Prioritarias a la vez** (pico): saturan los puestos que las atienden; las Normales
  esperan. El jugador **reconfigura/refuerza**. *La reconfiguración y la dotación son las palancas.*
- **Si se reconfigura un puesto durante una atención en curso:** **no la interrumpe**; el nuevo conjunto
  afecta a la **próxima** llamada (Flujo FL9). *Compromiso de servicio: no se corta una denuncia a medias.*
- **Si de noche no hay puestos ODAC dotados:** el **goteo nocturno** espera/abandona (el servicio abre 24 h
  pero sin agente no atiende, FL4). *Señal de falta de dotación nocturna, no un bug.*
- **Si se abandona una VioGén (Prioritaria):** penalización **grande** de reputación (F2, ~−5). *Es el peor
  caso; el diseño empuja a evitarlo priorizando.*
- **Si `mult_nocturno_odac = 0`** (config): de noche ODAC **no recibe a nadie** (válido; noche muerta).
  *Configuración extrema válida, no error.*
- **Si una denuncia llega con `prioridad` inválida** (dato corrupto): se **trata como Normal** con aviso.
  *Un dato malo no debe colar una denuncia como Prioritaria por error.*
- **Si un valor de reputación/peso llega fuera de rango:** se **clampa a un mínimo/máximo seguro** y se
  registra aviso. *Mismo patrón de clamp que el resto.*
- **Si se guarda la partida:** se serializan la **configuración de cada puesto** (qué atiende) y la
  **reputación acumulada**; al cargar se restauran y arranca en Pausa. *El estado de ODAC se persiste
  íntegro.*

## Dependencies

Como Documentación, ODAC es un **Feature configurador** (parametriza Flujo con la prioridad/reconfiguración).
Todas las upstream cerradas ✅.

**Este sistema depende de / configura:**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Datos** | Hard | *lee* catálogo de denuncias (13 tipos, `prioridad`, `reconfigurable`) ✅ GDD |
| **Flujo #4** | Hard | *configura* la reconfiguración (FL9); confía la cola/orden por prioridad (F7); Flujo **ejecuta** ✅ GDD |
| **Personal #6** | Hard | usa `ag_odac`; dotación por turno (24 h) ✅ GDD |
| **Construcción #7** | Hard | usa los **puestos ODAC** y la oficina ✅ GDD |

**Dependen de este sistema / lo alimentan:**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Generación de Demanda #5** | Hard | genera los **denunciantes** (multiplicador nocturno, mezcla de 13 tipos, eventos) ✅ GDD |
| **Paciencia y Satisfacción #10** | Hard | ODAC **genera** satisfacción/reputación (peso extra para Prioritarias) ✅ GDD; y **recibe** de Paciencia la carga de `tramite_reclamacion` (PS13, 30 min, autoinfligida) |
| **Economía #3** | Soft | ODAC **cuesta** (salarios), **no ingresa**; su reputación mejora el retorno DGP (indirecto) ✅ GDD |
| **Valoración de jefes #28** *(futuro)* | Soft | la reputación de ODAC alimenta la valoración *(diferido)* |
| **Detenidos #17** *(V-Slice)* | Hard | *(futuro)* atestados/detenidos/abogado (puestos largos) *(diferido)* |
| **Presión e Influencia #16** *(V-Slice)* | Soft | *(futuro)* dilemas/favores (colar VIP, denuncia a domicilio) *(diferido)* |
| **UI / HUD #11** | Hard | reconfiguración de puestos, colas por prioridad, indicador de reputación |

> **Consistencia bidireccional:** todas las upstream (**Datos ✅, Flujo ✅, Personal ✅, Construcción ✅**) y
> **Demanda ✅**, **Economía ✅** ya registran/reflejan la relación con ODAC. Registrado en
> `systems-index.md`.

## Tuning Knobs

### Knobs propios de ODAC

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `peso_prioridad_prioritaria` (F1) | 2.5 | 1.0 – 5.0 | ↑ atender/perder Prioritarias pesa mucho más en la satisfacción de ODAC (priorizar es crítico) / ↓ se aplana | ODAC |
| **modos de reconfiguración** (Polivalente / Prioritarias / Normales / subconjunto) | los 4 | — | Añadir presets = más granularidad de gestión | ODAC |

*(La escala 0–100 y sus knobs —`puntuacion_base` 80, `k_espera`, abandono = 0— los posee **Paciencia #10**;
ODAC ya no tiene `base_reputacion`/`base_abandono` propios tras la reconciliación de F1.)*

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto sobre ODAC |
|------|-----------|-------------------|
| `duracion_min` (13 denuncias, 15–60) | Datos → ODAC | Duración de cada denuncia (throughput F3) |
| `prioridad` (Prioritaria/Normal) | Datos → ODAC | Quién pasa delante (F7) |
| `mult_nocturno_odac` | Demanda | Cuánto baja la afluencia de madrugada (escalable) |
| mezcla de denuncias (pesos de los 13) | Demanda F3 | Cuántas Prioritarias vs Normales llegan → carga |
| `tope`/capacidad (4 puestos ODAC) | Datos/Construcción | Techo de capacidad (128/día) |
| `habilitar_aging_odac` | Flujo | Anti-inanición de Normales (MVP off; reconfiguración como válvula) |
| satisfacción 0–100 | Paciencia #10 | La escala real que consume la reputación |

**Interacciones entre knobs (clave):**
- **`peso_prioridad` × mezcla (Demanda)** definen **cuánto duele priorizar mal**: si hay muchas Prioritarias
  y pesan mucho, la reconfiguración es obligada.
- **`mult_nocturno_odac` × dotación nocturna (Personal)** definen si la noche se cubre con 1 puesto o hace
  falta más.
- **`peso_prioridad` × abandono (Paciencia #10)** define cuánto castiga dejar tirada una Prioritaria (un abandono cuenta como visita de puntuación 0 con su peso — Paciencia F2/F3).
- **`habilitar_aging_odac` (Flujo)** es la alternativa a la reconfiguración manual: si se activa, las
  Normales suben solas (menos necesidad de gestionar).

**Restricciones:** `peso_prioridad ≥ 1.0`; los pesos de mezcla suman 1.0 (Demanda).

## Visual/Audio Requirements

*Estilo art bible: institucional serio, VioGén/Prioritarias con **marca de urgencia** (rojo + icono,
daltónico), NO alarmista.*

| Elemento/Evento | Visual | Audio | Prioridad |
|---|---|---|---|
| **Denunciante** | Silueta con carpeta/papel (art bible §3); **Prioritarias** con marca de urgencia (rojo + icono) | Murmullo ambiente | Siempre |
| **Cola por prioridad** | Las **Prioritarias arriba/destacadas**; Normales debajo (icono + etiqueta) | — | Alta (legibilidad) |
| **Modo del puesto** (reconfiguración) | Icono del modo por puesto: Polivalente / Prioritarias / Normales / subconjunto | — | Siempre visible |
| **Llegada de VioGén/Prioritaria** | Aviso de **urgencia** (rojo sobrio) | Aviso serio (no alarma estridente) | **Alta** |
| **Reputación** (sube/baja) | Indicador de reputación del servicio con ↑/↓ | Tono sutil | Media |
| **Abandono de una Prioritaria** | Golpe visual (la denuncia se marcha, marca de fallo) | Golpe sobrio | **Alta** (fallo grave) |

> 📌 **Asset Spec** — Tras aprobar el art bible, `/asset-spec system:odac` para iconos de denuncia (13
> tipos), marca de urgencia/prioridad, iconos de modo de puesto, indicador de reputación.

## UI Requirements

*La pantalla la posee **UI/HUD #11**; ratón, sin hover-only.*

- **Panel de reconfiguración de puestos** *(control principal)*: por cada `puesto_odac`, elegir **qué
  atiende** (Polivalente / solo Prioritarias / solo Normales / subconjunto de los 13 tipos). Marca no válido
  si queda vacío (Edge Cases).
- **Cola por prioridad:** ver la cola con las **Prioritarias arriba** (destacadas) y las Normales debajo; nº
  en cola por tipo.
- **Indicador de reputación** del servicio (y su tendencia).
- **Avisos de urgencia** (VioGén/Prioritaria entrante) y de **abandono** de una Prioritaria.
- La UI **nunca hardcodea** los tipos/prioridades: los lee de Datos.

> **📌 UX Flag — ODAC:** UI real (reconfiguración de puestos, cola por prioridad, reputación, avisos de
> urgencia). En Pre-Producción, ejecutar `/ux-design` para estos controles **antes** de escribir epics; las
> stories citan `design/ux/[pantalla].md`.

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.*

**Denuncias y prioridad (OD1, OD3)**
- **AC-OD01** `[Unit]` — GIVEN el catálogo THEN ODAC tramita **13 tipos** (4 Prioritarias, 9 Normales) de Datos.
- **AC-OD02** `[Integration]` — GIVEN cola con VioGén(Prioritaria) y hurto(Normal) WHEN un puesto llama THEN atiende **VioGén primero** (F7).
- **AC-OD03** `[Unit]` — GIVEN dos Prioritarias en cola THEN se atienden en **FIFO** (menor `numero_turno`).

**Reconfiguración (OD4, OD5)**
- **AC-OD04** `[Integration]` — GIVEN un puesto WHEN se reconfigura a "solo Prioritarias" THEN deja de llamar Normales; afecta la **próxima** llamada, no la actual (FL9).
- **AC-OD05** `[Integration]` — GIVEN Prioritarias saturando WHEN se dedica un puesto a Normales THEN las Normales **avanzan** (válvula anti-inanición).
- **AC-OD06** `[Integration]` — GIVEN reconfigurar un puesto a **conjunto vacío** THEN se **rechaza** (≥1 tipo).

**24 h y nocturno (OD2)**
- **AC-OD07** `[Integration]` — GIVEN ODAC WHEN es de madrugada THEN sigue **abierta** y la tasa **baja** por `mult_nocturno_odac` (Demanda).
- **AC-OD08** `[Integration]` — GIVEN de noche **sin** puesto dotado THEN el goteo **espera/abandona** (FL4).

**Reputación (OD6, OD7, F1, F2)**
- **AC-OD09** `[Integration]` — GIVEN una VioGén (Prioritaria) y una Normal, ambas bien atendidas WHEN Paciencia promedia la satisfacción de ODAC (F3) THEN la VioGén **pesa 2.5×** frente a la Normal (`peso_prioridad` de ODAC). *(La puntuación 0–100 la calcula Paciencia F2, penalizando la espera; ODAC aporta el peso.)*
- **AC-OD10** `[Integration]` — GIVEN una VioGén **abandonada** (Prioritaria) WHEN Paciencia la registra THEN cuenta como visita de **puntuación 0 con peso 2.5** → hunde la satisfacción de ODAC mucho más que un abandono Normal (peso 1.0). *(Dejar tirada una VioGén es el peor golpe, vía el peso.)*
- **AC-OD11** `[Integration]` — GIVEN una denuncia ODAC completada THEN el `saldo_eur` **NO** cambia (sin ingreso); **sí** genera reputación (Paciencia).

**Capacidad/R5, cita, pausa, guardado (F3, OD9, OD10, Edge)**
- **AC-OD12** `[Unit]` — GIVEN dotación 960 min y dur. media ~30 (mezcla F3 = 29,75) THEN throughput ~**32/día**; 4 puestos ~**128/día** ≥ demanda ~36 (R5).
- **AC-OD13** `[Integration]` — GIVEN MVP (sin cita) THEN la demanda de ODAC **no se autolimita**.
- **AC-OD14** `[Integration]` — GIVEN el juego en **Pausa** WHEN se reconfigura un puesto THEN se permite; las atenciones no corren.
- **AC-OD15** `[Unit]` — GIVEN un save con config de puestos + reputación WHEN se carga THEN se restauran.
- **AC-OD16** `[Unit]` — GIVEN una denuncia con `prioridad` inválida THEN se trata como **Normal** con aviso.

## Open Questions

| # | Pregunta | Dominio | Cuándo se resuelve | Estado |
|---|----------|---------|--------------------|--------|
| 1 | **Valores semilla** (`peso_prioridad_prioritaria 2.5`, `mult_nocturno_odac`) — ¿los números iniciales dan una curva de satisfacción/reputación legible? *(La escala 0–100 y sus knobs los posee Paciencia #10 tras la reconciliación de F1.)* | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Reputación → retorno DGP / valoración #28** — ¿cómo convierte Paciencia #10 la reputación ODAC en el retorno mensual y en la valoración de jefes? Aquí solo se **produce** reputación; el consumo lo define #10/#28. | Paciencia #10 / Valoración #28 | Al diseñar #10 y #28 | Abierta |
| 3 | **Reconciliación Fase 5** — (a) mezcla de Demanda F3 redistribuida a **13 tipos** (Normales 0.87 / Prioritarias 0.13); (b) "~10 nocturno" sustituido por `mult_nocturno_odac` (default 0.5, escalable) en Demanda/Tiempo + registro (Flujo no lo referenciaba); (c) duración media ponderada validada = **29,75 ≈ 30 min** → throughput ~32/puesto, 4 puestos ~128/día ≥ 36 (R5). | Consistencia (este proyecto) | — | ✅ Aplicada 2026-07-21 |
| 4 | **Aging vs reconfiguración** — ¿basta la reconfiguración manual de puestos como válvula anti-inanición, o hace falta *aging* automático (subir prioridad de Normales que esperan demasiado)? | Diseño (ODAC / Paciencia #10) | Playtest MVP | Abierta |
| 5 | **Detenidos / abogados #17** — reservada la operativa 24h para que #17 (V-Slice) añada detenciones, calabozo y asistencia letrada sobre esta base. ¿Comparten puesto o requieren puesto propio? | Detenidos #17 | Al diseñar #17 (post-MVP) | Diferida |
| 6 | **Eventos de influencia #16** — "colar a un VIP" (sube valoración de jefes, baja paciencia de la sala) y "denuncia a domicilio" (deja el puesto sin dotación ~2 h). Capturados para #16; ¿se activan también en Documentación cuando exista el sistema de citas #14? | Presión e Influencia #16 | Al diseñar #16 | Diferida |
| 7 | **Cita previa #14** — las denuncias **no usan cita** (decisión 2026-07-22, realista; AC-OD13). La cita previa #14 aplica solo a **Documentación**; la **atención especial / colarse** en ODAC proviene de un favor del comisario → #16, no de cita. | Cita previa #14 / Influencia #16 | Al diseñar #14/#16 | Diferida |
