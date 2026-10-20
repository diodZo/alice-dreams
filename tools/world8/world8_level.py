"""
Datos del MUNDO 8 — El Castillo de las Pesadillas (diseño del nivel). El final de Alice Dreams.

Uso:  python tools/world8/world8_level.py
Escribe godot/data/world8/world8.json (nivel) y godot/data/world8/world8_boss.json (salón del trono).

Mismo formato que los Mundos 2-7: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 625 x 25 teselas (10.000 px) + salón del trono
(125 teselas, 2.000 px) = 12.000 px. Terreno "lavender" (roca violeta con cobertura lavanda) y
"castle" (piedra del castillo) en el Corazón del Castillo.

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Ningún escalón obligatorio supera 3 teselas sin ayuda; ningún hueco obligatorio
supera 5 teselas sin plataforma (el generador lo comprueba).

  A El Bosque de los Susurros           0-1.800   árboles retorcidos, calabazas, faroles;
                                                    plataformas fantasma, Fantasmita y Bloquito
  B Los Puentes de la Luna          1.800-3.800   plataformas colgantes, estrellas que caen,
                                                    plataformas que desaparecen, primer Murcibola,
                                                    1.er checkpoint
  C El Jardín de las Sombras        3.800-5.900   setas fantasma elásticas, charcos y bruma de
                                                    sombras, enemigos combinados, rutas especiales
  D Las Torres Encantadas           5.900-8.000   torres, plataformas móviles, ganchos oscilantes,
                                                    bloques que desaparecen, 2.º checkpoint
  E El Corazón del Castillo         8.000-10.000  pasillos, faroles mágicos y puentes ocultos,
                                                    tres recuerdos, cofre, 3.er checkpoint y la
                                                    puerta gigante al salón del trono
  F El Trono de las Pesadillas     10.000-12.000  salón del trono y arena del Rey Pesadelo
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world8"
ROWS = 25
LEVEL_W = 625
ARENA_W = 125
TOTAL = (LEVEL_W + ARENA_W) * 16
LAV = "lavender"
CAS = "castle"


def g(x, w, top=20, mat=LAV):
    """Isla que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top, "mat": mat}


def island(x, w, top, h, mat=LAV):
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
    "sky": "w8_sky", "far": "w8_clouds_far", "near": "w8_clouds_near",
    "atlas": "world8_bg", "objectsAtlas": "world8_objects", "sparkles": True,
    "drifters": ["ghost_bg", "cloud_plat_s"],
    "layers": [
        # capa lejana: cielo nocturno, luna creciente y el castillo de word_8.png
        {"scroll": [0.0, 0.02], "depth": 2, "items": [{"frame": "bg_castle", "x": 240, "y": 118}]},
        # islas flotantes, puentes y cascadas de ensueño
        {"scroll": [0.06, 0.04], "depth": 3, "frames": ["bg_isles", "bg_falls", "bg_ghosts", "bg_isles"], "step": 260, "y": [150, 176], "alpha": 0.85, "bob": True},
        {"scroll": [0.14, 0.08], "depth": 4, "frames": ["bg_falls", "bg_shadows", "bg_isles"], "step": 300, "y": [186, 206], "alpha": 0.9},
        # siluetas oscuras y árboles retorcidos cercanos
        {"scroll": [0.24, 0.12], "depth": 5, "frames": ["bg_shadows", "bg_trees"], "step": 360, "y": [204, 222], "alpha": 0.8},
        {"scroll": [0.32, 0.16], "depth": 6, "frames": ["bg_trees", "bg_ghosts"], "step": 430, "y": [222, 240], "alpha": 0.6},
    ],
}

terrain = [
    # A — El Bosque de los Susurros (0-112)
    g(0, 31, 20), g(36, 20, 20), g(60, 8, 19), g(72, 40, 20),
    # B — Los Puentes de la Luna (112-237)
    g(112, 16, 20), g(144, 32, 19), g(186, 20, 18), g(212, 26, 19),
    # C — El Jardín de las Sombras (238-368)
    g(238, 22, 20), g(268, 30, 20), g(304, 25, 19), g(334, 34, 20),
    # D — Las Torres Encantadas (368-500)
    g(368, 14, 20), g(382, 4, 18), g(386, 8, 16), g(394, 5, 18), g(399, 2, 15, CAS), g(401, 10, 12, CAS), g(421, 12, 13, CAS),
    g(447, 20, 20), g(467, 8, 18), g(475, 25, 20),
    # E — El Corazón del Castillo (500-625)
    g(500, 34, 20, CAS), g(544, 22, 20, CAS), g(566, 6, 18, CAS), g(572, 53, 20, CAS),
]

