class_name NPCsFlujo extends Node2D
## NPCsFlujo — la capa COSMÉTICA de ciudadanos (story flujo-008): spawnea un NPC por persona
## admitida, reparte destinos según el estado lógico (asiento o hueco de pie en la espera, la
## ventanilla al ser llamado, la calle al resolverse) y POSEE la navegación: un NavigationRegion2D
## bakeado del layout REAL de Construcción con `NavigationServer2D.bake_from_source_geometry_data`
## (patrón validado en el slice, Escalón 1) y re-bakeado SOLO al cambiar el layout (hook de
## Construcción, coalescido a un bake por frame como máximo — nunca por frame, manifiesto).
##
## COSMÉTICO PURO (FL5/ADR-0001): LEE Flujo y Construcción; jamás los muta. El aforo lógico no
## sabe nada de estos muñecos.
##
## Story: production/epics/flujo/story-008-comisaria-viva-npcs.md · TR-flow-005 · ADR-0004

const NPCScript := preload("res://src/main/npc_ciudadano.gd")
## El muñeco de PIEZAS que anda de verdad (2026-07-31). Lo comparten ciudadanos y funcionarios:
## el andar es el mismo para todos, solo cambian el color y si lleva gorra.
const MunecoScript := preload("res://src/main/muneco.gd")
## La mesa de la ventanilla, con su ordenador y sus papeles (2026-07-31).
const MesaAtencionScript := preload("res://src/main/mesa_atencion.gd")

## Colores placeholder por servicio (los mismos tonos que las salas de Construcción).
const COLOR_DOC := Color(0.35, 0.55, 0.9)
const COLOR_ODAC := Color(0.95, 0.6, 0.25)
## TIE (feedback flujo-008): un azul Doc ACLARADO para distinguir de un DNI/Pasaporte de un vistazo.
## Literal precalculado de COLOR_DOC.lightened(0.45) — las const no evalúan métodos entre sí.
const COLOR_TIE := Color(0.6425, 0.7525, 0.945)

## Rótulos de estado del puesto (texto SIEMPRE, respaldo daltónico) + su color de acento.
const ROTULO_ESTADO: Dictionary[StringName, String] = {
	&"cerrado": "CERRADO",
	&"abierto_sin_agente": "SIN AGENTE",
	&"libre": "LIBRE",
	&"en_camino": "EN CAMINO",   # enmienda 2026-07-25: llamada emitida, el ciudadano aún camina
	&"atendiendo": "ATENDIENDO",
	&"descansando": "☕ DESCANSO",   # Bienestar #13: su titular se ha ido a por su café
}
const COLOR_ESTADO: Dictionary[StringName, Color] = {
	&"cerrado": Color(0.6, 0.6, 0.6),
	&"abierto_sin_agente": Color(1.0, 0.8, 0.35),
	&"libre": Color(0.55, 0.9, 0.55),
	&"en_camino": Color(0.6, 0.7, 0.9),
	&"atendiendo": Color(0.5, 0.75, 1.0),
	&"descansando": Color(0.85, 0.7, 0.45),   # ámbar tostado: ni alarma ni normalidad
}
## Uniforme del policía (torso azul marino, cabeza clara — estilo npc_ciudadano).
const COLOR_POLICIA_TORSO := Color(0.10, 0.14, 0.30)
## Colores del ÁNIMO de quien espera (story paciencia-008). Sobrios, nada caricaturesco (art bible):
## el descontento se ve, pero esto es una comisaría, no un parque de atracciones.
const COLOR_ANIMO: Dictionary[StringName, Color] = {
	&"contento": Color(0.45, 0.80, 0.45),
	&"impaciente": Color(0.95, 0.78, 0.30),
	&"al_limite": Color(0.90, 0.35, 0.35),
}
## A quien el jugador ha COLADO se le pinta la barra en AZUL: se ve de un vistazo a quién le has
## hecho el favor y por qué se le llama antes que al resto (mecánica del 2026-07-26).
const COLOR_COLADO := Color(0.45, 0.75, 1.0)
## Sentinela de "sin celda" (fuera de todo rect de sala: las celdas del edificio son ≥ 0).
const CELDA_NULA := Vector2i(-1, -1)

## Barra de cansancio sobre el puesto (bienestar-013, feedback ANTICIPATORIO 2026-07-29): hoy el
## cansancio existe en el modelo y afecta al juego (ralentiza, manda al café) pero no se veía en
## ninguna parte — el jugador solo se enteraba cuando YA era demasiado tarde (rótulo ☕ DESCANSO).
## Tamaño fijo (no depende de a qué % esté el agente), bajo la etiqueta de nombre.
const ANCHO_BARRA_CANSANCIO: float = 50.0
const ALTO_BARRA_CANSANCIO: float = 4.0
const POS_Y_BARRA_CANSANCIO: float = 23.0
## Tramos de color (mismo criterio que Bienestar #13 usa para mandar al café): normal hasta 70,
## ámbar de aviso de 70 a 90, rojo crítico desde 90 — así se ve "está a punto de irse" ANTES del
## rótulo de café, que solo aparece cuando ya se ha ido.
const UMBRAL_CANSANCIO_AVISO: float = 70.0
const UMBRAL_CANSANCIO_CRITICO: float = 90.0
## `POS_Y_BARRA_CANSANCIO` la comparte TAMBIÉN la etiqueta "Extra" (minutos de descanso restantes,
## ver `_asegurar_visual_puesto`): son mutuamente excluyentes (la barra solo se ve dotado/activo; el
## extra solo con el titular de café, que es justo cuando la barra está oculta), así que reusar la
## misma franja no las hace competir por el espacio — evita solape #2026-07-29 sin sumar altura.

var _flujo: Node = null
var _construccion: Node = null
var _personal: Node = null
var _paciencia: Node = null
var _tam_celda: int = 40
var _pos_suelo: Vector2 = Vector2.ZERO
var _columnas: int = 24
var _filas: int = 13
var _region: NavigationRegion2D = null
var _rebake_pendiente: bool = false
## Celda de la sala de espera (banco o hueco de pie) → NPC que la ocupa. UNA CELDA, UNA PERSONA:
## solo estética de "sentarse/esperar de pie" — el aforo de verdad es de Flujo (F3).
var _plaza_de: Dictionary[Vector2i, Node] = {}
## Puesto_id → Node2D contenedor de su visual (muñeco policía + etiqueta nombre + rótulo estado).
## Se crea/borra/actualiza por DIFF (meta en el contenedor) — cero trabajo por frame si nada cambia.
var _visual_de_puesto: Dictionary[StringName, Node2D] = {}
## Segunda línea del rótulo de un puesto (hoy: los minutos que le quedan al que está de café).
var _rotulo_extra: Dictionary[StringName, String] = {}
## Capa donde cuelgan los muñecos que caminan al descanso (hereda el z_index 1 de `configurar`, así
## se dibujan por encima de las salas como el resto de NPCs).
var _capa_descansos: Node2D = null
## Dónde se planta el funcionario DE PIE (muñeco de piezas, sin sprite del agente): el centro de la
## celda norte de su mostrador — regla de rejilla del usuario (2026-08-02). Es la MISMA constante
## que usan la silla y el policía SENTADO (`MesaAtencionScript.CELDA_FUNCIONARIO`, ver ese fichero
## para la cuenta completa): UNA sola fuente de verdad para que de pie, sentado y silla coincidan
## siempre en el mismo punto — ver `_reconstruir_cuerpo_policia`.

## ── ORDEN DE CAPAS DEL CONTENEDOR DE LA VENTANILLA (ADR-0005) ───────────────────────────────────
## docs/architecture/adr-0005-orden-de-capas-contenedor-iso.md — el orden de dibujo dentro de
## "Puesto_X" es FIJO y con nombre; PROHIBIDO tocarlo con `add_child`/`move_child` sueltos (ya se
## rompió dos veces así: el policía encima de su mesa en julio, la silla nueva encima de todo el
## 2026-08-01). `_insertar_en_capa` es el ÚNICO mecanismo.
##
## La ventanilla, sentado (el caso canónico del ADR): FONDO=silla del funcionario < PERSONAJE=
## policía < FRENTE=mostrador (mostrador tapa piernas y silla). DE PIE (muñeco de piezas, sin
## sprite): el policía se ve ENTERO por encima del mostrador —es más alto que él, no hay piernas
## que tapar—, así que ahí es al REVÉS: el policía pasa a jugar el papel de FRENTE y el mostrador
## el de PERSONAJE. Sigue siendo el MISMO mecanismo de capas (nunca un `move_child` suelto) — lo
## que cambia es A QUÉ CAPA se asigna cada nodo según el modo, no cómo se reordena.
##
## CAPA_FRENTE_SUR (2026-08-03, bug con captura del usuario): el LADO SUR de la ventanilla -- la
## silla de espera y quien se sienta en ella -- va por ENCIMA de todo, mostrador incluido. Es el
## lado que da a camara: el mostrador de 2 celdas se dibuja desplazado a su celda este y su PNG cae
## 82 px a la izquierda del ancla, asi que tapa la celda sur entera. Con la silla metida dentro de
## "Mesa" (era NIETA del contenedor, o sea fuera del mecanismo de capas) su orden dependia del
## orden interno de ese nodo -- que ademas se permuta entero con el policia -- y acababa saliendo
## DEBAJO del mostrador: silla y piernas ocultas, como si el ciudadano estuviera subido a la mesa.
## El CIUDADANO no cuelga de aqui (vive en la capa global de munecos), asi que usa el equivalente
## por z_index: ver `Z_FRENTE_PUESTO` / `marcar_frente_de_puesto`.
##
## CAPA_FRENTE_SUR_ALTO (2026-08-03) es para la mitad de arriba de un mueble del frente cuando el
## personaje va EN MEDIO: el RESPALDO de la silla de espera partida (`MesaAtencion.
## silla_ciudadano_respaldo`). Necesita capa propia —y no compartir la de su asiento— porque
## `_insertar_en_capa` ordena por capa y dos hijos con la MISMA capa quedarían en orden indefinido.
const CAPA_FONDO: int = 0
const CAPA_PERSONAJE: int = 1
const CAPA_FRENTE: int = 2
const CAPA_FRENTE_SUR: int = 3
const CAPA_FRENTE_SUR_ALTO: int = 4

## ── EL PUESTO ES MOBILIARIO, NO GENTE (🐛 FIX 2026-08-03, bug con captura del usuario) ──────────
## *"el mostrador de la ventanilla TIE pegada al borde sur/este de Documentación se dibuja POR
## ENCIMA del murete frontal"*. Causa exacta, medida en el motor (`tools/_diag_oclusion_murete.gd`,
## volcado de z efectivos): el contenedor `"Puesto_<id>"` colgaba de `_capa_escena`, que hereda el
## `z_index = 2` de este nodo — la capa de GENTE, por diseño POR ENCIMA de las paredes para que
## ningún muñeco quede tapado por un murete. Pero de ese contenedor no cuelga solo el policía:
## cuelgan también su MOSTRADOR y sus DOS SILLAS, que son mobiliario y no tenían por qué viajar en
## la capa de la gente. Resultado: el mostrador se saltaba el murete que tiene delante.
##
## El arreglo NO toca ADR-0005: el orden interno del puesto (silla < policía < mostrador <
## silla_sur) lo sigue decidiendo `_insertar_en_capa` por orden de árbol. Lo que cambia es DÓNDE
## cuelga el bloque entero: de `_capa_puestos`, que vive en la BOLSA DE Y-SORT COMPARTIDA del juego
## ("MundoProfundo" de `Main`, z 0) junto al mobiliario estático de Construcción y a cada tramo de
## pared. Ahí el contenedor compite por PROFUNDIDAD como un mueble más, con la Y de la celda de su
## mostrador: el muro que tiene delante le tapa la base y el que tiene detrás queda detrás.
##
## ⚠️ El contenedor NO lleva `y_sort_enabled`: sus hijos se dibujan EN BLOQUE, todos a la Y del
## contenedor, y por tanto en el orden de árbol que les da ADR-0005 (regla citada en la doc de
## `CanvasItem.y_sort_enabled` y verificada en el motor). Es exactamente lo que queremos: la
## ventanilla se ordena por fuera como una pieza, y por dentro sigue mandando el ADR.
##
## Por qué NO rompe nada de lo aprobado (comprobado con fotomontaje antes/después):
##  · mesa tapa las piernas del policía sentado → van JUNTOS en el bloque, su orden relativo es el
##    mismo orden de árbol de siempre;
##  · el CIUDADANO atendido sigue en z 2 (+1 en el frente, `Z_FRENTE_PUESTO`) → sigue viéndose por
##    encima del mostrador y de su asiento, como se aprobó;
##  · el RESPALDO de su silla sigue en `Z_RESPALDO_FRENTE_SUR` = 4 (z efectivo 4) y le tapa la
##    lumbar (ver esa constante);
##  · las etiquetas y barras del puesto llevan `Z_ROTULOS_PUESTO` para conservar su z efectivo 2 —
##    son información, no mobiliario, y no deben quedar tapadas por un murete.
##
## El muñeco del POLICÍA baja también a z 0 (es parte del bloque). Es lo correcto: está DENTRO de
## su sala, así que el murete de esa sala le queda DELANTE y debe taparle la base como a cualquier
## otra cosa que esté ahí dentro. Con `ALTO_PARED_FRENTE` = 17 px el murete ni le roza (su celda
## está una fila más al norte, 20 px más arriba), así que se le sigue viendo entero.
##
## `Z_MUEBLES_PUESTO` solo se aplica en el camino de RESPALDO (sin capa profunda inyectada, ver
## `configurar`): ahí la capa de puestos sigue colgando de `_capa_escena` (z 2) y necesita este −2
## para volver al z efectivo 0 del mobiliario. Con capa profunda no hace falta: ya nace en el 0.
const Z_MUEBLES_PUESTO: int = -2
## z RELATIVO de las etiquetas/barras del contenedor del puesto, para que `Z_MUEBLES_PUESTO` no se
## las lleve por delante. El contenedor queda en z efectivo 0, así que un +2 aquí las devuelve al
## z efectivo 2 EXACTO que tenían antes del fix (la capa de gente): ni más —no deben pisar a los
## muñecos, que también están en 2 y se ordenan con ellas por y-sort— ni menos.
const Z_ROTULOS_PUESTO: int = 2

