"""Bordes de color nítidos: corta la malla justo por la línea donde cambia de zona (campo = 0), con los vértices de
la línea repetidos a cada lado. Así el color no sigue los lados de los triángulos (no sale en escalera)."""
import numpy as np


def split(F, f):
    """Corta cada triángulo que cruza f = 0. Devuelve (F nuevas, nuevos vértices [(i, j, t)] y lado de cada vértice
    (True: f > 0)); el vértice nuevo k es el punto i + t·(j − i), uno por cada lado del corte."""
    f = np.where(f == 0, -1e-9, f)
    pos = f > 0
    n = len(f)
    new, side, key = [], [], {}

    def cut(i, j, s):
        k = (min(i, j), max(i, j), s)
        if k not in key:
            key[k] = n + len(new)
            new.append((i, j, f[i] / (f[i] - f[j])))
            side.append(s)
        return key[k]

    out = []
    for tri in F:
        p = pos[tri]
        if p.all() or not p.any():
            out.append(tri)
            continue
        lone = np.where(p != (p.sum() == 2))[0][0] if p.sum() == 2 else np.where(p)[0][0]
        a, b, c = np.roll(tri, -lone)
        sa = pos[a]
        ab_a, ac_a = cut(a, b, sa), cut(a, c, sa)
        ab_o, ac_o = cut(a, b, not sa), cut(a, c, not sa)
        out += [(a, ab_a, ac_a), (ab_o, b, c), (ab_o, c, ac_o)]
    return np.array(out), new, np.r_[pos, np.array(side, bool)]


def lerp(A, new):
    """Valores de los vértices nuevos (A: un valor o fila por vértice)."""
    if not new:
        return A
    i, j, t = (np.array(x) for x in zip(*new))
    t = t.reshape((-1,) + (1,) * (A.ndim - 1))
    return np.concatenate([A, A[i] * (1 - t) + A[j] * t])


def lerp_skin(si, sw, new):
    """Índices y pesos de piel de los vértices nuevos: los de los dos extremos, los 8 de más peso."""
    if not new:
        return si, sw
    i, j, t = (np.array(x) for x in zip(*new))
    ni, nw = np.c_[si[i], si[j]], np.c_[sw[i] * (1 - t)[:, None], sw[j] * t[:, None]]
    top = np.argsort(-nw, 1)[:, :si.shape[1]]
    ni, nw = np.take_along_axis(ni, top, 1), np.take_along_axis(nw, top, 1)
    return np.concatenate([si, ni]), np.concatenate([sw, nw / nw.sum(1, keepdims=True)])