slopes = [
    # A: escalón con rampa
    {"x": 59, "y": 19, "dir": "up", "mat": LAV},
    # D: bajada de la primera torre y llegada al patio
    {"x": 381, "y": 19, "dir": "up", "mat": LAV}, {"x": 466, "y": 19, "dir": "up", "mat": LAV},
    {"x": 475, "y": 19, "dir": "down", "mat": LAV},
]

# bloques tenebrosos, de luna y de corazón (sólidos)
blocks = [
    {"x": 18, "y": 19, "type": "block_dark"}, {"x": 50, "y": 19, "type": "block_dark"},
    {"x": 200, "y": 17, "type": "block_moon"}, {"x": 201, "y": 17, "type": "block_moon"},
    {"x": 340, "y": 19, "type": "block_dark"}, {"x": 341, "y": 19, "type": "block_dark"}, {"x": 341, "y": 18, "type": "block_dark"},
    {"x": 490, "y": 19, "type": "block_heart"}, {"x": 491, "y": 19, "type": "block_heart"},
    {"x": 520, "y": 19, "type": "block_moon"},
]

SHROOM = -480
clouds = [
    # A
    {"x": 76, "y": 16, "frame": "cloud_plat_l", "top": 6},
    {"x": 100, "y": 15, "frame": "cloud_plat_m", "top": 6},
    # B: puentes de cuerda entre bastones de caramelo y plataformas de piedra
    {"x": 209, "y": 18, "frame": "candy_rope", "top": 6},
    {"x": 217, "y": 16, "frame": "stone_moon", "top": 3}, {"x": 221, "y": 13, "frame": "stone_star", "top": 3},
    {"x": 226, "y": 11, "frame": "cloud_plat_s", "top": 5},
    # C: setas fantasma elásticas y plataformas de nube
    {"x": 264, "y": 19, "frame": "shroom_pink", "top": 4, "bouncy": SHROOM},
    {"x": 276, "y": 20, "frame": "shroom_blue", "top": 4, "bouncy": SHROOM},
    {"x": 301, "y": 19, "frame": "cloud_plat_l", "top": 6},
    {"x": 318, "y": 19, "frame": "shroom_violet", "top": 4, "bouncy": -520},
    {"x": 322, "y": 12, "frame": "cloud_plat_m", "top": 6}, {"x": 328, "y": 10, "frame": "cloud_plat_s", "top": 5},
    {"x": 348, "y": 20, "frame": "shroom_pink", "top": 4, "bouncy": SHROOM},
    {"x": 352, "y": 16, "frame": "cloud_plat_c", "top": 6},
    # D: piedra del castillo (escalones hasta la torre)
    {"x": 455, "y": 16, "frame": "stone_moon", "top": 3},
    {"x": 486, "y": 12, "frame": "cloud_plat_s", "top": 5},
    # E: pasillos del castillo
    {"x": 512, "y": 16, "frame": "stone_star", "top": 3},
    {"x": 556, "y": 16, "frame": "stone_moon", "top": 3}, {"x": 560, "y": 13, "frame": "stone_heart", "top": 3},
    {"x": 586, "y": 16, "frame": "stone_star_s", "top": 3},
]

movers = [
    {"x": 414, "y": 12, "frame": "stone_heart", "top": 3, "dx": 4, "dy": 0, "duration": 2600},    # D: entre torres
    {"x": 480, "y": 18, "frame": "stone_star", "top": 3, "dx": 0, "dy": -4, "duration": 2400},     # D: a la llave
]

