"""
Datos del MUNDO 4 — Reino de las Burbujas (diseño del nivel).

Uso:  python tools/world4/world4_level.py
Escribe godot/data/world4/world4.json (nivel) y godot/data/world4/world4_boss.json (arena).

Mismo formato que los Mundos 2 y 3: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 565 x 25 teselas (9.040 px) + arena (60) = 10.000 px.
El terreno tiene dos materiales del tileset oficial ("sponge": esponja, "tile": azulejo de baño).

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Ningún escalón supera 3 teselas sin ayuda; lo más alto se alcanza con géiseres,
columnas de burbujas, burbujas de salto o plataformas móviles. Las balsas de agua son seguras:
la superficie queda 1 tesela por debajo del borde y siempre hay salida (borde bajo o columna).

  A Las bañeras de espuma      0-1.800   azulejos, esponja, primeras burbujas, agua poco honda, Pez Burbuja
  B Los jardines del jabón 1.800-3.600   espuma resbaladiza, géiseres, jabones, Cangrejito, 1.er checkpoint
  C El canal de los patitos 3.600-5.600  canal con barquitos, columnas de burbujas, Pompas Traviesas
  D Las cataratas de burbujas 5.600-7.900 columna gigante, rodillos, tramo submarino, 2.º checkpoint
  E El trono de Patoburbuja 7.900-10.000 gran bañera real y la arena del jefe
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world4"
ROWS = 25
LEVEL_W = 565
ARENA_W = 60


def g(x, w, top=20, mat="tile"):
    """Suelo que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top, "mat": mat}


def pool(x, w, depth=2, surface=21, mat="tile"):
    """Balsa: fondo de terreno y agua desde `surface` (1 tesela por debajo del borde)."""
    floor = surface + depth
    return [{"x": x, "y": floor, "w": w, "h": ROWS - floor, "mat": mat}], {"x": x, "y": surface, "w": w, "h": depth}


def row(x0, x1, y, step=4):
    return [{"x": x, "y": y} for x in range(x0, x1 + 1, step)]


def arc(x0, x1, y, height=2, step=3):
    n = x1 - x0
    return [{"x": x, "y": y - round(math.sin(math.pi * (x - x0) / n) * height)} for x in range(x0, x1 + 1, step)]


def column(x, y0, y1):
    return [{"x": x, "y": y} for y in range(y0, y1 + 1, 2)]


def enemy(t, x, y, a, b):
    return {"type": t, "x": x, "y": y, "patrol": [a, b]}


background = {
    "sky": "w4_sky", "far": "w4_foam_far", "near": "w4_foam_near",
    "atlas": "world4_bg", "objectsAtlas": "world4_objects", "sparkles": True,
    "drifters": ["bubble_float_m", "bubble_float_l"],
    "layers": [
        # capa 2: ciudad acuática, cascadas, arcoíris, bañera y gran pato de goma (word_4.png)
        {"scroll": [0.03, 0.03], "depth": 2, "items": [{"frame": "bg_city", "x": 250, "y": 66, "alpha": 0.96}]},
        # capa 3: cascadas a media distancia
        {"scroll": [0.15, 0.08], "depth": 4, "frames": ["bg_waterfall_a", "bg_waterfall_b"], "step": 240, "y": [150, 172], "alpha": 0.55},
        # burbujas grandes flotando
        {"scroll": [0.3, 0.15], "depth": 6, "frames": ["bg_bubble"], "step": 170, "y": [50, 140], "alpha": 0.75, "bob": True},
    ],
}

pools = {}
terrain = [
    # A — Las bañeras de espuma
    g(0, 30, 20, "tile"), g(18, 4, 19, "sponge"),
    g(40, 30, 20, "sponge"), g(74, 12, 20, "tile"), g(96, 16, 20, "sponge"),
    # B — Los jardines del jabón
    g(112, 26, 20, "sponge"), g(138, 12, 15, "tile"), g(162, 10, 17, "sponge"), g(172, 18, 20, "tile"),
    g(206, 19, 20, "tile"),
    # C — El canal de los patitos
    g(225, 10, 20, "sponge"), g(253, 6, 19, "sponge"), g(275, 16, 20, "sponge"), g(291, 14, 14, "tile"),
    g(305, 14, 17, "sponge"), g(333, 17, 19, "tile"),
    # D — Las cataratas de burbujas
    g(350, 16, 20, "tile"), g(373, 14, 13, "sponge"), g(387, 20, 14, "tile"), g(447, 15, 14, "tile"),
    g(476, 18, 17, "sponge"),
    # E — El trono de Patoburbuja
    g(494, 4, 18, "sponge"), g(498, 67, 19, "tile"),
]
waters = []
for x, w, depth, mat in [(30, 10, 2, "tile"), (86, 10, 3, "tile"), (150, 12, 2, "tile"), (235, 40, 2, "tile")]:
    floor, water = pool(x, w, depth, mat=mat)
    terrain = floor + terrain  # el fondo va antes: las islas que lo cruzan lo sobrescriben
    waters.append(water)
