extends SceneTree
## build_catalogo.gd — HERRAMIENTA DEV (no runtime): genera el catálogo `.tres` de Pozuelo desde código.
##
## Instancia por código cada definición del catálogo MVP con los valores EXACTOS del GDD `data-config.md`
## (F1–F7) y la guarda con `ResourceSaver.save()` en `res://datos/<carpeta>/<id>.tres`. Así se evita
## escribir `.tres` a mano (uids/`ext_resource` frágiles — Story 004 / ADR-0003 Notas). Este script vive
## en `tools/` (dev tooling), NUNCA se ejecuta en runtime del juego.
##
## Uso (headless, una vez / al cambiar los valores semilla):
##   godot --headless --path <repo> --script res://tools/build_catalogo.gd
##
## Comprueba el código de retorno de cada `ResourceSaver.save` y termina con exit code ≠0 si algo falla,
## para que el CI/usuario detecte una generación incompleta.
##
## Story: production/epics/datos/story-004-catalogo-mvp-pozuelo.md (contenido) · ADR-0003
## Fuente de los valores: design/gdd/data-config.md §F1–F7 (transcritos con exactitud).

# ── Scripts del esquema (Story 001) por RUTA LITERAL ─────────────────────────────────────
const TramiteDocScript := preload("res://src/foundation/datos/esquema/tramite_doc.gd")
const DenunciaODACScript := preload("res://src/foundation/datos/esquema/denuncia_odac.gd")
const TipoPuestoScript := preload("res://src/foundation/datos/esquema/tipo_puesto.gd")
const TipoSalaScript := preload("res://src/foundation/datos/esquema/tipo_sala.gd")
const TipoAgenteScript := preload("res://src/foundation/datos/esquema/tipo_agente.gd")
const CostesScript := preload("res://src/foundation/datos/esquema/costes.gd")
const EscenarioScript := preload("res://src/foundation/datos/esquema/escenario.gd")
const EventoDivisionScript := preload("res://src/foundation/datos/esquema/evento_division.gd")
const ComodidadScript := preload("res://src/foundation/datos/esquema/comodidad.gd")

const RUTA_CATALOGO := "res://datos/"

## Los `id` de las 14 atenciones de ODAC (F2), en orden. Se usa TANTO para generar las `DenunciaODAC`
## como para poblar `puesto_odac.atenciones_admitidas` (F3: "todas las denuncias") desde LA MISMA lista,
## de modo que puesto y catálogo NO puedan divergir.
##
## Son 13 denuncias CIUDADANAS + 1 atención INTERNA `reclamacion` (14ª — decisión usuario 2026-07-22):
## `reclamacion` (Hoja de reclamaciones, F2 "Atención especial") se modela como una DenunciaODAC más para
## que ocupe el mismo `puesto_odac` y comparta cola/duración, PERO su ORIGEN es interno: la GENERA Paciencia
## (PS13, cuando un ciudadano abandona Documentación), NO el generador de Demanda ciudadana. Por eso NO entra
## en la tabla de mezcla de Demanda; aquí solo existe como DEFINICIÓN de atención despachable en ODAC.
const IDS_DENUNCIAS: Array[StringName] = [
	&"viogen", &"lesiones", &"estafa", &"hurto_robo", &"amenazas", &"danos",
	&"perdida_sustraccion", &"permiso_viaje", &"desaparecidos", &"agresion_sexual",
	&"robo_violencia", &"okupacion", &"ciberestafa",
	&"reclamacion",  # 14ª: atención interna (la genera Paciencia PS13, no la demanda ciudadana).
]

## Nº de archivos que se esperan generados (para el resumen final). 3 trámites + 14 denuncias + 4 puestos
## + 5 salas + 3 agentes + 1 costes + 1 escenario + 2 eventos + 17 comodidades = 50.
## Las comodidades son 8 de sala de espera/oficina (Comodidades #15) + 6 de sala de descanso
## (Bienestar #13, familia "descanso" — petición del usuario 2026-07-29) + 3 de iluminación
## (familia "iluminacion", se colocan en CUALQUIER sala — petición del usuario 2026-07-29:
## "no veo tampoco la instalacion de luces para la noche").
const TOTAL_ESPERADO := 50

