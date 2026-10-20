"""
Datos del MUNDO 7 — El Valle de Caramelo (diseño del nivel).

Uso:  python tools/world7/world7_level.py
Escribe godot/data/world7/world7.json (nivel) y godot/data/world7/world7_boss.json (arena).

Mismo formato que los Mundos 2-6: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 656 x 25 teselas (10.496 px) + arena (63)
= 11.504 px. El terreno usa el material "frosting" (tierra de chocolate con glaseado rosa) y
"caramel" (con caramelo dorado) en la Fábrica.

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Ningún escalón obligatorio supera 3 teselas sin ayuda (gelatinas, gomas elásticas);
ningún hueco obligatorio supera 5 teselas sin plataforma.

  A Jardines de Algodón de Azúcar      0-2.000   árboles rosados, plataformas de chocolate,
                                                  galletas, malvaviscos, piruletas; saltos
                                                  sencillos, primeras gelatinas y Gomilitos
  B Los Puentes de Caramelo        2.000-4.200   puentes de pastel, bastones dulces, cascadas
                                                  de chocolate; Cuppy Dulzón, plataformas
                                                  móviles, caramelo resbaladizo, 1.er checkpoint
  C El Río de Chocolate            4.200-6.500   ríos y cascadas de chocolate, malvaviscos,
                                                  gelatinas flotantes; chocolate pegajoso,
                                                  rebotes, Piruletas Voladoras, ruta alta
  D La Fábrica de Caramelos        6.500-9.000   correas, bloques de galleta, lanzadores,
                                                  tobogán de caramelo, gelatinas que desaparecen,
                                                  piruletas giratorias, los tres enemigos, 2.º
                                                  checkpoint
  E El Castillo del Gran Pastel    9.000-11.500  castillo pastelero, glaseado, fresas, galletas
                                                  y la arena de Don Chupetón
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world7"
ROWS = 25
LEVEL_W = 656
ARENA_W = 63
TOTAL = (LEVEL_W + ARENA_W) * 16
MAT = "frosting"
CAR = "caramel"


def g(x, w, top=20, mat=MAT):
    """Isla que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top, "mat": mat}


def island(x, w, top, h, mat=MAT):
    """Isla flotante (se ve su base de chocolate colgante)."""
    return {"x": x, "y": top, "w": w, "h": h, "mat": mat}


def row(x0, x1, y, step=3):
    return [{"x": x, "y": y} for x in range(x0, x1 + 1, step)]


def arc(x0, x1, y, height=2, step=2):
    n = x1 - x0
    return [{"x": x, "y": y - round(math.sin(math.pi * (x - x0) / n) * height)} for x in range(x0, x1 + 1, step)]


def column(x, y0, y1):
    return [{"x": x, "y": y} for y in range(y0, y1 + 1, 2)]


def enemy(t, x, y, a, b, **extra):
    e = {"type": t, "x": x, "y": y, "patrol": [a, b]}
    e.update(extra)
    return e


background = {
    "sky": "w7_sky", "far": "w7_clouds_far", "near": "w7_clouds_near",
    "atlas": "world7_bg", "objectsAtlas": "world7_objects", "sparkles": True,
    "drifters": ["cream_s", "cream_xs"],
    "layers": [
        # capa 4 de la referencia: el castillo de dulces sobre su colina (word_7.png)
        {"scroll": [0.02, 0.02], "depth": 2, "items": [{"frame": "bg_castle", "x": 310, "y": 112}]},
        # capas 2-3: colinas de gomitas, dulces gigantes y árboles de algodón lejanos
        {"scroll": [0.06, 0.04], "depth": 3, "frames": ["bg_sweets", "bg_trees", "bg_mushroom", "bg_hills"], "step": 270, "y": [128, 160], "alpha": 0.85, "bob": True},
        # capa 5: cascadas de chocolate
        {"scroll": [0.15, 0.08], "depth": 4, "frames": ["bg_falls", "bg_hills", "bg_trees"], "step": 300, "y": [176, 200], "alpha": 0.9},
        # capas cercanas: setas de dulce, árboles de algodón y gomitas
        {"scroll": [0.24, 0.12], "depth": 5, "frames": ["bg_mushroom", "bg_trees"], "step": 380, "y": [198, 216], "alpha": 0.85},
        {"scroll": [0.32, 0.16], "depth": 6, "frames": ["bg_hills"], "step": 440, "y": [216, 236], "alpha": 0.7},
    ],
}

