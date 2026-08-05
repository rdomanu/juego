extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — PINTURA DE PAREDES Y SUELOS (2026-08-04).
##
## Enseña con el CÓDIGO REAL (`Construccion` + `ParedesSalas` + `ModoConstruccion`, sin mocks) lo que
## pidió el usuario en la quick-spec §2:
##
##   1. Una sala con TRES tramos de pared de TRES colores distintos (y el resto blanco: el color por
##      defecto de toda pared construida — muere el color por tipo de sala en las paredes).
##   2. Su suelo pintado a DOS colores (media sala de cada uno), sobre la rejilla del edificio.
##   3. El pincel con la PALETA DESPLEGADA: la UI real del modo construcción, con sus 30 muestras.
##   4. MAYÚS + clic = LA SALA ENTERA, por el camino del ratón (evento sintético con `shift_pressed`).
##
## ⚠️ La pintura se aplica POR EL MISMO CAMINO QUE EL CLIC DEL JUGADOR: se fabrica un
## `InputEventMouseButton` y se mete por `ModoConstruccion._unhandled_input` — nunca llamando a
## `Construccion.pintar_muro` por atajo. Si el bug estuviera en la traducción clic → arista/celda, un
## atajo por el modelo lo taparía.
##
## VEREDICTO PROGRAMÁTICO (no "a ojo" sobre el PNG): se compara el MODELO (`color_muro_de` /
## `color_suelo_de`) contra la GEOMETRÍA REALMENTE DIBUJADA (`ParedesSalas._tramos`).
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const EconomiaScript := preload("res://src/core/economia/economia.gd")
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ModoConstruccionScript := preload("res://src/main/modo_construccion.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const PaletaPinturaScript := preload("res://src/core/construccion/paleta_pintura.gd")

const TAM_CELDA: int = 40
## El edificio entero (24×13) proyectado mide 1480×740: el viewport lo encuadra sin cámara, igual
## que Main, para que el fantasma y la barra de la UI caigan donde caerían jugando.
const TAM_RENDER := Vector2i(1520, 800)
## La sala de pruebas: columnas 4..9, filas 3..7.
const RECT_SALA := Rect2i(4, 3, 6, 5)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Los tres colores de las tres paredes y los dos del suelo (ids de la paleta REAL — nada a mano).
const COLOR_PARED_A := &"terracota"
const COLOR_PARED_B := &"verde_salvia"
const COLOR_PARED_C := &"azul_institucional"
const COLOR_SUELO_A := &"arena"
const COLOR_SUELO_B := &"gris_azulado"

var _fallos: int = 0


func _ready() -> void:
	await _caso_pintura()
	print("[DIAG PINTURA] hecho — fallos=%d — ver %spintura_*.png" % [_fallos, CARPETA_SALIDA])
	get_tree().quit(0 if _fallos == 0 else 1)


# ── EL CASO ───────────────────────────────────────────────────────────────────────────────────

func _caso_pintura() -> void:
	var origen: Vector2 = ProyeccionScript.origen_centrado(24, 13, Vector2(TAM_RENDER))
	var piezas: Array = _montar(origen)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]

	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_documentacion", RECT_SALA)
	construccion.fijar_paredes_de_sala(sala, true)
	paredes.configurar(construccion, TAM_CELDA, origen)
	# El hook de layout es lo que en Main repinta las paredes tras CADA cambio del modelo — incluida
	# la pintura (el color de cada tramo entra en la firma de `ParedesSalas`).
	construccion.fijar_hook_layout(Callable(paredes, "actualizar"))

	var modo: Node2D = ModoConstruccionScript.new()
	modo.configurar(construccion, TAM_CELDA)
	mundo.add_child(modo)

	# ── 0) Estado de partida: TODA pared blanca, ningún suelo pintado ───────────────────────
	_afirmar(_paredes_no_blancas(paredes) == 0, "al empezar NINGUNA pared esta pintada (todas blancas)")
	await _capturar(sub, "0_sala_blanca")

	# ── 1) Tres tramos, tres colores, por el camino del clic ────────────────────────────────
	modo.activar_con_herramienta(ModoConstruccionScript.HERRAMIENTA_PINTAR_PARED, false)
	var objetivos: Array = [
		["norte", Vector2i(6, 3), &"arriba", COLOR_PARED_A],
		["sur", Vector2i(6, 7), &"abajo", COLOR_PARED_B],
		["este", Vector2i(9, 5), &"derecha", COLOR_PARED_C],
	]
	for objetivo: Array in objetivos:
		_elegir_color_en_la_paleta(modo, objetivo[3])
		_clic(modo, construccion, origen, objetivo[1], objetivo[2], false)
		var esperado: Color = PaletaPinturaScript.color_de(objetivo[3])
		var real: Color = construccion.color_muro_de(
			construccion.clave_de_muro(objetivo[1], objetivo[2])
		)
		print("[DIAG PINTURA] clic %s -> celda=%s lado=%s | color en el modelo=#%s" % [
			objetivo[0], objetivo[1], objetivo[2], real.to_html(false),
		])
		_afirmar(
			real.is_equal_approx(esperado),
			"el tramo %s queda del color elegido (#%s)" % [objetivo[0], esperado.to_html(false)]
		)
	await _capturar(sub, "1_tres_paredes_tres_colores")

	# ── 2) El suelo a dos colores: media sala de cada uno ───────────────────────────────────
	modo.activar_con_herramienta(ModoConstruccionScript.HERRAMIENTA_PINTAR_SUELO, false)
	var mitad: int = RECT_SALA.position.x + RECT_SALA.size.x / 2
	for celda: Vector2i in construccion.celdas_de_sala(sala):
		var id_color: StringName = COLOR_SUELO_A if celda.x < mitad else COLOR_SUELO_B
		_elegir_color_en_la_paleta(modo, id_color)
		_clic(modo, construccion, origen, celda, &"", false)
		_afirmar_silencioso(
			construccion.color_suelo_de(celda).is_equal_approx(
				PaletaPinturaScript.color_de(id_color)
			),
			"la celda %s queda del color de suelo elegido" % celda
		)
	print("[DIAG PINTURA] suelo pintado: %d celdas a dos colores" % construccion.area_de_sala(sala))
	await _capturar(sub, "2_suelo_dos_colores")

	# ── 3) LA PALETA DESPLEGADA: la UI real del pincel, con sus 30 muestras ─────────────────
	modo.activar_con_herramienta(ModoConstruccionScript.HERRAMIENTA_PINTAR_PARED, false)
	_afirmar(
		modo._rejilla_paleta.visible and modo._muestras.size() == 30,
		"con el pincel en la mano se despliega la paleta con sus 30 muestras"
	)
	await _capturar(sub, "3_ui_paleta_desplegada")

	# ── 4) MAYÚS + clic = LA SALA ENTERA ────────────────────────────────────────────────────
	_elegir_color_en_la_paleta(modo, COLOR_PARED_B)
	_clic(modo, construccion, origen, Vector2i(6, 3), &"arriba", true)
	var verde: Color = PaletaPinturaScript.color_de(COLOR_PARED_B)
	var distintos: int = 0
	for arista: Array in [
		[Vector2i(6, 3), &"arriba"], [Vector2i(6, 7), &"abajo"], [Vector2i(9, 5), &"derecha"],
		[Vector2i(4, 4), &"izquierda"],
	]:
		if not construccion.color_muro_de(
			construccion.clave_de_muro(arista[0], arista[1])
		).is_equal_approx(verde):
			distintos += 1
	_afirmar(distintos == 0, "MAYUS + clic deja TODA la sala del mismo color")
	# Y la fachada sigue intacta: el gesto de sala no la toca.
	var fachada_pintada: int = 0
	for clave: String in construccion.muros():
		if construccion.es_muro_fijo(clave) and construccion.muro_pintado(clave):
			fachada_pintada += 1
	_afirmar(fachada_pintada == 0, "la FACHADA sigue sin pintar (es ladrillo, no obra tuya)")
	await _capturar(sub, "4_mayus_sala_entera")

	# ── VEREDICTO: el modelo contra lo que de verdad está pintado ───────────────────────────
	_auditar(construccion, paredes, origen)


