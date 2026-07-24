class_name Personal extends Node
## Personal — la plantilla de la comisaría (sistema Core; NODO del mundo, NO autoload — arq. §3.4).
##
## Story 001 del epic: la instancia `Agente` (agente.gd) + las FÓRMULAS con knobs (F1 salario efectivo ·
## F2 Rapidez→duración · F3 Trato→satisfacción · F4 Salud→ausencia) y la config data-driven
## (`ConfigPersonal`).
## Story 002: el MERCADO de fichajes (F5 — candidatos sembrados con sesgo al centro, vía RNGService),
## contratar con gate de caja de Economía (E4, sin coste puntual — Open Q4) y despedir (gratis, MVP).
## Story 003: la ASIGNACIÓN a puestos (PA5; puestos ABSTRACTOS registrados por el mundo — Construcción
## registrará los reales con la misma API), máx. 1 Oficial por servicio (PA2) y el GATE FL4 que
## consumirá Flujo (`puesto_dotado` + modificadores por puesto).
## Story 004: las AUSENCIAS del día (PA7/PA11, F4) — tirada diaria al `nuevo_dia` (prioridad 30 del
## dispatcher: la nómina de Economía, prio 20, se cobra ANTES → baja pagada), titularidad conservada
## y aviso por el bus (`incidencia_personal`).
## Story 005: el OFICIAL (PA8/PA9, F6/F7) — cobertura automática de bajas con agentes LIBRES (MVP
## ratificado: no mueve titulares de otros puestos), presupuesto diario `ceil(Mando/2)` por servicio
## (⚠️ errata del GDD anotada: el texto de F6 dice floor, pero su tabla de salida y AC-PE14 son ceil)
## y canalización: con Oficial PRESENTE las incidencias del servicio salen en UN parte agrupado
## (`parte_personal`); sin él, avisos individuales (`incidencia_personal`).
##
## Provee (cuando el epic avance) el gate FL4 y los modificadores que consumirá Flujo; el dinero lo
## posee Economía (esta clase solo CALCULA salarios — cobrarlos es de Economía, prio 20 del nuevo_dia).
##
## Story: production/epics/personal/story-001-agente-y-formulas.md · TR-staff-001 · ADR-0003/0002

## Ruta del config de tuning (generado por tools/build_config_personal.gd; fallback a defaults).
const RUTA_CONFIG := "res://datos/config/personal.tres"
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
## La instancia de agente (preload por RUTA — gotcha del headless en frío).
const AgenteScript := preload("res://src/core/personal/agente.gd")

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var k_calidad: float = 0.5
var prima_rango_oficial: float = 1.3
var k_rapidez: float = 0.1
var k_motivacion_rapidez: float = 0.05
var k_trato: float = 0.25
var k_motivacion_trato: float = 0.1
var base_ausencia: float = 0.03
var k_salud: float = 0.02
var coste_despido: float = 0.0
var n_candidatos: int = 4
var refresco_mercado_jornadas: int = 3
var prob_candidato_oficial: float = 0.2
var pool_nombres: Array[String] = []

## La plantilla contratada (instancias Agente). La puebla el mercado (002) o el arranque del mundo (007).
var plantilla: Array[RefCounted] = []

# ── Mercado de fichajes (Story 002 · TR-staff-001 · GDD PA4/PA6, F5) ─────────────────────────
## Candidatos en oferta (instancias Agente SIN contratar). Se genera bajo demanda (`generar_mercado`)
## y se regenera completo por calendario; contratar solo retira al contratado (decisión de la story).
var mercado: Array[RefCounted] = []
## Jornadas transcurridas desde la última regeneración completa (F5).
var _jornadas_desde_refresco: int = 0
## Economía inyectada (gate E4 de contratación). En runtime la enchufa Main; los tests, una instancia real.
var _economia: Node = null
## EventBus inyectable (patrón Demanda; auto-resuelto en _ready): emite `incidencia_personal` y
## registra el hueco 30 del `nuevo_dia`. Sin bus (tests unitarios), las ausencias corren sin avisar.
var _bus: Node = null

