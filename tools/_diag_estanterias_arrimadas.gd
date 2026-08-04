extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — el ARRIMADO A PARED de las estanterías, con el código
## REAL (`Construccion` + `ParedesSalas`, sin mocks).
##
## Orden del usuario (quick-spec construccion-pintura-puertas-preview-2026-08-04 §1): las estanterías
## son muebles DE PARED — *"se anclan al EXTREMO de su celda según su orientación, de modo que NO
## quede hueco entre la pared y la estantería; quedaría mal y poco realista, tienes que ver que esto
## se respete"*. Y con verificación NUMÉRICA obligatoria, no a ojo.
##
## ── EL JUEZ ES UN NÚMERO (misma regla que `_diag_oclusion_murete.gd`) ──────────────────────────
## Por cada pieza se compara, en píxeles de PANTALLA:
##   · ESPERADO — el punto medio de la ARISTA de la celda por la que el mueble da la espalda (la
##     línea donde está la pared). Sale de `Proyeccion`, o sea del MODELO.
##   · REAL — el punto medio del borde TRASERO de la base opaca del sprite, reconstruido del DIBUJO:
##     centro de la base medido en el PNG (`AnclajeSprite.centro_base`) + el semieje de fondo, también
##     medido (`AnclajeSprite.semiejes_base`), en la dirección de la espalda.
## Delta ≤ 3 px en los dos ejes = PASA (por debajo del grosor de la línea de la rejilla: indistinguible
## a ojo, que es justo lo que no se podía decidir mirando la foto).
##
## ── LOS TRES MONTAJES ─────────────────────────────────────────────────────────────────────────
##  (A) CUATRO PAREDES — una estantería grande contra cada una de las cuatro paredes de una sala de
##      espera, cada una con la rotación cuya espalda mira a esa pared (norte 0°, este 90°, sur 180°,
##      oeste 270°). Las de 0° y 270° se colocan por el CAMINO REAL DEL JUEGO
##      (`construir_de_oficio_elemento` + `orientacion`); las de 90° y 180° se montan a mano porque
##      hoy la R solo tiene dos estados y no se llega a ellas (ver el informe).
##  (B) ESQUINA — las DOS estanterías pequeñas (OBJ_022 suelto) montando el rincón noroeste: una
##      pegada a la pared norte y otra a la oeste. Se mide, además del arrimado de cada una, el HUECO
##      que queda entre las dos.
##  (C) TRAMO SEGUIDO — dos pequeñas en celdas contiguas de la misma pared, para ver cuánto separa la
##      cuadrícula a dos módulos consecutivos.
##  (D) ESQUINA COMPLETA (2026-08-04, mueble propio de 2 celdas) — `estanteria_esquina` (OBJ_022
##      ENTERO, los dos brazos en la misma pieza) plantada EN el rincón noroeste de una sala aparte,
##      al lado de (B) en el mismo fotograma para que se vea morir el hueco. El juez aquí NO es
##      "borde trasero contra una arista" (esa cuenta asume una base rectangular convexa — ver el
##      aviso de `Construccion.COMODIDAD_ESTANTERIA_ESQUINA` sobre por qué `semiejes_base` no vale
##      para una L): es `_test_arrimado_esquina`, que compara el CENTRO de la base contra el VÉRTICE
##      que comparten las dos paredes — dos ejes, mismo margen de 3 px.
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const ParedesSalasScript := preload("res://src/main/paredes_salas.gd")
const ProyeccionScript := preload("res://src/foundation/proyeccion/proyeccion.gd")
const AnclajeSpriteScript := preload("res://src/foundation/proyeccion/anclaje_sprite.gd")

const TAM_CELDA: int = 40
const TAM_RENDER := Vector2i(900, 620)

## Carpeta del scratchpad de esta sesión (fuera del repo — PROHIBIDO escribir en assets/capturas/).
const CARPETA_SALIDA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/"

