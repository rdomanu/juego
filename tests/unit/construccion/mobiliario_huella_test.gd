# BLINDAJE DE LA NORMA "HUELLA EN CELDAS ENTERAS" (memoria `huella-celdas-enteras`, 2026-08-14).
# Tipo: Logic. DETERMINISTA: catálogo de datos fijo + medición geométrica de PNG ya en disco, sin
# reloj ni RNG ni ventana de pantalla (headless, sin `montar_visual`).
#
# Hasta hoy "¿el dibujo de este mueble se pasa de su celda?" se comprobaba A MANO, mueble a mueble,
# con `tools/_diag_*` desechables. Este test lo convierte en una comprobación automática que corre
# en cada pasada de la suite: recorre el CATÁLOGO REAL (no uno de mentira) y mide cada sprite con la
# MISMA vara que usa el juego para anclar mobiliario (`AnclajeSprite.semiejes_base`), contra la MISMA
# huella que calcula `Construccion` al plantar la pieza (`superficie` del catálogo + el eje que le
# toca según su orientación — ver `Construccion._paso_de`/`_es_eje_vertical`).
#
# TOLERANCIA: 0 (± 0.001 celdas de épsilon de coma flotante). Si un sprite real se pasa de su huella
# declarada, este test DEBE fallar — no se afloja el margen ni se excluye el mueble para ponerlo en
# verde (única excepción, documentada más abajo: la estantería de esquina, cuya silueta CÓNCAVA hace
# que la propia `semiejes_base` esté probada como medida inválida — no es "aflojar tolerancia", es no
# aplicar la vara equivocada a la única pieza que no es un rectángulo).
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

## Las 4 orientaciones reales del juego (grados, no índices — `Construccion.HORIZONTAL`/`VERTICAL`/
## `HORIZONTAL_GIRADO`/`VERTICAL_GIRADO`, ver su cabecera "LOS 4 VALORES SON GRADOS DE VERDAD").
const ORIENTACIONES: Array[int] = [
	ConstruccionScript.HORIZONTAL, ConstruccionScript.VERTICAL,
	ConstruccionScript.HORIZONTAL_GIRADO, ConstruccionScript.VERTICAL_GIRADO,
]

## Épsilon de coma flotante — el margen que pide la tarea, ni un píxel más (0.001 celdas = 0.04 px
## con TAM_CELDA=40; ningún redondeo de render puede colarse por ahí).
const EPS_CELDAS: float = 0.001

## `sofa_descanso` (ASIENTO_SOFA3) NO vive en `Construccion._sprites_comodidad()` — tiene su propio
## camino de sprite (`_ruta_sprite_asiento_sofa3`, colapsado a 2 vistas por EJE) documentado en la
## cabecera "EL SOFÁ DE 3 PLAZAS, MULTI-CELDA" de `construccion.gd`. Se cubre en su propio test.
const ID_SOFA := &"sofa_descanso"

## ÚNICA EXCLUSIÓN (documentada, no "para ponerlo verde"): la estantería de esquina es el ÚNICO
## mueble del catálogo con silueta CÓNCAVA (una L, no un rectángulo) — `construccion.gd` mismo lo dice
## en la cabecera de `COMODIDAD_ESTANTERIA_ESQUINA`: *"AnclajeSprite.semiejes_base asume una base
## RECTANGULAR CONVEXA (...); una L es CÓNCAVA y esa medida se rompe (comprobado: 0°/180° son el
## MISMO objeto girado 180° y deberían medir igual, y dan 1,538 y 0,963 celdas — no es ruido, es la
## premisa rota)"*. Y el propio dibujo está diseñado para "sobresalir visualmente hacia la celda
## diagonal que NO reserva" — un desbordamiento ACEPTADO a propósito por el modelo (huella en L no
## soportada, "Sin formas en L: la huella siempre es un rectángulo"), no un bug de arte. Aplicarle
## `semiejes_base` como si fuera un rectángulo no mediría un fallo real: mediría que la herramienta no
## sirve para esta silueta. Por eso queda fuera del barrido genérico — no porque diera rojo y se
## tapara, sino porque el rojo que daría no sería la norma rota, sería la vara rota.
const ID_ESTANTERIA_ESQUINA := &"estanteria_esquina"


## Instancia mínima solo para llegar a los métodos de instancia que resuelven la ruta del sprite
## (`_ruta_sprite_comodidad`/`_ruta_sprite_asiento_sofa3`) — no tocan `_elementos` ni el árbol, así
## que no hace falta economía ni sala. Mismo patrón de fixture que `bancos_multiplaza_test._construccion`.
func _construccion() -> Node:
	var c: Node = auto_free(ConstruccionScript.new())
	add_child(c)
	c.aplicar_config(ConfigConstruccionScript.new())
	return c


## Semiejes de la base, en CELDAS (no en píxeles): `AnclajeSprite.semiejes_base` ya mide en el plano
## lógico cuadrado (`TAM_CELDA` px/celda — la constante REAL de `proyeccion.gd`, no un 40 a pelo).
func _semiejes_en_celdas(textura: Texture2D) -> Vector2:
	var semiejes_px: Vector2 = AnclajeSpriteScript.semiejes_base(textura)
	var tam_celda: float = float(ProyeccionScript.TAM_CELDA)
	return semiejes_px / tam_celda


