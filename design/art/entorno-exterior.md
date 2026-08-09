# Entorno exterior de la comisaría — Concepto (Draft)

*Creado: 2026-08-07. Estado: Draft, sin sign-off. Encargo inicial: "poner fuera algunos árboles,
calle... algo de vida" — el edificio hoy flota en `COLOR_FONDO` (0.13, 0.14, 0.16), un vacío oscuro
(`src/main/main.gd`). **Rediseñado el mismo día por el usuario** con un recorrido realista de acceso
(calle → control de seguridad → recinto → edificio). No toca código ni assets; es la propuesta de
dirección de arte a validar antes de producir nada.*

---

## 1. Objetivo

Dar un marco de "sitio real" alrededor del edificio (24×13 celdas) sin que ese marco compita con el
interior, Y resolver de forma creíble cómo se accede a una comisaría real: no se entra caminando
directamente desde la acera — hay un filtro de seguridad antes del aparcamiento, y el aparcamiento
antes de la puerta.

---

## 2. El recorrido — columna vertebral del concepto

```
CALLE  →  CONTROL DE SEGURIDAD  →  RECINTO (aparcamiento)  →  PUERTA DEL EDIFICIO
(acera+   (garita + barrera,        (3 plazas patrulla +      (la puerta oeste ya
calzada)   filtra el acceso)         2 plazas visita)          existente, columna 0)
```

1. **Calle**: tramo corto de acera + calzada, solo en la zona de la entrada — no rodea el edificio.
2. **Control de seguridad**: una garita de vigilancia + una barrera, ANTES de que se pueda llegar al
   aparcamiento. Es el primer filtro — nadie llega al recinto sin pasar por aquí.
3. **Recinto interior**: ya dentro del control, el aparcamiento — 3 plazas de coche patrulla + 2
   plazas libres para visitas.
4. **Entrada del edificio**: la puerta que YA existe en el plano (lado oeste, columna 0, fila ~6 —
   `_abrir_puerta_de_oficio`, `src/main/main.gd`). El recorrido nuevo desemboca ahí, no la mueve.

Todo el recorrido vive en el lado OESTE del edificio, alineado con la puerta actual — no se inventa
una entrada nueva, se construye el camino hasta la que ya hay.

---

## 3. Plano de zonas (orientación)

```
                    [ FACHADAS DE FONDO — decorado plano, sin interior ]
                    [ FACHADAS DE FONDO — decorado plano, sin interior ]

  [ PARQUE ]     CALLE → CONTROL → RECINTO/APARCAMIENTO →  EDIFICIO (24×13)
  pequeño,       (acera+  (garita+   (3 patrulla +           puerta oeste
  al flanco      calzada) barrera)    2 visita)               existente
  norte del
  recinto

                    [ FACHADAS DE FONDO — decorado plano, sin interior ]
```

- **Eje principal** (calle→control→recinto→edificio): lado **oeste**, el mismo que la puerta actual.
- **Parque**: al flanco **norte** del recinto de control/aparcamiento — no se cruza con el camino de
  entrada de coches ni de peatones, es un lateral que se ve pero no se atraviesa.
- **Fachadas de fondo**: cierran el resto del vacío (norte, este, sur — los lados que NO dan a la
  calle de acceso). Son decorado plano, sin interior: su función es que el horizonte no sea negro,
  no que se puedan visitar.

---

## 4. Reglas de paleta (heredadas y ampliadas)

