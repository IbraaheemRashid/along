"""Reads the exported binary + JSON exactly as the app does and renders a check image
(front / left-oblique / back) with zones and spots, using a small numpy z-buffer."""
import json, struct, sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps/ios/Along/Assets.xcassets"

def load():
    b = (ASSETS / "InjectionBodyMesh.dataset/injection-body.bin").read_bytes()
    assert b[:4] == b"ABM1"
    (count,) = struct.unpack_from("<I", b, 4); o = 8; meshes = {}
    for _ in range(count):
        n = b[o]; o += 1; name = b[o:o + n].decode(); o += n
        v, i = struct.unpack_from("<II", b, o); o += 8
        pos = np.frombuffer(b, "<f4", v * 3, o).reshape(-1, 3); o += v * 12
        nrm = np.frombuffer(b, "<f4", v * 3, o).reshape(-1, 3); o += v * 12
        idx = np.frombuffer(b, "<u4", i, o).reshape(-1, 3); o += i * 4
        meshes[name] = (pos, nrm, idx)
    assert o == len(b), "trailing bytes"
    sites = json.loads((ASSETS / "InjectionBodySites.dataset/injection-sites.json").read_text())
    return meshes, sites

def rot_y(deg):
    a = np.radians(deg); c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def raster(meshes, colors, yaw, W=420, H=840, cx=0.0, cy=0.88, hh=0.92):
    R = rot_y(yaw); hw = hh * W / H
    img = np.ones((H, W, 3)); depth = np.full((H, W), -9.0)
    light = np.array([-0.45, 0.6, 0.66]); light /= np.linalg.norm(light)
    for name, (pos, nrm, idx) in meshes.items():
        col = np.array(colors(name))
        if col is None: continue
        P = pos @ R.T; N = nrm @ R.T
        sx = (P[:, 0] - (cx - hw)) / (2 * hw) * W; sy = ((cy + hh) - P[:, 1]) / (2 * hh) * H
        a, b, c = idx[:, 0], idx[:, 1], idx[:, 2]
        # back-face cull in screen space (y down → CCW from outside becomes CW)
        cross = (sx[b] - sx[a]) * (sy[c] - sy[a]) - (sy[b] - sy[a]) * (sx[c] - sx[a])
        for t in np.where(cross < 0)[0]:
            ia, ib, ic = a[t], b[t], c[t]
            xs = np.array([sx[ia], sx[ib], sx[ic]]); ys = np.array([sy[ia], sy[ib], sy[ic]])
            x0, x1 = int(max(xs.min(), 0)), int(min(xs.max() + 1, W)); y0, y1 = int(max(ys.min(), 0)), int(min(ys.max() + 1, H))
            if x0 >= x1 or y0 >= y1: continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9: continue
            w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            w2 = 1 - w0 - w1
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not inside.any(): continue
            z = w0 * P[ia, 2] + w1 * P[ib, 2] + w2 * P[ic, 2]
            n = (w0[..., None] * N[ia] + w1[..., None] * N[ib] + w2[..., None] * N[ic])
            n /= np.linalg.norm(n, axis=-1, keepdims=True)
            sub = depth[y0:y1, x0:x1]; upd = inside & (z > sub)
            shade = 0.42 + 0.58 * np.clip(n @ light, 0, 1)
            img[y0:y1, x0:x1][upd] = (col * shade[..., None])[upd]
            sub[upd] = z[upd]
    return img, R, (cx, cy, hh, hw, W, H)

def main(out):
    meshes, sites = load()
    zone_col = {z["mesh"]: z["color"] for z in sites["zones"]}
    def colors(name):
        if name == "body": return (0.9, 0.9, 0.9)
        if name.startswith("zone:"): return tuple(zone_col[name])
        return (1, 1, 1)
    views = []
    for yaw in (0, -45, 180):
        img, R, (cx, cy, hh, hw, W, H) = raster(meshes, colors, yaw)
        im = Image.fromarray((img * 255).astype(np.uint8))
        from PIL import ImageDraw
        d = ImageDraw.Draw(im)
        for area in sites["areas"]:
            for s in area["spots"]:
                p = np.array(s["p"]) @ R.T; n = np.array(s["n"]) @ R.T
                if n[2] < 0.15: continue
                x = (p[0] - (cx - hw)) / (2 * hw) * W; y = ((cy + hh) - p[1]) / (2 * hh) * H
                d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(20, 20, 25))
        views.append(im)
    sheet = Image.new("RGB", (sum(v.width for v in views), views[0].height), "white")
    x = 0
    for v in views: sheet.paste(v, (x, 0)); x += v.width
    sheet.save(out)
    print("meshes", len(meshes), "areas", len(sites["areas"]), "spots", sum(len(a["spots"]) for a in sites["areas"]))

if __name__ == "__main__":
    main(sys.argv[1])
