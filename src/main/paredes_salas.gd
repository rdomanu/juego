class_name ParedesSalas extends Node2D
## ParedesSalas — las salas se VEN como habitaciones, no como rectángulos de color en el suelo.
##
## Petición del usuario (2026-07-30): *"la sala de descanso tiene que ir con paredes, si no todo el
## mundo ve a los funcionarios descansando, es raro"* + *"el diseño de la comisaría como theme
## hospital"*. Fase VISUAL (el usuario eligió expresamente "que se vean primero"): dibuja el
## perímetro de cada sala con un hueco en la puerta, pero **NO bloquea el paso** — eso es una fase
## posterior aparte (colisión/navegación), que este nodo no toca.
##
## Solo LEE Construcción (rect + tipo + puerta de cada sala) y el catálogo de Datos para el color —
## nunca escribe en el modelo (ADR-0004: el visual refleja el modelo, jamás al revés).
##
## Rendimiento (regla del proyecto — cero redibujado por frame): sin `_process`. `actualizar()` la
## llama Main desde el hook de cambio de layout (`_al_cambiar_layout`, disparado por
## `Construccion._refrescar_visual` en cada construcción/demolición/movimiento/carga — nunca por
## frame) y compara una FIRMA de lo dibujado; si no cambió, ni se recalculan tramos ni se reparte
## nada a las dos pasadas. Mismo patrón DIFF que `npcs_flujo._firma` / `luces_objetos._firma`.
##
## ── PAREDES FRONTALES BAJITAS (2026-08-03) ──────────────────────────────────────────────────────
## Bug con captura del usuario: un sofá de 3 celdas pegado a la pared SUR de una sala se dibujaba
## sangrando POR ENCIMA de ella (la altura de esa pared no alcanzaba a cubrir el respaldo del sofá,
## así que el mueble parecía salirse del recinto). Decisión del usuario, la solución clásica del
## género (Theme Hospital / Two Point Hospital): las dos aristas de una sala cuyo lado EXTERIOR mira
## a cámara (sur y este) se dibujan a MEDIA altura —así tapan la base de cualquier mueble arrimado a
## ellas, sofá incluido— y las traseras (norte y oeste) se quedan a altura completa. Esa parte
## (`_cara_de_arista`, la regla "si detrás hay sala, es pared cercana y va baja") SIGUE VIGENTE.
##
## ── ORDEN POR PROFUNDIDAD, UN NODO POR TRAMO (2026-08-03, 3ª enmienda: el arreglo ESTRUCTURAL) ──
## Lo que se retira hoy es el REPARTO EN CAPAS. Hasta ahora estas paredes se pintaban en dos pasadas
## (`ParedesFondo` z 0 / `ParedesFrente` z 1), cada una un `_draw()` con TODOS sus tramos dentro: el
## orden contra el mobiliario lo decidía un z GLOBAL por pasada. Con eso, un muro DIVISORIO entre dos
## salas no tiene orden correcto posible —es la pared de delante de una sala y la de atrás de la
## otra— y el parche de ayer ("en un divisorio gana siempre el mobiliario, en las dos") lo rechazó el
## usuario con su caso real: una ventanilla pegada al divisorio Documentación/ODAC dibujaba el
## mostrador ENCIMA del muro que le debía tapar la base.
##
## Ahora cada tramo es un `TramoPared` propio (un `CanvasItem` por tramo) y todos viven en la BOLSA
## DE Y-SORT COMPARTIDA del juego (`Main` → "MundoProfundo"), junto con el mobiliario estático de
## Construcción (`_capa_elementos`) y los contenedores de las ventanillas (`NPCsFlujo`). El motor
## ordena la bolsa entera por la Y de pantalla de cada pieza (algoritmo del pintor): cada muro sale
## automáticamente DETRÁS de lo que tiene delante y DELANTE de lo que tiene detrás, sin elegir. El
## punto por el que se compara cada tramo es el CENTRO DE SU BASE (`_punto_de_orden`), que en esta
## proyección cae siempre entre el centro de la celda de detrás y el de la de delante — ver esa
## función para la cuenta. Fase 1 de `docs/architecture/borrador-orden-profundidad-rotaciones.md`.
##
## Este fichero sigue siendo el ÚNICO que lee el modelo y calcula geometría/alturas/colores; los
## `TramoPared` solo pintan lo que se les entrega (misma división de trabajo que había con
## `CapaParedes`, pero con un nodo por tramo en vez de dos nodos-pasada).

