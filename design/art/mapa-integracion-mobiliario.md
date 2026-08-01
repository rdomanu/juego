# Mapa de integración del mobiliario — pack "Isometric office"

Decisiones del usuario sobre qué pieza del pack (catálogo `capturas/NPC/Oficina/catalogo/`,
hoja `index_integracion.html`) sustituye a cada visual del juego. La regla de oro sigue siendo
ADR-0004: esto es CAPA VISUAL — el modelo no se entera.

## Decidido por el usuario (2026-08-01, viendo la hoja en Chrome)

| Pieza del pack | Destino en el juego | Estado |
|---|---|---|
| **OBJ_021** (escritorio) | **El mostrador de las ventanillas** (los puestos de atención: Documentación, TIE, ODAC). Sustituye a la mesa que hoy dibuja `mesa_atencion.gd` por código | **A integrar YA** |
| **OBJ_042** (solo las **2 pantallas** del grupo silla+monitores) | La comodidad **equipo_informatico** (la mejora de equipamiento), que estaba "sin candidato" | **A integrar YA** |
| **OBJ_000** (mostrador curvo de recepción) | **Seguridad de la entrada del edificio** — idea de futuro; conecta con el puesto `puesto_seguridad` que existe en `datos/` pero está desactivado en la UI | Idea registrada, NO integrar aún |
| **OBJ_006** (escritorio en L con silla y cajonera) | **Despacho sin atención al ciudadano** — p. ej. un futuro grupo de Policía Judicial trabajando de espaldas al público | Idea registrada, NO integrar aún |

## Decidido por el usuario — 2ª tanda (2026-08-01)

| Pieza del pack | Destino en el juego | Nota |
|---|---|---|
| **ARQ_007** (sofá de 3 plazas; estaba mal archivado como "arquitectura" por tamaño) | **`sofa_descanso`** — que resultó ser EL ÚNICO sofá del juego y es multi-celda (superficie=3): 3 plazas = 3 celdas, encaja clavado | identificado por el usuario 2026-08-01; INTEGRADO |
| OBJ_011 (sofá/sillón de 1 plaza) | **Renderizado pero sin cablear** (el juego no tiene hoy ningún mueble de 1 plaza tipo sillón). En el banquillo para una futura comodidad "sillón" si se diseña | el sprite ya existe en assets/sprites/mobiliario/ |
| **OBJ_040** | Papelera | — |
| **OBJ_002** (vía despiece) | Dispensador de agua | — |
| **silla_simple** (elegir la MÁS REPETIDA del pack entre OBJ_023/024/030/032) | Silla de espera (`asiento_basico`) | criterio objetivo: la que el autor del pack más usó |
| **La silla ROJA de OBJ_042** (extraer de su despiece SUB_042_*) | Silla del funcionario (auto, no construible) | decidido por el usuario 2026-08-01; sustituye a la candidata SUB_016_1 |
| La misma silla simple elegida para `asiento_basico` | Silla del CIUDADANO en la ventanilla (auto) | decidido por el usuario 2026-08-01 |
| **OBJ_038** (aparato negro de sobremesa — probablemente el proyector del pack; a 44 px pasa por radio) | La comodidad **`radio`** (existente, estaba "sin candidato"), horneada **con una mesita debajo** en el mismo sprite (es un aparato "para estar sobre algo", dixit el usuario) | CORRECCIÓN 2026-08-01: primero se apuntó como impresora de ODAC; el usuario lo re-identificó como radio mirando la hoja, y verificado a ojo por el coordinador |
| **OBJ_046** (teléfono) | Decorativo **sobre el mostrador de las ventanillas** — horneado dentro del mismo sprite del mostrador (OBJ_021), "de momento" | pedido 2026-08-01 |

### ⚠️ La impresora, aclarado por el usuario

- **`impresora_dni` (la comodidad existente, 2.200 €) queda SIN candidato en este pack**: una
  impresora de DNI es una máquina especializada, no una impresora de oficina. Se mantiene el visual
  actual hasta encontrar un asset adecuado en otra fuente.
- **Idea de comodidad NUEVA**: "impresora de documentos", familia ODAC, para imprimir/entregar las
  denuncias. Es una adición de juego (coste/aporte = balance): **pendiente de diseñarla con el
  usuario**, no entra sola. **Visual asignado por el usuario (2026-08-01): OBJ_008 ENTERO** —
  la cajonera con la impresora y todo lo que lleva encima, como un solo mueble.

## Decidido por el usuario — 3ª tanda (2026-08-01)

| Pieza del pack | Destino en el juego | Nota |
|---|---|---|
| **OBJ_007 y OBJ_022** (estanterías con carpetas/libros) | Estanterías para **estancias de trabajo**: ODAC (oficina de denuncias), Documentación y futuras salas de trabajo | decorativo/comodidad futura; sin números aún |
| ⚠️ OBJ_022 en concreto | Son **2 estanterías haciendo esquina**: hay que DESPIEZARLA en **1 estantería suelta** (misma técnica de semillas por malla repetida) — el jugador coloca 2 para montar la esquina él mismo | pedido 2026-08-01 |

## Pendiente de decisión del usuario

*(Nada — todas las piezas del mobiliario tienen decisión a 2026-08-01.)*

## Sin candidato en el pack (se queda el visual actual)

Las tres lámparas (punto de luz ámbar), televisión, radio, prensa, revistero, vending,
**y la impresora de DNI** (ver arriba).

## Notas de integración

- Los grupos se reconstruyen desde `catalogo_objetos_manifest.json` / `catalogo_despiece_manifest.json`
  (composición y transformadas de cada pieza); el renderizador de mobiliario genera los sprites
  a `assets/sprites/mobiliario/` en 4 rotaciones (el juego rota con R).
- CREDITS.md: la fila del pack pasa a "En uso" cuando el primer sprite entre en `assets/`.
  Solo geometría — las imágenes incrustadas en sus texturas no se usan.
