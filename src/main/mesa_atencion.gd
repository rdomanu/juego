extends Node
## MesaAtencion — la mesa de una ventanilla, con su ordenador y sus papeles.
##
## Encargo del usuario (2026-07-31): *"diseña la mesa de trabajo para que se vea una mesa para
## atender a la gente, que sale ahora un cuadrado en una cuadrícula; pon un ordenador apuntando al
## policía y algunos papeles"*.
##
## ── CÓMO ESTÁ MONTADA ─────────────────────────────────────────────────────────────────────────
## Todo son cajas isométricas (`PiezaIso`) apiladas. La mesa es un cuerpo bajo y ancho, y encima de
## su tablero se colocan las cosas: el ordenador del lado del funcionario y los papeles del lado del
## ciudadano, que es exactamente como está una ventanilla de verdad.
##
##   ┌ (arriba-derecha) ── el FUNCIONARIO ── ordenador, teclado
##   │
##   │   ▧ TABLERO
##   │
##   └ (abajo-izquierda) ── el CIUDADANO ── papeles, para firmar
##
## ── EL DETALLE QUE MÁS SE NOTA ────────────────────────────────────────────────────────────────
## La pantalla **mira al policía**, así que desde la cámara del juego se ve el DORSO del monitor,
## no la pantalla. Es lo correcto y además es lo que uno reconoce al instante de cualquier
## ventanilla: al ciudadano nunca se le enseña la pantalla. Se marca con un canto claro en el borde
## de arriba para que se lea "monitor" y no "caja".

const PiezaIsoScript := preload("res://src/foundation/proyeccion/pieza_iso.gd")

## Alto del cuerpo de la mesa. Por debajo de la cintura del muñeco (28 px de alto) para que el
## funcionario se vea de medio cuerpo por encima, como en una ventanilla.
const ALTO_MESA: float = 14.0
## Cuánto de su celda ocupa la mesa. 0.78: un mueble ancho, pero que deja ver el suelo alrededor —
## si llenara el rombo entero, el funcionario de la casilla de atrás parecería subido encima.
const ESCALA_MESA: float = 0.78
const COLOR_TABLERO := Color(0.45, 0.36, 0.28)      # madera de oficina

## El monitor: alto, estrecho y oscuro. Va del lado del funcionario.
const ALTO_MONITOR: float = 11.0
const ESCALA_MONITOR: float = 0.20
const COLOR_MONITOR := Color(0.13, 0.14, 0.17)
## Desplazamiento hacia el lado del FUNCIONARIO, en píxeles de pantalla, SOLO para la decoración
## que va ENCIMA del tablero (teclado/monitor/papeles del mostrador de código — ver `construir()`).
## Media casilla en el eje Y de la rejilla, que proyectada es arriba y a la derecha (ver
## `Proyeccion`). NO es la posición de la silla ni de quien se sienta — para eso, ver
## `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` más abajo (regla de rejilla, 2026-08-02).
const DECOR_HACIA_FUNCIONARIO := Vector2(14.0, -7.0)
## Y el del CIUDADANO, al otro lado: abajo y a la izquierda.
const DECOR_HACIA_CIUDADANO := Vector2(-13.0, 6.5)

const ALTO_TECLADO: float = 1.5
const ESCALA_TECLADO: float = 0.26
const COLOR_TECLADO := Color(0.22, 0.23, 0.26)

## Los papeles: casi planos, claros, y DOS montones ligeramente descolocados — un solo rectángulo
## perfecto en medio de la mesa se lee como una baldosa, no como papeles.
const ALTO_PAPEL: float = 1.0
const ESCALA_PAPEL: float = 0.17
const COLOR_PAPEL := Color(0.90, 0.89, 0.84)


## ── LA SILLA (2026-08-01) ──────────────────────────────────────────────────────────────────────
## Petición del usuario: *"en los puestos de atención debe haber 1 silla en cada puesto y en la sala
## de espera también"*. Y tiene sentido más allá de lo decorativo: si los personajes se sientan (ya
## tienen su pose), hace falta algo debajo o parecen flotando.
##
## Dos piezas: el asiento y el respaldo. Con el respaldo se lee "silla" incluso a tamaño diminuto;
## sin él, es un taburete o una caja.
const ALTO_ASIENTO_SILLA: float = 7.0
const ALTO_RESPALDO: float = 11.0
const ESCALA_SILLA: float = 0.42
const COLOR_SILLA := Color(0.30, 0.32, 0.38)


