extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Поддерживает 4 различные высокодетализированные 3D-модели:
# - Walker   -> Zombie1 (реалистичный гниющий зомби с детализированными текстурами вен, кожи и плоти)
# - Brute    -> Ulyaoth Zombie (чудовищный массивный мутант-демон высотой 2.8м)
# - Screamer -> Xellotath Zombie (зеленый потусторонний крикун с искаженным черепом)
# - Runner, Crawler, Spitter, Exploder -> Melty Cyborg Zombie с кибер-модификациями
#
# Особенности:
# - Полная фиксация трупа после смерти (не дергается и не встает)
# - Выверенные анимации ходьбы, атаки, урона и смерти под каждый скелет
# - Анатомически верное расположение кибернетических имплантов и оптики
# =========================================================================

# --- МОДЕЛИ ЗОМБИ (GLB/GLTF) ---
const MODEL_MELTY: String    = "res://models/zombies/melty_zombie/scene.gltf"
const MODEL_WALKER: String   = "res://models/zombies/zombie1/zombie1.glb"
const MODEL_BRUTE: String    = "res://models/zombies/ulyaoth/ulyaoth_zombie.glb"
const MODEL_SCREAMER: String = "res://models/zombies/xellotath/xellotath_zombie.glb"

# --- ПРЕЛОАД 3D АКСЕССУАРОВ (GLB) ---
const ACC_ARMOR_METAL   = preload("res://models/zombies/accessories/Armor_Metal.glb")
const ACC_ARMOR_BLACK   = preload("res://models/zombies/accessories/Armor_Black.glb")
const ACC_ARMOR_LEATHER = preload("res://models/zombies/accessories/Armor_Leather.glb")
const ACC_PLATE_LARGE   = preload("res://models/zombies/accessories/Details_Plate_Large.glb")
const ACC_PLATE_SMALL   = preload("res://models/zombies/accessories/Details_Plate_Small.glb")
const ACC_PIPES_SMALL   = preload("res://models/zombies/accessories/Details_Pipes_Small.glb")
const ACC_VENT          = preload("res://models/zombies/accessories/Details_Vent_1.glb")
const ACC_CABLE_LONG    = preload("res://models/zombies/accessories/Cable_Long.glb")
const ACC_ANTENNA       = preload("res://models/zombies/accessories/Antenna_1.glb")
const ACC_PROPANE_TANK  = preload("res://models/zombies/accessories/PropaneTank.glb")
const ACC_BATTERY       = preload("res://models/zombies/accessories/Battery_Big.glb")
const ACC_BACKPACK      = preload("res://models/zombies/accessories/Backpack.glb")
const ACC_BANDAGES      = preload("res://models/zombies/accessories/Bandages.glb")
const ACC_DAGGER        = preload("res://models/zombies/accessories/Dagger.glb")
const ACC_SKULL         = preload("res://models/zombies/accessories/Skull.glb")

var current_type: String = "Walker"

# Ссылки на ноды
var _model_instance: Node3D = null
var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var eye_lights: Array[OmniLight3D] = []

# Состояние
var is_moving: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var has_died: bool = false
var death_timer: float = 0.0

# Текстуры и материалы
var _tex_rags: Texture2D
var _tex_armor: Texture2D
var _tex_lens: Texture2D

var _mat_desert_rags: StandardMaterial3D
var _mat_cyber_armor: StandardMaterial3D
var _mat_dark_metal: StandardMaterial3D
var _mat_rust_metal: StandardMaterial3D
var _mat_steel_blade: StandardMaterial3D

