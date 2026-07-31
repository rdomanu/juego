# Bienestar #13 — guía de sign-off

> **Para qué es esto**: Bienestar #13 está implementado y probado por tests de integración, pero
> **nunca lo ha validado un ojo humano**. Esta es la lista de lo que hay que ver funcionando en la
> ventana para poder darlo por cerrado. No es un test automático: es lo que los tests **no pueden**
> comprobar — que se entienda y que se vea.
>
> **Fecha**: 2026-07-31 · **Estado**: pendiente de sign-off del usuario

---

## Antes de empezar

- Abre el juego y pon velocidad **3×** (tecla `3`): el cansancio sube despacio a propósito.
- Ten a mano la ficha de ventanilla: **clic izquierdo** sobre una ventanilla.
- El panel de personal es la tecla **P**.

---

## 1. El cansancio se VE, y se entiende

| Qué mirar | Qué debería pasar |
|---|---|
| Sobre cada funcionario, en el mundo | Una **barra** que se va llenando conforme atiende |
| En la ficha de la ventanilla | `Cansancio 47 %  (+12 % más lento)` — el número **con su consecuencia** |
| En el panel `P` | El mismo dato, para toda la plantilla de un vistazo |

**La pregunta de diseño**: ¿entiendes, sin que nadie te lo explique, que un funcionario cansado
atiende más lento? Si no se entiende, el sistema no cumple aunque los números sean correctos.

## 2. Se van al café ANDANDO

- [ ] Al llegar a cierto cansancio, el funcionario **deja el mostrador y camina** hasta la sala de
      descanso. No desaparece ni aparece de la nada.
- [ ] Mientras va, su ventanilla dice **"descansando"** con los minutos que le quedan.
- [ ] En la sala se le ve con su **taza (☕)**.
- [ ] Al terminar, **vuelve andando** a su ventanilla.

**Lo que se corrigió y hay que confirmar**: el café cuenta **al LLEGAR**, no durante el trayecto. Si
la sala está lejos, tarda más en empezar a recuperarse — y eso es a propósito, porque hace que
**dónde pones la sala de descanso importe**.

## 3. El patrón depende de la MOTIVACIÓN

Mira en la ficha de varias ventanillas la motivación de cada agente y compara cómo descansan:

| Motivación | Patrón esperado |
|---|---|
| Alta | **2 cafés cortos** — vuelve pronto al puesto |
| Media | **1 café largo** |
| Baja | **1 café de caradura** — se va lo antes posible y se toma su tiempo |

**La pregunta de diseño**: ¿se nota la diferencia entre un agente motivado y uno quemado, sin mirar
los números?

## 4. Los muebles de la sala acortan la pausa

- [ ] Entra en modo construcción (`B`) y compra un mueble de descanso (sofá, máquina de café).
- [ ] Al pasar el ratón, la etiqueta dice **"X min menos de descanso"** *(corregido el 2026-07-31:
      antes decía "menos de café", que sonaba a castigo cuando es una mejora)*.
- [ ] Con el mueble puesto, las pausas duran menos y los funcionarios vuelven antes.

## 5. El cupo de pausas es por TURNO de 8 h

- [ ] Un funcionario gasta sus pausas y ya no se va más **en ese turno**.
- [ ] Al cambiar de turno, vuelve a tener cupo.

**Por qué importa**: antes era por jornada completa, y como ODAC no cierra nunca, sus agentes
gastaban su única pausa y se quedaban al máximo de cansancio —un 25 % más lentos— durante horas sin
salida posible.

## 6. Quien cierra su ventanilla se va a casa

- [ ] Si a un funcionario le pilla el cierre de su ventanilla tomándose el café, **no vuelve**: se
      marcha a casa. El turno de Documentación no sigue hasta el día siguiente.

## 7. 🆕 Descanso in situ (cerrado el 2026-07-31)

Este era el **último hueco conocido** de Bienestar. Para probarlo hay que provocarlo:

- [ ] Entra en modo construcción y **encierra la sala de descanso con muros, sin dejar puerta**.
- [ ] Espera a que un funcionario quiera irse al café.
- [ ] **Debe quedarse en su ventanilla con la taza**, no salir a buscar una sala a la que no puede
      llegar.

**Qué pasaba antes**: salía, no llegaba, el viaje se cerraba a la fuerza y el agente se quedaba
"descansando" para el modelo pero **sin aparecer por ningún lado**. Su ventanilla se quedaba vacía
sin explicación. Ahora no pierde la pausa —sería castigarle por una obra que él no ha decidido— y
además se le ve.

---

## Veredicto

- [ ] **APROBADO** — Bienestar #13 cerrado.
- [ ] **CON PEGAS** — anotar abajo qué falla y volver a la cola.

**Notas del usuario:**

```
(a rellenar)
```
