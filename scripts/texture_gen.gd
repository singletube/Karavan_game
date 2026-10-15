extends Node

# =========================================================================
# УНИВЕРСАЛЬНАЯ ЗАГРУЗКА ИЛИ ЭКСПОРТ В PNG
# Если файл PNG лежит в assets/textures/ — загружается он (вы можете его редактировать).
# Если файла нет — процедурно создается и автоматически сохраняется в PNG!
# =========================================================================
static func get_or_create(filename: String, gen_func: Callable) -> Texture2D:
	var path: String = "res://assets/textures/" + filename
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D

	var img: Image = gen_func.call()
	var global_path: String = ProjectSettings.globalize_path(path)
	img.save_png(global_path)
	return ImageTexture.create_from_image(img)


static func preload_all_textures() -> void:
	make_cactus()
	make_dead_tree()
	make_wrecked_car()
	make_tumbleweed()
	make_skull_bones()
	make_player()
	make_player_face_texture()
	make_player_torso_texture()
	make_player_denim_texture()
	make_player_leather_texture()
	make_player_hat_texture()
	make_zombie_walker()
	make_zombie_runner()
	make_zombie_brute()
	make_zombie_crawler()
	make_zombie_spitter()
	make_zombie_screamer()
	make_zombie_exploder()
	make_weapon_revolver()
	make_weapon_shotgun()
	make_weapon_rifle()
	make_weapon_rocket()
	make_muzzle_flash()
	make_wheel_track()
	make_footprint_boot()
	make_footprint_hoof()
	make_blood_splatter()
	make_blood_pool()
	make_sand_puff()


# --- 1. КАКТУС ---
static func make_cactus() -> Texture2D:
	return get_or_create("cactus.png", _generate_cactus_image)

static func _generate_cactus_image() -> Image:
	var img: Image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	var trunk: Color = Color(0.20, 0.55, 0.15, 1.0)
	var dark: Color  = Color(0.13, 0.38, 0.10, 1.0)
	var spine: Color = Color(0.85, 0.82, 0.60, 1.0)

	for y in range(0, 64):
		for x in range(13, 19):
			img.set_pixel(x, y, trunk)
		img.set_pixel(13, y, dark)
		img.set_pixel(18, y, dark)

	for y in range(18, 31):
		for x in range(6, 14):
			img.set_pixel(x, y, trunk)
		img.set_pixel(6, y, dark)
	for y in range(10, 19):
		for x in range(6, 10):
			img.set_pixel(x, y, trunk)

	for y in range(22, 35):
		for x in range(18, 26):
			img.set_pixel(x, y, trunk)
		img.set_pixel(25, y, dark)
	for y in range(14, 23):
		for x in range(22, 26):
			img.set_pixel(x, y, trunk)

	for y in [5, 15, 35, 50]:
		img.set_pixel(12, y, spine)
		img.set_pixel(19, y, spine)

	return img


# =========================================================================
# ТИП ЗОМБИ 1: WALKER (Обычный пустынный зомби в лохмотьях)
# =========================================================================
static func make_zombie_walker() -> Texture2D:
	return get_or_create("zombie_walker.png", _generate_zombie_walker_image)

static func make_zombie_spritesheet() -> Texture2D:
	return make_zombie_walker()

static func make_enemy() -> Texture2D:
	return make_zombie_walker()

static func _generate_zombie_walker_image() -> Image:
	var total_w := 640
	var h := 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var flesh_base := Color(0.32, 0.44, 0.28, 1.0)
	var flesh_dark := Color(0.20, 0.28, 0.18, 1.0)
	var flesh_pale := Color(0.42, 0.54, 0.38, 1.0)
	var bone       := Color(0.82, 0.80, 0.70, 1.0)
	var blood      := Color(0.68, 0.08, 0.08, 1.0)
	var blood_dark := Color(0.35, 0.04, 0.04, 1.0)
	var rag_base   := Color(0.50, 0.44, 0.34, 1.0)
	var rag_dark   := Color(0.32, 0.26, 0.18, 1.0)
	var eye_glow   := Color(1.00, 0.90, 0.15, 1.0)

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var body_sway: int = 0
		var l_arm_y: int = 24
		var r_arm_y: int = 24
		var l_leg_fwd: int = 0
		var r_leg_fwd: int = 0
		var is_hurt: bool = false
		var is_die1: bool = false
		var is_dead: bool = false

		match frame_idx:
			0: pass
			1: body_sway = -1; l_leg_fwd = 4; r_leg_fwd = -4
			2: pass
			3: body_sway = 1; l_leg_fwd = -4; r_leg_fwd = 4
			4: pass
			5: l_arm_y = 16; r_arm_y = 16
			6: l_arm_y = 28; r_arm_y = 28
			7: is_hurt = true
			8: is_die1 = true
			9: is_dead = true

		if is_dead:
			for by in range(54, 62):
				for bx in range(12, 54):
					if Vector2(bx - 33, (by - 58) * 3).length() < 22:
						img.set_pixel(ox + bx, by, blood_dark)
			for py in range(55, 62):
				for px in range(16, 50):
					img.set_pixel(ox + px, py, rag_dark)
			for py in range(56, 60):
				for px in range(18, 48):
					img.set_pixel(ox + px, py, rag_base)
			continue

		if is_die1:
			for y in range(30, 60):
				for x in range(20, 44):
					img.set_pixel(ox + x, y, rag_base)
			for hy in range(22, 34):
				for hx in range(24, 40):
					img.set_pixel(ox + hx, hy, flesh_base)
			for by in range(58, 63):
				for bx in range(22, 42):
					img.set_pixel(ox + bx, by, blood)
			continue

		var cx: int = 32 + body_sway

		# Голова
		for y in range(8, 22):
			for x in range(cx - 7, cx + 7):
				if Vector2(x - cx, y - 15).length() < 6.8:
					img.set_pixel(ox + x, y, flesh_base if x < cx else flesh_dark)

		# Раскрытый череп
		for y in range(8, 12):
			for x in range(cx - 3, cx + 4):
				img.set_pixel(ox + x, y, blood_dark)

		# Глаза
		img.set_pixel(ox + cx - 3, 13, eye_glow)
		img.set_pixel(ox + cx + 2, 13, eye_glow)

		# Зубы
		for mx in range(cx - 3, cx + 4):
			img.set_pixel(ox + mx, 18, blood_dark)
		img.set_pixel(ox + cx - 2, 18, bone)
		img.set_pixel(ox + cx + 2, 18, bone)

		# Тело / саван
		for y in range(22, 44):
			var w: int = 10 + int((y - 22) * 0.4)
			for x in range(cx - w, cx + w):
				img.set_pixel(ox + x, y, rag_base if (x + y) % 4 != 0 else rag_dark)

		# Руки и когти
		for y in range(l_arm_y, l_arm_y + 16):
			for x in range(cx - 12, cx - 8):
				img.set_pixel(ox + x, y, flesh_base)
		for y in range(r_arm_y, r_arm_y + 16):
			for x in range(cx + 8, cx + 12):
				img.set_pixel(ox + x, y, flesh_base)

		# Ноги
		for y in range(44, 62):
			var lx: int = cx - 5 + int(float(l_leg_fwd) * ((y - 44) / 18.0))
			for x in range(lx - 2, lx + 2):
				img.set_pixel(ox + x, y, rag_dark)
			var rx: int = cx + 5 + int(float(r_leg_fwd) * ((y - 44) / 18.0))
			for x in range(rx - 2, rx + 2):
				img.set_pixel(ox + x, y, rag_dark)

		if is_hurt:
			for sy in range(14, 38):
				for sx in range(cx - 12, cx + 13):
					if (sx * 7 + sy * 11) % 9 == 0:
						img.set_pixel(ox + sx, sy, blood)

	return img


# =========================================================================
# ТИП ЗОМБИ 2: RUNNER (Быстрый тощий скелет-гуль, бежит на игрока)
# =========================================================================
static func make_zombie_runner() -> Texture2D:
	return get_or_create("zombie_runner.png", _generate_zombie_runner_image)

static func _generate_zombie_runner_image() -> Image:
	var total_w := 640
	var h := 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var bone_pale := Color(0.85, 0.80, 0.70, 1.0)
	var bone_dark := Color(0.55, 0.48, 0.38, 1.0)
	var blood_red := Color(0.85, 0.10, 0.10, 1.0)
	var eye_red   := Color(1.00, 0.20, 0.05, 1.0)

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var body_tilt: int = 2 # наклонен вперед при стремительном беге
		var leg_spread: int = 0
		var claw_ext: int = 0

		match frame_idx:
			0: body_tilt = 1
			1: leg_spread = 7; claw_ext = 4
			2: leg_spread = 1; claw_ext = 2
			3: leg_spread = -7; claw_ext = 4
			4: leg_spread = -1; claw_ext = 2
			5: claw_ext = 8
			6: claw_ext = 10
			7: body_tilt = -3
			8: pass
			9: pass

		if frame_idx == 9: # Dead
			for by in range(56, 62):
				for bx in range(14, 52):
					img.set_pixel(ox + bx, by, blood_red if (bx + by) % 3 == 0 else bone_dark)
			continue

		if frame_idx == 8: # Die
			for y in range(40, 62):
				for x in range(22, 42):
					img.set_pixel(ox + x, y, bone_pale)
			continue

		var cx: int = 32

		# Голый череп гуля
		for y in range(10, 22):
			for x in range(cx - 5, cx + 6):
				if Vector2(x - cx, y - 16).length() < 5.5:
					img.set_pixel(ox + x, y, bone_pale if x < cx else bone_dark)

		# Горящие алые глаза
		img.set_pixel(ox + cx - 2, 14, eye_red)
		img.set_pixel(ox + cx + 2, 14, eye_red)

		# Торчащие ребра и позвоночник
		for y in range(22, 42):
			img.set_pixel(ox + cx, y, bone_pale)
			if y % 3 == 0:
				for x in range(cx - 6, cx + 7):
					img.set_pixel(ox + x, y, bone_pale)
					if x == cx - 6 or x == cx + 6:
						img.set_pixel(ox + x, y, blood_red)

		# Вытянутые когтистые длинные руки
		for y in range(22, 38):
			img.set_pixel(ox + cx - 9 - claw_ext, y, bone_pale)
			img.set_pixel(ox + cx + 9 + claw_ext, y, bone_pale)
		for k in range(4):
			img.set_pixel(ox + cx - 12 - claw_ext - k, 38 + k, blood_red)
			img.set_pixel(ox + cx + 12 + claw_ext + k, 38 + k, blood_red)

		# Тонкие скелетные ноги
		for y in range(42, 62):
			img.set_pixel(ox + cx - 4 + int(leg_spread * ((y - 42) / 20.0)), y, bone_pale)
			img.set_pixel(ox + cx + 4 - int(leg_spread * ((y - 42) / 20.0)), y, bone_dark)

	return img


# =========================================================================
# ТИП ЗОМБИ 3: BRUTE (Огромный тяжелый мутант-мясник с цепями)
# =========================================================================
static func make_zombie_brute() -> Texture2D:
	return get_or_create("zombie_brute.png", _generate_zombie_brute_image)