## Grosor de la línea de pared, en píxeles (encargo: "gruesa, 3-4 px"). Con el isométrico se usa
## para las jambas y como respaldo si algún tramo llegara sin altura.
const GROSOR_PARED: float = 4.0
## ── PAREDES CON ALTURA (ISOMÉTRICO, 2026-07-30) ────────────────────────────────────────────────
## Alto de la cara de una pared TRASERA (norte/oeste — "fondo"), en píxeles. 34 px: más alto que un
## muñeco (22 px) para que se lea como pared y no como bordillo, y menos que el alto del rombo (40)
## para que no ahogue el dibujo.
const ALTO_PARED: float = 34.0
## Alto de una pared FRONTAL (sur/este — "frente", da a cámara), en píxeles. MEDIA altura de
## `ALTO_PARED` (2026-08-03, "PAREDES FRONTALES BAJITAS" — ver la cabecera del fichero): lo bastante
## alta para tapar la base de un mueble arrimado a ella (el bug del sofá — con la antigua altura de
## 10 px el respaldo se salía por encima), y aun así claramente más baja que la trasera, que es la
## lectura que pide el género. No hace falta preocuparse por tapar a la gente: los NPCs van en su
## PROPIA capa (`NPCsFlujo`, z_index 2) por encima de CUALQUIER pared (todas viven en la bolsa de
## y-sort compartida, z 0), así que su altura no compite con la de un muñeco.
const ALTO_PARED_FRENTE: float = ALTO_PARED / 2.0
## Largo de cada jamba (marco corto de puerta) — sobrio, sin arte elaborado (andamio hasta el art bible).
const LARGO_JAMBA: float = 10.0
## ── LA ESCALERA DE CAPAS DEL JUEGO, TRAS EL PASO A Y-SORT (2026-08-03) ─────────────────────────
## Ya NO hay constantes de z para las paredes: todas viven en z_index 0, dentro de la bolsa de
## y-sort compartida ("MundoProfundo", ver `main.gd`), y su orden contra cada mueble lo decide la
## profundidad, tramo a tramo (ver `_punto_de_orden`). El z_index solo separa lo que NUNCA debe
## entrelazarse con esa bolsa:
##
##   rejilla del suelo (`Main/Suelo`, z −2)
##     < tinta de las salas (`Construccion/_capa_salas`, z −1)
##       < ▓ BOLSA DE Y-SORT, z 0 ▓  → paredes (`TramoPared`) + mobiliario (`_capa_elementos`)
##                                     + contenedores de ventanilla (`NPCsFlujo/Puestos`),
##                                     ordenados entre sí por su Y de base
##         < rótulos de sala/puesto (z 1-2: información, no la tapa un muro)
##           < gente (`NPCsFlujo`, z 2)
##             < luces (`LucesObjetos`, z 3)
## Mismo centinela que `Construccion.CELDA_NULA_PUERTA` (-1,-1), referenciado por VALOR: el proyecto
## tipa estas inyecciones como `Node` genérico (mismo criterio que `luces_objetos.gd` /
## `modo_construccion.gd`), así que no se tipa `_construccion` como `Construccion` para leer su
## constante directamente.
const CELDA_SIN_PUERTA := Vector2i(-1, -1)
## Color de los MUROS LIBRES (2026-07-30 — Fase A del modelo Prison Architect: paredes primero,
## zonas después). Gris de obra NEUTRO a propósito: a diferencia de `_color_de_pared`, un muro libre
## no pertenece a ninguna sala, así que no toma el tono de ningún servicio.
const COLOR_MURO_LIBRE := Color(0.55, 0.55, 0.52)
## Color de la FACHADA del edificio (2026-07-30): los muros fijos que son la comisaría en sí. Tono
## de LADRILLO, distinto del gris de obra de un tabique que has levantado tú — de un vistazo se
## distingue lo que es estructura (y no se puede tocar) de lo que has construido.
const COLOR_FACHADA := Color(0.62, 0.44, 0.36)
## Grosor de la línea de VENTANA (FASE D, 2026-07-30): más fina que `GROSOR_PARED` — se lee como
## cristal, no como pared maciza.
const GROSOR_VENTANA: float = 2.0
## Color de una VENTANA (tono claro/azulado, a propósito distinto del gris neutro del tabique — se
## lee como cristal: se ve a través pero NO se pasa, fase E).
const COLOR_VENTANA := Color(0.62, 0.80, 0.95, 0.85)
## Fracción de cada extremo del tramo que sigue pintándose como pared cuando es una PUERTA — el resto
## (el centro) queda como hueco. 0.25 dueño de cada lado deja un hueco del 50% de la celda, ancho de
## sobra para que se lea "por aquí se pasa".
const PROPORCION_STUB_PUERTA: float = 0.25

## El script de `TramoPared` (una instancia POR TRAMO, ver la cabecera). Preload por el mismo
## convenio que usa el resto del proyecto para clases con `class_name` (p. ej. `MesaAtencionScript`
## en `npcs_flujo.gd`): un `const …Script` en vez de depender del registro global del `class_name`.
const TramoParedScript := preload("res://src/main/tramo_pared.gd")

var _construccion: Node = null
var _tam_celda: int = 40
var _desplazamiento: Vector2 = Vector2.ZERO
## Firma de lo último dibujado ("sala:rect:tipo:puerta" por sala, unidas): si no cambia entre dos
## llamadas a `actualizar()`, no se toca nada (ni cálculo ni reparto a las pasadas).
var _firma: String = ""
## Tramos de pared cacheados por `_recalcular_tramos()` — la lista de trabajo que
## `_reconstruir_nodos()` convierte en un `TramoPared` por entrada. Este fichero NO dibuja nada
## directamente (sin `_draw()` propio): eso es cosa de `TramoPared`.
var _tramos: Array[Dictionary] = []
## Jambas (el detalle de puerta) cacheadas igual que los tramos — también se dibujan con un
## `TramoPared` cada una (sin altura: una línea de suelo).
var _jambas: Array[Dictionary] = []


