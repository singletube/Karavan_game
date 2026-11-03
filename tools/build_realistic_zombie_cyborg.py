# -*- coding: utf-8 -*-
"""
Master Blender Script: Realistic Post-Apocalyptic Zombie Cyborg
Builds an anatomical ZBrush-sculpted zombie cyborg with:
- Full 2K/4K PBR textures (necrotic veined skin, brushed titanium, dark gunmetal, wet surgical flesh, torn cloth)
- Amputated left arm replaced with hydraulic cyber-prosthetic + serrated forearm ripper blade + 4-claw mechanical hand
- Amputated left leg replaced with twin-strut hydraulic bionic leg + shock absorber + mechanical claw foot
- Form-fitting bolted cranial titanium skull plate + glowing multi-lens crimson optical scanner + cyber-mandible respirator
- Surgical chest cavity with exposed ribs & glowing crimson cyber-core reactor + 8-segment dorsal exo-spine + neural cables
- Conforming torn post-apocalyptic tactical vest, distressed cargo pants, and laced combat boot
- Clean 23-bone humanoid armature (ZombieRig) with 7 full skeletal animations:
  Idle, Walk, Run, Attack, Hit, Death, Roar
"""

import bpy
import bmesh
import math
import random
import os
import shutil
from mathutils import Vector, Matrix, Euler, Quaternion

random.seed(42)

# ─── PATHS ────────────────────────────────────────────────────────────────────
PROJECT_DIR = r"c:\Users\user\Documents\идет-караван-из-ирана"
TEX_DIR     = os.path.join(PROJECT_DIR, "models", "zombies", "textures")
ACC_DIR     = os.path.join(PROJECT_DIR, "models", "zombies", "accessories")
ZOMBIE_FBX  = r"C:\Users\user\.gemini\antigravity\brain\648db63a-c814-40a9-817a-7195fe9a5e11\scratch\zombie1_unzip\source\zombie1.fbx"

OUT_DIR     = r"C:\Users\user\ZombieCyborg"
os.makedirs(OUT_DIR, exist_ok=True)
BLEND_PATH  = os.path.join(OUT_DIR, "zombie_cyborg.blend")
GLB_PATH    = os.path.join(OUT_DIR, "zombie_cyborg.glb")
FBX_PATH    = os.path.join(OUT_DIR, "zombie_cyborg.fbx")
GAME_GLB    = os.path.join(PROJECT_DIR, "models", "zombies", "zombie_cyborg.glb")

# ─── 1. CLEAR SCENE ───────────────────────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.render.fps = 24

# ─── 2. PBR MATERIAL FACTORY (glTF & Cycles Compatible) ──────────────────────
def load_image_cached(filename, non_color=False):
    path = os.path.join(TEX_DIR, filename)
    if not os.path.exists(path):
        return None
    for img in bpy.data.images:
        if img.filepath == path:
            return img
    img = bpy.data.images.load(path)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    return img