## Compara, arista a arista, el color del MODELO con el color del tramo REALMENTE dibujado.
func _auditar(construccion: Node, paredes: Node, origen: Vector2) -> void:
	var comprobados: int = 0
	var descuadres: Array[String] = []
	for clave: String in construccion.muros():
		if construccion.es_muro_fijo(clave):
			continue   # la fachada es ladrillo por decreto: su color no sale del modelo
		if construccion.tipo_muro_de_clave(clave) != construccion.TABIQUE:
			continue   # puertas y ventanas se dibujan en piezas: su firma se audita en otros diags
		var geo: Array = _geometria_de_clave(clave, origen)
		# Se muestrea al 12 % del tramo, no en su centro: el HUECO AUTOMATICO de la sala es un tabique
		# corriente en el modelo pero se DIBUJA como puerta (dos munones y el centro libre), asi que en
		# su centro no hay pared que auditar. Al 12 % siempre hay muro —sea tabique entero o munon de
		# puerta— y sigue estando lejos del vertice donde enlaza el tramo perpendicular.
		var punto: Vector2 = (geo[0] as Vector2).lerp(geo[1] as Vector2, 0.12)
		var dibujado: Color = _color_dibujado_en(paredes, punto)
		comprobados += 1
		if not dibujado.is_equal_approx(construccion.color_muro_de(clave)):
			descuadres.append("%s modelo=#%s dibujado=#%s" % [
				clave, construccion.color_muro_de(clave).to_html(false), dibujado.to_html(false),
			])
	print("[DIAG PINTURA] tramos auditados: %d | descuadres: %s" % [comprobados, descuadres])
	_afirmar(comprobados > 0, "la auditoria ha mirado tramos de verdad")
	_afirmar(descuadres.is_empty(), "TODO tramo se dibuja con EL COLOR QUE DICE EL MODELO")


