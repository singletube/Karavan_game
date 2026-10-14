"""
Generates high quality 16-bit 44.1kHz mono WAV sound effects for 'Идёт караван из Ирана'.
Pure standard library Python (struct, wave, math, random).
Generates:
1. shoot_revolver.wav - heavy crack, punchy low transient, metallic hammer tail
2. shoot_shotgun.wav - massive boom, 10-pellet scatter explosion, chest thump
3. shoot_rifle.wav - snappy military supersonic report, crisp metallic snap
4. shoot_rocket.wav - huge ignition blast, roaring rocket propellant thrust
5. reload_click.wav - crisp mechanical chamber snap / bolt rack
6. step_sand.wav - crunchy desert sand footstep, shifting granules
7. zombie_groan.wav - eerie low-frequency guttural zombie growl
8. zombie_screamer.wav - piercing high-frequency sonic banshee screech
9. zombie_acid.wav - sickening sizzle and toxic spit projectile sound
10. zombie_bite.wav - violent wet flesh crunch / claw tear
11. explosion.wav - apocalyptic deep bass rumble and destructive shockwave
12. zombie_die.wav - visceral death rattle and bone crunch
13. player_hurt.wav - heavy blunt impact grunt and blood rush
14. wave_start.wav - ominous war gong / desert horn fanfare
15. wave_win.wav - triumphant survival chime
"""

import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100

def clamp(v, min_v=-1.0, max_v=1.0):
    return max(min_v, min(max_v, v))

def write_wav(filepath, samples):
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        # Convert float (-1.0 to 1.0) to 16-bit signed int
        raw_data = bytearray()
        for s in samples:
            val = int(clamp(s) * 32767.0)
            raw_data.extend(struct.pack('<h', val))
        wf.writeframes(raw_data)
    print(f"Generated WAV: {filepath} ({len(samples)/SAMPLE_RATE:.2f}s)")

# --- Sound Synthesis Helpers ---

def noise_gen(count):
    return [random.uniform(-1.0, 1.0) for _ in range(count)]

def lowpass_filter(samples, cutoff_ratio=0.1):
    out = []
    prev = 0.0
    for s in samples:
        curr = prev + cutoff_ratio * (s - prev)
        out.append(curr)
        prev = curr
    return out

def env_adsr(length, a_len, d_len, s_lvl, r_len):
    out = []
    for i in range(length):
        if i < a_len:
            out.append(i / max(1, a_len))
        elif i < a_len + d_len:
            prog = (i - a_len) / max(1, d_len)
            out.append(1.0 - prog * (1.0 - s_lvl))
        elif i < length - r_len:
            out.append(s_lvl)
        else:
            prog = (i - (length - r_len)) / max(1, r_len)
            out.append(s_lvl * (1.0 - prog))
    return out

# --- 1. Revolver .44 ---
def gen_revolver():
    dur = 0.45
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Punchy low body (80Hz dropping to 35Hz)
        freq = 110.0 * math.exp(-t * 24.0) + 38.0
        sine = math.sin(2.0 * math.pi * freq * t)
        # High sharp transient crack (white noise bursts)
        noise = random.uniform(-1.0, 1.0) * math.exp(-t * 55.0) * 1.5
        # Metallic cylinder resonance
        metal = math.sin(2.0 * math.pi * 920.0 * t) * math.exp(-t * 18.0) * 0.25
        # Envelope
        env = math.exp(-t * 10.0)
        s = (sine * 0.9 + noise + metal) * env
        samples.append(clamp(s))
    return samples

# --- 2. Shotgun (Super Shotgun) ---
def gen_shotgun():
    dur = 0.75
    total = int(SAMPLE_RATE * dur)
    samples = []
    # Heavy distorted boom + multiple scatter peaks
    for i in range(total):
        t = i / SAMPLE_RATE
        # Huge sub-bass chest thump
        freq = 85.0 * math.exp(-t * 12.0) + 30.0
        sub = math.sin(2.0 * math.pi * freq * t) * 1.2
        # Wide scatter explosion (filtered noise)
        n = random.uniform(-1.0, 1.0)
        if t < 0.12:
            n *= 2.2
        elif t < 0.35:
            n *= 1.2 * math.exp(-t * 6.0)
        else:
            n *= 0.4 * math.exp(-t * 4.0)
        # Mechanical double-barrel vibration
        mech = math.sin(2.0 * math.pi * 320.0 * t) * math.exp(-t * 14.0) * 0.4
        env = math.exp(-t * 5.5)
        # Soft saturation distortion
        mix = (sub * 0.7 + n * 0.8 + mech) * env
        s = math.tanh(mix * 1.4)
        samples.append(s)
    return samples

