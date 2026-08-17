# Ficha de Ventanilla — detalle contextual (F3)

**Maqueta aprobada**: `design/ux/maquetas-menu-2026-08/maqueta_ventanilla.png` (+ script hermano y
`fondo_actual.png`). **Implementación**: `src/main/panel_ventanilla.gd` +
`src/main/marcador_ventanilla.gd`. **Aprobación del usuario**: 2026-08-18.

## Concepto

NO es un modal: es la ficha contextual del clic izquierdo sobre una ventanilla. El mundo sigue
visible y corriendo; la mesa pinchada queda realzada en el mundo (halo + etiqueta con el nombre
visible) mientras la ficha está abierta. Anclada a la derecha, POR DEBAJO del HUD (el saldo
siempre visible) y por encima de la franja de acciones. Se cierra con X, Esc o al demolerse la
ventanilla (seguir enseñando números de un mueble que no existe sería mentir).

## Capas

HUD (1) < ficha (`LAYER_FICHA = 11`, por encima de la brújula de depuración en la 10) <
modales Personal/Horario (12). El realce del mundo es `MarcadorVentanilla`: capa 2D hermana de la
bolsa y-sort (patrón CapaSombras; NUNCA hijo del mueble), z 400, recibe centros YA proyectados
(testeable sin Construcción), dibujo quieto sin parpadeo (regla de accesibilidad de movimiento).

## Secciones (datos 100% del código)

| Sección | Contenido | Fuente/Orden |
|---|---|---|
| Cabecera | Tipo de puesto del catálogo + X; chip "DNI 1 · ESTADO" (nombre visible, punto+texto) | catálogo · `nombre_visible_de_puesto` |
| AHORA MISMO | Trámite en curso, turno nº, min restantes, siguiente llamado; estados vacíos en llano | Flujo |
| QUIÉN LA LLEVA | Agente, atributos, cansancio CON consecuencia ("+N % más lento") | Personal (`mult_cansancio_rendimiento`) |
| EFICACIA | Descompuesta: catálogo ± agente ± equipamiento → duración y ≈atenciones/hora | fórmulas reales del panel |
| EN COLA · SERVICIO | `Flujo.personas_en_cola(servicio)` — etiquetado POR SERVICIO (su grano real) | Flujo |
| QUÉ ATIENDE | Trámites del catálogo; rama ODAC con modos + casillas de denuncia (`fijar_modo`) | ODAC |
| HORARIO DEL SERVICIO | Resumen con la MISMA API que la tecla H + casilla de tarde de ESTA ventanilla | Documentación · `fijar_puesto_de_tarde` |

## Reglas y verificación

- ADR-0001; dinero `formato_euros`; coma castellana; sin "atendidos hoy" (no existe en Flujo).
- Tests: `panel_ventanilla_test.gd` (15) + `marcador_ventanilla_test.gd` (2 — SEPARADO por el
  límite de ~16 KB del escáner de GdUnit4). Sonda: `tools/_diag_panel_ventanilla.{gd,tscn}`.
- Gotchas cazados aquí: asignar `button_pressed` por código no emite `toggled` (tests emiten a
  mano) · `captura_ventana.ps1` necesita `SetProcessDPIAware` (monitor al 125% recortaba la
  CAPTURA, no la UI).
