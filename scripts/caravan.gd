extends AnimatableBody3D

class_name Caravan

# --- Константы и настройки ---
const MAX_HEALTH: int = 500 # В 5 раз больше здоровья игрока (100 HP)
const BASE_SPEED: float = 2.25 # 1/4 скорости ходьбы игрока (9.0 / 4)

signal health_changed(current: int, max_hp: int)
signal caravan_destroyed
signal caravan_respawned
signal caravan_blocked_status(blocked: bool, reason: String)

@export var move_speed: float = BASE_SPEED
@export var move_direction: Vector3 = Vector3(0.0, 0.0, -1.0) # Идет вперед вглубь пустыни

var health: int = MAX_HEALTH
var is_destroyed: bool = false
var is_blocked: bool = false
var walk_phase: float = 0.0

var track_dist: float = 0.0
var wheel_dust_timer: float = 0.0
var last_hoof_cycle: int = -1

var _net_sync_timer: float = 0.0
var _remote_target_pos: Vector3 = Vector3.ZERO
var _has_remote_target: bool = false
var _hit_grace_timer: float = 0.0
const MIN_DAMAGE_INTERVAL: float = 0.18 # Кулдаун между тиками урона от толпы

@onready var model: CaravanModel3D = $CaravanModel3D
@onready var hit_sound: AudioStreamPlayer3D = $HitSound
@onready var break_sound: AudioStreamPlayer3D = $BreakSound

var snd_wood_hit: AudioStream = preload("res://assets/audio/shoot_revolver.mp3")

func _enter_tree() -> void:
	add_to_group("caravan")

func _ready() -> void:
	sync_to_physics = false
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

	if hit_sound and snd_wood_hit:
		hit_sound.stream = snd_wood_hit

func _physics_process(delta: float) -> void:
	if _hit_grace_timer > 0.0:
		_hit_grace_timer = maxf(0.0, _hit_grace_timer - delta)

	# Если мы клиент в мультиплеере — интерполируем к координатам сервера
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if _has_remote_target:
			var prev_pos := global_position
			global_position = global_position.lerp(_remote_target_pos, delta * 14.0)
			var moved_dist: float = global_position.distance_to(prev_pos)
			var is_moving: bool = (not is_destroyed and not is_blocked)

			if is_moving:
				walk_phase += delta * (move_speed * 1.5)
				track_dist += moved_dist
				if track_dist >= 0.85:
					track_dist = 0.0
					SandEffects.add_caravan_wheel_tracks(global_position, move_direction)

			var client_front_h := DesertGenerator.get_height(global_position.x, global_position.z - 2.5)
			var client_back_h := DesertGenerator.get_height(global_position.x, global_position.z + 2.5)
			var client_pitch := atan2(client_back_h - client_front_h, 5.0)
			rotation.x = lerp_angle(rotation.x, client_pitch, delta * 6.0)

			if model:
				model.update_animation(delta, is_moving, move_speed if is_moving else 0.0, walk_phase)
		return

	var was_blocked := is_blocked
	is_blocked = _check_road_obstacles()
	if is_blocked != was_blocked:
		caravan_blocked_status.emit(is_blocked, "ДОРОГА ЗАБЛОКИРОВАНА!" if is_blocked else "")

	# Сетевая синхронизация состояния каравана (10 раз в сек)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_sync_timer += delta
		if _net_sync_timer >= 0.1:
			_net_sync_timer = 0.0
			sync_caravan_state.rpc(global_position, health, is_blocked, is_destroyed, walk_phase)

	if is_destroyed or is_blocked:
		if model:
			model.update_animation(delta, false, 0.0, walk_phase)
		return

	var step := move_direction.normalized() * (move_speed * delta)
	global_position += step

	# Следование рельефу песчаных дюн (высота и наклон повозки)
	var target_y := DesertGenerator.get_height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, target_y, delta * 12.0)

	var front_h := DesertGenerator.get_height(global_position.x, global_position.z - 2.5)
	var back_h := DesertGenerator.get_height(global_position.x, global_position.z + 2.5)
	var target_pitch := atan2(back_h - front_h, 5.0)
	rotation.x = lerp_angle(rotation.x, target_pitch, delta * 6.0)

	walk_phase += delta * (move_speed * 1.5)

	# 1. Следы колес повозки на песке (каждые 0.85м пути)
	track_dist += move_speed * delta
	if track_dist >= 0.85:
		track_dist = 0.0
		SandEffects.add_caravan_wheel_tracks(global_position, move_direction)

	# 2. Клубы пыли из-под катящихся по песку колес
	wheel_dust_timer += delta
	if wheel_dust_timer >= 0.35:
		wheel_dust_timer = 0.0
		var right := move_direction.normalized().cross(Vector3.UP).normalized()
		SandEffects.spawn_dust_puff(global_position - right * 1.18 + Vector3(0.0, 0.05, 1.2), 0.45)
		SandEffects.spawn_dust_puff(global_position + right * 1.18 + Vector3(0.0, 0.05, 1.2), 0.45)

	# 3. Следы копыт осла при шаге
	var hoof_cycle: int = int(floor((walk_phase * 4.0) / PI))
	if hoof_cycle != last_hoof_cycle:
		last_hoof_cycle = hoof_cycle
		var is_pair_a := (hoof_cycle % 2 == 0)
		if is_pair_a:
			var fl_pos: Vector3 = global_transform * Vector3(-0.24, 0.0, -4.68)
			var br_pos: Vector3 = global_transform * Vector3(0.24, 0.0, -3.72)
			SandEffects.add_hoofprint(fl_pos, move_direction)
			SandEffects.add_hoofprint(br_pos, move_direction)
			SandEffects.spawn_dust_puff(fl_pos, 0.35)
		else:
			var fr_pos: Vector3 = global_transform * Vector3(0.24, 0.0, -4.68)
			var bl_pos: Vector3 = global_transform * Vector3(-0.24, 0.0, -3.72)
			SandEffects.add_hoofprint(fr_pos, move_direction)
			SandEffects.add_hoofprint(bl_pos, move_direction)
			SandEffects.spawn_dust_puff(fr_pos, 0.35)

	if model:
		model.update_animation(delta, true, move_speed, walk_phase)


