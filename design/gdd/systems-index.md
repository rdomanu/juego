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
| 1 | Sistema de Tiempo (reloj, día/noche, turnos) | Core | MVP | Not Started | — | — |
| 2 | Datos y Configuración *(inferred)* | Core | MVP | Not Started | — | — |
| 3 | Economía / Presupuesto | Economy | MVP | Not Started | — | Datos |
| 4 | Flujo de Personas y Colas | Gameplay | MVP | Not Started | — | Tiempo, Datos |
| 5 | Generación de Demanda *(inferred)* | Gameplay | MVP | Not Started | — | Tiempo, Datos |
| 6 | Personal / Agentes | Gameplay | MVP | Not Started | — | Datos, Economía |
| 7 | Construcción y Distribución | Gameplay | MVP | Not Started | — | Datos, Economía |
| 8 | Documentación (DNI/Pasaporte/TIE) | Gameplay | MVP | Not Started | — | Flujo, Personal, Construcción, Economía |
| 9 | ODAC / Denuncias | Gameplay | MVP | Not Started | — | Flujo, Personal, Construcción |
| 10 | Paciencia y Satisfacción | Gameplay | MVP | Not Started | — | Flujo, Tiempo |
| 11 | UI / HUD de Gestión *(inferred)* | UI | MVP | Not Started | — | (sistemas de juego) |
| 12 | Feedback y Juice *(inferred)* | UI | MVP | Not Started | — | (sistemas de juego) |
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
1. **Economía / Presupuesto** — depende de: Datos.
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
| Total de sistemas identificados | 27 |
| GDDs empezados | 0 |
| GDDs revisados | 0 |
| GDDs aprobados | 0 |
| Sistemas MVP diseñados | 0 / 12 |
| Sistemas Vertical Slice diseñados | 0 / 9 |

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

---

## Next Steps

- [ ] Revisar y aprobar este índice (el usuario quería verlo con calma)
- [ ] Diseñar los sistemas MVP primero con `/design-system [sistema]` (orden de arriba)
- [ ] `/design-review` sobre cada GDD terminado
- [ ] `/gate-check pre-production` cuando los sistemas MVP estén diseñados
