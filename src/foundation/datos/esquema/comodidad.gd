class_name Comodidad extends Resource
## Comodidad — un objeto que el jugador **compra y coloca** dentro de una sala (Comodidades #15).
##
## Cuatro familias, mismo catálogo y mismo modo de colocarse:
##   • **ciudadano**  — va en salas de **espera** y aporta **confort**: la gente aguanta más antes de
##     largarse (baja el `mult_comodidad` de Paciencia F1).
##   • **funcionario** — va en salas con **puestos** y aporta **rendimiento**: se atiende más rápido
##     (baja la duración efectiva de Flujo F1).
##   • **descanso**   — va en la **sala de descanso** y aporta **calidad del café** (Bienestar #13):
##     con la sala bien montada la pausa CUNDE más y el funcionario vuelve antes a su ventanilla.
##     Petición del usuario 2026-07-29: *"no hay objetos para esa sala, sillas, sofás, nevera,
##     revistas… cosas que puedan hacer descansar, agua"*.
##   • **iluminacion** — se coloca en **CUALQUIER** tipo de sala (espera, oficina o descanso): una
##     lámpara tiene sentido en cualquier sitio, a diferencia de las otras tres familias que solo
##     encajan en su tipo de sala. `aporte = 0.0` siempre: no da confort ni rendimiento, lo que
##     compra el jugador es VER de noche (petición del usuario 2026-07-29: *"no veo tampoco la
##     instalacion de luces para la noche"*) — la luce la enciende `src/main/luces_objetos.gd`.
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
## A quién beneficia: "ciudadano" (confort de la espera), "funcionario" (rendimiento del puesto),
## "descanso" (calidad del café en la sala de descanso) o "iluminacion" (luz instalable, va en
## cualquier tipo de sala — no beneficia a nadie en concreto, ver comentario de clase).
@export_enum("ciudadano", "funcionario", "descanso", "iluminacion") var familia: String
## Precio de compra, en euros (lo cobra Construcción por el gate E4 de Economía).
@export var coste_construccion_eur: int
## Lo que cuesta tenerlo encendido cada jornada. **0 = no consume** (papelera, revistero): se paga una
## vez y ya. Los aparatos (radio, tele, vending, equipos) sí sangran cada día.
@export var coste_mantenimiento_dia_eur: int = 0
## Cuánto aporta a su familia (confort o rendimiento). Se SUMA con el resto de objetos de la sala.
@export var aporte: float = 1.0
## Celdas que ocupa en la rejilla. Construcción LEE este campo al colocar: la celda de clic es el
## ANCLA y el cuerpo se extiende hacia +X `superficie - 1` celdas más (sin rotación ni formas en L —
## MVP, suficiente porque nada del catálogo mide más de 1×N). Bug corregido 2026-07-29 (petición del
## usuario jugando: "el sofá de 3 plazas debe ocupar 3 huecos, ahora solo ocupa 1, se amontonan") —
## el campo ya existía pero nadie lo leía. Coincide a propósito con `plazas` en los objetos donde uno
## se sienta (sofá 3, sillas 2): se lee solo. El resto del catálogo se queda en el default 1.
@export var superficie: int = 1

# ── Aforo del descanso (familia "descanso", Bienestar #13) ───────────────────────────────────
## Cuánta gente puede descansar A LA VEZ gracias a este objeto. Solo lo tienen los objetos donde uno
## se **sienta**: un sofá son 3 plazas, unas sillas 2; una nevera mejora el café de todos pero no es
## sitio donde sentarse, así que 0. Si la sala está llena, el que necesita café **se queda en su
## ventanilla atendiendo** hasta que quede sitio — no se pierde el descanso, se retrasa.
@export var plazas: int = 0

# ── Objetos de USO (story com-003): a estos la gente se ACERCA ───────────────────────────────
## ¿Hay que ir hasta él para aprovecharlo? La tele y el hilo musical se disfrutan **desde el
## asiento** (solo confort ambiental); al vending, a la fuente y al revistero **se va**.
@export var usable: bool = false
## Lo que deja de beneficio cada consumición, en euros. El vending vende: cada café es 1 € que entra
## en caja. Los objetos gratuitos (fuente, revistero) dejan 0 — dan servicio, no dinero.
@export var ingreso_por_uso_eur: float = 0.0
## Minutos de juego que dura el gesto (ir, consumir, volver). Mientras usa, la persona **no gasta
## paciencia**: está entretenida, que es justo lo que se le ha comprado.
@export var minutos_de_uso: float = 3.0
## Puntos de paciencia que devuelve haber ido (0-100). Un café calma más que hojear una revista.
@export var recupera_paciencia: float = 0.0

# ── Luz propia (petición del usuario 2026-07-28) ─────────────────────────────────────────────
## ¿Este objeto **se enciende de noche**? La tele, el vending y la fuente tienen pantalla o piloto;
## una papelera o un revistero, no. De día no se nota; cuando cae la noche, la sala deja de estar a
## oscuras del todo y se ven los puntos de luz de lo que has comprado.
@export var emite_luz: bool = false
## Color de esa luz. La tele tira a azul frío (pantalla), el vending a ámbar (los pilotos y el
## expositor iluminado), la fuente a un blanco tenue.
@export var color_luz: Color = Color(1.0, 0.9, 0.7)
## Radio de la luz en píxeles. Ninguna ilumina media comisaría: son toques, no farolas.
@export var radio_luz: float = 90.0
## Radio VERTICAL, para luces que no son redondas. **0 = redonda** (usa `radio_luz` en los dos ejes),
## que es el caso de casi todo. Existe por el FLUORESCENTE (decisión del usuario 2026-07-30): un tubo
## alumbra una franja alargada, no un círculo, así que su luz mide 5 casillas de ancho por 3 de alto.
## Es la forma de la luz contando la forma de la lámpara — y de paso lo que la distingue de la
## lámpara de pie, que cubre lo mismo pero en redondo y con luz cálida.
@export var radio_luz_y: float = 0.0
