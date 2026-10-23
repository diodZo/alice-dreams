"""
Datos del MUNDO 6 — El Reino del Tren de Juguete (diseño del nivel).

Uso:  python tools/world6/world6_level.py
Escribe godot/data/world6/world6.json (nivel) y godot/data/world6/world6_boss.json (arena).

Mismo formato que los Mundos 2-5: x, y, w, h en TESELAS de 16 px; para objetos apoyados en el
suelo `y` es la fila de la superficie. Recorrido: 630 x 25 teselas (10.080 px) + arena (58)
= 11.008 px. El terreno usa el material "cloud" (bloques azules con nube rosada) del tileset.

Límites de Alice (data/tuning.json): salto ~62 px (3,9 teselas) de alto y ~7 teselas de largo
corriendo. Ningún escalón obligatorio supera 3 teselas sin ayuda (resortes, trenes, hélices);
ningún hueco obligatorio supera 5 teselas sin plataforma.

  A La Estación de los Sueños      0-1.800   estación, campana, tren lento de práctica (conducir),
                                              Bloquecito Travieso, plataformas con hélice
  B Los Puentes del Arcoíris    1.800-4.000   puente arcoíris, tren que sube una pendiente con
                                              la primera palanca (ramal opcional: billete 1),
                                              Payasitos Resorte, pasarelas estrechas, 1.er checkpoint
  C El Ferrocarril de las Nubes 4.000-6.300   trenes de velocidades distintas (marcha atrás),
                                              Vagoncitos, bloques móviles, ruta del cielo opcional
                                              (billete 2), tren con pasarela a mitad de camino
  D La Fábrica de Juguetes      6.300-8.600   bloques que caen, ruedas, resortes, hélices, segunda
                                              palanca, barreras de estrella, los tres enemigos,
                                              ruta alta (billete 3), 2.º checkpoint
  E La Gran Estación Real       8.600-11.000  gran estación, tren largo, tren enemigo entre
                                              túneles arcoíris y la arena de Locomostro
"""
import json
import math
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from level_schema import compact  # noqa: E402  (esquema común, IMP-015)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world6"
ROWS = 25
LEVEL_W = 630
ARENA_W = 58
TOTAL = (LEVEL_W + ARENA_W) * 16
MAT = "cloud"


def g(x, w, top=20):
    """Isla que llega hasta el fondo del mundo."""
    return {"x": x, "y": top, "w": w, "h": ROWS - top, "mat": MAT}


def island(x, w, top, h):
    """Isla flotante (se ve su base de bloques colgante)."""
    return {"x": x, "y": top, "w": w, "h": h, "mat": MAT}


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
    "sky": "w6_sky", "far": "w6_clouds_far", "near": "w6_clouds_near",
    "atlas": "world6_bg", "objectsAtlas": "world6_objects", "sparkles": True,
    "drifters": ["cloud_s", "cloud_m"],
    "layers": [
        # capa 2: el castillo rosado sobre su isla con cascadas (word_6.png) y globos aerostáticos
        {"scroll": [0.02, 0.02], "depth": 2, "items": [{"frame": "bg_castle_isle", "x": 300, "y": 96}, {"frame": "bg_balloon", "x": 84, "y": 52}]},
        {"scroll": [0.05, 0.03], "depth": 3, "frames": ["bg_castles", "bg_balloons"], "step": 330, "y": [70, 130], "alpha": 0.85, "bob": True},
        # capa 3: islas con árboles, cascadas entre nubes y arcoíris lejanos
        {"scroll": [0.12, 0.07], "depth": 4, "frames": ["bg_hills", "bg_falls", "bg_rainbow"], "step": 250, "y": [150, 178], "alpha": 0.85, "bob": True},
        # capa 4: viaductos ferroviarios lejanos
        {"scroll": [0.22, 0.12], "depth": 5, "frames": ["bg_viaduct"], "step": 420, "y": [176, 196], "alpha": 0.9},
        {"scroll": [0.3, 0.16], "depth": 6, "frames": ["bg_near_clouds"], "step": 300, "y": [212, 232], "alpha": 0.7},
    ],
}

