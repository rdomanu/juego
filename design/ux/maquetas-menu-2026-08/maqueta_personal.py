# Maqueta de la pantalla "Personal" — ITERACIÓN 3: "EL TABLÓN DE DESTINOS" (carta blanca del usuario,
# 2026-08-17: "planifica el menú de personal para que sea intuitivo, fácil y con la información
# deseada, puedes reorganizar lo que quieras" + pide explícitamente MOVER ARRASTRANDO).
#
# Concepto: la pantalla gira alrededor de los PUESTOS (el "tablón"), no de dos listas separadas.
# Jerarquía de uso (de más a menos frecuente): PUESTOS > BANQUILLO > ACADEMIA > FICHA DE DETALLE.
# El gesto principal es arrastrar una tarjeta (banquillo o academia) a un slot de puesto; "Mover a ▾"
# en la ficha es la ALTERNATIVA de clic (regla del proyecto: nunca una acción SOLO por arrastre).
#
# Lenguaje visual: el mismo de siempre (menu_v3_completo.png / kit_ui_comisario.gd) — panel claro,
# tarjetas blancas con sombra suave, esquinas muy redondeadas, un único acento azul, chips con
# punto de color + texto, barras finas. Compuesta sobre fondo_v3.png con velo oscuro + desenfoque
# (conservados tal cual los dejó el coordinador: GaussianBlur(7) + velo alfa 205, chrome nítido).
#
# Honestidad (regla del proyecto — verificado en src/core/personal/personal.gd):
#   - `asignar()` (líneas 965-999): un puesto YA ocupado devuelve `false` sin excepción de
#     intercambio -> el slot ocupado se atenúa con "ocupado" durante el arrastre, NUNCA se sugiere
#     soltar ahí.
#   - La compatibilidad depende de `puestos_operables` del TipoAgente -> los puestos de un SERVICIO
#     distinto al del agente arrastrado se atenúan con "no compatible".
#   - Contratar desde ACADEMIA a un slot vacante = 2 llamadas reales compuestas (`contratar()` +
#     `asignar()`) — se anota como tal, no como una mecánica nueva.
#   - Solo existen los servicios Documentación y ODAC (`Personal.TIPOS_MERCADO`) — no hay TIE en
#     este build; por eso el tablón NO muestra un grupo TIE (la nota del usuario decía "si existe").
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

import os
# La imagen se escribe junto al script (promovido a design/ux/maquetas-menu-2026-08/ el 2026-08-17).
SCRATCH = os.path.dirname(os.path.abspath(__file__))
FONDO = r"C:\Users\manur\juego\design\ux\maquetas-menu-2026-08\fondo_v3.png"
F_DIR = r"C:\Windows\Fonts"

# ── Paleta (calcada de MOD_COLOR_* en src/ui/kit_ui_comisario.gd) ────────────────────────────────
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
AMBAR_TEXTO = (181, 112, 15)   # variante oscurecida SOLO para texto de cuerpo sobre PANEL (contraste)
ROJO = (226, 88, 82)
ROJO_SUAVE = (250, 227, 225)
AZUL_CUBRIENDO = (92, 156, 235)   # distinto matiz del ACENTO — mismo criterio que el andamio (COLOR_CUBRIENDO)
GRIS_SUAVE = (231, 233, 237)
GRIS_MUY_SUAVE = (243, 245, 248)


def F(nombre, tam):
    return ImageFont.truetype(os.path.join(F_DIR, nombre), tam)


NORM, SEMI, BOLD = "segoeui.ttf", "seguisb.ttf", "segoeuib.ttf"


# ── Nombres de puesto en clave de servicio (se conserva de la iteración 2) ───────────────────
# El usuario dio dos opciones: "DNI/PASAPORTE 1" (larga) o "DNI 1" (corta). Se usa la corta porque
# cabe en un rótulo de slot sin partirse; el resto del script SIEMPRE pasa por `puesto_legible()`.
NOMBRE_PUESTO = {
    "doc_1": "DNI 1", "doc_2": "DNI 2",
    "odac_1": "ODAC 1", "odac_2": "ODAC 2",
}


def puesto_legible(puesto_id):
    return NOMBRE_PUESTO.get(puesto_id, puesto_id)


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


