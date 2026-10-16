"""
Pipeline de recursos del Mundo 2 — El Reino de los Crayones Encantados.

Uso (desde la raíz del repositorio):
    python tools/world2/prepare_world2_assets.py            # genera godot/resources/world2 y godot/data/world2
    python tools/world2/prepare_world2_assets.py --debug    # además: tools/out/world2/*.png (hojas de comprobación)

Requisitos: Python 3.10+, Pillow, NumPy y SciPy.

Las cuatro imágenes oficiales (imagenes/word_2.png, tilesets_world_2.png, enemies_world_2.png,
jefemundo2.png) son hojas de ilustración, no spritesheets: tienen títulos, paneles, etiquetas,
halos de color y dibujos de tamaños distintos. Cada fotograma u objeto se describe con su caja
en tools/world2/world2_sources.json (editable a mano). Por cada recorte:
 1. Se separa del fondo: alfa >= umbral en las hojas con transparencia (descarta el halo);
    en la hoja de teselas sólo se elimina el fondo crema conectado con el borde del recorte,
    así los blancos, rosas y azules interiores no se tocan.
 2. Se conserva la isla principal (y las grandes) y se descartan efectos sueltos.
 3. Se reduce a la resolución lógica del juego con promedio de alfa premultiplicado y alfa
    binario (sin bordes difuminados), paleta común por personaje y refuerzo del contorno
    (las mismas funciones que tools/prepare_assets.py del Mundo 1).
 4. Los fotogramas de cada personaje se normalizan a una celda común alineada por los pies:
    el punto de apoyo es estable entre animaciones.
 5. Se empaqueta en atlas y se escriben los JSON que consume Godot (mismo formato que el
    Mundo 1) y un manifiesto con origen, caja, animación, duración, offset y validación.
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

CFG = json.load(open(os.path.join(HERE, "world2_sources.json"), encoding="utf-8"))
GODOT = os.path.join(ROOT, "godot")
RES = "resources/world2"
OUT_RES = os.path.join(GODOT, *RES.split("/"))
OUT_DATA = os.path.join(GODOT, "data", "world2")
DEBUG = "--debug" in sys.argv
DEBUG_DIR = os.path.join(ROOT, "tools", "out", "world2")

_cache = {}
MANIFEST = {"version": 1, "generatedBy": "tools/world2/prepare_world2_assets.py", "sources": CFG["sources"], "resources": []}


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


def flood(cand):
    """Fondo = candidatos conectados con el borde del recorte (rápido, con SciPy)."""
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


def extract(src_name, mode, box, opts):
    """Recorte RGBA sin fondo ajustado a su contenido. Devuelve (imagen, info de validación)."""
    img = src(src_name)
    x0, y0, x1, y1 = box
    crop = img[y0:y1 + 1, x0:x1 + 1].copy()
    if mode == "alpha":
        fg = crop[..., 3] >= opts.get("alpha_min", 240)
    else:
        fg = ~flood(cream_bg(crop))
        if opts.get("opaque"):
            fg = np.ones(fg.shape, bool)
    if "crop_top" in opts:
        fg[: max(0, opts["crop_top"] - y0)] = False
    if not opts.get("nocomp"):
        fg = keep_main(fg, opts.get("keep", 0.2))
    ys, xs = np.nonzero(fg)
    if len(ys) == 0:
        raise RuntimeError(f"Recorte vacío: {src_name} {box}")
    by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = crop[by0:by1, bx0:bx1].copy()
    out[..., 3] = np.where(fg[by0:by1, bx0:bx1], 255, 0)
    # Validación: si el sprite toca el borde de la caja y la imagen sigue opaca fuera de ella,
    # probablemente la caja corta el dibujo.
    touches = []
    H, W = img.shape[:2]
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
    return (~cream_bg(line[None])[0]).mean() > 0.3


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
def build_character(key, c):
    raw, infos = {}, {}
    for anim, a in c["anims"].items():
        for i, box in enumerate(a["boxes"]):
            ex, info = extract(c["src"], c["mode"], box, c)
            raw[(anim, i)] = P.downscale(ex, c["scale"])
            infos[(anim, i)] = (box, info, a)
    pal = P.make_palette(list(raw.values()), c.get("colors", 32))
    scaled = {k: P.darken_edges(P.apply_palette(v, pal), 0.7) for k, v in raw.items()}
    anchors = {k: P.feet_anchor(v) for k, v in scaled.items()}
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
            "cell": [cw, ch], "status": status_of(info, a.get("status"), f"{key}/{name}"),
            "notes": notes_of(info, f"{key}/{name}", a.get("note", "")),
        })
    anims = {a: {"frames": [f"{a}_{i}" for i in range(len(v["boxes"]))], "fps": v["fps"], "loop": v["loop"], "derived": False}
             for a, v in c["anims"].items()}
    return cells, {"frameWidth": cw, "frameHeight": ch, "anims": anims, "name": c["name"]}


# ---------------------------------------------------------------------------
# Objetos sueltos
# ---------------------------------------------------------------------------
def build_set(spec, default_src="tiles", default_mode="cream", kind="object"):
    imgs = {}
    for name, o in spec.items():
        s = o.get("src", default_src)
        mode = o.get("mode", default_mode)
        ex, info = extract(s, mode, o["box"], o)
        im = P.downscale(ex, o["scale"])
        im = finish(im, o.get("colors", 20), 0.0 if kind == "background" else 0.8)
        imgs[name] = im
        MANIFEST["resources"].append({
            "name": name, "type": kind, "source": CFG["sources"][s], "crop": o["box"], "trimmed": info["trim"],
            "size": [im.shape[1], im.shape[0]], "origin": "según la escena (centro o pies)",
            "status": status_of(info, o.get("status"), name),
            "notes": notes_of(info, name, o.get("note", "")),
        })
    return imgs


def save_atlas(key, images, sub):
    sheet, frames = P.pack(images)
    d = os.path.join(OUT_RES, sub)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, f"{key}.png"))
    conv = {n: [f["frame"]["x"], f["frame"]["y"], f["frame"]["w"], f["frame"]["h"], 0, 0, f["frame"]["w"], f["frame"]["h"]]
            for n, f in frames.items()}
    return {"texture": f"res://{RES}/{sub}/{key}.png", "size": [sheet.shape[1], sheet.shape[0]], "frames": conv}


# ---------------------------------------------------------------------------
# Terreno 16x16
# ---------------------------------------------------------------------------
def build_tileset():
    g = CFG["ground"]
    outline = np.array(g["outline"], np.uint8)
    img = src("tiles")

    def sample(box):
        x0, y0, x1, y1 = box
        c = img[y0:y1 + 1, x0:x1 + 1].copy()
        c[..., 3] = np.where(flood(cream_bg(c)), 0, 255)
        return c

    top_src = sample(g["top_sample"])
    s = 26 / top_src.shape[0]  # la muestra de 66 px de alto queda en 26 px: hierba ~10 px
    top_ds = P.downscale(top_src, s)
    # columna izquierda de la muestra: la del centro tiene una flor que quedaría cortada
    cx = g.get("top_column", 1)
    top = top_ds[0:16, cx:cx + 16].copy()
    fill_src = sample(g["fill_sample"])
    fill_ds = P.downscale(fill_src, s)
    fcx = fill_ds.shape[1] // 2 - 8
    fill = fill_ds[-16:, fcx:fcx + 16].copy() if fill_ds.shape[0] >= 16 else np.tile(fill_ds[-8:, fcx:fcx + 16], (2, 1, 1))
    fill[..., 3] = 255
    # la hierba no debe dejar huecos transparentes por encima de la tierra
    top = P.apply_palette(top, P.make_palette([top], 16))
    fill = P.apply_palette(fill, P.make_palette([fill], 10))
    for x in range(16):
        col = np.nonzero(top[:, x, 3])[0]
        if len(col):
            top[col[0]:, x, 3] = 255

    def bumpy(t, base=12):
        out = t.copy()
        for x in range(16):
            edge = base + int(round(2.2 * abs(math.sin(math.pi * (x + 0.5) / 8))))
            out[edge + 1:, x, 3] = 0
            out[edge, x, :3] = outline
            out[edge, x, 3] = 255
        return out

    def side(t, left, right):
        out = t.copy()
        for y in range(16):
            if left and out[y, 1, 3]:
                out[y, 0, :3] = outline
                out[y, 0, 3] = 255
            if right and out[y, 14, 3]:
                out[y, 15, :3] = outline
                out[y, 15, 3] = 255
        tops = [np.nonzero(out[:, x, 3])[0] for x in range(16)]
        for x, ys in enumerate(tops):
            if len(ys) and ((left and x == 0) or (right and x == 15)):
                out[ys[0]:ys[0] + 2, x, 3] = 0
        return out

    bottom = bumpy(fill)
    plat = top.copy()
    plat[12:] = bumpy(fill)[12:]
    plat = bumpy(plat, 12)
    plat[:12] = top[:12]

    def four(t):
        return [side(t, True, True), side(t, True, False), t, side(t, False, True)]

    tiles = four(top) + four(plat) + four(fill) + four(bottom)
    names = {}
    for i, (name, box) in enumerate(CFG["blocks"].items()):
        ex, info = extract("tiles", "cream", box, {})
        b = P.downscale(ex, size=(16, 16))
        b = P.apply_palette(b, P.make_palette([b], 14))
        tiles.append(b)
        names[name] = 16 + i
        MANIFEST["resources"].append({"name": name, "type": "block", "source": CFG["sources"]["tiles"], "crop": box,
                                      "trimmed": info["trim"], "size": [16, 16], "origin": "tesela", "status": status_of(info), "notes": ""})
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    sheet = np.zeros((rows * 16, cols * 16, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16] = t
    d = os.path.join(OUT_RES, "terrain")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, "world2_tiles.png"))
    for nm, box in (("ground_top", g["top_sample"]), ("ground_fill", g["fill_sample"])):
        MANIFEST["resources"].append({"name": nm, "type": "terrain_sample", "source": CFG["sources"]["tiles"], "crop": box,
                                      "size": [16, 16], "origin": "tesela", "status": "ok",
                                      "notes": "textura reducida; bordes laterales y base generados por el script"})
    return {"key": "world2_tiles", "texture": f"res://{RES}/terrain/world2_tiles.png", "tileSize": 16,
            "terrain": {"top": [0, 1, 2, 3], "plat": [4, 5, 6, 7], "fill": [8, 9, 10, 11], "bottom": [12, 13, 14, 15]},
            "blocks": names}


# ---------------------------------------------------------------------------
# Fondos: cielo y bancos de nubes con la paleta de word_2.png
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
        atlases[key] = save_atlas(key, cells, "enemies" if key != "garabato" else "boss")
        characters[key] = entry
        previews[key] = cells
    fx = build_set(CFG["fx"], default_src="enemies", default_mode="alpha", kind="fx")
    atlases["w2_fx"] = save_atlas("w2_fx", fx, "effects")
    objs = build_set(CFG["objects"])
    atlases["world2_objects"] = save_atlas("world2_objects", objs, "objects")
    bg = build_set(CFG["background"], kind="background")
    atlases["world2_bg"] = save_atlas("world2_bg", bg, "backgrounds")

    sp = CFG["scene_palette"]
    sky_cols = sample_colors(sp["sky_points"])
    cloud_cols = sample_colors(sp["cloud_points"])
    d = os.path.join(OUT_RES, "backgrounds")
    Image.fromarray(gen_sky(sky_cols), "RGBA").save(os.path.join(d, "w2_sky.png"))
    far = ("#FFFFFF", "#F4E8FA", cloud_cols[2], "#B9A7F4")
    near = ("#FFFFFF", "#FCE2F2", cloud_cols[3], "#D88CC0")
    Image.fromarray(P.gen_cloudbank(512, 110, far, 5, 50), "RGBA").save(os.path.join(d, "w2_clouds_far.png"))
    Image.fromarray(P.gen_cloudbank(512, 80, near, 13, 34), "RGBA").save(os.path.join(d, "w2_clouds_near.png"))
    images = {k: f"res://{RES}/backgrounds/{k}.png" for k in ("w2_sky", "w2_clouds_far", "w2_clouds_near")}
    for k in images:
        MANIFEST["resources"].append({"name": k, "type": "generated_background", "source": CFG["sources"]["scene"],
                                      "crop": None, "status": "ok",
                                      "notes": "generado con colores muestreados de word_2.png (cielo %s, nubes %s)" % (sky_cols, cloud_cols)})
    tileset = build_tileset()

    with open(os.path.join(OUT_DATA, "atlases.json"), "w", encoding="utf-8") as f:
        json.dump({"atlases": atlases, "images": images, "tileset": tileset}, f, indent=1, ensure_ascii=False)
    with open(os.path.join(OUT_DATA, "characters.json"), "w", encoding="utf-8") as f:
        json.dump(characters, f, indent=1, ensure_ascii=False)
    pend = [r["name"] for r in MANIFEST["resources"] if r.get("status") == "pending"]
    MANIFEST["summary"] = {"total": len(MANIFEST["resources"]), "pending": pend}
    with open(os.path.join(OUT_DATA, "world2_asset_manifest.json"), "w", encoding="utf-8") as f:
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
                dr.text((i * cw + 1, ch), n[:7], fill=(0, 0, 0))
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
        ts = Image.open(os.path.join(OUT_RES, "terrain", "world2_tiles.png"))
        bgim = Image.new("RGBA", ts.size, (120, 170, 230, 255))
        bgim.alpha_composite(ts)
        bgim.resize((ts.width * 6, ts.height * 6), Image.NEAREST).save(os.path.join(DEBUG_DIR, "debug_tiles.png"))
    print("OK ->", os.path.relpath(OUT_RES, ROOT), "y", os.path.relpath(OUT_DATA, ROOT))


if __name__ == "__main__":
    main()