## Acumula fallos de guardado para terminar con exit code ≠0.
var _fallos: int = 0
var _guardados: int = 0


func _init() -> void:
	print("build_catalogo: generando el catálogo MVP de Pozuelo en '%s'..." % RUTA_CATALOGO)
	_asegurar_carpetas()
	_generar_tramites()      # F1 — 3 TramiteDoc
	_generar_denuncias()     # F2 — 14 DenunciaODAC (13 ciudadanas + 1 interna `reclamacion`)
	_generar_puestos()       # F3 — 4 TipoPuesto
	_generar_salas()         # F4 — 5 TipoSala (incl. la de descanso, Bienestar #13)
	_generar_agentes()       # F5 — 3 TipoAgente
	_generar_costes()        # F6 — 1 Costes
	_generar_escenario()     # F7 — 1 Escenario
	_generar_eventos()       # F8 — 2 EventoDivision (story doc-004)
	_generar_comodidades()   # F9 — 8 Comodidad (story com-001)

	print("build_catalogo: %d guardados, %d fallos (esperados %d archivos)." % [
		_guardados, _fallos, TOTAL_ESPERADO,
	])
	if _fallos > 0 or _guardados != TOTAL_ESPERADO:
		push_error("build_catalogo: generación INCOMPLETA (%d/%d, %d fallos)." % [
			_guardados, TOTAL_ESPERADO, _fallos,
		])
		quit(1)
	else:
		print("build_catalogo: OK — catálogo completo generado.")
		quit(0)


# ── Generadores por familia ──────────────────────────────────────────────────────────────

## F1 · Trámites de Documentación. servicio="Documentacion", requiere_cita=false (MVP arranca sin cita).
func _generar_tramites() -> void:
	_guardar(_tramite(&"dni", "DNI", 12, 12, &"puesto_doc_general"), "tramites")
	_guardar(_tramite(&"pasaporte", "Pasaporte", 15, 30, &"puesto_doc_general"), "tramites")
	_guardar(_tramite(&"tie", "TIE", 15, 18, &"puesto_tie"), "tramites")


## F2 · Atenciones de ODAC (14). servicio="ODAC", tipo_puesto=puesto_odac, admite_cita=false (F2: las
## denuncias NO usan cita). Duración/prioridad de la tabla F2.
##
## Son 13 denuncias CIUDADANAS + 1 atención INTERNA `reclamacion` (14ª, decisión usuario 2026-07-22): la
## "Hoja de reclamaciones" (F2 "Atención especial") se modela como una DenunciaODAC más (mismo `puesto_odac`,
## misma cola). Su ORIGEN es interno: la GENERA Paciencia (PS13) cuando un ciudadano abandona Documentación,
## NO el generador de Demanda ciudadana. Aquí solo existe como DEFINICIÓN de atención (no entra en la tabla de
## mezcla de Demanda). `duracion_min=30`, `prioridad="Normal"` (F2), sin tarifa (las denuncias no cobran).
func _generar_denuncias() -> void:
	_guardar(_denuncia(&"viogen", "Violencia de género (VioGén)", 60, "Prioritaria"), "denuncias")
	_guardar(_denuncia(&"lesiones", "Lesiones", 30, "Normal"), "denuncias")
	_guardar(_denuncia(&"estafa", "Estafas", 30, "Normal"), "denuncias")
	_guardar(_denuncia(&"hurto_robo", "Hurtos / robos", 30, "Normal"), "denuncias")
	_guardar(_denuncia(&"amenazas", "Amenazas", 25, "Normal"), "denuncias")
	_guardar(_denuncia(&"danos", "Daños", 20, "Normal"), "denuncias")
	_guardar(_denuncia(&"perdida_sustraccion", "Pérdidas / sustracciones", 15, "Normal"), "denuncias")
	_guardar(_denuncia(&"permiso_viaje", "Permisos de viaje", 15, "Normal"), "denuncias")
	_guardar(_denuncia(&"desaparecidos", "Desaparecidos", 60, "Prioritaria"), "denuncias")
	_guardar(_denuncia(&"agresion_sexual", "Agresión sexual", 60, "Prioritaria"), "denuncias")
	_guardar(_denuncia(&"robo_violencia", "Robo con violencia / atraco", 35, "Prioritaria"), "denuncias")
	_guardar(_denuncia(&"okupacion", "Okupación de vivienda", 30, "Normal"), "denuncias")
	_guardar(_denuncia(&"ciberestafa", "Ciberestafa / delito informático", 35, "Normal"), "denuncias")
	# 14ª — atención interna (origen: Paciencia PS13, no la demanda ciudadana). Ver comentario de la función.
	_guardar(_denuncia(&"reclamacion", "Hoja de reclamaciones", 30, "Normal"), "denuncias")


