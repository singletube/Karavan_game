extends Node
class_name DesertScenery3D

const PropModels3D = preload("res://scripts/prop_models_3d.gd")

# --- Фабрика процедурных 3D моделей окружения пустыни ---
# Заменяет все 2D билборды на детализированные 3D меши с PBR-материалами и тенями

static var mat_bark     : StandardMaterial3D
static var mat_cactus   : StandardMaterial3D
static var mat_rust     : StandardMaterial3D
static var mat_metal    : StandardMaterial3D
static var mat_tire     : StandardMaterial3D
static var mat_bone     : StandardMaterial3D
static var mat_horn     : StandardMaterial3D
static var mat_straw    : StandardMaterial3D
static var mat_sign_yellow : StandardMaterial3D
static var mat_stone_cairn : StandardMaterial3D
static var mat_scrub_bush  : StandardMaterial3D
static var mat_insulator   : StandardMaterial3D

static func _load_tex(filename: String) -> Texture2D:
	var path := "res://assets/textures/props/" + filename
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			return res
	var os_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(os_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func _ensure_materials() -> void:
	if mat_bark != null:
		return

	# Высушенная растрескавшаяся кора мертвого дерева
	mat_bark = StandardMaterial3D.new()
	mat_bark.albedo_color = Color(0.24, 0.20, 0.17)
	mat_bark.roughness = 0.95
	var tex_bark := _load_tex("palm_bark.png")
	if tex_bark:
		mat_bark.albedo_texture = tex_bark
		mat_bark.uv1_scale = Vector3(1.0, 3.0, 1.0)

	# Пустынный кактус Сагуаро (ребристый зеленый с восковым налетом)
	mat_cactus = StandardMaterial3D.new()
	mat_cactus.albedo_color = Color(0.22, 0.46, 0.20)
	mat_cactus.roughness = 0.80
	var tex_cactus := _load_tex("cactus_skin.png")
	if tex_cactus:
		mat_cactus.albedo_texture = tex_cactus
		mat_cactus.uv1_scale = Vector3(2.0, 4.0, 2.0)

	# Ржавый металл остова машины
	mat_rust = StandardMaterial3D.new()
	mat_rust.albedo_color = Color(0.38, 0.22, 0.15)
	mat_rust.metallic = 0.35
	mat_rust.roughness = 0.88
	var tex_rust := _load_tex("corrugated_rust.png")
	if tex_rust:
		mat_rust.albedo_texture = tex_rust
		mat_rust.uv1_scale = Vector3(1.5, 1.5, 1.5)

	# Темный обгоревший каркас и детали
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.18, 0.18, 0.19)
	mat_metal.metallic = 0.8
	mat_metal.roughness = 0.45
	var tex_metal := _load_tex("blued_metal.png")
	if tex_metal:
		mat_metal.albedo_texture = tex_metal

	# Резина полуспущенных колес
	mat_tire = StandardMaterial3D.new()
	mat_tire.albedo_color = Color(0.10, 0.10, 0.10)
	mat_tire.roughness = 0.95
	var tex_tire := _load_tex("tire_tread.png")
	if tex_tire:
		mat_tire.albedo_texture = tex_tire
		mat_tire.uv1_scale = Vector3(3.0, 1.0, 1.0)

	# Выбеленный солнцем череп и кости
	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color(0.85, 0.82, 0.74)
	mat_bone.roughness = 0.70
	var tex_bone := _load_tex("skull_bone.png")
	if tex_bone:
		mat_bone.albedo_texture = tex_bone

	# Рога буйвола
	mat_horn = StandardMaterial3D.new()
	mat_horn.albedo_color = Color(0.30, 0.26, 0.22)
	mat_horn.roughness = 0.65

	# Сухие ветви перекати-поле
	mat_straw = StandardMaterial3D.new()
	mat_straw.albedo_color = Color(0.68, 0.54, 0.35)
	mat_straw.roughness = 0.95

	# Выцветший желтый дорожный знак
	mat_sign_yellow = StandardMaterial3D.new()
	mat_sign_yellow.albedo_color = Color(0.85, 0.68, 0.15)
	mat_sign_yellow.roughness = 0.60
	var tex_sign := _load_tex("warning_sign_cyborg.png")
	if tex_sign:
		mat_sign_yellow.albedo_texture = tex_sign

	# Каменные плиты тура караванщиков
	mat_stone_cairn = StandardMaterial3D.new()
	mat_stone_cairn.albedo_color = Color(0.55, 0.45, 0.34)
	mat_stone_cairn.roughness = 0.92
	var tex_cairn := _load_tex("red_canyon_rock.png")
	if tex_cairn:
		mat_stone_cairn.albedo_texture = tex_cairn
		mat_stone_cairn.uv1_scale = Vector3(1.2, 1.2, 1.2)

	# Сухой пустынный кустарник
	mat_scrub_bush = StandardMaterial3D.new()
	mat_scrub_bush.albedo_color = Color(0.48, 0.44, 0.24)
	mat_scrub_bush.roughness = 0.90

	# Белый керамический изолятор столба
	mat_insulator = StandardMaterial3D.new()
	mat_insulator.albedo_color = Color(0.88, 0.90, 0.92)
	mat_insulator.roughness = 0.25

