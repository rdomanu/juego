# Story 005: Los muebles de la sala de descanso

> **Epic**: Bienestar #13
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~2-3 h)
> **Manifest Version**: 2026-07-22
> **Last Updated**: 2026-07-29 — feedback de la demo, implementado el mismo día

## Context

**GDD**: pendiente (el epic nace de una petición directa del usuario, 2026-07-28) · Comodidades #15
(`comodidad.gd`, ya tenía dos familias)
**Governing ADRs**: ADR-0001 (Personal posee el cansancio y decide su fórmula; Construcción solo suma
lo que hay puesto), ADR-0003 (catálogo y knobs salen del `.tres`, nunca del código)

**Engine**: Godot 4.6 | **Risk**: LOW — reutiliza el patrón de familias de Comodidades #15.

**Nota de proceso**: story redactada DESPUÉS de implementar y testear, el mismo día de la demo (regla
del proyecto: feedback de comportamiento se implementa en el momento). Petición literal del usuario,
jugando la build del 2026-07-29: *"si me sale, lo unico que no hay objetos para esa sala, sillas,
sofas, nevera, revistas.... cosas que puedan hacer descansar, agua..."*. La sala de descanso (story
003) se podía construir pero estaba vacía: nada que comprar. Esta story llena ese hueco y conecta lo
comprado con la duración del café.

**Control Manifest Rules**:
- Required: catálogo y knobs salen del `.tres`. — ADR-0003
- Required: "calidad instalada → minutos de pausa" lo decide **Personal**; Construcción solo suma. —
  ADR-0001

---

## Decisiones de diseño (cerradas 2026-07-29)