static func _generate_zombie_brute_image() -> Image:
	var total_w := 640
	var h := 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var meat_base := Color(0.48, 0.28, 0.32, 1.0) # вздутая багровая плоть
	var meat_dark := Color(0.28, 0.14, 0.18, 1.0)
	var iron      := Color(0.55, 0.52, 0.50, 1.0) # ржавые цепи и кандалы
	var iron_rust := Color(0.65, 0.35, 0.15, 1.0)
	var eye_glow  := Color(1.00, 0.85, 0.10, 1.0)

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var arm_swing: int = 0
		var step_x: int = 0

		match frame_idx:
			0: pass
			1: step_x = 3; arm_swing = -2
			2: pass
			3: step_x = -3; arm_swing = 2
			4: pass
			5: arm_swing = 8  # замах огромными кулаками
			6: arm_swing = -6 # сокрушительный удар вниз
			7: pass
			8: pass
			9: pass

		if frame_idx == 9: # Dead
			for by in range(50, 62):
				for bx in range(10, 56):
					img.set_pixel(ox + bx, by, meat_dark if (bx + by) % 4 == 0 else meat_base)
			continue

		var cx: int = 32

		# Огромный толстый торс (x: 16..48, y: 16..46)
		for y in range(16, 48):
			var w: int = 15 - int(abs(y - 32) * 0.25)
			for x in range(cx - w, cx + w):
				var col := meat_base
				# Ржавые железные цепи накрест на груди
				if (x - y) % 6 == 0 or (x + y) % 6 == 0:
					col = iron if (x + y) % 3 == 0 else iron_rust
				img.set_pixel(ox + x, y, col)

		# Маленькая вдавленная голова в плечах
		for y in range(6, 18):
			for x in range(cx - 7, cx + 8):
				if Vector2(x - cx, y - 12).length() < 6.0:
					img.set_pixel(ox + x, y, meat_dark if x > cx else meat_base)
		# Светящиеся злые глаза
		img.set_pixel(ox + cx - 3, 11, eye_glow)
		img.set_pixel(ox + cx + 2, 11, eye_glow)

		# Огромные руки-кувалды
		for y in range(20, 48):
			for x in range(cx - 19, cx - 13):
				img.set_pixel(ox + x, y + arm_swing, meat_base)
			for x in range(cx + 13, cx + 19):
				img.set_pixel(ox + x, y - arm_swing, meat_base)
		# Кандалы на запястьях
		for x in range(cx - 20, cx - 12):
			img.set_pixel(ox + x, 40 + arm_swing, iron)
		for x in range(cx + 12, cx + 20):
			img.set_pixel(ox + x, 40 - arm_swing, iron)

		# Массивные ноги-тумбы
		for y in range(48, 62):
			for x in range(cx - 12 + step_x, cx - 4 + step_x):
				img.set_pixel(ox + x, y, meat_dark)
			for x in range(cx + 4 - step_x, cx + 12 - step_x):
				img.set_pixel(ox + x, y, meat_dark)

	return img


# =========================================================================
# ТИП ЗОМБИ 4: CRAWLER (Ползущий зомби-паук)
# =========================================================================
static func make_zombie_crawler() -> Texture2D:
	return get_or_create("zombie_crawler.png", _generate_zombie_crawler_image)

static func _generate_zombie_crawler_image() -> Image:
	var total_w: int = 640
	var h: int = 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var skin_base: Color = Color(0.45, 0.50, 0.42, 1.0) # бледно-зеленая гнилая кожа
	var skin_dark: Color = Color(0.25, 0.22, 0.18, 1.0) # темная гниль / тень
	var skin_pale: Color = Color(0.55, 0.60, 0.50, 1.0) # блик на коже
	var muscle_red: Color = Color(0.62, 0.18, 0.12, 1.0) # обнаженное мясо
	var blood_dark: Color = Color(0.38, 0.08, 0.08, 1.0) # засохшая кровь
	var gut_pink: Color = Color(0.72, 0.35, 0.30, 1.0) # кишки
	var gut_dark: Color = Color(0.50, 0.20, 0.20, 1.0) # тень кишок
	var bone: Color = Color(0.85, 0.82, 0.72, 1.0) # позвонки и кости
	var eye_glow: Color = Color(0.75, 0.95, 0.20, 1.0) # ядовито-желтые глаза

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var drag_offset: int = 0
		var l_arm_x: int = 0
		var r_arm_x: int = 0
		var l_arm_y: int = 0
		var r_arm_y: int = 0
		var mouth_open: bool = false
		var is_hurt: bool = false
		var is_die: bool = false
		var is_dead: bool = false

		match frame_idx:
			0:
				# Idle: дыхание на полу
				pass
			1:
				# Walk 1: левая рука тянется вперед, правая сзади
				l_arm_x = 7
				l_arm_y = -2
				r_arm_x = -4
				r_arm_y = 2
				drag_offset = 1
			2:
				# Walk 2: подтягивание корпуса
				l_arm_x = 3
				l_arm_y = 1
				r_arm_x = -1
				r_arm_y = 1
				drag_offset = 2
			3:
				# Walk 3: правая рука выбрасывается вперед, левая сзади
				l_arm_x = -4
				l_arm_y = 2
				r_arm_x = 7
				r_arm_y = -2
				drag_offset = 1
			4:
				# Walk 4: второе подтягивание
				l_arm_x = -1
				l_arm_y = 1
				r_arm_x = 3
				r_arm_y = 1
				drag_offset = 0
			5:
				# Attack 1: приподнялся на культях, замах обеими когтистыми руками
				l_arm_x = -3
				l_arm_y = -8
				r_arm_x = 5
				r_arm_y = -8
				mouth_open = true
			6:
				# Attack 2: яростный выпад когтями вперед
				l_arm_x = 10
				l_arm_y = 3
				r_arm_x = 12
				r_arm_y = 4
				mouth_open = true
			7:
				is_hurt = true
			8:
				is_die = true
			9:
				is_dead = true

		if is_dead:
			# Растекшаяся кровавая лужа с волочащимися кишками и обрубком позвоночника
			for py in range(54, 63):
				for px in range(10, 56):
					var dist: float = Vector2(px - 32, (py - 58) * 3).length()
					if dist < 23.0:
						img.set_pixel(ox + px, py, blood_dark if (px + py) % 3 != 0 else muscle_red)
			for gx in range(14, 46):
				var gy: int = 57 + int(sin(float(gx) * 0.7) * 2.5)
				if gy >= 54 and gy < 63:
					img.set_pixel(ox + gx, gy, gut_pink)
					img.set_pixel(ox + gx, gy + 1, gut_dark)
			# Обломок позвоночника
			for k in range(5):
				img.set_pixel(ox + 26 + k * 2, 56, bone)
			continue

		if is_die:
			# Умирающий: рухнул плашмя лицом в пол
			for py in range(48, 62):
				for px in range(16, 52):
					if (px - 34) * (px - 34) / 256.0 + (py - 56) * (py - 56) / 25.0 < 1.0:
						img.set_pixel(ox + px, py, skin_dark if px < 34 else skin_base)
			for gx in range(12, 30):
				var gy: int = 58 + int(cos(float(gx) * 0.5) * 2.0)
				if gy >= 50 and gy < 64:
					img.set_pixel(ox + gx, gy, gut_pink)
			for by in range(57, 63):
				for bx in range(20, 48):
					if (bx * 3 + by * 5) % 4 == 0:
						img.set_pixel(ox + bx, by, blood_dark)
			continue

		var cx: int = 34 + drag_offset
		var base_y: int = 48 # центрирован внизу (y: 40-58)

		# Волочащиеся внутренности и разорванный таз сзади (слева от cx)
		for gx in range(cx - 24, cx - 8):
			var gy1: int = 56 + int(sin(float(gx) * 0.5) * 2.5)
			var gy2: int = 58 + int(cos(float(gx) * 0.6) * 2.0)
			if gy1 >= 0 and gy1 < 64:
				img.set_pixel(ox + gx, gy1, gut_pink if (gx % 2 == 0) else gut_dark)
			if gy2 >= 0 and gy2 < 64:
				img.set_pixel(ox + gx, gy2, muscle_red)
		# Обнаженный позвоночник, торчащий из обрубка талии
		for sy in range(base_y + 2, base_y + 7):
			img.set_pixel(ox + cx - 9, sy, bone)
			img.set_pixel(ox + cx - 10, sy, muscle_red)
			img.set_pixel(ox + cx - 8, sy, blood_dark)

		# Изуродованный торс (низко над землей)
		for ty in range(base_y - 8, base_y + 6):
			var w: int = 8 - int(abs(ty - base_y) * 0.6)
			for tx in range(cx - 8 - w, cx + w):
				var col: Color = skin_base
				if tx < cx - 4:
					col = muscle_red if (tx + ty) % 3 == 0 else skin_dark
				elif (tx + ty) % 4 == 0:
					col = skin_pale
				elif ty > base_y + 2:
					col = skin_dark
				img.set_pixel(ox + tx, ty, col)

		# Выступающие ребра по бокам торса
		for ry in [base_y - 4, base_y - 1, base_y + 2]:
			for rx in range(cx - 7, cx - 1):
				if (rx + ry) % 2 == 0:
					img.set_pixel(ox + rx, ry, bone)

		# Голова ползуна (вытянута вперед и низко)
		var head_cx: int = cx + 5
		var head_cy: int = base_y - 5
		for hy in range(head_cy - 6, head_cy + 5):
			for hx in range(head_cx - 6, head_cx + 7):
				if Vector2(hx - head_cx, hy - head_cy).length() < 5.4:
					var hcol: Color = skin_base if hx > head_cx - 2 else skin_dark
					if hy < head_cy - 2 and (hx + hy) % 3 == 0:
						hcol = skin_pale
					img.set_pixel(ox + hx, hy, hcol)

		# Глаза (горящий желто-зеленый отблеск)
		img.set_pixel(ox + head_cx + 2, head_cy - 1, eye_glow)
		img.set_pixel(ox + head_cx + 4, head_cy - 1, eye_glow)

		# Пасть
		if mouth_open:
			for my in range(head_cy + 1, head_cy + 4):
				for mx in range(head_cx + 2, head_cx + 7):
					img.set_pixel(ox + mx, my, blood_dark)
			img.set_pixel(ox + head_cx + 3, head_cy + 1, bone)
			img.set_pixel(ox + head_cx + 5, head_cy + 1, bone)
			img.set_pixel(ox + head_cx + 4, head_cy + 3, bone)
		else:
			for mx in range(head_cx + 2, head_cx + 6):
				img.set_pixel(ox + mx, head_cy + 2, blood_dark)
			img.set_pixel(ox + head_cx + 3, head_cy + 2, bone)

		# Длинные паукообразные когтистые руки
		# Левая рука
		var lax: int = cx - 2 + l_arm_x
		var lay: int = base_y + 3 + l_arm_y
		for seg in range(12):
			var ax: int = cx - 4 + int(seg * ((lax - (cx - 4)) / 11.0))
			var ay: int = (base_y - 2) + int(seg * ((lay - (base_y - 2)) / 11.0))
			if ax >= 0 and ax < 64 and ay >= 0 and ay < 64:
				img.set_pixel(ox + ax, ay, skin_dark)
				img.set_pixel(ox + ax, ay + 1, skin_base)
		# Когти левой руки
		for k in range(4):
			var claw_x: int = lax + k * 2
			var claw_y: int = lay + 1 + int(k * 0.7)
			if claw_x >= 0 and claw_x < 64 and claw_y >= 0 and claw_y < 64:
				img.set_pixel(ox + claw_x, claw_y, bone)
				img.set_pixel(ox + claw_x + 1, claw_y, blood_dark)

		# Правая рука
		var rax: int = cx + 8 + r_arm_x
		var ray: int = base_y + 4 + r_arm_y
		for seg in range(13):
			var ax: int = cx + 2 + int(seg * ((rax - (cx + 2)) / 12.0))
			var ay: int = (base_y - 3) + int(seg * ((ray - (base_y - 3)) / 12.0))
			if ax >= 0 and ax < 64 and ay >= 0 and ay < 64:
				img.set_pixel(ox + ax, ay, skin_base)
				img.set_pixel(ox + ax, ay + 1, skin_dark)
		# Когти правой руки
		for k in range(4):
			var claw_x: int = rax + k * 2
			var claw_y: int = ray + 1 + int(k * 0.7)
			if claw_x >= 0 and claw_x < 64 and claw_y >= 0 and claw_y < 64:
				img.set_pixel(ox + claw_x, claw_y, bone)
				img.set_pixel(ox + claw_x + 1, claw_y, blood_dark)

		# Кровь при ранении
		if is_hurt:
			for sy in range(base_y - 10, base_y + 8):
				for sx in range(cx - 16, cx + 18):
					if (sx * 7 + sy * 13) % 7 == 0:
						img.set_pixel(ox + sx, sy, muscle_red)
					elif (sx * 5 + sy * 11) % 9 == 0:
						img.set_pixel(ox + sx, sy, blood_dark)

	return img


