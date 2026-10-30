extends Node3D

class_name CampNPC3D

# =========================================================================
# 3D МОДЕЛЬ ЖИТЕЛЯ ЛАГЕРЯ (ТОРГОВЕЦ, МАСТЕР, КОМАНДИР)
# =========================================================================
# Процедурная стилизованная 3D-модель человека с уникальной одеждой,
# головными уборами, оружием за спиной и живой idle-анимацией (дыхание, покачивание).

enum NPCType { TRADER, MECHANIC, COMMANDER }

@export var npc_type: NPCType = NPCType.TRADER
@export var npc_name: String = "Торговец Фарид"

var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var r_arm: Node3D
var l_arm: Node3D
var anim_phase: float = 0.0

static var mat_skin: StandardMaterial3D
static var mat_trader_robe: StandardMaterial3D
static var mat_mechanic_vest: StandardMaterial3D
static var mat_commander_uniform: StandardMaterial3D
static var mat_turban: StandardMaterial3D
static var mat_beret: StandardMaterial3D
static var mat_leather_belt: StandardMaterial3D
static var mat_brass: StandardMaterial3D

static func _ensure_materials() -> void:
	if mat_skin != null:
		return

	mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.78, 0.58, 0.42)
	mat_skin.roughness = 0.85

	mat_trader_robe = StandardMaterial3D.new()
	mat_trader_robe.albedo_color = Color(0.18, 0.45, 0.48)
	mat_trader_robe.roughness = 0.75

	mat_mechanic_vest = StandardMaterial3D.new()
	mat_mechanic_vest.albedo_color = Color(0.52, 0.38, 0.22)
	mat_mechanic_vest.roughness = 0.65

	mat_commander_uniform = StandardMaterial3D.new()
	mat_commander_uniform.albedo_color = Color(0.28, 0.35, 0.22)
	mat_commander_uniform.roughness = 0.8

	mat_turban = StandardMaterial3D.new()
	mat_turban.albedo_color = Color(0.92, 0.88, 0.78)
	mat_turban.roughness = 0.85

	mat_beret = StandardMaterial3D.new()
	mat_beret.albedo_color = Color(0.65, 0.18, 0.15)
	mat_beret.roughness = 0.8

	mat_leather_belt = StandardMaterial3D.new()
	mat_leather_belt.albedo_color = Color(0.22, 0.15, 0.10)
	mat_leather_belt.roughness = 0.6

	mat_brass = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.85, 0.70, 0.25)
	mat_brass.metallic = 0.85
	mat_brass.roughness = 0.35

func _ready() -> void:
	_ensure_materials()
	_build_model()

func _process(delta: float) -> void:
	anim_phase += delta * 1.8
	# Дыхание и легкое живое покачивание
	if torso_mesh:
		torso_mesh.position.y = 1.05 + sin(anim_phase) * 0.015
	if head_mesh:
		head_mesh.position.y = 1.55 + sin(anim_phase) * 0.018
		head_mesh.rotation.y = sin(anim_phase * 0.4) * 0.08
	if r_arm:
		r_arm.rotation.x = sin(anim_phase) * 0.05
	if l_arm:
		l_arm.rotation.x = -sin(anim_phase) * 0.05

func _build_model() -> void:
	# Ноги
	var l_leg := _add_box(self, Vector3(0.20, 0.75, 0.22), mat_leather_belt, Vector3(-0.14, 0.38, 0.0))
	var r_leg := _add_box(self, Vector3(0.20, 0.75, 0.22), mat_leather_belt, Vector3(0.14, 0.38, 0.0))

	# Ботинки
	_add_box(self, Vector3(0.22, 0.18, 0.32), mat_leather_belt, Vector3(-0.14, 0.09, 0.05))
	_add_box(self, Vector3(0.22, 0.18, 0.32), mat_leather_belt, Vector3(0.14, 0.09, 0.05))

	# Торс
	var body_mat := mat_trader_robe
	if npc_type == NPCType.MECHANIC:
		body_mat = mat_mechanic_vest
	elif npc_type == NPCType.COMMANDER:
		body_mat = mat_commander_uniform

	torso_mesh = _add_box(self, Vector3(0.48, 0.65, 0.28), body_mat, Vector3(0.0, 1.05, 0.0))

	# Пояс с пряжкой
	_add_box(self, Vector3(0.50, 0.10, 0.30), mat_leather_belt, Vector3(0.0, 0.78, 0.0))
	_add_box(self, Vector3(0.12, 0.12, 0.32), mat_brass, Vector3(0.0, 0.78, 0.0))

	# Голова и лицо
	head_mesh = _add_box(self, Vector3(0.26, 0.30, 0.26), mat_skin, Vector3(0.0, 1.55, 0.0))
	# Нос
	_add_box(head_mesh, Vector3(0.06, 0.10, 0.08), mat_skin, Vector3(0.0, 0.0, 0.16))

	# Головной убор по типу
	match npc_type:
		NPCType.TRADER:
			# Тюрбан торговца
			var turban := _add_cyl(head_mesh, 0.18, 0.22, 0.20, mat_turban, Vector3(0.0, 0.16, 0.0))
			_add_box(head_mesh, Vector3(0.08, 0.12, 0.06), mat_brass, Vector3(0.0, 0.16, 0.18)) # брошь
			# Мешочек с монетами на поясе
			_add_box(self, Vector3(0.15, 0.18, 0.15), mat_brass, Vector3(0.28, 0.75, 0.05))
		NPCType.MECHANIC:
			# Очки сварщика/инженера на лбу
			_add_box(head_mesh, Vector3(0.28, 0.06, 0.06), mat_brass, Vector3(0.0, 0.08, 0.14))
			# Разводной ключ на поясе
			_add_box(self, Vector3(0.08, 0.35, 0.06), mat_brass, Vector3(-0.28, 0.85, 0.0))
		NPCType.COMMANDER:
			# Берет командира
			var beret := _add_cyl(head_mesh, 0.08, 0.22, 0.18, mat_beret, Vector3(0.04, 0.18, -0.02), Vector3(0.0, 0.0, -deg_to_rad(15.0)))
			_add_box(head_mesh, Vector3(0.05, 0.05, 0.04), mat_brass, Vector3(0.14, 0.18, 0.10))
			# Кобура с револьвером
			_add_box(self, Vector3(0.14, 0.24, 0.10), mat_leather_belt, Vector3(0.28, 0.72, 0.05))

	# Руки
	l_arm = Node3D.new()
	l_arm.position = Vector3(-0.32, 1.30, 0.0)
	add_child(l_arm)
	_add_box(l_arm, Vector3(0.15, 0.55, 0.16), body_mat, Vector3(0.0, -0.24, 0.0))
	_add_box(l_arm, Vector3(0.12, 0.15, 0.14), mat_skin, Vector3(0.0, -0.55, 0.0))

	r_arm = Node3D.new()
	r_arm.position = Vector3(0.32, 1.30, 0.0)
	add_child(r_arm)
	_add_box(r_arm, Vector3(0.15, 0.55, 0.16), body_mat, Vector3(0.0, -0.24, 0.0))
	_add_box(r_arm, Vector3(0.12, 0.15, 0.14), mat_skin, Vector3(0.0, -0.55, 0.0))

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