# ── El camino del CLIC y de la PALETA (los mismos del jugador) ────────────────────────────────

## Elige una muestra de la paleta PULSANDO SU BOTÓN (no tocando `_color_pincel` a mano): así se
## comprueba de paso que la rejilla está cableada.
func _elegir_color_en_la_paleta(modo: Node2D, id_color: StringName) -> void:
	for i: int in PaletaPinturaScript.COLORES.size():
		if PaletaPinturaScript.COLORES[i]["id"] == id_color:
			(modo._muestras[i] as Button).pressed.emit()
			return
	push_error("[DIAG PINTURA] color '%s' que no esta en la paleta" % id_color)
	_fallos += 1


## Un clic izquierdo (pulsar + soltar) sobre la celda, opcionalmente con MAYÚS. `lado` vacío = el
## centro de la celda (el gesto del pincel de suelo, que apunta a la celda entera).
func _clic(
	modo: Node2D, construccion: Node, origen: Vector2, celda: Vector2i, lado: StringName,
	con_mayus: bool
) -> void:
	var punto_mundo: Vector2 = _punto_junto_al_lado(origen, celda, lado)
	var celda_leida: Vector2i = construccion.celda_de_punto(punto_mundo)
	if celda_leida != celda:
		push_error("[DIAG PINTURA] el punto de %s cae en la celda %s" % [celda, celda_leida])
		_fallos += 1
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		evento.shift_pressed = con_mayus
		evento.position = modo.get_canvas_transform() * punto_mundo
		modo._unhandled_input(evento)


## Un punto de MUNDO dentro de `celda`, pegado a `lado` (10 % hacia dentro) o en su centro.
func _punto_junto_al_lado(origen: Vector2, celda: Vector2i, lado: StringName) -> Vector2:
	var base := Vector2(celda) * float(TAM_CELDA)
	var dentro: Vector2 = Vector2(0.5, 0.5) * float(TAM_CELDA)
	match lado:
		&"izquierda":
			dentro = Vector2(0.1, 0.5) * float(TAM_CELDA)
		&"derecha":
			dentro = Vector2(0.9, 0.5) * float(TAM_CELDA)
		&"arriba":
			dentro = Vector2(0.5, 0.1) * float(TAM_CELDA)
		&"abajo":
			dentro = Vector2(0.5, 0.9) * float(TAM_CELDA)
	return origen + ProyeccionScript.proyectar(base + dentro)


# ── Lectura de lo dibujado ────────────────────────────────────────────────────────────────────

