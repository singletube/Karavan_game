extends Node3D
class_name PlayerModel3D

# --- 3D Модель Персонажа (Ковбой / Стрелок в пустыне) ---

var pelvis     : Node3D
var torso      : Node3D
var head       : Node3D
var hat        : Node3D

var l_leg      : Node3D
var r_leg      : Node3D
var l_arm      : Node3D
var r_arm      : Node3D
var weapon_holster : Node3D

# Материалы
var mat_leather : StandardMaterial3D
var mat_fabric  : StandardMaterial3D
var mat_skin    : StandardMaterial3D
var mat_denim   : StandardMaterial3D
var mat_metal   : StandardMaterial3D
var mat_bandana : StandardMaterial3D

# Анимация
var anim_time : float = 0.0
var is_moving : bool = false

func _ready() -> void:
	_init_materials()
	_build_model()

func _init_materials() -> void:
	# Коричневая кожа плаща и шляпы
	mat_leather = StandardMaterial3D.new()
	mat_leather.albedo_color = Color(0.24, 0.16, 0.11)
	mat_leather.roughness = 0.85

	# Пыльная серо-коричневая ткань рубашки
	mat_fabric = StandardMaterial3D.new()
	mat_fabric.albedo_color = Color(0.48, 0.44, 0.38)
	mat_fabric.roughness = 0.90

	# Лицо / кожа
	mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.74, 0.56, 0.44)
	mat_skin.roughness = 0.65

	# Джинсы / темные штаны
	mat_denim = StandardMaterial3D.new()
	mat_denim.albedo_color = Color(0.18, 0.22, 0.28)
	mat_denim.roughness = 0.88

	# Пряжки, шпоры, оружие
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.40, 0.42, 0.45)
	mat_metal.metallic = 0.9
	mat_metal.roughness = 0.35

	# Красная бандана на шее
	mat_bandana = StandardMaterial3D.new()
	mat_bandana.albedo_color = Color(0.68, 0.18, 0.14)
	mat_bandana.roughness = 0.8

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
	pelvis.position = Vector3(0.0, 0.9, 0.0)
	add_child(pelvis)

	# Пояс и ремень с патронташем
	_make_box(Vector3(0.38, 0.14, 0.26), mat_leather, pelvis, Vector3(0, 0, 0))
	_make_box(Vector3(0.12, 0.10, 0.04), mat_metal, pelvis, Vector3(0, 0, 0.14)) # пряжка

	# Торс
	torso = Node3D.new()
	torso.position = Vector3(0, 0.07, 0)
	pelvis.add_child(torso)
	_make_box(Vector3(0.42, 0.44, 0.28), mat_fabric, torso, Vector3(0, 0.22, 0))

	# Кожаный жилет/плащ поверх
	_make_box(Vector3(0.45, 0.46, 0.30), mat_leather, torso, Vector3(0, 0.22, -0.01))

	# Шея и бандана
	_make_cyl(0.12, 0.10, 0.11, mat_skin, torso, Vector3(0, 0.48, 0))
	_make_box(Vector3(0.24, 0.10, 0.24), mat_bandana, torso, Vector3(0, 0.46, 0.02))

	# Голова
	head = Node3D.new()
	head.position = Vector3(0, 0.60, 0)
	torso.add_child(head)
	_make_box(Vector3(0.24, 0.26, 0.24), mat_skin, head, Vector3(0, 0, 0))

	# Шляпа стетсон
	hat = Node3D.new()
	hat.position = Vector3(0, 0.14, 0)
	head.add_child(hat)
	# Поля шляпы (плоский цилиндр)
	_make_cyl(0.04, 0.38, 0.38, mat_leather, hat, Vector3(0, 0, 0))
	# Тулья шляпы
	_make_cyl(0.16, 0.20, 0.22, mat_leather, hat, Vector3(0, 0.09, 0))

	# Ноги
	l_leg = Node3D.new()
	l_leg.position = Vector3(-0.14, -0.05, 0)
	pelvis.add_child(l_leg)
	_make_cyl(0.50, 0.11, 0.09, mat_denim, l_leg, Vector3(0, -0.25, 0))
	# Сапог
	_make_box(Vector3(0.14, 0.32, 0.24), mat_leather, l_leg, Vector3(0, -0.65, 0.04))

	r_leg = Node3D.new()
	r_leg.position = Vector3(0.14, -0.05, 0)
	pelvis.add_child(r_leg)
	_make_cyl(0.50, 0.11, 0.09, mat_denim, r_leg, Vector3(0, -0.25, 0))
	_make_box(Vector3(0.14, 0.32, 0.24), mat_leather, r_leg, Vector3(0, -0.65, 0.04))

	# Руки
	l_arm = Node3D.new()
	l_arm.position = Vector3(-0.28, 0.38, 0)
	torso.add_child(l_arm)
	_make_cyl(0.48, 0.09, 0.07, mat_fabric, l_arm, Vector3(0, -0.22, 0))
	_make_box(Vector3(0.10, 0.14, 0.10), mat_leather, l_arm, Vector3(0, -0.48, 0)) # перчатка

	r_arm = Node3D.new()
	r_arm.position = Vector3(0.28, 0.38, 0)
	torso.add_child(r_arm)
	_make_cyl(0.48, 0.09, 0.07, mat_fabric, r_arm, Vector3(0, -0.22, 0))
	_make_box(Vector3(0.10, 0.14, 0.10), mat_leather, r_arm, Vector3(0, -0.48, 0))

	# Оружие в правой руке (3D Револьвер)
	var gun := Node3D.new()
	gun.position = Vector3(0, -0.50, 0.10)
	r_arm.add_child(gun)
	_make_box(Vector3(0.06, 0.10, 0.08), mat_leather, gun, Vector3(0, 0, 0)) # рукоять
	_make_cyl(0.18, 0.03, 0.03, mat_metal, gun, Vector3(0, 0.04, 0.10), Vector3(PI / 2.0, 0, 0)) # ствол
	_make_cyl(0.08, 0.05, 0.05, mat_metal, gun, Vector3(0, 0.04, 0.02), Vector3(PI / 2.0, 0, 0)) # барабан

func update_animation(delta: float, moving: bool, velocity_length: float) -> void:
	is_moving = moving
	if is_moving and velocity_length > 0.1:
		anim_time += delta * velocity_length * 2.2
		var leg_swing: float = sin(anim_time) * 0.55
		l_leg.rotation.x = leg_swing
		r_leg.rotation.x = -leg_swing
		l_arm.rotation.x = -leg_swing * 0.6
		r_arm.rotation.x = leg_swing * 0.4
		pelvis.position.y = 0.9 + abs(sin(anim_time * 2.0)) * 0.04
	else:
		# Плавный возврат в спокойную стойку
		l_leg.rotation.x = lerpf(l_leg.rotation.x, 0.0, delta * 10.0)
		r_leg.rotation.x = lerpf(r_leg.rotation.x, 0.0, delta * 10.0)
		l_arm.rotation.x = lerpf(l_arm.rotation.x, 0.0, delta * 10.0)
		r_arm.rotation.x = lerpf(r_arm.rotation.x, -0.2, delta * 10.0) # револьвер наготове
		pelvis.position.y = lerpf(pelvis.position.y, 0.9, delta * 10.0)
