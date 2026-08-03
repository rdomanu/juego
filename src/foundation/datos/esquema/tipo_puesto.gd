class_name TipoPuesto extends Resource
## TipoPuesto — definición (read-only) de un tipo de puesto de trabajo de la comisaría.
##
## Un puesto es la estación donde un agente despacha `Atencion`es (p. ej. "puesto de Documentación general").
## Referencia las atenciones que admite por `id` (`Array[StringName]`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Servicio del puesto. A diferencia de `Atencion`, aquí SÍ existe "Seguridad" (puesto_seguridad, GDD F3).
@export_enum("Documentacion", "ODAC", "Seguridad") var servicio: String
## `id`s de las `Atencion`es que este puesto puede despachar (referencias por id, no Resources anidados).
@export var atenciones_admitidas: Array[StringName]
## Si el puesto puede reconfigurarse (cambiar de servicio/atenciones) tras construirse.
@export var reconfigurable: bool
## Coste de construcción del puesto, en euros.
@export var coste_construccion_eur: int
## Nº de agentes que pueden operar el puesto simultáneamente. Default 1 (mínimo operable).
@export var plazas_agente: int = 1
## Superficie que ocupa en la rejilla A LO ANCHO (el largo del mostrador), en celdas. Default 1.
@export var superficie: int = 1
## Filas que el puesto RESERVA DETRÁS del mostrador: el sitio del funcionario (su silla). Default 1.
##
## ── LA HUELLA DEL PUESTO ES 2×3 (decisión del usuario, 2026-08-03) ──────────────────────────
## *"vamos a tratar los 3 elementos como 1 solo: la silla del ciudadano, la mesa y la silla del
## policía; 6 cuadrículas en total, 2×3"*. Una ventanilla se coloca y se demuele como UNA cosa, así
## que reserva el bloque entero: `superficie` (2) × (`fondo_detras` + 1 + `fondo_delante`) (3) = 6.
##
## El default es 1 y no 0 porque **todo puesto de esta comisaría es una ventanilla con su silla
## detrás y su silla delante** — es la definición del objeto, no una excepción de uno. Un `.tres`
## puede bajarlo a 0 (un mostrador corrido sin sitio de espera) sin tocar código.
##
## ⚠️ Reservar NO es bloquear: las filas de las sillas siguen siendo PISABLES (si no, nadie podría
## llegar andando a sentarse). Quien decide eso es `Construccion.celdas_obstaculo_de`.
@export var fondo_detras: int = 1
## Filas que el puesto RESERVA DELANTE del mostrador: el sitio del ciudadano. Ver `fondo_detras`.
@export var fondo_delante: int = 1
## Icono para la UI.
@export var icono: Texture2D
