extends Node3D

var speed       : float = 6.0
var wind_dir    : Vector3 = Vector3(1.0, 0.0, 0.3).normalized()
var rot_speed   : float = 5.0
var hop_speed   : float = 7.0
var hop_height  : float = 0.5
var time_offset : float = 0.0
var start_y     : float = 0.5

var model_3d    : Node3D

func _ready() -> void:
	time_offset = randf_range(0.0, 10.0)
	speed = randf_range(5.0, 9.0)
	hop_speed = randf_range(6.0, 10.0)
	hop_height = randf_range(0.3, 0.7)
	start_y = global_position.y

	# Инстанцируем объемную 3D модель перекати-поле
	model_3d = DesertScenery3D.create_tumbleweed_3d()
	add_child(model_3d)

func _process(delta: float) -> void:
	# Движение по ветру
	global_position += wind_dir * speed * delta

	# Подпрыгивания на кочках песка
	var t: float = Time.get_ticks_msec() / 1000.0 + time_offset
	global_position.y = start_y + absf(sin(t * hop_speed)) * hop_height

	# Реалистичное 3D вращение клубка при качении по земле
	if model_3d != null:
		model_3d.rotate_x(rot_speed * delta * 0.8)
		model_3d.rotate_z(-rot_speed * delta)

	# Циклический респавн при улете далеко
	if global_position.x > 180.0 or global_position.z > 180.0:
		global_position.x = -160.0 + randf_range(-20.0, 20.0)
		global_position.z = randf_range(-150.0, 150.0)
