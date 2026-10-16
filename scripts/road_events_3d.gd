extends Node

class_name RoadEvents3D

# Фабрика дорожных событий: баррикады с взрывоопасными бочками, заброшенные заправки и оазисы

# --- Материалы ---
static var mat_barrel_red   : StandardMaterial3D
static var mat_barrel_stripe: StandardMaterial3D
static var mat_concrete     : StandardMaterial3D
static var mat_beam_wood    : StandardMaterial3D
static var mat_metal_rusty  : StandardMaterial3D
static var mat_crate_supply : StandardMaterial3D
static var mat_water_oasis  : StandardMaterial3D
static var mat_palm_trunk   : StandardMaterial3D
static var mat_palm_frond   : StandardMaterial3D

# Новые материалы для развалин и построек
static var mat_sandstone    : StandardMaterial3D
static var mat_sandstone_dark: StandardMaterial3D
static var mat_bunker_wall  : StandardMaterial3D
static var mat_military_green: StandardMaterial3D
static var mat_plane_metal  : StandardMaterial3D
static var mat_burnt_metal  : StandardMaterial3D
static var mat_adobe_clay   : StandardMaterial3D
static var mat_clay_dark    : StandardMaterial3D
static var mat_sandbag      : StandardMaterial3D
static var mat_glass_broken : StandardMaterial3D
static var mat_carpet       : StandardMaterial3D
static var mat_neon_sign    : StandardMaterial3D
static var mat_emergency_red: StandardMaterial3D
static var mat_steel_beam   : StandardMaterial3D

static func _ensure_materials() -> void:
	if mat_barrel_red != null:
		return

	mat_barrel_red = StandardMaterial3D.new()
	mat_barrel_red.albedo_color = Color(0.85, 0.14, 0.10)
	mat_barrel_red.metallic = 0.4
	mat_barrel_red.roughness = 0.5

	mat_barrel_stripe = StandardMaterial3D.new()
	mat_barrel_stripe.albedo_color = Color(0.96, 0.78, 0.12)
	mat_barrel_stripe.roughness = 0.4

	mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.56, 0.54, 0.50)
	mat_concrete.roughness = 0.95

	mat_beam_wood = StandardMaterial3D.new()
	mat_beam_wood.albedo_color = Color(0.35, 0.22, 0.12)
	mat_beam_wood.roughness = 0.9

	mat_metal_rusty = StandardMaterial3D.new()
	mat_metal_rusty.albedo_color = Color(0.44, 0.26, 0.18)
	mat_metal_rusty.metallic = 0.55
	mat_metal_rusty.roughness = 0.75

	mat_crate_supply = StandardMaterial3D.new()
	mat_crate_supply.albedo_color = Color(0.28, 0.38, 0.22)
	mat_crate_supply.metallic = 0.3
	mat_crate_supply.roughness = 0.55

	mat_water_oasis = StandardMaterial3D.new()
	mat_water_oasis.albedo_color = Color(0.10, 0.52, 0.62, 0.85)
	mat_water_oasis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water_oasis.roughness = 0.08
	mat_water_oasis.metallic = 0.1

	mat_palm_trunk = StandardMaterial3D.new()
	mat_palm_trunk.albedo_color = Color(0.38, 0.28, 0.18)
	mat_palm_trunk.roughness = 0.9

	mat_palm_frond = StandardMaterial3D.new()
	mat_palm_frond.albedo_color = Color(0.18, 0.52, 0.15)
	mat_palm_frond.roughness = 0.65

	# Песчаник для древних руин
	mat_sandstone = StandardMaterial3D.new()
	mat_sandstone.albedo_color = Color(0.78, 0.66, 0.48)
	mat_sandstone.roughness = 0.92

	mat_sandstone_dark = StandardMaterial3D.new()
	mat_sandstone_dark.albedo_color = Color(0.60, 0.50, 0.35)
	mat_sandstone_dark.roughness = 0.95

	# Броня и бетон военного бункера
	mat_bunker_wall = StandardMaterial3D.new()
	mat_bunker_wall.albedo_color = Color(0.38, 0.39, 0.37)
	mat_bunker_wall.roughness = 0.88

	mat_military_green = StandardMaterial3D.new()
	mat_military_green.albedo_color = Color(0.24, 0.30, 0.18)
	mat_military_green.metallic = 0.35
	mat_military_green.roughness = 0.70

	mat_sandbag = StandardMaterial3D.new()
	mat_sandbag.albedo_color = Color(0.62, 0.54, 0.38)
	mat_sandbag.roughness = 0.96

	# Металл разбитого самолета
	mat_plane_metal = StandardMaterial3D.new()
	mat_plane_metal.albedo_color = Color(0.72, 0.74, 0.76)
	mat_plane_metal.metallic = 0.75
	mat_plane_metal.roughness = 0.40

	mat_burnt_metal = StandardMaterial3D.new()
	mat_burnt_metal.albedo_color = Color(0.18, 0.16, 0.15)
	mat_burnt_metal.roughness = 0.92

	# Саманный глиняный кирпич для развалин пустынных хижин
	mat_adobe_clay = StandardMaterial3D.new()
	mat_adobe_clay.albedo_color = Color(0.68, 0.48, 0.32)
	mat_adobe_clay.roughness = 0.95

	mat_clay_dark = StandardMaterial3D.new()
	mat_clay_dark.albedo_color = Color(0.50, 0.34, 0.22)
	mat_clay_dark.roughness = 0.95

	# Осколки стекла витрин
	mat_glass_broken = StandardMaterial3D.new()
	mat_glass_broken.albedo_color = Color(0.65, 0.82, 0.88, 0.45)
	mat_glass_broken.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass_broken.roughness = 0.15

	# Ткань шатра и ковры
	mat_carpet = StandardMaterial3D.new()
	mat_carpet.albedo_color = Color(0.68, 0.22, 0.16)
	mat_carpet.roughness = 0.95

	# Светящийся неон вывесок и светодиодов
	mat_neon_sign = StandardMaterial3D.new()
	mat_neon_sign.albedo_color = Color(1.0, 0.80, 0.25)
	mat_neon_sign.emission_enabled = true
	mat_neon_sign.emission = Color(1.0, 0.75, 0.20)
	mat_neon_sign.emission_energy_multiplier = 2.5

	# Аварийный красный маяк
	mat_emergency_red = StandardMaterial3D.new()
	mat_emergency_red.albedo_color = Color(0.95, 0.15, 0.10)
	mat_emergency_red.emission_enabled = true
	mat_emergency_red.emission = Color(0.95, 0.15, 0.10)
	mat_emergency_red.emission_energy_multiplier = 3.0

	# Темные конструкционные балки и стеллажи
	mat_steel_beam = StandardMaterial3D.new()
	mat_steel_beam.albedo_color = Color(0.22, 0.24, 0.26)
	mat_steel_beam.metallic = 0.70
	mat_steel_beam.roughness = 0.45

