class_name ConfigEconomia extends Resource
## ConfigEconomia — los tuning knobs de Economía (GDD economy-budget §Tuning Knobs), data-driven (E8).
##
## Igual que `ConfigTiempo`: un Resource tipado cuyo `.tres` (`res://datos/config/economia.tres`) se
## genera SIEMPRE por herramienta (`tools/build_config_economia.gd`), nunca a mano. Economía lo carga al
## entrar en escena con fallback seguro a estos defaults + clamp defensivo con aviso.
##
## Los valores que NO están aquí (tarifas, salarios, peonada, retorno_dgp_min/max) los posee el CATÁLOGO
## (Datos) — este config solo lleva los knobs propios de Economía.
##
## Story: production/epics/economia/story-001-nucleo-saldo-gates.md · TR-economy-004 · ADR-0001/0002

## Caja inicial de la partida, en euros (E1). Semilla 3000 (una oficina modesta + colchón).
@export var caja_inicial_eur: float = 3000.0
## Recargo diario sobre la deuda de APERTURA del día (F5). Semilla 0.02 (2 %/día).
@export var interes_deuda_diario: float = 0.02
## Suelo de insolvencia: con `saldo ≤ −deuda_max_eur` entra el rescate/game over (E9). Semilla 1000.
@export var deuda_max_eur: float = 1000.0
## Efectivo que inyecta un préstamo del Comisario Y coste de saldarlo (E9). Semilla 1500.
@export var importe_prestamo_eur: float = 1500.0
## Parte FIJA de la penalización diaria por préstamo vivo (F8). Semilla 30.
@export var penalizacion_fija_prestamo: float = 30.0
## Parte % de la penalización: mordida sobre el ingreso de Documentación del día, por préstamo vivo (F8). Semilla 0.20.
@export var pct_ingreso_prestamo: float = 0.20
## Salvavidas máximos EN TODA LA PARTIDA (sobre `prestamos_usados`; devolver no recupera). Semilla 3.
@export var num_prestamos_max: int = 3
## Horas de JUEGO de la ventana de gracia tras rechazar el rescate (E9). Semilla 12.
@export var ventana_gracia_insolvencia_horas: float = 12.0
## Umbral cosmético del HUD: por debajo, el saldo se muestra como "justo" (UI). Semilla 500.
@export var umbral_holgura_ui: float = 500.0
