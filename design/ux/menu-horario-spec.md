# Menú de Horario (F3)

**Maqueta aprobada**: `design/ux/maquetas-menu-2026-08/maqueta_horario.png` (script hermano con
geometría/colores/fórmulas). **Implementación**: `src/main/panel_horario.gd`.
**Aprobación del usuario**: 2026-08-18 tras auditoría de Fable (el texto del efecto del precio se
corrigió antes de enseñarla: la mecánica real es "pagar mejor cansa menos").

## Concepto

Modal hermano del Tablón de Destinos (velo, tarjeta grande, layer sobre la brújula, recolocación
al mostrar y al redimensionar; se abre/cierra con H y se puede usar en pausa). Tres decisiones
grandes a la izquierda, las ventanillas de tarde a la derecha, y TODA consecuencia visible antes
de confirmar nada.

## Zonas

| Zona | Contenido | API que ordena |
|---|---|---|
| Cabecera | Estado del servicio y demanda (punto de color + texto), banner del COMUNICADO DE LA DIVISIÓN solo si hay `evento_activo()` (texto real del evento y tope ampliado) | — (solo lectura) |
| Horario de cierre | Valor grande "Cierra a las HH:MM", slider de jornada base a `tope_autorizado()` con MARCA del tope ordinario cuando un evento lo amplía; consecuencia en rojo "+X,X h extra × N agente[s] → PEONADA Y €/día" (o "Sin horas extra…" en llano) | fijar hora de cierre (Documentación) |
| Precio de la hora extra | Valor grande "N €/hora" (convenio·tope), slider; consecuencia EN EL SENTIDO REAL: "A este precio la hora extra cansa un N % más que una normal · al tope cansaría como una normal" (`generosidad_peonada()`: a convenio cansa lo máximo, al tope como una normal) | fijar peonada €/hora |
| Última admisión | Valor grande HH:MM derivado, slider 0-30 min, ayuda "exprimir vs cuidar" | fijar margen de última admisión |
| Ventanillas de tarde | Una tarjeta por ventanilla con NOMBRE VISIBLE (`PanelPersonal.nombre_visible_de_puesto` — fuente única, sin duplicar la tabla), operador real vía Personal, casilla "se queda por la tarde" y botón manual Abrir/Cerrar (DOS acciones reales distintas), línea de coste o "cierra a las HH:MM"; debajo, COSTE TOTAL DE PEONADA HOY (tarjeta rojiza, `formato_euros`) | `fijar_puesto_de_tarde` · `Flujo.abrir_puesto`/`cerrar_puesto` |

## Reglas

- ADR-0001: la UI lee y ordena por la API pública; las cifras de consecuencia se calculan con las
  MISMAS fórmulas del Core (nunca re-implementadas con otro criterio).
- Dinero con `KitUIComisario.formato_euros`; decimales con coma castellana; "1 agente" singular.
- Tests: `tests/unit/ui/panel_horario_test.gd` (12: estructura, nombres visibles, órdenes de los
  3 sliders y de las dos acciones de ventanilla, textos de consecuencia con cifras exactas, tope
  ampliado con marca). Sonda: `tools/_diag_panel_horario.{gd,tscn}` (2 fases: recién abierto y
  con horas extra + evento activo).
- Defecto conocido compartido con el Tablón: a anchos de ventana pequeños (<1400) la columna
  derecha desborda — pendiente de una pasada de responsividad conjunta.
