extends Node3D

# Бесконечный процедурный генератор мира чанками (Infinite Chunk-Based Desert & Scenery)
# Генерирует бесшовные участки пустыни, песчаные дюны, мертвые деревья, кактусы Сагуаро,
# остовы ржавых машин, скалы, черепа и перекати-поле вокруг движущегося каравана и игрока.

# --- Параметры сетки чанков ---
@export var chunk_size       : float = 120.0  # Размер стороны чанка в метрах
@export var load_radius      : int   = 3      # Радиус видимости (7x7 = 49 активных чанков, 840м x 840м)
@export var unload_margin    : int   = 1      # Буферный зазор перед удалением далеких чанков
@export var road_clear_width : float = 4.8    # Ширина свободной центральной дороги каравана (X = 0)

const TUMBLEWEED_SCENE = preload("res://scenes/tumbleweed.tscn")
const RoadEvents3D = preload("res://scripts/road_events_3d.gd")

var active_chunks         : Dictionary = {} # Vector2i -> Node3D
var current_center_coord  : Vector2i   = Vector2i(999999, 999999)
var update_timer          : float      = 0.0
const UPDATE_INTERVAL     : float      = 0.20 # Частота проверки положения цели (сек)

# История и параметры спавна редких точек интереса (POI)
var spawned_gas_stations : Dictionary = {} # Vector2i -> Dictionary
var spawned_oases        : Dictionary = {} # Vector2i -> Dictionary
const MIN_GAS_STATION_CHUNK_DIST : int   = 5   # Минимум 4-5 чанков между любыми заправками (~480-600м)
const MIN_OASIS_CHUNK_DIST       : int   = 4   # Минимум 4 чанка между оазисами (~480м)
const MIN_GAS_OASIS_SEPARATION   : float = 2.0 # Минимум 2 чанка между заправкой и оазисом

# Переиспользуемые ресурсы (Shared Meshes & Materials для максимальной производительности)
var shared_floor_mesh     : BoxMesh
var shared_floor_shape    : BoxShape3D
var sand_material         : ShaderMaterial
var mat_rock              : StandardMaterial3D
var mat_rock_dark         : StandardMaterial3D

func _ready() -> void:
	_cleanup_old_static_world()
	_init_shared_resources()
	# Мгновенная генерация начальных 49 чанков вокруг точки старта
	_update_chunks(true)

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_chunks(false)

# Удаление старых статичных объектов начальной сцены (чтобы не дублировать чанки и не вызывать Z-fighting)
func _cleanup_old_static_world() -> void:
	var old_floor := get_node_or_null("../Floor") as StaticBody3D
	if old_floor:
		old_floor.queue_free()

	for r_name in ["../RockDistant1", "../RockDistant2", "../RockDistant3"]:
		var r_node := get_node_or_null(r_name)
		if r_node:
			r_node.queue_free()

func _init_shared_resources() -> void:
	# Единый меш и форма коллизии пола для всех чанков
	shared_floor_mesh = BoxMesh.new()
	shared_floor_mesh.size = Vector3(chunk_size, 0.4, chunk_size)

	shared_floor_shape = BoxShape3D.new()
	shared_floor_shape.size = Vector3(chunk_size, 0.4, chunk_size)

	# Получение шейдера песка от WorldSetup или создание резервного
	var world_node := get_tree().current_scene
	if world_node and world_node.has_method("get_sand_material"):
		sand_material = world_node.get_sand_material()

	if sand_material == null:
		var shader := load("res://shaders/sand.gdshader") as Shader
		if shader:
			sand_material = ShaderMaterial.new()
			sand_material.shader = shader
			sand_material.set_shader_parameter("sand_light",      Color(0.96, 0.84, 0.58))
			sand_material.set_shader_parameter("sand_mid",        Color(0.82, 0.66, 0.38))
			sand_material.set_shader_parameter("sand_dark",       Color(0.62, 0.46, 0.22))
			sand_material.set_shader_parameter("texture_scale",   0.20)
			sand_material.set_shader_parameter("ripple_strength", 0.65)
			sand_material.set_shader_parameter("roughness_base",  0.85)
			sand_material.set_shader_parameter("specular_amt",    0.22)

	# Материалы для песчаных скал
	mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.58, 0.44, 0.28)
	mat_rock.roughness = 0.95

	mat_rock_dark = StandardMaterial3D.new()
	mat_rock_dark.albedo_color = Color(0.42, 0.32, 0.20)
	mat_rock_dark.roughness = 0.95

