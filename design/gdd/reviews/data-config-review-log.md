# Review Log — Datos y Configuración (`data-config.md`)

Historial de `/design-review` sobre este GDD. Entrada más reciente arriba.

## Review — 2026-07-19 — Verdict: NEEDS REVISION (leve) → revisiones aplicadas en la misma sesión
Scope signal: M
Specialists: ninguno (modo lean; lentes de systems-designer / economy-designer / qa-lead aplicadas en el hilo principal — los subagentes de estudio fallan con el error "1M context")
Blocking items: 1 | Recommended: 5 | Nice-to-have: 3
Summary: GDD Foundation sólido y completo (8/8 secciones), con modelo de propiedad híbrido claro, edge cases y clamps bien especificados, valores realistas (tasas CNP) y sin contradecir las constantes del Sistema de Tiempo. Único bloqueante: el `Escenario` semilla (F7) estaba incompleto respecto a su esquema (faltaban `servicios_activos` y `rango_requerido`) y quedaba sin resolver si Entrada/Seguridad entra en el MVP → resuelto poblando F7 (`servicios_activos=[Documentacion, ODAC]`, `rango_requerido=Subinspector`) y definiendo Seguridad como **ambientación fija no gestionada** (el jugador es jefe de ODAC y Documentación, no de Seguridad; simulación real diferida a un sistema futuro, Open Question #5). Recomendados resueltos: aforo `sala_espera_doc` reconciliado 32→40 para casar con la regla F8 (elección del usuario), R5·Documentación aclarada (en MVP se acota por paciencia/abandono, no por cita; la cita = sistema #14 Vertical Slice), `entities.yaml` ampliado con 14 constantes cross-boundary (salarios, costes de construcción, topes de Pozuelo, aforos), wording de `Costes` aclarado (salarios viven en `TipoAgente`), y AC afinados (AC-D03 igualdad de valor, AC-D12 R5 con demanda `D` como entrada, AC-D16 +`servicios_activos`, AC-D18 →40, AC-D20 desglosado en D20a–d).
Prior verdict resolved: First review
