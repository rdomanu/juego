# Maqueta del DETALLE DE VENTANILLA (F3, tercera pieza tras Personal y Horario) — la ficha que
# aparece al pulsar sobre una ventanilla en el mundo. A diferencia de Personal/Horario, esto NO es un
# modal a pantalla completa: es una tarjeta CONTEXTUAL anclada al borde derecho (mismo criterio
# geométrico que el andamio real, src/main/panel_ventanilla.gd: anclada arriba-abajo, con el mismo
# hueco inferior para la barra del HUD — HUECO_BARRA_HUD = 100 px, literal del código), que deja VER
# el mundo detrás. Mismo lenguaje v3 que las hermanas (menu_v3_completo.png / kit_ui_comisario.gd /
# maqueta_personal.py / maqueta_horario.py): tarjeta blanca, sombra suave, un único acento azul.
#
# Contenido: SOLO lo que gestiona src/main/panel_ventanilla.gd (leído entero, 454 líneas) + las
# fuentes reales que consulta:
#   - AHORA MISMO: Flujo.persona_en_puesto / restante_de_puesto / siguiente_de (turno, trámite,
#     minutos restantes, el siguiente ya llamado).
#   - QUIÉN LA LLEVA: Personal.agente_de + atributos + cansancio con su consecuencia real
#     (mult_cansancio_rendimiento).
#   - EFICACIA (descompuesta, tal cual pide el comentario de cabecera del panel real): duración de
#     catálogo, el % que suma/resta el agente (modificador_produccion_de) y el equipamiento
#     (mult_equipamiento), y las atenciones/hora resultantes.
#   - EN COLA: Flujo.personas_en_cola(servicio) — dato REAL aunque el andamio actual no lo pinte
#     todavía (el mismo criterio ya usado en maqueta_personal.py con "quién opera").
#   - QUÉ ATIENDE: TipoPuesto.atenciones_admitidas (catálogo real: puesto_doc_general admite DNI y
#     Pasaporte, datos/puestos/puesto_doc_general.tres).
#   - HORARIO DEL SERVICIO: la MISMA API de Documentación que el panel de la tecla H (_bloque_horario
#     del andamio real dice explícitamente que es el mismo horario, no una copia) — mismo escenario
#     que maqueta_horario.py (Elena Ortiz en DNI 1, cierre 17:00, peonada 55 €/día) para que las tres
#     fichas del mismo día cuenten la misma historia.
#   - Cerrar con X (arriba) y con Esc (real: `_unhandled_input` solo escucha Esc — NO hay tecla de
#     apertura propia, se abre al pulsar la ventanilla en el mundo).
#
# Nombres de ventanilla: "DNI 1" (regla del proyecto, PanelPersonal.nombre_visible_de_puesto) — NUNCA
# el id técnico "doc_1". El propio andamio real también usa `String(_puesto_id)` sin traducir (una
# deuda que esta maqueta corrige, igual que ya corrigió Personal/Horario).
#
# Fondo: fondo_v3.png SIN velo oscuro completo — el mundo se ve. Solo una atenuación MUY suave fuera
# de la ficha, y un marcador de selección (halo + mesa) en la sala de espera abierta del fondo — se
# evitó a propósito la zona ya rotulada "Oficina de ODAC" del propio fondo_v3.png (ahí ya hay un texto
# real que dice ODAC; poner "DNI 1" encima habría sido una maqueta que se contradice a sí misma).
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# Fondo REAL del juego de HOY (captura de ventana con el HUD y la barra de acciones modernas
# ya implementados) -- fondo_v3.png arrastraba la barra de construccion VIEJA pixel-art, que
# ya no existe (auditoria 2026-08-18).
import os
# Promovida a design/ el 2026-08-18; el fondo (captura real del juego con la UI moderna) viaja
# como fondo_actual.png junto al script.
FONDO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fondo_actual.png")
SCRATCH = os.path.dirname(os.path.abspath(__file__))
F_DIR = r"C:\Windows\Fonts"

