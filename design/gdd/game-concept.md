# Game Concept: Comisario *(título provisional)*

*Created: 2026-07-18*
*Status: Draft*

---

## Elevator Pitch

> Es un **tycoon de gestión** donde diriges una comisaría del Cuerpo Nacional de Policía
> —de una pequeña Oficina de Denuncias a comisarías de toda España— gestionando el flujo
> de **ciudadanos, denunciantes y detenidos**, a tu personal, tus recursos y las presiones
> de quien tiene poder, para ascender de **subinspector a comisario**.

*Test 10 segundos: "Un Prison Architect de una comisaría española de verdad, donde subes de rango." ✅*

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Simulación / gestión (tycoon) con toques de estrategia |
| **Platform** | PC (Windows; Steam a futuro) |
| **Target Audience** | Fans de gestión/tycoon + público hispano (ver perfil abajo) |
| **Player Count** | Un jugador (single-player) |
| **Session Length** | 30–90 min |
| **Monetization** | Premium a futuro; ninguna por ahora |
| **Estimated Scope** | Grande (visión completa 1–2+ años, en solitario/aprendiendo; MVP en semanas–meses) |
| **Comparable Titles** | Prison Architect · This Is the Police · Two Point Hospital |

---

## Core Fantasy

Ser el gestor que convierte una humilde oficina de barrio en una comisaría modélica, y
ascender **por méritos** hasta dirigir comisarías por toda España. La promesa emocional:
*"Esta comisaría —y esta carrera— las he construido yo, con mis decisiones."*

A diferencia de un juego de acción policial, aquí el poder no está en la calle disparando,
sino en la **mesa de mando**: cómo organizas el edificio, a quién contratas, cómo gastas un
presupuesto siempre justo, y cómo respondes cuando alguien poderoso te pide un favor.

---

## Unique Hook

Como **Prison Architect**, PERO con el funcionamiento **real y fiel del CNP español**, donde
los "clientes" que fluyen por tu edificio son **ciudadanos a por el DNI, denunciantes, víctimas
y detenidos con sus abogados**, donde el **día y la noche** cambian los servicios abiertos y la
criminalidad, y donde **asciendes de subinspector a comisario** gestionando comisarías por toda
España — con **dilemas de presión e influencia sin respuesta fácil**.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | 6 | Arte 2D limpio y legible; ambiente sonoro de comisaría (radio, avisos, teclas) |
| **Fantasy** | 3 | Rol de mando policial; ambientación realista y fiel del CNP |
| **Narrative** | 4 | Historias emergentes: casos, agentes con trayectoria, dilemas de influencia |
| **Challenge** | 2 | Optimizar recursos, cumplir eficiencia con presupuesto ajustado, dilemas |
| **Fellowship** | N/A | Un jugador |
| **Discovery** | 5 | Descubrir cómo funcionan los sistemas; desbloquear unidades al ascender |
| **Expression** | 1 | Construir y organizar TU comisaría a tu estilo |
| **Submission** | 7 | Bucles de gestión tranquila entre los picos de tensión |

*(Prioridades 1–2: Expresión + Reto — justo lo que pidió el jugador: base tycoon + desafíos.)*

### Key Dynamics (Emergent player behaviors)
- Los jugadores **optimizan la distribución** de puestos y salas para reducir colas.
- Experimentan con **layouts** distintos según su estilo.
- **Sopesan los dilemas** de influencia (aceptar un favor por presupuesto vs. subir la criminalidad).
- **Planifican alrededor del ciclo día/noche** y los cambios de turno.
- **Especializan** su comisaría según el distrito.

