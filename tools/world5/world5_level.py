"""
Datos del MUNDO 5 — Sueños Cósmicos, Islas en el Cielo (diseño del nivel).

Uso:  python tools/world5/world5_level.py
Escribe godot/data/world5/world5.json (nivel) y godot/data/world5/world5_boss.json (arena).

Mismo formato que los Mundos 2-4: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 597 x 25 teselas (9.552 px) + arena (59)
= 10.496 px. El terreno usa el material "cosmic" (roca estrellada con nube) del tileset oficial.

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Ningún escalón supera 3 teselas sin ayuda; lo más alto se alcanza con trampolines de
estrella, plataformas de lanzamiento, cascadas de luz (corriente ascendente) o cohetes. Ningún
hueco obligatorio supera 5 teselas sin plataforma.

  A El observatorio de las nubes      0-2.000   nubes, estrellas sólidas y trampolín, Estrellita Fugaz
  B El camino de la luna          2.000-4.000   lunas crecientes, luna móvil y en órbita, plataforma
                                                colgante, cascada de luz, Cohetito, 1.er checkpoint
  C Los jardines planetarios      4.000-6.200   toboganes arcoíris, lanzamiento a la ruta alta con la
                                                estrella especial, grupos de Estrellitas, cohetes
  D La lluvia de meteoros         6.200-8.500   pendientes, islas partidas, Meteoritos, estrellas que
                                                caen, nubes explosivas, 2.º checkpoint
  E El trono de la Luna           8.500-10.500  gran isla con el palacio lunar y la arena del jefe
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world5"
ROWS = 25
LEVEL_W = 597
ARENA_W = 59
TOTAL = (LEVEL_W + ARENA_W) * 16


def g(x, w, top=20):
    """Isla que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top, "mat": "cosmic"}


def island(x, w, top, h):
    """Isla flotante (se ve su base de roca colgante)."""
    return {"x": x, "y": top, "w": w, "h": h, "mat": "cosmic"}


def row(x0, x1, y, step=4):
    return [{"x": x, "y": y} for x in range(x0, x1 + 1, step)]


def arc(x0, x1, y, height=2, step=3):
    n = x1 - x0
    return [{"x": x, "y": y - round(math.sin(math.pi * (x - x0) / n) * height)} for x in range(x0, x1 + 1, step)]


def column(x, y0, y1):
    return [{"x": x, "y": y} for y in range(y0, y1 + 1, 2)]


def along(sl, step=3):
    """Estrellas a lo largo de un tobogán, una tesela por encima de la rampa."""
    out = []
    for x in range(sl["x0"] + 2, sl["x1"] - 1, step):
        y = sl["y0"] + (x + 0.5 - sl["x0"]) / (sl["x1"] - sl["x0"]) * (sl["y1"] - sl["y0"])
        out.append({"x": x, "y": math.floor(y) - 1})
    return out


def enemy(t, x, y, a, b, **extra):
    e = {"type": t, "x": x, "y": y, "patrol": [a, b]}
    e.update(extra)
    return e


background = {
    "sky": "w5_sky", "far": "w5_clouds_far", "near": "w5_clouds_near",
    "atlas": "world5_bg", "objectsAtlas": "world5_objects", "sparkles": True,
    "drifters": ["cloud_s", "cloud_m"],
    "layers": [
        # capa 2: planetas, lunas y constelaciones lejanas
        {"scroll": [0.02, 0.02], "depth": 2, "items": [
            {"frame": "bg_ring_planet", "x": 66, "y": 46, "alpha": 0.95}, {"frame": "bg_blue_planet", "x": 430, "y": 40, "alpha": 0.9}]},
        {"scroll": [0.03, 0.02], "depth": 2, "frames": ["bg_trails"], "step": 260, "y": [24, 70], "alpha": 0.9},
        # capa 3: la luna sonriente y el castillo celeste de word_5.png
        {"scroll": [0.05, 0.04], "depth": 3, "items": [{"frame": "bg_moon_castle", "x": 268, "y": 92}]},
        # capa 3: islas distantes con torres y castillos
        {"scroll": [0.15, 0.08], "depth": 4, "frames": ["bg_island_small", "bg_tower_island", "bg_islet"], "step": 210, "y": [130, 175], "alpha": 0.8, "bob": True},
        # planetas más cercanos y niebla cósmica
        {"scroll": [0.28, 0.14], "depth": 5, "frames": ["bg_ring_planet", "bg_blue_planet", "bg_moon_face"], "step": 400, "y": [50, 110], "alpha": 0.75, "bob": True},
        {"scroll": [0.35, 0.18], "depth": 6, "frames": ["bg_fog"], "step": 320, "y": [195, 225], "alpha": 0.5},
    ],
}

