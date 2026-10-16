"""
Pipeline de preparación de recursos — Guardiana de los Sueños, Mundo 1.

Uso:
    python tools/prepare_assets.py            # genera public/assets/**
    python tools/prepare_assets.py --debug    # además escribe tools/out/debug_*.png

Requisitos: Python 3.10+, Pillow y NumPy (`pip install pillow numpy`).

Pasos por fotograma (ver README, sección "Preparación de recursos"):
 1. Recorte con la caja definida en asset_sources.py.
 2. Eliminación del fondo: relleno por inundación desde el borde del recorte
    sobre los píxeles "parecidos al fondo" (los blancos interiores, como los
    ojos, se conservan porque no tocan el borde).
 3. Separación de efectos: se conserva la isla de píxeles más grande y las
    islas cuyo área supere un umbral; estrellitas, burbujas y salpicaduras
    sueltas se descartan (los efectos se extraen aparte como FX).
 4. Eliminación de la sombra de suelo (gris azulado) en la franja inferior.
 5. Reducción a la resolución lógica con promedio de alfa premultiplicado y
    alfa binario (sin bordes difuminados) + paleta común por personaje.
 6. Normalización: todos los fotogramas de un personaje comparten tamaño de
    celda y se alinean por los pies (o por el centro, en el jefe).
 7. Empaquetado en atlas JSON (formato hash de Phaser) + manifest.json con
    las animaciones. Las hitboxes se definen en el código del juego, no aquí.

Los originales de /imagenes nunca se modifican.
"""
import json
import math
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asset_sources as S  # noqa: E402

OUT = os.path.join(ROOT, "public", "assets")
DEBUG = "--debug" in sys.argv
REPORT = []

_cache = {}


def src_img(name):
    if name not in _cache:
        path = os.path.join(ROOT, S.SRC[name])
        _cache[name] = np.array(Image.open(path).convert("RGBA"))
    return _cache[name]


# ---------------------------------------------------------------------------
# Segmentación
# ---------------------------------------------------------------------------
def bg_like(rgba, mode):
    rgb = rgba[..., :3].astype(int)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = mx - mn
    if mode == "white":
        return np.abs(rgb - np.array([254, 254, 255])).sum(-1) < 50
    if mode == "grey":
        return (sat < 30) & (mx < 232) & (mx > 40)
    if mode == "grey_soft":
        return (sat < 14) & (mx < 236) & (mx > 40)
    raise ValueError(mode)