### Core Mechanics (Systems we build)
1. **Gestión de flujo de personas**: ciudadanos/denunciantes/detenidos recorren el edificio (turno → espera → puesto/sala → resuelto).
2. **Construcción modular** de la comisaría (salas y unidades) con presupuesto.
3. **Gestión de personal**: agentes con rango y unidad, turnos, asignación a puestos/tareas.
4. **Ciclo día/noche + turnos** que cambian servicios activos y nivel de criminalidad.
5. **Presión e influencia + progresión de carrera**: dilemas con trade-offs; ascensos que desbloquean sistemas.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Diseñas y priorizas tu comisaría; decides cómo gastar el presupuesto y cómo responder a los dilemas | Core |
| **Competence** | Ves bajar tiempos y colas, cumples objetivos de eficiencia y asciendes de rango | Core |
| **Relatedness** | Agentes con nombre que evolucionan; ciudadanos y casos con pequeñas historias | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Progresión de carrera, ascensos, objetivos de eficiencia, hacer crecer la comisaría.
- [x] **Explorers** — Entender y optimizar sistemas, desbloquear unidades y descubrir sinergias de gestión.
- [ ] **Socializers** — Mínimo (single-player; relación con NPCs).
- [ ] **Killers/Competitors** — No es el foco.

### Flow State Design
- **Onboarding curve**: Los primeros 10 min eres **subinspector de la Oficina de Denuncias** con una cola sencilla de DNI. El juego enseña **un sistema por ascenso** (revelación progresiva).
- **Difficulty scaling**: Cada ascenso añade unidades/sistemas; comisarías mayores = más volumen, más dilemas.
- **Feedback clarity**: Métricas visibles — tiempos de espera, colas, satisfacción, presupuesto, criminalidad del distrito.
- **Recovery from failure**: Fallar un objetivo **no es game over**: reintentas el mes/turno. Aprendizaje, no castigo severo.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Gestionar el flujo de personas y resolver cuellos de botella: asignar un agente a un puesto,
abrir una ventanilla, mover a un detenido a una sala, atender una cola que crece.

### Short-Term (5–15 minutes)
Cerrar un **turno** cumpliendo los objetivos sin que exploten las colas ni el presupuesto. El
cambio de turno (mañana → tarde → **noche**) reconfigura el juego: de noche cierra el DNI, bajan
los denunciantes, sube la criminalidad y solo quedan brigadas de guardia + unidades 24h.

### Session-Level (30–120 minutes)
Sacar adelante varios días y alcanzar el **objetivo de eficiencia con el presupuesto asignado**,
lo que te gana el **ascenso**. Punto de parada natural + razón para volver (el siguiente rango).

### Long-Term Progression
La **escalera de carrera**: Subinspector (una oficina) → Inspector → Inspector Jefe (jefe de
brigada) → Comisario (comisaría entera) → gestionar comisarías por toda España. Cada rango
desbloquea nuevos sistemas, más presupuesto y más responsabilidad.

### Retention Hooks
- **Curiosity**: El siguiente ascenso y la siguiente unidad/comisaría por desbloquear.
- **Investment**: Tu comisaría y tus agentes, que no quieres abandonar.
- **Mastery**: Bajar tiempos de respuesta y optimizar el presupuesto.
- **Social**: N/A (single-player).

---

## Game Pillars

### Pillar 1: Realismo con alma
El juego se basa en el funcionamiento real del CNP (unidades, escalas, procedimientos), pero
siempre al servicio de la diversión.
*Design test*: Entre un detalle fiel pero tedioso y una simplificación que se juega mejor, elegimos el realismo que **aporta decisión**, no la burocracia vacía.

### Pillar 2: La comisaría está viva
El edificio bulle de gente con historias: ciudadanos, denunciantes, víctimas, detenidos, abogados y agentes con nombre.
*Design test*: Entre una métrica abstracta o un personaje/flujo **visible** que la represente, elegimos lo visible y humano.

### Pillar 3: De subinspector a toda España
El alcance se *gana*: cada ascenso desbloquea sistemas nuevos y sensación de progreso.
*Design test*: Entre dar algo gratis al inicio o ligarlo a un ascenso, lo ligamos al **ascenso**.

### Pillar 4: Tu comisaría, tus decisiones
El jugador expresa su estilo (cómo construye, prioriza y gasta el presupuesto) y esas decisiones importan.
*Design test*: Si una función no cambia **ninguna** decisión del jugador, se recorta.