# ── Paleta (idéntica a maqueta_personal.py / maqueta_horario.py) ─────────────────────────────
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


# ── Helpers de "ficha secuencial" — calcan _linea()/_separador() del andamio real: una línea, un
# color, un tamaño, y se avanza el cursor Y. Mantiene el guion de la ficha legible como una lista de
# instrucciones, igual que el GDScript original. ──────────────────────────────────────────────────
def linea(d, x, y, texto, color, tam=13, negrita=False, ancho_max=None, salto=6):
    fuente = F(SEMI if negrita else NORM, tam)
    if ancho_max is not None:
        y_cur = y
        for l in envolver_texto(d, texto, fuente, ancho_max):
            d.text((x, y_cur), l, font=fuente, fill=color)
            y_cur += tam + salto
        return y_cur
    d.text((x, y), texto, font=fuente, fill=color)
    return y + tam + salto


def etiqueta_seccion(d, x, y, texto):
    d.text((x, y), texto, font=F(BOLD, 10), fill=GRIS)
    return y + 20


def separador(d, x0, x1, y):
    d.line([x0, y, x1, y], fill=LINEA, width=1)
    return y + 14


def pista_mini(d, x, y, ancho, fraccion, color, min_label, max_label):
    d.rounded_rectangle([x, y, x + ancho, y + 6], 3, fill=LINEA)
    hx = x + ancho * max(0.0, min(1.0, fraccion))
    d.rounded_rectangle([x, y, hx, y + 6], 3, fill=color)
    d.ellipse([hx - 7, y - 4, hx + 7, y + 10], fill=TARJETA, outline=color, width=2)
    d.text((x, y + 14), min_label, font=F(NORM, 9), fill=GRIS)
    tw = ancho_texto(d, max_label, F(NORM, 9))
    d.text((x + ancho - tw, y + 14), max_label, font=F(NORM, 9), fill=GRIS)
    return y + 32


def casilla(d, x, y, lado, marcada):
    if marcada:
        d.rounded_rectangle([x, y, x + lado, y + lado], 4, fill=ACENTO)
        d.line([x + lado * 0.22, y + lado * 0.55, x + lado * 0.42, y + lado * 0.75],
               fill=(255, 255, 255), width=2)
        d.line([x + lado * 0.42, y + lado * 0.75, x + lado * 0.8, y + lado * 0.25],
               fill=(255, 255, 255), width=2)
    else:
        d.rounded_rectangle([x, y, x + lado, y + lado], 4, outline=(190, 196, 208), width=2)


