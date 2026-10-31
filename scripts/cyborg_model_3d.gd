extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Использует оригинальную анимированную 3D-модель (Melty Zombie)
# с богатым набором деталей:
# - Обноски одежды / рваные лохмотья пустыни (burlap rags, scarves, loincloths)
# - Корректное анатомическое расположение деталей (на груди, плечах, руках, коленях, а не в животе!)
# - Уникальные кибер-импланты для каждого типа (Walker, Runner, Brute, Crawler, Spitter, Screamer, Exploder)
# - Полная фиксация трупа после смерти (не дергается и не встает).
# =========================================================================

const ZOMBIE_MODEL_PATH: String = "res://models/zombies/melty_zombie/scene.gltf"

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

	# Добавление обносок одежды и кибернетических имплантов
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
	_mat_desert_rags.cull_mode = BaseMaterial3D.CULL_DISABLED # Двустороннее отображение ткани
	_mat_desert_rags.uv1_scale = Vector3(1.5, 1.5, 1.5)

	# 2. Материал кибер-брони с заклепками и ржавчиной
	_mat_cyber_armor = StandardMaterial3D.new()
	if _tex_armor:
		_mat_cyber_armor.albedo_texture = _tex_armor
	else:
		_mat_cyber_armor.albedo_color = Color(0.25, 0.23, 0.22)
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
			scale = Vector3.ONE * (BASE_SCALE * 1.45) # Громила высотой ~2.7м
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
	# 1. Рваный шарф / пончо вокруг шеи и плеч (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var poncho := MeshInstance3D.new()
	var p_mesh := CylinderMesh.new()
	p_mesh.top_radius = 0.28
	p_mesh.bottom_radius = 0.42
	p_mesh.height = 0.35
	poncho.mesh = p_mesh
	poncho.material_override = _mat_desert_rags
	poncho.position = Vector3(-0.35, 0.0, 0.1)
	neck_att.add_child(poncho)

	# 2. Рваная набедренная повязка / лохмотья пояса (кость hip_016)
	var hip_att := _get_or_create_bone_att("hip_016")
	var loincloth := MeshInstance3D.new()
	var l_mesh := BoxMesh.new()
	l_mesh.size = Vector3(0.5, 0.03, 0.55)
	loincloth.mesh = l_mesh
	loincloth.material_override = _mat_desert_rags
	loincloth.position = Vector3(-0.6, 0.0, 0.35)
	hip_att.add_child(loincloth)

	# 3. Свисающие лохмотья ткани сзади
	var back_rags := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.45, 0.03, 0.6)
	back_rags.mesh = b_mesh
	back_rags.material_override = _mat_desert_rags
	back_rags.position = Vector3(-0.65, 0.0, -0.25)
	hip_att.add_child(back_rags)

# =========================================================================
# УНИКАЛЬНЫЕ КИБЕРНЕТИЧЕСКИЕ АПГРЕЙДЫ ПО ТИПАМ
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
	# Алый окуляр с титановой накладкой на лбу
	var head_att := _get_or_create_bone_att("head_014")
	_create_cranial_plate(head_att, Color(1.0, 0.05, 0.05))

	# Баллистическая бронеплита на ВЕРХНЕЙ ЧАСТИ ГРУДИ (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var chestplate := MeshInstance3D.new()
	var cp_box := BoxMesh.new()
	cp_box.size = Vector3(0.55, 0.45, 0.08)
	chestplate.mesh = cp_box
	chestplate.material_override = _mat_cyber_armor
	# Смещение на грудь (не в живот!): local -X = вниз к груди, local +Z = вперед
	chestplate.position = Vector3(-0.7, 0.0, 0.48)
	neck_att.add_child(chestplate)

	# Сегментный позвоночный кабель на спине
	var spine_conduit := MeshInstance3D.new()
	var sc_cyl := CylinderMesh.new()
	sc_cyl.top_radius = 0.045
	sc_cyl.bottom_radius = 0.045
	sc_cyl.height = 0.85
	spine_conduit.mesh = sc_cyl
	spine_conduit.material_override = _mat_dark_metal
	spine_conduit.position = Vector3(-0.6, 0.0, -0.42)
	neck_att.add_child(spine_conduit)

	# Боевой клинок на правом предплечье/запястье
	var arm_att := _get_or_create_bone_att("forearm_R_09")
	var blade := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.04, 0.65, 0.09)
	blade.mesh = b_box
	blade.material_override = _mat_steel_blade
	blade.position = Vector3(0.0, 0.55, 0.12)
	arm_att.add_child(blade)

