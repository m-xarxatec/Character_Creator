# SPDX-License-Identifier: GPL-3.0-or-later
"""Crea un cuerpo humano con MPFB a partir de un JSON de valores.

Uso: blender -b -P blender/generar_cuerpo.py -- cuerpo.json

Formato del JSON (version 1); todo menos "version" es opcional:
{
  "version": 1,
  "species": "human",
  "macros": {"gender": 0.5, "height": 0.5, "race": {"asian": 0.33, ...}},
  "targets": {"hip-scale-horiz-incr": 0.6}
}
"""
import json
import os
import sys

import bpy
from bl_ext.blender_org.mpfb.services import HumanService, TargetService

FORMAT_VERSION = 1
MIN_AGE = 0.5  # 0.5 = adulto joven en MakeHuman; el editor solo crea adultos
FORBIDDEN_TARGET_DIRS = ("macrodetails", "genitals")


class BodyError(ValueError):
    """El JSON del cuerpo no es valido."""


def load_spec(path):
    """Lee el JSON y devuelve un dict completo y validado."""
    with open(path, encoding="utf-8") as file:
        return validate_spec(json.load(file))


def validate_spec(raw):
    unknown = set(raw) - {"version", "species", "macros", "targets"}
    if unknown:
        raise BodyError(f"Claves desconocidas: {sorted(unknown)}")
    if raw.get("version") != FORMAT_VERSION:
        raise BodyError(f"Se esperaba version {FORMAT_VERSION}, llego {raw.get('version')!r}")
    if raw.get("species", "human") != "human":
        raise BodyError("Por ahora solo existe la especie 'human'")
    return {
        "version": FORMAT_VERSION,
        "species": "human",
        "macros": _validate_macros(raw.get("macros", {})),
        "targets": _validate_targets(raw.get("targets", {})),
    }


def _validate_macros(raw):
    """Parte de los valores por defecto de MPFB y pisa los que traiga el JSON."""
    macros = TargetService.get_default_macro_info_dict()
    unknown = set(raw) - set(macros)
    if unknown:
        raise BodyError(f"Macros desconocidas: {sorted(unknown)}")
    for name, value in raw.items():
        if name == "race":
            macros["race"] = _validate_race(value, macros["race"])
        else:
            macros[name] = _unit(value, f"macros.{name}")
    if macros["age"] < MIN_AGE:
        raise BodyError(f"macros.age debe ser >= {MIN_AGE} (solo adultos)")
    return macros


def _validate_race(raw, default):
    unknown = set(raw) - set(default)
    if unknown:
        raise BodyError(f"Razas desconocidas: {sorted(unknown)}")
    race = {name: _unit(raw.get(name, 0.0), f"macros.race.{name}") for name in default}
    total = sum(race.values())
    if total <= 0:
        raise BodyError("macros.race no puede sumar 0")
    return {name: value / total for name, value in race.items()}  # MakeHuman espera que sumen 1


def _validate_targets(raw):
    """Devuelve {nombre: (ruta, peso)} y falla si un target no existe o esta prohibido."""
    targets = {}
    for name, value in raw.items():
        path = TargetService.target_full_path(name)
        stem = os.path.basename(path or "").split(".target")[0]
        if stem != name.lower():  # target_full_path tambien acepta prefijos; aqui exigimos el nombre exacto
            raise BodyError(f"Target desconocido: {name!r}")
        if os.path.basename(os.path.dirname(path)) in FORBIDDEN_TARGET_DIRS:
            raise BodyError(f"Target no permitido: {name!r}")
        targets[name] = (path, _unit(value, f"targets.{name}"))
    return targets


def _unit(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0.0 <= value <= 1.0:
        raise BodyError(f"{label} debe ser un numero entre 0 y 1, llego {value!r}")
    return float(value)


def create_body(spec):
    """Crea la malla base (en metros, pies en el suelo) con las macros y los targets del spec."""
    basemesh = HumanService.create_human(macro_detail_dict=spec["macros"], feet_on_ground=False)
    for name, (path, weight) in spec["targets"].items():
        TargetService.load_target(basemesh, path, weight=weight, name=name)
    _put_feet_on_ground(basemesh)
    return basemesh


def _put_feet_on_ground(basemesh):
    """Se hace al final: los targets pueden alargar las piernas y hundir los pies."""
    basemesh.location.z -= measure(basemesh)["lowest"]
    bpy.context.view_layer.objects.active = basemesh
    basemesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def measure(basemesh):
    """Medidas de la piel visible (sin malla auxiliar), en metros. Blender: Z arriba, X ancho, Y fondo."""
    evaluated = basemesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    points = [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]
    size = [max(p[axis] for p in points) - min(p[axis] for p in points) for axis in range(3)]
    return {
        "vertices": len(points),
        "height": round(size[2], 4),
        "width": round(size[0], 4),
        "depth": round(size[1], 4),
        "lowest": min(p[2] for p in points),
    }


def main():
    json_path = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = create_body(load_spec(json_path))
    print("RESUMEN:", json.dumps({key: round(value, 4) for key, value in measure(basemesh).items()}))


if __name__ == "__main__":
    try:
        main()
    except BodyError as error:
        print("ERROR:", error)
        sys.exit(1)