# ── Marcador de selección en el mundo (realce de baldosa isométrica, NUNCA sobre una etiqueta
# existente del fondo — se comprobó fondo_v3.png a mano: la zona "Oficina de ODAC" queda evitada).
# Auditoría v1: una "mesa" dibujada a mano (rectángulo + monitor) quedaba torpe y desconectada de la
# rejilla isométrica. Se sustituye por el MISMO lenguaje que ya usa maqueta_hud_v3.py para el suelo
# (un rombo isométrico, `d0.polygon`) — encaja con la escena y con el corro de sillas que YA rodea
# ese hueco central en el fondo real (se aprovecha, no se inventa mobiliario nuevo). ─────────────
def marcador_mundo(img, d, cx, cy):
    semiancho, semialto = 46, 19
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(capa)
    rombo = [(cx - semiancho, cy), (cx, cy - semialto), (cx + semiancho, cy), (cx, cy + semialto)]
    dd.polygon(rombo, fill=(*ACENTO, 70))
    dd.polygon(rombo, outline=(*ACENTO, 220))
    rombo_ext = [(cx - semiancho - 10, cy), (cx, cy - semialto - 10),
                 (cx + semiancho + 10, cy), (cx, cy + semialto + 10)]
    dd.polygon(rombo_ext, outline=(*ACENTO, 90))
    img.alpha_composite(capa)
    d = ImageDraw.Draw(img, "RGBA")
    # Etiqueta flotante "DNI 1" encima del marcador.
    fuente_tag = F(BOLD, 12)
    texto = "DNI 1"
    tw = ancho_texto(d, texto, fuente_tag)
    tag_w, tag_h = tw + 20, 26
    tag_x, tag_y = cx - tag_w / 2, cy - 52
    sombra_rect(img, (tag_x, tag_y, tag_x + tag_w, tag_y + tag_h), tag_h // 2, alfa=40, blur=5)
    d.rounded_rectangle([tag_x, tag_y, tag_x + tag_w, tag_y + tag_h], tag_h // 2, fill=ACENTO)
    texto_centrado_v(d, (tag_x + 10, tag_y + tag_h / 2), texto, fuente_tag, (255, 255, 255), tag_h)


# ══ Render principal ══════════════════════════════════════════════════════════════════════════
def render():
    img = cargar_base()
    W, H = img.size
    d = ImageDraw.Draw(img, "RGBA")

    # Marcador de selección en el mundo -- ANTES de la ficha, para que la ficha quede por encima si
    # se solapan en algún punto (no debería, pero por si acaso el orden es el correcto).
    marcador_mundo(img, d, 390, 300)
    d = ImageDraw.Draw(img, "RGBA")

    # Atenuación MUY suave del resto del mundo (NO un velo completo: el mundo se sigue viendo) --
    # una capa oscura casi transparente sobre TODO, y luego se recorta un hueco claro alrededor del
    # marcador para que la ventanilla seleccionada quede, si acaso, un poco MÁS viva, no menos.
    velo = Image.new("RGBA", img.size, (10, 14, 24, 40))
    img.alpha_composite(velo)
    d = ImageDraw.Draw(img, "RGBA")

    # ── La ficha: columna anclada al borde derecho (mismas medidas que el andamio real: hueco
    # inferior HUECO_BARRA_HUD = 100 px para la barra del HUD; el resto son proporciones del kit
    # moderno, más aire que el andamio de texto plano). ──────────────────────────────────────────
    HUECO_BARRA_HUD = 100
    px0, py0 = W - 476, 16
    px1, py1 = W - 16, H - HUECO_BARRA_HUD
    ancho_p = px1 - px0

    sombra_rect(img, (px0, py0, px1, py1), 20, alfa=50, blur=12, offset=(0, 6))
    d.rounded_rectangle([px0, py0, px1, py1], 20, fill=PANEL)

    pad = 24
    x0, x1 = px0 + pad, px1 - pad
    y = py0 + 22

    # Cabecera: nombre del TIPO de puesto (catálogo) + botón cerrar (X) ------------------------------
    d.text((x0, y), "Ventanilla Documentación", font=F(BOLD, 18), fill=TINTA)
    lado_x = 30
    bx, by = px1 - pad - lado_x, y - 2
    d.rounded_rectangle([bx, by, bx + lado_x, by + lado_x], 8, fill=TARJETA, outline=LINEA, width=1)
    d.line([bx + 9, by + 9, bx + lado_x - 9, by + lado_x - 9], fill=GRIS, width=2)
    d.line([bx + lado_x - 9, by + 9, bx + 9, by + lado_x - 9], fill=GRIS, width=2)
    y += 30

    # DNI 1 · ATENDIENDO (chip de estado — punto de color + texto, respaldo daltónico) --------------
    d.ellipse([x0, y + 4, x0 + 10, y + 14], fill=VERDE)
    d.text((x0 + 18, y), "DNI 1 · ATENDIENDO", font=F(SEMI, 12), fill=GRIS)
    y += 28
    y = separador(d, x0, x1, y)

    # ── AHORA MISMO ───────────────────────────────────────────────────────────────────────────
    y = etiqueta_seccion(d, x0, y, "AHORA MISMO")
    y = linea(d, x0, y, "DNI", TINTA, tam=16, negrita=True)
    y = linea(d, x0, y, "Turno nº 47", GRIS, tam=11)
    y = linea(d, x0, y, "Quedan 8 min de trámite", VERDE, tam=13, negrita=True)
    y = linea(d, x0, y, "Siguiente ya llamado: turno nº 48", GRIS, tam=11)
    y = separador(d, x0, x1, y)

    # ── QUIÉN LA LLEVA ────────────────────────────────────────────────────────────────────────
    y = etiqueta_seccion(d, x0, y, "QUIÉN LA LLEVA")
    y = linea(d, x0, y, "Elena Ortiz", TINTA, tam=16, negrita=True)
    y = linea(d, x0, y, "Rapidez 3 · Trato 4 · Motivación 3", GRIS, tam=12)
    y = linea(d, x0, y, "Cansancio 72 %  (+15 % más lento)", ROJO, tam=13, negrita=True)
    y = separador(d, x0, x1, y)

    # ── EFICACIA (descompuesta — la razón de ser de la ficha) ────────────────────────────────
    y = etiqueta_seccion(d, x0, y, "EFICACIA")
    y = linea(d, x0, y, "DNI: 13,1 min", TINTA, tam=15, negrita=True)
    y = linea(d, x0, y, "De catálogo: 12 min", GRIS, tam=11)
    y = linea(d, x0, y, "Por su agente: +15 %", ROJO, tam=11)
    y = linea(d, x0, y, "Por el equipamiento: −5 %", VERDE, tam=11)
    y = linea(d, x0, y, "≈ 4,6 atenciones/hora", TINTA, tam=12, negrita=True)
    y = separador(d, x0, x1, y)

    # ── EN COLA (Flujo.personas_en_cola — dato real, todo el servicio) ───────────────────────
    y = etiqueta_seccion(d, x0, y, "EN COLA · DOCUMENTACIÓN")
    y = linea(d, x0, y, "6 personas esperando turno", AMBAR_TEXTO, tam=13, negrita=True)
    y = separador(d, x0, x1, y)

    # ── QUÉ ATIENDE ───────────────────────────────────────────────────────────────────────────
    y = etiqueta_seccion(d, x0, y, "QUÉ ATIENDE")
    y = linea(d, x0, y, "DNI, Pasaporte", TINTA, tam=13)
    y = separador(d, x0, x1, y)

    # ── HORARIO DEL SERVICIO (misma API que el panel de la tecla H — no es una copia) ────────
    y = etiqueta_seccion(d, x0, y, "HORARIO DEL SERVICIO")
    y = linea(d, x0, y, "Abre 08:00 · cierra 17:00", TINTA, tam=13, negrita=True)
    y = pista_mini(d, x0, y + 6, x1 - x0, (1020 - 870) / float(1290 - 870), AMBAR, "14:30", "21:30") + 4
    y = linea(d, x0, y, "Peonada: 55 €/día (2,5 h extra × 1 agente)", ROJO, tam=12)
    y = linea(d, x0, y, "Precio de la hora extra: 22 €", TINTA, tam=12, negrita=True)
    y = pista_mini(d, x0, y + 6, x1 - x0, (22 - 15) / float(30 - 15), ACENTO, "15 €", "30 €") + 4
    y = linea(d, x0, y, "Pagar mejor cansa menos a quien se queda", GRIS, tam=10)
    casilla(d, x0, y + 2, 18, True)
    d.text((x0 + 26, y), "Esta ventanilla se queda por la tarde", font=F(SEMI, 12), fill=TINTA)
    y += 30
    y = separador(d, x0, x1, y)

    # Cerrar (Esc) ----------------------------------------------------------------------------------
    btxt = "Cerrar (Esc)"
    fuente_b = F(SEMI, 12)
    bw = ancho_texto(d, btxt, fuente_b) + 32
    boton_pill(d, x0, y, bw, 32, btxt, estilo="secundario", tam=12)

    salida = os.path.join(SCRATCH, "maqueta_ventanilla.png")
    img.convert("RGB").save(salida)
    print("OK ->", salida, img.size, "panel bottom:", py1, "contenido hasta:", y + 32)


if __name__ == "__main__":
    render()
