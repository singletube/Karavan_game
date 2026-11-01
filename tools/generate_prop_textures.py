"""
Procedural Texture Generator for Apocalypse Prop Library & Terrain
Generates high-detail textures with noise, patterns, and weathering into assets/textures/props/
"""
import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = os.path.join("assets", "textures", "props")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def clamp(v, low=0, high=255):
    return max(low, min(high, int(v)))

# Simple deterministic value noise
def pseudo_noise(x, y, seed=42):
    n = int(x * 374761393 + y * 668265263 + seed * 999999937) & 0x7FFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return float(n & 0xFFFF) / 65535.0

def smooth_noise(x, y, seed=42):
    ix, iy = int(x), int(y)
    fx, fy = x - ix, y - iy
    # Smoothstep
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    v00 = pseudo_noise(ix, iy, seed)
    v10 = pseudo_noise(ix + 1, iy, seed)
    v01 = pseudo_noise(ix, iy + 1, seed)
    v11 = pseudo_noise(ix + 1, iy + 1, seed)
    v0 = v00 * (1.0 - fx) + v10 * fx
    v1 = v01 * (1.0 - fx) + v11 * fx
    return v0 * (1.0 - fy) + v1 * fy

def fbm(x, y, octaves=4, seed=42):
    val = 0.0
    amp = 0.5
    freq = 1.0
    for o in range(octaves):
        val += smooth_noise(x * freq, y * freq, seed + o * 100) * amp
        amp *= 0.5
        freq *= 2.0
    return val