# -------------------------------------------------------------------------
# Вспомогательные функции построения
# -------------------------------------------------------------------------
static func _add_box(parent: Node3D, sz: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	box.material = mat
	mi.mesh = box
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _add_cyl(parent: Node3D, height: float, top_r: float, bot_r: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, segs: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = height
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.radial_segments = segs
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# =========================================================================
# 1. 3D МЕРТВОЕ ДЕРЕВО (Ствол + ветвящиеся сучья)
# =========================================================================
static func create_dead_tree_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "DeadTree3D"

	# Корневая база и нижний ствол
	_add_cyl(root, 2.5, 0.32, 0.45, mat_bark, Vector3(0, 1.25, 0), Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.06, 0.06)))
	# Верхний искривленный ствол
	_add_cyl(root, 2.2, 0.22, 0.32, mat_bark, Vector3(0.12, 3.4, 0.08), Vector3(0.14, randf_range(0, PI), -0.12))

	# 4 ветки в разные стороны под разными углами
	var branch_angles: Array[float] = [0.2, 1.8, 3.4, 4.9]
	for ang in branch_angles:
		var dir_x: float = cos(ang)
		var dir_z: float = sin(ang)
		var branch_base := Vector3(dir_x * 0.25 + 0.08, 3.0 + randf_range(-0.3, 0.5), dir_z * 0.25)

		# Основная толстая ветвь
		var b1 := _add_cyl(root, 1.8, 0.12, 0.20, mat_bark, branch_base + Vector3(dir_x * 0.7, 0.6, dir_z * 0.7), Vector3(dir_z * 0.7, 0, -dir_x * 0.7))

		# Тонкое корявое ответвление
		var b2_pos := branch_base + Vector3(dir_x * 1.5, 1.2, dir_z * 1.5)
		_add_cyl(root, 1.2, 0.05, 0.12, mat_bark, b2_pos, Vector3(dir_z * 1.1, 0, -dir_x * 1.1))

	return root

# =========================================================================
# 2. 3D РАЗБИТАЯ РЖАВАЯ МАШИНА (Кузов, капот, кабина, кузов пикапа, 4 колеса)
# =========================================================================
static func create_wrecked_car_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "WreckedCar3D"

	# Рама / шасси
	_add_box(root, Vector3(3.6, 0.35, 1.7), mat_metal, Vector3(0, 0.35, 0))

	# Капот пикапа
	_add_box(root, Vector3(1.3, 0.6, 1.6), mat_rust, Vector3(1.1, 0.7, 0))

	# Разбитая кабина (с вырезом для лобового стекла)
	_add_box(root, Vector3(1.1, 0.85, 1.55), mat_rust, Vector3(-0.1, 1.05, 0))
	# Крыша кабины со вмятиной
	_add_box(root, Vector3(1.2, 0.1, 1.6), mat_metal, Vector3(-0.1, 1.5, 0), Vector3(0.05, 0, -0.06))

	# Кузов пикапа сзади
	_add_box(root, Vector3(1.2, 0.5, 1.6), mat_rust, Vector3(-1.25, 0.65, 0))
	_add_box(root, Vector3(0.1, 0.45, 1.6), mat_metal, Vector3(-1.85, 0.65, 0)) # задний борт

	# Бамперы
	_add_box(root, Vector3(0.2, 0.25, 1.8), mat_metal, Vector3(1.8, 0.35, 0))
	_add_box(root, Vector3(0.2, 0.25, 1.8), mat_metal, Vector3(-1.85, 0.35, 0))

	# 4 полуспущенных, покосившихся колеса
	var wheel_offsets: Array[Vector3] = [
		Vector3(1.1, 0.38, 0.88),
		Vector3(1.1, 0.38, -0.88),
		Vector3(-1.1, 0.38, 0.88),
		Vector3(-1.1, 0.38, -0.88),
	]
	for wo in wheel_offsets:
		var tilt_z: float = randf_range(-0.15, 0.15)
		_add_cyl(root, 0.32, 0.36, 0.36, mat_tire, wo, Vector3(PI / 2.0, 0, tilt_z), 12)
		# Колесный диск
		_add_cyl(root, 0.34, 0.18, 0.18, mat_rust, wo, Vector3(PI / 2.0, 0, tilt_z), 8)

	return root

