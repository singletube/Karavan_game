extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER (BLENDER 3D GLB IMPORT)
# Загружает высокополигональные детальные PBR-модели, созданные в Blender
# на основе референса: иссушенная мумия, разорванные пустынные лохмотья,
# титановые бронепластины с заклепками, светящийся алый визор, гидравлические
# поршни и стальные когти.
# =========================================================================

const GLB_MODELS: Dictionary = {
	"Walker":   "res://models/zombies/cyborg_walker.glb",
	"Runner":   "res://models/zombies/cyborg_runner.glb",
	"Brute":    "res://models/zombies/cyborg_brute.glb",
	"Crawler":  "res://models/zombies/cyborg_crawler.glb",
	"Spitter":  "res://models/zombies/cyborg_spitter.glb",
	"Screamer": "res://models/zombies/cyborg_screamer.glb",
	"Exploder": "res://models/zombies/cyborg_exploder.glb"
}

var current_type: String = "Walker"

# --- Иерархия суставов (универсальный риг) ---
var root_node      : Node3D
var pelvis         : Node3D
var torso          : Node3D
var chest          : Node3D
var head           : Node3D

var l_hip          : Node3D
var l_knee         : Node3D
var r_hip          : Node3D
var r_knee         : Node3D

var l_shoulder     : Node3D
var l_elbow        : Node3D
var r_shoulder     : Node3D
var r_elbow        : Node3D

var rotating_saws  : Array[Node3D] = []

# --- Анимационное состояние ---
var anim_time      : float = 0.0
var walk_speed_mult: float = 1.0
var is_moving      : bool = false
var is_attacking   : bool = false
var is_hurt        : bool = false
var is_dead        : bool = false

var attack_progress: float = 0.0
var hurt_progress  : float = 0.0
var death_progress : float = 0.0

var _model_instance: Node3D

func _ready() -> void:
	pass

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()

	var path : String = GLB_MODELS.get(type_name, GLB_MODELS["Walker"])
	var scene_res = load(path)
	if not scene_res:
		push_error("Failed to load cyborg model: " + path)
		return

	_model_instance = scene_res.instantiate() as Node3D
	if not _model_instance:
		push_error("Failed to instantiate cyborg model instance: " + path)
		return

	_model_instance.name = "ModelInstance"
	# Разворот на PI, чтобы локальный фронт -Z совпадал с направлением движения в enemy.gd
	_model_instance.rotation.y = PI
	add_child(_model_instance)

	# Поиск суставов
	root_node   = _model_instance.find_child("Root", true, false) as Node3D
	pelvis      = _model_instance.find_child("Pelvis", true, false) as Node3D
	torso       = _model_instance.find_child("Torso", true, false) as Node3D
	chest       = _model_instance.find_child("Chest", true, false) as Node3D
	head        = _model_instance.find_child("Head", true, false) as Node3D

	l_shoulder  = _model_instance.find_child("L_Shoulder", true, false) as Node3D
	l_elbow     = _model_instance.find_child("L_Elbow", true, false) as Node3D
	r_shoulder  = _model_instance.find_child("R_Shoulder", true, false) as Node3D
	r_elbow     = _model_instance.find_child("R_Elbow", true, false) as Node3D

	l_hip       = _model_instance.find_child("L_Hip", true, false) as Node3D
	l_knee      = _model_instance.find_child("L_Knee", true, false) as Node3D
	r_hip       = _model_instance.find_child("R_Hip", true, false) as Node3D
	r_knee      = _model_instance.find_child("R_Knee", true, false) as Node3D

	# Безопасная инициализация заглушек при отсутствии узла
	root_node   = _ensure_node(root_node, _model_instance, "Root")
	pelvis      = _ensure_node(pelvis, root_node, "Pelvis")
	torso       = _ensure_node(torso, pelvis, "Torso")
	chest       = _ensure_node(chest, torso, "Chest")
	head        = _ensure_node(head, chest, "Head")

	l_shoulder  = _ensure_node(l_shoulder, chest, "L_Shoulder")
	l_elbow     = _ensure_node(l_elbow, l_shoulder, "L_Elbow")
	r_shoulder  = _ensure_node(r_shoulder, chest, "R_Shoulder")
	r_elbow     = _ensure_node(r_elbow, r_shoulder, "R_Elbow")

	l_hip       = _ensure_node(l_hip, pelvis, "L_Hip")
	l_knee      = _ensure_node(l_knee, l_hip, "L_Knee")
	r_hip       = _ensure_node(r_hip, pelvis, "R_Hip")
	r_knee      = _ensure_node(r_knee, r_hip, "R_Knee")

	# Поиск вращающихся дисковых пил
	rotating_saws.clear()
	for child in _model_instance.find_children("*Saw*", "Node3D", true, false):
		rotating_saws.append(child as Node3D)

func _ensure_node(node: Node3D, parent_node: Node3D, default_name: String) -> Node3D:
	if is_instance_valid(node):
		return node
	var dummy := Node3D.new()
	dummy.name = default_name
	if is_instance_valid(parent_node):
		parent_node.add_child(dummy)
	else:
		add_child(dummy)
	return dummy

func _clear_model() -> void:
	for c in get_children():
		c.queue_free()
	rotating_saws.clear()
	_model_instance = null
	anim_time = 0.0
	attack_progress = 0.0
	hurt_progress = 0.0
	death_progress = 0.0

