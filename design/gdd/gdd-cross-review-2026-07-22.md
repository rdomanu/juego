# Cross-GDD Review Report

**Date:** 2026-07-22
**GDDs Reviewed:** 12 (MVP completo: Tiempo, Datos, Economía, Flujo, Demanda, Personal, Construcción, Documentación, ODAC, Paciencia, UI/HUD, Feedback)
**Systems Covered:** los 12 sistemas MVP
**Modo:** lean / hilo principal (subagentes caídos por "1M context"; lentes de consistencia + game-design theory + scenario walkthrough aplicadas manualmente). Ejecutado tras cerrar la Fase 1 (12/12 `/design-review` APPROVED) + `/consistency-check` 11ª–13ª.
**Pilares:** 1) Realismo con alma · 2) La comisaría está viva · 3) De subinspector a toda España · 4) Tu comisaría, tus decisiones · 5) Presión e influencia.
**Anti-pilares:** NO acción/disparos · NO caricatura · NO burocracia tediosa · NO política partidista.

---

## Verdict: **CONCERNS** (0 blockers; 2 warnings de teoría de diseño; 1 nota para arquitectura)

Sin blockers → **no impide comenzar la arquitectura.** Los 2 warnings son de balance/alcance, no de coherencia, y convergen en un mismo punto (dar peso mecánico real a la valoración de jefes / ODAC en el objetivo del MVP).

---

## Consistencia entre GDD (Fase 2) — PASS

Las revisiones individuales + los consistency-checks 11ª–13ª ya resolvieron los conflictos cruzados que suelen aflorar aquí:

- **2a Bidireccionalidad de dependencias:** ✅ los 12 GDD se listan mutuamente (notas bidireccionales actualizadas durante la Fase 1).
- **2b Contradicciones de reglas:** ✅ compromiso de servicio (llamada/atención no abandona) consistente en Flujo/Paciencia/Personal/Construcción/Documentación; regla de cierre (última admisión) consistente en Economía/Flujo/Documentación; suelo `retorno_dgp` 0.15 no lo bypassa nadie.
- **2c Stale references:** ✅ 0 restos tras los consistency-checks (throughput ODAC 28→30; `base_reputacion`/`base_abandono` retirados; `bonus_satisfaccion`→`factor_trato`).
- **2d Ownership conflicts:** ✅ los dos grandes ya reconciliados en la Fase 1 — reputación de ODAC (Paciencia posee la escala 0–100; ODAC aporta `peso_prioridad`) y `factor_trato` (Personal produce el multiplicador que Paciencia espera).
- **2e Compatibilidad de fórmulas (cadenas):** ✅ **impecable.** Demanda (45/36 día) → Flujo (cap 260/128) → Economía (tarifa × retorno 0.15–0.45); Personal `factor_trato` 0.5–1.5 → Paciencia F2; `modificador_produccion` 0.5–1.3 → Flujo F1; `peso_prioridad` 2.5 → Paciencia F3; mezcla de 13 denuncias → 29,75 min → throughput 32 → 128 ≥ demanda 36 (R5). Todas las cadenas encajan.
- **2f AC cruzados:** ✅ AC-E03b ↔ AC-PS14 (ingreso estable intra-jornada) y AC-FL18 ↔ AC-PS19 (compromiso de servicio) concuerdan.

---

## Teoría de diseño (Fase 3) — CONCERNS

