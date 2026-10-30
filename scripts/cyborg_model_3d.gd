extends Node3D

# =========================================================================
# CYBORG ZOMBIE 3D PROCEDURAL GENERATOR & RIG
# "Высушенные зомби с кучей трубок, кибер-деталей, пил и светящейся жижи"
# =========================================================================

var current_type: String = "Walker"

# --- Высокодетализированные PBR Материалы ---
var mat_dried_flesh      : StandardMaterial3D # Высушенная пепельно-серая мумифицированная плоть
var mat_dried_flesh_dark : StandardMaterial3D # Обугленная сморщенная некротическая ткань
var mat_bone             : StandardMaterial3D # Высохшие кости, ребра, черепа, зубы
var mat_cyber_steel      : StandardMaterial3D # Шлифованная оружейная сталь, титановые скобы и суставы
var mat_cyber_dark       : StandardMaterial3D # Тяжелые вороненые рамы и каркасы экзоскелета
var mat_cable_black      : StandardMaterial3D # Ребристые черные шланги, пучки проводов
var mat_cable_yellow     : StandardMaterial3D # Изоляционная проводка питания
var mat_saw_disc         : StandardMaterial3D # Зеркальные лезвия дисковых пил
var mat_saw_teeth        : StandardMaterial3D # Зазубренные окровавленные стальные зубья
var mat_hazard           : StandardMaterial3D # Желто-черная индустриальная маркировка
var mat_ooze_green       : StandardMaterial3D # Радиоактивная бурлящая мутагенная жижа
var mat_ooze_cyan        : StandardMaterial3D # Криогенный хладагент / нейро-стимулятор
var mat_ooze_plasma      : StandardMaterial3D # Термоядерная плазма камикадзе
var mat_eye_red          : StandardMaterial3D # Алые оптические сенсоры / визоры
var mat_canister_glass   : StandardMaterial3D # Защитные колбы ампул

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

# Список вращающихся пил для динамической анимации
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

func _init_materials() -> void:
	if mat_dried_flesh != null:
		return

	# 1. Высушенная мумифицированная кожа (пепельно-землистая)
	mat_dried_flesh = StandardMaterial3D.new()
	mat_dried_flesh.albedo_color = Color(0.28, 0.23, 0.20)
	mat_dried_flesh.roughness = 0.90
	mat_dried_flesh.metallic = 0.05

	# 2. Обугленная сморщенная ткань
	mat_dried_flesh_dark = StandardMaterial3D.new()
	mat_dried_flesh_dark.albedo_color = Color(0.16, 0.13, 0.12)
	mat_dried_flesh_dark.roughness = 0.95

	# 3. Сухая пожелтевшая кость (череп, ребра)
	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color(0.74, 0.70, 0.60)
	mat_bone.roughness = 0.70

	# 4. Кибер-сталь (импланты, титановые скобы)
	mat_cyber_steel = StandardMaterial3D.new()
	mat_cyber_steel.albedo_color = Color(0.42, 0.44, 0.48)
	mat_cyber_steel.metallic = 0.95
	mat_cyber_steel.roughness = 0.25

	# 5. Вороненый карбоновый каркас
	mat_cyber_dark = StandardMaterial3D.new()
	mat_cyber_dark.albedo_color = Color(0.12, 0.13, 0.15)
	mat_cyber_dark.metallic = 0.85
	mat_cyber_dark.roughness = 0.45

	# 6. Ребристые черные кабели и трубки гидравлики
	mat_cable_black = StandardMaterial3D.new()
	mat_cable_black.albedo_color = Color(0.06, 0.06, 0.07)
	mat_cable_black.roughness = 0.80

	# 7. Предупреждающие кабели питания
	mat_cable_yellow = StandardMaterial3D.new()
	mat_cable_yellow.albedo_color = Color(0.85, 0.68, 0.08)
	mat_cable_yellow.roughness = 0.50

	# 8. Зеркальный диск циркулярной пилы
	mat_saw_disc = StandardMaterial3D.new()
	mat_saw_disc.albedo_color = Color(0.88, 0.90, 0.94)
	mat_saw_disc.metallic = 0.98
	mat_saw_disc.roughness = 0.12

	# 9. Окровавленные и ржавые зубья пилы
	mat_saw_teeth = StandardMaterial3D.new()
	mat_saw_teeth.albedo_color = Color(0.55, 0.22, 0.18)
	mat_saw_teeth.metallic = 0.80
	mat_saw_teeth.roughness = 0.45

	# 10. Предупреждающая окраска Hazard
	mat_hazard = StandardMaterial3D.new()
	mat_hazard.albedo_color = Color(0.92, 0.72, 0.05)
	mat_hazard.roughness = 0.35

	# 11. Светящаяся едкая мутагенная жижа (кислотно-зеленый неон)
	mat_ooze_green = StandardMaterial3D.new()
	mat_ooze_green.albedo_color = Color(0.18, 0.98, 0.25)
	mat_ooze_green.emission_enabled = true
	mat_ooze_green.emission = Color(0.20, 1.0, 0.30)
	mat_ooze_green.emission_energy_multiplier = 4.5

	# 12. Светящийся криогенный хладагент / нейростимулятор (бирюзовый)
	mat_ooze_cyan = StandardMaterial3D.new()
	mat_ooze_cyan.albedo_color = Color(0.08, 0.85, 1.0)
	mat_ooze_cyan.emission_enabled = true
	mat_ooze_cyan.emission = Color(0.10, 0.90, 1.0)
	mat_ooze_cyan.emission_energy_multiplier = 4.5

	# 13. Термоядерная плазма камикадзе
	mat_ooze_plasma = StandardMaterial3D.new()
	mat_ooze_plasma.albedo_color = Color(1.0, 0.45, 0.05)
	mat_ooze_plasma.emission_enabled = true
	mat_ooze_plasma.emission = Color(1.0, 0.50, 0.10)
	mat_ooze_plasma.emission_energy_multiplier = 5.0

	# 14. Алый оптический сенсор
	mat_eye_red = StandardMaterial3D.new()
	mat_eye_red.albedo_color = Color(1.0, 0.10, 0.05)
	mat_eye_red.emission_enabled = true
	mat_eye_red.emission = Color(1.0, 0.12, 0.06)
	mat_eye_red.emission_energy_multiplier = 4.0

	# 15. Стекло колб для жижи
	mat_canister_glass = StandardMaterial3D.new()
	mat_canister_glass.albedo_color = Color(0.2, 0.5, 0.3, 0.5)
	mat_canister_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canister_glass.roughness = 0.10
	mat_canister_glass.metallic = 0.20

