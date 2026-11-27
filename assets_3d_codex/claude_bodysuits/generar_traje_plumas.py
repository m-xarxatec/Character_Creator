"""Traje rojo y azul con plumas (plano: planos/traje_rojo_azul_plumas.png), sin lo reconocible del plano.

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_traje_plumas.py
Escribe packs/claude_traje_plumas/: traje_plumas, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»).
Generador de maillots (cortes.py): la piel recortada, pegada al cuerpo. Decidido por el responsable: **sin guantes**
(las mangas acaban en la muñeca), **sin los murciélagos** de los muslos y la espalda en **U** (sin las formas de ala).
- Maillot: cuello abierto y bajo (se ven las clavículas), rombo bajo en el pecho, espalda abierta en U hasta la cintura, piernas altas; detrás cubre
  la mitad de dentro de los glúteos. Mangas pegadas del hombro a la muñeca (la misma tela, otra zona).
- Medias hasta el tobillo: otra capa de piel, más pegada (MEDIAS_GAP), que sube por debajo del maillot. Sin «tela
  tensa»: la piel tal cual, sacada por su normal (si se alisa, a tan poca distancia asoma la piel).
- Maillot y medias de una cara (sin grosor: los bordes bajan a la piel y no se ve; la mitad de peso).
- Cuello de plumas «bien fur», del tamaño del plano: en cada hombro, filas de plumas que salen hacia fuera (las de
  fuera, largas, debajo; las de dentro, cortas, encima). Sin banda en la nuca (la quitó el responsable: el cuello, libre
  detrás). Cada pluma, rígida con la
  piel de su raíz (solo las formas que la mueven ≥ PLUMA_MIN_MOVE).
Zonas en COLOR_0: (0,0,0) maillot; r = 1 mangas; g = 1 medias; b = 1 plumas.
"""
import math, sys
from pathlib import Path
import numpy as np

import cortes as ct

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "claude_colas"))
import generar_colas as col

sud, tr, bk, P0, F0 = ct.sud, ct.tr, ct.bk, ct.P0, ct.F0
ct.ZONES.update({"mangas": (1, 0, 0, 1), "medias": (0, 1, 0, 1), "plumas": (0, 0, 1, 1)})
RNG = np.random.default_rng(5)
UP = np.array([0, 1.0, 0])

# --- maillot ---
NECK = (1.375, 0.3, 0.125, 0.100, 0.020)        # cuello abierto y bajo (se ven las clavículas): plano y − 0,3·z,
                                                # elipse (rx, rz) en z = 0,02
SLEEVE_T = 1.97                                 # mangas hasta la muñeca (0 hombro, 1 codo, 2 muñeca)
DIAMOND = (1.235, 0.030, 0.075)                 # rombo del pecho: centro y, media anchura y media altura
BACK_U = (1.30, 0.120, 0.280)                   # espalda en U: centro y, media anchura, media altura (baja a 1,02)
FRONT_HW = [(0.77, 0.016), (0.80, 0.022), (0.86, 0.045), (0.92, 0.075), (0.98, 0.105), (1.04, 0.135), (1.08, 0.25)]
BACK_HW = [(0.77, 0.016), (0.80, 0.030), (0.85, 0.060), (0.90, 0.090), (0.95, 0.120), (1.00, 0.150), (1.04, 0.25)]
# --- medias ---
MEDIAS_GAP = 0.0012                             # más pegadas que el maillot (2,5 mm): quedan debajo
ANKLE_Y = 0.095
MEDIAS_TOP = [(0, 1.00), (60, 1.04), (90, 1.10), (120, 1.08), (150, 1.03), (180, 1.00)]   # (grados, y): bajo el maillot
AXIS_Z = [(0.90, 0.020), (0.97, 0.045), (1.22, 0.045)]
# --- plumas: filas de fuera a dentro (radio de la raíz desde el eje del cuello, largo, media anchura, hueco a la piel,
# cuántas, grados desde delante de la primera y la última) ---
ROWS = [(0.122, 0.175, 0.038, 0.010, 14, 25, 160), (0.112, 0.150, 0.036, 0.016, 13, 30, 155),
        (0.102, 0.125, 0.032, 0.022, 12, 35, 150), (0.093, 0.100, 0.029, 0.028, 11, 40, 145),
        (0.085, 0.075, 0.024, 0.034, 10, 45, 140), (0.078, 0.050, 0.019, 0.040, 9, 50, 135)]