terrain = [
    # A — Jardines de Algodón de Azúcar
    g(0, 34, 20), g(38, 16, 20), g(54, 6, 19), g(65, 26, 20), island(80, 9, 15, 3), g(96, 30, 20),
    # B — Los Puentes de Caramelo
    g(126, 14, 20), g(147, 18, 19), g(175, 2, 19), g(177, 20, 18), g(202, 24, 18), island(232, 8, 15, 3), g(240, 22, 19),
    # C — El Río de Chocolate
    g(262, 30, 20), g(300, 26, 21), island(342, 7, 14, 2), g(334, 24, 20), g(366, 40, 19),
    # D — La Fábrica de Caramelos
    g(406, 16, 19), g(433, 20, 19), g(460, 22, 17), g(491, 18, 18),
    g(509, 4, 17, CAR), g(513, 1, 18, CAR), g(514, 1, 19, CAR), g(515, 1, 20, CAR), g(516, 1, 21, CAR), g(517, 15, 22, CAR),
    island(527, 4, 19, 1, CAR), g(532, 30, 19),
    # E — El Castillo del Gran Pastel
    g(562, 18, 19), island(586, 10, 17, 3), g(602, 54, 19),
]

slopes = [
    # A: escalón con rampa
    {"x": 53, "y": 19, "dir": "up", "mat": MAT},
    # B: llegada del bastón móvil a su misma altura y rampa hacia la cornisa
    {"x": 176, "y": 18, "dir": "up", "mat": MAT},
    # D: tobogán de caramelo dorado (rampas de 45 grados hacia abajo)
    {"x": 513, "y": 17, "dir": "down", "mat": CAR}, {"x": 514, "y": 18, "dir": "down", "mat": CAR},
    {"x": 515, "y": 19, "dir": "down", "mat": CAR}, {"x": 516, "y": 20, "dir": "down", "mat": CAR},
    {"x": 517, "y": 21, "dir": "down", "mat": CAR},
]

# bloques de galleta sueltos (sólidos)
blocks = [
    {"x": 418, "y": 18, "type": "block_cookie"}, {"x": 419, "y": 18, "type": "block_cookie"}, {"x": 419, "y": 17, "type": "block_cookie"},
    {"x": 444, "y": 18, "type": "block_cookie"}, {"x": 480, "y": 16, "type": "block_cookie"}, {"x": 481, "y": 16, "type": "block_cookie"},
    {"x": 655, "y": 18, "type": "block_cookie"}, {"x": 655, "y": 17, "type": "block_cookie"},
]