# tramo submarino de las cataratas: 9 teselas de agua junto al suelo alto (fila 14)
floor, water = pool(407, 40, 9, surface=15, mat="sponge")
terrain = floor + terrain
waters.append(water)

# rampas de 45 grados (tileset oficial "rampas / pendientes"): subida a la meseta de azulejo
slopes = [{"x": 17, "y": 19, "dir": "up", "mat": "sponge"}, {"x": 22, "y": 19, "dir": "down", "mat": "sponge"}]

blocks = [
    {"x": 58, "y": 16, "type": "block_glass"}, {"x": 59, "y": 16, "type": "block_glass"},
    {"x": 520, "y": 15, "type": "block_glass"}, {"x": 521, "y": 15, "type": "block_glass"},
]

# Plataformas unidireccionales (x = centro, y = superficie)
clouds = [
    {"x": 50, "y": 17, "frame": "bubble_plat_2", "top": 4}, {"x": 55, "y": 15, "frame": "bubble_plat_3", "top": 4},
    {"x": 62, "y": 13, "frame": "bubble_plat_s", "top": 4},                     # concha 1
    {"x": 194, "y": 19, "frame": "sponge_plat", "top": 3}, {"x": 199, "y": 18, "frame": "sponge_plat_b", "top": 3},
    {"x": 204, "y": 19, "frame": "sponge_plat", "top": 3},
    {"x": 196, "y": 14, "frame": "bubble_plat_s", "top": 4}, {"x": 201, "y": 12, "frame": "bubble_plat_s", "top": 4},
    {"x": 259, "y": 10, "frame": "bubble_plat_3", "top": 4}, {"x": 264, "y": 9, "frame": "bubble_plat_2", "top": 4},
    {"x": 269, "y": 10, "frame": "bubble_plat_3", "top": 4},                    # ruta alta del canal: concha 2
    {"x": 470, "y": 11, "frame": "tile_plat", "top": 3},                        # plataforma suspendida: concha 3
    {"x": 522, "y": 11, "frame": "bubble_plat_3", "top": 4},                    # patito real
]

movers = [
    {"x": 72, "y": 19, "frame": "bubble_plat_2", "top": 4, "dx": 0, "dy": -0.5, "duration": 1600},       # 0: burbuja que flota
    {"x": 152, "y": 15, "frame": "soap_pink", "top": 4, "dx": 7, "dy": 0, "duration": 3200},             # 1: jabón móvil
    {"x": 237.5, "y": 20, "frame": "boat_plat", "top": 23, "dx": 12, "dy": 0, "duration": 5200},         # 2: barquito
    {"x": 260, "y": 20, "frame": "boat_plat", "top": 23, "dx": 12, "dy": 0, "duration": 5200, "delay": 2600},  # 3: barquito
    {"x": 289.5, "y": 19, "frame": "bubble_plat_2", "top": 4, "dx": 0, "dy": -5, "duration": 3000},      # 4: ascensor de burbuja (pegado al muro)
    {"x": 464, "y": 14, "frame": "bubble_plat_3", "top": 4, "dx": 8, "dy": 0, "duration": 3400},         # 5: cruza el hueco
    {"x": 537, "y": 15, "frame": "soap_purple", "top": 4, "dx": 5, "dy": 0, "duration": 3000},           # 6: jabón en la bañera real
]

# burbujas frágiles: revientan poco después de pisarlas y se vuelven a inflar
crumbles = [{"x": x, "y": y, "frame": "bubble_plat_s", "top": 4, "pop": True} for x, y in [(322, 17), (326, 16), (330, 17)]]

# burbujas de salto (BouncePad)
pads = [
    {"x": 520, "y": 19, "frame": "jump_bubble_big", "power": -500},
    {"x": 302, "y": 14, "frame": "jump_bubble_s", "power": -470},
]

