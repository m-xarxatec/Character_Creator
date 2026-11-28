# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 9.7.1: formas de expresion (expr_*) para cuerpo.glb, con los nombres de VRM 1.0 (ficha ruta/pasos/9.7_expresiones.md).

- Cejas, mejillas y boca: mezcla de unidades ARKit de faceunits01 (CC0, Mika Suominen; copiadas en blender/faceunits01/,
  sin cambios) con los pesos de blender/expresiones.json. Pesos propios: no se copian expresiones de MPFB.
- Parpadeo: propio (cara_anime.EyeFit.blink_delta), por lados (D56): expr_blinkLeft y expr_blinkRight. VRM «blink» son
  las dos a la vez. Una correccion por cada extremo de Alto y Tamano de los ojos (expr_blinkLeft*eye_tall_incr, ...,
  peso = producto, como las de las macros), para que el ojo se cierre tambien con esos deslizadores.
- Todo pasa por EyeFit.face_delta: la bolsa del ojo sigue al lazo y queda detras de su membrana.
- Simetricas (promedio con el reflejo, como formas_propias). El parpadeo propio ya sale de un solo ojo.
- Paso 9.8: visemas de VRM (aa, ih, ou, ee, oh) con las de visemes02 (CC0, Mika Suominen; copiadas en
  blender/visemes02/, sin cambios): viseme_aa, viseme_I, viseme_U, viseme_E y viseme_O. Abren la boca: tras el 9.6
  la bolsa de la boca ya no esta aplastada (D57).
- Orden: las expresiones del 9.7, sus correcciones y despues las visemas (las formas de antes no cambian de sitio).
Uso (lo hace exportar_datos.export_species, con las formas de ojo ya corregidas por fit.fix_eye_shapes):
    shapes.update(expresiones.expression_shapes(basemesh, fit, shapes))
Unidades y "Left"/"Right": el lado del personaje (Left = +X, el ojo "l" de ojos.json; comprobado con los indices de
eyeBlinkLeft, que mueven los 36 del lazo izquierdo).
"""
import json
import os

import numpy as np
from bl_ext.blender_org.mpfb.services import TargetService

import formas_propias as fp

HERE = os.path.dirname(os.path.abspath(__file__))
RECIPES = os.path.join(HERE, "expresiones.json")
UNITS = (os.path.join(HERE, "faceunits01"), os.path.join(HERE, "visemes02"))  # paso 9.8: tambien las visemas
PREFIX = "expr_"
OWN = "propio"
BLINKS = {"blinkLeft": "l", "blinkRight": "r"}
BLINK_FIXES = ("eye_tall_decr", "eye_tall_incr", "eye_size_decr", "eye_size_incr")  # cambian lo que se abre el ojo


def load_recipes(path=RECIPES):
    with open(path, encoding="utf-8") as file:
        data = json.load(file)
    if data.get("version") != 1:
        raise ValueError("expresiones.json: version %s; este codigo lee la 1" % data.get("version"))
    return data["expresiones"]


def shape_names(recipes=None):
    """Nombres expr_* de cuerpo.glb, en el orden de expression_shapes (lo usan las pruebas)."""
    recipes = load_recipes() if recipes is None else recipes
    blinks = [n for n in recipes if n in BLINKS]
    out = []
    for name in recipes:
        out.append(PREFIX + name)
        if blinks and name == blinks[-1]:
            out += ["%s%s*%s" % (PREFIX, b, f) for b in BLINKS if recipes.get(b) == OWN for f in BLINK_FIXES]
    return out


def unit_deltas(basemesh, names):
    """{unidad: desplazamiento de cada vertice} (espacio de la malla), cargando cada .target con MPFB en una shape key
    temporal y restandole su base. La malla queda como estaba."""
    had_keys = basemesh.data.shape_keys is not None
    out = {}
    for name in names:
        found = [os.path.join(folder, name + ".target") for folder in UNITS]
        found = [p for p in found if os.path.exists(p)]
        if not found:
            raise ValueError("Falta la unidad %s en %s" % (name, ", ".join(UNITS)))
        path = found[0]
        key_name = "_unidad_" + name
        TargetService.load_target(basemesh, path, weight=0.0, name=key_name)
        key = basemesh.data.shape_keys.key_blocks[key_name]
        co = np.empty(len(key.data) * 3)
        base = np.empty(len(key.data) * 3)
        key.data.foreach_get("co", co)
        key.relative_key.data.foreach_get("co", base)
        out[name] = (co - base).reshape(-1, 3)
        basemesh.shape_key_remove(key)
    if not had_keys and basemesh.data.shape_keys is not None:
        basemesh.shape_key_clear()
    return out


def expression_shapes(basemesh, fit, shapes):
    """{"expr_<nombre>": (desplazamiento, huesos quietos)}; las correcciones del parpadeo, al final."""
    recipes = load_recipes()
    units = unit_deltas(basemesh, sorted({u for r in recipes.values() if r != OWN for u in r}))
    world = np.array(basemesh.matrix_world)[:3, :3]
    to_local = np.linalg.inv(world)
    still = {b.name: (np.zeros(3), np.zeros(3)) for b in basemesh.parent.data.bones}
    out = {}
    last_blink = [n for n in recipes if n in BLINKS][-1] if any(n in BLINKS for n in recipes) else None
    for name, recipe in recipes.items():
        if recipe == OWN:
            if name not in BLINKS:
                raise ValueError("expresiones.json: '%s' no puede ser \"propio\" (solo %s)" % (name, ", ".join(BLINKS)))
            delta = fit.blink_delta(fit.anime, BLINKS[name]) @ to_local.T
        else:
            delta = sum(weight * fit.face_delta(units[unit]) for unit, weight in recipe.items())
            # las de dos lados, simetricas; las de un lado (A/B del parpadeo), cortadas por x = 0
            delta = fp.symmetric(delta, fit.mirror) if name not in BLINKS else _one_side(delta, fit.points, BLINKS[name])
        out[PREFIX + name] = (delta, still)
        if name == last_blink:  # las correcciones, justo despues del parpadeo (asi las visemas del 9.8 van al final)
            out.update(_blink_fixes(fit, shapes, recipes, world, to_local, still))
    return out


def _blink_fixes(fit, shapes, recipes, world, to_local, still):
    """{"expr_blink<lado>*<forma de ojo>": correccion} del parpadeo propio en los extremos de BLINK_FIXES."""
    out = {}
    for name, side in BLINKS.items():
        if recipes.get(name) != OWN:
            continue  # con una receta de unidades (A/B de 9.7.0) no hay correcciones
        base = fit.blink_delta(fit.anime, side)
        for fix in BLINK_FIXES:
            state = fit.anime + shapes[fix][0] @ world.T
            out["%s%s*%s" % (PREFIX, name, fix)] = ((fit.blink_delta(state, side) - base) @ to_local.T, still)
    return out


def _one_side(delta, points, side):
    """Solo los vertices del lado side ("l": x > 0; "r": x < 0)."""
    keep = points[:, 0] > 0.0 if side == "l" else points[:, 0] < 0.0
    return np.where(keep[:, None], delta, 0.0)