- **3a Loops de progresión:** ✅ un solo loop dominante (gestionar bien → satisfacción/dinero + reputación → valoración de jefes → ascenso). Documentación (dinero) y ODAC (reputación) dan recursos **distintos** y complementarios (tensión intencional), no compiten como loop.
- **3b Attention budget:** ⚠️ ver **W1**.
- **3c Estrategia dominante:** ⚠️ ver **W2**.
- **3d Economía:** ✅ bien acotada — el dinero tiene sinks continuos (salarios), el positive-feedback se autolimita por la demanda (capacidad ≠ demanda), los préstamos tienen sink (penalización + devolución). Sin surplus infinito ni runaway.
- **3e Curva de dificultad:** ✅ estable en el MVP (el escalado es por escenario/rango, post-MVP #18/#26); la variación estacional (DG13) es cíclica y aprendible, no una divergencia monótona.
- **3f Alineación de pilares:** ✅ los 12 sistemas sirven pilares explícitos; **0 violaciones de anti-pilares**.
- **3g Fantasía coherente:** ✅ las 12 fantasías refuerzan una identidad única (el subinspector-gestor en la mesa de mando, no acción de calle) — coherente con la Core Fantasy del concepto.

### ⚠️ Warning W1 — Carga cognitiva en el límite alto
Durante el core loop conviven ~4–5 sistemas activos (Flujo/colas, Personal/asignación, Documentación/horario-peonada, ODAC/reconfiguración, + Economía/préstamos). El límite cómodo para la mayoría de jugadores es 3–4.
**Mitigantes ya diseñados:** el **Oficial** (Personal PA8/PA9: cobertura + canalización automáticas reducen microgestión), la **pausa** (pensar sin coste, Tiempo), y la **revelación progresiva por rango** (el MVP arranca con menos, Pilar 3).
**Recomendación:** verificar en el 1er playtest que 4–5 sistemas activos no abruman; el Oficial y la pausa son las válvulas de alivio. No bloquea.

### ⚠️ Warning W2 — Potencial estrategia dominante (Documentación > ODAC)
Documentación genera dinero; ODAC solo cuesta (rinde reputación). Si la **valoración de jefes** (que la reputación de ODAC alimenta) no tiene peso mecánico suficiente **en el MVP**, la estrategia óptima sería "dotar ODAC al mínimo y exprimir Documentación".
**Contexto:** es el mismo tema de alcance que salió en la revisión de Paciencia #10, abordado con la **decisión de ascenso** (valoración de jefes = marcador visible del MVP; ascenso efectivo post-MVP con #18/#28/#29).
**Mitigantes ya diseñados:** los abandonos de Prioritarias de ODAC (VioGén) hunden la satisfacción vía `peso_prioridad` 2.5; las reclamaciones graves cuentan aparte; el bucle Doc→ODAC (reclamaciones) también penaliza descuidar Documentación.
**Recomendación:** al **definir el objetivo de eficiencia del MVP**, asegurar que la valoración de jefes (reputación de ODAC + reclamaciones graves) **pese de verdad**, para que descuidar ODAC tenga coste tangible. No bloquea, pero es la decisión de balance más importante del MVP.

### ℹ️ Info — El MVP carece de "meta final" dura hasta #18
El ascenso efectivo es post-MVP (requiere 1 año + valoración ≥75% + curso, sistemas #18/#28/#29). En el MVP el objetivo es "no arruinarte + subir la valoración de jefes". Mitigado porque el core loop de gestión es divertido por sí solo (validado en el prototipo) y la valoración da dirección. Aceptable para un MVP cuya hipótesis es "¿es divertido el flujo?".

---

## Escenarios cruzados (Fase 4) — PASS (1 nota para arquitectura)

**Escenarios recorridos (5):**
1. **Hora punta en Documentación** — Demanda(pico) → Flujo(cola) → Paciencia(drenaje) → Economía(retorno día siguiente). Race llamada-vs-abandono resuelto (gana llamada). ✅
2. **Bucle abandono Doc → reclamación ODAC (PS13)** — Paciencia → Flujo → ODAC; sin recursión (AC-PS17); Feedback telegrafía el origen. ✅
3. **Ausencia de agente + cobertura del Oficial** — Personal(F4/F6) → Flujo; ausencias deterministas al inicio del día (PA11). ✅
4. **Cierre de jornada (`nuevo_dia`)** — Tiempo → Paciencia(cierra sat) + Economía(salarios/recargo/penalización). Ver nota abajo.
5. **Insolvencia + rescate en hora punta** — Economía → Tiempo(pausa); todo el juego respeta la pausa. ✅

**Sin blockers.** Los race conditions críticos están resueltos.

### ℹ️ Nota para arquitectura (no es defecto de diseño)
En el evento `nuevo_dia`/`nuevo_mes` confluyen varios handlers: Paciencia cierra `sat_cierre`, Economía cobra salarios/recargo/penalización y (al mes) balance, Tiempo avanza el calendario, Demanda aplica el perfil estacional. El **orden determinista de esos handlers** debe fijarlo el **ADR del bus de eventos** — los GDD lo dejan (correctamente) a arquitectura. *(No hay conflicto: el retorno DGP intra-jornada usa `sat_cierre_doc` de la jornada anterior, y los trámites se cobran durante la jornada, no en el evento de cierre — así que el orden entre "Economía cobra salarios" y "Paciencia cierra sat" no afecta al resultado; solo hay que fijarlo por determinismo.)*

---

## GDDs marcados para revisión

**Ninguno.** Los 2 warnings son propiedades emergentes (balance/alcance), no defectos de un GDD concreto. Se resuelven al definir el objetivo del MVP (W2) y en playtest (W1); no requieren reabrir ningún GDD.

---

## Acciones recomendadas antes de / durante la arquitectura

1. **(Balance, no bloqueante)** Tener presente **W2** al definir el objetivo de eficiencia del MVP: la valoración de jefes / reputación de ODAC debe pesar para que ODAC importe.
2. **(Arquitectura)** El ADR del bus de eventos debe fijar el **orden de handlers** de `nuevo_dia`/`nuevo_mes`.
3. **(Playtest)** Vigilar **W1** (carga cognitiva) en el 1er playtest.

Ninguna bloquea `/create-architecture`.
