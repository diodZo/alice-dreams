"""
Definición de las fuentes gráficas del Mundo 1.

Las hojas de referencia de /imagenes NO son spritesheets técnicos: los dibujos
no están alineados en una cuadrícula y tienen fondos (blanco, gris o un halo
semitransparente).  Por eso cada fotograma se describe aquí con su caja
(x0, y0, x1, y1) en coordenadas de la imagen original.  Las cajas se obtuvieron
etiquetando componentes conectados (ver `python tools/prepare_assets.py --debug`,
que dibuja las cajas detectadas sobre cada hoja).

Modos de fondo:
  white -> fondo casi blanco plano (Player.png, enemies.png)
  grey  -> paneles grises de la hoja de teselas
  alpha -> la imagen ya trae canal alfa (boss_worl_1.png), con halo que se recorta
"""

SRC = {
    "player": "imagenes/Player.png",
    "enemies": "imagenes/enemies.png",
    "boss": "imagenes/boss_worl_1.png",
    "tiles": "imagenes/Teselas pixel art del cielo de dulces.png",
}

# ---------------------------------------------------------------------------
# Personajes (fotogramas de tamaño uniforme, anclados por los pies)
# ---------------------------------------------------------------------------
CHARACTERS = {
    "player": {
        "src": "player", "mode": "white", "scale": 0.19, "anchor": "feet",
        "shadow": True, "colors": 40,
        "anims": {
            "idle": {"fps": 6, "repeat": -1, "boxes": [
                (13, 58, 113, 257), (124, 58, 223, 257), (234, 58, 333, 257), (346, 55, 444, 257)]},
            "blink": {"fps": 6, "repeat": 0, "boxes": [(455, 55, 571, 256)]},
            "walk": {"fps": 10, "repeat": -1, "boxes": [
                (588, 64, 716, 257), (726, 64, 863, 257), (878, 58, 1019, 257),
                (1023, 61, 1155, 257), (1160, 61, 1283, 257), (1291, 58, 1428, 257)]},
            "jump": {"fps": 8, "repeat": 0, "boxes": [(21, 330, 180, 526), (196, 319, 355, 508)]},
            "hurt": {"fps": 8, "repeat": 0, "boxes": [(408, 335, 575, 540), (594, 376, 745, 540)]},
            "victory": {"fps": 4, "repeat": -1, "boxes": [
                (817, 327, 980, 543), (997, 332, 1154, 543), (1218, 316, 1365, 543)]},
            "bubble": {"fps": 16, "repeat": 0, "boxes": [
                (13, 613, 150, 798), (161, 619, 310, 798), (320, 619, 468, 798), (576, 609, 726, 798)]},
            "paint": {"fps": 14, "repeat": 0, "boxes": [
                (747, 616, 908, 801), (917, 616, 1078, 801), (1126, 611, 1271, 801), (1285, 610, 1428, 801)]},
            "sling": {"fps": 12, "repeat": 0, "boxes": [
                (13, 869, 158, 1056), (178, 869, 337, 1056), (351, 869, 514, 1056), (575, 866, 727, 1056)]},
        },
        # Animaciones derivadas (reutilizan fotogramas existentes; la hoja no las trae)
        "derived": {
            "run": {"from": "walk", "fps": 15, "repeat": -1},
            "fall": {"frames": [("jump", 1), ("jump", 0)], "fps": 6, "repeat": -1},
        },
    },
    "scratch": {
        "src": "enemies", "mode": "white", "scale": 0.2, "anchor": "feet", "shadow": True, "colors": 24,
        "anims": {
            "idle": {"fps": 5, "repeat": -1, "boxes": [
                (25, 84, 149, 201), (154, 82, 284, 200), (294, 84, 423, 200), (438, 82, 568, 196)]},
            "walk": {"fps": 8, "repeat": -1, "boxes": [
                (611, 79, 733, 200), (749, 83, 854, 200), (876, 82, 984, 201), (1005, 82, 1120, 201)]},
            "attack": {"fps": 10, "repeat": 0, "boxes": [
                (25, 251, 155, 375), (160, 250, 305, 372), (310, 250, 462, 372), (535, 252, 694, 373)]},
            "hurt": {"fps": 8, "repeat": 0, "boxes": [(726, 251, 852, 375), (870, 275, 989, 376)]},
            "defeated": {"fps": 4, "repeat": 0, "boxes": [(1056, 268, 1197, 375), (1211, 312, 1402, 374)]},
        },
    },
    "spit": {
        "src": "enemies", "mode": "white", "scale": 0.2, "anchor": "feet", "shadow": True, "colors": 24,
        "anims": {
            "idle": {"fps": 5, "repeat": -1, "boxes": [
                (23, 474, 153, 590), (169, 474, 294, 590), (309, 473, 440, 589), (455, 468, 579, 589)]},
            "walk": {"fps": 8, "repeat": -1, "boxes": [
                (623, 468, 735, 592), (755, 472, 865, 592), (891, 468, 1001, 592), (1030, 466, 1151, 592)]},
            # La hoja sólo tiene 3 poses de escupir distintas: la segunda se repite.
            "attack": {"fps": 8, "repeat": 0, "boxes": [
                (26, 641, 148, 753), (167, 639, 300, 754), (167, 639, 300, 754), (504, 641, 632, 752)]},
            "hurt": {"fps": 8, "repeat": 0, "boxes": [(666, 639, 777, 753), (782, 667, 890, 756)]},
            "defeated": {"fps": 4, "repeat": 0, "boxes": [(919, 665, 1019, 754), (1026, 693, 1166, 754)]},
        },
    },
    "flea": {
        "src": "enemies", "mode": "white", "scale": 0.2, "anchor": "feet", "shadow": True, "colors": 24,
        "anims": {
            "idle": {"fps": 5, "repeat": -1, "boxes": [
                (32, 832, 148, 939), (172, 832, 287, 939), (310, 830, 427, 940), (449, 827, 566, 941)]},
            "walk": {"fps": 8, "repeat": -1, "boxes": [
                (607, 836, 708, 941), (741, 834, 844, 941), (877, 829, 990, 941), (1016, 825, 1125, 942)]},
            "attack": {"fps": 9, "repeat": 0, "boxes": [
                (38, 976, 142, 1072), (174, 976, 284, 1071), (302, 975, 404, 1072), (529, 976, 627, 1071)]},
            "hurt": {"fps": 8, "repeat": 0, "boxes": [(670, 975, 771, 1073), (782, 986, 888, 1072)]},
            "defeated": {"fps": 4, "repeat": 0, "boxes": [(923, 996, 1031, 1072), (1041, 1011, 1161, 1071)]},
        },
    },
    "nubarron": {
        "src": "boss", "mode": "alpha", "scale": 0.42, "anchor": "center", "colors": 40,
        "anims": {
            "idle": {"fps": 5, "repeat": -1, "boxes": [
                (55, 9, 287, 182), (308, 9, 530, 182), (557, 9, 789, 182), (813, 9, 1051, 181)]},
            "move": {"fps": 8, "repeat": -1, "boxes": [
                (38, 193, 267, 359), (283, 194, 489, 356), (505, 198, 717, 353),
                (734, 194, 950, 357), (965, 197, 1183, 352), (1207, 197, 1428, 354)]},
            # Los fotogramas 3 y 4 de soplido incluyen la ráfaga: se recorta sólo el cuerpo.
            "blow": {"fps": 6, "repeat": 0, "boxes": [
                (57, 364, 270, 521), (288, 367, 536, 518), (563, 368, 785, 522), (926, 369, 1150, 526)]},
            "shoot": {"fps": 7, "repeat": 0, "boxes": [
                (48, 529, 272, 683), (299, 530, 536, 683), (555, 534, 765, 681), (946, 537, 1179, 686)]},
            "storm": {"fps": 7, "repeat": -1, "boxes": [
                (34, 700, 328, 874), (360, 708, 695, 892), (696, 695, 1013, 887), (1030, 694, 1424, 887)]},
            "hurt": {"fps": 8, "repeat": 0, "boxes": [(43, 895, 276, 1061), (291, 899, 534, 1065)]},
            "defeated": {"fps": 3, "repeat": 0, "boxes": [(577, 901, 810, 1058), (919, 899, 1163, 1056)]},
        },
    },
}