terrain = [
    # A — La Estación de los Sueños
    g(0, 30, 20), g(44, 24, 20), g(79, 47, 19),
    # B — Los Puentes del Arcoíris
    g(138, 14, 19), island(176, 8, 18, 2), g(186, 20, 15), g(206, 1, 16), g(207, 13, 17), g(236, 24, 18),
    # C — El Ferrocarril de las Nubes
    island(279, 7, 18, 3), g(300, 14, 18), g(328, 20, 19),
    # D — La Fábrica de Juguetes
    g(386, 30, 19), g(416, 1, 20), g(417, 13, 21), g(430, 16, 17), island(457, 10, 22, 2), g(470, 22, 17),
    g(499, 18, 18), g(524, 13, 19),
    # E — La Gran Estación Real
    g(537, 23, 19), g(584, 46, 19),
]

slopes = [
    {"x": 206, "y": 15, "dir": "down", "mat": MAT}, {"x": 207, "y": 16, "dir": "down", "mat": MAT},
    {"x": 416, "y": 19, "dir": "down", "mat": MAT}, {"x": 417, "y": 20, "dir": "down", "mat": MAT},
]

# bloques de colores sueltos de la hoja (decoran los apoyos y la fábrica; son sólidos)
blocks = [
    {"x": 394, "y": 18, "type": "block_yellow"}, {"x": 395, "y": 18, "type": "block_blue"}, {"x": 394, "y": 17, "type": "block_red"},
    {"x": 426, "y": 20, "type": "block_green"}, {"x": 427, "y": 20, "type": "block_pink"},
    {"x": 491, "y": 16, "type": "block_blue_b"}, {"x": 629, "y": 18, "type": "block_yellow"}, {"x": 629, "y": 17, "type": "block_pink"},
]

# Plataformas unidireccionales (x = centro, y = superficie)
clouds = [
    # A: plataforma de estación elevada
    {"x": 100, "y": 16, "frame": "station_plat", "top": 7},
    # B: pasarelas estrechas de madera sobre el vacío
    {"x": 224, "y": 17, "frame": "wood_bridge_s", "top": 6}, {"x": 229, "y": 16, "frame": "wood_post", "top": 5},
    {"x": 233.5, "y": 17, "frame": "wood_bridge_s", "top": 6},
    # C: ruta del cielo (opcional, billete 2) y plataformas suspendidas
    {"x": 336, "y": 10, "frame": "cloud_plat_m", "top": 3}, {"x": 341, "y": 8, "frame": "cloud_plat_b", "top": 3},
    {"x": 346, "y": 8, "frame": "cloud_plat_l", "top": 3}, {"x": 352, "y": 11, "frame": "cloud_plat_c", "top": 3},
    {"x": 367, "y": 13, "frame": "wood_bridge_l", "top": 6},
    # D: estante de bloques sobre la meseta (ruta alta, billete 3)
    {"x": 436, "y": 13, "frame": "block_bridge", "top": 3}, {"x": 442, "y": 9, "frame": "cloud_plat_m", "top": 3},
    # E: andenes elevados de la gran estación
    {"x": 548, "y": 15, "frame": "station_plat", "top": 7}, {"x": 612, "y": 15, "frame": "wood_bridge_l", "top": 6},
]

movers = [
    {"x": 317, "y": 19, "frame": "block_bridge", "top": 3, "dx": 5, "dy": 0, "duration": 2600},      # 0: bloques móviles
    {"x": 519.5, "y": 18, "frame": "block_bridge", "top": 3, "dx": 2, "dy": 0, "duration": 2200},    # 1: pasarela móvil
]

