class_name ConfigPersonal extends Resource
## ConfigPersonal — los tuning knobs de Personal (GDD staff-agents §Tuning Knobs), data-driven.
##
## Igual que `ConfigDemanda`: el `.tres` (`res://datos/config/personal.tres`) se genera SIEMPRE por
## herramienta (`tools/build_config_personal.gd`), nunca a mano. Personal lo carga con fallback seguro
## a estos defaults + clamp defensivo con aviso.
##
## Los salarios BASE (60/70) los posee el CATÁLOGO (`TipoAgente.salario_dia_eur`) — aquí solo primas.
##
## ⚠️ Erratilla del GDD anotada (story-001): la tabla Tuning da `k_motivacion=0.05` genérico, pero la
## fórmula F3 usa 0.1 → se separan en DOS knobs fieles a las fórmulas (F2: 0.05 · F3: 0.1).
##
## Story: production/epics/personal/story-001-agente-y-formulas.md · TR-staff-001 · ADR-0003

## Cuánto encarece la calidad el salario (F1): prima = 1 + k × (media_atributos − 3)/2. Semilla 0.5.
@export var k_calidad: float = 0.5
## Prima de rango del Oficial sobre el salario (F1). Semilla 1.3 (el mando cuesta más).
@export var prima_rango_oficial: float = 1.3
## Peso de la Rapidez en la duración efectiva (F2). Semilla 0.1 (crack 0.8× · torpe 1.2× antes de Mot).
@export var k_rapidez: float = 0.1
## Modulación de la Motivación sobre la Rapidez (F2). Semilla 0.05 (leve — MVP sin fatiga, PA10).
@export var k_motivacion_rapidez: float = 0.05
## Peso del Trato en el factor de satisfacción (F3). Semilla 0.25 (Trato 5 → ×1.5 · Trato 1 → ×0.5).
@export var k_trato: float = 0.25
## Modulación de la Motivación sobre el Trato (F3). Semilla 0.1 (leve).
@export var k_motivacion_trato: float = 0.1
## Probabilidad base de ausencia diaria a Salud media (F4). Semilla 0.03 (3 %).
@export var base_ausencia: float = 0.03
## Pendiente de la ausencia por punto de Salud (F4). Semilla 0.02 (Salud 1 → 7 % · Salud 5 → 0 %).
@export var k_salud: float = 0.02
## Coste de despedir (PA6). Semilla 0 (MVP: despido libre).
@export var coste_despido: float = 0.0

# ── Cansancio y descansos (Bienestar #13, story bien-001) ────────────────────────────────────
## Minutos de ATENCIÓN que aguanta un funcionario antes de necesitar su descanso, si solo se toma
## una pausa. Quien parte su descanso en dos (motivación 5) se agota a la mitad de camino: el aguante
## efectivo se reparte entre sus pausas. 180 min ≈ una jornada de mañana despachando sin respiro.
@export var minutos_aguante: int = 180
## Pausa corta, la del que hace "15 y 15" (motivación 5).
@export var min_pausa_corta: int = 15
## Pausa reglamentaria de un tirón (motivación 3-4): la media hora que le corresponde.
@export var min_pausa_normal: int = 30
## Lo que se toma el CARADURA (motivación 1-2): el doble de lo que puede, y lo sabe.
@export var min_pausa_caradura: int = 60
## Cuánto más cansa atender en horas extra (peonada de Documentación #8): alargar la tarde no solo
## cuesta dinero, también quema a la gente. 1.5 = una hora de peonada cansa como hora y media.
@export var mult_cansancio_horas_extra: float = 1.5
## Lo que se alarga la pausa SIN sala de descanso construida: se van a la calle y tardan más en
## volver. 1.5 = la media hora se convierte en tres cuartos. La sala no es obligatoria —la partida
## arranca sin ella—, pero construirla se nota en cuánto tiempo tienes la ventanilla parada.
@export var mult_pausa_sin_sala: float = 1.5
## Cuánto se ralentiza un funcionario AGOTADO (Bienestar #13). 0.25 = con la barra a tope tarda un
## 25 % más en cada trámite. Es progresivo: a media barra, un 12,5 %. El cansancio no solo manda a la
## gente a descansar — mientras aguantan, rinden peor, y eso se nota en la cola antes que el café.
@export var k_cansancio_rendimiento: float = 0.25

