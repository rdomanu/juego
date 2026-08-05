# Silla vs tramo SUR — el y-sort tiene que seguir dando ganador al TRAMO (bug reportado por el
# usuario 2026-08-05: "he puesto paredes en la ODAC y la silla aparece montada encima de la media
# pared", tras subir ALTO_PARED de 34 a 65 px en dab56de).
#
# INVESTIGACIÓN (agente GDScript, 2026-08-06 · `tools/_diag_capas_odac.gd`): con los números en la
# mano, el ORDEN es CORRECTO — el tramo gana por diseño (`ParedesSalas._punto_de_orden`, la MISMA
# cuenta que ya usan sofás/mostradores/divisorios, validada por `_diag_oclusion_murete.gd`). Medido
# con la sonda: tramo sur `orden.y` = 290.00, silla `y_mundo` = 280.00 → el tramo gana por 10 px.
#
# Lo que el usuario VE (la punta del respaldo asomando sobre la media pared) NO es un bug de
# coordenadas: es que el sprite `silla_espera_270.png` (44 px, ancla en fracción 0.797 → el
# respaldo sube 35 px sobre el punto de anclaje) es más alto que `ALTO_PARED_FRENTE` (32.5 px) en
# el punto de la pared donde se apoya — y encima esa pared es una recta DIAGONAL (`_agregar_arista`
# aplica el alto en vertical puro), así que a la X exacta de la silla el borde de la pared está
# aún más bajo que en su punto medio: el hueco visible ronda los 22-23 px, no los 2-3 que daría el
# punto medio del tramo. Es una tensión de ALTURA entre dos valores recién afinados a mano
# (`ALTO_PARED_FRENTE`, 2026-08-05; `ANCLA_FRACCION_SILLA_ESPERA`, 2026-08-02), no un descuadre de
# `_punto_de_orden` — así que este test NO cambia ese hueco (sería tocar una constante de diseño
# ajena sin que el usuario lo haya pedido). Lo que SÍ hace es fijar como CANDADO DE REGRESIÓN el
# invariante que hoy es correcto: que el tramo siga ganando el y-sort contra la silla con holgura
# —para que un cambio futuro en `Proyeccion.centro_iso` o en `_punto_de_orden` no vuelva a invertir
# el orden (que sí sería la vuelta del bug de antes del paso a y-sort, 2026-08-03) sin que un test
# lo note.
#
# Tipo: Logic. DETERMINISTA (sin azar, sin reloj, sin I/O). Aislamiento: nodos `.new()` sin escena
# (`auto_free`), montados fuera del árbol — mismo patrón que el resto de `tests/unit/construccion`.
extends GdUnitTestSuite

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 10
const FILAS: int = 10
const SALA_ESPERA_ODAC := &"sala_espera_odac"
## Columnas 2..6, filas 2..5 (mismo rect que usa la sonda `_diag_capas_odac.gd`).
const RECT_SALA := Rect2i(2, 2, 5, 4)
## Última fila interior, pegada por dentro al muro sur (la arista vive en la fila-rejilla 6).
const CELDA_JUNTO_AL_MURO_SUR := Vector2i(4, 5)
## Holgura pedida por el coordinador para la comparación numérica.
const TOLERANCIA_PX: float = 3.0


## Sala de espera ODAC con paredes fijadas + una silla pegada por dentro al muro sur — sin
## `SubViewport` ni GPU: `ParedesSalas`/`Construccion` calculan geometría en `Node2D`s fuera de
## árbol, no hace falta renderizar nada para leer sus números.
func _mundo_con_silla_junto_al_muro() -> Dictionary:
	var construccion: Node = auto_free(ConstruccionScript.new())
	construccion.aplicar_config(ConfigConstruccionScript.new())
	construccion.edificio_columnas = COLUMNAS
	construccion.edificio_filas = FILAS
	var capa_profunda: Node2D = auto_free(Node2D.new())
	var origen: Vector2 = ProyeccionScript.origen_centrado(COLUMNAS, FILAS, Vector2(700, 560))
	construccion.montar_visual(TAM_CELDA, origen, capa_profunda)
	construccion.levantar_fachada()
	var sala_id: StringName = construccion.construir_de_oficio_sala(SALA_ESPERA_ODAC, RECT_SALA)
	construccion.fijar_paredes_de_sala(sala_id, true)
	construccion.construir_de_oficio_elemento(construccion.ASIENTO_BASICO, CELDA_JUNTO_AL_MURO_SUR)
	var paredes: Node2D = auto_free(ParedesSalasScript.new())
	paredes.configurar(construccion, TAM_CELDA, origen)
	return {"construccion": construccion, "paredes": paredes}


func test_orden_silla_vs_tramo_sur_gana_el_tramo() -> void:
	# Arrange
	var mundo: Dictionary = _mundo_con_silla_junto_al_muro()
	var construccion: Node = mundo["construccion"]
	var paredes: Node2D = mundo["paredes"]

	# Act — los dos puntos de orden, en el MISMO eje: el del tramo ya incluye el desplazamiento
	# (sale de `_esquina()`, que lo suma); el de la silla es LOCAL a `_capa_elementos` (cuyo
	# `position` ES el desplazamiento — ver `Construccion.montar_visual`), así que se le suma para
	# comparar contra el mismo origen.
	var clave_tramo_sur: String = "h:%d:%d" % [CELDA_JUNTO_AL_MURO_SUR.x, RECT_SALA.end.y]
	var orden_tramo: float = NAN
	for tramo: Dictionary in paredes._tramos:
		if tramo.has("clave_modelo") and String(tramo["clave_modelo"]) == clave_tramo_sur:
			orden_tramo = (tramo["orden"] as Vector2).y
			break
	var desplazamiento_y: float = (construccion._capa_elementos as Node2D).position.y
	var orden_silla: float = NAN
	for hijo: Node in construccion._capa_elementos.get_children():
		if hijo is Node2D and (hijo as Node2D).position.is_equal_approx(
			ProyeccionScript.centro_iso(CELDA_JUNTO_AL_MURO_SUR)
		):
			orden_silla = (hijo as Node2D).position.y + desplazamiento_y
			break

	# Assert
	assert_bool(is_nan(orden_tramo)).is_false()
	assert_bool(is_nan(orden_silla)).is_false()
	# El tramo tiene que ganar (dibujarse DESPUÉS, y_orden mayor) con al menos `TOLERANCIA_PX` de
	# holgura. Hoy la diferencia real es de 10 px (290.0 vs 280.0) — si un cambio futuro la erosiona
	# por debajo de la tolerancia, este test lo atrapa antes de que la silla vuelva a "montarse" en
	# la pared por un problema de ORDEN (que sí sería un bug nuevo, distinto del hueco de altura
	# documentado arriba).
	assert_float(orden_tramo - orden_silla).is_greater_equal(TOLERANCIA_PX)
