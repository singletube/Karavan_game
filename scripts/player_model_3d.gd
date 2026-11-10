extends Node3D
class_name PlayerModel3D

# =========================================================================
# 3D МОДЕЛЬ ПЕРСОНАЖА (Киберпанк-стрелок в пустыне с настоящей скелетной моделью и оружием)
# =========================================================================

const MODEL_CHARACTER = preload("res://models/player/CyberpunkCharacter.glb")

const MODEL_REVOLVER = preload("res://models/weapons/Revolver.glb")
const MODEL_SHOTGUN  = preload("res://models/weapons/Shotgun.glb")
const MODEL_RIFLE    = preload("res://models/weapons/AssaultRifle.glb")
const MODEL_SNIPER   = preload("res://models/weapons/SniperRifle.glb")
const MODEL_ROCKET   = preload("res://models/weapons/RocketLauncher.glb")
const MODEL_SMG      = preload("res://models/weapons/SMG.glb")

# Экземпляр персонажа и скелетной анимации
var char_instance  : Node3D = null
var skeleton       : Skeleton3D = null
var anim_player    : AnimationPlayer = null
var weapon_holder  : Node3D = null
var active_gun     : Node3D = null
var muzzle_flash   : OmniLight3D = null
var shoot_sound    : AudioStreamPlayer3D = null
var chest_light    : SpotLight3D = null

# Совместимость с внешними скриптами (dummy узлы)
var pelvis         : Node3D = null
var torso          : Node3D = null
var head           : Node3D = null
var hat            : Node3D = null
var face_mesh      : MeshInstance3D = null
var neck_mesh      : MeshInstance3D = null
var bandana_mesh   : MeshInstance3D = null
var l_leg          : Node3D = null
var r_leg          : Node3D = null
var l_arm          : Node3D = null
var r_arm          : Node3D = null

# Звуки выстрелов для 3D отображения
var snd_revolver : AudioStream
var snd_shotgun  : AudioStream
var snd_rifle    : AudioStream
var snd_rocket   : AudioStream

# Анимационное состояние
var current_anim       : String = ""
var current_weapon_name: String = "Pistol"
var is_first_person    : bool = false
var is_kicking         : bool = false
var kick_timer         : float = 0.0

func _ready() -> void:
	_init_sounds()
	_build_model()
	set_weapon("Pistol")

func _init_sounds() -> void:
	if ResourceLoader.exists("res://assets/audio/shoot_revolver.wav"):
		snd_revolver = load("res://assets/audio/shoot_revolver.wav") as AudioStream
	elif ResourceLoader.exists("res://assets/audio/shoot_revolver.mp3"):
		snd_revolver = load("res://assets/audio/shoot_revolver.mp3") as AudioStream

	if ResourceLoader.exists("res://assets/audio/shoot_shotgun.wav"):
		snd_shotgun = load("res://assets/audio/shoot_shotgun.wav") as AudioStream
	elif ResourceLoader.exists("res://assets/audio/shoot_shotgun.mp3"):
		snd_shotgun = load("res://assets/audio/shoot_shotgun.mp3") as AudioStream

	if ResourceLoader.exists("res://assets/audio/shoot_rifle.wav"):
		snd_rifle = load("res://assets/audio/shoot_rifle.wav") as AudioStream
	elif ResourceLoader.exists("res://assets/audio/shoot_rifle.mp3"):
		snd_rifle = load("res://assets/audio/shoot_rifle.mp3") as AudioStream

	if ResourceLoader.exists("res://assets/audio/shoot_rocket.wav"):
		snd_rocket = load("res://assets/audio/shoot_rocket.wav") as AudioStream
	elif ResourceLoader.exists("res://assets/audio/shoot_rocket.mp3"):
		snd_rocket = load("res://assets/audio/shoot_rocket.mp3") as AudioStream

