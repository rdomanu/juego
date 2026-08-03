extends Node2D
## DIAGNÓSTICO DESECHABLE — verifica EN EL MOTOR el arreglo de "sin camino ⇒ sin teletransporte"
## (bug reportado por el usuario 2026-08-03: *"las personas, si no pueden acceder a una sala porque
## hay paredes, SALTAN [se teletransportan]... podrías poner una señal de prohibido encima de sus
## cabezas"*).
##
## Escenario, con el CÓDIGO REAL (`Construccion`, `NPCsFlujo`, `NPCCiudadano`, `PersonaFlujo`): una
## sala de espera de 2×2 celdas con sus CUATRO muros levantados y SIN puerta (recinto sellado) +
## un ciudadano de Documentación cuyo destino lógico (`esperando_dentro`) cae dentro de esa sala.
##
##   Fase 0 (nace): el ciudadano detecta que no hay camino (BFS de `Construccion.
##                  distancia_en_celdas` vía `NPCsFlujo.hay_camino`) y se queda BLOQUEADO fuera de
##                  la sala, quieto, con la señal de prohibido sobre la cabeza.
##                  → captura 1: production/qa/evidence/bloqueo-navegacion-2026-08-03-bloqueado.png
##   Fase 1 (abre la puerta): se convierte un tramo de muro en PUERTA y se pide un rebake. El
##                  recheck periódico de `NPCCiudadano` (`FRAMES_RECHEQUEO_BLOQUEO`) lo detecta,
##                  el ciudadano entra andando y la señal desaparece.
##                  → captura 2: production/qa/evidence/bloqueo-navegacion-2026-08-03-desbloqueado.png
##
## Se borra tras usarlo — no es parte del pipeline final.

const ConstruccionScript := preload("res://src/core/construccion/construccion.gd")
const ConfigConstruccionScript := preload("res://src/core/construccion/config_construccion.gd")
const PersonalScript := preload("res://src/core/personal/personal.gd")
const ConfigPersonalScript := preload("res://src/core/personal/config_personal.gd")
const FlujoScript := preload("res://src/core/flujo/flujo.gd")
const PersonaScript := preload("res://src/core/demanda/persona.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")
const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")

const TAM_CELDA: int = 40
const COLUMNAS: int = 24
const FILAS: int = 13
## La sala sellada: 2×2 celdas, SIN puerta en ninguno de sus 4 lados.
const SALA_RECT := Rect2i(4, 2, 2, 2)
const CARPETA_EVIDENCIA := "res://production/qa/evidence/"

