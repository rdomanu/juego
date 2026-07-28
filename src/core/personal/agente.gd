class_name Agente extends RefCounted
## Agente — la INSTANCIA de un miembro de la plantilla (PA1): identidad, rango, atributos y estado.
## CERO fórmulas: los cálculos con knobs (salario, modificadores, ausencia) los posee el nodo Personal.
##
## Referencia su `TipoAgente` del catálogo por id (ADR-0003: por id, nunca anidando Resources). Es un
## objeto de partida (RefCounted, patrón ficha `Persona` de Demanda) — se serializa en la story 006.
##
## Story: production/epics/personal/story-001-agente-y-formulas.md · TR-staff-001 · ADR-0003

## Rangos (PA2): el jugador es el Subinspector (no es plantilla); bajo él, Oficiales y Policías.
const RANGO_POLICIA := &"policia"
const RANGO_OFICIAL := &"oficial"

## Estados del agente (GDD §States; las transiciones las gobiernan las stories 003/004/005).
const ESTADO_LIBRE := &"libre"
const ESTADO_ASIGNADO := &"asignado"
const ESTADO_AUSENTE := &"ausente"
const ESTADO_CUBRIENDO := &"cubriendo"
## Está en la sala de descanso (Bienestar #13): su puesto NO atiende mientras tanto.
const ESTADO_DESCANSANDO := &"descansando"

## Nombre propio (identidad — Pilar 2: gente con nombre, no fichas anónimas).
var nombre: String = ""
## Id del `TipoAgente` del catálogo (salario base, `puestos_operables`).
var tipo_id: StringName = &""
## Rango: `RANGO_POLICIA` o `RANGO_OFICIAL`.
var rango: StringName = RANGO_POLICIA
## Atributos 1–5 (PA3; 3 = medio). Se CLAMPAN en el setter (edge del GDD: dato corrupto no rompe).
var rapidez: int = 3:
	set(valor):
		rapidez = clampi(valor, 1, 5)
var trato: int = 3:
	set(valor):
		trato = clampi(valor, 1, 5)
var salud: int = 3:
	set(valor):
		salud = clampi(valor, 1, 5)
var motivacion: int = 3:
	set(valor):
		motivacion = clampi(valor, 1, 5)
## 🎖️ Mando (PA3): SOLO Oficiales (1–5); en Policías es SIEMPRE 0 (lo fuerza el setter).
var mando: int = 0:
	set(valor):
		mando = clampi(valor, 1, 5) if rango == RANGO_OFICIAL else 0
## Estado actual (una de las constantes ESTADO_*).
var estado: StringName = ESTADO_LIBRE
## Puesto asignado (`&""` si no tiene). La titularidad se conserva durante una ausencia (story 004).
var puesto_id: StringName = &""

# ── Cansancio (Bienestar #13, story bien-001) ────────────────────────────────────────────────
## Lo cansado que está, 0-100. Sube SOLO mientras atiende: estar de brazos cruzados en una
## ventanilla vacía no cansa; despachar sin parar, sí. Al llegar a 100 se levanta y se va a
## descansar (story 002). Se reinicia cada jornada.
var cansancio: float = 0.0:
	set(valor):
		cansancio = clampf(valor, 0.0, 100.0)
## Pausas que ya se ha tomado HOY. Su patrón dice cuántas le tocan (una o dos): agotadas, aguanta
## hasta el cierre aunque la barra vuelva a llenarse.
var pausas_gastadas: int = 0


func _init(
	p_nombre: String = "", p_tipo_id: StringName = &"", p_rango: StringName = RANGO_POLICIA,
	p_rapidez: int = 3, p_trato: int = 3, p_salud: int = 3, p_motivacion: int = 3, p_mando: int = 0
) -> void:
	nombre = p_nombre
	tipo_id = p_tipo_id
	rango = p_rango
	rapidez = p_rapidez
	trato = p_trato
	salud = p_salud
	motivacion = p_motivacion
	mando = p_mando   # el setter fuerza 0 en Policías y clampa 1-5 en Oficiales


## Media de los 4 atributos comunes (alimenta la prima de calidad del salario — Personal F1).
func media_atributos() -> float:
	return float(rapidez + trato + salud + motivacion) / 4.0
