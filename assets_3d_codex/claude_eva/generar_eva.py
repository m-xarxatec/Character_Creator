"""Traje espacial EVA sin casco (plano: planos/Vista técnica de traje espacial EVA sin casco.webp).

Uso:  python generar_eva.py   (en Linux: ~/.venvs/gamemolde_assets/bin/python generar_eva.py; necesita numpy y scipy)
Escribe packs/claude_evas/: traje_eva, **una sola pieza** de cuerpo entero con guantes y botas: ranura «ropa_exterior»,
cubre «ropa_torso», «ropa_piernas» y «ropa_pies». Sin mochila (decidido por el responsable).
Hecho como el kigurumi (usa las herramientas de la sudadera y del traje rosa): la piel entera (salvo cabeza y cuello)
copiada e hinchada, con los pesos y las formas del cuerpo por índice; así sigue a cualquier edición del cuerpo.
- Holgura: tronco 2,4 cm, brazos 2 cm, muslo 2,4 → pantorrilla 2,8 cm; guantes 2 mm (siguen a cada dedo); botas 1 cm
  (suela 4 mm), con los dedos alisados.
- Cuello: anillo metálico que encaja bajo el del casco de astronauta (claude_casco: mismos radios y altura). La parte
  alta queda dentro del anillo del casco; el reborde de abajo asoma. El traje sube de los hombros a ese reborde.
- Detalles en relieve: anillos de las muñecas, caja de mandos en el pecho con dos tubos a la cintura, cinturón con
  hebilla, hombreras, rodilleras, bolsillos en los muslos (con solapa) y la caña de las botas.
Zonas en COLOR_0: (0,0,0) tela; r = 1 gris (guantes, suelas, hombreras, rodilleras, cinturón, solapas, caña);
g = 1 metal (anillos, hebilla); b = 1 caja de mandos y tubos.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_chaqueta as ch
import generar_casco as casco

OUT = HERE / "packs" / "claude_evas"
PID = "traje_eva"

# --- medidas (metros) ---
OFF_TORSO, OFF_ARM, OFF_WRIST = 0.024, 0.020, 0.009
OFF_THIGH, OFF_CALF, OFF_SHAFT = 0.024, 0.028, 0.016
OFF_GLOVE, OFF_BOOT, OFF_SOLE = 0.002, 0.010, 0.004
OFF_COLLAR = 0.003                      # junto al anillo del cuello
LEG_GAP = 0.006                         # las perneras no pasan de x = ±6 mm
BOOT_T = 0.80                           # caña de la bota: a esta altura de la pierna (0 cadera, 1 tobillo)
WRIST_T = 0.90                          # anillo de la muñeca (0 codo, 1 muñeca)
SOLE_Y = 0.028                          # por debajo, la bota es suela (zona gris)
ZC = 0.02

# anillo del cuello, medido sobre el del casco de astronauta
CX, CZ = casco.C[0], casco.C[2]
RO, RI, YB = casco.RO, casco.RI, casco.Y_BOT
R_LIP, Y_LIP = RO + 0.003, YB - 0.007   # el borde del traje acaba en el reborde de abajo del anillo

P0, F0, SIDES, ARM = sud.P0, sud.F0, sud.SIDES, sud.ARM
ZONES = {"tela": (0, 0, 0, 1), "gris": (1, 0, 0, 1), "metal": (0, 1, 0, 1), "panel": (0, 0, 1, 1)}
LEG = {s: dict(hip=sud.joint_pos(s + "UpperLeg"), knee=sud.joint_pos(s + "LowerLeg"), ankle=sud.joint_pos(s + "Foot"))
       for s in SIDES}
for a in LEG.values():
    a["dir"] = (a["ankle"] - a["knee"]) / np.linalg.norm(a["ankle"] - a["knee"])
FINGERS = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")
HAND_W = sud.bone_weight([s + b for s in SIDES for b in ("Hand",)] +
                         [n for n in sud.JN if any(k in n for k in FINGERS[1:])])
ARM_W = sud.bone_weight([s + b for s in SIDES for b in ("UpperArm", "LowerArm")])
LEG_W = sud.bone_weight([s + b for s in SIDES for b in ("UpperLeg", "LowerLeg")])
FOOT_W = sud.bone_weight([s + b for s in SIDES for b in ("Foot", "Toes")])
HR = np.hypot(P0[:, 0] - CX, P0[:, 2] - CZ)                      # distancia al eje del anillo del cuello
NO_HEAD = sud.main_bone != "Head"
TORSO = NO_HEAD & (sud.arm_w < 0.3) & (LEG_W < 0.5) & (FOOT_W < 0.1)


def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def side_of(p, s):
    return np.sign(p[:, 0]) == SIDES[s]


# ---------------- 1. piel copiada e hinchada ----------------
def select_region():
    keep = NO_HEAD & (P0[:, 1] < YB) & ~((HR < R_LIP + 0.003) & (P0[:, 1] > YB - 0.05))
    faces = F0[keep[F0].all(1)]
    verts = np.unique(faces)
    remap = -np.ones(len(P0), int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def offsets(idx, v, nrm):
    """Holgura de cada vértice según el hueso que lo mueve (mezclada con los pesos)."""
    hw, aw, lw, fw = HAND_W[idx], ARM_W[idx], LEG_W[idx], FOOT_W[idx]
    t_arm, t_leg = np.zeros(len(v)), np.zeros(len(v))
    for s in SIDES:
        side = side_of(v, s)
        a, g = ARM[s], LEG[s]
        ta = (v - a["upper"]) @ (a["hand"] - a["upper"]) / np.sum((a["hand"] - a["upper"]) ** 2)
        tl = (v - g["hip"]) @ (g["ankle"] - g["hip"]) / np.sum((g["ankle"] - g["hip"]) ** 2)
        t_arm[side], t_leg[side] = ta[side], tl[side]
    off_arm = OFF_ARM + (OFF_WRIST - OFF_ARM) * smoothstep((t_arm - 0.80) / 0.17)
    off_leg = OFF_THIGH + (OFF_CALF - OFF_THIGH) * smoothstep((t_leg - 0.3) / 0.45)
    off_leg = off_leg + (OFF_SHAFT - off_leg) * smoothstep((t_leg - BOOT_T + 0.01) / 0.05)
    off_foot = np.where(nrm[:, 1] < -0.5, OFF_SOLE, OFF_BOOT)
    rest = np.clip(1 - hw - aw - lw - fw, 0, 1)
    off = OFF_TORSO * rest + aw * off_arm + hw * OFF_GLOVE + lw * off_leg + fw * off_foot
    near_ring = smoothstep((HR[idx] - R_LIP) / 0.08)                 # se estrecha al llegar al anillo
    return OFF_COLLAR + (off - OFF_COLLAR) * np.where(P0[idx, 1] > 1.2, near_ring, 1.0)


def separate_legs(v, x0, y0):
    m = (np.abs(x0) > 0.015) & (y0 < 0.88)
    sx = np.sign(x0[m])
    v[m, 0] = sx * np.maximum(sx * v[m, 0], LEG_GAP)
    return v


def to_lip(q):
    """Borde del cuello: sobre el círculo del reborde del anillo."""
    a = np.arctan2(q[:, 0] - CX, q[:, 2] - CZ)
    return np.c_[CX + R_LIP * np.sin(a), np.full(len(q), Y_LIP), CZ + R_LIP * np.cos(a)]


def build_shell():
    idx, f = select_region()
    loops = sud.boundary_loops(f)
    assert len(loops) == 1, [len(l) for l in loops]
    neck = loops[0]
    skin0 = P0[idx]
    nrm = sud.vertex_normals(skin0, f)
    off = offsets(idx, skin0, nrm)
    x0, y0 = skin0[:, 0].copy(), skin0[:, 1].copy()
    v = separate_legs(skin0 + nrm * off[:, None], x0, y0)
    v[neck] = to_lip(v[neck])
    hand = HAND_W[idx] > 0.5
    foot = FOOT_W[idx] > 0.3
    fixed = np.zeros(len(v), bool); fixed[neck] = True

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return separate_legs(v + nrm * np.maximum(0.6 * off - proj, 0)[:, None], x0, y0)

    for _ in range(5):
        v = keep_out(sud.taubin(v, f, fixed | hand, 10))
    for _ in range(6):                                               # botas: sin la forma de los dedos
        v = keep_out(sud.taubin(v, f, fixed | ~foot, 10))
    return idx, v, f


# ---------------- 2. piezas ----------------
def lathe_ring():
    """Anillo del cuello: reborde de abajo (asoma bajo el casco) y cuerpo alto (queda dentro del anillo del casco)."""
    prof = [(RI - 0.002, YB - 0.007), (RO + 0.002, YB - 0.007), (RO + 0.004, YB - 0.005), (RO + 0.004, YB - 0.002),
            (RO + 0.003, YB - 0.001), (RO - 0.0015, YB - 0.001), (RO - 0.0015, YB + 0.024), (RO - 0.0035, YB + 0.026),
            (RI + 0.0035, YB + 0.026), (RI + 0.0015, YB + 0.024), (RI + 0.0015, YB - 0.001), (RI - 0.002, YB - 0.001)]
    return casco.lathe([(r, y - casco.C[1]) for r, y in prof], casco.C, [0, 1, 0], 96)


def frame_of(axis):
    axis = axis / np.linalg.norm(axis)
    e1 = np.cross(axis, [0, 0, 1.0] if abs(axis[2]) < 0.9 else [1.0, 0, 0]); e1 /= np.linalg.norm(e1)
    return axis, e1, np.cross(axis, e1)


def band(shell, sel, center, axis, half, prof, n=72):
    """Banda alrededor de un tramo (cintura, muñeca, caña): sigue la sección del traje (radio máximo en cada ángulo
    dentro del tramo) y le da el perfil prof [(sobre el radio, a lo largo del eje)], cerrado."""
    axis, e1, e2 = frame_of(np.asarray(axis, float))
    d = shell[sel] - center
    ax = d @ axis
    m = np.abs(ax) < half + 0.006
    ang = np.arctan2(d[m] @ e2, d[m] @ e1)
    rad = np.linalg.norm(d[m] - np.outer(ax[m], axis), axis=1)
    bins = ((ang + math.pi) / (2 * math.pi) * n).astype(int) % n
    r = np.full(n, np.nan)
    for b in range(n):
        if (bins == b).any():
            r[b] = rad[bins == b].max()
    ok = ~np.isnan(r)
    k = np.arange(n)
    r = np.interp(k, np.r_[k[ok] - n, k[ok], k[ok] + n], np.tile(r[ok], 3))
    for _ in range(3):
        r = np.maximum(r, 0.5 * r + 0.25 * (np.roll(r, 1) + np.roll(r, -1)))
    th = (k + 0.5) / n * 2 * math.pi - math.pi
    u = np.outer(np.cos(th), e1) + np.outer(np.sin(th), e2)
    pr = np.asarray(prof, float)
    v = center + (r[:, None, None] + pr[None, :, 0, None]) * u[:, None, :] + pr[None, :, 1, None] * axis
    return tr.orient_closed(v.reshape(-1, 3), tr.ring_faces(n, len(pr), True))


def bevel_prof(h, out, inner=-0.002, b=0.002):
    return [(inner, -h), (out - b, -h), (out, -h + b), (out, h - b), (out - b, h), (inner, h)]


class Surface(ch.Surface):
    """Proyecta puntos 2D sobre el traje; con un marco propio si se da (en lo alto del hombro el «arriba» no sirve)."""
    def place(self, p, pts2d, lift, frame=None):
        if frame is None:
            n, up, right = self.frame(p)
        else:
            n, up, right = frame
        q = p + np.outer(pts2d[:, 0], right) + np.outer(pts2d[:, 1], up)
        d, i = self.kd.query(q, k=4)
        w = 1 / (d + 1e-4); w /= w.sum(1, keepdims=True)
        sp = (self.v[i] * w[..., None]).sum(1)
        sn = (self.n[i] * w[..., None]).sum(1); sn /= np.linalg.norm(sn, axis=1, keepdims=True)
        return sp + sn * lift, sn


def pad(surf, p, a, b, h, lift=0.0015, frame=None, K=6, M=36, edge=0.3):
    """Almohadilla elíptica (medias anchuras a × b) pegada a la superficie, de grosor h con el canto redondeado."""
    ang = np.linspace(0, 2 * math.pi, M, endpoint=False)
    rr = np.linspace(0, 1, K + 1)[1:]
    pts = np.vstack([[0, 0], np.concatenate([np.c_[a * r * np.cos(ang), b * r * np.sin(ang)] for r in rr])])
    rad = np.r_[0, np.repeat(rr, M)]
    base, sn = surf.place(p, pts, lift, frame)
    top = base + sn * (h * np.sqrt(np.clip((1 - rad) / edge, 0, 1)))[:, None]
    i = np.arange(M)
    f = [np.stack([np.zeros(M, int), 1 + i, 1 + (i + 1) % M], -1)]
    for k in range(K - 1):
        a0, b0 = 1 + k * M + i, 1 + k * M + (i + 1) % M
        f += [np.stack([a0, a0 + M, b0], -1), np.stack([b0, a0 + M, b0 + M], -1)]
    f = np.concatenate(f)
    n = len(top)
    return tr.orient_closed(np.vstack([top, base - sn * 0.001]), np.concatenate([f, f[:, ::-1] + n]))


def tube(pts, up, radius, ribs=0.012, m=10):
    """Tubo corrugado a lo largo de pts (con tapas)."""
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    r = radius * (1 + 0.10 * np.cos(s / ribs * 2 * math.pi))
    t = np.gradient(pts, axis=0); t /= np.linalg.norm(t, axis=1, keepdims=True)
    u = up - t * (up * t).sum(1, keepdims=True); u /= np.linalg.norm(u, axis=1, keepdims=True)
    b = np.cross(t, u)
    a = np.linspace(0, 2 * math.pi, m, endpoint=False)
    rings = pts[:, None] + r[:, None, None] * (np.cos(a)[None, :, None] * u[:, None] + np.sin(a)[None, :, None] * b[:, None])
    v, f = rings.reshape(-1, 3), tr.ring_faces(len(pts), m, False)
    i, n = np.arange(m), len(pts)
    v = np.vstack([v, pts[0], pts[-1]])
    f = np.concatenate([f, np.stack([np.full(m, len(v) - 2), (i + 1) % m, i], -1),
                        np.stack([np.full(m, len(v) - 1), (n - 1) * m + i, (n - 1) * m + (i + 1) % m], -1)])
    return tr.orient_closed(v, f)


def catmull(ctrl, per=12):
    c = np.vstack([ctrl[0], ctrl, ctrl[-1]])
    out = []
    for k in range(1, len(c) - 2):
        p0, p1, p2, p3 = c[k - 1:k + 3]
        for t in np.linspace(0, 1, per, endpoint=False):
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ** 2
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    return np.vstack([out, ctrl[-1]])


def on_surface(surf, pts, lift):
    d, i = surf.kd.query(pts, k=6)
    w = 1 / (d + 1e-4); w /= w.sum(1, keepdims=True)
    sp = (surf.v[i] * w[..., None]).sum(1)
    sn = (surf.n[i] * w[..., None]).sum(1); sn /= np.linalg.norm(sn, axis=1, keepdims=True)
    return sp + sn * lift, sn


def front_point(v, x, y):
    return ch.surface_point(v, x, y, front=True)


def details(shell, f, idx):
    """Lista de (malla, zona, máscara de piel de la que toma pesos y formas)."""
    surf = Surface(shell, f)
    torso_shell = (sud.arm_w[idx] < 0.3) & (HAND_W[idx] < 0.1)      # el reposo es en A: las manos llegan a la cintura
    rigid = ("rigida", TORSO)                                        # cajas: se mueven enteras, sin deformarse
    out = [(lathe_ring(), "metal", np.isin(sud.main_bone, ["UpperChest", "Chest", "LeftShoulder", "RightShoulder"]))]
    # cinturón y hebilla
    belt_y = 1.00
    sel = torso_shell & (np.abs(shell[:, 1] - belt_y) < 0.04)
    out.append((band(shell, sel, np.array([0, belt_y, ZC]), [0, 1, 0], 0.018, bevel_prof(0.018, 0.006)), "gris",
                TORSO | (LEG_W > 0)))
    pb = front_point(shell, 0.0, belt_y)
    nb = surf.frame(pb)[0]
    out.append((casco.box(pb + nb * 0.010, [0.026, 0.020, 0.004], [1, 0, 0], [0, 1, 0], nb), "metal", rigid))
    # caja de mandos en el pecho
    pc = front_point(shell, 0.0, 1.235)
    n_c, up_c, right_c = surf.frame(pc)
    n_c = np.array([0, 0.25 * n_c[1], 1.0]); n_c /= np.linalg.norm(n_c)
    up_c = np.array([0, 1.0, 0]) - n_c * n_c[1]; up_c /= np.linalg.norm(up_c)
    right_c = np.cross(up_c, n_c)
    box_c = pc + n_c * 0.030
    out.append((casco.box(box_c, [0.055, 0.038, 0.024], right_c, up_c, n_c), "panel", rigid))
    out.append((casco.box(box_c + n_c * 0.024 + up_c * 0.010, [0.030, 0.014, 0.002], right_c, up_c, n_c), "metal",
                rigid))
    # tubos: de los lados de la caja a los costados del cinturón
    for sx in (1, -1):
        start = box_c + right_c * (sx * 0.040) - up_c * 0.040
        ctrl = [front_point(shell, sx * x, y) for x, y in ((0.075, 1.15), (0.12, 1.09), (0.15, 1.04))]
        ctrl = np.vstack([start, on_surface(surf, np.array(ctrl), 0.012)[0]])
        path = catmull(ctrl)
        q, sn = on_surface(surf, path, 0.012)
        q[:3] = path[:3]
        out.append((tube(q, sn, 0.010), "panel", TORSO))
    # por cada lado: muñeca, hombrera, rodillera, bolsillo y caña de la bota
    for s, sx in SIDES.items():
        a, g = ARM[s], LEG[s]
        side = side_of(shell, s)
        arm_side = side_of(P0, s) & NO_HEAD & ((sud.arm_w > 0.3) | sud.hand_like)
        leg_side = side_of(P0, s) & ((LEG_W > 0.3) | (FOOT_W > 0.3))
        cw = a["lower"] + (a["hand"] - a["lower"]) * WRIST_T
        sel = side & (np.abs(shell[:, 0]) > np.abs(a["lower"][0]))
        prof = [(-0.003, -0.011), (0.003, -0.011), (0.005, -0.009), (0.005, -0.002), (0.003, -0.001), (0.003, 0.001),
                (0.005, 0.002), (0.005, 0.009), (0.003, 0.011), (-0.003, 0.011)]
        out.append((band(shell, sel, cw, a["dir"], 0.011, prof), "metal", arm_side))
        ps = a["upper"] + np.array([-sx * 0.005, 0.0, 0.0])
        top = shell[side & (np.abs(shell[:, 0] - ps[0]) < 0.02) & (np.abs(shell[:, 2] - ps[2]) < 0.03)]
        ptop = top[np.argmax(top[:, 1])]
        out.append((pad(surf, ptop, 0.045, 0.040, 0.006, frame=(np.array([0, 1.0, 0]), np.array([0, 0, 1.0]),
                                                                   np.array([sx * 1.0, 0, 0]))), "gris",
                    side_of(P0, s) & NO_HEAD & (sud.main_bone != "Neck")))
        pk = front_point(shell, g["knee"][0], g["knee"][1] - 0.01)
        out.append((pad(surf, pk, 0.045, 0.055, 0.010), "gris", leg_side))
        pp = front_point(shell, g["hip"][0] + sx * 0.055, 0.58)
        out.append((pad(surf, pp, 0.050, 0.060, 0.012, edge=0.15), "tela", leg_side))
        out.append((pad(surf, pp + np.array([0, 0.050, 0]), 0.052, 0.016, 0.014, edge=0.15), "gris", leg_side))
        # costuras acolchadas: dos aros en el brazo, dos en el antebrazo, dos en el muslo y uno en la espinilla
        arm_shell = side & (sud.arm_w[idx] > 0.5)
        leg_shell = side & (LEG_W[idx] > 0.5)
        for t, p0, p1 in ((0.45, a["upper"], a["lower"]), (0.72, a["upper"], a["lower"]),
                          (0.35, a["lower"], a["hand"]), (0.62, a["lower"], a["hand"])):
            c = p0 + (p1 - p0) * t                                   # sobre el eje de su tramo (el codo va doblado)
            out.append((band(shell, arm_shell, c, p1 - p0, 0.004, bevel_prof(0.004, 0.0035, b=0.0015)), "tela",
                        arm_side))
        for t in (0.18, 0.30, 0.66):
            c = g["hip"] + (g["ankle"] - g["hip"]) * t
            out.append((band(shell, leg_shell, c, g["ankle"] - g["hip"], 0.004, bevel_prof(0.004, 0.0035, b=0.0015)),
                        "tela", leg_side))
        cb = g["hip"] + (g["ankle"] - g["hip"]) * BOOT_T
        sel = side & (shell[:, 1] < g["knee"][1]) & (shell[:, 1] > g["ankle"][1] + 0.03)
        out.append((band(shell, sel, cb, g["dir"], 0.016, bevel_prof(0.016, 0.006)), "gris", leg_side))
    return out


# ---------------- 3. montaje y .glb ----------------
def build():
    idx, shell, f_shell = build_shell()
    verts, faces, zones, src_idx, src_w = [], [], [], [], []

    def add(v, f, zone, skin_idx=None, mask=None):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)) if isinstance(zone, str) else zone)
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        elif isinstance(mask, tuple):                                # rígida: los mismos 8 puntos de piel para todo
            near = np.unique(sud.nearest_skin(v, 2, mask[1])[0][:, 0])
            pick = near[np.linspace(0, len(near) - 1, 8).astype(int)]
            src_idx.append(np.tile(pick, (len(v), 1))); src_w.append(np.full((len(v), 8), 1 / 8))
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    grey = (HAND_W[idx] > 0.5) | ((FOOT_W[idx] > 0.3) & (shell[:, 1] < SOLE_Y))      # guantes y suelas
    zc = np.where(grey[:, None], ZONES["gris"], ZONES["tela"])
    add(shell, f_shell, zc, skin_idx=idx)
    for (v, f), zone, mask in details(shell, f_shell, idx):
        add(v, f, zone, mask=mask)
    v, f = np.concatenate(verts), np.concatenate(faces)
    return write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w))


def write(v, f, zc, si, sw):
    joints, weights = sud.blend_weights(si, sw)
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights); weights /= weights.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = build()
    cards = [tr.card(PID, "Traje espacial EVA", sha, [0.90, 0.90, 0.88], "ropa", "ropa_exterior",
                     ["ropa_torso", "ropa_piernas", "ropa_pies"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_evas", "nombre": "Trajes espaciales (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
