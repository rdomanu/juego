# Sistema de Avisos (toasts) — F3, última pieza de la interfaz moderna

**Maqueta aprobada**: `design/ux/maquetas-menu-2026-08/maqueta_avisos.png` (script hermano con el
mapeo señal→aviso decidido). **Implementación**: `src/ui/avisos_comisario.gd` (AvisosComisario,
CanvasLayer 11). **Aprobación del usuario**: 2026-08-18.

## Concepto

Pila vertical de tarjetas-toast (380 px) anclada arriba-derecha BAJO la barra del HUD (Y0=116, no
pisa los chips), que se **desplaza a la izquierda de la ficha de ventanilla** cuando está abierta
(`PanelVentanilla.borde_izquierdo()`, acoplamiento por duck-typing). Máximo 4 visibles; los demás
esperan y entran al compactarse la pila. Los toasts avisan de EVENTOS del bus; el feedback
contextual de acciones (colar un mueble, guardar…) sigue siendo `HudComisario.avisar` — son cosas
distintas y no se fusionan.

## Severidades (forma + color + texto, nunca solo color)

| Severidad | Aspecto | Vida |
|---|---|---|
| `critico` | Borde rojo, glifo triángulo de alerta, rótulo "Persistente" | NO se autodesvanece; botón × propio |
| `aviso` | Ámbar, glifo globo | Autodesvanecido con barra fina de progreso |
| `info` | Acento azul, glifo círculo-i | Autodesvanecido con barra fina |

Duraciones en `duraciones` (Dictionary editable — data-driven). Sin parpadeos (accesibilidad).

## Mapeo señal del bus → aviso (la tabla de la maqueta)

| Toast | Señales |
|---|---|
| CRÍTICO | `entro_en_deuda(saldo)`, `insolvencia`, `gracia_iniciada(min)`, `game_over` |
| AVISO | `salio_de_deuda`, `reclamacion_generada(origen)`, `parte_personal` con escaladas, `prestamo_pedido` |
| INFO | `aviso_division`, `incidencia_personal`, `parte_personal` sin escaladas |
| SIN toast | `cambio_de_turno`/`cambio_dia_noche`/`velocidad_cambiada` (el HUD ya lo enseña), `saldo_cambiado`/`tramite_completado`/`persona_generada`/`abandono` (ruido), `nivel_demanda_cambiado` (chip permanente) |

⚠️ `reclamacion_generada` está conectada pero HOY nadie la emite (cero emisores): sonará cuando
Paciencia emita — mejora inmediata nº 1 de la lista comentada con el usuario el 2026-08-18.

## Contrato

- `configurar(bus)` — se conecta él solo a las señales del mapeo (ADR-0001: solo escucha).
- `avisar_evento(severidad, titulo, detalle)` — API pública para avisos manuales/sondas/tests.
- Dinero con `formato_euros`; textos con los datos reales de cada señal.
- Tests: `avisos_comisario_test.gd` (18) + `avisos_comisario_bus_test.gd` (21) — partidos por el
  límite de ~16 KB del escáner de GdUnit4. Sonda: `tools/_diag_avisos.{gd,tscn}` (3 severidades +
  ficha abierta para la convivencia).
- Gotcha cazado aquí: el rótulo "Persistente" con el helper de etiqueta genérico (autowrap)
  salía partido en vertical en la columna estrecha → Label sin envoltura.
