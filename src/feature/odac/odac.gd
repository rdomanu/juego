class_name ODAC extends Node
## ODAC / Denuncias #9 — el dueño de la POLÍTICA de la oficina de denuncias.
##
## Es la última pieza del MVP (GDD `design/gdd/odac.md`). Y es una pieza pequeña a propósito: casi
## toda la mecánica de ODAC ya vive donde le toca, y este sistema NO la duplica.
##
## ── QUÉ HACE CADA UNO (frontera, que es lo que más confunde de este sistema) ───────────────────
##
##  · **Flujo #4** ya ordena la cola por `(rango_prioridad, numero_turno)` (F7) y ya sabe
##    reconfigurar un puesto (`reconfigurar_puesto`, FL9). ODAC no reimplementa nada de eso.
##  · **Paciencia #10** ya pondera la satisfacción con `peso_prioridad_prioritaria` (2.5): una
##    VioGén bien atendida cuenta 2,5× y dejarla abandonar hunde la media 2,5×.
##  · **Datos** ya tiene las 14 denuncias con su `prioridad` ("Prioritaria" / "Normal").
##    (Eran 13 al escribir esto; el catálogo REAL de `datos/denuncias/` manda — corregido 2026-08-18.)
##
## Lo que faltaba —y es lo que hay aquí— es **la palanca de gestión del jugador**: los MODOS de
## reconfiguración (OD4/OD5). Flujo sabe aplicar "este puesto admite estas denuncias"; ODAC es quien
## decide QUÉ listas tienen sentido y les pone nombre.
##
## ── POR QUÉ LOS MODOS Y NO UNA LISTA SUELTA ───────────────────────────────────────────────────
## Sin modos, reconfigurar sería marcar 14 casillas por puesto. Con modos, el jugador toma la
## decisión que de verdad importa —*"este puesto se dedica a lo urgente y este otro despacha
## administrativo"*— de un clic. La lista de 14 casillas sigue estando (modo `SUBCONJUNTO`) para
## quien quiera afinar.
##
## ── LA VÁLVULA ANTI-INANICIÓN (OD5) ───────────────────────────────────────────────────────────
## Las Prioritarias se atienden SIEMPRE antes que las Normales, y en el MVP no hay envejecimiento de
## cola. Si llegan muchas urgencias seguidas, las administrativas podrían no atenderse nunca. La
## reconfiguración **es** la válvula: dedicar un puesto a `SOLO_NORMALES` garantiza que avancen.
## Por eso los modos no son un adorno de UI — son la solución a un problema real del modelo.
##
## Story: última pieza del MVP · GDD design/gdd/odac.md (OD3/OD4/OD5) · ADR-0001/0002

## El servicio que gobierna este sistema (el mismo nombre que usan Datos y Flujo).
const SERVICIO := &"ODAC"

## Los cuatro modos de un puesto ODAC (GDD, tabla de States and Transitions).
enum Modo {
	POLIVALENTE,      ## Todas las denuncias. El de arranque: sin especializar.
	SOLO_PRIORITARIAS,## VioGén, desaparecidos, agresión sexual, robo con violencia.
	SOLO_NORMALES,    ## Las administrativas. La válvula anti-inanición (OD5).
	SUBCONJUNTO,      ## Los tipos que elija el jugador, uno a uno.
}

## Nombres para la interfaz. Van aquí y no en la UI porque el modo es un concepto de ODAC: si un día
## se añade un quinto modo, se añade en un solo sitio.
const NOMBRES_MODO: Dictionary[int, String] = {
	Modo.POLIVALENTE: "Polivalente",
	Modo.SOLO_PRIORITARIAS: "Solo prioritarias",
	Modo.SOLO_NORMALES: "Solo normales",
	Modo.SUBCONJUNTO: "A medida",
}

## Explicación corta de cada modo, para que el jugador entienda la CONSECUENCIA y no solo el nombre.
const AYUDA_MODO: Dictionary[int, String] = {
	Modo.POLIVALENTE: "Atiende todo. Las urgentes pasan primero.",
	Modo.SOLO_PRIORITARIAS: "Solo VioGén, desaparecidos, agresiones y atracos.",
	Modo.SOLO_NORMALES: "Solo administrativas. Evita que se queden sin atender.",
	Modo.SUBCONJUNTO: "Los tipos que elijas.",
}

## Emitida al cambiar el modo de un puesto, para que la UI se refresque sin sondear.
signal modo_cambiado(puesto_id: StringName, modo: int)

var _flujo: Node = null
## Puesto → modo elegido. Lo que NO está aquí es POLIVALENTE (el default): así un save de una
## partida sin tocar nada no arrastra una lista de modos redundante.
var _modo_de: Dictionary[StringName, int] = {}
## Puesto → tipos elegidos a mano, solo para el modo SUBCONJUNTO.
var _subconjunto_de: Dictionary[StringName, Array] = {}


