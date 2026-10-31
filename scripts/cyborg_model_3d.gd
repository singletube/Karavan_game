extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Использует высококачественную анимированную 3D-модель (Melty Zombie / Xellotath)
# с полным набором скелетных анимаций:
# walk01, walk02, run, idle01, idle02, attack01, attack02, damage, death, on_all_four_A
# А также кибернетические импланты: светящийся алый окуляр / визор на кости головы,
# цветовую дифференциацию и масштабирование по типам зомби.
# =========================================================================

const ZOMBIE_MODEL_PATH: String = "res://models/zombies/real_zombie_walker.glb"

var current_type: String = "Walker"

# Ссылки на ноды загруженной модели
var _model_instance: Node3D = null
var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var eye_light: OmniLight3D = null

# Параметры анимаций
var is_moving: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false

func _ready() -> void:
	pass

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()

	var scene_res = load(ZOMBIE_MODEL_PATH)
	if not scene_res:
		push_error("Failed to load real zombie model: " + ZOMBIE_MODEL_PATH)
		return

	_model_instance = scene_res.instantiate() as Node3D
	if not _model_instance:
		push_error("Failed to instantiate zombie model")
		return

	_model_instance.name = "RealZombieInstance"
	add_child(_model_instance)

	# Поиск AnimationPlayer
	anim_player = _model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		for c in _model_instance.find_children("*", "AnimationPlayer", true, false):
			anim_player = c as AnimationPlayer
			break

	# Настройка циклов анимаций
	if anim_player:
		_configure_animation_loops()

	# Поиск Skeleton3D для кибернетических аттачментов
	skeleton = _model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		for c in _model_instance.find_children("*", "Skeleton3D", true, false):
			skeleton = c as Skeleton3D
			break

	# Настройка масштаба и параметров под тип зомби
	_apply_type_customization()

	# Добавление светящегося кибер-окуляра на голову
	if skeleton:
		_attach_cyber_eye()

func _clear_model() -> void:
	for c in get_children():
		c.queue_free()
	_model_instance = null
	anim_player = null
	skeleton = null
	eye_light = null
	is_dead = false
	is_hurt = false
	is_attacking = false
	is_moving = false

func _configure_animation_loops() -> void:
	var looping_anims = ["walk01", "walk02", "run", "idle01", "idle02", "on_all_four_A", "on_all_four_B"]
	for a_name in looping_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR

	var single_anims = ["attack01", "attack02", "damage", "death"]
	for a_name in single_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_NONE

func _apply_type_customization() -> void:
	match current_type:
		"Runner":
			scale = Vector3(0.92, 0.92, 0.92)
		"Brute":
			scale = Vector3(1.38, 1.38, 1.38)
		"Crawler":
			scale = Vector3(1.05, 0.9, 1.05)
		"Spitter":
			scale = Vector3(0.95, 0.95, 0.95)
		"Screamer":
			scale = Vector3(0.96, 0.96, 0.96)
		"Exploder":
			scale = Vector3(1.0, 1.0, 1.0)
		_:
			scale = Vector3.ONE

func _get_type_eye_color() -> Color:
	match current_type:
		"Spitter":
			return Color(0.2, 1.0, 0.25) # Токсичный кислотный свет
		"Screamer":
			return Color(1.0, 0.85, 0.1) # Тревожный желто-янтарный
		"Exploder":
			return Color(1.0, 0.28, 0.05) # Взрывной огненно-оранжевый
		_:
			return Color(1.0, 0.08, 0.08) # Зловещий алый кибер-окуляр

func _attach_cyber_eye() -> void:
	var head_bone_idx = skeleton.find_bone("head_014")
	if head_bone_idx == -1:
		return

	var bone_attachment := BoneAttachment3D.new()
	bone_attachment.name = "CyberHeadAttachment"
	bone_attachment.bone_name = "head_014"
	skeleton.add_child(bone_attachment)

	var eye_color := _get_type_eye_color()

	# Металлическая оправа киберокуляра
	var socket_mesh := MeshInstance3D.new()
	var socket_cyl := CylinderMesh.new()
	socket_cyl.top_radius = 0.08
	socket_cyl.bottom_radius = 0.08
	socket_cyl.height = 0.06
	socket_mesh.mesh = socket_cyl
	var socket_mat := StandardMaterial3D.new()
	socket_mat.albedo_color = Color(0.12, 0.12, 0.13)
	socket_mat.metallic = 0.9
	socket_mat.roughness = 0.25
	socket_mesh.material_override = socket_mat
	socket_mesh.position = Vector3(0.15, 0.22, 0.45)
	socket_mesh.rotation_degrees = Vector3(80, 0, 0)
	bone_attachment.add_child(socket_mesh)

	# Светящаяся линза окуляра
	var lens_mesh := MeshInstance3D.new()
	var lens_sphere := SphereMesh.new()
	lens_sphere.radius = 0.06
	lens_sphere.height = 0.08
	lens_mesh.mesh = lens_sphere
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = eye_color
	lens_mat.emission_enabled = true
	lens_mat.emission = eye_color
	lens_mat.emission_energy_multiplier = 4.5
	lens_mesh.material_override = lens_mat
	lens_mesh.position = Vector3(0.0, 0.02, 0.0)
	socket_mesh.add_child(lens_mesh)

	# Источник света от окуляра
	eye_light = OmniLight3D.new()
	eye_light.light_color = eye_color
	eye_light.light_energy = 1.2
	eye_light.omni_range = 1.8
	eye_light.shadow_enabled = false
	lens_mesh.add_child(eye_light)

# =========================================================================
# УПРАВЛЕНИЕ АНИМАЦИЯМИ (ВЫЗЫВАЕТСЯ ИЗ ENEMY.GD)
# =========================================================================
func update_animation(_delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	if not anim_player:
		return

	is_moving = moving
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	# 1. Смерть (высший приоритет)
	if is_dead:
		if eye_light and is_instance_valid(eye_light):
			eye_light.light_energy = move_toward(eye_light.light_energy, 0.0, _delta * 3.0)
		if anim_player.current_animation != "death":
			anim_player.play("death", 0.15)
		return

	# 2. Получение урона
	if is_hurt:
		if anim_player.current_animation != "damage":
			anim_player.play("damage", 0.08, 1.4)
		return

	# 3. Атака
	if is_attacking:
		var atk_anim = "attack02" if (current_type == "Runner" or current_type == "Screamer") else "attack01"
		var atk_speed = 1.4 if current_type == "Runner" else 1.1
		if anim_player.current_animation != atk_anim:
			anim_player.play(atk_anim, 0.1, atk_speed)
		return

	# 4. Движение
	if is_moving:
		match current_type:
			"Crawler":
				if anim_player.current_animation != "on_all_four_A":
					anim_player.play("on_all_four_A", 0.2, maxf(1.0, move_speed * 0.45))
			"Runner":
				if anim_player.current_animation != "run":
					anim_player.play("run", 0.15, maxf(1.1, move_speed * 0.32))
			"Brute":
				if anim_player.current_animation != "walk02":
					anim_player.play("walk02", 0.2, 0.85)
			_:
				if anim_player.current_animation != "walk01":
					anim_player.play("walk01", 0.2, maxf(0.85, move_speed * 0.38))
		return

	# 5. Покой (Idle)
	if anim_player.current_animation != "idle01" and anim_player.current_animation != "idle02":
		anim_player.play("idle01", 0.25)
