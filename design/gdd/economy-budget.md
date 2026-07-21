# Economía / Presupuesto

> **Status**: Reviewed (/design-review lean 2026-07-19)
> **Author**: manu.rdo + Claude (hilo principal; lentes economy-designer / systems-designer / qa-lead — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-19
> **Last Verified**: 2026-07-19
> **Implements Pillar**: Pilar 4 — "Tu comisaría, tus decisiones" (presupuesto siempre justo) + Pilar 1 — "Realismo con alma" (tasas oficiales → DGP)
>
> **Nota de proceso**: `/design-review` (lean) del 2026-07-19: veredicto **NEEDS REVISION** (3 bloqueantes + 4 recomendados), **todos resueltos en la misma sesión**. Cambios clave: (1) recargo de deuda calculado sobre la deuda de **apertura** del día (arregla la contradicción F6↔AC-E09); (2) **modelo de préstamo cerrado** — coste híbrido (fija + % de ingresos) mientras el préstamo esté vivo, con **devolución** del principal para cancelarlo; (3) **rescate de insolvencia** con pausa + modal + ventana de gracia de 12 h. Log: `design/gdd/reviews/economy-budget-review-log.md`.

## Overview

El sistema de **Economía / Presupuesto** es la capa de dinero del juego: lleva la **caja de la comisaría**
y gobierna cada **ingreso** y cada **gasto**. A nivel técnico es un libro de cuentas que **lee** de *Datos
y Configuración* las cifras ya definidas —tarifas, costes de construcción, salarios, peonada, parámetros de
retorno DGP— y las convierte en un saldo que sube y baja con el tiempo: cobra por los trámites atendidos,
paga los salarios diarios del personal, descuenta las obras y las horas extra, y **cierra cuentas por
ciclos** que marca el Sistema de Tiempo (`nuevo_dia` / `nuevo_mes`). No inventa números: **posee la
*fórmula* de retorno DGP, el *ciclo* de presupuesto y los *flujos* de caja, y el *porqué y los rangos* de
cada euro**, mientras que los valores semilla concretos viven en Datos.

A nivel de diseño, el jugador **lo siente directamente**: el presupuesto es un recurso siempre justo que
convierte construir un puesto o contratar a un agente en una **decisión real** (Pilar 4 — "Tu comisaría,
tus decisiones"). El corazón del sistema es una tensión deliberada y realista (Pilar 1): las **tasas
oficiales** (DNI, Pasaporte, TIE) **no las ingresa la comisaría** —van a la Dirección General de la
Policía—, y lo que vuelve es un **retorno por desempeño** con un suelo fijo: cuanto mejor sirves, más te
devuelve la DGP. Así, **Documentación es tu única fuente de ingresos** y **ODAC es pura obligación**
(cuesta salarios y no genera euros; rinde en reputación). Sin esta capa no habría escasez, y sin escasez no
habría decisiones: el presupuesto es lo que da peso a todo lo que el jugador construye y prioriza.

> **Regla de propiedad:** Economía **posee** la fórmula `retorno_DGP(sat)`, el ciclo de presupuesto
> (diario/mensual), los flujos ingreso/gasto y los *rangos/porqué* de los valores económicos. **Lee** de
> `data-config.md` (vía `entities.yaml`) los valores semilla (tarifas, costes, salarios, peonada,
> `retorno_dgp_min/max`) **sin duplicarlos**. La *satisfacción* que alimenta el retorno la posee
> **Paciencia y Satisfacción (#10)** ✅ GDD: `sat` = `sat_cierre_doc`, la **media cerrada de satisfacción de
> Documentación de la jornada anterior** (fija todo el día → ingreso estable intra-jornada; Paciencia F3).

> **Alcance MVP y crecimiento:** en el MVP (Subinspector, Pozuelo) los **ingresos** = retorno DGP de
> Documentación; los **gastos** = salarios, construcción y peonadas. Al **ascender** (Ascensos #18) se
> abren nuevos canales —subvenciones, **bonus de la Dirección General**, más partidas de gasto—; el sistema
> se diseña **extensible** para añadirlos como nuevas fuentes sin rehacerlo. *(Detalle diferido; ver Open
> Questions.)*

## Player Fantasy

**Fantasía:** ser el gestor que **hace mucho con poco** — un presupuesto siempre corto que te obliga a
priorizar, donde cada euro es una apuesta y **cada mejora del servicio se nota en la caja**. No eres un
contable: eres quien decide en qué se convierte el dinero de tu comisaría.

Se vive en dos capas:

- **Control directo (decidir el gasto):** abrir otra ventanilla, contratar a un agente, pagar una peonada
  para no dejar la cola tirada… cada gasto es una decisión con **coste de oportunidad**. La fantasía es la
  del administrador que sopesa: *"¿me gasto los 500 € en otro puesto de Documentación ahora, o aguanto y
  ahorro para el de ODAC?"* El dinero es lo que hace que colocar una pieza **pese**.
- **Infraestructura que se siente (la caja respira):** aunque no toques nada, el dinero fluye — entra el
  **goteo del retorno DGP** por cada trámite bien atendido, salen los **salarios** cada día, se cierran las
  cuentas del ciclo. El jugador nota su salud financiera como quien mira el saldo del banco: la sensación
  de "voy holgado" o "voy justo" **tiñe todas las demás decisiones**.

**El momento a anclar:** acaban de descontarse los salarios del día y te has quedado con lo justo para
**una** cosa. La cola de Documentación crece y podrías abrir un puesto más (más ingresos… si hay demanda),
pero si te gastas la caja te quedas sin colchón para la nómina de mañana. ¿Inviertes o aguantas? Esa cuenta
—dinero que entra por servir bien contra dinero que sale sí o sí— es donde el presupuesto deja de ser un
número y se vuelve **decisión**.

**Referencia de sensación:** la gestión de caja ajustada de *Prison Architect* (grants/balance), *Two Point
Hospital* y *This Is the Police* — la satisfacción de ver una comisaría que **se paga a sí misma** gracias
a tu buen servicio. **Anti-fantasía:** NO es una hoja de cálculo que micro-gestionas línea a línea, ni un
simulador de quiebra cruel donde un mal día te borra la partida (fallar un objetivo **no es game over**:
aprietas el cinturón y lo intentas de nuevo). La tensión es de **escasez que hace pensar**, no de castigo.

## Detailed Design

### Core Rules

**E1 · Saldo único (la caja).** La comisaría tiene un único `saldo_eur` — **estado mutable de partida** que
posee Economía y persiste Guardado. Arranca en `caja_inicial_eur` (tuning) al iniciar el Escenario.

**E2 · Ingresos (MVP: un solo canal).** El único ingreso del MVP es el **retorno DGP** por cada trámite de
Documentación completado. Al recibir el evento *"trámite completado"* (de Flujo), Economía abona **al
instante** `ingreso_comisaria = tarifa_eur × retorno_DGP(sat)` (ver Formulas). **ODAC no genera ingreso**
(obligación; rinde reputación, no euros). *Canales futuros (subvenciones, bonus DGP) se añaden al ascender
— el sistema es extensible.*

**E3 · Gastos (MVP: tres tipos).**
- **Salarios** (recurrente): al cierre de cada día (`nuevo_dia`) se descuenta la suma del
  **`salario_dia_efectivo`** de cada agente **contratado** (Personal F1 = salario base de Datos × prima por
  atributos/rango; dotación en Personal).
- **Construcción** (puntual): al confirmar la colocación de un puesto/sala (evento de Construcción) se
  descuenta su `coste_construccion_eur` de una vez. **Al demoler**, se **reembolsa un %** del coste
  (`pct_reembolso_demolicion`, Construcción #7 F4); **mover** es gratis.
- **Peonadas** (por hora extra): si un agente trabaja fuera de su horario base, se acumula
  `peonada_eur_hora × horas_extra` y se descuenta al cierre de día. *(Las reglas de cuándo hay hora extra
  las posee Horarios/Personal — provisional en MVP; Economía solo aplica el coste.)*

**E4 · El gasto voluntario exige caja (no te endeudas construyendo).** Construir o contratar (gasto
**voluntario**) solo se permite si `saldo_eur ≥ coste`. No puedes colocar lo que no puedes pagar. *Protege
el pacing gradual y evita endeudarse a propósito.*

**E5 · Deuda por obligaciones (permitida, con recargo).** Los gastos **obligatorios**
(salarios, peonadas ya comprometidas, penalización de préstamos vivos) se descuentan **aunque dejen el
saldo negativo**: puedes entrar en **deuda** por no poder pagar la nómina. Mientras `saldo_eur < 0`:
- se aplica un **recargo diario** sobre la deuda (`interes_deuda_diario`, al cierre de día) — el agujero
  crece si no lo tapas. **El recargo se calcula sobre la deuda de *apertura* del día** (la que arrastras del
  cierre anterior), **no** sobre el déficit que crea la nómina de hoy: si hoy entras en rojo por la nómina,
  el primer recargo es *mañana* (ver F5/F6 y Edge Cases);
- se activa el **estado "números rojos"** (aviso claro en UI);
- **queda bloqueado el gasto voluntario** (E4) hasta volver a `saldo_eur ≥ 0`;
- puedes recurrir al **préstamo del Comisario** como salvavidas (ver **E9**).
Si la deuda alcanza el **suelo de insolvencia** `−deuda_max_eur`, entra en juego el salvavidas del Comisario:
mientras te queden préstamos, te rescata con coste; **agotados, es game over** (ver **E9**).

**E6 · Ciclo de cuentas: día = flujo, mes = objetivo.** El **día** es la unidad de flujo (ingresos
continuos + salarios/peonadas/recargo al cierre de `nuevo_dia`). El **mes** (`nuevo_mes`) cierra un
**balance mensual** (ingresos − gastos) que alimenta el objetivo de eficiencia. *(Calendario semanal de
Tiempo #1: cada jornada = 1 semana; el **mes = 4 jornadas**, así el objetivo mensual cierra cada 4
jornadas.)* Economía **no define** el
objetivo de ascenso (lo poseen Ascensos/Métricas); solo aporta el balance.

**E7 · Retorno DGP data-driven.** `retorno_DGP(sat)` usa `retorno_dgp_min/max` (semilla en Datos) y la
**satisfacción** (0–100) de Paciencia y Satisfacción (#10). Economía **posee la fórmula**; Datos los
params; Paciencia la satisfacción. `sat` = `sat_cierre_doc` (media cerrada de Documentación de la **jornada
anterior**, Paciencia F3) → el retorno es **fijo durante toda la jornada** y solo cambia al pasar de día.

**E8 · Todo el dinero es data-driven.** Ninguna cifra se hardcodea. `caja_inicial_eur`,
`interes_deuda_diario`, `deuda_max_eur`, `importe_prestamo_eur`, `penalizacion_fija_prestamo`,
`pct_ingreso_prestamo`, `num_prestamos_max`, `ventana_gracia_insolvencia_horas` y los umbrales son
**tuning de Economía**; tarifas, costes, salarios y peonada se **leen de Datos**.

**E9 · Préstamo del Comisario (salvavidas con coste, devolución — y game over).** Cuando andas apurado de
caja, puedes **pedir un préstamo a tu superior, el Comisario**: inyecta `importe_prestamo_eur` (1500) al
saldo al instante. El juego lleva dos contadores:
- **`prestamos_usados`** (histórico, nunca baja): cuántos has pedido **en toda la partida**. Es el que fija
  el límite (`num_prestamos_max` = 3) y el que decide el game over. Es el **"strike"** — *un strike es
  exactamente un préstamo usado; no se recupera al devolverlo.*
- **`prestamos_vivos`** (0…usados): cuántos siguen **sin saldar**. Es el que genera el coste diario.

**Coste de un préstamo vivo** (mientras no lo saldes):
- una **penalización diaria híbrida** = una **parte fija** (`penalizacion_fija_prestamo`, 30 €) **+** una
  **mordida sobre tus ingresos** de Documentación de ese día (`pct_ingreso_prestamo`, 20 %), **por cada
  préstamo vivo** (ver F8). *El Comisario "se lleva su parte" mientras le debas el favor; la mordida %
  auto-escala con tu actividad (días malos, poco; días buenos, más).*
- **baja tu valoración de jefes** *(métrica provisional — sistema futuro ligado a Presión e Influencia #16 /
  Métricas; en el MVP es solo un hook)*.

**Devolución (saldar el favor).** Puedes **devolver el principal** (`importe_prestamo_eur`, 1500 €) cuando
tengas caja: `prestamos_vivos −= 1` y **ese préstamo deja de pesar** (se acaba su parte fija y su mordida %).
El **strike NO se recupera** (`prestamos_usados` no baja): has gastado un salvavidas para siempre. *Da una
meta de recuperación clara: ahorrar para quitarte el lastre.*

**Rescate al tocar el suelo de insolvencia** (`saldo_eur ≤ −deuda_max_eur`):
- Si **quedan préstamos** (`prestamos_usados < num_prestamos_max`): el juego **se pausa** y el Comisario
  ofrece un préstamo por **modal**. Si **aceptas**, se inyecta (con su coste). Si **rechazas**, dispones de
  una **ventana de gracia de `ventana_gracia_insolvencia_horas` (12 h de juego)** para remontar por tus
  medios (que entren ingresos y el saldo suba por encima de `−deuda_max_eur`). Si al terminar la ventana
  **sigues** en el suelo, el préstamo **se inyecta automáticamente** con un aviso del Comisario (gasta 1
  préstamo). Si durante la ventana **sales** del suelo, se cancela el rescate y vuelves a "números rojos".
- Si **NO quedan préstamos** (`prestamos_usados = num_prestamos_max`): **game over — te echan de la
  comisaría** (sin modal ni gracia).

*El game over es una derrota terminal, distinta de fallar un objetivo (que sigue siendo blando: se
reintenta).* *(Pedir préstamos de forma preventiva es válido pero gasta strikes: agotar los 3 deja el
siguiente toque del suelo sin red → game over. La UI lo telegrafía; ver UI/Edge Cases.)*

### States and Transitions

El `saldo_eur` deriva un **estado financiero** (para UI y reglas), que transiciona solo al cruzar umbrales:

| Estado | Condición | Comportamiento | Señal al entrar |
|--------|-----------|----------------|-----------------|
| **Positivo** | `saldo_eur ≥ 0` | Normal; gasto voluntario permitido; puedes **saldar préstamos** vivos si tienes caja | `saldo_cambiado` |
| **Números rojos (deuda)** | `−deuda_max_eur < saldo_eur < 0` | Recargo diario (sobre deuda de apertura); gasto voluntario **bloqueado**; puedes pedir **préstamo** (E9); aviso | `entro_en_deuda` / `salio_de_deuda` |
| **Insolvencia (en gracia)** | `saldo_eur ≤ −deuda_max_eur` **y** el jugador rechazó el modal, **con** préstamos disponibles | Cuenta atrás de `ventana_gracia_insolvencia_horas` (12 h); sigue el recargo; si sube por encima del suelo → vuelve a "Números rojos"; si expira → rescate automático | `insolvencia` / `gracia_iniciada` |
| **Insolvencia (resuelta)** | `saldo_eur ≤ −deuda_max_eur` (al cruzar el suelo o al expirar la gracia) | Si quedan préstamos → **rescate del Comisario** (pausa+modal / auto tras gracia: préstamo, strike, −valoración jefes). Sin préstamos → **GAME OVER (te echan)** | `prestamo_pedido` / `game_over` |

*(Matiz de UI: dentro de "Positivo" la HUD puede colorear "holgado" vs "justo" con un umbral cosmético
`umbral_holgura_ui` — no es un estado del sistema.)* El catálogo económico es **estático**; el que cambia
es el **saldo** (instancia de partida) y los contadores `prestamos_usados`/`prestamos_vivos`. Las
transiciones las disparan ingresos/gastos al cruzar 0 o `−deuda_max_eur`; nunca hay salto retroactivo (se
evalúa al aplicar cada movimiento). **Al cruzar el suelo, el juego se pausa y ofrece el modal de rescate**
(E9): la única forma de quedar `≤ −deuda_max_eur` sin resolver es durante la ventana de gracia.

### Interactions with Other Systems

| Sistema | Qué le da / le pide Economía | Dueño de la interfaz |
|---------|------------------------------|----------------------|
| **Datos y Configuración** | *lee* `tarifa_eur`, costes, `salario_dia_eur`, `peonada_eur_hora`, `retorno_dgp_min/max` | Datos posee valores; Economía la fórmula/rangos |
| **Tiempo** | *escucha* `nuevo_dia` (cobra salarios/peonadas/recargo) y `nuevo_mes` (cierra balance) | Tiempo provee la fecha |
| **Flujo de Personas y Colas** | *escucha* "trámite completado" → abona ingreso al instante | Flujo emite el evento; Economía acredita |
| **Paciencia y Satisfacción (#10)** | *lee* `sat_cierre_doc` (media cerrada de la jornada anterior) para el retorno DGP ✅ GDD | Paciencia posee la satisfacción |
| **Personal / Agentes** | provee el **gate** "¿puedo contratar?" (E4) y cobra sus salarios diarios | Personal posee la dotación |
| **Construcción** | provee el **gate** "¿puedo construir?" (E4), descuenta el coste al colocar y **reembolsa un %** al demoler (F4 de #7) | Construcción posee la colocación |
| **Documentación** | fuente de **ingresos** (sus trámites) | Documentación posee su operativa |
| **ODAC** | **coste** (salarios) + reputación; **no** ingreso | ODAC posee su operativa |
| **Ascensos / Métricas** | provee el **balance mensual** para el objetivo de eficiencia | Ascensos posee el objetivo |
| **UI / HUD** | expone `saldo_eur`, estado financiero, ingresos/gastos del día | UI presenta |
| **Guardado y Carga** | serializa/restaura `saldo_eur` y el estado de deuda | Guardado serializa |

*(Provisionales hasta que existan sus GDDs: Flujo, Paciencia, Personal, Construcción, Documentación, ODAC,
Ascensos, Horarios.)*

## Formulas

> Los valores de tarifas/costes/salarios los **posee Datos** (aquí solo se componen); las cifras **nuevas**
> (caja inicial, interés, límite de deuda) son **tuning de Economía**, provisionales, a validar en el 1er
> playtest (Datos Open Q#3).

**F1 · Retorno DGP** *(fórmula propiedad de Economía; ya referenciada por Datos F8)*
`retorno_DGP(sat) = retorno_dgp_min + (retorno_dgp_max − retorno_dgp_min) × (clamp(sat, 0, 100) / 100)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `sat` | float | 0–100 | `sat_cierre_doc`: media cerrada de Documentación de la **jornada anterior** (Paciencia #10 F3) |
| `retorno_dgp_min` | float | 0.15 | Suelo fijo (Datos) |
| `retorno_dgp_max` | float | 0.45 | Techo a satisfacción 100% (Datos) |

**Salida:** 0.15–0.45. **Ejemplos:** sat 0 → 0.15 · sat 50 → **0.30** · sat 100 → 0.45.

**F2 · Ingreso por trámite (instantáneo)**
`ingreso_comisaria = tarifa_eur × retorno_DGP(sat)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `tarifa_eur` | float | ≥ 0 | Tasa oficial del trámite (Datos: DNI 12 · Pas 30 · TIE 18) |
| `retorno_DGP` | float | 0.15–0.45 | De F1 |

**Salida:** DNI 1,8–5,4 € · Pasaporte 4,5–13,5 € · TIE 2,7–8,1 €. **Ejemplo:** DNI a sat 50% = `12 × 0,30 = 3,6 €`.

**F3 · Salarios diarios** (al `nuevo_dia`)
`gasto_salarios_dia = Σ salario_dia_efectivo de cada agente contratado`
donde `salario_dia_efectivo` = salario base (Datos) × prima por atributos/rango (**Personal F1**).
**Ejemplo (agentes estándar):** 2×`ag_doc`(base 60) + 1×`ag_odac`(base 70) = **190 €/día**; con mejores
atributos o rango Oficial, más (Personal F1).

**F4 · Peonada** (hora extra; `horas_extra` lo posee Horarios/Personal — provisional)
`gasto_peonada = peonada_eur_hora × horas_extra`
**Ejemplo:** 3 h extra = `15 × 3 = 45 €`.

**F5 · Recargo de deuda** (al `nuevo_dia`, **al inicio del cierre**, solo si el saldo de apertura es `< 0`)
`recargo_deuda = |saldo_apertura| × interes_deuda_diario`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `saldo_apertura` | float | < 0 | La deuda que arrastras al llegar el cierre (antes de los gastos de hoy) |
| `interes_deuda_diario` | float | 0.02 | Recargo diario (tuning Economía) |

**Salida:** aumenta la deuda. **Ejemplo:** deuda 500 € → `+10 €/día`. **Clave (orden, ver F6):** el recargo
se calcula **antes** de aplicar la nómina/penalización de hoy, sobre la deuda de apertura. Así, si hoy
entras en rojo por la nómina, ese déficit **no** genera recargo hasta mañana (satisface AC-E09 y AC-E10).

**F6 · Actualización del saldo**
- Durante el día (instantáneo):
  - Al completar un trámite: `saldo_eur += ingreso_comisaria` (y `ingreso_doc_dia += ingreso_comisaria`)
  - Al pedir un préstamo (E9): `saldo_eur += importe_prestamo_eur`; `prestamos_usados += 1`; `prestamos_vivos += 1`
  - Al saldar un préstamo (E9, solo si `saldo_eur ≥ importe_prestamo_eur` y `prestamos_vivos > 0`):
    `saldo_eur −= importe_prestamo_eur`; `prestamos_vivos −= 1` *(no toca `prestamos_usados`)*
- Al cierre de día (`nuevo_dia`), en **orden determinista**:
  1. **Recargo** (F5): `si saldo_eur < 0: saldo_eur −= |saldo_eur| × interes_deuda_diario` *(sobre la deuda de apertura, antes de los gastos de hoy)*
  2. **Gastos del día**: `saldo_eur −= (gasto_salarios_dia + gasto_peonada_dia + penalizacion_prestamos_dia)`
  3. **Reinicio**: `ingreso_doc_dia = 0` para el siguiente día

**F7 · Balance mensual** (al `nuevo_mes`; lo consume Ascensos)
`balance_mes = ingresos_mes − gastos_mes`

**F8 · Penalización diaria por préstamos vivos** (al `nuevo_dia`, si `prestamos_vivos > 0`)
`penalizacion_prestamos_dia = prestamos_vivos × (penalizacion_fija_prestamo + pct_ingreso_prestamo × ingreso_doc_dia)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `prestamos_vivos` | int | 0–3 | Préstamos sin saldar (F6) |
| `penalizacion_fija_prestamo` | float | 30 | Parte fija por préstamo vivo/día (tuning Economía) |
| `pct_ingreso_prestamo` | float | 0.20 | Mordida sobre los ingresos de Documentación del día, por préstamo vivo (tuning Economía) |
| `ingreso_doc_dia` | float | ≥ 0 | Suma de ingresos de Documentación acreditados ese día (se reinicia al cierre) |

**Ejemplo** (ingreso del día `ingreso_doc_dia = 230 €`):
- 1 préstamo vivo → `1 × (30 + 0.20 × 230) = 30 + 46 = 76 €/día`.
- 3 préstamos vivos → `3 × (30 + 0.20 × 230) = 90 + 138 = 228 €/día` *(casi el 100 % de los ingresos de arranque: el 3.º préstamo es prácticamente terminal si no creces)*.
- Un día flojo (`ingreso_doc_dia = 50 €`), 1 vivo → `30 + 0.20 × 50 = 40 €/día` *(la mordida % auto-escala: en días malos pesa menos, no te remata)*.

**Valores semilla nuevos (tuning de Economía — provisionales, a validar en playtest):**

| Knob | Semilla | Razonamiento |
|------|--------:|-------------------------------------------------|
| `caja_inicial_eur` | 3000 | Monta una oficina inicial modesta (~2 puestos Doc + 1 ODAC + 2 salas ≈ 2000 €) + colchón de unos días; no permite construirlo todo de golpe. **Ojo pacing real:** con ODAC obligatorio (1 `ag_odac` = 70 €/día, sin ingreso) el neto de arranque **no** es ~110 €/día (2 puestos Doc − 2 salarios Doc) sino **~40 €/día** (≈230 ingreso − 60×2 − 70), así que ahorrar un puesto (500 €) son **~12 días**, no 4–5. El colchón de 3000 cubre ese arranque más lento; valor a confirmar en playtest (Open Q#3) |
| `interes_deuda_diario` | 0.02 | 2 %/día sobre la deuda de apertura: presiona sin espiral brutal |
| `deuda_max_eur` | 1000 | ~9 días de un déficit de ~110 €/día antes de escalar |
| `umbral_holgura_ui` | 500 | Cosmético: por debajo, la HUD muestra "justo" |
| `importe_prestamo_eur` | 1500 | Efectivo del rescate **y** coste de saldarlo (E9). ~medio arranque / varios días de margen |
| `penalizacion_fija_prestamo` | 30 | Parte **fija** del coste por préstamo vivo/día (F8). Se nota incluso en días de bajo ingreso (componente que no auto-escala → no subirla en exceso) |
| `pct_ingreso_prestamo` | 0.20 | Parte **%**: mordida sobre los ingresos de Documentación del día, por préstamo vivo (F8). Auto-escala con la actividad; 3 vivos = 60 % de tus ingresos |
| `num_prestamos_max` | 3 | Salvavidas máximos **en toda la partida** (sobre `prestamos_usados`; devolver no lo recupera). Caer en insolvencia con los 3 gastados = game over |
| `ventana_gracia_insolvencia_horas` | 12 | Horas de juego para remontar tras rechazar el modal de rescate antes de la inyección automática (E9) |

## Edge Cases

- **Si un trámite se completa con satisfacción fuera de [0,100]** (dato corrupto de Paciencia): se **clampa
  a [0,100]** antes de F1; el retorno nunca sale de [0.15, 0.45]. *Un dato corrupto no debe dar retornos
  imposibles.*
- **Si el jugador intenta construir/contratar sin caja** (`saldo < coste`): la acción se **rechaza** (botón
  deshabilitado + aviso), el saldo no baja. *E4: no te endeudas con gasto voluntario.*
- **Si al cierre de día la nómina deja el saldo negativo:** se **permite** (entras en números rojos), se
  aplica recargo **desde el día siguiente** (F5: el recargo va sobre la deuda de apertura, no sobre el
  déficit creado hoy) y se bloquea el gasto voluntario. *E5: la nómina es obligatoria.*
- **Si el saldo toca el suelo de insolvencia (`≤ −deuda_max_eur`) y quedan préstamos:** el juego **se
  pausa** y el Comisario ofrece un préstamo por **modal**. *Aceptar* → se inyecta (+efectivo, +strike,
  −valoración jefes, +préstamo vivo). *Rechazar* → arranca la **ventana de gracia** (12 h de juego). *E9.*
- **Si durante la ventana de gracia el saldo sube por encima del suelo** (entran ingresos): se **cancela el
  rescate**, la partida vuelve a "números rojos" normal y no se gasta préstamo. *Premia remontar por tus
  medios.*
- **Si la ventana de gracia expira y el saldo sigue `≤ −deuda_max_eur`:** se **inyecta el préstamo
  automáticamente** con aviso del Comisario (gasta 1 préstamo). *E9: no hay estado zombi bajo el suelo.*
- **Si toca la insolvencia y NO quedan préstamos (`prestamos_usados = 3`):** **game over** — te echan, sin
  modal ni gracia. *E9: derrota terminal.* *(Aunque hayas devuelto préstamos: el límite es sobre
  `prestamos_usados`, que no baja.)*
- **Si el jugador pide un préstamo estando en positivo** (uso preventivo): se **permite**, gasta un strike
  igualmente. *El salvavidas es suyo; adelantarlo es su decisión y su coste. Agotar los 3 así deja el
  siguiente toque del suelo sin red → game over: la UI avisa al pedir el último (ver UI Requirements).*
- **Si el jugador salda un préstamo** (devuelve 1500 € teniendo caja): `prestamos_vivos −= 1` y ese préstamo
  **deja de pesar** (cesan su parte fija y su mordida %); el **strike no se recupera** (`prestamos_usados`
  no baja). *E9: la devolución quita el lastre, no el salvavidas gastado.*
- **Si el jugador intenta saldar un préstamo sin caja suficiente** (`saldo_eur < importe_prestamo_eur`) o
  sin préstamos vivos: la acción se **rechaza** (botón deshabilitado). *No puedes devolver lo que no
  tienes.*
- **Si se falla el objetivo mensual** (balance insuficiente): **NO es game over** — se reintenta el ciclo.
  Solo la insolvencia sin préstamos es terminal. *Distinción clave: objetivo blando vs quiebra dura.*
- **🔑 Regla de cierre de servicio (última admisión):** si Documentación llega a su hora de cierre (p. ej.
  14:30) con ciudadanos **ya admitidos / en cola**, NO se les expulsa: el personal los **termina** aunque
  salga más tarde (genera **peonada**, F4), y solo se cierra la puerta a **nuevas** llegadas. *Evita dejar
  gente tirada (fallo visto en el prototipo HTML) y castigar la satisfacción injustamente. Dueños:
  Documentación (última admisión), Flujo (vaciar cola), Horarios/Personal (hora extra); Economía solo
  registra el coste* → **Open Question** para esos GDDs.
- **Si varios movimientos caen en el mismo instante** (trámites completados + cierre de día): se aplican en
  **orden determinista** — ingresos del frame (durante el día) → cierre de día: **(1) recargo de deuda**
  (sobre la deuda de apertura) → **(2) gastos** (salarios/peonada/penalización de préstamos vivos) → **(3)
  reinicio de `ingreso_doc_dia`**. *Determinismo del saldo; el recargo va antes de los gastos de hoy (F6).*
- **Si se carga una partida:** `saldo_eur`, `prestamos_usados`, `prestamos_vivos` y el estado de deuda/gracia
  se **restauran tal cual**; no se re-disparan cobros retroactivos. *Cargar sitúa, no reproduce (coherente
  con Tiempo).*
- **Si un knob llega fuera de rango** (negativo): se **clampa a mínimo seguro** (caja ≥ 0;
  `num_prestamos_max` entero ≥ 0; `interes_deuda_diario`, `penalizacion_fija_prestamo`,
  `pct_ingreso_prestamo`, `ventana_gracia_insolvencia_horas` ≥ 0) con aviso. *Dato corrupto no rompe la
  economía (igual patrón que Datos/Tiempo).*
- **Si `num_prestamos_max = 0`:** no hay salvavidas — el primer toque del suelo de insolvencia es **game
  over inmediato** (sin modal ni gracia). *Coherente con el límite; es una configuración válida (modo
  difícil).*

## Dependencies

**Este sistema depende de:**

| Sistema | Tipo | Interfaz (qué lee/escucha) |
|---------|------|-----------------------------|
| **Datos y Configuración** | Hard | *lee* `tarifa_eur`, costes, `salario_dia_eur`, `peonada_eur_hora`, `retorno_dgp_min/max` por `id` (✅ GDD) |
| **Tiempo** | Hard | *escucha* `nuevo_dia` (cobros diarios) y `nuevo_mes` (balance) (✅ GDD) |
| **Flujo de Personas y Colas** | Hard | *escucha* "trámite completado" → dispara el ingreso *(provisional)* |
| **Paciencia y Satisfacción (#10)** | Hard | *lee* `sat_cierre_doc` (media cerrada de la jornada anterior, 0–100) para F1 ✅ GDD; 1ª jornada = `sat_inicial` 50 |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Personal / Agentes** | Hard | gate "¿puedo contratar?" (E4) + cobro de salarios |
| **Construcción y Distribución** | Hard | gate "¿puedo construir?" (E4) + descuento del coste al colocar |
| **Documentación** | Hard | sus trámites generan el ingreso (vía Flujo) |
| **ODAC / Denuncias** | Soft | consume salarios (coste), **no** ingreso |
| **Ascensos / Métricas** | Hard | balance mensual para el objetivo de eficiencia |
| **Horarios y Peonadas** *(V-Slice)* | Hard | coste de peonada (horas extra) |
| **Valoración de jefes** *(futuro — a mapear)* | Hard | préstamos y objetivos fallidos la bajan *(hook provisional)* |
| **UI / HUD** | Hard | muestra `saldo_eur`, estado financiero, ingresos/gastos del día, botón de préstamo |
| **Guardado y Carga** | Hard | serializa `saldo_eur`, `prestamos_usados`, estado de deuda |

**Consistencia bidireccional:** cuando se escriba cada GDD dependiente, deberá listar "depende de: Economía".
*(Ninguno tiene GDD aún → referencia inversa provisional. Además: `systems-index.md` debe añadir **Tiempo** a
las dependencias de Economía — ajuste pendiente en el índice.)*

## Tuning Knobs

| Knob | Default | Rango seguro | Si ↑ / Si ↓ |
|------|--------:|--------------|-------------|
| `caja_inicial_eur` | 3000 | ≥ 0 | ↑ arranque más holgado (menos presión temprana) / ↓ más apretado |
| `interes_deuda_diario` | 0.02 | 0 – 0.10 | ↑ la deuda asfixia antes / ↓ más benévola |
| `deuda_max_eur` | 1000 | ≥ 0 | ↑ más margen antes del rescate/insolvencia / ↓ menos colchón |
| `importe_prestamo_eur` | 1500 | ≥ 0 | ↑ rescates más generosos (y más caros de saldar) / ↓ más justos |
| `penalizacion_fija_prestamo` | 30 | ≥ 0 | ↑ los préstamos pesan más incluso en días flojos (riesgo de espiral) / ↓ más baratos |
| `pct_ingreso_prestamo` | 0.20 | 0 – 0.50 | ↑ el Comisario se lleva más de tus ingresos por préstamo / ↓ mordida más suave |
| `num_prestamos_max` | 3 | entero ≥ 0 | ↑ más salvavidas (game over más lejano) / ↓ menos margen (0 = game over al primer suelo) |
| `ventana_gracia_insolvencia_horas` | 12 | ≥ 0 | ↑ más tiempo para remontar antes del rescate auto / ↓ menos (0 = rescate/game over inmediato al rechazar) |
| `umbral_holgura_ui` | 500 | ≥ 0 | Cosmético (color "holgado" vs "justo" en HUD) |

**Referenciados (dueño externo — NO se duplican):** `tarifa_eur`, costes de construcción, `salario_dia_eur`,
`peonada_eur_hora`, `retorno_dgp_min/max` (**Datos**); `escala_tiempo`, límites de turno (**Tiempo**).

**Interacciones entre knobs (cuidado):**
- **`caja_inicial_eur` × costes (Datos)** definen cuánto puedes construir de salida (objetivo: una oficina
  modesta, no todo). *Contar el coste obligatorio de ODAC al calibrar (ver razonamiento de la tabla).*
- **`interes_deuda_diario` × `deuda_max_eur`** definen cuánto aprieta la deuda y cuánto tardas en tocar
  insolvencia. *Cuidado con `interes_deuda_diario` alto (p. ej. 0.10): cerca del suelo, un solo día puede
  saltar de números rojos a insolvencia (recargo ≈ 100 €/día con deuda de 1000).*
- **`penalizacion_fija_prestamo` (no escala) vs `pct_ingreso_prestamo` (auto-escala):** la parte fija es la
  "peligrosa" — te la cobran igual los días de bajo ingreso, que es cuando pediste el préstamo. Para que el
  préstamo "se note" sin espiral de muerte, apóyate más en el **%** que en la fija.
- **`importe_prestamo_eur` × penalización (fija + %) × `num_prestamos_max`** definen la dureza del salvavidas
  y la distancia al game over. Como el préstamo se **devuelve** (E9), `importe_prestamo_eur` es a la vez el
  rescate y su coste de saldar: subirlo da más aire pero encarece quitarse el lastre.
- **`retorno_dgp_*` × tarifas (Datos)** gobiernan el ritmo de ingreso — no son knobs de Economía (los posee
  Datos), pero Economía posee la fórmula F1 que los usa, y `pct_ingreso_prestamo` muerde sobre ese ingreso.

**Restricciones:** `interes_deuda_diario`, `penalizacion_fija_prestamo`, `pct_ingreso_prestamo`,
`caja_inicial_eur`, `importe_prestamo_eur`, `deuda_max_eur`, `ventana_gracia_insolvencia_horas` ≥ 0;
`num_prestamos_max` entero ≥ 0; `prestamos_vivos ≤ prestamos_usados ≤ num_prestamos_max`.

## Visual/Audio Requirements

Economía no produce arte propio, pero **declara feedback** (lo sonoriza/anima Feedback/Audio):
- **Ingreso** (caja sube): tintineo corto + contador que sube con destello sutil. *Ata "buen servicio →
  dinero".* Prioridad media.
- **Gasto** (construir/contratar/nómina): sonido de descuento + saldo baja con breve parpadeo.
- **Números rojos / entrar en deuda**: saldo en **color de alerta** + aviso sonoro sobrio.
- **Préstamo del Comisario**: momento con peso (aviso serio del Comisario) + marca de "strike".
- **Game over (te echan)**: sting + pantalla de fin **seria** (no caricaturesca; según art bible).
- **Cierre de mes (balance)**: resumen con sonido de "informe".

Estilo según **art bible** (2D limpio, serio). Audio real lo sonoriza Feedback/Audio.

> 📌 **Asset Spec** — Tras aprobar el art bible se puede ejecutar `/asset-spec system:economy-budget` para
> los assets de feedback económico (iconos €/estado, sting de game over).

## UI Requirements

Economía alimenta el HUD (la UI **nunca hardcodea** cifras, las lee):
- **Indicador de saldo (€)** siempre visible, con **color por estado** (holgado / justo / números rojos).
- **Ingresos/gastos del día** (resumen) y **balance mensual** al cierre. El resumen de gastos **desglosa la
  penalización de préstamos** (fija + mordida %) para que el jugador vea qué le cuesta el favor.
- **Acción de préstamo**: botón con **préstamos restantes** (`num_prestamos_max − prestamos_usados`) y su
  coste (importe + penalización fija + % de ingresos). **Telegrafía obligatoria:** al pedir el **último**
  préstamo, confirmación explícita ("es tu último salvavidas: si vuelves a la insolvencia, te echan"); al
  quedar a **0 restantes**, aviso persistente de "sin red".
- **Acción de saldar préstamo**: botón (habilitado solo si `saldo ≥ importe_prestamo_eur` y
  `prestamos_vivos > 0`) que muestra cuántos préstamos siguen **vivos** y el coste de saldar uno.
- **Rescate de insolvencia**: modal del Comisario (pausa) con Aceptar/Rechazar; si se rechaza, **contador
  visible de la ventana de gracia** (12 h de juego) hasta la inyección automática.
- **Avisos**: entrada en deuda, insolvencia (modal), rescate automático, game over.

> **📌 UX Flag — Economía**: el HUD financiero (saldo, estado, préstamo, balance) se diseña con
> `/ux-design` en Pre-Producción, **antes** de escribir epics. Las stories de UI citan `design/ux/hud.md`,
> no este GDD.

## Acceptance Criteria

> Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre sistemas). *qa-lead no consultado
> (error "1M context"); lente qa aplicada en el hilo principal.*

**Ingresos (E2, F1, F2)**
- **AC-E01** `[Unit]` — GIVEN `dni` (tarifa 12) y `sat=50` WHEN se completa el trámite THEN `saldo_eur += 3,6` (12×0.30) **al instante**.
- **AC-E02** `[Unit]` — GIVEN `sat=0` THEN `retorno_DGP=0.15`; GIVEN `sat=100` THEN `0.45` (extremos de F1).
- **AC-E03** `[Unit]` — GIVEN `sat=150` (fuera de rango) WHEN F1 THEN se clampa a 100 → retorno `0.45` (no supera el techo).
- **AC-E04** `[Integration]` — GIVEN un trámite **ODAC** completado THEN `saldo_eur` **NO** cambia (ODAC no genera ingreso).

**Gastos (E3, F3, F4)**
- **AC-E05** `[Unit]` — GIVEN 2×`ag_doc`(60) + 1×`ag_odac`(70) contratados WHEN `nuevo_dia` THEN `saldo_eur −= 190`.
- **AC-E06** `[Unit]` — GIVEN 3 h extra a `peonada=15` THEN `gasto_peonada = 45`.

**Gate de gasto voluntario (E4)**
- **AC-E07** `[Integration]` — GIVEN `saldo=400` WHEN se intenta construir un puesto de 500 THEN se **rechaza** y el saldo sigue 400.
- **AC-E08** `[Integration]` — GIVEN `saldo=600` WHEN se construye un puesto de 500 THEN `saldo=100`.

**Deuda y recargo (E5, F5, F6)**
- **AC-E09** `[Unit]` — GIVEN `saldo=50` y nómina 190 WHEN `nuevo_dia` THEN `saldo=−140` (entra en números rojos) y el gasto voluntario queda **bloqueado**. *(El recargo NO se aplica el día de entrada: el saldo de apertura era +50.)*
- **AC-E10** `[Unit]` — GIVEN el día entra con `saldo=−500`, sin obligaciones ese día, `interes=0.02` WHEN `nuevo_dia` THEN recargo `=10` (sobre la deuda de apertura) → `saldo=−510`.
- **AC-E10b** `[Unit]` — GIVEN dos `nuevo_dia` consecutivos entrando con `saldo=−500` y sin obligaciones, `interes=0.02` WHEN se procesan THEN día 1 → `−510`; día 2 → `−520.20` (recargo compuesto sobre `−510`). *(El recargo se acumula a la deuda.)*
- **AC-E10c** `[Unit]` — GIVEN el día entra con `saldo=+20`, nómina 190, `interes=0.02` WHEN `nuevo_dia` THEN orden: recargo=0 (apertura ≥ 0) → gastos → `saldo=−170`; **no** hay recargo sobre los `−170` hasta el día siguiente. *(Orden determinista de F6: recargo antes de gastos.)*

**Préstamo e insolvencia (E9, F6, F8)**
- **AC-E11** `[Integration]` — GIVEN `prestamos_usados=0` WHEN se pide un préstamo THEN `saldo += 1500`, `prestamos_usados=1`, `prestamos_vivos=1`, y se dispara el hook "−valoración jefes".
- **AC-E12** `[Unit]` — GIVEN `prestamos_vivos=2`, `ingreso_doc_dia=230`, `penalizacion_fija=30`, `pct_ingreso=0.20` WHEN `nuevo_dia` THEN penalización `= 2 × (30 + 0.20×230) = 152` descontados.
- **AC-E12b** `[Unit]` — GIVEN `prestamos_vivos=1`, `ingreso_doc_dia=0` (día sin ingresos), `penalizacion_fija=30`, `pct_ingreso=0.20` WHEN `nuevo_dia` THEN penalización `= 30` (solo la parte fija; la mordida % es 0). *(La parte % auto-escala.)*
- **AC-E13** `[Integration]` — GIVEN `saldo ≤ −1000` y `prestamos_usados=3` WHEN se cruza el suelo THEN **game over** (te echan), sin modal ni gracia.
- **AC-E14** `[Integration]` — GIVEN `saldo ≤ −1000` y `prestamos_usados<3` WHEN se cruza el suelo THEN el juego **se pausa** y ofrece el modal de rescate; **NO** game over todavía.

**Rescate: modal, gracia y game over (E9, States)**
- **AC-E14a** `[Integration]` — GIVEN el modal de rescate y `prestamos_usados=1` WHEN el jugador **acepta** THEN `saldo += 1500`, `prestamos_usados=2`, `prestamos_vivos+1`, y sale del suelo.
- **AC-E14b** `[Integration]` — GIVEN el modal y el jugador **rechaza** WHEN pasan `ventana_gracia_insolvencia_horas`=12 h de juego **sin** salir del suelo THEN se inyecta el préstamo **automáticamente** con aviso (gasta 1 préstamo).
- **AC-E14c** `[Integration]` — GIVEN el jugador rechazó y está en la ventana de gracia WHEN entran ingresos que suben el saldo **por encima** de `−1000` antes de expirar THEN se **cancela** el rescate (no se gasta préstamo) y vuelve a "números rojos".
- **AC-E14d** `[Integration]` — GIVEN `num_prestamos_max=0` WHEN el saldo cruza el suelo por primera vez THEN **game over inmediato** (sin modal ni gracia).
- **AC-E14e** `[Integration]` — GIVEN el jugador pidió 3 préstamos preventivos en positivo (`prestamos_usados=3`) WHEN más tarde el saldo cruza el suelo THEN **game over** (agotó la red). *(Preventivo gasta strikes.)*

**Devolución de préstamo (E9, F6)**
- **AC-E14f** `[Integration]` — GIVEN `prestamos_usados=2`, `prestamos_vivos=2`, `saldo=1600` WHEN el jugador salda un préstamo THEN `saldo=100`, `prestamos_vivos=1`, `prestamos_usados=2` (el strike **no** se recupera).
- **AC-E14g** `[Integration]` — GIVEN `prestamos_vivos=1` que se salda WHEN el siguiente `nuevo_dia` THEN la penalización de ese préstamo **ya no se aplica** (dejó de estar vivo).
- **AC-E14h** `[Integration]` — GIVEN `saldo=1400` (`< importe_prestamo_eur`) o `prestamos_vivos=0` WHEN se intenta saldar THEN la acción se **rechaza** (botón deshabilitado); el saldo no cambia.

**Objetivo vs game over (E5/E9)**
- **AC-E15** `[Integration]` — GIVEN balance mensual insuficiente pero `saldo > −1000` THEN objetivo **fallido** pero **NO** game over (se reintenta el ciclo).

**Ciclo (E6, F7) y data-driven (E8)**
- **AC-E16** `[Unit]` — GIVEN `ingresos_mes=3000`, `gastos_mes=2600` WHEN `nuevo_mes` THEN `balance_mes=+400`.
- **AC-E17** `[Unit]` — GIVEN se edita `caja_inicial_eur=5000` (sin tocar código) WHEN nueva partida THEN saldo inicial `=5000`.

**Carga y determinismo (Edge Cases)**
- **AC-E18** `[Unit]` — GIVEN un save con `saldo=−300`, `prestamos_usados=2` y `prestamos_vivos=1` WHEN se carga THEN se restauran −300, 2 y 1, **sin** cobros retroactivos.
- **AC-E19** `[Unit]` — GIVEN la misma secuencia de movimientos aplicada dos veces desde idéntico estado THEN el `saldo_eur` final es **idéntico** (determinismo).

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | Modelo exacto **satisfacción → retorno DGP**: valores `retorno_dgp_min/max` y forma de la curva (interfaz con Paciencia #10 **resuelta**: `sat` = `sat_cierre_doc`, media cerrada de la jornada anterior) | Economía + Satisfacción (#10) | Balance / playtest | ✅ Interfaz resuelta; valores a playtest |
| 2 | **Objetivo mensual**: ¿de balance €, de satisfacción, o mixto? ¿Cómo se traduce en ascenso? | Economía + Ascensos | GDD Ascensos + playtest | Abierta |
| 3 | **Valores semilla económicos** (caja 3000 · interés 0.02 · deuda_max 1000 · préstamo 1500 · **fija préstamo 30 · % préstamo 0.20** · nº préstamos 3 · **gracia 12 h**) a validar — incluye el pacing real con ODAC obligatorio | Balance / playtest | 1er playtest MVP | Abierta |
| 4 | **Rescate al tocar el suelo** — **RESUELTA** (/design-review 2026-07-19): pausa + modal; rechazar → 12 h de gracia → inyección automática con aviso; sin préstamos → game over. Ver E9/States. | Economía + UX | — | ✅ Resuelta |
| 5 | **"Valoración de jefes"** (reputación con superiores): sistema nuevo a mapear — qué la sube/baja, rango, y cómo afecta (¿retorno? ¿ascensos? ¿eventos?) | Presión e Influencia #16 / Métricas | Mapear + GDD #16 | Abierta |
| 6 | **Canales por rango**: subvenciones, bonus DGP y nuevas partidas de gasto al ascender (Comisario+) | Ascensos #18 / Escalado #26 | GDDs #18/#26 | Abierta |
| 7 | **Regla de cierre (última admisión + peonada)**: cómo la implementan Documentación (última admisión), Flujo (vaciar cola) y Horarios (hora extra) | Documentación + Flujo + Horarios | GDDs respectivos | Abierta |
| 8 | **Peonadas en el MVP**: ¿existen ya (abrir puesto fuera de horario) o solo con Horarios (#13, V-Slice)? | Horarios/Personal + Economía | GDD Documentación/Horarios | Abierta |
| 9 | **Persistencia del saldo**: parte del ADR de formato de datos (comparte con Datos Open Q#8) | Arquitectura (technical-director) | Fase de arquitectura (ADR) | Abierta |