def flood_from_border(cand):
    """Marca como fondo los píxeles candidatos conectados con el borde."""
    h, w = cand.shape
    bg = np.zeros_like(cand)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if cand[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if cand[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    return bg


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    areas = [0]
    n = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        q = deque([(y0, x0)])
        a = 0
        while q:
            y, x = q.popleft()
            a += 1
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1),
                           (y + 1, x + 1), (y - 1, x - 1), (y + 1, x - 1), (y - 1, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    q.append((ny, nx))
        areas.append(a)
    return lab, areas


def keep_main(mask, keep=0.2):
    lab, areas = components(mask)
    if len(areas) <= 1:
        return mask
    big = max(areas[1:])
    keepset = [i for i, a in enumerate(areas) if i > 0 and a >= keep * big]
    return np.isin(lab, keepset)


def shadow_mask(rgba, fg):
    """Píxeles de sombra de suelo (gris azulado) en la franja inferior del sprite."""
    ys = np.nonzero(fg.any(1))[0]
    if len(ys) == 0:
        return np.zeros_like(fg)
    y0, y1 = ys[0], ys[-1]
    band = int(y1 - (y1 - y0) * 0.14)
    rgb = rgba[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    sh = (r > 120) & (r < 228) & ((b - r) > 4) & ((b - r) < 50) & (np.abs(g - r) < 22)
    rows = np.zeros_like(fg)
    rows[band:, :] = True
    return fg & sh & rows


def extract(src, mode, box, opts=None, shadow=False):
    """Devuelve un recorte RGBA (uint8) del sprite sin fondo, ajustado a su contenido."""
    opts = opts or {}
    img = src_img(src)
    x0, y0, x1, y1 = box
    pad = 3
    H, W = img.shape[:2]
    cx0, cy0 = max(0, x0 - pad), max(0, y0 - pad)
    cx1, cy1 = min(W, x1 + pad + 1), min(H, y1 + pad + 1)
    crop = img[cy0:cy1, cx0:cx1].copy()
    # Lo que queda fuera de la caja pertenece a otro dibujo: se trata como fondo.
    outside = np.ones(crop.shape[:2], bool)
    outside[y0 - cy0:y1 - cy0 + 1, x0 - cx0:x1 - cx0 + 1] = False
    if mode == "alpha":
        r, g, b, a = [crop[..., i].astype(int) for i in range(4)]
        fringe = (r > 170) & (b > 170) & (g < 150) & ((r - g) > 60)
        fg = (a > 200) & ~fringe & ~outside
    else:
        cand = bg_like(crop, mode) | outside
        fg = ~flood_from_border(cand) & ~outside
        if shadow:
            # Al quitar la sombra, el fondo que quedaba encerrado entre los pies
            # vuelve a tocar el borde: se inunda de nuevo.
            cand |= shadow_mask(crop, fg)
            fg = ~flood_from_border(cand) & ~outside
    if not opts.get("nocomp"):
        fg = keep_main(fg, opts.get("keep", 0.2))
    ys, xs = np.nonzero(fg)
    if len(ys) == 0:
        raise RuntimeError(f"Recorte vacío: {src} {box}")
    by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = crop[by0:by1, bx0:bx1].copy()
    out[..., 3] = np.where(fg[by0:by1, bx0:bx1], 255, 0)
    return out


def downscale(rgba, scale=None, size=None):
    h, w = rgba.shape[:2]
    if size:
        nw, nh = size
    else:
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    a = rgba[..., 3].astype(np.float32) / 255.0
    chans = []
    for i in range(3):
        c = rgba[..., i].astype(np.float32) * a
        chans.append(np.array(Image.fromarray(c, "F").resize((nw, nh), Image.BOX)))
    na = np.array(Image.fromarray(a, "F").resize((nw, nh), Image.BOX))
    rgb = np.stack(chans, -1) / np.maximum(na[..., None], 1e-4)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(na >= 0.5, 255, 0)
    return out


def make_palette(frames, colors):
    px = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames], 0)
    if len(px) == 0:
        return None
    strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)