func _check_road_obstacles() -> bool:
	var obstacles := get_tree().get_nodes_in_group("road_obstacle")
	if obstacles.is_empty():
		return false

	var fwd := move_direction.normalized()
	for obs in obstacles:
		if is_instance_valid(obs) and obs is Node3D:
			var to_obs: Vector3 = (obs as Node3D).global_position - global_position
			var forward_dist: float = to_obs.dot(fwd)
			# Препятствие на расстоянии от 2.0 до 8.5м впереди и в пределах ширины дороги (< 3.8м)
			if forward_dist > 2.0 and forward_dist < 8.5:
				var side_dist: float = (to_obs - fwd * forward_dist).length()
				if side_dist < 3.8:
					return true
	return false

# Возвращает позицию спавна внутри кузова повозки (для игрока)
func get_cargo_spawn_position() -> Vector3:
	return global_transform * Vector3(0.0, 1.15, 0.3)

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "request_caravan_damage", amount, hit_direction, hit_position)
		return

	# Защита от спама одновременных тиков урона от толпы
	if _hit_grace_timer > 0.0:
		return
	_hit_grace_timer = MIN_DAMAGE_INTERVAL

	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)

	_spawn_wood_splinters(hit_position if hit_position != Vector3.ZERO else global_position + Vector3(0.0, 1.0, 0.0), hit_direction)

	if hit_sound and not hit_sound.playing:
		hit_sound.pitch_scale = randf_range(0.65, 0.85)
		hit_sound.play()

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_caravan_state.rpc(global_position, health, is_blocked, is_destroyed, walk_phase)

	if health <= 0:
		_on_caravan_destroyed()

@rpc("any_peer", "reliable")
func request_caravan_damage(amount: int, hit_direction: Vector3, hit_position: Vector3) -> void:
	if multiplayer.is_server():
		take_damage(amount, hit_direction, hit_position)

func hitscan_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage), hit_direction, hit_position)

func projectile_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage), hit_direction, hit_position)

func _spawn_wood_splinters(pos: Vector3, hit_direction: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "WoodSplinters"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 16
	p.lifetime = 0.6
	p.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))

	var spray_dir := Vector3.UP
	if hit_direction.length_squared() > 0.01:
		spray_dir += -hit_direction.normalized() * 0.6
	p.direction = spray_dir.normalized()
	p.spread = 45.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var splinter_mat := StandardMaterial3D.new()
	splinter_mat.albedo_color = Color(0.55, 0.38, 0.22, 1.0)
	splinter_mat.roughness = 0.9

	var splinter_mesh := BoxMesh.new()
	splinter_mesh.size = Vector3(0.05, 0.05, 0.12)
	splinter_mesh.material = splinter_mat
	p.mesh = splinter_mesh

	get_parent().add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true

	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _on_caravan_destroyed() -> void:
	is_destroyed = true
	caravan_destroyed.emit()

	# 1. Убиваем игроков
	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if is_instance_valid(p) and p.has_method("take_damage"):
			p.take_damage(9999)

	# 2. Сбрасываем игру до волны 0
	var spawner: Node = get_tree().current_scene.get_node_or_null("WaveSpawner")
	if spawner and spawner.has_method("reset_to_wave_zero"):
		spawner.reset_to_wave_zero()

	# 3. Через 3 секунды восстанавливаем караван и респавним игрока в кузове
	await get_tree().create_timer(3.0).timeout
	health = MAX_HEALTH
	is_destroyed = false
	health_changed.emit(health, MAX_HEALTH)
	caravan_respawned.emit()

# --- СЕТЕВАЯ СИНХРОНИЗАЦИЯ КАРАВАНА ---
func send_full_sync_to_peer(peer_id: int) -> void:
	rpc_id(peer_id, "sync_full_caravan_state", global_position, health, is_blocked, is_destroyed, walk_phase)

@rpc("authority", "reliable")
func sync_full_caravan_state(pos: Vector3, hp: int, blocked: bool, destroyed: bool, s_walk_phase: float = 0.0) -> void:
	global_position = pos
	_remote_target_pos = pos
	_has_remote_target = true
	walk_phase = s_walk_phase
	health = hp
	health_changed.emit(health, MAX_HEALTH)
	if is_blocked != blocked:
		is_blocked = blocked
		caravan_blocked_status.emit(is_blocked, "ДОРОГА ЗАБЛОКИРОВАНА!" if is_blocked else "")
	is_destroyed = destroyed

@rpc("authority", "unreliable")
func sync_caravan_state(pos: Vector3, hp: int, blocked: bool, destroyed: bool, s_walk_phase: float = 0.0) -> void:
	if multiplayer.is_server():
		return
	_remote_target_pos = pos
	_has_remote_target = true
	if absf(walk_phase - s_walk_phase) > 1.2:
		walk_phase = s_walk_phase
	if health != hp:
		health = hp
		health_changed.emit(health, MAX_HEALTH)
	if is_blocked != blocked:
		is_blocked = blocked
		caravan_blocked_status.emit(is_blocked, "ДОРОГА ЗАБЛОКИРОВАНА!" if is_blocked else "")
	if is_destroyed != destroyed:
		is_destroyed = destroyed
		if is_destroyed:
			caravan_destroyed.emit()
		else:
			caravan_respawned.emit()