# --- Базовые геометрические примитивы с автотенью ---
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

# =========================================================================
# СПЕЦИАЛЬНЫЕ КОМПОНЕНТЫ: ПИЛЫ, КОЛБЫ С ЖИЖЕЙ, ТРУБКИ И РЕБРА
# =========================================================================

# Создает вращающуюся циркулярную пилу с зубьями и кожухом
func _create_circular_saw(parent: Node, pos: Vector3, radius: float, teeth_count: int = 12) -> Node3D:
	var saw_rig := Node3D.new()
	saw_rig.position = pos
	parent.add_child(saw_rig)

	# Кожух двигателя и мотора
	var motor := _create_box(saw_rig, Vector3(radius * 0.7, radius * 0.7, radius * 0.5), mat_cyber_dark, Vector3(0.0, 0.0, -radius * 0.35))
	_create_box(motor, Vector3(radius * 0.75, radius * 0.2, radius * 0.52), mat_hazard, Vector3(0.0, 0.0, 0.0))

	# Шланг подачи охлаждающей жижи в пилу
	var tube := _create_cylinder(saw_rig, radius * 0.08, radius * 0.8, mat_ooze_green, Vector3(radius * 0.3, radius * 0.3, -radius * 0.2))
	tube.rotation.x = deg_to_rad(45.0)

	# Вращающийся узел лезвия
	var blade_pivot := Node3D.new()
	blade_pivot.name = "BladePivot"
	saw_rig.add_child(blade_pivot)
	rotating_saws.append(blade_pivot)

	# Центральный фланец и ступица
	_create_cylinder(blade_pivot, radius * 0.25, 0.035, mat_cyber_steel, Vector3.ZERO).rotation.x = deg_to_rad(90.0)

	# Основной тонкий зеркальный стальной диск
	var disc := _create_cylinder(blade_pivot, radius, 0.012, mat_saw_disc, Vector3.ZERO)
	disc.rotation.x = deg_to_rad(90.0)

	# Зазубренные окровавленные зубья по периметру
	for i in range(teeth_count):
		var ang : float = (float(i) / float(teeth_count)) * TAU
		var tooth_x : float = cos(ang) * (radius * 0.95)
		var tooth_y : float = sin(ang) * (radius * 0.95)
		var tooth := _create_box(blade_pivot, Vector3(radius * 0.22, radius * 0.08, 0.018), mat_saw_teeth, Vector3(tooth_x, tooth_y, 0.0))
		tooth.rotation.z = ang + deg_to_rad(30.0) # Наклон зубьев по направлению вращения

	return saw_rig

# Создает колбу/баллон со светящейся мутагенной жижей и датчиками
func _create_ooze_vial(parent: Node, pos: Vector3, radius: float, height: float, ooze_mat: Material) -> Node3D:
	var vial := Node3D.new()
	vial.position = pos
	parent.add_child(vial)

	# Верхний и нижний металлические фланцы
	_create_cylinder(vial, radius * 1.25, height * 0.15, mat_cyber_steel, Vector3(0.0, height * 0.5, 0.0))
	_create_cylinder(vial, radius * 1.25, height * 0.15, mat_cyber_steel, Vector3(0.0, -height * 0.5, 0.0))

	# Светящееся ядро жижи внутри
	_create_cylinder(vial, radius * 0.85, height * 0.85, ooze_mat, Vector3.ZERO)

	# Внешняя защитная стеклянная капсула
	_create_cylinder(vial, radius, height * 0.90, mat_canister_glass, Vector3.ZERO)

	# Шланги подачи сверху и снизу
	var top_hose := _create_cylinder(vial, radius * 0.25, height * 0.4, mat_cable_black, Vector3(0.0, height * 0.65, 0.0))
	top_hose.rotation.z = deg_to_rad(20.0)

	return vial

