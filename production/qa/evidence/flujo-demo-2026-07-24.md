# Evidencia — flujo-008: LA COMISARÍA VIVE (NPCs navegando + demo integradora)

> **Story**: production/epics/flujo/story-008-comisaria-viva-npcs.md (Visual/Feel — ADVISORY)
> **Fecha**: 2026-07-24 · demo re-verificada y **firmada el 2026-07-25** tras 3 rondas de feedback
> **Suite**: 342/342, exit 0 · **Arranque headless**: limpio, exit 0

## Qué se entrega

- **Flujo cableado en Main** (name "Flujo", tras Demanda — orden del tick; tras Personal — orden
  de carga): `persona_generada` → admitir (turno + aforo; puerta Doc FL24) → encolar → NPC.
- **NPCs cosméticos** (CharacterBody2D + NavigationAgent2D, avoidance OFF, muñeco por servicio
  azul Doc / naranja ODAC / azul claro TIE, mouse ignorado): calle → asiento o hueco de pie en SU
  sala de espera → ventanilla al ser llamado (se detiene al borde del mostrador recortado) → calle
  y despawn. El paseo escala con la velocidad del reloj (Pausa lo congela). FL5: cosmético puro.
- **Navegación bakeada del layout real** (`NavigationServer2D.bake_from_source_geometry_data`,
  patrón del slice): suelo + 2 celdas de calle transitables; puestos como obstáculos. Re-bake
  SOLO al cambiar el layout (hook de Construcción, coalescido a 1/frame).
- **Sincronización de puestos** Construcción→Flujo en el mismo hook (altas y demoliciones).
- **HUD**: bloque "En cola: N Doc · N ODAC" + "Atendiendo: N · FPS n" (pull de getters) + puerta Doc.
- **Panel de personal** (tecla P, opera en Pausa): plantilla (asignar/desasignar/despedir) +
  mercado (contratar) + **resumen de un vistazo** (ver ronda 3).
- Hooks de la 006 cableados: `puede_demoler` (AC-CO13) y peonada → `registrar_horas_extra`.

## Checklist de la demo (manual, guion: 3× hasta las 07:55 → 1×)

| # | Verificación | Resultado |
|---|--------------|-----------|
| M1 | El ciclo entero a la vista: entran, esperan (sentados/de pie), ventanilla, salen | ✅ |
| M2 | EL SALDO SUBE con cada trámite completado | ✅ |
| M3 | Construir en vivo re-bakea sin dejar NPCs atascados | ✅ |
| M4 | FPS ≥ 60 sostenido en hora punta | ✅ sin tirones percibidos (cifra exacta no anotada) |

## Rondas de feedback con la ventana abierta (todas corregidas ANTES del sign-off)

1. **z_index / policías / rótulos / TIE / panel de personal** (2026-07-24, detalladas en `active.md`).
2. **Calibración del camino** (3 pasadas, 2026-07-25) — enmienda "EN CAMINO no se tramita": knob
   `velocidad_camino_celdas_min` **0.375** (= el paso cosmético de 90 px/s a 1×), paso **adaptativo**
   del muñeco acotado a ±50% (feedback "esprintaba"), origen ENTRADA si aún no dio tiempo a llegar
   a la sala. **Aprobado por el usuario.**
3. **Dos ciudadanos en el mismo asiento** (2026-07-25, bug real) — el hueco "de pie" se calculaba
   por turno sobre el rect de la sala, que **incluye las celdas de los bancos** → un de-pie podía
   plantarse sobre un sentado. Fix en `npcs_flujo.gd`: **una celda, una persona** (plazas reservadas
   en `_plaza_de`, huecos de pie que excluyen bancos y se reparten desde un origen por turno, purga
   de plazas fantasma). Sala a reventar (F3 admite ~1,2 pers./celda) → se comparte celda con desvío
   sub-celda determinista, nunca superposición exacta. **Verificado por el usuario.**
4. **El panel de personal no se leía de un vistazo** (2026-07-25) — añadido resumen: nómina diaria
   junto al saldo, línea "Plantilla: N (en puesto · banquillo · de baja) — Ventanillas cubiertas:
   X de Y" (verde sin vacantes / ámbar con ellas), un chip por ventanilla con **quién** la cubre o
   VACANTE, y contadores en las cabeceras PLANTILLA (N) / MERCADO (N). El chip respeta el gate FL4:
   titular **de baja** sin cobertura → gris y NO cuenta como cubierta (el panel no miente sobre lo
   que el juego hace). Verificado en headless sobre Main real. **Verificado por el usuario.**

## Sign-off

- Captura: `flujo-demo-2026-07-24.png` (auto, 2 s tras arranque)
- FPS observado: sin tirones percibidos por el usuario en hora punta (contador visible en el HUD)
- **Sign-off del usuario: ✅ CONCEDIDO (2026-07-25)** — *"vale ok todo, hay que pulir cosas de
  diseño pero parece que funciona bien"*.
- **Pendiente NO bloqueante**: el pulido visual/de diseño se recoge en UI/HUD #11 + art bible
  (todo el visual actual es andamio).
