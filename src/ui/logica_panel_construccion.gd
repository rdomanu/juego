class_name LogicaPanelConstruccion extends RefCounted
## LogicaPanelConstruccion — las partes PURAS del panel de construcción v2 (F1, 2026-08-15).
##
## Todo lo que el panel calcula sin tocar un `Node` ni el árbol de escena vive aquí, para poder
## testearlo con GdUnit4 sin montar `ModoConstruccion` (Resource/RefCounted puro, determinista):
## el filtro del buscador, el texto de huella "N celda(s) · M plaza(s)", y las tres conversiones de
## la ficha (confort → fracción de barra, `factor_satisfaccion` → "Nota al salir", aporte de confort
## → "Paciencia extra"). `ModoConstruccion._refrescar_tarjetas_visibles`/`_actualizar_ficha` llaman a
## estas funciones; NO las reimplementan.
##
## Story: F0/F1 "lenguaje visual de UI nuevo" (2026-08-15) · maquetas
## `design/ux/maquetas-menu-2026-08/menu_v2_moderno.png`/`menu_v3_completo.png` ·
## `design/ux/menu-construccion-spec.md`.

## Tope de `aporte` (confort) que la ficha pinta como barra LLENA (7/7 en la maqueta, "Banco
## premium"). Es un valor de PRESENTACIÓN (cómo se dibuja la barra), no una regla de negocio: el
## dato real de negocio es `Comodidad.aporte`, sin tope, y lo sigue usando tal cual
## `Paciencia.mult_comodidad_de`. Si un día el catálogo trae un objeto con más aporte que esto, la
## barra se queda llena (clamp), no se rompe.
const TOPE_CONFORT_BARRA: float = 7.0
## `k_confort` de `Paciencia.mult_comodidad_de` (`src/feature/paciencia/paciencia.gd`): duplicado
## aquí a propósito, como CONSTANTE DE PRESENTACIÓN — la ficha necesita conocer la fórmula para
## anticipar el "+N%" ANTES de colocar el mueble (no hay sala construida todavía sobre la que
## preguntarle a Paciencia); si el knob de Paciencia cambia, este número queda desincronizado
## (documentado como deuda -- ver el informe de la tarea, apartado "próximamente").
const K_CONFORT_PACIENCIA: float = 0.02


## Normaliza texto de búsqueda: recorta espacios y pasa a minúsculas. `""` (tras normalizar) =
## "sin filtro, todo pasa".
static func normalizar_busqueda(texto: String) -> String:
	return texto.strip_edges().to_lower()


## ¿El nombre de una tarjeta coincide con lo que se ha escrito en el buscador? Substring simple, sin
## acentos ni fuzzy-matching (MVP -- suficiente para nombres cortos del catálogo). Buscador vacío =
## coincide siempre.
static func coincide_busqueda(nombre: String, texto_busqueda: String) -> bool:
	var normalizado: String = normalizar_busqueda(texto_busqueda)
	if normalizado == "":
		return true
	return nombre.to_lower().contains(normalizado)


## La regla completa de visibilidad de UNA tarjeta: tiene que ser de la categoría ACTIVA Y (si hay
## texto en el buscador) su nombre tiene que contenerlo. Categoría vacía (`&""`, caso de Demoler
## en el reskin anterior) nunca es "la activa" -- no debería llamarse con eso, pero por si acaso
## no casa nunca por accidente con una categoría real.
static func tarjeta_visible(
	categoria_tarjeta: StringName, categoria_activa: StringName, nombre: String, texto_busqueda: String
) -> bool:
	if categoria_tarjeta == &"" or categoria_tarjeta != categoria_activa:
		return false
	return coincide_busqueda(nombre, texto_busqueda)


## "N celda(s) · M plaza(s)" (formato exacto de la maqueta, singular/plural correcto). `plazas <= 0`
## omite esa mitad entera (un escritorio no tiene plazas de asiento, no tiene sentido decir "0
## plazas") -- devuelve solo "N celda(s)".
static func texto_huella(celdas: int, plazas: int) -> String:
	var texto_celdas: String = "%d celda" % celdas if celdas == 1 else "%d celdas" % celdas
	if plazas <= 0:
		return texto_celdas
	var texto_plazas: String = "%d plaza" % plazas if plazas == 1 else "%d plazas" % plazas
	return "%s · %s" % [texto_celdas, texto_plazas]


## Fracción [0,1] de la barra de Confort, a partir del `aporte` bruto de una `Comodidad`. Ver
## `TOPE_CONFORT_BARRA`.
static func fraccion_confort(aporte_confort: float, tope: float = TOPE_CONFORT_BARRA) -> float:
	if tope <= 0.0:
		return 0.0
	return clampf(aporte_confort / tope, 0.0, 1.0)


## "Nota al salir": cuánto MEJORA `factor_satisfaccion` sobre el neutro (1.0), en puntos porcentuales
## enteros. `factor_satisfaccion` 1.2 → +20 (mostrar como "+20%"); 1.0 (neutro, todo lo que no es
## asiento) → 0.
static func porcentaje_nota_al_salir(factor_satisfaccion: float) -> int:
	return int(round((factor_satisfaccion - 1.0) * 100.0))


## "Paciencia extra": el `+N%` que resta al multiplicador de paciencia (`Paciencia.mult_comodidad_de`,
## `clamp(1 − k_confort×confort, min, 1.0)`) ANTES del clamp -- aquí se pinta la promesa completa del
## mueble, el clamp real de la sala construida lo aplica Paciencia con la suma de TODOS sus objetos.
static func porcentaje_paciencia_extra(aporte_confort: float, k_confort: float = K_CONFORT_PACIENCIA) -> int:
	return int(round(aporte_confort * k_confort * 100.0))