# -------------------------------------------------------------
# 1. TIRE TREAD TEXTURE (512x512)
# -------------------------------------------------------------
def generate_tire_tread():
    img = Image.new("RGBA", (512, 512), (28, 28, 30, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Dark charcoal base with fine rubber grain
    for y in range(512):
        for x in range(512):
            n = fbm(x * 0.05, y * 0.05, 3, seed=12)
            c = clamp(26 + (n - 0.5) * 16)
            pixels[x, y] = (c, c, int(c * 1.05), 255)

    # Longitudinal groove channels (deep black grooves)
    grooves = [64, 192, 320, 448]
    for gx in grooves:
        for offset in range(-8, 9):
            x = gx + offset
            depth = 1.0 - abs(offset) / 8.0
            for y in range(512):
                r, g, b, a = pixels[x, y]
                shadow = 1.0 - depth * 0.75
                pixels[x, y] = (clamp(r * shadow), clamp(g * shadow), clamp(b * shadow), 255)

    # Diagonal tread lugs & sipes
    lug_h = 32
    for y in range(0, 512, lug_h):
        # Draw chevron cuts across tread
        for x in range(0, 512):
            wave = int(math.sin(x * 0.04) * 8)
            py = (y + wave) % 512
            if abs(y % lug_h) < 4:
                r, g, b, a = pixels[x, py]
                pixels[x, py] = (clamp(r * 0.35), clamp(g * 0.35), clamp(b * 0.35), 255)

    path = os.path.join(OUTPUT_DIR, "tire_tread.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 2. HAZARD OIL DRUM (512x512)
# -------------------------------------------------------------
def generate_barrel_hazard():
    img = Image.new("RGBA", (512, 512), (220, 180, 25, 255))
    pixels = img.load()

    # Weathered yellow with diagonal black caution stripes
    stripe_w = 64
    for y in range(512):
        for x in range(512):
            # 45-degree stripe
            is_black = ((x + y) // stripe_w) % 2 == 0
            rust_n = fbm(x * 0.02, y * 0.02, 4, seed=88)
            
            if is_black:
                base_r, base_g, base_b = 32, 32, 34
            else:
                base_r, base_g, base_b = 215, 175, 22

            # Heavy rust chipping
            if rust_n > 0.62:
                rust_factor = (rust_n - 0.62) / 0.38
                base_r = clamp(base_r * (1.0 - rust_factor) + 115 * rust_factor)
                base_g = clamp(base_g * (1.0 - rust_factor) + 55 * rust_factor)
                base_b = clamp(base_b * (1.0 - rust_factor) + 32 * rust_factor)

            # Metal surface noise
            noise = (pseudo_noise(x, y, 99) - 0.5) * 18
            pixels[x, y] = (clamp(base_r + noise), clamp(base_g + noise), clamp(base_b + noise), 255)

    # Stenciled Biohazard / Radioactive symbol in center
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    # Outer ring
    draw.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], outline=(30, 25, 22, 220), width=8)
    draw.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], fill=(30, 25, 22, 240))
    # 3 biohazard leaves
    for angle in [0, 120, 240]:
        rad = math.radians(angle)
        lx = cx + int(math.cos(rad) * 45)
        ly = cy + int(math.sin(rad) * 45)
        draw.ellipse([lx - 32, ly - 32, lx + 32, ly + 32], outline=(30, 25, 22, 230), width=10)

    path = os.path.join(OUTPUT_DIR, "barrel_hazard.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 3. RED FLAMMABLE DRUM (512x512)
# -------------------------------------------------------------
def generate_barrel_red():
    img = Image.new("RGBA", (512, 512), (185, 35, 25, 255))
    pixels = img.load()

    for y in range(512):
        for x in range(512):
            n = fbm(x * 0.025, y * 0.025, 4, seed=44)
            r = clamp(175 + (n - 0.5) * 40)
            g = clamp(32 + (n - 0.5) * 15)
            b = clamp(24 + (n - 0.5) * 10)

            # Scratched rust patches
            if n > 0.65:
                rf = (n - 0.65) / 0.35
                r = clamp(r * (1 - rf) + 90 * rf)
                g = clamp(g * (1 - rf) + 48 * rf)
                b = clamp(b * (1 - rf) + 30 * rf)

            grain = (pseudo_noise(x, y, 77) - 0.5) * 14
            pixels[x, y] = (clamp(r + grain), clamp(g + grain), clamp(b + grain), 255)

    # White stenciled warning band
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 210, 512, 300], fill=(235, 230, 220, 200))
    # Stencil border marks
    for x in range(20, 500, 30):
        draw.line([(x, 215), (x + 15, 295)], fill=(175, 30, 20, 180), width=4)

    path = os.path.join(OUTPUT_DIR, "barrel_red.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 4. PALM BARK & FROND TEXTURES (512x512)
# -------------------------------------------------------------
def generate_palm_bark():
    img = Image.new("RGBA", (512, 512), (85, 62, 45, 255))
    pixels = img.load()

    for y in range(512):
        ring = math.sin(y * 0.12) * 22
        for x in range(512):
            fiber = fbm(x * 0.15, y * 0.02, 3, seed=55) * 35
            r = clamp(85 + ring + fiber)
            g = clamp(60 + ring * 0.8 + fiber * 0.8)
            b = clamp(42 + ring * 0.6 + fiber * 0.6)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "palm_bark.png")
    img.save(path)
    print("Saved:", path)

