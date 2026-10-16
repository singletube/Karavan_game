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

	# Бетонное возвышение островка
	_add_box(root, Vector3(8.5, 0.35, 12.0), mat_concrete, Vector3(0.0, 0.18, 0.0))

	# 4 стальные опорные колонны навеса
	var pillar_coords := [
		Vector3(-3.2, 2.2, -4.5),
		Vector3(3.2, 2.2, -4.5),
		Vector3(-3.2, 2.2, 4.5),
		Vector3(3.2, 2.2, 4.5)
	]
	for p in pillar_coords:
		_add_box(root, Vector3(0.35, 4.2, 0.35), mat_metal_rusty, p)

	# Навес из ржавого профилированного металла
	_add_box(root, Vector3(9.2, 0.35, 13.0), mat_metal_rusty, Vector3(0.0, 4.4, 0.0), Vector3(deg_to_rad(-2.5), 0.0, deg_to_rad(1.5)))

	# 2 винтажные бензоколонки
	var pump1 := _add_box(root, Vector3(0.9, 1.6, 0.7), mat_barrel_red, Vector3(-1.4, 1.15, 0.0))
	_add_box(pump1, Vector3(0.7, 0.4, 0.72), mat_concrete, Vector3(0.0, 0.35, 0.0)) # экран счетчика

	var pump2 := _add_box(root, Vector3(0.9, 1.6, 0.7), mat_barrel_red, Vector3(1.4, 1.15, 0.0))
	_add_box(pump2, Vector3(0.7, 0.4, 0.72), mat_concrete, Vector3(0.0, 0.35, 0.0))

	# Коллизия навеса и колонок
	var body := StaticBody3D.new()
	root.add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.5, 2.0, 4.0)
	col.shape = box
	col.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(col)

	# Ящик с припасами (Loot Crate)
	var crate := _create_loot_crate("ЗАБРАТЬ ПРИПАСЫ И ТОПЛИВО [E]", true)
	crate.position = Vector3(0.0, 0.4, 2.2)
	root.add_child(crate)

	return root

# =========================================================================
# 3. ПУСТЫННЫЙ ОАЗИС (DESERT OASIS)
# =========================================================================
static func create_oasis() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "DesertOasis"

	# Бирюзовое зеркало воды оазиса
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.5
	disc.bottom_radius = 6.5
	disc.height = 0.12
	disc.material = mat_water_oasis
	water.mesh = disc
	water.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(water)

	# 3 пальмы вокруг водоема
	var palm_positions := [
		Vector3(-5.2, 0.0, -3.2),
		Vector3(4.8, 0.0, -4.0),
		Vector3(2.5, 0.0, 5.5)
	]
	for pp in palm_positions:
		_create_palm_tree(root, pp)

	# Древний лагерь и сундук караванщика
	var chest := _create_loot_crate("ОТКРЫТЬ СУНДУК ОАЗИСА [E]", false)
	chest.position = Vector3(-1.8, 0.1, 4.5)
	root.add_child(chest)

	return root

