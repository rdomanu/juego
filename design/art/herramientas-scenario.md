# Scenario (scenario.com) — Investigación de planes y precios

**Fecha de la investigación:** 2026-07-30
**Fuente principal:** páginas oficiales de scenario.com y su centro de ayuda (help.scenario.com). Todo lo que no se pudo confirmar en una fuente oficial está marcado como **⚠️ NO VERIFICADO**.

**Para qué sirve este documento:** decidir si usamos Scenario para generar props, texturas de suelo, mobiliario, iconos de UI y otros elementos estáticos de nuestro tycoon isométrico — y con qué plan.

---

## 1. Tabla comparativa de todos los planes

| | **Free** | **Starter** | **Pro** | **Max** | **Enterprise** |
|---|---|---|---|---|---|
| **Precio/mes (mensual)** | $0 | $15 | $45 | $75 | Precio a medida (hablar con ventas) |
| **Precio/mes (facturación anual, -33%)** | — | ~$10.05 | ~$30.15 | ~$50.25 | A medida |
| **Créditos (Compute Units)** | 50 al día | 1.500/mes | 5.000/mes | 10.000/mes | A medida |
| **Usuarios** | 1 | 1 (single user) | 1 (single user) | hasta 25, con coste extra por asiento desde $30/mes | mínimo 10 usuarios, facturación anual |
| **Almacenamiento** | — | 50 GB | 500 GB | 1 TB (+1 TB por asiento) | 10 TB (+1 TB por asiento) |
| **Acceso a la API** | No | **No** | **Sí** | Sí | Sí |
| **Entrenar modelo propio (custom training)** | No | **No** | **Sí** | Sí | Sí |
| **Modelos de edición (Gemini, GPT, Runway/Kontext)** | No | No | Sí | Sí | Sí |
| **Cola prioritaria / generaciones "relax" ilimitadas** | No | No | Sí | Sí | Sí |
| **Colaboración en equipo** | No | No | No | Sí | Sí |
| **Soporte** | — | Comunidad (Discord) | Tickets | Tickets prioritarios | Cuenta dedicada + Slack |
| **Extras** | — | — | 10% descuento en compute | 20% descuento en compute | 30% descuento en compute; SSO, SOC2, auditoría |

