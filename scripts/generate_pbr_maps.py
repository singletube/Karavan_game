"""
generate_pbr_maps.py
Generates Normal Maps and Roughness Maps from Albedo textures using numpy & PIL.
"""

import sys
import os
import numpy as np
from PIL import Image

def generate_normal_and_roughness(albedo_path, bump_strength=3.0, invert_y=False):
    if not os.path.exists(albedo_path):
        print(f"File not found: {albedo_path}")
        return None, None
        
    img = Image.open(albedo_path).convert("RGB")
    arr = np.array(img, dtype=np.float32) / 255.0
    
    # Grayscale height approximation
    height = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    
    # Sobel filters for dx, dy
    # dy (vertical gradient), dx (horizontal gradient)
    gy, gx = np.gradient(height)
    
    gx = gx * bump_strength
    gy = gy * bump_strength * (-1.0 if invert_y else 1.0)
    gz = np.ones_like(gx)
    
    norm = np.sqrt(gx**2 + gy**2 + gz**2)
    nx = gx / norm
    ny = gy / norm
    nz = gz / norm
    
    # Map from [-1, 1] to [0, 255]
    normal_map = np.zeros_like(arr)
    normal_map[:, :, 0] = (nx * 0.5 + 0.5) * 255.0
    normal_map[:, :, 1] = (ny * 0.5 + 0.5) * 255.0
    normal_map[:, :, 2] = (nz * 0.5 + 0.5) * 255.0
    normal_img = Image.fromarray(normal_map.astype(np.uint8))
    
    # Roughness: high contrast variation
    roughness = np.clip((1.0 - height * 0.4) * 255.0, 40, 250).astype(np.uint8)
    roughness_img = Image.fromarray(roughness, mode='L')
    
    base_name, _ = os.path.splitext(albedo_path)
    normal_path = f"{base_name}_normal.png"
    roughness_path = f"{base_name}_roughness.png"
    
    normal_img.save(normal_path)
    roughness_img.save(roughness_path)
    print(f"Generated: {normal_path} and {roughness_path}")
    return normal_path, roughness_path

if __name__ == "__main__":
    if len(sys.argv) > 1:
        generate_normal_and_roughness(sys.argv[1])
