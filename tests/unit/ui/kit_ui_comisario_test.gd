# KitUIComisario (piloto Summer, 2026-08-07): el punto único de acceso al Theme del kit y a sus
# iconos -- ver la cabecera de `src/ui/kit_ui_comisario.gd`. Este test cubre el CONTRATO que el
# resto de `src/main` (ModoConstruccion, ModoDisenadorEntorno) da por hecho: el tema carga, un icono
# conocido del catálogo devuelve una textura real, y un id desconocido NO revienta (null silencioso
# + warning, nunca una excepción -- quien llama decide qué hacer sin icono).
#
# Tipo: Logic/carga de recursos bundleados en res:// (mismo patrón que el resto de la suite carga el
# catálogo de datos vía `Datos.obtener` -- no es "estado externo" en el sentido de la regla de
# aislamiento: son assets versionados en el repo, deterministas, sin red ni reloj). DETERMINISTA.
extends GdUnitTestSuite

const KitUIComisarioScript := preload("res://src/ui/kit_ui_comisario.gd")


# ── El tema ────────────────────────────────────────────────────────────────────────────────────

func test_tema_carga_devuelve_un_theme() -> void:
	# Act
	var tema: Theme = KitUIComisarioScript.tema()

	# Assert
	assert_object(tema).is_not_null()
	assert_bool(tema is Theme).is_true()


## Cacheado a nivel de clase (varias pantallas lo comparten -- un solo `load()` por proceso, ver la
## cabecera de `tema()`): dos llamadas deben devolver LA MISMA instancia, no dos cargas distintas.
func test_tema_llamado_dos_veces_devuelve_la_misma_instancia() -> void:
	# Act
	var primero: Theme = KitUIComisarioScript.tema()
	var segundo: Theme = KitUIComisarioScript.tema()

	# Assert
	assert_object(segundo).is_same(primero)


## Las variaciones que `ModoConstruccion`/`ModoDisenadorEntorno` piden por nombre (`theme_type_variation`)
## tienen que existir de verdad en el `.tres` -- si alguna se borra por error, un botón se queda con
## el estilo por defecto sin que nadie se entere hasta mirarlo en pantalla.
func test_tema_trae_las_variantes_que_consume_src_main() -> void:
	# Arrange
	var tema: Theme = KitUIComisarioScript.tema()
	var variantes: Array[StringName] = [
		KitUIComisarioScript.VARIANTE_PESTANA, KitUIComisarioScript.VARIANTE_TARJETA,
		KitUIComisarioScript.VARIANTE_BOTON_DEMOLER, KitUIComisarioScript.VARIANTE_PILDORA_PRIMARIA,
		KitUIComisarioScript.VARIANTE_PILDORA_SECUNDARIA, KitUIComisarioScript.VARIANTE_BARRA_SUPERIOR,
	]

	# Act / Assert
	for variante: StringName in variantes:
		assert_bool(tema.get_type_variation_base(variante) != &"").override_failure_message(
			"Falta la variante '%s' en theme_comisario.tres" % variante
		).is_true()


# ── Iconos ─────────────────────────────────────────────────────────────────────────────────────

## Un id conocido del catálogo (`ICONOS`) devuelve una textura real, no un placeholder ni null.
func test_icono_conocido_devuelve_una_textura() -> void:
	# Act
	var textura: Texture2D = KitUIComisarioScript.icono(&"plano")

	# Assert
	assert_object(textura).is_not_null()
	assert_bool(textura is Texture2D).is_true()


## Todo el catálogo carga -- ninguna entrada de `ICONOS` apunta a un archivo que ya no existe
## (regresión honesta: un nombre de archivo mal escrito en el diccionario no debe descubrirse en
## producción viendo un icono en blanco).
func test_todos_los_iconos_del_catalogo_cargan_textura() -> void:
	# Arrange
	var ids: Array = KitUIComisarioScript.ICONOS.keys()

	# Act / Assert
	for id: StringName in ids:
		assert_object(KitUIComisarioScript.icono(id)).override_failure_message(
			"Icono '%s' (%s) no cargó ninguna textura" % [id, KitUIComisarioScript.ICONOS[id]]
		).is_not_null()


## Un id que NO está en el catálogo no revienta: devuelve `null` en silencio (con warning) para que
## quien llama decida -- mismo contrato que `Datos.obtener_silencioso`.
func test_icono_desconocido_devuelve_null_sin_reventar() -> void:
	# Act
	var textura: Texture2D = KitUIComisarioScript.icono(&"esto_no_existe_en_el_catalogo")

	# Assert
	assert_object(textura).is_null()


# ── Módulos de la barra superior (Fase 2 del HUD, 2026-08-08) ────────────────────────────────────

## Un id conocido de `MODULOS_BARRA_SUPERIOR` devuelve una textura real -- mismo contrato que
## `icono()`, pero por su propio diccionario (los ids no comparten espacio de nombres).
func test_modulo_barra_superior_conocido_devuelve_una_textura() -> void:
	# Act
	var textura: Texture2D = KitUIComisarioScript.modulo_barra_superior(&"reloj")

	# Assert
	assert_object(textura).is_not_null()
	assert_bool(textura is Texture2D).is_true()


## Todo el catálogo de módulos carga -- ninguna entrada apunta a un archivo que ya no existe.
func test_todos_los_modulos_de_la_barra_superior_cargan_textura() -> void:
	# Arrange
	var ids: Array = KitUIComisarioScript.MODULOS_BARRA_SUPERIOR.keys()

	# Act / Assert
	for id: StringName in ids:
		assert_object(KitUIComisarioScript.modulo_barra_superior(id)).override_failure_message(
			"Módulo '%s' (%s) no cargó ninguna textura" % [id, KitUIComisarioScript.MODULOS_BARRA_SUPERIOR[id]]
		).is_not_null()


## Un id que NO está en el catálogo de módulos no revienta: `null` en silencio (con warning).
func test_modulo_barra_superior_desconocido_devuelve_null_sin_reventar() -> void:
	# Act
	var textura: Texture2D = KitUIComisarioScript.modulo_barra_superior(&"esto_no_existe")

	# Assert
	assert_object(textura).is_null()