# --- 3. Assault Rifle ---
def gen_rifle():
    dur = 0.28
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Supersonic snappy crack
        freq = 180.0 * math.exp(-t * 35.0) + 55.0
        thump = math.sin(2.0 * math.pi * freq * t)
        crack = random.uniform(-1.0, 1.0) * math.exp(-t * 45.0) * 1.8
        # Gun bolt clack
        bolt = math.sin(2.0 * math.pi * 1450.0 * t) * math.exp(-t * 28.0) * 0.3
        env = math.exp(-t * 16.0)
        s = (thump * 0.6 + crack + bolt) * env
        samples.append(clamp(s))
    return samples

# --- 4. Rocket Launcher (RPG) ---
def gen_rocket():
    dur = 1.1
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Tube pop/launch + roaring jet fire
        thump = math.sin(2.0 * math.pi * 55.0 * t) * math.exp(-t * 8.0) * 1.2
        jet_roar = random.uniform(-1.0, 1.0) * (0.8 if t < 0.4 else (0.8 * math.exp(-(t-0.4)*4.0)))
        whistle = math.sin(2.0 * math.pi * (220.0 + t * 450.0) * t) * 0.2 * math.exp(-t * 3.0)
        s = math.tanh((thump + jet_roar * 0.9 + whistle) * 1.3)
        samples.append(s)
    return samples

# --- 5. Reload Mechanical Click ---
def gen_reload():
    dur = 0.22
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Double click (t=0.01 and t=0.09)
        click1 = math.sin(2.0 * math.pi * 2100.0 * t) * math.exp(-t * 90.0)
        click2 = 0.0
        if t > 0.08:
            t2 = t - 0.08
            click2 = math.sin(2.0 * math.pi * 1650.0 * t2) * math.exp(-t2 * 70.0) * 1.3
        s = (click1 + click2) * 0.8
        samples.append(clamp(s))
    return samples

# --- 6. Step on Sand ---
def gen_step():
    dur = 0.16
    total = int(SAMPLE_RATE * dur)
    samples = []
    prev_g = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        # Low frequency foot impact + soft sand friction
        thump = math.sin(2.0 * math.pi * 50.0 * t) * math.exp(-t * 26.0) * 0.4
        raw_grit = random.uniform(-1.0, 1.0) * math.exp(-t * 22.0) * 0.35
        prev_g += 0.22 * (raw_grit - prev_g)
        # 2 times quieter overall (0.3 instead of 0.6)
        s = (thump + prev_g) * 0.3
        samples.append(clamp(s))
    return samples

# --- 7. Zombie Groan / Growl ---
def gen_zombie_groan():
    dur = 0.9
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Deep menacing formant (growl with modulation)
        lfo = 1.0 + 0.35 * math.sin(2.0 * math.pi * 18.0 * t)
        base_f = 75.0 + 15.0 * math.sin(2.0 * math.pi * 2.2 * t)
        voice = math.sin(2.0 * math.pi * base_f * t) + 0.5 * math.sin(2.0 * math.pi * base_f * 2.1 * t)
        sub = math.sin(2.0 * math.pi * (base_f * 0.5) * t) * 0.6
        gravel = random.uniform(-0.3, 0.3) * lfo
        env = math.sin(math.pi * (i / total)) # smooth bell envelope
        s = (voice * lfo + sub + gravel) * env * 0.7
        samples.append(clamp(s))
    return samples

# --- 8. Screamer Sonic Screech ---
def gen_screamer():
    dur = 1.2
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Piercing frequency glide + harsh vibrato
        f = 850.0 + 400.0 * math.sin(2.0 * math.pi * 1.5 * t) + 120.0 * math.sin(2.0 * math.pi * 35.0 * t)
        s1 = math.sin(2.0 * math.pi * f * t)
        s2 = math.sin(2.0 * math.pi * (f * 1.48) * t) * 0.6
        noise = random.uniform(-0.35, 0.35)
        env = math.sin(math.pi * (i / total))
        s = (s1 + s2 + noise) * env * 0.8
        samples.append(clamp(s))
    return samples

# --- 9. Spitter Acid Sizzle ---
def gen_acid():
    dur = 0.65
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Wet splat + high sizzling hiss
        splat = math.sin(2.0 * math.pi * 120.0 * math.exp(-t * 20.0) * t) * math.exp(-t * 15.0)
        sizzle = random.uniform(-1.0, 1.0) * (0.8 if (i % 7 < 4) else 0.2) * math.exp(-t * 4.0)
        s = (splat * 0.7 + sizzle * 0.5)
        samples.append(clamp(s))
    return samples

# --- 10. Zombie Bite / Melee Hit ---
def gen_bite():
    dur = 0.32
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        f = 140.0 * math.exp(-t * 22.0) + 40.0
        impact = math.sin(2.0 * math.pi * f * t) * 0.9
        crunch = random.uniform(-0.7, 0.7) * math.exp(-t * 18.0)
        env = math.exp(-t * 9.0)
        s = (impact + crunch) * env
        samples.append(clamp(s))
    return samples

