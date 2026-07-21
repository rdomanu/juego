# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.6 |
| **Release Date** | January 2026 |
| **Project Pinned** | 2026-02-12 |
| **Last Docs Verified** | 2026-07-22 |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5,
and 4.6 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |

## Verificación web 2026-07-22 (para Comisario, 2D de gestión)

Verificados contra `docs.godotengine.org/en/4.6` los dominios que **sí** usa Comisario (2D). **Hallazgo clave: la mayoría de los cambios HIGH-risk de 4.6 son de 3D (Jolt, IK, glow 3D, tonemapping) y NO afectan a este proyecto 2D.** Notas volcadas en `modules/`:
- **`modules/navigation.md`** — 2D pathfinding (NavigationServer2D dedicado 4.5+, NavigationAgent2D, gotcha del 1er physics frame). Flujo #4.
- **`modules/tilemap-2d.md`** *(nuevo)* — API de `TileMapLayer` (`set_cell`/`local_to_map`/…). Construcción #7. `TileMap` DEPRECADO.
- **`modules/save-load.md`** *(nuevo)* — JSON+FileAccess/ConfigFile para saves de partida (NO custom Resources: seguridad + issue 4.6); `.tres` solo para el catálogo estático. `user://`.
- **`modules/patterns.md`** *(nuevo)* — bus de eventos (autoload + signals); orden de handlers determinista (ADR).
- **`modules/rendering.md`** — mood 2D con **CanvasModulate + Light2D**; **glow real DESCARTADO en 2D** (resuelve Feedback #12 OpenQ2).

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.6/
