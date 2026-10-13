extends PlayerCharacter

# Адаптер связывает готовый пакет FPS-оружия с игровыми правилами «Каравана».
# Движение, модели, стрельба, боеприпасы и перезарядка берутся из пакета;
# здесь остаются здоровье, респавн и минимальная синхронизация мультиплеера.

signal health_changed(value: int)
signal ammo_changed(current: int, total: int)
signal weapon_changed(w_name: String, tex: Texture2D, cur_ammo: int, tot_ammo: int)
signal player_died

var health: int = 100
var is_dead: bool = false
var target_pos: Vector3 = Vector3.ZERO
var target_rot_y: float = 0.0
var _last_weapon_id: int = -1
var _last_magazine: int = -1
var _last_reserve: int = -1

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	super()
	target_pos = global_position
	target_rot_y = rotation.y
	await get_tree().process_frame

	if is_local():
		cam.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_node_or_null("HUD").hide()
		health_changed.emit(health)
		_publish_weapon_status(true)
	else:
		cam.current = false
		get_node_or_null("StateMachine").set_physics_process(false)
		get_node_or_null("CameraHolder").set_process(false)
		get_node_or_null("CameraHolder").set_process_unhandled_input(false)
		get_node_or_null("WeaponManager").hide()
		get_node_or_null("HUD").hide()

func is_local() -> bool:
	return multiplayer.multiplayer_peer == null or is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not is_local():
		global_position = global_position.lerp(target_pos, minf(delta * 18.0, 1.0))
		rotation.y = lerp_angle(rotation.y, target_rot_y, minf(delta * 18.0, 1.0))
		return
	if is_dead:
		return
	super(delta)
	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().size() > 0:
		rpc("sync_state", global_position, rotation.y)

func _process(_delta: float) -> void:
	if is_local() and not is_dead:
		_publish_weapon_status(false)

@rpc("any_peer", "unreliable_ordered")
func sync_state(pos: Vector3, rot_y: float) -> void:
	if not is_local():
		target_pos = pos
		target_rot_y = rot_y

func _publish_weapon_status(force: bool) -> void:
	var manager: WeaponManager = get_node_or_null("WeaponManager") as WeaponManager
	if manager == null or manager.current_weapon == null:
		return
	var resource: WeaponResource = manager.current_weapon.resources
	var magazine: int = resource.total_ammo_in_mag
	var reserve: int = manager.ammo_manager.ammo_dict.get(resource.ammo_type, 0)
	if force or resource.weapon_id != _last_weapon_id:
		_last_weapon_id = resource.weapon_id
		weapon_changed.emit(resource.weapon_name, null, magazine, reserve)
	if force or magazine != _last_magazine or reserve != _last_reserve:
		_last_magazine = magazine
		_last_reserve = reserve
		ammo_changed.emit(magazine, reserve)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	if not is_local():
		rpc_id(get_multiplayer_authority(), "apply_remote_damage", amount)
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	if health <= 0:
		_die()

@rpc("any_peer", "reliable")
func apply_remote_damage(amount: int) -> void:
	if is_local():
		take_damage(amount)

func _die() -> void:
	is_dead = true
	player_died.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await get_tree().create_timer(3.0).timeout
	health = 100
	is_dead = false
	global_position = Vector3(randf_range(-10.0, 10.0), 1.5, randf_range(-10.0, 10.0))
	health_changed.emit(health)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