# =========================================================================
# ТИП ЗОМБИ 5: SPITTER (Зомби-плевальщик с раздутым горлом и мешками кислоты)
# =========================================================================
static func make_zombie_spitter() -> Texture2D:
	return get_or_create("zombie_spitter.png", _generate_zombie_spitter_image)

static func _generate_zombie_spitter_image() -> Image:
	var total_w: int = 640
	var h: int = 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var skin_base: Color = Color(0.52, 0.58, 0.22, 1.0) # болезненная желто-зеленая кожа
	var skin_dark: Color = Color(0.32, 0.36, 0.14, 1.0) # темная кожа / складки
	var sac_green: Color = Color(0.30, 0.72, 0.15, 1.0) # токсичные зеленые мешки
	var sac_glow: Color = Color(0.60, 0.95, 0.20, 1.0) # яркое свечение кислоты
	var vein_dark: Color = Color(0.20, 0.30, 0.10, 1.0) # темные ядовитые вены
	var bruise_purple: Color = Color(0.42, 0.18, 0.38, 1.0) # лиловые кровоподтеки
	var acid_drip: Color = Color(0.55, 0.85, 0.10, 1.0) # капающая едкая кислота
	var bone: Color = Color(0.80, 0.85, 0.65, 1.0) # зубы
	var eye_col: Color = Color(0.90, 0.95, 0.40, 1.0) # мутный желтый глаз

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var hunch_x: int = 0
		var sac_jiggle: int = 0
		var spit_stage: int = 0
		var is_hurt: bool = false
		var is_die: bool = false
		var is_dead: bool = false
		var leg_step: int = 0

		match frame_idx:
			0:
				# Idle: дыхание с подрагиванием мешков
				sac_jiggle = 0
			1:
				# Walk 1: неуклюжий шаг
				leg_step = 4
				sac_jiggle = 1
				hunch_x = 1
			2:
				# Walk 2: шаг
				leg_step = 1
				sac_jiggle = -1
			3:
				# Walk 3: второй шаг
				leg_step = -4
				sac_jiggle = 1
				hunch_x = -1
			4:
				# Walk 4: шаг
				leg_step = -1
				sac_jiggle = 0
			5:
				# Attack 1: заглатывание воздуха, горло раздувается до максимума
				spit_stage = 1
				sac_jiggle = 2
				hunch_x = -2
			6:
				# Attack 2: выброс струи кислоты вперед
				spit_stage = 2
				sac_jiggle = -1
				hunch_x = 3
			7:
				is_hurt = true
			8:
				is_die = true
			9:
				is_dead = true

		if is_dead:
			# Труп, разъеденный собственной кислотой в шипящей луже
			for py in range(52, 63):
				for px in range(12, 54):
					var dist: float = Vector2(px - 33, (py - 58) * 3).length()
					if dist < 22.0:
						var col: Color = acid_drip if (px + py) % 3 == 0 else bruise_purple
						if dist < 12.0 and (px * py) % 2 == 0:
							col = sac_green
						img.set_pixel(ox + px, py, col)
			# Сгнившие остатки позвоночника
			for bx in range(24, 42):
				if bx % 3 == 0:
					img.set_pixel(ox + bx, 57, bone)
			continue

		if is_die:
			# Падение вперед, лопающиеся токсичные мешки
			for py in range(36, 60):
				for px in range(18, 48):
					if (px - 33) * (px - 33) / 180.0 + (py - 50) * (py - 50) / 70.0 < 1.0:
						img.set_pixel(ox + px, py, skin_dark if px < 33 else bruise_purple)
			# Брызги кислоты
			for k in range(18):
				var kx: int = 24 + (k * 7) % 26
				var ky: int = 40 + (k * 11) % 20
				if kx < 64 and ky < 64:
					img.set_pixel(ox + kx, ky, sac_glow if k % 2 == 0 else sac_green)
			continue

		var cx: int = 30 + hunch_x

		# Ноги (согнутые, с шишками и синяками)
		for y in range(44, 62):
			var l_leg_x: int = cx - 6 + int(float(leg_step) * ((y - 44) / 18.0))
			for lx in range(l_leg_x - 2, l_leg_x + 3):
				img.set_pixel(ox + lx, y, skin_dark if lx == l_leg_x - 2 else skin_base)
			var r_leg_x: int = cx + 6 - int(float(leg_step) * ((y - 44) / 18.0))
			for rx in range(r_leg_x - 2, r_leg_x + 3):
				img.set_pixel(ox + rx, y, bruise_purple if (rx + y) % 4 == 0 else skin_dark)

		# Сгорбленный раздутый торс (y: 20-46)
		for ty in range(20, 46):
			var tw: int = 9 + int((ty - 20) * 0.35)
			for tx in range(cx - tw, cx + tw + 2):
				var tcol: Color = skin_base
				if tx < cx - 3:
					tcol = skin_dark
				elif (tx + ty) % 5 == 0:
					tcol = bruise_purple
				elif (tx * 3 + ty * 7) % 11 == 0:
					tcol = vein_dark
				img.set_pixel(ox + tx, ty, tcol)

		# Вздутые токсичные мешки по бокам шеи и на плечах (слева и справа)
		var sac_rad: int = 5 + sac_jiggle + (3 if spit_stage == 1 else 0)
		for sy in range(16, 28):
			for sx in range(cx - 13 - sac_rad, cx - 4):
				var d_left: float = Vector2(sx - (cx - 10), sy - 21).length()
				if d_left < float(sac_rad):
					var scol: Color = sac_green
					if d_left < float(sac_rad) - 2.2:
						scol = sac_glow
					elif (sx + sy) % 3 == 0:
						scol = vein_dark
					img.set_pixel(ox + sx, sy, scol)

		# Правый мешок на горле (ближе к зрителю)
		for sy in range(17, 30):
			for sx in range(cx + 4, cx + 12 + sac_rad):
				var d_right: float = Vector2(sx - (cx + 8), sy - 23).length()
				if d_right < float(sac_rad):
					var scol: Color = sac_green
					if d_right < float(sac_rad) - 2.0:
						scol = sac_glow
					elif (sx + sy) % 3 == 0:
						scol = vein_dark
					img.set_pixel(ox + sx, sy, scol)

		# Руки (тощие, с потеками яда)
		for ay in range(26, 44):
			img.set_pixel(ox + cx - 11, ay, skin_dark)
			img.set_pixel(ox + cx - 10, ay, skin_base)
			img.set_pixel(ox + cx + 10, ay, skin_base)
			img.set_pixel(ox + cx + 11, ay, skin_dark)
			if ay % 6 == 0:
				img.set_pixel(ox + cx + 12, ay, acid_drip)

		# Голова и ОГРОМНАЯ отвисшая челюсть-мешок (занимает треть головы)
		var head_cx: int = cx + 4
		var head_cy: int = 14
		# Череп
		for hy in range(head_cy - 7, head_cy + 1):
			for hx in range(head_cx - 6, head_cx + 6):
				if Vector2(hx - head_cx, hy - head_cy).length() < 5.8:
					img.set_pixel(ox + hx, hy, skin_base if hx > head_cx - 2 else skin_dark)

		# Глаза
		img.set_pixel(ox + head_cx + 2, head_cy - 2, eye_col)
		img.set_pixel(ox + head_cx + 4, head_cy - 2, eye_col)

		# Огромная отвисшая раздутая нижняя челюсть / зоб (y: 14-25, x: head_cx - 4 .. head_cx + 10)
		var jaw_expand: int = (4 if spit_stage == 1 else (2 if spit_stage == 2 else 0))
		for jy in range(head_cy + 1, head_cy + 10 + jaw_expand):
			for jx in range(head_cx - 3, head_cx + 8 + jaw_expand):
				var jd: float = Vector2((jx - (head_cx + 2)), (jy - (head_cy + 5))).length()
				if jd < 5.5 + float(jaw_expand) * 0.7:
					var jcol: Color = bruise_purple
					if jd < 3.2:
						jcol = sac_green
					elif jx > head_cx + 1:
						jcol = skin_base
					img.set_pixel(ox + jx, jy, jcol)

		# Пасть и зубы
		if spit_stage == 2:
			# Широко открытый рот, изрыгающий кислоту
			for my in range(head_cy + 1, head_cy + 6):
				for mx in range(head_cx + 3, head_cx + 9):
					img.set_pixel(ox + mx, my, vein_dark)
			img.set_pixel(ox + head_cx + 4, head_cy + 1, bone)
			img.set_pixel(ox + head_cx + 7, head_cy + 1, bone)
			img.set_pixel(ox + head_cx + 5, head_cy + 5, bone)
			# Струя кислоты вперед (x: head_cx + 9 .. head_cx + 26)
			for sx in range(head_cx + 9, head_cx + 26):
				var sy_mid: int = head_cy + 3 + int((sx - head_cx - 9) * 0.35)
				for sy in range(sy_mid - 2, sy_mid + 3):
					if sy >= 0 and sy < 64:
						var scol: Color = sac_glow if abs(sy - sy_mid) == 0 else acid_drip
						if (sx + sy) % 4 == 0:
							scol = sac_green
						img.set_pixel(ox + sx, sy, scol)
				# Падающие капли
				if sx % 4 == 0 and sy_mid + 5 < 64:
					img.set_pixel(ox + sx, sy_mid + 5, acid_drip)
		else:
			for mx in range(head_cx + 3, head_cx + 7):
				img.set_pixel(ox + mx, head_cy + 2, vein_dark)
			img.set_pixel(ox + head_cx + 4, head_cy + 2, bone)
			# Капающая с подбородка кислота
			for dy in range(head_cy + 9, head_cy + 13):
				if dy < 64:
					img.set_pixel(ox + head_cx + 4, dy, acid_drip if dy % 2 == 0 else sac_glow)

		# Эффект урона
		if is_hurt:
			for sy in range(12, 42):
				for sx in range(cx - 14, cx + 18):
					if (sx * 7 + sy * 11) % 6 == 0:
						img.set_pixel(ox + sx, sy, acid_drip)
					elif (sx * 5 + sy * 13) % 8 == 0:
						img.set_pixel(ox + sx, sy, bruise_purple)

	return img


