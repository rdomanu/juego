# Spec — Panel de construcción v2 (F0/F1, 2026-08-15)

Implementación del nuevo lenguaje visual de UI aprobado por el usuario. Maquetas de referencia:
`design/ux/maquetas-menu-2026-08/menu_v2_moderno.png` (panel solo) y
`menu_v3_completo.png` (pantalla completa, HUD superior + panel). Sustituye a la barra inferior
"Apéndice B" del reskin anterior (`plan-maestro-ui.md`, 2026-08-07).

## F0 — Kit reutilizable

`src/ui/kit_ui_comisario.gd`, sección `KIT MODERNO` (prefijo `MOD_`/`moderno_*`): paleta clara
(panel 238,243,249 · tarjetas blancas · tinta 36,48,66 · acento azul 47,108,224 · verde/ámbar/rojo
de estado), y fábricas `moderno_tarjeta()`, `moderno_pastilla()`, `moderno_chip_estado()`,
`moderno_barra_progreso()`/`moderno_actualizar_barra_progreso()`, `moderno_boton_icono()`,
`toggle_segmentado()`. Conviven EN PARALELO con el kit pixel-art del piloto de Summer
(`VARIANTE_*`/`ICONOS`, sin tocar): el HUD superior y los modales siguen en la paleta navy hasta que
se decida migrarlos.

**Fuente**: se conserva Kenney Future (`assets/fonts/kenney_future.ttf`, la del `Theme` del kit) —
la maqueta prototipa con Segoe UI, pero la tipografía definitiva es una decisión de ARTE pendiente,
fuera del alcance de esta tarea (queda anotada aquí para que arte la retome).

## F1 — Panel de construcción

Reemplaza el cuerpo de `ModoConstruccion._crear_ui()` (`src/main/modo_construccion.gd`). El "cerebro"
NO cambia: `_botones_herramienta`, `_tarjetas_por_categoria`, `_categoria_de_herramienta`,
`_pestanas_categoria`, `CATEGORIAS`, `_fijar_herramienta`, `activar_con_herramienta`,
`_sprite_de_herramienta` y todo el sistema de fantasma/pincel de muro siguen intactos — solo cambia
CÓMO se construyen y pintan los controles.

### Zonas

- **Fila superior**: buscador (`_buscador`, `LineEdit` en pastilla, filtra en vivo con
  `text_changed`) + toggle Función/Sala (`toggle_segmentado`). Sin pastilla de presupuesto (vive en
  el HUD superior desde la fase 2, fuera de esta tarea).
- **Columna de categorías** (`_columna_categorias`, izquierda): las 5 categorías REALES de siempre
  — Salas · Muebles · Muros y suelos · Zonas · Herramientas — como pastillas verticales, la activa
  en azul de acento. **Decisión**: la maqueta ilustra otra taxonomía de ejemplo (Asientos,
  Almacenaje, Equipos, Aparatos, Decoración) que NO existe en el catálogo real
  (`Comodidad.familia` es ciudadano/funcionario/descanso/iluminación — no una categoría de tienda);
  usar las 5 categorías reales es la lectura fiel de la instrucción "deriva las categorías del
  catálogo real... que nada de lo que hoy se puede hacer se quede sin sitio". Las herramientas de
  construcción existentes (muro, puerta, ventana, pintar pared/suelo, zonas, Demoler) siguen todas
  con sitio.
- **Rejilla de tarjetas** (`_fila_tarjetas`, centro): `GridContainer` (6 columnas) dentro de un
  `ScrollContainer` VERTICAL — cambio respecto al reskin anterior (una fila horizontal con flechas
  ◀/▶). Con el buscador reduciendo lo visible, una sola fila ya no encaja el catálogo completo; el
  scroll vertical con su barra arrastrable es la afordancia "visible, no solo rueda" que pedía el
  proyecto. Cada tarjeta: miniatura (sprite real del catálogo vía `_sprite_de_herramienta`), nombre,
  precio, con borde de acento cuando está seleccionada. **Alto NO fijo** (regla dura del proyecto:
  ningún rótulo cortado) — el nombre envuelve a 2 líneas y la tarjeta crece si hace falta, nunca
  recorta.
- **Ficha del seleccionado** (`_panel_ficha`, derecha): sprite grande, nombre, precio, huella
  (`LogicaPanelConstruccion.texto_huella`, celdas/plazas REALES del catálogo), y tres barras —
  Confort (`aporte`/7), Nota al salir (`factor_satisfaccion` → "+N%"), Paciencia extra (derivada del
  confort, `k_confort=0.02` → "+N%", mismo `k_confort` que `Paciencia.mult_comodidad_de`). Las tres
  barras SOLO aparecen si el objeto es una `Comodidad` de verdad (duck-typing con
  `"factor_satisfaccion" in comodidad`); un puesto o una sala no las muestra.
- **Herramientas** (columna de iconos, extremo derecho): Mover y Clonar — **próximamente**, no
  existen como mecánica, botones deshabilitados con tooltip; Demoler — existe, mismo id `&"demoler"`
  de siempre, ahora vive aquí en vez de anclado a la fila de pestañas.

### Datos → tarjeta → ficha

`_anadir_herramienta(texto, id, es_sala, categoria, icono_id, textura_miniatura, ficha)` guarda
`ficha: {"precio", "huella", "extra", "comodidad"}` en `_datos_ficha[id]`, leído por la tarjeta (precio)
y por `_actualizar_ficha` (todo lo demás) — una sola fuente, sin recalcular en dos sitios.
Precio de sala: "Desde X €" + nota "+Y €/celda" (el coste real depende del área dibujada,
`Construccion.coste_por_celda × área`) — nunca un número fijo engañoso.

## Próximamente (documentado, no implementado en esta pasada)

- **Toggle "Sala"**: deshabilitado — agrupar por tipo de sala no está modelado en el catálogo.
- **Mover / Clonar**: deshabilitados con tooltip — no son mecánicas existentes hoy.
- **Categorías de tienda tipo maqueta** (Asientos/Almacenaje/Equipos/Aparatos/Decoración): requeriría
  un campo nuevo de categorización visual en `Comodidad`/`TipoPuesto` — decisión de diseño de datos,
  fuera del alcance de UI.
- **Tipografía definitiva**: pendiente de arte.

## Tests (lógica extraída, pura)

`src/ui/logica_panel_construccion.gd` + `tests/unit/ui/logica_panel_construccion_test.gd`: filtro
del buscador (`tarjeta_visible`/`coincide_busqueda`), huella (`texto_huella`), derivaciones de la
ficha (`fraccion_confort`, `porcentaje_nota_al_salir`, `porcentaje_paciencia_extra`).
`tests/unit/main/modo_construccion_panel_v2_test.gd`: el cableado real (mapeo catálogo→ficha,
buscador sobre botones reales, qué barras se muestran/ocultan).