# columnas de burbujas: corriente ascendente constante (WindZone)
bubble_columns = [
    {"x": 159, "y": 14, "w": 2, "h": 9, "force": 1500, "maxUp": 190},   # salida de la balsa del jabón
    {"x": 255, "y": 9, "w": 2, "h": 10, "force": 1500, "maxUp": 190},   # isla del canal: ruta alta
    {"x": 367, "y": 8, "w": 4, "h": 17, "force": 1600, "maxUp": 200},   # cascada gigante: sube a la meseta
    {"x": 444, "y": 10, "w": 2, "h": 14, "force": 1500, "maxUp": 200},  # salida del tramo submarino
]

# géiseres: ciclo fijo (burbujea, avisa y estalla)
geysers = [
    {"x": 137, "y": 20, "h": 7, "period": 3000, "power": 330},   # pegado al muro alto
    {"x": 214, "y": 20, "h": 6, "period": 3400, "delay": 900, "power": 330},
    {"x": 430, "y": 24, "h": 6, "period": 3000, "power": 260},   # bajo el agua
]

# espuma resbaladiza (PaintSurface color "foam")
paints = [
    {"x": 116, "y": 20, "w": 8, "color": "foam", "frame": "foam_slip"},
    {"x": 352, "y": 20, "w": 4, "color": "foam", "frame": "foam_slip"},
    {"x": 505, "y": 19, "w": 7, "color": "foam", "frame": "foam_slip"},
]

sponge_rollers = [
    {"x": 360, "y": 20, "range": [357, 364], "speed": 45, "frame": "roller_a"},
    {"x": 391, "y": 14, "range": [389, 396], "speed": 50, "frame": "roller_b"},
    {"x": 401, "y": 14, "range": [399, 405], "speed": 65, "frame": "roller_a"},
    {"x": 488, "y": 17, "range": [485, 492], "speed": 40, "frame": "roller_c"},
]

soaps = [
    {"x": 180, "y": 20, "range": [178, 188], "speed": 60, "frame": "soap_purple"},
    {"x": 540, "y": 19, "range": [532, 546], "speed": 55, "frame": "soap_pink"},
]

dream = [
    {"id": "shell_1", "kind": "shell", "x": 62, "y": 10},
    {"id": "shell_2", "kind": "shell", "x": 264, "y": 6},
    {"id": "shell_3", "kind": "shell", "x": 470, "y": 8},
    {"id": "starfish_1", "kind": "starfish", "x": 214, "y": 9},
    {"id": "rainbow_1", "kind": "rainbow", "x": 426, "y": 22},
    {"id": "duck_1", "kind": "duck", "x": 522, "y": 8},
]

stars = (
    # A
    row(5, 13, 19) + arc(14, 24, 18, 2) + row(26, 29, 19, 3) + row(31, 39, 20, 2) + row(42, 48, 19)
    + row(49, 51, 16, 2) + row(54, 56, 14, 2) + arc(66, 76, 18, 2) + row(78, 84, 19, 3) + row(87, 95, 22, 2)
    + row(98, 110, 19, 4)
    # B
    + row(114, 124, 19, 2) + row(127, 134, 19, 4) + column(137, 13, 17) + row(140, 148, 14, 4) + row(151, 159, 13, 2)
    + row(163, 170, 16, 3) + row(174, 188, 18, 4) + row(193, 205, 17, 2) + row(195, 197, 12, 2) + row(200, 202, 10, 2)
    + row(208, 212, 19, 2) + column(214, 11, 17) + row(216, 224, 19, 4)
    # C
    + row(226, 234, 19, 4) + arc(236, 252, 18, 2, 4) + column(255, 11, 17) + row(258, 270, 8, 3) + arc(261, 274, 18, 2, 4)
    + row(277, 286, 19, 3) + column(288, 13, 17) + row(293, 303, 13, 3) + row(306, 318, 16, 4) + row(321, 331, 14, 2)
    + row(335, 348, 18, 3)
    # D
    + row(354, 364, 19, 5) + column(369, 9, 17) + row(374, 385, 12, 3) + row(389, 405, 13, 4) + row(409, 443, 21, 4)
    + row(412, 440, 18, 7) + row(448, 460, 13, 4) + row(463, 473, 13, 2) + row(477, 492, 16, 3)
    # E
    + arc(494, 499, 17, 2) + row(501, 516, 18, 3) + column(520, 12, 16) + row(524, 556, 18, 4)
)

