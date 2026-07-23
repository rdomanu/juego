# Story 007: Demanda en el mundo — la comisaría respira 🎉 (HITO VISIBLE)

> **Epic**: Generación de Demanda
> **Status**: Complete — HITO VISIBLE firmado por el usuario (2026-07-24, opción A)
> **Layer**: Core (instanciación) + Presentation (HUD del esqueleto)
> **Type**: UI
> **Estimate**: S-M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/demand-generation.md` (UI Requirements — indicador BAJA/MEDIA/ALTA siempre visible con respaldo daltónico; Player Fantasy — ver la marea)
**Requirement**: `TR-demand-003` *(parcial — la presentación del nivel; el contador de llegadas es HUD de esqueleto, decisión del usuario 2026-07-23)*

**Governing ADRs**: ADR-0001 (primario — la UI lee y escucha el bus; la lógica NUNCA llama a la UI; dibujo en `_process`)
**ADR Decision Summary**: la UI escucha señales del bus (`persona_generada`, `nivel_demanda_cambiado`) y lee getters; jamás muta estado de juego.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: HUD del esqueleto por código (Labels en CanvasLayer, patrón del reloj y el saldo). Referencias cacheadas `@onready`.

**Control Manifest Rules (Presentation)**:
- Required: la UI lee estado y escucha el bus; **nunca muta**. — ADR-0001
- Required: dibujo en `_process`; textos/umbrales **no hardcodeados en la UI** (los provee Demanda/config). — manifest / GDD UI Requirements.
- Required: respaldo daltónico — el nivel lleva **texto además del color**. — GDD UI Requirements.

---

## Acceptance Criteria

*(Sin AC numerado de GDD — historia de instanciación + presentación; evidencia ADVISORY con sign-off. Decisión del alcance visible: usuario 2026-07-23 — "Llegadas + nivel".)*

- [ ] Demanda instanciada en `Main` (mundo de producción), cableada: `usar_bus(EventBus)`, `usar_tiempo(Tiempo)`, config cargada de `datos/config/demanda.tres`, grupo `Persist` activo.
- [ ] El HUD del esqueleto muestra **"Llegadas hoy: N"** — sube al ritmo de la mañana (pico 08:00–09:00), se frena tras el cierre de Documentación (14:30) y de madrugada solo avanza con el goteo de ODAC.
- [x] El HUD muestra el **nivel de demanda** con texto + color (BAJA verde / MEDIA ámbar / ALTA rojo — respaldo daltónico: el texto siempre presente). *(Corrección al implementar: con DG13 derivado en el arranque, la partida empieza en Mes 1 = enero ×0.6 → arranca en **BAJA**, no MEDIA. Aceptado en el sign-off.)*
- [ ] El contador se **resetea a 0** en el `nuevo_dia` (medianoche) — coherente con el reset de la 003.
- [ ] Suite completa en verde tras la integración (sin regresiones en Tiempo/Economía/SaveManager).

---

## Implementation Notes

- **Main**: añadir el nodo `Demanda` junto a `Economia` (mismo patrón de instanciación y cableado que eco-007). Orden de suscripción al tick: Demanda es la única de simulación por ahora (comentar el orden ADR para cuando llegue Flujo).
- **HUD**: la UI escucha `persona_generada` para el contador (o hace pull de `llegadas_hoy` en `_process` — elegir pull para no duplicar estado; el contador vive en Demanda, la UI solo lo pinta) y `nivel_demanda_cambiado` + getter `nivel_demanda()` para el tramo inicial.
- Colores del nivel: reutilizar la paleta de estados del saldo (verde/ámbar/rojo) por coherencia visual del esqueleto.
- **HITO VISIBLE** (regla de la sesión): al terminar, avisar al usuario y **ABRIR LA VENTANA** (`Godot_v4.6-stable_win64_console.exe --path C:\Users\manur\juego` en background). Guion de demo: reanudar, poner 3×, ver el contador acelerar en la mañana; saltar a la tarde y verlo frenarse; el indicador MEDIA visible junto al saldo y el reloj.
- Validación previa headless (`--headless --quit-after N`, 0 errores) antes de abrir la ventana.

---

## Out of Scope

- El **saldo NO sube todavía**: el ingreso llega con `tramite_completado`, que emitirá **Flujo** cuando exista (C1-6). Demanda solo hace que la gente *llegue*. (Avisado al usuario 2026-07-23 — expectativa ajustada.)
- Muñecos andando por la pantalla (Flujo + arte).
- El aviso de hora punta / evento estacional (UI/Feedback, Presentation — opcional GDD).
- El HUD definitivo (UI/HUD #11 — esto es el esqueleto).

---

## QA Test Cases

*Verificación manual (tipo UI) — evidencia + sign-off.*

- **Manual 1 — llegadas visibles**: Setup: lanzar ventana, reanudar, 3×. Verify: "Llegadas hoy" sube durante la mañana (varias por hora de juego). Pass: el contador crece sin errores en consola.
- **Manual 2 — la persiana**: Setup: dejar correr hasta pasadas las 14:30. Verify: el ritmo cae bruscamente (solo goteo ODAC); de madrugada casi parado. Pass: el cambio de ritmo es apreciable a simple vista.
- **Manual 3 — nivel**: Setup: arranque semillas MVP. Verify: indicador "Demanda Doc: BAJA" en verde (enero ×0.6), texto legible. Pass: texto + color correctos; sin solaparse con reloj/saldo.
- **Manual 4 — medianoche**: Setup: cruzar las 00:00. Verify: contador vuelve a 0 (y la nómina de Economía sigue apareciendo — sin regresión). Pass: ambos HUD conviven.
- **Automatizado (humo)**: suite completa `-a res://tests/unit -a res://tests/integration` → Exit code 0.

---

## Test Evidence

**Story Type**: UI (ADVISORY) — requiere **sign-off del usuario**.
**Required evidence**: `production/qa/evidence/demanda-hud-[fecha].md` + captura PNG + sign-off explícito del usuario en conversación.
**Status**: [x] `demanda-hud-2026-07-23.md` + PNG — **FIRMADO por el usuario 2026-07-24 (opción A)**. Suite 220/220, exit 0.

---

## Dependencies

- Depends on: Story 006 (epic completo por debajo) — DONE antes de empezar.
- Unlocks: cierre del epic Demanda (`/story-done` × 7) → C1-5 (stories de Personal).