func _ready() -> void:
	add_to_group("Persist")   # ADR-0002: el SaveManager recolecta por este grupo


## Inyección de dependencias (la llama Main antes de usarlo). ODAC **ordena** por la API pública de
## Flujo y nunca toca su estado interno.
func usar_flujo(flujo: Node) -> void:
	_flujo = flujo


# ── El catálogo de denuncias (se lee de Datos; ODAC no inventa tipos — OD1) ───────────────────

## Todas las denuncias del catálogo, en orden estable por id. Orden estable = dos partidas idénticas
## producen la misma lista y la misma UI.
func denuncias() -> Array[StringName]:
	var lista: Array[StringName] = []
	for recurso: Resource in Datos.obtener_todos(&"DenunciaODAC"):
		lista.append(recurso.id)
	lista.sort()
	return lista


## ¿Es una denuncia de las urgentes? El catálogo manda (OD1): ODAC no mantiene su propia lista de
## cuáles son prioritarias, porque entonces habría dos verdades y una se quedaría vieja.
func es_prioritaria(id_denuncia: StringName) -> bool:
	var d: Resource = Datos.obtener_silencioso(&"DenunciaODAC", id_denuncia)
	return d != null and d.prioridad == "Prioritaria"


## Las denuncias de un modo. Es la traducción de "qué quiere el jugador" a "qué entiende Flujo".
func atenciones_de_modo(modo: int, subconjunto: Array[StringName] = []) -> Array[StringName]:
	match modo:
		Modo.SOLO_PRIORITARIAS:
			return denuncias().filter(func(d: StringName) -> bool: return es_prioritaria(d))
		Modo.SOLO_NORMALES:
			return denuncias().filter(func(d: StringName) -> bool: return not es_prioritaria(d))
		Modo.SUBCONJUNTO:
			# Se filtra contra el catálogo: un save manipulado no puede colar tipos inventados.
			var validos: Array[StringName] = []
			for d: StringName in subconjunto:
				if Datos.obtener_silencioso(&"DenunciaODAC", d) != null:
					validos.append(d)
			validos.sort()
			return validos
		_:
			# POLIVALENTE: lista VACÍA a propósito. Para Flujo, vacío significa "sin override, usa el
			# catálogo del puesto" — que es exactamente lo que es ser polivalente. Mandar los 13 tipos
			# haría lo mismo pero dejaría un override que habría que mantener si el catálogo crece.
			return []


# ── La palanca del jugador (OD4) ─────────────────────────────────────────────────────────────

## Pone un puesto ODAC en un modo. Devuelve si se aplicó.
##
## No interrumpe la atención en curso (FL9): afecta a la PRÓXIMA llamada. Es lo correcto y además es
## lo que el GDD exige — a nadie se le corta la denuncia a medias porque el comisario reorganice.
## Se permite en Pausa (OD10), porque es gestión y la gestión no consume tiempo de juego.
func fijar_modo(
	puesto_id: StringName, modo: int, subconjunto: Array[StringName] = []
) -> bool:
	if _flujo == null:
		push_warning("ODAC: fijar modo SIN Flujo inyectado -> ignorado")
		return false
	if not NOMBRES_MODO.has(modo):
		push_warning("ODAC: modo desconocido (%d) -> ignorado" % modo)
		return false
	var atenciones: Array[StringName] = atenciones_de_modo(modo, subconjunto)
	# ⚠️ Un modo que no deja NINGUNA denuncia atendible convertiría el puesto en un mueble: se
	# rechaza. (Pasa si eliges "a medida" y no marcas nada.) Cerrar un puesto es otra cosa y tiene
	# su propia orden en Flujo — esto es reconfigurar, no cerrar.
	if modo == Modo.SUBCONJUNTO and atenciones.is_empty():
		return false
	if not _flujo.reconfigurar_puesto(puesto_id, atenciones):
		return false
	if modo == Modo.POLIVALENTE:
		_modo_de.erase(puesto_id)          # el default no se guarda
		_subconjunto_de.erase(puesto_id)
	else:
		_modo_de[puesto_id] = modo
		if modo == Modo.SUBCONJUNTO:
			_subconjunto_de[puesto_id] = atenciones
		else:
			_subconjunto_de.erase(puesto_id)
	modo_cambiado.emit(puesto_id, modo)
	return true


## En qué modo está un puesto (POLIVALENTE si nunca se tocó).
func modo_de(puesto_id: StringName) -> int:
	return _modo_de.get(puesto_id, Modo.POLIVALENTE)


