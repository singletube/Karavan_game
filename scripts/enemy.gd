extends CharacterBody3D

# --- Сигналы ---
signal enemy_died

# --- Тип зомби ---
@export_enum("Walker", "Runner", "Brute", "Crawler", "Spitter", "Screamer", "Exploder") var zombie_type : String = "Walker"

# --- Параметры движения и боя ---
const GRAVITY       := 20.0
const CHASE_RANGE   := 90.0

var move_speed      : float = 3.2
var max_hp          : int   = 75
var attack_dmg      : int   = 15
var attack_cooldown : float = 1.1
var attack_reach    : float = 2.2

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
var health       := 75
var attack_timer := 0.0
var hurt_timer   := 0.0
var walk_timer   := 0.0
var walk_frame_i := 0
var is_dead      := false
var player       : Node3D = null

enum EnemyState { IDLE, CHASE, ATTACK, DEAD }
var state : EnemyState = EnemyState.IDLE

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

	nav_agent.velocity_computed.connect(_on_velocity_computed)
	if die_sound:
		die_sound.stream = snd_die
	if hit_sound:
		hit_sound.stream = snd_bite

func _init_zombie_type() -> void:
	if cyborg_model_3d:
		cyborg_model_3d.setup_type(zombie_type)
		cyborg_model_3d.show()
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

	_apply_gravity(delta)
	_update_target_and_state()
	_process_movement_and_animation(delta)

	# Поворот 3D модели лицом к цели/игроку
	if cyborg_model_3d and cyborg_model_3d.visible:
		if player:
			var look_pos: Vector3 = Vector3(player.global_position.x, global_position.y, player.global_position.z)
			if global_position.distance_squared_to(look_pos) > 0.05:
				cyborg_model_3d.look_at(look_pos, Vector3.UP)
				cyborg_model_3d.rotate_y(PI) # Разворот лицом вперед

		var is_moving: bool = (state == EnemyState.CHASE and velocity.length_squared() > 0.1)
		var is_atk: bool = (state == EnemyState.ATTACK)
		var is_hurting: bool = (hurt_timer > 0.0)
		cyborg_model_3d.update_animation(delta, is_moving, move_speed, is_atk, is_hurting, false)

	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _update_target_and_state() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	var closest: Node3D = null
	var min_dist: float = INF

	for p in players:
		if p is Node3D and not (p.get("is_dead") == true):
			var d: float = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p

	player = closest
	if not player:
		state = EnemyState.IDLE
		return

	if min_dist <= attack_reach:
		state = EnemyState.ATTACK
	elif min_dist <= CHASE_RANGE:
		state = EnemyState.CHASE
	else:
		state = EnemyState.IDLE

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
			nav_agent.target_position = player.global_position
			var next_pos: Vector3 = nav_agent.get_next_path_position()
			var nav_dir: Vector3 = (next_pos - global_position)
			nav_dir.y = 0.0

			if nav_dir.length_squared() > 0.05:
				dir = nav_dir.normalized()
			else:
				var direct: Vector3 = (player.global_position - global_position)
				direct.y = 0.0
				dir = direct.normalized()

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

			attack_timer -= delta
			if attack_timer <= 0.0:
				_do_attack()
				attack_timer = attack_cooldown

			if attack_timer > attack_cooldown * 0.4:
				sprite.frame = FRAMES_ATTACK[0]
			else:
				sprite.frame = FRAMES_ATTACK[1]

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
	if player and player.has_method("take_damage"):
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= attack_reach + 0.6:
			player.take_damage(attack_dmg)

func _attack_spitter() -> void:
	# Дальняя атака ядом: не нужно подходить вплотную
	if hit_sound:
		hit_sound.stream = snd_acid
		hit_sound.play()
	if player and player.has_method("take_damage"):
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= attack_reach + 2.0:
			player.take_damage(attack_dmg)

func _attack_screamer() -> void:
	# АОЕ звуковая волна: урон всем игрокам в радиусе досягаемости
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

func _attack_exploder() -> void:
	# Самоубийственный взрыв: наносит урон всем игрокам и другим зомби в радиусе 6.0, затем погибает
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

	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e: Node in enemies:
		if e != self and e is Node3D and is_instance_valid(e) and not (e.get("is_dead") == true):
			var dist: float = global_position.distance_to((e as Node3D).global_position)
			if dist <= exp_radius:
				if e.has_method("take_damage"):
					e.take_damage(attack_dmg)

	_die()

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	health -= amount
	hurt_timer = 0.22
	sprite.frame = FRAME_HURT

	# 1. Кинетический отброс (Knockback) назад от пули
	if hit_direction.length_squared() > 0.01:
		velocity += hit_direction.normalized() * 5.5
	elif player:
		var away: Vector3 = (global_position - player.global_position).normalized()
		away.y = 0.0
		velocity += away * 4.8

	# 2. Анимация содрогания спрайта (Hit flinch / Squash & Stretch)
	var orig_scale: Vector3 = scale
	var hit_tween: Tween = create_tween().set_parallel(true)
	# Вспышка урона с электрической кибер-искрой (бирюзово-алый киберпанк/стимпанк глитч)
	sprite.modulate = Color(2.5, 0.4, 0.3, 1.0)
	hit_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

	# Сжатие по вертикали и расширение по бокам от силы удара
	sprite.scale = Vector3(1.22, 0.82, 1.22)
	hit_tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Кровь появляется прямо в точке попадания и разлетается против направления пули.
	var blood_position := hit_position
	if blood_position == Vector3.ZERO:
		blood_position = global_position + Vector3(0.0, 0.9, 0.0)
	_spawn_hit_blood(blood_position, hit_direction)

	if hit_sound:
		hit_sound.play()

	if health <= 0:
		_die()

func hitscan_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage), hit_direction, hit_position)

func projectile_hit(damage: float, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	take_damage(int(damage), hit_direction, hit_position)

func _spawn_hit_blood(pos: Vector3, hit_direction: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "HitBlood"
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.55
	var spray_direction := Vector3.UP
	if hit_direction.length_squared() > 0.01:
		spray_direction += -hit_direction.normalized() * 0.55
	p.direction = spray_direction.normalized()
	p.spread = 38.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -10.0, 0.0)
	p.color = Color(0.8, 0.015, 0.035, 1.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color(0.8, 0.015, 0.035, 1.0)
	droplet_material.roughness = 0.35
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.025
	droplet_mesh.height = 0.05
	droplet_mesh.material = droplet_material
	p.draw_pass_1 = droplet_mesh
	get_parent().add_child(p)
	p.global_position = pos
	var timer := get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = EnemyState.DEAD
	velocity = Vector3.ZERO
	shape.disabled = true

	enemy_died.emit()

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