# =========================================================================
# ТИП ЗОМБИ 6: SCREAMER (Зомби-визжальщик со звуковыми кольцами)
# =========================================================================
static func make_zombie_screamer() -> Texture2D:
	return get_or_create("zombie_screamer.png", _generate_zombie_screamer_image)

static func _generate_zombie_screamer_image() -> Image:
	var total_w: int = 640
	var h: int = 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var skin_ash: Color = Color(0.72, 0.68, 0.65, 1.0) # пепельно-белая бледная кожа
	var skin_dark: Color = Color(0.40, 0.38, 0.36, 1.0) # серая тень
	var skin_bright: Color = Color(0.88, 0.85, 0.82, 1.0) # бледный блик
	var eye_void: Color = Color(0.08, 0.05, 0.05, 1.0) # пустые темные глазницы
	var mouth_void: Color = Color(0.04, 0.02, 0.02, 1.0) # бездонная черная пасть
	var sonic_blue: Color = Color(0.45, 0.65, 0.90, 0.70) # звуковые кольца
	var sonic_bright: Color = Color(0.75, 0.90, 1.00, 0.90) # яркое ядро звуковой волны
	var rags_base: Color = Color(0.62, 0.60, 0.58, 1.0) # белые лохмотья
	var rags_dark: Color = Color(0.38, 0.36, 0.35, 1.0) # складки лохмотьев

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var float_y: int = 0
		var mouth_height: int = 6
		var arms_up: int = 0
		var sonic_power: int = 0
		var is_hurt: bool = false
		var is_die: bool = false
		var is_dead: bool = false

		match frame_idx:
			0:
				# Idle: парение на месте
				float_y = 0
				arms_up = 0
			1:
				# Walk 1: волнообразное покачивание
				float_y = -2
				arms_up = 2
			2:
				# Walk 2:
				float_y = -1
				arms_up = 1
			3:
				# Walk 3:
				float_y = 1
				arms_up = -1
			4:
				# Walk 4:
				float_y = 0
				arms_up = 0
			5:
				# Attack 1: подготовка к воплю, рот удлиняется
				float_y = -2
				mouth_height = 10
				arms_up = 6
				sonic_power = 1
			6:
				# Attack 2: максимальный крик! Огромные звуковые волны
				float_y = -3
				mouth_height = 13
				arms_up = 8
				sonic_power = 2
			7:
				is_hurt = true
			8:
				is_die = true
			9:
				is_dead = true

		if is_dead:
			# Опавшие белые лохмотья и удлиненный пустой череп
			for py in range(54, 62):
				for px in range(14, 50):
					img.set_pixel(ox + px, py, rags_dark if (px + py) % 3 == 0 else rags_base)
			for cx2 in range(26, 38):
				img.set_pixel(ox + cx2, 53, skin_ash)
			img.set_pixel(ox + 30, 53, eye_void)
			img.set_pixel(ox + 34, 53, eye_void)
			continue

		if is_die:
			# Складывающееся как пустой саван тело
			for py in range(32, 60):
				for px in range(22, 44):
					var d: float = Vector2(px - 32, (py - 46) * 1.5).length()
					if d < 14.0:
						img.set_pixel(ox + px, py, rags_base if px % 2 == 0 else skin_dark)
			continue

		var cx: int = 32
		var head_y: int = 12 + float_y

		# 1. Звуковые кольца (если атакует)
		if sonic_power > 0:
			var center_mouth: Vector2 = Vector2(cx + 3, head_y + 4)
			var radii: Array = [12.0, 20.0] if sonic_power == 1 else [10.0, 18.0, 26.0]
			for rad in radii:
				var min_a: float = -PI * 0.45
				var max_a: float = PI * 0.45
				var steps: int = int(rad * 3.0)
				for s in range(steps):
					var ang: float = min_a + (max_a - min_a) * (float(s) / float(steps))
					var wave_pos: Vector2 = center_mouth + Vector2(cos(ang), sin(ang)) * rad
					var wx: int = int(round(wave_pos.x))
					var wy: int = int(round(wave_pos.y))
					if wx >= 0 and wx < 64 and wy >= 0 and wy < 64:
						img.set_pixel(ox + wx, wy, sonic_bright if (s % 3 == 0) else sonic_blue)

		# 2. Ноги (очень тонкие, длинные ходули под саваном)
		for y in range(46, 62):
			img.set_pixel(ox + cx - 3, y, skin_dark)
			img.set_pixel(ox + cx - 2, y, skin_ash)
			img.set_pixel(ox + cx + 2, y, skin_ash)
			img.set_pixel(ox + cx + 3, y, skin_dark)

		# 3. Торс и истлевший погребальный саван (узкий силуэт)
		for ty in range(22 + float_y, 48):
			var tw: int = 6 + int((ty - (22 + float_y)) * 0.25)
			for tx in range(cx - tw, cx + tw + 1):
				var rcol: Color = rags_base
				if tx < cx - 2:
					rcol = rags_dark
				elif (tx + ty) % 4 == 0:
					rcol = skin_bright
				elif (tx == cx - tw or tx == cx + tw) and ty % 2 == 0:
					rcol = skin_dark
				img.set_pixel(ox + tx, ty, rcol)

		# 4. Длинные иссохшие руки, поднятые к голове
		var hand_y: int = head_y + 4 - arms_up
		# Левая рука
		for ay in range(head_y + 8, hand_y, -1 if head_y + 8 > hand_y else 1):
			img.set_pixel(ox + cx - 10, ay, skin_ash)
			img.set_pixel(ox + cx - 11, ay, skin_dark)
		# Правая рука
		for ay in range(head_y + 8, hand_y, -1 if head_y + 8 > hand_y else 1):
			img.set_pixel(ox + cx + 10, ay, skin_ash)
			img.set_pixel(ox + cx + 11, ay, skin_dark)
		# Иссохшие пальцы
		for k in range(3):
			img.set_pixel(ox + cx - 12 - k, hand_y - k, skin_ash)
			img.set_pixel(ox + cx + 12 + k, hand_y - k, skin_ash)

		# 5. Вытянутая бледная голова (в духе «Крика» Мунка)
		var head_h: int = 15 + (mouth_height - 6)
		for hy in range(head_y - 8, head_y - 8 + head_h):
			var cur_w: int = 5 - int(abs(hy - (head_y - 2)) * 0.25)
			for hx in range(cx - cur_w, cx + cur_w + 1):
				var hcol: Color = skin_ash
				if hx < cx - 1:
					hcol = skin_dark
				elif (hx + hy) % 3 == 0:
					hcol = skin_bright
				img.set_pixel(ox + hx, hy, hcol)

		# 6. Глубокие черные глазницы
		img.set_pixel(ox + cx - 2, head_y - 4, eye_void)
		img.set_pixel(ox + cx - 3, head_y - 4, eye_void)
		img.set_pixel(ox + cx + 2, head_y - 4, eye_void)
		img.set_pixel(ox + cx + 3, head_y - 4, eye_void)

		# 7. Зияющая черная бездна рта
		for my in range(head_y - 1, head_y - 1 + mouth_height):
			for mx in range(cx - 2, cx + 3):
				img.set_pixel(ox + mx, my, mouth_void)
		# Контур вокруг рта
		for my in range(head_y - 1, head_y - 1 + mouth_height):
			img.set_pixel(ox + cx - 3, my, skin_dark)
			img.set_pixel(ox + cx + 3, my, skin_dark)

		# Урон
		if is_hurt:
			for sy in range(head_y - 6, 44):
				for sx in range(cx - 14, cx + 15):
					if (sx * 7 + sy * 9) % 8 == 0:
						img.set_pixel(ox + sx, sy, skin_dark)

	return img


# =========================================================================
# ТИП ЗОМБИ 7: EXPLODER (Зомби-камикадзе с пылающим растрескавшимся брюхом)
# =========================================================================
static func make_zombie_exploder() -> Texture2D:
	return get_or_create("zombie_exploder.png", _generate_zombie_exploder_image)

