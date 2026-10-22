"""Esquema común de los JSON de nivel (IMP-015).

Cada generador (tools/worldN/worldN_level.py) llama a compact() antes de escribir: las claves
de mecánicas que el mundo no usa (listas vacías) no se escriben. LevelBuilder trata esas claves
como opcionales (data.get(k, [])), así que un mundo nuevo sólo declara lo que usa.
"""

# Claves que siempre se escriben aunque estén vacías: las lee el nivel, el registro de mundos o
# las pruebas en todos los mundos (y en las arenas de los jefes).
ALWAYS = {"sections", "terrain", "enemies", "stars", "checkpoints", "signs", "decor", "pickups", "startWeapons"}


def compact(data: dict) -> dict:
    """Copia de `data` sin las listas vacías que no forman parte del esquema común."""
    return {k: v for k, v in data.items() if k in ALWAYS or not (isinstance(v, list) and not v)}
