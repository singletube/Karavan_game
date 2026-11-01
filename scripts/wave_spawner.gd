extends Node3D

# --- Константы ---
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

# --- Настройки штурмов и спавна ---
@export var min_spawn_dist    : float = 18.0
@export var max_spawn_dist    : float = 40.0
@export var assault_break     : float = 24.0 # Передышка между штурмами (сек)
@export var max_alive_enemies : int   = 32

# --- Динамическая система угрозы и прогрессии сложности ---
# Угроза Роя (Threat Meter): от 0% до 100%
var threat_level          : float = 0.0
var difficulty_tier       : int   = 1
var assault_number        : int   = 0

# Состояния боевой обстановки (Combat Alert Phases):
# 0: CALM (Затишье, накопление угрозы, редкие разведчики)
# 1: AMBUSH (Тактическая засада с флангов)
# 2: ASSAULT (Массированный скоординированный штурм каравана)
enum ThreatPhase { CALM, AMBUSH, ASSAULT }
var current_phase: ThreatPhase = ThreatPhase.CALM

var wave_active           : bool  = false
var is_in_break           : bool  = false
var is_camp_paused        : bool  = false
var break_timer           : float = 0.0
var scout_timer           : float = 0.0
var hud_update_timer      : float = 0.0
var last_countdown_sec    : int   = -1
var enemies_alive         : int   = 0
var enemies_to_spawn      : Array[String] = []
var spawn_timer           : float = 0.0

# --- Контейнер для врагов ---
var enemies_container     : Node3D = null

# --- Аудио для штурмов ---
var snd_wave_start : AudioStream = preload("res://assets/audio/wave_start.wav")
var snd_wave_win   : AudioStream = preload("res://assets/audio/wave_win.wav")
var audio_player   : AudioStreamPlayer = null

# --- Сигналы для HUD ---
signal wave_started(wave_num: int, wave_name: String)
signal wave_completed(wave_num: int)
signal enemies_remaining(count: int)
signal wave_countdown(seconds: int)

func _ready() -> void:
	add_to_group("wave_spawner")
	_setup_container()
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	await get_tree().process_frame
	_find_and_connect_hud()

	# Начальная передышка перед первой активностью в пустоши
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_start_break(assault_break)

func _setup_container() -> void:
	var existing: Node = get_node_or_null("EnemiesContainer")
	if existing and existing is Node3D:
		enemies_container = existing as Node3D
	else:
		enemies_container = Node3D.new()
		enemies_container.name = "EnemiesContainer"
		add_child(enemies_container)

func _find_and_connect_hud() -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	var hud: Node = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("connect_spawner"):
		hud.connect_spawner(self)

func _get_caravan() -> Node3D:
	return get_tree().get_first_node_in_group("caravan") as Node3D

func _process(delta: float) -> void:
	# На клиенте логикой спавна и фаз управляет хост/сервер
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if is_camp_paused:
		threat_level = 0.0
		return

	# 1. Период передышки после отбитого штурма
	if is_in_break:
		break_timer -= delta
		var sec_left: int = int(ceil(maxf(0.0, break_timer)))
		if sec_left != last_countdown_sec:
			last_countdown_sec = sec_left
			wave_countdown.emit(sec_left)
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				sync_wave_countdown.rpc(sec_left)

		if break_timer <= 0.0:
			is_in_break = false
			threat_level = 12.0
			_notify_hud_threat()
		return

	# 2. Боевой режим (засада или штурм активны)
	if wave_active:
		if not enemies_to_spawn.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_wave_batch()
		elif enemies_alive <= 0:
			# Все нападающие ликвидированы!
			_complete_assault()
		return

	# 3. Режим исследования и движения каравана: накопление угрозы и прогрессия
	var caravan := _get_caravan()
	var dist_traveled: float = 0.0
	if caravan and is_instance_valid(caravan):
		dist_traveled = absf(caravan.global_position.z)

	# Уровень сложности (Tier) растет каждые 360 метров вглубь пустыни
	var new_tier: int = maxi(1, 1 + int(dist_traveled / 360.0))
	difficulty_tier = new_tier

	# Накопление шкалы Угрозы Роя
	var growth_rate: float = 1.0 + float(difficulty_tier) * 0.25
	# В Красном Каньоне и Токсичной Пустоши угроза нарастает быстрее
	if dist_traveled >= 550.0 and dist_traveled <= 1250.0:
		growth_rate *= 1.30 # Красный каньон
	elif dist_traveled > 1250.0 and dist_traveled <= 1850.0:
		growth_rate *= 1.60 # Токсичная кибер-пустошь

	threat_level = minf(100.0, threat_level + delta * growth_rate * 0.6)

	# Периодическое обновление статуса на HUD
	hud_update_timer += delta
	if hud_update_timer >= 1.0:
		hud_update_timer = 0.0
		_notify_hud_threat()

	# Одиночные разведчики во время затишья (Scouts)
	scout_timer += delta
	if scout_timer >= 20.0 and threat_level < 60.0 and enemies_alive < 3:
		scout_timer = 0.0
		_spawn_scout_ambush()

	# Фланговая засада при накоплении 55% угрозы
	if threat_level >= 55.0 and current_phase == ThreatPhase.CALM and enemies_alive < 2:
		_trigger_flank_ambush()

	# Полномасштабный штурм каравана при 100% угрозе
	elif threat_level >= 100.0:
		_trigger_full_assault()