## F3 · Tipos de Puesto. superficie=1, plazas_agente=1 (defaults del esquema, coinciden con F3).
## `puesto_odac.atenciones_admitidas` = TODAS las atenciones de ODAC (IDS_DENUNCIAS, misma lista fuente que
## F2 → no diverge). Incluye la 14ª `reclamacion`: `puesto_odac` DEBE admitirla para que la valide `Datos`
## (integridad referencial) y para que Paciencia (PS13) pueda encolarla en ODAC.
func _generar_puestos() -> void:
	_guardar(_puesto(
		&"puesto_doc_general", "Ventanilla Documentación", "Documentacion",
		[&"dni", &"pasaporte"], false, 500), "puestos")
	_guardar(_puesto(
		&"puesto_tie", "Puesto TIE", "Documentacion",
		[&"tie"], false, 500), "puestos")
	_guardar(_puesto(
		&"puesto_odac", "Puesto ODAC", "ODAC",
		IDS_DENUNCIAS, true, 600), "puestos")
	_guardar(_puesto(
		&"puesto_seguridad", "Entrada / Seguridad", "Seguridad",
		[], false, 400), "puestos")


## F4 · Tipos de Sala. `superficie=0` en todas: es INDICATIVA — Construcción posee el modelo espacial
## (F4 nota); no se fija como semilla aquí. Esperas: aforo real; oficinas: aforo 0 / coste 0 (áreas lógicas).
func _generar_salas() -> void:
	_guardar(_sala(
		&"sala_espera_doc", "Sala de Espera — Documentación", "espera", "Documentacion",
		[], 40, 200), "salas")
	_guardar(_sala(
		&"sala_espera_odac", "Sala de Espera — ODAC", "espera", "ODAC",
		[], 10, 200), "salas")
	_guardar(_sala(
		&"sala_documentacion", "Oficina de Documentación", "oficina", "Documentacion",
		[&"puesto_doc_general", &"puesto_tie"], 0, 0), "salas")
	_guardar(_sala(
		&"sala_odac", "Oficina de ODAC", "oficina", "ODAC",
		[&"puesto_odac"], 0, 0), "salas")
	# Bienestar #13: el cuarto donde se toman el cafe. Comun a los dos servicios (la comisaria tiene
	# UNA sala de descanso, no una por departamento). Sin ella se descansa igual, pero mas despacio.
	_guardar(_sala(
		&"sala_descanso", "Sala de Descanso", "descanso", "Comun",
		[], 0, 300, true), "salas")


## F5 · Tipos de Agente.
func _generar_agentes() -> void:
	_guardar(_agente(
		&"ag_doc", "Funcionario de Documentación", "Secretaría", "Básica", "complementario",
		[&"puesto_doc_general", &"puesto_tie"], 60), "agentes")
	_guardar(_agente(
		&"ag_odac", "Instructor de ODAC", "Policía Judicial", "Básica/Subinspección", "turnos",
		[&"puesto_odac"], 70), "agentes")
	_guardar(_agente(
		&"ag_seguridad", "Agente de Seguridad (Entrada)", "Seguridad Ciudadana", "Básica", "turnos",
		[&"puesto_seguridad"], 65), "agentes")