static func _generate_zombie_exploder_image() -> Image:
	var total_w: int = 640
	var h: int = 64
	var img: Image = Image.create(total_w, h, false, Image.FORMAT_RGBA8)

	var skin_stretched: Color = Color(0.55, 0.38, 0.32, 1.0) # натянутая истонченная кожа
	var skin_dark: Color = Color(0.30, 0.15, 0.12, 1.0) # растяжки и темная омертвевшая плоть
	var lava_crack: Color = Color(1.00, 0.55, 0.10, 1.0) # пылающие оранжевые разломы
	var glow_deep: Color = Color(0.95, 0.25, 0.05, 1.0) # глубинное магматическое свечение
	var core_yellow: Color = Color(1.00, 0.90, 0.30, 1.0) # раскаленное желтое ядро
	var ash_black: Color = Color(0.12, 0.10, 0.10, 1.0) # обугленная корка

	for frame_idx in range(10):
		var ox: int = frame_idx * 64
		var waddle_x: int = 0
		var belly_swell: int = 0
		var crack_glow: float = 1.0
		var is_boom: bool = false
		var is_hurt: bool = false
		var is_die: bool = false
		var is_dead: bool = false

		match frame_idx:
			0:
				# Idle: тяжелое колыхание
				pass
			1:
				# Walk 1: перевалка влево
				waddle_x = -2
			2:
				# Walk 2: шаг
				waddle_x = 0
			3:
				# Walk 3: перевалка вправо
				waddle_x = 2
			4:
				# Walk 4: шаг
				waddle_x = 0
			5:
				# Attack 1: критическое вздутие перед детонацией
				belly_swell = 4
				crack_glow = 1.6
			6:
				# Attack 2: БУМ! Вспышка взрыва
				is_boom = true
			7:
				is_hurt = true
			8:
				is_die = true
			9:
				is_dead = true

		if is_dead:
			# Обугленный дымящийся кратер с тлеющими углями
			for py in range(54, 63):
				for px in range(12, 52):
					var d: float = Vector2(px - 32, (py - 58) * 3).length()
					if d < 20.0:
						var col: Color = ash_black
						if (px * py) % 7 == 0:
							col = glow_deep
						elif (px + py) % 5 == 0:
							col = skin_dark
						img.set_pixel(ox + px, py, col)
			# Тлеющие искры
			for k in range(8):
				var kx: int = 20 + (k * 7) % 24
				var ky: int = 52 + (k * 3) % 8
				img.set_pixel(ox + kx, ky, lava_crack if k % 2 == 0 else core_yellow)
			continue

		if is_boom:
			# Кадр 6: Колоссальный взрыв — яркое ядро, лучи пламени и летящие ошметки
			var boom_center: Vector2 = Vector2(32, 34)
			for by in range(4, 60):
				for bx in range(4, 60):
					var dist: float = boom_center.distance_to(Vector2(bx, by))
					if dist < 12.0:
						# Яркий раскаленный центр
						img.set_pixel(ox + bx, by, core_yellow if dist < 7.0 else lava_crack)
					elif dist < 24.0:
						# Огненная волна
						if (bx + by) % 3 != 0:
							img.set_pixel(ox + bx, by, glow_deep if dist > 18.0 else lava_crack)
					elif dist < 30.0:
						# Всплески и искры во все стороны
						if (abs(bx - 32) < 4 or abs(by - 34) < 4 or abs(bx - by) < 4) and (bx * by) % 2 == 0:
							img.set_pixel(ox + bx, by, core_yellow)
			continue

		if is_die:
			# Разрыв брюха, хлещущий огонь
			for py in range(30, 60):
				for px in range(18, 46):
					var dist: float = Vector2(px - 32, (py - 48) * 1.3).length()
					if dist < 14.0:
						var col: Color = skin_dark if px < 32 else glow_deep
						if abs(px - 32) < 3:
							col = core_yellow
						img.set_pixel(ox + px, py, col)
			continue

		var cx: int = 32 + waddle_x
		var belly_cy: int = 35
		var belly_rx: int = 14 + belly_swell
		var belly_ry: int = 13 + belly_swell

		# 1. Короткие пухлые ножки-тумбы
		for y in range(46, 62):
			for x in range(cx - 10, cx - 3):
				img.set_pixel(ox + x, y, skin_dark if x == cx - 10 else skin_stretched)
			for x in range(cx + 3, cx + 10):
				img.set_pixel(ox + x, y, skin_dark if x == cx + 9 else skin_stretched)

		# 2. ОГРОМНОЕ раздутое брюхо-шар (доминирует над всем телом)
		for by in range(belly_cy - belly_ry, belly_cy + belly_ry + 1):
			for bx in range(cx - belly_rx, cx + belly_rx + 1):
				var norm_dist: float = (pow(float(bx - cx) / float(belly_rx), 2) + pow(float(by - belly_cy) / float(belly_ry), 2))
				if norm_dist <= 1.0:
					var bcol: Color = skin_stretched
					# Затемнение к краям шара
					if norm_dist > 0.8:
						bcol = skin_dark
					elif norm_dist > 0.6 and (bx + by) % 2 == 0:
						bcol = skin_dark

					# Пылающие магматические трещины на животе
					var crack_val: int = abs((bx * 3 - by * 5 + cx) % 7)
					var crack_cross: int = abs((bx * 4 + by * 3) % 9)
					if crack_val == 0 or crack_cross == 0:
						if crack_glow > 1.2:
							bcol = core_yellow if (bx + by) % 3 == 0 else lava_crack
						else:
							bcol = lava_crack if (bx + by) % 2 == 0 else glow_deep
					elif norm_dist < 0.4 and (bx + by) % 4 == 0:
						bcol = glow_deep

					img.set_pixel(ox + bx, by, bcol)

		# 3. Маленькая вдавленная голова поверх огромного брюха (y: 8-20)
		var head_cx: int = cx
		var head_cy: int = 15
		for hy in range(head_cy - 7, head_cy + 5):
			for hx in range(head_cx - 6, head_cx + 7):
				if Vector2(hx - head_cx, hy - head_cy).length() < 5.2:
					img.set_pixel(ox + hx, hy, skin_stretched if hx > head_cx - 2 else skin_dark)

		# Светящиеся злые глаза-бусинки
		img.set_pixel(ox + head_cx - 2, head_cy - 1, core_yellow)
		img.set_pixel(ox + head_cx + 2, head_cy - 1, core_yellow)
		img.set_pixel(ox + head_cx - 2, head_cy, glow_deep)
		img.set_pixel(ox + head_cx + 2, head_cy, glow_deep)

		# Искривленный рот
		for mx in range(head_cx - 2, head_cx + 3):
			img.set_pixel(ox + mx, head_cy + 3, skin_dark)

		# 4. Короткие пухлые ручки по бокам от огромного брюха
		for ay in range(24, 38):
			for ax in range(cx - belly_rx - 3, cx - belly_rx):
				if ax >= 0 and ax < 64:
					img.set_pixel(ox + ax, ay, skin_stretched)
			for ax in range(cx + belly_rx, cx + belly_rx + 3):
				if ax >= 0 and ax < 64:
					img.set_pixel(ox + ax, ay, skin_stretched)

		# Урон
		if is_hurt:
			for sy in range(belly_cy - belly_ry, belly_cy + belly_ry):
				for sx in range(cx - belly_rx, cx + belly_rx):
					if (sx * 7 + sy * 11) % 6 == 0:
						img.set_pixel(ox + sx, sy, core_yellow)
					elif (sx * 3 + sy * 5) % 7 == 0:
						img.set_pixel(ox + sx, sy, lava_crack)

	return img


# --- ДЕРЕВЬЯ, МАШИНЫ, ПЕРЕКАТИ-ПОЛЕ, КОСТИ, ИГРОК ---
static func make_dead_tree() -> Texture2D:
	return get_or_create("dead_tree.png", _generate_dead_tree_image)

static func _generate_dead_tree_image() -> Image:
	var w := 64
	var h := 96
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bark_base := Color(0.28, 0.20, 0.14, 1.0)
	var bark_dark := Color(0.18, 0.12, 0.08, 1.0)
	var bark_pale := Color(0.40, 0.30, 0.20, 1.0)

	for y in range(45, 96):
		var trunk_w: int = 4 + int(float(y - 45) * 0.18)
		for x in range(32 - trunk_w, 32 + trunk_w):
			img.set_pixel(x, y, bark_pale if x <= 32 - trunk_w + 1 else (bark_dark if x >= 32 + trunk_w - 2 else bark_base))

	for y in range(88, 96):
		for x in range(20, 27): img.set_pixel(x, y, bark_dark)
		for x in range(37, 45): img.set_pixel(x, y, bark_dark)

	for y in range(18, 50):
		var bx: int = 32 - int(float(50 - y) * 0.55)
		for x in range(bx - 2, bx + 2): img.set_pixel(x, y, bark_base)
		if y < 35:
			for x in range(bx - 8, bx): img.set_pixel(x, y - (bx - x) / 2, bark_pale)

	for y in range(12, 52):
		var bx: int = 32 + int(float(52 - y) * 0.50)
		for x in range(bx - 2, bx + 2): img.set_pixel(x, y, bark_base)
		if y < 30:
			for x in range(bx, bx + 10): img.set_pixel(x, y - (x - bx) / 2, bark_dark)

	for y in range(8, 30):
		var bx: int = 30 + int(sin(float(y) * 0.4) * 3.0)
		for x in range(bx - 1, bx + 2): img.set_pixel(x, y, bark_pale if x < bx else bark_dark)

	return img


static func make_wrecked_car() -> Texture2D:
	return get_or_create("wrecked_car.png", _generate_wrecked_car_image)

static func _generate_wrecked_car_image() -> Image:
	var w := 96
	var h := 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rust_base  := Color(0.52, 0.26, 0.12, 1.0)
	var rust_dark  := Color(0.35, 0.16, 0.08, 1.0)
	var rust_light := Color(0.68, 0.38, 0.18, 1.0)
	var glass_hole := Color(0.08, 0.08, 0.07, 1.0)
	var tire_rubber:= Color(0.14, 0.13, 0.12, 1.0)
	var rust_rim   := Color(0.40, 0.22, 0.10, 1.0)

	for y in range(18, 41):
		for x in range(8, 88):
			var col := rust_base
			if (x + y * 3) % 7 == 0: col = rust_dark
			elif (x * 2 + y) % 5 == 0: col = rust_light
			img.set_pixel(x, y, col)

	for y in range(22, 38):
		for x in range(8, 34):
			if not (y < 24 and x < 20):
				img.set_pixel(x, y, rust_light if y < 26 else rust_base)

	for y in range(8, 22):
		for x in range(34 + int(float(22 - y) * 0.4), 66 - int(float(22 - y) * 0.3)):
			img.set_pixel(x, y, rust_base)

	for y in range(12, 21):
		for x in range(37, 49): img.set_pixel(x, y, glass_hole)
		for x in range(51, 63): img.set_pixel(x, y, glass_hole)

	for y in range(34, 46):
		for x in range(18, 30):
			var d: float = Vector2(x - 24, y - 40).length()
			if d < 5.8: img.set_pixel(x, y, tire_rubber)
			if d < 2.5: img.set_pixel(x, y, rust_rim)
		for x in range(64, 76):
			var d: float = Vector2(x - 70, y - 40).length()
			if d < 5.8: img.set_pixel(x, y, tire_rubber)
			if d < 2.5: img.set_pixel(x, y, rust_rim)

	return img


static func make_tumbleweed() -> Texture2D:
	return get_or_create("tumbleweed.png", _generate_tumbleweed_image)

static func _generate_tumbleweed_image() -> Image:
	var s := 32
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var twig_base := Color(0.72, 0.58, 0.36, 1.0)
	var twig_dark := Color(0.48, 0.36, 0.20, 1.0)
	var twig_pale := Color(0.85, 0.72, 0.48, 1.0)
	var center := Vector2(16, 16)

	for y in range(s):
		for x in range(s):
			var d: float = center.distance_to(Vector2(x, y))
			if d < 13.5:
				var pat: int = int(sin(float(x) * 1.2) * 10.0 + cos(float(y) * 1.5) * 8.0 + float(x * y) * 0.1) % 7
				if pat == 0 or pat == 2 or pat == 4:
					img.set_pixel(x, y, twig_dark if d < 6.0 else (twig_pale if x > 16 else twig_base))
			elif d < 15.5 and (x * 7 + y * 13) % 9 == 0:
				img.set_pixel(x, y, twig_pale)

	return img


static func make_skull_bones() -> Texture2D:
	return get_or_create("skull_bones.png", _generate_skull_bones_image)