## Engancha las referencias, activa el y-sort de este nodo y hace el primer cálculo. La comisaría
## inicial (`_montar_comisaria_inicial`) ya tiene salas construidas ANTES de que Main cablee el hook
## de layout (mismo caso ya documentado en `Main._actualizar_etiquetas_salas`), así que este primer
## `actualizar()` es necesario para que esas salas de arranque no se queden sin pared hasta la
## primera compra.
##
## ⚠️ `y_sort_enabled` AQUÍ es la mitad del mecanismo: la otra mitad es que `Main` cuelgue este nodo
## de "MundoProfundo" (que también lo tiene). Verificado en el motor 4.6 (sonda de esta sesión, con
## captura): cuando un nodo con y-sort cuelga de OTRO con y-sort, sus hijos **no** se ordenan como
## un bloque aparte — entran en la MISMA bolsa que los hermanos del padre. Por eso cada `TramoPared`
## compite pieza a pieza contra el mobiliario de Construcción sin que este fichero tenga que saber
## nada de él (ni al revés): cada sistema conserva la propiedad de sus nodos.
func configurar(construccion: Node, tam_celda: int, desplazamiento: Vector2) -> void:
	_construccion = construccion
	_tam_celda = tam_celda
	_desplazamiento = desplazamiento
	y_sort_enabled = true
	actualizar()


## Recalcula las paredes SOLO si el layout cambió de verdad (patrón DIFF de firma). Main lo llama
## desde `_al_cambiar_layout` — el mismo hook que ya usan el re-bake de navegación de los NPCs y las
## etiquetas de sala — nunca desde un `_process`.
func actualizar() -> void:
	if _construccion == null:
		return
	var firma: String = _firma_actual()
	if firma == _firma:
		return
	_firma = firma
	_recalcular_tramos()
	_reconstruir_nodos()


## Las salas construidas, en los TRES tipos válidos (mismo patrón que usa Main para "todas las
## salas": no existe un getter único en Construcción, así que se combinan los tres — const-006).
func _todas_las_salas() -> Array[StringName]:
	return (
		_construccion.salas_de_tipo("espera") + _construccion.salas_de_tipo("oficina")
		+ _construccion.salas_de_tipo("descanso")
	)


## Una línea por sala: rect + tipo (color) + puerta. Si ninguna cambió, la firma entera es idéntica.
func _firma_actual() -> String:
	var partes: PackedStringArray = PackedStringArray()
	for sala_id: StringName in _todas_las_salas():
		var rect: Rect2i = _construccion.rect_de_sala(sala_id)
		var puerta: Vector2i = _construccion.puerta_de_sala(sala_id)
		# El "P"/"-" final es si esa sala lleva paredes: las paredes son OPCIONALES por sala (decision
		# del usuario 2026-07-30), asi que ponerlas o quitarlas tiene que disparar un redibujado.
		partes.append("%s:%d,%d,%d,%d:%s:%d,%d:%s" % [
			sala_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			_construccion.tipo_de_sala(sala_id), puerta.x, puerta.y,
			"P" if _construccion.sala_con_paredes(sala_id) else "-",
		])
	# Los MUROS LIBRES (2026-07-30) entran en la firma: pintar o demoler uno tiene que disparar el
	# redibujado igual que construir/demoler una sala. Se ORDENAN antes de unir — `Construccion.muros()`
	# no promete un orden estable entre llamadas, y sin orden estable la firma podría "cambiar" (y
	# redibujar de más) aunque el CONJUNTO de muros sea idéntico al de la vez anterior.
	# FASE D (2026-07-30): el TIPO de cada muro (tabique/puerta/ventana) entra en la firma junto a su
	# clave — sin esto, convertir un tabique en puerta con `fijar_tipo_de_muro` no cambia el CONJUNTO
	# de claves (la arista sigue siendo la misma), así que la firma quedaría idéntica y el cambio
	# jamás se pintaría.
	var muros: Array[String] = _construccion.muros()
	muros.sort()
	var muros_con_tipo: PackedStringArray = PackedStringArray()
	for clave: String in muros:
		muros_con_tipo.append(clave + ":" + String(_construccion.tipo_muro_de_clave(clave)))
	partes.append("MUROS:" + ",".join(muros_con_tipo))
	return "|".join(partes)