def apply_palette(rgba, pal):
    if pal is None:
        return rgba
    rgb = Image.fromarray(rgba[..., :3], "RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = rgba.copy()
    out[..., :3] = np.array(rgb)
    return out


def darken_edges(rgba, amount=0.55):
    """Refuerza el contorno: los píxeles opacos que tocan transparencia se oscurecen
    si son claros, para que el sprite se lea sobre fondos pastel."""
    a = rgba[..., 3] > 0
    pad = np.pad(a, 1)
    edge = a & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out = rgba.copy()
    lum = rgba[..., :3].astype(int).mean(-1)
    sel = edge & (lum > 120)
    out[sel, :3] = (out[sel, :3].astype(float) * amount).astype(np.uint8)
    return out


# ---------------------------------------------------------------------------
# Atlas
# ---------------------------------------------------------------------------
def pack(images, max_w=1024, padding=2):
    items = sorted(images.items(), key=lambda kv: (-kv[1].shape[0], kv[0]))
    x = y = padding
    shelf_h = 0
    pos = {}
    width = 0
    for name, im in items:
        h, w = im.shape[:2]
        if x + w + padding > max_w:
            x = padding
            y += shelf_h + padding
            shelf_h = 0
        pos[name] = (x, y)
        x += w + padding
        width = max(width, x)
        shelf_h = max(shelf_h, h)
    height = y + shelf_h + padding
    W = 1 << math.ceil(math.log2(max(width, 2)))
    Hh = 1 << math.ceil(math.log2(max(height, 2)))
    sheet = np.zeros((Hh, W, 4), np.uint8)
    frames = {}
    for name, im in images.items():
        px, py = pos[name]
        h, w = im.shape[:2]
        sheet[py:py + h, px:px + w] = im
        frames[name] = {
            "frame": {"x": px, "y": py, "w": w, "h": h},
            "rotated": False, "trimmed": False,
            "spriteSourceSize": {"x": 0, "y": 0, "w": w, "h": h},
            "sourceSize": {"w": w, "h": h},
        }
    return sheet, frames


def save_atlas(rel_dir, key, images):
    sheet, frames = pack(images)
    d = os.path.join(OUT, rel_dir)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, f"{key}.png"))
    data = {"frames": frames, "meta": {
        "app": "tools/prepare_assets.py", "image": f"{key}.png", "format": "RGBA8888",
        "size": {"w": sheet.shape[1], "h": sheet.shape[0]}, "scale": "1"}}
    with open(os.path.join(d, f"{key}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    return {"key": key, "png": f"assets/{rel_dir}/{key}.png", "json": f"assets/{rel_dir}/{key}.json"}


# ---------------------------------------------------------------------------
# Personajes
# ---------------------------------------------------------------------------
def feet_anchor(im):
    a = im[..., 3] > 0
    h = a.shape[0]
    rows = max(2, int(h * 0.12))
    xs = np.nonzero(a[h - rows:])[1]
    return float(xs.mean()) if len(xs) else im.shape[1] / 2


def build_character(key, cfg):
    raw = {}
    for anim, a in cfg["anims"].items():
        for i, box in enumerate(a["boxes"]):
            ex = extract(cfg["src"], cfg["mode"], box, shadow=cfg.get("shadow", False))
            raw[(anim, i)] = downscale(ex, cfg["scale"])
    pal = make_palette(list(raw.values()), cfg.get("colors", 32))
    scaled = {k: darken_edges(apply_palette(v, pal), 0.7) for k, v in raw.items()}

    if cfg["anchor"] == "feet":
        anchors = {k: feet_anchor(v) for k, v in scaled.items()}
        half = max(max(anchors[k], v.shape[1] - anchors[k]) for k, v in scaled.items())
        cw = int(math.ceil(half)) * 2 + 2
        ch = max(v.shape[0] for v in scaled.values()) + 2
    else:
        cw = max(v.shape[1] for v in scaled.values()) + 2
        ch = max(v.shape[0] for v in scaled.values()) + 2
    cw += cw % 2
    ch += ch % 2

    cells = {}
    for (anim, i), im in scaled.items():
        h, w = im.shape[:2]
        cell = np.zeros((ch, cw, 4), np.uint8)
        if cfg["anchor"] == "feet":
            x = int(round(cw / 2 - anchors[(anim, i)]))
            y = ch - h - 1
        else:
            x = (cw - w) // 2
            y = (ch - h) // 2
        x = max(0, min(cw - w, x))
        cell[y:y + h, x:x + w] = im
        cells[f"{anim}_{i}"] = cell

    anims = {}
    for anim, a in cfg["anims"].items():
        anims[anim] = {"frames": [f"{anim}_{i}" for i in range(len(a["boxes"]))],
                       "frameRate": a["fps"], "repeat": a["repeat"]}
    for anim, d in cfg.get("derived", {}).items():
        if "from" in d:
            frames = anims[d["from"]]["frames"]
        else:
            frames = [f"{a}_{i}" for a, i in d["frames"]]
        anims[anim] = {"frames": frames, "frameRate": d["fps"], "repeat": d["repeat"], "derived": True}

    folder = {"player": "player", "nubarron": "bosses"}.get(key, "enemies")
    entry = save_atlas(folder, key, cells)
    entry.update({"frameWidth": cw, "frameHeight": ch, "anims": anims})
    REPORT.append(f"| {key} | {len(cells)} fotogramas | celda {cw}x{ch} | extraído de {S.SRC[cfg['src']]} |")
    return entry, cells


# ---------------------------------------------------------------------------
# Tileset del terreno
# ---------------------------------------------------------------------------
OUTLINE = np.array([38, 44, 112], np.uint8)


def tile_from(box, mode="grey", alpha=True, colors=12):
    img = src_img("tiles")
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1].copy()
    if alpha:
        fg = ~flood_from_border(bg_like(crop, mode))
        crop[..., 3] = np.where(fg, 255, 0)
    else:
        crop[..., 3] = 255
    t = downscale(crop, size=(16, 16))
    pal = make_palette([t], colors)
    return apply_palette(t, pal)


def bumpy_bottom(t, base=12):
    out = t.copy()
    for x in range(16):
        edge = base + int(round(2.2 * abs(math.sin(math.pi * (x + 0.5) / 8))))
        out[edge + 1:, x, 3] = 0
        out[edge, x, :3] = OUTLINE
        out[edge, x, 3] = 255
    return out


def side(t, left=True, right=True):
    out = t.copy()
    for y in range(16):
        xs = np.nonzero(out[y, :, 3])[0]
        if len(xs) == 0:
            continue
        if left:
            out[y, 0, :3] = OUTLINE
            out[y, 0, 3] = 255 if out[y, 1, 3] else 0
        if right:
            out[y, 15, :3] = OUTLINE
            out[y, 15, 3] = 255 if out[y, 14, 3] else 0
    # esquina redondeada superior
    tops = [np.nonzero(out[:, x, 3])[0] for x in range(16)]
    for x, ys in enumerate(tops):
        if len(ys) == 0:
            continue
        if (left and x == 0) or (right and x == 15):
            out[ys[0]:ys[0] + 2, x, 3] = 0
        if (left and x == 1) or (right and x == 14):
            out[ys[0], x, 3] = 0
            out[ys[0] + 1, x, :3] = OUTLINE
    return out


def build_tileset():
    top = tile_from(S.GROUND_TOP, alpha=True, colors=14)
    fill = tile_from(S.GROUND_FILL, alpha=False, colors=8)
    bottom = bumpy_bottom(fill)
    plat = top.copy()
    plat[12:] = bumpy_bottom(fill)[12:]
    plat = bumpy_bottom(plat, 12)
    plat[:12] = top[:12]

    def four(t):
        return [side(t, True, True), side(t, True, False), t, side(t, False, True)]

    tiles = four(top) + four(plat) + four(fill) + four(bottom)
    names = {}
    for i, (name, box) in enumerate(S.BLOCKS):
        ex = extract("tiles", "grey", box)
        b = downscale(ex, size=(16, 16))
        b = apply_palette(b, make_palette([b], 12))
        tiles.append(b)
        names[name] = 16 + i
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    sheet = np.zeros((rows * 16, cols * 16, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16] = t
    d = os.path.join(OUT, "tilesets", "world1")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, "world1_tiles.png"))
    REPORT.append("| world1_tiles | 16 teselas de terreno + %d bloques | 16x16 | texturas extraídas de la hoja de teselas; bordes y base redondeada generados por el script |" % len(S.BLOCKS))
    return {
        "key": "world1_tiles", "png": "assets/tilesets/world1/world1_tiles.png", "tileSize": 16,
        "terrain": {"top": [0, 1, 2, 3], "plat": [4, 5, 6, 7], "fill": [8, 9, 10, 11], "bottom": [12, 13, 14, 15]},
        "blocks": names,
    }


