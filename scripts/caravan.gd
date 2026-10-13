extends AnimatableBody3D

class_name Caravan

# --- Константы и настройки ---
const MAX_HEALTH: int = 500 # В 5 раз больше здоровья игрока (100 HP)
const BASE_SPEED: float = 2.25 # 1/4 скорости ходьбы игрока (9.0 / 4)

signal health_changed(current: int, max_hp: int)
signal caravan_destroyed
signal caravan_respawned

@export var move_speed: float = BASE_SPEED
@export var move_direction: Vector3 = Vector3(0.0, 0.0, -1.0) # Идет вперед вглубь пустыни

var health: int = MAX_HEALTH
var is_destroyed: bool = false
var walk_phase: float = 0.0

@onready var model: CaravanModel3D = $CaravanModel3D
@onready var hit_sound: AudioStreamPlayer3D = $HitSound
@onready var break_sound: AudioStreamPlayer3D = $BreakSound

var snd_wood_hit: AudioStream = preload("res://assets/audio/shoot_revolver.mp3")

func _enter_tree() -> void:
	add_to_group("caravan")

func _ready() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

	if hit_sound and snd_wood_hit:
		hit_sound.stream = snd_wood_hit

func _physics_process(delta: float) -> void:
	if is_destroyed:
		if model:
			model.update_animation(delta, false, 0.0, walk_phase)
		return

	var step := move_direction.normalized() * (move_speed * delta)
	global_position += step

	walk_phase += delta * (move_speed * 1.5)

	if model:
		model.update_animation(delta, true, move_speed, walk_phase)

# Возвращает позицию спавна внутри кузова повозки (для игрока)
func get_cargo_spawn_position() -> Vector3:
	return global_transform * Vector3(0.0, 1.15, 0.3)

func take_damage(amount: int, hit_direction: Vector3 = Vector3.ZERO, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)

	_spawn_wood_splinters(hit_position if hit_position != Vector3.ZERO else global_position + Vector3(0.0, 1.0, 0.0), hit_direction)

	if hit_sound:
		hit_sound.pitch_scale = randf_range(0.65, 0.85)
		hit_sound.play()

	if health <= 0:
		_on_caravan_destroyed()

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
