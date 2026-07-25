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

## Pendiente de recoger del usuario

- [ ] **"Hay que pulir cosas de diseño"** (2026-07-25, al firmar el sign-off de flujo-008). Sin
      detallar todavía → **preguntar y desglosar aquí** antes de arrancar `/ux-design`.

## Andamios conocidos que hay que sustituir

Esto no es feedback: es deuda visual declarada, ya identificada por el equipo.

| # | Qué | Estado actual (andamio) | Adónde va |
|---|-----|------------------------|-----------|
| A1 | **Ciudadanos** | Dos rectángulos de color (torso + cabeza), color por servicio: azul Doc, naranja ODAC, azul claro TIE | Art bible §5 + sprites |
| A2 | **Policías** | Igual, torso azul marino + nombre en texto plano encima | Art bible §5 + sprites |
| A3 | **Salas y suelo** | Rectángulos de color sobre rejilla, sin textura ni mobiliario | Art bible §4 (color) + tileset |
| A4 | **Asientos** | Marcados solo por la celda; sentarse = pisar la celda | Sprite de banco con orientación |
| A5 | **HUD (barra inferior)** | Texto plano en una barra estilo tycoon: saldo, colas, atendiendo, FPS, puerta Doc | UI/HUD #11 tras `/ux-design` |
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
| J4 | Sin señal de **ánimo/paciencia** en los ciudadanos | Llega con Paciencia #10 (umbrales 66/33 ya definidos) |

## Restricciones que hay que respetar al pulir

- **Texto siempre, el color solo refuerza** (respaldo para daltónicos) — regla ya aplicada en rótulos,
  chips del panel y estados.
- **Ratón, pero sin interacciones solo-hover**: para poder añadir mando/táctil más adelante sin rediseñar.
- **Nada de arte antes del art bible §5-9** (condición 2 del gate a Producción).
- **`/ux-design` + `/ux-review` antes de las historias de UI** (condición 3 del gate).
- Los Control decorativos del mundo van con `MOUSE_FILTER_IGNORE` o se tragan los clics (bug ya visto
  dos veces).
