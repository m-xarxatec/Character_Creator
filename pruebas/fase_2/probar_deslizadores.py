# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 2.1: la tabla de deslizadores solo usa targets, macros y huesos que existen.

Uso: blender -b -P pruebas/fase_2/probar_deslizadores.py
"""
import csv
import os
import re
import sys

from bl_ext.blender_org.mpfb.services import TargetService

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_glb  # noqa: E402
import generar_cuerpo as gc  # noqa: E402
import cara_anime  # noqa: E402
import exportar_datos as ed  # noqa: E402
import formas_propias  # noqa: E402

TABLE = os.path.join(ROOT, "godot", "datos", "humana", "deslizadores.csv")
COLUMNS = ["id", "zona", "nombre", "tipo", "decr", "incr", "lados", "neutro"]
ZONES = 19  # sin contar «Cara» ni «Base» (pasos 3.14 y 6.2: sin deslizadores visibles en el MVP)
FACE_ZONE = "Cara"
HIDDEN_ZONES = {FACE_ZONE, "Base"}
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def sides(name, row):
    """Nombres de los targets de cada lado: 'x' -> ['l-x', 'r-x'] si el deslizador tiene dos lados."""
    return [f"{side}-{name}" for side in ("l", "r")] if row["lados"] == "2" else [name]


def target_ok(name):
    try:
        gc._validate_targets({name: 0.5})
        return True
    except gc.BodyError:
        return False


def shape_ok(row, value):
    """Forma: 'target+target' o 'macro:nombre=valor'."""
    macro = re.fullmatch(r"macro:(\w+)=([\d.]+)", value)
    if macro:
        return macro[1] in TargetService.get_default_macro_info_dict() and 0 <= float(macro[2]) <= 1
    names = [n for part in value.split("+") for n in sides(part, row)]
    return bool(value) and all(target_ok(n) for n in names)


def scale_of(row, value):
    """Proporción: 'escala:Hueso=valor' -> valor, o None si el hueso no es humanoide."""
    match = re.fullmatch(r"escala:(\w+)=([\d.]+)", value)
    if not match:
        return None
    bones = [match[1]] if row["lados"] == "1" else ["Left" + match[1], "Right" + match[1]]
    known = set(exportar_glb.humanoid_names().values())
    return float(match[2]) if all(b in known for b in bones) else None


def neutral_ok(row):
    """Forma y Proporción: neutro de 0 a 1 (con dos sentidos, entre los dos); Por crear: vacío."""
    if row["tipo"] == "Por crear":
        return row["neutro"] == ""
    try:
        n = float(row["neutro"])
    except ValueError:
        return False
    return 0 <= n < 1 if row["decr"] == "" else 0 < n < 1


def check_row(row):
    label = f"{row['id']}:"
    check(f"{label} neutro válido", neutral_ok(row), row["neutro"])
    if row["tipo"] == "Forma" and row["incr"].startswith("cara:"):
        steps = {name for name, *_ in cara_anime.STEPS}
        check(f"{label} forma de cara de un lado, de cara_anime.py, zona {FACE_ZONE}",
              row["decr"] == "" and row["incr"][len("cara:"):] in steps and row["zona"] == FACE_ZONE
              and row["lados"] == "1")
    elif row["tipo"] == "Forma" and row["incr"].startswith(ed.OWN):
        sources = [s[len(ed.OWN):] for s in (row["decr"], row["incr"]) if s]
        check(f"{label} forma propia de formas_propias.py", all(s in formas_propias.SHAPES for s in sources)
              and all(s.startswith(ed.OWN) for s in (row["decr"], row["incr"]) if s), f"{row['decr']} / {row['incr']}")
    elif row["tipo"] == "Forma":
        check(f"{label} formas existen", shape_ok(row, row["decr"]) and shape_ok(row, row["incr"]),
              f"{row['decr']} / {row['incr']}")
    elif row["tipo"] == "Proporción":
        low, high = scale_of(row, row["decr"]), scale_of(row, row["incr"])
        check(f"{label} escala de hueso humanoide, menos < 1 < más",
              low is not None and high is not None and 0 < low < 1 < high)
    else:
        check(f"{label} por crear sin fuente", row["decr"] == row["incr"] == "")


with open(TABLE, encoding="utf-8", newline="") as file:
    reader = csv.DictReader(file)
    rows = list(reader)
check("columnas", reader.fieldnames == COLUMNS, reader.fieldnames)
ids = [r["id"] for r in rows]
check("ids únicos", len(ids) == len(set(ids)))
check("ids en inglés snake_case", all(re.fullmatch(r"[a-z][a-z0-9_]*", i) for i in ids))
zones = {r["zona"] for r in rows} - HIDDEN_ZONES
check(f"{ZONES} zonas (sin {', '.join(sorted(HIDDEN_ZONES))})", len(zones) == ZONES, sorted(zones))
check("tipos válidos", all(r["tipo"] in ("Forma", "Proporción", "Por crear") for r in rows))
check("lados 1 o 2", all(r["lados"] in ("1", "2") for r in rows))
for r in rows:
    check_row(r)
check("detecta un target inventado", not target_ok("brazo-largo-incr"))

print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
sys.exit(1 if failures else 0)
