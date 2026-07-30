class_name LucesObjetos extends Node2D
## LucesObjetos — las luces de lo que has comprado **se encienden al caer la noche**.
##
## Petición del usuario (2026-07-28): *"sobre los objetos habría que añadir las luces y que se
## enciendan cuando empiece la noche"*. Cada comodidad del catálogo con `emite_luz` recibe un
## `PointLight2D`; su energía sube al anochecer y baja al amanecer, con la misma curva horaria que el
## ciclo de luz general — así encienden **justo cuando la sala se pone azul**, no antes ni después.
##
## Es lo que pide la §2 del art bible para la noche: *"fría, azulada, nivel bajo con focos
## puntuales"*. Los focos puntuales son estos.
##
## Reglas (control-manifest, Presentation): COSMÉTICO puro. Solo LEE Construcción (dónde está cada
## objeto) y el reloj (qué hora es); no toca la simulación. Se repuebla por DIFF (solo cuando cambia
## lo construido), nunca por frame. — ADR-0001 / ADR-0004

## Hora a la que las luces están del todo encendidas (21:00) y del todo apagadas (08:00). Entre medias
## se interpola, así que encienden y apagan de forma gradual, como el resto de la luz del día.
const MIN_NOCHE_PLENA := 1260.0
const MIN_DIA_PLENO := 480.0
## Amanece/anochece en estas horas: fuera de [MIN_DIA_PLENO, MIN_NOCHE_PLENA] la transición es suave.
const MIN_ANOCHECER := 1140.0   # 19:00 — empiezan a notarse
const MIN_AMANECER := 420.0     # 07:00 — empiezan a sobrar

const MINUTOS_POR_DIA := 1440.0

var _construccion: Node = null
var _tiempo: Node = null
## `elemento_id -> PointLight2D`, para no recrear luces que ya existen.
var _luz_de: Dictionary[StringName, PointLight2D] = {}
## Firma de lo construido: si no cambia, no se toca ningún nodo.
var _firma: String = ""
## Última energía aplicada (evita escribir en N luces cada frame por un cambio invisible).
var _energia_vista: float = -1.0
## Textura degradada que da la forma redonda a la luz (se genera una vez y la comparten todas).
var _textura: Texture2D = null


func configurar(construccion: Node, tiempo: Node) -> void:
	_construccion = construccion
	_tiempo = tiempo
	_textura = _crear_textura_luz()
	z_index = 3   # por encima de todo (suelo 0, paredes 1, gente 2): es luz, no un objeto


func _process(_delta: float) -> void:
	if _construccion == null:
		return
	_sincronizar_luces()
	_aplicar_energia()


