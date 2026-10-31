extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Использует оригинальную анимированную 3D-модель (Melty Zombie)
# с уникальными процедурными кибернетическими апгрейдами для каждого типа:
# - Walker:   Штурмовой окуляр, бронеплита на груди, боевой клинок на запястье
# - Runner:   Неоновый бирюзовый визор, радиаторные ребра на спине, клинки-богомолы на обеих руках, поршни на ногах
# - Brute:    Тяжелый бронешлем с узкой щелью, гигантский шипастый наплечник, колоссальная гидравлическая клешня
# - Crawler:  Паучий 4-глазый оптический сенсор, спинной панцирь с маячком, стальные когти
# - Spitter:  Химический респиратор с токсичным зеленым оком, баллоны с кислотой на спине, распылитель на руке
# - Screamer: Вращающаяся желтая сирена на голове, акустические тарелки-излучатели, антенная решетка
# - Exploder: Реакторное ядро бомбы в груди с пульсирующим пламенем, защитная клетка, мигающий маяк тревоги
#
# Фиксация после смерти: трупы падают на землю и намертво застывают (не дергаются).
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

# Материалы общего пользования
var _mat_dark_metal: StandardMaterial3D
var _mat_rust_metal: StandardMaterial3D
var _mat_hazard: StandardMaterial3D

func _ready() -> void:
	pass

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()
	_init_shared_materials()

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

	# Установка уникальных кибернетических имплантов для данного типа
	if skeleton:
		_build_type_cyber_upgrades()

	# Запуск начальной анимации покоя
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

func _init_shared_materials() -> void:
	_mat_dark_metal = StandardMaterial3D.new()
	_mat_dark_metal.albedo_color = Color(0.12, 0.12, 0.14)
	_mat_dark_metal.metallic = 0.95
	_mat_dark_metal.roughness = 0.25

	_mat_rust_metal = StandardMaterial3D.new()
	_mat_rust_metal.albedo_color = Color(0.38, 0.26, 0.18)
	_mat_rust_metal.metallic = 0.85
	_mat_rust_metal.roughness = 0.55

	_mat_hazard = StandardMaterial3D.new()
	_mat_hazard.albedo_color = Color(0.9, 0.72, 0.08)
	_mat_hazard.metallic = 0.6
	_mat_hazard.roughness = 0.35

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
			scale = Vector3.ONE * (BASE_SCALE * 1.42) # Колоссальный танк
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
	var head_att := _get_or_create_bone_att("head_014")
	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), Color(1.0, 0.05, 0.05), 0.04)

	# Бронеплита на груди с заклепками
	var chest_att := _get_or_create_bone_att("chest_017")
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.45, 0.08)
	plate.mesh = box
	plate.material_override = _mat_dark_metal
	plate.position = Vector3(0.1, -0.05, 0.55)
	plate.rotation_degrees = Vector3(10, 0, 0)
	chest_att.add_child(plate)

	# Клинок на правом запястье
	var arm_att := _get_or_create_bone_att("forearm_R_09")
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.04, 0.55, 0.08)
	blade.mesh = blade_box
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.8, 0.82, 0.85)
	blade_mat.metallic = 0.98
	blade_mat.roughness = 0.15
	blade.material_override = blade_mat
	blade.position = Vector3(0.0, 0.35, 0.1)
	arm_att.add_child(blade)

# --- 2. RUNNER: КИБЕР-БЕГУН (НЕОНОВЫЙ ВИЗОР, КЛИНКИ-БОГОМОЛЫ, ПОРШНИ) ---
func _build_runner_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var cyan_color := Color(0.1, 0.85, 1.0)
	# Узкий горизонтальный визор на глазах
	var visor := MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.12, 0.45, 0.06)
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

	# Спинные радиаторные рёбра (охлаждение спринтера)
	var chest_att := _get_or_create_bone_att("chest_017")
	for i in range(3):
		var fin := MeshInstance3D.new()
		var fin_box := BoxMesh.new()
		fin_box.size = Vector3(0.08, 0.03, 0.35)
		fin.mesh = fin_box
		fin.material_override = _mat_dark_metal
		fin.position = Vector3(0.3 - i * 0.22, 0.0, -0.45)
		chest_att.add_child(fin)

	# Парные клинки-богомолы на обеих руках
	for bone_name in ["forearm_L_051", "forearm_R_09"]:
		var a_att := _get_or_create_bone_att(bone_name)
		var b_mesh := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.03, 0.65, 0.07)
		b_mesh.mesh = b_box
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.15, 0.15, 0.18)
		b_mat.emission_enabled = true
		b_mat.emission = cyan_color
		b_mat.emission_energy_multiplier = 2.0
		b_mesh.material_override = b_mat
		b_mesh.position = Vector3(0.0, 0.45, 0.15)
		a_att.add_child(b_mesh)

	# Поршни на голенях
	for bone_name in ["shin_L_035", "shin_R_039"]:
		var s_att := _get_or_create_bone_att(bone_name)
		var piston := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.45
		piston.mesh = cyl
		piston.material_override = _mat_dark_metal
		piston.position = Vector3(0.0, 0.0, -0.12)
		s_att.add_child(piston)

