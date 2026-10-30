extends Node3D

class_name CampNPC3D

# =========================================================================
# 3D МОДЕЛИ ПОВСТАНЦЕВ-ТОРГОВЦЕВ И ЗАЩИТНИКОВ ЛАГЕРЯ
# =========================================================================
# 1. Торговец Фарид: плащ-дастер, шемаг, патронташ, латунная кибер-рука, винтовка
# 2. Оружейник Гассан: фартук кузнеца, маска сварщика, кибер-глаз, молот и разводной ключ
# 3. Капитан Башир: тактический бронежилет, берет с кокардой, рация с антенной, снайперка

enum NPCType { TRADER, MECHANIC, COMMANDER }

@export var npc_type: NPCType = NPCType.TRADER
@export var npc_name: String = "Торговец Фарид"

var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var r_arm: Node3D
var l_arm: Node3D
var prop_tool: Node3D
var anim_phase: float = 0.0

static var mat_skin               : StandardMaterial3D
static var mat_skin_dark          : StandardMaterial3D
static var mat_duster_coat        : StandardMaterial3D
static var mat_mechanic_apron     : StandardMaterial3D
static var mat_tactical_vest      : StandardMaterial3D
static var mat_camo_fabric        : StandardMaterial3D
static var mat_shemagh            : StandardMaterial3D
static var mat_beret              : StandardMaterial3D
static var mat_leather            : StandardMaterial3D
static var mat_brass              : StandardMaterial3D
static var mat_steel              : StandardMaterial3D
static var mat_dark_iron          : StandardMaterial3D
static var mat_gold_bullet        : StandardMaterial3D
static var mat_optic_cyan         : StandardMaterial3D
static var mat_led_green          : StandardMaterial3D
static var mat_goggle_glass       : StandardMaterial3D

static func _ensure_materials() -> void:
	if mat_skin != null:
		return

	# Кожа человека (загорелая, обветренная)
	mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.76, 0.56, 0.40)
	mat_skin.roughness = 0.85

	mat_skin_dark = StandardMaterial3D.new()
	mat_skin_dark.albedo_color = Color(0.25, 0.18, 0.15)
	mat_skin_dark.roughness = 0.95

	# Пустынный плащ-дастер торговца (песочно-охристый)
	mat_duster_coat = StandardMaterial3D.new()
	mat_duster_coat.albedo_color = Color(0.65, 0.52, 0.35)
	mat_duster_coat.roughness = 0.88

	# Промасленный кожаный фартук механика
	mat_mechanic_apron = StandardMaterial3D.new()
	mat_mechanic_apron.albedo_color = Color(0.38, 0.26, 0.16)
	mat_mechanic_apron.roughness = 0.65

	# Тактический бронежилет командира
	mat_tactical_vest = StandardMaterial3D.new()
	mat_tactical_vest.albedo_color = Color(0.22, 0.26, 0.20)
	mat_tactical_vest.roughness = 0.70

	# Армейский камуфляж
	mat_camo_fabric = StandardMaterial3D.new()
	mat_camo_fabric.albedo_color = Color(0.32, 0.36, 0.26)
	mat_camo_fabric.roughness = 0.85

	# Арафатка / шемаг
	mat_shemagh = StandardMaterial3D.new()
	mat_shemagh.albedo_color = Color(0.88, 0.82, 0.72)
	mat_shemagh.roughness = 0.90

	# Берет командира
	mat_beret = StandardMaterial3D.new()
	mat_beret.albedo_color = Color(0.65, 0.16, 0.14)
	mat_beret.roughness = 0.80

	# Ремни и кобуры
	mat_leather = StandardMaterial3D.new()
	mat_leather.albedo_color = Color(0.18, 0.12, 0.08)
	mat_leather.roughness = 0.55

	# Латунь кибер-руки и пряжек
	mat_brass = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.85, 0.70, 0.25)
	mat_brass.metallic = 0.90
	mat_brass.roughness = 0.28

	# Оружейная сталь
	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.45, 0.47, 0.50)
	mat_steel.metallic = 0.95
	mat_steel.roughness = 0.22

	# Вороненый металл
	mat_dark_iron = StandardMaterial3D.new()
	mat_dark_iron.albedo_color = Color(0.14, 0.15, 0.16)
	mat_dark_iron.metallic = 0.85
	mat_dark_iron.roughness = 0.45

	# Золотистые патроны в ленте
	mat_gold_bullet = StandardMaterial3D.new()
	mat_gold_bullet.albedo_color = Color(0.95, 0.80, 0.20)
	mat_gold_bullet.metallic = 0.90
	mat_gold_bullet.roughness = 0.25

	# Светящийся кибер-глаз
	mat_optic_cyan = StandardMaterial3D.new()
	mat_optic_cyan.albedo_color = Color(0.1, 0.85, 1.0)
	mat_optic_cyan.emission_enabled = true
	mat_optic_cyan.emission = Color(0.15, 0.9, 1.0)
	mat_optic_cyan.emission_energy_multiplier = 4.0

	# Зеленый индикатор рации
	mat_led_green = StandardMaterial3D.new()
	mat_led_green.albedo_color = Color(0.2, 1.0, 0.3)
	mat_led_green.emission_enabled = true
	mat_led_green.emission = Color(0.2, 1.0, 0.3)
	mat_led_green.emission_energy_multiplier = 4.0

	# Стекло очков
	mat_goggle_glass = StandardMaterial3D.new()
	mat_goggle_glass.albedo_color = Color(0.8, 0.7, 0.4, 0.6)
	mat_goggle_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_goggle_glass.roughness = 0.1
	mat_goggle_glass.metallic = 0.3