func _notify_hud_threat() -> void:
	var caravan := _get_caravan()
	var dist: int = int(absf(caravan.global_position.z)) if (caravan and is_instance_valid(caravan)) else 0
	var status_text: String = "УГРОЗА РОЯ: %d%% · ЭТАП %d" % [int(threat_level), difficulty_tier]
	var sub_text: String = "Караван в пути (%dм). Следите за барханами" % dist
	wave_started.emit(difficulty_tier, status_text)
	enemies_remaining.emit(enemies_alive)

func reduce_threat(amount: float) -> void:
	threat_level = maxf(0.0, threat_level - amount)
	_notify_hud_threat()

func _start_break(duration: float) -> void:
	is_in_break = true
	break_timer = duration
	last_countdown_sec = -1
	current_phase = ThreatPhase.CALM
	var sec: int = int(ceil(duration))
	wave_countdown.emit(sec)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_wave_countdown.rpc(sec)

# Одиночный разведчик на барханах (Scout)
func _spawn_scout_ambush() -> void:
	var z_type := "Runner" if randf() < 0.65 else "Walker"
	var caravan := _get_caravan()
	var base_pos: Vector3 = caravan.global_position if (caravan and is_instance_valid(caravan)) else Vector3.ZERO
	var side_x: float = (randf_range(18.0, 30.0)) * (1.0 if randf() < 0.5 else -1.0)
	var spawn_z: float = base_pos.z + randf_range(-15.0, 15.0)
	var spawn_y: float = DesertGenerator.get_height(base_pos.x + side_x, spawn_z) + 0.8
	_spawn_single_enemy(z_type, Vector3(base_pos.x + side_x, spawn_y, spawn_z))

# -------------------------------------------------------------------------
# ФЛАНГОВАЯ ЗАСАДА (FLANK AMBUSH)
# -------------------------------------------------------------------------
func _trigger_flank_ambush() -> void:
	current_phase = ThreatPhase.AMBUSH
	wave_active = true
	spawn_timer = 0.0

	var count: int = randi_range(2, 4)
	enemies_to_spawn.clear()
	for i in range(count):
		if difficulty_tier >= 2 and randf() < 0.45:
			enemies_to_spawn.append("Crawler")
		elif randf() < 0.5:
			enemies_to_spawn.append("Runner")
		else:
			enemies_to_spawn.append("Walker")

	var rem: int = enemies_alive + enemies_to_spawn.size()
	var title := "⚠️ ВНИМАНИЕ: ЗАСАДА НА ФЛАНГАХ!"
	wave_started.emit(difficulty_tier, title)
	enemies_remaining.emit(rem)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_wave_started.rpc(difficulty_tier, title, rem)

	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(true)

# -------------------------------------------------------------------------
# ПОЛНОМАСШТАБНЫЙ ШТУРМ КАРАВАНА (FULL ASSAULT HORDE)
# -------------------------------------------------------------------------
func _trigger_full_assault() -> void:
	current_phase = ThreatPhase.ASSAULT
	assault_number += 1
	wave_active = true
	threat_level = 100.0
	spawn_timer = 0.0

	var caravan := _get_caravan()
	var dist: float = absf(caravan.global_position.z) if (caravan and is_instance_valid(caravan)) else 0.0

	var enemies: Array[String] = _build_assault_roster(difficulty_tier, dist)
	enemies_to_spawn = enemies

	var rem: int = enemies_alive + enemies_to_spawn.size()
	var wave_title := "ШТУРМ КАРАВАНА: ЭТАП %d" % assault_number
	wave_started.emit(assault_number, wave_title)
	enemies_remaining.emit(rem)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_wave_started.rpc(assault_number, wave_title, rem)

	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(true)

	if audio_player and snd_wave_start:
		audio_player.stream = snd_wave_start
		audio_player.play()

