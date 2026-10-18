"""Diagnóstico reproducible de cajas de sprites del Mundo 4.

No genera recursos finales: enumera componentes y dibuja las regiones candidatas para que
world4_sources.json pueda corregirse a mano sin depender de una cuadrícula.
Uso: python tools/world4/detect_world4.py   -> tools/out/world4/detected_*.png/json
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world4"
OUT.mkdir(parents=True, exist_ok=True)


def connected_boxes(mask: np.ndarray, x0: int, y0: int, minimum: int = 120, grow: int = 2) -> list[list[int]]:
    grown = ndimage.binary_dilation(mask, iterations=grow) if grow else mask
    labels, _ = ndimage.label(grown, structure=np.ones((3, 3)))
    boxes: list[list[int]] = []
    for i, sl in enumerate(ndimage.find_objects(labels), 1):
        if sl is None:
            continue
        area = int((mask[sl] & (labels[sl] == i)).sum())
        if area < minimum:
            continue
        ys, xs = sl
        boxes.append([xs.start + x0, ys.start + y0, xs.stop + x0 - 1, ys.stop + y0 - 1, area])
    return sorted(boxes, key=lambda b: (b[1] // 60, b[0]))


def panel_mask(crop: np.ndarray, distance: int = 42) -> np.ndarray:
    rgb = crop[..., :3].astype(np.int16)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    base = np.median(border, axis=0)
    return np.sqrt(((rgb - base) ** 2).sum(axis=2)) > distance


def save_debug(image: np.ndarray, groups: dict, name: str, bg=(35, 28, 60, 255)) -> None:
    flat = Image.new("RGBA", (image.shape[1], image.shape[0]), bg)
    flat.alpha_composite(Image.fromarray(image))
    draw = ImageDraw.Draw(flat)
    for key, (panel, boxes) in groups.items():
        if panel:
            draw.rectangle(panel, outline=(255, 255, 0), width=2)
        for i, b in enumerate(boxes):
            draw.rectangle(b[:4], outline=(0, 255, 0), width=2)
            draw.text((b[0] + 2, b[1] + 2), f"{key[:6]}{i}", fill=(255, 0, 0))
    flat.convert("RGB").save(OUT / f"detected_{name}.png")
    (OUT / f"detected_{name}.json").write_text(json.dumps({k: v[1] for k, v in groups.items()}, indent=1), encoding="utf-8")


def inspect_boss() -> None:
    image = np.array(Image.open(ROOT / "imagenes" / "jefemundo4.png").convert("RGBA"))
    boxes = connected_boxes(image[..., 3] >= 200, 0, 0, 2500, 1)
    save_debug(image, {"boss": (None, boxes)}, "boss")


def inspect_panels(file: str, name: str, panels: dict, distance: int = 42) -> None:
    image = np.array(Image.open(ROOT / "imagenes" / file).convert("RGBA"))
    groups = {}
    for key, (x0, y0, x1, y1) in panels.items():
        crop = image[y0:y1 + 1, x0:x1 + 1]
        groups[key] = ([x0, y0, x1, y1], connected_boxes(panel_mask(crop, distance), x0, y0, 150))
    save_debug(image, groups, name)


ENEMY_PANELS = {
    "fish_idle": [32, 282, 232, 402], "fish_walk": [246, 282, 556, 402], "fish_attack": [570, 282, 836, 402],
    "fish_hurt": [850, 282, 996, 402], "fish_defeated": [1010, 282, 1186, 402], "fish_fx": [1200, 282, 1422, 402],
    "crab_idle": [32, 553, 232, 690], "crab_walk": [246, 553, 556, 690], "crab_attack": [570, 553, 836, 690],
    "crab_hurt": [850, 553, 996, 690], "crab_defeated": [1010, 553, 1186, 690], "crab_fx": [1200, 553, 1422, 690],
    "pompa_idle": [32, 835, 232, 1000], "pompa_walk": [246, 835, 556, 1000], "pompa_attack": [570, 835, 870, 1000],
    "pompa_hurt": [885, 835, 1020, 1000], "pompa_defeated": [1034, 835, 1186, 1000], "pompa_fx": [1200, 835, 1422, 1000],
}

TILE_PANELS = {
    "terrain_row1": [18, 172, 665, 262], "terrain_row2": [18, 282, 665, 362], "terrain_row3": [18, 400, 665, 512],
    "plat_bubbles": [680, 172, 1078, 250], "plat_foam": [680, 278, 1078, 360], "plat_boat": [680, 388, 800, 512],
    "plat_sponge": [812, 395, 945, 505], "plat_tiles": [950, 395, 1078, 505],
    "coll_stars": [1100, 172, 1310, 235], "coll_shell": [1318, 172, 1425, 235],
    "coll_flag": [1100, 270, 1210, 385], "coll_sign": [1215, 270, 1320, 385], "coll_portal": [1320, 270, 1430, 385],
    "coll_ducks": [1100, 420, 1430, 512],
    "water_surface": [18, 600, 368, 675], "water_under": [18, 712, 368, 885], "bubble_cols": [378, 585, 590, 770],
    "jump_bubbles": [592, 585, 790, 760], "splashes": [378, 805, 790, 885],
    "dec_brushes": [815, 600, 1010, 690], "dec_corals": [1020, 585, 1430, 690], "dec_starfish": [815, 725, 965, 780],
    "dec_shells": [968, 718, 1180, 785], "dec_soap": [1195, 690, 1430, 785], "dec_plants": [808, 812, 1000, 905],
    "dec_bubbles": [1005, 812, 1185, 905], "dec_waterfall": [1190, 812, 1430, 905],
    "haz_foam": [18, 975, 330, 1035], "haz_soap": [340, 965, 680, 1035], "haz_geyser": [690, 940, 1000, 1040],
    "haz_rollers": [1010, 960, 1430, 1040],
}

if __name__ == "__main__":
    inspect_boss()
    inspect_panels("enemies_world_4.png", "enemies", ENEMY_PANELS)
    inspect_panels("tilesets_world_4.png", "tiles", TILE_PANELS, 34)
    print(f"Diagnóstico escrito en {OUT}")
