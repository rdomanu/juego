# MAQUETA v2 "MODERNO" — el lenguaje real de Two Point / Sims 4: panel claro, tarjetas blancas
# con sombra SUAVE difuminada, esquinas redondas, un acento azul policía, barras de progreso en
# la ficha, iconos de línea dibujados (no emoji). Sobre la captura real; sprites reales.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

MOB = r"C:\Users\manur\juego\assets\sprites\mobiliario"
SCRATCH = r"C:\Users\manur\AppData\Local\Temp\claude\C--Users-manur-juego\aad5e0e0-a0be-4878-b068-20ca5cee13c8\scratchpad"
F_DIR = r"C:\Windows\Fonts"

PANEL = (238, 243, 249)      # gris azulado muy claro
BLANCO = (255, 255, 255)
TINTA = (36, 48, 66)         # texto principal
GRIS = (122, 136, 156)       # texto secundario
LINEA = (222, 229, 238)
AZUL = (47, 108, 224)        # acento policía
AZUL_SUAVE = (232, 240, 254)
VERDE = (34, 160, 94)
AMBAR = (240, 158, 44)
ROJO = (226, 88, 82)

def F(n, t):
    return ImageFont.truetype(os.path.join(F_DIR, n), t)

SEMI = "seguisb.ttf"   # Segoe UI Semibold — el tono "juego moderno"
NORM = "segoeui.ttf"
BOLD = "segoeuib.ttf"

def texto(d, xy, s, fnt, tam, color, max_w=None):
    if max_w:
        while tam > 8 and d.textlength(s, font=F(fnt, tam)) > max_w:
            tam -= 1
    d.text(xy, s, font=F(fnt, tam), fill=color)

def miniatura(png, lado):
    im = Image.open(os.path.join(MOB, png)).convert("RGBA")
    esc = min(lado / im.width, lado / im.height, 2.0)
    im = im.resize((max(1, int(im.width * esc)), max(1, int(im.height * esc))),
                   Image.NEAREST if esc >= 1 else Image.LANCZOS)
    marco = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    marco.alpha_composite(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    return marco

fondo = Image.open(os.path.join(SCRATCH, "fondo_v3.png")).convert("RGB")
W, H = fondo.size
ALTO = 360
Y0 = H - ALTO
img = fondo.copy().convert("RGBA")

# capa de sombras difuminadas (se pinta antes que las tarjetas)
sombras = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sombras)
def sombra_suave(caja, radio, alpha=46, dy=4):
    x0, y0, x1, y1 = caja
    ds.rounded_rectangle([x0, y0 + dy, x1, y1 + dy], radio, fill=(30, 45, 70, alpha))

CARTAS = []   # (caja, radio, fill, outline, width)
def carta(caja, radio, fill=BLANCO, outline=None, width=1, alpha=46, dy=4):
    sombra_suave(caja, radio, alpha, dy)
    CARTAS.append((caja, radio, fill, outline, width))

# ── composición ──────────────────────────────────────────────────────────────
# panel base con "hombro" redondeado que se solapa 14px sobre el juego
carta((-20, Y0 - 14, W + 20, H + 30), 22, PANEL, None, 0, alpha=70, dy=-6)

y_top = Y0 + 10
carta((16, y_top, 320, y_top + 38), 19)                       # buscador
carta((336, y_top, 566, y_top + 38), 19)                      # toggle

x_cat, y_cat = 16, Y0 + 64
for i in range(5):
    y = y_cat + i * 50
    carta((x_cat, y, x_cat + 172, y + 42), 21,
          AZUL if i == 0 else BLANCO)

