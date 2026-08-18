# Maqueta del PANEL DE ODAC (F4, tecla O) — la "UI definitiva" que sustituye al andamio provisional
# de `src/main/panel_odac.gd` (el propio archivo se declara "andamio... la UI definitiva es UI/HUD
# #11" en su cabecera). Mismo lenguaje v3 que las hermanas ya aprobadas (`maqueta_horario.py`/
# `maqueta_personal.py`/`kit_ui_comisario.gd`): modal con velo+blur, chrome nítido, tarjetas blancas,
# esquinas muy redondeadas, un único acento azul.
#
# Contenido: SOLO lo que soporta la API real:
#   - src/main/panel_odac.gd (leído entero) — la pantalla actual: 3 modos de un clic por ventanilla
#     (Polivalente/Solo prioritarias/Solo normales) + el aviso de "denuncias sin cubrir" (la válvula
#     anti-inanición, razón de ser de la pantalla — ver la cabecera larga de `odac.gd`). El 4º modo
#     ("a medida") NO se ofrece aquí a medias — el propio código lo dice: "es la UI fina que llegará
#     con UI/HUD #11 -- se indica pero no se ofrece aquí a medias". Esta maqueta SÍ es esa UI fina, y
#     aun así respeta la regla: la pastilla de 3 modos rápidos sigue siendo de 1 clic; "A medida" se
#     INDICA (qué tipos coge, de sobra útil para comparar) pero afinarlo tipo a tipo se queda en la
#     ficha individual (`panel_ventanilla.gd::_bloque_odac`, ya tiene sus 13 casillas) — duplicar esas
#     13 casillas aquí, multiplicadas por N ventanillas, sería ruido, no ayuda.
#   - src/feature/odac/odac.gd — Modo enum, NOMBRES_MODO, AYUDA_MODO, modo_de/fijar_modo,
#     denuncias_sin_cubrir(), atenciones_de_modo/subconjunto_de, es_prioritaria(), puestos().
#   - src/core/flujo/flujo.gd — personas_en_cola/personas_de_cola(&"ODAC") (para el reparto
#     prioritarias/normales de la cola — dato REAL, ver más abajo), estado_de_puesto (LIBRE/
#     ATENDIENDO/EN_CAMINO/ABIERTO_SIN_AGENTE/CERRADO), persona_en_puesto/restante_de_puesto.
#   - src/main/panel_personal.gd::PREFIJO_POR_TIPO_PUESTO — "ODAC 1"/"ODAC 2" (nunca el id técnico).
#   - datos/denuncias/*.tres — el catálogo REAL de 14 denuncias (4 Prioritarias: viogen,
#     desaparecidos, agresion_sexual, robo_violencia · 10 Normales: el resto) con sus `nombre`
#     exactos. (El comentario de `odac.gd` dice "13" pero el catálogo en disco tiene 14 -- se usa el
#     catálogo real, no el comentario desactualizado.)
#
# ══ QUÉ APORTA LA VISTA DE CONJUNTO QUE LA FICHA INDIVIDUAL NO DA ═══════════════════════════════
# La ficha de una ventanilla (`panel_ventanilla.gd`) solo sabe de SÍ MISMA: su modo, sus denuncias
# marcadas, la cola TOTAL del servicio (sin desglosar). Ninguna ficha puede decirte "entre TODAS tus
# ventanillas de ODAC, os estáis dejando 8 tipos de denuncia sin nadie que los coja" — eso es una
# propiedad del CONJUNTO, no de una ventanilla. Por eso esta pantalla añade tres cosas que la ficha no
# puede dar sola:
#   1. REPARTO DE LA COLA POR PRIORIDAD (dato real: `Flujo.personas_de_cola(&"ODAC")` trae los objetos
#      Persona; cada uno sabe su `tramite_id()`, y `ODAC.es_prioritaria(id)` dice si es urgente —
#      agregando eso se cuenta cuántos de los que esperan son urgentes y cuántos no, cosa que la ficha
#      de una sola ventanilla jamás podría saber por sí sola).
#   2. RESUMEN DE DEDICACIÓN (cuántas ventanillas están en cada modo) — la comparación explícita que
#      pide el encargo: de un vistazo, "¿cuántas cubren solo lo urgente?".
#   3. EL AVISO DE COBERTURA (`denuncias_sin_cubrir`) — que YA es, por construcción, una pregunta sobre
#      el conjunto (una denuncia está "sin cubrir" si NINGUNA ventanilla la coge). Aquí se dibuja como
#      chips en vez del párrafo de una sola línea que usa hoy el andamio (`_aviso.text`, un
#      `", ".join(...)` que con 8 tipos sería una frase larguísima) — más legible sin perder ni un dato.
#
# ══ ESTADO RETRATADO (con chicha, datos reales) ══════════════════════════════════════════════════
# 2 ventanillas ODAC (todo lo que hace falta para que el aviso de cobertura tenga sentido real, sin
# inventar una tercera para maquillarlo):
#   - ODAC 1: "Solo prioritarias" (cubre las 4 urgentes) — Marta Soler, ATENDIENDO ahora mismo una
#     "Violencia de género (VioGén)".
#   - ODAC 2: "A medida", 2 denuncias marcadas: "Hurtos / robos" y "Daños" — Javier Nieto, LIBRE.
# Entre las dos cubren 4 Prioritarias + 2 Normales = 6 de 14. Las 8 Normales restantes (Amenazas,
# Ciberestafa, Estafas, Lesiones, Okupación, Pérdidas/sustracciones, Permisos de viaje, Hoja de
# reclamaciones) se quedan SIN NINGUNA ventanilla que las atienda — el aviso en rojo, con datos reales,
# no inventados.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