# =========================================================================
# 3. 3D КАКТУС САГУАРО (ВЫСОКОДЕТАЛИЗИРОВАННЫЙ ИЗ БИБЛИОТЕКИ ПРОПОВ)
# =========================================================================
static func create_cactus_3d() -> Node3D:
	return PropModels3D.create_cactus_detailed()

# =========================================================================
# 4. 3D ЧЕРЕП И КОСТИ В ПЕСКЕ (ЧЕРЕП КИБОРГА / ЧЕЛОВЕКА + РЕБРА)
# =========================================================================
static func create_skull_bones_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "Bones3D"

	# В 50% случаев — зловещий череп киборга с красным глазом, в 50% — бычий/человеческий череп
	if randf() < 0.55:
		var cyb_skull := PropModels3D.create_skull_cyborg()
		cyb_skull.position = Vector3(0, 0.04, 0.1)
		cyb_skull.rotation = Vector3(deg_to_rad(randf_range(-15, 15)), deg_to_rad(randf_range(0, 360)), deg_to_rad(randf_range(-20, 20)))
		root.add_child(cyb_skull)
	else:
		# Черепная коробка быка с рогами
		_add_box(root, Vector3(0.35, 0.28, 0.45), mat_bone, Vector3(0, 0.06, 0))
		_add_box(root, Vector3(0.24, 0.20, 0.35), mat_bone, Vector3(0, 0.02, 0.35))
		_add_box(root, Vector3(0.08, 0.08, 0.08), mat_metal, Vector3(-0.14, 0.10, 0.10))
		_add_box(root, Vector3(0.08, 0.08, 0.08), mat_metal, Vector3(0.14, 0.10, 0.10))
		_add_cyl(root, 0.45, 0.05, 0.10, mat_horn, Vector3(-0.35, 0.16, -0.05), Vector3(0.2, 0.4, -1.0))
		_add_cyl(root, 0.30, 0.02, 0.05, mat_horn, Vector3(-0.55, 0.30, 0.05), Vector3(-0.2, 0.6, -0.6))
		_add_cyl(root, 0.45, 0.05, 0.10, mat_horn, Vector3(0.35, 0.16, -0.05), Vector3(0.2, -0.4, 1.0))
		_add_cyl(root, 0.30, 0.02, 0.05, mat_horn, Vector3(0.55, 0.30, 0.05), Vector3(-0.2, -0.6, 0.6))

	# Рядом торчащие из песка ребра
	for r in range(4):
		var rib_z: float = -0.3 - float(r) * 0.22
		var rib_w: float = 0.55 - float(r) * 0.05
		_add_cyl(root, 0.45, 0.04, 0.04, mat_bone, Vector3(-rib_w * 0.5, 0.06, rib_z), Vector3(0, 0, -0.7))
		_add_cyl(root, 0.45, 0.04, 0.04, mat_bone, Vector3(rib_w * 0.5, 0.06, rib_z), Vector3(0, 0, 0.7))

	return root

