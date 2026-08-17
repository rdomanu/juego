# Maqueta de la pantalla "Horario" (F3, siguiente pieza tras el Tablón de Destinos de Personal) — el
# panel donde el jugador decide el cierre de Documentación. Mismo lenguaje v3 (menu_v3_completo.png /
# kit_ui_comisario.gd / maqueta_personal.py): panel claro, tarjetas blancas con sombra suave, esquinas
# muy redondeadas, un único acento azul. Compuesta sobre fondo_v3.png con el mismo tratamiento de fondo
# que Personal: GaussianBlur(7) + velo alfa 205, con el chrome (barra de título) nítido.
#
# Contenido: SOLO lo que gestiona src/main/panel_horario.gd (leído entero) + la API real de
# src/feature/documentacion/documentacion.gd (rangos, fórmulas, valores por defecto):
#   - HORARIO DE CIERRE (fijar_hora_cierre, rango [cierre_base_min, tope_autorizado()])
#   - PRECIO DE LA HORA EXTRA (fijar_peonada_eur_hora, rango [peonada_eur_hora_min, _max])
#   - ÚLTIMA ADMISIÓN (fijar_margen_ultima_admision, rango [0,30])
#   - QUÉ VENTANILLAS SE QUEDAN POR LA TARDE (fijar_puesto_de_tarde) + su apertura/cierre manual
#     AHORA MISMO (Flujo.abrir_puesto/cerrar_puesto — el mismo botón "Abrir/Cerrar/Cerrará al
#     acabar" que ya existe en el andamio, es una acción DISTINTA de la casilla de la tarde)
#   - Contexto: nivel de demanda (Documentacion.nivel_demanda) y el comunicado de la División
#     (Documentacion.evento_activo) — con datos REALES del catálogo (datos/eventos/vacaciones.tres:
#     "Periodo vacacional", autoriza cerrar hasta las 21:30, meses 7-8).
#
# Nombres de ventanilla: la norma decidida ayer (PanelPersonal.nombre_visible_de_puesto,
# PREFIJO_POR_TIPO_PUESTO) — "DNI 1"/"DNI 2"/"TIE 1"/"ODAC 1", NUNCA el id técnico. Documentación solo
# gestiona los servicios con horario propio (DNI/TIE); ODAC no tiene horario aquí — no aparece.
#
# Estado retratado (honesto, con datos de catálogo reales, no inventados): temporada de "Periodo
# vacacional" (demanda ALTA, pico de pasaportes), DNI 1 se queda de tarde (peonada en marcha, servicio
# CERRANDO ahora mismo), DNI 2 se fue a su hora base.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

import os
# La imagen se escribe junto al script (promovido a design/ux/maquetas-menu-2026-08/ el 2026-08-18).
SCRATCH = os.path.dirname(os.path.abspath(__file__))
FONDO = r"C:\Users\manur\juego\design\ux\maquetas-menu-2026-08\fondo_v3.png"
F_DIR = r"C:\Windows\Fonts"

# ── Paleta (calcada de MOD_COLOR_* en src/ui/kit_ui_comisario.gd — misma que maqueta_personal.py) ──
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

# ── Nombres de ventanilla (regla del proyecto, decidida ayer) ────────────────────────────────
# Calca PanelPersonal.PREFIJO_POR_TIPO_PUESTO / nombre_visible_de_puesto (src/main/panel_personal.gd):
# prefijo por TIPO de puesto + ordinal dentro de su grupo. Documentación solo gestiona horario de DNI
# y TIE (servicio "Documentacion"); ODAC no tiene horario propio en este panel.
PREFIJO_POR_TIPO_PUESTO = {
    "puesto_doc_general": "DNI", "puesto_ventanilla_media": "DNI", "puesto_tie": "TIE",
}


