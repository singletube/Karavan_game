extends Node3D

class_name CaravanModel3D

# --- Цвета и материалы ---
var mat_wood_dark: StandardMaterial3D
var mat_wood_light: StandardMaterial3D
var mat_iron: StandardMaterial3D
var mat_cloth: StandardMaterial3D
var mat_cargo_crate: StandardMaterial3D
var mat_cargo_sack: StandardMaterial3D

# Осёл
var mat_donkey_fur: StandardMaterial3D
var mat_donkey_muzzle: StandardMaterial3D
var mat_donkey_dark: StandardMaterial3D
var mat_leather: StandardMaterial3D

# Узлы для анимации
var wheels: Array[Node3D] = []
var donkey_root: Node3D
var donkey_head: Node3D
var donkey_ears: Array[Node3D] = []
var donkey_legs: Array[Node3D] = [] # FL, FR, BL, BR
var donkey_tail: Node3D
var canopy_root: Node3D
var lantern_light: OmniLight3D

func _init() -> void:
	_init_materials()

func _ready() -> void:
	_build_carriage()
	_build_donkey()

func _init_materials() -> void:
	mat_wood_dark = StandardMaterial3D.new()
	mat_wood_dark.albedo_color = Color(0.42, 0.28, 0.16, 1.0)
	mat_wood_dark.roughness = 0.85

	mat_wood_light = StandardMaterial3D.new()
	mat_wood_light.albedo_color = Color(0.62, 0.44, 0.28, 1.0)
	mat_wood_light.roughness = 0.8

	mat_iron = StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.22, 0.22, 0.24, 1.0)
	mat_iron.metallic = 0.7
	mat_iron.roughness = 0.4

	mat_cloth = StandardMaterial3D.new()
	mat_cloth.albedo_color = Color(0.86, 0.80, 0.68, 1.0)
	mat_cloth.roughness = 0.95

	mat_cargo_crate = StandardMaterial3D.new()
	mat_cargo_crate.albedo_color = Color(0.55, 0.38, 0.22, 1.0)
	mat_cargo_crate.roughness = 0.75

	mat_cargo_sack = StandardMaterial3D.new()
	mat_cargo_sack.albedo_color = Color(0.72, 0.64, 0.48, 1.0)
	mat_cargo_sack.roughness = 0.9

	# Осёл
	mat_donkey_fur = StandardMaterial3D.new()
	mat_donkey_fur.albedo_color = Color(0.48, 0.45, 0.42, 1.0)
	mat_donkey_fur.roughness = 0.9

	mat_donkey_muzzle = StandardMaterial3D.new()
	mat_donkey_muzzle.albedo_color = Color(0.80, 0.76, 0.70, 1.0)
	mat_donkey_muzzle.roughness = 0.85

	mat_donkey_dark = StandardMaterial3D.new()
	mat_donkey_dark.albedo_color = Color(0.18, 0.16, 0.15, 1.0)
	mat_donkey_dark.roughness = 0.6

	mat_leather = StandardMaterial3D.new()
	mat_leather.albedo_color = Color(0.32, 0.18, 0.10, 1.0)
	mat_leather.roughness = 0.6