func _ready() -> void:
	_ensure_materials()
	_build_model()

func _process(delta: float) -> void:
	anim_phase += delta * 1.8
	# Живое дыхание
	if torso_mesh:
		torso_mesh.position.y = 1.05 + sin(anim_phase) * 0.015
	if head_mesh:
		head_mesh.position.y = 1.55 + sin(anim_phase) * 0.018
		head_mesh.rotation.y = sin(anim_phase * 0.35) * 0.06
	if r_arm:
		r_arm.rotation.x = sin(anim_phase) * 0.04
	if l_arm:
		l_arm.rotation.x = -sin(anim_phase) * 0.04

	# Покачивание инструмента / оружия
	if prop_tool:
		prop_tool.rotation.z = deg_to_rad(15.0) + sin(anim_phase * 1.2) * 0.06

func _build_model() -> void:
	# 1. НОГИ И БОТИНКИ
	var leg_mat := mat_leather if npc_type == NPCType.TRADER else mat_camo_fabric
	_add_box(self, Vector3(0.20, 0.75, 0.22), leg_mat, Vector3(-0.14, 0.38, 0.0))
	_add_box(self, Vector3(0.20, 0.75, 0.22), leg_mat, Vector3(0.14, 0.38, 0.0))

	# Прочные армейские ботинки с пряжками
	_add_box(self, Vector3(0.22, 0.18, 0.32), mat_leather, Vector3(-0.14, 0.09, 0.05))
	_add_box(self, Vector3(0.22, 0.18, 0.32), mat_leather, Vector3(0.14, 0.09, 0.05))

	# Полы плаща-дастера (для торговца)
	if npc_type == NPCType.TRADER:
		_add_box(self, Vector3(0.56, 0.60, 0.34), mat_duster_coat, Vector3(0.0, 0.55, 0.0))

	# 2. ТОРС
	var body_mat := mat_duster_coat
	if npc_type == NPCType.MECHANIC:
		body_mat = mat_mechanic_apron
	elif npc_type == NPCType.COMMANDER:
		body_mat = mat_tactical_vest

	torso_mesh = _add_box(self, Vector3(0.48, 0.65, 0.28), body_mat, Vector3(0.0, 1.05, 0.0))

	# Тактический разгрузочный ремень
	_add_box(self, Vector3(0.52, 0.10, 0.32), mat_leather, Vector3(0.0, 0.78, 0.0))
	_add_box(self, Vector3(0.12, 0.12, 0.34), mat_brass, Vector3(0.0, 0.78, 0.0))

	# 3. ДЕТАЛИЗАЦИЯ ПО ТИПУ ПОВСТАНЦА
	match npc_type:
		NPCType.TRADER:
			_build_trader_details()
		NPCType.MECHANIC:
			_build_mechanic_details()
		NPCType.COMMANDER:
			_build_commander_details()