# Создает обнаженную грудную клетку с высохшими ребрами и светящимся органом внутри
func _create_exposed_ribcage(parent: Node, pos: Vector3, width: float, height: float, depth: float, inner_mat: Material) -> void:
	# Внутреннее светящееся мутагенное сердце / насос жижи
	_create_sphere(parent, width * 0.35, inner_mat, pos + Vector3(0.0, 0.0, 0.02))

	# Вертикальная грудина
	_create_box(parent, Vector3(width * 0.12, height * 0.85, depth * 0.15), mat_bone, pos + Vector3(0.0, 0.0, depth * 0.55))

	# Изогнутые высохшие ребра (3 пары)
	for i in range(3):
		var y_off : float = pos.y + (float(i) - 1.0) * (height * 0.28)
		# Левое ребро
		var rib_l := _create_box(parent, Vector3(width * 0.52, height * 0.06, depth * 0.10), mat_bone, Vector3(pos.x - width * 0.25, y_off, pos.z + depth * 0.40))
		rib_l.rotation.y = deg_to_rad(-25.0)
		rib_l.rotation.z = deg_to_rad(10.0)
		# Правое ребро
		var rib_r := _create_box(parent, Vector3(width * 0.52, height * 0.06, depth * 0.10), mat_bone, Vector3(pos.x + width * 0.25, y_off, pos.z + depth * 0.40))
		rib_r.rotation.y = deg_to_rad(25.0)
		rib_r.rotation.z = deg_to_rad(-10.0)

# Создает кабели/трубки, соединяющие суставы
func _create_cable_strand(parent: Node, start_p: Vector3, end_p: Vector3, r: float, mat: Material) -> void:
	var mid_p : Vector3 = (start_p + end_p) * 0.5
	var dir : Vector3 = end_p - start_p
	var len : float = dir.length()
	if len < 0.01:
		return

	var strand := _create_cylinder(parent, r, len, mat, mid_p)
	# Ориентируем цилиндр вдоль вектора
	strand.look_at_from_position(mid_p, mid_p + dir, Vector3.UP)
	strand.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

# Создает высушенный череп с кибер-имплантами и трубками
func _create_cyborg_skull(parent: Node, eye_color_mat: Material, saw_teeth_jaw: bool = false) -> void:
	# Высушенная черепная коробка
	_create_box(parent, Vector3(0.22, 0.24, 0.22), mat_bone, Vector3(0.0, 0.12, 0.0))
	# Высушенная сморщенная кожа на щеках
	_create_box(parent, Vector3(0.23, 0.12, 0.15), mat_dried_flesh, Vector3(0.0, 0.08, 0.04))

	# Титановая бронепластина на лоб и левую часть черепа
	_create_box(parent, Vector3(0.14, 0.16, 0.23), mat_cyber_steel, Vector3(-0.06, 0.16, 0.02))

	# Шланги, вкрученные в затылок и питающие мозг жижей
	_create_cylinder(parent, 0.022, 0.18, mat_cable_black, Vector3(-0.05, 0.18, -0.12)).rotation.x = deg_to_rad(35.0)
	_create_cylinder(parent, 0.018, 0.18, mat_ooze_green, Vector3(0.05, 0.18, -0.12)).rotation.x = deg_to_rad(35.0)

	# Правая глазница: пустая темная впадина
	_create_sphere(parent, 0.035, mat_dried_flesh_dark, Vector3(0.05, 0.13, 0.11))

	# Левая глазница: кибернетический горящий сенсор с металлическим ободком
	_create_cylinder(parent, 0.045, 0.05, mat_cyber_dark, Vector3(-0.05, 0.13, 0.11)).rotation.x = deg_to_rad(90.0)
	_create_sphere(parent, 0.032, eye_color_mat, Vector3(-0.05, 0.13, 0.13))

	# Челюсть
	if saw_teeth_jaw:
		# Стальная челюсть-капкан с острыми зубьями пилы
		_create_box(parent, Vector3(0.18, 0.08, 0.18), mat_cyber_dark, Vector3(0.0, 0.01, 0.05))
		for j in range(4):
			_create_box(parent, Vector3(0.02, 0.06, 0.02), mat_saw_teeth, Vector3(-0.06 + j * 0.04, -0.02, 0.13))
	else:
		# Оскаленная костяная пасть с металлическими скобами
		_create_box(parent, Vector3(0.16, 0.08, 0.16), mat_bone, Vector3(0.0, 0.01, 0.05))
		_create_box(parent, Vector3(0.18, 0.03, 0.17), mat_cyber_steel, Vector3(0.0, 0.02, 0.06))

# Внешний кибер-позвоночник с узлами сервоприводов
func _create_cyber_spine(parent: Node, count: int, height: float, z_pos: float) -> void:
	var step : float = height / float(count)
	for i in range(count):
		var y : float = (float(i) + 0.5) * step
		# Позвонок
		_create_box(parent, Vector3(0.10, step * 0.65, 0.08), mat_bone, Vector3(0.0, y, z_pos))
		# Стальной фиксатор сервопривода
		_create_box(parent, Vector3(0.14, step * 0.35, 0.10), mat_cyber_steel, Vector3(0.0, y, z_pos - 0.02))
	# Двойные кабели вдоль позвоночника
	_create_cylinder(parent, 0.016, height, mat_cable_black, Vector3(-0.06, height * 0.5, z_pos - 0.03))
	_create_cylinder(parent, 0.016, height, mat_cable_black, Vector3(0.06, height * 0.5, z_pos - 0.03))

