# QA Plan — Sprint 2 · "La comisaría se construye y se llena (Core B)" · 2026-07-24

> **Modo**: lean (review-mode del proyecto) — plan a NIVEL DE EPIC (las stories las crean C2-1/C2-4;
> al escribirlas se embeben estos casos en su sección "QA Test Cases", patrón del proyecto). Gates de
> evidencia según `coding-standards.md` §Testing.
> **Suite base al abrir el sprint**: 264/264, exit 0.
> **Engine**: Godot 4.6 — ⚠️ los dos epics usan API post-cutoff: verificar SIEMPRE contra
> `docs/engine-reference/godot/modules/tilemap-2d.md` (Construcción) y `modules/navigation.md` (Flujo).

## Clasificación anticipada y evidencia exigida

### Epic Construcción (Must Have — C2-2) · GDD construction-layout.md (AC-CO01..18)

| Área (→ story futura) | Tipo | Gate | Evidencia exigida | Casos clave del GDD |
|-------|------|------|-------------------|---------------------|
| Validación de colocación (F6: dentro del edificio, sin solapes, área ≥ mínimo, tipo de sala correcto) | Logic | **BLOCKING** | `tests/unit/construccion/` | AC-CO01, AC-CO02, AC-CO03 |
| Costes y pago (F1 sala por área, F2 puesto/objeto, gate E4 de Economía, clamp corrupto) | Logic/Integration | **BLOCKING** | `tests/unit/construccion/` + Economía real | AC-CO04 (3×3=380; 5×4=600), AC-CO05 (sin caja → saldo intacto), AC-CO06, AC-CO18 (clamp ≥0) |
| Aforo de sala de espera (F3 por asientos con tope por densidad) | Logic | **BLOCKING** | `tests/unit/construccion/` | AC-CO07 (5×4 d0.7 → 14; tope), AC-CO08 (sin asientos → aforo 0) |
| Puestos útiles (F5 informativo, sin tope duro) | Logic | **BLOCKING** | ídem | AC-CO09 (10 puestos con 5 útiles → permitido), AC-CO10 (ceil(17.6/4)=5) |
| Demolición y mover (F4 reembolso, cascada con confirmación, mover gratis) | Integration | **BLOCKING** | `tests/integration/construccion/` | AC-CO11 (500×0.5=250), AC-CO12, AC-CO14. **AC-CO13 (puesto atendiendo termina y luego demuele) SE DIFIERE a Flujo** (no hay atención aún — patrón AC-PE10) |
| Puente a Personal/Flujo (registrar_puesto/quitar_puesto — API YA existente de personal-003) + Pausa construible | Integration | **BLOCKING** | ídem | AC-CO15 (construido → usable vía gate FL4; sin construir → no existe), AC-CO16 |
| Save/load del layout (Vector2i→[x,y] vía SerialUtil) | Integration | **BLOCKING** | round-trip JSON real | AC-CO17 (restaura rejilla, salas, puestos, objetos) |
| Ratón↔celda + preview fantasma + colocación VISIBLE (HITO) | UI | ADVISORY | `production/qa/evidence/construccion-hud-[fecha].md` + PNG + **sign-off usuario** | preview verde/rojo según F6; clic coloca y cobra; texto además de color |

### Epic Flujo (Should Have — C2-5) · GDD flow-queues.md (AC-FL01..27)

