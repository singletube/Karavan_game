class_name DungeonLoot3D
extends RefCounted

## Генератор отдельных 3D-предметов лута для подземелий и развалин:
## 1. Патроны (Ammo Box) — пополняет боезапас всех видов оружия
## 2. Аптечка (Medkit) — восстанавливает +50 HP здоровья игрока
## 3. Отдых / корм для осла (Donkey Care) — лечит осла/караван на +150 HP и снимает угрозу роя

const SND_PICKUP_PATH := "res://assets/audio/item_pickup.wav"

enum LootType {
	AMMO,
	MEDKIT,
	DONKEY_CARE
}

# -------------------------------------------------------------------------
# ФАБРИКА СЛУЧАЙНОГО НАБОРА ПРЕДМЕТОВ (ОТ 1 ДО 4 ШТУК В ДАНЖЕ)
# -------------------------------------------------------------------------
static func spawn_dungeon_loot_set(parent: Node3D, dungeon_type: String) -> Array[Node3D]:
	var items: Array[Node3D] = []
	var count: int = randi_range(1, 4)

	# Список доступных точек спавна в зависимости от архитектуры данжа
	var spawn_points: Array[Vector3] = _get_dungeon_spawn_points(dungeon_type)
	spawn_points.shuffle()

	# Пул типов лута с честными весами
	var loot_pool: Array[LootType] = [
		LootType.AMMO,
		LootType.MEDKIT,
		LootType.DONKEY_CARE,
		LootType.AMMO,
		LootType.MEDKIT
	]

	for i in range(mini(count, spawn_points.size())):
		var l_type: LootType = loot_pool.pick_random()
		var p_pos: Vector3 = spawn_points[i]
		var item: Node3D = null

		match l_type:
			LootType.AMMO:
				item = create_ammo_pickup(p_pos)
			LootType.MEDKIT:
				item = create_medkit_pickup(p_pos)
			LootType.DONKEY_CARE:
				item = create_donkey_care_pickup(p_pos)

		if item:
			parent.add_child(item)
			items.append(item)

	return items

# Координаты укрытий, алтарей, столов и комнат внутри развалин
static func _get_dungeon_spawn_points(dungeon_type: String) -> Array[Vector3]:
	match dungeon_type:
		"ancient_ruins":
			# Внутри древнего храма: на постаменте алтаря, между колоннами и в тайных нишах
			return [
				Vector3(0.0, 2.15, 0.0),    # Центр алтаря
				Vector3(-3.2, 0.45, -2.5),  # Левый портик
				Vector3(3.2, 0.45, -2.5),   # Правый портик
				Vector3(0.0, 0.45, -6.8),   # Задняя стена святилища
				Vector3(-2.8, 0.45, 3.2),   # Входные ступени слева
				Vector3(2.8, 0.45, 3.2)     # Входные ступени справа
			]
		"bunker_ruins":
			# Внутри военного бункера: на командном столе, оружейных стеллажах и в шлюзе
			return [
				Vector3(0.0, 0.45, 0.0),     # Центр бункера
				Vector3(-4.5, 0.45, -3.2),   # Оружейный арсенал
				Vector3(4.5, 0.45, -3.2),    # Комната связи
				Vector3(-3.8, 0.45, 3.8),    # Склад провизии
				Vector3(0.0, 0.45, 5.5)      # Входной шлюз
			]
		"clay_ruins":
			# Караван-сарай: во внутреннем дворике, жилых кельях и у колодца
			return [
				Vector3(0.0, 0.45, -2.2),    # Рядом с колодцем во дворе
				Vector3(-4.2, 0.45, 1.5),    # Западная комната караванщиков
				Vector3(4.2, 0.45, 1.5),     # Восточная комната отдыха
				Vector3(-3.8, 0.45, -4.5),   # Угловой склад
				Vector3(3.8, 0.45, -4.5)     # Стойло для вьючных животных
			]
		"plane_wreck_ruins":
			# Упавший самолет: в грузовом отсеке, кабине пилотов и за крылом
			return [
				Vector3(0.0, 0.55, 0.0),     # Грузовой отсек
				Vector3(0.0, 0.65, -5.5),    # Кабина пилотов
				Vector3(-3.5, 0.35, 2.2),    # Обломки левого крыла
				Vector3(3.5, 0.35, 2.2),     # Обломки правого крыла
				Vector3(0.0, 0.45, 6.2)      # Хвостовой грузовой люк
			]
		"crawl_shelter":
			# Засыпанный схрон
			return [
				Vector3(0.0, 0.35, 0.0),
				Vector3(-1.8, 0.35, -1.5),
				Vector3(1.8, 0.35, -1.5),
				Vector3(0.0, 0.35, 2.2)
			]
		_: # По умолчанию
			return [
				Vector3(-2.0, 0.40, -2.0),
				Vector3(2.0, 0.40, -2.0),
				Vector3(-2.0, 0.40, 2.0),
				Vector3(2.0, 0.40, 2.0)
			]

# =========================================================================
# 1. ПАТРОНЫ (AMMO BOX PICKUP)
# =========================================================================
static func create_ammo_pickup(pos: Vector3) -> Node3D:
	var root := _create_pickup_base("AmmoPickup", pos, LootType.AMMO, "[E] Взять патроны (+боезапас)")

	# 3D Модель: металлический армейский ящик защитного цвета с желтой маркировкой
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.52, 0.32, 0.32)
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.position = Vector3(0.0, 0.16, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.32, 0.18)
	mat.metallic = 0.85
	mat.roughness = 0.35
	mi.material_override = mat
	root.add_child(mi)

	# Желтая маркировочная полоса боеприпасов
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.53, 0.06, 0.33)
	var mi_str := MeshInstance3D.new()
	mi_str.mesh = stripe_mesh
	mi_str.position = Vector3(0.0, 0.18, 0.0)
	var mat_str := StandardMaterial3D.new()
	mat_str.albedo_color = Color(0.95, 0.82, 0.22)
	mat_str.emission_enabled = true
	mat_str.emission = Color(0.95, 0.82, 0.22) * 0.4
	mi_str.material_override = mat_str
	root.add_child(mi_str)

	# Мягкий янтарный свет
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.3)
	light.light_energy = 1.4
	light.omni_range = 2.8
	light.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(light)

	return root

# =========================================================================
# 2. АПТЕЧКА (MEDKIT PICKUP)
# =========================================================================
static func create_medkit_pickup(pos: Vector3) -> Node3D:
	var root := _create_pickup_base("MedkitPickup", pos, LootType.MEDKIT, "[E] Взять аптечку (+50 HP)")

	# Белый полевой медицинский кейс
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.46, 0.34, 0.20)
	var mi := MeshInstance3D.new()
	mi.mesh = case_mesh
	mi.position = Vector3(0.0, 0.17, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.94, 0.96)
	mat.roughness = 0.25
	mi.material_override = mat
	root.add_child(mi)

	# Красный медицинский крест на крышке
	var cross_h := BoxMesh.new()
	cross_h.size = Vector3(0.22, 0.08, 0.21)
	var mi_ch := MeshInstance3D.new()
	mi_ch.mesh = cross_h
	mi_ch.position = Vector3(0.0, 0.17, 0.0)

	var cross_v := BoxMesh.new()
	cross_v.size = Vector3(0.08, 0.22, 0.21)
	var mi_cv := MeshInstance3D.new()
	mi_cv.mesh = cross_v
	mi_cv.position = Vector3(0.0, 0.17, 0.0)

	var mat_cross := StandardMaterial3D.new()
	mat_cross.albedo_color = Color(0.95, 0.08, 0.08)
	mat_cross.emission_enabled = true
	mat_cross.emission = Color(0.95, 0.08, 0.08) * 0.8
	mi_ch.material_override = mat_cross
	mi_cv.material_override = mat_cross
	root.add_child(mi_ch)
	root.add_child(mi_cv)

	# Зелено-изумрудный луч медицинской помощи
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4)
	light.light_energy = 1.6
	light.omni_range = 2.8
	light.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(light)

	return root

# =========================================================================
# 3. ОТДЫХ И КОРМ ДЛЯ ОСЛА (DONKEY CARE PICKUP)
# =========================================================================
static func create_donkey_care_pickup(pos: Vector3) -> Node3D:
	var root := _create_pickup_base("DonkeyCarePickup", pos, LootType.DONKEY_CARE, "[E] Отдых для осла (+150 HP каравану)")

	# Холщовый мешок отборного овса
	var sack_mesh := CylinderMesh.new()
	sack_mesh.top_radius = 0.20
	sack_mesh.bottom_radius = 0.26
	sack_mesh.height = 0.42
	var mi_sack := MeshInstance3D.new()
	mi_sack.mesh = sack_mesh
	mi_sack.position = Vector3(-0.12, 0.21, 0.0)

	var mat_sack := StandardMaterial3D.new()
	mat_sack.albedo_color = Color(0.72, 0.60, 0.42)
	mat_sack.roughness = 0.90
	mi_sack.material_override = mat_sack
	root.add_child(mi_sack)

	# Деревянное ведро с чистой родниковой водой
	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.18
	bucket_mesh.bottom_radius = 0.14
	bucket_mesh.height = 0.34
	var mi_bucket := MeshInstance3D.new()
	mi_bucket.mesh = bucket_mesh
	mi_bucket.position = Vector3(0.18, 0.17, 0.0)

	var mat_bucket := StandardMaterial3D.new()
	mat_bucket.albedo_color = Color(0.48, 0.32, 0.18)
	mat_bucket.roughness = 0.70
	mi_bucket.material_override = mat_bucket
	root.add_child(mi_bucket)

	# Водная гладь внутри ведра
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.16
	water_mesh.bottom_radius = 0.16
	water_mesh.height = 0.04
	var mi_w := MeshInstance3D.new()
	mi_w.mesh = water_mesh
	mi_w.position = Vector3(0.18, 0.32, 0.0)
	var mat_w := StandardMaterial3D.new()
	mat_w.albedo_color = Color(0.2, 0.75, 0.95, 0.8)
	mat_w.roughness = 0.1
	mat_w.emission_enabled = true
	mat_w.emission = Color(0.1, 0.6, 0.9) * 0.5
	mi_w.material_override = mat_w
	root.add_child(mi_w)

	# Тёплое золотое свечение заботы
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.80, 0.35)
	light.light_energy = 1.8
	light.omni_range = 3.2
	light.position = Vector3(0.0, 0.40, 0.0)
	root.add_child(light)

	return root

# -------------------------------------------------------------------------
# ОБЩАЯ ЛОГИКА ПРЕДМЕТА (ПАРЯЩАЯ АНИМАЦИЯ, КОЛЛИЗИЯ И ПОДБОР)
# -------------------------------------------------------------------------
static func _create_pickup_base(p_name: String, pos: Vector3, l_type: LootType, prompt: String) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.add_to_group("interactive")
	root.add_to_group("pickup_item")
	root.set_meta("prompt_text", prompt)
	root.set_meta("loot_type", int(l_type))

	# Зона автоподбора при наступании
	var area := Area3D.new()
	area.name = "PickupArea"
	area.collision_layer = 0
	area.collision_mask = 2 # Слой игрока
	root.add_child(area)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	col.position = Vector3(0.0, 0.35, 0.0)
	area.add_child(col)

	# Скрипт поведения предмета
	var script_text := """
extends Node3D

var loot_type: int = 0
var base_y: float = 0.0
var anim_time: float = 0.0
var is_collected: bool = false
var snd_pickup: AudioStream = null

func _ready() -> void:
	base_y = position.y
	loot_type = int(get_meta("loot_type", 0))
	anim_time = randf() * TAU
	if ResourceLoader.exists("res://assets/audio/item_pickup.wav"):
		snd_pickup = load("res://assets/audio/item_pickup.wav")
	elif ResourceLoader.exists("res://assets/audio/wave_win.wav"):
		snd_pickup = load("res://assets/audio/wave_win.wav")

	var area = get_node_or_null("PickupArea") as Area3D
	if area:
		area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	anim_time += delta * 2.8
	# Плавное парение вверх-вниз и неторопливое вращение
	position.y = base_y + sin(anim_time) * 0.06
	rotate_y(delta * 1.2)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		collect(body)

func on_interact(player: Node) -> void:
	collect(player)

func collect(player: Node) -> void:
	if is_collected:
		return
	is_collected = true
	remove_from_group("interactive")
	remove_from_group("pickup_item")

	# Звук подбора
	if snd_pickup:
		var ap := AudioStreamPlayer.new()
		ap.stream = snd_pickup
		ap.volume_db = 0.5
		get_tree().root.add_child(ap)
		ap.play()
		ap.finished.connect(ap.queue_free)

	# Применение эффекта предмета
	match loot_type:
		0: # AMMO
			if player and player.has_method("add_ammo"):
				player.add_ammo(60)
			if player and player.has_method("notify_hud"):
				player.notify_hud("📦 БОЕПРИПАСЫ ПОПОЛНЕНЫ!", Color(1.0, 0.88, 0.25))

		1: # MEDKIT
			if player and player.has_method("heal"):
				player.heal(50)
			if player and player.has_method("notify_hud"):
				player.notify_hud("💊 +50 HP ЗДОРОВЬЕ ВОССТАНОВЛЕНО!", Color(0.3, 1.0, 0.45))

		2: # DONKEY CARE
			var caravan = get_tree().get_first_node_in_group("caravan")
			if caravan and is_instance_valid(caravan) and not caravan.get("is_destroyed"):
				var cur_hp: int = int(caravan.get("health"))
				var max_hp: int = int(caravan.get("MAX_HEALTH"))
				caravan.health = mini(max_hp, cur_hp + 150)
				if caravan.has_signal("health_changed"):
					caravan.health_changed.emit(caravan.health, max_hp)
				if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
					caravan.sync_caravan_state.rpc(caravan.global_position, caravan.health, caravan.is_blocked, caravan.is_destroyed, caravan.walk_phase)
			var ws = get_tree().get_first_node_in_group("wave_spawner")
			if ws and ws.has_method("reduce_threat"):
				ws.reduce_threat(25.0)
			if player and player.has_method("notify_hud"):
				player.notify_hud("🐴 ОСЁЛ НАКОРМЛЕН И ОТДОХНУЛ! (+150 HP КАРАВАНА)", Color(1.0, 0.85, 0.35))

	# Спавн золотистых искр подбора
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 18
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.2
	p.color = Color(1.0, 0.85, 0.3)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	p.restart()
	p.finished.connect(p.queue_free)

	# Скрыть подсказку взаимодействия
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_interaction_prompt"):
		hud.hide_interaction_prompt()

	queue_free()
"""
	var c_script := GDScript.new()
	c_script.source_code = script_text
	c_script.reload()
	root.set_script(c_script)

	return root