# --- 11. Massive Explosion (RPG / Exploder) ---
def gen_explosion():
    dur = 1.4
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Crushing sub-bass rumble (45Hz down to 18Hz)
        f = 55.0 * math.exp(-t * 4.0) + 18.0
        rumble = math.sin(2.0 * math.pi * f * t) * 1.5
        # Noise cloud with soft roll-off
        blast = random.uniform(-1.0, 1.0) * math.exp(-t * 3.2)
        env = math.exp(-t * 2.8)
        mix = (rumble + blast * 1.3) * env
        s = math.tanh(mix * 1.6)
        samples.append(s)
    return samples

# --- 12. Zombie Death Rattle ---
def gen_zombie_die():
    dur = 0.75
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        f = 95.0 * math.exp(-t * 3.5) + 30.0
        gurgle = math.sin(2.0 * math.pi * f * t) * (0.7 + 0.3 * math.sin(2.0 * math.pi * 22.0 * t))
        snap = (random.uniform(-0.8, 0.8) if t < 0.08 else 0.0)
        env = math.exp(-t * 4.0)
        s = (gurgle * 0.7 + snap) * env
        samples.append(clamp(s))
    return samples

# --- 13. Player Hurt Grunt ---
def gen_player_hurt():
    dur = 0.35
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        f = 130.0 * math.exp(-t * 12.0) + 55.0
        body = math.sin(2.0 * math.pi * f * t)
        impact = random.uniform(-0.5, 0.5) * math.exp(-t * 20.0)
        env = math.sin(math.pi * (i / total))
        s = (body * 0.8 + impact) * env
        samples.append(clamp(s))
    return samples

# --- 14. Wave Horn / Gong ---
def gen_wave_start():
    dur = 1.6
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # Deep brass / war horn chord (D minor - 73Hz and 110Hz and 146Hz)
        f1 = 73.4
        f2 = 110.0
        f3 = 146.8
        brass = (math.sin(2.0 * math.pi * f1 * t) * 0.6 +
                 math.sin(2.0 * math.pi * f2 * t) * 0.4 +
                 math.sin(2.0 * math.pi * f3 * t) * 0.3)
        env = (t / 0.15) if t < 0.15 else math.exp(-(t - 0.15) * 1.8)
        s = brass * env * 0.85
        samples.append(clamp(s))
    return samples

# --- 15. Wave Win Chime ---
def gen_wave_win():
    dur = 1.2
    total = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        # High clear harmonic chime (587Hz D5 and 880Hz A5)
        chime1 = math.sin(2.0 * math.pi * 587.3 * t) * math.exp(-t * 3.5)
        chime2 = (math.sin(2.0 * math.pi * 880.0 * (t - 0.12)) * math.exp(-(t - 0.12) * 3.0) if t > 0.12 else 0.0)
        s = (chime1 * 0.5 + chime2 * 0.5)
        samples.append(clamp(s))
    return samples

# --- 16. Desert Wind Howl / Sandstorm (Песчаные завывания) ---
def gen_wind_howl():
    # Полностью бесшумный буфер (хрустящий шум ветра убран по просьбе игрока)
    return [0.0] * int(SAMPLE_RATE * 1.0)


if __name__ == "__main__":
    out_dir = r"c:\Users\user\Documents\идет-караван-из-ирана\assets\audio"
    os.makedirs(out_dir, exist_ok=True)

    write_wav(os.path.join(out_dir, "shoot_revolver.wav"), gen_revolver())
    write_wav(os.path.join(out_dir, "shoot_shotgun.wav"), gen_shotgun())
    write_wav(os.path.join(out_dir, "shoot_rifle.wav"), gen_rifle())
    write_wav(os.path.join(out_dir, "shoot_rocket.wav"), gen_rocket())
    write_wav(os.path.join(out_dir, "reload_click.wav"), gen_reload())
    write_wav(os.path.join(out_dir, "step_sand.wav"), gen_step())
    write_wav(os.path.join(out_dir, "zombie_groan.wav"), gen_zombie_groan())
    write_wav(os.path.join(out_dir, "zombie_screamer.wav"), gen_screamer())
    write_wav(os.path.join(out_dir, "zombie_acid.wav"), gen_acid())
    write_wav(os.path.join(out_dir, "zombie_bite.wav"), gen_bite())
    write_wav(os.path.join(out_dir, "explosion.wav"), gen_explosion())
    write_wav(os.path.join(out_dir, "zombie_die.wav"), gen_zombie_die())
    write_wav(os.path.join(out_dir, "player_hurt.wav"), gen_player_hurt())
    write_wav(os.path.join(out_dir, "wave_start.wav"), gen_wave_start())
    write_wav(os.path.join(out_dir, "wave_win.wav"), gen_wave_win())
    write_wav(os.path.join(out_dir, "sand_wind_howl.wav"), gen_wind_howl())
    print("ALL 16 HIGH-IMPACT SOUND EFFECTS CREATED!")

