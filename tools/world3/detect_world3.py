"""Diagnóstico reproducible de cajas de sprites del Mundo 3.

No genera recursos finales: dibuja las regiones candidatas y enumera componentes
para que world3_sources.json pueda corregirse a mano sin depender de una cuadrícula.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "out" / "world3"
OUT.mkdir(parents=True, exist_ok=True)


def connected_boxes(mask: np.ndarray, x0: int, y0: int, minimum: int = 120) -> list[list[int]]:
    grown = ndimage.binary_dilation(mask, iterations=2)
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
    return sorted(boxes)


def enemy_mask(crop: np.ndarray) -> np.ndarray:
    """Separa el dibujo del panel pastel usando el color del borde y el contorno oscuro."""
    rgb = crop[..., :3].astype(np.int16)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    base = np.median(border, axis=0)
    distance = np.sqrt(((rgb - base) ** 2).sum(axis=2))
    # El fondo varía suavemente; el sprite tiene contorno oscuro y diferencias fuertes.
    return distance > 42


def inspect_enemies() -> None:
    image = np.array(Image.open(ROOT / "imagenes" / "enemies_world_3.png").convert("RGBA"))
    panels = {
        "rabbit_idle": [350, 55, 710, 180], "rabbit_walk": [720, 55, 1090, 180],
        "rabbit_jump": [1100, 55, 1430, 185], "rabbit_attack": [350, 215, 760, 350],
        "rabbit_hurt": [770, 215, 1040, 350], "rabbit_defeated": [1045, 215, 1430, 350],
        "wool_idle": [350, 420, 740, 555], "wool_roll": [740, 420, 1130, 555],
        "wool_jump": [1130, 410, 1430, 555], "wool_attack": [350, 570, 790, 710],
        "wool_hurt": [790, 570, 1050, 710], "wool_defeated": [1050, 570, 1430, 710],
        "pillow_idle": [350, 775, 740, 925], "pillow_fly": [740, 775, 1120, 925],
        "pillow_dash": [1120, 775, 1430, 925], "pillow_attack": [350, 930, 790, 1080],
        "pillow_hurt": [790, 930, 1050, 1080], "pillow_defeated": [1050, 930, 1430, 1080],
    }
    debug = Image.fromarray(image).convert("RGB")
    draw = ImageDraw.Draw(debug)
    result = {}
    for name, (x0, y0, x1, y1) in panels.items():
        crop = image[y0:y1 + 1, x0:x1 + 1]
        boxes = connected_boxes(enemy_mask(crop), x0, y0)
        result[name] = boxes
        draw.rectangle((x0, y0, x1, y1), outline=(255, 255, 0), width=2)
        for box in boxes:
            draw.rectangle(box[:4], outline=(0, 255, 0), width=2)
    debug.save(OUT / "detected_enemies.png")
    (OUT / "detected_enemies.json").write_text(json.dumps(result, indent=1), encoding="utf-8")


def inspect_boss() -> None:
    image = np.array(Image.open(ROOT / "imagenes" / "jefemundo3.png").convert("RGBA"))
    mask = image[..., 3] >= 220
    boxes = connected_boxes(mask, 0, 0, 1800)
    debug = Image.fromarray(image).convert("RGBA")
    flat = Image.new("RGBA", debug.size, (35, 28, 60, 255))
    flat.alpha_composite(debug)
    draw = ImageDraw.Draw(flat)
    for box in boxes:
        draw.rectangle(box[:4], outline=(0, 255, 0), width=2)
    flat.convert("RGB").save(OUT / "detected_boss.png")
    (OUT / "detected_boss.json").write_text(json.dumps(boxes, indent=1), encoding="utf-8")


if __name__ == "__main__":
    inspect_enemies()
    inspect_boss()
    print(f"Diagnóstico escrito en {OUT}")