# Trenes de juguete: vía (altura del carril), vagones y velocidad máxima / aceleración (px/s, px/s²).
# Los conduce Alice (IMP-029/IMP-035): cada tren espera parado al principio de su vía (la estación
# de salida) hasta que ella sube; con ARRIBA avanza hacia donde mira y al soltarlo frena. Si lo
# deja o se cae, el tren vuelve solo hasta ponerle un vagón al alcance (train_line.gd).
trains = [
    # 0 (A): tren lento de práctica sobre el primer hueco
    {"points": [[24, 20], [49, 20]], "cars": ["train_loco", "train_yellow"], "speed": 38, "accel": 30},
    # 1 (B): sube la pendiente; la primera palanca elige el ramal (A: isla principal; B: isla baja con billete 1)
    {"points": [[146, 19], [158, 19], [168, 15], [171, 15]], "branches": [[[171, 15], [190, 15]], [[171, 15], [177, 18], [184, 18]]],
     "cars": ["train_loco", "train_red", "train_star"], "speed": 50, "accel": 40},
    # 2 (C): tren lento hasta la isla de la campana
    {"points": [[256, 18], [280, 18]], "cars": ["train_loco", "train_red"], "speed": 46, "accel": 40},
    # 3 (C): tren rápido desde la isla de la campana
    {"points": [[283, 18], [303, 18]], "cars": ["train_loco", "train_star"], "speed": 84, "accel": 70},
    # 4 (C): vía larga con pendientes por el túnel arcoíris; se puede frenar bajo la pasarela (367)
    {"points": [[344, 19], [354, 19], [360, 15], [374, 15], [380, 19], [391, 19]], "cars": ["train_loco", "train_yellow", "train_red"],
     "speed": 68, "accel": 50},
    # 5 (D): segunda palanca (A: sigue a la derecha; B: baja a la isla de los bloques de estrella)
    {"points": [[442, 17], [453, 17]], "branches": [[[453, 17], [473, 17]], [[453, 17], [458, 22], [466, 22]]],
     "cars": ["train_loco", "train_star"], "speed": 56, "accel": 45},
    # 6 (E): el tren largo de la gran estación
    {"points": [[553, 19], [591, 19]], "cars": ["train_loco", "train_red", "train_yellow", "train_star"], "speed": 60, "accel": 40},
]

levers = [
    {"x": 143, "y": 19, "train": 1},
    {"x": 438, "y": 17, "train": 5},
]

bells = [
    {"x": 12, "y": 15, "train": -1, "gift": True},
    {"x": 282, "y": 16, "train": -1},
    {"x": 544, "y": 15, "train": -1, "gift": True},
]

# plataformas con hélice: fija, horizontal y vertical
helis = [
    {"x": 71, "y": 18},                                                   # A: fija
    {"x": 74.5, "y": 17, "variant": "b", "dx": 2.5, "duration": 2600},    # A: horizontal
    {"x": 331, "y": 18, "variant": "c", "dy": -7, "duration": 3600},     # C: vertical (ruta del cielo)
    {"x": 431, "y": 16, "variant": "c", "dy": -5, "duration": 3000},     # D: vertical (ruta alta, billete 3)
    {"x": 494, "y": 17, "variant": "b", "dx": 2.5, "duration": 2200},     # D: horizontal
]

rainbow_arches = [
    {"x0": 126, "x1": 138, "y": 19, "h": 2},
    # E: ruta alta y segura por encima del tren enemigo (empieza una tesela sobre el suelo:
    # por debajo se puede seguir andando por la vía)
    {"x0": 592, "x1": 608, "y": 18, "h": 3},
]

falling_blocks = [
    {"x": 404, "y": 12, "ground": 19, "frame": "fall_block_orange"},
    {"x": 409, "y": 12, "ground": 19, "frame": "fall_block_blue"},
    {"x": 508, "y": 11, "ground": 18, "frame": "fall_block_orange"},
    {"x": 512, "y": 11, "ground": 18, "frame": "fall_block_blue"},
]

rolling_wheels = [
    {"points": [[427, 21], [418, 21]], "speed": 62, "frame": "wheel_l", "mode": "loop"},
    {"points": [[427, 21], [418, 21]], "speed": 62, "frame": "wheel_s", "mode": "loop", "delay": 1300},
    {"points": [[503, 18], [516, 18]], "speed": 50, "frame": "wheel_l", "mode": "pingpong"},
]