# ---------------------------------------------------------------------------
# Fondos generados (cielo y bancos de nubes repetibles)
# ---------------------------------------------------------------------------
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def gen_sky(w=480, h=270):
    stops = [(0.0, "#3455A4"), (0.45, "#78C5F8"), (0.8, "#B9D8FA"), (1.0, "#F7C6E6")]
    bands = 14
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 3] = 255
    for y in range(h):
        t = y / (h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                u = (t - t0) / (t1 - t0)
                break
        q = u * bands
        lo = math.floor(q)
        frac = q - lo
        for x in range(w):
            k = lo + (1 if frac > BAYER[y % 4, x % 4] else 0)
            k = min(k, bands) / bands
            img[y, x, :3] = (hex_rgb(c0) * (1 - k) + hex_rgb(c1) * k).astype(np.uint8)
    return img


def gen_cloudbank(w, h, colors, seed, base):
    rng = np.random.default_rng(seed)
    hi, mid, low, outline = [hex_rgb(c) for c in colors]
    yy, xx = np.mgrid[0:h, 0:w]
    inside = np.zeros((h, w), bool)
    shade = np.zeros((h, w))
    n = int(w / 18)
    for i in range(n):
        cx = (i + rng.random() * 0.6) * w / n
        r = rng.uniform(10, 22)
        cy = base + rng.uniform(-8, 6)
        for off in (-w, 0, w):  # repetición horizontal sin costuras
            d = np.sqrt((xx - cx - off) ** 2 + (yy - cy) ** 2)
            m = d < r
            inside |= m
            shade = np.where(m, np.maximum(shade, 1 - (yy - (cy - r)) / (2 * r)), shade)
    inside |= yy > base + 8
    img = np.zeros((h, w, 4), np.uint8)
    col = np.where(shade[..., None] > 0.62, hi, np.where(shade[..., None] > 0.35, mid, low))
    col = np.where((yy > base + 8)[..., None] & (shade[..., None] == 0), low, col)
    img[..., :3] = col.astype(np.uint8)
    img[..., 3] = np.where(inside, 255, 0)
    pad = np.pad(inside, 1)
    edge = inside & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & np.roll(pad, 1, 1)[1:-1, 1:-1] & np.roll(pad, -1, 1)[1:-1, 1:-1])
    img[edge, :3] = outline.astype(np.uint8)
    return img


