# Estado de sesión — activo

*Última actualización: 2026-07-22*

## 🎉🎉🎉 HITO — GATE Pre-Production → **PRODUCTION** (2026-07-22)
`/gate-check pre-production→production` → **Veredicto CONCERNS → usuario decide AVANZAR con condiciones.**
El núcleo del gate está superado: **diversión validada** (slice PROCEED, jugado sin guía) + **riesgo técnico nº1
despejado** (150 NPCs → ~145 FPS) + cimientos firmes (12/12 GDD, 4 ADR `Accepted`, arquitectura, control-manifest,
tests+CI, consistencia sin conflictos abiertos). Panel de directores (lentes manuales, LEAN): **CD READY · TD READY ·
PR CONCERNS · AD CONCERNS.** Chain-of-Verification: 5 preguntas, veredicto sin cambios.
**Etapa avanzada a `Production`** (`production/stage.txt`). Informe:
`production/gate-checks/gate-2026-07-22-pre-production-to-production.md`.
**⚠️ 4 CONDICIONES registradas (resolver a su debido tiempo; NINGUNA bloquea el código de cimientos):**
(1) **Backlog** — `/create-epics` (foundation+core) → `/create-stories [epic]` → `/sprint-plan` *(inmediato)*;
(2) **Art bible 5–9 + sign-off AD-ART-BIBLE** — antes de la 1ª historia de arte/assets;
(3) **UX de pantallas clave** (`design/ux/hud.md` + menú principal + pausa) + `/ux-review` — antes de las historias de UI;
(4) **Inventario de entidades** (`design/assets/entity-inventory.md`, `/asset-spec`) — antes de producir arte (recomendado).
**✅ `/create-epics` Foundation + Core HECHO** (2026-07-22): **10 epics MVP** escritos en `production/epics/`
+ `production/epics/index.md`. **Foundation (5):** tiempo, datos, event-bus, save-manager, rng-service
(2 con GDD + 3 infra). **Core (5):** economia, flujo, demanda, personal, construccion. Uno por módulo de
arquitectura. Trazabilidad 100% (~37 TR, 0 huérfanos). Usuario eligió infra separada (no fundir). PR-EPIC
omitido (LEAN). Nota: Flujo = módulo más delicado (nav 2D + rendimiento) pero MITIGADO por spike QQ-02.
**Faltan capas Feature (Doc/ODAC/Paciencia) + Presentation (UI/Feedback)** → `/create-epics layer: feature`
/`presentation` cuando se aproximen.
**✅ `/create-stories event-bus` HECHO** (2026-07-22): 2 historias en `production/epics/event-bus/`
(story-001 autoload+señales de aviso [Integration, TR-bus-001]; story-002 dispatcher ordenado por prioridad
[Logic, TR-bus-002]). Cada una con ADR-0001, reglas del manifiesto, criterios de aceptación y **casos de
test escritos por el hilo principal** (QA Lead omitido LEAN; sin qa-plan previo). EPIC.md + índice
actualizados. 002 depende de 001; ninguna bloqueada (ADR-0001 Accepted).
**🎉 PRIMER CÓDIGO DE PRODUCCIÓN — Story 001 (event-bus) IMPLEMENTADA + TEST EN VERDE (2026-07-22):**
- **`project.godot` de Producción creado** en la RAÍZ del repo (res://=raíz; renderer Compatibility;
  autoload `EventBus` el primero; `config_version=5`). Escrito DESDE CERO (el del prototipo NO se toca).
- **`src/foundation/event_bus/event_bus.gd`** — Story 001 (TR-bus-001): autoload + 9 señales de aviso
  tipadas y documentadas; cero lógica de juego. Verificado headless (`VERIFY-EVENTBUS: PASS`).
- **GdUnit4 INSTALADO por Claude (línea de comandos)** en `addons/gdUnit4/` (repo oficial
  `godot-gdunit-labs/gdUnit4`, compat. 4.6). **Gitignored** (`/addons/gdUnit4/`, `/reports/`): lo instala la
  CI (gdUnit4-action) y en local aparte. `.godot/` generado (import OK).
- **Test permanente `tests/integration/event_bus/event_bus_signals_test.gd` → 3/3 PASS** (GdUnit4 headless).
  **Comando canónico verificado:** `godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:6007
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/integration --ignoreHeadlessMode` (0=OK/100=fallos/
  101=warn/103=abort; `--ignoreHeadlessMode` obligatorio; puerto 0 NO vale en 4.6).
- **⚠️ Follow-up menor (no bloquea):** `tests/gdunit4_runner.gd` (ruta `addons/gdunit4/GdUnitRunner.gd`
  inexistente) y la action de CI (`MikeSchulze/gdUnit4-action` → repo movido a `godot-gdunit-labs`) hay que
  alinearlos al comando real de arriba. La CLI de GdUnit4 (`GdUnitCmdTool.gd`) es un MainLoop → el runner
  custom vía `--script` no aplica.
- **Aprendizaje GDScript (registrado):** las lambdas capturan locales **por valor** → para contar en un
  test usar un `Array` (por referencia), no un `int`.
