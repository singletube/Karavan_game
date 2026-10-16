extends Node3D

class_name DesertGenerator

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

# Уникальный сид мира для полной случайности каждой новой игры (и синхронизации в мультиплеере)
var world_seed            : int        = 0
var active_chunks         : Dictionary = {} # Vector2i -> Node3D
var current_center_coord  : Vector2i   = Vector2i(999999, 999999)
var update_timer          : float      = 0.0
const UPDATE_INTERVAL     : float      = 0.20 # Частота проверки положения цели (сек)

# История и параметры спавна редких точек интереса (POI) и развалин с лутом
var spawned_pois         : Dictionary = {} # Vector2i -> Dictionary { type, side_x, z, rot }
var spawned_gas_stations : Dictionary = {} # Vector2i -> Dictionary
var spawned_oases        : Dictionary = {} # Vector2i -> Dictionary
const MIN_POI_CHUNK_DIST : int   = 2       # Минимум 2 чанка между любыми постройками с лутом (~240м)

# Переиспользуемые ресурсы (Shared Meshes & Materials для максимальной производительности)
var shared_floor_mesh     : BoxMesh
var shared_floor_shape    : BoxShape3D
var sand_material         : ShaderMaterial
var mat_rock              : StandardMaterial3D
var mat_rock_dark         : StandardMaterial3D

static var instance: DesertGenerator = null

func _enter_tree() -> void:
	instance = self
	add_to_group("desert_generator")

func _exit_tree() -> void:
	if instance == self:
		instance = null

static func get_height(wx: float, wz: float) -> float:
	if instance and is_instance_valid(instance):
		return instance.get_terrain_height(wx, wz)
	return 0.0

static func get_normal(wx: float, wz: float) -> Vector3:
	if instance and is_instance_valid(instance):
		return instance.get_terrain_normal(wx, wz)
	return Vector3.UP

# =========================================================================
# ВЫСОТА И РЕЛЬЕФ ПУСТЫНИ (PROCEDURAL DUNES & ELEVATION)
# =========================================================================
func get_raw_terrain_height(wx: float, wz: float) -> float:
	var seed_f: float = float(world_seed % 10000) * 0.05

	# 1. Основной равномерный и пологий рельеф песчаных барханов (gentle rolling dunes)
	var ang: float = deg_to_rad(28.0)
	var wind_u: float = wx * cos(ang) + wz * sin(ang)
	var wind_v: float = -wx * sin(ang) + wz * cos(ang)

	# Длинные очень пологие песчаные увалы (длина волны ~260м, перепад всего 0.65м)
	var swell1: float = sin(wind_u * 0.024 + seed_f) * 0.65
	# Мягкие поперечные волны (длина ~150м, перепад 0.35м)
	var swell2: float = cos(wind_v * 0.042 + seed_f * 1.3) * 0.35
	# Естественная легкая рябь бархана (длина ~60м, перепад всего 0.12м)
	var swell3: float = sin((wind_u * 0.10 + wind_v * 0.07) + seed_f * 0.7) * 0.12

	var gentle_dunes: float = swell1 + swell2 + swell3 # Общий перепад ±1.1м - очень пологий и мягкий

	# 2. Редкие одиночные песчаные холмы / гряды вдали от дороги (occasional distant low hills)
	# Масштаб 380-480м, появляются только изредка
	var m1: float = sin(wx * 0.0078 + wz * 0.0052 + seed_f * 0.4)
	var m2: float = cos(wx * 0.0061 - wz * 0.0094 + seed_f * 0.8)
	var mount_sample: float = m1 * m2 # от -1.0 до 1.0

	var big_mountain: float = 0.0
	if mount_sample > 0.45:
		var norm_peak: float = (mount_sample - 0.45) / 0.55 # от 0.0 до 1.0
		# Формируем плавную куполообразную вершину
		norm_peak = norm_peak * norm_peak * (3.0 - 2.0 * norm_peak)
		big_mountain = pow(norm_peak, 1.8) * 4.5 # Высота холмов ограничена ~4.5 метрами

	# Холмы не приближаются к дороге каравана (|wx| < 24м), вырастая плавно вдали
	var road_mount_mask: float = clampf((absf(wx) - 24.0) / 30.0, 0.0, 1.0)
	road_mount_mask = road_mount_mask * road_mount_mask * (3.0 - 2.0 * road_mount_mask)
	big_mountain *= road_mount_mask

	var wild_h: float = gentle_dunes + big_mountain

	# 3. Сглаженный тракт каравана по центру дороги (|wx| < 5.0м)
	# Дорога практически плоская и комфортная для каравана (перепад всего ±0.2м)
	var road_dist: float = absf(wx)
	var road_blend: float = clampf((road_dist - 3.5) / 10.0, 0.0, 1.0)
	road_blend = road_blend * road_blend * (3.0 - 2.0 * road_blend)

	var road_wave: float = sin(wz * 0.020 + seed_f) * 0.20

	var h: float = lerpf(road_wave, wild_h, road_blend)

	# 4. Стартовая площадка в точке высадки каравана (X=0, Z=0)
	var start_dist: float = sqrt(wx * wx + wz * wz)
	if start_dist < 28.0:
		var start_blend: float = clampf(start_dist / 28.0, 0.0, 1.0)
		start_blend = start_blend * start_blend * (3.0 - 2.0 * start_blend)
		h = lerpf(0.0, h, start_blend)

	return h

