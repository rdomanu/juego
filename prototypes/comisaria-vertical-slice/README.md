# Comisario — Vertical Slice (prototipo de usar y tirar)

> ⚠️ **VERTICAL SLICE — NOT FOR PRODUCTION.** Este proyecto Godot es un prototipo
> desechable. El código de Producción se escribirá desde cero en `src/` (nunca importa
> de aquí). Estándares relajados por velocidad; sigue las *capas* del `control-manifest`
> donde importa (determinismo, navegación real) pero no busca pulido.

## Pregunta de validación

> ¿Un jugador desde cero siente que *gestionar el flujo de ciudadanos por una Oficina de
> Denuncias, siendo subinspector,* es entretenido y satisfactorio ~3–5 min, sin guía — y
> podemos construir ese bucle a un ritmo razonable? (**diversión** + **viabilidad**).

## Cómo abrirlo (Godot 4.6)

1. Abre Godot 4.6 → Gestor de Proyectos → **Import**.
2. Selecciona el `project.godot` de **esta carpeta** → **Import & Edit**.
3. Pulsa **▶ (F5)** para jugar.

## Estructura

```
project.godot          # ficha del proyecto (renderer Compatibility, autoloads)
autoload/
  event_bus.gd         # "tablón de anuncios": señales cross-system (ADR-0001)
  rng_service.gd       # dado con semilla → determinismo (ADR-0002)
  tiempo.gd            # el reloj: paso fijo, Pausa/1×/2×/3×, turnos, día/noche
main/
  main.tscn / main.gd  # escena de arranque + HUD mínimo (Escalón 0)
```

## Escalones

- [x] **Escalón 0** — El proyecto respira: reloj corriendo + velocidades.
- [ ] Escalón 1 — Un ciudadano, un puesto (navegación real → atención → cobro).
- [ ] Escalón 2 — Cola + demanda (DNI + denuncia, métrica de espera).
- [ ] Escalón 3 — Construir + agentes + presupuesto.
- [ ] Escalón 4 — Día/noche + objetivo → ascenso.
- [ ] Escalón 5 — Spike de rendimiento QQ-02 (docenas de NPCs, ≥60 FPS).
