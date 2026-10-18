"""Diagnóstico reproducible de cajas de sprites del Mundo 5.

No genera recursos finales: enumera componentes y dibuja las regiones candidatas para que
world5_sources.json pueda corregirse a mano sin depender de una cuadrícula.
Uso: python tools/world5/detect_world5.py   -> tools/out/world5/detected_*.png/json
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world5"
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
    image = np.array(Image.open(ROOT / "imagenes" / "jefemundo5.png").convert("RGBA"))
    # alfa >= 240: descarta el halo magenta semitransparente y conserva el aura cósmica
    boxes = connected_boxes(image[..., 3] >= 240, 0, 0, 2500, 1)
    save_debug(image, {"boss": (None, boxes)}, "boss")


def inspect_panels(file: str, name: str, panels: dict, distance: int = 42, minimum: int = 150) -> None:
    image = np.array(Image.open(ROOT / "imagenes" / file).convert("RGBA"))
    groups = {}
    for key, (x0, y0, x1, y1) in panels.items():
        crop = image[y0:y1 + 1, x0:x1 + 1]
        groups[key] = ([x0, y0, x1, y1], connected_boxes(panel_mask(crop, distance), x0, y0, minimum))
    save_debug(image, groups, name)


# Paneles bajo el rótulo de cada animación (enemies_world_5.png)
ENEMY_PANELS = {
    "star_idle": [26, 230, 326, 302], "star_walk": [342, 230, 772, 302], "star_attack": [788, 230, 1150, 302],
    "star_hurt": [26, 336, 338, 418], "star_defeated": [352, 336, 733, 418], "star_fx": [748, 336, 1210, 418],
    "met_idle": [26, 533, 328, 606], "met_walk": [342, 533, 738, 606], "met_attack": [752, 533, 1152, 606],
    "met_hurt": [26, 640, 338, 720], "met_defeated": [354, 640, 735, 720], "met_fx": [750, 640, 1198, 720],
    "rkt_idle": [26, 838, 330, 912], "rkt_walk": [344, 838, 745, 912], "rkt_attack": [759, 838, 1155, 912],
    "rkt_hurt": [26, 948, 343, 1048], "rkt_defeated": [357, 948, 746, 1048], "rkt_fx": [760, 948, 1211, 1048],
}

TILE_PANELS = {
    "terrain_row1": [18, 148, 715, 250], "terrain_slopes": [18, 290, 310, 485], "terrain_hanging": [312, 290, 715, 478],
    "plat_cloud": [740, 150, 900, 232], "plat_star": [900, 150, 1060, 232], "plat_moon": [1062, 140, 1430, 230],
    "plat_hang": [740, 265, 905, 405], "plat_rocket": [905, 265, 1140, 405], "plat_obs": [1140, 228, 1430, 505],
    "plat_slide": [740, 425, 1140, 512],
    "sky_particles": [18, 582, 195, 668], "sky_falls": [195, 578, 305, 680], "sky_meteor": [305, 578, 420, 705],
    "sky_trail": [18, 692, 280, 770], "sky_fog": [280, 700, 420, 760], "sky_clouds": [18, 772, 420, 855],
    "dec_obs": [440, 560, 870, 720], "dec_fence": [440, 740, 580, 815], "dec_lamps": [580, 740, 720, 830],
    "dec_hang": [720, 740, 870, 830], "dec_extra": [440, 838, 870, 905],
    "haz_meteor": [890, 578, 1095, 690], "haz_rocket": [1095, 578, 1430, 665], "haz_fall": [890, 690, 1075, 800],
    "haz_clouds": [1075, 690, 1270, 800], "haz_launch": [1270, 690, 1430, 800],
    "coll_stars": [20, 940, 125, 1015], "coll_moons": [130, 940, 245, 1015], "coll_special": [250, 930, 340, 1015],
    "coll_flag": [345, 925, 455, 1030], "coll_sign": [455, 925, 545, 1030], "coll_portal": [548, 925, 680, 1030],
    "coll_rocket": [680, 925, 845, 1022],
    "bg_moon": [885, 880, 1000, 1005], "bg_planets": [960, 880, 1100, 1000], "bg_islands": [1100, 880, 1290, 1020],
    "bg_trails": [1290, 880, 1430, 990], "bg_clouds": [885, 1010, 1430, 1068],
}

if __name__ == "__main__":
    inspect_boss()
    inspect_panels("enemies_world_5.png", "enemies", ENEMY_PANELS, 40)
    inspect_panels("tilesets_world_5.png", "tiles", TILE_PANELS, 34)
    print(f"Diagnóstico escrito en {OUT}")