## Margen del test de arrimado, en píxeles de pantalla.
const TOLERANCIA_PX: float = 3.0

const ESTANTERIA := &"estanteria"
const ESTANTERIA_PEQUENA := &"estanteria_pequena"
const ESTANTERIA_ESQUINA := &"estanteria_esquina"

const ESPALDA_NORTE := Vector2i(0, -1)
const ESPALDA_ESTE := Vector2i(1, 0)
const ESPALDA_SUR := Vector2i(0, 1)
const ESPALDA_OESTE := Vector2i(-1, 0)

## Resultados de esta pasada: etiqueta → PASA/FALLA.
var _veredictos: Dictionary[String, bool] = {}


func _ready() -> void:
	_volcar_medidas()
	await _caso_cuatro_paredes()
	await _caso_esquina()
	await _caso_esquina_completa()
	var fallos: int = 0
	for etiqueta: String in _veredictos:
		if not _veredictos[etiqueta]:
			fallos += 1
	print("[DIAG ARRIMADO] RESUMEN: %d pieza(s), %d FALLA(N) -> %s" % [
		_veredictos.size(), fallos, "PASA" if fallos == 0 else "FALLA"
	])
	get_tree().quit()


## ── LO QUE MIDE EL JUEGO DE CADA PNG, ANTES DE DIBUJAR NADA ───────────────────────────────────
## El fondo medido es lo único de lo que depende el arrimado, así que se imprime primero: si esta
## tabla estuviera mal, todo lo demás estaría mal por la misma razón. Se comprueba de paso que las
## cuatro rotaciones de un mismo mueble dan el MISMO centro de base (comparten lienzo y ancla) y que
## los semiejes se INTERCAMBIAN al girar 90° (lo largo pasa a ser lo hondo).
func _volcar_medidas() -> void:
	for id_catalogo: StringName in [ESTANTERIA, ESTANTERIA_PEQUENA]:
		var datos: Dictionary = ConstruccionScript._sprites_comodidad()[id_catalogo]
		var prefijo: String = String(datos.get("sprite", String(id_catalogo)))
		for rot: int in [0, 90, 180, 270]:
			var ruta: String = "res://assets/sprites/mobiliario/comodidad_%s_%d.png" % [prefijo, rot]
			if not ResourceLoader.exists(ruta):
				push_error("[DIAG ARRIMADO] falta el PNG '%s'" % ruta)
				continue
			var textura: Texture2D = load(ruta)
			var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(textura)
			var espalda: Vector2i = AnclajeSpriteScript.espalda_girada(datos["espalda_0"], rot)
			var fondo: float = semiejes.y if espalda.x == 0 else semiejes.x
			# EL CONTRASTE que impide que la espalda declarada se quede desfasada: el eje por el que
			# el mueble da la espalda TIENE que ser el eje por el que es delgado, y eso se mide.
			var eje_corto: Vector2i = AnclajeSpriteScript.eje_corto(textura)
			var eje_espalda := Vector2i(absi(espalda.x), absi(espalda.y))
			var coherente: bool = eje_corto == eje_espalda
			if not coherente:
				push_error("[DIAG ARRIMADO] %s@%d°: espalda %s por el eje %s pero el mueble es delgado por %s" % [
					prefijo, rot, espalda, eje_espalda, eje_corto,
				])
			print("[DIAG ARRIMADO] %s@%d° PNG %dx%d centro_base=%s base=(%.1f x %.1f) px | espalda=%s fondo=%.2f -> recorrido=%.2f px | desvío pantalla=%s | eje corto medido=%s %s" % [
				prefijo, rot, textura.get_width(), textura.get_height(),
				AnclajeSpriteScript.centro_base(textura), semiejes.x * 2.0, semiejes.y * 2.0,
				espalda, fondo * 2.0, maxf(TAM_CELDA * 0.5 - fondo, 0.0),
				AnclajeSpriteScript.desvio_arrimado(textura, espalda),
				eje_corto, "OK" if coherente else "INCOHERENTE",
			])
			_veredictos["medida-%s@%d" % [prefijo, rot]] = coherente


