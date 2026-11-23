"""Exports the 3D injection-site body for the iOS app.

Writes two data assets into Assets.xcassets:
  InjectionBodyMesh.dataset/injection-body.bin  – body mesh + one decal mesh per tappable zone (+ rims)
  InjectionBodySites.dataset/injection-sites.json – areas, camera focus and spot positions

Binary layout (little endian):
  "ABM1" | u32 meshCount | meshCount × ( u8 nameLen | name utf8 | u32 vertexCount | u32 indexCount
                                         | f32 position[3·v] | f32 normal[3·v] | u32 index[i] )

Coordinates are metres, y up, the body faces +z and the person's left is +x.
Regenerate with: python3 tools/body-model/export_asset.py  (needs numpy, scikit-image, fast-simplification)
"""
import json, struct, sys
from pathlib import Path
import numpy as np
from skimage.measure import marching_cubes
import fast_simplification

sys.path.insert(0, str(Path(__file__).parent))
import body3d
from body3d import sdf, ZONES, PALETTE, NAVEL

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps/ios/Along/Assets.xcassets"

# ── meshing ───────────────────────────────────────────────────────────────────
def eval_sdf(points, chunk=300_000):
    return np.concatenate([sdf(points[i:i + chunk]) for i in range(0, len(points), chunk)])

def sdf_normals(v):
    e = 0.0008
    n = np.stack([eval_sdf(v + [e, 0, 0]) - eval_sdf(v - [e, 0, 0]),
                  eval_sdf(v + [0, e, 0]) - eval_sdf(v - [0, e, 0]),
                  eval_sdf(v + [0, 0, e]) - eval_sdf(v - [0, 0, e])], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)

def iso(lo, hi, res):
    xs, ys, zs = (np.arange(lo[i], hi[i] + res, res) for i in range(3))
    g = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), -1).reshape(-1, 3)
    vol = eval_sdf(g).reshape(len(xs), len(ys), len(zs))
    v, f, _, _ = marching_cubes(vol, 0.0, spacing=(res, res, res))
    v = v + np.array([xs[0], ys[0], zs[0]])
    return orient(v, f)

def orient(v, f):
    """Counter-clockwise winding seen from outside (SceneKit culls back faces)."""
    a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
    fn = np.cross(b - a, c - a)
    outward = sdf_normals((a + b + c) / 3)
    if np.mean(np.sum(fn * outward, -1) > 0) < 0.5:
        f = f[:, ::-1]
    return v, f

def compact(v, f, keep):
    f = f[keep]
    used = np.unique(f)
    remap = -np.ones(len(v), int); remap[used] = np.arange(len(used))
    return v[used], remap[f]

# ── zones ─────────────────────────────────────────────────────────────────────
def side_of(x): return "left" if x > 0 else "right"

def zone_metric(p, c, r):
    return np.linalg.norm((p - np.array(c)) / np.array(r), axis=-1)

def abdomen_quadrant(p, n):
    dx, dy = p[:, 0] - NAVEL[0], p[:, 1] - NAVEL[1]
    rr = np.sqrt((dx / 0.105) ** 2 + (dy / 0.095) ** 2)
    ok = (n[:, 2] > 0.35) & (p[:, 2] > 0.02) & (rr < 1) & (np.hypot(dx, dy) > 0.032)
    ok &= (np.abs(dx) > 0.004) & (np.abs(dy) > 0.004)
    return ok, rr, dx, dy

FOCUS = {  # region: (yaw for the person's left side in degrees, half height of the view in metres)
    "delt": (-60, 0.13), "tricep": (-135, 0.16), "flank": (-45, 0.15), "ventroglute": (-45, 0.15),
    "dorsoglute": (180, 0.16), "thigh": (-25, 0.21),
}
COUNTS = {"delt": 2, "tricep": 2, "flank": 3, "ventroglute": 3, "dorsoglute": 4, "thigh": 4}

def rot_y(deg): return body3d.rot_y(np.radians(deg))

def surface_along(o_world, yaw):
    """March a camera ray (world −z) onto the body; returns body-space point or None."""
    R = rot_y(yaw)
    o = np.asarray(o_world, float) @ R
    d = np.array([0, 0, -1.0]) @ R
    t = 0.0
    for _ in range(200):
        p = o + d * t
        s = sdf(p[None])[0]
        if s < 1e-5: return p
        t += s * 0.9
        if t > 1.2: return None
    return None

def place_spots(c, r, yaw, n):
    R = rot_y(yaw)
    cw = np.asarray(c) @ R.T
    reach = max(r) * 1.1
    cands = []
    for du in np.arange(-reach, reach, 0.003):
        for dv in np.arange(-reach, reach, 0.003):
            p = surface_along([cw[0] + du, cw[1] + dv, 0.6], yaw)
            if p is not None and zone_metric(p[None], c, r)[0] < 0.7:
                cands.append(p)
    cands = np.array(cands)
    # Farthest-point sampling from the point nearest the zone centre.
    chosen = [int(np.argmin(np.linalg.norm(cands - c, axis=1)))]
    dist = np.linalg.norm(cands - cands[chosen[0]], axis=1)
    for _ in range(n - 1):
        i = int(np.argmax(dist)); chosen.append(i)
        dist = np.minimum(dist, np.linalg.norm(cands - cands[i], axis=1))
    pts = cands[chosen]
    screen = pts @ R.T
    order = np.lexsort((screen[:, 0], -np.round(screen[:, 1], 3)))   # top-to-bottom, then left-to-right
    return pts[order]