## ── SPRITE DEL MOSTRADOR: 1 CELDA (legado) Y 2 CELDAS (2026-08-02) ────────────────────────────
## Igual que el muñeco del policía (`muneco.gd::hay_sprites`): si hay un render 3D del pack de
## oficina para el mostrador (`tools/render_mobiliario.gd`), se dibuja ESE en vez de las cajas de
## código. El sprite ya trae su propio monitor, teclado, ratón y teléfono montados encima, así que
## Tablero/Teclado/Monitor/Papeles/Papeles2 SOBRAN con él puesto — se decidió MIRANDO el render (un
## papel no pinta nada sobre un escritorio de madera que ya trae su propio teléfono). Las SILLAS
## siguen siendo de código: no vinieron en este render.
##
## DOS sprites, no uno, desde que el puesto pasó a ocupar 2 celdas de verdad (ver la cabecera de
## `Construccion` — "LA HUELLA DEL PUESTO: 2 CELDAS"): `ID_SPRITE_MOSTRADOR_2` para el caso normal
## y `ID_SPRITE_MOSTRADOR` (el de 1 celda de siempre) SOLO para la excepción de huella legado — un
## puesto de una partida guardada que no cabe en 2 celdas de hoy (`Construccion.es_huella_legado`).
## `construir()` elige uno u otro con `es_legado`.
const RUTA_SPRITES_MOBILIARIO := "res://assets/sprites/mobiliario/"
const ID_SPRITE_MOSTRADOR := "mostrador_atencion"
const ID_SPRITE_MOSTRADOR_2 := "mostrador_atencion2"
## Solo 0° por ahora: los puestos de atención SIEMPRE se construyen con la misma orientación fija
## (`CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` no dependen de `orientacion` — `Construccion._crear_
## pieza` ni se la pasa a los puestos), así que no hace falta elegir entre las 4 rotaciones
## renderizadas. 0° es la que se vio, mirando las 4: el monitor de espaldas a cámara (nunca se le
## enseña la pantalla al ciudadano, ver la cabecera del fichero) y sin nada raro en el encuadre.
const ROT_MOSTRADOR: int = 0
## Dónde cae el ANCLA (el centro del rombo de la celda, el mismo punto que usa
## `Proyeccion.centro_iso`) dentro del PNG, como fracción de su ancho/alto. Re-renderizados los DOS
## el 2026-08-02 (60×60 el de 1 celda, 120×120 el de 2 celdas). CORREGIDAS el mismo día: la
## fracción que imprimía `render_mobiliario.gd` al renderizar era el CENTRO DEL ENCUADRE, no el
## ancla real — el coordinador derivó la fracción correcta midiendo la BASE de cada PNG. Con la
## base como referencia, los dos sprites NO comparten fracción (encuadres distintos): una
## constante por cada uno.
const ANCLA_FRACCION_MOSTRADOR := Vector2(0.521, 0.727)      # 1 celda (legado)
const ANCLA_FRACCION_MOSTRADOR_2 := Vector2(0.825, 0.703)    # 2 celdas (monitor CENTRADO, lienzo 100×74)

