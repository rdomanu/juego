# Referencia: menús de construcción (capturas del usuario, 2026-08-02)

**Origen de las capturas**: capturas de un tycoon comercial (por la interfaz y los textos, de la
serie *Two Point*, localizado al español) guardadas por el usuario en `capturas/`. Se usa como
inspiración de PATRONES de interfaz — nada de esto es contenido de Comisario, la sala que aparece
("Laboratorio de ciencias") es del juego de referencia, no del nuestro. Este documento describe
SOLO lo observable en las imágenes; cuando un icono o un número no se puede identificar con
certeza, se dice explícitamente en vez de inventar una función.

Capturas analizadas a fondo: `objetos.PNG`, `construccion 2.PNG`, `construccion.PNG`,
`entorno.PNG`, `inicio.PNG`. Al final hay una mención breve de `contratar.PNG`, `clientes.PNG` y
`Avisos de progreso.PNG` como referencia futura.

---

## 1. Acceso: barra inferior de herramientas

En las cuatro capturas de gameplay (`objetos.PNG`, `construccion.PNG`, `construccion 2.PNG`,
`entorno.PNG`) hay una barra fija en la esquina inferior izquierda con iconos redondos. De
izquierda a derecha:

- Dos iconos sueltos, algo separados del resto (uno con aspecto de mapa/lápiz, otro de lista con
  líneas horizontales) — su función no se puede confirmar solo con estas capturas.
- 🪓 **Hacha/martillo** — abre el panel **CONSTRUIR** (salas). Se ve resaltado en turquesa cuando
  ese panel está abierto (`construccion.PNG`).
- 🪑 **Silla** — abre el panel **OBJETOS** (mobiliario y decoración). Se ve resaltado en naranja
  cuando ese panel está abierto (`objetos.PNG`).
- 🌳 **Árbol** — entorno/jardín exterior.
- 🧍➕ **Persona con un "+"** — contratar personal (confirmado por título en `contratar.PNG`, ver
  §7).
- 📖 **Libro abierto** — función no confirmable con certeza; por icono podría ser un catálogo o
  diario, pero no se abre en ninguna de las capturas analizadas.
- 🧍 **Persona (sin "+")** — función no confirmable con certeza.
- 🏛 **Edificio con columnas** — función no confirmable con certeza; por icono podría estar
  relacionado con prestigio o instituciones.
- 👁 **Ojo** — función no confirmable con certeza; por icono podría ser un modo de vista/cámara.

**Patrón importante para reutilizar**: cada botón es un interruptor (toggle) que abre SIEMPRE el
panel en el mismo sitio (pegado al borde izquierdo, con la misma cabecera de color) y se marca
visualmente como activo (resaltado) mientras su panel está abierto. Es el mismo mueble de acceso
para construir, amueblar, entorno y contratar — un jugador que aprende uno, aprende los cuatro.

---

## 2. Flujo de construir una sala

Reconstruido a partir de `construccion.PNG` (elegir y trazar la sala) y `construccion 2.PNG`
(amueblarla), que parecen ser dos momentos consecutivos del mismo flujo:

1. Clic en el icono de martillo de la barra inferior → se abre el panel **CONSTRUIR**, con la
   pestaña **"Salas"** activa (hay una segunda pestaña con icono de diploma/certificado junto a
   ella, sin abrir en las capturas — función no confirmable).
2. La lista de salas muestra nombre + precio (ej. "Laboratorio de ciencias — 18.200 €"); la fila
   elegida queda resaltada en naranja. Hay buscador ("Buscar") encima de la lista, igual que en el
   panel de objetos.
3. En el suelo aparece una huella AZUL semitransparente con volumen (no solo un contorno plano)
   del tamaño de la sala, con un pequeño cubo-ancla marcado con una X que se arrastra para fijar
   dónde va la sala.