# =========================================================================
# УПРАВЛЕНИЕ ЧАНКАМИ (СТРИМИНГ МИРА)
# =========================================================================
func _get_target_pos() -> Vector3:
	var caravan := get_tree().get_first_node_in_group("caravan") as Node3D
	if caravan and is_instance_valid(caravan):
		return caravan.global_position

	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node3D and is_instance_valid(p) and not (p.get("is_dead") == true):
			return (p as Node3D).global_position

	return Vector3.ZERO

func _update_chunks(force: bool) -> void:
	var target_pos := _get_target_pos()
	var center_cx: int = int(round(target_pos.x / chunk_size))
	var center_cz: int = int(round(target_pos.z / chunk_size))
	var new_center := Vector2i(center_cx, center_cz)

	if new_center == current_center_coord and not force:
		return

	current_center_coord = new_center

	# 1. Загрузка новых чанков в радиусе load_radius
	for dx in range(-load_radius, load_radius + 1):
		for dz in range(-load_radius, load_radius + 1):
			var coord := Vector2i(center_cx + dx, center_cz + dz)
			if not active_chunks.has(coord):
				_spawn_chunk(coord)

	# 2. Выгрузка устаревших чанков за пределами load_radius + unload_margin
	var max_dist: int = load_radius + unload_margin
	var to_remove: Array[Vector2i] = []
	for coord: Vector2i in active_chunks.keys():
		if abs(coord.x - center_cx) > max_dist or abs(coord.y - center_cz) > max_dist:
			to_remove.append(coord)

	for coord: Vector2i in to_remove:
		var c_node: Node3D = active_chunks[coord]
		if is_instance_valid(c_node):
			c_node.queue_free()
		active_chunks.erase(coord)

# =========================================================================
# ГЕНЕРАЦИЯ ОДНОГО ЧАНКА
# =========================================================================
func _get_chunk_seed(cx: int, cz: int) -> int:
	# Мультипликативное хеширование координат чанка для детерминированного псевдослучайного мира
	var h: int = (cx * 73856093) ^ (cz * 19349663)
	return abs(h)

