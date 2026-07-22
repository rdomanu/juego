# Story 002: Dispatcher de eventos ordenados por prioridad

> **Epic**: EventBus
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: (lo fija `/dev-story` al empezar)

## Context

**GDD**: `docs/architecture/architecture.md` §3.2 (Orden de handlers) — *módulo de infraestructura sin GDD propio*
**Requirement**: `TR-bus-002`
*(Texto del requisito en `docs/architecture/tr-registry.yaml` — leer fresco al revisar.)*

**ADR Governing Implementation**: ADR-0001: Bus de eventos, tick de simulación y orden determinista
**ADR Decision Summary**: los eventos con orden crítico (`nuevo_dia`, `nuevo_mes`) se resuelven con un
**registro con prioridad**: cada sistema llama `EventBus.registrar_ordenado(evento, prioridad, cb)`; al
disparar, el bus invoca los callables en **orden de prioridad ascendente**. El bus **no conoce los
sistemas** (solo guarda una lista de callables) → respeta las capas.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Callable` y `StringName` verificados para 4.6; sin APIs post-cutoff. El orden de
ejecución de `connect` sueltos entre autoloads **no está garantizado** por Godot → por eso hace falta este
dispatcher explícito (no basta un `connect`).

**Control Manifest Rules (Foundation)**:
- Required: eventos ordenados por registro con prioridad; `disparar_ordenado` invoca por prioridad
  ascendente. `nuevo_dia`: Paciencia(10)→Economía(20)→Personal(30)→Demanda(40).
  `nuevo_mes`: Economía(10)→Paciencia(20)→Demanda(30).
- Forbidden: **dispatcher hardcodeado que llame a los sistemas por nombre** (violaría las capas — es la
  Alternativa 3 rechazada del ADR); la Foundation no depende de Core/Feature.
- Guardrail: `disparar_ordenado` corre 1×/jornada → coste trivial.

---

## Acceptance Criteria

*Derivados de ADR-0001 (Decision punto 2, Validation Criteria, Risks):*

- [ ] `registrar_ordenado(evento: StringName, prioridad: int, cb: Callable) -> void` guarda el callable
      asociado a ese evento con su prioridad.
- [ ] `disparar_ordenado(evento: StringName) -> void` invoca los callables registrados para ese evento en
      **orden de prioridad ascendente** (menor prioridad primero).
- [ ] **Desempate determinista**: dos callables con la misma prioridad se invocan en **orden de registro**
      (estable dentro de una partida).
- [ ] Tras invocar los callables ordenados, se **emite la señal de notificación** correspondiente
      (`nuevo_dia`/`nuevo_mes`) para los oyentes no críticos (UI, Feedback).
- [ ] El bus **no llama a ningún sistema por nombre**: solo recorre su lista de callables.
- [ ] **Determinismo**: el mismo conjunto de registros + el mismo disparo producen **siempre** el mismo
      orden de invocación (independiente del reloj real o de los FPS).
- [ ] Casos límite gestionados: disparar un evento sin callables registrados no falla; lista tipada
      estáticamente.

---

## Implementation Notes

*Derivadas de ADR-0001 (Key Interfaces, Risks) + control-manifest:*

```gdscript
# En event_bus.gd (mismo autoload que Story 001):
# Estructura interna: por evento, una lista de {prioridad:int, orden:int, cb:Callable}
var _ordenados: Dictionary = {}   # StringName -> Array
var _contador_registro: int = 0   # para desempate estable por orden de registro

func registrar_ordenado(evento: StringName, prioridad: int, cb: Callable) -> void:
    if not _ordenados.has(evento):
        _ordenados[evento] = []
    _ordenados[evento].append({"prioridad": prioridad, "orden": _contador_registro, "cb": cb})
    _contador_registro += 1

func disparar_ordenado(evento: StringName) -> void:
    if not _ordenados.has(evento):
        return
    var lista: Array = _ordenados[evento].duplicate()
    lista.sort_custom(func(a, b):
        if a["prioridad"] == b["prioridad"]:
            return a["orden"] < b["orden"]      # desempate estable
        return a["prioridad"] < b["prioridad"]) # ascendente
    for entrada in lista:
        entrada["cb"].call()
    # tras el orden crítico, notificar a los no críticos:
    if evento == &"nuevo_dia":
        nuevo_dia.emit()
    elif evento == &"nuevo_mes":
        nuevo_mes.emit()
```

- Prioridades **espaciadas (10/20/30/40)** para dejar hueco a inserciones futuras sin renumerar.
- El bus expone `registrar_ordenado`/`disparar_ordenado`; **quién** registra su prioridad y **quién**
  dispara (Tiempo, al cruzar medianoche) es de otros epics — aquí solo el mecanismo.
- Considerar `sort_custom` estable: como el motor no garantiza estabilidad, el campo `orden` fuerza el
  desempate determinista explícitamente.

---

## Out of Scope

*Lo manejan historias/epics vecinos — no implementar aquí:*

- **Story 001**: la declaración del autoload y las señales de aviso.
- **Epic Tiempo**: quién **dispara** `disparar_ordenado("nuevo_dia")` (Tiempo, al cruzar medianoche) y el
  avance de fecha (paso 1 del orden).
- **Epics Paciencia/Economía/Personal/Demanda**: cada uno **registra su prioridad** y su handler real; aquí
  solo se prueba el mecanismo con callables de prueba (espías).

---

## QA Test Cases

*Escritos por el hilo principal (QA Lead omitido en LEAN; subagentes caídos). El programador implementa
contra estos casos con callables espía (los sistemas reales aún no existen).*

- **AC-1**: `disparar_ordenado` invoca en orden de prioridad ascendente.
  - Given: se registran 3 espías con prioridades **30, 10, 20** (en ese orden de registro), cada uno
    apuntando su prioridad en una lista compartida.
  - When: `EventBus.disparar_ordenado(&"nuevo_dia")`.
  - Then: la lista resultante es `[10, 20, 30]`.
  - Edge cases: 0 registros → no falla; 1 registro → se invoca; 4 registros (10/20/30/40) → orden exacto.
- **AC-2**: desempate determinista por orden de registro.
  - Given: se registran 3 espías **A, B, C** todos con prioridad **20**.
  - When: se dispara el evento.
  - Then: se invocan en orden **A → B → C** (el de registro).
  - Edge cases: repetir el disparo → mismo orden; mezclar prioridades iguales y distintas.
- **AC-3**: la señal de notificación se emite **después** de los callables ordenados.
  - Given: un espía registrado como callable ordenado (prioridad 10) + un oyente conectado a la **señal**
    `nuevo_dia`, ambos añadiendo su nombre a una lista.
  - When: `disparar_ordenado(&"nuevo_dia")`.
  - Then: la lista es `["ordenado", "senal"]` (el callable ordenado antes que el oyente de la señal).
- **AC-4**: determinismo entre ejecuciones.
  - Given: idéntico set de registros (mismas prioridades, mismo orden de registro).
  - When: se dispara el evento en 2 ejecuciones independientes del test.
  - Then: el orden de invocación es idéntico en ambas.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_bus/event_bus_orden_test.gd` — debe existir y pasar (orden ascendente,
  desempate estable, notificación posterior, determinismo). Test determinista: sin `randi()` ni tiempo real.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: **Story 001** (el autoload `EventBus` debe existir).
- Unlocks: el `nuevo_dia`/`nuevo_mes` ordenado que consumen Tiempo (dispara), Paciencia, Economía, Personal
  y Demanda (registran su prioridad).