## Tipos contratables del MVP (los 2 perfiles operativos del catálogo; `ag_seguridad` queda fuera del
## mercado — el vigilante llegará con su sistema).
const TIPOS_MERCADO: Array[StringName] = [&"ag_doc", &"ag_odac"]


func _ready() -> void:
	_cargar_config()
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	# Ausencias del día por el DISPATCHER (orden crítico ADR-0001, `nuevo_dia`: Paciencia 10 →
	# Economía 20 → **Personal 30** → Demanda 40). Solo en runtime real (árbol); los tests llaman
	# `_al_nuevo_dia` directo (patrón del proyecto).
	if _bus != null and _bus.has_method("registrar_ordenado"):
		_bus.registrar_ordenado(&"nuevo_dia", 30, _al_nuevo_dia)


## Inyecta Economía (dependency injection → testeable). Sin ella, contratar avisa y no aplica gate.
func usar_economia(economia: Node) -> void:
	_economia = economia


## Inyecta el EventBus (dependency injection → testeable sin el autoload real).
func usar_bus(bus: Node) -> void:
	_bus = bus


# ── F1 · Salario diario efectivo (base × prima de calidad × prima de rango) ──────────────────

## F1: `salario_base(tipo) × (1 + k_calidad × (media_atributos − 3)/2) × prima_rango`. El salario BASE
## vive en el catálogo (`TipoAgente.salario_dia_eur` — Datos); las primas son knobs. Mejor = más caro.
## Tipo inexistente en el catálogo → 0 con aviso (Datos ya avisa; el agente corrupto no cobra).
func salario_dia(agente: RefCounted) -> float:
	var tipo: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	if tipo == null:
		return 0.0
	var prima_calidad: float = 1.0 + k_calidad * (agente.media_atributos() - 3.0) / 2.0
	var prima_rango: float = prima_rango_oficial if agente.rango == AgenteScript.RANGO_OFICIAL else 1.0
	return float(tipo.salario_dia_eur) * prima_calidad * prima_rango


# ── F2 · Modificador de producción (Rapidez → duración efectiva; lo consumirá Flujo F1) ──────

## F2: `clamp((1 − k_rapidez×(R−3)) × (1 − k_mot_rap×(M−3)), 0.5, 1.3)`. Menor = más rápido. El rango
## extendido [0.5, 1.3] es la decisión 2026-07-21: un mal fichaje rinde PEOR que el estándar (>1.0).
func modificador_produccion(agente: RefCounted) -> float:
	var por_rapidez: float = 1.0 - k_rapidez * float(agente.rapidez - 3)
	var por_motivacion: float = 1.0 - k_motivacion_rapidez * float(agente.motivacion - 3)
	return clampf(por_rapidez * por_motivacion, 0.5, 1.3)


# ── F3 · Factor de trato (Trato → multiplicador de satisfacción; lo consumirá Paciencia F2) ──

## F3: `clamp(1 + k_trato×(T−3) × (1 + k_mot_trato×(M−3)), 0.5, 1.5)`. Trato 3 = 1.0 NEUTRO con
## cualquier Motivación (la modulación multiplica el desvío, no la base) — reconciliación 2026-07-22
## con Paciencia: esto es un MULTIPLICADOR de `puntuacion_visita`, no puntos aditivos.
func factor_trato(agente: RefCounted) -> float:
	var desvio: float = k_trato * float(agente.trato - 3)
	var por_motivacion: float = 1.0 + k_motivacion_trato * float(agente.motivacion - 3)
	return clampf(1.0 + desvio * por_motivacion, 0.5, 1.5)


# ── F4 · Probabilidad de ausencia diaria (Salud; la tirada real es de la story 004) ──────────

## F4: `clamp(base_ausencia − k_salud×(S−3), 0, 1)`. Salud 5 → 0 (clamp) · Salud 3 → 3 % · Salud 1 → 7 %.
func prob_ausencia(agente: RefCounted) -> float:
	return clampf(base_ausencia - k_salud * float(agente.salud - 3), 0.0, 1.0)


# ── F5 · Mercado de fichajes (Story 002 — todo el azar vía RNGService, orden de llamadas FIJO) ─

