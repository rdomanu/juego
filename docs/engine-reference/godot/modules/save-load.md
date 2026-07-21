# Godot Save / Load — Quick Reference

Last verified: 2026-07-22 (via docs.godotengine.org/en/4.6 + Godot forum) | Engine: Godot 4.6

Para el **guardado de partida** de Comisario (estado mutable: saldo, plantilla, layout, colas, reloj, sat, préstamos…). Todos los GDD dicen "cargar arranca en Pausa; no re-disparar eventos retroactivos".

## Distinción CLAVE para Comisario (dos cosas distintas)

1. **Catálogo data-driven (Datos #2)** = definiciones **estáticas del desarrollador** (trámites, denuncias, tipos de puesto/sala/agente, escenarios). → **Godot `Resource` (`.tres`)** es apropiado AQUÍ: son contenido, no del jugador, se cargan con `load()`/`preload()`. (Formato exacto = ADR de formato de datos; `.tres` vs JSON es Datos OpenQ#8.)
2. **Save de partida (estado mutable del jugador)** = lo que cambia al jugar. → **NO usar custom Resources para esto.** Usar **JSON + FileAccess** o **ConfigFile**.

## Por qué NO Resources para el save de partida (verificado 2026-07-22)

- **Seguridad:** cargar un `Resource` de un archivo puede ejecutar **código arbitrario** (vector de ataque si el save se comparte/modifica). Riesgo real.
- **4.6:** hay **issues reportados con `ResourceSaver`** al persistir custom Resources con subrecursos anidados (funcionaba en 4.5, se rompió en 4.6; workaround: `duplicate(true)`). Un motivo más para evitarlo en saves.
- **Consenso de la comunidad:** JSON o ConfigFile para saves de producción.
- **Export:** guardar en **`user://`**, NUNCA en `res://` (res:// es de solo lectura en exports).

## Patrón recomendado: JSON + FileAccess

```gdscript
# GUARDAR
var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
var estado := { "saldo": saldo, "jornada": jornada, "prestamos_usados": prestamos_usados }
save_file.store_line(JSON.stringify(estado))

# CARGAR
var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
var json = JSON.new()
if json.parse(save_file.get_line()) == OK:
    var estado = json.data
    saldo = estado["saldo"]
```

### Patrón por-objeto (cada sistema serializa su estado)
Cada nodo/sistema persistente implementa `save() -> Dictionary` y `load_state(d: Dictionary)`:
```gdscript
func save() -> Dictionary:
    return { "saldo_eur": saldo_eur, "prestamos_vivos": prestamos_vivos }
```
Reunir vía grupo: `get_tree().get_nodes_in_group("Persist")`.

## ⚠️ Limitaciones de JSON (importante)
- JSON **NO** serializa `Vector2`, `Vector2i`, `Color`, `Rect2` directamente → descomponer a números (`pos_x`, `pos_y`) o usar un helper. Relevante para el **layout de Construcción** (celdas `Vector2i`) → guardar como `[x, y]` o strings.
- Alternativa: **`FileAccess.store_var()` / `get_var()`** (binario) sí maneja tipos de Godot y es más compacto — pero menos legible/debuggeable. Opción válida si el layout tiene muchos `Vector2i`.

## Para el ADR de guardado (Comisario)
- **Save de partida:** JSON+FileAccess en `user://` (legible/debuggeable) o `store_var` binario si pesa el layout. Patrón `save()`/`load_state()` por sistema.
- **Catálogo:** `Resource` `.tres` (o JSON) — decisión separada (formato de datos).
- **Determinismo al cargar:** restaurar estado + **estado del RNG/semilla** (Demanda F4, Personal F5) → arrancar en **Pausa**, sin re-disparar eventos (coherente con Tiempo/Economía/Flujo/Paciencia).

## Errores comunes
- Guardar en `res://` (falla en export) → usar `user://`.
- Usar custom `Resource` como save de partida (seguridad + issue 4.6).
- Olvidar serializar el estado del RNG (rompe el determinismo al cargar).
- Intentar `JSON.stringify` un `Vector2i` directamente (no soportado).