func get_terrain_height(wx: float, wz: float) -> float:
	var h: float = get_raw_terrain_height(wx, wz)

	# Выравнивание фундамента под постройки (POI Foundation Leveling)
	for p_coord in spawned_pois.keys():
		var data: Dictionary = spawned_pois[p_coord]
		var c_world_x: float = float(p_coord.x) * chunk_size
		var c_world_z: float = float(p_coord.y) * chunk_size
		var p_x: float = c_world_x + data.get("side_x", data.get("x", 0.0))
		var p_z: float = c_world_z + data.get("z", 0.0)

		var dx: float = wx - p_x
		var dz: float = wz - p_z
		var d: float = sqrt(dx * dx + dz * dz)
		if d < 22.0:
			var base_h: float = get_raw_terrain_height(p_x, p_z)
			var blend: float = clampf((d - 10.0) / 12.0, 0.0, 1.0)
			blend = blend * blend * (3.0 - 2.0 * blend)
			h = lerpf(base_h, h, blend)

	return h

func get_terrain_normal(wx: float, wz: float) -> Vector3:
	var eps: float = 0.5
	var h_l: float = get_terrain_height(wx - eps, wz)
	var h_r: float = get_terrain_height(wx + eps, wz)
	var h_d: float = get_terrain_height(wx, wz - eps)
	var h_u: float = get_terrain_height(wx, wz + eps)
	return Vector3(h_l - h_r, 2.0 * eps, h_d - h_u).normalized()

func _ready() -> void:
	randomize()
	if world_seed == 0:
		world_seed = randi() & 0x7FFFFFFF
		if world_seed == 0:
			world_seed = 1337
	_cleanup_old_static_world()
	_init_shared_resources()
	# Мгновенная генерация начальных 49 чанков вокруг точки старта
	_update_chunks(true)

func send_full_sync_to_peer(peer_id: int) -> void:
	rpc_id(peer_id, "sync_world_seed", world_seed)

@rpc("authority", "reliable")
func sync_world_seed(new_seed: int) -> void:
	set_world_seed(new_seed)

func set_world_seed(new_seed: int) -> void:
	if world_seed == new_seed:
		return
	world_seed = new_seed
	# Полная перегенерация чанков под сид сервера
	for coord in active_chunks.keys():
		var c = active_chunks[coord]
		if is_instance_valid(c):
			c.queue_free()
	active_chunks.clear()
	spawned_pois.clear()
	spawned_gas_stations.clear()
	spawned_oases.clear()
	current_center_coord = Vector2i(999999, 999999)
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
	# Мультипликативное хеширование координат чанка с уникальным сидом мира
	var h: int = (cx * 73856093) ^ (cz * 19349663) ^ (world_seed * 83492791)
	return abs(h)

