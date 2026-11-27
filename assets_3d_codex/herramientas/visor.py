"""Visor rápido de un asset: render ortográfico (6 vistas) con el cuerpo en gris y las caras traseras en rojo puro.

Uso:  ~/.venvs/gamemolde_assets/bin/python -I herramientas/visor.py archivo.glb salida.png [opciones]
  --centro x y z    centro de la imagen (por defecto 0 1.0 0)
  --ancho m         media anchura de lo que se ve (por defecto 0.9)
  --desde y         solo el cuerpo por encima de esta altura (por defecto 0)
  --solo-izq        solo lo que está en x > 2 cm (calzado y guantes: un lado)
  --px n            píxeles de cada vista (por defecto 360)
Sirve para la revisión propia de la receta: caras al revés (rojo puro), huecos y la forma general.
Zonas de COLOR_0 → colores fijos (ZONE_RGB); no son los del asset, solo para distinguirlas.
"""
import sys, zlib, struct, argparse
from pathlib import Path
import numpy as np

BASE = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(BASE / "claude_gorra"), str(BASE / "claude_sudadera")]
import glb
import generar_sudadera as sud

ZONE_RGB = {(0, 0, 0): (0.90, 0.88, 0.86), (1, 0, 0): (0.95, 0.55, 0.15), (0, 1, 0): (0.72, 0.74, 0.80),
            (0, 0, 1): (0.30, 0.45, 0.90), (1, 1, 0): (0.95, 0.82, 0.25), (1, 0, 1): (0.30, 0.28, 0.32),
            (0, 1, 1): (0.20, 0.75, 0.70), (1, 1, 1): (0.15, 0.15, 0.17)}
BACK_RGB = np.array([1.0, 0, 0])
VIEWS = [(0, 0.1, 1), (0, 0.1, -1), (1, 0.1, 0.05), (0.7, 0.5, 1), (-0.7, 0.4, -1), (0.2, 1, 0.3)]


def load(path):
    doc, buf = glb.read(path)
    d = glb.mesh_data(doc, buf, False)
    v, f = d["POSITION"].astype(float), d["indices"].reshape(-1, 3)
    c = np.round(d["COLOR_0"][:, :3]).astype(int) if "COLOR_0" in d else np.zeros((len(v), 3), int)
    return v, f, np.array([ZONE_RGB.get(tuple(x), (0.2, 0.9, 0.2)) for x in c])


def render(meshes, view, px, ext, ctr):
    """meshes: [(v, f, colores por vértice o None = cuerpo gris)]."""
    eye = np.array(view, float); eye /= np.linalg.norm(eye)
    up0 = np.array([0, 0, -1.0]) if abs(eye[1]) > 0.9 else np.array([0, 1.0, 0])
    right = np.cross(up0, eye); right /= np.linalg.norm(right)
    up = np.cross(eye, right)
    img = np.ones((px, px, 3)); zb = np.full((px, px), -1e9)
    for V, F, C in meshes:
        P = V - ctr
        sx = ((P @ right) / ext * 0.5 + 0.5) * px
        sy = (0.5 - (P @ up) / ext * 0.5) * px
        dep = P @ eye
        n = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
        n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
        front = n @ eye
        for t in range(len(F)):
            i = F[t]
            xs, ys = sx[i], sy[i]
            x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, px - 1)
            y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, px - 1)
            if x0 > x1 or y0 > y1:
                continue
            X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
            if abs(d) < 1e-9:
                continue
            a = ((xs[1] - X) * (ys[2] - Y) - (xs[2] - X) * (ys[1] - Y)) / d
            b = ((xs[2] - X) * (ys[0] - Y) - (xs[0] - X) * (ys[2] - Y)) / d
            c = 1 - a - b
            m = (a >= -1e-6) & (b >= -1e-6) & (c >= -1e-6)
            z = a * dep[i[0]] + b * dep[i[1]] + c * dep[i[2]]
            sub = zb[y0:y1 + 1, x0:x1 + 1]
            m &= z > sub
            if not m.any():
                continue
            sub[m] = z[m]
            if C is None:
                rgb = np.array([0.55, 0.55, 0.6]) * (0.5 + 0.5 * abs(front[t]))
            elif front[t] < 0:
                rgb = BACK_RGB
            else:
                rgb = C[i].mean(0) * (0.55 + 0.45 * max(0, n[t] @ (eye * 0.6 + up * 0.5 + right * 0.3) / 0.85))
            img[y0:y1 + 1, x0:x1 + 1][m] = rgb
    return img


def write_png(path, img):
    h, w, _ = img.shape
    raw = b"".join(b"\0" + (np.clip(img[y], 0, 1) * 255).astype(np.uint8).tobytes() for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb"); ap.add_argument("png")
    ap.add_argument("--centro", nargs=3, type=float, default=[0, 1.0, 0])
    ap.add_argument("--ancho", type=float, default=0.9)
    ap.add_argument("--desde", type=float, default=0.0)
    ap.add_argument("--solo-izq", action="store_true")
    ap.add_argument("--px", type=int, default=360)
    a = ap.parse_args()
    v, f, col = load(a.glb)
    bf = sud.F0[(sud.P0[sud.F0][:, :, 1] > a.desde).all(1)]
    if a.solo_izq:
        f = f[(v[f][:, :, 0] > 0.02).all(1)]
        bf = bf[(sud.P0[bf][:, :, 0] > 0.03).all(1)]
    meshes = [(sud.P0, bf, None), (v, f, col)]
    tiles = [render(meshes, vw, a.px, a.ancho, np.array(a.centro)) for vw in VIEWS]
    write_png(a.png, np.vstack([np.hstack(tiles[:3]), np.hstack(tiles[3:])]))


if __name__ == "__main__":
    main()
