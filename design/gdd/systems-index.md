# Systems Index: Comisario *(título provisional)*

> **Status**: Draft — para revisión del usuario
> **Created**: 2026-07-19
> **Last Updated**: 2026-07-19
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

"Comisario" es un tycoon de gestión de una comisaría del CNP. Su motor es el **flujo de personas**
(ciudadanos, denunciantes, detenidos) atendidas por tu **personal** en **puestos** que construyes con
**presupuesto**, todo gobernado por un **sistema de tiempo** (reloj, día/noche, turnos). La diversión
nace de la tensión **ingresos (Documentación) vs. obligación (ODAC)** bajo presión creciente, con
**decisiones difíciles** (dilemas de influencia) y una **escalera de carrera con rangos reales del CNP**
que desbloquea sistemas progresivamente. Este índice descompone todo eso en sistemas, ordenados por
dependencia y prioridad, para escribir los GDDs en el orden correcto.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Sistema de Tiempo (reloj, día/noche, turnos) | Core | MVP | Reviewed | [time-system.md](time-system.md) | — |
| 2 | Datos y Configuración *(inferred)* | Core | MVP | Reviewed | [data-config.md](data-config.md) | — |
| 3 | Economía / Presupuesto | Economy | MVP | Reviewed | [economy-budget.md](economy-budget.md) | Datos, Tiempo |
| 4 | Flujo de Personas y Colas | Gameplay | MVP | Designed | [flow-queues.md](flow-queues.md) | Tiempo, Datos |
| 5 | Generación de Demanda *(inferred)* | Gameplay | MVP | Designed | [demand-generation.md](demand-generation.md) | Tiempo, Datos |
| 6 | Personal / Agentes | Gameplay | MVP | Designed | [staff-agents.md](staff-agents.md) | Datos, Economía |
| 7 | Construcción y Distribución | Gameplay | MVP | Designed | [construction-layout.md](construction-layout.md) | Datos, Economía |
| 8 | Documentación (DNI/Pasaporte/TIE) | Gameplay | MVP | Designed | [documentation.md](documentation.md) | Flujo, Personal, Construcción, Economía |
| 9 | ODAC / Denuncias | Gameplay | MVP | Designed | [odac.md](odac.md) | Flujo, Personal, Construcción |
| 10 | Paciencia y Satisfacción | Gameplay | MVP | Designed | [patience-satisfaction.md](patience-satisfaction.md) | Flujo, Tiempo |
| 11 | UI / HUD de Gestión *(inferred)* | UI | MVP | Designed | [ui-hud.md](ui-hud.md) | (sistemas de juego) |
| 12 | Feedback y Juice *(inferred)* | UI | MVP | Designed | [feedback-juice.md](feedback-juice.md) | (sistemas de juego) |
| 13 | Horarios y Peonadas | Gameplay | Vertical Slice | Not Started | — | Tiempo, Personal, Economía |
| 14 | Cita previa vs. sin cita | Gameplay | Vertical Slice | Not Started | — | Documentación, Demanda |
| 15 | Comodidades de sala de espera | Economy | Vertical Slice | Not Started | — | Construcción, Paciencia, Economía |
| 16 | Presión e Influencia (dilemas) | Narrative | Vertical Slice | Not Started | — | Economía, Personal, Tiempo |
| 17 | Detenidos y Abogados | Gameplay | Vertical Slice | Not Started | — | Flujo, Construcción, Personal |
| 18 | Ascensos / Carrera (rangos reales CNP) | Progression | Vertical Slice | Not Started | — | Economía, Satisfacción, Métricas |
| 19 | Brigadas (estructura orgánica) | Progression | Vertical Slice | Not Started | — | Personal, Ascensos |
| 20 | Guardado y Carga *(inferred)* | Persistence | Vertical Slice | Not Started | — | (estado de todos los sistemas) |
| 21 | Tutorial / Onboarding *(inferred)* | Meta | Vertical Slice | Not Started | — | Core + Ascensos |
| 22 | Sala 091 / Incidentes (despacho) | Gameplay | Alpha | Not Started | — | Personal, Tiempo, Brigadas |
| 23 | Vehículos / Patrullas | Gameplay | Alpha | Not Started | — | Personal, Sala 091 |
| 24 | Métricas del jugador *(inferred)* | Meta | Alpha | Not Started | — | (sistemas de juego) |
| 25 | Audio (ambiente, avisos) *(inferred)* | Audio | Alpha | Not Started | — | Feedback |
| 26 | Escalado a Comisarías / Mapa de España | Progression | Full Vision | Not Started | — | Ascensos, Economía, Guardado |
| 27 | Localización (i18n) *(inferred)* | Meta | Full Vision | Not Started | — | UI |
| 28 | Valoración de jefes (reputación con superiores) *(inferred)* | Progression | Vertical Slice | Not Started | — | Economía, Presión e Influencia #16, Métricas |
| 29 | Formación y Cursos (funcionarios) *(inferred)* | Progression | Vertical Slice | Not Started | — | Personal, Economía, Tiempo, Satisfacción #10, Flujo #4 |