4. Mientras se arrastra, una cabecera contextual arriba de la pantalla muestra en tiempo real:
   el tamaño ("5 × 5"), y una fila de iconos con un asterisco naranja — uno por cada objeto
   OBLIGATORIO de esa sala (puerta, pizarra, máquina) — visibles YA en esta fase, antes de haber
   colocado ningún mueble. Al final de esa fila hay un botón redondo con un check, que por su
   color apagado parece un botón de confirmar aún deshabilitado.
5. Una vez trazadas las paredes, el jugador pasa al panel **OBJETOS**, ahora con la pestaña de
   contexto mostrando el nombre de la sala ("Laboratorio de ciencias") en vez de una categoría
   genérica — es el MISMO panel que en `objetos.PNG`, solo que filtrado a lo que esa sala admite.
6. Ahí coloca los objetos, obligatorios y opcionales (ver §3 y §5); el checklist de asteriscos de
   la cabecera se mantiene visible mientras tanto.
7. El dinero del jugador (esquina inferior derecha de la pantalla) baja al confirmar: en las
   capturas se ve pasar de **500.000 → 492.500** entre `construccion.PNG` y `construccion 2.PNG`,
   ilustrando que el gasto se refleja de inmediato en el HUD.

**Detalles observados pero no confirmados con certeza**:
- Además del dinero de abajo a la derecha, hay una barra verde en la cabecera superior (junto a
  población y prestigio) con otro número que en `construccion.PNG` marca "0" y en
  `construccion 2.PNG` marca "7500". Podría ser un contador de gasto de la sesión de construcción
  en curso, distinto de la tesorería total — no se puede afirmar con solo estas dos imágenes.
- A la derecha de la pantalla hay un panel separado ("Cienciografía", con un objetivo tipo
  "Construye: Laboratorio de ciencias — 0/1"): es el sistema de objetivos/misiones del juego de
  referencia, NO parte del menú de construcción — convive en la misma pantalla pero es otro
  sistema.
- **Nota sobre la miniatura incrustada**: en `construccion.PNG` y `construccion 2.PNG` hay una
  segunda captura más pequeña superpuesta en la esquina inferior derecha, con un panel "ITEMS" en
  inglés. Es un añadido del propio usuario (un pegote suyo para su propia referencia), no forma
  parte de la interfaz del juego — se menciona aquí solo para que no se confunda con UI real.

---

## 3. Panel de objetos — anatomía

Basado principalmente en `objetos.PNG`, con partes confirmadas también en `construccion 2.PNG`:

- **Cabecera**: banda de color turquesa con icono de silla + título "OBJETOS" a la izquierda;
  botón de cerrar (X sobre fondo rojo) al final de la banda.
- **Pestaña de contexto**: justo debajo de la cabecera, una pestaña con forma de nota adhesiva
  muestra el filtro activo — "Objetos de pasillo" en modo libre, o el nombre de la sala
  ("Laboratorio de ciencias") cuando se está amueblando una sala recién construida. Es el mismo
  panel reutilizado; solo cambia qué lista.
- **Controles junto a la pestaña**: 3 botones cuadrados pequeños a la derecha de la pestaña
  (icono de flecha circular, icono de hoja/página con doblez, icono de flechas arriba-abajo).
  Por posición y forma encajan con controles de rotación/orientación del objeto que se va a
  colocar, pero la función exacta de cada uno de los tres no se puede confirmar solo con una
  imagen estática.
- **Buscador**: caja blanca con lupa y placeholder "Buscar", debajo de la pestaña de contexto.
  Aparece igual en el panel CONSTRUIR.
- **Rejilla de tarjetas** (3 columnas): cada tarjeta tiene:
  - Miniatura del objeto sobre fondo celeste.
  - Banda verde en la parte inferior con el precio (ej. "$ 3.500").
  - Estrella pequeña en la esquina superior izquierda (favorito; gris = no marcado como favorito).
  - En algunas tarjetas, un icono pequeño tipo etiqueta/nota en la esquina inferior derecha de la
    miniatura (visto en el sofá, la planta y un objeto de 2.500) — función no confirmable, podría
    señalar "nuevo" u otra propiedad.
