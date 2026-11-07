extends CharacterBody3D

# --- Сигналы ---
signal enemy_died

# --- Тип зомби ---
@export_enum("Walker", "Runner", "Brute", "Crawler", "Spitter", "Screamer", "Exploder") var zombie_type : String = "Walker":
	set(val):
		zombie_type = val
		if is_node_ready():
			_init_zombie_type()

# --- Параметры движения и боя ---
const GRAVITY       := 20.0
const CHASE_RANGE   := 150.0 # Дальний радиус обнаружения каравана для раннего марша

var move_speed      : float = 3.2
var max_hp          : int   = 75
var attack_dmg      : int   = 15
var attack_cooldown : float = 1.1
var attack_reach    : float = 2.2

# --- Обход препятствий (Obstacle Avoidance & Steering) ---
var avoidance_dir          : Vector3 = Vector3.ZERO
var avoidance_timer        : float   = 0.0
var stuck_detect_timer     : float   = 0.0
var last_check_pos         : Vector3 = Vector3.ZERO
var preferred_detour_sign  : float   = 1.0

# --- Ноды ---
@onready var sprite          : Sprite3D            = $Sprite3D
@onready var cyborg_model_3d : Node3D              = $CyborgModel3D
@onready var shape           : CollisionShape3D    = $CollisionShape3D
@onready var hit_sound       : AudioStreamPlayer3D = $HitSound
@onready var die_sound       : AudioStreamPlayer3D = $DieSound
@onready var nav_agent       : NavigationAgent3D   = $NavigationAgent3D

# --- Звуки зомби ---
var snd_groan    : AudioStream = preload("res://assets/audio/zombie_groan.wav")
var snd_screamer : AudioStream = preload("res://assets/audio/zombie_screamer.wav")
var snd_acid     : AudioStream = preload("res://assets/audio/zombie_acid.wav")
var snd_bite     : AudioStream = preload("res://assets/audio/zombie_bite.wav")
var snd_die      : AudioStream = preload("res://assets/audio/zombie_die.wav")
var snd_exp      : AudioStream = preload("res://assets/audio/explosion.mp3")

# --- Кадры спрайт-листа (10 кадров) ---
const FRAME_IDLE       := 0
const FRAMES_WALK      := [1, 2, 3, 4]
const FRAMES_ATTACK    := [5, 6]
const FRAME_HURT       := 7
const FRAME_DIE1       := 8
const FRAME_DEAD       := 9

# --- Состояние ---
var health          := 75
var attack_timer    : float = 0.4 # Небольшая начальная пауза перед первой атакой
var is_winding_up   : bool  = false
var hurt_timer      := 0.0
var walk_timer      := 0.0
var walk_frame_i    := 0
var is_dead         := false
var player          : Node3D = null

# --- Сетевая интерполяция для клиентов ---
var target_pos      : Vector3 = Vector3.ZERO
var target_rot_y    : float = 0.0
var remote_spd      : float = 0.0
var remote_is_atk   : bool = false
var remote_is_hurt  : bool = false
var remote_windup   : bool = false

enum EnemyState { IDLE, CHASE, ATTACK, DEAD }
var state : EnemyState = EnemyState.IDLE

func net_sync(pos: Vector3, rot_y: float, spd: float, is_atk: bool, is_hurt: bool, windup: bool = false) -> void:
	target_pos = pos
	target_rot_y = rot_y
	remote_spd = spd
	remote_is_atk = is_atk
	remote_is_hurt = is_hurt
	remote_windup = windup

func _ready() -> void:
	if cyborg_model_3d:
		cyborg_model_3d.hide()
	_init_zombie_type()

	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 0.01
	sprite.hframes = 10
	sprite.vframes = 1
	sprite.frame = FRAME_IDLE
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD

	if nav_agent and not nav_agent.velocity_computed.is_connected(_on_velocity_computed):
		nav_agent.velocity_computed.connect(_on_velocity_computed)
	if die_sound:
		die_sound.stream = snd_die
	if hit_sound:
		hit_sound.stream = snd_bite