---

## Priority Tiers

| Tier | Definición | Hito |
|------|------------|------|
| **MVP** | Bucle central jugable como Subinspector en la primera oficina (probar "¿es divertido?") | Primer prototipo jugable |
| **Vertical Slice** | Una comisaría completa con progresión, dilemas y varias unidades | Demo / slice |
| **Alpha** | Todos los sistemas presentes en bruto (091, vehículos, más comisarías) | Alpha |
| **Full Vision** | Escalado a toda España, pulido, localización | Beta / Release |

---

## Dependency Map

### Foundation Layer (sin dependencias)
1. **Sistema de Tiempo** — reloj y turnos gobiernan cuándo pasa todo (bottleneck).
2. **Datos y Configuración** — definiciones data-driven (trámites, denuncias, costes) que todo consume (pilar: valores data-driven).

### Core Layer (depende de Foundation)
1. **Economía / Presupuesto** — depende de: Datos, Tiempo.
2. **Flujo de Personas y Colas** — depende de: Tiempo, Datos (bottleneck: casi todo lo visible depende de él).
3. **Generación de Demanda** — depende de: Tiempo, Datos.
4. **Personal / Agentes** — depende de: Datos, Economía.
5. **Construcción y Distribución** — depende de: Datos, Economía.

### Feature Layer (depende de Core)
1. **Documentación** — depende de: Flujo, Personal, Construcción, Economía.
2. **ODAC / Denuncias** — depende de: Flujo, Personal, Construcción.
3. **Paciencia y Satisfacción** — depende de: Flujo, Tiempo.
4. **Horarios y Peonadas** — depende de: Tiempo, Personal, Economía.
5. **Cita previa vs. sin cita** — depende de: Documentación, Demanda.
6. **Comodidades de sala** — depende de: Construcción, Paciencia, Economía.
7. **Presión e Influencia** — depende de: Economía, Personal, Tiempo.
8. **Detenidos y Abogados** — depende de: Flujo, Construcción, Personal.

### Progression Layer
1. **Ascensos / Carrera** — depende de: Economía, Satisfacción, Métricas.
2. **Brigadas** — depende de: Personal, Ascensos.
3. **Escalado a Comisarías / Mapa de España** — depende de: Ascensos, Economía, Guardado.

### Presentation Layer (envuelve el juego)
1. **UI / HUD de Gestión** — depende de: los sistemas de juego que muestra.
2. **Feedback y Juice** — depende de: los sistemas de juego.

### Polish Layer (depende de casi todo)
1. **Guardado y Carga** — depende de: el estado de todos los sistemas.
2. **Tutorial / Onboarding** — depende de: Core + Ascensos.
3. **Métricas**, **Audio**, **Sala 091**, **Vehículos**, **Localización**.

---

## Recommended Design Order