# =========================================================================
# ВСПОМОГАТЕЛЬНЫЕ ЭЛЕМЕНТЫ: ПАЛЬМА И СУНДУК С ПРИПАСАМИ
# =========================================================================
static func _create_palm_tree(parent: Node3D, pos: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = pos
	parent.add_child(palm)

	# Изогнутый ствол пальмы
	var trunk_h: float = randf_range(5.2, 6.8)
	var lean_ang: float = deg_to_rad(randf_range(8.0, 16.0))
	_add_cyl(palm, trunk_h, 0.24, 0.42, mat_palm_trunk, Vector3(0.0, trunk_h * 0.5, 0.0), Vector3(lean_ang, randf_range(0.0, TAU), 0.0))

	# Пышная крона из листьев наверху
	var crown_pos := Vector3(0.0, trunk_h, 0.0)
	for i in range(7):
		var leaf_ang: float = float(i) * (TAU / 7.0)
		var lx: float = cos(leaf_ang) * 1.6
		var lz: float = sin(leaf_ang) * 1.6
		_add_box(palm, Vector3(0.4, 0.06, 3.2), mat_palm_frond, crown_pos + Vector3(lx, -0.4, lz), Vector3(deg_to_rad(28.0), leaf_ang, 0.0))

	# Коллизия ствола пальмы
	var body := StaticBody3D.new()
	palm.add_child(body)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = trunk_h
	cyl.radius = 0.4
	col.shape = cyl
	col.position.y = trunk_h * 0.5
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
				caravan.sync_caravan_state.rpc(caravan.global_position, caravan.health, caravan.is_blocked, caravan.is_destroyed)

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

	# Каменная платформа-стилобат полузанесенная песком
	_add_box(root, Vector3(14.0, 0.45, 14.0), mat_sandstone, Vector3(0.0, 0.22, 0.0))
	_add_box(root, Vector3(7.0, 0.22, 2.2), mat_sandstone_dark, Vector3(0.0, 0.11, 7.5)) # Ступени

	# 1. Передняя левая колонна (целая с капителью)
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(-4.5, 0.42, 4.2))
	_add_cyl(root, 5.0, 0.42, 0.46, mat_sandstone, Vector3(-4.5, 3.1, 4.2))
	_add_box(root, Vector3(1.3, 0.35, 1.3), mat_sandstone_dark, Vector3(-4.5, 5.75, 4.2))

	# 2. Передняя правая колонна (целая с капителью)
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(4.5, 0.42, 4.2))
	_add_cyl(root, 5.0, 0.42, 0.46, mat_sandstone, Vector3(4.5, 3.1, 4.2))
	_add_box(root, Vector3(1.3, 0.35, 1.3), mat_sandstone_dark, Vector3(4.5, 5.75, 4.2))

	# Каменный архитрав (перекрытие) между передними колоннами
	_add_box(root, Vector3(10.2, 0.7, 1.4), mat_sandstone, Vector3(0.0, 6.25, 4.2))
	# Треугольный фронтон наверху
	_add_box(root, Vector3(6.5, 0.5, 1.2), mat_sandstone_dark, Vector3(0.0, 6.85, 4.2))

	# 3. Задняя левая колонна (накренившаяся на 16 градусов)
	var lean_c := Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(-8.0))
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(-4.5, 0.42, -4.2))
	_add_cyl(root, 4.8, 0.42, 0.46, mat_sandstone, Vector3(-4.1, 2.9, -3.8), lean_c)

	# 4. Задняя правая колонна (разбитый обломок + упавшие барабаны)
	_add_box(root, Vector3(1.4, 0.4, 1.4), mat_sandstone_dark, Vector3(4.5, 0.42, -4.2))
	_add_cyl(root, 1.8, 0.42, 0.46, mat_sandstone, Vector3(4.5, 1.4, -4.2))
	# Упавшие каменные цилиндрические блоки в песке
	_add_cyl(root, 1.6, 0.42, 0.42, mat_sandstone, Vector3(3.2, 0.42, -2.8), Vector3(0.0, deg_to_rad(45.0), deg_to_rad(85.0)))
	_add_box(root, Vector3(1.2, 0.8, 1.0), mat_sandstone_dark, Vector3(4.8, 0.4, -1.6), Vector3(deg_to_rad(12.0), deg_to_rad(30.0), 0.0))

	# Полуразрушенная задняя стена святилища
	_add_box(root, Vector3(11.0, 3.4, 0.9), mat_sandstone_dark, Vector3(0.0, 1.9, -5.2))
	_add_box(root, Vector3(4.0, 1.2, 0.95), mat_sandstone, Vector3(-2.5, 4.2, -5.2))

	# Обломки боковых стен
	_add_box(root, Vector3(0.9, 2.4, 6.0), mat_sandstone_dark, Vector3(-5.5, 1.4, -1.0))
	_add_box(root, Vector3(0.9, 1.6, 4.5), mat_sandstone_dark, Vector3(5.5, 1.0, -1.0))

	# Центральный жертвенник / каменный пьедестал
	_add_box(root, Vector3(2.6, 0.75, 2.6), mat_sandstone_dark, Vector3(0.0, 0.6, 0.0))
	_add_box(root, Vector3(2.2, 0.25, 2.2), mat_sandstone, Vector3(0.0, 1.05, 0.0))

	# Древний сундук на алтаре с золотым свечением
	var chest := _create_loot_crate("ОТКРЫТЬ ДРЕВНИЙ СУНДУК [E]", false)
	chest.position = Vector3(0.0, 1.18, 0.0)
	root.add_child(chest)

	# Статичная коллизия храма
	var body := StaticBody3D.new()
	var col_base := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(14.0, 0.6, 14.0)
	col_base.shape = b_shape
	col_base.position = Vector3(0.0, 0.3, 0.0)
	body.add_child(col_base)

	# Коллизия задней стены
	var col_wall := CollisionShape3D.new()
	var w_shape := BoxShape3D.new()
	w_shape.size = Vector3(12.0, 4.5, 1.5)
	col_wall.shape = w_shape
	col_wall.position = Vector3(0.0, 2.2, -5.2)
	body.add_child(col_wall)

	root.add_child(body)
	return root

# =========================================================================
# 7. РАЗРУШЕННЫЙ ВОЕННЫЙ БУНКЕР (MILITARY BUNKER RUINS)
# =========================================================================
static func create_bunker_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "MilitaryBunkerRuins"

	# Основной массивный бетонный ДОТ / бункер
	_add_box(root, Vector3(11.0, 3.4, 9.5), mat_bunker_wall, Vector3(0.0, 1.7, 0.0))
	# Скошенная бронированная крыша
	_add_box(root, Vector3(12.0, 0.6, 10.5), mat_bunker_wall, Vector3(0.0, 3.65, 0.0))

	# Выносной входной шлюз с наклонными волнорезами
	_add_box(root, Vector3(1.2, 3.0, 3.5), mat_bunker_wall, Vector3(-2.8, 1.5, 5.2))
	_add_box(root, Vector3(1.2, 3.0, 3.5), mat_bunker_wall, Vector3(2.8, 1.5, 5.2))
	_add_box(root, Vector3(6.8, 0.6, 3.5), mat_bunker_wall, Vector3(0.0, 3.2, 5.2))

	# Сорванная взрывом тяжелая стальная гермодверь (лежит под углом внутри шлюза)
	_add_box(root, Vector3(2.6, 0.18, 3.0), mat_burnt_metal, Vector3(0.4, 0.15, 4.2), Vector3(deg_to_rad(6.0), deg_to_rad(-24.0), deg_to_rad(8.0)))
	# Предупреждающая желто-черная полоса на пороге
	_add_box(root, Vector3(4.2, 0.12, 0.25), mat_barrel_stripe, Vector3(0.0, 0.06, 6.8))

	# Узкие амбразуры для ведения огня
	_add_box(root, Vector3(2.2, 0.45, 0.4), mat_burnt_metal, Vector3(-3.4, 2.1, 4.8))
	_add_box(root, Vector3(2.2, 0.45, 0.4), mat_burnt_metal, Vector3(3.4, 2.1, 4.8))

	# Баррикада из мешков с песком у входа
	for i in range(4):
		_add_box(root, Vector3(1.1, 0.35, 0.55), mat_sandbag, Vector3(-3.2 + float(i) * 0.95, 0.2, 6.6), Vector3(0.0, deg_to_rad(randf_range(-6.0, 6.0)), 0.0))
		if i < 3:
			_add_box(root, Vector3(1.1, 0.35, 0.55), mat_sandbag, Vector3(-2.7 + float(i) * 0.95, 0.55, 6.6), Vector3(0.0, deg_to_rad(randf_range(-6.0, 6.0)), 0.0))

	# Сломанная антенна радиосвязи на крыше
	_add_cyl(root, 2.4, 0.06, 0.08, mat_metal_rusty, Vector3(3.5, 4.8, -2.5))
	_add_cyl(root, 2.8, 0.05, 0.06, mat_metal_rusty, Vector3(4.6, 5.8, -2.5), Vector3(deg_to_rad(52.0), 0.0, deg_to_rad(28.0)))

	# Военный контейнер с армейскими припасами внутри бункера
	var crate := _create_loot_crate("ОТКРЫТЬ ВОЕННЫЙ КОНТЕЙНЕР [E]", true)
	crate.position = Vector3(0.0, 0.35, -0.8)
	root.add_child(crate)

	# Статичная коллизия бункера
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(11.5, 3.8, 10.0)
	col.shape = b_shape
	col.position = Vector3(0.0, 1.9, 0.0)
	body.add_child(col)
	root.add_child(body)

	return root

# =========================================================================
# 8. ОБЛОМКИ ГРУЗОВОГО САМОЛЕТА (CRASHED PLANE WRECK)
# =========================================================================
static func create_plane_wreck_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PlaneWreckRuins"

	# Разорванный цилиндрический фюзеляж, врезавшийся в песок под углом
	var fuselage := Node3D.new()
	fuselage.position = Vector3(0.0, 1.2, 0.0)
	fuselage.rotation = Vector3(deg_to_rad(12.0), deg_to_rad(-25.0), deg_to_rad(16.0))
	root.add_child(fuselage)

	# Корпус самолета из листов дюралюминия
	_add_cyl(fuselage, 8.5, 1.85, 1.85, mat_plane_metal, Vector3(0.0, 0.0, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	# Обгоревший хвост с изломом
	_add_cyl(fuselage, 3.2, 1.2, 1.85, mat_burnt_metal, Vector3(0.0, 0.2, -5.2), Vector3(PI * 0.5 + deg_to_rad(18.0), 0.0, 0.0))

	# Огромное крыло самолета, торчащее вверх из песка под углом 35 градусов
	_add_box(root, Vector3(12.0, 0.28, 2.5), mat_plane_metal, Vector3(-5.2, 3.4, 0.5), Vector3(deg_to_rad(28.0), deg_to_rad(12.0), deg_to_rad(-28.0)))
	# Аварийная маркировка крыла
	_add_box(root, Vector3(2.4, 0.32, 0.5), mat_barrel_stripe, Vector3(-8.5, 5.0, -0.6), Vector3(deg_to_rad(28.0), deg_to_rad(12.0), deg_to_rad(-28.0)))

	# Оторванная реактивная турбина двигателя, наполовину засыпанная в песок
	var turbine := _add_cyl(root, 3.2, 0.82, 0.72, mat_burnt_metal, Vector3(4.8, 0.65, 2.8), Vector3(deg_to_rad(12.0), deg_to_rad(55.0), deg_to_rad(85.0)))
	_add_cyl(turbine, 0.3, 0.65, 0.65, mat_burnt_metal, Vector3(0.0, 1.45, 0.0)) # Ротор турбины

	# Вертикальный хвостовой киль, застрявший в дюне
	_add_box(root, Vector3(0.2, 4.2, 2.2), mat_plane_metal, Vector3(3.8, 1.8, -4.5), Vector3(deg_to_rad(18.0), deg_to_rad(-35.0), deg_to_rad(14.0)))

	# Авиационный грузовой контейнер, выброшенный из трюма
	var crate := _create_loot_crate("ОТКРЫТЬ АВИАЦИОННЫЙ ГРУЗ [E]", true)
	crate.position = Vector3(-0.6, 0.35, 2.5)
	crate.rotation.y = deg_to_rad(22.0)
	root.add_child(crate)

	# Физическая коллизия обломков
	var body := StaticBody3D.new()
	var col_f := CollisionShape3D.new()
	var f_box := BoxShape3D.new()
	f_box.size = Vector3(4.2, 3.2, 9.0)
	col_f.shape = f_box
	col_f.position = Vector3(0.0, 1.5, 0.0)
	body.add_child(col_f)

	var col_w := CollisionShape3D.new()
	var w_box := BoxShape3D.new()
	w_box.size = Vector3(10.0, 1.5, 3.0)
	col_w.shape = w_box
	col_w.position = Vector3(-5.0, 2.5, 0.0)
	body.add_child(col_w)

	root.add_child(body)
	return root

# =========================================================================
# 9. РАЗВАЛИНЫ ГЛИНЯНОГО КАРАВАН-САРАЯ (CLAY RUINS / ADOBE CARAVANSERAI)
# =========================================================================
static func create_clay_ruins() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "ClayCaravanseraiRuins"

	# Фундамент и пол из утоптанной глины
	_add_box(root, Vector3(11.0, 0.3, 11.0), mat_adobe_clay, Vector3(0.0, 0.15, 0.0))

	# Внешние толстые саманные стены с неровными разрушенными верхушками
	_add_box(root, Vector3(11.0, 3.2, 0.85), mat_adobe_clay, Vector3(0.0, 1.6, -5.0)) # Задняя стена
	_add_box(root, Vector3(0.85, 2.8, 9.5), mat_adobe_clay, Vector3(-5.0, 1.4, -0.2)) # Левая стена
	_add_box(root, Vector3(0.85, 2.2, 7.0), mat_adobe_clay, Vector3(5.0, 1.1, -1.5))  # Правая стена

	# Передняя стена с арочным порталом входа
	_add_box(root, Vector3(3.8, 2.8, 0.85), mat_adobe_clay, Vector3(-3.5, 1.4, 4.5))
	_add_box(root, Vector3(3.8, 2.8, 0.85), mat_adobe_clay, Vector3(3.5, 1.4, 4.5))
	_add_box(root, Vector3(3.4, 0.8, 0.85), mat_clay_dark, Vector3(0.0, 2.8, 4.5)) # Перемычка арки

	# Торчащие сквозь стены деревянные балки перекрытий (vigas)
	for i in range(5):
		var bz: float = -4.2 + float(i) * 1.8
		_add_cyl(root, 2.2, 0.10, 0.10, mat_beam_wood, Vector3(-5.0, 2.9, bz), Vector3(0.0, 0.0, PI * 0.5))
		if i % 2 == 0:
			_add_cyl(root, 2.0, 0.10, 0.10, mat_beam_wood, Vector3(5.0, 2.3, bz), Vector3(0.0, 0.0, PI * 0.5))

	# Внутренняя перегородка с полуразрушенным проходом
	_add_box(root, Vector3(4.5, 2.4, 0.65), mat_adobe_clay, Vector3(-1.5, 1.2, 0.0))

	# Глиняные сосуды и амфоры для масла и воды в углу
	_add_cyl(root, 0.95, 0.28, 0.18, mat_clay_dark, Vector3(-3.8, 0.5, 3.6))
	_add_cyl(root, 0.80, 0.24, 0.16, mat_clay_dark, Vector3(-4.3, 0.42, 3.2))
	_add_cyl(root, 0.65, 0.20, 0.14, mat_clay_dark, Vector3(-3.4, 0.35, 3.2))

	# Обвалившийся глиняный очаг в углу
	_add_cyl(root, 0.75, 0.65, 0.85, mat_clay_dark, Vector3(3.8, 0.4, -3.8))

	# Тайник контрабандиста в защищенной внутренней комнате
	var stash := _create_loot_crate("ОБЫСКАТЬ ТАЙНИК КОНТРАБАНДИСТА [E]", false)
	stash.position = Vector3(-3.0, 0.25, -2.8)
	root.add_child(stash)

	# Статичная коллизия стен
	var body := StaticBody3D.new()
	var col_back := CollisionShape3D.new()
	var b_back := BoxShape3D.new()
	b_back.size = Vector3(11.0, 3.5, 1.2)
	col_back.shape = b_back
	col_back.position = Vector3(0.0, 1.7, -5.0)
	body.add_child(col_back)

	var col_left := CollisionShape3D.new()
	var b_left := BoxShape3D.new()
	b_left.size = Vector3(1.2, 3.2, 10.0)
	col_left.shape = b_left
	col_left.position = Vector3(-5.0, 1.6, 0.0)
	body.add_child(col_left)

	var col_right := CollisionShape3D.new()
	var b_right := BoxShape3D.new()
	b_right.size = Vector3(1.2, 2.6, 8.0)
	col_right.shape = b_right
	col_right.position = Vector3(5.0, 1.3, -1.0)
	body.add_child(col_right)

	root.add_child(body)
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
