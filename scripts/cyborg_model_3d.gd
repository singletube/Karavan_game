extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Использует оригинальную анимированную 3D-модель (Melty Zombie)
# с богатым набором готовых 3D-деталей и аксессуаров:
# - Настоящие 3D-модели (броня, кирасы, клинки, баллоны, ранцы, кабели, антенны, черепа)
# - Корректное анатомическое расположение:
#   * Нагрудники и кирасы — на верхней части груди / пекторалях (Y ≈ 1.6-1.65м), а НЕ в животе!
#   * Наплечники — на плечевых суставах (Y ≈ 1.67м)
#   * Поясные лохмотья и повязки — на бедрах / талии (Y ≈ 1.0м)
#   * Клинки и наручи — вдоль предплечий
# - Обноски одежды: многослойные рваные лохмотья пустыни (burlap rags)
# - Уникальный кибернетический силуэт для каждого типа (Walker, Runner, Brute, Crawler, Spitter, Screamer, Exploder)
# - Полная фиксация трупа после смерти (не дергается и не встает)
# =========================================================================

const ZOMBIE_MODEL_PATH: String = "res://models/zombies/melty_zombie/scene.gltf"

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

	var scene_res = load(ZOMBIE_MODEL_PATH)
	if not scene_res:
		push_error("Failed to load zombie model: " + ZOMBIE_MODEL_PATH)
		return

	_model_instance = scene_res.instantiate() as Node3D
	if not _model_instance:
		push_error("Failed to instantiate zombie model")
		return

	_model_instance.name = "RealZombieInstance"
	add_child(_model_instance)

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

	# Запуск анимации покоя
	if anim_player:
		anim_player.play("idle01")

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
	_tex_rags = load("res://assets/textures/zombies/desert_rags.jpg")
	_tex_armor = load("res://assets/textures/zombies/cyber_armor.jpg")
	_tex_lens = load("res://assets/textures/zombies/optic_lens.jpg")

	# 1. Материал пустынных лохмотьев / рваной мешковины
	_mat_desert_rags = StandardMaterial3D.new()
	if _tex_rags:
		_mat_desert_rags.albedo_texture = _tex_rags
	else:
		_mat_desert_rags.albedo_color = Color(0.48, 0.40, 0.30)
	_mat_desert_rags.roughness = 0.95
	_mat_desert_rags.cull_mode = BaseMaterial3D.CULL_DISABLED # Двусторонняя ткань
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
	var looping_anims = ["walk01", "walk02", "run", "idle01", "idle02", "on_all_four_A", "on_all_four_B"]
	for a_name in looping_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR

	var single_anims = ["attack01", "attack02", "damage", "death"]
	for a_name in single_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_NONE

func _apply_type_customization() -> void:
	const BASE_SCALE: float = 0.68
	match current_type:
		"Runner":
			scale = Vector3.ONE * (BASE_SCALE * 0.90)
		"Brute":
			scale = Vector3.ONE * (BASE_SCALE * 1.45) # Высота ~2.7м
		"Crawler":
			scale = Vector3(BASE_SCALE * 1.05, BASE_SCALE * 0.85, BASE_SCALE * 1.05)
		"Spitter":
			scale = Vector3.ONE * (BASE_SCALE * 0.95)
		"Screamer":
			scale = Vector3.ONE * (BASE_SCALE * 0.96)
		"Exploder":
			scale = Vector3.ONE * (BASE_SCALE * 1.0)
		_:
			scale = Vector3.ONE * BASE_SCALE

func _get_or_create_bone_att(bone_name: String) -> BoneAttachment3D:
	for c in skeleton.get_children():
		if c is BoneAttachment3D and c.bone_name == bone_name:
			return c
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	att.name = "Att_" + bone_name
	skeleton.add_child(att)
	return att

