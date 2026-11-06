import wave
import struct
import math

sample_rate = 44100
duration = 0.22
num_samples = int(sample_rate * duration)
out_path = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\audio\item_pickup.wav"

frames = bytearray()
for i in range(num_samples):
    t = float(i) / sample_rate
    # 2-tone pleasant loot chime
    f = 587.33 if t < 0.08 else 880.0
    env = math.exp(-(t if t < 0.08 else (t - 0.08)) * 18.0)
    sample = math.sin(2.0 * math.pi * f * t) * env * 0.75
    sample += math.sin(2.0 * math.pi * f * 2.0 * t) * env * 0.25
    val = int(max(-1.0, min(1.0, sample)) * 32767.0)
    frames += struct.pack('<h', val)

with wave.open(out_path, 'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)
    wav.writeframes(frames)

print(f"Generated item pickup sound to: {out_path}")
