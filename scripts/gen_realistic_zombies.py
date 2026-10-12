"""
Generator for realistic high-resolution zombie spritesheets (2560x256, 10 frames of 256x256 each).
Uses Pillow with soft gradients, anatomically detailed shapes, realistic color palettes,
muscle/tendon details, realistic blood, bone, rags, shading and specular highlights.
"""

import math
from PIL import Image, ImageDraw, ImageFilter

FRAME_W = 256
FRAME_H = 256
TOTAL_FRAMES = 10
SHEET_W = FRAME_W * TOTAL_FRAMES
SHEET_H = FRAME_H

def smooth_oval(draw, bbox, fill, outline=None, outline_w=1):
    draw.ellipse(bbox, fill=fill, outline=outline, width=outline_w)

def draw_limb_segment(draw, p1, p2, r1, r2, fill, shadow_fill=None):
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = math.hypot(dx, dy)
    if length < 1e-4:
        return
    steps = max(int(length), 2)
    for i in range(steps + 1):
        t = i / steps
        cx = p1[0] + dx * t
        cy = p1[1] + dy * t
        cr = r1 + (r2 - r1) * t
        draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=fill)
        if shadow_fill and cr > 2:
            draw.ellipse([cx - cr * 0.4, cy + cr * 0.2, cx + cr * 0.9, cy + cr * 0.9], fill=shadow_fill)

