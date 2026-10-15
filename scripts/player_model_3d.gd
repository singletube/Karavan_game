extends Node3D
class_name PlayerModel3D

# =========================================================================
# 3D МОДЕЛЬ ПЕРСОНАЖА (Ковбой / Стрелок в пустыне с детальными текстурами)
# =========================================================================

var pelvis         : Node3D
var torso          : Node3D
var head           : Node3D
var hat            : Node3D
var face_mesh      : MeshInstance3D
var neck_mesh      : MeshInstance3D
var bandana_mesh   : MeshInstance3D

var l_leg          : Node3D
var r_leg          : Node3D
var l_arm          : Node3D
var r_arm          : Node3D
var weapon_holder  : Node3D
var active_gun     : Node3D = null
var muzzle_point   : Marker3D = null
var muzzle_flash   : OmniLight3D = null
var muzzle_quad    : MeshInstance3D = null
var shoot_sound    : AudioStreamPlayer3D = null
var chest_light    : SpotLight3D = null

# Материалы с процедурными текстурами
var mat_face       : StandardMaterial3D
var mat_torso      : StandardMaterial3D
var mat_denim      : StandardMaterial3D
var mat_leather    : StandardMaterial3D
var mat_hat        : StandardMaterial3D
var mat_skin       : StandardMaterial3D
var mat_metal      : StandardMaterial3D
var mat_bandana    : StandardMaterial3D
var mat_orange     : StandardMaterial3D # для бензопилы
var mat_dark_steel : StandardMaterial3D

# Звуки выстрелов для 3D отображения
var snd_revolver : AudioStream
var snd_shotgun  : AudioStream
var snd_rifle    : AudioStream
var snd_rocket   : AudioStream

# Анимация
var anim_time : float = 0.0
var is_moving : bool = false
var current_weapon_name: String = "Pistol"

var is_first_person : bool = false
var is_kicking      : bool = false
var kick_progress   : float = 0.0

func _ready() -> void:
	_init_materials()
	_init_sounds()
	_build_model()
	set_weapon("Pistol")

func _init_sounds() -> void:
	if ResourceLoader.exists("res://assets/audio/shoot_revolver.wav"):
		snd_revolver = load("res://assets/audio/shoot_revolver.wav") as AudioStream
	if ResourceLoader.exists("res://assets/audio/shoot_shotgun.wav"):
		snd_shotgun = load("res://assets/audio/shoot_shotgun.wav") as AudioStream
	if ResourceLoader.exists("res://assets/audio/shoot_rifle.wav"):
		snd_rifle = load("res://assets/audio/shoot_rifle.wav") as AudioStream
	if ResourceLoader.exists("res://assets/audio/shoot_rocket.wav"):
		snd_rocket = load("res://assets/audio/shoot_rocket.wav") as AudioStream

func _init_materials() -> void:
	var tex_face    : Texture2D = TextureGen.make_player_face_texture()
	var tex_torso   : Texture2D = TextureGen.make_player_torso_texture()
	var tex_denim   : Texture2D = TextureGen.make_player_denim_texture()
	var tex_leather : Texture2D = TextureGen.make_player_leather_texture()
	var tex_hat     : Texture2D = TextureGen.make_player_hat_texture()

	# 1. Лицо (глаза, усы, щетина, бандана)
	mat_face = StandardMaterial3D.new()
	mat_face.albedo_texture = tex_face
	mat_face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_face.roughness = 0.70

	# 2. Торс (кожаный жилет + клетчатая рубашка)
	mat_torso = StandardMaterial3D.new()
	mat_torso.albedo_texture = tex_torso
	mat_torso.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_torso.roughness = 0.85
	mat_torso.uv1_scale = Vector3(1.0, 1.0, 1.0)

	# 3. Джинсы (индиго деним с двойной строчкой)
	mat_denim = StandardMaterial3D.new()
	mat_denim.albedo_texture = tex_denim
	mat_denim.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_denim.roughness = 0.88
	mat_denim.uv1_scale = Vector3(1.0, 1.0, 1.0)

	# 4. Кожа (плащ, сапоги, кобура, перчатки)
	mat_leather = StandardMaterial3D.new()
	mat_leather.albedo_texture = tex_leather
	mat_leather.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_leather.roughness = 0.75

	# 5. Шляпа стетсон
	mat_hat = StandardMaterial3D.new()
	mat_hat.albedo_texture = tex_hat
	mat_hat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_hat.roughness = 0.80

	# 6. Кожа рук/шеи
	mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.76, 0.56, 0.44)
	mat_skin.roughness = 0.65

	# 7. Металл пряжек, оружия
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.65, 0.68, 0.72)
	mat_metal.metallic = 0.90
	mat_metal.roughness = 0.25

	# 8. Темная оружейная сталь
	mat_dark_steel = StandardMaterial3D.new()
	mat_dark_steel.albedo_color = Color(0.18, 0.18, 0.20)
	mat_dark_steel.metallic = 0.85
	mat_dark_steel.roughness = 0.35

	# 9. Красная бандана
	mat_bandana = StandardMaterial3D.new()
	mat_bandana.albedo_color = Color(0.72, 0.16, 0.12)
	mat_bandana.roughness = 0.8

	# 10. Оранжевый пластик бензопилы
	mat_orange = StandardMaterial3D.new()
	mat_orange.albedo_color = Color(0.95, 0.38, 0.05)
	mat_orange.roughness = 0.45