# Plataformas unidireccionales (x = centro, y = superficie). Las de gelatina rebotan.
JELLY = -470
clouds = [
    # A: primeras gelatinas elásticas y plataformas de galleta/malvavisco
    {"x": 36, "y": 19, "frame": "jelly_red", "top": 3, "bouncy": JELLY},
    {"x": 62.5, "y": 19, "frame": "cookie_bar", "top": 2},
    {"x": 72, "y": 16, "frame": "cookie_plat_l", "top": 2},
    {"x": 93.5, "y": 19, "frame": "cream_m", "top": 4},
    {"x": 104, "y": 16, "frame": "cream_l", "top": 4}, {"x": 110, "y": 14, "frame": "cream_s", "top": 4},
    # B: puente de pastel, bastones y galletas
    {"x": 143.5, "y": 20, "frame": "cake_bridge", "top": 6},
    {"x": 199.5, "y": 17, "frame": "candy_pink", "top": 2},
    {"x": 236, "y": 12, "frame": "cookie_bar", "top": 2},
    # C: malvaviscos y gelatinas flotantes sobre el río (ruta alta opcional con el caramelo 2)
    {"x": 295, "y": 19, "frame": "cream_l", "top": 4},
    {"x": 298, "y": 20, "frame": "cream_s", "top": 4},
    {"x": 315, "y": 16, "frame": "jelly_orange", "top": 3, "bouncy": JELLY},
    {"x": 327, "y": 15, "frame": "cream_m", "top": 4}, {"x": 331.5, "y": 13, "frame": "cream_s", "top": 4},
    {"x": 336, "y": 14, "frame": "cream_l", "top": 4},
    # camino bajo sobre el río: anchas y pegadas a la orilla (recogen a quien caiga de la ruta alta)
    {"x": 328.6, "y": 20, "frame": "cream_l", "top": 4}, {"x": 332.6, "y": 20, "frame": "cream_m", "top": 4},
    {"x": 312, "y": 13, "frame": "jelly_green", "top": 3, "bouncy": -440},
    {"x": 361, "y": 19, "frame": "cream_s", "top": 4}, {"x": 364, "y": 18, "frame": "cream_xs", "top": 3},
    {"x": 380, "y": 15, "frame": "cream_l", "top": 4},
    # D: estante de galletas (ruta alta, caramelo 3)
    {"x": 465, "y": 13, "frame": "cookie_plat_l", "top": 2}, {"x": 471, "y": 10, "frame": "cookie_bar", "top": 2},
    {"x": 529, "y": 19, "frame": "cookie_plat_s", "top": 2},
    # E: gelatina, puente de pastel y plataformas de chocolate del castillo
    {"x": 583, "y": 19, "frame": "jelly_red", "top": 3, "bouncy": JELLY},
    {"x": 599, "y": 18, "frame": "cake_bridge", "top": 6},
    {"x": 616, "y": 15, "frame": "choco_drip_plat", "top": 3}, {"x": 636, "y": 15, "frame": "cupcake_plat", "top": 5},
]

movers = [
    {"x": 168, "y": 19, "frame": "candy_bar", "top": 3, "dx": 4, "dy": 0, "duration": 2600},          # B: bastón móvil horizontal (su borde llega a la cornisa sin meterse debajo)
    {"x": 229, "y": 18, "frame": "candy_purple", "top": 2, "dx": 0, "dy": -3, "duration": 2400},     # B: sube a la cereza dorada
    {"x": 577, "y": 18, "frame": "candy_red", "top": 2, "dx": 0, "dy": -3, "duration": 2600},        # E: hacia la ruta alta
]

# gelatinas que desaparecen poco después de pisarlas (avisan temblando y vuelven al rato)
crumbles = [
    {"x": 455, "y": 18, "frame": "fall_jelly_red", "top": 3},
    {"x": 458, "y": 17, "frame": "fall_jelly_orange", "top": 3},
    {"x": 486, "y": 17, "frame": "fall_jelly_green", "top": 3},
    {"x": 530.5, "y": 17, "frame": "fall_jelly_purple", "top": 4},
    {"x": 593, "y": 15, "frame": "fall_jelly_red", "top": 3},
]

# gomas elásticas: trampolines en el suelo
pads = [
    {"x": 77, "y": 20, "frame": "gum_red", "power": -560},     # A: a la cornisa del caramelo 1
    {"x": 322, "y": 21, "frame": "gum_purple", "power": -560},  # C: a la ruta alta de malvaviscos
    {"x": 462, "y": 17, "frame": "gum_red", "power": -540},     # D: al estante de galletas
    {"x": 520, "y": 22, "frame": "gum_purple", "power": -520},  # D: salida del tobogán
]

# superficies: caramelo resbaladizo y chocolate pegajoso
paints = [
    {"x": 180, "y": 18, "w": 9, "color": "caramel"}, {"x": 209, "y": 18, "w": 10, "color": "caramel"},
    {"x": 268, "y": 20, "w": 10, "color": "choco"}, {"x": 305, "y": 21, "w": 14, "color": "choco"},
    {"x": 340, "y": 20, "w": 12, "color": "choco"}, {"x": 372, "y": 19, "w": 9, "color": "choco"},
    {"x": 509, "y": 17, "w": 4, "color": "caramel"}, {"x": 518, "y": 22, "w": 8, "color": "caramel"},
    {"x": 604, "y": 19, "w": 6, "color": "choco"},
]

