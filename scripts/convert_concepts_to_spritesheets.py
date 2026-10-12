"""
Converts generated photorealistic AI concepts into game-ready 10-frame spritesheets.
Isolates characters by removing background, extracts alpha mask,
and generates walk/attack/hurt/die/dead animation states via anatomical spatial transforms.
Saves directly into assets/textures/zombie_*.png
"""

import os
import glob
from PIL import Image, ImageOps, ImageEnhance, ImageFilter

FRAME_W = 256
FRAME_H = 256
TOTAL_FRAMES = 10
SHEET_W = FRAME_W * TOTAL_FRAMES
SHEET_H = FRAME_H

def remove_white_bg(img, threshold=238):
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        r, g, b, a = item
        # If pixel is close to pure white / light paper
        if r > threshold and g > threshold and b > threshold:
            # Smooth fade at boundary
            diff = min(r, min(g, b)) - threshold
            alpha = max(0, int(255 - (diff / (255 - threshold)) * 255))
            new_data.append((r, g, b, alpha))
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

def fit_to_frame(img, max_h=230, max_w=200):
    # Get bounding box of non-transparent pixels
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # Scale while maintaining aspect ratio
    w, h = img.size
    ratio = min(max_w / w, max_h / h)
    new_w = max(1, int(w * ratio))
    new_h = max(1, int(h * ratio))
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    return img

def create_animated_spritesheet(concept_img, out_path, is_crawler=False):
    isolated = remove_white_bg(concept_img)
    base_sprite = fit_to_frame(isolated, max_h=190 if is_crawler else 235, max_w=225 if is_crawler else 190)
    
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    bw, bh = base_sprite.size
    
    # Base ground placement
    base_x = (FRAME_W - bw) // 2
    base_y = (FRAME_H - bh) - 10

    for f in range(TOTAL_FRAMES):
        frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
        ox = base_x
        oy = base_y
        spr = base_sprite.copy()

        if f == 0:
            # Idle stance
            pass
        elif f == 1:
            # Step left: slight tilt & lift
            spr = spr.rotate(3.5, resample=Image.Resampling.BILINEAR, expand=False)
            ox -= 6
            oy -= 5
        elif f == 2:
            # Plant left
            ox -= 2
        elif f == 3:
            # Step right: slight tilt opposite
            spr = spr.rotate(-3.5, resample=Image.Resampling.BILINEAR, expand=False)
            ox += 6
            oy -= 5
        elif f == 4:
            # Plant right
            ox += 2
        elif f == 5:
            # Attack windup (rearing back, scaling up slightly)
            w_scaled = int(bw * 1.08)
            h_scaled = int(bh * 1.06)
            spr = spr.resize((w_scaled, h_scaled), Image.Resampling.LANCZOS)
            ox = (FRAME_W - w_scaled) // 2
            oy -= 12
        elif f == 6:
            # Attack strike (lunge forward)
            w_scaled = int(bw * 1.15)
            h_scaled = int(bh * 1.02)
            spr = spr.resize((w_scaled, h_scaled), Image.Resampling.LANCZOS)
            ox = (FRAME_W - w_scaled) // 2
            oy += 6
        elif f == 7:
            # Hurt flinch (knocked back, flash bright red/cyan)
            spr = spr.rotate(-9.0, resample=Image.Resampling.BILINEAR, expand=False)
            ox += 12
            # Tint damage overlay
            r, g, b, a = spr.split()
            r_enh = ImageEnhance.Brightness(r).enhance(2.2)
            spr = Image.merge("RGBA", (r_enh, g, b, a))
        elif f == 8:
            # Dying / falling backwards
            spr = spr.rotate(-45.0, resample=Image.Resampling.BILINEAR, expand=True)
            spr = spr.resize((int(spr.width * 0.85), int(spr.height * 0.7)), Image.Resampling.LANCZOS)
            ox = (FRAME_W - spr.width) // 2
            oy = FRAME_H - spr.height - 15
        elif f == 9:
            # Dead on ground (flat horizontal orientation)
            spr = spr.rotate(-85.0, resample=Image.Resampling.BILINEAR, expand=True)
            spr = spr.resize((int(spr.width * 0.95), int(spr.height * 0.42)), Image.Resampling.LANCZOS)
            ox = (FRAME_W - spr.width) // 2
            oy = FRAME_H - spr.height - 8

        frame.paste(spr, (ox, oy), spr)
        sheet.paste(frame, (f * FRAME_W, 0))

    sheet.save(out_path, "PNG", optimize=True)
    print(f"Exported Photorealistic Spritesheet: {out_path} ({SHEET_W}x{SHEET_H})")

if __name__ == "__main__":
    concept_dir = r"C:\Users\user\.gemini\antigravity\brain\648db63a-c814-40a9-817a-7195fe9a5e11"
    target_dir = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\textures"

    mapping = [
        ("cyborg_walker_zombie_*.jpg", "zombie_walker.png", False),
        ("cyborg_runner_ghoul_*.jpg", "zombie_runner.png", False),
        ("cyborg_brute_tank_*.jpg", "zombie_brute.png", False),
        ("cyborg_crawler_spider_*.jpg", "zombie_crawler.png", True),
        ("cyborg_spitter_chemical_*.jpg", "zombie_spitter.png", False),
        ("cyborg_screamer_siren_*.jpg", "zombie_screamer.png", False),
        ("cyborg_exploder_drone_*.jpg", "zombie_exploder.png", False),
    ]

    for pat, out_name, is_crawler in mapping:
        matches = glob.glob(os.path.join(concept_dir, pat))
        if matches:
            src = matches[-1]
            img = Image.open(src)
            out_file = os.path.join(target_dir, out_name)
            create_animated_spritesheet(img, out_file, is_crawler=is_crawler)
    print("ALL 7 PHOTOREALISTIC CONCEPT SPRITESHEETS CONVERTED!")
