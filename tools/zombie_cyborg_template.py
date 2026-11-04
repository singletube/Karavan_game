# -*- coding: utf-8 -*-
"""
Universal Modular Zombie-Cyborg Template Builder & Customizer
=============================================================
Creates:
1. `C:/Users/user/ZombieCyborg/zombie_cyborg_template.blend`
   - Organized into clean Blender Collections (`01_Rig`, `02_OrganicBody`, `03_Clothing`,
     `04_HeadImplants`, `05_TorsoBackImplants`, `06_CyberArms`, `07_CyberLegsBoots`)
   - Every body zone, garment, implant, cyber-limb, and weapon is a separate named mesh
     weighted to the shared 23-bone `ZombieRig` with 7 animations (`Idle`, `Walk`, `Run`,
     `Attack`, `Hit`, `Death`, `Roar`).
2. `C:/Users/user/ZombieCyborg/zombie_cyborg_template.glb` &
   `models/zombies/zombie_cyborg_template.glb`
   - Modular multi-mesh glTF 2.0 template ready for instant runtime customization in Godot 4
     (toggle any `Slot_*` or `Body_*` node and tint any material slot on the fly).
3. `C:/Users/user/ZombieCyborg/template_variants_preview.png`
   - Studio Cycles lineup render showing 4 distinct customized Zombie-Cyborgs built from
     this single template (Stalker Ripper, Heavy Siege Brute, Toxic Bio-Spitter, Dual-Blade Runner).

Can also be run with `--preset <name>` or `--config <path.json> --out <file.glb>` to bake
a specific single-mesh variant directly from CLI.
"""

import bpy
import bmesh
import math
import json
import sys
import os
import shutil
from mathutils import Vector, Matrix, Euler

# ─── PATHS ────────────────────────────────────────────────────────────────────
PROJECT_DIR = r"c:\Users\user\Documents\идет-караван-из-ирана"
TEX_DIR     = os.path.join(PROJECT_DIR, "models", "zombies", "textures")
ZOMBIE_FBX  = r"C:\Users\user\.gemini\antigravity\brain\648db63a-c814-40a9-817a-7195fe9a5e11\scratch\zombie1_unzip\source\zombie1.fbx"

OUT_DIR          = r"C:\Users\user\ZombieCyborg"
os.makedirs(OUT_DIR, exist_ok=True)
TEMPLATE_BLEND   = os.path.join(OUT_DIR, "zombie_cyborg_template.blend")
TEMPLATE_GLB     = os.path.join(OUT_DIR, "zombie_cyborg_template.glb")
GAME_TMPL_GLB    = os.path.join(PROJECT_DIR, "models", "zombies", "zombie_cyborg_template.glb")
PREVIEW_VARIANTS = os.path.join(OUT_DIR, "template_variants_preview.png")

# ─── BUILT-IN PRESET DEFINITIONS (Examples of JSON / Dict Configurations) ────
PRESETS = {
    "default_walker": {
        "description": "Стандартный зомби-киборг (левая кибер-рука с клинком, левая кибер-нога, грудной реактор)",
        "organic_limbs": {"arm_l": False, "arm_r": True, "leg_l": False, "leg_r": True},
        "slots": [
            "Slot_Head_CranialPlate_L", "Slot_Jaw_Respirator",
            "Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
            "Slot_Pauldron_L", "Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
            "Slot_LegL_CyberStrut", "Slot_Boot_R",
            "Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Asym"
        ],
        "colors": {
            "skin_tint": (1.0, 1.0, 1.0),
            "glow_color": (1.0, 0.06, 0.01),
            "armor_tint": (0.78, 0.80, 0.84),
            "shirt_tint": (0.22, 0.25, 0.18),
            "pants_tint": (0.18, 0.24, 0.34),
        }
    },
    "heavy_siege_brute": {
        "description": "Тяжёлый штурмовой киборг-танк (двойные наплечники, бронепластины торса, правый молот-крушитель, оранжевое свечение)",
        "organic_limbs": {"arm_l": False, "arm_r": False, "leg_l": False, "leg_r": False},
        "slots": [
            "Slot_Head_CranialPlate_L", "Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
            "Slot_Torso_HeavyArmor", "Slot_Back_ExoSpine",
            "Slot_Pauldron_L", "Slot_Pauldron_R",
            "Slot_ArmL_CyberClaw", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Crusher",
            "Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
            "Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
        ],
        "colors": {
            "skin_tint": (0.75, 0.72, 0.70),
            "glow_color": (1.0, 0.38, 0.02),
            "armor_tint": (0.45, 0.42, 0.38),
            "shirt_tint": (0.15, 0.15, 0.15),
            "pants_tint": (0.22, 0.18, 0.14),
        }
    },
    "toxic_bio_spitter": {
        "description": "Токсичный био-плеватель (кислотный распылитель в челюсти, хим-баллоны на спине, правая плазма-пушка, кислотно-зелёное свечение)",
        "organic_limbs": {"arm_l": True, "arm_r": False, "leg_l": True, "leg_r": False},
        "slots": [
            "Slot_Head_CranialPlate_R", "Slot_Jaw_AcidSpitter",
            "Slot_Torso_ChestCore_R", "Slot_Back_ChemTanks",
            "Slot_Pauldron_R", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Cannon",
            "Slot_LegR_CyberStrut", "Slot_Boot_L",
            "Slot_Cloth_RagsHood", "Slot_Cloth_CargoPants_Asym"
        ],
        "colors": {
            "skin_tint": (0.72, 0.92, 0.68),
            "glow_color": (0.12, 1.0, 0.08),
            "armor_tint": (0.35, 0.48, 0.36),
            "shirt_tint": (0.28, 0.32, 0.16),
            "pants_tint": (0.16, 0.22, 0.18),
        }
    },
    "dual_blade_stalker": {
        "description": "Скоростной киборг-потрошитель (оба протеза рук с двойными клинками, визор-сканер, синее плазменное свечение)",
        "organic_limbs": {"arm_l": False, "arm_r": False, "leg_l": False, "leg_r": False},
        "slots": [
            "Slot_Head_Visor_Full", "Slot_Head_SirenHorns",
            "Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
            "Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
            "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Blade",
            "Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
            "Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
        ],
        "colors": {
            "skin_tint": (0.82, 0.86, 0.96),
            "glow_color": (0.05, 0.62, 1.0),
            "armor_tint": (0.22, 0.26, 0.34),
            "shirt_tint": (0.12, 0.14, 0.20),
            "pants_tint": (0.10, 0.12, 0.18),
        }
    }
}

# ─── 1. SCENE RESET & COLLECTION SETUP ────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.render.fps = 24

COLLECTIONS = {}
for cname in (
    "01_Rig",
    "02_OrganicBody",
    "03_Clothing",
    "04_HeadImplants",
    "05_TorsoBackImplants",
    "06_CyberArms",
    "07_CyberLegsBoots",
):
    col = bpy.data.collections.new(cname)
    scene.collection.children.link(col)
    COLLECTIONS[cname] = col

def move_to_col(obj, col_name):
    target_col = COLLECTIONS[col_name]
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    target_col.objects.link(obj)

# ─── 2. PBR MATERIALS ────────────────────────────────────────────────────────
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
                 emission_color=None, emission_strength=0.0, normal_strength=1.0):
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

    if albedo_tex:
        img = load_image_cached(albedo_tex, non_color=False)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-280, 220)
            tex.image = img
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    if rough_tex:
        img = load_image_cached(rough_tex, non_color=True)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-280, -40)
            tex.image = img
            links.new(tex.outputs["Color"], bsdf.inputs["Roughness"])

    if normal_tex:
        img = load_image_cached(normal_tex, non_color=True)
        if img:
            tex = nodes.new("ShaderNodeTexImage")
            tex.location = (-320, -320)
            tex.image = img
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
        "Mat_Skin", base_color=(0.45, 0.48, 0.42, 1.0), metallic=0.0, roughness=0.62,
        albedo_tex="zombie_skin_albedo.png", normal_tex="zombie_skin_normal.png",
        rough_tex="zombie_skin_roughness.png", normal_strength=1.35
    ),
    "Meat": make_pbr_mat(
        "Mat_SurgicalMeat", base_color=(0.32, 0.03, 0.03, 1.0), metallic=0.0, roughness=0.22,
        albedo_tex="zombie_meat_albedo.png", normal_tex="mummy_flesh_normal.png", normal_strength=1.5
    ),
    "Steel": make_pbr_mat(
        "Mat_CyberSteel", base_color=(0.56, 0.58, 0.62, 1.0), metallic=0.88, roughness=0.36,
        albedo_tex="cyber_steel.png", normal_tex="cyber_armor_normal.png",
        rough_tex="cyber_armor_roughness.png", normal_strength=1.1
    ),
    "GunMetal": make_pbr_mat(
        "Mat_GunMetal", base_color=(0.16, 0.17, 0.20, 1.0), metallic=0.92, roughness=0.30,
        albedo_tex="cyber_gunmetal.png", normal_tex="cyber_armor_normal.png",
        rough_tex="cyber_armor_roughness.png", normal_strength=1.0
    ),
    "Chrome": make_pbr_mat(
        "Mat_ChromeBlade", base_color=(0.82, 0.85, 0.88, 1.0), metallic=0.98, roughness=0.12
    ),
    "Rubber": make_pbr_mat(
        "Mat_RubberHose", base_color=(0.04, 0.04, 0.05, 1.0), metallic=0.15, roughness=0.72,
        albedo_tex="cyber_gunmetal.png", normal_tex="cyber_armor_normal.png", normal_strength=0.9
    ),
    "Pants": make_pbr_mat(
        "Mat_PantsCloth", base_color=(0.08, 0.11, 0.15, 1.0), metallic=0.0, roughness=0.88,
        albedo_tex="zombie_pants_albedo.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=1.2
    ),
    "Shirt": make_pbr_mat(
        "Mat_ShirtCloth", base_color=(0.10, 0.11, 0.09, 1.0), metallic=0.0, roughness=0.90,
        albedo_tex="zombie_shirt_albedo.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=1.2
    ),
    "Leather": make_pbr_mat(
        "Mat_DarkLeather", base_color=(0.06, 0.05, 0.04, 1.0), metallic=0.15, roughness=0.52,
        albedo_tex="cyber_gunmetal.png", normal_tex="desert_rags_normal.png",
        rough_tex="desert_rags_roughness.png", normal_strength=0.9
    ),
    "Bone": make_pbr_mat(
        "Mat_BoneRibs", base_color=(0.74, 0.68, 0.54, 1.0), metallic=0.0, roughness=0.46
    ),
    "EyeDead": make_pbr_mat(
        "Mat_EyeDead", base_color=(0.68, 0.72, 0.66, 1.0), metallic=0.0, roughness=0.10
    ),
    "GlowPrimary": make_pbr_mat(
        "Mat_GlowPrimary", base_color=(1.0, 0.08, 0.02, 1.0), metallic=0.1, roughness=0.15,
        albedo_tex="optic_lens.png", emission_color=(1.0, 0.06, 0.01), emission_strength=14.0
    ),
    "GlowSecondary": make_pbr_mat(
        "Mat_GlowSecondary", base_color=(1.0, 0.32, 0.02, 1.0), metallic=0.0, roughness=0.2,
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

# ─── 3. IMPORT & PREPARE ANATOMICAL BASE + BUILD 23-BONE `ZombieRig` ─────────
print("Importing anatomical base mesh...")
bpy.ops.import_scene.fbx(filepath=ZOMBIE_FBX)

orig_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
orig_body = next(o for o in bpy.data.objects if o.type == 'MESH')
for o in list(bpy.data.objects):
    if o not in (orig_arm, orig_body):
        bpy.data.objects.remove(o, do_unlink=True)

orig_arm.animation_data_clear()
for pb in orig_arm.pose.bones:
    pb.matrix_basis.identity()
    for c in list(pb.constraints):
        pb.constraints.remove(c)

orig_arm.location = Vector((0.0, 0.118, 0.017))
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
orig_arm.select_set(True)
orig_body.select_set(True)
bpy.context.view_layer.objects.active = orig_arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

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

JOINT_POS = {}
for pb in orig_arm.pose.bones:
    JOINT_POS[pb.name] = (orig_arm.matrix_world @ pb.head).copy()
    JOINT_POS[pb.name + "_tail"] = (orig_arm.matrix_world @ pb.tail).copy()

bpy.ops.object.select_all(action='DESELECT')
orig_body.select_set(True)
bpy.context.view_layer.objects.active = orig_body
for mod in list(orig_body.modifiers):
    if mod.type == 'ARMATURE':
        bpy.ops.object.modifier_apply(modifier=mod.name)

bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.data.objects.remove(orig_arm, do_unlink=True)
for old_act in list(bpy.data.actions):
    bpy.data.actions.remove(old_act, do_unlink=True)

TARGET_UV_NAME = orig_body.data.uv_layers[0].name if orig_body.data.uv_layers else "UVMap"

# Build 23-bone `ZombieRig`
arm_data = bpy.data.armatures.new("ZombieRigData")
rig = bpy.data.objects.new("ZombieRig", arm_data)
COLLECTIONS["01_Rig"].objects.link(rig)
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

add_eb("Clavicle.L", JOINT_POS["L_shoulder"],  JOINT_POS["L_arm"],   "Chest", False)
add_eb("UpperArm.L", JOINT_POS["L_arm"],       JOINT_POS["L_elbow"], "Clavicle.L", True)
add_eb("Forearm.L",  JOINT_POS["L_elbow"],     JOINT_POS["L_wrist"], "UpperArm.L", True)
add_eb("Hand.L",     JOINT_POS["L_wrist"],     JOINT_POS["L_wrist"] + (JOINT_POS["L_wrist"] - JOINT_POS["L_elbow"]).normalized() * 0.14, "Forearm.L", True)

add_eb("Clavicle.R", JOINT_POS["R_shoulder"],  JOINT_POS["R_arm"],   "Chest", False)
add_eb("UpperArm.R", JOINT_POS["R_arm"],       JOINT_POS["R_elbow"], "Clavicle.R", True)
add_eb("Forearm.R",  JOINT_POS["R_elbow"],     JOINT_POS["R_wrist"], "UpperArm.R", True)
add_eb("Hand.R",     JOINT_POS["R_wrist"],     JOINT_POS["R_wrist"] + (JOINT_POS["R_wrist"] - JOINT_POS["R_elbow"]).normalized() * 0.14, "Forearm.R", True)

add_eb("Thigh.L",    JOINT_POS["L_leg"],       JOINT_POS["L_knee"],  "Hips", False)
add_eb("Shin.L",     JOINT_POS["L_knee"],      JOINT_POS["L_ankle"], "Thigh.L", True)
add_eb("Foot.L",     JOINT_POS["L_ankle"],     JOINT_POS["L_foot"],  "Shin.L", True)
add_eb("Toes.L",     JOINT_POS["L_foot"],      JOINT_POS["L_toes"],  "Foot.L", True)

add_eb("Thigh.R",    JOINT_POS["R_leg"],       JOINT_POS["R_knee"],  "Hips", False)
add_eb("Shin.R",     JOINT_POS["R_knee"],      JOINT_POS["R_ankle"], "Thigh.R", True)
add_eb("Foot.R",     JOINT_POS["R_ankle"],     JOINT_POS["R_foot"],  "Shin.R", True)
add_eb("Toes.R",     JOINT_POS["R_foot"],      JOINT_POS["R_toes"],  "Foot.R", True)

bpy.ops.object.mode_set(mode='OBJECT')

# Remap original 54 vertex groups onto `ZombieRig`
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

remap_mesh_vgroups_to_rig(orig_body)
assign_mat(orig_body, "Skin")
smooth_shade(orig_body)

def bind_to_rig(obj, col_name):
    obj.parent = rig
    has_arm = any(m.type == 'ARMATURE' for m in obj.modifiers)
    if not has_arm:
        m = obj.modifiers.new("Armature", 'ARMATURE')
        m.object = rig
    move_to_col(obj, col_name)
    return obj

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

# ─── 4. EXTRACT CONFORMING CLOTHING & ARMOR SHELLS BEFORE SPLITTING BODY ──────
def extract_conforming_shell(src_obj, name, face_filter_fn, offset=0.0045, thickness=0.004,
                             mat_key="Shirt", col_name="03_Clothing", reproject_uv=False):
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

    for v in bm.verts:
        co = v.co
        ripple = 0.0014 * math.sin(co.x * 28.0 + co.z * 19.0) * math.cos(co.y * 23.0)
        v.co += v.normal * (offset + ripple)

    bm.to_mesh(shell.data)
    bm.free()
    shell.data.update()

    if thickness > 0:
        sol = shell.modifiers.new("Solidify", 'SOLIDIFY')
        sol.thickness = thickness
        sol.offset = 1.0
        bpy.context.view_layer.objects.active = shell
        bpy.ops.object.modifier_apply(modifier=sol.name)

    if reproject_uv:
        box_project_uv(shell, scale=2.8)
    assign_mat(shell, mat_key)
    smooth_shade(shell)
    return bind_to_rig(shell, col_name)

# 4.1 Clothing Option A: Torn Tactical Vest (`Slot_Cloth_TacticalVest`)
extract_conforming_shell(
    orig_body, "Slot_Cloth_TacticalVest",
    lambda c, n: (1.15 <= c.z <= 1.56 and abs(c.x) <= 0.205
                  and not (c.x < 0.015 and c.y < -0.01 and 1.24 < c.z < 1.49)
                  and not (c.y > 0.02 and abs(c.x) < 0.048 and 1.14 < c.z < 1.57)
                  and c.z >= 1.17 + 0.045 * math.sin(c.x * 35.0 + c.y * 18.0)),
    offset=0.004, thickness=0.0035, mat_key="Shirt", col_name="03_Clothing"
)

# 4.2 Clothing Option B: Nomad Shoulder Shroud / Post-Apoc Hooded Poncho (`Slot_Cloth_RagsHood`)
extract_conforming_shell(
    orig_body, "Slot_Cloth_RagsHood",
    lambda c, n: (1.34 <= c.z <= 1.62 and abs(c.x) <= 0.25
                  and not (c.x < 0.01 and c.y < -0.02 and 1.30 < c.z < 1.46)
                  and c.z >= 1.36 + 0.04 * math.cos(c.x * 24.0 - c.y * 18.0)),
    offset=0.0065, thickness=0.0045, mat_key="Shirt", col_name="03_Clothing"
)

# 4.3 Pants Option A: Asymmetric Torn Cargo Pants (`Slot_Cloth_CargoPants_Asym`)
extract_conforming_shell(
    orig_body, "Slot_Cloth_CargoPants_Asym",
    lambda c, n: (0.42 <= c.z <= 1.02 and abs(c.x) <= 0.235
                  and (c.z >= 0.71 + 0.03 * math.sin(c.x * 40.0) if c.x >= 0 else c.z >= 0.47 + 0.03 * math.cos(c.x * 45.0))
                  and not (c.x < 0 and c.y < -0.04 and 0.58 < c.z < 0.66 and -0.21 < c.x < -0.12)),
    offset=0.005, thickness=0.004, mat_key="Pants", col_name="03_Clothing"
)

# 4.4 Pants Option B: Short Shredded Breeches for Dual Cyber-Legs (`Slot_Cloth_CargoPants_Short`)
extract_conforming_shell(
    orig_body, "Slot_Cloth_CargoPants_Short",
    lambda c, n: (0.68 <= c.z <= 1.02 and abs(c.x) <= 0.235
                  and c.z >= 0.71 + 0.035 * math.sin(c.x * 38.0 + c.y * 28.0)),
    offset=0.0055, thickness=0.004, mat_key="Pants", col_name="03_Clothing"
)

# 4.5 Left & Right Combat Boots (`Slot_Boot_L`, `Slot_Boot_R`)
boot_l = extract_conforming_shell(
    orig_body, "Slot_Boot_L",
    lambda c, n: (c.x > 0.05 and c.z < 0.285),
    offset=0.0055, thickness=0.005, mat_key="Leather", col_name="07_CyberLegsBoots", reproject_uv=True
)
boot_r = extract_conforming_shell(
    orig_body, "Slot_Boot_R",
    lambda c, n: (c.x < -0.05 and c.z < 0.285),
    offset=0.0055, thickness=0.005, mat_key="Leather", col_name="07_CyberLegsBoots", reproject_uv=True
)

# 4.6 Cranial Plates (`Slot_Head_CranialPlate_L`, `Slot_Head_CranialPlate_R`)
cran_l = extract_conforming_shell(
    orig_body, "Slot_Head_CranialPlate_L",
    lambda c, n: (c.z >= 1.765 and c.x >= -0.008),
    offset=0.0025, thickness=0.0045, mat_key="Steel", col_name="04_HeadImplants", reproject_uv=True
)
cran_r = extract_conforming_shell(
    orig_body, "Slot_Head_CranialPlate_R",
    lambda c, n: (c.z >= 1.765 and c.x <= 0.008),
    offset=0.0025, thickness=0.0045, mat_key="Steel", col_name="04_HeadImplants", reproject_uv=True
)

# 4.7 Conforming Juggernaut Heavy Chest Armor Shell (`Slot_Torso_HeavyArmor`)
heavy_armor_shell = extract_conforming_shell(
    orig_body, "Slot_Torso_HeavyArmor",
    lambda c, n: (1.22 <= c.z <= 1.53 and abs(c.x) <= 0.185 and c.y < 0.01 and abs(c.x) >= 0.016),
    offset=0.008, thickness=0.010, mat_key="Steel", col_name="05_TorsoBackImplants", reproject_uv=True
)

# ─── 5. SPLIT ORGANIC BODY INTO 5 INDEPENDENT ZONES (`02_OrganicBody`) ────────
# Use exact skeletal vertex group weights (Forearm+Hand, Shin+Foot+Toes) so amputating
# any limb cleanly removes 100% of the hand/fingers/foot with zero stray vertices!
vg_name_to_idx = {vg.name: vg.index for vg in orig_body.vertex_groups}

def get_vert_group_sum(v, bone_names):
    total = 0.0
    for bname in bone_names:
        gi = vg_name_to_idx.get(bname, -1)
        if gi >= 0:
            for g in v.groups:
                if g.group == gi:
                    total += g.weight
    return total

VERT_ZONE = {}
for v in orig_body.data.vertices:
    co = v.co
    if get_vert_group_sum(v, ("Forearm.L", "Hand.L")) > 0.18 or (co.x > 0.215 and co.z < 1.39):
        VERT_ZONE[v.index] = "Body_Arm_L"
    elif get_vert_group_sum(v, ("Forearm.R", "Hand.R")) > 0.18 or (co.x < -0.215 and co.z < 1.39):
        VERT_ZONE[v.index] = "Body_Arm_R"
    elif get_vert_group_sum(v, ("Shin.L", "Foot.L", "Toes.L")) > 0.22 or (co.x > 0.02 and co.z < 0.64):
        VERT_ZONE[v.index] = "Body_Leg_L"
    elif get_vert_group_sum(v, ("Shin.R", "Foot.R", "Toes.R")) > 0.22 or (co.x < -0.02 and co.z < 0.64):
        VERT_ZONE[v.index] = "Body_Leg_R"
    else:
        VERT_ZONE[v.index] = "Body_TorsoHead"

def classify_body_face_verts(bm_face):
    counts = {}
    for v in bm_face.verts:
        z = VERT_ZONE.get(v.index, "Body_TorsoHead")
        counts[z] = counts.get(z, 0) + 1
    # Majority vote among face vertices
    return max(counts.items(), key=lambda kv: kv[1])[0]

BODY_ZONES = {}
for zname in ("Body_TorsoHead", "Body_Arm_L", "Body_Arm_R", "Body_Leg_L", "Body_Leg_R"):
    bpy.ops.object.select_all(action='DESELECT')
    orig_body.select_set(True)
    bpy.context.view_layer.objects.active = orig_body
    bpy.ops.object.duplicate()
    zobj = bpy.context.active_object
    zobj.name = zname
    bm = bmesh.new()
    bm.from_mesh(zobj.data)
    bm.faces.ensure_lookup_table()
    to_del = [f for f in bm.faces if classify_body_face_verts(f) != zname]
    bmesh.ops.delete(bm, geom=to_del, context='FACES')
    bm.to_mesh(zobj.data)
    bm.free()
    zobj.data.update()
    BODY_ZONES[zname] = bind_to_rig(zobj, "02_OrganicBody")

# Add Dead Right & Left Eyes to `Body_TorsoHead` so organic face always has eyeballs
L_EYE = JOINT_POS["L_eye"]
R_EYE = JOINT_POS["R_eye"]
for eye_pos, ename in ((L_EYE, "OrgLeftEye"), (R_EYE, "OrgRightEye")):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.0122, location=eye_pos + Vector((0, -0.004, 0)))
    eo = bpy.context.active_object
    eo.name = ename
    assign_mat(eo, "EyeDead")
    smooth_shade(eo)
    eo.vertex_groups.new(name="Head").add(list(range(len(eo.data.vertices))), 1.0, 'REPLACE')
    bpy.ops.object.select_all(action='DESELECT')
    BODY_ZONES["Body_TorsoHead"].select_set(True)
    eo.select_set(True)
    bpy.context.view_layer.objects.active = BODY_ZONES["Body_TorsoHead"]
    bpy.ops.object.join()

bpy.data.objects.remove(orig_body, do_unlink=True)

# ─── 6. MODULAR CYBERNETIC SLOT BUILDER HELPERS ──────────────────────────────
def make_cyl_part(name, p1, p2, r1, r2=None, verts=16, mat_key="Steel", bone_name="Chest"):
    if r2 is None:
        r2 = r1
    p1 = Vector(p1)
    p2 = Vector(p2)
    vec = p2 - p1
    length = max(vec.length, 0.001)
    mid = (p1 + p2) * 0.5
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=length, location=mid)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec.normalized())
    obj.rotation_mode = 'XYZ'
    box_project_uv(obj, scale=2.6)
    assign_mat(obj, mat_key)
    smooth_shade(obj)
    obj.vertex_groups.new(name=bone_name).add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    return obj

def make_tube_part(name, points, radius=0.008, mat_key="Rubber", bone_name="Chest", corrugated=False):
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
    box_project_uv(obj, scale=2.6)
    assign_mat(obj, mat_key)
    smooth_shade(obj)
    obj.vertex_groups.new(name=bone_name).add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    return obj

def make_bolt_ring_part(name, center, axis_vec, radius, count=8, bolt_r=0.0045, mat_key="Chrome", bone_name="Chest"):
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
    box_project_uv(obj, scale=2.6)
    assign_mat(obj, mat_key)
    smooth_shade(obj)
    obj.vertex_groups.new(name=bone_name).add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    return obj

def join_slot_parts(slot_name, parts, col_name, base_obj=None):
    bpy.ops.object.select_all(action='DESELECT')
    all_p = ([base_obj] if base_obj else []) + parts
    for p in all_p:
        p.select_set(True)
    bpy.context.view_layer.objects.active = all_p[0]
    if len(all_p) > 1:
        bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = slot_name
    return bind_to_rig(joined, col_name)

# ─── 7. BUILD HEAD & JAW IMPLANT SLOTS (`04_HeadImplants`) ───────────────────
# 7.1 `Slot_Head_CranialPlate_L` (Left Titanium Skull Plate + Red Optic Scanner + Brow Laser)
optic_dir_l = Vector((0.08, -1.0, -0.04)).normalized()
brow_l = L_EYE + Vector((0.018, -0.004, 0.024))
join_slot_parts("Slot_Head_CranialPlate_L", [
    make_cyl_part("OptL_Mount", L_EYE + Vector((0.002, 0.012, 0)), L_EYE + optic_dir_l * 0.026, 0.025, 0.021, 20, "GunMetal", "Head"),
    make_cyl_part("OptL_Bezel", L_EYE + optic_dir_l * 0.020, L_EYE + optic_dir_l * 0.033, 0.021, 0.017, 20, "Steel", "Head"),
    make_cyl_part("OptL_Lens",  L_EYE + optic_dir_l * 0.028, L_EYE + optic_dir_l * 0.035, 0.014, 0.012, 20, "GlowPrimary", "Head"),
    make_bolt_ring_part("OptL_Bolts", L_EYE + optic_dir_l * 0.025, optic_dir_l, 0.0185, 6, 0.0025, "Chrome", "Head"),
    make_cyl_part("BrowL_Sens", brow_l, brow_l + optic_dir_l * 0.018, 0.008, 0.006, 12, "GunMetal", "Head"),
    make_cyl_part("BrowL_Glow", brow_l + optic_dir_l * 0.015, brow_l + optic_dir_l * 0.020, 0.0045, 0.004, 12, "GlowPrimary", "Head"),
], "04_HeadImplants", base_obj=cran_l)

# 7.2 `Slot_Head_CranialPlate_R` (Mirrored Right Titanium Skull Plate + Right Optic Scanner)
optic_dir_r = Vector((-0.08, -1.0, -0.04)).normalized()
brow_r = R_EYE + Vector((-0.018, -0.004, 0.024))
join_slot_parts("Slot_Head_CranialPlate_R", [
    make_cyl_part("OptR_Mount", R_EYE + Vector((-0.002, 0.012, 0)), R_EYE + optic_dir_r * 0.026, 0.025, 0.021, 20, "GunMetal", "Head"),
    make_cyl_part("OptR_Bezel", R_EYE + optic_dir_r * 0.020, R_EYE + optic_dir_r * 0.033, 0.021, 0.017, 20, "Steel", "Head"),
    make_cyl_part("OptR_Lens",  R_EYE + optic_dir_r * 0.028, R_EYE + optic_dir_r * 0.035, 0.014, 0.012, 20, "GlowPrimary", "Head"),
    make_bolt_ring_part("OptR_Bolts", R_EYE + optic_dir_r * 0.025, optic_dir_r, 0.0185, 6, 0.0025, "Chrome", "Head"),
    make_cyl_part("BrowR_Sens", brow_r, brow_r + optic_dir_r * 0.018, 0.008, 0.006, 12, "GunMetal", "Head"),
    make_cyl_part("BrowR_Glow", brow_r + optic_dir_r * 0.015, brow_r + optic_dir_r * 0.020, 0.0045, 0.004, 12, "GlowPrimary", "Head"),
], "04_HeadImplants", base_obj=cran_r)

# 7.3 `Slot_Head_Visor_Full` (Full-width Cyclops / Tactical Cyber-Visor across both eyes)
visor_parts = [
    make_cyl_part("VisorFrameL", (-0.068, -0.065, 1.804), (-0.032, -0.116, 1.804), 0.020, 0.022, 14, "GunMetal", "Head"),
    make_cyl_part("VisorFrameMid", (-0.036, -0.115, 1.804), (0.036, -0.115, 1.804), 0.022, 0.022, 16, "Steel", "Head"),
    make_cyl_part("VisorFrameR", (0.032, -0.116, 1.804), (0.068, -0.065, 1.804), 0.022, 0.020, 14, "GunMetal", "Head"),
    make_cyl_part("VisorSlitGlow", (-0.044, -0.124, 1.804), (0.044, -0.124, 1.804), 0.010, 0.010, 12, "GlowPrimary", "Head"),
]
join_slot_parts("Slot_Head_Visor_Full", visor_parts, "04_HeadImplants")

# 7.4 `Slot_Head_SirenHorns` (Acoustic Screamer Resonator Horns / Neural Antennas on Temples)
siren_parts = []
for s, tag in ((1.0, "L"), (-1.0, "R")):
    base_p = Vector((s * 0.068, -0.010, 1.825))
    tip_p  = Vector((s * 0.135, 0.025, 1.945))
    siren_parts.append(make_cyl_part(f"SirenBase_{tag}", base_p, tip_p, 0.016, 0.026, 16, "GunMetal", "Head"))
    siren_parts.append(make_cyl_part(f"SirenGlow_{tag}", tip_p, tip_p + (tip_p - base_p).normalized() * 0.008, 0.022, 0.018, 16, "GlowSecondary", "Head"))
join_slot_parts("Slot_Head_SirenHorns", siren_parts, "04_HeadImplants")

# 7.5 `Slot_Jaw_Respirator` (Mandible Clamp + Dual Filter Canisters + Corrugated Hoses)
jaw_chin = Vector((0.0, -0.118, 1.678))
resp_parts = [
    make_cyl_part("JawStrutL", (0.052, -0.058, 1.718), jaw_chin + Vector((0.022, 0.005, 0.004)), 0.011, 0.014, 10, "GunMetal", "Jaw"),
    make_cyl_part("JawStrutR", (-0.052, -0.058, 1.718), jaw_chin + Vector((-0.022, 0.005, 0.004)), 0.011, 0.014, 10, "GunMetal", "Jaw"),
    make_cyl_part("JawChinGuard", jaw_chin + Vector((-0.026, 0.002, 0)), jaw_chin + Vector((0.026, 0.002, 0)), 0.016, 0.016, 12, "Steel", "Jaw"),
    make_cyl_part("JawFilterL", (0.032, -0.105, 1.682), (0.052, -0.118, 1.668), 0.013, 0.015, 14, "GunMetal", "Jaw"),
    make_cyl_part("JawFilterR", (-0.032, -0.105, 1.682), (-0.052, -0.118, 1.668), 0.013, 0.015, 14, "GunMetal", "Jaw"),
    make_tube_part("RespHoseL", [(0.042, -0.108, 1.680), (0.048, -0.112, 1.662), (0.060, -0.104, 1.605), (0.054, -0.096, 1.540), (0.036, -0.084, 1.478)], 0.0095, "Rubber", "Chest", True),
    make_tube_part("RespHoseR", [(-0.042, -0.108, 1.680), (-0.048, -0.112, 1.662), (-0.060, -0.104, 1.605), (-0.054, -0.096, 1.540), (-0.036, -0.084, 1.478)], 0.0095, "Rubber", "Chest", True),
]
join_slot_parts("Slot_Jaw_Respirator", resp_parts, "04_HeadImplants")

# 7.6 `Slot_Jaw_AcidSpitter` (Bio-Chemical Spitter Nozzle + Glowing Throat Sac)
spit_parts = [
    make_cyl_part("SpitNozzleBase", (0.0, -0.105, 1.690), (0.0, -0.155, 1.668), 0.024, 0.018, 16, "GunMetal", "Jaw"),
    make_cyl_part("SpitNozzleTip",  (0.0, -0.150, 1.670), (0.0, -0.168, 1.662), 0.020, 0.015, 16, "Steel", "Jaw"),
    make_cyl_part("SpitCoreGlow",   (0.0, -0.162, 1.665), (0.0, -0.170, 1.661), 0.012, 0.010, 14, "GlowPrimary", "Jaw"),
    make_cyl_part("ThroatSacGlow",  (0.0, -0.085, 1.625), (0.0, -0.115, 1.575), 0.034, 0.028, 16, "GlowPrimary", "Neck"),
]
join_slot_parts("Slot_Jaw_AcidSpitter", spit_parts, "04_HeadImplants")

# ─── 8. BUILD TORSO & BACK IMPLANT SLOTS (`05_TorsoBackImplants`) ─────────────
# 8.1 `Slot_Torso_ChestCore_R` (Surgical Chest Cavity + Exposed Ribs + Glowing Reactor Core)
CORE_POS = Vector((-0.065, -0.095, 1.385))
core_dir = Vector((-0.18, -1.0, 0.05)).normalized()
core_parts = [
    make_cyl_part("CoreMeatBed", CORE_POS + core_dir * (-0.022), CORE_POS + core_dir * 0.008, 0.064, 0.058, 18, "Meat", "Chest"),
    make_cyl_part("CoreHousing", CORE_POS + core_dir * (-0.015), CORE_POS + core_dir * 0.022, 0.046, 0.040, 24, "GunMetal", "Chest"),
    make_cyl_part("CoreRing",    CORE_POS + core_dir * 0.018,   CORE_POS + core_dir * 0.028, 0.041, 0.034, 24, "Steel", "Chest"),
    make_cyl_part("CoreTurbine", CORE_POS + core_dir * 0.022,   CORE_POS + core_dir * 0.032, 0.029, 0.025, 20, "GlowPrimary", "Chest"),
    make_bolt_ring_part("CoreBolts", CORE_POS + core_dir * 0.024, core_dir, 0.037, 8, 0.0035, "Chrome", "Chest"),
]
for idx, rz in enumerate((1.435, 1.402, 1.368, 1.335)):
    core_parts.append(make_tube_part(f"Rib_{idx}", [
        (-0.012, -0.104, rz), (-0.045, -0.114, rz + 0.004), (-0.088, -0.106, rz - 0.003), (-0.122, -0.078, rz - 0.010)
    ], 0.0055, "Bone", "Chest"))
join_slot_parts("Slot_Torso_ChestCore_R", core_parts, "05_TorsoBackImplants")

# 8.2 `Slot_Torso_HeavyArmor` (Conforming Juggernaut Chest Plates + Center Core Guard + Bolts)
armor_parts = [
    make_bolt_ring_part("HeavyPecBolts_L", (0.078, -0.122, 1.405), (0.2, -1.0, 0.08), 0.052, 6, 0.0045, "Chrome", "Chest"),
    make_bolt_ring_part("HeavyPecBolts_R", (-0.078, -0.122, 1.405), (-0.2, -1.0, 0.08), 0.052, 6, 0.0045, "Chrome", "Chest"),
    make_cyl_part("HeavySternumCore", (0.0, -0.105, 1.385), (0.0, -0.132, 1.385), 0.036, 0.028, 16, "GunMetal", "Chest"),
    make_cyl_part("HeavySternumGlow", (0.0, -0.126, 1.385), (0.0, -0.136, 1.385), 0.020, 0.018, 16, "GlowSecondary", "Chest"),
]
join_slot_parts("Slot_Torso_HeavyArmor", armor_parts, "05_TorsoBackImplants", base_obj=heavy_armor_shell)

# 8.3 `Slot_Back_ExoSpine` (9-Vertebra Dorsal Exo-Spine + Chrome Rails + Neural Cables)
spine_pts = [
    (0.0, 0.095, 1.04), (0.0, 0.100, 1.11), (0.0, 0.106, 1.18),
    (0.0, 0.114, 1.25), (0.0, 0.120, 1.32), (0.0, 0.124, 1.39),
    (0.0, 0.122, 1.46), (0.0, 0.112, 1.53), (0.0, 0.096, 1.60)
]
spine_parts = [
    make_tube_part("SpineRailL", [(x + 0.020, y, z) for (x, y, z) in spine_pts], 0.0065, "Chrome", "Chest"),
    make_tube_part("SpineRailR", [(x - 0.020, y, z) for (x, y, z) in spine_pts], 0.0065, "Chrome", "Chest"),
]
for idx, (sx, sy, sz) in enumerate(spine_pts):
    b_p = "Spine" if sz < 1.29 else "Chest"
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, sy + 0.012, sz))
    vb = bpy.context.active_object
    vb.name = f"Vertebra_{idx}"
    vb.scale = (0.036, 0.026, 0.026)
    vb.rotation_euler = (math.radians(-8), 0, 0)
    bpy.ops.object.transform_apply(scale=True)
    box_project_uv(vb, scale=2.6)
    assign_mat(vb, "GunMetal" if idx % 2 == 0 else "Steel")
    smooth_shade(vb)
    vb.vertex_groups.new(name=b_p).add(list(range(len(vb.data.vertices))), 1.0, 'REPLACE')
    spine_parts.append(vb)
    if idx in (1, 3, 5, 7):
        spine_parts.append(make_cyl_part(f"SpineGlow_{idx}", (sx, sy + 0.022, sz), (sx, sy + 0.031, sz), 0.008, 0.006, 12, "GlowSecondary", b_p))
for s, tag in ((1.0, "L"), (-1.0, "R")):
    spine_parts.append(make_tube_part(f"NeuralCable_{tag}", [
        (s * 0.024, 0.068, 1.755), (s * 0.034, 0.095, 1.665), (s * 0.028, 0.105, 1.565), (s * 0.020, 0.108, 1.460)
    ], 0.0065, "Rubber", "Chest", True))
join_slot_parts("Slot_Back_ExoSpine", spine_parts, "05_TorsoBackImplants")

# 8.4 `Slot_Back_ChemTanks` (Twin Pressurized Bio-Hazard Cylinders on Back)
tank_parts = []
for s, tag in ((1.0, "L"), (-1.0, "R")):
    tx = s * 0.082
    tank_parts.append(make_cyl_part(f"ChemTank_{tag}", (tx, 0.148, 1.20), (tx, 0.165, 1.50), 0.052, 0.052, 20, "GunMetal", "Chest"))
    tank_parts.append(make_cyl_part(f"ChemWindow_{tag}", (tx, 0.162, 1.25), (tx, 0.175, 1.45), 0.044, 0.044, 18, "GlowPrimary", "Chest"))
    tank_parts.append(make_cyl_part(f"ChemCapTop_{tag}", (tx, 0.165, 1.50), (tx, 0.168, 1.54), 0.050, 0.032, 18, "Steel", "Chest"))
    tank_parts.append(make_tube_part(f"ChemHose_{tag}", [(tx, 0.168, 1.54), (s * 0.12, 0.08, 1.62), (s * 0.05, -0.08, 1.66)], 0.010, "Rubber", "Chest", True))
join_slot_parts("Slot_Back_ChemTanks", tank_parts, "05_TorsoBackImplants")

# 8.5 `Slot_Cloth_BeltHarness` (Tactical Waist Belt + Battery Pouches)
belt_parts = [
    make_cyl_part("WaistBeltRing", (0.0, -0.008, 1.025), (0.0, -0.008, 1.065), 0.165, 0.162, 24, "Leather", "Hips"),
    make_cyl_part("BeltBuckle", (0.0, -0.168, 1.045), (0.0, -0.180, 1.045), 0.028, 0.026, 8, "Steel", "Hips"),
]
for s, tag in ((1.0, "L"), (-1.0, "R")):
    belt_parts.append(make_cyl_part(f"BeltBattery_{tag}", (s * 0.155, -0.04, 1.01), (s * 0.155, -0.04, 1.08), 0.024, 0.024, 12, "GunMetal", "Hips"))
    belt_parts.append(make_cyl_part(f"BeltBattGlow_{tag}", (s * 0.155, -0.04, 1.08), (s * 0.155, -0.04, 1.09), 0.016, 0.014, 12, "GlowSecondary", "Hips"))
join_slot_parts("Slot_Cloth_BeltHarness", belt_parts, "03_Clothing")

# ─── 9. BUILD LEFT & RIGHT CYBER-ARM SLOTS (`06_CyberArms`) ──────────────────
def build_cyber_arm_set(side_sign, tag):
    sh_p = JOINT_POS[f"{tag}_arm"]
    el_p = JOINT_POS[f"{tag}_elbow"]
    wr_p = JOINT_POS[f"{tag}_wrist"]
    u_dir = (el_p - sh_p).normalized()
    f_dir = (wr_p - el_p).normalized()

    # 1. Shoulder Pauldron (`Slot_Pauldron_L` / `Slot_Pauldron_R`)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.088, location=sh_p + Vector((side_sign * 0.028, -0.005, 0.025)))
    paul = bpy.context.active_object
    paul.name = f"Slot_Pauldron_{tag}"
    paul.scale = (1.05, 0.88, 0.72)
    paul.rotation_euler = (0, math.radians(side_sign * 28), math.radians(-side_sign * 10))
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(paul.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().x * side_sign < -0.01 or f.calc_center_median().z < -0.015], context='FACES')
    bm.to_mesh(paul.data)
    bm.free()
    sol = paul.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.007
    bpy.ops.object.modifier_apply(modifier=sol.name)
    box_project_uv(paul, scale=2.6)
    assign_mat(paul, "Steel")
    smooth_shade(paul)
    paul.vertex_groups.new(name=f"UpperArm.{tag}").add(list(range(len(paul.data.vertices))), 1.0, 'REPLACE')
    bind_to_rig(paul, "06_CyberArms")

    # 2. Hydraulic Cyber-Arm + 4-Claw Hand (`Slot_ArmL_CyberClaw` / `Slot_ArmR_CyberClaw`)
    el_axis = Vector((side_sign * 1.0, 0.25, 0.0)).normalized()
    palm_c = wr_p + f_dir * 0.042
    arm_parts = [
        make_cyl_part(f"ArmMeat_{tag}", sh_p.lerp(el_p, 0.36), sh_p.lerp(el_p, 0.50), 0.060, 0.054, 18, "Meat", f"UpperArm.{tag}"),
        make_cyl_part(f"ArmCollar_{tag}", sh_p.lerp(el_p, 0.44), sh_p.lerp(el_p, 0.56), 0.058, 0.052, 20, "GunMetal", f"UpperArm.{tag}"),
        make_bolt_ring_part(f"ArmBolts_{tag}", sh_p.lerp(el_p, 0.49), u_dir, 0.057, 8, 0.0045, "Chrome", f"UpperArm.{tag}"),
        make_cyl_part(f"HumShaft_{tag}", sh_p.lerp(el_p, 0.48), el_p, 0.034, 0.030, 16, "GunMetal", f"UpperArm.{tag}"),
        make_cyl_part(f"HumPistC_{tag}", sh_p.lerp(el_p, 0.45) + Vector((side_sign * 0.024, -0.020, 0)), el_p.lerp(sh_p, 0.25) + Vector((side_sign * 0.022, -0.022, 0)), 0.016, 0.016, 12, "Steel", f"UpperArm.{tag}"),
        make_cyl_part(f"HumPistR_{tag}", sh_p.lerp(el_p, 0.65) + Vector((side_sign * 0.023, -0.021, 0)), el_p + Vector((side_sign * 0.020, -0.022, 0)), 0.009, 0.009, 12, "Chrome", f"UpperArm.{tag}"),
        make_cyl_part(f"ElbowSrv_{tag}", el_p - el_axis * 0.044, el_p + el_axis * 0.044, 0.042, 0.042, 20, "Steel", f"Forearm.{tag}"),
        make_cyl_part(f"ForeCore_{tag}", el_p, wr_p, 0.036, 0.028, 16, "GunMetal", f"Forearm.{tag}"),
        make_cyl_part(f"ForeShell_{tag}", el_p.lerp(wr_p, 0.14), el_p.lerp(wr_p, 0.84), 0.048, 0.038, 10, "Steel", f"Forearm.{tag}"),
        make_cyl_part(f"ForeGlow_{tag}", el_p.lerp(wr_p, 0.32) + Vector((side_sign * 0.018, -0.015, 0)), el_p.lerp(wr_p, 0.68) + Vector((side_sign * 0.016, -0.015, 0)), 0.012, 0.010, 12, "GlowSecondary", f"Forearm.{tag}"),
        make_cyl_part(f"WristCuff_{tag}", wr_p - f_dir * 0.015, wr_p + f_dir * 0.020, 0.032, 0.034, 16, "GunMetal", f"Hand.{tag}"),
        make_cyl_part(f"PalmBlock_{tag}", wr_p + f_dir * 0.018, wr_p + f_dir * 0.065, 0.032, 0.028, 8, "Steel", f"Hand.{tag}"),
    ]
    for idx, y_off in enumerate((-0.030, -0.010, 0.010, 0.030)):
        kn = palm_c + Vector((side_sign * 0.008, y_off, -0.038))
        md = kn + Vector((-side_sign * 0.010, y_off * 0.15 - 0.018, -0.042))
        tp = md + Vector((-side_sign * 0.028, -0.012, -0.035))
        arm_parts.append(make_cyl_part(f"FingP_{tag}_{idx}", kn, md, 0.0085, 0.0070, 8, "GunMetal", f"Hand.{tag}"))
        arm_parts.append(make_cyl_part(f"FingC_{tag}_{idx}", md, tp, 0.0070, 0.0012, 6, "Chrome", f"Hand.{tag}"))
    join_slot_parts(f"Slot_Arm{tag}_CyberClaw", arm_parts, "06_CyberArms")

    # 3. Forearm Ripper Blade Attachment (`Slot_ArmL_Weapon_Blade` / `Slot_ArmR_Weapon_Blade`)
    b_base = el_p.lerp(wr_p, 0.28) + Vector((side_sign * 0.036, -0.010, 0.0))
    b_tip  = wr_p + f_dir * 0.24 + Vector((side_sign * 0.032, -0.022, 0.0))
    blade_parts = [
        make_cyl_part(f"BladeMount_{tag}", b_base, b_base.lerp(b_tip, 0.35), 0.018, 0.014, 8, "GunMetal", f"Forearm.{tag}"),
        make_cyl_part(f"BladeEdge_{tag}",  b_base.lerp(b_tip, 0.12), b_tip, 0.016, 0.0015, 4, "Chrome", f"Forearm.{tag}"),
    ]
    join_slot_parts(f"Slot_Arm{tag}_Weapon_Blade", blade_parts, "06_CyberArms")

build_cyber_arm_set(1.0, "L")
build_cyber_arm_set(-1.0, "R")

# Additional Heavy Weapons for Right Arm:
# `Slot_ArmR_Weapon_Crusher` (Hydraulic Siege Hammer Fist)
P_WR_R = JOINT_POS["R_wrist"]
P_EL_R = JOINT_POS["R_elbow"]
f_dir_r = (P_WR_R - P_EL_R).normalized()
crush_parts = [
    make_cyl_part("CrusherHead", P_WR_R + f_dir_r * 0.02 + Vector((0, -0.06, 0)), P_WR_R + f_dir_r * 0.02 + Vector((0, 0.06, 0)), 0.072, 0.072, 12, "Steel", "Hand.R"),
    make_cyl_part("CrusherFace", P_WR_R + f_dir_r * 0.02 + Vector((0, -0.06, 0)), P_WR_R + f_dir_r * 0.02 + Vector((0, -0.085, 0)), 0.068, 0.076, 12, "GunMetal", "Hand.R"),
    make_cyl_part("CrusherGlow", P_WR_R + f_dir_r * 0.02 + Vector((0, 0.06, 0)), P_WR_R + f_dir_r * 0.02 + Vector((0, 0.072, 0)), 0.048, 0.042, 12, "GlowSecondary", "Hand.R"),
]
join_slot_parts("Slot_ArmR_Weapon_Crusher", crush_parts, "06_CyberArms")

# `Slot_ArmR_Weapon_Cannon` (Bio-Plasma / Chemical Mortar Barrel on Right Forearm)
cannon_parts = [
    make_cyl_part("CannonBarrel", P_EL_R.lerp(P_WR_R, 0.25), P_WR_R + f_dir_r * 0.18, 0.056, 0.048, 18, "GunMetal", "Forearm.R"),
    make_cyl_part("CannonMuzzle", P_WR_R + f_dir_r * 0.14, P_WR_R + f_dir_r * 0.21, 0.054, 0.058, 18, "Steel", "Forearm.R"),
    make_cyl_part("CannonCoreGlow", P_WR_R + f_dir_r * 0.19, P_WR_R + f_dir_r * 0.215, 0.038, 0.036, 16, "GlowPrimary", "Forearm.R"),
]
join_slot_parts("Slot_ArmR_Weapon_Cannon", cannon_parts, "06_CyberArms")

# ─── 10. BUILD LEFT & RIGHT CYBER-LEG SLOTS (`07_CyberLegsBoots`) ─────────────
def build_cyber_leg_set(side_sign, tag):
    hip_p  = JOINT_POS[f"{tag}_leg"]
    knee_p = JOINT_POS[f"{tag}_knee"]
    ank_p  = JOINT_POS[f"{tag}_ankle"]
    foot_p = JOINT_POS[f"{tag}_foot"]
    toe_p  = JOINT_POS[f"{tag}_toes"]
    t_dir  = (knee_p - hip_p).normalized()

    leg_parts = [
        make_cyl_part(f"LegMeat_{tag}", hip_p.lerp(knee_p, 0.72), hip_p.lerp(knee_p, 0.88), 0.076, 0.066, 20, "Meat", f"Thigh.{tag}"),
        make_cyl_part(f"LegCuff_{tag}", hip_p.lerp(knee_p, 0.78), knee_p, 0.072, 0.056, 20, "GunMetal", f"Thigh.{tag}"),
        make_bolt_ring_part(f"LegBolts_{tag}", hip_p.lerp(knee_p, 0.83), t_dir, 0.070, 10, 0.005, "Chrome", f"Thigh.{tag}"),
        make_cyl_part(f"KneeRot_{tag}", knee_p + Vector((-0.052, 0, 0)), knee_p + Vector((0.052, 0, 0)), 0.052, 0.052, 20, "Steel", f"Shin.{tag}"),
        make_cyl_part(f"TibiaStrut_{tag}", knee_p + Vector((0, -0.024, -0.02)), ank_p + Vector((0, -0.022, 0.02)), 0.026, 0.022, 16, "Steel", f"Shin.{tag}"),
        make_cyl_part(f"FibulaStrut_{tag}", knee_p + Vector((side_sign * 0.032, 0.015, -0.02)), ank_p + Vector((side_sign * 0.026, 0.010, 0.02)), 0.018, 0.015, 14, "GunMetal", f"Shin.{tag}"),
        make_cyl_part(f"ShockCyl_{tag}", knee_p + Vector((-side_sign * 0.010, 0.038, -0.03)), knee_p.lerp(ank_p, 0.58) + Vector((-side_sign * 0.008, 0.035, 0)), 0.028, 0.026, 16, "GunMetal", f"Shin.{tag}"),
        make_cyl_part(f"ShockRod_{tag}", knee_p.lerp(ank_p, 0.52) + Vector((-side_sign * 0.008, 0.035, 0)), ank_p + Vector((-side_sign * 0.005, 0.025, 0.02)), 0.015, 0.015, 14, "Chrome", f"Shin.{tag}"),
        make_cyl_part(f"ShinArmor_{tag}", knee_p.lerp(ank_p, 0.18) + Vector((0, -0.036, 0)), knee_p.lerp(ank_p, 0.76) + Vector((0, -0.030, 0)), 0.034, 0.024, 8, "Steel", f"Shin.{tag}"),
        make_cyl_part(f"AnkleSrv_{tag}", ank_p + Vector((-0.042, 0, 0)), ank_p + Vector((0.042, 0, 0)), 0.036, 0.036, 18, "GunMetal", f"Foot.{tag}"),
        make_cyl_part(f"HeelSpur_{tag}", ank_p, ank_p + Vector((0, 0.068, -0.115)), 0.024, 0.016, 12, "Steel", f"Foot.{tag}"),
        make_cyl_part(f"FootArch_{tag}", ank_p, foot_p, 0.032, 0.028, 14, "Steel", f"Foot.{tag}"),
    ]
    for idx, x_off in enumerate((-0.032, 0.0, 0.032)):
        ts = foot_p + Vector((x_off, -0.010, -0.010))
        tm = toe_p  + Vector((x_off * 1.15, -0.015, 0.002))
        tt = tm     + Vector((x_off * 0.2, -0.048, -0.018))
        leg_parts.append(make_cyl_part(f"ToeB_{tag}_{idx}", ts, tm, 0.014, 0.011, 8, "GunMetal", f"Toes.{tag}"))
        leg_parts.append(make_cyl_part(f"ToeT_{tag}_{idx}", tm, tt, 0.011, 0.003, 6, "Chrome", f"Toes.{tag}"))
    join_slot_parts(f"Slot_Leg{tag}_CyberStrut", leg_parts, "07_CyberLegsBoots")

build_cyber_leg_set(1.0, "L")
build_cyber_leg_set(-1.0, "R")

# Add rubber soles & ankle straps to `Slot_Boot_L` and `Slot_Boot_R`
for side_s, tag, b_obj in ((1.0, "L", boot_l), (-1.0, "R", boot_r)):
    ank_p  = JOINT_POS[f"{tag}_ankle"]
    foot_p = JOINT_POS[f"{tag}_foot"]
    toe_p  = JOINT_POS[f"{tag}_toes"]
    b_parts = [
        make_cyl_part(f"BootCollar_{tag}", ank_p + Vector((-side_s * 0.015, -0.032, 0.125)), ank_p + Vector((-side_s * 0.012, -0.028, 0.095)), 0.048, 0.044, 16, "GunMetal", f"Shin.{tag}"),
        make_cyl_part(f"BootBrace_{tag}",  ank_p + Vector((-side_s * 0.005, -0.015, 0.035)), ank_p + Vector((-side_s * 0.002, -0.010, 0.010)), 0.044, 0.045, 16, "Steel", f"Foot.{tag}"),
    ]
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=foot_p.lerp(toe_p, 0.42) + Vector((0, 0.022, -0.014)))
    sole = bpy.context.active_object
    sole.name = f"BootSole_{tag}"
    sole.scale = (0.048, 0.128, 0.015)
    sole.rotation_euler = (0, 0, math.radians(side_s * 6))
    bpy.ops.object.transform_apply(scale=True)
    box_project_uv(sole, scale=2.6)
    assign_mat(sole, "Rubber")
    smooth_shade(sole)
    sole.vertex_groups.new(name=f"Foot.{tag}").add(list(range(len(sole.data.vertices))), 1.0, 'REPLACE')
    b_parts.append(sole)
    join_slot_parts(f"Slot_Boot_{tag}", b_parts, "07_CyberLegsBoots", base_obj=b_obj)

# ─── 11. CREATE ALL 7 SKELETAL ANIMATIONS ON `ZombieRig` ─────────────────────
print("Building 7 skeletal animations on ZombieRig...")
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'

BONE_REST_MAT = {pb.name: (rig.matrix_world @ pb.bone.matrix_local).to_3x3() for pb in rig.pose.bones}

def set_bone_world_pose(pb_name, rx=0.0, ry=0.0, rz=0.0, loc=None):
    pb = rig.pose.bones[pb_name]
    R_w = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_matrix().to_3x3()
    R_b = BONE_REST_MAT[pb_name]
    pb.rotation_euler = (R_b.inverted() @ R_w @ R_b).to_euler('XYZ')
    pb.location = (R_b.inverted() @ Vector(loc)) if loc is not None else (0.0, 0.0, 0.0)

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
    if not rig.animation_data:
        rig.animation_data_create()
    track = rig.animation_data.nla_tracks.new()
    track.name = act.name
    strip = track.strips.new(act.name, int(act.frame_range[0]), act)
    strip.name = act.name
    track.mute = True

# Idle
act_idle = bpy.data.actions.new("Idle")
rig.animation_data_create()
rig.animation_data.action = act_idle
for f, ph in [(1, 0.0), (19, 0.5 * math.pi), (37, math.pi), (55, 1.5 * math.pi), (72, 2.0 * math.pi)]:
    reset_pose()
    s1, c1 = math.sin(ph), math.cos(ph)
    set_bone_world_pose("Hips", rx=4 + 1.5 * s1, ry=2.5 * c1, rz=2.0 * s1, loc=(0.012 * c1, 0, -0.015 + 0.010 * s1))
    set_bone_world_pose("Spine", rx=8 + 2.5 * s1, ry=-2.0 * c1, rz=-2.0 * s1)
    set_bone_world_pose("Chest", rx=6 + 3.5 * s1, ry=1.5 * s1, rz=3.0 * c1)
    set_bone_world_pose("Neck", rx=-5 + 2.0 * c1, ry=4.0 * s1, rz=-5.0 * s1)
    set_bone_world_pose("Head", rx=-4 - 3.0 * s1, ry=-6.0 * c1, rz=8.0 * s1)
    set_bone_world_pose("Jaw", rx=-6 - 5.0 * max(0, s1))
    set_bone_world_pose("UpperArm.L", rx=12 + 4 * s1, ry=4, rz=-6)
    set_bone_world_pose("Forearm.L", rx=24 + 6 * c1, ry=0, rz=-10)
    set_bone_world_pose("UpperArm.R", rx=8 - 3 * s1, ry=-4, rz=6)
    set_bone_world_pose("Forearm.R", rx=18 - 4 * c1, ry=0, rz=8)
    set_bone_world_pose("Thigh.L", rx=8 - 1.5 * s1)
    set_bone_world_pose("Shin.L", rx=-14 + 2.5 * s1)
    set_bone_world_pose("Foot.L", rx=6 - 1.0 * s1)
    set_bone_world_pose("Thigh.R", rx=5 + 1.5 * s1)
    set_bone_world_pose("Shin.R", rx=-10 - 2.5 * s1)
    set_bone_world_pose("Foot.R", rx=5 + 1.0 * s1)
    key_all_bones(f)
finalize_action(act_idle)

# Walk
act_walk = bpy.data.actions.new("Walk")
rig.animation_data.action = act_walk
for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in [
    (1,   26, -12,  8,  -20, -18, -10, -0.025,  4.5, 14, -9, -16,  24),
    (10,   4, -16,  0,    6, -42, -16, -0.055,  2.0, 17, -3,   2,   6),
    (19, -22, -22, -12,  30, -10,  10, -0.020, -4.5, 13,  9,  24, -18),
    (28,   8, -46, -18,   4, -16,   0, -0.045, -2.0, 16,  4,   4,   4),
    (36,  26, -12,  8,  -20, -18, -10, -0.025,  4.5, 14, -9, -16,  24),
]:
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
    set_bone_world_pose("Thigh.L", rx=lt)
    set_bone_world_pose("Shin.L", rx=ls)
    set_bone_world_pose("Foot.L", rx=lf)
    set_bone_world_pose("Thigh.R", rx=rt)
    set_bone_world_pose("Shin.R", rx=rs)
    set_bone_world_pose("Foot.R", rx=rf)
    key_all_bones(f)
finalize_action(act_walk)

# Run
act_run = bpy.data.actions.new("Run")
rig.animation_data.action = act_run
for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in [
    (1,   42, -18, 12,  -34, -28, -16, -0.04,  5.0, 22, -14, -28,  38),
    (6,    6, -24,  0,   12, -62, -22,  0.02,  1.5, 25,  -4,   4,   8),
    (11, -34, -30, -16,  44, -16,  14, -0.04, -5.0, 22,  14,  38, -28),
    (16,  14, -64, -22,   6, -24,   0,  0.02, -1.5, 25,   4,   8,   4),
    (20,  42, -18, 12,  -34, -28, -16, -0.04,  5.0, 22, -14, -28,  38),
]:
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

# Attack
act_atk = bpy.data.actions.new("Attack")
rig.animation_data.action = act_atk
reset_pose(); key_all_bones(1)
set_bone_world_pose("Hips", rx=4, rz=-18, loc=(0, 0.03, -0.02))
set_bone_world_pose("Spine", rx=-6, rz=-22); set_bone_world_pose("Chest", rx=-8, rz=-28)
set_bone_world_pose("Head", rx=-10, rz=24); set_bone_world_pose("Jaw", rx=-26)
set_bone_world_pose("UpperArm.L", rx=85, ry=28, rz=-35); set_bone_world_pose("Forearm.L", rx=55, rz=-20)
set_bone_world_pose("UpperArm.R", rx=-18, ry=-15, rz=15)
key_all_bones(8)
reset_pose()
set_bone_world_pose("Hips", rx=16, rz=22, loc=(0, -0.06, -0.04))
set_bone_world_pose("Spine", rx=22, rz=26); set_bone_world_pose("Chest", rx=24, rz=32)
set_bone_world_pose("Head", rx=-14, rz=-24); set_bone_world_pose("Jaw", rx=-30)
set_bone_world_pose("UpperArm.L", rx=28, ry=-24, rz=38); set_bone_world_pose("Forearm.L", rx=12, rz=22)
set_bone_world_pose("UpperArm.R", rx=65, ry=-20, rz=25); set_bone_world_pose("Forearm.R", rx=45)
key_all_bones(14)
reset_pose()
set_bone_world_pose("Hips", rx=14, rz=-16, loc=(0, -0.04, -0.03))
set_bone_world_pose("Spine", rx=18, rz=-20); set_bone_world_pose("Chest", rx=20, rz=-26)
set_bone_world_pose("UpperArm.L", rx=-12, ry=14, rz=-15); set_bone_world_pose("Forearm.L", rx=30)
set_bone_world_pose("UpperArm.R", rx=36, ry=18, rz=-32); set_bone_world_pose("Forearm.R", rx=16)
key_all_bones(20)
reset_pose(); key_all_bones(28)
finalize_action(act_atk)

# Hit
act_hit = bpy.data.actions.new("Hit")
rig.animation_data.action = act_hit
reset_pose(); key_all_bones(1)
set_bone_world_pose("Hips", rx=-12, ry=-6, rz=14, loc=(0.03, 0.06, -0.03))
set_bone_world_pose("Spine", rx=-18, ry=-8, rz=18); set_bone_world_pose("Chest", rx=-22, ry=-10, rz=24)
set_bone_world_pose("Head", rx=-28, ry=18, rz=22); set_bone_world_pose("Jaw", rx=-28)
set_bone_world_pose("UpperArm.L", rx=-24, ry=28, rz=-20); set_bone_world_pose("Forearm.L", rx=48)
set_bone_world_pose("UpperArm.R", rx=-20, ry=-26, rz=20); set_bone_world_pose("Forearm.R", rx=42)
key_all_bones(5)
reset_pose()
set_bone_world_pose("Hips", rx=10, ry=4, rz=-8, loc=(0.01, 0.02, -0.02))
set_bone_world_pose("Spine", rx=14, rz=-6); set_bone_world_pose("Chest", rx=12, rz=-8)
key_all_bones(11)
reset_pose(); key_all_bones(18)
finalize_action(act_hit)

# Death
act_death = bpy.data.actions.new("Death")
rig.animation_data.action = act_death
reset_pose(); key_all_bones(1)
set_bone_world_pose("Hips", rx=-10, rz=10, loc=(0, 0.03, -0.04))
set_bone_world_pose("Spine", rx=-16, rz=12); set_bone_world_pose("Chest", rx=-22, rz=16)
set_bone_world_pose("Head", rx=-32, ry=16, rz=18); set_bone_world_pose("Jaw", rx=-34)
set_bone_world_pose("UpperArm.L", rx=45, ry=35, rz=-25); set_bone_world_pose("UpperArm.R", rx=40, ry=-35, rz=25)
key_all_bones(8)
reset_pose()
set_bone_world_pose("Hips", rx=28, ry=8, rz=-12, loc=(0.02, -0.05, -0.44))
set_bone_world_pose("Spine", rx=24, rz=-10); set_bone_world_pose("Chest", rx=28, rz=-12)
set_bone_world_pose("Thigh.L", rx=52); set_bone_world_pose("Shin.L", rx=-115); set_bone_world_pose("Foot.L", rx=45)
set_bone_world_pose("Thigh.R", rx=48); set_bone_world_pose("Shin.R", rx=-110); set_bone_world_pose("Foot.R", rx=45)
key_all_bones(20)
for f_end in (34, 42):
    reset_pose()
    set_bone_world_pose("Hips", rx=84, ry=18, rz=-14, loc=(0.05, -0.38, -0.86))
    set_bone_world_pose("Spine", rx=10, ry=-8, rz=6); set_bone_world_pose("Chest", rx=6, ry=-6, rz=8)
    set_bone_world_pose("Head", rx=-22, ry=28, rz=32); set_bone_world_pose("Jaw", rx=-24)
    set_bone_world_pose("UpperArm.L", rx=55, ry=42, rz=-20); set_bone_world_pose("UpperArm.R", rx=25, ry=-38, rz=15)
    key_all_bones(f_end)
finalize_action(act_death)

# Roar
act_roar = bpy.data.actions.new("Roar")
rig.animation_data.action = act_roar
reset_pose(); key_all_bones(1)
set_bone_world_pose("Hips", rx=14, loc=(0, 0, -0.06)); set_bone_world_pose("Spine", rx=18); set_bone_world_pose("Chest", rx=20)
set_bone_world_pose("UpperArm.L", rx=28, ry=-15, rz=20); set_bone_world_pose("UpperArm.R", rx=28, ry=15, rz=-20)
key_all_bones(8)
for f_r, h_shake in ((18, -14), (23, 14), (28, -10)):
    reset_pose()
    set_bone_world_pose("Hips", rx=-8, loc=(0, -0.03, 0.01)); set_bone_world_pose("Spine", rx=-14); set_bone_world_pose("Chest", rx=-18)
    set_bone_world_pose("Head", rx=-24, ry=h_shake * 0.4, rz=h_shake); set_bone_world_pose("Jaw", rx=-38)
    set_bone_world_pose("UpperArm.L", rx=-18, ry=38, rz=-32); set_bone_world_pose("UpperArm.R", rx=-18, ry=-38, rz=32)
    key_all_bones(f_r)
reset_pose(); key_all_bones(40)
finalize_action(act_roar)

for tr in rig.animation_data.nla_tracks:
    tr.mute = False
rig.animation_data.action = act_idle
scene.frame_set(1)

# ─── 12. SAVE MASTER MODULAR TEMPLATE (`.BLEND` & `.GLB`) ────────────────────
print("Saving modular zombie_cyborg_template.blend and .glb...")
bpy.ops.wm.save_as_mainfile(filepath=TEMPLATE_BLEND)

bpy.ops.export_scene.gltf(
    filepath=TEMPLATE_GLB,
    export_format='GLB',
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_nla_strips=True,
    export_apply=False,
    export_yup=True
)
shutil.copy2(TEMPLATE_GLB, GAME_TMPL_GLB)

# ─── 13. RENDER 4 CUSTOMIZED VARIANTS LINEUP (`template_variants_preview.png`) ─
print("Rendering 4-variant customization showcase...")
ALL_SLOT_OBJS = [o for o in bpy.data.objects if o.type == 'MESH']

def apply_preset_visibility_and_colors(preset_cfg):
    org = preset_cfg["organic_limbs"]
    active_slots = set(preset_cfg["slots"])
    for o in ALL_SLOT_OBJS:
        if o.name == "Body_TorsoHead":
            o.hide_render = False
        elif o.name == "Body_Arm_L":
            o.hide_render = not org.get("arm_l", True)
        elif o.name == "Body_Arm_R":
            o.hide_render = not org.get("arm_r", True)
        elif o.name == "Body_Leg_L":
            o.hide_render = not org.get("leg_l", True)
        elif o.name == "Body_Leg_R":
            o.hide_render = not org.get("leg_r", True)
        else:
            o.hide_render = (o.name not in active_slots)

    cols = preset_cfg.get("colors", {})
    if "glow_color" in cols:
        gc = cols["glow_color"]
        bsdf = MAT["GlowPrimary"].node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*gc, 1.0)
            for k in ("Emission Color", "Emission"):
                if k in bsdf.inputs:
                    bsdf.inputs[k].default_value = (*gc, 1.0)

# Render each of the 4 presets at 500x950 and stitch into a 2000x950 showcase image
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
scene.cycles.samples = 36
scene.cycles.use_denoising = True
scene.render.resolution_x = 520
scene.render.resolution_y = 960

world = bpy.data.worlds.new("TemplateWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.045, 0.05, 0.06, 1.0)
    bg.inputs["Strength"].default_value = 0.75

def add_light(name, loc, rot_deg, energy, color=(1, 1, 1), size=2.0):
    ld = bpy.data.lights.new(name, type='AREA')
    ld.energy = energy
    ld.color = color
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)

add_light("Key",  (-1.8, -2.5, 2.5), (55, 0, -35), 260.0, (1.0, 0.96, 0.90))
add_light("Fill", ( 2.2, -1.8, 1.6), (65, 0,  45), 150.0, (0.75, 0.85, 1.0))
add_light("Rim",  ( 0.0,  2.4, 2.3), (-55, 0,  0), 210.0, (0.9, 0.9, 1.0))

cam_data = bpy.data.cameras.new("ShowcaseCam")
cam_data.lens = 45
cam_obj = bpy.data.objects.new("ShowcaseCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location = Vector((0.30, -2.75, 1.05))
direction = (Vector((0.0, 0.0, 0.98)) - cam_obj.location).normalized()
cam_obj.rotation_mode = 'QUATERNION'
cam_obj.rotation_quaternion = direction.to_track_quat('-Z', 'Y')
cam_obj.rotation_mode = 'XYZ'

# Save example JSON preset files to C:/Users/user/ZombieCyborg/presets/
PRESETS_DIR = os.path.join(OUT_DIR, "presets")
os.makedirs(PRESETS_DIR, exist_ok=True)
for pname, pcfg in PRESETS.items():
    with open(os.path.join(PRESETS_DIR, f"{pname}.json"), "w", encoding="utf-8") as f_json:
        json.dump(pcfg, f_json, ensure_ascii=False, indent=2)

# Check if CLI requested a specific single-variant export (`--preset <name> --out <file.glb>` or `--config <file.json> --out <file.glb>`)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if "--preset" in argv or "--config" in argv:
    custom_cfg = None
    if "--preset" in argv:
        p_key = argv[argv.index("--preset") + 1]
        custom_cfg = PRESETS.get(p_key, PRESETS["default_walker"])
    elif "--config" in argv:
        c_path = argv[argv.index("--config") + 1]
        with open(c_path, "r", encoding="utf-8") as fc:
            custom_cfg = json.load(fc)
    out_glb = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(OUT_DIR, "custom_zombie_cyborg.glb")
    apply_preset_visibility_and_colors(custom_cfg)
    for o in list(ALL_SLOT_OBJS):
        if o.hide_render:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format='GLB',
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_nla_strips=True,
        export_apply=False,
        export_yup=True
    )
    print(f"Exported custom variant to: {out_glb}")
    sys.exit(0)

panel_paths = []
for idx, (pname, pcfg) in enumerate(PRESETS.items()):
    apply_preset_visibility_and_colors(pcfg)
    if idx == 0:
        rig.animation_data.action = act_idle; scene.frame_set(1)
    elif idx == 1:
        rig.animation_data.action = act_roar; scene.frame_set(18)
    elif idx == 2:
        rig.animation_data.action = act_idle; scene.frame_set(25)
    else:
        rig.animation_data.action = act_atk; scene.frame_set(10)
    p_path = os.path.join(OUT_DIR, f"_tmp_panel_{idx}.png")
    scene.render.filepath = p_path
    bpy.ops.render.render(write_still=True)
    panel_paths.append(p_path)

print("UNIVERSAL ZOMBIE-CYBORG TEMPLATE COMPLETED SUCCESSFULLY!")