func _init_zombie_type() -> void:
	if cyborg_model_3d:
		cyborg_model_3d.setup_type(zombie_type)
		cyborg_model_3d.show()
	if sprite:
		sprite.hide()

	match zombie_type:
		"Runner":
			move_speed = 5.6
			max_hp = 45
			attack_dmg = 10
			attack_cooldown = 0.65
			attack_reach = 2.0
			scale = Vector3(0.88, 0.88, 0.88)

		"Brute":
			move_speed = 1.8
			max_hp = 220
			attack_dmg = 35
			attack_cooldown = 1.6
			attack_reach = 2.6
			scale = Vector3(1.35, 1.35, 1.35)

		"Crawler":
			move_speed = 2.4
			max_hp = 55
			attack_dmg = 12
			attack_cooldown = 0.8
			attack_reach = 1.8
			scale = Vector3(0.75, 0.75, 0.75)

		"Spitter":
			move_speed = 2.0
			max_hp = 65
			attack_dmg = 20
			attack_cooldown = 2.5
			attack_reach = 15.0
			scale = Vector3(1.0, 1.0, 1.0)

		"Screamer":
			move_speed = 3.5
			max_hp = 40
			attack_dmg = 8
			attack_cooldown = 3.0
			attack_reach = 8.0
			scale = Vector3(1.1, 1.1, 1.1)

		"Exploder":
			move_speed = 4.2
			max_hp = 50
			attack_dmg = 80
			attack_cooldown = 999.0
			attack_reach = 2.5
			scale = Vector3(1.15, 1.15, 1.15)

		_: # Walker (Штурмовой Киборг)
			move_speed = 3.2
			max_hp = 75
			attack_dmg = 15
			attack_cooldown = 1.1
			attack_reach = 2.2
			scale = Vector3(1.0, 1.0, 1.0)

	health = max_hp

