# LA INVARIANTE "1 PUESTO = 1 FUNCIONARIO QUE ENTRA".
#
# Encargo literal del usuario (2026-07-30): *"necesito que seas implacable con eso para que no se
# repita, 1 puesto = 1 funcionario que entra"*. El bucle de policías entrando una y otra vez se
# persiguió TRES veces por sus causas (el camino que el NavigationServer aún no había resuelto; el
# muñeco que llega antes que el modelo) y volvía en otra forma. Este test no prueba las causas:
# prueba la INVARIANTE, así que da igual qué se rompa por debajo.
#
# Tipo: Logic. DETERMINISTA: `decidir_entrada` es lógica pura — sin escena, sin navegación, sin
# reloj y sin azar. Por eso está aislada del resto del archivo.
extends GdUnitTestSuite

const NPCsFlujoScript := preload("res://src/main/npcs_flujo.gd")
const AgenteScript := preload("res://src/core/personal/agente.gd")


## Un agente cualquiera ya asignado a una ventanilla.
func _agente(puesto: StringName) -> RefCounted:
	var a: RefCounted = AgenteScript.new("Probador", &"ag_doc")
	a.puesto_id = puesto
	return a


# AC-1: la primera vez que el modelo dice "viene de camino", el funcionario entra andando.
func test_la_primera_vez_entra() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var agente: RefCounted = _agente(&"doc_1")
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()


# AC-2 🔒 EL CASO QUE MOTIVA TODO ESTO: si su viaje se cierra antes de tiempo (por lo que sea) y el
# modelo SIGUE diciendo que viene de camino, NO se le crea otro. Sin esta línea, el juego enseñaba
# 6 funcionarios entrando para 3 puestos.
func test_no_vuelve_a_entrar_aunque_su_viaje_se_cierre() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var agente: RefCounted = _agente(&"doc_1")
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()
	# El viaje se cierra (tiene_viaje pasa a false) pero el modelo sigue diciendo que viene:
	for _i in 100:
		assert_bool(npcs.decidir_entrada(agente, true, false)).is_false()


# AC-3: mientras está andando tampoco se le duplica (caso trivial, pero es la otra puerta de entrada).
func test_no_entra_dos_veces_mientras_anda() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var agente: RefCounted = _agente(&"doc_1")
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()
	assert_bool(npcs.decidir_entrada(agente, true, true)).is_false()


# AC-4: cuando el modelo deja de decir "viene de camino" (ya está trabajando), la marca se borra y
# AL DÍA SIGUIENTE vuelve a entrar. Si no, el arreglo del bucle habría roto la entrada diaria.
func test_al_dia_siguiente_vuelve_a_entrar() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var agente: RefCounted = _agente(&"doc_1")
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()
	assert_bool(npcs.decidir_entrada(agente, false, false)).is_false()   # llegó / se fue a casa
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()     # mañana, otra vez


# AC-5: si le REASIGNAN a otra ventanilla mientras sigue viniendo, entra a la nueva. La marca guarda
# el PUESTO, no solo al agente — si guardara solo al agente, un traslado le dejaría sin entrar.
func test_si_le_cambian_de_puesto_entra_al_nuevo() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var agente: RefCounted = _agente(&"doc_1")
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_false()
	agente.puesto_id = &"tie_1"
	assert_bool(npcs.decidir_entrada(agente, true, false)).is_true()


# AC-6: la cuenta que ve el jugador. TRES agentes para TRES ventanillas → TRES entradas, ni una más,
# por muchas vueltas que dé el bucle de refresco. Es literalmente lo que pidió el usuario.
func test_tres_puestos_tres_funcionarios_que_entran() -> void:
	var npcs: Node = auto_free(NPCsFlujoScript.new())
	var plantilla: Array[RefCounted] = [_agente(&"doc_1"), _agente(&"doc_2"), _agente(&"tie_1")]
	var entradas: int = 0
	# 300 pasadas del refresco (5 segundos de juego a 60 fps) con todos "viniendo de camino" y sin
	# viaje vivo — el peor caso posible, el que producía el desfile.
	for _pasada in 300:
		for agente: RefCounted in plantilla:
			if npcs.decidir_entrada(agente, true, false):
				entradas += 1
	assert_int(entradas).is_equal(3)