func _spawn_chunk(coord: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	# Центр чанка в мировых координатах
	chunk.position = Vector3(float(coord.x) * chunk_size, 0.0, float(coord.y) * chunk_size)
	add_child(chunk)
	active_chunks[coord] = chunk

	# 1. Секция пола чанка (бесшовный 3D рельеф песчаных дюн с физической коллизией)
	_build_chunk_floor(chunk, coord)

	# 2. Процедурные декорации чанка с детерминированным генератором
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed(coord.x, coord.y)

	_populate_chunk_scenery(chunk, coord, rng)

func _build_chunk_floor(chunk: Node3D, coord: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.name = "ChunkFloor"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if sand_material:
		st.set_material(sand_material)

	var steps: int = 16
	var step_sz: float = chunk_size / float(steps)
	var half: float = chunk_size * 0.5
	var chunk_origin_x: float = float(coord.x) * chunk_size
	var chunk_origin_z: float = float(coord.y) * chunk_size

	# 1. Генерация вершин песчаных дюн
	for iz in range(steps + 1):
		var local_z: float = float(iz) * step_sz - half
		var world_z: float = chunk_origin_z + local_z
		var v: float = float(iz) / float(steps)

		for ix in range(steps + 1):
			var local_x: float = float(ix) * step_sz - half
			var world_x: float = chunk_origin_x + local_x
			var u: float = float(ix) / float(steps)

			var h: float = get_terrain_height(world_x, world_z)
			var n: Vector3 = get_terrain_normal(world_x, world_z)

			st.set_normal(n)
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(local_x, h, local_z))

	# 2. Построение треугольников
	for iz in range(steps):
		var row_a: int = iz * (steps + 1)
		var row_b: int = (iz + 1) * (steps + 1)
		for ix in range(steps):
			var i0: int = row_a + ix
			var i1: int = row_a + ix + 1
			var i2: int = row_b + ix
			var i3: int = row_b + ix + 1

			# Треугольник 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)

			# Треугольник 2
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)

	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if sand_material:
		mi.material_override = sand_material
	body.add_child(mi)

	var col_shape := mesh.create_trimesh_shape()
	if col_shape:
		var col := CollisionShape3D.new()
		col.shape = col_shape
		body.add_child(col)

	chunk.add_child(body)

# Создание экземпляра постройки по типу
func _create_poi_node(p_type: String) -> Node3D:
	match p_type:
		"gas_station":
			return RoadEvents3D.create_gas_station()
		"oasis":
			return RoadEvents3D.create_oasis()
		"crawl_shelter":
			return RoadEvents3D.create_crawlspace_shelter_ruins()
		"ancient_ruins":
			return RoadEvents3D.create_ancient_ruins()
		"bunker_ruins":
			return RoadEvents3D.create_bunker_ruins()
		"plane_wreck":
			return RoadEvents3D.create_plane_wreck_ruins()
		"clay_ruins":
			return RoadEvents3D.create_clay_ruins()
		_:
			return RoadEvents3D.create_gas_station()

# Проверка дистанции до любых уже размещенных построек/развалин с лутом (минимум min_dist чанков)
func _is_far_enough_from_pois(coord: Vector2i, min_dist: int = MIN_POI_CHUNK_DIST) -> bool:
	for p_coord: Vector2i in spawned_pois.keys():
		# На дороге (X=0) проверяем продольное расстояние по Z
		if coord.x == 0 and p_coord.x == 0:
			if abs(coord.y - p_coord.y) < min_dist:
				return false
		# В 2D пространстве чанков
		var d: float = Vector2(coord).distance_to(Vector2(p_coord))
		if d < float(min_dist):
			return false
	return true

