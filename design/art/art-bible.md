# Art Bible — Comisario *(título provisional)*

*Created: 2026-07-19*
*Status: Draft — núcleo visual (secciones 1–4) completado; secciones 5–9 pendientes*

> **Art Director Sign-Off (AD-ART-BIBLE)**: N/A — modo *lean* (validación de director omitida).
> **Nota de autoría**: el núcleo visual lo redactó el hilo principal (Opus 4.8) actuando como
> art-director, porque la delegación a subagentes está bloqueada por los créditos de contexto 1M.

---

## 1. Declaración de Identidad Visual

> **Frase-regla:** *"Una institución pública española creíble, vista desde arriba con claridad de
> plano: todo lo que ves podría existir en una comisaría real del CNP, y su estado se lee al instante."*

**Principios de apoyo:**

1. **Claridad funcional antes que detalle** *(pilares 2 «la comisaría está viva» y 4 «tus decisiones»)*
   — de un vistazo se entiende cada sala, puesto y persona.
   *Test: si un adorno estorba leer un estado (cola, tipo, ocupación), se simplifica.*

2. **Autenticidad contenida, no espectáculo** *(pilar 1 «realismo con alma»)* — materiales, mobiliario
   y señalética reales del CNP, paleta sobria; nada cómico ni exagerado.
   *Test: ante «llamativo» vs. «creíble en una comisaría real», gana lo creíble.*

3. **La gente cuenta la historia** *(pilar 2 «la comisaría está viva»)* — los personajes, aunque
   simples, transmiten rol y estado por silueta, color y postura.
   *Test: si hay que invertir detalle, gana hacer legibles a las personas sobre el mobiliario.*

---

## 2. Ambiente y Atmósfera (Mood) por estado de juego

| Estado | Emoción objetivo | Iluminación | Adjetivos | Elemento que porta el mood |
|---|---|---|---|---|
| **Jornada de mañana** (Documentación abierta) | Ajetreo productivo | Cálida-neutra, diurna, contraste medio, sombras suaves | Ajetreado, funcional, luminoso, ordenado, cotidiano | Luz de ventanas + fluorescentes; movimiento constante de gente |
| **Noche** (Documentación cerrada, más criminalidad) | Vigilia tensa | Fría, azulada, nivel bajo con focos puntuales, alto contraste | Tenso, silencioso, frío, vigilante, sombrío | Azul giratorio de vehículo reflejado; pasillos en penumbra |
| **Dilema / presión** (llega un favor/influencia) | El peso de decidir | Viñeta: fondo desaturado + acento ámbar en el panel de decisión | Solemne, incómodo, íntimo, cargado | Foco sobre el cargo influyente; el resto en sombra |
| **Ascenso / logro** | Orgullo institucional | Cálida, dorada, limpia; instante de calma | Solemne, cálido, digno, satisfactorio | Galón/placa nuevo iluminado (azul CNP + dorado del escudo) |
| **Fracaso / mala gestión** | Agobio y desorden | Plana, fluorescente frío parpadeante, rojos de alerta | Caótico, saturado, agobiante, tenso | Colas rojas desbordadas, indicadores en alerta, gente marchándose |
| **Menús / gestión** | Calma de sala de control | Neutra, oscura-institucional, acentos azul CNP | Limpio, ordenado, serio, legible | Paneles tipo expediente/dosier; tipografía clara |

Cada estado debe sentirse visualmente distinto: la mañana es luminosa y viva, la noche fría y quieta,
el dilema aislado y solemne, el fracaso saturado de rojos.

---

## 3. Lenguaje de Formas

- **Siluetas de personajes** (legibles a tamaño pequeño en vista cenital): se distinguen por
  **color de rol + un accesorio de silueta**, no por la cara (que no se ve):
  - Agente uniformado → gorra / hombros marcados (silueta de autoridad).
  - Detenido → postura encorvada / esposas.
  - Abogado → maletín.
  - Denunciante → carpeta o papel en mano.
  - Ciudadano de a pie → silueta neutra.
  *Test: si dos arquetipos se confunden de un vistazo, se refuerza la silueta o el color, no el detalle facial.*

