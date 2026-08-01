# Ampliación de GDD — La impresora de documentos y el viaje del papel

**Estado: BORRADOR — pendiente de 3 decisiones del usuario (abajo). NO implementar hasta cerrarlas.**
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

## ❓ Las 3 decisiones pendientes del usuario

- **P1 — ¿Qué pasa si NO hay impresora (o está incomunicada)?** Opciones:
  (a) el trámite termina igual, sin viaje (la impresora es opcional, solo añade realismo y el
  aporte de comodidad); (b) el trámite se alarga un castigo fijo ("rebusca en el archivo");
  (c) ODAC/TIE no pueden atender sin impresora (dura, cambia el juego).
- **P2 — ¿Qué trámites llevan papel?** ¿Todos los de ODAC y TIE, o solo algunos (denuncia sí,
  consulta no)? ¿Documentación queda fuera porque su `impresora_dni` ya es otra cosa?
- **P3 — ¿La impresora de DNI existente se vuelve funcional igual** (viaje del papel en
  Documentación) **o se queda como comodidad de confort?**

## Acceptance Criteria (cuando se cierre el diseño)

- Test de modelo: un trámite ODAC con impresora a N celdas termina exactamente `t_viaje` después
  de lo que terminaría sin mecánica, y el ciudadano no abandona durante ESPERANDO_DOCUMENTO.
- Test de la invariante de entrada única: el viaje del papel NO dispara una segunda incorporación
  (reusar el patrón de `decidir_entrada`).
- Visual: el funcionario se ve ir y volver, y la ficha de la ventanilla lo cuenta.