## Cuántos tramos dibujados NO son blancos (o sea: cuántos están pintados). La fachada YA NO se
## descuenta aparte (2026-08-05: se pinta como cualquier tramo — murió `COLOR_FACHADA`); el color por
## defecto sin pintar tampoco es blanco desde la paleta clara (`Construccion.COLOR_PARED_POR_DEFECTO`,
## azul suave), pero esta comprobación se deja tal cual: es diagnóstico desechable, no pipeline.
func _paredes_no_blancas(paredes: Node) -> int:
	var total: int = 0
	for tramo: Dictionary in paredes._tramos:
		var color: Color = tramo["color"]
		if color.is_equal_approx(Color.WHITE):
			continue
		if color.is_equal_approx(ParedesSalasScript.COLOR_VENTANA):
			continue
		total += 1
	return total


## El color de la primera pieza dibujada que pasa por ese punto (transparente si no hay ninguna).
func _color_dibujado_en(paredes: Node, punto: Vector2) -> Color:
	for tramo: Dictionary in paredes._tramos:
		var cercano: Vector2 = Geometry2D.get_closest_point_to_segment(
			punto, tramo["desde"], tramo["hasta"]
		)
		if punto.distance_to(cercano) <= 1.0:
			return tramo["color"]
	return Color.TRANSPARENT


## Los dos extremos (en MUNDO) de una arista dada por su CLAVE de modelo ("v:col:row"/"h:col:row").
func _geometria_de_clave(clave: String, origen: Vector2) -> Array:
	var partes: PackedStringArray = clave.split(":")
	var a: int = int(partes[1])
	var b: int = int(partes[2])
	if partes[0] == "v":
		return [
			origen + ProyeccionScript.esquina_iso(a, b),
			origen + ProyeccionScript.esquina_iso(a, b + 1),
		]
	return [
		origen + ProyeccionScript.esquina_iso(a, b),
		origen + ProyeccionScript.esquina_iso(a + 1, b),
	]


func _afirmar(condicion: bool, que: String) -> void:
	if condicion:
		print("[DIAG PINTURA] ✓ %s" % que)
		return
	_fallos += 1
	print("[DIAG PINTURA] ✗ FALLA: %s" % que)


## Como `_afirmar` pero solo habla cuando falla (para los bucles de 30 celdas).
func _afirmar_silencioso(condicion: bool, que: String) -> void:
	if condicion:
		return
	_fallos += 1
	print("[DIAG PINTURA] ✗ FALLA: %s" % que)


# ── Montaje y captura ─────────────────────────────────────────────────────────────────────────

## Un SubViewport montado como Main: SIN cámara (mundo == pantalla), con la rejilla del suelo y con
## la bolsa de y-sort compartida. Devuelve [sub, mundo, construccion, paredes, profundo].
func _montar(origen: Vector2) -> Array:
	var sub := SubViewport.new()
	sub.size = TAM_RENDER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -1
	sub.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.14, 0.16)
	fondo.size = Vector2(TAM_RENDER)
	capa_fondo.add_child(fondo)
	var mundo := Node2D.new()
	sub.add_child(mundo)
	# La REJILLA del edificio, debajo de todo (z −2, como el "Suelo" de Main): el encargo pide verla
	# para juzgar qué celda está pintada de qué.
	var rejilla := Rejilla.new()
	rejilla.origen = origen
	rejilla.z_index = -2
	mundo.add_child(rejilla)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	var eco := EconomiaScript.new()
	eco.aplicar_config(ConfigEconomiaScript.new())
	mundo.add_child(eco)
	construccion.usar_economia(eco)
	eco.abonar(50000.0)
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, origen, profundo)
	return [sub, mundo, construccion, paredes, profundo]


## La rejilla isométrica del edificio, dibujada a mano (el diagnóstico no monta Main entero).
class Rejilla extends Node2D:
	var origen: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var color := Color(1.0, 1.0, 1.0, 0.10)
		for columna: int in range(25):
			draw_line(
				origen + Proyeccion.esquina_iso(columna, 0),
				origen + Proyeccion.esquina_iso(columna, 13), color, 1.0, true
			)
		for fila: int in range(14):
			draw_line(
				origen + Proyeccion.esquina_iso(0, fila),
				origen + Proyeccion.esquina_iso(24, fila), color, 1.0, true
			)


## Guarda el PNG completo de la pasada.
func _capturar(sub: SubViewport, nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = sub.get_texture().get_image()
	var ruta: String = "%spintura_%s.png" % [CARPETA_SALIDA, nombre]
	var err: Error = imagen.save_png(ruta)
	if err != OK:
		push_error("[DIAG PINTURA] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG PINTURA] %s -> %s" % [nombre, ruta])
