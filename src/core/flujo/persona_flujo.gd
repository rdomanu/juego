class_name PersonaFlujo extends RefCounted
## PersonaFlujo — una Persona DENTRO del flujo (FL1): la ficha de Demanda envuelta (referencia, no
## copia — decisión ratificada en demanda-002) + el turno, el estado de la máquina de 7 y el hueco
## de paciencia (Paciencia #10 lo poblará — stub en el MVP).
##
## CERO lógica de movimiento: el estado es la VERDAD (FL5 — el NPC visible de la story 008 lo
## observa; jamás al revés). Las transiciones las gobierna el nodo Flujo (tabla de válidas).
##
## Story: production/epics/flujo/story-001-persona-estados-turnos.md · TR-flow-001 · ADR-0001

## Estados de la Persona (GDD §States A; los mueve Flujo — el abandono lo dispara Paciencia).
const ESTADO_LLEGANDO := &"llegando"
const ESTADO_ESPERANDO_FUERA := &"esperando_fuera"
const ESTADO_ESPERANDO_DENTRO := &"esperando_dentro"
const ESTADO_LLAMADA := &"llamada"
const ESTADO_EN_ATENCION := &"en_atencion"
const ESTADO_RESUELTA := &"resuelta"
const ESTADO_ABANDONANDO := &"abandonando"

## La ficha de Demanda (Persona: servicio / tramite_id / minuto_llegada) — REFERENCIA compartida.
var ficha: RefCounted = null
## Número de turno (FL2): único y creciente por servicio; lo asigna Flujo al admitir. Nunca se reusa.
var numero_turno: int = 0
## Estado actual (una de las constantes ESTADO_*).
var estado: StringName = ESTADO_LLEGANDO
## Referencia de paciencia (Paciencia #10 — stub null en el MVP; AC-FL01 exige el hueco).
var paciencia: RefCounted = null


func _init(p_ficha: RefCounted = null, p_numero_turno: int = 0) -> void:
	ficha = p_ficha
	numero_turno = p_numero_turno


## Atajos de lectura sobre la ficha (evitan `persona.ficha.servicio` por todo el código).
func servicio() -> StringName:
	return ficha.servicio if ficha != null else &""


func tramite_id() -> StringName:
	return ficha.tramite_id if ficha != null else &""
