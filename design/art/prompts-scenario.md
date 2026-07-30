# Prompts para Scenario — Comisario

> **Estado**: primer lote de concept art. 2026-07-30.
> **Contexto**: el usuario tiene el plan **gratis (~50 créditos, sin API)**, así que estas
> generaciones se hacen **a mano desde la web**. Con 50 créditos hay para **muy pocas tiradas**:
> estos prompts están escritos para acertar a la primera, no para iterar veinte veces.

---

## 0. Antes de gastar un solo crédito: para qué es esto

Es **concept art**, no el sprite del juego. Conviene tenerlo claro porque cambia lo que hay que
pedirle a la IA.

El plan de producción acordado (art bible, §5) es **3D pre-renderizado a sprites**: se modela el
personaje una vez en 3D y se renderiza desde los 4-8 ángulos que necesita la vista isométrica. Se
hace así porque la IA generativa **falla justo en lo que este juego necesita**: el mismo personaje
visto desde cuatro ángulos, coherente entre sí. Pídele cuatro vistas y te da cuatro personas
parecidas, no una persona girada.

Entonces, ¿para qué sirve Scenario aquí? Para lo de antes:

| Sirve para | NO sirve para |
|---|---|
| Fijar **cómo es** el personaje antes de modelarlo (uniforme, silueta, paleta) | Sacar los sprites finales de los 4-8 ángulos |
| Tener una **referencia visual** que enseñarle a quien modele en 3D (o a ti mismo) | Sustituir el modelo 3D |
| Explorar variantes rápido (hombre/mujer, rangos, ODAC vs Documentación) | Animaciones |
| Props estáticos, texturas de suelo, iconos de UI | Nada que necesite coherencia entre ángulos |

**Consecuencia práctica**: en esta tanda pide **una vista de tres cuartos, de cuerpo entero, ficha de
personaje**. Ni pixel art, ni isométrico, ni cuatro ángulos. Eso viene después y por otro camino.

---

## 1. La tensión que hay que resolver en este primer lote

Tú has pedido *"lo más realista posible"*. El art bible tiene decidido **tono Two Point** (cartoon
estilizado, decisión tuya de hoy mismo).

No es una contradicción si se ordena bien, y de hecho es el orden correcto de trabajo:

1. **Primero realista** — para clavar el uniforme. Necesitas saber exactamente cómo es un policía
   nacional español antes de estilizarlo. Un cartoon con el uniforme mal es un cartoon mal.
2. **Después estilizado** — se le aplican las proporciones Two Point (cabeza grande, cuerpo
   simplificado, detalle solo donde se lee a distancia).

Así que **este primer lote es el realista**, y es deliberado. El siguiente será la versión
estilizada partiendo de él.

---

## 2. PROMPT PRINCIPAL — Policía Nacional (Documentación, ventanilla)

> ⚠️ **Verifica el uniforme tú antes de generar.** Yo puedo describir un uniforme genérico de
> policía español, pero **no debo darte por seguros detalles concretos** del uniforme actual del CNP
> (tonos exactos, colocación de emblemas, galones por rango). Búscate 2-3 fotos de referencia
> oficiales y ajusta las líneas marcadas con 🔍 antes de tirar. Es lo que más va a mejorar el
> resultado, mucho más que retocar el prompt.

**Prompt (en inglés — los modelos responden mejor):**

```
full body character reference sheet of a Spanish national police officer, front three-quarter
view, standing relaxed pose, neutral expression, administrative desk officer

uniform: dark navy blue police uniform, navy blue trousers, navy blue short-sleeve polo shirt
tucked in, black duty belt, black boots, shoulder patch insignia, chest name tape 🔍

realistic proportions, realistic fabric folds and material, studio character concept art,
clean neutral light grey background, even soft studio lighting, no harsh shadows,
sharp focus, high detail on uniform, full figure visible head to feet, centered composition
```

**Negative prompt:**

```
cartoon, anime, cel shading, pixel art, low poly, blurry, distorted hands, extra limbs,
weapon drawn, aggressive pose, dark moody lighting, dramatic shadows, cropped legs, cropped head,
busy background, text, watermark, multiple characters, american police, military camouflage
```

**Ajustes sugeridos:**