def make_pbr_mat(name, base_color=(0.5, 0.5, 0.5, 1.0), metallic=0.0, roughness=0.5,
                 albedo_tex=None, normal_tex=None, rough_tex=None,
                 emission_color=None, emission_strength=0.0, normal_strength=1.0, uv_scale=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (500, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (180, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness

    mapping_out = None
    if uv_scale != 1.0 and (albedo_tex or normal_tex or rough_tex):
        tc = nodes.new("ShaderNodeTexCoord")
        tc.location = (-750, 0)
        mp = nodes.new("ShaderNodeMapping")
        mp.location = (-550, 0)
        mp.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
        links.new(tc.outputs["UV"], mp.inputs["Vector"])
        mapping_out = mp.outputs["Vector"]

    if albedo_tex:
        img = load_image_cached(albedo_tex, non_color=False)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-280, 220)
            tex.image = img
            if mapping_out:
                links.new(mapping_out, tex.inputs["Vector"])
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    if rough_tex:
        img = load_image_cached(rough_tex, non_color=True)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-280, -40)
            tex.image = img
            if mapping_out:
                links.new(mapping_out, tex.inputs["Vector"])
            links.new(tex.outputs["Color"], bsdf.inputs["Roughness"])

    if normal_tex:
        img = load_image_cached(normal_tex, non_color=True)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-320, -320)
            tex.image = img
            if mapping_out:
                links.new(mapping_out, tex.inputs["Vector"])
            nmap = nodes.new("ShaderNodeNormalMap")
            nmap.location = (-60, -320)
            nmap.inputs["Strength"].default_value = normal_strength
            links.new(tex.outputs["Color"], nmap.inputs["Color"])
            links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    if emission_color and emission_strength > 0:
        for k in ("Emission Color", "Emission"):
            if k in bsdf.inputs:
                bsdf.inputs[k].default_value = (*emission_color[:3], 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength

    return mat

MAT = {
    "Skin": make_pbr_mat(
        "Skin", base_color=(0.45, 0.48, 0.42, 1.0), metallic=0.0, roughness=0.62,
        albedo_tex="zombie_skin_albedo.png", normal_tex="zombie_skin_normal.png",
        rough_tex="zombie_skin_roughness.png", normal_strength=1.35
    ),
    "Meat": make_pbr_mat(
        "Meat", base_color=(0.32, 0.03, 0.03, 1.0), metallic=0.0, roughness=0.22,
        albedo_tex="zombie_meat_albedo.png", normal_tex="mummy_flesh_normal.png",
        normal_strength=1.5, uv_scale=2.0
    ),
    "Steel": make_pbr_mat(
        "SteelWorn", base_color=(0.56, 0.58, 0.62, 1.0), metallic=0.88, roughness=0.36,
        albedo_tex="cyber_steel.png", normal_tex="cyber_armor_normal.png",
        rough_tex="cyber_armor_roughness.png", normal_strength=1.1
    ),
    "GunMetal": make_pbr_mat(
        "GunMetal", base_color=(0.16, 0.17, 0.20, 1.0), metallic=0.92, roughness=0.30,
        albedo_tex="cyber_gunmetal.png", normal_tex="cyber_armor_normal.png",
        rough_tex="cyber_armor_roughness.png", normal_strength=1.0
    ),
    "Chrome": make_pbr_mat(
        "ChromeHydraulic", base_color=(0.82, 0.85, 0.88, 1.0), metallic=0.98, roughness=0.12
    ),
    "Copper": make_pbr_mat(
        "CopperWire", base_color=(0.68, 0.36, 0.16, 1.0), metallic=0.88, roughness=0.32
    ),
    "Rubber": make_pbr_mat(
        "RubberHose", base_color=(0.04, 0.04, 0.05, 1.0), metallic=0.15, roughness=0.72,
        albedo_tex="cyber_gunmetal.png", normal_tex="cyber_armor_normal.png", normal_strength=0.9
    ),
    "Pants": make_pbr_mat(
        "PantsCloth", base_color=(0.08, 0.11, 0.15, 1.0), metallic=0.0, roughness=0.88,
        albedo_tex="zombie_pants_albedo.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=1.2
    ),
    "Shirt": make_pbr_mat(
        "ShirtCloth", base_color=(0.10, 0.11, 0.09, 1.0), metallic=0.0, roughness=0.90,
        albedo_tex="zombie_shirt_albedo.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=1.2
    ),
    "Leather": make_pbr_mat(
        "DarkLeather", base_color=(0.06, 0.05, 0.04, 1.0), metallic=0.15, roughness=0.52,
        albedo_tex="cyber_gunmetal.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=0.9
    ),
    "Bone": make_pbr_mat(
        "BoneYellowed", base_color=(0.74, 0.68, 0.54, 1.0), metallic=0.0, roughness=0.46
    ),
    "EyeDead": make_pbr_mat(
        "EyeDead", base_color=(0.68, 0.72, 0.66, 1.0), metallic=0.0, roughness=0.10
    ),
    "GlowRed": make_pbr_mat(
        "GlowRed", base_color=(1.0, 0.08, 0.02, 1.0), metallic=0.1, roughness=0.15,
        albedo_tex="optic_lens.png", emission_color=(1.0, 0.06, 0.01), emission_strength=14.0
    ),
    "GlowOrange": make_pbr_mat(
        "GlowOrange", base_color=(1.0, 0.32, 0.02, 1.0), metallic=0.0, roughness=0.2,
        emission_color=(1.0, 0.25, 0.02), emission_strength=8.0
    ),
}

def assign_mat(obj, mat_key):
    mat = MAT[mat_key]
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    return obj

def smooth_shade(obj):
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj

# ─── 3. IMPORT & PREPARE ZBRUSH ANATOMICAL ZOMBIE BASE (`zombie1.fbx`) ───────
print("Importing anatomical zombie1.fbx...")
bpy.ops.import_scene.fbx(filepath=ZOMBIE_FBX)

orig_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
orig_body = next(o for o in bpy.data.objects if o.type == 'MESH')
for o in list(bpy.data.objects):
    if o not in (orig_arm, orig_body):
        bpy.data.objects.remove(o, do_unlink=True)

# Clear C4D T-pose animation & IK constraints so we control the exact rest pose
orig_arm.animation_data_clear()
for pb in orig_arm.pose.bones:
    pb.matrix_basis.identity()
    for c in list(pb.constraints):
        pb.constraints.remove(c)

# Center feet at (0,0,0) and apply scale/rotation
orig_arm.location = Vector((0.0, 0.118, 0.017))
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
orig_arm.select_set(True)
orig_body.select_set(True)
bpy.context.view_layer.objects.active = orig_arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Adduct arms down 26 degrees from T-pose into natural menacing cyborg stance
def rotate_pose_bone_world(arm_obj, bone_name, euler_xyz):
    pb = arm_obj.pose.bones[bone_name]
    R_world = Euler(euler_xyz, 'XYZ').to_matrix().to_3x3()
    R_bone = (arm_obj.matrix_world @ pb.bone.matrix_local).to_3x3()
    pb.matrix_basis = (R_bone.inverted() @ R_world @ R_bone).to_4x4()

rotate_pose_bone_world(orig_arm, "L_arm", (0.04, math.radians(26), math.radians(-6)))
rotate_pose_bone_world(orig_arm, "R_arm", (0.04, math.radians(-26), math.radians(6)))
rotate_pose_bone_world(orig_arm, "L_elbow", (math.radians(12), 0, math.radians(-8)))
rotate_pose_bone_world(orig_arm, "R_elbow", (math.radians(14), 0, math.radians(8)))
bpy.context.view_layer.update()

# Record posed joint coordinates before applying armature modifier
JOINT_POS = {}
for pb in orig_arm.pose.bones:
    JOINT_POS[pb.name] = (orig_arm.matrix_world @ pb.head).copy()
    JOINT_POS[pb.name + "_tail"] = (orig_arm.matrix_world @ pb.tail).copy()

# Bake posed mesh into new rest geometry
bpy.ops.object.select_all(action='DESELECT')
orig_body.select_set(True)
bpy.context.view_layer.objects.active = orig_body
for mod in list(orig_body.modifiers):
    if mod.type == 'ARMATURE':
        bpy.ops.object.modifier_apply(modifier=mod.name)

# Unparent body from old Armature and delete old Armature + old C4D actions
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.data.objects.remove(orig_arm, do_unlink=True)
for old_act in list(bpy.data.actions):
    bpy.data.actions.remove(old_act, do_unlink=True)

orig_body.name = "ZombieBody"
assign_mat(orig_body, "Skin")
smooth_shade(orig_body)

# ─── 4. EXTRACT CONFORMING TORN CLOTHING & CRANIAL PLATE FROM ANATOMICAL MESH ─
def extract_conforming_shell(src_obj, name, face_filter_fn, offset=0.0045, thickness=0.004, mat_key="Shirt"):
    bpy.ops.object.select_all(action='DESELECT')
    src_obj.select_set(True)
    bpy.context.view_layer.objects.active = src_obj
    bpy.ops.object.duplicate()
    shell = bpy.context.active_object
    shell.name = name

    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.faces.ensure_lookup_table()
    to_del = [f for f in bm.faces if not face_filter_fn(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=to_del, context='FACES')

    # Push vertices outward along vertex normal + slight organic cloth ripple
    for v in bm.verts:
        co = v.co
        ripple = 0.0015 * math.sin(co.x * 28.0 + co.z * 19.0) * math.cos(co.y * 23.0)
        v.co += v.normal * (offset + ripple)

    bm.to_mesh(shell.data)
    bm.free()
    shell.data.update()

    # Solidify for thick realistic edges
    if thickness > 0:
        sol = shell.modifiers.new("Solidify", 'SOLIDIFY')
        sol.thickness = thickness
        sol.offset = 1.0
        bpy.context.view_layer.objects.active = shell
        bpy.ops.object.modifier_apply(modifier=sol.name)

    assign_mat(shell, mat_key)
    smooth_shade(shell)
    return shell

# 4A. Torn Tactical Vest / Shirt (ripped open over right chest cyber-core & open along back exo-spine)
def shirt_filter(c, n):
    if c.z < 1.15 or c.z > 1.56:
        return False
    if abs(c.x) > 0.205:
        return False
    # Cut out surgical chest reactor window on right chest
    if c.x < 0.015 and c.y < -0.01 and 1.24 < c.z < 1.49:
        return False
    # Cut out vertical dorsal channel on the back so the mechanical Exo-Spine is fully exposed
    if c.y > 0.02 and abs(c.x) < 0.048 and 1.14 < c.z < 1.57:
        return False
    # Jagged tattered hem at bottom
    hem = 1.17 + 0.045 * math.sin(c.x * 35.0 + c.y * 18.0) + 0.025 * math.cos(c.x * 65.0)
    if c.z < hem:
        return False
    return True

shirt_obj = extract_conforming_shell(orig_body, "TacticalTornShirt", shirt_filter, offset=0.004, thickness=0.0035, mat_key="Shirt")

# 4B. Torn Post-Apocalyptic Cargo Pants (strictly pelvis & thighs: abs(c.x) < 0.235 so hands are NEVER included!)
def pants_filter(c, n):
    if c.z > 1.03 or c.z < 0.42:
        return False
    if abs(c.x) > 0.235:
        return False
    # Jagged waistband
    waist = 1.015 + 0.018 * math.sin(c.x * 40.0 + c.y * 25.0)
    if c.z > waist:
        return False
    # Left leg (x > 0): shredded high on thigh at z = 0.69..0.74 to expose cyber-knee & thigh graft
    if c.x >= 0.0:
        hem_l = 0.71 + 0.032 * math.sin(c.x * 40.0 + c.y * 30.0)
        if c.z < hem_l:
            return False
    else:
        # Right leg (x < 0): tattered below knee at z = 0.45..0.52
        hem_r = 0.47 + 0.035 * math.cos(c.x * 45.0 - c.y * 35.0)
        if c.z < hem_r:
            return False
        # Knee rip hole on front right thigh
        if c.y < -0.04 and 0.58 < c.z < 0.66 and -0.21 < c.x < -0.12:
            return False
    return True

pants_obj = extract_conforming_shell(orig_body, "TornCargoPants", pants_filter, offset=0.005, thickness=0.004, mat_key="Pants")

# 4C. Form-Fitting Bolted Cranial Titanium Skull Plate (Left Front-Parietal-Temporal Dome)
def cranial_filter(c, n):
    if c.z < 1.765 or c.x < -0.008:
        return False
    return True

cranial_plate = extract_conforming_shell(orig_body, "CranialTitaniumPlate", cranial_filter, offset=0.0025, thickness=0.0045, mat_key="Steel")

# 4D. Conforming Laced Combat Boot on Right Foot/Ankle (extracted from anatomical right ankle/foot + armored sole)
def boot_shell_filter(c, n):
    return c.x < -0.05 and c.z < 0.285

boot_shell = extract_conforming_shell(orig_body, "RightCombatBootUpper", boot_shell_filter, offset=0.0055, thickness=0.005, mat_key="Leather")

# ─── 5. AMPUTATE ORGANIC LEFT FORE-LIMB & LEFT LOWER LEG + CHEST CAVITY ──────
bm = bmesh.new()
bm.from_mesh(orig_body.data)
bm.faces.ensure_lookup_table()

amputate_faces = []
for f in bm.faces:
    c = f.calc_center_median()
    # 1. Left arm below upper deltoid/bicep (x > 0.225, z < 1.39) -> replaced by cybernetic prosthetic
    if c.x > 0.225 and c.z < 1.39:
        amputate_faces.append(f)
    # 2. Left leg below mid-thigh (x > 0.02, z < 0.64) -> replaced by hydraulic cyber-leg
    elif c.x > 0.02 and c.z < 0.64:
        amputate_faces.append(f)
    # 3. Right foot below ankle (x < -0.02, z < 0.16) -> replaced by heavy combat boot
    elif c.x < -0.02 and c.z < 0.16:
        amputate_faces.append(f)

bmesh.ops.delete(bm, geom=amputate_faces, context='FACES')

# Carve recessed surgical cavity in right pectoral for the cyber-core reactor
for v in bm.verts:
    c = v.co
    if -0.13 < c.x < -0.015 and c.y < -0.04 and 1.31 < c.z < 1.45:
        dist = math.sqrt(((c.x + 0.07) / 0.06)**2 + ((c.z - 1.38) / 0.07)**2)
        if dist < 1.0:
            v.co.y += 0.032 * (1.0 - dist)

bm.to_mesh(orig_body.data)
bm.free()
orig_body.data.update()

# ─── 6. PROCEDURAL & KITBASH CYBERNETIC BUILDERS ─────────────────────────────
CYBER_PARTS = []  # List of (obj, parent_bone_name)

TARGET_UV_NAME = orig_body.data.uv_layers[0].name if orig_body.data.uv_layers else "UVMap"

def box_project_uv(obj, scale=2.6):
    bpy.context.view_layer.update()
    mesh = obj.data
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    mesh.uv_layers.new(name=TARGET_UV_NAME)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.verify()
    mw = obj.matrix_world
    rot_mw = mw.to_3x3()
    for f in bm.faces:
        n = (rot_mw @ f.normal).normalized()
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = mw @ loop.vert.co
            if ax >= ay and ax >= az:
                u, v = co.y * scale + 0.5, co.z * scale - 0.2
            elif ay >= ax and ay >= az:
                u, v = co.x * scale + 0.5, co.z * scale - 0.2
            else:
                u, v = co.x * scale + 0.5, co.y * scale + 0.5
            loop[uv_layer].uv = (u, v)
    bm.to_mesh(mesh)
    bm.free()

def reg_part(obj, bone_name, mat_key="Steel"):
    box_project_uv(obj, scale=3.2)
    assign_mat(obj, mat_key)
    smooth_shade(obj)
    CYBER_PARTS.append((obj, bone_name))
    return obj

def make_cyl_between(name, p1, p2, r1, r2=None, verts=16, mat_key="Steel", bone_name="Chest"):
    if r2 is None:
        r2 = r1
    p1 = Vector(p1)
    p2 = Vector(p2)
    vec = p2 - p1
    length = vec.length
    mid = (p1 + p2) * 0.5
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=length, location=mid)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec.normalized())
    obj.rotation_mode = 'XYZ'
    return reg_part(obj, bone_name, mat_key)