func _create_spine_vertebrae(parent: Node, count: int, height: float, z_pos: float) -> void:
	_create_cyber_spine(parent, count, height, z_pos)

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
# Высушенный зомби с обнаженными ребрами, насосом жижи и циркулярной пилой
# =========================================================================
func _build_walker() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.82, 0.0)

	# Таз: высушенная плоть в металлическом каркасе
	_create_box(pelvis, Vector3(0.34, 0.18, 0.24), mat_dried_flesh)
	_create_box(pelvis, Vector3(0.38, 0.06, 0.26), mat_cyber_steel, Vector3(0.0, 0.04, 0.0))

	# Живот и поясница: позвоночник с гидравликой
	torso.position = Vector3(0.0, 0.12, 0.0)
	_create_spine_vertebrae(torso, 3, 0.28, -0.06)
	_create_box(torso, Vector3(0.24, 0.26, 0.20), mat_dried_flesh, Vector3(0.0, 0.14, 0.01))
	# Шланги жижи с боков в живот
	_create_cylinder(torso, 0.02, 0.25, mat_ooze_green, Vector3(-0.14, 0.14, 0.0)).rotation.z = deg_to_rad(20.0)
	_create_cylinder(torso, 0.02, 0.25, mat_cable_black, Vector3(0.14, 0.14, 0.0)).rotation.z = deg_to_rad(-20.0)

	# Грудь: обнаженные ребра, светящееся мутагенное сердце
	chest.position = Vector3(0.0, 0.28, 0.0)
	_create_box(chest, Vector3(0.42, 0.38, 0.26), mat_dried_flesh, Vector3(0.0, 0.16, 0.0))
	_create_exposed_ribcage(chest, Vector3(0.0, 0.18, 0.04), 0.40, 0.34, 0.24, mat_ooze_green)
	# Колба с жижей на спине
	_create_ooze_vial(chest, Vector3(0.08, 0.20, -0.18), 0.055, 0.28, mat_ooze_green)
	_create_cyber_spine(chest, 4, 0.36, -0.14)

	# Голова: полувысушенный череп с титановой пластиной и проводами
	head.position = Vector3(0.0, 0.38, 0.0)
	_create_cyborg_skull(head, mat_eye_red, false)

	# ЛЕВАЯ РУКА: ВРАЩАЮЩАЯСЯ ЦИРКУЛЯРНАЯ ПИЛА
	l_shoulder.position = Vector3(-0.28, 0.28, 0.0)
	_create_cylinder(l_shoulder, 0.06, 0.24, mat_cyber_steel, Vector3(0.0, -0.12, 0.0))
	# Кабели питания пилы на плече
	_create_cylinder(l_shoulder, 0.018, 0.26, mat_cable_yellow, Vector3(-0.06, -0.12, 0.0))

	l_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_cylinder(l_elbow, 0.055, 0.18, mat_cyber_dark, Vector3(0.0, -0.09, 0.0))
	# Монтаж дисковой пилы на предплечье
	_create_circular_saw(l_elbow, Vector3(0.0, -0.32, 0.06), 0.22, 14)

	# ПРАВАЯ РУКА: Высохшая когтистая лапа с кабельными бандажами
	r_shoulder.position = Vector3(0.28, 0.28, 0.0)
	_create_cylinder(r_shoulder, 0.055, 0.24, mat_dried_flesh, Vector3(0.0, -0.12, 0.0))
	r_elbow.position = Vector3(0.0, -0.24, 0.0)
	_create_cylinder(r_elbow, 0.045, 0.24, mat_dried_flesh, Vector3(0.0, -0.12, 0.0))
	# Когтистые пальцы
	for f in range(4):
		var fx : float = -0.04 + f * 0.026
		_create_box(r_elbow, Vector3(0.015, 0.16, 0.025), mat_bone, Vector3(fx, -0.30, 0.02))
	# Провода, обмотанные вокруг руки
	_create_cylinder(r_elbow, 0.055, 0.04, mat_cable_black, Vector3(0.0, -0.16, 0.0))

	# НОГИ: Асимметричные (одна с шиной и скобами, вторая - гидравлический поршень)
	l_hip.position = Vector3(-0.13, -0.06, 0.0)
	_create_cylinder(l_hip, 0.06, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
	l_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(l_knee, 0.05, 0.38, mat_cyber_dark, Vector3(0.0, -0.19, 0.0))
	# Гидравлический поршень на колене
	_create_cylinder(l_knee, 0.025, 0.28, mat_cyber_steel, Vector3(0.05, -0.14, -0.05))
	_create_box(l_knee, Vector3(0.12, 0.08, 0.24), mat_cyber_steel, Vector3(0.0, -0.38, 0.06))

	r_hip.position = Vector3(0.13, -0.06, 0.0)
	_create_cylinder(r_hip, 0.065, 0.36, mat_dried_flesh, Vector3(0.0, -0.18, 0.0))
	r_knee.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(r_knee, 0.055, 0.38, mat_dried_flesh, Vector3(0.0, -0.19, 0.0))
	_create_box(r_knee, Vector3(0.12, 0.08, 0.22), mat_dried_flesh_dark, Vector3(0.0, -0.38, 0.05))
	# Металлические скобы на коленной чашечке
	_create_box(r_knee, Vector3(0.10, 0.12, 0.05), mat_cyber_steel, Vector3(0.0, -0.02, 0.06))

# =========================================================================
# 2. КИБЕР-СПРИНТЕР (RUNNER)
# Тощий сгорбленный труп с рессорными лезвиями и инъекторами бирюзовой жижи
# =========================================================================
func _build_runner() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.78, 0.0)
	_create_box(pelvis, Vector3(0.24, 0.12, 0.18), mat_dried_flesh_dark)

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_cylinder(torso, 0.04, 0.30, mat_cyber_steel, Vector3(0.0, 0.15, 0.0))

	# Грудь: вытянутая вперед с ампулами стимулятора
	chest.position = Vector3(0.0, 0.30, 0.05)
	_create_box(chest, Vector3(0.32, 0.30, 0.22), mat_dried_flesh, Vector3(0.0, 0.14, 0.0))
	# Двойные инъекторы со светящейся бирюзовой жижей в грудине
	_create_ooze_vial(chest, Vector3(-0.08, 0.15, 0.12), 0.035, 0.20, mat_ooze_cyan)
	_create_ooze_vial(chest, Vector3(0.08, 0.15, 0.12), 0.035, 0.20, mat_ooze_cyan)

	# Голова: вытянутая вперед морда с намордником-респиратором
	head.position = Vector3(0.0, 0.34, 0.10)
	_create_box(head, Vector3(0.18, 0.18, 0.24), mat_bone, Vector3(0.0, 0.09, 0.0))
	_create_box(head, Vector3(0.16, 0.12, 0.16), mat_cyber_dark, Vector3(0.0, 0.04, 0.10))
	# 4 светящихся сенсора на визоре
	_create_sphere(head, 0.022, mat_eye_red, Vector3(-0.05, 0.12, 0.12))
	_create_sphere(head, 0.022, mat_eye_red, Vector3(0.05, 0.12, 0.12))
	_create_sphere(head, 0.022, mat_eye_red, Vector3(-0.03, 0.06, 0.13))
	_create_sphere(head, 0.022, mat_eye_red, Vector3(0.03, 0.06, 0.13))
	# Иглы подачи стимулятора из затылка
	_create_cylinder(head, 0.012, 0.16, mat_ooze_cyan, Vector3(0.0, 0.14, -0.10)).rotation.x = deg_to_rad(45.0)

	# РУКИ: Оснащены вибро-лезвиями с зазубренными пилами
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.22, 0.24, 0.0)
		_create_cylinder(shoulder, 0.038, 0.26, mat_cyber_steel, Vector3(0.0, -0.13, 0.0))
		elbow.position = Vector3(0.0, -0.26, 0.0)
		_create_cylinder(elbow, 0.032, 0.26, mat_dried_flesh, Vector3(0.0, -0.13, 0.0))
		# Острое пилообразное лезвие на предплечье
		var blade := _create_box(elbow, Vector3(0.02, 0.42, 0.08), mat_saw_disc, Vector3(0.0, -0.38, 0.03))
		# Зубья на лезвии
		for tb in range(5):
			_create_box(blade, Vector3(0.025, 0.04, 0.03), mat_saw_teeth, Vector3(0.0, -0.14 + tb * 0.07, 0.05))

	# НОГИ: Изогнутые спринтерские пружинные лезвия (Blade Runners)
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.11, -0.05, 0.0)
		_create_cylinder(hip, 0.042, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(knee, 0.035, 0.40, mat_cyber_steel, Vector3(0.0, -0.20, -0.05))
		# Изогнутое лезвие стопы
		_create_box(knee, Vector3(0.04, 0.04, 0.28), mat_saw_disc, Vector3(0.0, -0.42, 0.08))
		# Пневматический цилиндр разгона со светящимся клапаном
		_create_cylinder(knee, 0.02, 0.22, mat_ooze_cyan, Vector3(side * 0.03, -0.16, -0.08))

# =========================================================================
# 3. БРОНИРОВАННЫЙ МЯСНИК-ДЖАГГЕРНАУТ (BRUTE)
# Колоссальный мутант с циркулярной мега-пилой и баком бурлящей жижи
# =========================================================================
func _build_brute() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.95, 0.0)
	_create_box(pelvis, Vector3(0.68, 0.32, 0.48), mat_cyber_dark)

	# Массивный торс, зажатый в промышленную броню
	torso.position = Vector3(0.0, 0.20, 0.0)
	_create_box(torso, Vector3(0.74, 0.42, 0.52), mat_dried_flesh, Vector3(0.0, 0.21, 0.0))
	_create_box(torso, Vector3(0.78, 0.20, 0.56), mat_cyber_steel, Vector3(0.0, 0.21, 0.0))

	chest.position = Vector3(0.0, 0.40, 0.0)
	_create_box(chest, Vector3(0.98, 0.62, 0.58), mat_cyber_dark, Vector3(0.0, 0.30, 0.0))
	_create_box(chest, Vector3(0.88, 0.16, 0.62), mat_hazard, Vector3(0.0, 0.20, 0.02))

	# БАК С БУРЛЯЩЕЙ ТОКСИЧНОЙ ЖИЖЕЙ НА СПИНЕ
	var vat := _create_cylinder(chest, 0.26, 0.65, mat_ooze_green, Vector3(0.0, 0.40, -0.34))
	_create_cylinder(vat, 0.28, 0.68, mat_canister_glass, Vector3(0.0, 0.0, 0.0))
	# Стальные обручи вокруг бака
	_create_cylinder(chest, 0.30, 0.08, mat_cyber_steel, Vector3(0.0, 0.22, -0.34))
	_create_cylinder(chest, 0.30, 0.08, mat_cyber_steel, Vector3(0.0, 0.58, -0.34))
	# Выхлопные трубы
	_create_cylinder(chest, 0.07, 0.50, mat_cyber_dark, Vector3(-0.35, 0.62, -0.30))
	_create_cylinder(chest, 0.07, 0.50, mat_cyber_dark, Vector3(0.35, 0.62, -0.30))

	# Голова: тяжелый палаческий шлем с горящей узкой амбразурой
	head.position = Vector3(0.0, 0.52, 0.08)
	_create_box(head, Vector3(0.40, 0.38, 0.40), mat_cyber_steel, Vector3(0.0, 0.16, 0.0))
	_create_box(head, Vector3(0.30, 0.05, 0.08), mat_eye_red, Vector3(0.0, 0.18, 0.20))
	# Толстые кабели в шею
	_create_cylinder(head, 0.035, 0.30, mat_cable_black, Vector3(-0.16, 0.05, -0.10)).rotation.x = deg_to_rad(30.0)
	_create_cylinder(head, 0.035, 0.30, mat_cable_black, Vector3(0.16, 0.05, -0.10)).rotation.x = deg_to_rad(30.0)

	# ЛЕВАЯ РУКА: ОГРОМНАЯ ТЯЖЕЛАЯ ДИСКОВАЯ МЕГА-ПИЛА
	l_shoulder.position = Vector3(-0.62, 0.46, 0.0)
	_create_cylinder(l_shoulder, 0.15, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
	l_elbow.position = Vector3(0.0, -0.36, 0.0)
	_create_box(l_elbow, Vector3(0.28, 0.44, 0.30), mat_cyber_steel, Vector3(0.0, -0.22, 0.0))
	# Мега-пила радиусом 0.36м с 16 зубьями
	_create_circular_saw(l_elbow, Vector3(0.0, -0.56, 0.08), 0.36, 16)

	# ПРАВАЯ РУКА: ГИДРАВЛИЧЕСКИЙ ДРОБЯЩИЙ ЗАХВАТ-КЛЕЩНЯ
	r_shoulder.position = Vector3(0.62, 0.46, 0.0)
	_create_cylinder(r_shoulder, 0.15, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
	r_elbow.position = Vector3(0.0, -0.36, 0.0)
	_create_cylinder(r_elbow, 0.13, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
	_create_box(r_elbow, Vector3(0.10, 0.48, 0.16), mat_saw_teeth, Vector3(-0.10, -0.54, 0.0))
	_create_box(r_elbow, Vector3(0.10, 0.48, 0.16), mat_saw_teeth, Vector3(0.10, -0.54, 0.0))
	# Шланг подачи жижи к клешне
	_create_cylinder(r_elbow, 0.03, 0.40, mat_ooze_green, Vector3(0.12, -0.25, 0.10))

	# НОГИ: Мощные колоннообразные поршни
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.26, -0.10, 0.0)
		_create_cylinder(hip, 0.15, 0.45, mat_cyber_dark, Vector3(0.0, -0.22, 0.0))
		knee.position = Vector3(0.0, -0.45, 0.0)
		_create_cylinder(knee, 0.14, 0.46, mat_cyber_steel, Vector3(0.0, -0.23, 0.0))
		_create_box(knee, Vector3(0.32, 0.18, 0.44), mat_cyber_dark, Vector3(0.0, -0.48, 0.08))

# =========================================================================
# 4. КИБЕР-ПАУК ПОЛЗУН (CRAWLER)
# Низко посаженный полутруп с клешнями-пилами и брюшком с жижей
# =========================================================================
func _build_crawler() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.35, 0.0)

	# Гусенично-паучий каркас
	_create_box(pelvis, Vector3(0.72, 0.28, 0.88), mat_cyber_dark)
	# Брюшко со светящейся зеленой жижей снизу
	_create_sphere(pelvis, 0.26, mat_ooze_green, Vector3(0.0, -0.06, -0.28))

	torso.position = Vector3(0.0, 0.18, -0.10)
	_create_box(torso, Vector3(0.48, 0.28, 0.38), mat_dried_flesh, Vector3(0.0, 0.14, 0.0))

	chest.position = Vector3(0.0, 0.26, 0.08)
	_create_box(chest, Vector3(0.52, 0.32, 0.36), mat_dried_flesh_dark, Vector3(0.0, 0.16, 0.0))
	_create_exposed_ribcage(chest, Vector3(0.0, 0.16, 0.05), 0.46, 0.28, 0.28, mat_ooze_green)

	# Голова с кластером из 5 зеленых глаз и жвалами
	head.position = Vector3(0.0, 0.30, 0.18)
	_create_box(head, Vector3(0.26, 0.22, 0.26), mat_bone, Vector3(0.0, 0.10, 0.0))
	# Глазной кластер
	_create_sphere(head, 0.035, mat_ooze_green, Vector3(-0.06, 0.14, 0.13))
	_create_sphere(head, 0.025, mat_ooze_green, Vector3(-0.02, 0.17, 0.13))
	_create_sphere(head, 0.030, mat_ooze_green, Vector3(-0.08, 0.08, 0.13))
	_create_sphere(head, 0.025, mat_ooze_green, Vector3(0.04, 0.14, 0.13))
	_create_sphere(head, 0.032, mat_ooze_green, Vector3(0.07, 0.09, 0.13))

	# ПЕРЕДНИЕ ЛАПЫ: Со спаренными циркулярными пилами-жвалами
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.36, 0.20, 0.12)
		_create_cylinder(shoulder, 0.08, 0.44, mat_cyber_steel, Vector3(side * 0.15, -0.10, 0.15))
		elbow.position = Vector3(side * 0.26, -0.22, 0.26)
		_create_cylinder(elbow, 0.06, 0.45, mat_cyber_dark, Vector3(0.0, -0.20, 0.10))
		# Пила на каждой клешне
		_create_circular_saw(elbow, Vector3(0.0, -0.48, 0.18), 0.20, 12)