def gen_portal(frames=6, size=40):
    out = {}
    cols = [hex_rgb(c) for c in ("#F7A8D8", "#B9A7F4", "#78C5F8", "#FFE082", "#FFF7FF")]
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    d = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 0.8) ** 2)
    ang = np.arctan2(yy - cy, xx - cx)
    for f in range(frames):
        img = np.zeros((size, size, 4), np.uint8)
        m = d < size / 2 - 1
        band = ((d / 3.2 - ang * 1.6 / math.pi + f * 2 / frames) % len(cols)).astype(int)
        img[m, :3] = np.array(cols)[band[m]].astype(np.uint8)
        img[m, 3] = 255
        ring = m & (d > size / 2 - 3)
        img[ring, :3] = hex_rgb("#3455A4").astype(np.uint8)
        out[f"portal_{f}"] = img
    return out


HEART = [
    ".##.##.",
    "#######",
    "#######",
    ".#####.",
    "..###..",
    "...#...",
]


def gen_hearts():
    res = {}
    for name, fill in (("heart_full", "#F7489A"), ("heart_empty", "#5B4E86")):
        h, w = len(HEART) + 2, len(HEART[0]) + 2
        img = np.zeros((h, w, 4), np.uint8)
        for y, row in enumerate(HEART):
            for x, c in enumerate(row):
                if c == "#":
                    img[y + 1, x + 1, :3] = hex_rgb(fill)
                    img[y + 1, x + 1, 3] = 255
        a = img[..., 3] > 0
        pad = np.pad(a, 1)
        around = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~a
        img[around, :3] = hex_rgb("#2A2350")
        img[around, 3] = 255
        if name == "heart_full":
            img[2, 2, :3] = 255
            img[2, 3, :3] = 255
        res[name] = img
    return res


# ---------------------------------------------------------------------------
def simple_set(spec, edges=True):
    imgs = {}
    for name, (src, mode, box, scale, opts) in spec.items():
        ex = extract(src, mode, box, opts)
        im = downscale(ex, scale, opts.get("size"))
        im = apply_palette(im, make_palette([im], opts.get("colors", 16)))
        if edges:
            im = darken_edges(im, 0.8)
        imgs[name] = im
    return imgs


