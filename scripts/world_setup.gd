extends Node3D

# Настройка окружения пустыни: динамическая смена времени суток (День / Закат / Ночь / Рассвет),
# процедурное небо, солнце, луна, туман, bloom, SSAO и шейдер барханов песка.

signal phase_changed(new_phase: String)
signal time_changed(time_norm: float, time_str: String, phase: String)

# --- Настройки суточного цикла ---
@export var cycle_duration: float = 240.0   # Полный оборот суток в секундах (4 минуты)
@export var time_of_day: float = 0.28       # Старт в 06:45 (мягкий утренний свет)
@export var time_scale: float = 1.0         # Множитель скорости времени
@export var pause_time: bool = false        # Пауза течения времени

# Ссылки на окружение и светила
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D

var current_phase: String = "ДЕНЬ"
var _last_phase: String = ""

func _enter_tree() -> void:
	add_to_group("world_setup")

func _ready() -> void:
	TextureGen.preload_all_textures()
	_setup_environment()
	_setup_sun_and_moon()
	_setup_sand()
	_update_lighting_and_sky()

func _process(delta: float) -> void:
	if not pause_time:
		time_of_day = fmod(time_of_day + (delta / cycle_duration) * time_scale, 1.0)
		if time_of_day < 0.0:
			time_of_day += 1.0

	_update_lighting_and_sky()

	var new_phase := get_phase_name()
	if new_phase != _last_phase:
		_last_phase = new_phase
		current_phase = new_phase
		phase_changed.emit(new_phase)

	time_changed.emit(time_of_day, get_clock_time(), current_phase)

# =====================================================================
# ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ HUD И ДРУГИХ СИСТЕМ
# =====================================================================
func get_phase_name() -> String:
	if time_of_day >= 0.22 and time_of_day < 0.70:
		return "ДЕНЬ"
	elif time_of_day >= 0.70 and time_of_day < 0.80:
		return "ЗАКАТ"
	elif time_of_day >= 0.80 or time_of_day < 0.18:
		return "НОЧЬ"
	else:
		return "РАССВЕТ"

func get_clock_time() -> String:
	var total_minutes: int = int(time_of_day * 24.0 * 60.0)
	var hours: int = (total_minutes / 60) % 24
	var mins: int = total_minutes % 60
	return "%02d:%02d" % [hours, mins]

func is_night() -> bool:
	return time_of_day >= 0.80 or time_of_day < 0.18

# =====================================================================
# ИНИЦИАЛИЗАЦИЯ ОКРУЖЕНИЯ
# =====================================================================
func _setup_environment() -> void:
	env = Environment.new()

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.09
	sky_mat.ground_curve = 0.02
	sky_mat.sun_angle_max = 35.0
	sky_mat.sun_curve = 0.08
	sky_mat.energy_multiplier = 1.3

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 1.2

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Туман
	env.fog_enabled = true
	env.fog_sun_scatter = 0.6
	env.fog_aerial_perspective = 0.25

	# Bloom / Glow
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.7
	env.glow_strength = 1.2
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale = 2.0

	# SSAO
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.ssao_power = 1.5

	# Тональная компрессия
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0

	# Цветокоррекция
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

func _setup_sun_and_moon() -> void:
	sun = get_node_or_null("SunLight") as DirectionalLight3D
	if not sun:
		sun = DirectionalLight3D.new()
		sun.name = "SunLight"
		add_child(sun)

	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55

	moon = get_node_or_null("AmbientFill") as DirectionalLight3D
	if not moon:
		moon = DirectionalLight3D.new()
		moon.name = "MoonLight"
		add_child(moon)

	moon.light_color = Color(0.62, 0.76, 0.98, 1.0)
	moon.light_angular_distance = 0.5
	moon.shadow_enabled = true
	moon.shadow_blur = 1.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 250.0