**Fuentes:** [Pricing | Scenario](https://www.scenario.com/pricing), [Scenario Pricing: Pick the Perfect Plan | Scenario](https://help.scenario.com/en/articles/pricing-plans/)

Los créditos **no se acumulan** de un mes a otro (ver punto 5). El plan Enterprise no publica precio: es "a medida", contactando con ventas — cualquier cifra concreta que veas en otro sitio para Enterprise (ej. "$125/usuario/mes") es de terceros no oficiales y no se pudo confirmar en la web de Scenario: **⚠️ NO VERIFICADO**.

---

## 2. ¿El plan de $15 incluye acceso a la API? ¿Y el de $45?

**Respuesta corta: NO, el plan de $15 (Starter) NO incluye API. El de $45 (Pro) SÍ la incluye.**

Esto se confirmó en tres fuentes oficiales independientes:

- La propia página de features de la API dice textualmente: *"Sign up for a paid plan (Pro, Team, or Enterprise) and generate your API key from the settings page."* — [Scenario REST API | Scenario](https://www.scenario.com/features/api)
- El artículo de ayuda sobre uso de la API dice: *"API access is available exclusively through selected paid plans (Pro & above)"* — [Scenario API Pricing & Creative Unit Costs](https://help.scenario.com/en/articles/api-usage-and-credits-creative-units)
- La página principal de precios, en la sección de Enterprise, menciona explícitamente integración de API/pipelines — no aparece esa mención en las tarjetas de Starter o Pro, coherente con que el acceso "de base" empieza en Pro.

Esto es **crítico** para nuestro caso: si el plan pensamos usarlo solo desde la web (subir referencias, generar a mano, descargar), Starter ($15) nos sirve. Pero si queremos automatizar generación (por ejemplo, generar un lote de 50 iconos de UI desde un script, o usar el servidor MCP para pedirle a un asistente de IA que genere assets directamente), **necesitamos como mínimo el plan Pro ($45)**.

---

## 3. ¿El plan de $15 permite entrenar un modelo propio?

**No.** El entrenamiento de modelo propio ("Train custom models") aparece listado como feature del plan **Pro ($45)** en adelante. El plan Starter da acceso a los modelos ya existentes de Scenario (más de 65 modelos "optimizados"/base), pero no permite subir tu propio set de referencias para entrenar un modelo con tu estilo.

Esto importa para nuestro caso: si queremos que todos los props/iconos del juego tengan un estilo visual consistente y propio (en vez de usar el look genérico de un modelo base), eso requiere entrenar un modelo — y **eso exige Pro o superior**, no Starter.

**Fuente:** [Pricing | Scenario](https://www.scenario.com/pricing), [Scenario Pricing: Pick the Perfect Plan | Scenario](https://help.scenario.com/en/articles/pricing-plans/)

---

## 4. ¿Cuántos créditos cuesta una generación típica?

**Aviso importante primero:** la propia documentación oficial de Scenario se niega deliberadamente a publicar cifras fijas. El artículo dedicado a esto dice textualmente:

> *"The exact CU cost always appears in the generator, Compute Planner, or API before you run."*
> *"This guide describes relative cost — not fixed prices. CU rates change as models and pipelines evolve."*

— [Model Costs for Asset Generation | Scenario](https://help.scenario.com/en/articles/model-costs-for-asset-generation/)

Es decir: los números que siguen son una **referencia orientativa**, no un precio garantizado — hay que confirmarlos dentro de la app (herramienta "Compute Planner") antes de comprometerse a un plan.

Dicho esto, un artículo del propio centro de ayuda de Scenario sí da un ejemplo concreto que sirve para hacerse una idea de escala:

- **Imagen estándar con un modelo tipo Flux:** ejemplo dado = **~5 créditos por imagen**.
- **Upscale (mejorar resolución):** ejemplo dado = **~15 créditos** (varía según el factor de escala y si es modo "fiel" o "creativo").
- **Quitar fondo (remove background):** clasificado como coste "bajo-medio", pero **no se dio una cifra exacta** → **⚠️ NO VERIFICADO** el número concreto.
- **Entrenar un modelo propio:** descrito como "el coste más alto, a menudo un orden de magnitud mayor que una sola generación". Cifras de referencia que aparecieron repetidas en dos fuentes: **entre 100 y 500 créditos** según la complejidad (tamaño del dataset, modelo base, épocas). Este rango hay que tratarlo como orientativo → **⚠️ NO VERIFICADO como cifra exacta**, pero es consistente entre fuentes.

### Cálculo aproximado (usando el ejemplo de ~5 créditos/imagen)

| | Starter (1.500 créditos/mes) | Pro (5.000 créditos/mes) |
|---|---|---|
| Imágenes estándar (~5 créditos c/u) | **~300 imágenes** | **~1.000 imágenes** |
| Upscales (~15 créditos c/u) | **~100 upscales** | **~333 upscales** |
| Entrenamientos de modelo (~100-500 créditos c/u) | No disponible en este plan | **entre ~10 y ~50 entrenamientos** (si se gastara todo el mes solo en eso, cosa poco realista) |

En la práctica, un mes normal de Pro reparte los 5.000 créditos entre generación de imágenes normales, algunos upscales y (si hace falta) uno o dos re-entrenamientos de modelo — no se gastarían todos en una sola categoría.

---

## 5. ¿Los créditos no usados se acumulan o caducan?

**Caducan. No se acumulan al mes siguiente.**

Cita textual del FAQ oficial: *"CUs renew monthly and don't roll over."*

Excepción: si compras créditos adicionales sueltos (add-on packs) cuando se te acaban antes de fin de mes, esos créditos comprados aparte sí tienen una validez más larga — **entre 90 días y un año** según el FAQ (esto último con menos detalle, tratarlo como orientativo).

**Fuente:** [FAQ | Scenario](https://help.scenario.com/articles/1129045411-frequently-asked-questions-faq)

---

## 6. ¿Se puede subir/bajar de plan a mitad de mes? ¿Hay permanencia?

- **Sí, se puede cambiar de plan (subir o bajar) en cualquier momento** desde Ajustes → Plans.
- El cambio **no es inmediato**: se aplica *"al inicio de tu próximo ciclo de facturación"* (cita textual del artículo oficial).
- **Cancelación:** se puede cancelar en cualquier momento, y conservas el acceso *"hasta que termine tu periodo de facturación"* ya pagado.
- **Permanencia / lock-in:** la documentación oficial revisada **no menciona ningún periodo mínimo de permanencia** para planes mensuales. Para el plan anual, obviamente el compromiso implícito es de un año (es lo que hace que salga un 33% más barato). No se encontró mención explícita de penalización por cancelar un plan anual a mitad de camino → **⚠️ NO VERIFICADO** si hay reembolso parcial o no al cancelar un anual antes de tiempo.

**Fuente:** [Upgrade, Downgrade or Cancel your Plan | Scenario](https://help.scenario.com/en/articles/how-to-upgrade-or-downgrade-a-subscription-on-scenario/)

---

## 7. ¿Tiene servidor MCP oficial? ¿En qué plan?

**Sí, Scenario tiene un servidor MCP oficial.** MCP ("Model Context Protocol") es el mismo protocolo que usa Claude Code para conectarse a herramientas externas — con el MCP de Scenario, un asistente de IA (Claude Code, Cursor, Claude Desktop, etc.) puede pedirle directamente a Scenario que genere un asset, sin que tengas que entrar a la web de Scenario a mano. Expone más de 60 herramientas y 550+ modelos.

**¿Qué plan hace falta?** La página oficial del MCP no lo dice de forma explícita, pero el propio artículo de "cómo empezar" dice que hace falta autenticarse con una **API key** (o OAuth) para usarlo, y que *"el uso cuesta lo mismo que en la web app"* (consume tus créditos normales). Como el punto 2 confirmó que **la API key solo está disponible desde el plan Pro ($45) en adelante**, la conclusión lógica es que **el MCP también requiere Pro o superior** — pero esto es una **inferencia nuestra combinando dos artículos**, no una frase única que lo diga explícitamente → **⚠️ NO VERIFICADO al 100%, pero muy probable**.

**Fuentes:** [Model Context Protocol | Scenario](https://www.scenario.com/features/mcp), [Getting Started with the Scenario MCP Server | Scenario](https://help.scenario.com/en/articles/getting-started-with-the-scenario-mcp-server/)

---

## 8. ¿Qué derechos comerciales da sobre las imágenes generadas?

**Buenas noticias: sí se pueden usar en un juego que se vende.** Citas textuales encontradas:

> *"Scenario does not claim ownership of anything you upload, and you own your content [...] you own your generated assets and can use them commercially, sell them, modify them."*

> *"All generations from Scenario's public foundation models, platform models, and tools are cleared for commercial use."*

Matices:
- Si entrenas un **modelo propio**, los pesos de ese modelo entrenado son tuyos, pero Scenario conserva la propiedad de la arquitectura base y la infraestructura de entrenamiento sobre la que se construyó (esto es normal y no afecta a que puedas vender lo que generas).
- La responsabilidad de que el material con el que entrenas un modelo propio (ej. referencias que subas) no infrinja derechos de autor de terceros es **tuya**, no de Scenario.
- No se encontraron menciones de modelos concretos "no aptos para uso comercial" dentro del plan estándar — la fuente que buscaba confirmar excepciones por modelo (`licenses-base-models`) devolvió error 404 al intentar acceder, así que no pudimos verificar si existe alguna letra pequeña por modelo específico → **⚠️ NO VERIFICADO en detalle por modelo individual**, aunque la declaración general de "cleared for commercial use" es clara y viene de fuente oficial.

**Fuente:** búsqueda oficial sobre [Terms and Conditions | Scenario](https://www.scenario.com/terms-and-conditions) y FAQ oficial.

---

## 9. Alternativas relevantes en 2026 para props/texturas/iconos de un tycoon isométrico

| Herramienta | Precio aprox. | ¿Mejor o peor que Scenario para este caso? |
|---|---|---|
| **Leonardo AI** | Tiene plan gratuito + planes de pago (rango similar, ~$10-48/mes según fuentes de terceros — **⚠️ NO VERIFICADO en su web oficial, no lo comprobamos directamente**) | Comparable a Scenario en flexibilidad para iconos/concept art 2D; menos enfocado específicamente en "reference-driven consistency" para sets de assets de un mismo juego. Buena alternativa si Scenario no convence. |
| **Recraft** | Planes de pago propios (⚠️ NO VERIFICADO, no comprobado en su web) | Especializado en ilustración vectorial e iconos planos — puede ser **mejor específicamente para iconos de UI** que Scenario, que está más pensado para arte de personajes/props "pintado". |
| **PixelLab / Rosebud PixelVibe** | Herramientas más nicho, orientadas a pixel art y tiles isométricos (⚠️ NO VERIFICADO precio) | Si el estilo final del juego fuera pixel art, esto encajaría mejor que Scenario. Para nuestro estilo (más "arte pintado" isométrico, no pixel art puro) es **menos relevante**, salvo que cambiemos de dirección de arte. |
| **Meshy / Tripo / Rodin (Hyper3D)** | Herramientas de generación 3D (⚠️ NO VERIFICADO precio exacto) | No compiten directamente con Scenario para sprites 2D — son para generar **modelos 3D** desde texto/imagen. Podrían ser un complemento (no sustituto) si en el futuro quisiéramos generar geometría 3D base para renderizar props isométricos, en vez de solo texturizar/pintar en 2D. |

Nota honesta: la mayoría de precios de estas alternativas vienen de artículos de terceros (blogs comparativos), no de las páginas oficiales de cada herramienta — no las verificamos una por una porque el encargo pedía centrarnos en Scenario. Si alguna de estas se vuelve candidata seria, habría que repetir este mismo ejercicio de verificación con su web oficial antes de decidir.

**Fuentes de la comparación:** [10 Best AI Game Asset Generators for 2026](https://www.tripo3d.ai/blog/best-ai-game-asset-generators), [AI Asset Generators Compared for Game Teams (2026)](https://www.seeles.ai/resources/blogs/ai-asset-generator-comparison-2026)

---

## 10. Aviso honesto: ¿sirve Scenario para el flujo "3D pre-renderizado a sprites"?

**Respuesta directa: NO ayuda con la parte de personajes en 3D renderizados a sprite. Scenario es una herramienta de generación de IMÁGENES (2D), no un motor de renderizado 3D.**

Para el flujo que tenemos decidido para los **personajes** (modelar/animar en 3D — ej. con un programa como Blender — y luego renderizar cada frame/ángulo a un sprite 2D), Scenario no interviene en absoluto: no modela en 3D, no anima, no renderiza cámaras. Ese trabajo lo sigue haciendo el pipeline 3D tradicional (herramienta de modelado + renderizador), tal como está planeado en el art bible.

Donde Scenario **sí puede ayudar** es exactamente en la otra mitad del plan que ya teníamos: los elementos **estáticos** — props sueltos, texturas de suelo, mobiliario, iconos de UI, quizás variaciones de un mismo prop para dar variedad visual sin modelarlas todas a mano. Ahí Scenario genera directamente la imagen 2D final (o casi final, si luego hace falta retocar), sin pasar por 3D.

Un matiz interesante encontrado durante la investigación: Scenario tiene contenido propio sobre "reskinning" de assets a estilo isométrico (un blog post titulado *"AI Game Asset Reskinning: Create Isometric Variants Fast on Scenario"*), lo que sugiere que sí está pensado para generar variantes isométricas de props — relevante para nuestro caso. No profundizamos en el contenido de ese artículo porque no formaba parte de las 10 preguntas del encargo, pero puede valer la pena revisarlo aparte si seguimos adelante con Scenario.

**Conclusión de esta sección:** mantener el plan tal como está — 3D pre-renderizado para personajes (fuera del alcance de Scenario), IA generativa (Scenario u otra) solo para props/texturas/iconos estáticos.

**Fuente:** [AI Game Asset Reskinning | Scenario](https://www.scenario.com/blog/reskin-game-assets-ai-isometric-art)

---

## Resumen para decidir

| | Starter $15/mes | Pro $45/mes |
|---|---|---|
| Créditos/mes | 1.500 | 5.000 |
| API | No | Sí |
| Entrenar modelo propio | No | Sí |
| MCP (probable, no 100% confirmado) | No | Sí |
| Imágenes aprox. (~5 créditos c/u, cifra de ejemplo no garantizada) | ~300 | ~1.000 |

Si el uso va a ser **solo manual desde la web** (entrar, generar, descargar, sin automatizar ni entrenar estilo propio), Starter alcanza. Pero en cuanto queramos **consistencia de estilo propia** (entrenar un modelo con nuestras referencias de arte) o **automatizar** generación (scripts, o el servidor MCP para pedírselo a Claude Code directamente), hace falta **Pro como mínimo**.