static func _generate_skull_bones_image() -> Image:
	var s := 32
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var bone_white := Color(0.88, 0.84, 0.74, 1.0)
	var bone_shadow:= Color(0.58, 0.52, 0.42, 1.0)
	var horn_dark  := Color(0.32, 0.24, 0.18, 1.0)
	var eye_socket := Color(0.18, 0.14, 0.10, 1.0)

	for x in range(4, 15):
		var y: int = 12 - int(float(14 - x) * 0.6)
		img.set_pixel(x, y, horn_dark)
		img.set_pixel(x, y + 1, horn_dark)
	for x in range(17, 28):
		var y: int = 12 - int(float(x - 17) * 0.6)
		img.set_pixel(x, y, horn_dark)
		img.set_pixel(x, y + 1, horn_dark)

	for y in range(10, 23):
		var w: int = 4 - int(float(y - 10) * 0.15)
		for x in range(16 - w, 16 + w):
			img.set_pixel(x, y, bone_white if x < 16 else bone_shadow)

	img.set_pixel(14, 13, eye_socket)
	img.set_pixel(18, 13, eye_socket)
	img.set_pixel(16, 17, eye_socket)

	for r in range(4):
		for x in range(23, 28):
			img.set_pixel(x, 20 + r * 2, bone_white)

	return img


static func make_player() -> Texture2D:
	return get_or_create("player.png", _generate_player_image)

static func _generate_player_image() -> Image:
	var img: Image = Image.create(48, 64, false, Image.FORMAT_RGBA8)
	var skin := Color(0.85, 0.65, 0.45, 1.0)
	var hat  := Color(0.20, 0.15, 0.10, 1.0)
	var shirt:= Color(0.18, 0.35, 0.55, 1.0)
	var pants:= Color(0.25, 0.22, 0.18, 1.0)
	var gun  := Color(0.12, 0.12, 0.12, 1.0)
	var band := Color(0.75, 0.20, 0.15, 1.0)

	for y in range(8, 11):
		for x in range(10, 38): img.set_pixel(x, y, hat)
	for y in range(3, 8):
		for x in range(16, 32): img.set_pixel(x, y, hat)
	for y in range(11, 19):
		for x in range(18, 30): img.set_pixel(x, y, skin)
	img.set_pixel(21, 14, Color(0.1, 0.1, 0.1, 1.0))
	img.set_pixel(26, 14, Color(0.1, 0.1, 0.1, 1.0))

	for y in range(18, 23):
		for x in range(19, 29): img.set_pixel(x, y, band)
	for y in range(23, 44):
		for x in range(15, 33): img.set_pixel(x, y, shirt)

	for y in range(24, 38):
		img.set_pixel(13, y, shirt)
		img.set_pixel(14, y, shirt)
		img.set_pixel(33, y, shirt)
		img.set_pixel(34, y, shirt)

	for y in range(37, 44): img.set_pixel(37, y, gun)
	for x in range(37, 43): img.set_pixel(x, 39, gun)

	for y in range(46, 60):
		for x in range(16, 23): img.set_pixel(x, y, pants)
		for x in range(25, 32): img.set_pixel(x, y, pants)
	for y in range(60, 64):
		for x in range(15, 23): img.set_pixel(x, y, hat)
		for x in range(25, 33): img.set_pixel(x, y, hat)

	return img


# =========================================================================
# ТЕКСТУРЫ ДЛЯ 3D МОДЕЛИ ИГРОКА / НАПАРНИКА (Third-Person Cowboy Model)
# =========================================================================

# 1. Текстура лица ковбоя (глаза, усы, щетина, бандана)
static func make_player_face_texture() -> Texture2D:
	return get_or_create("player_face.png", _generate_player_face_texture)

static func _generate_player_face_texture() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var skin_base  := Color(0.78, 0.58, 0.44, 1.0)
	var skin_dark  := Color(0.64, 0.46, 0.34, 1.0)
	var skin_light := Color(0.86, 0.67, 0.52, 1.0)
	var brow_col   := Color(0.20, 0.12, 0.08, 1.0)
	var eye_white  := Color(0.92, 0.92, 0.94, 1.0)
	var eye_iris   := Color(0.26, 0.16, 0.10, 1.0)
	var stache_col := Color(0.22, 0.14, 0.08, 1.0)
	var stache_hl  := Color(0.36, 0.24, 0.15, 1.0)
	var stubble    := Color(0.56, 0.40, 0.30, 1.0)
	var band_red   := Color(0.72, 0.16, 0.12, 1.0)
	var band_dark  := Color(0.50, 0.10, 0.08, 1.0)
	var band_dot   := Color(0.95, 0.90, 0.86, 1.0)

	# Базовая кожа лица с естественным затенением по краям
	for y in range(0, 24):
		for x in range(0, 32):
			var col := skin_base
			if x < 4 or x > 27 or y < 3:
				col = skin_dark
			elif y >= 4 and y <= 8 and x >= 10 and x <= 21:
				col = skin_light
			img.set_pixel(x, y, col)

	# Густые брови
	for x in range(6, 13):
		img.set_pixel(x, 8, brow_col)
		img.set_pixel(x, 9, brow_col)
	for x in range(19, 26):
		img.set_pixel(x, 8, brow_col)
		img.set_pixel(x, 9, brow_col)

	# Глаза с бликами
	for y in range(10, 13):
		for x in range(7, 12):
			img.set_pixel(x, y, eye_white)
		for x in range(20, 25):
			img.set_pixel(x, y, eye_white)
	# Радужка и зрачок
	img.set_pixel(9, 11, eye_iris)
	img.set_pixel(10, 11, eye_iris)
	img.set_pixel(9, 12, eye_iris)
	img.set_pixel(10, 12, eye_iris)
	img.set_pixel(22, 11, eye_iris)
	img.set_pixel(23, 11, eye_iris)
	img.set_pixel(22, 12, eye_iris)
	img.set_pixel(23, 12, eye_iris)
	# Блик в глазу
	img.set_pixel(9, 11, Color(1.0, 1.0, 1.0, 1.0))
	img.set_pixel(22, 11, Color(1.0, 1.0, 1.0, 1.0))

	# Нос с ноздрями
	for y in range(12, 17):
		img.set_pixel(15, y, skin_light)
		img.set_pixel(16, y, skin_light)
	img.set_pixel(14, 16, skin_dark)
	img.set_pixel(17, 16, skin_dark)

	# Пышные ковбойские усы подковой
	for x in range(8, 24):
		img.set_pixel(x, 18, stache_col)
		img.set_pixel(x, 19, stache_col)
	for x in range(10, 22):
		img.set_pixel(x, 17, stache_col)
	# Кончики усов спускаются вниз
	img.set_pixel(8, 20, stache_col)
	img.set_pixel(8, 21, stache_hl)
	img.set_pixel(23, 20, stache_col)
	img.set_pixel(23, 21, stache_hl)

	# Мужественная щетина на подбородке
	for y in range(20, 24):
		for x in range(10, 22):
			if (x + y) % 2 == 0 and img.get_pixel(x, y) == skin_base:
				img.set_pixel(x, y, stubble)

	# Красная шейная бандана с узором
	for y in range(24, 32):
		for x in range(0, 32):
			var b_col := band_red if (x + y) % 3 != 0 else band_dark
			img.set_pixel(x, y, b_col)
	# Мелкие узорные крапинки
	for y in range(25, 31, 2):
		for x in range(2, 30, 4):
			img.set_pixel(x, y, band_dot)

	return img


# 2. Текстура кожаного жилета и рубашки
static func make_player_torso_texture() -> Texture2D:
	return get_or_create("player_torso.png", _generate_player_torso_texture)

static func _generate_player_torso_texture() -> Image:
	var img: Image = Image.create(64, 64, true, Image.FORMAT_RGBA8)
	var leather_base := Color(0.32, 0.20, 0.12, 1.0)
	var leather_dark := Color(0.20, 0.12, 0.07, 1.0)
	var leather_st   := Color(0.56, 0.40, 0.24, 1.0)
	var brass_btn    := Color(0.85, 0.72, 0.28, 1.0)

	var shirt_blue   := Color(0.24, 0.36, 0.52, 1.0)
	var shirt_tan    := Color(0.72, 0.65, 0.52, 1.0)
	var shirt_navy   := Color(0.14, 0.22, 0.34, 1.0)
	var pearl_snap   := Color(0.95, 0.95, 0.98, 1.0)

	for y in range(0, 64):
		for x in range(0, 64):
			if x >= 20 and x <= 43:
				# Клетчатая ковбойская рубашка (Plaid shirt) с мягкими 8-пиксельными полосами
				var is_h := (y % 8 < 2)
				var is_v := (x % 8 < 2)
				var c := shirt_blue
				if is_h and is_v:
					c = shirt_navy
				elif is_h or is_v:
					c = shirt_tan
				img.set_pixel(x, y, c)
			else:
				# Коричневый кожаный жилет с мягким затемнением по контуру
				var l_col := leather_base
				if x == 18 or x == 19 or x == 44 or x == 45:
					l_col = leather_dark
				img.set_pixel(x, y, l_col)

	# Строчка шва на кожаном жилете
	for y in range(4, 60):
		img.set_pixel(16, y, leather_st)
		img.set_pixel(47, y, leather_st)

	# Перламутровые кнопки на планке рубашки
	for y in [12, 24, 36, 48]:
		for dx in range(0, 2):
			for dy in range(0, 2):
				img.set_pixel(31 + dx, y + dy, pearl_snap)

	# Латунные пуговицы на жилете
	for y in [16, 32, 48]:
		for dx in range(0, 2):
			for dy in range(0, 2):
				img.set_pixel(12 + dx, y + dy, brass_btn)
				img.set_pixel(51 + dx, y + dy, brass_btn)

	img.generate_mipmaps()
	return img


# 3. Текстура джинсов (Denim Jeans)
static func make_player_denim_texture() -> Texture2D:
	return get_or_create("player_denim.png", _generate_player_denim_texture)

static func _generate_player_denim_texture() -> Image:
	var img: Image = Image.create(64, 64, true, Image.FORMAT_RGBA8)
	var denim_base := Color(0.20, 0.28, 0.40, 1.0)
	var denim_fade := Color(0.28, 0.37, 0.50, 1.0)
	var denim_dark := Color(0.14, 0.19, 0.29, 1.0)
	var seam_gold  := Color(0.85, 0.60, 0.20, 1.0)
	var rivet_cop  := Color(0.90, 0.55, 0.25, 1.0)

	for y in range(0, 64):
		for x in range(0, 64):
			var d_col := denim_base
			var fold: float = sin(float(y) * 0.35) * 0.03
			d_col = d_col.lerp(denim_dark, clampf(fold + 0.05, 0.0, 0.25))
			# Мягкая естественная потертость ткани на бедрах и коленях
			if (y >= 16 and y <= 48) and (x >= 12 and x <= 50):
				var fade_factor: float = sin(float(x - 12) / 38.0 * PI) * sin(float(y - 16) / 32.0 * PI) * 0.40
				d_col = d_col.lerp(denim_fade, fade_factor)
			img.set_pixel(x, y, d_col)

	# Оранжево-золотой двойной шов по бокам штанин
	for y in range(0, 64):
		img.set_pixel(4, y, seam_gold)
		img.set_pixel(5, y, seam_gold * 0.8)
		img.set_pixel(58, y, seam_gold * 0.8)
		img.set_pixel(59, y, seam_gold)

	# Медные заклепки
	for y in [6, 56]:
		for dx in range(0, 2):
			for dy in range(0, 2):
				img.set_pixel(4 + dx, y + dy, rivet_cop)
				img.set_pixel(58 + dx, y + dy, rivet_cop)

	img.generate_mipmaps()
	return img