def nombre_visible_de_puesto(tipo_puesto, ordinal):
    prefijo = PREFIJO_POR_TIPO_PUESTO.get(tipo_puesto, "")
    return "%s %d" % (prefijo, ordinal) if prefijo else tipo_puesto


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
    """Envuelve `texto` en líneas que no superen `ancho_max` px (autowrap simple por palabras)."""
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
    elif estilo == "deshabilitado":
        fondo, color_txt = GRIS_SUAVE, GRIS
    else:
        fondo, color_txt = TARJETA, TINTA
    d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, fill=fondo)
    if estilo in ("secundario", "peligro", "deshabilitado"):
        d.rounded_rectangle([x, y, x + ancho, y + alto], alto // 2, outline=LINEA, width=1)
    fuente = F(SEMI, tam)
    tw = ancho_texto(d, texto, fuente)
    bbox = d.textbbox((0, 0), texto, font=fuente)
    texto_centrado_v(d, (x + (ancho - tw) / 2 - bbox[0], y + alto / 2), texto, fuente, color_txt, alto)


def punto_texto(d, x, y, texto, color_punto, color_texto=TINTA, tam=13, radio=6):
    """Punto de color + texto (respaldo daltónico: SIEMPRE los dos, nunca solo el color)."""
    cy = y
    d.ellipse([x, cy - radio, x + radio * 2, cy + radio], fill=color_punto)
    d.text((x + radio * 2 + 8, y - tam * 0.7), texto, font=F(SEMI, tam), fill=color_texto)


# ── Control grande: valor + pista con tirador + consecuencia (la pieza central de la pantalla) ──
def control_grande(img, d, x, y, ancho, alto, etiqueta, valor_grande, subtitulo, fraccion,
                    min_label, max_label, consecuencia, color_consecuencia, color_relleno=ACENTO,
                    marca_extra=None):
    """`marca_extra` = (fraccion, texto) opcional -- p. ej. el tope ORDINARIO antes de que un
    comunicado de la División lo amplíe (honestidad: se ve POR QUÉ el recorrido llega más lejos)."""
    sombra_rect(img, (x, y, x + ancho, y + alto), 18, alfa=28, blur=9)
    d.rounded_rectangle([x, y, x + ancho, y + alto], 18, fill=TARJETA)
    pad = 26

    d.text((x + pad, y + 20), etiqueta, font=F(BOLD, 12), fill=GRIS)
    d.text((x + pad, y + 42), valor_grande, font=F(BOLD, 27), fill=TINTA)
    fuente_sub = F(NORM, 12)
    tw_val = ancho_texto(d, valor_grande, F(BOLD, 27))
    d.text((x + pad + tw_val + 14, y + 56), subtitulo, font=fuente_sub, fill=GRIS)

    # Pista (rail) con tirador -----------------------------------------------------------------
    ry = y + 100
    rx0, rx1 = x + pad, x + ancho - pad
    d.rounded_rectangle([rx0, ry, rx1, ry + 10], 5, fill=LINEA)
    hx = rx0 + (rx1 - rx0) * max(0.0, min(1.0, fraccion))
    d.rounded_rectangle([rx0, ry, hx, ry + 10], 5, fill=color_relleno)
    if marca_extra is not None:
        mfrac, mtexto = marca_extra
        mx = rx0 + (rx1 - rx0) * mfrac
        d.line([mx, ry - 5, mx, ry + 15], fill=GRIS, width=2)
        fuente_m = F(NORM, 9)
        tw_m = ancho_texto(d, mtexto, fuente_m)
        d.text((mx - tw_m / 2, ry + 18), mtexto, font=fuente_m, fill=GRIS)
    d.ellipse([hx - 11, ry - 6, hx + 11, ry + 16], fill=TARJETA, outline=color_relleno, width=3)
    d.text((rx0, ry + 34 if marca_extra is None else ry + 34), min_label, font=F(NORM, 10), fill=GRIS)
    tw_max = ancho_texto(d, max_label, F(NORM, 10))
    d.text((rx1 - tw_max, ry + 34 if marca_extra is None else ry + 34), max_label,
           font=F(NORM, 10), fill=GRIS)

    # Consecuencia --------------------------------------------------------------------------------
    fuente_c = F(SEMI, 13)
    lineas = envolver_texto(d, consecuencia, fuente_c, ancho - pad * 2)
    cy = y + alto - pad - 4 - (len(lineas) - 1) * 16
    for linea in lineas:
        d.text((x + pad, cy), linea, font=fuente_c, fill=color_consecuencia)
        cy += 18


# ── Fila de ventanilla (checkbox "se queda por la tarde" + botón manual + detalle) ────────────
def casilla(d, x, y, lado, marcada):
    if marcada:
        d.rounded_rectangle([x, y, x + lado, y + lado], 5, fill=ACENTO)
        d.line([x + lado * 0.22, y + lado * 0.55, x + lado * 0.42, y + lado * 0.75], fill=(255, 255, 255), width=2)
        d.line([x + lado * 0.42, y + lado * 0.75, x + lado * 0.8, y + lado * 0.25], fill=(255, 255, 255), width=2)
    else:
        d.rounded_rectangle([x, y, x + lado, y + lado], 5, outline=(190, 196, 208), width=2)


def tarjeta_ventanilla(img, d, x, y, ancho, alto, nombre, operador, de_tarde, boton_txt,
                        boton_estilo, detalle, color_detalle):
    sombra_rect(img, (x, y, x + ancho, y + alto), 14)
    d.rounded_rectangle([x, y, x + ancho, y + alto], 14, fill=TARJETA)
    pad = 18

    casilla(d, x + pad, y + pad + 2, 20, de_tarde)
    d.text((x + pad + 30, y + pad - 3), nombre, font=F(SEMI, 15), fill=TINTA)

    fuente_b = F(SEMI, 11)
    bw = ancho_texto(d, boton_txt, fuente_b) + 26
    boton_pill(d, x + ancho - pad - bw, y + pad - 6, bw, 26, boton_txt, estilo=boton_estilo, tam=11)

    d.text((x + pad + 30, y + pad + 20), "Operada por %s" % operador, font=F(NORM, 10), fill=GRIS)
    d.text((x + pad, y + alto - pad - 14), detalle, font=F(SEMI, 11), fill=color_detalle)


# ══ Render principal ══════════════════════════════════════════════════════════════════════════
def render():
    img = cargar_base()
    W, H = img.size

    # Mismo tratamiento de fondo que maqueta_personal.py (conservado tal cual): desenfoque + velo,
    # chrome (barra de título) nítido.
    chrome = img.crop((0, 0, W, 34))
    img = img.filter(ImageFilter.GaussianBlur(7))
    img.paste(chrome, (0, 0))
    velo = Image.new("RGBA", img.size, (10, 14, 24, 205))
    img.alpha_composite(velo)

    d = ImageDraw.Draw(img, "RGBA")

    # ── Marco del modal (mismas medidas que Personal — pantallas hermanas) ──────────────────
    MX0, MY0, MX1, MY1 = 48, 40, W - 48, H - 40
    sombra_rect(img, (MX0, MY0, MX1, MY1), 22, alfa=60, blur=14, offset=(0, 8))
    d.rounded_rectangle([MX0, MY0, MX1, MY1], 22, fill=PANEL)

    pad = 32
    ix0, iy0, ix1, iy1 = MX0 + pad, MY0 + pad, MX1 - pad, MY1 - pad

    # ── Datos del escenario retratado (ver cabecera del script para la fuente de cada dato) ──
    apertura_base_min = 480          # 08:00 (Documentacion.apertura_base_min, default)
    cierre_base_min = 870            # 14:30 (default)
    slider_max_min = 1200            # 20:00 — tope ORDINARIO (default)
    tope_evento_min = 1290           # 21:30 — datos/eventos/vacaciones.tres (cierre_max_min default)
    tope_autorizado = max(slider_max_min, tope_evento_min)   # 1290
    hora_cierre_min = 1020           # 17:00 — decisión del jugador en este escenario
    margen_min = 15                  # default de catálogo
    hora_ultima_admision = max(apertura_base_min, hora_cierre_min - margen_min)   # 16:45
    horas_extra = max(0.0, (hora_cierre_min - cierre_base_min) / 60.0)            # 2.5 h
    num_agentes_doc = 1              # solo DNI 1 dotado Y de tarde
    peonada_eur_hora_min, peonada_eur_hora_max = 15.0, 30.0
    peonada_eur_hora = 22.0
    coste_peonada_dia = peonada_eur_hora * horas_extra * num_agentes_doc          # 55 €/día
    generosidad = (peonada_eur_hora - peonada_eur_hora_min) / (peonada_eur_hora_max - peonada_eur_hora_min)
    recargo = 1.5 + (1.0 - 1.5) * generosidad
    minuto_actual = 1010             # 16:50 — dentro de la franja CERRANDO

    def hhmm(m):
        return "%02d:%02d" % (int(m // 60) % 24, int(m % 60))

    # estado_servicio() real: CERRADO / CERRANDO / ABIERTO
    if minuto_actual < apertura_base_min or minuto_actual >= hora_cierre_min:
        estado, color_estado = "CERRADA", GRIS
        texto_estado = "Ahora: CERRADA — abre a las %s" % hhmm(apertura_base_min)
    elif minuto_actual >= hora_ultima_admision:
        estado, color_estado = "CERRANDO", AMBAR_TEXTO
        texto_estado = "Ahora: CERRANDO — ya no se da número; se termina a los admitidos"
    else:
        estado, color_estado = "ABIERTA", VERDE
        texto_estado = "Ahora: ABIERTA — dando número (hasta las %s)" % hhmm(hora_ultima_admision)

    nivel_demanda, color_demanda = "ALTA", ROJO
    consejo_demanda = "hay cola de sobra: alargar suele compensar"

    # ── Cabecera ──────────────────────────────────────────────────────────────────────────────
    d.text((ix0, iy0), "Horario", font=F(BOLD, 24), fill=TINTA)
    d.text((ix0, iy0 + 32), "Documentación — decide cuándo cierra el servicio y cuánto cuesta",
           font=F(NORM, 12), fill=GRIS)

    cerrar_txt = "Cerrar (H)"
    fuente_c = F(SEMI, 12)
    tw = ancho_texto(d, cerrar_txt, fuente_c)
    bw = tw + 34
    boton_pill(d, ix1 - bw, iy0 + 2, bw, 30, cerrar_txt, estilo="secundario", tam=12)

    y_ctx = iy0 + 58
    punto_texto(d, ix0, y_ctx + 8, texto_estado, color_estado, color_texto=TINTA, tam=14)
    punto_texto(d, ix0, y_ctx + 34, "Demanda %s — %s" % (nivel_demanda, consejo_demanda),
                color_demanda, color_texto=TINTA, tam=13)

    # Comunicado de la División (dato real de catálogo: datos/eventos/vacaciones.tres) ------------
    y_banner = y_ctx + 58
    banner_h = 44
    d.rounded_rectangle([ix0, y_banner, ix1, y_banner + banner_h], 12, fill=ACENTO_SUAVE)
    d.rounded_rectangle([ix0, y_banner, ix0 + 4, y_banner + banner_h], 2, fill=ACENTO)
    d.text((ix0 + 18, y_banner + 7), "COMUNICADO DE LA DIVISIÓN · Periodo vacacional",
           font=F(BOLD, 11), fill=ACENTO)
    d.text((ix0 + 18, y_banner + 24),
           "Pico de pasaportes — autoriza ampliar el horario hasta las 21:30 (tope ordinario: 20:00).",
           font=F(NORM, 11), fill=TINTA)

    y_div = y_banner + banner_h + 20
    d.line([ix0, y_div, ix1, y_div], fill=LINEA, width=1)

    # ── Dos columnas: controles grandes (izq.) / ventanillas de tarde (der.) ────────────────
    y_col = y_div + 22
    gap_col = 26
    ancho_izq = 940
    ancho_der = (ix1 - ix0) - ancho_izq - gap_col
    x_izq = ix0
    x_der = x_izq + ancho_izq + gap_col

    d.text((x_izq, y_col), "LA DECISIÓN DEL DÍA", font=F(BOLD, 13), fill=TINTA)
    d.text((x_der, y_col), "VENTANILLAS DE TARDE", font=F(BOLD, 13), fill=TINTA)
    d.text((x_der, y_col + 20), "Solo se paga peonada por las que se quedan",
           font=F(NORM, 10), fill=GRIS)

    y_cards = y_col + 32

    # Tarjeta 1 — HORARIO DE CIERRE ----------------------------------------------------------------
    alto_ctrl = 172
    frac_cierre = (hora_cierre_min - cierre_base_min) / float(tope_autorizado - cierre_base_min)
    frac_tope_ordinario = (slider_max_min - cierre_base_min) / float(tope_autorizado - cierre_base_min)
    control_grande(
        img, d, x_izq, y_cards, ancho_izq, alto_ctrl,
        "HORARIO DE CIERRE",
        "Cierra a las %s" % hhmm(hora_cierre_min),
        "(jornada base %s · máximo autorizado hoy %s)" % (hhmm(cierre_base_min), hhmm(tope_autorizado)),
        frac_cierre, hhmm(cierre_base_min), hhmm(tope_autorizado),
        ("+%.1f h extra × %d agente%s  →  PEONADA %.0f €/día" % (horas_extra, num_agentes_doc, "" if num_agentes_doc == 1 else "s", coste_peonada_dia)).replace(".", ","),
        ROJO, color_relleno=AMBAR,
        marca_extra=(frac_tope_ordinario, "tope ordinario %s" % hhmm(slider_max_min)),
    )

    # Tarjeta 2 — PRECIO DE LA HORA EXTRA -----------------------------------------------------------
    y2 = y_cards + alto_ctrl + 20
    frac_precio = (peonada_eur_hora - peonada_eur_hora_min) / (peonada_eur_hora_max - peonada_eur_hora_min)
    # La mecanica real (personal.gd): pagar MEJOR cansa MENOS -- a convenio la hora extra cansa lo
    # maximo, al tope autorizado cansa como una normal. El texto lo cuenta en ese sentido (la
    # primera redaccion, "pagar mas -> cansa un 27% mas", se leia justo al reves).
    efecto_txt = (
        "A este precio la hora extra cansa como una normal" if recargo <= 1.01
        else "A este precio la hora extra cansa un %d %% más que una normal · al tope (%.0f €) cansaría como una normal"
        % (round((recargo - 1.0) * 100.0), peonada_eur_hora_max)
    )
    color_efecto = GRIS if generosidad < 0.5 else VERDE
    control_grande(
        img, d, x_izq, y2, ancho_izq, alto_ctrl,
        "PRECIO DE LA HORA EXTRA",
        "%.0f €/hora" % peonada_eur_hora,
        "(convenio %.0f € · tope %.0f €)" % (peonada_eur_hora_min, peonada_eur_hora_max),
        frac_precio, "%.0f €" % peonada_eur_hora_min, "%.0f €" % peonada_eur_hora_max,
        efecto_txt, color_efecto, color_relleno=ACENTO,
    )

    # Tarjeta 3 — ÚLTIMA ADMISIÓN --------------------------------------------------------------------
    y3 = y2 + alto_ctrl + 20
    frac_margen = margen_min / 30.0
    control_grande(
        img, d, x_izq, y3, ancho_izq, alto_ctrl,
        "ÚLTIMA ADMISIÓN — hasta cuándo se da número",
        hhmm(hora_ultima_admision),
        "se deja de dar número %d min antes de cerrar" % margen_min,
        frac_margen, "0 min (exprimir)", "30 min (cuidar)",
        "Margen alto = tu gente sale a su hora. Margen 0 = más trámites, pero quien se queda "
        "terminando fuera de hora se desmotiva.",
        GRIS, color_relleno=ACENTO,
    )

    # ── Columna derecha: ventanillas de tarde ────────────────────────────────────────────────
    alto_vent = 96
    tarjeta_ventanilla(
        img, d, x_der, y_cards, ancho_der, alto_vent,
        "DNI 1", "Elena Ortiz", True, "Cerrar", "peligro",
        "%.0f €/día de peonada" % coste_peonada_dia, ROJO,
    )
    y_v2 = y_cards + alto_vent + 16
    tarjeta_ventanilla(
        img, d, x_der, y_v2, ancho_der, alto_vent,
        "DNI 2", "Rubén Paz", False, "Abrir", "secundario",
        "cierra a las %s" % hhmm(cierre_base_min), GRIS,
    )

    # Resumen del coste total (refuerza la consecuencia — pedido explícito del encargo) -----------
    y_total = y_v2 + alto_vent + 20
    alto_total = 78
    sombra_rect(img, (x_der, y_total, x_der + ancho_der, y_total + alto_total), 14, alfa=22)
    d.rounded_rectangle([x_der, y_total, x_der + ancho_der, y_total + alto_total], 14, fill=ROJO_SUAVE)
    d.text((x_der + 18, y_total + 14), "COSTE TOTAL DE PEONADA HOY", font=F(BOLD, 11), fill=ROJO)
    d.text((x_der + 18, y_total + 34), "%.0f €/día" % coste_peonada_dia, font=F(BOLD, 22), fill=ROJO)

    salida = os.path.join(SCRATCH, "maqueta_horario.png")
    img.convert("RGB").save(salida)
    print("OK ->", salida, img.size)


if __name__ == "__main__":
    render()