# plataformas colgantes de cadenas (péndulo bajo el anclaje). Oscilan sincronizadas: así nunca
# se cruzan y la distancia entre ellas es siempre la misma (saltos predecibles).
swings = [
    {"x": 131, "y": 12, "length": 112, "amplitude": 0.32, "duration": 3000, "frame": "hang_plat", "top": 3, "knot": "lantern_hang", "rope": "#5A3F2A"},
    {"x": 135.5, "y": 12, "length": 112, "amplitude": 0.32, "duration": 3000, "frame": "hang_plat_b", "top": 3, "knot": "lantern_hang", "rope": "#5A3F2A"},
    {"x": 140, "y": 12, "length": 112, "amplitude": 0.32, "duration": 3000, "frame": "hang_plat", "top": 3, "knot": "lantern_hang", "rope": "#5A3F2A"},
]

# plataformas que desaparecen poco después de pisarlas (tiemblan y vuelven)
crumbles = [
    {"x": 179, "y": 18, "frame": "small_plat_a", "top": 6}, {"x": 183, "y": 17, "frame": "small_plat_b", "top": 6},
    {"x": 331, "y": 18, "frame": "small_plat_a", "top": 6},
    {"x": 436, "y": 15, "frame": "small_plat_b", "top": 6}, {"x": 440, "y": 17, "frame": "small_plat_a", "top": 6},
    {"x": 444, "y": 19, "frame": "small_plat_b", "top": 6},
]

# Plataformas fantasma: VISIBLE -> WARNING -> INVISIBLE -> REAPPEAR con un ciclo fijo. Nunca
# desaparecen a la vez las que se necesitan: las de un mismo hueco van desfasadas (delay).
ghosts = [
    # A: la primera enseña la mecánica (ciclo largo)
    {"x": 33, "y": 19, "period": 4200, "visible": 2400, "warn": 900, "delay": 0},
    {"x": 88, "y": 16, "period": 3600, "visible": 1800, "warn": 800, "delay": 0},
    {"x": 93, "y": 13, "period": 3600, "visible": 1800, "warn": 800, "delay": 1800},
    # D-E: ruta alta hacia la llave del castillo
    {"x": 484, "y": 9, "period": 3400, "visible": 1700, "warn": 800, "delay": 0},
    {"x": 489, "y": 7, "period": 3400, "visible": 1700, "warn": 800, "delay": 1700},
]

# Estrellas que caen: avisan (estrella colgada que titila y destello en el suelo) y caen recto.
STAR_TRAP = {"frames": ["star_trap_b"], "warn_frame": "star_trap"}
falling = [
    {"x": 158, "y": 19, "height": 9, "period": 3200},
    {"x": 165, "y": 19, "height": 9, "period": 3200, "delay": 1600},
    {"x": 223, "y": 19, "height": 10, "period": 3400, "delay": 800},
    {"x": 231, "y": 19, "height": 10, "period": 3400, "delay": 2400},
    {"x": 492, "y": 20, "height": 10, "period": 3000, "delay": 500},
]
for f in falling:
    f.update(STAR_TRAP)

# Charcos y bruma de sombras: daño moderado con intervalo mientras se tocan.
shadows = [
    {"x": 248, "y": 20, "w": 4, "kind": "pool"},
    {"x": 278, "y": 20, "w": 6, "kind": "mist"},
    {"x": 312, "y": 19, "w": 4, "kind": "pool"},
    {"x": 356, "y": 20, "w": 4, "kind": "pool"},
    {"x": 457, "y": 20, "w": 5, "kind": "mist"},
]

# Ganchos en cadena: péndulos de hazard (sólo daña el gancho, la cadena no).
hooks = [
    {"x": 405, "y": 5, "length": 72, "swing": 55, "speed": 85, "frame": "hook_moon"},
    {"x": 452, "y": 13, "length": 64, "swing": 50, "speed": 95, "frame": "hook_star"},
    {"x": 462, "y": 13, "length": 64, "swing": 50, "speed": 95, "angle": 40, "frame": "hook_moon"},
    {"x": 590, "y": 13, "length": 64, "swing": 45, "speed": 80, "frame": "hook_star"},
]

# Faroles mágicos: al tocarlos (o dispararles) se encienden y revelan sus puentes ocultos.
lanterns = [
    {"id": "lantern_1", "x": 530, "y": 20, "bridges": ["bridge_1"]},
    {"id": "lantern_2", "x": 548, "y": 20, "bridges": ["bridge_2"]},
]
hidden_bridges = [
    {"id": "bridge_1", "x": 536, "y": 20, "frame": "candy_rope", "top": 6},
    {"id": "bridge_1", "x": 541.5, "y": 20, "frame": "candy_rope_s", "top": 6},
    {"id": "bridge_2", "x": 554, "y": 11, "frame": "cloud_plat_l", "top": 6},
]