## ── EL TEST NUMÉRICO ──────────────────────────────────────────────────────────────────────────
## `espalda` es hacia qué pared debe dar la espalda esta pieza. Devuelve el punto REAL (medio del
## borde trasero, en pantalla) para poder medir después huecos entre piezas.
func _test_arrimado(
	sprite: Sprite2D, origen: Vector2, celda: Vector2i, espalda: Vector2i, etiqueta: String
) -> Vector2:
	if sprite == null or sprite.texture == null:
		push_error("[DIAG ARRIMADO %s] SIN sprite -- test no aplicable" % etiqueta)
		_veredictos[etiqueta] = false
		return Vector2.INF
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(sprite.texture)
	var semieje_fondo: float = semiejes.y if espalda.x == 0 else semiejes.x
	# REAL: el centro de la base, tal y como QUEDA dibujado (posición del nodo + su offset + el píxel
	# del centro de base), llevado al plano cuadrado y corrido su medio fondo hacia la espalda.
	var centro_pantalla: Vector2 = (
		sprite.global_position + sprite.offset + AnclajeSpriteScript.centro_base(sprite.texture)
	)
	var centro_cuadrado: Vector2 = ProyeccionScript.desproyectar(centro_pantalla - origen)
	var trasero_cuadrado: Vector2 = centro_cuadrado + Vector2(espalda) * semieje_fondo
	var real: Vector2 = origen + ProyeccionScript.proyectar(trasero_cuadrado)
	# ESPERADO: el punto medio de la arista de la celda por la que da la espalda (la línea de pared).
	var linea_cuadrado: Vector2 = (
		ProyeccionScript.centro_cuadrado(celda) + Vector2(espalda) * (TAM_CELDA * 0.5)
	)
	var esperado: Vector2 = origen + ProyeccionScript.proyectar(linea_cuadrado)
	var delta: Vector2 = real - esperado
	var pasa: bool = absf(delta.x) <= TOLERANCIA_PX and absf(delta.y) <= TOLERANCIA_PX
	print("[DIAG ARRIMADO %s] celda=%s espalda=%s fondo=%.2f px PNG='%s'" % [
		etiqueta, celda, espalda, semieje_fondo * 2.0, sprite.texture.resource_path.get_file(),
	])
	print("[DIAG ARRIMADO %s]   desvío aplicado=%s (esperado por cálculo=%s)" % [
		etiqueta, sprite.position, AnclajeSpriteScript.desvio_arrimado(sprite.texture, espalda),
	])
	print("[DIAG ARRIMADO %s]   ESPERADO línea de pared=%s | REAL borde trasero=%s" % [
		etiqueta, esperado, real,
	])
	print("[DIAG ARRIMADO %s]   DELTA=%s (|%.2f| px)  VEREDICTO: %s" % [
		etiqueta, delta, delta.length(), "PASA" if pasa else "FALLA",
	])
	_veredictos[etiqueta] = pasa
	return real


