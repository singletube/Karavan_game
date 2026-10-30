extends Node3D

# =========================================================================
# ADVANCED ORGANIC & PROCEDURAL CYBORG ZOMBIE GENERATOR (FROM SCRATCH)
# Полный отказ от квадратных примитивов — гладкая анатомическая геометрия,
# процедурные PBR-текстуры (Normal Maps, Roughness, Albedo), дисковые пилы,
# гибкие шланги и светящаяся мутагенная жижа.
# =========================================================================

var current_type: String = "Walker"

# --- Высокодетализированные PBR Материалы с процедурными текстурами ---
var mat_mummy_flesh      : StandardMaterial3D # Высушенная кожа с глубокими складками и 3D нормалями
var mat_mummy_dark       : StandardMaterial3D # Обугленная сморщенная некротическая плоть
var mat_bone             : StandardMaterial3D # Сухая пожелтевшая кость
var mat_cyber_steel      : StandardMaterial3D # Шлифованный титан с царапинами и рельефом
var mat_cyber_dark       : StandardMaterial3D # Темный вороненый каркас сервоприводов
var mat_saw_disc         : StandardMaterial3D # Зеркальный стальной диск пилы
var mat_saw_teeth        : StandardMaterial3D # Зазубренные окровавленные стальные зубья
var mat_cable_black      : StandardMaterial3D # Ребристые черные шланги гидравлики
var mat_cable_yellow     : StandardMaterial3D # Предупреждающие кабели питания
var mat_hazard           : StandardMaterial3D # Желто-черные предупреждающие полосы
var mat_ooze_green       : StandardMaterial3D # Бурлящая кислотная жижа (Emission 5.0)
var mat_ooze_cyan        : StandardMaterial3D # Криогенный нейростимулятор (Emission 5.0)
var mat_ooze_plasma      : StandardMaterial3D # Термоядерная плазма (Emission 5.0)
var mat_eye_red          : StandardMaterial3D # Алый оптический сенсор / визор
var mat_canister_glass   : StandardMaterial3D # Стекло колб для жижи

# --- Иерархия суставов (универсальный риг) ---
var root_node      : Node3D
var pelvis         : Node3D
var torso          : Node3D
var chest          : Node3D
var head           : Node3D
var special_fx     : Node3D

var l_hip          : Node3D
var l_knee         : Node3D
var r_hip          : Node3D
var r_knee         : Node3D

var l_shoulder     : Node3D
var l_elbow        : Node3D
var r_shoulder     : Node3D
var r_elbow        : Node3D

var rotating_saws  : Array[Node3D] = []
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
	rotating_saws.clear()
	extra_limbs.clear()
	anim_time = 0.0
	attack_progress = 0.0
	hurt_progress = 0.0
	death_progress = 0.0

