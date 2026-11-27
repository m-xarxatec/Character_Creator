"""Bodysuit negro y dorado (plano: planos/bodysuit_negro_dorado.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_bodysuit_dorado.py
Escribe packs/claude_bodysuit_dorado/: bodysuit_dorado, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»).
Generador de maillots (cortes.py): la piel recortada, pegada al cuerpo; manga larga hasta la muñeca, ventana en el
pecho bajo el cuello, delante V alta con la entrepierna estrecha y detrás **hilo hasta arriba** (pedido por el
responsable): sube por el surco hasta y ≈ 0,93 y solo ahí se abre en un triángulo pequeño.
- Cuello vuelto: no va pegado (es holgado): la piel del cuello copiada e hinchada TN_OFF, con pliegues horizontales;
  el borde de arriba sube detrás hasta TN_TOP_BACK y baja delante hasta TN_TOP_FRONT (bajo la barbilla). Dos capas.
- En relieve (zona «detalle», dorado): franja de cada lado del cuello al puño (por el hombro y por fuera del brazo);
  triángulo y cuatro barritas en X en el pecho, un triangulito a cada lado de la ventana y, en la entrepierna, una
  barra, dos triángulos llenos y uno hueco.
Zonas en COLOR_0: (0,0,0) negro; r = 1 dorado.
"""
import math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "claude_casco"))
import cortes as ct
import generar_casco as casco

sud, tr, P0, F0 = ct.sud, ct.tr, ct.P0, ct.F0
unit = ct.unit

NECK_Y = 1.445                                  # la tela llega hasta aquí (queda bajo el cuello vuelto)
SLEEVE_T = 1.97                                 # manga larga: hasta la muñeca (0 hombro, 1 codo, 2 muñeca)
WINDOW = (0.0, 1.372, 0.050, 0.011, 0.006)      # ventana del pecho: centro x, y; media anchura y altura; radio
FRONT_HW = [(0.77, 0.010), (0.80, 0.014), (0.86, 0.035), (0.92, 0.065), (0.98, 0.100), (1.04, 0.135), (1.08, 0.25)]
BACK_HW = [(0.77, 0.006), (0.93, 0.006), (0.96, 0.025), (0.99, 0.060), (1.02, 0.110), (1.06, 0.25)]   # hilo hasta arriba
# cuello vuelto
TN_Y0, TN_TOP_BACK, TN_TOP_FRONT = 1.405, 1.500, 1.440
TN_OFF, TN_FOLD, TN_STEP = 0.012, 0.0035, 0.016  # holgura, hondo de los pliegues y paso entre ellos
# relieve dorado
LIFT, GOLD_T = 0.0016, 0.0012                   # sobre la tela y grosor
STRIPE_W = 0.022


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


# ---------------- cuello vuelto ----------------
def tn_top(p):
    return TN_TOP_BACK - (TN_TOP_BACK - TN_TOP_FRONT) * smooth(p[:, 2] / 0.07)


def turtleneck():
    """La piel del cuello entre TN_Y0 y el borde de arriba, hinchada con pliegues; dos capas unidas en los bordes."""
    near = (P0[:, 1] > TN_Y0 - 0.02) & (P0[:, 1] < TN_TOP_BACK + 0.02) & (np.abs(P0[:, 0]) < 0.11) & (sud.arm_w < 0.3)
    V, F = ct.bk._compact(P0, F0[near[F0].all(1)])
    V, F = tr.clip(V, F, TN_Y0 - V[:, 1])
    V, F = tr.clip(V, F, V[:, 1] - tn_top(V))
    V, F = tr.largest_part(V, F)
    n = sud.vertex_normals(V, F)
    ang = np.arctan2(V[:, 0], V[:, 2] - 0.04)
    k = (V[:, 1] - TN_Y0) / TN_STEP + 0.6 * np.sin(3 * ang + 0.5)
    fold = TN_FOLD * np.sin(2 * math.pi * k) + 0.002 * np.sin(5 * ang + 1.3)
    off = (TN_OFF + fold) * smooth((V[:, 1] - TN_Y0) / 0.010) + 0.004       # abajo baja hasta la tela
    out = V + n * off[:, None]
    loops = sud.boundary_loops(F)
    fixed = np.zeros(len(out), bool); fixed[np.concatenate(loops)] = True
    out = sud.taubin(out, F, fixed, 3)
    inner = out - sud.vertex_normals(out, F) * 0.003
    v, f = np.vstack([out, inner]), np.concatenate([F, F[:, ::-1] + len(out)])
    v, f = sud.bridge_open(v, f)
    head = P0[sud.main_bone == "Head"]
    print("MEDIDA cuello vuelto: %d vértices; a la cabeza (piel) mín %.1f mm" % (
        len(v), 1000 * cKDTree(head).query(v)[0].min()))
    return v, f


# ---------------- relieve dorado ----------------
class Cloth:
    """La tela (superficie de fuera) para apoyar el relieve: punto y normal más cercanos (media de 6 vértices)."""
    def __init__(self, O, F):
        self.O, self.n, self.kd = O, tr.vertex_normals(O, F), cKDTree(O)

    def project(self, p):
        d, i = self.kd.query(p, k=6)
        w = 1 / (d + 1e-4); w /= w.sum(1, keepdims=True)
        return (self.O[i] * w[..., None]).sum(1), unit((self.n[i] * w[..., None]).sum(1))

    def front(self, x, y):
        """Punto de delante en (x, y) y su marco (normal, arriba, derecha del que mira)."""
        m = np.where(self.O[:, 2] > 0.03)[0]
        _, k = cKDTree(self.O[m][:, :2]).query([x, y], k=4)
        p, n = self.project(self.O[m[k]].mean(0)[None])
        up = unit(np.array([0, 1.0, 0]) - n[0] * n[0][1])
        return p[0], (n[0], up, np.cross(up, n[0]))