func _physics_process(delta: float) -> void:
	if is_dead:
		if cyborg_model_3d and cyborg_model_3d.visible:
			cyborg_model_3d.update_animation(delta, false, 0.0, false, false, true)
		return

	# На клиентах мультиплеера врагами управляет сервер (интерполяция)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if target_pos != Vector3.ZERO:
			global_position = global_position.lerp(target_pos, minf(delta * 16.0, 1.0))
			rotation.y = lerp_angle(rotation.y, target_rot_y, minf(delta * 16.0, 1.0))

		if cyborg_model_3d and cyborg_model_3d.visible:
			cyborg_model_3d.update_animation(delta, remote_spd > 0.1, remote_spd, remote_is_atk, remote_is_hurt, false, remote_windup)

		return

	# Кулдаун удара плавно тикает каждый кадр независимо от состояния (бег/замах/покой)
	if attack_timer > 0.0:
		attack_timer = maxf(0.0, attack_timer - delta)

	_apply_gravity(delta)
	_update_target_and_state()
	_process_movement_and_animation(delta)

	# Поворот 3D модели по направлению движения / цели
	if cyborg_model_3d and cyborg_model_3d.visible:
		var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
		var is_moving: bool = (state == EnemyState.CHASE and horizontal_speed > 0.1)
		var is_atk: bool = (state == EnemyState.ATTACK and (is_winding_up or attack_timer > 0.0))
		var is_hurting: bool = (hurt_timer > 0.0)
		cyborg_model_3d.update_animation(delta, is_moving, horizontal_speed, is_atk, is_hurting, false, is_winding_up)

		var move_dir := velocity
		move_dir.y = 0.0
		if move_dir.length_squared() > 0.15:
			var look_pos: Vector3 = global_position + move_dir.normalized()
			cyborg_model_3d.look_at(look_pos, Vector3.UP)
			cyborg_model_3d.rotate_y(PI) # Разворот лицом вперед
		elif player:
			var look_pos: Vector3 = Vector3(player.global_position.x, global_position.y, player.global_position.z)
			if global_position.distance_squared_to(look_pos) > 0.05:
				cyborg_model_3d.look_at(look_pos, Vector3.UP)
				cyborg_model_3d.rotate_y(PI)

	move_and_slide()

	# Реакция на соприкосновения с препятствиями (баррикады, обломки, скалы): скольжение вокруг
	if state == EnemyState.CHASE and is_on_wall():
		var col_count := get_slide_collision_count()
		for i in range(col_count):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider == player:
				continue
			if collider is Node and ((collider as Node).is_in_group("player") or (collider as Node).is_in_group("caravan")):
				continue
			var n := col.get_normal()
			if n.y > 0.55:
				continue
			n.y = 0.0
			if n.length_squared() > 0.01:
				n = n.normalized()
				var direct := (player.global_position - global_position) if player else -n
				direct.y = 0.0
				var t1 := Vector3(-n.z, 0.0, n.x).normalized()
				var t2 := -t1
				var best_t := t1 if t1.dot(direct) >= t2.dot(direct) else t2
				avoidance_dir = (best_t * 0.85 + n * 0.20).normalized()
				avoidance_timer = 0.75
				break

	# Детекция застревания на месте: если зомби в погоне, но за 0.4с сдвинулся меньше 15см
	if state == EnemyState.CHASE:
		stuck_detect_timer += delta
		if stuck_detect_timer >= 0.4:
			stuck_detect_timer = 0.0
			var dist_moved := global_position.distance_to(last_check_pos)
			last_check_pos = global_position
			if dist_moved < 0.15:
				preferred_detour_sign = -preferred_detour_sign
				if player:
					var direct := (player.global_position - global_position)
					direct.y = 0.0
					if direct.length_squared() > 0.01:
						avoidance_dir = direct.normalized().rotated(Vector3.UP, deg_to_rad(75.0 * preferred_detour_sign))
				avoidance_timer = 0.95

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _update_target_and_state() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	var closest: Node3D = null
	var min_dist: float = INF

	for p in players:
		if p is Node3D and is_instance_valid(p) and not (p.get("is_dead") == true):
			var d: float = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p

	# Если враги ближе к каравану, чем к игроку — они атакуют караван
	var caravans: Array = get_tree().get_nodes_in_group("caravan")
	for c in caravans:
		if c is Node3D and is_instance_valid(c) and not (c.get("is_destroyed") == true):
			var d: float = global_position.distance_to((c as Node3D).global_position)
			if d < min_dist:
				min_dist = d
				closest = c as Node3D

	player = closest
	if not player:
		state = EnemyState.IDLE
		is_winding_up = false
		return

	var is_caravan: bool = player.is_in_group("caravan")
	var reach_threshold: float = attack_reach + (2.2 if is_caravan else 0.0)
	if min_dist <= reach_threshold:
		state = EnemyState.ATTACK
	elif min_dist <= CHASE_RANGE:
		state = EnemyState.CHASE
		is_winding_up = false
	else:
		state = EnemyState.IDLE
		is_winding_up = false

func _get_attack_cooldown(is_caravan: bool) -> float:
	if is_caravan:
		# Ощутимый честный кулдаун удара по каравану, чтобы враги не ломали повозку за секунду
		match zombie_type:
			"Runner":
				return 1.5
			"Crawler":
				return 1.6
			"Brute":
				return 2.5
			"Spitter":
				return 3.0
			"Screamer":
				return 3.5
			"Exploder":
				return 999.0
			_: # Walker
				return 1.8
	return attack_cooldown

