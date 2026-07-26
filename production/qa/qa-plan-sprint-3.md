# QA Plan — Sprint 3 ("Que la espera duela: Paciencia")

> **Sprint**: production/sprints/sprint-3.md · **Modo**: LEAN (QA Lead omitido; los casos de test los
> escribe el hilo principal dentro de cada story, patrón de los sprints 1 y 2)
> **Escrito**: 2026-07-26 · **Estado del sprint al escribirlo**: epic Paciencia 8/8 cerrado

## Alcance

| Epic | Stories | Tipo dominante | Evidencia exigida |
|---|---|---|---|
| **Paciencia #10** | 8 | Logic + Integration (7) · Visual/Feel (1) | Test automático por story **BLOQUEANTE** + evidencia con sign-off en la 008 |
| Documentación #8 | pendiente | Integration | Ídem, cuando se creen sus stories |

## Reglas de test de este sprint (además de las del proyecto)

1. **El determinismo es el riesgo nº1.** Paciencia entra en el bucle de simulación: el test A-vs-B
   (partida guardada + recargada vs partida continua) se corre **en cada story**, no solo al final.
   *Resultado: pasó a la primera con abandonos y reclamaciones activos.*
2. **Nada de azar propio.** Toda tirada por `RNGService`; los tests fuerzan probabilidad 1.0 / 0.0
   para no depender de la suerte, y hay un test de "misma semilla → mismas reclamaciones".
3. **Los valores esperados se calculan a mano desde el GDD**, nunca copiando lo que devuelve la
   implementación. Si la fórmula está mal escrita, el test tiene que cazarlo.
4. **Los knobs se prueban en sus bordes**: config nula, valores fuera de rango, umbrales cruzados,
   división por cero (tolerancia 0). El juego no debe petar con un `.tres` mal puesto.
5. **Lo Visual/Feel no se automatiza** (regla del proyecto), pero antes de enseñarlo se verifica en
   headless que **el dibujo refleja el modelo** (montar Main real, leer los textos/estados que
   produce). Eso caza los errores de cableado; la "sensación" la juzga el usuario.

## Cobertura conseguida

| Story | Tests | Estado |
|---|---|---|
| pac-001 núcleo + F1 | 17 unit | ✅ |
| pac-002 tick, Pausa y abandono | 11 + 2 integración | ✅ |
| pac-003 F2 puntuación | 9 unit + 2 integración | ✅ |
| pac-004 F3 media y cierre | 10 integración | ✅ |
| pac-005 sat → dinero | 5 integración | ✅ |
| pac-006 reclamaciones | 9 integración | ✅ |
| pac-007 persistencia + A-vs-B | 5 integración | ✅ |
| pac-008 hito visible | evidencia + sign-off | ✅ |
| C3-10 aviso sin servicio capaz | 5 integración | ✅ |
| **Suite total del proyecto** | **423** | **exit 0** |

## Smoke check del sprint

- Suite completa en verde tras **cada** story (no solo al final del epic).
- **Arranque headless limpio** (`--quit-after`) tras cada cambio que toque `Main`.
- Verificación dirigida sobre Main real para todo lo visible: panel de personal, panel de
  calibración, ánimo de los ciudadanos, menú del clic derecho.

## Bugs encontrados y su regresión

| Bug | Cómo se encontró | Regresión |
|---|---|---|
| La purga borraba la barra de quien estaba siendo atendido | Test de AC-PS04 | Cubierto por ese test |
| `olvidar()` borraba el peor dato del día **antes de contarlo** | Al implementar la 004 | `test_cierre_calcula_media_y_resetea_acumulador` |
| Espía de test que mentía (lambdas capturan por valor) | Test de determinismo con resultado imposible | El propio test, ya corregido |
| El clic derecho para colar no hacía nada | Reporte del usuario → diagnóstico con evento real | `test_colar_*` (5 casos) |
| La captura de evidencia petaba sin servidor gráfico | Diagnóstico del bug "el juego se detiene" | Guarda en `Main` |

## Lo que NO se ha probado (y por qué)

- **Rendimiento con la sala llena de indicadores**: se comprobó a ojo en la demo (sin tirones) y con
  el contador de FPS del HUD; no hay test automático de rendimiento en el proyecto todavía.
- **El balance** (¿30 minutos de aguante es lo justo?): no es automatizable — se calibró con el
  usuario en ventana y quedó **con una dependencia declarada** de Comodidades #15.
