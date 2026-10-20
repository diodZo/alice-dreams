"""Diagnóstico reproducible de cajas de sprites del Mundo 8.

No genera recursos finales: enumera componentes y dibuja las regiones candidatas para que
world8_sources.json pueda corregirse a mano sin depender de una cuadrícula.
Uso: python tools/world8/detect_world8.py [boss] [enemies] [tiles]  -> tools/out/world8/detected_*.png/json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world8"
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


def save_debug(image: np.ndarray, groups: dict, name: str) -> None:
    flat = Image.fromarray(image).convert("RGB")
    draw = ImageDraw.Draw(flat)
    for key, (panel, boxes) in groups.items():
        if panel:
            draw.rectangle(panel, outline=(255, 255, 0), width=1)
        for i, b in enumerate(boxes):
            draw.rectangle(b[:4], outline=(0, 255, 0), width=1)
            draw.text((b[0] + 2, b[1] + 2), f"{key[:7]}{i}", fill=(255, 0, 0))
    flat.save(OUT / f"detected_{name}.png")
    (OUT / f"detected_{name}.json").write_text(json.dumps({k: v[1] for k, v in groups.items()}, indent=1), encoding="utf-8")


def inspect_panels(file: str, name: str, panels: dict, distance: int = 42, minimum: int = 150) -> None:
    image = np.array(Image.open(ROOT / "imagenes" / file).convert("RGBA"))
    groups = {}
    for key, (x0, y0, x1, y1) in panels.items():
        crop = image[y0:y1 + 1, x0:x1 + 1]
        groups[key] = ([x0, y0, x1, y1], connected_boxes(panel_mask(crop, distance), x0, y0, minimum))
    save_debug(image, groups, name)


# Paneles de jefemundo8.png (fondo azul noche; sin los rótulos de animación)
BOSS_PANELS = {
    "idle": [22, 200, 715, 352], "walk": [735, 200, 1440, 352], "spit": [18, 400, 715, 505], "claw": [730, 400, 1440, 505],
    "fart": [18, 560, 715, 680], "fury": [732, 548, 1440, 680], "hurt": [18, 730, 258, 850], "defeat": [280, 735, 918, 852],
    "cat": [942, 740, 1440, 852], "fx": [15, 895, 1042, 992],
}

# Paneles de enemies_world_8.png (fondo rosado pálido; sin rótulos ni retratos)
ENEMY_PANELS = {
    "g_idle": [378, 200, 852, 282], "g_float": [862, 200, 1428, 282], "g_attack": [378, 312, 852, 388],
    "g_hurt": [862, 312, 1140, 388], "g_def": [1148, 312, 1428, 388], "g_fx": [378, 422, 1428, 476],
    "b_idle": [378, 512, 852, 590], "b_fly": [862, 512, 1428, 590], "b_attack": [378, 622, 852, 702],
    "b_hurt": [862, 622, 1140, 702], "b_def": [1148, 622, 1428, 702], "b_fx": [378, 732, 1428, 786],
    "k_idle": [378, 822, 852, 896], "k_walk": [862, 818, 1428, 896], "k_attack": [378, 932, 852, 1006],
    "k_hurt": [862, 932, 1140, 1006], "k_def": [1148, 932, 1428, 1006], "k_fx": [378, 1032, 1428, 1084],
}

# Paneles de tilesets_world_8.png
TILE_PANELS = {
    "t_top": [15, 238, 495, 318], "t_center": [15, 338, 495, 412], "t_edges": [15, 432, 275, 515],
    "t_ramps": [275, 432, 495, 515], "t_bottom": [15, 535, 495, 650],
    "p_cloud": [515, 240, 925, 318], "p_stone": [515, 340, 925, 397], "p_hang": [515, 418, 925, 505],
    "p_candy": [515, 512, 925, 575], "p_shroom": [515, 595, 780, 672], "p_small": [785, 595, 925, 672],
    "d_trees": [945, 238, 1280, 378], "d_pumpkin": [1280, 238, 1440, 330], "d_lamps": [1280, 345, 1440, 480],
    "d_fence": [945, 395, 1280, 480], "d_gargoyle": [945, 500, 1130, 672], "d_castle": [1135, 500, 1440, 672],
    "o_spikes": [15, 735, 205, 840], "o_pools": [205, 735, 375, 840], "o_blocks": [375, 735, 540, 840],
    "o_ghostplat": [15, 860, 225, 950], "o_starfall": [225, 860, 380, 955], "o_hooks": [380, 860, 540, 955],
    "o_mist": [15, 965, 540, 1072],
    "c_stars": [555, 735, 712, 800], "c_moons": [712, 735, 865, 800], "c_hearts": [865, 735, 1020, 800],
    "c_key": [555, 820, 735, 905], "c_orb": [735, 820, 890, 905], "c_isles": [890, 795, 1020, 905],
    "c_flag": [555, 922, 650, 1072], "c_signs": [650, 922, 790, 1072], "c_portal": [790, 922, 905, 1072],
    "c_chest": [905, 922, 1020, 1072],
    "bg_sky": [1040, 730, 1440, 870], "bg_isles": [1040, 885, 1240, 965], "bg_falls": [1240, 885, 1440, 965],
    "bg_clouds": [1040, 990, 1170, 1072], "bg_ghosts": [1170, 990, 1300, 1072], "bg_shadows": [1300, 990, 1440, 1072],
}

if __name__ == "__main__":
    what = sys.argv[1:] or ["boss", "enemies", "tiles"]
    if "boss" in what:
        inspect_panels("jefemundo8.png", "boss", BOSS_PANELS, 40, 300)
    if "enemies" in what:
        inspect_panels("enemies_world_8.png", "enemies", ENEMY_PANELS, 34, 80)
    if "tiles" in what:
        inspect_panels("tilesets_world_8.png", "tiles", TILE_PANELS, 30, 60)
    print(f"Diagnóstico escrito en {OUT}")