# =========================================================================
# 1. ДОРОЖНАЯ БАРРИКАДА С БОЧКАМИ (ROAD BARRICADE)
# =========================================================================
static func create_road_barricade() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "RoadBarricade"
	root.add_to_group("road_obstacle")
	root.add_to_group("interactive")

	# Параметры интерактивности
	root.set_meta("prompt_text", "РАЗОБРАТЬ ЗАВАЛ (Удерживайте [E])")
	root.set_meta("requires_hold", true)
	root.set_meta("hold_duration", 2.2)
	root.set_meta("health", 45) # Можно также взорвать/расстрелять

	# Скрипт-обработчик взаимодействия и взрыва
	var script_code := """
extends Node3D

var health: int = 45
var is_cleared: bool = false
var snd_explosion: AudioStream = preload("res://assets/audio/explosion.wav")

func on_interact_completed(player: Node) -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, false)
	else:
		clear_local(false)

func hitscan_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func projectile_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func take_damage(amt: int) -> void:
	if is_cleared:
		return
	health -= amt
	if health <= 0:
		detonate()

func detonate() -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, true)
	else:
		clear_local(true)

func clear_local(is_detonation: bool) -> void:
	if is_cleared:
		return
	is_cleared = true

	if is_detonation:
		# Звук мощного взрыва
		var ap := AudioStreamPlayer3D.new()
		ap.stream = snd_explosion
		ap.pitch_scale = randf_range(0.9, 1.1)
		ap.max_distance = 60.0
		get_parent().add_child(ap)
		ap.global_position = global_position
		ap.play()
		ap.finished.connect(ap.queue_free)

		# Сноп огня и искр
		_spawn_explosion_fx()

		# Урон всем врагам вокруг от взрыва бочек (радиус 7.5м, урон 130)
		var enemies := get_tree().get_nodes_in_group("Enemies")
		for e in enemies:
			if is_instance_valid(e) and e is CharacterBody3D:
				var dist: float = global_position.distance_to(e.global_position)
				if dist <= 7.5:
					var falloff: float = 1.0 - (dist / 7.5)
					var dmg: int = int(130.0 * falloff)
					if e.has_method("take_damage"):
						e.take_damage(dmg, (e.global_position - global_position).normalized(), global_position)

		# Уведомление игрокам
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("БОЧКИ ВЗОРВАНЫ! ДОРОГА РАСЧИЩЕНА", Color(1.0, 0.6, 0.2))
	else:
		_spawn_debris_particles()
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("ЗАВАЛ РАЗОБРАН! ПУТЬ СВОБОДЕН", Color(0.3, 1.0, 0.4))

	queue_free()

func _spawn_explosion_fx() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 45
	p.lifetime = 1.2
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.material = mat
	p.mesh = sphere

	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _spawn_debris_particles() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 25
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.25)
	box.material = mat
	p.mesh = box

	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.8, 0.0)
	p.emitting = true
	p.finished.connect(p.queue_free)
"""
	var custom_script := GDScript.new()
	custom_script.source_code = script_code
	custom_script.reload()
	root.set_script(custom_script)

	# --- 3D геометрия баррикады ---
	# 1. Бетонный блок перекрытия
	var col_body := StaticBody3D.new()
	col_body.name = "BarricadeCollision"
	col_body.add_to_group("Enemies") # Чтобы принимать попадания пуль
	root.add_child(col_body)

	_add_box(col_body, Vector3(6.5, 0.9, 0.8), mat_concrete, Vector3(0.0, 0.45, 0.0))
	_add_box(col_body, Vector3(6.2, 0.15, 0.15), mat_barrel_stripe, Vector3(0.0, 0.85, 0.35)) # Предупреждающая полоса

	# Коллизия преграды поперек дороги
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(6.5, 1.4, 1.2)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.7, 0.0)
	col_body.add_child(col_shape)

	# 2. Деревянные крестовины и брусья
	_add_box(root, Vector3(0.2, 1.8, 0.2), mat_beam_wood, Vector3(-2.2, 0.8, 0.2), Vector3(0.0, 0.0, deg_to_rad(30.0)))
	_add_box(root, Vector3(0.2, 1.8, 0.2), mat_beam_wood, Vector3(-2.2, 0.8, 0.2), Vector3(0.0, 0.0, deg_to_rad(-30.0)))
	_add_box(root, Vector3(0.2, 1.8, 0.2), mat_beam_wood, Vector3(2.2, 0.8, 0.2), Vector3(0.0, 0.0, deg_to_rad(30.0)))
	_add_box(root, Vector3(0.2, 1.8, 0.2), mat_beam_wood, Vector3(2.2, 0.8, 0.2), Vector3(0.0, 0.0, deg_to_rad(-30.0)))

	# 3. Красные взрывоопасные бочки
	var b1 := _add_cyl(root, 0.95, 0.32, 0.32, mat_barrel_red, Vector3(-1.1, 0.48, -0.45))
	_add_cyl(b1, 0.15, 0.33, 0.33, mat_barrel_stripe, Vector3(0.0, 0.12, 0.0))

	var b2 := _add_cyl(root, 0.95, 0.32, 0.32, mat_barrel_red, Vector3(1.2, 0.48, -0.45))
	_add_cyl(b2, 0.15, 0.33, 0.33, mat_barrel_stripe, Vector3(0.0, 0.12, 0.0))

	var b3 := _add_cyl(root, 0.95, 0.32, 0.32, mat_barrel_red, Vector3(0.1, 0.48, -0.55), Vector3(deg_to_rad(12.0), 0.0, 0.0))
	_add_cyl(b3, 0.15, 0.33, 0.33, mat_barrel_stripe, Vector3(0.0, 0.12, 0.0))

	# Желтый сигнальный маячок
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.75, 0.15)
	beacon.light_energy = 2.0
	beacon.omni_range = 8.0
	beacon.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(beacon)

	return root

