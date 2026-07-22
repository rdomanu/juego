# Story 008: `save()`/`load_state()` + grupo Persist + "cargar sitúa" (Pausa)

> **Epic**: Sistema de Tiempo
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3-4 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija /dev-story al empezar)

## Context

**GDD**: `design/gdd/time-system.md` (Core Rules 2.5 — al cargar arranca en Pausa; Interacciones — Guardado serializa el reloj; Edge Cases — cargar fija el estado y NO dispara eventos retroactivos)
**Requirement**: `TR-time-008` (serializar reloj/fecha; al cargar arranca en Pausa, sin eventos retroactivos)

**ADR Governing Implementation**: ADR-0002: Guardado / serialización (JSON en `user://`) *(primario)* · ADR-0001 *(sec. — provee el arranque en Pausa)*
**ADR Decision Summary**: cada sistema persistente implementa **`save() -> Dictionary`** y **`load_state(d: Dictionary)`**, y se marca con el grupo de nodos **`Persist`**. El `SaveManager` recorre el grupo (no conoce sistemas por nombre) y ensambla el JSON. `save()` devuelve **solo datos serializables** (números, texto, listas, dicts). Al cargar: se fija el estado, Tiempo queda en **Pausa**, y **NO** se re-disparan eventos ("cargar sitúa, no reproduce"). El RNG lo serializa su propio autoload (`RNGService.save()`), **no** el reloj.

**Engine**: Godot 4.6 | **Risk**: LOW *(la story del reloj es lógica pura sobre un Dictionary; la I/O real es del SaveManager, epic aparte)*
**Engine Notes**: `save()`/`load_state()` trabajan con un `Dictionary` de tipos JSON-safe. `minutos_juego`, `semana`, `mes`, `anio` son numéricos pequeños → **enteros/floats directos**, sin el truco de string. `add_to_group("Persist")` en `_ready`.

**Control Manifest Rules (Foundation)**:
- Required: `save()` devuelve **solo** tipos serializables; el nodo se marca con el grupo **`Persist`** en `_ready`; al cargar, Tiempo queda en **Pausa** y **NO** re-dispara eventos; `load_state` **sincroniza el umbral anterior** (turno/es_noche/medianoche) para no emitir un cruce espurio el 1er frame.
- Forbidden: **nunca** serializar datos derivados (`turno`, `es_de_noche` — se recalculan de `minutos_juego`); nunca serializar el RNG desde el reloj (lo hace `RNGService`); nunca re-disparar eventos pasados al cargar; nunca guardar la config (`ConfigTiempo` es del desarrollador, no del save).
- Cross-cutting: determinismo (round-trip idéntico); "cargar sitúa, no reproduce".

---

## Acceptance Criteria

*De GDD Edge Cases (carga) + Interacciones. Valores transcritos exactos de los AC-T del GDD:*

- [ ] **AC-T26**: GIVEN partida guardada a las **14:30, día 5, turno Tarde** WHEN se carga THEN muestra **14:30, día 5, Tarde**, **sin emitir** señales de cambio de turno / día-noche / `nuevo_dia`.
- [ ] **AC-T27**: GIVEN partida guardada con velocidad **3×** WHEN se carga THEN la velocidad activa es **Pausa (0×)**, sea cual sea la guardada; el reloj **no avanza** hasta que el jugador elija velocidad.

---

## Implementation Notes

- **`save() -> Dictionary`** — devuelve **solo el estado no derivado**:
  ```
  { "minutos_juego": <float>, "semana": <int>, "mes": <int>, "anio": <int> }
  ```
  **NO** incluye `turno` ni `es_de_noche` (derivados de `minutos_juego` — se recalculan al cargar). **NO** incluye la velocidad exacta (al cargar SIEMPRE arranca en Pausa). **NO** incluye el RNG (lo guarda `RNGService.save()`). Enteros pequeños sin truco de string (a diferencia de los enteros grandes del RNG).