| Área (→ story futura) | Tipo | Gate | Evidencia exigida | Casos clave del GDD |
|-------|------|------|-------------------|---------------------|
| Persona (máquina 7 estados) + turnos por servicio | Logic | **BLOCKING** | `tests/unit/flujo/` | AC-FL01, AC-FL02 (turnos consecutivos crecientes) |
| Colas: FIFO puro Doc, prioridad ODAC, compatibilidad de puesto (F7) | Logic | **BLOCKING** | ídem | AC-FL03 ({3,1,2}→1,2,3), AC-FL04 (Prioritaria antes), AC-FL05 (ninguna compatible → espera), AC-FL06 |
| Emparejamiento + gate FL4 de Personal + sin doble asignación | Integration | **BLOCKING** | `tests/integration/flujo/` con Personal real | AC-FL07 (sin agente NO atiende), AC-FL08, AC-FL23 (2 puestos, 1 persona → la toma exactamente uno, menor id) |
| Duración efectiva (F1 con `modificador_produccion` de Personal) + clamps | Logic | **BLOCKING** | ídem | AC-FL09 (12×1.0=12; ×0.7=8,4), AC-FL10 (clamp 1 min) |
| Cierre de atención → **`tramite_completado` UNA vez → Economía cobra → EL SALDO SUBE** | Integration | **BLOCKING** | con Economía real | AC-FL11 (emisión única, Persona Resuelta, puesto Libre) |
| Aforo de sala (F6) + cola exterior + crecimiento sin tope | Integration | **BLOCKING** | ídem | AC-FL12 (39/40 vs 40/40), AC-FL13 (41ª fuera; entra la primera al liberar), AC-FL14 |
| Pausa exacta + reconfigurar/cerrar puesto + compromiso de servicio | Integration | **BLOCKING** | ídem | AC-FL15, AC-FL25 (5 min exactos tras pausa), AC-FL16, AC-FL17, AC-FL18 (en Llamada/atención NO abandona) |
| Fórmulas de capacidad (F2 throughput, F3 capacidad, F4 ρ, F5 espera estimada) | Logic | **BLOCKING** | `tests/unit/flujo/` | AC-FL19 (390/15=26), AC-FL20 (≈260 a tope), AC-FL21 (ρ=2→1), AC-FL22 (120/60/indefinida) |
| Cierre de Documentación (última admisión, vaciar cola admitida) | Integration | **BLOCKING** | ídem | AC-FL24 (la peonada en sí es de Horarios #13 — aquí solo el hook) |
| Save/load + **determinismo** (el AC rey) | Integration | **BLOCKING** | round-trip + secuencia repetida | AC-FL26 (restaura N/estados/t, arranca en Pausa, 0 eventos), **AC-FL27 (misma secuencia → colas/asignaciones/eventos idénticos)** |
| NPCs navegando (NavigationServer2D — **cosmético por diseño FL5, FUERA del test determinista**) + demo integradora (HITO) | Visual/UI | ADVISORY | `production/qa/evidence/flujo-demo-[fecha].md` + PNG + **sign-off usuario** + **FPS** | gente entra→cola→puesto→sale; saldo SUBE en el HUD; **≥60 FPS** con volumen objetivo (spike QQ-02 da margen: 150 NPCs ≈ 145 FPS); gotcha nav: target tras 1er physics frame |

## Reglas transversales (test-standards del proyecto)

- Determinismo: sin reloj real ni RNG global; tiempo/RNG **inyectados o sembrados**; floats con
  `is_equal_approx` (ojo fronteras exactas → epsilon; lección personal-001).
- Aislamiento: bus/Tiempo/Economía/Personal **instancias propias** en tests (nunca autoloads reales
  salvo Datos/RNGService); teardown limpia; el test de Pausa con physics real en árbol (patrón DM11/PE19).
- La **lógica de Flujo se testea SIN navegación** (FL5: mover el muñeco es cosmético; la simulación es
  determinista por estados) — la nav solo se verifica visualmente + FPS.
- Nombres `test_[escenario]_[esperado]`; Arrange/Act/Assert; valores esperados del **catálogo real**
  (si el catálogo cambia y el test cae, es detección correcta de divergencia).
- Post-cutoff: toda llamada a `TileMapLayer`/`NavigationServer2D` se contrasta ANTES con
  `docs/engine-reference/godot/modules/`.

## Smoke test scope del sprint

1. Suite completa → **Exit code 0** (sin desactivar tests).
2. Arranque headless de Main con el mundo completo (Economía+Demanda+Personal+Construcción[+Flujo]) sin errores.
3. Construir un puesto → aparece, cobra, Personal puede asignarle agente (puente AC-CO15).
4. (Al cerrar Flujo) un ciudadano completa el ciclo entero y el saldo SUBE.
5. Save/load round-trip del mundo completo sin pérdida (grupo Persist al completo).
6. Rendimiento: sin caídas bajo 60 FPS con el volumen de NPCs objetivo.

## Playtest requirements

Sin sesiones formales de playtest en este sprint: los dos HITOS VISIBLES con **sign-off del usuario**
(colocación en Construcción; demo integradora en Flujo) hacen de validación de "feel". El playtest
formal llegará con el bucle completo (Paciencia + objetivo/ascenso).

## Sign-off del sprint

Patrón lean: evidencia por story + verificación independiente del hilo principal (re-ejecución de la
suite) + sign-off del usuario en los hitos visibles. Sin S1/S2 abiertos al cierre.