# ── Piezas reutilizables ──────────────────────────────────────────────────────────────────────
def barra_atributo(d, x, y, ancho_col_label, etiqueta, valor, maximo=5, color_llena=(150, 150, 168),
                    color_texto=GRIS, tam_fuente=10, lado_w=11, lado_h=8):
    d.text((x, y), etiqueta, font=F(NORM, tam_fuente), fill=color_texto)
    cx = x + ancho_col_label
    gap = 2
    for i in range(maximo):
        cxi = cx + i * (lado_w + gap)
        col = color_llena if i < valor else (222, 224, 230)
        d.rounded_rectangle([cxi, y + 1, cxi + lado_w, y + 1 + lado_h], 2, fill=col)
    cifra_x = cx + maximo * (lado_w + gap) + 6
    d.text((cifra_x, y), "%d/%d" % (valor, maximo), font=F(NORM, tam_fuente), fill=color_texto)


def barra_progreso(d, x, y, ancho, alto, fraccion, color, fondo=LINEA):
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=fondo)
    relleno = max(2, int(ancho * max(0.0, min(1.0, fraccion))))
    if relleno > alto:
        d.rounded_rectangle([x, y, x + relleno, y + alto], alto // 2, fill=color)


def chip_estado(d, x, y, ancho, alto, texto, color_punto, color_texto=TINTA, fondo=PANEL, tam=11):
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=fondo)
    cy = y + alto // 2
    d.ellipse([x + 10, cy - 4, x + 18, cy + 4], fill=color_punto)
    texto_centrado_v(d, (x + 26, cy), texto, F(SEMI, tam), color_texto, alto)


def triangulo_abajo(d, cx, cy, tam, color):
    """Flecha "▾" a mano — el glifo unicode ▾ no lo soporta Segoe UI Semibold (sale como tofu),
    cazado en la iteración 2."""
    r = tam / 2.0
    d.polygon([(cx - r, cy - r * 0.45), (cx + r, cy - r * 0.45), (cx, cy + r * 0.65)], fill=color)


def boton_pill(d, x, y, ancho, alto, texto, estilo="primario", tam=11, con_flecha=False):
    if estilo == "primario":
        fondo, color_txt = ACENTO, (255, 255, 255)
    elif estilo == "peligro":
        fondo, color_txt = TARJETA, ROJO
    elif estilo == "deshabilitado":
        fondo, color_txt = GRIS_SUAVE, GRIS
    else:
        fondo, color_txt = TARJETA, TINTA
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=fondo)
    if estilo in ("secundario", "peligro"):
        d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, outline=LINEA, width=1)
    fuente = F(SEMI, tam)
    tw = ancho_texto(d, texto, fuente)
    flecha_hueco = 15 if con_flecha else 0
    total_w = tw + flecha_hueco
    bbox = d.textbbox((0, 0), texto, font=fuente)
    start_x = x + (ancho - total_w) / 2 - bbox[0]
    texto_centrado_v(d, (start_x, y + alto / 2), texto, fuente, color_txt, alto)
    if con_flecha:
        triangulo_abajo(d, start_x + bbox[0] + tw + 8, y + alto / 2, 8, color_txt)


def avatar_inicial(d, cx, cy, lado, inicial, color_fondo, color_letra=(255, 255, 255)):
    d.ellipse([cx - lado / 2, cy - lado / 2, cx + lado / 2, cy + lado / 2], fill=color_fondo)
    fuente = F(BOLD, int(lado * 0.4))
    bbox = d.textbbox((0, 0), inicial, font=fuente)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), inicial, font=fuente, fill=color_letra)


def rect_punteado(d, x0, y0, x1, y1, radio, color, ancho_linea=2, dash=6, hueco=5):
    """Rectángulo redondeado de borde DISCONTINUO (para el slot VACANTE — "arrastra aquí"). Los
    tramos rectos llevan guiones; las esquinas, un arco corto continuo (aproximación razonable para
    una maqueta estática — PIL no tiene "dashed rounded rect" nativo)."""
    xs, xe = x0 + radio, x1 - radio
    xcur = xs
    while xcur < xe:
        xnext = min(xcur + dash, xe)
        d.line([xcur, y0, xnext, y0], fill=color, width=ancho_linea)
        d.line([xcur, y1, xnext, y1], fill=color, width=ancho_linea)
        xcur = xnext + hueco
    ys, ye = y0 + radio, y1 - radio
    ycur = ys
    while ycur < ye:
        ynext = min(ycur + dash, ye)
        d.line([x0, ycur, x0, ynext], fill=color, width=ancho_linea)
        d.line([x1, ycur, x1, ynext], fill=color, width=ancho_linea)
        ycur = ynext + hueco
    d.arc([x0, y0, x0 + 2 * radio, y0 + 2 * radio], 180, 270, fill=color, width=ancho_linea)
    d.arc([x1 - 2 * radio, y0, x1, y0 + 2 * radio], 270, 360, fill=color, width=ancho_linea)
    d.arc([x0, y1 - 2 * radio, x0 + 2 * radio, y1], 90, 180, fill=color, width=ancho_linea)
    d.arc([x1 - 2 * radio, y1 - 2 * radio, x1, y1], 0, 90, fill=color, width=ancho_linea)