## ── ANCLAS DE CELDA DE LA VENTANILLA (2026-08-02, MEDIO PASO desde 2026-08-03) ────────────────
## Regla del usuario, viendo el juego: *"la mesa debe ocupar 1 o 2 cuadrículas, las sillas 1, y
## todos los elementos deben ocupar de 1 en 1 cuadrícula; no coincide donde se sientan los
## ciudadanos con donde está la silla; las sillas no están en la misma línea que la mesa"*.
##
## Sustituye a los ajustes de píxel a mano de la calibración anterior (`HACIA_FUNCIONARIO_SPRITE`/
## `HACIA_CIUDADANO_SPRITE`, borrados): esos números no caían en el centro de ninguna celda ni
## coincidían con el punto donde el juego sienta de verdad a la gente. La ventanilla son TRES
## celdas en fila en el plano LÓGICO cuadrado (ver `NPCsFlujo._asegurar_visual_puesto`): el
## funcionario detrás (norte), el mostrador en medio (la celda del puesto en el modelo) y el
## ciudadano delante (sur, `NPCsFlujo._frente_del_puesto` = `centro_de_celda(celda + Vector2i(0,
## 1))`).
##
## DECISIÓN DEL USUARIO (2026-08-03, variante C del fotomontaje): la gente de la ventanilla se
## ARRIMA AL BORDE de su celda que mira al mostrador — silla y persona JUNTAS, pegadas al
## mostrador en vez de centradas en su cuadrícula. La celda LÓGICA del modelo **no cambia**
## (ADR-0004: flujo, turnos y navegación siguen anclando a la celda entera —
## `NPCsFlujo._frente_del_puesto` sigue devolviendo el centro de la celda sur completa—); lo que
## se mueve es solo el punto VISUAL del asiento.
##
## ── CUÁNTO ES "AL BORDE" (corregido 2026-08-03, 2º aviso del usuario) ─────────────────────────
## El primer intento movió el asiento MEDIO paso de celda, y medio paso pone el CENTRO de la silla
## justo EN la frontera entre celdas: media silla se le mete al mostrador, que es lo que la regla
## de rejilla prohíbe. "Al borde" es que la silla TOQUE la frontera sin cruzarla, o sea que su
## BASE quepa entera en su celda:
##
##     arrime = medio paso − medio fondo de la silla
##
## El fondo se mide en el PNG, sobre la base (las patas), y se pasa a celdas dividiendo por el
## ancho del rombo (una huella cuadrada de lado `s` celdas proyecta un rombo de `s`×80 px de
## ancho). Medido el 2026-08-03 sobre los renders actuales: silla de espera 31 px y silla del
## funcionario 33 px de base ⇒ 0,3875 y 0,4125 celdas de fondo ⇒ arrimes de 0,306 y 0,294 pasos
## (≈ 0,3, casi el mismo para las dos: son dos sillas de oficina del mismo tamaño).
##
## Cada silla —y quien se sienta en ella— ancla a estas constantes como ÚNICA fuente de verdad: es
## el mismo offset que usa el policía DE PIE (`NPCsFlujo._reconstruir_cuerpo_policia`, rama sin
## sprite) y el sentado (misma función, rama con sprite), y el que aplica al ciudadano
## `NPCsFlujo.colocar_muneco` vía `DESVIO_DIBUJO_CIUDADANO`. Persona y silla, siempre juntas.
const FONDO_BASE_SILLA_ESPERA_PX: float = 31.0
const FONDO_BASE_SILLA_FUNCIONARIO_PX: float = 33.0
## El fondo de cada silla en CELDAS (huella cuadrada de lado `s`: proyecta `s`×ANCHO_ROMBO px).
const FONDO_SILLA_ESPERA: float = FONDO_BASE_SILLA_ESPERA_PX / Proyeccion.ANCHO_ROMBO        # 0,3875
const FONDO_SILLA_FUNCIONARIO: float = FONDO_BASE_SILLA_FUNCIONARIO_PX / Proyeccion.ANCHO_ROMBO  # 0,4125
## Y el arrime resultante, en PASOS de celda (0,5 = la frontera; menos = dentro de su celda).
## RETROCESO_CIUDADANO (usuario 2026-08-03, mirando el juego): *"vamos a echar un poco más para
## atrás la silla del ciudadano, 1/4 de cuadrícula — ahora mismo está muy pegada"*. Se resta SOLO
## en el lado del ciudadano; el funcionario se queda donde estaba.
const RETROCESO_CIUDADANO: float = 0.25
const ARRIME_CIUDADANO: float = 0.5 - FONDO_SILLA_ESPERA / 2.0 - RETROCESO_CIUDADANO  # 0,05625
const ARRIME_FUNCIONARIO: float = 0.5 - FONDO_SILLA_FUNCIONARIO / 2.0     # 0,29375

## ALZADO del policía SENTADO (usuario 2026-08-03): *"subimos la altura donde está sentado el
## policía, le veo muy bajo — se le tiene que ver la cabeza a la altura del ordenador; no le hagas
## más grande"*. Píxeles de pantalla hacia ARRIBA, aplicados SOLO al muñeco sentado.
##
## ── HOY VALE CERO, Y ESO ES LA CURA, NO UN OLVIDO (2026-08-03, mismo día) ────────────────────
## El −25 se eligió cuando `CELDA_FUNCIONARIO` estaba mal (ver la cabecera de esa constante): el
## policía se dibujaba DENTRO de la celda del mostrador, o sea media celda MÁS ABAJO en pantalla de
## donde le toca, y por eso "se le veía muy bajo". El alzado era el parche, y funcionaba porque el
## mostrador —dibujado por encima— tapaba el hueco entre el muñeco levantado y su silla.
##
## Con el policía ya en SU celda norte, el alzado se SUMA al que ya le da la rejilla y lo deja
## FLOTANDO 25 px por encima del asiento, con el hueco a la vista (el mostrador ya no llega hasta
## ahí). Verificado A/B en el motor con `tools/_diag_ventanilla2.gd --  sin_alzado`: a cero se
## sienta sobre la silla Y la cabeza queda a la altura del monitor, que es literalmente lo que
## pedía el usuario. Se conserva la constante (no se borra la línea) porque es el mando para
## ajustar esa altura si alguna vez hace falta — hoy la rejilla ya la da bien.
const ALZADO_SENTADO_FUNCIONARIO := Vector2.ZERO

