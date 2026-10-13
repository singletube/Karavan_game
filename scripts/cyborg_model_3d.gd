extends Node3D

# --- Перечисление типов для фабрики 3D моделей ---
var current_type: String = "Walker"

# --- Материалы PBR ---
var mat_flesh     : StandardMaterial3D
var mat_steel     : StandardMaterial3D
var mat_dark      : StandardMaterial3D
var mat_eye_red   : StandardMaterial3D
var mat_eye_green : StandardMaterial3D
var mat_eye_cyan  : StandardMaterial3D
var mat_bone      : StandardMaterial3D
var mat_blade     : StandardMaterial3D
var mat_hazard    : StandardMaterial3D
var mat_acid      : StandardMaterial3D
var mat_plasma    : StandardMaterial3D

# --- Иерархия суставов (универсальный риг) ---
var root_node      : Node3D
var pelvis         : Node3D
var torso          : Node3D
var chest          : Node3D
var head           : Node3D
var special_fx     : Node3D # свет, плазма, кислота

var l_hip          : Node3D
var l_knee         : Node3D
var r_hip          : Node3D
var r_knee         : Node3D

var l_shoulder     : Node3D
var l_elbow        : Node3D
var r_shoulder     : Node3D
var r_elbow        : Node3D

# Дополнительные конечности (для паука-ползуна Crawler)
var extra_limbs    : Array[Node3D] = []

# --- Анимационное состояние ---
var anim_time      : float = 0.0
var walk_speed_mult: float = 1.0
var is_moving      : bool = false
var is_attacking   : bool = false
var is_hurt        : bool = false
var is_dead        : bool = false

var attack_progress: float = 0.0
var hurt_progress  : float = 0.0
var death_progress : float = 0.0

func _ready() -> void:
	_init_materials()

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()
	_init_materials()
	match type_name:
		"Runner":
			_build_runner()
		"Brute":
			_build_brute()
		"Crawler":
			_build_crawler()
		"Spitter":
			_build_spitter()
		"Screamer":
			_build_screamer()
		"Exploder":
			_build_exploder()
		_:
			_build_walker()

func _clear_model() -> void:
	for c in get_children():
		c.queue_free()
	extra_limbs.clear()
	anim_time = 0.0
	attack_progress = 0.0
	hurt_progress = 0.0
	death_progress = 0.0

func _init_materials() -> void:
	if mat_flesh != null:
		return

	# Гниющая багровая плоть
	mat_flesh = StandardMaterial3D.new()
	mat_flesh.albedo_color = Color(0.38, 0.22, 0.24)
	mat_flesh.roughness = 0.75

	# Вороненый оружейный металл
	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.30, 0.32, 0.36)
	mat_steel.metallic = 0.90
	mat_steel.roughness = 0.35

	# Карбоновый черный сплав
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.12, 0.13, 0.15)
	mat_dark.metallic = 0.70
	mat_dark.roughness = 0.50

	# Алый кибер-глаз
	mat_eye_red = StandardMaterial3D.new()
	mat_eye_red.albedo_color = Color(1.0, 0.1, 0.05)
	mat_eye_red.emission_enabled = true
	mat_eye_red.emission = Color(1.0, 0.15, 0.05)
	mat_eye_red.emission_energy_multiplier = 4.0

	# Зеленый кислотный сканер
	mat_eye_green = StandardMaterial3D.new()
	mat_eye_green.albedo_color = Color(0.1, 1.0, 0.2)
	mat_eye_green.emission_enabled = true
	mat_eye_green.emission = Color(0.15, 1.0, 0.25)
	mat_eye_green.emission_energy_multiplier = 4.0

	# Синий неон
	mat_eye_cyan = StandardMaterial3D.new()
	mat_eye_cyan.albedo_color = Color(0.1, 0.8, 1.0)
	mat_eye_cyan.emission_enabled = true
	mat_eye_cyan.emission = Color(0.15, 0.85, 1.0)
	mat_eye_cyan.emission_energy_multiplier = 4.0

	# Кость / череп
	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color(0.78, 0.74, 0.65)
	mat_bone.roughness = 0.65

	# Острое хромированное лезвие
	mat_blade = StandardMaterial3D.new()
	mat_blade.albedo_color = Color(0.85, 0.88, 0.92)
	mat_blade.metallic = 0.95
	mat_blade.roughness = 0.15

	# Предупреждающая желтая окраска (Hazard)
	mat_hazard = StandardMaterial3D.new()
	mat_hazard.albedo_color = Color(0.95, 0.75, 0.1)
	mat_hazard.roughness = 0.4

	# Токсичная кислота
	mat_acid = StandardMaterial3D.new()
	mat_acid.albedo_color = Color(0.2, 0.95, 0.1)
	mat_acid.emission_enabled = true
	mat_acid.emission = Color(0.2, 0.95, 0.1)
	mat_acid.emission_energy_multiplier = 2.5

	# Термоядерная плазма
	mat_plasma = StandardMaterial3D.new()
	mat_plasma.albedo_color = Color(1.0, 0.5, 0.05)
	mat_plasma.emission_enabled = true
	mat_plasma.emission = Color(1.0, 0.55, 0.1)
	mat_plasma.emission_energy_multiplier = 5.0

