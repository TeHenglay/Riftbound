"""Thunder Serpent meshes for the ChainShock skill (art/skill_models/thunderserpent).

Run inside Blender (e.g. from the Blender MCP):
    exec(open(r"<repo>/tools/art/thunder_serpent.py").read())

Builds, in a scene called ThunderSerpent:
    SerpentHead     dragon-like head, snout toward -Y: skull, open lower jaw,
                    dark mouth, fangs, glowing yellow eyes under black brows,
                    curved yellow horns with black spikes, side fins
    SerpentSegment  one body segment with a black dorsal fin and side fins
                    (cloned and scaled down the body in code)
    SerpentTail     tail tip with a fan fin
Each piece is first built from simple parts, then fused into one smooth
surface (fuse(): voxel remesh, smoothing, decimation) so horns, fins and jaws
grow out of the body with soft blends instead of looking stuck on; the
texture coordinates are then copied back from the parts.
All three share ThunderSerpent_Color.png (texture()): the skin is the house
anime water layers (deep blue back, white belly, white highlight streaks, black
ink strokes) with yellow lightning zigzags, plus solid patches for the black,
yellow, white and aqua parts. Skin UVs: u along the part (0 to 0.74), v around
it (0 = back, 0.5 = belly).
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = r"C:\Users\LayPl\OneDrive\Documents\GitHub\riftbound"
FOLDER = os.path.join(REPO, "art", "skill_models", "thunderserpent")

SKIN_U = 0.74  # skin region of the texture is u in [0, 0.75)
PATCH = {"black": 0.78, "yellow": 0.84, "white": 0.906, "aqua": 0.97}
SEG = 24


def texture():
    ns = {}
    exec(open(os.path.join(REPO, "tools", "art", "anime_layer_textures.py")).read(), ns)
    pal = ns["PALETTES"]["water"]
    n0 = ns["N"]
    sm = ns["_sm"]
    w, h, skin_w = 1024, 512, 768
    img = np.zeros((h, w, 4), np.float32)
    img[..., 3] = 1
    body, _ = ns["_layer"](1, pal)
    _, nh = ns["_layer"](2, pal)
    _, ni = ns["_layer"](3, pal)

    def tile(a):
        return np.concatenate([a, a[:, : skin_w - n0]], axis=1)

    body, nh, ni = tile(body), tile(nh), tile(ni)
    v = (np.arange(h) / (h - 1))[:, None]
    d = np.abs(v - 0.5)  # 0 at the belly, 0.5 on the back
    skin = body.copy()
    kb = (1 - sm(0.12, 0.2, d))[..., None]
    skin = skin * (1 - kb) + np.array((0.88, 0.98, 1.0)) * kb
    kk = sm(0.36, 0.46, d)[..., None]
    skin = skin * (1 - kk) + np.array((0.04, 0.28, 0.72)) * kk
    ah = (sm(0.78, 0.8, nh) * sm(0.2, 0.28, d))[..., None]
    skin = skin * (1 - ah) + np.array((0.97, 1.0, 1.0)) * ah
    ink = np.array((0.02, 0.05, 0.14))
    band = sm(0.16, 0.2, d) * (1 - sm(0.26, 0.32, d))
    strokes = sm(0.7, 0.72, ni) * sm(0.3, 0.4, d)
    ai = np.clip(band * sm(0.35, 0.37, ni) + strokes, 0, 1)[..., None]
    skin = skin * (1 - ai) + ink * ai
    img[:, :skin_w, :3] = skin

    # Lightning zigzags along the body: yellow, white core, black edge.
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:skin_w].astype(np.float32)

    def seg_dist(ax, ay, bx, by):
        px, py = xx - ax, yy - ay
        ex, ey = bx - ax, by - ay
        t = np.clip((px * ex + py * ey) / (ex * ex + ey * ey + 1e-6), 0, 1)
        return np.hypot(px - ex * t, py - ey * t)

    dist = np.full((h, skin_w), 1e9, np.float32)
    for row in (0.27, 0.73, 0.06, 0.94):
        y0 = row * (h - 1)
        x = -20.0
        pts = []
        while x < skin_w + 40:
            pts.append((x, y0 + rng.uniform(-22, 22)))
            x += rng.uniform(26, 52)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dist = np.minimum(dist, seg_dist(ax, ay, bx, by))
    region = img[:, :skin_w, :3]
    region[:] = np.where((dist < 7.5)[..., None], ink, region)
    region[:] = np.where((dist < 5)[..., None], np.array((1.0, 0.84, 0.18)), region)
    region[:] = np.where((dist < 1.8)[..., None], np.array((1.0, 1.0, 0.92)), region)

    for i, c in enumerate([(0.01, 0.02, 0.05), (1.0, 0.84, 0.18), (1.0, 1.0, 1.0), (0.55, 0.92, 1.0)]):
        img[:, skin_w + i * 64 : skin_w + (i + 1) * 64, :3] = c

    os.makedirs(FOLDER, exist_ok=True)
    key = "ThunderSerpent_Color"
    im = bpy.data.images.get(key) or bpy.data.images.new(key, w, h, alpha=True)
    if tuple(im.size) != (w, h):
        im.scale(w, h)
    im.pixels.foreach_set(img.reshape(-1))
    im.filepath_raw = os.path.join(FOLDER, key + ".png")
    im.file_format = "PNG"
    im.save()
    return im


def smooth_keys(keys, n=40):
    """Densely resample (y, zc, rx, rz) keys with smoothing, for soft lofts."""
    keys = sorted(keys)
    ky = np.array([k[0] for k in keys])
    ys = np.linspace(ky.min(), ky.max(), n)
    cols = [np.interp(ys, ky, np.array([k[c] for k in keys])) for c in (1, 2, 3)]
    for col in cols:
        for _ in range(4):
            col[1:-1] = (col[:-2] + 2 * col[1:-1] + col[2:]) / 4
    return list(zip(ys, *cols))


def loft(bm, uv, rings, patch=None):
    """rings: (y, z_center, rx, rz) along Y. A closed, capped tube."""
    ys = [r[0] for r in rings]
    ymin, ymax = min(ys), max(ys)
    loops = []
    for y, zc, rx, rz in rings:
        loops.append([bm.verts.new((math.sin(j / SEG * 2 * math.pi) * rx, y, zc + math.cos(j / SEG * 2 * math.pi) * rz)) for j in range(SEG)])
    for i in range(len(rings) - 1):
        for j in range(SEG):
            j1 = (j + 1) % SEG
            f = bm.faces.new((loops[i][j], loops[i][j1], loops[i + 1][j1], loops[i + 1][j]))
            for loop, (ii, jj) in zip(f.loops, ((i, j), (i, j1 if j1 else SEG), (i + 1, j1 if j1 else SEG), (i + 1, j))):
                if patch:
                    loop[uv].uv = (patch, 0.5)
                else:
                    loop[uv].uv = (SKIN_U * (rings[ii][0] - ymin) / (ymax - ymin + 1e-9), jj / SEG)
    for ring in (list(reversed(loops[0])), loops[-1]):
        f = bm.faces.new(ring)
        for loop in f.loops:
            loop[uv].uv = (patch or 0.05, 0.5)
    return [v for ring in loops for v in ring]


def spike(bm, uv, p0, p1, p2, r0, patch, steps=12, sides=12):
    """A tapered tube along a quadratic bezier p0 -> p2 (control p1)."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    rings = []
    for s in range(steps + 1):
        t = s / steps
        c = p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t
        tan = ((p1 - p0) * 2 * (1 - t) + (p2 - p1) * 2 * t).normalized()
        side = tan.orthogonal().normalized()
        up = tan.cross(side)
        r = r0 * (1 - t) ** 1.1 + 0.006
        rings.append([bm.verts.new(c + (side * math.cos(k / sides * 2 * math.pi) + up * math.sin(k / sides * 2 * math.pi)) * r) for k in range(sides)])
    faces = []
    for s in range(steps):
        for k in range(sides):
            faces.append(bm.faces.new((rings[s][k], rings[s][(k + 1) % sides], rings[s + 1][(k + 1) % sides], rings[s + 1][k])))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    faces.append(bm.faces.new(rings[-1]))
    for f in faces:
        for loop in f.loops:
            loop[uv].uv = (patch, 0.5)