## Coloca/reordena `hijo` en la capa `capa` dentro de `contenedor`. Si `hijo` no es aún su hijo, lo
## añade primero. Reordena SOLO los nodos con capa declarada (metadato `capa_iso`), de menor a
## mayor; los hijos SIN capa (etiquetas, barras de estado…) no se tocan — quedan detrás de todos,
## en el orden en que se añadieron, que es donde ya estaban.
func _insertar_en_capa(contenedor: Node2D, hijo: Node, capa: int) -> void:
	hijo.set_meta(&"capa_iso", capa)
	if hijo.get_parent() != contenedor:
		contenedor.add_child(hijo)
	var con_capa: Array[Node] = []
	for h: Node in contenedor.get_children():
		if h.has_meta(&"capa_iso"):
			con_capa.append(h)
	con_capa.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta(&"capa_iso")) < int(b.get_meta(&"capa_iso"))
	)
	for i: int in con_capa.size():
		contenedor.move_child(con_capa[i], i)
## ── SPRITE DEL FUNCIONARIO (2026-08-01) ───────────────────────────────────────────────────────
## La pareja de policías (J-Toastie, CC BY 3.0), integrada EXACTAMENTE como los ciudadanos con
## sprite 3D (ver `NPCScript.PREFIJO_SPRITE`/`ALTO_SPRITE`/`hay_sprites` en npc_ciudadano.gd): mismo
## alto (44 px) y mismo criterio de "si no hay sprites, el muñeco de piezas de siempre".
const ALTO_SPRITE_OFICIAL: int = 44
const PREFIJO_OFICIAL_H := "oficial_h"
const PREFIJO_OFICIAL_M := "oficial_m"
## Hacia dónde mira el funcionario SENTADO en su ventanilla: al SUR (+Y del mundo), hacia el
## ciudadano — el opuesto de `DIRECCION_SENTADO` (el ciudadano mira al norte, hacia él): se miran de
## frente, como en una ventanilla de verdad.
const DIRECCION_POLICIA_SENTADO := Vector2(0.0, 1.0)
## ── EL PASO (animación procedural, 2026-07-31) ──────────────────────────────────────────────
## El usuario, viendo el primer sprite: *"dios qué feo, no hay ningún tipo de animación al caminar
## ni nada"*. Y el problema no era el sprite: es que TODO EL MUNDO se deslizaba tieso por el suelo,
## rectángulos incluidos. Un muñeco que patina se lee como una ficha de parchís; uno que bota un
## poco al andar se lee como una persona, aunque sea un rectángulo.
##
## Se hace por CÓDIGO y no con fotogramas dibujados: no cuesta un solo píxel de arte, funciona hoy
## con los rectángulos y seguirá funcionando el día que haya sprites de verdad (sumará al ciclo de
## andar en vez de estorbarle).
##
## Cada cuánto camino recorrido se completa un paso, en píxeles del plano cuadrado. 26 ≈ zancada de
## persona a la escala del juego: más corto parece que trota, más largo parece que se arrastra.
const LARGO_ZANCADA: float = 26.0
## Cuánto tiene que moverse para que se le considere "andando hacia allí" y gire la cara. Se mide
## contra una posición de referencia que solo se actualiza al girar: así el muñeco no da volantazos
## por los micro-ajustes del agente de navegación, que corrige el rumbo constantemente.
const UMBRAL_GIRO: float = 1.5
## Hacia dónde mira quien está SENTADO, en el plano de la rejilla: al norte (−Y), que es donde están
## las ventanillas respecto de la sala de espera y donde está el funcionario respecto del ciudadano
## que atiende. Sentarse mirando a la pared quedaba raro y era lo que pasaba al conservar la última
## dirección de marcha.
const DIRECCION_SENTADO := Vector2(0.0, -1.0)
## La celda por la que se sale del edificio (la puerta de la fachada). Se usa para comprobar si un
## agente puede siquiera salir a la calle a tomarse el café cuando no hay sala de descanso.
const CELDA_PUERTA_SALIDA := Vector2i(0, 6)
## Cuánto sube el cuerpo en lo alto del paso. 2 px: se nota que bota, no parece que dé saltos.
const ALTURA_BOTE: float = 2.0
## Cuánto se balancea, en radianes (~2,3°). Muy poco a propósito: es un vaivén, no un tentetieso.
const VAIVEN_PASO: float = 0.04
## A qué distancia (px) de su destino se considera que un muñeco caminante HA LLEGADO. Un pelo por
## encima del `target_desired_distance` del agente de navegación (6 px), para que la comprobación
## física no contradiga a la del propio agente cuando este sí acierta.
const DISTANCIA_LLEGADA: float = 12.0
## Cuántos frames se insiste en recalcular el camino antes de dar un viaje por imposible. ~2 s a
## 60 fps: de sobra para que el NavigationServer sincronice, y corto para no dejar a nadie dando
## vueltas si su destino es de verdad inalcanzable.
const MAX_REINTENTOS_CAMINO: int = 120
## (El mostrador pasó a ser una MESA compuesta el 2026-07-31 — ver `mesa_atencion.gd`.)
## ISOMÉTRICO (2026-07-30): el plano lógico CUADRADO (oculto — navegación y cuerpos que andan) y la
## capa de escena ISOMÉTRICA (lo que se ve, ordenado por profundidad). Ver `configurar()`.
## Agente → puesto por el que YA hizo su entrada andando. Es la invariante "1 puesto = 1
## funcionario que entra": mientras el modelo siga diciendo que ese agente viene de camino, no se
## le crea un segundo viaje aunque el primero se cierre por lo que sea. Ver `_refrescar_incorporaciones`.
var _ya_entro: Dictionary[RefCounted, StringName] = {}
## Ventanillas cuyo titular YA está plantado en ellas: entra al terminar su entrada andando y sale
## cuando la ventanilla pasa de abierta a cerrada (fin de jornada). Es lo que distingue *"aún no ha
## abierto, pero él ya está"* de *"ya cerró y se ha ido a casa"* — sin esto, el funcionario se
## esfumaba justo en los minutos de cortesía con los que llega antes de abrir.
var _en_su_puesto: Dictionary[StringName, bool] = {}
var _capa_logica: Node2D = null
var _capa_escena: Node2D = null
## Capa de los CONTENEDORES de ventanilla ("Puesto_<id>"). Vive en la bolsa de y-sort compartida del
## juego cuando Main la inyecta (ver `configurar` y `Z_MUEBLES_PUESTO`); si no, cuelga de
## `_capa_escena` como antes. Tiene `y_sort_enabled` para que cada puesto compita por su cuenta —
## sin él, todas las ventanillas se dibujarían a la misma profundidad, en bloque.
var _capa_puestos: Node2D = null

# ── Trayecto cosmético del descanso (feedback demo 2026-07-29: *"debe estar la animación del
# abandono del puesto y estar en la sala de descanso sin el puesto atendido"*) ───────────────────
## `agente` (RefCounted de Personal) → Dictionary del viaje EN CURSO. Se crea UNA vez al empezar el
## descanso y se REUSA hasta que vuelve — nunca se reconstruye por frame (regla de rendimiento del
## archivo: si nada cambió, cero toques a nodos; aquí "nada cambió" es "sigue siendo el mismo viaje",
## así que el muñeco simplemente se MUEVE, nunca se recrea). Claves de cada viaje:
##   "muneco": CharacterBody2D — el cuerpo que anda (torso+cabeza+NavigationAgent2D hijo, "Nav").
##   "nav": NavigationAgent2D  — su agente de navegación (mismo patrón que npc_ciudadano).
##   "fase": StringName        — &"yendo" (mostrador→sala/calle), &"en_sala" (quieto con su taza)
##                                o &"volviendo" (sala/calle→mostrador).
##   "puesto_id": StringName   — a qué mostrador pertenece y a qué punto vuelve.
##   "celda_sala": Vector2i    — su asiento reservado en la sala de descanso (CELDA_NULA sin sala).
##   "listo": bool             — false en su primer physics frame (gotcha del NavigationServer: no
##                                sincroniza hasta ahí — engine-reference/.../navigation.md).
##   "destino_pendiente": Vector2 (opcional) — target aún no aplicado a `nav` (se aplica en el primer
##                                frame ya "listo", o de inmediato si el viaje ya llevaba rato andando).
## Dictionary SIN TIPAR a propósito (valores mixtos) — mismo criterio que `Personal._descansando`.
var _camino_descanso: Dictionary = {}
## Celdas de la sala de descanso YA ocupadas por alguien que llegó o va de camino → su agente. Se
## libera al empezar la vuelta. Dict APARTE de `_plaza_de`: son dos salas distintas (espera/descanso)
## y aquí el ocupante es un Agente de Personal, no un NPC de Flujo.
var _asiento_descanso: Dictionary[Vector2i, RefCounted] = {}
## Puestos cuyo titular ya terminó su descanso PERO el muñeco aún no ha llegado de vuelta: mientras
## esté aquí, `_actualizar_visual_puesto` mantiene el mostrador VACÍO aunque el modelo ya diga que el
## agente está `asignado` — si no, se verían DOS policías a la vez (el fijo del mostrador + el que
## todavía anda). Se pone en `_iniciar_vuelta` y se quita en `_cerrar_camino_descanso`.
var _regreso_en_curso: Dictionary[StringName, bool] = {}

# ── Trayecto cosmético de la INCORPORACIÓN (petición del usuario 2026-07-29: *"que entren los
# funcionarios antes del turno para ver la animación... hay que calcular cuánto tardan a su puesto
# y que entren ese tiempo antes"*) ────────────────────────────────────────────────────────────────
## El MODELO (`Personal.va_de_camino_al_puesto` / `minutos_para_incorporarse`) ya decide CUÁNDO sale
## de casa cada uno y cuánto tarda — esta sección SOLO lo pinta, reutilizando el mismo andamiaje que
## el descanso (`_crear_muneco_caminante`, el paso genérico `_mover_paso` — extraído de
## `_avanzar_camino_descanso` para que sirvan los DOS casos — y la capa `_capa_descansos`). Un único
## tramo por agente (puerta → su ventanilla; sin fase "en_sala" ni "volviendo": aquí no hay a dónde
## volver). `agente` → Dictionary del viaje, mismas claves que `_camino_descanso` salvo
## "fase"/"celda_sala".
var _camino_incorporacion: Dictionary = {}
## Puestos con una incorporación EN CURSO (el muñeco aún anda hacia el mostrador): mientras esté
## aquí, `_actualizar_visual_puesto` mantiene el mostrador VACÍO — mismo motivo y mismo patrón que
## `_regreso_en_curso`, para que nunca se vean DOS policías a la vez. Se pone en
## `_iniciar_camino_incorporacion` y se quita en `_cerrar_camino_incorporacion`.
var _incorporacion_en_curso: Dictionary[StringName, bool] = {}


## El objeto que esta persona está usando ahora (`&""` si ninguno) — lo LEE el NPC para saber si
## tiene que acercarse a la máquina. Cosmético puro: aquí no se decide nada (FL5).
func comodidad_de(persona: RefCounted) -> StringName:
	if _paciencia == null or not _paciencia.has_method("comodidad_en_uso"):
		return &""
	return _paciencia.comodidad_en_uso(persona)


func usar_paciencia(paciencia: Node) -> void:
	_paciencia = paciencia


## El ánimo que debe mostrar esta persona, o `&""` si no procede enseñarlo (ya la han llamado, o no
## hay sistema de paciencia). COSMÉTICO: solo LEE (FL5).
func animo_de(persona: RefCounted) -> StringName:
	if _paciencia == null or persona == null:
		return &""
	if persona.estado != &"esperando_dentro" and persona.estado != &"esperando_fuera":
		return &""
	if not _paciencia.tiene(persona):
		return &""
	if persona.colado:
		return &"colado"
	return _paciencia.animo_de_persona(persona)


## El ciudadano ESPERANDO más cercano a un punto del mundo (para el clic derecho de "colar"), o null
## si no hay ninguno a tiro. Radio generoso: los muñecos son pequeños y el jugador no tiene por qué
## clavar el píxel.
func ciudadano_en(punto: Vector2, radio: float = 22.0) -> Node:
	var mejor: Node = null
	var mejor_dist: float = radio
	# ISOMÉTRICO (2026-07-30): los cuerpos viven en el plano lógico (oculto), así que ahora se
	# buscan ahí — pero la distancia se mide en PANTALLA, contra el muñeco que el jugador está
	# viendo. Comparar contra el cuerpo daría aciertos en un sitio donde no hay nadie dibujado.
	for hijo: Node in _capa_logica.get_children():
		if not (hijo is CharacterBody2D) or hijo.get("persona") == null:
			continue
		if animo_de(hijo.persona) == &"":
			continue   # solo se puede colar a quien está esperando (a quien ya llamaron, no)
		var dist: float = a_pantalla((hijo as Node2D).position).distance_to(punto)
		if dist < mejor_dist:
			mejor_dist = dist
			mejor = hijo
	return mejor


## Qué fracción de su paciencia le queda [0, 1] — el ANCHO de su barra. Sin dato → llena (no se
## enseña una barra medio vacía a quien no estamos midiendo).
func fraccion_paciencia(persona: RefCounted) -> float:
	if _paciencia == null or persona == null:
		return 1.0
	var valor: float = _paciencia.paciencia_de(persona)
	if valor < 0.0:
		return 1.0
	return clampf(valor / _paciencia.PACIENCIA_INICIAL, 0.0, 1.0)


## Color del aro de ánimo (texto+forma no aplican a un indicador de 3 px: el respaldo daltónico de
## esta información vive en el HUD, que da los números de satisfacción y colas).
func color_de_animo(animo: StringName) -> Color:
	if animo == &"colado":
		return COLOR_COLADO
	return COLOR_ANIMO.get(animo, Color(1, 1, 1, 0.5))


