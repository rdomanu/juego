extends Node2D
## Main — ESQUELETO VISIBLE del juego de producción (Story 009 del epic Tiempo).
##
## Primera escena del juego: un suelo de rejilla (`TileMapLayer`) + un HUD provisional que hace VISIBLE
## el reloj (hora, fecha "Mes · Semana N", turno) con controles de velocidad (Pausa/1×/2×/3× + atajos
## Espacio/1/2/3). NO ES JUGABLE: sin construcción, sin ciudadanos, sin economía — es el andamio para
## ver latir el pulso del juego. Este HUD NO es el de UX (design/ux/hud.md se diseñará aparte).
##
## Reglas (control-manifest, Presentation): el HUD LEE el reloj (fuente única) y ORDENA la velocidad por
## la API pública (`Tiempo.fijar_velocidad`/`reanudar`); NUNCA muta su estado. El dibujo corre en
## `_process` (tiempo real); la simulación vive en `_physics_process` del autoload Tiempo (ADR-0001).
##
## Story: production/epics/tiempo/story-009-esqueleto-visible.md · ADR-0001 / ADR-0004 (TileMapLayer)

## Lado de cada celda de la rejilla, en píxeles (misma escala 40 px que validó el prototipo).
const TAM_CELDA: int = 40
## Dimensiones del suelo visible, en celdas (24×13 ≈ ventana por defecto 1152×648 con margen).
const COLUMNAS: int = 24
const FILAS: int = 13
## Paleta placeholder (suelo de comisaría sobrio; la línea marca la rejilla).
const COLOR_FONDO := Color(0.13, 0.14, 0.16)
const COLOR_SUELO := Color(0.22, 0.24, 0.27)
const COLOR_LINEA := Color(0.30, 0.32, 0.36)
const COLOR_BOTON_ACTIVO := Color(1.0, 0.85, 0.35)

## Nombres visibles de los turnos, indexados por el enum `Tiempo.Turno` (0/1/2).
const NOMBRES_TURNO: Array[String] = ["Mañana", "Tarde", "Noche"]
## Etiquetas de los botones de velocidad, indexadas por el enum `Tiempo.Velocidad` (0..3).
const NOMBRES_VELOCIDAD: Array[String] = ["⏸ Pausa", "1×", "2×", "3×"]

## Economía (Story 007 del epic economia): el primer sistema Core instanciado en el mundo (§3.4).
const EconomiaScript := preload("res://src/core/economia/economia.gd")
## Demanda (Story 007 del epic demanda): el grifo de la comisaría — genera las llegadas.
const DemandaScript := preload("res://src/core/demanda/demanda.gd")
## Plantilla inicial PROVISIONAL (dotación estándar del GDD: 2 ag_doc + 1 ag_odac = 190 €/jornada).
## HOOK de Personal: su epic la sustituirá por la dotación real contratada.
var PLANTILLA_INICIAL: Array[StringName] = [&"ag_doc", &"ag_doc", &"ag_odac"]
## Colores del estado financiero (placeholder sobrio; SIEMPRE acompañados de texto — accesibilidad).
const COLOR_HOLGADO := Color(0.55, 0.9, 0.55)
const COLOR_JUSTO := Color(1.0, 0.8, 0.35)
const COLOR_ROJOS := Color(0.95, 0.4, 0.4)

## Colores del nivel de demanda (DG12; SIEMPRE acompañados de texto — respaldo daltónico).
const COLORES_NIVEL: Dictionary[StringName, Color] = {
	&"BAJA": Color(0.55, 0.9, 0.55), &"MEDIA": Color(1.0, 0.8, 0.35), &"ALTA": Color(0.95, 0.4, 0.4),
}

var _lbl_hora: Label
var _lbl_fecha: Label
var _lbl_turno: Label
var _botones: Array[Button] = []
var _economia: Node
var _lbl_saldo: Label
var _lbl_estado_fin: Label
var _demanda: Node
var _lbl_llegadas: Label
var _lbl_nivel: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(COLOR_FONDO)
	_crear_suelo()
	_instanciar_mundo()
	_crear_hud()
	# El HUD reacciona a los avisos del bus (además del refresco continuo de _process): resaltado del
	# botón activo y refresco inmediato del turno/ciclo. La UI escucha; nunca muta (ADR-0001).
	EventBus.velocidad_cambiada.connect(_resaltar_boton)
	EventBus.cambio_de_turno.connect(func(_turno: int) -> void: _refrescar_etiquetas())
	EventBus.cambio_dia_noche.connect(func(_es_noche: bool) -> void: _refrescar_etiquetas())
	_resaltar_boton(Tiempo.velocidad_actual)
	_refrescar_etiquetas()
	_programar_captura_evidencia()


