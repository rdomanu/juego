# Story 006: Nómina real a Economía y persistencia

> **Epic**: Personal / Agentes
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/staff-agents.md` (PA6, F1; edge "si se guarda la partida")
**Requirement**: `TR-staff-001` *(parcial — serialización de plantilla/mercado)* + relación con TR-economy-002 (cobro) y TR-save-002 (RNG)
**Governing ADRs**: ADR-0002 (primario — `save()`/`load_state()` + grupo `Persist`; RNG lo serializa RNGService), ADR-0001 (secundario — el cobro sigue siendo de Economía, prio 20)
**ADR Decision Summary**: cada sistema serializa SU estado; Economía posee el dinero y el cobro del `nuevo_dia`; Personal solo le provee los salarios efectivos.

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (persistencia — APIs ya verificadas; `full_precision` ya aplicado en SaveManager)
**Engine Notes**: solo tipos JSON-safe en el save (StringName → String y reconvertir).

**Control Manifest Rules (Core / Foundation)**:
- Required: `save()`/`load_state()` + grupo `"Persist"`; carga sin señales ("cargar sitúa"). — ADR-0002
- Forbidden: duplicar el estado del RNG en el save de Personal. — ADR-0002

---

## ⚠️ Enmienda menor a Economía (hook previsto — aprobar al implementar)

`economia.gd` cobra hoy la nómina desde `fijar_plantilla(Array[StringName])` con el salario BASE del
catálogo (hook provisional documentado en eco-003: *"la fijará Personal en su epic con
salario_dia_efectivo = base × prima"*). Esta story ejecuta ese plan: añadir a Economía
`fijar_salarios_dia(salarios: Array[float])` (sustituye el cálculo por tipos cuando Personal existe;
`fijar_plantilla` queda para compat/tests). Personal la llama al contratar/despedir/cargar — el COBRO
sigue siendo 100 % de Economía en su prio 20.

---

## Acceptance Criteria

- [ ] **AC-PE07** `[Integration]` — GIVEN 2 agentes contratados WHEN `nuevo_dia` THEN Economía descuenta la **suma de sus `salario_dia` efectivos** (base × prima de calidad × prima de rango — F1), no el base.
- [ ] **AC-PE21** `[Integration]` — GIVEN un save con plantilla + mercado + RNG WHEN se carga THEN se **restaura todo** (agentes con atributos/estados/asignaciones, candidatos del mercado, contador de refresco), arranca en **Pausa** y la secuencia futura (mercado/ausencias) es **determinista**.
- [ ] *(ADR-0002)* — GIVEN la carga THEN **cero señales** emitidas (sin avisos retroactivos).

---

## Implementation Notes

- **Nómina**: `_actualizar_nomina()` → `_economia.fijar_salarios_dia(plantilla.map(salario_dia))`
  tras contratar/despedir/load. (Los AUSENTES cobran igual — la nómina es por plantilla, no por
  asistencia; consecuencia del orden 20/30 documentada en la 004.)
- **`save()`**: `{"plantilla": [dict por agente], "mercado": [dict por candidato],
  "jornadas_desde_refresco": int}`. Dict de agente: nombre, tipo (String), rango (String), 4 atributos,
  mando, estado (String), puesto (String). NO guardar: salarios (derivados de F1), fórmulas, RNG.
- **`load_state(d)`**: defensivo (`d.get` con defaults); reconstruir instancias Agente; validar
  `tipo_id` contra el catálogo (id huérfano → descartar con log, NUNCA invalidar el save — ADR-0002);
  re-registrar asignaciones (puestos ya registrados por el mundo ANTES de cargar — invariante del
  caller, documentar); `_actualizar_nomina()` SIN señales; grupo `Persist` en `_ready`.
- **Test de determinismo** (el corazón, patrón demanda-006): partida A → contratar/avanzar días →
  guardar (Personal + RNGService) → seguir N días registrando ausencias/mercados (secuencia A) VS
  cargar en mundo B y repetir los mismos días (secuencia B) → A == B.

---

## Out of Scope

- El HUD (007). · Slots de save / versionado (SaveManager). · Coste de contratación puntual (Open Q4).

---

## QA Test Cases

*Escritos por el hilo principal (modo lean).*

- **AC-PE07**: Given Economía real (saldo 3000) + 2 agentes: ag_doc media 5 (90 €) y ag_odac media 3 (70 €) → `disparar_ordenado(nuevo_dia)` en bus real → Then el saldo baja exactamente 160 € de nómina (más/menos los demás flujos del cierre, aislados con knobs neutros).
- **Prima real**: Given los mismos agentes → Then la nómina difiere del cálculo por salario base (90 ≠ 60) — verifica que la enmienda sustituye al hook provisional.
- **AC-PE21 (round-trip)**: Given plantilla con 3 agentes (1 Oficial cubriendo, 1 ausente), mercado con 2 candidatos, `jornadas_desde_refresco=2` → save → JSON (full_precision) → load en instancia nueva → Then todo idéntico campo a campo.
- **AC-PE21 (determinismo)**: patrón A-vs-B de arriba con semilla 4242 → secuencias de ausencias y mercados idénticas tras cargar.
- **Carga silenciosa**: Given espías de todas las señales de personal → load → 0 emisiones.
- **Id huérfano**: Given save con un agente de tipo &"ag_inexistente" → Then se descarta con log y el resto de la plantilla carga.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/personal/personal_nomina_save_test.gd` — debe existir y pasar (BLOCKING).
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (estado completo: cubriendo/ausente) — DONE antes de empezar.
- Unlocks: Story 007 (cierre visible del epic).
