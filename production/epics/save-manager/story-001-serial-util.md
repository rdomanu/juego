# Story 001: Helper de tipos JSON-safe (`Vector2i`↔`{x,y}`)

> **Epic**: SaveManager (guardado y carga)
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**Fuente**: `docs/architecture/adr-0002-guardado-serializacion.md` (Decision 3 — "Tipos de Godot: `Vector2i` → `{"x":.., "y":..}`; `Color`/otros → descomponer"; Constraints — "JSON no serializa `Vector2i`, `Color`, `Rect2` directamente → hay que descomponerlos"). *(Este epic NO tiene GDD: es infraestructura; la SPEC es el ADR-0002 + `docs/architecture/architecture.md` §3.3.)*
**Requirement**: `TR-save-003` (`Vector2i` — celdas del layout — → descomponer a `[x,y]` por la limitación de JSON).

**ADR Governing Implementation**: ADR-0002: Guardado / serialización (JSON en `user://`) + RNG determinista *(primario)*
**ADR Decision Summary**: JSON son datos, no código. Como JSON no conoce los tipos nativos de Godot (`Vector2i`, `Color`, `Rect2`), cada uno se **descompone** a un `Dictionary`/`Array` de números/texto y se **reconstruye** al cargar. La primera necesidad concreta es `Vector2i` (las celdas del layout de Construcción — TR-construction-004). Este helper centraliza esa traducción para que **cualquier** sistema (Construcción, Flujo) la use sin duplicar la aritmética y **sin depender del singleton** `SaveManager`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: aritmética pura sobre `Vector2i` (`.x`/`.y` son `int`). Sin I/O ni APIs de motor post-cutoff. `JSON.stringify`/`JSON.parse_string` se usan **solo en el test** de round-trip para probar que la representación sobrevive un viaje real por JSON. Ojo con el gotcha del parseo: `JSON.parse_string` devuelve los enteros pequeños como `float` (p. ej. `5.0`) → al reconstruir el `Vector2i` hay que castear con `int(...)` (por eso el helper acepta números y castea, no asume `int` exacto).

**Control Manifest Rules (Foundation)**:
- Required: `Vector2i` (celdas del layout) → `{"x":.., "y":..}` al serializar (JSON no serializa `Vector2i`/`Color`/`Rect2`). — ADR-0002. Tipado estático obligatorio.
- Forbidden: nunca serializar un tipo nativo de Godot crudo en el JSON (rompe el `stringify`/`parse`); nunca guardar en `res://`; nunca meter I/O en este helper (es lógica pura).
- Cross-cutting: determinismo (round-trip idéntico); reutilizable por Core sin acoplarse al autoload `SaveManager`.

---

## Acceptance Criteria

- [ ] **AC-SU01**: GIVEN `Vector2i(3, 7)` WHEN `SerialUtil.vec2i_a_dict(v)` THEN devuelve exactamente `{"x": 3, "y": 7}`.
- [ ] **AC-SU02**: GIVEN `{"x": 3, "y": 7}` WHEN `SerialUtil.dict_a_vec2i(d)` THEN devuelve exactamente `Vector2i(3, 7)`.
- [ ] **AC-SU03**: GIVEN un `Vector2i(-4, 12)` WHEN `dict_a_vec2i(JSON.parse_string(JSON.stringify(vec2i_a_dict(v))))` THEN el resultado es **idéntico** al original (round-trip a través de JSON real, incluso con los enteros llegando como `float`).
- [ ] **AC-SU04**: GIVEN un dict incompleto (falta `x` o `y`, o dict vacío `{}`) WHEN `dict_a_vec2i(d)` THEN devuelve `Vector2i.ZERO` y emite `push_warning` (defensivo — no peta ante un save manipulado/parcial).

---

## Implementation Notes

- **Ubicación**: `src/foundation/save_manager/serial_util.gd`, con **`class_name SerialUtil`**. A diferencia del autoload `SaveManager` (Story 002, SIN `class_name` por colisión con el nombre del singleton), este helper **SÍ** lleva `class_name`: no es un autoload, es una utilidad estática que los sistemas invocan por su nombre de clase (`SerialUtil.vec2i_a_dict(...)`) sin instanciar ni depender del singleton.
- **SOLO `static func`** (sin estado, sin `_init`, sin nodos):
  ```
  static func vec2i_a_dict(v: Vector2i) -> Dictionary:
      return {"x": v.x, "y": v.y}

  static func dict_a_vec2i(d: Dictionary) -> Vector2i:
      if not d.has("x") or not d.has("y"):
          push_warning("SerialUtil.dict_a_vec2i: faltan claves x/y -> Vector2i.ZERO")
          return Vector2i.ZERO
      return Vector2i(int(d["x"]), int(d["y"]))
  ```