# --- 2. RUNNER: КИБЕР-БЕГУН ---
func _build_runner_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var cyan_color := Color(0.1, 0.9, 1.0)

	# Аэродинамичный неоновый визор на глазах
	var visor := MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.12, 0.45, 0.08)
	visor.mesh = v_box
	var v_mat := StandardMaterial3D.new()
	v_mat.albedo_color = cyan_color
	v_mat.emission_enabled = true
	v_mat.emission = cyan_color
	v_mat.emission_energy_multiplier = 4.5
	visor.material_override = v_mat
	visor.position = Vector3(0.12, -0.02, 0.28)
	head_att.add_child(visor)
	_add_light(visor, cyan_color, 1.2, 2.0)

	# Тройные ребра охлаждения на спине (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	for i in range(3):
		var fin := MeshInstance3D.new()
		var fin_box := BoxMesh.new()
		fin_box.size = Vector3(0.18, 0.03, 0.38)
		fin.mesh = fin_box
		fin.material_override = _mat_dark_metal
		fin.position = Vector3(-0.35 - i * 0.22, 0.0, -0.42)
		neck_att.add_child(fin)

	# Парные выдвижные клинки-богомолы на обеих руках
	for bname in ["forearm_L_051", "forearm_R_09"]:
		var a_att := _get_or_create_bone_att(bname)
		var b_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.03, 0.72, 0.08)
		b_mesh.mesh = b_box
		b_mesh.material_override = _mat_steel_blade
		b_mesh.position = Vector3(0.0, 0.55, 0.14)
		a_att.add_child(b_mesh)

	# Пневматические поршни на голенях
	for bname in ["shin_L_035", "shin_R_039"]:
		var s_att := _get_or_create_bone_att(bname)
		var piston := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.5
		piston.mesh = cyl
		piston.material_override = _mat_dark_metal
		piston.position = Vector3(0.0, 0.0, -0.15)
		s_att.add_child(piston)

# --- 3. BRUTE: ТЯЖЕЛЫЙ ДЖАГГЕРНАУТ ---
func _build_brute_upgrades() -> void:
	# Тяжелая железная маска-череп с узкой светящейся щелью
	var head_att := _get_or_create_bone_att("head_014")
	var helmet := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.35, 0.65, 0.45)
	helmet.mesh = h_box
	helmet.material_override = _mat_cyber_armor
	helmet.position = Vector3(0.05, 0.0, 0.15)
	head_att.add_child(helmet)

	var slit := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.05, 0.45, 0.04)
	slit.mesh = s_box
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.02, 0.02)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.02, 0.02)
	red_mat.emission_energy_multiplier = 5.0
	slit.material_override = red_mat
	slit.position = Vector3(0.12, 0.0, 0.38)
	head_att.add_child(slit)
	_add_light(slit, Color(1.0, 0.02, 0.02), 1.6, 2.5)

	# Шипастый наплечник на левом плече
	var shoulder_att := _get_or_create_bone_att("shoulder_L_015")
	var pauldron := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.45, 0.55, 0.45)
	pauldron.mesh = p_box
	pauldron.material_override = _mat_cyber_armor
	pauldron.position = Vector3(0.0, 0.25, 0.0)
	shoulder_att.add_child(pauldron)

	# 2 стальных шипа на наплечнике
	for o in [-0.15, 0.15]:
		var spike := MeshInstance3D.new()
		var s_cone := CylinderMesh.new()
		s_cone.top_radius = 0.01
		s_cone.bottom_radius = 0.08
		s_cone.height = 0.35
		spike.mesh = s_cone
		spike.material_override = _mat_dark_metal
		spike.position = Vector3(0.0, 0.35, o)
		pauldron.add_child(spike)

	# Противоосколочный щит на верхней груди (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var blast_plate := MeshInstance3D.new()
	var bp_box := BoxMesh.new()
	bp_box.size = Vector3(0.65, 0.75, 0.14)
	blast_plate.mesh = bp_box
	blast_plate.material_override = _mat_cyber_armor
	blast_plate.position = Vector3(-0.75, 0.0, 0.52)
	neck_att.add_child(blast_plate)

	# Колоссальная гидравлическая клешня на правой руке
	var claw_att := _get_or_create_bone_att("forearm_R_09")
	var claw_base := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.18
	c_cyl.bottom_radius = 0.15
	c_cyl.height = 0.6
	claw_base.mesh = c_cyl
	claw_base.material_override = _mat_cyber_armor
	claw_base.position = Vector3(0.0, 0.3, 0.0)
	claw_att.add_child(claw_base)

	# 3 мощных стальных пальца-захвата
	for a in [-35.0, 0.0, 35.0]:
		var finger := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.08, 0.5, 0.08)
		finger.mesh = f_box
		finger.material_override = _mat_dark_metal
		finger.position = Vector3(0.0, 0.6, 0.12)
		finger.rotation_degrees = Vector3(0, 0, a)
		claw_base.add_child(finger)

