# Story 002: Datos autoload — carga + lookup por `id`

> **Epic**: Datos y Configuración
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija `/dev-story` al empezar)

## Context

**GDD**: `design/gdd/data-config.md` (R0 data-driven, R1 def≠instancia)
**Requirement**: `TR-data-001` (catálogo desde fuente externa), `TR-data-002` (def read-only), `TR-data-004`
(lookup por `id` en runtime)

**ADR Governing Implementation**: ADR-0003: Formato del catálogo (.tres Resource)
**ADR Decision Summary**: al arrancar se cargan los `.tres` con `load()`/`preload()`, se **indexan por `id`**
en diccionarios por tipo, y se resuelven con `Datos.obtener(tipo, id)` → definición **read-only** (los
sistemas nunca la mutan; crean sus instancias aparte, R1).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `load()` de Resources (sin parsear). Iterar una carpeta con `DirAccess`. `Datos` es el
**3º** autoload (orden `EventBus → RNGService → Datos → Tiempo → SaveManager`); valida en `_ready` (Story 003).

**Control Manifest Rules (Foundation)**:
- Required: orden de autoloads con `Datos` 3º; `Datos.obtener(tipo, id)` devuelve **read-only**; indexar por `id`.
- Forbidden: **nunca mutar** lo que devuelve `Datos.obtener` (plantilla compartida); nunca hardcodear valores
  de juego (leerlos del catálogo por `id`).

---

## Acceptance Criteria

*De GDD R0/R1, F1 y AC-D01/D02/D03:*

- [ ] Autoload `Datos` (`extends Node`) registrado como **3º** (tras `RNGService`).
- [ ] Al `_ready`, carga todos los `.tres` de `res://datos/<carpetas>` y los **indexa por `id`** en
      diccionarios por tipo (TramiteDoc, DenunciaODAC, TipoPuesto, TipoSala, TipoAgente, Costes, Escenario).
- [ ] `obtener(tipo: StringName, id: StringName) -> Resource` devuelve la definición; si no existe, devuelve
      una **definición nula segura** (o `null`) **con log**, sin romper.
- [ ] `obtener_todos(tipo: StringName) -> Array` devuelve todas las definiciones de ese tipo.
- [ ] **AC-D01**: cargado el catálogo, `dni`=(12 min, 12 €), `pasaporte`=(15, 30), `tie`=(15, 18).
- [ ] **AC-D02**: editar `tarifa_eur` de `dni` en el `.tres` (sin tocar código) → al recargar, `obtener`
      devuelve el nuevo valor.
- [ ] **AC-D03**: varios sistemas que resuelven `dni` por `id` obtienen **los mismos valores** (fuente única).

---

## Implementation Notes

- Cargar por carpeta (`DirAccess.get_files` sobre `res://datos/tramites/`, etc.) o por un índice; `load(ruta)`.
- Indexar: `_por_tipo: Dictionary` = `{ &"TramiteDoc": { &"dni": <Resource>, ... }, ... }`.
- `obtener` NO copia ni muta: devuelve la referencia read-only (la disciplina "no mutar" está en el manifest;
  los consumidores crean instancias aparte).
- **Dependencia de datos para el test**: el test de integración necesita **al menos un catálogo mínimo en
  disco**. Opciones: (a) usar el catálogo real de la Story 004; (b) un pequeño *fixture* de test. Ambos se
  generan con el **script-herramienta** (ver Story 004) para evitar escribir `.tres` a mano.

## Out of Scope

- **Story 001**: definir las clases (aquí solo se cargan/indexan).
- **Story 003**: la validación en carga (`validar()`).
- **Story 004**: el contenido del catálogo de Pozuelo.
- **SaveManager epic**: tolerancia a `id` huérfano al cargar un save (AC-D19).

## QA Test Cases

*Integration — carga desde disco + lookup. Requiere un catálogo (fixture o el real de 004) en `res://datos/`.*

- **AC-1 (AC-D01)**: cargar el catálogo → `Datos.obtener(&"TramiteDoc", &"dni").duracion_min == 12` y
  `.tarifa_eur == 12`; ídem `pasaporte`(15,30), `tie`(15,18).
- **AC-2 (lookup inexistente)**: `Datos.obtener(&"TramiteDoc", &"no_existe")` devuelve nulo seguro/`null`
  **sin romper** (y registra log).
- **AC-3 (obtener_todos)**: `Datos.obtener_todos(&"DenunciaODAC").size() == 13`.
- **AC-4 (AC-D03, fuente única)**: dos llamadas a `obtener(&"TramiteDoc", &"dni")` devuelven la **misma
  instancia** de definición (misma referencia read-only).

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/datos/datos_carga_lookup_test.gd` — debe existir y pasar.

**Status**: [ ] Not yet created

## Dependencies

- Depends on: **Story 001** (clases) + un catálogo en disco (Story 004 o fixture).
- Unlocks: que todos los sistemas resuelvan definiciones por `id`.