| Orden | Sistema | Prioridad | Capa | Agente(s) | Esfuerzo |
|-------|---------|-----------|------|-----------|----------|
| 1 | Sistema de Tiempo | MVP | Foundation | game-designer / systems-designer | S |
| 2 | Datos y Configuración | MVP | Foundation | systems-designer | S |
| 3 | Economía / Presupuesto | MVP | Core | economy-designer | M |
| 4 | Flujo de Personas y Colas | MVP | Core | systems-designer / game-designer | L |
| 5 | Generación de Demanda | MVP | Core | systems-designer | M |
| 6 | Personal / Agentes | MVP | Core | game-designer | M |
| 7 | Construcción y Distribución | MVP | Core | game-designer | M |
| 8 | Documentación | MVP | Feature | systems-designer | M |
| 9 | ODAC / Denuncias | MVP | Feature | systems-designer | M |
| 10 | Paciencia y Satisfacción | MVP | Feature | systems-designer | M |
| 11 | UI / HUD de Gestión | MVP | Presentation | ux-designer / ui-programmer | M |
| 12 | Feedback y Juice | MVP | Presentation | game-designer | S |
| 13+ | (Vertical Slice: Horarios, Cita, Comodidades, Influencia, Detenidos, Ascensos, Brigadas, Guardado, Tutorial) | V. Slice | Feature/Progression | varios | — |

> Esfuerzo: S = 1 sesión · M = 2-3 sesiones · L = 4+ sesiones.

---

## Circular Dependencies

- **Ninguna crítica detectada.** Nota: UI ↔ sistemas de juego es una dependencia de presentación
  esperada (la UI se diseña *después* del sistema que muestra), no un ciclo real.

---

## High-Risk Systems

| Sistema | Tipo de riesgo | Descripción | Mitigación |
|---------|----------------|-------------|------------|
| Flujo de Personas y Colas | Técnico + Diseño | Muchos NPCs navegando a la vez (rendimiento en Godot 2D); es el bottleneck del que todo depende | Ya validado como divertido en el prototipo; diseñar con cuidado y hacer spike de rendimiento antes de escalar |
| Sistema de Tiempo | Diseño | Casi todo depende de su modelo (tiempo real + día/noche + turnos) | Diseñarlo primero y estable; ya probado a grandes rasgos en el prototipo |
| Presión e Influencia | Diseño | Equilibrar dilemas para que sean justos y no premien la "corrupción" ni tomen partido | Diseño dedicado + playtest; anti-pilar de neutralidad política |
| Escalado a Comisarías | Alcance | "Toda España" es enorme; riesgo de no terminar | Diferido a Full Vision; la escalera de carrera trocea el trabajo |
| Ascensos / Divisas | Producción/Legal | Las divisas deben ser **exactas** (imagen real filtrada, no dibujada); son símbolos oficiales del Estado | Usar imágenes reales con filtro de estilo; revisar uso legal si se comercializa |

---

## Progress Tracker

| Métrica | Cuenta |
|---------|--------|
| Total de sistemas identificados | 29 |
| GDDs empezados | 12 |
| GDDs revisados | 3 |
| GDDs aprobados | 0 |
| Sistemas MVP diseñados | 12 / 12 ✅ |
| Sistemas Vertical Slice diseñados | 0 / 10 |

---

## Notas de dominio (para los GDDs)

**Ascensos — rangos y divisas reales del CNP** (Orden INT/430/2014; verificar posible reforma reciente
"Policía de Primera Clase / Inspector Principal" antes de arte final):

| Escala | Categoría | Divisa (insignia real) |
|--------|-----------|------------------------|
| Básica | Policía | Rama de laurel + 2 galones en ángulo |
| Básica | Oficial de Policía | Rama de laurel + 3 galones en ángulo |
| Subinspección | **Subinspector** *(inicio del jugador)* | Corona de laurel + 3 galones en ángulo |
| Ejecutiva | **Inspector** | 3 coronas de laurel en triángulo |
| Ejecutiva | **Inspector Jefe** *(jefe de brigada)* | Bastón de mando orlado + entorchado |
| Superior | **Comisario** *(jefe de comisaría)* | 2 bastones de mando orlados en línea |
| Superior | **Comisario Principal** | 3 bastones de mando orlados en línea |

> **Regla de assets (divisas)**: las divisas se representan con la **imagen real exacta** de cada
> insignia, aplicando un **filtro adaptado al estilo del juego** — NUNCA dibujadas a mano ni
> aproximadas. Formalizar en el art bible (sección 8, Estándares de assets).

**Brigadas** (esqueleto de la escalera de carrera): Seguridad Ciudadana (Zetas), Policía Judicial
(de ella cuelga la ODAC), Información, Policía Científica, Extranjería y Fronteras. Documentación
cuelga de la **Secretaría** (no de una brigada).