def generate_palm_leaf():
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Draw tapered pinnate leaf blade down the center (Y: 0 to 512)
    cx = 256
    for y in range(512):
        # Leaf width profile
        frac = y / 512.0
        width = math.sin(frac * math.pi) * 210.0 + 8.0
        for x in range(int(cx - width), int(cx + width)):
            dist = abs(x - cx) / width
            # Leaflet ridges
            ridge = math.sin(dist * 28.0 + y * 0.2) * 20.0
            r = clamp(35 + ridge * 0.5)
            g = clamp(115 - dist * 45 + ridge)
            b = clamp(28 - dist * 15)
            pixels[x, y] = (r, g, b, 255)

    # Central rachis (thick yellow-green central vein)
    for y in range(512):
        for ox in range(-5, 6):
            pixels[cx + ox, y] = (145, 160, 48, 255)

    path = os.path.join(OUTPUT_DIR, "palm_leaf.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 5. WEAPONS: BLUED STEEL & WALNUT (512x512)
# -------------------------------------------------------------
def generate_blued_metal():
    img = Image.new("RGBA", (512, 512), (38, 42, 48, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            brushed = fbm(x * 0.25, y * 0.02, 3, seed=22) * 18
            n = (pseudo_noise(x, y, 33) - 0.5) * 12
            c = clamp(40 + brushed + n)
            # Subtle iridescent blue-gunmetal hue
            pixels[x, y] = (c, clamp(c * 1.08), clamp(c * 1.25), 255)

    path = os.path.join(OUTPUT_DIR, "blued_metal.png")
    img.save(path)
    print("Saved:", path)

def generate_walnut_wood():
    img = Image.new("RGBA", (512, 512), (95, 52, 28, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            grain = math.sin(x * 0.08 + fbm(x * 0.02, y * 0.02, 3, seed=90) * 12.0) * 28.0
            r = clamp(98 + grain)
            g = clamp(54 + grain * 0.6)
            b = clamp(26 + grain * 0.35)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "walnut_wood.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 6. BONE & CYBERNETIC CIRCUIT (512x512)
# -------------------------------------------------------------
def generate_skull_bone():
    img = Image.new("RGBA", (512, 512), (225, 218, 200, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            n = fbm(x * 0.04, y * 0.04, 4, seed=15)
            r = clamp(225 + (n - 0.5) * 32)
            g = clamp(215 + (n - 0.5) * 32)
            b = clamp(195 + (n - 0.5) * 32)
            # Weathered porous dirt
            if n < 0.25:
                r = clamp(r - 40)
                g = clamp(g - 45)
                b = clamp(b - 45)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "skull_bone.png")
    img.save(path)
    print("Saved:", path)

def generate_cyber_circuit():
    img = Image.new("RGBA", (512, 512), (22, 24, 28, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Dark titanium hexagonal panels
    for y in range(0, 512, 64):
        for x in range(0, 512, 64):
            draw.rectangle([x, y, x + 60, y + 60], outline=(45, 48, 55, 255), width=2)

    # Intricate glowing circuit lines (cyan & neon red)
    lines_cyan = [
        [(32, 32), (32, 160), (96, 224), (256, 224)],
        [(256, 224), (384, 224), (448, 288), (448, 448)],
        [(128, 64), (128, 128), (224, 128)],
        [(300, 350), (380, 350), (380, 480)]
    ]
    for pts in lines_cyan:
        draw.line(pts, fill=(15, 220, 255, 255), width=4)
        for p in pts:
            draw.ellipse([p[0] - 6, p[1] - 6, p[0] + 6, p[1] + 6], fill=(180, 245, 255, 255))

    lines_red = [
        [(448, 64), (448, 160), (350, 160)],
        [(64, 380), (160, 380), (160, 448)],
        [(256, 128), (256, 224)]
    ]
    for pts in lines_red:
        draw.line(pts, fill=(255, 30, 20, 255), width=4)
        for p in pts:
            draw.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], fill=(255, 140, 120, 255))

    path = os.path.join(OUTPUT_DIR, "cyber_circuit.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 7. FORTIFICATIONS: SANDBAG BURLAP & CORRUGATED RUST (512x512)
# -------------------------------------------------------------
def generate_sandbag_burlap():
    img = Image.new("RGBA", (512, 512), (155, 135, 105, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            # Coarse cross weave
            weave_x = math.sin(x * 0.8) * 16
            weave_y = math.sin(y * 0.8) * 16
            dirt = fbm(x * 0.03, y * 0.03, 3, seed=71) * 30
            r = clamp(155 + weave_x + dirt)
            g = clamp(135 + weave_y + dirt * 0.85)
            b = clamp(105 + (weave_x + weave_y) * 0.5 + dirt * 0.7)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "sandbag_burlap.png")
    img.save(path)
    print("Saved:", path)

def generate_corrugated_rust():
    img = Image.new("RGBA", (512, 512), (120, 115, 110, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            # Corrugated wavy vertical profile
            wave = math.sin(x * 0.12) * 35
            rust_n = fbm(x * 0.03, y * 0.03, 4, seed=63)
            r = clamp(120 + wave)
            g = clamp(115 + wave)
            b = clamp(110 + wave)
            if rust_n > 0.50:
                rf = (rust_n - 0.50) / 0.50
                r = clamp(r * (1 - rf) + 145 * rf)
                g = clamp(g * (1 - rf) + 65 * rf)
                b = clamp(b * (1 - rf) + 35 * rf)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "corrugated_rust.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 8. WARNING SIGN CYBORG HAZARD (512x512)
# -------------------------------------------------------------
def generate_warning_sign():
    img = Image.new("RGBA", (512, 512), (230, 185, 30, 255))
    draw = ImageDraw.Draw(img)

    # Black warning border
    draw.rectangle([16, 16, 496, 496], outline=(25, 25, 25, 255), width=18)
    draw.rectangle([38, 38, 474, 474], outline=(25, 25, 25, 255), width=4)

    # Header banner
    draw.rectangle([42, 42, 470, 130], fill=(210, 25, 20, 255))

    # Skull / Cyborg eye icon in center
    cx, cy = 256, 260
    # Skull dome
    draw.ellipse([cx - 75, cy - 80, cx + 75, cy + 50], fill=(25, 25, 25, 255))
    draw.rectangle([cx - 45, cy + 15, cx + 45, cy + 75], fill=(25, 25, 25, 255))
    # Eye sockets (Left hollow, Right glowing red cyber eye)
    draw.ellipse([cx - 48, cy - 20, cx - 12, cy + 16], fill=(230, 185, 30, 255))
    draw.ellipse([cx + 12, cy - 20, cx + 48, cy + 16], fill=(255, 30, 20, 255))
    draw.ellipse([cx + 22, cy - 10, cx + 38, cy + 6], fill=(255, 230, 230, 255))

    # Teeth slits
    for tx in range(cx - 30, cx + 35, 14):
        draw.line([(tx, cy + 30), (tx, cy + 68)], fill=(230, 185, 30, 255), width=4)

    # Crossbones / Hazard bars underneath
    draw.rectangle([64, 400, 448, 450], fill=(25, 25, 25, 255))

    path = os.path.join(OUTPUT_DIR, "warning_sign_cyborg.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 9. NEW TERRAIN: RED CANYON ROCK & TOXIC SLUDGE (512x512)
# -------------------------------------------------------------
def generate_red_canyon_rock():
    img = Image.new("RGBA", (512, 512), (165, 82, 55, 255))
    pixels = img.load()
    for y in range(512):
        # Sedimentary strata lines
        strata = math.sin(y * 0.08 + math.sin(y * 0.02) * 4.0) * 32.0
        for x in range(512):
            n = fbm(x * 0.03, y * 0.015, 4, seed=101) * 25.0
            r = clamp(168 + strata + n)
            g = clamp(85 + strata * 0.6 + n * 0.5)
            b = clamp(56 + strata * 0.4 + n * 0.3)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "red_canyon_rock.png")
    img.save(path)
    print("Saved:", path)

def generate_toxic_sludge_ground():
    img = Image.new("RGBA", (512, 512), (45, 42, 38, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            cracks = fbm(x * 0.04, y * 0.04, 4, seed=777)
            # Fissures with glowing toxic green/cyan veins
            if 0.48 < cracks < 0.54:
                # Glowing vein
                glow = 1.0 - abs(cracks - 0.51) / 0.03
                r = clamp(30 + glow * 50)
                g = clamp(180 + glow * 75)
                b = clamp(50 + glow * 80)
            else:
                # Scorched black/dark earth
                soil = (pseudo_noise(x, y, 5) - 0.5) * 15
                r = clamp(42 + soil)
                g = clamp(40 + soil)
                b = clamp(36 + soil)
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "toxic_sludge_ground.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 10. CACTUS SKIN (512x512)
# -------------------------------------------------------------
def generate_cactus_skin():
    img = Image.new("RGBA", (512, 512), (55, 115, 48, 255))
    pixels = img.load()
    for y in range(512):
        for x in range(512):
            # Vertical accordion pleated ribs
            rib = math.sin(x * 0.16) * 32.0
            wax = (pseudo_noise(x, y, 11) - 0.5) * 12.0
            r = clamp(52 + rib * 0.6 + wax)
            g = clamp(118 + rib + wax)
            b = clamp(46 + rib * 0.5 + wax)
            # Spine cluster areoles at regular intervals along rib crests
            if math.cos(x * 0.16) > 0.92 and (y % 32 < 4):
                r, g, b = 230, 215, 140
            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "cactus_skin.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 16. FORTIFIED BUNKER CONCRETE (512x512)
# -------------------------------------------------------------
def generate_bunker_concrete():
    img = Image.new("RGBA", (512, 512), (105, 108, 106, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Heavy aggregate concrete with noise and formwork pitting
    for y in range(512):
        for x in range(512):
            base_n = fbm(x * 0.04, y * 0.04, 4, seed=331)
            fine_n = pseudo_noise(x, y, 77)
            c = clamp(100 + (base_n - 0.5) * 36 + (fine_n - 0.5) * 14)
            # Slight cold military olive tint
            r = clamp(c * 0.96)
            g = clamp(c * 1.0)
            b = clamp(c * 0.94)

            # Concrete formwork panel seam grooves at y=128, 256, 384 and x=256
            if y % 128 in [0, 1] or x in [255, 256]:
                r, g, b = clamp(r * 0.6), clamp(g * 0.6), clamp(b * 0.6)

            # Rust/grime water drip stains running down from rebar anchors
            if x % 64 in [31, 32] and y > 32:
                drip = math.exp(-((x % 64 - 31.5) ** 2) / 2.0) * math.sin(y * 0.05 + 1.0)
                if drip > 0.2:
                    r = clamp(r + drip * 45)
                    g = clamp(g - drip * 15)
                    b = clamp(b - drip * 25)

            pixels[x, y] = (r, g, b, 255)

    # Formwork tie-rod circular indentations with rust cores
    for py in [64, 192, 320, 448]:
        for px in [64, 192, 320, 448]:
            draw.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(55, 58, 56, 255), outline=(130, 135, 130, 255))
            draw.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(120, 60, 30, 255))

    path = os.path.join(OUTPUT_DIR, "bunker_concrete.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 17. ANCIENT TEMPLE SANDSTONE (512x512)
# -------------------------------------------------------------
def generate_ancient_temple_stone():
    img = Image.new("RGBA", (512, 512), (195, 168, 125, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Sandstone grain and mineral strata
    for y in range(512):
        for x in range(512):
            grain = fbm(x * 0.035, y * 0.015, 4, seed=512)
            fine = pseudo_noise(x, y, 99)
            base = 175 + (grain - 0.5) * 45 + (fine - 0.5) * 12
            r = clamp(base * 1.12)
            g = clamp(base * 0.96)
            b = clamp(base * 0.72)

            # Carved ashlar block mortar lines
            # Courses every 96 pixels with alternating staggered vertical joints
            course = y // 96
            in_course_y = y % 96
            x_shift = 128 if (course % 2 == 1) else 0
            in_block_x = (x + x_shift) % 256

            if in_course_y in [0, 1, 2] or in_block_x in [0, 1, 2]:
                r = clamp(r * 0.55)
                g = clamp(g * 0.52)
                b = clamp(b * 0.45)
            elif in_course_y in [3, 4] or in_block_x in [3, 4]:
                # Chiseled block bevel highlight
                r = clamp(r * 1.15)
                g = clamp(g * 1.12)
                b = clamp(b * 1.08)

            pixels[x, y] = (r, g, b, 255)

    # Decorative carved frieze meander / chevron relief band across y in [240..272]
    for x in range(0, 512, 32):
        draw.line([(x, 244), (x + 16, 268), (x + 32, 244)], fill=(130, 110, 80, 255), width=3)
        draw.line([(x, 242), (x + 16, 266), (x + 32, 242)], fill=(225, 200, 160, 255), width=1)

    path = os.path.join(OUTPUT_DIR, "ancient_temple_stone.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 18. CRASHED PLANE RIVETED METAL (512x512)
# -------------------------------------------------------------
def generate_plane_rivets():
    img = Image.new("RGBA", (512, 512), (180, 184, 188, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Brushed aircraft duralumin skin with scratches and oxidation
    for y in range(512):
        for x in range(512):
            brushed = (pseudo_noise(x, y // 2, 401) - 0.5) * 18.0
            panel_n = fbm(x * 0.02, y * 0.02, 3, seed=88)
            val = clamp(178 + brushed + (panel_n - 0.5) * 22)
            r = clamp(val * 0.98)
            g = clamp(val * 1.00)
            b = clamp(val * 1.04)

            # Overlapping lap joint seams every 128px horizontally & 256px vertically
            if y % 128 in [0, 1]:
                r, g, b = clamp(r * 0.6), clamp(g * 0.6), clamp(b * 0.62)
            elif y % 128 in [2, 3]:
                r, g, b = clamp(r * 1.25), clamp(g * 1.25), clamp(b * 1.28)

            # Scorched black / thermal distress streak
            if 340 < x < 460 and y > 200:
                dist = math.exp(-((x - 400) ** 2) / 800.0) * math.sin(y * 0.02)
                if dist > 0.15:
                    r = clamp(r * (1.0 - dist * 0.75))
                    g = clamp(g * (1.0 - dist * 0.80))
                    b = clamp(b * (1.0 - dist * 0.85))

            pixels[x, y] = (r, g, b, 255)

    # Rivet lines along panel seams
    for y_seam in [128, 256, 384]:
        for x_rivet in range(8, 512, 16):
            draw.ellipse([x_rivet - 3, y_seam - 10 - 3, x_rivet + 3, y_seam - 10 + 3], fill=(135, 138, 142, 255), outline=(220, 225, 230, 255))
            draw.ellipse([x_rivet - 3, y_seam + 10 - 3, x_rivet + 3, y_seam + 10 + 3], fill=(135, 138, 142, 255), outline=(220, 225, 230, 255))

    path = os.path.join(OUTPUT_DIR, "plane_rivets.png")
    img.save(path)
    print("Saved:", path)

# -------------------------------------------------------------
# 19. ADOBE MUD BRICK (512x512)
# -------------------------------------------------------------
def generate_adobe_brick():
    img = Image.new("RGBA", (512, 512), (180, 125, 85, 255))
    draw = ImageDraw.Draw(img)
    pixels = img.load()

    # Earthy terracotta mud brick with chopped straw flecks and drying cracks
    for y in range(512):
        for x in range(512):
            clay_n = fbm(x * 0.04, y * 0.04, 4, seed=702)
            speck = pseudo_noise(x, y, 313)
            base = 145 + (clay_n - 0.5) * 40
            r = clamp(base * 1.25)
            g = clamp(base * 0.88)
            b = clamp(base * 0.60)

            # Straw fiber flecks
            if speck > 0.94:
                r, g, b = 220, 195, 110

            # Irregular clay brick courses
            course = y // 64
            in_c_y = y % 64
            x_off = 100 if (course % 2 == 1) else 0
            in_b_x = (x + x_off) % 200

            if in_c_y in [0, 1, 2] or in_b_x in [0, 1, 2]:
                r = clamp(r * 0.65)
                g = clamp(g * 0.60)
                b = clamp(b * 0.52)

            pixels[x, y] = (r, g, b, 255)

    path = os.path.join(OUTPUT_DIR, "adobe_brick.png")
    img.save(path)
    print("Saved:", path)

if __name__ == "__main__":
    print("Generating comprehensive PBR texture library for apocalypse models...")
    generate_tire_tread()
    generate_barrel_hazard()
    generate_barrel_red()
    generate_palm_bark()
    generate_palm_leaf()
    generate_blued_metal()
    generate_walnut_wood()
    generate_skull_bone()
    generate_cyber_circuit()
    generate_sandbag_burlap()
    generate_corrugated_rust()
    generate_warning_sign()
    generate_red_canyon_rock()
    generate_toxic_sludge_ground()
    generate_cactus_skin()
    generate_bunker_concrete()
    generate_ancient_temple_stone()
    generate_plane_rivets()
    generate_adobe_brick()
    print("All textures generated successfully!")
