# Godot Rendering — Quick Reference

Last verified: 2026-02-12 | Engine: Godot 4.6

## What Changed Since ~4.3 (LLM Cutoff)

### 4.6 Changes
- **D3D12 is the default rendering backend on Windows** (was Vulkan)
- **Glow processes before tonemapping** (was after) — uses screen blending mode
- **AgX tonemapper**: new white point and contrast controls
- **SSR overhauled**: better realism, visual stability, and performance

### 4.5 Changes
- **Shader Baker**: Pre-compiles shaders to reduce startup time
- **SMAA 1x**: New anti-aliasing option (sharper than FXAA, cheaper than TAA)
- **Stencil buffer support**: Enables selective geometry masking/portal effects
- **Bent normal maps**: Directional occlusion encoded in normal map textures
- **Specular occlusion**: Ambient occlusion now correctly affects reflections

### 4.4 Changes
- **`RenderingDevice.draw_list_begin`**: Many parameters removed; optional `breadcrumb` added
- **Shader texture types**: Changed from `Texture2D` to `Texture` base type
- **Particles `.restart()`**: Added optional `keep_seed` parameter

### 4.3 Changes (in training data)
- **Compositor node**: `Compositor` + `CompositorEffect` for post-processing chains

## Current API Patterns

### Post-Processing (4.3+)
```gdscript
# Use Compositor node — NOT manual viewport shader chains
# Add Compositor as child of WorldEnvironment or Camera3D
# Create CompositorEffect resources for each post-process step
```

### Anti-Aliasing Options (4.6)
```
Project Settings → Rendering → Anti Aliasing:
- MSAA 2D/3D: Hardware MSAA (quality but expensive)
- Screen Space AA: FXAA (fast, blurry) or SMAA (sharp, moderate cost)  # SMAA new in 4.5
- TAA: Temporal (best quality, ghosting on fast motion)
```

### Rendering Backend Selection (4.6)
```
Project Settings → Rendering → Renderer:
- Forward+ (default): Full featured, desktop-focused
- Mobile: Optimized for mobile/low-end, limited features
- Compatibility: OpenGL 3.3 / WebGL 2, broadest hardware support

Windows default backend: D3D12 (was Vulkan pre-4.6)
```

## Common Mistakes
- Assuming Vulkan is the default backend on Windows (D3D12 since 4.6)
- Using manual viewport chains instead of Compositor for post-processing
- Using `Texture2D` in shader uniform types (use `Texture` since 4.4)
- Not using Shader Baker for projects with many shader variants

## 2D Ambient / Mood — Comisario notes (verified 2026-07-22 via docs.godotengine.org/en/4.6)

Para el **mood ambiental** de Comisario (mañana cálida / noche fría / fracaso rojizo — Feedback #12, art bible §2):

- **`CanvasModulate`** — el nodo clave: **tinta TODA la escena 2D** con un color ambiente base (aplica a lo NO iluminado por luces 2D). Cambiar su propiedad **`color`** cambia el mood de toda la pantalla. Simple y **estable (sin cambios en 4.6)**.
- **Transición de mood:** anima `CanvasModulate.color` con un **`Tween`** (`create_tween().tween_property(canvas_mod, "color", nuevo_color, dur)`) o `lerp` manual. **No hay sistema día/noche automático** — se scripta, disparado por el evento `cambio_dia_noche` de Tiempo #1.
- **Luces 2D** (toques puntuales): `PointLight2D` (color/energy/texture/texture_scale) y `DirectionalLight2D` (color/energy/height). Ambos con **blend mode** (Add/Sub/Mix).

**⚠️ Glow en 2D — DECISIÓN (resuelve Feedback #12 OpenQ2):** el glow real (WorldEnvironment) **NO está documentado/soportado de forma fiable para el canvas 2D en 4.6** (por eso el "glow rework 4.6" HIGH-risk **no aplica a Comisario**). → El mood usa **CanvasModulate + Light2D** (estable); el "dorado del ascenso" se hace con **animación de sprite** (Tween de escala/opacidad + un sprite de halo), NO con glow real. El glow real queda **descartado** para este proyecto 2D.
