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

## Pendiente de decisión del usuario (propuestas de la hoja, sin confirmar)

| Elemento del juego | Candidato propuesto |
|---|---|
| Silla de espera (`asiento_basico`) | OBJ_023 / 024 / 030 / 032 |
| Sofá (`sofa_descanso`) | OBJ_011 (y OBJ_033/047 vía despiece) |
| Papelera | OBJ_040 |
| Impresora de DNI | OBJ_038 |
| Dispensador / fuente de agua | OBJ_002 (vía despiece) |
| Archivadores / estanterías | OBJ_001/008/009 (despiece) · OBJ_007/022 |
| Silla del funcionario (auto, no construible) | la de OBJ_042 / SUB_016_1 |

## Sin candidato en el pack (se queda el visual actual)

Las tres lámparas (punto de luz ámbar), televisión, radio, prensa, revistero, vending.

## Notas de integración

- Los grupos se reconstruyen desde `catalogo_objetos_manifest.json` / `catalogo_despiece_manifest.json`
  (composición y transformadas de cada pieza); el renderizador de mobiliario genera los sprites
  a `assets/sprites/mobiliario/` en 4 rotaciones (el juego rota con R).
- CREDITS.md: la fila del pack pasa a "En uso" cuando el primer sprite entre en `assets/`.
  Solo geometría — las imágenes incrustadas en sus texturas no se usan.