def fin(bm, uv, pts, thick, patch):
    """A fin with real thickness (the remesh needs volume), bulging in the middle."""
    n = len(pts)
    cen = sum((Vector(p) for p in pts), Vector()) / n
    a = [bm.verts.new(Vector(p) + thick) for p in pts]
    b = [bm.verts.new(Vector(p) - thick) for p in pts]
    ca, cb = bm.verts.new(cen + thick * 2.5), bm.verts.new(cen - thick * 2.5)
    faces = []
    for k in range(n):
        k1 = (k + 1) % n
        faces += [bm.faces.new((a[k], a[k1], ca)), bm.faces.new((b[k1], b[k], cb)), bm.faces.new((a[k], b[k], b[k1], a[k1]))]
    for f in faces:
        for loop in f.loops:
            loop[uv].uv = (patch, 0.5)


def head(bm, uv):
    loft(bm, uv, smooth_keys([
        (1.0, 0.0, 0.55, 0.5), (0.5, 0.08, 0.72, 0.6), (-0.2, 0.14, 0.68, 0.52),
        (-0.9, 0.12, 0.52, 0.38), (-1.6, 0.08, 0.36, 0.26), (-2.1, 0.06, 0.2, 0.14), (-2.25, 0.06, 0.05, 0.04)]))
    # Lower jaw with its fangs, hinged near y=0.3 and swung open downward.
    jaw = bmesh.new()
    juv = jaw.loops.layers.uv.new("UVMap")
    loft(jaw, juv, smooth_keys([(0.45, -0.28, 0.5, 0.22), (-0.4, -0.32, 0.44, 0.18), (-1.2, -0.3, 0.3, 0.14), (-1.8, -0.28, 0.14, 0.08), (-1.95, -0.28, 0.04, 0.03)], 30))
    for k in range(5):
        y = -0.45 - k * 0.3
        for s in (-1, 1):
            spike(jaw, juv, (s * (0.34 - k * 0.05), y, -0.22), (s * (0.33 - k * 0.05), y - 0.02, -0.05), (s * (0.31 - k * 0.05), y - 0.05, 0.1), 0.06, PATCH["white"], 5, 8)
    hinge = Vector((0, 0.3, -0.2))
    rot = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(28), 4, "X") @ Matrix.Translation(-hinge)
    bmesh.ops.transform(jaw, matrix=rot, verts=jaw.verts)
    me = bpy.data.meshes.new("tmpjaw")
    jaw.to_mesh(me)
    jaw.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    # Dark mouth between the jaws, and the upper fangs.
    loft(bm, uv, smooth_keys([(0.2, -0.25, 0.42, 0.25), (-0.6, -0.38, 0.36, 0.28), (-1.4, -0.48, 0.18, 0.18)], 16), patch=PATCH["black"])
    for k in range(5):
        y = -0.5 - k * 0.32
        for s in (-1, 1):
            spike(bm, uv, (s * (0.42 - k * 0.05), y, 0.0), (s * (0.41 - k * 0.05), y - 0.02, -0.18), (s * (0.38 - k * 0.05), y - 0.05, -0.4), 0.07, PATCH["white"], 5, 8)
    for s in (-1, 1):
        # Glowing yellow eye under a black brow ridge.
        for vtx in loft(bm, uv, smooth_keys([(-0.32, 0.42, 0.02, 0.02), (-0.5, 0.45, 0.17, 0.11), (-0.72, 0.43, 0.13, 0.08), (-0.88, 0.4, 0.02, 0.02)], 12), patch=PATCH["yellow"]):
            vtx.co.x += s * 0.5
        spike(bm, uv, (s * 0.42, -0.2, 0.52), (s * 0.55, -0.55, 0.62), (s * 0.5, -0.95, 0.5), 0.1, PATCH["black"], 10, 10)
        # Curved horns sweeping back (yellow) with a black spike under each.
        spike(bm, uv, (s * 0.3, 0.05, 0.5), (s * 0.45, 0.9, 1.05), (s * 0.8, 2.0, 1.15), 0.17, PATCH["yellow"])
        spike(bm, uv, (s * 0.45, 0.4, 0.3), (s * 0.8, 1.0, 0.5), (s * 1.0, 1.7, 0.45), 0.11, PATCH["black"])
        fin(bm, uv, [(s * 0.55, 0.5, 0.05), (s * 1.0, 1.0, 0.25), (s * 1.45, 1.45, 0.3), (s * 1.15, 1.35, 0.0), (s * 0.65, 1.0, -0.15)], Vector((0, 0, 0.04)), PATCH["aqua"])