func _ready() -> void:
	pass

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()
	_init_materials()

	var scene_path := MODEL_MELTY
	match current_type:
		"Walker":
			scene_path = MODEL_WALKER
		"Brute":
			scene_path = MODEL_BRUTE
		"Screamer":
			scene_path = MODEL_SCREAMER
		_:
			scene_path = MODEL_MELTY

	var scene_res = load(scene_path)
	if not scene_res:
		push_error("Failed to load zombie model: " + scene_path)
		return

	_model_instance = scene_res.instantiate() as Node3D
	if not _model_instance:
		push_error("Failed to instantiate zombie model: " + scene_path)
		return

	_model_instance.name = "RealZombieInstance"
	add_child(_model_instance)

	# zombie1.glb смотрит в -Z, разворачиваем на 180 градусов, чтобы все модели единообразно смотрели в +Z
	if current_type == "Walker":
		_model_instance.rotation_degrees.y = 180.0

	# Поиск AnimationPlayer
	anim_player = _model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		for c in _model_instance.find_children("*", "AnimationPlayer", true, false):
			anim_player = c as AnimationPlayer
			break

	if anim_player:
		_configure_animation_loops()
		if not anim_player.animation_finished.is_connected(_on_anim_finished):
			anim_player.animation_finished.connect(_on_anim_finished)

	# Поиск Skeleton3D
	skeleton = _model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		for c in _model_instance.find_children("*", "Skeleton3D", true, false):
			skeleton = c as Skeleton3D
			break

	# Настройка масштаба под тип
	_apply_type_customization()

	# Добавление обносок одежды и 3D-аксессуаров
	if skeleton:
		_build_clothing_rags()
		_build_type_cyber_upgrades()

	# Запуск начальной анимации покоя
	if anim_player:
		var start_anim := "idle01"
		match current_type:
			"Walker":
				start_anim = "idle"
			"Brute", "Screamer":
				start_anim = "clip_0015"
			_:
				start_anim = "idle01"
		if anim_player.has_animation(start_anim):
			anim_player.play(start_anim)

func _clear_model() -> void:
	for c in get_children():
		c.queue_free()
	_model_instance = null
	anim_player = null
	skeleton = null
	eye_lights.clear()
	is_dead = false
	has_died = false
	death_timer = 0.0
	is_hurt = false
	is_attacking = false
	is_moving = false

func _init_materials() -> void:
	if ResourceLoader.exists("res://assets/textures/zombies/desert_rags.jpg"):
		_tex_rags = load("res://assets/textures/zombies/desert_rags.jpg")
	if ResourceLoader.exists("res://assets/textures/zombies/cyber_armor.jpg"):
		_tex_armor = load("res://assets/textures/zombies/cyber_armor.jpg")
	if ResourceLoader.exists("res://assets/textures/zombies/optic_lens.jpg"):
		_tex_lens = load("res://assets/textures/zombies/optic_lens.jpg")

	# 1. Материал пустынных лохмотьев / рваной мешковины
	_mat_desert_rags = StandardMaterial3D.new()
	if _tex_rags:
		_mat_desert_rags.albedo_texture = _tex_rags
	else:
		_mat_desert_rags.albedo_color = Color(0.48, 0.40, 0.30)
	_mat_desert_rags.roughness = 0.95
	_mat_desert_rags.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_desert_rags.uv1_scale = Vector3(1.5, 1.5, 1.5)

	# 2. Материал кибер-брони
	_mat_cyber_armor = StandardMaterial3D.new()
	if _tex_armor:
		_mat_cyber_armor.albedo_texture = _tex_armor
	else:
		_mat_cyber_armor.albedo_color = Color(0.28, 0.25, 0.24)
	_mat_cyber_armor.metallic = 0.88
	_mat_cyber_armor.roughness = 0.38

	# 3. Темный титан
	_mat_dark_metal = StandardMaterial3D.new()
	_mat_dark_metal.albedo_color = Color(0.12, 0.12, 0.14)
	_mat_dark_metal.metallic = 0.96
	_mat_dark_metal.roughness = 0.22

	# 4. Ржавая сталь
	_mat_rust_metal = StandardMaterial3D.new()
	_mat_rust_metal.albedo_color = Color(0.35, 0.22, 0.16)
	_mat_rust_metal.metallic = 0.82
	_mat_rust_metal.roughness = 0.6

	# 5. Полированная сталь клинков
	_mat_steel_blade = StandardMaterial3D.new()
	_mat_steel_blade.albedo_color = Color(0.85, 0.88, 0.92)
	_mat_steel_blade.metallic = 0.98
	_mat_steel_blade.roughness = 0.12

