extends Node

# =========================================================================
# МЕНЕДЖЕР ПЕСЧАНЫХ ЭФФЕКТОВ, СЛЕДОВ, КРОВИ И БУРИ (Sand Effects Manager)
# Управляет:
# 1. Следами колес повозки каравана
# 2. Следами копыт осла и шагов игрока на песке + хруст песка
# 3. Следами и лужами крови на песке (от пуль, бензопилы и взрывов)
# 4. Летающими клубами песка (песчаная буря / поземка)
# 5. Песчаными завываниями ветра (атмосферный эмбиент)
# =========================================================================

# Текстуры
var tex_wheel_track: Texture2D
var tex_footprint_boot: Texture2D
var tex_footprint_hoof: Texture2D
var tex_blood_splatter: Texture2D
var tex_blood_pool: Texture2D
var tex_sand_puff: Texture2D

# Звуки
var snd_step: AudioStream
var snd_wind: AudioStream

# Аудио плееры
var wind_player: AudioStreamPlayer
var step_players: Array[AudioStreamPlayer3D] = []
var step_player_idx: int = 0
const MAX_STEP_PLAYERS: int = 4

# Частицы летающего песка
var sand_cloud_particles: CPUParticles3D
var anim_time: float = 0.0

# Контейнеры декалей
var marks_root: Node3D
var active_decals: Array[Decal] = []
var decal_lifetimes: Array[float] = []
var decal_max_lifetimes: Array[float] = []

const MAX_ACTIVE_DECALS: int = 240

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_resources()
	_setup_containers()
	_setup_wind_audio()
	_setup_sand_clouds()
	_setup_step_audio()

func _init_resources() -> void:
	tex_wheel_track    = TextureGen.make_wheel_track()
	tex_footprint_boot = TextureGen.make_footprint_boot()
	tex_footprint_hoof = TextureGen.make_footprint_hoof()
	tex_blood_splatter = TextureGen.make_blood_splatter()
	tex_blood_pool     = TextureGen.make_blood_pool()
	tex_sand_puff      = TextureGen.make_sand_puff()

	if ResourceLoader.exists("res://assets/audio/step_sand.wav"):
		snd_step = load("res://assets/audio/step_sand.wav") as AudioStream
	if ResourceLoader.exists("res://assets/audio/sand_wind_howl.wav"):
		snd_wind = load("res://assets/audio/sand_wind_howl.wav") as AudioStream

func _setup_containers() -> void:
	marks_root = Node3D.new()
	marks_root.name = "SandMarksRoot"
	add_child(marks_root)

func _setup_wind_audio() -> void:
	if not snd_wind:
		return

	wind_player = AudioStreamPlayer.new()
	wind_player.name = "DesertWindHowlPlayer"
	wind_player.stream = snd_wind
	wind_player.bus = "Master"
	wind_player.volume_db = -10.5
	add_child(wind_player)

	# Бесшовное зацикливание песчаного завывания ветра
	if snd_wind is AudioStreamWAV:
		(snd_wind as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind_player.finished.connect(func():
		if is_instance_valid(wind_player):
			wind_player.play()
	)
	wind_player.play()

func _setup_step_audio() -> void:
	if not snd_step:
		return
	for i in range(MAX_STEP_PLAYERS):
		var sp := AudioStreamPlayer3D.new()
		sp.name = "SandStepAudio_%d" % i
		sp.stream = snd_step
		sp.bus = "Master"
		sp.volume_db = -7.0
		sp.max_distance = 25.0
		sp.attenuation_filter_cutoff_hz = 6000.0
		add_child(sp)
		step_players.append(sp)

func _setup_sand_clouds() -> void:
	sand_cloud_particles = CPUParticles3D.new()
	sand_cloud_particles.name = "FlyingSandClouds"
	sand_cloud_particles.amount = 50
	sand_cloud_particles.lifetime = 3.6
	sand_cloud_particles.preprocess = 2.0
	sand_cloud_particles.randomness = 0.5
	sand_cloud_particles.explosiveness = 0.0

	sand_cloud_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# Охват 70х70 метров вокруг камеры/каравана
	sand_cloud_particles.emission_box_extents = Vector3(36.0, 1.8, 36.0)

	# Направление ветра пустыни — дует по диагонали через барханы
	sand_cloud_particles.direction = Vector3(-1.0, 0.04, -0.55).normalized()
	sand_cloud_particles.spread = 18.0
	sand_cloud_particles.initial_velocity_min = 9.0
	sand_cloud_particles.initial_velocity_max = 16.0
	sand_cloud_particles.gravity = Vector3(0.0, -0.3, 0.0)

	sand_cloud_particles.scale_amount_min = 4.0
	sand_cloud_particles.scale_amount_max = 8.5

	# Цветовая кривая: мягкое появление из прозрачности и растворение
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.92, 0.78, 0.52, 0.0),
		Color(0.90, 0.75, 0.48, 0.38),
		Color(0.85, 0.68, 0.42, 0.35),
		Color(0.80, 0.62, 0.38, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.20, 0.75, 1.0])
	sand_cloud_particles.color_ramp = grad

	# Материал для клубящихся частиц песка
	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_texture = tex_sand_puff
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.billboard_keep_scale = true

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = p_mat
	sand_cloud_particles.mesh = quad

	add_child(sand_cloud_particles)

func _process(delta: float) -> void:
	anim_time += delta

	# 1. Завывание ветра — живые порывы (громкость плавно дышит)
	if wind_player and wind_player.playing:
		var gust: float = sin(anim_time * 0.45) * 2.2 + cos(anim_time * 0.95) * 1.2
		wind_player.volume_db = -10.5 + gust

	# 2. Позиционирование летающих клубов песка рядом с игроком или караваном
	if sand_cloud_particles:
		var fpos := _get_active_focus_position()
		sand_cloud_particles.global_position = Vector3(fpos.x, 1.4, fpos.z)

	# 3. Плавное затухание декалей со временем
	_update_decals(delta)

func _get_active_focus_position() -> Vector3:
	var viewport := get_viewport()
	if viewport:
		var cam := viewport.get_camera_3d()
		if cam:
			return cam.global_position

	var caravan := get_tree().get_first_node_in_group("caravan") as Node3D
	if caravan and is_instance_valid(caravan):
		return caravan.global_position

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and is_instance_valid(player):
		return player.global_position

	return Vector3.ZERO

func _update_decals(delta: float) -> void:
	var i: int = active_decals.size() - 1
	while i >= 0:
		if i >= active_decals.size():
			i -= 1
			continue

		var dec: Decal = active_decals[i]
		if not is_instance_valid(dec):
			active_decals.remove_at(i)
			decal_lifetimes.remove_at(i)
			decal_max_lifetimes.remove_at(i)
			i -= 1
			continue

		decal_lifetimes[i] -= delta
		var cur_lt: float = decal_lifetimes[i]
		var max_lt: float = decal_max_lifetimes[i]

		# В последние 20% времени декаль плавно засыпается песчинками
		var fade_dur: float = max_lt * 0.25
		if cur_lt < fade_dur:
			var alpha: float = clampf(cur_lt / maxf(fade_dur, 0.01), 0.0, 1.0)
			dec.modulate = Color(1.0, 1.0, 1.0, alpha)

		if cur_lt <= 0.0:
			dec.queue_free()
			active_decals.remove_at(i)
			decal_lifetimes.remove_at(i)
			decal_max_lifetimes.remove_at(i)

		i -= 1

func _register_decal(dec: Decal, lifetime: float) -> void:
	if active_decals.size() >= MAX_ACTIVE_DECALS:
		var oldest: Decal = active_decals[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		active_decals.remove_at(0)
		decal_lifetimes.remove_at(0)
		decal_max_lifetimes.remove_at(0)

	active_decals.append(dec)
	decal_lifetimes.append(lifetime)
	decal_max_lifetimes.append(lifetime)

# =========================================================================
# 1. СЛЕДЫ КОЛЕС ПО ВОЗКИ КАРАВАНА
# =========================================================================
func add_caravan_wheel_tracks(caravan_pos: Vector3, forward_dir: Vector3) -> void:
	var fwd := forward_dir.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	# Колесная колея каравана: левые колеса (-1.18м) и правые колеса (+1.18м)
	var left_pos  := caravan_pos - right * 1.18
	var right_pos := caravan_pos + right * 1.18

	add_wheel_track(left_pos, fwd)
	add_wheel_track(right_pos, fwd)

func add_wheel_track(pos: Vector3, forward_dir: Vector3) -> void:
	var dec := Decal.new()
	dec.name = "WheelTrackDecal"
	# Длина 1.1м, ширина 0.40м, глубина проекции 1.2м
	dec.size = Vector3(0.40, 1.2, 1.1)
	dec.texture_albedo = tex_wheel_track
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 45.0
	dec.distance_fade_length = 20.0

	marks_root.add_child(dec)
	dec.global_position = Vector3(pos.x, 0.05, pos.z)
	_align_decal_forward(dec, forward_dir)

	_register_decal(dec, 36.0)

# =========================================================================
# 2. СЛЕДЫ ШАГОВ (КОПЫТА ОСЛА И БОТИНКИ ИГРОКА)
# =========================================================================
func add_hoofprint(pos: Vector3, forward_dir: Vector3) -> void:
	var dec := Decal.new()
	dec.name = "HoofDecal"
	dec.size = Vector3(0.24, 0.9, 0.24)
	dec.texture_albedo = tex_footprint_hoof
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 35.0
	dec.distance_fade_length = 15.0

	marks_root.add_child(dec)
	dec.global_position = Vector3(pos.x, 0.05, pos.z)
	_align_decal_forward(dec, forward_dir)

	_register_decal(dec, 24.0)

func add_bootprint(pos: Vector3, forward_dir: Vector3, is_left: bool) -> void:
	var dec := Decal.new()
	dec.name = "BootDecal"
	dec.size = Vector3(0.22, 0.8, 0.36)
	dec.texture_albedo = tex_footprint_boot
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 35.0
	dec.distance_fade_length = 15.0

	marks_root.add_child(dec)
	dec.global_position = Vector3(pos.x, 0.05, pos.z)
	_align_decal_forward(dec, forward_dir)

	# Левая стопа зеркалится по горизонтали
	if is_left:
		dec.rotate_y(PI)
		dec.scale.x = -1.0

	_register_decal(dec, 20.0)

func play_sand_step(pos: Vector3) -> void:
	if step_players.is_empty():
		return
	var player: AudioStreamPlayer3D = step_players[step_player_idx]
	step_player_idx = (step_player_idx + 1) % step_players.size()
	if is_instance_valid(player):
		player.global_position = pos
		player.pitch_scale = randf_range(0.88, 1.15)
		player.play()

# =========================================================================
# 3. СЛЕДЫ КРОВИ НА ПЕСКЕ
# =========================================================================
func add_blood_splatter(pos: Vector3, hit_direction: Vector3 = Vector3.ZERO, scale_mult: float = 1.0) -> void:
	var dec := Decal.new()
	dec.name = "BloodSplatterDecal"
	var sz: float = randf_range(0.9, 1.5) * scale_mult
	dec.size = Vector3(sz, 1.2, sz)
	dec.texture_albedo = tex_blood_splatter
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 50.0
	dec.distance_fade_length = 20.0

	marks_root.add_child(dec)
	dec.global_position = Vector3(pos.x, 0.05, pos.z)
	# Случайный угол для органичности брызг
	dec.rotation.y = randf_range(0.0, TAU)

	_register_decal(dec, 45.0)

func add_blood_pool(pos: Vector3, max_scale: float = 1.8) -> void:
	var dec := Decal.new()
	dec.name = "BloodPoolDecal"
	dec.size = Vector3(0.2, 1.2, 0.2)
	dec.texture_albedo = tex_blood_pool
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = 50.0
	dec.distance_fade_length = 20.0

	marks_root.add_child(dec)
	dec.global_position = Vector3(pos.x, 0.05, pos.z)
	dec.rotation.y = randf_range(0.0, TAU)

	# Анимация растекания лужи крови по песку
	var tw := create_tween()
	var final_size := Vector3(max_scale, 1.2, max_scale)
	tw.tween_property(dec, "size", final_size, randf_range(2.0, 3.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_register_decal(dec, 60.0)

func add_explosion_crater(pos: Vector3) -> void:
	# Огромный след взрыва: центральная лужа крови + брызги вокруг
	add_blood_pool(pos, 3.8)
	for i in range(8):
		var ang := float(i) * (TAU / 8.0) + randf_range(-0.2, 0.2)
		var dist := randf_range(1.5, 3.5)
		var sp_pos := pos + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		add_blood_splatter(sp_pos, Vector3.ZERO, randf_range(1.2, 2.0))

# =========================================================================
# 4. ОБЛАЧКО ПЫЛИ / ПЕСКА
# =========================================================================
func spawn_dust_puff(pos: Vector3, scale_mult: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.name = "SandDustPuff"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 8
	p.lifetime = 0.55
	p.direction = Vector3(randf_range(-0.4, 0.4), 0.8, randf_range(-0.4, 0.4)).normalized()
	p.spread = 40.0
	p.initial_velocity_min = 1.0 * scale_mult
	p.initial_velocity_max = 2.4 * scale_mult
	p.gravity = Vector3(-1.8, 0.2, -0.9) # Сносится ветром пустыни
	p.scale_amount_min = 0.8 * scale_mult
	p.scale_amount_max = 1.6 * scale_mult

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.90, 0.76, 0.52, 0.55),
		Color(0.85, 0.70, 0.46, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = grad

	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_texture = tex_sand_puff
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.billboard_keep_scale = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = p_mat
	p.mesh = quad

	marks_root.add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true

	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

# Вспомогательный метод выравнивания декали по направлению движения
func _align_decal_forward(dec: Decal, forward_dir: Vector3) -> void:
	var f := forward_dir
	f.y = 0.0
	if f.length_squared() > 0.001:
		dec.rotation.y = atan2(f.x, f.z)
