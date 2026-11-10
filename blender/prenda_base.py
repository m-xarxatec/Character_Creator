# SPDX-License-Identifier: GPL-3.0-or-later
"""Prenda base pintada: marca en la malla las zonas de top y short.

No es geometria: es un atributo de color por vertice ("garment", 1 = prenda, 0 = piel)
que el shader pinta de un color plano. Asi sigue siempre al cuerpo.

Las zonas se miden sobre la forma "Basis" (igual en todos los cuerpos) y relativas a
los cubos de articulacion de MakeHuman, asi que salen identicas sea cual sea el cuerpo.
Hay que llamar a paint_base_garment despues de poner el rig (usa los pesos de los huesos).
"""
from poner_rig import bone_weights

ATTRIBUTE = "garment"
FEATHER = 0.06  # metros de degradado en el borde (unas 2 aristas): el shader corta en 0.5 y la linea sale recta

# Cada zona: de que articulacion a cual (con un desplazamiento en metros) y que huesos la llevan.
ZONES = (
    {  # short: de medio muslo alto a debajo del ombligo
        "low": ("joint-l-upper-leg", -0.10),
        "high": ("joint-spine-4", 0.03),
        "bones": ("pelvis", "spine_01", "thigh_l", "thigh_r"),
    },
    {  # top: banda del pecho, de debajo del busto a la axila
        "low": ("joint-spine-2", 0.04),
        "high": ("joint-spine-1", 0.035),
        "bones": ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"),
    },
)


def paint_base_garment(basemesh):
    """Crea (o repinta) el atributo de color y devuelve cuantos vertices quedan como prenda."""
    basis = basemesh.data.shape_keys.key_blocks["Basis"].data
    limits = [(_joint_height(basemesh, basis, *z["low"]), _joint_height(basemesh, basis, *z["high"])) for z in ZONES]
    colors = basemesh.data.color_attributes.get(ATTRIBUTE) or basemesh.data.color_attributes.new(ATTRIBUTE, "FLOAT_COLOR", "POINT")
    painted = 0
    for vertex in basemesh.data.vertices:
        weights = bone_weights(basemesh, vertex)
        height = basis[vertex.index].co.z
        value = max(_zone_value(height, low, high, weights, zone["bones"]) for zone, (low, high) in zip(ZONES, limits))
        colors.data[vertex.index].color = (value, value, value, 1.0)
        painted += value >= 0.5
    basemesh.data.color_attributes.active_color = colors
    basemesh.data.color_attributes.render_color_index = list(basemesh.data.color_attributes).index(colors)
    return painted


def _joint_height(basemesh, basis, group_name, offset):
    """Altura (z) del centro de un cubo de articulacion, mas un desplazamiento."""
    index = basemesh.vertex_groups[group_name].index
    heights = [basis[v.index].co.z for v in basemesh.data.vertices if any(g.group == index for g in v.groups)]
    return sum(heights) / len(heights) + offset


def _zone_value(height, low, high, weights, bones):
    """1 dentro de la zona, 0 fuera, con un degradado corto en los bordes."""
    inside_band = min(_ramp(height - low), _ramp(high - height))
    on_bones = sum(weights.get(bone, 0.0) for bone in bones)
    return min(inside_band, on_bones)


def _ramp(distance):
    return min(1.0, max(0.0, 0.5 + distance / FEATHER))
