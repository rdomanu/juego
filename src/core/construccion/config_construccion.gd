class_name ConfigConstruccion extends Resource
## ConfigConstruccion — los tuning knobs de Construcción (GDD construction-layout §Tuning Knobs).
##
## Igual que `ConfigPersonal`: el `.tres` (`res://datos/config/construccion.tres`) se genera SIEMPRE
## por herramienta (`tools/build_config_construccion.gd`), nunca a mano. Construcción lo carga con
## fallback seguro a estos defaults + clamp defensivo con aviso.
##
## Los costes BASE de salas y puestos los posee el CATÁLOGO (`TipoSala`/`TipoPuesto`
## `.coste_construccion_eur`) — aquí solo los knobs propios (por-celda, densidad, reembolso...).
##
## ⚠️ Decisión propuesta (story-001): el TAMAÑO DEL EDIFICIO vive aquí en el MVP (una sola
## comisaría); migrará a `Escenario` cuando haya multi-comisaría (#26).
##
## Story: production/epics/construccion/story-001-nucleo-rejilla-validacion.md · TR-construction-001 · ADR-0004

## Coste por celda de área al dibujar una sala (F1) — hace que sobredimensionar tenga precio. Semilla 20.
@export var coste_por_celda: float = 20.0
## Plazas de asiento que caben por celda de sala de espera (F3) — deja hueco para pasillos. Semilla 0.7.
@export var densidad_asientos: float = 0.7
## Personas DE PIE que caben por celda de sala de espera (ENMIENDA F3, flujo-005: sin asiento se
## entra igual — el asiento será confort cuando llegue Paciencia #10). Semilla 0.5.
@export var densidad_de_pie: float = 0.5
## Fracción del coste pagado que se devuelve al demoler (F4). Semilla 0.5.
@export var pct_reembolso: float = 0.5
## Área mínima de una sala, en celdas (CO3). Semilla 4 (2×2).
@export var area_min_sala: int = 4
## Coste de mover un elemento ya construido (CO8). Semilla 0 (reorganizar no penaliza — Pilar 4).
@export var coste_mover: float = 0.0
## Coste del asiento básico (F2; el catálogo no lo lista — MVP semilla de Comodidades #15). Semilla 25.
@export var coste_asiento_basico: float = 25.0

## Lo que cuesta UN TRAMO de muro (el lado de una celda). Los muros se pintan libremente
## (decisión del usuario 2026-07-30: *"la construcción de las paredes debe ser libre y luego dentro
## poner las zonas además de las puertas y ventanas"*), así que tienen que costar algo: si fueran
## gratis, cerrarlo todo siempre seria la jugada obvia y no habria decision que tomar. 15 € es
## barato a proposito — el precio no es el freno, el freno es el espacio que te comen y el rodeo
## que obligan a dar.
@export var coste_muro: float = 15.0
## Tamaño del edificio en celdas (CO1; Pozuelo = el suelo 24×13 del esqueleto — dimensionado R5).
@export var edificio_columnas: int = 24
@export var edificio_filas: int = 13
