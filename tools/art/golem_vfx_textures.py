# Builds the nation golem VFX textures (white/grey RGBA, tinted in Roblox).
# Run inside Blender, e.g. runpy.run_path(".../golem_vfx_textures.py")
# with OUT_DIR set in the globals, or call build_all(out_dir).
#
# Every sheet is plain abstract shapes (dots, streaks, puffs, rings, arcs) so
# they pass Roblox moderation. Flipbooks are square grids that match the
# ParticleEmitter FlipbookLayout (Grid2x2 / Grid4x4).
import math
import os

import bpy
import numpy as np

RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers

def grid(n):
    """Coordinates in [-1, 1] for an n x n cell, y up."""
    v = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(v, -v)
    return x, y


def value_noise(n, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells + 1, cells + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    t = np.linspace(0, cells, n, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i, i)]
    b = g[np.ix_(i, i + 1)]
    c = g[np.ix_(i + 1, i)]
    d = g[np.ix_(i + 1, i + 1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, seed, octaves=4, base=4):
    out = np.zeros((n, n))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(n, base * 2 ** o, seed + o) * amp
        total += amp
        amp *= 0.5
    return out / total


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def cell(lum, alpha):
    """Stack a luminance and alpha map into an RGBA cell (white tinted grey)."""
    lum = np.clip(lum, 0, 1)
    alpha = np.clip(alpha, 0, 1)
    return np.dstack([lum, lum, lum, alpha])


def sheet(cells, cols):
    rows = []
    for r in range(len(cells) // cols):
        rows.append(np.hstack(cells[r * cols:(r + 1) * cols]))
    return np.vstack(rows)


def save(rgba, path):
    h, w = rgba.shape[:2]
    name = os.path.basename(path)
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, w, h, alpha=True)
    # Blender stores rows bottom-up.
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("wrote", path, w, h)


def draw_segment(acc, x, y, p0, p1, width):
    """Max-blend a soft line segment into acc."""
    px, py = p0
    qx, qy = p1
    dx, dy = qx - px, qy - py
    ll = dx * dx + dy * dy + 1e-9
    t = np.clip(((x - px) * dx + (y - py) * dy) / ll, 0, 1)
    d = np.hypot(x - (px + t * dx), y - (py + t * dy))
    np.maximum(acc, np.exp(-(d / width) ** 2), out=acc)


# ---------------------------------------------------------------- textures

def glow(n=256):
    x, y = grid(n)
    r = np.hypot(x, y)
    a = np.exp(-(r / 0.42) ** 2) * smooth(1.0, 0.85, r)
    return cell(0.6 + 0.4 * np.exp(-(r / 0.2) ** 2), a)


def spark(w=64, h=256):
    v = (np.arange(w) + 0.5) / w * 2 - 1
    u = (np.arange(h) + 0.5) / h * 2 - 1
    x, y = np.meshgrid(v, -u)
    # Bright head at the top, tapering tail.
    taper = smooth(-1.0, 0.6, y) * smooth(1.0, 0.75, y)
    width = 0.15 + 0.35 * smooth(-1, 0.7, y)
    a = np.exp(-(x / width) ** 2) * taper
    return cell(0.7 + 0.3 * a, a)


def smoke(n=256, frames=16):
    out = []
    x, y = grid(n)
    r = np.hypot(x, y)
    for f in range(frames):
        t = f / (frames - 1)
        noise = fbm(n, 11 + f * 3, 5, 3)
        size = 0.45 + 0.45 * t
        edge = r / size + (noise - 0.5) * 0.9
        a = smooth(1.0, 0.35, edge) * (1 - t) ** 1.3 * 0.85
        lum = 0.65 + 0.35 * noise
        out.append(cell(lum, a))
    return sheet(out, 4)


def flame(n=256, frames=16):
    out = []
    x, y = grid(n)
    base = fbm(n * 2, 31, 5, 3)
    for f in range(frames):
        t = f / frames
        # Scroll the noise upward so the tongue flickers as it loops.
        off = int(t * n)
        noise = base[off:off + n, :n]
        warp = x + (noise - noise.mean(axis=1, keepdims=True)) * 0.9 * (y + 1.1)
        height = 0.9 - 0.25 * math.sin(t * math.tau)
        width = 0.4 * np.sqrt(smooth(height, -0.95, y)) * smooth(-1.0, -0.6, y) ** 0.5 + 0.03
        shape = smooth(1.0, 0.4, np.abs(warp) / width) * smooth(-1, -0.7, y) * smooth(height, height - 0.6, y)
        a = shape * (0.6 + 0.6 * noise)
        lum = 0.55 + 0.45 * smooth(0.2, 1.0, shape)
        out.append(cell(lum, a))
    return sheet(out, 4)


def burst(n=256, frames=16):
    out = []
    x, y = grid(n)
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    rays = 0.5 + 0.5 * np.cos(ang * 9 + np.sin(ang * 4) * 1.5)
    for f in range(frames):
        t = f / (frames - 1)
        reach = 0.25 + 0.75 * t ** 0.6
        core = np.exp(-(r / (0.35 * (1 - t) + 0.02)) ** 2)
        star = smooth(reach, reach * 0.3, r) * rays ** (2 + 6 * t)
        a = np.clip(core + star, 0, 1) * (1 - t) ** 1.1
        out.append(cell(0.75 + 0.25 * core, a))
    return sheet(out, 4)


def ring(n=256, frames=16):
    out = []
    x, y = grid(n)
    r = np.hypot(x, y)
    noise = fbm(n, 51, 4, 6)
    for f in range(frames):
        t = f / (frames - 1)
        rad = 0.2 + 0.72 * t ** 0.55
        thick = 0.18 * (1 - t) + 0.03
        d = np.abs(r + (noise - 0.5) * 0.12 - rad)
        band = np.exp(-(d / thick) ** 2)
        inner = smooth(rad, 0, r) * 0.25 * (1 - t)
        a = (band + inner) * (1 - t) ** 0.9 * smooth(1.0, 0.95, r)
        out.append(cell(0.7 + 0.3 * band, a))
    return sheet(out, 4)


def chunks(n=256):
    """Four angular stone-chip silhouettes, shaded with a top light."""
    out = []
    x, y = grid(n)
    for k in range(4):
        rng = np.random.default_rng(100 + k)
        sides = rng.integers(5, 8)
        angles = (np.arange(sides) + rng.uniform(-0.3, 0.3, sides)) / sides * math.tau
        radii = 0.6 + rng.random(sides) * 0.25
        pts = np.stack([np.cos(angles) * radii, np.sin(angles) * radii], 1)
        inside = np.ones_like(x, bool)
        shade = np.zeros_like(x)
        for i in range(sides):
            p, q = pts[i], pts[(i + 1) % sides]
            nx, ny = q[1] - p[1], -(q[0] - p[0])
            side = (x - p[0]) * nx + (y - p[1]) * ny
            inside &= side <= 0
            facet = (nx * 0.3 + ny * 0.9) / math.hypot(nx, ny)
            shade = np.where(side > -0.12, facet, shade)
        lum = np.where(shade != 0, 0.55 + 0.4 * shade, 0.75)
        lum = lum * (0.85 + 0.15 * fbm(n, 200 + k, 3, 8))
        out.append(cell(lum, inside.astype(float)))
    return sheet(out, 2)


def droplet(w=128, h=256):
    v = (np.arange(w) + 0.5) / w * 2 - 1
    u = (np.arange(h) + 0.5) / h * 2 - 1
    x, y = np.meshgrid(v, -u)
    # Round bottom, pointed top (falls with VelocityParallel).
    yy = (y + 0.35) / 0.65
    width = np.where(yy < 0, np.sqrt(np.clip(1 - yy ** 2, 0, 1)), np.clip(1 - yy, 0, 1) ** 1.4)
    edge = np.abs(x) / (width * 0.7 + 1e-6)
    a = smooth(1.0, 0.8, edge) * smooth(-1.0, -0.95, y)
    hl = np.exp(-(((x + 0.25) / 0.15) ** 2 + ((y + 0.45) / 0.15) ** 2))
    lum = 0.7 + 0.3 * hl - 0.15 * smooth(0.5, 1.0, edge)
    return cell(lum, a)


def splash(n=256, frames=16):
    out = []
    x, y = grid(n)
    rng = np.random.default_rng(61)
    count = 14
    ang = np.linspace(-0.9, 0.9, count) * math.pi / 2 + rng.normal(0, 0.08, count)
    speed = 0.8 + rng.random(count) * 0.5
    size = 0.05 + rng.random(count) * 0.05
    for f in range(frames):
        t = f / (frames - 1)
        acc = np.zeros_like(x)
        for i in range(count):
            # Droplets fly up and out on an arc from the bottom centre.
            px = math.sin(ang[i]) * speed[i] * t
            py = -0.85 + math.cos(ang[i]) * speed[i] * 1.6 * t - 1.3 * t * t
            s = size[i] * (1 - 0.6 * t)
            acc = np.maximum(acc, np.exp(-(((x - px) / s) ** 2 + ((y - py) / (s * 1.4)) ** 2)))
        crown = np.exp(-((np.abs(x) - 0.25 - 0.4 * t) / 0.08) ** 2) * smooth(-0.95, -0.7, y) * smooth(-0.3 - 0.2 * (1 - t), -0.6, y)
        a = np.clip(acc + crown * (1 - t), 0, 1) * (1 - t ** 3)
        out.append(cell(0.8 + 0.2 * acc, a))
    return sheet(out, 4)


def wind(n=256, frames=16):
    """A curved streak sweeping around the centre, head bright, tail fading."""
    out = []
    x, y = grid(n)
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    for f in range(frames):
        t = f / (frames - 1)
        head = -math.pi * 0.6 + t * math.pi * 1.4
        length = 2.6
        # Distance (in angle) behind the head, wrapped.
        behind = np.mod(head - ang, math.tau)
        along = smooth(length, 0, behind) * smooth(0, 0.15, behind)
        rad = 0.7 - 0.25 * behind / length
        band = np.exp(-((r - rad) / (0.04 + 0.07 * (1 - behind / length))) ** 2)
        fade = math.sin(math.pi * t) ** 0.7
        a = band * along * fade
        out.append(cell(0.8 + 0.2 * a, a))
    return sheet(out, 4)


def bolt_path(rng, start, end, depth, rough):
    pts = [np.array(start, float), np.array(end, float)]
    for _ in range(depth):
        new = [pts[0]]
        for p, q in zip(pts, pts[1:]):
            mid = (p + q) / 2
            d = q - p
            perp = np.array([-d[1], d[0]])
            mid = mid + perp * rng.normal(0, rough)
            new += [mid, q]
        pts = new
        rough *= 0.55
    return pts


def arcs(n=256, frames=16):
    """Jagged electric arcs; every frame is a fresh random arc for flicker."""
    out = []
    x, y = grid(n)
    for f in range(frames):
        rng = np.random.default_rng(300 + f)
        acc = np.zeros_like(x)
        a0 = rng.random() * math.tau
        start = (math.cos(a0) * 0.85, math.sin(a0) * 0.85)
        end = (-start[0] * 0.8 + rng.normal(0, 0.2), -start[1] * 0.8 + rng.normal(0, 0.2))
        main = bolt_path(rng, start, end, 6, 0.35)
        for p, q in zip(main, main[1:]):
            draw_segment(acc, x, y, p, q, 0.025)
        glowmap = np.zeros_like(x)
        for p, q in zip(main[::4], main[4::4]):
            draw_segment(glowmap, x, y, p, q, 0.12)
        for _ in range(2):
            i = rng.integers(len(main) // 4, 3 * len(main) // 4)
            p = main[i]
            br_end = p + rng.normal(0, 0.45, 2)
            br = bolt_path(rng, p, br_end, 4, 0.3)
            for a, b in zip(br, br[1:]):
                draw_segment(acc, x, y, a, b, 0.016)
        a = np.clip(acc + glowmap * 0.35, 0, 1) * smooth(1.0, 0.9, np.hypot(x, y))
        out.append(cell(0.75 + 0.25 * acc, a))
    return sheet(out, 4)


def star(n=256):
    """Four-point anime sparkle: thin cross flare with a bright core."""
    x, y = grid(n)
    r = np.hypot(x, y)
    ax, ay = np.abs(x), np.abs(y)
    arm = np.exp(-(ay / (0.03 + 0.05 * (1 - ax)) ) ** 2) * smooth(1.0, 0.0, ax)
    arm = np.maximum(arm, np.exp(-(ax / (0.03 + 0.05 * (1 - ay))) ** 2) * smooth(1.0, 0.0, ay))
    core = np.exp(-(r / 0.12) ** 2)
    halo = np.exp(-(r / 0.35) ** 2) * 0.35
    a = np.clip(arm ** 1.5 + core + halo, 0, 1)
    return cell(0.8 + 0.2 * core, a)


def swirl(n=256, frames=16):
    """Ground swirl: three spiral arcs spinning out and fading (seen from above)."""
    out = []
    x, y = grid(n)
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    for f in range(frames):
        t = f / (frames - 1)
        acc = np.zeros_like(x)
        for k in range(3):
            # A spiral arm: angle grows with radius, rotating over time.
            phase = ang - k * math.tau / 3 - t * 2.2 - r * 2.6
            d = np.abs(np.mod(phase + math.pi, math.tau) - math.pi)
            arc = np.exp(-(d / (0.16 + 0.1 * r)) ** 2)
            acc = np.maximum(acc, arc)
        band = smooth(0.12, 0.3, r) * smooth(0.25 + 0.7 * t ** 0.6 + 0.05, 0.25 + 0.7 * t ** 0.6 - 0.25, r)
        ring = np.exp(-((r - (0.25 + 0.65 * t ** 0.6)) / 0.025) ** 2)
        a = np.clip(acc * band + ring * 0.8, 0, 1) * math.sin(math.pi * min(1, t * 1.15)) ** 0.6
        out.append(cell(0.8 + 0.2 * ring, a))
    return sheet(out, 4)


def beam(w=128, h=512):
    """Vertical light pillar: hot centre line fading to the top and sides."""
    v = (np.arange(w) + 0.5) / w * 2 - 1
    u = (np.arange(h) + 0.5) / h
    x, y = np.meshgrid(v, u[::-1])
    core = np.exp(-(x / 0.08) ** 2)
    glow = np.exp(-(x / 0.45) ** 2) * 0.5
    fade = (1 - y) ** 1.5 * smooth(0.0, 0.04, y)
    a = np.clip(core + glow, 0, 1) * fade
    return cell(0.75 + 0.25 * core, a)


def crack(n=1024):
    """Ground impact: a scorched centre with jagged branching cracks.

    Luminance carries a glowing inner rim along each crack (tinted by the
    decal colour), alpha carries the dark crack shape."""
    rng = np.random.default_rng(42)
    x, y = grid(n)
    r = np.hypot(x, y)
    lines = np.zeros_like(x)
    glow = np.zeros_like(x)

    def branch(p, ang, length, width, depth):
        pts = [np.array(p, float)]
        steps = 5
        for _ in range(steps):
            ang += rng.normal(0, 0.45)
            q = pts[-1] + np.array([math.cos(ang), math.sin(ang)]) * length / steps
            pts.append(q)
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            w = width * (1 - i / (steps + 1))
            draw_segment(lines, x, y, a, b, w)
            draw_segment(glow, x, y, a, b, w * 2.6)
            if depth > 0 and rng.random() < 0.3:
                side = rng.choice([-1, 1])
                branch(b, ang + side * rng.uniform(0.5, 1.1), length * 0.45, w * 0.7, depth - 1)

    count = 7
    for k in range(count):
        ang = k / count * math.tau + rng.normal(0, 0.2)
        start = (math.cos(ang) * 0.1, math.sin(ang) * 0.1)
        branch(start, ang, rng.uniform(0.6, 0.85), 0.034, 1)
    # Short shatter cracks ringing the centre.
    for k in range(14):
        ang = rng.random() * math.tau
        a = np.array([math.cos(ang), math.sin(ang)]) * 0.18
        b = a + np.array([math.cos(ang + 1.6), math.sin(ang + 1.6)]) * rng.uniform(0.06, 0.12)
        draw_segment(lines, x, y, a, b, 0.016)

    noise = fbm(n, 77, 5, 6)
    scorch = smooth(0.38, 0.05, r + (noise - 0.5) * 0.22) * 0.92
    shape = np.clip(np.maximum(lines, scorch), 0, 1) * smooth(1.0, 0.92, r)
    # Bright where a crack runs through the hot middle, dark elsewhere.
    lum = np.clip(glow * smooth(0.55, 0.05, r) * 0.95 - lines * 0.5, 0, 1)
    return cell(lum, shape)


TEXTURES = {
    "Crack": crack,
    "Star": star,
    "Swirl_4x4": swirl,
    "Beam": beam,
    "Glow": glow,
    "Spark": spark,
    "Smoke_4x4": smoke,
    "Flame_4x4": flame,
    "Burst_4x4": burst,
    "Ring_4x4": ring,
    "Chunks_2x2": chunks,
    "Droplet": droplet,
    "Splash_4x4": splash,
    "Wind_4x4": wind,
    "Arc_4x4": arcs,
}


def build_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in TEXTURES.items():
        if only and name not in only:
            continue
        save(fn(), os.path.join(out_dir, "GolemFX_" + name + ".png"))


if "OUT_DIR" in globals():
    build_all(OUT_DIR, globals().get("ONLY"))