bumpers = [{"x": 486, "y": 17}, {"x": 557, "y": 19}]

hazard_trains = [
    {"x0": 596, "x1": 604, "y": 19, "period": 6200, "speed": 190, "dir": 1, "delay": 0},
]

hazards = [
    # hélices giratorias peligrosas (configuradas explícitamente como obstáculo)
    {"x": 479, "y": 10, "frame": "heli_hazard", "dy": 2, "duration": 1300, "spin": True},
    {"x": 532, "y": 15, "frame": "heli_hazard_b", "dx": 2, "duration": 1500, "spin": True},
]

# resortes de juguete (BouncePad que se pisa por arriba)
pads = [
    {"x": 182, "y": 18, "frame": "toy_spring", "power": -470, "surface": "top"},   # isla baja -> isla principal
    {"x": 429, "y": 21, "frame": "toy_spring", "power": -480, "surface": "top"},   # sube a la meseta de la fábrica
    {"x": 464, "y": 22, "frame": "toy_spring", "power": -480, "surface": "top"},   # isla de los bloques -> camino
]

star_blocks = [
    {"x": 52, "y": 16, "count": 2}, {"x": 53, "y": 16, "count": 1}, {"x": 54, "y": 16, "count": 2},
    # isla baja del segundo desvío (suelo en la fila 22), justo bajo el ramal A: lejos de la bajada
    # del ramal B para que Alice, de pie en el vagón, no se dé con la cabeza (IMP-029)
    {"x": 460, "y": 17, "count": 2}, {"x": 462, "y": 17, "count": 3},
    {"x": 541, "y": 15, "count": 2},
    # IMP-035: sobre las vías de la sección C (trenes 256-280 y 283-303, vía en la fila 18): de pie
    # en el vagón no se tocan; saltando se golpean desde abajo. Saltar en marcha es seguro: Alice
    # conserva la velocidad del tren en el aire (player.gd -> carry_x)
    {"x": 266, "y": 12, "count": 2}, {"x": 272, "y": 12, "count": 2},
    {"x": 292, "y": 12, "count": 2}, {"x": 297, "y": 12, "count": 2},
]

dream = [
    {"id": "ticket_1", "kind": "ticket", "x": 179, "y": 16, "frame": "ticket"},
    {"id": "ticket_2", "kind": "ticket", "x": 346, "y": 5, "frame": "ticket"},
    {"id": "ticket_3", "kind": "ticket", "x": 442, "y": 6, "frame": "ticket"},
]

stars = (
    # A
    row(3, 22, 19, 3) + row(31, 42, 17, 3) + row(45, 50, 19, 3) + row(52, 54, 14, 1) + row(56, 66, 19, 3)
    + arc(69, 79, 15, 2, 2) + row(83, 96, 18, 3) + row(98, 102, 14, 2) + row(104, 124, 18, 3)
    # B
    + arc(126, 138, 16, 2, 2) + row(140, 150, 18, 3) + arc(152, 170, 15, 3, 3) + row(177, 183, 17, 2)
    + row(188, 204, 14, 3) + row(208, 218, 16, 3) + row(222, 235, 15, 2) + row(238, 258, 17, 3)
    # C
    + arc(261, 278, 15, 2, 3) + row(280, 285, 17, 2) + arc(287, 299, 15, 2, 3) + row(302, 312, 17, 3)
    + column(331, 9, 15) + row(336, 352, 6, 3) + row(316, 326, 16, 3) + row(329, 346, 18, 3)
    + arc(348, 364, 12, 2, 3) + row(366, 369, 11, 1) + arc(372, 390, 12, 2, 3)
    # D
    + row(392, 414, 18, 3) + row(418, 426, 20, 3) + row(431, 444, 16, 3) + row(434, 438, 11, 2) + row(441, 443, 7, 1)
    + arc(447, 469, 14, 2, 3) + row(458, 465, 20, 2) + row(472, 490, 16, 3) + arc(492, 499, 15, 2, 2)
    + row(501, 516, 17, 3) + row(518, 522, 16, 2) + row(526, 536, 18, 3)
    # E
    + row(539, 558, 18, 3) + row(546, 550, 13, 2) + arc(560, 584, 15, 3, 3) + row(586, 595, 18, 3)
    + row(597, 603, 15, 2) + row(608, 616, 18, 3) + row(611, 614, 13, 1) + row(618, 624, 18, 2)
)

