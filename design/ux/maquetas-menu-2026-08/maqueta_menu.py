# MAQUETA del menú de construcción estilo Sims para Comisario.
# Se monta SOBRE la captura real del juego; miniaturas = sprites reales del catálogo.
# Regla de la casa: NINGÚN texto cortado — todo rótulo se mide y si no cabe, se reduce la fuente.
from PIL import Image, ImageDraw, ImageFont
import os

MOB = r"C:\Users\manur\juego\assets\sprites\mobiliario"
SCRATCH = r"C:\Users\manur\AppData\Local\Temp\claude\C--Users-manur-juego\aad5e0e0-a0be-4878-b068-20ca5cee13c8\scratchpad"

# Paleta calcada del HUD actual (muestreada de la captura)
NAVY = (16, 22, 42)          # fondo de la barra
NAVY_CLARO = (28, 38, 66)    # paneles internos
BORDE = (74, 104, 150)
CARTA = (232, 242, 252)      # tarjeta clara como los botones actuales
CARTA_SEL = (255, 244, 200)  # seleccionada (ámbar suave)
TEXTO_OSC = (24, 40, 66)
TEXTO_CLARO = (225, 235, 248)
VERDE = (92, 200, 120)
ROJO = (235, 90, 90)
AMBAR = (255, 214, 90)

def F(nombre, tam):
    return ImageFont.truetype(rf"C:\Windows\Fonts\{nombre}", tam)

def texto_ajustado(d, xy, txt, fuente_nombre, tam, color, max_w, negrita=True):
    """Dibuja el texto reduciendo la fuente hasta que quepa en max_w. Devuelve la fuente usada."""
    nombre = "arialbd.ttf" if negrita else "arial.ttf"
    while tam > 8:
        f = F(nombre, tam)
        if d.textlength(txt, font=f) <= max_w:
            d.text(xy, txt, font=f, fill=color)
            return f
        tam -= 1
    d.text(xy, txt, font=F(nombre, 8), fill=color)
    return F(nombre, 8)