func _configure_animation_loops() -> void:
	if not anim_player:
		return
	var looping_anims = [
		"walk01", "walk02", "run", "idle01", "idle02", "on_all_four_A", "on_all_four_B",
		"idle", "walk",
		"clip_0015", "clip_0004", "clip_0128", "Rest_Neutral"
	]
	for a_name in looping_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR

	var single_anims = [
		"attack01", "attack02", "damage", "death",
		"attack",
		"clip_0070", "clip_0037", "clip_0083"
	]
	for a_name in single_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_NONE

func _apply_type_customization() -> void:
	const BASE_SCALE: float = 0.68
	match current_type:
		"Walker":
			# zombie1.glb имеет высоту 1.93м; масштаб 0.95 дает идеальные 1.83м
			scale = Vector3.ONE * 0.95
		"Brute":
			# ulyaoth_zombie.glb имеет высоту 2.88м; enemy.tscn умножает на 1.35 => 2.88 * 0.70 * 1.35 = 2.72м
			scale = Vector3.ONE * 0.70
		"Screamer":
			# xellotath_zombie.glb имеет высоту 2.87м; масштаб 0.70 дает 2.01м
			scale = Vector3.ONE * 0.70
		"Runner":
			scale = Vector3.ONE * (BASE_SCALE * 0.90)
		"Crawler":
			scale = Vector3(BASE_SCALE * 1.05, BASE_SCALE * 0.85, BASE_SCALE * 1.05)
		"Spitter":
			scale = Vector3.ONE * (BASE_SCALE * 0.95)
		"Exploder":
			scale = Vector3.ONE * (BASE_SCALE * 1.0)
		_:
			scale = Vector3.ONE * BASE_SCALE

func _get_or_create_bone_att(bone_name: String) -> BoneAttachment3D:
	if not skeleton:
		return null
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		match bone_name:
			"head_014":
				bone_idx = skeleton.find_bone("head")
				if bone_idx == -1: bone_idx = skeleton.find_bone("bone_012_69e347a7")
			"neck_013":
				bone_idx = skeleton.find_bone("neck")
				if bone_idx == -1: bone_idx = skeleton.find_bone("chest")
				if bone_idx == -1: bone_idx = skeleton.find_bone("bone_011_f2192054")
			"hip_016":
				bone_idx = skeleton.find_bone("hips")
				if bone_idx == -1: bone_idx = skeleton.find_bone("bone_001_b4877dd4")
			"shoulder_L_015":
				bone_idx = skeleton.find_bone("L_shoulder")
				if bone_idx == -1: bone_idx = skeleton.find_bone("bone_013_6f0d8149")
			"forearm_R_09":
				bone_idx = skeleton.find_bone("R_elbow")
				if bone_idx == -1: bone_idx = skeleton.find_bone("R_arm")
				if bone_idx == -1: bone_idx = skeleton.find_bone("bone_016_db0adc42")
		if bone_idx == -1:
			return null
		bone_name = skeleton.get_bone_name(bone_idx)

	for c in skeleton.get_children():
		if c is BoneAttachment3D and c.bone_name == bone_name:
			return c
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	att.name = "Att_" + bone_name
	skeleton.add_child(att)
	return att