## F6 · Costes transversales (id fijo `costes_global` — ver nota de `id` en costes.gd).
func _generar_costes() -> void:
	var c: Resource = CostesScript.new()
	c.id = &"costes_global"
	c.peonada_eur_hora = 15.0
	c.retorno_dgp_min = 0.15
	c.retorno_dgp_max = 0.45
	_guardar(c, "costes")


## F7 · Escenario MVP — Oficina de Denuncias de Pozuelo.
func _generar_escenario() -> void:
	var e: Resource = EscenarioScript.new()
	e.id = &"pozuelo"
	e.nombre = "Oficina de Denuncias de Pozuelo"
	e.nivel = "Nivel 1 — Comisaría Local"
	e.poblacion = 90000
	# Dictionary[StringName, int] — tope por id de TipoPuesto (Doc≤8 · TIE≤2 · ODAC≤4 · Entrada 1).
	var tope: Dictionary[StringName, int] = {
		&"puesto_doc_general": 8,
		&"puesto_tie": 2,
		&"puesto_odac": 4,
		&"puesto_seguridad": 1,
	}
	e.tope_construible = tope
	e.rango_requerido = "Subinspector"
	var servicios: Array[StringName] = [&"Documentacion", &"ODAC"]
	e.servicios_activos = servicios
	_guardar(e, "escenarios")


# ── Fábricas de cada tipo ──────────────────────────────────────────────────────────────────
# icono = null en todo (arte pendiente del art bible — Story 004 Out of Scope).

func _tramite(
		id: StringName, nombre: String, duracion_min: int, tarifa_eur: int,
		tipo_puesto: StringName) -> Resource:
	var r: Resource = TramiteDocScript.new()
	r.id = id
	r.nombre = nombre
	r.servicio = "Documentacion"
	r.duracion_min = duracion_min
	r.tipo_puesto = tipo_puesto
	r.tarifa_eur = tarifa_eur
	r.requiere_cita = false
	return r


func _denuncia(id: StringName, nombre: String, duracion_min: int, prioridad: String) -> Resource:
	var r: Resource = DenunciaODACScript.new()
	r.id = id
	r.nombre = nombre
	r.servicio = "ODAC"
	r.duracion_min = duracion_min
	r.tipo_puesto = &"puesto_odac"
	r.prioridad = prioridad
	r.admite_cita = false
	return r


func _puesto(
		id: StringName, nombre: String, servicio: String, atenciones: Array,
		reconfigurable: bool, coste_eur: int) -> Resource:
	var r: Resource = TipoPuestoScript.new()
	r.id = id
	r.nombre = nombre
	r.servicio = servicio
	# El @export es Array[StringName] tipado; se copia a una var tipada para asignar limpio.
	var admitidas: Array[StringName] = []
	for a: StringName in atenciones:
		admitidas.append(a)
	r.atenciones_admitidas = admitidas
	r.reconfigurable = reconfigurable
	r.coste_construccion_eur = coste_eur
	# plazas_agente=1, superficie=1 son los defaults del esquema (coinciden con F3).
	return r


func _sala(
		id: StringName, nombre: String, tipo: String, servicio: String,
		puestos: Array, aforo: int, coste_eur: int,
		paredes: bool = false) -> Resource:
	var r: Resource = TipoSalaScript.new()
	r.id = id
	r.nombre = nombre
	r.tipo = tipo
	r.servicio = servicio
	var admitidos: Array[StringName] = []
	for p: StringName in puestos:
		admitidos.append(p)
	r.puestos_admitidos = admitidos
	r.aforo_espera = aforo
	r.coste_construccion_eur = coste_eur
	r.superficie = 0   # indicativa; la posee Construcción (F4 nota).
	# Solo la sala de DESCANSO nace con paredes (decision del usuario 2026-07-30): su razon de ser es
	# la intimidad. El resto nacen en planta diafana — ahi se quiere DELIMITAR la zona, no aislarla.
	r.paredes_por_defecto = paredes
	return r


