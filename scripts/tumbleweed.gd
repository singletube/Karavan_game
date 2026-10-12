extends Node3D

var speed       : float = 6.0
var wind_dir    : Vector3 = Vector3(1.0, 0.0, 0.3).normalized()
var rot_speed   : float = 5.0
var hop_speed   : float = 7.0
var hop_height  : float = 0.5
var time_offset : float = 0.0
var start_y     : float = 0.6

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	time_offset = randf_range(0.0, 10.0)
	speed = randf_range(5.0, 9.0)
	hop_speed = randf_range(6.0, 10.0)
	hop_height = randf_range(0.3, 0.7)
	start_y = global_position.y

	sprite.texture = TextureGen.make_tumbleweed()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.035
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD

func _process(delta: float) -> void:
	# Движение по ветру
	global_position += wind_dir * speed * delta

	# Подпрыгивания на кочках песка
	var t: float = Time.get_ticks_msec() / 1000.0 + time_offset
	global_position.y = start_y + abs(sin(t * hop_speed)) * hop_height

	# Вращение клубка
	sprite.rotation.z += rot_speed * delta

	# Циклический респавн при улете далеко
	if global_position.x > 180.0 or global_position.z > 180.0:
		global_position.x = -160.0 + randf_range(-20.0, 20.0)
		global_position.z = randf_range(-150.0, 150.0)