# =========================================================================
# ОБНОСКИ ПУСТЫННОЙ ОДЕЖДЫ (ДЛЯ ВСЕХ ЗОМБИ)
# =========================================================================
func _build_clothing_rags() -> void:
	# 1. Шейный платок / коул / рваное пончо на шее и плечах (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var poncho := MeshInstance3D.new()
	var p_mesh := CylinderMesh.new()
	p_mesh.top_radius = 0.24
	p_mesh.bottom_radius = 0.44
	p_mesh.height = 0.32
	poncho.mesh = p_mesh
	poncho.material_override = _mat_desert_rags
	# Смещение к плечам/ключицам
	poncho.position = Vector3(-0.25, 0.0, 0.02)
	neck_att.add_child(poncho)

	# 2. Рваный пустынный пояс и набедренная повязка (кость hip_016)
	var hip_att := _get_or_create_bone_att("hip_016")

	# Поясной кушак вокруг талии
	var sash := MeshInstance3D.new()
	var s_mesh := CylinderMesh.new()
	s_mesh.top_radius = 0.32
	s_mesh.bottom_radius = 0.34
	s_mesh.height = 0.16
	sash.mesh = s_mesh
	sash.material_override = _mat_desert_rags
	sash.position = Vector3(-0.10, 0.0, 0.0)
	hip_att.add_child(sash)

	# Передний свисающий лоскут до колен
	var flap_front := MeshInstance3D.new()
	var f_box := BoxMesh.new()
	f_box.size = Vector3(0.48, 0.38, 0.02)
	flap_front.mesh = f_box
	flap_front.material_override = _mat_desert_rags
	flap_front.position = Vector3(-0.35, 0.0, 0.16)
	flap_front.rotation_degrees = Vector3(10, 0, 0)
	hip_att.add_child(flap_front)

	# Задний свисающий лоскут
	var flap_back := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.52, 0.42, 0.02)
	flap_back.mesh = b_box
	flap_back.material_override = _mat_desert_rags
	flap_back.position = Vector3(-0.36, 0.0, -0.16)
	flap_back.rotation_degrees = Vector3(-10, 0, 0)
	hip_att.add_child(flap_back)

	# Боковые рваные лохмотья
	for side in [-0.18, 0.18]:
		var flap_side := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.38, 0.02, 0.28)
		flap_side.mesh = s_box
		flap_side.material_override = _mat_desert_rags
		flap_side.position = Vector3(-0.32, side, 0.0)
		hip_att.add_child(flap_side)

	# 3. Обмотки из бинтов / лоскутов на голенях
	for bname in ["shin_L_035", "shin_R_039"]:
		var shin_att := _get_or_create_bone_att(bname)
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

# --- 1. WALKER: ШТУРМОВОЙ КИБОРГ ---
func _build_walker_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")

	# Настоящая 3D стальная кираса на ВЕРХНЕЙ ЧАСТИ ГРУДИ (не в животе!)
	var armor = ACC_ARMOR_METAL.instantiate()
	neck_att.add_child(armor)
	armor.rotation_degrees = Vector3(0, 0, -90)
	armor.position = Vector3(-0.38, 0.0, 0.08)

	# Силовой кабель по хребту
	var cable = ACC_CABLE_LONG.instantiate()
	neck_att.add_child(cable)
	cable.rotation_degrees = Vector3(0, 0, -90)
	cable.position = Vector3(-0.32, 0.0, -0.09)

	# Гидравлические трубки кондуита на груди
	var pipes = ACC_PIPES_SMALL.instantiate()
	neck_att.add_child(pipes)
	pipes.rotation_degrees = Vector3(0, 0, -90)
	pipes.position = Vector3(-0.30, 0.08, 0.14)
	pipes.scale = Vector3.ONE * 1.4

	# Настоящий стальной боевой клинок на правом предплечье
	var arm_att := _get_or_create_bone_att("forearm_R_09")
	var dagger = ACC_DAGGER.instantiate()
	arm_att.add_child(dagger)
	dagger.rotation_degrees = Vector3(0, 90, 0)
	dagger.position = Vector3(0.25, 0.0, 0.06)
	dagger.scale = Vector3.ONE * 1.1

	# Титановый наплечник на левом плече
	var sh_att := _get_or_create_bone_att("shoulder_L_015")
	var pauldron = ACC_PLATE_SMALL.instantiate()
	sh_att.add_child(pauldron)
	pauldron.position = Vector3(0.20, 0.0, 0.08)
	pauldron.rotation_degrees = Vector3(0, 90, -45)
	pauldron.scale = Vector3.ONE * 1.5

	# Алый прицельный окуляр на черепе
	_create_cranial_plate(head_att, Color(1.0, 0.08, 0.08))