func _process_movement_and_animation(delta: float) -> void:
	if hurt_timer > 0.0:
		hurt_timer -= delta
		sprite.frame = FRAME_HURT
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 3.0 * delta)
		return

	match state:
		EnemyState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
			sprite.frame = FRAME_IDLE

		EnemyState.CHASE:
			var dir := Vector3.ZERO
			if player and is_instance_valid(player):
				var direct: Vector3 = (player.global_position - global_position)
				direct.y = 0.0
				if direct.length_squared() > 0.05:
					dir = direct.normalized()

			# Проактивный обход препятствий щупами-лучами
			dir = _compute_avoidance_steering(dir, delta)

			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

			# Скорость анимации зависит от скорости бега
			var step_interval: float = 0.18
			match zombie_type:
				"Runner":
					step_interval = 0.12
				"Brute":
					step_interval = 0.22
				"Crawler":
					step_interval = 0.20
				"Spitter":
					step_interval = 0.20
				"Screamer":
					step_interval = 0.14
				"Exploder":
					step_interval = 0.10
				_:
					step_interval = 0.18
			walk_timer += delta
			if walk_timer >= step_interval:
				walk_timer = 0.0
				walk_frame_i = (walk_frame_i + 1) % FRAMES_WALK.size()
				sprite.frame = FRAMES_WALK[walk_frame_i]

		EnemyState.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)

			var is_caravan: bool = (player != null and is_instance_valid(player) and player.is_in_group("caravan"))

			if attack_timer <= 0.0:
				if not is_winding_up:
					# Замах перед ударом (0.35с) — анимация замаха перед нанесением урона
					is_winding_up = true
					attack_timer = 0.35
				else:
					# Нанесение удара и запуск полного честного кулдауна
					is_winding_up = false
					_do_attack()
					attack_timer = _get_attack_cooldown(is_caravan)

			if is_winding_up:
				sprite.frame = FRAMES_ATTACK[0]
			else:
				sprite.frame = FRAMES_ATTACK[1]

# Проактивный обход препятствий щупами-лучами (Raycast Obstacle Avoidance)
func _compute_avoidance_steering(base_dir: Vector3, delta: float) -> Vector3:
	if not player or not is_instance_valid(player) or base_dir.length_squared() < 0.01:
		return base_dir

	# 1. Если активен временный маневр обхода препятствия:
	if avoidance_timer > 0.0:
		avoidance_timer -= delta
		if avoidance_dir.length_squared() > 0.01:
			return (avoidance_dir * 0.75 + base_dir * 0.25).normalized()

	# 2. Детекция препятствий лучами-щупами (Feelers)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if not space:
		return base_dir

	var origin := global_position + Vector3(0.0, 0.7, 0.0)

	# Проверка центрального луча (на 2.8м вперед)
	var center_end := origin + base_dir * 2.8
	var query_center := PhysicsRayQueryParameters3D.create(origin, center_end)
	query_center.exclude = [get_rid()]
	var hit_center := space.intersect_ray(query_center)

	if hit_center and not hit_center.is_empty():
		var col_obj = hit_center.get("collider")
		var is_target: bool = (col_obj == player)
		if not is_target and col_obj is Node:
			var node := col_obj as Node
			if node.is_in_group("player") or node.is_in_group("caravan"):
				is_target = true

		# Препятствие на пути (скала, баррикада, обломок, стена)
		if not is_target:
			var left_vec := base_dir.rotated(Vector3.UP, deg_to_rad(40.0))
			var right_vec := base_dir.rotated(Vector3.UP, deg_to_rad(-40.0))

			var q_left := PhysicsRayQueryParameters3D.create(origin, origin + left_vec * 2.2)
			q_left.exclude = [get_rid()]
			var hit_left := space.intersect_ray(q_left)

			var q_right := PhysicsRayQueryParameters3D.create(origin, origin + right_vec * 2.2)
			q_right.exclude = [get_rid()]
			var hit_right := space.intersect_ray(q_right)

			var left_free: bool = hit_left.is_empty()
			var right_free: bool = hit_right.is_empty()

			if left_free and not right_free:
				avoidance_dir = base_dir.rotated(Vector3.UP, deg_to_rad(55.0))
				avoidance_timer = 0.65
				preferred_detour_sign = -1.0
			elif right_free and not left_free:
				avoidance_dir = base_dir.rotated(Vector3.UP, deg_to_rad(-55.0))
				avoidance_timer = 0.65
				preferred_detour_sign = 1.0
			else:
				var norm: Vector3 = hit_center.get("normal", Vector3.ZERO)
				norm.y = 0.0
				if norm.length_squared() > 0.01:
					norm = norm.normalized()
					var t1 := Vector3(-norm.z, 0.0, norm.x).normalized()
					var t2 := -t1
					var best_t := t1 if t1.dot(base_dir) >= t2.dot(base_dir) else t2
					avoidance_dir = (best_t * 0.85 + norm * 0.25).normalized()
					avoidance_timer = 0.75
				else:
					avoidance_dir = base_dir.rotated(Vector3.UP, deg_to_rad(60.0 * preferred_detour_sign))
					avoidance_timer = 0.65

			return (avoidance_dir * 0.8 + base_dir * 0.2).normalized()

	return base_dir

