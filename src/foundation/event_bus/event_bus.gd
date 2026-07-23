extends Node
## EventBus — el tablon de anuncios global del juego (autoload "EventBus", el PRIMERO).
##
## Comunicacion cross-system DESACOPLADA: los emisores publican senales con `.emit()` y
## los interesados escuchan con `.connect(Callable)`. El bus SOLO retransmite: no contiene
## logica de juego ni llama a los sistemas por nombre (respeta las capas estrictas — ADR-0001).
##
## La lista CENTRAL de senales se documenta aqui (mitiga la baja descubribilidad del patron bus:
## "quien escucha este evento" se busca en el codigo, asi que la referencia vive junta y comentada).
##
## El dispatcher de eventos ordenados (`registrar_ordenado`/`disparar_ordenado`) es la Story 002.
##
## Story: production/epics/event-bus/story-001-autoload-senales-aviso.md (TR-bus-001) · ADR-0001

# ── Senales de aviso (el orden entre oyentes es indiferente) ──────────────────────────
## Un tramite (DNI, denuncia...) se ha completado en un puesto. Emisor: Flujo. Oyentes: Economia
## (cobra), Paciencia (cierra visita), Feedback (juice).
signal tramite_completado(tramite_id: StringName, agente)

## Una persona abandona la cola sin ser atendida. Emisor: Flujo/Paciencia. Oyentes: Feedback, contadores.
signal abandono(persona)

## Demanda ha generado una nueva persona que entra en la comisaria. Emisor: Demanda. Oyente: Flujo.
signal persona_generada(persona)

## Cambia el turno del dia (0=manana, 1=tarde, 2=noche). Emisor: Tiempo.
signal cambio_de_turno(turno: int)

## Cambia el ciclo dia/noche (true = es de noche). Emisor: Tiempo.
signal cambio_dia_noche(es_de_noche: bool)

## Cambia la velocidad de la simulacion (indice del enum Velocidad: 0=PAUSA, 1=X1, 2=X2, 3=X3).
## Emisor: Tiempo (maquina de velocidad, Story 006). Oyentes: UI/HUD (resalta el boton activo),
## Feedback. Se emite UNA vez por accion efectiva (solo cuando el indice CAMBIA). Story 006 · TR-time-002.
signal velocidad_cambiada(indice: int)

## El saldo de la comisaria ha cambiado. Emisor: Economia. Oyentes: UI, Feedback.
## (Enmienda 2026-07-23, epic economia story 001: int -> float — el dinero tiene decimales, GDD F2.)
signal saldo_cambiado(nuevo_saldo: float)

## Se ha pedido un prestamo del Comisario (E9): inyeccion + strike. Emisor: Economia. Oyentes: UI
## (contador de salvavidas restantes), Feedback. (Ampliacion 2026-07-23, epic economia story 004.)
signal prestamo_pedido(usados: int, vivos: int)

## El saldo ha entrado en numeros rojos (saldo < 0): gasto voluntario bloqueado, recargo diario activo.
## Emisor: Economia. Oyentes: UI (alerta), Feedback. (Ampliacion 2026-07-23, epic economia story 005.)
signal entro_en_deuda(saldo: float)

## El saldo ha vuelto a positivo (>= 0). Emisor: Economia. Oyentes: UI, Feedback. (Story 005.)
signal salio_de_deuda(saldo: float)

## El saldo ha tocado el suelo de insolvencia con prestamos disponibles: el juego se pausa y la UI debe
## mostrar el modal del Comisario (aceptar_rescate/rechazar_rescate). Emisor: Economia. (Story 005.)
signal insolvencia(saldo: float, prestamos_restantes: int)

## El jugador rechazo el rescate: arranca la ventana de gracia (minutos de JUEGO restantes). (Story 005.)
signal gracia_iniciada(minutos: float)

## Derrota terminal (E9): insolvencia sin salvavidas — te echan de la comisaria. Emisor: Economia.
## Oyentes: UI (pantalla de fin), Feedback. (Story 005.)
signal game_over(motivo: StringName)

## Se ha generado una reclamacion (p. ej. por un abandono en Documentacion). Emisor: Paciencia.
## Oyentes: ODAC (recibe la carga), Feedback.
signal reclamacion_generada(origen: StringName)

# ── Senales de notificacion (se emiten TRAS el orden critico → dispatcher de la Story 002) ──────
## Empieza un nuevo dia. Para oyentes NO criticos (UI refresca, Feedback). El orden critico
## (Paciencia cierra sat -> Economia cobra -> Personal ausencias -> Demanda reset) va por
## `disparar_ordenado(&"nuevo_dia")` (Story 002), NO por esta senal.
signal nuevo_dia

## Empieza un nuevo mes. Idem: para oyentes no criticos; el orden critico va por dispatcher.
signal nuevo_mes


# ── Dispatcher de eventos ordenados (Story 002 · TR-bus-002 · ADR-0001) ──────────────────
## Algunos eventos exigen que sus oyentes corran en un ORDEN FIJO (p. ej. al `nuevo_dia`:
## Paciencia cierra `sat` (10) -> Economia cobra (20) -> Personal ausencias (30) -> Demanda
## reset (40)). Godot NO garantiza el orden entre `connect` sueltos de autoloads distintos, asi
## que se usa un registro con prioridad: cada sistema llama `registrar_ordenado(...)` y el disparo
## invoca los callables por prioridad ascendente. El bus NO conoce los sistemas (solo callables) →
## respeta las capas estrictas (Foundation no depende de Core/Feature).

## Por evento (StringName) -> Array de entradas {prioridad:int, orden:int, cb:Callable}.
var _ordenados: Dictionary = {}
## Contador global de registro: fuerza un desempate ESTABLE y determinista entre prioridades iguales.
var _contador_registro: int = 0


## Registra un `callable` para que corra al disparar `evento`, en orden de `prioridad` ascendente.
## Prioridades espaciadas (10/20/30/40) para dejar hueco a inserciones futuras sin renumerar.
func registrar_ordenado(evento: StringName, prioridad: int, cb: Callable) -> void:
	if not _ordenados.has(evento):
		_ordenados[evento] = []
	_ordenados[evento].append({"prioridad": prioridad, "orden": _contador_registro, "cb": cb})
	_contador_registro += 1


## Invoca, en orden de prioridad ascendente (desempate por orden de registro), todos los callables
## registrados para `evento`; luego emite la senal de notificacion homonima para los oyentes NO
## criticos (UI/Feedback). Determinista: misma configuracion -> mismo orden, siempre.
func disparar_ordenado(evento: StringName) -> void:
	if _ordenados.has(evento):
		var lista: Array = (_ordenados[evento] as Array).duplicate()
		lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["prioridad"] == b["prioridad"]:
				return a["orden"] < b["orden"]   # desempate estable por orden de registro
			return a["prioridad"] < b["prioridad"])  # prioridad ascendente
		for entrada in lista:
			var cb: Callable = entrada["cb"]
			if cb.is_valid():
				cb.call()
	# Tras el orden critico, notificar a los oyentes no criticos (orden entre ellos indiferente):
	if evento == &"nuevo_dia":
		nuevo_dia.emit()
	elif evento == &"nuevo_mes":
		nuevo_mes.emit()
