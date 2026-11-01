"""Genera el paquete de PortMaster para la R36S: godot/export/r36s/alicedreams.zip

    py tools/r36s/build_r36s.py "C:\\ruta\\Godot_v4.7.2-stable_win64_console.exe"

Exporta el juego como .pck (el motor lo pone el runtime godot_4.7.1 de PortMaster) y lo empaqueta
con el lanzador. El zip se descomprime en la carpeta ports de la consola.
"""
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "export" / "r36s"
PRESET = "R36S (PortMaster)"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    OUT.mkdir(parents=True, exist_ok=True)
    pck = OUT / "alicedreams.pck"
    subprocess.run([sys.argv[1], "--headless", "--path", str(ROOT / "godot"), "--export-pack", PRESET, str(pck)], check=True)
    launcher = (ROOT / "tools" / "r36s" / "AliceDreams.sh").read_bytes().replace(b"\r\n", b"\n")
    with zipfile.ZipFile(OUT / "alicedreams.zip", "w", zipfile.ZIP_DEFLATED) as z:
        info = zipfile.ZipInfo("AliceDreams.sh")
        info.create_system = 3  # Unix: conserva el permiso de ejecución
        info.external_attr = (stat.S_IFREG | 0o755) << 16
        z.writestr(info, launcher)
        z.write(pck, "alicedreams/alicedreams.pck")
    print(OUT / "alicedreams.zip")


if __name__ == "__main__":
    main()