## ── ATENCIÓN CENTRADA EN EL MOSTRADOR (decisión del usuario, 2026-08-03) ─────────────────────
## Con solo el arrime de arriba, TODA la atención caía en la celda OESTE del mostrador de 2 celdas
## (la que pisan `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO`, ambas ancladas a la celda del puesto en el
## modelo). Viendo el mostrador ya colocado, el usuario pidió: *"pon la mesa justo en la mitad
## entre el asiento del policía y la silla del ciudadano; la atención puede ser en la mitad"*.
##
## Se resuelve corriendo a la gente (silla+persona juntas, los dos lados — ver la cabecera de
## arriba) MEDIO PASO DE CELDA hacia el ESTE en pantalla: de la celda OESTE del mostrador a la
## COSTURA entre sus 2 celdas. Medio paso es la mitad de `MEDIO_ANCHO`/`MEDIO_ALTO` (que YA es el
## paso de una celda completa), sumado al punto donde NACEN `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO`
## — los `ARRIME_*` al borde de la silla (arriba) no cambian, solo se traslada el conjunto entero.
const DESVIO_CENTRADO_ATENCION := Vector2(Proyeccion.MEDIO_ANCHO / 2.0, Proyeccion.MEDIO_ALTO / 2.0)

## ── DESDE DÓNDE SE MIDE EL ARRIME (bug corregido 2026-08-03, 3er aviso del usuario) ───────────
## Los `ARRIME_*` de arriba se miden **desde el centro de la celda de la PERSONA** hacia el
## mostrador (esa es su cuenta: medio paso menos medio fondo de silla, ver arriba). Pero
## `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO` se escriben en LOCAL del contenedor del puesto, y ese
## origen es el centro de la celda del MOSTRADOR: un paso entero más allá. Lo que hay que recorrer
## desde ahí es **`1 − ARRIME` pasos**, nunca `ARRIME` a secas.
##
## POR QUÉ ESTUVO MAL Y NO SE VIO (volcado en `tools/_diag_ventanilla2.gd`, captura del motor): el
## 2026-08-03 estas constantes fueron `paso × 0,5` — medio paso desde el mostrador. Medio paso es
## la FRONTERA entre las dos celdas, y la frontera cae en el mismo punto se mida desde el lado que
## se mida, así que el marco de referencia se cambió sin que el dibujo lo delatara. Al sustituir
## ese 0,5 por `ARRIME` (que se mide desde el extremo CONTRARIO) la silla del ciudadano se metió
## 0,44 celdas DENTRO del mostrador, y el `RETROCESO_CIUDADANO` de 0,25 —que existe justamente
## para separarla— la empujó otras 0,25 celdas ENCIMA de la mesa: silla y ciudadana subidas al
## tablero. Con `1 − ARRIME` el signo del retroceso vuelve a ser el que dice su comentario.
##
## Los dos pasos de celda EN PANTALLA, con nombre: es la misma cuenta de `Proyeccion.centro_iso`
## entre celdas vecinas en el eje norte-sur del plano lógico.
const PASO_NORTE := Vector2(Proyeccion.MEDIO_ANCHO, -Proyeccion.MEDIO_ALTO)
const PASO_SUR := Vector2(-Proyeccion.MEDIO_ANCHO, Proyeccion.MEDIO_ALTO)
const CELDA_FUNCIONARIO := (   # norte, detrás: su celda entera, menos el arrime al mostrador
	PASO_NORTE * (1.0 - ARRIME_FUNCIONARIO) + DESVIO_CENTRADO_ATENCION
)
const CELDA_CIUDADANO := (     # sur, delante: ídem por el otro lado
	PASO_SUR * (1.0 - ARRIME_CIUDADANO) + DESVIO_CENTRADO_ATENCION
)
## Del centro de la celda SUR (donde el modelo planta al ciudadano, `_frente_del_puesto`) al punto
## donde está su silla. Es el desvío de DIBUJO que le aplica `NPCsFlujo.colocar_muneco` mientras le
## atienden, para que se siente sobre la silla y no en el centro de la celda.
##
## Reescrita 2026-08-03 EN TÉRMINOS DE `CELDA_CIUDADANO` (antes: "un paso entero menos el arrime,
## con el signo cambiado", una cuenta paralela que duplicaba el arrime a mano). Si se hubiera
## dejado así, `DESVIO_CENTRADO_ATENCION` habría movido la silla sin mover al ciudadano —la MISMA
## familia de bug que ya avisa la cabecera de más arriba, "persona y silla, siempre juntas"—.
## Anclar la fórmula a la propia constante es la única forma de que no se puedan volver a separar:
## es LITERALMENTE "dónde está la silla menos dónde está el centro de la celda sur", y el centro de
## la celda sur, en local del contenedor, es `PASO_SUR`.
const DESVIO_DIBUJO_CIUDADANO := CELDA_CIUDADANO - PASO_SUR


## ¿Hay un sprite renderizado para este mostrador (`ID_SPRITE_MOSTRADOR` o `ID_SPRITE_MOSTRADOR_2`)?
static func hay_sprite_mostrador(id_sprite: String) -> bool:
	return ResourceLoader.exists(_ruta_sprite_mostrador(id_sprite))


static func _ruta_sprite_mostrador(id_sprite: String) -> String:
	return "%s%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, id_sprite, ROT_MOSTRADOR]