# --- 2. RUNNER: КИБЕР-БЕГУН ---
func _build_runner_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")
	var cyan_col := Color(0.1, 0.92, 1.0)

	# Легкая анатомическая тактическая кираса-портупея на груди
	var vest = ACC_ARMOR_LEATHER.instantiate()
	neck_att.add_child(vest)
	vest.rotation_degrees = Vector3(0, 0, -90)
	vest.position = Vector3(-0.36, 0.0, 0.07)
	vest.scale = Vector3.ONE * 1.15

	# Двойные выхлопные турбины охлаждения на лопатках
	var vent = ACC_VENT.instantiate()
	neck_att.add_child(vent)
	vent.rotation_degrees = Vector3(0, 0, -90)
	vent.position = Vector3(-0.28, 0.0, -0.12)
	vent.scale = Vector3.ONE * 1.4

	# Позвоночный силовой кабель
	var cable = ACC_CABLE_LONG.instantiate()
	neck_att.add_child(cable)
	cable.rotation_degrees = Vector3(0, 0, -90)
	cable.position = Vector3(-0.30, 0.0, -0.08)

	# Парные выдвижные клинки-богомолы на обоих предплечьях
	for bname in ["forearm_L_051", "forearm_R_09"]:
		var a_att := _get_or_create_bone_att(bname)
		var blade = ACC_DAGGER.instantiate()
		a_att.add_child(blade)
		blade.rotation_degrees = Vector3(0, 90, 0)
		blade.position = Vector3(0.25, 0.0, 0.06)
		blade.scale = Vector3.ONE * 1.2

	# Неоновый узкий визор на глазах
	var visor := MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.10, 0.42, 0.07)
	visor.mesh = v_box
	var v_mat := StandardMaterial3D.new()
	v_mat.albedo_color = cyan_col
	v_mat.emission_enabled = true
	v_mat.emission = cyan_col
	v_mat.emission_energy_multiplier = 4.8
	visor.material_override = v_mat
	visor.position = Vector3(0.12, -0.02, 0.28)
	head_att.add_child(visor)
	_add_light(visor, cyan_col, 1.2, 2.2)

# --- 3. BRUTE: ТЯЖЕЛЫЙ ДЖАГГЕРНАУТ ---
func _build_brute_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")

	# Тяжелая черная титановая кираса на ВЕРХНЕЙ ГРУДИ
	var armor = ACC_ARMOR_BLACK.instantiate()
	neck_att.add_child(armor)
	armor.rotation_degrees = Vector3(0, 0, -90)
	armor.position = Vector3(-0.40, 0.0, 0.10)
	armor.scale = Vector3.ONE * 1.25

	# Железная маска-череп на лице
	var skull = ACC_SKULL.instantiate()
	head_att.add_child(skull)
	skull.rotation_degrees = Vector3(0, 0, -90)
	skull.position = Vector3(0.06, 0.0, 0.12)
	skull.scale = Vector3.ONE * 0.95

	# Горящая багровая щель визора сквозь глазницы черепа
	var eye_glow := MeshInstance3D.new()
	var eg_box := BoxMesh.new()
	eg_box.size = Vector3(0.04, 0.35, 0.04)
	eye_glow.mesh = eg_box
	var eg_mat := StandardMaterial3D.new()
	eg_mat.albedo_color = Color(1.0, 0.02, 0.02)
	eg_mat.emission_enabled = true
	eg_mat.emission = Color(1.0, 0.02, 0.02)
	eg_mat.emission_energy_multiplier = 5.0
	eye_glow.material_override = eg_mat
	eye_glow.position = Vector3(0.02, 0.0, 0.08)
	skull.add_child(eye_glow)
	_add_light(eye_glow, Color(1.0, 0.02, 0.02), 1.8, 2.5)

	# Массивный бронещит на левом плече
	var sh_l := _get_or_create_bone_att("shoulder_L_015")
	var blast_plate = ACC_PLATE_LARGE.instantiate()
	sh_l.add_child(blast_plate)
	blast_plate.position = Vector3(0.24, 0.0, 0.08)
	blast_plate.rotation_degrees = Vector3(0, 90, -45)
	blast_plate.scale = Vector3.ONE * 1.6

	# Наплечник со щитком на правом плече
	var sh_r := _get_or_create_bone_att("shoulder_R_06")
	var pauldron_r = ACC_PLATE_SMALL.instantiate()
	sh_r.add_child(pauldron_r)
	pauldron_r.position = Vector3(-0.22, 0.0, 0.08)
	pauldron_r.rotation_degrees = Vector3(0, 90, 45)
	pauldron_r.scale = Vector3.ONE * 1.8

	# Колоссальная гидравлическая клешня на правой руке
	var claw_att := _get_or_create_bone_att("forearm_R_09")
	var claw_base := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.18
	c_cyl.bottom_radius = 0.15
	c_cyl.height = 0.55
	claw_base.mesh = c_cyl
	claw_base.material_override = _mat_cyber_armor
	claw_base.position = Vector3(0.22, 0.0, 0.0)
	claw_att.add_child(claw_base)

	# 3 стальных захвата на клешне
	for a in [-35.0, 0.0, 35.0]:
		var finger := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.08, 0.45, 0.08)
		finger.mesh = f_box
		finger.material_override = _mat_dark_metal
		finger.position = Vector3(0.35, 0.0, 0.08)
		finger.rotation_degrees = Vector3(0, a, 0)
		claw_base.add_child(finger)

	# Трофейный череп на поясном ремне
	var hip_att := _get_or_create_bone_att("hip_016")
	var trophy = ACC_SKULL.instantiate()
	hip_att.add_child(trophy)
	trophy.rotation_degrees = Vector3(0, 0, -90)
	trophy.position = Vector3(-0.25, 0.22, 0.14)
	trophy.scale = Vector3.ONE * 0.7