# =========================================================================
# 5. 3D ПЕРЕКАТИ-ПОЛЕ (Пересекающиеся объемные каркасные кольца из прутьев)
# =========================================================================
static func create_tumbleweed_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "Tumbleweed3D"

	# Создаем сферу из переплетенных ветвей и торов/ободов
	var radii: Array[float] = [0.42, 0.40, 0.38, 0.44]
	var rotations: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(PI / 2.0, 0, 0),
		Vector3(0, 0, PI / 2.0),
		Vector3(PI / 4.0, PI / 4.0, 0),
		Vector3(-PI / 4.0, PI / 3.0, PI / 6.0),
		Vector3(PI / 3.0, -PI / 4.0, -PI / 3.0)
	]

	for rot in rotations:
		# Создаем кольцо из тонких сегментов
		var segments: int = 8
		var r: float = 0.40
		for s in range(segments):
			var a1: float = float(s) * (TAU / float(segments))
			var a2: float = float(s + 1) * (TAU / float(segments))
			var mid_a: float = (a1 + a2) * 0.5
			var pos := Vector3(cos(mid_a) * r, sin(mid_a) * r, 0)
			var length: float = r * (TAU / float(segments)) * 1.05
			var cyl := _add_cyl(root, length, 0.022, 0.022, mat_straw, pos, Vector3(0, 0, mid_a + PI / 2.0), 5)
			# Поворачиваем вокруг центра
			if rot.length_squared() > 0.0001:
				cyl.transform = Transform3D().rotated(rot.normalized(), rot.length()) * cyl.transform

	# Внутренний сгусток сухих веток в сердцевине
	_add_box(root, Vector3(0.24, 0.24, 0.24), mat_straw, Vector3.ZERO, Vector3(0.4, 0.7, 0.2))

	return root

# =========================================================================
# 6. КАМЕННЫЙ ТУР / ПИРАМИДКА ИЗ КАМНЕЙ (STONE CAIRN)
# Древний каменный ориентир караванщиков в песках
# =========================================================================
static func create_stone_cairn_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "StoneCairn3D"

	# 5 сложенных друг на друга плоских камней
	_add_box(root, Vector3(1.1, 0.32, 1.0), mat_stone_cairn, Vector3(0.0, 0.16, 0.0), Vector3(0.0, deg_to_rad(12.0), 0.0))
	_add_box(root, Vector3(0.92, 0.28, 0.88), mat_stone_cairn, Vector3(0.04, 0.46, -0.03), Vector3(0.04, deg_to_rad(-24.0), -0.03))
	_add_box(root, Vector3(0.72, 0.25, 0.68), mat_stone_cairn, Vector3(-0.03, 0.72, 0.02), Vector3(-0.03, deg_to_rad(35.0), 0.04))
	_add_box(root, Vector3(0.52, 0.22, 0.50), mat_stone_cairn, Vector3(0.02, 0.95, -0.02), Vector3(0.02, deg_to_rad(-12.0), -0.02))
	_add_box(root, Vector3(0.34, 0.22, 0.32), mat_stone_cairn, Vector3(-0.01, 1.17, 0.01), Vector3(0.05, deg_to_rad(55.0), 0.03))

	# Мелкие опорные камешки вокруг основания
	for i in range(4):
		var a: float = float(i) * (TAU / 4.0) + 0.3
		_add_box(root, Vector3(0.3, 0.18, 0.28), mat_stone_cairn, Vector3(cos(a) * 0.7, 0.09, sin(a) * 0.7), Vector3(0.1, a, -0.1))

	return root

# =========================================================================
# 7. ТЕЛЕГРАФНЫЙ СТОЛБ С ОБОРВАННЫМИ ПРОВОДАМИ (TELEGRAPH POLE)
# =========================================================================
static func create_telegraph_pole_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "TelegraphPole3D"

	# Наклон столба от пустынного ветра
	var pole_lean := Vector3(deg_to_rad(randf_range(-6.0, 6.0)), 0.0, deg_to_rad(randf_range(-6.0, 6.0)))
	var pole := Node3D.new()
	pole.rotation = pole_lean
	root.add_child(pole)

	# Деревянный ствол столба
	_add_cyl(pole, 6.4, 0.11, 0.15, mat_bark, Vector3(0.0, 3.2, 0.0))

	# Поперечина перекладины (траверса)
	_add_box(pole, Vector3(1.8, 0.12, 0.12), mat_bark, Vector3(0.0, 5.8, 0.0))

	# 4 керамических изолятора на траверсе
	var ins_x: Array[float] = [-0.75, -0.25, 0.25, 0.75]
	for ix in ins_x:
		_add_cyl(pole, 0.16, 0.04, 0.05, mat_insulator, Vector3(ix, 5.94, 0.0))

	# Оборванные свисающие провода
	_add_cyl(pole, 2.8, 0.01, 0.01, mat_metal, Vector3(-0.75, 4.4, 0.25), Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-8.0)))
	_add_cyl(pole, 3.6, 0.01, 0.01, mat_metal, Vector3(0.75, 4.0, -0.2), Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(14.0)))

	return root

