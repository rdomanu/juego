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
## a cámara (sur y este) se dibujan a MEDIA altura y en una capa POR ENCIMA del mobiliario estático
## —así tapan la base de cualquier mueble arrimado a ellas, sofá incluido—; las traseras (norte y
## oeste) se quedan exactamente como estaban: altura completa, en su capa de siempre.
##
## El reparto en dos pasadas (`_fondo`/`_frente`, ambas instancias de `CapaParedes`) es puro DIBUJO:
## la geometría y el modelo los sigue leyendo y calculando ESTE fichero (`_recalcular_tramos`); las
## dos pasadas solo reciben ya el paquete de tramos/jambas que les toca y pintan. Ver
## `_cara_de_arista` (quién decide "cercana"/"frente") y `_repartir_en_capas` (quién los separa).
##
## ── FIX POSTERIOR — PARED TRASERA TAPADA POR EL MOBILIARIO (2026-08-03, misma fecha, otro bug) ──
## La frase de arriba ("las traseras... se quedan en su capa de siempre") describía un bug, no una
## garantía: esa "capa de siempre" (z_index 1, por ENCIMA del mobiliario) hacía que un sofá pegado a
## una pared NORTE/OESTE se dibujara por DEBAJO de ella (reporte de partida del usuario). La ALTURA
## de la pasada trasera NO cambia (sigue en `ALTO_PARED`, completa); lo que cambia es su CAPA:
## `Z_PAREDES_FONDO` baja a 0 (empate con el mobiliario, resuelto por orden en el árbol — ver ese
## const más abajo para el detalle completo). La pasada frontal no se toca — nunca tuvo este bug.

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
## PROPIA capa por encima de CUALQUIER pared (`Z_PAREDES_FRENTE` < capa de NPCs, ver más abajo), así
## que su altura no compite con la de un muñeco como sí competía antes.
const ALTO_PARED_FRENTE: float = ALTO_PARED / 2.0
## Largo de cada jamba (marco corto de puerta) — sobrio, sin arte elaborado (andamio hasta el art bible).
const LARGO_JAMBA: float = 10.0
## z_index de la pasada TRASERA (fondo — norte/oeste, altura completa). 🐛 FIX (2026-08-03, bug
## reportado en partida: "un sofá contra la pared NORTE se dibuja por DEBAJO de ella"). Hasta este
## fix valía 1 —igual que la pasada frontal, "quedan como están" heredado del único `ParedesSalas`
## de antes de partirse en dos— es decir, por ENCIMA del mobiliario estático de Construcción
## (`_capa_elementos`, z_index 0, sin fijar): una pared trasera con altura (`ALTO_PARED`, sube en
## pantalla hacia la cámara) dibujada ENCIMA de un mueble arrimado a su cara de dentro lo tapaba —
## exactamente el caso del sofá. Ese "quedan como están" era justo el bug, no una decisión correcta.
##
## Ahora vale 0: el MISMO z_index —sin fijar— que usa el mobiliario estático (`_capa_elementos`) y
## el suelo de las salas (`_capa_salas`, la tinta de color por servicio). Los tres EMPATAN a
## z_index 0, así que quién se dibuja encima de quién lo decide el ORDEN EN EL ÁRBOL, no un número
## distinto (regla verificada en `docs/engine-reference/godot/modules/isometrico-2d.md` §5: sin
## y-sort de por medio, el empate a mismo z_index se resuelve en orden de escena; "el y-sort JAMÁS
## hace que un z_index menor se dibuje delante de uno mayor" tampoco aplica aquí — no hay y-sort
## entre estas capas). `Main` añade el nodo `ParedesSalas` (y por tanto esta pasada, su hijo
## `ParedesFondo`) ANTES que `Construccion` en el árbol — ver el comentario en `main.gd` donde se
## crea `_paredes_salas` — así que `_capa_elementos` queda DESPUÉS y se dibuja ENCIMA de la pared
## trasera: el sofá delante de su pared, no detrás. `Construccion` no se toca (fuera del alcance de
## este fix): su capa de mobiliario se queda en el z_index 0 sin fijar que ya tenía.
##
## z_index de la pasada FRONTAL (frente — sur/este, media altura): sigue en 1, SIN CAMBIOS — ya
## estaba bien: por ENCIMA del mobiliario (0 < 1) y por DEBAJO de los NPCs (`NPCsFlujo`, z_index 2)
## y de las luces (`LucesObjetos`, z_index 3). Esta pasada no tenía ningún bug reportado ("la pasada
## frontal SÍ está bien por encima"). Antes de este fix, fondo y frente COMPARTÍAN el valor 1 (ver
## el historial de este fichero, "PAREDES FRONTALES BAJITAS"); ahora son dos valores DISTINTOS a
## propósito — el empate a 1 ya no le corresponde a la trasera.
##
## Escalera completa resultante (suelo < mobiliario < gente < luces, con las dos pasadas de pared
## intercaladas donde toca cada una): suelo (`Suelo` + `_capa_salas`, z 0, primeros en el árbol) <
## pared TRASERA (`ParedesFondo`, z 0, tree-order tras el suelo pero antes del mobiliario) <
## mobiliario estático (`_capa_elementos`, z 0, último del empate) < pared FRONTAL (`ParedesFrente`,
## z 1) < gente (`NPCsFlujo`, z 2) < luces (`LucesObjetos`, z 3).
const Z_PAREDES_FONDO: int = 0
const Z_PAREDES_FRENTE: int = 1
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

## El script de `CapaParedes` (dos instancias — fondo/frente, ver la cabecera). Preload por el mismo
## convenio que usa el resto del proyecto para clases con `class_name` (p. ej. `MesaAtencionScript`
## en `npcs_flujo.gd`): un `const …Script` en vez de depender del registro global del `class_name`.
const CapaParedesScript := preload("res://src/main/capa_paredes.gd")

var _construccion: Node = null
var _tam_celda: int = 40
var _desplazamiento: Vector2 = Vector2.ZERO
## Firma de lo último dibujado ("sala:rect:tipo:puerta" por sala, unidas): si no cambia entre dos
## llamadas a `actualizar()`, no se toca nada (ni cálculo ni reparto a las pasadas).
var _firma: String = ""
## Tramos de pared cacheados por `_recalcular_tramos()` — lista de trabajo COMBINADA (fondo+frente)
## que `_repartir_en_capas()` separa al final en los dos paquetes que de verdad se pintan. Este
## fichero NO dibuja nada directamente (sin `_draw()` propio): eso es cosa de `CapaParedes`.
var _tramos: Array[Dictionary] = []
## Jambas (el detalle de puerta) cacheadas igual que los tramos.
var _jambas: Array[Dictionary] = []
## Las dos pasadas de dibujo (instancias de `CapaParedes`), creadas una vez en `configurar()`.
## Tipadas como `Node2D` genérico (mismo convenio que `Main._paredes_salas` para un `…Script.new()`
## preloaded: la asignación estática no refina el tipo exacto de la subclase) — se castea a
## `CapaParedes` en el único sitio que necesita su API propia (`_repartir_en_capas`).
var _fondo: Node2D = null
var _frente: Node2D = null


## Engancha las referencias, crea las dos pasadas de dibujo y hace el primer cálculo. La comisaría
## inicial (`_montar_comisaria_inicial`) ya tiene salas construidas ANTES de que Main cablee el hook
## de layout (mismo caso ya documentado en `Main._actualizar_etiquetas_salas`), así que este primer
## `actualizar()` es necesario para que esas salas de arranque no se queden sin pared hasta la
## primera compra.
func configurar(construccion: Node, tam_celda: int, desplazamiento: Vector2) -> void:
	_construccion = construccion
	_tam_celda = tam_celda
	_desplazamiento = desplazamiento
	# DOS PASADAS (2026-08-03, "PAREDES FRONTALES BAJITAS" — ver la cabecera del fichero): antes
	# había un único `ParedesSalas._draw()` con z_index 1. Ahora ese dibujo lo hacen dos hijos
	# `CapaParedes`, cada uno con el z_index que le toca (ver `Z_PAREDES_FONDO`/`Z_PAREDES_FRENTE`).
	# `ParedesSalas` en sí ya no dibuja nada (queda en z_index 0, el de por defecto, que es
	# irrelevante porque no tiene contenido propio que pintar).
	var fondo := CapaParedesScript.new()
	fondo.name = "ParedesFondo"
	fondo.z_index = Z_PAREDES_FONDO
	add_child(fondo)
	_fondo = fondo
	var frente := CapaParedesScript.new()
	frente.name = "ParedesFrente"
	frente.z_index = Z_PAREDES_FRENTE
	# Añadida DESPUÉS de fondo (orden estable, sin necesidad real desde el fix de 2026-08-03: fondo y
	# frente ya NO comparten z_index —0 y 1— así que frente gana SIEMPRE por número, no por empate de
	# árbol; ver `Z_PAREDES_FONDO`/`Z_PAREDES_FRENTE` más arriba).
	add_child(frente)
	_frente = frente
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
	_repartir_en_capas()


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
		tramo.merge(_cara_de_arista(unidad["detras"], unidad["delante"]))
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
		var cara: Dictionary = _cara_de_arista(geo["detras"], geo["delante"], fija)
		if tipo == _construccion.PUERTA:
			_agregar_puerta_libre(
				geo["desde"], geo["hasta"], cara, COLOR_FACHADA if fija else COLOR_MURO_LIBRE
			)
		elif tipo == _construccion.VENTANA:
			# La ventana tambien SUBE (es pared), pero en color cristal translucido: se ve a traves,
			# no se pasa (fase E). Si esta recortada por la regla de la camara, queda la linea fina.
			#
			# ⚠️ EXCEPCIÓN a "media altura" (2026-08-03): una ventana en una arista FRONTAL se queda a
			# ALTURA COMPLETA, no a `ALTO_PARED_FRENTE` como el resto de esa pasada. Se decidió así (y
			# se deja constancia aquí, no en silencio) porque una ventana recortada a media altura no
			# se lee como ventana: es un cristal a ras de suelo, más parecido a un poyete que a un
			# hueco por el que se ve hacia fuera. "alto" se fija ANTES del merge con `cara` y
			# `Dictionary.merge` no pisa claves existentes por defecto, así que el valor de aquí
			# sobrevive; lo que SÍ toma de `cara` es "frente" (para que la ventana se reparta a la
			# pasada que le toca por capa, aunque su altura no sea la de esa pasada).
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
	# 5) ORDEN POR PROFUNDIDAD (ISOMÉTRICO, 2026-07-30). Todas las paredes salen de UN solo `_draw`,
	#    así que aquí el orden de la lista ES el orden de dibujo: lo que se pinta después, tapa. Se
	#    ordenan de FONDO a FRENTE por el punto más bajo de su base — sin esto, una pared del fondo
	#    calculada más tarde se pintaría encima de una que está delante de ella, y el dibujo se
	#    leería del revés. (`_tramos` se recalcula solo al cambiar el layout, nunca por frame, así
	#    que ordenar aquí no cuesta nada en partida.)
	_tramos.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return maxf(a["desde"].y, a["hasta"].y) < maxf(b["desde"].y, b["hasta"].y)
	)


## Separa `_tramos`/`_jambas` (la lista de trabajo combinada) en los dos paquetes que de verdad se
## pintan y se los entrega a cada pasada (2026-08-03, "PAREDES FRONTALES BAJITAS" — ver la cabecera
## del fichero). La clave "frente" de cada dict la puso `_cara_de_arista`/`_jamba`; se ORDENA primero
## (paso anterior) y se particiona DESPUÉS, así que el orden de fondo-a-frente sobrevive DENTRO de
## cada paquete — el reparto en dos nodos no puede romper el orden de profundidad que ya se calculó.
func _repartir_en_capas() -> void:
	var tramos_fondo: Array[Dictionary] = []
	var tramos_frente: Array[Dictionary] = []
	for tramo: Dictionary in _tramos:
		if tramo.get("frente", false):
			tramos_frente.append(tramo)
		else:
			tramos_fondo.append(tramo)
	var jambas_fondo: Array[Dictionary] = []
	var jambas_frente: Array[Dictionary] = []
	for jamba: Dictionary in _jambas:
		if jamba.get("frente", false):
			jambas_frente.append(jamba)
		else:
			jambas_fondo.append(jamba)
	(_fondo as CapaParedes).fijar(tramos_fondo, jambas_fondo)
	(_frente as CapaParedes).fijar(tramos_frente, jambas_frente)


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
			"delante": Vector2i(a, b),
		}
	if partes[0] == "h":
		# "h:col:row" — arista del eje X en la fila `b`, de la columna `a` a la `a + 1`.
		# (En pantalla baja hacia la DERECHA.)
		return {
			"desde": _esquina(a, b), "hasta": _esquina(a + 1, b),
			"detras": Vector2i(a, b - 1),
			"delante": Vector2i(a, b),
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
	# `cara["frente"]` ya lo puso `_cara_de_arista` — se reusa aquí para que las jambas de esta
	# puerta vayan a la MISMA pasada que sus dos tramos flanqueantes (arriba).
	var frente: bool = cara.get("frente", false)
	_jambas.append(_jamba(inicio_hueco, perpendicular, color, frente))
	_jambas.append(_jamba(fin_hueco, perpendicular, color, frente))


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
	# Mismo criterio que `_cara_de_arista`: "izquierda"/"arriba" son las aristas TRASERAS (oeste/
	# norte — pasada fondo); "derecha"/"abajo" dan a cámara (este/sur — pasada frente). Sin esto, la
	# puerta de una sala con pared frontal se repartiría siempre al fondo, sin importar en qué lado
	# esté de verdad.
	var frente: bool = info["lado"] == "derecha" or info["lado"] == "abajo"
	# ISOMÉTRICO: los puntos salen de `_esquina` y las direcciones "hacia dentro" pasan por
	# `_direccion` — en rombos, "hacia dentro" ya no es horizontal ni vertical en pantalla.
	if info["lado"] == "izquierda":
		var dentro: Vector2 = _direccion(Vector2(LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.position.x, puerta.y), dentro, color, frente),
			_jamba(_esquina(rect.position.x, puerta.y + 1), dentro, color, frente),
		]
	if info["lado"] == "derecha":
		var dentro: Vector2 = _direccion(Vector2(-LARGO_JAMBA, 0.0))
		return [
			_jamba(_esquina(rect.end.x, puerta.y), dentro, color, frente),
			_jamba(_esquina(rect.end.x, puerta.y + 1), dentro, color, frente),
		]
	if info["lado"] == "arriba":
		var dentro: Vector2 = _direccion(Vector2(0.0, LARGO_JAMBA))
		return [
			_jamba(_esquina(puerta.x, rect.position.y), dentro, color, frente),
			_jamba(_esquina(puerta.x + 1, rect.position.y), dentro, color, frente),
		]
	var dentro_abajo: Vector2 = _direccion(Vector2(0.0, -LARGO_JAMBA))   # "abajo"
	return [
		_jamba(_esquina(puerta.x, rect.end.y), dentro_abajo, color, frente),
		_jamba(_esquina(puerta.x + 1, rect.end.y), dentro_abajo, color, frente),
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
## "detras" y "delante" son las DOS celdas que la arista separa (norte y sur). Antes solo hacía
## falta la de detrás; "delante" la añade la enmienda del muro divisorio (2026-08-03) — ver
## `_cara_de_arista`, que necesita saber si hay sala a AMBOS lados.
func _unidad_h(fila_gridline: int, celda_x: int) -> Dictionary:
	return {
		"clave": "h:%d:%d" % [fila_gridline, celda_x],
		"desde": _esquina(celda_x, fila_gridline), "hasta": _esquina(celda_x + 1, fila_gridline),
		"detras": Vector2i(celda_x, fila_gridline - 1),
		"delante": Vector2i(celda_x, fila_gridline),
	}


## Un tramo del eje Y (grid-line en la columna `columna_gridline`, celda `celda_y`). En pantalla
## baja hacia la izquierda; en el modelo sigue siendo la arista "v" de siempre. Mismo par
## "detras"/"delante" que `_unidad_h`, aquí oeste y este.
func _unidad_v(columna_gridline: int, celda_y: int) -> Dictionary:
	return {
		"clave": "v:%d:%d" % [columna_gridline, celda_y],
		"desde": _esquina(columna_gridline, celda_y), "hasta": _esquina(columna_gridline, celda_y + 1),
		"detras": Vector2i(columna_gridline - 1, celda_y),
		"delante": Vector2i(columna_gridline, celda_y),
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
## 2. Cada arista ahora se etiqueta con `"frente": bool` (antes solo llevaba "alto") — es la clave
##    que usa `ParedesSalas._repartir_en_capas` para mandar la arista a la pasada `ParedesFrente`
##    (capa por ENCIMA del mobiliario estático, por DEBAJO de los NPCs) o a `ParedesFondo` (la pasada
##    de siempre, altura completa, sin tocar). Antes de esta enmienda solo existía UNA pasada, así
##    que "cercana"/"alta" únicamente cambiaba la ALTURA, nunca la capa — con la pared cercana a solo
##    10 px, no hacía falta más para no tapar al mobiliario, pero al subir la altura a media (para
##    tapar la base de un mueble alto) hacía falta separarla en su propia capa para que un NPC que
##    camina por delante de la sala se siga dibujando POR ENCIMA de ella, no por detrás.
##
## ── ENMIENDA 2026-08-03 (2ª) — EL MURO DIVISORIO ENTRE DOS SALAS ────────────────────────────────
## Bug con captura del usuario, medido en el motor (`tools/_diag_oclusion_murete.gd`, caso
## `b_divisorio`): *"los dispensadores de agua de Descanso, tras el muro divisorio con ODAC"*
## aparecían PARTIDOS EN DOS — el muro se pintaba justo por el medio de cada dispensador, pedestal
## debajo y garrafa encima.
##
## La causa es que esta función solo mira UN lado. Un muro compartido por DOS salas (ODAC al norte,
## Descanso al sur) tiene sala DETRÁS → se clasificaba "cercana" → pasada FRENTE, que vive en
## `Z_PAREDES_FRENTE` = 1, por ENCIMA de todo el mobiliario (z 0). Pero ese mismo muro es la pared
## de ATRÁS de la sala de abajo, y lo que ella tiene arrimado por dentro está DELANTE de él: al ir
## el muro en una capa superior, se pintaba encima de esos muebles y los cortaba por la mitad.
##
## La regla nueva: **si hay sala a los DOS lados, es un DIVISORIO** y se manda a la pasada FONDO
## (z 0, que va ANTES de `Construccion` en el árbol, así que el mobiliario se dibuja encima) pero
## CONSERVANDO la altura baja de `ALTO_PARED_FRENTE` — no sube a `ALTO_PARED` porque eso taparía el
## interior de la sala de arriba, que es justo lo que "PAREDES FRONTALES BAJITAS" vino a evitar.
##
## TRADE-OFF, escrito a propósito y no en silencio: en un divisorio ya no hay un único orden que
## sea correcto para las dos salas a la vez (con un z global, o tapa a una o tapa a la otra). Se
## elige que gane SIEMPRE el mobiliario, en las dos: es la misma regla ya ratificada hoy para las
## paredes traseras (el sofá se dibuja DELANTE de su pared norte, ver `Z_PAREDES_FONDO`), y el
## precio —la sala de arriba pierde el recorte de base contra ESA arista concreta, una franja de
## 17 px— es mucho menor que partir un mueble entero por la mitad. La solución sin trade-off es
## ordenar paredes y muebles por profundidad con y-sort: Fase 1 del borrador
## `docs/architecture/borrador-orden-profundidad-rotaciones.md`, fuera del alcance de este fix.
##
## Devuelve `{"alto": float, "frente": bool}` — listo para fundirse en el diccionario del tramo.
func _cara_de_arista(detras: Vector2i, delante: Vector2i, fija: bool = false) -> Dictionary:
	# La FACHADA del edificio (2026-07-30) se mide contra el EDIFICIO, no contra las salas: sus dos
	# lados del fondo (arriba e izquierda) tienen detrás la calle y van altos —son el telón de la
	# comisaría—, y los dos de delante tienen detrás el interior entero, así que van bajos. Sin esta
	# distinción, la fachada de abajo taparía la comisaría completa.
	var cercana: bool = (
		_celda_en_edificio(detras) if fija else _construccion.sala_en(detras) != &""
	)
	# La fachada NUNCA es divisorio: por fuera de ella no hay sala, es el borde del edificio.
	var divisorio: bool = (
		cercana and not fija and _construccion.sala_en(delante) != &""
	)
	return {
		"alto": ALTO_PARED_FRENTE if cercana else ALTO_PARED,
		"frente": cercana and not divisorio,
	}


## ¿Esa celda cae dentro de la rejilla del edificio? (espeja `Construccion._celda_en_edificio`,
## que es privada).
func _celda_en_edificio(celda: Vector2i) -> bool:
	return (
		celda.x >= 0 and celda.y >= 0
		and celda.x < _construccion.edificio_columnas and celda.y < _construccion.edificio_filas
	)


## Un tramo de jamba: `desde` + un desplazamiento hacia dentro de la sala. `frente` enruta la jamba
## a la pasada que toca (`_repartir_en_capas`) — mismo criterio que `_cara_de_arista`: TRUE si su
## arista da a cámara (sur/este), FALSE si es trasera (norte/oeste). El "grosor" viaja en el propio
## diccionario para que `CapaParedes` no necesite conocer `GROSOR_PARED` (esa constante es de
## MODELO/geometría, no de dibujo — vive aquí).
func _jamba(desde: Vector2, hacia_dentro: Vector2, color: Color, frente: bool = false) -> Dictionary:
	return {
		"desde": desde, "hasta": desde + hacia_dentro, "color": color, "frente": frente,
		"grosor": GROSOR_PARED,
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