enemies = (
    [enemy("bloquecito", x, y, a, b) for x, y, a, b in [
        (58, 20, 50, 66), (96, 19, 90, 110), (101, 19, 91, 110),
        (244, 18, 238, 251), (411, 19, 401, 415), (476, 17, 472, 482), (484, 17, 474, 490),
        (592, 19, 586, 594), (612, 19, 608, 620)]]
    + [enemy("payasito", x, y, x, x) for x, y in [
        (195, 15), (200, 15), (241, 18), (330, 19), (506, 18), (514, 18), (540, 19)]]
    + [enemy("vagoncito", x, y, a, b) for x, y, a, b in [
        (307, 18, 302, 311), (336, 19, 333, 339), (433, 17, 431, 437), (530, 19, 525, 536)]]
)

# IMP-011: corazones recogibles (una vida si falta alguna) al terminar los tramos con más enemigos
hearts = [{"x": 212, "y": 16, "atlas": "fx", "frame": "heart_full", "scale": 1.5}, {"x": 438, "y": 16, "atlas": "fx", "frame": "heart_full", "scale": 1.5}, {"x": 525, "y": 18, "atlas": "fx", "frame": "heart_full", "scale": 1.5}]

# IMP-001: uno por sección (o a <= 320 px de su entrada) y ningún tramo > 2.500 px; los de las
# teselas 254 y 548 quedan justo antes de subir a los trenes de las secciones C y E
checkpoints = [{"x": 118, "y": 19}, {"x": 254, "y": 18}, {"x": 398, "y": 19}, {"x": 548, "y": 19}]

signs = [
    {"x": 3, "y": 20, "text": "Mundo 5: ¡El Reino del Tren de Juguete! Viaja en los trenes mágicos entre las nubes"},
    {"x": 9, "y": 20, "text": "Toca la campana de la estación: ¡Din don!"},
    {"x": 21, "y": 20, "text": "¡Conduce el tren! Súbete y mantén ARRIBA (^, W o cruceta): va hacia donde miras. Suelta y frena"},
    {"x": 46, "y": 20, "text": "Golpea los bloques de estrella desde abajo: ¡sueltan estrellas!"},
    {"x": 66, "y": 20, "text": "Las plataformas con hélice flotan. Sus hélices no hacen daño"},
    {"x": 120, "y": 19, "text": "El puente arcoíris une las islas: ¡crúzalo!"},
    {"x": 141, "y": 19, "text": "Toca la palanca para cambiar el desvío antes de cruzarlo con el tren"},
    {"x": 189, "y": 15, "text": "El Payasito Resorte salta de su caja y lanza estrellas: ¡apártate!"},
    {"x": 238, "y": 18, "text": "Hay tres billetes dorados escondidos en el reino"},
    {"x": 279, "y": 18, "text": "Mira atrás y mantén ARRIBA: el tren va marcha atrás. Si lo dejas, vuelve a buscarte"},
    {"x": 302, "y": 18, "text": "El Vagoncito Chispa lanza chispas y suelta humo. El humo no hace daño"},
    {"x": 329, "y": 19, "text": "La hélice que sube lleva a la ruta del cielo"},
    {"x": 342, "y": 19, "text": "Frena el tren bajo la pasarela del túnel: ¡hay estrellas!"},
    {"x": 392, "y": 19, "text": "La Fábrica de Juguetes: los bloques tiemblan antes de caer"},
    {"x": 419, "y": 21, "text": "Las ruedas ruedan siempre igual: ¡sáltalas! El resorte te sube a la meseta"},
    {"x": 472, "y": 17, "text": "Las barreras de estrella te empujan sin hacer daño"},
    {"x": 586, "y": 19, "text": "¡Cuidado! Cuando la señal se pone roja y suena el silbato, sale un tren del túnel"},
    {"x": 620, "y": 19, "text": "La Gran Estación Real: Locomostro te espera"},
]

decor = []


def deco(x, y, frame, **kw):
    d = {"x": x, "y": y, "frame": frame}
    d.update(kw)
    decor.append(d)


for x, y, f, kw in [
    # A — estación de madera, campana, señales, bloques, trenes decorativos
    (6, 20, "station_house", {"back": True}), (14, 20, "station_bell", {"back": True}), (12, 20, "bell_post", {"back": True}),
    (18, 20, "toy_train_big", {"back": True}), (25, 20, "sign_arrow", {}), (1, 20, "tree_green", {}), (28, 20, "tree_blue", {}),
    (27, 20, "fence_w6", {"back": True}), (36, 25, "wood_trestle", {"back": True}), (42, 25, "wood_trestle", {"back": True}),
    (47, 20, "bush_flowers", {}), (60, 20, "deco_blocks", {"back": True}), (64, 20, "pennants", {}), (67, 20, "tree_blue_b", {}),
    (83, 19, "sign_dir", {}), (88, 19, "tree_green_b", {}), (93, 19, "bush_b", {}), (100, 19, "station_fence", {"back": True}),
    (106, 19, "castle_pair", {"back": True, "scale": 1.2}), (112, 19, "pennants", {}), (116, 19, "bush_flowers", {}),
    # B — puentes, cascadas, arcoíris
    (123, 19, "tree_blue", {}), (140, 19, "fence_w6", {}), (149, 19, "sign_star", {}), (162, 25, "wood_trestle", {"back": True}),
    (166, 24, "wood_trestle", {"back": True}), (186, 15, "tree_green", {}), (190, 15, "deco_blocks", {"back": True}),
    (203, 15, "bush_b", {}), (212, 17, "tree_blue_b", {}), (217, 17, "pennants", {}), (229, 23, "wood_post", {"back": True}),
    (246, 18, "castle_pair", {"back": True}), (252, 18, "station_bell", {"back": True}), (257, 18, "sign_dir", {}),
    # C — estaciones en las nubes, túnel arcoíris
    (283, 18, "station_house", {"back": True}), (285, 18, "tree_green_b", {}), (305, 18, "station_fence", {"back": True}),
    (311, 18, "rainbow_tunnel", {"back": True}), (330, 19, "bush_flowers", {}), (345, 19, "deco_blocks", {"back": True}),
    (367, 16, "rainbow_tunnel", {"back": True, "scale": 1.5}), (358, 25, "wood_trestle", {"back": True}), (377, 25, "wood_trestle", {"back": True}),
    # D — fábrica: bloques gigantes, ruedas, cajas
    (392, 19, "deco_blocks", {"back": True, "scale": 1.6}), (400, 19, "wheel_deco", {}), (413, 19, "deco_blocks", {"back": True}),
    (421, 21, "wheel_deco", {"back": True}), (432, 17, "deco_blocks", {"back": True, "scale": 1.3}), (445, 17, "wheel_deco", {}),
    (474, 17, "deco_blocks", {"back": True, "scale": 1.5}), (481, 17, "wheel_deco", {"back": True}), (489, 17, "deco_blocks", {"back": True}),
    (502, 18, "deco_blocks", {"back": True, "scale": 1.4}), (516, 18, "wheel_deco", {}), (527, 19, "sign_arrow", {}),
    (534, 19, "deco_blocks", {"back": True}),
    # E — gran estación real
    (539, 19, "castle_pair", {"back": True, "scale": 1.5}), (544, 19, "bell_post", {"back": True}), (548, 19, "station_house", {"back": True, "scale": 1.3}),
    (554, 19, "pennants", {}), (557, 19, "tree_blue", {}), (586, 19, "station_fence", {"back": True}), (590, 19, "tree_green", {}),
    (610, 19, "pennants", {}), (616, 19, "castle_pair", {"back": True, "scale": 1.6}), (622, 19, "rainbow_tunnel", {"back": True, "scale": 1.7}),
    (627, 19, "pennants", {}), (566, 25, "wood_trestle", {"back": True}), (578, 25, "wood_trestle", {"back": True}),
]:
    deco(x, y, f, **kw)
