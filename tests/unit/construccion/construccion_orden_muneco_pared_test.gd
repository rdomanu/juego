# Muñeco ANDANTE vs tramo SUR — el candado del cambio ESTRUCTURAL del 2026-08-06.
#
# QUÉ CAMBIÓ. Hasta hoy la gente que anda se dibujaba en una capa con `z_index = 2` FIJO, por encima
# de TODA la bolsa de y-sort (paredes + mobiliario + ventanillas). Esa decisión se tomó con
# `ALTO_PARED_FRENTE` = 17 px, cuando un murete no llegaba ni a la cintura de un muñeco. Con la
# pared subida a 65 px (`ALTO_PARED`, 2026-08-05) el murete mide 32,5 y el usuario lo cazó con
# captura (`scratchpad/capas_odac_antes.png`): un NPC pegado por DENTRO al muro sur se dibujaba
# ENTERO por encima de él, como si flotara fuera de la sala. Orden del usuario: que los muñecos
# andantes compitan por profundidad como cualquier otra pieza.
#
# QUÉ FIJA ESTE TEST. Los DOS lados del mismo muro, que es justo lo que ningún z global podía dar a
# la vez (misma lección que el muro divisorio de `paredes_salas.gd`):
#   1. muñeco DENTRO de la sala, junto al muro sur → gana el TRAMO (le tapa las piernas);
#   2. muñeco FUERA, delante de ese mismo muro     → gana el MUÑECO (se ve entero por delante);
#   3. y el cableado que lo hace posible: `NPCsFlujo` cuelga su capa de muñecos de la BOLSA que le
#      inyecta `Main`, no de sí mismo — si alguien la devuelve a z 2, el 1 sigue pasando por
#      geometría pero el juego vuelve a estar roto, así que se comprueba aparte.
#
# El punto de orden de un muñeco son SUS PIES: `Muneco` ancla por la base y `NPCsFlujo.colocar_muneco`
# lo planta en `Proyeccion.proyectar(punto_cuadrado)`, o sea el centro del rombo de la celda que
# pisa. El test lo verifica por el camino REAL (`Construccion.centro_de_celda` → `Proyeccion.
# proyectar`) en vez de dar por hecho que es `centro_iso`.
#
# Sobre la TOLERANCIA: el margen real es de 10 px en los dos casos. El "bote" del paso
# (`NPCsFlujo.ALTURA_BOTE` = 2 px) sube el nodo como mucho 2 px mientras camina, así que el peor
# caso instantáneo sigue siendo 8 px — muy por encima de los 3 px de holgura que se exigen aquí.
#
# Hermano de `construccion_orden_silla_pared_test.gd` (misma plantilla, mismo mundo, misma sala).
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin I/O). Aislamiento: nodos `.new()` sin escena
# (`auto_free`), montados fuera del árbol.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 10
const FILAS: int = 10
const SALA_ESPERA_ODAC := &"sala_espera_odac"
## Columnas 2..6, filas 2..5 (mismo rect que la sonda `_diag_capas_odac.gd` y que el test de la silla).
const RECT_SALA := Rect2i(2, 2, 5, 4)
## Última fila INTERIOR, pegada por dentro al muro sur (que vive en la fila-rejilla 6).
const CELDA_DENTRO := Vector2i(3, 5)
## Primera fila ya FUERA de la sala, al otro lado de ese mismo muro (más cerca de cámara).
const CELDA_FUERA := Vector2i(3, 6)
## Holgura de las comparaciones numéricas (la misma que usa la sonda).
const TOLERANCIA_PX: float = 3.0


## Sala de espera ODAC con paredes fijadas — sin `SubViewport` ni GPU: `ParedesSalas`/`Construccion`
## calculan geometría en `Node2D`s fuera de árbol, no hace falta renderizar nada para leer números.
func _mundo_con_sala_amurallada() -> Dictionary:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.edificio_columnas = COLUMNAS
	construccion.edificio_filas = FILAS
	var capa_profunda: Node2D = auto_free(Node2D.new())
	capa_profunda.y_sort_enabled = true
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(700, 560))
	construccion.montar_visual(TAM_CELDA, origen, capa_profunda)
	construccion.levantar_fachada()
	var sala_id: StringName = construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	paredes.configurar(construccion, TAM_CELDA, origen)
	return {
		"construccion": construccion, "paredes": paredes,
		"capa_profunda": capa_profunda, "origen": origen,
	}


## El `orden.y` (la Y con la que el y-sort compara ese tramo) del muro sur de la sala en una columna.
func _orden_tramo_sur(paredes: Node2D, columna: int) -> float:
	var clave: String = "h:%d:%d" % [columna, RECT_SALA.end.y]
	for tramo: Dictionary in paredes._tramos:
		if tramo.has("clave_modelo") and String(tramo["clave_modelo"]) == clave:
			return (tramo["orden"] as Vector2).y
	return NAN


