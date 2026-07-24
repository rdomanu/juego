# Evidencia UI — El solar visible + modo construcción (stories const-006 y const-007) 🎉 HITO VISIBLE

> **Stories**: production/epics/construccion/story-006-solar-visible-montaje-inicial.md +
> story-007-modo-construccion-raton.md
> **Tipo**: UI (ADVISORY) — requiere sign-off del usuario (conjunto para 006+007)
> **Fecha**: 2026-07-24
> **Captura**: `construccion-hud-2026-07-24.png` (automática a los 2 s, solo dev)

## Qué se verifica

**const-006 — el solar visible:**
1. Salas pintadas sobre el suelo (TileMapLayer propio): oficina Doc azul + espera Doc apagada +
   oficina ODAC naranja + espera ODAC apagada, cada una con su **nombre** (texto además del color).
2. Ventanillas (cajas oscuras con el nombre del tipo) y asientos como **escenas** (`PackedScene` +
   `map_to_local` — nunca tiles con lógica).
3. **Montaje inicial DE OFICIO** (decisión ratificada): construido por la API real con coste 0 —
   saldo 3000 € y nómina 190 € INTACTOS; ids compat `doc_1`/`doc_2`/`odac_1`; los agentes reciben
   sus puestos por el puente `registrar_puesto` (el registro a mano de Main quedó retirado).
4. **Main reordenado**: Construcción ANTES que Personal (orden de hijos = orden de carga del
   SaveManager — invariante de personal-006/const-005).

**const-007 — modo construcción con ratón:**
1. **B** (o el botón "🔨 Construir") entra/sale del modo; el mundo se atenúa; barra inferior con
   los tipos LEÍDOS del catálogo (salas, puestos con coste, asiento, demoler).
2. **Preview fantasma** que sigue al cursor celda a celda: verde/rojo según F6 EN VIVO + texto
   ("Válido · 500 €" / "No válido" / "Sin caja") — respaldo daltónico.
3. **Dibujar sala arrastrando** con área y coste en vivo (F1); soltar construye si es válido.
4. **Clic coloca y COBRA** (gate E4 — saldo visible en el HUD); **demoler** reembolsa; demoler una
   sala con contenido pide **confirmación de cascada** (nº de elementos + reembolso total).

## Verificación manual (guion)

> **Feedback del usuario en la 1ª pasada (2026-07-24) — CORREGIDO antes del sign-off:**
> (a) la barra de construcción no se veía al pulsar B (bug de anclas: anclada abajo crecía HACIA
> ABAJO, fuera de pantalla → `grow_vertical = GROW_DIRECTION_BEGIN`); (b) el panel de info tapaba
> la comisaría → **HUD rediseñado a barra inferior estilo tycoon** (petición del usuario): fila de
> secciones reloj · velocidad · finanzas · demanda · personal abajo del todo, la barra de
> construcción se apoya encima, y el suelo sube a y=24 (mundo despejado).
>
> **Feedback de la 2ª pasada (2026-07-24) — CORREGIDO:** (c) el fantasma del puesto apenas se veía
> sobre la sala coloreada (quedaba bajo el atenuador) → preview movido POR ENCIMA del atenuador con
> borde grueso casi opaco + relleno translúcido + texto con contorno; (d) **ENMIENDA de diseño a
> la 007 (petición del usuario):** dibujar pegado/solapado a una sala del MISMO tipo ahora la
> **AMPLÍA** (misma sala, unión rectangular exacta, cobra SOLO las celdas nuevas sin re-pagar la
> base; el preview lo anuncia "AMPLIAR sala · +N celdas") en vez de crear una sala separada; un
> dibujo en "L" o de otro tipo sigue creando sala aparte (CO3: salas rectangulares). Cubierto por
> 2 tests nuevos (suite 297/297, exit 0).
>
> **Feedback de la 3ª pasada (2026-07-24) — CORREGIDO:** (e) "los bancos no se pueden construir" →
> los botones Asiento y ❌ Demoler quedaban FUERA de pantalla (la fila única de botones con los
> nombres largos del catálogo supera los 1152 px) → `HFlowContainer`: la barra de herramientas
> envuelve en varias filas y todos los botones son visibles/clicables.
>
> **Feedback de la 4ª pasada (2026-07-24) — CORREGIDO:** (f) "demoler no me deja demoler puestos o
> asientos, solo salas enteras" → los `ColorRect` de los placeholders SE TRAGABAN los clics
> (mouse_filter STOP por defecto): al pinchar SOBRE un elemento el clic nunca llegaba a la
> herramienta (solo llegaban los de celdas vacías → ruta de sala) → `MOUSE_FILTER_IGNORE` en la
> caja del placeholder (es decorativa). Gotcha registrado: todo Control decorativo del mundo debe
> ignorar el ratón.

| # | Setup | Verify | Resultado |
|---|---|---|---|
| M1 | Lanzar ventana | Solar montado y DESPEJADO: 4 salas con nombre y color, 3 ventanillas, 11 asientos; **barra de info abajo** (estilo tycoon) sin tapar nada; saldo 3000 y nómina 190 intactos | ⬜ |
| M2 | Pulsar B → elegir una ventanilla | Preview verde SOLO dentro de su oficina en celda libre; rojo con texto al solapar/salir/sin sala | ⬜ |
| M3 | Clic para colocar → mirar saldo | −500 € en el HUD; demolerla con ❌ → +250 € | ⬜ |
| M4 | Herramienta de sala → arrastrar | "N celdas · X €" en vivo; rectángulo pequeño (1×2) en rojo por área mínima | ⬜ |
| M5 | ❌ sobre una sala con contenido | Diálogo de cascada (nº elementos + reembolso); cancelar NO demuele; confirmar demuele todo | ⬜ |
| Auto | Suite completa + headless | 295/295, **Exit code: 0**; arranque headless limpio | ✅ 2026-07-24 |

## Sign-off

✅ **SIGN-OFF del usuario (2026-07-24)** tras 4 rondas de prueba-y-arreglo con la ventana abierta
(el proceso ejercitó M1-M5 de forma iterativa: solar montado, preview verde/rojo, colocar/demoler
con saldo a la vista, ampliar salas arrastrando, cascada con confirmación). Los 4 hallazgos de
feedback (barra invisible por anclas · HUD tapando el mundo → barra inferior tycoon · botones fuera
de pantalla → HFlowContainer · placeholders tragándose los clics → MOUSE_FILTER_IGNORE) quedaron
corregidos y documentados arriba ANTES del sign-off. Suite final: **297/297, exit 0**.
