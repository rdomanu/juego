# Nota del reskin de oficio (F4): modal del Comisario + menús contextuales

**Sin maqueta propia** — el kit moderno ya estaba probado en 6 pantallas. Aprobado como parte de
la F4 (2026-08-18).

- `modal_comisario.gd`: solo ASPECTO (lógica y contrato con Economía/EventBus intactos). Velo +
  tarjeta de diálogo centrada (layer 13, por encima de todo: es la pantalla que para el juego),
  glifo de alerta, kicker "LA PARTIDA ESTÁ EN PAUSA", cita del Comisario, tres tarjetitas de
  datos (caja/inyección/avisos, `formato_euros`) y píldoras de decisión. La recolocación va en
  DOS PASADAS (`call_deferred`): el mínimo de un Label con autowrap depende del ancho YA
  repartido — medirlo en el mismo frame daba 1135 px de alto y la tarjeta salía como una columna
  cortada (cazado con sonda de medición).
- Menús del clic derecho (ciudadano y sala): estilizados sobre el PopupMenu nativo con
  `KitUIComisario.moderno_estilizar_menu_contextual` (fuente única para los dos) — tarjeta blanca
  radio 12, hover acento suave, tipografía del kit. La lógica de ítems no se tocó.
- LIMPIEZA verificada con grep: fuera el código muerto del piloto (`VARIANTE_TOAST_*`, los
  módulos 9-slice del HUD viejo y `modulo_barra_superior()`).
- Sonda: `tools/_diag_modal_comisario.{gd,tscn}` (2 fases: menú con ítems de muestra + rescate
  por la señal real `insolvencia`). Tests: `modal_comisario_test.gd` (15) + kit adaptado.
- Deuda apuntada: los ítems del menú de sala llevan emojis (📐/🧱/🪑) contra la regla del
  proyecto — se sustituyen por texto limpio en la implementación del panel de ODAC (misma zona).
