"""Diagnóstico reproducible de cajas de sprites del Mundo 6.

No genera recursos finales: enumera componentes y dibuja las regiones candidatas para que
world6_sources.json pueda corregirse a mano sin depender de una cuadrícula.
Uso: python tools/world6/detect_world6.py   -> tools/out/world6/detected_*.png/json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world6"
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
    image = np.array(Image.open(ROOT / "imagenes" / "jefemundo6.png").convert("RGBA"))
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


# Paneles bajo el rótulo de cada animación (enemies_world_6.png)
ENEMY_PANELS = {
    "clown_idle": [400, 192, 660, 318], "clown_jump": [672, 192, 1018, 318], "clown_attack": [1030, 192, 1428, 318],
    "clown_hurt": [400, 356, 690, 482], "clown_defeated": [700, 356, 995, 482], "clown_fx": [1005, 356, 1428, 482],
    "block_idle": [400, 540, 645, 622], "block_walk": [655, 540, 992, 622], "block_attack": [1000, 540, 1428, 622],
    "block_hurt": [400, 666, 688, 770], "block_defeated": [696, 666, 992, 770], "block_fx": [1005, 666, 1428, 770],
    "wagon_idle": [400, 826, 648, 930], "wagon_move": [660, 826, 1000, 930], "wagon_attack": [1012, 826, 1428, 930],
    "wagon_hurt": [400, 968, 668, 1072], "wagon_defeated": [676, 968, 1000, 1072], "wagon_fx": [1005, 968, 1428, 1072],
}

TILE_PANELS = {
    "t_top": [18, 175, 480, 250], "t_center": [18, 265, 480, 335], "t_edges": [18, 345, 265, 425],
    "t_ramps": [268, 345, 480, 425], "t_bottom": [18, 455, 480, 545],
    "p_wood": [508, 175, 1000, 238], "p_blocks": [508, 255, 740, 340], "p_clouds": [745, 258, 1000, 345],
    "p_heli": [508, 357, 855, 470], "p_rainbow": [858, 368, 1000, 470], "p_station": [508, 480, 1000, 552],
    "r_rails": [1025, 178, 1435, 240], "r_curves": [1025, 258, 1205, 360], "r_special": [1208, 265, 1435, 345],
    "r_wagons": [1025, 383, 1435, 470], "r_conn": [1025, 490, 1435, 552],
    "d_all": [12, 598, 460, 935],
    "h_trains": [478, 618, 935, 750], "h_heli": [478, 768, 690, 860], "h_springs": [695, 768, 790, 860],
    "h_fall": [795, 768, 935, 860], "h_wheels": [478, 880, 700, 935], "h_bumper": [710, 880, 935, 935],
    "c_stars": [955, 630, 1150, 700], "c_ticket": [1152, 640, 1235, 715], "c_block": [1238, 640, 1340, 715],
    "c_flag": [1345, 635, 1435, 735], "c_signs": [955, 755, 1225, 860], "c_portal": [1225, 755, 1435, 860],
    "bg_strip": [12, 985, 1438, 1075],
}

if __name__ == "__main__":
    what = sys.argv[1:] or ["boss", "enemies", "tiles"]
    if "boss" in what:
        inspect_boss()
    if "enemies" in what:
        inspect_panels("enemies_world_6.png", "enemies", ENEMY_PANELS, 40)
    if "tiles" in what:
        inspect_panels("tilesets_world_6.png", "tiles", TILE_PANELS, 34)
    print(f"Diagnóstico escrito en {OUT}")