| Ajuste | Valor | Por qué |
|---|---|---|
| Modelo | el base más realista que tengas | No un modelo de estilo cartoon: el estilizado viene después |
| Relación de aspecto | **vertical (2:3 o 9:16)** | Es una figura de pie: en cuadrado sale recortada o diminuta |
| Nº de imágenes | **4 de golpe** | Cuesta lo mismo por imagen y multiplicas por 4 las probabilidades de acertar |
| Semilla | anótala si algo te gusta | Es lo que te deja repetir el mismo look en las variantes |

**Por qué el prompt dice lo que dice:**

- *"administrative desk officer"* y *"standing relaxed"*: no queremos un poli de acción. En este
  juego atiende en una ventanilla; la pose tiene que ser la de alguien de pie, tranquilo.
- *"weapon drawn"* en el negativo: sin esto, la IA por defecto te lo pone en pose táctica.
- *"american police"* en el negativo: es el sesgo más fuerte que tienen estos modelos con la palabra
  "police". Sin excluirlo, sale con uniforme azul claro de sheriff.
- *"full figure visible head to feet"* y *"cropped legs"* en el negativo: para una ficha de personaje
  necesitas los pies; los modelos tienden a encuadrar de cintura para arriba.
- *"clean neutral light grey background"*: fondo plano para recortar fácil y para juzgar la silueta.

---

## 3. VARIANTES (mismo prompt, cambiando una línea)

Si la primera tanda sale bien, **guarda la semilla** y cambia solo lo marcado. Con 50 créditos yo
elegiría **dos** de estas, no las cinco.

| Variante | Qué cambiar |
|---|---|
| **Mujer policía** | `Spanish national police officer` → `female Spanish national police officer`, y añade `hair tied back` |
| **De más rango** (jefe/oficial) | añade `senior officer, rank insignia on shoulders 🔍, more formal shirt` |
| **ODAC (denuncias)** | añade `seated at a desk, taking a statement, writing` — ODAC es sentado, no de ventanilla |
| **Cara de cansado** | `neutral expression` → `tired expression, end of a long shift` — para el sistema de cansancio |
| **Vista de espaldas** | añade `back view` — le hace falta a quien modele el 3D |

---

## 4. Lo que NO conviene generar todavía

- **Los 4-8 ángulos del sprite.** Es justo lo que la IA hace mal y donde quemarías los créditos sin
  resultado usable.
- **Ciudadanos.** Van a ser muchos arquetipos distintos; hasta que el estilo del policía no esté
  cerrado, generarlos es tirar créditos.
- **Nada isométrico.** El ángulo del juego sale del render 3D, no del prompt.

---

## 5. Cuando tengas la imagen

1. Guárdala en `capturas/` o en `design/art/referencias/` (dime cuál prefieres y lo dejo fijado).
2. La miro y **anoto en el art bible** lo que se decida: paleta real del uniforme, silueta,
   accesorios que distinguen los roles.
3. Con eso se cierra §5 (dirección de personajes) y se puede empezar el modelo 3D.

> **Decisión que sigue pendiente y que esta imagen ayuda a tomar**: §5 del art bible —
> personajes **sin cara** (más barato, la expresión vive en la postura) vs **cara mínima** (más
> expresivo, pero multiplica 4-8 ángulos × expresiones). Cuando veas al personaje generado te va a
> resultar mucho más fácil decidirlo.

---

## 6. Sobre el plan de Scenario

Corrección a lo que te dije antes: **el plan Starter de 15 $ SÍ incluye acceso a API** — lo estás
leyendo en su web y mi comprobación anterior se equivocó en ese punto.

Con eso, la diferencia real entre Starter (15 $) y Pro (45 $) para este proyecto es:

| | Starter 15 $ | Pro 45 $ |
|---|---|---|
| Créditos/mes | 1.500 | 5.000 |
| API | Sí | Sí |
| **Entrenar modelo propio** | 🔍 confírmalo en su web | Sí |
| Almacenamiento | 50 GB | 500 GB |

**Lo que entrenar un modelo propio te daría**: coherencia de estilo entre TODO lo que generes —
que el mostrador, la silla y la papelera parezcan del mismo juego. Es lo único que de verdad
justifica el salto a 45 $, y **no hace falta todavía**: primero hay que tener un estilo que
entrenar, y eso es exactamente lo que estás empezando a hacer ahora con los créditos gratis.

**Mi recomendación**: gasta los 50 gratis en este lote. Si el resultado te convence, **Starter**.
El salto a Pro, cuando tengas 20-30 imágenes de estilo cerrado con las que entrenar.