func _create_box(parent: Node, sz: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _create_cylinder(parent: Node, r: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _create_sphere(parent: Node, r: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	mi.mesh = sph
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _init_base_rig() -> void:
	root_node = Node3D.new()
	root_node.name = "Root"
	add_child(root_node)

	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	root_node.add_child(pelvis)

	torso = Node3D.new()
	torso.name = "Torso"
	pelvis.add_child(torso)

	chest = Node3D.new()
	chest.name = "Chest"
	torso.add_child(chest)

	head = Node3D.new()
	head.name = "Head"
	chest.add_child(head)

	l_shoulder = Node3D.new()
	l_shoulder.name = "L_Shoulder"
	chest.add_child(l_shoulder)

	l_elbow = Node3D.new()
	l_elbow.name = "L_Elbow"
	l_shoulder.add_child(l_elbow)

	r_shoulder = Node3D.new()
	r_shoulder.name = "R_Shoulder"
	chest.add_child(r_shoulder)

	r_elbow = Node3D.new()
	r_elbow.name = "R_Elbow"
	r_shoulder.add_child(r_elbow)

	l_hip = Node3D.new()
	l_hip.name = "L_Hip"
	pelvis.add_child(l_hip)

	l_knee = Node3D.new()
	l_knee.name = "L_Knee"
	l_hip.add_child(l_knee)

	r_hip = Node3D.new()
	r_hip.name = "R_Hip"
	pelvis.add_child(r_hip)

	r_knee = Node3D.new()
	r_knee.name = "R_Knee"
	r_hip.add_child(r_knee)

# =========================================================================
# 1. ШТУРМОВОЙ КИБОРГ-ХОДОК (WALKER)
# =========================================================================
func _build_walker() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.82, 0.0)
	_create_box(pelvis, Vector3(0.36, 0.16, 0.24), mat_dark)

	torso.position = Vector3(0.0, 0.12, 0.0)
	_create_cylinder(torso, 0.07, 0.28, mat_steel, Vector3(0.0, 0.14, -0.02))

	chest.position = Vector3(0.0, 0.28, 0.0)
	_create_box(chest, Vector3(0.48, 0.36, 0.28), mat_dark, Vector3(0.0, 0.16, 0.0))
	_create_box(chest, Vector3(0.24, 0.32, 0.30), mat_steel, Vector3(-0.11, 0.17, 0.01))
	_create_box(chest, Vector3(0.20, 0.28, 0.29), mat_flesh, Vector3(0.12, 0.16, 0.01))

	head.position = Vector3(0.0, 0.38, 0.0)
	_create_box(head, Vector3(0.24, 0.26, 0.24), mat_bone, Vector3(0.0, 0.13, 0.0))
	_create_box(head, Vector3(0.13, 0.14, 0.25), mat_steel, Vector3(-0.06, 0.18, 0.01))
	_create_box(head, Vector3(0.20, 0.09, 0.20), mat_dark, Vector3(0.0, 0.03, 0.04))

	var eye: MeshInstance3D = _create_cylinder(head, 0.035, 0.06, mat_eye_red, Vector3(-0.06, 0.14, 0.12))
	eye.rotation.x = deg_to_rad(90.0)

	l_shoulder.position = Vector3(-0.30, 0.28, 0.0)
	_create_cylinder(l_shoulder, 0.06, 0.24, mat_steel, Vector3(0.0, -0.12, 0.0))
	l_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_cylinder(l_elbow, 0.05, 0.24, mat_dark, Vector3(0.0, -0.12, 0.0))
	_create_box(l_elbow, Vector3(0.04, 0.45, 0.10), mat_blade, Vector3(0.0, -0.38, 0.04))

	r_shoulder.position = Vector3(0.30, 0.28, 0.0)
	_create_cylinder(r_shoulder, 0.065, 0.24, mat_flesh, Vector3(0.0, -0.12, 0.0))
	r_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_cylinder(r_elbow, 0.055, 0.24, mat_flesh, Vector3(0.0, -0.12, 0.0))
	for c_i in range(3):
		_create_box(r_elbow, Vector3(0.02, 0.16, 0.03), mat_steel, Vector3(-0.04 + c_i * 0.04, -0.30, 0.03))

	l_hip.position = Vector3(-0.14, -0.06, 0.0)
	_create_cylinder(l_hip, 0.06, 0.36, mat_steel, Vector3(0.0, -0.18, 0.0))
	l_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(l_knee, 0.05, 0.38, mat_dark, Vector3(0.0, -0.19, 0.0))
	_create_box(l_knee, Vector3(0.12, 0.08, 0.24), mat_steel, Vector3(0.0, -0.38, 0.06))

	r_hip.position = Vector3(0.14, -0.06, 0.0)
	_create_cylinder(r_hip, 0.065, 0.36, mat_flesh, Vector3(0.0, -0.18, 0.0))
	r_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(r_knee, 0.055, 0.38, mat_flesh, Vector3(0.0, -0.19, 0.0))
	_create_box(r_knee, Vector3(0.12, 0.08, 0.22), mat_dark, Vector3(0.0, -0.38, 0.05))

# =========================================================================
# 2. КИБЕР-ГУЛЬ СПРИНТЕР (RUNNER)
# =========================================================================
func _build_runner() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.78, 0.0)
	_create_box(pelvis, Vector3(0.26, 0.12, 0.18), mat_dark)

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_cylinder(torso, 0.045, 0.32, mat_steel, Vector3(0.0, 0.16, 0.0))

	chest.position = Vector3(0.0, 0.32, 0.0)
	_create_box(chest, Vector3(0.34, 0.30, 0.20), mat_dark, Vector3(0.0, 0.14, 0.0))

	head.position = Vector3(0.0, 0.34, 0.06) # Вытянута вперед
	_create_box(head, Vector3(0.18, 0.20, 0.22), mat_steel, Vector3(0.0, 0.10, 0.0))
	# Тройной визор ночного видения
	_create_sphere(head, 0.03, mat_eye_red, Vector3(-0.05, 0.12, 0.11))
	_create_sphere(head, 0.03, mat_eye_red, Vector3(0.05, 0.12, 0.11))
	_create_sphere(head, 0.025, mat_eye_red, Vector3(0.0, 0.16, 0.11))

	# Тонкие скоростные руки с бритвенными вибро-лезвиями
	l_shoulder.position = Vector3(-0.22, 0.24, 0.0)
	_create_cylinder(l_shoulder, 0.04, 0.26, mat_steel, Vector3(0.0, -0.13, 0.0))
	l_elbow.position = Vector3(0.0, -0.26, 0.0)
	_create_cylinder(l_elbow, 0.035, 0.26, mat_dark, Vector3(0.0, -0.13, 0.0))
	_create_box(l_elbow, Vector3(0.02, 0.35, 0.05), mat_blade, Vector3(0.0, -0.36, 0.02))

	r_shoulder.position = Vector3(0.22, 0.24, 0.0)
	_create_cylinder(r_shoulder, 0.04, 0.26, mat_steel, Vector3(0.0, -0.13, 0.0))
	r_elbow.position = Vector3(0.0, -0.26, 0.0)
	_create_cylinder(r_elbow, 0.035, 0.26, mat_dark, Vector3(0.0, -0.13, 0.0))
	_create_box(r_elbow, Vector3(0.02, 0.35, 0.05), mat_blade, Vector3(0.0, -0.36, 0.02))

	# Ноги — закругленные изогнутые спринтерские лезвия (Blade runner)
	l_hip.position = Vector3(-0.11, -0.05, 0.0)
	_create_cylinder(l_hip, 0.045, 0.36, mat_dark, Vector3(0.0, -0.18, 0.0))
	l_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(l_knee, 0.035, 0.40, mat_steel, Vector3(0.0, -0.20, -0.04))
	_create_box(l_knee, Vector3(0.06, 0.05, 0.26), mat_blade, Vector3(0.0, -0.42, 0.08))

	r_hip.position = Vector3(0.11, -0.05, 0.0)
	_create_cylinder(r_hip, 0.045, 0.36, mat_dark, Vector3(0.0, -0.18, 0.0))
	r_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(r_knee, 0.035, 0.40, mat_steel, Vector3(0.0, -0.20, -0.04))
	_create_box(r_knee, Vector3(0.06, 0.05, 0.26), mat_blade, Vector3(0.0, -0.42, 0.08))

# =========================================================================
# 3. БРОНИРОВАННЫЙ ТАНК-ДЖАГГЕРНАУТ (BRUTE)
# =========================================================================
func _build_brute() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.95, 0.0)
	_create_box(pelvis, Vector3(0.65, 0.30, 0.45), mat_dark)

	torso.position = Vector3(0.0, 0.20, 0.0)
	_create_box(torso, Vector3(0.70, 0.40, 0.50), mat_steel, Vector3(0.0, 0.20, 0.0))

	chest.position = Vector3(0.0, 0.40, 0.0)
	# Массивная наклонная бронеплита с предупреждающей полосой
	_create_box(chest, Vector3(0.95, 0.60, 0.55), mat_steel, Vector3(0.0, 0.28, 0.0))
	_create_box(chest, Vector3(0.85, 0.12, 0.58), mat_hazard, Vector3(0.0, 0.16, 0.01))
	# Выхлопные трубы за спиной
	_create_cylinder(chest, 0.07, 0.55, mat_dark, Vector3(-0.30, 0.55, -0.25))
	_create_cylinder(chest, 0.07, 0.55, mat_dark, Vector3(0.30, 0.55, -0.25))

	head.position = Vector3(0.0, 0.52, 0.08)
	_create_box(head, Vector3(0.38, 0.35, 0.38), mat_dark, Vector3(0.0, 0.15, 0.0))
	# Горизонтальная узкая амбразура со светящимся алым визором
	_create_box(head, Vector3(0.28, 0.05, 0.06), mat_eye_red, Vector3(0.0, 0.16, 0.19))

	# Левая рука: ПНЕВМАТИЧЕСКИЙ ОТБОЙНЫЙ МОЛОТ / БУР
	l_shoulder.position = Vector3(-0.58, 0.45, 0.0)
	_create_cylinder(l_shoulder, 0.14, 0.35, mat_dark, Vector3(0.0, -0.17, 0.0))
	l_elbow.position = Vector3(0.0, -0.35, 0.0)
	_create_box(l_elbow, Vector3(0.28, 0.50, 0.28), mat_steel, Vector3(0.0, -0.25, 0.0))
	# Заостренный бур
	_create_cylinder(l_elbow, 0.09, 0.45, mat_blade, Vector3(0.0, -0.65, 0.0))

	# Правая рука: ГИДРАВЛИЧЕСКИЙ ЗАХВАТ-КЛЕЩНЯ
	r_shoulder.position = Vector3(0.58, 0.45, 0.0)
	_create_cylinder(r_shoulder, 0.14, 0.35, mat_dark, Vector3(0.0, -0.17, 0.0))
	r_elbow.position = Vector3(0.0, -0.35, 0.0)
	_create_cylinder(r_elbow, 0.12, 0.35, mat_steel, Vector3(0.0, -0.18, 0.0))
	_create_box(r_elbow, Vector3(0.08, 0.35, 0.12), mat_steel, Vector3(-0.08, -0.50, 0.0))
	_create_box(r_elbow, Vector3(0.08, 0.35, 0.12), mat_steel, Vector3(0.08, -0.50, 0.0))

	# Толстые колонноподобные гидравлические ноги
	l_hip.position = Vector3(-0.25, -0.10, 0.0)
	_create_cylinder(l_hip, 0.14, 0.45, mat_dark, Vector3(0.0, -0.22, 0.0))
	l_knee.position = Vector3(0.0, -0.45, 0.0)
	_create_cylinder(l_knee, 0.13, 0.45, mat_steel, Vector3(0.0, -0.22, 0.0))
	_create_box(l_knee, Vector3(0.30, 0.16, 0.42), mat_dark, Vector3(0.0, -0.46, 0.08))

	r_hip.position = Vector3(0.25, -0.10, 0.0)
	_create_cylinder(r_hip, 0.14, 0.45, mat_dark, Vector3(0.0, -0.22, 0.0))
	r_knee.position = Vector3(0.0, -0.45, 0.0)
	_create_cylinder(r_knee, 0.13, 0.45, mat_steel, Vector3(0.0, -0.22, 0.0))
	_create_box(r_knee, Vector3(0.30, 0.16, 0.42), mat_dark, Vector3(0.0, -0.46, 0.08))

