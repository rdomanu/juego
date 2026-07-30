# Backlog de pulido visual y de UX

> **Qué es esto**: la lista donde se apunta el feedback **estético / de presentación** que sale de las
> demos, en el momento en que se dice, para que llegue entero a `/ux-design` y al **UI/HUD #11** en vez
> de perderse en el fichero de sesión.
>
> **Regla de fase (Producción)**: el feedback de **comportamiento** se implementa el mismo día; el
> feedback **estético** se apunta aquí. Todo el visual actual es **andamio declarado** — formas y
> colores planos hechos por código, sin arte, pensados para que la simulación se pueda ver y probar.
>
> **Creado**: 2026-07-25 (acción #3 de la retrospectiva del Sprint 2).
> **Consumen este fichero**: `/ux-design` (specs de pantalla), UI/HUD #11, art bible §5-9.

---

## Feedback del usuario — 2026-07-25 (desglose de "hay que pulir cosas de diseño")

Sus palabras: *"son los paneles de construcción, de empleados, el panel de abajo que tiene que ser
intuitivo como los tycoon, las skills que aparecen deben ser como una barra para ver dónde está el
máximo y el mínimo, ahora no sé si 4 es mucho o es poco, si es sobre 5 puntos o sobre 100"*.

| # | Petición | Tipo | Estado |
|---|----------|------|--------|
| **U1** | **Atributos del personal como BARRA**, no como número: que se vea de un vistazo dónde está el mínimo y el máximo. *"No sé si 4 es mucho o poco, si es sobre 5 o sobre 100"* | **Legibilidad — funcional** | ✅ **Resuelto 2026-07-25** (barra de 5 casillas llenas/vacías + el número; ver nota abajo) |
| **U2** | **Panel de construcción** más intuitivo | Estética + UX | ⬜ Para `/ux-design` |
| **U3** | **Panel de empleados** (plantilla/mercado) más intuitivo | Estética + UX | ⬜ Para `/ux-design` |
| **U4** | **La barra de abajo (HUD) tiene que ser intuitiva "como los tycoon"** | Estética + UX | ⬜ Para `/ux-design` — es la petición marco: referencia clara al género |
| **U5** | *(implícito en U1)* Toda cifra que el jugador tenga que juzgar necesita su **escala visible**: no basta el número, hace falta saber respecto a qué | **Principio de UX** | 🔸 Aplicado en el HUD de satisfacción y en el panel de calibración; pendiente el resto |
| **U6** | *"No hay panel de guardado, ni de personal accesible como el de construir"* (2026-07-26) | **Funcional — faltaba acceso** | ✅ **Resuelto 2026-07-26**: barra de acciones con botones visibles **Personal (P)**, **Guardar (F5)**, **Cargar (F9)** + aviso del último guardado. El guardado EXISTÍA pero no había forma de invocarlo desde el juego |
| **U8** | *"En el diseño habría que poner como un icono para saber a qué viene cada uno: documentación, TIE, sustracción, pérdida…"* (2026-07-26) | **Legibilidad — requisito de diseño** | ⬜ Para `/ux-design` + art bible. **Especificado abajo** |
| **U7** | *"Lo de calibrar debe ser un menú interno solo para el desarrollador"* (2026-07-26) | Herramienta DEV | ✅ **Resuelto 2026-07-26**: panel de calibración (F1) que **solo se instancia en desarrollo** (`OS.has_feature("editor")`); en un build exportado no existe ni el botón |

> **Nota sobre U1 (resuelto en caliente):** el dato ya decía "4/5", pero en texto pequeño y gris no se
> leía como escala. Se sustituyó por una **barra de 5 casillas** (llenas/vacías) con el número al lado —
> el máximo se ve sin leer. Es **legibilidad funcional**, no adorno: sin saber la escala no se puede
> decidir a quién contratar, que es la decisión que ese panel existe para tomar. El resto (U2-U4) sí es
> rediseño y espera a `/ux-design`.

> **U5 como criterio de aceptación de `/ux-design`:** ningún indicador numérico del HUD o de los paneles
> se da por bueno si el jugador no puede saber, mirándolo, si ese número es bueno o malo.

### U8 — Icono de "a qué viene" por ciudadano (requisito de diseño)

Hoy el color del muñeco solo distingue **servicio** (azul Documentación / naranja ODAC / azul claro
TIE): mirando la sala no se sabe si esa persona viene a renovar el DNI o a denunciar una agresión. El
jugador necesita **leer la sala de un vistazo** para decidir a quién colar, qué ventanilla abrir o si
una urgencia lleva demasiado esperando.

**Los 17 tipos que hay que cubrir** (ids reales del catálogo — cualquier icono debe salir de ahí, no
del código):

| Servicio | Tipos |
|---|---|
| **Documentación** (3) | `dni` · `pasaporte` · `tie` |
| **ODAC — Prioritarias** | `viogen` · `desaparecidos` · `agresion_sexual` · `robo_violencia` |
| **ODAC — Normales** | `hurto_robo` · `estafa` · `ciberestafa` · `danos` · `amenazas` · `lesiones` · `okupacion` · `perdida_sustraccion` · `permiso_viaje` · `reclamacion` |

**Criterios de aceptación para `/ux-design`:**
- Legible **a distancia de cámara y sin pasar el ratón** (regla del proyecto: nada hover-only).
- Debe distinguirse **la urgencia** además del tipo: una VioGén y un extravío de DNI no pueden pedir
  la misma atención visual (el peso de prioridad ya existe en el modelo: 2.5 frente a 1.0).
- **Convive con la barra de paciencia** que ya va sobre la cabeza: hay que resolver el conjunto
  (¿icono al lado de la barra? ¿en el cuerpo? ¿ambos en una "chapa"?), no cada pieza por su cuenta.
- Respaldo no-cromático (no basta el color) y nombre completo disponible en el **menú contextual**,
  que ya lo muestra.
- El `reclamacion` merece distinguirse: es trabajo que **generó el propio jugador** al dejar irse a
  alguien; verlo acumularse en la sala es parte del castigo.

## Feedback del usuario — 2026-07-30 (muros libres)

| # | Petición | Tipo | Estado |
|---|----------|------|--------|
| **U9** | **El trazado de muros "va mejor, no del todo bien"** tras clavar el arrastre a un eje. El usuario no concretó qué sigue fallando y pidió continuar con las fases. **Volver a preguntarle qué le chirría exactamente** antes de dar la herramienta por buena — es la herramienta con la que se construye toda la comisaría, así que la comodidad importa más que en cualquier otro sitio | **Usabilidad — funcional** | ⬜ Pendiente de concretar con el usuario |

## Andamios conocidos que hay que sustituir

Esto no es feedback: es deuda visual declarada, ya identificada por el equipo.

| # | Qué | Estado actual (andamio) | Adónde va |
|---|-----|------------------------|-----------|
| A1 | **Ciudadanos** | Dos rectángulos de color (torso + cabeza), color por servicio: azul Doc, naranja ODAC, azul claro TIE | Art bible §5 + sprites |
| A2 | **Policías** | Igual, torso azul marino + nombre en texto plano encima | Art bible §5 + sprites |
| A3 | **Salas y suelo** | Rectángulos de color sobre rejilla, sin textura ni mobiliario | Art bible §4 (color) + tileset |
| A4 | **Asientos** | Marcados solo por la celda; sentarse = pisar la celda | Sprite de banco con orientación |
| A5 | **HUD (barra inferior)** | Texto plano en una barra estilo tycoon: saldo, colas, atendiendo, FPS, puerta Doc, satisfacción, reclamaciones y botonera de acciones | UI/HUD #11 tras `/ux-design` |
| A6 | **Rótulos de estado de puesto** | Texto + color sobre el mostrador (CERRADO / SIN AGENTE / LIBRE / EN CAMINO / ATENDIENDO) | UI/HUD #11 — ¿iconos? ¿globo? |
| A7 | **Panel de personal (tecla P)** | Panel construido por código: dos columnas de tarjetas + resumen de cobertura | UI/HUD #11 — pantalla de plantilla real |
| A8 | **Barra de construcción** | Botones de texto en `HFlowContainer` sobre el HUD | UI/HUD #11 — toolbar con iconos |
| A9 | **Cola exterior** | Los que no caben se reparten en vertical en la calle, sin forma de "fila" | Idea apuntada: **editor de fila/cola** tipo Planet Coaster (backlog, no MVP) |

## Juice y feedback pendiente (no bloquea)

| # | Qué | Nota |
|---|-----|------|
| J1 | Los funcionarios **desaparecen** al cerrar el puesto | Debería **caminar hasta la puerta** e irse (enmienda del horario, flujo-006) |
| J2 | El trámite completado no tiene **remate visual ni sonoro** | El saldo sube en el HUD y ya; candidato a "ping" institucional + número flotante |
| J3 | La **llamada de turno** no se anuncia | GDD Flujo lo pide: "ping" de ventanilla, prioridad media-alta |
| J4 | ~~Sin señal de ánimo/paciencia en los ciudadanos~~ | ✅ Hecho en paciencia-008: barrita de ánimo sobre la cabeza (66/33) |

## Restricciones que hay que respetar al pulir

- **Texto siempre, el color solo refuerza** (respaldo para daltónicos) — regla ya aplicada en rótulos,
  chips del panel y estados.
- **Ratón, pero sin interacciones solo-hover**: para poder añadir mando/táctil más adelante sin rediseñar.
- **Nada de arte antes del art bible §5-9** (condición 2 del gate a Producción).
- **`/ux-design` + `/ux-review` antes de las historias de UI** (condición 3 del gate).
- Los Control decorativos del mundo van con `MOUSE_FILTER_IGNORE` o se tragan los clics (bug ya visto
  dos veces).
