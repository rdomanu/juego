# El ciclo de luz día/noche (2026-07-28) — la traducción de la §2 del art bible a color de pantalla.
# Tipo: Logic. DETERMINISTA: `color_a_las` es una función PURA (recibe la hora, no la busca), así que
# se puede comprobar sin reloj, sin árbol y sin abrir una ventana.
extends GdUnitTestSuite

const CicloLuzScript := preload("res://src/main/ciclo_luz.gd")


## Cuánto tira un color al azul frente al ámbar: >0 es noche, <0 es luz cálida. Es la medida que de
## verdad importa aquí (que la noche se sienta fría y el día cálido), no los valores exactos.
func _frialdad(color: Color) -> float:
	return color.b - color.r


# ── La noche es fría y el día cálido ─────────────────────────────────────────────────────
func test_de_madrugada_el_mundo_es_azul() -> void:
	var noche: Color = CicloLuzScript.color_a_las(180.0)     # 03:00
	assert_bool(_frialdad(noche) > 0.2).is_true()


func test_a_mediodia_la_luz_es_neutra_y_clara() -> void:
	var mediodia: Color = CicloLuzScript.color_a_las(780.0)  # 13:00
	assert_bool(absf(_frialdad(mediodia)) < 0.05).is_true()  # ni azul ni ámbar
	assert_bool(mediodia.r > 0.95).is_true()                 # y brillante


func test_la_tarde_se_dora() -> void:
	var tarde: Color = CicloLuzScript.color_a_las(1080.0)    # 18:00 — hora de peonada
	assert_bool(_frialdad(tarde) < -0.1).is_true()           # tira a ámbar


func test_al_abrir_documentacion_la_luz_ya_es_calida() -> void:
	# 08:00 es cuando entra la gente: el art bible pide "ajetreo productivo", no penumbra.
	var apertura: Color = CicloLuzScript.color_a_las(480.0)
	assert_bool(apertura.r > 0.95).is_true()
	assert_bool(_frialdad(apertura) < 0.0).is_true()


# ── La transición es continua: no hay saltos de color ────────────────────────────────────
func test_la_luz_cambia_poco_a_poco_no_a_saltos() -> void:
	# Entre dos minutos consecutivos el color no puede pegar un salto perceptible en ningún momento
	# del día: si lo hiciera, se vería un "parpadeo" al cruzar esa hora.
	var anterior: Color = CicloLuzScript.color_a_las(0.0)
	for minuto: int in range(1, 1440):
		var actual: Color = CicloLuzScript.color_a_las(float(minuto))
		var salto: float = (
			absf(actual.r - anterior.r) + absf(actual.g - anterior.g) + absf(actual.b - anterior.b)
		)
		assert_bool(salto < 0.02).is_true()
		anterior = actual


func test_el_dia_empalma_con_el_siguiente() -> void:
	# El minuto 1439 y el 0 tienen que ser casi el mismo color: si no, a medianoche se vería un corte.
	var final: Color = CicloLuzScript.color_a_las(1439.0)
	var principio: Color = CicloLuzScript.color_a_las(0.0)
	assert_bool(absf(final.b - principio.b) < 0.02).is_true()


# ── Nunca a oscuras: la claridad funcional manda sobre el efecto ─────────────────────────
func test_ni_en_la_noche_mas_honda_se_deja_de_ver_la_sala() -> void:
	# Principio 1 del art bible: "si un adorno estorba leer un estado, se simplifica". Una noche
	# preciosa en la que no se distingue quién espera sería un fallo de diseño, no un logro.
	for minuto: int in range(0, 1440, 15):
		var luz: Color = CicloLuzScript.color_a_las(float(minuto))
		assert_bool(luz.r > 0.35).is_true()
		assert_bool(luz.g > 0.35).is_true()
		assert_bool(luz.b > 0.35).is_true()


# ── La hora entra cruda: el reloj acumula minutos sin parar ──────────────────────────────
func test_la_hora_acumulada_del_reloj_se_normaliza() -> void:
	# El día 3 a las 13:00 son 5.100 minutos: debe dar el mismo color que las 13:00 del día 1.
	assert_bool(
		CicloLuzScript.color_a_las(5100.0).is_equal_approx(CicloLuzScript.color_a_las(780.0))
	).is_true()


# ══ Las luces de los objetos se encienden de noche (petición del usuario 2026-07-28) ══════
const LucesObjetosScript := preload("res://src/main/luces_objetos.gd")


