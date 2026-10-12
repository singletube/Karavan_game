extends Node3D
# Настройка окружения пустыни: небо, туман, bloom, SSAO, солнце, песок

func _ready() -> void:
	TextureGen.preload_all_textures()
	_setup_environment()
	_setup_sun()
	_setup_sand()

# =====================================================================
func _setup_environment() -> void:
	var env := Environment.new()

	# --- Процедурное небо ---
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.10, 0.22, 0.55)   # тёмно-синий зенит
	sky_mat.sky_horizon_color    = Color(0.82, 0.52, 0.22)   # оранжевый горизонт
	sky_mat.sky_curve            = 0.09
	sky_mat.ground_bottom_color  = Color(0.52, 0.38, 0.18)   # цвет земли снизу
	sky_mat.ground_horizon_color = Color(0.78, 0.56, 0.28)   # граница земли
	sky_mat.ground_curve         = 0.02
	sky_mat.sun_angle_max        = 35.0
	sky_mat.sun_curve            = 0.08
	sky_mat.energy_multiplier    = 1.5

	var sky := Sky.new()
	sky.sky_material          = sky_mat
	sky.radiance_size         = Sky.RADIANCE_SIZE_256

	env.sky                          = sky
	env.background_mode              = Environment.BG_SKY
	env.background_energy_multiplier = 1.2

	# --- Ambient (от неба) ---
	env.ambient_light_source          = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color           = Color(0.72, 0.58, 0.35)
	env.ambient_light_energy          = 0.4

	# --- Отражения ---
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# --- Туман (тепловая дымка пустыни) ---
	env.fog_enabled       = true
	env.fog_light_color   = Color(0.88, 0.70, 0.42)
	env.fog_light_energy  = 0.6
	env.fog_sun_scatter   = 0.6
	env.fog_density       = 0.004
	env.fog_aerial_perspective = 0.25

	# --- Bloom / Glow ---
	env.glow_enabled       = true
	env.glow_normalized    = false
	env.glow_intensity     = 0.7
	env.glow_strength      = 1.2
	env.glow_bloom         = 0.15
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale     = 2.0

	# --- SSAO (мягкие тени в углублениях) ---
	env.ssao_enabled   = true
	env.ssao_radius    = 1.2
	env.ssao_intensity = 2.5
	env.ssao_power     = 1.5

	# --- Тональная компрессия (реалистичный контраст) ---
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white    = 6.0

	# --- Цветокоррекция ---
	env.adjustment_enabled    = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast   = 1.08
	env.adjustment_saturation = 1.15

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# =====================================================================
func _setup_sun() -> void:
	var sun := $SunLight as DirectionalLight3D
	if not sun:
		return

	sun.light_color              = Color(1.00, 0.88, 0.65)
	sun.light_energy             = 3.2
	sun.light_angular_distance   = 0.6      # визуальный диск солнца
	sun.shadow_enabled           = true
	sun.shadow_blur              = 0.8
	sun.directional_shadow_mode  = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_split_1      = 0.1
	sun.directional_shadow_split_2      = 0.25
	sun.directional_shadow_split_3      = 0.55

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

	# Передаём параметры шейдеру
	mat.set_shader_parameter("sand_light",       Color(0.96, 0.84, 0.58))
	mat.set_shader_parameter("sand_mid",         Color(0.82, 0.66, 0.38))
	mat.set_shader_parameter("sand_dark",        Color(0.62, 0.46, 0.22))
	mat.set_shader_parameter("texture_scale",    0.20)
	mat.set_shader_parameter("ripple_strength",  0.65)
	mat.set_shader_parameter("roughness_base",   0.85)
	mat.set_shader_parameter("specular_amt",     0.22)

	mesh_inst.material_override = mat