# --- 4. CRAWLER: ПАУК-СТАЛКЕР ---
func _build_crawler_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var red_col := Color(1.0, 0.05, 0.05)
	_create_ocular_eye(head_att, Vector3(0.12, -0.22, 0.28), red_col, 0.035)
	_create_ocular_eye(head_att, Vector3(0.12, -0.32, 0.28), red_col, 0.035)
	_create_ocular_eye(head_att, Vector3(0.02, -0.18, 0.26), red_col, 0.028)
	_create_ocular_eye(head_att, Vector3(0.02, -0.36, 0.26), red_col, 0.028)

	# Спинной бронепанцирь (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var carapace := MeshInstance3D.new()
	var car_box := BoxMesh.new()
	car_box.size = Vector3(0.7, 0.65, 0.15)
	carapace.mesh = car_box
	carapace.material_override = _mat_cyber_armor
	carapace.position = Vector3(-0.65, 0.0, -0.45)
	neck_att.add_child(carapace)

	# Мигающий маяк на панцире
	var beacon := MeshInstance3D.new()
	var b_sph := SphereMesh.new()
	b_sph.radius = 0.06
	b_sph.height = 0.08
	beacon.mesh = b_sph
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(1.0, 0.4, 0.0)
	b_mat.emission_enabled = true
	b_mat.emission = Color(1.0, 0.4, 0.0)
	b_mat.emission_energy_multiplier = 4.0
	beacon.material_override = b_mat
	beacon.position = Vector3(0.0, 0.0, -0.12)
	carapace.add_child(beacon)
	_add_light(beacon, Color(1.0, 0.4, 0.0), 1.0, 1.8)

# --- 5. SPITTER: ХИМИЧЕСКИЙ БИО-КИБОРГ ---
func _build_spitter_upgrades() -> void:
	var toxic_green := Color(0.2, 1.0, 0.25)
	var head_att := _get_or_create_bone_att("head_014")
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

	# Двойные кислотные баллоны за спиной на шее/лопатках (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	for x_offset in [-0.22, 0.22]:
		var tank := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.1
		cyl.bottom_radius = 0.1
		cyl.height = 0.7
		tank.mesh = cyl
		var tank_mat := StandardMaterial3D.new()
		tank_mat.albedo_color = Color(0.1, 0.35, 0.12)
		tank_mat.emission_enabled = true
		tank_mat.emission = toxic_green
		tank_mat.emission_energy_multiplier = 2.0
		tank.material_override = tank_mat
		tank.position = Vector3(-0.55, x_offset, -0.52)
		tank.rotation_degrees = Vector3(0, 0, 90)
		neck_att.add_child(tank)

	# Распылитель кислоты на левой руке
	var spray_att := _get_or_create_bone_att("forearm_L_051")
	var nozzle := MeshInstance3D.new()
	var n_cyl := CylinderMesh.new()
	n_cyl.top_radius = 0.05
	n_cyl.bottom_radius = 0.08
	n_cyl.height = 0.45
	nozzle.mesh = n_cyl
	nozzle.material_override = _mat_dark_metal
	nozzle.position = Vector3(0.0, 0.4, 0.12)
	spray_att.add_child(nozzle)

# --- 6. SCREAMER: НЕЙРО-СИРЕНА ---
func _build_screamer_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var amber_color := Color(1.0, 0.82, 0.08)

	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), amber_color, 0.04)

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
	_add_light(siren, amber_color, 1.4, 2.2)

	# Акустические излучатели по бокам черепа
	for side in [-0.3, 0.3]:
		var dish := MeshInstance3D.new()
		var d_cyl := CylinderMesh.new()
		d_cyl.top_radius = 0.14
		d_cyl.bottom_radius = 0.03
		d_cyl.height = 0.08
		dish.mesh = d_cyl
		dish.material_override = _mat_dark_metal
		dish.position = Vector3(0.05, side, 0.0)
		dish.rotation_degrees = Vector3(0, 0, 90 if side > 0 else -90)
		head_att.add_child(dish)

	# Антенная решетка на спине (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var antenna := MeshInstance3D.new()
	var a_cyl := CylinderMesh.new()
	a_cyl.top_radius = 0.015
	a_cyl.bottom_radius = 0.02
	a_cyl.height = 1.05
	antenna.mesh = a_cyl
	antenna.material_override = _mat_dark_metal
	antenna.position = Vector3(0.1, 0.15, -0.45)
	neck_att.add_child(antenna)

# --- 7. EXPLODER: ДРОН-КАМИКАДЗЕ ---
func _build_exploder_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var fiery_orange := Color(1.0, 0.22, 0.02)
	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), fiery_orange, 0.04)

	# Реакторное ядро бомбы НА ГРУДИ (кость neck_013)
	var neck_att := _get_or_create_bone_att("neck_013")
	var bomb_core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	bomb_core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = fiery_orange
	core_mat.emission_enabled = true
	core_mat.emission = fiery_orange
	core_mat.emission_energy_multiplier = 6.0
	bomb_core.material_override = core_mat
	bomb_core.position = Vector3(-0.7, 0.0, 0.52)
	neck_att.add_child(bomb_core)
	_add_light(bomb_core, fiery_orange, 2.2, 3.5)

	# Защитная клетка реактора
	var cage := MeshInstance3D.new()
	var cage_box := BoxMesh.new()
	cage_box.size = Vector3(0.48, 0.48, 0.14)
	cage.mesh = cage_box
	cage.material_override = _mat_cyber_armor
	cage.position = Vector3(-0.7, 0.0, 0.6)
	neck_att.add_child(cage)

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