# =========================================================================
# 8. СУХОЙ ПУСТЫННЫЙ КУСТАРНИК (DESERT SCRUB BUSH)
# =========================================================================
static func create_desert_bush_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "DesertBush3D"

	# Куст из нескольких переплетенных сухих веток и сферических шапок
	for i in range(5):
		var ang: float = float(i) * (TAU / 5.0) + randf_range(-0.2, 0.2)
		var rad: float = randf_range(0.25, 0.45)
		var b_pos := Vector3(cos(ang) * rad, randf_range(0.2, 0.45), sin(ang) * rad)
		var b_sz := Vector3(randf_range(0.5, 0.75), randf_range(0.4, 0.6), randf_range(0.5, 0.75))
		_add_box(root, b_sz, mat_scrub_bush, b_pos, Vector3(randf_range(-0.3, 0.3), ang, randf_range(-0.3, 0.3)))

	# Центральный сухой стволик у земли
	_add_cyl(root, 0.4, 0.05, 0.08, mat_bark, Vector3(0.0, 0.2, 0.0), Vector3(0.1, 0.2, 0.0))

	return root

# =========================================================================
# 9. РЖАВЫЙ ДОРОЖНЫЙ ЗНАК / УКАЗАТЕЛЬ (RUSTY ROAD SIGN)
# =========================================================================
static func create_road_sign_3d() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "RoadSign3D"

	var lean := Vector3(deg_to_rad(randf_range(-7.0, 7.0)), randf_range(0.0, TAU), deg_to_rad(randf_range(-5.0, 5.0)))
	var holder := Node3D.new()
	holder.rotation = lean
	root.add_child(holder)

	# Стальной оцинкованный шест
	_add_cyl(holder, 2.6, 0.035, 0.04, mat_metal, Vector3(0.0, 1.3, 0.0))

	# Ромбовидный дорожный знак предупреждения
	_add_box(holder, Vector3(0.85, 0.85, 0.03), mat_sign_yellow, Vector3(0.0, 2.2, 0.02), Vector3(0.0, 0.0, deg_to_rad(45.0)))
	# Черная предупреждающая полоса в центре знака
	_add_box(holder, Vector3(0.16, 0.75, 0.035), mat_rust, Vector3(0.0, 2.2, 0.025), Vector3(0.0, 0.0, deg_to_rad(45.0)))

	return root

# =========================================================================
# 10. ГРУППА РЖАВЫХ БОЧЕК И БРОШЕННЫХ ШИН (OIL DRUMS & TIRES CLUSTER)
# =========================================================================
static func create_oil_drums_cluster_3d() -> Node3D:
	var root := Node3D.new()
	root.name = "OilDrumsCluster3D"

	# Стоящая ржавая бочка
	var d1 := PropModels3D.create_oil_drum("rusty")
	d1.position = Vector3(-0.35, 0.0, 0.0)
	d1.rotation = Vector3(deg_to_rad(6.0), 0.0, deg_to_rad(4.0))
	root.add_child(d1)

	# Поваленная аварийная бочка
	var d2 := PropModels3D.create_oil_drum("hazard" if randf() < 0.5 else "toxic")
	d2.position = Vector3(0.42, 0.28, -0.15)
	d2.rotation = Vector3(0.0, deg_to_rad(35.0), PI * 0.5 - deg_to_rad(8.0))
	root.add_child(d2)

	# Детализированная шина с диском, прислоненная к бочке
	var tire := PropModels3D.create_tire(true, false)
	tire.position = Vector3(-0.08, 0.32, 0.45)
	tire.rotation = Vector3(deg_to_rad(22.0), deg_to_rad(-18.0), PI * 0.5)
	root.add_child(tire)

	return root