def atenuar_rect(img, x, y, ancho, alto, radio, etiqueta, alfa=175):
    """Lava semitransparente sobre un slot ocupado/incompatible durante el arrastre + una etiqueta
    pequeña en la esquina — SIEMPRE en una capa aparte + alpha_composite (dibujar con alfa
    directamente sobre `img` NO mezcla en Pillow, solo sustituye píxeles)."""
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(capa)
    dd.rounded_rectangle([x, y, x + ancho, y + alto], radio, fill=(*GRIS_MUY_SUAVE, alfa))
    img.alpha_composite(capa)
    d = ImageDraw.Draw(img, "RGBA")
    fuente = F(BOLD, 9)
    tw = ancho_texto(d, etiqueta, fuente)
    tag_w, tag_h = tw + 16, 20
    tag_x, tag_y = x + ancho - 12 - tag_w, y + 8
    d.rounded_rectangle([tag_x, tag_y, tag_x + tag_w, tag_y + tag_h], 10, fill=TARJETA)
    d.rounded_rectangle([tag_x, tag_y, tag_x + tag_w, tag_y + tag_h], 10, outline=LINEA, width=1)
    texto_centrado_v(d, (tag_x + 8, tag_y + tag_h / 2), etiqueta, fuente, GRIS, tag_h)


def color_cansancio(valor):
    if valor >= 90:
        return ROJO, ROJO
    if valor >= 70:
        return AMBAR, AMBAR_TEXTO
    return (150, 150, 168), GRIS


# ── Datos de ejemplo (coherentes con las reglas reales) ───────────────────────────────────────
PUESTOS = [
    {"id": "doc_1", "servicio": "Documentación", "estado": "cubriendo",
     "agente": {"nombre": "Diego Soto", "tipo": "Documentación", "rango": "Policía", "cansancio": 95,
                "salario": 30}},
    {"id": "doc_2", "servicio": "Documentación", "estado": "vacante"},
    {"id": "odac_1", "servicio": "ODAC", "estado": "asignado",
     "agente": {"nombre": "Marta Ruiz", "tipo": "ODAC", "rango": "Oficial", "cansancio": 82,
                "salario": 62}},
    {"id": "odac_2", "servicio": "ODAC", "estado": "ausente_sin_cobertura",
     "agente": {"nombre": "Ana Puig", "tipo": "ODAC", "rango": "Policía", "cansancio": 0,
                "salario": 34}},
]

# El agente que se está arrastrando en la ilustración (item 6 del feedback).
CARLOS = {
    "nombre": "Carlos Vidal", "tipo": "Documentación", "rango": "Policía",
    "attrs": {"Rapidez": 2, "Trato": 3, "Salud": 4, "Motivación": 2},
    "cansancio": 0, "salario": 30, "estado": "libre",
}
BANQUILLO = [CARLOS]   # el resto de la plantilla está en un puesto o de baja — ver PUESTOS

ACADEMIA = [
    {"nombre": "Laura Gómez", "tipo": "Documentación", "rango": "Policía",
     "opera": "Documentación", "salario": 32},
    {"nombre": "Iker Zabala", "tipo": "ODAC", "rango": "Oficial", "opera": "ODAC", "salario": 58},
    {"nombre": "Noa Ferrer", "tipo": "ODAC", "rango": "Policía", "opera": "ODAC", "salario": 29},
    {"nombre": "Pau Roig", "tipo": "Documentación", "rango": "Policía",
     "opera": "Documentación", "salario": 35},
]

SLOT_CHIP = {
    "cubriendo": ("Cubriendo", AZUL_CUBRIENDO),
    "asignado": ("Asignado", VERDE),
    "ausente_sin_cobertura": ("De baja — sin cobertura", GRIS),
}