import os
# Promovida a design/ux/maquetas-menu-2026-08/ el 2026-08-18; el fondo viaja junto al script.
FONDO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fondo_actual.png")
SCRATCH = os.path.dirname(os.path.abspath(__file__))
SCRATCH = os.path.dirname(os.path.abspath(__file__))
F_DIR = r"C:\Windows\Fonts"

# ── Paleta (idéntica a las maquetas hermanas / MOD_COLOR_* de kit_ui_comisario.gd) ────────────────
PANEL = (238, 243, 249)
TARJETA = (255, 255, 255)
TINTA = (36, 48, 66)
GRIS = (122, 136, 156)
LINEA = (222, 229, 238)
ACENTO = (47, 108, 224)
ACENTO_SUAVE = (232, 240, 254)
VERDE = (34, 160, 94)
VERDE_SUAVE = (226, 244, 234)
AMBAR = (240, 158, 44)
AMBAR_SUAVE = (252, 238, 219)
AMBAR_TEXTO = (181, 112, 15)
ROJO = (226, 88, 82)
ROJO_SUAVE = (250, 227, 225)
GRIS_SUAVE = (231, 233, 237)


def F(nombre, tam):
    return ImageFont.truetype(os.path.join(F_DIR, nombre), tam)


NORM, SEMI, BOLD = "segoeui.ttf", "seguisb.ttf", "segoeuib.ttf"


def cargar_base():
    return Image.open(FONDO).convert("RGBA")