terrain = [
    # A — El observatorio de las nubes
    g(0, 22, 20), g(26, 14, 20), g(40, 12, 18), g(57, 20, 19), g(77, 16, 18), g(97, 34, 19),
    # B — El camino de la luna
    g(140, 10, 18), g(160, 18, 19), g(178, 14, 13), g(203, 14, 16), g(217, 8, 19), g(231, 19, 19),
    # C — Los jardines planetarios
    g(257, 15, 16), g(286, 25, 20), g(314, 13, 19), g(327, 3, 17), g(330, 5, 15), g(353, 18, 21),
    g(376, 11, 15),
    # D — La lluvia de meteoros
    g(387, 1, 16), g(388, 22, 17), g(416, 13, 18), island(431, 5, 17, 4), island(439, 5, 16, 4), island(447, 6, 17, 4),
    g(463, 8, 18), g(471, 14, 17), g(491, 20, 18), g(517, 14, 19),
    # E — El trono de la Luna
    g(531, 66, 19), island(547, 7, 10, 2),
]

# rampas de 45 grados (tileset oficial "pendientes / rampas")
slopes = [
    {"x": 76, "y": 18, "dir": "up", "mat": "cosmic"},
    {"x": 387, "y": 15, "dir": "down", "mat": "cosmic"}, {"x": 388, "y": 16, "dir": "down", "mat": "cosmic"},
    {"x": 470, "y": 17, "dir": "up", "mat": "cosmic"},
]

blocks = [{"x": 537, "y": 18, "type": "block_star"}]

# Plataformas unidireccionales (x = centro, y = superficie)
clouds = [
    # A
    {"x": 24, "y": 19, "frame": "cloud_plat_m", "top": 2},
    {"x": 31.5, "y": 16, "frame": "star_plat", "top": 4},                 # estrella sólida
    {"x": 41.5, "y": 13, "frame": "cloud_plat_l", "top": 1},              # sobre el trampolín: ficha de luna 1
    {"x": 54.5, "y": 17, "frame": "cloud_plat_l", "top": 1},
    {"x": 95, "y": 17, "frame": "cloud_plat_m", "top": 2},
    # B: lunas crecientes en curva
    {"x": 133.5, "y": 17, "frame": "moon_plat_a", "top": 8}, {"x": 137, "y": 15, "frame": "moon_plat_b", "top": 4},
    {"x": 186, "y": 10, "frame": "islet_e", "top": 1},
    # C
    {"x": 312.5, "y": 19, "frame": "star_plat", "top": 4},
    {"x": 304.5, "y": 11, "frame": "cloud_plat_l", "top": 1}, {"x": 309.5, "y": 10, "frame": "star_plat", "top": 4},
    {"x": 314.5, "y": 10, "frame": "moon_plat_c", "top": 7}, {"x": 319.5, "y": 10, "frame": "islet_d", "top": 1},   # ruta alta: estrella especial
    # D
    {"x": 413, "y": 17, "frame": "cloud_plat_m", "top": 2}, {"x": 443.5, "y": 11, "frame": "islet_b", "top": 1},  # ficha de luna 3
    {"x": 488, "y": 16, "frame": "cloud_plat_m", "top": 2},
    # E
    {"x": 556, "y": 13, "frame": "islet_a", "top": 1},
]

movers = [
    {"x": 152, "y": 18, "frame": "moon_plat_d", "top": 9, "dx": 5, "dy": 0, "duration": 3200},          # 0: luna creciente móvil
    {"x": 228, "y": 18, "frame": "hang_plat", "top": 18, "dx": 0, "dy": 0.6, "duration": 1500},         # 1: plataforma colgante
]

rockets = [
    {"x": 251.5, "y": 18, "frame": "rocket_side", "top": 2, "dx": 4, "dy": 0, "duration": 2800},        # cohete sobre el vacío
    {"x": 372.5, "y": 21, "frame": "rocket_lift", "top": 2, "dx": 0, "dy": -6, "duration": 3400},       # cohete ascensor
    {"x": 455.5, "y": 17, "frame": "rocket_side", "top": 2, "dx": 5, "dy": 0, "duration": 3000},        # cohete entre islas
]