# --- 3. BRUTE: ТЯЖЕЛЫЙ ДЖАГГЕРНАУТ (БРОНЕШЛЕМ, СПАЙКИ, ГИДРАВЛИЧЕСКАЯ КЛЕШНЯ) ---
func _build_brute_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	# Тяжелая железная маска-шлем
	var helmet := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.35, 0.65, 0.45)
	helmet.mesh = h_box
	helmet.material_override = _mat_rust_metal
	helmet.position = Vector3(0.05, 0.0, 0.15)
	head_att.add_child(helmet)

	# Узкая алая смотровая щель
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
	_add_light(slit, Color(1.0, 0.02, 0.02), 1.5, 2.5)

	# Шипастый наплечник на левом плече
	var shoulder_att := _get_or_create_bone_att("shoulder_L_015")
	var pauldron := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.4, 0.5, 0.4)
	pauldron.mesh = p_box
	pauldron.material_override = _mat_rust_metal
	pauldron.position = Vector3(0.0, 0.25, 0.0)
	shoulder_att.add_child(pauldron)

	# Шип на наплечнике
	var spike := MeshInstance3D.new()
	var s_cone := CylinderMesh.new()
	s_cone.top_radius = 0.01
	s_cone.bottom_radius = 0.08
	s_cone.height = 0.35
	spike.mesh = s_cone
	spike.material_override = _mat_dark_metal
	spike.position = Vector3(0.0, 0.38, 0.0)
	pauldron.add_child(spike)

	# Колоссальная гидравлическая клешня на правой руке
	var claw_att := _get_or_create_bone_att("forearm_R_09")
	var claw_base := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.16
	c_cyl.bottom_radius = 0.14
	c_cyl.height = 0.55
	claw_base.mesh = c_cyl
	claw_base.material_override = _mat_rust_metal
	claw_base.position = Vector3(0.0, 0.25, 0.0)
	claw_att.add_child(claw_base)

	# Стальные клешни-захваты
	for a in [-35.0, 0.0, 35.0]:
		var finger := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.08, 0.45, 0.08)
		finger.mesh = f_box
		finger.material_override = _mat_dark_metal
		finger.position = Vector3(0.0, 0.55, 0.1)
		finger.rotation_degrees = Vector3(0, 0, a)
		claw_base.add_child(finger)

# --- 4. CRAWLER: ПАУК-СТАЛКЕР (МУЛЬТИОКУЛЯР, ПАНЦИРЬ, КОГТИ) ---
func _build_crawler_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	# 4 паучьих светящихся окуляра
	var red_col := Color(1.0, 0.05, 0.05)
	_create_ocular_eye(head_att, Vector3(0.12, -0.22, 0.28), red_col, 0.03)
	_create_ocular_eye(head_att, Vector3(0.12, -0.32, 0.28), red_col, 0.03)
	_create_ocular_eye(head_att, Vector3(0.02, -0.18, 0.26), red_col, 0.025)
	_create_ocular_eye(head_att, Vector3(0.02, -0.36, 0.26), red_col, 0.025)

	# Спинной защитный панцирь
	var chest_att := _get_or_create_bone_att("chest_017")
	var carapace := MeshInstance3D.new()
	var car_box := BoxMesh.new()
	car_box.size = Vector3(0.7, 0.65, 0.15)
	carapace.mesh = car_box
	carapace.material_override = _mat_dark_metal
	carapace.position = Vector3(0.0, 0.0, -0.45)
	chest_att.add_child(carapace)

	# Маячок на панцире
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
	beacon.position = Vector3(0.0, 0.0, -0.1)
	carapace.add_child(beacon)
	_add_light(beacon, Color(1.0, 0.4, 0.0), 1.0, 1.8)