def main():
    manifest = {"version": 1, "generatedBy": "tools/prepare_assets.py",
                "characters": {}, "atlases": [], "images": [], "tileset": None}
    previews = {}

    for key, cfg in S.CHARACTERS.items():
        entry, cells = build_character(key, cfg)
        manifest["characters"][key] = entry
        previews[key] = cells

    fx = simple_set(S.FX)
    fx.update(gen_portal())
    fx.update(gen_hearts())
    manifest["atlases"].append(save_atlas("fx", "fx", fx))
    REPORT.append("| fx | %d imágenes | proyectiles/iconos extraídos; portal_* y heart_* generados por el script |" % len(fx))

    objs = simple_set(S.OBJECTS)
    manifest["atlases"].append(save_atlas("tilesets/world1", "world1_objects", objs))
    REPORT.append("| world1_objects | %d objetos | extraídos de la hoja de teselas |" % len(objs))

    bg = simple_set(S.BACKGROUND, edges=False)
    manifest["atlases"].append(save_atlas("backgrounds/world1", "world1_bg", bg))
    REPORT.append("| world1_bg | %d elementos | islas, luna y castillo extraídos de la hoja de teselas |" % len(bg))

    d = os.path.join(OUT, "backgrounds", "world1")
    Image.fromarray(gen_sky(), "RGBA").save(os.path.join(d, "sky.png"))
    Image.fromarray(gen_cloudbank(512, 110, ("#FFF7FF", "#F2D7F7", "#D9C4F4", "#B9A7F4"), 3, 50), "RGBA").save(os.path.join(d, "clouds_far.png"))
    Image.fromarray(gen_cloudbank(512, 80, ("#FFF7FF", "#FBD3EC", "#F7A8D8", "#D88CC0"), 11, 34), "RGBA").save(os.path.join(d, "clouds_near.png"))
    for k in ("sky", "clouds_far", "clouds_near"):
        manifest["images"].append({"key": k, "png": f"assets/backgrounds/world1/{k}.png"})
    REPORT.append("| sky / clouds_far / clouds_near | 3 imágenes | generadas proceduralmente con la paleta del mundo (no existen en las referencias) |")

    manifest["tileset"] = build_tileset()

    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)

    with open(os.path.join(OUT, "ASSETS_REPORT.md"), "w", encoding="utf-8") as f:
        f.write("# Informe de recursos generados\n\nGenerado por `tools/prepare_assets.py`.\n\n")
        f.write("| Recurso | Contenido | Detalle |\n|---|---|---|\n")
        f.write("\n".join(REPORT) + "\n")

    if DEBUG:
        dd = os.path.join(HERE, "out")
        os.makedirs(dd, exist_ok=True)
        for key, cells in previews.items():
            names = sorted(cells)
            ch, cw = cells[names[0]].shape[:2]
            sheet = Image.new("RGBA", (cw * len(names), ch), (120, 170, 230, 255))
            for i, n in enumerate(names):
                im = Image.fromarray(cells[n], "RGBA")
                sheet.alpha_composite(im, (i * cw, 0))
            sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
            sheet.save(os.path.join(dd, f"debug_{key}.png"))
        for name, imgs in (("fx", fx), ("objects", objs), ("bg", bg)):
            sheet, _ = pack(imgs)
            im = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), (120, 170, 230, 255))
            im.alpha_composite(Image.fromarray(sheet, "RGBA"))
            im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(dd, f"debug_{name}.png"))
        ts = Image.open(os.path.join(OUT, "tilesets", "world1", "world1_tiles.png"))
        bgim = Image.new("RGBA", ts.size, (120, 170, 230, 255))
        bgim.alpha_composite(ts)
        bgim.resize((ts.width * 6, ts.height * 6), Image.NEAREST).save(os.path.join(dd, "debug_tiles.png"))
    print("OK ->", OUT)


if __name__ == "__main__":
    main()