# ── Calidad de la sala de descanso (bien-005, petición del usuario 2026-07-29) ───────────────
## Cuánto ACORTA la pausa cada punto de calidad instalada en la sala de descanso (sofá, máquina de
## café, nevera…). 0.024 = cada punto recorta un 2,4 % del café. Sala pelada = 1.0 (nada cambia);
## sin sala, `mult_pausa_sin_sala`.
##
## **Por qué 0.024 y no un redondo**: el catálogo de descanso suma **12,5 puntos** con los seis
## objetos (prensa 1 + sillas 1 + agua 1,5 + nevera 2 + café 3 + sofá 4), y 12,5 × 0.024 = **0,30
## exacto** → el multiplicador aterriza justo en el suelo de 0,7 con la sala COMPLETA. Con el 0.03
## original se tocaba el suelo a los ~10 puntos y **los dos últimos muebles no hacían nada**: quien
## los comprara todos pagaba de más (y mantenimiento eterno) por cero efecto. Ajuste del usuario
## 2026-07-29 al ver el número: que cada compra cuente hasta la última.
@export var k_confort_pausa: float = 0.024
## Suelo del multiplicador: por muy montada que esté la sala, la pausa nunca baja de aquí. 0.7 = un
## 30 % menos como mucho. El tope existe para que el sistema NO pierda su tensión — el epic entero
## nace de que la ventanilla se queda sola, y un descanso de 5 minutos no obligaría a decidir nada.
@export var mult_pausa_min: float = 0.7
## Plazas de descanso que da la sala VACÍA, sin muebles: uno de pie, apoyado en la pared. Existe para
## que una sala recién construida no bloquee a nadie; las plazas de verdad se compran (sofá 3,
## sillas 2). Si no hay sitio, el que necesita café **sigue atendiendo** hasta que quede libre.
@export var plazas_descanso_base: int = 1
## Minutos de juego que tarda un funcionario en recorrer UNA celda al ir a la sala de descanso.
## 2.67 = el mismo paso que ya usa Flujo para el camino del ciudadano (`velocidad_camino_celdas_min`
## 0.375 celdas/min, que es 1/0.375 = 2.67 min por celda), dicho del derecho. Petición del usuario
## 2026-07-29: el café **empieza a contar cuando llega**, así que este trayecto es tiempo de ausencia
## AÑADIDO — y por tanto poner la sala de descanso cerca de las ventanillas tiene premio. 0 = llega
## al instante (comportamiento anterior).
@export var min_por_celda_a_descanso: float = 2.67
## Cada cuántas horas de reloj se renueva el cupo de cafés de cada agente. 8 = tres turnos al día
## (00-08 / 08-16 / 16-24), el turno clásico del CNP.
##
## **Por qué existe** (bug reportado por el usuario 2026-07-29: *"en la odac el funcionario lleva con
## la línea roja de cansancio mucho tiempo y sigue atendiendo"*): el cupo de pausas era POR JORNADA,
## así que un agente de ODAC —servicio que no cierra nunca— gastaba su única pausa y se quedaba con
## la barra al máximo **hasta 18 horas de juego**, rindiendo un 25 % peor y sin poder hacer nada.
## Con el cupo por turno, cada 8 h vuelve a tener derecho a su café. Documentación no se entera: su
## jornada (08:00-14:30) cabe entera en un turno, así que allí sigue siendo una pausa al día.
##
## Es además el primer ladrillo del **sistema de turnos** que pidió el usuario (turnos de reloj
## mañana/tarde/noche): cuando ese sistema exista, heredará esta misma idea.
@export var horas_por_turno: int = 8
## Minutos de cortesia con que el funcionario quiere estar YA en su ventanilla antes de que abra.
## Peticion del usuario 2026-07-29: *"hay que calcular lo que tarda a su puesto y de ahi calcular
## cuanto tiempo de antelacion tiene que llegar antes con 5 minutos de margen antes"*. Sale de casa
## a la hora de apertura MENOS lo que tarde en cruzar la comisaria MENOS estos 5 minutos.
@export var margen_llegada_min: float = 5.0

# ── Mercado de fichajes (story 002 — knobs ya definidos aquí, patrón ConfigDemanda) ──────────
## Candidatos que ofrece el mercado (F5). Semilla 4.
@export var n_candidatos: int = 4
## Jornadas entre regeneraciones completas del mercado (F5; decisión propuesta story-002). Semilla 3.
@export var refresco_mercado_jornadas: int = 3
## Probabilidad de que un candidato sea Oficial (decisión propuesta story-002 — el GDD no fija de
## dónde sale el Oficial; sin esto no habría forma de ficharlo). Semilla 0.2.
@export var prob_candidato_oficial: float = 0.2
## Pool de nombres para candidatos (Open Q5 del GDD: pool fijo español en el MVP; RNG elige de aquí).
@export var pool_nombres: Array[String] = [
	"Ana Ruiz", "Carlos Vega", "Lucía Ortega", "Javier Molina", "María Serrano", "Pablo Iglesias",
	"Carmen Duarte", "Sergio Navarro", "Elena Castro", "Miguel Herrera", "Laura Campos",
	"David Fuentes", "Sara Medina", "Andrés Pardo", "Isabel Rojas", "Óscar Delgado",
	"Nuria Blanco", "Raúl Cano", "Teresa Gil", "Hugo Márquez", "Silvia Peña", "Alberto Lara",
	"Patricia Soto", "Jorge Rivas",
]
