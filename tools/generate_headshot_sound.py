import wave
import struct
import math

sample_rate = 44100
duration = 0.28  # seconds
num_samples = int(sample_rate * duration)

out_path = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\audio\headshot.wav"

frames = bytearray()
for i in range(num_samples):
    t = float(i) / sample_rate
    
    # Fast initial attack click (crunch/impact)
    click = (1.0 - math.exp(-t * 200.0)) * math.exp(-t * 40.0) * (math.sin(2.0 * math.pi * 320.0 * t))
    
    # Sharp metallic high tone (ping/ding like helmet penetration / skull crack)
    tone1 = math.sin(2.0 * math.pi * 1760.0 * t) * math.exp(-t * 18.0)
    tone2 = math.sin(2.0 * math.pi * 2640.0 * t) * math.exp(-t * 24.0) * 0.6
    tone3 = math.sin(2.0 * math.pi * 880.0 * t) * math.exp(-t * 12.0) * 0.4
    
    # High frequency crackle/spark
    noise = (math.sin(t * 15432.0) * 0.15) * math.exp(-t * 35.0)
    
    sample = (click * 0.5 + tone1 * 0.45 + tone2 * 0.3 + tone3 * 0.25 + noise) * 0.85
    sample = max(-1.0, min(1.0, sample))
    
    val = int(sample * 32767.0)
    frames += struct.pack('<h', val)

with wave.open(out_path, 'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)
    wav.writeframes(frames)

print(f"Generated headshot sound to: {out_path}")
