"""Troceado del kit de UI de Comisario (piloto Summer, sesion 2026-08-07; reescrito 2026-08-08).

Recorta cada pieza/estado/icono de las hojas generadas (fondo magenta o damero falso segun
la hoja) a PNG con alfa real, en assets/ui/kit/. Genera ademas un contact-sheet de auditoria.

Ejecutar: python tools/_trocear_ui_kit.py   (o "py -3 tools/_trocear_ui_kit.py")
No requiere Godot -- solo Pillow/numpy/scipy (ya presentes en el entorno).

REESCRITURA 2026-08-08 -- que cambia y por que:
  1) SCRATCH apuntaba a un directorio de sesion que ya no existe. Ahora lee de
     capturas/fuentes/ui_kit_summer (carpeta estable del repo, no un scratch de sesion).
  2) La clave de croma antigua comparaba cada pixel contra UN solo magenta de referencia
     (distancia euclidea). Eso fallaba en dos sitios: (a) el damero falso de la hoja del
     boton demoler NO es gris -- es magenta claro/oscuro alternado -- así que el modo
     "checker" (gris) no lo detectaba y el modo "magenta+checker" tomaba el minimo de dos
     mascaras rotas; (b) las lineas-guia lila-magenta de la hoja de la barra superior caían
     fuera del radio de tolerancia y quedaban como pixeles sueltos opacos.
     Solucion: clave por MATIZ (hue), no por distancia RGB a un punto fijo. El magenta
     claro y el oscuro del damero comparten el mismo matiz (~303 grados), solo cambia
     saturacion/valor -- una sola prueba de matiz los detecta a ambos. Los grises/blancos
     reales del arte (saturacion muy baja) quedan siempre exentos de "parecer magenta" por
     ruido de matiz numerico.
  3) Se anade DESCONTAMINACION DE COLOR (despill): en los pixeles de borde con alfa parcial
     (mezcla real magenta+pieza por antialiasing) se resta la contribucion del magenta de
     fondo mas cercano (claro u oscuro) y se re-escala -- así el borde no arrastra un halo
     rosado/magenta cuando se compone sobre otro fondo en el juego.
  4) Erosion final de 1px sobre el canal alfa (grey_erosion) para limar cualquier resto de
     fleco que la descontaminacion no absorba del todo (pedido explicito para iconos, pero
     se aplica a toda pieza con fondo magenta -- no hace dano en piezas ya limpias).
  5) La caja de recorte del boton demoler se AJUSTA para no incluir el rotulo de la hoja
     "(1) Normal State" / "(2) Hover/Pressed State" -- medido pixel a pixel sobre el fondo
     rojo real del boton (ver notas junto a PIEZAS_DEMOLER).
  6) El modo "checker" (damero GRIS real, unico en la hoja piloto de pestanas/tarjetas) se
     mantiene tal cual -- ya producia alfa binario limpio; verificado con PIL antes de tocarlo.
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SCRATCH = r"C:\Users\manur\juego\capturas\fuentes\ui_kit_summer"
OUT = r"C:\Users\manur\juego\assets\ui\kit"
CONTROL = (
    r"C:\Users\manur\AppData\Local\Temp\claude\C--Users-manur-juego"
    r"\1f7d5694-02c7-4fc1-9a44-a8546d82445c\scratchpad"
)
os.makedirs(OUT, exist_ok=True)
os.makedirs(CONTROL, exist_ok=True)

# Los dos tonos de magenta que aparecen en las hojas: el chroma-key solido y el damero
# falso (claro/oscuro) de la hoja del boton demoler. Ambos comparten matiz ~303 grados.
MAGENTA_BRIGHT = np.array([248, 8, 238], dtype=np.float32)
MAGENTA_DARK = np.array([180, 0, 166], dtype=np.float32)
MAGENTA_HUE_DEG = 303.0


def rgb_to_hsv_np(arr_u8):
    """HxWx3 uint8 -> (h en grados 0-360, s 0-1, v 0-1), vectorizado."""
    a = arr_u8.astype(np.float32) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    maxc = np.max(a, axis=-1)
    minc = np.min(a, axis=-1)
    v = maxc
    delta = maxc - minc
    s = np.where(maxc > 0, delta / np.where(maxc > 0, maxc, 1.0), 0.0)
    safe_delta = np.where(delta == 0, 1.0, delta)
    rc = (maxc - r) / safe_delta
    gc = (maxc - g) / safe_delta
    bc = (maxc - b) / safe_delta
    h = np.zeros_like(r)
    h = np.where(maxc == r, bc - gc, h)
    h = np.where(maxc == g, 2.0 + rc - bc, h)
    h = np.where(maxc == b, 4.0 + gc - rc, h)
    h = (h / 6.0) % 1.0
    h = np.where(delta == 0, 0.0, h)
    return h * 360.0, s, v


def alpha_magenta_hue(arr, hue_target=MAGENTA_HUE_DEG, tol_in=16, tol_out=34, sat_min=0.12):
    """Alfa por matiz: cualquier pixel con matiz cercano al magenta (claro U oscuro) se
    vuelve transparente, sin importar su brillo/saturacion exactos -- así cubre a la vez
    el chroma-key solido y el damero falso magenta con una sola prueba. Los pixeles poco
    saturados (grises/blancos reales del arte) quedan excluidos a proposito: con
    saturacion tan baja el matiz es ruido numerico y NO debe leerse como "es magenta".
    """
    h, s, v = rgb_to_hsv_np(arr[..., :3])
    hue_dist = np.abs(h - hue_target)
    hue_dist = np.minimum(hue_dist, 360.0 - hue_dist)
    hue_dist = np.where(s < sat_min, 999.0, hue_dist)
    alpha = np.clip((hue_dist - tol_in) / max(1.0, (tol_out - tol_in)) * 255.0, 0, 255)
    return alpha.astype(np.uint8)


def alpha_checker_gray(arr, value_max=132):
    """Damero GRIS real (unico en la hoja piloto pestanas/tarjetas).

    CORRECCION 2026-08-08 (dos bugs encontrados con PIL, no solo teoria):
    1) scipy trata el exterior del array como border_value=0 durante binary_closing:
       eso erosionaba la fila/columna 0 (borde EXACTO del recorte, que aqui siempre es
       fondo real de sobra) a "no-fondo" solo por no tener vecino fuera del array -- el
       bbox del alfa se disparaba a (0,0,ancho,alto) entero y el autocrop no recortaba
       nada. pestana_normal.png salia con lienzo 250x300 completo en vez de su silueta.
    2) En pestana_activa.png (y variantes con halo/glow claro pegado al borde) quedaba
       un fleco de damero SIN convertir: el antialiasing entre el glow blanco-azulado de
       la pieza y la celda CLARA del damero (~116) produce un tono intermedio (~150-190)
       que el umbral estricto (r<132) no reconoce como fondo, así que esa celda concreta
       del damero se quedaba opaca -- se ve como una fila de casillas sueltas junto al
       borde. Verificado leyendo el canal alfa pixel a pixel (alternaba 255/0 en la
       columna 0).
    Solucion con dos pasadas:
      a) SEMILLA estricta (umbral ajustado) + conexion por flood-fill al borde del
         recorte -- solo cuenta como fondo lo que de verdad esta pegado al marco de
         sobra, nunca una isla gris casual dentro de la propia pieza.
      b) HISTERESIS: desde esa semilla, crece 3-4 iteraciones hacia vecinos "gris debil"
         (tolerancia mas laxa) -- así arrastra el antialiasing/blend de la celda clara
         sin comerse el interior solido de la pieza (que no es gris ahi)."""
    r, g, b = arr[..., 0].astype(int), arr[..., 1].astype(int), arr[..., 2].astype(int)
    # Tolerancia 24 (no 8): el damero de la hoja piloto NO es gris neutro puro -- en la franja
    # entre pestañas queda TEÑIDO de azul por el sangrado de la pieza vecina (medido en
    # pestana_normal: RGB ~(56,68,73), diferencias entre canales de hasta ~17) y con <8 esa
    # tira sobrevivia opaca en el borde derecho de las 4 pestañas. El interior de la pieza no
    # corre peligro: sus azules reales tienen tintes mucho mas fuertes (p. ej. el relleno
    # (123,160,188) separa 65 entre canales) y ademas la semilla exige CONEXION con el borde.
    diff_bg = (np.abs(r - g) < 24) & (np.abs(g - b) < 24) & (np.abs(r - b) < 24)
    strict = diff_bg & (r < value_max)

    pad = 4
    strict_p = np.pad(strict, pad, mode="edge")
    labeled, n = ndimage.label(strict_p)
    border_labels = set(labeled[0, :].tolist()) | set(labeled[-1, :].tolist())
    border_labels |= set(labeled[:, 0].tolist()) | set(labeled[:, -1].tolist())
    border_labels.discard(0)
    bg_p = np.isin(labeled, list(border_labels))
    bg = bg_p[pad:-pad, pad:-pad]

    # 30/200 (no 20/190) por el mismo motivo que la semilla: las celdas CLARAS del damero
    # tenido tambien separan mas de 20 entre canales en la franja de sangrado.
    lenient = (np.abs(r - g) < 30) & (np.abs(g - b) < 30) & (np.abs(r - b) < 30) & (r < 200)
    for _ in range(4):
        grown = ndimage.binary_dilation(bg) & lenient
        if (grown & ~bg).sum() == 0:
            bg = bg | grown
            break
        bg = bg | grown

    return np.where(bg, 0, 255).astype(np.uint8)


def despill_magenta(rgb_u8, alpha_u8):
    """Descontamina el color de los pixeles de borde con alfa parcial: resta la
    contribucion del magenta de fondo mas cercano (claro u oscuro, el que corresponda
    localmente) y re-escala. Sin esto, el borde compuesto sobre OTRO fondo en el juego
    arrastra un halo rosado/magenta aunque el alfa ya sea correcto."""
    mask = (alpha_u8 > 0) & (alpha_u8 < 255)
    if not mask.any():
        return rgb_u8
    rgbf = rgb_u8.astype(np.float32)
    a = alpha_u8.astype(np.float32) / 255.0
    d_bright = ((rgbf - MAGENTA_BRIGHT) ** 2).sum(axis=-1)
    d_dark = ((rgbf - MAGENTA_DARK) ** 2).sum(axis=-1)
    ref = np.where((d_bright <= d_dark)[..., None], MAGENTA_BRIGHT, MAGENTA_DARK)
    a_safe = np.clip(a, 0.2, 1.0)[..., None]  # evita amplificar ruido al dividir por alfa casi 0
    decon = (rgbf - (1.0 - a_safe) * ref) / a_safe
    decon = np.clip(decon, 0, 255)
    out = np.where(mask[..., None], decon, rgbf)
    return out.astype(np.uint8)


def erode_alpha_1px(alpha_u8):
    """Erosion de 1px sobre el alfa (filtro de minimo local) para limar cualquier resto
    de fleco magenta que la descontaminacion no absorba del todo en pieza con fondo
    magenta (iconos sobre todo, pero se aplica a toda pieza de ese tipo)."""
    return ndimage.grey_erosion(alpha_u8, size=(3, 3)).astype(np.uint8)


def quitar_lineas_guia(rgb_u8):
    """SOLO para ui_barra_superior.png: la hoja fuente trae dos lineas-guia grises finas
    (de las burbujas-callout que senalan el boton play y la insignia) que CRUZAN por
    encima del panel ya opaco -- no son spill de croma, son anotacion real dibujada sobre
    la pieza, así que ninguna clave de color las quita. Se detectan por ser las unicas
    componentes grandes de tono gris medio (170-240, canales parejos) dentro del panel
    y se rellenan por vecino-no-enmascarado-mas-cercano (inpaint barato, funciona bien
    porque el fondo alrededor es plano o un degradado suave)."""
    rgb = rgb_u8.astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    gray = (np.abs(r - g) < 10) & (np.abs(g - b) < 10) & (np.abs(r - b) < 10)
    midtone = gray & (r > 150) & (r < 240)
    labeled, n = ndimage.label(midtone, structure=np.ones((3, 3)))
    if n == 0:
        return rgb_u8
    sizes = ndimage.sum(midtone, labeled, range(1, n + 1))
    big = np.zeros_like(midtone)
    for i, s in enumerate(sizes, start=1):
        if s > 80:  # las lineas-guia miden ~130-175px de area; el resto es ruido (rebordes de iconos)
            big |= (labeled == i)
    if not big.any():
        return rgb_u8
    mask = ndimage.binary_dilation(big, iterations=3)
    _, indices = ndimage.distance_transform_edt(mask, return_indices=True)
    filled = rgb_u8[indices[0], indices[1]]
    return np.where(mask[..., None], filled, rgb_u8).astype(np.uint8)


def load(name):
    return Image.open(os.path.join(SCRATCH, name)).convert("RGB")


def save_piece(im_rgb, box, out_name, mode, save_control=False, quitar_guias=False):
    crop = im_rgb.crop(box)
    arr = np.array(crop)
    if mode == "magenta_hue":
        alpha = alpha_magenta_hue(arr)
        rgb = despill_magenta(arr, alpha)
        alpha = erode_alpha_1px(alpha)
        if quitar_guias:
            rgb = quitar_lineas_guia(rgb)
    elif mode == "checker":
        alpha = alpha_checker_gray(arr)
        rgb = arr
    else:
        raise ValueError(f"modo desconocido: {mode}")
    rgba = np.dstack([rgb, alpha])
    out = Image.fromarray(rgba, mode="RGBA")
    # AUTOCROP: las cajas de busqueda llevan margen de sobra a proposito (para no
    # comerse ningun pixel de la pieza); este paso ajusta al bbox real del alfa + 4px de
    # aire, así los margenes de 9-slice miden algo real sobre el PNG final.
    bbox = out.getbbox()
    if bbox is not None:
        pad = 4
        x0, y0, x1, y1 = bbox
        x0 = max(0, x0 - pad)
        y0 = max(0, y0 - pad)
        x1 = min(out.width, x1 + pad)
        y1 = min(out.height, y1 + pad)
        out = out.crop((x0, y0, x1, y1))
    out.save(os.path.join(OUT, out_name))
    if save_control:
        out.save(os.path.join(CONTROL, f"ctrl_{out_name}"))
    return out


results = []  # (out_name, PIL image) for contact sheet

# ── 1) PIEZA PILOTO: pestañas + tarjetas (damero GRIS real) ────────────────────────────────
pilot = load("ui_piloto_pestanas_tarjetas.png")
tabs = [
    ("pestana_normal.png", (18, 92, 268, 392)),
    ("pestana_hover.png", (264, 92, 514, 392)),
    ("pestana_activa.png", (510, 92, 762, 392)),
    ("pestana_bloqueada.png", (758, 92, 1010, 392)),
]
for name, box in tabs:
    im = save_piece(pilot, box, name, "checker")
    results.append((name, im))

cards = [
    ("tarjeta_normal.png", (28, 562, 268, 875)),
    ("tarjeta_hover.png", (264, 562, 514, 875)),
    ("tarjeta_seleccionada.png", (510, 562, 762, 875)),
    ("tarjeta_bloqueada.png", (758, 562, 1010, 875)),
]
for name, box in cards:
    im = save_piece(pilot, box, name, "checker")
    results.append((name, im))

# ── 2) BARRA SUPERIOR (fondo magenta solido + lineas-guia magenta-lila) ────────────────────
barra = load("ui_barra_superior.png")
piezas_barra = [
    ("barra_superior_fondo.png", (44, 417, 981, 607)),
    ("barra_superior_modulo_reloj.png", (58, 466, 292, 564)),
    ("barra_superior_modulo_velocidad.png", (296, 466, 474, 564)),
    ("barra_superior_modulo_saldo.png", (476, 466, 714, 564)),
    ("barra_superior_modulo_objetivo.png", (712, 466, 954, 564)),
]
for name, box in piezas_barra:
    im = save_piece(barra, box, name, "magenta_hue",
                     save_control=(name == "barra_superior_fondo.png"),
                     quitar_guias=(name == "barra_superior_fondo.png"))
    results.append((name, im))

# ── 3) BOTÓN DEMOLER (fondo magenta solido arriba + damero falso magenta abajo) ────────────
# Cajas MEDIDAS pixel a pixel sobre el boton real (mascara "es rojo de boton", no gris/no
# magenta): fila 381-642, col 57-486 (normal) / 537-966 (pulsado) en la hoja fuente
# 1024x1024. Se añade margen de ~8-10px SIN llegar a la fila 370 donde empieza el rotulo
# "(1) Normal State" (ese rotulo termina claramente antes de la fila 374).
demoler = load("ui_boton_demoler.png")
piezas_demoler = [
    ("boton_demoler_normal.png", (49, 374, 494, 650)),
    ("boton_demoler_pulsado.png", (529, 373, 974, 650)),
]
for name, box in piezas_demoler:
    im = save_piece(demoler, box, name, "magenta_hue", save_control=True)
    results.append((name, im))

# ── 4) MARCO DE VENTANA + PÍLDORAS DE BOTÓN (fondo magenta solido) ─────────────────────────
ventana = load("ui_marco_ventana.png")
piezas_ventana = [
    ("ventana_marco.png", (50, 175, 695, 840)),
    ("ventana_cabecera.png", (50, 175, 695, 275)),
    ("boton_pildora_primario_normal.png", (698, 306, 977, 419)),
    ("boton_pildora_primario_hover.png", (690, 419, 983, 543)),
    ("boton_pildora_secundario_normal.png", (692, 571, 980, 692)),
    ("boton_pildora_secundario_hover.png", (692, 703, 981, 825)),
]
for name, box in piezas_ventana:
    im = save_piece(ventana, box, name, "magenta_hue", save_control=(name == "ventana_marco.png"))
    results.append((name, im))

# ── 5) BANDEJA DE AVISOS (4 toasts, fondo magenta solido) ──────────────────────────────────
avisos = load("ui_bandeja_avisos.png")
piezas_avisos = [
    ("toast_info.png", (76, 66, 948, 281)),
    ("toast_aviso.png", (76, 294, 948, 509)),
    ("toast_critico.png", (76, 522, 948, 737)),
    ("toast_queja.png", (76, 750, 948, 965)),
]
for name, box in piezas_avisos:
    im = save_piece(avisos, box, name, "magenta_hue", save_control=(name == "toast_info.png"))
    results.append((name, im))

# ── 6) ICONOS — Lote A (construcción y mundo, 8 primeros de los 12 en la hoja) ─────────────
lote1 = load("ui_iconos_lote1.png")
nombres_lote1 = [
    "icono_plano.png", "icono_sillon.png", "icono_muro.png", "icono_pin.png",
    "icono_llave_inglesa.png", "icono_rodillo.png", "icono_papelera.png", "icono_candado.png",
]
cajas_lote1 = [
    (46, 81, 265, 301), (284, 81, 503, 301), (521, 81, 740, 301), (759, 81, 978, 301),
    (46, 344, 265, 565), (284, 344, 503, 565), (521, 344, 740, 565), (759, 344, 978, 565),
]
for name, box in zip(nombres_lote1, cajas_lote1):
    im = save_piece(lote1, box, name, "magenta_hue", save_control=(name == "icono_plano.png"))
    results.append((name, im))

# ── 7) ICONOS — Lote B (gestión y HUD, 8) ──────────────────────────────────────────────────
lote2 = load("ui_iconos_lote2.png")
nombres_lote2 = [
    "icono_personal.png", "icono_reloj.png", "icono_disquete.png", "icono_carpeta.png",
    "icono_moneda.png", "icono_velocimetro.png", "icono_campana.png", "icono_queja.png",
]
cajas_lote2 = [
    (32, 261, 258, 499), (277, 261, 503, 499), (521, 261, 747, 499), (766, 261, 992, 499),
    (32, 525, 258, 763), (277, 525, 503, 763), (521, 525, 747, 763), (766, 525, 992, 763),
]
for name, box in zip(nombres_lote2, cajas_lote2):
    im = save_piece(lote2, box, name, "magenta_hue", save_control=(name == "icono_reloj.png"))
    results.append((name, im))

print("Piezas troceadas:", len(results))

# ── CONTACT SHEET de auditoría ───────────────────────────────────────────────────────────────
cols = 6
cell = 190
rows = (len(results) + cols - 1) // cols
sheet_w = cols * cell
sheet_h = rows * (cell + 26)
sheet = Image.new("RGB", (sheet_w, sheet_h), (60, 60, 65))
draw = ImageDraw.Draw(sheet)
# fondo de damero para ver la transparencia real conseguida
tile = 10
for yy in range(0, sheet_h, tile):
    for xx in range(0, sheet_w, tile):
        if ((xx // tile) + (yy // tile)) % 2 == 0:
            draw.rectangle([xx, yy, xx + tile, yy + tile], fill=(90, 90, 95))

for i, (name, im) in enumerate(results):
    col = i % cols
    row = i // cols
    x0 = col * cell
    y0 = row * (cell + 26)
    thumb = im.copy()
    thumb.thumbnail((cell - 16, cell - 36))
    sheet.paste(thumb, (x0 + 8, y0 + 8), thumb)
    draw.text((x0 + 6, y0 + cell - 22), name, fill=(255, 255, 0))

sheet.save(os.path.join(CONTROL, "contact_sheet_kit_ui.png"))
print("Contact sheet:", os.path.join(CONTROL, "contact_sheet_kit_ui.png"))


# ── 8) REESCALADO FINAL DE LAS PIEZAS DE BOTON (2026-08-08, fix del "achatado") ────────────
# Los margenes de un StyleBoxTexture son PIXELES DE TEXTURA dibujados 1:1 en el boton: con
# arte de ~250px y botones de 84px las esquinas se comian el boton entero y el centro salia
# aplastado (visto en el playtest del usuario). Se reescala cada familia de piezas de BOTON
# a ~1.2x su tamano de render (nitido y con margenes pequenos); un solo factor UNIFORME por
# familia para que los 4 estados de cada boton casen entre si (ley: nada de escala no
# uniforme ni factores distintos por estado). Los margenes del theme se dividen igual.
# Piezas grandes (toasts, ventana_marco, barra_superior) NO se tocan: se usan a tamano grande.
FACTOR_BOTON = {
    "pestana_normal.png": 0.42, "pestana_hover.png": 0.42,
    "pestana_activa.png": 0.42, "pestana_bloqueada.png": 0.42,
    "tarjeta_normal.png": 0.43, "tarjeta_hover.png": 0.43,
    "tarjeta_seleccionada.png": 0.43, "tarjeta_bloqueada.png": 0.43,
    "boton_demoler_normal.png": 0.25, "boton_demoler_pulsado.png": 0.25,
    "boton_pildora_primario_normal.png": 0.5, "boton_pildora_primario_hover.png": 0.5,
    "boton_pildora_secundario_normal.png": 0.5, "boton_pildora_secundario_hover.png": 0.5,
}
for nombre, factor in FACTOR_BOTON.items():
    ruta = os.path.join(OUT, nombre)
    im = Image.open(ruta).convert("RGBA")
    nuevo = im.resize((max(1, round(im.width * factor)), max(1, round(im.height * factor))), Image.LANCZOS)
    nuevo.save(ruta)
    print("reescalada %s: %dx%d -> %dx%d (x%.2f)" % (nombre, im.width, im.height, nuevo.width, nuevo.height, factor))