## `capa_profunda` (2026-08-03): el nodo con `y_sort_enabled` de `Main` ("MundoProfundo") donde se
## ordenan por profundidad las paredes y el mobiliario. Los CONTENEDORES de ventanilla cuelgan de
## ahí (vía `_capa_puestos`) porque son mobiliario — ver `Z_MUEBLES_PUESTO`. La GENTE no: se queda
## en `_capa_escena` (z 2), por encima de cualquier pared. `null` → todo como antes del cambio
## (herramientas y tests que montan este nodo sueltos).
func configurar(
	flujo: Node,
	construccion: Node,
	personal: Node,
	tam_celda: int,
	pos_suelo: Vector2,
	columnas: int,
	filas: int,
	capa_profunda: Node2D = null,
) -> void:
	# Gotcha de orden de dibujo: las capas visuales de Construcción cuelgan de un nodo NO-CanvasItem
	# → son RAÍCES de canvas aparte que se pintan después del bloque de Main (donde vivimos). Sin
	# esto, los NPCs se dibujan DEBAJO de las salas al cruzarlas. z_index 1 los pone encima.
	z_index = 2   # sobre el suelo (0) y sobre las paredes (1): la gente nunca queda tapada
	_flujo = flujo
	_construccion = construccion
	_personal = personal
	_tam_celda = tam_celda
	_pos_suelo = pos_suelo
	_columnas = columnas
	_filas = filas
	# ── ISOMÉTRICO (2026-07-30): DOS capas, y esta separación es la clave de toda la conversión ──
	#
	# `_capa_logica` es el PLANO DEL ARQUITECTO: la comisaría vista desde arriba, celdas cuadradas
	# de 40 px. Aquí viven la navegación y los cuerpos que andan. **Está oculta**: no se dibuja
	# nunca, solo se calcula en ella. Sigue exactamente igual que antes de la conversión, y por eso
	# ni las velocidades ni los cronómetros ni los 643 tests se han tenido que tocar.
	#
	# `_capa_escena` es LO QUE SE VE: la misma comisaría en rombos. Cada cuerpo de la capa lógica
	# tiene aquí su muñeco, al que se le copia la posición ya proyectada en cada physics frame.
	_capa_logica = Node2D.new()
	_capa_logica.name = "PlanoLogico"
	_capa_logica.visible = false
	add_child(_capa_logica)
	_capa_escena = Node2D.new()
	_capa_escena.name = "Escena"
	_capa_escena.position = pos_suelo
	# Orden de dibujo por PROFUNDIDAD (nuevo con el isométrico): dentro de esta capa, quien está
	# más abajo en pantalla tapa a quien está detrás — que es justo lo que hace que una vista
	# isométrica se lea como un espacio y no como un collage. ⚠️ Verificado en la doc de Godot 4.6:
	# `y_sort_enabled` NO es recursivo (solo ordena los hijos DIRECTOS) y solo desempata entre
	# nodos del MISMO z_index. Por eso los muñecos cuelgan de aquí directamente, y no metidos cada
	# uno en un subnodo suyo.
	_capa_escena.y_sort_enabled = true
	add_child(_capa_escena)
	# La capa de VENTANILLAS: mobiliario, no gente. Va a la bolsa compartida si Main la inyecta (así
	# cada puesto se ordena contra las paredes y los muebles de su sala); si no, se queda dentro de
	# `_capa_escena` compensando con `Z_MUEBLES_PUESTO` para conservar su z efectivo de siempre.
	# Misma `position` en los dos casos: los contenedores se colocan con `Proyeccion.centro_iso`
	# PELADA (ver `_actualizar_visual_puesto`), que no incluye el origen del suelo.
	_capa_puestos = Node2D.new()
	_capa_puestos.name = "Puestos"
	_capa_puestos.position = pos_suelo
	_capa_puestos.y_sort_enabled = true
	if capa_profunda != null:
		capa_profunda.add_child(_capa_puestos)
	else:
		_capa_puestos.z_index = Z_MUEBLES_PUESTO
		_capa_escena.add_child(_capa_puestos)
	_region = NavigationRegion2D.new()
	_region.name = "Navegacion"
	_capa_logica.add_child(_region)
	# Capa de los que están de café (Bienestar #13): son CUERPOS que andan, así que van al plano
	# lógico; sus muñecos visibles se registran aparte en `_capa_escena`.
	_capa_descansos = Node2D.new()
	_capa_descansos.name = "Descansos"
	_capa_logica.add_child(_capa_descansos)
	_rebake_pendiente = true


## Coloca un muñeco en pantalla A PARTIR de dónde está su cuerpo en el plano lógico, Y LE PONE EL
## PASO: un bote y un vaivén que dependen del CAMINO RECORRIDO, no del reloj.
##
## Que dependa del camino y no del tiempo es la clave de que parezca andar: si se para, el bote se
## para con él (no sigue botando en el sitio); si el juego va a 3×, camina más rápido y bota más
## rápido, solo. Y en Pausa se queda quieto sin tener que comprobar la pausa en ningún sitio.
func colocar_muneco(visual: Node2D, punto_cuadrado: Vector2) -> void:
	var destino: Vector2 = Proyeccion.proyectar(punto_cuadrado)
	# ARRIME al mostrador: desvío de DIBUJO de quien está en el frente de una ventanilla, para que
	# se siente sobre su silla y no en el centro de su celda (ver `marcar_frente_de_puesto` y la
	# cuenta del arrime en `mesa_atencion.gd`). Nadie más lleva este metadato, así que ni los que
	# caminan ni los funcionarios se enteran.
	if bool(visual.get_meta(&"arrime_puesto", false)):
		destino += MesaAtencionScript.DESVIO_DIBUJO_CIUDADANO
	# Gotcha de Godot: `get_meta(clave, defecto)` avisa igualmente si la clave no existe, así que se
	# pregunta primero con `has_meta` (el primer frame de cada muñeco no tiene posición previa).
	var recorrido: float = float(visual.get_meta(&"recorrido")) if visual.has_meta(&"recorrido") else 0.0
	var paso_frame: float = 0.0
	if visual.has_meta(&"pos_previa"):
		paso_frame = (destino - (visual.get_meta(&"pos_previa") as Vector2)).length()
		recorrido += paso_frame
	visual.set_meta(&"recorrido", recorrido)
	visual.set_meta(&"pos_previa", destino)
	# ¿Está andando ahora mismo? Se mide por lo que se ha movido ESTE frame, y se suaviza para que
	# el ciclo arranque y pare sin tirones. Sin esto, al pararse se quedaría congelado a media
	# zancada, como un maniquí de escaparate.
	var andando: float = float(visual.get_meta(&"andando")) if visual.has_meta(&"andando") else 0.0
	andando = lerpf(andando, 1.0 if paso_frame > 0.05 else 0.0, MunecoScript.SUAVIZADO)
	visual.set_meta(&"andando", andando)
	# Media zancada por bote: al andar se sube y se baja una vez por CADA pie, no una por paso.
	var fase: float = recorrido / LARGO_ZANCADA * PI
	visual.position = destino - Vector2(0.0, MunecoScript.bote(fase, andando))
	visual.rotation = sin(fase) * VAIVEN_PASO * andando
	# Un muñeco de SPRITE avanza su ciclo de fotogramas; el de piezas mueve sus piezas. Los dos con
	# la MISMA fase, así que caminan al mismo ritmo.
	if visual.get_child_count() > 0 and visual.get_child(0).has_meta(&"prefijo"):
		# ⚠️ SENTADO solo si además está PARADO. Sin esta condición, alguien que ya tiene su silla
		# reservada pero todavía va andando hacia ella cruzaba media comisaría en postura de
		# sentado — lo cazó el usuario al momento: *"no pueden ir sentadas esas personas siempre,
		# ahora andan con esa postura"*. La silla se reserva al ELEGIR destino, no al llegar; el que
		# sabe si ha llegado es el movimiento, no el modelo.
		var sentado: bool = bool(visual.get_meta(&"sentado", false)) and andando < 0.2
		if sentado:
			# Sentado se mira SIEMPRE hacia donde toca (a la ventanilla), no hacia donde venía
			# andando: si no, cada uno se sienta mirando a un lado distinto.
			MunecoScript.orientar_sprite(
				visual.get_child(0) as Node2D, DIRECCION_SENTADO
			)
		MunecoScript.animar_sprite(visual.get_child(0) as Node2D, fase, andando, sentado)
	else:
		MunecoScript.animar(visual, fase, andando)
	# HACIA DÓNDE MIRA. Se decide por el movimiento de ESTE frame, y solo cuando de verdad se ha
	# movido — si no, al pararse daría un volantazo por un temblor de medio píxel. Al quedarse quieto
	# conserva la última dirección, que es lo natural: uno no gira la cara al detenerse.
	#
	# ⚠️ El giro se mide en el PLANO DEL MUNDO (`punto_cuadrado`), no en pantalla. Los sprites se
	# generaron girando el modelo en 3D, así que cada uno es un rumbo del mundo; y la proyección
	# isométrica deforma los ángulos, de modo que mezclarlos hace que el personaje ande de espaldas.
	# El muñeco de piezas sí usa la pantalla, porque solo necesita saber izquierda/derecha.
	if paso_frame > UMBRAL_GIRO and andando >= 0.2:
		var previo: Vector2 = punto_cuadrado
		if visual.has_meta(&"pos_previa_giro"):
			previo = visual.get_meta(&"pos_previa_giro") as Vector2
		var avance_mundo: Vector2 = punto_cuadrado - previo
		if avance_mundo.length() > UMBRAL_GIRO:
			if visual.get_child_count() > 0 and visual.get_child(0).has_meta(&"prefijo"):
				MunecoScript.orientar_sprite(visual.get_child(0) as Node2D, avance_mundo)
			else:
				var en_pantalla: Vector2 = Proyeccion.proyectar(avance_mundo)
				MunecoScript.orientar(visual, en_pantalla.x < 0.0, en_pantalla.y < 0.0)
			visual.set_meta(&"pos_previa_giro", punto_cuadrado)
	elif not visual.has_meta(&"pos_previa_giro"):
		visual.set_meta(&"pos_previa_giro", punto_cuadrado)


## Cuelga un muñeco de la capa que SE VE. Lo llaman los cuerpos al nacer (npc_ciudadano) y los
## viajes de descanso/incorporación: el cuerpo se queda en el plano lógico y su muñeco viene aquí.
func registrar_muneco(muneco: Node2D) -> void:
	_capa_escena.add_child(muneco)


## ¿Está SENTADO este ciudadano ahora mismo? Dos casos, y los dos son "tiene una silla debajo":
##  · espera dentro **en un asiento** (no de pie: en la sala caben más de los que se sientan);
##  · está **siendo atendido**, que es en la silla de la ventanilla.
##
## Lo consume la capa visual para elegir el sprite de sentado. Es lectura pura: no decide nada de la
## simulación (FL5).
func esta_sentado(npc: Node) -> bool:
	if npc == null or npc.get("persona") == null:
		return false
	var estado: StringName = npc.persona.estado
	if estado == &"en_atencion":
		return true
	if estado != &"esperando_dentro":
		return false
	var plaza: Vector2i = _plaza_reservada_de(npc)
	if plaza == CELDA_NULA or _construccion == null:
		return false
	# Su plaza es un ASIENTO si en esa celda hay un elemento de tipo asiento.
	var elemento: StringName = _construccion.elemento_en(plaza)
	return elemento != &"" and _construccion.catalogo_de(elemento) == _construccion.ASIENTO_BASICO


## ¿Está este ciudadano PLANTADO EN EL FRENTE de su ventanilla (sentado o de pie, mientras le
## atienden)? Es lectura pura del estado lógico (FL5): `en_atencion` es exactamente el tramo en el
## que el juego le manda a `_frente_del_puesto`, la celda sur del mostrador. Mientras camina por el
## mapa (incluida la llamada anticipada, que espera DOS celdas más atrás) devuelve `false`.
func en_frente_del_puesto(npc: Node) -> bool:
	if npc == null or npc.get("persona") == null:
		return false
	return npc.persona.estado == &"en_atencion"


## ── EL CIUDADANO ATENDIDO, POR ENCIMA DEL MOSTRADOR (2026-08-03) ──────────────────────────────
## La silla de espera lo resuelve con una capa del contenedor (`CAPA_FRENTE_SUR`, ADR-0005), pero el
## ciudadano NO cuelga de ese contenedor: vive en la capa global de muñecos (`registrar_muneco`),
## donde se le copia la posición proyectada cada physics frame y donde el y-sort le ordena contra
## todo lo demás. Meterlo en el contenedor del puesto para poder darle capa sería peor: dejaría de
## ser hermano del resto de muñecos justo mientras le atienden, y el y-sort de la capa de escena ya
## no le compararía con nadie (entraría y saldría del contenedor en cada llamada).
##
## Alternativa elegida, la del ADR para casos entre capas de escena distintas: **z_index de ESTADO**
## — sube a `Z_FRENTE_PUESTO` SOLO mientras está en el frente del puesto y vuelve a 0 al salir. Es
## determinista (depende de un estado del modelo, no del orden de creación de nodos), reversible y
## no toca a nadie más: el ciudadano que ANDA por el mapa se queda en z 0 y lo sigue ordenando el
## y-sort como siempre. Verificado en engine-reference (isometrico-2d.md §5): el y-sort ordena
## DENTRO de cada grupo de z_index y jamás dibuja un z menor por delante de uno mayor.
const Z_FRENTE_PUESTO: int = 1

## ⚠️ PROBADO Y DESCARTADO CON FOTOMONTAJE (2026-08-03): poner la silla ENTERA por encima de la
## persona sentada (z 2 > `Z_FRENTE_PUESTO`), que sobre el papel es lo correcto —se sienta mirando
## a la mesa, con el respaldo del lado de cámara—, en la práctica la BORRA: el sprite está
## renderizado con asiento y respaldo macizos y encima del muñeco solo deja asomar el pelo. Ver la
## enmienda del ADR-0005.
##
## La solución buena es OCLUSIÓN PARCIAL con la silla PARTIDA en dos sprites, y para eso está la
## constante de abajo: solo el RESPALDO se dibuja por encima del sentado (le tapa la lumbar, que es
## lo físicamente cierto), mientras su asiento se queda debajo. Mientras no existan los PNG de las
## dos mitades, se usa la silla entera por DEBAJO del sentado y esta constante no se aplica a nadie.
##
## 🐛 2026-08-03 (fix del murete): pasa de 2 a 4 SIN cambiar el resultado en pantalla. Es un z
## RELATIVO al contenedor del puesto, y ese contenedor bajó de z efectivo 2 a 0 (`Z_MUEBLES_PUESTO`);
## sumar 4 en vez de 2 deja el respaldo en el MISMO z efectivo 4 de siempre, que es lo que le
## mantiene por encima del ciudadano sentado (z efectivo 3 = capa de muñecos 2 + `Z_FRENTE_PUESTO`).
const Z_RESPALDO_FRENTE_SUR: int = 4

## ── Y EL ARRIME AL MOSTRADOR (mismo estado, misma función) ────────────────────────────────────
## El 2026-08-03 el usuario eligió el "arrime al borde" (variante C): silla y persona PEGADAS al
## mostrador, a MEDIO paso del ancla en vez de en el centro de su celda. La silla se movió
## (`MesaAtencion.CELDA_CIUDADANO`) pero el CIUDADANO no, porque a él no le coloca esa constante
## sino su cuerpo del plano lógico, que sigue —y debe seguir— en el centro de la celda sur
## (`_frente_del_puesto`; ADR-0004: la navegación y el modelo no se tocan por un ajuste visual).
## Resultado: se sentaba media celda por debajo de su silla, otra vez el *"no coincide donde se
## sientan los ciudadanos con donde está la silla"*. Se corrige con un desvío SOLO DE DIBUJO, del
## mismo estado que el z_index: `MesaAtencion.DESVIO_DIBUJO_CIUDADANO`, que es exactamente lo que
## hay del centro de la celda sur a la silla (una sola fuente de verdad con la propia silla, ver la
## cuenta del arrime en `mesa_atencion.gd`).


