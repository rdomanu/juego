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
aguarda (su **aforo** lo dan los asientos, no un número fijo). Lee de *Datos* los tipos de puesto/sala, sus
costes y la superficie de los puestos; opera con *Economía* el gate "¿puedo pagarlo?" y el descuento al
colocar.

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
> posición** de cada puesto y el **aforo** de cada sala de espera. **No posee**: *qué atiende* un puesto (→
> Datos), *quién lo opera* (→ Personal #6), el *ciclo de atención* (→ Flujo #4), ni la *calidad/deterioro*
> de los asientos (→ **Comodidades #15**; Construcción los coloca, #15 les da calidad). *(Reconciliación
> con Datos: `tope_construible` → **límite físico del edificio**; `aforo_espera` 40/10 → **referencia**, el
> aforo real lo dan los asientos. R5 se mantiene por el espacio.)*

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
- **Objetos:** asientos (→ aforo), mostradores, decoración *(Comodidades #15 los detalla; MVP: asiento
  básico = 1 plaza)*.

**CO3 · Dibujar una sala (tamaño libre).** Se elige un tipo de sala y se **arrastra** un rectángulo de
celdas. Reglas: **dentro del edificio**, **no solapa** con otra sala, **tamaño ≥ mínimo**. Coste al
confirmar (Formulas). **Sobredimensionar o hacinar es libre** (con consecuencias — Comodidades/Paciencia).

**CO4 · Colocar puestos y objetos dentro.** Un puesto se coloca **dentro de la oficina de su servicio**
(`doc_general`/`tie` en `sala_documentacion`; `odac` en `sala_odac`). Un asiento, dentro de una sala de
espera. Ocupan celdas; **no solapan**.

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
| **Flujo #4** | *provee* la **existencia y posición** de puestos y el **aforo** (por asientos) de las salas | Construcción provee; Flujo opera ✅ GDD |
| **Personal #6** | *provee* los **puestos** donde Personal asigna agentes | Construcción provee ✅ GDD |
| **Documentación #8 / ODAC #9** | sus oficinas y puestos | ellos poseen su operativa *(provisional)* |
| **Comodidades #15** *(V-Slice)* | *(futuro)* los asientos/objetos con **calidad y deterioro** (Construcción los coloca; #15 su calidad) | #15 posee la calidad *(diferido)* |
| **Paciencia #10** | *(indirecto)* el **aforo** y la comodidad de la sala afectan la espera | Paciencia posee la curva *(provisional)* |
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

### F3 · Aforo de una sala de espera (por asientos)

`aforo_sala = min( plazas_asientos_colocadas , plazas_max_por_area )`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `plazas_asientos_colocadas` | int | ≥ 0 | Suma de plazas de los asientos puestos (MVP: asiento básico = 1) |
| `plazas_max_por_area` | int | ≥ 0 | `floor(area_celdas × densidad_asientos)` — cuántas plazas caben |
| `densidad_asientos` | float | 0.7 (tuning) | Plazas por celda (deja hueco para pasillos) |

**Salida:** sala 5×4 (20 celdas), densidad 0.7 → caben `floor(20×0.7)=14` plazas; si colocas 10 asientos →
aforo **10**; si intentas 20 → tope **14**. *(El `aforo_espera` 40/10 de Datos es la referencia del aforo
típico a tope de construcción histórico.)*

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

**Nota de frontera:** el **coste base** de puestos/salas lo posee **Datos**; la **calidad de los asientos**
(más allá de 1 plaza), **Comodidades #15**; el **dimensionado del edificio** para cumplir R5,
**Datos/Construcción** conjuntamente.

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
- **`densidad_asientos` × área de sala** definen el **aforo** (F3): salas eficientes vs. amplias.
- **`pct_reembolso` × `coste_mover`** definen **cuánto cuesta reorganizar**: bajos = libertad total (Pilar
  4); altos = planificar bien de entrada.
- **`tamaño_edificio` es el nuevo "tope"**: debe caber ≥ `puestos_utiles` (F5) para cumplir R5; encogerlo
  es la palanca de dificultad espacial por comisaría (#26).

**Restricciones:** `coste_por_celda, coste_base_sala, coste_asiento_basico, coste_mover ≥ 0`; `pct_reembolso
∈ [0,1]`; `densidad_asientos ∈ (0,1]`; `tamaño_edificio` ≥ caber `puestos_utiles` (R5).

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
| 1 | **Valores semilla** (`coste_por_celda 20`, `densidad_asientos 0.7`, `pct_reembolso 0.5`, `coste_asiento 25`) | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Tamaño del edificio de Pozuelo** (celdas): dimensionar para R5 (caber `puestos_utiles` + esperas + entrada) | Datos + Construcción | 1er playtest | Abierta |
| 3 | **Reconciliación con Datos** — `tope_construible` → referencia de dimensionado (no cupo); `aforo_espera` 40/10 → referencia (aforo real por asientos). **APLICADA** en Datos F7/F4 (verificado en `/consistency-check` 5ª, 2026-07-21). | Datos | — | ✅ Resuelta |
| 4 | **Catálogo de objetos** (`TipoObjeto`) y su detalle (calidad/deterioro/limpieza) | Datos + Comodidades #15 | GDD #15 | Abierta |
| 5 | **¿Construcción instantánea o con obra/tiempo?** MVP instantáneo; validar si la obra aporta o estorba | Diseño / playtest | 1er playtest | Abierta |
| 6 | **Edificios de forma difícil / distinta por comisaría** (reto espacial Theme Hospital) — capturado en #26 | Escalado #26 | GDD #26 | Abierta |
| 7 | **Ampliar edificio / múltiples plantas** (futuro) | Escalado #26 | GDD #26 | Abierta |