# ---------------------------------------------------------------------------
# Imágenes sueltas empaquetadas en atlas: (src, mode, box, scale, opciones)
# opciones: keep -> proporción mínima de área para conservar islas secundarias
#           size -> forzar tamaño exacto (w, h)
# ---------------------------------------------------------------------------
FX = {
    # proyectiles y efectos de la protagonista
    "bubble": ("player", "white", (521, 621, 580, 680), 0.25, {}),
    "paint_splash": ("player", "white", (1078, 655, 1124, 718), 0.3, {}),
    "pellet": ("player", "white", (546, 924, 573, 950), 0.3, {}),
    "icon_bubble": ("player", "white", (803, 897, 898, 1000), 0.2, {}),
    "icon_paint": ("player", "white", (931, 907, 1043, 996), 0.2, {}),
    "icon_sling": ("player", "white", (1091, 906, 1183, 1000), 0.2, {}),
    # proyectiles enemigos
    "slash": ("enemies", "white", (1222, 463, 1313, 534), 0.28, {"keep": 0.05}),
    "spit_blob": ("enemies", "white", (1222, 549, 1276, 615), 0.22, {}),
    "flea_bug": ("enemies", "white", (1238, 637, 1307, 698), 0.22, {"keep": 0.05}),
    # jefe
    "wind": ("boss", "alpha", (788, 385, 909, 520), 0.32, {"keep": 0.05}),
    "cloudball": ("boss", "alpha", (1360, 594, 1427, 654), 0.3, {}),
    "star_gold": ("tiles", "grey", (1327, 439, 1384, 498), 0.3, {}),
    "sparkle": ("tiles", "grey", (1297, 499, 1335, 539), 0.25, {}),
}

