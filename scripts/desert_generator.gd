extends Node3D

# --- Настройки плотности генерации (настоящая просторная пустыня) ---
@export var tree_count        : int = 12
@export var car_count         : int = 5
@export var cactus_count      : int = 16
@export var bones_count       : int = 8
@export var tumbleweed_count  : int = 6
@export var spawn_radius      : float = 280.0
@export var safe_spawn_radius : float = 25.0

const TUMBLEWEED_SCENE = preload("res://scenes/tumbleweed.tscn")

func _ready() -> void:
	_generate_dead_trees()
	_generate_wrecked_cars()
	_generate_extra_cacti()
	_generate_bones()
	_generate_tumbleweeds()

func _get_random_desert_pos() -> Vector3:
	var angle: float = randf_range(0.0, TAU)
	var dist: float  = randf_range(safe_spawn_radius, spawn_radius)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

# =========================================================================
# 1. ЗАСОХШИЕ ДЕРЕВЬЯ (ПОЛНОЦЕННЫЕ 3D МОДЕЛИ)
# =========================================================================
func _generate_dead_trees() -> void:
	var container := Node3D.new()
	container.name = "DeadTrees"
	add_child(container)

	for i in range(tree_count):
		var tree_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		tree_body.position = pos
		tree_body.rotation.y = randf_range(0.0, TAU)

		var model := DesertScenery3D.create_dead_tree_3d()
		var s: float = randf_range(0.85, 1.35)
		model.scale = Vector3(s, s, s)

		# Коллизия ствола дерева
		var col := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 4.8 * s
		cylinder.radius = 0.45 * s
		col.shape = cylinder
		col.position.y = 2.4 * s

		tree_body.add_child(model)
		tree_body.add_child(col)
		container.add_child(tree_body)

# =========================================================================
# 2. РАЗБИТЫЕ РЖАВЫЕ МАШИНЫ (ПОЛНОЦЕННЫЕ 3D МОДЕЛИ - УКРЫТИЯ)
# =========================================================================
func _generate_wrecked_cars() -> void:
	var container := Node3D.new()
	container.name = "WreckedCars"
	add_child(container)

	for i in range(car_count):
		var car_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		car_body.position = pos
		car_body.rotation.y = randf_range(0.0, TAU)

		var model := DesertScenery3D.create_wrecked_car_3d()
		var s: float = randf_range(0.9, 1.25)
		model.scale = Vector3(s, s, s)

		# Плотная коробка коллизии (надежное укрытие от пуль и зомби)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.8 * s, 1.8 * s, 2.2 * s)
		col.shape = box
		col.position.y = 0.9 * s

		car_body.add_child(model)
		car_body.add_child(col)
		container.add_child(car_body)

# =========================================================================
# 3. ДОПОЛНИТЕЛЬНЫЕ КАКТУСЫ САГУАРО (ПОЛНОЦЕННЫЕ 3D МОДЕЛИ)
# =========================================================================
func _generate_extra_cacti() -> void:
	var container := Node3D.new()
	container.name = "GeneratedCacti"
	add_child(container)

	for i in range(cactus_count):
		var cact_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		cact_body.position = pos
		cact_body.rotation.y = randf_range(0.0, TAU)

		var model := DesertScenery3D.create_cactus_3d()
		var s: float = randf_range(0.85, 1.35)
		model.scale = Vector3(s, s, s)

		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = 3.0 * s
		cyl.radius = 0.35 * s
		col.shape = cyl
		col.position.y = 1.5 * s

		cact_body.add_child(model)
		cact_body.add_child(col)
		container.add_child(cact_body)

# =========================================================================
# 4. ЧЕРЕПА И КОСТИ В ПЕСКЕ (ПОЛНОЦЕННЫЕ 3D МОДЕЛИ)
# =========================================================================
func _generate_bones() -> void:
	var container := Node3D.new()
	container.name = "DesertBones"
	add_child(container)

	for i in range(bones_count):
		var pos: Vector3 = _get_random_desert_pos()
		var model := DesertScenery3D.create_skull_bones_3d()
		model.position = pos
		model.rotation.y = randf_range(0.0, TAU)
		var s: float = randf_range(0.9, 1.3)
		model.scale = Vector3(s, s, s)

		container.add_child(model)

# =========================================================================
# 5. ПЕРЕКАТИ-ПОЛЕ (3D ОБЪЕМНЫЕ КЛУБКИ КАТЯТСЯ ПО ПУСТЫНЕ)
# =========================================================================
func _generate_tumbleweeds() -> void:
	var container := Node3D.new()
	container.name = "Tumbleweeds"
	add_child(container)

	for i in range(tumbleweed_count):
		var tw := TUMBLEWEED_SCENE.instantiate()
		tw.position = Vector3(
			randf_range(-140.0, 140.0),
			0.5,
			randf_range(-140.0, 140.0)
		)
		container.add_child(tw)
