# Evidencia Visual/UI — Story 009 (epic Tiempo): Esqueleto visible

> **Fecha**: 2026-07-23
> **Story**: production/epics/tiempo/story-009-esqueleto-visible.md
> **Tipo**: Visual/UI (ADVISORY)
> **Build**: commit 3282e06 · Godot 4.6.stable · suite 107/107 exit 0
> **Captura**: `tiempo-esqueleto-2026-07-23.png` (generada automáticamente por `main.gd` a los 2 s de ejecución)

## Walkthrough manual

Ventana lanzada por Claude (`Godot_v4.6-stable_win64_console.exe --path <raíz>`) tras validación headless
limpia (0 errores, 0 warnings, 200 frames). Comprobado:

| Paso | Resultado |
|------|-----------|
| La ventana abre con `Main.tscn` sin errores en consola | ✅ |
| Se ve la rejilla de suelo (TileMapLayer 24×13, sin interacción de ratón) | ✅ |
| HUD: hora HH:MM en grande, fecha "Mes · Semana — Año", turno | ✅ (actualizándose en vivo) |
| La hora avanza a 1× al arrancar (4 min de juego por segundo real) | ✅ |
| Espacio pausa / reanuda a la última velocidad | ✅ |
| 1/2/3 y los botones cambian la velocidad; el activo se resalta en dorado | ✅ |
| El HUD reacciona a `velocidad_cambiada` / `cambio_de_turno` / `cambio_dia_noche` | ✅ |

## Sign-off

**Usuario (manu.rdo): ✅ VISTO BUENO** — 2026-07-23, tras ver la ventana en vivo (sesión Claude Code).

## Notas

- **No jugable** (por diseño de la story): sin construcción, colas, personal ni economía. Es el andamio
  visible del reloj; base de escena para el epic Construcción.
- **HUD provisional**: será sustituido por el HUD real de UX (`design/ux/hud.md` + epic UI/HUD #11).
- La captura automática solo corre en entorno de desarrollo (`OS.has_feature("editor")`); nunca en build
  exportada.