func _create_box(parent: Node, size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
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
	parent.add_child(mi)
	return mi

# =========================================================================
# 1. КАРЕТА / ПОВОЗКА (КАРАВАН)
# =========================================================================
func _build_carriage() -> void:
	var carriage := Node3D.new()
	carriage.name = "Carriage"
	add_child(carriage)

	# Днище кузова (толстая деревянная платформа на высоте 0.65 над землей)
	# Длина 3.6м, ширина 2.2м, толщина 0.15м
	_create_box(carriage, Vector3(2.2, 0.15, 3.6), mat_wood_dark, Vector3(0.0, 0.65, 0.0))

	# Продольные и поперечные балки рамы снизу
	_create_box(carriage, Vector3(0.18, 0.18, 3.8), mat_wood_dark, Vector3(-0.9, 0.52, 0.0))
	_create_box(carriage, Vector3(0.18, 0.18, 3.8), mat_wood_dark, Vector3(0.9, 0.52, 0.0))
	_create_box(carriage, Vector3(2.1, 0.16, 0.16), mat_iron, Vector3(0.0, 0.48, -1.2)) # Передняя ось
	_create_box(carriage, Vector3(2.1, 0.16, 0.16), mat_iron, Vector3(0.0, 0.48, 1.2))  # Задняя ось

	# Борта кузова (деревянные доски):
	# Левый борт
	_create_box(carriage, Vector3(0.1, 0.7, 3.6), mat_wood_light, Vector3(-1.05, 1.05, 0.0))
	# Правый борт
	_create_box(carriage, Vector3(0.1, 0.7, 3.6), mat_wood_light, Vector3(1.05, 1.05, 0.0))
	# Передний борт
	_create_box(carriage, Vector3(2.2, 0.8, 0.1), mat_wood_light, Vector3(0.0, 1.1, -1.75))
	# Задний борт (низкий откидной бортик для удобного запрыгивания)
	_create_box(carriage, Vector3(2.2, 0.4, 0.1), mat_wood_light, Vector3(0.0, 0.9, 1.75))

	# Угловые вертикальные стойки
	var post_positions := [
		Vector3(-1.05, 1.1, -1.75), Vector3(1.05, 1.1, -1.75),
		Vector3(-1.05, 1.1, 0.0),    Vector3(1.05, 1.1, 0.0),
		Vector3(-1.05, 1.1, 1.75),  Vector3(1.05, 1.1, 1.75)
	]
	for p: Vector3 in post_positions:
		_create_box(carriage, Vector3(0.12, 0.85, 0.12), mat_wood_dark, p)

	# Высокие опорные стойки для просторной высокой крыши (высота до 3.4м)
	var canopy_posts := [
		Vector3(-1.05, 2.1, -1.6), Vector3(1.05, 2.1, -1.6),
		Vector3(-1.05, 2.1, 0.1),  Vector3(1.05, 2.1, 0.1),
		Vector3(-1.05, 2.1, 1.6),  Vector3(1.05, 2.1, 1.6)
	]
	for cp: Vector3 in canopy_posts:
		_create_box(carriage, Vector3(0.1, 2.1, 0.1), mat_wood_dark, cp)

	# Тент / высокий балдахин (просторная арочная крыша на высоте 3.5м над землей)
	canopy_root = Node3D.new()
	canopy_root.name = "Canopy"
	carriage.add_child(canopy_root)
	# Изогнутые поперечные дуги тента
	_create_box(canopy_root, Vector3(2.3, 0.08, 0.08), mat_wood_dark, Vector3(0.0, 3.42, -1.6))
	_create_box(canopy_root, Vector3(2.3, 0.08, 0.08), mat_wood_dark, Vector3(0.0, 3.42, 0.1))
	_create_box(canopy_root, Vector3(2.3, 0.08, 0.08), mat_wood_dark, Vector3(0.0, 3.42, 1.6))
	# Продольные перекладины конька крыши
	_create_box(canopy_root, Vector3(0.08, 0.08, 3.6), mat_wood_dark, Vector3(0.0, 3.46, 0.0))
	# Верхняя ткань тента
	_create_box(canopy_root, Vector3(2.35, 0.06, 3.6), mat_cloth, Vector3(0.0, 3.5, 0.0))
	# Свисающие края тента по бокам
	_create_box(canopy_root, Vector3(0.06, 0.65, 3.6), mat_cloth, Vector3(-1.18, 3.15, 0.0))
	_create_box(canopy_root, Vector3(0.06, 0.65, 3.6), mat_cloth, Vector3(1.18, 3.15, 0.0))

	# Декоративный груз каравана в передней части кузова (ящики и мешки с пряностями)
	_create_box(carriage, Vector3(0.65, 0.55, 0.65), mat_cargo_crate, Vector3(-0.65, 0.95, -1.2))
	_create_box(carriage, Vector3(0.55, 0.45, 0.55), mat_cargo_crate, Vector3(-0.65, 1.45, -1.2))
	_create_box(carriage, Vector3(0.7, 0.6, 0.5), mat_cargo_crate, Vector3(0.65, 0.98, -1.25))
	_create_cylinder(carriage, 0.28, 0.65, mat_cargo_sack, Vector3(0.2, 1.0, -1.35))
	_create_cylinder(carriage, 0.25, 0.55, mat_cargo_sack, Vector3(-0.15, 0.95, -1.35))

	# Фонарь караванщика на передней стойке
	var lantern_post := _create_box(carriage, Vector3(0.06, 0.35, 0.06), mat_iron, Vector3(1.15, 1.6, -1.75))
	_create_box(lantern_post, Vector3(0.18, 0.22, 0.18), mat_donkey_dark, Vector3(0.0, -0.05, 0.0))
	lantern_light = OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.75, 0.35, 1.0)
	lantern_light.light_energy = 2.5
	lantern_light.omni_range = 8.0
	lantern_post.add_child(lantern_light)

	# 4 больших деревянных колеса со спицами и железными ободами
	var wheel_data := [
		Vector3(-1.18, 0.55, -1.2), # Переднее левое
		Vector3(1.18, 0.55, -1.2),  # Переднее правое
		Vector3(-1.18, 0.55, 1.2),  # Заднее левое
		Vector3(1.18, 0.55, 1.2)   # Заднее правое
	]
	for wpos: Vector3 in wheel_data:
		var wheel := _build_wheel()
		wheel.position = wpos
		carriage.add_child(wheel)
		wheels.append(wheel)

	# Дышло и упряжь (соединение повозки с ослом)
	_create_box(carriage, Vector3(0.12, 0.12, 2.2), mat_wood_dark, Vector3(-0.4, 0.55, -2.8))
	_create_box(carriage, Vector3(0.12, 0.12, 2.2), mat_wood_dark, Vector3(0.4, 0.55, -2.8))
	_create_box(carriage, Vector3(1.0, 0.1, 0.1), mat_wood_dark, Vector3(0.0, 0.55, -3.8))