# --- 4. CRAWLER: ПАУК-СТАЛКЕР ---
func _build_crawler_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var neck_att := _get_or_create_bone_att("neck_013")
	var amber_col := Color(1.0, 0.45, 0.02)

	# 4 светящихся паучьих ока на голове
	_create_ocular_eye(head_att, Vector3(0.12, -0.22, 0.28), amber_col, 0.035)
	_create_ocular_eye(head_att, Vector3(0.12, -0.32, 0.28), amber_col, 0.035)
	_create_ocular_eye(head_att, Vector3(0.02, -0.18, 0.26), amber_col, 0.028)
	_create_ocular_eye(head_att, Vector3(0.02, -0.36, 0.26), amber_col, 0.028)

	# Хитиновый спинной бронепанцирь (настоящая 3D плита)
	var carapace = ACC_PLATE_LARGE.instantiate()
	neck_att.add_child(carapace)
	carapace.rotation_degrees = Vector3(0, 180, -90)
	carapace.position = Vector3(-0.35, 0.0, -0.14)
	carapace.scale = Vector3.ONE * 1.5

	# Вентиляционный охладитель
	var vent = ACC_VENT.instantiate()
	neck_att.add_child(vent)
	vent.rotation_degrees = Vector3(0, 0, -90)
	vent.position = Vector3(-0.22, 0.0, -0.16)

	# Сигнальный маячок на панцире
	var beacon := MeshInstance3D.new()
	var b_sph := SphereMesh.new()
	b_sph.radius = 0.06
	b_sph.height = 0.08
	beacon.mesh = b_sph
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = amber_col
	b_mat.emission_enabled = true
	b_mat.emission = amber_col
	b_mat.emission_energy_multiplier = 4.0
	beacon.material_override = b_mat
	beacon.position = Vector3(-0.32, 0.0, -0.18)
	neck_att.add_child(beacon)
	_add_light(beacon, amber_col, 1.2, 2.0)