func _make_box(sz: Vector3, mat: Material, parent_node: Node3D, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	box.material = mat
	mi.mesh = box
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent_node.add_child(mi)
	return mi

func _make_cyl(height: float, top_r: float, bot_r: float, mat: Material, parent_node: Node3D, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = height
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.radial_segments = 12
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent_node.add_child(mi)
	return mi

func _build_model() -> void:
	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	pelvis.position = Vector3(0.0, 0.9, 0.0)
	add_child(pelvis)

	# Пояс и ремень с патронташем
	_make_box(Vector3(0.38, 0.14, 0.26), mat_leather, pelvis, Vector3(0, 0, 0))
	_make_box(Vector3(0.12, 0.10, 0.04), mat_metal, pelvis, Vector3(0, 0, 0.14)) # пряжка

	# Торс
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.07, 0)
	pelvis.add_child(torso)
	_make_box(Vector3(0.44, 0.44, 0.28), mat_torso, torso, Vector3(0, 0.22, 0))

	# Шея и красная бандана
	neck_mesh = _make_cyl(0.12, 0.10, 0.11, mat_skin, torso, Vector3(0, 0.48, 0))
	bandana_mesh = _make_box(Vector3(0.24, 0.10, 0.24), mat_bandana, torso, Vector3(0, 0.46, 0.02))

	# Тактический нагрудный фонарь
	chest_light = SpotLight3D.new()
	chest_light.name = "ChestFlashlight"
	chest_light.position = Vector3(0.14, 0.35, 0.18)
	chest_light.rotation = Vector3(0, 0, 0)
	chest_light.light_color = Color(0.96, 0.97, 1.0)
	chest_light.light_energy = 2.8
	chest_light.spot_range = 35.0
	chest_light.spot_angle = 36.0
	chest_light.shadow_enabled = true
	chest_light.visible = false
	torso.add_child(chest_light)

	# Голова
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.60, 0)
	torso.add_child(head)
	_make_box(Vector3(0.24, 0.26, 0.24), mat_skin, head, Vector3(0, 0, 0))

	# Лицевая пластина с детальной текстурой (глаза, брови, усы, бандана)
	face_mesh = MeshInstance3D.new()
	face_mesh.name = "FaceMesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.26)
	quad.material = mat_face
	face_mesh.mesh = quad
	face_mesh.position = Vector3(0, 0, 0.122)
	face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(face_mesh)

	# Шляпа стетсон
	hat = Node3D.new()
	hat.name = "Hat"
	hat.position = Vector3(0, 0.14, 0)
	head.add_child(hat)
	# Поля шляпы (плоский цилиндр с текстурой шляпы)
	_make_cyl(0.04, 0.38, 0.38, mat_hat, hat, Vector3(0, 0, 0))
	# Тулья шляпы
	_make_cyl(0.16, 0.20, 0.22, mat_hat, hat, Vector3(0, 0.09, 0))

	# Ноги
	l_leg = Node3D.new()
	l_leg.name = "LeftLeg"
	l_leg.position = Vector3(-0.14, -0.05, 0)
	pelvis.add_child(l_leg)
	_make_cyl(0.50, 0.11, 0.09, mat_denim, l_leg, Vector3(0, -0.25, 0))
	# Сапог
	_make_box(Vector3(0.14, 0.32, 0.24), mat_leather, l_leg, Vector3(0, -0.65, 0.04))
	# Шпора
	_make_box(Vector3(0.08, 0.04, 0.06), mat_metal, l_leg, Vector3(0, -0.72, -0.09))

	r_leg = Node3D.new()
	r_leg.name = "RightLeg"
	r_leg.position = Vector3(0.14, -0.05, 0)
	pelvis.add_child(r_leg)
	_make_cyl(0.50, 0.11, 0.09, mat_denim, r_leg, Vector3(0, -0.25, 0))
	_make_box(Vector3(0.14, 0.32, 0.24), mat_leather, r_leg, Vector3(0, -0.65, 0.04))
	_make_box(Vector3(0.08, 0.04, 0.06), mat_metal, r_leg, Vector3(0, -0.72, -0.09))

	# Руки
	l_arm = Node3D.new()
	l_arm.name = "LeftArm"
	l_arm.position = Vector3(-0.28, 0.38, 0)
	torso.add_child(l_arm)
	_make_cyl(0.48, 0.09, 0.07, mat_torso, l_arm, Vector3(0, -0.22, 0))
	_make_box(Vector3(0.10, 0.14, 0.10), mat_leather, l_arm, Vector3(0, -0.48, 0)) # перчатка

	r_arm = Node3D.new()
	r_arm.name = "RightArm"
	r_arm.position = Vector3(0.28, 0.38, 0)
	torso.add_child(r_arm)
	_make_cyl(0.48, 0.09, 0.07, mat_torso, r_arm, Vector3(0, -0.22, 0))
	_make_box(Vector3(0.10, 0.14, 0.10), mat_leather, r_arm, Vector3(0, -0.48, 0))

	# Держатель оружия в правой руке
	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
	weapon_holder.position = Vector3(0, -0.50, 0.10)
	r_arm.add_child(weapon_holder)

	# 3D звук выстрела для напарника
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

	match weapon_name:
		"Shotgun":
			# Двустволка
			_make_box(Vector3(0.06, 0.10, 0.22), mat_leather, active_gun, Vector3(0, -0.02, -0.10)) # приклад
			_make_cyl(0.55, 0.025, 0.025, mat_dark_steel, active_gun, Vector3(-0.025, 0.04, 0.22), Vector3(PI / 2.0, 0, 0))
			_make_cyl(0.55, 0.025, 0.025, mat_dark_steel, active_gun, Vector3(0.025, 0.04, 0.22), Vector3(PI / 2.0, 0, 0))
			muzzle_flash.position = Vector3(0, 0.04, 0.52)
		"AssaultRifle":
			# Автомат
			_make_box(Vector3(0.06, 0.10, 0.20), mat_leather, active_gun, Vector3(0, -0.02, -0.08))
			_make_box(Vector3(0.07, 0.10, 0.35), mat_dark_steel, active_gun, Vector3(0, 0.04, 0.12)) # ствольная коробка
			_make_box(Vector3(0.05, 0.18, 0.10), mat_metal, active_gun, Vector3(0, -0.10, 0.14), Vector3(0.2, 0, 0)) # рожок
			_make_cyl(0.45, 0.022, 0.022, mat_dark_steel, active_gun, Vector3(0, 0.04, 0.44), Vector3(PI / 2.0, 0, 0))
			muzzle_flash.position = Vector3(0, 0.04, 0.68)
		"SniperRifle":
			# Снайперская винтовка с оптикой
			_make_box(Vector3(0.06, 0.11, 0.26), mat_leather, active_gun, Vector3(0, -0.02, -0.12))
			_make_cyl(0.75, 0.024, 0.024, mat_dark_steel, active_gun, Vector3(0, 0.04, 0.38), Vector3(PI / 2.0, 0, 0))
			_make_cyl(0.24, 0.035, 0.035, mat_metal, active_gun, Vector3(0, 0.11, 0.15), Vector3(PI / 2.0, 0, 0)) # прицел
			muzzle_flash.position = Vector3(0, 0.04, 0.78)
		"RocketLauncher":
			# Ракетница (РПГ / Базука)
			_make_cyl(0.95, 0.075, 0.075, StandardMaterial3D.new(), active_gun, Vector3(0, 0.08, 0.15), Vector3(PI / 2.0, 0, 0))
			active_gun.get_child(0).material_override = mat_torso
			_make_cyl(0.14, 0.11, 0.075, mat_metal, active_gun, Vector3(0, 0.08, 0.62), Vector3(PI / 2.0, 0, 0)) # раструб
			muzzle_flash.position = Vector3(0, 0.08, 0.70)
		"Chainsaw":
			# Бензопила
			_make_box(Vector3(0.22, 0.22, 0.35), mat_orange, active_gun, Vector3(0, 0.04, 0.05)) # корпус
			_make_box(Vector3(0.03, 0.14, 0.50), mat_dark_steel, active_gun, Vector3(0, 0.04, 0.45)) # шина
			_make_box(Vector3(0.04, 0.16, 0.52), mat_metal, active_gun, Vector3(0, 0.04, 0.45)) # цепь
			muzzle_flash.position = Vector3(0, 0.04, 0.72)
		_:
			# Классический револьвер .44
			_make_box(Vector3(0.06, 0.10, 0.08), mat_leather, active_gun, Vector3(0, 0, 0)) # рукоять
			_make_cyl(0.22, 0.028, 0.028, mat_metal, active_gun, Vector3(0, 0.04, 0.12), Vector3(PI / 2.0, 0, 0)) # ствол
			_make_cyl(0.09, 0.05, 0.05, mat_dark_steel, active_gun, Vector3(0, 0.04, 0.03), Vector3(PI / 2.0, 0, 0)) # барабан
			muzzle_flash.position = Vector3(0, 0.04, 0.25)