# ríos de chocolate (decorado al fondo de los huecos: caer sigue siendo caer al vacío)
rivers = [{"x": 292, "w": 8, "color": "choco"}, {"x": 326, "w": 8, "color": "choco"}, {"x": 358, "w": 8, "color": "choco"}]

# correas de chocolate (x = borde izquierdo; cada correa mide 68 px)
belts = [
    {"x": 422.5, "y": 18, "dir": 1, "speed": 45}, {"x": 427.5, "y": 18, "dir": 1, "speed": 45},
    {"x": 482.5, "y": 17, "dir": -1, "speed": 32},
    {"x": 541, "y": 16, "dir": 1, "speed": 40},
]

# piruletas giratorias (base del palo en la superficie)
lollipops = [
    {"x": 447, "y": 19, "speed": 80, "angle": 0},
    {"x": 500, "y": 18, "speed": 70, "swing": 60, "angle": 0, "frame": "lolli_spin"},
    {"x": 548, "y": 19, "speed": -75, "angle": 180},
    {"x": 628, "y": 19, "speed": 70, "swing": 55, "angle": 0},
]

# lanzadores de caramelos (avisan antes de cada disparo)
launchers = [
    {"x": 441, "y": 19, "dir": -1, "period": 2800, "speed": 90},
    {"x": 506, "y": 18, "dir": -1, "period": 3000, "speed": 90, "delay": 900, "frame": "launcher_b"},
    {"x": 559, "y": 19, "dir": -1, "period": 2600, "speed": 95},
    {"x": 646, "y": 19, "dir": -1, "period": 3200, "speed": 85, "delay": 600},
]

# chorros de chocolate (suben del suelo tras un aviso)
choco_jets = [
    {"x": 285, "y": 20, "period": 3400, "up": 1300},
    {"x": 496, "y": 18, "period": 3200, "up": 1200, "delay": 600, "frame": "choco_jet_b"},
    {"x": 555, "y": 19, "period": 3000, "up": 1100, "delay": 1500},
]

hazards = [
    # plataformas con pinchos de caramelo (se saltan)
    {"x": 449, "y": 19, "frame": "spike_cake", "shape": "spikes"},
    {"x": 611, "y": 19, "frame": "spike_cake", "shape": "spikes"},
]

# bloques de premio (golpe desde abajo o disparo: sueltan estrellas)
star_blocks = [
    # A: sobre la plataforma de galleta (se golpean saltando desde ella)
    {"x": 69, "y": 13, "count": 2}, {"x": 70, "y": 13, "count": 1}, {"x": 71, "y": 13, "count": 2},
    {"x": 213, "y": 14, "count": 2},
    {"x": 538, "y": 15, "count": 3},
    {"x": 621, "y": 15, "count": 2}, {"x": 622, "y": 15, "count": 2},
]

hearts = [{"x": 130, "y": 18}, {"x": 288, "y": 16}, {"x": 425, "y": 14}, {"x": 566, "y": 17}]

dream = [
    {"id": "candy_1", "kind": "candy", "x": 85, "y": 12, "frame": "candy_lolli"},
    {"id": "candy_2", "kind": "candy", "x": 337, "y": 11, "frame": "candy_heart"},
    {"id": "candy_3", "kind": "candy", "x": 471, "y": 7, "frame": "candy_bean"},
    {"id": "cherry_1", "kind": "cherry", "x": 235, "y": 9, "frame": "golden_cherry"},
    {"id": "cake_1", "kind": "cake", "x": 591, "y": 14, "frame": "cake_slice"},
]

