# Review Log — Economía / Presupuesto (`economy-budget.md`)

## Review — 2026-07-19 — Verdict: NEEDS REVISION → RESUELTO en la misma sesión
- **Modo:** lean (subagentes de estudio caídos por "1M context"; lentes economy-designer / systems-designer / qa-lead / creative-director aplicadas en el hilo principal).
- **Scope signal:** L (multi-sistema, 8 fórmulas, estado mutable persistente, ADR de persistencia pendiente).
- **Especialistas:** ninguno vía subagente (lentes en hilo principal).
- **Bloqueantes:** 3 | **Recomendados:** 4 | **Nice-to-have:** 3.
- **Prior verdict resolved:** primera revisión.
- **Completitud:** 8/8 secciones + Visual/Audio, UI, Open Questions.

### Bloqueantes (resueltos)
1. **Contradicción del recargo de deuda (F6 vs Edge Case vs AC-E09/E10).** F6 y el edge de determinismo
   aplicaban el recargo el mismo día tras la nómina; el edge case y AC-E09 decían "desde el día siguiente".
   → **Fix:** el recargo se calcula sobre la **deuda de apertura** del día, antes de los gastos de hoy
   (F5/F6 reescritas; orden determinista: recargo → gastos → reinicio). Añadidos AC-E10b (compuesto) y
   AC-E10c (orden).
2. **Ciclo de vida del préstamo sin definir (E9/F8): "activo" vs "usados", ¿penalización permanente?**
   → **Fix (decisión del usuario):** modelo **híbrido** = parte fija (`penalizacion_fija_prestamo`=30) +
   mordida % de ingresos (`pct_ingreso_prestamo`=0.20), **por préstamo vivo**; el préstamo se puede
   **devolver** (principal 1500 €) para cancelar su coste; el **strike no se recupera**. Dos contadores:
   `prestamos_usados` (histórico, límite/game over) y `prestamos_vivos` (coste). F8 reescrita; entidad
   antigua deprecada en el registro.
3. **Hueco de la máquina de estados en Insolvencia (Open Q#4).**
   → **Fix (decisión del usuario):** al tocar el suelo, **pausa + modal**; si se rechaza, **ventana de
   gracia de 12 h** (`ventana_gracia_insolvencia_horas`) → inyección automática con aviso; si sube durante
   la gracia, se cancela; sin préstamos disponibles → game over. States/Edge Cases/AC-E14a–e actualizados.
   Open Q#4 marcada RESUELTA.

### Recomendados (resueltos)
1. **Pacing con ODAC obligatorio:** el razonamiento de `caja_inicial_eur` ignoraba el salario de ODAC
   (obligatorio, sin ingreso). → Corregido el razonamiento (neto real ~40 €/día; ~12 días/ampliación);
   valor 3000 mantenido, a validar en playtest (Open Q#3).
2. **Telegrafía del último salvavidas:** añadida confirmación al pedir el último préstamo + aviso "sin red"
   + botón de saldar (UI Requirements).
3. **AC faltantes:** añadidos AC-E10b/c, E12b, E14a–h (gracia, devolución, preventivo→game over,
   `num_prestamos_max=0`, orden determinista).
4. **Término "strike":** aclarado = `prestamos_usados` (histórico); no se recupera al devolver.

### Nice-to-have (resueltos)
1. `data-config.md` F8: añadido `clamp(sat,0,100)` a la redacción de la fórmula.
2. `systems-index.md` Dependency Map: "Economía depende de: Datos" → "Datos, Tiempo"; Status → Reviewed;
   tracker GDDs revisados 2→3.
3. Nota de tuning: `interes_deuda_diario` alto cerca del suelo puede precipitar la insolvencia (interacción
   de knobs).

### Cambios en el registro (`entities.yaml`)
- `penalizacion_prestamo_diaria` → **deprecated**.
- Añadidos: `penalizacion_fija_prestamo` (30), `pct_ingreso_prestamo` (0.20),
  `ventana_gracia_insolvencia_horas` (12).
- `num_prestamos_max` e `importe_prestamo_eur`: notas actualizadas (histórico; coste de saldar).

### Veredicto senior (síntesis)
GDD de alta calidad; el riesgo estaba concentrado en el modelo de préstamos/insolvencia (E9). Cerrada su
aritmética (recargo) y su ciclo de vida (devolución + gracia) para que el game over terminal —decisión
consciente del usuario— no traicione la anti-fantasía "no es quiebra cruel". Listo para
`/consistency-check` y, tras él, para continuar con el siguiente sistema del MVP.