func _on_velocity_computed(safe_vel: Vector3) -> void:
	if not is_dead and hurt_timer <= 0.0:
		velocity.x = safe_vel.x
		velocity.z = safe_vel.z

func _do_attack() -> void:
	match zombie_type:
		"Spitter":
			_attack_spitter()
		"Screamer":
			_attack_screamer()
		"Exploder":
			_attack_exploder()
		_:
			_attack_melee()

func _attack_melee() -> void:
	if hit_sound:
		hit_sound.stream = snd_bite
		hit_sound.play()
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var reach_bonus: float = 2.4 if player.is_in_group("caravan") else 0.6
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= attack_reach + reach_bonus:
			player.take_damage(attack_dmg)

func _attack_spitter() -> void:
	# Дальняя атака ядом: не нужно подходить вплотную
	if hit_sound:
		hit_sound.stream = snd_acid
		hit_sound.play()
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var reach_bonus: float = 3.5 if player.is_in_group("caravan") else 2.0
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= attack_reach + reach_bonus:
			player.take_damage(attack_dmg)

func _attack_screamer() -> void:
	# АОЕ звуковая волна: урон всем игрокам и каравану в радиусе досягаемости
	if hit_sound:
		hit_sound.stream = snd_screamer
		hit_sound.play()
	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node3D and is_instance_valid(p) and not (p.get("is_dead") == true):
			var dist: float = global_position.distance_to((p as Node3D).global_position)
			if dist <= attack_reach:
				if p.has_method("take_damage"):
					p.take_damage(attack_dmg)

	var caravans: Array = get_tree().get_nodes_in_group("caravan")
	for c: Node in caravans:
		if c is Node3D and is_instance_valid(c) and not (c.get("is_destroyed") == true):
			var dist: float = global_position.distance_to((c as Node3D).global_position)
			if dist <= attack_reach + 2.0:
				if c.has_method("take_damage"):
					c.take_damage(attack_dmg)

func _get_sand_fx() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/SandEffects")

func _attack_exploder() -> void:
	# Самоубийственный взрыв: наносит урон всем игрокам, каравану и другим зомби в радиусе 6.0, затем погибает
	if die_sound:
		die_sound.stream = snd_exp
		die_sound.play()
	var exp_radius: float = 6.0
	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node3D and is_instance_valid(p) and not (p.get("is_dead") == true):
			var dist: float = global_position.distance_to((p as Node3D).global_position)
			if dist <= exp_radius:
				if p.has_method("take_damage"):
					p.take_damage(attack_dmg)

	var caravans: Array = get_tree().get_nodes_in_group("caravan")
	for c: Node in caravans:
		if c is Node3D and is_instance_valid(c) and not (c.get("is_destroyed") == true):
			var dist: float = global_position.distance_to((c as Node3D).global_position)
			if dist <= exp_radius + 1.5:
				if c.has_method("take_damage"):
					c.take_damage(attack_dmg)

	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e: Node in enemies:
		if e != self and e is Node3D and is_instance_valid(e) and not (e.get("is_dead") == true):
			var dist: float = global_position.distance_to((e as Node3D).global_position)
			if dist <= exp_radius:
				if e.has_method("take_damage"):
					e.take_damage(attack_dmg)

	var s_fx := _get_sand_fx()
	if s_fx:
		s_fx.add_explosion_crater(global_position)
	_die()

