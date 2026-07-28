class_name CicloLuz extends CanvasModulate
## CicloLuz — la hora del día se VE. Tinta todo el mundo 2D según el reloj: la mañana entra cálida,
## el mediodía es neutro, la tarde se dora y la noche cae azul y fría.
##
## Es la traducción directa de la §2 del art bible (Mood por estado de juego):
##   · Jornada de mañana → "cálida-neutra, diurna, contraste medio" → ajetreo productivo.
##   · Noche (Doc cerrada) → "fría, azulada, nivel bajo" → vigilia tensa.
## El resto de moods de esa tabla (dilema, ascenso, fracaso) son puntuales y van por otro lado; esto
## es solo el ciclo horario, que es el que está siempre presente.
##
## Decisión de motor YA TOMADA en `docs/engine-reference/godot/modules/rendering.md`: el mood 2D se
## hace con **CanvasModulate** (estable en 4.6); el glow real está DESCARTADO para este proyecto.
##
## Reglas (control-manifest, Presentation): solo LEE el reloj (fuente única) y pinta; jamás toca la
## simulación. El dibujo va en `_process` (tiempo real): a 2× y 3× el cielo cambia más deprisa
## porque el reloj corre más deprisa, y en Pausa se queda quieto — que es lo correcto.
##
## ⚠️ El HUD y los paneles viven en sus propios `CanvasLayer`, así que **no se tiñen**: la interfaz
## tiene que seguir siendo igual de legible a las 04:00 que a mediodía.

## Paradas del día: minuto del día → color ambiente. Entre dos paradas se interpola, así que la luz
## cambia de forma continua y no a saltos. Los colores salen de la §2 del art bible; son SEMILLA,
## pensados para verse en pantalla, no para ser fotométricamente correctos.
const PARADAS: Array[Dictionary] = [
	# Noche cerrada: azul frío y oscuro, pero NUNCA tan oscuro que no se lea quién hay en la sala
	# (principio 1 del art bible: la claridad funcional manda sobre el efecto).
	{"min": 0, "color": Color(0.42, 0.48, 0.70)},
	{"min": 300, "color": Color(0.45, 0.50, 0.72)},    # 05:00 — la noche más honda ya pasó
	{"min": 420, "color": Color(0.78, 0.72, 0.72)},    # 07:00 — amanece, el azul se retira
	{"min": 480, "color": Color(1.00, 0.95, 0.88)},    # 08:00 — abre Documentación: luz cálida
	{"min": 780, "color": Color(1.00, 1.00, 0.99)},    # 13:00 — mediodía, neutro y claro
	{"min": 1080, "color": Color(1.00, 0.93, 0.82)},   # 18:00 — la tarde se dora
	{"min": 1230, "color": Color(0.80, 0.72, 0.75)},   # 20:30 — atardece
	{"min": 1320, "color": Color(0.48, 0.53, 0.75)},   # 22:00 — noche
	{"min": 1440, "color": Color(0.42, 0.48, 0.70)},   # 24:00 — empalma con el minuto 0
]

const MINUTOS_POR_DIA := 1440.0

## El reloj (inyectado por Main). Sin él, la luz se queda en el color de mediodía: nunca a oscuras.
var _tiempo: Node = null
## Última hora pintada, para no tocar el nodo si no ha cambiado de minuto (cero trabajo por frame).
var _minuto_visto: int = -1


## Inyecta el reloj y pinta la luz que toca AHORA (sin transición: al cargar una partida de noche,
## la escena aparece de noche, no amaneciendo).
func configurar(tiempo: Node) -> void:
	_tiempo = tiempo
	_repintar(true)


func _process(_delta: float) -> void:
	_repintar(false)


## Recalcula el color si el reloj ha cambiado de minuto. `forzar` lo pinta aunque no haya cambiado.
func _repintar(forzar: bool) -> void:
	if _tiempo == null:
		return
	var min_dia: int = int(fposmod(_tiempo.minutos_juego, MINUTOS_POR_DIA))
	if min_dia == _minuto_visto and not forzar:
		return
	_minuto_visto = min_dia
	color = color_a_las(float(min_dia))


## El color ambiente que corresponde a esa hora del día (minutos [0, 1440)). Función **pura**: recibe
## la hora, no la busca — así se puede testear sin reloj y la usa cualquiera que quiera saber "de qué
## color es el mundo a las 22:00".
static func color_a_las(minuto_del_dia: float) -> Color:
	var min_dia: float = fposmod(minuto_del_dia, MINUTOS_POR_DIA)
	for i: int in range(PARADAS.size() - 1):
		var desde: Dictionary = PARADAS[i]
		var hasta: Dictionary = PARADAS[i + 1]
		if min_dia < float(desde["min"]) or min_dia > float(hasta["min"]):
			continue
		var tramo: float = float(hasta["min"]) - float(desde["min"])
		if tramo <= 0.0:
			return desde["color"]
		var t: float = (min_dia - float(desde["min"])) / tramo
		return (desde["color"] as Color).lerp(hasta["color"], t)
	return PARADAS[PARADAS.size() - 1]["color"]
