"""
blender_build_all_zombies.py
Generates full set of high-detail post-apocalyptic Cyborg Zombie 3D GLB models
matching the gritty, realistic desert cyborg aesthetic from the reference image.
"""

import bpy
import math
import os

PROJECT_DIR = r"c:\Users\user\Documents\идет-караван-из-ирана"
MODELS_DIR = os.path.join(PROJECT_DIR, "models", "zombies")
os.makedirs(MODELS_DIR, exist_ok=True)

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_mat(name, base_color, metallic=0.0, roughness=0.5, emission_color=(0,0,0,1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = base_color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
        if emission_strength > 0.0:
            bsdf.inputs['Emission Color'].default_value = emission_color
            bsdf.inputs['Emission Strength'].default_value = emission_strength
    return mat

def get_materials():
    return {
        "flesh": create_pbr_mat("M_Flesh", (0.35, 0.28, 0.22, 1.0), metallic=0.05, roughness=0.88),
        "flesh_dark": create_pbr_mat("M_FleshDark", (0.19, 0.15, 0.12, 1.0), metallic=0.05, roughness=0.92),
        "bone": create_pbr_mat("M_Bone", (0.68, 0.62, 0.52, 1.0), metallic=0.0, roughness=0.75),
        "steel": create_pbr_mat("M_Steel", (0.22, 0.23, 0.25, 1.0), metallic=0.92, roughness=0.32),
        "armor": create_pbr_mat("M_Armor", (0.28, 0.27, 0.26, 1.0), metallic=0.85, roughness=0.45),
        "chrome": create_pbr_mat("M_Chrome", (0.85, 0.88, 0.90, 1.0), metallic=0.98, roughness=0.12),
        "rags": create_pbr_mat("M_Rags", (0.42, 0.36, 0.27, 1.0), metallic=0.0, roughness=0.95),
        "wire_red": create_pbr_mat("M_WireRed", (0.65, 0.08, 0.06, 1.0), metallic=0.1, roughness=0.45),
        "wire_dark": create_pbr_mat("M_WireDark", (0.08, 0.08, 0.09, 1.0), metallic=0.2, roughness=0.55),
        "optic_red": create_pbr_mat("M_OpticRed", (0.4, 0.0, 0.0, 1.0), metallic=0.1, roughness=0.1, emission_color=(1.0, 0.04, 0.02, 1.0), emission_strength=10.0),
        "optic_cyan": create_pbr_mat("M_OpticCyan", (0.0, 0.3, 0.4, 1.0), metallic=0.1, roughness=0.1, emission_color=(0.1, 0.8, 1.0, 1.0), emission_strength=10.0),
        "ooze_green": create_pbr_mat("M_OozeGreen", (0.05, 0.35, 0.1, 1.0), metallic=0.1, roughness=0.2, emission_color=(0.15, 1.0, 0.25, 1.0), emission_strength=8.0),
        "plasma_yellow": create_pbr_mat("M_PlasmaYellow", (0.4, 0.35, 0.02, 1.0), metallic=0.1, roughness=0.2, emission_color=(1.0, 0.85, 0.1, 1.0), emission_strength=9.0)
    }

def create_empty(name, parent=None, location=(0,0,0), rotation=(0,0,0)):
    emp = bpy.data.objects.new(name, None)
    emp.empty_display_type = 'PLAIN_AXES'
    emp.empty_display_size = 0.08
    bpy.context.collection.objects.link(emp)
    if parent:
        emp.parent = parent
    emp.location = location
    emp.rotation_euler = rotation
    return emp

def setup_obj(obj, name, material=None, parent=None, location=(0,0,0), rotation=(0,0,0), scale=(1,1,1)):
    obj.name = name
    if material:
        obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj

def add_cube(name, size=(0.1, 0.1, 0.1), location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    return setup_obj(bpy.context.active_object, name, material, parent, location, rotation, scale=size)

def add_cylinder(name, radius=0.02, depth=0.2, segments=8, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=segments)
    return setup_obj(bpy.context.active_object, name, material, parent, location, rotation)

def add_sphere(name, radius=0.05, segments=12, rings=8, location=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings)
    return setup_obj(bpy.context.active_object, name, material, parent, location, scale=scale)

def add_cone(name, radius1=0.02, radius2=0.001, depth=0.1, segments=6, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cone_add(radius1=radius1, radius2=radius2, depth=depth, vertices=segments)
    return setup_obj(bpy.context.active_object, name, material, parent, location, rotation)

def add_torus(name, major_radius=0.1, minor_radius=0.02, location=(0,0,0), rotation=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius, major_segments=12, minor_segments=6)
    return setup_obj(bpy.context.active_object, name, material, parent, location, rotation, scale=scale)

def export_glb(filename):
    export_path = os.path.join(MODELS_DIR, filename)
    print(f"Exporting: {export_path}")
    bpy.ops.export_scene.gltf(
        filepath=export_path,
        export_format='GLB',
        use_selection=False,
        export_apply=False,
        export_yup=True
    )
    print(f"Exported: {filename}")

# Standard Rig Builder
def build_base_rig(scale_mult=1.0):
    root = create_empty("Root", location=(0,0,0))
    pelvis = create_empty("Pelvis", parent=root, location=(0, 0, 0.88 * scale_mult))
    torso = create_empty("Torso", parent=pelvis, location=(0, 0, 0.12 * scale_mult))
    chest = create_empty("Chest", parent=torso, location=(0, 0, 0.22 * scale_mult))
    head = create_empty("Head", parent=chest, location=(0, 0.05 * scale_mult, 0.36 * scale_mult))

    l_shoulder = create_empty("L_Shoulder", parent=chest, location=(-0.24 * scale_mult, 0.0, 0.22 * scale_mult))
    l_elbow = create_empty("L_Elbow", parent=l_shoulder, location=(0.0, 0.0, -0.32 * scale_mult))

    r_shoulder = create_empty("R_Shoulder", parent=chest, location=(0.25 * scale_mult, 0.0, 0.22 * scale_mult))
    r_elbow = create_empty("R_Elbow", parent=r_shoulder, location=(0.0, 0.0, -0.34 * scale_mult))

    l_hip = create_empty("L_Hip", parent=pelvis, location=(-0.14 * scale_mult, 0.0, -0.05 * scale_mult))
    l_knee = create_empty("L_Knee", parent=l_hip, location=(0.0, 0.0, -0.42 * scale_mult))

    r_hip = create_empty("R_Hip", parent=pelvis, location=(0.14 * scale_mult, 0.0, -0.05 * scale_mult))
    r_knee = create_empty("R_Knee", parent=r_hip, location=(0.0, 0.0, -0.42 * scale_mult))

    return {
        "root": root, "pelvis": pelvis, "torso": torso, "chest": chest, "head": head,
        "l_shoulder": l_shoulder, "l_elbow": l_elbow, "r_shoulder": r_shoulder, "r_elbow": r_elbow,
        "l_hip": l_hip, "l_knee": l_knee, "r_hip": r_hip, "r_knee": r_knee
    }

# =========================================================================
# 1. WALKER (Standard desert cyborg zombie - Exact Reference)
# =========================================================================
def build_walker():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.0)
    
    # Head
    add_sphere("MummyCranium", radius=0.11, segments=16, rings=12, location=(0.01, -0.01, 0.02), scale=(0.95, 1.15, 1.1), material=m["flesh"], parent=r["head"])
    add_sphere("MummyCheek_R", radius=0.06, segments=8, rings=6, location=(0.05, 0.04, -0.04), scale=(0.7, 1.0, 1.2), material=m["flesh_dark"], parent=r["head"])
    add_cube("CyberPlate_Main", size=(0.08, 0.13, 0.14), location=(-0.055, 0.02, 0.04), rotation=(0, math.radians(-10), math.radians(10)), material=m["steel"], parent=r["head"])
    add_cube("CyberPlate_Temple", size=(0.04, 0.08, 0.09), location=(-0.085, -0.03, 0.01), rotation=(math.radians(15), 0, math.radians(15)), material=m["armor"], parent=r["head"])
    for r_idx in range(5):
        ang = 0.2 + r_idx * 0.35
        add_sphere(f"Rivet_{r_idx}", radius=0.008, segments=6, rings=4, location=(-math.sin(ang)*0.10-0.01, math.cos(ang)*0.09+0.02, 0.08-r_idx*0.03), material=m["chrome"], parent=r["head"])
    add_cylinder("OpticHousing", radius=0.024, depth=0.025, segments=12, location=(-0.045, 0.095, 0.012), rotation=(math.radians(90), 0, math.radians(-12)), material=m["steel"], parent=r["head"])
    add_sphere("GlowingOpticLens", radius=0.015, segments=10, rings=8, location=(-0.045, 0.106, 0.012), material=m["optic_red"], parent=r["head"])
    add_sphere("MummySocket_R", radius=0.016, segments=8, rings=6, location=(0.045, 0.088, 0.012), scale=(1.0, 0.5, 0.9), material=m["flesh_dark"], parent=r["head"])
    add_cube("JawBase", size=(0.09, 0.11, 0.04), location=(0.0, 0.065, -0.085), rotation=(math.radians(16), 0, 0), material=m["bone"], parent=r["head"])
    for t_idx in range(6):
        tx = -0.032 + t_idx * 0.013
        ty = 0.115 - abs(tx) * 0.35
        add_cone(f"Tooth_U_{t_idx}", radius1=0.005, radius2=0.001, depth=0.018, segments=5, location=(tx, ty, -0.065), rotation=(math.radians(180), 0, 0), material=m["bone"], parent=r["head"])
        add_cone(f"Tooth_L_{t_idx}", radius1=0.005, radius2=0.001, depth=0.016, segments=5, location=(tx, ty - 0.01, -0.098), material=m["bone"], parent=r["head"])
    for w_idx in range(5):
        wx = -0.065 + w_idx * 0.025
        wy = -0.04 - (w_idx % 2) * 0.02
        add_cylinder(f"NeckWire_{w_idx}", radius=0.005, depth=0.18, segments=6, location=(wx, wy, -0.09), rotation=(math.radians(-25), math.radians(12 - w_idx*6), math.radians(-8)), material=m["wire_red"] if w_idx%2==0 else m["wire_dark"], parent=r["head"])
    add_torus("NeckRags", major_radius=0.11, minor_radius=0.032, location=(0, -0.01, -0.11), scale=(1.1, 1.25, 0.7), material=m["rags"], parent=r["head"])
    add_cube("NeckRagStrip", size=(0.05, 0.012, 0.22), location=(0.04, 0.08, -0.22), rotation=(math.radians(15), math.radians(-10), math.radians(12)), material=m["rags"], parent=r["head"])

    # Chest & Torso
    for v_idx in range(5):
        add_cube(f"Vertebra_{v_idx}", size=(0.06, 0.045, 0.026), location=(0, -0.07, 0.18 - v_idx * 0.06), material=m["steel"], parent=r["chest"])
    add_cylinder("SpineHydraulic", radius=0.018, depth=0.34, segments=8, location=(0, -0.095, 0.04), material=m["chrome"], parent=r["chest"])
    for rib_idx in range(5):
        z_pos = 0.16 - rib_idx * 0.055
        sf = 1.0 - rib_idx * 0.07
        add_torus(f"Rib_L_{rib_idx}", major_radius=0.11 * sf, minor_radius=0.011, location=(-0.01, 0.01, z_pos), rotation=(math.radians(12), 0, math.radians(-10)), scale=(1.0, 1.1, 0.6), material=m["bone"], parent=r["chest"])
        add_torus(f"Rib_R_{rib_idx}", major_radius=0.11 * sf, minor_radius=0.011, location=(0.01, 0.01, z_pos), rotation=(math.radians(12), 0, math.radians(10)), scale=(1.0, 1.1, 0.6), material=m["steel"] if rib_idx%2==1 else m["bone"], parent=r["chest"])
    add_cube("Sternum", size=(0.03, 0.02, 0.16), location=(0.0, 0.115, 0.06), material=m["bone"], parent=r["chest"])
    add_cylinder("ThoracicCore", radius=0.034, depth=0.12, segments=8, location=(-0.02, 0.025, 0.06), material=m["ooze_green"], parent=r["chest"])
    add_cube("ChestCloth", size=(0.18, 0.13, 0.07), location=(0.06, 0.04, 0.19), rotation=(math.radians(14), math.radians(18), math.radians(-12)), material=m["rags"], parent=r["chest"])

    # Pelvis
    add_cube("PelvisCore", size=(0.16, 0.10, 0.08), location=(0, 0, -0.02), material=m["flesh_dark"], parent=r["pelvis"])
    add_torus("TacticalBelt", major_radius=0.17, minor_radius=0.025, location=(0, 0, 0.04), scale=(0.9, 0.8, 1.0), material=m["steel"], parent=r["pelvis"])
    add_cube("BeltBuckle", size=(0.035, 0.018, 0.03), location=(0.0, 0.145, 0.04), material=m["chrome"], parent=r["pelvis"])
    for p_idx in (-1, 1):
        add_cube(f"Pouch_{p_idx}", size=(0.05, 0.035, 0.055), location=(p_idx * 0.15, 0.04, 0.03), rotation=(0, 0, math.radians(p_idx * 15)), material=m["rags"], parent=r["pelvis"])
    for t_idx in range(4):
        add_cube(f"WaistTatter_{t_idx}", size=(0.04, 0.008, 0.18), location=(-0.09 + t_idx*0.06, 0.13 - abs(t_idx-1.5)*0.02, -0.12), rotation=(math.radians(12), math.radians(t_idx*4 - 6), 0), material=m["rags"], parent=r["pelvis"])

    # Right Cyber Arm
    add_sphere("ShoulderServo_R", radius=0.048, segments=10, rings=8, location=(0,0,0), material=m["steel"], parent=r["r_shoulder"])
    add_cube("Pauldron_R", size=(0.11, 0.13, 0.08), location=(0.05, 0.0, 0.05), rotation=(0, math.radians(-25), 0), material=m["armor"], parent=r["r_shoulder"])
    for h_idx in (-0.025, 0.025):
        add_cylinder(f"Sleeve_R_{h_idx}", radius=0.018, depth=0.18, segments=8, location=(h_idx, -0.01, -0.10), material=m["steel"], parent=r["r_shoulder"])
        add_cylinder(f"Rod_R_{h_idx}", radius=0.011, depth=0.16, segments=8, location=(h_idx, -0.01, -0.22), material=m["chrome"], parent=r["r_shoulder"])
    add_cylinder("ElbowHinge_R", radius=0.042, depth=0.045, segments=12, location=(0,0,0), rotation=(0, math.radians(90), 0), material=m["steel"], parent=r["r_elbow"])
    add_cube("ForearmArmor_R", size=(0.065, 0.075, 0.22), location=(0, 0.015, -0.14), material=m["armor"], parent=r["r_elbow"])
    add_cylinder("WristServo_R", radius=0.036, depth=0.035, segments=10, location=(0, 0, -0.27), material=m["steel"], parent=r["r_elbow"])
    add_cube("Palm_R", size=(0.055, 0.032, 0.05), location=(0, 0, -0.32), material=m["steel"], parent=r["r_elbow"])
    for f_idx, fx in enumerate((-0.032, -0.01, 0.012, 0.034)):
        add_cone(f"Talon_R_{f_idx}", radius1=0.009, radius2=0.001, depth=0.10, segments=6, location=(fx * 1.25, 0.035, -0.42), rotation=(math.radians(35), 0, math.radians(fx * 300)), material=m["chrome"], parent=r["r_elbow"])
    add_cone("Thumb_R", radius1=0.010, radius2=0.001, depth=0.08, segments=6, location=(-0.048, -0.02, -0.36), rotation=(math.radians(15), math.radians(40), math.radians(-30)), material=m["chrome"], parent=r["r_elbow"])

    # Left Mummy Arm
    add_sphere("Shoulder_L", radius=0.042, segments=8, rings=8, location=(0,0,0), material=m["flesh_dark"], parent=r["l_shoulder"])
    add_cylinder("UpperArm_L", radius=0.026, depth=0.28, segments=8, location=(0, 0, -0.15), material=m["flesh"], parent=r["l_shoulder"])
    add_cylinder("Forearm_L", radius=0.022, depth=0.26, segments=8, location=(0, 0, -0.13), material=m["flesh"], parent=r["l_elbow"])
    add_cube("Palm_L", size=(0.04, 0.022, 0.04), location=(0, 0, -0.28), material=m["flesh_dark"], parent=r["l_elbow"])
    for f_idx in range(4):
        fx = -0.025 + f_idx * 0.016
        add_cone(f"Claw_L_{f_idx}", radius1=0.007, radius2=0.001, depth=0.09, segments=5, location=(fx, 0.018, -0.34), rotation=(math.radians(28), 0, math.radians(fx * 250)), material=m["bone"], parent=r["l_elbow"])

    # Legs
    for side, hip, knee, is_r in (("L", r["l_hip"], r["l_knee"], False), ("R", r["r_hip"], r["r_knee"], True)):
        xm = 1.0 if is_r else -1.0
        add_sphere(f"HipServo_{side}", radius=0.048, segments=8, rings=8, location=(0,0,0), material=m["steel"], parent=hip)
        add_cylinder(f"Thigh_{side}", radius=0.05, depth=0.36, segments=10, location=(0, 0, -0.20), material=m["rags"], parent=hip)
        add_cube(f"ThighArmor_{side}", size=(0.08, 0.03, 0.22), location=(0, 0.05, -0.20), rotation=(math.radians(-5), 0, 0), material=m["armor"], parent=hip)
        add_cylinder(f"KneeServo_{side}", radius=0.048, depth=0.045, segments=12, location=(0,0,0), rotation=(0, math.radians(90), 0), material=m["steel"], parent=knee)
        add_cylinder(f"Shin_{side}", radius=0.042, depth=0.34, segments=8, location=(0, 0, -0.18), material=m["steel"], parent=knee)
        add_cube(f"ShinArmor_{side}", size=(0.065, 0.026, 0.22), location=(0, 0.046, -0.17), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.075, 0.16, 0.06), location=(0, 0.04, -0.40), material=m["armor"], parent=knee)
        for toe_idx in (-0.025, 0.0, 0.025):
            add_cone(f"BootClaw_{side}_{toe_idx}", radius1=0.009, radius2=0.001, depth=0.05, segments=5, location=(toe_idx, 0.13, -0.41), rotation=(math.radians(90), 0, 0), material=m["steel"], parent=knee)

    export_glb("cyborg_walker.glb")

# =========================================================================
# 2. RUNNER (Agile, fast cyber-ghoul, dual razor claw blades, twin crimson optics)
# =========================================================================
def build_runner():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.92) # slightly leaner/shorter

    # Head (twin glowing optics, streamlined predator skull)
    add_sphere("Cranium", radius=0.095, segments=14, rings=10, location=(0, 0.02, 0.02), scale=(0.85, 1.25, 1.0), material=m["flesh_dark"], parent=r["head"])
    add_cube("ForeheadPlate", size=(0.10, 0.14, 0.06), location=(0, 0.05, 0.04), rotation=(math.radians(20), 0, 0), material=m["steel"], parent=r["head"])
    # Twin red eyes
    for eye_x in (-0.035, 0.035):
        add_cylinder(f"OpticRing_{eye_x}", radius=0.018, depth=0.02, segments=8, location=(eye_x, 0.10, 0.015), rotation=(math.radians(90), 0, 0), material=m["steel"], parent=r["head"])
        add_sphere(f"OpticLens_{eye_x}", radius=0.012, segments=8, rings=6, location=(eye_x, 0.11, 0.015), material=m["optic_red"], parent=r["head"])
    add_cube("Jaw", size=(0.07, 0.12, 0.035), location=(0, 0.08, -0.06), rotation=(math.radians(20), 0, 0), material=m["bone"], parent=r["head"])

    # Chest (reinforced spine, exposed speed-boost thrusters / cooling vents)
    add_cylinder("Spine", radius=0.016, depth=0.32, segments=8, location=(0, -0.08, 0.04), material=m["chrome"], parent=r["chest"])
    add_cube("ChestArmor", size=(0.16, 0.12, 0.18), location=(0, 0.03, 0.06), material=m["armor"], parent=r["chest"])
    add_cylinder("ExhaustVent_L", radius=0.022, depth=0.12, segments=8, location=(-0.08, -0.10, 0.14), rotation=(math.radians(35), 0, 0), material=m["steel"], parent=r["chest"])
    add_cylinder("ExhaustVent_R", radius=0.022, depth=0.12, segments=8, location=(0.08, -0.10, 0.14), rotation=(math.radians(35), 0, 0), material=m["steel"], parent=r["chest"])

    # Pelvis
    add_cube("PelvisCore", size=(0.14, 0.09, 0.07), location=(0,0,-0.02), material=m["steel"], parent=r["pelvis"])

    # Both Arms: DUAL RAZOR CLAW BLADES (Terrifying predatory mantis/ghoul blades)
    for side, shoulder, elbow, is_r in (("L", r["l_shoulder"], r["l_elbow"], False), ("R", r["r_shoulder"], r["r_elbow"], True)):
        xm = 1.0 if is_r else -1.0
        add_cylinder(f"UpperArm_{side}", radius=0.024, depth=0.28, segments=8, location=(0,0,-0.14), material=m["steel"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.022, depth=0.28, segments=8, location=(0,0,-0.14), material=m["armor"], parent=elbow)
        # Giant razor-sharp blade forearm extension
        add_cube(f"RazorBlade_{side}", size=(0.012, 0.06, 0.35), location=(xm * 0.03, 0.04, -0.28), rotation=(math.radians(18), 0, 0), material=m["chrome"], parent=elbow)
        # Triple curved claws
        for c_idx in (-0.02, 0.0, 0.02):
            add_cone(f"RunnerClaw_{side}_{c_idx}", radius1=0.008, radius2=0.001, depth=0.12, segments=5, location=(c_idx, 0.03, -0.38), rotation=(math.radians(40), 0, 0), material=m["chrome"], parent=elbow)

    # Legs (Hydraulic sprint legs)
    for side, hip, knee, is_r in (("L", r["l_hip"], r["l_knee"], False), ("R", r["r_hip"], r["r_knee"], True)):
        add_cylinder(f"Thigh_{side}", radius=0.042, depth=0.34, segments=8, location=(0,0,-0.18), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.034, depth=0.34, segments=8, location=(0,0,-0.18), material=m["steel"], parent=knee)
        add_cylinder(f"ShinPiston_{side}", radius=0.012, depth=0.30, segments=6, location=(0, -0.04, -0.18), material=m["chrome"], parent=knee)
        add_cube(f"SprintBoot_{side}", size=(0.06, 0.15, 0.05), location=(0, 0.04, -0.38), material=m["armor"], parent=knee)

    export_glb("cyborg_runner.glb")

# =========================================================================
# 3. BRUTE (Massive juggernaut tank, heavy armor, colossal hydraulic fist & saw)
# =========================================================================
def build_brute():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.25) # 1.25x scale, massive

    # Head (Iron cage visor, heavy armored cowl)
    add_sphere("HeadCore", radius=0.14, segments=12, rings=8, location=(0, 0.02, 0.02), material=m["flesh_dark"], parent=r["head"])
    add_cube("HeavyHelmet", size=(0.20, 0.22, 0.20), location=(0, 0.03, 0.04), material=m["armor"], parent=r["head"])
    # Visor slit with intense red optic glow
    add_cube("VisorGlow", size=(0.14, 0.03, 0.03), location=(0, 0.13, 0.03), material=m["optic_red"], parent=r["head"])

    # Colossal Armored Torso with Engine Pack
    add_cube("TorsoArmor", size=(0.42, 0.28, 0.36), location=(0, 0.04, 0.12), material=m["armor"], parent=r["chest"])
    for p_idx in (-0.12, 0.12):
        add_cube(f"ChestPlate_{p_idx}", size=(0.14, 0.04, 0.24), location=(p_idx, 0.17, 0.12), material=m["steel"], parent=r["chest"])
    # Dual exhaust pipes on back
    add_cylinder("Exhaust_L", radius=0.038, depth=0.32, segments=10, location=(-0.14, -0.16, 0.24), material=m["steel"], parent=r["chest"])
    add_cylinder("Exhaust_R", radius=0.038, depth=0.32, segments=10, location=(0.14, -0.16, 0.24), material=m["steel"], parent=r["chest"])

    # Pelvis
    add_cube("PelvisHeavy", size=(0.32, 0.20, 0.14), location=(0,0,-0.03), material=m["armor"], parent=r["pelvis"])

    # Right Arm: COLOSSAL HYDRAULIC CRUSHER FIST
    add_sphere("ShoulderServo_R", radius=0.09, segments=10, rings=8, location=(0,0,0), material=m["steel"], parent=r["r_shoulder"])
    add_cube("PauldronHeavy_R", size=(0.22, 0.24, 0.16), location=(0.08, 0, 0.08), material=m["armor"], parent=r["r_shoulder"])
    add_cylinder("BicepPiston1_R", radius=0.035, depth=0.30, segments=8, location=(-0.04, 0, -0.18), material=m["steel"], parent=r["r_shoulder"])
    add_cylinder("BicepPiston2_R", radius=0.035, depth=0.30, segments=8, location=(0.04, 0, -0.18), material=m["chrome"], parent=r["r_shoulder"])
    add_cube("CrusherForearm_R", size=(0.16, 0.16, 0.30), location=(0, 0, -0.22), material=m["armor"], parent=r["r_elbow"])
    add_cube("CrusherFist_R", size=(0.18, 0.18, 0.18), location=(0, 0.04, -0.42), material=m["steel"], parent=r["r_elbow"])

    # Left Arm: ROTATING INDUSTRIAL CIRCULAR SAW
    add_sphere("ShoulderServo_L", radius=0.08, segments=10, rings=8, location=(0,0,0), material=m["steel"], parent=r["l_shoulder"])
    add_cylinder("Arm_L", radius=0.05, depth=0.30, segments=8, location=(0,0,-0.18), material=m["steel"], parent=r["l_shoulder"])
    add_cube("SawMount_L", size=(0.12, 0.12, 0.22), location=(0,0,-0.16), material=m["armor"], parent=r["l_elbow"])
    # Circular saw disc (named Saw_Disc so it spins!)
    add_cylinder("Saw_Disc_Brute", radius=0.22, depth=0.02, segments=24, location=(0, 0.06, -0.32), rotation=(0, math.radians(90), 0), material=m["chrome"], parent=r["l_elbow"])

    # Heavy Tank Legs
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"ThighHeavy_{side}", radius=0.08, depth=0.45, segments=10, location=(0,0,-0.24), material=m["armor"], parent=hip)
        add_cylinder(f"ShinHeavy_{side}", radius=0.075, depth=0.45, segments=10, location=(0,0,-0.24), material=m["steel"], parent=knee)
        add_cube(f"TankBoot_{side}", size=(0.14, 0.26, 0.10), location=(0, 0.06, -0.52), material=m["armor"], parent=knee)

    export_glb("cyborg_brute.glb")

# =========================================================================
# 4. SPITTER (Chemical mutagen cyborg, acid canisters, chemical spray nozzle)
# =========================================================================
def build_spitter():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.0)

    # Head (Gas mask / chemical respirator with elongated injector tube)
    add_sphere("HeadCore", radius=0.10, segments=12, rings=8, location=(0,0,0.02), material=m["flesh_dark"], parent=r["head"])
    add_cube("Respirator", size=(0.10, 0.11, 0.08), location=(0, 0.06, -0.04), material=m["steel"], parent=r["head"])
    # Open chemical spray nozzle
    add_cylinder("AcidNozzle", radius=0.024, depth=0.08, segments=10, location=(0, 0.13, -0.05), rotation=(math.radians(90), 0, 0), material=m["chrome"], parent=r["head"])
    add_sphere("AcidGlow", radius=0.015, segments=8, rings=6, location=(0, 0.15, -0.05), material=m["ooze_green"], parent=r["head"])

    # Chest: DUAL CHEMICAL ACID CANISTERS on Back
    add_cylinder("Spine", radius=0.018, depth=0.34, segments=8, location=(0, -0.08, 0.04), material=m["steel"], parent=r["chest"])
    add_cube("ChestPlate", size=(0.20, 0.14, 0.22), location=(0, 0.02, 0.08), material=m["armor"], parent=r["chest"])
    for side_x, name in ((-0.11, "L"), (0.11, "R")):
        # Glowing green chemical tanks
        add_cylinder(f"AcidTank_{name}", radius=0.042, depth=0.30, segments=10, location=(side_x, -0.10, 0.10), material=m["ooze_green"], parent=r["chest"])
        add_cylinder(f"TankCap_{name}", radius=0.046, depth=0.03, segments=10, location=(side_x, -0.10, 0.26), material=m["steel"], parent=r["chest"])
        # Ribbed hose running forward
        add_torus(f"AcidHose_{name}", major_radius=0.08, minor_radius=0.012, location=(side_x, -0.02, 0.18), rotation=(math.radians(45), 0, 0), material=m["wire_dark"], parent=r["chest"])

    # Pelvis
    add_cube("PelvisCore", size=(0.16, 0.10, 0.08), location=(0,0,-0.02), material=m["rags"], parent=r["pelvis"])

    # Arms (Injector claws)
    for side, shoulder, elbow, is_r in (("L", r["l_shoulder"], r["l_elbow"], False), ("R", r["r_shoulder"], r["r_elbow"], True)):
        add_cylinder(f"UpperArm_{side}", radius=0.028, depth=0.28, segments=8, location=(0,0,-0.15), material=m["flesh"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.025, depth=0.26, segments=8, location=(0,0,-0.14), material=m["steel"], parent=elbow)
        for c_idx in (-0.02, 0.02):
            add_cone(f"SpitterNeedle_{side}_{c_idx}", radius1=0.007, radius2=0.001, depth=0.11, segments=5, location=(c_idx, 0.02, -0.33), rotation=(math.radians(25), 0, 0), material=m["ooze_green"], parent=elbow)

    # Legs
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.048, depth=0.36, segments=8, location=(0,0,-0.20), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.040, depth=0.34, segments=8, location=(0,0,-0.18), material=m["steel"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.07, 0.15, 0.06), location=(0, 0.04, -0.40), material=m["armor"], parent=knee)

    export_glb("cyborg_spitter.glb")

# =========================================================================
# 5. SCREAMER (Sonic disruptor dish, acoustic siren, cyan pulsing emitters)
# =========================================================================
def build_screamer():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.96)

    # Head: ABLATIVE DISRUPTOR DISH mounted behind skull
    add_sphere("HeadCore", radius=0.10, segments=12, rings=8, location=(0, 0.02, 0.02), material=m["flesh_dark"], parent=r["head"])
    # Large parabolic acoustic dish
    add_cone("DisruptorDish", radius1=0.24, radius2=0.03, depth=0.06, segments=16, location=(0, -0.06, 0.10), rotation=(math.radians(-90), 0, 0), material=m["steel"], parent=r["head"])
    add_sphere("DisruptorCore", radius=0.04, segments=10, rings=8, location=(0, -0.04, 0.10), material=m["optic_cyan"], parent=r["head"])
    # Wide screaming jaw with acoustic speaker grille
    add_cube("SpeakerJaw", size=(0.08, 0.10, 0.05), location=(0, 0.07, -0.07), rotation=(math.radians(25), 0, 0), material=m["optic_cyan"], parent=r["head"])

    # Chest: Acoustic Resonance Amplifier
    add_cylinder("Spine", radius=0.016, depth=0.32, segments=8, location=(0, -0.08, 0.04), material=m["chrome"], parent=r["chest"])
    add_cube("ResonatorChest", size=(0.18, 0.12, 0.20), location=(0, 0.02, 0.06), material=m["armor"], parent=r["chest"])
    add_cylinder("SonicCoil", radius=0.045, depth=0.08, segments=12, location=(0, 0.09, 0.06), rotation=(math.radians(90), 0, 0), material=m["optic_cyan"], parent=r["chest"])

    # Pelvis & Limbs
    add_cube("PelvisCore", size=(0.15, 0.09, 0.07), location=(0,0,-0.02), material=m["steel"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.026, depth=0.28, segments=8, location=(0,0,-0.14), material=m["steel"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.022, depth=0.26, segments=8, location=(0,0,-0.13), material=m["flesh"], parent=elbow)
        for c_idx in (-0.02, 0.02):
            add_cone(f"Claw_{side}_{c_idx}", radius1=0.007, radius2=0.001, depth=0.09, segments=5, location=(c_idx, 0.02, -0.32), material=m["chrome"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.045, depth=0.34, segments=8, location=(0,0,-0.18), material=m["steel"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.038, depth=0.34, segments=8, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.07, 0.15, 0.05), location=(0, 0.04, -0.38), material=m["steel"], parent=knee)

    export_glb("cyborg_screamer.glb")

# =========================================================================
# 6. EXPLODER (Swollen pulsing reactor chest, volatile cells, hazard warning)
# =========================================================================
def build_exploder():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.05)

    # Head (Melted half-skull with exposed cyber brain wires)
    add_sphere("HeadCore", radius=0.10, segments=12, rings=8, location=(0, 0.02, 0.02), material=m["flesh_dark"], parent=r["head"])
    add_sphere("BrainGlow", radius=0.06, segments=10, rings=8, location=(-0.03, -0.02, 0.06), material=m["plasma_yellow"], parent=r["head"])

    # Chest: MASSIVE SWOLLEN THERMONUCLEAR CORE
    add_sphere("PlasmaReactorCore", radius=0.15, segments=16, rings=12, location=(0, 0.04, 0.08), material=m["plasma_yellow"], parent=r["chest"])
    # Restraining steel cage brackets
    add_torus("ReactorCage1", major_radius=0.16, minor_radius=0.016, location=(0, 0.04, 0.08), rotation=(math.radians(90), 0, 0), material=m["steel"], parent=r["chest"])
    add_torus("ReactorCage2", major_radius=0.16, minor_radius=0.016, location=(0, 0.04, 0.08), rotation=(0, math.radians(90), 0), material=m["armor"], parent=r["chest"])
    # 4 Volatile fuel canisters attached around torso
    for idx, (cx, cy) in enumerate([(-0.14, 0.08), (0.14, 0.08), (-0.12, -0.08), (0.12, -0.08)]):
        add_cylinder(f"FuelCell_{idx}", radius=0.028, depth=0.20, segments=8, location=(cx, cy, 0.08), material=m["plasma_yellow"], parent=r["chest"])

    # Pelvis & Limbs
    add_cube("PelvisCore", size=(0.18, 0.12, 0.08), location=(0,0,-0.02), material=m["armor"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.032, depth=0.28, segments=8, location=(0,0,-0.15), material=m["steel"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.028, depth=0.26, segments=8, location=(0,0,-0.14), material=m["flesh_dark"], parent=elbow)
        add_sphere(f"ExplosiveHand_{side}", radius=0.045, segments=8, rings=6, location=(0, 0, -0.32), material=m["plasma_yellow"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.052, depth=0.36, segments=8, location=(0,0,-0.20), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.046, depth=0.34, segments=8, location=(0,0,-0.18), material=m["steel"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.08, 0.16, 0.06), location=(0, 0.04, -0.40), material=m["steel"], parent=knee)

    export_glb("cyborg_exploder.glb")

# =========================================================================
# 7. CRAWLER (Low-profile spider/stalker hybrid)
# =========================================================================
def build_crawler():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.85)

    # Flattened predatory skull with quad optic sensors
    add_sphere("HeadCore", radius=0.09, segments=12, rings=8, location=(0, 0.05, 0.0), scale=(1.2, 1.4, 0.6), material=m["flesh_dark"], parent=r["head"])
    for ox, oz in ((-0.04, 0.02), (0.04, 0.02), (-0.02, -0.02), (0.02, -0.02)):
        add_sphere(f"SpiderEye_{ox}_{oz}", radius=0.010, segments=6, rings=4, location=(ox, 0.16, oz), material=m["optic_red"], parent=r["head"])

    # Low hunch torso
    add_cylinder("Spine", radius=0.02, depth=0.30, segments=8, location=(0, -0.04, 0.0), rotation=(math.radians(45), 0, 0), material=m["steel"], parent=r["chest"])
    add_cube("Carapace", size=(0.24, 0.22, 0.10), location=(0, 0.0, 0.04), material=m["armor"], parent=r["chest"])

    # Pelvis
    add_cube("PelvisCore", size=(0.18, 0.12, 0.08), location=(0,0,-0.02), material=m["steel"], parent=r["pelvis"])

    # Elongated Multi-segment Stalker Arms
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.022, depth=0.36, segments=8, location=(0,0,-0.18), material=m["steel"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.018, depth=0.36, segments=8, location=(0,0,-0.18), material=m["chrome"], parent=elbow)
        add_cone(f"SpikeHand_{side}", radius1=0.012, radius2=0.001, depth=0.18, segments=5, location=(0, 0.02, -0.42), rotation=(math.radians(20), 0, 0), material=m["chrome"], parent=elbow)

    # Splayed Spider Legs
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.038, depth=0.36, segments=8, location=(0,0,-0.18), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.030, depth=0.36, segments=8, location=(0,0,-0.18), material=m["steel"], parent=knee)
        add_cone(f"SpikeFoot_{side}", radius1=0.014, radius2=0.001, depth=0.16, segments=5, location=(0, 0.03, -0.42), rotation=(math.radians(20), 0, 0), material=m["steel"], parent=knee)

    export_glb("cyborg_crawler.glb")

# Run all builds!
print("--- BUILDING ALL 7 CYBORG ZOMBIE GLB MODELS ---")
build_walker()
build_runner()
build_brute()
build_spitter()
build_screamer()
build_exploder()
build_crawler()
print("--- ALL 7 MODELS BUILT & EXPORTED SUCCESSFULLY! ---")
