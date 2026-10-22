"""Resumen del registro de pruebas jugadas (IMP-034).

    python tools/playtest_summary.py [ruta/playtest.csv]

Sin ruta usa el de Windows: %APPDATA%/Godot/app_userdata/<juego>/playtest.csv.
Imprime, por mundo y sección, caídas, golpes y desmayos, y cuántas sesiones llegaron al final,
en una tabla Markdown lista para pegar en docs/PLAYTEST_LOG.md.
"""
import csv
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path


def default_path() -> Path:
    base = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata"
    found = sorted(base.glob("*/playtest.csv"), key=lambda p: p.stat().st_mtime) if base.exists() else []
    if not found:
        sys.exit("No se encontró playtest.csv: pásalo como argumento")
    return found[-1]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")  # la consola de Windows no usa UTF-8 por defecto
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else default_path()
    rows = list(csv.DictReader(path.open(encoding="utf-8")))
    counts = defaultdict(Counter)  # (mundo, sección) -> evento -> n
    finished = defaultdict(set)    # mundo -> sesiones que cruzaron la puerta
    sessions = defaultdict(set)    # mundo -> sesiones que lo empezaron
    for r in rows:
        key = (r["mundo"], r["escena"].endswith("_boss"), r["seccion"])
        counts[key][r["evento"]] += 1
        if r["evento"] == "inicio":
            sessions[r["mundo"]].add(r["sesion"])
        if r["evento"] in ("fin", "jefe_vencido"):
            finished[(r["mundo"], r["evento"])].add(r["sesion"])
    print(f"Registro: {path} ({len(rows)} filas)\n")
    print("| Mundo | Sección | Caídas | Golpes | Desmayos |")
    print("|---|---|---|---|---|")
    for (world, boss, section), c in sorted(counts.items(), key=lambda kv: (int(kv[0][0] or 0), kv[0][1], kv[0][2])):
        if not (c["caida"] or c["golpe"] or c["desmayo"]):
            continue
        label = f"{section} (jefe)" if boss else section
        print(f"| {world} | {label} | {c['caida']} | {c['golpe']} | {c['desmayo']} |")
    print("\n| Mundo | Sesiones | Llegan a la puerta | Vencen al jefe |")
    print("|---|---|---|---|")
    for world in sorted(sessions, key=lambda w: int(w or 0)):
        print(f"| {world} | {len(sessions[world])} | {len(finished[(world, 'fin')])} | {len(finished[(world, 'jefe_vencido')])} |")


if __name__ == "__main__":
    main()