# =========================================================================
# ОБНОСКИ ПУСТЫННОЙ ОДЕЖДЫ
# =========================================================================
func _build_clothing_rags() -> void:
	# zombie1, ulyaoth и xellotath уже имеют детализированные рваные одежды/тела
	if current_type == "Walker" or current_type == "Brute" or current_type == "Screamer":
		return

	# 1. Шейный платок / коул на шее и плечах (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	if neck_att:
		var poncho := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.24
		p_mesh.bottom_radius = 0.44
		p_mesh.height = 0.32
		poncho.mesh = p_mesh
		poncho.material_override = _mat_desert_rags
		poncho.position = Vector3(-0.25, 0.0, 0.02)
		neck_att.add_child(poncho)

	# 2. Рваный пустынный пояс и набедренная повязка (кость hip_016)
	var hip_att := _get_or_create_bone_att("hip_016")
	if hip_att:
		var sash := MeshInstance3D.new()
		var s_mesh := CylinderMesh.new()
		s_mesh.top_radius = 0.32
		s_mesh.bottom_radius = 0.34
		s_mesh.height = 0.16
		sash.mesh = s_mesh
		sash.material_override = _mat_desert_rags
		sash.position = Vector3(-0.10, 0.0, 0.0)
		hip_att.add_child(sash)

		var flap_front := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.48, 0.38, 0.02)
		flap_front.mesh = f_box
		flap_front.material_override = _mat_desert_rags
		flap_front.position = Vector3(-0.35, 0.0, 0.16)
		flap_front.rotation_degrees = Vector3(10, 0, 0)
		hip_att.add_child(flap_front)

		var flap_back := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.52, 0.42, 0.02)
		flap_back.mesh = b_box
		flap_back.material_override = _mat_desert_rags
		flap_back.position = Vector3(-0.36, 0.0, -0.16)
		flap_back.rotation_degrees = Vector3(-10, 0, 0)
		hip_att.add_child(flap_back)

	# 3. Обмотки из бинтов / лоскутов на голенях
	for bname in ["shin_L_035", "shin_R_039"]:
		var shin_att := _get_or_create_bone_att(bname)
		if shin_att:
			var wrap := MeshInstance3D.new()
			var w_cyl := CylinderMesh.new()
			w_cyl.top_radius = 0.11
			w_cyl.bottom_radius = 0.10
			w_cyl.height = 0.38
			wrap.mesh = w_cyl
			wrap.material_override = _mat_desert_rags
			wrap.position = Vector3(0.18, 0.0, 0.0)
			shin_att.add_child(wrap)

# =========================================================================
# УНИКАЛЬНЫЕ 3D КИБЕРНЕТИЧЕСКИЕ АПГРЕЙДЫ ПО ТИПАМ
# =========================================================================
func _build_type_cyber_upgrades() -> void:
	match current_type:
		"Walker":
			_build_walker_upgrades()
		"Runner":
			_build_runner_upgrades()
		"Brute":
			_build_brute_upgrades()
		"Crawler":
			_build_crawler_upgrades()
		"Spitter":
			_build_spitter_upgrades()
		"Screamer":
			_build_screamer_upgrades()
		"Exploder":
			_build_exploder_upgrades()
		_:
			_build_walker_upgrades()

# --- 1. WALKER: ШТУРМОВОЙ КИБОРГ (Zombie1) ---
func _build_walker_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head")
	var chest_att := _get_or_create_bone_att("chest")
	var sh_att := _get_or_create_bone_att("L_shoulder")

	# Алый прицельный окуляр на черепе
	if head_att:
		_create_ocular_eye(head_att, Vector3(0.06, 0.10, 0.12), Color(1.0, 0.08, 0.08), 0.04)

	# Стальной наплечник на левом плече
	if sh_att:
		var pauldron = ACC_PLATE_SMALL.instantiate()
		sh_att.add_child(pauldron)
		pauldron.position = Vector3(0.08, 0.0, 0.0)
		pauldron.rotation_degrees = Vector3(0, 90, -30)
		pauldron.scale = Vector3.ONE * 0.9

	# Кабели питания на груди
	if chest_att:
		var cable = ACC_CABLE_LONG.instantiate()
		chest_att.add_child(cable)
		cable.position = Vector3(0.0, 0.05, 0.08)
		cable.rotation_degrees = Vector3(0, 0, 90)
		cable.scale = Vector3.ONE * 0.7

