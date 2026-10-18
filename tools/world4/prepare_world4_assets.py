"""
Pipeline de recursos del Mundo 4 — Reino de las Burbujas.

Uso (desde la raíz del repositorio):
    python tools/world4/prepare_world4_assets.py            # genera recursos y datos del Mundo 4
    python tools/world4/prepare_world4_assets.py --debug    # además: tools/out/world4/*.png

Requisitos: Python 3.10+, Pillow, NumPy y SciPy.

Las cuatro imágenes oficiales del Mundo 4 son hojas de ilustración, no spritesheets: tienen títulos,
paneles, etiquetas y dibujos de tamaños distintos. Cada fotograma u objeto se describe con su caja en
tools/world4/world4_sources.json (editable a mano). Por cada recorte:
 1. Se separa del fondo: alfa >= umbral en la hoja del jefe; en las demás sólo se elimina el fondo
    pastel conectado con el borde del recorte (los blancos de la espuma interior no se tocan).
    `only` limita el recorte a zonas (rectángulos o polígonos) cuando dos dibujos se tocan.
 2. Se conserva la isla principal (y las grandes) y se descartan burbujas sueltas.
 3. Se reduce a la resolución lógica del juego con promedio de alfa premultiplicado y alfa binario
    (sin bordes difuminados), paleta común por personaje y refuerzo del contorno (las mismas funciones
    que tools/prepare_assets.py del Mundo 1). Nada se suaviza en Godot: filtro nearest.
 4. Los fotogramas de cada personaje se normalizan a una celda común alineada por abajo y con un pivote
    horizontal estable (pies, centro del dibujo o centro del cuerpo amarillo del pato).
 5. Se empaqueta en atlas y se escriben los JSON que consume Godot (mismo formato que los Mundos 1-3)
    y un manifiesto con origen, caja, animación, duración, offset y validación.
Los originales nunca se modifican.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import prepare_assets as P  # noqa: E402  (funciones de reducción, paleta, contorno y atlas del Mundo 1)

CFG = json.load(open(os.path.join(HERE, "world4_sources.json"), encoding="utf-8"))
GODOT = os.path.join(ROOT, "godot")
RES = "resources/world4"
OUT_RES = os.path.join(GODOT, *RES.split("/"))
OUT_DATA = os.path.join(GODOT, "data", "world4")
DEBUG = "--debug" in sys.argv
DEBUG_DIR = os.path.join(ROOT, "tools", "out", "world4")

_cache = {}
MANIFEST = {"version": 1, "generatedBy": "tools/world4/prepare_world4_assets.py", "sources": CFG["sources"], "resources": []}


def src(name):
    if name not in _cache:
        _cache[name] = np.array(Image.open(os.path.join(ROOT, CFG["sources"][name])).convert("RGBA"))
    return _cache[name]


# ---------------------------------------------------------------------------
# Segmentación
# ---------------------------------------------------------------------------
def cream_bg(rgba):
    rgb = rgba[..., :3].astype(int)
    mx, mn = rgb.max(-1), rgb.min(-1)
    return (mx >= 232) & ((mx - mn) < 28)


def panel_bg(rgba, distance=42):
    """Candidato de fondo pastel según la mediana del borde del recorte."""
    rgb = rgba[..., :3].astype(np.int16)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    base = np.median(border, axis=0)
    return np.sqrt(((rgb - base) ** 2).sum(axis=2)) <= distance


def flood(cand):
    """Fondo = candidatos conectados con el borde del recorte."""
    lab, _ = ndimage.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))


def keep_main(mask, keep):
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n <= 1:
        return mask
    areas = ndimage.sum(mask, lab, range(1, n + 1))
    big = areas.max()
    keepset = [i + 1 for i, a in enumerate(areas) if a >= keep * big]
    return np.isin(lab, keepset)


def unpack_box(entry):
    """Una caja es [x0,y0,x1,y1] o {box, only, ...}: devuelve (caja, opciones propias)."""
    if isinstance(entry, dict):
        return entry["box"], {k: v for k, v in entry.items() if k != "box"}
    return entry, {}


def extract(src_name, mode, box, opts):
    """Recorte RGBA sin fondo ajustado a su contenido. Devuelve (imagen, info de validación)."""
    img = src(src_name)
    x0, y0, x1, y1 = box
    crop = img[y0:y1 + 1, x0:x1 + 1].copy()
    if mode == "alpha":
        fg = crop[..., 3] >= opts.get("alpha_min", 240)
    elif mode == "opaque":
        fg = np.ones(crop.shape[:2], bool)
    elif mode == "panel":
        fg = ~flood(panel_bg(crop, opts.get("distance", 30)))
    else:
        fg = ~flood(cream_bg(crop))
    if "only" in opts:
        canvas = Image.new("L", (fg.shape[1], fg.shape[0]), 0)
        draw = ImageDraw.Draw(canvas)
        for zone in opts["only"]:
            if isinstance(zone[0], list):
                draw.polygon([(px - x0, py - y0) for px, py in zone], fill=255)
            else:
                ax0, ay0, ax1, ay1 = zone
                draw.rectangle((ax0 - x0, ay0 - y0, ax1 - x0, ay1 - y0), fill=255)
        fg &= np.array(canvas) > 0
    if not opts.get("nocomp"):
        fg = keep_main(fg, opts.get("keep", 0.2))
    ys, xs = np.nonzero(fg)
    if len(ys) == 0:
        raise RuntimeError(f"Recorte vacío: {src_name} {box}")
    by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = crop[by0:by1, bx0:bx1].copy()
    out[..., 3] = np.where(fg[by0:by1, bx0:bx1], 255, 0)
    # Validación: si el sprite toca el borde de la caja y la imagen sigue opaca fuera de ella,
    # probablemente la caja corta el dibujo (salvo si `only` lo recorta a propósito).
    touches = []
    H, W = img.shape[:2]
    if "only" not in opts:
        if by0 == 0 and y0 > 0 and _opaque_outside(img, mode, slice(x0 + bx0, x0 + bx1), y0 - 1, True):
            touches.append("arriba")
        if by1 == crop.shape[0] and y1 + 1 < H and _opaque_outside(img, mode, slice(x0 + bx0, x0 + bx1), y1 + 1, True):
            touches.append("abajo")
        if bx0 == 0 and x0 > 0 and _opaque_outside(img, mode, slice(y0 + by0, y0 + by1), x0 - 1, False):
            touches.append("izquierda")
        if bx1 == crop.shape[1] and x1 + 1 < W and _opaque_outside(img, mode, slice(y0 + by0, y0 + by1), x1 + 1, False):
            touches.append("derecha")
    info = {"trim": [int(x0 + bx0), int(y0 + by0), int(x0 + bx1 - 1), int(y0 + by1 - 1)], "touches": touches}
    return out, info


def _opaque_outside(img, mode, span, at, row):
    line = img[at, span] if row else img[span, at]
    if mode == "alpha":
        return (line[..., 3] >= 240).mean() > 0.15
    return False  # en las hojas sin alfa el fondo del panel es continuo: no se puede deducir


def status_of(info, override=None, name=None):
    if override in ("ok", "pending"):
        return override
    if info["touches"] and name in CFG.get("reviewed", {}):
        return "ok"
    return "pending" if info["touches"] else "ok"


def notes_of(info, name, default=""):
    if not info["touches"]:
        return default
    msg = "toca el borde de la caja: " + ", ".join(info["touches"])
    if name in CFG.get("reviewed", {}):
        msg += " | revisado a mano: " + CFG["reviewed"][name]
    return msg


def finish(im, colors, edges=0.8):
    im = P.apply_palette(im, P.make_palette([im], colors))
    return P.darken_edges(im, edges) if edges else im


# ---------------------------------------------------------------------------
# Personajes
# ---------------------------------------------------------------------------
def anchor_of(im, mode):
    """Pivote horizontal del fotograma reducido."""
    a = im[..., 3] > 0
    if mode == "centroid":
        xs = np.nonzero(a)[1]
        return float(xs.mean()) if len(xs) else im.shape[1] / 2
    if mode == "yellow":
        rgb = im[..., :3].astype(int)
        yellow = a & (rgb[..., 0] > 200) & (rgb[..., 1] > 150) & (rgb[..., 2] < 140)
        xs = np.nonzero(yellow)[1]
        if len(xs) > 20:
            return float(xs.mean())
        return anchor_of(im, "centroid")
    return P.feet_anchor(im)


def build_character(key, c):
    raw, infos = {}, {}
    for anim, a in c["anims"].items():
        for i, entry in enumerate(a["boxes"]):
            box, own = unpack_box(entry)
            ex, info = extract(c["src"], c["mode"], box, {**c, **own})
            raw[(anim, i)] = P.downscale(ex, c["scale"])
            infos[(anim, i)] = (box, info, a)
    pal = P.make_palette(list(raw.values()), c.get("colors", 32))
    scaled = {k: P.darken_edges(P.apply_palette(v, pal), 0.7) for k, v in raw.items()}
    anchors = {k: anchor_of(v, c.get("anchor", "feet")) for k, v in scaled.items()}
    half = max(max(anchors[k], v.shape[1] - anchors[k]) for k, v in scaled.items())
    cw = int(math.ceil(half)) * 2 + 2
    ch = max(v.shape[0] for v in scaled.values()) + 2
    cw += cw % 2
    ch += ch % 2
    cells = {}
    for (anim, i), im in scaled.items():
        h, w = im.shape[:2]
        cell = np.zeros((ch, cw, 4), np.uint8)
        x = max(0, min(cw - w, int(round(cw / 2 - anchors[(anim, i)]))))
        y = ch - h - 1
        cell[y:y + h, x:x + w] = im
        name = f"{anim}_{i}"
        cells[name] = cell
        box, info, a = infos[(anim, i)]
        MANIFEST["resources"].append({
            "name": f"{key}/{name}", "type": "frame", "source": CFG["sources"][c["src"]],
            "crop": box, "trimmed": info["trim"], "animation": anim, "frame": i,
            "duration_ms": round(1000 / a["fps"]), "offset": [x, y], "origin": [cw // 2, ch - 1],
            "cell": [cw, ch], "anchor": c.get("anchor", "feet"), "status": status_of(info, a.get("status"), f"{key}/{name}"),
            "notes": notes_of(info, f"{key}/{name}", a.get("note", "")),
        })
    anims = {a: {"frames": [f"{a}_{i}" for i in range(len(v["boxes"]))], "fps": v["fps"], "loop": v["loop"], "derived": False}
             for a, v in c["anims"].items()}
    return cells, {"frameWidth": cw, "frameHeight": ch, "anims": anims, "name": c["name"]}


# ---------------------------------------------------------------------------
# Objetos sueltos
# ---------------------------------------------------------------------------
def build_set(spec, default_src="tiles", default_mode="panel", kind="object"):
    imgs = {}
    for name, o in spec.items():
        s = o.get("src", default_src)
        mode = o.get("mode", default_mode)
        ex, info = extract(s, mode, o["box"], o)
        im = P.downscale(ex, o["scale"])
        im = finish(im, o.get("colors", 20), 0.0 if kind == "background" or mode == "opaque" else 0.8)
        if o.get("fade_bottom"):
            n = min(int(o["fade_bottom"]), im.shape[0])
            ramp = np.linspace(1.0, 0.0, n)[:, None]
            im[-n:, :, 3] = (im[-n:, :, 3] * ramp).astype(np.uint8)
        imgs[name] = im
        MANIFEST["resources"].append({
            "name": name, "type": kind, "source": CFG["sources"][s], "crop": o["box"], "trimmed": info["trim"],
            "size": [im.shape[1], im.shape[0]], "origin": "según la escena (centro o pies)",
            "status": status_of(info, o.get("status"), name),
            "notes": notes_of(info, name, o.get("note", "")),
        })
    return imgs


def gen_whirl(size=22):
    """Remolino de agua (no existe suelto en las hojas): espiral con los azules y blancos del jefe."""
    boss = src("boss")
    a = boss[..., 3] >= 200
    rgb = boss[..., :3].astype(int)
    water = a & (rgb[..., 2] > 200) & (rgb[..., 0] < 150)
    cols = rgb[water]
    deep = np.median(cols[cols[..., 1] < 170], axis=0) if (cols[..., 1] < 170).any() else np.array([40, 120, 230])
    light = np.median(cols[cols[..., 1] >= 170], axis=0) if (cols[..., 1] >= 170).any() else np.array([140, 210, 255])
    img = np.zeros((size, size, 4), np.uint8)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, (y - c) * 1.6  # elipse aplanada, como el remolino de la hoja
            r = math.hypot(dx, dy)
            if r > c:
                continue
            ang = math.atan2(dy, dx)
            band = (ang / (2 * math.pi) * 3 + r / 3.2) % 1.0
            if band < 0.42:
                col = (255, 255, 255) if band < 0.14 else light
            elif r < c * 0.25:
                col = light
            else:
                col = deep
            img[y, x, :3] = col
            img[y, x, 3] = 255
    return P.darken_edges(img, 0.7)


def save_atlas(key, images, sub):
    sheet, frames = P.pack(images)
    d = os.path.join(OUT_RES, sub)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, f"{key}.png"))
    conv = {n: [f["frame"]["x"], f["frame"]["y"], f["frame"]["w"], f["frame"]["h"], 0, 0, f["frame"]["w"], f["frame"]["h"]]
            for n, f in frames.items()}
    return {"texture": f"res://{RES}/{sub}/{key}.png", "size": [sheet.shape[1], sheet.shape[0]], "frames": conv}


# ---------------------------------------------------------------------------
# Terreno 16x16: dos materiales (esponja y azulejo) en bloques de 32x32
# ---------------------------------------------------------------------------
def block32(box, colors=14):
    """Bloque de la hoja reducido a 32x32 (2x2 teselas) sin el fondo del panel."""
    # tolerancia baja: la espuma blanca se parece mucho al fondo lavanda del panel
    ex, info = extract("tiles", "panel", box, {"keep": 0.2, "distance": 12})
    b = P.downscale(ex, size=(32, 32))
    return P.apply_palette(b, P.make_palette([b], colors)), info


def side(t, left, right, outline):
    out = t.copy()
    for y in range(16):
        for x, on in ((0, left), (15, right)):
            if on and out[y, x, 3]:
                out[y, x, :3] = outline
                out[y, x, 3] = 255
    if left or right:
        tops = [np.nonzero(out[:, x, 3])[0] for x in range(16)]
        for x, ys in enumerate(tops):
            if len(ys) and ((left and x == 0) or (right and x == 15)):
                out[ys[0]:ys[0] + 2, x, 3] = 0  # esquina redondeada
    return out


def bumpy(t, outline, base=12):
    out = t.copy()
    for x in range(16):
        edge = base + int(round(2.2 * abs(math.sin(math.pi * (x + 0.5) / 8))))
        out[edge + 1:, x, 3] = 0
        out[edge, x, :3] = outline
        out[edge, x, 3] = 255
    return out


def solid_below_foam(t):
    """La espuma no deja huecos transparentes por encima del material."""
    out = t.copy()
    for x in range(16):
        col = np.nonzero(out[:, x, 3])[0]
        if len(col):
            out[col[0]:, x, 3] = 255
    return out


def ramp(body, cap, outline, rising_right):
    """Rampa de 45 grados: material bajo la diagonal y una franja de espuma encima."""
    foam = cap[cap[..., 3] > 0][:, :3]
    light = foam[foam.sum(1) > 600]
    foam_col = np.median(light, 0).astype(np.uint8) if len(light) else np.array([250, 250, 255], np.uint8)
    out = np.zeros((16, 16, 4), np.uint8)
    for y in range(16):
        for x in range(16):
            edge = 15 - x if rising_right else x  # fila de la superficie en esa columna
            if y < edge:
                continue
            d = y - edge
            out[y, x] = body[y, x]
            out[y, x, 3] = 255
            if d == 0:
                out[y, x, :3] = outline
            elif d <= 3:
                out[y, x, :3] = foam_col
    return out


def build_tileset():
    tiles = []

    def add(t):
        tiles.append(t)
        return len(tiles) - 1

    g = CFG["ground"]
    materials = {}
    slopes = {}
    for mat, m in g["materials"].items():
        outline = np.array(m["outline"], np.uint8)
        base, info_b = block32(m["base"])
        foam, info_f = block32(m["foam"])
        base[..., 3] = 255
        for half in (slice(0, 16), slice(16, 32)):
            foam[:, half] = np.concatenate([solid_below_foam(foam[:16, half]), foam[16:, half]], axis=0)
        foam[16:, :, 3] = 255

        def quad(img, px, py):
            return img[py * 16:(py + 1) * 16, px * 16:(px + 1) * 16].copy()

        def four(t):
            return [side(t, True, True, outline), side(t, True, False, outline), t, side(t, False, True, outline)]

        sets = {"cap0": [], "cap1": [], "body": [], "plat": [], "cap1_bottom": [], "bottom": []}
        for px in (0, 1):
            sets["cap0"] += [add(t) for t in four(quad(foam, px, 0))]
            sets["cap1"] += [add(t) for t in four(quad(foam, px, 1))]
            sets["plat"] += [add(t) for t in four(bumpy(quad(foam, px, 0), outline))]
            sets["cap1_bottom"] += [add(t) for t in four(bumpy(quad(foam, px, 1), outline))]
        for py in (0, 1):
            for px in (0, 1):
                sets["body"] += [add(t) for t in four(quad(base, px, py))]
                sets["bottom"] += [add(t) for t in four(bumpy(quad(base, px, py), outline))]
        materials[mat] = sets
        body = quad(base, 0, 1)
        slopes[f"{mat}_up"] = add(ramp(body, quad(foam, 0, 0), outline, True))
        slopes[f"{mat}_down"] = add(ramp(body, quad(foam, 1, 0), outline, False))
        for nm, box, info in ((f"{mat}_base", m["base"], info_b), (f"{mat}_foam", m["foam"], info_f)):
            MANIFEST["resources"].append({"name": nm, "type": "terrain_sample", "source": CFG["sources"]["tiles"], "crop": box,
                                          "trimmed": info["trim"], "size": [32, 32], "origin": "bloque de 2x2 teselas", "status": "ok",
                                          "notes": "bloque reducido a 32x32; bordes laterales, base y rampas generados por el script"})
    names = {}
    for name, box in CFG["blocks"].items():
        ex, info = extract("tiles", "panel", box, {"keep": 0.2})
        b = P.downscale(ex, size=(16, 16))
        b = P.apply_palette(b, P.make_palette([b], 12))
        b[..., 3] = 255
        names[name] = add(b)
        MANIFEST["resources"].append({"name": name, "type": "block", "source": CFG["sources"]["tiles"], "crop": box,
                                      "trimmed": info["trim"], "size": [16, 16], "origin": "tesela", "status": status_of(info, name=name),
                                      "notes": notes_of(info, name)})
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    sheet = np.zeros((rows * 16, cols * 16, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16] = t
    d = os.path.join(OUT_RES, "terrain")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, "world4_tiles.png"))
    sp = materials["sponge"]
    # `terrain` (formato de los Mundos 1-3) se conserva como respaldo con la esponja
    legacy = {"top": sp["cap0"][:4], "plat": sp["plat"][:4], "fill": sp["body"][:4], "bottom": sp["bottom"][:4]}
    return {"key": "world4_tiles", "texture": f"res://{RES}/terrain/world4_tiles.png", "tileSize": 16,
            "terrain": legacy, "materials": materials, "defaultMaterial": "sponge", "slopes": slopes, "blocks": names}


# ---------------------------------------------------------------------------
# Fondos: cielo y bancos de espuma con la paleta de word_4.png
# ---------------------------------------------------------------------------
def sample_colors(points):
    scene = src("scene")
    return ["#%02X%02X%02X" % tuple(int(v) for v in scene[y, x, :3]) for x, y in points]


def gen_sky(colors, w=480, h=270):
    stops = [(0.0, colors[0]), (0.45, colors[1]), (0.8, colors[2]), (1.0, colors[3])]
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
            k = min(lo + (1 if frac > P.BAYER[y % 4, x % 4] else 0), bands) / bands
            img[y, x, :3] = (P.hex_rgb(c0) * (1 - k) + P.hex_rgb(c1) * k).astype(np.uint8)
    return img


def main():
    os.makedirs(OUT_DATA, exist_ok=True)
    atlases, characters = {}, {}
    previews = {}
    for key, c in CFG["characters"].items():
        cells, entry = build_character(key, c)
        atlases[key] = save_atlas(key, cells, "enemies" if key != "patoburbuja" else "boss")
        characters[key] = entry
        previews[key] = cells
    fx = build_set(CFG["fx"], default_src="enemies")
    fx["whirl"] = gen_whirl()
    MANIFEST["resources"].append({"name": "whirl", "type": "generated_fx", "source": CFG["sources"]["boss"], "crop": None,
                                  "size": [22, 22], "status": "ok",
                                  "notes": "remolino generado con los azules y blancos del agua de jefemundo4.png (la hoja no lo trae suelto)"})
    atlases["w4_fx"] = save_atlas("w4_fx", fx, "effects")
    objs = build_set(CFG["objects"])
    atlases["world4_objects"] = save_atlas("world4_objects", objs, "objects")
    bg = build_set(CFG["background"], kind="background")
    atlases["world4_bg"] = save_atlas("world4_bg", bg, "backgrounds")

    sp = CFG["scene_palette"]
    sky_cols = sample_colors(sp["sky_points"])
    foam_cols = sample_colors(sp["foam_points"])
    d = os.path.join(OUT_RES, "backgrounds")
    Image.fromarray(gen_sky(sky_cols), "RGBA").save(os.path.join(d, "w4_sky.png"))
    far = ("#FFFFFF", "#EEF4FF", foam_cols[1], "#9CC8F4")
    near = ("#FFFFFF", "#F8EAFB", foam_cols[2], "#6FB8EC")
    Image.fromarray(P.gen_cloudbank(512, 110, far, 21, 50), "RGBA").save(os.path.join(d, "w4_foam_far.png"))
    Image.fromarray(P.gen_cloudbank(512, 80, near, 34, 34), "RGBA").save(os.path.join(d, "w4_foam_near.png"))
    images = {k: f"res://{RES}/backgrounds/{k}.png" for k in ("w4_sky", "w4_foam_far", "w4_foam_near")}
    for k in images:
        MANIFEST["resources"].append({"name": k, "type": "generated_background", "source": CFG["sources"]["scene"],
                                      "crop": None, "status": "ok",
                                      "notes": "generado con colores muestreados de word_4.png (cielo %s, espuma %s)" % (sky_cols, foam_cols)})
    tileset = build_tileset()

    with open(os.path.join(OUT_DATA, "atlases.json"), "w", encoding="utf-8") as f:
        json.dump({"atlases": atlases, "images": images, "tileset": tileset}, f, indent=1, ensure_ascii=False)
    with open(os.path.join(OUT_DATA, "characters.json"), "w", encoding="utf-8") as f:
        json.dump(characters, f, indent=1, ensure_ascii=False)
    pend = [r["name"] for r in MANIFEST["resources"] if r.get("status") == "pending"]
    MANIFEST["summary"] = {"total": len(MANIFEST["resources"]), "pending": pend}
    with open(os.path.join(OUT_DATA, "world4_asset_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(MANIFEST, f, indent=1, ensure_ascii=False)
    print("Recursos:", len(MANIFEST["resources"]), "| pendientes de revisión:", pend)
    for k, v in characters.items():
        print(f"  {k}: celda {v['frameWidth']}x{v['frameHeight']}, " + ", ".join(f"{a} {len(x['frames'])}" for a, x in v["anims"].items()))

    if DEBUG:
        os.makedirs(DEBUG_DIR, exist_ok=True)
        for key, cells in previews.items():
            names = list(cells)
            ch, cw = cells[names[0]].shape[:2]
            sheet = Image.new("RGBA", (cw * len(names), ch + 12), (120, 170, 230, 255))
            dr = ImageDraw.Draw(sheet)
            for i, n in enumerate(names):
                sheet.alpha_composite(Image.fromarray(cells[n], "RGBA"), (i * cw, 0))
                dr.line((i * cw, ch - 1, i * cw + cw - 1, ch - 1), fill=(255, 0, 0))  # línea de apoyo
                dr.line((i * cw + cw // 2, 0, i * cw + cw // 2, ch - 1), fill=(255, 0, 0))  # pivote
                dr.text((i * cw + 1, ch), n[:9], fill=(0, 0, 0))
            sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(DEBUG_DIR, f"debug_{key}.png"))
        for name, imgs in (("fx", fx), ("objects", objs), ("bg", bg)):
            sheet, frames = P.pack(imgs)
            im = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), (120, 170, 230, 255))
            im.alpha_composite(Image.fromarray(sheet, "RGBA"))
            dr = ImageDraw.Draw(im)
            for n, f in frames.items():
                fr = f["frame"]
                dr.rectangle((fr["x"], fr["y"], fr["x"] + fr["w"] - 1, fr["y"] + fr["h"] - 1), outline=(255, 0, 0))
            im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(DEBUG_DIR, f"debug_{name}.png"))
        ts = Image.open(os.path.join(OUT_RES, "terrain", "world4_tiles.png"))
        bgim = Image.new("RGBA", ts.size, (120, 170, 230, 255))
        bgim.alpha_composite(ts)
        bgim.resize((ts.width * 5, ts.height * 5), Image.NEAREST).save(os.path.join(DEBUG_DIR, "debug_tiles.png"))
    print("OK ->", os.path.relpath(OUT_RES, ROOT), "y", os.path.relpath(OUT_DATA, ROOT))


if __name__ == "__main__":
    main()