# Выбор типа развалины / постройки
func _pick_random_poi_type(rng: RandomNumberGenerator, is_road: bool) -> String:
	var roll := rng.randf()
	if is_road:
		# На караванном тракте: разнообразные постройки
		if roll < 0.18:
			return "gas_station"
		elif roll < 0.32:
			return "oasis"
		elif roll < 0.48:
			return "crawl_shelter"
		elif roll < 0.64:
			return "ancient_ruins"
		elif roll < 0.78:
			return "bunker_ruins"
		elif roll < 0.90:
			return "plane_wreck"
		else:
			return "clay_ruins"
	else:
		# В глубине пустыни: загадочные развалины, обломки и тайники
		if roll < 0.22:
			return "crawl_shelter"
		elif roll < 0.42:
			return "ancient_ruins"
		elif roll < 0.60:
			return "plane_wreck"
		elif roll < 0.76:
			return "bunker_ruins"
		elif roll < 0.88:
			return "clay_ruins"
		elif roll < 0.95:
			return "oasis"
		else:
			return "gas_station"

func _populate_starting_location(chunk: Node3D, coord: Vector2i, rng: RandomNumberGenerator, exclusion_zones: Array[Vector3]) -> void:
	# Безопасная зона спавна каравана, осла и игроков (радиус 10м вокруг центра X=0, Z=0)
	exclusion_zones.append(Vector3(0.0, 0.0, 10.0))

	if spawned_pois.has(coord):
		var data: Dictionary = spawned_pois[coord]
		var p_type: String = data.get("type", "gas_station")
		var node := _create_poi_node(p_type)
		node.rotation.y = data.get("rot", 0.0)
		var sx: float = data.get("side_x", 16.0)
		var sz: float = data.get("z", 0.0)
		var sy: float = get_terrain_height(chunk.position.x + sx, chunk.position.z + sz)
		node.position = Vector3(sx, sy - 0.06, sz)
		chunk.add_child(node)
		_setup_poi_loot_crate(node, coord)
		exclusion_zones.append(Vector3(sx, sz, 18.0))
		return

	# Случайная генерация стартовой локации:
	# 75% вероятность — старт каравана прямо возле полноценной постройки или развалин!
	# (Заброшенная заправка, цветущий оазис с пальмами, древний храм, бункер, упавший самолет, глиняный караван-сарай или тайник)
	var roll := rng.randf()
	if roll < 0.75:
		var p_type := _pick_random_poi_type(rng, true)
		var side_x: float = 16.0 if rng.randf() < 0.5 else -16.0
		var goodie_z: float = rng.randf_range(-12.0, 12.0)
		var rot_y: float = deg_to_rad(-90.0 if side_x > 0.0 else 90.0)
		if p_type == "oasis" or p_type == "ancient_ruins" or p_type == "clay_ruins" or p_type == "crawl_shelter":
			rot_y += deg_to_rad(rng.randf_range(-15.0, 15.0))

		var node := _create_poi_node(p_type)
		node.rotation.y = rot_y
		var sy: float = get_terrain_height(chunk.position.x + side_x, chunk.position.z + goodie_z)
		node.position = Vector3(side_x, sy - 0.06, goodie_z)
		chunk.add_child(node)
		_setup_poi_loot_crate(node, coord)
		exclusion_zones.append(Vector3(side_x, goodie_z, 18.0))

		spawned_pois[coord] = { "type": p_type, "side_x": side_x, "z": goodie_z, "rot": rot_y }
		if p_type == "gas_station":
			spawned_gas_stations[coord] = spawned_pois[coord]
		elif p_type == "oasis":
			spawned_oases[coord] = spawned_pois[coord]
	else:
		# 25% вероятность — аутентичный стартовый лагерь караванщиков в пустоши:
		# разбитые машины, склад горючего, дорожные знаки и стартовый ящик припасов
		var camp_side: float = 13.0 if rng.randf() < 0.5 else -13.0
		var camp_z: float = rng.randf_range(-10.0, 10.0)
		exclusion_zones.append(Vector3(camp_side, camp_z, 14.0))

		# Разбитая машина на обочине лагеря
		var car_y: float = get_terrain_height(chunk.position.x + camp_side, chunk.position.z + camp_z - 3.5)
		_create_car(chunk, Vector3(camp_side, car_y, camp_z - 3.5), rng.randf_range(0.95, 1.2), rng.randf_range(0.0, TAU))
		# Склад топливных бочек
		var drums_offset: float = -2.5 if camp_side > 0.0 else 2.5
		var drums_y: float = get_terrain_height(chunk.position.x + camp_side + drums_offset, chunk.position.z + camp_z + 2.5)
		_create_oil_drums(chunk, Vector3(camp_side + drums_offset, drums_y, camp_z + 2.5), 1.0, deg_to_rad(15.0))
		# Дорожный указатель
		var sign_y: float = get_terrain_height(chunk.position.x + camp_side * 0.65, chunk.position.z + camp_z)
		_create_road_sign(chunk, Vector3(camp_side * 0.65, sign_y, camp_z), 1.0, deg_to_rad(180.0 if camp_side > 0.0 else 0.0))
		# Каменный ориентир
		var cairn_y: float = get_terrain_height(chunk.position.x + camp_side, chunk.position.z + camp_z + 4.5)
		_create_cairn(chunk, Vector3(camp_side, cairn_y, camp_z + 4.5), 1.2, 0.0)

		# Стартовый ящик с припасами на привале караванщиков
		var starter_crate := RoadEvents3D._create_loot_crate("ЗАБРАТЬ СТАРТОВЫЕ ПРИПАСЫ [E]", true)
		var crate_y: float = get_terrain_height(chunk.position.x + camp_side, chunk.position.z + camp_z)
		starter_crate.position = Vector3(camp_side, crate_y - 0.06, camp_z)
		chunk.add_child(starter_crate)
		_setup_poi_loot_crate(starter_crate, coord)

