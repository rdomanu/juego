# Ampliación de GDD — La impresora de documentos y el viaje del papel

**Estado: DISEÑO CERRADO por el usuario (2026-08-01). Pendiente: (a) los números de la comodidad
(propuesta al final, falta su OK) y (b) la implementación como historia con tests.**
Propuesto por el usuario el 2026-08-01, durante la integración del mobiliario.

## Overview

Ciertos trámites terminan con un DOCUMENTO físico que hay que entregar al ciudadano (la denuncia
impresa en la ODAC, el resguardo/tarjeta en el TIE). Cerca del final del trámite, el funcionario
**se levanta, va a la impresora, coge el papel y vuelve a su mesa** para entregarlo. El trámite no
termina —y el ciudadano no puede irse— hasta que el funcionario vuelve con el papel.

## Player Fantasy

La comisaría respira: se ve a los funcionarios levantarse a por papeles, y el jugador siente que
**colocar bien la impresora importa** — una impresora lejos es cola que se acumula.

## Detailed Rules (propuesta)

1. En los puestos con trámite "con papel" (ODAC y TIE; ver P2), cuando al trámite le quedan
   **T_AVISO = 5 minutos de juego**, el funcionario inicia el viaje a la impresora de documentos
   más cercana ACCESIBLE (mismo criterio de paso que el resto de viajes: `distancia_en_celdas`).
2. El viaje es ida → coger papel (una pausa breve en la impresora) → vuelta a la mesa.
3. El trámite NO puede completarse antes de que el funcionario esté de vuelta: si el trámite
   "acabaría" y el funcionario aún no ha vuelto, el trámite queda en fase **ESPERANDO_DOCUMENTO**
   (y la paciencia del ciudadano NO drena: ya le están atendiendo — coherente con la regla actual
   de que la paciencia se para desde la llamada).
4. La duración del viaje sale del MODELO, no de los píxeles (ADR-0004): tiempo = f(distancia en
   celdas ida y vuelta + pausa de recogida). El visual solo lo interpreta (como los viajes al café).
5. Mientras el funcionario está a por el papel, su ventanilla muestra el estado (p. ej. "🖨️ a por
   el documento") — mismo patrón que el "☕ DESCANSO".

## Formulas (a calibrar en balance)

- `t_viaje = (2 × distancia_celdas / velocidad_celdas_por_min) + t_recogida`
- Tuning knobs: `T_AVISO` (5 min propuesto), `t_recogida`, velocidad (la ya existente de viajes).

## Edge Cases

- **Sin impresora construida o inaccesible**: ver decisión P1.
- Impresora demolida a mitad de viaje: el funcionario vuelve con las manos vacías y aplica P1.
- Funcionario que entra en descanso con viaje de papel pendiente: el papel manda — primero entrega,
  luego café (propuesta).
- Varias ventanillas compartiendo una impresora: sin cola en el MVP (la impresora es infinita);
  si algún día hay cola, es otra ampliación.

## Dependencies

- Comodidad NUEVA "impresora de documentos" (visual ya elegido: OBJ_008 entero, ver
  `design/art/mapa-integracion-mobiliario.md`). Requiere diseñar coste/mantenimiento/aporte.
- Flujo (fase nueva del trámite), Personal (estado del funcionario), NPCsFlujo (el viaje visual,
  mismo sistema que los viajes al café), Construcción (`distancia_en_celdas`).

## ✅ Decisiones del usuario (2026-08-01) — diseño cerrado

- **P1 resuelta con una regla mejor: OBJETOS OBLIGATORIOS POR SALA.** No existe el caso "sala sin
  impresora": construir una sala nueva exige un mínimo de objetos — **Documentación: 1 puesto
  (DNI o TIE) + 1 impresora de documentos · ODAC: 1 puesto + 1 impresora**. La validación es de
  Construcción, en el momento de construir. (Esto abre la mecánica general de "requisitos mínimos
  de sala", reutilizable para futuras estancias.)
- **Colocación (también en el trazado automático inicial)**: la impresora va **DETRÁS del puesto o
  a un lado, pero siempre de la mesa hacia atrás — NUNCA hacia el lado del ciudadano**. En el
  diseño inicial automático: en Documentación, detrás del puesto de TIE; en ODAC, igual.
- **Compartida**: UNA impresora sirve a VARIAS mesas (sin cola de impresora en el MVP).
- **P2 — Trámites con papel: TODAS las denuncias (ODAC) y la EXPEDICIÓN de TIE.** El resto de
  trámites (DNI, pasaporte, consultas) no hacen el viaje del papel.
- **P3 — La `impresora_dni` existente se queda como comodidad de confort** (no funcional): la
  impresora de documentos es un objeto NUEVO y distinto (visual: OBJ_008 entero).
- **Partidas guardadas antiguas / comisaría inicial**: el trazado automático inicial coloca las
  impresoras; al cargar un save sin ellas se aplica el mismo patrón idempotente que la fachada
  (se recolocan si faltan). *(Detalle de implementación, coherente con lo decidido.)*

## 🔢 Números de la comodidad — PROPUESTA (pendiente del OK del usuario)

Referencias: impresora_dni 2.200 € / 3 €/día / aporte 6,0 · dispensador 180 € / 1 €/día / 1,5.

| Campo | Propuesta | Razón |
|---|---|---|
| Coste | **600 €** | obligatoria por sala: no puede ser un lujo que castigue ampliar |
| Mantenimiento | **2 €/día** | tinta y papel; entre el dispensador y la impresora de DNI |
| Aporte (familia funcionario) | **2,0** | modesto: su valor real es FUNCIONAL (el papel), no el confort |
| Huella | 1 celda | como el resto de comodidades de suelo |

## Acceptance Criteria (cuando se cierre el diseño)

- Test de modelo: un trámite ODAC con impresora a N celdas termina exactamente `t_viaje` después
  de lo que terminaría sin mecánica, y el ciudadano no abandona durante ESPERANDO_DOCUMENTO.
- Test de la invariante de entrada única: el viaje del papel NO dispara una segunda incorporación
  (reusar el patrón de `decidir_entrada`).
- Visual: el funcionario se ve ir y volver, y la ficha de la ventanilla lo cuenta.