func _build_wheel() -> Node3D:
	var w := Node3D.new()
	# Железный обод
	var rim := _create_cylinder(w, 0.52, 0.12, mat_iron)
	rim.rotation.z = PI * 0.5

	# Деревянная ступица
	var hub := _create_cylinder(w, 0.15, 0.16, mat_wood_dark)
	hub.rotation.z = PI * 0.5

	# 6 деревянных спиц
	for i in range(3):
		var spoke := _create_box(w, Vector3(0.06, 0.94, 0.06), mat_wood_light)
		spoke.rotation.x = float(i) * (PI / 3.0)

	return w

# =========================================================================
# 2. ОСЁЛ (АНИМИРОВАННЫЙ 3D ПЕРСОНАЖ КАРАВАНА)
# =========================================================================
func _build_donkey() -> void:
	donkey_root = Node3D.new()
	donkey_root.name = "Donkey"
	# Осёл находится впереди повозки (Z = -4.2)
	donkey_root.position = Vector3(0.0, 0.0, -4.2)
	add_child(donkey_root)

	# Туловище осла (овальное, высота центра ~0.95)
	var body := _create_box(donkey_root, Vector3(0.65, 0.70, 1.45), mat_donkey_fur, Vector3(0.0, 0.95, 0.0))
	# Светлый живот
	_create_box(body, Vector3(0.55, 0.22, 1.35), mat_donkey_muzzle, Vector3(0.0, -0.26, 0.0))
	# Вьючное седло / упряжь на спине
	_create_box(body, Vector3(0.72, 0.25, 0.65), mat_leather, Vector3(0.0, 0.32, 0.0))

	# Шея (наклонена вперед и вверх)
	var neck := _create_box(donkey_root, Vector3(0.38, 0.65, 0.42), mat_donkey_fur, Vector3(0.0, 1.35, -0.65), Vector3(deg_to_rad(28.0), 0.0, 0.0))
	# Темная грива
	_create_box(neck, Vector3(0.12, 0.68, 0.18), mat_donkey_dark, Vector3(0.0, 0.02, 0.22))

	# Голова осла
	donkey_head = Node3D.new()
	donkey_head.name = "DonkeyHead"
	donkey_head.position = Vector3(0.0, 1.62, -0.88)
	donkey_root.add_child(donkey_head)

	# Череп
	_create_box(donkey_head, Vector3(0.36, 0.38, 0.52), mat_donkey_fur, Vector3(0.0, 0.0, 0.0))
	# Морда (вытянутая вперед и вниз со светлым носом)
	_create_box(donkey_head, Vector3(0.30, 0.28, 0.42), mat_donkey_muzzle, Vector3(0.0, -0.12, -0.38))
	# Черный кончик носа / ноздри
	_create_box(donkey_head, Vector3(0.24, 0.14, 0.12), mat_donkey_dark, Vector3(0.0, -0.15, -0.58))
	# Глаза
	_create_box(donkey_head, Vector3(0.40, 0.09, 0.09), mat_donkey_dark, Vector3(0.0, 0.08, -0.08))

	# Длинные характерные уши осла!
	var ear_left := _create_box(donkey_head, Vector3(0.12, 0.45, 0.08), mat_donkey_fur, Vector3(-0.16, 0.38, 0.12), Vector3(deg_to_rad(-18.0), deg_to_rad(-15.0), deg_to_rad(-22.0)))
	_create_box(ear_left, Vector3(0.07, 0.38, 0.04), mat_donkey_muzzle, Vector3(0.0, 0.0, -0.03))
	donkey_ears.append(ear_left)

	var ear_right := _create_box(donkey_head, Vector3(0.12, 0.45, 0.08), mat_donkey_fur, Vector3(0.16, 0.38, 0.12), Vector3(deg_to_rad(-18.0), deg_to_rad(15.0), deg_to_rad(22.0)))
	_create_box(ear_right, Vector3(0.07, 0.38, 0.04), mat_donkey_muzzle, Vector3(0.0, 0.0, -0.03))
	donkey_ears.append(ear_right)

	# 4 ноги осла с копытами
	var leg_coords := [
		Vector3(-0.24, 0.72, -0.48), # Передняя левая
		Vector3(0.24, 0.72, -0.48),  # Передняя правая
		Vector3(-0.24, 0.72, 0.48),  # Задняя левая
		Vector3(0.24, 0.72, 0.48)   # Задняя правая
	]
	for lpos: Vector3 in leg_coords:
		var leg_pivot := Node3D.new()
		leg_pivot.position = lpos
		donkey_root.add_child(leg_pivot)

		# Верхняя часть ноги
		_create_box(leg_pivot, Vector3(0.16, 0.42, 0.18), mat_donkey_fur, Vector3(0.0, -0.21, 0.0))
		# Нижняя часть ноги
		_create_box(leg_pivot, Vector3(0.13, 0.35, 0.14), mat_donkey_fur, Vector3(0.0, -0.52, 0.0))
		# Темное копыто
		_create_box(leg_pivot, Vector3(0.15, 0.12, 0.17), mat_donkey_dark, Vector3(0.0, -0.71, 0.01))

		donkey_legs.append(leg_pivot)

	# Хвост с кисточкой
	donkey_tail = Node3D.new()
	donkey_tail.position = Vector3(0.0, 1.05, 0.72)
	donkey_root.add_child(donkey_tail)
	_create_cylinder(donkey_tail, 0.04, 0.45, mat_donkey_fur, Vector3(0.0, -0.22, 0.08), Vector3(deg_to_rad(15.0), 0.0, 0.0))
	_create_box(donkey_tail, Vector3(0.12, 0.18, 0.12), mat_donkey_dark, Vector3(0.0, -0.46, 0.14))