## El mostrador de sprite: un `Sprite2D` anclado por el mismo punto que las piezas de código (el
## centro de la celda, `Vector2.ZERO` en local) — no por su esquina ni por su centro geométrico.
## `ancla_fraccion`: `ANCLA_FRACCION_MOSTRADOR` (1 celda) o `ANCLA_FRACCION_MOSTRADOR_2` (2 celdas)
## según qué sprite se esté colocando — cada encuadre tiene la suya, ver la constante.
static func _pieza_sprite_mostrador(id_sprite: String, ancla_fraccion: Vector2) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Tablero"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	var textura: Texture2D = load(_ruta_sprite_mostrador(id_sprite))
	sprite.texture = textura
	sprite.offset = Vector2(
		-textura.get_width() * ancla_fraccion.x,
		-textura.get_height() * ancla_fraccion.y
	)
	raiz.add_child(sprite)
	return raiz


## ── SILLAS DE SPRITE (2026-08-01, 2ª tanda) ──────────────────────────────────────────────────
## La roja de OBJ_042 para el funcionario; la de espera (OBJ_023, la más repetida del pack —ver
## `render_mobiliario.gd`— la misma en TODAS las esperas, ventanillas incluidas) para el ciudadano
## y para `Construccion.ASIENTO_BASICO`. Mismo patrón que el mostrador: si no hay sprite, la silla
## de código de siempre.
const ID_SPRITE_SILLA_FUNCIONARIO := "silla_funcionario"
const ID_SPRITE_SILLA_ESPERA := "silla_espera"
## Cada silla, su PROPIA rotación — NO la misma para las dos: cada mueble tiene su frente en un
## sitio distinto de la escena de origen (ver `render_mobiliario.gd`). Elegidas MIRANDO las 4 con
## la silla VACÍA y flechas de referencia sobre la imagen (2º aviso del usuario 2026-08-02: la
## primera elección se hizo con un muñeco sentado ENCIMA que tapaba el asiento — así se coló el
## error; regla nueva: la dirección de un asiento se juzga con el asiento vacío):
##  · Funcionario: 180° — el asiento abre hacia ABAJO-IZQUIERDA de pantalla, hacia el ciudadano
##    (la misma dirección a la que da la cara de cajones del mostrador); el respaldo queda
##    arriba-derecha, a la espalda del policía, que se sienta mirando al sur.
##  · Espera: 270° — el asiento abre hacia ARRIBA-DERECHA, hacia la mesa; el respaldo queda hacia
##    cámara, a la espalda del ciudadano.
const ROT_SILLA_FUNCIONARIO: int = 180
const ROT_SILLA_ESPERA: int = 270
## Anclas actualizadas 2026-08-02 (nuevo re-render de todo el mobiliario — dato definitivo).
const ANCLA_FRACCION_SILLA_FUNCIONARIO := Vector2(0.493, 0.824)
const ANCLA_FRACCION_SILLA_ESPERA := Vector2(0.495, 0.797)


## ── LA SILLA DE ESPERA, PARTIDA EN DOS (2026-08-03) ──────────────────────────────────────────
## Por qué: en el frente de la ventanilla el ciudadano se sienta MIRANDO A LA MESA (de espaldas a
## cámara), así que lo correcto es que el RESPALDO le tape la zona lumbar. Con la silla entera solo
## caben dos órdenes y los dos mienten: la silla entera delante lo BORRA (probado con fotomontaje,
## ver ADR-0005) y detrás deja el respaldo escondido tras él. La solución es oclusión PARCIAL: dos
## sprites de la MISMA silla —asiento (patas+asiento) y respaldo— anclados en el MISMO punto, con
## el muñeco EN MEDIO.
##
## Solo hace falta la rotación 270 (la única que usa el frente de la ventanilla). Para el resto de
## usos (esperas normales, `Construccion.ASIENTO_BASICO`) sigue la silla ENTERA de siempre: ahí no
## hay nadie entre las dos mitades y partirla no aportaría nada.
##
## MIENTRAS NO EXISTAN LOS PNG, `hay_silla_espera_partida()` devuelve false y todo se comporta como
## hasta ahora (silla entera en `CAPA_FRENTE_SUR`, por debajo del sentado) — el cableado ya está
## puesto y se activa solo en cuanto aparezcan los ficheros.
const ID_SPRITE_SILLA_ESPERA_ASIENTO := "silla_espera_asiento"
const ID_SPRITE_SILLA_ESPERA_RESPALDO := "silla_espera_respaldo"
## Anclas DEFINITIVAS (2026-08-03): los dos PNG salieron con lienzos recortados a su propia caja
## (30×33 el asiento, 27×21 el respaldo), así que el coordinador localizó el ENCAJE exacto de cada
## pieza dentro de la silla entera por correlación de píxeles (asiento en offset +2,+10; respaldo
## en +0,+7 sobre el lienzo 34×44) y trasladó el ancla de la silla entera (0.495, 0.797) a cada
## encuadre. Verificado superponiendo: asiento+respaldo reconstruyen la silla entera sin fantasmas.
## La `y` del respaldo es >1 a propósito: su punto de anclaje (el suelo de la celda) queda por
## debajo de su recorte flotante.
const ANCLA_FRACCION_SILLA_ESPERA_ASIENTO := Vector2(0.494, 0.760)
const ANCLA_FRACCION_SILLA_ESPERA_RESPALDO := Vector2(0.623, 1.337)


