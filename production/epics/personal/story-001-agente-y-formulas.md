# Story 001: El Agente y sus fórmulas (F1–F4)

> **Epic**: Personal / Agentes
> **Status**: Implemented — 9/9 tests en verde (pendiente `/story-done`)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-24

## Context

**GDD**: `design/gdd/staff-agents.md` (PA1–PA3, PA10, F1–F4)
**Requirement**: `TR-staff-001` *(parcial — la instancia Agente y sus fórmulas; el mercado llega en la 002)*
*(Texto en `docs/architecture/tr-registry.yaml`)*

**Governing ADRs**: ADR-0003 (primario — config data-driven `.tres` por herramienta), ADR-0002 (secundario — sin azar aquí, pero los knobs alimentan las tiradas de 002/004)
**ADR Decision Summary**: valores de juego en Resources tipados generados por herramienta; el código lee por `id` del catálogo (`TipoAgente`: salario base 60/70, `puestos_operables`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: sin API post-cutoff. Gotchas del proyecto: preload por ruta en frío; clase de instancia como `RefCounted` (patrón ficha `Persona` de Demanda).

**Control Manifest Rules (Core)**:
- Required: data-driven (knobs en `datos/config/personal.tres`); tipado estático; sistemas Core = nodos del mundo.
- Forbidden: hardcodear valores de juego; autoloads para sistemas Core.

---

## Acceptance Criteria

- [ ] **AC-PE01** `[Unit]` — GIVEN un agente contratado THEN tiene `nombre`, `tipo`, `rango`, 4 atributos (1–5); si es Oficial, **Mando**.
- [ ] **AC-PE03** `[Unit]` — GIVEN Rapidez 5/Mot 4 THEN `modificador_produccion ≈ 0.76`; Rapidez 1/Mot 2 → `≈ 1.26` (F2, clamp [0.5, 1.3]).
- [ ] **AC-PE04** `[Unit]` — GIVEN `ag_doc` (base 60) media atributos 5 THEN `salario_dia = 90`; media 2 → 45; Oficial media 4 → 97.5 (F1).
- [ ] **AC-PE11** `[Unit]` — GIVEN Trato 5 THEN `factor_trato = 1.5`; Trato 3 → **1.0** (neutro); Trato 1 → **0.5** (F3 — multiplicador para Paciencia F2).
- [ ] **AC-PE12** `[Unit]` — GIVEN Salud 5 THEN `prob_ausencia = 0` (clamp); Salud 3 → 3 %; Salud 1 → 7 % (F4).
- [ ] **AC-PE18** `[Unit]` — GIVEN el MVP THEN la Motivación es atributo **base** (modula F2/F3 levemente), sin fatiga dinámica.
- [ ] **AC-PE20** `[Unit]` — GIVEN un atributo fuera de [1,5] THEN se **clampa**; los derivados se clampan (F2 [0.5,1.3], F3 [0.5,1.5], F4 [0,1]).

---

## Implementation Notes

- **`src/core/personal/agente.gd`** — `class_name Agente extends RefCounted` (instancia de partida, NO Resource del catálogo): `nombre: String`, `tipo_id: StringName` (ref a `TipoAgente`), `rango: StringName` (&"policia"/&"oficial"), `rapidez/trato/salud/motivacion: int` (1–5, clamp en setter o al crear), `mando: int` (0 si Policía), `estado: StringName` (&"libre"/&"asignado"/&"ausente"/&"cubriendo" — transiciones en 003/004), `puesto_id: StringName` (&"" si libre). Cero lógica de fórmulas (las posee el nodo Personal, que tiene los knobs).
- **`src/core/personal/personal.gd`** — nodo `class_name Personal extends Node` (patrón Demanda/Economía: `usar_bus`/inyección, `aplicar_config` con clamps, `_cargar_config`).
- **`src/core/personal/config_personal.gd`** + **`tools/build_config_personal.gd`** → `datos/config/personal.tres`. Knobs (GDD §Tuning): `k_calidad=0.5`, `prima_rango_oficial=1.3`, `k_rapidez=0.1`, `k_motivacion_rapidez=0.05`, `k_trato=0.25`, `k_motivacion_trato=0.1`, `base_ausencia=0.03`, `k_salud=0.02`, `coste_despido=0.0` + los de mercado (002: `n_candidatos=4`, `refresco_mercado_jornadas=3`, `prob_candidato_oficial=0.2`, pool de nombres).
  *(⚠️ Erratilla GDD anotada: la tabla Tuning da `k_motivacion=0.05` genérico, pero F3 usa 0.1 — se implementan los valores de las FÓRMULAS, separados en dos knobs.)*
- **Fórmulas** (funciones puras del nodo, reciben el Agente):
  `salario_dia(a)` = `salario_base(tipo, Datos) × (1 + k_calidad×(media_atributos−3)/2) × prima` (F1);
  `modificador_produccion(a)` = `clamp((1 − k_rapidez×(R−3)) × (1 − k_mot_rap×(M−3)), 0.5, 1.3)` (F2);
  `factor_trato(a)` = `clamp(1 + k_trato×(T−3) × (1 + k_mot_trato×(M−3)), 0.5, 1.5)` (F3);
  `prob_ausencia(a)` = `clamp(base_ausencia − k_salud×(S−3), 0, 1)` (F4).
- El rango extendido de F2 (`[0.5, 1.3]` — un mal fichaje rinde PEOR que 1.0) es la decisión 2026-07-21 que Flujo F1 consumirá.

---

## Out of Scope

- Story 002: mercado, contratación, despido. · Story 003: asignación/estados. · Story 004: evaluar ausencias. · Story 006: nómina real a Economía.

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-PE01**: Given Agente creado con todos los campos → Then los expone tipados; Oficial lleva `mando` ≥ 1; Policía `mando` = 0.
- **AC-PE03**: F2(R5,M4) = 0.8×0.95 = 0.76 (±0.001); F2(R1,M2) = 1.2×1.05 = 1.26; F2(R3,M3) = 1.0.
- **AC-PE04**: F1: media 5 → 90.0; media 2 → 45.0; Oficial media 4 → 97.5; `ag_odac` base 70 (del catálogo REAL) media 3 → 70.0.
- **AC-PE11**: F3(T5,M3) = 1.5; F3(T3,M*) = 1.0 (neutro con cualquier Motivación); F3(T1,M3) = 0.5.
- **AC-PE12**: F4(S5) = 0.0 (clamp); F4(S3) = 0.03; F4(S1) = 0.07.
- **AC-PE18**: F2/F3 con M5 vs M1 difieren (modulación existe) pero ≤ ~10 % (leve); no hay ningún estado de fatiga.
- **AC-PE20**: Agente creado con rapidez 9 → se clampa a 5; F2 con extremos artificiales nunca sale de [0.5,1.3].
- Config: el `.tres` real existe y trae las semillas; knob negativo → clamp con aviso (patrón Economía/Demanda).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/personal/personal_agente_formulas_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [x] Creado y en verde (9 tests; suite total 229/229, exit 0 — 2026-07-24)

---

## Dependencies

- Depends on: None (Foundation completa; catálogo TipoAgente ya existe).
- Unlocks: Story 002 (mercado).