orbits = [
    {"x": 197.5, "y": 14, "rx": 2.5, "ry": 1.2, "duration": 4600, "frame": "moon_plat_a", "top": 8},    # luna en órbita: ruta curva
    {"x": 514, "y": 17, "rx": 2, "ry": 1.5, "duration": 4200, "dir": -1, "frame": "moon_plat_c", "top": 7},
]

slides = [
    {"x0": 271, "y0": 16, "x1": 286, "y1": 20, "speed": 190},
    {"x0": 335, "y0": 15, "x1": 353, "y1": 21, "speed": 200},
]

# trampolines de estrella (suaves) y plataformas de lanzamiento (BouncePad)
pads = [
    {"x": 37, "y": 20, "frame": "star_spring", "power": -480},
    {"x": 300, "y": 20, "frame": "launch_pad", "power": -560},
    {"x": 328, "y": 17, "frame": "star_spring", "power": -400},
    {"x": 440, "y": 16, "frame": "star_spring", "power": -450},
]

# cascadas de luz que suben (corriente ascendente con chispas doradas)
light_falls = [
    {"x": 175, "y": 7, "w": 3, "h": 12, "force": 1500, "maxUp": 200},   # sube al acantilado del camino de la luna
    {"x": 544, "y": 5, "w": 2, "h": 14, "force": 1500, "maxUp": 200},   # sube a la isla alta del trono (constelación)
]

falling_stars = [
    {"x": 396, "y": 17, "height": 10, "period": 3200},
    {"x": 403, "y": 17, "height": 10, "period": 3200, "delay": 1600},
    {"x": 426, "y": 18, "height": 10, "period": 3000, "delay": 800},
    {"x": 495, "y": 18, "height": 10, "period": 3000},
    {"x": 500, "y": 18, "height": 10, "period": 3000, "delay": 1000},
    {"x": 505, "y": 18, "height": 10, "period": 3000, "delay": 2000},
]

explosive_clouds = [
    {"x": 411, "y": 13}, {"x": 425, "y": 14},
    {"x": 486, "y": 12}, {"x": 490, "y": 13},
    {"x": 525, "y": 15},
]

dream = [
    {"id": "moon_1", "kind": "moon_token", "x": 41, "y": 10, "frame": "moon_token"},
    {"id": "moon_2", "kind": "moon_token", "x": 197, "y": 9, "frame": "moon_token"},
    {"id": "moon_3", "kind": "moon_token", "x": 443, "y": 8, "frame": "moon_token"},
    {"id": "special_1", "kind": "special", "x": 319, "y": 7, "frame": "special_star"},
    {"id": "constellation_1", "kind": "constellation", "x": 550, "y": 8, "frame": "star_w5_b", "tint": "#bfe8ff"},
    {"id": "rocket_1", "kind": "rocket", "x": 514, "y": 13, "frame": "mini_rocket", "tint": "#ffe28a"},
]

stars = (
    # A
    row(4, 20, 19, 4) + arc(22, 26, 17, 2, 2) + row(28, 30, 19, 2) + row(31, 32, 14, 1) + row(34, 38, 19, 4)
    + column(37, 13, 17) + row(40, 43, 11, 3) + row(44, 50, 17, 3) + arc(52, 57, 15, 2, 2) + row(59, 75, 18, 4)
    + row(78, 92, 17, 3) + arc(93, 97, 15, 2, 2) + row(99, 129, 18, 3)
    # B
    + row(133, 134, 15, 1) + row(136, 138, 13, 2) + row(141, 149, 17, 2) + arc(150, 159, 16, 2, 3) + row(161, 173, 18, 3)
    + column(176, 9, 17) + row(179, 191, 12, 3) + row(185, 187, 8, 2) + arc(193, 202, 12, 2, 3) + row(204, 216, 15, 3)
    + row(218, 224, 18, 3) + arc(225, 231, 16, 2, 2) + row(232, 249, 18, 3)
    # C
    + arc(250, 257, 16, 2, 2) + row(259, 270, 15, 3) + along(slides[0]) + row(287, 299, 19, 3) + column(300, 13, 18)
    + row(302, 307, 9, 2) + row(309, 315, 8, 3) + row(301, 309, 19, 4) + row(312, 313, 17, 1) + row(316, 326, 18, 3)
    + row(328, 334, 14, 3) + along(slides[1]) + row(354, 370, 20, 3) + column(372, 14, 19) + row(377, 386, 14, 3)
    # D
    + row(390, 409, 16, 3) + arc(410, 416, 16, 2, 2) + row(417, 428, 17, 3) + row(432, 435, 16, 1) + row(439, 443, 15, 2)
    + row(441, 446, 9, 2) + row(448, 452, 16, 2) + arc(453, 463, 15, 2, 3) + row(464, 469, 17, 2) + row(472, 484, 16, 3)
    + row(486, 490, 15, 2) + row(492, 510, 17, 3) + arc(511, 517, 15, 2, 2) + row(518, 530, 18, 3)
    # E
    + row(532, 543, 18, 3) + column(545, 7, 17) + row(548, 553, 9, 2) + row(555, 586, 18, 3)
)