## La Y de mundo por la que se ordena un muñeco plantado en esa celda: el camino REAL de
## `NPCsFlujo.colocar_muneco` (proyectar el centro de la celda del plano cuadrado) más el origen del
## suelo, que en el juego lo aporta la `position` de la capa de escena.
func _orden_muneco(construccion: Node, origen: Vector2, celda: Vector2i) -> float:
	return ProyeccionScript.proyectar(construccion.centro_de_celda(celda)).y + origen.y


func test_muneco_dentro_junto_al_muro_sur_lo_tapa_el_tramo() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_sala_amurallada()
	var construccion: Node = mundo["construccion"]
	var paredes: Node2D = mundo["paredes"]
	var origen: Vector2 = mundo["origen"]

	# Act
	var orden_tramo: float = _orden_tramo_sur(paredes, CELDA_DENTRO.x)
	var orden_muneco: float = _orden_muneco(construccion, origen, CELDA_DENTRO)

	# Assert — el tramo se dibuja DESPUÉS (Y mayor), o sea ENCIMA: la media pared le tapa la base.
	assert_bool(is_nan(orden_tramo)).is_false()
	assert_float(orden_tramo - orden_muneco).is_greater_equal(TOLERANCIA_PX)


func test_muneco_fuera_delante_del_muro_sur_se_ve_entero() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_sala_amurallada()
	var construccion: Node = mundo["construccion"]
	var paredes: Node2D = mundo["paredes"]
	var origen: Vector2 = mundo["origen"]

	# Act
	var orden_tramo: float = _orden_tramo_sur(paredes, CELDA_FUERA.x)
	var orden_muneco: float = _orden_muneco(construccion, origen, CELDA_FUERA)

	# Assert — ahora gana el MUÑECO (Y mayor): está más cerca de cámara que la pared, se ve entero.
	assert_bool(is_nan(orden_tramo)).is_false()
	assert_float(orden_muneco - orden_tramo).is_greater_equal(TOLERANCIA_PX)


## El pie de todo lo anterior: los PIES del muñeco son de verdad el centro del rombo de su celda.
## Si `colocar_muneco` dejara de anclar ahí (o `Proyeccion` cambiara de convenio), los dos tests de
## arriba seguirían pasando por geometría pero medirían un punto que ya no es el del dibujo.
func test_el_punto_de_orden_de_un_muneco_es_el_centro_de_su_celda() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_sala_amurallada()
	var construccion: Node = mundo["construccion"]

	# Act
	var por_el_camino_real: Vector2 = ProyeccionScript.proyectar(
		construccion.centro_de_celda(CELDA_DENTRO)
	)

	# Assert
	assert_vector(por_el_camino_real).is_equal_approx(
		ProyeccionScript.centro_iso(CELDA_DENTRO), Vector2.ONE * 0.01
	)


## EL CABLEADO: `NPCsFlujo` tiene que colgar su capa de muñecos de la BOLSA que le inyecta `Main`,
## en z_index 0 y con y-sort propio (y-sort anidado = una sola bolsa, verificado en el motor 4.6).
## Este es el candado contra la regresión de verdad: devolver la gente a su capa privada de z 2.
func test_la_capa_de_munecos_cuelga_de_la_bolsa_de_profundidad() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_sala_amurallada()
	var construccion: Node = mundo["construccion"]
	var capa_profunda: Node2D = mundo["capa_profunda"]
	var origen: Vector2 = mundo["origen"]
	var npcs: Node2D = auto_free(NPCsFlujoScript.new())

	# Act — `flujo` y `personal` no se dereferencian en `configurar` (solo se guardan): este test
	# mide el CABLEADO de capas, no la simulación.
	npcs.configurar(
		null, construccion, null, TAM_CELDA, origen, COLUMNAS, FILAS, capa_profunda
	)
	var capa_escena: Node2D = npcs._capa_escena

	# Assert
	assert_object(capa_escena.get_parent()).is_same(capa_profunda)
	assert_int(capa_escena.z_index).is_equal(0)   # ⚠️ un 2 aquí devuelve el bug del usuario
	assert_bool(capa_escena.y_sort_enabled).is_true()
	assert_vector(capa_escena.position).is_equal(origen)


## Sin bolsa inyectada (sondas y tests que montan `NPCsFlujo` suelto) se conserva el comportamiento
## de antes: la capa cuelga del propio nodo y hereda su z 2. Documentado en `configurar`.
func test_sin_bolsa_inyectada_la_capa_de_munecos_se_queda_en_casa() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_sala_amurallada()
	var construccion: Node = mundo["construccion"]
	var origen: Vector2 = mundo["origen"]
	var npcs: Node2D = auto_free(NPCsFlujoScript.new())

	# Act
	npcs.configurar(null, construccion, null, TAM_CELDA, origen, COLUMNAS, FILAS, null)

	# Assert
	assert_object(npcs._capa_escena.get_parent()).is_same(npcs)
	assert_int(npcs.z_index).is_equal(2)