# =========================================================================
# 3. АНИМАЦИЯ ХОДЬБЫ И ДВИЖЕНИЯ
# =========================================================================
func update_animation(delta: float, is_moving: bool, move_speed: float, walk_phase: float) -> void:
	if is_moving:
		# Вращение колес в соответствии со скоростью (радиус ~0.52)
		var wheel_rot: float = (move_speed / 0.52) * delta
		for w: Node3D in wheels:
			w.rotate_x(wheel_rot)

		# Шаг осла: передние и задние ноги двигаются диагонально (FL-BR, FR-BL)
		var leg_angle: float = sin(walk_phase * 4.0) * deg_to_rad(28.0)
		if donkey_legs.size() >= 4:
			donkey_legs[0].rotation.x = leg_angle       # Передняя левая
			donkey_legs[1].rotation.x = -leg_angle      # Передняя правая
			donkey_legs[2].rotation.x = -leg_angle      # Задняя левая
			donkey_legs[3].rotation.x = leg_angle       # Задняя правая

		# Покачивание туловища и головы осла
		if donkey_root:
			donkey_root.position.y = abs(sin(walk_phase * 8.0)) * 0.04
		if donkey_head:
			donkey_head.rotation.x = sin(walk_phase * 4.0) * deg_to_rad(6.0)

		# Шевеление ушами осла
		if donkey_ears.size() >= 2:
			donkey_ears[0].rotation.z = deg_to_rad(-22.0) + sin(walk_phase * 3.0) * deg_to_rad(6.0)
			donkey_ears[1].rotation.z = deg_to_rad(22.0) - cos(walk_phase * 3.0) * deg_to_rad(6.0)

		# Виляние хвоста
		if donkey_tail:
			donkey_tail.rotation.z = sin(walk_phase * 5.0) * deg_to_rad(18.0)

		# Мягкое покачивание тента повозки на песчаных неровностях
		if canopy_root:
			canopy_root.rotation.z = sin(walk_phase * 2.0) * deg_to_rad(1.2)
			canopy_root.rotation.x = cos(walk_phase * 2.5) * deg_to_rad(1.0)
	else:
		# Остановка — возврат ног в исходное положение
		for l: Node3D in donkey_legs:
			l.rotation.x = lerp_angle(l.rotation.x, 0.0, delta * 8.0)
		if donkey_tail:
			donkey_tail.rotation.z = sin(walk_phase * 1.5) * deg_to_rad(8.0)