## Marca el muñeco de un ciudadano como "en el frente de su ventanilla": z_index por encima del
## mostrador y arrime de medio paso a su silla. Por DIFF (solo escribe si cambia); se llama una vez
## por ciudadano y physics frame. Al salir del estado se deshacen las dos cosas.
func marcar_frente_de_puesto(visual: Node2D, en_frente: bool) -> void:
	if visual == null:
		return
	var z: int = Z_FRENTE_PUESTO if en_frente else 0
	if visual.z_index != z:
		visual.z_index = z
	if bool(visual.get_meta(&"arrime_puesto", false)) != en_frente:
		visual.set_meta(&"arrime_puesto", en_frente)


## Un punto del plano lógico cuadrado, llevado a coordenadas de PANTALLA (globales). Lo usan el
## acierto del clic derecho y cualquier cosa que tenga que comparar "dónde se ve" con "dónde está".
func a_pantalla(punto_cuadrado: Vector2) -> Vector2:
	return _pos_suelo + Proyeccion.proyectar(punto_cuadrado)


## Hook del cambio de layout (lo cablea Main): coalescido — como mucho un bake por frame.
func solicitar_rebake() -> void:
	_rebake_pendiente = true


## Minutos de camino que le quedan a la persona de este NPC (0.0 si su puesto ya no existe o la
## lógica ya lo dio por llegado) — para el paso ADAPTATIVO del muñeco (ver npc_ciudadano).
func camino_restante_min(persona: RefCounted) -> float:
	var puesto_id: StringName = _flujo.puesto_de(persona)
	# BUG corregido 2026-07-29 (el usuario: "en la odac siempre hay un ciudadano sentado o bien tarda
	# mucho en irse"): desde la LLAMADA ANTICIPADA, `puesto_de` tambien devuelve el puesto del
	# RESERVADO — pero `camino_restante_de` da el camino de quien YA esta siendo atendido, que casi
	# siempre es 0 porque ya llego. El reservado leia "me queda 0", el paso adaptativo lo interpretaba
	# como "ya casi estas, remata" y le ponia a 1,5x: llegaba corriendo y se quedaba congelado junto al
	# mostrador hasta 60 min (lo que dura una denuncia gorda de ODAC). Su dato de verdad es otro.
	if _flujo.siguiente_de(puesto_id) == persona:
		return _flujo.siguiente_camino_restante_de(puesto_id)
	return _flujo.camino_restante_de(puesto_id)


func _physics_process(_delta: float) -> void:
	if _rebake_pendiente:
		_rebake_pendiente = false
		_bakear_navegacion()
	_refrescar_puestos()
	_refrescar_descansos()
	_refrescar_incorporaciones()
	_sincronizar_caminantes()


## Bake del polígono navegable: el suelo del edificio + dos celdas de "calle" a la izquierda
## (spawn, cola exterior y salida) como área transitable; cada PUESTO se recorta como obstáculo
## (el NPC rodea el mostrador y se detiene en su borde). Los asientos NO se recortan: pisar la
## celda del banco es "sentarse".
func _bakear_navegacion() -> void:
	# ISOMÉTRICO (2026-07-30): la navegación vive en el PLANO LÓGICO CUADRADO, cuyo origen es la
	# esquina (0,0) de la rejilla a secas — ya no se le suma `_pos_suelo`. Ese desplazamiento es de
	# PANTALLA y ahora lo aplica la capa de escena al dibujar; metiéndolo aquí, los destinos (que
	# salen de `Construccion.centro_de_celda`, sin desplazar) habrían caído fuera del polígono
	# navegable y nadie habría podido moverse.
	var datos := NavigationMeshSourceGeometryData2D.new()
	var origen := Vector2(-2.0 * _tam_celda, 0.0)
	var fin := Vector2(_columnas * _tam_celda, _filas * _tam_celda)
	datos.add_traversable_outline(PackedVector2Array([
		origen, Vector2(fin.x, origen.y), fin, Vector2(origen.x, fin.y),
	]))
	for servicio: String in ["Documentacion", "ODAC", "Seguridad"]:
		for puesto_id: StringName in _construccion.puestos_de_servicio(servicio):
			# Se recorta el CUERPO del puesto (el mostrador: 2 celdas, o 1 si es huella mínima), NO su
			# huella de colocación. Desde el 2026-08-03 un puesto RESERVA 2×3 = 6 celdas (mostrador +
			# silla del funcionario + silla del ciudadano), pero las filas de las sillas tienen que
			# seguir siendo PISABLES: el policía y el ciudadano llegan ANDANDO a sentarse, y con las 6
			# bloqueadas se quedarían sin camino. Por eso aquí va `celdas_obstaculo_de` y no
			# `celdas_de_elemento` — dos preguntas distintas, dos funciones distintas (ver la cabecera
			# de `Construccion`). Sigue siendo la MISMA verdad del modelo: no puede desincronizarse.
			for celda_cuerpo: Vector2i in _construccion.celdas_obstaculo_de(puesto_id):
				var esquina: Vector2 = Vector2(celda_cuerpo) * float(_tam_celda)
				var lado := float(_tam_celda)
				datos.add_obstruction_outline(PackedVector2Array([
					esquina, esquina + Vector2(lado, 0), esquina + Vector2(lado, lado), esquina + Vector2(0, lado),
				]))
	# FASE E (2026-07-30): los MUROS bloquean de verdad. Cada tabique se recorta como una franja fina
	# de obstáculo sobre su arista — las PUERTAS no se recortan, y por eso son lo único por donde se
	# puede entrar en una sala cerrada. Las ventanas SÍ bloquean (se ve a través, no se pasa).
	#
	# El grosor es de un tercio de celda a propósito: si fuera un pelo, el agente (radio 8 px) se
	# colaría entre dos tabiques contiguos por el hueco de la esquina; si fuera de una celda entera,
	# se comería el suelo útil de las dos celdas vecinas y la gente no podría pegarse a la pared.
	var grosor: float = float(_tam_celda) / 3.0
	for clave: String in _construccion.muros():
		var partes: PackedStringArray = clave.split(":")
		if partes.size() != 3:
			continue
		if _construccion.tipo_muro_de_clave(clave) == &"puerta":
			continue   # por la puerta SE PASA: no se recorta
		var cx: int = int(partes[1])
		var cy: int = int(partes[2])
		var esq: Vector2 = Vector2(float(cx), float(cy)) * float(_tam_celda)
		var largo := float(_tam_celda)
		var a0: Vector2
		var a1: Vector2
		if partes[0] == "h":
			a0 = esq - Vector2(0.0, grosor / 2.0)          # arista de ARRIBA: franja horizontal
			a1 = a0 + Vector2(largo, grosor)
		else:
			a0 = esq - Vector2(grosor / 2.0, 0.0)          # arista IZQUIERDA: franja vertical
			a1 = a0 + Vector2(grosor, largo)
		datos.add_obstruction_outline(PackedVector2Array([
			a0, Vector2(a1.x, a0.y), a1, Vector2(a0.x, a1.y),
		]))
	var poligono := NavigationPolygon.new()
	poligono.agent_radius = 8.0
	NavigationServer2D.bake_from_source_geometry_data(poligono, datos)
	_region.navigation_polygon = poligono


## Nace el NPC de una persona recién admitida: aparece en la calle; su primer destino se lo dará
## su estado (dentro/fuera) en su siguiente physics frame (nunca en _ready — gotcha del server).
func spawn(persona: RefCounted) -> void:
	var npc: CharacterBody2D = NPCScript.new()
	var color: Color
	# La piel varía entre la gente (una cola toda del mismo color exacto se lee como clones) y es
	# determinista por número de turno: cada ciudadano mantiene siempre la suya, también al cargar.
	var piel: Color = MunecoScript.piel_de(persona.numero_turno)
	if persona.tramite_id() == &"tie":
		color = COLOR_TIE   # feedback flujo-008: el TIE se distingue del DNI/Pasaporte de un vistazo
		piel = MunecoScript.PIEL_TIE   # decisión del usuario 2026-07-31: la cola se lee de un vistazo
	elif persona.servicio() == &"Documentacion":
		color = COLOR_DOC
	else:
		color = COLOR_ODAC
	npc.position = _punto_calle(persona.numero_turno)
	# El cuerpo va al plano lógico (oculto); su muñeco se registra solo en la capa de escena desde
	# `configurar`. ⚠️ ORDEN: primero `add_child` y luego `configurar` — `configurar` llama a
	# `registrar_muneco`, y la posición del muñeco se copia del cuerpo, que ya debe estar colocado.
	_capa_logica.add_child(npc)
	npc.configurar(persona, self, _flujo.velocidad_npc_px_s, color, piel)
	colocar_muneco(npc.muneco, npc.position)


## El NPC llegó a la salida (Resuelta/Abandonando): libera su asiento y desaparece.
func despachar(npc: Node) -> void:
	_liberar_plaza(npc)
	npc.queue_free()


## El destino según el estado LÓGICO de su persona (el NPC lo pide SOLO al cambiar de estado).
func destino_de(npc: Node) -> Vector2:
	var persona: RefCounted = npc.persona
	match persona.estado:
		&"esperando_dentro":
			# ¿Se ha levantado a por un café? (story com-003) Entonces su destino es la máquina; al
			# terminar vuelve a su sitio de siempre (`_sitio_en_espera` es idempotente: le devuelve
			# la plaza que tenía reservada, no le busca otra).
			var comodidad: StringName = comodidad_de(persona)
			if comodidad != &"":
				return _construccion.centro_de_celda(_construccion.posicion_de(comodidad))
			return _sitio_en_espera(npc)
		&"esperando_fuera":
			return _punto_calle(persona.numero_turno)
		&"llamada", &"en_atencion":
			_liberar_plaza(npc)
			# El RESERVADO de la llamada anticipada no va al mismo sitio que quien esta siendo atendido:
			# espera de pie A UN LADO del mostrador, como en una oficina de verdad cuando ya te han
			# llamado pero el de delante sigue. Sin esto los dos munecos se pintaban SUPERPUESTOS.
			var suyo: StringName = _flujo.puesto_de(persona)
			if _flujo.siguiente_de(suyo) == persona:
				# LA LÍNEA DE DISCRECIÓN (petición del usuario, 2026-07-30: *"queda mal que esté un
				# ciudadano denunciando y otro al lado pudiendo escuchar todo"*). Antes el llamado
				# por anticipado esperaba a UN LADO del mostrador, pegado a quien estaba siendo
				# atendido — que en una comisaría de verdad es justo lo que no puede pasar: nadie
				# pone la oreja mientras otro pone una denuncia.
				#
				# Ahora espera DOS CASILLAS más atrás, en la línea que hay pintada en el suelo de
				# cualquier ventanilla real. Es una decisión de DIBUJO, no de modelo: el turno, el
				# cronómetro y el momento de la llamada no cambian; solo dónde se planta el muñeco.
				return _frente_del_puesto(persona) + Vector2(0.0, float(_tam_celda) * 2.0)
			return _frente_del_puesto(persona)
		_:
			# Resuelta / Abandonando (o cualquier raro): a la calle; despawn al llegar.
			_liberar_plaza(npc)
			return _punto_calle(persona.numero_turno)


## Un punto de la calle (el margen izquierdo, FUERA del edificio): entrada, cola exterior y
## salida. Repartido en vertical por turno para que la cola exterior se vea como grupito.
func _punto_calle(turno: int) -> Vector2:
	var base := Vector2(-1.0 * _tam_celda, 6.5 * _tam_celda)
	return base + Vector2(0.0, float(turno % 6) * 18.0 - 54.0)


## Sitio en la espera: PRIMERO un asiento libre de sus salas; sin asiento libre, un hueco de pie
## LIBRE (una celda de la sala que no sea banco y que no tenga ya a otro). Una celda = una persona:
## la plaza se RESERVA en `_plaza_de` hasta que el NPC la suelta (llamada/salida/despacho).
## Feedback 2026-07-25: antes el hueco de pie se calculaba solo por turno sobre el rect de la sala
## (que INCLUYE las celdas de los bancos) → un de-pie podía plantarse encima de un sentado.
## Solo si la sala está físicamente a tope (aforo F3 admite hasta 1,2 personas/celda) se apretujan:
## misma celda con un desvío sub-celda determinista, para que se vean dos cuerpos y no uno.
func _sitio_en_espera(npc: Node) -> Vector2:
	var persona: RefCounted = npc.persona
	var propia: Vector2i = _plaza_reservada_de(npc)
	if propia != CELDA_NULA:   # idempotente: quien ya tiene plaza no se muda al re-preguntar
		return _construccion.centro_de_celda(propia)
	var salas: Array[StringName] = _construccion.salas_de_espera_de(persona.servicio())
	for sala_id: StringName in salas:
		for asiento_id: StringName in _construccion.asientos_de_sala(sala_id):
			var celda_asiento: Vector2i = _construccion.posicion_de(asiento_id)
			if _plaza_libre(celda_asiento):
				_plaza_de[celda_asiento] = npc
				return _construccion.centro_de_celda(celda_asiento)
	for sala_id: StringName in salas:
		var celda_pie: Vector2i = _hueco_de_pie_libre(sala_id, persona.numero_turno)
		if celda_pie != CELDA_NULA:
			_plaza_de[celda_pie] = npc
			return _construccion.centro_de_celda(celda_pie)
	if not salas.is_empty():
		return _sitio_apretujado(salas[0], persona.numero_turno)
	return _punto_calle(persona.numero_turno)


## Primera celda LIBRE de la sala que no sea un banco, barriendo desde un origen determinista por
## turno (y dando la vuelta) para que la gente se reparta en vez de amontonarse en una esquina.
func _hueco_de_pie_libre(sala_id: StringName, turno: int) -> Vector2i:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var area: int = rect.get_area()
	if area <= 0:
		return CELDA_NULA
	var bancos: Dictionary = {}
	for asiento_id: StringName in _construccion.asientos_de_sala(sala_id):
		bancos[_construccion.posicion_de(asiento_id)] = true
	var origen: int = turno % area
	for salto: int in range(area):
		var celda: Vector2i = _celda_del_rect(rect, (origen + salto) % area)
		if not bancos.has(celda) and _plaza_libre(celda):
			return celda
	return CELDA_NULA


## Sala a REVENTAR: se comparte celda (el aforo lógico lo permite), pero con un desvío sub-celda
## determinista por turno para que no queden dos cuerpos exactamente superpuestos.
func _sitio_apretujado(sala_id: StringName, turno: int) -> Vector2:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	var celda: Vector2i = _celda_del_rect(rect, turno % maxi(rect.get_area(), 1))
	var desvio := Vector2(
		float(turno % 3) * 7.0 - 7.0, float((turno / 3) % 3) * 7.0 - 7.0
	)
	return _construccion.centro_de_celda(celda) + desvio


