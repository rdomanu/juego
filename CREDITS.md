# Créditos y atribuciones — Comisario

Este archivo recoge **todo el material de terceros** usado en el juego y la atribución que su
licencia exige. Es una obligación legal, no una cortesía: las licencias Creative Commons "BY"
permiten usar el material —incluso comercialmente— **a cambio de citar al autor**.

> **Regla del proyecto**: ningún asset de terceros entra en `assets/` sin su fila en esta tabla. Si
> no sabes la licencia de algo, no se usa. Cuesta más quitarlo después que buscarla ahora.

---

## Modelos 3D

| Asset | Autor | Licencia | Uso en el juego | Estado |
|---|---|---|---|---|
| ["🏫 girl"](https://skfb.ly/orY8Q) | Karma🔥 | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) | Base para el personaje femenino (pendiente de vestir con el uniforme del CNP) | **En evaluación** |
| ["Police Officer Portrait"](https://skfb.ly/pKqVq) | restore50 | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) | Policía masculino | **En evaluación** |
| ["Police Officer in Uniform"](https://skfb.ly/pKqUM) | restore50 | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) | Policía femenina | **En evaluación** |
| ["Isometric office"](https://sketchfab.com/3d-models/isometric-office-d31464eed8044190911b221648aca432) | Companion_Cube | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) | Mobiliario de oficina (solo la geometría; ver nota) | **En evaluación** |

### Texto de atribución a incluir en los créditos del juego

```
"🏫 girl" (https://skfb.ly/orY8Q) by Karma🔥
is licensed under Creative Commons Attribution
(http://creativecommons.org/licenses/by/4.0/).

"Police Officer Portrait" (https://skfb.ly/pKqVq) by restore50
is licensed under Creative Commons Attribution
(http://creativecommons.org/licenses/by/4.0/).

"Police Officer in Uniform" (https://skfb.ly/pKqUM) by restore50
is licensed under Creative Commons Attribution
(http://creativecommons.org/licenses/by/4.0/).

"Isometric office" (https://skfb.ly/6TVso) by Companion_Cube
is licensed under Creative Commons Attribution
(http://creativecommons.org/licenses/by/4.0/).
```

> ✅ **Atribuciones completas (2026-08-01)**: las cuatro líneas de arriba son las que genera
> Sketchfab, aportadas por el usuario. Cada fila pasa de "En evaluación" a "En uso" cuando sus
> sprites entren en `assets/`.

> ⚠️ **Nota sobre el paquete de oficina**: se usa **solo la geometría del mobiliario**, renderizada
> a sprites propios. Las imágenes incrustadas en sus texturas (pósters, cuadros, diplomas, fotos)
> **no se usan en el juego**: son material de terceros que el autor del paquete incorporó y cuya
> procedencia no está confirmada.

**Dónde tiene que aparecer**: en una pantalla de créditos accesible desde el menú del juego. Con CC
BY basta con que esté ahí y sea legible; no hace falta ponerlo en pantalla durante la partida.

**Ojo si el modelo se MODIFICA** (que es el plan: vestirlo de policía): CC BY permite modificar, pero
la atribución **se mantiene igual** y conviene indicar que se ha modificado. Añadir *"— modificado"*
al final de la línea es suficiente.

---

## Referencias visuales (NO son assets del juego)

Material usado solo como **referencia** para diseñar, que no se distribuye con el juego:

| Material | Origen | Para qué |
|---|---|---|
| Uniformes del Cuerpo Nacional de Policía | [Wikipedia](https://es.wikipedia.org/wiki/Anexo:Uniformes_del_Cuerpo_Nacional_de_Polic%C3%ADa) (CC BY-SA) | Verificar el uniforme real: prendas, colores, divisas |
| Capturas de Two Point Campus / Hospital | Capturas del propio usuario | Referencia de tono y tratamiento visual (art bible) |

Mirar una imagen para entender cómo es un uniforme **no** genera obligación de atribución: lo que
se copia es el conocimiento, no el archivo. Distinto sería incluir la imagen en el juego.

---

## Material generado con IA

| Material | Herramienta | Notas |
|---|---|---|
| Referencia del policía (`design/art/referencias/policia_recortado.png`) | Gemini (imagen) | Generado a partir del uniforme de Wikipedia. **Referencia interna**, no arte del juego |

---

## Descartados, y por qué (para no volver a evaluarlos)

| Asset | Motivo del descarte |
|---|---|
| `stylized-girl.zip` (Sketchfab) | Sin esqueleto (0 `Deformer`/`Skin`): no puede animarse. Solo cabeza, sin uniforme. Y el archivo se llama "sell on sketchfab" → licencia de pago sin aclarar |
| `asset_azLhfgxR14...glb` (3D desde una foto) | Bajorrelieve: 0,25 de fondo/ancho frente al ~0,60 de una persona. Sin esqueleto. Solo válido de frente |