def sombra_rect(img, caja, radio, alfa=26, blur=8, offset=(0, 3)):
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    x0, y0, x1, y1 = caja
    d.rounded_rectangle([x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
                         radio, fill=(10, 14, 24, alfa))
    img.alpha_composite(capa.filter(ImageFilter.GaussianBlur(blur)))


def texto_centrado_v(d, xy, texto, fuente, fill, alto_linea):
    x, y = xy
    bbox = d.textbbox((0, 0), texto, font=fuente)
    h = bbox[3] - bbox[1]
    d.text((x, y - h / 2 - bbox[1]), texto, font=fuente, fill=fill)


def ancho_texto(d, texto, fuente):
    bbox = d.textbbox((0, 0), texto, font=fuente)
    return bbox[2] - bbox[0]


def envolver_texto(d, texto, fuente, ancho_max):
    palabras = texto.split(" ")
    lineas, actual = [], ""
    for palabra in palabras:
        prueba = (actual + " " + palabra).strip()
        if ancho_texto(d, prueba, fuente) <= ancho_max or actual == "":
            actual = prueba
        else:
            lineas.append(actual)
            actual = palabra
    if actual:
        lineas.append(actual)
    return lineas


def boton_pill(d, x, y, ancho, alto, texto, estilo="primario", tam=11):
    if estilo == "primario":
        fondo, color_txt = ACENTO, (255, 255, 255)
    elif estilo == "peligro":
        fondo, color_txt = TARJETA, ROJO
    else:
        fondo, color_txt = TARJETA, TINTA
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=fondo)
    if estilo in ("secundario", "peligro"):
        d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, outline=LINEA, width=1)
    fuente = F(SEMI, tam)
    tw = ancho_texto(d, texto, fuente)
    bbox = d.textbbox((0, 0), texto, font=fuente)
    texto_centrado_v(d, (x + (ancho - tw) / 2 - bbox[0], y + alto / 2), texto, fuente, color_txt, alto)


def punto_texto(d, x, y, texto, color_punto, color_texto=TINTA, tam=13, radio=6):
    cy = y
    d.ellipse([x, cy - radio, x + radio * 2, cy + radio], fill=color_punto)
    d.text((x + radio * 2 + 8, y - tam * 0.7), texto, font=F(SEMI, tam), fill=color_texto)


## Casilla marcada dibujada -- a menos de ~14px de lado el radio de esquina (antes 40% del lado) y el
## trazo de 2px se comían la forma y salía un "engranaje" en vez de un check (visto en zoom, pasada
## 2). Lado mínimo 14 + radio proporcional más bajo (22%) arregla la lectura.
def casilla_check(d, x, y, lado, color=ACENTO):
    radio = max(2, lado * 0.22)
    d.rounded_rectangle([x, y, x + lado, y + lado], radio, fill=color)
    d.line([x + lado * 0.24, y + lado * 0.54, x + lado * 0.42, y + lado * 0.72],
           fill=(255, 255, 255), width=2)
    d.line([x + lado * 0.42, y + lado * 0.72, x + lado * 0.78, y + lado * 0.28],
           fill=(255, 255, 255), width=2)


# ── Chip suelto (fondo + texto), devuelve su ancho -- pieza base del flujo de chips de abajo. Los
# chips con casilla marcada tienen su propia variante (`flujo_chips_check`), más abajo. ─────────────
def chip(d, x, y, texto, color_fondo, color_texto, tam=11, alto=24):
    fuente = F(SEMI, tam)
    tw = ancho_texto(d, texto, fuente)
    pad_izq = 14
    ancho = pad_izq + tw + 12
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=color_fondo)
    texto_centrado_v(d, (x + pad_izq, y + alto / 2), texto, fuente, color_texto, alto)
    return ancho


## Coloca una lista de textos como chips en flujo (salto de línea automático) dentro de `ancho_max`.
## Devuelve la y tras la última fila.
def flujo_chips(d, x0, y0, ancho_max, textos, color_fondo, color_texto, tam=11, alto=24, gap=8):
    x, y = x0, y0
    fila_alto = alto
    for texto in textos:
        fuente = F(SEMI, tam)
        tw = ancho_texto(d, texto, fuente)
        ancho_chip = 14 + tw + 12
        if x != x0 and x + ancho_chip > x0 + ancho_max:
            x = x0
            y += fila_alto + gap
        chip(d, x, y, texto, color_fondo, color_texto, tam, alto)
        x += ancho_chip + gap
    return y + fila_alto