func is_headshot_hit(hit_pos: Vector3) -> bool:
	if hit_pos == Vector3.ZERO:
		return false

	var sc_y: float = maxf(0.1, scale.y)
	var sc_xz: float = maxf(0.1, (scale.x + scale.z) * 0.5)

	# 1. Проверяем точное расстояние до кости Head скелета (радиус черепа ~18 см, исключая грудь на 34 см ниже)
	if is_inside_tree() and cyborg_model_3d and cyborg_model_3d.visible:
		var skel: Skeleton3D = cyborg_model_3d.find_child("GeneralSkeleton", true, false) as Skeleton3D
		if not skel:
			skel = cyborg_model_3d.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel and skel.is_inside_tree():
			var head_idx := skel.find_bone("Head")
			if head_idx != -1:
				var head_world_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(head_idx).origin
				var dist_to_head := hit_pos.distance_to(head_world_pos)
				# Череп киборга компактный: радиус 0.19м и точка выше подбородка/шеи (выше 1.60м)
				if dist_to_head <= 0.19 * sc_y and hit_pos.y >= (head_world_pos.y - 0.12 * sc_y):
					return true

	# 2. Геометрическая высота: строго зона черепа выше шеи (от 1.58м) в пределах ширины головы (0.22м)
	var local_y: float = (hit_pos.y - global_position.y) / sc_y
	if local_y >= 1.58:
		var horiz_dist := Vector2(hit_pos.x - global_position.x, hit_pos.z - global_position.z).length() / sc_xz
		if horiz_dist <= 0.22:
			return true

	return false

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> bool:
	if is_dead:
		return false

	var is_headshot := is_headshot_hit(hit_position)
	var final_amount: int = int(round(amount * 2.5)) if is_headshot else amount

	# Если урон нанес клиент в мультиплеере, перенаправляем запрос на авторитетный сервер
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "request_take_damage", final_amount, hit_direction, hit_position, is_headshot)
		_play_hit_flinch(hit_direction, hit_position, is_headshot)
		return is_headshot

	health -= final_amount
	_play_hit_flinch(hit_direction, hit_position, is_headshot)

	if health <= 0:
		_die()
		if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc("sync_die", hit_direction)
	else:
		if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc("sync_hurt", hit_direction, hit_position, is_headshot)

	return is_headshot

@rpc("any_peer", "reliable")
func request_take_damage(amount: int, hit_direction: Vector3, hit_position: Vector3, is_headshot: bool = false) -> void:
	if multiplayer.is_server():
		take_damage(amount, hit_direction, hit_position)

@rpc("authority", "reliable")
func sync_die(hit_direction: Vector3) -> void:
	if not is_dead:
		if hit_direction.length_squared() > 0.01:
			velocity += hit_direction.normalized() * 5.5
		_die()

@rpc("authority", "unreliable")
func sync_hurt(hit_direction: Vector3, hit_position: Vector3, is_headshot: bool = false) -> void:
	if not is_dead:
		_play_hit_flinch(hit_direction, hit_position, is_headshot)

func _play_hit_flinch(hit_direction: Vector3, hit_position: Vector3, is_headshot: bool = false) -> void:
	hurt_timer = 0.32 if is_headshot else 0.22
	if sprite:
		sprite.frame = FRAME_HURT
		var hit_tween: Tween = create_tween().set_parallel(true)
		var flash_color := Color(3.5, 1.8, 0.4, 1.0) if is_headshot else Color(2.5, 0.4, 0.3, 1.0)
		sprite.modulate = flash_color
		hit_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
		var punch_scale := Vector3(1.35, 0.75, 1.35) if is_headshot else Vector3(1.22, 0.82, 1.22)
		sprite.scale = punch_scale
		hit_tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Кинетический отброс (Knockback) назад
	var knock_force: float = 8.5 if is_headshot else 5.5
	if hit_direction.length_squared() > 0.01:
		velocity += hit_direction.normalized() * knock_force
	elif player:
		var away: Vector3 = (global_position - player.global_position).normalized()
		away.y = 0.0
		velocity += away * (knock_force * 0.9)

	# Кровь и искры в точке попадания
	var blood_position := hit_position
	if blood_position == Vector3.ZERO:
		blood_position = global_position + Vector3(0.0, 1.4 if is_headshot else 0.9, 0.0)

	if is_headshot:
		_spawn_headshot_blood(blood_position, hit_direction)
	else:
		_spawn_hit_blood(blood_position, hit_direction)

	var s_fx := _get_sand_fx()
	if s_fx:
		s_fx.add_blood_splatter(global_position, hit_direction)

	if hit_sound and not hit_sound.playing:
		hit_sound.play()