## El dibujo corre en tiempo real (_process, ADR-0001): refresca los textos leyendo el reloj.
func _process(_delta: float) -> void:
	_refrescar_etiquetas()


## Atajos de teclado: Espacio = pausa/reanuda; 1/2/3 = velocidades. La UI solo ORDENA por la API pública.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	match (evento as InputEventKey).keycode:
		KEY_SPACE:
			if Tiempo.velocidad_actual == Tiempo.Velocidad.PAUSA:
				Tiempo.reanudar()
			else:
				Tiempo.fijar_velocidad(Tiempo.Velocidad.PAUSA)
		KEY_1:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X1)
		KEY_2:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X2)
		KEY_3:
			Tiempo.fijar_velocidad(Tiempo.Velocidad.X3)


# ── El mundo (sistemas Core instanciados — arquitectura §3.4 paso 3) ─────────────────────────
## Instancia los sistemas Core del mundo. De momento: Economía (name "Economia" = su clave de save).
## Su _ready auto-resuelve los autoloads reales (bus/reloj), carga su config, se registra en el
## dispatcher (cobros nuevo_dia prio 20 / nuevo_mes prio 10) y entra al grupo Persist.
func _instanciar_mundo() -> void:
	_economia = EconomiaScript.new()
	_economia.name = "Economia"
	add_child(_economia)
	_economia.fijar_plantilla(PLANTILLA_INICIAL)
	# La ventana de gracia de insolvencia corre en MINUTOS DE JUEGO → la empuja el tick del reloj.
	Tiempo.suscribir_tick(_economia.avanzar_gracia)
	# Demanda (story demanda-007): su _ready se suscribe al tick, carga config + escenario (Pozuelo) y
	# entra a Persist. ORDEN ADR-0001: cuando existan Flujo/Paciencia deben instanciarse DESPUÉS de
	# Demanda (el tick se empuja en orden de suscripción: Tiempo → Demanda → Flujo → Paciencia).
	_demanda = DemandaScript.new()
	_demanda.name = "Demanda"
	add_child(_demanda)


# ── Suelo (TileMapLayer — NUNCA TileMap, deprecado) ──────────────────────────────────────────
## Crea el suelo: un TileSet mínimo generado por código (tile plano con borde de rejilla) y una
## rejilla COLUMNAS×FILAS pintada con set_cell. Solo estética; sin interacción de ratón (Construcción #7).
func _crear_suelo() -> void:
	var imagen := Image.create(TAM_CELDA, TAM_CELDA, false, Image.FORMAT_RGBA8)
	imagen.fill(COLOR_SUELO)
	for i in TAM_CELDA:
		imagen.set_pixel(i, 0, COLOR_LINEA)
		imagen.set_pixel(0, i, COLOR_LINEA)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = ImageTexture.create_from_image(imagen)
	fuente.texture_region_size = Vector2i(TAM_CELDA, TAM_CELDA)
	fuente.create_tile(Vector2i.ZERO)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TAM_CELDA, TAM_CELDA)
	var id_fuente: int = tileset.add_source(fuente)

	var suelo := TileMapLayer.new()
	suelo.name = "Suelo"
	suelo.tile_set = tileset
	# Centrado aproximado en la ventana por defecto (1152×648).
	suelo.position = Vector2(96, 64)
	for x in COLUMNAS:
		for y in FILAS:
			suelo.set_cell(Vector2i(x, y), id_fuente, Vector2i.ZERO)
	add_child(suelo)


