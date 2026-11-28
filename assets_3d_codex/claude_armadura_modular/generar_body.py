"""Armadura modular, pieza 1: body azul con mallas marrones (plano: planos/armadura_modular.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_body.py
Escribe packs/claude_armadura_modular/armadura_body.glb (ranura «ropa_torso», cubre «ropa_piernas») y su ficha en el
pack.json (el pack lleva 3 piezas: body, chaqueta y acero; decidido por el responsable).
Generador de maillots (claude_bodysuits/cortes.py): la piel recortada, pegada al cuerpo, de una cara.
- Body azul: dos aberturas bajo el pecho, las mismas que las del peto (pack_modular.HOLE: con el peto puesto se ve la
  piel, como el plano; decidido por el responsable); cuello redondo, mangas marrones hasta la muñeca (la misma tela, otra zona), delante V alta y detrás
  tanga; paneles marrones en los costados (más hacia dentro en la cintura) y ribete marrón en el cuello y las piernas.
  Cada borde de color, cortado justo por su línea (zonas.py): nítido, sin escalera.
- Cinturón marrón en relieve a la cintura, con hebilla cuadrada delante.
- Mallas marrones con pie: otra capa, más pegada, que sube por debajo del body.
Zonas en COLOR_0: (0,0,0) azul; r = 1 marrón; g = 1 metal (hebilla).
"""
import sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_bodysuits", "claude_casco"):
    sys.path.insert(0, str(HERE.parent / d))
import cortes as ct
import generar_top_arnes as ta
import generar_bodysuit_dorado as dor
import generar_casco as casco
import pack_modular as pm
import zonas

sud, tr, bk, P0, F0 = ct.sud, ct.tr, ct.bk, ct.P0, ct.F0
ct.ZONES.update({"azul": (0, 0, 0, 1), "marron": (1, 0, 0, 1), "metal": (0, 1, 0, 1)})
BLUE, BROWN = np.array(ct.ZONES["azul"], float), np.array(ct.ZONES["marron"], float)
PID = "armadura_body"

# --- body ---
NECK = (1.395, 0.3, 0.090, 0.080, 0.020)        # cuello redondo: plano y − 0,3·z, elipse (rx, rz) en z = 0,02
SLEEVE_T = 1.97                                 # mangas hasta la muñeca
FRONT_HW = [(0.77, 0.008), (0.80, 0.012), (0.86, 0.035), (0.92, 0.068), (0.98, 0.105), (1.03, 0.140), (1.07, 0.25)]
BACK_HW = [(0.77, 0.006), (0.85, 0.008), (0.89, 0.030), (0.94, 0.065), (0.99, 0.105), (1.03, 0.140), (1.07, 0.25)]
TRIM_W = 0.010                                  # ribete marrón del cuello y las piernas
PANEL_F = [(0.90, 62), (1.00, 58), (1.08, 48), (1.18, 56), (1.30, 72), (1.45, 80)]    # borde de delante (grados)
PANEL_B = [(0.90, 140), (1.45, 128)]           # borde de detrás
# --- cinturón ---
BELT_Y = [(0, 1.000), (90, 1.020), (180, 1.035)]   # (grados, y): baja un poco delante
BELT_H, BELT_T, BELT_GAP = 0.018, 0.0030, 0.0035   # media altura, grosor, sobre el body
BUCKLE = (0.030, 0.026, 0.0045, 0.0035)          # media anchura, media altura, ancho de la barra, grosor
# --- mallas ---
MALLAS_GAP = 0.0012
MALLAS_TOP = [(0, 1.00), (60, 1.04), (90, 1.10), (120, 1.08), (150, 1.03), (180, 1.00)]
AXIS_Z = [(0.90, 0.020), (0.97, 0.045), (1.22, 0.045)]
MIN_MOVE = 0.0005


# ---------------- body ----------------
def panel_field(V):
    """> 0 en los paneles de los costados (en metros, más o menos: 1° ≈ 1,5 mm)."""
    phi, y = ta.phi_of(V[:, :3]), V[:, 1]
    return np.minimum(phi - np.interp(y, *zip(*PANEL_F)), np.interp(y, *zip(*PANEL_B)) - phi) * 0.0015


def brown_field(O, si, sw, loops):
    """> 0 en lo marrón: mangas, paneles y ribete del cuello, las piernas y las aberturas."""
    arm = ((sud.arm_w[si] * sw).sum(1) - 0.5) * 0.05
    edges = [lp for lp in loops if O[lp][:, 1].mean() < 1.5 and arm[lp].mean() < 0]
    trim = TRIM_W - cKDTree(np.vstack([O[lp] for lp in edges])).query(O)[0]
    return np.maximum.reduce([arm, panel_field(O), trim])


def body_sheet(cuts):
    """La tela del body con el borde de cada zona cortado justo por su línea (nítido, sin escalera)."""
    O, F, loops, si, sw = ct.sheet(cuts)
    F2, new, brown = zonas.split(F, brown_field(O, si, sw, loops))
    O2 = zonas.lerp(O, new)
    si2, sw2 = zonas.lerp_skin(si, sw, new)
    return (O, F, loops, si, sw), (O2, F2, si2, sw2, np.where(brown[:, None], BROWN, BLUE))


