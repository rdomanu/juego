# Estado de sesión — activo

*Última actualización: 2026-07-28*

<!-- STATUS -->
Epic: Bienestar #13 (capa Feature)
Feature: Cansancio y sala de descanso
Task: implementado sin cerrar; faltan stories 002-004 y sign-off
<!-- /STATUS -->

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
**✅ const-006 IMPLEMENTADA (2026-07-24) — headless limpio, suite 295/295 exit 0, SIN regresiones:**
construccion.gd: API DE OFICIO (`construir_de_oficio_sala/elemento` — valida pero NO cobra,
coste_pagado 0 [demoler no regala reembolso], id_forzado compat; montaje inválido = aviso ruidoso) +
refactor `_alta_elemento` común + CAPA VISUAL (`montar_visual(tam_celda, desplazamiento)`:
TileMapLayer "Salas" con TileSet por código — un source por TipoSala del catálogo vía obtener_todos,
color por servicio [Doc azul/ODAC naranja/Común gris, esperas apagadas lerp] + etiqueta de nombre;
elementos = PackedScene placeholder EMPAQUETADAS por código (pack + instantiate + map_to_local,
TR-construction-003; puesto caja 0.8 celda con etiqueta nombre, asiento 0.4) · `_refrescar_visual`
redibuja TODO desde el modelo en cada mutación (hooks en _crear_sala/_crear_elemento/demoler_*/
mover/load_state; nunca por frame; sin montar_visual = inerte para tests headless). Main:
**Construcción instanciada ANTES que Personal** (orden de hijos = orden de carga del SaveManager),
`usar_personal` tras crear Personal, `_montar_comisaria_inicial()` de oficio (oficina Doc 6×4 en
(1,1) con doc_1/doc_2 · espera Doc 6×4 con 8 asientos · oficina ODAC 4×3 con odac_1 · espera ODAC
3×3 con 3 asientos; puestos → Personal por el PUENTE, ya no a mano) + `_dotar_plantilla_inicial()`;
POS_SUELO const compartida; captura → construccion-hud-2026-07-24.png. SIN commit aún; sign-off
conjunto con la 007.
**🔨 const-007 IMPLEMENTADA — VENTANA ABIERTA, SIGN-OFF PENDIENTE (2026-07-24):** getters nuevos en
construccion.gd (`celda_bajo_cursor` [local_to_map del manifiesto; headless → (-1,-1)] ·
`centro_de_celda` · `elemento_en` · `reembolso_de_sala` · `puede_pagar` [preview "sin caja" sin
intentar construir]) + `src/main/modo_construccion.gd` NUEVO (class_name ModoConstruccion, Node2D
andamio: atajo B/botón toggle con atenuador del mundo · barra inferior CanvasLayer con tipos LEÍDOS
del catálogo [Seguridad excluida CO11; asiento de config; ❌ demoler] focus_mode NONE · preview
fantasma ColorRect+Label REUTILIZADOS con guarda de celda/herramienta/arrastre (cero alloc con
cursor quieto) verde/rojo/naranja + TEXTO · dibujar sala arrastrando con área+coste en vivo ·
clic coloca vía construir_* (paga E4) · demoler con ConfirmationDialog de cascada [contenido +
reembolso; cancelar no demuele] · clic dcho/Esc cancela por capas) + Main lo instancia tras el HUD
(nota + "B construcción"). Headless limpio; **suite 295/295, exit 0**; evidencia
`construccion-hud-2026-07-24.md` escrita (sign-off ⬜, conjunto 006+007). SIN commit aún.
**Guion demo:** M1 solar montado (saldo/nómina intactos) · M2 B→ventanilla→preview verde/rojo ·
M3 colocar −500/demoler +250 · M4 arrastrar sala coste en vivo + 1×2 rojo · M5 cascada con diálogo.
**🔧 FEEDBACK 1ª pasada del usuario, CORREGIDO (2026-07-24):** (a) barra de construcción invisible
al pulsar B — bug de anclas (PRESET_BOTTOM_WIDE crece hacia ABAJO fuera de pantalla) → `grow_vertical
= GROW_DIRECTION_BEGIN` en AMBAS barras (gotcha registrado: toda barra anclada abajo necesita grow
BEGIN); (b) panel de info tapaba la comisaría → **HUD REDISEÑADO a barra inferior estilo tycoon**
(petición del usuario, ya aplicada): _crear_hud ahora es PRESET_BOTTOM_WIDE con fila de secciones
(helper _seccion con VSeparator: reloj 24px · velocidad+nota · saldo · demanda · personal), la barra
de construcción se apoya ENCIMA (offset -84 = HUECO_BARRA_INFO), POS_SUELO y 64→24 (mundo despejado).
Headless limpio; ventana RELANZADA con los arreglos (la vieja cerrada con TaskStop).
**🔧 FEEDBACK 2ª pasada, CORREGIDO (2026-07-24):** (c) preview del puesto poco visible → movido a la
CanvasLayer POR ENCIMA del atenuador (sin cámara, coords mundo==pantalla), Panel+StyleBoxFlat borde
3px casi opaco + relleno 0.30 + Label con outline negro; (d) **ENMIENDA de diseño (petición del
usuario): AMPLIAR salas** — `sala_ampliable(tipo, rect)` (unión rectangular EXACTA con sala del
mismo tipo, aporta celdas nuevas, cabe, no pisa otras; en "L" o tipo distinto → sala aparte CO3) +
`coste_ampliacion` (SOLO celdas nuevas, SIN base) + construir_sala fusiona rect (merge) y acumula
coste_pagado; preview "AMPLIAR sala · N celdas · X €". 2 tests nuevos en construccion_pagar_test
(ampliar pegado 120 € + solapado rectangular 100 € con rect final 5×4; tipo distinto/L → sala
nueva). **Suite total: 297/297, exit 0.** Ventana relanzada de nuevo. Sign-off ⬜ pendiente.
**🔧 FEEDBACK 3ª pasada, CORREGIDO (2026-07-24):** "los bancos no se pueden construir" → los botones
Asiento/Demoler quedaban FUERA de pantalla (fila única HBox con nombres largos del catálogo >
1152 px) → `_fila_herramientas` pasa a **HFlowContainer** (envuelve en filas; h/v_separation).
Headless limpio; ventana relanzada. Gotcha UI registrado: toolbars con textos de catálogo →
SIEMPRE flow/scroll, nunca HBox fijo.
**🔧 FEEDBACK 4ª pasada, CORREGIDO (2026-07-24):** "demoler no deja demoler puestos/asientos, solo
salas" → los ColorRect de los placeholders TRAGABAN los clics (mouse_filter STOP por defecto): el
clic sobre un elemento nunca llegaba a _unhandled_input (solo celdas vacías → ruta de sala) →
`caja.mouse_filter = MOUSE_FILTER_IGNORE` en _empaquetar_placeholder. **Gotcha UI registrado: todo
Control DECORATIVO del mundo (ColorRect/Panel de placeholders) debe ignorar el ratón.** Headless
limpio; ventana relanzada.
**🎉🎉🎉 EPIC CONSTRUCCIÓN COMPLETO (2026-07-24, 7/7 + SIGN-OFF ✅ del usuario) — CUARTO MÓDULO
CORE TERMINADO (Economía, Demanda, Personal, Construcción; solo queda FLUJO):** sign-off dado tras
4 rondas de prueba-y-arreglo con ventana ("continúa" tras cerrar la ventana conforme). Suite final
**297/297, exit 0**. Cierre formal: stories 001-007 → Complete con secciones Cierre (001 tamaño
edificio en config · 002 ENMIENDA AMPLIAR salas · 003 puentes e2e · 004 ignorar+AC-CO13 diferido ·
005 round-trip combinado en orden · 006 rediseño HUD tycoon+POS_SUELO 24 · 007 los 4 gotchas de UI);
EPIC.md → Complete; index → Complete; sprint-status: C2-1..C2-3 + const-001..007 = done (TODO el
Must Have del Sprint 2 hecho EL MISMO DÍA de abrirlo); evidencia construccion-hud-2026-07-24.md con
sign-off ✅ y las 4 rondas documentadas.
**✅ C2-4 `/create-stories flujo` HECHO (2026-07-24, aprobado por el usuario):** 8 stories en
`production/epics/flujo/` (001 PersonaFlujo 7 estados+turnos [Logic; ENVUELVE la ficha de Demanda]
· 002 colas F7 FIFO+prioridad+compatibilidad [Logic; sin RNG] · 003 puestos+gate FL4+emparejamiento
menor-id-gana [Int] · 004 atención F1 clamp≥1 + tramite_completado UNA vez + E2E SALDO SUBE [Int;
tick DESPUÉS de Demanda; el viaje NO descuenta trámite] · 005 aforo F6 dentro/fuera por asientos de
Construcción + F2-F5 puras con centinelas -1 [Logic] · 006 compromiso+gestión caliente: cierre/
reconfig pendientes, forzar_abandono API para Paciencia, cierre Doc cruce 870 provisional,
**AC-CO13 vía callable puede_demoler cableado por Main** [Int] · 007 persistencia+AC-FL27
determinismo A-vs-B con save a mitad [Int] · 008 NPCs navegando: bake del layout real, re-bake solo
al cambiar, target tras 1er physics frame, avoidance OFF, FPS≥60, HUD "En cola/Atendiendo", HITO
VISIBLE+sign-off [Visual]). **27/27 AC + AC-CO13.** Interfaces provisionales documentadas (paciencia
stub · cierre Doc → Documentación #8 · minutos_operativos → Horarios · puestos nacen abiertos).
EPIC→In Progress, index, sprint-status expandido (C2-4 done; flujo-001..008 ready-for-dev). SIN
commit aún.
**✅ Stories de Flujo COMMITEADAS (dc578dc, pusheado).**
**✅ flujo-001 + flujo-002 IMPLEMENTADAS + TEST EN VERDE (2026-07-24):** `src/core/flujo/` —
`persona_flujo.gd` (PersonaFlujo RefCounted: ENVUELVE la ficha de Demanda por referencia +
numero_turno + estado [7 constantes] + paciencia stub null + atajos servicio()/tramite_id()) ·
`flujo.gd` (nodo class_name Flujo: TRANSICIONES_VALIDAS const Dictionary tipado [tabla States A;
inválida → aviso sin cambio] · `admitir(ficha)` turnos por servicio crecientes sin reuso ·
`encolar` [Llegando→Esperando dentro; la 005 refinará fuera] · **F7 `elegir_de_cola(servicio,
admitidas)`** PURA: clave mínima (rango_prioridad, numero_turno), solo ESPERANDO_DENTRO elegibles;
`_rango_prioridad`: Doc siempre 1, ODAC por DenunciaODAC.prioridad del catálogo ["Prioritaria"→0] ·
`retirar_de_cola`/`personas_en_cola`) · `config_flujo.gd` (3 knobs propios del GDD:
duracion_desplazamiento_seg 1.5 clamp[0,5] cosmético · habilitar_aging_odac false ·
tope_cola_exterior 0=∞) + `tools/build_config_flujo.gd` → `datos/config/flujo.tres`. Tests
`flujo_persona_turnos_test.gd` **4/4** (FL01 misma referencia · FL02 turnos Doc 1,2,3/ODAC 1,2 ·
máquina válida+inválida+camino fuera→dentro+compromiso-no-es-transición · clamps+.tres) y
`flujo_colas_test.gd` **5/5** (FL03 FIFO puro con cola revuelta · FL04 viogen antes que estafa
[catálogo real] · FL05 tie no llama · FL06 se salta la tie sin adelantarla · bordes).
**Suite total: 306/306, exit 0.**
**✅ flujo-001..002 COMMITEADAS (9cbfe56).**
**✅ flujo-003 IMPLEMENTADA + TEST EN VERDE (2026-07-24):** en flujo.gd — constantes PUESTO_* ·
`_puestos_flujo {puesto_id -> {tipo, abierto, persona, restante}}` (orden de inserción = desempate
AC-FL23; `restante` para la 004) · `usar_personal` (gate FL4) · `registrar_puesto_flujo`/
`quitar_puesto_flujo` (ids de Construcción + tipo del catálogo; NACEN abiertos — decisión MVP;
idempotente; la retirada con atención es contrato de la 006) · `abrir_puesto`/`cerrar_puesto`
(cierre en caliente → 006) · `estado_de_puesto` DERIVADO (cerrado → abierto_sin_agente [FL4
`_personal.puesto_dotado`] → atendiendo [persona] → libre) · `_emparejar()` (puestos LIBRES en
orden estable de registro → elegir_de_cola F7 con servicio+atenciones del TipoPuesto → retirar +
Llamada + referencia; sin dobles por construcción). Test `flujo_puestos_test.gd` **6/6 a la
primera** (FL07 sin agente no atiende · FL08 llama · FL23 exactamente uno [el 1.º registrado] ·
States B cerrar/reabrir/desasignar · **puente completo Construcción→Personal→Flujo** con puesto
construido de verdad · registros inválidos). **Suite total: 312/312, exit 0.** Epic Flujo 3/8.
**✅ flujo-003 COMMITEADA (2cc5c58).**
**🎉 flujo-004 IMPLEMENTADA + TEST EN VERDE (2026-07-24) — EL SALDO SUBE POR PRIMERA VEZ (en test):**
en flujo.gd — `duracion_efectiva(servicio, tramite_id, puesto_id)` F1 (duracion_min del catálogo
[TramiteDoc/DenunciaODAC según servicio — sin warnings cruzados] × modificador_produccion_de de
Personal; **clamp maxf(1.0,...)**: id inexistente → base 0 → 1 min, AC-FL10) · usar_bus/usar_tiempo
+ `_suscribir_al_tick` (patrón Demanda; Flujo se suscribe DESPUÉS — Main lo garantiza en la 008) ·
`_al_tick(delta)` ORDEN FIJO del contrato: (1) `_avanzar_atenciones` [restar delta; a 0 →
`tramite_completado(tramite_id, agente REAL)` UNA vez → Resuelta → puesto Libre] → (2) `_emparejar`
[el liberado llama EN el mismo tick] → (3) `_arrancar_llamadas` [Llamada→En atención + restante=F1;
la atención ARRANCA el tick del emparejamiento — el viaje es cosmético]. Test
`flujo_atencion_test.gd` **5/5 a la primera** (F1 12.0/9.12 crack · corrupto clamp 1 min · FL11
emisión ÚNICA a los 12 min exactos + agente real en el evento + encadenado p2 en el mismo tick ·
**E2E saldo 3000→3003.6 con Economía real** · Pausa con physics real congela restante).
**Suite total: 317/317, exit 0.** Epic Flujo 4/8.
**✅ flujo-004 COMMITEADA (703f1af). FIN DE SESIÓN 2026-07-24 (2ª).**
**✅ flujo-005 IMPLEMENTADA + TEST EN VERDE (2026-07-24, 3ª sesión, hilo principal):** aforo F6 +
fórmulas F2-F5 — Construcción gana **`aforo_de_servicio(servicio)`** (suma `aforo_de_sala` de
TODAS las salas de espera del servicio; una "Comun" cuenta para ambos — **decisión de impl.
pendiente de ratificar**: agregado en vez del getter `sala_de_espera_de` porque el jugador puede
construir VARIAS esperas del mismo servicio) · Flujo gana `usar_construccion` + `_aforo_de` (sin
Construcción → -1 "sin límite" = comportamiento de los tests 001-004, cero regresiones) ·
`encolar` clasifica dentro/fuera con `hay_plaza_dentro` PURA (AC-FL12 boundary 39/40 vs 40/40) +
`ocupacion_dentro` (solo ESPERANDO_DENTRO ocupa asiento; Llamada/atención no) · `retirar_de_cola`
→ `_promover_de_fuera` (entra la de MENOR turno; bucle por si se liberan varias plazas; servirá
también al abandono de la 006) · F2-F5 PURAS con centinela -1.0 (F2 floor, dur≤0 → 0 con aviso ·
F3 producto · F4 ρ · F5 espera estimada — NUNCA ∞ ni división por cero). **⚠️ Edge documentado:
con Construcción y 0 asientos NADIE entra ni es llamado** (comisaría sin sala de espera no
atiende — visible vía UI/R5 futuro).
**🔧 ENMIENDA F3 "DE PIE" (petición del usuario en la 1ª pasada, APLICADA):** una sala de espera
SIN asientos no deja a la gente en la calle — `aforo_de_sala` = SENTADOS (min(asientos,
floor(área×densidad_asientos)), como antes) **+ DE PIE (floor(área × `densidad_de_pie`))**, knob
NUEVO en ConfigConstruccion (**semilla 0.5** = 1 de pie por cada 2 celdas — número pendiente de
ratificar; .tres regenerado). El tope físico de ASIENTOS (CO7, 15.º rechazado) no cambia; los
asientos serán confort cuando llegue Paciencia #10. Tests actualizados a la fórmula: CO7 20/24 ·
CO8 → `test_sala_sin_asientos_aforo_de_pie` (9 celdas → 4 de pie) · demoler/mover a tope 10 ·
fixture flujo 2×2+1 asiento = aforo 3 · **test nuevo `test_sin_asientos_entran_de_pie`** (0
asientos → 2 de pie dentro + 1 fuera). Propagar F3 al GDD construction-layout con C2-7. **Idea
apuntada (backlog, no MVP): editor de fila/cola de personas** (tipo Planet Coaster).
Tests de la 005: `flujo_formulas_test.gd` **5/5** (FL12/19/20/21/22, valores exactos 26 · 52/260 ·
2→1 · 120/60/-1) + `flujo_aforo_test.gd` **5/5** (FL13 6 personas/aforo 3 real con entrada por
turno tras _emparejar · de pie · FL14 20 admisiones sin tope ni freno con atención real 2 ciclos ·
aforo agregado Doc 3+3 / ODAC 3). **Suite total: 326/326, exit 0.** SIN commit aún. Epic Flujo 5/8.
**✅ flujo-006 IMPLEMENTADA + TEST EN VERDE (2026-07-24, 3ª sesión):** compromiso de servicio y
gestión en caliente — puesto gana `cierre_pendiente`/`retirada_pendiente`/`override` (FL9):
`cerrar_puesto` con atención NO interrumpe (Cerrado AL emitir; `abrir_puesto` CANCELA el
pendiente) · `quitar_puesto_flujo` ahora devuelve bool y con atención espera al trámite (cierra
el contrato de la 003) · `reconfigurar_puesto` solo tipos `reconfigurable` (ids no admitidos
descartados con aviso; ninguno válido → false; [] limpia; PRÓXIMA llamada) · `forzar_abandono`
API para Paciencia (Esperando → Abandonando + señal `abandono` + libera plaza [entra el de
fuera]; Llamada/atención → false — REGLA dura) · **AC-CO13 en Construcción**: gate callable
`fijar_puede_demoler` (Main → `flujo.puede_demoler_puesto`; sin cablear → directo, compat) +
`_demoliciones_pendientes` + `reintentar_demoliciones_pendientes()` (Flujo las reintenta en el
tick TRAS avanzar atenciones y ANTES de emparejar; retira del registro las que caen) · **cascada
`demoler_sala` con puesto atendiendo → RECHAZADA entera con aviso** (decisión impl.: sin salas a
medio demoler; el jugador reintenta) · **cierre Doc AC-FL24 DERIVADO del reloj** (sin cruce con
estado: `puerta_doc_abierta()` = min_dia < `cierre_doc_min`, knob NUEVO en ConfigFlujo semilla
870 ⚠️ cross-fact duplicado de `ventana_doc_fin_min` de Demanda — registrar al propagar; .tres
regenerado): `admitir` Doc → null con puerta cerrada (caller descarta; ODAC 24 h); cola admitida
se atiende hasta vaciarse; minutos Doc trabajados con puerta cerrada → `fijar_hook_horas_extra`
(HORAS; Main lo cableará a `Economia.registrar_horas_extra`; sin cablear no-op) · Pausa FL15/25
por construcción. Tests `flujo_gestion_caliente_test.gd` **8/8** (FL17 cerrar+reabrir · FL16
viogen 60 min no interrumpida y salta a estafa con viogen2 Prioritaria esperando · rechazos FL9 ·
FL18 compromiso con señal y promoción de fuera · FL24 puerta+peonada 0.6 h exactas en Economía
real · CO13 e2e con reembolso 250 y agente al banquillo · retirada pendiente · FL15/25 pausa
exacta 5.0 y reanudar continúa 2 puestos). **1 bug de FIXTURE cazado por la suite** (mundo CO13
sin sala de espera → aforo 0 → nadie entraba: recordatorio de que con Construcción inyectada el
aforo MANDA). **Suite total: 334/334, exit 0.** SIN commit aún. Epic Flujo 6/8.
**⚠️ Decisiones impl. 006 pendientes de ratificar:** cierre Doc provisional EN FLUJO (la story lo
proponía) · knob `cierre_doc_min` duplicando el 870 · cascada de sala rechazada si atiende ·
reabrir cancela cierre pendiente.
**✅ flujo-007 IMPLEMENTADA + TEST EN VERDE (2026-07-24, 3ª sesión):** persistencia ADR-0002 +
grupo Persist en _ready (clave = node.name "Flujo" — Main debe nombrarlo así en la 008) —
`save()` = {personas [servicio/tramite/minuto_llegada/turno/estado — las colas y el dentro/fuera
se RE-DERIVAN del estado], puestos [id/abierto/cierre_pendiente/**retirada_pendiente** (no
estaba en la story, la 006 lo exige)/override/persona_turno/restante — el REGISTRO lo hace el
mundo ANTES de cargar, patrón Personal], turnos por servicio}; `load_state` defensivo (persona
con trámite fuera de catálogo / servicio raro / estado inválido → descartada con aviso; puesto
no registrado → descartado; atendida sin puesto → descartada; re-atado de atención por
SERVICIO+turno [los turnos van por servicio — un "3" de Doc no es el "3" de ODAC]; contador de
turnos reforzado a ≥ max turno visto [FL2 sin reuso]; 0 señales). Flujo gana preload de la ficha
Persona de Demanda (reconstrucción). Tests `flujo_save_determinismo_test.gd` **3/3 a la
primera** (AC-FL26 round-trip JSON full_precision campo a campo con cierre_pendiente vivo,
restante 7.5 exacto, turnos fuera [5,6], contador→7, 0 señales al cargar y el tick siguiente
completa+cierra · **AC-FL27 prueba reina**: guion 40 ticks [6 admisiones mixtas + reconfigurar +
forzar_abandono + cerrar/reabrir] en mundo A vs mundo B con SAVE en t15 y carga en B2 → eventos
(orden+payload) Y save() final IDÉNTICOS · corruptos descartados con aviso y el resto carga).
**Suite total: 337/337, exit 0.** Epic Flujo 7/8.
**✅ flujo-007 COMMITEADA (68ed442, pusheada).**
**🔨 flujo-008 IMPLEMENTADA — VENTANA ABIERTA, SIGN-OFF PENDIENTE (2026-07-24, 3ª sesión):**
Main cablea Flujo (name "Flujo", tras Demanda [tick] y tras Personal [orden de carga];
`persona_generada` → admitir [null si puerta Doc cerrada] → encolar → NPC; hooks 006:
fijar_puede_demoler + fijar_hook_horas_extra→Economía) + `_sincronizar_puestos_flujo()` (fuente
única Construcción: registra nuevos / quita demolidos) enganchado al **hook de layout NUEVO de
Construcción** (`fijar_hook_layout`, disparado en _refrescar_visual — también re-bakea la nav,
coalescido 1/frame). NUEVOS: `src/main/npc_ciudadano.gd` (CharacterBody2D fantasma +
NavigationAgent2D avoidance OFF + muñeco ColorRect mouse-IGNORE; target SOLO tras 1er physics
frame; destino recalculado SOLO al cambiar el estado de SU PersonaFlujo; velocidad × mult del
reloj [Pausa congela; 2×/3× corren]) y `src/main/npcs_flujo.gd` (manager: NavigationRegion2D +
bake_from_source_geometry_data del layout real [suelo + 2 celdas de CALLE a la izquierda
transitables; PUESTOS recortados como obstáculos — el NPC se para al borde del mostrador;
asientos NO recortados = sentarse]; asientos cosméticos ocupados/liberados; hueco de pie
determinista por turno; calle = spawn/cola exterior/salida). Getters nuevos: Flujo
`atendiendo_total`/`puesto_de(persona)`/`puestos_registrados` · Construcción `catalogo_de`/
`salas_de_espera_de`/`rect_de_sala`/`asientos_de_sala` · ConfigFlujo knob `velocidad_npc_px_s`
90 [10,600] (.tres regenerado). HUD bloque flujo: "En cola: N Doc · N ODAC" + "Atendiendo: N ·
FPS n" (guardrail 60). Captura evidencia → flujo-demo-2026-07-24.png. **Suite 337/337 exit 0 +
arranque headless limpio.** Evidencia `production/qa/evidence/flujo-demo-2026-07-24.md` escrita
(M1-M4 ⬜, sign-off ⬜). VENTANA ABIERTA (task bk4anv8n1). SIN commit aún.
**🔧 RONDAS DE FEEDBACK EN VENTANA (2026-07-24/25) — MODO NUEVO ordenado por el usuario: OPUS 4.8
implementa, FABLE coordina/supervisa/remata** (los agentes se atascan pidiendo aprobación por el
protocolo colaborativo → patrón que funciona: relanzar con "plan YA APROBADO, no pidas
aprobación"; si agotan turno, Fable remata lo mecánico — regla de rescate):
- **z_index NPCs** (gotcha NUEVO: capas visuales bajo un nodo NO-CanvasItem = raíces de canvas
  aparte que pintan DESPUÉS del bloque de Main → NPCs debajo de las salas; fix z_index=1).
- **Policías visibles** (muñeco azul marino + nombre tras cada mostrador dotado, DIFF por metas)
  + **rótulo de estado por puesto** (CERRADO/SIN AGENTE/LIBRE/EN CAMINO/ATENDIENDO, texto+color)
  + **HUD puerta Doc** ("Doc: ABIERTA (cierra 14:30)"/CERRADA).
- **Ventanilla TIE inicial** (decisión usuario: tie_1 en (6,2) + 4º agente ag_doc — los TIE solo
  los atiende puesto_tie; sin ella esperaban PARA SIEMPRE [el "misterio de las 22:00"]; nómina
  inicial ~255 €). **TIE azul claro** (COLOR_TIE) distinguible de dni/pasaporte.
- **PANEL DE PERSONAL** (`src/main/panel_personal.gd`, tecla P, opera en Pausa): PLANTILLA
  (asignar a puestos libres compatibles/desasignar/despedir) + MERCADO (contratar gate E4;
  generar_mercado() al arranque de Main — decisión andamio). 2ª pasada legibilidad: atributos
  "Rapidez 3/5 · ..." con autowrap; aviso "Sin puestos libres compatibles — este perfil opera:
  X"; "Opera: X" en candidatos.
- **ENMIENDA "EN CAMINO no se tramita" (usuario, 2026-07-25 — SUSTITUYE la decisión de la 004):**
  el trámite arranca cuando la persona LLEGA. Camino = distancia REAL del MODELO (centro de la
  sala de espera más cercana → celda del puesto, euclídea en celdas) / knob NUEVO
  `velocidad_camino_celdas_min` (2.0; 0=instantáneo compat; SUSTITUYE a
  duracion_desplazamiento_seg) — la regla sagrada FL5 intacta (del plano, no del sprite).
  `_arrancar_llamadas`→`_avanzar_caminos(delta)`; `camino_restante` en dict+save; estado derivado
  NUEVO del puesto **&"en_camino"** (States B +1 — propagar GDD en C2-7); atendiendo_total solo
  en_atencion; muñeco sincronizado (`velocidad_camino_px_s()` = misma velocidad lógica). Tests:
  camino 0 sin Construcción → tests viejos intactos; fixtures con Construcción aislados a 0.0;
  `flujo_camino_test.gd` 2/2 (2.0 min exactos calculados a mano); determinismo A-vs-B sobrevive
  CON camino real.
- **HORARIO PROVISIONAL Doc (usuario: "los funcionarios se van al cierre"; hasta Documentación
  #8):** knob `apertura_doc_min` 480 (cross-fact ventana_doc_inicio Demanda); flag
  `cierre_horario` en dict+save; `_gestionar_horario_doc()` al final del tick: fuera de horario +
  libre + cola admitida vacía → cierra (AC-FL24 intacto: primero vacía la peonada); en horario +
  cierre_horario → reabre solo; el cierre MANUAL del jugador NO se reabre. Policía OCULTO si
  puesto cerrado ("se van"; caminar a casa = juice futuro). `flujo_horario_test.gd` 3 tests
  (no-cierra-con-cola→cierra-al-vaciar · reabre a las 480 · manual no reabre · ODAC 24h);
  pausa-test a las 500 (en horario). FL24 test asserta "cerrado" final.
- **RESPUESTA AL USUARIO (fase):** estamos en PRODUCCIÓN, no diseño; feedback de COMPORTAMIENTO
  → ahora (barato); feedback ESTÉTICO → anotar para UI/HUD #11 + art bible (todo el visual
  actual es andamio que se rehará). El usuario cazó 3 reglas de diseño reales en demo.
- **CALIBRACIONES del camino (2ª y 3ª, tras demo):** (2ª) quitado un ÷60 espurio en la velocidad
  visual y knob 2.0→0.5 (con 2.0 el EN CAMINO duraba un parpadeo); (3ª — la BUENA): knob
  **0.375** = EXACTAMENTE el paso cosmético 90 px/s a 1× (90÷40÷6) · **paso ADAPTATIVO** del
  muñeco EN CAMINO acotado a ±50% del normal (feedback "esprintaba": cubre los px restantes en
  los minutos LÓGICOS restantes, getter `camino_restante_de(puesto)` — lo cosmético se ajusta a
  la verdad, FL5) · **origen ENTRADA**: `_minutos_de_camino(servicio, puesto, persona)` usa la
  const `CELDA_ENTRADA (0,6)` como origen si la persona AÚN no tuvo tiempo de llegar a su sala
  (derivado de minuto_llegada + reloj — el caso "ODAC libre te llama al entrar en la calle").
  Sanity del test A-vs-B ajustado (cuenta TIPOS de evento, no cantidad — caminos más largos = 
  menos trámites en 40 ticks; LA PRUEBA REINA A==B pasó en todas las calibraciones).
**Suite tras todo: 342/342, exit 0** (+arranque headless limpio; .tres de flujo regenerado 4×).
**🎉🎉🎉 SIGN-OFF CONCEDIDO (2026-07-25) — EPIC FLUJO 8/8 CERRADO = CORE 5/5 COMPLETO.**
2 rondas más de feedback en ventana ANTES del sign-off, ambas corregidas (Opus 5 en hilo principal,
sin subagentes — orden del usuario 2026-07-25: *"no uses fable para coordinar, coordina con opus 5"*):
- **BUG REAL — dos ciudadanos en el mismo asiento**: el hueco "de pie" se calculaba por turno sobre el
  rect de la sala, que **INCLUYE las celdas de los bancos** → un de-pie se plantaba sobre un sentado; y
  los de-pie tampoco se reservaban sitio entre ellos. Fix en `npcs_flujo.gd` (cosmético puro, FL5):
  **una celda, una persona** — `_plaza_de` (celda→NPC) reserva banco O hueco; los huecos de pie
  EXCLUYEN celdas de banco y barren el rect desde un origen determinista por turno (con vuelta);
  `_liberar_plaza` suelta TODAS las entradas del NPC y purga las de NPCs muertos (antes: asientos
  fantasma bloqueados para siempre); `_sitio_en_espera` idempotente. Sala a reventar (F3 admite ~1,2
  pers./celda) → se comparte celda con **desvío sub-celda determinista**, nunca superposición exacta.
- **Panel de personal ilegible de un vistazo**: añadido resumen (nómina €/día junto al saldo; línea
  "Plantilla: N (en puesto · banquillo · de baja) — Ventanillas cubiertas: X de Y", verde sin vacantes
  / ámbar con ellas; **un chip por ventanilla** con quién la cubre o VACANTE; contadores PLANTILLA (N)
  / MERCADO (N); panel 860×520). **El chip respeta el gate FL4**: titular DE BAJA sin cobertura → gris
  y NO cuenta como cubierta (si no, el panel diría "cubierta" y el juego no atendería ahí);
  cubridor → "(cubriendo)" azul. Verificado con un script headless temporal sobre Main REAL (patrón
  útil: montar Main en SceneTree, `await process_frame` ×10, llamar al `_reconstruir()` del panel).
**Cierre formal APLICADO (2026-07-25):** evidencia firmada (M1-M4 ✅) · 8 stories → **Complete** con
sección **Cierre** (la 004 documenta la enmienda del camino; la 006 el horario provisional + ratifica
el cierre Doc en Flujo) · `EPIC.md` Flujo → Complete 8/8 · `epics/index.md` → Complete · `sprint-2.md`
nota C2-4/C2-5/C2-6 ✅ · `sprint-status.yaml` flujo-001..008 + C2-6 → done.
**✅ C2-7 HECHA (2026-07-25) — 🏁 SPRINT 2 AL 100 % (7/7).** Commit del paquete: **`11f704e`** (29
archivos). 7 correcciones propagadas a 5 GDD + registro, cada una con nota de por qué era errata:
- `staff-agents.md` **F6 `floor`→`ceil(Mando/2)`** (2 sitios: fórmula + tabla Tuning; manda la TABLA
  de salida 1-2→1 · 3-4→2 · 5→3, que es lo implementado y lo que dice AC-PE14).
- `time-system.md` **AC-T26 14:30→15:30** (14:30 es turno MAÑANA en la tabla del propio GDD; el
  ejemplo mezclaba el horario laboral de Doc con el turno del reloj. El test ya usaba 15:30).
- `demand-generation.md` **`tasa_base_odac` 0.5→0.4** en la tabla Tuning (F1/AC-DM02/OpenQ ya decían
  0.4 = 36/día, y 0.4 es lo implementado) + **valle nocturno ≈10→≈5** en 4 sitios (el derivado real es
  **5,25** = 36 × 7/24 × 0,5; el "≈10" era una estimación a ojo que nunca cuadró con la fórmula).
- `construction-layout.md` **F3 = sentados + DE PIE** (`de_pie = floor(área × densidad_de_pie)`, knob
  0.5 en Tuning + invariantes + OpenQ 1) con la enmienda explicada: sin asientos NO se queda la gente
  en la calle; los asientos pasan a ser CONFORT (los cobrará Paciencia #10).
- `flow-queues.md` **FL5 = "EN CAMINO no se tramita"** (el trámite arranca al LLEGAR; distancia del
  PLANO ÷ `velocidad_camino_celdas_min`; el viejo `duracion_desplazamiento_seg` marcado como retirado;
  OpenQ 9 reescrita) + **States B: estado nuevo `En camino`** (5 estados: Cerrado · Abierto sin agente
  · Libre · **En camino** · Atendiendo) + **enmienda del horario provisional de Doc en AC-FL24**.
- `design/registry/entities.yaml`: **+4 cross-facts** — `apertura_doc_min` 480 y `cierre_doc_min` 870
  (marcados como EL MISMO HECHO que `ventana_doc_inicio/fin` de Demanda: si cambia uno, cambia el otro),
  `velocidad_camino_celdas_min` 0.375, `densidad_de_pie` 0.5; `densidad_asientos` con notes corregidas;
  `last_updated` 2026-07-25. YAML validado (52 constantes).
**Verificación cruzada GDD ↔ registro ↔ código:** los 4 valores coinciden (`config_flujo.gd` 0.375/870/
480, `config_construccion.gd` 0.5, `config_demanda.gd` 480/870/0.4) y **0 restos** de los valores viejos
(greps de floor(Mando, AC-T26 14:30, tasa 0.5, ≈10, duracion_desplazamiento_seg). `/consistency-check`
completo NO ejecutado (LEAN): verificación dirigida por grep, suficiente para erratas ya conocidas.
**✅ CIERRE DE SPRINT 2 Y ARRANQUE DEL 3 (2026-07-25) — commits `f3a8f79` + siguiente, pusheados:**
- **Push a GitHub hecho** (`68ed442..a24e5bf` y siguientes). Nada pendiente en el working tree.
- **1ª RETROSPECTIVA del proyecto** (`production/retrospectives/retro-sprint-2-2026-07-25.md`, línea
  base): 7/7 tareas, 15 stories, 264→342 tests, 15 commits, 8 bugs (todos cazados en ventana, 0
  escapados), 6 entregables no planificados, 0 carryover. **Hallazgo principal: el trabajo no
  planificado fue ~30 % del epic Flujo y entró sin renegociar el plan** — no es un problema de estimar
  mejor, es una partida presupuestaria que faltaba. **5 acciones**: (1) presupuestar las rondas de demo
  como tarea propia · (2) aviso de "demanda sin servicio capaz" (el misterio de las 22:00 no debe
  repetirse) · (3) backlog de pulido visual · (4) erratas del GDD al momento, no al final · (5) regla
  escrita de capas (los 2 bugs repetidos: z_index y clics tragados).
- **`design/ux/pulido-backlog.md` CREADO** (acción 3): 9 andamios conocidos + 4 apuntes de juice +
  restricciones. **⚠️ Pendiente de que el usuario desglose su "hay que pulir cosas de diseño"** (C3-12).
- **MEMORIAS actualizadas**: (a) *no ofrecer "parar por hoy"* — orden explícita del usuario; (b) el modo
  de trabajo vigente es **Opus 5 coordina E implementa en hilo principal, sin subagentes** (supera la
  orden anterior de "Opus 4.8 vía subagentes + Fable coordina").
- **`/create-epics layer: feature` HECHO**: 3 epics nuevos (`documentacion`, `odac`, `paciencia`) con
  ADRs gobernantes, tabla de TR (8/8 trazados, **0 huérfanos**, riesgo de motor **LOW** en los tres) y
  las interfaces que ya heredan de Core. `epics/index.md` → **13 epics** (5+5+3).
- **DECISIÓN DEL USUARIO (2026-07-25): Sprint 3 = Documentación #8 + ODAC #9** (los configuradores);
  **Paciencia #10 al Sprint 4** (la opción que se le recomendó, no elegida — anotar por si cambia).
- **`/sprint-plan new` HECHO** → `production/sprints/sprint-3.md` + `sprint-status.yaml` regenerado
  (12 tareas: 5 must / 4 should / 3 nice; el del Sprint 2 archivado en
  `production/sprints/sprint-2-status-archivado.yaml`). **Las rondas de demo YA van presupuestadas**
  (C3-4 y C3-8, 0,3 ses. cada una) — acción 1 del retro aplicada.
**🚀 EPIC PACIENCIA #10 — 7/8 STORIES IMPLEMENTADAS Y COMMITEADAS (2026-07-26, sesión larga sin
interrupciones por orden del usuario: "continúa varias sesiones, no me preguntes salvo que sea
importante, haz commit si quieres").** Suite **410/410**, todo pusheado.
- **001** núcleo + F1 (barra 0-100, drenaje, hacinamiento, ánimo por umbrales 66/33) — 17 tests.
- **002** tick + Pausa + **ABANDONO** (cableada en Main: la partida ya se puede perder) — 11 tests.
  🐛 *Bug silencioso cazado por un test:* la purga no puede basarse en "ya no está en la cola" (Flujo
  saca de la cola a quien llama) → se purga por ESTADO.
- **003** F2 puntuación de visita + el "recibo" de la espera (`_paciencia_al_llamar`) — 9+2 tests.
- **004** F3 media del día + cierre `nuevo_dia` **prio 10** (antes de Economía 20) — 10 tests.
  🐛 *Bug cazado que ningún AC cubría:* el bucle de abandonos hacía `olvidar()` **antes** de contar la
  visita → borraba el peor dato de la jornada justo antes de anotarlo; la satisfacción habría salido
  inflada siempre.
- **005** 🎉 **EL BUCLE ECONÓMICO CIERRA**: `sat_cierre` → `Economia.fijar_sat_cierre` → retorno DGP.
  Atender bien hoy sube el retorno de 0.30 a 0.39 mañana — 5 tests.
- **006** reclamaciones con RNGService (0.4), **corte de recursión por el propio trámite**, graves
  aparte, reset mensual — 9 tests. 🐛 *El gotcha de las lambdas por valor volvió a morder* (un espía
  con `int` daba 0 reclamaciones en 20 abandonos a p=0.4: 3 entre 100.000) → Array por referencia.
- **007** persistencia + **LA PRUEBA REINA A-vs-B con abandonos: PASÓ A LA PRIMERA**. Reenganche por
  clave estable `servicio#turno` (al cargar, Flujo crea PersonaFlujo nuevas) + getter nuevo de Flujo
  `personas_en_puestos()` (quien está en ventanilla no está en ninguna cola: sin él perdía su barra).
- **008 IMPLEMENTADA, EN REVIEW**: aro de ánimo sobre cada cabeza (verde/ámbar/rojo, oculto al ser
  llamado, DIFF) + HUD "Satisfacción: N/100 (ayer N)" con su escala visible + contador de
  reclamaciones (graves en rojo). **Falta el SIGN-OFF del usuario en ventana.**
**⚠️ HALLAZGO DE BALANCE (evidencia `paciencia-demo-2026-07-26.md`): ~90 abandonos en 5 h de juego**,
casi todos de ODAC antes de que abra Doc. Coherente con el diseño (ODAC 24 h con UNA ventanilla, ~36
denuncias/día, paciencia semilla 30 min), pero hay que **calibrar `tolerancia_base_min` CON el usuario**
(tarea C3-4). Palancas ordenadas y recomendación (empezar solo por el knob) en la evidencia.
**Ruta nueva `src/feature/`** (1er sistema de la capa Feature; no había convención escrita).
**🎉 EPIC PACIENCIA #10 CERRADO 8/8 CON SIGN-OFF (2026-07-26).** Suite **423/423**, todo pusheado.
Último commit: `c9b7d4a`. La partida YA SE PUEDE PERDER.

**Sign-off literal:** *"paciencia está bien de momento, veo que baja mucho la barra pero entiendo que
con mejoras en la sala podría subir la paciencia por lo que lo dejamos así"*. `tolerancia_base_min`
**se queda en 30** por decisión del usuario.

**⚠️ DEPENDENCIA DE DISEÑO REGISTRADA (no perder de vista):** ese sign-off trae una condición
implícita — se acepta el ritmo de cabreo **porque se cuenta con Comodidades #15, que aún no existe**.
Si ese sistema no llega, hay que subir la tolerancia; cuando llegue, hay que **revisar el número otra
vez**. Está escrito en `production/qa/evidence/paciencia-demo-2026-07-26.md` y en el cierre de la 008.

**Lo que entró el 26 además de las stories** (peticiones del usuario en ventana, todas cerradas):
- **Botonera de acciones en el HUD**: Personal (P) · **Guardar (F5)** · **Cargar (F9)**. ⚠️ El
  guardado EXISTÍA en el código pero **no había forma de invocarlo**: la partida no se podía guardar.
- **Panel de calibración F1, SOLO-DEV** (`src/main/panel_admin.gd`): 13 knobs agrupados por lo que el
  jugador nota (la espera / las visitas / el horario y el reloj / la comisaría), cada uno con su rango
  a la vista, termómetro en vivo arriba y botones **"Fijar en el catálogo"** (escribe los `.tres`) y
  **"Volver a los del catálogo"**. Solo se instancia con `OS.has_feature("editor")` → **no existe en un
  build exportado** (orden expresa del usuario: *"solo para el desarrollador"*).
- **Barra de paciencia que SE VACÍA** (antes era de tamaño fijo y solo cambiaba de color: no se veía
  venir el abandono). Fondo + relleno que se encoge; azul = colado.
- **MECÁNICA NUEVA — COLAR** (clic derecho → **menú contextual** con ficha de la persona + opción
  "⬆ Colar"): rango de prioridad máximo en F7 y **el resto de la cola pierde 10 puntos**
  (`penalizacion_colado`). Vale también para la cola exterior. Documentada en el GDD de Paciencia y
  registrada como cross-fact. 🐛 *El clic no funcionaba: leía `get_global_mouse_position()` (el puntero
  del sistema) en vez de la posición DEL EVENTO. Regla ya escrita en el control manifest.*
- **ENMIENDA del usuario**: el camino de entrada (puerta → su sitio de espera) **no gasta paciencia**;
  son ~10 min de juego con el ritmo actual. Hermana de "EN CAMINO no se tramita".
- **C3-10** `Flujo.tramites_sin_servicio()` + aviso rojo en el HUD (*"⚠ Nadie puede atender: tie ×3"*):
  el "misterio de las 22:00" ya no puede repetirse en silencio. 5 tests.
- **C3-11** reglas de orden de dibujo y ratón escritas en `docs/architecture/control-manifest.md`,
  cada una con el bug real que la originó + prohibido que las herramientas DEV entren en el build.
- **C3-1** `production/qa/qa-plan-sprint-3.md` escrito con la cobertura real y los 5 bugs cazados.

**PENDIENTE ANOTADO EN DISEÑO (NO implementado, por orden del usuario):**
- **U8 — icono de "a qué viene" cada ciudadano** (`design/ux/pulido-backlog.md` §U8 + `ui-hud.md`):
  los **17 tipos reales del catálogo**, con la urgencia distinguible del tipo, sin hover y resuelto
  JUNTO con la barra de paciencia que ya va sobre la cabeza. Para `/ux-design`.
- **Epic Comodidades #15 esbozado** (`production/epics/comodidades/`): vending, revistas, TV, mejores
  asientos → suben la paciencia. **El hueco ya existe en F1** (`mult_comodidad`, hoy fijo en 1.0):
  falta el CONTENIDO, no la fórmula. Fuera del MVP, pendiente de decisión de alcance del usuario.

**ESTADO DEL SPRINT 3:** 14/20 tareas. Hechas: C3-1, C3-2, pac-001..008, C3-3/4/5, C3-10, C3-11,
C3-12. **PENDIENTES: C3-6 `/create-stories documentacion` → C3-7 implementar → C3-8 demo → C3-9
cierre.** C3-13 (epic ODAC #9) sigue marcado como probable Sprint 4.

**PRÓXIMO INMEDIATO: Documentación #8** — epic ya escrito en `production/epics/documentacion/EPIC.md`
(TR-doc-001/002 trazados, riesgo LOW). Lo importante de ese epic: **el horario vive HOY prestado dentro
de Flujo** (`apertura_doc_min` 480 / `cierre_doc_min` 870, `_gestionar_horario_doc`, hook de peonada) y
hay que **migrarlo a su dueño** convirtiéndolo en configurable por el jugador (slider 08:00–20:00
pagando peonada). **Red de seguridad: `tests/integration/flujo/flujo_horario_test.gd` debe seguir en
verde durante toda la migración**; migrar en una story propia, sin mezclar features nuevas.

**[HISTÓRICO] C3-1 `/qa-plan sprint`** (antes de implementar nada, patrón de los sprints 1-2) →
**C3-2 `/create-stories documentacion`** → C3-3 implementar. **Deuda que salda este sprint: el horario
de Doc deja de vivir prestado en Flujo** (los tests de `flujo_horario_test.gd` son la red de seguridad
de esa migración).
**[HISTÓRICO — resuelto] Tras sign-off:** COMMIT del paquete (008 + panel + enmiendas) → cerrar epic Flujo 8/8
(stories→Complete con Cierres [en la 004: enmienda camino; en la 006: horario provisional];
EPIC/index/sprint-status C2-4..C2-6 + flujo-001..008 → done) = **CORE 5/5 COMPLETO** → C2-7
erratas GDD (F6 ceil staff-agents · AC-T26 time-system · tasa_base_odac y valle nocturno
demand-generation · F3 aforo de-pie construction-layout · cross-facts cierre_doc_min 870 y
apertura_doc_min 480 al registro · enmienda camino/States B a flow-queues).
- **008 (HITO VISIBLE = CORE 5/5)**: Main instancia Flujo DESPUÉS de Demanda (orden del tick) +
  usar_personal/usar_construccion/registrar los 3 puestos + conectar `persona_generada` del bus →
  admitir+encolar; NPCs CharacterBody2D+NavigationAgent2D placeholder color por servicio
  (⚠️ manifiesto: avoidance OFF, target tras `await get_tree().physics_frame` NUNCA en _ready,
  re-bake SOLO al cambiar layout, `NavigationServer2D.bake_from_source_geometry_data` — patrón del
  slice Escalón 1; verificar TODO contra docs/engine-reference/godot/modules/navigation.md); el NPC
  OBSERVA su PersonaFlujo (estados → destinos; mouse_filter IGNORE); HUD bloque Flujo en la barra
  inferior ("En cola: N · Atendiendo: N"); FPS ≥60 (spike QQ-02 margen); headless+suite → VENTANA
  (guion: 3× hasta 07:55 → 1× ver la apertura, gente entrando y EL SALDO SUBIENDO) → sign-off →
  cierre epic+C2-6 → C2-7 erratas GDD (F6 ceil staff-agents · AC-T26 time-system · tasa_base_odac
  y valle nocturno demand-generation).
Decisiones flujo ratificadas de facto (001-004): puestos nacen abiertos · el viaje NO descuenta
trámite (la atención arranca el tick del emparejamiento) · orden del tick avanzar→emparejar→
arrancar. ⚠️ Pendiente de ratificar: cierre Doc provisional en Flujo (006).
**GOTCHAS NUEVOS de esta sesión (además de los del traspaso anterior):** barra UI anclada abajo →
`grow_vertical = GROW_DIRECTION_BEGIN` o se dibuja fuera de pantalla · toolbars con textos del
catálogo → HFlowContainer (nunca HBox fijo) · TODO Control decorativo del mundo (ColorRect de
placeholders) → `mouse_filter = MOUSE_FILTER_IGNORE` o se traga los clics · HUD = barra inferior
estilo tycoon (petición del usuario; POS_SUELO=(96,24); la barra de construcción se apoya encima
con offset -84) · const Dictionary tipado con constantes de un preload funciona · ampliar salas =
Rect2i.merge con chequeo de unión exacta (inclusión-exclusión), cobra SOLO celdas nuevas.
Tras sign-off: cerrar epic Construcción 7/7 (stories→Complete con Cierres, EPIC, index,
sprint-status C2-2/C2-3+const-00X→done), commit, y PRÓXIMO: C2-4 `/create-stories flujo`.
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

---

## 🕐 EPIC DOCUMENTACIÓN #8 — 4/5 STORIES CERRADAS + PANEL EN VENTANA (2026-07-26, sesión Opus 5)

**Suite 485/485, exit 0** (423 → 485, +62). Arranque headless limpio. Todo commiteado (`82c78b1`).
**C3-6 HECHA** (5 stories escritas, commit `8d4fd2f`) · **C3-7 casi hecha** (falta el sign-off de la 005).

- **001 · El servicio y su reloj** (commit `9039110`) — `src/feature/documentacion/` (2º sistema de la
  capa Feature): F3 última admisión, F1 pura de horas extra, `estado_servicio` (abierto/cerrando/
  cerrado), tope de la División y la política de cita (MVP sin cita). Config `.tres` con 6 knobs.
  22 tests. *El test cazó una expectativa mía mal calculada, no un fallo del código.*
- **002 · 🚚 LA MUDANZA** (commit `0879d28`) — **la deuda del Sprint 2 está saldada**: el horario ya no
  vive prestado en Flujo. Documentación lo POSEE, Flujo lo EJECUTA (`fijar_horario_doc`) y Demanda lo
  RESPETA (`fijar_ventana_doc`). Los knobs salieron de `ConfigFlujo`/`ConfigDemanda` (fuente única).
  🚦 **La red de seguridad aguantó**: `flujo_horario_test` (3) y `demanda_tick_ventana_test` (6) verdes
  **sin tocarlos**. 11 tests nuevos.
  - **Decisión**: Demanda recibe la **última admisión** como fin de ventana (no el cierre): fabricar a
    alguien que encontraría la puerta cerrada al llegar es demanda imposible de atender.
  - **Agujero cerrado**: `puerta_doc_abierta()` ahora comprueba también la apertura (antes, a las
    03:00, admitía trámites de Doc).
  - 🐛 *Un test ajeno se rompió y era señal*: `flujo_atencion_test` creaba su reloj sin hora (00:00) y
    dejó de poder admitir. El gotcha de siempre; arreglado poniendo el reloj a las 08:20.
- **003 · La peonada** (commit `0093064`) — **la peonada cambió de significado** (aprobado por el
  usuario): se paga por **ampliar el horario** (DO4), no por los rezagados; terminar fuera de hora
  cuesta **moral** (−1 de motivación, suelo 1, una vez por agente y día). **Hook provisional de Flujo
  RETIRADO**. Cierre del día en prioridad **15** (Paciencia 10 → **Doc 15** → Economía 20: si fuera
  después, la peonada se cobraría un día tarde). `Personal.agentes_dotados_en_servicio()` nuevo.
  16 tests.
- **004 · Eventos de la División + guardado** (commit `0093064`+) — TR-doc-002 cerrado. Esquema nuevo
  `EventoDivision` + `datos/eventos/` con 2 comunicados (**vacaciones** meses 7–8 → pasaporte 21:30;
  **colapso_extranjeria** mes 2 → TIE 21:30), deterministas por mes. Señal `aviso_division` en el bus.
  `save()`/`load_state()` + grupo Persist. **El save guarda las DECISIONES, no el marco** (el horario
  base y los topes se releen del catálogo → un reequilibrado futuro llega a las partidas guardadas).
  13 tests **a la primera**. Catálogo: **32 recursos** (antes 30).
- **005 · Panel del horario (tecla H)** (commit `82c78b1`) — **IMPLEMENTADO, EN VENTANA, PENDIENTE DE
  SIGN-OFF**: slider de cierre con la peonada en vivo, última admisión, semáforo de demanda con icono
  + texto + consejo, bandeja de comunicados, estado ABIERTA/CERRANDO/CERRADA. Botón en la botonera.

**⚠️ HALLAZGO DE DISEÑO ANOTADO (no resuelto — para la demo C3-8):** el perfil intradía de Demanda
(`perfil_hora_doc`) solo tiene peso de 8 a 14 y **suma 1.0** (AC-DM03a). Es decir: **ampliar el
horario no trae gente nueva por la tarde**; sirve para **vaciar la cola acumulada**, que es justo lo
que dice el GDD (DO4). Si en la demo se ve que ni con demanda ALTA queda cola suficiente para que la
peonada compense, la palanca es añadir franjas de tarde como demanda **extra** (sin renormalizar, para
no tocar los 45/día calibrados) — es la Open Question nº1 del GDD.

**PENDIENTE: sign-off de la 005 → C3-9 (cierre formal del epic) → C3-13 (epic ODAC #9, Sprint 4).**

**➕ STORY 006 (2026-07-28, commit `637e4cf`) — nacida del feedback del usuario en la demo.** Suite
**497/497**. (1) **La peonada se paga POR VENTANILLA que se queda por la tarde**, no por plantilla:
antes era todo o nada y la decisión "dejo una de guardia" no se podía tomar. Si no queda ninguna, el
servicio se comporta como si no hubieras ampliado (pero el slider no se mueve). (2) **Goteo de tarde**
(`perfil_hora_doc_tarde`, knob aditivo): ~9 personas/día abriendo hasta las 20:00 — pequeño a
propósito, no paga una ventanilla solo; la paga con la cola acumulada. GDD y registro actualizados.
**La cita previa queda donde estaba: sistema #14 (V-Slice)** — es la versión "con información" de esta
misma decisión, y el usuario la quiere. PENDIENTE: demo baja vs alta + sign-off (005 y 006).

---

## 🎉🎉🎉 EPICS DOCUMENTACIÓN #8 Y COMODIDADES #15 CERRADOS (2026-07-28) + MENÚ DE SALA + PRÓXIMO: BIENESTAR #13

**Suite 535/535, exit 0.** Arranque headless limpio. Todo commiteado y pusheado.

**Documentación #8 CERRADO (6/6 stories).** El panel del horario (tecla H) se probó en ventana: slider
de cierre con la peonada recalculada en vivo, ventanillas que se quedan por la tarde, margen de última
admisión y la bandeja de comunicados de la División. **Sign-off literal: "me parece muy bien"
(2026-07-28)**. La propia demo dejó dos ajustes (story 006, ya cerrada): la peonada se paga **por
ventanilla** que se queda de guardia, no por toda la plantilla (antes era todo o nada y no dejaba tomar
la decisión real que el jugador quería tomar); y se añadió un **goteo de demanda de tarde**
(`perfil_hora_doc_tarde`) porque el perfil de Demanda original solo repartía llegadas hasta las 14:00 —
ampliar horario sin eso solo vaciaba cola vieja, nunca traía gente nueva. **Queda pendiente de
calibración fina**: si ese goteo, sumado a la cola acumulada, basta para que la peonada de tarde
compense de verdad en todos los niveles de demanda — se decide con más partidas, no es un rediseño.
Evidencia: `production/qa/evidence/documentacion-demo-2026-07-28.md`.

**Comodidades #15 CERRADO (3/3 stories) — y esto es notable porque NO nació del plan.** Es un epic que
el usuario pidió sobre la marcha (2026-07-26), aprovechando que Paciencia ya dejaba el hueco
`mult_comodidad` sin usar; se construyó y se probó **sin pasar antes por `/sprint-plan`**. Se demostró
en ventana el menú del clic derecho sobre la sala, la compra/colocación de objetos y el uso real del
vending (gente dejando la cola, usando la máquina y volviendo). **Dos ajustes salieron de verlo en
marcha** — el motivo por el que las demos en ventana valen más que el test automático para temas de
sensación y ritmo: (1) **tope de 2 viajes por visita** — *"hay muchos que lo hacen varias veces, eso no
es normal, vas 1 vez o 2 como mucho, he visto a 1 hasta 4 veces"*; sin tope la tirada podía repetirse
cada tick para la misma persona; (2) **rasgo `prob_consumidor` (0.45) por persona** — *"no todos
consumen por lo que sea; no todos los que baje la paciencia quieren tomar algo, al igual que el agua"*;
ahora cada persona decide de una vez, al generarse, si es de las que consumen. **Sign-off literal: "lo
dejamos así, continúa con el resto" (2026-07-28)**. Evidencia:
`production/qa/evidence/comodidades-demo-2026-07-28.md`.

**Menú contextual del clic derecho sobre la SALA** (no confundir con el clic derecho sobre un
ciudadano, para colar — eso es de Flujo/Paciencia): es el acceso por el que entra Comodidades, con una
entrada "🛋 Comodidades" que estaba puesta y deshabilitada desde antes de que el epic se implementara.
Ya funciona a pleno uso: comprar objetos, colocarlos y ver su efecto.

**Tres epics quedaron esbozados sin planificar todavía** (cada uno con su EPIC.md: qué existe, qué
falta, preguntas de diseño abiertas — a la espera de que el usuario decida meterlos en un sprint):
**Bienestar #13** (cansancio y sala de descanso: 30 min de café por jornada, 1 hora los caraduras; al
agotarse la barra el agente se levanta y la ventanilla se queda sola), **Retos del Comisario** (te
endosan un funcionario castigado con atributos malos que no puedes despedir), y **Comodidades #15** —
que estaba en esta misma lista de "esbozado sin planificar" y **ya salió de ella** implementándose y
cerrándose directamente por petición del usuario, sin pasar por planificación formal.

**Cambio de modo de trabajo**: esta sesión pasa a un modo **híbrido de coordinación** — Opus 5 en el
hilo principal coordina (mantiene la visión de conjunto, decide qué se delega y revisa el resultado) y
los **subagentes Sonnet 5 ejecutan** tareas delegadas y acotadas (como esta misma tanda de evidencias y
cierres de epic, hecha por el Producer). Motivo: descargar trabajo mecánico bien definido del hilo
principal sin perder supervisión — el hilo principal sigue siendo quien decide y firma.

**PENDIENTE: el siguiente sistema en la lista es Bienestar #13** (cansancio y sala de descanso) —
`/create-stories bienestar` cuando el usuario decida meterlo en un sprint. Depende de que Comodidades
ya esté cerrado (lo está) para que la comparación "invierto en aguante (comodidades) vs. invierto en
descanso del funcionario (bienestar)" tenga sentido completo.

---

## 🎉🐛 CIERRE DE SESIÓN (2026-07-28) — DOS BUGS DE BLOQUEO ARREGLADOS + CICLO DÍA/NOCHE + LA PEONADA AL PRECIO DEL JUGADOR

**Suite 591/591, exit 0.** Arranque headless limpio. Todo commiteado y pusheado.

**Recapitulando lo ya cerrado hoy** (ver bloque anterior): epic **Documentación #8 CERRADO (6/6)** y
epic **Comodidades #15 CERRADO (3/3)** — este último nacido de una petición del usuario sobre la
marcha, no del plan de sprint. Los dos con evidencia de demo y sign-off literal del usuario en
`production/qa/evidence/`.

**Menú contextual del clic derecho sobre la SALA, ya completo**: ampliar / asientos / ventanillas /
comodidades / demoler, todo desde el mismo menú. Lo que faltaba no era la mecánica —ampliar ya
funcionaba desde el Sprint 2— sino el **ACCESO**: había que saberse el truco de dibujar pegado a la
sala existente para que la ampliación se reconociera como tal.

**Comodidades #15, cómo funciona por dentro** (resumen de completitud, ajustes ya recogidos en el
bloque anterior): 8 objetos en dos familias — **ciudadano → confort → la gente aguanta más** (sube la
barra de paciencia) y **funcionario → rendimiento → se atiende más rápido**. Los objetos se USAN de
verdad, no son decoración: la persona se levanta de la cola, va al vending, consume (1 € a caja, +15 de
paciencia) y vuelve a su sitio. Dos ajustes salieron de verlo en marcha: tope de 2 viajes por visita, y
un rasgo por persona (`prob_consumidor` 0.45) porque no todo el mundo consume.

**Epic Bienestar #13 (cansancio y sala de descanso) — IMPLEMENTADO en lo esencial, SIN CERRAR
formalmente todavía.** Lo que ya funciona: una barra de cansancio que sube solo mientras el agente
atiende; tres patrones de descanso derivados de la **MOTIVACIÓN** del agente (Motivación 5 → dos
pausas de 15 min; 3-4 → una pausa de 30 min seguidos; 1-2 → un caradura que se toma 60 min); el
descanso es REAL, no cosmético (el agente termina el trámite en curso, se levanta, la ventanilla para
de atender, y vuelve con la barra a cero); una sala de descanso nueva en el catálogo (300 €, y sin ella
la pausa se alarga ×1,5 — el juego empuja a construirla); se ve en pantalla (rótulo ámbar con cuenta
atrás sobre la ventanilla vacía + muñecos con una taza dentro de la sala); el cansancio también
ralentiza el servicio un 25 % con la barra llena, de forma progresiva (no es un interruptor); un aviso
propio en el HUD, separado del aviso de "nadie puede atender" para no confundir las dos causas;
reinicio diario y persistencia. **Falta para cerrarlo formalmente**: escribir las stories 002, 003 y
004 del epic (solo existe la 001 escrita) y pasar por demo + sign-off.

**El precio de la peonada lo elige el jugador** (slider nuevo en el panel H, rango 15-30 €/hora). El
techo de 30 está razonado con los números del propio juego: un agente genera entre 20 y 30 €/hora
atendiendo, así que pagar por encima de 30 es pagar por el puro privilegio de que trabajen fuera de
hora. Efecto añadido: **pagar más cansa menos** — el multiplicador de cansancio baja de ×1,5 a ×1,0
cuanto más se paga.

**Ciclo de luz día/noche** (`src/main/ciclo_luz.gd`, vía CanvasModulate): mañana cálida, mediodía
neutro, tarde dorada, noche azul. Y **luces propias de los objetos** (`src/main/luces_objetos.gd`, vía
PointLight2D): la tele, el vending, la fuente y el equipo informático se encienden solos al anochecer.
Los dos con función pura testeada sin necesidad de abrir ventana.

**🐛🐛 DOS BUGS DE BLOQUEO ARREGLADOS** — los dos reportados por el usuario como "se queda parado / no
avanza", la peor clase de bug porque el jugador no sabe si el problema es el juego o él:
- **La partida empezaba a las 00:00** y Documentación no abre hasta las 08:00: 8 horas de juego real
  sin nada que gestionar, sensación de "no pasa nada". Arreglado arrancando a las **07:30**
  (`ConfigTiempo.hora_inicio_min` + `Tiempo.iniciar_partida_nueva()`, llamado desde Main) — con
  cuidado de NO tocar la hora de una partida cargada: el arreglo vive solo en el arranque de partida
  nueva, no en `aplicar_config`, precisamente para no desplazar el reloj de un guardado existente.
- **Quedarse sin dinero bloqueaba la partida DE VERDAD, no solo la pausaba.** Economía pausa el reloj
  y emite la señal `insolvencia` esperando que alguien decida (rescate/game over), pero **nadie
  escuchaba esa señal** — la partida se quedaba pausada para siempre, sin salida. Arreglado con
  `src/main/modal_comisario.gd`. **Este queda anotado como el bug más grave de la sesión**: no era un
  problema de rendimiento sino un sistema que hablaba solo, sin nadie al otro lado escuchando.
- El diagnóstico se hizo **midiendo antes de tocar nada** (4,00 min de juego por segundo de reloj, 144
  FPS en headless / 58 con ventana, nodos estables) — eso descartó rendimiento y fugas de memoria como
  causa antes de mirar la lógica.

**Modo de trabajo nuevo, ya en marcha**: Opus 5 coordina y verifica en el hilo principal; los
subagentes **Sonnet 5** ejecutan lo delegable (papeleo, diagnósticos acotados, documentación) en
paralelo cuando no tocan los mismos archivos. **Gotcha aprendido (pasó dos veces)**: los subagentes se
quedan sin turno a mitad de escribir documentos largos — hay que trocear el encargo y comprobar los
archivos resultantes, no fiarse solo de su informe de vuelta.

**PRÓXIMO**: cerrar formalmente Bienestar #13 (faltan las stories 002/003/004 del epic — solo existe la
001 — más demo y sign-off). Después, a elegir por el usuario: **Retos del Comisario** (esbozado en
`production/epics/retos-comisario/`), **ODAC #9** (C3-13 en el backlog, la última pieza del MVP sin
implementar) o una tanda de **juice** (números flotantes, rebotes — el usuario ha dicho que le gustan
las animaciones de los juegos idle).

---

## 🧱 CIERRE DE SESIÓN (2026-07-30) — MUROS LIBRES COMPLETOS (5 FASES) + LLAMADA ANTICIPADA + BIENESTAR #13 SIGUE SIN CERRAR

**Estado verificado en el hilo principal (no por informe de subagente): suite 643 casos, 0 fallos, exit
code 0. Arranque headless limpio. Todo commiteado y pusheado. Catálogo 50/50 recursos.**

### Bienestar #13 — implementado del todo, SIN SIGN-OFF todavía
Hoy se completó lo visual y lo jugable que faltaba: la barra de cansancio se VE sobre cada
funcionario (y en el panel P); el patrón de descanso (2 cafés cortos / 1 café largo / 1 café de
caradura) sale de la MOTIVACIÓN del agente; el camino a la sala de descanso se ve andado de verdad
(ya no hay teletransporte) y cuenta AL LLEGAR, no durante el trayecto; la sala tiene AFORO (si no cabe,
el agente sigue atendiendo, no pierde su turno de café); los muebles de la sala ACORTAN la pausa hasta
un 30 % (suelo calibrado para que cada compra cuente); el cupo de cafés se renueva por TURNO DE 8 HORAS
(no por jornada completa, que dejaba a la gente de ODAC 24 h agotada); y quien está de café cuando
cierra su ventanilla se marcha a casa sin terminarlo. **Falta la demo formal en ventana y el sign-off
del usuario** — lo implementado está probado por test de integración, no por ojo humano viendo andar al
muñeco.

### La llamada anticipada (Flujo)
Medido con números reales: un agente de Documentación pasaba **17 minutos parado** por cada cliente
(esperando a que cruzara la comisaría) y solo 13 atendiendo — **trabajaba el 44 % de su jornada**, y de
paso la barra de cansancio nunca llegaba a llenarse en ese servicio porque solo cansa el tiempo de
atención. Se descartaron "meter más gente" (no falta cola) y "acelerar el camino x3" (rompería la
velocidad calibrada del muñeco). La solución: cada ventanilla puede tener un SIGUIENTE ya llamado que
viene andando mientras el actual termina, y empalma en el mismo tick si ya llegó — como una oficina de
verdad que canta el número antes de que te levantes. Resuelto: la ventanilla ya no se queda parada
esperando el paseo del próximo cliente.

### Muros libres — las 5 fases (A-E), COMPLETAS
Petición del usuario: "la construcción de las paredes debe ser libre y luego dentro poner las zonas".
El flujo completo, cerrado hoy: **pintar muros** (fase A, arrastre por arista) → **una sala deja de ser
un rectángulo** y pasa a ser un conjunto de celdas real (fase B) → **el hueco que encierras ES la zona**,
con la forma que tenga, sin dibujar rectángulos (fase C) → **puertas y ventanas** en los muros ya
levantados (fase D) → **los muros bloquean el paso de verdad** (fase E). Decisión clave: **el muro vive
en la ARISTA entre dos celdas, no dentro de una celda** — así no come superficie útil, dos salas pegadas
comparten tabique, y ni el coste ni el aforo (que se calculan por área) cambian. Y la distinción que
hace funcionar todo el sistema: **`hay_muro()`** decide qué espacio encierras (una puerta cuenta como
pared, si no la sala se "escaparía" por su propia puerta); **`deja_pasar()`** decide si SE PUEDE cruzar
esa arista al moverse (por la puerta sí se pasa, por la ventana no). Son dos preguntas distintas sobre
la misma arista.

### Los bugs cazados hoy (la parte más valiosa del registro)
- **Las comodidades se perdían al guardar**: al cargar, `load_state` daba por inválido todo lo que no
  fuera un asiento NI un TipoPuesto — y una máquina de vending, una tele o un sofá no son ninguna de las
  dos cosas. Guardabas con F5, cargabas con F9, y las salas amuebladas volvían vacías.
- **El juego se comía su propia evidencia de QA**: un andamio de captura automática escribía SIEMPRE en
  el mismo archivo que usaba una demo firmada como prueba — cada arranque pisaba la foto de aquel día.
- **Las lámparas no salían en ningún menú**: no existía ninguna familia de iluminación comprable — solo
  se encendían solas la tele, el vending, la fuente y el equipo. El usuario preguntó por las luces de
  noche y sencillamente no había nada que comprar.
- **El ciudadano plantado en ODAC**: efecto colateral de la llamada anticipada — el muñeco ya llamado
  leía "me queda 0 de camino" (el dato de OTRO agente) y corría a paso acelerado, llegaba antes de
  tiempo y se quedaba congelado hasta 60 minutos, encima pintado sobre el que sí atendían.
- **El agente que no se iba al café sin cola**: el descanso solo se comprobaba al COMPLETAR un trámite,
  y sin cliente esperando no se completa ninguno — con la ventanilla vacía era, paradójicamente, cuando
  menos probable era que se fuera a descansar.
- **El cupo agotado que dejaba a la gente en rojo 18 horas**: el cupo de cafés era por JORNADA completa
  y ODAC no cierra nunca, así que un agente gastaba su única pausa y se quedaba al máximo de cansancio
  (25 % más lento) durante toda la sesión sin salida.
- **La luz que no se encendía al construirla de noche**: el cálculo de energía se saltaba el trabajo
  cuando la energía global no había cambiado (lo normal a media noche) — una lámpara recién comprada
  nacía apagada hasta el siguiente amanecer/anochecer.
- **El menú que ofrecía "abrir la ventanilla asiento_3"**: se preguntaba primero si el elemento estaba
  cerrado (cualquier id desconocido responde "cerrado") y solo después si era una ventanilla de verdad
  — el orden de las preguntas estaba invertido, y encima mostraba el id interno en vez del nombre.

### Deuda conocida y pendientes
- **Los tres cronómetros del juego (llegar a la ventanilla, ir al café, entrar por la mañana) miden en
  LÍNEA RECTA.** Con paredes que ahora obligan a rodear, el reloj puede decir que se tarda menos de lo
  que de verdad se tarda. Se paga midiendo rutas reales y cacheándolas en el rebake de navegación, no
  por frame.
- **Punto U9 del backlog de pulido**: el usuario dijo que el trazado de muros "va mejor, no del todo
  bien" y no concretó qué falla — pidió seguir. Hay que volver a preguntárselo antes de dar la
  herramienta por definitivamente buena, porque es con la que se construye TODA la comisaría.
- **ODAC #9**: la última pieza del MVP, todavía sin implementar (sin panel propio; se maneja por el
  clic derecho sobre la sala mientras tanto).
- **Bienestar #13**: implementado del todo, sin demo formal ni sign-off.
- **Se puede encerrar gente cerrando un espacio sin puerta.** Es un comportamiento PERMITIDO a propósito
  (el modelo no obliga a dejar salida), pero en partida se sentirá como un bug si le pasa a alguien sin
  querer.

### Próximo
El usuario ha decidido pasar a **DISEÑO**: art bible §5-9 (dirección de personajes, lenguaje de
entornos, dirección visual de UI/HUD, estándares de assets, referencias). Nota de contexto: `assets/`
está VACÍO (0 archivos) y la regla del proyecto es explícita — nada de arte antes del art bible §5-9
(condición 2 del gate Pre-Production → Production, todavía sin resolver).

### Nota de método
Hoy **ONCE subagentes se quedaron sin turno a mitad de tarea**. Uno de ellos dejó el juego SIN COMPILAR
y sin la función central de la llamada anticipada (llamadas a una función inexistente) — se revirtió su
trabajo y se rehízo entero en el hilo principal, sin delegar. Todo lo dado por bueno en esta sesión se
verificó en el hilo principal con la suite completa y el arranque headless, **nunca por el informe de
vuelta de un subagente**.

---

## 🔄 CAMBIO DE RUMBO AL CIERRE (2026-07-30) — EL JUEGO PASA A ISOMÉTRICO

**Decidido por el usuario en los últimos mensajes de la sesión**: *"quiero un theme hospital con la
misma visualización"*, *"realista pero jugón"*, *"lo veo muy pixel"* (descarta el pixel art),
*"quiero una experiencia tycoon total"*.

**Verificado antes de decidir**: Theme Hospital es **isométrico** (sprites pre-renderizados desde 3D).
El juego es hoy **cenital con rejilla cuadrada**.

**NO se toca el modelo**: Flujo, Personal, Paciencia, Economía, Demanda, Documentación, los muros en
aristas, las zonas, los cronómetros — nada conoce la proyección. **Los 643 tests siguen valiendo.**
Es mérito del ADR-0004 (*el visual refleja el modelo, jamás al revés*).

**Se rehace la capa visual**: proyección celda↔píxel (cuadrado → rombo 2:1), suelos, paredes (pasan a
tener altura), sprites anclados por la base, **orden de dibujo por profundidad (nuevo)**, y la
conversión clic→celda de la que vive el modo construcción.

**Orden acordado**: (1) la proyección con los rectángulos de colores actuales, para comprobar que todo
sigue funcionando sin arte de por medio; (2) el arte después, en 3D pre-renderizado.

**Se hace AHORA porque el arte no existe todavía** (`assets/` = 0 archivos): no se tira nada.

Anotado en `design/gdd/construction-layout.md` y en `design/art/art-bible.md` (§5/§6/§8 marcadas EN
REVISIÓN; §1-4, §7 y §9 siguen valiendo enteras).

**Herramientas de arte investigadas** (para la sesión de producción, no la de conversión): Scenario
(45 $/mes, entrena modelo propio, tiene MCP), SpriteCook, Pixel Plugin + Aseprite. Aviso registrado:
la IA generativa falla justo en personajes multiángulo consistentes — de ahí el 3D pre-renderizado.

---

## 🔷 SESIÓN 2026-07-30 (2ª) — CONVERSIÓN A ISOMÉTRICO, EN CURSO

**Decisión de ventana y rombo (usuario)**: ventana **1600×900** + rombo **80×40** (2:1, el del art
bible §8). Motivo: el tablero de 24×13 celdas mide **1480×740 px** proyectado y no cabía en los
1152×648 anteriores. Se agrandó la ventana en vez de encoger el rombo, para no bajar la resolución
a la que se dibujará el arte. Escrito en `project.godot` → `[display]`.

### La decisión de arquitectura de la sesión: DOS PLANOS

Es lo que hay que entender para tocar cualquier cosa visual a partir de ahora.

- **Plano lógico CUADRADO** (celdas de 40 px, `Proyeccion.TAM_CELDA`): la rejilla del modelo, la
  NAVEGACIÓN, las distancias y las velocidades de los muñecos. **No se ha tocado.** Vive en el nodo
  oculto `NPCs/PlanoLogico`.
- **Pantalla ISOMÉTRICA** (rombos de 80×40): lo que se ve. Vive en `NPCs/Escena` (con
  `y_sort_enabled`), en las capas de Construcción y en las paredes.

**Por qué así y no metiendo el TileMap en modo isométrico** (la alternativa corta): en coordenadas
isométricas, andar "en diagonal hacia abajo" recorre 40 px y "en diagonal hacia el lado" recorre 80.
A la misma velocidad en px/s, un ciudadano cruzaría celdas al **doble de ritmo según hacia dónde
ande**, y los cronómetros del modelo (que cuentan CUADRÍCULAS) dejarían de cuadrar con lo que se ve
— la familia de bugs de "el ciudadano plantado en ODAC". Manteniendo la navegación en el plano
cuadrado, la velocidad es la misma en toda dirección.

Consecuencia práctica: cada cuerpo que anda tiene un **muñeco** aparte en la capa de escena, al que
se le copia la posición ya proyectada cada physics frame (`npc_ciudadano._physics_process` para los
ciudadanos; `NPCsFlujo._sincronizar_caminantes` para los funcionarios que van al café o entran a
trabajar).

### Piezas nuevas

- **`src/foundation/proyeccion/proyeccion.gd`** (`Proyeccion`) — la única traducción cuadrado↔iso.
  Matemática pura, sin dependencias. `proyectar` / `desproyectar` / `centro_iso` / `esquina_iso` /
  `rombo_de_celda` / `profundidad` / `transformada` / `origen_centrado`.
- **`tests/unit/proyeccion/proyeccion_test.gd`** — 15 casos: ida y vuelta, los 4 vértices, clic
  dentro del rombo, aristas compartidas, profundidad, encaje del tablero. **Verdes.**
- **`docs/engine-reference/godot/modules/isometrico-2d.md`** — API de Godot 4.6 verificada contra la
  doc oficial. Gotcha capital: **`y_sort_enabled` NO es recursivo** (solo ordena hijos DIRECTOS) y
  solo desempata **dentro del mismo `z_index`**.
- **`design/art/herramientas-scenario.md`** — planes de Scenario verificados.

### API nueva de Construcción (la frontera entre los dos planos)

| Función | Devuelve | Para qué |
|---|---|---|
| `centro_de_celda(celda)` | plano CUADRADO | destinos de navegación, distancias |
| `centro_en_pantalla(celda)` | PANTALLA | colocar cualquier cosa que se dibuje |
| `esquina_en_pantalla(col, fila)` | PANTALLA | paredes (van de vértice a vértice) |
| `celda_de_punto(punto)` | celda | de un CLIC (ahora funciona en headless) |
| `punto_cuadrado_de(punto)` | plano CUADRADO | dónde exactamente DENTRO de la celda (pincel de muros) |

### Convertido

Suelo de fondo · suelos de sala · mostradores, asientos y comodidades (**anclados por la BASE**) ·
rótulos de sala · paredes y jambas (siguen las aristas del rombo) · ciudadanos · funcionarios que
andan · luces · el fantasma del modo construcción (pasa de `Panel` rectangular a **polígono
dibujado**: la huella real, como en Two Point Campus) · el pincel de aristas · el clic derecho.

### Referencia visual del usuario: `capturas/` (Two Point Campus)

Metidas por el usuario a mitad de sesión. **Resuelven el problema de las paredes**: en Two Point,
las paredes del lado CERCANO a la cámara sencillamente **no se dibujan** — se ve el interior entero;
las del fondo van a altura completa con su remate superior. El fantasma de sala es una caja
translúcida con **solo las dos paredes del fondo**. Esa es la regla a implementar.

### PENDIENTE en la conversión

1. **Paredes con ALTURA** + la regla de arriba (hoy son líneas planas sobre la arista).
2. **Profundidad entre capas distintas**: hoy la gente (z 2) siempre se pinta sobre mostradores
   (z 0) y paredes (z 1) porque son capas separadas, y el y-sort no cruza capas. Para que un
   mostrador tape de verdad a quien está detrás, todo eso tiene que colgar de UNA capa y-sorted.
3. Cámara (paneo/zoom) — no hace falta con 1600×900, pero llegará.

### 🐛 Bug cazado por el usuario nada más abrir la ventana (2026-07-30)

*"los funcionarios no están en sus puestos, están fuera de la comisaría"*. Causa: los mostradores
(`_visual_de_puesto`) se colocaban con `Construccion.centro_en_pantalla()`, que YA suma el origen de
la rejilla — pero cuelgan de `_capa_escena`, que también está puesta en `pos_suelo`. **El
desplazamiento se sumaba dos veces** y los mostradores (con sus policías encima) se iban un tablero
entero abajo a la derecha, fuera del edificio. Corregido: dentro de `_capa_escena` va la proyección
PELADA (`Proyeccion.centro_iso`).

**Regla que deja el bug, para no repetirlo**: `Construccion.centro_en_pantalla` / `esquina_en_pantalla`
incluyen el origen → solo valen para nodos que cuelgan de algo colocado en (0,0). Para hijos de
`_capa_escena` o de `Construccion._capa_elementos` (que ya llevan el origen) hay que usar
`Proyeccion.centro_iso` / `esquina_iso` / `proyectar`, sin origen.

Capas auditadas tras el fallo, una por una: suelo de fondo ✓ · `_capa_salas` ✓ · `_capa_elementos` ✓ ·
`EtiquetasSala` ✓ · `ParedesSalas` ✓ · `LucesObjetos` ✓ · preview de construcción ✓ · muñecos ✓.
El único caso mal era el de los mostradores.

### 🐛 2º aviso del usuario: los objetos no seguían la rejilla

*"los objetos deben seguir la dirección de las cuadrículas, ahora mismo se superponen y se ponen en
horizontal sin seguir las cuadrículas"*. Causa: mostradores, asientos y comodidades se dibujaban con
un `ColorRect`, que es un rectángulo RECTO de pantalla. Sobre rejilla cuadrada coincidía con la
celda; sobre rombos apuntaba a una dirección que no existe en el juego, y un sofá de 3 celdas salía
como una barra horizontal atravesando el suelo.

Corregido con **`src/foundation/proyeccion/pieza_iso.gd`** (`PiezaIso`): dibuja cada objeto como
caja isométrica sobre su huella REAL de celdas (tapa + las dos caras frontales + contorno, con
sombreado por cara). Sustituye a `_empaquetar_placeholder`, que se ha eliminado.

### Refinamiento de la regla de paredes tras ver `capturas/clientes.PNG`

La primera versión RECORTABA las paredes cercanas (solo línea de suelo). La captura de cerca enseña
que Two Point **sí las dibuja**, pero vistas por FUERA: su cara cuelga hacia ABAJO en pantalla,
sobre el pasillo, en vez de subir sobre la sala. Se mantiene la sensación de recinto cerrado Y se ve
el interior. Implementado así: `_cara_de_arista` devuelve `{alto, exterior}` y `_draw` crece hacia
arriba o hacia abajo según eso.

---

## 🧱 AMPLIACIONES DEL 2026-07-30 (2ª tanda) — ROTAR CON R + FACHADA FIJA

**Pedidas por el usuario viendo el juego ya en isométrico. Suite: 672 casos, 0 fallos, exit 0**
(658 + 14 nuevos en `tests/integration/construccion/construccion_fachada_rotacion_test.gd`).

### Rotar con R
*"debe poder rotarse un objeto con la R por ejemplo"*. Un elemento de varias celdas (el sofá de 3,
los mostradores) crece desde su ancla en UN eje; girar es elegir cuál.

- `Construccion.HORIZONTAL` (crece hacia +X, **el valor de siempre**) / `VERTICAL` (hacia +Y).
- La orientación es **aditiva**: por defecto todo se comporta como antes, así que **ni un test
  existente se tocó**. Los saves antiguos, que no traen el campo, se cargan como HORIZONTAL.
- API nueva: `celdas_de_elemento(id)`, `orientacion_de(id)`; parámetro `orientacion` en
  `validar_elemento`, `construir_elemento`, `_celdas_de`, `_alta_elemento`, `_crear_elemento`.
- El fantasma gira con la pieza y `PiezaIso` dibuja la huella en el eje correcto.

### La fachada fija
*"deberíamos poner unos muros fijos que no se pueden modificar que es exactamente el diseño de la
comisaría... poniendo además una puerta de acceso donde entren y salgan los npc"*.

- `Construccion.levantar_fachada()` cierra el perímetro del edificio y abre una puerta de 2 celdas
  en el lado de la calle, en la fila de `CELDA_PUERTA_EDIFICIO` (0,6) — por donde ya llegaba la
  gente, así que el recorrido de siempre sigue valiendo.
- Los muros de fachada viven en `_muros` como cualquier tabique (recinto, paso y dibujo los tratan
  igual, cero casos especiales) y `_muros_fijos` marca cuáles son intocables: `demoler_muro` y
  `fijar_tipo_de_muro` los rechazan. No cuestan dinero.
- **Es idempotente**: se llama al montar la comisaría Y después de cargar partida (en el save son
  tabiques corrientes, así que hay que volver a marcarlos como fijos — si no, una partida cargada
  te dejaría derribar la fachada).
- **NO cambia los recintos**: el modelo ya trataba el perímetro del edificio como muro implícito
  (`recinto_de`), así que declararlo explícito no altera ninguna zona. Hay test que lo prueba.
- **Sí cambia la navegación**: ahora la puerta es el ÚNICO hueco por el que se entra y se sale.
- Visual: color LADRILLO (`COLOR_FACHADA`), distinto del gris de obra de un tabique del jugador.
  Y su altura se mide contra el EDIFICIO, no contra las salas: los lados de arriba/izquierda tienen
  detrás la calle (van altos, son el telón) y los de abajo/derecha tienen detrás el interior (van
  bajos). Sin esa distinción, la fachada de abajo taparía la comisaría entera.

### Decisión de arte cerrada: TONO TWO POINT
*"el estilo vamos a implantarlo con tipo two point, puede darle algo de gracia a algo tan serio"*.
Resuelta la tensión que quedaba: §1 del art bible ("nada cómico ni exagerado") queda SUPERADA y
Two Point pasa de anti-referencia (§9) a **referencia principal de tono**. Humor de SITUACIÓN y
observación, no parodia. NO se adopta su paleta hipersaturada ni su HUD repartido (§4 y §7 mandan).
**Pendiente del usuario**: §5 — personajes SIN CARA (recomendado, barato) vs CARA MÍNIMA (multiplica
4-8 ángulos × expresiones).

### Confirmado leyendo el código (no hacía falta tocar nada)
La paciencia **ya se para en cuanto llaman al ciudadano**: `Paciencia._espera()` solo drena en
`ESPERANDO_DENTRO` / `ESPERANDO_FUERA`, y al llamarle pasa a `LLAMADA`. La propuesta del usuario
("pausar la paciencia 5 minutos antes") ya está, y mejor: se para en el momento exacto en que el
juego le promete que ya le toca.

### 🐛 EL BUG GORDO DE LA SESIÓN: los funcionarios entraban en bucle

*"siguen entrando 6 funcionarios para 3 puestos de documentación"*. Lo dije mal la primera vez
(conté nodos en un instante y salía 1:1); la forma correcta de medirlo era **instrumentar la ventana
real** y mirar quién arranca viaje:

```
[DIAG-ENTRA] Carlos Vega → doc_2
[DIAG-ENTRA] Ana Ruiz    → doc_1
[DIAG-ENTRA] Carlos Vega → doc_2   ← otra vez
[DIAG-ENTRA] Ana Ruiz    → doc_1   ← otra vez
```

**Causa** (`npcs_flujo._mover_paso`): fijar `nav.target_position` lanza una consulta de camino que el
NavigationServer resuelve **al frame siguiente**. El código preguntaba `is_navigation_finished()` dos
líneas más abajo, en el MISMO frame — y contestaba `true` porque aún no había camino. El viaje se
cerraba al instante, el muñeco se borraba, el modelo seguía diciendo "este agente viene de camino" y
al frame siguiente nacía un viaje nuevo. **Un bucle.** Afectaba también a los viajes al café.

**Arreglo**: tras aplicar el destino se sale con `return false`; ese frame solo sirve para encargar
el camino. Es el mismo gotcha del primer physics frame del NavigationServer que ya estaba
documentado, una vuelta de tuerca más.

**Lección de método**: contar nodos en un instante NO vale para cazar un bucle de crear/destruir.
Hay que instrumentar el EVENTO (quién arranca qué) y mirarlo en la ventana real, no en headless —
donde además el viewport es de 64×64 y las posiciones de pantalla no significan nada.

### El policía se dibujaba encima de su propia mesa

*"el funcionario está en la misma cuadrícula que la mesa y no se ve"*. Estaba bien colocado (una
casilla detrás, comprobado: `policia glob=(620,118)` vs `mesa (580,138)`), pero **el orden de dibujo
estaba invertido**: la mesa la pintaba Construcción en `_capa_elementos` (z 0) y el policía vivía en
la capa de NPCs (z 2), así que el muñeco salía ENCIMA del mostrador.

**Arreglo**: la mesa de una ventanilla la dibuja ahora su propio contenedor, **después** del policía
— dentro de un mismo nodo se pinta en orden, así que el mostrador le tapa las piernas, que es
exactamente lo que ves cuando alguien te atiende. Construcción deja de pintar caja para los puestos
(sigue pintando asientos y comodidades).

### 🔒 LA INVARIANTE: 1 PUESTO = 1 FUNCIONARIO QUE ENTRA

El bucle se persiguió **tres veces por sus causas** y volvía en otra forma:
1. `is_navigation_finished()` contesta "ya llegaste" el mismo frame en que se fija el destino,
   porque el NavigationServer aún no ha resuelto el camino → se arregló saliendo ese frame.
2. Ese mismo método miente también mientras calcula → se pasó a MEDIR la distancia real al destino,
   con reintentos y un tope (`MAX_REINTENTOS_CAMINO`) por si el destino es inalcanzable.
3. El muñeco llega ANTES que el modelo (píxeles vs minutos), el viaje se cerraba y el modelo pedía
   otro → ahora el muñeco que llega se queda plantado esperando a que el modelo lo dé por
   incorporado. (Mismo arreglo para el descanso sin sala construida, que tenía el mismo bucle.)

**Y aun así seguía.** Encargo del usuario: *"necesito que seas implacable con eso para que no se
repita, 1 puesto = 1 funcionario que entra"*. Así que se dejó de depender de acertar con la causa:

`NPCsFlujo.decidir_entrada(agente, viene, tiene_viaje)` — lógica **pura** (sin escena, sin
navegación, sin reloj) que apunta en `_ya_entro` que ese agente YA hizo su entrada para ESE puesto.
Mientras el modelo siga diciendo que viene de camino, no se le crea otro viaje pase lo que pase. La
marca se borra cuando el modelo deja de decirlo → mañana entra otra vez; y guarda el PUESTO, no solo
al agente → si le reasignan, entra a la nueva ventanilla.

Cubierto por `tests/unit/main/npcs_entrada_unica_test.gd` (6 casos), incluido el que reproduce el
peor caso: 3 agentes × 300 pasadas del refresco con el viaje cerrándose siempre → **exactamente 3
entradas**. El test prueba la INVARIANTE, no las causas, así que da igual qué se rompa por debajo.

**Lección de método**: los tres primeros arreglos eran correctos y ninguno bastaba. Cuando un bug
vuelve por tercera vez, hay que dejar de arreglar la causa y blindar la invariante — y aislarla en
una función pura para poder probarla sin motor.

### Cierre del bucle: el arreglo que había que DESHACER

El intento nº3 ("el muñeco que llega espera a que el modelo le dé por incorporado") resultó ser
**peor que el problema**: el modelo puede tardar mucho en decirlo, así que el viaje quedaba abierto
para siempre y con él la supresión del mostrador — el funcionario **no se veía nunca** en su
ventanilla. Lo cazó el usuario al instante.

Deshecho: el viaje se cierra EN CUANTO el muñeco llega, como antes. Cerrar pronto es seguro **desde
que existe la invariante**: aunque el modelo siga diciendo "viene de camino", ese agente ya no
vuelve a entrar. La invariante es lo que hace innecesario acertar con el momento exacto de cierre.

### El orden de dibujo de la ventanilla, en tres intentos

1. Policía en la MISMA celda que la mesa → parecía subido encima.
2. Policía una casilla atrás, pero la mesa vivía en otra capa más al fondo → seguía pintándose por
   debajo del muñeco.
3. Mesa traída al contenedor y dibujada DESPUÉS → su cara superior se comía al muñeco
   (*"se pone en la mesa y tapa al funcionario"*).
4. **Bueno**: mesa primero, policía después. Él está una casilla más al fondo (más arriba en
   pantalla), así que verle entero por encima del mostrador es lo correcto en isométrico.

### Medido, no supuesto: quién entra a trabajar

`va_de_camino_al_puesto` por agente, instrumentado en ventana:
- **Ana Ruiz (doc_1)** y **Carlos Vega (doc_2)**: entran andando. ✅
- **Javier Molina (odac_1)**: no entra porque ODAC es de 24 h — ya está en su puesto. Lo dedujo el
  propio usuario y es correcto.
- **Lucía Ortega (tie_1)**: su ventanilla SÍ abre (medido en una corrida larga: `tie_1` pasa por
  `cerrado → libre → atendiendo`), solo que más tarde que las de Documentación general. Entra
  cuando le toca; la muestra de 4 segundos era demasiado corta para verlo.

### ⚠️ GOTCHA NUEVO DE HERRAMIENTA: `--import` reescribe los `.tres`

Ejecutar `godot --headless --import` (que arranca el editor) **reescribió `datos/config/demanda.tres`**
—reordenó claves y añadió `tasa_base_doc = 0.9`— y eso tumbó `demanda_volumen_test`. No era el
código: era la herramienta. Revertido con `git restore -- datos/`.

**Regla**: `--import` solo para registrar un `class_name` nuevo, y DESPUÉS comprobar
`git status -- datos/` y revertir lo que haya tocado. Nunca dar por bueno un fallo de test sin mirar
antes si el árbol de datos ha cambiado solo.

### Luces de techo (2026-07-30)

*"las luces pueden ir encima de otros objetos, ya que están arriba, excepto la luz de suelo. en
lugar de ser un cuadrado entero se puede poner un punto en el centro amarillo para saber que es
una luz"*.

- Campo nuevo de catálogo **`Comodidad.en_techo`** (`true` en `fluorescente` y `foco_led`; la
  `lampara_pie` NO lo lleva — esa se apoya en el suelo y estorba). Data-driven: si mañana hay un
  ventilador de techo, basta con marcarlo en su `.tres`.
- Modelo: una pieza de techo **no ocupa suelo** — se cuelga encima de lo que sea, y tener una
  colgada tampoco impide amueblar debajo (funciona en los dos sentidos; si solo funcionara en uno,
  el jugador tendría que acordarse de poner las luces las últimas).
- Al pinchar en una celda con luz Y mueble, `elemento_en` devuelve **la luz** — es la que está
  dibujada encima y a la que estás apuntando.
- Visual: **punto ámbar con halo** (`PiezaIso.punto`), no una caja: marca dónde está sin comerse la
  casilla ni tapar lo de debajo.
- `tests/integration/construccion/construccion_luces_techo_test.gd` — 7 casos.

### La mesa dejó de llenar su baldosa

Última vuelta del problema del funcionario invisible: el mostrador se dibujaba ocupando el rombo
ENTERO, así que el policía, plantado en la casilla de atrás, quedaba pegado a su borde y parecía
estar encima. `PiezaIso` acepta ahora una **escala** (cuánto de su celda ocupa la pieza) y el
mostrador va al **0,62** — un mueble no llena la baldosa entera.

### Lucía Ortega: NO era un bug (revertido)

Se llegó a tocar `Personal._gestionar_incorporaciones` para que entrara aunque la partida arrancase
pasada su hora de salida. **El usuario lo paró**: *"lo de Lucía sí estaba bien así porque su puesto
está más lejos, déjalo... porque si pongo Documentación más lejos deberá tener la misma lógica"*.
Tiene razón y la lógica ya existía: cada uno sale de casa restando lo que tarda en cruzar la
comisaría, así que **cuanto más lejos esté tu ventanilla, antes madruga su titular**. Revertido con
`git restore`; `personal.gd` queda intacto.

### 🐛 EL FUNCIONARIO INVISIBLE: era una línea borrada, no un problema de dibujo

El usuario lo reportó **cinco veces** y acabó mandando una captura (`capturas/Captura funcionarios.PNG`)
porque yo seguía dando vueltas. En la captura se ve lo importante: **los mostradores y los nombres
están, y del funcionario no hay ni rastro** — no es que estuviera mal colocado, es que no se dibujaba.

Medido (`policia.get_child_count()`): **0 hijos**. El nodo `Policia` existía, estaba bien colocado
una casilla detrás y `is_visible_in_tree()` era `true`... pero estaba **VACÍO**. Al reordenar mesa y
policía dentro del contenedor borré sin querer la línea `_anadir_cuerpo_policia(policia)`.

Todo lo investigado después de ese borrado —orden de dibujo, tamaño de la mesa, capas, z_index—
perseguía un fantasma. Los cambios que salieron de ahí (la mesa al 0,62 de su celda, el orden
mesa→policía) se quedan porque son correctos por sí mismos, pero **ninguno era la causa**.

**Lección de método, la más cara de la sesión**: cuando algo "no se ve", lo PRIMERO es comprobar que
el nodo existe Y TIENE CONTENIDO (`get_child_count()`), antes de tocar una sola línea de posición,
capa o z_index. Y cuando el usuario repite el mismo síntoma más de dos veces, hay que pedirle una
captura en vez de seguir razonando sobre píxeles a ciegas.

---

## 🚶 2026-07-31 — EL MUÑECO DE PIEZAS: la gente ANDA

### Cómo se llegó aquí (la parte útil)

1. Se generó el **primer sprite realista** del policía con Gemini + la imagen del uniforme del CNP
   como referencia. Salió **muy bien**: "POLICÍA NACIONAL" legible con tilde, escudo en la gorra,
   polo azul casi negro, cargo, botas, pose en A. `capturas/policia.jpg`.
2. Se metió en el juego a 72 px como prueba. Veredicto del usuario: ***"dios qué feo, no hay ningún
   tipo de animación al caminar ni nada"***. Y tenía razón.
3. **El diagnóstico correcto no era el sprite**: era que TODO EL MUNDO se deslizaba tieso, los
   rectángulos incluidos. Un muñeco que patina se lee como una ficha de parchís.

### Lo que se hizo: `src/main/muneco.gd`

Muñeco de **piezas sueltas** (piernas, brazos, torso, cabeza, gorra) que el código mueve. Como un
recortable de papel sujeto con encuadernadores: no se redibuja nada, se GIRA cada pieza sobre su
articulación.

- **Piernas** en oposición; **brazos** al revés que la pierna de su lado (así anda una persona);
  **bote** una vez por cada pie.
- Todo sale de **una fase que avanza con el CAMINO RECORRIDO, no con el reloj**. Consecuencias que
  salen gratis: si se para, el ciclo se para; a 3× camina y bota más rápido solo; en Pausa se queda
  quieto sin comprobar la pausa en ningún sitio.
- **`andando` suavizado** (0→1): sin esto, al llegar a la ventanilla se quedaba congelado a media
  zancada como un maniquí de escaparate.
- La **gorra** distingue funcionario de ciudadano a tamaño diminuto — regla del art bible: a ese
  tamaño solo sobrevive la silueta.
- Lo comparten ciudadanos y funcionarios: el andar es el mismo para todos.

**Coste de arte: CERO.** Y no se tira: cuando llegue el arte 3D, cada pieza se cambia por su sprite
y el ciclo sigue siendo el mismo código.

### La lección que deja

El 90 % de la sensación de "está vivo" viene del **movimiento**, no del dibujo. Se comprobó al
revés: un señor fotorrealista perfecto, deslizándose tieso, pareció feo. Rectángulos que mueven las
piernas, no.

### Pendiente de decidir con el usuario

- **Las 8 direcciones**: hoy el muñeco no mira hacia donde anda. Es lo siguiente que se nota.
- El sprite realista queda como **referencia de uniforme** (`design/art/referencias/`), no como arte
  de juego. Sirve para el modelo 3D, que es otra sesión.

---

## ✅ 2026-07-31 — ODAC #9 CERRADO: la última pieza del MVP

**Suite: 698 casos, 0 fallos, exit 0** (685 + 13 nuevos).

### La sorpresa al abrirlo: el modelo YA estaba hecho

Antes de escribir nada se leyó el GDD y el código, y **tres de las cuatro piezas ya existían**:

| Pieza | Dónde estaba ya |
|---|---|
| Prioridad de denuncias (OD3) | `Flujo._rango_prioridad` + `elegir_de_cola` por `(rango, turno)` |
| Peso 2,5× en reputación (F1) | `Paciencia.peso_prioridad_prioritaria` |
| Reconfigurar un puesto (FL9) | `Flujo.reconfigurar_puesto` con `override` |

Lo que faltaba era **la palanca del jugador**: no había forma de usar nada de eso. Por eso ODAC ha
salido pequeño a propósito — **no duplica** lo que ya funcionaba.

### Lo escrito

- **`src/feature/odac/odac.gd`** (`ODAC`): dueño de la POLÍTICA. Los 4 modos (Polivalente / Solo
  prioritarias / Solo normales / A medida), su traducción a listas de denuncias, y
  `denuncias_sin_cubrir()` — el diagnóstico de la válvula anti-inanición. Persistible (grupo
  "Persist"), y al cargar **reaplica** los modos a Flujo (si solo los anotara, el panel diría una
  cosa y el puesto haría otra).
- **`src/main/panel_odac.gd`** (tecla **O**): los tres modos de un clic, cada uno con su frase de
  CONSECUENCIA, y un **aviso en rojo** si alguna denuncia se ha quedado sin ventanilla.
- **`Flujo.tipo_de_puesto_flujo()`**: getter nuevo para que ODAC sepa qué puestos son suyos sin
  mantener una lista propia que se quedaría vieja al construir o demoler.

### La regla de juego que hay detrás (y que el test estrella prueba)

Las urgentes pasan SIEMPRE delante y no hay envejecimiento de cola en el MVP: si llegan urgencias
seguidas, **las administrativas pueden no atenderse nunca**. La reconfiguración ES la válvula.
`test_avisa_de_las_denuncias_que_se_quedan_sin_ventanilla` y
`test_dedicar_una_ventanilla_a_normales_lo_arregla` prueban exactamente eso.

### Alcance declarado

El modo **"a medida"** está en el modelo y probado (incluido que descarta tipos inventados de un
save manipulado) pero **no tiene botón**: son 13 casillas por puesto y eso es UI fina de UI/HUD #11.
Se prefirió no ofrecerlo a medias.

---

## 2026-07-31 (tarde) — FICHA DE VENTANILLA, BIENESTAR CERRADO Y VEREDICTO DE LA TEXTURA

### La ficha de ventanilla (clic izquierdo sobre una ventanilla)

Petición del usuario: *"tipo tycoon, cuando se pulsa sobre algo y se detalla"*. Cuatro bloques:

1. **AHORA MISMO** — qué trámite se gestiona y cuánto queda. Si el ciudadano está llamado pero aún
   viene andando dice *"viene de camino"*, no minutos: el trámite todavía no ha empezado y decir
   minutos sería mentir.
2. **QUIÉN LA LLEVA** — con el cansancio **y su consecuencia al lado**: `47 % (+12 % más lento)`.
3. **EFICACIA, DESCOMPUESTA** — catálogo / lo que pone su agente / lo que quita el equipamiento /
   atenciones por hora. Un número solo dice que algo va mal; el desglose dice **qué tocar**.
4. **MANDOS** — en ODAC, los 3 modos + las 13 denuncias una a una; en Documentación, el horario
   (misma API que el panel H, no una copia), la peonada con su coste en €/día, el precio de la hora
   extra y el "se queda por la tarde" de esa ventanilla.

### 🐛 DOS FALLOS DE UI, Y LOS DOS DEJAN REGLA

**1. El panel no se veía.** Se usó `PRESET_TOP_RIGHT`, que ancla a un PUNTO (la esquina); con ese
anclaje `offset_bottom = -100` se mide desde ese punto y el panel quedaba de **altura negativa**.
→ **Regla**: para una columna pegada a un borde, anclar arriba Y abajo a mano, no con el preset de
esquina.

**2. No se podía pulsar nada.** El panel se reconstruía entero **60 veces por segundo**, botones
incluidos: cada control se destruía antes de que al clic le diera tiempo a completarse.
→ **Regla, la importante**: **jamás reconstruir por frame un contenedor con controles
interactivos.** Ahora está partido en `_caja_viva` (solo etiquetas, se repinta por frame) y
`_caja_mandos` (controles, se construye una vez y al cambiar un modo).

### Bienestar #13 — cerrado el último hueco: DESCANSO IN SITU

Desde que los muros bloquean el paso, la sala de descanso puede quedar **incomunicada**. Antes: el
funcionario salía a buscarla, no llegaba, el viaje se cerraba a la fuerza y se quedaba
"descansando" para el modelo **sin aparecer por ningún lado**; su ventanilla se quedaba vacía sin
explicación. Ahora se comprueba el camino ANTES de salir (`Construccion.distancia_en_celdas`): si no
hay, se toma el café **en su sitio**, con su taza y sin perder la pausa — sería castigarle por una
obra que él no ha decidido. Igual si tampoco puede salir a la calle.

**Guía de sign-off** en `production/qa/evidence/bienestar-13-signoff.md`: 7 puntos a comprobar en la
ventana, incluido cómo provocar el caso nuevo (encerrar la sala de descanso sin puerta). Es lo que
los tests NO pueden verificar: que se entienda y que se vea. **Pendiente del usuario.**

### ❌ VEREDICTO: la textura `stylized-girl.zip` NO se usa

El usuario descargó un asset para hacer policías mujeres. Abierto y analizado:

| Qué trae | Veredicto |
|---|---|
| `sell on sketchfab2_.fbx` (9 mallas, 40 materiales) | **Sin esqueleto**: 0 `Deformer`, 0 `Skin`, 0 `AnimationStack`. Es una estatua, no puede andar |
| `___.png` 2048×2048 | Es el **mapa UV** de la cara desplegada, no un sprite. Solo cabeza: **no hay uniforme** |
| El nombre del archivo | *"sell on sketchfab"* → **asset de pago**. Muchas licencias de Sketchfab prohíben usarlo en un juego que se vende |

Los tres problemas son el mismo del policía 3D de anoche, más el de licencia, que es el que no tiene
arreglo técnico. **Alternativa recomendada**: las mujeres policía se resuelven en el muñeco de
piezas — una pieza de pelo y repartir el género por número de turno, igual que ya se hace con los
cuatro tonos de piel. Funciona hoy y no depende de la licencia de nadie.

---

# 🎨 CIERRE DE SESIÓN 2026-08-01 — EL PIPELINE DE ARTE 3D→SPRITES, Y QUÉ HACER MAÑANA

**Estado verificado en el hilo principal: 698 casos, 0 fallos, exit 0. Arranque limpio. `datos/`
intacto. Todo commiteado y pusheado.**

## ⭐ DECISIÓN DEL USUARIO: EL ESTILO ES **LOW-POLY**

Cierra la última pregunta abierta del art bible. Consecuencias prácticas:
- Encaja con el pipeline que ya existe (3D → sprites): low-poly renderiza rápido y se lee limpio al
  reducir a 44 px.
- Se acabó el debate "realista vs Two Point": **low-poly con tono Two Point**.
- Y encaja con los assets que se están descargando, que son low-poly.

## LO QUE YA FUNCIONA (y NO hay que rehacer)

### `tools/render_sprites.gd` — el pipeline completo
Convierte cualquier modelo 3D con esqueleto en los sprites del juego. **Es código, va en git, no se
pierde.** Lo que genera son PNG en `assets/sprites/personajes/`, que también van en git.

```
godot --path <proyecto> res://tools/RenderSprites.tscn
```

Produce, para el prefijo configurado: **8 direcciones × 8 fotogramas de andar + 8 de sentado**, en
dos tamaños (88 y 44 px).

**Las cinco cuentas que costó acertar** (todas documentadas en el archivo):
1. **Cámara a 26,565°** (`atan(1/2)`), no a 30°: es el ángulo del rombo 2:1. Con 30° los pies no
   pisan el suelo.
2. **Ortográfica**, no en perspectiva: si no, un personaje en el centro y otro en la esquina se ven
   con inclinaciones distintas.
3. **La orientación se MIDE, no se supone**: se saca de los pies del modelo (del talón a la punta).
   Suponerla hizo que los ciudadanos entraran de lado andando hacia atrás.
4. **El balanceo va sobre el eje lateral DEL PERSONAJE**, no sobre un eje fijo del mundo. Con un eje
   fijo, la pierna se adelanta hacia donde mira el escenario.
5. **Todas las poses se escalan con el MISMO factor**, sacado de la figura de pie. Ajustar cada
   imagen a la misma altura ampliaba a la figura sentada.

### Lo que hay montado en el juego
- Ciudadanos con sprite 3D: andan, giran a 8 direcciones y **se sientan** (en la silla de la espera
  y en la de la ventanilla), solo cuando están parados y mirando siempre al norte.
- Funcionarios con el **muñeco de piezas** (rectángulos articulados), que sigue siendo válido y sirve
  de comparación. **No se ha tirado**: el día que haya sprites de policía, se cambia y ya.
- Sillas: dos por ventanilla (funcionario y ciudadano) y con respaldo en la sala de espera.

## 📦 EL PAQUETE DE OFICINA (lo que trae, medido)

`capturas/NPC/Oficina/isometric_office.glb` — **FUERA DE GIT a propósito** (164 MB; ver `.gitignore`).

| | |
|---|---|
| Mallas | **748** |
| Triángulos | ~155.700 |
| Materiales / texturas | 48 / 22 |
| Esqueleto y animaciones | Ninguno (es mobiliario) |
| Nombres | `Object_10`, `Object_1023`… **genéricos**: no dicen qué es cada cosa |

⚠️ **FALTA SU LICENCIA Y SU ATRIBUCIÓN.** No entra en `assets/` hasta que esté su fila en
`CREDITS.md` — es la regla del proyecto. Preguntar al usuario de dónde salió.

## 🎯 PLAN PARA LA PRÓXIMA SESIÓN: "darle caña a los diseños"

### 1. El catálogo visual de la oficina (lo primero, y es una herramienta)
Con 748 mallas llamadas `Object_NNN` no hay forma de saber qué es cada una. **Escribir una variante
del renderizador que saque una miniatura de CADA malla por separado**, montar una hoja de contactos
y que el usuario elija a dedo: "esta es la mesa", "esta la silla", "esta la planta".

Es exactamente el mismo patrón que ya funcionó cuatro veces esta noche: **mirar en vez de suponer.**

### 2. Sustituir el mobiliario placeholder
Los muebles del juego son cajas isométricas dibujadas por código (`PiezaIso`, `mesa_atencion.gd`).
Cambiarlas por sprites renderizados del paquete: mesa, silla, ordenador, planta, papelera, vending.
El sitio donde se enchufa ya está aislado.

### 3. El policía en low-poly
Falta el personaje que de verdad importa. Dos caminos: buscar un modelo low-poly con **pantalón** y
licencia CC BY, o vestir el que hay en Blender. La referencia del uniforme del CNP ya está
verificada en `design/art/referencia-uniforme-cnp.md`.

### 4. Cerrar el art bible §5
Sigue sin decidir: personajes **sin cara** vs **cara mínima**. Con los sprites ya en pantalla a 44 px
es una decisión de dos minutos: mirar si la cara se ve.

## ⚠️ GOTCHAS NUEVOS DE ESTA SESIÓN (leer antes de tocar arte)

1. **Todo PNG generado por herramienta necesita `--import` antes de que el juego lo vea.** Si no,
   `ResourceLoader.exists()` da false y el juego se cae al placeholder sin avisar.
2. **Después de `--import`, comprobar `git status -- datos/`**: arranca el editor y ya reescribió un
   `.tres` una vez (tumbó un test que no tenía nada que ver).
3. **Una pose de esqueleto se define ENTERA.** Todo hueso que toque alguna pose, las demás tienen que
   devolverlo — si no, se heredan restos. Fue el "andan de rodillas".
4. **Nunca reconstruir por frame un contenedor con controles interactivos**: los botones se destruyen
   antes de que el clic se complete y no se puede pulsar nada.
5. **Anclar un panel a un borde con anclajes a mano**, no con `PRESET_*_RIGHT`: ese preset ancla a un
   PUNTO y los offsets se miden desde ahí (panel de altura negativa = invisible).

## MÉTODO: lo que más valor ha dado hoy

Cuatro bugs, cuatro veces que **medir** resolvió en un minuto lo que suponer no resolvía en veinte:

| Síntoma | Qué se midió | Causa real |
|---|---|---|
| Funcionario invisible | `get_child_count()` = 0 | Le faltaba el cuerpo (línea borrada) |
| 6 funcionarios para 3 puestos | Quién arranca viaje, en ventana real | Bucle crear/destruir |
| Andan de lado y hacia atrás | Las 8 direcciones etiquetadas | Rumbo de pantalla vs de mundo |
| Andan de rodillas | El flag de sentado en vivo | Pose heredada del sentado |

Y una que se resolvió **probando las cuatro combinaciones y mirando**: los signos de cadera y rodilla
al sentarse. Con rigs ajenos no se deduce: se renderiza y se mira.

---

# 🎨 2026-08-01 (noche) — SESIÓN DE DISEÑOS EN CURSO (Fable 5 coordina, subagentes ejecutan)

**Estado verificado al arrancar: 698/698 casos, 0 fallos, exit 0 de GdUnit · arranque headless limpio
· árbol limpio.** Modo de trabajo: ultracode (el usuario lo pidió) — subagentes Sonnet 5 en paralelo,
Fable 5 verifica TODO mirando archivos/PNG, no informes.

## Hecho y commiteado

- **`a720398` docs(legal)**: las TRES atribuciones completas en CREDITS.md, aportadas por el usuario:
  policías "Police Officer Portrait"/"in Uniform" de **restore50** (CC BY 4.0) y "Isometric office"
  de **Companion_Cube** (CC BY 4.0). Nota: del pack de oficina solo se usa la GEOMETRÍA — sus
  texturas incrustadas (pósters/cuadros/fotos) son material de terceros sin procedencia clara y NO
  entran en el juego. (El usuario pidió no mencionar el origen televisivo del pack: respetado, no
  consta en ningún doc.)
- **`d98614f` feat(arte)**: `tools/render_catalogo_oficina.gd` + `.tscn` — catálogo visual v1 del
  pack: 748 miniaturas aisladas (una por malla) + hoja de contactos `index.html` + manifiesto JSON
  con la posición mundial de cada instancia. Los PNG quedan fuera de git (`capturas/`).
  **Bug cazado EN VERIFICACIÓN, no por el informe del agente**: las mallas se acumulaban en el
  viewport y cada foto salía con vecinos colados (la misma pared verde en fotos distintas la
  delató). El agente se quedó DOS VECES sin turno antes de mirar sus PNG — la regla del traspaso
  ("verifica tú mismo") pagó la sesión entera.

## ⭐ Descubrimiento clave: los dos policías de Sketchfab NO SIRVEN

Radiografiados con Python (chunk JSON del GLB) y **verificado por el hilo principal**: `skins=0,
joints=0, animaciones=0` en ambos. Son ESTATUAS de una pieza (y encima 335K/290K triángulos, ×30 el
estilo low-poly). Cuerpo entero sí ("Portrait" era solo el título), pero sin esqueleto no andan, no
se sientan, nada. Quedan "En evaluación" en CREDITS.md; si no se usan → tabla de descartados.

## ⭐ Los sustitutos: pareja "Male/Female Officer" de J-Toastie (poly.pizza, CC BY 3.0)

Un explorador web barrió Sketchfab (por API)/poly.pizza/Quaternius/Kenney. La pareja ganadora está
**ya descargada** (sin login, CDN público) en `capturas/NPC/Policias/candidatos/` y radiografiada:
- 0,27 MB y ~5.100 tris cada uno (low-poly DE VERDAD), un personaje por archivo.
- **Esqueleto de 27 huesos + 5 animaciones propias** — incluida `Armature|Walk`. No hay que
  inventarles el andar.
- **SIN codos ni rodillas** (brazo y pierna = una pieza; convención `.L`/`.R`: `Foot.L`, `Hand.R`,
  `CORE`…). Consecuencia: el sentado no existe y hay que TRUCARLO (pierna entera a la horizontal +
  bajar el cuerpo). A 44 px y con el mostrador tapando piernas puede colar — SE DECIDE MIRANDO.
- Uniforme muestreado sobre la malla: azul marino casi negro (tono CNP). Textura = paleta de
  franjas `GGrid.png` compartida byte a byte por ambos (misma familia visual garantizada).

## En marcha ahora mismo (2 subagentes en background)

1. **Catálogo v2 "objetos enteros"**: el usuario vio la v1 y los muebles salen DESPIEZADOS (ruedas
   / asiento / respaldo sueltos: el pack está horneado así). El agente agrupa por proximidad de
   AABBs mundiales (manifiesto v1), arquitectura aparte, y renderiza cada cluster montado →
   `catalogo/objetos/` + `index_objetos.html`. AVISAR AL USUARIO Y ABRIRLE LA HOJA al terminar.
2. **Render de prueba de la pareja J-Toastie**: `tools/render_sprites_animado.gd` (variante que
   MUESTREA la animación embebida en vez de posar huesos; carga por GLTFDocument para no pasar por
   `--import`): 8 dir × 8 fotogramas de andar + reposo + 4 variantes de sentado trucado →
   `candidatos/render_test/` + hoja. El usuario da el veredicto MIRANDO.

## Pendientes de esta sesión

*(Sección histórica — TODO lo de aquí abajo se COMPLETÓ durante la propia sesión: policías
aprobados, integrados y con orientación corregida; §5 cerrado; mobiliario elegido pieza a pieza
por el usuario e integrado en dos tandas; CREDITS al día con J-Toastie EN USO.)*

---

# 🏁 CIERRE DE SESIÓN 2026-08-01 (madrugada/mañana) — TRASPASO

**El prompt de traspaso COMPLETO está en `production/session-state/traspaso-proxima-sesion.md`
(leerlo entero: modo de trabajo, estado, tarea siguiente, gotchas nuevos y reglas).** Resumen de un
vistazo:

- **EN EL JUEGO**: policías J-Toastie (andar+sentado+8 dir bien orientadas, género por nombre) y
  9 muebles del pack (mostrador con teléfono, pantallas, papelera, dispensador, radio, sofá 3
  plazas, 2 sillas). Suite 698/0 verificada en cada pasada. Pusheado hasta `955332e`.
- **⚠️ EN VUELO al cerrar**: el fix de capas/orientación de las sillas de la ventanilla (ADR-0005,
  mecanismo de capas con nombre) — un agente quedó trabajando; VERIFICAR SU ESTADO es el primer
  paso de la sesión siguiente (git status + composites + suite).
- **DISEÑO CERRADO listo para implementar**: la mecánica de la impresora de documentos
  (design/gdd/impresora-documentos-tramite.md) — objetos obligatorios por sala, viaje del papel,
  mantenimiento por turno de uso (2 €/turno). Es la tarea estrella de la próxima sesión.
- **Fuente de verdad del mobiliario**: design/art/mapa-integracion-mobiliario.md (decisiones del
  usuario fila a fila + ideas futuras: seguridad de entrada, despacho Judicial, decoración pared).
- **Reglas nuevas**: ADR-0005 (orden de capas fijo, prohibido add_child suelto en contenedor
  compartido) + arranque en pausa con `-- --pausa` para los hitos visibles.
- Pendientes heredados: sign-off Bienestar #13 · U9 muros · ODAC "a medida" en panel O · falda de
  girl · pantalla de créditos del juego (obligación CC BY) · impresora de DNI sin asset.

---

# ⚡ CIERRE RÁPIDO 2026-08-02 (usuario apaga el equipo)

HITO CASI CERRADO: "huella exacta + mostrador 2 celdas". TODO el trabajo está en disco:
- Cámara de render corregida (26,565°→30°) + cubo de calibración (0,498/0,498 ✓). TODOS los
  sprites re-renderizados con base EXACTA a sus celdas (mostrador2 2,000 · sofá 3,025 · legado 0,975).
- MODELO: puesto huella 2×1 (ancla=celda de trabajo, cuerpo al ESTE, dato en catálogo superficie=2),
  migración idempotente de saves (legado si no cabe), tests nuevos. Unit 333/333 + integración 376/376
  verificados por agentes; VERIFICACIÓN FINAL MÍA de la suite completa en curso al cerrar.
- INTEGRACIÓN VISUAL: regla "sprite ancla en la ÚLTIMA celda del cuerpo" (Proyeccion.delta_ultima_celda),
  mesa_atencion con 2 sprites (2 celdas / 1 legado, ancla 0.501,0.747), navegación recorta el cuerpo entero.
- DECISIONES DEL USUARIO HOY: rejilla implacable para TODO · REHACER LA COMISARÍA INICIAL (salas para
  puestos 2×1 + impresora obligatoria TIE/ODAC + descanso + 2 esperas) — diseñar plano CON él ·
  rotaciones con capas por ángulo (borrador docs/architecture/borrador-orden-profundidad-rotaciones.md).
- PENDIENTE INMEDIATO SESIÓN SIGUIENTE: si no hubo commit, pasar suite completa → commit por hitos →
  abrir en pausa → veredicto del usuario. Después: plano comisaría nueva → impresora completa (GDD cerrado).

---

# 🏁 CIERRE DE SESIÓN 2026-08-03 (por contexto) — TRASPASO

**El prompt de traspaso COMPLETO está en `production/session-state/traspaso-proxima-sesion.md`
(leerlo ENTERO: leyes nuevas, 3 tareas en vuelo con su estado de disco, cola y comandos).**
Resumen de un vistazo:

- Sesión MARATÓN de calidad visual con el usuario dirigiendo en vivo: investigación completa
  (plan-calidad-visual.md + sintesis-como-hacer-un-tycoon.md, listón = BIG PHARMA), ventanilla
  FIRMADA como escena patrón, unidad 2×3, MundoProfundo (y-sort fase 1) implementado, sofá a 2
  celdas con sus 3 respaldos, muros modelo Sims por tramo.
- **LEY nueva Nº1 (la dio el usuario)**: AUTO-ANCLAJE POR LÍMITES — los sprites se colocan
  midiendo sus propios píxeles contra su huella; muere la cadena de anclas a mano que causó el
  bucle de horas. EN VUELO al cerrar (con puertas y accesos/señal 🚫) — ver traspaso.
- Commiteado y pusheado hasta `041284c` (suite 713/713 Exit 0 en ese punto). WIP de 3 agentes SIN
  commitear, documentado archivo a archivo en el traspaso.

---

# ✅ CICLO CERRADO 2026-08-04 (sesión siguiente al traspaso)

Las 3 tareas en vuelo del traspaso están TERMINADAS, verificadas y commiteadas:
- `116a1f2` puertas (cualquier tramo + acuse verde/rojo + fantasmas muertos; causa raíz: dos
  caminos de dibujo por arista en paredes_salas.gd). Test regresión 5/5.
- `86cd75d` accesos (sin camino ⇒ sin teletransporte, señal 🚫, recheck ~3 s; bug extra cazado:
  hay_camino bloqueaba todo origen en la CALLE — arreglado con CELDA_PUERTA_SALIDA). Test 4 casos.
- `2fcbb8f` AUTO-ANCLAJE POR LÍMITES (AnclajeSprite en foundation/proyeccion): mostradores, sofá y
  4 comodidades medidos de sus píxeles; 7 constantes de ancla borradas; DESVIO_CENTRADO_MESA a
  ZERO. Test de esquina C4/C5 delta (0.0, 0.0) PASA. **Mesa aprobada por el usuario en imagen
  ("me vale así si") ANTES de commitear** — regla nueva reforzada: todo tema visual (tamaño/
  posición/objeto nuevo o mejorado) se le enseña en imagen CON CELDAS antes de su OK.
- Suite completa tras todo: **722/722 Exit 0** + arranque headless limpio (solo warning puesto_tie).

PENDIENTE INMEDIATO: cola del traspaso — plano de la comisaría inicial NUEVA (con el usuario),
impresora de documentos (GDD cerrado), Fase 2 plan visual (hero asset ventanilla). Menor: señal 🚫
se ve algo grande → proponer A/B/C en imagen con celdas cuando toque.

---

# ✅ PAQUETE GRANDE 2026-08-04 (segunda tanda del día)

Pedido del usuario ejecutado entero, con su spec literal en
design/quick-specs/construccion-pintura-puertas-preview-2026-08-04.md:
- `2fd16b5` tests: ventanas end-to-end (9) + "se entra por el hueco de la puerta" verificado
  con trayectoria real (0 bugs — la navegación ya lo respetaba; ahora con regresión).
- `ab3f936` CIUDADANOS: 7 modelos civiles serie CUTES (J-Toastie, CC BY) aprobados en hoja
  ("me valen los diseños"); 1008 sprites; reparto determinista por nombre en npc_ciudadano.gd;
  girl sustituido. PENDIENTE: variantes de color ropa/pelo (hoja al usuario).
- `63a0a4e` CONSTRUCCIÓN: pintura (paredes blancas por defecto + pincel + paleta 30 en
  paleta_pintura.gd + suelo por celda + MAYÚS=sala + persistencia) · puerta manual (muere el
  hueco automático; al amurallar, el jugador coloca la puerta; Esc = sin puerta con señal 🚫) ·
  preview fantasma estilo tycoon (sprite real translúcido vía AnclajeSprite, rojo si inválido).
- `7bbb510` ESTANTERÍAS: estanteria (130 €) + estanteria_pequena (80 €) PROVISIONALES,
  ARRIMADO A PARED medido de píxeles (0.00 px contra la línea de pared, 16/16 diag).
  HALLAZGO: esquina con 2 sueltas deja ~1 celda de hueco (estructural) → si el usuario quiere
  esquina perfecta, pieza en L propia (OBJ_022 completo, 2 celdas). DECISIÓN PENDIENTE.
- Suite completa tras todo: **767/767 Exit 0** + arranque headless limpio (warning puesto_tie).

DECISIONES PENDIENTES DEL USUARIO: precios definitivos estanterías · pieza esquina en L sí/no ·
variantes de color de ciudadanos (hoja por hacer) · los colores de pared elegidos los pinta él
en el juego (paleta completa disponible).

---

# 🔌 SESIÓN 2026-08-05 — Summer Engine probado + CONEXIÓN MCP EN CURSO

- Suelo de baldosas (generado por Summer, auditado y adoptado): commit `38ea5b0`. Deuda: tests del suelo.
- COMPARACIÓN props (7 modelos poly.pizza, capturas/fuentes/props_poly/): NUESTRO pipeline ganó
  (demo con arrimado 0.00px + sobremesa sobre tablero medido, tools/_demo_props_pipeline.*) vs
  Summer (3 intentos, 2 rescates del coordinador, props colocados fuera del edificio).
  Veredicto usuario PENDIENTE de confirmar con ambas capturas delante; decisión de integración de
  los 7 props al catálogo TAMBIÉN pendiente (hoja v2 aprobación parcial: "pequeños o en el centro"
  → resuelto en la demo). OJO: Summer dejó sprites propios en assets/sprites/mobiliario/
  ({taquilla,vending,...}_*.png SIN prefijo comodidad_) y una carpeta demo/ — SIN commitear, decidir
  si se borran al integrar los props de verdad.
- MCP: integración Summer↔Claude Code ES OFICIAL (docs.summerengine.com/mcp/claude-code, puerto
  6550, requiere la app abierta con el proyecto). Setup lanzado con
  `npx -y summer-engine@latest setup claude-code --yes`. TRAS EL REINICIO: probar conexión con algo
  inofensivo (summer_play + summer_screenshot), reglas pactadas: commit antes de sesión con Summer,
  nunca dos editores a la vez, generación de pago solo con OK del usuario por uso, todo auditado.
- PENDIENTES DEL USUARIO (sin cambios): puerta A/B · ventana tal cual/ensanchada · props 7 OK →
  integración con soportes para sobremesa · 5 mejoras del guion (propuestas, sin luz verde aún) ·
  hoja puertas/ventanas → integrar arte en tramos tras decisión.
- EN VUELO al cerrar: nada de agentes (todos cerrados). Tools de la sesión sin commitear:
  _render/_hoja/_diag props, _demo_props_pipeline (se commitean ahora), morralla vieja intacta.

---

# 🎨 CIERRE 2026-08-05 (2ª parte) — el usuario aplica cambios visuales CON SUMMER

- Commiteado antes de soltar el terreno: `643cbf7` = suelo limpio + rodapié en pared + rejilla
  solo al construir (123/123 dirigidos + arranque limpio; suite COMPLETA no re-corrida — pasarla
  en la próxima sesión) + renders props v3 preservados en capturas/fuentes/props_poly/renders_v3/.
- El usuario decidió aplicar "todos los cambios" visuales pendientes ÉL MISMO con Summer Engine
  (paleta clara estilo su demo: suelo crema ~(0.87,0.84,0.78), paredes azul suave ~(0.72,0.78,0.88)
  o blancas; y lo que él decida). PRÓXIMA SESIÓN: auditar TODO el diff de Summer contra `643cbf7`
  (git diff, archivo a archivo), pasar suite completa, revertir churn de project.godot/Main.tscn
  si aparece, y commitear por hitos lo que valga. NO asumir que las decisiones pendientes
  (puerta A/B, ventana, props, paleta) se tomaron — preguntar qué hizo con Summer.
- Agente de hoja de paleta DETENIDO sin obra (no estorba). Hoja v3 de props enseñada, sin
  veredicto aún.

---

# 🎨 SESIÓN 2026-08-05 (3ª parte) — paleta clara vía Summer MCP + fachada pintable + plan de escalado

- AUDITORÍA del terreno tras la sesión Summer del usuario: NO había obra de Summer en código
  (solo docs del cierre, commiteados en `0014d8e`). Suite completa verificada: 774/774.
- CONEXIÓN MCP SUMMER OPERATIVA: paleta clara aplicada VÍA SUMMER (summer_replace_text, flujo
  summer_start_game_task): COLOR_PARED_POR_DEFECTO azul suave (0.72,0.78,0.88) ·
  COLOR_SUELO_POR_DEFECTO crema nuevo (0.87,0.84,0.78) · COLOR_SUELO de main.gd crema.
  Gotcha: main.gd es CRLF → summer_replace_text multilinea falla ahí; usar old_text de UNA línea.
- PAQUETE (agente Sonnet, 5 reanudaciones con receta numerada — patrón: se para cada ~20 tools):
  fachada PINTABLE (sigue sin demolerse, con test) · pintar_edificio_muros/suelos + gesto MAYÚS
  ampliado (fachada→todo el edificio; suelo sin sala→todas las baldosas; MAYÚS sala intacto) ·
  tests reescritos sin debilitar (nace color por defecto, no blanco) · tools/_diag_alturas_pared.
- PLAN DE ESCALADO: design/art/plan-escalado.md (ancla 44px=1,70m, PX_POR_METRO≈25,88, tabla
  completa con mediciones reales — script del art-director ejecutado por el coordinador, borrado
  tras uso). REVISAR gordos: estanterías (~3,1m la grande), dispensador viejo (~2,7m), sillas/
  sofás inflados (ojo: el alto útil incluye base isométrica, % exagerados en huella 2 celdas).
  Impresora DNI especificada (1,50m, ancha, azul, 1 celda, del usuario).
- SUITE COMPLETA FINAL: **776/776 Exit 0**. SIN COMMITEAR a propósito: espera el veredicto visual
  del usuario (ley 3). 4 fotos alturas_pared_{34,48,65,70}.png en scratchpad ENSEÑADAS (34=1,30m
  actual · 48=1,85m · 65=2,50m · 70=2,70m oficina). ALTO_PARED sigue en 34.0 hasta que elija.
- DECISIONES PENDIENTES DEL USUARIO: altura de pared (4 fotos) · tinte de salas (¿claro u
  oscuro?) · hoja props v3 · puerta A/B · ventana · lote REVISAR de proporciones (hoja con
  muñeco por hacer tras decidir altura).

---

# ✅ CONTINUACIÓN 2026-08-06 — pared 65px (medida de la referencia) + UX Sims + pintura por CARA

- Commit `dab56de` (aprobado por el usuario con captura): paleta clara + fachada pintable +
  MAYÚS edificio + pared 65px (proporción MEDIDA de captura_demo_props: 120/81 = 1,48× muñeco)
  + selector tramo completo + preview MAYÚS + velo de zonas + acabado suelo baldosa/liso +
  plan-escalado.md. Suite 779/779.
- PINTURA POR CARA (quick-spec 3f, pedido literal) + PICKING POR QUAD (bug real confirmado:
  con pared de 65px el picking de suelo seleccionaba la arista 2-3 filas al norte): modelo
  clave_de_cara :a/:b (b = celda de mayor coordenada = cara que dibuja ParedesSalas), sala
  pinta caras interiores, edificio pinta fachada solo interior, migración de saves viejos a
  ambas caras, tramo_bajo_punto point-in-quad con fallback a suelo (muro nuevo intacto).
  Captura ux_caras_pintadas.png ENSEÑADA y aprobada la mecánica. Suite completa 783/783 Exit 0.
- Gotcha de sondas _diag con ModoConstruccion: su _process pisa el estado forzado con el ratón
  real fuera del tablero → set_process(false) en la sonda (documentado en _diag_ux_pintura.gd).
- INVENTARIO DE OBJETOS QUE FALTAN entregado al usuario (agente Explore): 🔴 impresora de
  documentos (bloquea GDD estrella, sin sprite ni .tres) · 🟠 impresora DNI (tres existe 2.200€,
  falta arte) / mesa de trabajo / mueble soporte / puerta+ventana arte / fuente 1,60 re-render ·
  🟡 lámparas, prensa, revistero, nevera, máquina café (cajas de código) · 🔵 taquilla+archivador
  (arte sin objeto) y duplicado dispensador vs fuente_agua.

---

# 🏁 CIERRE DE SESIÓN 2026-08-06 — LOTE GORDO: impresora completa + 2 bugs de raíz + reparto Summer

- **⭐ MECÁNICA DE LA IMPRESORA DE DOCUMENTOS implementada ENTERA** (Opus, GDD cerrado):
  src/core/impresora/ (módulo + config), viaje del papel solapado con la atención (decisión 1:
  Reglas>AC del GDD), mantenimiento 2€/turno de uso como knob general de Comodidad,
  comodidades_obligatorias/puestos_minimos en TipoSala, colocación derivada detrás del puesto
  (Doc (6,1) tras el TIE · ODAC (9,1)), salas nuevas del jugador la COMPRAN (600€), 38 tests
  nuevos. Decisiones 1-9 del agente en su informe (transcript). PENDIENTES de enganche: muñeco
  visual del viaje (npcs_flujo, API fase_de/impresora_de/restante_de lista), ficha ventanilla
  ("🖨 a por el documento", texto_ventanilla() listo), demolición de impresora desde la UI
  (impresora_demolida() sin llamar), datos/config/impresora.tres (cae a defaults).
- **BUG NAVEGACIÓN arreglado de raíz** (atravesaban paredes): rutas cacheadas sin invalidar —
  Construccion.version_layout (static, ++ en _refrescar_visual) + chequeo O(1) por frame en
  npc_ciudadano → re-pathfinding al cambiar el edificio. Regresión 5 casos (4 lados + muro
  tras ruta) en tests/integration/flujo/flujo_muro_tras_ruta_test.gd.
- **BUG CAPAS arreglado de raíz** (estructural, Opus): los muñecos ANDANTES entran en la bolsa
  y-sort (muere el z2 "gente siempre encima" de la era pared-17px); rótulos/barras/🚫/☕ a
  Z_ROTULO_FLOTANTE 6 (info siempre visible). Escalera de capas nueva documentada en
  npcs_flujo.gd. Silla: NO era bug (respaldo 35px > murete 32.5px; el usuario lo dio por BUENO).
  Tests: construccion_orden_{silla,muneco}_pared_test.gd.
- **REPARTO NUEVO (memoria persistente reparto-summer-arte)**: TODO el arte lo genera SUMMER
  (login CLI hecho: cloud SIN app abierta, verificado con summer_search_assets), Claude dirige/
  audita/integra, el usuario aprueba y autoriza cada gasto. FACTOR DE PRESENCIA 1,25 elegido
  con hoja A/B/C (plan-escalado.md §1): objetos = metros × 25,88 × 1,25; personajes y
  arquitectura sin factor.
- **1ª PIEZA DEL REPARTO**: fotocopiadora de Summer (duelo ganado a nuestra composición "deja
  bastante que desear" según el usuario) → comodidad_impresora_documentos_*.png a 39px,
  rotaciones por ESPEJO desde la vista 0° (las 4 "vistas" de la IA eran el mismo ángulo — 
  LECCIÓN: para rotaciones reales pedir a Summer el modelo 3D y rotarlo con nuestro pipeline).
  Cableada en _sprites_comodidad(). Originales en capturas/fuentes/impresora_summer/. CREDITS
  al día (generación propia vía Summer).
- **SUITE COMPLETA DEL LOTE: 834/834 Exit 0** + arranque limpio. Todo commiteado (ver git log).
- Gotchas de sesión: summer_replace_text multilinea FALLA en archivos CRLF (main.gd) → old_text
  de una línea · sondas con ModoConstruccion → set_process(false) · los PNG de "4 direcciones"
  de la IA de Summer NO son rotaciones reales.

---

# ⭐ HITO 2026-08-06 (sesión Fable, commit 9a5b72b) — 4 posiciones + impresora DNI

- **Rotación 4 posiciones REAL** (pedido del usuario): R cicla 0/90/180/270, huella traspuesta
  en 90/270, sprites rotacion_directa con fallback 2 vistas, migración saves (1→90). 12 tests.
- **Triángulo azul de orientación** en preview de colocación (capa UI construcción, no y-sort).
- **Impresora de DNI integrada**: modelo 3D Summer (plan Pro CONTRATADO hoy; ~3% cupo/pieza),
  aprobada "tal cual" por el usuario (alta ~2,30m, imponente), 4 vistas reales del pipeline
  propio a 58px, comodidad_impresora_dni_*, superficie=2, CREDITS al día. GLB en
  capturas/fuentes/impresora_dni_summer/.
- **Spec mecánica DNI DECIDIDO** (design/quick-specs/impresora-dni-quick-spec.md): cola FIFO
  por máquina, ámbito por sala, OBLIGATORIA a 2.200€ (decisión usuario, excepción a regla
  600€), sustituye bonus pasivo, malus enfado clamp [1.0,1.3], ratio 1:10 atasco / 3-4:10
  fluido (Sakasegawa). PENDIENTE DE IMPLEMENTAR (historia futura).
- Suite 850/850 Exit 0 + arranque limpio. Sondas nuevas desechables en tools/ (_diag_triangulo,
  _diag_rotacion_4, _diag/render/hoja impresora_dni*).
- **Estrategia de gasto Summer pactada**: pago solo piezas protagonistas; gratis vía KayKit
  local (nevera fridge_A/B, lámparas, mesas, sillas/sofás/estanterías para lote REVISAR),
  biblioteca Summer (árboles/setos/farola/calzada excelente; SIN oficina/electrodomésticos),
  7 sprites viejos de Summer ya pagados. Único hueco de pago detectado: revistero.

## 📌 PEDIDO DEL USUARIO (2026-08-06, durante playtest — PENDIENTE, tras los bugs del cursor):
Viaje del papel VISIBLE de punta a punta: el policía vuelve de la impresora CON un papel en
las manos → gesto de entrega al ciudadano en la ventanilla → el ciudadano sale de comisaría
con el papel a la vista. (Extiende el viaje visual de npcs_flujo recién cableado; aplica a
impresora de documentos y en su día a la de DNI.)

## 🐛 BUG DEL PLAYTEST (2026-08-06): el viaje visual de la impresora ATRAVIESA LA MESA
El policía va en línea recta a la impresora (cruza el mostrador/mesa, sin esquivar mobiliario)
y a la vuelta pasa por el NPC/ciudadano antes de volver a su silla (parada intermedia rara).
Arreglar JUNTO con el papel visible (mismo código, npcs_flujo/_camino_impresora): usar el
pathfinding real con obstáculos (como los ciudadanos), coreografía ida→recoger→mesa→entrega.

## ✅ DECISIÓN DEL USUARIO (2026-08-06): VENTANAS EN LA FACHADA — SÍ
Se abre la regla "la fachada no se toca" SOLO para ventanas: el jugador podrá poner ventanas
en los muros fijos (la fachada sigue indemolible y sin puertas nuevas). Al diseñar el plano de
la comisaría inicial nueva, incluir algunas ventanas de serie. Implementar tras el fix del
cursor (mismo código de construcción). Ref: construccion.gd fijar_tipo_de_muro (_muros_fijos).

## 🪑 EN CURSO (2026-08-06): mesa de ventanilla 2 celdas con Summer
Job de generación 3D lanzado (idempotencyKey comisario-mesa-ventanilla-v1, ~0,54$, OK del
usuario). Spec del BLOQUE 2×3: fila ciudadano (2 celdas, silla centrada) + MESA 2 celdas
(estilo ventanilla, solo el mueble, sin sillas pegadas) + fila policía (2 celdas, silla de
escritorio en medio con hueco a los lados). Al llegar: pipeline 4 vistas reales + hoja del
bloque 2×3 montado con las sillas existentes y muñecos → veredicto del usuario.

## 💡 IDEA DE DISEÑO APROBADA EN CONCEPTO (2026-08-06): ventanillas y sillas por CALIDADES
3 tiers de mobiliario de atención con precio/beneficio crecientes. Reparto de efectos propuesto
por el coordinador y bien recibido: mesa de ventanilla (3 calidades) → RAPIDEZ del trámite ·
silla del policía (3 calidades) → CANSANCIO/fatiga (engancha con descansos/café) · silla del
ciudadano (3 calidades) → PACIENCIA mientras espera (engancha con sistema de paciencia).
Cada compra resuelve un problema visible distinto. La mesa 2×3 de Summer en curso = base de las
3 versiones (misma silueta, acabados distintos). PENDIENTE: quick-spec con números cuando pase
la cola actual (bugs cursor + papel visible + ventanas fachada).
REGLA AÑADIDA POR EL USUARIO (2026-08-06): las sillas de los tiers son objetos SUELTOS e
independientes del bloque de ventanilla — colocables en cualquier sitio (decorativas, esquinas,
sala de espera). El bloque 2×3 es disposición recomendada, NUNCA un mueble soldado. El efecto
de cada silla aplica por contexto (junto a puesto → policía; en espera → ciudadano sentado).
ACTUALIZACIÓN mesas ventanilla (2026-08-06): concepto de la 1ª mesa APROBADO por el usuario con
un defecto señalado: el monitor mira al CIUDADANO y debe mirar al POLICÍA (pendiente decidir si
se regenera o se disimula). Encargadas las otras 2 variantes del tier (OK de gasto dado):
BÁSICA (mesa sencilla + CRT antiguo ancho mirando al policía, sin mampara; job
comisario-mesa-ventanilla-basica-v1) y PRO (mesa moderna + 2 pantallas planas al policía +
mampara; job comisario-mesa-ventanilla-pro-v1). GLB de la 1ª (media) en
capturas/fuentes/mesa_ventanilla_summer/ — OJO: trae una SILLA NEGRA incrustada pese al prompt
(comprobar si es nodo separable al renderizar; si está fusionada, decidir regenerar/disimular).
MESAS VENTANILLA — veredictos del usuario (2026-08-06): PRO APROBADA tal cual (blanca moderna,
2 pantallas, placa policial, sin silla). BÁSICA v1 rechazada por: mampara de cristal que no
debe llevar + CRT demasiado grande/mal puesto → regenerada como v2 (job
comisario-mesa-ventanilla-basica-v2, OK de gasto dado): sin cristal/mampara/silla/cajonera,
CRT pequeño centrado delante del policía. MEDIA (v1): concepto aprobado, defectos conocidos
(monitor mira al ciudadano + silla incrustada) — pendiente decidir tras comprobar en render si
la silla es nodo separable.

## 🛒 FICHAJES DEL USUARIO EN LA BIBLIOTECA GRATIS (2026-08-06, del catálogo HTML):
1. Escritorio "Low Poly Game Asset" → mesa de trabajo INTERNA (no atención al público; para
   judicial/despachos futuros — judicial aún no existe).
2. Silla "Low Poly Office Chair" → aprovechar (candidata al lote REVISAR de sillas infladas).
3. "Low Poly Vending Machine" → le gusta MÁS que la vending vieja de Summer (sin integrar) →
   sustituirla.
PLAN: descargar los 3 GLB de la biblioteca (gratis) + render 4 vistas a escala + hojas con
muñeco → veredicto del usuario → integrar. BATCH junto con las 3 mesas de ventanilla, cuando
el motor quede libre (no mientras el usuario juega — regla anti-pantalla-gris).

## ✅ PLAN UI KENNEY APROBADO Y EN COLA (2026-08-06): Theme de Godot con Kenney UI Pack v2.0
local (tema azul+gris claro) + paneles de los packs UI Kenney de la biblioteca Summer (gratis).
Fases: 0 cimientos (inventario+Theme) → 1 barra de construcción (pestañas por categoría con
icono, tarjetas con miniatura+precio, fotomontaje previo sobre pantallazo real) → 2 HUD de
partida → 3 ventanas. Posición en cola: DESPUÉS del lote de renders (mesas+fichajes), para que
el fotomontaje enseñe las mesas nuevas. Todo capa visual, cero coste.

## 📌 PEDIDO DEL USUARIO (2026-08-06, playtest): DESPLAZAMIENTO DE CÁMARA
"Si hago zoom quiero también desplazarme" — hoy solo existe zoom con rueda, sin pan. Implementar:
WASD/flechas + arrastre con botón central del ratón · velocidad proporcional al zoom · límites
del tablero. HACER JUSTO DESPUÉS del fix definitivo del picking (mismo territorio de
cámara/input — el picking corregido debe funcionar también con la cámara desplazada, así que
el orden es: fix picking → pan de cámara → verificar picking CON pan y zoom juntos).
SÍNTOMA ADICIONAL confirmado por el usuario (mismo bug de picking): al COLOCAR objetos
(p. ej. una silla) tampoco respeta la celda elegida — aparece en otro lado. Coherente con la
mezcla de espacios: el clic de colocación pasa por la misma conversión desviada que el
resaltado. Verificar en la sonda del camino real que colocar también acierta.

---

# ⭐ CHECKPOINT 2026-08-06 (tarde) — commits 5-8 del día

- `61c090e` nevera blanca + lámpara pie KayKit (CC BY) · `18f882d` unificación agua (dispensador
  grande CON rotación real elegido por el usuario; fuente_agua retirada; procedencia real:
  kit Isometric office) · `36e0cc3` fix silla-sobre-impresora (orientación vieja duplicada en
  impresora_documentos) + picking consciente de muros · `ebbed1f` **fix GORDO: fórmula de zoom
  INVERTIDA en Main._cambiar_zoom (~150px de deriva por paso de rueda) + fantasma de colocación
  a capa con transform de cámara** (verificado camino real 3/3 + visual 4/4 a 0.00px) ·
  `1adba83` silenciados 116 warnings/sesión (obtener_silencioso en _al_tramite_completado).
- Suite tras todo: **857/857 Exit 0**. El "cursor desviado" del usuario tenía TRES capas:
  picking plano sin muros → dibujo en capa sin cámara → fórmula de zoom invertida. Las tres
  arregladas con regresiones.
- INCIDENTES de proceso: caché .godot corrupta por instancias concurrentes (pantalla gris) →
  regla dura: NADA de imports/tests con el juego abierto; import completo la reconstruye.
  El usuario cierra ventanas negras de consola → avisado de que son los tests.
  Agente borró _check_trazado.gd (untracked, irrecuperable, impacto bajo) → regla nueva en
  memoria: prohibir borrados de archivos ajenos en prompts.
- Mesas Summer: PRO renderizada y en hoja (bloque 2×3 con sillas actuales) · media y basica_v2
  FUSIONADAS (silla/mampara no separables) → PENDIENTE decisión usuario: regenerar por módulos
  (mesa vacía + aparatos nuestros compuestos, ~0,54$/u).
- Fichajes biblioteca (escritorio+silla+vending) descargados; render+hoja EN CURSO.
- PENDIENTE usuario: mesas por módulos sí/no · veredicto hoja fichajes · ¿ventanas cerradas
  por él o solas? (sin errores en log; sospecha: cierra las consolas negras).

## 📏 REGLAS DE LÓGICA DE BLOQUES fijadas por el usuario (2026-08-06 noche):
- TODA mesa (ventanilla Y escritorio de trabajo interno) ocupa 2 CELDAS de ancho, con la silla
  CENTRADA entre las 2 celdas de su lado.
- SILLAS: el POLICÍA lleva silla de escritorio (con ruedas); el CIUDADANO una silla NORMAL
  (nunca de escritorio — "no vas a un sitio y te ponen una silla de escritorio").
- ORIENTACIÓN: TODO el mundo se sienta MIRANDO A LA MESA (en la hoja anterior ambas sillas
  miraban hacia fuera — mal). Replicar la geometría real del juego (mesa_atencion).
- Los 3 TIERS de ventanilla deben verse LOS 3 en la hoja: básica (mesa vacía v3 + CRT antiguo
  generándose, job comisario-crt-antiguo-v1) · media (mesa+mampara vacía generándose, job
  comisario-mesa-ventanilla-media-v2-vacia, + monitor plano equipo_informatico compuesto) ·
  pro (aprobada tal cual).
- VENDING NUEVA: APROBADA por el usuario → integrar (sustituye a la vieja) en el próximo lote
  de integraciones. Escritorio y silla: pendientes del veredicto sobre la hoja corregida.

## ✅ DECISIONES UI DEL USUARIO (2026-08-07 — las 5 del plan maestro):
1. Encargo de arte: SISTEMA VISUAL COMPLETO, identidad POLICÍA NACIONAL ESPAÑOLA.
2. Personal/Horario: VENTANA FLOTANTE para decisiones rápidas (como ahora); PANTALLA COMPLETA
   para gestión compleja de niveles superiores (gestión de la comisaría).
3. BARRA SUPERIOR nueva: información (reloj/dinero/velocidad/satisfacción) ARRIBA, herramientas ABAJO.
4. BANDEJA DE AVISOS: SÍ entra en el encargo de arte aunque eventos/quejas no estén implementados.
   ⚠️ APUNTADO PARA NO DUPLICAR: cuando se implementen eventos aleatorios/quejas, el arte de
   avisos YA EXISTIRÁ — reutilizarlo, no encargarlo de nuevo.
5. TONO: TYCOON SIMPÁTICO (tipo los tycoon clásicos), no dosier sobrio. (Actualiza ui-hud.md.)
SIGUIENTE: redactar el prompt detalladísimo para Summer (revisión del usuario antes de gastar).

## ✅ ENTORNO EXTERIOR: APROBADA FASE 1 (2026-08-07) con las recomendaciones: calle solo fachada
sur + acera + 2-3 árboles/setos apagados + farola. Fase 2: aparcamiento 1 plaza + patrulla azul
CNP. Banco/contenedor después. Implementar cuando el motor quede libre de la hoja de ventanillas.

## 🧱 DESCUBRIMIENTO DEL USUARIO: Kenney Building Kit (kenney.nl/assets/building-kit, CC0) —
kit de paredes/construcción que podría servir para el interior. ⚠️ EVALUAR ANTES DE ADOPTAR:
nuestras paredes son DIBUJADAS POR CÓDIGO (pintura por CARA, modos auto/todas/bajitas, 65px) —
un kit 3D texturizado puede chocar con la pintura por caras. Hacer comparativa visual + informe
técnico (art-director + godot) antes de decidir. Descargar el kit a capturas/fuentes/.

## 🏙️ ENTORNO EXTERIOR — DISEÑO DEL USUARIO (2026-08-07, sustituye la fase 1 genérica):
Layout realista de comisaría: CALLE (solo zona de entrada) → CONTROL DE SEGURIDAD con GARITA
+ BARRERAS → recinto con APARCAMIENTO (3 plazas coche patrulla + 2 libres visitas) → entrada
del edificio. Alrededor: bancos, farolas y vida · PARQUE pequeño al lado · FACHADAS de edificios
de fondo completas SIN interior (decorado). ⚠️ kenney_carkit: EXCLUIR TRACTORES (solo turismos/
furgonetas). "Piensa bien antes de pedir lo del entorno" — el concepto debe pensarse con este
recorrido de seguridad antes de encargar/producir nada.

## ✅ VEREDICTOS DEL USUARIO sobre hoja_ventanillas_final (2026-08-07):
- SILLAS CIUDADANO: A aprobada (tier básico) · C aprobada como TIER INTERMEDIO (azul) · crear
  una TERCERA con reposabrazos más cómoda (tier alto, generación pendiente ~0,54$).
- ESCRITORIO: aprobado, PERO sobraba la silla negra compuesta — la blanca YA viene horneada en
  el modelo y se queda ESA. Bloque escritorio SIN silla_oficina añadida.
- VENTANILLAS: básica y media BIEN orientadas · PRO MAL: mesa/ordenador miran al ciudadano →
  usar la rotación del modelo con monitores al policía (tiene 4 vistas renderizadas).
- BÁSICA: el CRT sale FLOTANDO sobre la mesa → corregir asiento de la composición.
- MEDIA: se ven 2 monitores POR ENCIMA de la mampara → UN solo monitor, integrado (más bajo,
  fuente: pantalla individual del kit isometric office u otra gratis).
- 🔑 DECISIÓN DE DISEÑO: YA NO se mejora equipamiento suelto — SE MEJORA LA VENTANILLA COMPLETA
  (básica → media → pro; la utilidad de cada tier se verá). Actualizar quick-specs cuando toque.
- ENTORNO: TODO ADELANTE ("hazlo y lo vamos viendo") SALVO garita+barrera: al usuario le da
  miedo que la IA no la haga bien y propone CONSTRUIRLA ÉL con las piezas del Building Kit y
  que la usemos → preparar sesión de edición del usuario (commit antes, regla nunca-dos-editores).
- PROMPT UI: aprobado con UN cambio — color base BLANCO en lugar de crema. "Vamos viendo" →
  pieza piloto (pestañas+tarjeta) tras actualizar el doc.

## ✅ VEREDICTOS v2 (2026-08-07): ESCRITORIO OK (integrar) · BÁSICA: CRT descentrado/teclado
levitando → centrarlo SIN que sobresalga (fix: componer EN 3D, no en 2D) · MEDIA: monitor muy
PEQUEÑO → más grande, y NO puede dibujarse encima de la mampara (capas — fix: componer en 3D
para oclusión real) · BLOQUES COMPLETOS por tier: básica=mesa+silla A · media=mesa+silla C ·
pro=mesa+SILLA NUEVA CÓMODA del ciudadano (generándose, reposabrazos) — la ventanilla se
mejora EN BLOQUE (mesa+sillas juntas) · PRO OK · UI: ESTILO APROBADO ("azul policía con fondo
blanco") → producir el resto del kit (lecciones piloto: fondo magenta sólido, hover sin halo).

## ✅ VEREDICTOS FINALES VENTANILLAS (2026-08-07): APROBADAS con sillas por tier:
BÁSICA=silla madera A · MEDIA=silla azul C · PRO=silla cómoda nueva (GLB descargado,
silla_ciudadano_comoda.glb, falta render 4 vistas). GO INTEGRACIÓN: la ventanilla actual del
juego pasa a arte del TIER BÁSICO; media y pro integradas como assets para la futura mecánica
de mejora por bloque. + escritorio + sillas A/C/cómoda + vending nueva. Precios provisionales.

## ✅ ENTORNO AMPLIADO (2026-08-07): cubrir TODA la comisaría alrededor hasta LÍMITE
infranqueable (estilo Theme Hospital: nunca ver vacío al mover la cámara) · más jardín, más
parking/aceras, algún edificio de fondo — criterio libre del coordinador ("lo que veas").
EMPAREJAR con el PAN DE CÁMARA pendiente (WASD/arrastre + límites = no ver vacío). Tras la
integración. Base fase 1 YA verificada (12/12 tests + sonda, SIN commit aún — commit con suite).

---
# ⭐ CHECKPOINT commits 9-10 (2026-08-07): b8da661 entorno base fase 1 (capa EntornoExterior,
calle/recinto/5 plazas/césped, 12 tests, sonda 115 celdas) · a05eec1 MEGA-LOTE catálogo 11→16:
ventanilla del juego = TIER BÁSICO en vivo (mesa+CRT composición 3D, sillas por rol, Asiento
25€ hereda arte madera) · tiers media/pro como assets (mecánica de mejora pendiente de
quick-spec) · escritorio 350 + silla_oficina 90 + sillas espera 25/60/120 provisionales ·
vending sprite nuevo · CREDITS +10. Suite 873/873 + arranque limpio.
SIGUIENTE EN MOTOR: entorno COMPLETO alrededor (perímetro entero estilo Theme Hospital, más
jardín/parking/aceras/edificios de fondo a criterio) + PAN DE CÁMARA con límites (WASD +
arrastre botón central + velocidad por zoom + clamp al entorno). Luego: props del entorno
(árboles/farolas/coches sin tractor) · garita del usuario cuando quiera · piezas UI restantes
(4/8 hechas) · quick-spec mejora de ventanilla · papel visible + ruta impresora sin atravesar
mesas · ventanas en fachada · evaluación Building Kit paredes.

## 💡 ESTÁNDAR PROPUESTO POR EL USUARIO (2026-08-07): LADO DE ACCIÓN de cada objeto
"Elaborar un plan para seleccionar un lado de acción: qué lado del diseño tiene que ir mirando
a quién" — vending: acción en el frontal · silla: lado contrario al respaldo · ordenador: donde
esté el funcionario... Sistematizar: metadato frente_accion por objeto en catálogo + convención
de vistas ligada al lado de acción + LEY de verificación (toda hoja enseña al muñeco USANDO el
lado de acción en cada rotación — sentado en sillas, de pie frente a máquinas). Doc en
elaboración: design/art/lado-de-accion.md. Motivado por la silla del ciudadano 2 veces al revés.

---
# ⭐ CHECKPOINT commits 11-13 (2026-08-07 tarde): 9cf1bb5 silla 180 (insuficiente) · b250f2f
CIUDAD ALREDEDOR COMPLETA (manzanas 6x6 deterministas, 1/5 parque, acera perimetral, acceso
oeste intacto) + PAN DE CÁMARA (WASD/flechas/botón central, velocidad∝zoom, clamp al rect de
cobertura = single source of truth con el dibujo; 15 tests) · 84db7de SILLA DEFINITIVA a 225°
(vista de ACCIÓN elegida con muñeco sentado + recortes; azul/cómoda listas) + estándar
design/art/lado-de-accion.md COMMITEADO (migración 18 objetos, 2 verificados; AVISO: sala de
espera comparte mecanismo, verificar con muñeco sentado pendiente).
Suite 887/887. 13 commits en el ciclo 2026-08-06/07.
COLA VIVA: props del entorno sobre anclas (árboles/farolas/coches SIN tractores/banco) · piezas
UI 5-8 (marco modal, pantalla completa, bandeja avisos, iconos ×2) · garita del usuario ·
quick-spec mejora ventanilla por bloque · papel visible + ruta impresora sin atravesar mesas ·
ventanas en fachada · evaluación Building Kit paredes · verificar sillas sala de espera con
muñeco sentado · playtest del usuario del mega-lote.

## 🔴 FEEDBACK PLAYTEST ENTORNO (2026-08-07): "muy raro, solo cuadrados de colores, no hay
vida, las manzanas pequeñas y muchas" + "el recinto de la comisaría es inexistente".
REHACER: 1) manzanas MÁS GRANDES y MENOS (calles 2 celdas, menos densidad, tejados con detalle
—variación, parapetos, sombras—) · 2) RECINTO REAL: valla perimetral dibujada por código
(estilo murete bajito del juego) rodeando explanada+aparcamiento, con hueco de entrada en el
control (donde irán garita+barrera) · 3) VIDA: pasada de props YA — árboles urbanos en aceras y
parques ("Low Poly Street Tree" descargándose), setos, farolas, coches del carkit (police.glb +
turismos SIN tractores) en las plazas.

## 🎮 PROPUESTA DEL USUARIO ACEPTADA (2026-08-07): MODO DISEÑADOR DE ENTORNO
"¿Podría hacerlo yo con esos objetos, como si fuera un builder, y cuando lo tenga te digo 'ya
tenemos el entorno' y lo guardas fijo para la primera comisaría?" → SÍ. Plan: herramienta
in-game (patrón ModoConstruccion) con paleta de piezas del entorno (casas/valla/caminos/
árboles/setos/farolas/coches/jardineras — los 22 sprites de assets/sprites/entorno/), colocación
con rejilla + R + triángulo + cámara nueva, guardado a archivo de datos; al "ya tenemos el
entorno" del usuario → se congela como entorno FIJO de la comisaría 1 (committeado). También
servirá para montar la garita. Orden: commit reforma actual como base → construir el modo →
sesión de diseño del usuario.
REGLA DE ESCALA DEL USUARIO (2026-08-07): los COCHES ocupan MÍNIMO 3 CELDAS de largo ("la mesa
ocupa 2 y un coche es más grande que una mesa"). Aplicar en el lote del modo diseñador:
re-render de los coches del carkit a huella 3×1 mínimo (largo ≈4,5m con el factor de presencia)
+ redimensionar las plazas de aparcamiento acorde. Añadir la regla a design/art/plan-escalado.md
cuando se toque ese doc (tabla de referencias relativas: mesa 2 celdas < coche 3+ celdas).

---
# ⭐ CHECKPOINT commits 14-16 (2026-08-07 noche): 098256e reforma entorno con assets reales
(recinto campus, 5 casas Kenney, valla por tramos con hueco, props; Metro Corner descartado
con evidencia; losetas de carretera aplazadas) · 05d590e MODO DISEÑADOR DE ENTORNO (flag
--disenador + F12, paleta completa, F8 guarda a user://entorno_disenado.json, congelado =
copiar a res://datos/entorno_layout.json que sustituye el scatter) + FIX CAPAS (props verticales
del entorno a la bolsa y-sort de MundoProfundo — farolas del sur ya no se cortan, bug cazado
por el usuario) + COCHES a 3,19 celdas (regla "mínimo 3") con plazas 1×3 + FAROLAS NOCTURNAS
(luces_objetos, mismo mecanismo interior). Suite 905/905.
PENDIENTE INMEDIATO: sesión de DISEÑO DEL USUARIO con el modo (lanzar con --disenador) → al
"ya tenemos el entorno", congelar su layout. Después: piezas UI 5-8 · garita (la montará en el
diseñador con piezas cuando estén en paleta o aparte) · quick-spec mejora ventanilla · papel
visible · ventanas fachada · verificar sillas sala de espera sentadas · retoques estética
entorno si el usuario los pide tras diseñar (vallas naranjas, variedad de árboles).

## 🔴 FEEDBACK DEL DISEÑADOR EN USO (2026-08-07 noche): "funciona bien, me gusta" PERO:
1. CASAS MUY PEQUEÑAS (escala vs coches/personas/comisaría — "una porción muy pequeña al lado
   del edificio"): re-render a escala de PARCELA (~6-8 celdas de ancho, ~2-3× lo actual; una
   casa >> un coche). El layout del usuario guarda celda+rotación → sus casas colocadas se
   re-escalan solas al recargar sprites.
2. UI URGENTE: el menú del diseñador SE SOLAPA con los datos del juego y cuesta seleccionar →
   quick-fix: ocultar HUD del juego con el editor activo + recolocar/agrandar paleta. Y
   acelerar el kit de UI completo (generando piezas 5-8 ya).

## 🎨 UI IMPLEMENTADA SIN VERIFICAR (2026-08-07 noche, SIN commit — motor ocupado por la
sesión de diseño del usuario): kit troceado (41 piezas assets/ui/kit/, contact-sheet en
scratchpad; bordes "regulares" en hovers con halo + posible defringe pendiente en iconos) ·
theme_comisario.tres (9-slice con márgenes ESTIMADOS, ajustar a ojo en editor) + fuente Kenney
Future · src/ui/kit_ui_comisario.gd · barra de construcción NUEVA por pestañas+tarjetas+Demoler
fijo (modo_construccion.gd) · FIX SOLAPE: HUD se oculta con el diseñador activo (señal
activado_cambiado→main.gd) · paleta del diseñador con Theme y botones ≥48px · CREDITS (fuente
+ kit) · 2 tests nuevos escritos SIN ejecutar. Piezas de arte: todas menos la plantilla de
pantalla completa (futuro). VERIFICAR AL LIBERARSE EL MOTOR: suite completa + visual (B barra
nueva, márgenes 9-slice, --disenador+F12 oculta HUD) → commits. + CASAS a escala de parcela
(re-render 2-3×) en el mismo hueco.

---
# ⭐ CHECKPOINT 2026-08-08 TARDE-NOCHE (sesión Fable maratón) — ver traspaso-proxima-sesion.md
Commits e3937f4..9a9d5b3 (pusheado hasta b17a9f3): casas uniformes+16 nuevas · entrada SUR ·
kit UI limpio+tarjetas+miniaturas+brújula · paleta 2.0 (5 categorías, 21 casas, carreteras 6
celdas con curva que PROLONGA) · papel visible · pintura fachada/blanco/tiers/silla N · HUD
RECONSTRUIDO (HudComisario) · diseñador F12 fix + Building Kit (10 bk_). Arte generado listo:
2 bancos + barrera (capturas/fuentes/, thumbs auditados). PRIMERA TAREA PRÓXIMA SESIÓN: 3
failures de contaminación entre suites (verdes en aislado) — ver traspaso. Veredictos del
usuario pendientes: HUD nuevo, paleta Construcción/garita, hoja bancos+barrera, bandas blancas
de carretera, ampliación Este (¿24→32?).

---
# ⭐ CHECKPOINT 2026-08-09 (sesión Fable, arranque)
1) CONTAMINACIÓN ENTRE SUITES RESUELTA (commit 2191608): causa raíz = modo_disenador_entorno_test
llamaba alternar() → Tiempo.fijar_velocidad(PAUSA) sobre el AUTOLOAD y nadie reanudaba → NPCs
congelados en flujo_muro_tras_ruta (quieto 600 frames) + impresora_papel_visible (viaje sin
cerrar). Cazado por bisección (unit/main → modo_disenador). Fix de aislamiento: before/after_test
guarda y restaura Tiempo.velocidad_actual. Bonus: gdUnit descartaba el resto de la suite tras el
fallo → reaparecen 4 casos: suite ahora 953/953 VERDE (antes 949 con 3 rojos).
2) CARRETERAS FUSIÓN TOTAL (tarea 0b, decisión ya dada): pipeline render_entorno_urbano.gd
+ _bordes_de_via (detección por color de calzada, 5 muestras a 0,12uv por borde, umbral medido
con PIL: asfalto 122/129/157, franja oscura ≤104, banda 255 — idéntico en las 4 rotaciones)
+ _afeitar_extremos_via (extiende el perfil transversal hasta el borde exacto del rombo,
franja 0,03uv, muestra a 0,05uv; NO alfa — alfar dejaría rendija porque las losetas no solapan).
Re-render de las 5 (SOLO_IDS), --import hecho. Verificado con PIL + ojo: recta-recta, codo en L
(curva PROLONGA), cruce 4 vías, T, cebra — costura invisible; muesca ~1px en ápice interior del
codo (aceptada, invisible a 1x; el render viejo tenía costuras oscuras cruzando TODA la vía).
OJO: simular costuras con paso EXACTO (240,120), no H//2 (=122, mete 2px de rendija falsa).
PENDIENTE INMEDIATO: suite completa post-render en marcha → commit de pipeline+PNGs.
Ley nueva del usuario (en memoria supervision-visual-fable): auditar toda captura antes de
enseñarla — cero textos superpuestos/fuera de recuadro, "perfecta de videojuego bueno".

## Avance 2026-08-09 (2ª parte): HUD auditado + opción A implementada
- Commit 95be810: velocidad uniforme (⏸ emoji → "II" tipográfico; flat esconde dibujo pero NO
  content margins → styleboxes vacíos + sep 10px; pip 10px) · saldo "3.000 €" (_formato_euros,
  spec §1.3-[3]) + placa 179px · barra_superior_fondo.png saneado (bultos horneados, borde recto).
- OPCIÓN A ELEGIDA POR EL USUARIO (franja CONSTRUIR): confirmado que píldoras = arte del kit
  (StyleBoxTexture) pero fondos de franjas = gris default del MOTOR (theme sin Panel). Implementado:
  píldora "Construir (B)" (señal construccion_solicitada→main) primera de la fila · franja
  colapsada ELIMINADA (_panel_raiz.visible = _activo) · fondo plano deliberado compartido
  KitUIComisario.COLOR_FONDO_BARRA_INFERIOR (ley Summer: relleno plano tolerado) · HUECO 84→60
  sincronizado (ALTO_BARRA_HUD 60, HUECO_BARRA_INFO eliminado, barra abierta apoya en borde real
  — sin agujero de mundo) · diseñador cierra construcción al abrirse (orden: cerrar ANTES de
  ocultar acciones por el rebote de activado_cambiado) · emoji 🔨 fuera · test HUD a 6 píldoras.
- DEFECTOS PREEXISTENTES APUNTADOS (cazados en auditoría, pendientes): rótulos de tarjetas de
  construcción TRUNCADOS ("OFICINA DE DOCUMEN...") — ley del usuario "nada fuera del recuadro" ·
  paleta del diseñador: píldora CASA K cortada por el borde dcho + "CARGADO:" pegado al borde.

## Avance 2026-08-09 (3ª parte): hojas de veredicto bancos + barrera LISTAS
- Push hecho (usuario OK): origin/main al día hasta f5f9d39.
- Renders: agente Sonnet creó tools/_render_bancos_barrera.gd/.tscn (verificado contra disco).
  1ª pasada calibró por altura 0,85m → bancos de 0,36-0,45 celdas (inútil). Fable re-calibró por
  ANCHO (encargo manda): medio/pro 3 celdas, madera 2. HALLAZGO CLAVE: el ancla de familia de
  asientos es asiento_sofa3 (109×81px para 3 plazas) — las hojas van a ESA escala (109px), no a
  240px. Paso de celda a lo largo de un eje = 40px horizontales (no 80).
- Descartados por rotos (verificado a ojo): banco_desgastado_graveyard (geometría revuelta),
  banco_urbano_retro (sin textura). Quedan: medio (aeropuerto), pro (azul), madera (básico).
- Hojas en scratchpad: hoja_bancos_v3.png (muñecos sentados en centroides de cojín medidos por
  color; referencia silla+sofa3+muñeco) · hoja_barrera_v3.png (rot 0 cruza la calle N-S — 0/180
  cruzan, 90/270 paralelas; carretera_90 ES la calle N-S en pantalla; pilar al arcén; AVISO:
  pilar ~2,5 muñecos de alto con pluma a 6 celdas).
- PENDIENTE: veredicto del usuario sobre ambas hojas → quick-spec asiento multi-plaza → integrar.

## Avance 2026-08-09 (4ª parte): barrera re-hecha a escala de coche (feedback usuario)
Feedback: "no tiene sentido, 2 montadas juntas, debe ser a escala del coche, NPC antiguo,
la pluma como mucho al arranque del parabrisas, es inmenso" + "el largo no puede superar el
ancho de una calle de 6 celdas". Diagnóstico: el modelo es UNA unidad con cabina GIGANTE tipo
garita + poste suelto (por eso parecían 2). Regla de escala nueva: factor = 43px (arranque del
parabrisas del coche_policia, medido) / 120px (altura de montaje de la pluma en el render
nativo) ≈ 0,36. NPC de escala = policia_40px (girl_44px es ANTIGUO — no volver a usarlo en hojas).
3 variantes compuestas (barrera_3_variantes_v2.png): V1 unidad completa cerrando un carril ·
V2 dos unidades en espejo entrada/salida (coche_180 esperando) · V3 sin cabina (cirugía PIL:
pluma + poste en ambos extremos). Pendiente veredicto del usuario (también hoja_bancos_v3).

## Avance 2026-08-09 (5ª parte): barrera v9 — pluma 3D real
Feedback iterativo del usuario sobre la barrera: (1) "ninguna de las 3 variantes: motor en
arcén y principio de un lado, pluma hasta el final del otro lado sin tocar el arcén" · (2)
"las líneas rojas no siguen la línea" (textura del modelo ROTA: parches desfasados al doblar
el cilindro) · (3) "la pluma no tiene 3D y al motor le falta algo" (mi pluma PIL era plana y
al cortar el brazo dejé la cabina mocha).
SOLUCIÓN v9: tools/_render_pluma_barrera.gd(.tscn) — pluma 3D REAL por segmentos BoxMesh
rojo/blanco planos (relleno plano tolerado por la ley Summer) con cámara/luces del pipeline →
capturas/fuentes/barrera_summer/renders/pluma_limpia_{0,90,180,270}.png. Motor = recorte del
render nativo x<118 SIN limpiar rojos (la limpieza mordía la cabina) + autocrop a contenido
(el lienzo nativo tiene aire debajo: la cabina solo llega a y=233/413 — por eso "flotaba").
Composición: pluma nace del canto de la cabina tapando el muñón del brazo viejo.
GOTCHAS SONDA: const SALIDA ya existe en render_mobiliario (renombrar) · la escena debe ser
Node3D (la base extiende Node3D; con Node2D el script no se asigna y Godot se queda colgado
sin quit — matar con taskkill).
PENDIENTE: veredicto de barrera_v9.png y de hoja_bancos_v3.png.

## Avance 2026-08-09 (6ª parte): BARRERA DISEÑO 1 INTEGRADA EN EL JUEGO
- Usuario eligió diseño 1 (caja 72px) + confirmó que policia_40px NO es el agente de las mesas
  (es sprite viejo — los de mesa son los cabezones tipo Poly; el policia_40px solo era escala).
- Pieza final: 4 sprites assets/sprites/entorno/barrera_seguridad_{0,90,180,270}.png compuestos
  con PIL: cabina del modelo (recorte rectangular por rotación + acortado POR ABAJO 33px nativos
  — así el punto de montaje del brazo BAJA a la vez que la caja — + repintado del brazo horneado
  SOLO en el corredor del brazo, rot 0/270) + pluma 3D real (tools/_render_pluma_barrera.gd,
  BoxMesh segmentos rojo/blanco, SECCION 0,14) + ancla invisible alfa 16 en el suelo de la punta
  (rot 0/270: la punta cuelga más bajo que la base del motor y AnclajeSprite anclaría mal; lienzo
  ampliado por abajo para que el suelo real de la punta quepa).
- Registro: modo_disenador_entorno.gd OBJETOS_IDS + "🚧 Barrera de entrada".
- VERIFICADO IN-GAME con tools/_diag_barrera_ingame (sonda desechable): captura en
  production/qa/evidence/barrera_ingame_2026-08-09.png.
- GOTCHAS de la sonda in-game: el diseñador guarda UNA pieza por celda (la barrera en la celda
  de la loseta LA SUSTITUYE → colocarla en la celda del arcén) · Main._camara usa
  ANCHOR_MODE_FIXED_TOP_LEFT (posición = esquina sup-izq: para centrar, restar media ventana) ·
  el clamp de cámara pisa posiciones fuera de cobertura · el motor 3D por cajas salía NEGRO con
  la iluminación del pipeline (se descartó; cabina = modelo real).
- Suite en marcha como gate → commit. PENDIENTE del usuario: hoja de bancos (hoja_bancos_v3.png),
  borde ondulado, columnas ampliación Este. Push: 2 commits sin subir (95be810, f5f9d39) + el de
  la barrera cuando esté verde (el usuario pidió saber qué queda por pushear al terminar).

---
# ⭐ CHECKPOINT 2026-08-09 (sesión Fable maratón) — ver traspaso-proxima-sesion.md
16 commits, 2191608..e0a7e9b, TODO PUSHEADO. Suite 949 -> **974/974 verde**.
Hecho: aislamiento de la suite (Tiempo PAUSA sin restaurar) · fusión de carreteras · HUD auditado
(⏸ era emoji del sistema; saldo con formato de spec) · franja CONSTRUIR = píldora del kit (opción A)
· diseñador con paleta rehecha + "Base visible/oculta" + "Importar entorno" · alineación a la
cuadrícula por paridad de huella · Building Kit 10->21 piezas (la puerta era la pieza equivocada:
wall-doorway-* es pared CON hueco) · bordes lisos con TAM_RENDER 2048 (contorno suavizado 42%->99%)
· barrera diseño 1 sin cortes · ciudadanos de perfil + papel en la mano con capas · ventanillas que
giran ENTERAS · bancos multi-plaza (3 tiers, 1 NPC por celda, 3 sentados verificados).
PRÓXIMO: re-render general del catálogo con el supermuestreo (TAM_RENDER ya está a 2048; falta
ejecutar los pipelines y VACIAR SOLO_IDS en render_entorno_urbano).
GOTCHA MÁS CARO DEL DÍA: dos celdas contiguas distan 40px (MEDIO rombo), no 80 — causó muros
solapados, bancos gigantes y casas descuadradas. Y: la escala se ancla a una pieza que YA existe en
el juego, no a cuentas teóricas.
Veredictos pendientes del usuario: columnas de la ampliación Este (¿24->32?), borde ondulado del kit.

---
# SESIÓN 2026-08-09 (tarde) — arranque
Árbol limpio y pusheado hasta ad4eb74 (verificado). Suite 974/974 desde el cierre anterior.
CAMBIO DE PRIORIDAD DEL USUARIO al empezar: antes del re-render general, quiere decidir el
TAMAÑO DE LOS BANCOS ("están bastante grandes") con una hoja de 3 tamaños menores + coche y
policía Poly al lado.
Diagnóstico medido (PIL): banco medio 108x101, pro 108x104, básico 72x56; sofá3 aprobado 108x72;
policía de pie (oficial_h_44px) 28x45. Los bancos medio/pro miden 2,2-2,3 VECES el alto de una
persona de pie y 30px más que el sofá de 3 plazas con el mismo ancho -> la familia se ancló por
ANCHO y la ALTURA se disparó. La queja del usuario es correcta y medible.
Hoja v1 RECHAZADA por mí en auditoría: sin nadie sentado (el agente afirmó en falso que no había
sprites `*_sit_*`; SÍ existen oficial_h_44px_sit_N y todos los civiles), rejilla que no llegaba
bajo los bancos, policías de pie tapando el brazo del banco. Pedida v2.

## Reconocimiento del RE-RENDER GENERAL (agente Sonnet 5, solo lectura, 2026-08-09 tarde)
Estado real por pipeline (verificado con git log/ls-files):
- YA MIGRADOS a 2048+LANCZOS: render_mobiliario (~40 PNG), render_props_poly (28),
  _render_estanterias (12), render_entorno_urbano (hasta ~148, HOY limitado por SOLO_IDS a 72).
- SIN MIGRAR (siguen a TAM_RENDER=512, cada uno con su propia constante, NO heredan):
  render_sprites (girl, 144) · render_sprites_civiles (~1008) · render_sprites_animado
  (oficial_h/m, ~288) · render_variantes_civiles_produccion (~2016) · _render_dispensador_b (4)
  · _render_silla_espera_partida (3). => ~3456 PNG de PERSONAJES sin supermuestrear: es el 99%
  del volumen y el trabajo más largo con diferencia.
- NO TOCAR: render_catalogo_objetos / render_catalogo_oficina / render_despiece_objetos
  (salida gitignored, no alimenta al juego) y los 18 _render_* que escriben solo a scratchpad.
ORDEN: (1) render_mobiliario -> (2) render_props_poly -> (3) _render_estanterias ->
(4) render_entorno_urbano CON SOLO_IDS VACIADO -> (5) los 4 de personajes subiendo su
TAM_RENDER 512->2048 -> (6) _render_silla_espera_partida (DEPENDE de silla_espera_270.png del
paso 1) -> (7) _render_dispensador_b (ojo: FACTOR_TAMANO_B=1.28, calibración propia).
RIESGOS: las 5 piezas de RECORTAR_CANTOS_VIA (carreteras) llevan cirugía de píxel (recorte a
rombo + afeitado de extremos) -> revisar a ojo que la sutura siga sin costura.
AFEITAR_CANTOS_MURO debe seguir VACÍO (decisión del usuario: la nitidez es resolución, no retoque).
VERIFICACIÓN: bbox de silueta antes/después (±1-2px o se aborta) + fracción de ancla igual +
% de píxeles de PERÍMETRO con alfa intermedio (debe subir). Nunca medir sobre el área.

## VEREDICTO DEL USUARIO 2026-08-09: bancos a ESCALA B = 75%
Elegida la opción B de `hoja_bancos_escala.png` (scratchpad de esta sesión). Motivo: deja el banco
de aeropuerto en 76px de alto, casi clavado al `asiento_sofa3` (108x72) que el usuario YA aprobó.
La escala NO se aplica encogiendo el PNG (emborrona el borde y tira por tierra el supermuestreo):
se mete en el pipeline y se RE-RENDERIZA desde el .glb -> entra en el lote del re-render general.
Hoja auditada por mí en 3 pasadas: v1 rechazada (sin sentados, rejilla corta), v2 con rejilla que
pisaba los rótulos -> arreglado por mí: rejilla en capa recortada a alfombra rectangular
(GRID_DEPTH 20 + GRID_CLIP) y placa de fondo del color EXACTO de la banda bajo cada rótulo.

## HALLAZGO GORDO: LOS NPC NO PUEDEN SENTARSE (el usuario lo cazó en la hoja)
"están de pie en los asientos". CIERTO y es estructural, no un fallo de la hoja:
- El esqueleto de `capturas/NPC/Ciudadanos/candidatos/generic_male.glb` (y familia) tiene 27 huesos
  y NINGUNO es de pierna: CORE, Body, Head, Hand.L/R (+dedos), Foot.L/R, Toes.L/R. Son cabezones
  estilo Rayman: los pies FLOTAN pegados al cuerpo. No hay cadera ni rodilla que doblar.
- Por eso `render_sprites_civiles.gd::_posar_sentado` gira `Foot.L`/`Foot.R` 85 grados
  (SENTADO_GRADOS_PIE) y baja el CORE medio largo de pierna (SENTADO_BAJADA_FRACCION 0,5). El
  resultado es "de pie hundido", que es exactamente lo que se ve. OJO: las constantes se llaman
  HUESO_PIERNA_IZQ/DER pero apuntan a Foot.L/Foot.R — el nombre engaña.
- Animaciones disponibles en el .glb: Grounded, Idle, Jump, Sprint, Walk. **`Grounded` está sin
  explorar** y es la candidata más barata a pose de sentado.
- Comprobado con PIL: `civil_h1_44px_sit_*` y `civil_h1_44px_*_0` son visualmente la misma figura
  erguida.

### Dónde se aplica el 75% de los bancos (localizado, SIN ejecutar aún — Godot ocupado)
`tools/_render_bancos_barrera.gd` controla la escala con `ancho_objetivo_celdas` (escala UNIFORME):
  banco_espera_medio 1.35 -> **1.0125**   |   banco_espera_pro 1.35 -> **1.0125**
  banco_madera_summer 0.90 -> **0.675**
Escribe en `capturas/fuentes/bancos_espera/renders/` (NO directo a assets): tras el render hay que
promover los PNG a `assets/sprites/mobiliario/comodidad_banco_espera_{basico,medio,pro}_{0,90,180,270}.png`.

### Exploración de la pose sentada: resultados (2026-08-09 tarde)
1. SONDA DE POSES (`tools/_diag_poses_sentado.gd`, desechable): probadas ACTUAL, GROUNDED (t=0..1),
   HUNDIDO 0.75/1.0, RECOSTADO ±12°, PIES ADELANTE 0.20/0.40 y COMBO. **NINGUNA se lee como
   sentado.** `Armature|Grounded` resultó ser un "recuperar el equilibrio" de 0,333 s, erguido, sin
   flexión: NO sirve. PIES ADELANTE es PEOR que el bug (despega la bota del cuerpo). Nota: la hoja
   que generó el agente tenía los muñecos a escala falsa -> NO se enseñó al usuario.
   Dato técnico: subir SENTADO_BAJADA_FRACCION no cambia nada porque el pipeline hace autocrop al
   contenido; el hundido solo serviría con oclusión real en el juego.
2. TRUCO DEL MUEBLE PARTIDO (probado por mí, `scratchpad/prueba_banco_partido.py`): el juego YA lo
   usa en la ventanilla (`npcs_flujo.gd::hay_silla_espera_partida` + `silla_espera_asiento_270.png`
   / `silla_espera_respaldo_270.png`): el NPC va ENTRE las dos mitades del mueble. Probado en el
   banco con corte a media altura y con banda fina de canto (8/12 px) + hundido 6/10.
   **VEREDICTO MÍO: no basta.** El corte ancho mete patas y reposabrazos por delante del TORSO (el
   muñeco parece DETRÁS del banco); el fino apenas cambia nada. El problema no es la oclusión: es
   que la silueta erguida es idéntica a la de estar de pie.
3. INVENTARIO DE RIGS: escaneados los 284 .glb de `capturas/`. **Solo `capturas/NPC/girl.glb` tiene
   rig humano completo** (74 huesos: Hips_01, RightUpLeg_063, RightLeg_064, LeftUpLeg_068,
   LeftLeg_069), sin animaciones. Ningún pack de personajes CC0 con piernas descargado.
   => Con el arte actual NO hay sentado posible. En marcha una demo con girl.glb sentada de verdad
   para que el usuario vea la diferencia y decida si encarga la pose a Summer.

## DECISIÓN DEL USUARIO 2026-08-10: REHACER LOS CIUDADANOS CON RIG COMPLETO
Tras ver el diagrama de esqueletos (`scratchpad/diagrama_esqueletos.png`, posiciones derivadas de
las `inverseBindMatrices` del .glb), el usuario descarta el apaño del mueble macizo y elige la
opción cara: **modelos de personaje nuevos con piernas de verdad**. Su razón (buena y de largo
plazo): *"en un futuro tienen que subir escaleras o bajarlas o subirse a un coche"*.
- El rig actual: CORE -> {Body->Head, Hand.L, Hand.R, Foot.L->Toes.L, Foot.R->Toes.R}. Manos y
  pies CUELGAN DE LA CADERA. Tres huesos por dedo y CERO en la pierna. No hay bisagra que doblar:
  no es dificultad, es imposibilidad sin re-riggear en Blender.
- Alcance real: 7 modelos civiles (generic_male/female, citizen1-3, retail_worker, crypto_bro) +
  2 de oficial = 9. Los 21 prefijos civiles salen de esos 7 por recoloreado.
- **CONSECUENCIA INMEDIATA EN EL RE-RENDER**: los ~3.456 PNG de `assets/sprites/personajes/`
  SALEN DEL LOTE del supermuestreo (se tirarían al llegar el muñeco nuevo). El re-render general
  queda en muebles + entorno (~230 PNG). Ahorro grande de tiempo.
- PLAN antes de gastar: (1) el usuario reconecta Summer con /mcp; (2) yo redacto el prompt del
  modelo PILOTO y le enseño coste por pieza; (3) se genera UNO solo; (4) hoja de comparación con
  los ciudadanos actuales (de pie / andando / sentado) + verlo in-game; (5) solo con su OK, los 8
  restantes. Nada de encargar 9 a ciegas.
- TRABAJO TÉCNICO QUE ME TOCA A MÍ (sin coste): `render_sprites_civiles.gd` y
  `render_sprites_animado.gd` buscan los huesos POR NOMBRE (`CORE`, `Foot.L`...). Un rig nuevo
  traerá nombres estándar distintos -> hay que parametrizar los nombres de hueso por modelo y
  reescribir `_posar_sentado` para doblar cadera+rodilla de verdad (ya validado el método con
  girl.glb en `tools/_diag_sentado_rig_completo.gd`).

## HITO 2026-08-10: bancos a su tamaño final + las plazas las manda el MUEBLE
REGLA NUEVA DEL USUARIO (memoria `huella-celdas-enteras`): la huella de todo objeto es un número
ENTERO de celdas, aunque el dibujo deje huecos. Y se mide EN EL PLANO DEL SUELO (como
`AnclajeSprite.semiejes_base`), NUNCA por el ancho en píxeles de pantalla — el usuario cazó ese
error mío: el mueble está girado 45° y en pantalla su largo sale deformado.
Recorrido de decisiones del usuario: 75 % -> huella 2 celdas -> opción B "que LLENE sus celdas para
poder hacer hileras sin huecos" -> "las plazas las manda el mueble, no la celda" -> banco de madera
a 1 celda EXACTA.
- `_render_bancos_barrera.gd` receta v6: ancho_objetivo_celdas medio/pro 1,0125 -> **1,2981**,
  madera 0,675 -> **0,6683**. Medido tras el render: 2,013 / 1,988 / 0,988 celdas de largo. Los
  sprites promovidos a `assets/sprites/mobiliario/comodidad_banco_espera_*`.
- Fichas: basico superficie 1 / plazas 2 · medio y pro superficie **2** / plazas **3**.
- `Construccion.sitios_sentables_de_sala()` NUEVA: devuelve POSICIONES, una por plaza del mueble,
  repartidas por su eje (`(i+0,5)·celdas/plazas − 0,5`), con un empujón de 1/4 de celda hacia atrás
  porque el asiento está en la mitad TRASERA (sin él los NPC se sentaban DELANTE del banco,
  verificado in-game). El eje sale de la ORIENTACIÓN, no de restar celdas (con huella de 1 celda
  esa resta da cero y las plazas se encimarían).
- `npcs_flujo`: nuevo registro `_asiento_de` indexado por POSICIÓN redondeada (la celda ya no
  identifica la plaza) + `_asiento_libre` + `_asiento_reservado_de` + `SITIO_NULO`; `esta_sentado`
  y `_liberar_plaza` al día. `celdas_sentables_de_sala` SIGUE existiendo: la usa
  `_hueco_de_pie_libre` para esquivar los bancos.
- ⚠️ EFECTO COLATERAL DEL SUPERMUESTREO, cazado por la suite: `AnclajeSprite.UMBRAL_ALFA` 0,05 ->
  **0,50**. La reducción LANCZOS deja un halo de píxeles tenues y con 0,05 contaba como mueble: en
  `comodidad_estanteria_suelta_90` los semiejes sumaban 18,50 contra un semiancho de 16,50 (2 px de
  desvío, fuera de tolerancia) -> el mueble se arrimaba mal a la pared. Con 0,50 el desvío cae a
  0,50 px. Este fallo estaba LATENTE: no salió en la suite del re-render porque Godot servía los
  .ctex viejos; apareció al forzar `--import`.
- Suite: **974/974 verde**.
- PENDIENTE de afinar: el empujón de 1/4 de celda mejora mucho (verificado in-game: el NPC ya se
  sienta SOBRE el asiento) pero no está calibrado contra el fondo real de cada mueble.
- PENDIENTE de decidir: precios/aporte de los bancos (150 € y 240 € se fijaron para 3 plazas en 3
  celdas; ahora son 3 plazas en 2 celdas) y si el banco de madera con 2 plazas en 1 celda cuadra.

## 2026-08-10 (noche): asientos MEDIDOS del dibujo + 3 piezas nuevas de Summer
- El usuario: "no encaja perfecto la persona que se sienta con el lugar exacto del asiento".
  CIERTO: repartir las plazas uniformemente por el eje da puntos plausibles pero no los cojines
  reales (la proyección iso acerca unos y aleja otros; los reposabrazos comen ancho).
  ARREGLADO: `AnclajeSprite.centros_de_asiento(textura, plazas)` busca cada plaza en SU franja de
  columnas — X = centro de la franja ocupada, Y = fila más ancha de la mitad inferior (la banda del
  cojín). `Construccion.sitios_sentables_de_sala` la usa y cae de vuelta al reparto uniforme si no
  hay textura (tests con catálogos de mentira). Cacheado por textura+plazas.
  VERIFICADO en hoja: los 3 muñecos caen clavados en los 3 cojines del banco de aeropuerto.
  Se elimina el empujón artificial de 1/4 de celda: ya no hace falta, el asiento medido está donde
  toca. `construccion.gd` necesitó `const AnclajeSpriteScript := preload(...)` (el class_name no
  resuelve en headless en frío).
- Suite: 974/974 verde.
- ENCARGOS A SUMMER (1,61 $ en total, 3 piezas de 0,54 $):
  1. `banco_3plazas_largo_summer.glb` — pedido con ratio largo/alto 3,75 para llenar 3 celdas.
     **FALLÓ el encargo**: devolvió ratio 2,00, igual que el viejo. Los generadores toman las
     proporciones numéricas como inspiración, NO como especificación. A 3 celdas mide 145 px de
     alto = 3,2 muñecos (enorme). DESCARTADO como banco de 3 celdas.
  2. `banco_premium_madera_summer.glb` — BUENO: 3 asientos azules, reposabrazos y mesitas de
     madera con taza y móvil cargando (idea del usuario: lo pro se nota en los extras). A 2 celdas
     mide 78 px de alto = 1,7 muñecos, MÁS BAJO que el actual (2,2). Ratio 2,32.
  3. `mesita_revistas_summer.glb` — BUENA a la primera: mesa cuadrada baja de madera con revistas.
     Va en la 3ª celda junto al banco de 2 (idea del usuario para aprovechar el hueco).
- ⚠️ PENDIENTE (lo dejo abierto y no oculto): el premium viene ORIENTADO AL REVÉS (respaldo a
  cámara en la vista 0; la vista buena es la que hoy sale como 90). Intenté dos vías en
  `_render_bancos_barrera.gd` —`giro_base_grados` antes del render y `pasos_giro` al repartir las 4
  vistas— y NINGUNA surte efecto: las 4 vistas salen idénticas. Hay que averiguar dónde se aplica
  de verdad la rotación en ese pipeline (sospecha: `_ejecutar` heredado de `render_mobiliario.gd`,
  o `_componer` reordenando). Hasta entonces el premium NO se integra.
- Los .glb nuevos están en `capturas/fuentes/bancos_espera/` SIN VERSIONAR (convención del repo
  para las fuentes de arte). Son de pago: conviene decidir si se versionan.

## 2026-08-12: GAMA DE BANCOS CERRADA — norma "1 celda = 2 plazas"
NORMA FIJADA CON EL USUARIO (la clave de todo el lío de estas sesiones):
- **1 celda = 1 módulo = 2 plazas.** Un banco más largo se hace ENCADENANDO módulos, nunca
  agrandando el mueble. Así la ALTURA deja de depender de la LONGITUD, que era el nudo.
- **Las plazas van a 1/4 y 3/4 de cada celda** -> la distancia entre dos sentados es SIEMPRE media
  celda (20 px en X, 10 en Y, 22,4 px en recta), tanto dentro de un módulo como en la junta entre
  dos. Requisito literal del usuario. La fórmula de reparto uniforme ya lo cumple cuando
  plazas = 2 x celdas.
- **Ninguna pieza puede PASARSE de su celda** (solaparía). Como el sprite es de píxeles enteros y
  1 px = 0,025 celdas, el 1,000 exacto NO existe: se elige siempre el valor inmediatamente por
  debajo. Quedan en 0,988 / 0,963 / 0,988.
- **Techo de altura**: ningún mueble de sala de espera pasa de la ventanilla (1,31 muñecos).
  Los tres quedan en 0,93 / 1,04 / 1,11.
- Se DESCARTA medir los cojines del PNG (`AnclajeSprite.centros_de_asiento`, que sigue existiendo
  sin usarse): los cojines del arte no caen a 1/4 y 3/4, así que respetarlos rompía la distancia
  constante. Manda la norma; el arte se elige para encajar en ella.
ARTE: los tres bancos son los modelos VIEJOS recalibrados (receta v8 en `_render_bancos_barrera`):
banco_madera_summer 0,6715 · banco_espera_medio 0,6280 · banco_espera_pro 0,6492.
Fichas: los tres con superficie 1 y plazas 2.
ENCARGOS A SUMMER DESCARTADOS (3,22 $ en total, 6 piezas): los módulos nuevos (basico/medio/pro)
y el banco de 3 plazas alargado son MÁS CUADRADOS que los viejos (ratio 1,40-1,81 contra 2,07-2,57)
y dejan 21-34 % de hueco. Se quedan guardados en `capturas/fuentes/bancos_espera/` por si algún día
cambia la escala. LECCIÓN: el arte se evalúa a 40 px con un muñeco sentado delante, NO en la vista
de catálogo; y las proporciones NO se pueden pedir por texto a un generador (se pidió ratio 3,75 y
devolvió 2,00). El número que hay que exigir para esta rejilla es **largo = 2,6 x alto**.
Suite: 974/974 verde. Tests actualizados a la norma (leen las plazas del catálogo para no caducar).
PENDIENTE: precios (80/150/240 se fijaron para otro aforo) · el pro sigue pareciéndose al medio ·
la mesita de revistas de Summer está descargada y sin integrar · verificación in-game con los 2
sentados a la vez (la sonda solo pilló uno).

## 2026-08-12: LOS ASIENTOS TIENEN DOS EJES (decisión de diseño del usuario)
El usuario preguntó "¿qué se gana al subir de nivel de asiento?" y eligió los DOS ejes:
1. **CONFORT** (`aporte`, ya existía y estaba implementado — el usuario creía que no):
   `mult_paciencia = 1 − 0,02 × confort_sala` con suelo 0,6. Actúa DURANTE la espera: aguantan más
   antes de largarse. Subido de 2 / 3,5 / 5 a **2 / 4 / 7** para que el salto de gama se note (el
   espacio es el recurso escaso, así que el caro tiene que rendir más POR CELDA).
2. **NOTA AL SALIR** (`factor_satisfaccion`, NUEVO): **1,05 / 1,12 / 1,20**. Multiplica la
   puntuación de la visita junto al factor de espera y al de trato:
   `puntuacion = base × espera × trato × asiento`. Encajó sin inventar sistema porque F3 ya era una
   multiplicación de factores. **Y tiene retorno económico**: la satisfacción de CIERRE alimenta el
   retorno de la DGP en Economía, así que comprar buenos asientos se traduce en dinero.
Implementación: `Comodidad.factor_satisfaccion` (esquema) · `Construccion.factor_satisfaccion_de_sala`
(media PONDERADA POR PLAZAS — lo que cuenta es en qué se sienta la gente, no cuántos muebles hay; sin
asientos → 1,0 neutro) · `Paciencia.puntuacion_atendida(..., factor_asiento)` y `_factor_asiento_de`
(pregunta por las salas de espera del SERVICIO y toma la mejor; NO mira el asiento concreto que ocupó
—eso es de la capa visual y Paciencia no debe depender de ella, ADR-0001).
7 tests nuevos (4 en bancos_multiplaza_test, 3 en paciencia_puntuacion_test). Suite 981/981 verde.

## 2026-08-14: SOMBRAS DE CONTACTO — decisión B (30%) + test blindaje de huella
Sesión nueva (Fable 5 coordina; Sonnet 5 ejecuta; el usuario descartó Antigravity: no ofrece
modelos Claude 5 y el BYOK no funciona en Windows — se sigue en Claude Code).
DECISIONES DEL USUARIO:
- Sombra de contacto bajo muebles y NPC: variante **B, alfa pico 0,30**, color (10,10,15),
  caída (1−r²)^1,2. Elegida sobre hoja de 4 variantes (sin/18%/30%/45%) montada con sprites
  reales a escala del juego. La elipse se define EN EL PLANO DEL SUELO y se proyecta
  (eje u→(1,0.5), v→(−1,0.5) por px lógico) — una elipse alineada a pantalla queda descentrada
  del mueble girado 45° (se vio en la propia hoja y se corrigió antes de enseñarla).
- La sombra del NPC compensa el BOTE del andar (visual.position resta el bote en
  npcs_flujo:634): el cuerpo bota, la mancha queda pegada al suelo. Sentado → sombra oculta.
- Test nuevo que BLINDA la norma "ningún sprite se pasa de su huella" (hasta hoy se medía a
  mano): mide todo el catálogo con AnclajeSprite.semiejes_base por orientación; tolerancia 0.
EN MARCHA (2 agentes Sonnet 5 en paralelo):
1. Implementación sombras: sombra_contacto.gd nuevo + construccion.gd (primer hijo del raiz,
   semiejes de semiejes_base, centro geométrico de la huella) + muneco.gd/npcs_flujo.gd
   (hijo "Sombra", compensación de bote) + CAPA_SOMBRA=-1 en puestos (mostrador; sentados sin
   sombra) + ADR-0005 + tests. Suite puerto 6008.
2. tests/unit/construccion/mobiliario_huella_test.gd. Suite puerto 6009.
Hoja de decisión: scratchpad de la sesión (hoja_sombras.py / .png).
PENDIENTE al volver los agentes: verificar informes CONTRA DISCO, sonda visual in-game con
sombras (auditar yo antes de enseñar), commit por hito con verde.

## 2026-08-14 (tarde): BUG GORDO CAZADO — sprites nacidos en la carga dentro de la bolsa NO se pintan
El primer intento de sombras (Sprite2D hijo de cada mueble/muñeco) quedó implementado y con tests
verdes… y EN PANTALLA no salía NI UNA sombra. Diagnóstico mío con sondas y muestreo de píxeles
(nada de ojímetro):
- Los nodos existían, visible=true, textura bien (alfa 0,996 en el centro), transform bien, cadena
  de padres impecable (autopsia completa). Y cero efecto en píxeles.
- MATRIZ DE PRUEBAS: fresco→bolsa PINTA · fresco→raíz real del mueble PINTA · duplicate() de una
  víctima PINTA · la víctima original NO PINTA en ningún sitio (ni reparentada) y NO se cura
  (queue_redraw, visible off/on, z_index=-1). Sin duplicados de muebles (descartado).
- REGLA EMPÍRICA: todo CanvasItem creado DURANTE LA CARGA como descendiente de MundoProfundo
  (y-sort anidado) queda permanentemente sin renderizar. Creado después, o fuera de la bolsa,
  pinta siempre. NO reproducible en escena mínima (probado: 2 y-sort anidados, cámara desplazada,
  reparenteo en el mismo frame — todo pinta en aislado). Causa raíz del motor: sin identificar.
- Segundo hallazgo: semiejes_base mide las PATAS (silla madera 5,25×5,25; estantería 2,75 de
  fondo) → sombra invisible de puro pequeña. Añadido SEMIEJE_MINIMO_MUEBLE=9.0 +
  semiejes_para_mueble() en sombra_contacto.gd.
- LECCIÓN DE PROCESO: los tests de estructura del agente estaban verdes con las sombras invisibles.
  La verificación visual/numérica de PÍXELES es obligatoria para todo lo que pinte en pantalla.
REDISEÑO EN MARCHA (encargado al agente con spec detallada): CapaSombras única (Node2D, z=-1,
HERMANA de MundoProfundo, territorio probado-seguro) que dibuja todas las elipses en _draw() desde
un registro con weakrefs; muebles se registran al crearse, colocar_muneco deja meta
pos_suelo_sombra (destino sin bote). Criterio de éxito NUMÉRICO en la sonda _diag_sombras.
Sondas de esta cacería: _diag_sombras (radiografía+bisecciones), _diag_sombra_aislada,
_diag_semiejes_sombra — desechables.

## 2026-08-15: SOMBRAS EN EL JUEGO (CapaSombras) + huella BLINDADA Y EN VERDE
CIERRE de la cacería de ayer — el fantasma era EL INSTRUMENTO: `get_viewport().get_texture().
get_image()` en el renderer Compatibility PIERDE contenido (los "nodos envenenados" pintaban
PERFECTAMENTE en la ventana real; verificado con PrintWindow + muestreo de píxeles). Lección
grabada a fuego: **verificación visual = captura de la VENTANA (PrintWindow), nunca el volcado
del viewport**. La sonda `_diag_sombras` ya se queda 15 s quieta para capturarla desde fuera y el
`.ps1` de captura está en el scratchpad de la sesión (captura_ventana.ps1).
- El rediseño CapaSombras SE QUEDA (aunque el motivo original fuera fantasma): una capa única
  z=−1 hermana de la bolsa, registro con weakrefs, cero nodos por mueble, orden garantizado por z.
  Suelo mínimo de semiejes (9 px lógicos) para muebles de patas finas.
- Verificación numérica en ventana real: sombra de silla medida (64,73,90) vs suelo (68,78,96) —
  coincide con la predicción teórica de la curva B a ese radio. En suelos claros se lee clara;
  en salas oscuras queda sutil (knob: SombraContacto.ALFA_PICO si el usuario quiere más).
- RECALIBRADO de los 2 infractores de huella (pedido expreso del usuario): banco_espera_pro
  (receta v9 en _render_bancos_barrera: 0,6492→0,6332) y escritorio_trabajo (la receta canónica
  resultó ser _render_biblioteca_fichajes, objetivo_px 58→49; el escritorio encoge ~15%, hoja
  antes/después en scratchpad hoja_recalibrado.png, PENDIENTE del OK visual del usuario).
  Medidos tras promover+import: ambos 0,988 celdas máx en las 4 vistas.
- SUITE: **996/996 verde, Exit code 0** (era 981 + 1 huella + 8 sombra_contacto + 5 muneco_sombra
  + 1 más de la suite previa). Arranque limpio.
- Agente-gotcha nuevo: el agente implementador murió por watchdog (600 s sin progreso) tras 4
  atascos; el rediseño lo ejecutó Fable directamente.
- Informe de PAREDES (pregunta del usuario, agente verificado): las paredes JUGABLES (salas,
  fachada, muros del pincel) son 100% dibujo por código (TramoPared.draw_colored_polygon), CERO
  kit; el Building Kit (79 glb) solo aporta 22 piezas decorativas manuales del diseñador de
  entorno; la garita/tejados/barricadas del kit siguen sin usar; el defecto "dientes de 2 px"
  sigue sin arreglo activo (dos parches desactivados por veredicto del usuario 2026-08-09).

## 2026-08-15 (tarde): DECISIÓN — segundas plantas APLAZADAS del todo
El usuario descarta incluso la "base mínima" auditada (save con planta:0, claves p0:, proyección
con offset, dimensiones indexables, ADR): las comisarías van PREDISEÑADAS por nivel y no se
expanden, así que las plantas pertenecen al diseño de futuras comisarías (sistema #26 Escalado).
La auditoría completa de supuestos de planta única (por sistema, con S/M/L y los 5 pasos de base
mínima) quedó en el informe del agente de esta sesión — recuperarla de ahí si el tema vuelve.
Cola vigente: ① verificar Fase 1 del pincel (agente escribiendo) → ② maqueta del menú de
construcción estilo Sims (SIN selector de planta) → ③ fotomontaje pared definitiva kit-vs-código.

## 2026-08-15 (noche): FASE 1 DEL PINCEL ENTREGADA + sombra de NPC en su sitio
- Pincel de muros estilo Sims COMPLETO: fantasma del trazo entero semitransparente (verde/rojo
  por validez del TRAMO COMPLETO) + coste en vivo + construir al soltar en dos pasadas +
  `Construccion.puede_construir_muro/puede_demoler_muro` públicas y puras (fin de la lógica
  duplicada en la UI). El pincel del F12 pasa al MISMO gesto (ancla+eje clavado+fantasma+aplicar
  al soltar) con matemática acumulada — el "diente de 2 px" de los muros del kit era un bug de
  COLOCACIÓN (redondeo por celda), verificado con spike al píxel (pendiente del kit 0,4997 ≈ 0,5;
  0 saltos al encadenar con paso exacto; la costura por unión es el CANTO del módulo = panelado).
- Agente Sonnet: 5 atascos (~25-40 tool-uses el patrón) + 3 Godots colgados; verificación final
  hecha por Fable. Suite 1009/1009 verde (13 tests nuevos). Arranque limpio.
- 🐛 cazado EN VIVO por el usuario: la sombra del NPC salía corrida — `pos_suelo_sombra` se
  guardaba en LOCALES de _capa_escena y CapaSombras la dibujaba como global. Arreglado
  (to_global) y medido en ventana: 22 unidades más oscura bajo los pies, en su sitio.
- Defecto menor conocido: el fantasma del trazo se dibuja POR ENCIMA del HUD superior cuando el
  muro cae en el borde norte de la pantalla (capa de preview vs capa del HUD) — apuntado, sin
  arreglar.
- Capturas de verificación en scratchpad: fantasma_arrastre.png / muro_final.png / ventana_sonda.

## 2026-08-15 (noche 2): UI MODERNA APROBADA — arranca la implementación por fases
- El usuario APRUEBA la dirección "moderno Two Point/Sims" (maqueta v2 del panel de construcción
  y v3 con el HUD superior a juego: pastillas, tarjetas blancas con sombra suave, acento azul,
  chips de estado, dinero arriba). Las variantes temáticas A/B/C (expediente/táctico/juguete) NO
  gustaron — lección: el usuario quiere lenguaje de juego moderno, no disfraces.
- Maquetas y scripts guardados en design/ux/maquetas-menu-2026-08/ (12 archivos).
- captura_ventana.ps1 promovida a tools/ con parámetro -Salida (herramienta de verificación).
- PLAN DE IMPLEMENTACIÓN (aprobado): F0 kit_ui_moderno (componentes reutilizables) → F1 panel de
  construcción (mata rótulos truncados; dinero fuera del panel) → F2 HUD superior → F3 resto de
  pantallas (Personal, Horario, detalle de mesa, avisos) DISEÑÁNDOLAS ENTONCES con el kit probado
  (decisión: primero aplicar, luego diseñar lo demás con el kit).
- EN MARCHA: agente Sonnet (ui-programmer) con F0+F1; verificación final con suite + captura de
  ventana auditada. Vigilar atascos (patrón ~25-40 tool-uses).

## 2026-08-15 (cierre por apagado): PANEL DE CONSTRUCCIÓN MODERNO — implementado, captura buena
- F0+F1 IMPLEMENTADOS (agente Sonnet 4 atascos + remate de Fable): kit moderno en
  kit_ui_comisario.gd (tarjeta/pastilla/chip/barra/toggle), panel nuevo en modo_construccion.gd
  (buscador vivo + toggle Función/Sala[deshab.] + categorías laterales + rejilla de tarjetas con
  scroll + ficha con barras Confort/Nota/Paciencia + spec en design/ux/menu-construccion-spec.md).
- ARREGLOS DE FABLE tras auditar capturas: (1) Button NO es contenedor → contenido anclado
  PRESET_FULL_RECT + ALTO_TARJETA_MODERNA fijo (los nombres salían en vertical); (2) márgenes del
  toggle_segmentado; (3) ANCHO_TARJETA 116→134 (DOCUMENTACIÓN partía palabra); (4) bancos añadidos
  a COMODIDADES_ROTACION_DIRECTA (miniatura genérica → sprite real); (5) tarjeta Asiento usa
  textura_silla_espera(); fuente nombre tarjeta 11→10.
- CAPTURA FINAL BUENA: scratchpad panel_implementado.png (auditada: ni un texto roto, miniaturas
  reales, ficha OK). Sonda: tools/_diag_panel_construccion_v2.{gd,tscn}.
- ⚠️ PENDIENTE AL VOLVER (¡PRIMERO!): re-ejecutar SUITE COMPLETA + arranque (el último run se
  perdió por un error del entorno; la base previa a los 5 retoques de estilo estaba 1035/1035
  verde). Si verde → enseñar panel_implementado.png al usuario → push con su OK → F2 (HUD
  superior, maqueta v3) → F3 (Personal/Horario/detalle mesa/avisos con el kit).
- HUD superior viejo sigue en pantalla (F2 sin empezar, correcto por fases).
