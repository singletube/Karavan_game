extends CharacterBody3D
class_name SkullDrone

const SkullDroneModel3DClass = preload("res://scripts/skull_drone_model_3d.gd")

# --- Параметры здоровья и состояния ---
@export var max_health      : int   = 90
var health                  : int   = 90
var is_dead                 : bool  = false
var is_fleeing              : bool  = false
var is_scanning             : bool  = false
var flee_timer              : float = 0.0

# Безопасные свойства для сетевой синхронизации и проверок состояния
var attack_timer            : float = 0.0
var hurt_timer              : float = 0.0
var is_winding_up           : bool  = false
var zombie_type             : String = "drone"
var state                   : int   = 0

# --- Полет и кружение по орбите ---
var orbit_angle             : float = 0.0
var orbit_radius            : float = 13.5
var orbit_height            : float = 5.2
var orbit_speed             : float = 0.72 # Радианы в секунду (плавный облет)
var hover_time              : float = 0.0

# --- Сканирование и звуковые эффекты ---
var scan_sound_timer        : float = 0.0
var scan_check_timer        : float = 0.0

# --- Узлы модели и аудио ---
var model                   : Node3D = null
var scan_audio              : AudioStreamPlayer3D = null
var flee_audio              : AudioStreamPlayer3D = null
var hit_audio               : AudioStreamPlayer3D = null
var spawner_ref             : Node = null

func _enter_tree() -> void:
	add_to_group("Enemies")
	add_to_group("enemy")
	add_to_group("skull_drone")

func _ready() -> void:
	health = max_health
	orbit_angle = randf() * TAU
	orbit_radius = randf_range(11.5, 15.5)

	# Настройка модели
	model = get_node_or_null("SkullDroneModel3D") as Node3D
	if not model:
		model = SkullDroneModel3DClass.new()
		model.name = "SkullDroneModel3D"
		add_child(model)

	# Аудио сканирования (электронные импульсы радара)
	scan_audio = AudioStreamPlayer3D.new()
	scan_audio.name = "ScanAudio"
	scan_audio.max_distance = 38.0
	scan_audio.volume_db = -2.0
	if ResourceLoader.exists("res://assets/audio/drone_scan.wav"):
		scan_audio.stream = load("res://assets/audio/drone_scan.wav")
	add_child(scan_audio)

	# Аудио бегства при старте волны (форсаж реактивных турбин)
	flee_audio = AudioStreamPlayer3D.new()
	flee_audio.name = "FleeAudio"
	flee_audio.max_distance = 60.0
	flee_audio.volume_db = 1.0
	if ResourceLoader.exists("res://assets/audio/drone_flee.wav"):
		flee_audio.stream = load("res://assets/audio/drone_flee.wav")
	add_child(flee_audio)

	# Аудио попадания по броне
	hit_audio = AudioStreamPlayer3D.new()
	hit_audio.name = "HitAudio"
	hit_audio.max_distance = 35.0
	hit_audio.volume_db = 0.0
	if ResourceLoader.exists("res://assets/audio/reload_click.wav"):
		hit_audio.stream = load("res://assets/audio/reload_click.wav")
	add_child(hit_audio)

	_find_spawner()

func _find_spawner() -> void:
	if not get_tree():
		return
	if get_tree().current_scene:
		spawner_ref = get_tree().current_scene.find_child("WaveSpawner", true, false)
	if not spawner_ref:
		spawner_ref = get_tree().get_first_node_in_group("wave_spawner")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	hover_time += delta

	# Проверка: если началась волна врагов — дрон обязан немедленно улететь!
	if not is_fleeing and _check_should_flee():
		start_flee()

	# Режим бегства (дрон форсирует подъем в небо)
	if is_fleeing:
		_process_flee(delta)
		return

	# Нормальный режим: полет кругами вокруг каравана и игрока
	_process_orbit_and_scan(delta)

func _check_should_flee() -> bool:
	if spawner_ref and is_instance_valid(spawner_ref):
		if spawner_ref.get("wave_active") == true:
			return true
		if spawner_ref.get("current_phase") != null and int(spawner_ref.get("current_phase")) != 0: # Не CALM
			return true
	return false

func start_flee() -> void:
	if is_fleeing:
		return
	is_fleeing = true
	_set_scanning(false)

	if flee_audio and flee_audio.stream:
		flee_audio.play()

	if model:
		model.is_fleeing = true

func _process_flee(delta: float) -> void:
	flee_timer += delta
	# Ускорение вверх и вперед в открытый космос / небо
	velocity.y = lerpf(velocity.y, 28.0, delta * 3.5)
	velocity.z = lerpf(velocity.z, -14.0, delta * 2.0)
	rotation_degrees.x = lerp_angle(deg_to_rad(rotation_degrees.x), deg_to_rad(-55.0), delta * 4.0)
	move_and_slide()

	# Когда улетел высоко в облака — удаляем
	if global_position.y >= 55.0 or flee_timer >= 3.0:
		queue_free()

