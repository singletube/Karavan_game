extends Node3D

class_name ChainsawModel3D

# --- Материалы ---
var mat_orange: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_chain: StandardMaterial3D
var mat_chrome: StandardMaterial3D

var blade_root: Node3D
var chain_teeth: Array[MeshInstance3D] = []
var is_active: bool = false
var anim_time: float = 0.0

@onready var attack_point: Marker3D = $AttackPoint
@onready var muzzle_flash_spawner: Marker3D = $MuzzleFlashSpawner

func _init() -> void:
	_init_materials()

func _ready() -> void:
	_build_chainsaw()

func _init_materials() -> void:
	mat_orange = StandardMaterial3D.new()
	mat_orange.albedo_color = Color(0.95, 0.36, 0.05, 1.0) # Классический оранжевый цвет Stihl / Husqvarna
	mat_orange.roughness = 0.45

	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.14, 0.14, 0.16, 1.0)
	mat_dark.roughness = 0.7

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.72, 0.74, 0.78, 1.0)
	mat_steel.metallic = 0.8
	mat_steel.roughness = 0.3

	mat_chain = StandardMaterial3D.new()
	mat_chain.albedo_color = Color(0.35, 0.35, 0.38, 1.0)
	mat_chain.metallic = 0.9
	mat_chain.roughness = 0.35

	mat_chrome = StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.88, 0.92, 1.0)
	mat_chrome.metallic = 0.95
	mat_chrome.roughness = 0.2

func _create_box(parent: Node, size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = 2 # Слой отображения оружия от первого лица
	parent.add_child(mi)
	return mi

func _create_cylinder(parent: Node, radius: float, height: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.layers = 2
	parent.add_child(mi)
	return mi

func _build_chainsaw() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	# 1. Основной моторный отсек (оранжевый корпус)
	_create_box(body, Vector3(0.18, 0.22, 0.32), mat_orange, Vector3(0.0, 0.0, 0.0))
	# Черная верхняя крышка воздушного фильтра
	_create_box(body, Vector3(0.15, 0.08, 0.22), mat_dark, Vector3(0.0, 0.14, 0.04))
	# Стартер сбоку (круглая крышка с тросиком)
	_create_cylinder(body, 0.07, 0.04, mat_dark, Vector3(-0.11, 0.01, 0.02), Vector3(0.0, 0.0, PI * 0.5))
	# Выхлопное сопло спереди справа
	_create_box(body, Vector3(0.06, 0.08, 0.08), mat_steel, Vector3(0.10, -0.04, -0.16))

	# 2. Рукоятки
	# Задняя рукоятка управления с кнопкой газа
	_create_box(body, Vector3(0.06, 0.16, 0.24), mat_dark, Vector3(0.0, -0.04, 0.26))
	_create_box(body, Vector3(0.05, 0.04, 0.12), mat_orange, Vector3(0.0, 0.05, 0.25)) # Спусковой курок
	# Передняя верхняя дуговая рукоятка (металлическая труба)
	_create_cylinder(body, 0.018, 0.24, mat_chrome, Vector3(0.0, 0.18, -0.04), Vector3(0.0, 0.0, PI * 0.5))
	_create_cylinder(body, 0.018, 0.20, mat_chrome, Vector3(-0.12, 0.08, -0.04), Vector3(0.0, 0.0, 0.0))
	# Щиток тормоза цепи перед верхней рукояткой
	_create_box(body, Vector3(0.16, 0.12, 0.02), mat_dark, Vector3(0.0, 0.17, -0.12), Vector3(deg_to_rad(-18.0), 0.0, 0.0))

	# 3. Пильная шина (Blade / Guide Bar)
	blade_root = Node3D.new()
	blade_root.name = "Blade"
	blade_root.position = Vector3(0.0, -0.02, -0.18)
	body.add_child(blade_root)

	# Стальное полотно шины (длина 0.62м, высота 0.12м, толщина 0.02м)
	_create_box(blade_root, Vector3(0.022, 0.12, 0.62), mat_steel, Vector3(0.0, 0.0, -0.31))
	# Закругленный наконечник шины
	_create_cylinder(blade_root, 0.058, 0.024, mat_steel, Vector3(0.0, 0.0, -0.62), Vector3(0.0, 0.0, PI * 0.5))
	# Центральная продольная гравировка на полотне
	_create_box(blade_root, Vector3(0.026, 0.05, 0.45), mat_dark, Vector3(0.0, 0.0, -0.30))

	# Зубья цепи (множество острых зубьев по периметру шины)
	for i in range(12):
		var z_pos: float = -0.06 - (float(i) * 0.048)
		# Верхние зубья
		var t_top := _create_box(blade_root, Vector3(0.028, 0.024, 0.032), mat_chain, Vector3(0.0, 0.068, z_pos), Vector3(deg_to_rad(20.0), 0.0, 0.0))
		chain_teeth.append(t_top)
		# Нижние зубья
		var t_bot := _create_box(blade_root, Vector3(0.028, 0.024, 0.032), mat_chain, Vector3(0.0, -0.068, z_pos), Vector3(deg_to_rad(-20.0), 0.0, 0.0))
		chain_teeth.append(t_bot)

	# Передние огибающие зубья на наконечнике
	for a in range(5):
		var ang: float = -PI * 0.5 + float(a) * (PI / 4.0)
		var t_tip := _create_box(blade_root, Vector3(0.028, 0.022, 0.030), mat_chain, 
			Vector3(0.0, sin(ang) * 0.068, -0.62 - cos(ang) * 0.068), 
			Vector3(ang, 0.0, 0.0))
		chain_teeth.append(t_tip)

	# 4. Точки атаки и эффектов
	if not attack_point:
		attack_point = Marker3D.new()
		attack_point.name = "AttackPoint"
		add_child(attack_point)
	attack_point.position = Vector3(0.0, -0.02, -0.85)

	if not muzzle_flash_spawner:
		muzzle_flash_spawner = Marker3D.new()
		muzzle_flash_spawner.name = "MuzzleFlashSpawner"
		add_child(muzzle_flash_spawner)
	muzzle_flash_spawner.position = Vector3(0.0, -0.02, -0.75)

func _process(delta: float) -> void:
	anim_time += delta
	# Анимация бега зубьев цепи (эффект бешеного вращения цепи)
	var speed: float = 35.0 if is_active else 8.0
	for i in range(chain_teeth.size()):
		var t := chain_teeth[i]
		if is_instance_valid(t):
			t.position.z += sin(anim_time * speed + float(i)) * 0.003

	# Вибрация мотора в руках
	if is_active:
		position.x = sin(anim_time * 65.0) * 0.004
		position.y = cos(anim_time * 55.0) * 0.005
		rotation.z = sin(anim_time * 45.0) * deg_to_rad(1.2)
	else:
		position.x = sin(anim_time * 20.0) * 0.001
		position.y = cos(anim_time * 18.0) * 0.001
		rotation.z = 0.0

func set_sawing(active: bool) -> void:
	is_active = active
