# Story 005: La reputación se convierte en dinero (retorno DGP)

> **Epic**: Paciencia y Satisfacción
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S (~1-2 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: —

## Context

**GDD**: `design/gdd/patience-satisfaction.md` (F4 — *referenciada*, dueña: Economía) +
`design/gdd/economy-budget.md` (retorno DGP)
**Requirement**: `TR-patience-003` (Economía usa `sat_cierre` **anterior** → ingreso estable intra-jornada)
**Governing ADRs**: ADR-0001 (primario — API pública entre sistemas)
**ADR Decision Summary**: la fórmula F4 es de **Economía**; Paciencia solo **aporta el dato**
(`sat_cierre_doc` de la jornada anterior). Esta story es el **cableado + la prueba**, no una fórmula nueva.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: n/a.

**Control Manifest Rules (Feature)**:
- Required: Economía **lee** el `sat_cierre` de AYER, nunca la media viva de hoy — decisión de diseño
  ya reconciliada (2026-07-21): el ingreso no puede fluctuar dentro del mismo día. — arquitectura
- Forbidden: que Paciencia toque el saldo (Economía cobra; Paciencia informa). — ADR-0001

---

## Acceptance Criteria

- [ ] **AC-PS14** `[Integration]` — GIVEN `sat_cierre_doc = 50` de ayer WHEN se cobran trámites hoy THEN
      `retorno_dgp = 0.30` **fijo toda la jornada** (no cambia intra-día aunque la media de hoy suba o baje).

---

## Implementation Notes

- Cableado en `Main`: inyectar Paciencia en Economía (o el hook inverso, con el patrón de callables ya
  usado en `fijar_hook_horas_extra` / `fijar_puede_demoler`). Sin Paciencia cableada, Economía debe
  seguir funcionando con su valor por defecto (**compatibilidad: los tests de Economía no se tocan**).
- `retorno_dgp = retorno_dgp_min + (max − min) × (sat_cierre_doc_ayer / 100)` → sat 0 = 0.15 · sat 50 =
  0.30 · sat 100 = 0.45. La fórmula ya vive en Economía: aquí solo se le da el dato bueno.
- **La prueba que importa**: cobrar dos trámites con la media de hoy cambiando entre medias y verificar
  que el retorno aplicado es **el mismo** en ambos.
- Verificar que el ciclo completo cierra: atender bien hoy → `sat_cierre` alto → **mañana** cada trámite
  paga más. Es el bucle de recompensa central del juego.

---

## Test Cases

`tests/integration/paciencia/paciencia_ingresos_test.gd`
- `test_retorno_usa_el_sat_de_ayer_y_no_cambia_intradia` (AC-PS14)
- `test_sat_alto_ayer_paga_mas_hoy` (el bucle completo: 0.45 vs 0.15)
- `test_sin_paciencia_cableada_economia_sigue_con_su_default` (compatibilidad)

---

## Out of Scope

- Las reclamaciones (006) y el HUD del medidor (008).
