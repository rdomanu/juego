# Test Infrastructure

**Engine**: Godot 4.6
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-07-22

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

```
godot --headless --script tests/gdunit4_runner.gd
```

> **Nota:** el proyecto Godot aún no está inicializado (no existe `project.godot`) y GdUnit4
> aún no está instalado. El lanzador y el CI quedan escritos pero **en reposo** hasta entonces.

## Instalando GdUnit4

```
1. Abrir Godot → AssetLib → buscar "GdUnit4" → Download & Install
2. Activar el plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Reiniciar el editor
4. Verificar: existe res://addons/gdunit4/
```

## Test Naming

- **Archivos**: `[system]_[feature]_test.gd`
- **Funciones**: `test_[scenario]_[expected]`
- **Ejemplo**: `economy_retorno_dgp_test.gd` → `test_retorno_dgp_con_sat_50_devuelve_esperado()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## Determinismo (recordatorio del proyecto)

Los tests deben ser **deterministas**: sin semillas aleatorias sin sembrar, sin aserciones dependientes
del reloj real. Toda aleatoriedad de juego pasa por `RNGService` sembrado (ADR-0002), lo que facilita
tests reproducibles. La simulación corre en paso fijo (`_physics_process`, ADR-0001).

## CI

Los tests se ejecutan automáticamente en cada push a `main` y en cada pull request.
Un fallo del suite bloquea el merge (regla de `coding-standards.md`: nunca deshabilitar tests para pasar CI).
