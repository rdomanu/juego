extends Node2D
## DIAGNÓSTICO DESECHABLE (GPU, no headless) — planta 20 ciudadanos (10 de pie + 10 sentados) con
## `numero_turno` distintos y comprueba que `NPCCiudadano._prefijo_de` (selección determinista de los
## 21 prefijos `civil_*` — 7 modelos + 14 variantes de color, story 2026-08-04) reparte de verdad
## entre varios prefijos, no siempre el mismo. Usa la MISMA función que el juego (no una
## reimplementación aparte, para no divergir).
## Imprime por consola el turno -> prefijo de cada uno y cuántos prefijos DISTINTOS salieron, y
## guarda una captura de la ventana en el scratchpad de la sesión para verlo a ojo.
## Se borra tras usarlo — no es parte del pipeline final.

const SALIDA_CAPTURA := "C:/Users/manur/AppData/Local/Temp/claude/C--Users-manur-juego/97b28cec-f535-4ea2-8bd3-af9a5b118451/scratchpad/ciudadanos_variedad_21.png"
const MunecoScript := preload("res://src/main/muneco.gd")
const NPCCiudadanoScript := preload("res://src/main/npc_ciudadano.gd")
const PersonaFlujoScript := preload("res://src/core/flujo/persona_flujo.gd")

## 20 (2026-08-04, ampliado de 10 a 21 prefijos posibles: con 10 turnos casi nunca se veían todos los
## modelos nuevos, solo una muestra) -- turnos 0..19 cubren casi todo el ciclo de 21 sin repetir ninguno.
const N_CIUDADANOS: int = 20
const ALTO_SPRITE: int = 44


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.55, 0.58, 0.6)
	fondo.size = Vector2(1900, 900)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	# La MISMA selección que usa el juego de verdad: una instancia real de NPCCiudadano (sin montar
	# en el árbol, no hace falta: `_prefijo_de` solo mira `persona.numero_turno`).
	var npc_para_elegir := NPCCiudadanoScript.new()

	var mitad: int = N_CIUDADANOS / 2
	var prefijos_vistos: Dictionary = {}
	for i: int in N_CIUDADANOS:
		var turno: int = i
		var persona: RefCounted = PersonaFlujoScript.new(null, turno)
		var prefijo: String = npc_para_elegir._prefijo_de(persona)
		prefijos_vistos[prefijo] = true
		var sentado: bool = i >= mitad
		var col: int = i % mitad
		var x: float = 100.0 + col * 180.0
		var y: float = 220.0 if not sentado else 620.0
		var muneco: Node2D
		if MunecoScript.hay_sprites(prefijo, ALTO_SPRITE):
			if sentado:
				muneco = MunecoScript.construir_sprite_sentado(prefijo, ALTO_SPRITE, Vector2(0.0, 1.0))
			else:
				muneco = MunecoScript.construir_sprite(prefijo, ALTO_SPRITE)
		else:
			muneco = Node2D.new()
			muneco.add_child(MunecoScript.construir(Color(0.7, 0.2, 0.2), false, MunecoScript.PIEL))
			push_warning("_diag_ciudadanos_variedad: %s SIN sprites -> muñeco de piezas" % prefijo)
		muneco.position = Vector2(x, y)
		add_child(muneco)

		var etiqueta := Label.new()
		etiqueta.text = "turno %d\n%s\n%s" % [turno, prefijo, "sentado" if sentado else "de pie"]
		etiqueta.position = Vector2(x - 45, y - 110)
		etiqueta.size = Vector2(90, 50)
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.add_theme_color_override("font_color", Color.BLACK)
		add_child(etiqueta)

		print("[VARIEDAD] turno %d (%s) -> %s" % [turno, "sentado" if sentado else "de pie", prefijo])

	npc_para_elegir.free()   # CharacterBody2D nunca montado en el árbol: liberarlo a mano (si no, RID leak)

	print("[VARIEDAD] prefijos DISTINTOS: %d -> %s" % [prefijos_vistos.size(), prefijos_vistos.keys()])
	if prefijos_vistos.size() >= 4:
		print("[VARIEDAD] OK: >= 4 prefijos distintos")
	else:
		push_error("[VARIEDAD] FALLO: menos de 4 prefijos distintos")

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SALIDA_CAPTURA.get_base_dir())
	imagen.save_png(SALIDA_CAPTURA)
	print("[VARIEDAD] captura guardada en %s" % SALIDA_CAPTURA)
	get_tree().quit()