## Regenera el mercado COMPLETO: `n_candidatos` candidatos sembrados (F5). Determinista: misma semilla
## → mismos candidatos (AC-PE06). Resetea el contador de refresco.
func generar_mercado() -> void:
	mercado.clear()
	for i: int in range(n_candidatos):
		mercado.append(_generar_candidato())
	_jornadas_desde_refresco = 0


## Un candidato F5: atributos con DISTRIBUCIÓN SESGADA AL CENTRO (media redondeada de 2 tiradas 1-5 →
## triangular: medias comunes, cracks y paquetes raros — el `sesgo_candidatos` del GDD). El rango es
## Oficial con `prob_candidato_oficial` (decisión propuesta de la story: de aquí salen los Oficiales).
## Orden de tiradas FIJO (nombre → tipo → rango → 4 atributos → mando) = contrato determinista.
func _generar_candidato() -> RefCounted:
	var nombre: String = pool_nombres[RNGService.randi_rango(0, pool_nombres.size() - 1)]
	var tipo_id: StringName = TIPOS_MERCADO[RNGService.randi_rango(0, TIPOS_MERCADO.size() - 1)]
	var rango: StringName = AgenteScript.RANGO_POLICIA
	if RNGService.randf() < prob_candidato_oficial:
		rango = AgenteScript.RANGO_OFICIAL
	var rapidez: int = _tirada_sesgada()
	var trato: int = _tirada_sesgada()
	var salud: int = _tirada_sesgada()
	var motivacion: int = _tirada_sesgada()
	var mando: int = _tirada_sesgada() if rango == AgenteScript.RANGO_OFICIAL else 0
	return AgenteScript.new(nombre, tipo_id, rango, rapidez, trato, salud, motivacion, mando)


## Tirada 1-5 sesgada al centro: media redondeada de 2 tiradas uniformes (triangular — el 3 es lo más
## común, el 1 y el 5 escasean).
func _tirada_sesgada() -> int:
	var suma: int = RNGService.randi_rango(1, 5) + RNGService.randi_rango(1, 5)
	return roundi(float(suma) / 2.0)


## Contrata al candidato `indice` del mercado (PA4). Gate E4 de Economía: exige poder pagar su
## `salario_dia` — SOLO comprueba, no cobra (sin coste puntual en el MVP — Open Q4; la nómina diaria
## la cobra Economía). El contratado sale del mercado y entra a plantilla como libre.
func contratar(indice: int) -> bool:
	if indice < 0 or indice >= mercado.size():
		push_warning("Personal: contratar indice %d fuera del mercado (%d candidatos)" % [indice, mercado.size()])
		return false
	var candidato: RefCounted = mercado[indice]
	if _economia != null and not _economia.puede_pagar(salario_dia(candidato)):
		return false
	if _economia == null:
		push_warning("Personal: contratando SIN gate de Economia (no inyectada)")
	mercado.remove_at(indice)
	candidato.estado = AgenteScript.ESTADO_LIBRE
	plantilla.append(candidato)
	return true


## Despide a un agente (PA6): sale de la plantilla, LIBERA su puesto y deja de contar en nómina.
## Coste 0 (MVP). (El compromiso "termina su atención en curso" es contrato de Flujo al integrar.)
func despedir(agente: RefCounted) -> void:
	var indice: int = plantilla.find(agente)
	if indice < 0:
		push_warning("Personal: despedir a alguien que no esta en plantilla -> ignorado")
		return
	desasignar(agente)
	plantilla.remove_at(indice)


## Handler del `nuevo_dia` (prioridad 30 del dispatcher — registrado en `_ready`; los tests lo llaman
## directo). Orden interno FIJO — contrato determinista del RNG (cambiarlo rompería la reproducibilidad
## de partidas guardadas): (1) deshacer las coberturas de ayer ANTES de reincorporar (story 005),
## (2) reincorporar a los ausentes de ayer, (3) tirada F4 de ausencia por agente, (4) cobertura del
## Oficial F6, (5) avisos F7 (parte agrupado o individuales), (6) ciclo de refresco del mercado (F5).
## Solo el paso (3) —y el (6) los días de refresco— consume tiradas del RNG.
func _al_nuevo_dia() -> void:
	_deshacer_coberturas()
	_reincorporar_ausentes()
	var incidencias: Dictionary = _evaluar_ausencias()
	var cobertura: Dictionary = _cubrir_vacantes()
	_emitir_avisos(incidencias, cobertura)
	_jornadas_desde_refresco += 1
	if _jornadas_desde_refresco >= refresco_mercado_jornadas:
		generar_mercado()


