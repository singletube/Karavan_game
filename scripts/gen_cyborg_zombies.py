"""
Generates CYBORG HORROR ZOMBIE spritesheets (2560x256, 10 frames of 256x256 each).
Combines bio-mechanical implants, steel skull plates, glowing crimson cyber-optics,
pneumatic pistons, exposed servomotors, wiring harnesses, oil-mixed blood,
and horrifying biomechanical mutations.
Frame 7 (HURT) features visible electrical arcs, sparking cybernetics, and heavy impact recoil!
"""

import math
import random
from PIL import Image, ImageDraw, ImageFilter

FRAME_W = 256
FRAME_H = 256
TOTAL_FRAMES = 10
SHEET_W = FRAME_W * TOTAL_FRAMES
SHEET_H = FRAME_H

def draw_wire(draw, pts, color, width=2):
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill=color, width=width)

def draw_piston(draw, p1, p2, width=7, metal_col=(180, 185, 195, 255), dark_col=(40, 45, 50, 255)):
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    mid = (p1[0] + dx * 0.5, p1[1] + dy * 0.5)
    # Outer dark casing
    draw.line([p1, mid], fill=dark_col, width=width)
    # Inner shiny steel rod
    draw.line([mid, p2], fill=metal_col, width=max(2, width - 3))

def draw_bio_segment(draw, p1, p2, r1, r2, flesh_col, cyber_col=None):
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
        col = cyber_col if (cyber_col and (i % 5 < 2)) else flesh_col
        draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=col)