## Reconstruye `_tramos` y `_jambas` desde cero leyendo el modelo. Es la parte "cara" (recorre el
## perímetro celda a celda de cada sala), pero solo corre cuando `actualizar()` ya detectó un cambio
## real — nunca por frame.
func _recalcular_tramos() -> void:
	_tramos.clear()
	_jambas.clear()
	# Solo las salas que TIENEN paredes (decision del usuario 2026-07-30): "hay a veces que no quiero
	# paredes y solo quiero delimitar las salas... no me importa que no tengan paredes documentacion y
	# odac ni tampoco la sala de espera pero si la de descanso". Delimitar una zona y AISLARLA son dos
	# cosas distintas: Documentacion, ODAC y las esperas se leen bien en planta diafana; la de descanso
	# se cierra porque su razon de ser es que no se vea a los funcionarios de cafe desde la cola.
	var salas: Array[StringName] = []
	for sala_id: StringName in _todas_las_salas():
		if _construccion.sala_con_paredes(sala_id):
			salas.append(sala_id)
	# 1) Las unidades de perímetro que son HUECO DE PUERTA, de TODAS las salas — con prioridad
	#    absoluta sobre cualquier pared: una puerta nunca queda tapiada, ni siquiera por la pared de
	#    la sala vecina si esa pared cae exactamente sobre el mismo tramo compartido.
	var huecos: Dictionary = {}
	for sala_id: StringName in salas:
		var clave: String = _clave_de_puerta(sala_id)
		if clave != "":
			huecos[clave] = true
	# 2) Cada sala aporta las unidades de SU perímetro (celda a celda), salvo las de hueco. La
	#    PRIMERA sala que reclama una unidad se la queda — así dos salas pegadas que comparten un
	#    tramo de pared lo pintan UNA sola vez (se evita el doble trazo en vez de solaparlo).
	var duenio: Dictionary = {}      # clave de unidad -> color de quien la reclamó primero
	var geometria: Dictionary = {}   # clave de unidad -> {"desde": Vector2, "hasta": Vector2}
	for sala_id: StringName in salas:
		var color: Color = _color_de_pared(sala_id)
		for unidad: Dictionary in _unidades_de_perimetro(sala_id):
			var clave: String = unidad["clave"]
			if huecos.has(clave) or duenio.has(clave):
				continue
			duenio[clave] = color
			geometria[clave] = unidad
	for clave: String in geometria:
		var unidad: Dictionary = geometria[clave]
		var tramo: Dictionary = {
			"desde": unidad["desde"], "hasta": unidad["hasta"], "color": duenio[clave],
		}
		tramo.merge(_cara_de_arista(unidad["detras"]))
		_tramos.append(tramo)
	# 3) Las jambas: un detalle sutil por cada puerta real (celda distinta de CELDA_SIN_PUERTA).
	for sala_id: StringName in salas:
		_jambas.append_array(_jambas_de_puerta(sala_id))
	# 4) Los MUROS LIBRES (2026-07-30 — Fase A: paredes primero, zonas después): mismo grosor y
	#    estilo que las paredes de sala, pero con su propio color neutro — no pertenecen a ninguna
	#    sala. Si un muro libre cae justo en el mismo tramo físico que ya pintó una pared de sala
	#    (`duenio`), NO se repinta encima — `Construccion.clave_de_muro` usa un convenio col:row para
	#    las aristas horizontales que NO coincide textualmente con el de este fichero (row:col,
	#    heredado de `_unidad_h`); `_clave_equivalente_en_paredes` traduce entre los dos para comparar
	#    la MISMA arista física. Los huecos de puerta NO se comprueban aquí a propósito: un muro libre
	#    es una entidad real del modelo (ADR-0004 — el visual refleja el modelo), así que si el
	#    jugador construye uno sobre el hueco de una puerta, SE VE (aunque sea una rareza jugable).
	for clave_construccion: String in _construccion.muros():
		if duenio.has(_clave_equivalente_en_paredes(clave_construccion)):
			continue
		var geo: Dictionary = _geometria_de_muro_libre(clave_construccion)
		if geo.is_empty():
			continue
		# FASE D (2026-07-30): puertas y ventanas se DIBUJAN distinto de un tabique — el visual
		# refleja el tipo del modelo (ADR-0004), no solo si hay o no arista.
		var tipo: StringName = _construccion.tipo_muro_de_clave(clave_construccion)
		var fija: bool = _construccion.es_muro_fijo(clave_construccion)
		var cara: Dictionary = _cara_de_arista(geo["detras"], fija)
		if tipo == _construccion.PUERTA:
			_agregar_puerta_libre(
				geo["desde"], geo["hasta"], cara, COLOR_FACHADA if fija else COLOR_MURO_LIBRE
			)
		elif tipo == _construccion.VENTANA:
			# La ventana tambien SUBE (es pared), pero en color cristal translucido: se ve a traves,
			# no se pasa (fase E). Si esta recortada por la regla de la camara, queda la linea fina.
			#
			# ⚠️ EXCEPCIÓN a "media altura" (2026-08-03): una ventana en una arista CERCANA se queda a
			# ALTURA COMPLETA, no a `ALTO_PARED_FRENTE` como el resto de las cercanas. Se decidió así (y
			# se deja constancia aquí, no en silencio) porque una ventana recortada a media altura no
			# se lee como ventana: es un cristal a ras de suelo, más parecido a un poyete que a un
			# hueco por el que se ve hacia fuera. "alto" se fija ANTES del merge con `cara` y
			# `Dictionary.merge` no pisa claves existentes por defecto, así que el valor de aquí
			# sobrevive intacto (hoy `cara` ya solo trae "alto", así que el merge no aporta nada más —
			# se conserva por simetría con los otros dos casos y para no callar la excepción).
			var ventana: Dictionary = {
				"desde": geo["desde"], "hasta": geo["hasta"],
				"color": COLOR_VENTANA, "grosor": GROSOR_VENTANA, "alto": ALTO_PARED,
			}
			ventana.merge(cara)
			_tramos.append(ventana)
		else:
			var libre: Dictionary = {
				"desde": geo["desde"], "hasta": geo["hasta"],
				"color": COLOR_FACHADA if fija else COLOR_MURO_LIBRE,
			}
			libre.merge(cara)
			_tramos.append(libre)
	# 5) EL PUNTO DE ORDEN de cada tramo (2026-08-03): la Y por la que el motor lo comparará contra
	#    los muebles. Se rellena aquí, de una vez, para TODOS los caminos de arriba (perímetro de
	#    sala, muro libre, ventana y los dos muñones de una puerta) — así ninguno se puede olvidar.
	for tramo: Dictionary in _tramos:
		tramo["orden"] = _punto_de_orden(tramo["desde"], tramo["hasta"])
	# 6) ORDEN EN EL ÁRBOL, de fondo a frente (ISOMÉTRICO, 2026-07-30). Desde el paso a y-sort esto
	#    YA NO decide el dibujo —lo decide la Y de cada `TramoPared`—, pero se conserva porque el
	#    y-sort no documenta cómo desempata dos piezas con la MISMA Y (dos aristas perpendiculares que
	#    se juntan en una esquina las tienen): dejar el árbol ya ordenado por profundidad hace que ese
	#    caso caiga siempre del lado correcto y que un volcado del árbol se lea igual que el dibujo.
	#    (`_tramos` se recalcula solo al cambiar el layout, nunca por frame, así que no cuesta nada.)
	_tramos.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (a["orden"] as Vector2).y < (b["orden"] as Vector2).y
	)


