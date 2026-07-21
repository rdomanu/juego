# Review Log — Datos y Configuración (`data-config.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Re-review — 2026-07-22 — Verdict: APPROVED
- **Scope signal:** M.
- **Modo:** lean (lentes systems-designer / economy-designer / qa-lead / creative-director en el hilo principal; subagentes caídos por "1M context").
- **Motivo de re-revisión:** se añadió la atención `reclamacion` (F2) y el catálogo ODAC creció a **13 denuncias**.
- **Blocking:** 0 | **Recommended:** 5 (consistencia) | **Nice:** 1 | **Decisión de diseño:** 1 (`admite_cita`) — **todo resuelto en la misma sesión.**
- **Prior verdict resolved:** Yes (el bloqueante de 2026-07-19 —Escenario semilla— sigue resuelto; sin regresión).

### Cambios de consistencia (residuos del crecimiento del catálogo)
1. **[F8]** Duración media ODAC 28→**30** (línea 312): `4×(60/30)=8→aforo 10` (casa con el chequeo R5 y el registro).
2. **[Conteo]** "8 tipos de denuncia" → **13** en Visual/Audio y en R2 (enumeración → "13 tipos, ver F2").
3. **[F8 pacing]** Neto "~110 €/día → 4–5 días" → **~40 €/día → ~12 días** (reconciliado con Economía: antes ignoraba el salario de ODAC obligatorio).
4. **[metadatos]** Status "Designed (pendiente)" → **Reviewed**; Last Updated → 2026-07-22.
5. **[consistencia]** Nota bidireccional actualizada (los dependientes del MVP ya tienen GDD).
- **Nice [registro]:** `entities.yaml` — quitada la nota stale "PENDIENTE de añadir a Datos F2" de `tramite_reclamacion` (ya está); `last_updated`→2026-07-22.

### Decisión de diseño (usuario, realismo — denunciar en la Policía Nacional NO requiere cita)
6. **Denuncias sin cita:** `admite_cita=false` en las 13 (antes 8 en `true`). La **cita previa #14** aplica solo a **Documentación** (DNI/Pasaporte/TIE). Nota de F2 reescrita; R5-válvulas ("`admite_cita`/derivación" → "derivación"); Tuning Knobs (fila `admite_cita` = false todas). AC-D05 (viogen=false) sigue válido.
7. **"Atención especial = solicitud del comisario":** anotado en el índice bajo **Presión e Influencia #16** (el colarse / atención VIP proviene de un favor del jefe, no de una cita). Fuera del MVP.
8. **Propagación a ODAC #9** *(diligencia del cambio cross-fact)*: OD9 ("todas admiten cita, directriz usuario") reescrito a "Sin cita (realista)"; Open Q7 actualizada.

### Veredicto senior (síntesis)
El crecimiento del catálogo (8→13 denuncias, +`reclamacion`) estaba bien en F2 pero dejó residuos numéricos en los chequeos de sanity, ya barridos y reconciliados con Economía. La decisión de realismo (denuncias sin cita) **simplifica el modelo y elimina la incoherencia del criterio `admite_cita`**, con la mecánica de "colarse" reubicada correctamente en #16. **Datos queda re-aprobado.**

---

## Review — 2026-07-19 — Verdict: NEEDS REVISION (leve) → revisiones aplicadas en la misma sesión
Scope signal: M
Specialists: ninguno (modo lean; lentes de systems-designer / economy-designer / qa-lead aplicadas en el hilo principal — los subagentes de estudio fallan con el error "1M context")
Blocking items: 1 | Recommended: 5 | Nice-to-have: 3
Summary: GDD Foundation sólido y completo (8/8 secciones), con modelo de propiedad híbrido claro, edge cases y clamps bien especificados, valores realistas (tasas CNP) y sin contradecir las constantes del Sistema de Tiempo. Único bloqueante: el `Escenario` semilla (F7) estaba incompleto respecto a su esquema (faltaban `servicios_activos` y `rango_requerido`) y quedaba sin resolver si Entrada/Seguridad entra en el MVP → resuelto poblando F7 (`servicios_activos=[Documentacion, ODAC]`, `rango_requerido=Subinspector`) y definiendo Seguridad como **ambientación fija no gestionada** (el jugador es jefe de ODAC y Documentación, no de Seguridad; simulación real diferida a un sistema futuro, Open Question #5). Recomendados resueltos: aforo `sala_espera_doc` reconciliado 32→40 para casar con la regla F8 (elección del usuario), R5·Documentación aclarada (en MVP se acota por paciencia/abandono, no por cita; la cita = sistema #14 Vertical Slice), `entities.yaml` ampliado con 14 constantes cross-boundary (salarios, costes de construcción, topes de Pozuelo, aforos), wording de `Costes` aclarado (salarios viven en `TipoAgente`), y AC afinados (AC-D03 igualdad de valor, AC-D12 R5 con demanda `D` como entrada, AC-D16 +`servicios_activos`, AC-D18 →40, AC-D20 desglosado en D20a–d).
Prior verdict resolved: First review
