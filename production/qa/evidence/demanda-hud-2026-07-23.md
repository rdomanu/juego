# Evidencia — Story demanda-007: Demanda en el mundo (HUD del esqueleto)

> **Story**: production/epics/demanda/story-007-demanda-en-el-mundo.md · Tipo UI (ADVISORY)
> **Fecha**: 2026-07-23 (implementación) / 2026-07-24 (sign-off)
> **Captura**: `demanda-hud-2026-07-23.png` (auto-captura a los 2 s de correr, mecanismo del esqueleto)
> **Build**: main (suite 220/220, exit 0; Main validado headless 180 frames sin errores)

## Qué se verificó (ventana real, 2 sesiones)

- **Sesión 1 (2026-07-23)**: partida arrancada desde las 00:00 (medianoche) — el usuario observó **1 sola
  llegada** en la madrugada. Diagnóstico: **comportamiento CORRECTO** (DG6: Documentación cerrada hasta
  las 08:00; solo el goteo nocturno de ODAC, ~0,75/h con `mult_nocturno_odac`). La demo se repitió con
  guion (esperar a la apertura).
- **Sesión 2 (2026-07-24)**: el usuario vio el **contador "Llegadas hoy" subir** tras la apertura de las
  08:00 (Manual 1 ✅) y el **indicador "Demanda Doc: BAJA"** visible con texto + color (Manual 3 ✅ —
  BAJA por enero ×0.6, ver nota). El frenazo tras el cierre de 14:30 se observó en sesión 1 por la
  inversa (noche = solo goteo) (Manual 2 ✅). El reset de medianoche (Manual 4) queda cubierto por el
  test automático de orden prio-40 (`demanda_tick_ventana_test.gd`).
- Sesiones sin un solo error ni warning en consola.

## Sign-off

**✅ FIRMADO por el usuario (manu.rdo) el 2026-07-24 — opción A: hito aceptado tal cual** (alcance
aprobado del epic: contador de llegadas + nivel BAJA/MEDIA/ALTA).

Anotaciones del sign-off:
- **Expectativa registrada**: el usuario esperaba VER personas entrar. Los muñecos visibles son el epic
  **Flujo** (+ Construcción); Demanda es el motor invisible (la ficha `Persona` ya viaja por el bus y
  Flujo la recogerá). Se rechazó el "caramelo visual" provisional (+1 flotante) — se hará bien en Flujo.
- **Arranque enero-BAJA**: la partida empieza en Mes 1 (enero, ×0.6 → ~27/día, nivel BAJA). Aceptado
  tal cual en el sign-off; queda como knob de tuning (`mult_estacional` / mes inicial) para playtest.
- **Idea apuntada (tuning futuro, Tiempo)**: hora de arranque de la partida a las ~07:55 para abrir con
  acción (hoy arranca a las 00:00 y la madrugada es el momento más muerto).
