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

**Consecuencia práctica**: en esta tanda pide una **ficha de personaje de cuerpo entero, vista
frontal y en POSE EN A** (brazos algo separados del cuerpo). Ni pixel art, ni isométrico, ni cuatro
ángulos: eso viene después y por otro camino.

*Por qué pose en A y no tres cuartos*: es la pose estándar de referencia para modelar y riggear —
proporciones claras y brazos despejados. Lo confirmó el ejemplo que pasó el usuario
(`capturas/ejemplo imagen.PNG`), que es exactamente eso.

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

## 2. PROMPT PRINCIPAL — Policía Nacional (escala básica, oficina de Documentación)

> ✅ **Uniforme verificado en Wikipedia** (enlace que pasaste). Esto ya NO es una descripción
> genérica mía: son las prendas reales del uniforme de servicio ordinario del CNP **vigente desde
> 2021**. Y es bastante distinto de lo que te di antes — cambia lo importante.

### Lo que dice la fuente, y por qué importa para el prompt

| Prenda | Detalle real | Qué cambia respecto a mi versión anterior |
|---|---|---|
| Torso | **Polo azul oscuro con botones falsos** | Yo puse "camisa". Es POLO: cuello blando, sin botonadura de verdad |
| Piernas | **Pantalón azul oscuro con bolsillos de pernera** | Son pantalones tipo cargo, con bolsillos en el muslo |
| Calzado | **Botas de media caña negras** | No zapato de vestir: bota |
| Cabeza | **Gorra tipo "beisbolera"** | NO gorra de plato. La de plato es de gala/representación |
| Identificación | Placa de plástico inyectado en el polo + **número personal en velcro** | |
| Rotulación | **"POLICÍA NACIONAL" serigrafiado** en el pecho (delantera izquierda) **y en la espalda** | Detalle muy visible y muy español: sin él no se lee como CNP |
| Rango | **Divisas en los hombros mediante manguitos** (desde 2014) | Van en hombreras, no en la manga |
| Frío | Jersey de cuello de pico, cazadora o anorak, mismo color y elementos | Para la variante de invierno |

**Prompt (en inglés):**

```
full body character model sheet of a Spanish National Police officer (Policia Nacional),
front view, A-pose, arms slightly away from body, neutral expression, standing straight,
symmetrical, office desk officer, european man

modern 2021 Spanish police service uniform: very dark navy blue (almost black) short-sleeve
polo shirt with flat collar, matching very dark navy cargo trousers with thigh pockets,
black mid-calf boots, dark navy baseball cap, shoulder rank slides,
chest badge and identification number, "POLICIA NACIONAL" lettering printed on the chest

realistic materials, realistic fabric folds, detailed stitching, character concept art for 3D
modeling reference, plain dark grey studio background, even soft lighting, sharp focus,
full figure visible from head to feet, centered composition
```


**Negative prompt:**

```
fantasy, elf, armor, cape, medieval, american police, sheriff, NYPD, light blue shirt, khaki,
brown uniform, green uniform, beret, checkered band, chequered pattern, sillitoe tartan,
military camouflage, tricorn hat, peaked cap, necktie, cartoon, anime, cel shading, pixel art,
weapon drawn, aggressive pose, sunglasses, dark moody lighting, cropped legs, cropped head,
busy background, text, watermark, multiple characters, blurry, distorted hands, extra limbs
```

**Ajustes:**

| Ajuste | Valor | Por qué |
|---|---|---|
| Modelo | el base más realista que tengas | El estilizado viene después |
| Relación de aspecto | **vertical (2:3 o 9:16)** | Es una figura de pie |
| Nº de imágenes | **4 de golpe** | Mismo coste por imagen, x4 opciones de acertar |
| Semilla | anótala si algo te gusta | Es lo que deja repetir el look en las variantes |

**Por qué el negativo dice lo que dice** (aquí es donde se gana o se pierde la tirada):

- `american police, sheriff, NYPD, light blue shirt` — el sesgo más fuerte de estos modelos con la
  palabra "police". Sin excluirlo sale un sheriff de camisa celeste.
- `brown uniform` — el CNP **fue marrón hasta 1986**. Hay fotos de sobra en internet y el modelo las
  ha visto. Es justo el "uniforme antiguo" del que me avisaste.
- `green uniform` — para que no se cuele la Guardia Civil, que es verde.
- `peaked cap` (gorra de plato) y `necktie` — esos son de **gala y representación**, no del uniforme
  de trabajo. Es exactamente la confusión que me señalaste: el comisario en un acto sí lleva plato;
  el policía de ventanilla, gorra de béisbol.
- `tricorn hat` — el tricornio es de la Guardia Civil de gala. Fuera.
- `beret` (**boina**) — la boina es icono de Guardia Civil, Mossos y Ertzaintza, **no** del CNP
  actual, que usa gorra de béisbol (trabajo) o de plato (gala). Es un error muy fácil de cometer.
- `checkered band, chequered pattern, sillitoe tartan` — la **franja de cuadros** (ese damero blanco
  y azul del pecho o la espalda) es marca de **Policía Local/Municipal**, no del CNP. Sin excluirla
  se cuela sola porque en las fotos de "policía español" sale muchísimo.
- `fantasy, elf, armor, cape, medieval` — por la plantilla del ejemplo que pasaste: está entrenada
  tirando a fantasía y te cuela capa o armadura sin que la pidas.

> 💡 **El azul**: es azul marino **casi negro**, no un azul medio. Los dos uniformes históricos del
> propio CNP —el **marrón** de 1978-1986 y el **azul más claro** de 1986-2021— son la trampa: el
> modelo ha visto miles de fotos de los dos. Por eso el prompt dice *"very dark navy (almost
> black)"* y el negativo excluye `light blue shirt` y `brown uniform`.
> ⚠️ **No existe código Pantone/RGB oficial público** del azul actual (comprobado): el tono se
> decidirá a ojo sobre las referencias.

## 3. VARIANTES (mismo prompt, cambiando una línea)

Si la primera tanda sale bien, **guarda la semilla** y cambia solo lo marcado. Con 50 créditos yo
elegiría **dos** de estas, no las cinco.

| Variante | Qué cambiar |
|---|---|
| **Mujer policía** | `Spanish national police officer` → `female Spanish national police officer`, y añade `hair tied back` |
| **De más rango** (jefe/oficial) | añade `senior officer, more rank insignia on shoulder slides` — la divisa exacta por escala está en `referencia-uniforme-cnp.md` |
| **EL COMISARIO** (tú, el jefe) | uniforme DISTINTO: es de **representación**, con **gorra de plato**. Prompt aparte — ver el documento de referencia |
| **Invierno** | `short-sleeve polo` → `navy blue V-neck sweater over polo` o `navy blue jacket` |
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