# =========================================================================
# 2. ЗАБРОШЕННАЯ ЗАПРАВКА С ПРИПАСАМИ (ABANDONED GAS STATION)
# =========================================================================
static func create_gas_station() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "AbandonedGasStation"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Бетонное возвышение островка заправки
	_add_collidable_box(body, root, Vector3(9.5, 0.35, 14.0), mat_concrete, Vector3(0.0, 0.18, 0.0))
	# Желто-черный предупреждающий бордюр по краям
	_add_box(root, Vector3(9.6, 0.36, 0.25), mat_barrel_stripe, Vector3(0.0, 0.18, 7.0))
	_add_box(root, Vector3(9.6, 0.36, 0.25), mat_barrel_stripe, Vector3(0.0, 0.18, -7.0))

	# 2. 4 массивные стальные опорные колонны навеса (каждая с жесткой коллизией)
	var pillar_coords := [
		Vector3(-3.5, 2.3, -5.2),
		Vector3(3.5, 2.3, -5.2),
		Vector3(-3.5, 2.3, 5.2),
		Vector3(3.5, 2.3, 5.2)
	]
	for p in pillar_coords:
		_add_collidable_box(body, root, Vector3(0.5, 4.4, 0.5), mat_metal_rusty, p)
		_add_box(root, Vector3(0.8, 0.3, 0.8), mat_steel_beam, Vector3(p.x, 0.35, p.z))

	# 3. Навес из ржавого профилированного металла с фермами
	_add_collidable_box(body, root, Vector3(10.2, 0.45, 15.0), mat_metal_rusty, Vector3(0.0, 4.6, 0.0), Vector3(deg_to_rad(-2.0), 0.0, deg_to_rad(1.0)))
	_add_box(root, Vector3(9.8, 0.25, 0.3), mat_steel_beam, Vector3(0.0, 4.25, 0.0))
	_add_box(root, Vector3(9.8, 0.25, 0.3), mat_steel_beam, Vector3(0.0, 4.25, 4.8))
	_add_box(root, Vector3(9.8, 0.25, 0.3), mat_steel_beam, Vector3(0.0, 4.25, -4.8))

	# 4. Вывеска заправки с мерцающим неоновым светом
	_add_box(root, Vector3(4.8, 1.1, 0.25), mat_neon_sign, Vector3(0.0, 5.4, 7.5))
	var sign_light := OmniLight3D.new()
	sign_light.light_color = Color(1.0, 0.72, 0.2)
	sign_light.light_energy = 2.4
	sign_light.omni_range = 10.0
	sign_light.position = Vector3(0.0, 5.4, 7.8)
	root.add_child(sign_light)

	# 5. Две винтажные бензоколонки с жесткой коллизией, шлангами и экранами
	var p1_pos := Vector3(-1.6, 1.25, 0.0)
	var p2_pos := Vector3(1.6, 1.25, 0.0)
	for p_pos in [p1_pos, p2_pos]:
		_add_collidable_box(body, root, Vector3(1.0, 1.9, 0.8), mat_barrel_red, p_pos)
		_add_box(root, Vector3(0.8, 0.45, 0.84), mat_concrete, p_pos + Vector3(0.0, 0.4, 0.0))
		_add_cyl(root, 0.3, 0.25, 0.25, mat_barrel_stripe, p_pos + Vector3(0.0, 1.1, 0.0))
		_add_cyl(root, 1.4, 0.04, 0.04, mat_steel_beam, p_pos + Vector3(0.48, -0.1, 0.0), Vector3(0.0, 0.0, deg_to_rad(12.0)))
		_add_cyl(root, 0.02, 0.65, 0.65, mat_burnt_metal, Vector3(p_pos.x, 0.36, p_pos.z + 0.3))

	# 6. ЗДАНИЕ ОПЕРАТОРСКОЙ / МАГАЗИН ПРИ ДОРОГЕ (Cashier / Convenience Kiosk)
	# Стены полностью осязаемы и не проходимы!
	var k_center := Vector3(8.5, 0.0, 0.0)
	_add_collidable_box(body, root, Vector3(6.2, 0.35, 9.2), mat_concrete, k_center + Vector3(0.0, 0.18, 0.0))
	_add_collidable_box(body, root, Vector3(6.2, 3.4, 0.5), mat_concrete, k_center + Vector3(0.0, 1.7, -4.35))
	_add_collidable_box(body, root, Vector3(6.2, 3.4, 0.5), mat_concrete, k_center + Vector3(0.0, 1.7, 4.35))
	_add_collidable_box(body, root, Vector3(0.5, 3.4, 9.2), mat_concrete, k_center + Vector3(3.0, 1.7, 0.0))
	# Фасадная стена с дверным проемом:
	_add_collidable_box(body, root, Vector3(0.5, 3.4, 3.2), mat_concrete, k_center + Vector3(-3.0, 1.7, -2.8))
	_add_collidable_box(body, root, Vector3(0.5, 3.4, 3.2), mat_concrete, k_center + Vector3(-3.0, 1.7, 2.8))
	_add_collidable_box(body, root, Vector3(0.5, 1.0, 2.8), mat_concrete, k_center + Vector3(-3.0, 2.9, 0.0))
	_add_collidable_box(body, root, Vector3(6.6, 0.4, 9.6), mat_metal_rusty, k_center + Vector3(0.0, 3.5, 0.0))

	# Осколки стекол на витринах магазина
	_add_box(root, Vector3(0.08, 1.6, 2.0), mat_glass_broken, k_center + Vector3(-3.0, 1.6, 2.6))
	_add_box(root, Vector3(0.08, 1.6, 2.0), mat_glass_broken, k_center + Vector3(-3.0, 1.6, -2.6))

	# Внутри магазина: кассовый прилавок и стеллажи
	_add_collidable_box(body, root, Vector3(2.6, 1.0, 0.8), mat_beam_wood, k_center + Vector3(0.5, 0.5, -1.8))
	_add_collidable_box(body, root, Vector3(0.6, 2.4, 3.4), mat_steel_beam, k_center + Vector3(2.4, 1.2, 1.2))

	# Мусорный контейнер и бочки снаружи
	_add_collidable_box(body, root, Vector3(1.2, 1.3, 1.8), mat_military_green, k_center + Vector3(-1.8, 0.65, 5.5))
	_add_collidable_cyl(body, root, 0.95, 0.32, 0.32, mat_barrel_red, k_center + Vector3(0.5, 0.48, 5.5))

	# Ящик с припасами (Loot Crate) внутри магазина за кассой
	var crate := _create_loot_crate("ЗАБРАТЬ ПРИПАСЫ И ТОПЛИВО [E]", true)
	crate.position = k_center + Vector3(0.5, 0.35, -2.8)
	root.add_child(crate)

	return root

# =========================================================================
# 3. ПУСТЫННЫЙ ОАЗИС (DESERT OASIS)
# =========================================================================
static func create_oasis() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "DesertOasis"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Бирюзовое зеркало воды оазиса
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.8
	disc.bottom_radius = 6.8
	disc.height = 0.12
	disc.material = mat_water_oasis
	water.mesh = disc
	water.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(water)

	_add_cyl(root, 0.22, 7.4, 7.8, mat_sandstone, Vector3(0.0, 0.10, 0.0))

	# Камни по кромке водоема (твердые препятствия с коллизией)
	for i in range(10):
		var stone_ang: float = float(i) * (TAU / 10.0) + 0.15
		var sx: float = cos(stone_ang) * 7.1
		var sz: float = sin(stone_ang) * 7.1
		var s_rad: float = randf_range(0.35, 0.65)
		_add_collidable_box(body, root, Vector3(s_rad * 1.8, s_rad * 1.1, s_rad * 1.5), mat_sandstone_dark, Vector3(sx, s_rad * 0.45, sz), Vector3(deg_to_rad(randf_range(-12.0, 12.0)), randf_range(0.0, TAU), 0.0))

	# 2. 4 пальмы вокруг водоема с непроходимыми стволами
	var palm_positions := [
		Vector3(-5.8, 0.0, -3.8),
		Vector3(5.2, 0.0, -4.6),
		Vector3(3.2, 0.0, 5.8),
		Vector3(-4.8, 0.0, 4.6)
	]
	for pp in palm_positions:
		_create_palm_tree(root, pp)

	# 3. Бедуинский шатер кочевников (Nomad Tent Camp)
	var tent_center := Vector3(-2.2, 0.0, 5.2)
	var pole_offsets := [
		Vector3(-2.0, 0.0, -1.8),
		Vector3(2.0, 0.0, -1.8),
		Vector3(-2.0, 0.0, 1.8),
		Vector3(2.0, 0.0, 1.8)
	]
	for po in pole_offsets:
		_add_collidable_cyl(body, root, 2.5, 0.07, 0.07, mat_beam_wood, tent_center + po + Vector3(0.0, 1.25, 0.0))

	_add_box(root, Vector3(4.4, 0.06, 4.0), mat_carpet, tent_center + Vector3(0.0, 2.55, 0.0), Vector3(deg_to_rad(4.0), 0.0, deg_to_rad(-3.0)))
	_add_box(root, Vector3(3.4, 0.04, 3.2), mat_carpet, tent_center + Vector3(0.0, 0.02, 0.0))

	# Кострище с углями и каменным кольцом
	var fire_pos := tent_center + Vector3(2.8, 0.0, 0.8)
	for i in range(7):
		var fa: float = float(i) * (TAU / 7.0)
		_add_collidable_box(body, root, Vector3(0.4, 0.25, 0.35), mat_sandstone_dark, fire_pos + Vector3(cos(fa) * 0.8, 0.12, sin(fa) * 0.8))
	_add_cyl(root, 0.8, 0.08, 0.08, mat_burnt_metal, fire_pos + Vector3(0.0, 0.12, 0.0), Vector3(0.0, deg_to_rad(35.0), PI * 0.5))
	_add_cyl(root, 0.8, 0.08, 0.08, mat_burnt_metal, fire_pos + Vector3(0.0, 0.14, 0.0), Vector3(0.0, deg_to_rad(-45.0), PI * 0.5))
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.12)
	fire_light.light_energy = 2.8
	fire_light.omni_range = 8.5
	fire_light.position = fire_pos + Vector3(0.0, 0.6, 0.0)
	root.add_child(fire_light)

	# Глиняные сосуды
	_add_collidable_cyl(body, root, 0.95, 0.26, 0.16, mat_clay_dark, tent_center + Vector3(-1.4, 0.48, 1.2))
	_add_collidable_cyl(body, root, 0.75, 0.22, 0.14, mat_clay_dark, tent_center + Vector3(-1.8, 0.38, 0.8))

	# Сундук оазиса внутри шатра
	var chest := _create_loot_crate("ОТКРЫТЬ СУНДУК ОАЗИСА [E]", false)
	chest.position = tent_center + Vector3(0.0, 0.15, 0.0)
	root.add_child(chest)

	return root

