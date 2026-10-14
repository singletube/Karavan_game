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
	is_cleared = true
	_spawn_debris_particles()
	if player and player.has_method("notify_hud"):
		player.notify_hud("ЗАВАЛ РАЗОБРАН! ПУТЬ СВОБОДЕН", Color(0.3, 1.0, 0.4))
	queue_free()

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
	is_cleared = true

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

	# Уведомление игроку
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("notify_hud"):
			p.notify_hud("БОЧКИ ВЗОРВАНЫ! ДОРОГА РАСЧИЩЕНА", Color(1.0, 0.6, 0.2))

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
	is_looted = true

	# Звук подбора припасов
	var ap := AudioStreamPlayer.new()
	ap.stream = snd_pickup
	ap.volume_db = -4.0
	get_tree().root.add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)

	# Восстановление игрока и каравана
	if player and is_instance_valid(player):
		player.health = 100
		if player.has_signal("health_changed"):
			player.health_changed.emit(100)

		# Пополнение всех патронов до максимума
		var wm = player.get_node_or_null("WeaponManager")
		if wm and wm.get("ammo_manager"):
			var am = wm.ammo_manager
			if am.get("ammo_dict") and am.get("max_nb_per_ammo_dict"):
				for a_type in am.max_nb_per_ammo_dict:
					am.ammo_dict[a_type] = am.max_nb_per_ammo_dict[a_type]

		# Ремонт каравана (+150 HP)
		var caravan = get_tree().get_first_node_in_group("caravan")
		if caravan and is_instance_valid(caravan) and not caravan.get("is_destroyed"):
			var cur_hp: int = int(caravan.get("health"))
			var max_hp: int = int(caravan.get("MAX_HEALTH"))
			caravan.health = mini(max_hp, cur_hp + 150)
			if caravan.has_signal("health_changed"):
				caravan.health_changed.emit(caravan.health, max_hp)

		if player.has_method("notify_hud"):
			player.notify_hud("+150 ХП КАРАВАНА · БОЕЗАПАС ПОПОЛНЕН!", Color(0.25, 1.0, 0.45))

	# Изменение визуала после сбора (крышка открывается, свет затухает)
	var glow = get_node_or_null("CrateGlow")
	if glow:
		glow.light_energy = 0.3
	var lid = get_node_or_null("Lid")
	if lid:
		lid.rotation.x = deg_to_rad(-65.0)

	remove_from_group("interactive")
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