enemies = (
    [enemy("estrellita", x, y, a, b, **kw) for x, y, a, b, kw in [
        (66, 15, 60, 74, {}), (108, 15, 102, 116, {"wave_phase": 0.0}), (113, 14, 107, 121, {"wave_phase": 0.5}),
        (168, 15, 162, 176, {}), (238, 15, 233, 248, {}),
        (292, 15, 288, 304, {"wave_phase": 0.0}), (295, 14, 290, 306, {"wave_phase": 0.33}), (298, 15, 292, 308, {"wave_phase": 0.66}),
        (317, 15, 314, 326, {"wave_phase": 0.0}), (320, 14, 314, 326, {"wave_phase": 0.5}),
        (424, 14, 418, 429, {}), (500, 13, 493, 509, {}), (565, 14, 558, 575, {"wave_phase": 0.25})]]
    + [enemy("cohetito", x, y, a, b, **kw) for x, y, a, b, kw in [
        (170, 15, 165, 176, {}), (210, 12, 210, 210, {"axis": "v", "range": 2}), (244, 14, 236, 249, {}),
        (322, 14, 317, 326, {}), (357, 16, 357, 357, {"axis": "v", "range": 2}), (482, 14, 477, 484, {}),
        (508, 14, 503, 510, {}), (580, 14, 572, 588, {})]]
    + [enemy("meteorito", x, y, a, b) for x, y, a, b in [
        (393, 17, 389, 408), (405, 17, 398, 409), (424, 18, 419, 428), (503, 18, 498, 510), (478, 17, 472, 484),
        (481, 17, 474, 484), (497, 18, 492, 510), (523, 19, 518, 530), (560, 19, 552, 570)]]
)

# IMP-001: uno por sección (o a <= 320 px de su entrada), ningún tramo > 2.500 px
checkpoints = [{"x": 126, "y": 19}, {"x": 163, "y": 19}, {"x": 265, "y": 16}, {"x": 419, "y": 18}, {"x": 540, "y": 19}]

signs = [
    {"x": 3, "y": 20, "text": "Mundo 6: ¡Sueños Cósmicos! Explora las islas del cielo con tus tres armas"},
    {"x": 28, "y": 20, "text": "La estrella sólida se pisa. La estrella con muelle es un trampolín"},
    {"x": 59, "y": 19, "text": "La Estrellita Fugaz vuela rápido y lanza miniestrellas"},
    {"x": 128, "y": 19, "text": "Las lunas crecientes forman un camino: ¡salta de una a otra!"},
    {"x": 161, "y": 19, "text": "El Cohetito Centinela enciende el motor antes de disparar"},
    {"x": 173, "y": 19, "text": "Métete en la cascada de luz dorada: te subirá hasta arriba"},
    {"x": 248, "y": 19, "text": "Sube al cohete: te lleva sobre el vacío"},
    {"x": 268, "y": 16, "text": "El tobogán arcoíris desliza rápido: las flechas frenan o aceleran un poco"},
    {"x": 297, "y": 20, "text": "La plataforma de lanzamiento te lanza muy alto: arriba hay un tesoro"},
    {"x": 369, "y": 21, "text": "El cohete ascensor sube y baja: espera a que llegue"},
    {"x": 389, "y": 17, "text": "¡Lluvia de meteoros! Las estrellas que caen avisan con un destello"},
    {"x": 408, "y": 17, "text": "Las nubes explosivas estallan si las tocas: ¡dispárales desde lejos!"},
    {"x": 533, "y": 19, "text": "El Trono de la Luna: Luna Estelar te espera"},
]