# --- 5. SPITTER: ХИМИЧЕСКИЙ БИО-КИБОРГ (КИСЛОТНЫЕ БАЛЛОНЫ, РЕСПИРАТОР, РАСПЫЛИТЕЛЬ) ---
func _build_spitter_upgrades() -> void:
	var toxic_green := Color(0.2, 1.0, 0.25)
	var head_att := _get_or_create_bone_att("head_014")

	# Токсичный окуляр
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

	# Двойные кислотные баллоны за спиной
	var chest_att := _get_or_create_bone_att("chest_017")
	for x_offset in [-0.22, 0.22]:
		var tank := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = 0.65
		tank.mesh = cyl
		var tank_mat := StandardMaterial3D.new()
		tank_mat.albedo_color = Color(0.1, 0.3, 0.12)
		tank_mat.emission_enabled = true
		tank_mat.emission = toxic_green
		tank_mat.emission_energy_multiplier = 1.8
		tank.material_override = tank_mat
		tank.position = Vector3(0.0, x_offset, -0.55)
		tank.rotation_degrees = Vector3(0, 0, 90)
		chest_att.add_child(tank)

	# Распылитель кислоты на левом предплечье
	var spray_att := _get_or_create_bone_att("forearm_L_051")
	var nozzle := MeshInstance3D.new()
	var n_cyl := CylinderMesh.new()
	n_cyl.top_radius = 0.05
	n_cyl.bottom_radius = 0.08
	n_cyl.height = 0.4
	nozzle.mesh = n_cyl
	nozzle.material_override = _mat_dark_metal
	nozzle.position = Vector3(0.0, 0.35, 0.1)
	spray_att.add_child(nozzle)

# --- 6. SCREAMER: НЕЙРО-СИРЕНА (МИГАЮЩИЙ МАЯК, АКУСТИЧЕСКИЕ ТАРЕЛКИ, АНТЕННЫ) ---
func _build_screamer_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var amber_color := Color(1.0, 0.82, 0.08)

	# Желтый сканирующий визор
	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), amber_color, 0.04)

	# Сирена на макушке
	var siren := MeshInstance3D.new()
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = 0.06
	s_cyl.bottom_radius = 0.09
	s_cyl.height = 0.15
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
		d_cyl.top_radius = 0.12
		d_cyl.bottom_radius = 0.03
		d_cyl.height = 0.08
		dish.mesh = d_cyl
		dish.material_override = _mat_dark_metal
		dish.position = Vector3(0.05, side, 0.0)
		dish.rotation_degrees = Vector3(0, 0, 90 if side > 0 else -90)
		head_att.add_child(dish)

	# Антенная решетка на спине
	var chest_att := _get_or_create_bone_att("chest_017")
	var antenna := MeshInstance3D.new()
	var a_cyl := CylinderMesh.new()
	a_cyl.top_radius = 0.015
	a_cyl.bottom_radius = 0.02
	a_cyl.height = 0.95
	antenna.mesh = a_cyl
	antenna.material_override = _mat_dark_metal
	antenna.position = Vector3(0.45, 0.15, -0.45)
	chest_att.add_child(antenna)

# --- 7. EXPLODER: ДРОН-КАМИКАДЗЕ (РЕАКТОР-БОМБА В ГРУДИ, СТРОБОСКОП) ---
func _build_exploder_upgrades() -> void:
	var head_att := _get_or_create_bone_att("head_014")
	var fiery_orange := Color(1.0, 0.22, 0.02)
	_create_ocular_eye(head_att, Vector3(0.12, -0.28, 0.28), fiery_orange, 0.04)

	# Реакторное ядро бомбы прямо в груди
	var chest_att := _get_or_create_bone_att("chest_017")
	var bomb_core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	bomb_core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = fiery_orange
	core_mat.emission_enabled = true
	core_mat.emission = fiery_orange
	core_mat.emission_energy_multiplier = 6.0
	bomb_core.material_override = core_mat
	bomb_core.position = Vector3(0.05, 0.0, 0.52)
	chest_att.add_child(bomb_core)
	_add_light(bomb_core, fiery_orange, 2.0, 3.2)

	# Защитная решетка вокруг бомбы
	var cage := MeshInstance3D.new()
	var cage_box := BoxMesh.new()
	cage_box.size = Vector3(0.42, 0.42, 0.12)
	cage.mesh = cage_box
	cage.material_override = _mat_rust_metal
	cage.position = Vector3(0.05, 0.0, 0.6)
	chest_att.add_child(cage)

# --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ СОЗДАНИЯ ---
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

	# 1. Смерть (высший приоритет): фиксирует труп намертво без дерганий
	if is_dead:
		if not has_died:
			has_died = true
			death_timer = 0.0
			# Моментально гасим все кибернетические огни
			for light in eye_lights:
				if is_instance_valid(light):
					light.light_energy = 0.0
			anim_player.play("death", 0.1)
			return

		# Если уже умер — отслеживаем завершение анимации и намертво замораживаем
		death_timer += _delta
		if death_timer >= 2.95 or not anim_player.is_playing() or anim_player.current_animation != "death":
			anim_player.pause()
			if anim_player.has_animation("death"):
				anim_player.seek(anim_player.get_animation("death").length, true)
		return

	# Если труп — не давать проигрывать другие анимации
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
