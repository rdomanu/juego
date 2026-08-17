# Menú de Personal — "El Tablón de Destinos" (F3)

**Maqueta aprobada**: `design/ux/maquetas-menu-2026-08/maqueta_personal.png` (script hermano
`maqueta_personal.py` con geometría y colores exactos). **Implementación**: `src/main/panel_personal.gd`.
**Aprobación del usuario**: 2026-08-17 ("me parece bien todo") tras 3 iteraciones de maqueta.

## Concepto

La pantalla se organiza alrededor de los **puestos** (lo que el jugador gestiona de verdad), no de
listas de personas. Jerarquía de uso: puestos > banquillo > academia > detalle. El gesto principal
es **arrastrar**; toda acción de arrastre tiene alternativa de un clic (regla del proyecto: nada
solo-arrastre, para gamepad/táctil futuros).

## Zonas

| Zona | Contenido | Interacción |
|---|---|---|
| Cabecera | Título, instrucción, Cerrar (P), saldo/nómina (formato `KitUIComisario.formato_euros`), resumen de cobertura coloreado, aviso de rechazos | — |
| PUESTOS (izq.) | Un slot por puesto registrado en Flujo, agrupados por servicio con subtítulo. Slot ocupado: avatar, nombre, chip de estado, mini-cansancio, salario. Vacante: borde punteado "Suelta aquí" | Drop target; clic selecciona al ocupante |
| BANQUILLO | Contratados sin puesto, tarjetas compactas | Arrastrables; clic selecciona |
| ACADEMIA | Candidatos del mercado ("la promoción se renueva cada 3 días") con "Contratar — N €/día" | Botón contrata; arrastrar a slot vacante = contratar + asignar |
| FICHA (inferior) | El seleccionado: atributos 1-5 (+Mando solo Oficial), cansancio 0-100 (ámbar 70-90, rojo 90+, siempre con cifra), salario, pausas | Botones según estado: "Mover a ▾" (desplegable propio del kit), Desasignar, Despedir, Contratar |

## Arrastre (drag & drop nativo de Godot)

- Durante el arrastre: slots **compatibles** iluminados (borde acento + fondo suave); los no
  válidos **atenuados con el motivo escrito** ("no compatible", "su titular está de baja"…).
- Un rechazo nunca es silencioso: el motivo va al aviso de cabecera.
- Mover un asignado = `desasignar()` + `asignar()` (si el segundo paso falla, se le devuelve a su
  puesto anterior y se avisa).
- Candidato a slot = `contratar()` + `asignar()`; si Economía rechaza el sueldo, motivo visible.
- **Sobre un puesto OCUPADO** (2026-08-17, 2ª ronda de prueba del usuario): compuesto con la API —
  **intercambio** (el desplazado vuelve al puesto de origen del que llega) o **sustitución** (sin
  origen viable, el desplazado pasa al banquillo, avisado). El titular de baja no se desplaza.
- **Línea de impacto** en el slot válido y en las opciones del desplegable: "Rapidez 4,0 → 3,5 ·
  Trato 3,0 → 3,2" — el antes/después de las **medias del servicio destino** (`_texto_impacto`;
  en movimientos dentro del mismo servicio simula el intercambio completo). Rapidez y Trato son
  los atributos que rinden en el puesto; Salud/Motivación van por bajas/cansancio.

## Norma de nombres visibles (vale para TODO el juego)

Ningún id técnico en pantalla. Fuente única: `PanelPersonal.nombre_visible_de_puesto(id, tipo,
ordinal)` sobre la tabla `PREFIJO_POR_TIPO_PUESTO` (DNI/TIE/ODAC/SEG + ordinal por orden de
registro). Un tipo fuera de la tabla enseña el id técnico tal cual, a propósito: delata la tabla
incompleta en la primera captura.

## Contrato técnico

- ADR-0001: la UI **lee** y **ordena** por la API pública de `Personal`
  (`contratar/asignar/desasignar/despedir`); nunca muta estado.
- `Main._abrir_personal()` → `visible = true` + `_reconstruir()` (foto fresca; sin refresco por frame).
- CanvasLayer en `layer = 12` (por encima de la brújula de depuración, layer 10).
- Recolocación explícita del modal al mostrar + `viewport.size_changed` (gotcha de contenedores
  ocultos, mismo patrón que `ModoConstruccion._recolocar_panel`).
- Tests: `tests/unit/ui/panel_personal_test.gd` (nombres visibles, estructura, órdenes).
  Sonda visual: `tools/_diag_panel_personal.{gd,tscn}` + `tools/captura_ventana.ps1`.