def segment(bm, uv):
    loft(bm, uv, smooth_keys([(-0.75, 0, 0.3, 0.27), (-0.5, 0, 0.5, 0.45), (0, 0, 0.58, 0.52), (0.5, 0, 0.5, 0.45), (0.75, 0, 0.3, 0.27)], 24))
    fin(bm, uv, [(0, -0.45, 0.35), (0, 0.0, 0.5), (0, 0.55, 0.38), (0, 0.65, 1.05)], Vector((0.05, 0, 0)), PATCH["black"])
    for s in (-1, 1):
        fin(bm, uv, [(s * 0.45, -0.1, -0.05), (s * 0.95, 0.5, -0.25), (s * 0.45, 0.35, -0.2)], Vector((0, 0, 0.035)), PATCH["aqua"])


def tail(bm, uv):
    loft(bm, uv, smooth_keys([(-0.6, 0, 0.35, 0.32), (0, 0, 0.3, 0.27), (0.8, 0, 0.15, 0.13), (1.3, 0, 0.04, 0.04)], 24))
    fin(bm, uv, [(0, 0.2, 0.0), (0, 1.9, 0.9), (0, 1.5, 0.0), (0, 1.9, -0.9)], Vector((0.05, 0, 0)), PATCH["aqua"])
    fin(bm, uv, [(0, 0.6, 0.05), (0, 1.75, 0.6), (0, 1.5, 0.0), (0, 1.75, -0.6)], Vector((0.075, 0, 0)), PATCH["yellow"])


