# Story 001: Esquema — clases Resource del catálogo

> **Epic**: Datos y Configuración
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `design/gdd/data-config.md` (R2 — tipos de definición)
**Requirement**: `TR-data-002` (Definición read-only ≠ Instancia; referencian por `id`)

**ADR Governing Implementation**: ADR-0003: Formato del catálogo (.tres Resource) *(primario)* · ADR-0002 *(sec.)*
**ADR Decision Summary**: catálogo = Custom Resources (`.tres`) con **clases tipadas** (`class_name` +
`@export`), jerarquía `Atencion` → `TramiteDoc`/`DenunciaODAC` + `TipoPuesto`/`TipoSala`/`TipoAgente`/
`Costes`/`Escenario`. **Referencias entre definiciones por `id` (`StringName`), NUNCA anidando Resources**
(evita el problema de `duplicate_deep` en 4.5 y permite validar integridad).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name`/`@export`/`@export_enum` estables. Referencias = `Array[StringName]` (ids), no
`Array[Resource]`. `class_name` se resuelve con el proyecto importado (usar `preload(...)` en tests si hiciera
falta en headless "en frío").

**Control Manifest Rules (Foundation)**:
- Required: catálogo = Custom Resources `.tres` tipados; jerarquía `Atencion`→`TramiteDoc`/`DenunciaODAC` +
  `TipoPuesto`/`TipoSala`/`TipoAgente`/`Costes`/`Escenario`.
- Forbidden: **nunca anidar Resources** (referenciar por `id`); nunca meter lógica de juego en el catálogo.
- Cross-cutting: tipado estático.

---

## Acceptance Criteria

*De GDD R2 (tabla de tipos) + ADR-0003 (Key Interfaces):*

- [x] `Atencion extends Resource` (`class_name Atencion`) con `@export`: `id: StringName`, `nombre: String`,
      `servicio` (`@export_enum("Documentacion","ODAC")`), `duracion_min: int`, `tipo_puesto: StringName`,
      `icono: Texture2D`.
- [x] `TramiteDoc extends Atencion` con `tarifa_eur: int`, `requiere_cita: bool`.
- [x] `DenunciaODAC extends Atencion` con `prioridad` (`@export_enum("Normal","Prioritaria")`),
      `admite_cita: bool` (sin `tarifa_eur`).
- [x] `TipoPuesto`: `id, nombre, servicio, atenciones_admitidas: Array[StringName], reconfigurable: bool,
      coste_construccion_eur: int, plazas_agente: int, superficie: int, icono`.
- [x] `TipoSala`: `id, nombre, tipo/servicio, puestos_admitidos: Array[StringName], aforo_espera: int,
      coste_construccion_eur: int, superficie: int, icono`.
- [x] `TipoAgente`: `id, puesto_organico, unidad, escala_rango, salario_dia_eur: int, tipo_horario,
      puestos_operables: Array[StringName]`.
- [x] `Costes`: `peonada_eur_hora: float`, `retorno_dgp_min: float`, `retorno_dgp_max: float`.
- [x] `Escenario`: `id, nombre, nivel, poblacion: int, tope_construible (Dictionary por servicio),
      rango_requerido, servicios_activos: Array[StringName]`.
- [x] Todas las referencias cruzadas son `Array[StringName]` (ids), **no** `Array[Resource]`.

---

## Implementation Notes

- Ubicación de los scripts de clase: `src/foundation/datos/esquema/` (un `.gd` por clase). El **contenido**
  del catálogo (`.tres`) va aparte en `res://datos/` (Story 004).
- Solo `@export` + `class_name`; cero lógica. Los enums con `@export_enum("A","B")` sobre un `String`.
- `tope_construible` como `Dictionary` (`{"puesto_doc_general": 8, ...}`) o campos; decidir al implementar.

## Out of Scope

- **Story 002**: cargar los `.tres` e indexarlos (autoload `Datos`).
- **Story 003**: validación en carga.
- **Story 004**: el contenido del catálogo de Pozuelo (los `.tres` con valores).

## QA Test Cases

*Logic — verifica la estructura del esquema (no valores; eso es 004).*

- **AC-1 (jerarquía)**: `TramiteDoc.new()` y `DenunciaODAC.new()` son `is Atencion`; `Atencion.new()` es
  `is Resource`.
- **AC-2 (campos trámite)**: una instancia `TramiteDoc` tiene las propiedades `tarifa_eur`, `requiere_cita`,
  y las heredadas (`id`, `duracion_min`…). *(Verificar con `"tarifa_eur" in t` o `t.get_property_list()`.)*
- **AC-3 (campos denuncia)**: una instancia `DenunciaODAC` tiene `prioridad` y `admite_cita`, y **no** tiene
  `tarifa_eur`.
- **AC-4 (referencias por id)**: `TipoPuesto.atenciones_admitidas` acepta un `Array[StringName]` (asignar
  `[&"dni", &"pasaporte"]` no falla y se lee igual).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/datos/datos_esquema_test.gd` — debe existir y pasar.

**Status**: [x] Creado y PASA (`datos_esquema_test.gd` 9/9; suite del proyecto 32/32, 2026-07-22)

## Dependencies

- Depends on: None.
- Unlocks: Story 002 (carga/lookup), 003 (validación), 004 (contenido) — todas usan estas clases.

## Cierre (2026-07-22)

Implementada vía subagente `godot-gdscript-specialist` (Opus) + revisión y re-ejecución independiente de la
suite en el hilo principal (32/32 en verde). Decisiones registradas:
- **Gotcha nuevo**: en headless "en frío", `extends Atencion` (por `class_name`) en una clase hija
  preload-ada falla ("Could not resolve script") → las 2 hijas heredan por **ruta literal**
  (`extends "res://src/foundation/datos/esquema/atencion.gd"`). Documentado en el código.
- `Costes` añade `id` (no pedido por el GDD) para indexado uniforme por `id` en Story 002.
- `Escenario.tope_construible` usa `Dictionary[StringName, int]` tipado (estable en 4.6).
- Revisión del hilo principal: corregido doc comment de `retorno_dgp_min/max` ("euros" → fracción [0,1]).
- Los `.gd.uid` no se materializan en el flujo headless (igual que los scripts previos); se generarán al
  abrir el editor. No bloquea.