decor = []


def deco(x, y, frame, **kw):
    d = {"x": x, "y": y, "frame": frame}
    d.update(kw)
    decor.append(d)


# A — observatorios, telescopios, barandillas
for x, y, f, kw in [
    (7, 20, "obs_dome", {"back": True}), (15, 20, "telescope_tower", {"back": True}), (19, 20, "fence", {}),
    (11, 20, "star_post_a", {}), (29, 20, "lantern", {}), (34, 20, "globe", {}), (45, 18, "fence", {}),
    (49, 18, "hang_star_a", {}), (62, 19, "obs_dome2", {"back": True}), (70, 19, "small_telescope", {}),
    (74, 19, "star_post_b", {}), (82, 18, "tall_tower", {"back": True}), (88, 18, "fence", {}), (101, 19, "armillary", {}),
    (106, 19, "lantern", {}), (115, 19, "tower_small", {"back": True}), (121, 19, "fence", {}), (126, 19, "star_post_a", {}),
    # B — lunas, estrellas colgantes, cascadas de luz decorativas
    (143, 18, "hang_star_b", {}), (147, 18, "lantern", {}), (166, 19, "hang_star_c", {}), (172, 19, "star_post_b", {}),
    (182, 13, "telescope_tower", {"back": True}), (189, 13, "fence", {}), (207, 16, "small_dome", {"back": True}),
    (214, 16, "hang_star_a", {}), (220, 19, "lantern", {}), (235, 19, "obs_dome2", {"back": True}), (241, 19, "fence", {}),
    (246, 19, "star_post_a", {}),
    # C — planetas, globos y cúpulas
    (261, 16, "globe", {}), (265, 16, "pink_dome", {"back": True}), (289, 20, "armillary", {}), (294, 20, "gazebo", {}),
    (306, 20, "globe", {}), (318, 19, "pink_dome", {"back": True}), (324, 19, "small_telescope", {}), (332, 15, "tiny_tower", {}),
    (357, 21, "obs_dome_small", {"back": True}), (364, 21, "globe", {}), (369, 21, "lantern", {}), (379, 15, "armillary", {}),
    (384, 15, "star_post_b", {}),
    # D — rocas y meteoritos varados, estelas
    (391, 17, "meteor_l", {}), (399, 17, "meteor_s", {}), (408, 17, "meteor_m", {}), (421, 18, "lantern", {}),
    (427, 18, "meteor_l", {}), (433, 17, "meteor_m", {}), (449, 17, "meteor_s", {}), (466, 18, "tiny_tower", {}),
    (478, 17, "meteor_m", {}), (494, 18, "meteor_l", {}), (507, 18, "fence", {}), (520, 19, "meteor_m", {}),
    (528, 19, "star_post_a", {}),
    # E — palacio lunar
    (540, 19, "tower_island", {"back": True, "scale": 1.4}), (558, 19, "obs_dome", {"back": True, "scale": 1.5}),
    (566, 19, "telescope_tower", {"back": True, "scale": 1.4}), (572, 19, "tall_tower", {"back": True, "scale": 1.6}),
    (578, 19, "obs_dome2", {"back": True, "scale": 1.4}), (581, 19, "fence", {}), (585, 19, "lantern", {}),
    (550, 10, "star_post_a", {}), (535, 19, "star_post_b", {}),
]:
    deco(x, y, f, **kw)
# cascadas de luz decorativas: tenues, al fondo y sin chispas (no empujan)
for x in [22.5, 52.5, 131.5, 156, 193, 225.5, 255, 311, 371, 413, 437, 445, 461]:
    deco(x, 24, "light_fall_0", back=True, alpha=0.45)
# islotes de nube con roca colgante flotando en los huecos (decorado)
for x, y, f in [(24, 23, "islet_c"), (93, 24, "islet_g"), (135, 23, "islet_h"), (199, 23, "islet_f"), (279, 24, "islet_c"),
                (345, 24, "islet_h"), (412, 23, "islet_g"), (458, 24, "islet_e"), (513, 24, "islet_c")]:
    deco(x, y, f, back=True, alpha=0.8)
# primer plano: sólo piezas pequeñas y bajas para no tapar a Alice
for x, y, f in [(2, 20, "cloud_s"), (100, 19, "cloud_s"), (232, 19, "cloud_s"), (355, 21, "cloud_s"), (532, 19, "cloud_s"), (594, 19, "cloud_s")]:
    deco(x, y, f, front=True)