stars = (
    # A
    row(3, 31, 19, 3) + arc(34, 38, 16, 2, 1) + row(40, 52, 19, 3) + row(55, 59, 18, 2) + arc(60, 65, 17, 2, 1)
    + row(67, 75, 19, 3) + row(81, 88, 14, 2) + row(90, 95, 17, 2) + row(98, 124, 19, 3) + arc(102, 112, 12, 2, 2)
    # B
    + row(127, 139, 19, 3) + arc(140, 147, 17, 2, 1) + row(149, 163, 18, 3) + arc(165, 175, 16, 2, 2) + row(177, 195, 17, 3)
    + arc(197, 202, 14, 2, 1) + row(204, 224, 17, 3) + column(229, 12, 16) + row(233, 239, 14, 2) + row(242, 260, 18, 3)
    # C
    + row(264, 290, 19, 3) + arc(292, 300, 16, 2, 2) + row(302, 324, 20, 3) + row(326, 337, 11, 2) + row(343, 348, 12, 1)
    + arc(326, 334, 18, 2, 2) + row(336, 356, 19, 3) + arc(358, 366, 16, 2, 2) + row(368, 404, 18, 3) + row(378, 382, 13, 2)
    # D
    + row(408, 420, 18, 3) + row(423, 432, 15, 2) + row(435, 452, 18, 3) + arc(453, 460, 15, 2, 1) + row(462, 480, 16, 3)
    + row(463, 467, 11, 2) + row(469, 473, 8, 2) + arc(482, 491, 14, 2, 2) + row(493, 508, 17, 3) + row(509, 516, 15, 1)
    + row(518, 530, 21, 3) + row(533, 560, 18, 3) + row(541, 545, 14, 2)
    # E
    + row(563, 579, 18, 3) + arc(580, 586, 16, 2, 1) + row(587, 595, 16, 2) + arc(596, 602, 15, 2, 1) + row(604, 650, 18, 3)
    + row(614, 618, 13, 2) + row(634, 638, 13, 2)
)

enemies = (
    [enemy("gomilito", x, y, a, b) for x, y, a, b in [
        (46, 20, 40, 52), (112, 20, 100, 122), (395, 19, 388, 403), (474, 17, 466, 480), (536, 19, 533, 544), (632, 19, 626, 640)]]
    + [enemy("cuppy", x, y, a, b) for x, y, a, b in [
        (156, 19, 149, 163), (190, 18, 185, 195), (220, 18, 214, 224), (252, 19, 244, 259), (466, 17, 462, 472),
        (542, 19, 536, 546), (608, 19, 604, 618), (624, 19, 620, 630)]]
    + [enemy("piruleta", x, y, a, b, fly=[3, 2]) for x, y, a, b in [
        (280, 15, 272, 290), (315, 16, 306, 324), (353, 16, 344, 358), (386, 14, 376, 398), (550, 14, 544, 558), (642, 14, 636, 650)]]
)

checkpoints = [{"x": 205, "y": 18}, {"x": 468, "y": 17}]

signs = [
    {"x": 3, "y": 20, "text": "Mundo 7: ¡El Valle de Caramelo! Un reino de chocolate, glaseado y gominolas"},
    {"x": 30, "y": 20, "text": "Las gelatinas son elásticas: ¡salta encima y rebotarás muy alto!"},
    {"x": 41, "y": 20, "text": "El Gomilito Saltarín se mueve a saltitos. Si le das, ¡se divide en gomitas!"},
    {"x": 74, "y": 20, "text": "Pisa la goma elástica para subir a la cornisa. Hay tres caramelos especiales"},
    {"x": 66, "y": 20, "text": "Golpea los bloques de premio desde abajo: ¡sueltan estrellas!"},
    {"x": 128, "y": 20, "text": "¡Un corazón dulce! Recupera un corazón de vida"},
    {"x": 150, "y": 19, "text": "Cuppy Dulzón levanta su piruleta antes de disparar: ¡salta el caramelo!"},
    {"x": 177, "y": 18, "text": "El caramelo dorado resbala: frena con tiempo"},
    {"x": 224, "y": 18, "text": "El bastón que sube lleva a una cereza dorada"},
    {"x": 264, "y": 20, "text": "El Río de Chocolate: el chocolate es pegajoso y te frena"},
    {"x": 282, "y": 20, "text": "Los chorros de chocolate burbujean antes de salir"},
    {"x": 302, "y": 21, "text": "La Piruleta Voladora lanza caramelitos en abanico: busca el hueco"},
    {"x": 320, "y": 21, "text": "La goma te sube a los malvaviscos: ¡ruta de estrellas!"},
    {"x": 408, "y": 19, "text": "La Fábrica de Caramelos: las correas de chocolate te llevan"},
    {"x": 438, "y": 19, "text": "El lanzador brilla antes de disparar. Las piruletas giran siempre igual"},
    {"x": 452, "y": 19, "text": "Estas gelatinas tiemblan y desaparecen: ¡no te pares!"},
    {"x": 479, "y": 17, "text": "Esta correa va hacia atrás: ¡corre!"},
    {"x": 510, "y": 17, "text": "¡El tobogán de caramelo dorado!"},
    {"x": 564, "y": 19, "text": "El Castillo del Gran Pastel"},
    {"x": 645, "y": 19, "text": "Don Chupetón te espera dentro del castillo"},
]