def make_tube_curve(name, points, radius=0.008, mat_key="Rubber", bone_name="Chest", corrugated=False):
    crv = bpy.data.curves.new(name + "_crv", 'CURVE')
    crv.dimensions = '3D'
    crv.bevel_depth = radius
    crv.bevel_resolution = 5
    crv.use_fill_caps = True
    spl = crv.splines.new('CATMULL_ROM' if hasattr(crv.splines, 'CATMULL_ROM') else 'POLY')
    spl.points.add(len(points) - 1)
    for i, pt in enumerate(points):
        spl.points[i].co = (pt[0], pt[1], pt[2], 1.0)
    obj = bpy.data.objects.new(name, crv)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    if corrugated:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for i, v in enumerate(bm.verts):
            if (i // 12) % 2 == 0:
                v.co += v.normal * (radius * 0.25)
        bm.to_mesh(obj.data)
        bm.free()
    return reg_part(obj, bone_name, mat_key)

def make_bolt_ring(name, center, axis_vec, radius, count=8, bolt_r=0.005, mat_key="Steel", bone_name="Chest"):
    center = Vector(center)
    z_ax = Vector(axis_vec).normalized()
    up = Vector((0, 0, 1)) if abs(z_ax.z) < 0.9 else Vector((1, 0, 0))
    x_ax = z_ax.cross(up).normalized()
    y_ax = z_ax.cross(x_ax).normalized()
    bm = bmesh.new()
    for i in range(count):
        ang = (2.0 * math.pi * i) / count
        pos = center + (x_ax * math.cos(ang) + y_ax * math.sin(ang)) * radius
        rot = Matrix((x_ax, y_ax, z_ax)).transposed().to_4x4()
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=6,
            radius1=bolt_r, radius2=bolt_r * 0.85, depth=bolt_r * 1.4,
            matrix=Matrix.Translation(pos) @ rot
        )
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return reg_part(obj, bone_name, mat_key)

# ─── 6A. CRANIAL & FACIAL CYBERNETICS (`Head` & `Jaw`) ───────────────────────
L_EYE = JOINT_POS["L_eye"]   # (0.0338, -0.0948, 1.8029)
R_EYE = JOINT_POS["R_eye"]   # (-0.0338, -0.0948, 1.8029)
HEAD_P = JOINT_POS["head"]   # (0.0000, -0.0133, 1.7261)
JAW_P  = JOINT_POS["jaw"]    # (0.0000, -0.0531, 1.7225)
LIP_P  = JOINT_POS["lip"]    # (0.0000, -0.1226, 1.7098)

# Register extracted CranialTitaniumPlate to Head & box-project UVs on cranial plate and boot
box_project_uv(cranial_plate, scale=3.2)
box_project_uv(boot_shell, scale=3.2)
CYBER_PARTS.append((cranial_plate, "Head"))

# Bloody necrotic surgical tissue rim along cranial plate edge
make_tube_curve("CranialSurgicalScar", [
    (0.0, -0.105, 1.865), (0.0, -0.075, 1.895), (0.0, 0.015, 1.902),
    (0.0, 0.085, 1.860), (0.045, 0.088, 1.785), (0.072, -0.015, 1.770),
    (0.058, -0.088, 1.775)
], radius=0.0055, mat_key="Meat", bone_name="Head")

# Multi-lens Tactical Optical Scanner on Left Eye
optic_dir = Vector((0.08, -1.0, -0.04)).normalized()
make_cyl_between("CyberOpticMount", L_EYE + Vector((0.002, 0.012, 0.0)), L_EYE + optic_dir * 0.026, 0.025, 0.021, verts=20, mat_key="GunMetal", bone_name="Head")
make_cyl_between("CyberOpticBezel", L_EYE + optic_dir * 0.020, L_EYE + optic_dir * 0.033, 0.021, 0.017, verts=20, mat_key="Steel", bone_name="Head")
make_cyl_between("CyberOpticLensGlow", L_EYE + optic_dir * 0.028, L_EYE + optic_dir * 0.035, 0.014, 0.012, verts=20, mat_key="GlowRed", bone_name="Head")
make_bolt_ring("CyberOpticBolts", L_EYE + optic_dir * 0.025, optic_dir, 0.0185, count=6, bolt_r=0.0025, mat_key="Chrome", bone_name="Head")

# Secondary micro-targeter laser sensor above left brow
brow_pos = L_EYE + Vector((0.018, -0.004, 0.024))
make_cyl_between("CyberBrowSensor", brow_pos, brow_pos + optic_dir * 0.018, 0.008, 0.006, verts=12, mat_key="GunMetal", bone_name="Head")
make_cyl_between("CyberBrowLaser", brow_pos + optic_dir * 0.015, brow_pos + optic_dir * 0.020, 0.0045, 0.004, verts=12, mat_key="GlowRed", bone_name="Head")

# Dead milky right organic eyeball sunk in socket
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.0125, location=R_EYE + Vector((0.0, -0.004, 0.0)))
reye = bpy.context.active_object
reye.name = "DeadRightEye"
reg_part(reye, "Head", "EyeDead")

# Cybernetic Mandible Respirator / Lower Jaw Clamp (`Jaw`)
jaw_chin = Vector((0.0, -0.118, 1.678))
jaw_l    = Vector((0.052, -0.058, 1.718))
jaw_r    = Vector((-0.052, -0.058, 1.718))
make_cyl_between("JawStrutL", jaw_l, jaw_chin + Vector((0.022, 0.005, 0.004)), 0.011, 0.014, verts=10, mat_key="GunMetal", bone_name="Jaw")
make_cyl_between("JawStrutR", jaw_r, jaw_chin + Vector((-0.022, 0.005, 0.004)), 0.011, 0.014, verts=10, mat_key="GunMetal", bone_name="Jaw")
make_cyl_between("JawChinGuard", jaw_chin + Vector((-0.026, 0.002, 0.0)), jaw_chin + Vector((0.026, 0.002, 0.0)), 0.016, 0.016, verts=12, mat_key="Steel", bone_name="Jaw")

# Dual side respirator filter canisters on mandible
for s, tag in ((1.0, "L"), (-1.0, "R")):
    p_start = Vector((s * 0.032, -0.105, 1.682))
    p_end   = Vector((s * 0.052, -0.118, 1.668))
    make_cyl_between(f"JawFilter_{tag}", p_start, p_end, 0.013, 0.015, verts=14, mat_key="GunMetal", bone_name="Jaw")
    make_cyl_between(f"JawFilterCap_{tag}", p_end, p_end + (p_end - p_start).normalized() * 0.005, 0.014, 0.011, verts=14, mat_key="Steel", bone_name="Jaw")

# Steel teeth/fang grille inside lower jaw
for i in range(-3, 4):
    tx = i * 0.0075
    ty = -0.114 + abs(i) * 0.0025
    make_cyl_between(f"CyberTooth_{i}", (tx, ty, 1.686), (tx, ty - 0.002, 1.704), 0.0032, 0.0008, verts=6, mat_key="Chrome", bone_name="Jaw")

# Corrugated breathing tubes from jaw filters directly into upper chest intake sockets
make_tube_curve("RespiratorHoseL", [
    (0.042, -0.108, 1.680), (0.048, -0.112, 1.662), (0.060, -0.104, 1.605), (0.054, -0.096, 1.540), (0.036, -0.084, 1.478)
], radius=0.0095, mat_key="Rubber", bone_name="Chest", corrugated=True)
make_tube_curve("RespiratorHoseR", [
    (-0.042, -0.108, 1.680), (-0.048, -0.112, 1.662), (-0.060, -0.104, 1.605), (-0.054, -0.096, 1.540), (-0.036, -0.084, 1.478)
], radius=0.0095, mat_key="Rubber", bone_name="Chest", corrugated=True)
make_cyl_between("JawHoseCollarL", (0.042, -0.108, 1.680), (0.047, -0.111, 1.665), 0.013, 0.012, verts=12, mat_key="Steel", bone_name="Jaw")
make_cyl_between("JawHoseCollarR", (-0.042, -0.108, 1.680), (-0.047, -0.111, 1.665), 0.013, 0.012, verts=12, mat_key="Steel", bone_name="Jaw")
make_cyl_between("ChestIntakePortL", (0.036, -0.096, 1.485), (0.036, -0.078, 1.475), 0.015, 0.017, verts=12, mat_key="GunMetal", bone_name="Chest")
make_cyl_between("ChestIntakePortR", (-0.036, -0.096, 1.485), (-0.036, -0.078, 1.475), 0.015, 0.017, verts=12, mat_key="GunMetal", bone_name="Chest")

# ─── 6B. CHEST REACTOR CORE, EXPOSED RIBS, ARMOR & EXO-SPINE (`Chest`/`Spine`) ─
CORE_POS = Vector((-0.065, -0.095, 1.385))
core_dir = Vector((-0.18, -1.0, 0.05)).normalized()

# Bloody surgical meat bed inside right chest cavity
bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=0.068, location=CORE_POS + Vector((0.008, 0.022, 0.0)))
meat_bed = bpy.context.active_object
meat_bed.name = "ChestSurgicalMeat"
meat_bed.scale = (0.95, 0.45, 1.05)
reg_part(meat_bed, "Chest", "Meat")

# 4 Exposed broken yellowed ribs arching across the surgical chest cavity
for idx, rz in enumerate((1.435, 1.402, 1.368, 1.335)):
    make_tube_curve(f"ExposedRib_{idx}", [
        (-0.012, -0.104, rz),
        (-0.045, -0.114, rz + 0.004),
        (-0.088, -0.106, rz - 0.003),
        (-0.122, -0.078, rz - 0.010)
    ], radius=0.0055, mat_key="Bone", bone_name="Chest")

# High-detail glowing Crimson Cyber-Heart / Reactor Core inside the ribcage
make_cyl_between("ChestCoreHousing", CORE_POS + core_dir * (-0.015), CORE_POS + core_dir * 0.022, 0.046, 0.040, verts=24, mat_key="GunMetal", bone_name="Chest")
make_cyl_between("ChestCoreRing", CORE_POS + core_dir * 0.018, CORE_POS + core_dir * 0.028, 0.041, 0.034, verts=24, mat_key="Steel", bone_name="Chest")
make_cyl_between("ChestCoreTurbine", CORE_POS + core_dir * 0.022, CORE_POS + core_dir * 0.032, 0.029, 0.025, verts=20, mat_key="GlowRed", bone_name="Chest")
make_bolt_ring("ChestCoreBolts", CORE_POS + core_dir * 0.024, core_dir, 0.037, count=8, bolt_r=0.0035, mat_key="Chrome", bone_name="Chest")