# =========================================================================
# БИОМЕХАНИЧЕСКАЯ АНИМАЦИЯ ПОХОДКИ, АТАКИ И ПОРАЖЕНИЯ
# =========================================================================
func update_animation(delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	is_moving = moving
	walk_speed_mult = move_speed
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	# Вращение дисковых пил (если установлены)
	var saw_speed : float = (40.0 if is_attacking else 18.0) * delta
	for saw in rotating_saws:
		if is_instance_valid(saw):
			saw.rotate_z(saw_speed)

	if is_dead:
		_animate_death(delta)
		return

	if is_hurt:
		_animate_hurt(delta)
		return

	if is_moving:
		anim_time += delta * (walk_speed_mult * 2.2)
	else:
		anim_time = move_toward(anim_time, 0.0, delta * 3.0)

	var leg_angle : float = sin(anim_time) * 0.65
	var body_bob  : float = absf(cos(anim_time)) * 0.06
	var spine_yaw : float = sin(anim_time) * 0.15

	if current_type != "Crawler" and current_type != "Exploder":
		pelvis.position.y = lerpf(pelvis.position.y, (0.88 if current_type == "Walker" else (1.05 if current_type == "Brute" else 0.85)) - body_bob, delta * 10.0)
		torso.rotation.y = spine_yaw
		head.rotation.y = -spine_yaw * 0.5
		head.rotation.x = sin(anim_time * 2.0) * 0.08

		l_hip.rotation.x = leg_angle
		r_hip.rotation.x = -leg_angle
		l_knee.rotation.x = maxf(0.0, -leg_angle * 0.8)
		r_knee.rotation.x = maxf(0.0, leg_angle * 0.8)
	elif current_type == "Crawler":
		l_shoulder.rotation.x = sin(anim_time) * 0.45
		r_shoulder.rotation.x = -sin(anim_time) * 0.45
		torso.rotation.y = sin(anim_time) * 0.20
	elif current_type == "Exploder":
		pelvis.rotation.z = sin(anim_time) * 0.12
		l_hip.rotation.x = leg_angle * 0.7
		r_hip.rotation.x = -leg_angle * 0.7

	# Анимация рук и атак
	if is_attacking:
		_animate_attack(delta)
	else:
		attack_progress = 0.0
		if current_type == "Screamer":
			l_shoulder.rotation.x = deg_to_rad(-85.0) + sin(anim_time * 1.5) * 0.15
			l_shoulder.rotation.z = deg_to_rad(30.0)
			r_shoulder.rotation.x = deg_to_rad(-85.0) + sin(anim_time * 1.5) * 0.15
			r_shoulder.rotation.z = deg_to_rad(-30.0)
		elif current_type != "Crawler" and current_type != "Exploder":
			l_shoulder.rotation.x = deg_to_rad(-25.0) + sin(anim_time) * 0.30
			l_shoulder.rotation.z = deg_to_rad(12.0)
			l_elbow.rotation.x = deg_to_rad(-45.0)

			r_shoulder.rotation.x = deg_to_rad(-20.0) - sin(anim_time) * 0.30
			r_shoulder.rotation.z = deg_to_rad(-12.0)
			r_elbow.rotation.x = deg_to_rad(-35.0)

func _animate_attack(delta: float) -> void:
	attack_progress += delta * (6.5 if current_type == "Runner" else 4.2)
	var phase : float = fmod(attack_progress, TAU)

	if phase < PI:
		var t : float = phase / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(-120.0), t)
		l_elbow.rotation.x = deg_to_rad(-85.0)
		torso.rotation.y = deg_to_rad(25.0)
	else:
		var t : float = (phase - PI) / PI
		l_shoulder.rotation.x = lerp_angle(l_shoulder.rotation.x, deg_to_rad(45.0), t * 1.8)
		l_elbow.rotation.x = deg_to_rad(-10.0)
		torso.rotation.y = deg_to_rad(-30.0)

func _animate_hurt(delta: float) -> void:
	hurt_progress += delta * 8.0
	chest.rotation.x = deg_to_rad(-22.0)
	head.rotation.x = deg_to_rad(-35.0)
	l_shoulder.rotation.x = deg_to_rad(15.0)
	r_shoulder.rotation.x = deg_to_rad(15.0)
	root_node.position.z = -0.08

func _animate_death(delta: float) -> void:
	death_progress = minf(1.0, death_progress + delta * 2.8)
	var t : float = death_progress

	var target_y : float = 0.28
	if current_type == "Brute":
		target_y = 0.45
	elif current_type == "Crawler":
		target_y = 0.18
	elif current_type == "Exploder":
		target_y = 0.35

	root_node.position.y = lerpf(root_node.position.y, target_y, t)
	root_node.rotation.x = lerp_angle(root_node.rotation.x, deg_to_rad(-85.0), t)
	l_hip.rotation.x = lerp_angle(l_hip.rotation.x, deg_to_rad(-10.0), t)
	r_hip.rotation.x = lerp_angle(r_hip.rotation.x, deg_to_rad(-10.0), t)
	l_knee.rotation.x = lerp_angle(l_knee.rotation.x, deg_to_rad(40.0), t)
	r_knee.rotation.x = lerp_angle(r_knee.rotation.x, deg_to_rad(25.0), t)
	l_shoulder.rotation.z = lerp_angle(l_shoulder.rotation.z, deg_to_rad(45.0), t)
	r_shoulder.rotation.z = lerp_angle(r_shoulder.rotation.z, deg_to_rad(-45.0), t)
	pelvis.rotation = pelvis.rotation.lerp(Vector3.ZERO, t)
	torso.rotation = torso.rotation.lerp(Vector3.ZERO, t)