x_g, y_g = 204, Y0 + 64
CW, CH, GAP = 136, 148, 12
OBJ = [
    ("silla_espera_0.png", "Silla de espera", "25 €", "1 celda · 1 plaza", False),
    ("comodidad_silla_espera_madera_0.png", "Silla de madera", "25 €", "1 celda · 1 plaza", False),
    ("comodidad_banco_espera_basico_0.png", "Banco básico", "80 €", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_medio_0.png", "Banco acolchado", "150 €", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_pro_0.png", "Banco premium", "240 €", "1 celda · 2 plazas", True),
    ("comodidad_escritorio_trabajo_0.png", "Escritorio", "350 €", "1 celda", False),
    ("comodidad_estanteria_suelta_0.png", "Estantería", "120 €", "1 celda", False),
]
for i, (_, _, _, _, sel) in enumerate(OBJ):
    cx = x_g + i * (CW + GAP)
    cy = y_g - (6 if sel else 0)
    carta((cx, cy, cx + CW, cy + CH), 16, BLANCO,
          AZUL if sel else None, 3 if sel else 0,
          alpha=70 if sel else 46, dy=7 if sel else 4)

x_f = x_g + 7 * (CW + GAP) + 4          # ficha derecha
carta((x_f, Y0 + 64, W - 100, H - 18), 16)
for j in range(3):                        # herramientas circulares
    y = Y0 + 70 + j * 92
    carta((W - 84, y, W - 20, y + 64), 32)

# pintar sombras difuminadas y luego las cartas
img.alpha_composite(sombras.filter(ImageFilter.GaussianBlur(7)))
d = ImageDraw.Draw(img, "RGBA")
for caja, radio, fill, outline, width in CARTAS:
    d.rounded_rectangle(caja, radio, fill=fill,
                        outline=outline, width=width if outline else 0)

# ── contenido ────────────────────────────────────────────────────────────────
# buscador con lupa dibujada
d.ellipse([32, y_top + 11, 46, y_top + 25], outline=GRIS, width=2)
d.line([44, y_top + 24, 52, y_top + 31], fill=GRIS, width=2)
texto(d, (62, y_top + 8), "Buscar mueble", NORM, 15, GRIS, 240)
# toggle con "pastilla" activa
d.rounded_rectangle([341, y_top + 4, 452, y_top + 34], 16, fill=AZUL_SUAVE)
texto(d, (362, y_top + 9), "Función", SEMI, 15, AZUL, 90)
texto(d, (486, y_top + 9), "Sala", SEMI, 15, GRIS, 60)

# categorías con icono de línea + rótulo
def icono_cat(cx, cy, tipo, color):
    if tipo == "asiento":
        d.rounded_rectangle([cx, cy + 8, cx + 16, cy + 15], 2, outline=color, width=2)
        d.line([cx + 2, cy + 8, cx + 2, cy], fill=color, width=2)
        d.line([cx + 2, cy + 15, cx + 2, cy + 19], fill=color, width=2)
        d.line([cx + 14, cy + 15, cx + 14, cy + 19], fill=color, width=2)
    elif tipo == "caja":
        d.rounded_rectangle([cx, cy + 4, cx + 16, cy + 18], 2, outline=color, width=2)
        d.line([cx, cy + 9, cx + 16, cy + 9], fill=color, width=2)
    elif tipo == "monitor":
        d.rounded_rectangle([cx, cy + 3, cx + 16, cy + 14], 2, outline=color, width=2)
        d.line([cx + 5, cy + 17, cx + 11, cy + 17], fill=color, width=2)
    elif tipo == "taza":
        d.rounded_rectangle([cx, cy + 6, cx + 12, cy + 17], 3, outline=color, width=2)
        d.arc([cx + 11, cy + 8, cx + 17, cy + 14], -80, 80, fill=color, width=2)
    elif tipo == "planta":
        d.arc([cx + 1, cy + 2, cx + 15, cy + 16], 200, 340, fill=color, width=2)
        d.line([cx + 8, cy + 8, cx + 8, cy + 18], fill=color, width=2)
CATS = [("asiento", "Asientos"), ("caja", "Almacenaje"), ("monitor", "Equipos"),
        ("taza", "Aparatos"), ("planta", "Decoración")]