## Variante con casilla marcada DIBUJADA delante de cada chip (nunca el carácter unicode "✓": la
## fuente del sistema no lo trae limpio a este tamaño y sale como tofu -- mismo gotcha ya documentado
## en `kit_ui_comisario.gd::GlifoModerno` para la flecha "▾").
def flujo_chips_check(d, x0, y0, ancho_max, textos, color_fondo, color_texto, tam=11, alto=24, gap=8):
    x, y = x0, y0
    fila_alto = alto
    for texto in textos:
        fuente = F(SEMI, tam)
        tw = ancho_texto(d, texto, fuente)
        lado_icono = min(15, alto - 6)
        texto_x = 6 + lado_icono + 5
        ancho_chip = texto_x + tw + 12
        if x != x0 and x + ancho_chip > x0 + ancho_max:
            x = x0
            y += fila_alto + gap
        d.rounded_rectangle([x, y, x + ancho_chip, y + alto], alto // 2, fill=color_fondo)
        casilla_check(d, x + 6, y + (alto - lado_icono) / 2, lado_icono, color_texto)
        texto_centrado_v(d, (x + texto_x, y + alto / 2), texto, fuente, color_texto, alto)
        x += ancho_chip + gap
    return y + fila_alto


# ── Segmentado de 3 modos rápidos (1 clic) -- gemelo visual de KitUIComisario.toggle_segmentado,
# pero puede no tener NINGUNO activo (el puesto está en "A medida", SUBCONJUNTO -- honestidad: no se
# inventa que uno de los 3 esté "puesto" cuando no lo está). ──────────────────────────────────────
def segmentado_modos(d, x, y, ancho, alto, modo_activo, nombres_modo):
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=TARJETA, outline=LINEA, width=1)
    n = len(nombres_modo)
    seg_w = ancho / n
    for i, (id_modo, texto) in enumerate(nombres_modo):
        sx0 = x + i * seg_w
        activo = id_modo == modo_activo
        if activo:
            d.rounded_rectangle(
                [sx0 + 3, y + 3, sx0 + seg_w - 3, y + alto - 3], (alto - 6) // 2, fill=ACENTO_SUAVE
            )
        color_txt = ACENTO if activo else TINTA
        fuente = F(SEMI, 12)
        tw = ancho_texto(d, texto, fuente)
        texto_centrado_v(d, (sx0 + (seg_w - tw) / 2, y + alto / 2), texto, fuente, color_txt, alto)


# ── Una tarjeta de ventanilla ODAC (la unidad de comparación de la vista de conjunto) ─────────────
def tarjeta_odac(img, d, x, y, ancho, nombre, operador, sin_agente, estado, color_estado,
                  ahora_mismo, modo_id, nombre_modo_actual, ayuda_modo, color_ayuda, es_a_medida,
                  denuncias_a_medida):
    pad = 22
    seg_alto = 40
    # Alto dinámico: cabecera + operador + (ahora mismo, si hay) + segmentado + ayuda + (chips a
    # medida, si toca).
    fuente_ayuda = F(NORM, 12)
    lineas_ayuda = envolver_texto(d, ayuda_modo, fuente_ayuda, ancho - pad * 2)
    alto = pad + 26 + 20 + (18 if ahora_mismo else 0) + 14 + seg_alto + 10 + len(lineas_ayuda) * 16 + pad
    if es_a_medida:
        # 52 y no 30: el rotulo (18) + la fila de chips (22+6) + aire; con 30 la linea de ayuda
        # rozaba el borde inferior de la tarjeta (auditoria de Fable, 2026-08-18).
        alto += 52
    caja = (x, y, x + ancho, y + alto)
    sombra_rect(img, caja, 16, alfa=26, blur=9)
    d.rounded_rectangle(caja, 16, fill=TARJETA)

    yy = y + pad
    d.text((x + pad, yy), nombre, font=F(BOLD, 18), fill=TINTA)
    tw_nombre = ancho_texto(d, nombre, F(BOLD, 18))
    punto_texto(d, x + pad + tw_nombre + 20, yy + 12, estado, color_estado, color_texto=GRIS, tam=11, radio=5)
    yy += 30
    d.text((x + pad, yy), (
        "Sin agente asignado" if sin_agente else "Operada por %s" % operador
    ), font=F(NORM, 12), fill=ROJO if sin_agente else GRIS)
    yy += 22
    if ahora_mismo:
        d.text((x + pad, yy), ahora_mismo, font=F(SEMI, 12), fill=VERDE)
        yy += 20
    yy += 6

    d.text((x + pad, yy), "DEDICACIÓN", font=F(BOLD, 10), fill=GRIS)
    yy += 16
    nombres_modo = [("polivalente", "Polivalente"), ("prioritarias", "Solo prioritarias"),
                     ("normales", "Solo normales")]
    segmentado_modos(d, x + pad, yy, ancho - pad * 2, seg_alto, modo_id, nombres_modo)
    yy += seg_alto + 8
    if es_a_medida:
        d.text((x + pad, yy), "A MEDIDA · elegidas %d de 14" % len(denuncias_a_medida), font=F(SEMI, 12), fill=ACENTO)
        yy += 18
        yy = flujo_chips_check(
            d, x + pad, yy, ancho - pad * 2, denuncias_a_medida, ACENTO_SUAVE, ACENTO, tam=10, alto=22
        ) + 6
    for linea in lineas_ayuda:
        d.text((x + pad, yy), linea, font=fuente_ayuda, fill=color_ayuda)
        yy += 16
    return y + alto


# ══ Render principal ══════════════════════════════════════════════════════════════════════════
def triangulo_alerta(d, cx, cy, r, color):
    d.polygon([(cx, cy - r), (cx - r * 0.95, cy + r * 0.8), (cx + r * 0.95, cy + r * 0.8)],
              outline=color, width=2)
    d.line([cx, cy - r * 0.32, cx, cy + r * 0.22], fill=color, width=2)
    d.ellipse([cx - 1.6, cy + r * 0.42, cx + 1.6, cy + r * 0.42 + 3.2], fill=color)


## Dibuja TODO el contenido del modal (marco + cabecera + secciones) con el techo del modal en
## `MY0` -- factorizado aparte para poder medir cuánto ocupa en una pasada "en seco" y luego centrar
## el modal en vertical con esa medida real, en vez de dejar la mitad de abajo vacía (pantalla con
## poco contenido -- 2 ventanillas -- comparada con las hermanas Personal/Horario, que llenan un
## modal a pantalla completa de sobra). Devuelve la Y final del contenido (para dimensionar).
def dibujar_contenido(img, d, W, H, MY0):
    # ── Marco del modal (mismo ancho que Personal/Horario — pantallas hermanas; alto AUTOAJUSTADO
    # al contenido real de esta pantalla, más modesta: 2 ventanillas, no 3 controles grandes) ──────
    MX0, MX1 = 48, W - 48
    MY1 = H - MY0
    sombra_rect(img, (MX0, MY0, MX1, MY1), 22, alfa=60, blur=14, offset=(0, 8))
    d.rounded_rectangle([MX0, MY0, MX1, MY1], 22, fill=PANEL)

    pad = 32
    ix0, iy0, ix1, iy1 = MX0 + pad, MY0 + pad, MX1 - pad, MY1 - pad
    ancho_contenido = ix1 - ix0

    # ── Cabecera ─────────────────────────────────────────────────────────────────────────────
    d.text((ix0, iy0), "ODAC", font=F(BOLD, 24), fill=TINTA)
    d.text((ix0, iy0 + 32), "Oficina de Denuncias — decide a qué se dedica cada ventanilla",
           font=F(NORM, 12), fill=GRIS)
    cerrar_txt = "Cerrar (O)"
    fuente_c = F(SEMI, 12)
    tw = ancho_texto(d, cerrar_txt, fuente_c)
    bw = tw + 34
    boton_pill(d, ix1 - bw, iy0 + 2, bw, 30, cerrar_txt, estilo="secundario", tam=12)

    # ── Reparto de la cola por prioridad (dato agregado REAL — ver cabecera del script) ─────────
    # Flujo.personas_en_cola(&"ODAC") = 8; de esos, 5 son de denuncias Prioritarias (ODAC.
    # es_prioritaria(persona.tramite_id())) y 3 de Normales -- conteo agregando personas_de_cola().
    y_ctx = iy0 + 58
    total_cola = 8
    prioritarias_cola = 5
    normales_cola = total_cola - prioritarias_cola
    d.text((ix0, y_ctx), "EN COLA · ODAC", font=F(BOLD, 10), fill=GRIS)
    y_ctx += 18
    punto_texto(d, ix0, y_ctx + 7, "%d urgentes esperando" % prioritarias_cola, AMBAR,
                color_texto=TINTA, tam=14)
    punto_texto(d, ix0 + 260, y_ctx + 7, "%d administrativas esperando" % normales_cola, GRIS,
                color_texto=TINTA, tam=14)
    y_ctx += 30

    # ── Resumen de dedicación (comparación de conjunto — lo que ninguna ficha individual da) ───
    y_ctx += 10
    d.text((ix0, y_ctx), "DEDICACIÓN DE LA OFICINA", font=F(BOLD, 10), fill=GRIS)
    y_ctx += 18
    resumen = [
        ("0 Polivalente", GRIS_SUAVE, TINTA), ("1 Solo prioritarias", AMBAR_SUAVE, AMBAR_TEXTO),
        ("0 Solo normales", GRIS_SUAVE, TINTA), ("1 A medida", ACENTO_SUAVE, ACENTO),
    ]
    xr = ix0
    for texto, fondo, color_txt in resumen:
        xr += chip(d, xr, y_ctx, texto, fondo, color_txt, tam=12, alto=28) + 10
    y_ctx += 28 + 18

    # ── Aviso de cobertura (la válvula anti-inanición, OD5 — datos reales del escenario) ────────
    sin_cubrir = [
        "Amenazas", "Ciberestafa / delito informático", "Estafas", "Lesiones",
        "Okupación de vivienda", "Pérdidas / sustracciones", "Permisos de viaje",
        "Hoja de reclamaciones",
    ]
    banner_x0, banner_x1 = ix0, ix1
    banner_y0 = y_ctx
    fuente_banner_titulo = F(BOLD, 12)
    titulo_banner = "SIN COBERTURA · %d tipos de denuncia sin ninguna ventanilla que los atienda" % len(sin_cubrir)
    # Altura del banner: título + filas de chips (se calcula simulando el flujo antes de pintar fondo).
    chips_alto_estimado = 24
    filas_estimadas = 1
    xx = banner_x0 + 18
    for t in sin_cubrir:
        w = 14 + ancho_texto(d, t, F(SEMI, 10)) + 12
        if xx != banner_x0 + 18 and xx + w > banner_x1 - 18:
            filas_estimadas += 1
            xx = banner_x0 + 18
        xx += w + 6
    banner_h = 16 + 18 + filas_estimadas * (chips_alto_estimado + 6) + 12
    sombra_rect(img, (banner_x0, banner_y0, banner_x1, banner_y0 + banner_h), 14, alfa=20)
    d.rounded_rectangle([banner_x0, banner_y0, banner_x1, banner_y0 + banner_h], 14, fill=ROJO_SUAVE)
    d.rounded_rectangle([banner_x0, banner_y0, banner_x0 + 4, banner_y0 + banner_h], 2, fill=ROJO)
    # Triángulo de alerta DIBUJADO (forma, no solo color -- accesibilidad transversal del proyecto,
    # mismo criterio que los toasts de F3): el banner no depende solo del rojo para leerse crítico.
    triangulo_alerta(d, banner_x0 + 28, banner_y0 + 20, 10, ROJO)
    d.text((banner_x0 + 46, banner_y0 + 12), titulo_banner, font=fuente_banner_titulo, fill=ROJO)
    flujo_chips(d, banner_x0 + 18, banner_y0 + 34, (banner_x1 - banner_x0) - 36, sin_cubrir,
                (255, 255, 255), ROJO, tam=10, alto=24)

    # ── Ventanillas ODAC, en columnas (comparación lado a lado — la razón de ser de la pantalla) ──
    y_lista = banner_y0 + banner_h + 24
    d.text((ix0, y_lista), "VENTANILLAS ODAC", font=F(BOLD, 13), fill=TINTA)
    y_lista += 26

    gap_col = 24
    ancho_col = (ancho_contenido - gap_col) / 2

    fin1 = tarjeta_odac(
        img, d, ix0, y_lista, ancho_col,
        "ODAC 1", "Marta Soler", False, "ATENDIENDO", VERDE,
        "Violencia de género (VioGén) · turno nº 12 · quedan 22 min",
        "prioritarias", "Solo prioritarias",
        "Solo VioGén, desaparecidos, agresiones y atracos.", AMBAR_TEXTO,
        False, [],
    )
    d = ImageDraw.Draw(img, "RGBA")
    fin2 = tarjeta_odac(
        img, d, ix0 + ancho_col + gap_col, y_lista, ancho_col,
        "ODAC 2", "Javier Nieto", False, "LIBRE", GRIS,
        "",
        "a_medida", "A medida",
        "Se afina tipo a tipo en su ficha (clic sobre la ventanilla).", GRIS,
        True, ["Hurtos / robos", "Daños"],
    )
    d = ImageDraw.Draw(img, "RGBA")

    y_fin = max(fin1, fin2) + 14
    nota = "El detalle tipo a tipo (las 14 casillas) se afina en la ficha de cada ventanilla — clic sobre ella en el mundo."
    d.text((ix0, y_fin), nota, font=F(NORM, 10), fill=GRIS)

    return y_fin + 16   # + el mismo pad (32) que ya se resta arriba no hace falta, esto es contenido puro


# ══ Render principal ══════════════════════════════════════════════════════════════════════════
def render():
    base = cargar_base()
    W, H = base.size

    # Mismo tratamiento de fondo que las hermanas modales (Personal/Horario): desenfoque + velo,
    # chrome (barra de título de la ventana) nítido. Se hace UNA vez y se reutiliza en las dos
    # pasadas (medir + pintar definitivo) para no desenfocar dos veces.
    chrome = base.crop((0, 0, W, 34))
    fondo_borroso = base.filter(ImageFilter.GaussianBlur(7))
    fondo_borroso.paste(chrome, (0, 0))
    velo = Image.new("RGBA", fondo_borroso.size, (10, 14, 24, 205))
    fondo_borroso.alpha_composite(velo)

    # ── Pasada 1 (EN SECO): mide cuánto ocupa el contenido real con el modal arrancando en
    # MY0_prueba, sobre una COPIA descartable -- así el modal final se puede centrar en vertical con
    # su alto real en vez de forzar el margen 40/40 fijo de las hermanas (que en ellas se llena solo,
    # aquí con 2 ventanillas dejaría medio modal en blanco). ──────────────────────────────────────
    MY0_prueba = 40
    img_prueba = fondo_borroso.copy()
    d_prueba = ImageDraw.Draw(img_prueba, "RGBA")
    y_fin_prueba = dibujar_contenido(img_prueba, d_prueba, W, H, MY0_prueba)
    alto_contenido = (y_fin_prueba - MY0_prueba) + 32   # + el mismo pad inferior que el superior

    # ── Pasada 2 (definitiva): modal centrado en vertical con ese alto medido. ───────────────────
    MY0 = max(40, int((H - alto_contenido) / 2))
    img = fondo_borroso.copy()
    d = ImageDraw.Draw(img, "RGBA")
    y_fin = dibujar_contenido(img, d, W, H, MY0)

    salida = os.path.join(SCRATCH, "maqueta_odac.png")
    img.convert("RGB").save(salida)
    print("OK ->", salida, img.size, "MY0 centrado:", MY0, "alto contenido:", alto_contenido,
          "y_fin:", y_fin)


if __name__ == "__main__":
    render()
