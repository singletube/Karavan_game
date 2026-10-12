extends Node3D

# --- Настройки плотности генерации (настоящая просторная пустыня) ---
@export var tree_count        : int = 10
@export var car_count         : int = 4
@export var cactus_count      : int = 12
@export var bones_count       : int = 6
@export var tumbleweed_count  : int = 5
@export var spawn_radius      : float = 280.0
@export var safe_spawn_radius : float = 25.0

const TUMBLEWEED_SCENE = preload("res://scenes/tumbleweed.tscn")

# Кэш текстур, чтобы генерировать картинку только один раз для всех объектов
var tex_tree : Texture2D
var tex_car  : Texture2D
var tex_bone : Texture2D
var tex_cact : Texture2D

func _ready() -> void:
	_init_textures()
	_generate_dead_trees()
	_generate_wrecked_cars()
	_generate_extra_cacti()
	_generate_bones()
	_generate_tumbleweeds()

func _init_textures() -> void:
	tex_tree = TextureGen.make_dead_tree()
	tex_car  = TextureGen.make_wrecked_car()
	tex_bone = TextureGen.make_skull_bones()
	tex_cact = TextureGen.make_cactus()

func _get_random_desert_pos() -> Vector3:
	var angle: float = randf_range(0.0, TAU)
	var dist: float  = randf_range(safe_spawn_radius, spawn_radius)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

# =========================================================================
# 1. ЗАСОХШИЕ ДЕРЕВЬЯ
# =========================================================================
func _generate_dead_trees() -> void:
	var container := Node3D.new()
	container.name = "DeadTrees"
	add_child(container)

	for i in range(tree_count):
		var tree_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		tree_body.position = pos

		# Спрайт дерева
		var spr := Sprite3D.new()
		spr.texture = tex_tree
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.05
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		spr.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		spr.position.y = 2.4

		# Случайный масштаб для разнообразия
		var s: float = randf_range(0.85, 1.35)
		spr.scale = Vector3(s, s, s)

		# Коллизия ствола
		var col := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 4.8 * s
		cylinder.radius = 0.45 * s
		col.shape = cylinder
		col.position.y = 2.4 * s

		tree_body.add_child(spr)
		tree_body.add_child(col)
		container.add_child(tree_body)

# =========================================================================
# 2. РАЗБИТЫЕ РЖАВЫЕ МАШИНЫ (УКРЫТИЯ)
# =========================================================================
func _generate_wrecked_cars() -> void:
	var container := Node3D.new()
	container.name = "WreckedCars"
	add_child(container)

	for i in range(car_count):
		var car_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		car_body.position = pos

		var spr := Sprite3D.new()
		spr.texture = tex_car
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.045
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		spr.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		spr.position.y = 1.05

		var s: float = randf_range(0.9, 1.25)
		spr.scale = Vector3(s, s, s)

		# Плотная коробка коллизии (надежное укрытие от пуль и зомби)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.8 * s, 1.8 * s, 2.2 * s)
		col.shape = box
		col.position.y = 0.9 * s

		car_body.add_child(spr)
		car_body.add_child(col)
		container.add_child(car_body)

# =========================================================================
# 3. ДОПОЛНИТЕЛЬНЫЕ КАКТУСЫ
# =========================================================================
func _generate_extra_cacti() -> void:
	var container := Node3D.new()
	container.name = "GeneratedCacti"
	add_child(container)

	for i in range(cactus_count):
		var cact_body := StaticBody3D.new()
		var pos: Vector3 = _get_random_desert_pos()
		cact_body.position = pos

		var spr := Sprite3D.new()
		spr.texture = tex_cact
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.04
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		spr.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		spr.position.y = 1.3

		var s: float = randf_range(0.8, 1.4)
		spr.scale = Vector3(s, s, s)

		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = 2.6 * s
		cyl.radius = 0.35 * s
		col.shape = cyl
		col.position.y = 1.3 * s

		cact_body.add_child(spr)
		cact_body.add_child(col)
		container.add_child(cact_body)

# =========================================================================
# 4. ЧЕРЕПА И КОСТИ В ПЕСКЕ
# =========================================================================
func _generate_bones() -> void:
	var container := Node3D.new()
	container.name = "DesertBones"
	add_child(container)

	for i in range(bones_count):
		var pos: Vector3 = _get_random_desert_pos()
		var spr := Sprite3D.new()
		spr.texture = tex_bone
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.035
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		spr.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		spr.position = Vector3(pos.x, 0.55, pos.z)
		spr.scale = Vector3(randf_range(0.9, 1.2), randf_range(0.9, 1.2), 1.0)

		container.add_child(spr)

# =========================================================================
# 5. ПЕРЕКАТИ-ПОЛЕ (КАТЯТСЯ ПО ПУСТЫНЕ)
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