## Reconstruye los nodos de dibujo: un `TramoPared` por tramo y por jamba, hijos DIRECTOS de este
## nodo (que tiene y-sort, ver `configurar`), cada uno colocado en su punto de orden.
##
## Se rehace entero en vez de reciclar nodos a propósito: solo corre cuando la firma del layout
## cambió de verdad (`actualizar()`), es decir, en una construcción/demolición/carga — nunca por
## frame. Reciclar añadiría estado que mantener a cambio de nada medible.
##
## `free()` inmediato y no `queue_free()`: los nuevos tramos se añaden en la MISMA llamada, y con un
## borrado diferido convivirían un frame con los viejos (dos veces cada pared, con z-fighting visible
## al mover un muro). Mismo criterio que `Construccion._refrescar_visual` con su mobiliario.
func _reconstruir_nodos() -> void:
	for hijo: Node in get_children():
		hijo.free()
	for tramo: Dictionary in _tramos:
		_crear_nodo(tramo)
	for jamba: Dictionary in _jambas:
		_crear_nodo(jamba)


## Un `TramoPared` para una pieza ya calculada (tramo o jamba). El `add_child` va ANTES del `fijar`
## para que el `queue_redraw()` de dentro caiga sobre un nodo que ya está en el árbol.
func _crear_nodo(pieza: Dictionary) -> void:
	var nodo := TramoParedScript.new()
	add_child(nodo)
	nodo.fijar(pieza)


## Traduce una clave de `Construccion.muros()` (convenio "v:col:row" / "h:col:row") a la clave
## EQUIVALENTE de este fichero, para poder comparar contra `duenio` (que usa "v:col:row" para
## verticales — mismo orden, coincide — pero "h:row:col" para horizontales, heredado de `_unidad_h`/
## `_clave_de_puerta`). Solo se intercambian los dos números en el caso "h"; devuelve "" si la clave
## no tiene el formato esperado (nunca debería pasar — `Construccion` es la única que las genera).
func _clave_equivalente_en_paredes(clave_construccion: String) -> String:
	var partes: PackedStringArray = clave_construccion.split(":")
	if partes.size() != 3:
		return ""
	if partes[0] == "v":
		return clave_construccion   # mismo convenio col:row en los dos ficheros — no hace falta tocar
	return "h:%s:%s" % [partes[2], partes[1]]   # "h": Construccion guarda col:row; aquí es row:col


## La geometría (en píxeles de MUNDO) de una arista con la clave de `Construccion.muros()`
## ("v:col:row" o "h:col:row" — ver `Construccion.clave_de_muro`). `{}` si la clave es inválida.
func _geometria_de_muro_libre(clave: String) -> Dictionary:
	var partes: PackedStringArray = clave.split(":")
	if partes.size() != 3:
		return {}
	var a: int = int(partes[1])
	var b: int = int(partes[2])
	if partes[0] == "v":
		# "v:col:row" — arista del eje Y en la columna `a`, del borde de fila `b` al `b + 1`.
		# (En pantalla ya no es vertical: baja hacia la IZQUIERDA. El nombre "v" se conserva
		# porque es la clave del MODELO, que no sabe nada de proyecciones.)
		return {
			"desde": _esquina(a, b), "hasta": _esquina(a, b + 1),
			"detras": Vector2i(a - 1, b),
		}
	if partes[0] == "h":
		# "h:col:row" — arista del eje X en la fila `b`, de la columna `a` a la `a + 1`.
		# (En pantalla baja hacia la DERECHA.)
		return {
			"desde": _esquina(a, b), "hasta": _esquina(a + 1, b),
			"detras": Vector2i(a, b - 1),
		}
	return {}


## Dibuja el HUECO de una PUERTA en un muro libre (FASE D, 2026-07-30): dos tramos cortos de pared en
## los extremos del tramo —para que la arista siga leyéndose como el mismo tabique— dejando un hueco
## central por el que se pasa, más dos jambas cortas marcando el marco (mismo recurso `_jamba` que ya
## usan las puertas de sala). A diferencia de una puerta de sala, un muro libre no pertenece a
## ninguna habitación — no hay un "lado de dentro" que priorizar—, así que las dos jambas apuntan al
## MISMO lado (perpendicular al tabique): es un detalle decorativo, no una pista de navegación.
func _agregar_puerta_libre(
	desde: Vector2, hasta: Vector2, cara: Dictionary, color: Color = COLOR_MURO_LIBRE
) -> void:
	var direccion: Vector2 = hasta - desde
	var inicio_hueco: Vector2 = desde + direccion * PROPORCION_STUB_PUERTA
	var fin_hueco: Vector2 = hasta - direccion * PROPORCION_STUB_PUERTA
	var izq: Dictionary = {"desde": desde, "hasta": inicio_hueco, "color": color}
	izq.merge(cara)
	_tramos.append(izq)
	var der: Dictionary = {"desde": fin_hueco, "hasta": hasta, "color": color}
	der.merge(cara)
	_tramos.append(der)
	var perpendicular: Vector2 = direccion.normalized().rotated(PI / 2.0) * LARGO_JAMBA
	_jambas.append(_jamba(inicio_hueco, perpendicular, color))
	_jambas.append(_jamba(fin_hueco, perpendicular, color))


