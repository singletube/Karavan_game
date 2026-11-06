extends Node3D

# --- Константы ---
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const SKULL_DRONE_SCENE: PackedScene = preload("res://scenes/skull_drone.tscn")

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
var wave_active_timer     : float = 0.0 # Таймер длительности волны/засады для защиты от зависаний
var is_in_break           : bool  = false
var is_camp_paused        : bool  = false
var break_timer           : float = 0.0
var scout_timer           : float = 0.0
var march_encounter_timer : float = 6.5 # Первое появление врагов вдали через 6.5 сек
var straggler_cleanup_timer: float = 0.0 # Таймер очистки отставших далеко позади врагов
var hud_update_timer      : float = 0.0
var last_countdown_sec    : int   = -1
var enemies_alive         : int   = 0
var enemies_to_spawn      : Array[String] = []
var spawn_timer           : float = 0.0

# --- Дрон-череп (Skull Drone) ---
var is_skull_drone_scanning: bool  = false
var skull_drone_spawn_timer: float = 22.0 # Появление первого дрона-разведчика через 22 сек спокойного пути

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

	# Плавный сбалансированный старт: враги покажутся вдалеке через 6.5 сек
	is_in_break = false
	threat_level = 0.0
	march_encounter_timer = 6.5

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

	var caravan := _get_caravan()
	var dist_traveled: float = 0.0
	var is_moving: bool = false
	var is_boosted: bool = false
	if caravan and is_instance_valid(caravan):
		dist_traveled = absf(caravan.global_position.z)
		is_moving = not caravan.get("is_destroyed") and not caravan.get("is_blocked")
		is_boosted = caravan.get("is_boosted") == true

	# Уровень сложности (Tier) растет каждые 240 метров вглубь пустыни (сбалансированная прогрессия)
	var new_tier: int = maxi(1, 1 + int(dist_traveled / 240.0))
	difficulty_tier = new_tier

	# --- БЕЗУСЛОВНАЯ ОЧИСТКА ОТСТАВШИХ ЗОМБИ (каждые 1.5с) ---
	# Работает ВСЕГДА (и во время волн, и на марше), чтобы враги не застревали позади и не зависали волны!
	straggler_cleanup_timer += delta
	if straggler_cleanup_timer >= 1.5:
		straggler_cleanup_timer = 0.0
		_cleanup_stragglers(caravan)

	# 1. Период передышки после отбитого штурма (если дрон сканирует — таймер идет вдвое быстрее)
	if is_in_break:
		var break_speed: float = 2.0 if is_skull_drone_scanning else 1.0
		break_timer -= delta * break_speed
		var sec_left: int = int(ceil(maxf(0.0, break_timer)))
		if sec_left != last_countdown_sec:
			last_countdown_sec = sec_left
			wave_countdown.emit(sec_left)
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				sync_wave_countdown.rpc(sec_left)

		if break_timer <= 0.0:
			is_in_break = false
			threat_level = 10.0
			_notify_hud_threat()
		return

	# 2. Боевой режим (засада или штурм активны)
	if wave_active:
		wave_active_timer += delta
		if not enemies_to_spawn.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_wave_batch()
		# Автоматическое завершение волны, если все враги убиты или волна затянулась (>30с)
		elif enemies_alive <= 0 or wave_active_timer >= 32.0 or (wave_active_timer >= 16.0 and enemies_alive <= 1):
			_complete_assault()
		return

	# 3. Режим исследования и движения каравана: умеренное комфортное накопление угрозы
	# (При активном сканировании дроном-черепом скорость приближения волны удваивается x2)
	var drone_mult: float = 2.0 if is_skull_drone_scanning else 1.0
	var growth_rate: float = 0.85 if difficulty_tier == 1 else (1.20 + float(difficulty_tier) * 0.45)
	if dist_traveled >= 450.0 and dist_traveled <= 1100.0:
		growth_rate *= 1.30 # Красный каньон
	elif dist_traveled > 1100.0:
		growth_rate *= 1.60 # Выжженная кибер-пустошь

	# Скорость роста угрозы
	var threat_mult: float = (1.1 if difficulty_tier == 1 else 2.0) * drone_mult
	if not is_moving:
		threat_mult *= 0.35
	elif is_boosted:
		threat_mult *= 2.6

	threat_level = minf(100.0, threat_level + delta * growth_rate * threat_mult)

	# Периодическое обновление статуса на HUD
	hud_update_timer += delta
	if hud_update_timer >= 1.0:
		hud_update_timer = 0.0
		_notify_hud_threat()

	# --- СТОЛКНОВЕНИЯ НА МАРШЕ ---
	# До 5 врагов на 1 этапе, 9 на 2 этапе, до 14 со 3 этапа
	var max_march_enemies: int = 5 if difficulty_tier == 1 else (9 if difficulty_tier == 2 else 14)
	if is_moving and enemies_alive < max_march_enemies:
		march_encounter_timer -= delta * drone_mult
		if march_encounter_timer <= 0.0:
			var next_interval: float = randf_range(6.5, 10.5) if difficulty_tier == 1 else randf_range(4.5, 7.5)
			if is_boosted:
				next_interval = maxf(2.5, next_interval * 0.55)
			march_encounter_timer = next_interval
			_spawn_march_encounter(caravan, is_boosted)

	# --- ПЕРИОДИЧЕСКИЙ СПАВН ДРОНА-ЧЕРЕПА (ПОКА НЕТ ВОЛНЫ) ---
	_process_skull_drone_spawning(delta, caravan)

	# Одиночные разведчики (только со 2 этапа)
	if difficulty_tier >= 2:
		scout_timer += delta
		if scout_timer >= 14.0 and threat_level < 60.0 and enemies_alive < 3:
			scout_timer = 0.0
			_spawn_scout_ambush()

	# Фланговая засада при накоплении угрозы (на 1 этапе — только при 75%, со 2 этапа — при 55%)
	var ambush_thresh: float = 75.0 if difficulty_tier == 1 else 55.0
	if threat_level >= ambush_thresh and current_phase == ThreatPhase.CALM and enemies_alive < 3:
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