# --- 5. SPITTER: ХИМИЧЕСКИЙ БИО-КИБОРГ ---
func _build_spitter_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")
	var toxic_green := Color(0.2, 1.0, 0.25)

	# Ядовитый зеленый окуляр
	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), toxic_green, 0.045)

	# Химический респиратор на челюсти
	var jaw_att := _get_or_create_bone_att("jaw_019")
	var mask := MeshInstance3D.new()
	var m_box := BoxMesh.new()
	m_box.size = Vector3(0.15, 0.35, 0.25)
	mask.mesh = m_box
	mask.material_override = _mat_dark_metal
	mask.position = Vector3(0.0, 0.0, 0.15)
	jaw_att.add_child(mask)

	# Парные 3D баллоны с токсином за спиной на шее/лопатках
	for side in [-0.14, 0.14]:
		var tank = ACC_PROPANE_TANK.instantiate()
		neck_att.add_child(tank)
		tank.rotation_degrees = Vector3(0, 0, -90)
		tank.position = Vector3(-0.35, side, -0.16)
		tank.scale = Vector3.ONE * 0.55

	# Питающие трубки
	var pipes = ACC_PIPES_SMALL.instantiate()
	neck_att.add_child(pipes)
	pipes.rotation_degrees = Vector3(0, 0, -90)
	pipes.position = Vector3(-0.25, 0.0, -0.10)
	pipes.scale = Vector3.ONE * 1.3

	# Распылитель кислоты на левой руке
	var spray_att := _get_or_create_bone_att("forearm_L_051")
	var nozzle := MeshInstance3D.new()
	var n_cyl := CylinderMesh.new()
	n_cyl.top_radius = 0.05
	n_cyl.bottom_radius = 0.08
	n_cyl.height = 0.45
	nozzle.mesh = n_cyl
	nozzle.material_override = _mat_dark_metal
	nozzle.position = Vector3(0.25, 0.0, 0.08)
	spray_att.add_child(nozzle)

# --- 6. SCREAMER: НЕЙРО-СИРЕНА ---
func _build_screamer_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")
	var amber_color := Color(1.0, 0.82, 0.08)

	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), amber_color, 0.04)

	# Легкая портупея на груди
	var vest = ACC_ARMOR_LEATHER.instantiate()
	neck_att.add_child(vest)
	vest.rotation_degrees = Vector3(0, 0, -90)
	vest.position = Vector3(-0.36, 0.0, 0.07)
	vest.scale = Vector3.ONE * 1.1

	# Вращающийся купол сирены на макушке
	var siren := MeshInstance3D.new()
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = 0.06
	s_cyl.bottom_radius = 0.09
	s_cyl.height = 0.16
	siren.mesh = s_cyl
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = amber_color
	s_mat.emission_enabled = true
	s_mat.emission = amber_color
	s_mat.emission_energy_multiplier = 5.0
	siren.material_override = s_mat
	siren.position = Vector3(0.35, -0.05, 0.0)
	head_att.add_child(siren)
	_add_light(siren, amber_color, 1.5, 2.5)

	# Акустические излучатели по бокам черепа
	for side in [-0.28, 0.28]:
		var dish := MeshInstance3D.new()
		var d_cyl := CylinderMesh.new()
		d_cyl.top_radius = 0.13
		d_cyl.bottom_radius = 0.03
		d_cyl.height = 0.08
		dish.mesh = d_cyl
		dish.material_override = _mat_dark_metal
		dish.position = Vector3(0.05, side, 0.0)
		dish.rotation_degrees = Vector3(0, 0, 90 if side > 0 else -90)
		head_att.add_child(dish)

	# Настоящая 3D длинная антенна связи на верхней части спины
	var antenna = ACC_ANTENNA.instantiate()
	neck_att.add_child(antenna)
	antenna.rotation_degrees = Vector3(0, 0, -90)
	antenna.position = Vector3(-0.15, 0.12, -0.12)
	antenna.scale = Vector3.ONE * 0.85

	# Силовой кабель по спине
	var cable = ACC_CABLE_LONG.instantiate()
	neck_att.add_child(cable)
	cable.rotation_degrees = Vector3(0, 0, -90)
	cable.position = Vector3(-0.30, 0.0, -0.08)