def stripe(cloth, side):
    """Franja del cuello al puño: por encima del hombro y por fuera del brazo (en pose A, lo de arriba del brazo)."""
    a, s = sud.ARM[side], sud.SIDES[side]
    d1, d2 = unit(a["lower"] - a["upper"]), unit(a["hand"] - a["lower"])
    up1, up2 = unit(np.cross(d1, [0, 0, s * 1.0])), unit(np.cross(d2, [0, 0, s * 1.0]))
    up1, up2 = up1 * np.sign(up1[1]), up2 * np.sign(up2[1])
    guide = [[s * 0.07, 1.420, 0.0], [s * 0.12, 1.410, 0.0]]
    guide += [a["upper"] + (a["lower"] - a["upper"]) * t + up1 * 0.07 for t in np.linspace(0, 1, 8)]
    guide += [a["lower"] + (a["hand"] - a["lower"]) * t + up2 * 0.06 for t in np.linspace(0.1, 0.93, 8)]
    g = np.array(guide)
    s_ = np.r_[0, np.cumsum(np.linalg.norm(np.diff(g, axis=0), axis=1))]
    pts = np.stack([np.interp(np.arange(0, s_[-1], 0.006), s_, g[:, j]) for j in range(3)], 1)
    for _ in range(3):
        q, n = cloth.project(pts)
        for _ in range(8):
            q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        pts = q
    q, n = cloth.project(pts)
    for _ in range(6):                                                 # sin los dientes de la proyección
        q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        n[1:-1] = unit(0.5 * n[1:-1] + 0.25 * (n[:-2] + n[2:]))
    return tr.sweep(q + n * (LIFT + 0.0006), n, tr.rect(0, GOLD_T, STRIPE_W / 2))


def bar(p, frame, c, ang, length, width):
    n, up, right = frame
    ex = math.cos(ang) * right + math.sin(ang) * up
    ey = -math.sin(ang) * right + math.cos(ang) * up
    return casco.box(p + c[0] * right + c[1] * up + n * (LIFT + GOLD_T / 2), np.array([length / 2, width / 2, GOLD_T / 2]),
                     ex, ey, n)


def tri_corners(size, down=True):
    a = np.radians([270, 30, 150] if down else [90, 210, 330])
    return np.c_[np.cos(a), np.sin(a)] * size / math.sqrt(3)


def tri_outline(p, frame, c, size, width, down=True):
    k = tri_corners(size, down) + c
    out = []
    for i in range(3):
        a, b = k[i], k[(i + 1) % 3]
        mid, d = (a + b) / 2, b - a
        out.append(bar(p, frame, mid, math.atan2(d[1], d[0]), np.linalg.norm(d) + width, width))
    return out


def tri_filled(p, frame, c, size, down=True):
    n, up, right = frame
    k = tri_corners(size, down) + c
    base = p + np.outer(k[:, 0], right) + np.outer(k[:, 1], up)
    v = np.vstack([base + n * (LIFT + GOLD_T), base + n * LIFT])
    f = np.array([[0, 1, 2], [3, 5, 4], [0, 3, 1], [1, 3, 4], [1, 4, 2], [2, 4, 5], [2, 5, 0], [0, 5, 3]])
    return tr.orient_closed(v, f)


def emblems(cloth):
    out = []
    p, fr = cloth.front(0.0, 1.325)                                    # pecho: triángulo grande
    out += tri_outline(p, fr, (0, 0), 0.045, 0.0045)
    p, fr = cloth.front(0.0, 1.262)                                    # cuatro barritas en X
    for sx in (1, -1):
        for sy in (1, -1):
            out.append(bar(p, fr, (sx * 0.028, sy * 0.020), math.atan2(sy, sx), 0.020, 0.0035))
    for sx in (1, -1):                                                 # triangulito a cada lado de la ventana
        p, fr = cloth.front(sx * 0.068, 1.392)
        out += tri_outline(p, fr, (0, 0), 0.013, 0.0022)
    p, fr = cloth.front(0.0, 0.860)                                    # entrepierna: barra, ▼, ▼, ▽
    out.append(bar(p, fr, (0, 0.024), 0, 0.018, 0.0030))
    out.append(tri_filled(p, fr, (0, 0.008), 0.017))
    out.append(tri_filled(p, fr, (0, -0.010), 0.017))
    out += tri_outline(p, fr, (0, -0.028), 0.017, 0.0022)
    return out


# ---------------- montaje ----------------
def extras(O, F):
    cloth = Cloth(O, F)
    torso = (sud.main_bone != "Head") & (sud.arm_w < 0.3) & ~sud.hand_like
    neck = (P0[:, 1] > 1.36) & (sud.arm_w < 0.3)
    parts = [(turtleneck(), "tela", neck)]
    for side in ("Left", "Right"):
        arm = (np.sign(P0[:, 0]) == sud.SIDES[side]) & ~sud.hand_like & (sud.main_bone != "Head")
        parts.append((stripe(cloth, side), "detalle", arm))
    parts += [(e, "detalle", torso) for e in emblems(cloth)]
    return parts


def main():
    cuts = [ct.neck_top(NECK_Y), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), ct.window(*WINDOW),
            ct.bottom(FRONT_HW, BACK_HW)]
    ct.build(cuts, HERE / "packs" / "claude_bodysuit_dorado", "claude_bodysuit_dorado", "Bodysuit dorado (pruebas)",
             "bodysuit_dorado", "Bodysuit negro y dorado", [0.08, 0.08, 0.09], extras)


if __name__ == "__main__":
    main()