var _construccion: Node
var _npcs: Node2D
var _npc: Node
var _persona: RefCounted
var _fase: int = 0
var _frames_en_fase: int = 0
## Cuántos frames se espera tras nacer antes de comprobar/capturar el bloqueo (deja asentar el
## primer physics frame del NavigationServer + un par de frames de margen).
const FRAMES_ANTES_DE_CAPTURA_1: int = 20
## Tras abrir la puerta: FRAMES_RECHEQUEO_BLOQUEO (180, ver npcs_flujo.gd) + margen para que el
## ciudadano recorra a pie el último tramo hasta la sala antes de la 2ª captura.
const FRAMES_ANTES_DE_CAPTURA_2: int = 260


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA_EVIDENCIA)
	_construccion = ConstruccionScript.new()
	add_child(_construccion)
	_construccion.aplicar_config(ConfigConstruccionScript.new())
	var personal: Node = PersonalScript.new()
	add_child(personal)
	personal.aplicar_config(ConfigPersonalScript.new())
	_construccion.usar_personal(personal)
	var flujo: Node = FlujoScript.new()
	add_child(flujo)
	flujo.usar_personal(personal)
	flujo.usar_construccion(_construccion)

	# La sala sellada: se levanta y se amuralla ENTERA, sin abrir ningún hueco (mecanismo real de
	# Construcción — story flujo/ADR-0004, sin tocar su modelo).
	var ok_sala: bool = _construccion.construir_de_oficio_sala(&"sala_espera_doc", SALA_RECT) != &""
	print("[diag_bloqueo] sala creada: %s" % ok_sala)
	var muros_ok: bool = true
	for x: int in range(SALA_RECT.position.x, SALA_RECT.position.x + SALA_RECT.size.x):
		muros_ok = _construccion.construir_muro(Vector2i(x, SALA_RECT.position.y), &"arriba") and muros_ok
		muros_ok = _construccion.construir_muro(
			Vector2i(x, SALA_RECT.position.y + SALA_RECT.size.y - 1), &"abajo"
		) and muros_ok
	for y: int in range(SALA_RECT.position.y, SALA_RECT.position.y + SALA_RECT.size.y):
		muros_ok = _construccion.construir_muro(Vector2i(SALA_RECT.position.x, y), &"izquierda") and muros_ok
		muros_ok = _construccion.construir_muro(
			Vector2i(SALA_RECT.position.x + SALA_RECT.size.x - 1, y), &"derecha"
		) and muros_ok
	print("[diag_bloqueo] 8 muros levantados (sin puerta): %s" % muros_ok)

	_npcs = NPCsFlujoScript.new()
	add_child(_npcs)
	_npcs.configurar(flujo, _construccion, personal, TAM_CELDA, Vector2.ZERO, COLUMNAS, FILAS, null)

	var ficha: RefCounted = PersonaScript.new(&"Documentacion", &"dni", 0.0)
	_persona = PersonaFlujoScript.new(ficha, 1)
	_persona.estado = PersonaFlujoScript.ESTADO_ESPERANDO_DENTRO
	_npcs.spawn(_persona)
	# `spawn` añade el NPC como último hijo de `_capa_logica` ("PlanoLogico"): lo recuperamos por ahí
	# en vez de guardar la referencia de `spawn` (que no la devuelve — cosmético puro, FL5).
	var plano_logico: Node2D = _npcs.get_node("PlanoLogico")
	_npc = plano_logico.get_child(plano_logico.get_child_count() - 1)
	print("[diag_bloqueo] NPC creado en %s, destino lógico dentro de la sala sellada" % [_npc.position])

	# Cámara: encuadra a la vez el punto de la CALLE (donde el bloqueado se queda quieto en la fase
	# 0) y la sala sellada (su destino) — centrada solo en la sala, el bloqueado habría quedado FUERA
	# de cuadro en la 1ª captura y la evidencia no probaría nada. Punto medio en el plano CUADRADO
	# (`proyectar` es lineal: promediar antes o después da el mismo sitio) + zoom moderado para que
	# quepan los dos extremos.
	var centro_logico: Vector2 = Proyeccion.centro_cuadrado(
		SALA_RECT.position + SALA_RECT.size / 2
	)
	var punto_medio: Vector2 = (_npc.position + centro_logico) / 2.0
	var camara := Camera2D.new()
	camara.position = Proyeccion.proyectar(punto_medio)
	camara.zoom = Vector2(1.3, 1.3)
	add_child(camara)   # ⚠️ ORDEN: make_current() exige que la cámara YA esté en el árbol
	camara.make_current()


func _physics_process(_delta: float) -> void:
	_frames_en_fase += 1
	match _fase:
		0:
			if _frames_en_fase < FRAMES_ANTES_DE_CAPTURA_1:
				return
			var bloqueado: bool = bool(_npc.get(&"_bloqueado"))
			var icono_visible: bool = bool((_npc.get(&"_icono_bloqueo") as Node2D).visible)
			print(
				"[diag_bloqueo] FASE 0 — bloqueado=%s icono_visible=%s posicion=%s (dentro de la sala esperaría y≈%s)"
				% [bloqueado, icono_visible, _npc.position, SALA_RECT.position.y * TAM_CELDA]
			)
			_capturar("bloqueo")
			# Abre un hueco: convierte el muro norte de la sala en PUERTA (no se toca ningún otro
			# muro) y pide el rebake real de navegación (mismo hook que usa Main tras una obra).
			var abierto: bool = _construccion.fijar_tipo_de_muro(
				Vector2i(SALA_RECT.position.x, SALA_RECT.position.y), &"arriba", _construccion.PUERTA
			)
			_npcs.solicitar_rebake()
			print("[diag_bloqueo] puerta abierta: %s -> recheck periódico en marcha" % abierto)
			_fase = 1
			_frames_en_fase = 0
		1:
			if _frames_en_fase < FRAMES_ANTES_DE_CAPTURA_2:
				return
			var bloqueado: bool = bool(_npc.get(&"_bloqueado"))
			var icono_visible: bool = bool((_npc.get(&"_icono_bloqueo") as Node2D).visible)
			print(
				"[diag_bloqueo] FASE 1 — bloqueado=%s icono_visible=%s posicion=%s"
				% [bloqueado, icono_visible, _npc.position]
			)
			_capturar("desbloqueado")
			print("[diag_bloqueo] FIN — Exit 0")
			get_tree().quit(0)


func _capturar(sufijo: String) -> void:
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	var ruta: String = "%sbloqueo-navegacion-2026-08-03-%s.png" % [CARPETA_EVIDENCIA, sufijo]
	imagen.save_png(ruta)
	print("[diag_bloqueo] captura guardada: %s" % ruta)
