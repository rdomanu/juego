# Documentación (DNI/Pasaporte/TIE)

> **Status**: In Design
> **Author**: manu.rdo + Claude (hilo principal; lentes game-designer / systems-designer — subagentes caídos por "1M context")
> **Last Updated**: 2026-07-21
> **Last Verified**: 2026-07-21
> **Implements Pillar**: Pilar 1 — "Realismo con alma" + Pilar 4 — "Tu comisaría, tus decisiones"

## Overview

El sistema de **Documentación** es el servicio de **tramitación de documentos nacionales** —**DNI,
Pasaporte y TIE**— que la comisaría presta al ciudadano: la faceta de **Secretaría** del edificio y, en el
MVP, **tu única fuente de ingresos**. No inventa el flujo ni la gente (eso son Flujo y Demanda); lo que
**posee** es la **operativa del servicio**: su **horario de apertura** (base **08:00–14:30**, ampliable con
el slider hasta las **20:00** pagando **peonada** por las horas extra), su **política de cita** (el MVP
arranca **sin cita**), y la **última admisión** (hasta qué minuto se da número antes de cerrar). Cada trámite que se completa **abona el retorno
DGP** (lo cobra Economía), así que Documentación es lo que **da de comer** a la comisaría: sostiene la
nómina —incluida la de ODAC, que no genera un euro—. Configura el comportamiento de otros —fija los
horarios que **Flujo** ejecuta al abrir/cerrar los puestos, la ventana que **Demanda** respeta al generar
ciudadanos— y se apoya en los **agentes `ag_doc`** (Personal) sobre los **puestos** `doc_general`/`tie`
(Construcción).

A nivel de diseño, Documentación es donde el jugador **convierte su servicio público en presupuesto**
(Pilares 1 y 4). El corazón son sus **decisiones de horario**: *"¿abro a las 08:00 y pago la peonada para
captar la cola temprana, o espero a las 09:00? ¿aprieto la última admisión hasta el cierre para rascar más
trámites —aunque mi gente salga tarde y descontenta—, o cierro la puerta 15 minutos antes para que se vayan
a su hora?"* Es la tensión clásica de **exprimir vs cuidar** (el "crunch" de los tycoon), pero medida en
**euros contra moral**. Y como son **trámites reales del CNP** —con sus tasas y sus tiempos—, el servicio se
siente **auténtico** (Pilar 1). Sin esta capa no hay ingresos que sostengan la comisaría, ni el servicio
ciudadano que la justifica.