- El exterior sigue más apagado que el interior claro (art-bible §3: "se retiran mobiliario, suelo y
  paredes... para que atraigan la vista las personas y lo accionable").
- **Nuevo matiz por el control de seguridad**: la garita usa la MISMA paleta institucional que el
  edificio (gris/azul CNP `#0B2A5B`), no un color de "caseta genérica" — refuerza que es parte de la
  comisaría, no un añadido ajeno. La barrera es el único elemento con rayas de aviso (rojo/blanco o
  amarillo/negro, mínimas, solo en la propia barra) — es funcionalmente una señal de tráfico, no un
  acento decorativo, así que no rompe la regla de "un solo acento de color fuerte".
- El acento de color fuerte del conjunto sigue siendo el coche patrulla (azul CNP), ahora reforzado
  por tener HASTA 3 unidades en el aparcamiento — sigue siendo un único mensaje ("aquí hay policía"),
  no tres focos de atención distintos.
- Fachadas de fondo: tono aún más apagado que la calle/control — son fondo de fondo, deben leerse
  como silueta de ciudad, nunca competir con nada del primer plano.

---

## 5. Sourcing pieza a pieza

| Pieza | Candidato gratis | Estado | Notas |
|---|---|---|---|
| **Garita de vigilancia** | Componible con **Kenney Building Kit** (`capturas/fuentes/kenney_building_kit/`): `wall` + `wall-window-square` (para ver hacia la calle) + `wall-doorway-square` + `roof-flat-square` + `column` — un cubículo 1 celda, mismo kit que ya se está usando para otras piezas | **Verificado localmente** — el kit trae exactamente estas piezas | Mejor opción: cero coste de licencia, mismo lenguaje modular que el resto |
| **Barrera del control** | `barricade-doorway-a/b/c` del mismo Building Kit (verificado, existen) — pero son barricadas de puerta/obra, no una pluma de control de acceso real | **Candidato imperfecto** | Puede leerse como "obra" más que "checkpoint" — ver decisión 1 más abajo. Biblioteca Summer no tiene una pieza confirmada de este tipo en este repo (sin evidencia local, no asumir que existe) |
| **Plazas de aparcamiento (líneas pintadas)** | Pintura de suelo **por código**, igual que "Pintar suelo" ya existe en el modo construcción actual | Sin asset — es una textura/patrón procedural | No es un recurso a descargar; es una decisión técnica que ya tiene precedente en el proyecto |
| **Coches — turismos/furgonetas únicamente** | `kenney_carkit` (CC0, ya descargado): **`police.glb`** (coche patrulla YA hecho, sin necesidad de repintar nada) + `sedan`, `sedan-sports`, `suv`, `suv-luxury`, `hatchback-sports`, `taxi`, `van`, `delivery`, `delivery-flat` para las plazas de visita | **Verificado localmente** — 102 modelos en el kit, confirmados los nombres | **Excluidos por instrucción**: `tractor`, `tractor-police`, `tractor-shovel` (los 3 tractores del kit). También fuera por no ser turismo/furgoneta: `truck`, `truck-flat`, `firetruck`, `garbage-truck`, los `kart-*`, `race`/`race-future` |
| **Bancos y farolas** | Biblioteca Summer (ya conocida de la propuesta anterior) / KayKit (`kaykit_furniture`, ya descargado, trae `lamp_standing` reutilizable como farola de calle si se prefiere ese estilo) | Parcial: KayKit verificado localmente, Summer sin evidencia de archivo en este repo | Dos candidatos válidos, cualquiera de los dos cierra el hueco sin pago |
| **Parque (árboles/setos)** | Biblioteca Summer (ya validada en la propuesta anterior) | Sin evidencia de archivo local — se asume disponible por lo ya dicho por el usuario | Igual que en el concepto anterior |
| **Parque (césped/fuente)** | Césped: color de suelo **por código** (igual que las plazas de aparcamiento). Fuente: NO hay pieza confirmada localmente; si se quiere una fuente de verdad, es la única pieza del parque sin candidato gratis verificado | Césped resuelto sin asset; fuente sin verificar | La fuente de parque NO es obligatoria — un parque pequeño con árboles+banco+césped ya cumple sin ella |
| **Fachadas de fondo** | Componibles con **Kenney Building Kit**: `wall` + `wall-window-square`/`wall-window-wide-square` + `roof-flat-*` apiladas en 2-3 alturas, sin interior (huecas por dentro, no se ve) | **Verificado localmente**, mismo kit | Ver honestidad de nivel de detalle en el punto 6 — compone bien para silueta, no para "fachada de diseño" variada |

---

## 6. Fases de producción (replanteadas)

| Fase | Contenido | Por qué en ese orden |
|---|---|---|
| **1 — mínima** | Acera + calzada corta (solo tramo de acceso) + **control de seguridad completo** (garita + barrera) + plazas de aparcamiento pintadas (sin coches todavía) | El control de seguridad **define la entrada** — sin él, cualquier coche/farola que se coloque después no tiene dónde encajar. Se prioriza sobre "romper el vacío con árboles sueltos" porque ahora hay un recorrido que respetar |
| **2** | 3 coches patrulla (`police.glb`) + hasta 2 coches de visita en las plazas libres + farolas junto al control y el aparcamiento | Da la lectura completa de "comisaría en uso" una vez el recinto ya existe |
| **3** | Parque pequeño (árboles/setos + banco; césped por código) en el flanco norte | Vida y detalle, sin bloquear el recorrido funcional de las fases 1-2 |
| **4** | Fachadas de fondo (norte/este/sur) — decorado plano sin interior | Cierra el resto del horizonte una vez el frente (fases 1-3) ya está resuelto — es lo menos urgente porque es lo más lejano a la cámara |
| **5 — fuera de alcance ahora** | Calle rodeando el edificio por más de un lado + iluminación nocturna del exterior coordinada con el mood "noche" del art-bible (§2) | Se retoma solo si el resto del roadmap visual lo justifica |

---

## 7. Piezas que necesitarían generación de pago — honestidad

**Minimizado, pero no cero esta vez:**

- **Garita**: NO necesita pago — el Building Kit la compone completa y verificada.
- **Barrera de control**: el candidato gratis (`barricade-doorway`) es aproximado, no es una pluma de
  control real. Si al verla montada no convence, es la pieza más pequeña y barata de encargar por
  generación (una sola pieza, geometría simple: poste + brazo horizontal).
- **Coches**: NO necesita pago — `police.glb` ya es literalmente un coche patrulla hecho.
- **Fachadas de fondo**: el Building Kit da silueta correcta (paredes+ventanas+tejado apilados), pero
  con una sola paleta de piezas se van a parecer todas entre sí. Para una PRIMERA iteración (fase 4)
  esto basta — es fondo, no protagonista. Si más adelante se quiere variedad real de fachadas
  (ladrillo distinto, balcones, alturas dispares), ESO sí sería candidato razonable a un pequeño
  encargo de pago — pero no hace falta para cerrar el concepto de esta propuesta.
- **Fuente del parque**: sin candidato gratis verificado, pero es opcional — el parque no la necesita
  para funcionar visualmente (árboles + banco + césped por código ya cuentan la idea).

---

## 8. Decisiones para el usuario (máx. 3)

1. **Barrera del control**: ¿se acepta el candidato gratis aproximado (`barricade-doorway` del
   Building Kit, reskinado) o se prefiere encargar la pieza específica (barato, una sola pieza) para
   que se lea claramente como pluma de control de acceso?
2. **Fachadas de fondo**: ¿basta con componer el Building Kit sin mucha variedad para la fase 4
   (rápido, gratis, un poco repetitivo), o se quiere variedad real de fachadas desde ya (probable
   encargo de pago, pocas piezas)?
3. **Parque**: ¿flanco norte del recinto (propuesto aquí, no cruza el camino de coches/peatones) o se
   prefiere otra ubicación?
