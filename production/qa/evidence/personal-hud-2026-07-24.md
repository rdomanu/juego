# Evidencia UI — Personal en el mundo (story personal-007) 🎉 HITO VISIBLE

> **Story**: production/epics/personal/story-007-personal-en-el-mundo.md
> **Tipo**: UI (ADVISORY) — requiere sign-off del usuario
> **Fecha**: 2026-07-24
> **Captura**: `personal-hud-2026-07-24.png` (automática a los 2 s, solo dev)

## Qué se verifica

El bloque nuevo del HUD provisional (bajo el de Demanda) y la sustitución del hook económico:

1. **Plantilla real en Main**: nodo `Personal` (clave de save "Personal") instanciado tras
   Economía y Demanda; puestos `doc_1`/`doc_2` (`puesto_doc_general`) y `odac_1` (`puesto_odac`)
   registrados; 3 agentes con nombre (pool del config) y atributos medios asignados a ellos.
   Decisión ratificada 2026-07-24: dotación 2 ag_doc + 1 ag_odac (3/3/3/3) → nómina F1
   60+60+70 = **190 €/día, idéntica al hook `PLANTILLA_INICIAL` retirado** (cero cambio de balance).
2. **HUD**: "Plantilla: 3 · Nómina: 190 €/día" + línea de incidencia ("Plantilla al completo" en
   verde / "Hoy falta(n): [nombre] ([puesto])" en ámbar — texto además del color, respaldo daltónico).
3. **La nómina que cobra Economía a medianoche sale de los agentes reales** (`fijar_salarios_dia`,
   enmienda 006): el saldo baja 190 € en el cierre, como antes del cambio.

## Verificación manual (guion)

| # | Setup | Verify | Resultado |
|---|---|---|---|
| M1 | Lanzar ventana | "Plantilla: 3 · Nómina: 190 €/día" legible, sin solapes | ✅ usuario 2026-07-24 |
| M2 | 3× y cruzar una medianoche | Saldo −190 € en el cierre (igual que antes del cambio) | — (no ejercitado explícitamente en la demo; cubierto por test AC-PE07 automático) |
| M3 | (opcional: knob `base_ausencia` subido en vivo) | "Hoy falta: [nombre] ([puesto])" al cruzar medianoche; desaparece al reincorporarse | — (opcional, no ejercitado; cubierto por tests de la 004 + oferta de demo en vivo declinada) |
| Auto | Suite completa | 264/264, **Exit code: 0** | ✅ 2026-07-24 |

Validación previa: arranque headless 30 frames limpio (0 errores/avisos).

## Sign-off

✅ **SIGN-OFF del usuario (2026-07-24)** con la ventana abierta: bloque de plantilla/nómina visible y
entendido ("veo... plantilla y coste"). Nota de expectativas gestionada en la demo: los NPCs visibles
NO son de este epic — son de Flujo (tras Construcción), como quedó registrado al cerrar Demanda.