# =========================================================================
# ГЕНЕРАЦИЯ ПРОЦЕДУРНЫХ PBR-ТЕКСТУР И МАТЕРИАЛОВ
# =========================================================================
func _init_materials() -> void:
	if mat_mummy_flesh != null:
		return

	# 1. Текстура нормалей и складок высушенной мумифицированной кожи
	var noise_flesh := FastNoiseLite.new()
	noise_flesh.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_flesh.frequency = 0.09
	noise_flesh.fractal_octaves = 4

	var tex_flesh_normal := NoiseTexture2D.new()
	tex_flesh_normal.noise = noise_flesh
	tex_flesh_normal.as_normal_map = true
	tex_flesh_normal.bump_strength = 7.5
	tex_flesh_normal.width = 128
	tex_flesh_normal.height = 128

	var tex_flesh_albedo := NoiseTexture2D.new()
	tex_flesh_albedo.noise = noise_flesh
	tex_flesh_albedo.width = 128
	tex_flesh_albedo.height = 128

	# 2. Текстура шлифованного металла с царапинами
	var noise_metal := FastNoiseLite.new()
	noise_metal.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_metal.frequency = 0.15

	var tex_metal_normal := NoiseTexture2D.new()
	tex_metal_normal.noise = noise_metal
	tex_metal_normal.as_normal_map = true
	tex_metal_normal.bump_strength = 3.5
	tex_metal_normal.width = 128
	tex_metal_normal.height = 128

	# 3. Текстура бурлящей жижи
	var noise_ooze := FastNoiseLite.new()
	noise_ooze.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_ooze.frequency = 0.12

	var tex_ooze_noise := NoiseTexture2D.new()
	tex_ooze_noise.noise = noise_ooze
	tex_ooze_noise.width = 64
	tex_ooze_noise.height = 64

	# --- Инициализация PBR материалов ---

	# Высушенная пепельная кожа мумии с глубоким 3D-рельефом
	mat_mummy_flesh = StandardMaterial3D.new()
	mat_mummy_flesh.albedo_color = Color(0.32, 0.27, 0.23)
	mat_mummy_flesh.albedo_texture = tex_flesh_albedo
	mat_mummy_flesh.normal_enabled = true
	mat_mummy_flesh.normal_texture = tex_flesh_normal
	mat_mummy_flesh.roughness = 0.85

	# Обугленная сморщенная ткань
	mat_mummy_dark = StandardMaterial3D.new()
	mat_mummy_dark.albedo_color = Color(0.18, 0.14, 0.12)
	mat_mummy_dark.normal_enabled = true
	mat_mummy_dark.normal_texture = tex_flesh_normal
	mat_mummy_dark.roughness = 0.95

	# Высохшая кость
	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color(0.78, 0.74, 0.64)
	mat_bone.roughness = 0.65

	# Титановый сплав с царапинами и бликами
	mat_cyber_steel = StandardMaterial3D.new()
	mat_cyber_steel.albedo_color = Color(0.44, 0.46, 0.50)
	mat_cyber_steel.metallic = 0.95
	mat_cyber_steel.roughness = 0.22
	mat_cyber_steel.normal_enabled = true
	mat_cyber_steel.normal_texture = tex_metal_normal

	# Вороненый каркас сервоприводов
	mat_cyber_dark = StandardMaterial3D.new()
	mat_cyber_dark.albedo_color = Color(0.12, 0.13, 0.15)
	mat_cyber_dark.metallic = 0.85
	mat_cyber_dark.roughness = 0.45

	# Зеркальный стальной диск пилы
	mat_saw_disc = StandardMaterial3D.new()
	mat_saw_disc.albedo_color = Color(0.92, 0.94, 0.96)
	mat_saw_disc.metallic = 0.98
	mat_saw_disc.roughness = 0.10

	# Окровавленные зубья пилы
	mat_saw_teeth = StandardMaterial3D.new()
	mat_saw_teeth.albedo_color = Color(0.58, 0.18, 0.14)
	mat_saw_teeth.metallic = 0.75
	mat_saw_teeth.roughness = 0.40

	# Черные ребристые шланги гидравлики
	mat_cable_black = StandardMaterial3D.new()
	mat_cable_black.albedo_color = Color(0.05, 0.05, 0.06)
	mat_cable_black.roughness = 0.85

	# Желтый кабель питания
	mat_cable_yellow = StandardMaterial3D.new()
	mat_cable_yellow.albedo_color = Color(0.85, 0.70, 0.08)
	mat_cable_yellow.roughness = 0.50

	# Предупреждающая маркировка Hazard
	mat_hazard = StandardMaterial3D.new()
	mat_hazard.albedo_color = Color(0.92, 0.74, 0.06)
	mat_hazard.roughness = 0.35

	# Светящаяся едкая мутагенная жижа (кислотно-зеленый неон)
	mat_ooze_green = StandardMaterial3D.new()
	mat_ooze_green.albedo_color = Color(0.18, 0.98, 0.25)
	mat_ooze_green.emission_enabled = true
	mat_ooze_green.emission = Color(0.20, 1.0, 0.30)
	mat_ooze_green.emission_energy_multiplier = 5.0
	mat_ooze_green.emission_texture = tex_ooze_noise

	# Светящийся криогенный хладагент / нейростимулятор (бирюзовый)
	mat_ooze_cyan = StandardMaterial3D.new()
	mat_ooze_cyan.albedo_color = Color(0.08, 0.85, 1.0)
	mat_ooze_cyan.emission_enabled = true
	mat_ooze_cyan.emission = Color(0.10, 0.90, 1.0)
	mat_ooze_cyan.emission_energy_multiplier = 5.0

	# Термоядерная плазма камикадзе
	mat_ooze_plasma = StandardMaterial3D.new()
	mat_ooze_plasma.albedo_color = Color(1.0, 0.45, 0.05)
	mat_ooze_plasma.emission_enabled = true
	mat_ooze_plasma.emission = Color(1.0, 0.50, 0.10)
	mat_ooze_plasma.emission_energy_multiplier = 5.0

	# Алый оптический сенсор
	mat_eye_red = StandardMaterial3D.new()
	mat_eye_red.albedo_color = Color(1.0, 0.10, 0.05)
	mat_eye_red.emission_enabled = true
	mat_eye_red.emission = Color(1.0, 0.12, 0.06)
	mat_eye_red.emission_energy_multiplier = 4.5

	# Стекло капсул и колб
	mat_canister_glass = StandardMaterial3D.new()
	mat_canister_glass.albedo_color = Color(0.2, 0.5, 0.35, 0.45)
	mat_canister_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canister_glass.roughness = 0.08
	mat_canister_glass.metallic = 0.20

# =========================================================================
# ГЛАДКИЕ АНАТОМИЧЕСКИЕ И ПРОЦЕДУРНЫЕ ПРИМИТИВЫ (БЕЗ КВАДРАТОВ!)
# =========================================================================

