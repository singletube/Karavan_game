extends Node3D
class_name SkullDroneModel3D

# --- Ссылки на элементы модели для анимации ---
var cranium_mesh       : MeshInstance3D = null
var eye_sensor         : MeshInstance3D = null
var eye_material       : StandardMaterial3D = null
var jaw_node           : Node3D = null
var left_thruster      : Node3D = null
var right_thruster     : Node3D = null
var thruster_particles : CPUParticles3D = null
var beacon_light       : OmniLight3D = null
var scanner_light      : SpotLight3D = null
var scanner_cone       : MeshInstance3D = null
var scanner_cone_mat   : StandardMaterial3D = null

var _anim_time         : float = 0.0
var _beacon_timer      : float = 0.0
var is_scanning        : bool  = false
var is_fleeing         : bool  = false

func _ready() -> void:
	_build_model()

func _build_model() -> void:
	# 1. Череп (Верхний купол / Cranium)
	cranium_mesh = MeshInstance3D.new()
	cranium_mesh.name = "Cranium"
	var skull_sphere := SphereMesh.new()
	skull_sphere.radius = 0.44
	skull_sphere.height = 0.88
	cranium_mesh.mesh = skull_sphere
	cranium_mesh.scale = Vector3(1.0, 0.90, 1.15)
	cranium_mesh.position = Vector3(0.0, 0.12, 0.0)

	var skull_mat := StandardMaterial3D.new()
	skull_mat.albedo_color = Color(0.82, 0.80, 0.74) # Костяной оттенок
	skull_mat.roughness = 0.55
	skull_mat.metallic = 0.25
	cranium_mesh.material_override = skull_mat
	add_child(cranium_mesh)

	# Кибернетическая бронепластина на темени
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.36, 0.12, 0.55)
	var mi_plate := MeshInstance3D.new()
	mi_plate.mesh = plate_mesh
	mi_plate.position = Vector3(0.0, 0.48, -0.05)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.18, 0.19, 0.22)
	plate_mat.metallic = 0.90
	plate_mat.roughness = 0.30
	mi_plate.material_override = plate_mat
	add_child(mi_plate)

	# 2. Глазницы (Левая - оптический красный сканер, Правая - темная с диодами)
	# Левый глазной сенсор
	var eye_casing := MeshInstance3D.new()
	var casing_cyl := CylinderMesh.new()
	casing_cyl.top_radius = 0.13
	casing_cyl.bottom_radius = 0.13
	casing_cyl.height = 0.18
	eye_casing.mesh = casing_cyl
	eye_casing.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	eye_casing.position = Vector3(-0.19, 0.06, 0.38)
	var casing_mat := StandardMaterial3D.new()
	casing_mat.albedo_color = Color(0.12, 0.12, 0.14)
	casing_mat.metallic = 0.95
	eye_casing.material_override = casing_mat
	add_child(eye_casing)

	eye_sensor = MeshInstance3D.new()
	var eye_sph := SphereMesh.new()
	eye_sph.radius = 0.10
	eye_sph.height = 0.20
	eye_sensor.mesh = eye_sph
	eye_sensor.position = Vector3(-0.19, 0.06, 0.46)
	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.10, 0.10)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.8, 0.15, 0.15)
	eye_material.emission_energy_multiplier = 2.0
	eye_sensor.material_override = eye_material
	add_child(eye_sensor)

	# Правая глазница (кибернетический датчик с желтым микродиодом)
	var r_eye := MeshInstance3D.new()
	var r_eye_mesh := SphereMesh.new()
	r_eye_mesh.radius = 0.11
	r_eye_mesh.height = 0.22
	r_eye.mesh = r_eye_mesh
	r_eye.position = Vector3(0.19, 0.06, 0.36)
	var r_eye_mat := StandardMaterial3D.new()
	r_eye_mat.albedo_color = Color(0.08, 0.08, 0.08)
	r_eye_mat.metallic = 0.8
	r_eye.material_override = r_eye_mat
	add_child(r_eye)

	var sub_diode := MeshInstance3D.new()
	var diode_mesh := SphereMesh.new()
	diode_mesh.radius = 0.04
	diode_mesh.height = 0.08
	sub_diode.mesh = diode_mesh
	sub_diode.position = Vector3(0.19, 0.06, 0.45)
	var diode_mat := StandardMaterial3D.new()
	diode_mat.albedo_color = Color(1.0, 0.7, 0.1)
	diode_mat.emission_enabled = true
	diode_mat.emission = Color(1.5, 0.8, 0.15)
	sub_diode.material_override = diode_mat
	add_child(sub_diode)

	# Носовая полость (темный треугольник)
	var nose := MeshInstance3D.new()
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(0.12, 0.15, 0.10)
	nose.mesh = nose_mesh
	nose.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	nose.position = Vector3(0.0, -0.06, 0.44)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.06, 0.05, 0.05)
	nose.material_override = nose_mat
	add_child(nose)

	# 3. Нижняя челюсть с металлическими зубьями (Jaw)
	jaw_node = Node3D.new()
	jaw_node.name = "JawNode"
	jaw_node.position = Vector3(0.0, -0.16, 0.08)

	var jaw_box := MeshInstance3D.new()
	var j_mesh := BoxMesh.new()
	j_mesh.size = Vector3(0.36, 0.14, 0.32)
	jaw_box.mesh = j_mesh
	jaw_box.position = Vector3(0.0, -0.06, 0.10)
	var jaw_mat := StandardMaterial3D.new()
	jaw_mat.albedo_color = Color(0.24, 0.25, 0.28)
	jaw_mat.metallic = 0.85
	jaw_mat.roughness = 0.4
	jaw_box.material_override = jaw_mat
	jaw_node.add_child(jaw_box)

	# Металлические зубы (хромированная решетка)
	for i in range(5):
		var tooth := MeshInstance3D.new()
		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(0.045, 0.08, 0.045)
		tooth.mesh = t_mesh
		tooth.position = Vector3(-0.10 + float(i) * 0.05, 0.02, 0.24)
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.9, 0.9, 0.9)
		t_mat.metallic = 0.95
		tooth.material_override = t_mat
		jaw_node.add_child(tooth)

	add_child(jaw_node)

	# 4. Боковые репульсорные гондолы (Thrusters)
	left_thruster = _create_thruster_pod(-1.0)
	add_child(left_thruster)

	right_thruster = _create_thruster_pod(1.0)
	add_child(right_thruster)

	# Частицы реактивных выхлопов (турбулентные искры)
	thruster_particles = CPUParticles3D.new()
	thruster_particles.name = "ThrusterSparks"
	thruster_particles.amount = 28
	thruster_particles.lifetime = 0.4
	thruster_particles.speed_scale = 1.2
	thruster_particles.explosiveness = 0.05
	thruster_particles.randomness = 0.5
	thruster_particles.direction = Vector3(0.0, -1.0, -0.4)
	thruster_particles.spread = 22.0
	thruster_particles.initial_velocity_min = 2.0
	thruster_particles.initial_velocity_max = 4.5
	thruster_particles.gravity = Vector3(0.0, 1.5, 0.0)
	thruster_particles.color = Color(0.3, 0.8, 1.0, 0.85)

	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.025
	p_mesh.height = 0.05
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.4, 0.85, 1.0)
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.5, 1.2, 2.0)
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thruster_particles.mesh = p_mesh
	thruster_particles.position = Vector3(0.0, -0.15, -0.28)
	add_child(thruster_particles)

	# 5. Антенна с мигающим сигнальным маячком
	var mast := MeshInstance3D.new()
	var m_cyl := CylinderMesh.new()
	m_cyl.top_radius = 0.012
	m_cyl.bottom_radius = 0.018
	m_cyl.height = 0.35
	mast.mesh = m_cyl
	mast.position = Vector3(0.0, 0.65, -0.12)
	add_child(mast)

	beacon_light = OmniLight3D.new()
	beacon_light.light_color = Color(1.0, 0.15, 0.15)
	beacon_light.light_energy = 1.5
	beacon_light.omni_range = 3.5
	beacon_light.position = Vector3(0.0, 0.82, -0.12)
	add_child(beacon_light)

	# 6. Сканирующий красный прожектор (SpotLight3D)
	scanner_light = SpotLight3D.new()
	scanner_light.name = "ScannerLight"
	scanner_light.light_color = Color(1.0, 0.12, 0.12)
	scanner_light.light_energy = 2.6
	scanner_light.spot_range = 28.0
	scanner_light.spot_angle = 32.0
	scanner_light.spot_attenuation = 0.65
	scanner_light.position = Vector3(-0.19, 0.06, 0.48)
	scanner_light.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	add_child(scanner_light)

	# 7. Видимый полупрозрачный луч сканера (Волюметрический конус)
	scanner_cone = MeshInstance3D.new()
	scanner_cone.name = "ScannerCone"
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.06
	cone_mesh.bottom_radius = 3.6
	cone_mesh.height = 18.0
	scanner_cone.mesh = cone_mesh
	scanner_cone.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
	scanner_cone.position = Vector3(-0.19, -3.8, 8.2)

	scanner_cone_mat = StandardMaterial3D.new()
	scanner_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner_cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	scanner_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	scanner_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scanner_cone_mat.albedo_color = Color(1.0, 0.12, 0.12, 0.14)
	scanner_cone.material_override = scanner_cone_mat
	add_child(scanner_cone)