- **Objetos bloqueados**: conviven en la MISMA rejilla que el resto (no se separan en otra
  pestaña), pero con la miniatura sobre fondo GRIS en vez de celeste y precio "0" en la banda
  verde — en `objetos.PNG` son 4 trofeos al final de la lista.
- **Objetos obligatorios** (visto en `construccion 2.PNG`): la tarjeta suma un asterisco naranja
  en la esquina superior de la miniatura, además de (no en sustitución de) la estrella de
  favorito — ver detalle en §5.
- **Pestañas verticales de categoría**: en el borde izquierdo del panel, fuera de la rejilla, una
  columna de iconos (estrella, pulgar arriba, silla, máscaras de teatro, marco de cuadro, globo de
  diálogo, pieza de puzle, símbolo de infinito). La pestaña activa se resalta en naranja. El
  significado exacto de cada icono de categoría no se puede confirmar solo con la imagen; lo que
  sí es un patrón claro es la POSICIÓN — una barra vertical de categorías siempre a la izquierda
  de la rejilla de tarjetas.

---

## 4. Colocación de un objeto

- Al elegir una tarjeta y mover el ratón sobre el suelo, aparece una huella (contorno) VERDE que
  encaja EXACTO con la rejilla isométrica de celdas: el contorno tiene el tamaño real del objeto
  (por ejemplo, el banco de dos plazas deja un rectángulo alargado, no un cuadrado genérico) — nada
  sobresale de las celdas que el objeto realmente ocupa.
- El mismo patrón de huella verde ajustada a la celda se repite en `construccion 2.PNG` con la
  puerta que se está posicionando dentro del plano azul de la sala.
- Con el objeto ya colocado y seleccionado (visible en `objetos.PNG`, junto al banco colocado),
  aparecen dos iconos flotantes pequeños, en vertical, fuera de la huella:
  - Uno **cian** con una flecha de cuatro direcciones — por forma y posición, parece el control
    para **mover** el objeto ya colocado.
  - Uno **naranja** con forma de gancho/imán — función no confirmable con certeza; un candidato
    razonable es "ajuste automático a la rejilla", pero no hay manera de confirmarlo solo con la
    imagen. No se identifica en esta captura un icono claro de "moneda especial".

---

## 5. Objetos obligatorios por sala

- En `construccion 2.PNG` (sala "Laboratorio de ciencias"), 3 de los 6 objetos listados llevan un
  **asterisco naranja** en su tarjeta: la pizarra (600 €), la máquina (10.000 €) y la puerta
  (100 €). Los otros tres —estantería (600 €), monitor (100 €) y planta (150 €)— no lo llevan: son
  opcionales.
- Ese mismo trío de iconos con asterisco se repite en la cabecera superior de la pantalla (junto
  al tamaño "5×5"), como un checklist fijo mientras dura la construcción de la sala — el jugador
  ve de un vistazo qué le falta sin tener que revisar tarjeta por tarjeta en la rejilla.
- El botón de confirmar (icono de check, al final de esa misma fila) tiene aspecto apagado/gris en
  las capturas, lo que sugiere que la sala no se da por terminada hasta que el checklist está
  completo.
- **Nota de diseño — coincide con una mecánica ya diseñada en Comisario**: este patrón (objetos
  obligatorios por sala, verificados antes de dar la sala por construida) es la misma idea que ya
  aparece cerrada en `design/gdd/impresora-documentos-tramite.md`, sección "Decisiones del
  usuario": Documentación necesita 1 puesto (DNI o TIE) + 1 impresora de documentos; ODAC necesita
  1 puesto + 1 impresora. Estas capturas no cambian esa mecánica, pero son una buena referencia de
  CÓMO enseñarla en pantalla (asterisco en la tarjeta + checklist fijo en la cabecera + confirmar
  bloqueado hasta completarlo) para cuando se diseñe la interfaz de esa mecánica.