# 4. Текстура темной кожи (для шляпы, сапог, кобуры и пояса)
static func make_player_leather_texture() -> Texture2D:
	return get_or_create("player_leather.png", _generate_player_leather_texture)

static func _generate_player_leather_texture() -> Image:
	var img: Image = Image.create(64, 64, true, Image.FORMAT_RGBA8)
	var l_dark := Color(0.20, 0.13, 0.08, 1.0)
	var l_mid  := Color(0.28, 0.18, 0.12, 1.0)
	var l_lite := Color(0.42, 0.28, 0.18, 1.0)
	var metal  := Color(0.80, 0.82, 0.86, 1.0)

	for y in range(0, 64):
		for x in range(0, 64):
			var c := l_mid
			if (x < 4 or x > 59 or y < 4 or y > 59):
				c = l_dark
			img.set_pixel(x, y, c)

	# Прошивка светлой нитью
	for i in range(4, 60, 4):
		for d in range(0, 2):
			img.set_pixel(i + d, 6, l_lite)
			img.set_pixel(i + d, 57, l_lite)
			img.set_pixel(6, i + d, l_lite)
			img.set_pixel(57, i + d, l_lite)

	# Металлические заклепки / пряжка
	for dx in range(0, 4):
		for dy in range(0, 4):
			img.set_pixel(30 + dx, 30 + dy, metal)

	img.generate_mipmaps()
	return img


# 5. Текстура ковбойской шляпы стетсон
static func make_player_hat_texture() -> Texture2D:
	return get_or_create("player_hat.png", _generate_player_hat_texture)

static func _generate_player_hat_texture() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var hat_dark := Color(0.18, 0.12, 0.08, 1.0)
	var hat_mid  := Color(0.26, 0.18, 0.12, 1.0)
	var hat_band := Color(0.10, 0.06, 0.04, 1.0)
	var concho   := Color(0.88, 0.88, 0.92, 1.0)

	for y in range(0, 32):
		for x in range(0, 32):
			var c := hat_mid
			if y < 4 or y > 27:
				c = hat_dark
			img.set_pixel(x, y, c)

	# Кожаный шляпный ремешок (Hatband)
	for y in range(13, 17):
		for x in range(0, 32):
			img.set_pixel(x, y, hat_band)

	# Серебряные ковбойские кончо (бляхи) на ремешке
	for x in [4, 12, 20, 28]:
		img.set_pixel(x, 14, concho)
		img.set_pixel(x + 1, 14, concho)
		img.set_pixel(x, 15, concho)
		img.set_pixel(x + 1, 15, concho)

	return img

# 1. РЕВОЛЬВЕР .44
static func make_weapon_revolver() -> Texture2D:
	return get_or_create("weapon_revolver.png", _generate_weapon_revolver_image)

static func _generate_weapon_revolver_image() -> Image:
	var w := 128
	var h := 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var metal_dark := Color(0.16, 0.16, 0.18, 1.0)
	var metal_mid  := Color(0.28, 0.28, 0.32, 1.0)
	var metal_light:= Color(0.48, 0.48, 0.54, 1.0)
	var wood       := Color(0.40, 0.22, 0.12, 1.0)
	var skin       := Color(0.78, 0.60, 0.42, 1.0)

	var cx := 64

	# Длинный ствол по центру (y: 35..85, x: 58..70)
	for y in range(35, 85):
		for x in range(cx - 6, cx + 7):
			var col := metal_mid
			if x == cx - 6: col = metal_light
			elif x >= cx + 5: col = metal_dark
			img.set_pixel(x, y, col)

	# Мушка на конце ствола
	for y in range(30, 36):
		for x in range(cx - 2, cx + 3):
			img.set_pixel(x, y, metal_light if x == cx - 1 else metal_dark)

	# Барабан (y: 85..105, x: 52..76)
	for y in range(85, 106):
		for x in range(cx - 12, cx + 13):
			var col := metal_mid
			if (x - cx) % 5 == 0: col = metal_dark
			elif (x - cx) % 5 == 1: col = metal_light
			img.set_pixel(x, y, col)

	# Курок
	for y in range(88, 98):
		img.set_pixel(cx, y, metal_light)
		img.set_pixel(cx + 1, y, metal_light)

	# Рукоятка деревянная (y: 105..127, x: 58..74)
	for y in range(105, 128):
		for x in range(cx - 4, cx + 10):
			img.set_pixel(x, y, wood)

	# Рука стрелка снизу (y: 100..127, x: 44..84)
	for y in range(100, 128):
		for x in range(cx - 18, cx + 18):
			if not (x >= cx - 4 and x <= cx + 8 and y >= 105):
				if Vector2(x - cx, y - 114).length() < 16.0:
					img.set_pixel(x, y, skin)

	return img


# 2. ДВУСТВОЛКА (SUPER SHOTGUN)
static func make_weapon_shotgun() -> Texture2D:
	return get_or_create("weapon_shotgun.png", _generate_weapon_shotgun_image)

static func _generate_weapon_shotgun_image() -> Image:
	var w := 160
	var h := 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var steel_dark := Color(0.12, 0.12, 0.14, 1.0)
	var steel_mid  := Color(0.24, 0.24, 0.28, 1.0)
	var steel_light:= Color(0.44, 0.44, 0.50, 1.0)
	var wood       := Color(0.35, 0.18, 0.10, 1.0)
	var wood_dark  := Color(0.22, 0.10, 0.05, 1.0)
	var skin       := Color(0.78, 0.60, 0.42, 1.0)

	var cx := 80

	# Левый ствол (x: 65..77, y: 32..88)
	for y in range(32, 88):
		for x in range(cx - 15, cx - 2):
			var col := steel_mid
			if x == cx - 15: col = steel_light
			elif x == cx - 3: col = steel_dark
			img.set_pixel(x, y, col)
	# Дульное отверстие левого ствола
	for x in range(cx - 13, cx - 4):
		img.set_pixel(x, 32, Color(0.04, 0.04, 0.04, 1.0))
		img.set_pixel(x, 33, Color(0.04, 0.04, 0.04, 1.0))

	# Правый ствол (x: 82..94, y: 32..88)
	for y in range(32, 88):
		for x in range(cx + 2, cx + 15):
			var col := steel_mid
			if x == cx + 2: col = steel_light
			elif x == cx + 14: col = steel_dark
			img.set_pixel(x, y, col)
	# Дульное отверстие правого ствола
	for x in range(cx + 4, cx + 13):
		img.set_pixel(x, 32, Color(0.04, 0.04, 0.04, 1.0))
		img.set_pixel(x, 33, Color(0.04, 0.04, 0.04, 1.0))

	# Перемычка и планка между стволами
	for y in range(34, 88):
		for x in range(cx - 2, cx + 2):
			img.set_pixel(x, y, steel_dark)

	# Мушка посередине
	img.set_pixel(cx - 1, 31, steel_light)
	img.set_pixel(cx, 31, steel_light)

	# Деревянное цевье (y: 75..110, x: 60..100)
	for y in range(75, 110):
		for x in range(cx - 19, cx + 19):
			var col := wood if (x + y) % 6 != 0 else wood_dark
			img.set_pixel(x, y, col)

	# Руки держащие двустволку
	# Левая рука (держит цевье снизу)
	for y in range(92, 128):
		for x in range(cx - 30, cx - 12):
			img.set_pixel(x, y, skin)
	# Правая рука (держит шейку ложи)
	for y in range(95, 128):
		for x in range(cx + 12, cx + 32):
			img.set_pixel(x, y, skin)

	return img


# 3. АВТОМАТ КАРАВАНА (ASSAULT RIFLE)
static func make_weapon_rifle() -> Texture2D:
	return get_or_create("weapon_rifle.png", _generate_weapon_rifle_image)

static func _generate_weapon_rifle_image() -> Image:
	var w := 140
	var h := 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var metal_dark := Color(0.14, 0.14, 0.15, 1.0)
	var metal_mid  := Color(0.25, 0.26, 0.28, 1.0)
	var metal_light:= Color(0.45, 0.46, 0.50, 1.0)
	var khaki      := Color(0.42, 0.38, 0.28, 1.0)
	var skin       := Color(0.78, 0.60, 0.42, 1.0)

	var cx := 70

	# Тонкий ствол со щелевым пламегасителем (y: 24..65, x: 66..74)
	for y in range(24, 65):
		for x in range(cx - 4, cx + 5):
			img.set_pixel(x, y, metal_mid if x < cx else metal_dark)

	# Мушка в кольце (y: 20..27)
	img.set_pixel(cx, 20, metal_light)
	img.set_pixel(cx - 1, 21, metal_light)
	img.set_pixel(cx + 1, 21, metal_light)

	# Газоотводная трубка
	for y in range(28, 60):
		img.set_pixel(cx, y, metal_light)

	# Ствольная коробка и цевье (y: 65..110, x: 58..82)
	for y in range(65, 110):
		for x in range(cx - 11, cx + 12):
			var col := khaki if y > 72 and y < 98 else metal_mid
			if x == cx - 11: col = metal_light
			elif x >= cx + 10: col = metal_dark
			img.set_pixel(x, y, col)

	# Магазин изогнутый снизу слева (y: 96..127, x: 50..66)
	for y in range(96, 128):
		var curve: int = int((y - 96) * 0.25)
		for x in range(cx - 14 - curve, cx - 4 - curve):
			img.set_pixel(x, y, metal_dark)

	# Руки
	for y in range(95, 128):
		for x in range(cx - 24, cx - 12): img.set_pixel(x, y, skin)
		for x in range(cx + 12, cx + 28): img.set_pixel(x, y, skin)

	return img


# 4. ТЯЖЕЛАЯ РАКЕТНИЦА (ROCKET LAUNCHER)
static func make_weapon_rocket() -> Texture2D:
	return get_or_create("weapon_rocket.png", _generate_weapon_rocket_image)

