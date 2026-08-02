class_name Proyeccion
## Proyeccion — la ÚNICA traducción entre el plano lógico (cuadrado) y lo que se ve (isométrico).
##
## Cambio de rumbo 2026-07-30: el juego pasa de vista CENITAL a ISOMÉTRICA ("quiero un theme
## hospital con la misma visualización"). Este fichero es la pieza raíz de esa conversión.
##
## ── LA IDEA, EN LLANO ──────────────────────────────────────────────────────────────────────
## Hay DOS planos, y no son el mismo:
##
##  · **El plano lógico (cuadrado)**: la comisaría vista desde arriba, celdas de 40×40 px. Aquí
##    viven la rejilla del modelo, la NAVEGACIÓN (por dónde se puede andar), las distancias y las
##    velocidades de los muñecos. **Nada de esto cambia con la conversión** — está calibrado y
##    probado por los 643 tests, y sigue siendo la verdad.
##  · **El plano de pantalla (isométrico)**: lo que el jugador VE. Cada celda cuadrada se dibuja
##    como un rombo de 80×40 px, girado 45° y aplastado a la mitad.
##
## `proyectar()` traduce del primero al segundo (para DIBUJAR) y `desproyectar()` del segundo al
## primero (para saber dónde has hecho CLIC). Es la misma comisaría contada de dos maneras: como
## un plano de arquitecto y como una foto en perspectiva.
##
## ── POR QUÉ ASÍ Y NO "PONIENDO EL TILEMAP EN ISOMÉTRICO" ────────────────────────────────────
## La alternativa (que todo el juego —navegación incluida— viviera ya en coordenadas isométricas)
## parece más corta, pero rompe algo calibrado: en el plano isométrico, andar "en diagonal hacia
## abajo" recorre 40 px mientras andar "en diagonal hacia el lado" recorre 80 px. A la misma
## velocidad en píxeles por segundo, un ciudadano cruzaría celdas al DOBLE de ritmo según hacia
## dónde ande, y los cronómetros del modelo (que cuentan CUADRÍCULAS, no píxeles) dejarían de
## cuadrar con lo que se ve. Es exactamente la familia de bugs de "el ciudadano plantado en ODAC".
##
## Manteniendo la navegación en el plano cuadrado, la velocidad es la misma en toda dirección y
## no se toca ni una línea del modelo. ADR-0004 llevado a su conclusión: *el visual refleja el
## modelo, jamás al revés*.
##
## ── LAS CUENTAS ────────────────────────────────────────────────────────────────────────────
## Con celda cuadrada `TAM_CELDA` = 40 y rombo `ANCHO`×`ALTO` = 80×40, las fórmulas se simplifican
## a algo que se puede comprobar de cabeza (ANCHO/2 = TAM_CELDA y ALTO/2 = TAM_CELDA/2):
##
##     iso.x = cuad.x - cuad.y
##     iso.y = (cuad.x + cuad.y) / 2
##
## Las cuatro esquinas de la celda (0,0) — que en cuadrado son (0,0) (40,0) (40,40) (0,40) —
## pasan a ser (0,0) (40,20) (0,40) (-40,20): el rombo. Su centro, (20,20) en cuadrado, cae en
## (0,20), que es justo el centro del rombo. ✓
##
## Sin dependencias (solo Vector2 entra y sale): por eso vive en `foundation/` y puede usarla
## cualquier capa sin invertir la dirección de dependencias.

## Lado de una celda en el plano LÓGICO cuadrado, en píxeles. Es el valor histórico del proyecto
## (`Main.TAM_CELDA`) y NO cambia con la conversión: la navegación y las velocidades siguen
## calibradas contra este número.
const TAM_CELDA: int = 40

## Ancho del rombo isométrico en pantalla, en píxeles (art bible §8: proporción estándar 2:1).
const ANCHO_ROMBO: int = 80
## Alto del rombo isométrico en pantalla, en píxeles (la mitad del ancho — eso es el "2:1").
const ALTO_ROMBO: int = 40

## Medio rombo, precalculado: es el paso que da un desplazamiento de UNA celda en cada eje.
const MEDIO_ANCHO: float = ANCHO_ROMBO / 2.0
const MEDIO_ALTO: float = ALTO_ROMBO / 2.0


