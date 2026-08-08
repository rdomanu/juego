class_name PaletaPintura
## PaletaPintura — los 30 colores con los que el jugador pinta paredes y suelos (2026-08-04).
##
## Petición del usuario (quick-spec `construccion-pintura-puertas-preview-2026-08-04.md` §2):
## *"repertorio de ~30 colores fácilmente elegibles... Data-driven"*, con la elección concreta de la
## paleta delegada ("o los que veas").
##
## ── POR QUÉ UN SCRIPT DE CONSTANTES Y NO UN `.tres` EN `datos/` ────────────────────────────────
## `datos/` es el catálogo de COSAS DEL JUEGO que se consultan por id a través del autoload `Datos`
## (tipos de sala, puestos, comodidades): cosas con precio, con reglas y con balance detrás. Una
## paleta no es eso — es una constante de PRESENTACIÓN, sin balance, sin coste y sin reglas: 30
## tuplas fijas que nadie va a tunear partida a partida. Meterla en `datos/` obligaría a crear un
## `Resource` nuevo, registrarlo en el autoload y mantener 30 ficheros `.tres` para no ganar nada.
## Sigue siendo data-driven en lo que importa: **ningún color está escrito a mano en la UI ni en el
## dibujo** — todos salen de aquí, y añadir o quitar uno es tocar SOLO esta lista.
##
## ── EL CRITERIO DE LA PALETA: TONOS APAGADOS ───────────────────────────────────────────────────
## 6 familias × 5 tonos. Saturación contenida a propósito: los sprites del pack de mobiliario ya
## traen su propio color, y una pared saturada al 100 % los aplasta (el mismo criterio de "mood
## apagado" que ya seguía el color placeholder de las salas). El PRIMERO es el blanco puro, que es
## además el color POR DEFECTO de toda pared construida (decisión del usuario: muere el color por
## tipo de sala en las paredes).
##
## ── SERIALIZACIÓN ──────────────────────────────────────────────────────────────────────────────
## Los colores viajan al save como **hex html de 6 dígitos** (`Color.to_html(false)`), no como
## objeto: el save del proyecto es JSON puro (ADR-0002 · `modules/save-load.md`) y un `Color` no es
## JSON. `desde_hex`/`a_hex` son el único punto por el que pasa esa conversión.

## El color de una pared recién construida y de cualquier tramo sin pintar: BLANCO.
##
## ⚠️ COMPENSADO, YA NO "ffffff" LITERAL (2026-08-08 — playtest: *"el color blanco es como
## crema"*). Causa raíz: `CicloLuz` (`src/main/ciclo_luz.gd`) tiñe TODO el mundo 2D con
## `CanvasModulate` según la hora — es multiplicativo, así que un blanco puro (1,1,1) EN PANTALLA se
## convierte literalmente en el color de la parada del reloj. En horario de apertura eso es un
## ámbar suave (08:00 → `Color(1.00, 0.95, 0.88)`; 18:00 → `Color(1.00, 0.93, 0.82)`, la más cálida
## de las horas de servicio) — de ahí el "crema" que reportó el usuario. A mediodía (13:00 →
## `Color(1.00, 1.00, 0.99)`) el tinte ya es casi neutro, así que ahí SÍ se veía blanco de verdad.
##
## El hex no se puede "poner blanco" y ya —el HTML de este dato no controla el tinte, que es harina
## de otro costal (Presentation, `CicloLuz`), y esa capa no se toca aquí (es un cambio de DATO, no
## de arte ni de motor). La única palanca disponible en este fichero es sesgar el hex al color
## OPUESTO al que resta el tinte —más frío (menos rojo/verde, más azul)— para que el PRODUCTO
## `hex × tinte` vuelva a leerse neutro en pantalla durante el horario de apertura.
##
## El hex de abajo es la media geométrica-simple de compensar contra las tres paradas de la jornada
## de servicio (08:00 / 13:00 / 18:00 — `CicloLuz.PARADAS`): por canal, `compensado = min(canal) /
## media(canal)`, normalizado a que el canal más alto llegue a 1.0 (no se puede pasar de 255 para
## "sobre-compensar" el resto). Con `e5eeff` (0.898, 0.933, 1.0):
##   · 08:00 → pinta (0.90, 0.89, 0.88) — prácticamente neutro, ya no ambarino.
##   · 13:00 → pinta (0.90, 0.93, 0.99) — un frío MUY leve, imperceptible junto al resto de la paleta.
##   · 18:00 → pinta (0.90, 0.87, 0.82) — sigue habiendo algo de calidez residual (es la hora más
##     cálida de las tres), pero la brecha R↔B baja de 0.18 a 0.08: la mitad de "crema" que antes.
## Por la noche el tinte ya es frío por diseño (vigilia azulada, ver `CicloLuz`), así que esta
## corrección no lo agrava de forma perceptible: sigue siendo el mismo blanco de siempre a ras de
## paleta, la sala ya se ve azulada de por sí a esas horas.
const HEX_POR_DEFECTO: String = "e5eeff"

## Las familias, en el orden en que se muestran en la rejilla de la UI (una fila por familia).
const FAMILIAS: Array[StringName] = [
	&"neutros", &"azules", &"verdes", &"tierras", &"amarillos", &"rojos",
]