## ¿Están renderizadas las DOS mitades de la silla de espera (rotación 270)? Con una sola no vale:
## media silla es peor que la silla entera.
static func hay_silla_espera_partida() -> bool:
	return (
		ResourceLoader.exists(_ruta_sprite_silla(ID_SPRITE_SILLA_ESPERA_ASIENTO, ROT_SILLA_ESPERA))
		and ResourceLoader.exists(
			_ruta_sprite_silla(ID_SPRITE_SILLA_ESPERA_RESPALDO, ROT_SILLA_ESPERA)
		)
	)


static func hay_sprite_silla_funcionario() -> bool:
	return ResourceLoader.exists(_ruta_sprite_silla(ID_SPRITE_SILLA_FUNCIONARIO, ROT_SILLA_FUNCIONARIO))


static func hay_sprite_silla_espera() -> bool:
	return ResourceLoader.exists(_ruta_sprite_silla(ID_SPRITE_SILLA_ESPERA, ROT_SILLA_ESPERA))


static func _ruta_sprite_silla(id_silla: String, rotacion: int) -> String:
	return "%s%s_%d.png" % [RUTA_SPRITES_MOBILIARIO, id_silla, rotacion]


## Una silla de sprite, anclada por el mismo punto que `silla()`: el sitio donde se sienta quien
## la usa (`Vector2.ZERO` en local), no su esquina.
static func _pieza_sprite_silla(id_silla: String, rotacion: int, ancla_fraccion: Vector2) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Silla"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	var textura: Texture2D = load(_ruta_sprite_silla(id_silla, rotacion))
	sprite.texture = textura
	sprite.offset = Vector2(
		-textura.get_width() * ancla_fraccion.x, -textura.get_height() * ancla_fraccion.y
	)
	raiz.add_child(sprite)
	return raiz


## La silla del FUNCIONARIO: sprite si lo hay, si no la de código de siempre.
static func silla_funcionario_o_defecto(hacia_atras: Vector2, color: Color = COLOR_SILLA) -> Node2D:
	if hay_sprite_silla_funcionario():
		return _pieza_sprite_silla(
			ID_SPRITE_SILLA_FUNCIONARIO, ROT_SILLA_FUNCIONARIO, ANCLA_FRACCION_SILLA_FUNCIONARIO
		)
	return silla(hacia_atras, color)


## La silla de ESPERA: sprite si lo hay, si no la de código de siempre. La usan el lado del
## ciudadano en la ventanilla Y `Construccion` para `ASIENTO_BASICO` (misma silla en los dos
## sitios, a propósito: es la MISMA silla de espera del edificio).
static func silla_espera_o_defecto(hacia_atras: Vector2, color: Color = COLOR_SILLA_ESPERA_DEFECTO) -> Node2D:
	if hay_sprite_silla_espera():
		return _pieza_sprite_silla(ID_SPRITE_SILLA_ESPERA, ROT_SILLA_ESPERA, ANCLA_FRACCION_SILLA_ESPERA)
	return silla(hacia_atras, color)


## Color de la silla de código de espera cuando no hay sprite — mismo tono que usaba
## `Construccion.COLOR_SILLA_ESPERA` antes de esta pasada (gris institucional cálido).
const COLOR_SILLA_ESPERA_DEFECTO := Color(0.38, 0.36, 0.34)


## Una silla mirando hacia `hacia_atras` (el respaldo se pone a ese lado). El vector va en píxeles
## de pantalla, así que se usan las mismas constantes de lado que la mesa.
static func silla(hacia_atras: Vector2, color: Color = COLOR_SILLA) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Silla"
	raiz.add_child(_pieza("Asiento", Vector2.ZERO, ALTO_ASIENTO_SILLA, ESCALA_SILLA, color))
	# El respaldo: más alto, más estrecho y desplazado al lado contrario de quien se sienta.
	raiz.add_child(_pieza(
		"Respaldo", hacia_atras * 0.30 - Vector2(0.0, ALTO_ASIENTO_SILLA),
		ALTO_RESPALDO, ESCALA_SILLA * 0.55, color.darkened(0.15)
	))
	return raiz


