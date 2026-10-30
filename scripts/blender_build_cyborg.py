"""
blender_build_cyborg.py
Builds a realistic post-apocalyptic Cyborg Zombie matching the user's reference image:
- Skeletal mummy anatomy with desiccated flesh and visible ribcage
- Half-skull / half bolted cybernetic steel plate
- Glowing crimson ocular sensor / optic lens
- Bundled red/black wires and hydraulic spine
- Heavy industrial mechanical right arm with hydraulic pistons and 4 steel claw talons
- Withered mummy left arm with ragged bandages and sharp claws
- Combat exoskeleton legs with armored plates, knee servos, and clawed boots
- Tattered desert rags / bandages hanging from neck, shoulder, and waist
- Clean node hierarchy for instant procedural or skeletal animation
"""

import bpy
import math
import os

# 1. Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# 2. Materials
def create_pbr_material(name, base_color, metallic=0.0, roughness=0.5, emission_color=(0,0,0,1), emission_strength=0.0):
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

mat_flesh       = create_pbr_material("Mat_MummyFlesh", (0.35, 0.28, 0.22, 1.0), metallic=0.05, roughness=0.88)
mat_flesh_dark  = create_pbr_material("Mat_MummyDark", (0.20, 0.16, 0.13, 1.0), metallic=0.05, roughness=0.92)
mat_bone        = create_pbr_material("Mat_Bone", (0.68, 0.62, 0.52, 1.0), metallic=0.0, roughness=0.75)
mat_steel       = create_pbr_material("Mat_CyberSteel", (0.22, 0.23, 0.25, 1.0), metallic=0.92, roughness=0.32)
mat_armor       = create_pbr_material("Mat_CyberArmor", (0.28, 0.27, 0.26, 1.0), metallic=0.85, roughness=0.45)
mat_chrome      = create_pbr_material("Mat_ChromeHydraulics", (0.85, 0.88, 0.90, 1.0), metallic=0.98, roughness=0.12)
mat_rags        = create_pbr_material("Mat_DesertRags", (0.42, 0.36, 0.27, 1.0), metallic=0.0, roughness=0.95)
mat_wire_red    = create_pbr_material("Mat_WireRed", (0.65, 0.08, 0.06, 1.0), metallic=0.1, roughness=0.45)
mat_wire_dark   = create_pbr_material("Mat_WireDark", (0.08, 0.08, 0.09, 1.0), metallic=0.2, roughness=0.55)
mat_optic_glow  = create_pbr_material("Mat_GlowingOptic", (0.4, 0.0, 0.0, 1.0), metallic=0.1, roughness=0.1, emission_color=(1.0, 0.04, 0.02, 1.0), emission_strength=10.0)
mat_ooze        = create_pbr_material("Mat_GlowingOoze", (0.05, 0.35, 0.1, 1.0), metallic=0.1, roughness=0.2, emission_color=(0.15, 1.0, 0.25, 1.0), emission_strength=6.0)

# 3. Helpers
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
    obj = bpy.context.active_object
    return setup_obj(obj, name, material, parent, location, rotation, scale=size)

def add_cylinder(name, radius=0.02, depth=0.2, segments=8, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=segments)
    obj = bpy.context.active_object
    return setup_obj(obj, name, material, parent, location, rotation)

def add_sphere(name, radius=0.05, segments=12, rings=8, location=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings)
    obj = bpy.context.active_object
    return setup_obj(obj, name, material, parent, location, scale=scale)

def add_cone(name, radius1=0.02, radius2=0.001, depth=0.1, segments=6, location=(0,0,0), rotation=(0,0,0), material=None, parent=None):
    bpy.ops.mesh.primitive_cone_add(radius1=radius1, radius2=radius2, depth=depth, vertices=segments)
    obj = bpy.context.active_object
    return setup_obj(obj, name, material, parent, location, rotation)

def add_torus(name, major_radius=0.1, minor_radius=0.02, location=(0,0,0), rotation=(0,0,0), scale=(1,1,1), material=None, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius, major_segments=12, minor_segments=6)
    obj = bpy.context.active_object
    return setup_obj(obj, name, material, parent, location, rotation, scale=scale)


# =========================================================================
# RIG HIERARCHY (EXACT NODE NAMES COMPATIBLE WITH GODOT ANIMATION)
# =========================================================================
root = create_empty("Root", location=(0,0,0))
pelvis = create_empty("Pelvis", parent=root, location=(0, 0, 0.88))
torso = create_empty("Torso", parent=pelvis, location=(0, 0, 0.12))
chest = create_empty("Chest", parent=torso, location=(0, 0, 0.22))
head = create_empty("Head", parent=chest, location=(0, 0.05, 0.36))

# Arms
l_shoulder = create_empty("L_Shoulder", parent=chest, location=(-0.24, 0.0, 0.22))
l_elbow = create_empty("L_Elbow", parent=l_shoulder, location=(0.0, 0.0, -0.32))

r_shoulder = create_empty("R_Shoulder", parent=chest, location=(0.25, 0.0, 0.22))
r_elbow = create_empty("R_Elbow", parent=r_shoulder, location=(0.0, 0.0, -0.34))

# Legs
l_hip = create_empty("L_Hip", parent=pelvis, location=(-0.14, 0.0, -0.05))
l_knee = create_empty("L_Knee", parent=l_hip, location=(0.0, 0.0, -0.42))

r_hip = create_empty("R_Hip", parent=pelvis, location=(0.14, 0.0, -0.05))
r_knee = create_empty("R_Knee", parent=r_hip, location=(0.0, 0.0, -0.42))


# =========================================================================
# 1. HEAD (Half Mummy Skull, Bolted Cyber Plate, Glowing Red Optic, Teeth, Wires)
# =========================================================================
# Mummy Cranium
add_sphere("MummyCranium", radius=0.11, segments=16, rings=12, location=(0.01, -0.01, 0.02), scale=(0.95, 1.15, 1.1), material=mat_flesh, parent=head)

# Sunken mummy right temple/cheek
add_sphere("MummyCheek_R", radius=0.06, segments=8, rings=6, location=(0.05, 0.04, -0.04), scale=(0.7, 1.0, 1.2), material=mat_flesh_dark, parent=head)

# Bolted Cybernetic Steel Plate (Left half of skull, forehead & temple)
add_cube("CyberSkullPlate_Main", size=(0.08, 0.13, 0.14), location=(-0.055, 0.02, 0.04), rotation=(0, math.radians(-10), math.radians(10)), material=mat_steel, parent=head)
add_cube("CyberSkullPlate_Temple", size=(0.04, 0.08, 0.09), location=(-0.085, -0.03, 0.01), rotation=(math.radians(15), 0, math.radians(15)), material=mat_armor, parent=head)

# Rivets along the cyber plate
for r_idx in range(5):
    ang = 0.2 + r_idx * 0.35
    rx = -math.sin(ang) * 0.10 - 0.01
    ry = math.cos(ang) * 0.09 + 0.02
    rz = 0.08 - r_idx * 0.03
    add_sphere(f"PlateRivet_{r_idx}", radius=0.008, segments=6, rings=4, location=(rx, ry, rz), material=mat_chrome, parent=head)

# Red Glowing Robotic Eye Housing & Lens (Left Eye)
add_cylinder("OpticHousing", radius=0.024, depth=0.025, segments=12, location=(-0.045, 0.095, 0.012), rotation=(math.radians(90), 0, math.radians(-12)), material=mat_steel, parent=head)
add_sphere("GlowingOpticLens", radius=0.015, segments=10, rings=8, location=(-0.045, 0.106, 0.012), material=mat_optic_glow, parent=head)

# Sunken Mummy Eye Socket (Right Eye)
add_sphere("MummySocket_R", radius=0.016, segments=8, rings=6, location=(0.045, 0.088, 0.012), scale=(1.0, 0.5, 0.9), material=mat_flesh_dark, parent=head)

# Open Snarling Jaw
add_cube("JawBase", size=(0.09, 0.11, 0.04), location=(0.0, 0.065, -0.085), rotation=(math.radians(16), 0, 0), material=mat_bone, parent=head)

# Jagged Individual Teeth
for t_idx in range(6):
    tx = -0.032 + t_idx * 0.013
    ty = 0.115 - abs(tx) * 0.35
    add_cone(f"Tooth_Upper_{t_idx}", radius1=0.005, radius2=0.001, depth=0.018, segments=5, location=(tx, ty, -0.065), rotation=(math.radians(180), 0, 0), material=mat_bone, parent=head)
    add_cone(f"Tooth_Lower_{t_idx}", radius1=0.005, radius2=0.001, depth=0.016, segments=5, location=(tx, ty - 0.01, -0.098), material=mat_bone, parent=head)

# Bundled Red & Dark Wires from Skull into Neck
for w_idx in range(5):
    wx = -0.065 + w_idx * 0.025
    wy = -0.04 - (w_idx % 2) * 0.02
    w_mat = mat_wire_red if w_idx % 2 == 0 else mat_wire_dark
    add_cylinder(f"NeckWire_{w_idx}", radius=0.005, depth=0.18, segments=6, location=(wx, wy, -0.09), rotation=(math.radians(-25), math.radians(12 - w_idx*6), math.radians(-8)), material=w_mat, parent=head)

# Ragged Desert Cowl around neck
add_torus("NeckRagsTorus", major_radius=0.11, minor_radius=0.032, location=(0, -0.01, -0.11), scale=(1.1, 1.25, 0.7), material=mat_rags, parent=head)
add_cube("NeckRagStrip", size=(0.05, 0.012, 0.22), location=(0.04, 0.08, -0.22), rotation=(math.radians(15), math.radians(-10), math.radians(12)), material=mat_rags, parent=head)


# =========================================================================
# 2. CHEST & TORSO (Spine, Ribcage, Thoracic Hydraulics, Core, Scavenged Cloth)
# =========================================================================
# Mechanical Spine Vertebrae
for v_idx in range(5):
    add_cube(f"ChestVertebra_{v_idx}", size=(0.06, 0.045, 0.026), location=(0, -0.07, 0.18 - v_idx * 0.06), material=mat_steel, parent=chest)

# Hydraulic spine column strut
add_cylinder("SpineHydraulic", radius=0.018, depth=0.34, segments=8, location=(0, -0.095, 0.04), material=mat_chrome, parent=chest)

# Anatomical Ribs (5 pairs of curved ribs)
for r_idx in range(5):
    z_pos = 0.16 - r_idx * 0.055
    scale_fac = 1.0 - r_idx * 0.07
    # Left Rib (Bone / mummy)
    add_torus(f"Rib_L_{r_idx}", major_radius=0.11 * scale_fac, minor_radius=0.011, location=(-0.01, 0.01, z_pos), rotation=(math.radians(12), 0, math.radians(-10)), scale=(1.0, 1.1, 0.6), material=mat_bone, parent=chest)
    # Right Rib (Cyber-steel reinforced)
    r_mat = mat_steel if r_idx % 2 == 1 else mat_bone
    add_torus(f"Rib_R_{r_idx}", major_radius=0.11 * scale_fac, minor_radius=0.011, location=(0.01, 0.01, z_pos), rotation=(math.radians(12), 0, math.radians(10)), scale=(1.0, 1.1, 0.6), material=r_mat, parent=chest)

# Sternum
add_cube("SternumBone", size=(0.03, 0.02, 0.16), location=(0.0, 0.115, 0.06), material=mat_bone, parent=chest)

# Internal Thoracic Core / Mutagen Canister (Green Ooze glow)
add_cylinder("ThoracicCore", radius=0.034, depth=0.12, segments=8, location=(-0.02, 0.025, 0.06), material=mat_ooze, parent=chest)

# Thoracic Cables inside ribcage
for c_idx in range(4):
    cx = -0.06 + c_idx * 0.04
    cy = 0.02 - (c_idx % 2) * 0.03
    c_mat = mat_wire_dark if c_idx % 2 == 0 else mat_wire_red
    add_cylinder(f"ThoracicCable_{c_idx}", radius=0.007, depth=0.22, segments=6, location=(cx, cy, 0.04), rotation=(math.radians(15 - c_idx*8), math.radians(c_idx*6), 0), material=c_mat, parent=chest)

# Scavenged Desert Cloth / Rags draped over right shoulder and chest
add_cube("ChestCloth_Drape", size=(0.18, 0.13, 0.07), location=(0.06, 0.04, 0.19), rotation=(math.radians(14), math.radians(18), math.radians(-12)), material=mat_rags, parent=chest)
for s_idx in range(3):
    add_cube(f"ChestCloth_Tatter_{s_idx}", size=(0.04, 0.009, 0.18), location=(-0.05 + s_idx*0.06, 0.12 - s_idx*0.015, -0.06 - s_idx*0.04), rotation=(math.radians(14), math.radians(8 - s_idx*8), math.radians(-5 + s_idx*5)), material=mat_rags, parent=chest)


# =========================================================================
# 3. PELVIS & WAIST (Tactical Belt, Pouches, Shredded Fabric)
# =========================================================================
for v_idx in range(3):
    add_cube(f"LumbarVertebra_{v_idx}", size=(0.06, 0.045, 0.026), location=(0, -0.065, 0.08 - v_idx * 0.05), material=mat_steel, parent=pelvis)

add_cube("PelvisCore", size=(0.16, 0.10, 0.08), location=(0, 0, -0.02), material=mat_flesh_dark, parent=pelvis)
add_torus("TacticalBelt", major_radius=0.17, minor_radius=0.025, location=(0, 0, 0.04), scale=(0.9, 0.8, 1.0), material=mat_steel, parent=pelvis)
add_cube("BeltBuckle", size=(0.035, 0.018, 0.03), location=(0.0, 0.145, 0.04), material=mat_chrome, parent=pelvis)

for p_idx in (-1, 1):
    add_cube(f"BeltPouch_{p_idx}", size=(0.05, 0.035, 0.055), location=(p_idx * 0.15, 0.04, 0.03), rotation=(0, 0, math.radians(p_idx * 15)), material=mat_rags, parent=pelvis)

for t_idx in range(4):
    add_cube(f"WaistTatter_{t_idx}", size=(0.04, 0.008, 0.18), location=(-0.09 + t_idx*0.06, 0.13 - abs(t_idx-1.5)*0.02, -0.12), rotation=(math.radians(12), math.radians(t_idx*4 - 6), 0), material=mat_rags, parent=pelvis)


# =========================================================================
# 4. RIGHT ARM - HEAVY CYBERNETIC WAR ARM (Hydraulics, Pauldron, Steel Claws)
# =========================================================================
# Shoulder Servo
add_sphere("ShoulderServo_R", radius=0.048, segments=10, rings=8, location=(0,0,0), material=mat_steel, parent=r_shoulder)

# Bolted Shoulder Pauldron (Angular combat armor)
add_cube("PauldronArmor_R", size=(0.11, 0.13, 0.08), location=(0.05, 0.0, 0.05), rotation=(0, math.radians(-25), 0), material=mat_armor, parent=r_shoulder)
for b_idx in range(3):
    add_cylinder(f"PauldronBolt_{b_idx}", radius=0.007, depth=0.016, segments=6, location=(0.10, -0.06 + b_idx*0.06, 0.06), rotation=(0, math.radians(65), 0), material=mat_chrome, parent=r_shoulder)

# Dual Hydraulic Bicep Cylinders (Dark sleeves + polished chrome rods)
for h_idx in (-0.025, 0.025):
    add_cylinder(f"HydraulicSleeve_R_{h_idx}", radius=0.018, depth=0.18, segments=8, location=(h_idx, -0.01, -0.10), material=mat_steel, parent=r_shoulder)
    add_cylinder(f"HydraulicRod_R_{h_idx}", radius=0.011, depth=0.16, segments=8, location=(h_idx, -0.01, -0.22), material=mat_chrome, parent=r_shoulder)

# Heavy flexible power conduit along bicep
for cb_idx in range(2):
    cb_mat = mat_wire_dark if cb_idx == 0 else mat_wire_red
    add_cylinder(f"ArmCable_R_{cb_idx}", radius=0.007, depth=0.28, segments=6, location=(0.04 - cb_idx*0.07, 0.035, -0.16), rotation=(math.radians(-8), math.radians(10 - cb_idx*15), 0), material=cb_mat, parent=r_shoulder)

# --- Forearm & Claw Hand (R_Elbow) ---
# Elbow Hinge Servo Disc
add_cylinder("ElbowHinge_R", radius=0.042, depth=0.045, segments=12, location=(0,0,0), rotation=(0, math.radians(90), 0), material=mat_steel, parent=r_elbow)

# Heavy Armored Forearm Plates
add_cube("ForearmArmor_R", size=(0.065, 0.075, 0.22), location=(0, 0.015, -0.14), material=mat_armor, parent=r_elbow)
add_cylinder("ForearmPiston_R", radius=0.009, depth=0.22, segments=6, location=(0.035, -0.028, -0.14), material=mat_chrome, parent=r_elbow)

# Wrist Rotary Servo Collar
add_cylinder("WristServo_R", radius=0.036, depth=0.035, segments=10, location=(0, 0, -0.27), material=mat_steel, parent=r_elbow)
add_cube("Palm_R", size=(0.055, 0.032, 0.05), location=(0, 0, -0.32), material=mat_steel, parent=r_elbow)

# 4 Segmented Razor-Sharp Steel Claw Talons (Curved blades)
claw_angles = (-0.032, -0.01, 0.012, 0.034)
for f_idx, fx in enumerate(claw_angles):
    add_cylinder(f"Knuckle_R_{f_idx}", radius=0.007, depth=0.04, segments=6, location=(fx, 0.01, -0.36), rotation=(math.radians(18), 0, math.radians(fx * 200)), material=mat_steel, parent=r_elbow)
    add_cone(f"ClawTalon_R_{f_idx}", radius1=0.009, radius2=0.001, depth=0.10, segments=6, location=(fx * 1.25, 0.035, -0.42), rotation=(math.radians(35), 0, math.radians(fx * 300)), material=mat_chrome, parent=r_elbow)

# Thumb Talon
add_cone("ThumbClaw_R", radius1=0.010, radius2=0.001, depth=0.08, segments=6, location=(-0.048, -0.02, -0.36), rotation=(math.radians(15), math.radians(40), math.radians(-30)), material=mat_chrome, parent=r_elbow)


# =========================================================================
# 5. LEFT ARM - DESICCATED MUMMY HYBRID ARM (Thin bone, bandages, claws)
# =========================================================================
add_sphere("ShoulderJoint_L", radius=0.042, segments=8, rings=8, location=(0,0,0), material=mat_flesh_dark, parent=l_shoulder)
add_cylinder("UpperArm_L", radius=0.026, depth=0.28, segments=8, location=(0, 0, -0.15), material=mat_flesh, parent=l_shoulder)

for b_idx in range(3):
    add_torus(f"Bandage_L_{b_idx}", major_radius=0.030, minor_radius=0.009, location=(0, 0, -0.09 - b_idx*0.07), rotation=(math.radians(b_idx * 15 - 10), math.radians(b_idx * 12), 0), material=mat_rags, parent=l_shoulder)

add_cylinder("ArmBrace_L", radius=0.006, depth=0.26, segments=6, location=(0.0, -0.028, -0.15), material=mat_steel, parent=l_shoulder)

# --- Forearm & Mummy Claw (L_Elbow) ---
add_sphere("ElbowJoint_L", radius=0.030, segments=8, rings=6, location=(0,0,0), material=mat_bone, parent=l_elbow)
add_cylinder("Forearm_L", radius=0.022, depth=0.26, segments=8, location=(0, 0, -0.13), material=mat_flesh, parent=l_elbow)

for b_idx in range(3):
    add_torus(f"FaBandage_L_{b_idx}", major_radius=0.025, minor_radius=0.008, location=(0, 0, -0.07 - b_idx*0.06), material=mat_rags, parent=l_elbow)

add_cube("DanglingRag_L", size=(0.02, 0.008, 0.16), location=(-0.02, -0.015, -0.22), rotation=(math.radians(-15), math.radians(-12), math.radians(20)), material=mat_rags, parent=l_elbow)
add_cube("Palm_L", size=(0.04, 0.022, 0.04), location=(0, 0, -0.28), material=mat_flesh_dark, parent=l_elbow)

# 4 Mummy Claw Fingers
for f_idx in range(4):
    fx = -0.025 + f_idx * 0.016
    add_cone(f"MummyClaw_L_{f_idx}", radius1=0.007, radius2=0.001, depth=0.09, segments=5, location=(fx, 0.018, -0.34), rotation=(math.radians(28), 0, math.radians(fx * 250)), material=mat_bone, parent=l_elbow)


# =========================================================================
# 6. LEGS - COMBAT EXOSKELETON LEGS (Armor Plates, Servos, Pistons, Boots)
# =========================================================================
def build_leg(side_name, hip_node, knee_node, is_right=False):
    x_mult = 1.0 if is_right else -1.0
    
    # --- THIGH (hip_node) ---
    add_sphere(f"HipServo_{side_name}", radius=0.048, segments=8, rings=8, location=(0,0,0), material=mat_steel, parent=hip_node)
    add_cylinder(f"ThighCore_{side_name}", radius=0.05, depth=0.36, segments=10, location=(0, 0, -0.20), material=mat_rags, parent=hip_node)
    
    # Curved Front Armor Plate
    add_cube(f"ThighArmor_{side_name}", size=(0.08, 0.03, 0.22), location=(0, 0.05, -0.20), rotation=(math.radians(-5), 0, 0), material=mat_armor, parent=hip_node)
    add_cube(f"ThighSidePlate_{side_name}", size=(0.025, 0.065, 0.18), location=(x_mult * 0.055, 0.0, -0.20), material=mat_steel, parent=hip_node)
    add_cylinder(f"ThighPiston_{side_name}", radius=0.013, depth=0.28, segments=6, location=(0, -0.055, -0.20), material=mat_chrome, parent=hip_node)

    # --- SHIN & BOOT (knee_node) ---
    add_cylinder(f"KneeServo_{side_name}", radius=0.048, depth=0.045, segments=12, location=(0,0,0), rotation=(0, math.radians(90), 0), material=mat_steel, parent=knee_node)
    add_cube(f"KneeCap_{side_name}", size=(0.06, 0.035, 0.07), location=(0, 0.048, 0.01), material=mat_armor, parent=knee_node)
    
    add_cylinder(f"ShinCore_{side_name}", radius=0.042, depth=0.34, segments=8, location=(0, 0, -0.18), material=mat_steel, parent=knee_node)
    add_cube(f"ShinArmor_{side_name}", size=(0.065, 0.026, 0.22), location=(0, 0.046, -0.17), material=mat_armor, parent=knee_node)
    add_cylinder(f"ExoStrut_{side_name}", radius=0.010, depth=0.32, segments=6, location=(x_mult * 0.052, 0.0, -0.18), material=mat_chrome, parent=knee_node)

    # Combat Cyber Boot
    add_cylinder(f"Ankle_{side_name}", radius=0.036, depth=0.04, segments=8, location=(0, 0, -0.36), rotation=(0, math.radians(90), 0), material=mat_steel, parent=knee_node)
    add_cube(f"Boot_{side_name}", size=(0.075, 0.16, 0.06), location=(0, 0.04, -0.40), material=mat_armor, parent=knee_node)
    
    for toe_idx in (-0.025, 0.0, 0.025):
        add_cone(f"BootClaw_{side_name}_{toe_idx}", radius1=0.009, radius2=0.001, depth=0.05, segments=5, location=(toe_idx, 0.13, -0.41), rotation=(math.radians(90), 0, 0), material=mat_steel, parent=knee_node)
    
    add_cylinder(f"HeelPiston_{side_name}", radius=0.011, depth=0.08, segments=6, location=(0, -0.065, -0.37), material=mat_chrome, parent=knee_node)

build_leg("L", l_hip, l_knee, is_right=False)
build_leg("R", r_hip, r_knee, is_right=True)

print("CYBORG ZOMBIE MODEL BUILT SUCCESSFULLY!")

# Export to GLB
export_path = r"c:\Users\user\Documents\идет-караван-из-ирана\models\zombies\cyborg_walker.glb"
print(f"Exporting to: {export_path}")
bpy.ops.export_scene.gltf(
    filepath=export_path,
    export_format='GLB',
    use_selection=False,
    export_apply=False,
    export_yup=True
)
print("GLB EXPORT FINISHED SUCCESSFULLY!")