# ── Ausencias del día (Story 004 · TR-staff-003 · GDD PA7/PA11, F4) ──────────────────────────

## Reincorpora a los ausentes de AYER (PA7): el titular vuelve a su puesto (su plaza se le conservó);
## un ausente sin puesto vuelve al banquillo.
func _reincorporar_ausentes() -> void:
	for agente: RefCounted in plantilla:
		if agente.estado == AgenteScript.ESTADO_AUSENTE:
			if agente.puesto_id != &"":
				agente.estado = AgenteScript.ESTADO_ASIGNADO
			else:
				agente.estado = AgenteScript.ESTADO_LIBRE


## La tirada diaria de ausencia (PA11): recorre la plantilla en ORDEN ESTABLE y por agente tira
## `RNGService.randf() < prob_ausencia` (F4) — orden fijo + RNG sembrado = determinista (AC-PE13).
## El ausente CONSERVA la titularidad (no se desasigna) pero su puesto deja de estar dotado
## (`puesto_dotado` → false: pérdida de capacidad real para Flujo — AC-PE15). Devuelve las
## incidencias del día agrupadas por servicio (&"" = baja de un agente del banquillo):
## `servicio -> Array de {agente, puesto}` — los avisos los emite `_emitir_avisos` (F7, story 005).
func _evaluar_ausencias() -> Dictionary:
	var incidencias: Dictionary = {}
	for agente: RefCounted in plantilla:
		if RNGService.randf() < prob_ausencia(agente):
			agente.estado = AgenteScript.ESTADO_AUSENTE
			var servicio: String = "" if agente.puesto_id == &"" else servicio_de_puesto(agente.puesto_id)
			if not incidencias.has(servicio):
				incidencias[servicio] = []
			incidencias[servicio].append({"agente": agente, "puesto": agente.puesto_id})
	return incidencias


# ── El Oficial: cobertura y canalización (Story 005 · TR-staff-003 · GDD PA8/PA9, F6/F7) ─────

## Deshace las coberturas de ayer: cada cubridor vuelve al banquillo. Corre ANTES de reincorporar
## (el titular que vuelve se encuentra su puesto libre de prestados). Si el titular sigue de baja,
## la pasada de cobertura de HOY volverá a cubrirlo (con presupuesto fresco del Oficial).
func _deshacer_coberturas() -> void:
	for puesto_id: StringName in _coberturas:
		_coberturas[puesto_id].estado = AgenteScript.ESTADO_LIBRE
	_coberturas.clear()


## La cobertura del Oficial (F6): por cada puesto con TITULAR DE BAJA (en orden estable de registro),
## si el servicio tiene Oficial asignado Y presente (no de baja él mismo — edge del GDD), gasta su
## presupuesto diario `ceil(Mando/2)` reasignando al primer agente LIBRE compatible
## (`puestos_operables`; MVP ratificado: solo libres, no mueve titulares). Sin candidato o sin
## presupuesto → la baja se ESCALA al jugador (F7). Un puesto sin titular no se cubre (dotarlo es
## tarea del jugador, no una baja). Devuelve `servicio -> {cubiertas, escaladas}`. Sin azar: la
## cobertura es determinista por reglas (manifest).
func _cubrir_vacantes() -> Dictionary:
	var resumen: Dictionary = {}
	var presupuesto: Dictionary = {}
	for puesto_id: StringName in _puestos:
		var titular: RefCounted = _asignaciones.get(puesto_id)
		if titular == null or titular.estado != AgenteScript.ESTADO_AUSENTE:
			continue
		var servicio: String = servicio_de_puesto(puesto_id)
		var oficial: RefCounted = _oficial_de_servicio(servicio)
		if oficial == null or oficial.estado != AgenteScript.ESTADO_ASIGNADO:
			continue   # sin mando presente no hay cobertura NI parte: avisos individuales (F7)
		if not presupuesto.has(servicio):
			# F6 por la TABLA del GDD (Mando 1-2 → 1 · 3-4 → 2 · 5 → 3) = ceil, no el floor del texto.
			presupuesto[servicio] = ceili(float(oficial.mando) / 2.0)
		if not resumen.has(servicio):
			resumen[servicio] = {"cubiertas": 0, "escaladas": 0}
		var candidato: RefCounted = _libre_compatible(_puestos[puesto_id])
		if int(presupuesto[servicio]) <= 0 or candidato == null:
			resumen[servicio]["escaladas"] = int(resumen[servicio]["escaladas"]) + 1
			continue
		presupuesto[servicio] = int(presupuesto[servicio]) - 1
		_coberturas[puesto_id] = candidato
		candidato.estado = AgenteScript.ESTADO_CUBRIENDO
		resumen[servicio]["cubiertas"] = int(resumen[servicio]["cubiertas"]) + 1
	return resumen


