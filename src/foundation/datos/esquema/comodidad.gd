class_name Comodidad extends Resource
## Comodidad — un objeto que el jugador **compra y coloca** dentro de una sala (Comodidades #15).
##
## Dos familias, mismo catálogo y mismo modo de colocarse:
##   • **ciudadano**  — va en salas de **espera** y aporta **confort**: la gente aguanta más antes de
##     largarse (baja el `mult_comodidad` de Paciencia F1).
##   • **funcionario** — va en salas con **puestos** y aporta **rendimiento**: se atiende más rápido
##     (baja la duración efectiva de Flujo F1).
##
## El `aporte` es un número **abstracto** a propósito: cada sistema decide qué hace con él (ADR-0001).
## Construcción solo suma los aportes de cada sala; Paciencia y Flujo los convierten con SU fórmula.
##
## Solo estructura (`@export`): CERO lógica.
##
## Story: production/epics/comodidades/story-001-catalogo-y-confort-de-sala.md · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Qué hace, en una línea, para el menú de compra.
@export var descripcion: String
## A quién beneficia: "ciudadano" (confort de la espera) o "funcionario" (rendimiento del puesto).
@export_enum("ciudadano", "funcionario") var familia: String
## Precio de compra, en euros (lo cobra Construcción por el gate E4 de Economía).
@export var coste_construccion_eur: int
## Lo que cuesta tenerlo encendido cada jornada. **0 = no consume** (papelera, revistero): se paga una
## vez y ya. Los aparatos (radio, tele, vending, equipos) sí sangran cada día.
@export var coste_mantenimiento_dia_eur: int = 0
## Cuánto aporta a su familia (confort o rendimiento). Se SUMA con el resto de objetos de la sala.
@export var aporte: float = 1.0
## Celdas que ocupa (como el resto de elementos colocables). 1 en todo el catálogo semilla.
@export var superficie: int = 1
