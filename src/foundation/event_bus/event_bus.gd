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

## El saldo de la comisaria ha cambiado. Emisor: Economia. Oyentes: UI, Feedback.
signal saldo_cambiado(nuevo_saldo: int)

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