func play_shoot_effect(w_name: String = "") -> void:
	if not w_name.is_empty() and w_name != current_weapon_name:
		set_weapon(w_name)

	# 1. Визуальная вспышка выстрела
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

	# 3. Анимационная отдача руки
	if r_arm:
		r_arm.rotation.x -= 0.35
		var tw_arm := create_tween()
		tw_arm.tween_property(r_arm, "rotation:x", -0.2, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_flashlight(is_on: bool) -> void:
	if chest_light and not is_first_person:
		chest_light.visible = is_on

func set_first_person_mode(enabled: bool) -> void:
	is_first_person = enabled
	if head:
		head.visible = !enabled
	if neck_mesh:
		neck_mesh.visible = !enabled
	if bandana_mesh:
		bandana_mesh.visible = !enabled
	if l_arm:
		l_arm.visible = !enabled
	if r_arm:
		r_arm.visible = !enabled
	if chest_light:
		chest_light.visible = false
	if pelvis:
		# Сильно сдвигаем тело назад относительно камеры (на 38 см),
		# чтобы плечи и грудь не лезли в экран и не мешали обзору
		pelvis.position.z = -0.38 if enabled else 0.0

func play_kick() -> void:
	is_kicking = true
	kick_progress = 0.0

func update_animation(delta: float, moving: bool, velocity_length: float, is_crouching: bool = false) -> void:
	is_moving = moving

	# 1. Анимация мощного пинка ногой (Spartan Kick)
	if is_kicking:
		kick_progress += delta * 2.4
		var k: float = sin(minf(kick_progress, 1.0) * PI)
		# Правая нога резко взлетает вперед и вверх прямо перед взглядом игрока
		r_leg.rotation.x = -k * 1.55
		r_leg.position.z = k * 0.78
		r_leg.position.y = -0.05 + k * 0.38
		# Корпус отклоняется назад от силы и отдачи пинка
		torso.rotation.x = k * 0.18

		if not is_first_person and l_arm:
			l_arm.rotation.x = k * 0.40

		if kick_progress >= 1.0:
			is_kicking = false
			r_leg.position = Vector3(0.14, -0.05, 0)
			torso.rotation.x = 0.0
		return

	# 2. Анимация приседания (Crouch)
	var target_pelvis_y: float = 0.55 if is_crouching else 0.90
	if is_crouching:
		l_leg.rotation.x = lerpf(l_leg.rotation.x, -0.45, delta * 12.0)
		r_leg.rotation.x = lerpf(r_leg.rotation.x, -0.45, delta * 12.0)
		r_leg.position = r_leg.position.lerp(Vector3(0.14, -0.05, 0), delta * 12.0)
		pelvis.position.y = lerpf(pelvis.position.y, target_pelvis_y, delta * 12.0)
		torso.rotation.x = lerpf(torso.rotation.x, 0.15, delta * 12.0) # наклон вперед в приседе
		return

	# 3. Анимация ходьбы / бега
	if is_moving and velocity_length > 0.1:
		anim_time += delta * minf(velocity_length, 9.0) * 2.4
		var leg_swing: float = sin(anim_time) * 0.55
		l_leg.rotation.x = leg_swing
		r_leg.rotation.x = -leg_swing
		r_leg.position = Vector3(0.14, -0.05, 0)
		if not is_first_person:
			l_arm.rotation.x = -leg_swing * 0.6
			r_arm.rotation.x = -0.25 + leg_swing * 0.25
		pelvis.position.y = 0.9 + abs(sin(anim_time * 2.0)) * 0.04
		torso.rotation.x = lerpf(torso.rotation.x, 0.0, delta * 10.0)
	else:
		# Плавный возврат в спокойную стойку
		l_leg.rotation.x = lerpf(l_leg.rotation.x, 0.0, delta * 10.0)
		r_leg.rotation.x = lerpf(r_leg.rotation.x, 0.0, delta * 10.0)
		r_leg.position = r_leg.position.lerp(Vector3(0.14, -0.05, 0), delta * 10.0)
		if not is_first_person:
			l_arm.rotation.x = lerpf(l_arm.rotation.x, 0.0, delta * 10.0)
			r_arm.rotation.x = lerpf(r_arm.rotation.x, -0.2, delta * 10.0) # оружие наготове
		pelvis.position.y = lerpf(pelvis.position.y, 0.9, delta * 10.0)
		torso.rotation.x = lerpf(torso.rotation.x, 0.0, delta * 10.0)