## ── EL TEST NUMÉRICO DE LA ESQUINA (dos paredes a la vez) ─────────────────────────────────────
## `_test_arrimado` compara el borde TRASERO (un semieje medido) contra la arista de UNA pared — no
## sirve para una pieza que toca DOS a la vez (no hay "un" borde trasero en una L, hay dos, que se
## juntan en el vértice — y `semiejes_base` está probado ROTO para esta silueta cóncava, ver el aviso
## de `Construccion.COMODIDAD_ESTANTERIA_ESQUINA`). Así que aquí el juez es distinto y más simple: el
## CENTRO de la base (medido, sin ajuste de fondo) tiene que caer sobre el VÉRTICE que comparten las
## dos aristas — dos ejes, mismo margen de 3 px.
func _test_arrimado_esquina(
	sprite: Sprite2D, origen: Vector2, celda: Vector2i, espalda_a: Vector2i, espalda_b: Vector2i,
	etiqueta: String
) -> Vector2:
	if sprite == null or sprite.texture == null:
		push_error("[DIAG ARRIMADO %s] SIN sprite -- test no aplicable" % etiqueta)
		_veredictos[etiqueta] = false
		return Vector2.INF
	# REAL: el centro de la base tal y como QUEDA dibujado -- sin correr ningún fondo, a propósito.
	var real: Vector2 = (
		sprite.global_position + sprite.offset + AnclajeSpriteScript.centro_base(sprite.texture)
	)
	# ESPERADO: el vértice de la celda que comparten las dos paredes (media celda en CADA dirección).
	var vertice_cuadrado: Vector2 = (
		ProyeccionScript.centro_cuadrado(celda)
		+ Vector2(espalda_a) * (TAM_CELDA * 0.5) + Vector2(espalda_b) * (TAM_CELDA * 0.5)
	)
	var esperado: Vector2 = origen + ProyeccionScript.proyectar(vertice_cuadrado)
	var delta: Vector2 = real - esperado
	var pasa: bool = absf(delta.x) <= TOLERANCIA_PX and absf(delta.y) <= TOLERANCIA_PX
	print("[DIAG ARRIMADO %s] celda=%s espaldas=%s+%s PNG='%s'" % [
		etiqueta, celda, espalda_a, espalda_b, sprite.texture.resource_path.get_file(),
	])
	print("[DIAG ARRIMADO %s]   desvío aplicado=%s (esperado por cálculo=%s)" % [
		etiqueta, sprite.position,
		AnclajeSpriteScript.desvio_arrimado_esquina(espalda_a, espalda_b),
	])
	print("[DIAG ARRIMADO %s]   ESPERADO vértice=%s | REAL centro de base=%s" % [
		etiqueta, esperado, real,
	])
	print("[DIAG ARRIMADO %s]   DELTA eje X=%.2f px | eje Y=%.2f px (|%.2f| px)  VEREDICTO: %s" % [
		etiqueta, delta.x, delta.y, delta.length(), "PASA" if pasa else "FALLA",
	])
	_veredictos[etiqueta] = pasa
	return real


## (A) Una estantería contra cada una de las cuatro paredes.
func _caso_cuatro_paredes() -> void:
	var piezas: Array = _montar(Vector2(4.5, 4.5), 2.6)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(2, 2, 5, 5))
	construccion.fijar_paredes_de_sala(sala, true)
	# Las DOS que alcanza la R hoy, por el CAMINO REAL DEL JUEGO (HORIZONTAL → norte, VERTICAL → oeste).
	var norte := Vector2i(4, 2)
	var oeste := Vector2i(2, 4)
	if construccion.construir_de_oficio_elemento(
		ESTANTERIA, norte, &"est_norte", construccion.HORIZONTAL
	) == &"":
		push_error("[DIAG ARRIMADO] estantería NORTE no colocada")
	if construccion.construir_de_oficio_elemento(
		ESTANTERIA, oeste, &"est_oeste", construccion.VERTICAL
	) == &"":
		push_error("[DIAG ARRIMADO] estantería OESTE no colocada")
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var capa: Node2D = construccion._capa_elementos
	var origen: Vector2 = capa.global_position
	# Las otras DOS paredes (este y sur) NO son alcanzables con la R de hoy (dos estados): se montan
	# a mano con la MISMA función que usa el juego, para que el test numérico las cubra igual.
	var este := Vector2i(6, 4)
	var sur := Vector2i(4, 6)
	_plantar_a_mano(construccion, capa, ESTANTERIA, este, ESPALDA_ESTE)
	_plantar_a_mano(construccion, capa, ESTANTERIA, sur, ESPALDA_SUR)
	_test_arrimado(_sprite_en_celda(capa, norte), origen, norte, ESPALDA_NORTE, "A-pared-norte")
	_test_arrimado(_sprite_en_celda(capa, este), origen, este, ESPALDA_ESTE, "A-pared-este")
	_test_arrimado(_sprite_en_celda(capa, sur), origen, sur, ESPALDA_SUR, "A-pared-sur")
	_test_arrimado(_sprite_en_celda(capa, oeste), origen, oeste, ESPALDA_OESTE, "A-pared-oeste")
	await _capturar_sin_liberar(sub, "estanterias_arrimadas_limpio")
	# La rejilla ENCIMA: amarillo = la celda de cada estantería; cian = la línea de pared contra la
	# que se mide (la arista trasera). Si el mueble no toca esa línea, se ve sin discutir.
	for par: Array in [
		[norte, ESPALDA_NORTE], [este, ESPALDA_ESTE], [sur, ESPALDA_SUR], [oeste, ESPALDA_OESTE],
	]:
		_marcar_celda(mundo, par[0], Color(1.0, 0.9, 0.1))
		_marcar_arista(mundo, par[0], par[1], Color(0.2, 0.9, 1.0))
	await _capturar(sub, "estanterias_arrimadas")