func _agente(
		id: StringName, puesto_organico: String, unidad: String, escala_rango: String,
		tipo_horario: String, puestos: Array, salario_dia_eur: int) -> Resource:
	var r: Resource = TipoAgenteScript.new()
	r.id = id
	r.puesto_organico = puesto_organico
	r.unidad = unidad
	r.escala_rango = escala_rango
	r.tipo_horario = tipo_horario
	var operables: Array[StringName] = []
	for p: StringName in puestos:
		operables.append(p)
	r.puestos_operables = operables
	r.salario_dia_eur = salario_dia_eur
	return r


## F8 · Los eventos de la División (DO7, story doc-004). MVP: **2 eventos simples** para validar el
## mecanismo — el catálogo crece en playtest/V-Slice (campañas de DNI, jornada ininterrumpida...).
## Deterministas por MES (decisión del usuario 2026-07-26): la estacionalidad se aprende, no se sortea.
func _generar_eventos() -> void:
	_guardar(_evento(
		&"vacaciones", "Periodo vacacional",
		"La División avisa del pico anual de pasaportes. Se autoriza ampliar el horario hasta las 21:30.",
		[7, 8], &"pasaporte", 1290
	), "eventos")
	_guardar(_evento(
		&"colapso_extranjeria", "Colapso en extranjería",
		"Atasco en las citas de extranjería. Se autoriza ampliar el horario de TIE hasta las 21:30.",
		[2], &"tie", 1290
	), "eventos")


func _evento(
	id: StringName, nombre: String, descripcion: String,
	meses: Array[int], tramite: StringName, cierre_max_min: int
) -> Resource:
	var r: Resource = EventoDivisionScript.new()
	r.id = id
	r.nombre = nombre
	r.descripcion = descripcion
	r.meses = meses
	r.tramite_destacado = tramite
	r.cierre_max_min = cierre_max_min
	return r


