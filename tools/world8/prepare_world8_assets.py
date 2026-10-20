"""
Pipeline de recursos del Mundo 8 — El Castillo de las Pesadillas.

Uso (desde la raíz del repositorio):
    python tools/world8/prepare_world8_assets.py            # genera recursos y datos del Mundo 8
    python tools/world8/prepare_world8_assets.py --debug    # además: tools/out/world8/*.png

Requisitos: Python 3.10+, Pillow, NumPy y SciPy.

Mismo proceso que el Mundo 6 (tools/world6/prepare_world6_assets.py), con las cuatro referencias
oficiales del Mundo 8 (word_7.png, tilesets_world_7.png, enemies_world_7.png, jefemundo7.png).
Cada fotograma u objeto se describe con su caja en tools/world8/world8_sources.json (editable a
mano; tools/world8/detect_world8.py dibuja las candidatas). Por cada recorte:
 1. Se separa del fondo: alfa >= 240 en la hoja del jefe (sin el halo rojo); en las demás sólo
    se elimina el fondo pastel conectado con el borde del recorte (los textos y marcos quedan
    fuera de las cajas). `only` limita el recorte a zonas cuando dos dibujos se tocan: así se
    separan los proyectiles (estrellitas, escupitajo, ráfaga, nube, ondas) de los cuerpos.
 2. Se conserva la isla principal (y las grandes) y se descartan chispas sueltas.
 3. Se reduce a la resolución lógica del juego con alfa binario, paleta común por personaje y
    refuerzo del contorno. Nada se suaviza en Godot: filtro nearest. Un cuadro puede llevar su
    propia `scale` (los cuadros de daño y derrota están dibujados más grandes en la hoja).
 4. Los fotogramas de cada personaje se normalizan a una celda común alineada por abajo y con un
    pivote horizontal estable (pies, centroide o una x fijada a mano por fotograma).
 5. Se empaqueta en atlas y se escriben los JSON que consume Godot (mismo formato que los Mundos 1-6)
    y un manifiesto con origen, caja, animación, duración, offset, validación y cuadros reutilizados.
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
sys.path.insert(0, HERE)
import generate_world8_extras as X  # noqa: E402  (trono y habitación de Alice, dibujados por código)

CFG = json.load(open(os.path.join(HERE, "world8_sources.json"), encoding="utf-8"))
GODOT = os.path.join(ROOT, "godot")
RES = "resources/world8"
OUT_RES = os.path.join(GODOT, *RES.split("/"))
OUT_DATA = os.path.join(GODOT, "data", "world8")
DEBUG = "--debug" in sys.argv
DEBUG_DIR = os.path.join(ROOT, "tools", "out", "world8")
BOSS_KEYS = ("rey_pesadelo", "gato_morado")

_cache = {}
MANIFEST = {"version": 1, "generatedBy": "tools/world8/prepare_world8_assets.py", "sources": CFG["sources"], "resources": []}


def src(name):
    if name not in _cache:
        _cache[name] = np.array(Image.open(os.path.join(ROOT, CFG["sources"][name])).convert("RGBA"))
    return _cache[name]


# ---------------------------------------------------------------------------
# Segmentación
# ---------------------------------------------------------------------------
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
    """Una caja es [x0,y0,x1,y1] o {box, only, pivot, ...}: devuelve (caja, opciones propias)."""
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
    elif mode == "sky":
        # Mundo 8: el cielo de word_7.png es un degradado azul; se descartan los píxeles con
        # dominante azul (el castillo, las nubes y los dulces son rosas, blancos y amarillos)
        rgb = crop[..., :3].astype(int)
        fg = ~((rgb[..., 2] > rgb[..., 0] + opts.get("sky_margin", 18)) & (rgb[..., 2] >= rgb[..., 1]))
    elif mode == "bright":
        fg = crop[..., :3].astype(int).mean(-1) >= opts.get("lum", 200)
    else:
        cand = panel_bg(crop, opts.get("distance", 30))
        if opts.get("bluer_keep"):
            # Mundo 8: el fondo del panel de enemigos es rosado con halos brillantes. Un píxel
            # parecido al fondo sólo es fondo si no es más azulado que él: así se conserva el
            # blanco azulado del Fantasmita aunque la tolerancia sea alta.
            rgb = crop[..., :3].astype(int)
            border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
            base = np.median(border, axis=0)
            cand &= (rgb[..., 2] - rgb[..., 0]) <= (base[2] - base[0]) + opts["bluer_keep"]
        fg = ~flood(cand)
    if opts.get("open"):
        # elimina hilos de halo de 1-2 px pegados al contorno
        fg = ndimage.binary_opening(fg, iterations=int(opts["open"]))
    if opts.get("navy"):
        # Mundo 8: la hoja del jefe tiene fondo azul noche; las ondas y el humo lo encierran, así
        # que se descarta también el azul noche no conectado con el borde (oscuro y con dominante
        # azul). El contorno negro que se pierda lo repone el refuerzo del contorno.
        rgb = crop[..., :3].astype(int)
        fg &= ~((rgb.max(-1) < opts.get("navy_max", 96)) & (rgb[..., 2] > rgb[..., 0] + 6) & (rgb[..., 2] >= rgb[..., 1]))
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
    if "only" not in opts and mode == "alpha":
        if by0 == 0 and y0 > 0 and _opaque_outside(img, slice(x0 + bx0, x0 + bx1), y0 - 1, True):
            touches.append("arriba")
        if by1 == crop.shape[0] and y1 + 1 < H and _opaque_outside(img, slice(x0 + bx0, x0 + bx1), y1 + 1, True):
            touches.append("abajo")
        if bx0 == 0 and x0 > 0 and _opaque_outside(img, slice(y0 + by0, y0 + by1), x0 - 1, False):
            touches.append("izquierda")
        if bx1 == crop.shape[1] and x1 + 1 < W and _opaque_outside(img, slice(y0 + by0, y0 + by1), x1 + 1, False):
            touches.append("derecha")
    info = {"trim": [int(x0 + bx0), int(y0 + by0), int(x0 + bx1 - 1), int(y0 + by1 - 1)], "touches": touches}
    return out, info


def _opaque_outside(img, span, at, row):
    # en las hojas sin alfa el fondo del panel es continuo: sólo se puede deducir con alfa
    line = img[at, span] if row else img[span, at]
    return (line[..., 3] >= 240).mean() > 0.15


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
def _blob_x(im, mask):
    """x media de la mancha conectada más grande de `mask` (None si no hay mancha suficiente)."""
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n == 0:
        return None
    areas = ndimage.sum(mask, lab, range(1, n + 1))
    i = int(np.argmax(areas)) + 1
    if areas[i - 1] < 12:
        return None
    return float(np.nonzero(lab == i)[1].mean())


def anchor_of(im, mode):
    """Pivote horizontal del fotograma reducido."""
    a = im[..., 3] > 0
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    masks = {
        "yellow": a & (r > 200) & (g > 150) & (b < 140),
        "pale": a & (r > 225) & (g > 205) & (b >= 110) & (b <= 225) & (r - b > 25),
        "dark": a & (rgb.max(-1) < 150),
        "white": a & (rgb.min(-1) > 190),
        # cabina azul intenso de Locomostro (el humo es azul claro: r alto)
        "blue": a & (b > 140) & (r < 80) & (g < 130),
    }
    if mode in masks:
        x = _blob_x(im, masks[mode])
        if x is not None:
            return x
        mode = "centroid"
    if mode == "centroid":
        xs = np.nonzero(a)[1]
        return float(xs.mean()) if len(xs) else im.shape[1] / 2
    return P.feet_anchor(im)


def build_character(key, c):
    raw, infos, pivots = {}, {}, {}
    for anim, a in c["anims"].items():
        for i, entry in enumerate(a["boxes"]):
            box, own = unpack_box(entry)
            ex, info = extract(c["src"], c["mode"], box, {**c, **own})
            raw[(anim, i)] = P.downscale(ex, own.get("scale", c["scale"]))
            infos[(anim, i)] = (box, info, a)
            if "pivot" in own:
                # x fijada a mano en la hoja original -> píxel del fotograma reducido
                tw = info["trim"][2] - info["trim"][0] + 1
                pivots[(anim, i)] = (own["pivot"] - info["trim"][0]) * raw[(anim, i)].shape[1] / tw
    pal = P.make_palette(list(raw.values()), c.get("colors", 32))
    scaled = {k: P.darken_edges(P.apply_palette(v, pal), 0.7) for k, v in raw.items()}
    anchors = {k: pivots.get(k, anchor_of(v, c.get("anchor", "feet"))) for k, v in scaled.items()}
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
            "cell": [cw, ch], "anchor": "pivot manual" if (anim, i) in pivots else c.get("anchor", "feet"),
            "status": status_of(info, a.get("status"), f"{key}/{name}"),
            "notes": notes_of(info, f"{key}/{name}", a.get("note", "")),
            **({"reused": a["reused"]} if "reused" in a else {}),
        })
    anims = {a: {"frames": [f"{a}_{i}" for i in range(len(v["boxes"]))], "fps": v["fps"], "loop": v["loop"], "derived": "reused" in v}
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
        im = finish(im, o.get("colors", 20), 0.0 if kind == "background" or mode in ("opaque", "bright") else 0.8)
        if o.get("fade_bottom"):
            n = min(int(o["fade_bottom"]), im.shape[0])
            ramp = np.linspace(1.0, 0.0, n)[:, None]
            # alfa binario con trama ordenada: el borde inferior se disuelve sin semitransparencias
            bayer = np.tile(P.BAYER, (n // 4 + 1, im.shape[1] // 4 + 1))[:n, :im.shape[1]]
            im[-n:, :, 3] = np.where(ramp > bayer, im[-n:, :, 3], 0).astype(np.uint8)
        imgs[name] = im
        MANIFEST["resources"].append({
            "name": name, "type": kind, "source": CFG["sources"][s], "crop": o["box"], "trimmed": info["trim"],
            "size": [im.shape[1], im.shape[0]], "origin": "según la escena (centro o pies)",
            "status": status_of(info, o.get("status"), name),
            "notes": notes_of(info, name, o.get("note", "")),
        })
    return imgs


def strip_from(im, w=8):
    """Tira repetible para Line2D: las `w` columnas centrales de una pieza real ya reducida
    (puente arcoíris recto, vía corta). Se recorta en alto a las filas opacas."""
    cx = im.shape[1] // 2
    band = im[:, cx - w // 2:cx - w // 2 + w].copy()
    rows = np.nonzero(band[..., 3].max(1))[0]
    return band[rows.min():rows.max() + 1]


def save_atlas(key, images, sub):
    sheet, frames = P.pack(images)
    d = os.path.join(OUT_RES, sub)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, f"{key}.png"))
    conv = {n: [f["frame"]["x"], f["frame"]["y"], f["frame"]["w"], f["frame"]["h"], 0, 0, f["frame"]["w"], f["frame"]["h"]]
            for n, f in frames.items()}
    return {"texture": f"res://{RES}/{sub}/{key}.png", "size": [sheet.shape[1], sheet.shape[0]], "frames": conv}


# ---------------------------------------------------------------------------
# Terreno 16x16: roca violeta (o piedra del castillo) con cobertura lavanda, en bloques de 32x32
# ---------------------------------------------------------------------------
def block32(box, mode="panel", stack=1, colors=14):
    """Bloque de la hoja reducido a 32x32 (2x2 teselas) sin el fondo del panel.
    `stack` apila la franja varias veces en vertical antes de reducirla (roca sin estrellas)."""
    # tolerancia baja: las nubes blancas se parecen mucho al fondo lavanda del panel
    ex, info = extract("tiles", mode, box, {"keep": 0.2, "distance": 12})
    if stack > 1:
        ex = np.concatenate([ex] * stack, axis=0)
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
    """La nube no deja huecos transparentes por encima de la roca."""
    out = t.copy()
    for x in range(16):
        col = np.nonzero(out[:, x, 3])[0]
        if len(col):
            out[col[0]:, x, 3] = 255
    return out


def ramp(body, cap, outline, rising_right):
    """Rampa de 45 grados: roca bajo la diagonal y una franja de nube encima."""
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
        base, info_b = block32(m["base"], "opaque", int(m.get("base_stack", 1)))
        base[..., 3] = 255
        if "cap" in m:
            # la cobertura lavanda de 'tiles superiores' se apoya sobre el bloque de
            # chocolate real (reducida a 32 x cap_h); por encima queda transparente.
            ex, info_f = extract("tiles", "panel", m["cap"], {"keep": 0.2, "distance": 12})
            cap = P.downscale(ex, size=(32, int(m.get("cap_h", 11))))
            cap = P.apply_palette(cap, P.make_palette([cap], 10))
            foam = base.copy()
            ch = cap.shape[0]
            on = cap[..., 3] > 0
            foam[:ch][on] = cap[on]
            for x in range(32):
                ys = np.nonzero(on[:, x])[0]
                foam[:ys[0] if len(ys) else ch, x, 3] = 0
        else:
            foam, info_f = block32(m["foam"])
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
    Image.fromarray(sheet, "RGBA").save(os.path.join(d, "world8_tiles.png"))
    cm = materials["lavender"]
    # `terrain` (formato de los Mundos 1-3) se conserva como respaldo
    legacy = {"top": cm["cap0"][:4], "plat": cm["plat"][:4], "fill": cm["body"][:4], "bottom": cm["bottom"][:4]}
    return {"key": "world8_tiles", "texture": f"res://{RES}/terrain/world8_tiles.png", "tileSize": 16,
            "terrain": legacy, "materials": materials, "defaultMaterial": "lavender", "slopes": slopes, "blocks": names}


# ---------------------------------------------------------------------------
# Fondos: cielo nocturno y bancos de nubes violetas con la paleta de word_8.png
# ---------------------------------------------------------------------------
def sample_colors(points):
    scene = src("scene")
    return ["#%02X%02X%02X" % tuple(int(v) for v in scene[y, x, :3]) for x, y in points]


def gen_sky(colors, w=480, h=270):
    """Cielo nocturno en bandas con trama ordenada (sin degradados suaves) y estrellas de 1 px
    (algunas en cruz) en amarillo lunar #FFE18C, como el cielo de word_8.png."""
    stops = [(0.0, colors[0]), (0.4, colors[1]), (0.78, colors[2]), (1.0, colors[3])]
    bands = 16
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
    rng = np.random.default_rng(7)
    star = np.array([255, 225, 140])
    for _ in range(70):
        x, y = int(rng.integers(2, w - 2)), int(rng.integers(2, 150))
        img[y, x, :3] = star if rng.random() < 0.6 else (255, 255, 255)
        if rng.random() < 0.25:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx, :3] = (img[y + dy, x + dx, :3] * 0.4 + star * 0.6).astype(np.uint8)
    return img