## (B) y (C) La ESQUINA con las dos pequeñas, y un tramo seguido de dos pequeñas en la misma pared.
func _caso_esquina() -> void:
	var piezas: Array = _montar(Vector2(4.0, 3.6), 4.0)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	var sala: StringName = construccion.construir_de_oficio_sala(&"sala_espera_doc", Rect2i(2, 2, 5, 5))
	construccion.fijar_paredes_de_sala(sala, true)
	# ESQUINA noroeste: el módulo del rincón pegado a la pared NORTE (0°) y el de debajo pegado a la
	# pared OESTE (270°) — las dos rotaciones que la R sí alcanza.
	var esq_norte := Vector2i(2, 2)
	var esq_oeste := Vector2i(2, 3)
	# TRAMO SEGUIDO: dos módulos en celdas contiguas de la MISMA pared norte.
	var tramo_a := Vector2i(4, 2)
	var tramo_b := Vector2i(5, 2)
	for par: Array in [
		[esq_norte, construccion.HORIZONTAL], [esq_oeste, construccion.VERTICAL],
		[tramo_a, construccion.HORIZONTAL], [tramo_b, construccion.HORIZONTAL],
	]:
		if construccion.construir_de_oficio_elemento(
			ESTANTERIA_PEQUENA, par[0], &"", par[1]
		) == &"":
			push_error("[DIAG ARRIMADO] estantería pequeña no colocada en %s" % par[0])
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var capa: Node2D = construccion._capa_elementos
	var origen: Vector2 = capa.global_position
	_test_arrimado(_sprite_en_celda(capa, esq_norte), origen, esq_norte, ESPALDA_NORTE, "B-esquina-norte")
	_test_arrimado(_sprite_en_celda(capa, esq_oeste), origen, esq_oeste, ESPALDA_OESTE, "B-esquina-oeste")
	_test_arrimado(_sprite_en_celda(capa, tramo_a), origen, tramo_a, ESPALDA_NORTE, "C-tramo-a")
	_test_arrimado(_sprite_en_celda(capa, tramo_b), origen, tramo_b, ESPALDA_NORTE, "C-tramo-b")
	# El HUECO entre módulos, medido en el plano cuadrado (px de celda): lo que la cuadrícula deja
	# entre dos piezas de 1 celda que no llenan su celda entera.
	_volcar_hueco(capa, esq_norte, esq_oeste, "B-esquina")
	_volcar_hueco(capa, tramo_a, tramo_b, "C-tramo")
	await _capturar_sin_liberar(sub, "estanterias_esquina_limpio")
	for celda: Vector2i in [esq_norte, esq_oeste, tramo_a, tramo_b]:
		_marcar_celda(mundo, celda, Color(1.0, 0.9, 0.1))
	_marcar_arista(mundo, esq_norte, ESPALDA_NORTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, esq_oeste, ESPALDA_OESTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, tramo_a, ESPALDA_NORTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, tramo_b, ESPALDA_NORTE, Color(0.2, 0.9, 1.0))
	await _capturar(sub, "estanterias_esquina")


