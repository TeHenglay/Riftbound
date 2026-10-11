"""Anime layered skill textures: one 2x2 atlas per element, one cell per layer.

Run inside Blender (numpy only), e.g. from the Blender MCP:
    exec(open(r"<repo>/tools/art/anime_layer_textures.py").read())
    bake("fire", r"<repo>/art/skill_models/firestorm", "FirestormNoise")

The four cells match the four nested layers of a skill mesh (inner to outer):
    cell 0  Core       white-hot, almost solid, so the effect glows from inside
    cell 1  Body       the element colour in three flat tones, ragged streaks
    cell 2  Highlight  thin white streaks, mostly empty
    cell 3  Ink        sparse dark strokes on the outside (the anime shade)
Cell i sits at UV (i % 2 * 0.5, i // 2 * 0.5); v runs from the bottom of the
layer (0) to the top (1). Streaks run almost sideways with jagged edges, the
noise is warped by a second noise so it flows, and the bottom of the core and
body layers fades to white where the effect meets the ground.

bake() also writes <name>_Erode1 / _Erode2: the same atlas with more of each
layer cut away, swapped in by code to dissolve the effect.
"""
import numpy as np

N = 512

PALETTES = {
    # core low/high, body dark/mid/light, highlight, ink
    "fire": dict(core=((1.0, 0.86, 0.35), (1.0, 1.0, 0.9)), body=((0.95, 0.42, 0.05), (1.0, 0.68, 0.12), (1.0, 0.9, 0.35)),
                 hi=(1.0, 1.0, 0.92), ink=((0.12, 0.03, 0.02), (0.35, 0.08, 0.03))),
    "water": dict(core=((0.55, 0.9, 1.0), (0.95, 1.0, 1.0)), body=((0.05, 0.45, 0.9), (0.2, 0.7, 1.0), (0.55, 0.92, 1.0)),
                  hi=(0.95, 1.0, 1.0), ink=((0.02, 0.06, 0.16), (0.05, 0.16, 0.35))),
    "rift": dict(core=((0.95, 0.6, 1.0), (1.0, 0.92, 1.0)), body=((0.55, 0.15, 0.85), (0.85, 0.35, 1.0), (1.0, 0.7, 1.0)),
                 hi=(1.0, 0.95, 1.0), ink=((0.08, 0.02, 0.14), (0.22, 0.06, 0.32))),
    "wind": dict(core=((0.86, 1.0, 0.6), (1.0, 1.0, 0.92)), body=((0.55, 0.85, 0.2), (0.75, 0.97, 0.4), (0.9, 1.0, 0.7)),
                 hi=(1.0, 1.0, 0.95), ink=((0.04, 0.1, 0.03), (0.12, 0.25, 0.08))),
    "ice": dict(core=((0.8, 0.96, 1.0), (1.0, 1.0, 1.0)), body=((0.35, 0.65, 0.95), (0.6, 0.85, 1.0), (0.85, 0.97, 1.0)),
                hi=(1.0, 1.0, 1.0), ink=((0.03, 0.06, 0.18), (0.1, 0.18, 0.4))),
    "lightning": dict(core=((1.0, 0.95, 0.55), (1.0, 1.0, 0.95)), body=((0.95, 0.7, 0.1), (1.0, 0.85, 0.25), (1.0, 0.97, 0.6)),
                      hi=(1.0, 1.0, 1.0), ink=((0.1, 0.05, 0.2), (0.3, 0.15, 0.5))),
}

# Per layer: cutoff (share of the noise cut away), streak tilt in degrees,
# streak length / width (spectrum widths), warp strength in pixels, seed.
LAYERS = [
    dict(cut=0.0, tilt=14, along=1.6, across=9, warp=18, seed=11),   # core
    dict(cut=0.32, tilt=18, along=1.4, across=12, warp=24, seed=12),  # body
    dict(cut=0.78, tilt=12, along=1.0, across=26, warp=16, seed=13),  # highlight
    dict(cut=0.7, tilt=20, along=1.2, across=16, warp=28, seed=14),   # ink
]
FOAM = 0.12  # bottom share that fades to white on the core and body


def _noise(seed, tilt, along, across):
    r = np.random.default_rng(seed)
    k = np.fft.fftfreq(N) * N
    kx, ky = np.meshgrid(k, k)
    a = np.radians(tilt)
    # Streaks run along direction (cos a, sin a): low frequencies along it.
    ka = kx * np.cos(a) + ky * np.sin(a)
    kc = -kx * np.sin(a) + ky * np.cos(a)
    amp = np.zeros((N, N))
    for s, w in ((1.0, 1.0), (2.0, 0.5), (4.0, 0.25)):
        amp += w * np.exp(-(ka / (along * s)) ** 2 - (kc / (across * s)) ** 2)
    amp[0, 0] = 0
    f = np.real(np.fft.ifft2(amp * np.exp(2j * np.pi * r.random((N, N)))))
    flat = f.ravel()
    order = flat.argsort()
    ranks = np.empty_like(order)
    ranks[order] = np.arange(flat.size)
    return (ranks / (flat.size - 1)).reshape(N, N)


