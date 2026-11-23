"""Gender-neutral 3D mannequin defined as a signed distance field (smooth-blended
primitives). Renders shaded PNG views by sphere tracing and can export a mesh.
Units ~ metres, y up, body faces +z, person's left is +x."""
import sys
import numpy as np

# ── primitives ────────────────────────────────────────────────────────────────
def ellipsoid(p, c, r):
    q = (p - c) / r
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm((p - c) / (np.asarray(r) ** 2), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

def cone(p, a, b, ra, rb):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    t = np.clip(((p - a) @ ba) / (ba @ ba), 0, 1)
    d = np.linalg.norm(p - a - t[:, None] * ba, axis=-1)
    return d - (ra + (rb - ra) * t)

def smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0) / k
    return np.minimum(a, b) - h * h * k * 0.25

def sides(fn):
    """Build left and right copies of a limb (x mirrored)."""
    return [fn(1.0), fn(-1.0)]

# ── body ──────────────────────────────────────────────────────────────────────
def limb_arm(s):
    def f(p):
        sh, el, wr = (s * 0.178, 1.37, -0.008), (s * 0.252, 1.105, -0.025), (s * 0.3, 0.855, 0.005)
        d = cone(p, sh, el, 0.046, 0.03)
        d = smin(d, cone(p, el, wr, 0.03, 0.023), 0.02)
        d = smin(d, ellipsoid(p, np.array([s * 0.32, 0.775, 0.012]), np.array([0.022, 0.068, 0.04])), 0.025)
        d = smin(d, ellipsoid(p, np.array([s * 0.268, 1.02, -0.012]), np.array([0.034, 0.075, 0.034])), 0.04)  # forearm
        d = smin(d, ellipsoid(p, np.array([s * 0.19, 1.335, -0.01]), np.array([0.04, 0.066, 0.046])), 0.05)  # deltoid
        return d
    return f

def limb_leg(s):
    def f(p):
        hp, kn, an = (s * 0.088, 0.93, 0.0), (s * 0.098, 0.505, 0.008), (s * 0.1, 0.085, -0.012)
        d = cone(p, hp, kn, 0.088, 0.046)
        d = smin(d, cone(p, kn, an, 0.045, 0.028), 0.025)
        d = smin(d, ellipsoid(p, np.array([s * 0.1, 0.355, -0.018]), np.array([0.042, 0.11, 0.045])), 0.06)  # calf
        d = smin(d, cone(p, (s * 0.1, 0.035, -0.03), (s * 0.112, 0.022, 0.105), 0.032, 0.024), 0.035)        # foot
        return d
    return f

ARMS = sides(limb_arm)
LEGS = sides(limb_leg)

def sdf(p):
    # Head and neck
    d = ellipsoid(p, np.array([0, 1.645, 0.0]), np.array([0.083, 0.09, 0.093]))
    d = smin(d, ellipsoid(p, np.array([0, 1.595, 0.02]), np.array([0.058, 0.042, 0.058])), 0.04)
    d = smin(d, cone(p, (0, 1.43, -0.012), (0, 1.57, -0.005), 0.056, 0.05), 0.04)
    # Torso: chest, waist, pelvis, glutes — kept neutral (no chest or hip exaggeration)
    t = ellipsoid(p, np.array([0, 1.30, -0.008]), np.array([0.148, 0.15, 0.094]))
    t = smin(t, ellipsoid(p, np.array([0, 1.12, 0.0]), np.array([0.132, 0.15, 0.092])), 0.09)
    t = smin(t, ellipsoid(p, np.array([0, 0.965, -0.012]), np.array([0.148, 0.12, 0.088])), 0.12)
    t = smin(t, ellipsoid(p, np.array([0.072, 0.935, -0.055]), np.array([0.076, 0.082, 0.066])), 0.05)
    t = smin(t, ellipsoid(p, np.array([-0.072, 0.935, -0.055]), np.array([0.076, 0.082, 0.066])), 0.05)
    t = smin(t, cone(p, (-0.16, 1.38, -0.014), (0.16, 1.38, -0.014), 0.043, 0.043), 0.08)   # shoulder line
    t = smin(t, ellipsoid(p, np.array([0, 1.425, -0.02]), np.array([0.13, 0.05, 0.06])), 0.06)   # trapezius
    d = smin(d, t, 0.05)
    for a in ARMS:
        d = smin(d, a(p), 0.035)
    for l in LEGS:
        d = smin(d, l(p), 0.04)
    return d