func _build_model() -> void:
	# Создаем фиктивные узлы для совместимости
	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	add_child(pelvis)
	torso = Node3D.new()
	torso.name = "Torso"
	pelvis.add_child(torso)
	head = Node3D.new()
	head.name = "Head"
	torso.add_child(head)
	l_leg = Node3D.new()
	l_leg.name = "LeftLeg"
	pelvis.add_child(l_leg)
	r_leg = Node3D.new()
	r_leg.name = "RightLeg"
	pelvis.add_child(r_leg)
	l_arm = Node3D.new()
	l_arm.name = "LeftArm"
	torso.add_child(l_arm)
	r_arm = Node3D.new()
	r_arm.name = "RightArm"
	torso.add_child(r_arm)

	# Загружаем полноценную 3D GLB модель персонажа
	char_instance = MODEL_CHARACTER.instantiate()
	char_instance.name = "CyberpunkCharacter"
	add_child(char_instance)

	# Скрываем встроенный меч
	var sword: Node = char_instance.find_child("Sword", true, false)
	if sword and sword is VisualInstance3D:
		(sword as VisualInstance3D).visible = false

	# Находим контроллер скелетных анимаций и скелет
	skeleton = char_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = char_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		anim_player.playback_default_blend_time = 0.15

	# Находим точку крепления оружия на кисти руки (BoneAttachment3D "Weapon")
	var att_weapon := char_instance.find_child("Weapon", true, false)
	if att_weapon:
		weapon_holder = att_weapon
	else:
		weapon_holder = Node3D.new()
		weapon_holder.name = "WeaponHolder"
		char_instance.add_child(weapon_holder)

	# 3D звук выстрела
	shoot_sound = AudioStreamPlayer3D.new()
	shoot_sound.name = "RemoteShootSound"
	shoot_sound.bus = "Master"
	shoot_sound.max_distance = 45.0
	shoot_sound.volume_db = 0.0
	weapon_holder.add_child(shoot_sound)

	# Вспышка выстрела
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.light_color = Color(1.0, 0.85, 0.35)
	muzzle_flash.light_energy = 6.0
	muzzle_flash.omni_range = 5.0
	muzzle_flash.visible = false
	weapon_holder.add_child(muzzle_flash)

	# Тактический нагрудный фонарь
	chest_light = SpotLight3D.new()
	chest_light.name = "ChestFlashlight"
	chest_light.position = Vector3(0.0, 1.3, 0.25)
	chest_light.rotation_degrees = Vector3(0, 0, 0)
	chest_light.light_color = Color(0.96, 0.97, 1.0)
	chest_light.light_energy = 2.8
	chest_light.spot_range = 35.0
	chest_light.spot_angle = 36.0
	chest_light.shadow_enabled = true
	chest_light.visible = false
	add_child(chest_light)

	# Запуск стартовой анимации прицеливания с оружием
	_play_anim("CharacterArmature|Idle_Gun_Pointing", 1.0)

# =========================================================================
# УПРАВЛЕНИЕ АНИМАЦИЯМИ
# =========================================================================
func _play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if current_anim != anim_name:
		current_anim = anim_name
		anim_player.play(anim_name, 0.2, speed)
	else:
		anim_player.speed_scale = speed

func update_animation(delta: float, moving: bool, velocity_length: float, _is_crouching: bool = false) -> void:
	# Удерживаем скрытие головы/рук в 1-м лице при воспроизведении анимаций
	if is_first_person:
		_apply_first_person_bone_hiding()

	# 1. Анимация пинка ногой имеет наивысший приоритет
	if is_kicking:
		kick_timer -= delta
		if kick_timer <= 0.0:
			is_kicking = false
		else:
			return

	# 2. Ходьба или спринт
	if moving and velocity_length > 0.15:
		if velocity_length > 4.5:
			_play_anim("CharacterArmature|Run", clampf(velocity_length / 4.8, 0.8, 1.6))
		else:
			_play_anim("CharacterArmature|Walk", clampf(velocity_length / 2.2, 0.7, 1.4))
	else:
		# 3. Стойка готовности с оружием
		_play_anim("CharacterArmature|Idle_Gun_Pointing", 1.0)

func play_kick() -> void:
	is_kicking = true
	kick_timer = 0.55
	if anim_player and anim_player.has_animation("CharacterArmature|Kick_Right"):
		current_anim = "CharacterArmature|Kick_Right"
		anim_player.play("CharacterArmature|Kick_Right", 0.08, 1.6)