for i, (tipo, nombre) in enumerate(CATS):
    y = y_cat + i * 50
    col = BLANCO if i == 0 else GRIS
    icono_cat(x_cat + 16, y + 10, tipo, col)
    texto(d, (x_cat + 46, y + 9), nombre, SEMI, 15, BLANCO if i == 0 else TINTA, 118)

# tarjetas
for i, (png, nombre, precio, huella, sel) in enumerate(OBJ):
    cx = x_g + i * (CW + GAP)
    cy = y_g - (6 if sel else 0)
    img.paste(miniatura(png, 70), (cx + (CW - 70) // 2, cy + 8), miniatura(png, 70))
    texto(d, (cx + 12, cy + 84), nombre, SEMI, 14, TINTA, CW - 24)
    texto(d, (cx + 12, cy + 104), precio, BOLD, 15, AZUL if not sel else VERDE, 70)
    texto(d, (cx + 12, cy + 124), huella, NORM, 12, GRIS, CW - 24)

# ficha derecha
fx = x_f + 16
img.paste(miniatura("comodidad_banco_espera_pro_0.png", 88), (fx, Y0 + 76),
          miniatura("comodidad_banco_espera_pro_0.png", 88))
texto(d, (fx + 100, Y0 + 78), "Banco premium", SEMI, 18, TINTA, 170)
texto(d, (fx + 100, Y0 + 104), "240 €", BOLD, 16, VERDE, 90)
texto(d, (fx + 100, Y0 + 126), "1 celda · 2 plazas", NORM, 13, GRIS, 170)
def barra(y, k, frac, color, vtxt):
    texto(d, (fx, y), k, NORM, 13, GRIS, 120)
    d.rounded_rectangle([fx, y + 20, fx + 190, y + 28], 4, fill=(232, 237, 244))
    d.rounded_rectangle([fx, y + 20, fx + int(190 * frac), y + 28], 4, fill=color)
    texto(d, (fx + 200, y + 14), vtxt, SEMI, 14, color, 70)
barra(Y0 + 176, "Confort", 1.0, AZUL, "7/7")
barra(Y0 + 216, "Nota al salir", 0.8, VERDE, "+20%")
barra(Y0 + 256, "Paciencia extra", 0.6, AMBAR, "+14%")
texto(d, (fx, H - 46), "Mayús al colocar: repetir mueble", NORM, 13, AZUL, 260)

# herramientas: iconos de línea en círculo
def icono_tool(cx, cy, tipo, color):
    if tipo == "mano":
        d.rounded_rectangle([cx + 4, cy + 2, cx + 12, cy + 18], 4, outline=color, width=2)
        d.line([cx, cy + 10, cx + 4, cy + 8], fill=color, width=2)
    elif tipo == "gotero":
        d.line([cx + 3, cy + 15, cx + 13, cy + 5], fill=color, width=3)
        d.ellipse([cx + 11, cy + 1, cx + 17, cy + 7], outline=color, width=2)
    elif tipo == "pala":
        d.line([cx + 3, cy + 3, cx + 13, cy + 13], fill=color, width=3)
        d.polygon([(cx + 11, cy + 17), (cx + 17, cy + 11), (cx + 17, cy + 17)], fill=color)
TOOLS = [("mano", "Mover", TINTA), ("gotero", "Clonar", TINTA), ("pala", "Demoler", ROJO)]
for j, (tipo, nombre, col) in enumerate(TOOLS):
    y = Y0 + 70 + j * 92
    icono_tool(W - 60, y + 14, tipo, col)
    texto(d, (W - 84, y + 66), nombre, NORM, 12, col if col == ROJO else GRIS, 64)

lienzo = Image.new("RGB", (W, H + 46), (24, 24, 26))
dl = ImageDraw.Draw(lienzo)
dl.text((16, 12), "MAQUETA v3 · pantalla completa — HUD superior y panel de construcción en el mismo lenguaje",
        font=F(BOLD, 18), fill=(240, 240, 240))
lienzo.paste(img.convert("RGB"), (0, 46))
lienzo.save(os.path.join(SCRATCH, "menu_v3_completo.png"))
print("OK")
