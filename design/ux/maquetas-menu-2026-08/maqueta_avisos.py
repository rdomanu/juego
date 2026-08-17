# Maqueta del SISTEMA DE AVISOS (toasts) — última pieza de la interfaz moderna. Mismo lenguaje que
# las hermanas ya aprobadas (`maqueta_ventanilla.py`/`maqueta_hud_v3.py`/`kit_ui_comisario.gd`):
# tarjetas blancas, sombra suave, esquinas muy redondeadas, un único acento azul.
#
# ══ MAPEO señal→aviso (semilla de la spec) ═══════════════════════════════════════════════════════
# Fuente: src/foundation/event_bus/event_bus.gd (comentarios "Emisor:"/"Oyentes:" de cada señal) +
# quién la emite hoy (grep `.emit(` en src/). Solo entra lo que el JUGADOR necesita saber SIN estar
# mirando el sitio exacto donde pasó — un cambio de turno o de velocidad se VE en el HUD (el reloj y
# el segmento activo ya lo dicen), así que NO es un aviso; una reclamación o un impago si no se
# avisan, el jugador nunca se entera hasta que ya es tarde.
#
#   SÍ llevan toast (con su severidad):
#   - entro_en_deuda(saldo)          → CRÍTICO, persistente (no se autodesvanece: sigue en deuda
#                                       hasta `salio_de_deuda`, así que el aviso tampoco debe irse solo)
#   - insolvencia(saldo, prestamos)  → CRÍTICO, persistente (bloquea el juego con un modal — el toast
#                                       es el eco que queda si el jugador ya cerró el modal)
#   - gracia_iniciada(minutos)       → CRÍTICO, persistente (cuenta atrás activa)
#   - game_over(motivo)              → CRÍTICO, persistente (aunque en la práctica lo tapa la pantalla
#                                       de fin — se deja mapeado por completitud)
#   - salio_de_deuda(saldo)          → AVISO, auto-desvanecido (buena noticia, pero merece más que un
#                                       parpadeo de INFO: cierra una alarma que estuvo activa)
#   - reclamacion_generada(origen)   → AVISO, auto-desvanecido (queja real de un ciudadano — el chip
#                                       "Satisfacción" del HUD ya arrastra el contador, el toast es el
#                                       instante en que ocurrió)
#   - parte_personal(resumen)        → AVISO si resumen.escaladas > 0 (requiere decisión), si no INFO
#   - aviso_division(evento,on)      → INFO, auto-desvanecido (comunicado informativo, no urgente)
#   - incidencia_personal(texto,..)  → INFO, auto-desvanecido (una baja concreta; si el Oficial la
#                                       agrupa, va como `parte_personal` y esta no se duplica)
#   - prestamo_pedido(usados,vivos)  → AVISO, auto-desvanecido (no es una alarma nueva -- ya venías de
#                                       `insolvencia`-- pero el jugador debe ver cuántos salvavidas le
#                                       quedan)
#   - nivel_demanda_cambiado(nivel)  → NO usa toast: el chip "Demanda" del HUD YA es el indicador
#                                       permanente (spec HUD "brújula futura de la peonada"); un toast
#                                       duplicaría la misma información sin aportar nada nuevo.
#
#   NO llevan toast (ya se ven en el HUD/mundo, o son demasiado frecuentes para interrumpir):
#   - cambio_de_turno / cambio_dia_noche / velocidad_cambiada  → el reloj y el segmento activo del
#     HUD YA lo muestran en todo momento; un toast por cada uno saturaría la pila sin decir nada nuevo.
#   - saldo_cambiado / tramite_completado / persona_generada / abandono → ocurren muchas veces por
#     minuto (cada trámite, cada persona) — el chip de Satisfacción/Saldo del HUD agrega el dato; un
#     toast por CADA abandono sería ruido, no aviso (el resumen agregado si acaso saldría en un parte).
#
# ══ SEVERIDAD → forma+color (icono SIEMPRE, nunca solo el color — accesibilidad transversal) ═════
#   INFO     → círculo "i", acento suave (mismo azul único del kit) — auto-desvanecido rápido.
#   AVISO    → globo de diálogo con "!", ámbar — auto-desvanecido, algo más lento que INFO.
#   CRÍTICO  → triángulo de alerta, rojo — PERSISTENTE (no se autodesvanece), con botón "×" propio:
#              exige acción/lectura del jugador, no puede desaparecer solo.
#
# ══ POSICIÓN ═══════════════════════════════════════════════════════════════════════════════════
# Ancla arriba-DERECHA, bajo la barra flotante del HUD (mismo margen de 12px que ya usa esa barra) —
# es el rincón donde ya mira el jugador para el reloj/saldo, y dónde Los Sims/Two Point Campus ponen
# sus notificaciones. Ancho de columna 380px (deliberadamente MENOR que los 460px de la ficha de
# ventanilla: la pila de avisos no necesita tanto aire como una ficha de datos, y así deja hueco).
#
# CONVIVENCIA CON LA FICHA DE VENTANILLA (`panel_ventanilla.gd`, ancla derecha, 460px, y0=16..H-100,
# "implementada ya"): si la pila de avisos usara la MISMA esquina derecha con su propio ancho, con la
# ficha abierta invadiría su columna. Solución retratada abajo: con la ficha abierta, la pila de
# avisos se DESPLAZA a la izquierda del borde de la ficha, con el mismo margen de 12px que usa el
# borde derecho de pantalla, pero aplicado al borde IZQUIERDO de la ficha — nunca se solapan, y el
# jugador sigue viendo ambas cosas sin que ninguna tape a la otra. (La pila arranca en y=88, bajo el
# cuerpo entero del HUD -- ver Y0 más abajo; la ficha arranca en y=16 porque ya solapaba la altura del
# HUD antes de esta pieza, comportamiento heredado que esta maqueta no toca.)
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# Fondo real: la misma captura que usan las hermanas F3 (`maqueta_ventanilla.py`/`maqueta_horario.py`)
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
AMBAR = (240, 158, 44)
AMBAR_TEXTO = (181, 112, 15)
AMBAR_SUAVE = (252, 238, 219)
ROJO = (226, 88, 82)
ROJO_SUAVE = (250, 227, 225)
GRIS_SUAVE = (231, 233, 237)