func _spawn_chunk(coord: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	# Центр чанка в мировых координатах
	chunk.position = Vector3(float(coord.x) * chunk_size, 0.0, float(coord.y) * chunk_size)
	add_child(chunk)
	active_chunks[coord] = chunk

	# 1. Секция пола чанка (бесшовный песок с коллизией)
	_build_chunk_floor(chunk)

	# 2. Процедурные декорации чанка с детерминированным генератором
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed(coord.x, coord.y)

	_populate_chunk_scenery(chunk, coord, rng)

func _build_chunk_floor(chunk: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ChunkFloor"

	var mi := MeshInstance3D.new()
	mi.mesh = shared_floor_mesh
	if sand_material:
		mi.material_override = sand_material
	mi.position = Vector3(0.0, -0.2, 0.0)

	var col := CollisionShape3D.new()
	col.shape = shared_floor_shape
	col.position = Vector3(0.0, -0.2, 0.0)

	body.add_child(mi)
	body.add_child(col)
	chunk.add_child(body)

# Проверка дистанции до уже размещенных заправок (минимум min_dist чанков)
func _is_far_enough_from_gas_stations(coord: Vector2i, min_dist: int = MIN_GAS_STATION_CHUNK_DIST) -> bool:
	for g_coord: Vector2i in spawned_gas_stations.keys():
		# На дороге (X=0) проверяем продольное расстояние по Z
		if coord.x == 0 and g_coord.x == 0:
			if abs(coord.y - g_coord.y) < min_dist:
				return false
		# В 2D пространстве чанков (включая боковые)
		var d: float = Vector2(coord).distance_to(Vector2(g_coord))
		if d < float(min_dist):
			return false
	return true

# Проверка дистанции до оазисов (минимум min_dist чанков и разделение с заправками)
func _is_far_enough_from_oases(coord: Vector2i, min_dist: int = MIN_OASIS_CHUNK_DIST) -> bool:
	for o_coord: Vector2i in spawned_oases.keys():
		if coord.x == 0 and o_coord.x == 0:
			if abs(coord.y - o_coord.y) < min_dist:
				return false
		var d: float = Vector2(coord).distance_to(Vector2(o_coord))
		if d < float(min_dist):
			return false

	# Оазис не должен спавниться прямо возле заправки (мин. 3.5 чанка)
	for g_coord: Vector2i in spawned_gas_stations.keys():
		var d: float = Vector2(coord).distance_to(Vector2(g_coord))
		if d < MIN_GAS_OASIS_SEPARATION:
			return false
	return true

func _populate_chunk_scenery(chunk: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	var is_spawn_center: bool = (coord == Vector2i(0, 0))
	var half: float = (chunk_size * 0.5) - 3.0
	var exclusion_zones: Array[Vector3] = [] # x, z, radius

	if is_spawn_center:
		exclusion_zones.append(Vector3(0.0, 0.0, 16.0))

	# 0. Процедурные события на центральном тракте каравана (coord.x == 0)
	if coord.x == 0 and coord.y < 0:
		# Если этот чанк уже был зафиксирован ранее при стриминге
		if spawned_gas_stations.has(coord):
			var data: Dictionary = spawned_gas_stations[coord]
			var node := RoadEvents3D.create_gas_station()
			node.rotation.y = data.get("rot", 0.0)
			node.position = Vector3(data.get("side_x", 14.5), 0.0, data.get("z", 0.0))
			chunk.add_child(node)
			exclusion_zones.append(Vector3(data.get("side_x", 14.5), data.get("z", 0.0), 18.0))

		elif spawned_oases.has(coord):
			var data: Dictionary = spawned_oases[coord]
			var node := RoadEvents3D.create_oasis()
			node.position = Vector3(data.get("side_x", 14.5), 0.0, data.get("z", 0.0))
			chunk.add_child(node)
			exclusion_zones.append(Vector3(data.get("side_x", 14.5), data.get("z", 0.0), 18.0))

		else:
			# Новый чанк. Проверяем возможность спавна заправки или оазиса с ограничением в 4-5 чанков
			var req_gas_dist: int = rng.randi_range(4, 5)
			var can_gas: bool = (coord.y <= -4) and _is_far_enough_from_gas_stations(coord, req_gas_dist)
			var can_oasis: bool = (coord.y <= -3) and _is_far_enough_from_oases(coord, rng.randi_range(4, 5))

			# 75% вероятность наличия дорожного события в чанке
			if rng.randf() < 0.75:
				var want_goodie := false
				var pick_gas := false
				var pick_oasis := false

				# Ништяки могут появиться ТОЛЬКО если соблюдена минимальная дистанция (4-5 чанков)
				if can_gas or can_oasis:
					# Шанс ништяка при выполнении кулдауна дистанции (60% — в 2 раза чаще)
					if rng.randf() < 0.60:
						want_goodie = true
						if can_gas and can_oasis:
							# Оазисы реже заправок (35% оазис, 65% заправка)
							if rng.randf() < 0.35:
								pick_oasis = true
							else:
								pick_gas = true
						elif can_gas:
							pick_gas = true
						elif can_oasis:
							pick_oasis = true

				if want_goodie and pick_gas:
					# --- ЗАБРОШЕННАЯ ЗАПРАВКА ---
					# Появляется не ближе 8-10 чанков от других заправок!
					var side_x: float = 14.5 if rng.randf() < 0.5 else -14.5
					var goodie_z: float = rng.randf_range(-22.0, 22.0)
					var rot_y: float = deg_to_rad(-90.0 if side_x > 0.0 else 90.0)

					var node := RoadEvents3D.create_gas_station()
					node.rotation.y = rot_y
					node.position = Vector3(side_x, 0.0, goodie_z)
					chunk.add_child(node)
					exclusion_zones.append(Vector3(side_x, goodie_z, 18.0))

					spawned_gas_stations[coord] = { "side_x": side_x, "z": goodie_z, "rot": rot_y }

				elif want_goodie and pick_oasis:
					# --- ПУСТЫННЫЙ ОАЗИС ---
					# Редкий оазис с пальмами, водоемом и древним сундуком
					var side_x: float = 15.0 if rng.randf() < 0.5 else -15.0
					var goodie_z: float = rng.randf_range(-22.0, 22.0)

					var node := RoadEvents3D.create_oasis()
					node.position = Vector3(side_x, 0.0, goodie_z)
					chunk.add_child(node)
					exclusion_zones.append(Vector3(side_x, goodie_z, 18.0))

					spawned_oases[coord] = { "side_x": side_x, "z": goodie_z }

				else:
					# --- ДОРОЖНОЕ ПРЕПЯТСТВИЕ ---
					# Баррикада с взрывными бочками, автозавал или камнепад
					var obst_type: int = rng.randi() % 3
					var obst_node: Node3D = null
					match obst_type:
						0:
							obst_node = RoadEvents3D.create_road_barricade()
						1:
							obst_node = RoadEvents3D.create_wreck_blockade()
						_:
							obst_node = RoadEvents3D.create_rockfall_blockade()

					var obst_z: float = rng.randf_range(-32.0, 32.0)
					obst_node.position = Vector3(0.0, 0.0, obst_z)
					chunk.add_child(obst_node)
					exclusion_zones.append(Vector3(0.0, obst_z, 14.0))

	# В диких боковых чанках (coord.x != 0) редкий оазис или заправка в глубине пустыни (1.2% шанс)
	elif coord.x != 0 and abs(coord.y) > 0:
		if spawned_gas_stations.has(coord):
			var data: Dictionary = spawned_gas_stations[coord]
			var node := RoadEvents3D.create_gas_station()
			node.rotation.y = data.get("rot", 0.0)
			node.position = Vector3(data.get("x", 0.0), 0.0, data.get("z", 0.0))
			chunk.add_child(node)
			exclusion_zones.append(Vector3(data.get("x", 0.0), data.get("z", 0.0), 18.0))

		elif spawned_oases.has(coord):
			var data: Dictionary = spawned_oases[coord]
			var node := RoadEvents3D.create_oasis()
			node.position = Vector3(data.get("x", 0.0), 0.0, data.get("z", 0.0))
			chunk.add_child(node)
			exclusion_zones.append(Vector3(data.get("x", 0.0), data.get("z", 0.0), 18.0))

		elif rng.randf() < 0.024:
			var can_gas_wild: bool = _is_far_enough_from_gas_stations(coord, 5)
			var can_oasis_wild: bool = _is_far_enough_from_oases(coord, 4)
			var wild_z: float = rng.randf_range(-28.0, 28.0)
			var wild_x: float = rng.randf_range(-28.0, 28.0)

			if can_oasis_wild and (rng.randf() < 0.70 or not can_gas_wild):
				var wild_node := RoadEvents3D.create_oasis()
				wild_node.position = Vector3(wild_x, 0.0, wild_z)
				chunk.add_child(wild_node)
				exclusion_zones.append(Vector3(wild_x, wild_z, 18.0))
				spawned_oases[coord] = { "x": wild_x, "z": wild_z }
			elif can_gas_wild:
				var wild_node := RoadEvents3D.create_gas_station()
				var rot_y: float = rng.randf_range(0.0, TAU)
				wild_node.rotation.y = rot_y
				wild_node.position = Vector3(wild_x, 0.0, wild_z)
				chunk.add_child(wild_node)
				exclusion_zones.append(Vector3(wild_x, wild_z, 18.0))
				spawned_gas_stations[coord] = { "x": wild_x, "z": wild_z, "rot": rot_y }

	# Вспомогательная лямбда проверки попадания в зону исключения
	var is_in_exclusion := func(p: Vector3) -> bool:
		for z: Vector3 in exclusion_zones:
			var dx: float = p.x - z.x
			var dz: float = p.z - z.y
			if (dx * dx + dz * dz) < (z.z * z.z):
				return true
		return false

	# 1. Засохшие деревья (1-3 на чанк)
	var tree_count: int = rng.randi_range(1, 3)
	for i in range(tree_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, true)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.85, 1.35)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_tree(chunk, pos, s, rot_y)

	# 2. Кактусы Сагуаро (2-4 на чанк)
	var cactus_count: int = rng.randi_range(2, 4)
	for i in range(cactus_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, true)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.85, 1.35)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_cactus(chunk, pos, s, rot_y)

	# 3. Разбитые ржавые машины на обочинах (35% шанс)
	if rng.randf() < 0.35 and not is_spawn_center:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, true, 2.0)
		if not is_in_exclusion.call(pos):
			var s: float = rng.randf_range(0.9, 1.25)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_car(chunk, pos, s, rot_y)

	# 4. Скальные валуны (50% шанс — укрытия на склонах барханов)
	if rng.randf() < 0.50:
		var rock_count: int = rng.randi_range(1, 2)
		for i in range(rock_count):
			var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, true, 4.0)
			if is_in_exclusion.call(pos):
				continue
			var s: float = rng.randf_range(0.85, 1.4)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_rock(chunk, pos, s, rot_y, rng)

	# 5. Черепа и кости в песке (0-2 на чанк)
	var bones_count: int = rng.randi_range(0, 2)
	for i in range(bones_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, false)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.9, 1.3)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_bones(chunk, pos, s, rot_y)


	# 6. Перекати-поле (12% шанс на чанк)
	if rng.randf() < 0.12 and TUMBLEWEED_SCENE:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, half, rng, false)
		var tw := TUMBLEWEED_SCENE.instantiate() as Node3D
		if tw:
			tw.position = pos + Vector3(0.0, 0.5, 0.0)
			chunk.add_child(tw)