func _process_orbit_and_scan(delta: float) -> void:
	var caravan := _get_caravan()
	var player  := _get_player()

	# Точка притяжения: центр масс между караваном и игроком
	var center_pos := Vector3.ZERO
	if caravan and player:
		center_pos = (caravan.global_position + player.global_position) * 0.5
	elif caravan:
		center_pos = caravan.global_position
	elif player:
		center_pos = player.global_position
	else:
		center_pos = global_position

	# Кружение по плавной орбите
	orbit_angle += orbit_speed * delta
	var target_x: float = center_pos.x + cos(orbit_angle) * orbit_radius
	var target_z: float = center_pos.z + sin(orbit_angle) * orbit_radius
	var target_y: float = center_pos.y + orbit_height + sin(hover_time * 2.2) * 0.45

	var target_pos := Vector3(target_x, target_y, target_z)
	var move_dir := (target_pos - global_position)
	var dist_to_target := move_dir.length()

	# Плавное движение к точке орбиты с легким покачиванием
	var fly_speed: float = clampf(dist_to_target * 2.4, 4.0, 14.0)
	velocity = velocity.lerp(move_dir.normalized() * fly_speed, delta * 4.5)
	move_and_slide()

	# Разворот лицом к цели наблюдения (к каравану или игроку)
	var look_target := center_pos + Vector3.UP * 1.2
	var dir_to_look := (look_target - global_position).normalized()
	if dir_to_look.length_squared() > 0.001:
		var target_yaw := atan2(-dir_to_look.x, -dir_to_look.z)
		rotation.y = lerp_angle(rotation.y, target_yaw + PI, delta * 4.0)
		rotation.x = lerp_angle(rotation.x, -dir_to_look.y * 0.75, delta * 3.5)
		# Легкий крен (roll) при поворотах по орбите
		rotation.z = lerp_angle(rotation.z, -sin(orbit_angle) * 0.18, delta * 3.0)

	# Логика сканирования: если игрок или караван в зоне видимости (< 32м)
	scan_check_timer += delta
	if scan_check_timer >= 0.2:
		scan_check_timer = 0.0
		var dist_to_look: float = global_position.distance_to(center_pos)
		var can_scan: bool = dist_to_look <= 34.0 and not is_fleeing
		_set_scanning(can_scan)

	# Звуковое сопровождение активного сканирования
	if is_scanning:
		scan_sound_timer += delta
		if scan_sound_timer >= 0.85:
			scan_sound_timer = 0.0
			if scan_audio and scan_audio.stream:
				scan_audio.pitch_scale = randf_range(0.96, 1.04)
				scan_audio.play()

func _set_scanning(val: bool) -> void:
	if is_scanning == val:
		return
	is_scanning = val

	if model:
		model.is_scanning = val

	# Сообщаем спавнеру волн об ускорении таймера
	if spawner_ref and is_instance_valid(spawner_ref):
		if spawner_ref.has_method("set_skull_drone_scanning"):
			spawner_ref.set_skull_drone_scanning(val)

func _get_caravan() -> Node3D:
	return get_tree().get_first_node_in_group("caravan") as Node3D

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null

# =========================================================================
# УРОН, ХЭДШОТЫ И УНИЧТОЖЕНИЕ
# =========================================================================
func is_headshot_hit(hit_position: Vector3) -> bool:
	# Выстрел в лицо (оптический сенсор), лоб или верх черепа
	var local_hit: Vector3 = to_local(hit_position)
	if local_hit.y >= -0.05 and local_hit.z >= -0.15:
		return true
	return false

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> bool:
	if is_dead:
		return false

	var is_headshot: bool = is_headshot_hit(hit_position)
	var final_amount: int = int(round(amount * 2.5)) if is_headshot else amount

	health -= final_amount

	# Звук попадания и импульс от пули
	if hit_audio and hit_audio.stream:
		hit_audio.pitch_scale = randf_range(0.9, 1.1)
		hit_audio.play()

	if hit_direction.length_squared() > 0.01:
		velocity += hit_direction.normalized() * 0.45

	if health <= 0:
		_die(hit_direction)
	return is_headshot

func hitscan_hit(damage: float, direction: Vector3, hit_position: Vector3) -> bool:
	return take_damage(int(damage), direction, hit_position)

func _die(hit_direction: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	is_dead = true
	_set_scanning(false)

	# Снимаем ускорение с волн
	if spawner_ref and is_instance_valid(spawner_ref):
		if spawner_ref.has_method("set_skull_drone_scanning"):
			spawner_ref.set_skull_drone_scanning(false)

	# 1. Звук взрыва кибер-черепа
	if is_inside_tree() and get_tree() and get_tree().root:
		var boom_audio := AudioStreamPlayer3D.new()
		boom_audio.name = "ExplosionAudio"
		boom_audio.max_distance = 50.0
		boom_audio.volume_db = 2.0
		if ResourceLoader.exists("res://assets/audio/explosion.wav"):
			boom_audio.stream = load("res://assets/audio/explosion.wav")
		elif ResourceLoader.exists("res://assets/audio/explosion.mp3"):
			boom_audio.stream = load("res://assets/audio/explosion.mp3")
		get_tree().root.add_child(boom_audio)
		boom_audio.global_position = global_position
		boom_audio.play()
		boom_audio.finished.connect(boom_audio.queue_free)

		# 2. Эффект взрыва: искры, пламя и дым
		var p := CPUParticles3D.new()
		p.name = "DroneExplosionParticles"
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 45
		p.lifetime = 0.8
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 8.5
		p.gravity = Vector3(0.0, -8.0, 0.0)
		p.color = Color(1.0, 0.45, 0.1, 1.0)
		get_tree().root.add_child(p)
		p.global_position = global_position
		p.emitting = true
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)

	# Дрон взрывается и уничтожается (без выпадения лута)
	queue_free()