## Del plano LÓGICO cuadrado a la PANTALLA isométrica. Úsala para colocar cualquier cosa que se
## dibuje: suelos, paredes, mostradores, muñecos, rótulos, luces.
static func proyectar(punto_cuadrado: Vector2) -> Vector2:
	var u: float = punto_cuadrado.x / TAM_CELDA   # columna continua (puede tener decimales)
	var v: float = punto_cuadrado.y / TAM_CELDA   # fila continua
	return Vector2((u - v) * MEDIO_ANCHO, (u + v) * MEDIO_ALTO)


## De la PANTALLA isométrica al plano LÓGICO cuadrado. Úsala para todo lo que venga del RATÓN:
## un clic te da un punto de pantalla, y el modelo solo entiende el plano cuadrado.
##
## Es la inversa EXACTA de `proyectar` (no una aproximación): despejando el sistema de dos
## ecuaciones de arriba sale `u = iso.x/ANCHO + iso.y/ALTO` y `v = iso.y/ALTO - iso.x/ANCHO`.
static func desproyectar(punto_iso: Vector2) -> Vector2:
	var u: float = punto_iso.x / ANCHO_ROMBO + punto_iso.y / ALTO_ROMBO
	var v: float = punto_iso.y / ALTO_ROMBO - punto_iso.x / ANCHO_ROMBO
	return Vector2(u * TAM_CELDA, v * TAM_CELDA)


## El CENTRO de una celda, en el plano lógico cuadrado. (La proyección isométrica de este punto
## es el centro del rombo.)
static func centro_cuadrado(celda: Vector2i) -> Vector2:
	return Vector2(
		(float(celda.x) + 0.5) * TAM_CELDA,
		(float(celda.y) + 0.5) * TAM_CELDA
	)


## El centro de una celda, ya en PANTALLA isométrica (el centro del rombo).
static func centro_iso(celda: Vector2i) -> Vector2:
	return proyectar(centro_cuadrado(celda))


## El DESPLAZAMIENTO en pantalla (un delta, no una posición absoluta) de recorrer `celdas - 1`
## pasos de una celda en la dirección `paso` del plano lógico cuadrado (`Vector2i(1,0)` este /
## `Vector2i(0,1)` sur — la misma convención de `Construccion._celdas_de`/`_paso_de`).
##
## Para qué existe (regla verificada con composites, 2026-08-02): un SPRITE de mobiliario
## compuesto de varias celdas (`render_mobiliario.gd`) se dibuja con su ancla en la ÚLTIMA celda
## de su cuerpo, no en la celda donde el modelo pone el ancla lógica — al revés que `PiezaIso`
## (la caja de código), que SÍ ancla ahí y crece hacia +X/+Y desde ese punto (ver su cabecera).
## Sumar este delta al `centro_iso` del ancla lógica da el punto de pantalla donde colgar el
## sprite. Con `celdas` = 1 el delta es `Vector2.ZERO`, así que la misma llamada vale para
## mobiliario de 1 celda sin distinguir casos con un `if` por mueble — es la ÚNICA fuente de esta
## cuenta; la comparten `Construccion` (comodidades multi-celda) y `MesaAtencion` (el mostrador).
static func delta_ultima_celda(paso: Vector2i, celdas: int) -> Vector2:
	return centro_iso(paso * maxi(celdas - 1, 0)) - centro_iso(Vector2i.ZERO)


## La celda que contiene un punto del plano lógico cuadrado. `floor` y no `int()`: con
## coordenadas negativas (la calle está a la izquierda del edificio, en x negativa) `int(-0.5)`
## daría 0 y `floor(-0.5)` da -1, que es la celda correcta.
static func celda_de_cuadrado(punto_cuadrado: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(punto_cuadrado.x / TAM_CELDA)),
		int(floor(punto_cuadrado.y / TAM_CELDA))
	)


## La celda bajo un punto de PANTALLA isométrica. Es el camino completo del ratón al modelo:
## pantalla → plano cuadrado → celda.
static func celda_de_iso(punto_iso: Vector2) -> Vector2i:
	return celda_de_cuadrado(desproyectar(punto_iso))