def render_walker_frame(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # Frame animation parameters
    sway_x = 0
    l_leg_angle = 0
    r_leg_angle = 0
    l_arm_raise = 0
    r_arm_raise = 0
    head_tilt = 0
    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    if f_idx == 1:
        sway_x = -4
        l_leg_angle = 18
        r_leg_angle = -18
        l_arm_raise = -6
        r_arm_raise = 6
    elif f_idx == 2:
        sway_x = -1
        l_leg_angle = 6
        r_leg_angle = -6
    elif f_idx == 3:
        sway_x = 4
        l_leg_angle = -18
        r_leg_angle = 18
        l_arm_raise = 6
        r_arm_raise = -6
    elif f_idx == 4:
        sway_x = 1
        l_leg_angle = -6
        r_leg_angle = 6
    elif f_idx == 5:
        # Attack windup
        l_arm_raise = -35
        r_arm_raise = -30
        head_tilt = -3
    elif f_idx == 6:
        # Attack lunge
        l_arm_raise = 20
        r_arm_raise = 25
        sway_x = 8
    elif is_hurt:
        sway_x = -6
        head_tilt = 8
    elif is_die:
        # Collapsing
        pass
    elif is_dead:
        # On the ground
        pass

    # Palette
    flesh_base = (78, 98, 72, 255)
    flesh_shadow = (42, 56, 38, 255)
    flesh_hl = (112, 134, 102, 255)
    blood_dark = (70, 10, 10, 255)
    blood_fresh = (145, 18, 18, 255)
    bone = (198, 190, 168, 255)
    rag_base = (92, 80, 64, 255)
    rag_shadow = (54, 46, 36, 255)
    rag_hl = (128, 114, 94, 255)
    eye_amber = (240, 210, 40, 255)

    if is_dead:
        # Horizontal corpse on desert floor
        # Blood pool
        d.ellipse([30, 215, 230, 250], fill=(50, 8, 8, 210))
        d.ellipse([50, 222, 210, 245], fill=blood_dark)
        # Body lying down
        # Torso
        d.polygon([(60, 225), (140, 220), (145, 240), (65, 242)], fill=rag_base)
        d.polygon([(65, 222), (135, 221), (138, 232), (68, 234)], fill=rag_hl)
        # Legs extended
        draw_limb_segment(d, (140, 230), (205, 232), 12, 8, rag_shadow)
        draw_limb_segment(d, (205, 232), (235, 235), 8, 6, flesh_shadow)
        # Head tilted back
        d.ellipse([35, 220, 68, 242], fill=flesh_shadow)
        d.ellipse([38, 222, 62, 238], fill=flesh_base)
        d.ellipse([42, 224, 52, 232], fill=blood_dark)
        # Severed arm
        draw_limb_segment(d, (85, 235), (120, 245), 9, 6, flesh_base)
        return im

    if is_die:
        # Falling backwards / collapsing
        # Kneeling collapsed
        d.ellipse([70, 220, 190, 250], fill=(60, 10, 10, 180))
        # Torso angled
        draw_limb_segment(d, (120, 160), (135, 215), 24, 20, rag_base, rag_shadow)
        # Head thrown back
        d.ellipse([100, 120, 145, 165], fill=flesh_base)
        d.ellipse([110, 122, 138, 148], fill=blood_dark)
        # Arms flailing
        draw_limb_segment(d, (110, 170), (70, 195), 11, 7, flesh_base)
        draw_limb_segment(d, (145, 170), (185, 190), 11, 7, flesh_base)
        # Folded legs
        draw_limb_segment(d, (125, 215), (100, 242), 15, 11, rag_shadow)
        draw_limb_segment(d, (135, 215), (160, 242), 15, 11, rag_shadow)
        return im

    # Standing/Walking/Attacking humanoid
    cx = 128 + sway_x
    head_cy = 58
    neck_cy = 82
    torso_top_y = 88
    pelvis_y = 162
    feet_y = 244

    # Back leg (depth sorted)
    back_leg_x = cx + (18 if l_leg_angle >= 0 else -18)
    back_foot_x = cx + int(math.sin(math.radians(-l_leg_angle)) * 32) + 12
    draw_limb_segment(d, (cx + 8, pelvis_y), (back_leg_x, 200), 15, 11, rag_shadow)
    draw_limb_segment(d, (back_leg_x, 200), (back_foot_x, feet_y), 11, 8, flesh_shadow)
    # Tattered boot/foot
    d.polygon([(back_foot_x - 7, feet_y), (back_foot_x + 14, feet_y), (back_foot_x + 8, feet_y - 8)], fill=rag_shadow)

    # Back arm
    back_hand_y = 150 + back_arm_dy if 'back_arm_dy' in locals() else (145 + r_arm_raise)
    back_hand_x = cx + 55
    draw_limb_segment(d, (cx + 26, torso_top_y + 12), (cx + 42, 128), 12, 9, flesh_shadow)
    draw_limb_segment(d, (cx + 42, 128), (back_hand_x, back_hand_y), 9, 6, flesh_shadow)

    # Torso (Muscular/rotted bulk)
    # Silhouette & base
    torso_poly = [
        (cx - 30, torso_top_y), (cx + 30, torso_top_y),
        (cx + 24, pelvis_y), (cx - 24, pelvis_y)
    ]
    d.polygon(torso_poly, fill=rag_shadow)
    # Tattered shirt / rags
    for y in range(int(torso_top_y), int(pelvis_y), 4):
        width = 28 - int(abs(y - (torso_top_y + pelvis_y) / 2) * 0.12)
        d.line([(cx - width, y), (cx + width, y)], fill=rag_base if (y // 6) % 2 == 0 else rag_shadow, width=4)

    # Exposed ribs & rot on chest
    d.ellipse([cx - 16, torso_top_y + 12, cx + 8, torso_top_y + 44], fill=blood_dark)
    for ry in range(int(torso_top_y) + 16, int(torso_top_y) + 40, 7):
        d.line([(cx - 14, ry), (cx + 4, ry - 2)], fill=bone, width=2)
        d.ellipse([cx - 4, ry, cx + 2, ry + 3], fill=blood_fresh)

    # Rags hanging from waist
    rag_bottoms = [
        (cx - 24, pelvis_y), (cx - 22, pelvis_y + 24),
        (cx - 12, pelvis_y + 18), (cx, pelvis_y + 26),
        (cx + 14, pelvis_y + 19), (cx + 24, pelvis_y + 25),
        (cx + 24, pelvis_y)
    ]
    d.polygon(rag_bottoms, fill=rag_base)

    # Front leg
    front_leg_x = cx + (18 if r_leg_angle >= 0 else -18)
    front_foot_x = cx + int(math.sin(math.radians(r_leg_angle)) * 34) - 10
    draw_limb_segment(d, (cx - 10, pelvis_y), (front_leg_x, 200), 16, 12, rag_base, rag_shadow)
    draw_limb_segment(d, (front_leg_x, 200), (front_foot_x, feet_y), 12, 9, flesh_base, flesh_shadow)
    # Bare rotten foot with exposed tendons
    d.polygon([(front_foot_x - 12, feet_y), (front_foot_x + 8, feet_y), (front_foot_x - 2, feet_y - 9)], fill=flesh_shadow)
    d.line([(front_foot_x - 8, feet_y - 2), (front_foot_x + 6, feet_y - 2)], fill=blood_dark, width=2)

    # Neck
    draw_limb_segment(d, (cx, torso_top_y + 6), (cx, neck_cy), 13, 11, flesh_base, flesh_shadow)

    # Head (Sculpted realistic skull shape)
    head_center_x = cx + int(head_tilt * 0.8)
    d.ellipse([head_center_x - 22, head_cy - 28, head_center_x + 22, head_cy + 24], fill=flesh_shadow)
    d.ellipse([head_center_x - 20, head_cy - 26, head_center_x + 18, head_cy + 22], fill=flesh_base)
    # Forehead highlight
    d.ellipse([head_center_x - 14, head_cy - 24, head_center_x + 10, head_cy - 8], fill=flesh_hl)
    # Hollow cheekbones
    d.polygon([(head_center_x - 18, head_cy), (head_center_x - 8, head_cy + 10), (head_center_x - 16, head_cy + 18)], fill=flesh_shadow)
    d.polygon([(head_center_x + 18, head_cy), (head_center_x + 8, head_cy + 10), (head_center_x + 16, head_cy + 18)], fill=flesh_shadow)

    # Exposed cranial bone & brain rot
    d.chord([head_center_x - 16, head_cy - 28, head_center_x + 12, head_cy - 10], 190, 350, fill=bone)
    d.ellipse([head_center_x - 10, head_cy - 26, head_center_x + 6, head_cy - 14], fill=blood_dark)

    # Sunken eye sockets
    d.ellipse([head_center_x - 16, head_cy - 7, head_center_x - 4, head_cy + 7], fill=(18, 14, 12, 255))
    d.ellipse([head_center_x + 4, head_cy - 7, head_center_x + 16, head_cy + 7], fill=(18, 14, 12, 255))
    # Glowing predatory retinas
    d.ellipse([head_center_x - 12, head_cy - 2, head_center_x - 7, head_cy + 3], fill=eye_amber)
    d.ellipse([head_center_x + 7, head_cy - 2, head_center_x + 12, head_cy + 3], fill=eye_amber)
    d.ellipse([head_center_x - 10, head_cy - 1, head_center_x - 8, head_cy + 1], fill=(255, 255, 200, 255))
    d.ellipse([head_center_x + 9, head_cy - 1, head_center_x + 11, head_cy + 1], fill=(255, 255, 200, 255))

    # Rotting nose cavity
    d.polygon([(head_center_x - 4, head_cy + 8), (head_center_x + 4, head_cy + 8), (head_center_x, head_cy + 3)], fill=(24, 16, 14, 255))

    # Gaping jaw with rotten teeth
    d.polygon([
        (head_center_x - 14, head_cy + 14), (head_center_x + 14, head_cy + 14),
        (head_center_x + 10, head_cy + 28), (head_center_x - 10, head_cy + 28)
    ], fill=blood_dark)
    # Teeth (upper & lower)
    for tx in range(head_center_x - 10, head_center_x + 11, 4):
        d.line([(tx, head_cy + 14), (tx, head_cy + 18)], fill=bone, width=2)
        d.line([(tx, head_cy + 24), (tx, head_cy + 27)], fill=bone, width=2)

    # Front arm (lunging or swinging)
    front_hand_y = 150 + l_arm_raise
    front_hand_x = cx - 45 - (15 if l_arm_raise < 0 else 0)
    draw_limb_segment(d, (cx - 28, torso_top_y + 10), (cx - 38, 128), 14, 10, flesh_base, flesh_shadow)
    draw_limb_segment(d, (cx - 38, 128), (front_hand_x, front_hand_y), 10, 7, flesh_base, flesh_shadow)
    # Clawed rotting hand
    d.ellipse([front_hand_x - 8, front_hand_y - 6, front_hand_x + 8, front_hand_y + 8], fill=flesh_shadow)
    for finger_i in range(4):
        fx = front_hand_x - 10 + finger_i * 6
        fy = front_hand_y + 12
        d.line([(front_hand_x - 6 + finger_i * 4, front_hand_y + 4), (fx, fy)], fill=bone, width=2)
        d.line([(fx, fy - 3), (fx, fy)], fill=blood_dark, width=2)

    # Damage overlay on hurt frame
    if is_hurt:
        d.ellipse([cx - 25, torso_top_y + 20, cx + 25, torso_top_y + 60], fill=(200, 20, 20, 140))
        for _ in range(8):
            d.line([(cx - 10, torso_top_y + 30), (cx - 25 + _ * 6, torso_top_y + 55)], fill=blood_fresh, width=3)

    return im

def render_runner_frame(f_idx):
    """Skeletal, emaciated, hyper-fast runner with exposed spine, razor claws, glowing red eyes."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    bone_pale = (215, 205, 185, 255)
    bone_shadow = (130, 115, 95, 255)
    bone_hl = (245, 240, 225, 255)
    tendon_red = (160, 25, 25, 255)
    eye_red = (255, 35, 15, 255)

    if is_dead:
        d.ellipse([40, 222, 225, 248], fill=(60, 10, 10, 190))
        d.polygon([(60, 226), (150, 224), (210, 238), (55, 242)], fill=bone_shadow)
        d.line([(70, 228), (145, 226)], fill=bone_pale, width=6)
        d.ellipse([45, 224, 75, 242], fill=bone_pale)
        return im

    if is_die:
        d.ellipse([80, 220, 185, 248], fill=(50, 10, 10, 160))
        draw_limb_segment(d, (130, 150), (135, 225), 18, 14, bone_shadow)
        d.ellipse([110, 115, 150, 155], fill=bone_pale)
        return im

    # Runner leans heavily forward (sprinting stance)
    lean_x = 18
    stride = (f_idx % 4)
    stride_angles = [28, -25, 32, -30]
    leg_spread = stride_angles[stride]

    cx = 128 + lean_x
    torso_top = 92
    pelvis_y = 168

    # Ribcage / spine (visible bony structure)
    # Spine column
    d.line([(cx, torso_top), (cx - 10, pelvis_y)], fill=bone_pale, width=7)
    # Individual ribs
    for i, ry in enumerate(range(int(torso_top) + 8, int(pelvis_y) - 10, 9)):
        rw = 22 - i * 2
        d.arc([cx - rw - 5, ry - 6, cx + rw - 5, ry + 10], 190, 350, fill=bone_pale, width=3)
        d.line([(cx - rw - 5, ry + 2), (cx - rw, ry + 2)], fill=tendon_red, width=2)
        d.line([(cx + rw - 10, ry + 2), (cx + rw - 5, ry + 2)], fill=tendon_red, width=2)

    # Legs (hyper-extended, thin, animalistic joints)
    l_foot_x = cx - 10 + leg_spread * 1.3
    r_foot_x = cx + 5 - leg_spread * 1.3
    # Left leg
    draw_limb_segment(d, (cx - 12, pelvis_y), (cx - 15 + leg_spread * 0.5, 205), 9, 6, bone_shadow)
    draw_limb_segment(d, (cx - 15 + leg_spread * 0.5, 205), (l_foot_x, 244), 6, 4, bone_pale, bone_shadow)
    # Right leg
    draw_limb_segment(d, (cx + 8, pelvis_y), (cx + 10 - leg_spread * 0.5, 205), 9, 6, bone_shadow)
    draw_limb_segment(d, (cx + 10 - leg_spread * 0.5, 205), (r_foot_x, 244), 6, 4, bone_pale, bone_shadow)

    # Head (elongated ghoul skull, thrust forward)
    head_x = cx + 18
    head_y = 66
    d.ellipse([head_x - 18, head_y - 20, head_x + 18, head_y + 16], fill=bone_shadow)
    d.ellipse([head_x - 16, head_y - 18, head_x + 16, head_y + 14], fill=bone_pale)
    d.ellipse([head_x - 10, head_y - 16, head_x + 10, head_y - 2], fill=bone_hl)
    # Gaping hollow eyes with red pinpoints
    d.ellipse([head_x - 11, head_y - 4, head_x - 3, head_y + 4], fill=(10, 5, 5, 255))
    d.ellipse([head_x + 3, head_y - 4, head_x + 11, head_y + 4], fill=(10, 5, 5, 255))
    d.ellipse([head_x - 8, head_y - 2, head_x - 5, head_y + 2], fill=eye_red)
    d.ellipse([head_x + 5, head_y - 2, head_x + 8, head_y + 2], fill=eye_red)
    d.ellipse([head_x - 7, head_y - 1, head_x - 6, head_y + 1], fill=(255, 220, 220, 255))
    d.ellipse([head_x + 6, head_y - 1, head_x + 7, head_y + 1], fill=(255, 220, 220, 255))

    # Long razor claws / arms
    claw_reach = 40 if f_idx in (5, 6) else 25
    draw_limb_segment(d, (cx - 18, torso_top + 8), (cx - 30, 130), 8, 5, bone_pale, bone_shadow)
    draw_limb_segment(d, (cx - 30, 130), (cx - 45 - claw_reach, 155), 5, 3, bone_pale)
    for c_idx in range(4):
        d.line([(cx - 45 - claw_reach, 155), (cx - 65 - claw_reach, 160 + c_idx * 5)], fill=tendon_red, width=2)
        d.line([(cx - 60 - claw_reach, 158 + c_idx * 4), (cx - 65 - claw_reach, 160 + c_idx * 5)], fill=bone_hl, width=2)

    draw_limb_segment(d, (cx + 18, torso_top + 8), (cx + 25, 130), 8, 5, bone_shadow)
    draw_limb_segment(d, (cx + 25, 130), (cx + 35 + claw_reach * 0.7, 150), 5, 3, bone_pale)

    if is_hurt:
        d.ellipse([cx - 20, torso_top + 10, cx + 20, torso_top + 50], fill=(220, 30, 30, 160))

    return im

def render_brute_frame(f_idx):
    """Massive, hulking mutant butcher with swollen muscles, rusted chains, iron collar."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    flesh_purple = (112, 68, 76, 255)
    flesh_shadow = (65, 34, 42, 255)
    flesh_hl = (152, 95, 105, 255)
    iron = (140, 135, 130, 255)
    iron_rust = (165, 85, 35, 255)
    iron_dark = (50, 48, 46, 255)

    if is_dead:
        d.ellipse([20, 210, 240, 250], fill=(50, 15, 20, 210))
        d.ellipse([35, 218, 225, 246], fill=flesh_shadow)
        d.ellipse([60, 215, 180, 240], fill=flesh_purple)
        return im

    if is_die:
        d.ellipse([40, 205, 220, 250], fill=(50, 15, 20, 190))
        draw_limb_segment(d, (128, 140), (135, 225), 45, 35, flesh_shadow)
        d.ellipse([110, 95, 155, 140], fill=flesh_purple)
        return im

    cx = 128
    sway = 6 if f_idx in (1, 3) else 0
    arm_swing = 25 if f_idx == 5 else (-20 if f_idx == 6 else 0)

    # Massive torso (huge trapezoids and chest)
    # Neck and traps
    traps = [(cx - 55, 95), (cx + 55, 95), (cx + 42, 175), (cx - 42, 175)]
    d.polygon(traps, fill=flesh_shadow)
    d.ellipse([cx - 52, 70, cx + 52, 135], fill=flesh_purple)
    # Muscle definition (pecs, abs)
    d.ellipse([cx - 45, 95, cx - 2, 132], fill=flesh_shadow)
    d.ellipse([cx - 40, 98, cx - 6, 128], fill=flesh_hl)
    d.ellipse([cx + 2, 95, cx + 45, 132], fill=flesh_shadow)
    d.ellipse([cx + 6, 98, cx + 40, 128], fill=flesh_hl)

    # Crossed rusted chains over chest
    d.line([(cx - 48, 85), (cx + 42, 170)], fill=iron_dark, width=9)
    d.line([(cx - 48, 85), (cx + 42, 170)], fill=iron_rust, width=6)
    d.line([(cx - 46, 87), (cx + 40, 168)], fill=iron, width=3)

    d.line([(cx + 48, 85), (cx - 42, 170)], fill=iron_dark, width=9)
    d.line([(cx + 48, 85), (cx - 42, 170)], fill=iron_rust, width=6)
    d.line([(cx + 46, 87), (cx - 40, 168)], fill=iron, width=3)

    # Pillar legs
    draw_limb_segment(d, (cx - 28, 175), (cx - 30, 244), 22, 16, flesh_shadow)
    draw_limb_segment(d, (cx + 28, 175), (cx + 30, 244), 22, 16, flesh_shadow)

    # Small pinhead sunken into huge traps
    head_y = 60
    d.ellipse([cx - 22, head_y - 20, cx + 22, head_y + 20], fill=flesh_shadow)
    d.ellipse([cx - 18, head_y - 18, cx + 18, head_y + 18], fill=flesh_purple)
    # Iron spiked collar
    d.ellipse([cx - 26, head_y + 8, cx + 26, head_y + 24], fill=iron_dark)
    d.ellipse([cx - 24, head_y + 10, cx + 24, head_y + 22], fill=iron_rust)
    for sp in range(-20, 21, 8):
        d.line([(cx + sp, head_y + 8), (cx + sp * 1.2, head_y - 2)], fill=iron, width=3)

    # Tiny yellow glowing eyes
    d.ellipse([cx - 10, head_y - 4, cx - 4, head_y + 2], fill=(240, 200, 30, 255))
    d.ellipse([cx + 4, head_y - 4, cx + 10, head_y + 2], fill=(240, 200, 30, 255))

    # Giant boulder arms & rusted iron gauntlets
    l_arm_y = 155 + arm_swing
    r_arm_y = 155 - arm_swing
    draw_limb_segment(d, (cx - 52, 95), (cx - 65, l_arm_y), 24, 18, flesh_purple, flesh_shadow)
    draw_limb_segment(d, (cx + 52, 95), (cx + 65, r_arm_y), 24, 18, flesh_purple, flesh_shadow)

    # Shackles on wrists
    d.ellipse([cx - 78, l_arm_y - 10, cx - 52, l_arm_y + 16], fill=iron_rust)
    d.ellipse([cx + 52, r_arm_y - 10, cx + 78, r_arm_y + 16], fill=iron_rust)
    # Dangling broken chain links
    for lk in range(3):
        d.ellipse([cx - 70, l_arm_y + 16 + lk * 10, cx - 60, l_arm_y + 26 + lk * 10], outline=iron, width=3)
        d.ellipse([cx + 60, r_arm_y + 16 + lk * 10, cx + 70, r_arm_y + 26 + lk * 10], outline=iron, width=3)

    if is_hurt:
        d.ellipse([cx - 40, 85, cx + 40, 160], fill=(220, 20, 20, 140))

    return im

def render_crawler_frame(f_idx):
    """Torso-only crawling mutant dragging along ground on hands. Trailing bloody intestines."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    skin = (110, 125, 105, 255)
    skin_dark = (55, 65, 52, 255)
    skin_hl = (145, 165, 138, 255)
    guts_pink = (185, 90, 80, 255)
    guts_dark = (95, 25, 25, 255)
    bone = (205, 195, 175, 255)

    if is_dead:
        d.ellipse([30, 225, 230, 250], fill=(50, 10, 10, 210))
        d.polygon([(50, 232), (180, 230), (210, 245), (45, 246)], fill=skin_dark)
        return im

    if is_die:
        d.ellipse([50, 215, 210, 250], fill=(60, 10, 10, 180))
        draw_limb_segment(d, (100, 200), (140, 235), 20, 14, skin_dark)
        return im

    # Body sits low on ground: waist at y=200, head at y=145
    cx = 128
    drag_cycle = (f_idx % 4)
    arm_l_x = cx - 55 + (drag_cycle * 8)
    arm_r_x = cx + 55 - (drag_cycle * 8)

    # Trailing intestines and severed spine
    d.ellipse([cx + 10, 205, cx + 95, 235], fill=guts_dark)
    for g_i in range(5):
        gx = cx + 25 + g_i * 12
        gy = 215 + int(math.sin(g_i * 1.5) * 6)
        d.ellipse([gx - 8, gy - 6, gx + 8, gy + 6], fill=guts_pink)
        d.ellipse([gx - 5, gy - 3, gx + 4, gy + 2], fill=(225, 120, 110, 255))

    # Severed spine stump
    d.polygon([(cx + 8, 198), (cx + 28, 196), (cx + 26, 212), (cx + 6, 214)], fill=bone)
    d.line([(cx + 12, 196), (cx + 12, 214)], fill=(120, 20, 20, 255), width=2)

    # Torso (horizontal, angled forward)
    torso_pts = [
        (cx - 35, 160), (cx + 25, 185),
        (cx + 15, 215), (cx - 40, 195)
    ]
    d.polygon(torso_pts, fill=skin_dark)
    d.polygon([(cx - 32, 165), (cx + 20, 188), (cx + 10, 210), (cx - 36, 192)], fill=skin)
    # Shoulder blades
    d.ellipse([cx - 38, 162, cx - 12, 190], fill=skin_hl)

    # Low menacing head (looking directly up at player)
    head_x = cx - 42
    head_y = 152
    d.ellipse([head_x - 22, head_y - 20, head_x + 22, head_y + 20], fill=skin_dark)
    d.ellipse([head_x - 18, head_y - 18, head_x + 18, head_y + 18], fill=skin)
    d.ellipse([head_x - 12, head_y - 16, head_x + 8, head_y - 2], fill=skin_hl)

    # Gaping mouth full of needle teeth
    d.polygon([(head_x - 14, head_y + 6), (head_x + 6, head_y + 6), (head_x - 4, head_y + 22)], fill=(40, 8, 8, 255))
    for t_i in range(-10, 4, 3):
        d.line([(head_x + t_i, head_y + 6), (head_x + t_i, head_y + 12)], fill=bone, width=1)

    # Glowing pale yellow-green eyes
    d.ellipse([head_x - 14, head_y - 4, head_x - 6, head_y + 4], fill=(190, 245, 50, 255))
    d.ellipse([head_x - 1, head_y - 4, head_x + 7, head_y + 4], fill=(190, 245, 50, 255))

    # Powerful dragging arms planted on ground
    draw_limb_segment(d, (cx - 30, 175), (arm_l_x, 230), 16, 12, skin, skin_dark)
    draw_limb_segment(d, (arm_l_x, 230), (arm_l_x - 15, 244), 12, 8, skin_dark)
    # Left claw planted
    d.polygon([(arm_l_x - 25, 244), (arm_l_x + 5, 244), (arm_l_x - 8, 235)], fill=skin_dark)

    draw_limb_segment(d, (cx + 5, 185), (arm_r_x, 232), 16, 12, skin, skin_dark)
    draw_limb_segment(d, (arm_r_x, 232), (arm_r_x + 15, 244), 12, 8, skin_dark)
    # Right claw planted
    d.polygon([(arm_r_x - 5, 244), (arm_r_x + 25, 244), (arm_r_x + 8, 235)], fill=skin_dark)

    if is_hurt:
        d.ellipse([cx - 40, 160, cx + 20, 210], fill=(220, 20, 20, 150))

    return im

def render_spitter_frame(f_idx):
    """Hunched, bloated zombie with huge glowing acid sacs on throat/shoulders."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    skin_toxic = (125, 145, 65, 255)
    skin_dark = (60, 75, 30, 255)
    sac_green = (80, 220, 35, 255)
    sac_glow = (140, 255, 60, 255)
    sac_core = (210, 255, 120, 255)
    acid_drip = (110, 235, 30, 255)

    if is_dead:
        # Puddle of caustic acid and dissolved bones
        d.ellipse([25, 215, 235, 250], fill=(50, 140, 20, 190))
        d.ellipse([50, 222, 210, 245], fill=sac_green)
        d.ellipse([80, 228, 180, 240], fill=sac_core)
        return im

    if is_die:
        d.ellipse([60, 210, 200, 250], fill=(60, 160, 30, 160))
        draw_limb_segment(d, (128, 150), (135, 230), 28, 20, skin_dark)
        return im

    cx = 128
    # Hunched gait
    head_y = 65
    neck_y = 92
    torso_top = 100
    pelvis_y = 175

    # Legs
    draw_limb_segment(d, (cx - 16, pelvis_y), (cx - 20, 244), 16, 11, skin_dark)
    draw_limb_segment(d, (cx + 16, pelvis_y), (cx + 20, 244), 16, 11, skin_dark)

    # Torso
    d.ellipse([cx - 35, torso_top, cx + 35, pelvis_y + 10], fill=skin_dark)
    d.ellipse([cx - 30, torso_top + 4, cx + 30, pelvis_y + 5], fill=skin_toxic)

    # Huge glowing toxic sacs on throat & shoulders
    pulse = int(math.sin(f_idx * 1.2) * 4)
    # Left shoulder sac
    d.ellipse([cx - 52 - pulse, torso_top - 10, cx - 18, torso_top + 32], fill=skin_dark)
    d.ellipse([cx - 48 - pulse, torso_top - 8, cx - 22, torso_top + 28], fill=sac_green)
    d.ellipse([cx - 42 - pulse, torso_top - 4, cx - 28, torso_top + 18], fill=sac_glow)
    d.ellipse([cx - 38 - pulse, torso_top, cx - 32, torso_top + 10], fill=sac_core)

    # Right shoulder sac
    d.ellipse([cx + 18, torso_top - 10, cx + 52 + pulse, torso_top + 32], fill=skin_dark)
    d.ellipse([cx + 22, torso_top - 8, cx + 48 + pulse, torso_top + 28], fill=sac_green)
    d.ellipse([cx + 28, torso_top - 4, cx + 42 + pulse, torso_top + 18], fill=sac_glow)
    d.ellipse([cx + 32, torso_top, cx + 38 + pulse, torso_top + 10], fill=sac_core)

    # Giant throat goiter / acid sac
    d.ellipse([cx - 25, neck_y - 12, cx + 25, neck_y + 30 + pulse], fill=skin_dark)
    d.ellipse([cx - 22, neck_y - 10, cx + 22, neck_y + 26 + pulse], fill=sac_green)
    d.ellipse([cx - 15, neck_y - 4, cx + 15, neck_y + 18 + pulse], fill=sac_glow)
    d.ellipse([cx - 8, neck_y, cx + 8, neck_y + 12 + pulse], fill=sac_core)

    # Head (distended jaw)
    d.ellipse([cx - 20, head_y - 20, cx + 20, head_y + 16], fill=skin_dark)
    d.ellipse([cx - 16, head_y - 18, cx + 16, head_y + 14], fill=skin_toxic)
    # Pale blind milky eyes
    d.ellipse([cx - 12, head_y - 4, cx - 4, head_y + 3], fill=(220, 240, 200, 255))
    d.ellipse([cx + 4, head_y - 4, cx + 12, head_y + 3], fill=(220, 240, 200, 255))

    # Gaping distended lower jaw dripping acid
    d.polygon([(cx - 16, head_y + 8), (cx + 16, head_y + 8), (cx + 10, head_y + 32), (cx - 10, head_y + 32)], fill=(30, 50, 15, 255))
    # Dripping acid streams (active attack on frames 5, 6)
    if f_idx in (5, 6):
        # Vomiting long acid projectile stream
        d.line([(cx, head_y + 24), (cx, head_y + 75)], fill=acid_drip, width=8)
        d.line([(cx, head_y + 28), (cx, head_y + 70)], fill=sac_core, width=4)
        for dr in range(6):
            dx = cx + int(math.sin(dr * 1.7) * 16)
            dy = head_y + 50 + dr * 12
            d.ellipse([dx - 5, dy - 5, dx + 5, dy + 5], fill=sac_glow)
    else:
        for dp in [-8, 0, 8]:
            d.line([(cx + dp, head_y + 30), (cx + dp, head_y + 44)], fill=acid_drip, width=2)
            d.ellipse([cx + dp - 2, head_y + 42, cx + dp + 2, head_y + 48], fill=sac_core)

    # Arms hanging low
    draw_limb_segment(d, (cx - 36, torso_top + 10), (cx - 42, 175), 11, 7, skin_toxic, skin_dark)
    draw_limb_segment(d, (cx + 36, torso_top + 10), (cx + 42, 175), 11, 7, skin_toxic, skin_dark)

    if is_hurt:
        d.ellipse([cx - 28, torso_top + 10, cx + 28, torso_top + 60], fill=(240, 40, 40, 140))

    return im

def render_screamer_frame(f_idx):
    """Tall, gaunt, ash-white phantom with elongated screaming maw and sonic rings."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    ash_white = (210, 205, 200, 255)
    ash_shadow = (115, 108, 105, 255)
    ash_hl = (245, 242, 238, 255)
    void_black = (12, 8, 8, 255)
    sonic_blue = (120, 185, 245, 180)
    sonic_glow = (180, 225, 255, 240)

    if is_dead:
        d.ellipse([45, 225, 220, 248], fill=(30, 25, 25, 180))
        d.polygon([(65, 230), (160, 228), (200, 244), (60, 246)], fill=ash_shadow)
        return im

    if is_die:
        d.ellipse([70, 215, 190, 248], fill=(30, 25, 25, 160))
        draw_limb_segment(d, (128, 140), (135, 230), 16, 11, ash_shadow)
        return im

    cx = 128
    # Tall, slender silhouette (head at y=48)
    head_y = 48
    torso_top = 78
    pelvis_y = 155

    # Tattered spectral shroud covering legs
    shroud_pts = [
        (cx - 18, pelvis_y), (cx + 18, pelvis_y),
        (cx + 25, 235), (cx + 12, 244),
        (cx, 232), (cx - 15, 244),
        (cx - 28, 235)
    ]
    d.polygon(shroud_pts, fill=ash_shadow)
    d.polygon([(cx - 14, pelvis_y), (cx + 14, pelvis_y), (cx + 18, 230), (cx - 18, 230)], fill=ash_white)

    # Narrow emaciated torso
    draw_limb_segment(d, (cx, torso_top), (cx, pelvis_y), 15, 12, ash_white, ash_shadow)

    # Raised arms in agony
    arm_angle = -45 if f_idx in (5, 6) else -20
    draw_limb_segment(d, (cx - 16, torso_top + 6), (cx - 45, 105 + arm_angle), 8, 5, ash_white, ash_shadow)
    draw_limb_segment(d, (cx - 45, 105 + arm_angle), (cx - 55, 80 + arm_angle * 1.4), 5, 3, ash_white)

    draw_limb_segment(d, (cx + 16, torso_top + 6), (cx + 45, 105 + arm_angle), 8, 5, ash_white, ash_shadow)
    draw_limb_segment(d, (cx + 45, 105 + arm_angle), (cx + 55, 80 + arm_angle * 1.4), 5, 3, ash_white)

    # Elongated Munch-style "The Scream" head
    d.ellipse([cx - 18, head_y - 25, cx + 18, head_y + 25], fill=ash_shadow)
    d.ellipse([cx - 15, head_y - 23, cx + 15, head_y + 23], fill=ash_white)
    d.ellipse([cx - 8, head_y - 20, cx + 6, head_y - 6], fill=ash_hl)

    # Dark hollow eye sockets
    d.ellipse([cx - 13, head_y - 12, cx - 3, head_y - 2], fill=void_black)
    d.ellipse([cx + 3, head_y - 12, cx + 13, head_y - 2], fill=void_black)

    # Impossibly elongated cavernous mouth
    d.ellipse([cx - 10, head_y + 2, cx + 10, head_y + 24], fill=void_black)
    d.ellipse([cx - 6, head_y + 5, cx + 6, head_y + 21], fill=(28, 12, 16, 255))

    # Expanding sonic shockwaves during scream (attacks & high intensity)
    if f_idx in (5, 6):
        for ring_r in [30, 52, 75]:
            d.arc([cx - ring_r, head_y + 12 - ring_r, cx + ring_r, head_y + 12 + ring_r], 0, 360, fill=sonic_glow, width=3)
            d.arc([cx - ring_r - 2, head_y + 12 - ring_r - 2, cx + ring_r + 2, head_y + 12 + ring_r + 2], 0, 360, fill=sonic_blue, width=1)

    if is_hurt:
        d.ellipse([cx - 20, torso_top, cx + 20, torso_top + 50], fill=(220, 30, 30, 140))

    return im

def render_exploder_frame(f_idx):
    """Grotesquely bloated kamikaze zombie. Glowing magma/lava cracks on huge belly, blast on die."""
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_dead = (f_idx == 9)
    is_die = (f_idx == 8)
    is_hurt = (f_idx == 7)

    skin_bloat = (135, 95, 80, 255)
    skin_dark = (75, 42, 35, 255)
    lava_red = (245, 55, 15, 255)
    lava_orange = (255, 140, 25, 255)
    lava_core = (255, 230, 80, 255)

    if is_dead:
        # Smoldering blast crater on ground
        d.ellipse([20, 215, 240, 250], fill=(25, 20, 18, 220))
        d.ellipse([45, 222, 215, 246], fill=(50, 25, 15, 240))
        d.ellipse([80, 228, 180, 242], fill=(180, 70, 20, 180))
        return im

    if is_die or f_idx == 6:
        # Massive explosion detonation frame!
        d.ellipse([10, 60, 246, 246], fill=(255, 120, 20, 220))
        d.ellipse([30, 80, 226, 235], fill=lava_orange)
        d.ellipse([60, 105, 196, 215], fill=lava_core)
        d.ellipse([90, 130, 166, 190], fill=(255, 255, 230, 255))
        # Fiery blast rays radiating outwards
        cx = 128
        cy = 160
        for ray_i in range(16):
            ang = ray_i * (math.pi / 8)
            rx = cx + math.cos(ang) * 115
            ry = cy + math.sin(ang) * 105
            d.line([(cx, cy), (rx, ry)], fill=lava_core, width=5)
        return im

    cx = 128
    head_y = 62
    belly_cy = 148
    belly_r = 54 + int(f_idx * 1.5)  # Expands as it gets closer to exploding!

    # Stubby waddling legs underneath massive belly
    draw_limb_segment(d, (cx - 24, belly_cy + 35), (cx - 26, 244), 16, 12, skin_dark)
    draw_limb_segment(d, (cx + 24, belly_cy + 35), (cx + 26, 244), 16, 12, skin_dark)

    # Tiny head sitting on top of sphere
    d.ellipse([cx - 16, head_y - 18, cx + 16, head_y + 16], fill=skin_dark)
    d.ellipse([cx - 13, head_y - 16, cx + 13, head_y + 14], fill=skin_bloat)
    # Manic glowing orange eyes
    d.ellipse([cx - 9, head_y - 4, cx - 3, head_y + 2], fill=lava_orange)
    d.ellipse([cx + 3, head_y - 4, cx + 9, head_y + 2], fill=lava_orange)
    d.ellipse([cx - 7, head_y - 3, cx - 5, head_y], fill=lava_core)
    d.ellipse([cx + 5, head_y - 3, cx + 7, head_y], fill=lava_core)

    # Massive spherical belly dominating the sprite
    d.ellipse([cx - belly_r, belly_cy - belly_r, cx + belly_r, belly_cy + belly_r], fill=skin_dark)
    d.ellipse([cx - belly_r + 4, belly_cy - belly_r + 4, cx + belly_r - 4, belly_cy + belly_r - 4], fill=skin_bloat)

    # Intricate glowing molten magma cracks across the distended flesh
    crack_branches = [
        [(cx - 35, belly_cy - 20), (cx - 15, belly_cy), (cx, belly_cy + 25), (cx + 20, belly_cy + 40)],
        [(cx - 15, belly_cy), (cx - 5, belly_cy - 25), (cx + 15, belly_cy - 35)],
        [(cx + 5, belly_cy - 10), (cx + 25, belly_cy), (cx + 38, belly_cy + 20)],
        [(cx - 25, belly_cy + 20), (cx - 10, belly_cy + 35), (cx + 5, belly_cy + 38)]
    ]
    for branch in crack_branches:
        for i in range(len(branch) - 1):
            p1 = branch[i]
            p2 = branch[i + 1]
            d.line([p1, p2], fill=lava_red, width=7)
            d.line([p1, p2], fill=lava_orange, width=4)
            d.line([p1, p2], fill=lava_core, width=2)

    # Central pulsing magma core
    core_r = 16 + int(math.sin(f_idx * 1.5) * 5)
    d.ellipse([cx - core_r, belly_cy - core_r, cx + core_r, belly_cy + core_r], fill=(255, 60, 20, 160))
    d.ellipse([cx - core_r + 4, belly_cy - core_r + 4, cx + core_r - 4, belly_cy + core_r - 4], fill=(255, 160, 40, 200))
    d.ellipse([cx - core_r + 8, belly_cy - core_r + 8, cx + core_r - 8, belly_cy + core_r - 8], fill=lava_core)

    # Tiny stubby outstretched arms
    draw_limb_segment(d, (cx - belly_r + 8, belly_cy - 15), (cx - belly_r - 18, belly_cy - 25), 10, 6, skin_bloat, skin_dark)
    draw_limb_segment(d, (cx + belly_r - 8, belly_cy - 15), (cx + belly_r + 18, belly_cy - 25), 10, 6, skin_bloat, skin_dark)

    if is_hurt:
        d.ellipse([cx - belly_r, belly_cy - belly_r, cx + belly_r, belly_cy + belly_r], fill=(255, 40, 20, 150))

    return im

def build_spritesheet(renderer, out_path):
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for f_idx in range(TOTAL_FRAMES):
        frame = renderer(f_idx)
        sheet.paste(frame, (f_idx * FRAME_W, 0))
    # Slight antialiasing/softening pass to blend high-res vector details into natural game look
    sheet = sheet.filter(ImageFilter.SMOOTH_MORE)
    sheet.save(out_path, "PNG", optimize=True)
    print(f"Generated realistic spritesheet: {out_path} ({SHEET_W}x{SHEET_H})")

if __name__ == "__main__":
    import os
    base_dir = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\textures"
    os.makedirs(base_dir, exist_ok=True)

    build_spritesheet(render_walker_frame, os.path.join(base_dir, "zombie_walker.png"))
    build_spritesheet(render_runner_frame, os.path.join(base_dir, "zombie_runner.png"))
    build_spritesheet(render_brute_frame, os.path.join(base_dir, "zombie_brute.png"))
    build_spritesheet(render_crawler_frame, os.path.join(base_dir, "zombie_crawler.png"))
    build_spritesheet(render_spitter_frame, os.path.join(base_dir, "zombie_spitter.png"))
    build_spritesheet(render_screamer_frame, os.path.join(base_dir, "zombie_screamer.png"))
    build_spritesheet(render_exploder_frame, os.path.join(base_dir, "zombie_exploder.png"))
    print("ALL 7 REALISTIC HIGH-RES ZOMBIE SPRITESHEETS CREATED!")