## ── MESA CENTRADA ENTRE LOS ASIENTOS (decisión del usuario, 2026-08-03) ──────────────────────
## La base del sprite de 2 celdas (`mostrador_atencion2`) mide ~0,44 celdas de FONDO (el eje
## perpendicular al mostrador), y hoy su esquina sur queda pegada al borde sur de sus celdas: toda
## la holgura (~0,56 celdas) cae al norte. Mismo pedido que `DESVIO_CENTRADO_ATENCION` de arriba
## — centrar la mesa entre el asiento del policía y la silla del ciudadano—, aplicado al MUEBLE en
## vez de a la gente: la mitad de esa holgura (0,28 celdas) se corre hacia el NORTE en pantalla.
##
## Solo al sprite de 2 celdas (`superficie == 2`, el caso normal desde 2026-08-02): el de 1 celda
## (huella legado, `es_legado`) no se ha vuelto a medir con esta regla y es una excepción de saves
## viejos, no del juego de hoy — tocarlo sin verificar sería inventar un número.
const DESVIO_CENTRADO_MESA := Vector2(0.28 * Proyeccion.MEDIO_ANCHO, -0.28 * Proyeccion.MEDIO_ALTO)
## Corrección A LO LARGO del eje del mostrador (2026-08-03, medida sobre la rejilla del diagnóstico
## de oclusión, caso C4): la masa del sprite asomaba ~0,4 celdas por el sureste de su huella y se
## quedaba ~0,37 corta por el noroeste. Desplazamiento de 0,38 pasos hacia el NOROESTE de pantalla
## (dirección −u: un paso al oeste lógico proyecta (−MEDIO_ANCHO, −MEDIO_ALTO)). Verificado
## re-lanzando el diagnóstico hasta asomos simétricos.
const DESVIO_CENTRADO_MESA_LARGO := Vector2(
	-0.38 * Proyeccion.MEDIO_ANCHO, -0.38 * Proyeccion.MEDIO_ALTO
)


## Monta la mesa completa. Se coloca en el CENTRO de la celda de TRABAJO (el ancla del modelo) y
## todo va en local. `es_legado`: el puesto es una huella legado de 1 celda
## (`Construccion.es_huella_legado`) — usa el sprite/tablero de 1 celda, sin desplazar; si no (el
## caso normal desde 2026-08-02), usa el de 2 celdas y desplaza SOLO el "Tablero" a la ÚLTIMA
## celda de su cuerpo: regla verificada por composites — un sprite a rotación 0 ancla en la celda
## ESTE de su cuerpo, no en la celda del modelo (`Proyeccion.delta_ultima_celda`, la MISMA cuenta
## que usa `Construccion` para sus comodidades multi-celda — no es un caso especial del
## mostrador). "Mesa" en sí se queda en el ancla del modelo (silla/policía siguen anclando ahí vía
## `CELDA_FUNCIONARIO`/`CELDA_CIUDADANO`, sin tocar); con 1 celda el delta es cero, así que el
## camino legado no necesita su propio `if` de posición. Al de 2 celdas, además, se le suma
## `DESVIO_CENTRADO_MESA` (ver esa constante) para centrarlo entre los dos asientos.
static func construir(es_legado: bool = false) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Mesa"
	# Superficie del cuerpo en celdas: 2 el caso normal (catálogo, `TipoPuesto.superficie`), 1 la
	# excepción de huella legado (`Construccion.SUPERFICIE_LEGADO`) — mismos números, sin importar
	# la constante para no acoplar este script de piezas visuales al core.
	var superficie: int = 1 if es_legado else 2
	var id_sprite: String = ID_SPRITE_MOSTRADOR if es_legado else ID_SPRITE_MOSTRADOR_2
	var ancla_mostrador: Vector2 = ANCLA_FRACCION_MOSTRADOR if es_legado else ANCLA_FRACCION_MOSTRADOR_2
	if hay_sprite_mostrador(id_sprite):
		var tablero: Node2D = _pieza_sprite_mostrador(id_sprite, ancla_mostrador)
		tablero.position = Proyeccion.delta_ultima_celda(Vector2i(1, 0), superficie)
		if not es_legado:
			tablero.position += DESVIO_CENTRADO_MESA + DESVIO_CENTRADO_MESA_LARGO
		raiz.add_child(tablero)
	else:
		raiz.add_child(_pieza("Tablero", Vector2.ZERO, ALTO_MESA, ESCALA_MESA, COLOR_TABLERO))
		# Todo lo que va ENCIMA se sube el alto de la mesa: si no, quedaría metido dentro del tablero.
		var encima := Vector2(0.0, -ALTO_MESA)
		# Del lado del funcionario: teclado delante y monitor detrás (él lo mira de frente).
		raiz.add_child(_pieza(
			"Teclado", encima + DECOR_HACIA_FUNCIONARIO * 0.55, ALTO_TECLADO, ESCALA_TECLADO, COLOR_TECLADO
		))
		raiz.add_child(_pieza(
			"Monitor", encima + DECOR_HACIA_FUNCIONARIO, ALTO_MONITOR, ESCALA_MONITOR, COLOR_MONITOR
		))
		# Del lado del ciudadano: los papeles que viene a firmar.
		raiz.add_child(_pieza(
			"Papeles", encima + DECOR_HACIA_CIUDADANO, ALTO_PAPEL, ESCALA_PAPEL, COLOR_PAPEL
		))
		raiz.add_child(_pieza(
			"Papeles2", encima + DECOR_HACIA_CIUDADANO + Vector2(6.0, 2.0), ALTO_PAPEL, ESCALA_PAPEL,
			COLOR_PAPEL.darkened(0.08)
		))
	# NINGUNA DE LAS DOS SILLAS vive aquí dentro: las dos son HERMANAS de "Mesa" en el contenedor
	# del puesto, cada una en SU CAPA con nombre (ADR-0005) — ver `silla_ciudadano()` abajo y
	# `NPCsFlujo._asegurar_visual_puesto`. La del funcionario salió el 2026-08-01 (aviso del
	# usuario: *"la silla, luego encima el policía, y luego la mesa tapando al policía y a la
	# silla"*) y la del ciudadano el 2026-08-03, por el mismo motivo de fondo: siendo NIETAS del
	# contenedor quedaban fuera del mecanismo de capas y su orden dependía del orden interno de
	# este nodo, que además se intercambia entero con el policía en `_reconstruir_cuerpo_policia`.
	return raiz


