class_name ConfigDemanda extends Resource
## ConfigDemanda — los tuning knobs de Demanda (GDD demand-generation §Tuning Knobs), data-driven.
##
## Igual que `ConfigEconomia`: un Resource tipado cuyo `.tres` (`res://datos/config/demanda.tres`) se
## genera SIEMPRE por herramienta (`tools/build_config_demanda.gd`), nunca a mano. Demanda lo carga al
## entrar en escena con fallback seguro a estos defaults + clamp defensivo con aviso.
##
## La `poblacion` NO vive aquí: la posee el `Escenario` del catálogo (Datos) — cada comisaría tiene la
## suya (petición del usuario 2026-07-23: población variable, tasas ajustables sin tocar código).
##
## ⚠️ Errata del GDD anotada (story-001): la tabla Tuning dice `tasa_base_odac` 0.5, pero F1/AC-DM02/F5
## usan 0.4 (→ 36/día). Se implementa 0.4. Propagar al GDD cuando se toque.
##
## Story: production/epics/demanda/story-001-nucleo-config-volumen.md · TR-demand-001 · ADR-0003

## Llegadas de Documentación por 1.000 hab/día (F1). Semilla 0.5 → 45/día en Pozuelo (90.000 hab).
@export var tasa_base_doc: float = 0.5
## Llegadas de ODAC por 1.000 hab/día (F1). Semilla 0.4 → 36/día en Pozuelo (menos que Doc, y más largas).
@export var tasa_base_odac: float = 0.4
## Perfil intradía de Documentación (F2): fracción de la demanda diaria por hora de inicio de franja.
## Front-loaded (pico a la apertura 08:00). La franja 14 dura SOLO 30 min (hasta el cierre 14:30). Σ = 1.0.
@export var perfil_hora_doc: Dictionary[int, float] = {
	8: 0.30, 9: 0.22, 10: 0.16, 11: 0.12, 12: 0.10, 13: 0.07, 14: 0.03,
}
## Perfil intradía de ODAC (F2): fracción por hora, 24 h. Semilla UNIFORME (1/24 por hora; el matiz
## "decae 22-23h" es tuning fino — Open Q2/Q5); el valle nocturno lo crea `mult_nocturno_odac` en
## runtime, NO estos pesos. Σ = 1.0. Se rellena en `_init` (uniforme programático > 24 líneas a mano).
@export var perfil_hora_odac: Dictionary[int, float] = {}
## Reduce el peso horario de ODAC en la franja 00:00–07:00 (valle nocturno, F2/DG3). Rango 0.2–1.0.
## La salida (≈5 denuncias nocturnas en Pozuelo) es DERIVADA: escala con la población del escenario.
@export var mult_nocturno_odac: float = 0.5
## Multiplicador de carga de la jornada (F2). Con el calendario semanal, cada jornada = 1 semana;
## default 1.0 (la variación gruesa la llevan la estacionalidad DG13 y los eventos DG11).
@export var mult_dia_semana: float = 1.0
## Tope de ráfaga anti-avalancha (F4/DG5): máximo de Personas generadas por tick. Rango 1–10.
@export var max_llegadas_por_tick: int = 3
## Escala de la tasa base por nivel/rango (DG8). 1.0 en el MVP (Nivel 1); Ascensos lo subirá.
@export var factor_crecimiento_nivel: float = 1.0
## Ventana de apertura de Documentación en minutos del día (DG6): [inicio, fin). 480 = 08:00, 870 = 14:30.
## PROVISIONAL: la ventana la poseerá Documentación #8 (peonada amplía el cierre); Demanda la consulta.
@export var ventana_doc_inicio_min: int = 480
@export var ventana_doc_fin_min: int = 870
## Mezcla de trámites de Documentación (F3): peso de cada `TramiteDoc` del catálogo. Σ = 1.0.
@export var mezcla_doc: Dictionary[StringName, float] = {
	&"dni": 0.45, &"pasaporte": 0.35, &"tie": 0.20,
}
## Mezcla de denuncias de ODAC (F3): peso de cada `DenunciaODAC` del catálogo (13 tipos; las 4
## Prioritarias raras suman 0.13). Σ = 1.0. (`reclamacion` NO está: la inyecta Paciencia, no el grifo.)
@export var mezcla_odac: Dictionary[StringName, float] = {
	&"hurto_robo": 0.18, &"estafa": 0.15, &"perdida_sustraccion": 0.12, &"ciberestafa": 0.10,
	&"danos": 0.09, &"lesiones": 0.07, &"amenazas": 0.07, &"okupacion": 0.05,
	&"permiso_viaje": 0.04, &"robo_violencia": 0.04, &"viogen": 0.04, &"desaparecidos": 0.03,
	&"agresion_sexual": 0.02,
}
## Umbrales del nivel de demanda BAJA/MEDIA/ALTA (DG12, story 004; Open Q9 — provisionales):
## demanda diaria efectiva de Doc < bajo → BAJA · ≥ alto → ALTA · resto → MEDIA.
## Con las semillas: 45 → MEDIA · verano 67.5 → ALTA · enero 27 → BAJA (los 3 tramos alcanzables).
@export var umbral_nivel_bajo: float = 40.0
@export var umbral_nivel_alto: float = 60.0
## Multiplicador estacional por mes sobre la demanda de Documentación (DG13, story 005). Determinista:
## Jun/Jul/Ago y Dic ×1.5 (verano/Navidad) · Ene/Feb ×0.6 · resto ×1.0.
@export var mult_estacional: Dictionary[int, float] = {
	1: 0.6, 2: 0.6, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.5,
	7: 1.5, 8: 1.5, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.5,
}
## Eventos de demanda multi-día (DG11, story 005; catálogo = tuning, Open Q8). Cada evento:
## { "id": StringName, "meses_inicio": Array[int], "duracion_jornadas": int,
##   "mult_peso": Dictionary[StringName, float] (multiplica el peso de mezcla de esos trámites) }.
@export var eventos: Array[Dictionary] = [
	{
		"id": &"vacaciones",
		"meses_inicio": [6, 12],
		"duracion_jornadas": 3,
		"mult_peso": {&"pasaporte": 2.0, &"permiso_viaje": 3.0},
	},
]


func _init() -> void:
	# Perfil ODAC uniforme programático (24 × 1/24). Corre ANTES de que el loader aplique las
	# propiedades del .tres → un perfil personalizado guardado lo sobreescribe sin conflicto.
	if perfil_hora_odac.is_empty():
		for hora: int in range(24):
			perfil_hora_odac[hora] = 1.0 / 24.0