## Celda i-ésima de un rect, en orden de lectura (fila a fila).
func _celda_del_rect(rect: Rect2i, indice: int) -> Vector2i:
	return rect.position + Vector2i(indice % rect.size.x, indice / rect.size.x)


## Una celda está libre si nadie la reservó o su ocupante ya desapareció (purga de plazas fantasma).
func _plaza_libre(celda: Vector2i) -> bool:
	if not _plaza_de.has(celda):
		return true
	if is_instance_valid(_plaza_de[celda]):
		return false
	_plaza_de.erase(celda)
	return true


## La celda que este NPC tiene reservada (CELDA_NULA si ninguna).
func _plaza_reservada_de(npc: Node) -> Vector2i:
	for celda: Vector2i in _plaza_de:
		if _plaza_de[celda] == npc:
			return celda
	return CELDA_NULA


## La celda FRENTE al mostrador (el puesto está recortado del polígono navegable).
func _frente_del_puesto(persona: RefCounted) -> Vector2:
	var puesto_id: StringName = _flujo.puesto_de(persona)
	if puesto_id == &"":
		return _punto_calle(persona.numero_turno)
	var celda: Vector2i = _construccion.posicion_de(puesto_id)
	return _construccion.centro_de_celda(celda + Vector2i(0, 1))


## Suelta la plaza del NPC (y de paso purga las de NPCs ya desaparecidos): TODAS sus entradas, no
## solo la primera — si alguna vez reservase dos, la segunda quedaría bloqueada para siempre.
func _liberar_plaza(npc: Node) -> void:
	var sueltas: Array[Vector2i] = []
	for celda: Vector2i in _plaza_de:
		var ocupante: Node = _plaza_de[celda]
		if ocupante == npc or not is_instance_valid(ocupante):
			sueltas.append(celda)
	for celda: Vector2i in sueltas:
		_plaza_de.erase(celda)


# ── Visual de puestos: policía + rótulo de estado (feedback flujo-008) ───────────────────────
## Refresco COSMÉTICO por PULL de getters (FL5/ADR-0001: jamás muta la simulación). Corre en
## _physics_process TRAS el rebake (el layout ya está estable). Cero allocs por frame: un Node2D
## contenedor por puesto que persiste; el DIFF (metas `nombre`/`estado` en el contenedor) toca
## los nodos SOLO cuando el operativo o el estado cambian. El RÓTULO se muestra para TODOS los
## puestos registrados (también SIN AGENTE/CERRADO — un puesto sin dotar debe verse); el MUÑECO
## del policía solo si el puesto está dotado.
func _refrescar_puestos() -> void:
	if _flujo == null:
		return
	var vivos: Dictionary[StringName, bool] = {}
	for puesto_id: StringName in _flujo.puestos_registrados():
		var celda: Vector2i = _construccion.posicion_de(puesto_id)
		if celda == Vector2i(-1, -1):
			continue   # puesto sin posición en el layout (raro): sin visual
		vivos[puesto_id] = true
		var dotado: bool = _personal != null and _personal.puesto_dotado(puesto_id)
		var nombre: String = ""
		var cansancio: float = 0.0
		if dotado:
			var agente: RefCounted = _personal.agente_de(puesto_id)
			nombre = agente.nombre if agente != null else ""
			cansancio = agente.cansancio if agente != null else 0.0
		var estado: StringName = _flujo.estado_de_puesto(puesto_id)
		# Bienestar #13: si su titular está de café, se DICE — y con los minutos que le quedan. Una
		# ventanilla parada sin explicación parece un bug; con el motivo delante, es una decisión de
		# gestión (¿monto una sala de descanso? ¿contrato a alguien que cubra?).
		var de_cafe: RefCounted = (
			_personal.agente_descansando_en(puesto_id)
			if _personal != null and _personal.has_method("agente_descansando_en") else null
		)
		if de_cafe != null:
			estado = &"descansando"
			nombre = de_cafe.nombre
			var quedan: int = roundi(_personal.minutos_de_descanso_restantes(de_cafe))
			_rotulo_extra[puesto_id] = "☕ %d min" % quedan
		_asegurar_visual_puesto(puesto_id, celda)
		# Si el puesto se MUEVE (modo obra), su visual le sigue (DIFF por celda vista).
		var contenedor: Node2D = _visual_de_puesto[puesto_id]
		if contenedor.get_meta(&"celda", Vector2i(-9999, -9999)) != celda:
			contenedor.set_meta(&"celda", celda)
			# ISOMETRICO: el mostrador se DIBUJA, asi que va en pantalla; y se ancla por la BASE
			# (el centro del rombo de su celda), no flotando media celda por encima como antes.
			# OJO al origen: el contenedor cuelga de `_capa_puestos`, que YA esta puesta en
			# `pos_suelo` — asi que aqui va la proyeccion PELADA (`Proyeccion.centro_iso`) y NO
			# `Construccion.centro_en_pantalla`, que ademas suma el origen. Sumarlo dos veces fue
			# el bug que reporto el usuario nada mas abrir la ventana: "los funcionarios no estan
			# en sus puestos, estan fuera de la comisaria" — los mostradores se iban un tablero
			# entero hacia abajo a la derecha, y con ellos los policias que los atienden.
			contenedor.position = Proyeccion.centro_iso(celda)
		_actualizar_visual_puesto(
			puesto_id, dotado, nombre, estado, _rotulo_extra.get(puesto_id, ""), cansancio,
			_regreso_en_curso.has(puesto_id), _incorporacion_en_curso.has(puesto_id)
		)
		if de_cafe == null:
			_rotulo_extra.erase(puesto_id)
	# Retira los visuales de puestos que ya no están registrados (demolidos / cargados fuera).
	for puesto_id: StringName in _visual_de_puesto.keys():
		if not vivos.has(puesto_id):
			_visual_de_puesto[puesto_id].queue_free()
			_visual_de_puesto.erase(puesto_id)


## El trayecto cosmético del descanso (Bienestar #13 + feedback demo 2026-07-29). YA NO se reconstruye
## por firma de conteo (ese patrón creaba un muñeco NUEVO directamente puesto dentro de la sala → el
## teletransporte que reportó el usuario en la demo). Ahora cada agente tiene COMO MUCHO un viaje
## activo en `_camino_descanso`, creado una vez al empezar el descanso y REUSADO (solo se MUEVE) hasta
## que vuelve. Tres pasadas, cada una O(agentes activos), nunca O(reconstruir la sala entera):
##   1) ALTAS   — quien acaba de pasar a `descansando` sin viaje todavía → nace en su mostrador.
##   2) BAJAS   — quien ya no está `descansando` pero su viaje seguía "yendo"/"en_sala" → media
##                vuelta hacia el mostrador (si aún iba de camino a la sala, gira EN EL SITIO: el
##                viaje es solo visual, no espera a "llegar" para empezar a volver — no alarga ni
##                acorta la pausa, que sigue siendo 100% de `Personal`).
##   3) AVANCE  — cada viaje vivo se mueve un paso (mismo NavigationAgent2D + get_next_path_position
##                + move_and_slide que npc_ciudadano), o se cierra si ya ha llegado del todo.
## Sin sala construida: el viaje de ida termina en la calle y el muñeco desaparece ahí — sin sala no
## se pinta a nadie dentro (esa ausencia informa; no se inventa una sala fantasma). La vuelta, en ese
## caso, NO se anima (no hay desde dónde) y el mostrador recupera a su titular de golpe, igual que
## pasa hoy — el teletransporte que se elimina aquí es el de la sala, no el de la calle.
func _refrescar_descansos() -> void:
	if _personal == null or _construccion == null:
		return
	for agente: RefCounted in _personal.plantilla:
		if agente.estado == &"descansando" and not _camino_descanso.has(agente):
			_iniciar_camino_descanso(agente)
	for agente: RefCounted in _camino_descanso:
		var viaje: Dictionary = _camino_descanso[agente]
		var sigue_descansando: bool = agente.estado == &"descansando" and _personal.plantilla.has(agente)
		if not sigue_descansando and viaje["fase"] != &"volviendo":
			_iniciar_vuelta(viaje)
	var terminados: Array[RefCounted] = []
	for agente: RefCounted in _camino_descanso:
		if _avanzar_camino_descanso(_camino_descanso[agente]):
			terminados.append(agente)
	for agente: RefCounted in terminados:
		_cerrar_camino_descanso(_camino_descanso[agente])
		_camino_descanso.erase(agente)


## La primera sala de tipo "descanso" construida (`&""` si no hay ninguna).
func _sala_de_descanso() -> StringName:
	var salas: Array[StringName] = _construccion.salas_de_tipo("descanso")
	return salas[0] if not salas.is_empty() else &""


## Arranca el viaje de IDA: crea el muñeco caminante UNA vez, exactamente en el punto al que ya
## navegan los ciudadanos que van a esa ventanilla (`_punto_de_su_puesto`) — el mismo punto garantiza
## que el arranque cae dentro del polígono navegable (el mostrador en sí está recortado como
## obstáculo en `_bakear_navegacion`; el punto EXACTO donde se planta el muñeco quieto del mostrador
## no lo está, y no vale para pathfinding). El target real se aplica un frame más tarde (`listo`,
## gotcha del NavigationServer) — este frame solo se deja el viaje listo para que lo recoja
## `_avanzar_camino_descanso`.
func _iniciar_camino_descanso(agente: RefCounted) -> void:
	var puesto_id: StringName = agente.puesto_id
	var muneco: CharacterBody2D = _crear_muneco_caminante(agente)
	muneco.position = _punto_de_su_puesto(puesto_id)
	_capa_descansos.add_child(muneco)
	var sala: StringName = _sala_de_descanso()
	var celda_sala: Vector2i = CELDA_NULA
	var destino: Vector2
	if sala != &"":
		celda_sala = _asiento_descanso_libre(sala)
		# ── DESCANSO IN SITU (2026-07-31) ────────────────────────────────────────────────────
		# Hueco conocido de Bienestar #13, apuntado y sin cerrar hasta hoy: *"si un funcionario no
		# puede salir a la sala de descanso, que descanse donde está"*.
		#
		# Desde que los muros bloquean el paso de verdad, la sala de descanso puede quedar
		# INCOMUNICADA: encerrada sin puerta, o al otro lado de un tabique que el jugador acaba de
		# levantar. Antes, el muñeco salía a buscarla, no llegaba, y el viaje se cerraba a la
		# fuerza — el agente se quedaba "descansando" para el modelo pero SIN aparecer por ningún
		# lado, y su ventanilla quedaba vacía sin explicación.
		#
		# Ahora se comprueba ANTES de salir. Si no hay camino, se toma el café EN SU SITIO: no
		# pierde la pausa (sería castigarle por una obra que él no ha decidido) y se le ve, con su
		# taza, en su ventanilla. Peor que un café en condiciones, pero mucho mejor que
		# desaparecer.
		if _camino_hasta(puesto_id, celda_sala) < 0:
			_asiento_descanso.erase(celda_sala)
			celda_sala = CELDA_NULA
			sala = &""
	if sala != &"" and celda_sala != CELDA_NULA:
		_asiento_descanso[celda_sala] = agente
		destino = _construccion.centro_de_celda(celda_sala)
	else:
		# Sin sala (o sin camino hasta ella): a la calle, con reparto determinista por la fila de su
		# puesto para que varios sin sala a la vez no salgan pegados unos a otros. Y si TAMPOCO se
		# puede salir a la calle, se queda donde está.
		destino = _punto_calle(_construccion.posicion_de(puesto_id).y)
		if _camino_hasta(puesto_id, CELDA_PUERTA_SALIDA) < 0:
			destino = _punto_de_su_puesto(puesto_id)
	_camino_descanso[agente] = {
		"muneco": muneco,
		"nav": muneco.get_node("Nav") as NavigationAgent2D,
		"fase": &"yendo",
		"puesto_id": puesto_id,
		"celda_sala": celda_sala,
		"listo": false,
		"destino_pendiente": destino,
	}


## Cuántas cuadrículas hay del puesto a esa celda, esquivando muros (-1 si NO HAY CAMINO). Se
## pregunta a Construcción, que es la dueña de la rejilla y de los muros; aquí no se reimplementa
## ningún pathfinding.
func _camino_hasta(puesto_id: StringName, celda: Vector2i) -> int:
	if _construccion == null or not _construccion.has_method("distancia_en_celdas"):
		return 0   # sin forma de comprobarlo, se asume que se puede (comportamiento de siempre)
	return _construccion.distancia_en_celdas(_construccion.posicion_de(puesto_id), celda)


## Da la vuelta a un viaje YA EXISTENTE (nunca crea un muñeco nuevo): libera el asiento si lo tenía y
## le quita la taza, y reapunta su destino al mostrador. Si aún iba "yendo" (la pausa terminó antes de
## llegar a la sala), gira desde donde esté — no hace falta que "llegue" primero.
func _iniciar_vuelta(viaje: Dictionary) -> void:
	if viaje["celda_sala"] != CELDA_NULA:
		_asiento_descanso.erase(viaje["celda_sala"])
		_quitar_taza(viaje["muneco"])
		viaje["celda_sala"] = CELDA_NULA
	viaje["fase"] = &"volviendo"
	viaje["destino_pendiente"] = _punto_de_su_puesto(viaje["puesto_id"])
	_regreso_en_curso[viaje["puesto_id"]] = true


