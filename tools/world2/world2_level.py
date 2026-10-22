"""
Datos del MUNDO 2 — El Reino de los Crayones Encantados (diseño del nivel).

Uso:  python tools/world2/world2_level.py
Escribe godot/data/world2/world2.json (nivel) y godot/data/world2/world2_boss.json (arena).

Mismo formato y unidades que src/data/world1.js: x, y, w, h en TESELAS de 16 px; para objetos
apoyados en el suelo `y` es la fila de la superficie. El motor (Level/LevelBuilder) no cambia:
sólo se añaden listas nuevas (rulers, paints, rollers, bouncers, drips, rivers, magicCrayons)
que el Mundo 1 no usa.

Recorrido: 474 x 25 teselas (7.584 px) + arena del Gran Lienzo (60 teselas) = 9.000 px.
  A Escritorio gigante    0-1.500   B Jardín de crayones 1.500-3.300   C Río de pintura 3.300-5.200
  D Fábrica de dibujos 5.200-7.300  E El Gran Lienzo     7.300-9.000 (aproximación + arena)
"""
import json
import math
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from level_schema import compact  # noqa: E402  (esquema común, IMP-015)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "godot", "data", "world2")
ROWS = 25
LEVEL_W = 474
ARENA_W = 60


def g(x, w, top=20):
    """Suelo que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top}


def f(x, y, w, h):
    """Fragmento flotante con base redondeada."""
    return {"x": x, "y": y, "w": w, "h": h}


def row(x, y, n, step=1):
    return [{"x": x + i * step, "y": y} for i in range(n)]


def arc(x, y, n, height=2):
    return [{"x": x + i, "y": y - round(math.sin(math.pi * i / (n - 1)) * height)} for i in range(n)]


def enemy(t, x, y, a, b):
    return {"type": t, "x": x, "y": y, "patrol": [a, b]}


LEVEL = {
    "id": 2,
    "key": "world2",
    "name": "El Reino de los Crayones Encantados",
    "widthTiles": LEVEL_W,
    "heightTiles": ROWS,
    "music": "world2",
    "tileset": "world2_tiles",
    "objectsAtlas": "world2_objects",
    "backgroundAtlas": "world2_bg",
    "progress": {"total": 9000, "offset": 0, "scale": 1},
    "playerStart": {"x": 3, "y": 20},
    "nextScene": "Boss2",
    # el Mundo 2 empieza con las tres armas del Mundo 1
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w2", "signpost": "signpost_w2", "star": ["world2_objects", "star_big"]},
    "sections": [
        {"id": "A", "name": "Escritorio gigante", "from": 0},
        {"id": "B", "name": "Jardín de crayones", "from": 1500},
        {"id": "C", "name": "Río de pintura", "from": 3300},
        {"id": "D", "name": "Fábrica de dibujos", "from": 5200},
        {"id": "E", "name": "El Gran Lienzo", "from": 7300},
    ],
    # Capas del fondo (word_2.png como referencia de composición): cielo, arcoíris y castillo
    # lejanos, nubes, hojas de cuaderno y garabatos a media distancia, estrellas colgantes.
    "background": {
        "sky": "w2_sky", "far": "w2_clouds_far", "near": "w2_clouds_near",
        "atlas": "world2_bg", "objectsAtlas": "world2_objects", "sparkles": True,
        "drifters": ["cloud_small", "cloud_puffy", "cloud_long"],
        "layers": [
            {"scroll": [0.02, 0.04], "depth": 2, "items": [{"frame": "bg_rainbow", "x": 250, "y": 84, "alpha": 0.95, "scale": 1.3}]},
            {"scroll": [0.05, 0.08], "depth": 3, "items": [{"frame": "bg_castle", "x": 300, "y": 120}]},
            {"scroll": [0.12, 0.05], "depth": 4, "frames": ["bg_cloud_face", "bg_cloud_a"], "step": 280, "y": [30, 80], "alpha": 0.9, "scale": 0.85, "bob": True},
            {"scroll": [0.2, 0.08], "depth": 5, "frames": ["bg_scrap_a", "bg_scrap_b", "bg_scrap_c", "bg_doodle_heart", "bg_doodle_star", "bg_doodle_sun", "bg_doodle_flower"], "step": 150, "y": [70, 150], "alpha": 0.8, "bob": True},
            {"scroll": [0.32, 0.1], "depth": 6, "frames": ["bg_star_hang_a", "bg_star_hang_b"], "step": 120, "y": [0, 0], "top": True, "sway": True},
        ],
    },
    "terrain": [
        # A — Escritorio gigante
        g(0, 22), g(25, 14), g(47, 13), f(66, 17, 8, 2), g(74, 20),
        # B — Jardín de crayones
        g(94, 24), g(122, 10, 19), g(141, 22, 19), g(173, 14, 19), g(204, 15, 19),
        # C — Río de pintura
        f(237, 19, 6, 3), g(249, 16, 19), g(282, 18, 19), g(306, 44, 19),
        # D — Fábrica de dibujos
        g(355, 25, 19), g(380, 14, 16), g(400, 30, 19),
        # D/E — llegada al Gran Lienzo
        g(434, 40, 19),
    ],
    "blocks": [
        {"x": 29, "y": 17, "type": "block_a"}, {"x": 30, "y": 17, "type": "block_b"}, {"x": 31, "y": 17, "type": "block_c"},
        {"x": 70, "y": 16, "type": "block_notebook"},
        {"x": 334, "y": 13, "type": "block_notebook"}, {"x": 342, "y": 13, "type": "block_notebook_heart"},
        {"x": 377, "y": 18, "type": "block_a"}, {"x": 378, "y": 18, "type": "block_b"}, {"x": 378, "y": 17, "type": "block_c"},
        {"x": 379, "y": 18, "type": "block_star_w2"}, {"x": 379, "y": 17, "type": "block_heart_w2"}, {"x": 379, "y": 16, "type": "block_color"},
        {"x": 386, "y": 15, "type": "block_color"}, {"x": 386, "y": 14, "type": "block_star_w2"}, {"x": 386, "y": 13, "type": "block_heart_w2"},
        {"x": 412, "y": 13, "type": "block_notebook_star"},
        {"x": 446, "y": 15, "type": "block_a"}, {"x": 447, "y": 15, "type": "block_b"}, {"x": 448, "y": 15, "type": "block_c"},
    ],
    # Plataformas unidireccionales (x = centro, y = superficie). "top": px del borde del dibujo a la superficie.
    "clouds": [
        {"x": 23, "y": 18, "frame": "book_pink"},
        {"x": 53, "y": 16, "frame": "book_blue"},
        {"x": 80, "y": 16, "frame": "crayon_plat_pink"},
        {"x": 84, "y": 14, "frame": "crayon_plat_blue"},
        {"x": 88, "y": 12, "frame": "crayon_plat_yellow"},
        {"x": 145, "y": 15, "frame": "cloud_puffy"},
        {"x": 150, "y": 12, "frame": "cloud_face"},
        {"x": 156, "y": 14, "frame": "cloud_long"},
        {"x": 240, "y": 11, "frame": "cloud_puffy"},
        {"x": 246, "y": 9, "frame": "cloud_long"},
        {"x": 252, "y": 8, "frame": "cloud_face"},
        {"x": 286, "y": 14, "frame": "book_pink"},
        {"x": 292, "y": 12, "frame": "book_blue"},
        {"x": 302, "y": 18, "frame": "cloud_puffy"},
        {"x": 431, "y": 18, "frame": "cloud_puffy"},
    ],
    "bridges": [],
    "rulers": [
        {"x": 39, "y": 20, "w": 8},
        {"x": 60, "y": 20, "to": [66, 17]},
        {"x": 132, "y": 19, "w": 9, "drawn": True, "cycle": [2600, 1600, 0]},
        {"x": 163, "y": 19, "w": 10, "switch": [160, 19]},
        {"x": 187, "y": 19, "points": [[191, 20], [195, 21], [199, 20], [204, 19]]},
        {"x": 350, "y": 19, "w": 5, "drawn": True},
        {"x": 394, "y": 16, "to": [400, 19]},
    ],
    "movers": [
        {"x": 222, "y": 19, "frame": "notebook_plat", "top": 6, "dx": 11, "dy": 0, "duration": 3000},
        {"x": 244, "y": 19, "frame": "book_blue", "dx": 3, "dy": 0, "duration": 1600},
    ],
    "crumbles": [
        {"x": 267, "y": 18, "frame": "notebook_page"},
        {"x": 271, "y": 17, "frame": "notebook_page"},
        {"x": 275, "y": 18, "frame": "notebook_page"},
        {"x": 279, "y": 17, "frame": "notebook_page"},
    ],
    "pads": [],
    "winds": [],
    "hazards": [
        {"x": 262, "y": 18, "frame": "splash_pink"},
        {"x": 452, "y": 17, "frame": "splash_blue", "dy": -2, "duration": 1300},
    ],
    "paints": [
        {"x": 100, "y": 20, "w": 12, "color": "blue"},
        {"x": 237, "y": 19, "w": 6, "color": "yellow"},
        {"x": 312, "y": 19, "w": 6, "color": "yellow"},
        {"x": 330, "y": 19, "w": 9, "color": "pink"},
        {"x": 420, "y": 19, "w": 7, "color": "pink"},
        {"x": 438, "y": 19, "w": 8, "color": "blue"},
    ],
    "rollers": [
        {"x": 340, "y": 19, "range": [331, 348], "speed": 55},
        {"x": 405, "y": 19, "range": [402, 418], "speed": 70},
        {"x": 414, "y": 19, "range": [402, 418], "speed": 45},
    ],
    "bouncers": [
        {"x": 368, "y": 19, "height": 3, "period": 1200, "delay": 0},
        {"x": 372, "y": 19, "height": 3, "period": 1200, "delay": 600},
        {"x": 442, "y": 19, "height": 2.5, "period": 1000, "delay": 300},
    ],
    "drips": [
        {"x": 334, "y": 14, "color": "pink", "period": 1800},
        {"x": 342, "y": 14, "color": "blue", "period": 2200, "delay": 900},
        {"x": 412, "y": 14, "color": "yellow", "period": 1700},
    ],
    "rivers": [
        {"x": 219, "w": 18, "color": "blue"}, {"x": 243, "w": 6, "color": "pink"},
        {"x": 265, "w": 17, "color": "yellow"}, {"x": 300, "w": 6, "color": "blue"},
    ],
    "magicCrayons": [
        {"x": 150, "y": 12, "color": "red"},
        {"x": 252, "y": 8, "color": "blue"},
        {"x": 386, "y": 13, "color": "yellow"},
    ],
    "stars": (
        # A
        row(6, 19, 5) + arc(21, 18, 5) + row(29, 15, 3) + arc(39, 19, 8, 2) + row(51, 15, 4)
        + row(62, 18, 3) + row(67, 15, 4) + row(79, 15, 3) + row(87, 11, 3)
        # B
        + row(101, 19, 6) + arc(117, 18, 6) + row(133, 18, 6) + row(144, 14, 3) + row(154, 13, 4)
        + row(164, 18, 7) + row(188, 18, 3) + row(196, 19, 3)
        # C
        + row(208, 18, 4) + row(222, 17, 5) + row(239, 10, 3) + row(245, 8, 3) + row(255, 18, 4)
        + row(268, 16, 2) + row(276, 16, 2) + row(285, 13, 3) + row(291, 11, 3) + row(310, 18, 4)
        # D
        + row(326, 18, 3) + row(351, 18, 3) + row(360, 18, 4) + row(377, 16, 2) + row(383, 15, 4)
        + arc(394, 15, 6) + row(404, 16, 4) + row(424, 18, 3) + row(430, 16, 3)
        # E
        + row(440, 18, 4) + row(446, 14, 3) + row(455, 18, 4)
    ),
    "enemies": [
        enemy("eraser", 34, 20, 26, 38), enemy("eraser", 86, 20, 76, 92),
        enemy("crayon", 108, 20, 100, 116), enemy("crayon", 156, 19, 145, 161), enemy("crayon", 180, 19, 175, 185),
        enemy("brush", 258, 19, 252, 263), enemy("brush", 292, 19, 285, 298), enemy("brush", 316, 19, 308, 324),
        enemy("eraser", 344, 19, 339, 349), enemy("crayon", 364, 19, 358, 375), enemy("brush", 388, 16, 382, 393),
        enemy("crayon", 410, 19, 403, 417), enemy("eraser", 424, 19, 419, 429), enemy("brush", 446, 19, 437, 452),
    ],
    # IMP-001: uno por sección y ningún tramo > 2.500 px. El primero va antes del puente dibujado
    # (132-140), no después; el de la sección C, antes de los ríos con plataformas móviles
    "checkpoints": [{"x": 125, "y": 19}, {"x": 211, "y": 19}, {"x": 357, "y": 19}, {"x": 458, "y": 19}],
    "pickups": [],
    "signs": [
        {"x": 5, "y": 20, "text": "Mundo 2: el Reino de los Crayones Encantados. ¡Tus tres armas te acompañan!"},
        {"x": 36, "y": 20, "text": "Las reglas sirven de puente: ¡crúzalas!"},
        {"x": 58, "y": 20, "text": "Algunas reglas están inclinadas: sube con cuidado"},
        {"x": 97, "y": 20, "text": "La pintura AZUL resbala: frena con tiempo"},
        {"x": 129, "y": 19, "text": "Los puentes dibujados aparecen y desaparecen. ¡Atento al parpadeo!"},
        {"x": 158, "y": 19, "text": "Toca el molinillo para dibujar el puente"},
        {"x": 233, "y": 19, "text": "Cruza el río de pintura sobre los cuadernos"},
        {"x": 238, "y": 19, "text": "La pintura AMARILLA rebota. Mantén SALTAR para subir más"},
        {"x": 327, "y": 19, "text": "La pintura ROSA es pegajosa: te frena"},
        {"x": 348, "y": 19, "text": "¡Los borradores pueden borrar los puentes dibujados!"},
        {"x": 460, "y": 19, "text": "El Gran Lienzo. ¡Garabato te espera!"},
    ],
    "decor": [
        # A
        {"x": 2, "y": 20, "frame": "crayon_giant_pink"}, {"x": 3, "y": 20, "frame": "crayon_giant_blue"},
        {"x": 8, "y": 20, "frame": "bush_wide"}, {"x": 12, "y": 20, "frame": "flower_white", "front": True},
        {"x": 16, "y": 20, "frame": "books_stack"}, {"x": 19, "y": 20, "frame": "pinwheel_a", "sway": True},
        {"x": 27, "y": 20, "frame": "flower_tulip"}, {"x": 44, "y": 20, "frame": "pencil_giant_yellow"},
        {"x": 49, "y": 20, "frame": "bush_wide"}, {"x": 56, "y": 20, "frame": "notebook_page"},
        {"x": 68, "y": 17, "frame": "flower_white"}, {"x": 77, "y": 20, "frame": "crayon_giant_yellow"},
        {"x": 82, "y": 20, "frame": "flower_tulip", "front": True}, {"x": 91, "y": 20, "frame": "books_stack"},
        # B
        {"x": 95, "y": 20, "frame": "crayon_giant_purple"}, {"x": 96, "y": 20, "frame": "crayon_giant_pink"},
        {"x": 113, "y": 20, "frame": "pinwheel_b", "sway": True}, {"x": 115, "y": 20, "frame": "pencil_giant_blue"},
        {"x": 124, "y": 19, "frame": "bush_wide"}, {"x": 143, "y": 19, "frame": "crayon_giant_blue"},
        {"x": 148, "y": 19, "frame": "flower_white", "front": True}, {"x": 152, "y": 19, "frame": "pinwheel_a", "sway": True},
        {"x": 175, "y": 19, "frame": "crayon_giant_yellow"}, {"x": 177, "y": 19, "frame": "crayon_giant_pink"},
        {"x": 184, "y": 19, "frame": "bush_wide"}, {"x": 206, "y": 19, "frame": "pinwheel_b", "sway": True},
        # C
        {"x": 212, "y": 19, "frame": "notebook_page"}, {"x": 216, "y": 19, "frame": "paint_blue_puddle"},
        {"x": 251, "y": 19, "frame": "books_stack"}, {"x": 284, "y": 19, "frame": "flower_tulip"},
        {"x": 297, "y": 19, "frame": "paint_yellow_puddle"}, {"x": 308, "y": 19, "frame": "pencil_giant_blue"},
        {"x": 320, "y": 19, "frame": "notebook_page"},
        # D
        {"x": 328, "y": 19, "frame": "books_stack"}, {"x": 352, "y": 19, "frame": "paint_pink_puddle"},
        {"x": 356, "y": 19, "frame": "crayon_giant_purple"}, {"x": 362, "y": 19, "frame": "pencil_giant_yellow"},
        {"x": 382, "y": 16, "frame": "pinwheel_a", "sway": True}, {"x": 391, "y": 16, "frame": "books_stack"},
        {"x": 402, "y": 19, "frame": "notebook_page"}, {"x": 428, "y": 19, "frame": "crayon_giant_blue"},
        # E
        {"x": 436, "y": 19, "frame": "bush_wide"}, {"x": 444, "y": 19, "frame": "flower_white", "front": True},
        {"x": 450, "y": 19, "frame": "pinwheel_b", "sway": True}, {"x": 458, "y": 19, "frame": "crayon_giant_pink"},
        {"x": 459, "y": 19, "frame": "crayon_giant_yellow"}, {"x": 463, "y": 19, "frame": "books_stack"},
        {"x": 470, "y": 19, "frame": "crayon_giant_purple"}, {"x": 471, "y": 19, "frame": "pencil_giant_blue"},
    ],
    # Entrada al Gran Lienzo: al tocarla empieza la batalla contra Garabato
    "door": {"x": 466, "y": 19, "atlas": "world2_objects", "frame": "portal_w2", "scale": 1.0},
}

BOSS = {
    "key": "world2_boss",
    "worldId": 2,
    "widthTiles": ARENA_W,
    "heightTiles": 17,
    "music": "world2",
    "bossMusic": "garabato",
    "tileset": "world2_tiles",
    "objectsAtlas": "world2_objects",
    "backgroundAtlas": "world2_bg",
    "background": LEVEL["background"],
    "frames": LEVEL["frames"],
    "progress": {"total": 9000, "offset": LEVEL_W * 16, "scale": (9000 - LEVEL_W * 16) / (ARENA_W * 16)},
    "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "El Gran Lienzo", "from": 7300}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3}],
    "blocks": [],
    "clouds": [
        {"x": 16, "y": 10, "frame": "cloud_puffy"},
        {"x": 44, "y": 10, "frame": "cloud_puffy"},
    ],
    "bridges": [],
    "rulers": [{"x": 27, "y": 8, "w": 6}],
    "movers": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": row(14, 13, 3) + row(28, 7, 4) + row(43, 13, 3),
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [
        {"x": 1, "y": 14, "frame": "crayon_giant_pink"}, {"x": 2, "y": 14, "frame": "crayon_giant_blue"},
        {"x": 30, "y": 14, "frame": "flower_white", "front": True},
        {"x": 57, "y": 14, "frame": "books_stack"}, {"x": 59, "y": 14, "frame": "pencil_giant_yellow"},
    ],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_color"},
    "triggerX": 9,
    "boss": {
        "homeX": 36, "minX": 8, "maxX": 58, "floorY": 224, "frameBoth": True,
        "scene": "res://scenes/bosses/Garabato.tscn",
        "name": "Garabato",
        "introBanner": "¡Garabato, el Rey de los Crayones!",
        "defeatBanner": "¡Los colores mágicos vuelven al lienzo!",
        "portalToast": "Se ha abierto el portal al Mundo 3",
        "afterMusic": "world2",
    },
    "portal": {"x": 57, "y": 14},
}


def check(level):
    """Comprobaciones básicas de coherencia de los datos."""
    W = level["widthTiles"]
    for t in level["terrain"]:
        assert 0 <= t["x"] and t["x"] + t["w"] <= W, t
    for e in level["enemies"]:
        assert e["patrol"][0] <= e["x"] <= e["patrol"][1], e
    for s in level["stars"]:
        assert 0 <= s["x"] < W and 0 <= s["y"] < level["heightTiles"], s


def main():
    os.makedirs(OUT, exist_ok=True)
    check(LEVEL)
    check(BOSS)
    for name, d in (("world2.json", LEVEL), ("world2_boss.json", BOSS)):
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as fh:
            json.dump(compact(d), fh, indent=1, ensure_ascii=False)
    print(f"Mundo 2: {LEVEL['widthTiles']}x{ROWS} teselas ({LEVEL['widthTiles'] * 16} px) + arena {ARENA_W} teselas; "
          f"{len(LEVEL['stars'])} estrellas (+{len(BOSS['stars'])} en la arena), {len(LEVEL['enemies'])} enemigos, "
          f"{len(LEVEL['rulers'])} puentes de reglas, {len(LEVEL['paints'])} superficies de pintura")


if __name__ == "__main__":
    main()