## El primer agente LIBRE de la plantilla (orden estable) que puede operar ese tipo de puesto.
func _libre_compatible(tipo_puesto_id: StringName) -> RefCounted:
	for agente: RefCounted in plantilla:
		if agente.estado != AgenteScript.ESTADO_LIBRE:
			continue
		var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
		if tipo_agente != null and tipo_puesto_id in tipo_agente.puestos_operables:
			return agente
	return null


## La canalización (F7, PA9): por servicio con incidencias, CON Oficial presente → UN parte agrupado
## (`parte_personal`; las cubiertas cuentan como autoresueltas, `escaladas` > 0 = requiere decisión);
## SIN Oficial (o bajas del banquillo, servicio &"") → un aviso individual por baja
## (`incidencia_personal`). Orden de emisión determinista (orden de detección de las bajas).
func _emitir_avisos(incidencias: Dictionary, cobertura: Dictionary) -> void:
	if _bus == null:
		return
	for servicio: String in incidencias:
		var lista: Array = incidencias[servicio]
		var oficial: RefCounted = null
		if servicio != "":
			oficial = _oficial_de_servicio(servicio)
		if oficial != null and oficial.estado == AgenteScript.ESTADO_ASIGNADO:
			var datos_cobertura: Dictionary = cobertura.get(servicio, {"cubiertas": 0, "escaladas": 0})
			_bus.parte_personal.emit({
				"servicio": servicio,
				"ausencias": lista.size(),
				"cubiertas": int(datos_cobertura["cubiertas"]),
				"escaladas": int(datos_cobertura["escaladas"]),
			})
		else:
			for incidencia: Dictionary in lista:
				_bus.incidencia_personal.emit(
					"%s no ha venido hoy (baja)" % incidencia["agente"].nombre, incidencia["puesto"]
				)


## Si el agente estaba cubriendo un puesto, la cobertura se anula (el puesto vuelve a quedar sin
## dotar). NO toca el estado del agente — eso lo decide quien llama (asignar/desasignar).
func _liberar_cobertura_de(agente: RefCounted) -> void:
	var puesto_cubierto: Variant = _coberturas.find_key(agente)
	if puesto_cubierto != null:
		_coberturas.erase(puesto_cubierto)


# ── Asignación a puestos y gate FL4 (Story 003 · TR-staff-002 · GDD PA2/PA5) ─────────────────

## Puestos que existen en el mundo: `puesto_id -> tipo_puesto_id` (catálogo). Hoy los registra Main
## (dotación estándar del esqueleto); cuando exista Construcción, registrará los puestos REALES con
## esta misma API y nada se tira.
var _puestos: Dictionary[StringName, StringName] = {}
## Asignaciones vigentes: `puesto_id -> Agente` (`plazas_agente = 1`). SIEMPRE el TITULAR (un
## ausente conserva su entrada — story 004); los cubridores van aparte en `_coberturas`.
var _asignaciones: Dictionary[StringName, RefCounted] = {}
## Coberturas vigentes HOY (story 005): `puesto_id -> cubridor` (estado &"cubriendo"; su `puesto_id`
## propio queda &"" — cubre de prestado, sin titularidad). Se deshacen al empezar cada `nuevo_dia`.
var _coberturas: Dictionary[StringName, RefCounted] = {}