# Heavy bolted steel pectoral armor plate on Left Chest + Cross-Chest Harness
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.072, -0.098, 1.405))
l_pec_plate = bpy.context.active_object
l_pec_plate.name = "LeftPectoralArmor"
l_pec_plate.scale = (0.068, 0.022, 0.076)
l_pec_plate.rotation_euler = (math.radians(8), math.radians(-12), math.radians(-14))
bpy.ops.object.transform_apply(scale=True)
bev = l_pec_plate.modifiers.new("Bevel", 'BEVEL')
bev.width = 0.006
bev.segments = 2
bpy.ops.object.modifier_apply(modifier=bev.name)
reg_part(l_pec_plate, "Chest", "Steel")
make_bolt_ring("LeftPecBolts", (0.072, -0.110, 1.405), (0.18, -1.0, 0.08), 0.048, count=6, bolt_r=0.004, mat_key="GunMetal", bone_name="Chest")

# Dorsal 9-Vertebra Mechanical Exo-Spine (`Spine` & `Chest`) + Occipital Neural Cables
spine_pts = [
    (0.0, 0.095, 1.04), (0.0, 0.100, 1.11), (0.0, 0.106, 1.18),
    (0.0, 0.114, 1.25), (0.0, 0.120, 1.32), (0.0, 0.124, 1.39),
    (0.0, 0.122, 1.46), (0.0, 0.112, 1.53), (0.0, 0.096, 1.60)
]
make_tube_curve("ExoSpineRailL", [(x + 0.020, y, z) for (x, y, z) in spine_pts], radius=0.0065, mat_key="Chrome", bone_name="Chest")
make_tube_curve("ExoSpineRailR", [(x - 0.020, y, z) for (x, y, z) in spine_pts], radius=0.0065, mat_key="Chrome", bone_name="Chest")

for idx, (sx, sy, sz) in enumerate(spine_pts):
    b_parent = "Spine" if sz < 1.29 else "Chest"
    # Vertebra block protruding cleanly from the open back surgical channel
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, sy + 0.012, sz))
    vb = bpy.context.active_object
    vb.name = f"ExoVertebra_{idx}"
    vb.scale = (0.036, 0.026, 0.026)
    vb.rotation_euler = (math.radians(-8), 0, 0)
    bpy.ops.object.transform_apply(scale=True)
    reg_part(vb, b_parent, "GunMetal" if idx % 2 == 0 else "Steel")
    # glowing dorsal node on alternating vertebrae
    if idx in (1, 3, 5, 7):
        make_cyl_between(f"SpineGlow_{idx}", (sx, sy + 0.022, sz), (sx, sy + 0.031, sz), 0.008, 0.006, verts=12, mat_key="GlowOrange", bone_name=b_parent)

# Neural cables from back of skull into dorsal exo-spine
for s, tag in ((1.0, "L"), (-1.0, "R")):
    make_tube_curve(f"NeuralCable_{tag}", [
        (s * 0.024, 0.068, 1.755),
        (s * 0.034, 0.095, 1.665),
        (s * 0.028, 0.105, 1.565),
        (s * 0.020, 0.108, 1.460)
    ], radius=0.0065, mat_key="Rubber", bone_name="Chest", corrugated=True)

# ─── 6C. HEAVY INDUSTRIAL CYBERNETIC LEFT ARM (`UpperArm.L`, `Forearm.L`, `Hand.L`) ─
P_SH_L = JOINT_POS["L_arm"]    # (0.1878, 0.0105, 1.5096)
P_EL_L = JOINT_POS["L_elbow"]  # (0.2930, -0.0330, 1.2780)
P_WR_L = JOINT_POS["L_wrist"]  # (0.3481, -0.1560, 1.0476)

# 1. Bloody surgical graft cuff & bolted shoulder pauldron (`UpperArm.L`)
stump_pos = P_SH_L.lerp(P_EL_L, 0.45)
arm_dir_u = (P_EL_L - P_SH_L).normalized()
make_cyl_between("LeftArmMeatStump", P_SH_L.lerp(P_EL_L, 0.36), P_SH_L.lerp(P_EL_L, 0.50), 0.060, 0.054, verts=18, mat_key="Meat", bone_name="UpperArm.L")
make_cyl_between("LeftArmGraftCollar", P_SH_L.lerp(P_EL_L, 0.44), P_SH_L.lerp(P_EL_L, 0.56), 0.058, 0.052, verts=20, mat_key="GunMetal", bone_name="UpperArm.L")
make_bolt_ring("LeftArmGraftBolts", P_SH_L.lerp(P_EL_L, 0.49), arm_dir_u, 0.057, count=8, bolt_r=0.0045, mat_key="Chrome", bone_name="UpperArm.L")

# Armored Shoulder Pauldron dome over left deltoid
bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.088, location=P_SH_L + Vector((0.028, -0.005, 0.025)))
pauldron = bpy.context.active_object
pauldron.name = "LeftShoulderPauldron"
pauldron.scale = (1.05, 0.88, 0.72)
pauldron.rotation_euler = (0, math.radians(28), math.radians(-10))
bpy.ops.object.transform_apply(scale=True)
# Keep upper-outer half of sphere
bm = bmesh.new()
bm.from_mesh(pauldron.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().x < -0.01 or f.calc_center_median().z < -0.015], context='FACES')
bm.to_mesh(pauldron.data)
bm.free()
sol = pauldron.modifiers.new("Solidify", 'SOLIDIFY')
sol.thickness = 0.007
bpy.ops.object.modifier_apply(modifier=sol.name)
reg_part(pauldron, "UpperArm.L", "Steel")

# Dual hydraulic humerus struts + central chrome piston (`UpperArm.L`)
make_cyl_between("HumerusMainShaft", P_SH_L.lerp(P_EL_L, 0.48), P_EL_L, 0.034, 0.030, verts=16, mat_key="GunMetal", bone_name="UpperArm.L")
make_cyl_between("HumerusPistonCyl", P_SH_L.lerp(P_EL_L, 0.45) + Vector((0.024, -0.020, 0)), P_EL_L.lerp(P_SH_L, 0.25) + Vector((0.022, -0.022, 0)), 0.016, 0.016, verts=12, mat_key="Steel", bone_name="UpperArm.L")
make_cyl_between("HumerusPistonRod", P_SH_L.lerp(P_EL_L, 0.65) + Vector((0.023, -0.021, 0)), P_EL_L + Vector((0.020, -0.022, 0)), 0.009, 0.009, verts=12, mat_key="Chrome", bone_name="UpperArm.L")

# 2. Rotary Servo Elbow Joint & Armored Forearm (`Forearm.L`)
elbow_axis = Vector((1.0, 0.25, 0.0)).normalized()
make_cyl_between("CyberElbowServo", P_EL_L - elbow_axis * 0.044, P_EL_L + elbow_axis * 0.044, 0.042, 0.042, verts=20, mat_key="Steel", bone_name="Forearm.L")
make_cyl_between("CyberElbowCap", P_EL_L - elbow_axis * 0.048, P_EL_L + elbow_axis * 0.048, 0.024, 0.024, verts=16, mat_key="GunMetal", bone_name="Forearm.L")

# Forearm dual radius/ulna structural rods + armored chassis
fore_dir = (P_WR_L - P_EL_L).normalized()
make_cyl_between("ForearmCore", P_EL_L, P_WR_L, 0.036, 0.028, verts=16, mat_key="GunMetal", bone_name="Forearm.L")
make_cyl_between("ForearmArmorShell", P_EL_L.lerp(P_WR_L, 0.14), P_EL_L.lerp(P_WR_L, 0.84), 0.048, 0.038, verts=10, mat_key="Steel", bone_name="Forearm.L")
make_cyl_between("ForearmPowerSlot", P_EL_L.lerp(P_WR_L, 0.32) + Vector((0.018, -0.015, 0)), P_EL_L.lerp(P_WR_L, 0.68) + Vector((0.016, -0.015, 0)), 0.012, 0.010, verts=12, mat_key="GlowOrange", bone_name="Forearm.L")

# Forearm-Mounted Serrated Industrial Ripper Blade (extends past wrist for lethal melee slashes)
blade_base = P_EL_L.lerp(P_WR_L, 0.28) + Vector((0.036, -0.010, 0.0))
blade_tip  = P_WR_L + fore_dir * 0.22 + Vector((0.032, -0.022, 0.0))
bm = bmesh.new()
b_len = (blade_tip - blade_base).length
# Create sleek double-beveled combat blade mesh along local Z
v_back_bot  = bm.verts.new((-0.004,  0.018, 0.0))
v_back_top  = bm.verts.new((-0.004,  0.014, b_len * 0.82))
v_edge_bot  = bm.verts.new(( 0.000, -0.024, 0.04))
v_edge_mid  = bm.verts.new(( 0.000, -0.028, b_len * 0.72))
v_tip       = bm.verts.new(( 0.000, -0.008, b_len))
v_ridge_bot = bm.verts.new(( 0.005,  0.004, 0.0))
v_ridge_top = bm.verts.new(( 0.004,  0.002, b_len * 0.80))
v_ridge2_b  = bm.verts.new((-0.005,  0.004, 0.0))
v_ridge2_t  = bm.verts.new((-0.004,  0.002, b_len * 0.80))

for f_verts in [
    (v_back_bot, v_ridge_bot, v_ridge_top, v_back_top),
    (v_ridge_bot, v_edge_bot, v_edge_mid, v_ridge_top),
    (v_ridge_top, v_edge_mid, v_tip, v_back_top),
    (v_back_bot, v_back_top, v_ridge2_t, v_ridge2_b),
    (v_ridge2_b, v_ridge2_t, v_edge_mid, v_edge_bot),
    (v_back_top, v_tip, v_edge_mid, v_ridge2_t),
]:
    try:
        bm.faces.new(f_verts)
    except ValueError:
        pass

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
blade_mesh = bpy.data.meshes.new("CyberRipperBlade")
bm.to_mesh(blade_mesh)
bm.free()
blade_obj = bpy.data.objects.new("CyberRipperBlade", blade_mesh)
bpy.context.collection.objects.link(blade_obj)
blade_obj.location = blade_base
blade_obj.rotation_mode = 'QUATERNION'
blade_obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((blade_tip - blade_base).normalized())
blade_obj.rotation_mode = 'XYZ'
reg_part(blade_obj, "Forearm.L", "Chrome")

# 3. Articulated 4-Claw Mechanical Hand (`Hand.L`)
palm_center = P_WR_L + fore_dir * 0.042
make_cyl_between("CyberWristCuff", P_WR_L - fore_dir * 0.015, P_WR_L + fore_dir * 0.020, 0.032, 0.034, verts=16, mat_key="GunMetal", bone_name="Hand.L")
bpy.ops.mesh.primitive_cube_add(size=1.0, location=palm_center)
palm = bpy.context.active_object
palm.name = "CyberPalmBlock"
palm.scale = (0.022, 0.046, 0.048)
palm.rotation_mode = 'QUATERNION'
palm.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(fore_dir)
palm.rotation_mode = 'XYZ'
bpy.ops.object.transform_apply(scale=True)
reg_part(palm, "Hand.L", "Steel")

# 4 Finger Claws + 1 Opposable Thumb Claw
for idx, y_off in enumerate((-0.030, -0.010, 0.010, 0.030)):
    knuckle = palm_center + Vector((0.008, y_off, -0.038))
    mid_j   = knuckle + Vector((-0.010, y_off * 0.15 - 0.018, -0.042))
    tip_j   = mid_j   + Vector((-0.028, -0.012, -0.035))
    make_cyl_between(f"CyberFingerProx_{idx}", knuckle, mid_j, 0.0085, 0.0070, verts=8, mat_key="GunMetal", bone_name="Hand.L")
    make_cyl_between(f"CyberFingerClaw_{idx}", mid_j, tip_j, 0.0070, 0.0012, verts=6, mat_key="Chrome", bone_name="Hand.L")

thumb_k = palm_center + Vector((-0.012, -0.038, -0.012))
thumb_m = thumb_k + Vector((-0.018, -0.026, -0.028))
thumb_t = thumb_m + Vector((0.012, -0.010, -0.026))
make_cyl_between("CyberThumbProx", thumb_k, thumb_m, 0.0095, 0.0075, verts=8, mat_key="GunMetal", bone_name="Hand.L")
make_cyl_between("CyberThumbClaw", thumb_m, thumb_t, 0.0075, 0.0015, verts=6, mat_key="Chrome", bone_name="Hand.L")

# ─── 6D. HYDRAULIC BIONIC LEFT LEG (`Thigh.L`, `Shin.L`, `Foot.L`, `Toes.L`) ──
P_HIP_L  = JOINT_POS["L_leg"]    # (0.1117, -0.0008, 0.9955)
P_KNEE_L = JOINT_POS["L_knee"]   # (0.1796, 0.0347, 0.5949)
P_ANK_L  = JOINT_POS["L_ankle"]  # (0.2448, 0.1598, 0.1461)
P_FOOT_L = JOINT_POS["L_foot"]   # (0.2619, 0.0636, 0.0414)
P_TOE_L  = JOINT_POS["L_toes"]   # (0.2709, -0.0613, 0.0252)

# Thigh amputation collar (`Thigh.L`)
thigh_stump = P_HIP_L.lerp(P_KNEE_L, 0.82)
thigh_dir   = (P_KNEE_L - P_HIP_L).normalized()
make_cyl_between("LeftThighMeatStump", P_HIP_L.lerp(P_KNEE_L, 0.72), P_HIP_L.lerp(P_KNEE_L, 0.88), 0.076, 0.066, verts=20, mat_key="Meat", bone_name="Thigh.L")
make_cyl_between("LeftThighCuff", P_HIP_L.lerp(P_KNEE_L, 0.78), P_KNEE_L, 0.072, 0.056, verts=20, mat_key="GunMetal", bone_name="Thigh.L")
make_bolt_ring("LeftThighBolts", P_HIP_L.lerp(P_KNEE_L, 0.83), thigh_dir, 0.070, count=10, bolt_r=0.005, mat_key="Chrome", bone_name="Thigh.L")

# Rotary Knee Servo & Armored Patella Shield (`Shin.L`)
make_cyl_between("CyberKneeRotor", P_KNEE_L + Vector((-0.052, 0, 0)), P_KNEE_L + Vector((0.052, 0, 0)), 0.052, 0.052, verts=20, mat_key="Steel", bone_name="Shin.L")
bpy.ops.mesh.primitive_cube_add(size=1.0, location=P_KNEE_L + Vector((0.0, -0.052, 0.010)))
patella = bpy.context.active_object
patella.name = "CyberPatellaShield"
patella.scale = (0.046, 0.024, 0.068)
patella.rotation_euler = (math.radians(-14), 0, 0)
bpy.ops.object.transform_apply(scale=True)
reg_part(patella, "Shin.L", "Steel")

# Twin Structural Tibia Struts + Rear Hydraulic Shock Absorber (`Shin.L`)
make_cyl_between("CyberTibiaStrutFront", P_KNEE_L + Vector((0.0, -0.024, -0.02)), P_ANK_L + Vector((0.0, -0.022, 0.02)), 0.026, 0.022, verts=16, mat_key="Steel", bone_name="Shin.L")
make_cyl_between("CyberFibulaStrutOuter", P_KNEE_L + Vector((0.032, 0.015, -0.02)), P_ANK_L + Vector((0.026, 0.010, 0.02)), 0.018, 0.015, verts=14, mat_key="GunMetal", bone_name="Shin.L")
make_cyl_between("CyberCalfShockCyl", P_KNEE_L + Vector((-0.010, 0.038, -0.03)), P_KNEE_L.lerp(P_ANK_L, 0.58) + Vector((-0.008, 0.035, 0)), 0.028, 0.026, verts=16, mat_key="GunMetal", bone_name="Shin.L")
make_cyl_between("CyberCalfShockRod", P_KNEE_L.lerp(P_ANK_L, 0.52) + Vector((-0.008, 0.035, 0)), P_ANK_L + Vector((-0.005, 0.025, 0.02)), 0.015, 0.015, verts=14, mat_key="Chrome", bone_name="Shin.L")
make_cyl_between("CyberShinArmor", P_KNEE_L.lerp(P_ANK_L, 0.18) + Vector((0.0, -0.036, 0)), P_KNEE_L.lerp(P_ANK_L, 0.76) + Vector((0.0, -0.030, 0)), 0.034, 0.024, verts=8, mat_key="Steel", bone_name="Shin.L")

# Mechanical Claw Foot (`Foot.L` & `Toes.L`)
make_cyl_between("CyberAnkleServo", P_ANK_L + Vector((-0.042, 0, 0)), P_ANK_L + Vector((0.042, 0, 0)), 0.036, 0.036, verts=18, mat_key="GunMetal", bone_name="Foot.L")
make_cyl_between("CyberHeelSpur", P_ANK_L, P_ANK_L + Vector((0.0, 0.068, -0.115)), 0.024, 0.016, verts=12, mat_key="Steel", bone_name="Foot.L")
make_cyl_between("CyberFootArch", P_ANK_L, P_FOOT_L, 0.032, 0.028, verts=14, mat_key="Steel", bone_name="Foot.L")

for idx, x_off in enumerate((-0.032, 0.0, 0.032)):
    t_start = P_FOOT_L + Vector((x_off, -0.010, -0.010))
    t_mid   = P_TOE_L  + Vector((x_off * 1.15, -0.015, 0.002))
    t_tip   = t_mid    + Vector((x_off * 0.2, -0.048, -0.018))
    make_cyl_between(f"CyberToeBase_{idx}", t_start, t_mid, 0.014, 0.011, verts=8, mat_key="GunMetal", bone_name="Toes.L")
    make_cyl_between(f"CyberToeTalon_{idx}", t_mid, t_tip, 0.011, 0.003, verts=6, mat_key="Chrome", bone_name="Toes.L")

# ─── 6E. HEAVY POST-APOCALYPTIC COMBAT BOOT ON ORGANIC RIGHT FOOT (`Foot.R`/`Toes.R`) ─
P_ANK_R  = JOINT_POS["R_ankle"]  # (-0.2448, 0.1598, 0.1461)
P_FOOT_R = JOINT_POS["R_foot"]   # (-0.2619, 0.0636, 0.0414)
P_TOE_R  = JOINT_POS["R_toes"]   # (-0.2709, -0.0613, 0.0252)

# Metallic shin & ankle buckle straps + steel toe cap + lugged rubber sole over conforming `boot_shell`
make_cyl_between("RightBootTopCollar", P_ANK_R + Vector((0.015, -0.032, 0.125)), P_ANK_R + Vector((0.012, -0.028, 0.095)), 0.048, 0.044, verts=16, mat_key="GunMetal", bone_name="Shin.R")
make_cyl_between("RightBootAnkleBrace", P_ANK_R + Vector((0.005, -0.015, 0.035)), P_ANK_R + Vector((0.002, -0.010, 0.010)), 0.044, 0.045, verts=16, mat_key="Steel", bone_name="Foot.R")

# Steel toe cap & thick lugged rubber sole
bpy.ops.mesh.primitive_cube_add(size=1.0, location=P_FOOT_R.lerp(P_TOE_R, 0.42) + Vector((0.0, 0.022, -0.014)))
boot_sole = bpy.context.active_object
boot_sole.name = "RightBootSole"
boot_sole.scale = (0.048, 0.128, 0.015)
boot_sole.rotation_euler = (0, 0, math.radians(-6))
bpy.ops.object.transform_apply(scale=True)
reg_part(boot_sole, "Foot.R", "Rubber")

# ─── 7. BUILD CLEAN 23-BONE HUMANOID ARMATURE (`ZombieRig`) ──────────────────
print("Building 23-bone ZombieRig...")
arm_data = bpy.data.armatures.new("ZombieRigData")
rig = bpy.data.objects.new("ZombieRig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones

def add_eb(name, head, tail, parent_name=None, connect=False):
    b = eb.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if (b.tail - b.head).length < 0.01:
        b.tail = b.head + Vector((0, 0, 0.05))
    b.roll = 0.0
    if parent_name and parent_name in eb:
        b.parent = eb[parent_name]
        b.use_connect = connect
    return b

add_eb("Root",       (0.0, 0.0, 0.0),          (0.0, 0.0, 0.22), None, False)
add_eb("Hips",       JOINT_POS["hips"],        JOINT_POS["spine"], "Root", False)
add_eb("Spine",      JOINT_POS["spine"],       JOINT_POS["chest"], "Hips", True)
add_eb("Chest",      JOINT_POS["chest"],       JOINT_POS["neck"],  "Spine", True)
add_eb("Neck",       JOINT_POS["neck"],        JOINT_POS["head"],  "Chest", True)
add_eb("Head",       JOINT_POS["head"],        JOINT_POS["head"] + Vector((0, 0, 0.21)), "Neck", True)
add_eb("Jaw",        JOINT_POS["jaw"],         JOINT_POS["lip"],   "Head", False)

# Left Arm
add_eb("Clavicle.L", JOINT_POS["L_shoulder"],  JOINT_POS["L_arm"],   "Chest", False)
add_eb("UpperArm.L", JOINT_POS["L_arm"],       JOINT_POS["L_elbow"], "Clavicle.L", True)
add_eb("Forearm.L",  JOINT_POS["L_elbow"],     JOINT_POS["L_wrist"], "UpperArm.L", True)
add_eb("Hand.L",     JOINT_POS["L_wrist"],     JOINT_POS["L_wrist"] + (JOINT_POS["L_wrist"] - JOINT_POS["L_elbow"]).normalized() * 0.14, "Forearm.L", True)

# Right Arm
add_eb("Clavicle.R", JOINT_POS["R_shoulder"],  JOINT_POS["R_arm"],   "Chest", False)
add_eb("UpperArm.R", JOINT_POS["R_arm"],       JOINT_POS["R_elbow"], "Clavicle.R", True)
add_eb("Forearm.R",  JOINT_POS["R_elbow"],     JOINT_POS["R_wrist"], "UpperArm.R", True)
add_eb("Hand.R",     JOINT_POS["R_wrist"],     JOINT_POS["R_wrist"] + (JOINT_POS["R_wrist"] - JOINT_POS["R_elbow"]).normalized() * 0.14, "Forearm.R", True)

# Left Leg
add_eb("Thigh.L",    JOINT_POS["L_leg"],       JOINT_POS["L_knee"],  "Hips", False)
add_eb("Shin.L",     JOINT_POS["L_knee"],      JOINT_POS["L_ankle"], "Thigh.L", True)
add_eb("Foot.L",     JOINT_POS["L_ankle"],     JOINT_POS["L_foot"],  "Shin.L", True)
add_eb("Toes.L",     JOINT_POS["L_foot"],      JOINT_POS["L_toes"],  "Foot.L", True)

# Right Leg
add_eb("Thigh.R",    JOINT_POS["R_leg"],       JOINT_POS["R_knee"],  "Hips", False)
add_eb("Shin.R",     JOINT_POS["R_knee"],      JOINT_POS["R_ankle"], "Thigh.R", True)
add_eb("Foot.R",     JOINT_POS["R_ankle"],     JOINT_POS["R_foot"],  "Shin.R", True)
add_eb("Toes.R",     JOINT_POS["R_foot"],      JOINT_POS["R_toes"],  "Foot.R", True)

bpy.ops.object.mode_set(mode='OBJECT')

# ─── 8. REMAP VERTEX GROUPS ON BODY & CLOTHING + SKIN CYBERNETIC PARTS ───────
VG_MAP = {
    "hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
    "jaw": "Jaw", "lip": "Jaw", "L_eye": "Head", "R_eye": "Head",
    "L_shoulder": "Clavicle.L", "L_arm": "UpperArm.L", "L_elbow": "Forearm.L", "L_wrist": "Hand.L",
    "R_shoulder": "Clavicle.R", "R_arm": "UpperArm.R", "R_elbow": "Forearm.R", "R_wrist": "Hand.R",
    "L_leg": "Thigh.L", "L_knee": "Shin.L", "L_ankle": "Foot.L", "L_foot": "Foot.L", "L_toes": "Toes.L",
    "R_leg": "Thigh.R", "R_knee": "Shin.R", "R_ankle": "Foot.R", "R_foot": "Foot.R", "R_toes": "Toes.R",
}
for k in list(orig_body.vertex_groups.keys()):
    if k not in VG_MAP:
        if k.startswith("L_"):
            VG_MAP[k] = "Hand.L"
        elif k.startswith("R_"):
            VG_MAP[k] = "Hand.R"

def remap_mesh_vgroups_to_rig(mesh_obj):
    # Accumulate weights per target bone
    n_verts = len(mesh_obj.data.vertices)
    target_weights = {b.name: [0.0] * n_verts for b in rig.data.bones}

    idx_to_target = {}
    for vg in mesh_obj.vertex_groups:
        t_name = VG_MAP.get(vg.name, vg.name if vg.name in target_weights else None)
        if t_name:
            idx_to_target[vg.index] = t_name

    for v in mesh_obj.data.vertices:
        for g in v.groups:
            t_name = idx_to_target.get(g.group)
            if t_name:
                target_weights[t_name][v.index] += g.weight

    mesh_obj.vertex_groups.clear()
    for b_name, w_list in target_weights.items():
        vg = mesh_obj.vertex_groups.new(name=b_name)
        for vi, w in enumerate(w_list):
            if w > 0.0005:
                vg.add([vi], min(w, 1.0), 'REPLACE')

for soft_obj in (orig_body, shirt_obj, pants_obj, boot_shell):
    remap_mesh_vgroups_to_rig(soft_obj)

# Assign 100% rigid bone weights to every hard-surface cybernetic & boot piece
for part_obj, bone_name in CYBER_PARTS:
    part_obj.vertex_groups.clear()
    vg = part_obj.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(part_obj.data.vertices))), 1.0, 'REPLACE')

# Join all parts into a single clean multi-material mesh ("ZombieCyborgMesh") for optimal glTF/Godot performance
bpy.ops.object.select_all(action='DESELECT')
all_meshes = [orig_body, shirt_obj, pants_obj, boot_shell] + [p for (p, _) in CYBER_PARTS]
for m_obj in all_meshes:
    m_obj.select_set(True)
bpy.context.view_layer.objects.active = orig_body
bpy.ops.object.join()

main_mesh = bpy.context.active_object
main_mesh.name = "ZombieCyborgMesh"
main_mesh.parent = rig
arm_mod = main_mesh.modifiers.new("Armature", 'ARMATURE')
arm_mod.object = rig

# ─── 9. CREATE ALL 7 REALISTIC SKELETAL ANIMATIONS ON `ZombieRig` ────────────
print("Creating 7 skeletal animations (Idle, Walk, Run, Attack, Hit, Death, Roar)...")
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'

# World-space rotation helper so we can specify intuitive anatomical angles:
# rx > 0: pitch forward (bow torso / raise leg forward / raise arm forward)
# rx < 0: pitch backward (arch torso back / swing leg back)
# ry > 0: roll right / tilt head right
# rz > 0: yaw twist left
BONE_REST_MAT = {}
for pb in rig.pose.bones:
    BONE_REST_MAT[pb.name] = (rig.matrix_world @ pb.bone.matrix_local).to_3x3()

def set_bone_world_pose(pb_name, rx=0.0, ry=0.0, rz=0.0, loc=None):
    pb = rig.pose.bones[pb_name]
    R_w = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_matrix().to_3x3()
    R_b = BONE_REST_MAT[pb_name]
    M_local = (R_b.inverted() @ R_w @ R_b)
    pb.rotation_euler = M_local.to_euler('XYZ')
    if loc is not None:
        # Convert world delta loc to bone local space
        pb.location = R_b.inverted() @ Vector(loc)
    else:
        pb.location = (0.0, 0.0, 0.0)

def key_all_bones(frame):
    scene.frame_set(frame)
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        pb.keyframe_insert(data_path="location", frame=frame)

def reset_pose():
    for pb in rig.pose.bones:
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)

def finalize_action(act):
    act.use_fake_user = True
    # Smooth Bezier interpolation if fcurves accessible
    if hasattr(act, "fcurves"):
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'BEZIER'
    # Push down to NLA track so glTF 2.0 exporter exports all 7 actions reliably
    if not rig.animation_data:
        rig.animation_data_create()
    track = rig.animation_data.nla_tracks.new()
    track.name = act.name
    strip = track.strips.new(act.name, int(act.frame_range[0]), act)
    strip.name = act.name
    track.mute = True

# 9.1 IDLE (Frames 1..72, looping heavy breathing, optic scan, cyber-claw twitch)
act_idle = bpy.data.actions.new("Idle")
rig.animation_data_create()
rig.animation_data.action = act_idle
for f, ph in [(1, 0.0), (19, 0.5 * math.pi), (37, math.pi), (55, 1.5 * math.pi), (72, 2.0 * math.pi)]:
    reset_pose()
    s1 = math.sin(ph)
    c1 = math.cos(ph)
    set_bone_world_pose("Hips", rx=4 + 1.5 * s1, ry=2.5 * c1, rz=2.0 * s1, loc=(0.012 * c1, 0, -0.015 + 0.010 * s1))
    set_bone_world_pose("Spine", rx=8 + 2.5 * s1, ry=-2.0 * c1, rz=-2.0 * s1)
    set_bone_world_pose("Chest", rx=6 + 3.5 * s1, ry=1.5 * s1, rz=3.0 * c1)
    set_bone_world_pose("Neck", rx=-5 + 2.0 * c1, ry=4.0 * s1, rz=-5.0 * s1)
    set_bone_world_pose("Head", rx=-4 - 3.0 * s1, ry=-6.0 * c1, rz=8.0 * s1)
    set_bone_world_pose("Jaw", rx=-6 - 5.0 * max(0, s1))
    # Heavy cybernetic left arm hangs forward & twitches
    set_bone_world_pose("UpperArm.L", rx=12 + 4 * s1, ry=4, rz=-6)
    set_bone_world_pose("Forearm.L", rx=24 + 6 * c1, ry=0, rz=-10)
    set_bone_world_pose("Hand.L", rx=8 * s1, ry=12 * c1, rz=0)
    # Organic right arm
    set_bone_world_pose("UpperArm.R", rx=8 - 3 * s1, ry=-4, rz=6)
    set_bone_world_pose("Forearm.R", rx=18 - 4 * c1, ry=0, rz=8)
    # Asymmetric leg stance
    set_bone_world_pose("Thigh.L", rx=8 - 1.5 * s1, ry=0, rz=0)
    set_bone_world_pose("Shin.L", rx=-14 + 2.5 * s1, ry=0, rz=0)
    set_bone_world_pose("Foot.L", rx=6 - 1.0 * s1)
    set_bone_world_pose("Thigh.R", rx=5 + 1.5 * s1, ry=0, rz=0)
    set_bone_world_pose("Shin.R", rx=-10 - 2.5 * s1, ry=0, rz=0)
    set_bone_world_pose("Foot.R", rx=5 + 1.0 * s1)
    key_all_bones(f)
finalize_action(act_idle)

# 9.2 WALK (Frames 1..36, heavy asymmetric cyborg shamble / limp)
act_walk = bpy.data.actions.new("Walk")
rig.animation_data.action = act_walk
walk_keys = [
    # (frame, L_thigh, L_shin, L_foot, R_thigh, R_shin, R_foot, hip_z, hip_roll, spine_rx, chest_rz, armL_rx, armR_rx)
    (1,   26, -12,  8,  -20, -18, -10, -0.025,  4.5, 14, -9, -16,  24),
    (10,   4, -16,  0,    6, -42, -16, -0.055,  2.0, 17, -3,   2,   6),
    (19, -22, -22, -12,  30, -10,  10, -0.020, -4.5, 13,  9,  24, -18),
    (28,   8, -46, -18,   4, -16,   0, -0.045, -2.0, 16,  4,   4,   4),
    (36,  26, -12,  8,  -20, -18, -10, -0.025,  4.5, 14, -9, -16,  24),
]
for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in walk_keys:
    reset_pose()
    set_bone_world_pose("Hips", rx=8, ry=hroll, rz=-crz * 0.6, loc=(hroll * 0.004, 0, hz))
    set_bone_world_pose("Spine", rx=srx, ry=-hroll * 0.6, rz=crz * 0.5)
    set_bone_world_pose("Chest", rx=10, ry=-hroll * 0.4, rz=crz)
    set_bone_world_pose("Neck", rx=-8, ry=hroll * 0.8, rz=-crz * 0.5)
    set_bone_world_pose("Head", rx=-6, ry=-hroll * 1.2, rz=-crz * 0.4)
    set_bone_world_pose("Jaw", rx=-10 if f in (10, 28) else -5)
    set_bone_world_pose("UpperArm.L", rx=14 + al, ry=6, rz=-8)
    set_bone_world_pose("Forearm.L", rx=28 + max(0, al * 0.6), ry=0, rz=-10)
    set_bone_world_pose("UpperArm.R", rx=12 + ar, ry=-6, rz=8)
    set_bone_world_pose("Forearm.R", rx=22 + max(0, ar * 0.6), ry=0, rz=8)
    set_bone_world_pose("Thigh.L", rx=lt, ry=0, rz=0)
    set_bone_world_pose("Shin.L", rx=ls, ry=0, rz=0)
    set_bone_world_pose("Foot.L", rx=lf, ry=0, rz=0)
    set_bone_world_pose("Thigh.R", rx=rt, ry=0, rz=0)
    set_bone_world_pose("Shin.R", rx=rs, ry=0, rz=0)
    set_bone_world_pose("Foot.R", rx=rf, ry=0, rz=0)
    key_all_bones(f)
finalize_action(act_walk)

# 9.3 RUN (Frames 1..20, aggressive mechanical sprint / servo overdrive charge)
act_run = bpy.data.actions.new("Run")
rig.animation_data.action = act_run
run_keys = [
    (1,   42, -18, 12,  -34, -28, -16, -0.04,  5.0, 22, -14, -28,  38),
    (6,    6, -24,  0,   12, -62, -22,  0.02,  1.5, 25,  -4,   4,   8),
    (11, -34, -30, -16,  44, -16,  14, -0.04, -5.0, 22,  14,  38, -28),
    (16,  14, -64, -22,   6, -24,   0,  0.02, -1.5, 25,   4,   8,   4),
    (20,  42, -18, 12,  -34, -28, -16, -0.04,  5.0, 22, -14, -28,  38),
]
for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in run_keys:
    reset_pose()
    set_bone_world_pose("Hips", rx=14, ry=hroll, rz=-crz * 0.5, loc=(0, 0, hz))
    set_bone_world_pose("Spine", rx=srx, ry=-hroll * 0.5, rz=crz * 0.5)
    set_bone_world_pose("Chest", rx=14, ry=0, rz=crz)
    set_bone_world_pose("Neck", rx=-14, ry=0, rz=-crz * 0.5)
    set_bone_world_pose("Head", rx=-12, ry=hroll, rz=-crz * 0.4)
    set_bone_world_pose("Jaw", rx=-16)
    set_bone_world_pose("UpperArm.L", rx=24 + al, ry=8, rz=-10)
    set_bone_world_pose("Forearm.L", rx=42 + max(0, al * 0.5), ry=0, rz=-12)
    set_bone_world_pose("UpperArm.R", rx=22 + ar, ry=-8, rz=10)
    set_bone_world_pose("Forearm.R", rx=38 + max(0, ar * 0.5), ry=0, rz=12)
    set_bone_world_pose("Thigh.L", rx=lt)
    set_bone_world_pose("Shin.L", rx=ls)
    set_bone_world_pose("Foot.L", rx=lf)
    set_bone_world_pose("Thigh.R", rx=rt)
    set_bone_world_pose("Shin.R", rx=rs)
    set_bone_world_pose("Foot.R", rx=rf)
    key_all_bones(f)
finalize_action(act_run)

# 9.4 ATTACK (Frames 1..28, wind-up + lethal cyber-blade slash + right claw follow-through)
act_atk = bpy.data.actions.new("Attack")
rig.animation_data.action = act_atk
# Frame 1: Base ready
reset_pose()
key_all_bones(1)
# Frame 8: Wind-up (twist torso left, raise cyber-blade high, open mandible jaw)
reset_pose()
set_bone_world_pose("Hips", rx=4, rz=-18, loc=(0, 0.03, -0.02))
set_bone_world_pose("Spine", rx=-6, rz=-22)
set_bone_world_pose("Chest", rx=-8, rz=-28)
set_bone_world_pose("Head", rx=-10, rz=24)
set_bone_world_pose("Jaw", rx=-26)
set_bone_world_pose("UpperArm.L", rx=85, ry=28, rz=-35)
set_bone_world_pose("Forearm.L", rx=55, ry=0, rz=-20)
set_bone_world_pose("UpperArm.R", rx=-18, ry=-15, rz=15)
set_bone_world_pose("Thigh.L", rx=18)
set_bone_world_pose("Shin.L", rx=-24)
key_all_bones(8)
# Frame 14: Lethal Downward/Cross Slash with Left Cyber-Blade!
reset_pose()
set_bone_world_pose("Hips", rx=16, rz=22, loc=(0, -0.06, -0.04))
set_bone_world_pose("Spine", rx=22, rz=26)
set_bone_world_pose("Chest", rx=24, rz=32)
set_bone_world_pose("Head", rx=-14, rz=-24)
set_bone_world_pose("Jaw", rx=-30)
set_bone_world_pose("UpperArm.L", rx=28, ry=-24, rz=38)
set_bone_world_pose("Forearm.L", rx=12, ry=0, rz=22)
set_bone_world_pose("Hand.L", rx=-18, ry=0, rz=0)
set_bone_world_pose("UpperArm.R", rx=65, ry=-20, rz=25)
set_bone_world_pose("Forearm.R", rx=45)
set_bone_world_pose("Thigh.L", rx=28)
set_bone_world_pose("Shin.L", rx=-32)
set_bone_world_pose("Thigh.R", rx=-14)
set_bone_world_pose("Shin.R", rx=-18)
key_all_bones(14)
# Frame 20: Secondary Right ClawSwipe
reset_pose()
set_bone_world_pose("Hips", rx=14, rz=-16, loc=(0, -0.04, -0.03))
set_bone_world_pose("Spine", rx=18, rz=-20)
set_bone_world_pose("Chest", rx=20, rz=-26)
set_bone_world_pose("Head", rx=-10, rz=18)
set_bone_world_pose("Jaw", rx=-18)
set_bone_world_pose("UpperArm.L", rx=-12, ry=14, rz=-15)
set_bone_world_pose("Forearm.L", rx=30)
set_bone_world_pose("UpperArm.R", rx=36, ry=18, rz=-32)
set_bone_world_pose("Forearm.R", rx=16)
key_all_bones(20)
# Frame 28: Return to stance
reset_pose()
key_all_bones(28)
finalize_action(act_atk)

# 9.5 HIT (Frames 1..18, heavy impact stagger & spark flinch)
act_hit = bpy.data.actions.new("Hit")
rig.animation_data.action = act_hit
reset_pose()
key_all_bones(1)
# Frame 5: Violent snap backward
reset_pose()
set_bone_world_pose("Hips", rx=-12, ry=-6, rz=14, loc=(0.03, 0.06, -0.03))
set_bone_world_pose("Spine", rx=-18, ry=-8, rz=18)
set_bone_world_pose("Chest", rx=-22, ry=-10, rz=24)
set_bone_world_pose("Neck", rx=-20, ry=12, rz=15)
set_bone_world_pose("Head", rx=-28, ry=18, rz=22)
set_bone_world_pose("Jaw", rx=-28)
set_bone_world_pose("UpperArm.L", rx=-24, ry=28, rz=-20)
set_bone_world_pose("Forearm.L", rx=48)
set_bone_world_pose("UpperArm.R", rx=-20, ry=-26, rz=20)
set_bone_world_pose("Forearm.R", rx=42)
set_bone_world_pose("Thigh.L", rx=16)
set_bone_world_pose("Shin.L", rx=-28)
key_all_bones(5)
# Frame 11: Catch balance forward
reset_pose()
set_bone_world_pose("Hips", rx=10, ry=4, rz=-8, loc=(0.01, 0.02, -0.02))
set_bone_world_pose("Spine", rx=14, rz=-6)
set_bone_world_pose("Chest", rx=12, rz=-8)
set_bone_world_pose("Head", rx=10, rz=-6)
set_bone_world_pose("UpperArm.L", rx=22)
set_bone_world_pose("UpperArm.R", rx=18)
key_all_bones(11)
reset_pose()
key_all_bones(18)
finalize_action(act_hit)

