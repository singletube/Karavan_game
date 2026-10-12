extends CharacterBody3D

# --- Настройки движения ---
const WALK_SPEED      := 5.0
const RUN_SPEED       := 9.0
const CROUCH_SPEED    := 2.5
const JUMP_VELOCITY   := 6.0
const GRAVITY         := 20.0
const MOUSE_SENS      := 0.002

# --- Настройки приседания ---
const STAND_HEIGHT    := 1.8
const CROUCH_HEIGHT   := 0.9
const STAND_EYE_Y     := 0.75
const CROUCH_EYE_Y   := 0.25

# --- Ноды ---
@onready var camera        : Camera3D            = $Head/Camera3D
@onready var head          : Node3D              = $Head
@onready var shape         : CollisionShape3D    = $CollisionShape3D
@onready var weapon_rig    : Node3D              = $Head/Camera3D/WeaponRig
@onready var muzzle_flash  : OmniLight3D         = $Head/Camera3D/MuzzleFlash
@onready var body_sprite   : Sprite3D            = $BodySprite
@onready var shoot_sound   : AudioStreamPlayer3D = $ShootSound
@onready var step_sound    : AudioStreamPlayer3D = $StepSound

# --- Состояние ---
var is_crouching  := false
var fire_timer    := 0.0
var is_reloading  := false
var health        := 100
var is_dead       := false

# --- СИСТЕМА ОРУЖИЯ (4 СТВОЛА) ---
enum WeaponType { REVOLVER, SHOTGUN, RIFLE, ROCKET }
var current_weapon_idx : int = 0

var weapons : Array = []

# --- Сетевая интерполяция для удаленных игроков ---
var target_pos : Vector3 = Vector3.ZERO
var target_rot_y : float = 0.0

signal health_changed(value: int)
signal ammo_changed(current: int, total: int)
signal weapon_changed(w_name: String, tex: Texture2D, cur_ammo: int, tot_ammo: int)
signal weapon_fired(recoil_amt: float)
signal player_died

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	target_pos = global_position
	target_rot_y = rotation.y

	_init_weapons()

	if is_local():
		camera.current = true
		body_sprite.visible = false
		if weapon_rig:
			weapon_rig.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		emit_signal("health_changed", health)
		switch_weapon(WeaponType.REVOLVER)
	else:
		camera.current = false
		if weapon_rig:
			weapon_rig.hide()
		body_sprite.visible = true
		body_sprite.texture = TextureGen.make_player()
		body_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		body_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		body_sprite.pixel_size = 0.04
		body_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		body_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD

# --- Аудио ресурсы (Настоящие звуки выстрелов и взрывов) ---
var snd_revolver : AudioStream = preload("res://assets/audio/shoot_revolver.mp3")
var snd_shotgun  : AudioStream = preload("res://assets/audio/shoot_shotgun.mp3")
var snd_rifle    : AudioStream = preload("res://assets/audio/shoot_rifle.mp3")
var snd_rocket   : AudioStream = preload("res://assets/audio/shoot_rocket.mp3")
var snd_reload   : AudioStream = preload("res://assets/audio/reload_click.mp3")
var snd_hurt     : AudioStream = preload("res://assets/audio/player_hurt.wav")
var snd_explosion: AudioStream = preload("res://assets/audio/explosion.mp3")

func _init_weapons() -> void:
	weapons = [
		{
			"id": WeaponType.REVOLVER,
			"name": "РЕВОЛЬВЕР .44",
			"texture": TextureGen.make_weapon_revolver(),
			"sound": snd_revolver,
			"fire_rate": 0.28,
			"reload_time": 1.25,
			"damage": 32,
			"pellets": 1,
			"spread": 0.005,
			"max_mag": 6,
			"cur_mag": 6,
			"total_ammo": 120,
			"recoil": 35.0,
			"kick_z": 0.065,
			"kick_rot": 14.0,
			"is_explosive": false
		},
		{
			"id": WeaponType.SHOTGUN,
			"name": "ОБРЕЗ ДВУСТВОЛКИ",
			"texture": TextureGen.make_weapon_shotgun(),
			"sound": snd_shotgun,
			"fire_rate": 0.82,
			"reload_time": 1.4,
			"damage": 14,
			"pellets": 10,
			"spread": 0.075,
			"max_mag": 2,
			"cur_mag": 2,
			"total_ammo": 60,
			"recoil": 75.0,
			"kick_z": 0.13,
			"kick_rot": 26.0,
			"is_explosive": false
		},
		{
			"id": WeaponType.RIFLE,
			"name": "АВТОМАТ КАРАВАНА",
			"texture": TextureGen.make_weapon_rifle(),
			"sound": snd_rifle,
			"fire_rate": 0.095,
			"reload_time": 1.3,
			"damage": 18,
			"pellets": 1,
			"spread": 0.02,
			"max_mag": 30,
			"cur_mag": 30,
			"total_ammo": 180,
			"recoil": 18.0,
			"kick_z": 0.038,
			"kick_rot": 6.5,
			"is_explosive": false
		},
		{
			"id": WeaponType.ROCKET,
			"name": "РАКЕТНИЦА RPG",
			"texture": TextureGen.make_weapon_rocket(),
			"sound": snd_rocket,
			"fire_rate": 0.95,
			"reload_time": 1.6,
			"damage": 160,
			"pellets": 1,
			"spread": 0.001,
			"max_mag": 1,
			"cur_mag": 1,
			"total_ammo": 15,
			"recoil": 85.0,
			"kick_z": 0.17,
			"kick_rot": 32.0,
			"is_explosive": true
		}
	]

