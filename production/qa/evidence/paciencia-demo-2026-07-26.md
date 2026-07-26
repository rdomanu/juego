# Evidencia — paciencia-008: SE VE EL CABREO (ánimo, medidor y la marcha)

> **Story**: production/epics/paciencia/story-008-animo-visible-demo.md (Visual/Feel — ADVISORY)
> **Fecha**: 2026-07-26 · **Suite**: 410/410, exit 0 · **Arranque headless**: limpio, exit 0
> **Estado**: ⬜ **PENDIENTE DE SIGN-OFF DEL USUARIO** (ventana abierta)

## Qué se entrega

- **Aro de ánimo sobre cada ciudadano que espera**: una barrita de color sobre la cabeza —
  🟢 contento (>66) · 🟡 impaciente (33-66) · 🔴 al límite (<33). Se oculta en cuanto lo llaman
  (su espera acabó). Refresco por DIFF: solo se toca el nodo al cambiar de tramo, nunca cada frame.
- **HUD de satisfacción** en la barra inferior: `Satisfacción: N/100 (ayer N)` — la media de HOY
  construyéndose junto al **cierre de ayer, que es el que fija el dinero de hoy** — con el color por
  los mismos umbrales que el ánimo de la gente (66/33). **La escala siempre visible** (principio U5
  del backlog de pulido).
- **Contador de reclamaciones**: `Reclamaciones hoy: N (M graves) · mes: N`. Las graves en rojo.
- Detrás, ya funcionando desde las stories 001-007: la gente se cansa, se marcha, puntúa su visita,
  la media del día se cierra al amanecer y **fija el retorno DGP del día siguiente**, y los cabreados
  generan reclamaciones que ocupan ventanilla en ODAC sin pagar nada.

## Verificación automática previa a la demo

Script temporal sobre Main REAL (90 s de juego acelerado ×30), ya borrado:

```
VERIFY-PAC: 00:00 | vigiladas=0 | sat_hoy=50.0 | quejas=0 | abandonos=0
VERIFY-PAC: 02:36 | vigiladas=1 | sat_hoy=52.0 | quejas=1 | abandonos=40
VERIFY-PAC: 05:06 | vigiladas=1 | sat_hoy=67.2 | quejas=0 | abandonos=91
VERIFY-PAC: animos observados = { contento: 933, impaciente: 1503, al_limite: 482 }
VERIFY-PAC: PASS
```

Los tres ánimos se pintan, la satisfacción se mueve con lo que pasa y las quejas se acumulan.

## Checklist de la demo (manual)

| # | Verificación | Resultado |
|---|--------------|-----------|
| M1 | Cada ciudadano esperando muestra su ánimo y se ve **cambiar** con el tiempo | ⬜ |
| M2 | Alguien **se marcha** al agotarse su paciencia, de forma legible | ⬜ |
| M3 | El HUD muestra la satisfacción de hoy junto a la de ayer, y las reclamaciones | ⬜ |
| M4 | **Se nota la diferencia**: con poca plantilla la gente se va; contratando, deja de irse | ⬜ |
| M5 | FPS ≥ 60 con la sala llena de indicadores | ⬜ |

## ⚠️ Hallazgo de BALANCE para calibrar en la demo (tarea C3-4)

En la verificación automática salieron **~90 abandonos en 5 horas de juego**, casi todos de **ODAC**
antes de que Documentación abra. Es coherente con los números del diseño, no un bug:

- ODAC atiende **24 h** y arranca con **una sola ventanilla**; Demanda genera ~36 denuncias al día.
- La paciencia semilla (`tolerancia_base_min` **30 min**) no da para tanta cola.

**Es exactamente la decisión que toca tomar contigo en la ventana.** Las palancas, de menos a más
invasiva:

1. **Subir `tolerancia_base_min`** (30 → 45/60): la gente aguanta más. Lo más simple.
2. **Dotar mejor ODAC de salida** (2ª ventanilla o 2º agente en el montaje inicial): cambia el punto
   de partida de la partida, no la regla.
3. **Bajar la demanda nocturna** de ODAC (`mult_nocturno_odac`): menos gente de madrugada.

Mi recomendación: **empezar por la 1** (es un número, no un rediseño) y ver en la ventana si el ritmo
de cabreo se siente justo. Lo que NO hay que hacer es tocar tres cosas a la vez y no saber cuál fue.

## Sign-off

- **Sign-off del usuario:** ⬜ PENDIENTE
- Valor de `tolerancia_base_min` acordado tras calibrar: ⬜ (semilla actual: 30)