# =========================================================================
# 4. КИБЕР-ПАУК ПОЛЗУН (CRAWLER)
# =========================================================================
func _build_crawler() -> void:
	_init_base_rig()
	# Низкая посадка на гусеничном шасси
	pelvis.position = Vector3(0.0, 0.32, 0.0)
	# Гусеничный танковый модуль шасси
	_create_box(pelvis, Vector3(0.70, 0.28, 0.85), mat_dark)
	_create_box(pelvis, Vector3(0.18, 0.24, 0.90), mat_steel, Vector3(-0.30, -0.04, 0.0))
	_create_box(pelvis, Vector3(0.18, 0.24, 0.90), mat_steel, Vector3(0.30, -0.04, 0.0))

	torso.position = Vector3(0.0, 0.18, -0.10)
	_create_box(torso, Vector3(0.48, 0.28, 0.38), mat_steel, Vector3(0.0, 0.14, 0.0))

	chest.position = Vector3(0.0, 0.26, 0.08)
	_create_box(chest, Vector3(0.52, 0.30, 0.36), mat_flesh, Vector3(0.0, 0.15, 0.0))

	head.position = Vector3(0.0, 0.30, 0.18)
	_create_box(head, Vector3(0.26, 0.22, 0.24), mat_bone, Vector3(0.0, 0.10, 0.0))
	# Мульти-глазный зеленый кластер
	_create_sphere(head, 0.035, mat_eye_green, Vector3(-0.06, 0.14, 0.12))
	_create_sphere(head, 0.025, mat_eye_green, Vector3(-0.02, 0.17, 0.12))
	_create_sphere(head, 0.030, mat_eye_green, Vector3(-0.08, 0.09, 0.12))
	# Челюсти-клешни
	_create_box(head, Vector3(0.03, 0.16, 0.04), mat_blade, Vector3(-0.08, -0.02, 0.14))
	_create_box(head, Vector3(0.03, 0.16, 0.04), mat_blade, Vector3(0.08, -0.02, 0.14))

	# Массивные экскаваторные передние гидро-клешни
	l_shoulder.position = Vector3(-0.35, 0.22, 0.10)
	_create_cylinder(l_shoulder, 0.08, 0.42, mat_steel, Vector3(-0.15, -0.10, 0.15))
	l_elbow.position = Vector3(-0.25, -0.22, 0.25)
	_create_cylinder(l_elbow, 0.06, 0.45, mat_dark, Vector3(0.0, -0.20, 0.10))
	_create_box(l_elbow, Vector3(0.08, 0.30, 0.18), mat_blade, Vector3(0.0, -0.45, 0.20))

	r_shoulder.position = Vector3(0.35, 0.22, 0.10)
	_create_cylinder(r_shoulder, 0.08, 0.42, mat_steel, Vector3(0.15, -0.10, 0.15))
	r_elbow.position = Vector3(0.25, -0.22, 0.25)
	_create_cylinder(r_elbow, 0.06, 0.45, mat_dark, Vector3(0.0, -0.20, 0.10))
	_create_box(r_elbow, Vector3(0.08, 0.30, 0.18), mat_blade, Vector3(0.0, -0.45, 0.20))