## Registra un puesto del mundo. El tipo debe existir en el catálogo (integridad — patrón Datos).
func registrar_puesto(puesto_id: StringName, tipo_puesto_id: StringName) -> void:
	if Datos.obtener(&"TipoPuesto", tipo_puesto_id) == null:
		push_warning("Personal: tipo de puesto '%s' no existe en el catalogo -> no registrado" % tipo_puesto_id)
		return
	_puestos[puesto_id] = tipo_puesto_id


## Retira un puesto del mundo (demolición futura): su agente, si lo había, queda libre; una
## cobertura activa se anula (el cubridor vuelve al banquillo — story 005).
func quitar_puesto(puesto_id: StringName) -> void:
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		cubridor.estado = AgenteScript.ESTADO_LIBRE
		_coberturas.erase(puesto_id)
	var agente: RefCounted = _asignaciones.get(puesto_id)
	if agente != null:
		desasignar(agente)
	_puestos.erase(puesto_id)


## Asigna un agente a un puesto (PA5). Reglas de juego (false SILENCIOSO — son rechazos normales que
## la UI mostrará deshabilitados, no errores): puesto ocupado, tipo no operable (`puestos_operables`
## de Datos) o 2.º Oficial en el servicio (PA2). Un dato inexistente sí avisa. Si el agente estaba en
## otro puesto, se MUEVE (libera el anterior — atómico; el "no cortar la atención en curso" es
## contrato de Flujo al consumir el cambio).
func asignar(agente: RefCounted, puesto_id: StringName) -> bool:
	if not _puestos.has(puesto_id):
		push_warning("Personal: asignar a puesto no registrado '%s'" % puesto_id)
		return false
	if agente.estado == AgenteScript.ESTADO_AUSENTE:
		return false   # hoy está de baja (story 004): no se incorpora hasta el nuevo_dia siguiente
	var ocupante: RefCounted = _asignaciones.get(puesto_id)
	if ocupante == agente:
		return true   # ya estaba — idempotente
	if ocupante != null:
		return false   # plazas_agente = 1
	var tipo_agente: Resource = Datos.obtener(&"TipoAgente", agente.tipo_id)
	if tipo_agente == null:
		return false   # Datos ya avisó
	var tipo_puesto_id: StringName = _puestos[puesto_id]
	if not (tipo_puesto_id in tipo_agente.puestos_operables):
		return false   # un ag_doc no opera un puesto_odac (Datos manda)
	if agente.rango == AgenteScript.RANGO_OFICIAL:
		var servicio: String = servicio_de_puesto(puesto_id)
		var oficial_actual: RefCounted = _oficial_de_servicio(servicio)
		if oficial_actual != null and oficial_actual != agente:
			return false   # máx. 1 Oficial por servicio (PA2)
	if agente.puesto_id != &"":
		_asignaciones.erase(agente.puesto_id)
	# (story 005) si el propio agente estaba cubriendo en otro sitio, deja de hacerlo; y si el puesto
	# destino lo tapaba un cubridor (su titular se fue), el cubridor vuelve al banquillo: llega titular.
	_liberar_cobertura_de(agente)
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		cubridor.estado = AgenteScript.ESTADO_LIBRE
		_coberturas.erase(puesto_id)
	_asignaciones[puesto_id] = agente
	agente.puesto_id = puesto_id
	agente.estado = AgenteScript.ESTADO_ASIGNADO
	return true


## Quita a un agente de su puesto (vuelve al banquillo). Sin puesto → no-op. Un AUSENTE pierde la
## titularidad pero sigue de baja hoy (story 004: la baja es del día, no se "cura" desasignando).
## A un CUBRIENDO se le anula la cobertura (story 005) y queda libre.
func desasignar(agente: RefCounted) -> void:
	_liberar_cobertura_de(agente)
	if agente.puesto_id != &"":
		_asignaciones.erase(agente.puesto_id)
	agente.puesto_id = &""
	if agente.estado != AgenteScript.ESTADO_AUSENTE:
		agente.estado = AgenteScript.ESTADO_LIBRE


## Servicio de un puesto registrado ("Documentacion"/"ODAC"/"Seguridad") — lo posee el catálogo.
func servicio_de_puesto(puesto_id: StringName) -> String:
	var tipo: Resource = Datos.obtener(&"TipoPuesto", _puestos.get(puesto_id, &""))
	if tipo == null:
		return ""
	return tipo.servicio