## Las unidades (una por celda) del perímetro de una sala: 4 lados, sin duplicar las esquinas — el
## mismo criterio de "en_borde" que usa `Construccion._puerta_automatica`.
func _unidades_de_perimetro(sala_id: StringName) -> Array[Dictionary]:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var unidades: Array[Dictionary] = []
	for x: int in range(rect.position.x, rect.end.x):
		unidades.append(_unidad_h(rect.position.y, x))
		unidades.append(_unidad_h(rect.end.y, x))
	for y: int in range(rect.position.y, rect.end.y):
		unidades.append(_unidad_v(rect.position.x, y))
		unidades.append(_unidad_v(rect.end.x, y))
	return unidades


## Info de la puerta de una sala (`{}` si no tiene una puerta válida en su perímetro). Determinismo
## en las ESQUINAS (una celda de esquina toca DOS lados a la vez, p. ej. `rect.position` toca el
## lado IZQUIERDO y el de ARRIBA): se prioriza IZQUIERDA > DERECHA > ARRIBA > ABAJO. Documentado
## aquí porque lo pide la tarea — al jugador le da igual (el hueco cae en la esquina de cualquier
## forma), pero el código necesita una única respuesta estable.
func _info_puerta(sala_id: StringName) -> Dictionary:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var puerta: Vector2i = _construccion.puerta_de_sala(sala_id)
	if puerta == CELDA_SIN_PUERTA:
		return {}
	if puerta.x == rect.position.x:
		return {"lado": "izquierda", "rect": rect, "puerta": puerta}
	if puerta.x == rect.end.x - 1:
		return {"lado": "derecha", "rect": rect, "puerta": puerta}
	if puerta.y == rect.position.y:
		return {"lado": "arriba", "rect": rect, "puerta": puerta}
	if puerta.y == rect.end.y - 1:
		return {"lado": "abajo", "rect": rect, "puerta": puerta}
	return {}   # la puerta no cae en el perímetro (dato corrupto) -> sin hueco ni jambas aquí


## La unidad de perímetro que ocupa la puerta de la sala (`""` si no tiene puerta válida).
func _clave_de_puerta(sala_id: StringName) -> String:
	var info: Dictionary = _info_puerta(sala_id)
	if info.is_empty():
		return ""
	var rect: Rect2i = info["rect"]
	var puerta: Vector2i = info["puerta"]
	match info["lado"]:
		"izquierda":
			return "v:%d:%d" % [rect.position.x, puerta.y]
		"derecha":
			return "v:%d:%d" % [rect.end.x, puerta.y]
		"arriba":
			return "h:%d:%d" % [rect.position.y, puerta.x]
		_:
			return "h:%d:%d" % [rect.end.y, puerta.x]   # "abajo"


## Dos jambas cortas a los dos lados del hueco de la puerta (marco sobrio, nada de arte elaborado —
## andamio declarado hasta que llegue el art bible), apuntando hacia DENTRO de la sala.
func _jambas_de_puerta(sala_id: StringName) -> Array[Dictionary]:
	var info: Dictionary = _info_puerta(sala_id)
	if info.is_empty():
		return []
	var rect: Rect2i = info["rect"]
	var puerta: Vector2i = info["puerta"]
	var color: Color = _color_de_pared(sala_id)
	# ISOMÉTRICO: los puntos salen de `_esquina` y las direcciones "hacia dentro" pasan por
	# `_direccion` — en rombos, "hacia dentro" ya no es horizontal ni vertical en pantalla.
	if info["lado"] == "izquierda":
		var dentro: Vector2 = _direccion(Vector2(LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.position.x, puerta.y), dentro, color),
			_jamba(_esquina(rect.position.x, puerta.y + 1), dentro, color),
		]
	if info["lado"] == "derecha":
		var dentro: Vector2 = _direccion(Vector2(-LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.end.x, puerta.y), dentro, color),
			_jamba(_esquina(rect.end.x, puerta.y + 1), dentro, color),
		]
	if info["lado"] == "arriba":
		var dentro: Vector2 = _direccion(Vector2(0.0, LARGO_JAMBA))
		return [
			_jamba(_esquina(puerta.x, rect.position.y), dentro, color),
			_jamba(_esquina(puerta.x + 1, rect.position.y), dentro, color),
		]
	var dentro_abajo: Vector2 = _direccion(Vector2(0.0, -LARGO_JAMBA))   # "abajo"
	return [
		_jamba(_esquina(puerta.x, rect.end.y), dentro_abajo, color),
		_jamba(_esquina(puerta.x + 1, rect.end.y), dentro_abajo, color),
	]


## Mismo cálculo que el privado `Construccion._color_de_sala` (color base por servicio + tono por
## tipo), DUPLICADO aquí a propósito: es privado (prefijo `_`) y esta tarea tiene prohibido tocar
## `construccion.gd`. No es una paleta nueva — es la MISMA, solo oscurecida para que la pared
## "pertenezca" a su sala. Si esa paleta cambia allí, hay que replicar el cambio aquí también.
func _color_de_pared(sala_id: StringName) -> Color:
	var tipo_sala: Resource = Datos.obtener(&"TipoSala", _construccion.tipo_de_sala(sala_id))
	if tipo_sala == null:
		return Color(0.1, 0.1, 0.1)   # no debería pasar (Datos ya avisó) — gris de emergencia
	var base := Color(0.30, 0.38, 0.55)
	if tipo_sala.servicio == "ODAC":
		base = Color(0.55, 0.40, 0.22)
	elif tipo_sala.servicio == "Comun":
		base = Color(0.35, 0.37, 0.40)
	if tipo_sala.tipo == "espera":
		base = base.lerp(Color(0.22, 0.24, 0.27), 0.45)
	return base.darkened(0.4)


## Un tramo del eje X (grid-line en la fila `fila_gridline`, celda `celda_x`). En pantalla baja
## hacia la derecha; en el modelo sigue siendo la arista "h" de siempre.
##
## "detras" es la celda del lado del FONDO (norte) — la que decide la altura de la cara
## (`_cara_de_arista`). La del lado de delante (sur) ya no hace falta guardarla: desde el paso a
## y-sort (2026-08-03) el orden contra el mobiliario de CADA lado lo decide la profundidad del
## tramo, no una clasificación previa que mirase las dos celdas.
func _unidad_h(fila_gridline: int, celda_x: int) -> Dictionary:
	return {
		"clave": "h:%d:%d" % [fila_gridline, celda_x],
		"desde": _esquina(celda_x, fila_gridline), "hasta": _esquina(celda_x + 1, fila_gridline),
		"detras": Vector2i(celda_x, fila_gridline - 1),
	}


## Un tramo del eje Y (grid-line en la columna `columna_gridline`, celda `celda_y`). En pantalla
## baja hacia la izquierda; en el modelo sigue siendo la arista "v" de siempre. Mismo "detras" que
## `_unidad_h`, aquí el lado oeste.
func _unidad_v(columna_gridline: int, celda_y: int) -> Dictionary:
	return {
		"clave": "v:%d:%d" % [columna_gridline, celda_y],
		"desde": _esquina(columna_gridline, celda_y), "hasta": _esquina(columna_gridline, celda_y + 1),
		"detras": Vector2i(columna_gridline - 1, celda_y),
	}


## ── LA REGLA DE LAS PAREDES QUE TAPAN (ISOMÉTRICO, 2026-07-30) ─────────────────────────────────
##
## El problema, en llano: una pared con altura sube hacia ARRIBA en pantalla, así que tapa lo que
## tiene DETRÁS (más al fondo). Las paredes del fondo de una sala tapan la calle, y eso está bien;
## pero las del lado de la cámara tapan el INTERIOR de la sala, y entonces no ves ni a tu gente ni
## tus mostradores: ves una fila de muros.
##
## Cómo lo resuelven Theme Hospital y Two Point: las paredes del lado cercano a la cámara se
## dibujan MUCHO MÁS BAJAS que las del fondo. Siguen ahí —marcan el recinto, y en las esquinas
## enlazan con las altas— pero como no llegan ni a la cintura de un muñeco, no tapan a nadie.
##
## La regla, sin excepciones: **si lo que hay DETRÁS de esta pared es una sala, es una pared
## CERCANA y va baja; si no, va a altura completa**. Sale sola de la geometría, sin marcar nada a
## mano: las dos paredes del fondo de una sala tienen detrás la calle (→ altas, hacen de fondo) y
## las dos del frente tienen detrás la propia sala (→ bajas, hacen de pretil). Un muro suelto en
## mitad de la nada tiene detrás suelo vacío, así que va alto, que es lo que se espera de un
## tabique aislado.
##
## ⚠️ Se probó ANTES a dibujar la pared cercana por su cara EXTERIOR (colgando hacia ABAJO en
## pantalla, imitando la perspectiva 3D de Two Point). El usuario lo cazó al momento —*"unas salen
## bien y otras como apuntando debajo del suelo, raro"*— y tenía razón: eso funciona con una cámara
## 3D de verdad, que ve el muro por encima, pero en 2D plano una cara que baja se lee como una
## solapa colgando, y encima descuadra las esquinas donde se junta con una pared que sube. Bajar
## la altura es la solución 2D, y es exactamente lo que hacía Theme Hospital.
##
## ── ENMIENDA 2026-08-03 — "PAREDES FRONTALES BAJITAS" (bug del sofá) ────────────────────────────
## Bajar la altura no bastaba: con solo 10 px, un mueble con silueta alta arrimado a la pared
## CERCANA (un sofá contra la pared SUR, captura del usuario) subía por ENCIMA de esa franja y se
## leía como si se saliera de la sala — "sangrando" hacia fuera. Dos cambios, los dos en este método:
##
## 1. La pared CERCANA sube a `ALTO_PARED_FRENTE` (media altura de la trasera) en vez de un simple
##    "bordillo" de 10 px: ahora sí tapa la base de un mueble arrimado a ella.
## 2. Esa pared pasó a dibujarse en una CAPA por encima del mobiliario (`ParedesFrente`, z 1), para
##    que de verdad recortase la base de lo que tuviera arrimado.
##
## ── ENMIENDA 2026-08-03 (2ª) — EL MURO DIVISORIO, Y POR QUÉ SE RETIRÓ EL REPARTO EN CAPAS ───────
## El punto 2 duró un día. Bug con captura del usuario, medido en el motor
## (`tools/_diag_oclusion_murete.gd`): un muro compartido por DOS salas se clasificaba "cercano"
## (tiene sala detrás) y subía a la capa de encima del mobiliario… pero ese MISMO muro es la pared de
## ATRÁS de la sala de abajo, y lo que ella tiene arrimado por dentro está DELANTE de él: el muro se
## dibujaba encima de esos muebles y los partía por la mitad (los dispensadores de Descanso).
##
## Se intentó primero mandar los divisorios a la capa de abajo ("que gane siempre el mobiliario, en
## las dos salas"). El usuario rechazó ese trade-off con su caso real: una ventanilla pegada al
## divisorio Documentación/ODAC dibujaba el mostrador ENCIMA del muro que le debía tapar la base.
## Tenía razón, y la conclusión es estructural: **con un z GLOBAL por capa no existe un orden
## correcto para los dos lados de un divisorio**. Elijas la capa que elijas, una de las dos salas se
## dibuja mal.
##
## Por eso hoy esta función ya NO clasifica capas: devuelve solo la ALTURA. Quién tapa a quién lo
## decide la PROFUNDIDAD, tramo a tramo, en la bolsa de y-sort compartida (ver la cabecera del
## fichero y `_punto_de_orden`) — y un divisorio sale, a la vez, delante del mobiliario de la sala de
## arriba y detrás del de la de abajo, que es justo lo que la escena pide.
##
## La regla de ALTURA no cambia ni una coma: **si lo que hay DETRÁS es sala (o interior del edificio,
## para la fachada), la pared es CERCANA y va a media altura; si no, altura completa**. Un divisorio
## tiene sala detrás → cercano → bajito, que es lo correcto: es la pared de delante de la sala de
## arriba y no debe tapar su interior.
##
## Devuelve `{"alto": float}` — listo para fundirse en el diccionario del tramo.
func _cara_de_arista(detras: Vector2i, fija: bool = false) -> Dictionary:
	# La FACHADA del edificio (2026-07-30) se mide contra el EDIFICIO, no contra las salas: sus dos
	# lados del fondo (arriba e izquierda) tienen detrás la calle y van altos —son el telón de la
	# comisaría—, y los dos de delante tienen detrás el interior entero, así que van bajos. Sin esta
	# distinción, la fachada de abajo taparía la comisaría completa.
	var cercana: bool = (
		_celda_en_edificio(detras) if fija else _construccion.sala_en(detras) != &""
	)
	return {"alto": ALTO_PARED_FRENTE if cercana else ALTO_PARED}