# =========================================================================
# 5. ХИМИЧЕСКИЙ ОГНЕМЕТЧИК/КИСЛОТОМЕТ (SPITTER)
# =========================================================================
func _build_spitter() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.80, 0.0)
	_create_box(pelvis, Vector3(0.40, 0.18, 0.32), mat_dark)

	torso.position = Vector3(0.0, 0.14, 0.0)
	_create_box(torso, Vector3(0.44, 0.32, 0.36), mat_flesh, Vector3(0.0, 0.16, 0.0))

	chest.position = Vector3(0.0, 0.30, 0.0)
	_create_box(chest, Vector3(0.50, 0.38, 0.38), mat_dark, Vector3(0.0, 0.18, 0.0))
	# Двойные светящиеся баллоны с токсичной зеленой кислотой за спиной
	_create_cylinder(chest, 0.09, 0.50, mat_acid, Vector3(-0.16, 0.35, -0.24))
	_create_cylinder(chest, 0.09, 0.50, mat_acid, Vector3(0.16, 0.35, -0.24))
	_create_cylinder(chest, 0.11, 0.12, mat_steel, Vector3(-0.16, 0.58, -0.24))
	_create_cylinder(chest, 0.11, 0.12, mat_steel, Vector3(0.16, 0.58, -0.24))

	head.position = Vector3(0.0, 0.40, 0.05)
	_create_box(head, Vector3(0.24, 0.26, 0.26), mat_steel, Vector3(0.0, 0.12, 0.0))
	# Круглые зеленые линзы противогаза
	_create_cylinder(head, 0.045, 0.05, mat_eye_green, Vector3(-0.06, 0.14, 0.14)).rotation.x = deg_to_rad(90.0)
	_create_cylinder(head, 0.045, 0.05, mat_eye_green, Vector3(0.06, 0.14, 0.14)).rotation.x = deg_to_rad(90.0)
	# Распылительное сопло на челюсти
	_create_cylinder(head, 0.05, 0.14, mat_dark, Vector3(0.0, 0.02, 0.18)).rotation.x = deg_to_rad(90.0)

	l_shoulder.position = Vector3(-0.30, 0.26, 0.0)
	_create_cylinder(l_shoulder, 0.06, 0.26, mat_flesh, Vector3(0.0, -0.13, 0.0))
	l_elbow.position = Vector3(0.0, -0.26, 0.0)
	_create_cylinder(l_elbow, 0.05, 0.26, mat_steel, Vector3(0.0, -0.13, 0.0))

	r_shoulder.position = Vector3(0.30, 0.26, 0.0)
	_create_cylinder(r_shoulder, 0.06, 0.26, mat_flesh, Vector3(0.0, -0.13, 0.0))
	r_elbow.position = Vector3(0.0, -0.26, 0.0)
	_create_cylinder(r_elbow, 0.05, 0.26, mat_steel, Vector3(0.0, -0.13, 0.0))

	l_hip.position = Vector3(-0.15, -0.06, 0.0)
	_create_cylinder(l_hip, 0.065, 0.36, mat_dark, Vector3(0.0, -0.18, 0.0))
	l_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(l_knee, 0.055, 0.38, mat_steel, Vector3(0.0, -0.19, 0.0))

	r_hip.position = Vector3(0.15, -0.06, 0.0)
	_create_cylinder(r_hip, 0.065, 0.36, mat_dark, Vector3(0.0, -0.18, 0.0))
	r_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(r_knee, 0.055, 0.38, mat_steel, Vector3(0.0, -0.19, 0.0))