func _build_trader_details() -> void:
	# Патронташ крест-накрест через грудь
	var bandolier := _add_box(torso_mesh, Vector3(0.50, 0.10, 0.32), mat_leather, Vector3(0.0, 0.06, 0.0))
	bandolier.rotation.z = deg_to_rad(35.0)
	for b in range(5):
		var bx : float = -0.16 + float(b) * 0.08
		_add_cyl(torso_mesh, 0.07, 0.018, 0.018, mat_gold_bullet, Vector3(bx, 0.06 + bx * 0.5, 0.17)).rotation.x = deg_to_rad(90.0)

	# Кошели с монетами на поясе
	_add_box(self, Vector3(0.16, 0.18, 0.14), mat_leather, Vector3(0.28, 0.75, 0.05))
	_add_box(self, Vector3(0.14, 0.14, 0.12), mat_brass, Vector3(-0.28, 0.75, 0.05))

	# ГОЛОВА: шемаг (арафатка) закрывает лицо, авиаторские очки на лбу
	head_mesh = _add_box(self, Vector3(0.26, 0.30, 0.26), mat_skin, Vector3(0.0, 1.55, 0.0))
	# Шемаг закрывает нижнюю половину лица
	_add_box(head_mesh, Vector3(0.28, 0.16, 0.28), mat_shemagh, Vector3(0.0, -0.06, 0.03))
	# Тюрбан на макушке
	_add_cyl(head_mesh, 0.16, 0.20, 0.22, mat_shemagh, Vector3(0.0, 0.16, 0.0))
	# Очки на лбу с бронзовой оправой
	_add_cyl(head_mesh, 0.04, 0.045, 0.045, mat_brass, Vector3(-0.06, 0.12, 0.14)).rotation.x = deg_to_rad(90.0)
	_add_cyl(head_mesh, 0.04, 0.045, 0.045, mat_brass, Vector3(0.06, 0.12, 0.14)).rotation.x = deg_to_rad(90.0)
	_add_cyl(head_mesh, 0.045, 0.035, 0.035, mat_goggle_glass, Vector3(-0.06, 0.12, 0.145)).rotation.x = deg_to_rad(90.0)
	_add_cyl(head_mesh, 0.045, 0.035, 0.035, mat_goggle_glass, Vector3(0.06, 0.12, 0.145)).rotation.x = deg_to_rad(90.0)

	# РУКИ: Левая рука — ЛАТУННЫЙ КИБЕР-ПРОТЕЗ со шестеренками
	l_arm = Node3D.new()
	l_arm.position = Vector3(-0.32, 1.30, 0.0)
	add_child(l_arm)
	_add_box(l_arm, Vector3(0.14, 0.28, 0.14), mat_duster_coat, Vector3(0.0, -0.14, 0.0))
	# Механическое латунное предплечье
	_add_cylinder(l_arm, 0.05, 0.28, mat_brass, Vector3(0.0, -0.38, 0.0))
	_add_cylinder(l_arm, 0.065, 0.06, mat_dark_iron, Vector3(0.0, -0.28, 0.0)) # сустав
	# Пальцы протеза
	for fg in range(4):
		_add_box(l_arm, Vector3(0.018, 0.12, 0.02), mat_brass, Vector3(-0.03 + fg * 0.02, -0.56, 0.01))

	# Правая рука в рукаве плаща
	r_arm = Node3D.new()
	r_arm.position = Vector3(0.32, 1.30, 0.0)
	add_child(r_arm)
	_add_box(r_arm, Vector3(0.14, 0.50, 0.14), mat_duster_coat, Vector3(0.0, -0.24, 0.0))
	_add_box(r_arm, Vector3(0.12, 0.14, 0.12), mat_skin, Vector3(0.0, -0.54, 0.0))

	# ВИНТОВКА ЗА СПИНОЙ В ЧЕХЛЕ
	var rifle := Node3D.new()
	rifle.position = Vector3(0.0, 1.25, -0.20)
	rifle.rotation = Vector3(0.0, 0.0, deg_to_rad(-35.0))
	add_child(rifle)
	_add_box(rifle, Vector3(0.08, 0.95, 0.06), mat_leather, Vector3.ZERO) # чехол
	_add_cylinder(rifle, 0.02, 0.35, mat_steel, Vector3(0.0, 0.55, 0.0)) # ствол винтовки