# conos de las islas flotantes y casitas de nube en los huecos (decorado lejano)
for x, y, f in [(37, 24, "isle_cone_a"), (74, 24, "mini_isle"), (131, 24, "isle_cone_b"), (162, 22, "tiny_isle"),
                (180, 23, "isle_cone_c"), (228, 24, "mini_isle"), (268, 24, "isle_cone_a"), (292, 24, "isle_cone_b"),
                (322, 24, "mini_isle"), (362, 24, "isle_cone_c"), (461, 25, "isle_cone_b"), (496, 24, "tiny_isle"),
                (520, 24, "mini_isle"), (572, 24, "isle_cone_a")]:
    deco(x, y, f, back=True, alpha=0.85)
# primer plano: sólo piezas pequeñas y bajas para no tapar a Alice ni los obstáculos
for x, y, f in [(2, 20, "cloud_s"), (85, 19, "bush_s"), (189, 15, "bush_s"), (302, 18, "cloud_s"), (393, 19, "bush_s"),
                (538, 19, "cloud_s"), (626, 19, "bush_s")]:
    deco(x, y, f, front=True)

dream_names = {"ticket": "Billete mágico"}

level = {
    "id": 5, "key": "world6", "name": "El Reino del Tren de Juguete", "widthTiles": LEVEL_W, "heightTiles": ROWS,
    "music": "world6", "tileset": "world6_tiles", "objectsAtlas": "world6_objects", "backgroundAtlas": "world6_bg",
    "progress": {"total": TOTAL, "offset": 0, "scale": 1}, "playerStart": {"x": 4, "y": 20}, "nextScene": "Boss6",
    "startWeapons": ["bubble", "paint", "sling"],
    "frames": {"flag": "flag_w6", "signpost": "sign_w6", "star": ["world6_objects", "star_w6"]},
    "sections": [
        {"id": "A", "name": "La Estación de los Sueños", "from": 0},
        {"id": "B", "name": "Los Puentes del Arcoíris", "from": 1800},
        {"id": "C", "name": "El Ferrocarril de las Nubes", "from": 4000},
        {"id": "D", "name": "La Fábrica de Juguetes", "from": 6300},
        {"id": "E", "name": "La Gran Estación Real", "from": 8600},
    ],
    "background": background, "terrain": terrain, "slopes": slopes, "blocks": blocks, "clouds": clouds,
    "bridges": [], "rulers": [], "movers": movers, "swings": [], "crumbles": [], "pads": pads,
    "winds": [], "hazards": hazards, "paints": [], "rollers": [], "bouncers": [], "drips": [], "rivers": [],
    "magicCrayons": [], "yarnRollers": [], "sleepClouds": [], "magicButtons": [],
    "trains": trains, "levers": levers, "bells": bells, "helis": helis, "rainbowArches": rainbow_arches,
    "fallingBlocks": falling_blocks, "rollingWheels": rolling_wheels, "bumpers": bumpers, "hazardTrains": hazard_trains,
    "starBlocks": star_blocks,
    "dreamCollectibles": dream, "dreamMain": "ticket", "dreamNames": dream_names,
    "dreamBanner": "¡Los %d billetes mágicos! Estrella extra", "dreamHud": ["world6_objects", "ticket", "ticket_"],
    "stars": [], "enemies": enemies, "checkpoints": checkpoints, "pickups": [], "hearts": hearts,
    "signs": signs, "decor": decor,
    "door": {"x": 626, "y": 19, "atlas": "world6_objects", "frame": "portal_w6", "scale": 1.0},
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
    assert GRID[e["y"]][e["x"]] and not GRID[e["y"] - 1][e["x"]], f"enemigo sin suelo libre: {e}"
for c in checkpoints:
    assert GRID[c["y"]][c["x"]] and not GRID[c["y"] - 1][c["x"]], f"checkpoint sin suelo: {c}"
for d in dream:
    assert not GRID[d["y"]][d["x"]], f"billete dentro del terreno: {d}"

arena_bg = dict(background)
arena_bg["layers"] = [
    background["layers"][0],
    {"scroll": [0.03, 0.03], "depth": 3, "items": [{"frame": "bg_castles", "x": 120, "y": 120}, {"frame": "bg_castles", "x": 380, "y": 116}]},
    background["layers"][2], background["layers"][3],
]

boss = {
    "key": "world6_boss", "worldId": 5, "widthTiles": ARENA_W, "heightTiles": 17, "music": "world6", "bossMusic": "locomostro",
    "tileset": "world6_tiles", "objectsAtlas": "world6_objects", "backgroundAtlas": "world6_bg", "background": arena_bg,
    "frames": level["frames"], "progress": {"total": TOTAL, "offset": LEVEL_W * 16, "scale": 1}, "playerStart": {"x": 2, "y": 14},
    "sections": [{"id": "E", "name": "La Gran Estación Real", "from": 8600}],
    "terrain": [{"x": 0, "y": 14, "w": ARENA_W, "h": 3, "mat": MAT}], "blocks": [],
    # nubes a 3 teselas del suelo: más altas que el cuerpo de Locomostro (se esquiva la embestida)
    "clouds": [{"x": 13, "y": 11, "frame": "cloud_plat_l", "top": 3}, {"x": 29, "y": 10, "frame": "cloud_plat_m", "top": 3},
               {"x": 45, "y": 11, "frame": "cloud_plat_l", "top": 3}],
    "bridges": [], "rulers": [], "movers": [], "swings": [], "crumbles": [], "pads": [], "winds": [], "hazards": [],
    "stars": [{"x": x, "y": 8} for x in [12, 13, 14, 28, 29, 30, 44, 45, 46]],
    "enemies": [], "checkpoints": [], "pickups": [], "signs": [],
    "decor": [
        {"x": 3, "y": 14, "frame": "pennants"}, {"x": 8, "y": 14, "frame": "station_house", "back": True},
        {"x": 20, "y": 14, "frame": "rainbow_tunnel", "back": True, "scale": 1.6}, {"x": 29, "y": 14, "frame": "station_plat", "back": True},
        {"x": 38, "y": 14, "frame": "rainbow_tunnel", "back": True, "scale": 1.6}, {"x": 50, "y": 14, "frame": "castle_pair", "back": True, "scale": 1.3},
        {"x": 55, "y": 14, "frame": "pennants"}, {"x": 25, "y": 14, "frame": "sign_star"}, {"x": 33, "y": 14, "frame": "wheel_deco"},
    ],
    "gate": {"x": 5, "rows": [10, 11, 12, 13], "tile": "block_red"}, "triggerX": 9,
    "boss": {"homeX": 40, "minX": 6, "maxX": 57, "floorY": 224, "frameBoth": True, "scene": "res://scenes/bosses/Locomostro.tscn",
             "name": "Locomostro", "introBanner": "¡Locomostro llega a la Gran Estación Real!",
             "defeatBanner": "¡Locomostro se queda dormido!", "portalToast": "El portal al Mundo 6 está preparado",
             "afterMusic": "world6_victory"},
    "portal": {"x": 54, "y": 14},
}

OUT.mkdir(parents=True, exist_ok=True)
for name, data in [("world6.json", level), ("world6_boss.json", boss)]:
    (OUT / name).write_text(json.dumps(compact(data), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"Mundo 6: {len(level['stars'])} estrellas, {len(enemies)} enemigos, {len(trains)} trenes, ancho total {TOTAL} px")
