"""Export a baked golem as the five-part foe template the game's FoeRig uses.

Run inside Blender on a golem .blend after export_golem.py has made the baked
low-poly mesh (object named PREFIX). Writes <PREFIX>_Parts.fbx with one mesh
per limb: Body, ArmL, ArmR, LegL, LegR, standing on y = 0 and facing -Z once
imported into Roblox (FBX -Y-forward Blender scenes come in facing +Z, so the
copy is turned 180 degrees first). Import it into
ServerStorage.RiftboundAssets.Foes.<Nation>Golem with the Studio 3D Importer,
unit set to Studs, and add a SurfaceAppearance from textures/ to each part.

The R15 parts named "Left..." sit on Blender -X, which is the golem's right
side once it faces the camera, so they become ArmR/LegR here.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix

LIMBS = {
    "Body": ("Head", "UpperTorso", "LowerTorso"),
    "ArmR": ("LeftUpperArm", "LeftLowerArm", "LeftHand"),
    "ArmL": ("RightUpperArm", "RightLowerArm", "RightHand"),
    "LegR": ("LeftUpperLeg", "LeftLowerLeg", "LeftFoot"),
    "LegL": ("RightUpperLeg", "RightLowerLeg", "RightFoot"),
}


def export_parts(PREFIX, OUT_DIR):
    src = bpy.data.objects[PREFIX]
    col = bpy.data.collections.get(PREFIX + "_Parts") or bpy.data.collections.new(PREFIX + "_Parts")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    group_index = {vg.name: vg.index for vg in src.vertex_groups}
    made = []
    for limb, groups in LIMBS.items():
        wanted = {group_index[g] for g in groups}
        bm = bmesh.new()
        bm.from_mesh(src.data)
        deform = bm.verts.layers.deform.active
        drop = [v for v in bm.verts if not any(k in wanted for k in v[deform].keys())]
        bmesh.ops.delete(bm, geom=drop, context='VERTS')
        bm.transform(src.matrix_world)
        # turned to face -Z in Roblox; the golem already stands on z = 0
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi, 3, 'Z'))
        me = bpy.data.meshes.new(limb)
        bm.to_mesh(me)
        bm.free()
        for m in src.data.materials:
            me.materials.append(m)
        o = bpy.data.objects.new(limb, me)
        col.objects.link(o)
        o.vertex_groups.clear()
        made.append(o)

    bpy.ops.object.select_all(action='DESELECT')
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    path = os.path.join(OUT_DIR, PREFIX + "_Parts.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False,
                             bake_anim=False)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    return path, tris