# ── site zones (paint on the surface) ─────────────────────────────────────────
PALETTE = {
    "delt": (0.37, 0.70, 0.79), "tricep": (0.89, 0.72, 0.29), "abdomen": (0.31, 0.69, 0.48),
    "flank": (0.90, 0.60, 0.69), "ventroglute": (0.91, 0.54, 0.29), "dorsoglute": (0.61, 0.48, 0.82),
    "thigh": (0.85, 0.38, 0.35),
}
ZONES = []  # (key, centre, radii)
for s in (1, -1):
    ZONES += [
        ("delt", (s * 0.22, 1.32, -0.012), (0.04, 0.05, 0.075)),
        ("tricep", (s * 0.238, 1.19, -0.058), (0.045, 0.075, 0.035)),
        ("flank", (s * 0.135, 1.06, -0.02), (0.04, 0.045, 0.06)),
        ("ventroglute", (s * 0.165, 0.925, 0.012), (0.038, 0.048, 0.05)),
        ("dorsoglute", (s * 0.095, 0.975, -0.13), (0.055, 0.04, 0.05)),
        ("thigh", (s * 0.15, 0.68, 0.05), (0.04, 0.1, 0.06)),
    ]
NAVEL = np.array([0, 1.085, 0.0])

def zone_paint(p, n, za=None):
    za = za or {}
    """Returns colour (N,3), alpha (N,), border (N,) for surface points."""
    col = np.zeros_like(p); alpha = np.zeros(len(p)); border = np.zeros(len(p))
    for key, c, r in ZONES:
        m = np.linalg.norm((p - np.array(c)) / np.array(r), axis=-1)
        inside = m < 1
        k = za.get(key, 1.0)
        col[inside] = PALETTE[key]; alpha[inside] = 0.82 * k
        border[(m > 0.86) & inside] = k
    # Abdomen: ring around the navel, front-facing, split into 4 quadrants.
    dx, dy = p[:, 0] - NAVEL[0], p[:, 1] - NAVEL[1]
    rr = np.sqrt((dx / 0.105) ** 2 + (dy / 0.095) ** 2)
    front = (n[:, 2] > 0.35) & (p[:, 2] > 0.02)
    ab = front & (rr < 1) & (np.hypot(dx, dy) > 0.032)
    gap = (np.abs(dx) < 0.004) | (np.abs(dy) < 0.004)
    k = za.get("abdomen", 1.0)
    col[ab & ~gap] = PALETTE["abdomen"]; alpha[ab & ~gap] = 0.82 * k
    border[ab & ((rr > 0.88) | (np.hypot(dx, dy) < 0.036))] = k
    border[ab & gap] = k
    return col, alpha, border