# =========================================================================
# ВСПОМОГАТЕЛЬНЫЕ ЭЛЕМЕНТЫ: ПАЛЬМА И СУНДУК С ПРИПАСАМИ
# =========================================================================
static func _create_palm_tree(parent: Node3D, pos: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = pos
	parent.add_child(palm)

	var trunk_h: float = randf_range(5.6, 7.2)
	var lean_ang: float = deg_to_rad(randf_range(6.0, 12.0))
	var rot_y: float = randf_range(0.0, TAU)
	_add_cyl(palm, trunk_h, 0.28, 0.52, mat_palm_trunk, Vector3(0.0, trunk_h * 0.5, 0.0), Vector3(lean_ang, rot_y, 0.0))

	# Кольца коры на стволе
	for i in range(4):
		var ring_y: float = 1.0 + float(i) * 1.2
		_add_cyl(palm, 0.12, 0.44 - float(i) * 0.03, 0.46 - float(i) * 0.03, mat_beam_wood, Vector3(0.0, ring_y, 0.0), Vector3(lean_ang, rot_y, 0.0))

	# Крона из 8 листьев наверху
	var crown_pos := Vector3(sin(rot_y) * sin(lean_ang) * (trunk_h * 0.5), trunk_h, cos(rot_y) * sin(lean_ang) * (trunk_h * 0.5))
	for i in range(8):
		var leaf_ang: float = float(i) * (TAU / 8.0)
		var lx: float = cos(leaf_ang) * 1.8
		var lz: float = sin(leaf_ang) * 1.8
		_add_box(palm, Vector3(0.48, 0.08, 3.8), mat_palm_frond, crown_pos + Vector3(lx, -0.4, lz), Vector3(deg_to_rad(28.0), leaf_ang, 0.0))

	# Гроздь кокосов
	for i in range(3):
		var coconut_ang: float = float(i) * (TAU / 3.0)
		_add_cyl(palm, 0.35, 0.18, 0.18, mat_sandstone_dark, crown_pos + Vector3(cos(coconut_ang) * 0.35, -0.45, sin(coconut_ang) * 0.35))

	# Твердая статическая коллизия ствола пальмы (невозможно пройти сквозь)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	palm.add_child(body)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 4.8
	cyl.radius = 0.60
	col.shape = cyl
	col.position = Vector3(0.0, 2.4, 0.0)
	body.add_child(col)

static func _create_loot_crate(prompt: String, is_gas_station: bool) -> Node3D:
	var crate_root := Node3D.new()
	crate_root.name = "LootCrate"
	crate_root.add_to_group("interactive")
	crate_root.add_to_group("loot_crate")
	crate_root.set_meta("prompt_text", prompt)
	crate_root.set_meta("requires_hold", false)

	# Скрипт подбора лута
	var script_text := """
extends Node3D

var is_looted: bool = false
var snd_pickup: AudioStream = preload("res://assets/audio/wave_win.wav")

func on_interact(player: Node) -> void:
	if is_looted:
		return
	var crate_id: String = str(get_meta("crate_id", ""))
	var p_id: int = 1
	if player and player.name.is_valid_int():
		p_id = player.name.to_int()
	elif multiplayer.has_multiplayer_peer():
		p_id = multiplayer.get_unique_id()

	if NetworkManager != null and NetworkManager.has_method("request_loot_crate") and not crate_id.is_empty():
		NetworkManager.request_loot_crate(crate_id, p_id)
	else:
		apply_loot_local(p_id)

func mark_already_looted() -> void:
	is_looted = true
	remove_from_group("interactive")
	var glow = get_node_or_null("CrateGlow")
	if glow:
		glow.light_energy = 0.3
	var lid = get_node_or_null("Lid")
	if lid:
		lid.rotation.x = deg_to_rad(-65.0)

func apply_loot_local(looter_peer_id: int) -> void:
	if is_looted:
		return
	mark_already_looted()

	# Звук подбора припасов для всех
	var ap := AudioStreamPlayer.new()
	ap.stream = snd_pickup
	ap.volume_db = -4.0
	get_tree().root.add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)

	# Ремонт каравана (+150 HP) на сервере или локально
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var caravan = get_tree().get_first_node_in_group("caravan")
		if caravan and is_instance_valid(caravan) and not caravan.get("is_destroyed"):
			var cur_hp: int = int(caravan.get("health"))
			var max_hp: int = int(caravan.get("MAX_HEALTH"))
			caravan.health = mini(max_hp, cur_hp + 150)
			if caravan.has_signal("health_changed"):
				caravan.health_changed.emit(caravan.health, max_hp)
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				caravan.sync_caravan_state.rpc(caravan.global_position, caravan.health, caravan.is_blocked, caravan.is_destroyed, caravan.walk_phase)

	# Пополнение здоровья и патронов игроку, открывшему ящик, и уведомление остальным
	var my_id: int = 1
	if multiplayer.has_multiplayer_peer():
		my_id = multiplayer.get_unique_id()

	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			var pid: int = p.name.to_int() if p.name.is_valid_int() else 1
			if pid == looter_peer_id:
				p.health = 100
				if p.has_signal("health_changed"):
					p.health_changed.emit(100)
				var wm = p.get_node_or_null("WeaponManager")
				if wm and wm.get("ammo_manager"):
					var am = wm.ammo_manager
					if am.get("ammo_dict") and am.get("max_nb_per_ammo_dict"):
						for a_type in am.max_nb_per_ammo_dict:
							am.ammo_dict[a_type] = am.max_nb_per_ammo_dict[a_type]
				if p.has_method("notify_hud"):
					p.notify_hud("+150 ХП КАРАВАНА · БОЕЗАПАС ПОПОЛНЕН!", Color(0.25, 1.0, 0.45))
			elif pid == my_id:
				if p.has_method("notify_hud"):
					p.notify_hud("НАПАРНИК НАШЕЛ ПРИПАСЫ! КАРАВАН ОТРЕМОНТИРОВАН", Color(0.3, 0.85, 1.0))
"""
	var c_script := GDScript.new()
	c_script.source_code = script_text
	c_script.reload()
	crate_root.set_script(c_script)

	# Модель ящика
	var box_col := Color(0.28, 0.42, 0.22) if is_gas_station else Color(0.55, 0.38, 0.20)
	var mat_c := StandardMaterial3D.new()
	mat_c.albedo_color = box_col
	mat_c.roughness = 0.7

	_add_box(crate_root, Vector3(1.1, 0.55, 0.75), mat_c, Vector3(0.0, 0.28, 0.0))
	var lid := _add_box(crate_root, Vector3(1.14, 0.12, 0.78), mat_metal_rusty, Vector3(0.0, 0.58, 0.0))
	lid.name = "Lid"

	# Зеленый маячок лута
	var light := OmniLight3D.new()
	light.name = "CrateGlow"
	light.light_color = Color(0.3, 1.0, 0.4) if is_gas_station else Color(1.0, 0.85, 0.3)
	light.light_energy = 2.4
	light.omni_range = 6.0
	light.position = Vector3(0.0, 0.75, 0.0)
	crate_root.add_child(light)

	return crate_root

# =========================================================================
# 4. АВТОЗАВАЛ ИЗ РАЗБИТЫХ МАШИН (WRECK BLOCKADE)
# =========================================================================
static func create_wreck_blockade() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "WreckBlockade"
	root.add_to_group("road_obstacle")
	root.add_to_group("interactive")

	root.set_meta("prompt_text", "РАЗОБРАТЬ АВТОЗАВАЛ (Удерживайте [E])")
	root.set_meta("requires_hold", true)
	root.set_meta("hold_duration", 2.4)
	root.set_meta("health", 65)

	var script_code := """
extends Node3D

var health: int = 65
var is_cleared: bool = false
var snd_explosion: AudioStream = preload("res://assets/audio/explosion.wav")

func on_interact_completed(player: Node) -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, false)
	else:
		clear_local(false)

func hitscan_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func projectile_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func take_damage(amt: int) -> void:
	if is_cleared:
		return
	health -= amt
	if health <= 0:
		detonate()

func detonate() -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, true)
	else:
		clear_local(true)

func clear_local(is_detonation: bool) -> void:
	if is_cleared:
		return
	is_cleared = true

	if is_detonation:
		var ap := AudioStreamPlayer3D.new()
		ap.stream = snd_explosion
		ap.pitch_scale = randf_range(0.85, 1.05)
		ap.max_distance = 65.0
		get_parent().add_child(ap)
		ap.global_position = global_position
		ap.play()
		ap.finished.connect(ap.queue_free)

		_spawn_explosion_fx()

		var enemies := get_tree().get_nodes_in_group("Enemies")
		for e in enemies:
			if is_instance_valid(e) and e is CharacterBody3D:
				var dist: float = global_position.distance_to(e.global_position)
				if dist <= 8.0:
					var dmg: int = int(140.0 * (1.0 - dist / 8.0))
					if e.has_method("take_damage"):
						e.take_damage(dmg, (e.global_position - global_position).normalized(), global_position)

		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("МАШИНЫ ВЗОРВАНЫ! ПРОЕЗД ОТКРЫТ", Color(1.0, 0.6, 0.2))
	else:
		_spawn_debris_particles()
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("АВТОЗАВАЛ РАСЧИЩЕН! ПУТЬ СВОБОДЕН", Color(0.3, 1.0, 0.4))

	queue_free()

func _spawn_explosion_fx() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 50
	p.lifetime = 1.3
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.08)
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.material = mat
	p.mesh = sphere

	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _spawn_debris_particles() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 30
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0.0, -12.0, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.18)
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.18)
	box.material = mat
	p.mesh = box

	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	p.emitting = true
	p.finished.connect(p.queue_free)
"""
	var c_script := GDScript.new()
	c_script.source_code = script_code
	c_script.reload()
	root.set_script(c_script)

	# 1. Первая разбитая ржавая машина (развернута под углом поперек левой стороны)
	var car1 := Node3D.new()
	car1.position = Vector3(-1.4, 0.0, 0.0)
	car1.rotation = Vector3(deg_to_rad(6.0), deg_to_rad(35.0), deg_to_rad(-8.0))
	root.add_child(car1)
	_add_box(car1, Vector3(2.1, 0.75, 4.0), mat_metal_rusty, Vector3(0.0, 0.55, 0.0))
	_add_box(car1, Vector3(1.7, 0.65, 2.0), mat_metal_rusty, Vector3(0.0, 1.20, -0.2))
	# Колеса
	_add_cyl(car1, 0.28, 0.42, 0.42, mat_metal_rusty, Vector3(-1.1, 0.42, 1.2), Vector3(0.0, 0.0, PI * 0.5))
	_add_cyl(car1, 0.28, 0.42, 0.42, mat_metal_rusty, Vector3(1.1, 0.42, -1.2), Vector3(0.0, 0.0, PI * 0.5))

	# 2. Вторая перевернутая машина поперек правой стороны дороги
	var car2 := Node3D.new()
	car2.position = Vector3(1.5, 0.0, 0.4)
	car2.rotation = Vector3(deg_to_rad(12.0), deg_to_rad(-40.0), deg_to_rad(15.0))
	root.add_child(car2)
	_add_box(car2, Vector3(2.0, 0.7, 3.6), mat_metal_rusty, Vector3(0.0, 0.5, 0.0))
	_add_box(car2, Vector3(1.6, 0.6, 1.8), mat_metal_rusty, Vector3(0.0, 1.1, -0.1))

	# 3. Взрывоопасная бочка в эпицентре завала
	var barrel := _add_cyl(root, 0.95, 0.34, 0.34, mat_barrel_red, Vector3(0.0, 0.48, -0.1))
	_add_cyl(barrel, 0.12, 0.35, 0.35, mat_barrel_stripe, Vector3(0.0, 0.18, 0.0))
	_add_cyl(barrel, 0.12, 0.35, 0.35, mat_barrel_stripe, Vector3(0.0, -0.18, 0.0))

	# 4. Статичная коллизия перекрытия
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 2.0, 2.4)
	col.shape = shape
	col.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(col)
	root.add_child(body)

	return root

