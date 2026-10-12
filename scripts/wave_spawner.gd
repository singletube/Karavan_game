extends Node3D

# --- Константы ---
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

# --- Настройки волн ---
@export var min_spawn_dist    : float = 18.0
@export var max_spawn_dist    : float = 42.0
@export var wave_break        : float = 8.0
@export var max_alive_enemies : int   = 30

# --- Состояние спавнера ---
var current_wave       : int   = 0
var wave_active        : bool  = false
var enemies_alive      : int   = 0
var enemies_to_spawn   : Array[String] = []
var spawn_timer        : float = 0.0

var is_in_break        : bool  = false
var break_timer        : float = 0.0
var last_countdown_sec : int   = -1

# --- Контейнер для врагов ---
var enemies_container  : Node3D = null

# --- Аудио для волн ---
var snd_wave_start : AudioStream = preload("res://assets/audio/wave_start.wav")
var snd_wave_win   : AudioStream = preload("res://assets/audio/wave_win.wav")
var audio_player   : AudioStreamPlayer = null

# --- Сигналы для HUD ---
signal wave_started(wave_num: int, wave_name: String)
signal wave_completed(wave_num: int)
signal enemies_remaining(count: int)
signal wave_countdown(seconds: int)

func _ready() -> void:
	_setup_container()
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	await get_tree().process_frame
	_find_and_connect_hud()

	# Стартовая передышка перед первой волной
	_start_break(wave_break)

func _setup_container() -> void:
	var existing: Node = get_node_or_null("EnemiesContainer")
	if existing and existing is Node3D:
		enemies_container = existing as Node3D
	else:
		enemies_container = Node3D.new()
		enemies_container.name = "EnemiesContainer"
		add_child(enemies_container)

func _find_and_connect_hud() -> void:
	var hud: Node = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("connect_spawner"):
		hud.connect_spawner(self)

func _process(delta: float) -> void:
	if is_in_break:
		break_timer -= delta
		var sec_left: int = int(ceil(maxf(0.0, break_timer)))
		if sec_left != last_countdown_sec:
			last_countdown_sec = sec_left
			wave_countdown.emit(sec_left)

		if break_timer <= 0.0:
			is_in_break = false
			_start_next_wave()
		return

	if not wave_active:
		return

	if not enemies_to_spawn.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_wave_batch()

func _start_break(duration: float) -> void:
	is_in_break = true
	break_timer = duration
	last_countdown_sec = -1
	wave_countdown.emit(int(ceil(duration)))

func _start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	is_in_break = false
	spawn_timer = 0.0

	var data: Dictionary = _get_wave_composition(current_wave)
	var wave_name: String = data["name"] as String
	var list: Array[String] = (data["enemies"] as Array[String]).duplicate()
	enemies_to_spawn = list

	wave_started.emit(current_wave, wave_name)
	enemies_remaining.emit(enemies_alive + enemies_to_spawn.size())

	if audio_player and snd_wave_start:
		audio_player.stream = snd_wave_start
		audio_player.play()

func _get_wave_composition(wave_num: int) -> Dictionary:
	var w_name: String = ""
	var enemies: Array[String] = []

	match wave_num:
		1:
			w_name = "Разведка"
			for i: int in range(5):
				enemies.append("Walker")
		2:
			w_name = "Патруль"
			for i: int in range(8):
				enemies.append("Walker")
			for i: int in range(2):
				enemies.append("Runner")
			enemies.shuffle()
		3:
			w_name = "Стая"
			for i: int in range(4):
				enemies.append("Walker")
			for i: int in range(4):
				enemies.append("Runner")
			for i: int in range(2):
				enemies.append("Crawler")
			enemies.shuffle()
		4:
			w_name = "Осада"
			for i: int in range(6):
				enemies.append("Walker")
			for i: int in range(4):
				enemies.append("Runner")
			for i: int in range(2):
				enemies.append("Spitter")
			enemies.append("Brute")
			enemies.shuffle()
		5:
			w_name = "Нашествие"
			for i: int in range(8):
				enemies.append("Walker")
			for i: int in range(6):
				enemies.append("Runner")
			for i: int in range(3):
				enemies.append("Crawler")
			for i: int in range(2):
				enemies.append("Screamer")
			enemies.append("Brute")
			enemies.shuffle()
		6:
			w_name = "Ад"
			for i: int in range(10):
				enemies.append("Walker")
			for i: int in range(8):
				enemies.append("Runner")
			for i: int in range(4):
				enemies.append("Crawler")
			for i: int in range(3):
				enemies.append("Spitter")
			for i: int in range(2):
				enemies.append("Screamer")
			for i: int in range(2):
				enemies.append("Brute")
			enemies.append("Exploder")
			enemies.shuffle()
		_:
			w_name = "Бесконечность"
			enemies = _build_endless_composition(wave_num)

	return {
		"name": w_name,
		"enemies": enemies
	}