# ── renderer (orthographic sphere tracing) ────────────────────────────────────
def rot_y(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def normals(p):
    e = 0.0015
    n = np.stack([sdf(p + [e, 0, 0]) - sdf(p - [e, 0, 0]),
                  sdf(p + [0, e, 0]) - sdf(p - [0, e, 0]),
                  sdf(p + [0, 0, e]) - sdf(p - [0, 0, e])], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)

def render(yaw_deg, zones, W=560, H=1180, cx=0.0, cy=0.87, half_h=0.89, bg=(1, 1, 1), za=None, shadow=True):
    half_w = half_h * W / H
    x0, x1, y0, y1 = cx - half_w, cx + half_w, cy - half_h, cy + half_h
    xs = np.linspace(x0, x1, W); ys = np.linspace(y1, y0, H)
    X, Y = np.meshgrid(xs, ys)
    R = rot_y(np.radians(yaw_deg))            # world → body rotation
    o = np.stack([X.ravel(), Y.ravel(), np.full(X.size, 0.5)], -1)
    d_dir = np.array([0, 0, -1.0])
    t = np.zeros(len(o)); hit = np.zeros(len(o), bool); alive = np.ones(len(o), bool)
    for _ in range(90):
        idx = np.where(alive)[0]
        if len(idx) == 0: break
        pw = o[idx] + t[idx, None] * d_dir
        dist = sdf(pw @ R)
        t[idx] += dist * 0.9
        h = dist < 0.0008
        hit[idx[h]] = True
        alive[idx[h]] = False
        alive[idx[t[idx] > 1.0]] = False
    img = np.ones((len(o), 3)) * np.array(bg)
    idx = np.where(hit)[0]
    pw = o[idx] + t[idx, None] * d_dir
    pb = pw @ R
    nb = normals(pb)
    nw = nb @ R.T                              # normal in world/view space
    # Lighting: soft key from upper-left-front, fill, rim, hemispheric ambient, AO.
    key = np.array([-0.45, 0.6, 0.66]); key /= np.linalg.norm(key)
    fill = np.array([0.6, 0.1, 0.8]); fill /= np.linalg.norm(fill)
    diff = np.clip(nw @ key, 0, 1) * 0.62 + np.clip(nw @ fill, 0, 1) * 0.2
    amb = 0.32 + 0.1 * nw[:, 1]
    ao = np.ones(len(pb))
    for i, h in enumerate([0.01, 0.025, 0.05]):
        ao -= (h - sdf(pb + nb * h)).clip(0) * (2.2 / (i + 1))
    ao = ao.clip(0.35, 1)
    rim = (1 - np.clip(nw[:, 2], 0, 1)) ** 3 * 0.18
    base = np.array([0.90, 0.895, 0.89])
    lum = ((diff + amb) * ao)[:, None]
    c = base * lum + rim[:, None]
    spec = np.clip(nw @ ((key + [0, 0, 1]) / np.linalg.norm(key + [0, 0, 1])), 0, 1) ** 40 * 0.12
    c += spec[:, None]
    if zones:
        zc, zal, zb = zone_paint(pb, nb, za)
        zl = (0.55 + 0.5 * lum)                # zones keep shape shading, stay saturated
        painted = np.array(zc) * zl
        c = c * (1 - zal[:, None]) + painted * zal[:, None]
        c = c * (1 - 0.75 * zb[:, None]) + 0.75 * zb[:, None]
    # Navel mark on front views.
    nav = np.linalg.norm(pb - (NAVEL + [0, 0, 0.1]), axis=-1)
    navel_hit = (np.hypot(pb[:, 0], pb[:, 1] - NAVEL[1]) < 0.007) & (nb[:, 2] > 0.5)
    c[navel_hit] *= 0.78
    img[idx] = c.clip(0, 1)
    # Soft floor shadow.
    img = img.reshape(H, W, 3)
    gy = (Y - 0.0) / 0.03; gx = X / 0.22
    sh = np.exp(-(gx ** 2 + gy ** 2)) * 0.12
    mask = ~hit.reshape(H, W)
    if shadow:
        img[mask] -= sh[mask, None]
    return (img.clip(0, 1) * 255).astype(np.uint8)

def export_mesh(path, res=0.006):
    from skimage.measure import marching_cubes
    import trimesh
    xs = np.arange(-0.45, 0.45, res); ys = np.arange(-0.02, 1.78, res); zs = np.arange(-0.25, 0.25, res)
    G = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), -1).reshape(-1, 3)
    vals = np.concatenate([sdf(G[i:i + 400000]) for i in range(0, len(G), 400000)])
    v, f, n, _ = marching_cubes(vals.reshape(len(xs), len(ys), len(zs)), 0, spacing=(res, res, res))
    v += [xs[0], ys[0], zs[0]]
    m = trimesh.Trimesh(v, f[:, ::-1]); m = m.simplify_quadric_decimation(face_count=40000) if hasattr(m, "simplify_quadric_decimation") else m
    m.export(path)
    return len(m.vertices), len(m.faces)

if __name__ == "__main__":
    from PIL import Image
    out = sys.argv[1]; zones = "--zones" in sys.argv
    views = [(0, "front"), (180, "back"), (-35, "angle")]
    if "--quick" in sys.argv:
        views = views[:1]
    for yaw, name in views:
        img = render(yaw, zones)
        Image.fromarray(img).resize((373, 787), Image.LANCZOS).save(f"{out}/{name}{'-zones' if zones else ''}.png")
        print("rendered", name, flush=True)