# =========================================================================
# 5. ХИМИЧЕСКИЙ МУТАНТ-СПИТТЕР (SPITTER)
# Горбун с двойными баками кислоты, трубками и распылителем на челюсти
# =========================================================================
func _build_spitter() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.80, 0.0)
	_create_box(pelvis, Vector3(0.40, 0.18, 0.32), mat_dried_flesh_dark)

	torso.position = Vector3(0.0, 0.14, 0.0)
	_create_box(torso, Vector3(0.44, 0.32, 0.36), mat_dried_flesh, Vector3(0.0, 0.16, 0.0))

	# Грудь с огромным химическим горбом
	chest.position = Vector3(0.0, 0.30, 0.0)
	_create_box(chest, Vector3(0.50, 0.38, 0.40), mat_dried_flesh, Vector3(0.0, 0.18, 0.0))

	# ДВОЙНЫЕ ВЕРТИКАЛЬНЫЕ БАКИ С ЯДОВИТО-ЗЕЛЕНОЙ КИСЛОТОЙ
	_create_ooze_vial(chest, Vector3(-0.16, 0.36, -0.24), 0.09, 0.48, mat_ooze_green)
	_create_ooze_vial(chest, Vector3(0.16, 0.36, -0.24), 0.09, 0.48, mat_ooze_green)

	# Манометры и клапаны сброса давления
	_create_cylinder(chest, 0.04, 0.06, mat_hazard, Vector3(0.0, 0.45, -0.15))

	# Голова: противогазная маска с широким соплом-инжектором
	head.position = Vector3(0.0, 0.40, 0.06)
	_create_box(head, Vector3(0.25, 0.26, 0.26), mat_bone, Vector3(0.0, 0.12, 0.0))
	_create_cylinder(head, 0.05, 0.05, mat_ooze_green, Vector3(-0.06, 0.14, 0.14)).rotation.x = deg_to_rad(90.0)
	_create_cylinder(head, 0.05, 0.05, mat_ooze_green, Vector3(0.06, 0.14, 0.14)).rotation.x = deg_to_rad(90.0)
	# Распылительное сопло
	_create_cylinder(head, 0.06, 0.16, mat_cyber_steel, Vector3(0.0, 0.02, 0.18)).rotation.x = deg_to_rad(90.0)
	# ШЛАНГИ, ИДУЩИЕ ОТ БАКОВ ПРЯМО В ЧЕЛЮСТЬ
	_create_cylinder(chest, 0.025, 0.45, mat_cable_black, Vector3(-0.15, 0.30, 0.0)).rotation.x = deg_to_rad(40.0)
	_create_cylinder(chest, 0.025, 0.45, mat_cable_black, Vector3(0.15, 0.30, 0.0)).rotation.x = deg_to_rad(40.0)

	# Руки с химическими инжекторами
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.30, 0.26, 0.0)
		_create_cylinder(shoulder, 0.06, 0.26, mat_dried_flesh, Vector3(0.0, -0.13, 0.0))
		elbow.position = Vector3(0.0, -0.26, 0.0)
		_create_cylinder(elbow, 0.05, 0.26, mat_cyber_steel, Vector3(0.0, -0.13, 0.0))
		# Иглы-когти
		_create_box(elbow, Vector3(0.03, 0.22, 0.04), mat_ooze_green, Vector3(0.0, -0.32, 0.04))

	# Ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.15, -0.06, 0.0)
		_create_cylinder(hip, 0.065, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(knee, 0.055, 0.38, mat_cyber_steel, Vector3(0.0, -0.19, 0.0))

# =========================================================================
# 6. АКУСТИЧЕСКАЯ СИРЕНА (SCREAMER)
# Высокий высушенный труп с акустическим рупором и импульсными катушками
# =========================================================================
func _build_screamer() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.90, 0.0)
	_create_box(pelvis, Vector3(0.24, 0.12, 0.18), mat_dried_flesh_dark)

	torso.position = Vector3(0.0, 0.10, 0.0)
	_create_spine_vertebrae(torso, 4, 0.40, -0.04)

	chest.position = Vector3(0.0, 0.40, 0.0)
	_create_box(chest, Vector3(0.32, 0.32, 0.22), mat_dried_flesh, Vector3(0.0, 0.16, 0.0))
	# Катушки Теслы со светящейся бирюзовой жижей на плечах
	_create_ooze_vial(chest, Vector3(-0.16, 0.28, -0.08), 0.04, 0.26, mat_ooze_cyan)
	_create_ooze_vial(chest, Vector3(0.16, 0.28, -0.08), 0.04, 0.26, mat_ooze_cyan)

	# Голова: металлический каркас с гигантским акустическим раструбом
	head.position = Vector3(0.0, 0.42, 0.0)
	_create_box(head, Vector3(0.20, 0.22, 0.20), mat_bone, Vector3(0.0, 0.10, -0.04))
	var horn := _create_cylinder(head, 0.24, 0.26, mat_cyber_dark, Vector3(0.0, 0.14, 0.10))
	horn.rotation.x = deg_to_rad(90.0)
	var emitter := _create_cylinder(head, 0.17, 0.22, mat_ooze_cyan, Vector3(0.0, 0.14, 0.15))
	emitter.rotation.x = deg_to_rad(90.0)

	# Длинные тонкие руки-антенны
	for side in [-1.0, 1.0]:
		var shoulder : Node3D = l_shoulder if side < 0 else r_shoulder
		var elbow    : Node3D = l_elbow if side < 0 else r_elbow
		shoulder.position = Vector3(side * 0.20, 0.26, 0.0)
		_create_cylinder(shoulder, 0.035, 0.35, mat_cyber_steel, Vector3(0.0, -0.17, 0.0))
		elbow.position = Vector3(0.0, -0.35, 0.0)
		_create_cylinder(elbow, 0.025, 0.42, mat_saw_disc, Vector3(0.0, -0.21, 0.0))

	# Тонкие ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.09, -0.05, 0.0)
		_create_cylinder(hip, 0.04, 0.45, mat_cyber_dark, Vector3(0.0, -0.22, 0.0))
		knee.position = Vector3(0.0, -0.45, 0.0)
		_create_cylinder(knee, 0.03, 0.45, mat_cyber_steel, Vector3(0.0, -0.22, 0.0))