func _create_thruster_pod(side: float) -> Node3D:
	var pod := Node3D.new()
	pod.position = Vector3(side * 0.58, 0.0, -0.10)

	# Пилон крепления к черепу
	var pylon := MeshInstance3D.new()
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.24, 0.06, 0.14)
	pylon.mesh = p_mesh
	pylon.position = Vector3(-side * 0.10, 0.0, 0.0)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 0.22, 0.25)
	p_mat.metallic = 0.9
	pylon.material_override = p_mat
	pod.add_child(pylon)

	# Корпус турбины
	var engine := MeshInstance3D.new()
	var eng_mesh := CylinderMesh.new()
	eng_mesh.top_radius = 0.13
	eng_mesh.bottom_radius = 0.15
	eng_mesh.height = 0.42
	engine.mesh = eng_mesh
	engine.rotation_degrees = Vector3(20.0, 0.0, 0.0)
	var eng_mat := StandardMaterial3D.new()
	eng_mat.albedo_color = Color(0.14, 0.15, 0.18)
	eng_mat.metallic = 0.95
	eng_mat.roughness = 0.25
	engine.material_override = eng_mat
	pod.add_child(engine)

	# Сопло с плазменным свечением
	var nozzle := MeshInstance3D.new()
	var noz_mesh := CylinderMesh.new()
	noz_mesh.top_radius = 0.11
	noz_mesh.bottom_radius = 0.11
	noz_mesh.height = 0.04
	nozzle.mesh = noz_mesh
	nozzle.position = Vector3(0.0, -0.21, -0.08)
	var noz_mat := StandardMaterial3D.new()
	noz_mat.albedo_color = Color(0.2, 0.7, 1.0)
	noz_mat.emission_enabled = true
	noz_mat.emission = Color(0.4, 1.1, 2.2)
	nozzle.material_override = noz_mat
	pod.add_child(nozzle)

	return pod