## F9 · Los objetos que se compran y se colocan (Comodidades #15, story com-001). Cuatro familias:
## "ciudadano" (confort de la espera), "funcionario" (rendimiento del puesto), "descanso" (calidad
## del café) e "iluminacion" (se coloca en cualquier sala — petición del usuario 2026-07-29, ver
## comentario de `TOTAL_ESPERADO`). El mantenimiento SOLO lo llevan los aparatos que consumen: la
## papelera y el revistero se pagan una vez y ya.
func _generar_comodidades() -> void:
	_guardar(_comodidad(
		&"papelera", "Papelera", "Una sala sin papeleras se ensucia y se nota.",
		"ciudadano", 60, 0, 1.0
	), "comodidades")
	_guardar(_comodidad(
		&"revistero", "Revistero", "Prensa del dia: se coge una y se hojea mientras se espera.",
		"ciudadano", 150, 0, 2.0, true, 0.0, 2.0, 8.0
	), "comodidades")
	_guardar(_comodidad(
		&"radio", "Hilo musical", "Musica ambiente: la espera se hace menos larga.",
		"ciudadano", 250, 1, 3.0
	), "comodidades")
	_guardar(_comodidad(
		&"fuente_agua", "Fuente de agua", "Agua fresca para los que llevan horas. Gratis.",
		"ciudadano", 400, 2, 3.0, true, 0.0, 2.0, 10.0,
		true, Color(0.85, 0.95, 1.0), 70.0    # un piloto blanco tenue
	), "comodidades")
	_guardar(_comodidad(
		&"vending", "Maquina de vending", "Cafe y algo de picar: cada consumicion deja 1 EUR en caja.",
		"ciudadano", 1200, 3, 5.0, true, 1.0, 3.0, 15.0,
		true, Color(1.0, 0.85, 0.55), 95.0    # el expositor iluminado y sus pilotos
	), "comodidades")
	_guardar(_comodidad(
		&"television", "Television", "Lo que mas mata el tiempo de una sala de espera.",
		"ciudadano", 900, 4, 6.0, false, 0.0, 3.0, 0.0,
		true, Color(0.55, 0.72, 1.0), 110.0   # el parpadeo azulado de la pantalla
	), "comodidades")
	_guardar(_comodidad(
		&"equipo_informatico", "Equipo informatico nuevo", "Menos pantallazos, mas tramites.",
		"funcionario", 1500, 2, 4.0, false, 0.0, 3.0, 0.0,
		true, Color(0.70, 0.85, 1.0), 80.0    # el monitor encendido en la oficina de noche
	), "comodidades")
	_guardar(_comodidad(
		&"impresora_dni", "Impresora de DNI moderna", "El documento sale en la mitad de tiempo.",
		"funcionario", 2200, 3, 6.0
	), "comodidades")
	# Familia "descanso" (Bienestar #13, peticion del usuario 2026-07-29): lo que se pone en la sala
	# de descanso. Cuanto mejor montada, MENOS dura la pausa: el cafe cunde y vuelven antes a la
	# ventanilla. Los que tienen `plazas` son ademas sitio donde sentarse (aforo del descanso).
	_guardar(_comodidad(
		&"prensa_diaria", "Prensa del dia", "El periodico y unas revistas. Desconectar tambien descansa.",
		"descanso", 50, 1, 1.0
	), "comodidades")
	_guardar(_comodidad(
		&"sillas_office", "Sillas de office", "Cuatro sillas y una mesa: lo minimo para no tomarse el cafe de pie.",
		"descanso", 90, 0, 1.0, false, 0.0, 3.0, 0.0,
		false, Color(1.0, 0.9, 0.7), 90.0, 2, 2    # 2 plazas, superficie 2 (coinciden a proposito)
	), "comodidades")
	_guardar(_comodidad(
		&"dispensador_agua", "Dispensador de agua", "Agua fria para el personal. Barato y se agradece.",
		"descanso", 180, 1, 1.5, false, 0.0, 3.0, 0.0,
		true, Color(0.85, 0.95, 1.0), 60.0      # un piloto blanco tenue
	), "comodidades")
	_guardar(_comodidad(
		&"nevera", "Nevera", "Para el tupper y las bebidas frias. La media hora cunde el doble.",
		"descanso", 320, 2, 2.0
	), "comodidades")
	_guardar(_comodidad(
		&"maquina_cafe", "Maquina de cafe", "El cafe de verdad, el que da nombre a la pausa.",
		"descanso", 380, 3, 3.0, false, 0.0, 3.0, 0.0,
		true, Color(1.0, 0.85, 0.55), 75.0      # el piloto ambar de la maquina
	), "comodidades")
	_guardar(_comodidad(
		&"sofa_descanso", "Sofa", "Se sientan tres y se levantan nuevos. La pieza cara de la sala.",
		"descanso", 550, 0, 4.0, false, 0.0, 3.0, 0.0,
		false, Color(1.0, 0.9, 0.7), 90.0, 3, 3    # 3 plazas, superficie 3 (coinciden a proposito)
	), "comodidades")
	# Familia "iluminacion" (peticion del usuario 2026-07-29: "no veo tampoco la instalacion de
	# luces para la noche"). Se coloca en CUALQUIER tipo de sala (espera, oficina o descanso) --
	# a diferencia de las otras tres familias, que solo encajan en la suya. `aporte = 0.0` en las
	# tres: no dan confort ni rendimiento, lo que se compra es VER de noche, no un multiplicador
	# (si se quisiera tambien un poco de confort por "sala bien iluminada", seria una decision de
	# diseno aparte -- no metida aqui sin avisar). El foco LED es el unico con mantenimiento 0:
	# consume tan poco que no sangra a diario, a cambio de costar mas de entrada.
	# ILUMINACION (peticion del usuario 2026-07-29). El ALCANCE se piensa en CASILLAS, que es como lo
	# ve el jugador, y se convierte a pixeles aqui: la celda mide 40 px, asi que una cobertura de NxN
	# casillas centrada en la lampara es un radio de (N/2)*40. 3x3 -> 60 px · 5x5 -> 100 px.
	# "un foco led que es el mas caro puede dar luz de 5x5 casillas... el fluorescente por ejemplo 3x3
	# igual que la lampara de pie". Precios rebajados a la mitad en la misma pasada: "las lamparas las
	# veo demasiado caras".
	_guardar(_comodidad(
		&"fluorescente", "Fluorescente", "El tubo de toda oficina. Barato y de sobra para ver.",
		"iluminacion", 60, 1, 0.0, false, 0.0, 3.0, 0.0,
		true, Color(0.90, 0.96, 1.0), 100.0, 0, 1, 60.0   # TUBO: 5 casillas de ancho x 3 de alto
	), "comodidades")
	_guardar(_comodidad(
		&"lampara_pie", "Lampara de pie", "Luz calida, un rincon mas acogedor para pasar la noche.",
		"iluminacion", 90, 1, 0.0, false, 0.0, 3.0, 0.0,
		true, Color(1.0, 0.82, 0.55), 60.0     # calida y acogedora - 3x3 casillas, como el fluorescente
	), "comodidades")
	_guardar(_comodidad(
		&"foco_led", "Foco LED", "El mas caro de instalar, pero no gasta nada dia a dia.",
		"iluminacion", 180, 0, 0.0, false, 0.0, 3.0, 0.0,
		true, Color(0.88, 0.94, 1.0), 100.0    # LED - 5x5 CASILLAS (radio 2,5 celdas): el que de verdad ilumina una sala
	), "comodidades")