def _blob(seed, cells=4):
    r = np.random.default_rng(seed)
    k = np.fft.fftfreq(N) * N
    kx, ky = np.meshgrid(k, k)
    amp = np.exp(-(kx ** 2 + ky ** 2) / cells ** 2)
    amp[0, 0] = 0
    f = np.real(np.fft.ifft2(amp * np.exp(2j * np.pi * r.random((N, N)))))
    return (f - f.min()) / (f.max() - f.min())


def _sample(img, x, y):
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x0 %= N
    y0 %= N
    x1, y1 = (x0 + 1) % N, (y0 + 1) % N
    return (img[y0, x0] * (1 - fx) + img[y0, x1] * fx) * (1 - fy) + (img[y1, x0] * (1 - fx) + img[y1, x1] * fx) * fy


def _sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def _layer(i, pal):
    L = LAYERS[i]
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    v = yy / (N - 1)
    dx = (_blob(L["seed"] + 100) * 2 - 1) * L["warp"]
    dy = (_blob(L["seed"] + 200) * 2 - 1) * L["warp"]
    n = _sample(_noise(L["seed"], L["tilt"], L["along"], L["across"]), xx + dx, yy + dy)
    q = (np.round(np.clip((n - L["cut"]) / (1 - L["cut"] + 1e-6), 0, 1) * 2) / 2)[..., None]  # 3 flat tones
    if i == 0:
        lo, hi = np.array(pal["core"][0]), np.array(pal["core"][1])
        col = lo * (1 - q) + hi * q
    elif i == 1:
        d, m, l = (np.array(c) for c in pal["body"])
        col = np.where(q < 0.25, d, np.where(q < 0.75, m, l))
    elif i == 2:
        col = np.broadcast_to(np.array(pal["hi"]), (N, N, 3)).copy()
    else:
        d, l = (np.array(c) for c in pal["ink"])
        col = np.where(q < 0.5, d, l)
    if i < 2:
        foam = _sm(FOAM, FOAM * 0.4, v + dy / N * 2)[..., None]
        col = col * (1 - foam) + np.array(pal["core"][1]) * foam
    return col, n


def atlas(element, erode=0.0):
    pal = PALETTES[element]
    img = np.zeros((2 * N, 2 * N, 4), np.float32)
    for i in range(4):
        col, n = _layer(i, pal)
        cut = LAYERS[i]["cut"] + erode
        a = _sm(cut, cut + 0.02, n) if cut > 0 else np.ones_like(n)
        cx, cy = (i % 2) * N, (i // 2) * N
        img[cy:cy + N, cx:cx + N, :3] = col
        img[cy:cy + N, cx:cx + N, 3] = a
    return img


def strip(element, width=1024, height=256, seed=0):
    """One flattened strip for Trails and Beams: the four layers stacked
    (core under body under highlights under ink) along a band that is thick in
    the middle and ragged at both edges. u runs along the trail and wraps."""
    pal = PALETTES[element]
    reps = width // N
    cols, alphas = [], []
    for i in range(4):
        col, n = _layer(i, pal)
        # tile across the width; squash the 512 rows down to the strip height
        rows = np.linspace(0, N - 1, height).astype(int)
        col = np.tile(col[rows], (1, reps, 1))
        n = np.tile(n[rows], (1, reps))
        cut = LAYERS[i]["cut"]
        cols.append(col)
        alphas.append(_sm(cut, cut + 0.02, n) if cut > 0 else np.ones_like(n))
    v = np.linspace(-1, 1, height)[:, None]
    edge = 0.75 + 0.2 * _blob(seed + 300)[np.linspace(0, N - 1, height).astype(int)][:, np.arange(width) % N]
    band = 1 - _sm(edge - 0.15, edge, np.abs(v))
    img = np.zeros((height, width, 4), np.float32)
    # Core only in the middle, body over the whole band, then highlights and ink.
    core_band = 1 - _sm(0.25, 0.45, np.abs(v))
    for i, (col, a) in enumerate(zip(cols, alphas)):
        a = a * band * (core_band if i == 0 else 1)
        img[..., :3] = img[..., :3] * (1 - a[..., None]) + col * a[..., None]
        img[..., 3] = np.maximum(img[..., 3], a)
    return img


def bake(element, folder, name):
    """Writes <folder>/<name>.png plus _Erode1 / _Erode2 through Blender images."""
    import bpy

    out = {}
    for suffix, erode in (("", 0.0), ("_Erode1", 0.12), ("_Erode2", 0.24)):
        img = atlas(element, erode)
        key = name + suffix
        im = bpy.data.images.get(key) or bpy.data.images.new(key, 2 * N, 2 * N, alpha=True)
        if tuple(im.size) != (2 * N, 2 * N):
            im.scale(2 * N, 2 * N)
        im.pixels.foreach_set(img.reshape(-1))
        im.filepath_raw = folder.rstrip("\\/") + "/" + key + ".png"
        im.file_format = "PNG"
        im.save()
        out[key] = img
    return out
