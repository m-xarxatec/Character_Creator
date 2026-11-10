# SPDX-License-Identifier: GPL-3.0-or-later
"""Crea un personaje con MPFB a partir de un JSON de valores: cuerpo, esqueleto y prenda base.

Uso: blender -b -P blender/generar_cuerpo.py -- cuerpo.json [salida.glb]

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

import bl_ext.blender_org.mpfb as mpfb
import bpy
from bl_ext.blender_org.mpfb.services import HumanService, TargetService

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # para importar los otros scripts de blender/
from anclajes import add_sockets  # noqa: E402
from exportar_glb import export_glb, rename_to_humanoid  # noqa: E402
from limpiar_malla import clean_mesh  # noqa: E402
from poner_rig import add_rig  # noqa: E402
from pose_t import apply_t_pose  # noqa: E402
from prenda_base import paint_base_garment  # noqa: E402

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
    return _snap_out_of_gaps(macros)


def mpfb_gaps():
    """{macro: [(desde, hasta)]}: valores que MPFB no asigna a ningun tramo (pruebas/fase_2/hueco_mpfb/)."""
    path = os.path.join(os.path.dirname(mpfb.__file__), "data", "targets", "macrodetails", "macro.json")
    with open(path, encoding="utf-8") as file:
        config = json.load(file)["macrotargets"]
    return {name: [(a["highest"], b["lowest"]) for a, b in zip(m["parts"], m["parts"][1:])] for name, m in config.items()}


def in_mpfb_gap(name, value, gaps=None):
    return any(low <= value <= high for low, high in (gaps or mpfb_gaps()).get(name, []))


def _snap_out_of_gaps(macros):
    """Dentro de un hueco MPFB quita todas las formas de la macro (hasta 9 cm en el pecho): se usa 0,5.
    Los huecos de un adulto estan todos junto a 0,5."""
    gaps = mpfb_gaps()
    for name, value in macros.items():
        if name != "race" and value != 0.5 and in_mpfb_gap(name, value, gaps):
            print(f"AVISO: macros.{name} = {value} cae en un hueco de MPFB; se usa 0.5")
            macros[name] = 0.5
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


def build_character(spec):
    """Personaje listo para exportar, en pose T y con nombres humanoides. Devuelve (malla, anclajes)."""
    basemesh = create_body(spec)
    add_rig(basemesh)
    paint_base_garment(basemesh)
    clean_mesh(basemesh)
    apply_t_pose(basemesh)
    rename_to_humanoid(basemesh)
    return basemesh, add_sockets(basemesh)


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
    args = sys.argv[sys.argv.index("--") + 1:]
    json_path = args[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh, sockets = build_character(load_spec(json_path))
    if len(args) > 1:
        export_glb(basemesh, sockets, os.path.abspath(args[1]))
        print("EXPORTADO:", os.path.abspath(args[1]))
    print("RESUMEN:", json.dumps({key: round(value, 4) for key, value in measure(basemesh).items()}))


if __name__ == "__main__":
    try:
        main()
    except BodyError as error:
        print("ERROR:", error)
        sys.exit(1)