func _process(delta: float) -> void:
	_anim_time += delta

	# 1. Мигание сигнального маячка на антенне (2 раза в секунду)
	_beacon_timer += delta
	if beacon_light:
		beacon_light.visible = fmod(_beacon_timer, 0.5) < 0.25

	# 2. Анимация парения и работы челюсти
	if jaw_node:
		var jaw_offset: float = sin(_anim_time * 2.2) * 0.02
		if is_scanning:
			jaw_offset += sin(_anim_time * 9.0) * 0.03 # Дрожит/стрекочет при сканировании
		jaw_node.position.y = -0.16 + jaw_offset

	# 3. Визуальный фидбек сканирования (пульсация красного луча)
	if is_scanning:
		var pulse: float = 0.5 + 0.5 * sin(_anim_time * 10.0)
		if scanner_light:
			scanner_light.light_energy = 2.4 + pulse * 2.8
			scanner_light.light_color = Color(1.0, 0.15 + pulse * 0.25, 0.15)
		if scanner_cone_mat:
			scanner_cone_mat.albedo_color.a = 0.14 + pulse * 0.18
		if eye_material:
			eye_material.emission_energy_multiplier = 2.2 + pulse * 2.5
	else:
		if scanner_light:
			scanner_light.light_energy = 1.4
			scanner_light.light_color = Color(0.9, 0.2, 0.2)
		if scanner_cone_mat:
			scanner_cone_mat.albedo_color.a = 0.08
		if eye_material:
			eye_material.emission_energy_multiplier = 1.5

	# 4. Режим бегства (форсаж турбин)
	if is_fleeing and thruster_particles:
		thruster_particles.amount = 45
		thruster_particles.speed_scale = 2.4
		thruster_particles.initial_velocity_min = 6.0
		thruster_particles.initial_velocity_max = 12.0
		if scanner_cone:
			scanner_cone.visible = false
		if scanner_light:
			scanner_light.visible = false