# Гладкая анатомическая капсула (мышцы, конечности, торс)
func _create_capsule(parent: Node, r: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = h
	cap.radial_segments = 16
	cap.rings = 4
	mi.mesh = cap
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# Гладкая сфера (череп, суставы, капсулы, органы)
func _create_sphere(parent: Node, r: float, mat: Material, pos: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	sph.radial_segments = 16
	sph.rings = 8
	mi.mesh = sph
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# Гладкий цилиндр высокой детализации (трубки, поршни, баки)
func _create_cylinder(parent: Node, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = 16
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# Круглый тор (ребристые шланги, уплотнительные кольца)
func _create_torus(parent: Node, inner_r: float, outer_r: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.ring_segments = 16
	torus.rings = 8
	mi.mesh = torus
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# Вращающаяся дисковая пила с зеркальным полотном, 16 зубьями и кожухом
func _create_circular_saw(parent: Node, pos: Vector3, radius: float, teeth_count: int = 16) -> Node3D:
	var saw_rig := Node3D.new()
	saw_rig.position = pos
	parent.add_child(saw_rig)

	# Кожух гидромотора
	_create_capsule(saw_rig, radius * 0.38, radius * 0.75, mat_cyber_dark, Vector3(0.0, 0.0, -radius * 0.30), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_cylinder(saw_rig, radius * 0.42, radius * 0.42, radius * 0.15, mat_hazard, Vector3(0.0, 0.0, -radius * 0.15), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Шланг охлаждения пилы жижей
	_create_cylinder(saw_rig, radius * 0.06, radius * 0.06, radius * 0.70, mat_ooze_green, Vector3(radius * 0.25, radius * 0.25, -radius * 0.15), Vector3(deg_to_rad(35.0), 0.0, 0.0))

	# Вращающийся узел лезвия
	var blade_pivot := Node3D.new()
	blade_pivot.name = "BladePivot"
	saw_rig.add_child(blade_pivot)
	rotating_saws.append(blade_pivot)

	# Ступица
	_create_cylinder(blade_pivot, radius * 0.22, radius * 0.22, 0.035, mat_cyber_steel, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Тонкий круглый стальной диск (24 радиальных сегмента)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.012
	disc.radial_segments = 24
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.material_override = mat_saw_disc
	disc_mi.rotation.x = deg_to_rad(90.0)
	blade_pivot.add_child(disc_mi)

	# 16 острых зазубренных окровавленных зубьев по периметру
	for i in range(teeth_count):
		var ang : float = (float(i) / float(teeth_count)) * TAU
		var tx : float = cos(ang) * (radius * 0.94)
		var ty : float = sin(ang) * (radius * 0.94)
		var tooth := _create_capsule(blade_pivot, radius * 0.035, radius * 0.20, mat_saw_teeth, Vector3(tx, ty, 0.0), Vector3(0.0, 0.0, ang + deg_to_rad(35.0)))

	return saw_rig

# Колба со светящейся жижей, стеклянным кожухом и шлангами
func _create_ooze_canister(parent: Node, pos: Vector3, radius: float, height: float, ooze_mat: Material) -> Node3D:
	var can := Node3D.new()
	can.position = pos
	parent.add_child(can)

	# Верхний и нижний титановые фланцы
	_create_cylinder(can, radius * 1.25, radius * 1.25, height * 0.12, mat_cyber_steel, Vector3(0.0, height * 0.48, 0.0))
	_create_cylinder(can, radius * 1.25, radius * 1.25, height * 0.12, mat_cyber_steel, Vector3(0.0, -height * 0.48, 0.0))

	# Внутреннее светящееся ядро
	_create_cylinder(can, radius * 0.85, radius * 0.85, height * 0.86, ooze_mat, Vector3.ZERO)

	# Внешний стеклянный цилиндр
	_create_cylinder(can, radius, radius, height * 0.90, mat_canister_glass, Vector3.ZERO)

	# Шланг питания
	_create_cylinder(can, radius * 0.22, radius * 0.22, height * 0.35, mat_cable_black, Vector3(0.0, height * 0.60, 0.0), Vector3(0.0, 0.0, deg_to_rad(25.0)))
	return can

# Реалистичный высушенный череп с 3D-рельефом, челюстью и кибер-визором
func _create_realistic_mummy_skull(parent: Node, eye_mat: Material, saw_jaw: bool = false) -> void:
	# Округлая черепная коробка
	_create_sphere(parent, 0.13, mat_mummy_flesh, Vector3(0.0, 0.12, 0.0), Vector3(0.95, 1.05, 1.15))

	# Высушенная челюсть с открытой пастью
	_create_capsule(parent, 0.065, 0.15, mat_mummy_dark, Vector3(0.0, 0.01, 0.07), Vector3(deg_to_rad(45.0), 0.0, 0.0))

	# Зубы в оскале
	for t in range(5):
		var tx : float = -0.05 + float(t) * 0.025
		_create_capsule(parent, 0.008, 0.035, mat_bone, Vector3(tx, 0.02, 0.13))

	# Темная впадина правой глазницы (пустая глазница мумии)
	_create_sphere(parent, 0.032, mat_mummy_dark, Vector3(0.05, 0.12, 0.10))

	# Левая глазница: кибернетический горящий объектив с хромированной оправой
	_create_cylinder(parent, 0.038, 0.038, 0.04, mat_cyber_dark, Vector3(-0.05, 0.12, 0.10), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_sphere(parent, 0.026, eye_mat, Vector3(-0.05, 0.12, 0.12))

	# Изогнутая титановая пластина на лоб
	var brow := _create_capsule(parent, 0.05, 0.18, mat_cyber_steel, Vector3(-0.04, 0.18, 0.06), Vector3(0.0, 0.0, deg_to_rad(70.0)))

	# Шланги, вкрученные прямо в череп сзади
	_create_cylinder(parent, 0.016, 0.016, 0.20, mat_cable_black, Vector3(-0.05, 0.16, -0.10), Vector3(deg_to_rad(35.0), 0.0, 0.0))
	_create_cylinder(parent, 0.014, 0.014, 0.20, mat_ooze_green, Vector3(0.05, 0.16, -0.10), Vector3(deg_to_rad(35.0), 0.0, 0.0))

# Реалистичная 3D грудная клетка с изогнутыми ребрами и светящимся органом
func _create_3d_ribcage(parent: Node, pos: Vector3, width: float, height: float, inner_mat: Material) -> void:
	# Мутагенный насос / светящееся био-сердце
	_create_sphere(parent, width * 0.32, inner_mat, pos + Vector3(0.0, 0.0, 0.02))

	# Вертикальная грудина
	_create_capsule(parent, width * 0.06, height * 0.80, mat_bone, pos + Vector3(0.0, 0.0, width * 0.45))

	# 3 пары изогнутых округлых ребер
	for i in range(3):
		var y_off : float = pos.y + (float(i) - 1.0) * (height * 0.28)
		# Левое ребро
		var rib_l := _create_capsule(parent, width * 0.038, width * 0.55, mat_bone, Vector3(pos.x - width * 0.25, y_off, pos.z + width * 0.32))
		rib_l.rotation = Vector3(deg_to_rad(15.0), deg_to_rad(-25.0), deg_to_rad(15.0))
		# Правое ребро
		var rib_r := _create_capsule(parent, width * 0.038, width * 0.55, mat_bone, Vector3(pos.x + width * 0.25, y_off, pos.z + width * 0.32))
		rib_r.rotation = Vector3(deg_to_rad(15.0), deg_to_rad(25.0), deg_to_rad(-15.0))

# Внешний кибернетический сегментированный позвоночник
func _create_articulated_spine(parent: Node, count: int, height: float, z_pos: float) -> void:
	var step : float = height / float(count)
	for i in range(count):
		var y : float = (float(i) + 0.5) * step
		_create_sphere(parent, step * 0.35, mat_bone, Vector3(0.0, y, z_pos))
		_create_cylinder(parent, step * 0.32, step * 0.32, step * 0.40, mat_cyber_steel, Vector3(0.0, y, z_pos - 0.02), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	# Двойные гибкие кабели вдоль позвоночника
	_create_cylinder(parent, 0.014, 0.014, height, mat_cable_black, Vector3(-0.06, height * 0.5, z_pos - 0.04))
	_create_cylinder(parent, 0.014, 0.014, height, mat_cable_black, Vector3(0.06, height * 0.5, z_pos - 0.04))

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

	# Таз: гладкая округлая анатомия мумии с металлическим бандажом
	_create_capsule(pelvis, 0.16, 0.34, mat_mummy_flesh, Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_create_torus(pelvis, 0.14, 0.19, mat_cyber_steel, Vector3(0.0, 0.02, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Торс: гибкий позвоночник с сервоприводами и мумифицированная брюшная полость
	torso.position = Vector3(0.0, 0.12, 0.0)
	_create_capsule(torso, 0.13, 0.28, mat_mummy_flesh, Vector3(0.0, 0.14, 0.0))
	_create_articulated_spine(torso, 3, 0.28, -0.06)
	# Шланги подачи жижи в брюшину
	_create_cylinder(torso, 0.016, 0.016, 0.26, mat_ooze_green, Vector3(-0.12, 0.14, 0.0), Vector3(0.0, 0.0, deg_to_rad(25.0)))
	_create_cylinder(torso, 0.016, 0.016, 0.26, mat_cable_black, Vector3(0.12, 0.14, 0.0), Vector3(0.0, 0.0, deg_to_rad(-25.0)))

	# Грудная клетка: объемные 3D-ребра и светящееся био-сердце
	chest.position = Vector3(0.0, 0.28, 0.0)
	_create_capsule(chest, 0.18, 0.38, mat_mummy_flesh, Vector3(0.0, 0.16, 0.0))
	_create_3d_ribcage(chest, Vector3(0.0, 0.16, 0.04), 0.36, 0.32, mat_ooze_green)
	_create_ooze_canister(chest, Vector3(0.08, 0.20, -0.16), 0.055, 0.26, mat_ooze_green)
	_create_articulated_spine(chest, 4, 0.36, -0.12)

	# Голова: череп мумии со светящимся алым сенсором
	head.position = Vector3(0.0, 0.38, 0.0)
	_create_realistic_mummy_skull(head, mat_eye_red, false)

	# ЛЕВАЯ РУКА: ВРАЩАЮЩАЯСЯ ЦИРКУЛЯРНАЯ ПИЛА С ЗУБЬЯМИ
	l_shoulder.position = Vector3(-0.26, 0.26, 0.0)
	_create_capsule(l_shoulder, 0.06, 0.26, mat_cyber_steel, Vector3(0.0, -0.12, 0.0))
	_create_sphere(l_shoulder, 0.07, mat_cyber_dark, Vector3(0.0, 0.0, 0.0))

	l_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_cylinder(l_elbow, 0.055, 0.055, 0.18, mat_cyber_dark, Vector3(0.0, -0.09, 0.0))
	_create_circular_saw(l_elbow, Vector3(0.0, -0.32, 0.06), 0.22, 16)

	# ПРАВАЯ РУКА: Мумифицированная когтистая рука в черных шлангах
	r_shoulder.position = Vector3(0.26, 0.26, 0.0)
	_create_capsule(r_shoulder, 0.06, 0.26, mat_mummy_flesh, Vector3(0.0, -0.12, 0.0))
	_create_sphere(r_shoulder, 0.065, mat_mummy_dark, Vector3(0.0, 0.0, 0.0))

	r_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_capsule(r_elbow, 0.05, 0.26, mat_mummy_flesh, Vector3(0.0, -0.12, 0.0))
	# Когти
	for f in range(4):
		var fx : float = -0.035 + float(f) * 0.024
		_create_capsule(r_elbow, 0.01, 0.16, mat_bone, Vector3(fx, -0.30, 0.02), Vector3(deg_to_rad(15.0), 0.0, 0.0))
	_create_torus(r_elbow, 0.045, 0.065, mat_cable_black, Vector3(0.0, -0.16, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# НОГИ: Асимметричные
	# Левая: кибер-гидравлика
	l_hip.position = Vector3(-0.13, -0.06, 0.0)
	_create_capsule(l_hip, 0.06, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
	l_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(l_knee, 0.045, 0.045, 0.38, mat_cyber_dark, Vector3(0.0, -0.19, 0.0))
	_create_cylinder(l_knee, 0.022, 0.022, 0.28, mat_cyber_steel, Vector3(0.05, -0.14, -0.05)) # поршень
	_create_capsule(l_knee, 0.05, 0.22, mat_cyber_steel, Vector3(0.0, -0.38, 0.06), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Правая: мумифицированная нога с металлическим шарниром
	r_hip.position = Vector3(0.13, -0.06, 0.0)
	_create_capsule(r_hip, 0.065, 0.36, mat_mummy_flesh, Vector3(0.0, -0.18, 0.0))
	r_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_capsule(r_knee, 0.055, 0.38, mat_mummy_flesh, Vector3(0.0, -0.19, 0.0))
	_create_torus(r_knee, 0.05, 0.075, mat_cyber_steel, Vector3(0.0, -0.02, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_capsule(r_knee, 0.05, 0.22, mat_mummy_dark, Vector3(0.0, -0.38, 0.05), Vector3(deg_to_rad(90.0), 0.0, 0.0))

# =========================================================================
# 2. КИБЕР-СПРИНТЕР (RUNNER)
# =========================================================================
func _build_runner() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.78, 0.0)
	_create_capsule(pelvis, 0.12, 0.26, mat_mummy_dark, Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_capsule(torso, 0.09, 0.30, mat_mummy_flesh, Vector3(0.0, 0.15, 0.0))

	# Вытянутая вперед грудь с капсулами стимулятора
	chest.position = Vector3(0.0, 0.30, 0.06)
	_create_capsule(chest, 0.14, 0.32, mat_mummy_flesh, Vector3(0.0, 0.14, 0.0))
	_create_ooze_canister(chest, Vector3(-0.07, 0.15, 0.10), 0.035, 0.18, mat_ooze_cyan)
	_create_ooze_canister(chest, Vector3(0.07, 0.15, 0.10), 0.035, 0.18, mat_ooze_cyan)

	# Голова: вытянутый хищный череп с квадро-сенсорами
	head.position = Vector3(0.0, 0.34, 0.12)
	_create_sphere(head, 0.11, mat_mummy_dark, Vector3.ZERO, Vector3(0.85, 0.95, 1.3))
	# Респиратор на морде
	_create_capsule(head, 0.05, 0.14, mat_cyber_dark, Vector3(0.0, -0.04, 0.10), Vector3(deg_to_rad(70.0), 0.0, 0.0))
	# 4 красных визора
	_create_sphere(head, 0.020, mat_eye_red, Vector3(-0.045, 0.08, 0.12))
	_create_sphere(head, 0.020, mat_eye_red, Vector3(0.045, 0.08, 0.12))
	_create_sphere(head, 0.018, mat_eye_red, Vector3(-0.03, 0.03, 0.13))
	_create_sphere(head, 0.018, mat_eye_red, Vector3(0.03, 0.03, 0.13))

	# Руки с костяными вибро-лезвиями
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.20, 0.24, 0.0)
		_create_capsule(shoulder, 0.045, 0.26, mat_cyber_steel, Vector3(0.0, -0.13, 0.0))
		elbow.position = Vector3(0.0, -0.26, 0.0)
		_create_capsule(elbow, 0.038, 0.26, mat_mummy_flesh, Vector3(0.0, -0.13, 0.0))
		# Пилообразное вибро-лезвие
		_create_capsule(elbow, 0.025, 0.44, mat_saw_disc, Vector3(0.0, -0.38, 0.03))

	# Ноги: рессорные пружинные лезвия
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.10, -0.05, 0.0)
		_create_capsule(hip, 0.045, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(knee, 0.032, 0.032, 0.40, mat_cyber_steel, Vector3(0.0, -0.20, -0.05))
		# Изогнутая пружинная стопа
		_create_capsule(knee, 0.035, 0.30, mat_saw_disc, Vector3(0.0, -0.42, 0.08), Vector3(deg_to_rad(65.0), 0.0, 0.0))

# =========================================================================
# 3. БРОНИРОВАННЫЙ МЯСНИК-ДЖАГГЕРНАУТ (BRUTE)
# =========================================================================
func _build_brute() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.95, 0.0)
	_create_capsule(pelvis, 0.32, 0.65, mat_cyber_dark, Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	torso.position = Vector3(0.0, 0.20, 0.0)
	_create_capsule(torso, 0.34, 0.45, mat_mummy_flesh, Vector3(0.0, 0.20, 0.0))

	# Колоссальная бронированная грудь
	chest.position = Vector3(0.0, 0.40, 0.0)
	_create_capsule(chest, 0.46, 0.70, mat_mummy_dark, Vector3(0.0, 0.28, 0.0))
	_create_torus(chest, 0.44, 0.52, mat_hazard, Vector3(0.0, 0.22, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# БАК С БУРЛЯЩЕЙ МУТАГЕННОЙ ЖИЖЕЙ НА СПИНЕ
	var vat := _create_cylinder(chest, 0.26, 0.26, 0.68, mat_ooze_green, Vector3(0.0, 0.38, -0.34))
	_create_cylinder(vat, 0.28, 0.28, 0.70, mat_canister_glass, Vector3.ZERO)
	_create_torus(vat, 0.27, 0.31, mat_cyber_steel, Vector3(0.0, 0.20, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_torus(vat, 0.27, 0.31, mat_cyber_steel, Vector3(0.0, -0.20, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	# Выхлопные трубы
	_create_cylinder(chest, 0.07, 0.07, 0.55, mat_cyber_dark, Vector3(-0.35, 0.62, -0.28))
	_create_cylinder(chest, 0.07, 0.07, 0.55, mat_cyber_dark, Vector3(0.35, 0.62, -0.28))

	# Голова: тяжелый сферический шлем палача с узкой амбразурой
	head.position = Vector3(0.0, 0.52, 0.08)
	_create_sphere(head, 0.22, mat_cyber_steel, Vector3(0.0, 0.16, 0.0))
	_create_capsule(head, 0.035, 0.26, mat_eye_red, Vector3(0.0, 0.18, 0.20), Vector3(0.0, 0.0, deg_to_rad(90.0)))

	# ЛЕВАЯ РУКА: ОГРОМНАЯ 0.7M ДИСКОВАЯ МЕГА-ПИЛА
	l_shoulder.position = Vector3(-0.62, 0.46, 0.0)
	_create_capsule(l_shoulder, 0.16, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
	l_elbow.position = Vector3(0.0, -0.36, 0.0)
	_create_capsule(l_elbow, 0.14, 0.42, mat_cyber_steel, Vector3(0.0, -0.20, 0.0))
	_create_circular_saw(l_elbow, Vector3(0.0, -0.56, 0.08), 0.36, 20)

	# ПРАВАЯ РУКА: ГИДРАВЛИЧЕСКИЙ ДРОБЯЩИЙ ЗАХВАТ
	r_shoulder.position = Vector3(0.62, 0.46, 0.0)
	_create_capsule(r_shoulder, 0.16, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
	r_elbow.position = Vector3(0.0, -0.36, 0.0)
	_create_capsule(r_elbow, 0.14, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
	_create_capsule(r_elbow, 0.06, 0.48, mat_saw_teeth, Vector3(-0.09, -0.52, 0.0), Vector3(deg_to_rad(20.0), 0.0, 0.0))
	_create_capsule(r_elbow, 0.06, 0.48, mat_saw_teeth, Vector3(0.09, -0.52, 0.0), Vector3(deg_to_rad(-20.0), 0.0, 0.0))

	# Ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.26, -0.10, 0.0)
		_create_capsule(hip, 0.16, 0.46, mat_cyber_dark, Vector3(0.0, -0.22, 0.0))
		knee.position = Vector3(0.0, -0.46, 0.0)
		_create_cylinder(knee, 0.14, 0.14, 0.46, mat_cyber_steel, Vector3(0.0, -0.23, 0.0))
		_create_capsule(knee, 0.15, 0.38, mat_cyber_dark, Vector3(0.0, -0.48, 0.08), Vector3(deg_to_rad(90.0), 0.0, 0.0))

# =========================================================================
# 4. КИБЕР-ПАУК ПОЛЗУН (CRAWLER)
# =========================================================================
func _build_crawler() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.35, 0.0)

	# Низкое паучье брюшко со светящейся кислотой
	_create_sphere(pelvis, 0.34, mat_cyber_dark, Vector3(0.0, 0.0, -0.15), Vector3(1.1, 0.8, 1.2))
	_create_sphere(pelvis, 0.28, mat_ooze_green, Vector3(0.0, -0.06, -0.26))

	torso.position = Vector3(0.0, 0.18, -0.08)
	_create_capsule(torso, 0.16, 0.38, mat_mummy_flesh, Vector3(0.0, 0.14, 0.0))

	chest.position = Vector3(0.0, 0.24, 0.08)
	_create_capsule(chest, 0.18, 0.38, mat_mummy_dark, Vector3(0.0, 0.16, 0.0))
	_create_3d_ribcage(chest, Vector3(0.0, 0.16, 0.04), 0.34, 0.28, mat_ooze_green)

	# Голова с 5 зелеными линзами
	head.position = Vector3(0.0, 0.28, 0.18)
	_create_sphere(head, 0.12, mat_mummy_flesh, Vector3(0.0, 0.08, 0.0))
	_create_sphere(head, 0.035, mat_ooze_green, Vector3(-0.05, 0.12, 0.10))
	_create_sphere(head, 0.025, mat_ooze_green, Vector3(-0.01, 0.15, 0.10))
	_create_sphere(head, 0.030, mat_ooze_green, Vector3(-0.07, 0.06, 0.10))
	_create_sphere(head, 0.025, mat_ooze_green, Vector3(0.03, 0.12, 0.10))
	_create_sphere(head, 0.030, mat_ooze_green, Vector3(0.06, 0.06, 0.10))

	# Передние лапы с вращающимися микро-пилами
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.34, 0.18, 0.12)
		_create_capsule(shoulder, 0.07, 0.42, mat_cyber_steel, Vector3(side * 0.14, -0.10, 0.14))
		elbow.position = Vector3(side * 0.24, -0.20, 0.24)
		_create_cylinder(elbow, 0.055, 0.055, 0.42, mat_cyber_dark, Vector3(0.0, -0.18, 0.08))
		_create_circular_saw(elbow, Vector3(0.0, -0.45, 0.16), 0.18, 14)

# =========================================================================
# 5. ХИМИЧЕСКИЙ МУТАНТ-СПИТТЕР (SPITTER)
# =========================================================================
func _build_spitter() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.80, 0.0)
	_create_capsule(pelvis, 0.18, 0.38, mat_mummy_dark, Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	torso.position = Vector3(0.0, 0.14, 0.0)
	_create_capsule(torso, 0.18, 0.36, mat_mummy_flesh, Vector3(0.0, 0.16, 0.0))

	# Сгорбленная грудь со сдвоенными баллонами кислоты
	chest.position = Vector3(0.0, 0.30, 0.0)
	_create_capsule(chest, 0.22, 0.42, mat_mummy_flesh, Vector3(0.0, 0.18, -0.05))

	_create_ooze_canister(chest, Vector3(-0.16, 0.36, -0.22), 0.09, 0.46, mat_ooze_green)
	_create_ooze_canister(chest, Vector3(0.16, 0.36, -0.22), 0.09, 0.46, mat_ooze_green)

	# Голова: противогазная маска с широким соплом
	head.position = Vector3(0.0, 0.40, 0.06)
	_create_sphere(head, 0.13, mat_mummy_dark, Vector3(0.0, 0.10, 0.0))
	_create_cylinder(head, 0.045, 0.045, 0.05, mat_ooze_green, Vector3(-0.06, 0.12, 0.12), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_cylinder(head, 0.045, 0.045, 0.05, mat_ooze_green, Vector3(0.06, 0.12, 0.12), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	# Сопло на челюсти
	_create_cylinder(head, 0.065, 0.05, 0.16, mat_cyber_steel, Vector3(0.0, 0.01, 0.16), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Шланги от баков прямо в сопло челюсти
	_create_cylinder(chest, 0.022, 0.022, 0.45, mat_cable_black, Vector3(-0.14, 0.28, 0.0), Vector3(deg_to_rad(45.0), 0.0, 0.0))
	_create_cylinder(chest, 0.022, 0.022, 0.45, mat_cable_black, Vector3(0.14, 0.28, 0.0), Vector3(deg_to_rad(45.0), 0.0, 0.0))

	# Руки
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.28, 0.26, 0.0)
		_create_capsule(shoulder, 0.06, 0.26, mat_mummy_flesh, Vector3(0.0, -0.13, 0.0))
		elbow.position = Vector3(0.0, -0.26, 0.0)
		_create_capsule(elbow, 0.05, 0.26, mat_cyber_steel, Vector3(0.0, -0.13, 0.0))
		_create_capsule(elbow, 0.025, 0.22, mat_ooze_green, Vector3(0.0, -0.32, 0.04))

	# Ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.14, -0.06, 0.0)
		_create_capsule(hip, 0.065, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_capsule(knee, 0.055, 0.38, mat_cyber_steel, Vector3(0.0, -0.19, 0.0))

# =========================================================================
# 6. АКУСТИЧЕСКАЯ СИРЕНА (SCREAMER)
# =========================================================================
func _build_screamer() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.90, 0.0)
	_create_capsule(pelvis, 0.11, 0.24, mat_mummy_dark, Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_articulated_spine(torso, 4, 0.40, -0.04)

	chest.position = Vector3(0.0, 0.40, 0.0)
	_create_capsule(chest, 0.14, 0.34, mat_mummy_flesh, Vector3(0.0, 0.16, 0.0))
	_create_ooze_canister(chest, Vector3(-0.14, 0.26, -0.08), 0.04, 0.24, mat_ooze_cyan)
	_create_ooze_canister(chest, Vector3(0.14, 0.26, -0.08), 0.04, 0.24, mat_ooze_cyan)

	# Голова: акустический рупор
	head.position = Vector3(0.0, 0.42, 0.0)
	_create_sphere(head, 0.11, mat_bone, Vector3(0.0, 0.10, -0.04))
	_create_cylinder(head, 0.24, 0.10, 0.26, mat_cyber_dark, Vector3(0.0, 0.14, 0.10), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_cylinder(head, 0.17, 0.06, 0.22, mat_ooze_cyan, Vector3(0.0, 0.14, 0.15), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Длинные антенные руки
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.18, 0.26, 0.0)
		_create_capsule(shoulder, 0.032, 0.36, mat_cyber_steel, Vector3(0.0, -0.17, 0.0))
		elbow.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(elbow, 0.015, 0.025, 0.44, mat_saw_disc, Vector3(0.0, -0.22, 0.0))

	# Ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.09, -0.05, 0.0)
		_create_capsule(hip, 0.038, 0.45, mat_cyber_dark, Vector3(0.0, -0.22, 0.0))
		knee.position = Vector3(0.0, -0.45, 0.0)
		_create_capsule(knee, 0.030, 0.45, mat_cyber_steel, Vector3(0.0, -0.22, 0.0))

# =========================================================================
# 7. БИО-ТЕРМОЯДЕРНЫЙ КАМИКАДЗЕ (EXPLODER)
# =========================================================================
func _build_exploder() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.70, 0.0)

	# Сферическая бронекапсула реактора
	_create_sphere(pelvis, 0.54, mat_cyber_dark, Vector3(0.0, 0.15, 0.0))
	# Светящееся плазменное ядро
	_create_sphere(pelvis, 0.42, mat_ooze_plasma, Vector3(0.0, 0.18, 0.16))
	# Защитные кольца Hazard
	_create_torus(pelvis, 0.52, 0.60, mat_hazard, Vector3(0.0, 0.15, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Ампулы нестабильной смеси
	for a in range(4):
		var ang : float = float(a) * (PI * 0.5) + deg_to_rad(45.0)
		var vx : float = cos(ang) * 0.52
		var vz : float = sin(ang) * 0.52
		_create_ooze_canister(pelvis, Vector3(vx, 0.15, vz), 0.05, 0.32, mat_ooze_green)

	# Голова с мигающим тревожным маячком
	head.position = Vector3(0.0, 0.72, 0.0)
	_create_sphere(head, 0.12, mat_bone, Vector3(0.0, 0.08, 0.0))
	_create_cylinder(head, 0.065, 0.065, 0.14, mat_cyber_dark, Vector3(0.0, 0.20, 0.0))
	_create_sphere(head, 0.055, mat_eye_red, Vector3(0.0, 0.28, 0.0))

	# 4 устойчивые поршневые ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.36, 0.0, 0.18)
		_create_cylinder(hip, 0.075, 0.075, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(knee, 0.065, 0.065, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))

# =========================================================================
# УНИВЕРСАЛЬНАЯ АНИМАЦИЯ С ВРАЩЕНИЕМ ДИСКОВЫХ ПИЛ
# =========================================================================
func update_animation(delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	is_moving = moving
	walk_speed_mult = move_speed
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	# Живое вращение всех дисковых пил
	var saw_speed : float = (40.0 if is_attacking else 18.0) * delta
	for saw in rotating_saws:
		if is_instance_valid(saw):
			saw.rotate_z(saw_speed)

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
		l_shoulder.rotation.x = sin(anim_time) * 0.45
		r_shoulder.rotation.x = -sin(anim_time) * 0.45
		torso.rotation.y = sin(anim_time) * 0.20
	elif current_type == "Exploder":
		pelvis.rotation.z = sin(anim_time) * 0.12
		l_hip.rotation.x = leg_angle * 0.7
		r_hip.rotation.x = -leg_angle * 0.7

	# Анимация рук и ударов пилы
	if is_attacking:
		_animate_attack(delta)
	else:
		attack_progress = 0.0
		if current_type == "Screamer":
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
	attack_progress += delta * (6.5 if current_type == "Runner" else 4.2)
	var phase : float = fmod(attack_progress, TAU)

	if phase < PI:
		var t : float = phase / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(-120.0), t)
		l_elbow.rotation.x = deg_to_rad(-85.0)
		torso.rotation.y = deg_to_rad(25.0)
	else:
		var t : float = (phase - PI) / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(45.0), t * 1.8)
		l_elbow.rotation.x = deg_to_rad(-10.0)
		torso.rotation.y = deg_to_rad(-30.0)

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