def main():
    os.makedirs(OUT_DATA, exist_ok=True)
    atlases, characters = {}, {}
    previews = {}
    for key, c in CFG["characters"].items():
        cells, entry = build_character(key, c)
        atlases[key] = save_atlas(key, cells, "enemies" if key not in BOSS_KEYS else "boss")
        characters[key] = entry
        previews[key] = cells
    fx = build_set(CFG["fx"], default_src="enemies")
    atlases["w8_fx"] = save_atlas("w8_fx", fx, "effects")
    objs = build_set(CFG["objects"])
    # el trono no está en las referencias: se dibuja por código con la paleta del Mundo 8
    objs["throne"] = X.make_throne()
    MANIFEST["resources"].append({"name": "throne", "type": "generated_object", "source": None, "crop": None,
                                  "size": [objs["throne"].shape[1], objs["throne"].shape[0]], "origin": "pies", "status": "ok",
                                  "notes": "generado por tools/world8/generate_world8_extras.py (no aparece en las referencias)"})
    X.main()
    for k in ("bedroom", "bedroom_blanket"):
        MANIFEST["resources"].append({"name": k, "type": "generated_cinematic", "source": None, "crop": None, "status": "ok",
                                      "notes": "habitación de Alice para la cinemática final, dibujada por código; Alice usa sus fotogramas oficiales"})
    atlases["world8_objects"] = save_atlas("world8_objects", objs, "objects")
    bg = build_set(CFG["background"], kind="background")
    atlases["world8_bg"] = save_atlas("world8_bg", bg, "backgrounds")

    sp = CFG["scene_palette"]
    sky_cols = sample_colors(sp["sky_points"])
    cloud_cols = sample_colors(sp["cloud_points"])
    d = os.path.join(OUT_RES, "backgrounds")
    Image.fromarray(gen_sky(sky_cols), "RGBA").save(os.path.join(d, "w8_sky.png"))
    # nubes violetas lejos y lavanda/rosa mágico cerca, como los bancos de nubes de word_8.png
    far = ("#C8A5FF", cloud_cols[0], cloud_cols[1], "#35205F")
    near = ("#F6B4E9", cloud_cols[2], cloud_cols[3], "#713CA8")
    Image.fromarray(P.gen_cloudbank(512, 110, far, 71, 50), "RGBA").save(os.path.join(d, "w8_clouds_far.png"))
    Image.fromarray(P.gen_cloudbank(512, 80, near, 72, 34), "RGBA").save(os.path.join(d, "w8_clouds_near.png"))
    images = {k: f"res://{RES}/backgrounds/{k}.png" for k in ("w8_sky", "w8_clouds_far", "w8_clouds_near")}
    for k in images:
        MANIFEST["resources"].append({"name": k, "type": "generated_background", "source": CFG["sources"]["scene"],
                                      "crop": None, "status": "ok",
                                      "notes": "generado con colores muestreados de word_8.png (cielo %s, nubes %s)" % (sky_cols, cloud_cols)})
    tileset = build_tileset()

    with open(os.path.join(OUT_DATA, "atlases.json"), "w", encoding="utf-8") as f:
        json.dump({"atlases": atlases, "images": images, "tileset": tileset}, f, indent=1, ensure_ascii=False)
    with open(os.path.join(OUT_DATA, "characters.json"), "w", encoding="utf-8") as f:
        json.dump(characters, f, indent=1, ensure_ascii=False)
    pend = [r["name"] for r in MANIFEST["resources"] if r.get("status") == "pending"]
    MANIFEST["summary"] = {"total": len(MANIFEST["resources"]), "pending": pend}
    with open(os.path.join(OUT_DATA, "world8_asset_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(MANIFEST, f, indent=1, ensure_ascii=False)
    print("Recursos:", len(MANIFEST["resources"]), "| pendientes de revisión:", pend)
    for k, v in characters.items():
        print(f"  {k}: celda {v['frameWidth']}x{v['frameHeight']}, " + ", ".join(f"{a} {len(x['frames'])}" for a, x in v["anims"].items()))

    if DEBUG:
        os.makedirs(DEBUG_DIR, exist_ok=True)
        for key, cells in previews.items():
            names = list(cells)
            ch, cw = cells[names[0]].shape[:2]
            sheet = Image.new("RGBA", (cw * len(names), ch + 12), (40, 50, 120, 255))
            dr = ImageDraw.Draw(sheet)
            for i, n in enumerate(names):
                sheet.alpha_composite(Image.fromarray(cells[n], "RGBA"), (i * cw, 0))
                dr.line((i * cw, ch - 1, i * cw + cw - 1, ch - 1), fill=(255, 0, 0))  # línea de apoyo
                dr.line((i * cw + cw // 2, 0, i * cw + cw // 2, ch - 1), fill=(255, 0, 0))  # pivote
                dr.text((i * cw + 1, ch), n[:9], fill=(255, 255, 255))
            sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(DEBUG_DIR, f"debug_{key}.png"))
        for name, imgs in (("fx", fx), ("objects", objs), ("bg", bg)):
            sheet, frames = P.pack(imgs)
            im = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), (40, 50, 120, 255))
            im.alpha_composite(Image.fromarray(sheet, "RGBA"))
            dr = ImageDraw.Draw(im)
            for n, f in frames.items():
                fr = f["frame"]
                dr.rectangle((fr["x"], fr["y"], fr["x"] + fr["w"] - 1, fr["y"] + fr["h"] - 1), outline=(255, 0, 0))
            im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(DEBUG_DIR, f"debug_{name}.png"))
        ts = Image.open(os.path.join(OUT_RES, "terrain", "world8_tiles.png"))
        bgim = Image.new("RGBA", ts.size, (40, 50, 120, 255))
        bgim.alpha_composite(ts)
        bgim.resize((ts.width * 5, ts.height * 5), Image.NEAREST).save(os.path.join(DEBUG_DIR, "debug_tiles.png"))
    print("OK ->", os.path.relpath(OUT_RES, ROOT), "y", os.path.relpath(OUT_DATA, ROOT))


if __name__ == "__main__":
    main()