# =====================================================================
# ДИНАМИЧЕСКИЙ РАСЧЕТ ОСВЕЩЕНИЯ И НЕБА
# =====================================================================
func _update_lighting_and_sky() -> void:
	if not env or not sky_mat or not sun or not moon:
		return

	# Угол движения светил: 0.25 = восход (0 rad), 0.50 = зенит (PI/2), 0.75 = закат (PI), 0.0 = полночь
	var theta: float = (time_of_day - 0.25) * TAU

	# Траектория солнца с наклоном для длинных кинематографичных теней в пустыне
	var sun_dir := Vector3(
		-cos(theta) * 0.90,
		sin(theta),
		-cos(theta) * 0.40
	).normalized()

	var moon_dir := -sun_dir

	var p := _get_interpolated_palette(time_of_day)

	# Настройка неба
	sky_mat.sky_top_color = p["sky_top"]
	sky_mat.sky_horizon_color = p["sky_horizon"]
	sky_mat.ground_bottom_color = p["ground_bottom"]
	sky_mat.ground_horizon_color = p["ground_horizon"]
	sky_mat.energy_multiplier = p["sky_energy"]

	# Настройка фонового освещения и тумана
	env.ambient_light_color = p["ambient_color"]
	env.ambient_light_energy = p["ambient_energy"]
	env.fog_light_color = p["fog_color"]
	env.fog_light_energy = p["fog_energy"]
	env.fog_density = p["fog_density"]

	# Положение и свет Солнца
	if sun_dir.y > -0.05:
		var sun_pos := sun_dir * 90.0
		sun.global_position = sun_pos
		sun.look_at(Vector3.ZERO, Vector3.UP)
		sun.visible = true
		sun.shadow_enabled = true
		var elev: float = clampf(sun_dir.y / 0.28, 0.0, 1.0)
		sun.light_energy = p["sun_max_energy"] * elev
		sun.light_color = p["sun_color"]
	else:
		sun.visible = false
		sun.shadow_enabled = false
		sun.light_energy = 0.0

	# Положение и свет Луны
	if moon_dir.y > -0.05:
		var moon_pos := moon_dir * 90.0
		moon.global_position = moon_pos
		moon.look_at(Vector3.ZERO, Vector3.UP)
		moon.visible = true
		moon.shadow_enabled = true
		var m_elev: float = clampf(moon_dir.y / 0.28, 0.0, 1.0)
		moon.light_energy = p["moon_max_energy"] * m_elev
		moon.light_color = Color(0.62, 0.76, 0.98, 1.0)
	else:
		moon.visible = false
		moon.shadow_enabled = false
		moon.light_energy = 0.0

# =====================================================================
# ИНТЕРПОЛЯЦИЯ ЦВЕТОВОЙ ПАЛИТРЫ (MIDNIGHT -> DAWN -> NOON -> DUSK)
# =====================================================================
func _get_interpolated_palette(t: float) -> Dictionary:
	# 4 ключевые точки: 0.0 (Полночь), 0.25 (Рассвет), 0.50 (Полдень), 0.75 (Закат)
	var p_midnight := {
		"sky_top": Color(0.015, 0.025, 0.07),
		"sky_horizon": Color(0.05, 0.07, 0.15),
		"ground_bottom": Color(0.015, 0.02, 0.04),
		"ground_horizon": Color(0.03, 0.04, 0.08),
		"sky_energy": 0.45,
		"ambient_color": Color(0.12, 0.16, 0.28),
		"ambient_energy": 0.12,
		"fog_color": Color(0.035, 0.05, 0.11),
		"fog_energy": 0.30,
		"fog_density": 0.0055,
		"sun_color": Color(1.0, 0.5, 0.2),
		"sun_max_energy": 0.0,
		"moon_max_energy": 0.42
	}

	var p_dawn := {
		"sky_top": Color(0.12, 0.20, 0.50),
		"sky_horizon": Color(0.95, 0.60, 0.38),
		"ground_bottom": Color(0.38, 0.26, 0.18),
		"ground_horizon": Color(0.68, 0.44, 0.26),
		"sky_energy": 1.15,
		"ambient_color": Color(0.65, 0.50, 0.35),
		"ambient_energy": 0.35,
		"fog_color": Color(0.80, 0.58, 0.40),
		"fog_energy": 0.50,
		"fog_density": 0.0042,
		"sun_color": Color(1.0, 0.76, 0.52),
		"sun_max_energy": 2.2,
		"moon_max_energy": 0.06
	}

	var p_noon := {
		"sky_top": Color(0.10, 0.22, 0.55),
		"sky_horizon": Color(0.82, 0.52, 0.22),
		"ground_bottom": Color(0.52, 0.38, 0.18),
		"ground_horizon": Color(0.78, 0.56, 0.28),
		"sky_energy": 1.40,
		"ambient_color": Color(0.72, 0.58, 0.35),
		"ambient_energy": 0.45,
		"fog_color": Color(0.88, 0.70, 0.42),
		"fog_energy": 0.60,
		"fog_density": 0.0035,
		"sun_color": Color(1.00, 0.94, 0.82),
		"sun_max_energy": 3.0,
		"moon_max_energy": 0.0
	}

	var p_dusk := {
		"sky_top": Color(0.14, 0.08, 0.28),
		"sky_horizon": Color(0.96, 0.36, 0.12),
		"ground_bottom": Color(0.30, 0.18, 0.12),
		"ground_horizon": Color(0.60, 0.26, 0.14),
		"sky_energy": 1.05,
		"ambient_color": Color(0.60, 0.32, 0.20),
		"ambient_energy": 0.28,
		"fog_color": Color(0.75, 0.34, 0.16),
		"fog_energy": 0.52,
		"fog_density": 0.0048,
		"sun_color": Color(1.0, 0.42, 0.14),
		"sun_max_energy": 2.2,
		"moon_max_energy": 0.08
	}

	var p_from: Dictionary
	var p_to: Dictionary
	var weight: float = 0.0

	if t < 0.25:
		p_from = p_midnight
		p_to = p_dawn
		weight = t / 0.25
	elif t < 0.50:
		p_from = p_dawn
		p_to = p_noon
		weight = (t - 0.25) / 0.25
	elif t < 0.75:
		p_from = p_noon
		p_to = p_dusk
		weight = (t - 0.50) / 0.25
	else:
		p_from = p_dusk
		p_to = p_midnight
		weight = (t - 0.75) / 0.25

	# Мягкое косинусное сглаживание переходов
	var smooth_w: float = 0.5 - 0.5 * cos(weight * PI)

	var result := {}
	for k: String in p_from.keys():
		var val_from = p_from[k]
		var val_to = p_to[k]
		if val_from is Color:
			result[k] = (val_from as Color).lerp(val_to as Color, smooth_w)
		elif val_from is float:
			result[k] = lerpf(val_from as float, val_to as float, smooth_w)
		else:
			result[k] = val_to
	return result

# =====================================================================
# ШЕЙДЕР ПЕСКА
# =====================================================================
func _setup_sand() -> void:
	var floor_node := get_node_or_null("Floor") as StaticBody3D
	if not floor_node:
		return
	var mesh_inst := floor_node.get_node_or_null("FloorMesh") as MeshInstance3D
	if not mesh_inst:
		return

	var shader := load("res://shaders/sand.gdshader") as Shader
	if not shader:
		push_warning("sand.gdshader не найден!")
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sand_light",       Color(0.96, 0.84, 0.58))
	mat.set_shader_parameter("sand_mid",         Color(0.82, 0.66, 0.38))
	mat.set_shader_parameter("sand_dark",        Color(0.62, 0.46, 0.22))
	mat.set_shader_parameter("texture_scale",    0.20)
	mat.set_shader_parameter("ripple_strength",  0.65)
	mat.set_shader_parameter("roughness_base",   0.85)
	mat.set_shader_parameter("specular_amt",     0.22)

	mesh_inst.material_override = mat
