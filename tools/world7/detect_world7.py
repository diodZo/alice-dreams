"""Diagnóstico reproducible de cajas de sprites del Mundo 7.

No genera recursos finales: enumera componentes y dibuja las regiones candidatas para que
world7_sources.json pueda corregirse a mano sin depender de una cuadrícula.
Uso: python tools/world7/detect_world7.py   -> tools/out/world7/detected_*.png/json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world7"
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
    image = np.array(Image.open(ROOT / "imagenes" / "jefemundo7.png").convert("RGBA"))
    # alfa >= 240: descarta el halo rojo/magenta semitransparente
    boxes = connected_boxes(image[..., 3] >= 240, 0, 0, 2500, 1)
    save_debug(image, {"boss": (None, boxes)}, "boss")


def inspect_panels(file: str, name: str, panels: dict, distance: int = 42, minimum: int = 150) -> None:
    image = np.array(Image.open(ROOT / "imagenes" / file).convert("RGBA"))
    groups = {}
    for key, (x0, y0, x1, y1) in panels.items():
        crop = image[y0:y1 + 1, x0:x1 + 1]
        groups[key] = ([x0, y0, x1, y1], connected_boxes(panel_mask(crop, distance), x0, y0, minimum))
    save_debug(image, groups, name)


# Paneles de enemies_world_7.png (sin los rótulos de animación ni los retratos grandes)
ENEMY_PANELS = {
    "cuppy_top": [195, 215, 595, 315], "cuppy_row": [15, 345, 595, 428], "cuppy_hurt": [15, 445, 330, 540], "cuppy_def": [335, 445, 595, 540],
    "gomi_top": [605, 240, 1030, 330], "gomi_row": [605, 352, 1032, 436], "gomi_split": [605, 462, 795, 540], "gomi_hurt": [795, 462, 900, 540],
    "gomi_def": [900, 462, 1035, 540],
    "piru_row": [1052, 345, 1440, 436], "piru_hurt": [1052, 458, 1235, 540], "piru_def": [1240, 458, 1440, 540],
    # mitad inferior: segunda hoja de teselas del Mundo 7 y franja de parallax
    "x_top": [15, 610, 395, 700], "x_center": [15, 712, 395, 780], "x_edges": [15, 795, 395, 865], "x_bottom": [15, 875, 395, 940],
    "x_plat": [410, 618, 745, 905], "x_elem": [758, 618, 1100, 945], "x_deco": [1110, 618, 1440, 945],
    "x_coll": [15, 985, 680, 1078], "x_parallax": [695, 995, 1440, 1078],
}

TILE_PANELS = {
    "t_top": [15, 235, 490, 305], "t_center": [15, 325, 490, 395], "t_edges": [15, 420, 285, 505],
    "t_ramps": [290, 420, 490, 505], "t_bottom": [15, 535, 490, 640],
    "p_cookie": [510, 225, 965, 280], "p_candy": [510, 305, 750, 400], "p_cream": [755, 305, 965, 435],
    "p_jelly": [510, 440, 740, 497], "p_candybar": [510, 505, 745, 560], "p_special": [770, 455, 965, 550],
    "p_cakebar": [510, 575, 770, 645], "p_spike": [770, 580, 965, 645],
    "d_trees": [985, 225, 1205, 395], "d_sweets": [1205, 225, 1440, 400], "d_cakes": [985, 420, 1205, 552],
    "d_falls": [1210, 410, 1440, 555], "d_bridge": [985, 580, 1440, 650],
    "o_lolli": [10, 715, 168, 850], "o_cookie": [180, 735, 335, 850], "o_belt": [340, 725, 518, 835],
    "o_jets": [10, 880, 178, 1062], "o_jelly": [180, 900, 340, 1062], "o_launch": [345, 890, 518, 1048],
    "c_stars": [1040, 718, 1225, 778], "c_special": [1240, 715, 1435, 795], "c_cherry": [1040, 825, 1115, 920],
    "c_block": [1118, 835, 1208, 920], "c_cake": [1210, 832, 1290, 920], "c_portal": [1295, 818, 1430, 930],
    "c_signs": [1045, 960, 1215, 1058], "c_flag": [1230, 955, 1365, 1070],
}

if __name__ == "__main__":
    what = sys.argv[1:] or ["boss", "enemies", "tiles"]
    if "boss" in what:
        inspect_boss()
    if "enemies" in what:
        inspect_panels("enemies_world_7.png", "enemies", ENEMY_PANELS, 34, 60)
    if "tiles" in what:
        inspect_panels("tilesets_world_7.png", "tiles", TILE_PANELS, 30, 60)
    print(f"Diagnóstico escrito en {OUT}")