decor = []


def deco(x, y, frame, **kw):
    d = {"x": x, "y": y, "frame": frame}
    d.update(kw)
    decor.append(d)


for x, y, f, kw in [
    # A — árboles de algodón de azúcar, piruletas, setas y vallas
    (1, 20, "tree_big", {"back": True}), (8, 20, "fence_cane", {"back": True}), (13, 20, "mushroom_candy", {"back": True}),
    (19, 20, "tree_m", {}), (24, 20, "lolli_giant_a", {"back": True}), (27, 20, "bush_candy", {}), (33, 20, "cane_post", {}),
    (43, 20, "tree_big", {"back": True}), (49, 20, "swirl_cone", {}), (51, 20, "tree_s", {}), (57, 19, "cupcake", {"back": True}),
    (68, 20, "giant_sweets", {"back": True}), (79, 20, "cane_hook", {}), (84, 15, "tree_m", {"back": True}), (87, 15, "cone_tree", {}),
    (99, 20, "mushroom_candy", {"back": True}), (106, 20, "tree_big", {"back": True}), (115, 20, "fence_cane", {"back": True}),
    (119, 20, "cake_strawberry", {}), (123, 20, "tree_s", {}),
    # B — puentes, bastones, cascadas de chocolate
    (127, 20, "cane_post", {}), (133, 20, "choco_falls", {"back": True}), (139, 20, "cane_post", {}), (147, 19, "cane_post", {}),
    (152, 19, "tree_m", {"back": True}), (160, 19, "gum_mound", {"back": True}), (164, 19, "cane_hook", {}),
    (176, 18, "cane_post", {}), (186, 18, "choco_falls", {"back": True}), (194, 18, "bush_candy", {}),
    (203, 18, "fence_cane", {"back": True}), (216, 18, "tree_big", {"back": True}), (224, 18, "cane_slant", {}),
    (234, 15, "cone_tree", {}), (243, 19, "giant_sweets", {"back": True}), (249, 19, "choco_dome", {}), (257, 19, "tree_m", {}),
    # C — cascadas y ríos de chocolate, malvaviscos, fuentes de caramelo
    (263, 20, "choco_falls", {"back": True}), (271, 20, "caramel_jet_a", {"back": True}), (279, 20, "choco_dome", {}),
    (290, 20, "cane_post", {}), (301, 21, "caramel_jet_b", {"back": True}), (311, 21, "choco_falls", {"back": True}),
    (319, 21, "gum_cake", {}), (335, 20, "choco_falls", {"back": True}), (344, 14, "cupcake", {}), (352, 20, "caramel_slab", {"back": True}),
    (369, 19, "choco_falls", {"back": True}), (377, 19, "mushroom_candy", {"back": True}), (390, 19, "caramel_jet_a", {"back": True}),
    (398, 19, "tree_big", {"back": True}), (404, 19, "cane_post", {}),
    # D — fábrica: bloques de galleta, fuentes de caramelo, bastones
    (409, 19, "cookie_blocks", {"back": True}), (414, 19, "caramel_jet_b", {"back": True}), (436, 19, "cookie_blocks", {"back": True}),
    (452, 19, "cane_post", {}), (461, 17, "cane_hook", {}), (477, 17, "cookie_blocks", {"back": True}), (493, 18, "caramel_slab", {"back": True}),
    (503, 18, "cookie_blocks", {"back": True}), (511, 17, "cane_post", {}), (523, 22, "caramel_jet_a", {"back": True}),
    (534, 19, "cookie_blocks", {"back": True}), (546, 19, "gum_mound", {"back": True}), (553, 19, "cane_slant", {}),
    # E — el castillo del gran pastel: pasteles, fresas, cupcakes y piruletas
    (563, 19, "cake_strawberry", {}), (568, 19, "giant_sweets", {"back": True}), (575, 19, "cupcake", {}),
    (588, 17, "tree_s", {}), (594, 17, "cake_strawberry", {"back": True}), (603, 19, "cane_post", {}),
    (607, 19, "gum_cake", {"back": True}), (619, 19, "choco_dome", {"back": True}), (626, 19, "giant_sweets", {"back": True}),
    (633, 19, "cake_strawberry", {}), (640, 19, "lolli_giant_a", {"back": True}), (648, 19, "cupcake", {"back": True}),
    (653, 19, "cane_hook", {}),
]:
    deco(x, y, f, **kw)