**ODAC (Oficina de Denuncias y Atención al Ciudadano)** — abierta **24h**, con **horario a turnos**
(07–15 / 15–23 / 23–07). Hace **mucho más que "poner denuncias"** (para el GDD de ODAC #9 y el de
Detenidos y Abogados #17):
- **Muchos tipos de denuncia** (no solo 3): permisos de viaje, estafas, lesiones,
  pérdidas/sustracciones, VioGén (prioritaria), daños, amenazas, hurtos/robos… *(lista a cerrar en el
  GDD de ODAC).*
- **Atestados de detenidos**, **comparecencia** de los policías que practican la detención, **toma de
  declaración** al detenido, **aviso/llamada al abogado** del detenido.
- Puestos de ODAC **reconfigurables en caliente**: un puesto puede atender un tipo de denuncia, varios
  o todos.
- → Las funciones de detenidos/abogado enlazan con el GDD **Detenidos y Abogados** (Vertical Slice).

**Horarios de trabajo reales del CNP** (para el GDD de Horarios y Personal): **horario a turnos** (8h
rotativo 24h: 07–15 / 15–23 / 23–07, p. ej. ODAC y Seguridad Ciudadana); **horario complementario**
(el más común, L–V 08:00–14:30 mañana y 14:30–20:00 tarde, p. ej. Documentación); y **guardias**
(personal localizable de noche para Judicial, Científica, Extranjería…). El Sistema de Tiempo solo
provee el reloj/turnos; estos patrones de asignación son de Horarios/Personal.

**Valoración de jefes (reputación con superiores)** *(sistema #28, surgido al diseñar Economía)* — métrica
que refleja tu **standing con la cúpula** (Comisario, DGP). **Baja** al pedir favores/préstamos a superiores
o al llevar varios días sin cumplir objetivos; su efecto exacto (¿modula ascensos?, ¿retorno?, ¿dispara
eventos?) está por definir. Es la **moneda del Pilar 5 (Presión e Influencia #16)**; en el MVP solo existe
como **hook** (Economía baja esta valoración al pedir un préstamo del Comisario — ver `economy-budget.md`
E9). El sistema completo se diseña con #16 / Métricas.

**Presión e Influencia — dilemas (sistema #16, ejemplos del usuario 2026-07-21)** — el **Pilar 5**: personas
influyentes (superiores, VIP, políticos, medios) piden **favores** con trade-offs sin respuesta fácil. Se
**manifiestan** en los servicios visibles (ODAC, Documentación) pero el sistema los posee. Ejemplos concretos:
- **Colar a alguien** (un superior/VIP pide saltarse la cola): +**valoración de jefes #28**, pero la sala se
  **indigna** al ver el enchufe → −**paciencia/satisfacción #10** de los que esperan.
- **Denuncia/trámite a domicilio** (un VIP pide que un agente vaya a su casa): el agente queda **fuera del
  puesto ~2 h** → −capacidad de ese servicio.
- **Atender sin cita** (con Cita previa #14 activa, un jefe pide colar a alguien sin cita): mismo dilema
  (favor vs. indignación de los que sí pidieron cita).
**Regla de diseño (Pilar 5, crítica):** nunca una opción obviamente buena; **jamás premiar la corrupción** ni
tomar partido político (anti-pilar). Alcance **Vertical Slice**; ganchos ya en ODAC/Documentación.

**Formación y Cursos** *(sistema #29, surgido al diseñar Flujo)* — progresión de los **funcionarios**: cada
agente puede formarse en **cursos con niveles** pagando **dinero** (matrícula → Economía) y **tiempo** (el
agente no atiende durante N días → coste de oportunidad). **Formación por skill específico** (alineada con los atributos de Personal #6, 2026-07-21): eliges **qué
skill** formar —⚡Rapidez, 🤝Trato, ❤️Salud, 🔥Motivación, o 🎖️Mando (Oficiales)— y sube **solo esa**
(formar Rapidez sube Rapidez, no todas). Niveles = la escala **1–5** → hasta ~4 mejoras por skill.
- ⚡Rapidez → `modificador_produccion` (Flujo #4). 🤝Trato → `bonus_satisfaccion` (retorno DGP, Satisfacción
  #10). ❤️Salud → menos ausencias. 🔥Motivación → rendimiento. 🎖️Mando → mejor cobertura del Oficial.
- **Coste creciente + retorno decreciente** (regla del usuario): cada nivel cuesta más (€ matrícula →
  Economía + **días** sin atender = coste de oportunidad) y aporta **menos %** (4→5 « 1→2) → evita el
  "no-brainer" de maxear. Refs: **Two Point Hospital** (formación por cualificación con niveles);
  **Football Manager** (retorno decreciente cerca del tope).
- **Tensión con la nómina:** como el salario depende de los atributos (Personal F1), **formar sube el
  salario** del agente → mejorar **encarece la plantilla** (decisión, no gratis).
El **gancho** ya existe en `flow-queues.md` (Flujo aplica una duración efectiva y un bonus modulados por el
agente; los **valores** los posee Personal/Formación). Alcance **Vertical Slice** (capa de profundidad sobre
Personal, como Horarios #13 / Comodidades #15). Diseño exacto (curva de mejora, coste €+días, desbloqueo por
rango, riesgo de "no-brainer") → GDD propio con Personal/Economía.

**Comodidades de sala de espera** *(sistema #15, matices surgidos al diseñar Demanda)* — objetos de la sala
de espera (asientos y **máquinas de café/vending**) con **doble efecto**: (1) **la paciencia se agota más
despacio** cuantas más/mejores comodidades tenga la sala → **Paciencia #10**; (2) las **máquinas generan
ingreso secundario**: **1 €/consumo**, con **~30 % de las personas** consumiendo algo → **Economía #3**. La
aleatoriedad del consumo se resuelve con el **mismo patrón determinista sembrado** que usa Demanda (F4): por
cada persona, una tirada del RNG sembrado; si `rng < prob_consumo` (≈0.30) → +1 € (reproducible y testeable).
Alcance **Vertical Slice**; diseño exacto (calidad, deterioro, mantenimiento, curva de paciencia, coste,
riesgo de "no-brainer") → GDD #15 con Paciencia/Economía. *(El aforo máximo de la sala lo posee Datos
`aforo_espera`; Comodidades llena ese aforo con asientos mejorables.)*
**Catálogo de objetos/mobiliario** *(surgido al diseñar Construcción #7, 2026-07-21)*: asientos (aforo +
confort), **mesas, luces, plantas, papeleras/limpieza, decoración** y **máquinas de vending**. **Ownership:**
**Construcción #7** posee el *mecanismo de colocarlos* (ocupan celda, cuestan, dentro de salas) y en el MVP
solo el **asiento básico** (para el aforo); el **catálogo** (`TipoObjeto`) lo cataloga **Datos**; la
**calidad, deterioro, mantenimiento/limpieza y su efecto en paciencia/satisfacción** los detalla **#15**
(Two Point Hospital-style: confort y limpieza suben la satisfacción del ciudadano que espera). Alcance
**Vertical Slice**.

**Escalado a Comisarías — comisarías reales con volumen diferenciado** *(sistema #26, idea del usuario
2026-07-21)* — cada comisaría = una definición `Escenario` (Datos) con **volumen y distribución propios
calibrados a datos reales** (población INE + criminalidad del **Portal Estadístico de Criminalidad**,
Ministerio del Interior). Curva de dificultad: **Pozuelo (tranquila, MVP) → Parla (mucho volumen) →
comisarías de distrito de la ciudad de Madrid → Centro (máximo volumen de España, noches frenéticas)**.
Enfoque **Madrid-first** (Comunidad de Madrid: comisarías CNP locales; ciudad: comisarías de distrito).
- **Compatibilidad con lo ya diseñado (SIN rework — ganchos ya puestos):** `Escenario` es extensible
  (Datos F7: "niveles superiores = nuevas definiciones Escenario"); la demanda **ya escala por escenario**
  vía `tasa_base` × población (Demanda F1) y `factor_crecimiento_nivel` (DG8); el **invariante R5 se valida
  POR escenario** (Datos R5); los **perfiles intradía son por servicio** (Demanda F2) → un perfil "Centro"
  con noches altas es **añadir datos**, no reprogramar; `tope_construible` por servicio ya es por-escenario
  → distinta distribución de salas por comisaría.
- **Única generalización futura (prevista, no rediseño):** `tasa_base_doc/odac` pasan de constante global
  (hoy Pozuelo 0.5/0.4) a **campo por `Escenario`** (o multiplicador de escenario × base). Ya anticipado
  por DG8.
- **Menú admin de tuning de volumen** *(herramienta de dev — aprovechable YA para calibrar el MVP; semilla
  en la UI de Demanda como "visor de diseño")*: editar `tasa_base`/perfiles/multiplicadores en vivo con
  **preview de llegadas/día y pico/hora vs capacidad (R5)**, para llegar al volumen deseado por comisaría
  sin pasarse ni quedarse corto. Guarda de vuelta a la config data-driven.
- **Retos distintos por comisaría (Theme Hospital-style, idea 2026-07-21):** que no todas se jueguen igual.
  Cada `Escenario` lleva, además del volumen, su **perfil propio**: (a) **mezcla de demanda distinta** (zona
  con inmigración → más TIE/extranjería; turística → más pasaportes/robos; Centro → denuncia nocturna
  intensa); (b) **edificio distinto** (más pequeño o de forma difícil = **reto espacial**, como el terreno
  de Theme Hospital); (c) **objetivos/dificultad** propios (umbral de eficiencia, presupuesto más ajustado);
  (d) **eventos de zona** (futuro: manifestaciones, picos). Todo cabe en campos del `Escenario` (Datos ya
  extensible) → **sin rework**. Es lo que hace que ascender de comisaría **se sienta como un reto nuevo**,
  no repetido.
- **Pendiente (Fase 1):** investigar nº de comisarías CNP en la Comunidad de Madrid + criminalidad por
  zona (registros públicos) → tabla `comisaría → (población, índice criminalidad, tier de volumen,
  tasa_base sugerida, intensidad nocturna)`. Alcance **Full Vision (#26)**.

**Fatiga, descanso y bienestar del personal** *(profundidad diferida — matices del usuario 2026-07-21;
liga Horarios #13 + Comodidades/Bienestar #15)* — capa sobre Personal #6 que hace la **Motivación
dinámica**:
- **Modelo abstracto (SIN turnos rotativos):** se **descartan los turnos** por agente; como en la mayoría
  de tycoon, **1 agente cubre su puesto** (Documentación en su horario; ODAC 24 h) y se gestiona con
  **descansos**, no con rotación. *(El reloj mantiene día/noche para demanda/ambiente; el agente no rota.
  Los turnos del CNP —07-15/15-23/23-07— siguen siendo del reloj/Tiempo, no de la dotación.)*
- **Fatiga:** trabajar **sube la fatiga**; a más fatiga, **rinde más lento** (`rendimiento_efectivo =
  atributo_base × factor(fatiga)`) pero **sigue trabajando** si lo exiges (decisión **exprimir vs cuidar**).
  Fatiga alta sostenida → más **ausencias** (enlaza con Salud/PA7 de Personal).
- **Recuperación (dos vías con roles distintos):** **día libre** (no asignado) = recuperación **completa**
  (reset ~100 % con 1 día); **sala de descanso** (Construcción + Comodidades) = recuperación **parcial** en
  micro-pausas durante la jornada, que **estira** el ciclo pero **NO sustituye** al día libre (tope de
  recuperación por sala; nunca lleva a 0). *Balance clave del usuario: la sala no puede trivializar los
  días de descanso.*
- **Cadencia objetivo (a validar en playtest):** ~**3–4 días de trabajo : 1 día libre** sin sala; con
  sala, el ciclo se estira (~5–6 : 1). 1 día libre recupera el 100 %.
- **Turnos con coste de fatiga** (mañana/tarde altos por volumen; noche antinatural + acumula): **en
  pausa** de momento; si se retoman, van a Horarios #13. *(#13 sigue siendo relevante por las **peonadas**;
  los turnos rotativos de personal quedan descartados a favor del modelo abstracto.)*
- **Gancho ya puesto:** Personal PA10 (Motivación es atributo y modula rendimiento). Alcance **Vertical
  Slice**.

---

## Next Steps

- [ ] Revisar y aprobar este índice (el usuario quería verlo con calma)
- [ ] Diseñar los sistemas MVP primero con `/design-system [sistema]` (orden de arriba)
- [ ] `/design-review` sobre cada GDD terminado
- [ ] `/gate-check pre-production` cuando los sistemas MVP estén diseñados