# =========================================================================
# 5. КАМЕННЫЙ ОБВАЛ (ROCKFALL BLOCKADE)
# =========================================================================
static func create_rockfall_blockade() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "RockfallBlockade"
	root.add_to_group("road_obstacle")
	root.add_to_group("interactive")

	root.set_meta("prompt_text", "РАЗОБРАТЬ КАМЕННЫЙ ЗАВАЛ (Удерживайте [E])")
	root.set_meta("requires_hold", true)
	root.set_meta("hold_duration", 2.2)
	root.set_meta("health", 50)

	var script_code := """
extends Node3D

var health: int = 50
var is_cleared: bool = false
var snd_explosion: AudioStream = preload("res://assets/audio/explosion.wav")

func on_interact_completed(player: Node) -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, false)
	else:
		clear_local(false)

func hitscan_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func projectile_hit(damage: float, _hit_dir: Vector3 = Vector3.ZERO, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage))

func take_damage(amt: int) -> void:
	if is_cleared:
		return
	health -= amt
	if health <= 0:
		detonate()

func detonate() -> void:
	if is_cleared:
		return
	var obst_id: String = str(get_meta("obstacle_id", ""))
	if NetworkManager != null and NetworkManager.has_method("request_clear_obstacle") and not obst_id.is_empty():
		NetworkManager.request_clear_obstacle(obst_id, true)
	else:
		clear_local(true)

func clear_local(is_detonation: bool) -> void:
	if is_cleared:
		return
	is_cleared = true

	if is_detonation:
		var ap := AudioStreamPlayer3D.new()
		ap.stream = snd_explosion
		ap.pitch_scale = randf_range(0.75, 0.95)
		ap.max_distance = 60.0
		get_parent().add_child(ap)
		ap.global_position = global_position
		ap.play()
		ap.finished.connect(ap.queue_free)

		_spawn_debris_particles()

		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("СКАЛЫ РАЗБИТЫ! КАРАВАН ИДЕТ ДАЛЬШЕ", Color(1.0, 0.8, 0.3))
	else:
		_spawn_debris_particles()
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("notify_hud"):
				p.notify_hud("КАМНИ РАЗОБРАНЫ! ПУТЬ СВОБОДЕН", Color(0.3, 1.0, 0.4))

	queue_free()

func _spawn_debris_particles() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 35
	p.lifetime = 0.85
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0.0, -14.0, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.28)
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.24, 0.24)
	box.material = mat
	p.mesh = box

	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	p.emitting = true
	p.finished.connect(p.queue_free)
"""
	var c_script := GDScript.new()
	c_script.source_code = script_code
	c_script.reload()
	root.set_script(c_script)

	# Скальные глыбы поперек дороги
	_add_box(root, Vector3(2.6, 1.5, 2.0), mat_concrete, Vector3(-1.2, 0.75, 0.0), Vector3(deg_to_rad(12.0), deg_to_rad(25.0), deg_to_rad(-6.0)))
	_add_box(root, Vector3(2.4, 1.3, 1.8), mat_concrete, Vector3(1.3, 0.65, 0.2), Vector3(deg_to_rad(-8.0), deg_to_rad(-30.0), deg_to_rad(10.0)))
	_add_box(root, Vector3(1.6, 0.9, 1.4), mat_concrete, Vector3(0.1, 0.45, -0.4), Vector3(deg_to_rad(15.0), deg_to_rad(10.0), deg_to_rad(5.0)))
	# Сломанное бревно / столб
	_add_cyl(root, 3.8, 0.15, 0.15, mat_beam_wood, Vector3(0.0, 0.85, 0.0), Vector3(deg_to_rad(12.0), deg_to_rad(75.0), deg_to_rad(78.0)))

	# Статичная коллизия
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 1.8, 2.2)
	col.shape = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(col)
	root.add_child(body)

	return root