# primer plano: sólo piezas pequeñas y bajas para no tapar a Alice ni los obstáculos
for x, y, f in [(5, 20, "gumdrops"), (88, 20, "gumdrops"), (200, 18, "gumdrops"), (318, 21, "gumdrops"), (412, 19, "gumdrops"),
                (565, 19, "gumdrops"), (642, 19, "gumdrops")]:
    deco(x, y, f, front=True)

dream_names = {"candy": "Caramelo especial", "cherry": "Cereza dorada", "cake": "Trozo de pastel"}

level = {
    "id": 7, "key": "world7", "name": "El Valle de Caramelo", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world7", "tileset": "world7_tiles", "objectsAtlas": "world7_objects", "backgroundAtlas": "world7_bg",
    "progress": {"total": TOTAL, "offset": 0, "scale": 1}, "playerStart": {"x": 4, "y": 20}, "nextScene": "Boss7",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w7", "signpost": "sign_w7", "star": ["world7_objects", "star_w7"]},
    "sections": [
        {"id": "A", "name": "Jardines de Algodón de Azúcar", "from": 0},
        {"id": "B", "name": "Los Puentes de Caramelo", "from": 2000},
        {"id": "C", "name": "El Río de Chocolate", "from": 4200},
        {"id": "D", "name": "La Fábrica de Caramelos", "from": 6500},
        {"id": "E", "name": "El Castillo del Gran Pastel", "from": 9000},
    ],
    "background": background, "terrain": terrain, "slopes": slopes, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": [], "crumbles": crumbles, "pads": pads,
    "winds": [], "hazards": hazards, "paints": paints, "rollers": [], "bouncers": [], "drips": [], "rivers": rivers,
    "magicCrayons": [], "yarnRollers": [], "sleepClouds": [], "magicButtons": [],
    "belts": belts, "lollipops": lollipops, "launchers": launchers, "chocoJets": choco_jets, "hearts": hearts,
    "starBlocks": star_blocks,
    "dreamCollectibles": dream, "dreamMain": "candy", "dreamNames": dream_names,
    "dreamBanner": "¡Los %d caramelos especiales! Estrella extra", "dreamHud": ["world7_objects", "candy_heart", "candy_"],
    "stars": [], "enemies": enemies, "checkpoints": checkpoints, "pickups": [],
    "signs": signs, "decor": decor,
    "door": {"x": 650, "y": 19, "atlas": "world7_objects", "frame": "portal_w7", "scale": 1.0},
}


# --------------------------------------------------------------- comprobaciones
def solid_grid():
    grid = [[False] * LEVEL_W for _ in range(ROWS)]
    for r in terrain:
        for y in range(r["y"], min(ROWS, r["y"] + r["h"])):
            for x in range(max(0, r["x"]), min(LEVEL_W, r["x"] + r["w"])):
                grid[y][x] = True
    for b in blocks + star_blocks:
        grid[b["y"]][b["x"]] = True
    for s in slopes:
        grid[s["y"]][s["x"]] = True
    return grid


GRID = solid_grid()
# las estrellas que caerían dentro del terreno se descartan (se generan por filas y arcos)
level["stars"] = [s for s in stars if 0 <= s["x"] < LEVEL_W and 0 <= s["y"] < ROWS and not GRID[s["y"]][s["x"]]]
for e in enemies:
    if e["type"] == "piruleta":
        assert not GRID[e["y"]][e["x"]], f"piruleta dentro del terreno: {e}"
        continue
    assert GRID[e["y"]][e["x"]] and not GRID[e["y"] - 1][e["x"]], f"enemigo sin suelo libre: {e}"