# ── Slot de puesto (la pieza central del tablón) ──────────────────────────────────────────────
def slot_puesto(img, d, x, y, ancho, alto, slot, resaltado=False, ocultar_texto_vacante=False):
    pad = 14
    # Rótulo del puesto (SIEMPRE visible, ocupado o no — identidad del slot).
    rotulo = puesto_legible(slot["id"])
    fuente_rot = F(BOLD, 12)
    rw = ancho_texto(d, rotulo, fuente_rot) + 22
    rx, ry, rh = x + pad, y + (alto - 26) / 2, 26

    if slot["estado"] == "vacante":
        color_borde = ACENTO if resaltado else (190, 196, 208)
        fondo = ACENTO_SUAVE if resaltado else PANEL
        d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=fondo)
        rect_punteado(d, x, y, x + ancho, y + alto, 14, color_borde, ancho_linea=2 if not resaltado else 3)
        d.rounded_rectangle([rx, ry, rx + rw, ry + rh], 13,
                             fill=TARJETA if not resaltado else (255, 255, 255))
        texto_centrado_v(d, (rx + 11, ry + rh / 2), rotulo, fuente_rot, TINTA, rh)
        # Auditoría v3 (2ª pasada): con el fantasma del arrastre encima, este texto quedaba CORTADO a
        # media palabra bajo la leyenda flotante ("Suelta aqu|í...") — un fragmento roto, no una
        # superposición limpia. Se omite aquí; el fantasma + la leyenda ya comunican el mensaje.
        if not ocultar_texto_vacante:
            texto = "Suelta aquí para asignar" if resaltado else "VACANTE — arrastra aquí un agente"
            color_txt = ACENTO if resaltado else GRIS
            fuente_v = F(SEMI, 13)
            tw = ancho_texto(d, texto, fuente_v)
            cx0 = rx + rw + 16
            texto_centrado_v(d, (cx0 + (ancho - (cx0 - x) - 16 - tw) / 2, y + alto / 2), texto,
                              fuente_v, color_txt, alto)
        return

    # Ocupado (asignado / cubriendo / de baja): tarjeta blanca sólida.
    sombra_rect(img, (x, y, x + ancho, y + alto), 14)
    d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=TARJETA)
    atenuada = slot["estado"] == "ausente_sin_cobertura"
    d.rounded_rectangle([rx, ry, rx + rw, ry + rh], 13, fill=PANEL)
    texto_centrado_v(d, (rx + 11, ry + rh / 2), rotulo, fuente_rot, TINTA, rh)

    ag = slot["agente"]
    ax = rx + rw + 16
    cy = y + alto / 2
    color_avatar = (170, 178, 196) if atenuada else ACENTO
    avatar_inicial(d, ax + 18, cy, 38, ag["nombre"][0], color_avatar)

    ix = ax + 40
    color_nombre = GRIS if atenuada else TINTA
    d.text((ix, y + 16), ag["nombre"], font=F(SEMI, 13), fill=color_nombre)
    d.text((ix, y + 33), "%s · %s" % (ag["tipo"], ag["rango"]), font=F(NORM, 10), fill=GRIS)
    texto_chip, color_chip = SLOT_CHIP[slot["estado"]]
    chip_estado(d, ix, y + 51, 168, 20, texto_chip, color_chip, tam=9)

    cxc = ix + 190
    color_barra_c, color_texto_c = color_cansancio(ag["cansancio"])
    if atenuada:
        color_barra_c, color_texto_c = (205, 207, 214), GRIS
    d.text((cxc, y + 15), "Cansancio", font=F(NORM, 9), fill=GRIS)
    barra_progreso(d, cxc, y + 28, 100, 7, ag["cansancio"] / 100.0, color_barra_c)
    d.text((cxc, y + 40), "%d/100" % ag["cansancio"], font=F(SEMI, 9), fill=color_texto_c)

    txt_sal = "%d €/día" % ag["salario"]
    fuente_sal = F(NORM, 10)
    tw = ancho_texto(d, txt_sal, fuente_sal)
    d.text((x + ancho - pad - tw, y + alto - pad - 12), txt_sal, font=fuente_sal, fill=GRIS)


