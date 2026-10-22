"""
Datos del MUNDO 3 — El Reino de los Peluches Dormilones (diseño del nivel).

Uso:  python tools/world3/world3_level.py
Escribe godot/data/world3/world3.json (nivel) y godot/data/world3/world3_boss.json (arena).

Mismo formato que el Mundo 2: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 565 x 25 teselas (9.040 px) + arena (60).

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Por eso ningún escalón supera 3 teselas, los huecos sin ayuda miden <= 5 y todo lo
que está más alto se alcanza con almohadas elásticas, ascensores, cuerdas o corrientes.

  A El rincón de los juguetes     0-1.700   tutorial: bloques, primera almohada, conejitos
  B Los puentes de lana       1.700-3.500   cuerdas oscilantes sobre huecos anchos, ovillos
  C Las almohadas flotantes   3.500-5.500   plataformas móviles, ascensor, nubes que se deshacen
  D El laberinto de las mantas 5.500-7.800  escalones de mantas, nubes de sueño, botón mágico
  E El castillo de los sueños 7.800-10.000  aproximación al castillo de bloques y arena
"""
import json
import math
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from level_schema import compact  # noqa: E402  (esquema común, IMP-015)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world3"
ROWS = 25
LEVEL_W = 565
ARENA_W = 60


def g(x, w, top=20):
    """Suelo que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top}


def row(x0, x1, y, step=4):
    return [{"x": x, "y": y} for x in range(x0, x1 + 1, step)]


def arc(x0, x1, y, height=2, step=3):
    """Estrellas en arco (huecos y saltos): y es la fila de los extremos."""
    n = x1 - x0
    return [{"x": x, "y": y - round(math.sin(math.pi * (x - x0) / n) * height)} for x in range(x0, x1 + 1, step)]


def column(x, y0, y1):
    return [{"x": x, "y": y} for y in range(y0, y1 + 1, 2)]


def enemy(t, x, y, a, b):
    return {"type": t, "x": x, "y": y, "patrol": [a, b]}


background = {
    "sky": "w3_sky", "far": "w3_clouds_far", "near": "w3_clouds_near",
    "atlas": "world3_bg", "objectsAtlas": "world3_objects", "sparkles": True,
    "drifters": [],
    # sólo la franja alta de word_3.png: ventana, luna, móvil y cuna (sin plataformas pintadas)
    "layers": [
        {"scroll": [0.01, 0.02], "depth": 2, "items": [{"frame": "bg_reference", "x": 240, "y": 52, "alpha": 0.95}]},
    ],
}

terrain = [
    # A — El rincón de los juguetes
    g(0, 36), g(40, 30), g(74, 38, 19),
    # B — Los puentes de lana (huecos de 10 y 15 teselas: sólo se cruzan en las cuerdas)
    g(122, 19), g(151, 28, 19), g(194, 26),
    # C — Las almohadas flotantes
    g(230, 17), g(254, 22, 14), g(290, 23, 19), g(318, 26),
    # D — El laberinto de las mantas (escalones de 2 teselas y muro alto del ascensor)
    g(344, 22), g(366, 15, 18), g(381, 15, 16), g(405, 21, 16), g(426, 17), {"x": 443, "y": 23, "w": 3, "h": 2}, g(446, 17, 12), g(463, 25),
    # E — El castillo de los sueños
    g(493, 20, 19), g(517, 48, 19),
]

blocks = [
    {"x": 16, "y": 19, "type": "block_pink"}, {"x": 17, "y": 19, "type": "block_blue"}, {"x": 17, "y": 18, "type": "block_star"},
    {"x": 58, "y": 17, "type": "block_check_pink"}, {"x": 59, "y": 17, "type": "block_button"}, {"x": 60, "y": 17, "type": "block_check_blue"},
    {"x": 88, "y": 16, "type": "block_heart"}, {"x": 89, "y": 16, "type": "block_star"},
    {"x": 200, "y": 17, "type": "block_pink"}, {"x": 201, "y": 17, "type": "block_heart"},
    {"x": 330, "y": 17, "type": "block_blue"}, {"x": 331, "y": 17, "type": "block_star"},
    {"x": 520, "y": 16, "type": "block_check_pink"}, {"x": 521, "y": 16, "type": "block_button"},
]

# Plataformas unidireccionales (x = centro, y = superficie)
clouds = [
    {"x": 38, "y": 18, "frame": "cloud_pink"},                                              # ayuda en el primer hueco
    {"x": 30, "y": 14, "frame": "cloud_white"}, {"x": 34, "y": 12, "frame": "cloud_blue"},  # tras la 1.ª almohada: luna 1
    {"x": 213, "y": 13, "frame": "cloud_white"}, {"x": 217, "y": 11, "frame": "cloud_pink"},  # botón dorado 1
    {"x": 315, "y": 18, "frame": "cloud_blue"},
    {"x": 490, "y": 18, "frame": "cloud_pink"},
    {"x": 502, "y": 14, "frame": "cloud_white"}, {"x": 506, "y": 12, "frame": "cloud_blue"},  # botón dorado 3
]

movers = [
    {"x": 221, "y": 19, "frame": "cloud_blue", "dx": 7, "dy": 0, "duration": 2600},        # 0: cruza el hueco 220-229
    {"x": 250, "y": 19, "frame": "cloud_pink", "dx": 0, "dy": -6, "duration": 2800},       # 1: ascensor a la meseta
    {"x": 303, "y": 12, "frame": "cloud_white", "dx": 6, "dy": 0, "duration": 2400},       # 2: secreto tras la almohada
    {"x": 397, "y": 16, "frame": "cloud_blue", "dx": 6, "dy": 0, "duration": 2600},        # 3: cruza el hueco 396-404
    {"x": 444.5, "y": 21, "frame": "cloud_pink", "dx": 0, "dy": -10, "duration": 3400, "active": False},  # 4: ascensor del botón (pozo poco hondo junto al muro)
]

# Cuerdas: x, y = anclaje; el asiento cuelga `length` px por debajo (fila 17,5).
swings = [
    {"x": 117, "y": 13, "length": 72, "amplitude": 0.6, "duration": 2800},
    {"x": 146, "y": 13, "length": 72, "amplitude": 0.6, "duration": 2600},
    {"x": 183, "y": 13, "length": 72, "amplitude": 0.6, "duration": 2800},
    {"x": 189, "y": 13, "length": 72, "amplitude": 0.6, "duration": 2800, "delay": 1400},  # a contratiempo
]

crumbles = [{"x": x, "y": y, "frame": "cloud_white"} for x, y in [(279, 15), (283, 14), (287, 15)]]

pads = [
    {"x": 26, "y": 20, "frame": "pillow_pad", "power": -470},
    {"x": 96, "y": 19, "frame": "pillow_pad", "power": -470},
    {"x": 210, "y": 20, "frame": "pillow_pad", "power": -500},
    {"x": 299, "y": 19, "frame": "pillow_pad", "power": -500},
    {"x": 498, "y": 19, "frame": "pillow_pad", "power": -480},
]

# sin corrientes: en un nivel de huecos y nubes que se deshacen, flotar sin control confunde
winds = []

yarn_rollers = [
    {"x": 160, "y": 19, "range": [153, 176], "speed": 55, "frame": "yarn_ball_pink"},
    {"x": 370, "y": 18, "range": [367, 379], "speed": 50, "frame": "yarn_ball_pink"},
    {"x": 415, "y": 16, "range": [406, 424], "speed": 65, "frame": "yarn_ball_pink"},
    {"x": 470, "y": 20, "range": [465, 485], "speed": 60, "frame": "yarn_ball_pink"},
]

# y = fila del centro de la nube (la zona cubre w x h teselas)
sleep_clouds = [
    {"x": 358, "y": 18.5, "w": 4, "h": 2, "duration": 2400},
    {"x": 415, "y": 14.5, "w": 4, "h": 2, "duration": 2400},
    {"x": 454, "y": 10.5, "w": 4, "h": 2, "duration": 2400},
    {"x": 476, "y": 18.5, "w": 5, "h": 2, "duration": 2400},
]

magic_buttons = [{"x": 432, "y": 20, "frame": "magic_button", "targetMover": 4}]

dream = [
    {"id": "moon_1", "kind": "moon", "x": 34, "y": 9},
    {"id": "moon_2", "kind": "moon", "x": 283, "y": 11},
    {"id": "moon_3", "kind": "moon", "x": 459, "y": 9},
    {"id": "button_1", "kind": "button", "x": 217, "y": 8},
    {"id": "button_2", "kind": "button", "x": 311, "y": 9},
    {"id": "button_3", "kind": "button", "x": 506, "y": 9},
]

stars = (
    # A
    row(6, 14, 19) + arc(14, 20, 19, 2) + row(24, 32, 19) + column(26, 15, 17) + arc(35, 41, 18, 2)
    + row(44, 56, 19) + row(57, 61, 16, 2) + row(63, 69, 19) + arc(69, 75, 18, 2)
    + row(80, 86, 18) + row(87, 90, 15, 2) + column(96, 12, 16) + row(100, 110, 18)
    # B
    + arc(111, 123, 16, 2) + row(126, 138, 19) + arc(140, 152, 16, 2) + row(156, 176, 18, 4)
    + arc(178, 195, 16, 2) + row(198, 206, 19) + row(212, 214, 12, 2) + row(216, 218, 10, 2)
    # C
    + arc(219, 230, 18, 2) + row(232, 246, 19, 4) + column(250, 13, 17) + row(256, 274, 13, 4)
    + arc(276, 289, 13, 2) + row(292, 298, 18) + row(302, 309, 11) + arc(312, 318, 18, 2) + row(320, 342, 19, 4)
    # D
    + row(346, 364, 19, 4) + row(367, 379, 17, 4) + row(382, 394, 15, 4) + arc(395, 405, 15, 2)
    + row(407, 424, 15, 4) + row(428, 442, 19, 4) + column(444, 12, 17) + row(448, 461, 11, 4)
    + row(465, 486, 19, 4)
    # E
    + arc(487, 493, 18, 2) + row(495, 511, 18, 4) + arc(512, 517, 18, 2) + row(519, 555, 18, 4)
)

enemies = (
    [enemy("rabbit", x, y, a, b) for x, y, a, b in [(50, 20, 44, 64), (84, 19, 76, 94), (200, 20, 195, 207), (330, 20, 324, 342), (388, 16, 382, 394), (480, 20, 470, 486), (528, 19, 518, 540)]]
    + [enemy("wool", x, y, a, b) for x, y, a, b in [(169, 19, 164, 174), (236, 20, 231, 245), (352, 20, 345, 364), (438, 20, 434, 443), (502, 19, 494, 511)]]
    # las almohadas flotan 3-4 teselas sobre el suelo: se alcanzan de un salto
    + [enemy("pillow", x, y, a, b) for x, y, a, b in [(242, 16, 232, 246), (264, 10, 256, 274), (294, 15, 291, 311), (338, 16, 330, 343), (456, 8, 448, 461), (536, 15, 524, 548)]]
)

# IMP-001: uno por sección (o a <= 320 px de su entrada), ningún tramo > 2.500 px
checkpoints = [{"x": 109, "y": 19}, {"x": 214, "y": 20}, {"x": 322, "y": 20}, {"x": 409, "y": 16}, {"x": 485, "y": 20}]

signs = [
    {"x": 5, "y": 20, "text": "Mundo 3: El Reino de los Peluches Dormilones. ¡Tus tres armas te acompañan!"},
    {"x": 23, "y": 20, "text": "Las almohadas elásticas te lanzan muy alto: ¡salta encima!"},
    {"x": 106, "y": 19, "text": "Sube a la cuerda cuando se acerque y salta al otro lado en su vaivén"},
    {"x": 272, "y": 14, "text": "Las nubes blancas se deshacen al pisarlas: ¡no te detengas!"},
    {"x": 347, "y": 20, "text": "Las nubes violetas dan sueño: vas más lenta, pero sigues al mando"},
    {"x": 428, "y": 20, "text": "Pisa el botón mágico para despertar el ascensor de nube"},
    {"x": 548, "y": 19, "text": "El Castillo de los Sueños: el Rey Siestón te espera"},
]

decor = [
    {"x": x, "y": y, "frame": f, "front": front} for x, y, f, front in [
        (10, 20, "flower_pink", True), (46, 20, "yarn_ball_blue", False), (66, 20, "yarn_ball_blue", False),
        (102, 19, "yarn_ball_blue", False), (128, 20, "flower_pink", True), (205, 20, "yarn_ball_blue", False),
        (240, 20, "yarn_ball_blue", False), (268, 14, "yarn_ball_blue", False), (308, 19, "flower_pink", True),
        (340, 20, "yarn_ball_blue", False), (392, 16, "yarn_ball_blue", False), (458, 12, "flower_pink", True),
        (509, 19, "yarn_ball_blue", False), (533, 19, "yarn_ball_blue", False), (552, 19, "yarn_ball_blue", False),
    ]
]

level = {
    "id": 3, "key": "world3", "name": "El Reino de los Peluches Dormilones", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world3", "tileset": "world3_tiles", "objectsAtlas": "world3_objects", "backgroundAtlas": "world3_bg",
    "progress": {"total": 10000, "offset": 0, "scale": 1}, "playerStart": {"x": 3, "y": 20}, "nextScene": "Boss3",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w3", "signpost": "sign_block", "star": ["world3_objects", "star_w3"]},
    "sections": [
        {"id": "A", "name": "El rincón de los juguetes", "from": 0},
        {"id": "B", "name": "Los puentes de lana", "from": 1700},
        {"id": "C", "name": "Las almohadas flotantes", "from": 3500},
        {"id": "D", "name": "El laberinto de las mantas", "from": 5500},
        {"id": "E", "name": "El castillo de los sueños", "from": 7800},
    ],
    "background": background, "terrain": terrain, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": swings, "crumbles": crumbles, "pads": pads,
    "winds": winds, "hazards": [], "paints": [], "rollers": [], "bouncers": [], "drips": [], "rivers": [],
    "magicCrayons": [], "yarnRollers": yarn_rollers, "sleepClouds": sleep_clouds, "magicButtons": magic_buttons,
    "dreamCollectibles": dream, "stars": stars, "enemies": enemies, "checkpoints": checkpoints, "pickups": [],
    "signs": signs, "decor": decor,
    "door": {"x": 558, "y": 19, "atlas": "world3_objects", "frame": "castle_w3", "scale": 1.0},
}

boss = {
    "key": "world3_boss", "worldId": 3, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world3", "bossMusic": "sieston",
    "tileset": "world3_tiles", "objectsAtlas": "world3_objects", "backgroundAtlas": "world3_bg", "background": background,
    "frames": level["frames"], "progress": {"total": 10000, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "El castillo de los sueños", "from": 7800}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3}], "blocks": [],
    "clouds": [{"x": 15, "y": 10, "frame": "cloud_pink"}, {"x": 44, "y": 10, "frame": "cloud_blue"}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 9} for x in [14, 15, 16, 43, 44, 45]],
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [{"x": 3, "y": 14, "frame": "flower_pink", "front": True}, {"x": 30, "y": 14, "frame": "yarn_ball_blue"}, {"x": 55, "y": 14, "frame": "flower_pink", "front": True}],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_star"}, "triggerX": 9,
    "boss": {"homeX": 34, "minX": 8, "maxX": 58, "floorY": 224, "frameBoth": True, "scene": "res://scenes/bosses/ReySieston.tscn",
             "name": "Rey Siestón", "introBanner": "¡Rey Siestón, el Rey de los Peluches Dormilones!",
             "defeatBanner": "¡El reino vuelve a dormir en paz!", "portalToast": "El portal al Mundo 4 está preparado", "afterMusic": "world3"},
    "portal": {"x": 57, "y": 14},
}

# IMP-027: ningún Ovillo (embiste) patrulla a menos de 4 teselas de un foso que se cruza con
# cuerda: su golpe y el retroceso lanzarían a Alice al vacío. La plataforma entre las cuerdas de
# la sección B (122-140) queda de descanso; el Ovillo pasa al suelo continuo de la 152-177.
ground = {x for t in terrain for x in range(t["x"], t["x"] + t["w"])}
rope_pits = [x for x in range(int(level["widthTiles"])) if x not in ground and any(abs(x - s["x"]) <= 6 for s in swings)]
for e in enemies:
    if e["type"] == "wool":
        a, b = e["patrol"]
        assert all(p < a - 4 or p > b + 4 for p in rope_pits), f"Ovillo junto a un foso con cuerda: {e}"

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world3.json", level), ("world3_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(compact(data), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 3: {len(stars)} estrellas, {len(enemies)} enemigos, ancho total {(LEVEL_W + ARENA_W) * 16} px")