func test_de_dia_los_objetos_no_dan_luz() -> void:
	assert_float(LucesObjetosScript.energia_a_las(600.0)).is_equal(0.0)    # 10:00
	assert_float(LucesObjetosScript.energia_a_las(900.0)).is_equal(0.0)    # 15:00


func test_de_noche_estan_encendidos_del_todo() -> void:
	assert_float(LucesObjetosScript.energia_a_las(1320.0)).is_equal(1.0)   # 22:00
	assert_float(LucesObjetosScript.energia_a_las(120.0)).is_equal(1.0)    # 02:00


func test_encienden_al_anochecer_de_forma_gradual() -> void:
	# Entre las 19:00 y las 21:00 van subiendo: a las 20:00 están a medias.
	assert_float(LucesObjetosScript.energia_a_las(1140.0)).is_equal(0.0)   # 19:00 — aún no
	assert_float(LucesObjetosScript.energia_a_las(1200.0)).is_equal_approx(0.5, 0.01)
	assert_float(LucesObjetosScript.energia_a_las(1260.0)).is_equal(1.0)   # 21:00 — del todo


func test_se_apagan_al_amanecer() -> void:
	assert_float(LucesObjetosScript.energia_a_las(420.0)).is_equal(1.0)    # 07:00 — aún encendidas
	assert_float(LucesObjetosScript.energia_a_las(450.0)).is_equal_approx(0.5, 0.01)
	assert_float(LucesObjetosScript.energia_a_las(480.0)).is_equal(0.0)    # 08:00 — ya sobran


func test_la_transicion_no_da_saltos() -> void:
	var anterior: float = LucesObjetosScript.energia_a_las(0.0)
	for minuto: int in range(1, 1440):
		var actual: float = LucesObjetosScript.energia_a_las(float(minuto))
		assert_bool(absf(actual - anterior) < 0.03).is_true()
		anterior = actual


func test_solo_se_encienden_los_que_tienen_luz_propia() -> void:
	# La tele, el vending, el dispensador y el equipo informático tienen pantalla o piloto; la
	# papelera y el revistero, no. Que la lista salga del CATÁLOGO es lo que permite añadir objetos
	# sin tocar la capa visual. (`fuente_agua` retirada 2026-08-06, duplicado del dispensador.)
	assert_bool(Datos.obtener(&"Comodidad", &"television").emite_luz).is_true()
	assert_bool(Datos.obtener(&"Comodidad", &"vending").emite_luz).is_true()
	assert_bool(Datos.obtener(&"Comodidad", &"dispensador_agua").emite_luz).is_true()
	assert_bool(Datos.obtener(&"Comodidad", &"equipo_informatico").emite_luz).is_true()
	assert_bool(Datos.obtener(&"Comodidad", &"papelera").emite_luz).is_false()
	assert_bool(Datos.obtener(&"Comodidad", &"revistero").emite_luz).is_false()
	assert_bool(Datos.obtener(&"Comodidad", &"radio").emite_luz).is_false()


# ══ Iluminación instalable (petición del usuario 2026-07-29: "no veo tampoco la instalacion de
# luces para la noche") — objetos de la familia "iluminacion", CUYA razón de ser es emitir luz ══
func test_las_tres_lamparas_emiten_luz_y_no_dan_confort_ni_rendimiento() -> void:
	for id: StringName in [&"fluorescente", &"lampara_pie", &"foco_led"]:
		var lampara: Resource = Datos.obtener(&"Comodidad", id)
		assert_str(lampara.familia).is_equal("iluminacion")
		assert_bool(lampara.emite_luz).is_true()
		# Lo que compra el jugador es VER, no un multiplicador (comentario de clase en comodidad.gd).
		assert_float(lampara.aporte).is_equal(0.0)


func test_el_foco_led_es_el_unico_sin_mantenimiento_diario() -> void:
	# Decisión de diseño: el foco LED cuesta más de entrada (350) pero 0 €/día; el fluorescente y
	# la lámpara de pie son más baratos de comprar pero sangran 1 €/día cada uno.
	assert_int(Datos.obtener(&"Comodidad", &"foco_led").coste_mantenimiento_dia_eur).is_equal(0)
	assert_int(Datos.obtener(&"Comodidad", &"fluorescente").coste_mantenimiento_dia_eur).is_equal(1)
	assert_int(Datos.obtener(&"Comodidad", &"lampara_pie").coste_mantenimiento_dia_eur).is_equal(1)
