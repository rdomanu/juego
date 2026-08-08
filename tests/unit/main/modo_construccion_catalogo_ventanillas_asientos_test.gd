# CATÁLOGO INCOMPLETO (2026-08-08 — playtest: "no puedo elegir los puestos medio o pro para
# construir, ni tampoco los distintos asientos"). El arte ya existía en `assets/sprites/mobiliario/`
# (`ventanilla_media_*`/`ventanilla_pro_*`, sillas de espera azul/cómoda) pero faltaba: (a) el
# `TipoPuesto` de la media/pro en `datos/puestos/` y (b) la tarjeta en la barra de construcción para
# los asientos por tier (existían como `Comodidad`, pero solo se compraban desde el menú contextual
# de una sala ya construida, nunca desde la barra).
# Tipo: Logic/UI. DETERMINISTA: catálogo real + `ModoConstruccion._crear_ui()`, sin ratón ni GPU.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")

const TAM_CELDA: int = 40


func _modo() -> Node2D:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO)
	var modo: Node2D = auto_free(ModoConstruccionScript.new())
	modo.configurar(construccion, TAM_CELDA, null)
	add_child(modo)
	return modo


# ── El CATÁLOGO tiene los dos tiers nuevos de ventanilla ──────────────────────────────────
func test_ventanilla_media_y_pro_existen_en_el_catalogo() -> void:
	var media: Resource = Datos.obtener_silencioso(&"TipoPuesto", &"ventanilla_media")
	var pro: Resource = Datos.obtener_silencioso(&"TipoPuesto", &"ventanilla_pro")
	assert_object(media).override_failure_message("falta datos/puestos/puesto_ventanilla_media.tres").is_not_null()
	assert_object(pro).override_failure_message("falta datos/puestos/puesto_ventanilla_pro.tres").is_not_null()
	assert_int(media.superficie).is_equal(2)
	assert_int(pro.superficie).is_equal(2)


## Precios escalonados: básica (puesto_doc_general, 500 €, EL PRECIO REAL del catálogo — no los
## 150 € que se asumían al encargar la tarea) < media < pro. Provisionales, marcados como tal en el
## informe de la tarea.
func test_precios_escalonados_basica_media_pro() -> void:
	var basica: Resource = Datos.obtener(&"TipoPuesto", &"puesto_doc_general")
	var media: Resource = Datos.obtener(&"TipoPuesto", &"ventanilla_media")
	var pro: Resource = Datos.obtener(&"TipoPuesto", &"ventanilla_pro")
	assert_int(basica.coste_construccion_eur).is_equal(500)
	assert_int(media.coste_construccion_eur).is_greater(basica.coste_construccion_eur)
	assert_int(pro.coste_construccion_eur).is_greater(media.coste_construccion_eur)


# ── Los asientos por tier YA existían como `Comodidad`; se comprueba que siguen ahí ────────
func test_los_asientos_azul_y_comoda_existen_en_el_catalogo() -> void:
	var azul: Resource = Datos.obtener_silencioso(&"Comodidad", &"silla_espera_azul")
	var comoda: Resource = Datos.obtener_silencioso(&"Comodidad", &"silla_espera_comoda")
	assert_object(azul).is_not_null()
	assert_object(comoda).is_not_null()
	assert_str(azul.familia).is_equal("ciudadano")
	assert_str(comoda.familia).is_equal("ciudadano")


# ── Las CUATRO salen como TARJETA en la barra de construcción ─────────────────────────────
func test_ventanilla_media_y_pro_salen_como_tarjeta_en_la_barra() -> void:
	var modo: Node2D = _modo()
	assert_bool(modo._botones_herramienta.has(&"ventanilla_media")) \
		.override_failure_message("ventanilla_media no tiene tarjeta en la barra").is_true()
	assert_bool(modo._botones_herramienta.has(&"ventanilla_pro")) \
		.override_failure_message("ventanilla_pro no tiene tarjeta en la barra").is_true()
	assert_str(String(modo._categoria_de_herramienta[&"ventanilla_media"])).is_equal("muebles")
	assert_str(String(modo._categoria_de_herramienta[&"ventanilla_pro"])).is_equal("muebles")


func test_asientos_azul_y_comoda_salen_como_tarjeta_en_la_barra() -> void:
	var modo: Node2D = _modo()
	assert_bool(modo._botones_herramienta.has(&"silla_espera_azul")) \
		.override_failure_message("silla_espera_azul no tiene tarjeta en la barra").is_true()
	assert_bool(modo._botones_herramienta.has(&"silla_espera_comoda")) \
		.override_failure_message("silla_espera_comoda no tiene tarjeta en la barra").is_true()
	assert_str(String(modo._categoria_de_herramienta[&"silla_espera_azul"])).is_equal("muebles")
	assert_str(String(modo._categoria_de_herramienta[&"silla_espera_comoda"])).is_equal("muebles")


## La miniatura de la tarjeta de cada tier de ventanilla es SU PROPIO sprite (no la básica de
## siempre) — el bug hermano de este catálogo: si la tarjeta existe pero enseña el mueble
## equivocado, el jugador cree que está comprando lo de siempre.
func test_la_miniatura_de_cada_tier_de_ventanilla_es_la_suya() -> void:
	var modo: Node2D = _modo()
	var textura_media: Texture2D = modo._sprite_de_herramienta(&"ventanilla_media", 0, 1).get("textura")
	var textura_pro: Texture2D = modo._sprite_de_herramienta(&"ventanilla_pro", 0, 1).get("textura")
	assert_object(textura_media).is_not_null()
	assert_object(textura_pro).is_not_null()
	assert_str(textura_media.resource_path).contains("ventanilla_media")
	assert_str(textura_pro.resource_path).contains("ventanilla_pro")


## Y los puestos de SIEMPRE (sin tier propio) NO cambian: siguen enseñando la básica.
func test_la_miniatura_de_los_puestos_sin_tier_sigue_siendo_la_basica() -> void:
	var modo: Node2D = _modo()
	var textura: Texture2D = modo._sprite_de_herramienta(&"puesto_doc_general", 0, 1).get("textura")
	assert_object(textura).is_not_null()
	assert_str(textura.resource_path).contains("ventanilla_basica")