func is_local() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return is_multiplayer_authority()

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_dead:
		return

	# F11: Полный экран
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		toggle_fullscreen()
		return

	# Переключение оружия на цифры 1, 2, 3, 4
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: switch_weapon(WeaponType.REVOLVER)
			KEY_2: switch_weapon(WeaponType.SHOTGUN)
			KEY_3: switch_weapon(WeaponType.RIFLE)
			KEY_4: switch_weapon(WeaponType.ROCKET)

	# Колесико мыши для смены оружия
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var prev_idx: int = (current_weapon_idx - 1 + weapons.size()) % weapons.size()
			switch_weapon(prev_idx)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_idx: int = (current_weapon_idx + 1) % weapons.size()
			switch_weapon(next_idx)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clamp(
			head.rotation.x - event.relative.y * MOUSE_SENS,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)

func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func switch_weapon(idx: int) -> void:
	if idx < 0 or idx >= weapons.size():
		return
	if is_reloading:
		is_reloading = false
		if weapon_rig:
			weapon_rig.cancel_reload()
	current_weapon_idx = idx
	fire_timer = 0.15 # задержка доставания
	if weapon_rig:
		weapon_rig.set_active_weapon(current_weapon_idx)
	var w: Dictionary = weapons[current_weapon_idx]
	emit_signal("weapon_changed", w["name"], w["texture"], w["cur_mag"], w["total_ammo"])
	emit_signal("ammo_changed", w["cur_mag"], w["total_ammo"])

func _physics_process(delta: float) -> void:
	if not is_local():
		global_position = global_position.lerp(target_pos, delta * 18.0)
		rotation.y = lerp_angle(rotation.y, target_rot_y, delta * 18.0)
		return

	if is_dead:
		return

	_handle_gravity(delta)
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_shoot(delta)

	move_and_slide()

	# 3D обновление покачивания и отдачи оружия
	if weapon_rig:
		var h_vel: Vector2 = Vector2(velocity.x, velocity.z)
		var is_moving: bool = is_on_floor() and h_vel.length() > 0.8
		weapon_rig.update_transform(delta, is_moving, h_vel.length())

	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().size() > 0:
		rpc("sync_state", global_position, rotation.y, head.rotation.x)

@rpc("any_peer", "unreliable_ordered")
func sync_state(pos: Vector3, rot_y: float, _head_x: float) -> void:
	if is_local():
		return
	target_pos = pos
	target_rot_y = rot_y

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = JUMP_VELOCITY

func _handle_crouch(delta: float) -> void:
	var want_crouch: bool = Input.is_action_pressed("crouch")

	if want_crouch and not is_crouching:
		is_crouching = true
		_set_crouch_shape(true)
	elif not want_crouch and is_crouching:
		if _can_stand_up():
			is_crouching = false
			_set_crouch_shape(false)

	var target_eye_y: float = CROUCH_EYE_Y if is_crouching else STAND_EYE_Y
	head.position.y = lerp(head.position.y, target_eye_y, delta * 12.0)

func _set_crouch_shape(crouching: bool) -> void:
	var cap: CapsuleShape3D = shape.shape as CapsuleShape3D
	if cap:
		cap.height = CROUCH_HEIGHT if crouching else STAND_HEIGHT

func _can_stand_up() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3  = global_position
	var to: Vector3    = global_position + Vector3.UP * (STAND_HEIGHT + 0.1)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.exclude = [self]
	var result: Dictionary = space.intersect_ray(query)
	return result.is_empty()

func _handle_movement(delta: float) -> void:
	var speed: float
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("run"):
		speed = RUN_SPEED
	else:
		speed = WALK_SPEED

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 8.0 * delta)

func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	var w: Dictionary = weapons[current_weapon_idx]

	if is_reloading:
		return

	if Input.is_action_pressed("shoot") and fire_timer <= 0.0 and w["cur_mag"] > 0:
		_fire()
		fire_timer = w["fire_rate"]
	elif (Input.is_action_just_pressed("reload") or (Input.is_action_pressed("shoot") and w["cur_mag"] == 0)) and w["total_ammo"] > 0 and w["cur_mag"] < w["max_mag"]:
		_reload()