## LA SILLA DEL CIUDADANO, suelta y ya colocada — la cuelga `NPCsFlujo._asegurar_visual_puesto` en
## la capa `CAPA_FRENTE_SUR` del contenedor del puesto (ADR-0005), POR ENCIMA del mostrador.
##
## Por qué encima y no dentro de "Mesa" (bug del 2026-08-03, con captura): el mostrador de 2 celdas
## se dibuja desplazado a su celda ESTE (`Proyeccion.delta_ultima_celda`) y su PNG cae 82 px hacia
## la izquierda del ancla, así que TAPA la celda sur entera — justo donde están la silla de espera
## y el ciudadano al que atienden. Metida dentro de "Mesa" la silla dependía del orden interno de
## ese nodo (y ese nodo entero se permuta con el policía), y acababa saliendo DEBAJO del mostrador:
## silla y piernas ocultas, como si estuvieran subidos a la mesa. Con capa propia el orden es fijo:
## mostrador (FRENTE) < silla de espera (FRENTE_SUR).
##
## LA POSICIÓN usa `CELDA_CIUDADANO` (arrime de medio paso, ver la constante): el mismo punto al que
## mira el ciudadano cuando le atienden.
static func silla_ciudadano() -> Node2D:
	var del_ciudadano: Node2D = silla_espera_o_defecto(CELDA_CIUDADANO.normalized() * 20.0)
	del_ciudadano.name = "SillaCiudadano"
	del_ciudadano.position = CELDA_CIUDADANO
	return del_ciudadano


## El ASIENTO (patas + asiento) de la silla partida, ya colocado. Va en `CAPA_FRENTE_SUR`, como la
## silla entera: por encima del mostrador y por debajo de quien se sienta.
static func silla_ciudadano_asiento() -> Node2D:
	var asiento: Node2D = _pieza_sprite_silla(
		ID_SPRITE_SILLA_ESPERA_ASIENTO, ROT_SILLA_ESPERA, ANCLA_FRACCION_SILLA_ESPERA_ASIENTO
	)
	asiento.name = "SillaCiudadano"
	asiento.position = CELDA_CIUDADANO
	return asiento


## El RESPALDO de la silla partida, ya colocado — MISMA posición que el asiento (las dos mitades
## comparten punto de anclaje; lo que las separa es su fracción de ancla dentro de cada PNG). Va
## por ENCIMA del ciudadano sentado, para taparle solo la zona lumbar (ver `NPCsFlujo.
## CAPA_FRENTE_SUR_ALTO` / `Z_RESPALDO_FRENTE_SUR`).
static func silla_ciudadano_respaldo() -> Node2D:
	var respaldo: Node2D = _pieza_sprite_silla(
		ID_SPRITE_SILLA_ESPERA_RESPALDO, ROT_SILLA_ESPERA, ANCLA_FRACCION_SILLA_ESPERA_RESPALDO
	)
	respaldo.name = "SillaCiudadanoRespaldo"
	respaldo.position = CELDA_CIUDADANO
	return respaldo


static func _pieza(nombre: String, pos: Vector2, alto: float, escala: float, color: Color) -> Node2D:
	var p: Node2D = PiezaIsoScript.new()
	p.name = nombre
	p.position = pos
	p.configurar(1, 1, alto, color, escala)
	return p
