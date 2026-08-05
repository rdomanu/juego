class_name TipoSala extends Resource
## TipoSala — definición (read-only) de un tipo de sala/área de la comisaría.
##
## Una sala agrupa puestos y/o gestiona espera (GDD F4: sala de espera vs área lógica/oficina). Referencia
## los puestos que admite por `id` (`Array[StringName]`), NUNCA anidando Resources (ADR-0003).
##
## Solo estructura (`@export`): CERO lógica. Carga en Story 002, contenido en Story 004.
##
## Story: production/epics/datos/story-001-esquema-clases-resource.md (TR-data-002) · ADR-0003

## Identificador único de la definición (clave de lookup en el autoload Datos — Story 002).
@export var id: StringName
## Nombre visible (UI).
@export var nombre: String
## Rol de la sala: "espera" (aloja ciudadanos en cola) u "oficina" (área lógica que agrupa puestos). GDD F4.
## "espera" (aloja ciudadanos en cola) · "oficina" (agrupa puestos) · "descanso" (donde los
## funcionarios se toman su café — Bienestar #13: sin ella descansan igual, pero tardan más en
## volver porque se van a la calle).
@export_enum("espera", "oficina", "descanso") var tipo: String
## Servicio de la sala. "Comun" = compartida entre servicios (GDD R2: "servicio|Comun").
@export_enum("Documentacion", "ODAC", "Comun") var servicio: String
## `id`s de los `TipoPuesto` que pueden colocarse en esta sala (referencias por id, no Resources anidados).
@export var puestos_admitidos: Array[StringName]
## Aforo de personas en espera que soporta la sala.
@export var aforo_espera: int
## Coste de construcción de la sala, en euros.
@export var coste_construccion_eur: int
## Superficie que ocupa en la rejilla, en celdas.
@export var superficie: int
## ¿Este tipo de sala nace CON PAREDES? (2026-07-30, decisión del usuario: *"hay a veces que no
## quiero paredes y solo quiero delimitar las salas... no me importa que no tengan paredes
## documentación y odac ni tampoco la sala de espera pero sí la de descanso"*).
##
## Es solo el VALOR DE PARTIDA: cada sala ya construida se puede cambiar después una por una desde
## su menú. La sala de descanso viene cerrada porque su razón de ser es la intimidad —que no se vea
## a los funcionarios tomando café desde la sala de espera—; el resto nacen abiertas, en planta
## diáfana, porque ahí lo que se quiere es DELIMITAR la zona, no aislarla.
@export var paredes_por_defecto: bool = false

# ── REQUISITOS MÍNIMOS DE SALA (GDD impresora-documentos-tramite.md, decisión P1 del usuario) ──
## Comodidades OBLIGATORIAS de esta sala, por `id` de catálogo. La regla que cerró el diseño de la
## impresora: *"no existe el caso 'sala sin impresora'"* — una oficina de Documentación o de ODAC
## nace con su impresora de documentos, y si falta (save antiguo, sala recién designada) se coloca
## sola, idempotente, igual que la fachada.
##
## Es una mecánica GENERAL y reutilizable ("requisitos mínimos de sala"), no un caso especial de la
## impresora: mañana un calabozo puede exigir su banco y su cámara sin tocar una línea de código.
## Vacío = la sala no exige nada (salas de espera y de descanso).
@export var comodidades_obligatorias: Array[StringName] = []
## Cuántos PUESTOS exige como mínimo esta sala (Documentación: 1 · ODAC: 1). A diferencia de las
## comodidades, un puesto NO se coloca solo: cuesta dinero y necesita un funcionario asignado, así
## que el que falte se REPORTA (`ImpresoraDocumentos.puestos_faltantes`) para que la UI lo cuente.
@export var puestos_minimos: int = 0

## Icono para la UI.
@export var icono: Texture2D
