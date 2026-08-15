# Tres VARIACIONES de dirección de arte del menú de construcción, sobre la captura real.
# A) EXPEDIENTE (papel kraft, pestañas de carpeta, sello)  B) CENTRAL DE MANDO (HUD táctico
# nocturno, chaflanes, cian/ámbar)  C) JUGUETE (Two Point: bordes gordos, sombra dura, caramelo).
# Regla de la casa: ningún texto cortado (texto_ajustado reduce fuente hasta caber).
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, random

MOB = r"C:\Users\manur\juego\assets\sprites\mobiliario"
SCRATCH = r"C:\Users\manur\AppData\Local\Temp\claude\C--Users-manur-juego\aad5e0e0-a0be-4878-b068-20ca5cee13c8\scratchpad"
FUENTES = r"C:\Windows\Fonts"

def fuente(nombre, tam, alternativas=()):
    for n in (nombre,) + tuple(alternativas):
        ruta = os.path.join(FUENTES, n)
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tam)
    return ImageFont.truetype(os.path.join(FUENTES, "arialbd.ttf"), tam)

def texto_ajustado(d, xy, txt, fnombre, tam, color, max_w, alternativas=()):
    while tam > 8:
        f = fuente(fnombre, tam, alternativas)
        if d.textlength(txt, font=f) <= max_w:
            d.text(xy, txt, font=f, fill=color)
            return
        tam -= 1
    d.text(xy, txt, font=fuente(fnombre, 8, alternativas), fill=color)

