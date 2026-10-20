"""
Recursos del Mundo 8 que NO están en las cuatro referencias oficiales y se dibujan por código
(pixel art de bloques, sin suavizado, con la paleta del Mundo 8):

  - throne.png            el trono oscuro del salón del Rey Pesadelo (decorado)
  - bedroom.png           la habitación de Alice al amanecer (cinemática final, 480x270)
  - bedroom_blanket.png   la colcha de la cama, capa delantera que tapa a Alice acostada/sentada

Alice NUNCA se dibuja aquí: la cinemática usa sus fotogramas oficiales (resources/player). El
panel "FINAL" de jefemundo8.png muestra otra niña (rubia, vestido azul) y no se usa.

Uso: python tools/world8/generate_world8_extras.py   (también lo llama prepare_world8_assets.py)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "godot", "resources", "world8", "cinematics")

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
INK = (40, 22, 60)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def dither_v(img, box, top, bottom, bands=10):
    """Degradado vertical en bandas con trama ordenada (sin semitransparencias)."""
    x0, y0, x1, y1 = box
    a, b = np.array(hexc(top)), np.array(hexc(bottom))
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        q = t * bands
        lo, frac = math.floor(q), q - math.floor(q)
        for x in range(x0, x1):
            k = min(lo + (1 if frac > BAYER[y % 4, x % 4] else 0), bands) / bands
            img[y, x, :3] = (a * (1 - k) + b * k).astype(np.uint8)
            img[y, x, 3] = 255


def outline(img, color=INK):
    """Contorno de 1 px alrededor de lo opaco."""
    a = img[..., 3] > 0
    edge = np.zeros_like(a)
    edge[1:, :] |= a[:-1, :]
    edge[:-1, :] |= a[1:, :]
    edge[:, 1:] |= a[:, :-1]
    edge[:, :-1] |= a[:, 1:]
    edge &= ~a
    img[edge] = (*color, 255)
    return img


def star(d, cx, cy, r, color):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    d.polygon(pts, fill=color)


def heart(d, cx, cy, s, color):
    d.ellipse((cx - s, cy - s, cx, cy), fill=color)
    d.ellipse((cx, cy - s, cx + s, cy), fill=color)
    d.polygon([(cx - s, cy - s / 2), (cx + s, cy - s / 2), (cx, cy + s)], fill=color)


# ------------------------------------------------------------------- trono
def make_throne():
    w, h = 46, 64
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark, mid, light = hexc("#35205F"), hexc("#4B2C82"), hexc("#713CA8")
    # respaldo alto con tres agujas
    d.rectangle((9, 14, 36, 44), fill=dark)
    for cx, top in ((11, 2), (23, 0), (35, 2)):
        d.polygon([(cx - 4, 16), (cx + 4, 16), (cx, top)], fill=mid)
    d.rectangle((12, 17, 33, 41), fill=mid)
    d.rectangle((14, 19, 31, 39), fill=hexc("#D85CD5"))
    d.rectangle((15, 20, 30, 38), fill=hexc("#B0479F"))
    heart(d, 22.5, 28, 5, hexc("#F6B4E9"))
    # luna sobre el respaldo
    d.ellipse((19, 5, 27, 13), fill=hexc("#FFE18C"))
    d.ellipse((21, 4, 29, 12), fill=(0, 0, 0, 0))
    # asiento, brazos y patas
    d.rectangle((5, 40, 40, 47), fill=light)
    d.rectangle((7, 44, 38, 49), fill=hexc("#D85CD5"))
    d.rectangle((3, 34, 9, 52), fill=dark)
    d.rectangle((36, 34, 42, 52), fill=dark)
    d.ellipse((2, 31, 10, 38), fill=mid)
    d.ellipse((35, 31, 43, 38), fill=mid)
    d.rectangle((8, 50, 37, 60), fill=dark)
    d.rectangle((10, 52, 35, 58), fill=mid)
    star(d, 22.5, 55, 3, hexc("#FFE18C"))
    d.rectangle((2, 60, 43, 63), fill=dark)
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] > 0, 255, 0)
    return outline(arr)


# --------------------------------------------------------------- habitación
W, H = 480, 270
BED = {"head_x": 54, "foot_x": 344, "mattress_y": 182, "bottom_y": 230}


def make_bedroom():
    img = np.zeros((H, W, 4), np.uint8)
    # pared lavanda que se ilumina hacia la ventana (amanecer)
    dither_v(img, (0, 0, W, 214), "#8F6BC9", "#D9C2F2", 12)
    im = Image.fromarray(img, "RGBA")
    d = ImageDraw.Draw(im)
    # papel pintado: estrellitas y lunas pequeñas
    rng = np.random.default_rng(8)
    for _ in range(46):
        x, y = int(rng.integers(6, W - 6)), int(rng.integers(6, 200))
        if 350 <= x <= 462 and 36 <= y <= 152:
            continue
        if rng.random() < 0.7:
            star(d, x, y, 2.4, hexc("#F3E5FF"))
        else:
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=hexc("#F6B4E9"))
    # zócalo y suelo de madera
    d.rectangle((0, 206, W, 214), fill=hexc("#6B3F8F"))
    for y in range(214, H, 8):
        d.rectangle((0, y, W, y + 7), fill=hexc("#9A6440") if (y // 8) % 2 else hexc("#8A5636"))
        off = 37 * ((y // 8) % 3)
        for x in range(off % 60, W, 60):
            d.line((x, y, x, y + 7), fill=hexc("#5E3622"))
    # alfombra redonda
    d.ellipse((150, 238, 330, 266), fill=hexc("#F6B4E9"))
    d.ellipse((160, 242, 320, 262), fill=hexc("#D85CD5"))
    d.ellipse((176, 246, 304, 258), fill=hexc("#F6B4E9"))
    # ventana con el amanecer
    wx0, wy0, wx1, wy1 = 362, 44, 450, 146
    sky = np.array(im)
    dither_v(sky, (wx0, wy0, wx1, wy1), "#FFB38A", "#FFE6B0", 8)
    im = Image.fromarray(sky, "RGBA")
    d = ImageDraw.Draw(im)
    d.ellipse((392, 112, 428, 148), fill=hexc("#FFE18C"))  # sol naciente
    d.rectangle((wx0, 128, wx1, wy1), fill=hexc("#C8A5FF"))  # colinas lejanas
    d.ellipse((wx0 - 10, 118, wx0 + 50, 150), fill=hexc("#B08BEA"))
    d.ellipse((wx0 + 40, 122, wx1 + 10, 152), fill=hexc("#A07AE0"))
    d.rectangle((wx0 - 4, wy0 - 4, wx1 + 4, wy0), fill=hexc("#F3E5FF"))
    d.rectangle((wx0 - 4, wy1, wx1 + 4, wy1 + 5), fill=hexc("#F3E5FF"))
    d.rectangle((wx0 - 4, wy0, wx0, wy1), fill=hexc("#F3E5FF"))
    d.rectangle((wx1, wy0, wx1 + 4, wy1), fill=hexc("#F3E5FF"))
    d.rectangle(((wx0 + wx1) // 2 - 1, wy0, (wx0 + wx1) // 2 + 1, wy1), fill=hexc("#F3E5FF"))
    d.rectangle((wx0, (wy0 + wy1) // 2 - 1, wx1, (wy0 + wy1) // 2 + 1), fill=hexc("#F3E5FF"))
    # cortinas rosadas recogidas
    for cx, sgn in ((wx0 - 6, -1), (wx1 + 6, 1)):
        pts = [(cx - 12 * (sgn < 0) + 0, 34), (cx + 12 * (sgn > 0), 34), (cx + 12 * (sgn > 0) + 6 * sgn, 160), (cx - 12 * (sgn < 0) + 6 * sgn, 160)]
        d.polygon(pts, fill=hexc("#F6B4E9"))
        for k in range(3):
            xx = cx + sgn * (2 + 3 * k) - (6 if sgn < 0 else 0)
            d.line((xx, 36, xx + 2 * sgn, 158), fill=hexc("#D85CD5"))
        d.rectangle((cx - 9, 100, cx + 3, 104), fill=hexc("#D85CD5"))
    d.rectangle((wx0 - 24, 30, wx1 + 24, 34), fill=hexc("#6B3F8F"))
    # luz del amanecer en el suelo (trama)
    arr = np.array(im)
    for y in range(214, 250):
        for x in range(300 + (y - 214), 420 + (y - 214)):
            if 0 <= x < W and BAYER[y % 4, x % 4] < 0.35:
                arr[y, x, :3] = np.minimum(255, arr[y, x, :3].astype(int) + 40)
    im = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(im)
    # estantería con juguetes
    d.rectangle((150, 74, 250, 78), fill=hexc("#6B3F2A"))
    d.rectangle((158, 56, 166, 74), fill=hexc("#D85CD5"))
    d.rectangle((167, 60, 174, 74), fill=hexc("#5FB7F0"))
    d.rectangle((175, 58, 181, 74), fill=hexc("#FFE18C"))
    d.ellipse((190, 56, 208, 74), fill=hexc("#C89060"))  # osito
    d.ellipse((188, 52, 196, 60), fill=hexc("#C89060"))
    d.ellipse((202, 52, 210, 60), fill=hexc("#C89060"))
    d.ellipse((195, 62, 203, 70), fill=hexc("#F2D3B0"))
    d.rectangle((216, 64, 226, 74), fill=hexc("#FFA657"))  # bloques
    d.rectangle((228, 64, 238, 74), fill=hexc("#7EE07E"))
    d.rectangle((222, 54, 232, 64), fill=hexc("#F6B4E9"))
    # estrellas de papel colgantes
    for x, l, c in ((40, 40, "#FFE18C"), (110, 60, "#F6B4E9"), (280, 34, "#FFE18C"), (318, 54, "#C8F0FF")):
        d.line((x, 0, x, l), fill=hexc("#F3E5FF"))
        star(d, x, l + 5, 6, hexc(c))
    # mesita con lámpara de estrella
    d.rectangle((8, 186, 46, 230), fill=hexc("#7A4A2E"))
    d.rectangle((10, 196, 44, 198), fill=hexc("#5E3622"))
    d.rectangle((24, 170, 30, 186), fill=hexc("#F3E5FF"))
    d.polygon([(14, 170), (40, 170), (34, 154), (20, 154)], fill=hexc("#FFE18C"))
    star(d, 27, 163, 4, hexc("#FFA657"))
    # cama: cabecero de madera con corazón, colchón y almohadas (la colcha va aparte)
    hx, fx, my, by = BED["head_x"], BED["foot_x"], BED["mattress_y"], BED["bottom_y"]
    d.rectangle((hx - 8, 112, hx + 10, by + 6), fill=hexc("#8A5636"))
    d.ellipse((hx - 8, 100, hx + 10, 124), fill=hexc("#8A5636"))
    heart(d, hx + 1, 132, 5, hexc("#F6B4E9"))
    d.rectangle((fx - 6, 158, fx + 10, by + 6), fill=hexc("#8A5636"))
    d.ellipse((fx - 6, 150, fx + 10, 166), fill=hexc("#8A5636"))
    d.rectangle((hx + 10, my, fx - 6, by - 8), fill=hexc("#FFF6FF"))   # colchón
    d.rectangle((hx + 10, by - 8, fx - 6, by), fill=hexc("#C8A5FF"))   # somier
    d.ellipse((hx + 12, my - 22, hx + 74, my + 6), fill=hexc("#FFFFFF"))  # almohadas
    d.ellipse((hx + 14, my - 16, hx + 68, my + 6), fill=hexc("#F3E5FF"))
    d.ellipse((hx + 50, my - 18, hx + 104, my + 6), fill=hexc("#FFF0FB"))
    arr = np.array(im)
    arr[..., 3] = 255
    return arr


def make_blanket():
    """Colcha azul con corazones y ribete rosa; borde superior ondulado. Capa delantera."""
    hx, fx, my, by = BED["head_x"], BED["foot_x"], BED["mattress_y"], BED["bottom_y"]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x0, x1, top = hx + 64, fx - 2, my - 6
    pts = [(x0, by + 8)]
    for x in range(x0, x1 + 1, 4):
        pts.append((x, top + round(1.5 * math.sin(x / 9.0))))
    pts.append((x1, by + 8))
    d.polygon(pts, fill=hexc("#4E6FD6"))
    d.rectangle((x0, top + 3, x1, top + 7), fill=hexc("#F6B4E9"))
    for i, x in enumerate(range(x0 + 16, x1 - 8, 28)):
        for j, y in enumerate(range(top + 18, by + 4, 16)):
            if (i + j) % 2 == 0:
                heart(d, x, y, 3, hexc("#F6B4E9"))
            else:
                star(d, x, y, 3, hexc("#FFE18C"))
    d.line((x0, top + 2, x0, by + 8), fill=hexc("#35408F"))
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] > 0, 255, 0)
    return outline(arr, (30, 30, 80))


def main():
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(make_bedroom(), "RGBA").save(os.path.join(OUT, "bedroom.png"))
    Image.fromarray(make_blanket(), "RGBA").save(os.path.join(OUT, "bedroom_blanket.png"))
    Image.fromarray(make_throne(), "RGBA").save(os.path.join(OUT, "throne.png"))
    print("Extras del Mundo 8 ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