### Pillar 5: Presión e influencia (decisiones sin respuesta fácil)
Personas influyentes (políticos, empresarios, mandos, medios) piden favores que benefician a tu comisaría pero cuestan recursos o consecuencias. **Nunca hay una opción obviamente correcta.**
*Design test*: Si un dilema tiene una elección claramente buena, le añadimos un coste real o lo cortamos.
*Ejemplo*: un cargo pide un coche patrulla en su casa 3–4 días a cambio de una subvención → aceptas: +presupuesto pero −2 agentes en la calle 24h → sube la criminalidad del distrito; rechazas: pierdes la subvención y quizá un aliado.

### Anti-Pillars (What This Game Is NOT)

- **NO es un juego de acción/disparos**: gestionas la comisaría, no controlas a un agente disparando en la calle. *(Protege los pilares 2 y 4.)*
- **NO es una caricatura**: nada de humor absurdo o parodia que rompa el tono serio y realista. *(Protege el pilar 1.)*
- **NO es un simulador de burocracia tedioso**: no metemos realismo que solo sea rellenar formularios sin decisión. *(Protege el pilar 4.)*
- **NO toma partido político (pero SÍ hay dilemas de influencia)**: nada de partidos, ideologías ni signo político real; sí presiones y favores **apolíticos** con consecuencias medibles. *(Mantiene el tono respetuoso y vendible; alimenta el pilar 5.)*

> ⚠️ **Nota de diseño**: el sistema de presión/influencia (pilar 5) hay que estudiarlo **con mucho cuidado** para que sean trade-offs interesantes y nunca parezca que premia la corrupción o toma partido. Marcado como sistema a diseñar con atención en su GDD.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **Prison Architect** | Gestión 2D cenital de una institución; construcción modular de salas | Comisaría CNP realista; flujo de ciudadanos, no solo presos | Valida que un 2D serio de institución engancha y se puede hacer en solitario |
| **This Is the Police** | Gestión policial + dilemas morales + turnos | Base tycoon de construcción + realismo CNP; sin tono noir/corrupto | Valida que la gestión policial tiene público |
| **Two Point Hospital** | Flujo de "clientes" por el edificio; salas especializadas | Tono realista (no caricatura); ciudadanos/denunciantes/detenidos | Valida que el bucle de flujo de personas es divertido |
| **911 Operator** | Despacho de incidentes en un mapa | Solo como sistema futuro (sala 091), no el juego entero | Referencia para la fase operativa avanzada |

**Non-game inspirations**: la vida real de una comisaría del CNP (referencias: Usera, Pozuelo), procedimientos y terminología reales (DNI/pasaporte/NIE, VioGén, 091, unidades GAC/UPR/PJ/ODAC/Científica).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–45 |
| **Gaming experience** | Mid-core |
| **Time availability** | Sesiones de 30–90 min, tardes/fines de semana |
| **Platform preference** | PC |
| **Current games they play** | Prison Architect, This Is the Police, Two Point Hospital, RimWorld |
| **What they're looking for** | Un tycoon de gestión con tema fresco (policía realista española) y progresión con decisiones que importan |
| **What would turn them away** | Acción/disparos, tono caricaturesco, micropagos, política partidista |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 + GDScript *(ya configurado)* — 2D excelente, gratis, ideal para un solo dev principiante |
| **Key Technical Challenges** | Pathfinding/navegación de NPCs por el edificio; simulación de colas/flujo; arquitectura de datos escalable a muchas comisarías; guardado/carga |
| **Art Style** | 2D cenital/isométrico (look 2.5D), limpio y serio |
| **Art Pipeline Complexity** | Medium (2D custom) — **el mayor riesgo de esfuerzo** |
| **Audio Needs** | Moderate (ambiente de comisaría, radio policial, avisos 091) |
| **Networking** | None (single-player) |
| **Content Volume** | MVP = 1 oficina; visión = decenas de comisarías y muchas unidades |
| **Procedural Systems** | Ciudadanos, casos e incidentes generados proceduralmente, mezclados según turno y día/noche |

