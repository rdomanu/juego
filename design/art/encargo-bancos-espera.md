# Encargo — Bancos de sala de espera por tiers (2026-08-08)

Pedido del usuario: sustituir/complementar las sillas de espera con BANCOS de 2-3 celdas,
**un asiento de NPC por celda**. Tres calidades, mismo reparto de efectos que las sillas
(paciencia del ciudadano mientras espera). "Las sillas no me gusta[n]".

Autorización de gasto: dada 2026-08-08 ("si no hay esos assets dile a Summer que lo cree")
— generación 3D ≈0,54$/pieza si la biblioteca gratis no da nada. ANTES de generar: buscar en
biblioteca Summer ("bench", "waiting bench", "airport bench", "wooden bench") y enseñar
candidatos al usuario.

## Los 3 tiers (prompts de generación preparados)

1. **banco_espera_basico** (~2 celdas, 2 plazas) — "worn old wooden waiting bench, 2 seats,
   scratched dark wood slats, slightly sagging, old municipal office style, low-poly stylized
   game asset, matches worn basic desk furniture" — desgastado y antiguo, a juego con la mesa
   básica.
2. **banco_espera_medio** (~3 celdas, 3 plazas) — "airport waiting bench, 3 connected seats,
   brushed metal frame with black cushioned seats, shared armrests, clean modern public
   seating, low-poly stylized game asset" — el clásico de aeropuerto.
3. **banco_espera_pro** (~3 celdas, 3 plazas) — "premium waiting bench, 3 wide padded seats,
   navy blue upholstery with chrome frame, elegant lounge public seating, comfortable
   armrests, low-poly stylized game asset" — premium, tapizado azul marino (paleta CNP).

## Reglas de integración (cuando llegue el arte)

- Ley de módulos: si el modelo no da bien las 2-3 celdas SIN deformar, se compone por módulos
  o se regenera — nunca estirar (escala-muebles-por-modulos).
- Pipeline: render_mobiliario por ANCHO de huella, 4 vistas reales, vista de acción con
  muñeco SENTADO en cada plaza (ley 11, lado-de-accion.md).
- MECÁNICA NUEVA a implementar (lote aparte): asiento multi-plaza — huella 2-3 celdas con un
  asiento por celda (hoy cada asiento es 1 objeto/1 celda). Diseñar en quick-spec antes de
  integrar: ocupación por plaza, orden de llenado, efecto paciencia por tier.
- Precios provisionales sugeridos: básico 40€ / medio 90€ / pro 180€ (por plaza saldría
  20/30/60 — ajustar con el balance de sillas 25/60/120).

## Estado

- [x] Biblioteca Summer buscada (2026-08-08, MCP reconectado): sin bancos de aeropuerto ni
      premium; candidatos GRATIS para el tier básico descargados a capturas/fuentes/bancos_espera/:
      banco_desgastado_graveyard.glb (Kenney Graveyard, el "desgastado"), banco_urbano_retro.glb
      (Kenney Retro Urban), banco_madera_summer.glb (generado comunidad).
- [ ] Candidatos enseñados al usuario (hoja de render pendiente)
- [x] Generación DISPARADA 2026-08-08 (~0,54$/u, autorizada): banco medio aeropuerto
      job 97661730-2103-4f59-87fb-4134be5b32bb (comisario-banco-espera-medio-v1) · banco pro
      job 2976cbcb-9f85-4d2c-b019-5e9b88ab008a (comisario-banco-espera-pro-v1). Barrera:
      job aa182f49-cb7c-4557-af3c-1b5714435e9e (comisario-barrera-seguridad-v1, ver
      encargo-barrera-seguridad.md). Al completarse: descargar GLB, auditar thumbnail ANTES de
      enseñar, render 4 vistas.
- [ ] Render 4 vistas + hoja con muñecos sentados
- [ ] Veredicto del usuario
- [ ] Quick-spec asiento multi-plaza + implementación