# ── HUD provisional (construido por código, como el prototipo validado) ──────────────────────
## Panel arriba-izquierda: hora grande, fecha "Mes · Semana N — Año A", turno, y 4 botones de velocidad.
func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD"
	add_child(capa)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	capa.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	panel.add_child(caja)

	_lbl_hora = Label.new()
	_lbl_hora.add_theme_font_size_override("font_size", 30)
	caja.add_child(_lbl_hora)

	_lbl_fecha = Label.new()
	caja.add_child(_lbl_fecha)

	_lbl_turno = Label.new()
	caja.add_child(_lbl_turno)

	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 6)
	caja.add_child(fila_botones)
	for indice in NOMBRES_VELOCIDAD.size():
		var boton := Button.new()
		boton.text = NOMBRES_VELOCIDAD[indice]
		# Gotcha del prototipo: sin esto, Espacio "pulsa" el botón enfocado en vez de pausar.
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(func() -> void: Tiempo.fijar_velocidad(indice as Tiempo.Velocidad))
		fila_botones.add_child(boton)
		_botones.append(boton)

	# Bloque financiero (Story 007 del epic economia): saldo + estado, SOLO lectura.
	caja.add_child(HSeparator.new())
	_lbl_saldo = Label.new()
	_lbl_saldo.add_theme_font_size_override("font_size", 22)
	caja.add_child(_lbl_saldo)
	_lbl_estado_fin = Label.new()
	_lbl_estado_fin.add_theme_font_size_override("font_size", 12)
	caja.add_child(_lbl_estado_fin)

	# Bloque de demanda (story demanda-007): llegadas del día + nivel BAJA/MEDIA/ALTA, SOLO lectura.
	caja.add_child(HSeparator.new())
	_lbl_llegadas = Label.new()
	_lbl_llegadas.add_theme_font_size_override("font_size", 16)
	caja.add_child(_lbl_llegadas)
	_lbl_nivel = Label.new()
	_lbl_nivel.add_theme_font_size_override("font_size", 12)
	caja.add_child(_lbl_nivel)

	var nota := Label.new()
	nota.text = "Esqueleto visible — no jugable (HUD provisional) · Espacio pausa · 1/2/3 velocidad"
	nota.add_theme_font_size_override("font_size", 11)
	nota.modulate = Color(1, 1, 1, 0.55)
	caja.add_child(nota)


## Refresca hora/fecha/turno LEYENDO el reloj (fuente única; jamás se escribe en él) y el saldo
## LEYENDO Economía (la UI lee y ordena, nunca muta — ADR-0001).
func _refrescar_etiquetas() -> void:
	_lbl_hora.text = Tiempo.hhmm(Tiempo.minutos_juego)
	_lbl_fecha.text = "Mes %d · Semana %d — Año %d" % [Tiempo.mes, Tiempo.semana, Tiempo.anio]
	_lbl_turno.text = "Turno: %s" % NOMBRES_TURNO[Tiempo.turno_de(Tiempo.minutos_juego)]
	if _economia == null or _lbl_saldo == null:
		return
	var saldo: float = _economia.saldo_eur
	_lbl_saldo.text = "%.2f €" % saldo
	if saldo < 0.0:
		_lbl_saldo.modulate = COLOR_ROJOS
		_lbl_estado_fin.text = "Estado: NÚMEROS ROJOS (gasto bloqueado)"
		_lbl_estado_fin.modulate = COLOR_ROJOS
	elif saldo < _economia.umbral_holgura_ui:
		_lbl_saldo.modulate = COLOR_JUSTO
		_lbl_estado_fin.text = "Estado: justo"
		_lbl_estado_fin.modulate = COLOR_JUSTO
	else:
		_lbl_saldo.modulate = COLOR_HOLGADO
		_lbl_estado_fin.text = "Estado: holgado"
		_lbl_estado_fin.modulate = COLOR_HOLGADO
	if _demanda == null or _lbl_llegadas == null:
		return
	_lbl_llegadas.text = "Llegadas hoy: %d" % _demanda.llegadas_hoy
	var nivel: StringName = _demanda.nivel_demanda()
	_lbl_nivel.text = "Demanda Doc: %s" % nivel
	_lbl_nivel.modulate = COLORES_NIVEL.get(nivel, Color.WHITE)


## Resalta el botón de la velocidad activa (dorado) y apaga el resto. Oyente de `velocidad_cambiada`.
func _resaltar_boton(indice: int) -> void:
	for i in _botones.size():
		_botones[i].modulate = COLOR_BOTON_ACTIVO if i == indice else Color.WHITE


# ── Evidencia ADVISORY de la story (solo en desarrollo, nunca en build exportada) ────────────
## A los 2 s de correr, guarda una captura del viewport en production/qa/evidence/ (la evidencia
## Visual/UI de la Story 009). Solo corre en entorno de desarrollo (feature "editor"); se retirará
## cuando el HUD real de UX sustituya a este andamio.
func _programar_captura_evidencia() -> void:
	if not OS.has_feature("editor"):
		return
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute("res://production/qa/evidence")
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://production/qa/evidence/demanda-hud-2026-07-23.png")
	)