## Un paso GENÉRICO de cualquier trayecto cosmético de este archivo (descanso E incorporación):
## aplica el gotcha del primer physics frame del NavigationServer (el target no sincroniza hasta
## entonces — engine-reference/.../navigation.md), consume el `destino_pendiente` que aún no se
## haya aplicado y mueve el muñeco un paso — MISMO patrón que npc_ciudadano (NavigationAgent2D +
## get_next_path_position + move_and_slide, respetando la Pausa/velocidad de Tiempo: en Pausa nadie
## anda, igual que el resto de NPCs de este archivo). Devuelve `true` SOLO cuando la navegación ha
## llegado a su destino ESTE frame — qué significa "llegar" lo decide quien llama (para el descanso,
## pasar a "en_sala"; para la incorporación, cerrar el viaje del todo).
func _mover_paso(viaje: Dictionary) -> bool:
	var nav: NavigationAgent2D = viaje["nav"] as NavigationAgent2D
	if not viaje["listo"]:
		viaje["listo"] = true   # el NavigationServer sincroniza EN este frame: el target va al siguiente
		return false
	if viaje.has("destino_pendiente"):
		nav.target_position = viaje["destino_pendiente"]
		# Se GUARDA el destino (no solo se aplica): abajo hace falta para comprobar si el muñeco ha
		# llegado de verdad, en vez de fiarse de lo que diga el agente de navegación.
		viaje["destino"] = viaje["destino_pendiente"]
		viaje["reintentos"] = 0
		viaje.erase("destino_pendiente")
		return false
		# 🐛 BUG cazado por el usuario el 2026-07-30 ("siguen entrando 6 funcionarios para 3 puestos
		# de documentación") y confirmado instrumentando el juego en ventana: cada agente arrancaba
		# el viaje DOS VECES (y más), y se veía un desfile de policías entrando una y otra vez.
		#
		# La causa: fijar `target_position` lanza una consulta de camino que el NavigationServer
		# resuelve en el SIGUIENTE frame. Preguntarle aquí mismo `is_navigation_finished()` —dos
		# líneas más abajo— devolvía `true` porque todavía no había camino que recorrer. El viaje se
		# cerraba de inmediato, el muñeco se borraba, el modelo seguía diciendo "este agente viene de
		# camino", y al frame siguiente se creaba un viaje nuevo. Un bucle.
		#
		# Se sale ANTES de preguntar: este frame solo sirve para encargar el camino. Es el mismo
		# gotcha del primer physics frame que ya está documentado arriba, una vuelta de tuerca más.
		return false
	var mult: float = Tiempo.multiplicador_velocidad
	if mult <= 0.0:
		return false
	var muneco: CharacterBody2D = viaje["muneco"] as CharacterBody2D
	if nav.is_navigation_finished():
		# 🐛 BUG cazado por el usuario el 2026-07-30 ("siguen entrando 6 funcionarios para 3 puestos")
		# y medido instrumentando la ventana: `is_navigation_finished()` MIENTE mientras el
		# NavigationServer no ha resuelto el camino — contesta "ya has llegado" cuando en realidad
		# aún no ha empezado. El viaje se cerraba en la puerta, el muñeco se borraba, el modelo
		# seguía diciendo "este agente viene de camino" y nacía un viaje nuevo: el desfile de
		# policías entrando una y otra vez.
		#
		# Así que no se pregunta al agente de navegación, se MIDE: solo ha llegado quien está de
		# verdad al lado de su destino. Si dice que ha terminado pero sigue lejos, se le vuelve a
		# encargar el camino (el servidor ya habrá sincronizado) en vez de darlo por llegado.
		var destino: Vector2 = viaje.get("destino", muneco.position)
		if muneco.position.distance_to(destino) <= DISTANCIA_LLEGADA:
			return true
		# Red de seguridad: si el destino es INALCANZABLE (un recinto sin puerta, por ejemplo) esto
		# no puede reintentar para siempre. Tras `MAX_REINTENTOS_CAMINO` se da por terminado igual —
		# el muñeco desaparece y el mostrador vuelve a enseñar a su titular, que es mucho mejor que
		# un policía dando vueltas eternamente por la comisaría.
		var reintentos: int = int(viaje.get("reintentos", 0)) + 1
		viaje["reintentos"] = reintentos
		if reintentos > MAX_REINTENTOS_CAMINO:
			return true
		nav.target_position = destino
		return false
	var siguiente: Vector2 = nav.get_next_path_position()
	muneco.velocity = muneco.global_position.direction_to(siguiente) * _flujo.velocidad_npc_px_s * mult
	muneco.move_and_slide()
	return false


## Avanza un viaje de DESCANSO un paso (delega el movimiento en `_mover_paso`, compartido con la
## incorporación). Devuelve `true` si el viaje ha terminado del todo (se cierra fuera, en
## `_refrescar_descansos`, para no borrar del dict mientras se itera).
func _avanzar_camino_descanso(viaje: Dictionary) -> bool:
	if viaje["fase"] == &"en_sala":
		return false   # quieto con su taza: nada que mover ni que comprobar
	if not _mover_paso(viaje):
		return false
	# Llegó: "yendo" CON sala → se queda ("en_sala", con su taza); "yendo" SIN sala o "volviendo" →
	# viaje completo.
	if viaje["fase"] == &"yendo" and viaje["celda_sala"] != CELDA_NULA:
		viaje["fase"] = &"en_sala"
		_poner_taza(viaje["muneco"])
		return false
	if viaje["fase"] == &"yendo":
		# SIN sala de descanso (o sin camino hasta ella): el muñeco ha llegado a donde podía —la
		# calle, o su propia ventanilla si tampoco podía salir— y ahí se queda hasta que el modelo
		# dé la pausa por terminada (entonces `_iniciar_vuelta` lo gira). Antes se cerraba el viaje
		# al llegar, pero el agente seguía en `descansando` para el modelo, así que nacía otro viaje
		# y el muñeco salía una y otra vez — el mismo bucle que el de las incorporaciones, con la
		# misma causa: el muñeco termina antes que el modelo.
		#
		# Y SE LE PONE LA TAZA IGUAL: está de café, aunque sea de pie en la calle o en su propia
		# ventanilla. Sin taza, el jugador vería a un funcionario parado sin motivo aparente.
		viaje["fase"] = &"en_sala"
		_poner_taza(viaje["muneco"])
		return false
	return true


## Cierra un viaje terminado: borra el muñeco y, si terminaba una VUELTA, libera la supresión del
## mostrador (`_regreso_en_curso`) — a partir de aquí el DIFF de `_actualizar_visual_puesto` decide si
## el mostrador vuelve a enseñar a su titular real. (La entrada en `_camino_descanso` la borra el
## llamador — este método no toca ese dict, solo lo que cuelga del viaje.)
func _cerrar_camino_descanso(viaje: Dictionary) -> void:
	if viaje["fase"] == &"volviendo":
		_regreso_en_curso.erase(viaje["puesto_id"])
	_borrar_caminante(viaje["muneco"] as Node)


## El punto al que YA navegan los ciudadanos atendidos en este puesto (`_frente_del_puesto`, pero sin
## necesitar una `persona`): el mostrador en sí está recortado como obstáculo, así que este es el
## único punto garantizado dentro del polígono navegable para ese puesto. Puesto inexistente
## (despedido/desasignado/demolido mientras descansaba) → un punto de calle, como cualquier NPC sin
## destino real.
func _punto_de_su_puesto(puesto_id: StringName) -> Vector2:
	if puesto_id == &"":
		return _punto_calle(0)
	var celda: Vector2i = _construccion.posicion_de(puesto_id)
	if celda == CELDA_NULA:
		return _punto_calle(0)
	return _construccion.centro_de_celda(celda + Vector2i(0, 1))


## Primera celda LIBRE de la sala de descanso (mismo barrido en lectura que usa `_hueco_de_pie_libre`
## para la sala de espera, pero en su propio dict — son salas distintas). Sin hueco no debería pasar
## nunca (`Personal.hay_sitio_para_descansar` ya limita el aforo antes de mandar a nadie aquí); si
## pasara, mejor una superposición rara en la esquina que un crash.
func _asiento_descanso_libre(sala_id: StringName) -> Vector2i:
	var rect: Rect2i = _construccion.rect_de_sala(sala_id)
	if rect.get_area() <= 0:
		return rect.position
	for indice: int in range(rect.get_area()):
		var celda: Vector2i = _celda_del_rect(rect, indice)
		if not _asiento_descanso.has(celda):
			return celda
	return rect.position


## Añade la taza (☕) al llegar a la sala — el mismo indicador que ya existía, ahora sobre el muñeco
## que de verdad caminó hasta allí en vez de uno recién creado en el sitio.
func _poner_taza(cuerpo: Node2D) -> void:
	var muneco: Node2D = _visual_caminante(cuerpo)
	if muneco == null:
		return
	var taza := Label.new()
	taza.name = "Taza"
	taza.text = "☕"
	taza.add_theme_font_size_override("font_size", 10)
	taza.position = Vector2(-6, -34)
	taza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muneco.add_child(taza)


## Quita la taza al levantarse a volver (defensivo: si el viaje era sin sala, nunca la tuvo — no hay
## nada que hacer).
func _quitar_taza(cuerpo: Node2D) -> void:
	var muneco: Node2D = _visual_caminante(cuerpo)
	if muneco == null:
		return
	var taza: Node = muneco.get_node_or_null("Taza")
	if taza != null:
		taza.queue_free()


## ¿Hay que hacer que este agente ENTRE ANDANDO ahora mismo? Es la invariante "1 puesto = 1
## funcionario que entra", aislada aquí a propósito para que se pueda probar sola, sin escena, sin
## navegación y sin reloj (ver `tests/.../npcs_entrada_unica_test.gd`).
##
## Muta `_ya_entro`: devolver `true` es también apuntar que ese agente ya hizo su entrada.
func decidir_entrada(agente: RefCounted, viene: bool, tiene_viaje: bool) -> bool:
	if not viene:
		_ya_entro.erase(agente)   # ya está trabajando (o ya no viene): mañana volverá a entrar
		return false
	if tiene_viaje:
		return false              # ya está andando ahora mismo
	if _ya_entro.get(agente, &"") == agente.puesto_id:
		return false              # YA hizo su entrada para este puesto: no se repite pase lo que pase
	_ya_entro[agente] = agente.puesto_id
	return true


## El trayecto cosmético de la LLEGADA (ver comentario de `_camino_incorporacion`). Dos pasadas,
## mismo espíritu que `_refrescar_descansos` pero sin fases intermedias — un único tramo puerta→
## puesto:
##   1) ALTAS — quien el modelo ya dice que viene (`va_de_camino_al_puesto`) y aún no tiene viaje.
##   2) AVANCE — cada viaje vivo se mueve un paso; se cierra si YA LLEGÓ (nav) o si perdió el puesto
##      por el que venía mientras andaba (despido/reasignación/demolición — `Personal` ya lo saca
##      solo de `_viniendo_a_trabajar`; aquí basta con comparar `agente.puesto_id` contra el puesto
##      del viaje). Cerrar por NAV (no por el aviso del modelo de "ya ha llegado") es a propósito:
##      el modelo cronometra con minutos, el muñeco con píxeles — si se cerrase por el modelo, el
##      mostrador fijo podría reaparecer ANTES de que el muñeco llegara de verdad y se verían dos
##      policías a la vez (el mismo motivo que ya cubre `_regreso_en_curso` en el descanso).
func _refrescar_incorporaciones() -> void:
	if _personal == null or _construccion == null:
		return
	for agente: RefCounted in _personal.plantilla:
		var viene: bool = _personal.va_de_camino_al_puesto(agente)
		# ── LA INVARIANTE, Y ES DURA: 1 PUESTO = 1 FUNCIONARIO QUE ENTRA ────────────────────────
		# Encargo literal del usuario (2026-07-30): *"necesito que seas implacable con eso para que
		# no se repita, 1 puesto = 1 funcionario que entra"*. Y con razón: este bucle se ha
		# perseguido tres veces por sus causas (el camino que aún no estaba listo, el muñeco que
		# llega antes que el modelo) y volvía en otra forma.
		#
		# Así que ya no se depende de acertar con la causa. Se anota que ESTE agente ya hizo su
		# entrada para ESTE puesto, y no vuelve a hacerla pase lo que pase. La marca se borra sola
		# cuando el modelo deja de decir "viene de camino" —o sea, cuando ya está trabajando o ya no
		# viene—, así que mañana entra otra vez con normalidad, y si le reasignan a otra ventanilla
		# también (la marca guarda el PUESTO, no solo el agente).
		#
		# Que se cierre un viaje antes de tiempo dejará de duplicar a nadie: como mucho se verá un
		# muñeco de menos, que es un fallo mucho menos aparatoso que un desfile de policías.
		if decidir_entrada(agente, viene, _camino_incorporacion.has(agente)):
			_iniciar_camino_incorporacion(agente)
	var terminados: Array[RefCounted] = []
	for agente: RefCounted in _camino_incorporacion:
		var viaje: Dictionary = _camino_incorporacion[agente]
		var perdio_el_puesto: bool = agente.puesto_id != viaje["puesto_id"]
		# 🐛 LA RAÍZ del "entran 6 funcionarios para 3 puestos" (usuario, 2026-07-30), medida
		# instrumentando la ventana: el MUÑECO llega antes que el MODELO. El muñeco anda en píxeles
		# y el modelo cronometra en minutos, y no van sincronizados al milímetro. Antes bastaba con
		# que el muñeco llegara para cerrar el viaje y borrarlo — pero el modelo seguía diciendo
		# "este agente viene de camino", así que al frame siguiente nacía un viaje NUEVO y el policía
		# volvía a entrar por la puerta. De ahí el desfile.
		#
		# Ahora el muñeco que llega se QUEDA PLANTADO en su ventanilla esperando a que el modelo lo
		# dé por incorporado. Se cierra cuando coinciden los dos, que es lo que de verdad significa
		# "ya está trabajando". (El caso contrario —modelo listo y muñeco aún andando— ya estaba
		# cubierto y sigue estándolo: no se cierra hasta que el muñeco llega.)
		# Se cierra EN CUANTO el muñeco llega. Se probó a esperar además a que el modelo diera al
		# agente por incorporado, y fue peor: el modelo puede tardar mucho en decirlo (o no decirlo),
		# el viaje se quedaba abierto para siempre y con él la supresión del mostrador — resultado,
		# el funcionario NO SE VEÍA NUNCA en su ventanilla. Lo reportó el usuario en el acto.
		#
		# Cerrar pronto es seguro desde que existe la invariante de `decidir_entrada`: aunque el
		# modelo siga diciendo "viene de camino", ese agente ya no vuelve a entrar. Antes de la
		# invariante esto era justo lo que producía el desfile de policías.
		if perdio_el_puesto or _mover_paso(viaje):
			terminados.append(agente)
	for agente: RefCounted in terminados:
		_cerrar_camino_incorporacion(_camino_incorporacion[agente])
		_camino_incorporacion.erase(agente)


## Arranca el viaje de LLEGADA: crea el muñeco caminante UNA vez, en la calle junto a la puerta —
## MISMO punto que usa el descanso sin sala construida (`_punto_calle`, con la fila del puesto como
## clave determinista para que varias incorporaciones a la vez no nazcan pegadas unas a otras) — y
## lo manda al punto frente a su ventanilla (`_punto_de_su_puesto`, ya usado por el descanso: dentro
## del polígono navegable, a diferencia del mostrador en sí, que está recortado como obstáculo). El
## target real se aplica un frame más tarde (gotcha del NavigationServer, ver `_mover_paso`).
func _iniciar_camino_incorporacion(agente: RefCounted) -> void:
	var puesto_id: StringName = agente.puesto_id
	var muneco: CharacterBody2D = _crear_muneco_caminante(agente)
	muneco.position = _punto_calle(_construccion.posicion_de(puesto_id).y)
	_capa_descansos.add_child(muneco)
	_camino_incorporacion[agente] = {
		"muneco": muneco,
		"nav": muneco.get_node("Nav") as NavigationAgent2D,
		"puesto_id": puesto_id,
		"listo": false,
		"destino_pendiente": _punto_de_su_puesto(puesto_id),
	}
	_incorporacion_en_curso[puesto_id] = true