hazards = [
    {"x": 120, "y": 20, "frame": "spike_candy", "shape": "spikes"},
    {"x": 196, "y": 18, "frame": "spike_candy", "shape": "spikes"},
    {"x": 428, "y": 13, "frame": "spike_cone", "shape": "spikes"},
    {"x": 604, "y": 20, "frame": "spike_candy", "shape": "spikes"},
]

hearts = [{"x": 70, "y": 18, "frame": "heart_dream"}, {"x": 160, "y": 16, "frame": "heart_dream"},
          {"x": 286, "y": 17, "frame": "heart_dream_b"}, {"x": 426, "y": 10, "frame": "heart_dream"},
          {"x": 540, "y": 16, "frame": "heart_dream_b"}, {"x": 612, "y": 17, "frame": "heart_dream"}]

# Tres recuerdos mágicos de la aventura (sección E): el valor, la imaginación y la amistad.
memories = [
    {"id": "memory_courage", "kind": "memory", "x": 515, "y": 13, "frame": "dream_orb", "tint": "#FFA657", "memory": "courage"},
    {"id": "memory_imagination", "kind": "memory", "x": 560, "y": 10, "frame": "dream_orb", "tint": "#C8A5FF", "memory": "imagination"},
    {"id": "memory_friendship", "kind": "memory", "x": 600, "y": 17, "frame": "dream_orb", "tint": "#F6B4E9", "memory": "friendship"},
]

dream = [
    {"id": "moon_1", "kind": "moon", "x": 96, "y": 10, "frame": "moon_gold"},
    {"id": "moon_2", "kind": "moon", "x": 226, "y": 8, "frame": "moon_violet"},
    {"id": "moon_3", "kind": "moon", "x": 406, "y": 9, "frame": "moon_blue"},
    {"id": "orb_1", "kind": "orb", "x": 328, "y": 7, "frame": "dream_orb"},
    {"id": "key_1", "kind": "key", "x": 492, "y": 4, "frame": "castle_key"},
] + memories

# Cofre final: se abre con la llave del castillo y suelta estrellas y un corazón alado.
chests = [{"x": 592, "y": 20, "frame": "chest_w8", "stars": 8}]

stars = (
    # A
    row(3, 28, 19, 3) + arc(30, 36, 16, 2, 1) + row(38, 54, 19, 3) + row(60, 67, 18, 2) + arc(68, 72, 16, 2, 1)
    + row(74, 110, 19, 3) + row(86, 94, 12, 2) + row(98, 102, 12, 2)
    # B
    + row(113, 124, 19, 3) + arc(127, 145, 15, 2, 2) + row(147, 174, 18, 3) + arc(177, 185, 15, 2, 2)
    + row(187, 205, 17, 3) + arc(207, 212, 15, 2, 1) + row(213, 236, 18, 3) + row(216, 222, 11, 2)
    # C
    + row(239, 259, 19, 3) + arc(261, 268, 15, 2, 1) + row(269, 297, 19, 3) + arc(275, 285, 12, 3, 2)
    + arc(298, 304, 16, 2, 1) + row(305, 327, 18, 3) + row(320, 326, 9, 2) + arc(329, 334, 15, 2, 1)
    + row(335, 367, 19, 3) + row(350, 354, 12, 2)
    # D
    + row(369, 380, 19, 3) + row(383, 393, 15, 2) + column(398, 9, 13) + row(402, 410, 11, 2) + arc(411, 421, 9, 2, 2)
    + row(422, 432, 12, 2) + arc(434, 446, 12, 2, 2) + row(448, 466, 19, 3) + row(468, 474, 17, 2) + row(476, 499, 19, 3)
    + column(480, 9, 13) + row(484, 490, 4, 2)
    # E
    + row(501, 533, 19, 3) + arc(534, 544, 17, 2, 2) + row(545, 565, 19, 3) + row(552, 558, 8, 2)
    + row(567, 571, 17, 2) + row(573, 624, 19, 3)
)

enemies = (
    [enemy("fantasmita", x, y, a, b, fly=[3, 2]) for x, y, a, b in [
        (46, 16, 40, 54), (104, 15, 96, 110), (226, 14, 216, 234), (290, 15, 280, 296), (322, 14, 314, 328),
        (352, 13, 344, 360), (478, 15, 472, 486), (524, 15, 516, 532), (582, 15, 574, 590)]]
    + [enemy("bloquito", x, y, a, b) for x, y, a, b in [
        (80, 20, 74, 92), (194, 18, 188, 204), (272, 20, 269, 286), (346, 20, 343, 354), (372, 20, 369, 380),
        (452, 20, 448, 465), (506, 20, 502, 514), (578, 20, 574, 588)]]
    + [enemy("murcibola", x, y, a, b, rest=[x, y]) for x, y, a, b in [
        (168, 14, 160, 174), (232, 13, 222, 236), (308, 14, 304, 320), (362, 14, 354, 366), (432, 9, 424, 434),
        (496, 14, 488, 499), (568, 13, 562, 576)]]
)

checkpoints = [{"x": 150, "y": 19}, {"x": 425, "y": 13}, {"x": 610, "y": 20}]

signs = [
    {"x": 3, "y": 20, "text": "Mundo 8: El Castillo de las Pesadillas. ¡La última aventura de Alice!"},
    {"x": 27, "y": 20, "text": "Las plataformas fantasma brillan antes de desaparecer... ¡y siempre vuelven!"},
    {"x": 39, "y": 20, "text": "El Fantasmita Farol levanta su farol antes de lanzar una estrellita"},
    {"x": 74, "y": 20, "text": "El Bloquito Sombra embiste: después del golpe se queda quieto. ¡Ahora!"},
    {"x": 84, "y": 20, "text": "Arriba hay un fragmento de luna. ¡Reúne los tres!"},
    {"x": 114, "y": 20, "text": "Los Puentes de la Luna: salta a las plataformas colgantes cuando se acerquen"},
    {"x": 152, "y": 19, "text": "Las estrellas titilan antes de caer: mira el destello del suelo"},
    {"x": 166, "y": 19, "text": "El Murcibola de Trapo se encoge antes de lanzarse en picada"},
    {"x": 174, "y": 19, "text": "Estas plataformas tiemblan y se caen: ¡no te pares!"},
    {"x": 240, "y": 20, "text": "El Jardín de las Sombras: no pises los charcos de sombra"},
    {"x": 258, "y": 20, "text": "Las setas fantasma son elásticas: ¡rebota!"},
    {"x": 270, "y": 20, "text": "La bruma de sombras hace daño: salta por encima con la seta"},
    {"x": 316, "y": 19, "text": "Esta seta te sube a una ruta secreta con el orbe especial"},
    {"x": 370, "y": 20, "text": "Las Torres Encantadas: ¡salta de escalón en escalón!"},
    {"x": 449, "y": 20, "text": "Los ganchos se balancean siempre igual: pasa cuando se alejen"},
    {"x": 477, "y": 20, "text": "Arriba, entre plataformas fantasma, está la llave del castillo"},
    {"x": 502, "y": 20, "text": "El Corazón del Castillo: busca los tres recuerdos mágicos"},
    {"x": 528, "y": 20, "text": "Los faroles mágicos revelan puentes ocultos. ¡Tócalo!"},
    {"x": 590, "y": 20, "text": "¿Tienes la llave? Este cofre guarda un tesoro"},
    {"x": 616, "y": 20, "text": "Detrás de la gran puerta te espera el Rey Pesadelo. ¡Valor, Alice!"},
]

decor = []


def deco(x, y, frame, **kw):
    d = {"x": x, "y": y, "frame": frame}
    d.update(kw)
    decor.append(d)


for x, y, f, kw in [
    # A — árboles retorcidos, calabazas, faroles, vallas
    (1, 20, "tree_twisted", {"back": True}), (8, 20, "fence", {"back": True}), (14, 20, "pumpkins", {}),
    (19, 20, "lamp_post", {}), (23, 20, "tree_twisted_b", {"back": True}), (40, 20, "candles", {}), (44, 20, "tree_twisted", {"back": True}),
    (51, 20, "pumpkin", {}), (63, 19, "lantern_moon", {"back": True}), (66, 19, "fence_b", {"back": True}),
    (78, 20, "gargoyle_s", {"back": True}), (86, 20, "tree_twisted_b", {"back": True}), (95, 20, "pumpkins", {}),
    (103, 20, "orb_post", {}), (108, 20, "tree_twisted", {"back": True}),
    # B — puentes, cadenas, estrellas, cascadas
    (113, 20, "lamp_post", {}), (117, 20, "fence", {"back": True}), (124, 20, "lantern_star", {}),
    (147, 19, "lantern_moon", {}), (155, 19, "gargoyle", {"back": True}), (171, 19, "fence_b", {"back": True}),
    (188, 18, "pumpkins", {}), (203, 18, "lamp_post", {}), (214, 19, "tree_twisted_b", {"back": True}),
    (229, 19, "candles", {}), (235, 19, "lantern_star", {}),
    # C — setas, calabazas, árboles oscuros, faroles
    (239, 20, "tree_twisted", {"back": True}), (255, 20, "pumpkins", {}), (269, 20, "lamp_post", {}),
    (288, 20, "tree_twisted_b", {"back": True}), (295, 20, "pumpkin", {}), (306, 19, "fence", {"back": True}),
    (324, 19, "tree_twisted", {"back": True}), (336, 20, "candles", {}), (344, 20, "gargoyle_s", {"back": True}),
    (362, 20, "tree_twisted_b", {"back": True}), (366, 20, "lantern_moon", {}),
    # D — torres, ventanas iluminadas, cadenas
    (370, 20, "castle_window", {"back": True}), (378, 20, "banner_moon", {"back": True}), (389, 16, "lamp_post", {}),
    (403, 12, "banner_star", {"back": True}), (409, 12, "castle_window", {"back": True}), (423, 13, "banner_heart", {"back": True}),
    (431, 13, "gargoyle_s", {}), (449, 20, "castle_window", {"back": True}), (464, 20, "lamp_post", {}),
    (470, 18, "banner_moon", {"back": True}), (477, 20, "gargoyle", {"back": True}), (497, 20, "banner_star", {"back": True}),
    # E — el corazón del castillo: ventanales, estandartes, gárgolas, cristales
    (501, 20, "castle_window", {"back": True}), (508, 20, "banner_heart", {"back": True}), (517, 20, "castle_window", {"back": True}),
    (526, 20, "banner_star", {"back": True}), (533, 20, "lamp_post", {}), (545, 20, "castle_window", {"back": True}),
    (551, 20, "banner_moon", {"back": True}), (563, 20, "gargoyle", {"back": True}), (569, 18, "banner_heart", {"back": True}),
    (575, 20, "castle_window", {"back": True}), (583, 20, "banner_star", {"back": True}), (598, 20, "castle_window", {"back": True}),
    (606, 20, "gargoyle_s", {"back": True}), (614, 20, "banner_heart", {"back": True}), (623, 20, "lamp_post", {}),
]:
    deco(x, y, f, **kw)
# primer plano: sólo piezas pequeñas y bajas
for x, y, f in [(6, 20, "pumpkin"), (98, 20, "candles"), (190, 18, "pumpkin"), (300, 20, "candles"), (374, 20, "pumpkin"), (511, 20, "candles"), (594, 20, "candles")]:
    deco(x, y, f, front=True)

dream_names = {"moon": "Fragmento de luna", "orb": "Orbe especial", "key": "Llave del castillo", "memory": "Recuerdo mágico"}

level = {
    "id": 8, "key": "world8", "name": "El Castillo de las Pesadillas", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world8", "tileset": "world8_tiles", "objectsAtlas": "world8_objects", "backgroundAtlas": "world8_bg",
    "progress": {"total": TOTAL, "offset": 0, "scale": 1}, "playerStart": {"x": 4, "y": 20}, "nextScene": "Boss8",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w8", "signpost": "sign_w8", "star": ["world8_objects", "star_w8"]},
    "sections": [
        {"id": "A", "name": "El Bosque de los Susurros", "from": 0},
        {"id": "B", "name": "Los Puentes de la Luna", "from": 1800},
        {"id": "C", "name": "El Jardín de las Sombras", "from": 3800},
        {"id": "D", "name": "Las Torres Encantadas", "from": 5900},
        {"id": "E", "name": "El Corazón del Castillo", "from": 8000},
        {"id": "F", "name": "El Trono de las Pesadillas", "from": 10000},
    ],
    "background": background, "terrain": terrain, "slopes": slopes, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": swings, "crumbles": crumbles, "pads": [],
    "winds": [], "hazards": hazards, "paints": [], "rollers": [], "bouncers": [], "drips": [], "rivers": [],
    "magicCrayons": [], "yarnRollers": [], "sleepClouds": [], "magicButtons": [],
    "fallingStars": falling, "ghostPlatforms": ghosts, "shadowZones": shadows, "hooks": hooks,
    "lanterns": lanterns, "hiddenBridges": hidden_bridges, "chests": chests, "hearts": hearts,
    "dreamCollectibles": dream, "dreamMain": "moon", "dreamNames": dream_names,
    "dreamBanner": "¡Los %d fragmentos de luna! Estrella extra", "dreamHud": ["world8_objects", "moon_gold", "moon_"],
    "stars": [], "enemies": enemies, "checkpoints": checkpoints, "pickups": [],
    "signs": signs, "decor": decor,
    "door": {"x": 620, "y": 20, "atlas": "world8_objects", "frame": "portal_w8", "scale": 1.3, "giant": True},
}


# --------------------------------------------------------------- comprobaciones
def solid_grid():
    grid = [[False] * LEVEL_W for _ in range(ROWS)]
    for r in terrain:
        for y in range(r["y"], min(ROWS, r["y"] + r["h"])):
            for x in range(max(0, r["x"]), min(LEVEL_W, r["x"] + r["w"])):
                grid[y][x] = True
    for b in blocks:
        grid[b["y"]][b["x"]] = True
    for s in slopes:
        grid[s["y"]][s["x"]] = True
    return grid


GRID = solid_grid()
level["stars"] = [s for s in stars if 0 <= s["x"] < LEVEL_W and 0 <= s["y"] < ROWS and not GRID[s["y"]][s["x"]]]
for e in enemies:
    if e["type"] in ("fantasmita", "murcibola"):
        assert not GRID[e["y"]][e["x"]], f"enemigo volador dentro del terreno: {e}"
        continue
    assert GRID[e["y"]][e["x"]] and not GRID[e["y"] - 1][e["x"]], f"enemigo sin suelo libre: {e}"
for c in checkpoints + hazards + lanterns + chests + [{"x": int(f["x"]), "y": f["y"]} for f in falling]:
    assert GRID[c["y"]][int(c["x"])] and not GRID[c["y"] - 1][int(c["x"])], f"objeto sin suelo: {c}"
for z in shadows:
    for x in range(z["x"], z["x"] + z["w"]):
        assert GRID[z["y"]][x] and not GRID[z["y"] - 1][x], f"sombra sin suelo: {z}"
for d in dream + hearts:
    assert not GRID[d["y"]][d["x"]], f"coleccionable dentro del terreno: {d}"
for s in signs:
    assert GRID[s["y"]][s["x"]] and not GRID[s["y"] - 1][s["x"]], f"cartel sin suelo: {s}"
for cp in checkpoints:
    assert not any(z["x"] - 2 <= cp["x"] <= z["x"] + z["w"] + 1 for z in shadows), f"checkpoint junto a una sombra: {cp}"
# huecos obligatorios: ninguna columna sin suelo durante más de 5 teselas sin plataforma
spans = [(c["x"] - 3, c["x"] + 3) for c in clouds] + [(m["x"] - 3, m["x"] + 3 + m.get("dx", 0)) for m in movers] \
    + [(c["x"] - 1.5, c["x"] + 1.5) for c in crumbles] + [(gp["x"] - 1.5, gp["x"] + 1.5) for gp in ghosts] \
    + [(s["x"] - 1.5 - math.sin(s["amplitude"]) * s["length"] / 16, s["x"] + 1.5 + math.sin(s["amplitude"]) * s["length"] / 16) for s in swings] \
    + [(b["x"] - 3, b["x"] + 3) for b in hidden_bridges]
