"""Horma de calzado propia (pie izquierdo; el derecho se refleja): la forma sale de perfiles, no de la piel del pie.

Una caja del pie de sección supereléptica (punta redonda, talón recto, planta plana) unida en suave a una caña elíptica
alrededor de la pierna. La malla se saca con rayos desde un eje que baja por la pierna, se curva en el tobillo y sigue
hasta la punta: rejilla limpia (filas × NA columnas + un polo en la punta), abierta solo en la boca.
La usan las zapatillas futuristas, las zapatillas altas y las botas medievales; cada una da sus medidas (ver Horma).
"""
import math
import numpy as np

import generar_sudadera as sud
import generar_traje as tr


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


class Horma:
    """Medidas en metros. Perfiles del pie a lo largo de z: pz, pw (media anchura), pc (centro x), pt (alto).
    Caña: tablas por altura y del eje de la pierna (axis_x, axis_z) y de sus medios ejes (ax fuera, az delante)."""
    fx = 0.187
    pz = [-0.046, -0.020, 0.020, 0.060, 0.100, 0.140, 0.175, 0.205, 0.236]
    pw = [0.036, 0.039, 0.042, 0.047, 0.054, 0.057, 0.055, 0.049, 0.042]
    pc = [0.185, 0.186, 0.187, 0.189, 0.190, 0.189, 0.187, 0.184, 0.181]
    pt = [0.080, 0.084, 0.088, 0.092, 0.077, 0.066, 0.061, 0.058, 0.055]
    heel_r, toe_r, fp = 0.030, 0.042, 2.4
    axis_y, axis_x, axis_z = [-0.2, 1.0], [0.203, 0.131], [0.050, -0.070]
    shaft_y, shaft_ax, shaft_az, sp = [-0.2, 0.09, 1.0], [0.044, 0.044, 0.041998], [0.055, 0.055, 0.0524975], 2.3
    blend, y_bot = 0.08, -0.002
    collar = (0.152, 0.007, 0.004)                     # boca: altura delante, cuánto sube detrás, cuánto baja a los lados
    fold = None                                        # arrugas: fold(y, ángulo) → fracción que crece la caña
    na, n_shaft, n_arc, n_foot, n_toe = 72, 16, 28, 24, 8
    y_b, r_arc, pe_z = 0.094, 0.072, 0.196

    def __init__(self, **kw):
        for k, v in kw.items():
            assert hasattr(self, k), k
            setattr(self, k, v)
        self.th = np.linspace(-math.pi, math.pi, self.na, endpoint=False)   # 0 delante (o arriba), +90° fuera
        self.j0 = self.na // 2

    # --- forma ---
    def leg_axis(self, y):
        return np.interp(y, self.axis_y, self.axis_x), np.interp(y, self.axis_y, self.axis_z)

    def collar_y(self, th):
        y0, back, dip = self.collar
        return y0 + back * (1 - np.cos(th)) / 2 - dip * np.sin(th) ** 2

    def ends(self, z):
        z0, z1 = self.pz[0], self.pz[-1]
        h = np.clip((z0 + self.heel_r - z) / self.heel_r, 0, 1)
        t = np.clip((z - (z1 - self.toe_r)) / self.toe_r, 0, 1)
        return (1 - h ** 4) ** 0.25 * np.sqrt(1 - t ** 2) * ((z > z0) & (z < z1))

    def field(self, p):
        """< 1 dentro de la horma."""
        x, y, z = p[:, 0], p[:, 1], p[:, 2]
        e = self.ends(z)
        W = np.interp(z, self.pz, self.pw) * e + 1e-9
        T = np.interp(z, self.pz, self.pt) * np.sqrt(e) + 1e-9
        g1 = ((np.abs(x - np.interp(z, self.pz, self.pc)) / W) ** self.fp + (np.maximum(y, 0) / T) ** self.fp) ** (1 / self.fp)
        g1 = np.where(e > 1e-4, g1, 1e3)
        xc, zc = self.leg_axis(y)
        k = 1.0 if self.fold is None else 1 + self.fold(y, np.arctan2(x - xc, z - zc))
        ax, az = np.interp(y, self.shaft_y, self.shaft_ax) * k, np.interp(y, self.shaft_y, self.shaft_az) * k
        g2 = ((np.abs(x - xc) / ax) ** self.sp + (np.abs(z - zc) / az) ** self.sp) ** (1 / self.sp)
        g = -self.blend * np.logaddexp(-g1 / self.blend, -g2 / self.blend)
        return np.where(y < self.y_bot, 1e3, g)

    def cast(self, O, D, step=0.0015, n=130, strict=True):
        """Primer punto donde cada rayo sale de la horma (si no strict, el que no sale se queda en su tope)."""
        shape = O.shape
        O, D = O.reshape(-1, 3), D.reshape(-1, 3)
        assert (self.field(O) < 1).all()
        s = np.arange(1, n + 1) * step
        out = self.field((O[:, None] + D[:, None] * s[None, :, None]).reshape(-1, 3)).reshape(len(O), n) >= 1
        if strict:
            assert out.any(1).all()
        else:
            out[:, -1] = True
        k = out.argmax(1)
        lo, hi = np.where(k > 0, s[k - 1], 0.0), s[k]
        for _ in range(24):
            mid = 0.5 * (lo + hi)
            o = self.field(O + D * mid[:, None]) >= 1
            hi, lo = np.where(o, mid, hi), np.where(o, lo, mid)
        return (O + D * (0.5 * (lo + hi))[:, None]).reshape(shape)

    # --- malla ---
    def rays(self):
        TH, NA = self.th, self.na
        X, UP = np.array([1.0, 0, 0]), np.array([0, 1.0, 0])
        O, D = [], []
        yc = self.collar_y(TH)
        for f in np.linspace(0, 1, self.n_shaft, endpoint=False):        # caña: planos horizontales
            y = yc + f * (self.y_b - yc)
            xc, zc = self.leg_axis(y)
            O.append(np.stack([xc, y, zc], 1)); D.append(np.stack([np.sin(TH), 0 * TH, np.cos(TH)], 1))
        xb, zb = self.leg_axis(self.y_b)
        R = self.r_arc
        for g in np.linspace(0, math.pi / 2, self.n_arc, endpoint=False):  # tobillo: los planos giran hacia delante
            p = [xb + (self.fx - xb) * g / (math.pi / 2), self.y_b - R * math.sin(g), zb + R * (1 - math.cos(g))]
            N = np.array([0, math.sin(g), math.cos(g)])
            O.append(np.tile(p, (NA, 1))); D.append(np.outer(np.cos(TH), N) + np.outer(np.sin(TH), X))
        ye, ze = self.y_b - R, zb + R
        for z in np.linspace(ze, self.pe_z, self.n_foot):                # pie
            O.append(np.tile([self.fx, ye, z], (NA, 1))); D.append(np.outer(np.cos(TH), UP) + np.outer(np.sin(TH), X))
        for b in np.arange(1, self.n_toe + 1) / (self.n_toe + 1) * math.pi / 2:   # punta: media cúpula hasta el polo
            O.append(np.tile([self.fx, ye, self.pe_z], (NA, 1)))
            D.append(math.cos(b) * (np.outer(np.cos(TH), UP) + np.outer(np.sin(TH), X)) + math.sin(b) * np.array([0, 0, 1.0]))
        return np.array(O), unit(np.array(D)), np.array([self.fx, ye, self.pe_z])

    def build_shell(self):
        """Cara de fuera: (vértices, caras, filas). Las primeras NA son la boca; el último, el polo de la punta."""
        NA = self.na
        O, D, pe = self.rays()
        G = self.cast(O, D)
        pole = self.cast(pe[None], np.array([[0, 0, 1.0]]))[0]
        R = len(G)
        v = np.vstack([G.reshape(-1, 3), pole])
        f = tr.ring_faces(R, NA, False)
        i = np.arange(NA)
        last = (R - 1) * NA
        f = np.concatenate([f, np.stack([last + i, np.full(NA, R * NA), last + (i + 1) % NA], -1)])
        fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
        if np.einsum("ij,ij->", fn, v[f].mean(1) - np.r_[self.fx, 0.04, 0.08]) < 0:
            f = f[:, ::-1]
        fixed = np.zeros(len(v), bool); fixed[:NA] = True; fixed[-1] = True
        v = sud.taubin(v, f, fixed, 4)
        return v, f, R

    def lining(self, v, f, rows, thick, lift=0.0):
        """Forro (cara de dentro) de las primeras filas y canto redondo en la boca (lift: relieve de lo de fuera)."""
        NA = self.na
        n = sud.vertex_normals(v, f)
        inner = v[:rows * NA] - n[:rows * NA] * thick
        fi = tr.ring_faces(rows, NA, False)
        m = inner[fi].mean(1)
        xc, zc = self.leg_axis(m[:, 1])
        fn = np.cross(inner[fi[:, 1]] - inner[fi[:, 0]], inner[fi[:, 2]] - inner[fi[:, 0]])
        if np.einsum("ij,ij->", fn, m - np.c_[xc, m[:, 1], zc]) > 0:
            fi = fi[:, ::-1]
        top_o, top_i = v[:NA] + n[:NA] * lift, inner[:NA]
        mid = 0.5 * (top_o + top_i) + np.array([0, thick * 0.6, 0])
        lip = np.vstack([top_o, mid, top_i])
        fl = tr.ring_faces(3, NA, False)
        fn = np.cross(lip[fl[:, 1]] - lip[fl[:, 0]], lip[fl[:, 2]] - lip[fl[:, 0]])
        if fn[:, 1].sum() < 0:
            fl = fl[:, ::-1]
        return (inner, fi), (lip, fl)

    def leg_ray_point(self, y, th, lift):
        """Punto de la caña a la altura y y el ángulo th, despegado lift (rayo horizontal desde el eje)."""
        xc, zc = self.leg_axis(y)
        O = np.stack([xc, y, zc], -1).reshape(-1, 3)
        D = np.stack([np.sin(th), 0 * th, np.cos(th)], -1).reshape(-1, 3)
        p = self.cast(O, D)
        return (p + D * np.asarray(lift).reshape(-1, 1)).reshape(np.shape(y) + (3,)), D.reshape(np.shape(y) + (3,))


def mirror_both(v, f):
    """La horma de los dos pies en una malla: el izquierdo y su reflejo."""
    vr = v * [-1, 1, 1]
    return np.vstack([v, vr]), np.concatenate([f, f[:, ::-1] + len(v)])