OBJECTS = {
    # terreno decorativo / plataformas de nube (colisión unidireccional)
    "cloud_small": ("tiles", "grey", (834, 63, 919, 120), 0.42, {}),
    "cloud_long": ("tiles", "grey", (929, 59, 1112, 121), 0.42, {}),
    "cloud_med": ("tiles", "grey", (834, 137, 953, 196), 0.42, {}),
    "cloud_face": ("tiles", "grey", (834, 211, 997, 281), 0.42, {}),
    "cloud_face_small": ("tiles", "grey", (834, 296, 953, 358), 0.42, {}),
    "cloud_face_long": ("tiles", "grey", (962, 292, 1112, 361), 0.42, {}),
    "cloud_puff": ("tiles", "grey", (1014, 218, 1112, 269), 0.42, {}),
    # puente arcoíris: tramo central repetible + extremos de nube
    "rainbow_mid": ("tiles", "grey", (1192, 66, 1262, 113), 0.34, {"nocomp": True}),
    "rainbow_cap_l": ("tiles", "grey", (1138, 62, 1190, 117), 0.34, {"nocomp": True}),
    "rainbow_cap_r": ("tiles", "grey", (1264, 62, 1315, 117), 0.34, {"nocomp": True}),
    "rainbow_arc_l": ("tiles", "grey", (1148, 133, 1287, 248), 0.3, {}),
    "rainbow_arc_r": ("tiles", "grey", (1312, 133, 1432, 247), 0.3, {}),
    # elementos interactivos
    "jump_pad": ("tiles", "grey", (730, 513, 788, 556), 0.34, {}),
    "spiky_bubble": ("tiles", "grey", (959, 498, 1020, 561), 0.3, {}),
    "hazard_bubble": ("tiles", "grey", (817, 425, 875, 483), 0.3, {}),
    "bumper_pink": ("tiles", "grey", (1069, 502, 1148, 561), 0.3, {}),
    "bumper_blue": ("tiles", "grey", (1174, 497, 1254, 561), 0.3, {}),
    "flag": ("tiles", "grey", (1124, 612, 1277, 776), 0.3, {}),
    "signpost": ("tiles", "grey", (1311, 631, 1428, 776), 0.26, {}),
    # decoración
    "tree_big": ("tiles", "grey", (16, 611, 162, 772), 0.42, {}),
    "tree_med": ("tiles", "grey", (164, 615, 285, 772), 0.42, {}),
    "tree_small": ("tiles", "grey", (260, 653, 365, 773), 0.42, {}),
    "fence_long": ("tiles", "grey", (386, 619, 509, 666), 0.3, {}),
    "fence_med": ("tiles", "grey", (386, 684, 508, 727), 0.3, {}),
    "fence_short": ("tiles", "grey", (402, 733, 495, 773), 0.3, {}),
    "flowers_a": ("tiles", "grey", (538, 619, 598, 656), 0.3, {}),
    "flowers_b": ("tiles", "grey", (615, 617, 687, 656), 0.3, {}),
    "bush_a": ("tiles", "grey", (535, 664, 626, 712), 0.3, {}),
    "bush_b": ("tiles", "grey", (641, 666, 698, 711), 0.3, {}),
    "bush_c": ("tiles", "grey", (532, 721, 620, 770), 0.3, {}),
    "bush_eggs": ("tiles", "grey", (628, 722, 702, 769), 0.3, {}),
    "lollipop_pink": ("tiles", "grey", (723, 617, 808, 770), 0.3, {}),
    "lollipops": ("tiles", "grey", (801, 624, 908, 769), 0.3, {}),
    "pinwheel_big": ("tiles", "grey", (940, 617, 1043, 769), 0.32, {}),
    "pinwheel_small": ("tiles", "grey", (1037, 669, 1095, 769), 0.32, {}),
    "waterfall_big": ("tiles", "grey", (16, 828, 145, 1069), 0.36, {"keep": 0.02}),
    "waterfall_a": ("tiles", "grey", (150, 827, 211, 1069), 0.36, {}),
    "waterfall_b": ("tiles", "grey", (217, 827, 279, 1069), 0.36, {}),
    "egg_pink": ("tiles", "grey", (737, 830, 808, 903), 0.26, {}),
    "egg_blue": ("tiles", "grey", (816, 846, 868, 903), 0.26, {}),
    "egg_yellow": ("tiles", "grey", (872, 846, 914, 900), 0.26, {}),
    "egg_purple": ("tiles", "grey", (918, 830, 959, 901), 0.26, {}),
    "crystals": ("tiles", "grey", (728, 909, 828, 987), 0.26, {"keep": 0.05}),
    "egg_green": ("tiles", "grey", (830, 916, 885, 976), 0.26, {}),
    "egg_rainbow": ("tiles", "grey", (884, 916, 959, 976), 0.26, {}),
    "egg_mound": ("tiles", "grey", (728, 979, 961, 1067), 0.3, {}),
}

