"""Bake and export a nation golem from its working .blend for Roblox.

Run inside Blender (e.g. through the Blender MCP) with PREFIX, COLLECTION, RIG and OUT_DIR set:
builds a low-poly copy of the R15 parts, bakes the procedural rock into
Color/Emissive/Normal/Roughness maps from the high-detail parts, and writes
<PREFIX>.fbx plus one FBX per animation (Idle, Walk, Attack).
"""
import os
import bpy


def export_golem(PREFIX, COLLECTION, RIG, OUT_DIR, size=2048):
    O = bpy.data.objects
    sc = bpy.context.scene
    src = bpy.data.collections[COLLECTION]
    rig = O[RIG]
    rig.data.pose_position = 'REST'

    ex_name = PREFIX + "_Export"
    ex = bpy.data.collections.get(ex_name) or bpy.data.collections.new(ex_name)
    if ex.name not in sc.collection.children:
        sc.collection.children.link(ex)
    for o in list(ex.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    lp_groups = {}

    def low_poly_group(g):
        # same surface shape, but no subdivision and no carved crack grooves
        if g.name not in lp_groups:
            name = g.name + "LP"
            if name in bpy.data.node_groups:
                bpy.data.node_groups.remove(bpy.data.node_groups[name])
            lp = g.copy()
            lp.name = name
            for n in lp.nodes:
                if n.type in ('SUBDIVIDE_MESH', 'SUBDIVISION_SURFACE'):
                    n.inputs['Level'].default_value = 0
                if n.type == 'MATH' and n.operation == 'MULTIPLY' and n.inputs[1].default_value < 0:
                    n.inputs[1].default_value = 0.0
            lp_groups[g.name] = lp
        return lp_groups[g.name]

    meshes = [o for o in src.objects if o.type == 'MESH' and not o.hide_render]

    def copy(o, name, low=False):
        originals = {}
        if low:
            for m in o.modifiers:
                if m.type == 'NODES' and m.node_group:
                    originals[m.name] = m.node_group
                    m.node_group = low_poly_group(m.node_group)
        rigmod = o.modifiers.get("Rig")
        if rigmod:
            rigmod.show_viewport = False
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        if rigmod:
            rigmod.show_viewport = True
        for mname, group in originals.items():
            o.modifiers[mname].node_group = group
        c =bpy.data.objects.new(name, me)
        c.matrix_world = o.matrix_world.copy()
        ex.objects.link(c)
        return c

    def join(objs, name):
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        j = bpy.context.object
        j.name = name
        j.data.name = name
        return j

    H = join([copy(o, o.name + "_HP") for o in meshes], PREFIX + "_HP")
    L = join([copy(o, o.name + "_LP", low=True) for o in meshes], PREFIX)

    bpy.ops.object.select_all(action='DESELECT')
    L.select_set(True)
    bpy.context.view_layer.objects.active = L
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')

    mname = PREFIX + "_Baked"
    if mname in bpy.data.materials:
        bpy.data.materials.remove(bpy.data.materials[mname])
    m = bpy.data.materials.new(mname)
    m.use_nodes = True
    L.data.materials.clear()
    L.data.materials.append(m)
    for p in L.data.polygons:
        p.material_index = 0
    nt = m.node_tree
    for k, cs in (("Color", "sRGB"), ("Emissive", "sRGB"), ("Normal", "Non-Color"), ("Roughness", "Non-Color")):
        nm = PREFIX + "_" + k
        if nm in bpy.data.images:
            bpy.data.images.remove(bpy.data.images[nm])
        im = bpy.data.images.new(nm, size, size, alpha=False)
        im.colorspace_settings.name = cs
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = im
        n.name = k

    prev = sc.render.engine
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 1
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.12
    bk.max_ray_distance = 0.3
    bk.margin = 8
    bk.use_pass_direct = False
    bk.use_pass_indirect = False
    bk.use_pass_color = True
    bpy.ops.object.select_all(action='DESELECT')
    H.select_set(True)
    L.select_set(True)
    bpy.context.view_layer.objects.active = L
    for k, typ in (("Color", "DIFFUSE"), ("Emissive", "EMIT"), ("Normal", "NORMAL"), ("Roughness", "ROUGHNESS")):
        for n in nt.nodes:
            n.select = False
        nt.nodes[k].select = True
        nt.nodes.active = nt.nodes[k]
        if typ == "DIFFUSE":
            bpy.ops.object.bake(type=typ, pass_filter={'COLOR'})
        else:
            bpy.ops.object.bake(type=typ)
    sc.render.engine = prev

    tex = os.path.join(OUT_DIR, "textures")
    os.makedirs(tex, exist_ok=True)
    for k in ("Color", "Emissive", "Normal", "Roughness"):
        im = bpy.data.images[PREFIX + "_" + k]
        im.filepath_raw = os.path.join(tex, PREFIX + "_" + k + ".png")
        im.file_format = 'PNG'
        im.save()

    N = nt.nodes
    b = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
    nt.links.new(N["Color"].outputs[0], b.inputs['Base Color'])
    nt.links.new(N["Roughness"].outputs[0], b.inputs['Roughness'])
    nmap = N.new('ShaderNodeNormalMap')
    nt.links.new(N["Normal"].outputs[0], nmap.inputs['Color'])
    nt.links.new(nmap.outputs[0], b.inputs['Normal'])
    nt.links.new(N["Emissive"].outputs[0], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 6

    H.hide_render = True
    H.hide_viewport = True
    L.parent = rig
    md = L.modifiers.get("Rig") or L.modifiers.new("Rig", 'ARMATURE')
    md.object = rig

    ad = rig.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = None
    for p in rig.pose.bones:
        p.rotation_euler = (0, 0, 0)
        p.location = (0, 0, 0)
    common = dict(use_selection=True, add_leaf_bones=False, mesh_smooth_type='FACE',
                  path_mode='COPY', embed_textures=False, primary_bone_axis='Y', secondary_bone_axis='X')
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    L.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, PREFIX + ".fbx"),
                             object_types={'ARMATURE', 'MESH'}, bake_anim=False, **common)
    rig.data.pose_position = 'POSE'
    for name in ("Idle", "Walk", "Attack"):
        act = bpy.data.actions[name]
        ad.action = act
        sc.frame_start, sc.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, f"{PREFIX}_{name}.fbx"),
                                 object_types={'ARMATURE'}, bake_anim=True, bake_anim_use_all_actions=False,
                                 bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
                                 bake_anim_simplify_factor=0.0, **common)
    ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    sc.frame_start, sc.frame_end = 1, 213
    sc.frame_set(1)
    return sum(len(p.vertices) - 2 for p in L.data.polygons)