# =========================================================================
# 6. АКУСТИЧЕСКАЯ СИРЕНА (SCREAMER)
# =========================================================================
func _build_screamer() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.90, 0.0)
	_create_box(pelvis, Vector3(0.24, 0.12, 0.18), mat_dark)

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_cylinder(torso, 0.04, 0.40, mat_blade, Vector3(0.0, 0.20, 0.0))

	chest.position = Vector3(0.0, 0.40, 0.0)
	_create_box(chest, Vector3(0.32, 0.32, 0.22), mat_dark, Vector3(0.0, 0.16, 0.0))

	# Голова: ГИГАНТСКИЙ ПАРАБОЛИЧЕСКИЙ АКУСТИЧЕСКИЙ РУПОР
	head.position = Vector3(0.0, 0.42, 0.0)
	var horn: MeshInstance3D = _create_cylinder(head, 0.22, 0.25, mat_dark, Vector3(0.0, 0.15, 0.08))
	horn.rotation.x = deg_to_rad(90.0)
	var inner_cone: MeshInstance3D = _create_cylinder(head, 0.16, 0.20, mat_eye_cyan, Vector3(0.0, 0.15, 0.14))
	inner_cone.rotation.x = deg_to_rad(90.0)

	# Длинные тонкие руки-антенны
	l_shoulder.position = Vector3(-0.20, 0.26, 0.0)
	_create_cylinder(l_shoulder, 0.035, 0.35, mat_blade, Vector3(0.0, -0.17, 0.0))
	l_elbow.position = Vector3(0.0, -0.35, 0.0)
	_create_cylinder(l_elbow, 0.025, 0.38, mat_steel, Vector3(0.0, -0.19, 0.0))

	r_shoulder.position = Vector3(0.20, 0.26, 0.0)
	_create_cylinder(r_shoulder, 0.035, 0.35, mat_blade, Vector3(0.0, -0.17, 0.0))
	r_elbow.position = Vector3(0.0, -0.35, 0.0)
	_create_cylinder(r_elbow, 0.025, 0.38, mat_steel, Vector3(0.0, -0.19, 0.0))

	l_hip.position = Vector3(-0.09, -0.05, 0.0)
	_create_cylinder(l_hip, 0.04, 0.45, mat_dark, Vector3(0.0, -0.22, 0.0))
	l_knee.position = Vector3(0.0, -0.45, 0.0)
	_create_cylinder(l_knee, 0.03, 0.45, mat_blade, Vector3(0.0, -0.22, 0.0))

	r_hip.position = Vector3(0.09, -0.05, 0.0)
	_create_cylinder(r_hip, 0.04, 0.45, mat_dark, Vector3(0.0, -0.22, 0.0))
	r_knee.position = Vector3(0.0, -0.45, 0.0)
	_create_cylinder(r_knee, 0.03, 0.45, mat_blade, Vector3(0.0, -0.22, 0.0))