BACKGROUND = {
    "island_big": ("tiles", "grey", (358, 837, 523, 957), 0.36, {"keep": 0.05}),
    "island_wide": ("tiles", "grey", (583, 870, 708, 957), 0.36, {"keep": 0.05}),
    "island_eggs": ("tiles", "grey", (429, 965, 569, 1068), 0.36, {}),
    "island_small_a": ("tiles", "grey", (577, 960, 651, 1048), 0.36, {}),
    "island_small_b": ("tiles", "grey", (368, 945, 426, 1019), 0.36, {}),
    "island_tiny": ("tiles", "grey", (658, 954, 701, 1008), 0.36, {}),
    "moon": ("tiles", "grey", (1340, 834, 1428, 926), 0.5, {}),
    "castle": ("tiles", "grey_soft", (1224, 818, 1338, 940), 0.62, {"keep": 0.05}),
}

# Bloques sólidos que pasan a formar parte del tileset (16x16 exactos)
BLOCKS = [
    ("block_star", (21, 425, 72, 474)),
    ("block_pink", (194, 425, 244, 474)),
    ("block_blue", (250, 425, 301, 474)),
    ("block_swirl_pink", (21, 485, 72, 540)),
    ("block_swirl_blue", (78, 484, 131, 541)),
    ("block_swirl_purple", (135, 484, 188, 541)),
    ("block_stripe_yellow", (193, 485, 244, 541)),
    ("block_stripe_pink", (250, 485, 301, 541)),
    ("block_heart", (409, 425, 463, 474)),
    ("block_bubble", (477, 425, 530, 474)),
]

# Fuentes de textura del terreno
GROUND_TOP = (206, 67, 278, 139)       # interior de la tesela de suelo nº3 (hierba + algodón)
GROUND_FILL = (104, 222, 158, 276)      # interior de roca-nube azul
GROUND_BOTTOM = (98, 250, 165, 320)     # roca con borde inferior redondeado