func _populate_chunk_scenery(chunk: Node3D, coord: Vector2i, rng: RandomNumberGenerator) -> void:
	var is_spawn_center: bool = (coord == Vector2i(0, 0))
	var half: float = (chunk_size * 0.5) - 3.0
	var exclusion_zones: Array[Vector3] = [] # x, z, radius

	# 0. Процедурные события на центральном тракте каравана (coord.x == 0)
	if is_spawn_center:
		_populate_starting_location(chunk, coord, rng, exclusion_zones)
	elif coord.x == 0 and coord.y < 0:
		if spawned_pois.has(coord):
			var data: Dictionary = spawned_pois[coord]
			var p_type: String = data.get("type", "gas_station")
			var node := _create_poi_node(p_type)
			node.rotation.y = data.get("rot", 0.0)
			var sx: float = data.get("side_x", 14.5)
			var sz: float = data.get("z", 0.0)
			var sy: float = get_terrain_height(chunk.position.x + sx, chunk.position.z + sz)
			node.position = Vector3(sx, sy - 0.06, sz)
			chunk.add_child(node)
			_setup_poi_loot_crate(node, coord)
			exclusion_zones.append(Vector3(sx, sz, 18.0))

		else:
			var can_poi: bool = (coord.y <= -1) and _is_far_enough_from_pois(coord, rng.randi_range(2, 4))

			# 85% вероятность наличия дорожного события в чанке
			if rng.randf() < 0.85:
				if can_poi and rng.randf() < 0.82:
					var p_type := _pick_random_poi_type(rng, true)
					var side_x: float = 14.5 if rng.randf() < 0.5 else -14.5
					var goodie_z: float = rng.randf_range(-22.0, 22.0)
					var rot_y: float = deg_to_rad(-90.0 if side_x > 0.0 else 90.0)
					if p_type == "oasis" or p_type == "ancient_ruins" or p_type == "clay_ruins" or p_type == "crawl_shelter":
						rot_y += deg_to_rad(randf_range(-15.0, 15.0))

					var node := _create_poi_node(p_type)
					node.rotation.y = rot_y
					var sy: float = get_terrain_height(chunk.position.x + side_x, chunk.position.z + goodie_z)
					node.position = Vector3(side_x, sy - 0.06, goodie_z)
					chunk.add_child(node)
					_setup_poi_loot_crate(node, coord)
					exclusion_zones.append(Vector3(side_x, goodie_z, 18.0))

					spawned_pois[coord] = { "type": p_type, "side_x": side_x, "z": goodie_z, "rot": rot_y }
					if p_type == "gas_station":
						spawned_gas_stations[coord] = spawned_pois[coord]
					elif p_type == "oasis":
						spawned_oases[coord] = spawned_pois[coord]

				else:
					# --- ДОРОЖНОЕ ПРЕПЯТСТВИЕ ---
					var obst_id: String = "%d_%d" % [coord.x, coord.y]
					if NetworkManager == null or not NetworkManager.cleared_obstacles.has(obst_id):
						var obst_type: int = rng.randi() % 3
						var obst_node: Node3D = null
						match obst_type:
							0:
								obst_node = RoadEvents3D.create_road_barricade()
							1:
								obst_node = RoadEvents3D.create_wreck_blockade()
							_:
								obst_node = RoadEvents3D.create_rockfall_blockade()

						obst_node.name = "RoadObstacle"
						obst_node.set_meta("obstacle_id", obst_id)
						var obst_z: float = rng.randf_range(-32.0, 32.0)
						var obst_y: float = get_terrain_height(chunk.position.x, chunk.position.z + obst_z)
						obst_node.position = Vector3(0.0, obst_y - 0.06, obst_z)
						chunk.add_child(obst_node)
						exclusion_zones.append(Vector3(0.0, obst_z, 14.0))

	# В диких боковых чанках (coord.x != 0) развалины и постройки в глубине пустыни (шанс 6.8%)
	elif coord.x != 0 and abs(coord.y) > 0:
		if spawned_pois.has(coord):
			var data: Dictionary = spawned_pois[coord]
			var p_type: String = data.get("type", "ancient_ruins")
			var node := _create_poi_node(p_type)
			node.rotation.y = data.get("rot", 0.0)
			var wx: float = data.get("x", 0.0)
			var wz: float = data.get("z", 0.0)
			var wy: float = get_terrain_height(chunk.position.x + wx, chunk.position.z + wz)
			node.position = Vector3(wx, wy - 0.06, wz)
			chunk.add_child(node)
			_setup_poi_loot_crate(node, coord)
			exclusion_zones.append(Vector3(wx, wz, 18.0))

		elif rng.randf() < 0.068 and _is_far_enough_from_pois(coord, 2):
			# В дикой пустыне спавнятся развалины храмов, обломки самолетов, бункеры, караван-сараи, засыпанные схроны
			var p_type := _pick_random_poi_type(rng, false)
			var wild_z: float = rng.randf_range(-26.0, 26.0)
			var wild_x: float = rng.randf_range(-26.0, 26.0)
			var rot_y: float = rng.randf_range(0.0, TAU)

			var wild_node := _create_poi_node(p_type)
			wild_node.rotation.y = rot_y
			var wild_y: float = get_terrain_height(chunk.position.x + wild_x, chunk.position.z + wild_z)
			wild_node.position = Vector3(wild_x, wild_y - 0.06, wild_z)
			chunk.add_child(wild_node)
			_setup_poi_loot_crate(wild_node, coord)
			exclusion_zones.append(Vector3(wild_x, wild_z, 18.0))

			spawned_pois[coord] = { "type": p_type, "x": wild_x, "z": wild_z, "rot": rot_y }
			if p_type == "gas_station":
				spawned_gas_stations[coord] = spawned_pois[coord]
			elif p_type == "oasis":
				spawned_oases[coord] = spawned_pois[coord]

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
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.85, 1.35)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_tree(chunk, pos, s, rot_y)

	# 2. Кактусы Сагуаро (2-4 на чанк)
	var cactus_count: int = rng.randi_range(2, 4)
	for i in range(cactus_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.85, 1.35)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_cactus(chunk, pos, s, rot_y)

	# 3. Разбитые ржавые машины на обочинах (35% шанс)
	if rng.randf() < 0.35:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true, 2.0)
		if not is_in_exclusion.call(pos):
			var s: float = rng.randf_range(0.9, 1.25)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_car(chunk, pos, s, rot_y)

	# 4. Скальные валуны (50% шанс — укрытия на склонах барханов)
	if rng.randf() < 0.50:
		var rock_count: int = rng.randi_range(1, 2)
		for i in range(rock_count):
			var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true, 4.0)
			if is_in_exclusion.call(pos):
				continue
			var s: float = rng.randf_range(0.85, 1.4)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_rock(chunk, pos, s, rot_y, rng)

	# 5. Черепа и кости в песке (0-2 на чанк)
	var bones_count: int = rng.randi_range(0, 2)
	for i in range(bones_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, false)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.9, 1.3)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_bones(chunk, pos, s, rot_y)

	# 6. Перекати-поле (12% шанс на чанк)
	if rng.randf() < 0.12 and TUMBLEWEED_SCENE:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, false)
		var tw := TUMBLEWEED_SCENE.instantiate() as Node3D
		if tw:
			tw.position = pos + Vector3(0.0, 0.5, 0.0)
			chunk.add_child(tw)

	# 7. Сухие пустынные кустарники (2-5 на чанк)
	var bush_count: int = rng.randi_range(2, 5)
	for i in range(bush_count):
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, false)
		if is_in_exclusion.call(pos):
			continue
		var s: float = rng.randf_range(0.8, 1.35)
		var rot_y: float = rng.randf_range(0.0, TAU)
		_create_bush(chunk, pos, s, rot_y)

	# 8. Каменные туры / ориентиры караванщиков (40% шанс на чанк)
	if rng.randf() < 0.40:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true, 1.5)
		if not is_in_exclusion.call(pos):
			var s: float = rng.randf_range(0.9, 1.3)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_cairn(chunk, pos, s, rot_y)

	# 9. Заброшенные телеграфные столбы вдоль обочины (35% шанс в придорожных чанках)
	if abs(coord.x) <= 1 and rng.randf() < 0.35:
		var pole_side: float = 7.0 if rng.randf() < 0.5 else -7.0
		var pole_z: float = rng.randf_range(-half * 0.8, half * 0.8)
		var pole_y: float = get_terrain_height(chunk.position.x + pole_side, chunk.position.z + pole_z)
		var pole_pos := Vector3(pole_side, pole_y, pole_z)
		if not is_in_exclusion.call(pole_pos):
			var s: float = rng.randf_range(0.95, 1.15)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_telegraph_pole(chunk, pole_pos, s, rot_y)

	# 10. Ржавые дорожные знаки (28% шанс у обочин дороги)
	if abs(coord.x) <= 1 and rng.randf() < 0.28:
		var sign_side: float = 6.0 if rng.randf() < 0.5 else -6.0
		var sign_z: float = rng.randf_range(-half * 0.8, half * 0.8)
		var sign_y: float = get_terrain_height(chunk.position.x + sign_side, chunk.position.z + sign_z)
		var sign_pos := Vector3(sign_side, sign_y, sign_z)
		if not is_in_exclusion.call(sign_pos):
			var s: float = rng.randf_range(0.9, 1.2)
			var rot_y: float = deg_to_rad(90.0 if sign_side < 0.0 else -90.0) + rng.randf_range(-0.3, 0.3)
			_create_road_sign(chunk, sign_pos, s, rot_y)

	# 11. Скопления ржавых бочек и брошенных шин (25% шанс)
	if rng.randf() < 0.25:
		var pos: Vector3 = _get_prop_pos(chunk.position.x, chunk.position.z, half, rng, true, 2.0)
		if not is_in_exclusion.call(pos):
			var s: float = rng.randf_range(0.9, 1.25)
			var rot_y: float = rng.randf_range(0.0, TAU)
			_create_oil_drums(chunk, pos, s, rot_y)