## LOS 30 COLORES. `id` es la clave estable (no se traduce ni se muestra), `nombre` lo que lee el
## jugador en el tooltip y `hex` el color en RGB de 6 dígitos, sin alfa: una pared es opaca.
## ⚠️ El primero de la lista ES el color por defecto (`por_defecto()` lo lee de aquí).
const COLORES: Array[Dictionary] = [
	# ── Neutros (el blanco puro abre la lista: es el color de partida de toda pared) ───────────
	# "ffffff" YA NO: ver la cabecera de `HEX_POR_DEFECTO`, el mismo hex compensado vive aquí para
	# que la muestra de la rejilla y el color por defecto sean SIEMPRE el mismo valor (nunca dos
	# literales "ffffff" que uno se olvide de actualizar si esto se vuelve a tocar).
	{"id": &"blanco_puro", "familia": &"neutros", "nombre": "Blanco puro", "hex": HEX_POR_DEFECTO},
	{"id": &"blanco_roto", "familia": &"neutros", "nombre": "Blanco roto", "hex": "f2ede3"},
	{"id": &"gris_claro", "familia": &"neutros", "nombre": "Gris claro", "hex": "d8d9d6"},
	{"id": &"gris_calido", "familia": &"neutros", "nombre": "Gris cálido", "hex": "c9c2b6"},
	{"id": &"gris_azulado", "familia": &"neutros", "nombre": "Gris azulado", "hex": "b3bcc4"},
	# ── Azules (el primero es el azul institucional de siempre: 0.30/0.38/0.55) ────────────────
	{"id": &"azul_institucional", "familia": &"azules", "nombre": "Azul institucional", "hex": "4d618c"},
	{"id": &"azul_acero", "familia": &"azules", "nombre": "Azul acero", "hex": "5f7ea3"},
	{"id": &"azul_niebla", "familia": &"azules", "nombre": "Azul niebla", "hex": "8aa3b8"},
	{"id": &"azul_hielo", "familia": &"azules", "nombre": "Azul hielo", "hex": "aec4d4"},
	{"id": &"celeste_apagado", "familia": &"azules", "nombre": "Celeste apagado", "hex": "c6dbe6"},
	# ── Verdes ────────────────────────────────────────────────────────────────────────────────
	{"id": &"verde_musgo", "familia": &"verdes", "nombre": "Verde musgo", "hex": "5f7358"},
	{"id": &"verde_oliva", "familia": &"verdes", "nombre": "Verde oliva", "hex": "7c7f4e"},
	{"id": &"verde_salvia", "familia": &"verdes", "nombre": "Verde salvia", "hex": "8a9c82"},
	{"id": &"verde_menta", "familia": &"verdes", "nombre": "Verde menta", "hex": "a8c0ae"},
	{"id": &"verde_eucalipto", "familia": &"verdes", "nombre": "Verde eucalipto", "hex": "c2cfbc"},
	# ── Tierras ───────────────────────────────────────────────────────────────────────────────
	{"id": &"marron_cacao", "familia": &"tierras", "nombre": "Marrón cacao", "hex": "6f5641"},
	{"id": &"barro_claro", "familia": &"tierras", "nombre": "Barro claro", "hex": "9a8571"},
	{"id": &"terracota", "familia": &"tierras", "nombre": "Terracota", "hex": "a9694f"},
	{"id": &"beige_tostado", "familia": &"tierras", "nombre": "Beige tostado", "hex": "c2a683"},
	{"id": &"arena", "familia": &"tierras", "nombre": "Arena", "hex": "d8c6a5"},
	# ── Amarillos ─────────────────────────────────────────────────────────────────────────────
	{"id": &"caramelo", "familia": &"amarillos", "nombre": "Caramelo", "hex": "b98a4a"},
	{"id": &"ocre", "familia": &"amarillos", "nombre": "Ocre", "hex": "b8914a"},
	{"id": &"mostaza", "familia": &"amarillos", "nombre": "Mostaza", "hex": "c0a24e"},
	{"id": &"amarillo_apagado", "familia": &"amarillos", "nombre": "Amarillo apagado", "hex": "d6c26b"},
	{"id": &"amarillo_pajizo", "familia": &"amarillos", "nombre": "Amarillo pajizo", "hex": "e0d3a3"},
	# ── Rojos ─────────────────────────────────────────────────────────────────────────────────
	{"id": &"ciruela", "familia": &"rojos", "nombre": "Ciruela", "hex": "6e4a5c"},
	{"id": &"burdeos", "familia": &"rojos", "nombre": "Burdeos", "hex": "7a4048"},
	{"id": &"rojo_ladrillo", "familia": &"rojos", "nombre": "Rojo ladrillo", "hex": "96574d"},
	{"id": &"teja", "familia": &"rojos", "nombre": "Teja", "hex": "b06a5c"},
	{"id": &"rosa_empolvado", "familia": &"rojos", "nombre": "Rosa empolvado", "hex": "d3a9a4"},
]


## El color POR DEFECTO de una pared sin pintar (el primero de la paleta: blanco puro).
static func por_defecto() -> Color:
	return Color.html(HEX_POR_DEFECTO)


## Los 30 colores, en el orden de la paleta. Lo consume la rejilla de muestras de la UI.
static func colores() -> Array[Color]:
	var salida: Array[Color] = []
	for entrada: Dictionary in COLORES:
		salida.append(Color.html(String(entrada["hex"])))
	return salida


## El color de un id de la paleta (blanco por defecto si el id no existe — nunca devuelve basura).
static func color_de(id: StringName) -> Color:
	for entrada: Dictionary in COLORES:
		if entrada["id"] == id:
			return Color.html(String(entrada["hex"]))
	return por_defecto()


## Color → texto para el save (hex de 6 dígitos, sin alfa ni almohadilla).
static func a_hex(color: Color) -> String:
	return color.to_html(false)


## Texto del save → Color. Defensivo (ADR-0002): un hex corrupto NO invalida la partida, cae al
## blanco por defecto.
static func desde_hex(texto: String) -> Color:
	var limpio: String = texto.strip_edges().trim_prefix("#")
	if not Color.html_is_valid(limpio):
		return por_defecto()
	return Color.html(limpio)