- **Geometría de entornos**: **ortogonal/rectilínea** dominante (rejilla), coherente con la
  arquitectura pública funcional española (pasillos rectos, mobiliario modular, mostradores). Las
  curvas son escasas y se reservan a lo «humano» (plantas, sillas de espera, personas). Comunica
  orden, burocracia e institución *(pilares 1 y 4)*.

- **Gramática de UI**: HUD **distinto** del mundo pero emparentado — estética de **expediente / dosier
  oficial** (fichas, pestañas, sellos), no diegético dentro del edificio. Rectangular, tipografía de
  oficina. La UI es tu «mesa de mando» *(pilar 4)*.

- **Formas héroe vs. de apoyo**: atraen la vista **las personas y lo accionable** (puestos, colas,
  alertas, el panel de decisión); se retiran mobiliario, suelo y paredes (grises azulados, bajo
  contraste) *(pilar 2)*.

---

## 4. Sistema de Color

### Paleta primaria (color · rol · significado)

| Color | Hex aprox. | Rol / significado |
|---|---|---|
| 🔵 Azul marino CNP | `#0B2A5B` | Ancla institucional: uniformes, marca, señalética. «Autoridad, oficialidad». |
| ⬜ Gris azulado | `#3A4656` / `#8A97A8` | Mobiliario, suelos, paredes: el fondo que «se retira». |
| 📄 Blanco papel | `#EDEFF2` | Documentos, mostradores, superficies limpias: claridad. |
| 🟡 Ámbar / dorado | `#E0A73B` | Dinero/ingresos y reconocimiento (ascensos, escudo). «Valor, logro». |
| 🟢 Verde | `#3FA65A` | Estados positivos/OK (atendido, paciencia alta, servicio cumplido). |
| 🔴 Rojo | `#D64545` | Urgencia/alerta (paciencia agotada, cola desbordada, VioGén prioritaria). |
| 🟣 Burdeos/púrpura sobrio | `#8C3D52` | Presión/influencia (dilemas): un color «fuera de lo cotidiano». |

### Color semántico
- **Dinero/ingreso** = ámbar; **obligación/coste** = gris o rojo tenue.
- **Paciencia del ciudadano** = degradado verde → ámbar → rojo (respaldo: opacidad + parpadeo al bajar).
- **Estado de puesto** = verde (atendiendo) / azul (libre) / ámbar (sin agente) / gris (cerrado).
- **Trámites y tipos de denuncia** = color propio, pero SIEMPRE con **icono + etiqueta** de respaldo.
- **Unidades/brigadas** = matices dentro de la familia azul-institucional (nada de arcoíris saturado,
  que rompería el tono serio); se diferencian por tono, no por colores primarios chillones.

### Paleta de UI
Base oscura-institucional (azul marino muy oscuro / gris carbón) con texto claro, acentos **azul CNP**
y **ámbar** para acciones y valor; **rojo** reservado a alertas. Diverge del mundo (más claro/diurno)
para que el HUD «mande» y no se confunda con la escena.

### Seguridad para daltónicos
Los pares problemáticos son **verde/rojo** (paciencia, OK/alerta) y **verde/ámbar**. Regla: **nunca**
comunicar un estado crítico solo por color — respaldo obligatorio de **forma/icono/texto** (✓ ⏳ ⚠) y/o
posición. Los tipos de trámite y denuncia usan icono + etiqueta además del color.

---

## Secciones pendientes (para una próxima sesión)

5. Dirección de personajes · 6. Lenguaje de entornos · 7. Dirección visual de UI/HUD ·
8. Estándares de assets (formatos, resoluciones, límites Godot) · 9. Referencias.

**Referencias base ya acordadas**: *Prison Architect* (vista cenital, legibilidad institucional,
construcción modular — evitar su aspereza de prisión); *This Is the Police* (paleta sobria, gestión
policial adulta — evitar el noir); fotos reales de comisarías del CNP (autenticidad y azul corporativo);
*Two Point Hospital* como **anti-referencia** de tono (evitar su caricatura).