## Cierra un viaje de incorporación terminado (llegó, o perdió el puesto por el camino): borra el
## muñeco y libera la supresión del mostrador — a partir de aquí el DIFF de `_actualizar_visual_
## puesto` decide si el mostrador enseña a su titular real (si el puesto ya no es suyo, no lo hará:
## `dotado`/`agente_de` ya no lo devuelven).
func _cerrar_camino_incorporacion(viaje: Dictionary) -> void:
	_incorporacion_en_curso.erase(viaje["puesto_id"])
	# Ya está en su ventanilla: a partir de aquí se le VE, tenga la ventanilla abierta o no (llega
	# unos minutos antes de abrir a propósito). Ver `_actualizar_visual_puesto`.
	_en_su_puesto[viaje["puesto_id"]] = true
	_borrar_caminante(viaje["muneco"] as Node)


## El PREFIJO de sprite de un funcionario, repartido determinista por su NOMBRE (identidad estable
## del agente — no cambia al reasignarlo de puesto, a diferencia de `puesto_id`; mismo criterio que
## `MunecoScript.piel_de` reparte la piel de los ciudadanos por su número de turno, nunca por azar,
## para que el mismo agente salga siempre con el mismo sprite, también al recargar la partida).
## Aproximadamente mitad y mitad entre los dos policías del pack (J-Toastie, CC BY 3.0).
func _prefijo_oficial_de(nombre: String) -> String:
	return PREFIJO_OFICIAL_H if posmod(nombre.hash(), 2) == 0 else PREFIJO_OFICIAL_M


## Torso + cabeza del uniforme (las mismas piezas, pixel a pixel) añadidas a `destino`: lo comparten
## el muñeco QUIETO del mostrador (`_asegurar_visual_puesto`) y el CAMINANTE de esta sección
## (`_crear_muneco_caminante`), para que sea el mismo cuerpo se mire donde se mire.
## ISOMÉTRICO (2026-07-30): ANCLADO POR LA BASE — los pies caen en (0,0) del nodo, que es el punto
## de la celda donde de verdad está de pie. Antes iba centrado a media altura (torso en y=-8): en
## cenital daba igual, en isométrico el policía parecería flotar por encima de su mostrador.
##
## FALLBACK (2026-08-01): es el muñeco de PIEZAS que se usa cuando NO hay sprites de policía
## (`hay_sprites` da false) o mientras aún no se conoce al agente — quien de verdad decide
## pieza-o-sprite es `_crear_muneco_caminante` (el que anda) y `_reconstruir_cuerpo_policia` (el fijo
## de la ventanilla). Se conserva sin tocar: es el "sin romper nada" del que depende la comisaría si
## el render de sprites faltara.
func _anadir_cuerpo_policia(destino: Node2D) -> void:
	# Uniforme del CNP con los colores sacados de la referencia real (ver `Muneco`): polo azul
	# marino, pantalón un punto más oscuro, botas negras, piel en cara y antebrazos (manga corta) y
	# gorra con visera.
	destino.add_child(MunecoScript.construir(
		MunecoScript.AZUL_UNIFORME, true, MunecoScript.PIEL,
		MunecoScript.AZUL_PANTALON, MunecoScript.NEGRO_BOTA
	))


## Un muñeco de policía que CAMINA: sobre un CharacterBody2D con NavigationAgent2D hijo — el MISMO
## sistema que npc_ciudadano (ADR-0004): fantasma (collision_layer/mask 0, sin avoidance — MVP) y
## movido a mano desde `_avanzar_camino_descanso` con get_next_path_position + move_and_slide (no
## tiene su propio `_physics_process`: lo empuja este archivo, que es quien controla la cadencia del
## DIFF).
##
## SPRITE (2026-08-01): integrado EXACTAMENTE como los ciudadanos (`npc_ciudadano.configurar`) — si
## hay sprites del policía que le toca (`_prefijo_oficial_de(agente.nombre)`), sprite; si no, el
## muñeco de piezas de siempre. `colocar_muneco`/`_sincronizar_caminantes` ya saben animar el ciclo
## de andar de un sprite (miran `get_child(0).has_meta(&"prefijo")`): no hace falta tocar nada ahí.
func _crear_muneco_caminante(agente: RefCounted = null) -> CharacterBody2D:
	var muneco := CharacterBody2D.new()
	muneco.collision_layer = 0
	muneco.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 7.0
	forma.shape = circulo
	muneco.add_child(forma)
	var nav := NavigationAgent2D.new()
	nav.name = "Nav"
	nav.radius = 7.0
	nav.path_desired_distance = 4.0
	nav.target_desired_distance = 6.0
	nav.avoidance_enabled = false   # manifiesto: OFF (Experimental en 4.6), igual que npc_ciudadano
	muneco.add_child(nav)
	# ISOMÉTRICO (2026-07-30): el CUERPO (esto) anda por el plano lógico cuadrado y no se dibuja;
	# lo que se ve es este otro nodo, que cuelga de la capa de escena y al que se le copia la
	# posición ya proyectada en `_sincronizar_caminantes`. Mismo reparto que en npc_ciudadano.
	var visual := Node2D.new()
	visual.name = "MunecoPolicia"
	var prefijo: String = _prefijo_oficial_de(agente.nombre) if agente != null else ""
	if prefijo != "" and MunecoScript.hay_sprites(prefijo, ALTO_SPRITE_OFICIAL):
		visual.add_child(MunecoScript.construir_sprite(prefijo, ALTO_SPRITE_OFICIAL))
	else:
		_anadir_cuerpo_policia(visual)
	registrar_muneco(visual)
	muneco.set_meta(&"visual", visual)
	return muneco


## El muñeco VISIBLE de un cuerpo caminante (null si ya no existe). Todo lo que sea DIBUJO sobre un
## caminante (la taza del café, y mañana su sprite) va aquí, nunca en el cuerpo.
func _visual_caminante(cuerpo: Node) -> Node2D:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return null
	var visual: Variant = cuerpo.get_meta(&"visual", null)
	if visual == null or not is_instance_valid(visual):
		return null
	return visual as Node2D


## Borra un cuerpo caminante Y su muñeco. Siempre por aquí: soltar solo el cuerpo dejaría el muñeco
## dibujado para siempre en el sitio donde murió (un policía fantasma junto a la máquina de café).
func _borrar_caminante(cuerpo: Node) -> void:
	var visual: Node2D = _visual_caminante(cuerpo)
	if visual != null:
		visual.queue_free()
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.queue_free()


## Copia la posición de cada cuerpo caminante a su muñeco, ya proyectada. Una pasada por physics
## frame sobre los viajes VIVOS (descansos + incorporaciones): son unos pocos, no la plantilla
## entera. Es el equivalente del `muneco.position = ...` que npc_ciudadano hace en su propio
## `_physics_process` — los caminantes no tienen script propio, así que lo hace este archivo.
func _sincronizar_caminantes() -> void:
	for cuerpo: Node in _capa_descansos.get_children():
		var visual: Node2D = _visual_caminante(cuerpo)
		if visual != null:
			colocar_muneco(visual, (cuerpo as Node2D).position)


## Crea (una vez) el contenedor del puesto con sus piezas hijas fijas: muñeco policía (torso +
## cabeza), etiqueta de nombre (font 8, bajo el muñeco), rótulo de estado (font 9, sobre el
## mostrador) y etiqueta "Extra" (font 9, minutos de descanso restantes — franja compartida con la
## barra de cansancio, ver su comentario de const). El contenedor se ancla sobre la celda del
## puesto; las piezas van en local.
func _asegurar_visual_puesto(puesto_id: StringName, celda: Vector2i) -> void:
	if _visual_de_puesto.has(puesto_id):
		return
	var contenedor := Node2D.new()
	contenedor.name = "Puesto_%s" % puesto_id
	contenedor.position = Proyeccion.centro_iso(celda)
	# EL PUESTO ES MOBILIARIO: no lleva z propio — el suyo se lo da `_capa_puestos`, que es quien
	# decide si el bloque vive en la bolsa de profundidad compartida o compensando dentro de la capa
	# de gente. Ver `Z_MUEBLES_PUESTO` para el bug, la causa medida y por qué no rompe ADR-0005 (el
	# orden INTERNO sigue siendo orden de árbol, dentro de un bloque sin y-sort propio).
	# El muñeco policía (torso + cabeza, estilo npc_ciudadano); se muestra solo si el puesto está dotado.
	var policia := Node2D.new()
	policia.name = "Policia"
	# ⚠️ ESTA LÍNEA es la que le pone el cuerpo (torso + cabeza). Se perdió el 2026-07-30 al
	# reordenar mesa y policía dentro del contenedor, y el resultado fue un nodo "Policia" existente,
	# bien colocado y visible... pero VACÍO. El funcionario no se veía por ningún lado, y todo lo que
	# se investigó después (orden de dibujo, tamaño de la mesa, capas, z_index) perseguía un fantasma
	# — hasta que se midió `policia.get_child_count()` y salió 0.
	_anadir_cuerpo_policia(policia)
	# LA VENTANILLA SON TRES CASILLAS EN FILA (petición del usuario, 2026-07-30, viendo el
	# isométrico: *"la mesa de atención debe ser como 3 casillas: 1 donde está el policía, otra la
	# mesa y otra la silla con el ciudadano; ahora veo encima de la mesa al funcionario"*):
	#
	#     [ funcionario ]  ←  celda - (0,1),  DETRÁS del mostrador
	#     [   MESA      ]  ←  la celda del puesto en el modelo
	#     [  ciudadano  ]  ←  celda + (0,1),  donde ya le manda `_frente_del_puesto`
	#
	# El ciudadano ya iba a su casilla desde antes; lo que faltaba era sacar al funcionario de
	# ENCIMA de la mesa. Se mueve solo el DIBUJO: el modelo sigue teniendo el puesto en una celda,
	# así que ni costes, ni validación de colocación, ni un solo test cambian.
	#
	# EL ORDEN DE DIBUJO, por CAPAS con nombre (ADR-0005 — nunca `add_child`/`move_child` sueltos:
	# ya se rompió DOS veces así, ver el ADR). De pie (sin sprite de policía, el caso de aquí): la
	# silla del funcionario al FONDO (vacía, nadie sentado todavía), la mesa de PERSONAJE y el
	# policía de FRENTE —él es quien tapa, al ser más alto que el mostrador—. `_reconstruir_cuerpo_
	# policia` reasigna las capas de policía/mesa (nunca la de la silla) en cuanto se sienta.
	var silla_funcionario: Node2D = MesaAtencionScript.silla_funcionario_o_defecto(
		MesaAtencionScript.CELDA_FUNCIONARIO.normalized() * 20.0
	)
	silla_funcionario.name = "SillaFuncionario"
	silla_funcionario.position = MesaAtencionScript.CELDA_FUNCIONARIO
	_insertar_en_capa(contenedor, silla_funcionario, CAPA_FONDO)
	# `es_huella_legado`: un puesto de save viejo que no cabe en 2 celdas hoy usa el mostrador de 1
	# celda (ver `MesaAtencion.construir` y la cabecera "LA HUELLA DEL PUESTO" en `Construccion`).
	_insertar_en_capa(
		contenedor, MesaAtencionScript.construir(_construccion.es_huella_legado(puesto_id)),
		CAPA_PERSONAJE
	)
	policia.position = MesaAtencionScript.CELDA_FUNCIONARIO
	_insertar_en_capa(contenedor, policia, CAPA_FRENTE)
	# LA SILLA DE ESPERA (lado SUR, el que da a camara) va por ENCIMA del mostrador: es lo que hay
	# DELANTE de la ventanilla, no detras. Hermana de "Mesa" y en su propia capa (2026-08-03, ver
	# CAPA_FRENTE_SUR) -- antes era hija de "Mesa" y el mostrador de 2 celdas la tapaba.
	#
	# PARTIDA EN DOS si estan renderizadas sus mitades: asiento DEBAJO del ciudadano y respaldo
	# ENCIMA (oclusion parcial: le tapa la lumbar y se le sigue viendo). Las dos van a la misma
	# posicion; lo que las ordena contra el muneco -- que vive en otra capa de escena -- es el z.
	# Sin las dos mitades, la silla ENTERA por debajo del sentado, como hasta ahora.
	if MesaAtencionScript.hay_silla_espera_partida():
		_insertar_en_capa(contenedor, MesaAtencionScript.silla_ciudadano_asiento(), CAPA_FRENTE_SUR)
		var respaldo: Node2D = MesaAtencionScript.silla_ciudadano_respaldo()
		respaldo.z_index = Z_RESPALDO_FRENTE_SUR
		_insertar_en_capa(contenedor, respaldo, CAPA_FRENTE_SUR_ALTO)
	else:
		_insertar_en_capa(contenedor, MesaAtencionScript.silla_ciudadano(), CAPA_FRENTE_SUR)
	# Etiqueta de nombre (bajo el muñeco). Ancho fijo 60 + centrado para no depender del texto. Font
	# 8 (un punto menos que el resto): entre nombre/estado/minutos, el nombre es el dato MENOS
	# accionable (feedback 2026-07-29 de solape) — si algo tiene que ceder espacio, es él.
	var lbl_nombre := _label_centrada(8, Vector2(-30, 10))
	lbl_nombre.name = "Nombre"
	contenedor.add_child(lbl_nombre)
	# Barra de cansancio (bienestar-013, feedback anticipatorio): bajo la etiqueta de nombre. Dos
	# piezas — un FONDO oscuro que marca dónde está el 100 % (respaldo NO cromático: en escala de
	# grises se sigue viendo cuánto le falta al relleno para llegar al borde) y un RELLENO que se
	# encoge y cambia de color según el cansancio real. Ambas nacen ocultas: `_actualizar_visual_
	# puesto` decide si procede enseñarlas (puesto dotado, no cerrado, agente no está de café).
	var pos_barra := Vector2(-ANCHO_BARRA_CANSANCIO * 0.5, POS_Y_BARRA_CANSANCIO)
	var barra_fondo := ColorRect.new()
	barra_fondo.name = "BarraCansancioFondo"
	barra_fondo.color = Color(0.08, 0.08, 0.08, 0.85)
	barra_fondo.size = Vector2(ANCHO_BARRA_CANSANCIO, ALTO_BARRA_CANSANCIO)
	barra_fondo.position = pos_barra
	barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_fondo.visible = false
	contenedor.add_child(barra_fondo)
	var barra_relleno := ColorRect.new()
	barra_relleno.name = "BarraCansancioRelleno"
	barra_relleno.color = COLOR_ESTADO[&"libre"]
	barra_relleno.size = Vector2(ANCHO_BARRA_CANSANCIO, ALTO_BARRA_CANSANCIO)
	barra_relleno.position = pos_barra
	barra_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_relleno.visible = false
	contenedor.add_child(barra_relleno)
	# Minutos de descanso restantes, en SU PROPIA etiqueta (feedback 2026-07-29: *"el tiempo restante
	# que le queda de descanso se sobrepone con otras letras"*). Antes se concatenaba como segunda
	# línea de "Estado" con un salto de línea — esa línea extra crecía hacia abajo e invadía el
	# nombre. Con etiqueta propia, "Estado" mide SIEMPRE una sola línea (ver `_actualizar_visual_
	# puesto`) y esta ocupa la franja de la barra de cansancio (mutuamente excluyentes, ver la const).
	var lbl_extra := _label_centrada(9, Vector2(-30, POS_Y_BARRA_CANSANCIO))
	lbl_extra.name = "Extra"
	lbl_extra.visible = false
	contenedor.add_child(lbl_extra)
	# Rótulo de estado (sobre el mostrador). Texto SIEMPRE + color de acento (respaldo daltónico).
	var lbl_estado := _label_centrada(9, Vector2(-30, -_tam_celda * 0.5))
	lbl_estado.name = "Estado"
	contenedor.add_child(lbl_estado)
	# Los RÓTULOS (nombre, estado, minutos, barra de cansancio) recuperan el z efectivo 2 que tenían
	# antes de que el contenedor bajara a la capa de mobiliario: son INFORMACIÓN sobre el puesto, no
	# muebles, y un murete no debe poder tapar el nombre del funcionario. Ver `Z_ROTULOS_PUESTO`.
	# Se hace en un solo sitio (aquí, al final) en vez de repetirlo nodo a nodo: los hijos SIN
	# `capa_iso` son, por definición, exactamente los rótulos (ver `_insertar_en_capa`).
	for hijo: Node in contenedor.get_children():
		if hijo is CanvasItem and not hijo.has_meta(&"capa_iso"):
			(hijo as CanvasItem).z_index = Z_ROTULOS_PUESTO
	_capa_puestos.add_child(contenedor)
	_visual_de_puesto[puesto_id] = contenedor