# Расчет позиции объекта с обязательной проверкой свободного коридора дороги каравана
func _get_prop_pos(chunk_wx: float, half: float, rng: RandomNumberGenerator, is_obstacle: bool, extra_clearance: float = 0.0) -> Vector3:
	var lx: float = rng.randf_range(-half, half)
	var lz: float = rng.randf_range(-half, half)

	if is_obstacle:
		var world_x: float = chunk_wx + lx
		var required_clear: float = road_clear_width + extra_clearance
		if abs(world_x) < required_clear:
			var side_sign: float = 1.0 if world_x >= 0.0 else -1.0
			var shift: float = (required_clear + rng.randf_range(1.2, 5.0)) * side_sign
			lx = clampf(shift - chunk_wx, -half, half)

	return Vector3(lx, 0.0, lz)

# =========================================================================
# ФАБРИКИ 3D ДЕКОРАЦИЙ
# =========================================================================
func _create_tree(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var tree_body := StaticBody3D.new()
	tree_body.position = pos
	tree_body.rotation.y = rot_y

	var model := DesertScenery3D.create_dead_tree_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 4.8 * s
	cyl.radius = 0.45 * s
	col.shape = cyl
	col.position.y = 2.4 * s

	tree_body.add_child(model)
	tree_body.add_child(col)
	parent.add_child(tree_body)

func _create_cactus(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var cact_body := StaticBody3D.new()
	cact_body.position = pos
	cact_body.rotation.y = rot_y

	var model := DesertScenery3D.create_cactus_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 3.0 * s
	cyl.radius = 0.35 * s
	col.shape = cyl
	col.position.y = 1.5 * s

	cact_body.add_child(model)
	cact_body.add_child(col)
	parent.add_child(cact_body)

func _create_car(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var car_body := StaticBody3D.new()
	car_body.position = pos
	car_body.rotation.y = rot_y

	var model := DesertScenery3D.create_wrecked_car_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.8 * s, 1.8 * s, 2.2 * s)
	col.shape = box
	col.position.y = 0.9 * s

	car_body.add_child(model)
	car_body.add_child(col)
	parent.add_child(car_body)

func _create_rock(parent: Node3D, pos: Vector3, s: float, rot_y: float, rng: RandomNumberGenerator) -> void:
	var rock_body := StaticBody3D.new()
	rock_body.position = pos
	rock_body.rotation.y = rot_y

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var sz := Vector3(
		rng.randf_range(3.0, 5.5) * s,
		rng.randf_range(1.6, 2.8) * s,
		rng.randf_range(2.5, 4.2) * s
	)
	box.size = sz
	mi.mesh = box
	mi.material_override = mat_rock if rng.randf() > 0.4 else mat_rock_dark
	mi.position.y = sz.y * 0.45
	mi.rotation = Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))

	var col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = sz
	col.shape = col_box
	col.position = mi.position

	rock_body.add_child(mi)
	rock_body.add_child(col)
	parent.add_child(rock_body)

func _create_bones(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var model := DesertScenery3D.create_skull_bones_3d()
	model.position = pos
	model.rotation.y = rot_y
	model.scale = Vector3(s, s, s)
	parent.add_child(model)