**✅ Story 002 (event-bus) IMPLEMENTADA + TEST EN VERDE (2026-07-22):** dispatcher de eventos ordenados
(`registrar_ordenado`/`disparar_ordenado`) añadido a `event_bus.gd` — orden por prioridad ascendente
(10/20/30/40), desempate estable por orden de registro, notificación tras el orden crítico, guarda
`is_valid()`. Test `tests/unit/event_bus/event_bus_orden_test.gd` **5/5 PASS**. **Suite EventBus completa:
10/10** (001: 3, 002: 5, sanity: 2), exit 0. **🎉 EPIC EVENT-BUS COMPLETO en código+test** (falta cierre
formal `/story-done` de ambas + commit de la 002).
**✅ Story 002 COMMITEADA** (commit `4e06e00`, pusheada). Epic EventBus completo y guardado en GitHub.
**✅ `/create-stories rng-service` HECHO** (2026-07-22): 3 historias en `production/epics/rng-service/`
(story-001 autoload+sembrado [Logic]; story-002 elección ponderada [Logic]; story-003 serialización del RNG
[Integration, TR-save-002]). ADR-0002; casos de test escritos por el hilo principal. EPIC+índice
actualizados. 002/003 dependen de 001; ninguna bloqueada.
**✅ RNGService Story 001 IMPLEMENTADA + TEST EN VERDE (2026-07-22):** `src/foundation/rng_service/
rng_service.gd` (autoload `RNGService`, 2º tras EventBus, registrado en `project.godot`; `sembrar`/
`randi_rango`/`randf`). Test `tests/unit/rng_service/rng_service_sembrado_test.gd` **4/4 PASS**. **Suite total
del proyecto: 14/14** (event_bus 8, rng 4, sanity 2), exit 0. SIN commitear todavía.
**✅ RNGService Story 001 COMMITEADA** (commit `fb693fe`, pusheada).
**✅ RNGService Story 002 IMPLEMENTADA + TEST EN VERDE (2026-07-22):** `elegir_ponderado` (proporcional a
pesos, normalización defensiva, edge -1). Test `rng_service_ponderada_test.gd` **5/5 PASS**. **Suite total:
19/19**, exit 0. SIN commitear todavía.
**🐛 BUG CAPTURADO POR EL TEST (lección importante, registrada):** dentro de `elegir_ponderado`, `randf()`
sin cualificar resolvía a la **función GLOBAL de Godot** (`@GlobalScope.randf()`, RNG global sin sembrar)
en vez del método sembrado del autoload → rompía el determinismo (a≠b). Arreglado con `self.randf()`.
**Footgun general: nombrar métodos del autoload igual que utilidades globales (`randf`/`randi`) → cualificar
SIEMPRE las llamadas internas con `self.`** (aplicar en futuros servicios). Diagnosticado con un script
standalone (`tests/verify_event_bus_tmp_diag.gd`, gitignored).
**✅ RNGService Story 002 COMMITEADA** (commit `0d280f2`).
**✅ RNGService Story 003 IMPLEMENTADA + TEST EN VERDE (2026-07-22):** `save()`/`load_state()` + grupo
`Persist`. **Decisión: semilla/estado como String** (no int) para preservar el int64 en el round-trip por
JSON (float pierde precisión > 2^53). Test `rng_service_serializacion_test.gd` **4/4 PASS** (incl. round-trip
vía JSON). SIN commitear todavía.
**🎉 EPIC RNGService COMPLETO** en código+test (3/3 stories: 001 sembrado, 002 ponderada, 003 serialización).
**Suite total: 23/23**, exit 0. **2 de 5 módulos Foundation completos** (EventBus + RNGService).
**✅ RNGService Story 003 COMMITEADA** (commit `c75472c`). Epic RNGService completo en GitHub.
**✅ `/create-stories datos` HECHO** (2026-07-22): 4 historias en `production/epics/datos/` (001 esquema
[Logic]; 002 autoload carga+lookup [Integration]; 003 validación [Logic]; 004 catálogo Pozuelo [Config/Data]).
ADR-0003; casos de test escritos por el hilo principal. EPIC+índice actualizados. Orden 001→002→003→004.
**⚠️ Reto de implementación anotado (story 004):** crear los `.tres` a mano es frágil (uids/ext_resource) →
**generar el catálogo con un script-herramienta `tools/build_catalogo.gd`** (`extends SceneTree` +
`ResourceSaver.save`) ejecutado en headless. Dev tooling en `tools/`, no runtime.
**✅ SUBAGENTES FUNCIONAN DE NUEVO (2026-07-22, sesión Fable 5):** probado con agente trivial — el error
"Usage credits required for 1M context" ya NO ocurre. **Modo de trabajo aprobado por el usuario: HÍBRIDO** —
historias en serie (dependen unas de otras); dentro de cada una, especialista (Opus 4.8) implementa y
Fable 5 (hilo principal) supervisa, revisa el código y re-ejecuta los tests; verificaciones QA read-only
en paralelo. Cuando toque tier Sonnet → Sonnet 5 (nunca 4.6); ante la duda del alias, usar Opus.
**✅ Datos Story 001 IMPLEMENTADA + CERRADA (2026-07-22, vía godot-gdscript-specialist Opus + revisión del
hilo principal):** 8 clases en `src/foundation/datos/esquema/` (atencion, tramite_doc, denuncia_odac,
tipo_puesto, tipo_sala, tipo_agente, costes, escenario) — solo `class_name`+`@export` tipados, refs por id
(`Array[StringName]`), cero lógica. Test `tests/unit/datos/datos_esquema_test.gd` **9/9 PASS**. **Suite
total: 32/32, exit 0** (re-verificada de forma independiente en el hilo principal). Revisión: corregido doc
comment `retorno_dgp_min/max` ("euros"→fracción [0,1]).
**🆕 GOTCHA NUEVO (aplicar en el futuro):** en headless "en frío", `extends Atencion` (por `class_name`) en
una clase hija preload-ada FALLA ("Could not resolve script") → heredar por **ruta literal**
(`extends "res://src/.../atencion.gd"`). Aplicado en tramite_doc.gd/denuncia_odac.gd, documentado en código.
**Decisiones impl. 001:** `Costes` lleva `id` extra (indexado uniforme en Story 002);
`Escenario.tope_construible` = `Dictionary[StringName, int]` tipado (OK 4.6); `.gd.uid` no se materializan
en headless (tampoco los previos; se generarán al abrir el editor — no bloquea).
**✅ CIERRE FORMAL de 6 stories (2026-07-22, aprobado por usuario):** EventBus 001/002 + RNGService
001/002/003 (verificación QA por 2 agentes read-only Opus: TODOS los AC CUMPLIDOS con evidencia
archivo:línea, 0 desviaciones ADR/manifest) + Datos 001. Stories→Complete; EPICs event-bus y
rng-service→**Complete**; índice actualizado (Datos = In Progress 1/4). Sugerencia QA no bloqueante a
backlog: 2 asserts extra de edge cases en `event_bus_signals_test` (desconexión de oyente; emisión repetida).
**✅ Datos Story 002 IMPLEMENTADA + CERRADA + COMMITEADA (2026-07-22, commit 86b8ce8; especialista Opus +
supervisión por muestreo del hilo principal):** autoload `Datos` (3º en project.godot) — carga res://datos/
con DirAccess+load, indexa {tipo->{id->Resource}} (hijas ANTES que la base, preload por ruta),
obtener()/obtener_todos() read-only (null+push_warning si falta). **Catálogo REAL generado: 29 .tres**
(tools/build_catalogo.gd, valores F1–F7; SIN `reclamacion` — modelado pendiente en la 004: ¿14ª denuncia o
atención aparte? los tests esperan 13). Test integración **6/6**; **suite 38/38, exit 0** (re-verificada
independiente en hilo principal). AC-D02 cumplido por construcción (valores solo en .tres). Acepta
`.tres.remap` (export).
**✅ Datos Story 003 IMPLEMENTADA + CERRADA + COMMITEADA (2026-07-22, commit 143b2ca):** `validar()` en
datos.gd — integridad referencial (nombra id colgante; dev no oculta / jugador descarta), duplicados en
`_indexar` (gana el 1º), clamps con aviso, R5 WARNING sin abortar (solo con `demanda_max_odac>0`;
MINUTOS_OPERATIVOS=960, media simple de denuncias), servicio activo sin puesto. Única mutación del
catálogo = clamps/descartes EN CARGA (documentado). Test 9/9 (incl. rama dev y R5 negativo, añadidos tras
el review). **Code review independiente (Opus): APROBADO, 0 bloqueantes** (backlog menor anotado en el
cierre de la story). **Suite 47/47, exit 0.** Catálogo real valida limpio.
**📌 DECISIÓN DE DISEÑO (usuario, 2026-07-22): `reclamacion` = 14ª DenunciaODAC** (Normal, sin tarifa,
puesto_odac la admite; la demanda ciudadana NO la genera — la generará Paciencia PS13). Los AC/tests del
"13" pasan a "13 ciudadanas + 1 interna = 14". Opciones B (ficha base aparte) y C (diferir) descartadas.
**🎉🎉 EPIC DATOS COMPLETO (2026-07-22, 4/4 stories; commits 1ec959c/86b8ce8/143b2ca/c6d46e0):**
Story 004 cerrada — `reclamacion` añadida como 14ª DenunciaODAC (ENMIENDA de AC aprobada: "13" → 13
ciudadanas + 1 interna), catálogo regenerado a **30 .tres**, smoke `datos_catalogo_pozuelo_test.gd`
(validar()==[] + spot-checks F1/F2/F4/F7). **Suite 53/53, exit 0.** **3 de 5 módulos Foundation
COMPLETOS Y CERRADOS: EventBus, RNGService, Datos.**
**📌 DECISIÓN usuario (2026-07-22): "ESQUELETO VISIBLE" tras el módulo Tiempo** — al terminar Tiempo,
crear la escena principal mínima (Main.tscn: suelo TileMapLayer + HUD del reloj) y ABRIRLE LA VENTANA
al usuario (primera visual del juego de producción; no jugable aún). Es la escena que Construcción
necesitará igualmente.
**✅ Epic tiempo EN MARCHA:** 9 stories aprobadas y escritas (commit f3fd3b4; decisiones: ConfigTiempo
.tres propio · `velocidad_cambiada(indice:int)` se añadirá al EventBus en la 006 · T33 advisory).
**Stories 001-005 IMPLEMENTADAS + CERRADAS** (commits 67c118b / 8f47e31 / [004-005 commit 2026-07-23]):
acumulador `avanzar(delta)` puro con clamp anti-salto (fposmod 1440) · ConfigTiempo data-driven
(datos/config/tiempo.tres vía tools/build_config_tiempo.gd; clamp escala [3,12]) · conversiones puras +
enum Turno (derivados, nunca almacenados) · **cruces de umbral → señales del bus** (1 emisión por cruce,
orden turno→día/noche, guardas anti-jitter, bus INYECTABLE con `usar_bus()` para aislar tests) ·
**calendario semanal** (semana/mes/año; 48 jornadas=1 año; `nuevo_dia`/`nuevo_mes` SIEMPRE vía
`disparar_ordenado`; orden completo turno→día/noche→nuevo_dia testeado).
**Suite 90/90, exit 0.** Gotchas nuevos: tipos por class_name en firmas fallan en frío → `Resource` +
preload por ruta; `_procesar_cruces(minutos_antes)` se llama TRAS `avanzar()` (el enganche automático es
la 007); `sincronizar_umbrales()` evita cruces espurios al arrancar/cargar (lo usará la 008).
**⚠️ Incidencias de agentes (2026-07-22/23):** límite de sesión + 2 atascos de stream + 1 proceso caído a
mitad de la 004-005 → el hilo principal (Fable) rescató el parcial (117 líneas buenas) y escribió los
tests. Si los agentes vuelven a fallar seguido: hacer en hilo principal directamente.
**✅ Stories 006-008 IMPLEMENTADAS + CERRADAS (2026-07-23, commit d54246e):** máquina de velocidad
{PAUSA,X1,X2,X3} directa (mult derivado; reanudar→última velocidad; `velocidad_cambiada(indice:int)`
AÑADIDA al EventBus) · `_physics_process` = avanzar+_procesar_cruces + hook del tick sin nombres + T33
advisory · save()={minutos_juego,semana,mes,anio}, load_state→PAUSA+sincronizar_umbrales+0 eventos,
grupo Persist. **Suite 107/107, exit 0.** El agente agotó el turno antes del último test → rematado en
hilo principal. **🐛 ERRATA del GDD cazada por el test:** AC-T26 empareja "14:30" con turno "Tarde", pero
14:30 es MAÑANA según la tabla de turnos del propio GDD (mezcla el horario laboral de Documentación con
el turno del reloj) → test con 15:30; backlog: corregir el ejemplo en time-system.md.
**🎉🎉🎉 EPIC TIEMPO COMPLETO (2026-07-23, 9/9) + PRIMERA VENTANA DEL JUEGO ABIERTA Y FIRMADA:** Story
009 implementada en HILO PRINCIPAL (commit 3282e06; escena/HUD por código como el prototipo): Main.tscn
main scene, suelo TileMapLayer 24×13 (TileSet generado por código), HUD provisional (hora/fecha/turno,
botones Pausa-1×-2×-3× con focus_mode NONE, atajos Espacio/1/2/3, resaltado vía velocidad_cambiada),
captura de evidencia automática a los 2 s (solo dev). Headless limpio. **VENTANA ABIERTA AL USUARIO →
SIGN-OFF ✅ (2026-07-23)**; evidencia `production/qa/evidence/tiempo-esqueleto-2026-07-23.md` + PNG.
**4 de 5 módulos Foundation COMPLETOS Y CERRADOS: EventBus, RNGService, Datos, Tiempo.**
**🎉🎉🎉 EPIC SAVE-MANAGER COMPLETO (2026-07-23, 7/7) → FOUNDATION 5/5 COMPLETA:** troceo aprobado y 7
stories escritas (commit 22c9541; decisiones: API sin slots `guardar_partida`/`cargar_partida(ruta)` con
ADR-0002 alineado; clave por sistema = `node.name` del grupo Persist; version desconocida → rechazar).
Implementación en 3 bloques (commits 821d33a / c7e8ddb / [006-007]): SerialUtil estático
(vec2i↔{x,y}, int() por floats de JSON) · recolección `_recolectar_de` con nodos-espía · escritura segura
temp+rename (HALLAZGO Windows: `rename_absolute` NO sobrescribe → borrar destino solo con .tmp válido;
rutas con `ProjectSettings.globalize_path` — DirAccess no traga user:// a pelo) · lectura + `_migrar`
(v1 identidad; mayor → rechaza) · distribución tolerante (clave ausente → defaults+warning, 0 eventos) ·
round-trip END-TO-END por disco real (RNG determinista a través del JSON; reloj idéntico + Pausa) ·
autoload 5º registrado + smoke standalone `tests/smoke_save_manager.gd` (SMOKE_OK guardar/cargar true) +
smoke doc `production/qa/smoke-2026-07-23.md`. **Suite 135/135, exit 0.**
**🏗️ HITO: LOS 5 MÓDULOS FOUNDATION COMPLETOS Y CERRADOS (EventBus, RNGService, Datos, Tiempo,
SaveManager) + esqueleto visible firmado.** El "ERROR Parse JSON ... got 'esto'" de la salida de la suite
es un caso de test intencionado (save corrupto → fallo controlado).
**✅ SPRINT 1 ABIERTO (2026-07-23, commits 8bfda34/112768f/4b3730a):** `/sprint-plan` hecho —
production/sprints/sprint-1.md + sprint-status.yaml + review-mode.txt=lean. Must Have = epic Economía;
Should = Demanda; Nice = stories de Personal. **QA plan del sprint escrito** (qa-plan-sprint-1.md, lean:
6 Logic BLOCKING + 1 Visual ADVISORY).
**⚠️ SUBAGENTES CAÍDOS OTRA VEZ** ("Usage credits required for 1M context", como la sesión original) →
TODO en hilo principal (regla fija). El usuario puede reactivarlos con /usage-credits.
**✅ C1-1: 7 stories de Economía ESCRITAS y aprobadas** (hilo principal). Decisiones: Economía = NODO del
mundo (arquitectura §3.4, no autoload); ConfigEconomia .tres (9 knobs); enmienda bus `saldo_cambiado`
int→float + 6 señales nuevas previstas (prestamo_pedido, entro/salio_de_deuda, insolvencia,
gracia_iniciada, game_over); interfaces provisionales (sat_cierre=50 fija + fijar_sat_cierre; plantilla
inyectable fijar_plantilla; registrar_horas_extra; modal rescate = señales + aceptar/rechazar_rescate).
**✅ eco-001 IMPLEMENTADA (commit d877995):** src/core/economia/economia.gd (nodo, gates E4, usar_bus) +
config_economia.gd + tools/build_config_economia.gd → datos/config/economia.tres + enmienda del bus
aplicada (señal float + test alineado). Tests 6/6. **Suite 141/141, exit 0.**
**🎉🎉🎉 EPIC ECONOMÍA COMPLETO (2026-07-23, 7/7 + sign-off) — PRIMER MÓDULO CORE TERMINADO:** las 7
stories implementadas EN HILO PRINCIPAL en un día (commits d877995 → 088d6f2): núcleo+config+gates ·
ingresos DGP (cache de tarifas anti-warnings; sat provisional 50) · cierre diario determinista (recargo
apertura→gastos→reset, prio 20) · préstamos (strikes históricos + penalización híbrida) · insolvencia
(estados derivados, pausa REAL del reloj, gracia 720 min de juego cableada al tick, rescate auto, game
over) · balance mensual (prio 10) + save/load Persist (11 claves) · **SALDO EN HUD con sign-off del
usuario** (3000 € verde/ámbar/rojo + texto; nómina −190 €/medianoche a la vista; evidencia
economia-saldo-hud-2026-07-23.md + PNG). **Suite 173/173, exit 0.** Bus ampliado documentado:
saldo_cambiado float + prestamo_pedido, entro/salio_de_deuda, insolvencia, gracia_iniciada, game_over.
Sprint 1: C1-1/C1-2/C1-3 + eco-001..007 = done en sprint-status.yaml.
**✅ `/create-stories demanda` HECHO (2026-07-23, aprobado por el usuario tras explicación en llano):**
7 historias en `production/epics/demanda/` (001 núcleo+config+volumen · 002 generador determinista ·
003 tick+ventana+bus [Integration] · 004 nivel BAJA/MEDIA/ALTA [enmienda bus `nivel_demanda_cambiado`] ·
005 estacionalidad+eventos · 006 persistencia [Integration] · 007 HUD llegadas+nivel [UI, HITO VISIBLE]).
19/19 AC del GDD + **AC-DM20 nuevo** (proporcionalidad de `poblacion` — petición del usuario: población
variable por escenario, tasas ajustables por config sin tocar código; verificado que `Escenario.poblacion`
ya existe en el esquema). Decisiones del usuario: ficha Persona = **RefCounted tipada** (servicio,
tramite_id, minuto_llegada; Flujo la envolverá); HUD = contador llegadas + nivel (expectativa ajustada:
el saldo NO sube hasta Flujo/C1-6, Demanda solo hace llegar gente). Verificado: `persona_generada` ya está
en el bus (event_bus.gd:24) — sin `tramite_solicitado`. **⚠️ 2 erratas del GDD anotadas en story-001**
(tasa_base_odac 0.4 [F1/AC] vs 0.5 [tabla Tuning]; "≈10 nocturnas" vs ≈5.25 derivado de 36×7/24×0.5) —
propagar al GDD cuando se toque. EPIC.md + index.md actualizados. SIN commit (las 7 stories + código 001 se commitean cuando el usuario diga).
**✅ demanda-001 IMPLEMENTADA + TEST EN VERDE (2026-07-23, hilo principal — subagentes caídos de la sesión
anterior, sin reintentar):** `src/core/demanda/demanda.gd` (nodo `class_name Demanda`, F1/F2 puras:
tasa_efectiva/demanda_dia/llegadas_esperadas_hora/densidad_por_minuto con ventana Doc 480-870, valle ODAC
horas 0-6 × mult, franja 14 = 30 min; poblacion SIEMPRE del Escenario vía `fijar_escenario`/inyectable
`fijar_poblacion`; aplicar_config con clamps patrón Economía) + `config_demanda.gd` (ConfigDemanda: 16
knobs incl. mezclas F3, umbrales DG12, mult_estacional DG13 y eventos DG11 para stories 002-005; perfil
ODAC uniforme rellenado en _init) + `tools/build_config_demanda.gd` → `datos/config/demanda.tres`
(generado OK; Godot solo persiste lo ≠ default — normal). Test `demanda_volumen_test.gd` **17/17 PASS**
a la primera (AC-DM01..04, 12, 13, 19 + AC-DM20 proporcionalidad poblacion 30k/180k + mezclas vs catálogo
real + .tres real). **Suite total: 190/190, exit 0.** Nota: valle nocturno testeado al valor DERIVADO
5.25 (no el "≈10" del GDD — errata anotada en la story).
**✅ demanda-002 IMPLEMENTADA + TEST EN VERDE (2026-07-23):** `persona.gd` (class_name Persona,
RefCounted: servicio/tramite_id/minuto_llegada, cero lógica) + generador F4 en demanda.gd:
`procesar_avance(delta_min, min_dia) -> Array[RefCounted]` (acumuladores Dictionary por servicio,
residuo conservado, tope de ráfaga GLOBAL por tick, orden fijo Doc→ODAC, aviso anti-no-drena con
guarda), `_elegir_tramite` vía RNGService.elegir_ponderado sobre arrays PARALELOS ids/pesos (orden de
inserción del config = estable/determinista; `acumulador_de()` read-only). Test
`demanda_generador_test.gd` **7/7** (DM06 determinismo secuencia completa, DM07 tope+excedente, DM08
proporciones 2100 draws ±0.05, DM17 [2,1,1] end-to-end, ficha válida, tope global, delta 0).
**Lección tipado:** un literal Dictionary SIN tipo no se asigna a una propiedad `Dictionary[K,V]` vía
referencia `Resource` → declarar el literal tipado primero. **Suite: 197/197, exit 0.**
**🎉🎉🎉 EPIC DEMANDA COMPLETO (2026-07-24, 7/7 + sign-off) — SEGUNDO MÓDULO CORE TERMINADO:**
commit a1df0fc (stories 001-003) + cierre final. Stories 004-007 en hilo principal:
- **004 nivel BAJA/MEDIA/ALTA**: enmienda del bus `nivel_demanda_cambiado(nivel)` aplicada;
  clasificar_nivel puro (bordes: <bajo BAJA, ≥alto ALTA); señal solo al cambiar; getter pull. 6/6.
- **005 estacionalidad+eventos**: mult_estacional[mes] solo Doc (nuevo_mes prio 30, espías 29/31);
  eventos por calendario (vacaciones jun/dic, 3 jornadas, mult_peso pasaporte×2/permiso_viaje×3);
  pesos efectivos recalculados solo al activar/expirar (cero alloc en tick). 7/7.
- **006 persistencia**: save 6 claves / load defensivo sin señales; round-trip JSON real; test
  determinismo guardar-a-mitad → secuencia futura idéntica. **2 HALLAZGOS APLICADOS:** (a) mult
  estacional se deriva del mes TAMBIÉN en _ready (coherencia arranque/carga — la partida EMPIEZA en
  enero ×0.6 = nivel BAJA, ~27/día); (b) **SaveManager.guardar_partida → full_precision=true** (los
  floats perdían decimales en JSON.stringify → rompía el determinismo exacto de ADR-0002). 5/5.
- **007 HUD (VISIBLE, FIRMADO 2026-07-24 opción A)**: Demanda instanciada en Main (name "Demanda";
  Flujo/Paciencia deberán instanciarse DESPUÉS — orden del tick); HUD: "Llegadas hoy: N" +
  "Demanda Doc: NIVEL" (verde/ámbar/rojo + texto). Evidencia demanda-hud-2026-07-23.md + PNG.
  **Aprendizaje de demo:** el reloj arranca a las 00:00 → 1ª sesión el usuario solo vio el goteo
  nocturno (1 persona — correcto pero mala demo); guion bueno = 3× hasta las 07:55 y ver la apertura.
  **Expectativa del usuario registrada:** quiere VER gente entrar → eso es FLUJO (rechazó el +1
  flotante provisional). Idea apuntada: hora de arranque ~07:55 (tuning Tiempo futuro).
**Suite final: 220/220, exit 0.** Sprint: C1-4 + dem-001..007 = done. Epic + índice → Complete.
**✅ C1-5 `/create-stories personal` HECHO (2026-07-24, aprobado por el usuario — SOLO escritura, la
implementación es Sprint 2):** 7 historias en `production/epics/personal/` (001 Agente+fórmulas F1-F4 ·
002 mercado sembrado con sesgo al centro · 003 asignación+gate FL4 [puestos ABSTRACTOS registrables —
Construcción los hará reales con la misma API] · 004 ausencias nuevo_dia prio 30 [nómina prio 20 cobra
ANTES → baja pagada] · 005 Oficial F6/F7 [cubre floor(Mando/2), solo libres MVP; parte agrupado] ·
006 nómina efectiva a Economía [enmienda fijar_salarios_dia — hook previsto en eco-003] + persistencia ·
007 HUD plantilla+nómina+ausencia [VISIBLE]). **20/21 AC; AC-PE10 (duración efectiva) diferido a Flujo
explícitamente.** Decisiones propuestas EN las stories (aprobar al implementar): prob_candidato_oficial
0.2 · refresco mercado por calendario (contratar solo retira al contratado) · gate contratación =
puede_pagar(salario_dia) sin coste puntual (Open Q4) · plantilla inicial 2+1 atributos medios (nómina
190 € intacta) · señales bus incidencia_personal/parte_personal. Erratilla GDD anotada (k_motivacion
0.05 tabla vs 0.1 en F3 → dos knobs separados). EPIC+índice+sprint actualizados (C1-5 done).
**SPRINT 1 COMPLETO AL 100 % (todas las tareas done, 6 días antes de plazo).** Sin commit aún.
**PRÓXIMO:** commit de C1-5 → luego Sprint 2 (/sprint-plan: implementar Personal; después Construcción
y Flujo — al cerrar Flujo el saldo SUBIRÁ por fin en el HUD y la pantalla se parecerá a la preview).
**✅ C1-5 COMMITEADO (a525cff, pusheado). SPRINT 1 CERRADO.**
**✅ personal-001 IMPLEMENTADA + TEST EN VERDE (2026-07-24, hilo principal — arranque de facto del
Sprint 2 a petición del usuario, sin /sprint-plan formal aún):** `src/core/personal/agente.gd`
(class_name Agente, RefCounted: nombre/tipo_id/rango/4 atributos con CLAMP en setter/mando forzado a 0
en Policías/estado/puesto_id + media_atributos) + `personal.gd` (nodo class_name Personal: fórmulas
F1 salario_dia [base del catálogo `TipoAgente.salario_dia_eur` × prima calidad × prima rango] · F2
modificador_produccion [0.5-1.3] · F3 factor_trato [0.5-1.5, Trato 3 = 1.0 neutro con cualquier Mot —
la modulación multiplica el DESVÍO] · F4 prob_ausencia [0-1] + aplicar_config con clamps [prima_rango
≥ 1.0; pool vacío → genérico]) + `config_personal.gd` (13 knobs + pool 24 nombres; k_motivacion
SEPARADO en dos: 0.05 F2 / 0.1 F3 — erratilla GDD) + `tools/build_config_personal.gd` →
`datos/config/personal.tres`. Test `personal_agente_formulas_test.gd` **9/9** (PE01/03/04/11/12/18/20
+ clamps config + .tres real). **Lección float:** un assert de FRONTERA exacta (<= 0.1) cae por
representación binaria (0.05×2 ≠ 0.1 exacto) → epsilon 0.1001. Nota GdUnit: tras un FAIL corta la
suite (los "6 de 9 tests" eran eso). **Suite total: 229/229, exit 0.** SIN commit aún.
**✅ personal-002 IMPLEMENTADA + TEST EN VERDE (2026-07-24):** mercado F5 en personal.gd —
`generar_mercado()` (n_candidatos sembrados; orden de tiradas FIJO nombre→tipo→rango→atributos→mando),
`_tirada_sesgada` (media redondeada de 2×randi_rango(1,5) → triangular, cracks raros), Oficiales con
prob_candidato_oficial 0.2, TIPOS_MERCADO=[ag_doc, ag_odac] (ag_seguridad fuera), `contratar(i)` (gate
E4 `_economia.puede_pagar(salario_dia)` inyectado vía usar_economia; SOLO comprueba, no cobra —
Open Q4; contratado sale del mercado → plantilla libre), `despedir` (gratis, limpia puesto_id),
`_al_nuevo_dia` con ciclo de refresco (regeneración completa cada refresco_mercado_jornadas=3;
contratar NO repone el hueco — decisión de la story; la 004 le añadirá ausencias y el registro prio
30). Test `personal_mercado_test.gd` **7/7 a la primera** (PE05 gate con Economía REAL, PE06
determinismo campo a campo, sesgo triangular 1600 tiradas, mercado vacío válido, refresco calendario,
despido, banquillo). **Suite total: 236/236, exit 0.** SIN commit (001+002 pendientes).
**✅ personal-003 IMPLEMENTADA + TEST EN VERDE (2026-07-24):** asignación en personal.gd —
`registrar_puesto/quitar_puesto` (puestos ABSTRACTOS `_puestos: {puesto_id -> tipo_puesto_id}`;
Construcción registrará los reales con la misma API), `asignar` (valida: registrado, plazas 1,
`puestos_operables` del catálogo, máx 1 Oficial/servicio [PA2 — `TipoPuesto.servicio` YA estaba en el
esquema, sin convención]; mover atómico; rechazos de REGLA silenciosos, datos malos con aviso;
idempotente), `desasignar`, `servicio_de_puesto`, `_oficial_de_servicio` (lo reutilizará la 005) +
**gate FL4**: `puesto_dotado` (asignado/cubriendo — el ausente NO dota, 004), `agente_de`,
`modificador_produccion_de`/`factor_trato_de` (sin agente → 1.0 + aviso). `despedir` ahora libera el
puesto de verdad. Test `personal_asignacion_test.gd` **7/7 a la primera** (PE02/08/09 + doble
ocupación + modificadores + inválidos + despedir/quitar_puesto liberan). **Suite total: 243/243,
exit 0.**
**✅ personal-001..003 COMMITEADAS (commit 06d6fb0, pusheado). FIN DE SESIÓN 2026-07-24.**
**✅ personal-004 IMPLEMENTADA + TEST EN VERDE (2026-07-24, hilo principal):** ausencias del día en
personal.gd — `_al_nuevo_dia` AMPLIADO con orden interno FIJO documentado (contrato determinista del
RNG: reincorporar ausentes de ayer → tirada F4 por agente en orden de plantilla → refresco del
mercado al final); `_reincorporar_ausentes` (titular→asignado / banquillo→libre) +
`_evaluar_ausencias` (RNGService.randf() < prob_ausencia; marca &"ausente" CONSERVANDO titularidad →
puesto_dotado false); registro `registrar_ordenado(&"nuevo_dia", 30, ...)` en _ready SOLO en árbol
(bus inyectable `usar_bus` patrón Demanda, auto-resuelto a /root/EventBus); enmienda del bus
APLICADA: señal `incidencia_personal(texto, puesto)` (una por baja; puesto &"" si banquillo).
**2 micro-decisiones NUEVAS fuera de story (pendientes de ratificar): la baja del día no se "cura"**
— (a) `asignar` RECHAZA a un ausente (silencioso, regla de juego) y (b) `desasignar` a un ausente le
quita la plaza pero conserva &"ausente" hasta la reincorporación (cierran el exploit de re-dotar el
puesto reasignando al enfermo). Test integración `personal_ausencias_test.gd` **7/7 a la primera**
(AC-PE13 determinismo 2 pasadas · boundary prob 1/0 · AC-PE15 titularidad+no-cura · reincorporación
titular/banquillo · señal 2 bajas · orden prio 30 con espías 29/31 · AC-PE19 Pausa con physics real).
**Suite total: 250/250, exit 0.** SIN commit aún.
**✅ RATIFICADO por el usuario (2026-07-24):** las 2 micro-decisiones de la 004 (asignar rechaza
ausente; desasignar conserva &"ausente") + la simplificación MVP de la 005 (solo LIBRES cubren).
**✅ personal-005 IMPLEMENTADA + TEST EN VERDE (2026-07-24, hilo principal):** el Oficial en
personal.gd — `_al_nuevo_dia` ahora: deshacer coberturas de ayer → reincorporar → tirada F4 (devuelve
incidencias por servicio) → `_cubrir_vacantes` (F6) → `_emitir_avisos` (F7) → mercado. Cobertura:
`_coberturas {puesto->cubridor}` SEPARADO de `_asignaciones` (el titular ausente conserva su entrada;
el cubridor cubre de prestado con puesto_id &"" y estado &"cubriendo"); presupuesto por servicio
**`ceil(Mando/2)` — ⚠️ ERRATA GDD F6 cazada: el texto dice floor(Mando/2) pero su tabla de salida
(1-2→1 · 3-4→2 · 5→3) y AC-PE14 son ceil; implementado fiel a la TABLA, propagar al GDD** (como
k_motivacion). Solo cubre puestos con TITULAR de baja (sin titular = tarea del jugador); candidato =
primer LIBRE compatible (puestos_operables) en orden de plantilla; Oficial ausente no cubre (edge).
Canalización F7: con Oficial presente → 1 `parte_personal({servicio, ausencias, cubiertas,
escaladas})` (enmienda del bus APLICADA); sin Oficial o banquillo → `incidencia_personal`
individuales. Gate FL4 actualizado: `puesto_dotado` true si hay cubridor; `agente_de`/modificadores
responden por el agente OPERATIVO (cubridor si lo hay). asignar/desasignar/quitar_puesto liberan
coberturas (sin cubridores colgantes). Test `personal_oficial_test.gd` **8/8 a la primera** (PE14
Mando 4→2 y Mando 1→1 · PE15 sin Oficial · PE16 1 parte vs 3 individuales · PE17 escalada ·
Oficial ausente · reincorporación deshace cobertura · compatibilidad ag_odac no cubre Doc).
**Suite total: 258/258, exit 0** (Personal 38/38). SIN commit aún (004+005 pendientes).
**✅ personal-004+005 COMMITEADAS (commit 6296a52, pusheado).**
**✅ personal-006 IMPLEMENTADA + TEST EN VERDE (2026-07-24, hilo principal):** nómina efectiva +
persistencia — **enmienda a Economía APLICADA** (`fijar_salarios_dia(Array[float])`: una vez fijada
SUSTITUYE al cálculo por tipos en `_gasto_salarios_dia`; array vacío = nómina 0, NO fallback;
`fijar_plantilla` queda para compat/tests); Personal `_actualizar_nomina()` (F1 por agente, plantilla
completa — el ausente cobra) llamada en contratar/despedir/load_state. Persistencia ADR-0002:
`save()` = {plantilla, mercado (dicts JSON-safe por agente), jornadas_desde_refresco, **coberturas
por ÍNDICE de plantilla** (necesarias para restaurar puesto_dotado — la story no las listaba, el
diseño de la 005 las exige)}; `load_state` defensivo (tipo huérfano → agente descartado con aviso,
NUNCA invalida el save; estado desconocido → libre; `_reconstruir_asignaciones` [puesto no
registrado/duplicado → banquillo, gana el 1º] + `_reconstruir_coberturas` + `_sanear_estados_
cargados`), 0 señales, nómina re-fijada en silencio; grupo Persist en _ready. INVARIANTE del caller:
puestos registrados ANTES de cargar. Test `personal_nomina_save_test.gd` **6/6 a la primera**
(AC-PE07 160 € efectivos vs 130 base con hook fijado · contratar/despedir re-fijan [despedir todo →
cierre sin gasto] · AC-PE21 round-trip JSON full_precision campo a campo con cobertura restaurada ·
AC-PE21 determinismo A-vs-B 2+3 días con refresco de mercado en medio, semilla 4242 · carga 0
señales · huérfano descartado). **Suite total: 264/264, exit 0.** SIN commit aún.
**✅ personal-006 COMMITEADA (commit 08612d6, pusheado).**
**🔨 personal-007 IMPLEMENTADA — VENTANA ABIERTA, SIGN-OFF PENDIENTE (2026-07-24):** plantilla
RATIFICADA (2 ag_doc + 1 ag_odac medios, nómina 190 € intacta). Hecho: `incorporar(agente)` en
personal.gd (API de arranque: entra libre sin gate + re-fija nómina); Main: hook
PLANTILLA_INICIAL/fijar_plantilla RETIRADO → nodo Personal (name "Personal", usar_economia, tras
Demanda), DOTACION_INICIAL const [tipo, puesto, tipo_puesto]×3, puestos registrados ANTES de
cualquier carga (invariante load_state), 3 agentes del pool de nombres asignados; HUD bloque nuevo:
"Plantilla: N · Nómina: X €/día" + "Plantilla al completo" (verde) / "Hoy falta(n): nombre (puesto)"
(ámbar, pull por frame de estados — texto+color daltónico); captura evidencia →
personal-hud-2026-07-24.png. Headless 30 frames limpio; **suite 264/264, exit 0**; evidencia
`production/qa/evidence/personal-hud-2026-07-24.md` escrita (sign-off ⬜ PENDIENTE). SIN commit.
**🎉🎉🎉 EPIC PERSONAL COMPLETO (2026-07-24, 7/7 + SIGN-OFF ✅ del usuario) — TERCER MÓDULO CORE
TERMINADO (Economía, Demanda, Personal):** sign-off dado con la ventana abierta ("veo plantilla y
coste"); en la demo el usuario preguntó por los NPCs visibles → expectativa re-gestionada en llano:
son de FLUJO (tras Construcción), Personal es gestión — quedó conforme. Cierre formal hecho:
stories 004-007 → Complete (con secciones "Cierre" que documentan: micro-decisiones ratificadas de
la 004, errata F6 floor→ceil + solo-libres de la 005, coberturas añadidas al save en la 006,
expectativa NPCs en la 007); EPIC.md → Complete (todas las decisiones propuestas RATIFICADAS);
index.md Personal → Complete; evidencia personal-hud-2026-07-24.md con sign-off ✅ (M2/M3 no
ejercitados en demo, cubiertos por tests automáticos — anotado con honestidad). **Suite 264/264,
exit 0.**
**✅ SPRINT 2 ABIERTO FORMALMENTE (2026-07-24, /sprint-plan new, lean — PR-SPRINT omitido):**
production/sprints/sprint-2.md + sprint-status.yaml reescrito (C2-1..C2-7). Goal: cerrar Core —
**Construcción** (Must: C2-1 create-stories → C2-2 implementar ~6-7 stories con ratón+E4+API puestos
de Personal, HITO VISIBLE → C2-3 cierre) → **Flujo** (Should: C2-4 stories [verificar nav en
engine-reference] → C2-5 implementar ~7-8 stories, NPCs VISIBLES + saldo SUBE, 60 FPS spike QQ-02 →
C2-6 cierre+demo) → C2-7 Nice: propagar erratas GDD (F6 ceil, AC-T26, tasa_base_odac, valle
nocturno). Capacidad ~2,5 sesiones (velocidad ~7 stories/sesión). Personal quedó registrado como
trabajo ENTRE sprints. **Decisión usuario: /qa-plan sprint ANTES de implementar** (como Sprint 1).
**✅ Sprint-2.md + qa-plan-sprint-2.md ESCRITOS Y COMMITEADOS (90bd27a, pusheado).** QA plan lean a
nivel de epic citando AC-CO01..18 y AC-FL01..27; lógica de Flujo se testea SIN navegación (FL5);
hitos visibles con sign-off + FPS ≥60.
**✅ C2-1 `/create-stories construccion` HECHO (2026-07-24, aprobado por el usuario):** 7 stories en
`production/epics/construccion/` (001 núcleo+config+validación F6 [Logic] · 002 construir+pagar F1/F2
gate E4 [Int] · 003 puentes registrar_puesto→Personal + aforo F3 + F5 [Int] · 004 demoler/mover F4
cascada 2 pasos [Int] · 005 pausa+persistencia layout [Int, ADR-0002] · 006 solar visible
TileMapLayer+PackedScene+montaje inicial DE OFICIO [UI] · 007 modo construcción ratón+preview
fantasma [UI, HITO VISIBLE+sign-off]). **17/18 AC; AC-CO13 (demoler atendiendo) DIFERIDO a Flujo**
(patrón AC-PE10). Decisiones propuestas EN las stories (aprobar al implementar): tamaño del edificio
en ConfigConstruccion · montaje inicial pagado DE OFICIO (saldo 3000/nómina 190 intactos) · mover
solo puestos/objetos · ids doc_1/doc_2/odac_1 compat · **⚠️ Main reordenado: Construcción ANTES que
Personal (invariante de carga de personal-006 — detectado al trocear)**. EPIC→In Progress, index
actualizado, sprint-status.yaml expandido (C2-1 done; const-001..007 ready-for-dev). SIN commit aún.
**✅ Stories de Construcción COMMITEADAS (3f3a793, pusheado).**
**✅ const-001 IMPLEMENTADA + TEST EN VERDE (2026-07-24, hilo principal):**
`src/core/construccion/construccion.gd` (class_name Construccion, nodo del mundo: modelo lógico
`_salas {id->{tipo,rect:Rect2i}}` + `_elementos {id->{catalogo,celda,sala,coste_pagado}}` +
`_contador_ids`; `validar_sala` F6 [dentro edificio ∧ sin solape estricto — adyacente vale ∧ área ≥
mín] · `validar_elemento` [sala compatible: puesto → puestos_admitidos del catálogo, ASIENTO_BASICO
(id especial, no está en catálogo) → sala tipo "espera"; celda libre] · `sala_en`/`_crear_sala`/
`_crear_elemento` (registro directo sin cobrar — lo usará la 002; `id_forzado` para compat doc_1...))
+ `config_construccion.gd` (9 knobs; edificio 24×13 = el suelo del esqueleto; ⚠️ decisión propuesta:
tamaño edificio en config, a Escenario en multi-comisaría) + `tools/build_config_construccion.gd` →
`datos/config/construccion.tres` (generado OK). Test `construccion_validacion_test.gd` **7/7 a la
primera** (CO01 solape/límites/adyacente · CO03 frontera área 4 · CO02 puesto en su oficina ·
asiento solo en espera · solape elementos · tipos inexistentes · clamps+.tres real).
**Suite total: 271/271, exit 0.** SIN commit aún.
**✅ const-002 + const-003 IMPLEMENTADAS + TEST EN VERDE (2026-07-24):** en construccion.gd —
002: `coste_sala` F1 (base catálogo TipoSala + coste_por_celda×área; oficinas base 0) ·
`coste_elemento` F2 (ASIENTO_BASICO de config 25 €; puestos del catálogo 500/500/600) ·
`_clamp_coste` AC-CO18 · `construir_sala`/`construir_elemento` (validar → `_pagar` → alta con
coste_pagado; rechazo de regla silencioso; `_pagar` usa `_economia.cobrar` que YA gatea E4 él solo —
sin Economía avisa y construye gratis [tests]) · usar_economia/usar_personal inyectables.
003: construir un PUESTO llama `_personal.registrar_puesto(elemento_id, id_catalogo)` (puente;
elemento_id generado tipo "puesto_doc_general_1") · `aforo_de_sala` F3 = min(_asientos_en,
floor(área×densidad)) con RECHAZO del asiento sobrante EN validar_elemento (el preview también lo
verá rojo) · `puestos_utiles` F5 puro (throughput ≤0 → 0 aviso) · getters Flujo: `posicion_de`
(centinela (-1,-1)) + `puestos_de_servicio` (orden estable). Tests `construccion_pagar_test.gd`
**5/5** (F1 380/600/oficina 180 · CO05 saldo intacto · CO06 600→100 + coste_pagado · sala paga y
registra + inválida no cobra · clamp) y `construccion_puentes_test.gd` **6/6** (CO15 asignar+gate
FL4 real · CO07 aforo 10→14→15.º rechazado sin cobrar · CO08 aforo 0 · CO09 10 puestos sin tope
1000 € restantes · CO10 F5 · posicion_de). **Suite total: 282/282, exit 0** (Construcción 18/18).
**✅ const-004 + const-005 IMPLEMENTADAS + TEST EN VERDE (2026-07-24):** en construccion.gd —
004: `demoler_elemento` (F4 abona coste_pagado×pct vía `_abonar`; libera celda; `quitar_puesto` si
era puesto) · cascada en 2 pasos `contenido_de_sala` (UI confirma) + `demoler_sala` (reembolsa cada
elemento + la sala; _crear_sala AHORA guarda coste_pagado — construir_sala se lo pasa) ·
`mover_elemento` (revalida con param `ignorar` NUEVO en validar_elemento/_celda_ocupada/_asientos_en
— no se cuenta a sí mismo, arregla mover asiento en sala a tope; gratis NO pasa por el gate [con
coste_mover>0 sí — en deuda cobrar(0) daría false]; conserva id/coste_pagado; Personal ni se
entera). 005: grupo Persist en _ready · `save()` {salas[id,tipo,rect[x,y,w,h],coste_pagado],
elementos[id,catalogo,celda[x,y],coste_pagado], contador_ids} (sala del elemento SE RE-DERIVA de la
celda) · `load_state` defensivo (corrupto descartado con aviso; ANTES de limpiar retira del puente
los puestos del estado anterior — sin huérfanos en Personal._puestos; re-registra los cargados;
contador restaurado anti-colisión). Tests `construccion_demoler_test.gd` **7/7** (CO11 2750 ·
CO12 cascada 660 → 2340 · CO14 mover gratis+agente intacto · mover incompatible · reembolso sobre
lo PAGADO · mover asiento a tope [ignorar] · ids inexistentes) y `construccion_save_test.gd` **6/6**
(CO17 campo a campo + contador fresco · re-registro · **combinado Construcción→Personal en ORDEN** ·
sin dinero/señales · corrupto · CO16 Pausa con physics real). **Suite total: 295/295, exit 0**
(Construcción 31/31). Motor completo 5/7 — quedan las visibles.
**PRÓXIMO INMEDIATO:** const-006 (solar visible: TileMapLayer "Salas" con TileSet por código color
por servicio + etiquetas · puestos/asientos PackedScene placeholder por código con map_to_local ·
montaje inicial DE OFICIO construido por la API real con flag gratis + ids compat doc_1/doc_2/odac_1
· **Main reordenado Construcción ANTES que Personal** y retirar registrar_puesto a mano; captura,
sign-off conjunto con 007) → 007 (modo construcción ratón+preview fantasma, HITO VISIBLE+sign-off).
**✅ demanda-003 IMPLEMENTADA + TEST EN VERDE (2026-07-23):** cableado en demanda.gd — usar_bus/
usar_tiempo (patrón Economía), `_suscribir_al_tick` (Tiempo.suscribir_tick, idempotente; Demanda 1º —
Flujo/Paciencia se suscribirán DESPUÉS), `_al_tick` (min_dia de tiempo.minutos_juego al FINAL del
avance → _detectar_cierre_doc por CRUCE de 870 con guarda `_min_dia_anterior` → procesar_avance →
emit persona_generada + llegadas_hoy++), reset acumulador Doc al cierre, `_al_nuevo_dia` prio 40
(reset llegadas_hoy; registrado en _ready solo en árbol). Test integración
`demanda_tick_ventana_test.gd` **6/6 a la primera** (DM05 bus+catálogo real, DM09 15:00 Doc 0/ODAC≥1,
DM10 reset al cruce, DM11 Pausa con physics REAL en árbol (mult 0 → no push), DM16 360 fichas exactas
sin freno, orden prio 40 con espías 39/41). **Suite total: 203/203, exit 0.** Sin commit aún (todo el
epic pendiente de commit).
**PRÓXIMO INMEDIATO (SESIÓN NUEVA — decidido por contexto al 75%):** tarea **C1-4 = epic DEMANDA**
(Should Have del Sprint 1): `/create-stories demanda` (propuesta desde demand-generation.md: tasas de
llegada calibradas a R5, mezcla ponderada de los 14 tipos vía RNGService.elegir_ponderado, régimen
día/noche con mult_nocturno_odac, perfil semanal; emitirá tramite_solicitado/persona_generada — verificar
señales del bus) → aprobar → implementar. Demanda hará que el saldo SUBA en el HUD (ingresos visibles).
Luego C1-5 stories de Personal. Si los subagentes siguen caídos ("Usage credits 1M") → hilo principal;
el usuario puede reactivarlos con /usage-credits.
Estado de código: 173/173 tests verdes; Foundation 5/5; Core 1/5 (Economía); Sprint 1 dentro de plazo.
Leftovers a limpiar (permiso rm denegado): `tests/verify_event_bus_tmp.gd` (gitignored) + clon externo
`C:/Users/manur/gdunit4_tmp` (fuera del repo).
Producción reimplementa en `src/` DESDE CERO (nunca importa de `prototypes/`; el slice es solo referencia de diseño).

## 🚀 EN CURSO — VERTICAL SLICE (1er build jugable) — Phase 4: Implement (2026-07-22)
**Concepto:** `comisaria-vertical-slice` · **Modo:** LEAN · **Skill:** `/vertical-slice` en curso.
**Pregunta de validación (falsable):** ¿un jugador desde cero siente que *gestionar el flujo de ciudadanos por una
Oficina de Denuncias siendo subinspector* es entretenido ~3–5 min, sin guía — y podemos construir ese bucle a ritmo
razonable? (fun + feasibility).
**Ciclo demostrado:** [Inicio] presupuesto + oficina casi vacía → [Reto] colocas puestos, asignas 2–3 agentes,
gestionas cola (DNI + 1 denuncia) por un día/noche sin que exploten esperas ni dinero → [Resolución] objetivo de
eficiencia cumplido → **"¡Ascenso!"**.
**Alcance (rebanada mínima, recorta alcance NO calidad):** Tiempo(reloj+Pausa/1/2/3×+1 día-noche) · Demanda(tasa+RNG
sembrado) · Flujo(turno→cola→puesto→delta→resuelto/abandono) · Datos(DNI + 1 denuncia) · Construcción(1–2 puestos +
sala espera con presupuesto, rejilla real) · Personal(2–3 agentes asignables) · Economía(presupuesto+cobro+salario) ·
Paciencia(barra→abandono, sat básica) · Objetivo→Ascenso · UI/HUD básico. **FUERA:** 13 tipos, construcción libre
completa, reclamaciones, mercado/Oficial/ausencias, préstamos, eventos estacionales, juice pulido.
**Spike QQ-02 (riesgo técnico nº1):** docenas de NPCs con NavigationServer2D/NavigationAgent2D a **≥60 FPS**; plan B
AStarGrid2D. Nav = arquitectura real (ADR-0004) para que el spike sea representativo.
**Arte:** placeholder (formas/colores), cero arte real.
**Decisión de ubicación (REVISADA con usuario 2026-07-22):** proyecto Godot **AISLADO dentro de
`prototypes/comisaria-vertical-slice/`** (`project.godot` ahí; `res://` = esa carpeta). Motivo: el usuario pidió
carpeta propia hecha por Claude → evita el bloqueo de Godot 4.6 a "New Project en carpeta no vacía" (usa **Import**) y
es coherente con throwaway. La **raíz del repo se reserva para el proyecto de PRODUCCIÓN** (con su andamiaje
`res://tests/`); producción se escribe en `src/` desde cero (nunca importa de prototypes/). Renderer del slice =
**Compatibility** (`gl_compatibility`; 2D puro + arranque seguro Windows; technical-preferences lo autoriza).
**Plan por escalones (verificación con el usuario tras cada uno):**
- ✅ **Escalón 0 — El proyecto respira:** 7 archivos creados en `prototypes/comisaria-vertical-slice/`
  (project.godot + autoloads EventBus/RNGService/Tiempo + main.tscn/main.gd con HUD del reloj por código +
  Pausa/1×/2×/3× + atajos Espacio/1/2/3 + fondo que cambia con día/noche). **VALIDADO EN HEADLESS por Claude**
  (Godot 4.6.stable, 0 errores/warnings, 3 autoloads cargan) **+ VERIFICADO POR EL USUARIO 2026-07-22**
  (ve el reloj correr, botones/atajos OK, fondo día/noche). **COMPLETO. ← Siguiente: Escalón 1.**
  Nota de flujo: Claude puede lanzar el juego con ventana él mismo (`Godot_v4.6-stable_win64_console.exe --path ...`
  en background) y validar en headless (`--headless --quit-after N`) — el usuario solo mira/juega.
- ✅ **Escalón 1 — Un ciudadano, un puesto:** CONSTRUIDO + validado headless (0 errores). Archivos nuevos:
  `personas/persona.gd` (CharacterBody2D + NavigationAgent2D, avoidance OFF, gotcha 1er physics frame, estados
  A_PUESTO→ATENDIENDO→A_SALIDA, atención con `Tiempo.delta_juego`), `mundo/mundo.gd` (NavigationRegion2D +
  NavigationPolygon bakeado con `NavigationServer2D.bake_from_source_geometry_data` + traversable/obstruction
  outline = muro a rodear; genera 1 ciudadano a la vez), autoload `economia/economia.gd` (Core: saldo 3000 +
  TARIFA_DNI 12€ al oír `tramite_completado`). **BUG del Escalón 0 corregido:** los botones robaban Espacio →
  `focus_mode = FOCUS_NONE`. Capas reordenadas: Fondo(layer -1) < Mundo < HUD. **VERIFICADO POR EL USUARIO
  2026-07-22** (rodea el muro ✅, sube presupuesto ✅, Espacio OK ✅). **🎉 Navegación 2D = riesgo técnico nº1,
  VALIDADA con 1 NPC** (el spike de VOLUMEN sigue pendiente → Escalón 5, QQ-02). **COMPLETO. ← Siguiente: Escalón 2.**
  **Aprendizajes técnicos (para todo el slice):** (1) `class_name` NO se resuelve en headless "en frío" (sin
  abrir editor) → usar `preload("res://...").new()`; (2) `PackedVector2Array` con `Vector2(...)` NO puede ser
  `const` → usar `var`; (3) validar SIEMPRE en headless (`--quit-after N`) antes de lanzar ventana.
- ✅ **Escalón 2 — Cola + demanda:** CONSTRUIDO + validado headless (0 errores, 900 frames). Nuevo:
  `demanda/demanda.gd` (nodo: ritmo INTERVALO_DIA 10min / NOCHE 40min + `RNGService.elegir_ponderado`
  DNI 0.6 / denuncia 0.4). `persona.gd` reescrita: estados A_ESPERA→ESPERANDO→LLAMADA→ATENDIENDO→SALIENDO,
  `tipo` (dni/denuncia), color por tipo (azul/naranja), acumula `_espera_min`, señal `empezo_atencion`.
  `mundo.gd` reescrita: hace de Flujo (cola FIFO `_cola`, sala de espera con 12 asientos, 1 puesto
  `_en_atencion`, métrica espera media/última/atendidos). `economia.gd`: TARIFA por tipo (dni 12€, denuncia 0€).
  `main.gd`: HUD con En cola / Espera media / Atendidos. **← Pendiente verificación visual del usuario**
  (¿llegan y hacen cola?, ¿atiende de uno en uno?, ¿métricas se mueven?, ¿de noche baja afluencia?).
  Nota diseño: 1 puesto no da abasto → la cola crece → motiva el Escalón 3 (construir puestos + agentes).
  **FIX 2026-07-22 (2 bugs reportados por el usuario, misma raíz):** las Personas (CharacterBody2D) se empujaban
  por colisión física y salían del área navegable; una en estado LLAMADA empujada fuera quedaba atascada y
  BLOQUEABA el puesto → la cola crecía sin fin. Solución: `collision_layer=0`/`collision_mask=0` (sin empujones;
  solaparse es cosmético, coherente con ADR-0004 avoidance off) + salvavidas `TELEPORT_UMBRAL_MIN=300` min-juego
  (snap al destino si un trayecto se atasca, en LLAMADA y SALIENDO). Re-validado headless (0 errores). El borde
  del "cuadrado" es solo decorativo (draw_rect); el límite real es el navmesh.
  **MEJORA 2026-07-22 (feedback usuario):** (a) espera = COLA EN FILA ordenada que avanza (adiós amontonamiento;
  `_pos_fila` serpenteante + `_reordenar_cola` + `persona.ir_a_espera`); (b) colisión personas↔personas OFF pero
  personas↔entorno ON (`collision_layer=2`/`collision_mask=1`, listo para paredes/objetos físicos del Escalón 3);
  (c) el puesto se libera AL TERMINAR el trámite (señal `libera_puesto`), no al salir del edificio → el siguiente
  entra mientras el anterior sale; (d) cola en **ZIGZAG continuo** (`_pos_fila` invierte columnas en filas impares
  → recorrido en S, nadie cruza a nadie). Re-validado headless (0 errores). **✅ VERIFICADO POR EL USUARIO
  2026-07-22** (fila zigzag OK, puesto libera al terminar OK, sin amontonamiento ni cruces). Decisión: fila
  zigzag en vez de asientos → OK para el slice; producción reconciliará con aforo/comodidad. **COMPLETO.**
- 🔄 **Escalón 3 — Construir + agentes + presupuesto** (AMPLIADO por feedback del usuario; troceado en 4 entregas).
  **Decisión de alcance (usuario 2026-07-22):** sistema de espera COMPLETO = asientos (te sientas si hay hueco) →
  al llenarse, cola con **BARANDILLAS CONSTRUIBLES POR EL JUGADOR** (clic-clic traza el recorrido; capacidad =
  longitud/separación) → si se llena, esperar FUERA de la comisaría. (El usuario eligió la opción grande a pesar
  del aviso de scope; es un sistema tipo Planet Coaster.) Entregas:
  - (A) Construir puestos: `puesto.gd` (entidad), varios puestos, colocación con ratón (fantasma + snap rejilla 40 +
    validación + gate Economía `puede_pagar`/`cobrar`, COSTE 500), reparto de cola entre puestos libres.
    CONSTRUIDO + validado headless (0 errores). `puesto.gd` (Node2D, atiende 1 a la vez, `esta_disponible`,
    `asignar_persona`, `liberar`, `atiende_a`). Construcción vía `_unhandled_input` (clic izq coloca / der sale),
    fantasma en `_process` con `_snap`/`_colocacion_valida`. **FIX 2026-07-22 (bug reportado por usuario):** el
    ColorRect de fondo (full-rect) tenía `mouse_filter=STOP` → se tragaba los clics y no colocaba nada →
    `mouse_filter=IGNORE`. + rejilla visible en modo construir (`_dibujar_rejilla`) + puesto inicial alineado a la
    rejilla (960,240) + umbral de solape 84→74. **MEJORA 2026-07-22 (feedback usuario):** puesto con ORIENTACIÓN
    (rotar con tecla R en construir; lado FUNCIONARIO = marca azul detrás [ahí irá el agente en D] + lado
    CIUDADANO = frente donde se atiende; `dir_frente`/`pos_atencion` según orientación; la mesa cambia dims al
    rotar; fantasma dibuja la orientación). **← Pendiente re-verificación usuario.**
  - (B) Asientos: CONSTRUIDO + validado headless. **Modelo corregido (feedback usuario: los sentados NO se
    levantan a cambiar de silla):** `_cola` = orden FIFO de atención; asiento FIJO por persona (`_asiento_de` +
    `_asientos_libres`); `_fila` = desborde de pie (zigzag). Al atender → `_sacar_de_espera`: si libera asiento,
    el 1º de `_fila` se sienta ahí (trasvase) + `_reordenar_fila` (SOLO los de pie se mueven). 12 asientos.
    **+ HUD movido ABAJO-IZQUIERDA y compactado** (tapaba la sala de espera; `set_anchors_and_offsets_preset`
    BOTTOM_LEFT). **← Pendiente verificación usuario.**
  - (C) Barandillas construibles: CONSTRUIDO + validado headless. `_postes` (polilínea), modo BARANDILLA
    (clic=poste, Z=deshacer, empieza por la cabeza=poste 0 naranja); `_pos_espera_pie` sigue el recorrido
    (`_pos_en_recorrido` interpola; `capacidad_cola` = longitud/SEP_COLA); desborde `_pos_fuera` (apila en la
    entrada); fallback zigzag si <2 postes. **+ modo DEMOLER (feedback usuario, no estaba previsto):** clic borra
    puesto (reembolso 250€ = 50%, GDD F4) o poste; resalta en rojo el objetivo bajo el cursor. HUD reescrito:
    3 botones (Construir puesto / Trazar cola / Borrar) + "De pie: X/cap". **← Pendiente verificación usuario.**
  - (D) Agentes: CONSTRUIDO + validado headless. `agente.gd` (Node2D, z_index 1, color, aro de selección).
    3 agentes; puesto requiere `agente != null` para atender (gris=cerrado / amarillo=abierto); modo AGENTE
    (clic agente → clic puesto = asignar; clic fuera = a disponibles; se colocan en `pos_funcionario` = lado azul);
    salario 60€/agente asignado al `nuevo_dia` (EventBus). Puesto inicial arranca con agente 0; demoler un puesto
    libera su agente. HUD: botón "Agentes" + "Agentes: A/T". **← Pendiente verificación usuario. Cierra Escalón 3.**
  Refactor hecho: `persona.configurar` sin `pos_puesto`; `persona.llamar_al_puesto(pos)` recibe la posición del puesto.
- 🔄 **Escalón 4 — Día/noche + objetivo → ascenso:** CONSTRUIDO + validado headless. (a) Demanda nocturna: de
  noche SOLO denuncias (DNI/Documentación cierra; ODAC 24h) + menos afluencia (intervalo 40 vs 10). (b) Objetivo:
  RANGOS (Subinspector→Inspector→Inspector Jefe→Comisario); al alcanzar `_objetivo` atendidos (paso 25) →
  `EventBus.ascenso` → overlay central "¡ASCENSO!" + pausa + botón "Seguir jugando" (sube al siguiente rango).
  HUD: "Rango · Objetivo X/Y". **← Pendiente verificación usuario.**
  **PENDIENTE tras verificar:** (1) barandillas como OBSTÁCULO de navegación — los que van/vuelven del puesto
  las rodean (petición usuario; requiere re-bake del navmesh con las barandillas como obstrucción + offset de la
  cola); (2) Escalón 5 = spike de rendimiento QQ-02; (3) REPORT.md con verdict.
- ✅ **Escalón 5 — Spike de rendimiento QQ-02: PASA HOLGADO.** Modo estrés (botón "Test rendimiento" / auto en
  headless) genera hasta N NPCs + muestra FPS. **Medido por Claude en headless: 80 NPCs → ~145 fps; 150 NPCs →
  ~145 fps** (simulación pura, sin render/vsync; presupuesto 60 fps = 16,6 ms → sim usa ~7 ms). La navegación mesh
  (NavigationServer2D/NavigationAgent2D) NO es cuello de botella; **riesgo técnico nº1 MITIGADO; plan B AStarGrid2D
  NO necesario.** `_estres`/`TOPE_ESTRES`/`_npcs_vivos`/print FPS.
- 🎉 **PROTOTIPO COMPLETO (Escalones 0–5).** Bucle validado por el usuario a lo largo de la sesión + spike PASA.
  **Decisión usuario 2026-07-22:** prototipo terminado → ir a Producción (aclarado prototipo≠juego; 2 salas Doc/ODAC,
  paredes, arte… son de Producción vía GDD, NO del slice).
  **✅ REPORT.md escrito (verdict PROCEED)** en `prototypes/comisaria-vertical-slice/REPORT.md` + registrado en
  `prototypes/index.md`. CD-PLAYTEST omitido (modo LEAN). **`/vertical-slice` COMPLETO.**
  **PRÓXIMO (Producción):** `/gate-check` (Pre-Production→Production; el REPORT es la evidencia de playtest) →
  `/create-epics` (foundation, core) → `/create-stories [epic]` → `/sprint-plan`. Producción reimplementa en
  `src/` DESDE CERO (nunca importa de `prototypes/`). **Diferido a Producción (backlog del slice):** 2 salas
  Doc/ODAC con salas de espera · paredes/salas con colisión · barandillas como OBSTÁCULO de navegación (re-bake) ·
  arte real · 13 tipos · reclamaciones · dilemas de influencia · ascenso completo. **Nada del prototipo se migra:
  es solo referencia de diseño.**
  **⚠️ Nota commit:** en toda la sesión NO se ha hecho `git commit` — prototipo + REPORT + updates de estado sin
  guardar en git (hito pendiente de commit).
**Pasos MANUALES del usuario (principiante):** ya tiene Godot 4.6 instalado ✅ · PENDIENTE: crear/importar el proyecto
en Godot (genera `project.godot`), instalar GdUnit4 (AssetLib, más tarde), pulsar Play (F5).
**Recordatorios:** subagentes caídos → hilo principal (Opus 4.8); explicar en llano + verificar dudas técnicas con web;
protocolo colaborativo (pedir permiso antes de escribir); seguir el control-manifest al programar.

## Fase 4bis — ARQUITECTURA FIRMADA + REVISADA (2026-07-22, sesión nueva)
🎉 **`/architecture-review` HECHO — Verdict PASS.** Cobertura 100% (56/56 TR-IDs), 0 conflictos cross-ADR,
motor 4.6 consistente, 0 banderas de revisión de GDD. **2 correcciones menores aplicadas** (ADR-0002 `Depends On`
+= ADR-0003; corregida ref inexistente `TR-patience-008`→`003/004` en architecture.md). **LOS 4 ADRs quedan
`Accepted`** (orden del grafo: 0001/0003 → 0002/0004). Artefactos: `architecture-review-2026-07-22.md`,
`traceability-index.md`, `tr-registry.yaml` (poblado con los 56 IDs, v2). Nota para el manifest: `instantiate()`
(no `instance()`); gotchas de navegación 2D (target tras 1er physics frame; re-bake solo al cambiar layout).
**Pre-gate checklist:** ❌ tests/ · ❌ CI · ❌ ux/interaction-patterns.md · ❌ accessibility-requirements.md.
**✅ `/create-control-manifest` HECHO** (2026-07-22): `docs/architecture/control-manifest.md` (Manifest Version
2026-07-22; capas Foundation/Core/Feature/Presentation + Global; cada regla trazada a su ADR/fuente;
TD-MANIFEST omitido por LEAN).
**✅ `/test-setup` HECHO** (2026-07-22): `tests/` (unit/integration/smoke/evidence) + `tests/README.md` +
`tests/gdunit4_runner.gd` + `tests/smoke/critical-paths.md` (adaptado a Comisario) + `.github/workflows/tests.yml`
(gdUnit4-action, Godot 4.6). **Andamiaje en reposo** hasta inicializar Godot + instalar GdUnit4.
**✅ Gate note resuelto:** creado `tests/unit/example/example_sanity_test.gd` (plantilla + patrón de
determinismo RNG; incluye ejemplo comentado de test real de `retorno_dgp`).
**🔄 EN CURSO — `/ux-design`:** ✅ `design/accessibility-requirements.md` escrito (2026-07-22).
**Decisión usuario:** MVP solo-jugador sin necesidades de accesibilidad → **baseline de legibilidad de
fábrica DENTRO** (no-color con icono/forma/texto; todo por clic, sin hover-only; atajos Espacio/1/2/3;
audio no imprescindible) · **DIFERIDO post-MVP** (sin cerrar la puerta): panel de opciones configurable
(escala_ui/reducir_movimiento), remapeo de teclas, paletas daltónicas, lector de pantalla. **Resuelve
ui-hud OQ7.** PENDIENTE: `design/ux/interaction-patterns.md`.
**Nota (2026-07-22):** al usuario le preocupaba cuándo se responden las Open Questions → se le explicó el
sistema (ya resueltas / ahora Pre-Prod / **1er playtest** [la mayoría de jugabilidad] / post-MVP); NO quiso
guardarlo como documento (viven en cada GDD). Reiteró: **usar Sonnet 5, nunca 4.6** cuando toque Sonnet.
**✅ `design/ux/interaction-patterns.md` escrito** (12 patrones: paneo/zoom, dibujar sala por arrastre,
preview fantasma, colocar puesto/objeto, seleccionar/asignar agente, modos sobre la vista, HUD+5 tabs,
reconfig ODAC, control de velocidad, toasts, indicadores con respaldo, hover-detalle). Cross-ref OK.
**🎉 LOS 2 DOCUMENTOS QUE PIDE LA PUERTA ESTÁN HECHOS** (accessibility-requirements + interaction-patterns).
**✅ `/ux-review` HECHO** (2026-07-22): `interaction-patterns.md` → **APPROVED** (0 bloqueantes; 3 advisories
menores → se completan al diseñar `hud.md`/pantallas). ALINEADO con GDD; CUMPLE accesibilidad; CONSISTENTE.
**`/ux-design` + `/ux-review` COMPLETOS.**

## 🎉🎉 HITO — GATE Technical Setup → Pre-Production: **PASS** (2026-07-22)
`/gate-check pre-production` → **PASS, 0 bloqueantes.** 13/13 artefactos requeridos; quality checks OK;
sin ciclos de ADR; **4/4 directores READY** (lentes manuales, LEAN). Chain-of-Verification: verdict sin cambios.
**Etapa avanzada a `Pre-Production`** (`production/stage.txt`). Informe:
`production/gate-checks/gate-2026-07-22-technical-setup-to-pre-production.md`.
**2 observaciones menores (no bloquean):** (1) índice de trazabilidad **renombrado** a
`docs/architecture/requirements-traceability.md` (nombre canónico) — hecho; (2) `hud.md` diferido al slice.
**Condiciones abiertas para Pre-Producción:** spike de rendimiento nav 2D **QQ-02** (en el vertical slice);
completar art bible 5–9 + sign-off AD-ART-BIBLE antes del gate de Producción.

## 🚀 PRÓXIMO (fase Pre-Producción) — el 1er BUILD JUGABLE
**`/vertical-slice`** = primer build jugable (crear `project.godot`, instalar GdUnit4, primer código Godot,
correr el spike QQ-02). **HACERLO ANTES de epics/stories** (validar diversión primero). Luego: playtest →
`/playtest-report` (≥1 sesión para el gate Pre-Prod→Producción) → `/ux-design hud` → art bible 5–9 + sign-off
→ `/create-epics` (foundation, core) → `/create-stories` → `/sprint-plan new`.
**Recordatorio fijo:** subagentes caídos → todo en hilo principal (Opus 4.8); usar **Sonnet 5** si vuelven;
usuario principiante (explicar en llano + verificar dudas técnicas con web); protocolo colaborativo.
**Nota:** el proyecto Godot aún NO está inicializado (no hay `project.godot`); se creará en el vertical slice
(o antes si conviene para correr los tests de verdad).

## Session Extract — /architecture-review 2026-07-22
- Verdict: PASS
- Requirements: 56 total — 56 covered, 0 partial, 0 gaps
- New TR-IDs registered: 56 (tr-registry.yaml v2)
- GDD revision flags: None
- Top ADR gaps: None
- ADRs: 0001/0002/0003/0004 → Accepted
- Report: docs/architecture/architecture-review-2026-07-22.md

## Tarea actual
🎉 **HITO: DISEÑO MVP COMPLETO — 12/12 sistemas diseñados.** Todos los GDD del MVP escritos y consistentes
(`/consistency-check` 10ª PASS). **Estado del proyecto:** cerrada la fase de diseño de sistemas MVP.
**PRÓXIMO (fase nueva):** (1) `/design-review` en **sesiones NUEVAS** de los 12 GDD (independencia del autor);
(2) `/review-all-gdds` (revisión holística de teoría de diseño); (3) `/gate-check pre-production`; (4) arquitectura
(`/create-architecture` → ADRs, incl. bus de eventos, guardado, glow 4.6) → (5) **implementación en Godot** = primer
**build jugable** (lo que el usuario pidió que le avise). Alternativa: **vertical slice** en Godot antes de terminar
la revisión, si el usuario quiere adelantar la prueba jugable. Existe el **prototipo-concepto HTML** ya jugable.

## Fase de REVISIÓN + ARQUITECTURA (Ruta A) — EN CURSO (iniciada 2026-07-21)
**Ritmo elegido:** GDD por GDD (aprobación entre cada uno). Modo LEAN, hilo principal (subagentes caídos por "1M context").
**Progreso Fase 1 (`/design-review`, 12 GDD):**
- ✅ **Economía #3** (re-revisión) — **APPROVED** (0 bloqueantes; 2 recomendados + 2 nice aplicados: bloque "Vocabulario temporal" en E6 + F3 "Salarios por jornada" [día = jornada = ciclo 24 h = `nuevo_dia`]; `AC-E03b` ingreso estable intra-jornada; limpieza de nota obsoleta en Dependencies; metadatos → 2026-07-21). Log: `economy-budget-review-log.md`. **+ `/consistency-check` 11ª PASS.**
- ✅ **Tiempo #1** (re-revisión) — **APPROVED** (0 bloqueantes; 2 recom + 3 nice aplicados: Status header "Designed"→**Reviewed**; notas bidireccional/Cross-References actualizadas [dependientes MVP ya tienen GDD]; `AC-T22b` cruce de año; AC-T33 hardware → Open Q). Calendario semanal verificado **internamente consistente** (regla 7 ↔ AC-T20/T22 ↔ knob `jornadas_por_mes` ↔ UI ↔ Interacciones). Log: `time-system-review-log.md`.
- ✅ **Datos #2** (re-revisión) — **APPROVED** (0 bloqueantes; 5 recom consistencia + 1 nice + 1 decisión de diseño). Barridos residuos del catálogo 8→13 denuncias (dur 28→30 en F8; conteo 8→13; pacing 110→40 reconciliado con Economía); metadatos→Reviewed. **DECISIÓN (realismo, usuario): denuncias SIN cita** (`admite_cita=false` en las 13; la cita previa #14 aplica solo a Documentación); **"atención especial = favor del comisario" → #16** (anotado en índice); **propagado a ODAC #9** (OD9 + Open Q7). Log: `data-config-review-log.md`.
- 🎉 **BLOQUE A COMPLETO (3/3 re-revisiones).** Economía, Tiempo, Datos re-aprobados.
- ✅ **BLOQUE B — Paciencia #10** (1ª revisión) — **APPROVED** (0 bloqueantes; 3 recom + 4 nice). Nice aplicados (clamps F1/F5, nota bidireccional, nota pesos). **DECISIÓN de alcance (usuario 2026-07-22): ascenso a Inspector = 1 año (48 jornadas) + valoración jefes ≥75% + curso, evaluado SOLO en enero → post-MVP (#18/#28/#29); en el MVP la valoración de jefes es el marcador que da consecuencia a ODAC.** Open Q3 actualizada. Log: `patience-satisfaction-review-log.md`. **Pendientes para más adelante:** (rec.2) verificar solapamiento `puntuacion_visita`↔`reputacion_aporte` al revisar **ODAC #9**; (rec.3) telegrafiar origen de reclamaciones en **Feedback #12**.
- ✅ **Flujo #4** (1ª revisión) — **APPROVED** (0 bloqueantes; 1 recom menor + 2 nice aplicados: nota `ρ` con capacidad=0 en F4; Status header In Design→**Reviewed**; nota bidireccional actualizada). GDD **ejemplar** (bottleneck; 7 fórmulas, 27 AC, edge cases exhaustivos). Log: `flow-queues-review-log.md`.
- ✅ **ODAC #9** (1ª revisión) — **NEEDS REVISION (leve) → RESUELTO**. **Reconciliación clave (rec.2 de Paciencia RESUELTO):** ODAC ya NO calcula reputación propia (retiradas F1/F2 `reputacion_aporte`/`penalizacion` + knobs `base_reputacion`/`base_abandono`); **Paciencia posee la escala 0–100 —que penaliza la espera—, ODAC solo aporta `peso_prioridad` 2.5** (opción A del usuario). Registrado `peso_prioridad_prioritaria` en `entities.yaml`; corregido Paciencia PS6. Eliminada UI duplicada; nice (metadatos, `admite_cita`). Log: `odac-review-log.md`.
- ✅ **Demanda #5** (1ª revisión) — **APPROVED** (0 bloqueantes; 1 recom + 3 nice aplicados: reconciliado `mult_dia_semana` [quitado "lunes/sábado", coherente con calendario semanal]; metadatos→Reviewed; nota bidireccional; quitado `admite_cita` de F3). **Verificación numérica impecable** (mezcla 13 tipos → 29,75 exacto, cuadra con throughput 32/128). Log: `demand-generation-review-log.md`.
- ✅ **Personal #6** (1ª revisión) — **NEEDS REVISION (leve) → RESUELTO**. **Reconciliación clave:** F3 producía `bonus_satisfaccion` aditivo (±10) incompatible con Paciencia F2 → reescrito como **`factor_trato` multiplicador (0.5–1.5, Trato 3=1.0)**; `k_trato` 5→0.25; **renombrado `bonus_satisfaccion`→`factor_trato` propagado en 4 GDD** (staff/patience/flow/index). Eliminada UI duplicada; nice (`k_motivacion`, F4 clamp, metadatos). Log: `staff-agents-review-log.md`.
- ✅ **Construcción #7** (1ª revisión) — **APPROVED** (0 bloqueantes; 1 recom estructural + 3 nice aplicados: eliminada UI duplicada; metadatos→Reviewed; Open Q3 reconciliación con Datos→**Resuelta**; nota bidireccional). GDD ejemplar (construcción libre; F5 `puestos_utiles`=5 cuadra con Demanda/Flujo). Log: `construction-layout-review-log.md`.
- ✅ **Documentación #8** (1ª revisión) — **APPROVED** (0 bloqueantes; 2 recom + 2 nice aplicados: eliminada UI duplicada; **2 reconciliaciones obsoletas cerradas** [nota Interactions + Open Q4: ventana 08:00 + calendario semanal ya aplicados]; residuo "sábados/domingos" reformulado; metadatos→Reviewed). Log: `documentation-review-log.md`.
- ✅ **UI/HUD #11** (1ª revisión) — **APPROVED** (0 bloqueantes; 1 recom + 1 nice aplicados: reconciliados nombres de tabs en Player Fantasy [Empleados→Funcionarios, +Servicios]; metadatos→Reviewed). Capa de presentación limpia (consume, no define). Log: `ui-hud-review-log.md`.
- ✅ **Feedback #12** (1ª revisión) — **APPROVED** (0 bloqueantes; 1 recom + 1 nice aplicados: telegrafiar origen de reclamaciones [cierra pendiente de Paciencia #10]; metadatos→Reviewed). Glow 4.6 y bus de eventos bien capturados como Open Q para arquitectura. Log: `feedback-juice-review-log.md`.
- 🎉🎉 **FASE 1 COMPLETA — 12/12 GDD revisados y APPROVED.** Bloque A (3 re-revisiones: Economía/Tiempo/Datos) + Bloque B (9 primeras revisiones). **3 reconciliaciones de interfaz resueltas** (denuncias sin cita; reputación ODAC→Paciencia posee; `bonus_satisfaccion`→`factor_trato` multiplicador). **2 decisiones de diseño capturadas** (denuncias sin cita → atención especial = favor del comisario #16; mecanismo de ascenso anual: 1 año + valoración jefes ≥75% + curso, solo en enero). 1 conflicto de consistencia cazado y resuelto (throughput ODAC en Flujo L227).
- ✅ **`/consistency-check` 13ª hecho** (2026-07-22): 2 residuos de identificadores retirados en ODAC resueltos; **los 12 GDD consistentes**.
- ✅ **Fase 2: `/review-all-gdds` HECHA** (2026-07-22) — **Verdict CONCERNS (0 blockers).** Consistencia PASS (las reconciliaciones de la Fase 1 limpiaron el terreno; cadenas de fórmulas impecables). **2 warnings de teoría de diseño:** **W1** carga cognitiva ~4-5 sistemas activos (mitigado: Oficial/pausa/revelación progresiva; a playtest); **W2** potencial estrategia dominante Doc>ODAC si la valoración de jefes no pesa en el MVP (→ al definir el objetivo del MVP, que ODAC importe). **1 nota para arquitectura:** orden de handlers de `nuevo_dia`/`nuevo_mes` (ADR bus de eventos). **0 GDD marcados para revisión.** Informe: `design/gdd/gdd-cross-review-2026-07-22.md`.

## Session Extract — /review-all-gdds 2026-07-22
- Verdict: CONCERNS (0 blockers)
- GDDs reviewed: 12
- Flagged for revision: None
- Warnings: W1 (carga cognitiva ~4-5 sistemas activos → playtest) · W2 (estrategia dominante Doc>ODAC → dar peso a la valoración de jefes en el objetivo del MVP)
- Nota arquitectura: orden de handlers `nuevo_dia`/`nuevo_mes` → ADR bus de eventos
- Recommended next: /gate-check pre-production
- Report: design/gdd/gdd-cross-review-2026-07-22.md

- ✅ **Fase 3: `/gate-check` HECHO** (2026-07-22) — gate **Systems Design → Technical Setup: PASS** (0 blockers; 4 directores READY; chain-of-verification sin cambios). **Etapa avanzada a `Technical Setup`** (`production/stage.txt`). Reporte: `production/gate-checks/gate-2026-07-22-systems-design-to-technical-setup.md`.
- 🔄 **EN CURSO — Fase 4: `/create-architecture`** (Fase 0 hecha: contexto motor + knowledge gap).
  - ✅ **FORMACIÓN EN GODOT 4.6** (2026-07-22, vía web oficial; biblioteca de referencia actualizada): verificados los dominios 2D de Comisario y volcados en `docs/engine-reference/godot/`. **Hallazgo: la mayoría de HIGH-risk de 4.6 son de 3D (Jolt/IK/glow 3D) → NO afectan a este 2D.** Módulos NUEVOS: `tilemap-2d.md`, `save-load.md`, `patterns.md`; enriquecidos `navigation.md` + `rendering.md`; `VERSION.md` Last Docs Verified→2026-07-22.
  - **Decisiones técnicas ya desbloqueadas por la formación:** (a) **glow real DESCARTADO en 2D** → mood con CanvasModulate+Light2D, dorado del ascenso con animación de sprite (resuelve Feedback #12 OpenQ2 — ya NO necesita ADR); (b) **save de partida = JSON/ConfigFile en `user://`, NO custom Resources** (seguridad + issue conocido de ResourceSaver 4.6); el **catálogo** de Datos = `.tres`; (c) **rejilla = `TileMapLayer`** (`TileMap` deprecado); (d) **pathfinding NPCs = NavigationServer2D/NavigationAgent2D** (gotcha: fijar target tras el 1er physics frame); (e) **bus de eventos = autoload + signals**, con orden de handlers determinista vía dispatcher (ADR).
  - ⏳ **Pendiente de la arquitectura:** Technical Requirements Baseline (extraer TRs de los 12 GDD) → mapa de capas → module ownership → data flow → API boundaries → ADR audit → escribir `docs/architecture/architecture.md` → lista de ADRs a crear.
  - 🔄 **RITMO ELEGIDO (2026-07-22): 3 BLOQUES** con aprobación por bloque. **✅ BLOQUE 1 (Estructura)** en `architecture.md` v0.1: TR Baseline (~70 TRs, 6 decisiones transversales), mapa de capas (Foundation+▸EventBus/▸SaveManager/▸RNGService / Core / Feature / Presentation), propiedad de módulos (14 módulos). **✅ BLOQUE 2 (Comportamiento) ESCRITO:** Data Flow (bucle de simulación, bus+orden handlers, save/load, orden init) + API Boundaries (EventBus/RNGService/SaveManager/Tiempo/Datos/gates Economía/Flujo). **2 decisiones capturadas: D1** (simulación en `_physics_process`, paso fijo → determinismo + NavigationAgent2D) y **D2** (dispatcher explícito para eventos ordenados nuevo_dia/nuevo_mes). **✅ BLOQUE 3 (Cierre) ESCRITO:** ADR audit (0 previos → 4 nuevos) + trazabilidad 100% (0 gaps) + 5 principios + 4 Open Questions (QQ-01..04) + **sign-off TD: APPROVED WITH CONDITIONS**.
- 🎉🎉 **`/create-architecture` COMPLETO — `docs/architecture/architecture.md` v1.0** (TD APPROVED WITH CONDITIONS; LP omitido por LEAN). **Fase 4 de la Ruta A cerrada.**
- **4 ADRs a crear (Foundation primero):** **ADR-0001 Bus de eventos+tick+orden [D1/D2] — ✅ ESCRITO 2026-07-22 (Proposed, `adr-0001-bus-de-eventos.md`)**; decisión de orden = **registro con prioridad en el bus** (bus no conoce los sistemas); verificado con doc oficial Godot (`_physics_process` delta fijo + event bus = práctica recomendada). · **ADR-0002 Guardado/serialización+RNG — ✅ ESCRITO 2026-07-22 (Proposed, `adr-0002-guardado-serializacion.md`)**: JSON en `user://`, patrón `save()`/`load_state()` vía grupo `Persist` (respeta la regla "Foundation no llama por nombre"), serializa el RNG; guardar plano = JSON con `Vector2i`→`{x,y}`; riesgo de seguridad de `.tres` verificado con web (ejecución de código). · **ADR-0003 Formato del catálogo — ✅ ESCRITO 2026-07-22 (Proposed, `adr-0003-formato-catalogo.md`)**: catálogo en `.tres` Resources tipados (editor visual, sin parsear, práctica recomendada verificada con web); referencias por `id` (NO Resources anidados → evita `duplicate_deep` 4.5); read-only (instancias aparte); resuelve QQ-01 / Datos OpenQ#8. · **ADR-0004 Rejilla+navegación 2D — ✅ ESCRITO 2026-07-22 (Proposed, `adr-0004-rejilla-navegacion-2d.md`)**: cuadrícula=`TileMapLayer`; caminar=`NavigationServer2D`+`NavigationAgent2D` (mesh; **avoidance experimental en 4.6 → OFF/mínimo**; gotcha: fijar target tras 1er physics frame); puestos=`PackedScene` (no tiles); **movimiento COSMÉTICO separado de la lógica determinista (Flujo FL5)** → protege el determinismo; QQ-02 (spike de rendimiento nav 2D) queda para el vertical slice; plan B = AStarGrid2D. **🎉🎉 LOS 4 ADRs previstos ESCRITOS (todos Proposed).** **Verificados con web oficial Godot** (physics_process, event bus, seguridad .tres, Custom Resources, TileMapLayer, NavigationAgent2D avoidance experimental). Libro de normas (`docs/registry/architecture.yaml`) poblado. **Nota: usuario principiante — todos los ADRs explicados en llano con analogías + verificación web.**
- **PENDIENTE PARA GATE pre-production:** (1) marcar los 4 ADRs `Accepted` (ahora Proposed); (2) `/architecture-review` en **SESIÓN NUEVA** (no en esta — imparcialidad); (3) `/create-control-manifest`; (4) `/test-setup`; (5) `/ux-design`. Luego `/gate-check pre-production` → Pre-Production → `/vertical-slice` (1er build jugable — **AVISAR al usuario**; ahí corre el spike QQ-02). **Condición del sign-off:** escribir+aceptar 0001/0002/0003 antes de codificar gameplay; spike de rendimiento nav 2D (QQ-02) en el vertical slice. **Nota usuario 2026-07-22: es PRINCIPIANTE en lo técnico → explicar cada ADR en lenguaje llano con analogías y verificar dudas técnicas con WebSearch; él decide a nivel "¿tiene sentido para el juego?", el código lo lleva Claude.**
- **PRÓXIMO (orden):** `/architecture-decision` de los 4 ADRs (Foundation primero) → `/architecture-review` (bootstrapea la matriz de trazabilidad + TR registry) → `/create-control-manifest` → `/test-setup` → `/ux-design` → `/gate-check pre-production` → Pre-Production → `/vertical-slice` (1er build jugable — **AVISAR al usuario**).
  - **ADRs previstos:** (1) bus de eventos [+orden handlers], (2) guardado/serialización, (3) formato de datos del catálogo (`.tres` vs JSON — Datos OpenQ8), (4) rejilla/TileMapLayer + navegación 2D. *(Glow ya resuelto sin ADR.)*
- → Fase 5: implementación Godot = 1er build jugable (**AVISAR al usuario**).
**Orden restante (Bloque B):** ✅ COMPLETO (9/9). **Fase 1 entera: 12/12 GDD APPROVED.**
**Pendiente al llegar a ODAC #9:** ya se le propagó la decisión "denuncias sin cita" (OD9 + Open Q7); revisar el resto con normalidad.
**Después de la Fase 1:** `/review-all-gdds` → `/gate-check pre-production` → `/create-architecture` (ADRs: bus de eventos, guardado, glow 4.6, TileMapLayer) → implementación Godot = 1er build jugable (**avisar al usuario**).
**Nota para cuando toque Documentación #8:** su Open Q#4 marca como "reconciliación pendiente (calendario semanal)" algo **ya aplicado** (consistency 6ª) → limpiar esa Open Q obsoleta al revisar #8.

<!-- CONSISTENCY-CHECK: 2026-07-22 | GDDs checked: dirigido (reconciliaciones Bloque B: factor_trato, retiros ODAC, peso_prioridad) | Conflicts found: 2 (resueltos) | Verdict: CONFLICTS FOUND → resuelto -->
✅ `/consistency-check` (2026-07-22, 13ª): **CONFLICTS FOUND (2) → RESUELTO**. Blindaje tras cerrar Fase 1. (a) Renombrado `bonus_satisfaccion`→`factor_trato` **limpio** (0 restos en GDD activos, solo en review-log histórico). (b) `peso_prioridad_prioritaria` 2.5 **consistente** en ODAC/Paciencia/registro. (c) **2 residuos** de identificadores retirados en ODAC (`base_abandono`/`base_reputacion` en Interacciones-knobs L301 y Open Q1 L376) → **corregidos**. Registrado en `docs/consistency-failures.md`. **Los 12 GDD consistentes tras las reconciliaciones del Bloque B.**

<!-- CONSISTENCY-CHECK: 2026-07-22 | GDDs checked: dirigido (admite_cita en 6 GDD + throughput ODAC) | Conflicts found: 1 (resuelto) | Verdict: CONFLICTS FOUND → resuelto -->
✅ `/consistency-check` (2026-07-22, 12ª): **CONFLICTS FOUND (1) → RESUELTO**. Tras re-revisar Datos #2: (a) `admite_cita=false` en las 13 denuncias **consistente** en todos los GDD (Datos F2/R5/Tuning, ODAC OD9/Open Q7 propagados; Demanda/Documentación/Flujo solo usan `requiere_cita` de Doc) — 0 restos de "todas admiten cita". (b) **1 conflicto**: `flow-queues.md` L227 conservaba `dur ODAC ≈28 → 34/día` (valores de 8 tipos) contra L237/Datos F8/registro (`30 → 32 → 128`); **corregido** a `30→32`. Registrado en `docs/consistency-failures.md`. 0 conflictos restantes.

<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 5 (foco ediciones Economía: economy/patience/demand/documentation/ui + time) | Conflicts found: 0 | Verdict: PASS -->
✅ `/consistency-check` (2026-07-21, 11ª): **PASS** — verificadas las ediciones de claridad de Economía. Contrato `sat=sat_cierre_doc` consistente (Economía AC-E03b ↔ Paciencia AC-PS14, misma propiedad, ejemplos 40/50 ambos válidos); calendario semanal `jornadas_por_mes=4` / "Mes·Semana N" alineado en 5 GDD (Tiempo dueño); salarios 60/70/190 y knobs económicos sin divergencias. 0 stale (no se tocaron valores). Nota: Doc #8 Open Q#4 obsoleta (calendario ya reconciliado) → limpiar al revisar #8.

<!-- histórico -->
✅ **COMPLETO: GDD Feedback y Juice** (`design/gdd/feedback-juice.md`, Status: *Designed*). **12º y ÚLTIMO** sistema
MVP (#12, UI/Presentación). Skeleton creado (2026-07-21). Capa que responde a **eventos** y da **game feel** (distinta
de UI #11 que muestra estado). **Directriz usuario: juice TIPO TYCOON** (números flotantes, notificaciones, emotes de
ánimo, remates de objetivo) pero con **piel sobria CNP** (art bible §1.2 "autenticidad contenida, no espectáculo";
anti-Two Point Hospital de TONO, sí de estructura). Usa art bible §2 (mood por estado) + §4 (color semántico). Godot:
Tween/AnimationPlayer/CanvasModulate/partículas sutiles/audio mínimo; ⚠️ verificar glow reworkeado en 4.6. Audio MÍNIMO
(preferencia fija). Depende de eventos de todos los sistemas + UI #11 + art bible✅. **Al cerrarlo → MVP 12/12 diseñado.**
**Decisiones:** números flotantes **solo +€** (costes vía HUD); vida ambiental **MVP mínimo** (idle básico); **mood por
estado** = mañana/noche/fracaso/menús (dilema/ascenso = hooks #16/ascensos). 4 canales (visual puntual/audio/ambiental/HUD);
juice budget anti-saturación + intensidad por importancia; accesibilidad (nunca solo color/sonido; audio desactivable).
**Hecho: Overview✅ · Player Fantasy✅ · Detailed Design✅ (FB1–FB13 + vocabulario).** Pendiente: Formulas · Edge · Deps ·
Tuning · V/A · UI · Acceptance · OQ.

<!-- histórico -->
✅ **COMPLETO: GDD UI/HUD de Gestión** (`design/gdd/ui-hud.md`, Status: *Designed* — pendiente `/design-review`).
11º sistema MVP (**11/12**). Las **11 secciones escritas**. HUD persistente + **5 tabs (Comisaría · Funcionarios ·
Servicios · Valoraciones · Despacho del Comisario)**; Construcción/Asignación = modos sobre la vista; config servicios
híbrida; **registro de pantallas data-driven desbloqueable por rango** (Pilar 3; lo de rango superior NO se enseña —ni
"próximamente"— hasta desbloquear). UI **solo lee + emite órdenes** (no muta). F1–F4 = mapeos de color (referenciados +
umbrales UI propios 40/70). **Sin reconciliaciones Fase 5** (la UI consume, no define cross-facts; todos los GDD ya la
listan como dependiente). Registro: `umbral_holgura_ui` referenced_by += ui-hud. **Respondido al usuario:** prueba jugable
llega en implementación (tras #12); existe prototipo HTML; se puede adelantar un vertical slice si lo pide.
**PRÓXIMO: Feedback y Juice #12** (12º y ÚLTIMO MVP) → cierra el diseño MVP **12/12**.

<!-- histórico -->
🚧 (cerrado) **GDD UI/HUD de Gestión** (`design/gdd/ui-hud.md`). 11º sistema MVP (#11, UI).
Skeleton creado (2026-07-21). **Agregador de presentación:** NO posee valores de juego, los muestra. **Decisiones:**
HUD persistente (reloj/fecha/velocidad·saldo·sat·objetivo·avisos) + **5 tabs tycoon: Comisaría · Funcionarios ·
Servicios · Valoraciones · Despacho del Comisario**; Construcción/Asignación = **modos sobre la vista**; config de
servicios **híbrida** (horario Doc global en Servicios; reconfig ODAC contextual en el puesto); **registro de pantallas
data-driven y desbloqueable por rango** (Pilar 3 — Jefatura Superior/brigadas futuro #18/#19/#26). UI solo lee+emite
órdenes (no muta); daltónico. Godot Control+CanvasLayer; ratón sin hover-only. **Hecho: Overview✅ · Player Fantasy✅ ·
Detailed Design✅ (UI1–UI15).** Pendiente: Formulas · Edge · Deps · Tuning · V/A · UI-Req · Acceptance · OQ.
**NOTA usuario: pidió aviso de cuándo se puede probar jugable → respondido (llega en fase de implementación tras #11/#12;
existe prototipo HTML; se puede adelantar un vertical slice si lo pide).**

<!-- histórico -->
✅ **COMPLETO: GDD Paciencia y Satisfacción** (`design/gdd/patience-satisfaction.md`, Status: *Designed* —
pendiente `/design-review`). 10º sistema MVP (**10/12**). Las **11 secciones escritas**. **Reconciliación Fase 5
APLICADA (2026-07-21):** (a) Economía concreta `sat`=`sat_cierre_doc` (media cerrada jornada anterior; ya no
"provisional") en regla de propiedad/E7/F1/interacciones/deps/OpenQ1; (b) Datos +`tramite_reclamacion` (ODAC,
30min, Normal, sin tarifa, origen Paciencia PS13); (c) ODAC nota carga variable (F3/interacciones/deps, sin tocar
R5 base); (d) Demanda nota (carga de Paciencia, no del generador); (e) registro (+`sat_inicial 50`,
+`prob_reclamacion 0.4`, +entidad `tramite_reclamacion`, referenced_by aforos/retorno_dgp). **CONVIENE
`/consistency-check`.** **PRÓXIMO: UI/HUD de Gestión #11** (11º MVP), luego Feedback y Juice #12 → cierra MVP 12/12.

<!-- histórico Paciencia (diseño) -->
🚧 (cerrado) **GDD Paciencia y Satisfacción** (`design/gdd/patience-satisfaction.md`). 10º
sistema MVP (#10, Gameplay). Skeleton creado (2026-07-21). **Sistema pieza central:** dueño de la escala
**`sat` (0–100)** que Economía (retorno_dgp: min 0.15/max 0.45) y ODAC (reputación) ya referencian como
provisional; dueño de la **curva de paciencia** por persona (Flujo ejecuta el abandono al llegar a 0). Depende
Flujo✅/Tiempo✅. Downstream: Comodidades #15 (amplía paciencia), Valoración jefes #28, UI #11, Feedback #12.
Aforo (Datos 40/10) y espera (Flujo F5) alimentan la paciencia. **Decisiones:** satisfacción **por servicio**
(Doc→dinero, ODAC→reputación; global solo HUD); paciencia **base común + modificadores** (hacinamiento/comodidad);
**cierre diario** de la media → fija el multiplicador de ingresos de la jornada SIGUIENTE (dinero estable
intra-día); `sat_inicial=50` ambos el 1er día. **Hecho: Overview✅ · Player Fantasy✅ · Detailed Design✅
(PS1–PS11) · Formulas✅ (F1 drenaje · F2 puntuacion_visita · F3 media/cierre · F4 ref Economía · F5 global).**
**NUEVO — Hoja de reclamaciones (PS12/PS13):** cada abandono suma al contador `reclamaciones` (eficiencia + valoración
#28, indep. de sat; Prioritarias ODAC = grave). **Bucle:** abandono de Documentación con `prob_reclamacion`=0.4 genera
un trámite `reclamacion` (Normal, 30 min, sin tarifa) en ODAC → puede saturarla (Doc mal llevada contamina ODAC); sin
recursión; carga autoinfligida (no toca R5 base). **Hecho: …Edge Cases✅.**
**⚠️ Reconciliar Fase 5:** (1) Economía `retorno_dgp` usa `sat_cierre_doc` de la jornada anterior (hoy "sat provisional");
(2) Datos +tipo `reclamacion` (ODAC, 30 min, Normal, sin tarifa); (3) ODAC nota carga variable por reclamaciones + R5;
(4) Demanda nota: ODAC recibe carga extra de Paciencia (no del generador). Pendiente: Deps · Tuning · V/A · UI · Acceptance · OQ.

<!-- histórico -->
✅ **COMPLETO: GDD ODAC / Denuncias** (`design/gdd/odac.md`, Status: *Designed* — pendiente `/design-review`).
9º sistema MVP (**9/12**). Las **11 secciones escritas**. ODAC **24h**; MVP = denuncias de ciudadanos
(detenidos/abogados = #17 V-Slice). **13 denuncias** (4 Prioritarias: VioGén/Desaparecidos/Agresión sexual/Robo
violencia; 9 Normales). **ODAC no genera €** → rinde **reputación** (F1 `reputacion_aporte = base × peso_prioridad
2.5 × factor_trato`; F2 penalización por abandono) que alimenta retorno DGP + valoración #28 (los consume
Paciencia #10). Mecánicas: **prioridad** (Flujo F7), **reconfiguración en caliente** de puestos (4 modos), 24h.
**✅ RECONCILIACIONES FASE 5 APLICADAS (2026-07-21):** (a) mezcla Demanda F3 redistribuida a **13 tipos**
(Normales 0.87 / Prioritarias 0.13; ejemplo tuning corregido DNI 0.45); (b) **`mult_nocturno_odac`** (default 0.5,
rango 0.2–1.0, **escalable con población**) reemplaza el "~10 fijo" en Demanda (Overview/régimen/F2/AC-DM04/OQ5/
Tuning) + Tiempo (regla 6/Deps) + **registro** (constante nueva, source Demanda; Flujo NO lo referenciaba);
(c) duración media ponderada validada = **29,75 ≈ 30 min** → throughput ODAC **~32/puesto**, 4 puestos **~128/día**
≥ 36 (R5 ×3,5); actualizados ODAC F3/AC-OD12 y notas de registro (throughput_puesto, aforo_odac, tasa_base_odac).
**PRÓXIMO: `/consistency-check`** (verificar el paquete ODAC), luego **`/design-system` Paciencia y Satisfacción #10**
(10º MVP; consume la reputación de ODAC y la satisfacción que modula retorno DGP). `/design-review` de los 6 GDD
Designed pendientes en sesión NUEVA.

<!-- histórico -->
✅ **COMPLETO: GDD Documentación** (`design/gdd/documentation.md`, Status: *Designed* —
pendiente `/design-review`). 8º sistema MVP (8/12). Las 11 secciones escritas. **División de Documentación**
(órgano superior) + **slider de horario** (08:00–14:30 base, ampliable a 20:00 con peonada) + **peonada voluntaria
motiva+cansa vs última admisión tardía desmotiva** (margen 15) + **eventos estacionales** (vacaciones→Pas 21:30,
extranjería→TIE, catálogo crece con DG11) + **perfil estacional anual** (DG13 añadido a Demanda: verano/Navidad
ALTA, Ene-Feb BAJA). **Próximo: `/design-review documentation.md` sesión NUEVA.**
**✅ RECONCILIACIONES APLICADAS (2026-07-21):** (a) ventana 08:00–14:30 en Demanda(F2/DG6/F5/AC)+Flujo(F2/F3/AC:
throughput Doc **26**, cap **260**); (b) calendario Tiempo #1 (regla 7 reescrita + knob `jornadas_por_mes=4`;
jornada=semana; "Mes·Semana N"; notas en Economía E6 y Demanda F2); (c) registro (+`jornadas_por_mes`,
+`margen_ultima_admision_min`, +referenced_by peonada/trámites). **Conviene `/consistency-check` para verificar.**

<!-- histórico -->
✅ **COMPLETO: GDD Documentación** (`design/gdd/documentation.md`, Status: *In Design*). 8º
sistema MVP (#8, Feature). Skeleton creado (2026-07-21). Primera de capa Feature; **todas las upstream cerradas**
(Flujo/Personal/Construcción/Economía✅). **Decisiones:** horario base **09:00–14:30** L-V; **2 palancas de
horario:** (1) **apertura 08:00 con peonada** (coste €, rentable según demanda DG12); (2) **última admisión
configurable** (`margen_última_admisión`: 14:15 personal a su hora vs 14:30 más ingresos pero **descontento/−
Motivación** por salir tarde — SIN peonada, el coste es moral; paralelo "crunch" de tycoons). MVP **sin cita**
(requiere_cita=false; #14 lo activa). Efecto de motivación conecta con Personal/Bienestar #13/#15.
**REFINADO con el usuario:** **División de Documentación** (órgano superior) fija horario base y manda eventos;
**slider de horario base 08:00–14:30 ampliable a 20:00** (horas extra = peonada); **peonada voluntaria = motiva
+ cansa** vs **última admisión tardía = desmotiva**; **eventos estacionales** (vacaciones→Pasaporte 21:30,
colapso extranjería→TIE) ligados a Demanda DG11 (catálogo crece; MVP 1-2). **Hecho: Overview✅ · Player
Fantasy✅ · Detailed Design✅** (DO1–DO12). **⚠️ Reconciliación pendiente (Fase 5): (a) ventana base 08:00–14:30 en
Demanda (pico 08:00, ~390min) y Flujo (throughput Doc ~26/día); (b) CALENDARIO de Tiempo #1 (decisión usuario
2026-07-21): knob `jornadas_por_mes=4`, cada jornada de 24h = **1 SEMANA** de calendario → 4 semanas = 1 mes,
48 jornadas = 1 año; fecha mostrada como "Mes · Semana N" (N=1..4); `nuevo_mes` cada 4 jornadas; Economía cierra
objetivo mensual cada 4 jornadas; el `mult_dia_semana` de Demanda F2 se reinterpreta (cada jornada = carga media
semanal, no "lunes/martes"). El reloj 24h interno NO cambia (hora/turnos/horario Doc 08:00-14:30 siguen).** Pendiente: Formulas · Edge · Deps · Tuning ·
Visual/Audio · UI · Acceptance · Open Questions.

<!-- histórico -->
✅ **COMPLETO: GDD Construcción y Distribución** (`design/gdd/construction-layout.md`, Status: *Designed* —
pendiente `/design-review`). 7º sistema MVP (7/12). Las 11 secciones escritas. **Construcción LIBRE estilo
Theme Hospital**: rejilla, edificio fijo, salas de tamaño libre (arrastrar, coste por área F1), puestos/objetos
dentro, **aforo por asientos** (F3), **puestos ILIMITADOS** (F5 la demanda manda: puestos_utiles=ceil(pico/
throughput); de más = ociosos), mover gratis/demoler 50% (F4). **Reconciliación con Datos PENDIENTE de aplicar**
(tope_construible→referencia dimensionado, aforo_espera→referencia). Objetos (mobiliario/luces/papeleras) →
detalle en Comodidades #15; retos por comisaría → #26. **Próximo: `/design-review construction-layout.md` sesión
NUEVA.**

<!-- histórico -->
🚧 (cerrado) GDD Construcción y Distribución (`design/gdd/construction-layout.md`, Status: *In Design*). 7º
sistema MVP (#7, Core). Skeleton creado (2026-07-21). **Modelo decidido: construcción LIBRE estilo Theme
Hospital** — edificio de tamaño fijo (Pozuelo, una planta), **salas de tamaño libre** (arrastrar), objetos/
puestos dentro, **aforo por asientos** (no fijo), **SIN topes rígidos** (límite = espacio + presupuesto).
**Reconciliación pendiente con Datos** (al cerrar): `tope_construible` → límite físico del edificio (no cupo);
`aforo_espera` 40/10 → referencia (aforo real = asientos, Comodidades #15). R5 se mantiene por el espacio.
Depende Datos✅/Economía✅; upstream de Flujo✅/Personal✅. **Hecho: Overview✅ · Player Fantasy✅ · Detailed
Design✅** (CO1–CO12: rejilla+edificio fijo, salas tamaño libre, puestos/objetos dentro, aforo por asientos,
gate coste, sin topes rígidos, mover/demoler con %, instantáneo). **Pendiente: Formulas · Edge Cases · Deps ·
Tuning · Visual/Audio · UI · Acceptance · Open Questions.**

<!-- histórico -->
✅ **COMPLETO: GDD Personal / Agentes** (`design/gdd/staff-agents.md`, Status: *Designed* — pendiente
`/design-review`). 6º sistema MVP (6/12). Las 11 secciones escritas. Agentes individuales (nombre/tipo/rango
Policía/Oficial + 4 atributos ⚡🤝❤️🔥 + 🎖️Mando); mercado de candidatos (mejor=más caro, F1 base×prima);
asignación (gate FL4); ausencias (F4 por Salud, RNG sembrado); Oficial = cobertura (F6) + canalización (F7)
por Mando; Motivación base (fatiga diferida). **Ajuste cross-GDD:** `modificador_produccion` extendido a
[0.5,1.3] (agentes lentos) → reconciliado en Flujo F1 + registro. Capturado en índice: Fatiga/Bienestar
(#13/#15), Formación por skill (#29 con coste creciente/retorno decreciente). **Próximo: `/design-review
design/gdd/staff-agents.md` en sesión NUEVA.**

<!-- histórico -->
🚧 (cerrado) GDD Personal / Agentes (`design/gdd/staff-agents.md`, Status: *In Design*). 6º sistema MVP
(#6, Core). Skeleton creado (2026-07-21). **Alcance decidido con el usuario:** agentes individuales
(nombre/tipo/rango **Policía/Oficial**); jugador = Subinspector (jefe); **máx 1 Oficial por servicio**;
**ausencias básicas** (evento de personal, RNG sembrado determinista); **Oficial = cobertura automática +
canalización/batching de incidencias + autoresolución** de lo trivial (middle-management que reduce
microgestión — refs: This Is the Police, Football Manager, Dwarf Fortress, RimWorld); salarios (Oficial >
Policía); modificadores default (Formación #29 los mejora). **DIFERIDO a Horarios #13:** turnos rotativos,
dotación por turno, vacaciones planificadas, guardias. Depende Datos✅/Economía✅; upstream de Flujo✅ (gate
FL4 + duración efectiva). **Hecho: Overview✅ · Player Fantasy✅ · Detailed Design✅** (PA1–PA12; +🎖️Mando
del Oficial como 5º atributo; modelo fatiga/descanso —día libre reset 100%, sala parcial que no sustituye,
cadencia ~3-4:1— DIFERIDO a Bienestar #13/#15 y capturado en el índice; **turnos DESCARTADOS** → modelo
abstracto 1 agente cubre su puesto 24h). **Pendiente: Formulas · Edge Cases · Dependencies · Tuning ·
Visual/Audio · UI · Acceptance · Open Questions.**

<!-- histórico -->
✅ **COMPLETO: GDD Generación de Demanda** (`design/gdd/demand-generation.md`, Status: *Designed* — pendiente
`/design-review`). 5º sistema MVP (#5, Core). Modelo: **tasa por franja + azar acotado (semilla determinista)**.
Redactado en hilo principal (subagentes caídos), modo lean. Las 11 secciones escritas. **Añadidos por el usuario:**
DG11 eventos estacionales (vacaciones→pasaporte/permiso_viaje, satura ODAC puntualmente), DG12 nivel demanda Doc
**BAJA/MEDIA/ALTA** (ligado a rentabilidad de peonada — que NO sea siempre beneficio), perfil nocturno (~10 en
00–07h), mezcla **DNI0.45/Pas0.35/TIE0.20**, `tasa_odac`0.4 < `doc`0.5. Registro ampliado (`demanda_dia_servicio`
+ `tasa_base_doc/odac` + `max_llegadas_por_tick` + 8 referenced_by). **Idea capturada en índice: Comodidades #15**
(paciencia + vending 1€/consumo ~30%, resuelto con RNG sembrado). CD-GDD-ALIGN omitido (lean).
**Próximo: `/design-review design/gdd/demand-generation.md` en sesión NUEVA.**

<!-- histórico -->

<!-- histórico -->
✅ **COMPLETO: GDD Flujo de Personas y Colas** (`design/gdd/flow-queues.md`, Status: *Designed* — pendiente
`/design-review`). 4º sistema MVP (#4, Core, esfuerzo L). Redactado en hilo principal (subagentes caídos), modo
lean. Las 8 obligatorias + Visual/Audio + UI + Open Questions escritas. Registro `entities.yaml` ampliado
(2 fórmulas: `duracion_efectiva`, `throughput_puesto`; +8 `referenced_by`). Índice: 4/12 MVP diseñados.
CD-GDD-ALIGN omitido (lean). **Próximo: `/design-review design/gdd/flow-queues.md` en sesión NUEVA.** **Hecho: Overview ✅ · Player Fantasy ✅ · Detailed Design ✅** (Core Rules FL1–FL10, States
Persona+Puesto, Interactions) **· Formulas ✅** (F1 dur_efectiva · F2 throughput/puesto · F3 capacidad
servicio/R5 · F4 factor carga ρ · F5 espera estimada · F6 aforo/desbordamiento · F7 selección de cola)
**· Edge Cases ✅** (12 casos; regla última admisión + cola exterior sin tope + sin anti-inanición ODAC en MVP)
**· Dependencies ✅ · Tuning Knobs ✅ · Visual/Audio ✅ · UI ✅ · Acceptance Criteria ✅ (AC-FL01–27) · Open
Questions ✅ (9).** GDD COMPLETO. Decisión usuario 2026-07-19: seguir proceso MVP completo (NO atajo a Godot).
Nota: proyecto Godot aún sin inicializar (no hay project.godot).
Decisiones de diseño tomadas: cola = **turno por servicio**, el puesto llama al siguiente compatible
(atenciones_admitidas); aforo lleno → **cola exterior** (entra al liberarse plaza); movimiento **cosmético/corto**
(cuenta esperar+atender); **compromiso de servicio** (en Llamada/En atención ya no abandona → base de la regla de
cierre); `duracion_efectiva = duracion_min × modificador_produccion(agente)`; emite `"trámite completado"` y
`"abandono"`. Provisionales: Demanda #5 (llegadas), Paciencia #10 (curva/abandono), Formación #29 (modificadores).
🆕 Idea capturada: **Formación y Cursos = sistema #29** (Vertical Slice, 2 ramas —producción/velocidad +
atención/satisfacción— de 3 niveles; gancho ya en Overview+Core de Flujo). Interfaces a respetar: emitir
`"trámite completado"` (Economía),
consumir `delta`+pausa (Tiempo), leer `duracion_min`/`tipo_puesto`/`atenciones_admitidas` (Datos). Provisional:
Demanda #5 (llegadas) y Paciencia #10 (curva) sin GDD. Aprendizaje del prototipo: volumen = driver de diversión;
demanda ≠ capacidad.

<!-- histórico -->
✅ **GDD Economía / Presupuesto REVISADO** (`design/gdd/economy-budget.md`, Status: *Reviewed*).
`/design-review` (lean) del 2026-07-19: veredicto **NEEDS REVISION** (3 bloqueantes + 4 recomendados + 3
nice-to-have), **todos resueltos en la misma sesión**. Cambios clave: (1) recargo sobre deuda de apertura
(arregla F6↔AC-E09); (2) **modelo de préstamo cerrado** — coste híbrido (fija 30 + 20% ingresos por préstamo
vivo), **devolución** del principal para cancelarlo, strike no se recupera; (3) **rescate de insolvencia**
pausa+modal+gracia 12 h → inyección auto. Nuevos knobs: `penalizacion_fija_prestamo`, `pct_ingreso_prestamo`,
`ventana_gracia_insolvencia_horas`; deprecado `penalizacion_prestamo_diaria`. Log:
`design/gdd/reviews/economy-budget-review-log.md`. **Los 3 GDDs del MVP hasta aquí quedan revisados (Tiempo,
Datos, Economía).** Próximo: `/consistency-check` y luego `/design-system Flujo de Personas y Colas` (#4).

<!-- histórico previo -->
✅ **GDD Economía / Presupuesto COMPLETO** (`design/gdd/economy-budget.md`, Status: *Designed*, pendiente de
`/design-review`). 3er GDD del MVP (3/12). Las 11 secciones escritas (E1–E9, F1–F8, 19 AC, 9 Open Questions).
Decisiones clave: flujo diario + objetivo mensual · caja inicial + solo retorno DGP · **préstamos del Comisario
(E9: máx 3 + game over)** · deuda con recargo · ingreso instantáneo · regla de cierre (última admisión + peonada).
Pendiente Fase 5: registrar en entities.yaml (7 knobs + fórmula retorno_DGP); índice (status + Tiempo en deps +
nuevo sistema "Valoración de jefes"); luego `/design-review economy-budget.md` en sesión NUEVA.
DECIDIDO: (a) préstamos del Comisario lean en MVP (E9: efectivo + penalización diaria + máx 3 + GAME OVER al arruinarte sin préstamos); "valoración de jefes" = SISTEMA FUTURO a mapear (hook provisional, ligado a Influencia #16/Métricas) → añadir al índice. (b) regla de cierre (última admisión + peonada) capturada en Edge Cases → Open Question para Documentación/Flujo/Horarios.
Decisiones Core Rules: flujo diario + objetivo mensual · caja inicial + solo retorno DGP · DEUDA permitida con penalización (recargo diario + intervención DGP, sin game over) · ingreso instantáneo por trámite.
Nota de alcance del usuario: ingresos/gastos crecen con el rango (Comisario → subvenciones, bonus DGP…) → diferido a Ascensos #18 (Open Questions).

✅ **GDD Datos y Configuración REVISADO** (`design/gdd/data-config.md`, Status: *Reviewed*). `/design-review`
(lean) del 2026-07-19: veredicto **NEEDS REVISION (leve)**; 1 bloqueante + 5 recomendados **resueltos en la
misma sesión** (Escenario semilla completado, aforo Doc 32→40, R5/cita aclarada, `entities.yaml` +14
constantes, AC afinados). Log: `design/gdd/reviews/data-config-review-log.md`.
✅ **GDD Sistema de Tiempo REVISADO** (`design/gdd/time-system.md`, Status: *Reviewed*). `/design-review`
(lean) del 2026-07-19: veredicto **APPROVED** (0 bloqueantes, 1 recomendado advisory sobre la ventana
08:00 vs 09:00 de Documentación, 2 nice-to-have). Log: `design/gdd/reviews/time-system-review-log.md`.
**Los 2 GDDs Foundation del MVP quedan revisados.**
- 8/8 secciones obligatorias + Visual/Audio, UI, Open Questions (9 preguntas abiertas).
- Fase 5 hecha: registrados en `entities.yaml` 3 trámites (dni/pasaporte/tie) + 4 constantes
  (peonada_eur_hora=15, retorno_dgp_min=0.15, retorno_dgp_max=0.45, poblacion_pozuelo=90000);
  índice actualizado (2/12 MVP diseñados).
- ⚠️ Subagentes de estudio FALLARON con "API Error: Usage credits required for 1M context"
  (systems-designer, economy-designer, qa-lead). Secciones D/H redactadas en el hilo principal.
  Revisar en `/design-review`. (Contradice la nota previa de que "ya funcionan".)

## Decisiones clave del GDD de Datos
- Alcance **híbrido**: Datos posee esquema + catálogo semilla; los dominios documentan porqué/rangos y apuntan aquí.
- 2 tipos con base común `Atención`: `TramiteDoc` (tarifa) y `DenunciaODAC` (prioridad, sin tarifa). Puesto y Sala separados. Tipo `Escenario` (poblacion, nivel, tope_construible).
- **Invariante R5 anti-colapso**: capacidad máx construible ≥ demanda máx de la población (ODAC no tiene cita general).
- `tarifa_eur` = tasa oficial → va a la DGP; la comisaría recibe `tarifa × retorno_DGP(satisfacción)` con suelo fijo (fórmula=Economía; satisfacción=#10, fuente ODAC).
- Semillas: DNI 12€/12min · Pas 30€/15min · TIE 18€/15min; ODAC viogen 60/estafa 30/robos 30 (resto 15-30); costes puesto 500/500/600/400, salas espera 200; salarios 60/70/65; retorno DGP 0.15–0.45; Pozuelo pob 90000 Nivel1, tope Doc≤8/TIE≤2/ODAC≤4/Ent1, aforo espera 32/10.
- Ajustes del usuario: 2 salas de espera separadas, entrada/seguridad, niveles de comisaría (Pozuelo=Nivel1 Local; Usera futuro).
- Ideas ancladas para GDDs posteriores (→ Open Questions): demanda evolutiva+picos (Demanda); dinero no trivial/expansión gradual + rentabilidad de peonadas (Economía); satisfacción→retorno DGP (Satisfacción#10); comodidades asientos calidad/deterioro (#15); arco+seguridad interna+hechos aleatorios (sistema futuro).

- (Anterior) ✅ GDD Sistema de Tiempo (`design/gdd/time-system.md`, *Designed*, pendiente /design-review).

## Decisiones clave del GDD de Tiempo
- Tiempo real con pausa. Velocidades: Pausa / 1× / 2× / 3×.
- `escala_tiempo` = **4** (rango 3–12) min-juego por seg-real. Día de 24h = 6 min a 1×. Retuneable.
- Turnos reales CNP: **Mañana 07–15 · Tarde 15–23 · Noche 23–07**. ODAC 24h; Documentación diurna.
- Carga de partida → arranca en **Pausa (0×)**. Reloj = fuente única de tiempo.
- Nota de dominio **ODAC** (24h; atestados/declaración/abogado; muchos tipos de denuncia) y **horarios
  reales** (a turnos / complementario / guardias) guardadas en `systems-index.md`.

## Hecho en esta sesión (histórico)
- ✅ Plantilla CCGS + GitHub `rdomanu/juego` + Godot 4.6.
- ✅ Concepto (`design/gdd/game-concept.md`).
- ✅ Prototipo HTML validado — PROCEDE (`prototypes/comisaria-flujo-concept/REPORT.md`).
- ✅ Art bible núcleo 1-4 (`design/art/art-bible.md`).
- ✅ Índice de 27 sistemas (`design/gdd/systems-index.md`).
- ✅ **GDD Sistema de Tiempo** (`design/gdd/time-system.md`).

## Orden de diseño MVP
Tiempo ✅ → Datos ✅ → **Economía** (siguiente) → Flujo y Colas → Demanda → Personal → Construcción →
Documentación → ODAC → Paciencia → UI/HUD → Feedback.

## Nota técnica (actualizada)
- ⚠️ **Los subagentes de estudio FALLAN** con "API Error: Usage credits required for 1M context"
  (probado con model=sonnet en systems-designer/economy-designer/qa-lead). Para usarlos habría que
  activar créditos de 1M o forzar contexto estándar. Mientras tanto: **redactar en el hilo principal**.
- Instrucción del usuario: **usar siempre Sonnet 5** cuando toque un modelo Sonnet (cuando vuelvan a funcionar).

## Siguiente paso
1. ✅ Datos · ✅ Tiempo · ✅ Economía revisados · ✅ **Flujo · Demanda · Personal · Construcción · Documentación
   DISEÑADOS (8/12 MVP)**. (Tiempo/Economía tocados por la reconciliación del calendario → conviene re-revisarlos.)
2. **`/consistency-check`** (verificar las reconciliaciones: ventana 08:00, calendario semanal, throughput Doc 26/260).
3. `/design-review` en **sesión NUEVA** de los **5 GDD pendientes**: `flow-queues`, `demand-generation`,
   `staff-agents`, `construction-layout`, `documentation`.
4. Siguiente sistema en orden: **`/design-system ODAC` (#9, Feature)** — denuncias (8 tipos), prioridad (VioGén),
   reconfiguración en caliente de puestos, operativa 24h; **detenidos/abogados** son #17 (V-Slice, fuera de MVP).
5. Pendiente futuro (capturado en índice): **Comisarías/retos por comisaría #26**, **Fatiga/Bienestar #13/#15**,
   **Formación por skill #29**, **Comodidades/objetos #15**, **eventos estacionales/División (catálogo crece)**, #28.

<!-- CONSISTENCY-CHECK: 2026-07-19 | GDDs checked: 2 (data-config, time-system) | Conflicts found: 0 | Verdict: PASS | Report: inline (esta sesión) -->
✅ `/consistency-check` (2026-07-19): **PASS** — Datos ↔ Tiempo consistentes; 26/26 entradas del registro verificadas; migración aforo 32→40 limpia.
<!-- CONSISTENCY-CHECK: 2026-07-19 | GDDs checked: 3 (data-config, time-system, economy-budget) | Conflicts found: 0 | Verdict: PASS | Report: inline (post-revisión Economía) -->
✅ `/consistency-check` (2026-07-19, 2ª): **PASS** — Economía ↔ Datos/Tiempo consistentes tras la revisión; fórmula retorno_dgp (con clamp) y knobs de préstamo (fija 30 · % 0.20 · gracia 12h) alineados en GDD y registro; `penalizacion_prestamo_diaria` deprecada limpiamente.
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 5 (time, data, economy, flow, demand) | Conflicts found: 0 | Verdict: PASS | Report: inline -->
✅ `/consistency-check` (2026-07-21, 3ª): **PASS** — Flujo+Demanda ↔ Datos/Tiempo/Economía consistentes (aforos 40/10, capacidades 220/137, throughput 22/34, población 90000, topes 8/2/4, demanda ODAC 36 dentro de 30–60, fórmulas nuevas sin choques). Goteo nocturno alineado (00:00–07:00) en Demanda+Tiempo.
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 6 (+staff-agents) | Conflicts found: 0 | Verdict: PASS | Report: inline -->
✅ `/consistency-check` (2026-07-21, 4ª): **PASS** — 0 conflictos de valor con Personal añadido. `modificador_produccion` [0.5,1.3] consistente (Flujo F1/Personal F2/registro); salarios 60/70 base consistentes. ⚠️ 2 alineaciones de interfaz recomendadas: (1) Economía suma `salario_dia_efectivo` (Personal F1 base×prima), no valor plano de Datos → alinear E3/F3; (2) Flujo atribuye `modificador_produccion` a Formación, ahora lo computa Personal (Rapidez)+Formación → alinear FL5/EdgeCase/OpenQ (aún dice "2 ramas × 3 niveles"). **[Ambas aplicadas 2026-07-21.]**
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 7 (+construction-layout) | Conflicts found: 0 | Verdict: PASS -->
✅ `/consistency-check` (2026-07-21, 5ª): **PASS** — 0 conflictos con Construcción. Costes 500/500/600/200 consistentes; reconciliación Datos aplicada (tope→referencia F7, aforo→referencia F4); tope como calibración R5 coherente en Datos/Demanda/Flujo. ⚠️ 1 alineación menor: Economía E3 no menciona el reembolso de demolición (Construcción F4) → **aplicada**.
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 8 (+documentation) | Conflicts found: internos (reconciliación parcial) | Verdict: CONFLICTS FOUND -->
✅ `/consistency-check` (2026-07-21, 6ª): CONFLICTS FOUND (internos) → **LIMPIEZA APLICADA 2026-07-21**: Documentación Overview+PlayerFantasy corregidos (08:00 base, peonada = alargar la tarde); restos de ventana 09:00 en Demanda(régimen/tablas/edge/OpenQ7)/Flujo(OpenQ6)/Tiempo(ejemplos 390/480) → 08:00; calendario viejo en Tiempo (F1/AC-T20/AC-T22/UI/Overview/interacciones Horarios) → **modelo semanal** (semana/Mes·Semana N). Grep final: solo quedan restos en review-logs históricos. **8 GDD consistentes.**

<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 12 (+feedback-juice) | Conflicts found: 0 | Verdict: PASS -->
✅ `/consistency-check` (2026-07-21, 10ª): **PASS** — Feedback y Juice #12 cerrado. **MVP 12/12 diseñado.** Cierre limpio:
Feedback consume eventos/valores, no define cross-facts. Verificado: umbrales de ánimo 66/33 consistentes (Feedback ↔
Paciencia PS5 ↔ UI); referencia art bible §2 (mood) / §4 (color) sin choques. Sin reconciliaciones. **12 GDD consistentes.**
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 11 (+ui-hud) | Conflicts found: 0 | Verdict: PASS -->
✅ `/consistency-check` (2026-07-21, 9ª): **PASS** — UI/HUD #11 cerrado (11/12). Cierre **limpio**: la UI consume, no define
cross-facts. Verificado: umbrales de ánimo 66/33 idénticos (UI F2 ↔ Paciencia PS5); `umbral_holgura_ui` 500 consistente
(Economía dueño, UI referencia, registro referenced_by += ui-hud). Bidireccional OK: los 10 GDD de gameplay ya listan
"UI/HUD #11" como dependiente. Sin reconciliaciones. **11 GDD consistentes.**
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 10 (+patience-satisfaction) | Conflicts found: 0 valor (reconciliación de interfaz aplicada) | Verdict: PASS -->
✅ `/consistency-check` (2026-07-21, 8ª): **PASS** — Paciencia #10 cerrado (10/12). 0 conflictos de valor. Interfaz `sat`
**concretada**: `retorno_dgp` usa `sat_cierre_doc` (media cerrada de la jornada anterior) — 0 restos de "sat provisional" en
Economía (regla propiedad/E7/F1/interacciones/deps/OpenQ1 actualizados). Nuevos cross-facts consistentes en 4 GDD + registro:
`tramite_reclamacion` (30 min, ODAC, Normal, sin tarifa, origen Paciencia PS13) en Datos F2 + entidad registrada; `prob_reclamacion`
0.4 y `sat_inicial` 50 registrados; aforos 40/10 y `retorno_dgp` con referenced_by += Paciencia. Carga de reclamaciones marcada
**autoinfligida** (no toca R5 base de ODAC). **10 GDD consistentes.**
<!-- CONSISTENCY-CHECK: 2026-07-21 | GDDs checked: 9 (+odac) | Conflicts found: 6 stale (propagados) | Verdict: PASS (tras propagar) -->
✅ `/consistency-check` (2026-07-21, 7ª): **PASS tras propagar**. Cerrado ODAC #9 (9/12). El cambio de ancla ODAC (dur. media 28→**29,75≈30**, throughput 34→**32**, cap 137→**128**) dejó **6 referencias obsoletas** que la skill cazó y se **propagaron**: Flujo F3 (4×32=128), Demanda F5 + AC-DM12 (128), ODAC Tuning (128), Datos F8 (960/30≈32) + AC-D12 (≈30→128). Nueva constante **`mult_nocturno_odac`** (0.5, escalable) registrada (source Demanda; ref Demanda/ODAC/Tiempo) y sustituye el "~10 fijo". Mezcla ODAC F3 = 13 tipos (Σ=1.0). Registro `last_updated`→2026-07-21. Grep final: 0 restos de 137/34/28 en GDD/registro. **9 GDD consistentes.**
<!-- QA-PLAN: 2026-07-24 | System: sprint-2 (Construccion+Flujo) | Plan written: production/qa/qa-plan-sprint-2.md -->
