# Paso 1 de la v3: reemplaza el HUD superior viejo por la barra MODERNA (mismo lenguaje que el
# panel v2) sobre la captura real → deja fondo_v3.png listo para el render del panel inferior.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

SCRATCH = r"C:\Users\manur\AppData\Local\Temp\claude\C--Users-manur-juego\aad5e0e0-a0be-4878-b068-20ca5cee13c8\scratchpad"
F_DIR = r"C:\Windows\Fonts"
PANEL = (238, 243, 249); BLANCO = (255, 255, 255); TINTA = (36, 48, 66)
GRIS = (122, 136, 156); AZUL = (47, 108, 224); AZUL_SUAVE = (232, 240, 254)
VERDE = (34, 160, 94); AMBAR = (240, 158, 44)

def F(n, t): return ImageFont.truetype(os.path.join(F_DIR, n), t)
SEMI, NORM, BOLD = "seguisb.ttf", "segoeui.ttf", "segoeuib.ttf"

img = Image.open(os.path.join(SCRATCH, "fantasma_arrastre.png")).convert("RGBA")
W, H = img.size

# ── borrar el HUD viejo: relleno liso de césped (el teselado con retales quedaba fatal) ──────────
d0 = ImageDraw.Draw(img)
d0.rectangle([0, 40, W, 238], fill=(66, 73, 57))
# damero sutil para que no sea un plastón: cuadros isométricos grandes alternos
for fila in range(6):
    for col in range(-2, 24):
        if (fila + col) % 2 == 0:
            cx = col * 84 + (fila % 2) * 42
            cy = 40 + fila * 34
            d0.polygon([(cx - 42, cy + 17), (cx, cy), (cx + 42, cy + 17), (cx, cy + 34)],
                       fill=(71, 78, 61))

# ── barra nueva ──────────────────────────────────────────────────────────────
sombra = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(sombra)
ds.rounded_rectangle([12, 70, W - 12, 134], 20, fill=(30, 45, 70, 70))
img.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(7)))
d = ImageDraw.Draw(img, "RGBA")
d.rounded_rectangle([12, 64, W - 12, 128], 20, fill=PANEL)

def pill(caja, fill=BLANCO):
    d.rounded_rectangle(caja, 16, fill=fill)

y0, y1 = 76, 116
# reloj + día/hora
pill((28, y0, 250, y1))
d.ellipse([42, y0 + 8, 66, y0 + 32], outline=TINTA, width=2)
d.line([54, y0 + 14, 54, y0 + 21], fill=TINTA, width=2)
d.line([54, y0 + 21, 61, y0 + 25], fill=TINTA, width=2)
d.text((78, y0 + 8), "Día 3 · 07:47", font=F(SEMI, 17), fill=TINTA)

# control de velocidad segmentado (pausa | ▶ | ▶▶ | ▶▶▶), activo = ▶
pill((266, y0, 470, y1))
seg_w = (470 - 266) // 4
d.rounded_rectangle([266 + seg_w + 3, y0 + 4, 266 + 2 * seg_w - 3, y1 - 4], 13, fill=AZUL_SUAVE)
def tri(cx, cy, col, n=1):
    for k in range(n):
        d.polygon([(cx + k * 11, cy - 7), (cx + k * 11, cy + 7), (cx + 9 + k * 11, cy)], fill=col)
cy = (y0 + y1) // 2
d.rectangle([266 + seg_w // 2 - 6, cy - 7, 266 + seg_w // 2 - 2, cy + 7], fill=GRIS)
d.rectangle([266 + seg_w // 2 + 2, cy - 7, 266 + seg_w // 2 + 6, cy + 7], fill=GRIS)
tri(266 + seg_w + seg_w // 2 - 4, cy, AZUL)
tri(266 + 2 * seg_w + seg_w // 2 - 10, cy, GRIS, 2)
tri(266 + 3 * seg_w + seg_w // 2 - 15, cy, GRIS, 3)

# chips de estado
def chip(x, w, dibuja):
    pill((x, y0, x + w, y1))
    dibuja(x)
    return x + w + 14
x = 496
def c_satisf(x):
    d.text((x + 14, y0 + 3), "Satisfacción", font=F(NORM, 12), fill=GRIS)
    d.rounded_rectangle([x + 14, y0 + 24, x + 104, y0 + 31], 4, fill=(232, 237, 244))
    d.rounded_rectangle([x + 14, y0 + 24, x + 59, y0 + 31], 4, fill=AZUL)
    d.text((x + 114, y0 + 9), "50%", font=F(SEMI, 15), fill=TINTA)
x = chip(x, 165, c_satisf)
def c_demanda(x):
    d.ellipse([x + 14, cy - 6, x + 26, cy + 6], fill=AMBAR)
    d.text((x + 34, y0 + 8), "Demanda baja", font=F(SEMI, 15), fill=TINTA)
x = chip(x, 160, c_demanda)
def c_plantilla(x):
    d.ellipse([x + 14, y0 + 7, x + 26, y0 + 19], outline=TINTA, width=2)
    d.arc([x + 10, y0 + 20, x + 30, y0 + 38], 180, 360, fill=TINTA, width=2)
    d.text((x + 38, y0 + 8), "4/4", font=F(SEMI, 15), fill=TINTA)
x = chip(x, 92, c_plantilla)
def c_docs(x):
    d.rounded_rectangle([x + 14, y0 + 7, x + 28, y0 + 33], 2, outline=TINTA, width=2)
    d.line([x + 18, y0 + 14, x + 24, y0 + 14], fill=TINTA, width=1)
    d.line([x + 18, y0 + 19, x + 24, y0 + 19], fill=TINTA, width=1)
    d.text((x + 36, y0 + 8), "0 en cola", font=F(SEMI, 15), fill=TINTA)
x = chip(x, 138, c_docs)

# dinero, a la derecha
pill((W - 226, y0, W - 28, y1))
d.ellipse([W - 212, y0 + 8, W - 188, y0 + 32], fill=(226, 244, 234))
d.text((W - 206, y0 + 9), "€", font=F(BOLD, 15), fill=VERDE)
d.text((W - 178, y0 + 7), "3.000 €", font=F(SEMI, 18), fill=TINTA)

img.convert("RGB").save(os.path.join(SCRATCH, "fondo_v3.png"))
print("OK fondo_v3")