# =========================================================================
# 7. ТЕРМОЯДЕРНЫЙ ДРОИД-КАМИКАДЗЕ (EXPLODER)
# =========================================================================
func _build_exploder() -> void:
	_init_base_rig()
	# Огромная сферическая бронекапсула на ножках
	pelvis.position = Vector3(0.0, 0.70, 0.0)
	_create_sphere(pelvis, 0.52, mat_dark, Vector3(0.0, 0.15, 0.0))
	_create_sphere(pelvis, 0.35, mat_plasma, Vector3(0.0, 0.18, 0.22))
	# Стальные обода и полосы опасности
	_create_box(pelvis, Vector3(1.10, 0.08, 1.10), mat_hazard, Vector3(0.0, 0.15, 0.0))

	# Маячок на макушке
	head.position = Vector3(0.0, 0.70, 0.0)
	_create_cylinder(head, 0.08, 0.12, mat_dark, Vector3(0.0, 0.06, 0.0))
	_create_cylinder(head, 0.06, 0.15, mat_eye_red, Vector3(0.0, 0.18, 0.0))

	# 4 поршневые устойчивые ноги
	l_hip.position = Vector3(-0.35, 0.0, 0.20)
	_create_cylinder(l_hip, 0.07, 0.35, mat_steel, Vector3(0.0, -0.17, 0.0))
	l_knee.position = Vector3(0.0, -0.35, 0.0)
	_create_cylinder(l_knee, 0.06, 0.35, mat_dark, Vector3(0.0, -0.17, 0.0))

	r_hip.position = Vector3(0.35, 0.0, 0.20)
	_create_cylinder(r_hip, 0.07, 0.35, mat_steel, Vector3(0.0, -0.17, 0.0))
	r_knee.position = Vector3(0.0, -0.35, 0.0)
	_create_cylinder(r_knee, 0.06, 0.35, mat_dark, Vector3(0.0, -0.17, 0.0))