# --- 1. CYBORG WALKER (Штурмовой Киборг-Зомби) ---
def render_cyborg_walker(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    sway = (-5 if f_idx in (1, 5) else (5 if f_idx in (3, 6) else 0))
    if is_hurt:
        sway = -10

    # Palette: gunmetal steel, decayed flesh, glowing cyan/crimson HUD lights, hydraulic oil
    steel_plate = (145, 150, 160, 255)
    steel_dark = (48, 52, 58, 255)
    steel_shiny = (215, 222, 235, 255)
    flesh_rot = (65, 82, 60, 255)
    flesh_dark = (35, 45, 32, 255)
    cyber_red = (255, 30, 20, 255)
    cyber_cyan = (40, 235, 255, 255)
    wire_yellow = (235, 190, 30, 255)
    wire_blue = (35, 120, 230, 255)
    oil_black = (20, 18, 16, 255)

    if is_dead:
        # Shattered cyborg carcass, smoking hydraulic fluid
        d.ellipse([30, 215, 230, 250], fill=(20, 15, 15, 210))
        d.ellipse([50, 222, 210, 245], fill=oil_black)
        # Twisted titanium chassis
        d.polygon([(55, 225), (145, 220), (195, 238), (60, 242)], fill=steel_dark)
        d.line([(70, 225), (140, 223)], fill=steel_plate, width=8)
        d.ellipse([40, 220, 75, 240], fill=steel_shiny)
        d.ellipse([45, 225, 52, 232], fill=(120, 15, 10, 255))
        return im

    if is_die:
        # Collapsing with sparking servos
        d.ellipse([65, 215, 195, 250], fill=(30, 15, 15, 180))
        draw_bio_segment(d, (120, 160), (135, 220), 25, 18, flesh_dark, steel_plate)
        d.ellipse([105, 120, 150, 165], fill=steel_dark)
        return im

    cx = 128 + sway
    head_y = 56
    torso_top = 86
    pelvis_y = 162

    # Left Leg: Fully mechanical hydraulic strider leg
    l_foot_x = cx - 18 + (-12 if f_idx in (1, 2) else 12)
    draw_piston(d, (cx - 14, pelvis_y), (l_foot_x, 202), width=10, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (l_foot_x, 202), (l_foot_x - 5, 244), width=8, metal_col=steel_plate, dark_col=steel_dark)
    # Heavy titanium stomper foot
    d.polygon([(l_foot_x - 18, 244), (l_foot_x + 8, 244), (l_foot_x - 5, 234)], fill=steel_shiny)
    d.polygon([(l_foot_x - 16, 242), (l_foot_x + 6, 242), (l_foot_x - 4, 236)], fill=steel_dark)

    # Right Leg: Rotted bio-leg grafted with steel brace
    r_foot_x = cx + 18 + (12 if f_idx in (1, 2) else -12)
    draw_bio_segment(d, (cx + 12, pelvis_y), (r_foot_x, 205), 16, 12, flesh_rot, flesh_dark)
    draw_bio_segment(d, (r_foot_x, 205), (r_foot_x + 5, 244), 12, 9, flesh_dark)
    # Steel exoskeleton brace strapped on thigh and calf
    d.line([(cx + 18, pelvis_y + 8), (r_foot_x + 6, 238)], fill=steel_shiny, width=4)
    d.ellipse([r_foot_x - 3, 204, r_foot_x + 13, 220], fill=steel_dark)

    # Torso: Reinforced armored carapace over exposed rotting ribcage
    d.polygon([(cx - 32, torso_top), (cx + 32, torso_top), (cx + 25, pelvis_y), (cx - 25, pelvis_y)], fill=steel_dark)
    # Left armored chest plate with riveted edges
    d.polygon([(cx - 30, torso_top + 4), (cx - 2, torso_top + 4), (cx - 4, torso_top + 45), (cx - 26, torso_top + 42)], fill=steel_plate)
    d.polygon([(cx - 28, torso_top + 6), (cx - 4, torso_top + 6), (cx - 6, torso_top + 43), (cx - 24, torso_top + 40)], fill=steel_shiny)
    # Glowing power core reactor on chest
    d.ellipse([cx - 18, torso_top + 16, cx - 8, torso_top + 26], fill=cyber_cyan)
    d.ellipse([cx - 16, torso_top + 18, cx - 10, torso_top + 24], fill=(230, 255, 255, 255))

    # Right side chest: Torn open, rotted lung replaced by mechanical pneumatic pump
    d.ellipse([cx + 4, torso_top + 10, cx + 28, torso_top + 48], fill=oil_black)
    d.line([(cx + 8, torso_top + 20), (cx + 24, torso_top + 20)], fill=(200, 30, 20, 255), width=3)
    d.line([(cx + 8, torso_top + 32), (cx + 24, torso_top + 32)], fill=steel_shiny, width=4)
    # Exposed hanging colorful high-voltage wires
    draw_wire(d, [(cx - 4, torso_top + 42), (cx + 2, torso_top + 55), (cx + 10, torso_top + 48)], wire_yellow, width=3)
    draw_wire(d, [(cx + 12, torso_top + 48), (cx + 18, torso_top + 62), (cx + 8, pelvis_y)], wire_blue, width=2)

    # Neck: Steel spinal column with rotted throat
    d.line([(cx, torso_top + 5), (cx, head_y + 18)], fill=steel_shiny, width=9)
    d.line([(cx - 2, torso_top + 5), (cx - 2, head_y + 18)], fill=steel_dark, width=5)

    # Head: Split cyborg skull — half rotten human jaw, half titanium combat visor
    d.ellipse([cx - 22, head_y - 25, cx + 22, head_y + 22], fill=steel_dark)
    # Left side: Titanium cranial shell
    d.chord([cx - 22, head_y - 25, cx + 15, head_y + 20], 90, 270, fill=steel_plate)
    d.chord([cx - 20, head_y - 23, cx + 12, head_y + 18], 100, 260, fill=steel_shiny)
    # Glowing crimson cybernetic optical sensor array
    d.ellipse([cx - 16, head_y - 7, cx - 2, head_y + 7], fill=(50, 5, 5, 255))
    d.ellipse([cx - 14, head_y - 5, cx - 4, head_y + 5], fill=cyber_red)
    d.ellipse([cx - 11, head_y - 2, cx - 7, head_y + 2], fill=(255, 220, 220, 255))

    # Right side head: Rotted flesh, hollow eye, exposed steel jaw mechanism
    d.chord([cx - 4, head_y - 25, cx + 22, head_y + 22], 270, 90, fill=flesh_rot)
    d.ellipse([cx + 5, head_y - 6, cx + 15, head_y + 4], fill=(12, 10, 8, 255))
    # Metal lower jaw with steel teeth
    d.polygon([(cx - 12, head_y + 10), (cx + 12, head_y + 10), (cx + 8, head_y + 25), (cx - 8, head_y + 25)], fill=steel_dark)
    for tx in range(cx - 8, cx + 9, 4):
        d.line([(tx, head_y + 10), (tx, head_y + 15)], fill=steel_shiny, width=2)
        d.line([(tx, head_y + 20), (tx, head_y + 24)], fill=steel_shiny, width=2)

    # Right Arm: Hydraulic steel claw arm
    claw_y = 150 + (-25 if f_idx in (5, 6) else 0)
    draw_piston(d, (cx + 30, torso_top + 8), (cx + 50, 125), width=12, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (cx + 50, 125), (cx + 62, claw_y), width=9, metal_col=steel_plate, dark_col=steel_dark)
    # Triple razor steel pincer claw
    for cl in [-8, 0, 8]:
        d.line([(cx + 62, claw_y), (cx + 78, claw_y + 12 + cl)], fill=steel_shiny, width=4)
        d.line([(cx + 70, claw_y + 6 + cl), (cx + 78, claw_y + 12 + cl)], fill=cyber_red, width=2)

    # Left Arm: Bio-arm with steel blade grafted into forearm
    draw_bio_segment(d, (cx - 30, torso_top + 8), (cx - 45, 125), 14, 10, flesh_rot, flesh_dark)
    draw_bio_segment(d, (cx - 45, 125), (cx - 52, 160), 10, 7, flesh_dark)
    # Subdermal forearm machete blade extending past wrist
    d.polygon([(cx - 55, 135), (cx - 48, 135), (cx - 62, 185), (cx - 68, 180)], fill=steel_shiny)

    # Hurt frame: Electrical discharge / blue-white lightning arcing across chassis
    if is_hurt:
        for _ in range(5):
            lx = cx + random.randint(-40, 40)
            ly = torso_top + random.randint(0, 70)
            d.line([(lx, ly), (lx + random.randint(-15, 15), ly + random.randint(-15, 15))], fill=(180, 240, 255, 255), width=3)
            d.line([(lx, ly), (lx + random.randint(-20, 20), ly + random.randint(-20, 20))], fill=(255, 255, 255, 255), width=1)

    return im

# --- 2. CYBORG RUNNER (Скоростной Кибер-Гуль Спринтер) ---
def render_cyborg_runner(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    carbon_black = (28, 30, 32, 255)
    steel_shiny = (220, 225, 235, 255)
    neon_amber = (255, 150, 10, 255)
    bone_rotten = (160, 150, 135, 255)
    blood_dark = (90, 15, 15, 255)

    if is_dead:
        d.ellipse([35, 222, 230, 248], fill=(30, 10, 10, 200))
        d.polygon([(50, 226), (160, 224), (210, 240), (45, 244)], fill=carbon_black)
        d.line([(60, 228), (150, 226)], fill=steel_shiny, width=6)
        return im

    if is_die:
        d.ellipse([75, 218, 190, 248], fill=(40, 10, 10, 180))
        draw_piston(d, (130, 150), (135, 225), width=14, metal_col=steel_shiny, dark_col=carbon_black)
        return im

    # Extreme forward sprinting posture
    cx = 142
    torso_top = 88
    pelvis_y = 165
    stride = (f_idx % 4)
    stride_angles = [34, -28, 38, -32]
    leg_spread = stride_angles[stride]

    # Spine: Exposed titanium vertebrae column with flashing yellow optical fiber data cables
    d.line([(cx, torso_top), (cx - 15, pelvis_y)], fill=steel_shiny, width=8)
    for v_y in range(int(torso_top), int(pelvis_y), 8):
        d.line([(cx - 8, v_y), (cx + 8, v_y)], fill=carbon_black, width=4)
        d.ellipse([cx - 2, v_y - 2, cx + 2, v_y + 2], fill=neon_amber)

    # Legs: High-speed carbon-fiber prosthetic running blades (like cheetah blades)
    l_foot_x = cx - 15 + leg_spread * 1.5
    r_foot_x = cx + 10 - leg_spread * 1.5
    # Curved blade legs
    draw_piston(d, (cx - 12, pelvis_y), (cx - 18, 205), width=8, metal_col=steel_shiny, dark_col=carbon_black)
    d.arc([l_foot_x - 15, 195, l_foot_x + 25, 245], 45, 180, fill=steel_shiny, width=5)

    draw_piston(d, (cx + 8, pelvis_y), (cx + 14, 205), width=8, metal_col=steel_shiny, dark_col=carbon_black)
    d.arc([r_foot_x - 15, 195, r_foot_x + 25, 245], 45, 180, fill=steel_shiny, width=5)

    # Head: Aerodynamic skull helmet with triple glowing red lenses
    head_x = cx + 24
    head_y = 62
    d.ellipse([head_x - 20, head_y - 18, head_x + 20, head_y + 16], fill=carbon_black)
    d.polygon([(head_x - 18, head_y - 10), (head_x + 18, head_y - 10), (head_x + 25, head_y), (head_x - 15, head_y + 5)], fill=steel_shiny)
    # Tri-eye night vision sensor array
    d.ellipse([head_x + 5, head_y - 6, head_x + 15, head_y + 2], fill=(255, 20, 20, 255))
    d.ellipse([head_x - 5, head_y - 2, head_x + 3, head_y + 4], fill=(255, 20, 20, 255))
    d.ellipse([head_x + 8, head_y + 4, head_x + 16, head_y + 10], fill=(255, 20, 20, 255))

    # Arms: Twin high-frequency vibro-blades instead of hands
    claw_reach = 45 if f_idx in (5, 6) else 25
    draw_piston(d, (cx - 15, torso_top + 6), (cx - 35, 128), width=7, metal_col=steel_shiny, dark_col=carbon_black)
    draw_piston(d, (cx - 35, 128), (cx - 48 - claw_reach, 155), width=5, metal_col=steel_shiny, dark_col=carbon_black)
    # Serrated laser-etched vibroblade extending 35px
    d.polygon([(cx - 48 - claw_reach, 150), (cx - 88 - claw_reach, 160), (cx - 48 - claw_reach, 162)], fill=steel_shiny)
    d.line([(cx - 52 - claw_reach, 155), (cx - 84 - claw_reach, 159)], fill=neon_amber, width=2)

    draw_piston(d, (cx + 15, torso_top + 6), (cx + 32, 128), width=7, metal_col=steel_shiny, dark_col=carbon_black)
    draw_piston(d, (cx + 32, 128), (cx + 45 + claw_reach * 0.6, 150), width=5, metal_col=steel_shiny, dark_col=carbon_black)

    if is_hurt:
        for _ in range(4):
            d.line([(cx, torso_top + 15), (cx + random.randint(-30, 30), torso_top + random.randint(-10, 40))], fill=(255, 240, 150, 255), width=2)

    return im

# --- 3. CYBORG BRUTE (Бронированный Джаггернаут) ---
def render_cyborg_brute(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    armor_green = (58, 68, 54, 255) # Heavy military tank armor
    armor_dark = (28, 35, 26, 255)
    steel_shiny = (210, 218, 225, 255)
    flesh_rot = (95, 55, 60, 255)
    hazard_yellow = (235, 185, 20, 255)
    hazard_black = (25, 25, 25, 255)

    if is_dead:
        d.ellipse([20, 210, 240, 250], fill=(25, 20, 20, 220))
        d.ellipse([35, 218, 225, 246], fill=armor_dark)
        d.ellipse([60, 215, 180, 240], fill=armor_green)
        return im

    if is_die:
        d.ellipse([40, 205, 220, 250], fill=(30, 20, 20, 190))
        draw_piston(d, (128, 140), (135, 225), width=35, metal_col=steel_shiny, dark_col=armor_dark)
        return im

    cx = 128
    sway = 8 if f_idx in (1, 3) else 0
    arm_swing = 30 if f_idx == 5 else (-25 if f_idx == 6 else 0)

    # Massive armored torso with blast shields and hazard stripes
    traps = [(cx - 62, 90), (cx + 62, 90), (cx + 46, 175), (cx - 46, 175)]
    d.polygon(traps, fill=armor_dark)
    d.polygon([(cx - 58, 92), (cx + 58, 92), (cx + 42, 172), (cx - 42, 172)], fill=armor_green)
    # Sloped reactive armor plates
    d.polygon([(cx - 52, 95), (cx - 5, 95), (cx - 8, 145), (cx - 45, 142)], fill=armor_dark)
    d.polygon([(cx - 48, 97), (cx - 7, 97), (cx - 10, 142), (cx - 42, 140)], fill=armor_green)

    d.polygon([(cx + 5, 95), (cx + 52, 95), (cx + 45, 142), (cx + 8, 145)], fill=armor_dark)
    d.polygon([(cx + 7, 97), (cx + 48, 97), (cx + 42, 140), (cx + 10, 142)], fill=armor_green)

    # Industrial hazard warning stripes across belt
    for hx in range(cx - 36, cx + 36, 10):
        d.polygon([(hx, 155), (hx + 6, 155), (hx + 12, 172), (hx + 6, 172)], fill=hazard_yellow)

    # Massive pneumatic pillar legs
    draw_piston(d, (cx - 30, 172), (cx - 32, 244), width=24, metal_col=steel_shiny, dark_col=armor_dark)
    draw_piston(d, (cx + 30, 172), (cx + 32, 244), width=24, metal_col=steel_shiny, dark_col=armor_dark)

    # Armored blast helmet with narrow red slit visor
    head_y = 58
    d.ellipse([cx - 25, head_y - 22, cx + 25, head_y + 22], fill=armor_dark)
    d.ellipse([cx - 22, head_y - 20, cx + 22, head_y + 20], fill=armor_green)
    d.line([(cx - 16, head_y), (cx + 16, head_y)], fill=(255, 30, 20, 255), width=4)
    d.line([(cx - 14, head_y), (cx + 14, head_y)], fill=(255, 230, 230, 255), width=2)

    # Heavy industrial pile-driver hydraulic arms
    l_arm_y = 155 + arm_swing
    r_arm_y = 155 - arm_swing
    draw_piston(d, (cx - 58, 90), (cx - 75, l_arm_y), width=26, metal_col=steel_shiny, dark_col=armor_dark)
    draw_piston(d, (cx + 58, 90), (cx + 75, r_arm_y), width=26, metal_col=steel_shiny, dark_col=armor_dark)

    # Industrial hydraulic jackhammer knuckles on left hand
    d.rectangle([cx - 95, l_arm_y - 12, cx - 62, l_arm_y + 22], fill=armor_dark)
    d.rectangle([cx - 92, l_arm_y - 10, cx - 65, l_arm_y + 20], fill=steel_shiny)
    for spk in range(-8, 18, 8):
        d.polygon([(cx - 95, l_arm_y + spk), (cx - 108, l_arm_y + spk + 4), (cx - 95, l_arm_y + spk + 8)], fill=steel_shiny)

    # Right hand: Giant pneumatic crushing vise
    d.rectangle([cx + 62, r_arm_y - 12, cx + 95, r_arm_y + 22], fill=armor_dark)
    d.rectangle([cx + 65, r_arm_y - 10, cx + 92, r_arm_y + 20], fill=steel_shiny)

    if is_hurt:
        for _ in range(6):
            d.line([(cx - 40 + _ * 14, 110), (cx - 30 + _ * 12, 135)], fill=(255, 255, 255, 255), width=3)
            d.line([(cx - 40 + _ * 14, 110), (cx - 30 + _ * 12, 135)], fill=(120, 220, 255, 255), width=6)

    return im

# --- 4. CYBORG CRAWLER (Кибер-Паук Ползун на Гидравлических Клешнях) ---
def render_cyborg_crawler(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    steel_shiny = (215, 220, 230, 255)
    steel_dark = (40, 42, 48, 255)
    flesh_rot = (85, 95, 75, 255)
    cyber_green = (40, 255, 120, 255)
    wire_copper = (210, 120, 40, 255)

    if is_dead:
        d.ellipse([30, 225, 230, 250], fill=(20, 15, 15, 210))
        d.polygon([(50, 232), (180, 230), (210, 245), (45, 246)], fill=steel_dark)
        return im

    if is_die:
        d.ellipse([50, 215, 210, 250], fill=(30, 15, 15, 180))
        draw_piston(d, (100, 200), (140, 235), width=18, metal_col=steel_shiny, dark_col=steel_dark)
        return im

    cx = 128
    drag = (f_idx % 4)
    arm_l_x = cx - 62 + drag * 10
    arm_r_x = cx + 62 - drag * 10

    # Exposed mechanical spine connecting to small tread base
    d.ellipse([cx + 15, 210, cx + 85, 238], fill=steel_dark)
    # Exposed spinning copper servomotor coils
    for m_i in range(3):
        mx = cx + 28 + m_i * 18
        d.ellipse([mx - 7, 216, mx + 7, 230], fill=wire_copper)
        d.ellipse([mx - 4, 219, mx + 4, 227], fill=steel_shiny)

    # Torso: Low slung armored carapace with green status lights
    torso_pts = [(cx - 38, 160), (cx + 28, 182), (cx + 18, 215), (cx - 45, 198)]
    d.polygon(torso_pts, fill=steel_dark)
    d.polygon([(cx - 35, 164), (cx + 24, 184), (cx + 15, 210), (cx - 40, 195)], fill=steel_shiny)

    # Low predatory head with glowing green optical visor
    head_x = cx - 44
    head_y = 152
    d.ellipse([head_x - 22, head_y - 20, head_x + 22, head_y + 20], fill=steel_dark)
    d.ellipse([head_x - 18, head_y - 18, head_x + 18, head_y + 18], fill=flesh_rot)
    # Horrifying robotic spider mandible mouth
    d.polygon([(head_x - 16, head_y + 5), (head_x + 8, head_y + 5), (head_x - 4, head_y + 24)], fill=steel_dark)
    for spk in [-10, -2, 6]:
        d.line([(head_x + spk, head_y + 5), (head_x + spk * 1.3, head_y + 18)], fill=steel_shiny, width=3)

    # Multi-eye cyber spider cluster
    for ox, oy in [(-12, -4), (-4, -6), (4, -4), (-8, 2), (0, 2)]:
        d.ellipse([head_x + ox - 2, head_y + oy - 2, head_x + ox + 2, head_y + oy + 2], fill=cyber_green)

    # Hydraulic pincer arms digging into the sand
    draw_piston(d, (cx - 32, 175), (arm_l_x, 232), width=15, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (arm_l_x, 232), (arm_l_x - 18, 244), width=10, metal_col=steel_shiny, dark_col=steel_dark)
    d.polygon([(arm_l_x - 28, 244), (arm_l_x + 6, 244), (arm_l_x - 8, 234)], fill=steel_shiny)

    draw_piston(d, (cx + 8, 185), (arm_r_x, 232), width=15, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (arm_r_x, 232), (arm_r_x + 18, 244), width=10, metal_col=steel_shiny, dark_col=steel_dark)
    d.polygon([(arm_r_x - 6, 244), (arm_r_x + 28, 244), (arm_r_x + 8, 234)], fill=steel_shiny)

    if is_hurt:
        d.line([(cx - 20, 170), (cx + 10, 195)], fill=(255, 255, 255, 255), width=4)

    return im

# --- 5. CYBORG SPITTER (Химический Огнеметчик/Кислотомет) ---
def render_cyborg_spitter(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    steel_shiny = (210, 215, 225, 255)
    steel_dark = (42, 45, 52, 255)
    glass_tube = (60, 240, 120, 180)
    toxic_core = (180, 255, 80, 255)
    hazard_rust = (175, 85, 30, 255)

    if is_dead:
        d.ellipse([25, 215, 235, 250], fill=(20, 50, 15, 200))
        d.ellipse([50, 222, 210, 245], fill=steel_dark)
        return im

    if is_die:
        d.ellipse([60, 210, 200, 250], fill=(30, 60, 20, 180))
        draw_piston(d, (128, 150), (135, 230), width=24, metal_col=steel_shiny, dark_col=steel_dark)
        return im

    cx = 128
    head_y = 65
    torso_top = 100
    pelvis_y = 175

    # Legs
    draw_piston(d, (cx - 18, pelvis_y), (cx - 22, 244), width=14, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (cx + 18, pelvis_y), (cx + 22, 244), width=14, metal_col=steel_shiny, dark_col=steel_dark)

    # Torso: Mounted chemical containment tank on back
    d.ellipse([cx - 40, torso_top - 5, cx + 40, pelvis_y + 10], fill=steel_dark)
    # Transparent glowing chemical cannisters with bubbling neon acid
    d.rectangle([cx - 36, torso_top + 8, cx - 18, torso_top + 48], fill=steel_dark)
    d.rectangle([cx - 34, torso_top + 10, cx - 20, torso_top + 46], fill=glass_tube)
    d.ellipse([cx - 30, torso_top + 22, cx - 24, torso_top + 34], fill=toxic_core)

    d.rectangle([cx + 18, torso_top + 8, cx + 36, torso_top + 48], fill=steel_dark)
    d.rectangle([cx + 20, torso_top + 10, cx + 34, torso_top + 46], fill=glass_tube)
    d.ellipse([cx + 24, torso_top + 22, cx + 30, torso_top + 34], fill=toxic_core)

    # High pressure chemical hose connecting tank to jaw
    draw_wire(d, [(cx - 20, torso_top + 15), (cx - 12, head_y + 15), (cx, head_y + 22)], hazard_rust, width=5)

    # Head: Gas mask respirator bolted directly to rotted jawbones
    d.ellipse([cx - 22, head_y - 20, cx + 22, head_y + 18], fill=steel_dark)
    # Twin circular gas mask optical filters with glowing green lenses
    d.ellipse([cx - 16, head_y - 8, cx - 4, head_y + 4], fill=toxic_core)
    d.ellipse([cx + 4, head_y - 8, cx + 16, head_y + 4], fill=toxic_core)

    # Mechanical flame/acid nozzle valve on mouth
    d.polygon([(cx - 10, head_y + 12), (cx + 10, head_y + 12), (cx + 6, head_y + 32), (cx - 6, head_y + 32)], fill=steel_shiny)

    # Acid ejection stream on attack
    if f_idx in (5, 6):
        d.line([(cx, head_y + 28), (cx, head_y + 85)], fill=glass_tube, width=10)
        d.line([(cx, head_y + 30), (cx, head_y + 80)], fill=toxic_core, width=5)
        for dr in range(8):
            dx = cx + int(math.sin(dr * 1.5) * 18)
            dy = head_y + 50 + dr * 12
            d.ellipse([dx - 6, dy - 6, dx + 6, dy + 6], fill=toxic_core)
    else:
        d.line([(cx, head_y + 32), (cx, head_y + 45)], fill=toxic_core, width=3)

    # Arms with steel prosthetic fittings
    draw_piston(d, (cx - 38, torso_top + 10), (cx - 44, 175), width=9, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (cx + 38, torso_top + 10), (cx + 44, 175), width=9, metal_col=steel_shiny, dark_col=steel_dark)

    if is_hurt:
        d.ellipse([cx - 20, torso_top + 15, cx + 20, torso_top + 55], fill=(255, 60, 40, 160))

    return im

# --- 6. CYBORG SCREAMER (Акустический Диссонанс / Сирена) ---
def render_cyborg_screamer(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    chrome_plate = (225, 230, 240, 255)
    carbon_dark = (35, 38, 44, 255)
    sonic_cyan = (40, 220, 255, 200)
    sonic_white = (220, 255, 255, 255)

    if is_dead:
        d.ellipse([45, 225, 220, 248], fill=(20, 25, 30, 180))
        d.polygon([(65, 230), (160, 228), (200, 244), (60, 246)], fill=carbon_dark)
        return im

    if is_die:
        d.ellipse([70, 215, 190, 248], fill=(20, 25, 30, 160))
        draw_piston(d, (128, 140), (135, 230), width=12, metal_col=chrome_plate, dark_col=carbon_dark)
        return im

    cx = 128
    head_y = 50
    torso_top = 80
    pelvis_y = 158

    # Tattered carbon shroud covering lower limbs
    d.polygon([(cx - 18, pelvis_y), (cx + 18, pelvis_y), (cx + 25, 244), (cx - 25, 244)], fill=carbon_dark)
    d.line([(cx - 10, pelvis_y), (cx + 10, 240)], fill=chrome_plate, width=3)

    # Ultra-thin chrome spinal column
    draw_piston(d, (cx, torso_top), (cx, pelvis_y), width=11, metal_col=chrome_plate, dark_col=carbon_dark)

    # Raised chrome acoustic amplifier arms
    arm_angle = -45 if f_idx in (5, 6) else -22
    draw_piston(d, (cx - 16, torso_top + 6), (cx - 48, 105 + arm_angle), width=6, metal_col=chrome_plate, dark_col=carbon_dark)
    draw_piston(d, (cx + 16, torso_top + 6), (cx + 48, 105 + arm_angle), width=6, metal_col=chrome_plate, dark_col=carbon_dark)

    # Head: Cavernous parabolic sonic speaker horn replacing entire face
    d.ellipse([cx - 20, head_y - 24, cx + 20, head_y + 24], fill=carbon_dark)
    d.ellipse([cx - 16, head_y - 20, cx + 16, head_y + 20], fill=chrome_plate)

    # Deep concentric acoustic megaphone cone
    d.ellipse([cx - 12, head_y - 12, cx + 12, head_y + 16], fill=carbon_dark)
    d.ellipse([cx - 7, head_y - 7, cx + 7, head_y + 11], fill=sonic_cyan)
    d.ellipse([cx - 3, head_y - 3, cx + 3, head_y + 7], fill=sonic_white)

    # Radiating acoustic shockwave rings on scream attack
    if f_idx in (5, 6):
        for ring_r in [34, 58, 85]:
            d.arc([cx - ring_r, head_y + 2 - ring_r, cx + ring_r, head_y + 2 + ring_r], 0, 360, fill=sonic_white, width=3)
            d.arc([cx - ring_r - 2, head_y + 2 - ring_r - 2, cx + ring_r + 2, head_y + 2 + ring_r + 2], 0, 360, fill=sonic_cyan, width=1)

    if is_hurt:
        d.line([(cx - 15, head_y), (cx + 15, head_y + 30)], fill=(255, 255, 255, 255), width=3)

    return im

# --- 7. CYBORG EXPLODER (Термоядерный Дроид-Смертник) ---
def render_cyborg_exploder(f_idx):
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    is_hurt = (f_idx == 7)
    is_die = (f_idx == 8)
    is_dead = (f_idx == 9)

    steel_shiny = (215, 222, 230, 255)
    steel_dark = (38, 40, 46, 255)
    plasma_orange = (255, 110, 15, 255)
    plasma_yellow = (255, 230, 40, 255)
    plasma_white = (255, 255, 240, 255)

    if is_dead:
        d.ellipse([20, 215, 240, 250], fill=(20, 18, 16, 220))
        d.ellipse([50, 222, 210, 245], fill=(50, 25, 15, 240))
        return im

    if is_die or f_idx == 6:
        # Nuclear core meltdown explosion frame
        cx = 128
        cy = 155
        d.ellipse([10, 50, 246, 246], fill=(255, 90, 10, 220))
        d.ellipse([30, 75, 226, 235], fill=plasma_orange)
        d.ellipse([60, 100, 196, 215], fill=plasma_yellow)
        d.ellipse([90, 125, 166, 185], fill=plasma_white)
        for ray_i in range(16):
            ang = ray_i * (math.pi / 8)
            d.line([(cx, cy), (cx + math.cos(ang) * 118, cy + math.sin(ang) * 105)], fill=plasma_white, width=6)
        return im

    cx = 128
    head_y = 60
    belly_cy = 146
    belly_r = 56 + int(f_idx * 1.6)

    # Stubby titanium hydraulic legs
    draw_piston(d, (cx - 24, belly_cy + 36), (cx - 26, 244), width=18, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (cx + 24, belly_cy + 36), (cx + 26, 244), width=18, metal_col=steel_shiny, dark_col=steel_dark)

    # Tiny armored dome head with warning beacon
    d.ellipse([cx - 18, head_y - 18, cx + 18, head_y + 16], fill=steel_dark)
    d.ellipse([cx - 14, head_y - 15, cx + 14, head_y + 13], fill=steel_shiny)
    # Rotating red beacon light on top
    d.rectangle([cx - 6, head_y - 25, cx + 6, head_y - 16], fill=(255, 20, 20, 255))
    d.ellipse([cx - 4, head_y - 23, cx + 4, head_y - 18], fill=(255, 220, 220, 255))

    # Massive spherical magnetic containment sphere with leaking plasma
    d.ellipse([cx - belly_r, belly_cy - belly_r, cx + belly_r, belly_cy + belly_r], fill=steel_dark)
    d.ellipse([cx - belly_r + 4, belly_cy - belly_r + 4, cx + belly_r - 4, belly_cy + belly_r - 4], fill=(60, 30, 20, 255))

    # Intersecting steel magnetic containment bands
    d.arc([cx - belly_r, belly_cy - belly_r, cx + belly_r, belly_cy + belly_r], 0, 360, fill=steel_shiny, width=6)
    d.line([(cx - belly_r, belly_cy), (cx + belly_r, belly_cy)], fill=steel_shiny, width=7)
    d.line([(cx, belly_cy - belly_r), (cx, belly_cy + belly_r)], fill=steel_shiny, width=7)

    # Glowing plasma core breach (cracking through the shell)
    core_r = 22 + int(math.sin(f_idx * 1.5) * 6)
    d.ellipse([cx - core_r, belly_cy - core_r, cx + core_r, belly_cy + core_r], fill=plasma_orange)
    d.ellipse([cx - core_r + 5, belly_cy - core_r + 5, cx + core_r - 5, belly_cy + core_r - 5], fill=plasma_yellow)
    d.ellipse([cx - core_r + 10, belly_cy - core_r + 10, cx + core_r - 10, belly_cy + core_r - 10], fill=plasma_white)

    # Short titanium arms holding thermal detonator triggers
    draw_piston(d, (cx - belly_r + 10, belly_cy - 12), (cx - belly_r - 20, belly_cy - 22), width=10, metal_col=steel_shiny, dark_col=steel_dark)
    draw_piston(d, (cx + belly_r - 10, belly_cy - 12), (cx + belly_r + 20, belly_cy - 22), width=10, metal_col=steel_shiny, dark_col=steel_dark)

    if is_hurt:
        d.ellipse([cx - belly_r, belly_cy - belly_r, cx + belly_r, belly_cy + belly_r], fill=(255, 60, 20, 160))

    return im

def build_spritesheet(renderer, out_path):
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for f_idx in range(TOTAL_FRAMES):
        frame = renderer(f_idx)
        sheet.paste(frame, (f_idx * FRAME_W, 0))
    # High-quality smoothing pass
    sheet = sheet.filter(ImageFilter.SMOOTH_MORE)
    sheet.save(out_path, "PNG", optimize=True)
    print(f"Generated Cyborg Spritesheet: {out_path} ({SHEET_W}x{SHEET_H})")

if __name__ == "__main__":
    import os
    base_dir = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\textures"
    os.makedirs(base_dir, exist_ok=True)

    build_spritesheet(render_cyborg_walker, os.path.join(base_dir, "zombie_walker.png"))
    build_spritesheet(render_cyborg_runner, os.path.join(base_dir, "zombie_runner.png"))
    build_spritesheet(render_cyborg_brute, os.path.join(base_dir, "zombie_brute.png"))
    build_spritesheet(render_cyborg_crawler, os.path.join(base_dir, "zombie_crawler.png"))
    build_spritesheet(render_cyborg_spitter, os.path.join(base_dir, "zombie_spitter.png"))
    build_spritesheet(render_cyborg_screamer, os.path.join(base_dir, "zombie_screamer.png"))
    build_spritesheet(render_cyborg_exploder, os.path.join(base_dir, "zombie_exploder.png"))
    print("ALL 7 CYBORG ZOMBIE SPRITESHEETS CREATED!")