enemies = (
    [enemy("bubble_fish", x, y, a, b) for x, y, a, b in [
        (35, 22.6, 31, 39), (64, 16, 58, 68), (91, 22.8, 87, 95), (266, 22.6, 262, 273), (395, 10, 389, 404),
        (418, 20, 409, 428), (436, 22, 430, 443), (488, 13, 480, 492), (545, 15, 540, 552)]]
    + [enemy("sponge_crab", x, y, a, b) for x, y, a, b in [
        (128, 20, 125, 134), (184, 20, 178, 189), (220, 20, 215, 224), (298, 14, 292, 303), (344, 19, 335, 348),
        (480, 17, 477, 484), (530, 19, 526, 531)]]
    + [enemy("pompa", x, y, a, b) for x, y, a, b in [
        (246, 16, 240, 252), (283, 16, 277, 289), (312, 13, 307, 317), (341, 15, 335, 347), (452, 10, 448, 460),
        (512, 15, 506, 518)]]
)

checkpoints = [{"x": 173, "y": 20}, {"x": 352, "y": 20}]

signs = [
    {"x": 7, "y": 20, "text": "Mundo 4: ¡El Reino de las Burbujas! Tus tres armas te acompañan"},
    {"x": 44, "y": 20, "text": "Las plataformas de burbujas flotan: ¡súbete a ellas!"},
    {"x": 82, "y": 20, "text": "En el agua pulsa salto para nadar. Cerca de la superficie, ¡salta fuera!"},
    {"x": 113, "y": 20, "text": "La espuma resbala: frena con tiempo"},
    {"x": 132, "y": 20, "text": "El géiser de burbujas te lanza muy alto: espera a que estalle"},
    {"x": 226, "y": 20, "text": "El Canal de los Patitos: sube a los barquitos"},
    {"x": 254, "y": 19, "text": "Las columnas de burbujas te elevan"},
    {"x": 317, "y": 17, "text": "Las burbujas frágiles revientan: ¡no te pares!"},
    {"x": 364, "y": 20, "text": "Salta a la cascada de burbujas: te subirá hasta arriba"},
    {"x": 388, "y": 14, "text": "Los rodillos de esponja empujan: pasa cuando se alejen"},
    {"x": 405, "y": 14, "text": "Bajo el agua flotas: pulsa salto para nadar hacia arriba"},
    {"x": 550, "y": 19, "text": "El Trono de Patoburbuja: ¡el Rey te espera!"},
]

decor = [
    # front: True delante de Alice, "water" delante del agua (fondo submarino) pero detrás de Alice
    {"x": x, "y": y, "frame": f, "front": front is True, "water": front == "water"} for x, y, f, front in [
        (8, 20, "brush_pink", False), (12, 20, "bottle_blue", False), (26, 20, "coral_pink", False),
        (33, 21, "duck_a", False), (46, 20, "bottle_star", False), (66, 20, "coral_green", False), (78, 20, "brush_blue", False),
        (89, 21, "duck_b", False), (100, 20, "seaweed", False), (106, 20, "starfish_gold", True),
        (120, 20, "coral_mix", False), (126, 20, "bottle_pink", False), (142, 15, "brush_orange", False), (146, 15, "bottle_small", False),
        (166, 17, "coral_pink", False), (176, 20, "seaweed", False), (186, 20, "shell_conch", True), (210, 20, "bottle_star", False),
        (218, 20, "coral_green", False), (229, 20, "brush_pink", False), (243, 21, "duck_c", False), (249, 21, "duck_a", False),
        (256, 19, "shell_blue", True), (268, 21, "duck_b", False), (279, 20, "coral_mix", False), (296, 14, "bottle_blue", False),
        (308, 17, "seaweed", False), (337, 19, "brush_blue", False), (346, 19, "starfish_pink", True),
        (356, 20, "coral_pink", False), (378, 13, "coral_green", False), (383, 13, "bottle_pink", False),
        (412, 24, "seaweed", "water"), (420, 24, "coral_mix", "water"), (433, 24, "coral_pink", "water"), (440, 24, "shell_purple", "water"),
        (450, 14, "brush_orange", False), (458, 14, "bottle_small", False), (480, 17, "coral_green", False),
        (500, 19, "coral_pink", False), (508, 19, "duck_a", False), (514, 19, "bottle_star", False), (527, 19, "brush_pink", False),
        (534, 19, "coral_mix", False), (548, 19, "bottle_pink", False), (554, 19, "duck_c", False), (562, 19, "bottle_blue", False),
    ]
]