# =========================================================================
# 6. ДРЕВНИЕ КАМЕННЫЕ РУИНЫ ХРАМА (ANCIENT TEMPLE RUINS)
# =========================================================================
static func create_ancient_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "AncientTempleRuins"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Платформа-стилобат и ступени святилища
	_add_collidable_box(body, root, Vector3(14.0, 0.5, 14.0), mat_sandstone, Vector3(0.0, 0.25, 0.0))
	_add_collidable_box(body, root, Vector3(8.0, 0.25, 2.5), mat_sandstone_dark, Vector3(0.0, 0.12, 7.8))

	# 2. 4 массивные античные колонны (каждая колонна полностью твердая и осязаемая!)
	# Передняя левая колонна:
	_add_collidable_box(body, root, Vector3(1.5, 0.45, 1.5), mat_sandstone_dark, Vector3(-4.5, 0.45, 4.2))
	_add_collidable_cyl(body, root, 5.2, 0.44, 0.48, mat_sandstone, Vector3(-4.5, 3.2, 4.2))
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(-4.5, 5.9, 4.2))

	# Передняя правая колонна:
	_add_collidable_box(body, root, Vector3(1.5, 0.45, 1.5), mat_sandstone_dark, Vector3(4.5, 0.45, 4.2))
	_add_collidable_cyl(body, root, 5.2, 0.44, 0.48, mat_sandstone, Vector3(4.5, 3.2, 4.2))
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(4.5, 5.9, 4.2))

	# Архитрав и фронтон над передними колоннами
	_add_collidable_box(body, root, Vector3(10.6, 0.7, 1.5), mat_sandstone, Vector3(0.0, 6.35, 4.2))
	_add_box(root, Vector3(7.2, 0.6, 1.3), mat_sandstone_dark, Vector3(0.0, 7.0, 4.2))

	# Задняя левая накренившаяся колонна:
	var lean_c := Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-6.0))
	_add_collidable_box(body, root, Vector3(1.5, 0.45, 1.5), mat_sandstone_dark, Vector3(-4.5, 0.45, -4.2))
	_add_collidable_cyl(body, root, 5.0, 0.44, 0.48, mat_sandstone, Vector3(-4.2, 3.1, -3.9), lean_c)

	# Задняя правая разрушенная колонна (обрубок + упавшие барабаны в песке):
	_add_collidable_box(body, root, Vector3(1.5, 0.45, 1.5), mat_sandstone_dark, Vector3(4.5, 0.45, -4.2))
	_add_collidable_cyl(body, root, 2.2, 0.44, 0.48, mat_sandstone, Vector3(4.5, 1.6, -4.2))
	_add_collidable_cyl(body, root, 1.8, 0.44, 0.44, mat_sandstone, Vector3(3.2, 0.45, -2.8), Vector3(0.0, deg_to_rad(45.0), deg_to_rad(85.0)))
	_add_collidable_box(body, root, Vector3(1.4, 0.8, 1.1), mat_sandstone_dark, Vector3(4.8, 0.4, -1.6), Vector3(deg_to_rad(10.0), deg_to_rad(25.0), 0.0))

	# 3. Стены целлы святилища (каждая стена имеет жесткую физическую коллизию)
	# Задняя стена:
	_add_collidable_box(body, root, Vector3(11.2, 3.8, 1.0), mat_sandstone_dark, Vector3(0.0, 2.1, -5.2))
	# Левая боковая стена:
	_add_collidable_box(body, root, Vector3(1.0, 2.8, 6.8), mat_sandstone_dark, Vector3(-5.5, 1.6, -1.2))
	# Правая боковая стена:
	_add_collidable_box(body, root, Vector3(1.0, 2.2, 5.2), mat_sandstone_dark, Vector3(5.5, 1.3, -1.8))

	# 4. Центральный жертвенник и чаши с вечным огнем
	_add_collidable_box(body, root, Vector3(2.8, 0.8, 2.8), mat_sandstone_dark, Vector3(0.0, 0.65, 0.0))
	_add_collidable_box(body, root, Vector3(2.4, 0.3, 2.4), mat_sandstone, Vector3(0.0, 1.15, 0.0))

	# 2 факельные каменные чаши по бокам алтаря
	for sx in [-2.2, 2.2]:
		_add_collidable_cyl(body, root, 1.2, 0.3, 0.2, mat_sandstone_dark, Vector3(sx, 0.85, 0.0))
		var fl := OmniLight3D.new()
		fl.light_color = Color(1.0, 0.65, 0.15)
		fl.light_energy = 2.2
		fl.omni_range = 7.0
		fl.position = Vector3(sx, 1.6, 0.0)
		root.add_child(fl)

	# Древний сундук на алтаре
	var chest := _create_loot_crate("ОТКРЫТЬ ДРЕВНИЙ СУНДУК [E]", false)
	chest.position = Vector3(0.0, 1.32, 0.0)
	root.add_child(chest)

	return root

# =========================================================================
# 7. РАЗРУШЕННЫЙ ВОЕННЫЙ БУНКЕР (MILITARY BUNKER RUINS)
# =========================================================================
static func create_bunker_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "MilitaryBunkerRuins"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# ПОЛНОСТЬЮ ПОЛЫЙ ВНУТРИ БУНКЕР С ОТДЕЛЬНЫМИ СТЕНАМИ И КОЛЛИЗИЯМИ!
	# Задняя стена:
	_add_collidable_box(body, root, Vector3(11.8, 3.6, 1.2), mat_bunker_wall, Vector3(0.0, 1.8, -4.8))
	# Левая стена:
	_add_collidable_box(body, root, Vector3(1.2, 3.6, 10.0), mat_bunker_wall, Vector3(-5.3, 1.8, 0.2))
	# Правая стена:
	_add_collidable_box(body, root, Vector3(1.2, 3.6, 10.0), mat_bunker_wall, Vector3(5.3, 1.8, 0.2))
	# Передняя стена (левое крыло):
	_add_collidable_box(body, root, Vector3(4.2, 3.6, 1.2), mat_bunker_wall, Vector3(-3.8, 1.8, 5.2))
	# Передняя стена (правое крыло):
	_add_collidable_box(body, root, Vector3(4.2, 3.6, 1.2), mat_bunker_wall, Vector3(3.8, 1.8, 5.2))
	# Перемычка над дверным проемом бункера (ширина проема 3.4м):
	_add_collidable_box(body, root, Vector3(3.6, 0.9, 1.2), mat_bunker_wall, Vector3(0.0, 3.15, 5.2))
	# Бронированная крыша бункера:
	_add_collidable_box(body, root, Vector3(12.2, 0.6, 11.6), mat_bunker_wall, Vector3(0.0, 3.9, 0.2))

	# Выносной входной шлюз с волнорезами
	_add_collidable_box(body, root, Vector3(0.8, 3.0, 3.0), mat_bunker_wall, Vector3(-2.2, 1.5, 7.0))
	_add_collidable_box(body, root, Vector3(0.8, 3.0, 3.0), mat_bunker_wall, Vector3(2.2, 1.5, 7.0))

	# Сорванная взрывом гермодверь лежит на полу (визуальный декор без зацепа коллизии)
	_add_box(root, Vector3(2.6, 0.12, 3.0), mat_burnt_metal, Vector3(0.3, 0.04, 6.2), Vector3(deg_to_rad(4.0), deg_to_rad(-22.0), deg_to_rad(4.0)))
	# Полосатая маркировка на пороге
	_add_box(root, Vector3(4.4, 0.12, 0.3), mat_barrel_stripe, Vector3(0.0, 0.06, 8.2))

	# Мешки с песком у амбразур
	for i in range(4):
		_add_collidable_box(body, root, Vector3(1.1, 0.35, 0.55), mat_sandbag, Vector3(-3.6 + float(i) * 1.05, 0.2, 7.8), Vector3(0.0, deg_to_rad(randf_range(-6.0, 6.0)), 0.0))

	# Антенна радиосвязи на крыше
	_add_cyl(root, 3.2, 0.06, 0.08, mat_metal_rusty, Vector3(3.8, 5.4, -2.5))
	_add_cyl(root, 2.8, 0.05, 0.06, mat_metal_rusty, Vector3(4.8, 6.4, -2.5), Vector3(deg_to_rad(50.0), 0.0, deg_to_rad(26.0)))

	# ВНУТРИ БУНКЕРА:
	# Тактическая радиостанция / серверные стойки у стены
	_add_collidable_box(body, root, Vector3(3.2, 2.2, 0.9), mat_military_green, Vector3(-3.4, 1.1, -3.8))
	# Мигающие зеленые и желтые светодиоды на консоли
	_add_box(root, Vector3(2.8, 0.2, 0.92), mat_neon_sign, Vector3(-3.4, 1.4, -3.8))

	# Аварийный красный фонарь на потолке бункера
	_add_box(root, Vector3(0.3, 0.3, 0.3), mat_emergency_red, Vector3(0.0, 3.4, 0.0))
	var red_beacon := OmniLight3D.new()
	red_beacon.light_color = Color(1.0, 0.15, 0.1)
	red_beacon.light_energy = 3.2
	red_beacon.omni_range = 9.5
	red_beacon.position = Vector3(0.0, 3.2, 0.0)
	root.add_child(red_beacon)

	# Военный контейнер внутри бункера на деревянном поддоне
	_add_collidable_box(body, root, Vector3(1.8, 0.2, 1.8), mat_beam_wood, Vector3(0.0, 0.1, -1.0))
	var crate := _create_loot_crate("ОТКРЫТЬ ВОЕННЫЙ КОНТЕЙНЕР [E]", true)
	crate.position = Vector3(0.0, 0.35, -1.0)
	root.add_child(crate)

	return root

# =========================================================================
# 8. ОБЛОМКИ ГРУЗОВОГО САМОЛЕТА (CRASHED PLANE WRECK)
# =========================================================================
static func create_plane_wreck_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PlaneWreckRuins"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Полый разорванный фюзеляж самолета
	var fus_tilt := Vector3(deg_to_rad(10.0), deg_to_rad(-22.0), deg_to_rad(14.0))
	# Левый и правый борт кабины (игрок может зайти внутрь пролома!)
	_add_collidable_box(body, root, Vector3(0.4, 3.2, 9.0), mat_plane_metal, Vector3(-1.8, 1.6, 0.0), fus_tilt)
	_add_collidable_box(body, root, Vector3(0.4, 3.2, 9.0), mat_plane_metal, Vector3(1.8, 1.6, 0.0), fus_tilt)
	_add_collidable_box(body, root, Vector3(3.8, 0.4, 9.0), mat_burnt_metal, Vector3(0.0, 3.2, 0.0), fus_tilt)

	# Изогнутый носовой обтекатель
	_add_cyl(root, 2.5, 0.6, 1.8, mat_plane_metal, Vector3(-0.6, 1.2, 5.2), Vector3(PI * 0.5, deg_to_rad(15.0), 0.0))

	# 2. Огромное крыло самолета, торчащее вверх из песка (с жесткой коллизией)
	var wing_rot := Vector3(deg_to_rad(26.0), deg_to_rad(12.0), deg_to_rad(-26.0))
	_add_collidable_box(body, root, Vector3(12.0, 0.35, 2.6), mat_plane_metal, Vector3(-5.5, 3.2, 0.5), wing_rot)
	# Спасательная полосатая маркировка на закрылках
	_add_box(root, Vector3(2.4, 0.38, 0.6), mat_barrel_stripe, Vector3(-8.8, 4.8, -0.6), wing_rot)

	# 3. Оторванная реактивная турбина двигателя (полностью осязаемая)
	var turb_rot := Vector3(deg_to_rad(12.0), deg_to_rad(55.0), deg_to_rad(85.0))
	_add_collidable_cyl(body, root, 3.4, 0.88, 0.78, mat_burnt_metal, Vector3(4.8, 0.75, 2.6), turb_rot)
	# Лопатки ротора турбины
	_add_cyl(root, 0.3, 0.70, 0.70, mat_plane_metal, Vector3(4.8, 0.75, 2.6), turb_rot)

	# 4. Хвостовой стабилизатор, воткнутый в дюну
	_add_collidable_box(body, root, Vector3(0.3, 4.4, 2.4), mat_plane_metal, Vector3(3.8, 1.9, -4.5), Vector3(deg_to_rad(18.0), deg_to_rad(-32.0), deg_to_rad(12.0)))

	# 5. Разбросанные грузовые контейнеры и багаж
	_add_collidable_box(body, root, Vector3(1.2, 1.0, 1.4), mat_military_green, Vector3(2.5, 0.5, -1.8))
	_add_collidable_box(body, root, Vector3(1.0, 0.8, 1.1), mat_sandbag, Vector3(1.4, 0.4, 2.8))

	# Авиационный грузовой контейнер с ценным лутом
	var crate := _create_loot_crate("ОТКРЫТЬ АВИАЦИОННЫЙ ГРУЗ [E]", true)
	crate.position = Vector3(-0.4, 0.35, 2.6)
	crate.rotation.y = deg_to_rad(20.0)
	root.add_child(crate)

	return root

# =========================================================================
# 9. РАЗВАЛИНЫ ГЛИНЯНОГО КАРАВАН-САРАЯ (CLAY RUINS / ADOBE CARAVANSERAI)
# =========================================================================
static func create_clay_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "ClayCaravanseraiRuins"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Глиняный пол фундамента
	_add_collidable_box(body, root, Vector3(11.4, 0.3, 11.4), mat_adobe_clay, Vector3(0.0, 0.15, 0.0))

	# 2. Толстые саманные внешние стены (каждая стена полностью твердая!)
	# Задняя стена:
	_add_collidable_box(body, root, Vector3(11.4, 3.4, 0.9), mat_adobe_clay, Vector3(0.0, 1.7, -5.2))
	# Левая стена:
	_add_collidable_box(body, root, Vector3(0.9, 3.0, 10.2), mat_adobe_clay, Vector3(-5.2, 1.5, -0.1))
	# Правая стена:
	_add_collidable_box(body, root, Vector3(0.9, 2.6, 7.8), mat_adobe_clay, Vector3(5.2, 1.3, -1.3))

	# Передняя стена с арочным порталом (левый и правый сегменты + перемычка):
	_add_collidable_box(body, root, Vector3(4.2, 3.0, 0.9), mat_adobe_clay, Vector3(-3.6, 1.5, 4.8))
	_add_collidable_box(body, root, Vector3(4.2, 3.0, 0.9), mat_adobe_clay, Vector3(3.6, 1.5, 4.8))
	_add_collidable_box(body, root, Vector3(3.2, 0.9, 0.9), mat_clay_dark, Vector3(0.0, 3.0, 4.8))

	# Внутренняя перегородка с проходом в тайную комнату
	_add_collidable_box(body, root, Vector3(4.6, 2.6, 0.7), mat_adobe_clay, Vector3(-1.8, 1.3, 0.0))

	# Деревянные потолочные балки (vigas)
	for i in range(5):
		var bz: float = -4.2 + float(i) * 1.8
		_add_cyl(root, 2.4, 0.11, 0.11, mat_beam_wood, Vector3(-5.2, 3.0, bz), Vector3(0.0, 0.0, PI * 0.5))
		if i % 2 == 0:
			_add_cyl(root, 2.2, 0.11, 0.11, mat_beam_wood, Vector3(5.2, 2.4, bz), Vector3(0.0, 0.0, PI * 0.5))

	# Глиняный очаг/тандыр в углу
	_add_collidable_cyl(body, root, 0.8, 0.65, 0.85, mat_clay_dark, Vector3(3.8, 0.45, -3.8))
	# Большие глиняные амфоры с коллизией
	_add_collidable_cyl(body, root, 1.0, 0.32, 0.20, mat_clay_dark, Vector3(-3.8, 0.5, 3.6))
	_add_collidable_cyl(body, root, 0.85, 0.26, 0.18, mat_clay_dark, Vector3(-4.3, 0.42, 3.1))

	# Тайник контрабандиста во внутренней комнате
	var stash := _create_loot_crate("ОБЫСКАТЬ ТАЙНИК КОНТРАБАНДИСТА [E]", false)
	stash.position = Vector3(-3.2, 0.3, -2.8)
	root.add_child(stash)

	return root