# --- 7. EXPLODER: ДРОН-КАМИКАДЗЕ ---
func _build_exploder_upgrades() -> void:
	var neck_att := _get_or_create_bone_att("neck_013")
	var head_att := _get_or_create_bone_att("head_014")
	var fiery_orange := Color(1.0, 0.28, 0.02)

	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), fiery_orange, 0.045)

	# Настоящая 3D энергетическая батарея / реакторное ядро бомбы НА ВЕРХНЕЙ ГРУДИ
	var reactor = ACC_BATTERY.instantiate()
	neck_att.add_child(reactor)
	reactor.rotation_degrees = Vector3(0, 0, -90)
	reactor.position = Vector3(-0.38, 0.0, 0.10)
	reactor.scale = Vector3.ONE * 1.6

	# Защитная рама/плита реактора вокруг батареи
	var frame = ACC_PLATE_LARGE.instantiate()
	neck_att.add_child(frame)
	frame.rotation_degrees = Vector3(0, 0, -90)
	frame.position = Vector3(-0.39, 0.0, 0.06)
	frame.scale = Vector3.ONE * 1.1

	# Пульсирующий строб реактора
	var strobe := MeshInstance3D.new()
	var s_sph := SphereMesh.new()
	s_sph.radius = 0.08
	s_sph.height = 0.12
	strobe.mesh = s_sph
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = fiery_orange
	s_mat.emission_enabled = true
	s_mat.emission = fiery_orange
	s_mat.emission_energy_multiplier = 6.0
	strobe.material_override = s_mat
	strobe.position = Vector3(-0.38, 0.0, 0.16)
	neck_att.add_child(strobe)
	_add_light(strobe, fiery_orange, 2.5, 3.5)

	# 3D тактический ранец со взрывчаткой за спиной
	var pack = ACC_BACKPACK.instantiate()
	neck_att.add_child(pack)
	pack.rotation_degrees = Vector3(0, 180, -90)
	pack.position = Vector3(-0.35, 0.0, -0.16)
	pack.scale = Vector3.ONE * 0.45

	# Охладители на плечах
	var vent = ACC_VENT.instantiate()
	neck_att.add_child(vent)
	vent.rotation_degrees = Vector3(0, 0, -90)
	vent.position = Vector3(-0.25, 0.0, -0.10)

# --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
func _create_cranial_plate(parent: Node3D, color: Color) -> void:
	# Металлическая пластина на черепе
	var plate := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.18, 0.28, 0.06)
	plate.mesh = p_box
	plate.material_override = _mat_cyber_armor
	plate.position = Vector3(0.14, -0.25, 0.24)
	plate.rotation_degrees = Vector3(15, 0, 0)
	parent.add_child(plate)

	# Окуляр внутри пластины
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

	# 1. Смерть: фиксирует труп намертво без дерганий
	if is_dead:
		if not has_died:
			has_died = true
			death_timer = 0.0
			for light in eye_lights:
				if is_instance_valid(light):
					light.light_energy = 0.0
			anim_player.play("death", 0.1)
			return

		death_timer += _delta
		if death_timer >= 2.95 or not anim_player.is_playing() or anim_player.current_animation != "death":
			anim_player.pause()
			if anim_player.has_animation("death"):
				anim_player.seek(anim_player.get_animation("death").length, true)
		return

	if has_died:
		# Труп уже умер — никаких других анимаций больше никогда не проигрывать
		return

	# 2. Получение урона
	if is_hurt:
		if anim_player.current_animation != "damage":
			anim_player.play("damage", 0.08, 1.4)
		return

	# 3. Атака
	if is_attacking:
		var atk_anim = "attack02" if (current_type == "Runner" or current_type == "Screamer") else "attack01"
		var atk_speed = 1.4 if current_type == "Runner" else 1.1
		if anim_player.current_animation != atk_anim:
			anim_player.play(atk_anim, 0.1, atk_speed)
		return

	# 4. Движение
	if is_moving:
		match current_type:
			"Crawler":
				if anim_player.current_animation != "on_all_four_B":
					anim_player.play("on_all_four_B", 0.2, maxf(1.0, move_speed * 0.45))
			"Runner":
				if anim_player.current_animation != "run":
					anim_player.play("run", 0.15, maxf(1.1, move_speed * 0.32))
			"Brute":
				if anim_player.current_animation != "walk02":
					anim_player.play("walk02", 0.2, 0.85)
			_:
				if anim_player.current_animation != "walk01":
					anim_player.play("walk01", 0.2, maxf(0.85, move_speed * 0.38))
		return

	# 5. Покой (Idle)
	if anim_player.current_animation != "idle01" and anim_player.current_animation != "idle02":
		anim_player.play("idle01", 0.25)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "death":
		if anim_player:
			anim_player.pause()
			if anim_player.has_animation("death"):
				anim_player.seek(anim_player.get_animation("death").length, true)