def F(nombre, tam):
    return ImageFont.truetype(os.path.join(F_DIR, nombre), tam)


NORM, SEMI, BOLD = "segoeui.ttf", "seguisb.ttf", "segoeuib.ttf"


def sombra_rect(img, caja, radio, alfa=26, blur=8, offset=(0, 3)):
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    x0, y0, x1, y1 = caja
    d.rounded_rectangle([x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
                         radio, fill=(10, 14, 24, alfa))
    img.alpha_composite(capa.filter(ImageFilter.GaussianBlur(blur)))


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


def texto_centrado_v(d, xy, texto, fuente, fill, alto_caja):
    x, y = xy
    bbox = d.textbbox((0, 0), texto, font=fuente)
    h = bbox[3] - bbox[1]
    d.text((x, y - h / 2 - bbox[1]), texto, font=fuente, fill=fill)


# ── Iconos de severidad (vectoriales, mismo lenguaje de trazo que GlifoModerno: círculo/globo/
# triángulo — forma DISTINTA por severidad, nunca solo el color) ──────────────────────────────────
def icono_info(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=2)
    d.ellipse([cx - 1.6, cy - r * 0.42, cx + 1.6, cy - r * 0.42 + 3.2], fill=color)
    d.line([cx, cy - r * 0.05, cx, cy + r * 0.5], fill=color, width=2)


def icono_aviso(d, cx, cy, r, color):
    # globo de diálogo: rectángulo redondeado + colita, con "!" dentro
    caja = [cx - r, cy - r * 0.85, cx + r, cy + r * 0.55]
    d.rounded_rectangle(caja, r * 0.35, outline=color, width=2)
    d.polygon([(cx - r * 0.25, cy + r * 0.5), (cx + r * 0.15, cy + r * 0.5), (cx - r * 0.05, cy + r * 1.05)],
              fill=color)
    d.line([cx, cy - r * 0.5, cx, cy + r * 0.02], fill=color, width=2)
    d.ellipse([cx - 1.6, cy + r * 0.18, cx + 1.6, cy + r * 0.18 + 3.2], fill=color)


def icono_critico(d, cx, cy, r, color):
    d.polygon([(cx, cy - r), (cx - r * 0.95, cy + r * 0.8), (cx + r * 0.95, cy + r * 0.8)],
               outline=color, width=2)
    d.line([cx, cy - r * 0.32, cx, cy + r * 0.22], fill=color, width=2)
    d.ellipse([cx - 1.7, cy + r * 0.42, cx + 1.7, cy + r * 0.42 + 3.4], fill=color)


def cerrar_x(d, cx, cy, lado, color):
    d.line([cx - lado, cy - lado, cx + lado, cy + lado], fill=color, width=2)
    d.line([cx + lado, cy - lado, cx - lado, cy + lado], fill=color, width=2)


# ── Una tarjeta de aviso ───────────────────────────────────────────────────────────────────────
# severidad: "info" | "aviso" | "critico". `persistente` dibuja el botón "×" (solo lo lleva CRÍTICO,
# el resto se autodesvanece: NO necesita cierre manual). `barra_tiempo` (0..1, solo INFO/AVISO):
# raya fina de progreso que se agota — pista visual de "esto va a irse solo", nunca la única señal
# (el propio dato de severidad ya está en forma+color+texto; la barra es un extra, no lo esencial).
def tarjeta_aviso(img, d, x0, y0, ancho, severidad, titulo, subtitulo, persistente=False, barra_tiempo=None):
    ICONOS = {"info": icono_info, "aviso": icono_aviso, "critico": icono_critico}
    COLORES = {"info": ACENTO, "aviso": AMBAR_TEXTO, "critico": ROJO}
    FONDOS_ICONO = {"info": ACENTO_SUAVE, "aviso": AMBAR_SUAVE, "critico": ROJO_SUAVE}
    color = COLORES[severidad]
    fondo_icono = FONDOS_ICONO[severidad]

    pad = 16
    icono_lado = 40
    x_texto = x0 + pad + icono_lado + 12
    ancho_texto_max = ancho - pad - icono_lado - 12 - pad - (22 if persistente else 0)

    fnt_titulo = F(SEMI, 14)
    fnt_sub = F(NORM, 12)
    lineas_titulo = envolver_texto(d, titulo, fnt_titulo, ancho_texto_max)
    lineas_sub = envolver_texto(d, subtitulo, fnt_sub, ancho_texto_max) if subtitulo else []

    alto_texto = len(lineas_titulo) * 19 + (4 + len(lineas_sub) * 17 if lineas_sub else 0)
    alto_min_icono = icono_lado + pad
    alto_contenido = max(alto_texto, alto_min_icono)
    alto_barra = 6 if barra_tiempo is not None else 0
    alto = pad + alto_contenido + pad + alto_barra

    caja = (x0, y0, x0 + ancho, y0 + alto)
    sombra_rect(img, caja, 16, alfa=(46 if severidad == "critico" else 34), blur=10, offset=(0, 4))
    d.rounded_rectangle(caja, 16, fill=TARJETA)
    if severidad == "critico":
        # borde fino rojo -- el respaldo de "esto sigue activo" además del icono/color del texto.
        d.rounded_rectangle(caja, 16, outline=ROJO, width=2)

    # Icono en su pastilla circular de color suave.
    cx_icono = x0 + pad + icono_lado / 2
    cy_icono = y0 + pad + icono_lado / 2
    d.ellipse([cx_icono - icono_lado / 2, cy_icono - icono_lado / 2,
               cx_icono + icono_lado / 2, cy_icono + icono_lado / 2], fill=fondo_icono)
    ICONOS[severidad](d, cx_icono, cy_icono, icono_lado * 0.28, color)

    y_texto = y0 + pad
    for linea in lineas_titulo:
        d.text((x_texto, y_texto), linea, font=fnt_titulo, fill=TINTA)
        y_texto += 19
    if lineas_sub:
        y_texto += 2
        for linea in lineas_sub:
            d.text((x_texto, y_texto), linea, font=fnt_sub, fill=GRIS)
            y_texto += 17

    if persistente:
        cerrar_x(d, x0 + ancho - pad - 6, y0 + pad + 6, 5, GRIS)
        etiqueta = "Persistente"
        fnt_p = F(SEMI, 9)
        tw = ancho_texto(d, etiqueta, fnt_p)
        d.text((x0 + ancho - pad - tw, y0 + alto - alto_barra - 15), etiqueta, font=fnt_p, fill=GRIS)

    if barra_tiempo is not None:
        y_barra = y0 + alto - alto_barra - 2
        d.rounded_rectangle([x0 + pad, y_barra, x0 + ancho - pad, y_barra + 3], 2, fill=LINEA)
        hx = x0 + pad + (ancho - 2 * pad) * max(0.0, min(1.0, barra_tiempo))
        d.rounded_rectangle([x0 + pad, y_barra, hx, y_barra + 3], 2, fill=color)

    return y0 + alto


# ── Ficha de ventanilla ABREVIADA (solo lo justo para retratar la convivencia; el detalle completo
# ya lo prueba `maqueta_ventanilla.py` — no se duplica aquí) ───────────────────────────────────────
def ficha_ventanilla_abreviada(img, d, W, H):
    px0, py0 = W - 476, 16
    px1, py1 = W - 16, H - 100
    sombra_rect(img, (px0, py0, px1, py1), 20, alfa=50, blur=12, offset=(0, 6))
    d.rounded_rectangle([px0, py0, px1, py1], 20, fill=PANEL)
    pad = 24
    x0, x1 = px0 + pad, px1 - pad
    y = py0 + 22
    d.text((x0, y), "Ventanilla Documentación", font=F(BOLD, 18), fill=TINTA)
    lado_x = 30
    bx, by = px1 - pad - lado_x, y - 2
    d.rounded_rectangle([bx, by, bx + lado_x, by + lado_x], 8, fill=TARJETA, outline=LINEA, width=1)
    d.line([bx + 9, by + 9, bx + lado_x - 9, by + lado_x - 9], fill=GRIS, width=2)
    d.line([bx + lado_x - 9, by + 9, bx + 9, by + lado_x - 9], fill=GRIS, width=2)
    y += 30
    d.ellipse([x0, y + 4, x0 + 10, y + 14], fill=VERDE)
    d.text((x0 + 18, y), "DNI 1 · ATENDIENDO", font=F(SEMI, 12), fill=GRIS)
    y += 32
    d.line([x0, y, x1, y], fill=LINEA, width=1)
    y += 18
    d.text((x0, y), "AHORA MISMO", font=F(BOLD, 10), fill=GRIS)
    y += 24
    d.text((x0, y), "DNI · Turno nº 47", font=F(SEMI, 15), fill=TINTA)
    y += 26
    d.text((x0, y), "Quedan 8 min de trámite", font=F(SEMI, 13), fill=VERDE)
    y += 40
    d.line([x0, y, x1, y], fill=LINEA, width=1)
    y += 40
    d.text((x0, y), "(resto de la ficha: ver maqueta_ventanilla.py)", font=F(NORM, 11), fill=GRIS)
    return px0


def render():
    img = Image.open(FONDO).convert("RGBA")
    W, H = img.size
    d = ImageDraw.Draw(img, "RGBA")

    MARGEN = 12
    ANCHO_PILA = 380
    # A diferencia de la ficha de ventanilla (que arranca en y=16, solapando la propia altura de la
    # barra flotante del HUD -- comportamiento YA implementado y aceptado en panel_ventanilla.gd), la
    # pila de avisos es pieza NUEVA: se ancla estrictamente POR DEBAJO del HUD (12+64+12=88 -- mismo
    # margen de 12px que ya usa la barra flotante) para no tapar NUNCA un chip mientras lees un aviso.
    # 116 y no 88: la barra flotante del HUD llega hasta y~104 (12 de margen + 92 de tarjeta)
    # y con 88 el toast critico pisaba la franja baja de los chips Plantilla/Doc
    # (auditoria de Fable, 2026-08-18).
    Y0 = 116

    # 1) Ficha de ventanilla abierta primero (queda DEBAJO en z-order si algo llegara a rozarse,
    #    aunque con el desplazamiento no debería pasar nunca).
    borde_izq_ficha = ficha_ventanilla_abreviada(img, d, W, H)
    d = ImageDraw.Draw(img, "RGBA")

    # 2) Pila de avisos DESPLAZADA a la izquierda del borde de la ficha (convivencia, ver cabecera).
    x0 = borde_izq_ficha - MARGEN - ANCHO_PILA

    y = Y0
    y = tarjeta_aviso(
        img, d, x0, y, ANCHO_PILA, "critico",
        "Saldo en números rojos",
        "−1.240 € · gasto voluntario bloqueado hasta salir de deuda",
        persistente=True,
    )
    d = ImageDraw.Draw(img, "RGBA")
    y += 12
    y = tarjeta_aviso(
        img, d, x0, y, ANCHO_PILA, "aviso",
        "Nueva reclamación",
        "Documentación · por una espera larga",
        barra_tiempo=0.55,
    )
    d = ImageDraw.Draw(img, "RGBA")
    y += 12
    y = tarjeta_aviso(
        img, d, x0, y, ANCHO_PILA, "info",
        "Elena Ortiz se va a descansar",
        "15 min · deja DNI 1",
        barra_tiempo=0.85,
    )
    d = ImageDraw.Draw(img, "RGBA")

    # Etiqueta de contexto (solo para la maqueta, no forma parte del HUD): marca el ancla de la pila.
    fnt_tag = F(SEMI, 11)
    txt = "PILA DE AVISOS — ancla derecha, bajo el HUD (desplazada al abrir la ficha)"
    tw = ancho_texto(d, txt, fnt_tag)
    tag_x0, tag_y0 = x0, y + 14
    d.rounded_rectangle([tag_x0, tag_y0, tag_x0 + tw + 20, tag_y0 + 26], 13, fill=(*TINTA, 210))
    d = ImageDraw.Draw(img, "RGBA")
    texto_centrado_v(d, (tag_x0 + 10, tag_y0 + 13), txt, fnt_tag, (255, 255, 255), 26)

    salida = os.path.join(SCRATCH, "maqueta_avisos.png")
    img.convert("RGB").save(salida)
    print("OK ->", salida, img.size, "pila x0:", x0, "ficha borde izq:", borde_izq_ficha, "y final:", y)


if __name__ == "__main__":
    render()