---

## 6. Propuestas para Comisario (PENDIENTES DE DECISIÓN DEL USUARIO)

Esto es un mapeo de ideas, NINGUNA decidida todavía. Para no dar nada por hecho, así es como
funciona hoy Comisario (comprobado en el código antes de escribir esto, no es una suposición):

- **`KEY_B`** alterna el modo construcción (`ModoConstruccion._alternar_modo`, en
  `src/main/modo_construccion.gd`).
- **`KEY_R`** rota el objeto que se lleva en la mano antes de colocarlo (mismo archivo).
- **Clic derecho sobre una sala** abre un menú contextual (`PopupMenu`, función `_abrir_menu_sala`
  en `src/main/main.gd`): es una LISTA DE TEXTO con emoji (ej. "☕ Máquina de café (180 € +
  1 €/día) · +X min de espera"), que ofrece los puestos de la sala, las comodidades que admite,
  las ventanillas ya construidas y "Demoler esta sala". No es un panel visual con miniaturas.
- **Clic derecho sobre un ciudadano** abre otro menú contextual (colar a alguien en la cola).

Diferencias frente a lo visto en las capturas de referencia, y propuestas abiertas:

1. **Mantener `B` y `R` tal cual** — ya funcionan, el usuario los pidió explícitamente y no chocan
   con nada de lo visto en las capturas (no se observaron atajos de teclado en las imágenes).
   *(Pendiente: sin decisión que tomar aquí, es solo constatar que no hay conflicto.)*
2. **¿Evolucionar el menú de clic derecho de "lista de texto" a un panel con tarjetas** (miniatura
   + precio + asterisco si es obligatoria), como el panel OBJETOS de referencia? Ganaría
   reconocimiento visual pero cuesta más UI/arte que una lista de texto. *(Pendiente de decisión
   del usuario — a valorar frente al alcance de Comisario.)*
3. **¿Añadir un checklist visual de objetos obligatorios en la cabecera** durante la construcción
   de una sala, reutilizando el patrón del asterisco naranja, para cuando se implemente la UI de
   `impresora-documentos-tramite.md`? *(Pendiente de decisión del usuario.)*
4. **¿Añadir buscador y categorías al menú de comodidades** si el catálogo de objetos crece mucho?
   Hoy la lista de Comisario es corta (cabe en un `PopupMenu`); en las capturas el catálogo es
   grande, de ahí el buscador — puede que Comisario no lo necesite todavía. *(Pendiente de
   decisión del usuario.)*
5. **¿Necesita Comisario un botón de "confirmar" explícito** para dar una sala por terminada (como
   el check apagado/activo de las capturas), o basta con que la sala empiece a funcionar en cuanto
   tiene lo obligatorio, sin paso de confirmación aparte (patrón actual, más silencioso)?
   *(Pendiente de decisión del usuario.)*

---

## 7. Otras capturas (referencia futura, no analizadas a fondo)

- **`contratar.PNG`** — panel "CONTRATAR PERSONAL": lista de candidatos en tarjetas a la
  izquierda, ficha de detalle a la derecha (retrato, sueldo, habilidades, rasgos con descripción),
  botones de aceptar (✓ verde) y descartar (🗑 rojo). Referencia futura para el menú de contratar
  personal de Comisario.
- **`clientes.PNG`** — vista de gameplay dentro de una sala con personajes trabajando, sin ningún
  panel de menú abierto. Referencia futura para composición de escena/cámara.
- **`Avisos de progreso.PNG`** — notificación de tipo diálogo en la franja inferior (retrato +
  texto + botón "Siguiente"), estilo similar al mensaje de bienvenida de `inicio.PNG`. Referencia
  futura para el sistema de avisos/notificaciones narrativas.