## La huella DECLARADA (en celdas, por eje) que le toca a una comodidad genérica en esta orientación:
## la MISMA cuenta que hace `Construccion._crear_pieza` para la caja gris (`ancho`/`largo` — ver su
## cabecera "La huella crece en +X o en +Y según cómo esté girada la pieza... es el MISMO eje que
## reserva el modelo"): `superficie` celdas a lo largo del eje de `_paso_de` (X si NO es eje vertical,
## Y si lo es) y 1 celda en el perpendicular. `x` = eje X (este/oeste), `y` = eje Y (norte/sur) — el
## mismo orden que devuelve `semiejes_base`.
func _huella_declarada(superficie: int, orientacion: int) -> Vector2:
	var eje_vertical: bool = ConstruccionScript._es_eje_vertical(orientacion)
	var ancho_x: float = 1.0 if eje_vertical else float(superficie)
	var largo_y: float = float(superficie) if eje_vertical else 1.0
	return Vector2(ancho_x, largo_y)


## El JUEZ único: el sprite de `mueble` en `orientacion`, cargado de `ruta`, no puede medir en NINGÚN
## eje más que lo que declara `superficie` para esa orientación. Mensaje con mueble/orientación/eje/
## medido/permitido — para que un fallo futuro se entienda solo, sin abrir el PNG.
func _asertar_no_se_pasa_de_su_huella(
	mueble: StringName, orientacion: int, ruta: String, superficie: int
) -> void:
	assert_bool(ResourceLoader.exists(ruta)).override_failure_message(
		"'%s' (orientación %d°): no existe el sprite declarado en %s"
		% [mueble, orientacion, ruta]
	).is_true()
	var textura: Texture2D = load(ruta) as Texture2D
	assert_object(textura).override_failure_message(
		"'%s' (orientación %d°): %s no cargó como Texture2D" % [mueble, orientacion, ruta]
	).is_not_null()

	var medido: Vector2 = _semiejes_en_celdas(textura) * 2.0   # semieje × 2 = el largo entero
	var permitido: Vector2 = _huella_declarada(superficie, orientacion)

	assert_float(medido.x).override_failure_message(
		"'%s' orientación %d° eje X: medido %.3f celdas, permitido %.3f celdas (sprite %s)"
		% [mueble, orientacion, medido.x, permitido.x, ruta]
	).is_less_equal(permitido.x + EPS_CELDAS)
	assert_float(medido.y).override_failure_message(
		"'%s' orientación %d° eje Y: medido %.3f celdas, permitido %.3f celdas (sprite %s)"
		% [mueble, orientacion, medido.y, permitido.y, ruta]
	).is_less_equal(permitido.y + EPS_CELDAS)


# ── El barrido genérico: TODO el catálogo con sprite propio, en sus 4 orientaciones ────────────────
## Cubre los 19 ids que declara `Construccion._sprites_comodidad()` (el diccionario real que decide
## qué PNG carga cada comodidad — no una lista copiada a mano, así que un mueble nuevo que se dé de
## alta ahí entra solo en la cobertura la próxima vez que corra la suite) × las 4 orientaciones, salvo
## la excepción documentada arriba. 18 muebles × 4 orientaciones = 72 combinaciones, 2 ejes cada una.
func test_ningun_sprite_de_comodidad_se_pasa_de_su_huella_en_ninguna_orientacion() -> void:
	var construccion: Node = _construccion()
	var mapa_sprites: Dictionary = ConstruccionScript._sprites_comodidad()
	assert_int(mapa_sprites.size()).override_failure_message(
		"el catálogo de sprites de comodidad está vacío: este test no cubriría nada"
	).is_greater(0)

	var cubiertos := 0
	for id_catalogo: StringName in mapa_sprites:
		if id_catalogo == ID_ESTANTERIA_ESQUINA:
			continue   # única excepción — ver cabecera del fichero

		var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", id_catalogo)
		assert_object(comodidad).override_failure_message(
			"'%s' está en _sprites_comodidad() pero no existe como Comodidad en el catálogo Datos"
			% id_catalogo
		).is_not_null()
		var superficie: int = maxi(comodidad.superficie, 1)
		var datos_sprite: Dictionary = mapa_sprites[id_catalogo]

		for orientacion: int in ORIENTACIONES:
			var rotacion: int = ConstruccionScript.rotacion_sprite_comodidad(datos_sprite, orientacion)
			var ruta: String = construccion._ruta_sprite_comodidad(id_catalogo, rotacion)
			_asertar_no_se_pasa_de_su_huella(id_catalogo, orientacion, ruta, superficie)
			cubiertos += 1

	# Cobertura real: 18 muebles (19 del catálogo − 1 excepción documentada) × 4 orientaciones.
	assert_int(cubiertos).override_failure_message(
		"cobertura inesperada: %d combinaciones mueble×orientación (se esperaban %d)"
		% [cubiertos, (mapa_sprites.size() - 1) * ORIENTACIONES.size()]
	).is_equal((mapa_sprites.size() - 1) * ORIENTACIONES.size())


# ── El sofá de 3 plazas: mismo juez, camino de sprite propio (`_ruta_sprite_asiento_sofa3`) ────────
## `sofa_descanso` no pasa por `_sprites_comodidad()` (ver su cabecera en `construccion.gd`), así que
## queda fuera del barrido de arriba a propósito — se cubre aquí con su propia resolución de ruta,
## que colapsa las 4 orientaciones a 2 vistas reales por EJE (`_rotacion_asiento_sofa3`).
func test_el_sofa_de_3_plazas_no_se_pasa_de_su_huella_en_ninguna_orientacion() -> void:
	var construccion: Node = _construccion()
	var comodidad: Resource = Datos.obtener_silencioso(&"Comodidad", ID_SOFA)
	assert_object(comodidad).override_failure_message(
		"no existe la comodidad '%s' en el catálogo" % ID_SOFA
	).is_not_null()
	var superficie: int = maxi(comodidad.superficie, 1)

	for orientacion: int in ORIENTACIONES:
		var ruta: String = construccion._ruta_sprite_asiento_sofa3(orientacion)
		_asertar_no_se_pasa_de_su_huella(ID_SOFA, orientacion, ruta, superficie)