func hitscan_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> bool:
	return take_damage(int(damage), hit_direction, hit_position)

func projectile_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> bool:
	return take_damage(int(damage), hit_direction, hit_position)

func _spawn_headshot_blood(pos: Vector3, hit_direction: Vector3) -> void:
	if not is_inside_tree() or not get_tree() or not get_parent():
		return
	_spawn_hit_blood(pos, hit_direction)
	var p := CPUParticles3D.new()
	p.name = "HeadshotSparks"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 28
	p.lifetime = 0.5
	p.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var spray_direction := Vector3.UP
	if hit_direction.length_squared() > 0.01:
		spray_direction += -hit_direction.normalized() * 0.6
	p.direction = spray_direction.normalized()
	p.spread = 55.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.color = Color(1.0, 0.85, 0.25, 1.0)
	p.scale_amount_min = 1.8
	p.scale_amount_max = 3.0

	var spark_material := StandardMaterial3D.new()
	spark_material.albedo_color = Color(1.0, 0.9, 0.3, 1.0)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.8, 0.2, 1.0)
	spark_material.emission_energy_multiplier = 4.0

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.025
	spark_mesh.height = 0.05
	spark_mesh.material = spark_material
	p.mesh = spark_mesh

	get_parent().add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true
	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _spawn_hit_blood(pos: Vector3, hit_direction: Vector3) -> void:
	if not is_inside_tree() or not get_tree() or not get_parent():
		return
	var p := CPUParticles3D.new()
	p.name = "HitBlood"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var spray_direction := Vector3.UP
	if hit_direction.length_squared() > 0.01:
		spray_direction += -hit_direction.normalized() * 0.55
	p.direction = spray_direction.normalized()
	p.spread = 38.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0.0, -10.0, 0.0)
	p.color = Color(0.8, 0.015, 0.035, 1.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color(0.8, 0.015, 0.035, 1.0)
	droplet_material.roughness = 0.35
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.03
	droplet_mesh.height = 0.06
	droplet_mesh.material = droplet_material
	# CPUParticles3D uses `mesh`; `draw_pass_1` belongs to GPUParticles3D.
	p.mesh = droplet_mesh
	get_parent().add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true
	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = EnemyState.DEAD
	velocity = Vector3.ZERO
	shape.disabled = true

	if cyborg_model_3d and cyborg_model_3d.visible:
		cyborg_model_3d.update_animation(0.0, false, 0.0, false, false, true)

	enemy_died.emit()

	# Растекающаяся лужа крови под телом поверженного киборга
	var pool_scale: float = 2.4 if zombie_type == "Brute" else 1.65
	var s_fx := _get_sand_fx()
	if s_fx:
		s_fx.add_blood_pool(global_position, pool_scale)

	if die_sound:
		die_sound.play()

	sprite.frame = FRAME_DIE1
	await get_tree().create_timer(0.35).timeout
	sprite.frame = FRAME_DEAD

	await get_tree().create_timer(15.0).timeout
	var fade_tween: Tween = create_tween().set_parallel(true)
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	if cyborg_model_3d and cyborg_model_3d.visible:
		fade_tween.tween_property(cyborg_model_3d, "scale", Vector3.ZERO, 2.0)
	await fade_tween.finished
	queue_free()