func _fire() -> void:
	var w: Dictionary = weapons[current_weapon_idx]
	w["cur_mag"] -= 1

	emit_signal("ammo_changed", w["cur_mag"], w["total_ammo"])
	emit_signal("weapon_fired", w["recoil"])

	if weapon_rig:
		weapon_rig.play_recoil(w["kick_z"], w["kick_rot"])

	_play_shoot_effects()

	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().size() > 0:
		rpc("sync_shoot_effect")

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z

	var pellets_count: int = w["pellets"]
	var spread_val: float = w["spread"]
	var damage_val: int = w["damage"]
	var is_exp: bool = w["is_explosive"]

	for i in range(pellets_count):
		var spread_dir: Vector3 = forward
		if spread_val > 0.001:
			var right: Vector3 = camera.global_transform.basis.x
			var up: Vector3 = camera.global_transform.basis.y
			spread_dir += (right * randf_range(-spread_val, spread_val) + up * randf_range(-spread_val, spread_val))
			spread_dir = spread_dir.normalized()

		var target: Vector3 = origin + spread_dir * 140.0
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
		query.exclude = [self]
		var hit: Dictionary = space.intersect_ray(query)

		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var target_node: Object = hit.collider

			if is_exp:
				# Взрыв ракеты по площади!
				_explode_at(hit_pos, 7.5, damage_val)
				break
			else:
				if target_node and target_node.has_method("take_damage"):
					target_node.take_damage(damage_val, spread_dir)

func _explode_at(pos: Vector3, radius: float, max_dmg: int) -> void:
	# Звук взрыва в 3D пространстве
	var exp_player := AudioStreamPlayer3D.new()
	exp_player.stream = snd_explosion
	exp_player.max_distance = 60.0
	get_parent().add_child(exp_player)
	exp_player.global_position = pos
	exp_player.play()
	exp_player.finished.connect(func(): exp_player.queue_free())

	# Наносим урон всем врагам в радиусе взрыва
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			var dist: float = pos.distance_to((e as Node3D).global_position)
			if dist <= radius:
				var falloff: float = 1.0 - (dist / radius)
				if e.has_method("take_damage"):
					e.take_damage(int(max_dmg * max(0.25, falloff)))

	# Если попали рядом с собой или другими игроками
	var players: Array = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node3D and is_instance_valid(p):
			var dist: float = pos.distance_to((p as Node3D).global_position)
			if dist <= radius:
				var falloff: float = 1.0 - (dist / radius)
				if p.has_method("take_damage"):
					p.take_damage(int(max_dmg * 0.5 * falloff))

func _play_shoot_effects() -> void:
	if shoot_sound:
		var w: Dictionary = weapons[current_weapon_idx]
		if w.has("sound") and w["sound"] != null:
			shoot_sound.stream = w["sound"]
		shoot_sound.play()
	if muzzle_flash:
		muzzle_flash.show()
		var timer: SceneTreeTimer = get_tree().create_timer(0.06)
		timer.timeout.connect(func(): if muzzle_flash: muzzle_flash.hide())

@rpc("any_peer", "call_remote")
func sync_shoot_effect() -> void:
	_play_shoot_effects()

func _reload() -> void:
	var w: Dictionary = weapons[current_weapon_idx]
	if is_reloading or w["total_ammo"] <= 0 or w["cur_mag"] == w["max_mag"]:
		return

	is_reloading = true
	var reload_duration: float = w["reload_time"]
	var reload_weapon_idx: int = current_weapon_idx

	# Звук механической перезарядки
	if shoot_sound:
		shoot_sound.stream = snd_reload
		shoot_sound.play()

	if weapon_rig:
		weapon_rig.play_reload(current_weapon_idx, reload_duration)

	var timer: SceneTreeTimer = get_tree().create_timer(reload_duration)
	timer.timeout.connect(func():
		# Проверяем, что игрок не переключил оружие во время перезарядки и жив
		if is_reloading and current_weapon_idx == reload_weapon_idx and not is_dead:
			var needed: int = w["max_mag"] - w["cur_mag"]
			var take: int   = min(needed, w["total_ammo"])
			w["cur_mag"]   += take
			w["total_ammo"]-= take
			emit_signal("ammo_changed", w["cur_mag"], w["total_ammo"])
			is_reloading = false
	)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	if not is_local():
		rpc_id(get_multiplayer_authority(), "apply_remote_damage", amount)
		return

	# Звук ранения игрока
	if shoot_sound:
		shoot_sound.stream = snd_hurt
		shoot_sound.play()

	health = max(0, health - amount)
	emit_signal("health_changed", health)
	if health <= 0:
		_die()

@rpc("any_peer", "reliable")
func apply_remote_damage(amount: int) -> void:
	if is_local():
		take_damage(amount)

func _die() -> void:
	is_dead = true
	emit_signal("player_died")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn() -> void:
	health = 100
	_init_weapons()
	is_dead = false
	global_position = Vector3(randf_range(-10.0, 10.0), 1.5, randf_range(-10.0, 10.0))
	emit_signal("health_changed", health)
	switch_weapon(current_weapon_idx)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