# --- 2. RUNNER: КИБЕР-БЕГУН (Melty) ---
func _build_runner_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")

	if neck_att:
		var armor = ACC_ARMOR_LEATHER.instantiate()
		neck_att.add_child(armor)
		armor.rotation_degrees = Vector3(0, 0, -90)
		armor.position = Vector3(-0.35, 0.0, 0.06)

		for side in [-0.14, 0.14]:
			var vent = ACC_VENT.instantiate()
			neck_att.add_child(vent)
			vent.position = Vector3(-0.30, side, -0.10)
			vent.rotation_degrees = Vector3(0, 0, -90)

	if head_att:
		_create_cranial_plate(head_att, Color(0.95, 0.85, 0.1))

# --- 3. BRUTE: ДЕМОНИЧЕСКИЙ ГРОМИЛА (Ulyaoth) ---
func _build_brute_upgrades() -> void:
	var head_att := _get_or_create_bone_att("bone_012_69e347a7")
	var neck_att := _get_or_create_bone_att("bone_011_f2192054")
	var back_att := _get_or_create_bone_att("bone_003_1a679f56")

	# Огненный глаз ярости
	if head_att:
		_create_ocular_eye(head_att, Vector3(0.0, 0.15, 0.18), Color(1.0, 0.45, 0.05), 0.06)

	# Тяжелая черная титановая бронеплита
	if neck_att:
		var armor = ACC_ARMOR_BLACK.instantiate()
		neck_att.add_child(armor)
		armor.position = Vector3(0.0, -0.1, 0.25)
		armor.rotation_degrees = Vector3(0, 0, 0)
		armor.scale = Vector3.ONE * 1.6

	# Охладительные трубы на спине
	if back_att:
		var vent = ACC_VENT.instantiate()
		back_att.add_child(vent)
		vent.position = Vector3(0.0, 0.1, -0.25)
		vent.rotation_degrees = Vector3(0, 180, 0)
		vent.scale = Vector3.ONE * 1.4

# --- 4. CRAWLER: ПАУК-ПОЛЗУН (Melty) ---
func _build_crawler_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var hip_att := _get_or_create_bone_att("hip_016")

	if head_att:
		_create_ocular_eye(head_att, Vector3(-0.06, 0.05, 0.22), Color(0.85, 0.15, 0.95), 0.035)
		_create_ocular_eye(head_att, Vector3(0.06, 0.05, 0.22), Color(0.85, 0.15, 0.95), 0.035)

	if hip_att:
		var batt = ACC_BATTERY.instantiate()
		hip_att.add_child(batt)
		batt.rotation_degrees = Vector3(0, 0, 90)
		batt.position = Vector3(-0.25, 0.0, -0.15)
		batt.scale = Vector3.ONE * 0.45

# --- 5. SPITTER: ХИМИЧЕСКИЙ ПЛЕВУН (Melty) ---
func _build_spitter_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")

	if neck_att:
		var tank = ACC_PROPANE_TANK.instantiate()
		neck_att.add_child(tank)
		tank.rotation_degrees = Vector3(0, 0, -90)
		tank.position = Vector3(-0.35, 0.0, -0.18)
		tank.scale = Vector3.ONE * 0.45

	if head_att:
		_create_cranial_plate(head_att, Color(0.2, 0.95, 0.25))