def main():
    meshes = {}
    print("body…", flush=True)
    v, f = iso((-0.45, -0.02, -0.25), (0.45, 1.78, 0.25), 0.004)
    print(" raw", len(v), len(f), flush=True)
    v2, f2 = fast_simplification.simplify(v.astype(np.float32), f.astype(np.int32), target_reduction=1 - 70_000 / len(f))
    v2, f2 = orient(v2.astype(np.float64), f2)
    meshes["body"] = (v2, sdf_normals(v2), f2)
    print(" body", len(v2), len(f2), flush=True)

    zones_meta = []
    def add_decal(name, area, color, v, f, keep_fill, keep_rim):
        for kind, keep, lift in (("zone", keep_fill, 0.0012), ("rim", keep_rim, 0.0018)):
            if keep.sum() == 0: continue
            vv, ff = compact(v, f, keep)
            nn = sdf_normals(vv)
            meshes[f"{kind}:{name}"] = (vv + nn * lift, nn, ff)
        zones_meta.append({"mesh": f"zone:{name}", "rim": f"rim:{name}", "area": area, "color": [round(x, 3) for x in color]})

    for key, c, r in ZONES:
        side = side_of(c[0]); name = f"{key}.{side}"
        pad = np.array(r) + 0.012
        v, f = iso(np.array(c) - pad, np.array(c) + pad, 0.0026)
        cen = (v[f[:, 0]] + v[f[:, 1]] + v[f[:, 2]]) / 3
        m = zone_metric(cen, c, r)
        add_decal(name, name, PALETTE[key], v, f, m < 1, (m > 0.86) & (m < 1))
        print(" zone", name, int((m < 1).sum()), flush=True)

    lo = NAVEL + [-0.12, -0.11, 0.0]; hi = NAVEL + [0.12, 0.11, 0.16]
    v, f = iso(lo, hi, 0.0024)
    cen = (v[f[:, 0]] + v[f[:, 1]] + v[f[:, 2]]) / 3
    ok, rr, dx, dy = abdomen_quadrant(cen, sdf_normals(cen))
    rim = ok & ((rr > 0.88) | (np.hypot(dx, dy) < 0.036))
    for vert in ("upper", "lower"):
        for side in ("left", "right"):
            q = ok & ((dy > 0) if vert == "upper" else (dy < 0)) & ((dx > 0) if side == "left" else (dx < 0))
            add_decal(f"abdomen.{side}.{vert}", "abdomen", PALETTE["abdomen"], v, f, q, q & rim)

    # Areas, focus and spots.
    areas = []
    offs = [(0.042, 0.034), (0.074, 0.028), (0.038, 0.064), (0.066, 0.055)]
    spots = []
    for vert, sy in (("upper", 1), ("lower", -1)):
        for side, sx in (("left", 1), ("right", -1)):
            for i, (ox, oy) in enumerate(offs):
                p = surface_along([NAVEL[0] + sx * ox, NAVEL[1] + sy * oy, 0.6], 0)
                spots.append({"id": f"abdomen.{side}.{vert}.{i + 1}", "p": p.round(5).tolist(), "n": sdf_normals(p[None])[0].round(4).tolist()})
    areas.append({"id": "abdomen", "region": "abdomen", "side": None, "yaw": 0, "center": [0, 1.075, 0.09], "halfHeight": 0.19, "spots": spots})
    for key, c, r in ZONES:
        side = side_of(c[0]); yaw_l, hh = FOCUS[key]
        yaw = yaw_l if side == "left" else (-yaw_l if abs(yaw_l) != 180 else 180)
        pts = place_spots(c, r, yaw, COUNTS[key])
        normals = sdf_normals(pts)
        areas.append({"id": f"{key}.{side}", "region": key, "side": side, "yaw": yaw,
                      "center": np.array(c).round(4).tolist(), "halfHeight": hh,
                      "spots": [{"id": f"{key}.{side}.{i + 1}", "p": p.round(5).tolist(), "n": n.round(4).tolist()}
                                for i, (p, n) in enumerate(zip(pts, normals))]})
        print(" spots", key, side, len(pts), flush=True)

    # Write assets.
    for ds, fname, payload in (("InjectionBodyMesh", "injection-body.bin", None), ("InjectionBodySites", "injection-sites.json", None)):
        d = ASSETS / f"{ds}.dataset"; d.mkdir(parents=True, exist_ok=True)
        (d / "Contents.json").write_text(json.dumps({"data": [{"filename": fname, "idiom": "universal"}],
                                                      "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    out = bytearray(b"ABM1") + struct.pack("<I", len(meshes))
    for name, (v, n, f) in meshes.items():
        nb = name.encode()
        out += struct.pack("<B", len(nb)) + nb + struct.pack("<II", len(v), f.size)
        out += np.asarray(v, "<f4").tobytes() + np.asarray(n, "<f4").tobytes() + np.asarray(f, "<u4").tobytes()
    (ASSETS / "InjectionBodyMesh.dataset/injection-body.bin").write_bytes(bytes(out))
    (ASSETS / "InjectionBodySites.dataset/injection-sites.json").write_text(
        json.dumps({"version": 1, "units": "metres", "areas": areas, "zones": zones_meta}, separators=(",", ":")) + "\n")
    print("wrote", len(meshes), "meshes,", len(out) // 1024, "KB", flush=True)

if __name__ == "__main__":
    main()