# ── Tarjeta compacta de BANQUILLO (arrastrable) ───────────────────────────────────────────────
def tarjeta_banquillo(img, d, x, y, ancho, alto, agente, arrastrando=False):
    pad = 12
    if arrastrando:
        # Origen del arrastre: se deja un HUECO (línea punteada + relleno pálido) en vez de la
        # tarjeta sólida — el fantasma real "está" flotando cerca del slot destino.
        d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=GRIS_MUY_SUAVE)
        rect_punteado(d, x, y, x + ancho, y + alto, 14, (200, 205, 214), ancho_linea=2)
        fuente_tag = F(BOLD, 9)
        tag = "Arrastrando…"
        tw = ancho_texto(d, tag, fuente_tag)
        d.text((x + ancho - pad - tw, y + 10), tag, font=fuente_tag, fill=GRIS)
        color_nombre, color_av = GRIS, (198, 203, 214)
    else:
        sombra_rect(img, (x, y, x + ancho, y + alto), 14)
        d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=TARJETA)
        color_nombre, color_av = TINTA, ACENTO

    avatar_inicial(d, x + pad + 16, y + 34, 32, agente["nombre"][0], color_av)
    ix = x + pad + 38
    d.text((ix, y + 8), agente["nombre"], font=F(SEMI, 13), fill=color_nombre)
    d.text((ix, y + 25), "%s · %s" % (agente["tipo"], agente["rango"]), font=F(NORM, 10), fill=GRIS)

    # Cansancio en SU PROPIA fila y el salario en la suya — auditoría v3: compartir fila hacía que
    # la cifra de cansancio y el salario colisionaran ("0/10030 €/día").
    color_barra_c, color_texto_c = color_cansancio(agente["cansancio"])
    d.text((ix, y + 43), "Cansancio", font=F(NORM, 9), fill=GRIS)
    barra_progreso(d, ix + 58, y + 44, 78, 7, agente["cansancio"] / 100.0, color_barra_c)
    d.text((ix + 142, y + 43), "%d/100" % agente["cansancio"], font=F(SEMI, 9), fill=color_texto_c)

    txt_sal = "%d €/día" % agente["salario"]
    fuente_sal = F(NORM, 9)
    tw = ancho_texto(d, txt_sal, fuente_sal)
    d.text((x + ancho - pad - tw, y + 60), txt_sal, font=fuente_sal, fill=GRIS)


# ── Tarjeta compacta de ACADEMIA (arrastrable) ────────────────────────────────────────────────
def tarjeta_academia(img, d, x, y, ancho, alto, candidato):
    sombra_rect(img, (x, y, x + ancho, y + alto), 14)
    d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=TARJETA)
    pad = 14
    avatar_inicial(d, x + pad + 17, y + alto / 2, 34, candidato["nombre"][0], (110, 122, 148))
    ix = x + pad + 40
    d.text((ix, y + 11), candidato["nombre"], font=F(SEMI, 13), fill=TINTA)
    d.text((ix, y + 28), "%s · %s" % (candidato["tipo"], candidato["rango"]), font=F(NORM, 10), fill=GRIS)
    d.text((ix, y + 44), "Opera: %s" % candidato["opera"], font=F(NORM, 9), fill=GRIS)

    texto_boton = "Contratar — %d €/día" % candidato["salario"]
    fuente = F(SEMI, 10)
    tw = ancho_texto(d, texto_boton, fuente)
    bw = tw + 26
    bx = x + ancho - pad - bw
    by = y + (alto - 26) / 2
    boton_pill(d, bx, by, bw, 26, texto_boton, estilo="primario", tam=10)


# ── Ficha de detalle (grid -> ficha, mismo patrón que el panel de construcción) ───────────────
def ficha_detalle(img, d, x, y, ancho, alto, agente):
    sombra_rect(img, (x, y, x + ancho, y + alto), 18, alfa=30, blur=9)
    d.rounded_rectangle([x, y, x + ancho, y + alto], 18, fill=TARJETA)
    pad = 24

    d.text((x + pad, y + 14), "SELECCIONADO", font=F(BOLD, 10), fill=GRIS)

    cy = y + alto / 2 + 6
    avatar_inicial(d, x + pad + 32, cy, 64, agente["nombre"][0], ACENTO)
    ix = x + pad + 76
    d.text((ix, y + 36), agente["nombre"], font=F(BOLD, 20), fill=TINTA)
    d.text((ix, y + 66), "%s · %s" % (agente["tipo"], agente["rango"]), font=F(NORM, 12), fill=GRIS)
    chip_estado(d, ix, y + 90, 168, 24, "En el banquillo", AMBAR, tam=11)

    # Atributos
    ax = ix + 220
    ay = y + 40
    fila = 0
    for etiqueta, valor in agente["attrs"].items():
        barra_atributo(d, ax, ay + fila * 20, 78, etiqueta, valor, color_llena=(140, 148, 172),
                        color_texto=GRIS, tam_fuente=11, lado_w=13, lado_h=9)
        fila += 1

    # Cansancio grande
    cxc = ax + 280
    color_barra_c, color_texto_c = color_cansancio(agente["cansancio"])
    d.text((cxc, y + 40), "Cansancio", font=F(SEMI, 12), fill=GRIS)
    barra_progreso(d, cxc, y + 62, 200, 12, agente["cansancio"] / 100.0, color_barra_c)
    d.text((cxc + 210, y + 55), "%d/100" % agente["cansancio"], font=F(BOLD, 15), fill=color_texto_c)
    d.text((cxc, y + 100), "Salario: %d €/día" % agente["salario"], font=F(NORM, 12), fill=GRIS)

    # Acciones (derecha) — LIBRE: "Mover a" + "Despedir". "Desasignar" es SOLO para un agente
    # ASIGNADO (no aplica a Carlos, que está en el banquillo) — se omite por honestidad, no por
    # espacio: mostrar un botón que hoy no haría nada sería el mismo error que ya evitó el andamio.
    bw_desp = ancho_texto(d, "Despedir", F(SEMI, 12)) + 32
    bx = x + ancho - pad - bw_desp
    by = y + alto - pad - 34
    boton_pill(d, bx, by, bw_desp, 34, "Despedir", estilo="peligro", tam=12)
    bx -= 10
    bw_mover = ancho_texto(d, "Mover a", F(SEMI, 12)) + 32 + 15
    bx -= bw_mover
    boton_pill(d, bx, by, bw_mover, 34, "Mover a", estilo="secundario", tam=12, con_flecha=True)
    nota = "El desplegable lista los puestos compatibles — alternativa al arrastre."
    fuente_n = F(NORM, 9)
    tw = ancho_texto(d, nota, fuente_n)
    d.text((x + ancho - pad - tw, by - 16), nota, font=fuente_n, fill=GRIS)