- **`load_state(d: Dictionary)`**:
  1. Fija `minutos_juego`, `semana`, `mes`, `anio` desde `d` (con defaults seguros si falta una clave).
  2. **Arranca en Pausa**: `fijar_velocidad(PAUSA)` (H6). `ultima_velocidad_juego` queda en default (X1) → reanudar irá a 1× (coherente con H6/GDD).
  3. **Sincroniza el umbral anterior**: fijar `turno_anterior = turno(minutos_juego)` y `era_de_noche_anterior = es_de_noche(minutos_juego)` (y el marcador de medianoche) **sin emitir**. Así el 1er `_physics_process` tras cargar **no** detecta un cruce espurio (el estado "anterior" ya coincide con el cargado).
  4. **NO re-dispara** ningún evento (`cambio_de_turno`, `cambio_dia_noche`, `nuevo_dia`, `nuevo_mes`). "Cargar sitúa, no reproduce" (GDD/ADR-0002).
- **Grupo `Persist`**: en `_ready`, `add_to_group("Persist")` para que el `SaveManager` (epic aparte) lo recorra sin conocerlo por nombre (ADR-0002).
- **Round-trip**: `load_state(save())` deja el reloj en el mismo estado (mismos minutos/semana/mes/año), en Pausa. Los derivados (turno/es_noche/HH:MM) se recalculan idénticos.
- **`self.` footgun**: si `save`/`load_state` sombrearan alguna global (no lo hacen), cualificar con `self.`.

## Out of Scope

- El **`SaveManager`** (orquestación, I/O a `user://`, JSON.stringify/parse, escritura temp+rename): epic **SaveManager** (Ready), no esta story. Aquí solo el **contrato** `save()`/`load_state()` del reloj y el grupo `Persist`.
- La serialización del **RNG** (`RNGService.save()` — ya existe, epic RNGService Complete).
- La **config** (`ConfigTiempo`): no se serializa (contenido del desarrollador).
- Tolerancia a `id` huérfano del catálogo (no aplica al reloj — no referencia ids del catálogo).

## QA Test Cases

*Logic — round-trip del Dictionary + espías del EventBus. Determinista. `tests/unit/tiempo/`.*

- **`test_roundtrip_estado_identico`**: fijar `minutos_juego=870.0` (14:30), `semana`, `mes`, `anio`; `d = save()`; nuevo reloj `load_state(d)` → mismo estado; derivados (turno Tarde, HH:MM "14:30") recalculados iguales. (Cubre AC-T26 en su parte de estado.)
- **`test_carga_no_emite_eventos`** (AC-T26): conectar espías a `EventBus.cambio_de_turno`, `cambio_dia_noche`, `nuevo_dia`, `nuevo_mes`; `load_state({14:30, dia 5, ...})` → **0 emisiones** durante la carga. Y un `_physics_process` **inmediato** tras cargar → **0** cruces espurios (gracias a la sincronización del umbral).
- **`test_carga_arranca_en_pausa`** (AC-T27): `save()` con velocidad 3× (o simplemente cargar) → tras `load_state`, la velocidad activa es **PAUSA** y `minutos_juego` no avanza en el siguiente tick hasta elegir velocidad.
- **`test_save_no_incluye_derivados`**: `save()` **no** tiene claves `turno`/`es_de_noche`/`rng`.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tiempo/tiempo_save_test.gd` — debe existir y pasar (BLOCKING).

**Status**: not yet created

## Dependencies

- Depends on: **Story 005** (serializa semana/mes/año que el calendario mantiene) y **Story 006** (usa `fijar_velocidad(PAUSA)` para arrancar en Pausa). *(El contrato `save()`/`load_state()` sigue el patrón del RNGService ya cerrado.)*
- Unlocks: la integración del reloj con el **SaveManager** (su epic) y una partida guardable/cargable.

## Notas de headless (gotcha del proyecto)

Preload por ruta literal de `tiempo.gd`. Para verificar "0 emisiones durante la carga", conectar espías al EventBus en el setup y assertar contador 0 tras `load_state` (y tras un `_physics_process` inmediato). Desconectar en el teardown. **Nunca** hora real del sistema.