dream_names = {"shell": "Concha token", "starfish": "Estrella marina mágica", "rainbow": "Burbuja arcoíris", "duck": "Patito real"}

level = {
    "id": 4, "key": "world4", "name": "Reino de las Burbujas", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world4", "tileset": "world4_tiles", "objectsAtlas": "world4_objects", "backgroundAtlas": "world4_bg",
    "progress": {"total": 10000, "offset": 0, "scale": 1}, "playerStart": {"x": 3, "y": 20}, "nextScene": "Boss4",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w4", "signpost": "sign_w4", "star": ["world4_objects", "star_w4"]},
    "sections": [
        {"id": "A", "name": "Las bañeras de espuma", "from": 0},
        {"id": "B", "name": "Los jardines del jabón", "from": 1800},
        {"id": "C", "name": "El canal de los patitos", "from": 3600},
        {"id": "D", "name": "Las cataratas de burbujas", "from": 5600},
        {"id": "E", "name": "El trono de Patoburbuja", "from": 7900},
    ],
    "background": background, "terrain": terrain, "slopes": slopes, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": [], "crumbles": crumbles, "pads": pads,
    "winds": [], "hazards": [], "paints": paints, "rollers": [], "bouncers": [], "drips": [], "rivers": [],
    "magicCrayons": [], "yarnRollers": [], "sleepClouds": [], "magicButtons": [],
    "waters": waters, "geysers": geysers, "bubbleColumns": bubble_columns, "spongeRollers": sponge_rollers, "soaps": soaps,
    "dreamCollectibles": dream, "dreamMain": "shell", "dreamNames": dream_names,
    "dreamBanner": "¡Las %d conchas token! Estrella extra", "dreamHud": ["world4_objects", "shell_token", "shell_"],
    "stars": stars, "enemies": enemies, "checkpoints": checkpoints, "pickups": [],
    "signs": signs, "decor": decor,
    "door": {"x": 558, "y": 19, "atlas": "world4_objects", "frame": "portal_w4", "scale": 1.0},
}

arena_bg = dict(background)
arena_bg["layers"] = [
    # el gran pato de goma de la ilustración queda en el centro, detrás del combate
    {"scroll": [0.03, 0.03], "depth": 2, "items": [{"frame": "bg_city", "x": 240, "y": 66, "alpha": 0.96}]},
    background["layers"][1], background["layers"][2],
]

boss = {
    "key": "world4_boss", "worldId": 4, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world4", "bossMusic": "patoburbuja",
    "tileset": "world4_tiles", "objectsAtlas": "world4_objects", "backgroundAtlas": "world4_bg", "background": arena_bg,
    "frames": level["frames"], "progress": {"total": 10000, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "El trono de Patoburbuja", "from": 7900}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3, "mat": "tile"}], "blocks": [],
    "clouds": [{"x": 15, "y": 10, "frame": "bubble_plat_3", "top": 4}, {"x": 45, "y": 10, "frame": "bubble_plat_3", "top": 4}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 8} for x in [14, 15, 16, 44, 45, 46]],
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [
        {"x": 3, "y": 14, "frame": "brush_blue"}, {"x": 9, "y": 14, "frame": "bottle_blue"}, {"x": 22, "y": 14, "frame": "duck_a"},
        {"x": 30, "y": 14, "frame": "coral_mix"}, {"x": 38, "y": 14, "frame": "duck_c"}, {"x": 51, "y": 14, "frame": "coral_pink"},
        {"x": 56, "y": 14, "frame": "bottle_star"},
    ],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_tile"}, "triggerX": 9,
    "boss": {"homeX": 34, "minX": 8, "maxX": 58, "floorY": 224, "frameBoth": True, "scene": "res://scenes/bosses/ReyPatoburbuja.tscn",
             "name": "Rey Patoburbuja", "introBanner": "¡El Rey Patoburbuja defiende su bañera real!",
             "defeatBanner": "¡El Rey Patoburbuja se duerme entre la espuma!", "portalToast": "El portal al Mundo 5 está preparado",
             "afterMusic": "world4"},
    "portal": {"x": 57, "y": 14},
}

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world4.json", level), ("world4_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 4: {len(stars)} estrellas, {len(enemies)} enemigos, ancho total {(LEVEL_W + ARENA_W) * 16} px")