## El VÉRTICE de la rejilla en la intersección (columna, fila), en PANTALLA isométrica.
##
## Ojo a la diferencia con `centro_iso`: aquí (columna, fila) NO es una celda, es una esquina
## —una intersección de las líneas de la rejilla—. Las paredes viven en las ARISTAS entre celdas
## (decisión de modelo del 2026-07-30), así que se dibujan de vértice a vértice, no de centro a
## centro. La esquina (0,0) es la de arriba de la celda (0,0); la (1,1), la de abajo.
static func esquina_iso(columna: int, fila: int) -> Vector2:
	return proyectar(Vector2(float(columna) * TAM_CELDA, float(fila) * TAM_CELDA))


## Los cuatro vértices del rombo de una celda, en PANTALLA isométrica y en orden (arriba, derecha,
## abajo, izquierda). Para pintar el suelo de una celda como polígono o resaltarla en el preview.
static func rombo_de_celda(celda: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		esquina_iso(celda.x, celda.y),
		esquina_iso(celda.x + 1, celda.y),
		esquina_iso(celda.x + 1, celda.y + 1),
		esquina_iso(celda.x, celda.y + 1),
	])


## La PROFUNDIDAD de un punto para ordenar el dibujo: en isométrico, lo que está más abajo en
## pantalla tapa a lo que está detrás. Es sencillamente la Y proyectada, expuesta con nombre
## propio porque es un concepto del juego ("quién tapa a quién"), no una coordenada cualquiera.
static func profundidad(punto_cuadrado: Vector2) -> float:
	return proyectar(punto_cuadrado).y


## La proyección, empaquetada como `Transform2D` de Godot, con el origen de la rejilla en
## `origen`. Es LA MISMA cuenta que `proyectar()`, expresada de la forma que entiende el motor.
##
## Para qué sirve: si a un nodo se le pone esta transformada, TODO lo que cuelgue de él se dibuja
## ya proyectado, sin tocar ni una coordenada. Es la forma barata de convertir el SUELO (que se
## pinta pegado al terreno y por tanto sí debe deformarse con él): un `TileMapLayer` cuadrado
## corriente, con esta transformada encima, pinta rombos perfectos — y su `local_to_map` sigue
## respondiendo en celdas, así que el clic sigue funcionando solo.
##
## ⚠️ NO se la pongas a personajes, mostradores ni rótulos: esos NO están pintados en el suelo,
## están DE PIE sobre él, y deformarlos los dejaría tumbados. Esos se colocan uno a uno con
## `proyectar()` y se quedan derechos.
static func transformada(origen: Vector2) -> Transform2D:
	# Columna X: una celda hacia el este avanza (1, 0.5). Columna Y: una hacia el sur, (-1, 0.5).
	return Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), origen)


## El tamaño que ocupa un tablero de `columnas`×`filas` celdas una vez proyectado, en píxeles de
## pantalla. Sirve para centrarlo en la ventana (el rombo total es MÁS ANCHO y MÁS BAJO que el
## tablero cuadrado equivalente: un tablero de 24×13 pasa de 960×520 a 1480×740).
static func tamano_tablero(columnas: int, filas: int) -> Vector2:
	return Vector2(float(columnas + filas) * MEDIO_ANCHO, float(columnas + filas) * MEDIO_ALTO)


## Dónde hay que poner el ORIGEN de la rejilla (la esquina (0,0)) para que un tablero de
## `columnas`×`filas` quede centrado dentro de un área de `tamano_area` píxeles.
##
## El detalle que hace falta: en isométrico la esquina (0,0) NO es la esquina superior izquierda
## del dibujo, sino el vértice de ARRIBA del rombo grande — y de ahí el tablero se abre hacia la
## izquierda `filas` medios-anchos. Por eso hay que empujarlo a la derecha esa cantidad.
static func origen_centrado(columnas: int, filas: int, tamano_area: Vector2) -> Vector2:
	var tablero: Vector2 = tamano_tablero(columnas, filas)
	return Vector2(
		(tamano_area.x - tablero.x) / 2.0 + float(filas) * MEDIO_ANCHO,
		(tamano_area.y - tablero.y) / 2.0
	)