> **Regla de propiedad:** Documentación **posee** los *horarios de apertura*, la *última admisión*, la
> *política de cita por trámite* y la *operativa* de tramitación de DNI/Pasaporte/TIE. **Lee** de *Datos*
> los trámites (dur/tarifa/`requiere_cita`). **Configura** a *Flujo* (cuándo abrir/cerrar los puestos, hasta
> cuándo admitir) y a *Demanda* (la ventana y la cita). Al completarse un trámite, **Flujo emite**
> `"trámite completado"` → **Economía** abona el retorno DGP. **No posee**: el *flujo de colas* (→ Flujo
> #4), la *generación* de ciudadanos (→ Demanda #5), el *retorno DGP* (→ Economía #3), los *agentes* (→
> Personal #6) ni los *puestos* (→ Construcción #7). *(La **cita previa** como regulador que autolimita la
> demanda es el sistema **#14**, Vertical Slice; el descontento del personal por salir tarde conecta con
> **Personal/Bienestar #13/#15**.)*

## Player Fantasy

**Fantasía:** ser el **jefe de la ventanilla que sostiene la comisaría** — quien decide cómo exprimir el
servicio de documentos para que las cuentas cuadren, **sin quemar a su gente**. La satisfacción de que *"lo
que entra por mi ventanilla paga la casa"* (Pilares 1 y 4).

Se vive en dos capas:

- **Control directo (gestionar el servicio):** decidir el **horario** —¿**alargo la tarde** pagando peonada
  para captar más trámites? ¿aprieto la última admisión hasta el cierre?—, leer el **nivel de demanda**
  (BAJA/MEDIA/ALTA) para saber si la peonada compensa, y sopesar **euros contra moral**. Es la fantasía del
  gestor que optimiza los ingresos de su servicio con decisiones reales.
- **Infraestructura que se vive (la ventanilla trabaja):** abre a su hora, entra la gente, se tramita,
  **entra el goteo de dinero** que sostiene todo —incluida la ODAC que solo cuesta—. El jugador nota que
  **su servicio es el que da de comer**.

**El momento a anclar:** el **apretón del cierre**. Son las 14:15, la última admisión, y hay cinco personas
más asomando por la puerta. *"¿Las admito —más dinero, pero mi gente saldrá tarde y descontenta— o cierro y
que se vayan a su hora?"* Y su gemelo, la **peonada de la tarde**: demanda ALTA, la cola no baja al dar las
14:30; *"¿alargo el horario pagando la peonada para vaciarla —y sacar más—, o cierro a mi hora?"* Esa cuenta
—ingreso contra coste, dinero contra moral— es el corazón del servicio.

**Referencia de sensación:** la gestión de servicio y moral de *Two Point Hospital*, y el **crunch** de
*Software Inc / Game Dev Tycoon* (horas extra = más output, menos moral). **Anti-fantasía:** NO es
**burocracia tediosa** (anti-pilar 1: nada de rellenar formularios sin decisión); NO es **exprimir sin
consecuencia** (la moral pone freno); NO es una **fuente de dinero pasiva** (las decisiones de horario
**importan**). El jugador nunca debe sentir que Documentación *"va sola, sin nada que decidir"*.

*(Nota de proceso: `creative-director` no consultado —modo LEAN + subagentes caídos—; lente creativa
aplicada en el hilo principal.)*

## Detailed Design

### Core Rules

**DO1 · Los trámites del servicio.** Documentación tramita **DNI** (12 min/12€/`doc_general`), **Pasaporte**
(15/30/`doc_general`) y **TIE** (15/18/`tie`) — Datos. Cada trámite completado abona el retorno DGP
(Economía). No inventa trámites; posee su operativa.

**DO2 · La División de Documentación (órgano superior).** Órgano que coordina las unidades de Documentación
de toda España *(ambientación realista, Pilar 1)*. En el juego **fija el horario base y los límites** (DO3)
y **manda eventos** (DO7). Es la voz institucional tras las reglas de horario.

**DO3 · Horario con slider (base 08:00–14:30, ampliable a 20:00).** Horario base fijado por la División:
**L–V 08:00–14:30** (390 min, jornada de mañana, **sin peonada**). El jugador **amplía con un slider hasta
las 20:00** (rango autorizado por la División); las horas **más allá de 14:30 = peonada** (DO4). Opción de
**jornada ininterrumpida**. Documentación fija el horario que **Flujo ejecuta** y **Demanda respeta**.
Sábados/domingos cerrado (MVP).

**DO4 · Peonada de horas extra (voluntaria → motiva, cansa).** Ampliar más allá de 14:30 cuesta **peonada**
(`peonada_eur_hora` × horas extra × nº agentes). La cubren los **mismos** agentes o **refuerzos** generados
(normalmente disponibles). Como es **voluntaria y pagada**, la **Motivación NO baja** (el dinero motiva; se
mantiene/restaura), pero la **fatiga sube** (cansa igual). Rentable según demanda (DG12).

**DO5 · Última admisión (exprimir vs cuidar → coste de MORAL).** La última admisión (hasta qué minuto se da
número antes del cierre) es configurable con `margen_ultima_admision_min`:
- **Margen 15:** el personal sale **a su hora** — **contento**. Menos trámites.
- **Margen 0 (admite hasta el cierre):** termina a los rezagados **fuera de horario sin cobrar extra** →
  **desmotiva** (descontento). Más trámites.
- **Sin peonada** (el coste es **moral**, no dinero — a diferencia de DO4). La atención **siempre se
  termina** (compromiso de servicio, Flujo).

**DO6 · Efecto en el personal (gancho Bienestar).** La distinción DO4/DO5 (peonada = motiva+cansa; última
admisión tardía = desmotiva) alimenta la **Motivación/fatiga** de Personal. El modelo pleno de moral
dinámica es **Bienestar #13/#15** (diferido); en el MVP, **efecto ligero/gancho**.

**DO7 · Eventos de la División (estacionales, ligados a DG11).** La División manda **eventos temporales**
que amplían el horario por picos:
- **Periodo vacacional** → pico de **Pasaportes** → autoriza ampliar hasta **21:30**.
- **Colapso en extranjería** → amplía el horario de **TIE**.
- MVP: **1–2 eventos simples** para validar el mecanismo; el **catálogo crece** en playtest/V-Slice
  (campañas de DNI, jornada ininterrumpida, etc.). La División es la "voz" de los picos estacionales de
  Demanda (DG11).

**DO8 · Política de cita (MVP sin cita).** `requiere_cita=false` (Datos): la demanda no se autolimita (se
acota por paciencia/abandono, FL7). Documentación posee la política; la **cita previa** es el sistema **#14**
(V-Slice).

**DO9 · Fuente de ingresos.** Trámite completado → (vía Flujo) `"trámite completado"` → Economía abona
`tarifa_eur × retorno_DGP(sat)`. **Única fuente de ingresos** del MVP; la satisfacción la posee Paciencia
#10.

**DO10 · Requisitos de operación.** Un puesto de Doc atiende solo si **construido** + **abierto** (horario) +
**dotado** (`ag_doc`) + **en horario** (Flujo FL4).

**DO11 · Pausa.** En Pausa el reloj no corre; el jugador sí puede ajustar el slider de horario / margen de
última admisión (gestión en pausa).

**DO12 · Nivel de demanda como brújula.** Documentación consume **BAJA/MEDIA/ALTA** (Demanda DG12) para
informar la decisión de horas extra: BAJA → no rentable; MEDIA → ajustada; ALTA → rentable pero difícil dar
abasto.

### States and Transitions

| Estado | Descripción | Sale a |
|--------|-------------|--------|
| **Cerrado** | Fuera de horario | Abierto (llega la apertura: 08:00, o según eventos/slider) |
| **Abierto (admitiendo)** | En horario, **dando número** | Cerrando (llega la última admisión) |
| **Cerrando** | Ya **no da número**; termina a los admitidos | Cerrado (si pasa del cierre → descontento DO5 / peonada si horas extra DO4) |

- El estado abierto/cerrado de cada puesto lo **ejecuta Flujo**; Documentación fija **cuándo** (slider +
  eventos). En **Pausa** no hay transiciones (el reloj no corre).

### Interactions with Other Systems

| Sistema | Qué fluye | Dueño |
|---|---|---|
| **Datos** | *lee* trámites DNI/Pas/TIE (dur/tarifa/`requiere_cita`) | Datos ✅ GDD |
| **Flujo #4** | *configura* horario (abrir/cerrar), última admisión; Flujo ejecuta | Documentación configura; Flujo ejecuta ✅ GDD |
| **Demanda #5** | *configura* la ventana (08:00–14:30 / ampliaciones) y la cita; **eventos de la División ↔ DG11** | Documentación configura; Demanda genera ✅ GDD |
| **Economía #3** | trámite → ingreso (retorno DGP); **peonada** de horas extra (coste) | Economía abona/cobra ✅ GDD |
| **Personal #6** | usa `ag_doc`; **peonada motiva+cansa / última admisión tardía desmotiva**; refuerzos para peonadas | Personal posee dotación/moral ✅ GDD |
| **Construcción #7** | puestos `doc_general`/`tie`, oficina de Doc | Construcción ✅ GDD |
| **Paciencia #10** | la **satisfacción** modula el retorno DGP | Paciencia posee la curva *(provisional)* |
| **Horarios/Bienestar #13 / #15** *(V-Slice)* | *(futuro)* moral/fatiga plena, gestión fina de peonadas | #13/#15 *(diferido)* |
| **Cita previa #14** *(V-Slice)* | *(futuro)* activa `requiere_cita` | #14 *(diferido)* |
| **UI / HUD #11** | slider de horario, peonada, avisos de la División, nivel de demanda | UI presenta |

> **Reconciliación pendiente (se aplica en Fase 5):** la ventana base pasa a **08:00–14:30** en **Demanda**
> (pico 08:00, ~390 min) y en **Flujo** (throughput Doc ~26/día en vez de 22). Valores semilla.

## Formulas

> Documentación tiene **pocas fórmulas propias** (mucho es lógica de horario); las clave son la **peonada**
> y la **última admisión**. Lo demás lo referencia. Números **semilla provisional**. Prefijo `F#`.

### F1 · Coste de peonada por ampliar horario

`coste_peonada_dia = peonada_eur_hora × horas_extra × num_agentes_doc`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `peonada_eur_hora` | float | 15 (Datos) | Coste de una hora extra por funcionario |
| `horas_extra` | float | 0 – 5.5 | `max(0, hora_cierre − 14:30)` en horas (slider hasta 20:00) |
| `num_agentes_doc` | int | ≥ 0 | Agentes de Doc que cubren las horas extra |

**Salida y ejemplo:** cerrar a las **18:00** (3,5 h extra) con 2 agentes → `15 × 3,5 × 2 = **105 €/día**`. Lo
cobra Economía (peonada, F4 de Economía).

### F2 · Rentabilidad de la peonada (la decisión)

`peonada_rentable = (ingreso_extra_esperado > coste_peonada_dia)`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `ingreso_extra_esperado` | float | ≥ 0 | `trámites_extra × ingreso_medio_trámite` en las horas extra |
| `trámites_extra` | float | ≥ 0 | Trámites atendidos en las horas extra (según nivel de demanda DG12) |
| `coste_peonada_dia` | float | ≥ 0 | De F1 |

**Salida:** booleano — **la clave del sistema**. Con demanda **BAJA**, pocas llegadas tardías →
`ingreso_extra < coste` → **pierdes**. Con demanda **ALTA**, muchas → `ingreso_extra > coste` → **ganas**.
*El jugador lee el nivel BAJA/MEDIA/ALTA (DG12) para decidir; MEDIA es la difícil (días en negativo
posibles).*

### F3 · Hora de última admisión

`hora_ultima_admision = hora_cierre − margen_ultima_admision_min`

| Variable | Tipo | Rango | Descripción |
|----------|------|-------|-------------|
| `hora_cierre` | hora | 14:30 – 20:00 | Fin del horario (base o ampliado por slider/eventos) |
| `margen_ultima_admision_min` | int | 0 – 30 · **default 15** | Minutos antes del cierre en que se deja de dar número |

**Salida:** cierre 14:30, margen 15 → **última admisión 14:15**. Quien coge número **≤ 14:15** se atiende;
después, **puerta cerrada**. **Margen 0** = admite hasta el cierre → riesgo de terminar fuera de horario
(**desmotiva**, DO5).

**Fórmulas referenciadas (dueño externo — no se reinventan):**
- **Ingreso** por trámite: `ingreso_comisaria = tarifa_eur × retorno_DGP(sat)` (**Economía F1/F2**).
- **Throughput** de un puesto de Doc: `minutos_operativos / duracion_efectiva_media` (**Flujo F2**) — con
  el horario base **08:00–14:30 = 390 min** → ~26/día (reconciliación pendiente).
- **Nivel BAJA/MEDIA/ALTA** y su **perfil estacional anual** (verano/Navidad ALTA, Ene-Feb BAJA, resto
  MEDIA): **Demanda DG12/DG13/F2** — Documentación solo lo **consume** para la decisión de peonada.

## Edge Cases

*Formato: **Si [condición]: [qué pasa exactamente]. [por qué].** Cubre DO1–DO12 y F1–F3.*

- **Si el jugador amplía el horario con el slider:** se **permite** libremente; la **peonada** resultante
  (F1) se cobra al cierre del día (gasto — puede dejar en rojo como la nómina, Economía E5). *Activar la
  ampliación es una decisión de gestión, no un gasto voluntario bloqueado.*
- **Si la peonada se activa con demanda BAJA** (pierdes dinero): **permitido** — pierdes dinero. El nivel
  BAJA/MEDIA/ALTA (DG12) es la **brújula** que lo avisa. *No es error; es una mala decisión que el juego
  telegrafía.*
- **Si la última admisión es margen 0 y cierra con cola:** los admitidos se **terminan fuera de horario** →
  **desmotiva** al personal (DO5), **sin peonada** (el coste es moral). *Exprimir el cierre tiene precio en
  moral, no en €.*
- **Si un evento de la División (vacaciones/extranjería) está activo:** **autoriza** ampliar el horario
  (hasta 21:30 en vacaciones) — el jugador **decide** si amplía (y paga la peonada). *La División
  recomienda/habilita; la decisión sigue siendo del jugador (Pilar 4).*
- **Si el jugador intenta pasar de las 20:00 sin un evento activo:** el slider se **limita a 20:00** (la
  División no lo autoriza). Solo los eventos permiten más (hasta 21:30). *El rango lo fija la División.*
- **Si Documentación se deja cerrado un día** (0 horas / sábado): **permitido** — sin ingresos ese día.
  *Cerrar es una decisión válida (fin de semana, o ahorro con demanda BAJA).*
- **Si el servicio está abierto pero sin agentes de Doc dotados:** **no atiende** (Flujo FL4); las puertas
  abren pero la cola crece/abandona. *Señal de falta de personal, no un bug.*
- **Si un trámite llega con `requiere_cita=true` en el MVP** (config futura sin #14): se **trata como sin
  cita** con aviso (la cita previa #14 no está activa). *El MVP arranca sin cita; el flag existe para #14.*
- **Si cruza `nuevo_mes` a mitad de jornada** (cambio de perfil estacional): el nuevo `mult_estacional`
  (Demanda DG13) se aplica desde ese punto; el nivel BAJA/MEDIA/ALTA se recalcula. *La estacionalidad la
  gestiona Demanda; Documentación solo lee el nivel.*
- **Si se guarda la partida:** se serializan el **horario configurado** (slider, `margen_ultima_admision`,
  ampliación activa), el **evento de la División activo** y su ventana; al cargar se restauran y arranca en
  Pausa. *El estado del servicio se persiste íntegro.*

## Dependencies

Documentación es un **Feature configurador**: depende de las capas Core y las **parametriza** (les dice
horarios/cita). Casi todas las relaciones son mutuas y **todas las upstream están cerradas** ✅.

**Este sistema depende de / configura:**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Datos** | Hard | *lee* trámites DNI/Pas/TIE (dur/tarifa/`requiere_cita`) ✅ GDD |
| **Flujo #4** | Hard | *configura* horario (abrir/cerrar puestos) y última admisión; **Flujo ejecuta** el flujo de Doc ✅ GDD |
| **Demanda #5** | Hard | *configura* la **ventana** (08:00–14:30 / ampliaciones) y la **cita**; sus **eventos ↔ DG11/DG13**; **Demanda genera** ✅ GDD |
| **Economía #3** | Hard | trámite completado → **ingreso** (retorno DGP); **peonada** de horas extra (coste) ✅ GDD |
| **Personal #6** | Hard | usa `ag_doc`; **peonada motiva+cansa / última admisión tardía desmotiva** ✅ GDD |
| **Construcción #7** | Hard | usa los **puestos** `doc_general`/`tie` y la oficina de Doc ✅ GDD |

**Dependen de este sistema:**

| Sistema | Tipo | Interfaz |
|---------|------|----------|
| **Paciencia y Satisfacción #10** | Soft | *(indirecto)* la satisfacción de los trámites de Doc modula el retorno DGP *(provisional)* |
| **Cita previa #14** *(V-Slice)* | Hard | *(futuro)* activa `requiere_cita` de los trámites de Doc *(diferido)* |
| **Horarios/Bienestar #13 / #15** *(V-Slice)* | Soft | *(futuro)* moral/fatiga plena del personal de Doc *(diferido)* |
| **UI / HUD #11** | Hard | *expone* el slider de horario, la peonada, los avisos de la División y el nivel de demanda |

> **Nota — Documentación es "configurador":** con **Flujo, Demanda** (y Economía/Personal), la relación es
> de **parametrización** — Documentación no reimplementa el flujo/la demanda, les **dice cómo comportarse**
> para su servicio (horarios, última admisión, cita). Por eso son a la vez dependencias y "configurados".

> **Consistencia bidireccional:** todas las upstream (**Datos ✅, Flujo ✅, Demanda ✅, Economía ✅, Personal
> ✅, Construcción ✅**) ya registran la relación con Documentación o la reflejan; se afina en la
> reconciliación. Registrado en `systems-index.md`.

## Tuning Knobs

### Knobs propios de Documentación

| Knob | Default | Rango seguro | Si ↑ / Si ↓ | Owner |
|------|---------|--------------|-------------|-------|
| `horario_apertura_base` | 08:00 | fijado por la División | Adelantar/atrasar la apertura base | Documentación (División) |
| `horario_cierre_base` | 14:30 | 14:30 | La jornada base de mañana | Documentación (División) |
| `slider_min` · `slider_max` | 08:00 · **20:00** | rango que autoriza la División | ↑ `slider_max` = más horas extra posibles (más ingreso/coste) | Documentación (División) |
| `margen_ultima_admision_min` | 15 | 0 – 30 | ↑ cierra la puerta antes (personal contento, menos trámites) / ↓ exprime hasta el cierre (más ingreso, **desmotiva**) | Documentación |
| catálogo de **eventos de la División** | 1–2 en MVP (vacaciones→Pas 21:30; extranjería→TIE) | — | Añadir eventos = más variedad estacional (crece con DG11) | Documentación / Demanda |
| `peonada_activa_por_defecto` | off | {on, off} | on = amplía siempre (riesgo con demanda BAJA) / off = el jugador decide cada día | Documentación |

### Knobs referenciados (dueño externo — no se duplican)

| Knob | Dónde vive | Efecto |
|------|-----------|--------|
| `peonada_eur_hora` (15) | Datos → Economía | Coste de las horas extra (F1) |
| trámites DNI/Pas/TIE (dur/tarifa) | Datos | Duración e ingreso de cada trámite |
| `retorno_dgp` (0.15–0.45) | Economía | El ingreso real por trámite |
| nivel **BAJA/MEDIA/ALTA** + `mult_estacional` | Demanda DG12/DG13 | Cuándo la peonada compensa (F2) |
| `requiere_cita` | Datos → Cita #14 | MVP false; #14 lo activa |

**Interacciones entre knobs (clave):**
- **`horario` (slider) × nivel de demanda × `peonada_eur_hora`** definen la **rentabilidad de las horas
  extra** (F2): ampliar solo compensa con demanda MEDIA/ALTA.
- **`margen_ultima_admision_min`** es la palanca **exprimir vs cuidar**: baja = más ingresos + descontento;
  alta = personal a su hora.
- **Los eventos de la División** amplían el `slider_max` temporalmente (vacaciones → 21:30) → picos de
  ingreso ligados a la estacionalidad.

**Restricciones:** `slider_min ≤ horario_apertura_base`; `horario_cierre_base ≤ slider_max`;
`margen_ultima_admision_min ∈ [0, 30]`.

## Visual/Audio Requirements

*Estilo art bible: institucional serio, HUD tipo expediente/dosier, respaldo daltónico.*

| Elemento/Evento | Visual | Audio | Prioridad |
|---|---|---|---|
| **Aviso de la División** (evento) | Notificación tipo **comunicado oficial** (membrete, sello) | Aviso institucional sobrio | **Alta** (es una orden) |
| **Estado del servicio** | Indicador **Abierto / Cerrando / Cerrado** + reloj de apertura/cierre | Campana de apertura/cierre | Siempre visible |
| **Nivel de demanda** BAJA/MEDIA/ALTA | Semáforo verde/ámbar/rojo **+ icono + texto** (daltónicos) | — | Siempre |
| **Peonada activa** (horas extra) | Marca de "horas extra" en el reloj + coste del día | — | Media |
| **Personal saliendo tarde** (descontento DO5) | Caras cansadas / icono de descontento al pasar del cierre | Suspiro sobrio | Media |
| **Ingreso por trámite** | *(lo sonoriza Economía: tintineo)* | — | (Economía) |

> 📌 **Asset Spec** — Tras aprobar el art bible, `/asset-spec system:documentation` para el comunicado de la
> División, iconos de estado del servicio, semáforo de demanda.

## UI Requirements

*La pantalla la posee **UI/HUD #11**; ratón, sin hover-only.*

- **Slider de horario** *(control principal)*: ajustar apertura/cierre dentro del rango de la División
  (**08:00–20:00**), con **horas extra y coste de peonada en vivo** (F1). Jornada ininterrumpida como opción.
- **Control de última admisión** (`margen`, 0–30 min): la palanca **exprimir vs cuidar**.
- **Indicador de nivel de demanda** (BAJA/MEDIA/ALTA + estacional) — la **brújula** de la peonada (F2).
- **Bandeja de avisos de la División** (eventos: vacaciones→Pasaporte, colapso→TIE).
- **Panel del servicio:** estado (Abierto/Cerrando/Cerrado), ingresos del día de Documentación.
- La UI **nunca hardcodea** horas/costes: los lee de config y de Datos.

> **📌 UX Flag — Documentación:** UI real (slider de horario, avisos de la División, indicador de demanda).
> En Pre-Producción, ejecutar `/ux-design` para estos controles **antes** de escribir epics; las stories
> citan `design/ux/[pantalla].md`.

## UI Requirements

[To be designed]

## Acceptance Criteria

> Formato Given-When-Then. Tipo: `[Unit]` (lógica/fórmula pura) · `[Integration]` (interacción entre
> sistemas). *qa-lead no consultado (error "1M context"); lente qa aplicada en el hilo principal.*

**Trámites y horario (DO1, DO3, DO4)**
- **AC-DC01** `[Unit]` — GIVEN el catálogo THEN los trámites de Doc son **DNI**(12/12), **Pasaporte**(15/30), **TIE**(15/18) de Datos.
- **AC-DC02** `[Integration]` — GIVEN horario base 08:00–14:30 WHEN son las 15:00 THEN Flujo cierra los puestos de Doc y Demanda **no genera** Doc.
- **AC-DC03** `[Integration]` — GIVEN el slider ampliado a **18:00** THEN los puestos de Doc siguen abiertos hasta las 18:00 (Flujo ejecuta).
- **AC-DC04** `[Unit]` — GIVEN cerrar a 18:00 (3,5 h extra), 2 agentes, `peonada=15` THEN `coste_peonada=105€` (F1).

**Peonada vs última admisión (DO4, DO5, F2, F3)**
- **AC-DC05** `[Integration]` — GIVEN peonada activa y demanda **ALTA** THEN `ingreso_extra > coste` (rentable); con **BAJA** → pierde (F2).
- **AC-DC06** `[Integration]` — GIVEN peonada (voluntaria) THEN la **Motivación no baja** y la **fatiga sube** (gancho Personal/Bienestar).
- **AC-DC07** `[Unit]` — GIVEN cierre 14:30, `margen=15` THEN última admisión **14:15**; quien coge número ≤14:15 se atiende, después puerta cerrada (F3).
- **AC-DC08** `[Integration]` — GIVEN `margen=0` y cola al cierre THEN el personal termina fuera de horario → **desmotiva** (DO5), **sin peonada**.

**Eventos de la División (DO7)**
- **AC-DC09** `[Integration]` — GIVEN evento "vacaciones" activo THEN se **autoriza** ampliar hasta **21:30**; el jugador decide si amplía.
- **AC-DC10** `[Integration]` — GIVEN **sin** evento activo WHEN se usa el slider THEN se **limita a 20:00**.

**Cita, ingresos, requisitos (DO6, DO9, DO10)**
- **AC-DC11** `[Integration]` — GIVEN MVP (`requiere_cita=false`) THEN la demanda de Doc **no se autolimita** (se acota por paciencia).
- **AC-DC12** `[Integration]` — GIVEN un trámite de Doc completado THEN Economía abona `tarifa_eur × retorno_DGP(sat)`.
- **AC-DC13** `[Integration]` — GIVEN un puesto de Doc **sin agente** o **fuera de horario** THEN **no atiende** (FL4).

**Nivel de demanda, pausa, guardado (DO12, DO11, Edge)**
- **AC-DC14** `[Integration]` — GIVEN el nivel de demanda THEN es **visible** (BAJA/MEDIA/ALTA) y **varía por mes** (estacional, DG13).
- **AC-DC15** `[Integration]` — GIVEN el juego en **Pausa** WHEN se ajusta el slider/margen THEN se permite; el horario **no avanza**.
- **AC-DC16** `[Unit]` — GIVEN un save con horario configurado + evento activo WHEN se carga THEN se restauran.

## Open Questions

| # | Pregunta | Dueño | Plazo | Estado |
|---|----------|-------|-------|--------|
| 1 | **Valores semilla** (`margen 15`, `slider_max 20:00`, coste peonada, umbral de rentabilidad) | Balance / playtest | 1er playtest MVP | Abierta |
| 2 | **Catálogo de eventos de la División** (crece con DG11): cuáles, frecuencia, cuánto amplían y qué trámite | Documentación + Demanda + playtest | 1er playtest / V-Slice | Abierta |
| 3 | **Efecto de moral** (peonada motiva+cansa; última admisión tardía desmotiva): modelo pleno | Bienestar #13/#15 | GDD #13/#15 | Abierta |
| 4 | **Reconciliación pendiente**: ventana base 08:00–14:30 (Demanda/Flujo) + **calendario semanal** (Tiempo #1: 4 semanas/mes, "Mes·Semana N") | Reconciliar (Fase 5) | Al cerrar #8 | Abierta |
| 5 | **¿Cuánto desmotiva** exactamente la última admisión tardía (margen 0)? — calibrar con Bienestar | Personal/Bienestar + playtest | 1er playtest | Abierta |
| 6 | **Refuerzos para peonadas** (agentes nuevos vs los mismos): cómo se generan/eligen | Personal + Documentación | GDD Personal/Horarios | Abierta |
| 7 | **Cita previa #14**: cómo activa `requiere_cita` y regula la demanda | Cita #14 (V-Slice) | GDD #14 | Abierta |