# 9.6 DEATH (Frames 1..42, cyber-core short-circuit convulsion, knees buckle, collapse to ground)
act_death = bpy.data.actions.new("Death")
rig.animation_data.action = act_death
reset_pose()
key_all_bones(1)
# Frame 8: System overload shock (arch back, jaw wide)
reset_pose()
set_bone_world_pose("Hips", rx=-10, rz=10, loc=(0, 0.03, -0.04))
set_bone_world_pose("Spine", rx=-16, rz=12)
set_bone_world_pose("Chest", rx=-22, rz=16)
set_bone_world_pose("Head", rx=-32, ry=16, rz=18)
set_bone_world_pose("Jaw", rx=-34)
set_bone_world_pose("UpperArm.L", rx=45, ry=35, rz=-25)
set_bone_world_pose("Forearm.L", rx=50)
set_bone_world_pose("UpperArm.R", rx=40, ry=-35, rz=25)
set_bone_world_pose("Forearm.R", rx=45)
set_bone_world_pose("Thigh.L", rx=22)
set_bone_world_pose("Shin.L", rx=-40)
set_bone_world_pose("Thigh.R", rx=18)
set_bone_world_pose("Shin.R", rx=-36)
key_all_bones(8)
# Frame 20: Drop onto knees
reset_pose()
set_bone_world_pose("Hips", rx=28, ry=8, rz=-12, loc=(0.02, -0.05, -0.44))
set_bone_world_pose("Spine", rx=24, rz=-10)
set_bone_world_pose("Chest", rx=28, rz=-12)
set_bone_world_pose("Head", rx=24, ry=-12)
set_bone_world_pose("Jaw", rx=-20)
set_bone_world_pose("UpperArm.L", rx=38, ry=12)
set_bone_world_pose("Forearm.L", rx=32)
set_bone_world_pose("UpperArm.R", rx=34, ry=-12)
set_bone_world_pose("Forearm.R", rx=28)
set_bone_world_pose("Thigh.L", rx=52)
set_bone_world_pose("Shin.L", rx=-115)
set_bone_world_pose("Foot.L", rx=45)
set_bone_world_pose("Thigh.R", rx=48)
set_bone_world_pose("Shin.R", rx=-110)
set_bone_world_pose("Foot.R", rx=45)
key_all_bones(20)
# Frame 34..42: Collapse flat onto chest/side on the ground
for f_end in (34, 42):
    reset_pose()
    set_bone_world_pose("Hips", rx=84, ry=18, rz=-14, loc=(0.05, -0.38, -0.86))
    set_bone_world_pose("Spine", rx=10, ry=-8, rz=6)
    set_bone_world_pose("Chest", rx=6, ry=-6, rz=8)
    set_bone_world_pose("Neck", rx=-18, ry=15, rz=22)
    set_bone_world_pose("Head", rx=-22, ry=28, rz=32)
    set_bone_world_pose("Jaw", rx=-24)
    set_bone_world_pose("UpperArm.L", rx=55, ry=42, rz=-20)
    set_bone_world_pose("Forearm.L", rx=38)
    set_bone_world_pose("UpperArm.R", rx=25, ry=-38, rz=15)
    set_bone_world_pose("Forearm.R", rx=45)
    set_bone_world_pose("Thigh.L", rx=-12, ry=10)
    set_bone_world_pose("Shin.L", rx=-28)
    set_bone_world_pose("Thigh.R", rx=8, ry=-12)
    set_bone_world_pose("Shin.R", rx=-42)
    key_all_bones(f_end)
finalize_action(act_death)

# 9.7 ROAR (Frames 1..40, menacing cybernetic battle cry, chest thrust, jaw wide, claws spread)
act_roar = bpy.data.actions.new("Roar")
rig.animation_data.action = act_roar
reset_pose()
key_all_bones(1)
# Frame 8: Crouch intake
reset_pose()
set_bone_world_pose("Hips", rx=14, loc=(0, 0, -0.06))
set_bone_world_pose("Spine", rx=18)
set_bone_world_pose("Chest", rx=20)
set_bone_world_pose("Head", rx=16)
set_bone_world_pose("UpperArm.L", rx=28, ry=-15, rz=20)
set_bone_world_pose("Forearm.L", rx=55)
set_bone_world_pose("UpperArm.R", rx=28, ry=15, rz=-20)
set_bone_world_pose("Forearm.R", rx=55)
set_bone_world_pose("Thigh.L", rx=22)
set_bone_world_pose("Shin.L", rx=-32)
set_bone_world_pose("Thigh.R", rx=22)
set_bone_world_pose("Shin.R", rx=-32)
key_all_bones(8)
# Frame 18 & 28: Full terrifying Roar (chest thrust forward, head thrown back, mandible wide open)
for f_r, h_shake in ((18, -14), (23, 14), (28, -10)):
    reset_pose()
    set_bone_world_pose("Hips", rx=-8, loc=(0, -0.03, 0.01))
    set_bone_world_pose("Spine", rx=-14)
    set_bone_world_pose("Chest", rx=-18, rz=h_shake * 0.3)
    set_bone_world_pose("Neck", rx=-16, rz=h_shake * 0.5)
    set_bone_world_pose("Head", rx=-24, ry=h_shake * 0.4, rz=h_shake)
    set_bone_world_pose("Jaw", rx=-38)
    set_bone_world_pose("UpperArm.L", rx=-18, ry=38, rz=-32)
    set_bone_world_pose("Forearm.L", rx=25)
    set_bone_world_pose("UpperArm.R", rx=-18, ry=-38, rz=32)
    set_bone_world_pose("Forearm.R", rx=25)
    set_bone_world_pose("Thigh.L", rx=8)
    set_bone_world_pose("Shin.L", rx=-12)
    set_bone_world_pose("Thigh.R", rx=8)
    set_bone_world_pose("Shin.R", rx=-12)
    key_all_bones(f_r)
reset_pose()
key_all_bones(40)
finalize_action(act_roar)

# Leave character in frame 1 of Idle for preview & default load
for tr in rig.animation_data.nla_tracks:
    tr.mute = False
rig.animation_data.action = act_idle
scene.frame_set(1)

# ─── 10. SAVE `.BLEND`, `.GLB`, `.FBX` & COPY TO GODOT PROJECT ───────────────
print("Exporting .blend, .glb, and .fbx...")
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

bpy.ops.export_scene.gltf(
    filepath=GLB_PATH,
    export_format='GLB',
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_nla_strips=True,
    export_apply=False,
    export_yup=True
)
shutil.copy2(GLB_PATH, GAME_GLB)

bpy.ops.export_scene.fbx(
    filepath=FBX_PATH,
    use_selection=False,
    bake_anim=True,
    bake_anim_use_all_actions=True,
    bake_anim_use_nla_strips=True,
    add_leaf_bones=False,
    path_mode='COPY',
    embed_textures=True
)

# ─── 11. STUDIO LIGHTING & CYCLES PREVIEW RENDERS ────────────────────────────
print("Rendering Cycles studio previews...")
scene.render.engine = 'CYCLES'
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'CUDA'
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scene.cycles.device = 'GPU'
except Exception:
    pass
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 900
scene.render.resolution_y = 1100

world = bpy.data.worlds.new("StudioWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.04, 0.045, 0.055, 1.0)
    bg.inputs["Strength"].default_value = 0.7

def add_light(name, ltype, loc, rot_deg, energy, color=(1.0, 1.0, 1.0), size=1.5):
    ld = bpy.data.lights.new(name, type=ltype)
    ld.energy = energy
    ld.color = color
    if hasattr(ld, "size"):
        ld.size = size
    lo = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    return lo

add_light("KeyLight",  'AREA', (-1.8, -2.4, 2.5), (55, 0, -35), 260.0, (1.0, 0.96, 0.90), size=2.0)
add_light("FillLight", 'AREA', ( 2.2, -1.8, 1.6), (65, 0,  45), 140.0, (0.75, 0.85, 1.0), size=2.2)
add_light("RimLight",  'AREA', ( 0.0,  2.4, 2.3), (-55, 0,  0), 220.0, (1.0, 0.35, 0.25), size=1.8)

cam_data = bpy.data.cameras.new("PreviewCam")
cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
bpy.context.collection.objects.link(cam_obj)
scene.camera = cam_obj

def aim_camera(cam, eye, target, lens=55):
    cam.data.lens = lens
    cam.location = Vector(eye)
    direction = (Vector(target) - Vector(eye)).normalized()
    cam.rotation_mode = 'QUATERNION'
    cam.rotation_quaternion = direction.to_track_quat('-Z', 'Y')
    cam.rotation_mode = 'XYZ'

# 1. Front 3/4 Full Body Preview (pose in menacing Attack frame 11 for dynamic preview or Idle frame 1)
rig.animation_data.action = act_idle
scene.frame_set(1)
aim_camera(cam_obj, (0.55, -2.55, 1.15), (0.02, 0.0, 0.98), lens=50)
scene.render.filepath = os.path.join(OUT_DIR, "preview_front.png")
bpy.ops.render.render(write_still=True)

# 2. Close-up Face & Upper Torso Preview
scene.render.resolution_x = 900
scene.render.resolution_y = 900
aim_camera(cam_obj, (0.22, -1.05, 1.66), (0.0, -0.04, 1.60), lens=65)
scene.render.filepath = os.path.join(OUT_DIR, "preview_face.png")
bpy.ops.render.render(write_still=True)

# 3. Back Exo-Spine & Cybernetics Preview
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
aim_camera(cam_obj, (-0.50, 2.45, 1.18), (0.0, 0.0, 1.02), lens=50)
scene.render.filepath = os.path.join(OUT_DIR, "preview_back.png")
bpy.ops.render.render(write_still=True)

print("ALL DONE! Realistic Zombie Cyborg built, animated, exported, and rendered.")
