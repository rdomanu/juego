# Story 004: Catálogo MVP — Oficina de Denuncias de Pozuelo

> **Epic**: Datos y Configuración
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-22

## Context

**GDD**: `design/gdd/data-config.md` (F1–F7 — valores semilla del catálogo)
**Requirement**: `TR-data-001` (catálogo desde fuente externa — el **contenido**)

**ADR Governing Implementation**: ADR-0003: Formato del catálogo (.tres Resource)
**ADR Decision Summary**: **un `.tres` por definición**, en carpetas por tipo (`res://datos/tramites/`,
`/denuncias/`, `/puestos/`, `/salas/`, `/agentes/`, `/escenarios/`, `/costes/`); referencias por `id`.
Transcribir los valores semilla de `data-config.md` (F1–F7) y `entities.yaml`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: los `.tres` referencian los scripts de clase (Story 001). **Crear `.tres` a mano es
frágil** (formato con `uid`/`ext_resource`); se generarán con un **script-herramienta** (ver Notas).

**Control Manifest Rules (Foundation)**:
- Required: un `.tres` por definición en `res://datos/<tipo>/`; referencias por `id`; los valores viven aquí
  (data-driven), no en código.
- Cross-cutting: coherencia con `entities.yaml` (registro de diseño).

---

## Acceptance Criteria

*De GDD F1–F7 + AC-D01/D16/D18/D20:*

- [x] **Trámites (F1)**: `dni`(12min,12€), `pasaporte`(15,30), `tie`(15,18), `requiere_cita=false`.
- [x] **Denuncias (F2)**: las **13** `DenunciaODAC` con sus `duracion_min`/`prioridad`, `admite_cita=false`
      (4 Prioritarias: viogen, desaparecidos, agresion_sexual, robo_violencia; 9 Normales). *(La atención
      interna `reclamacion` la posee/gener­a Paciencia — no es demanda ciudadana; incluirla como definición
      de atención según F2.)*
- [x] **Puestos (F3)**: `puesto_doc_general`, `puesto_tie`, `puesto_odac`(reconfigurable=true), `puesto_seguridad`,
      con `atenciones_admitidas`, `coste_eur` y `reconfigurable` correctos.
- [x] **Salas (F4)**: `sala_espera_doc`(aforo 40), `sala_espera_odac`(aforo 10), `sala_documentacion`,
      `sala_odac`.
- [x] **Agentes (F5)**: `ag_doc`(60€), `ag_odac`(70€), `ag_seguridad`(65€) con `puestos_operables`.
- [x] **Costes (F6)**: `peonada_eur_hora=15`, `retorno_dgp_min=0.15`, `retorno_dgp_max=0.45`.
- [x] **Escenario Pozuelo (F7, AC-D16)**: `poblacion=90000`, `nivel="Nivel 1 — Comisaría Local"`,
      `servicios_activos=[Documentacion, ODAC]`, topes Doc≤8 / TIE≤2 / ODAC≤4 / Entrada 1.
- [x] **El catálogo completo valida limpio (AC-D20a–d)**: `Datos.validar()` (Story 003) devuelve **`[]`**
      (0 refs colgantes, 0 ids duplicados, 0 valores fuera de rango, R5 pasa, todo servicio con puesto).

---

## Implementation Notes

- **Enfoque de autoría (headless-safe)**: escribir un **script-herramienta** `tools/build_catalogo.gd`
  (`extends SceneTree`) que instancia cada Resource por código con sus valores (F1–F7) y lo guarda con
  `ResourceSaver.save(res, "res://datos/<tipo>/<id>.tres")`. Ejecutarlo una vez en headless
  (`godot --headless --script res://tools/build_catalogo.gd`). Así se evita escribir `.tres` a mano (uids/
  `ext_resource` frágiles). El script-herramienta es **dev tooling** (`tools/`), no código runtime.
- Alternativa: crear los `.tres` en el editor (Inspector) — pero rompe el flujo headless.
- Transcribir con cuidado desde `data-config.md` (F1–F7) y `design/registry/entities.yaml`; mantenerlos
  coherentes.

## Out of Scope

- **Story 001/002/003**: clases, carga/lookup, validación (aquí solo el **contenido**).
- Iconos reales de cada definición (arte): pendientes del art bible + `/asset-spec`; de momento
  referencia/placeholder.

## QA Test Cases

*Config/Data — smoke: cargar el catálogo real + validar limpio + spot-check de valores.*

- **AC-1 (AC-D20, limpio)**: cargar el catálogo real de `res://datos/` → `Datos.validar()` devuelve `[]`
  (0 errores/warnings).
- **AC-2 (AC-D01, valores)**: `obtener(&"TramiteDoc", &"dni")` → `duracion_min=12`, `tarifa_eur=12`.
- **AC-3 (conteo)**: `obtener_todos(&"DenunciaODAC").size() == 13`.
- **AC-4 (AC-D16, Escenario)**: `obtener(&"Escenario", &"pozuelo")` → `poblacion=90000`,
  `servicios_activos` contiene `Documentacion` y `ODAC`.
- **AC-5 (AC-D18, aforo)**: `sala_espera_doc.aforo_espera == 40`.

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check (`production/qa/smoke-*.md`) **y/o** un test de integración
`tests/integration/datos/datos_catalogo_pozuelo_test.gd` que carga el catálogo real y asevera
`validar()==[]` + los valores spot-check.

**Status**: [x] Creado y PASA (datos_catalogo_pozuelo_test.gd 6/6 + datos_carga_lookup_test.gd actualizado; suite del proyecto 53/53, 2026-07-22)

## Dependencies

- Depends on: **Story 001** (clases) para instanciar; **Story 003** (validar) para el AC de "valida limpio".
- Unlocks: que Economía/Flujo/Demanda/Personal/Construcción/Doc/ODAC tengan datos reales que leer.

## Cierre (2026-07-22)

Implementada vía subagente godot-gdscript-specialist (Opus) + verificación del hilo principal (suite
53/53, exit 0). Commit c6d46e0. **ENMIENDA DE AC aprobada por el usuario (2026-07-22):** la atención
interna `reclamacion` se modela como la **14ª DenunciaODAC** (30 min, Normal, sin tarifa, la admite
`puesto_odac`); su origen es interno (la genera Paciencia PS13) y NO entra en la mezcla de Demanda
ciudadana. En consecuencia, donde los AC decían "13 denuncias" se lee "13 ciudadanas + 1 interna = 14
DenunciaODAC en el catálogo" (test de recuento actualizado 13→14). Catálogo final: **30 .tres** generados
exclusivamente por `tools/build_catalogo.gd`; el smoke verifica `Datos.validar() == []` sobre el catálogo
real + spot-checks de F1/F2/F4/F7. Nota: `validar()` corre con `demanda_max_odac=0` (R5 se evaluará con la
D real cuando exista Demanda).
