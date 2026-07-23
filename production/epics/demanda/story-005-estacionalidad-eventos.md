# Story 005: Estacionalidad anual y eventos de demanda

> **Epic**: Generación de Demanda
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/demand-generation.md` (DG13 — perfil estacional; DG11 — eventos multi-día; F3 — la mezcla que inclinan)
**Requirement**: `TR-demand-001` *(parcial — modulación del volumen/mezcla que genera)*
*(Texto del requisito en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0001 (primario — evento ordenado `nuevo_mes`: **Demanda = prioridad 30**, tras Economía 10 y Paciencia 20), ADR-0002 (secundario — sin azar nuevo: activación **determinista** por calendario)
**ADR Decision Summary**: `nuevo_mes` va por `registrar_ordenado`; el orden fijado por ADR-0001 es Economía(10)→Paciencia(20)→Demanda(30).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. Tiempo ya expone `mes`/`semana`/`anio` y dispara `nuevo_mes` tras `nuevo_dia` en la misma jornada (calendario semanal: 1 jornada = 1 semana, 4 semanas = 1 mes).

**Control Manifest Rules (Core)**:
- Required: `registrar_ordenado(&"nuevo_mes", 30, ...)`. — ADR-0001
- Required: multiplicadores y eventos **en config** (`demanda.tres`), deterministas — nada de RNG en la activación. — ADR-0002 / data-driven.

---

## Acceptance Criteria

*Del GDD, acotados a esta historia:*

- [ ] **AC-DM14** `[Integration]` — GIVEN un evento "vacaciones" activo WHEN se genera THEN sube la proporción/tasa de `pasaporte` (Doc) y `permiso_viaje` (ODAC) frente al perfil regular.
- [ ] *(DG13, derivado)* — GIVEN el mes de Tiempo WHEN `nuevo_mes` THEN el `mult_estacional[mes]` se aplica a la demanda de **Documentación** (Jun/Jul/Ago/Dic ×1.5 · Ene/Feb ×0.6 · resto ×1.0) y el **nivel** (DG12) se reevalúa (verano → ALTA, enero → BAJA con las semillas).

---

## Implementation Notes

- **DG13 — capa determinista**: `mult_estacional: Dictionary[int, float]` en config = {1:0.6, 2:0.6, 6:1.5, 7:1.5, 8:1.5, 12:1.5, resto:1.0}. Se aplica en `demanda_dia` de **Doc solamente** (el GDD lo define sobre Documentación), **encima** del perfil intradía/semanal y **por debajo** de los eventos DG11. En `_al_nuevo_mes` (prio 30): leer `tiempo.mes`, fijar el mult vigente, reevaluar nivel (señal de la 004 si cambia de tramo).
- **DG11 — mecanismo genérico de eventos** (catálogo = tuning, Open Q8; semilla mínima):
  config `eventos: Array[Dictionary]` (o Resource anidable por id — mantenerlo simple: Dictionary tipado en ConfigDemanda) con:
  `{id: &"vacaciones", meses_inicio: [6, 12], duracion_jornadas: 3, mult_peso: {&"pasaporte": 2.0, &"permiso_viaje": 3.0}}`.
  - **Activación determinista**: en `_al_nuevo_mes`, si `mes ∈ meses_inicio` → evento activo con `jornadas_restantes = duracion_jornadas`.
  - **Decremento**: en `_al_nuevo_dia` (handler prio 40 ya existente, 003) → `jornadas_restantes -= 1`; a 0 → desactivar.
  - **Efecto sobre la mezcla**: `mezcla_efectiva[tramite] = peso_base × mult_peso.get(tramite, 1.0)` — y se pasa tal cual a `elegir_ponderado` (que normaliza; **no** renormalizar a mano). Así "sube la proporción" sin tocar los pesos base.
  - Los picos pueden saturar capacidad *instantánea* (cola = reto) pero no cambian la *sostenida* fuera del evento → R5 intacto (DG7/DG11).
- **Un solo evento activo a la vez** en MVP (si coincidieran, gana el primero por orden de config + `push_warning`) — simplificación explícita; ampliar es tuning futuro.
- Estado nuevo a serializar en la 006: mult vigente (derivable del mes — NO guardar), `evento_activo_id` + `jornadas_restantes` (sí guardar).

---

## Out of Scope

- El **aviso al jugador** del evento/temporada (UI/Feedback — Presentation).
- El catálogo completo de eventos y su tuning fino (Open Q8 — playtest).
- `mult_dia_semana` variable por jornada (default 1.0; tuning post-playtest).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **DG13**: Given mes=6 (junio) → When `nuevo_mes` (disparo ordenado real vía bus) → Then `demanda_dia_doc` = 45 × 1.5 = 67.5 y el nivel pasa a ALTA (1 señal). Given mes=1 → Then 27 y BAJA. Given mes=4 → Then 45 y MEDIA.
- **AC-DM14**: Given evento "vacaciones" activo y semilla fija → When 2000 elecciones Doc → Then frecuencia(`pasaporte`) > su frecuencia sin evento (0.35 base → ≈0.52 con mult 2.0: 0.70/1.35); ídem `permiso_viaje` en ODAC. When el evento expira (3 `nuevo_dia`) → Then las frecuencias vuelven al perfil regular.
- **Activación/expiración**: Given mes=12 → Then evento activo con 3 jornadas; tras 3 `nuevo_dia` → inactivo. Given mes=5 → nunca se activa.
- **Orden**: espías con prio 29/31 en `nuevo_mes` verifican que Demanda corre en 30.
- Edge: `mult_peso` sobre un `tramite_id` inexistente en la mezcla → se ignora con `push_warning` (no rompe la elección).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/demanda/demanda_estacional_test.gd` — debe existir y pasar (BLOCKING). *(AC-DM14 usa el bus real para `nuevo_mes` → si el archivo acaba necesitando árbol de escena completo, puede vivir en `tests/integration/demanda/` — decidirlo al implementar.)*
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (nivel a reevaluar) — DONE antes de empezar.
- Unlocks: Story 006 (serializa el estado del evento).
