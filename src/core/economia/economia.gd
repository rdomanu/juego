class_name Economia extends Node
## Economia — la caja de la comisaría (sistema Core; NODO del mundo, NO autoload — arquitectura §3.4).
##
## Story 001 del epic: el núcleo — saldo único (`saldo_eur`, E1), config data-driven (`ConfigEconomia`,
## E8) y los GATES de gasto voluntario (`puede_pagar`/`cobrar`/`abonar`, E4) que usarán Construcción y
## Personal. El saldo SOLO muta por esta API (y por los flujos internos de stories posteriores: ingresos
## DGP, cierre diario, préstamos).
##
## El bus se INYECTA (`usar_bus()`, patrón de tiempo.gd): en runtime se auto-resuelve al autoload
## `EventBus`; los tests pasan su propia instancia (aislamiento). Sin bus no emite (fallback seguro).
##
## Story: production/epics/economia/story-001-nucleo-saldo-gates.md · TR-economy-004 · ADR-0001/0002

## Ruta del config de tuning (generado por tools/build_config_economia.gd; fallback a defaults si falta).
const RUTA_CONFIG := "res://datos/config/economia.tres"
const ConfigEconomiaScript := preload("res://src/core/economia/config_economia.gd")

## La caja (E1): estado mutable de partida. Arranca en `caja_inicial_eur` al aplicar el config.
var saldo_eur: float = 0.0

# ── Tuning knobs (copiados del config con clamp; ver aplicar_config) ─────────────────────────
var interes_deuda_diario: float = 0.02
var deuda_max_eur: float = 1000.0
var importe_prestamo_eur: float = 1500.0
var penalizacion_fija_prestamo: float = 30.0
var pct_ingreso_prestamo: float = 0.20
var num_prestamos_max: int = 3
var ventana_gracia_insolvencia_horas: float = 12.0
var umbral_holgura_ui: float = 500.0

## El EventBus al que se emiten los avisos (inyectable; auto-resuelto en _ready). Puede ser null en tests.
var _bus: Node = null


func _ready() -> void:
	if _bus == null:
		_bus = get_node_or_null("/root/EventBus")
	_cargar_config()


## Inyecta el EventBus (dependency injection → testeable sin el autoload real). Solo reasigna.
func usar_bus(bus: Node) -> void:
	_bus = bus


# ── Gates de gasto voluntario (E4 — la API que usan Construcción/Personal) ──────────────────

## ¿Hay caja para un gasto voluntario de `coste`? (E4: nunca te endeudas construyendo/contratando.
## En números rojos —saldo < 0— siempre es false, lo que implementa el bloqueo de E5.)
func puede_pagar(coste: float) -> bool:
	return saldo_eur >= coste and coste >= 0.0


## Gasto VOLUNTARIO: descuenta `coste` solo si pasa el gate. Devuelve si se aplicó. Emite `saldo_cambiado`.
func cobrar(coste: float) -> bool:
	if not puede_pagar(coste):
		return false
	saldo_eur -= coste
	_emitir_saldo()
	return true


## Abona `cantidad` a la caja (ingresos, reembolsos, inyecciones). Emite `saldo_cambiado`.
func abonar(cantidad: float) -> void:
	saldo_eur += cantidad
	_emitir_saldo()


# ── Config (E8 — data-driven, patrón ConfigTiempo) ──────────────────────────────────────────

## Aplica un ConfigEconomia (inyectable en tests, sin tocar disco). Clamp defensivo con aviso: todos los
## knobs ≥ 0 (`num_prestamos_max` entero ≥ 0) — un dato corrupto no rompe la economía (Edge Cases del GDD).
## Fija el saldo inicial en `caja_inicial_eur` (nueva partida; cargar partida lo sobreescribe después).
func aplicar_config(config: Resource) -> void:
	if config == null or not (config is ConfigEconomiaScript):
		push_warning("Economia: config invalido -> defaults")
		config = ConfigEconomiaScript.new()
	saldo_eur = _clamp_knob(config.caja_inicial_eur, "caja_inicial_eur")
	interes_deuda_diario = _clamp_knob(config.interes_deuda_diario, "interes_deuda_diario")
	deuda_max_eur = _clamp_knob(config.deuda_max_eur, "deuda_max_eur")
	importe_prestamo_eur = _clamp_knob(config.importe_prestamo_eur, "importe_prestamo_eur")
	penalizacion_fija_prestamo = _clamp_knob(config.penalizacion_fija_prestamo, "penalizacion_fija_prestamo")
	pct_ingreso_prestamo = _clamp_knob(config.pct_ingreso_prestamo, "pct_ingreso_prestamo")
	num_prestamos_max = int(_clamp_knob(float(config.num_prestamos_max), "num_prestamos_max"))
	ventana_gracia_insolvencia_horas = _clamp_knob(
		config.ventana_gracia_insolvencia_horas, "ventana_gracia_insolvencia_horas")
	umbral_holgura_ui = _clamp_knob(config.umbral_holgura_ui, "umbral_holgura_ui")


## Carga el `.tres` real con fallback seguro (falta/inválido → defaults con aviso; no peta).
func _cargar_config() -> void:
	var config: Resource = null
	if ResourceLoader.exists(RUTA_CONFIG):
		config = load(RUTA_CONFIG)
	if config == null:
		push_warning("Economia: no se pudo cargar '%s' -> defaults" % RUTA_CONFIG)
	aplicar_config(config)


## Clampa un knob a ≥ 0 con aviso si venía fuera de rango (patrón Datos/Tiempo).
func _clamp_knob(valor: float, nombre: String) -> float:
	if valor < 0.0:
		push_warning("Economia: knob '%s' fuera de rango (%f) -> 0" % [nombre, valor])
		return 0.0
	return valor


## Emite `saldo_cambiado(saldo_eur)` por el bus inyectado (si lo hay).
func _emitir_saldo() -> void:
	if _bus != null:
		_bus.saldo_cambiado.emit(saldo_eur)
