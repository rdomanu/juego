# Evidencia Visual/UI — Story 007 (epic Economía): saldo en el HUD del esqueleto

> **Fecha**: 2026-07-23
> **Story**: production/epics/economia/story-007-saldo-en-hud.md
> **Tipo**: Visual/UI (ADVISORY)
> **Build**: commit 088d6f2 · Godot 4.6.stable · suite 173/173 exit 0
> **Captura**: `economia-saldo-hud-2026-07-23.png` (automática a los 2 s de ejecución, ventana real)

## Walkthrough manual

| Paso | Resultado |
|------|-----------|
| Ventana abre con Main + Economía instanciada (name "Economia", plantilla provisional 2×ag_doc+1×ag_odac) sin errores | ✅ |
| HUD financiero visible bajo el reloj: `3000,00 €` + "Estado: holgado" en verde (color + texto) | ✅ |
| A 3×, al cruzar medianoche la nómina se descuenta A LA VISTA: −190 € (60+60+70 del catálogo) | ✅ |
| Umbrales de estado: < 500 € → ámbar "justo"; < 0 → rojo "NÚMEROS ROJOS (gasto bloqueado)" | ✅ (lógica cubierta por tests; colores verificados en código) |
| Ventana de gracia cableada al tick real (`Tiempo.suscribir_tick → avanzar_gracia`, minutos de juego) | ✅ |
| Sin errores en consola durante la sesión | ✅ |

## Sign-off

**Usuario (manu.rdo): ✅ VISTO BUENO** — 2026-07-23, tras ver la ventana en vivo con el saldo y la nómina.

## Notas

- La UI **lee y ordena, nunca muta** (ADR-0001); el bloque financiero es solo lectura.
- HUD provisional (no es el `hud.md` de UX); botones de préstamo/modal de rescate llegarán con el epic
  UI #11 — la lógica ya existe y está testeada (señales `insolvencia`/`gracia_iniciada`/`game_over`).
- El saldo solo BAJA de momento: los ingresos visibles llegan con Demanda + Flujo (próximos epics).