func _build_mechanic_details() -> void:
	# Торс: кожаный фартук со следами масла и карманом для инструментов
	_add_box(torso_mesh, Vector3(0.40, 0.45, 0.04), mat_dark_iron, Vector3(0.0, -0.05, 0.15))
	# Разводной ключ на поясе
	_add_box(self, Vector3(0.06, 0.42, 0.04), mat_steel, Vector3(-0.28, 0.85, 0.0))

	# ГОЛОВА: маска сварщика на лбу, густая борода, КИБЕРНЕТИЧЕСКИЙ СИНИЙ ГЛАЗ
	head_mesh = _add_box(self, Vector3(0.26, 0.30, 0.26), mat_skin, Vector3(0.0, 1.55, 0.0))
	# Борода
	_add_box(head_mesh, Vector3(0.24, 0.16, 0.10), mat_skin_dark, Vector3(0.0, -0.10, 0.12))
	# Маска сварщика поднята на лоб
	var mask := _add_box(head_mesh, Vector3(0.32, 0.20, 0.14), mat_dark_iron, Vector3(0.0, 0.18, 0.10))
	mask.rotation.x = deg_to_rad(-25.0)
	_add_box(mask, Vector3(0.18, 0.08, 0.02), mat_goggle_glass, Vector3(0.0, 0.0, 0.08))

	# Левый глаз: человек
	_add_box(head_mesh, Vector3(0.04, 0.03, 0.02), mat_skin_dark, Vector3(-0.06, 0.04, 0.135))
	# Правый глаз: КИБЕР-ВИЗОР со светящейся синей оптикой
	_add_cylinder(head_mesh, 0.03, 0.04, mat_dark_iron, Vector3(0.06, 0.04, 0.13)).rotation.x = deg_to_rad(90.0)
	_add_sphere(head_mesh, 0.022, mat_optic_cyan, Vector3(0.06, 0.04, 0.15))

	# РУКИ: закатанные рукава, мускулистые предплечья
	l_arm = Node3D.new()
	l_arm.position = Vector3(-0.32, 1.30, 0.0)
	add_child(l_arm)
	_add_box(l_arm, Vector3(0.14, 0.26, 0.14), mat_camo_fabric, Vector3(0.0, -0.13, 0.0))
	_add_box(l_arm, Vector3(0.12, 0.28, 0.12), mat_skin, Vector3(0.0, -0.38, 0.0))
	_add_box(l_arm, Vector3(0.13, 0.14, 0.13), mat_leather, Vector3(0.0, -0.55, 0.0)) # рабочая перчатка

	r_arm = Node3D.new()
	r_arm.position = Vector3(0.32, 1.30, 0.0)
	add_child(r_arm)
	_add_box(r_arm, Vector3(0.14, 0.26, 0.14), mat_camo_fabric, Vector3(0.0, -0.13, 0.0))
	_add_box(r_arm, Vector3(0.12, 0.28, 0.12), mat_skin, Vector3(0.0, -0.38, 0.0))
	_add_box(r_arm, Vector3(0.13, 0.14, 0.13), mat_leather, Vector3(0.0, -0.55, 0.0))

	# ТЯЖЕЛЫЙ ГАЕЧНЫЙ КЛЮЧ В ПРАВОЙ РУКЕ
	prop_tool = Node3D.new()
	prop_tool.position = Vector3(0.0, -0.55, 0.08)
	r_arm.add_child(prop_tool)
	_add_cylinder(prop_tool, 0.02, 0.45, mat_steel, Vector3(0.0, 0.0, 0.0))
	_add_box(prop_tool, Vector3(0.12, 0.10, 0.03), mat_steel, Vector3(0.0, 0.22, 0.0))

	# ДРОБОВИК НА ПЛЕЧЕВОМ РЕМНЕ ЗА СПИНОЙ
	var shotg := Node3D.new()
	shotg.position = Vector3(0.0, 1.25, -0.20)
	shotg.rotation = Vector3(0.0, 0.0, deg_to_rad(30.0))
	add_child(shotg)
	_add_box(shotg, Vector3(0.06, 0.70, 0.08), mat_steel, Vector3.ZERO)
	_add_box(shotg, Vector3(0.05, 0.22, 0.09), mat_mechanic_apron, Vector3(0.0, -0.28, 0.0))