def miniatura(ruta, lado):
    im = Image.open(ruta).convert("RGBA")
    escala = min(lado / im.width, lado / im.height, 2.0)
    nuevo = (max(1, int(im.width * escala)), max(1, int(im.height * escala)))
    im = im.resize(nuevo, Image.NEAREST if escala >= 1 else Image.LANCZOS)
    marco = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    marco.alpha_composite(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    return marco

fondo = Image.open(os.path.join(SCRATCH, "fantasma_arrastre.png")).convert("RGB")
W, H = fondo.size
ALTO_PANEL = 360
Y0 = H - ALTO_PANEL
img = fondo.copy()
d = ImageDraw.Draw(img)

# ── panel base ───────────────────────────────────────────────────────────────
d.rectangle([0, Y0, W, H], fill=NAVY)
d.rectangle([0, Y0, W, Y0 + 3], fill=BORDE)

# ── fila superior: buscador + orden + filtro + presupuesto ───────────────────
y_top = Y0 + 12
d.rounded_rectangle([16, y_top, 300, y_top + 34], 8, fill=NAVY_CLARO, outline=BORDE)
texto_ajustado(d, (30, y_top + 8), "buscar mueble...", "arial", 15, (150, 165, 195), 260, False)
# toggle Sala/Función
d.rounded_rectangle([316, y_top, 560, y_top + 34], 8, fill=NAVY_CLARO, outline=BORDE)
d.rounded_rectangle([320, y_top + 3, 436, y_top + 31], 6, fill=CARTA)
texto_ajustado(d, (338, y_top + 9), "POR FUNCIÓN", "arialbd", 13, TEXTO_OSC, 95)
texto_ajustado(d, (462, y_top + 9), "POR SALA", "arialbd", 13, (150, 165, 195), 90)
# filtro precio
d.rounded_rectangle([576, y_top, 750, y_top + 34], 8, fill=NAVY_CLARO, outline=BORDE)
texto_ajustado(d, (590, y_top + 9), "PRECIO: TODOS  \u25BE", "arialbd", 12, TEXTO_CLARO, 150)
# presupuesto (siempre visible)
d.rounded_rectangle([W - 240, y_top, W - 16, y_top + 34], 8, fill=(46, 60, 40), outline=VERDE)
texto_ajustado(d, (W - 222, y_top + 8), "PRESUPUESTO:  3.000 €", "arialbd", 14, (180, 240, 190), 200)

# ── columna izquierda: categorías por función ────────────────────────────────
x_cat, y_cat = 16, Y0 + 60
CATS = [("\U0001FA91", "ASIENTOS", True), ("\U0001F5C4", "ALMACENAJE", False),
        ("\U0001F4BB", "EQUIPOS", False), ("\u2615", "APARATOS", False),
        ("\U0001F33F", "DECORACIÓN", False), ("\U0001F6E0", "HERRAMIENTAS", False)]
for i, (icono, nombre, activa) in enumerate(CATS):
    y = y_cat + i * 47
    d.rounded_rectangle([x_cat, y, x_cat + 168, y + 40], 8,
                        fill=CARTA if activa else NAVY_CLARO, outline=BORDE)
    texto_ajustado(d, (x_cat + 12, y + 10), nombre, "arialbd", 13,
                   TEXTO_OSC if activa else TEXTO_CLARO, 145)

# ── rejilla central de tarjetas (3 filas visibles, nada de 2 filas de los Sims) ─
objetos = [
    ("silla_espera_0.png", "Silla de espera", "25 €", "1 celda · 1 plaza", False),
    ("comodidad_silla_espera_madera_0.png", "Silla de madera", "25 €", "1 celda · 1 plaza", False),
    ("comodidad_banco_espera_basico_0.png", "Banco básico", "80 €", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_medio_0.png", "Banco acolchado", "150 €", "1 celda · 2 plazas", False),
    ("comodidad_banco_espera_pro_0.png", "Banco premium", "240 €", "1 celda · 2 plazas", True),
    ("comodidad_escritorio_trabajo_0.png", "Escritorio", "350 €", "1 celda", False),
    ("comodidad_estanteria_suelta_0.png", "Estantería", "120 €", "1 celda", False),
    ("comodidad_dispensador_agua_0.png", "Dispensador", "90 €", "1 celda", False),
    ("comodidad_equipo_informatico_0.png", "Equipo inform.", "200 €", "sobre mesa", False),
]
x_g, y_g = 200, Y0 + 60
CW, CH, GAP = 128, 132, 10
por_fila = 7
for i, (png, nombre, precio, huella, sel) in enumerate(objetos):
    cx = x_g + (i % por_fila) * (CW + GAP)
    cy = y_g + (i // por_fila) * (CH + GAP)
    d.rounded_rectangle([cx, cy, cx + CW, cy + CH], 10,
                        fill=CARTA_SEL if sel else CARTA,
                        outline=AMBAR if sel else BORDE, width=3 if sel else 1)
    ruta = os.path.join(MOB, png)
    if os.path.exists(ruta):
        img.paste(miniatura(ruta, 66), (cx + (CW - 66) // 2, cy + 8),
                  miniatura(ruta, 66))
    texto_ajustado(d, (cx + 8, cy + 78), nombre, "arialbd", 13, TEXTO_OSC, CW - 16)
    texto_ajustado(d, (cx + 8, cy + 96), precio, "arialbd", 13, (30, 110, 60), CW - 16)
    texto_ajustado(d, (cx + 8, cy + 112), huella, "arial", 11, (95, 110, 135), CW - 16, False)

# ── ficha del seleccionado (derecha) ─────────────────────────────────────────
x_f = x_g + por_fila * (CW + GAP) + 8
d.rounded_rectangle([x_f, Y0 + 60, W - 96, H - 16], 10, fill=NAVY_CLARO, outline=AMBAR, width=2)
fx = x_f + 14
ruta_sel = os.path.join(MOB, "comodidad_banco_espera_pro_0.png")
img.paste(miniatura(ruta_sel, 84), (fx, Y0 + 74), miniatura(ruta_sel, 84))
texto_ajustado(d, (fx + 96, Y0 + 78), "Banco premium", "arialbd", 16, TEXTO_CLARO, 165)
texto_ajustado(d, (fx + 96, Y0 + 102), "240 €", "arialbd", 15, (150, 230, 160), 100)
texto_ajustado(d, (fx + 96, Y0 + 124), "1 celda · 2 plazas", "arial", 12, (170, 185, 210), 165, False)
stats = [("CONFORT", "7 / 7", VERDE), ("NOTA AL SALIR", "+20 %", VERDE), ("AGUANTE EXTRA", "-14 % impaciencia", AMBAR)]
for i, (k, v, c) in enumerate(stats):
    y = Y0 + 170 + i * 30
    texto_ajustado(d, (fx, y), k, "arialbd", 12, (160, 175, 200), 120)
    texto_ajustado(d, (fx + 132, y), v, "arialbd", 12, c, 130)
texto_ajustado(d, (fx, H - 52), "MAYÚS al colocar = repetir mueble", "arial", 12, AMBAR, 250, False)

# ── herramientas (columna derecha) ───────────────────────────────────────────
tools = [("\u270B", "MANO", NAVY_CLARO), ("\U0001F4A7", "CLONAR", NAVY_CLARO), ("\U0001F5D1", "DEMOLER", (120, 36, 40))]
for i, (icono, nombre, color) in enumerate(tools):
    y = Y0 + 60 + i * 92
    d.rounded_rectangle([W - 84, y, W - 16, y + 80], 10, fill=color, outline=BORDE)
    f_i = F("seguiemj.ttf", 28) if os.path.exists(r"C:\Windows\Fonts\seguiemj.ttf") else F("arial.ttf", 26)
    d.text((W - 66, y + 12), icono, font=f_i, fill=TEXTO_CLARO, embedded_color=True)
    texto_ajustado(d, (W - 80, y + 56), nombre, "arialbd", 11, TEXTO_CLARO, 60)

# ── cinta de título de la maqueta ────────────────────────────────────────────
lienzo = Image.new("RGB", (W, H + 46), (32, 34, 38))
dl = ImageDraw.Draw(lienzo)
dl.text((16, 12), "MAQUETA v1 — menú de construcción estilo Sims (sobre captura real; miniaturas = sprites del juego)",
        font=F("arialbd.ttf", 18), fill=(240, 240, 240))
lienzo.paste(img, (0, 46))
lienzo.save(os.path.join(SCRATCH, "maqueta_menu.png"))
print("OK", lienzo.size)