# =========================================================================
# УНИВЕРСАЛЬНАЯ ПРОЦЕДУРНАЯ АНИМАЦИЯ 3D КИБОРГОВ
# =========================================================================
func update_animation(delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	is_moving = moving
	walk_speed_mult = move_speed
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	if is_dead:
		_animate_death(delta)
		return

	if is_hurt:
		_animate_hurt(delta)
		return

	if is_moving:
		anim_time += delta * (walk_speed_mult * 2.2)
	else:
		anim_time = move_toward(anim_time, 0.0, delta * 3.0)

	var leg_angle : float = sin(anim_time) * 0.65
	var body_bob  : float = absf(cos(anim_time)) * 0.06
	var spine_yaw : float = sin(anim_time) * 0.15

	if current_type != "Crawler" and current_type != "Exploder":
		pelvis.position.y = lerpf(pelvis.position.y, (0.82 if current_type == "Walker" else (0.95 if current_type == "Brute" else 0.85)) - body_bob, delta * 10.0)
		torso.rotation.y = spine_yaw
		head.rotation.y = -spine_yaw * 0.5
		head.rotation.x = sin(anim_time * 2.0) * 0.08

		l_hip.rotation.x = leg_angle
		r_hip.rotation.x = -leg_angle
		l_knee.rotation.x = maxf(0.0, -leg_angle * 0.8)
		r_knee.rotation.x = maxf(0.0, leg_angle * 0.8)
	elif current_type == "Crawler":
		# Паук ползет: попеременное сгибание передних клешней
		l_shoulder.rotation.x = sin(anim_time) * 0.45
		r_shoulder.rotation.x = -sin(anim_time) * 0.45
		torso.rotation.y = sin(anim_time) * 0.20
	elif current_type == "Exploder":
		# Переваливающийся сферический бег
		pelvis.rotation.z = sin(anim_time) * 0.12
		l_hip.rotation.x = leg_angle * 0.7
		r_hip.rotation.x = -leg_angle * 0.7

	# Руки
	if is_attacking:
		_animate_attack(delta)
	else:
		attack_progress = 0.0
		if current_type == "Screamer":
			# Подняты вверх в агонии
			l_shoulder.rotation.x = deg_to_rad(-85.0) + sin(anim_time * 1.5) * 0.15
			l_shoulder.rotation.z = deg_to_rad(30.0)
			r_shoulder.rotation.x = deg_to_rad(-85.0) + sin(anim_time * 1.5) * 0.15
			r_shoulder.rotation.z = deg_to_rad(-30.0)
		elif current_type != "Crawler" and current_type != "Exploder":
			l_shoulder.rotation.x = deg_to_rad(-25.0) + sin(anim_time) * 0.30
			l_shoulder.rotation.z = deg_to_rad(12.0)
			l_elbow.rotation.x = deg_to_rad(-45.0)

			r_shoulder.rotation.x = deg_to_rad(-20.0) - sin(anim_time) * 0.30
			r_shoulder.rotation.z = deg_to_rad(-12.0)
			r_elbow.rotation.x = deg_to_rad(-35.0)

func _animate_attack(delta: float) -> void:
	attack_progress += delta * (6.0 if current_type == "Runner" else 4.0)
	var phase : float = fmod(attack_progress, TAU)

	if phase < PI:
		var t : float = phase / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(-110.0), t)
		l_elbow.rotation.x = deg_to_rad(-80.0)
		torso.rotation.y = deg_to_rad(20.0)
	else:
		var t : float = (phase - PI) / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(35.0), t * 1.5)
		l_elbow.rotation.x = deg_to_rad(-10.0)
		torso.rotation.y = deg_to_rad(-25.0)