func _build_endless_composition(wave_num: int) -> Array[String]:
	# Масштабирование состава волны 6 множителем (wave - 5) * 0.5, максимум 60 врагов
	var mult: float = (float(wave_num) - 5.0) * 0.5
	var base_counts: Dictionary = {
		"Walker": 10,
		"Runner": 8,
		"Crawler": 4,
		"Spitter": 3,
		"Screamer": 2,
		"Brute": 2,
		"Exploder": 1
	}

	var scaled: Dictionary = {}
	var total_count: int = 0

	for z_type: String in base_counts:
		var c: int = int(round(float(base_counts[z_type]) * mult))
		if c < 1:
			c = 1
		scaled[z_type] = c
		total_count += c

	# Ограничение максимума в 60 врагов
	if total_count > 60:
		var ratio: float = 60.0 / float(total_count)
		var re_total: int = 0
		for z_type: String in scaled:
			var trimmed: int = int(round(float(scaled[z_type]) * ratio))
			if trimmed < 1:
				trimmed = 1
			scaled[z_type] = trimmed
			re_total += trimmed

		while re_total > 60:
			if scaled["Walker"] > 1:
				scaled["Walker"] -= 1
				re_total -= 1
			elif scaled["Runner"] > 1:
				scaled["Runner"] -= 1
				re_total -= 1
			else:
				break

	var result: Array[String] = []
	for z_type: String in scaled:
		var count: int = scaled[z_type] as int
		for i: int in range(count):
			result.append(z_type)

	result.shuffle()
	return result

func _spawn_wave_batch() -> void:
	if enemies_to_spawn.is_empty() or enemies_alive >= max_alive_enemies:
		return

	var available_slots: int = max_alive_enemies - enemies_alive
	var group_size: int = 1
	var next_delay: float = 1.0

	if current_wave == 1:
		group_size = 2
		next_delay = 1.2
	else:
		group_size = randi_range(3, 5)
		next_delay = randf_range(0.8, 1.8)

	group_size = mini(group_size, enemies_to_spawn.size())
	group_size = mini(group_size, available_slots)

	if group_size <= 0:
		return

	var center_pos: Vector3 = _get_random_spawn_point()

	for i: int in range(group_size):
		var z_type: String = enemies_to_spawn.pop_front()
		var offset: Vector3 = Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
		_spawn_single_enemy(z_type, center_pos + offset)

	spawn_timer = next_delay

func _spawn_single_enemy(z_type: String, pos: Vector3) -> void:
	var enemy: CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
	if not enemy:
		return

	# Устанавливаем тип зомби ДО добавления в дерево сцены
	enemy.zombie_type = z_type

	var spawn_pos: Vector3 = Vector3(pos.x, 0.8, pos.z)
	enemy.global_position = spawn_pos

	enemies_container.add_child(enemy)
	enemy.global_position = spawn_pos
	enemies_alive += 1

	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

func _get_random_spawn_point() -> Vector3:
	var players: Array = get_tree().get_nodes_in_group("player")
	var alive_players: Array[Node3D] = []

	for p: Node in players:
		if p is Node3D and is_instance_valid(p) and not (p.get("is_dead") == true):
			alive_players.append(p as Node3D)

	var anchor_pos: Vector3 = Vector3.ZERO
	if alive_players.size() > 0:
		var chosen_player: Node3D = alive_players[randi() % alive_players.size()]
		anchor_pos = chosen_player.global_position

	var angle: float = randf() * TAU
	var dist: float = randf_range(min_spawn_dist, max_spawn_dist)
	var spawn_x: float = anchor_pos.x + cos(angle) * dist
	var spawn_z: float = anchor_pos.z + sin(angle) * dist

	return Vector3(spawn_x, 0.8, spawn_z)

func _on_enemy_died(_enemy: Node) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	var remaining: int = enemies_alive + enemies_to_spawn.size()
	enemies_remaining.emit(remaining)

	if remaining <= 0 and wave_active:
		_complete_wave()

func _complete_wave() -> void:
	wave_active = false
	wave_completed.emit(current_wave)

	if audio_player and snd_wave_win:
		audio_player.stream = snd_wave_win
		audio_player.play()

	_start_break(wave_break)
