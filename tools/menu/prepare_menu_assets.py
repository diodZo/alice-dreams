"""
Fondos del menú principal y del mapa de mundos.

Uso (desde la raíz del repositorio):
    python tools/menu/prepare_menu_assets.py

Fuentes oficiales (no se modifican):
    imagenes/menu_principal.png   pantalla de título con los tres primeros mundos y el audio
    imagenes/mapa_mundos.png      mapa con los ocho mundos

Las ilustraciones se reducen a la resolución lógica del juego (480x270). En el menú se borra
el "SÍ" de "MÚSICA: SÍ" / "EFECTOS: SÍ": el juego escribe SÍ o NO según la configuración real (el resto de rótulos de la ilustración son fijos y se conservan).
Las zonas interactivas (islas, recuadros) se describen en scripts/ui/menu.gd y world_map.gd
en coordenadas de 480x270.
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "godot", "resources", "menu")
SIZE = (480, 270)

# rectángulos [x0, y0, x1, y1] en píxeles de la imagen original y color del interior del recuadro
MENU_ERASE = [
    ((1150, 770, 1205, 815), (253, 250, 253)),  # "SÍ" de "MÚSICA: SÍ"
    ((1488, 770, 1530, 815), (253, 250, 253)),  # "SÍ" de "EFECTOS: SÍ"
]


def reduce(img):
    return img.convert("RGB").resize(SIZE, Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    menu = Image.open(os.path.join(ROOT, "imagenes", "menu_principal.png")).convert("RGB")
    draw = ImageDraw.Draw(menu)
    for box, color in MENU_ERASE:
        draw.rectangle(box, fill=color)
    reduce(menu).save(os.path.join(OUT, "menu_bg.png"))
    world_map = Image.open(os.path.join(ROOT, "imagenes", "mapa_mundos.png"))
    reduce(world_map).save(os.path.join(OUT, "world_map_bg.png"))
    print("OK ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