# ---------------- cinturón ----------------
def belt(O, F):
    degs = np.r_[np.linspace(0, 180, 37), np.linspace(180, 0, 37)[1:]]
    sides = np.r_[np.ones(37), -np.ones(36)]
    pts = np.array([ta.ray_skin(d, np.interp(d, *zip(*BELT_Y)), s) for d, s in zip(degs, sides)])
    cloth = dor.Cloth(O, F)                                            # sobre la tela del body (detrás hace
    q, n = cloth.project(pts)                                          # de puente sobre la espalda baja)
    q, n = ta.smooth_line(q, n, 3)
    d, k = cloth.kd.query(q, k=8)
    s = np.einsum("ijk,ijk->ij", q[:, None] - cloth.O[k], cloth.n[k]).min(1)
    pts = q + n * (np.maximum(-s, 0) + BELT_GAP - 0.0025)[:, None]
    pts = np.vstack([pts, pts[1:3]])                                   # cierra el lazo (solapa un poco)
    n = np.vstack([n, n[1:3]])
    v, f = tr.sweep(pts, n, tr.rect(0, BELT_T, BELT_H))
    hw, hh, bw, th = BUCKLE
    c, nn = pts[0], n[0]
    ex = ct.unit(np.cross([0, 1.0, 0], nn))
    ey = np.cross(nn, ex)
    base = c + nn * (BELT_T + th / 2)
    bars = [casco.box(base + ey * (hh - bw / 2), [hw, bw / 2, th / 2], ex, ey, nn),
            casco.box(base - ey * (hh - bw / 2), [hw, bw / 2, th / 2], ex, ey, nn),
            casco.box(base + ex * (hw - bw / 2), [bw / 2, hh, th / 2], ex, ey, nn),
            casco.box(base - ex * (hw - bw / 2), [bw / 2, hh, th / 2], ex, ey, nn),
            casco.box(base + ex * 0.004, [0.0015, hh * 0.9, th * 0.7], ex, ey, nn)]        # hebijón
    torso = (sud.arm_w < 0.3) & ~sud.hand_like & (np.abs(P0[:, 1] - 1.02) < 0.08)
    out = [((v, f), "marron", torso, np.full(len(v), BELT_GAP), MIN_MOVE)]
    out += [(b, "metal", torso, np.full(len(b[0]), BELT_GAP), 0.006) for b in bars]
    return out


# ---------------- mallas ----------------
def mallas_cut(V):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    phi = np.degrees(np.arctan2(np.abs(x), z - np.interp(y, *zip(*AXIS_Z))))
    f = y - np.interp(phi, *zip(*MALLAS_TOP))
    return np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, 1.0, f)


def mallas():
    V, F, loops = ct.cut_skin([mallas_cut], (-0.05, 1.15))
    q, si, sw, n = bk.on_skin(V)
    O = bk.to_edges(q + n * MALLAS_GAP, loops)
    q, si, sw, n = bk.on_skin(O)
    h = ((O - q) * n).sum(1)
    print("MEDIDA mallas: %d vértices; a la piel mín %.1f mm; de y = %.3f a %.3f" % (
        len(O), 1000 * h[h > MALLAS_GAP * 0.9].min(), O[:, 1].min(), O[:, 1].max()))
    return (O, F), "marron", (ct.pad8(si), ct.pad8(sw)), h, MIN_MOVE


def extras(O, F):
    return [mallas()] + belt(O, F)


def main():
    old = pm.cards()
    cuts = [ct.neck_round(*NECK), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T),
            ct.bottom(FRONT_HW, BACK_HW), pm.chest_hole]
    pm.OUT.mkdir(parents=True, exist_ok=True)
    bk.OUT = pm.OUT
    (O, F, loops, si, sw), (v, f, i, w, Z0) = body_sheet(cuts)
    V, Fs, Z, I, W = [v], [f], [Z0], [ct.pad8(i)], [ct.pad8(w)]
    H = [((v - (P0[i] * w[..., None]).sum(1)) * bk.normal_at(bk.SKIN_N, i, w)).sum(1)]
    M = [np.full(len(v), MIN_MOVE)]
    for (pv, pf), zone, src, h, mm in extras(O, F):                  # como cortes.build
        pv = np.asarray(pv, float)
        pi, pw = src if isinstance(src, tuple) else sud.nearest_skin(pv, 8, src)
        Fs.append(np.asarray(pf, int) + sum(len(x) for x in V))
        V.append(pv); I.append(ct.pad8(pi)); W.append(ct.pad8(pw))
        Z.append(np.tile(ct.ZONES[zone], (len(pv), 1)))
        H.append(h); M.append(np.full(len(pv), mm))
    sha, targets = bk.write(np.concatenate(V), np.concatenate(Fs), np.concatenate(Z), np.concatenate(I),
                            np.concatenate(W), np.concatenate(H), PID, np.concatenate(M))
    ct.measure(O, F, loops, si, sw, targets)
    card = tr.card(PID, "Body azul con mallas (armadura modular)", sha, [0.20, 0.29, 0.40], "ropa", "ropa_torso",
                   ["ropa_piernas"])
    pm.save(old, [card])


if __name__ == "__main__":
    main()