---

## Risks and Open Questions

### Design Risks
- El bucle de flujo puede volverse repetitivo sin suficiente variedad de eventos/ciudadanos.
- El sistema de influencia/dilemas puede sentirse injusto o "premiar la corrupción" si no se equilibra con muchísimo cuidado.

### Technical Risks
- Rendimiento del pathfinding/simulación con muchos NPCs a la vez en Godot 2D.
- Arquitectura de datos para escalar de una oficina a muchas comisarías sin rehacer todo.

### Market Risks
- Nicho con competencia establecida (Prison Architect, This Is the Police). Diferenciador = tema español realista del CNP.

### Scope Risks
- "Toda España" es enorme; riesgo real de no terminar. Mitigado por MVP mínimo + escalera de carrera que trocea el trabajo.
- El arte realista 2D consume tiempo estando en solitario.

### Open Questions
- ¿El flujo de una sola oficina es divertido por sí solo? → lo resuelve el **prototipo** del MVP.
- ¿Qué modelo exacto de tiempo (tiempo real con pausa) escala bien a comisarías grandes? → prototipo.
- ¿Cómo equilibrar los dilemas de influencia para que sean justos e interesantes? → diseño dedicado + playtest.

---

## MVP Definition

**Core hypothesis**: *"Gestionar el flujo de ciudadanos/denunciantes por una Oficina de Denuncias
(siendo subinspector) es divertido y satisfactorio por sí solo durante 20–30 minutos."*

**Required for MVP**:
1. Una **Oficina de Denuncias** con puestos/ventanillas y sala de espera **construibles** con presupuesto.
2. **Flujo de ciudadanos** generados: trámite de DNI + poner una denuncia (coger turno → esperar → puesto → resuelto).
3. **2–3 agentes** asignables a puestos; una **métrica de eficiencia** (tiempo de espera/satisfacción) y un **presupuesto**.
4. Al menos **un cambio de turno** (o ciclo día/noche) que altere la afluencia.
5. Un **objetivo de eficiencia** que, al cumplirse, dispara el **ascenso** (mensaje de progresión).

**Explicitly NOT in MVP** (defer to later):
- Otras unidades (Seguridad Ciudadana, Policía Judicial, Científica), detenidos + abogados.
- Sala 091 / incidentes en mapa, vehículos y patrullas.
- Sistema de presión e influencia.
- Multi-comisaría y mapa de España.

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | Oficina de Denuncias | Bucle de flujo + construcción + presupuesto + 1 objetivo | Semanas–meses |
| **Vertical Slice** | Una comisaría completa | + unidades, detenidos+abogados, sala 091, vehículos, ascenso a Comisario | Meses |
| **Alpha** | Varios tipos de comisaría | + sistema de influencia + reputación + día/noche completo | Meses |
| **Full Vision** | Comisarías por toda España | + mapa nacional + meta-progresión | 1–2+ años |

---

## Next Steps

> **Ruta recomendada: Prototipo primero (Path B)** — el bucle de flujo aún no está probado y es
> un primer juego, así que validamos que es divertido antes de escribir GDDs extensos.

- [x] Configurar el motor (`/setup-engine`) — **hecho**: Godot 4.6 + GDScript.
- [ ] **Prototipar el núcleo** (`/prototype gestion-de-flujo-oficina-denuncias`) — construir en 1–3 días un prototipo desechable del MVP para ver si es divertido.
- [ ] Si el prototipo PROCEDE → `/art-bible` (definir la identidad visual 2D antes de producir arte).
- [ ] Descomponer en sistemas (`/map-systems`) — mapa de dependencias y orden de diseño.
- [ ] Diseñar cada sistema (`/design-system [sistema]`) — GDD guiado, empezando por el flujo de la Oficina de Denuncias.
- [ ] Validar el concepto (`/design-review design/gdd/game-concept.md`).
- [ ] Planificar el primer sprint (`/sprint-plan new`).