# --- 6. SCREAMER: ПОТУСТОРОННЯЯ СИРЕНА (Xellotath) ---
func _build_screamer_upgrades() -> void:
	var head_att := _get_or_create_bone_att("bone_012_69e347a7")
	var neck_att := _get_or_create_bone_att("bone_011_f2192054")

	# Психоакустическая антенна на голове
	if head_att:
		var ant = ACC_ANTENNA.instantiate()
		head_att.add_child(ant)
		ant.position = Vector3(0.0, 0.35, 0.0)
		ant.rotation_degrees = Vector3(0, 0, 0)
		ant.scale = Vector3.ONE * 1.2
		# Бирюзовый неоновый сенсор
		_create_ocular_eye(head_att, Vector3(0.0, 0.12, 0.16), Color(0.1, 0.95, 0.9), 0.05)

	# Блок акустического резонанса на шее
	if neck_att:
		var plate = ACC_PLATE_LARGE.instantiate()
		neck_att.add_child(plate)
		plate.position = Vector3(0.0, 0.0, 0.15)
		plate.rotation_degrees = Vector3(0, 0, 0)
		plate.scale = Vector3.ONE * 1.0

# --- 7. EXPLODER: КАМИКАДЗЕ (Melty) ---
func _build_exploder_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")

	if head_att:
		_create_cranial_plate(head_att, Color(1.0, 0.45, 0.05))

	if neck_att:
		var pack = ACC_BACKPACK.instantiate()
		neck_att.add_child(pack)
		pack.rotation_degrees = Vector3(0, 180, -90)
		pack.position = Vector3(-0.35, 0.0, -0.16)
		pack.scale = Vector3.ONE * 0.45

# --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
func _create_cranial_plate(parent: Node3D, color: Color) -> void:
	if not parent:
		return
	var plate := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.18, 0.28, 0.06)
	plate.mesh = p_box
	plate.material_override = _mat_cyber_armor
	plate.position = Vector3(0.14, -0.25, 0.24)
	plate.rotation_degrees = Vector3(15, 0, 0)
	parent.add_child(plate)

	var socket_mesh := MeshInstance3D.new()
	var socket_cyl := CylinderMesh.new()
	socket_cyl.top_radius = 0.045
	socket_cyl.bottom_radius = 0.045
	socket_cyl.height = 0.03
	socket_mesh.mesh = socket_cyl
	socket_mesh.material_override = _mat_dark_metal
	socket_mesh.position = Vector3(0.0, -0.03, 0.04)
	socket_mesh.rotation_degrees = Vector3(0, 0, 90)
	plate.add_child(socket_mesh)

	var lens_mesh := MeshInstance3D.new()
	var lens_sphere := SphereMesh.new()
	lens_sphere.radius = 0.035
	lens_sphere.height = 0.045
	lens_mesh.mesh = lens_sphere
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = color
	lens_mat.emission_enabled = true
	lens_mat.emission = color
	lens_mat.emission_energy_multiplier = 4.5
	lens_mesh.material_override = lens_mat
	lens_mesh.position = Vector3(0.0, 0.015, 0.0)
	socket_mesh.add_child(lens_mesh)

	_add_light(lens_mesh, color, 1.2, 2.0)

func _create_ocular_eye(parent: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	if not parent:
		return
	var socket_mesh := MeshInstance3D.new()
	var socket_cyl := CylinderMesh.new()
	socket_cyl.top_radius = radius * 1.2
	socket_cyl.bottom_radius = radius * 1.2
	socket_cyl.height = radius * 0.7
	socket_mesh.mesh = socket_cyl
	socket_mesh.material_override = _mat_dark_metal
	socket_mesh.position = pos
	socket_mesh.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(socket_mesh)

	var lens_mesh := MeshInstance3D.new()
	var lens_sphere := SphereMesh.new()
	lens_sphere.radius = radius
	lens_sphere.height = radius * 1.3
	lens_mesh.mesh = lens_sphere
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = color
	lens_mat.emission_enabled = true
	lens_mat.emission = color
	lens_mat.emission_energy_multiplier = 4.2
	lens_mesh.material_override = lens_mat
	lens_mesh.position = Vector3(0.0, radius * 0.35, 0.0)
	socket_mesh.add_child(lens_mesh)

	_add_light(lens_mesh, color, 1.0, 1.8)

func _add_light(parent: Node3D, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	eye_lights.append(light)

# =========================================================================
# УПРАВЛЕНИЕ АНИМАЦИЯМИ (ВЫЗЫВАЕТСЯ ИЗ ENEMY.GD)
# =========================================================================
func update_animation(_delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	if not anim_player:
		return

	is_moving = moving
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	var anim_death = "death"
	var anim_damage = "damage"
	var anim_attack = "attack01"
	var anim_walk = "walk01"
	var anim_idle = "idle01"

	match current_type:
		"Walker":
			anim_death = "death"
			anim_damage = "attack"
			anim_attack = "attack"
			anim_walk = "walk"
			anim_idle = "idle"
		"Brute":
			anim_death = "clip_0083"
			anim_damage = "clip_0037"
			anim_attack = "clip_0070"
			anim_walk = "clip_0004"
			anim_idle = "clip_0015"
		"Screamer":
			anim_death = "clip_0083"
			anim_damage = "clip_0037"
			anim_attack = "clip_0070"
			anim_walk = "clip_0004"
			anim_idle = "clip_0015"
		"Runner":
			anim_death = "death"
			anim_damage = "damage"
			anim_attack = "attack02"
			anim_walk = "run"
			anim_idle = "idle01"
		"Crawler":
			anim_death = "death"
			anim_damage = "damage"
			anim_attack = "attack01"
			anim_walk = "on_all_four_B"
			anim_idle = "idle01"
		_:
			anim_death = "death"
			anim_damage = "damage"
			anim_attack = "attack01"
			anim_walk = "walk01"
			anim_idle = "idle01"

	# 1. Смерть: фиксирует труп намертво без дерганий
	if is_dead:
		if not has_died:
			has_died = true
			death_timer = 0.0
			for light in eye_lights:
				if is_instance_valid(light):
					light.light_energy = 0.0
			if anim_player.has_animation(anim_death):
				anim_player.play(anim_death, 0.1)
			return

		death_timer += _delta
		var d_len: float = anim_player.get_animation(anim_death).length if anim_player.has_animation(anim_death) else 2.5
		if death_timer >= (d_len - 0.05) or not anim_player.is_playing() or anim_player.current_animation != anim_death:
			anim_player.pause()
			if anim_player.has_animation(anim_death):
				anim_player.seek(d_len, true)
		return

	if has_died:
		# Труп уже умер — никаких других анимаций больше никогда не проигрывать
		return

	# 2. Получение урона
	if is_hurt:
		if anim_player.has_animation(anim_damage) and anim_player.current_animation != anim_damage:
			anim_player.play(anim_damage, 0.08, 1.4)
		return

	# 3. Атака
	if is_attacking:
		var atk_speed = 1.4 if current_type == "Runner" else 1.1
		if anim_player.has_animation(anim_attack) and anim_player.current_animation != anim_attack:
			anim_player.play(anim_attack, 0.1, atk_speed)
		return

	# 4. Движение
	if is_moving:
		var spd_mult = 1.0
		match current_type:
			"Crawler":
				spd_mult = maxf(1.0, move_speed * 0.45)
			"Runner":
				spd_mult = maxf(1.1, move_speed * 0.32)
			"Brute":
				spd_mult = 0.85
			"Walker":
				spd_mult = maxf(0.9, move_speed * 0.40)
			_:
				spd_mult = maxf(0.85, move_speed * 0.38)
		if anim_player.has_animation(anim_walk) and anim_player.current_animation != anim_walk:
			anim_player.play(anim_walk, 0.2, spd_mult)
		return

	# 5. Покой (Idle)
	if anim_player.has_animation(anim_idle) and anim_player.current_animation != anim_idle:
		anim_player.play(anim_idle, 0.25)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "death" or anim_name == "clip_0083":
		if anim_player:
			anim_player.pause()
			if anim_player.has_animation(anim_name):
				anim_player.seek(anim_player.get_animation(anim_name).length, true)