def fuse(ob, voxel, smooth_repeat, target_tris):
    """Melt the parts of `ob` into one smooth surface and copy the UVs back."""
    scn = bpy.context.scene
    src = ob.copy()
    src.data = ob.data.copy()
    scn.collection.objects.link(src)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    rem = ob.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = voxel
    rem.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier=rem.name)
    sm = ob.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = smooth_repeat
    bpy.ops.object.modifier_apply(modifier=sm.name)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > target_tris:
        dec = ob.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = target_tris / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    if not ob.data.uv_layers:
        ob.data.uv_layers.new(name="UVMap")
    dt = ob.modifiers.new("UVs", "DATA_TRANSFER")
    dt.object = src
    dt.use_loop_data = True
    dt.data_types_loops = {"UV"}
    dt.loop_mapping = "POLYINTERP_NEAREST"
    bpy.ops.object.modifier_apply(modifier=dt.name)
    for p in ob.data.polygons:
        p.use_smooth = True
    me = src.data
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.meshes.remove(me)


def build():
    scn = bpy.data.scenes.get("ThunderSerpent") or bpy.data.scenes.new("ThunderSerpent")
    bpy.context.window.scene = scn
    for o in list(scn.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for name in ("SerpentHead", "SerpentSegment", "SerpentTail"):
        old = bpy.data.meshes.get(name)
        if old and old.users == 0:
            bpy.data.meshes.remove(old)
    im = texture()
    mat = bpy.data.materials.get("ThunderSerpent") or bpy.data.materials.new("ThunderSerpent")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = im
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    out = []
    for i, (name, fn, voxel, rep, tris) in enumerate((
        ("SerpentHead", head, 0.03, 4, 9000),
        ("SerpentSegment", segment, 0.03, 4, 2500),
        ("SerpentTail", tail, 0.03, 4, 2500),
    )):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        fn(bm, uv)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        scn.collection.objects.link(ob)
        fuse(ob, voxel, rep, tris)
        ob.location.x = i * 4
        out.append(ob)
    return out


def export(obs):
    for ob in obs:
        ob.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    path = os.path.join(FOLDER, "ThunderSerpent.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_ALL", path_mode="COPY", embed_textures=False)
    for i, ob in enumerate(obs):
        ob.location.x = i * 4
    return path


if __name__ == "__main__" or True:
    for ob in build():
        print(ob.name, tuple(round(x, 2) for x in ob.dimensions), sum(len(p.vertices) - 2 for p in ob.data.polygons), "tris")