# Выбор типа врага в зависимости от глубины и биома
func _pick_enemy_for_tier() -> String:
	var roll := randf()
	match difficulty_tier:
		1:
			# На 1 этапе преимущественно Walker (80%) и 20% Runner
			return "Runner" if roll < 0.20 else "Walker"
		2:
			# Со 2 этапа подключаются Runner, ползуны (Crawler) и редкие Brute
			if roll < 0.15: return "Crawler"
			elif roll < 0.45: return "Runner"
			elif roll < 0.55: return "Brute"
			else: return "Walker"
		3:
			if roll < 0.20: return "Spitter"
			elif roll < 0.40: return "Brute"
			elif roll < 0.65: return "Runner"
			elif roll < 0.85: return "Crawler"
			else: return "Screamer"
		_:
			if roll < 0.20: return "Screamer"
			elif roll < 0.40: return "Exploder"
			elif roll < 0.60: return "Brute"
			elif roll < 0.80: return "Spitter"
			else: return "Runner"

# Регулярный спавн столкновений прямо ВПЕРЕДИ по курсу движения каравана
func _spawn_march_encounter(caravan: Node3D, boosted: bool) -> void:
	if not caravan or not is_instance_valid(caravan):
		return
	var c_pos := caravan.global_position
	# Спавним ЗАРАНЕЕ и ПОДАЛЬШЕ ВПЕРЕДИ (60-95м, при ускорении 90-140м)
	var spawn_dist_ahead: float = randf_range(90.0, 140.0) if boosted else randf_range(60.0, 95.0)
	var pack_size: int = randi_range(1, 2) if difficulty_tier == 1 else (randi_range(2, 3) if difficulty_tier == 2 else randi_range(3, 5))

	var center_x := randf_range(-14.0, 14.0)
	var center_z := c_pos.z - spawn_dist_ahead

	for i in range(pack_size):
		var offset_x := randf_range(-4.0, 4.0)
		var offset_z := randf_range(-4.0, 4.0)
		var ex := center_x + offset_x
		var ez := center_z + offset_z
		var ey := DesertGenerator.get_height(ex, ez) + 0.8

		var z_type := _pick_enemy_for_tier()
		_spawn_single_enemy(z_type, Vector3(ex, ey, ez))

# Очистка зомби, отставших далеко позади каравана (караван ушел вперед по -Z)
func _cleanup_stragglers(caravan: Node3D) -> void:
	if not caravan or not is_instance_valid(caravan) or not enemies_container:
		return
	var c_pos := caravan.global_position
	var players := get_tree().get_nodes_in_group("player")

	for child: Node in enemies_container.get_children():
		if child is Node3D and is_instance_valid(child):
			var e_pos := (child as Node3D).global_position
			# 1. Если враг остался далеко позади каравана (> 85м по Z)
			# 2. Или если враг ушел/застрял в стороне (> 135м от каравана)
			var is_behind: bool = (e_pos.z > c_pos.z + 85.0)
			var is_too_far: bool = (e_pos.distance_to(c_pos) > 135.0)
			if is_behind or is_too_far:
				var near_player := false
				for p in players:
					if p is Node3D and is_instance_valid(p):
						if e_pos.distance_to((p as Node3D).global_position) < 24.0:
							near_player = true
							break
				if not near_player:
					child.queue_free()
					enemies_alive = maxi(0, enemies_alive - 1)

# Одиночный разведчик на барханах (Scout) - появляется далеко в поле видимости
func _spawn_scout_ambush() -> void:
	var z_type := _pick_enemy_for_tier()
	var caravan := _get_caravan()
	var base_pos: Vector3 = caravan.global_position if (caravan and is_instance_valid(caravan)) else Vector3.ZERO
	var side_x: float = (randf_range(16.0, 26.0)) * (1.0 if randf() < 0.5 else -1.0)
	# Далеко впереди каравана
	var spawn_z: float = base_pos.z - randf_range(50.0, 80.0)
	var spawn_y: float = DesertGenerator.get_height(base_pos.x + side_x, spawn_z) + 0.8
	_spawn_single_enemy(z_type, Vector3(base_pos.x + side_x, spawn_y, spawn_z))

# -------------------------------------------------------------------------
# ФЛАНГОВАЯ ЗАСАДА (FLANK AMBUSH)
# -------------------------------------------------------------------------
func _trigger_flank_ambush() -> void:
	_dismiss_skull_drones()
	current_phase = ThreatPhase.AMBUSH
	wave_active = true
	wave_active_timer = 0.0
	spawn_timer = 0.0

	var count: int = 1 if difficulty_tier == 1 else (2 if difficulty_tier == 2 else randi_range(2, 3))
	enemies_to_spawn.clear()
	for i in range(count):
		enemies_to_spawn.append(_pick_enemy_for_tier())

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
	_dismiss_skull_drones()
	current_phase = ThreatPhase.ASSAULT
	assault_number += 1
	wave_active = true
	wave_active_timer = 0.0
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
		1: # 0 - 360m: Развед-отряд (мягкий вводный этап)
			for i in range(3): list.append("Walker")
			list.append("Runner")
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
	wave_active_timer = 0.0
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

	# Спавн нападающих с дюн ВПЕРЕДИ по курсу движения каравана (караван идет в сторону -Z)
	var caravan := _get_caravan()
	var base_z: float = caravan.global_position.z if (caravan and is_instance_valid(caravan)) else 0.0
	var side_sign: float = 1.0 if randf() < 0.5 else -1.0
	var flank_x: float = (randf_range(12.0, 24.0)) * side_sign
	var spawn_ahead_z: float = base_z - randf_range(48.0, 75.0)

	for i in range(group_size):
		var z_type: String = enemies_to_spawn.pop_front()
		var ex: float = flank_x + randf_range(-3.0, 3.0)
		var ez: float = spawn_ahead_z + randf_range(-3.0, 3.0)
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
			if child.is_in_group("skull_drone"):
				continue
			var atk_t: float = float(child.get("attack_timer")) if child.get("attack_timer") != null else 0.0
			var hurt_t: float = float(child.get("hurt_timer")) if child.get("hurt_timer") != null else 0.0
			var is_atk: bool = (child.get("state") == 2 and (child.get("is_winding_up") == true or atk_t > 0.0))
			var is_hurt: bool = (hurt_t > 0.0)
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
	_dismiss_skull_drones()
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

# =========================================================================
# МЕХАНИКА ДРОНА-ЧЕРЕПА (SKULL DRONE SCOUT)
# =========================================================================
func _process_skull_drone_spawning(delta: float, caravan: Node3D) -> void:
	if wave_active or is_in_break or is_camp_paused:
		return

	var drones := get_tree().get_nodes_in_group("skull_drone")
	if drones.is_empty():
		skull_drone_spawn_timer -= delta
		if skull_drone_spawn_timer <= 0.0:
			skull_drone_spawn_timer = randf_range(38.0, 58.0)
			_spawn_skull_drone(caravan)
	else:
		skull_drone_spawn_timer = randf_range(38.0, 58.0)

func _spawn_skull_drone(caravan: Node3D) -> void:
	if not SKULL_DRONE_SCENE:
		return
	var drone = SKULL_DRONE_SCENE.instantiate() as Node3D
	if not drone:
		return

	var center := caravan.global_position if (caravan and is_instance_valid(caravan)) else global_position
	var angle := randf() * TAU
	var spawn_dist := randf_range(28.0, 40.0)
	var spawn_pos := center + Vector3(cos(angle) * spawn_dist, randf_range(9.0, 14.0), sin(angle) * spawn_dist)
	drone.global_position = spawn_pos

	add_child(drone)

func set_skull_drone_scanning(val: bool) -> void:
	if is_skull_drone_scanning == val:
		return
	is_skull_drone_scanning = val
	_notify_hud_scanning_status(val)

func _notify_hud_scanning_status(val: bool) -> void:
	if not is_inside_tree() or not get_tree() or not get_tree().current_scene:
		return
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("set_skull_drone_scanning"):
		hud.set_skull_drone_scanning(val)

func _dismiss_skull_drones() -> void:
	is_skull_drone_scanning = false
	_notify_hud_scanning_status(false)
	var drones := get_tree().get_nodes_in_group("skull_drone")
	for d in drones:
		if is_instance_valid(d) and d.has_method("start_flee"):
			d.start_flee()