static func _generate_weapon_rocket_image() -> Image:
	var w := 160
	var h := 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var tube_base := Color(0.24, 0.32, 0.22, 1.0) # военный хаки/олива
	var tube_dark := Color(0.14, 0.20, 0.12, 1.0)
	var tube_light:= Color(0.38, 0.48, 0.34, 1.0)
	var warhead   := Color(0.78, 0.18, 0.12, 1.0) # красный наконечник ракеты
	var warhead_b := Color(0.20, 0.20, 0.20, 1.0)
	var skin      := Color(0.78, 0.60, 0.42, 1.0)

	var cx := 80

	# Ракета торчащая из трубы (y: 18..44)
	for y in range(18, 44):
		var rw: int = 1 + int(float(y - 18) * 0.45)
		if rw > 9: rw = 9
		for x in range(cx - rw, cx + rw + 1):
			var col := warhead if y < 30 else warhead_b
			img.set_pixel(x, y, col)

	# Широкая ракетная труба (y: 40..115, x: 64..96)
	for y in range(40, 115):
		for x in range(cx - 16, cx + 17):
			var col := tube_base
			if x <= cx - 14: col = tube_light
			elif x >= cx + 14: col = tube_dark
			img.set_pixel(x, y, col)

	# Утолщенный раструб трубы на срезе (y: 40..46, x: 60..100)
	for y in range(40, 46):
		for x in range(cx - 19, cx + 20):
			img.set_pixel(x, y, tube_light if x < cx else tube_dark)

	# Прицельная стойка сбоку
	for y in range(35, 60):
		img.set_pixel(cx - 21, y, Color(0.1, 0.1, 0.1, 1.0))
		img.set_pixel(cx - 20, y, Color(0.8, 0.8, 0.2, 1.0))

	# Руки держащие базуку
	for y in range(92, 128):
		for x in range(cx - 30, cx - 14): img.set_pixel(x, y, skin)
		for x in range(cx + 14, cx + 32): img.set_pixel(x, y, skin)

	return img


# 5. ВСПЫШКА ВЫСТРЕЛА (MUZZLE FLASH)
static func make_muzzle_flash() -> Texture2D:
	return get_or_create("muzzle_flash.png", _generate_muzzle_flash_image)

static func _generate_muzzle_flash_image() -> Image:
	var s := 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	var f_white := Color(1.0, 1.0, 0.9, 1.0)
	var f_yellow:= Color(1.0, 0.85, 0.2, 0.9)
	var f_orange:= Color(1.0, 0.45, 0.05, 0.7)

	for y in range(s):
		for x in range(s):
			var d: float = center.distance_to(Vector2(x, y))
			if d < 7.0:
				img.set_pixel(x, y, f_white)
			elif d < 15.0:
				img.set_pixel(x, y, f_yellow)
			elif d < 25.0 and (x * y) % 3 != 0:
				img.set_pixel(x, y, f_orange)
			# Всплески пламени в стороны
			elif (abs(x - 32) < 4 and d < 30.0) or (abs(y - 32) < 4 and d < 30.0):
				img.set_pixel(x, y, f_yellow)

	return img


# =========================================================================
# 6. СЛЕД КОЛЕСА КАРАВАНА НА ПЕСКЕ (WHEEL TRACK)
# =========================================================================
static func make_wheel_track() -> Texture2D:
	return get_or_create("wheel_track.png", _generate_wheel_track_image)

static func _generate_wheel_track_image() -> Image:
	var w := 32
	var h := 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		var y_fade: float = sin((float(y) / float(h)) * PI)
		for x in range(w):
			# Центральная дорожка шириной 20 пикселей (от x=6 до x=26)
			var dist_center: float = abs(float(x) - 16.0)
			if dist_center > 11.0:
				continue

			var groove_depth: float = 0.0
			# Две глубокие колеи от железного обода колеса каравана
			var d_groove: float = abs(dist_center - 5.0)
			if d_groove < 3.5:
				groove_depth = 1.0 - (d_groove / 3.5)

			# Поперечные бороздки от спиц и неровностей колеса
			var rib: float = sin(float(y) * 0.45) * 0.25
			var alpha: float = clampf((groove_depth * 0.75 + 0.25 + rib) * y_fade, 0.0, 0.95)

			# Темный оттенок спрессованного в колее песка
			var r: float = lerpf(0.50, 0.26, groove_depth)
			var g: float = lerpf(0.36, 0.17, groove_depth)
			var b: float = lerpf(0.20, 0.09, groove_depth)
			img.set_pixel(x, y, Color(r, g, b, alpha))

	return img


# =========================================================================
# 7. СЛЕД БОТИНКА ИГРОКА НА ПЕСКЕ (FOOTPRINT BOOT)
# =========================================================================
static func make_footprint_boot() -> Texture2D:
	return get_or_create("footprint_boot.png", _generate_footprint_boot_image)

static func _generate_footprint_boot_image() -> Image:
	var w := 32
	var h := 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var nx: float = (float(x) - 16.0) / 10.0
			var inside: bool = false
			var depth: float = 0.0

			# Носок и подушечка стопы (y: 6..24)
			if y >= 6 and y <= 24:
				var half_w: float = 1.0 - pow((float(y) - 16.0) / 11.0, 2.0) * 0.35
				if abs(nx) <= half_w:
					inside = true
					depth = 0.85
					# Рельефные протекторы ботинка (горизонтальные насечки)
					if y % 4 == 0:
						depth = 0.4

			# Свод стопы (y: 24..30)
			elif y > 24 and y < 30:
				if nx > -0.45 and nx < 0.65:
					inside = true
					depth = 0.55

			# Пятка (y: 30..42)
			elif y >= 30 and y <= 42:
				var half_w: float = 0.75 - pow((float(y) - 36.0) / 7.0, 2.0) * 0.25
				if abs(nx) <= half_w:
					inside = true
					depth = 0.95
					if y % 4 == 0:
						depth = 0.5

			if inside:
				var edge_fade: float = 1.0 - pow(nx * 0.85, 4.0)
				var alpha: float = clampf(depth * edge_fade * 0.88, 0.0, 0.9)
				var c := Color(0.28, 0.18, 0.10, alpha)
				img.set_pixel(x, y, c)

	return img


# =========================================================================
# 8. СЛЕД КОПЫТА ОСЛА НА ПЕСКЕ (FOOTPRINT HOOF)
# =========================================================================
static func make_footprint_hoof() -> Texture2D:
	return get_or_create("footprint_hoof.png", _generate_footprint_hoof_image)

static func _generate_footprint_hoof_image() -> Image:
	var s := 32
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 14)

	for y in range(s):
		for x in range(s):
			var pos := Vector2(x, y)
			var d: float = center.distance_to(pos)
			var inside: bool = false
			var depth: float = 0.0

			# Внешняя подкова копыта (овальная дуга)
			var angle := atan2(pos.y - center.y, pos.x - center.x)
			if d >= 5.5 and d <= 11.5 and pos.y <= 24:
				inside = true
				depth = 0.92
			# Центральная стрелка копыта осла ("V"-образная выемка)
			elif d < 5.5 and pos.y >= 10 and pos.y <= 21 and abs(pos.x - 16) <= (pos.y - 10) * 0.6:
				inside = true
				depth = 0.75

			if inside:
				var alpha: float = clampf(depth * 0.92, 0.0, 0.95)
				img.set_pixel(x, y, Color(0.24, 0.15, 0.08, alpha))

	return img


# =========================================================================
# 9. БРЫЗГИ И ПЯТНА КРОВИ НА ПЕСКЕ (BLOOD SPLATTER)
# =========================================================================
static func make_blood_splatter() -> Texture2D:
	return get_or_create("blood_splatter.png", _generate_blood_splatter_image)

static func _generate_blood_splatter_image() -> Image:
	var s := 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	var c_core := Color(0.38, 0.02, 0.03, 0.96)
	var c_mid  := Color(0.55, 0.04, 0.05, 0.90)
	var c_edge := Color(0.28, 0.08, 0.06, 0.75)

	# Детерминированный генератор для повторяемости
	var rng := RandomNumberGenerator.new()
	rng.seed = 77192

	# 1. Центральное ядро кляксы
	for y in range(s):
		for x in range(s):
			var pos := Vector2(x, y)
			var d: float = center.distance_to(pos)
			var angle: float = atan2(pos.y - center.y, pos.x - center.x)
			# Неровные органические края
			var r_max: float = 9.0 + sin(angle * 5.0) * 3.5 + cos(angle * 3.0 + 1.2) * 2.0
			if d <= r_max:
				var t: float = d / maxf(r_max, 1.0)
				var c: Color = c_core.lerp(c_edge, t)
				img.set_pixel(x, y, c)

	# 2. Разлетающиеся капли и струи брызг в стороны
	for i in range(16):
		var sp_angle: float = (float(i) / 16.0) * TAU + rng.randf_range(-0.15, 0.15)
		var sp_dist: float = rng.randf_range(11.0, 26.0)
		var drop_center := center + Vector2(cos(sp_angle), sin(sp_angle)) * sp_dist
		var drop_radius: float = rng.randf_range(1.4, 3.2)

		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var px: int = int(drop_center.x) + dx
				var py: int = int(drop_center.y) + dy
				if px >= 0 and px < s and py >= 0 and py < s:
					var dist_d: float = drop_center.distance_to(Vector2(px, py))
					if dist_d <= drop_radius:
						img.set_pixel(px, py, c_mid)

	return img


# =========================================================================
# 10. БОЛЬШАЯ ЛУЖА КРОВИ (BLOOD POOL)
# =========================================================================
static func make_blood_pool() -> Texture2D:
	return get_or_create("blood_pool.png", _generate_blood_pool_image)

static func _generate_blood_pool_image() -> Image:
	var s := 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)

	var c_deep := Color(0.26, 0.01, 0.02, 0.98)
	var c_fresh:= Color(0.48, 0.03, 0.04, 0.92)
	var c_soak := Color(0.32, 0.10, 0.07, 0.70)

	for y in range(s):
		for x in range(s):
			var pos := Vector2(x, y)
			var d: float = center.distance_to(pos)
			var angle: float = atan2(pos.y - center.y, pos.x - center.x)

			# Аморфная форма растекающейся по песку лужи
			var r_pool: float = 21.0 + sin(angle * 4.0) * 4.0 + cos(angle * 7.0) * 2.5 + sin(angle * 2.0) * 3.0
			if d <= r_pool:
				var t: float = d / r_pool
				var c: Color = c_deep.lerp(c_soak, pow(t, 1.4))
				img.set_pixel(x, y, c)
			elif d <= r_pool + 2.5:
				var edge_fade: float = 1.0 - (d - r_pool) / 2.5
				img.set_pixel(x, y, Color(c_soak.r, c_soak.g, c_soak.b, c_soak.a * edge_fade))

	return img


# =========================================================================
# 11. МЯГКИЙ КЛУБ ПЕСКА / ПЫЛИ (SAND PUFF)
# =========================================================================
static func make_sand_puff() -> Texture2D:
	return get_or_create("sand_puff.png", _generate_sand_puff_image)

static func _generate_sand_puff_image() -> Image:
	var s := 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	var sand_color := Color(0.92, 0.78, 0.54)

	for y in range(s):
		for x in range(s):
			var pos := Vector2(x, y)
			var d: float = center.distance_to(pos)
			var angle: float = atan2(pos.y - center.y, pos.x - center.x)

			# Пушистые клубящиеся облачные лепестки
			var r_cloud: float = 26.0 + sin(angle * 3.0) * 3.5 + cos(angle * 5.0 + 0.8) * 2.5
			if d <= r_cloud:
				var norm_d: float = d / r_cloud
				# Мягкий спад плотности (косинусный)
				var alpha: float = 0.5 * (1.0 + cos(norm_d * PI))
				alpha = pow(alpha, 1.3) * 0.72
				img.set_pixel(x, y, Color(sand_color.r, sand_color.g, sand_color.b, alpha))

	return img