func _comodidad(
	id: StringName, nombre: String, descripcion: String, familia: String,
	coste: int, mantenimiento: int, aporte: float,
	usable: bool = false, ingreso_uso: float = 0.0, minutos_uso: float = 3.0,
	recupera: float = 0.0,
	emite_luz: bool = false, color_luz: Color = Color(1.0, 0.9, 0.7), radio_luz: float = 90.0,
	plazas: int = 0, superficie: int = 1, radio_luz_y: float = 0.0
) -> Resource:
	var r: Resource = ComodidadScript.new()
	r.id = id
	r.nombre = nombre
	r.descripcion = descripcion
	r.familia = familia
	r.coste_construccion_eur = coste
	r.coste_mantenimiento_dia_eur = mantenimiento
	r.aporte = aporte
	r.usable = usable
	r.ingreso_por_uso_eur = ingreso_uso
	r.minutos_de_uso = minutos_uso
	r.recupera_paciencia = recupera
	r.emite_luz = emite_luz
	r.color_luz = color_luz
	r.radio_luz = radio_luz
	r.plazas = plazas
	r.radio_luz_y = radio_luz_y
	r.superficie = superficie
	return r


# ── Guardado (con comprobación de error) ─────────────────────────────────────────────────

## Crea las carpetas del catálogo si faltan (DirAccess). Idempotente.
func _asegurar_carpetas() -> void:
	var base: DirAccess = DirAccess.open("res://")
	if base == null:
		push_error("build_catalogo: no se pudo abrir 'res://'.")
		quit(1)
		return
	base.make_dir_recursive("datos")
	for carpeta: String in [
		"tramites", "denuncias", "puestos", "salas", "agentes", "costes", "escenarios", "eventos",
		"comodidades",
	]:
		base.make_dir_recursive("datos".path_join(carpeta))


## Guarda `res` en `res://datos/<carpeta>/<res.id>.tres` y comprueba el código de error de ResourceSaver.
func _guardar(res: Resource, carpeta: String) -> void:
	var id: StringName = res.get(&"id")
	var ruta: String = RUTA_CATALOGO.path_join(carpeta).path_join("%s.tres" % id)
	var err: int = ResourceSaver.save(res, ruta)
	if err != OK:
		push_error("build_catalogo: FALLO al guardar '%s' (error %d)." % [ruta, err])
		_fallos += 1
		return
	_guardados += 1
	print("  guardado: %s" % ruta)