# Расчет позиции объекта с обязательной проверкой свободного коридора дороги каравана
func _get_prop_pos(chunk_wx: float, chunk_wz: float, half: float, rng: RandomNumberGenerator, is_obstacle: bool, extra_clearance: float = 0.0) -> Vector3:
	var lx: float = rng.randf_range(-half, half)
	var lz: float = rng.randf_range(-half, half)

	if is_obstacle:
		var world_x: float = chunk_wx + lx
		var required_clear: float = road_clear_width + extra_clearance
		if abs(world_x) < required_clear:
			var side_sign: float = 1.0 if world_x >= 0.0 else -1.0
			var shift: float = (required_clear + rng.randf_range(1.2, 5.0)) * side_sign
			lx = clampf(shift - chunk_wx, -half, half)

	var ly: float = get_terrain_height(chunk_wx + lx, chunk_wz + lz)
	return Vector3(lx, ly, lz)

# =========================================================================
# ФАБРИКИ 3D ДЕКОРАЦИЙ
# =========================================================================
func _create_tree(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var tree_body := StaticBody3D.new()
	tree_body.position = pos - Vector3(0.0, 0.25 * s, 0.0)
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
	cact_body.position = pos - Vector3(0.0, 0.18 * s, 0.0)
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
	car_body.position = pos - Vector3(0.0, 0.10 * s, 0.0)
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
	mi.position.y = sz.y * 0.32
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
	model.position = pos - Vector3(0.0, 0.04 * s, 0.0)
	model.rotation.y = rot_y
	model.scale = Vector3(s, s, s)
	parent.add_child(model)

func _setup_poi_loot_crate(poi_node: Node, coord: Vector2i) -> void:
	var crate := poi_node.find_child("LootCrate", true, false)
	if crate:
		var crate_id: String = "%d_%d" % [coord.x, coord.y]
		crate.name = "LootCrate_%s" % crate_id
		crate.set_meta("crate_id", crate_id)
		if NetworkManager != null and NetworkManager.looted_crates.has(crate_id):
			if crate.has_method("mark_already_looted"):
				crate.mark_already_looted()

func _create_bush(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var model := DesertScenery3D.create_desert_bush_3d()
	model.position = pos - Vector3(0.0, 0.10 * s, 0.0)
	model.rotation.y = rot_y
	model.scale = Vector3(s, s, s)
	parent.add_child(model)

func _create_cairn(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var cairn_body := StaticBody3D.new()
	cairn_body.position = pos - Vector3(0.0, 0.14 * s, 0.0)
	cairn_body.rotation.y = rot_y

	var model := DesertScenery3D.create_stone_cairn_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 1.4 * s
	cyl.radius = 0.55 * s
	col.shape = cyl
	col.position.y = 0.7 * s

	cairn_body.add_child(model)
	cairn_body.add_child(col)
	parent.add_child(cairn_body)

func _create_telegraph_pole(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var pole_body := StaticBody3D.new()
	pole_body.position = pos - Vector3(0.0, 0.40 * s, 0.0)
	pole_body.rotation.y = rot_y

	var model := DesertScenery3D.create_telegraph_pole_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 6.4 * s
	cyl.radius = 0.22 * s
	col.shape = cyl
	col.position.y = 3.2 * s

	pole_body.add_child(model)
	pole_body.add_child(col)
	parent.add_child(pole_body)

func _create_road_sign(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var sign_body := StaticBody3D.new()
	sign_body.position = pos - Vector3(0.0, 0.25 * s, 0.0)
	sign_body.rotation.y = rot_y

	var model := DesertScenery3D.create_road_sign_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 2.4 * s
	cyl.radius = 0.12 * s
	col.shape = cyl
	col.position.y = 1.2 * s

	sign_body.add_child(model)
	sign_body.add_child(col)
	parent.add_child(sign_body)

func _create_oil_drums(parent: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var drums_body := StaticBody3D.new()
	drums_body.position = pos - Vector3(0.0, 0.12 * s, 0.0)
	drums_body.rotation.y = rot_y

	var model := DesertScenery3D.create_oil_drums_cluster_3d()
	model.scale = Vector3(s, s, s)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6 * s, 1.0 * s, 1.4 * s)
	col.shape = box
	col.position.y = 0.5 * s

	drums_body.add_child(model)
	drums_body.add_child(col)
	parent.add_child(drums_body)