# ── Ilustración del arrastre (fantasma + cursor + leyenda) ────────────────────────────────────
def dibujar_cursor(d, x, y, escala=1.15, color=(28, 32, 42)):
    puntos = [(0, 0), (0, 17), (4.5, 13), (7.5, 20), (10.5, 18.5), (7.5, 12), (13, 12)]
    puntos = [(x + px * escala, y + py * escala) for px, py in puntos]
    d.polygon(puntos, fill=color, outline=(255, 255, 255), width=1)


def fantasma_banquillo(img, x, y, ancho, alto, agente, alfa=205):
    """Copia semitransparente de la tarjeta de banquillo, siguiendo el cursor — SIEMPRE en una capa
    aparte (ver nota en `atenuar_rect`: Pillow no mezcla alfa al dibujar directo sobre `img`)."""
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(capa, "RGBA")
    dd.rounded_rectangle([x + 3, y + 10, x + ancho + 3, y + alto + 10], 14, fill=(10, 14, 24, 60))
    dd.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=(255, 255, 255, alfa))
    dd.rounded_rectangle([x, y, x + ancho, y + alto], 14, outline=(*ACENTO, 255), width=2)
    pad = 12
    dd.ellipse([x + pad, y + alto / 2 - 15, x + pad + 30, y + alto / 2 + 15], fill=(*ACENTO, alfa))
    fuente_i = F(BOLD, 12)
    inicial = agente["nombre"][0]
    bbox = dd.textbbox((0, 0), inicial, font=fuente_i)
    dd.text((x + pad + 15 - (bbox[2] - bbox[0]) / 2 - bbox[0],
              y + alto / 2 - (bbox[3] - bbox[1]) / 2 - bbox[1]), inicial, font=fuente_i,
             fill=(255, 255, 255, 255))
    ix = x + pad + 40
    dd.text((ix, y + 14), agente["nombre"], font=F(SEMI, 13), fill=(*TINTA, 255))
    dd.text((ix, y + 33), "%s · %s" % (agente["tipo"], agente["rango"]), font=F(NORM, 10),
             fill=(*GRIS, 255))
    img.alpha_composite(capa)


def leyenda_flotante(img, d, x, y, texto):
    fuente = F(SEMI, 11)
    tw = ancho_texto(d, texto, fuente)
    w, h = tw + 22, 28
    sombra_rect(img, (x, y, x + w, y + h), h // 2, alfa=50, blur=6, offset=(0, 3))
    d.rounded_rectangle([x, y, x + w, y + h], h // 2, fill=ACENTO)
    texto_centrado_v(d, (x + 11, y + h / 2), texto, fuente, (255, 255, 255), h)


# ══ Render principal ══════════════════════════════════════════════════════════════════════════
def render():
    img = cargar_base()
    W, H = img.size

    # Desenfoque del juego bajo el velo + velo oscuro (conservados tal cual del coordinador).
    chrome = img.crop((0, 0, W, 34))
    img = img.filter(ImageFilter.GaussianBlur(7))
    img.paste(chrome, (0, 0))
    velo = Image.new("RGBA", img.size, (10, 14, 24, 205))
    img.alpha_composite(velo)

    d = ImageDraw.Draw(img, "RGBA")

    # ── Marco del modal ──────────────────────────────────────────────────────────────────────
    MX0, MY0, MX1, MY1 = 48, 40, W - 48, H - 40
    sombra_rect(img, (MX0, MY0, MX1, MY1), 22, alfa=60, blur=14, offset=(0, 8))
    d.rounded_rectangle([MX0, MY0, MX1, MY1], 22, fill=PANEL)

    pad = 32
    ix0, iy0, ix1, iy1 = MX0 + pad, MY0 + pad, MX1 - pad, MY1 - pad

    # Cabecera -------------------------------------------------------------------------------------
    d.text((ix0, iy0), "Personal", font=F(BOLD, 24), fill=TINTA)
    d.text((ix0, iy0 + 32), "Arrastra un agente a un puesto, o usa \"Mover a\" — se gestiona igual en pausa",
           font=F(NORM, 12), fill=GRIS)

    cerrar_txt = "Cerrar (P)"
    fuente_c = F(SEMI, 12)
    tw = ancho_texto(d, cerrar_txt, fuente_c)
    bw = tw + 34
    boton_pill(d, ix1 - bw, iy0 + 2, bw, 30, cerrar_txt, estilo="secundario", tam=12)

    y_linea2 = iy0 + 58
    nomina_total = sum(a["salario"] for a in BANQUILLO) + sum(
        p["agente"]["salario"] for p in PUESTOS if "agente" in p)
    d.text((ix0, y_linea2), "Saldo: 2.450 €   ·   Nómina: %d €/día" % nomina_total,
           font=F(NORM, 13), fill=TINTA)

    en_puesto = sum(1 for p in PUESTOS if p["estado"] in ("asignado", "cubriendo"))
    banquillo_n = len(BANQUILLO)
    de_baja = sum(1 for p in PUESTOS if p["estado"] == "ausente_sin_cobertura")
    total_plantilla = en_puesto + banquillo_n + de_baja
    cubiertos = sum(1 for p in PUESTOS if p["estado"] in ("asignado", "cubriendo"))
    total_puestos = len(PUESTOS)
    vacantes = total_puestos - cubiertos
    color_resumen = AMBAR_TEXTO if vacantes > 0 else VERDE
    resumen = ("Plantilla: %d  (en puesto %d · banquillo %d · de baja %d)   —   "
               "Ventanillas cubiertas: %d de %d") % (
        total_plantilla, en_puesto, banquillo_n, de_baja, cubiertos, total_puestos,
    )
    y_linea3 = y_linea2 + 24
    d.text((ix0, y_linea3), resumen, font=F(SEMI, 13), fill=color_resumen)

    y_div = y_linea3 + 34
    d.line([ix0, y_div, ix1, y_div], fill=LINEA, width=1)

    # ── Tres columnas: PUESTOS / BANQUILLO / ACADEMIA ────────────────────────────────────────
    y_col_header = y_div + 18
    ancho_total = ix1 - ix0
    gap_col = 24
    ancho_puestos = 660
    ancho_banquillo = 260
    ancho_academia = ancho_total - ancho_puestos - ancho_banquillo - 2 * gap_col
    x_puestos = ix0
    x_banquillo = x_puestos + ancho_puestos + gap_col
    x_academia = x_banquillo + ancho_banquillo + gap_col

    d.text((x_puestos, y_col_header), "PUESTOS", font=F(BOLD, 14), fill=TINTA)
    d.text((x_banquillo, y_col_header), "BANQUILLO (%d)" % len(BANQUILLO), font=F(BOLD, 14), fill=TINTA)
    d.text((x_academia, y_col_header), "ACADEMIA (%d)" % len(ACADEMIA), font=F(BOLD, 14), fill=TINTA)

    y_cards = y_col_header + 28

    # BANQUILLO ---------------------------------------------------------------------------------
    d.text((x_banquillo, y_cards), "Arrastra la tarjeta a un puesto compatible",
           font=F(NORM, 10), fill=GRIS)
    y_ban = y_cards + 22
    alto_ban = 80
    for agente in BANQUILLO:
        tarjeta_banquillo(img, d, x_banquillo, y_ban, ancho_banquillo, alto_ban, agente,
                           arrastrando=True)
        y_ban += alto_ban + 10
    banquillo_bottom = y_ban - 10

    # ACADEMIA ------------------------------------------------------------------------------------
    d.text((x_academia, y_cards), "Nuevo ingreso — la promoción se renueva cada 3 días",
           font=F(NORM, 10), fill=GRIS)
    y_aca = y_cards + 22
    alto_aca = 68
    for candidato in ACADEMIA:
        tarjeta_academia(img, d, x_academia, y_aca, ancho_academia, alto_aca, candidato)
        y_aca += alto_aca + 10
    academia_bottom = y_aca - 10

    # PUESTOS (agrupados por servicio) -------------------------------------------------------------
    grupos = [("DNI · Documentación", ["doc_1", "doc_2"]), ("ODAC", ["odac_1", "odac_2"])]
    slot_h = 80
    y_p = y_cards
    slot_bounds = {}   # id -> (x, y) para posicionar luego el fantasma/realces
    for etiqueta_grupo, ids in grupos:
        d.text((x_puestos, y_p), etiqueta_grupo, font=F(SEMI, 12), fill=TINTA)
        y_p += 22
        for pid in ids:
            slot = next(p for p in PUESTOS if p["id"] == pid)
            resaltado = (pid == "doc_2")   # el destino ILUMINADO del arrastre en curso
            # doc_2 oculta su texto "arrastra aquí" porque el fantasma+leyenda lo tapan del todo
            # (ver comentario en slot_puesto) — el resto de slots lo enseña normal.
            slot_puesto(img, d, x_puestos, y_p, ancho_puestos, slot_h, slot, resaltado=resaltado,
                        ocultar_texto_vacante=resaltado)
            slot_bounds[pid] = (x_puestos, y_p)
            y_p += slot_h + 10
        y_p += 10
    puestos_bottom = y_p - 10

    # Atenuar los slots que NO son un destino válido para Carlos (tipo Documentación) mientras
    # arrastra: doc_1 está OCUPADO (Diego, cubriendo) -> "ocupado"; los ODAC son de otro servicio
    # -> "no compatible". doc_2 se quedó resaltado arriba (destino real).
    x0, y0 = slot_bounds["doc_1"]
    atenuar_rect(img, x0, y0, ancho_puestos, slot_h, 14, "ocupado")
    for pid in ("odac_1", "odac_2"):
        x0, y0 = slot_bounds[pid]
        atenuar_rect(img, x0, y0, ancho_puestos, slot_h, 14, "no compatible")

    # ── Divisor antes de la ficha ─────────────────────────────────────────────────────────────
    contenido_bottom = max(puestos_bottom, banquillo_bottom, academia_bottom)
    y_div2 = contenido_bottom + 20
    d = ImageDraw.Draw(img, "RGBA")   # el draw handle sigue siendo válido tras alpha_composite
    d.line([ix0, y_div2, ix1, y_div2], fill=LINEA, width=1)

    # ── Ficha de detalle (Carlos Vidal — el agente que se está arrastrando) ──────────────────
    y_ficha = y_div2 + 16
    alto_ficha = iy1 - y_ficha
    ficha_detalle(img, d, ix0, y_ficha, ancho_total, alto_ficha, CARLOS)

    # ── Ilustración del arrastre: fantasma + cursor + leyenda, ENCIMA de todo ───────────────
    # Auditoría v3 (1ª pasada): la leyenda tapaba el propio fantasma (avatar y nombre) y el cursor
    # caía sobre el rótulo "DNI 2". Reordenado: el fantasma se centra DENTRO del slot dejando el
    # rótulo visible a la izquierda; el cursor va en su esquina superior IZQUIERDA pero FUERA de su
    # cuerpo; la leyenda flota a la DERECHA del fantasma (hueco vacío del slot resaltado), nunca
    # encima de ningún texto.
    dx0, dy0 = slot_bounds["doc_2"]
    fantasma_ancho, fantasma_alto = 230, 58
    fantasma_x = dx0 + 108
    fantasma_y = dy0 + (slot_h - fantasma_alto) / 2
    fantasma_banquillo(img, fantasma_x, fantasma_y, fantasma_ancho, fantasma_alto, CARLOS)
    d = ImageDraw.Draw(img, "RGBA")
    cursor_x, cursor_y = fantasma_x - 10, fantasma_y - 8
    dibujar_cursor(d, cursor_x, cursor_y)
    leyenda_flotante(img, d, fantasma_x + fantasma_ancho + 18, fantasma_y + (fantasma_alto - 28) / 2,
                      "Soltar para asignar")

    salida = os.path.join(SCRATCH, "maqueta_personal.png")
    img.convert("RGB").save(salida)
    print("OK ->", salida, img.size)


if __name__ == "__main__":
    render()