for c in checkpoints + hazards + launchers + choco_jets + lollipops:
    assert GRID[c["y"]][c["x"]] and not GRID[c["y"] - 1][c["x"]], f"objeto sin suelo: {c}"
for p in pads:
    assert GRID[p["y"]][p["x"]] and not GRID[p["y"] - 1][p["x"]], f"goma sin suelo: {p}"
for d in dream + hearts:
    assert not GRID[d["y"]][d["x"]], f"coleccionable dentro del terreno: {d}"
for s in signs:
    assert GRID[s["y"]][s["x"]] and not GRID[s["y"] - 1][s["x"]], f"cartel sin suelo: {s}"
# huecos obligatorios: ninguna columna sin suelo durante más de 5 teselas sin plataforma
spans = [(c["x"] - 3, c["x"] + 3) for c in clouds] + [(m["x"] - 3, m["x"] + 3 + m.get("dx", 0)) for m in movers] \
    + [(c["x"] - 1.5, c["x"] + 1.5) for c in crumbles] + [(b["x"], b["x"] + 4.25) for b in belts]
run = 0
for x in range(LEVEL_W):
    has_ground = any(GRID[y][x] for y in range(ROWS))
    covered = any(a <= x <= b for a, b in spans)
    run = 0 if has_ground or covered else run + 1
    assert run <= 5, f"hueco de más de 5 teselas sin plataforma en x={x}"

arena_bg = dict(background)
arena_bg["layers"] = [
    background["layers"][0],
    {"scroll": [0.03, 0.03], "depth": 3, "items": [{"frame": "bg_sweets", "x": 110, "y": 130}, {"frame": "bg_mushroom", "x": 390, "y": 140}]},
    background["layers"][2],
]

boss = {
    "key": "world7_boss", "worldId": 7, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world7", "bossMusic": "don_chupeton",
    "tileset": "world7_tiles", "objectsAtlas": "world7_objects", "backgroundAtlas": "world7_bg", "background": arena_bg,
    "frames": level["frames"], "progress": {"total": TOTAL, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "El Castillo del Gran Pastel", "from": 9000}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3, "mat": MAT}], "blocks": [],
    # nubes de crema a 3 teselas del suelo: más altas que el cuerpo de Don Chupetón (se esquiva el giro)
    "clouds": [{"x": 15, "y": 11, "frame": "cream_l", "top": 4}, {"x": 32, "y": 11, "frame": "cream_m", "top": 4},
               {"x": 49, "y": 11, "frame": "cream_l", "top": 4}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 8} for x in [14, 15, 16, 31, 32, 33, 48, 49, 50]],
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [
        {"x": 3, "y": 14, "frame": "cane_post"}, {"x": 8, "y": 14, "frame": "giant_sweets", "back": True},
        {"x": 20, "y": 14, "frame": "cake_strawberry", "back": True}, {"x": 27, "y": 14, "frame": "choco_falls", "back": True},
        {"x": 38, "y": 14, "frame": "cupcake", "back": True}, {"x": 44, "y": 14, "frame": "giant_sweets", "back": True},
        {"x": 55, "y": 14, "frame": "mushroom_candy", "back": True}, {"x": 61, "y": 14, "frame": "cane_hook"},
    ],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_cookie"}, "triggerX": 9,
    "boss": {"homeX": 44, "minX": 6, "maxX": 62, "floorY": 224, "frameBoth": True, "scene": "res://scenes/bosses/DonChupeton.tscn",
             "name": "Don Chupetón", "introBanner": "¡Don Chupetón sale del Gran Pastel!",
             "defeatBanner": "¡Don Chupetón se ha quedado dormido!", "portalToast": "Se ha abierto el portal al Mundo 8",
             "afterMusic": "world7_victory"},
    "portal": {"x": 58, "y": 14},
}

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world7.json", level), ("world7_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 7: {len(level['stars'])} estrellas, {len(enemies)} enemigos, ancho total {TOTAL} px")