# =========================================================================
# ПЕРЕКЛЮЧЕНИЕ 3D ОРУЖИЯ В РУКАХ
# =========================================================================
func set_weapon(weapon_name: String) -> void:
	current_weapon_name = weapon_name
	if not weapon_holder:
		return

	if active_gun and is_instance_valid(active_gun):
		active_gun.queue_free()

	active_gun = Node3D.new()
	active_gun.name = "Gun_" + weapon_name
	weapon_holder.add_child(active_gun)

	# Примечание: так как родительский CharacterArmature имеет масштаб 100,
	# дочерние объекты внутри Weapon масштабируются соответственно на 0.00xx
	match weapon_name:
		"Shotgun":
			var gun := MODEL_SHOTGUN.instantiate()
			gun.scale = Vector3.ONE * 0.0016
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.006, 0.0, 0.0)
		"AssaultRifle":
			var gun := MODEL_RIFLE.instantiate()
			gun.scale = Vector3.ONE * 0.0032
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.007, 0.0, 0.0)
		"SniperRifle":
			var gun := MODEL_SNIPER.instantiate()
			gun.scale = Vector3.ONE * 0.0036
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.008, 0.0, 0.0)
		"RocketLauncher":
			var gun := MODEL_ROCKET.instantiate()
			gun.scale = Vector3.ONE * 0.0040
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.007, 0.0, 0.0)
		"SMG":
			var gun := MODEL_SMG.instantiate()
			gun.scale = Vector3.ONE * 0.0032
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.005, 0.0, 0.0)
		"Chainsaw":
			# Временный маркер для бензопилы
			var mesh_inst := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.15, 0.15)
			mesh_inst.mesh = box
			mesh_inst.scale = Vector3.ONE * 0.003
			mesh_inst.position = Vector3(0.002, 0.0, 0.0)
			active_gun.add_child(mesh_inst)
			muzzle_flash.position = Vector3(0.005, 0.0, 0.0)
		_: # Pistol / Revolver
			var gun := MODEL_REVOLVER.instantiate()
			gun.scale = Vector3.ONE * 0.0020
			active_gun.add_child(gun)
			muzzle_flash.position = Vector3(0.004, 0.0, 0.0)

func play_shoot_effect(w_name: String = "") -> void:
	if not w_name.is_empty() and w_name != current_weapon_name:
		set_weapon(w_name)

	# 1. Вспышка выстрела
	if muzzle_flash:
		muzzle_flash.show()
		var tw := create_tween()
		tw.tween_interval(0.06)
		tw.tween_callback(muzzle_flash.hide)

	# 2. Звук выстрела в 3D
	if shoot_sound:
		match current_weapon_name:
			"Shotgun":
				shoot_sound.stream = snd_shotgun if snd_shotgun else snd_revolver
			"AssaultRifle":
				shoot_sound.stream = snd_rifle if snd_rifle else snd_revolver
			"SniperRifle":
				shoot_sound.stream = snd_rifle if snd_rifle else snd_revolver
			"RocketLauncher":
				shoot_sound.stream = snd_rocket if snd_rocket else snd_revolver
			_:
				shoot_sound.stream = snd_revolver
		if shoot_sound.stream:
			shoot_sound.pitch_scale = randf_range(0.92, 1.08)
			shoot_sound.play()

	# 3. Анимационный выстрел, если не в пинке и не в беге
	if not is_kicking and current_anim == "CharacterArmature|Idle_Gun_Pointing":
		if anim_player and anim_player.has_animation("CharacterArmature|Idle_Gun_Shoot"):
			anim_player.play("CharacterArmature|Idle_Gun_Shoot", 0.05, 1.5)
			anim_player.queue("CharacterArmature|Idle_Gun_Pointing")

func set_flashlight(is_on: bool) -> void:
	if chest_light and not is_first_person:
		chest_light.visible = is_on

func set_first_person_mode(enabled: bool) -> void:
	is_first_person = enabled
	if char_instance:
		char_instance.visible = true
		_ensure_mesh_visible(char_instance)
	_apply_first_person_bone_hiding()
	if chest_light:
		chest_light.visible = false if enabled else chest_light.visible

func _ensure_mesh_visible(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(node as VisualInstance3D).visible = true
	for child in node.get_children():
		if child.name == "Sword":
			continue
		_ensure_mesh_visible(child)

func _apply_first_person_bone_hiding() -> void:
	if not skeleton:
		return
	var scale_val: Vector3 = Vector3(0.001, 0.001, 0.001) if is_first_person else Vector3.ONE
	var bones := ["Head", "Neck", "UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R", "Hand.L", "Hand.R"]
	for b_name in bones:
		var idx: int = skeleton.find_bone(b_name)
		if idx != -1:
			skeleton.set_bone_pose_scale(idx, scale_val)
	if active_gun:
		active_gun.visible = not is_first_person