# =========================================================================
# 10. ЗАСЫПАННЫЙ БУНКЕР ВЫЖИВШИХ (CRAWLSPACE FALLOUT SHELTER)
# Постройка с заваленным низким лазом: пролезть внутрь можно ТОЛЬКО ПРИСЕВ!
# =========================================================================
static func create_crawlspace_shelter_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "CrawlspaceShelterRuins"

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)

	# 1. Основание пола (заподлицо с поверхностью песка Y = 0.0 — никаких ступеней и порогов!)
	_add_collidable_box(body, root, Vector3(14.0, 0.4, 16.0), mat_sandstone, Vector3(0.0, -0.2, 0.0))

	# 2. ВНУТРЕННЯЯ ПОДЗЕМНАЯ КОМНАТА-СХРОН (Z от -1.0 до -6.5)
	# Внутри комнаты высота потолка 2.7м — здесь игрок может свободно встать во весь рост!
	# Задняя стена комнаты:
	_add_collidable_box(body, root, Vector3(8.8, 3.2, 1.0), mat_bunker_wall, Vector3(0.0, 1.6, -6.5))
	# Левая стена комнаты:
	_add_collidable_box(body, root, Vector3(1.0, 3.2, 6.0), mat_bunker_wall, Vector3(-4.4, 1.6, -3.5))
	# Правая стена комнаты:
	_add_collidable_box(body, root, Vector3(1.0, 3.2, 6.0), mat_bunker_wall, Vector3(4.4, 1.6, -3.5))
	# Потолок внутренней комнаты:
	_add_collidable_box(body, root, Vector3(8.8, 0.6, 6.0), mat_bunker_wall, Vector3(0.0, 2.9, -3.5))

	# Внутренняя передняя перегородка вокруг проема лаза:
	_add_collidable_box(body, root, Vector3(3.1, 3.2, 1.0), mat_bunker_wall, Vector3(-2.85, 1.6, -0.5))
	_add_collidable_box(body, root, Vector3(3.1, 3.2, 1.0), mat_bunker_wall, Vector3(2.85, 1.6, -0.5))

	# 3. ШИРОКИЙ НИЗКИЙ ТОННЕЛЬ-ЛАЗ (CRAWLWAY: Z от -0.5 до 4.2, ширина 2.6м)
	# Левая стена тоннеля:
	_add_collidable_box(body, root, Vector3(1.6, 2.8, 4.7), mat_bunker_wall, Vector3(-2.1, 1.4, 1.85))
	# Правая стена тоннеля:
	_add_collidable_box(body, root, Vector3(1.6, 2.8, 4.7), mat_bunker_wall, Vector3(2.1, 1.4, 1.85))

	# !!! КЛЮЧЕВАЯ КОЛЛИЗИЯ ЛАЗА: НИЗКОЕ ПЕРЕКРЫТИЕ (LINTEL & CEILING) !!!
	# Высота просвета ровно 1.45м от земли!
	# Стоящий игрок (рост 1.8м) физически упирается и НЕ МОЖЕТ пройти!
	# Присевший игрок (рост 0.9м) свободно и плавно пролезает на корточках (клавиша [C] или [Ctrl])!
	# Толщина балки 0.8м, центр Y = 1.45 + 0.4 = 1.85м:
	_add_collidable_box(body, root, Vector3(2.6, 0.8, 4.7), mat_bunker_wall, Vector3(0.0, 1.85, 1.85))

	# Обваленные бетонные плиты и песок поверх перекрытия входа
	_add_box(root, Vector3(3.8, 1.2, 2.6), mat_sandstone_dark, Vector3(0.0, 2.8, 2.8), Vector3(deg_to_rad(6.0), deg_to_rad(-12.0), deg_to_rad(4.0)))
	_add_box(root, Vector3(3.0, 0.8, 3.0), mat_bunker_wall, Vector3(0.3, 2.6, 1.0), Vector3(deg_to_rad(-4.0), deg_to_rad(10.0), 0.0))

	# Предупреждающая желто-черная полоса на перемычке лаза
	_add_box(root, Vector3(2.6, 0.22, 0.1), mat_barrel_stripe, Vector3(0.0, 1.35, 4.22))

	# 4. ДЕТАЛИ ВНУТРИ СЕКРЕТНОГО СХРОНА (SURVIVOR BUNKER INTERIOR):
	# Подвесной аварийный фонарь с теплым оранжевым свечением
	_add_cyl(root, 0.6, 0.02, 0.02, mat_steel_beam, Vector3(0.0, 2.2, -3.5))
	_add_box(root, Vector3(0.35, 0.45, 0.35), mat_emergency_red, Vector3(0.0, 1.8, -3.5))
	var lantern_light := OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.68, 0.22)
	lantern_light.light_energy = 3.2
	lantern_light.omni_range = 9.0
	lantern_light.position = Vector3(0.0, 1.7, -3.5)
	root.add_child(lantern_light)

	# Койка выжившего
	_add_collidable_box(body, root, Vector3(1.4, 0.4, 2.4), mat_sandbag, Vector3(-2.8, 0.25, -4.5))
	_add_box(root, Vector3(1.2, 0.1, 0.8), mat_carpet, Vector3(-2.8, 0.5, -5.2))

	# Стеллаж с армейскими ящиками
	_add_collidable_box(body, root, Vector3(0.7, 2.0, 2.8), mat_steel_beam, Vector3(3.2, 1.0, -3.8))
	_add_box(root, Vector3(0.5, 0.3, 0.7), mat_military_green, Vector3(3.2, 0.8, -4.5))
	_add_box(root, Vector3(0.5, 0.3, 0.7), mat_military_green, Vector3(3.2, 1.4, -3.4))

	# ЦЕННЫЙ СЕКРЕТНЫЙ ТАЙНИК ВЫЖИВШИХ В ЦЕНТРЕ СХРОНА
	var crate := _create_loot_crate("ОБЫСКАТЬ СЕКРЕТНЫЙ ТАЙНИК ВЫЖИВШИХ [E]", true)
	crate.position = Vector3(0.0, 0.35, -3.8)
	root.add_child(crate)

	return root

# =========================================================================
# ВСПОМОГАТЕЛЬНЫЕ МЕШ-ФУНКЦИИ
# =========================================================================

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

static func _add_cyl(parent: Node3D, height: float, top_r: float, bot_r: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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

static func _add_collidable_box(body: StaticBody3D, parent_visual: Node3D, sz: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := _add_box(parent_visual, sz, mat, pos, rot)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	col.shape = box
	col.position = pos
	col.rotation = rot
	body.add_child(col)
	return mi

static func _add_collidable_cyl(body: StaticBody3D, parent_visual: Node3D, height: float, top_r: float, bot_r: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := _add_cyl(parent_visual, height, top_r, bot_r, mat, pos, rot)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = height
	cyl.radius = maxf(top_r, bot_r)
	col.shape = cyl
	col.position = pos
	col.rotation = rot
	body.add_child(col)
	return mi
