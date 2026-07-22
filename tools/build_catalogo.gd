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

const RUTA_CATALOGO := "res://datos/"

## Los `id` de las 13 denuncias de ODAC (F2), en orden. Se usa TANTO para generar las `DenunciaODAC`
## como para poblar `puesto_odac.atenciones_admitidas` (F3: "todas las denuncias") desde LA MISMA lista,
## de modo que puesto y catálogo NO puedan divergir. (`reclamacion` NO se incluye — decisión pendiente
## Story 004; el catálogo MVP tiene exactamente 13 denuncias.)
const IDS_DENUNCIAS: Array[StringName] = [
	&"viogen", &"lesiones", &"estafa", &"hurto_robo", &"amenazas", &"danos",
	&"perdida_sustraccion", &"permiso_viaje", &"desaparecidos", &"agresion_sexual",
	&"robo_violencia", &"okupacion", &"ciberestafa",
]

## Nº de archivos que se esperan generados (para el resumen final). 3 trámites + 13 denuncias + 4 puestos
## + 4 salas + 3 agentes + 1 costes + 1 escenario = 29.
const TOTAL_ESPERADO := 29

## Acumula fallos de guardado para terminar con exit code ≠0.
var _fallos: int = 0
var _guardados: int = 0


func _init() -> void:
	print("build_catalogo: generando el catálogo MVP de Pozuelo en '%s'..." % RUTA_CATALOGO)
	_asegurar_carpetas()
	_generar_tramites()      # F1 — 3 TramiteDoc
	_generar_denuncias()     # F2 — 13 DenunciaODAC
	_generar_puestos()       # F3 — 4 TipoPuesto
	_generar_salas()         # F4 — 4 TipoSala
	_generar_agentes()       # F5 — 3 TipoAgente
	_generar_costes()        # F6 — 1 Costes
	_generar_escenario()     # F7 — 1 Escenario

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


## F2 · Denuncias de ODAC (las 13). servicio="ODAC", tipo_puesto=puesto_odac, admite_cita=false (F2:
## las denuncias NO usan cita). Duración/prioridad de la tabla F2.
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


## F3 · Tipos de Puesto. superficie=1, plazas_agente=1 (defaults del esquema, coinciden con F3).
## `puesto_odac.atenciones_admitidas` = TODAS las denuncias (IDS_DENUNCIAS, misma lista que F2 → no diverge).
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
		puestos: Array, aforo: int, coste_eur: int) -> Resource:
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


# ── Guardado (con comprobación de error) ─────────────────────────────────────────────────

## Crea las carpetas del catálogo si faltan (DirAccess). Idempotente.
func _asegurar_carpetas() -> void:
	var base: DirAccess = DirAccess.open("res://")
	if base == null:
		push_error("build_catalogo: no se pudo abrir 'res://'.")
		quit(1)
		return
	base.make_dir_recursive("datos")
	for carpeta: String in ["tramites", "denuncias", "puestos", "salas", "agentes", "costes", "escenarios"]:
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
