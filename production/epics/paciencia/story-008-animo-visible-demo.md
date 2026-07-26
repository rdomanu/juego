# Story 008: 🎉 HITO VISIBLE — se ve el cabreo (ánimo, medidor y la marcha)

> **Epic**: Paciencia y Satisfacción
> **Status**: Complete
> **Layer**: Feature (+ Presentation provisional)
> **Type**: Visual/Feel *(ADVISORY — evidencia + sign-off)*
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-26 — cerrada con el SIGN-OFF del usuario

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (Visual/Audio Requirements, UI Requirements) +
`design/gdd/ui-hud.md` (F2 ánimo, umbrales 66/33)
**Requirement**: cierre visible de `TR-patience-001..004`
**Governing ADRs**: ADR-0001 (la UI **lee**, nunca muta), ADR-0004 (capa cosmética)
**ADR Decision Summary**: FL5 — lo visible refleja el modelo con retardo; jamás decide nada.

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (capa visual sobre NPCs ya existentes)
**Engine Notes**: gotchas ya registrados — `z_index` en capas bajo nodos no-CanvasItem;
`MOUSE_FILTER_IGNORE` en todo Control decorativo del mundo; refresco por **pull con DIFF**, nunca
creando nodos por frame.

**Control Manifest Rules (Presentation)**:
- Required: la UI **lee** `Paciencia` y **no** hardcodea umbrales (los toma de la config). — ADR-0001
- Required: color **+ forma/texto** (respaldo daltónico) — regla fija del proyecto.
- Forbidden: que el indicador de ánimo mute nada del modelo.

---

## Acceptance Criteria (demo, ADVISORY)

- [ ] **M1** — Cada ciudadano esperando muestra su ánimo (🟢/🟡/🔴 por umbrales 66/33) y se ve **cambiar**
      con el tiempo.
- [ ] **M2** — Alguien **se marcha** al agotarse su paciencia, de forma legible (gesto sobrio, sin drama).
- [ ] **M3** — El HUD muestra la `sat` de hoy **construyéndose** junto al cierre de ayer (el que fija el
      dinero), y el contador de reclamaciones.
- [ ] **M4** — Se **nota la diferencia**: con poca plantilla la gente se va; contratando y abriendo
      ventanillas, deja de irse.
- [ ] **M5** — FPS ≥ 60 con la sala llena de indicadores.

---

## Implementation Notes

- **Ánimo sobre el NPC**: un aro/indicador pequeño sobre la silueta (el GDD pide legible a distancia de
  cámara, **sin hover**). Refresco por DIFF: solo cuando cambia de tramo (🟢→🟡→🔴), no cada frame.
- **Andamio declarado**: como el resto del visual, esto lo sustituirá UI/HUD #11. Anotar en
  `design/ux/pulido-backlog.md` cualquier feedback estético que salga de la demo, sin implementarlo.
- **Medidor de satisfacción**: 0-100 con banda de color y transición **suave** (no salta) — el GDD lo pide
  explícitamente. Junto al número, la escala visible (**principio U5** del backlog de pulido: ningún
  indicador sin su escala).
- **Demo (guion)**: partida normal hasta la hora punta → ver el degradado de ánimos en la sala → dejar
  que alguien se vaya → contratar y abrir otra ventanilla → ver que deja de pasar. Evidencia en
  `production/qa/evidence/paciencia-demo-<fecha>.md` con checklist y captura.
- **Calibración CON el usuario** (tarea C3-4 del sprint): `tolerancia_base_min` 30 es una semilla. Si en
  la demo la gente se va demasiado pronto o nunca se va, se ajusta el knob **en caliente** y se anota el
  valor elegido. Este es el número más importante del balance del juego hasta ahora.

---

## Test Cases

Visual/Feel → **evidencia + sign-off**, no test automático (regla del proyecto: la "sensación" no se
automatiza). Sí automatizable y exigido antes de la demo:
- Suite completa en verde + arranque headless limpio.
- `test_animo_por_umbrales_66_33` (ya en la 001) cubre la lógica del color.

---

## Out of Scope

- La UI real (UI/HUD #11, tras `/ux-design`).
- Audio del abandono (Feedback y Juice #12).

## Cierre (2026-07-26) — 🎉 SIGN-OFF DEL USUARIO

**Implementado:**
- `npc_ciudadano.gd`: barrita de ánimo sobre la cabeza, oculta mientras no espera, refrescada por DIFF.
- `npcs_flujo.gd`: `usar_paciencia` + `animo_de(persona)` / `color_de_animo` — COSMÉTICO puro: lee
  Paciencia y jamás la muta (FL5).
- `main.gd`: bloque de HUD con **satisfacción de hoy junto a la de ayer** (la que fija el dinero) y
  contador de reclamaciones, con las graves en rojo. Color por los mismos umbrales 66/33 que el ánimo.
- Verificación automática sobre Main real: los tres ánimos se pintan, la satisfacción se mueve y las
  quejas se acumulan. **Suite 410/410, exit 0.**

**Sign-off concedido (2026-07-26)**: *"paciencia está bien de momento, veo que baja mucho la barra
pero entiendo que con mejoras en la sala podría subir la paciencia por lo que lo dejamos así"*.
Checklist M1-M5 ✅. **`tolerancia_base_min` se queda en 30** por decisión del usuario.

**5 rondas de feedback antes del sign-off**, todas corregidas (detalle en la evidencia):
1. La barra **no se leía** (era de tamaño fijo y solo cambiaba de color) → rehecha como barra que
   **se vacía**: al llegar a cero, la persona se va. Lo que ves es lo que va a pasar.
2. **Faltaban accesos**: el guardado existía en el código pero no había forma de invocarlo desde el
   juego → botonera visible (Personal / Guardar / Cargar) con sus teclas.
3. **Panel de calibración F1**, solo para el desarrollador (no se instancia en un build exportado).
4. **Enmienda**: el camino hasta el sitio de espera no gasta paciencia.
5. **Mecánica nueva**: colar con el botón derecho (menú contextual) a costa del resto de la cola.

**⚠️ El sign-off trae una condición implícita** que queda registrada en la evidencia: el usuario
acepta este ritmo de cabreo **porque cuenta con que las mejoras de sala lo compensen**
(Comodidades #15, que aún no existe). Si ese sistema no llega, hay que subir `tolerancia_base_min`;
y cuando llegue, hay que revisar el número otra vez.