FEATHER_SCALE = 0.8                             # largo y ancho de todas (el responsable: «un poco más pequeñas»)
NECK_AXIS = (0.0, 0.0)                          # eje del cuello (x, z)
LATERAL = 0.35                                  # dirección: hacia el lado + esto × hacia fuera del cuello
DROOP = [34, 28, 22, 16, 11, 7]                 # caída de cada fila (grados): las de fuera, más (forma de ala)
DROOP_FB = 12                                   # extra delante y detrás
ROLL = 25                                       # giro de la hoja sobre su eje (± grados): no se ven de canto
CURL = 0.15                                     # la punta sube (fracción del largo)
RINGS, SIDES = 8, 4
ROOT_MIN_Y = 1.30                               # la raíz, en el hombro (no más abajo)
PLUMA_MIN_MOVE = 0.006
TELA_MIN_MOVE = 0.0005                           # maillot y medias: lo que una forma mueve menos, quieto (peso)


# ---------------- maillot ----------------
def diamond(V):
    yc, hw, hh = DIAMOND
    d = 1 - (np.abs(V[:, 0]) / hw + np.abs(V[:, 1] - yc) / hh)
    return np.where(V[:, 2] > 0.05, d * hw, -1.0)


def sleeve_zone(i, w):
    arm = (sud.arm_w[i] * w).sum(1)
    return np.where((arm > 0.5)[:, None], ct.ZONES["mangas"], ct.ZONES["tela"])


# ---------------- medias ----------------
def medias_cut(V):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    phi = np.degrees(np.arctan2(np.abs(x), z - np.interp(y, *zip(*AXIS_Z))))
    f = np.maximum(ANKLE_Y - y, y - np.interp(phi, *zip(*MEDIAS_TOP)))
    return np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, 1.0, f)


def medias():
    V, F, loops = ct.cut_skin([medias_cut], (0.06, 1.15))
    q, si, sw, n = bk.on_skin(V)
    O = bk.to_edges(q + n * MEDIAS_GAP, loops)
    q, si, sw, n = bk.on_skin(O)
    h = ((O - q) * n).sum(1)
    inner = h > MEDIAS_GAP * 0.9
    low = []
    for d in sud.B["targets"].values():
        P = P0 + d
        Os = O + (d[si] * sw[..., None]).sum(1) + (bk.normal_at(sud.vertex_normals(P, F0), si, sw) - n) * h[:, None]
        low.append(((Os - (P[si] * sw[..., None]).sum(1)) * bk.normal_at(sud.vertex_normals(P, F0), si, sw)).sum(1)
                   [inner].min())
    print("MEDIDA medias: %d vértices; a la piel mín %.1f mm (reposo), %.1f mm (con cada forma); de y = %.3f a %.3f" % (
        len(O), 1000 * h[inner].min(), 1000 * min(low), O[:, 1].min(), O[:, 1].max()))
    return (O, F), "medias", (ct.pad8(si), ct.pad8(sw)), h, TELA_MIN_MOVE


# ---------------- plumas ----------------
TORSO_F = F0[((sud.main_bone != "Head") & ~sud.hand_like)[F0].all(1)]


def drop_ray(x, z):
    """Primer punto de la piel (sin la cabeza) bajando en vertical por (x, z)."""
    T = P0[TORSO_F]
    o, d = np.array([x, 1.7, z]), -UP
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    p = np.cross(d, e2)
    det = (e1 * p).sum(1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    s = o - T[:, 0]
    u = (s * p).sum(1) * inv
    q = np.cross(s, e1)
    v = (q @ d) * inv
    t = (q * e2).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0) & (1.7 - t > ROOT_MIN_Y)
    return o + d * t[hit].min() if hit.any() else None