- **`int(...)` en la reconstrucción** es OBLIGATORIO, no cosmético: tras `JSON.parse_string`, un `3` guardado vuelve como `3.0` (float). Sin el cast, `Vector2i(3.0, 7.0)` funciona por conversión implícita, pero el cast explícito documenta la intención y evita sorpresas con tipado estático estricto.
- **Hueco documentado para tipos futuros**: dejar un comentario que reserve el sitio para `color_a_dict`/`dict_a_color` (`Color` → `{"r","g","b","a"}`) y `rect2_a_dict`/`dict_a_rect2` cuando Construcción/Presentation los necesiten. NO implementarlos aquí (YAGNI — solo `Vector2i` tiene consumidor real ahora: el layout).
- **Fuera del autoload a propósito**: Construcción (Core) y Flujo necesitan traducir `Vector2i` en SUS propios `save()`/`load_state()`, que corren ANTES de que el `SaveManager` ensamble nada. Un helper estático desacoplado se usa desde cualquier capa sin violar las capas ni depender del orden de autoloads.
- **`self.` footgun**: no aplica (no hay métodos de instancia ni sombreado de globales). Anotado por consistencia con el patrón del proyecto.

## Out of Scope

- La **recolección** del grupo `Persist` y el ensamblado del dict raíz con `version`: **Story 002**.
- La **I/O** (escribir/leer en `user://`): **Stories 003/004**.
- `Color`/`Rect2`: hueco reservado, sin implementar (ningún sistema los serializa aún; se añadirán cuando Construcción/Feedback los necesiten).
- El uso real de este helper por Construcción (traducir el layout): epic **Construcción** (Core), no este.

## QA Test Cases

*Logic — funciones estáticas puras, deterministas. `tests/unit/save_manager/serial_util_test.gd`.*

- **`test_vec2i_a_dict_descompone`** (AC-SU01): `vec2i_a_dict(Vector2i(3,7))` → `{"x":3,"y":7}` (comparar claves y valores exactos).
- **`test_dict_a_vec2i_reconstruye`** (AC-SU02): `dict_a_vec2i({"x":3,"y":7})` → `Vector2i(3,7)`.
- **`test_roundtrip_por_json_identico`** (AC-SU03): `v = Vector2i(-4,12)`; `d = JSON.parse_string(JSON.stringify(vec2i_a_dict(v)))`; `dict_a_vec2i(d) == v`. *(Prueba explícitamente el paso por `float` del parseo.)*
- **`test_dict_incompleto_devuelve_zero`** (AC-SU04): `dict_a_vec2i({})` y `dict_a_vec2i({"x":3})` → ambos `Vector2i.ZERO` (y warning; el test verifica el valor de retorno, el warning es observacional).

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_manager/serial_util_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: **None** (utilidad raíz del epic; solo aritmética sobre `Vector2i`).
- Unlocks: **Story 002** (la recolección/ensamblado la usará para cualquier sub-dict con `Vector2i`) y, fuera del epic, el `save()` de **Construcción** (layout).

## Notas de gotchas del proyecto

- **`JSON.parse_string` → `float`**: los enteros vuelven como `float` tras el round-trip por JSON → castear con `int(...)` al reconstruir el `Vector2i` (AC-SU03 lo prueba de forma explícita). Esta es la razón real de que exista este helper y no se guarde el `Vector2i` "a pelo".
- **Preload por ruta en headless**: en el test, si el runner corre en frío, `preload("res://src/foundation/save_manager/serial_util.gd")` en lugar de depender de que el `class_name SerialUtil` esté registrado globalmente (mismo gotcha del `class_name` en frío visto en `tiempo.gd`/`datos`).
- **Sin I/O**: este helper NUNCA toca disco — mantenerlo puro lo hace testeable sin `user://` ni teardown de archivos.