run = 0
for x in range(LEVEL_W):
    has_ground = any(GRID[y][x] for y in range(ROWS))
    covered = any(a <= x <= b for a, b in spans)
    run = 0 if has_ground or covered else run + 1
    assert run <= 5, f"hueco de más de 5 teselas sin plataforma en x={x}"
# secciones: cada checkpoint en la sección pedida (B, D y antes del jefe en E)
cpx = [c["x"] * 16 for c in checkpoints]
assert 1800 <= cpx[0] < 3800 and 5900 <= cpx[1] < 8000 and 8000 <= cpx[2] < 10000

# ------------------------------------------------------------------ salón del trono (F)
GATE_X = 64
arena_bg = dict(background)
arena_bg["layers"] = [
    background["layers"][0],
    {"scroll": [0.03, 0.03], "depth": 3, "items": [{"frame": "bg_isles", "x": 90, "y": 150}, {"frame": "bg_falls", "x": 380, "y": 156}]},
    background["layers"][3],
]
arena_decor = []
for x, f, back in [
    (2, "lamp_post", False), (6, "castle_window", True), (12, "banner_heart", True), (18, "gargoyle", True), (24, "castle_window", True),
    (30, "banner_star", True), (36, "lamp_post", False), (42, "castle_window", True), (48, "banner_moon", True), (54, "gargoyle_s", True),
    (59, "castle_window", True), (70, "banner_heart", True), (82, "castle_window", True), (94, "banner_star", True),
    (106, "castle_window", True), (113, "throne", True), (120, "banner_moon", True), (123, "lamp_post", False),
]:
    arena_decor.append({"x": x, "y": 14, "frame": f, "back": back})

boss = {
    "key": "world8_boss", "worldId": 8, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world8", "bossMusic": "rey_pesadelo",
    "furyMusic": "rey_pesadelo_fury", "transformMusic": "transformation",
    "tileset": "world8_tiles", "objectsAtlas": "world8_objects", "backgroundAtlas": "world8_bg", "background": arena_bg,
    "frames": level["frames"], "progress": {"total": TOTAL, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 3, "y": 14},
    "sections": [{"id": "F", "name": "El Trono de las Pesadillas", "from": 10000}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3, "mat": CAS}], "blocks": [],
    # plataformas laterales a 3 teselas del suelo: por encima de las ondas del grito y de la
    # ráfaga del garrazo (que recorren el suelo). El cuerpo dañino del jefe queda por debajo.
    "clouds": [{"x": 74, "y": 11, "frame": "stone_moon", "top": 3}, {"x": 93, "y": 11, "frame": "stone_heart", "top": 3},
               {"x": 112, "y": 11, "frame": "stone_moon", "top": 3}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 12} for x in range(8, 58, 4)] + [{"x": x, "y": 8} for x in [73, 74, 75, 92, 93, 94, 111, 112, 113]],
    "enemies": [], "checkpoints": [], "pickups": [],
    "signs": [{"x": 4, "y": 14, "text": "El Trono de las Pesadillas. El Rey Pesadelo... ¿por qué estará tan enfadado?"}],
    "decor": arena_decor,
    # fase 2: estrellas que caen en la arena (se activan con aviso; siempre hay sitio libre)
    "phaseStars": [dict(STAR_TRAP, x=78, y=14, height=9, period=3600), dict(STAR_TRAP, x=99, y=14, height=9, period=3600, delay=1800),
                   dict(STAR_TRAP, x=118, y=14, height=9, period=3600, delay=900)],
    "gate": {"x": GATE_X, "rows": [10, 11, 12, 13], "tile": "block_dark"}, "triggerX": GATE_X + 4,
    "boss": {"homeX": 86, "minX": GATE_X + 1, "maxX": ARENA_W - 1, "floorY": 224, "frameBoth": True,
             "scene": "res://scenes/bosses/ReyPesadelo.tscn", "name": "Rey Pesadelo",
             "introBanner": "¡El Rey Pesadelo despierta!", "defeatBanner": "El Rey Pesadelo está agotado..."},
}

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world8.json", level), ("world8_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 8: {len(level['stars'])} estrellas, {len(enemies)} enemigos, ancho total {TOTAL} px")