**1. Los muebles ACORTAN la pausa, no alargan el aguante posterior.** Se ofrecieron tres caminos: (a)
acortar el café, (b) aguantar más antes del siguiente, (c) mitad y mitad. Eligió (a) por ser el efecto
MÁS LEGIBLE — pagas 550 € por un sofá y VES que vuelven antes. (b) se descartó por invisible: el
jugador no puede comprobar que su compra funciona. Escala: **sin sala ×1,5 · sala pelada ×1,0 · sala
montada hasta ×0,7** (suelo). Los 30 min de la story 001 se quedan, como mucho, en 21. El suelo 0,7
existe para que la mecánica no pierda tensión: un café de 5 minutos dejaría al epic sin sentido
(Bienestar #13 nace de que la ventanilla se queda sola), y el tope asegura que la decisión siga
importando por muy montada que esté la sala.

**2. Hay AFORO: cada asiento es una plaza, quien no cabe se queda atendiendo.** Si tres necesitan café
y solo hay dos plazas, el tercero **no pierde el descanso** — sigue en su ventanilla, atendiendo, y lo
reintenta luego sin gastar una pausa de su cupo. La sala pasa a ser decisión de TAMAÑO además de
calidad.

**3. La plaza base (`plazas_descanso_base = 1`) evita que una sala recién construida bloquee a
todos** — uno de pie, apoyado en la pared. **Sin sala, no hay aforo**: la calle es infinita; el
castigo de no tener sala ya es el ×1,5, no hace falta cobrarlo dos veces.

---

## Acceptance Criteria

- [x] **AC-BI35** `[Data]` — GIVEN el catálogo THEN existe la familia `descanso` en `Comodidad` con 6
      objetos nuevos (`prensa_diaria`, `sillas_office`, `dispensador_agua`, `nevera`, `maquina_cafe`,
      `sofa_descanso`) y el catálogo pasa de 41 a **47 recursos**.
- [x] **AC-BI36** `[Data]` — GIVEN cada objeto nuevo THEN cumple la tabla: `prensa_diaria` 50 €/1
      aporte/0 plazas · `sillas_office` 90 €/1/**2 plazas** · `dispensador_agua` 180 €/1,5/0 ·
      `nevera` 320 €/2/0 · `maquina_cafe` 380 €/3/0 · `sofa_descanso` 550 €/4/**3 plazas**.
- [x] **AC-BI37** `[Integration]` — GIVEN objetos colocados THEN `Construccion.descanso_instalado()`
      suma su `aporte` y `plazas_de_descanso()` suma sus `plazas` (de todas las salas tipo `descanso`)
      — Construcción solo cuenta, no decide.
- [x] **AC-BI38** `[Unit]` — GIVEN sin sala construida THEN `Personal.mult_pausa_por_sala()` es
      `mult_pausa_sin_sala` (1,5); GIVEN sala pelada THEN 1,0; GIVEN calidad instalada THEN baja
      `k_confort_pausa` (0,03) por punto con suelo `mult_pausa_min` (0,7).
- [x] **AC-BI39** `[Unit]` — GIVEN `Personal.plazas_de_descanso()` THEN es `plazas_descanso_base` (1)
      más lo comprado; sin sala, es 0 e interpretado como "sin tope".
- [x] **AC-BI40** `[Integration]` — GIVEN la sala llena THEN `enviar_a_descansar(agente)` no lo manda,
      devuelve `0.0` y sigue `ASIGNADO` sin gastar pausa; GIVEN se libera una plaza THEN ese agente
      puede ser enviado en el siguiente intento.
- [x] **AC-BI41** `[Integration]` — GIVEN un objeto `descanso` en el menú de construcción THEN solo se
      coloca en sala de tipo `descanso` (gate por `comodidad.familia`), igual que `ciudadano`→`espera`
      y `funcionario`→`oficina`.
- [x] **AC-BI42** `[Visual]` — GIVEN el menú de la sala de descanso THEN cada objeto lista precio,
      mantenimiento y aporte (y plazas si da asiento); el título de la sala muestra plazas totales y
      el % resultante de la pausa.

---

## Implementation Notes

- **Catálogo** (`comodidad.gd`): tercera familia `descanso` en el `@export_enum` + campo `plazas: int
  = 0`. `tools/build_catalogo.gd` genera los 6 objetos; `TOTAL_ESPERADO` sube a 47.
- **Construcción** (`construccion.gd`): `descanso_instalado()`/`plazas_de_descanso()`, mismo patrón
  que `confort_de_sala`/`equipamiento_de_sala` sobre `aporte_de_sala(sala_id, "descanso")`. El gate de
  colocación gana `"descanso" → tipo_sala.tipo == "descanso"`; efecto secundario: antes `funcionario`
  cabía por descarte en cualquier sala que no fuera de espera (incluida descanso), ahora cada familia
  tiene su sitio exacto.
- **Personal** (`personal.gd`, ADR-0001, misma frontera que ya separa Paciencia de Flujo — `descanso`
  no inventó camino nuevo, `aporte_de_sala` ya era genérico): `mult_pausa_por_sala()` = sin sala
  `mult_pausa_sin_sala`; con sala, `clampf(1.0 - k_confort_pausa * descanso_instalado(),
  mult_pausa_min, 1.0)`. `plazas_de_descanso()` = `plazas_descanso_base + Construccion.plazas_de_
  descanso()` (0 sin sala). `enviar_a_descansar` comprueba `hay_sitio_para_descansar()` ANTES de mover
  al agente: sin sitio, `0.0`, sin tocar estado ni cupo. Knobs nuevos en `ConfigPersonal`:
  `k_confort_pausa` (0,03), `mult_pausa_min` (0,7), `plazas_descanso_base` (1).
- **Main** (`main.gd`): `_anadir_comodidades_al_menu` gana la rama `"descanso"` (☕) y añade plazas a
  la etiqueta cuando el objeto las tiene; `_titulo_de_sala` gana su rama para tipo `descanso`, con
  plazas totales y el % del multiplicador de pausa.

---

## Out of Scope

- Audio/juice del café (sonido, animación de sentarse) → Feedback y Juice #12.
- Coste de moral por caraduras repetidos → sin implementar, ya señalado en la story 003.
- Arte final de los muebles — sigue siendo andamio, pendiente de art bible.
- Gestión de aforo por planta/turno con varias salas — el sistema ya las suma, sin UI dedicada.

---

## QA Test Cases

`tests/integration/personal/personal_sala_descanso_test.gd` (en escritura en paralelo a esta story)

- **AC-BI35 / AC-BI36**: smoke del catálogo — 6 objetos con familia `descanso`, valores según tabla,
  conteo total 47.
- **AC-BI37**: varios objetos colocados → `descanso_instalado()`/`plazas_de_descanso()` suman lo
  puesto, y una segunda sala de tipo `descanso` se suma a la primera.
- **AC-BI38 / AC-BI39**: sin sala → 1,5 y 0 plazas (sin tope); sala pelada → 1,0 y solo la plaza base;
  calidad y muebles crecientes → descenso hasta el suelo 0,7 y plazas sumadas de sillas/sofá.
- **AC-BI40**: sala llena → el siguiente que necesita café se queda `ASIGNADO` sin gastar pausa; se
  libera una plaza → consigue su descanso en el siguiente intento.
- **AC-BI41**: colocar `descanso` en espera/oficina (rechazado) y en descanso (aceptado); cruzado con
  `ciudadano`/`funcionario`.
- **AC-BI42**: manual/visual — menú con precio, mantenimiento, aporte y plazas; título con plazas y %
  de pausa.

---

## Test Evidence

**Story Type**: Integration (con un componente Visual/UI en AC-BI42, ADVISORY).

**Logic/Integration**: [x] Passing — `tests/integration/personal/personal_sala_descanso_test.gd` cubre
AC-BI35 a AC-BI41; suite completa en verde (verificado 2026-07-29).

**Visual**: [ ] **PENDIENTE de demo y sign-off.** El usuario NO ha visto todavía los 6 objetos en el
menú: los pidió precisamente porque **no existían**, y se implementaron después de esa demo. Queda por
comprobar en ventana que el clic derecho sobre la sala de descanso los ofrece, que se colocan, y que
el título de la sala refleja las plazas y el % de duración del café.

---

## Dependencies

- Depends on: Story 001 (barra de cansancio, patrones de pausa) · Story 003 (sala de descanso,
  `mult_pausa_sin_sala`) · Comodidades #15 (`aporte_de_sala`, patrón de familias)
- Unlocks: cierre completo del epic **Bienestar #13**.
