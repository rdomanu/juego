class_name ConfigPersonal extends Resource
## ConfigPersonal — los tuning knobs de Personal (GDD staff-agents §Tuning Knobs), data-driven.
##
## Igual que `ConfigDemanda`: el `.tres` (`res://datos/config/personal.tres`) se genera SIEMPRE por
## herramienta (`tools/build_config_personal.gd`), nunca a mano. Personal lo carga con fallback seguro
## a estos defaults + clamp defensivo con aviso.
##
## Los salarios BASE (60/70) los posee el CATÁLOGO (`TipoAgente.salario_dia_eur`) — aquí solo primas.
##
## ⚠️ Erratilla del GDD anotada (story-001): la tabla Tuning da `k_motivacion=0.05` genérico, pero la
## fórmula F3 usa 0.1 → se separan en DOS knobs fieles a las fórmulas (F2: 0.05 · F3: 0.1).
##
## Story: production/epics/personal/story-001-agente-y-formulas.md · TR-staff-001 · ADR-0003

## Cuánto encarece la calidad el salario (F1): prima = 1 + k × (media_atributos − 3)/2. Semilla 0.5.
@export var k_calidad: float = 0.5
## Prima de rango del Oficial sobre el salario (F1). Semilla 1.3 (el mando cuesta más).
@export var prima_rango_oficial: float = 1.3
## Peso de la Rapidez en la duración efectiva (F2). Semilla 0.1 (crack 0.8× · torpe 1.2× antes de Mot).
@export var k_rapidez: float = 0.1
## Modulación de la Motivación sobre la Rapidez (F2). Semilla 0.05 (leve — MVP sin fatiga, PA10).
@export var k_motivacion_rapidez: float = 0.05
## Peso del Trato en el factor de satisfacción (F3). Semilla 0.25 (Trato 5 → ×1.5 · Trato 1 → ×0.5).
@export var k_trato: float = 0.25
## Modulación de la Motivación sobre el Trato (F3). Semilla 0.1 (leve).
@export var k_motivacion_trato: float = 0.1
## Probabilidad base de ausencia diaria a Salud media (F4). Semilla 0.03 (3 %).
@export var base_ausencia: float = 0.03
## Pendiente de la ausencia por punto de Salud (F4). Semilla 0.02 (Salud 1 → 7 % · Salud 5 → 0 %).
@export var k_salud: float = 0.02
## Coste de despedir (PA6). Semilla 0 (MVP: despido libre).
@export var coste_despido: float = 0.0

# ── Mercado de fichajes (story 002 — knobs ya definidos aquí, patrón ConfigDemanda) ──────────
## Candidatos que ofrece el mercado (F5). Semilla 4.
@export var n_candidatos: int = 4
## Jornadas entre regeneraciones completas del mercado (F5; decisión propuesta story-002). Semilla 3.
@export var refresco_mercado_jornadas: int = 3
## Probabilidad de que un candidato sea Oficial (decisión propuesta story-002 — el GDD no fija de
## dónde sale el Oficial; sin esto no habría forma de ficharlo). Semilla 0.2.
@export var prob_candidato_oficial: float = 0.2
## Pool de nombres para candidatos (Open Q5 del GDD: pool fijo español en el MVP; RNG elige de aquí).
@export var pool_nombres: Array[String] = [
	"Ana Ruiz", "Carlos Vega", "Lucía Ortega", "Javier Molina", "María Serrano", "Pablo Iglesias",
	"Carmen Duarte", "Sergio Navarro", "Elena Castro", "Miguel Herrera", "Laura Campos",
	"David Fuentes", "Sara Medina", "Andrés Pardo", "Isabel Rojas", "Óscar Delgado",
	"Nuria Blanco", "Raúl Cano", "Teresa Gil", "Hugo Márquez", "Silvia Peña", "Alberto Lara",
	"Patricia Soto", "Jorge Rivas",
]