## El Oficial ASIGNADO en un servicio (null si no hay) — regla PA2 y, en la story 005, quién cubre.
func _oficial_de_servicio(servicio: String) -> RefCounted:
	for agente: RefCounted in _asignaciones.values():
		if agente.rango == AgenteScript.RANGO_OFICIAL and servicio_de_puesto(agente.puesto_id) == servicio:
			return agente
	return null


# ── Gate FL4 y modificadores por puesto (la API que consumirá Flujo) ─────────────────────────

## ¿El puesto está DOTADO? (gate FL4): hay un cubridor (story 005) o el titular está al pie. El
## AUSENTE no dota (story 004). Un puesto sin dotar está cerrado: Flujo no atiende en él.
func puesto_dotado(puesto_id: StringName) -> bool:
	if _coberturas.has(puesto_id):
		return true
	var agente: RefCounted = _asignaciones.get(puesto_id)
	return agente != null and agente.estado == AgenteScript.ESTADO_ASIGNADO


## El agente que responde HOY por el puesto: el cubridor si hay cobertura (story 005); si no, el
## titular (aunque esté ausente — la titularidad se consulta aquí o por `agente.puesto_id`).
func agente_de(puesto_id: StringName) -> RefCounted:
	var cubridor: RefCounted = _coberturas.get(puesto_id)
	if cubridor != null:
		return cubridor
	return _asignaciones.get(puesto_id)


## F2 del agente OPERATIVO del puesto (lo consumirá Flujo F1; con cobertura rinde el cubridor).
## Sin agente → 1.0 neutro con aviso.
func modificador_produccion_de(puesto_id: StringName) -> float:
	var agente: RefCounted = agente_de(puesto_id)
	if agente == null:
		push_warning("Personal: modificador de un puesto sin agente ('%s') -> 1.0" % puesto_id)
		return 1.0
	return modificador_produccion(agente)


## F3 del agente OPERATIVO del puesto (lo consumirá Flujo al cerrar → Paciencia). Sin agente → 1.0
## con aviso.
func factor_trato_de(puesto_id: StringName) -> float:
	var agente: RefCounted = agente_de(puesto_id)
	if agente == null:
		push_warning("Personal: factor de trato de un puesto sin agente ('%s') -> 1.0" % puesto_id)
		return 1.0
	return factor_trato(agente)


# ── Config (patrón Economía/Demanda: aplicar con clamp defensivo + carga con fallback) ───────

## Copia los knobs del config con clamp defensivo y aviso. Config nulo/de otro tipo → defaults.
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigPersonalScript):
		push_warning("Personal: config invalido -> defaults")
		config = ConfigPersonalScript.new()
	k_calidad = _clamp_knob(config.k_calidad, "k_calidad")
	prima_rango_oficial = maxf(_clamp_knob(config.prima_rango_oficial, "prima_rango_oficial"), 1.0)
	k_rapidez = _clamp_knob(config.k_rapidez, "k_rapidez")
	k_motivacion_rapidez = _clamp_knob(config.k_motivacion_rapidez, "k_motivacion_rapidez")
	k_trato = _clamp_knob(config.k_trato, "k_trato")
	k_motivacion_trato = _clamp_knob(config.k_motivacion_trato, "k_motivacion_trato")
	base_ausencia = _clamp_knob(config.base_ausencia, "base_ausencia")
	k_salud = _clamp_knob(config.k_salud, "k_salud")
	coste_despido = _clamp_knob(config.coste_despido, "coste_despido")
	n_candidatos = maxi(config.n_candidatos, 1)
	refresco_mercado_jornadas = maxi(config.refresco_mercado_jornadas, 1)
	prob_candidato_oficial = clampf(config.prob_candidato_oficial, 0.0, 1.0)
	pool_nombres = config.pool_nombres.duplicate()
	if pool_nombres.is_empty():
		push_warning("Personal: pool_nombres vacio -> nombre generico")
		pool_nombres = ["Agente Sin Nombre"]


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Personal: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón Datos/Tiempo/Economía/Demanda).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Personal: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor
