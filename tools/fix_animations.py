# -*- coding: utf-8 -*-
"""
Fix Animations for Zombie Cyborg Template
Re-generates smooth, expressive keyframed animations for:
- Idle (breathing torso, head tilt/twitch, organic idle sway)
- Walk (heavy asymmetric predator march, swinging cyber-claws, foot plant)
- Run (fast forward-hunched stalker sprint, rapid limb cycle)
- Attack (ferocious windup and cyber-blade downward cleave / slash)
- Hit (torso recoil, flinch, head snapback)
- Death (dramatic stagger and collapse to ground)
- Roar (screamer acoustic siren scream / chest flare)
Bakes all keyframes at 30 fps directly into glTF so Godot 4 plays them smoothly.
"""

import bpy
import math
import os
import shutil
from mathutils import Vector, Matrix, Euler

TEMPLATE_BLEND = r"C:\Users\user\ZombieCyborg\zombie_cyborg_template.blend"
OUT_GLB_1      = r"C:\Users\user\ZombieCyborg\zombie_cyborg_template.glb"
OUT_GLB_2      = r"c:\Users\user\Documents\идет-караван-из-ирана\models\zombies\zombie_cyborg_template.glb"

bpy.ops.wm.open_mainfile(filepath=TEMPLATE_BLEND)
rig = bpy.data.objects.get("ZombieRig")
scene = bpy.context.scene

print("ZombieRig found:", rig.name)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')

# Precalculate bone rest matrix in armature space
BONE_REST_MAT = {pb.name: (rig.matrix_world @ pb.bone.matrix_local).to_3x3() for pb in rig.pose.bones}

# Clear any previous actions and NLA tracks to start completely fresh
if rig.animation_data:
    while rig.animation_data.nla_tracks:
        rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks[0])
    rig.animation_data.action = None

for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'

def reset_pose():
    for pb in rig.pose.bones:
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)

def set_bone_world_pose(pb_name, rx=0.0, ry=0.0, rz=0.0, loc=None):
    if pb_name not in rig.pose.bones:
        return
    pb = rig.pose.bones[pb_name]
    R_w = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_matrix().to_3x3()
    R_b = BONE_REST_MAT[pb_name]
    pb.rotation_euler = (R_b.inverted() @ R_w @ R_b).to_euler('XYZ')
    if loc is not None:
        pb.location = (R_b.inverted() @ Vector(loc))
    else:
        pb.location = (0.0, 0.0, 0.0)

def key_all_bones(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        pb.keyframe_insert(data_path="location", frame=frame)

# -------------------------------------------------------------------------
# 1. IDLE (72 frames, 2.4s loop @ 30fps)
# -------------------------------------------------------------------------
print("Building Idle...")
act_idle = bpy.data.actions.new("Idle")
rig.animation_data_create()
rig.animation_data.action = act_idle
act_idle.use_fake_user = True

for f, ph in [(1, 0.0), (19, 0.5 * math.pi), (37, math.pi), (55, 1.5 * math.pi), (72, 2.0 * math.pi)]:
    reset_pose()
    s1, c1 = math.sin(ph), math.cos(ph)
    # Hips slight sway and breathe
    set_bone_world_pose("Hips", rx=4.0 + 2.0 * s1, ry=3.0 * c1, rz=2.5 * s1, loc=(0.015 * c1, 0.0, -0.015 + 0.012 * s1))
    set_bone_world_pose("Spine", rx=8.0 + 3.0 * s1, ry=-2.5 * c1, rz=-2.5 * s1)
    set_bone_world_pose("Chest", rx=6.0 + 4.5 * s1, ry=2.0 * s1, rz=3.5 * c1)
    set_bone_world_pose("Neck", rx=-5.0 + 3.0 * c1, ry=4.5 * s1, rz=-5.0 * s1)
    set_bone_world_pose("Head", rx=-6.0 - 4.0 * s1, ry=-7.0 * c1, rz=9.0 * s1)
    set_bone_world_pose("Jaw", rx=-8.0 - 8.0 * max(0.0, s1))
    # Left cyber-arm holding blade ready
    set_bone_world_pose("Clavicle.L", rx=2.0, ry=-3.0, rz=2.0)
    set_bone_world_pose("UpperArm.L", rx=16.0 + 5.0 * s1, ry=6.0, rz=-10.0)
    set_bone_world_pose("Forearm.L", rx=32.0 + 8.0 * c1, ry=0.0, rz=-12.0)
    # Right arm loose
    set_bone_world_pose("Clavicle.R", rx=2.0, ry=3.0, rz=-2.0)
    set_bone_world_pose("UpperArm.R", rx=10.0 - 4.0 * s1, ry=-5.0, rz=8.0)
    set_bone_world_pose("Forearm.R", rx=22.0 - 5.0 * c1, ry=0.0, rz=10.0)
    # Legs grounded
    set_bone_world_pose("Thigh.L", rx=10.0 - 2.0 * s1, rz=2.0)
    set_bone_world_pose("Shin.L", rx=-16.0 + 3.0 * s1)
    set_bone_world_pose("Foot.L", rx=6.0 - 1.0 * s1)
    set_bone_world_pose("Thigh.R", rx=6.0 + 2.0 * s1, rz=-2.0)
    set_bone_world_pose("Shin.R", rx=-12.0 - 3.0 * s1)
    set_bone_world_pose("Foot.R", rx=6.0 + 1.0 * s1)
    key_all_bones(f)

# -------------------------------------------------------------------------
# 2. WALK (36 frames, 1.2s loop @ 30fps) - Heavy stalking zombie march
# -------------------------------------------------------------------------
print("Building Walk...")
act_walk = bpy.data.actions.new("Walk")
rig.animation_data.action = act_walk
act_walk.use_fake_user = True

walk_frames = [
    # f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar
    (1,   32, -14,  10, -26, -22, -12, -0.030,  5.0, 16, -12, -22,  30),
    (10,   6, -20,   0,   8, -52, -18, -0.065,  2.5, 20,  -4,   4,   8),
    (19, -28, -26, -14,  36, -12,  12, -0.025, -5.0, 15,  12,  30, -22),
    (28,  10, -56, -20,   6, -20,   0, -0.055, -2.5, 19,   5,   6,   5),
    (36,  32, -14,  10, -26, -22, -12, -0.030,  5.0, 16, -12, -22,  30),
]

for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in walk_frames:
    reset_pose()
    set_bone_world_pose("Hips", rx=10.0, ry=hroll, rz=-crz * 0.7, loc=(hroll * 0.005, 0.0, hz))
    set_bone_world_pose("Spine", rx=srx, ry=-hroll * 0.7, rz=crz * 0.6)
    set_bone_world_pose("Chest", rx=12.0, ry=-hroll * 0.5, rz=crz)
    set_bone_world_pose("Neck", rx=-10.0, ry=hroll * 0.9, rz=-crz * 0.6)
    set_bone_world_pose("Head", rx=-8.0, ry=-hroll * 1.3, rz=-crz * 0.5)
    set_bone_world_pose("Jaw", rx=-12.0 if f in (10, 28) else -6.0)
    # Left cyber-arm blade swing
    set_bone_world_pose("Clavicle.L", rx=4.0, ry=-4.0, rz=3.0)
    set_bone_world_pose("UpperArm.L", rx=18.0 + al, ry=8.0, rz=-12.0)
    set_bone_world_pose("Forearm.L", rx=36.0 + max(0.0, al * 0.7), ry=0.0, rz=-14.0)
    # Right arm swing
    set_bone_world_pose("Clavicle.R", rx=4.0, ry=4.0, rz=-3.0)
    set_bone_world_pose("UpperArm.R", rx=16.0 + ar, ry=-8.0, rz=10.0)
    set_bone_world_pose("Forearm.R", rx=28.0 + max(0.0, ar * 0.7), ry=0.0, rz=10.0)
    # Legs
    set_bone_world_pose("Thigh.L", rx=lt)
    set_bone_world_pose("Shin.L", rx=ls)
    set_bone_world_pose("Foot.L", rx=lf)
    set_bone_world_pose("Thigh.R", rx=rt)
    set_bone_world_pose("Shin.R", rx=rs)
    set_bone_world_pose("Foot.R", rx=rf)
    key_all_bones(f)

# -------------------------------------------------------------------------
# 3. RUN (20 frames, 0.66s loop @ 30fps) - Aggressive stalker sprint
# -------------------------------------------------------------------------
print("Building Run...")
act_run = bpy.data.actions.new("Run")
rig.animation_data.action = act_run
act_run.use_fake_user = True

run_frames = [
    (1,   48, -22,  14, -40, -32, -18, -0.045,  6.0, 24, -16, -34,  44),
    (6,    8, -28,   0,  16, -70, -25,  0.025,  2.0, 28,  -5,   6,  10),
    (11, -40, -34, -18,  50, -20,  16, -0.045, -6.0, 24,  16,  44, -34),
    (16,  16, -72, -25,   8, -28,   0,  0.025, -2.0, 28,   5,  10,   6),
    (20,  48, -22,  14, -40, -32, -18, -0.045,  6.0, 24, -16, -34,  44),
]

for (f, lt, ls, lf, rt, rs, rf, hz, hroll, srx, crz, al, ar) in run_frames:
    reset_pose()
    set_bone_world_pose("Hips", rx=18.0, ry=hroll, rz=-crz * 0.6, loc=(hroll * 0.005, 0.0, hz))
    set_bone_world_pose("Spine", rx=srx, ry=-hroll * 0.6, rz=crz * 0.6)
    set_bone_world_pose("Chest", rx=18.0, ry=0.0, rz=crz)
    set_bone_world_pose("Neck", rx=-16.0, ry=0.0, rz=-crz * 0.6)
    set_bone_world_pose("Head", rx=-14.0, ry=hroll, rz=-crz * 0.5)
    set_bone_world_pose("Jaw", rx=-18.0)
    set_bone_world_pose("UpperArm.L", rx=28.0 + al, ry=10.0, rz=-14.0)
    set_bone_world_pose("Forearm.L", rx=48.0 + max(0.0, al * 0.6), ry=0.0, rz=-16.0)
    set_bone_world_pose("UpperArm.R", rx=26.0 + ar, ry=-10.0, rz=12.0)
    set_bone_world_pose("Forearm.R", rx=44.0 + max(0.0, ar * 0.6), ry=0.0, rz=14.0)
    set_bone_world_pose("Thigh.L", rx=lt)
    set_bone_world_pose("Shin.L", rx=ls)
    set_bone_world_pose("Foot.L", rx=lf)
    set_bone_world_pose("Thigh.R", rx=rt)
    set_bone_world_pose("Shin.R", rx=rs)
    set_bone_world_pose("Foot.R", rx=rf)
    key_all_bones(f)

# -------------------------------------------------------------------------
# 4. ATTACK (28 frames, 0.93s @ 30fps) - Windup & vicious cleave
# -------------------------------------------------------------------------
print("Building Attack...")
act_atk = bpy.data.actions.new("Attack")
rig.animation_data.action = act_atk
act_atk.use_fake_user = True

# Frame 1: Base stance
reset_pose()
set_bone_world_pose("Hips", rx=8.0, rz=-5.0, loc=(0.0, 0.0, -0.01))
set_bone_world_pose("Spine", rx=10.0); set_bone_world_pose("Chest", rx=8.0)
key_all_bones(1)

# Frame 8: Massive windup back with raised blade arm
reset_pose()
set_bone_world_pose("Hips", rx=-6.0, rz=-22.0, loc=(0.0, 0.04, -0.02))
set_bone_world_pose("Spine", rx=-10.0, rz=-26.0); set_bone_world_pose("Chest", rx=-12.0, rz=-32.0)
set_bone_world_pose("Head", rx=-14.0, rz=26.0); set_bone_world_pose("Jaw", rx=-28.0)
set_bone_world_pose("UpperArm.L", rx=95.0, ry=32.0, rz=-42.0); set_bone_world_pose("Forearm.L", rx=65.0, rz=-25.0)
set_bone_world_pose("UpperArm.R", rx=-22.0, ry=-18.0, rz=18.0)
set_bone_world_pose("Thigh.L", rx=-15.0); set_bone_world_pose("Thigh.R", rx=20.0)
key_all_bones(8)

# Frame 14: Downward brutal cleave impact!
reset_pose()
set_bone_world_pose("Hips", rx=22.0, rz=26.0, loc=(0.0, -0.08, -0.05))
set_bone_world_pose("Spine", rx=28.0, rz=30.0); set_bone_world_pose("Chest", rx=30.0, rz=36.0)
set_bone_world_pose("Head", rx=-18.0, rz=-28.0); set_bone_world_pose("Jaw", rx=-35.0)
set_bone_world_pose("UpperArm.L", rx=35.0, ry=-28.0, rz=45.0); set_bone_world_pose("Forearm.L", rx=15.0, rz=26.0)
set_bone_world_pose("UpperArm.R", rx=72.0, ry=-24.0, rz=28.0); set_bone_world_pose("Forearm.R", rx=50.0)
set_bone_world_pose("Thigh.L", rx=35.0); set_bone_world_pose("Shin.L", rx=-40.0)
set_bone_world_pose("Thigh.R", rx=-25.0); set_bone_world_pose("Shin.R", rx=-15.0)
key_all_bones(14)

# Frame 20: Follow-through and recovery
reset_pose()
set_bone_world_pose("Hips", rx=16.0, rz=-12.0, loc=(0.0, -0.04, -0.03))
set_bone_world_pose("Spine", rx=18.0, rz=-15.0); set_bone_world_pose("Chest", rx=20.0, rz=-18.0)
set_bone_world_pose("UpperArm.L", rx=-8.0, ry=14.0, rz=-15.0); set_bone_world_pose("Forearm.L", rx=32.0)
set_bone_world_pose("UpperArm.R", rx=38.0, ry=18.0, rz=-28.0); set_bone_world_pose("Forearm.R", rx=20.0)
key_all_bones(20)

# Frame 28: Return to rest
reset_pose()
set_bone_world_pose("Hips", rx=8.0, rz=-5.0, loc=(0.0, 0.0, -0.01))
set_bone_world_pose("Spine", rx=10.0); set_bone_world_pose("Chest", rx=8.0)
key_all_bones(28)

# -------------------------------------------------------------------------
# 5. HIT (18 frames, 0.6s @ 30fps) - Recoil and flinch
# -------------------------------------------------------------------------
print("Building Hit...")
act_hit = bpy.data.actions.new("Hit")
rig.animation_data.action = act_hit
act_hit.use_fake_user = True

reset_pose(); key_all_bones(1)

# Frame 5: Stagger backward
reset_pose()
set_bone_world_pose("Hips", rx=-16.0, ry=-8.0, rz=16.0, loc=(0.03, 0.08, -0.04))
set_bone_world_pose("Spine", rx=-22.0, ry=-10.0, rz=20.0); set_bone_world_pose("Chest", rx=-26.0, ry=-12.0, rz=28.0)
set_bone_world_pose("Head", rx=-32.0, ry=20.0, rz=24.0); set_bone_world_pose("Jaw", rx=-32.0)
set_bone_world_pose("UpperArm.L", rx=-28.0, ry=32.0, rz=-25.0); set_bone_world_pose("Forearm.L", rx=55.0)
set_bone_world_pose("UpperArm.R", rx=-24.0, ry=-30.0, rz=25.0); set_bone_world_pose("Forearm.R", rx=48.0)
key_all_bones(5)

# Frame 11: Counter-balance
reset_pose()
set_bone_world_pose("Hips", rx=12.0, ry=5.0, rz=-10.0, loc=(0.01, 0.02, -0.02))
set_bone_world_pose("Spine", rx=16.0, rz=-8.0); set_bone_world_pose("Chest", rx=14.0, rz=-10.0)
key_all_bones(11)

reset_pose(); key_all_bones(18)

# -------------------------------------------------------------------------
# 6. DEATH (42 frames, 1.4s @ 30fps) - Dramatic crumple to ground
# -------------------------------------------------------------------------
print("Building Death...")
act_death = bpy.data.actions.new("Death")
rig.animation_data.action = act_death
act_death.use_fake_user = True

reset_pose(); key_all_bones(1)

# Frame 8: Fatal shot recoil
reset_pose()
set_bone_world_pose("Hips", rx=-14.0, rz=12.0, loc=(0.0, 0.04, -0.05))
set_bone_world_pose("Spine", rx=-20.0, rz=15.0); set_bone_world_pose("Chest", rx=-26.0, rz=18.0)
set_bone_world_pose("Head", rx=-36.0, ry=18.0, rz=20.0); set_bone_world_pose("Jaw", rx=-38.0)
set_bone_world_pose("UpperArm.L", rx=50.0, ry=38.0, rz=-30.0); set_bone_world_pose("UpperArm.R", rx=45.0, ry=-38.0, rz=30.0)
key_all_bones(8)

# Frame 20: Knees buckle, dropping to ground
reset_pose()
set_bone_world_pose("Hips", rx=32.0, ry=10.0, rz=-14.0, loc=(0.02, -0.06, -0.48))
set_bone_world_pose("Spine", rx=26.0, rz=-12.0); set_bone_world_pose("Chest", rx=30.0, rz=-14.0)
set_bone_world_pose("Thigh.L", rx=58.0); set_bone_world_pose("Shin.L", rx=-120.0); set_bone_world_pose("Foot.L", rx=50.0)
set_bone_world_pose("Thigh.R", rx=54.0); set_bone_world_pose("Shin.R", rx=-115.0); set_bone_world_pose("Foot.R", rx=50.0)
key_all_bones(20)

# Frames 34 & 42: Final flat slump onto ground
for f_end in (34, 42):
    reset_pose()
    set_bone_world_pose("Hips", rx=88.0, ry=20.0, rz=-16.0, loc=(0.05, -0.42, -0.92))
    set_bone_world_pose("Spine", rx=12.0, ry=-10.0, rz=8.0); set_bone_world_pose("Chest", rx=8.0, ry=-8.0, rz=10.0)
    set_bone_world_pose("Head", rx=-26.0, ry=32.0, rz=36.0); set_bone_world_pose("Jaw", rx=-30.0)
    set_bone_world_pose("UpperArm.L", rx=60.0, ry=45.0, rz=-25.0); set_bone_world_pose("UpperArm.R", rx=30.0, ry=-42.0, rz=18.0)
    key_all_bones(f_end)

# -------------------------------------------------------------------------
# 7. ROAR (40 frames, 1.33s @ 30fps) - Chest heave & acoustic siren scream
# -------------------------------------------------------------------------
print("Building Roar...")
act_roar = bpy.data.actions.new("Roar")
rig.animation_data.action = act_roar
act_roar.use_fake_user = True

reset_pose(); key_all_bones(1)

# Frame 8: Inhale / hunch
reset_pose()
set_bone_world_pose("Hips", rx=16.0, loc=(0.0, 0.0, -0.07))
set_bone_world_pose("Spine", rx=20.0); set_bone_world_pose("Chest", rx=24.0)
set_bone_world_pose("UpperArm.L", rx=32.0, ry=-18.0, rz=24.0); set_bone_world_pose("UpperArm.R", rx=32.0, ry=18.0, rz=-24.0)
key_all_bones(8)

# Frames 18, 23, 28: Chest expand and vibrating head shake
for f_r, h_shake in ((18, -16.0), (23, 16.0), (28, -12.0)):
    reset_pose()
    set_bone_world_pose("Hips", rx=-10.0, loc=(0.0, -0.04, 0.02))
    set_bone_world_pose("Spine", rx=-16.0); set_bone_world_pose("Chest", rx=-22.0)
    set_bone_world_pose("Head", rx=-28.0, ry=h_shake * 0.4, rz=h_shake); set_bone_world_pose("Jaw", rx=-42.0)
    set_bone_world_pose("UpperArm.L", rx=-22.0, ry=42.0, rz=-36.0); set_bone_world_pose("UpperArm.R", rx=-22.0, ry=-42.0, rz=36.0)
    key_all_bones(f_r)

reset_pose(); key_all_bones(40)

# Set default active action to Idle
rig.animation_data.action = act_idle
reset_pose()

# Save updated blend file
print("Saving blend file...")
bpy.ops.wm.save_as_mainfile(filepath=TEMPLATE_BLEND)

# Export glTF with FULL ANIMATION BAKING
print("Exporting glTF with export_bake_animation=True...")
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB_1,
    export_format='GLB',
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_bake_animation=True,
    export_optimize_animation_size=False,
    export_apply=False,
    export_yup=True
)

shutil.copy2(OUT_GLB_1, OUT_GLB_2)
print("Successfully copied to:", OUT_GLB_2)
print("ANIMATION FIX COMPLETED SUCCESSFULLY!")