def miniatura(png, lado):
    im = Image.open(os.path.join(MOB, png)).convert("RGBA")
    esc = min(lado / im.width, lado / im.height, 2.0)
    im = im.resize((max(1, int(im.width * esc)), max(1, int(im.height * esc))),
                   Image.NEAREST if esc >= 1 else Image.LANCZOS)
    marco = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    marco.alpha_composite(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    return marco

OBJETOS = [
    ("silla_espera_0.png", "Silla de espera", "25", "1 celda · 1 plaza", False),
    ("comodidad_silla_espera_madera_0.png", "Silla de madera", "25", "1 celda · 1 plaza", False),
    ("comodidad_banco_espera_basico_0.png", "Banco básico", "80", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_medio_0.png", "Banco acolchado", "150", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_pro_0.png", "Banco premium", "240", "1 celda · 2 plazas", True),
    ("comodidad_escritorio_trabajo_0.png", "Escritorio", "350", "1 celda", False),
    ("comodidad_estanteria_suelta_0.png", "Estantería", "120", "1 celda", False),
]
CATS = ["ASIENTOS", "ALMACENAJE", "EQUIPOS", "APARATOS", "DECORACIÓN"]

fondo = Image.open(os.path.join(SCRATCH, "fantasma_arrastre.png")).convert("RGB")
W, H = fondo.size
ALTO = 360
Y0 = H - ALTO


def guardar(img, nombre, titulo):
    lienzo = Image.new("RGB", (W, H + 46), (24, 24, 26))
    dl = ImageDraw.Draw(lienzo)
    dl.text((16, 12), titulo, font=fuente("arialbd.ttf", 18), fill=(240, 240, 240))
    lienzo.paste(img, (0, 46))
    lienzo.save(os.path.join(SCRATCH, nombre))
    print("OK", nombre)


# ══ A · EXPEDIENTE ═══════════════════════════════════════════════════════════
def variacion_expediente():
    img = fondo.copy().convert("RGBA")
    d = ImageDraw.Draw(img)
    KRAFT = (201, 172, 121); KRAFT_OSC = (176, 146, 96); PAPEL = (241, 233, 214)
    TINTA = (42, 48, 74); ROJO_SELLO = (178, 52, 46); LAPIZ = (110, 100, 82)
    # panel = carpeta kraft con lomo
    d.rectangle([0, Y0, W, H], fill=KRAFT)
    d.rectangle([0, Y0, W, Y0 + 8], fill=KRAFT_OSC)
    # textura de papel (moteado determinista)
    rnd = random.Random(7)
    for _ in range(2600):
        x, y = rnd.randint(0, W - 1), rnd.randint(Y0, H - 1)
        tono = rnd.choice([(0, 0, 0, 10), (255, 255, 255, 12)])
        d.point((x, y), fill=tono)
    # pestañas de carpeta (categorías)
    y_tab = Y0 + 14
    x = 16
    for i, c in enumerate(CATS):
        f = fuente("courbd.ttf", 15)
        wtx = d.textlength(c, font=f) + 34
        activa = i == 0
        col = PAPEL if activa else KRAFT_OSC
        d.polygon([(x, y_tab + 34), (x + 10, y_tab), (x + wtx - 10, y_tab),
                   (x + wtx, y_tab + 34)], fill=col, outline=TINTA)
        d.text((x + 18, y_tab + 8), c, font=f, fill=TINTA if activa else (80, 66, 44))
        x += wtx + 6
    # folio interior
    d.rectangle([16, y_tab + 34, W - 16, H - 14], fill=PAPEL, outline=TINTA, width=2)
    # cabecera del folio: buscador subrayado + presupuesto como anotación
    texto_ajustado(d, (36, y_tab + 48), "BUSCAR:", "courbd.ttf", 14, LAPIZ, 90)
    d.line([116, y_tab + 66, 420, y_tab + 66], fill=LAPIZ, width=2)
    texto_ajustado(d, (W - 320, y_tab + 46), "FONDOS: 3.000 €", "courbd.ttf", 17, TINTA, 280)
    # fichas de archivo
    x_g, y_g = 36, y_tab + 84
    CW, CH, GAP = 150, 168, 14
    for i, (png, nombre, precio, huella, sel) in enumerate(OBJETOS):
        cx = x_g + i * (CW + GAP)
        cy = y_g
        d.rectangle([cx + 3, cy + 3, cx + CW + 3, cy + CH + 3], fill=(0, 0, 0, 40))
        d.rectangle([cx, cy, cx + CW, cy + CH], fill=(252, 248, 238), outline=TINTA, width=2)
        d.line([cx, cy + 24, cx + CW, cy + 24], fill=(200, 60, 60), width=1)
        texto_ajustado(d, (cx + 8, cy + 5), nombre, "courbd.ttf", 13, TINTA, CW - 16)
        img.paste(miniatura(png, 78), (cx + (CW - 78) // 2, cy + 32), miniatura(png, 78))
        texto_ajustado(d, (cx + 8, cy + 116), precio + " €", "courbd.ttf", 16, ROJO_SELLO, CW - 16)
        texto_ajustado(d, (cx + 8, cy + 140), huella, "Inkfree.ttf", 15, LAPIZ, CW - 16, ("segoepr.ttf", "cour.ttf"))
        if sel:
            sello = Image.new("RGBA", (150, 60), (0, 0, 0, 0))
            ds = ImageDraw.Draw(sello)
            ds.rectangle([2, 2, 147, 57], outline=ROJO_SELLO, width=3)
            ds.text((14, 16), "ELEGIDO", font=fuente("courbd.ttf", 24), fill=ROJO_SELLO)
            sello = sello.rotate(9, expand=True)
            img.alpha_composite(sello, (cx + CW - 130, cy - 16))
    # herramientas: cajón de tampones a la derecha
    x_t = x_g + 7 * (CW + GAP) + 6
    for j, t in enumerate(["MANO", "CLONAR", "DEMOLER"]):
        y = y_g + j * 58
        d.rectangle([x_t, y, W - 36, y + 46], fill=KRAFT if t != "DEMOLER" else (214, 160, 150),
                    outline=TINTA, width=2)
        texto_ajustado(d, (x_t + 12, y + 12), t, "courbd.ttf", 15, TINTA, W - 52 - x_t)
    guardar(img.convert("RGB"), "menu_A_expediente.png",
            "VARIACIÓN A · EXPEDIENTE — carpeta kraft, fichas de archivo, sello y máquina de escribir")


# ══ B · CENTRAL DE MANDO ═════════════════════════════════════════════════════
def chaflan(d, caja, corte, **kw):
    x0, y0, x1, y1 = caja
    d.polygon([(x0 + corte, y0), (x1 - corte, y0), (x1, y0 + corte), (x1, y1 - corte),
               (x1 - corte, y1), (x0 + corte, y1), (x0, y1 - corte), (x0, y0 + corte)], **kw)

def variacion_central():
    img = fondo.copy().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    NOCHE = (10, 14, 20); PANEL = (17, 24, 33); LINEA = (42, 60, 76)
    CIAN = (86, 214, 228); AMBAR = (255, 176, 64); GRIS = (138, 156, 168)
    d.rectangle([0, Y0, W, H], fill=NOCHE)
    for y in range(Y0, H, 3):  # líneas de escaneo sutiles
        d.line([0, y, W, y], fill=(255, 255, 255, 5))
    d.rectangle([0, Y0, W, Y0 + 2], fill=CIAN)
    # cabecera
    y_top = Y0 + 12
    chaflan(d, (16, y_top, 330, y_top + 34), 10, fill=PANEL, outline=LINEA)
    texto_ajustado(d, (34, y_top + 8), "> buscar equipamiento_", "consola.ttf", 14, GRIS, 280)
    chaflan(d, (346, y_top, 610, y_top + 34), 10, fill=PANEL, outline=LINEA)
    texto_ajustado(d, (362, y_top + 8), "FUNCIÓN", "bahnschrift.ttf", 15, CIAN, 90)
    texto_ajustado(d, (480, y_top + 8), "SALA", "bahnschrift.ttf", 15, GRIS, 60)
    d.line([466, y_top + 6, 466, y_top + 28], fill=LINEA, width=2)
    chaflan(d, (W - 260, y_top, W - 16, y_top + 34), 10, fill=PANEL, outline=AMBAR)
    texto_ajustado(d, (W - 242, y_top + 8), "FONDOS  3.000 €", "bahnschrift.ttf", 15, AMBAR, 220)
    # categorías: fichas verticales con muesca
    x_c, y_c = 16, Y0 + 60
    for i, c in enumerate(CATS):
        y = y_c + i * 50
        activa = i == 0
        chaflan(d, (x_c, y, x_c + 170, y + 42), 8,
                fill=(26, 46, 54) if activa else PANEL,
                outline=CIAN if activa else LINEA)
        if activa:
            d.rectangle([x_c + 4, y + 8, x_c + 8, y + 34], fill=CIAN)
        texto_ajustado(d, (x_c + 18, y + 11), c, "bahnschrift.ttf", 15,
                       CIAN if activa else GRIS, 145)
    # rejilla
    x_g, y_g = 204, Y0 + 60
    CW, CH, GAP = 138, 140, 10
    for i, (png, nombre, precio, huella, sel) in enumerate(OBJETOS):
        cx = x_g + i * (CW + GAP)
        cy = y_g
        chaflan(d, (cx, cy, cx + CW, cy + CH), 12,
                fill=(24, 40, 46) if sel else PANEL,
                outline=CIAN if sel else LINEA)
        img.paste(miniatura(png, 68), (cx + (CW - 68) // 2, cy + 8), miniatura(png, 68))
        texto_ajustado(d, (cx + 10, cy + 82), nombre.upper(), "bahnschrift.ttf", 13,
                       (222, 234, 240), CW - 20)
        texto_ajustado(d, (cx + 10, cy + 102), precio + " €", "consolab.ttf", 15, AMBAR, CW - 20)
        texto_ajustado(d, (cx + 10, cy + 121), huella, "consola.ttf", 11, GRIS, CW - 20)
        if sel:
            texto_ajustado(d, (cx + 10, cy - 16), "\u25B8 SELECCIONADO", "bahnschrift.ttf", 12, CIAN, CW)
    # ficha inferior: banda de datos
    y_f = y_g + CH + 16
    chaflan(d, (204, y_f, W - 100, H - 14), 12, fill=PANEL, outline=CIAN)
    img.paste(miniatura("comodidad_banco_espera_pro_0.png", 64), (222, y_f + 12),
              miniatura("comodidad_banco_espera_pro_0.png", 64))
    texto_ajustado(d, (300, y_f + 10), "BANCO PREMIUM", "bahnschrift.ttf", 17, (230, 240, 244), 200)
    texto_ajustado(d, (300, y_f + 36), "240 € · 1 celda · 2 plazas", "consola.ttf", 13, GRIS, 260)
    datos = [("CONFORT", "7/7", CIAN), ("NOTA SALIDA", "+20%", CIAN), ("IMPACIENCIA", "-14%", AMBAR)]
    for j, (k, v, c) in enumerate(datos):
        x = 590 + j * 200
        texto_ajustado(d, (x, y_f + 10), k, "bahnschrift.ttf", 12, GRIS, 120)
        texto_ajustado(d, (x, y_f + 28), v, "consolab.ttf", 20, c, 120)
        d.line([x - 18, y_f + 10, x - 18, y_f + 52], fill=LINEA, width=2)
    texto_ajustado(d, (1190, y_f + 22), "MAYÚS = repetir", "consola.ttf", 13, AMBAR, 180)
    # herramientas
    for j, t in enumerate(["MANO", "CLONAR", "DEMOLER"]):
        y = Y0 + 60 + j * 92
        chaflan(d, (W - 84, y, W - 16, y + 80), 10,
                fill=(60, 22, 24) if t == "DEMOLER" else PANEL,
                outline=(230, 90, 90) if t == "DEMOLER" else LINEA)
        texto_ajustado(d, (W - 78, y + 32), t, "bahnschrift.ttf", 12,
                       (240, 160, 160) if t == "DEMOLER" else GRIS, 58)
    guardar(img.convert("RGB"), "menu_B_central.png",
            "VARIACIÓN B · CENTRAL DE MANDO — HUD táctico nocturno, chaflanes, cian y ámbar sodio")


# ══ C · JUGUETE ══════════════════════════════════════════════════════════════
def variacion_juguete():
    img = fondo.copy().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    CREMA = (250, 240, 219); TRAZO = (58, 48, 64); TURQ = (78, 196, 186)
    CORAL = (245, 126, 108); SOL = (255, 205, 84); BLANCO = (255, 252, 245)
    d.rectangle([0, Y0, W, H], fill=CREMA)
    # confeti de fondo
    rnd = random.Random(3)
    for _ in range(60):
        x, y = rnd.randint(0, W), rnd.randint(Y0 + 10, H)
        r = rnd.randint(2, 5)
        d.ellipse([x, y, x + r, y + r], fill=rnd.choice([(78,196,186,60), (245,126,108,60), (255,205,84,80)]))
    d.rectangle([0, Y0, W, Y0 + 6], fill=TRAZO)
    def carta(caja, color, radio=16, grosor=4, sombra=6):
        x0, y0, x1, y1 = caja
        d.rounded_rectangle([x0 + sombra, y0 + sombra, x1 + sombra, y1 + sombra], radio, fill=(58, 48, 64, 90))
        d.rounded_rectangle(caja, radio, fill=color, outline=TRAZO, width=grosor)
    # cabecera
    y_top = Y0 + 16
    carta((16, y_top, 320, y_top + 40), BLANCO)
    texto_ajustado(d, (34, y_top + 9), "¿Qué buscamos hoy?", "comicbd.ttf", 15, (140, 130, 150), 260, ("trebucbd.ttf",))
    carta((340, y_top, 600, y_top + 40), TURQ)
    texto_ajustado(d, (362, y_top + 9), "FUNCIÓN", "trebucbd.ttf", 16, BLANCO, 95)
    texto_ajustado(d, (486, y_top + 9), "SALA", "trebucbd.ttf", 16, (36, 110, 104), 70)
    carta((W - 250, y_top, W - 16, y_top + 40), SOL)
    texto_ajustado(d, (W - 232, y_top + 9), "HUCHA: 3.000 €", "trebucbd.ttf", 16, TRAZO, 210)
    # categorías: píldoras gorditas
    x_c, y_c = 16, Y0 + 74
    for i, c in enumerate(CATS):
        y = y_c + i * 52
        activa = i == 0
        carta((x_c, y, x_c + 170, y + 42), CORAL if activa else BLANCO, radio=21)
        texto_ajustado(d, (x_c + 18, y + 10), c, "trebucbd.ttf", 15, BLANCO if activa else TRAZO, 140)
    # rejilla
    x_g, y_g = 206, Y0 + 74
    CW, CH, GAP = 138, 150, 12
    for i, (png, nombre, precio, huella, sel) in enumerate(OBJETOS):
        cx = x_g + i * (CW + GAP)
        cy = y_g - (10 if sel else 0)
        carta((cx, cy, cx + CW, cy + CH), (255, 244, 214) if sel else BLANCO,
              radio=18, grosor=5 if sel else 4, sombra=9 if sel else 6)
        img.paste(miniatura(png, 72), (cx + (CW - 72) // 2, cy + 10), miniatura(png, 72))
        texto_ajustado(d, (cx + 10, cy + 88), nombre, "trebucbd.ttf", 14, TRAZO, CW - 20)
        # chapa de precio inclinada
        chapa = Image.new("RGBA", (74, 40), (0, 0, 0, 0))
        dc = ImageDraw.Draw(chapa)
        dc.rounded_rectangle([2, 2, 71, 37], 17, fill=SOL, outline=(58, 48, 64, 255), width=3)
        dc.text((12, 8), precio + "€", font=fuente("trebucbd.ttf", 17), fill=(58, 48, 64))
        chapa = chapa.rotate(-7, expand=True)
        img.alpha_composite(chapa, (cx + CW - 72, cy + CH - 44))
        texto_ajustado(d, (cx + 10, cy + 110), huella, "trebuc.ttf", 12, (150, 140, 155), CW - 84)
        if sel:
            texto_ajustado(d, (cx + 14, cy - 24), "\u2605 ¡ESTE!", "trebucbd.ttf", 16, CORAL, CW)
    # ficha inferior
    y_f = y_g + CH + 18
    carta((206, y_f, W - 104, H - 16), BLANCO)
    texto_ajustado(d, (226, y_f + 8), "Banco premium", "trebucbd.ttf", 17, TRAZO, 190)
    texto_ajustado(d, (226, y_f + 32), "los VIP de la sala de espera", "comicbd.ttf", 13, (150, 140, 155), 240, ("trebuc.ttf",))
    for j, (k, v, c) in enumerate([("CONFORT", "7/7", TURQ), ("NOTA", "+20%", TURQ), ("PACIENCIA", "+14%", CORAL)]):
        x = 500 + j * 180
        carta((x, y_f + 8, x + 156, y_f + 46), CREMA, radio=12, grosor=3, sombra=4)
        texto_ajustado(d, (x + 12, y_f + 15), k, "trebucbd.ttf", 13, TRAZO, 70)
        texto_ajustado(d, (x + 96, y_f + 13), v, "trebucbd.ttf", 17, c, 55)
    texto_ajustado(d, (1090, y_f + 18), "MAYÚS = ¡otro más!", "comicbd.ttf", 14, CORAL, 190, ("trebucbd.ttf",))
    # herramientas
    for j, (t, col) in enumerate([("MANO", TURQ), ("CLONAR", SOL), ("DEMOLER", CORAL)]):
        y = Y0 + 74 + j * 94
        carta((W - 88, y, W - 16, y + 80), col, radio=18)
        texto_ajustado(d, (W - 82, y + 30), t, "trebucbd.ttf", 13, BLANCO if col != SOL else TRAZO, 62)
    guardar(img.convert("RGB"), "menu_C_juguete.png",
            "VARIACIÓN C · JUGUETE — Two Point: bordes gordos, sombra dura, colores caramelo")


variacion_expediente()
variacion_central()
variacion_juguete()