## EL PUNTO DE ORDEN de un tramo: por dónde lo compara el y-sort contra el mobiliario. Es el CENTRO
## de su base (la línea que toca el suelo), y esa elección no es arbitraria — es la que hace que el
## mecanismo funcione en los dos lados de un divisorio. La cuenta, con la proyección del proyecto
## (`Proyeccion`: `iso.y = (col + fila) · MEDIO_ALTO`, con `MEDIO_ALTO` = 20 px por celda):
##
##   · una arista horizontal en la línea de rejilla `F`, sobre la columna `C`, tiene sus extremos en
##     `y = (C + F)·20` y `y = (C + 1 + F)·20` → su centro cae en `(C + F + 0.5)·20`;
##   · el centro de la celda de DETRÁS (norte, `(C, F−1)`) cae en `(C + F)·20`;
##   · el centro de la celda de DELANTE (sur, `(C, F)`) cae en `(C + F + 1)·20`.
##
## El centro de la base queda SIEMPRE estrictamente entre los dos (y lo mismo, por simetría, para
## una arista vertical con sus celdas oeste/este). Traducido: el muro se dibuja DESPUÉS de lo que
## está en la celda de detrás (le tapa la base) y ANTES de lo que está en la de delante (queda
## detrás de ello). Las dos cosas a la vez, sin decidir nada — que es exactamente lo que un z global
## no podía dar.
func _punto_de_orden(desde: Vector2, hasta: Vector2) -> Vector2:
	return (desde + hasta) * 0.5


## ¿Esa celda cae dentro de la rejilla del edificio? (espeja `Construccion._celda_en_edificio`,
## que es privada).
func _celda_en_edificio(celda: Vector2i) -> bool:
	return (
		celda.x >= 0 and celda.y >= 0
		and celda.x < _construccion.edificio_columnas and celda.y < _construccion.edificio_filas
	)


## Un tramo de jamba: `desde` + un desplazamiento hacia dentro de la sala. El "grosor" viaja en el
## propio diccionario para que `TramoPared` no necesite conocer `GROSOR_PARED` (esa constante es de
## MODELO/geometría, no de dibujo — vive aquí).
##
## Su "orden" (la Y con la que compite en la bolsa de y-sort) es su PROPIO centro, no el de la arista
## de la que sale: una jamba es un trocito de marco apoyado en el suelo, medio paso hacia dentro de
## la sala, y ahí es donde de verdad está — así queda por delante de la pared del fondo con la que
## enlaza y por detrás de un mueble que esté más adentro, sin ningún caso especial.
func _jamba(desde: Vector2, hacia_dentro: Vector2, color: Color) -> Dictionary:
	var hasta: Vector2 = desde + hacia_dentro
	return {
		"desde": desde, "hasta": hasta, "color": color,
		"orden": _punto_de_orden(desde, hasta), "grosor": GROSOR_PARED,
	}


## El VÉRTICE de la rejilla en la intersección (columna, fila), en píxeles de PANTALLA.
##
## ISOMÉTRICO (2026-07-30): sustituye a las antiguas `_gx`/`_gy`, que devolvían una X y una Y por
## separado porque en vista cenital una línea de rejilla era una recta horizontal o vertical y
## bastaba con una coordenada. En rombos ya no: cada intersección es un punto de los dos ejes a la
## vez, y las paredes se dibujan en DIAGONAL siguiendo los lados del rombo.
func _esquina(columna: int, fila: int) -> Vector2:
	return _desplazamiento + Proyeccion.esquina_iso(columna, fila)


## Un vector de desplazamiento (no un punto) llevado del plano cuadrado a la pantalla. Se usa para
## las jambas, que apuntan "hacia dentro de la sala" — una dirección del PLANO, que en isométrico
## deja de ser horizontal o vertical en pantalla. Al ser la proyección lineal, se puede aplicar
## directamente al vector sin sumarle el origen.
func _direccion(en_plano: Vector2) -> Vector2:
	return Proyeccion.proyectar(en_plano)
