# Panel de ODAC — vista de conjunto (F4, última pieza)

**Maqueta aprobada**: `design/ux/maquetas-menu-2026-08/maqueta_odac.png` (script hermano con las
decisiones). **Implementación**: `src/main/panel_odac.gd`. **Aprobación del usuario**: 2026-08-18.

## Concepto

La ficha de ventanilla ya cubre el detalle individual (casillas tipo a tipo): este panel es la
**vista de conjunto** de la Oficina de Denuncias — lo que ninguna ficha puede saber sola. Modal
compacto CENTRADO y autoajustado al contenido (con el patrón de DOS PASADAS de
`modal_comisario.gd` para el alto: el mínimo de un Label con autowrap depende del ancho ya
repartido).

## Zonas

| Zona | Contenido | Fuente |
|---|---|---|
| Cabecera | "ODAC" + "Cerrar (O)" | — |
| EN COLA · ODAC | Reparto por prioridad: "N urgentes esperando" (ámbar) · "N administrativas" (gris) | `Flujo.personas_de_cola` + `ODAC.es_prioritaria` |
| DEDICACIÓN DE LA OFICINA | Chips resumen (ventanillas por modo, activo resaltado) | `ODAC.modo_de` por ventanilla |
| SIN COBERTURA | Banner rojizo con chips de los tipos sin ninguna ventanilla — SOLO si hay | `ODAC.denuncias_sin_cubrir()` |
| VENTANILLAS ODAC | Por ventanilla: nombre visible, operador, estado, pastilla de modos rápidos de 1 clic (honesta: en SUBCONJUNTO ninguno marcado) y "A MEDIDA · elegidas N de 14" con chips; nota que remite a la ficha para el tipo a tipo | `fijar_modo` (ordena) |

## Accesos

- Tecla **O** (como siempre).
- **NUEVO** (petición del usuario 2026-08-18): opción "Dedicación de ODAC" en el menú contextual
  de la sala cuando la sala pinchada es de tipo ODAC.

## Notas

- ADR-0001 (la UI lee y ordena); nombres visibles vía el helper único; coma castellana.
- En la misma pasada: emojis eliminados de los menús contextuales (regla del proyecto) y
  corregido el comentario desactualizado "13 denuncias" de `odac.gd` (el catálogo real tiene 14).
- Tests: `panel_odac_test.gd` (10) + `main_menu_sala_odac_test.gd` (5). Sonda:
  `tools/_diag_panel_odac.{gd,tscn}`.