# Построение прогрессирующего состава штурмовой группы
func _build_assault_roster(tier: int, dist_z: float) -> Array[String]:
	var list: Array[String] = []

	match tier:
		1: # 0 - 360m: Развед-отряд
			for i in range(5): list.append("Walker")
			for i in range(2): list.append("Runner")
		2: # 360 - 720m (перед лагерем #1): Налет стаи
			for i in range(6): list.append("Walker")
			for i in range(4): list.append("Runner")
			for i in range(2): list.append("Crawler")
		3: # 720 - 1080m (Красный каньон): Осада с артиллерией
			for i in range(6): list.append("Walker")
			for i in range(4): list.append("Runner")
			for i in range(3): list.append("Crawler")
			list.append("Spitter")
			list.append("Brute")
		4: # 1080 - 1440m (Глубины каньона / перед лагерем #2): Тяжелый штурм
			for i in range(8): list.append("Walker")
			for i in range(5): list.append("Runner")
			for i in range(3): list.append("Crawler")
			for i in range(2): list.append("Spitter")
			list.append("Brute")
		5: # 1440 - 1800m (Токсичная пустошь): Кибер-нашествие
			for i in range(8): list.append("Walker")
			for i in range(6): list.append("Runner")
			for i in range(4): list.append("Crawler")
			for i in range(2): list.append("Spitter")
			for i in range(2): list.append("Screamer")
			list.append("Brute")
			list.append("Exploder")
		_: # 1800m+: Бесконечная нарастающая сложность
			var mult: float = 1.0 + float(tier - 5) * 0.35
			var counts := {
				"Walker": int(round(8 * mult)),
				"Runner": int(round(6 * mult)),
				"Crawler": int(round(4 * mult)),
				"Spitter": int(round(2 * mult)),
				"Screamer": int(round(2 * mult)),
				"Brute": int(round(1 * mult)),
				"Exploder": int(round(1 * mult))
			}
			for z_type: String in counts:
				for i in range(mini(12, counts[z_type])):
					list.append(z_type)

	list.shuffle()
	return list

# -------------------------------------------------------------------------
# СТРАЖИ ПОДЗЕМЕЛИЙ И РАЗВАЛИН (DUNGEON GUARDIANS)
# -------------------------------------------------------------------------
func spawn_dungeon_guardians(poi_node: Node, poi_type: String, world_pos: Vector3) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var guard_types: Array[String] = []
		match poi_type:
			"bunker_ruins":
				guard_types = ["Brute", "Walker", "Runner"]
			"ancient_ruins":
				guard_types = ["Runner", "Runner", "Walker"]
			"plane_wreck":
				guard_types = ["Crawler", "Runner"]
			"clay_ruins":
				guard_types = ["Crawler", "Walker"]
			_:
				guard_types = ["Walker", "Runner"]

		for i in range(guard_types.size()):
			var z_type: String = guard_types[i]
			var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
			var g_pos := world_pos + offset
			g_pos.y = DesertGenerator.get_height(g_pos.x, g_pos.z) + 0.8
			_spawn_single_enemy(z_type, g_pos, "Guardian_%s_%d" % [poi_type, _next_enemy_id()])

func _complete_assault() -> void:
	wave_active = false
	current_phase = ThreatPhase.CALM
	threat_level = 10.0 # Сброс угрозы на базовый уровень после отбитого штурма

	wave_completed.emit(assault_number)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_wave_completed.rpc(assault_number)

	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(false)

	if audio_player and snd_wave_win:
		audio_player.stream = snd_wave_win
		audio_player.play()

	_start_break(assault_break)

func _spawn_wave_batch() -> void:
	if enemies_to_spawn.is_empty() or enemies_alive >= max_alive_enemies:
		return

	var available_slots: int = max_alive_enemies - enemies_alive
	var group_size: int = mini(randi_range(2, 4), enemies_to_spawn.size())
	group_size = mini(group_size, available_slots)
	if group_size <= 0:
		return

	# Фланговый спавн с барханов слева или справа от тракта
	var caravan := _get_caravan()
	var base_z: float = caravan.global_position.z if (caravan and is_instance_valid(caravan)) else 0.0
	var side_sign: float = 1.0 if randf() < 0.5 else -1.0
	var flank_x: float = (randf_range(min_spawn_dist, max_spawn_dist)) * side_sign

	for i in range(group_size):
		var z_type: String = enemies_to_spawn.pop_front()
		var ex: float = flank_x + randf_range(-3.0, 3.0)
		var ez: float = base_z + randf_range(-14.0, 14.0)
		var ey: float = DesertGenerator.get_height(ex, ez) + 0.8
		_spawn_single_enemy(z_type, Vector3(ex, ey, ez))

	spawn_timer = randf_range(1.0, 2.2)

var _enemy_id_counter: int = 0
var _enemy_sync_timer: float = 0.0
const ENEMY_SYNC_INTERVAL: float = 0.05

func _next_enemy_id() -> int:
	_enemy_id_counter += 1
	return _enemy_id_counter

func _physics_process(delta: float) -> void:
	# На сервере периодически транслируем позиции и анимацию врагов клиентам
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_enemy_sync_timer += delta
		if _enemy_sync_timer >= ENEMY_SYNC_INTERVAL:
			_enemy_sync_timer = 0.0
			_broadcast_enemies_batch()

func _broadcast_enemies_batch() -> void:
	if not enemies_container:
		return
	var batch: Array = []
	for child in enemies_container.get_children():
		if is_instance_valid(child) and child is CharacterBody3D and not child.get("is_dead"):
			var is_atk: bool = (child.get("state") == 2 and (child.get("is_winding_up") == true or child.get("attack_timer") > 0.0))
			var is_hurt: bool = (child.get("hurt_timer") > 0.0)
			batch.append([
				child.name,
				child.global_position,
				child.rotation.y,
				child.velocity.length(),
				is_atk,
				is_hurt
			])
	if not batch.is_empty():
		sync_enemies_batch.rpc(batch)

@rpc("authority", "unreliable")
func sync_enemies_batch(batch: Array) -> void:
	if not enemies_container:
		return
	for item in batch:
		var e_name: String = item[0]
		var e_node: Node = enemies_container.get_node_or_null(e_name)
		if e_node and is_instance_valid(e_node) and e_node.has_method("net_sync"):
			e_node.net_sync(item[1], item[2], item[3], item[4], item[5])

func _spawn_single_enemy(z_type: String, pos: Vector3, custom_name: String = "") -> void:
	var enemy: CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
	if not enemy:
		return

	if custom_name.is_empty():
		enemy.name = "Enemy_%d" % _next_enemy_id()
	else:
		enemy.name = custom_name

	enemy.zombie_type = z_type

	var spawn_y: float = DesertGenerator.get_height(pos.x, pos.z) + 0.8
	var spawn_pos: Vector3 = Vector3(pos.x, spawn_y, pos.z)

	enemies_container.add_child(enemy)
	enemy.global_position = spawn_pos
	enemies_alive += 1

	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_spawn_enemy.rpc(enemy.name, z_type, spawn_pos)

@rpc("authority", "reliable")
func sync_spawn_enemy(e_name: String, z_type: String, spawn_pos: Vector3) -> void:
	if enemies_container == null:
		_setup_container()
	if enemies_container.has_node(e_name):
		return
	var enemy: CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
	if not enemy:
		return
	enemy.name = e_name
	enemy.zombie_type = z_type
	enemy.global_position = spawn_pos
	enemies_container.add_child(enemy)
	enemy.global_position = spawn_pos
	enemies_alive += 1
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

func _on_enemy_died(_enemy: Node) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	var remaining: int = enemies_alive + enemies_to_spawn.size()
	enemies_remaining.emit(remaining)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_enemies_remaining.rpc(remaining)

	if remaining <= 0 and wave_active:
		_complete_assault()

func set_camp_peaceful_zone(in_camp: bool) -> void:
	is_camp_paused = in_camp
	if in_camp:
		threat_level = 0.0
		current_phase = ThreatPhase.CALM
		if enemies_container:
			for child: Node in enemies_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		enemies_alive = 0
		enemies_to_spawn.clear()
		wave_active = false
		enemies_remaining.emit(0)
		if has_node("/root/MusicManager"):
			get_node("/root/MusicManager").set_combat_mode(false)
		wave_started.emit(difficulty_tier, "БЕЗОПАСНАЯ ЗОНА: АВАНПОСТ ВЫЖИВШИХ")
	else:
		# При выходе из лагеря даем короткую передышку перед новым этапом
		threat_level = 0.0
		_start_break(12.0)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_camp_peaceful_zone.rpc(in_camp)

@rpc("authority", "reliable")
func sync_camp_peaceful_zone(in_camp: bool) -> void:
	is_camp_paused = in_camp
	if in_camp:
		threat_level = 0.0
		current_phase = ThreatPhase.CALM
		wave_started.emit(difficulty_tier, "БЕЗОПАСНАЯ ЗОНА: АВАНПОСТ ВЫЖИВШИХ")
		if has_node("/root/MusicManager"):
			get_node("/root/MusicManager").set_combat_mode(false)

func reset_to_wave_zero() -> void:
	wave_active = false
	is_in_break = false
	threat_level = 0.0
	current_phase = ThreatPhase.CALM
	enemies_to_spawn.clear()
	if enemies_container:
		for child: Node in enemies_container.get_children():
			child.queue_free()
	enemies_alive = 0
	assault_number = 0
	enemies_remaining.emit(0)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_reset_to_wave_zero.rpc()

	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(false)

	_start_break(assault_break)

# --- СЕТЕВАЯ СИНХРОНИЗАЦИЯ ---
func send_full_sync_to_peer(peer_id: int) -> void:
	var rem: int = enemies_alive + enemies_to_spawn.size()
	rpc_id(peer_id, "sync_full_spawner_state", assault_number, wave_active, is_in_break, int(ceil(maxf(0.0, break_timer))), rem, is_camp_paused, threat_level)

	var existing_enemies: Array = []
	if enemies_container:
		for child in enemies_container.get_children():
			if is_instance_valid(child) and child is CharacterBody3D and not child.get("is_dead"):
				existing_enemies.append({
					"name": child.name,
					"type": child.get("zombie_type"),
					"pos": child.global_position,
					"rot_y": child.rotation.y,
					"hp": child.get("health")
				})
	rpc_id(peer_id, "sync_all_existing_enemies", existing_enemies)

@rpc("authority", "reliable")
func sync_all_existing_enemies(enemies_list: Array) -> void:
	if enemies_container == null:
		_setup_container()
	for data in enemies_list:
		var e_name: String = str(data.get("name", ""))
		if e_name.is_empty() or enemies_container.has_node(e_name):
			continue
		var z_type: String = str(data.get("type", "Walker"))
		var spawn_pos: Vector3 = data.get("pos", Vector3.ZERO)
		var enemy: CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
		if not enemy:
			continue
		enemy.name = e_name
		enemy.zombie_type = z_type
		enemy.global_position = spawn_pos
		enemy.rotation.y = float(data.get("rot_y", 0.0))
		if data.has("hp"):
			enemy.health = int(data["hp"])
		enemies_container.add_child(enemy)
		enemy.global_position = spawn_pos
		enemies_alive += 1
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

@rpc("authority", "reliable")
func sync_full_spawner_state(w_num: int, is_active: bool, in_break: bool, break_sec: int, rem: int, s_camp_paused: bool = false, s_threat: float = 0.0) -> void:
	assault_number = w_num
	wave_active = is_active
	is_in_break = in_break
	is_camp_paused = s_camp_paused
	threat_level = s_threat
	if is_camp_paused:
		wave_started.emit(difficulty_tier, "БЕЗОПАСНАЯ ЗОНА: АВАНПОСТ ВЫЖИВШИХ")
		if has_node("/root/MusicManager"):
			get_node("/root/MusicManager").set_combat_mode(false)
	elif is_in_break:
		wave_countdown.emit(break_sec)
	elif wave_active:
		wave_started.emit(assault_number, "ШТУРМ КАРАВАНА #%d" % assault_number)
		enemies_remaining.emit(rem)
		if has_node("/root/MusicManager"):
			get_node("/root/MusicManager").set_combat_mode(true)

@rpc("authority", "reliable")
func sync_wave_started(w_num: int, w_name: String, rem: int) -> void:
	assault_number = w_num
	wave_active = true
	is_in_break = false
	wave_started.emit(w_num, w_name)
	enemies_remaining.emit(rem)
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(true)
	if audio_player and snd_wave_start:
		audio_player.stream = snd_wave_start
		audio_player.play()

@rpc("authority", "reliable")
func sync_wave_completed(w_num: int) -> void:
	wave_active = false
	current_phase = ThreatPhase.CALM
	wave_completed.emit(w_num)
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_combat_mode(false)
	if audio_player and snd_wave_win:
		audio_player.stream = snd_wave_win
		audio_player.play()

@rpc("authority", "unreliable")
func sync_enemies_remaining(count: int) -> void:
	enemies_remaining.emit(count)

@rpc("authority", "unreliable")
func sync_wave_countdown(seconds: int) -> void:
	wave_countdown.emit(seconds)

@rpc("authority", "reliable")
func sync_reset_to_wave_zero() -> void:
	reset_to_wave_zero()