## Los tipos elegidos a mano de un puesto (vacío si no está en modo SUBCONJUNTO).
func subconjunto_de(puesto_id: StringName) -> Array[StringName]:
	var guardado: Array = _subconjunto_de.get(puesto_id, [])
	var salida: Array[StringName] = []
	for d: Variant in guardado:
		salida.append(StringName(d))
	return salida


## Los puestos de ODAC que existen ahora mismo, en orden estable. Se pregunta a Flujo (que es quien
## lleva el registro) en vez de mantener una lista propia que se quedaría vieja al construir o
## demoler una ventanilla.
func puestos() -> Array[StringName]:
	if _flujo == null:
		return []
	var lista: Array[StringName] = []
	for puesto_id: StringName in _flujo.puestos_registrados():
		var tipo: Resource = Datos.obtener_silencioso(
			&"TipoPuesto", _flujo.tipo_de_puesto_flujo(puesto_id)
		)
		if tipo != null and tipo.servicio == String(SERVICIO):
			lista.append(puesto_id)
	return lista


# ── Diagnóstico para la UI: ¿me estoy dejando denuncias sin atender? (OD5) ────────────────────

## Las denuncias que **ningún puesto abierto puede atender** ahora mismo. Es la alarma de la válvula
## anti-inanición: si el jugador pone todos los puestos en "solo prioritarias", las administrativas
## se quedan en la cola para siempre y nada se lo diría.
##
## Devuelve la lista vacía cuando todo está cubierto, que es el caso normal.
func denuncias_sin_cubrir() -> Array[StringName]:
	var cubiertas: Dictionary[StringName, bool] = {}
	for puesto_id: StringName in puestos():
		for d: StringName in _atenciones_efectivas(puesto_id):
			cubiertas[d] = true
	var huerfanas: Array[StringName] = []
	for d: StringName in denuncias():
		if not cubiertas.has(d):
			huerfanas.append(d)
	return huerfanas


## Lo que ese puesto admite DE VERDAD: su modo si lo tiene, o el catálogo de su tipo si es
## polivalente. (Es la misma cuenta que hace Flujo al emparejar; aquí se replica solo para el
## diagnóstico, sin tocar su estado.)
func _atenciones_efectivas(puesto_id: StringName) -> Array[StringName]:
	var modo: int = modo_de(puesto_id)
	if modo != Modo.POLIVALENTE:
		return atenciones_de_modo(modo, subconjunto_de(puesto_id))
	var tipo: Resource = Datos.obtener_silencioso(
		&"TipoPuesto", _flujo.tipo_de_puesto_flujo(puesto_id)
	)
	if tipo == null:
		return []
	var salida: Array[StringName] = []
	for d: Variant in tipo.atenciones_admitidas:
		salida.append(StringName(d))
	return salida


# ── Persistencia (ADR-0002 · grupo "Persist") ────────────────────────────────────────────────

## Se guardan **las decisiones del jugador** y nada más: qué modo puso en cada puesto. Lo demás
## (qué denuncias son prioritarias, cuáles existen) sale del catálogo al cargar, así que reequilibrar
## el juego no deja partidas viejas con una copia congelada.
func save() -> Dictionary:
	var modos: Array = []
	var ids: Array[StringName] = _modo_de.keys()
	ids.sort()   # orden estable: dos saves del mismo estado deben ser idénticos byte a byte
	for puesto_id: StringName in ids:
		var sub: Array[String] = []
		for d: StringName in subconjunto_de(puesto_id):
			sub.append(String(d))
		modos.append({
			"puesto": String(puesto_id), "modo": int(_modo_de[puesto_id]), "tipos": sub,
		})
	return {"modos": modos}


## Restaura los modos. **Se vuelven a aplicar a Flujo**, no solo se anotan: al cargar, Flujo arranca
## con todos los puestos polivalentes, así que si aquí solo se guardara el número, la partida cargada
## se vería con "solo prioritarias" en el panel mientras el puesto atendía de todo.
func load_state(datos: Dictionary) -> void:
	_modo_de.clear()
	_subconjunto_de.clear()
	for entrada: Variant in datos.get("modos", []):
		if not (entrada is Dictionary):
			push_warning("ODAC: entrada de modo corrupta en el save -> descartada")
			continue
		var puesto_id := StringName(String(entrada.get("puesto", "")))
		var modo: int = int(entrada.get("modo", Modo.POLIVALENTE))
		if puesto_id == &"" or not NOMBRES_MODO.has(modo):
			push_warning("ODAC: modo invalido en el save ('%s') -> descartado" % puesto_id)
			continue
		var tipos: Array[StringName] = []
		for d: Variant in entrada.get("tipos", []):
			tipos.append(StringName(String(d)))
		fijar_modo(puesto_id, modo, tipos)
