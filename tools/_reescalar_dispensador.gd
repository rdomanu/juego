extends "res://tools/render_mobiliario.gd"
## _reescalar_dispensador — Fase 1 de calidad visual (auditoría 2026-08-03): SOLO
## `comodidad_dispensador_agua` estaba sobredimensionado frente a la persona de 44 px (pared
## medida ~37-38 px; objetivo 29-34 px, ver `design/art/investigacion/auditoria-visual.md`). Las
## otras dos piezas señaladas en el primer encargo (radio, equipo informático) quedaron
## DESCARTADAS por el coordinador tras revisar el kit de referencia — no se tocan.
##
## Hereda TODO el pipeline de `render_mobiliario.gd` (misma cámara fija 30°/45°, mismas recetas,
## misma calibración de escala contra el mostrador) para que el resultado sea BIT-IDÉNTICO al que
## saldría de relanzar la herramienta completa — pero sobreescribe `_ejecutar()` para renderizar
## en la GPU SOLO lo estrictamente necesario:
##   · `mostrador_atencion` a 0° — la referencia de calibración de `escala_final` (no se guarda).
##   · `comodidad_dispensador_agua` — las 4 rotaciones (se guarda, con un multiplicador propio
##     sobre `escala_final`, mismo patrón que `MULTIPLICADOR_MOSTRADOR1`/`MULTIPLICADOR_SOFA3` del
##     padre).
## Así NUNCA se llama a `Image.save_png()` para ninguna otra receta -- cero riesgo de tocar
## `mostrador_atencion`, `comodidad_radio`, `comodidad_equipo_informatico`, etc. `radio_max` (la
## cámara) SÍ se calcula sobre TODAS las recetas (`_ancla_de`/`_radio_de`, geometría pura, sin
## GPU) -- eso es lo que garantiza el "bit-idéntico": un `tam_camara` distinto cambiaría el
## encuadre en bruto del mostrador y, con él, `escala_final` (ver la nota de más abajo).
##
## MULTIPLICADOR_DISPENSADOR: medido con Python (`medir_pared.py`, fuera de Godot, fórmula del
## encargo -- pared = alto_opaco - (Lu+Lv)×20, umbral alfa>10/255) sobre los PNG que va guardando
## el propio proceso de esta pieza (ronda 1: `escala_final`×1,00 sin tocar; ronda 2: la que ya
## había en disco).
##
## RONDA 1 (bug encontrado y corregido en la propia medición, no en el render): mi primera pasada
## de `medir_pared.py` desempataba las esquinas W/E (columna más a la izq/dcha, cuando hay varias
## filas empatadas en ese extremo -- el dispensador tiene una pared vertical recta de armario, no
## una caja con un único vértice) tomando la MEDIA de esas filas. Eso coge el CENTRO de la pared
## del armario, no su PIE (la esquina real de la base, la fila más baja/cercana al suelo entre las
## empatadas) -- inflaba Lu/Lv y salía `pared`≈37,5 px, sistemáticamente ~1,5× por debajo de lo
## real. Corregido a "fila MÁS BAJA entre las empatadas" (coherente con el criterio ya escrito en
## la cabecera de `render_mobiliario.gd` para `MULTIPLICADOR_MOSTRADOR1`: "esquina más a la
## izq/dcha, SU Y MÁS BAJA"). Con la corrección, sobre el PNG de la ronda 1 (25×70 sin tocar, antes
## de aplicar ningún multiplicador): pared ≈ 49,25 px en las 4 rotaciones -- coincide con la
## medida del coordinador (49 px).
##
## RONDA 2: objetivo 29-34 px (medio 31,5) -> factor = 31,5/49,25 = 0,6396 ≈ 0,65 (pedido del
## coordinador, "aplica ×0,65 sobre la escala actual de la receta" -- verificado: 49,25×0,65=32,0,
## dentro de rango). ⚠️ "la escala actual de la receta" es la de la RONDA 1 YA APLICADA
## (`escala_final`×0,84 -- el PNG de 21×58 px que hay en disco, el que se acaba de medir), NO
## `escala_final`×1,00: este script SIEMPRE reescala desde el `bruto` de Godot (geometría 3D real,
## recién renderizada), nunca desde un PNG ya reescalado -- así que hay que arrastrar el 0,84 de la
## ronda 1 a mano. `MULTIPLICADOR_DISPENSADOR` final = 0,84 × 0,65 = 0,546.
## RONDA 3 (2026-08-03): el usuario, mirando la hoja de tamaños A/B/C junto al policía, eligió la
## B ("crecido": pared ~41 px, presencia clara en su celda sin competir con las personas) — el
## realista de 32 px se le quedaba perdido en la cuadrícula. Factor ×1,28 sobre la ronda 2:
## 0,546 × 1,28 = 0,699 (pared esperada ≈ 32×1,28 ≈ 41).
const MULTIPLICADOR_DISPENSADOR: float = 0.699