def feather(root, n_skin, d, length, width, clear):
    """Pluma: hoja plana en punta (sección en lente), que sale de root hacia d, cae, sube en la punta y no entra en la
    piel (a clear como poco). Devuelve (v, f)."""
    tau = np.linspace(0, 1, RINGS)
    side = ct.unit(np.cross(d, UP))
    up = ct.unit(np.cross(side, d))
    path = root + n_skin * clear + np.outer(tau * length, d) + np.outer(CURL * length * tau ** 2, up)
    path += np.outer(np.sin(math.pi * tau) * RNG.uniform(-0.01, 0.01), side)
    for _ in range(3):
        path = bk.push_out(path, clear, 2)
        path[1:-1] = 0.5 * path[1:-1] + 0.25 * (path[:-2] + path[2:])
    t = ct.unit(np.gradient(path, axis=0))
    nb = ct.unit(np.cross(t, side))
    nb *= np.sign((nb * up).sum(1))[:, None]
    sd = ct.unit(np.cross(nb, t))
    rl = math.radians(RNG.uniform(-ROLL, ROLL))
    nb, sd = nb * math.cos(rl) + sd * math.sin(rl), sd * math.cos(rl) - nb * math.sin(rl)
    teeth = 1 - 0.22 * np.clip((tau - 0.45) / 0.55, 0, 1) * (np.abs(np.sin(9 * math.pi * tau)))   # borde dentado
    wl = width * (0.35 + 0.65 * np.sin(math.pi / 2 * np.clip(tau / 0.35, 0, 1))) * (1 - tau) ** 0.45 * teeth + 0.0006
    th = 0.30 * wl + 0.0004
    a = np.linspace(0, 2 * math.pi, SIDES, endpoint=False)
    ring = path[:, None] + wl[:, None, None] * np.cos(a)[None, :, None] * sd[:, None] \
        + th[:, None, None] * np.sin(a)[None, :, None] * nb[:, None]
    v = np.vstack([ring.reshape(-1, 3), path[0], path[-1]])
    return v, col.tube_faces(v, path, RINGS, SIDES)


def plumas():
    out = []
    for s in (1, -1):
        for j, (r, ln, w, clear, n, a0, a1) in enumerate(ROWS):
            for k in range(n):
                psi = math.radians(a0 + (a1 - a0) * (k + 0.5 * (j % 2)) / max(n - 1 + 0.5 * (j % 2), 1)
                                   + RNG.uniform(-3, 3))
                radial = np.array([s * math.sin(psi), 0, math.cos(psi)])
                rr, hit = r, None
                while hit is None:                                     # detrás, fuera del cuerpo: más cerca del eje
                    hit = drop_ray(NECK_AXIS[0] + rr * radial[0], NECK_AXIS[1] + rr * radial[2])
                    rr -= 0.004
                _, si, sw, nrm = bk.on_skin(hit[None])
                drop = math.radians(DROOP[j] + DROOP_FB * abs(math.cos(psi)) + RNG.uniform(-4, 4))
                d0 = ct.unit(np.array([s * 1.0, 0, 0]) + LATERAL * radial)
                d = d0 * math.cos(drop) - UP * math.sin(drop)
                v, f = feather(hit, nrm[0], d, FEATHER_SCALE * ln * RNG.uniform(0.9, 1.1),
                               FEATHER_SCALE * w * RNG.uniform(0.9, 1.1), clear)
                out.append(((v, f), "plumas", (np.tile(si, (len(v), 1)), np.tile(sw, (len(v), 1))),
                            np.zeros(len(v)), PLUMA_MIN_MOVE))
    return out


def extras(O, F):
    return [medias()] + plumas()


def main():
    cuts = [ct.neck_round(*NECK), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), diamond,
            ct.oval(*BACK_U), ct.bottom(FRONT_HW, BACK_HW)]
    ct.build(cuts, HERE / "packs" / "claude_traje_plumas", "claude_traje_plumas", "Traje con plumas (pruebas)",
             "traje_plumas", "Traje rojo y azul con plumas", [0.62, 0.08, 0.10], extras, sleeve_zone,
             TELA_MIN_MOVE, thick=False)


if __name__ == "__main__":
    main()