## Aplica el estado por DIFF: solo toca los nodos si el nombre, estado, extra o el TRAMO de
## cansancio vistos cambiaron (metas en el contenedor). El muñeco se muestra/oculta con `dotado`;
## el rótulo siempre visible. `extra` (minutos de descanso) vive en SU PROPIA etiqueta ("Extra"),
## nunca concatenado a "Estado" — feedback 2026-07-29: la línea extra invadía el nombre de abajo.
##
## `cansancio` se CUANTIZA a pasos del 5 % (`int(cansancio / 5.0)`) antes de entrar en la firma:
## el cansancio del agente sube cada physics_process (bienestar-013), así que meterlo crudo (float)
## en la comparación rompería el DIFF por completo — cualquier variación de una centésima ya sería
## "distinto", y el contenedor se repintaría 60 veces por segundo en vez de cero. Cuantizado, la
## barra solo se toca ~20 veces en TODA la vida útil del agente (100 % / 5 % por paso), que es
## exactamente la cadencia con la que tiene sentido que el jugador la vea moverse.
func _actualizar_visual_puesto(
	puesto_id: StringName, dotado: bool, nombre: String, estado: StringName, extra: String,
	cansancio: float = 0.0, oculto_por_regreso: bool = false, oculto_por_llegada: bool = false
) -> void:
	var contenedor: Node2D = _visual_de_puesto[puesto_id]
	var visto_dotado: bool = contenedor.get_meta(&"dotado", false)
	var visto_nombre: String = contenedor.get_meta(&"nombre", "")
	var visto_estado: StringName = contenedor.get_meta(&"estado", &"")
	var visto_extra: String = contenedor.get_meta(&"extra", "")
	var paso_cansancio: int = int(cansancio / 5.0)
	var visto_paso_cansancio: int = contenedor.get_meta(&"paso_cansancio", -1)
	var visto_regreso: bool = contenedor.get_meta(&"oculto_por_regreso", false)
	var visto_llegada: bool = contenedor.get_meta(&"oculto_por_llegada", false)
	if (
		visto_dotado == dotado and visto_nombre == nombre and visto_estado == estado
		and visto_extra == extra and visto_paso_cansancio == paso_cansancio
		and visto_regreso == oculto_por_regreso and visto_llegada == oculto_por_llegada
	):
		return   # nada cambió (ni siquiera el TRAMO de cansancio ni el regreso/llegada): cero toques
	contenedor.set_meta(&"dotado", dotado)
	contenedor.set_meta(&"nombre", nombre)
	contenedor.set_meta(&"estado", estado)
	contenedor.set_meta(&"extra", extra)
	contenedor.set_meta(&"paso_cansancio", paso_cansancio)
	contenedor.set_meta(&"oculto_por_regreso", oculto_por_regreso)
	contenedor.set_meta(&"oculto_por_llegada", oculto_por_llegada)
	# Horario provisional 2026-07-25 "los funcionarios se van": con el puesto cerrado (por horario o
	# por el jugador) el muñeco y su nombre desaparecen del mostrador — caminar a casa es juice futuro.
	var policia: Node2D = contenedor.get_node("Policia")
	# SPRITE DEL FUNCIONARIO (2026-08-01): el cuerpo se reconstruye SOLO cuando cambia DE QUIÉN es
	# (nombre distinto — nuevo titular, o el puesto se queda sin nadie): es la misma condición que ya
	# formaba parte del DIFF de arriba, así que esto sigue costando cero mientras nada cambie.
	if nombre != visto_nombre:
		_reconstruir_cuerpo_policia(contenedor, policia, nombre)
	# De café, el mostrador se queda VACÍO (quien se ve es el muñeco CAMINANTE de `_refrescar_descansos`)
	# pero el nombre sigue: es SU ventanilla, solo que ahora mismo no hay nadie. `oculto_por_regreso`
	# (feedback demo 2026-07-29) tapa el hueco entre "el modelo ya dice que ha vuelto" y "el muñeco
	# caminante todavía no ha llegado": sin esto se verían DOS policías un instante (el fijo del
	# mostrador + el que aún anda) si le llaman justo al terminar la pausa. `oculto_por_llegada`
	# (petición del usuario 2026-07-29: que se les vea ENTRAR) es el mismo tapaagujeros pero para la
	# incorporación: mientras el muñeco camina desde la puerta hasta su ventanilla, el mostrador debe
	# seguir VACÍO aunque el puesto ya esté `dotado` en el modelo (lo está desde que se le asignó).
	# ── EL FUNCIONARIO SE VE AUNQUE SU VENTANILLA ESTÉ CERRADA ─────────────────────────────────
	# Petición del usuario (2026-07-30): *"los funcionarios siempre tienen que verse aunque su puesto
	# esté cerrado. Hay unos minutos desde que entran que se desplazan a su puesto que está cerrado y
	# desaparece el NPC, pero cuando abre aparecen; en todo momento tienen que verse"*.
	#
	# Y es lo lógico: sale de casa con antelación justamente para estar sentado ANTES de abrir. Que
	# se esfumara en esos minutos era la regla vieja del horario ("con el puesto cerrado el muñeco
	# desaparece"), que no distinguía entre *"todavía no ha abierto"* y *"ya se ha ido a casa"*.
	#
	# Ahora se distinguen con `_en_su_puesto`: entra al llegar andando y sale cuando su ventanilla
	# pasa de ABIERTA a CERRADA, que es el momento en que termina su jornada y se marcha. Antes de
	# abrir → está y se le ve; después de cerrar → se ha ido.
	var cerrado: bool = estado == &"cerrado"
	if cerrado and visto_estado != &"cerrado" and visto_estado != &"":
		_en_su_puesto.erase(puesto_id)   # su ventanilla acaba de cerrar: fin de jornada, a casa
	var en_activo: bool = (
		dotado and estado != &"descansando"
		and (not cerrado or _en_su_puesto.has(puesto_id))
		and not oculto_por_regreso and not oculto_por_llegada
	)
	policia.visible = en_activo
	var lbl_nombre: Label = contenedor.get_node("Nombre")
	lbl_nombre.visible = estado == &"descansando" or (dotado and estado != &"cerrado")
	lbl_nombre.text = nombre
	var lbl_estado: Label = contenedor.get_node("Estado")
	lbl_estado.text = ROTULO_ESTADO.get(estado, String(estado).to_upper())
	lbl_estado.modulate = COLOR_ESTADO.get(estado, Color.WHITE)
	# Los minutos van en SU PROPIA etiqueta (ver comentario en `_asegurar_visual_puesto`): "Estado" ya
	# NO le añade un salto de línea — así su bloque mide siempre una línea, dotado o no de café, y no
	# puede crecer hacia la franja del nombre.
	var lbl_extra: Label = contenedor.get_node("Extra")
	lbl_extra.visible = extra != ""
	lbl_extra.text = extra
	lbl_extra.modulate = COLOR_ESTADO.get(estado, Color.WHITE)
	# Barra de cansancio: MISMA condición que el muñeco (`en_activo`) — quien está de café ya tiene
	# su rótulo con la cuenta atrás, y un puesto sin dotar o cerrado no tiene a nadie a quien medir.
	var barra_fondo: ColorRect = contenedor.get_node("BarraCansancioFondo")
	var barra_relleno: ColorRect = contenedor.get_node("BarraCansancioRelleno")
	barra_fondo.visible = en_activo
	barra_relleno.visible = en_activo
	if en_activo:
		var fraccion: float = clampf(cansancio, 0.0, 100.0) / 100.0
		barra_relleno.size.x = ANCHO_BARRA_CANSANCIO * fraccion
		barra_relleno.color = _color_cansancio(cansancio)


## Reconstruye el cuerpo del "Policia" de un puesto cuando cambia DE QUIÉN es. Si hay sprites del
## policía que le toca (género determinista por el nombre, ver `_prefijo_oficial_de`), se sienta
## MIRANDO al ciudadano, en la silla que ya dibuja la mesa (`MesaAtencionScript.
## CELDA_FUNCIONARIO`, la misma que usa `SillaFuncionario`) y con el mostrador dibujándose DESPUÉS
## (por encima): le tapa las piernas, como en una ventanilla de verdad — para lo que estaba pensado
## `ALTO_MESA` desde el principio (ver su comentario en `mesa_atencion.gd`: "para que el
## funcionario se vea de medio cuerpo por encima").
##
## SIN sprites (o sin nombre: puesto vacío) se conserva el muñeco de piezas de siempre, DE PIE en
## la MISMA celda norte (`MesaAtencionScript.CELDA_FUNCIONARIO` — regla de rejilla 2026-08-02, ver
## ese fichero) y dibujado POR ENCIMA del mostrador: es el acomodo que ya corrigió el bug histórico
## "se pone en la mesa y tapa al funcionario" (ver `_asegurar_visual_puesto`) — un muñeco de pie no
## cabe sentado en la silla sin la pose de verdad, así que aquí NO se le toca la geometría.
##
## El orden de dibujo (`move_child`) solo se toca si el MODO cambió de verdad (meta
## `policia_sentado` en el contenedor): repetir el mismo modo dos veces seguidas no debe intercambiar
## mesa/policía otra vez, o quedarían permutados sin motivo.
func _reconstruir_cuerpo_policia(contenedor: Node2D, policia: Node2D, nombre: String) -> void:
	for hijo: Node in policia.get_children():
		hijo.queue_free()
	var prefijo: String = _prefijo_oficial_de(nombre) if nombre != "" else ""
	var con_sprite: bool = prefijo != "" and MunecoScript.hay_sprites(prefijo, ALTO_SPRITE_OFICIAL)
	if con_sprite:
		policia.add_child(MunecoScript.construir_sprite_sentado(
			prefijo, ALTO_SPRITE_OFICIAL, DIRECCION_POLICIA_SENTADO
		))
		# CELDA_FUNCIONARIO + alzado del sentado (usuario 2026-08-03: la cabeza a la altura del
		# monitor) — ver ambas constantes en `mesa_atencion.gd`. El alzado es SOLO del muñeco.
		policia.position = MesaAtencionScript.CELDA_FUNCIONARIO + MesaAtencionScript.ALZADO_SENTADO_FUNCIONARIO
	else:
		_anadir_cuerpo_policia(policia)
		policia.position = MesaAtencionScript.CELDA_FUNCIONARIO
	if contenedor.get_meta(&"policia_sentado", false) != con_sprite:
		contenedor.set_meta(&"policia_sentado", con_sprite)
		# POR CAPAS, nunca con `move_child` sueltos (ADR-0005): lo unico que cambia entre modos es a
		# QUE capa va cada nodo. Sentado: el mostrador delante, tapandole las piernas. De pie: el
		# muneco es mas alto que el mostrador y va el delante. La silla del funcionario (FONDO) y la
		# del ciudadano (FRENTE_SUR) no se tocan: su capa no depende del modo.
		var mesa: Node2D = contenedor.get_node("Mesa")
		_insertar_en_capa(contenedor, policia, CAPA_PERSONAJE if con_sprite else CAPA_FRENTE)
		_insertar_en_capa(contenedor, mesa, CAPA_FRENTE if con_sprite else CAPA_PERSONAJE)


## Color del RELLENO de la barra de cansancio, por tramo. Reutiliza tonos que YA existen en este
## archivo — nunca uno nuevo: el ámbar es LITERALMENTE `COLOR_ESTADO[&"descansando"]`, el mismo que
## pinta el rótulo "☕ DESCANSO" (un único "ámbar de aviso" en toda la pantalla, no dos matices para
## la misma idea); el rojo crítico es el mismo que el ánimo "al_limite" de paciencia (mismo
## significado: cuidado, esto se acaba). Por debajo del umbral de aviso, el verde de "LIBRE".
func _color_cansancio(cansancio: float) -> Color:
	if cansancio >= UMBRAL_CANSANCIO_CRITICO:
		return COLOR_ANIMO[&"al_limite"]
	elif cansancio >= UMBRAL_CANSANCIO_AVISO:
		return COLOR_ESTADO[&"descansando"]
	return COLOR_ESTADO[&"libre"]


## Una Label decorativa de ancho fijo (60 px) y centrada: mismo tamaño ocupe lo que ocupe el texto
## (evita saltos de layout entre "LIBRE" y "ATENDIENDO"). IGNORA el ratón (gotcha de construcción).
func _label_centrada(tam_fuente: int, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", tam_fuente)
	lbl.size = Vector2(60, 0)
	lbl.position = pos
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