func _build_commander_details() -> void:
	# Торс: бронежилет с керамическими пластинами и шевроном повстанцев
	_add_box(torso_mesh, Vector3(0.42, 0.45, 0.08), mat_dark_iron, Vector3(0.0, 0.04, 0.14)) # грудная пластина
	_add_box(torso_mesh, Vector3(0.14, 0.06, 0.02), mat_beret, Vector3(0.0, 0.20, 0.19)) # шеврон

	# ТАКТИЧЕСКАЯ РАДИОСТАНЦИЯ НА ЛЕВОМ ПЛЕЧЕ С АНТЕННОЙ И ЗЕЛЕНЫМ ДИОДОМ
	var radio := _add_box(torso_mesh, Vector3(0.10, 0.16, 0.10), mat_dark_iron, Vector3(-0.20, 0.24, 0.10))
	_add_cylinder(radio, 0.008, 0.35, mat_dark_iron, Vector3(0.02, 0.22, 0.0)) # гибкая антенна
	_add_sphere(radio, 0.016, mat_led_green, Vector3(-0.02, 0.06, 0.06)) # мигающий диод связи

	# Кобура с револьвером на правом бедре
	_add_box(self, Vector3(0.12, 0.26, 0.10), mat_leather, Vector3(0.28, 0.72, 0.05))

	# ГОЛОВА: БЕРЕТ С ЗОЛОТОЙ КОКАРДОЙ, ШРАМ ЧЕРЕЗ ЩЕКУ
	head_mesh = _add_box(self, Vector3(0.26, 0.30, 0.26), mat_skin, Vector3(0.0, 1.55, 0.0))
	# Шрам
	_add_box(head_mesh, Vector3(0.02, 0.14, 0.01), mat_skin_dark, Vector3(-0.08, -0.02, 0.135)).rotation.z = deg_to_rad(20.0)

	# Красный берет
	var beret := _add_cyl(head_mesh, 0.09, 0.22, 0.18, mat_beret, Vector3(0.04, 0.18, -0.02))
	beret.rotation.z = -deg_to_rad(15.0)
	# Золотая кокарда
	_add_box(head_mesh, Vector3(0.06, 0.06, 0.04), mat_brass, Vector3(0.14, 0.18, 0.10))

	# РУКИ: камуфляжные рукава, тактические перчатки
	l_arm = Node3D.new()
	l_arm.position = Vector3(-0.32, 1.30, 0.0)
	add_child(l_arm)
	_add_box(l_arm, Vector3(0.15, 0.50, 0.15), mat_camo_fabric, Vector3(0.0, -0.22, 0.0))
	_add_box(l_arm, Vector3(0.13, 0.14, 0.13), mat_leather, Vector3(0.0, -0.52, 0.0))

	r_arm = Node3D.new()
	r_arm.position = Vector3(0.32, 1.30, 0.0)
	add_child(r_arm)
	_add_box(r_arm, Vector3(0.15, 0.50, 0.15), mat_camo_fabric, Vector3(0.0, -0.22, 0.0))
	_add_box(r_arm, Vector3(0.13, 0.14, 0.13), mat_leather, Vector3(0.0, -0.52, 0.0))

	# СНАЙПЕРСКАЯ ВИНТОВКА С ОПТИКОЙ ЗА СПИНОЙ
	var sniper := Node3D.new()
	sniper.position = Vector3(0.0, 1.30, -0.22)
	sniper.rotation = Vector3(0.0, 0.0, deg_to_rad(-25.0))
	add_child(sniper)
	# Ложе и ствол
	_add_box(sniper, Vector3(0.06, 0.95, 0.08), mat_dark_iron, Vector3.ZERO)
	_add_cylinder(sniper, 0.018, 0.45, mat_steel, Vector3(0.0, 0.65, 0.0))
	# Оптический прицел
	_add_cylinder(sniper, 0.03, 0.28, mat_dark_iron, Vector3(0.0, 0.10, 0.07)).rotation.x = deg_to_rad(90.0)
	_add_sphere(sniper, 0.024, mat_optic_cyan, Vector3(0.0, 0.24, 0.07))

# Вспомогательные методы создания примитивов с тенями
static func _add_box(parent: Node, sz: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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

static func _add_cylinder(parent: Node, r: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _add_sphere(parent: Node, r: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	sph.material = mat
	mi.mesh = sph
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _add_cyl(parent: Node, height: float, top_r: float, bot_r: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = height
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi
