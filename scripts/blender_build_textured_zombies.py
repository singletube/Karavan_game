"""
blender_build_textured_zombies.py
Builds clean, simple, low/mid-poly Cyborg Zombie models with UV unwrapping
and applies the high-resolution generated textures:
- mummy_flesh.png (+ normal & roughness)
- cyber_armor.png (+ normal & roughness)
- desert_rags.png (+ normal & roughness)
- optic_lens.png (with bright emission)
"""

import bpy
import math
import os

PROJECT_DIR = r"c:\Users\user\Documents\идет-караван-из-ирана"
MODELS_DIR = os.path.join(PROJECT_DIR, "models", "zombies")
TEX_DIR = os.path.join(MODELS_DIR, "textures")

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_mat(name, albedo_file=None, normal_file=None, roughness_file=None, metallic=0.0, roughness_val=0.5, is_emission=False, emission_strength=0.0, base_color_fallback=(0.5,0.5,0.5,1.0)):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    nodes.clear()

    output = nodes.new(type='ShaderNodeOutputMaterial')
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness_val
    bsdf.inputs['Base Color'].default_value = base_color_fallback

    if albedo_file:
        alb_path = os.path.join(TEX_DIR, albedo_file)
        if os.path.exists(alb_path):
            tex_node = nodes.new(type='ShaderNodeTexImage')
            tex_node.image = bpy.data.images.load(alb_path)
            mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
            if is_emission:
                mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Emission Color'])
                bsdf.inputs['Emission Strength'].default_value = emission_strength

    if normal_file:
        norm_path = os.path.join(TEX_DIR, normal_file)
        if os.path.exists(norm_path):
            norm_tex = nodes.new(type='ShaderNodeTexImage')
            norm_tex.image = bpy.data.images.load(norm_path)
            norm_tex.image.colorspace_settings.name = 'Non-Color'
            norm_node = nodes.new(type='ShaderNodeNormalMap')
            mat.node_tree.links.new(norm_tex.outputs['Color'], norm_node.inputs['Color'])
            mat.node_tree.links.new(norm_node.outputs['Normal'], bsdf.inputs['Normal'])

    if roughness_file:
        r_path = os.path.join(TEX_DIR, roughness_file)
        if os.path.exists(r_path):
            r_tex = nodes.new(type='ShaderNodeTexImage')
            r_tex.image = bpy.data.images.load(r_path)
            r_tex.image.colorspace_settings.name = 'Non-Color'
            mat.node_tree.links.new(r_tex.outputs['Color'], bsdf.inputs['Roughness'])

    return mat

def get_materials():
    return {
        "mummy": create_pbr_mat("M_MummyFlesh", "mummy_flesh.png", "mummy_flesh_normal.png", "mummy_flesh_roughness.png", metallic=0.05, roughness_val=0.85, base_color_fallback=(0.35, 0.28, 0.22, 1.0)),
        "armor": create_pbr_mat("M_CyberArmor", "cyber_armor.png", "cyber_armor_normal.png", "cyber_armor_roughness.png", metallic=0.90, roughness_val=0.35, base_color_fallback=(0.25, 0.25, 0.27, 1.0)),
        "rags": create_pbr_mat("M_DesertRags", "desert_rags.png", "desert_rags_normal.png", "desert_rags_roughness.png", metallic=0.0, roughness_val=0.95, base_color_fallback=(0.42, 0.36, 0.27, 1.0)),
        "optic": create_pbr_mat("M_OpticLens", "optic_lens.png", None, None, metallic=0.1, roughness_val=0.1, is_emission=True, emission_strength=8.0, base_color_fallback=(1.0, 0.05, 0.02, 1.0)),
        "chrome": create_pbr_mat("M_Chrome", None, None, None, metallic=0.98, roughness_val=0.12, base_color_fallback=(0.85, 0.88, 0.90, 1.0))
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

def setup_mesh_obj(obj, name, material=None, parent=None, location=(0,0,0), rotation=(0,0,0), scale=(1,1,1)):
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
    # Smart UV Project for seamless texture mapping
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    except:
        pass
    return obj

def add_cube(name, size=(0.1, 0.1, 0.1), location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    return setup_mesh_obj(bpy.context.active_object, name, material, parent, location, rotation, scale=size)

def add_cylinder(name, radius=0.02, depth=0.2, segments=12, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=segments)
    return setup_mesh_obj(bpy.context.active_object, name, material, parent, location, rotation)

def add_sphere(name, radius=0.05, segments=14, rings=10, location=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings)
    return setup_mesh_obj(bpy.context.active_object, name, material, parent, location, scale=scale)

def add_cone(name, radius1=0.02, radius2=0.001, depth=0.1, segments=8, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cone_add(radius1=radius1, radius2=radius2, depth=depth, vertices=segments)
    return setup_mesh_obj(bpy.context.active_object, name, material, parent, location, rotation)

def add_torus(name, major_radius=0.1, minor_radius=0.02, location=(0,0,0), rotation=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius, major_segments=14, minor_segments=8)
    return setup_mesh_obj(bpy.context.active_object, name, material, parent, location, rotation, scale=scale)

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
# 1. TEXTURED WALKER (Simple, clean, cohesive low/mid-poly silhouette with rich textures)
# =========================================================================
def build_textured_walker():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.0)

    # HEAD:
    # 1. Stylized cranium with textured mummy flesh
    add_sphere("Head_Cranium", radius=0.12, segments=16, rings=12, location=(0.01, 0.0, 0.02), scale=(0.95, 1.15, 1.1), material=m["mummy"], parent=r["head"])
    # 2. Open jaw with mummy flesh / bone texture
    add_cube("Head_Jaw", size=(0.10, 0.12, 0.05), location=(0.0, 0.065, -0.08), rotation=(math.radians(16), 0, 0), material=m["mummy"], parent=r["head"])
    # 3. Bolted cybernetic steel half-plate with cyber armor texture
    add_cube("Head_CyberPlate", size=(0.09, 0.14, 0.15), location=(-0.055, 0.02, 0.04), rotation=(0, math.radians(-10), math.radians(10)), material=m["armor"], parent=r["head"])
    # 4. Glowing red ocular sensor lens
    add_cylinder("Head_OpticHousing", radius=0.026, depth=0.025, segments=14, location=(-0.045, 0.095, 0.012), rotation=(math.radians(90), 0, math.radians(-12)), material=m["armor"], parent=r["head"])
    add_sphere("Head_OpticLens", radius=0.016, segments=12, rings=8, location=(-0.045, 0.108, 0.012), material=m["optic"], parent=r["head"])
    # 5. Draped desert cowl / rags around neck
    add_torus("Head_CowlRags", major_radius=0.11, minor_radius=0.035, location=(0, -0.01, -0.11), scale=(1.1, 1.25, 0.7), material=m["rags"], parent=r["head"])

    # CHEST & TORSO:
    # 1. Main athletic skeletal ribcage body with mummy flesh texture
    add_cube("Chest_Body", size=(0.28, 0.18, 0.32), location=(0.0, 0.02, 0.08), material=m["mummy"], parent=r["chest"])
    # 2. Armored cyber-spine and sternum bracket with cyber armor texture
    add_cube("Chest_CyberPlate", size=(0.14, 0.05, 0.28), location=(0.0, 0.11, 0.08), material=m["armor"], parent=r["chest"])
    add_cylinder("Chest_SpineHydraulic", radius=0.022, depth=0.34, segments=10, location=(0.0, -0.095, 0.08), material=m["chrome"], parent=r["chest"])
    # 3. Scavenged desert cloth draped across torso
    add_cube("Chest_RagsDrape", size=(0.20, 0.14, 0.10), location=(0.06, 0.04, 0.19), rotation=(math.radians(14), math.radians(18), math.radians(-12)), material=m["rags"], parent=r["chest"])

    # PELVIS / WAIST:
    # 1. Waist with desert rags & combat cloth texture
    add_cube("Pelvis_Pants", size=(0.24, 0.16, 0.14), location=(0, 0, -0.02), material=m["rags"], parent=r["pelvis"])
    # 2. Heavy tactical belt with armor texture
    add_torus("Pelvis_Belt", major_radius=0.16, minor_radius=0.025, location=(0, 0, 0.04), scale=(0.95, 0.85, 1.0), material=m["armor"], parent=r["pelvis"])
    add_cube("Pelvis_Buckle", size=(0.04, 0.02, 0.035), location=(0.0, 0.145, 0.04), material=m["chrome"], parent=r["pelvis"])
    # 3. Hanging tattered loincloth
    add_cube("Pelvis_Loincloth", size=(0.14, 0.02, 0.22), location=(0.0, 0.11, -0.12), rotation=(math.radians(10), 0, 0), material=m["rags"], parent=r["pelvis"])

    # RIGHT ARM (Heavy cybernetic war arm with cyber armor texture):
    # 1. Shoulder servo & bolted pauldron
    add_sphere("Shoulder_Servo_R", radius=0.055, segments=12, rings=8, location=(0,0,0), material=m["armor"], parent=r["r_shoulder"])
    add_cube("Shoulder_Pauldron_R", size=(0.14, 0.16, 0.11), location=(0.05, 0.0, 0.05), rotation=(0, math.radians(-25), 0), material=m["armor"], parent=r["r_shoulder"])
    # 2. Upper arm hydraulic cyber cylinder
    add_cylinder("Arm_Cyber_R", radius=0.036, depth=0.28, segments=12, location=(0, -0.01, -0.15), material=m["armor"], parent=r["r_shoulder"])
    add_cylinder("Arm_Piston_R", radius=0.016, depth=0.24, segments=8, location=(0.02, 0.02, -0.15), material=m["chrome"], parent=r["r_shoulder"])
    # 3. Forearm with heavy armor plating
    add_cube("Forearm_Armor_R", size=(0.09, 0.10, 0.26), location=(0, 0.015, -0.14), material=m["armor"], parent=r["r_elbow"])
    # 4. Mechanical claw hand with sharp talons
    add_cube("Hand_Palm_R", size=(0.07, 0.045, 0.06), location=(0, 0, -0.30), material=m["armor"], parent=r["r_elbow"])
    for f_idx, fx in enumerate((-0.032, -0.01, 0.012, 0.034)):
        add_cone(f"Talon_R_{f_idx}", radius1=0.010, radius2=0.001, depth=0.12, segments=6, location=(fx * 1.25, 0.035, -0.40), rotation=(math.radians(35), 0, math.radians(fx * 250)), material=m["chrome"], parent=r["r_elbow"])

    # LEFT ARM (Withered mummy arm wrapped in bandages):
    # 1. Upper arm with mummy flesh texture
    add_cylinder("Arm_Mummy_L", radius=0.034, depth=0.28, segments=12, location=(0, 0, -0.15), material=m["mummy"], parent=r["l_shoulder"])
    # 2. Bandage wraps on arm
    add_torus("Arm_Bandage_L", major_radius=0.038, minor_radius=0.012, location=(0, 0, -0.14), material=m["rags"], parent=r["l_shoulder"])
    # 3. Forearm with mummy flesh texture
    add_cylinder("Forearm_Mummy_L", radius=0.028, depth=0.26, segments=12, location=(0, 0, -0.13), material=m["mummy"], parent=r["l_elbow"])
    # 4. Mummy hand with clawed fingers
    add_cube("Hand_Palm_L", size=(0.05, 0.03, 0.05), location=(0, 0, -0.28), material=m["mummy"], parent=r["l_elbow"])
    for f_idx in range(4):
        fx = -0.025 + f_idx * 0.016
        add_cone(f"Claw_L_{f_idx}", radius1=0.008, radius2=0.001, depth=0.10, segments=5, location=(fx, 0.018, -0.34), rotation=(math.radians(28), 0, math.radians(fx * 200)), material=m["mummy"], parent=r["l_elbow"])

    # LEGS (Exoskeleton legs with cyber armor texture & combat boots):
    for side, hip, knee, is_r in (("L", r["l_hip"], r["l_knee"], False), ("R", r["r_hip"], r["r_knee"], True)):
        xm = 1.0 if is_r else -1.0
        # Thigh with cyber armor plate
        add_cylinder(f"Thigh_Core_{side}", radius=0.055, depth=0.36, segments=12, location=(0, 0, -0.20), material=m["rags"], parent=hip)
        add_cube(f"Thigh_Plate_{side}", size=(0.09, 0.04, 0.26), location=(0, 0.045, -0.20), rotation=(math.radians(-5), 0, 0), material=m["armor"], parent=hip)
        # Knee servo
        add_cylinder(f"Knee_Servo_{side}", radius=0.05, depth=0.05, segments=14, location=(0,0,0), rotation=(0, math.radians(90), 0), material=m["armor"], parent=knee)
        # Shin with cyber armor plate
        add_cylinder(f"Shin_Core_{side}", radius=0.048, depth=0.34, segments=12, location=(0, 0, -0.18), material=m["armor"], parent=knee)
        add_cube(f"Shin_Plate_{side}", size=(0.08, 0.035, 0.24), location=(0, 0.042, -0.17), material=m["armor"], parent=knee)
        # Combat cyber boot
        add_cube(f"Boot_Main_{side}", size=(0.09, 0.18, 0.08), location=(0, 0.04, -0.40), material=m["armor"], parent=knee)
        for toe_idx in (-0.025, 0.0, 0.025):
            add_cone(f"Boot_Toe_{side}_{toe_idx}", radius1=0.011, radius2=0.001, depth=0.06, segments=6, location=(toe_idx, 0.14, -0.41), rotation=(math.radians(90), 0, 0), material=m["chrome"], parent=knee)

    export_glb("cyborg_walker.glb")

# =========================================================================
# 2. RUNNER (Textured fast cyber-ghoul)
# =========================================================================
def build_textured_runner():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.92)

    # Head (twin glowing optics, streamlined mummy skull)
    add_sphere("Head_Cranium", radius=0.10, segments=14, rings=10, location=(0, 0.02, 0.02), scale=(0.85, 1.25, 1.0), material=m["mummy"], parent=r["head"])
    add_cube("Head_Plate", size=(0.11, 0.14, 0.07), location=(0, 0.05, 0.04), rotation=(math.radians(20), 0, 0), material=m["armor"], parent=r["head"])
    for eye_x in (-0.035, 0.035):
        add_cylinder(f"Optic_Housing_{eye_x}", radius=0.02, depth=0.02, segments=10, location=(eye_x, 0.10, 0.015), rotation=(math.radians(90), 0, 0), material=m["armor"], parent=r["head"])
        add_sphere(f"Optic_Lens_{eye_x}", radius=0.013, segments=10, rings=8, location=(eye_x, 0.11, 0.015), material=m["optic"], parent=r["head"])

    # Torso & Pelvis
    add_cube("Chest_Body", size=(0.24, 0.15, 0.28), location=(0, 0.02, 0.06), material=m["armor"], parent=r["chest"])
    add_cube("Pelvis_Pants", size=(0.20, 0.13, 0.12), location=(0, 0, -0.02), material=m["rags"], parent=r["pelvis"])

    # Dual Razor Blades on Arms
    for side, shoulder, elbow, is_r in (("L", r["l_shoulder"], r["l_elbow"], False), ("R", r["r_shoulder"], r["r_elbow"], True)):
        xm = 1.0 if is_r else -1.0
        add_cylinder(f"Arm_{side}", radius=0.03, depth=0.28, segments=10, location=(0,0,-0.14), material=m["armor"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.026, depth=0.28, segments=10, location=(0,0,-0.14), material=m["armor"], parent=elbow)
        add_cube(f"Blade_{side}", size=(0.016, 0.07, 0.38), location=(xm * 0.03, 0.04, -0.28), rotation=(math.radians(18), 0, 0), material=m["chrome"], parent=elbow)

    # Sprint Legs
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.048, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.040, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.075, 0.16, 0.06), location=(0, 0.04, -0.38), material=m["armor"], parent=knee)

    export_glb("cyborg_runner.glb")

# =========================================================================
# 3. BRUTE (Textured heavy tank juggernaut)
# =========================================================================
def build_textured_brute():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.25)

    # Armored Juggernaut Head
    add_cube("Head_Helmet", size=(0.22, 0.24, 0.22), location=(0, 0.03, 0.04), material=m["armor"], parent=r["head"])
    add_cube("Head_Visor", size=(0.15, 0.04, 0.04), location=(0, 0.14, 0.03), material=m["optic"], parent=r["head"])

    # Heavy Torso & Pelvis
    add_cube("Chest_Armor", size=(0.46, 0.30, 0.40), location=(0, 0.04, 0.12), material=m["armor"], parent=r["chest"])
    add_cylinder("Exhaust_L", radius=0.042, depth=0.35, segments=10, location=(-0.16, -0.16, 0.24), material=m["armor"], parent=r["chest"])
    add_cylinder("Exhaust_R", radius=0.042, depth=0.35, segments=10, location=(0.16, -0.16, 0.24), material=m["armor"], parent=r["chest"])
    add_cube("Pelvis_Armor", size=(0.36, 0.24, 0.16), location=(0,0,-0.03), material=m["armor"], parent=r["pelvis"])

    # Giant Crusher Fist (Right)
    add_cube("Pauldron_R", size=(0.24, 0.26, 0.18), location=(0.08, 0, 0.08), material=m["armor"], parent=r["r_shoulder"])
    add_cylinder("Arm_R", radius=0.06, depth=0.32, segments=10, location=(0, 0, -0.18), material=m["armor"], parent=r["r_shoulder"])
    add_cube("Crusher_Forearm_R", size=(0.18, 0.18, 0.32), location=(0, 0, -0.22), material=m["armor"], parent=r["r_elbow"])
    add_cube("Crusher_Fist_R", size=(0.20, 0.20, 0.20), location=(0, 0.04, -0.42), material=m["chrome"], parent=r["r_elbow"])

    # Rotating Saw Blade (Left)
    add_cylinder("Arm_L", radius=0.055, depth=0.32, segments=10, location=(0,0,-0.18), material=m["armor"], parent=r["l_shoulder"])
    add_cube("Saw_Mount_L", size=(0.14, 0.14, 0.24), location=(0,0,-0.16), material=m["armor"], parent=r["l_elbow"])
    add_cylinder("Saw_Disc_Brute", radius=0.24, depth=0.025, segments=24, location=(0, 0.06, -0.32), rotation=(0, math.radians(90), 0), material=m["chrome"], parent=r["l_elbow"])

    # Heavy Legs
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.09, depth=0.46, segments=12, location=(0,0,-0.24), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.08, depth=0.46, segments=12, location=(0,0,-0.24), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.16, 0.28, 0.12), location=(0, 0.06, -0.52), material=m["armor"], parent=knee)

    export_glb("cyborg_brute.glb")

# =========================================================================
# 4. SPITTER, SCREAMER, EXPLODER, CRAWLER
# =========================================================================
def build_textured_spitter():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.0)
    add_sphere("Head_Core", radius=0.11, segments=14, rings=10, location=(0,0,0.02), material=m["mummy"], parent=r["head"])
    add_cube("Head_Respirator", size=(0.11, 0.12, 0.09), location=(0, 0.06, -0.04), material=m["armor"], parent=r["head"])
    add_cylinder("Acid_Nozzle", radius=0.026, depth=0.09, segments=12, location=(0, 0.14, -0.05), rotation=(math.radians(90), 0, 0), material=m["chrome"], parent=r["head"])
    add_cube("Chest_Body", size=(0.26, 0.16, 0.30), location=(0, 0.02, 0.08), material=m["mummy"], parent=r["chest"])
    for side_x, name in ((-0.12, "L"), (0.12, "R")):
        add_cylinder(f"AcidTank_{name}", radius=0.048, depth=0.32, segments=12, location=(side_x, -0.10, 0.10), material=m["optic"], parent=r["chest"])
    add_cube("Pelvis_Core", size=(0.20, 0.14, 0.12), location=(0,0,-0.02), material=m["rags"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.032, depth=0.28, segments=10, location=(0,0,-0.15), material=m["mummy"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.028, depth=0.26, segments=10, location=(0,0,-0.14), material=m["armor"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.052, depth=0.36, segments=10, location=(0,0,-0.20), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.045, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.08, 0.16, 0.07), location=(0, 0.04, -0.40), material=m["armor"], parent=knee)
    export_glb("cyborg_spitter.glb")

def build_textured_screamer():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.96)
    add_sphere("Head_Core", radius=0.11, segments=14, rings=10, location=(0, 0.02, 0.02), material=m["mummy"], parent=r["head"])
    add_cone("Disruptor_Dish", radius1=0.26, radius2=0.04, depth=0.07, segments=18, location=(0, -0.06, 0.10), rotation=(math.radians(-90), 0, 0), material=m["armor"], parent=r["head"])
    add_sphere("Disruptor_Core", radius=0.045, segments=12, rings=8, location=(0, -0.04, 0.10), material=m["optic"], parent=r["head"])
    add_cube("Chest_Body", size=(0.24, 0.15, 0.28), location=(0, 0.02, 0.06), material=m["armor"], parent=r["chest"])
    add_cube("Pelvis_Core", size=(0.18, 0.12, 0.10), location=(0,0,-0.02), material=m["rags"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.03, depth=0.28, segments=10, location=(0,0,-0.14), material=m["armor"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.025, depth=0.26, segments=10, location=(0,0,-0.13), material=m["mummy"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.048, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.042, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.08, 0.16, 0.06), location=(0, 0.04, -0.38), material=m["armor"], parent=knee)
    export_glb("cyborg_screamer.glb")

def build_textured_exploder():
    reset_scene()
    m = get_materials()
    r = build_base_rig(1.05)
    add_sphere("Head_Core", radius=0.11, segments=14, rings=10, location=(0, 0.02, 0.02), material=m["mummy"], parent=r["head"])
    add_sphere("Chest_ReactorCore", radius=0.18, segments=18, rings=14, location=(0, 0.04, 0.08), material=m["optic"], parent=r["chest"])
    add_torus("Reactor_Cage1", major_radius=0.19, minor_radius=0.018, location=(0, 0.04, 0.08), rotation=(math.radians(90), 0, 0), material=m["armor"], parent=r["chest"])
    add_cube("Pelvis_Core", size=(0.24, 0.16, 0.12), location=(0,0,-0.02), material=m["armor"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.036, depth=0.28, segments=10, location=(0,0,-0.15), material=m["armor"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.032, depth=0.26, segments=10, location=(0,0,-0.14), material=m["mummy"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.056, depth=0.36, segments=10, location=(0,0,-0.20), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.050, depth=0.34, segments=10, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cube(f"Boot_{side}", size=(0.09, 0.17, 0.07), location=(0, 0.04, -0.40), material=m["armor"], parent=knee)
    export_glb("cyborg_exploder.glb")

def build_textured_crawler():
    reset_scene()
    m = get_materials()
    r = build_base_rig(0.85)
    add_sphere("Head_Core", radius=0.10, segments=14, rings=10, location=(0, 0.05, 0.0), scale=(1.2, 1.4, 0.6), material=m["mummy"], parent=r["head"])
    add_sphere("Spider_Eye_L", radius=0.015, segments=8, rings=6, location=(-0.04, 0.16, 0.01), material=m["optic"], parent=r["head"])
    add_sphere("Spider_Eye_R", radius=0.015, segments=8, rings=6, location=(0.04, 0.16, 0.01), material=m["optic"], parent=r["head"])
    add_cube("Chest_Carapace", size=(0.28, 0.24, 0.12), location=(0, 0.0, 0.04), material=m["armor"], parent=r["chest"])
    add_cube("Pelvis_Core", size=(0.20, 0.14, 0.10), location=(0,0,-0.02), material=m["armor"], parent=r["pelvis"])
    for side, shoulder, elbow in (("L", r["l_shoulder"], r["l_elbow"]), ("R", r["r_shoulder"], r["r_elbow"])):
        add_cylinder(f"Arm_{side}", radius=0.026, depth=0.36, segments=10, location=(0,0,-0.18), material=m["armor"], parent=shoulder)
        add_cylinder(f"Forearm_{side}", radius=0.022, depth=0.36, segments=10, location=(0,0,-0.18), material=m["chrome"], parent=elbow)
        add_cone(f"Spike_{side}", radius1=0.014, radius2=0.001, depth=0.20, segments=6, location=(0, 0.02, -0.42), rotation=(math.radians(20), 0, 0), material=m["chrome"], parent=elbow)
    for side, hip, knee in (("L", r["l_hip"], r["l_knee"]), ("R", r["r_hip"], r["r_knee"])):
        add_cylinder(f"Thigh_{side}", radius=0.042, depth=0.36, segments=10, location=(0,0,-0.18), material=m["armor"], parent=hip)
        add_cylinder(f"Shin_{side}", radius=0.035, depth=0.36, segments=10, location=(0,0,-0.18), material=m["armor"], parent=knee)
        add_cone(f"SpikeFoot_{side}", radius1=0.016, radius2=0.001, depth=0.18, segments=6, location=(0, 0.03, -0.42), rotation=(math.radians(20), 0, 0), material=m["chrome"], parent=knee)
    export_glb("cyborg_crawler.glb")

print("--- BUILDING ALL 7 TEXTURED CYBORG ZOMBIES IN BLENDER ---")
build_textured_walker()
build_textured_runner()
build_textured_brute()
build_textured_spitter()
build_textured_screamer()
build_textured_exploder()
build_textured_crawler()
print("--- ALL 7 TEXTURED MODELS BUILT SUCCESSFULLY ---")