## (D) ESQUINA COMPLETA — `estanteria_esquina` (OBJ_022 entero) en su propia sala, AL LADO de una
## réplica del montaje (B) (las dos sueltas) para que un solo fotograma enseñe el ANTES/DESPUÉS: el
## hueco de (B) contra el rincón cerrado de (D). Ver la cabecera del fichero.
func _caso_esquina_completa() -> void:
	var piezas: Array = _montar(Vector2(8.0, 4.5), 1.3)
	var sub: SubViewport = piezas[0]
	var mundo: Node2D = piezas[1]
	var construccion: Node = piezas[2]
	var paredes: Node = piezas[3]
	construccion.levantar_fachada()
	# Sala IZQUIERDA — réplica de (B): las dos sueltas, con su hueco.
	var sala_sueltas: StringName = construccion.construir_de_oficio_sala(
		&"sala_espera_doc", Rect2i(2, 2, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala_sueltas, true)
	var esq_norte := Vector2i(2, 2)
	var esq_oeste := Vector2i(2, 3)
	for par: Array in [[esq_norte, construccion.HORIZONTAL], [esq_oeste, construccion.VERTICAL]]:
		if construccion.construir_de_oficio_elemento(
			ESTANTERIA_PEQUENA, par[0], &"", par[1]
		) == &"":
			push_error("[DIAG ARRIMADO] estantería pequeña no colocada en %s" % par[0])
	# Sala DERECHA — la pieza NUEVA, de 2 celdas, plantada EN el rincón.
	var sala_esquina: StringName = construccion.construir_de_oficio_sala(
		&"sala_espera_doc", Rect2i(9, 2, 5, 5)
	)
	construccion.fijar_paredes_de_sala(sala_esquina, true)
	var esquina := Vector2i(9, 2)
	if construccion.construir_de_oficio_elemento(
		ESTANTERIA_ESQUINA, esquina, &"", construccion.HORIZONTAL
	) == &"":
		push_error("[DIAG ARRIMADO] estantería de esquina no colocada")
	paredes.configurar(construccion, TAM_CELDA, Vector2.ZERO)
	var capa: Node2D = construccion._capa_elementos
	var origen: Vector2 = capa.global_position
	# EL JUEZ: la pieza nueva toca las DOS paredes a la vez -- test de dos ejes contra el VÉRTICE.
	_test_arrimado_esquina(
		_sprite_en_celda(capa, esquina), origen, esquina, ESPALDA_NORTE, ESPALDA_OESTE,
		"D-esquina-completa"
	)
	# El HUECO que le queda a la pieza nueva contra su propio rincón (para compararlo con el de (B),
	# ya impreso arriba, "B-esquina" en `_caso_esquina`): cero celdas de separación, es UNA pieza.
	await _capturar_sin_liberar(sub, "estanteria_esquina_limpio")
	for celda: Vector2i in [esq_norte, esq_oeste, esquina]:
		_marcar_celda(mundo, celda, Color(1.0, 0.9, 0.1))
	_marcar_arista(mundo, esq_norte, ESPALDA_NORTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, esq_oeste, ESPALDA_OESTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, esquina, ESPALDA_NORTE, Color(0.2, 0.9, 1.0))
	_marcar_arista(mundo, esquina, ESPALDA_OESTE, Color(0.2, 0.9, 1.0))
	await _capturar(sub, "estanteria_esquina")


## El hueco ENTRE dos módulos: la distancia (en píxeles del plano cuadrado, o sea de celda) que
## separa las dos siluetas de base. No emite veredicto — es el número con el que el usuario decide si
## la esquina "encaja" o si hace falta arte específico de rincón.
func _volcar_hueco(capa: Node2D, celda_a: Vector2i, celda_b: Vector2i, etiqueta: String) -> void:
	var caja_a: Rect2 = _base_cuadrada(capa, celda_a)
	var caja_b: Rect2 = _base_cuadrada(capa, celda_b)
	if caja_a.size == Vector2.ZERO or caja_b.size == Vector2.ZERO:
		return
	# Separación por eje: 0 (o negativa) = se tocan o solapan en ese eje.
	var hueco_x: float = maxf(caja_b.position.x - caja_a.end.x, caja_a.position.x - caja_b.end.x)
	var hueco_y: float = maxf(caja_b.position.y - caja_a.end.y, caja_a.position.y - caja_b.end.y)
	print("[DIAG ARRIMADO %s] HUECO entre módulos: base A=%s base B=%s -> separación x=%.2f px, y=%.2f px (0 = se tocan)" % [
		etiqueta, caja_a, caja_b, hueco_x, hueco_y,
	])


## El rectángulo de suelo que pisa la pieza de una celda, en el plano lógico cuadrado.
func _base_cuadrada(capa: Node2D, celda: Vector2i) -> Rect2:
	var sprite: Sprite2D = _sprite_en_celda(capa, celda)
	if sprite == null or sprite.texture == null:
		return Rect2()
	var origen: Vector2 = capa.global_position
	var centro_pantalla: Vector2 = (
		sprite.global_position + sprite.offset + AnclajeSpriteScript.centro_base(sprite.texture)
	)
	var centro: Vector2 = ProyeccionScript.desproyectar(centro_pantalla - origen)
	var semiejes: Vector2 = AnclajeSpriteScript.semiejes_base(sprite.texture)
	return Rect2(centro - semiejes, semiejes * 2.0)


## Monta a mano la pieza de una comodidad arrimada a una pared cualquiera, con la misma función del
## juego (`_pieza_sprite_comodidad`) y colgándola donde la colgaría `_crear_pieza`. Solo para las
## dos paredes que la R de hoy no alcanza: sirve para que el test numérico cubra las cuatro.
##
## No puede reutilizar `_pieza_sprite_comodidad` tal cual: esa función solo sabe de los dos estados
## de la R (norte y oeste), que es justo lo que aquí se quiere saltar. Así que repite sus CUATRO
## líneas —cargar el PNG de la rotación que toca, anclar, arrimar— con la espalda pedida. Si esas
## cuatro líneas cambian en producción, este diagnóstico deja de reflejarlas: es desechable a
## propósito, y el camino de verdad ya está cubierto por las piezas norte y oeste.
func _plantar_a_mano(
	construccion: Node, capa: Node2D, id_catalogo: StringName, celda: Vector2i, espalda: Vector2i
) -> void:
	var datos: Dictionary = ConstruccionScript._sprites_comodidad()[id_catalogo]
	var rotacion: int = AnclajeSpriteScript.rotacion_para_espalda(datos["espalda_0"], espalda)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(construccion._ruta_sprite_comodidad(id_catalogo, rotacion))
	AnclajeSpriteScript.aplicar(sprite, Vector2i(1, 0), 1)
	sprite.position = AnclajeSpriteScript.desvio_arrimado(sprite.texture, espalda)
	var caja := Node2D.new()
	caja.name = "Caja"
	caja.add_child(sprite)
	var raiz := Node2D.new()
	raiz.position = ProyeccionScript.centro_iso(celda)
	raiz.add_child(caja)
	capa.add_child(raiz)


## El `Sprite2D` de la pieza que cuelga en una celda. Las piezas se identifican por su POSICIÓN (el
## nodo raíz de cada elemento se planta en el centro proyectado de su celda ancla).
func _sprite_en_celda(capa: Node2D, celda: Vector2i) -> Sprite2D:
	var objetivo: Vector2 = ProyeccionScript.centro_iso(celda)
	for hijo: Node in capa.get_children():
		if not (hijo is Node2D) or hijo is Label:
			continue
		if (hijo as Node2D).position.distance_to(objetivo) > 0.5:
			continue
		var sprite: Node = hijo.get_node_or_null("Caja/Sprite")
		if sprite is Sprite2D:
			return sprite as Sprite2D
	return null


## Un SubViewport montado como lo monta Main: fondo opaco + `ParedesSalas` ANTES que `Construccion`,
## los dos dentro de la bolsa de profundidad. Devuelve [sub, mundo, construccion, paredes, profundo].
func _montar(foco: Vector2, zoom: float) -> Array:
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
	var camara := Camera2D.new()
	camara.zoom = Vector2(zoom, zoom)
	camara.position = ProyeccionScript.proyectar(foco * float(TAM_CELDA))
	sub.add_child(camara)
	camara.make_current()
	var mundo := Node2D.new()
	sub.add_child(mundo)
	var profundo := Node2D.new()
	profundo.name = "MundoProfundo"
	profundo.y_sort_enabled = true
	mundo.add_child(profundo)
	var paredes := ParedesSalasScript.new()
	profundo.add_child(paredes)
	var construccion := ConstruccionScript.new()
	construccion.aplicar_config(ConfigConstruccionScript.new())
	mundo.add_child(construccion)
	construccion.montar_visual(TAM_CELDA, Vector2.ZERO, profundo)
	return [sub, mundo, construccion, paredes, profundo]


## El contorno de una celda, por encima de todo (z 10). Solo diagnóstico.
func _marcar_celda(mundo: Node2D, celda: Vector2i, color: Color) -> void:
	var borde := Line2D.new()
	borde.z_index = 10
	borde.width = 1.0
	borde.default_color = color
	borde.closed = true
	borde.points = PackedVector2Array([
		ProyeccionScript.esquina_iso(celda.x, celda.y),
		ProyeccionScript.esquina_iso(celda.x + 1, celda.y),
		ProyeccionScript.esquina_iso(celda.x + 1, celda.y + 1),
		ProyeccionScript.esquina_iso(celda.x, celda.y + 1),
	])
	mundo.add_child(borde)


## LA LÍNEA DE PARED contra la que se mide: la arista de la celda por la que el mueble da la espalda.
func _marcar_arista(mundo: Node2D, celda: Vector2i, espalda: Vector2i, color: Color) -> void:
	var desde := Vector2i.ZERO
	var hasta := Vector2i.ZERO
	match espalda:
		Vector2i(0, -1):   # norte
			desde = celda
			hasta = celda + Vector2i(1, 0)
		Vector2i(0, 1):    # sur
			desde = celda + Vector2i(0, 1)
			hasta = celda + Vector2i(1, 1)
		Vector2i(-1, 0):   # oeste
			desde = celda
			hasta = celda + Vector2i(0, 1)
		_:                 # este
			desde = celda + Vector2i(1, 0)
			hasta = celda + Vector2i(1, 1)
	var linea := Line2D.new()
	linea.z_index = 11
	linea.width = 2.0
	linea.default_color = color
	linea.points = PackedVector2Array([
		ProyeccionScript.esquina_iso(desde.x, desde.y),
		ProyeccionScript.esquina_iso(hasta.x, hasta.y),
	])
	mundo.add_child(linea)


func _capturar_sin_liberar(sub: SubViewport, nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%s%s.png" % [CARPETA_SALIDA, nombre]
	var err: Error = sub.get_texture().get_image().save_png(ruta)
	if err != OK:
		push_error("[DIAG ARRIMADO] save_png '%s' fallo (error %d)" % [ruta, err])
	else:
		print("[DIAG ARRIMADO] %s -> %s" % [nombre, ruta])


func _capturar(sub: SubViewport, nombre: String) -> void:
	await _capturar_sin_liberar(sub, nombre)
	sub.queue_free()
