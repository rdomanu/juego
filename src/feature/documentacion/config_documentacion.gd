class_name ConfigDocumentacion extends Resource
## ConfigDocumentacion — los tuning knobs del servicio de Documentación (GDD `documentation.md`
## §Tuning Knobs). Esta story (001) trae los del HORARIO y la ÚLTIMA ADMISIÓN; el catálogo de eventos
## de la División llega en la 004 (como recursos propios del catálogo, no como knobs de aquí).
##
## El `.tres` (`res://datos/config/documentacion.tres`) se genera SIEMPRE por herramienta
## (`tools/build_config_documentacion.gd`), nunca a mano. Documentación lo carga con fallback + clamps.
##
## ⚠️ Estos valores los fija **la División de Documentación** (el órgano superior, DO2): son el marco
## dentro del cual el jugador decide. El jugador NO edita este `.tres` — mueve el slider, y el slider
## se mueve dentro de este rango.
##
## Story: production/epics/documentacion/story-001-servicio-reloj-config.md · TR-doc-001 · ADR-0003

## Minuto del día en que abre Documentación (DO3). 480 = 08:00. **Mismo hecho** que
## `ventana_doc_inicio` de Demanda y que el `apertura_doc_min` que ejecuta Flujo (registro de
## entidades): desde este epic, el dueño es Documentación y los demás lo reciben.
@export var apertura_base_min: int = 480
## Minuto del día en que cierra la jornada BASE, sin peonada (DO3). 870 = 14:30 (390 min de mañana).
## Ampliar por encima de esta hora es lo que cuesta peonada (DO4, story 003).
@export var cierre_base_min: int = 870
## Extremo inferior del rango autorizado por la División para el slider. 480 = 08:00.
## Restricción del GDD: `slider_min ≤ apertura_base`.
@export var slider_min_min: int = 480
## Extremo superior ORDINARIO del slider: hasta aquí puede alargar el jugador sin evento (DO3).
## 1200 = 20:00. Solo un evento de la División (story 004) autoriza pasar de aquí (hasta 21:30).
@export var slider_max_min: int = 1200
## Minutos antes del cierre en que se deja de dar número (F3, DO5) — la palanca **exprimir vs cuidar**.
## Rango seguro 0–30, default 15: con 15 el personal sale a su hora; con 0 se exprime hasta el cierre
## y quien se queda terminando fuera de hora **se desmotiva** (story 003).
@export var margen_ultima_admision_min: int = 15
# ── El precio de la hora extra (petición del usuario 2026-07-28) ─────────────────────────────
## Lo que el jugador paga por hora de peonada. **Pagar más cansa menos**: la hora extra se lleva
## mejor si va bien pagada (lo aplica Personal en su fórmula de cansancio). Arranca en el mínimo.
@export var peonada_eur_hora: float = 15.0
## El suelo: la peonada REGLAMENTARIA, lo que la División obliga a pagar como mínimo. Con este pago,
## la hora extra cansa lo máximo (×1.5 en Personal).
@export var peonada_eur_hora_min: float = 15.0
## El techo. **30 €/h no es un número redondo cualquiera**: es donde la hora extra deja de dar
## beneficio. Un agente atendiendo a buen ritmo genera ~20-30 €/hora (5 DNI/h × 12 € × retorno DGP),
## así que por encima de 30 estarías pagando por el privilegio de que trabajen. El tope existe para
## que no se puedan escribir cifras absurdas, no para impedir una mala decisión: dentro del rango, el
## jugador puede perder dinero si quiere.
@export var peonada_eur_hora_max: float = 30.0
## Si la partida arranca con el horario ya ampliado (DO4). `false` = el jugador decide cada día;
## `true` = amplía siempre (y paga peonada aunque la demanda sea BAJA).
@export var peonada_activa_por_defecto: bool = false