# =========================================================================
# 7. БИО-ТЕРМОЯДЕРНЫЙ КАМИКАДЗЕ (EXPLODER)
# Раздутый труп с реакторной капсулой нестабильной плазменной жижи
# =========================================================================
func _build_exploder() -> void:
	_init_base_rig()
	pelvis.position = Vector3(0.0, 0.70, 0.0)

	# Сферическая бронекапсула реактора
	_create_sphere(pelvis, 0.54, mat_cyber_dark, Vector3(0.0, 0.15, 0.0))
	# Огромное светящееся оранжевое плазменное ядро
	_create_sphere(pelvis, 0.42, mat_ooze_plasma, Vector3(0.0, 0.18, 0.16))
	# Предупреждающие желтые кольца с полосами опасности
	_create_box(pelvis, Vector3(1.15, 0.09, 1.15), mat_hazard, Vector3(0.0, 0.15, 0.0))

	# Ампулы нестабильной смеси по периметру реактора
	for a in range(4):
		var ang : float = float(a) * (PI * 0.5) + deg_to_rad(45.0)
		var vx : float = cos(ang) * 0.52
		var vz : float = sin(ang) * 0.52
		_create_ooze_vial(pelvis, Vector3(vx, 0.15, vz), 0.05, 0.32, mat_ooze_green)

	# Голова с мигающим тревожным маячком
	head.position = Vector3(0.0, 0.72, 0.0)
	_create_box(head, Vector3(0.22, 0.20, 0.22), mat_bone, Vector3(0.0, 0.08, 0.0))
	_create_cylinder(head, 0.07, 0.14, mat_cyber_dark, Vector3(0.0, 0.20, 0.0))
	_create_cylinder(head, 0.055, 0.16, mat_eye_red, Vector3(0.0, 0.28, 0.0))

	# 4 устойчивые гидро-ноги
	for side in [-1.0, 1.0]:
		var hip  : Node3D = l_hip if side < 0 else r_hip
		var knee : Node3D = l_knee if side < 0 else r_knee
		hip.position = Vector3(side * 0.36, 0.0, 0.18)
		_create_cylinder(hip, 0.08, 0.36, mat_cyber_steel, Vector3(0.0, -0.18, 0.0))
		knee.position = Vector3(0.0, -0.36, 0.0)
		_create_cylinder(knee, 0.07, 0.36, mat_cyber_dark, Vector3(0.0, -0.18, 0.0))

# =========================================================================
# УНИВЕРСАЛЬНАЯ ПРОЦЕДУРНАЯ АНИМАЦИЯ 3D КИБОРГОВ С ЖИВЫМИ ВРАЩАЮЩИМИСЯ ПИЛАМИ
# =========================================================================
func update_animation(delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	is_moving = moving
	walk_speed_mult = move_speed
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	# 1. ЖИВОЕ ВРАЩЕНИЕ ВСЕХ ДИСКОВЫХ ПИЛ
	# При атаке пилы раскручиваются до бешеной скорости (35 рад/с), при ходьбе - 16 рад/с
	var saw_speed : float = (38.0 if is_attacking else 18.0) * delta
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

	# Анимация рук и взмахов пилы
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

	# Замах пилой и сокрушительный рез вперед
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