dream_names = {"moon_token": "Ficha de luna", "special": "Estrella especial", "constellation": "Fragmento de constelación", "rocket": "Mini cohete dorado"}

level = {
    "id": 6, "key": "world5", "name": "Sueños Cósmicos — Islas en el Cielo", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world5", "tileset": "world5_tiles", "objectsAtlas": "world5_objects", "backgroundAtlas": "world5_bg",
    "progress": {"total": TOTAL, "offset": 0, "scale": 1}, "playerStart": {"x": 4, "y": 20}, "nextScene": "Boss5",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w5", "signpost": "sign_w5", "star": ["world5_objects", "star_w5"]},
    "sections": [
        {"id": "A", "name": "El observatorio de las nubes", "from": 0},
        {"id": "B", "name": "El camino de la luna", "from": 2000},
        {"id": "C", "name": "Los jardines planetarios", "from": 4000},
        {"id": "D", "name": "La lluvia de meteoros", "from": 6200},
        {"id": "E", "name": "El trono de la Luna", "from": 8500},
    ],
    "background": background, "terrain": terrain, "slopes": slopes, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": [], "crumbles": [], "pads": pads,
    "winds": [], "hazards": [], "paints": [], "rollers": [], "bouncers": [], "drips": [], "rivers": [],
    "magicCrayons": [], "yarnRollers": [], "sleepClouds": [], "magicButtons": [],
    "rockets": rockets, "orbits": orbits, "slides": slides, "lightFalls": light_falls,
    "fallingStars": falling_stars, "explosiveClouds": explosive_clouds,
    "dreamCollectibles": dream, "dreamMain": "moon_token", "dreamNames": dream_names,
    "dreamBanner": "¡Las %d fichas de luna! Estrella extra", "dreamHud": ["world5_objects", "moon_token", "moon_"],
    "stars": stars, "enemies": enemies, "checkpoints": checkpoints, "pickups": [],
    "signs": signs, "decor": decor,
    "door": {"x": 590, "y": 19, "atlas": "world5_objects", "frame": "portal_w5", "scale": 1.0},
}

arena_bg = dict(background)
arena_bg["layers"] = [
    background["layers"][0], background["layers"][1],
    # la luna sonriente y el castillo quedan en el centro, detrás del combate
    {"scroll": [0.03, 0.03], "depth": 3, "items": [{"frame": "bg_moon_castle", "x": 240, "y": 88}]},
    background["layers"][3],
]

boss = {
    "key": "world5_boss", "worldId": 6, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world5", "bossMusic": "luna_estelar",
    "tileset": "world5_tiles", "objectsAtlas": "world5_objects", "backgroundAtlas": "world5_bg", "background": arena_bg,
    "frames": level["frames"], "progress": {"total": TOTAL, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "El trono de la Luna", "from": 8500}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3, "mat": "cosmic"}], "blocks": [],
    "clouds": [{"x": 15, "y": 10, "frame": "cloud_plat_l", "top": 1}, {"x": 44, "y": 10, "frame": "cloud_plat_l", "top": 1}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 8} for x in [14, 15, 16, 43, 44, 45]],
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [
        {"x": 3, "y": 14, "frame": "lantern"}, {"x": 9, "y": 14, "frame": "obs_dome2", "back": True},
        {"x": 21, "y": 14, "frame": "star_post_a"}, {"x": 29, "y": 14, "frame": "fence"}, {"x": 37, "y": 14, "frame": "star_post_b"},
        {"x": 50, "y": 14, "frame": "tall_tower", "back": True}, {"x": 55, "y": 14, "frame": "lantern"},
    ],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_star"}, "triggerX": 9,
    "boss": {"homeX": 34, "minX": 8, "maxX": 57, "floorY": 224, "frameBoth": True, "scene": "res://scenes/bosses/LunaEstelar.tscn",
             "name": "Luna Estelar", "introBanner": "¡Luna Estelar defiende el Trono de la Luna!",
             "defeatBanner": "¡Luna Estelar se duerme entre las nubes!", "portalToast": "El portal al Mundo 7 está preparado",
             "afterMusic": "world5"},
    "portal": {"x": 56, "y": 14},
}

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world5.json", level), ("world5_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 5: {len(stars)} estrellas, {len(enemies)} enemigos, ancho total {TOTAL} px")