## Crea o retira luces según lo que haya construido. Por DIFF: la firma es la lista de objetos
## luminosos, así que comprar una tele o demolerla es lo único que dispara trabajo real.
func _sincronizar_luces() -> void:
	var luminosos: Dictionary[StringName, Resource] = {}
	# Los TRES tipos de sala: la familia "iluminacion" (petición 2026-07-29) se coloca en
	# cualquiera, y la sala de descanso YA tenía objetos con `emite_luz` (dispensador de agua,
	# máquina de café) cuyo piloto nunca se encendía porque este bucle se paró en dos tipos.
	var salas: Array[StringName] = _construccion.salas_de_tipo("espera")
	salas += _construccion.salas_de_tipo("oficina")
	salas += _construccion.salas_de_tipo("descanso")
	for sala_id: StringName in salas:
		for elemento_id: StringName in _construccion.contenido_de_sala(sala_id):
			var comodidad: Resource = Datos.obtener_silencioso(
				&"Comodidad", _construccion.catalogo_de_elemento(elemento_id)
			)
			if comodidad != null and comodidad.emite_luz:
				luminosos[elemento_id] = comodidad
	var firma: String = ",".join(PackedStringArray(luminosos.keys()))
	if firma == _firma:
		return
	_firma = firma
	# 🐛 Corregido 2026-07-29 (el usuario: "si pongo una luz de noche no se enciende hasta la
	# siguiente noche"). `_aplicar_energia` se salta el trabajo cuando la energia global no ha
	# cambiado — que es lo normal a media noche cerrada. Una lampara recien comprada nacia entonces
	# con su energia por defecto y se quedaba APAGADA hasta el siguiente amanecer/anochecer, cuando
	# la energia volviera a moverse. Al cambiar lo construido se invalida esa cache para que la luz
	# nueva reciba la energia de ESTE momento: si la pones de noche, alumbra ya; si la pones de dia,
	# nace apagada, que es lo que toca.
	_energia_vista = -1.0
	# Fuera las que ya no están (objeto demolido).
	for elemento_id: StringName in _luz_de.keys():
		if not luminosos.has(elemento_id):
			_luz_de[elemento_id].queue_free()
			_luz_de.erase(elemento_id)
	# Y alta de las nuevas.
	for elemento_id: StringName in luminosos:
		if _luz_de.has(elemento_id):
			continue
		var comodidad: Resource = luminosos[elemento_id]
		var luz := PointLight2D.new()
		luz.texture = _textura
		luz.color = comodidad.color_luz
		luz.texture_scale = comodidad.radio_luz / 64.0   # la textura base mide 128 px (radio 64)
		# Luces NO redondas (decision del usuario 2026-07-30): el fluorescente es un TUBO y alumbra una
		# franja, no un circulo. `texture_scale` es un unico numero, asi que el alto distinto se
		# consigue achatando el propio nodo — la textura redonda sigue siendo la misma para todas.
		if comodidad.radio_luz_y > 0.0 and comodidad.radio_luz > 0.0:
			luz.scale = Vector2(1.0, comodidad.radio_luz_y / comodidad.radio_luz)
		luz.energy = 0.0
		luz.blend_mode = Light2D.BLEND_MODE_ADD          # suma luz, no repinta el suelo
		# ISOMÉTRICO (2026-07-30): la luz se DIBUJA, así que va en pantalla (centro del rombo de su
		# celda), no en el plano lógico cuadrado por el que anda la gente.
		luz.position = _construccion.centro_en_pantalla(_construccion.posicion_de(elemento_id))
		add_child(luz)
		_luz_de[elemento_id] = luz


## Sube o baja la energía de TODAS las luces según la hora. Un solo cálculo por frame y, si el valor
## no ha cambiado de forma perceptible, ni se tocan los nodos.
func _aplicar_energia() -> void:
	if _luz_de.is_empty() or _tiempo == null:
		return
	var energia: float = energia_a_las(_tiempo.minutos_juego)
	if absf(energia - _energia_vista) < 0.01:
		return
	_energia_vista = energia
	for elemento_id: StringName in _luz_de:
		var luz: PointLight2D = _luz_de[elemento_id]
		luz.energy = energia
		luz.visible = energia > 0.01   # apagadas del todo, ni se dibujan


## Cuánta luz dan a esa hora: **0 de día, 1 de noche**, con transición suave al anochecer y al
## amanecer. Función **pura** (recibe la hora, no la busca) → se comprueba sin reloj ni ventana.
static func energia_a_las(minuto_del_dia: float) -> float:
	var min_dia: float = fposmod(minuto_del_dia, MINUTOS_POR_DIA)
	if min_dia >= MIN_NOCHE_PLENA or min_dia <= MIN_AMANECER:
		return 1.0
	if min_dia >= MIN_DIA_PLENO and min_dia <= MIN_ANOCHECER:
		return 0.0
	if min_dia < MIN_DIA_PLENO:
		# Amaneciendo: de 1 a 0 entre las 07:00 y las 08:00.
		return 1.0 - (min_dia - MIN_AMANECER) / (MIN_DIA_PLENO - MIN_AMANECER)
	# Anocheciendo: de 0 a 1 entre las 19:00 y las 21:00.
	return (min_dia - MIN_ANOCHECER) / (MIN_NOCHE_PLENA - MIN_ANOCHECER)


## Un degradado radial blanco→transparente de 128×128, la forma de la luz. Se genera por código: el
## proyecto no tiene pipeline de assets todavía y una textura de este tipo no merece un PNG.
func _crear_textura_luz() -> Texture2D:
	var lado: int = 128
	var imagen: Image = Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var centro: Vector2 = Vector2(lado, lado) * 0.5
	for y: int in range(lado):
		for x: int in range(lado):
			var d: float = Vector2(x, y).distance_to(centro) / (float(lado) * 0.5)
			# Caída suave (cuadrática): el borde se difumina en vez de cortarse en seco.
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			imagen.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(imagen)