func _animate_hurt(delta: float) -> void:
	hurt_progress += delta * 8.0
	chest.rotation.x = deg_to_rad(-22.0)
	head.rotation.x = deg_to_rad(-35.0)
	l_shoulder.rotation.x = deg_to_rad(15.0)
	r_shoulder.rotation.x = deg_to_rad(15.0)
	root_node.position.z = -0.08

func _animate_death(delta: float) -> void:
	death_progress = minf(1.0, death_progress + delta * 2.8)
	var t : float = death_progress

	# Труп валится навзничь на землю, оставаясь лежать сверху на песке
	var target_y : float = 0.28
	if current_type == "Brute":
		target_y = 0.45
	elif current_type == "Crawler":
		target_y = 0.18
	elif current_type == "Exploder":
		target_y = 0.35

	root_node.position.y = lerpf(root_node.position.y, target_y, t)
	root_node.rotation.x = lerp_angle(root_node.rotation.x, deg_to_rad(-85.0), t)
	l_hip.rotation.x = lerp_angle(l_hip.rotation.x, deg_to_rad(-10.0), t)
	r_hip.rotation.x = lerp_angle(r_hip.rotation.x, deg_to_rad(-10.0), t)
	l_knee.rotation.x = lerp_angle(l_knee.rotation.x, deg_to_rad(40.0), t)
	r_knee.rotation.x = lerp_angle(r_knee.rotation.x, deg_to_rad(25.0), t)
	l_shoulder.rotation.z = lerp_angle(l_shoulder.rotation.z, deg_to_rad(45.0), t)
	r_shoulder.rotation.z = lerp_angle(r_shoulder.rotation.z, deg_to_rad(-45.0), t)
	pelvis.rotation = pelvis.rotation.lerp(Vector3.ZERO, t)
	torso.rotation = torso.rotation.lerp(Vector3.ZERO, t)