func _ejecutar(todas: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var recetas: Array[Dictionary] = _recetas()

	# 1) Cámara fija: radio_max sobre TODAS las recetas (geometría pura, sin GPU) -- idéntico al
	# padre, para que el encuadre en bruto (y por tanto `escala_final`) no varíe ni un píxel.
	var anclas: Dictionary = {}
	var radio_max := 0.0
	for receta: Dictionary in recetas:
		var ancla: Vector3 = _ancla_de(receta, todas)
		anclas[receta["id_salida"]] = ancla
		radio_max = maxf(radio_max, _radio_de(receta, todas, ancla))
	var tam_camara: float = radio_max * 2.0 * MARGEN
	print("[REESCALAR_DISPENSADOR] radio máximo de las recetas: %.3f m -> cámara fija a %.3f m" % [
		radio_max, tam_camara
	])

	_sub = SubViewport.new()
	_sub.size = Vector2i(TAM_RENDER, TAM_RENDER)
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.own_world_3d = true
	add_child(_sub)

	var mundo := Node3D.new()
	_sub.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	mundo.add_child(sol)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	entorno.environment = env
	mundo.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(_camara)
	_colocar_camara(tam_camara)

	var grupo := Node3D.new()
	mundo.add_child(grupo)

	# 2) Render en GPU SOLO de lo necesario: mostrador (rot 0, referencia de calibración) +
	# comodidad_dispensador_agua (las 4 rotaciones, la única que se guarda).
	var crudos: Dictionary = {}

	_montar_receta(grupo, _receta_por_id(recetas, ID_MOSTRADOR), todas, anclas[ID_MOSTRADOR])
	grupo.rotation = Vector3.ZERO
	var bruto_mostrador: Dictionary = await _renderizar_bruto()
	crudos[ID_MOSTRADOR] = {0: bruto_mostrador}
	print("[REESCALAR_DISPENSADOR] %s @ 0° (solo calibración, no se guarda): bruto %dx%d px" % [
		ID_MOSTRADOR, (bruto_mostrador["imagen"] as Image).get_width(),
		(bruto_mostrador["imagen"] as Image).get_height()
	])

	var receta_dispensador: Dictionary = _receta_por_id(recetas, ID_DISPENSADOR)
	_montar_receta(grupo, receta_dispensador, todas, anclas[ID_DISPENSADOR])
	var por_rotacion: Dictionary = {}
	for rot: int in ROTACIONES:
		grupo.rotation = Vector3(0.0, deg_to_rad(float(rot)), 0.0)
		var bruto: Dictionary = await _renderizar_bruto()
		por_rotacion[rot] = bruto
		var imagen: Image = bruto["imagen"]
		print("[REESCALAR_DISPENSADOR] %s @ %d°: bruto %dx%d px" % [
			ID_DISPENSADOR, rot, imagen.get_width(), imagen.get_height()
		])
	crudos[ID_DISPENSADOR] = por_rotacion

	# 3) Calibración: EXACTA al paso 3 del padre (mismo `ID_MOSTRADOR` a 0°, mismo
	# `ESCALA_OBJETIVO_MOSTRADOR`) -- así `escala_final` sale idéntico al de la última pasada
	# completa, sin necesidad de haber renderizado el resto de recetas.
	var referencia: Dictionary = crudos[ID_MOSTRADOR][0]
	var ancho_bruto: int = (referencia["imagen"] as Image).get_width()
	var ancho_objetivo: float = Proyeccion.ANCHO_ROMBO * ESCALA_OBJETIVO_MOSTRADOR
	var escala_final: float = ancho_objetivo / float(maxi(ancho_bruto, 1))
	print(
		"[REESCALAR_DISPENSADOR] calibración: mostrador bruto=%dpx -> objetivo=%.1fpx (80×%.2f) -> factor=%.4f"
		% [ancho_bruto, ancho_objetivo, ESCALA_OBJETIVO_MOSTRADOR, escala_final]
	)

	# 4) Guarda SOLO comodidad_dispensador_agua, a escala_final * MULTIPLICADOR_DISPENSADOR.
	# `_guardar_receta_a_escala` (heredado) imprime lienzo/ancla -- esa es la fuente de la tabla
	# de anclas por rotación del informe final.
	_guardar_receta_a_escala(crudos, ID_DISPENSADOR, ID_DISPENSADOR, escala_final * MULTIPLICADOR_DISPENSADOR)

	print("[REESCALAR_DISPENSADOR] hecho.")
	get_tree().quit()


func _receta_por_id(recetas: Array[Dictionary], id_salida: String) -> Dictionary:
	for receta: Dictionary in recetas:
		if receta["id_salida"] == id_salida:
			return receta
	push_error("REESCALAR_DISPENSADOR: receta no encontrada: %s" % id_salida)
	return {}
