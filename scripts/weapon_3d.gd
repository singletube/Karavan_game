extends Node3D

# --- Базовые трансформации для выравнивания по центру ---
const BASE_POS := Vector3(0.0, -0.19, -0.42)
const BASE_ROT := Vector3(0.0, 0.0, 0.0)

var current_weapon_idx : int = 0
var weapon_nodes       : Array = []

# Физические параметры отдачи
var recoil_z   : float = 0.0
var recoil_rot : float = 0.0
var bob_time   : float = 0.0

@onready var muzzle_flash_3d : Node3D = $MuzzleFlash3D

func _ready() -> void:
	position = BASE_POS
	rotation = BASE_ROT
	_build_3d_weapons()
	_build_muzzle_flash()
	set_active_weapon(0)

var reload_tween : Tween = null
var is_reloading : bool = false

func play_reload(idx: int, duration: float) -> void:
	cancel_reload()
	is_reloading = true

	reload_tween = create_tween()

	match idx:
		0: # --- РЕВОЛЬВЕР ---
			# 1. Откидывание вправо-вниз и открытие барабана
			reload_tween.tween_property(self, "position", Vector3(0.04, BASE_POS.y - 0.09, BASE_POS.z + 0.03), duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", Vector3(deg_to_rad(-12.0), deg_to_rad(10.0), deg_to_rad(36.0)), duration * 0.25)
			# 2. Выброс гильз (встряска)
			reload_tween.tween_property(self, "position:y", BASE_POS.y - 0.05, duration * 0.15).set_trans(Tween.TRANS_BACK)
			reload_tween.tween_property(self, "position:y", BASE_POS.y - 0.09, duration * 0.15)
			# 3. Вставка патронов (спидлоадер щелкает)
			reload_tween.tween_property(self, "position", Vector3(0.02, BASE_POS.y - 0.07, BASE_POS.z), duration * 0.20)
			# 4. Защелкивание барабана и взвод курка по центру
			reload_tween.tween_property(self, "position", BASE_POS, duration * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", BASE_ROT, duration * 0.25)

		1: # --- ДВУСТВОЛКА (ПЕРЕЛОМ СТВОЛОВ) ---
			# 1. Резкий перелом стволов вниз
			reload_tween.tween_property(self, "position", Vector3(0.0, BASE_POS.y - 0.08, BASE_POS.z + 0.04), duration * 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", Vector3(deg_to_rad(-48.0), 0.0, deg_to_rad(-4.0)), duration * 0.28)
			# 2. Вылет гильз и вставка двух патронов 12 калибра
			reload_tween.tween_property(self, "position:y", BASE_POS.y - 0.09, duration * 0.32)
			# 3. Резкий смачный захлоп стволов вверх!
			reload_tween.tween_property(self, "rotation:x", deg_to_rad(14.0), duration * 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# 4. Возврат в боевое положение
			reload_tween.tween_property(self, "position", BASE_POS, duration * 0.20)
			reload_tween.parallel().tween_property(self, "rotation", BASE_ROT, duration * 0.20)

		2: # --- АВТОМАТ КАРАВАНА ---
			# 1. Наклон влево, сброс рожка
			reload_tween.tween_property(self, "position", Vector3(-0.03, BASE_POS.y - 0.07, BASE_POS.z + 0.02), duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", Vector3(deg_to_rad(-8.0), deg_to_rad(-6.0), deg_to_rad(-22.0)), duration * 0.25)
			# 2. Вбивание нового магазина снизу
			reload_tween.tween_property(self, "position:y", BASE_POS.y - 0.02, duration * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# 3. Передергивание затвора (откат назад)
			reload_tween.tween_property(self, "position:z", BASE_POS.z + 0.06, duration * 0.25)
			reload_tween.parallel().tween_property(self, "rotation", Vector3(deg_to_rad(6.0), 0.0, 0.0), duration * 0.25)
			# 4. Сброс затвора и возврат
			reload_tween.tween_property(self, "position", BASE_POS, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", BASE_ROT, duration * 0.25)

		3: # --- РАКЕТНИЦА RPG ---
			# 1. Опускание трубы и наклон задней части вверх
			reload_tween.tween_property(self, "position", Vector3(0.0, BASE_POS.y - 0.12, BASE_POS.z + 0.05), duration * 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", Vector3(deg_to_rad(26.0), 0.0, deg_to_rad(5.0)), duration * 0.30)
			# 2. Вставка новой ракеты спереди в раструб
			reload_tween.tween_property(self, "position:z", BASE_POS.z + 0.02, duration * 0.35)
			# 3. Защелкивание и фиксация
			reload_tween.tween_property(self, "rotation:x", deg_to_rad(10.0), duration * 0.20)
			# 4. Вскидывание на плечо по центру
			reload_tween.tween_property(self, "position", BASE_POS, duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			reload_tween.parallel().tween_property(self, "rotation", BASE_ROT, duration * 0.35)

	reload_tween.finished.connect(func(): is_reloading = false)

func cancel_reload() -> void:
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
	is_reloading = false

func set_active_weapon(idx: int) -> void:
	cancel_reload()
	current_weapon_idx = idx
	for i in range(weapon_nodes.size()):
		var w: Node3D = weapon_nodes[i] as Node3D
		if w:
			w.visible = (i == idx)

	# Анимация доставания (подъем снизу вверх в 3D)
	position.y = BASE_POS.y - 0.15
	rotation.x = deg_to_rad(-18.0)

func play_recoil(kick_z: float, kick_rot: float) -> void:
	if is_reloading:
		return
	recoil_z += kick_z
	recoil_rot += kick_rot
	_show_muzzle_flash()

func _show_muzzle_flash() -> void:
	if muzzle_flash_3d:
		muzzle_flash_3d.show()
		var timer: SceneTreeTimer = get_tree().create_timer(0.05)
		timer.timeout.connect(func(): if muzzle_flash_3d: muzzle_flash_3d.hide())

func update_transform(delta: float, is_moving: bool, move_speed: float) -> void:
	if is_reloading:
		return

	# 1. Затухание отдачи (пружина)
	recoil_z = lerp(recoil_z, 0.0, delta * 14.0)
	recoil_rot = lerp(recoil_rot, 0.0, delta * 16.0)

	# 2. Покачивание оружия в 3D при ходьбе (Bobbing)
	var bob_x: float = 0.0
	var bob_y: float = 0.0
	if is_moving:
		bob_time += delta * move_speed * 1.8
		bob_x = sin(bob_time) * 0.014
		bob_y = abs(cos(bob_time)) * 0.010
	else:
		bob_time = move_toward(bob_time, 0.0, delta * 10.0)

	# 3. Применение финальной позиции и вращения (строго отцентрировано по X = 0.0)
	var target_pos := Vector3(
		BASE_POS.x + bob_x,
		BASE_POS.y + bob_y,
		BASE_POS.z + recoil_z
	)
	var target_rot := Vector3(
		BASE_ROT.x + deg_to_rad(recoil_rot) + (sin(bob_time) * 0.02 if is_moving else 0.0),
		BASE_ROT.y,
		BASE_ROT.z + (cos(bob_time) * 0.02 if is_moving else 0.0)
	)

	position = position.lerp(target_pos, delta * 22.0)
	rotation.x = lerp_angle(rotation.x, target_rot.x, delta * 22.0)
	rotation.y = lerp_angle(rotation.y, target_rot.y, delta * 22.0)
	rotation.z = lerp_angle(rotation.z, target_rot.z, delta * 22.0)


# =========================================================================
# ПОСТРОЕНИЕ 3D МОДЕЛЕЙ ОРУЖИЯ
# =========================================================================
func _build_3d_weapons() -> void:
	# Материалы PBR
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.20, 0.20, 0.24)
	mat_metal.metallic = 0.90
	mat_metal.roughness = 0.30

	var mat_metal_dark := StandardMaterial3D.new()
	mat_metal_dark.albedo_color = Color(0.12, 0.12, 0.14)
	mat_metal_dark.metallic = 0.80
	mat_metal_dark.roughness = 0.45

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.38, 0.20, 0.10)
	mat_wood.roughness = 0.75

	var mat_khaki := StandardMaterial3D.new()
	mat_khaki.albedo_color = Color(0.26, 0.32, 0.22)
	mat_khaki.metallic = 0.35
	mat_khaki.roughness = 0.55

	var mat_warhead := StandardMaterial3D.new()
	mat_warhead.albedo_color = Color(0.80, 0.16, 0.12)
	mat_warhead.roughness = 0.40

	# --- 1. РЕВОЛЬВЕР .44 (Слот 1) ---
	var rev := Node3D.new()
	rev.name = "Weapon3D_Revolver"
	add_child(rev)
	weapon_nodes.append(rev)

	# Ствол
	var rev_barrel := _create_box(Vector3(0.038, 0.045, 0.30), mat_metal)
	rev_barrel.position = Vector3(0.0, 0.02, -0.15)
	rev.add_child(rev_barrel)

	# Мушка
	var rev_sight := _create_box(Vector3(0.008, 0.018, 0.015), mat_metal_dark)
	rev_sight.position = Vector3(0.0, 0.052, -0.28)
	rev.add_child(rev_sight)

	# Барабан
	var rev_cyl := _create_cylinder(0.034, 0.075, mat_metal_dark)
	rev_cyl.rotation.x = deg_to_rad(90.0)
	rev_cyl.position = Vector3(0.0, 0.01, -0.01)
	rev.add_child(rev_cyl)

	# Рукоятка
	var rev_grip := _create_box(Vector3(0.036, 0.11, 0.055), mat_wood)
	rev_grip.rotation.x = deg_to_rad(-22.0)
	rev_grip.position = Vector3(0.0, -0.065, 0.04)
	rev.add_child(rev_grip)

	# --- 2. ОБРЕЗ ДВУСТВОЛКИ (Слот 2) ---
	var shot := Node3D.new()
	shot.name = "Weapon3D_Shotgun"
	add_child(shot)
	weapon_nodes.append(shot)

	# Левый ствол
	var s_barrel_l := _create_cylinder(0.024, 0.38, mat_metal_dark)
	s_barrel_l.rotation.x = deg_to_rad(90.0)
	s_barrel_l.position = Vector3(-0.026, 0.02, -0.16)
	shot.add_child(s_barrel_l)

	# Правый ствол
	var s_barrel_r := _create_cylinder(0.024, 0.38, mat_metal_dark)
	s_barrel_r.rotation.x = deg_to_rad(90.0)
	s_barrel_r.position = Vector3(0.026, 0.02, -0.16)
	shot.add_child(s_barrel_r)

	# Прицельная планка сверху
	var s_rib := _create_box(Vector3(0.016, 0.012, 0.38), mat_metal)
	s_rib.position = Vector3(0.0, 0.038, -0.16)
	shot.add_child(s_rib)

	# Мушка посередине
	var s_bead := _create_box(Vector3(0.008, 0.012, 0.012), mat_metal)
	s_bead.position = Vector3(0.0, 0.048, -0.34)
	shot.add_child(s_bead)

	# Деревянное цевье снизу
	var s_forend := _create_box(Vector3(0.088, 0.042, 0.22), mat_wood)
	s_forend.position = Vector3(0.0, -0.015, -0.09)
	shot.add_child(s_forend)

	# Деревянная рукоятка ложи
	var s_stock := _create_box(Vector3(0.048, 0.09, 0.08), mat_wood)
	s_stock.rotation.x = deg_to_rad(-24.0)
	s_stock.position = Vector3(0.0, -0.06, 0.06)
	shot.add_child(s_stock)

	# --- 3. АВТОМАТ КАРАВАНА (Слот 3) ---
	var rif := Node3D.new()
	rif.name = "Weapon3D_Rifle"
	add_child(rif)
	weapon_nodes.append(rif)

	# Ствольная коробка
	var r_rec := _create_box(Vector3(0.048, 0.068, 0.26), mat_metal_dark)
	r_rec.position = Vector3(0.0, 0.02, -0.08)
	rif.add_child(r_rec)

	# Ствол с пламегасителем
	var r_bar := _create_cylinder(0.014, 0.28, mat_metal)
	r_bar.rotation.x = deg_to_rad(90.0)
	r_bar.position = Vector3(0.0, 0.024, -0.32)
	rif.add_child(r_bar)

	# Мушка кольцевая
	var r_sight := _create_box(Vector3(0.012, 0.028, 0.015), mat_metal)
	r_sight.position = Vector3(0.0, 0.052, -0.38)
	rif.add_child(r_sight)

	# Цевье
	var r_guard := _create_box(Vector3(0.054, 0.052, 0.16), mat_wood)
	r_guard.position = Vector3(0.0, 0.015, -0.21)
	rif.add_child(r_guard)

	# Изогнутый магазин
	var r_mag := _create_box(Vector3(0.032, 0.14, 0.065), mat_metal_dark)
	r_mag.rotation.x = deg_to_rad(18.0)
	r_mag.position = Vector3(0.0, -0.08, -0.10)
	rif.add_child(r_mag)

	# Пистолетная рукоятка
	var r_grip := _create_box(Vector3(0.036, 0.095, 0.045), mat_wood)
	r_grip.rotation.x = deg_to_rad(-22.0)
	r_grip.position = Vector3(0.0, -0.065, 0.05)
	rif.add_child(r_grip)

	# --- 4. РАКЕТНИЦА RPG (Слот 4) ---
	var rkt := Node3D.new()
	rkt.name = "Weapon3D_Rocket"
	add_child(rkt)
	weapon_nodes.append(rkt)

	# Ракетная труба
	var rkt_tube := _create_cylinder(0.062, 0.55, mat_khaki)
	rkt_tube.rotation.x = deg_to_rad(90.0)
	rkt_tube.position = Vector3(0.0, 0.02, -0.14)
	rkt.add_child(rkt_tube)

	# Раструб на конце трубы
	var rkt_ring := _create_cylinder(0.074, 0.06, mat_metal_dark)
	rkt_ring.rotation.x = deg_to_rad(90.0)
	rkt_ring.position = Vector3(0.0, 0.02, -0.40)
	rkt.add_child(rkt_ring)

	# Ракета торчащая из ствола (коническая боеголовка)
	var rkt_warhead := _create_cylinder(0.058, 0.18, mat_warhead)
	rkt_warhead.rotation.x = deg_to_rad(90.0)
	rkt_warhead.position = Vector3(0.0, 0.02, -0.47)
	rkt.add_child(rkt_warhead)

	# Прицельный щиток сбоку
	var rkt_optic := _create_box(Vector3(0.015, 0.045, 0.06), mat_metal_dark)
	rkt_optic.position = Vector3(-0.075, 0.06, -0.20)
	rkt.add_child(rkt_optic)

	# Рукоятка
	var rkt_grip := _create_box(Vector3(0.038, 0.12, 0.05), mat_khaki)
	rkt_grip.rotation.x = deg_to_rad(-16.0)
	rkt_grip.position = Vector3(0.0, -0.08, -0.06)
	rkt.add_child(rkt_grip)

# =========================================================================
# ВСПЫШКА ВЫСТРЕЛА (3D FLASH + LIGHT)
# =========================================================================
func _build_muzzle_flash() -> void:
	var flash_parent := Node3D.new()
	flash_parent.name = "MuzzleFlash3D"
	flash_parent.position = Vector3(0.0, 0.025, -0.48)
	flash_parent.visible = false
	add_child(flash_parent)
	muzzle_flash_3d = flash_parent

	# Динамический свет вспышки
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.35)
	light.light_energy = 5.5
	light.omni_range = 8.0
	flash_parent.add_child(light)

	# 3D квад-звезда вспышки
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.9, 0.3)
	flash_mat.albedo_texture = TextureGen.make_muzzle_flash()
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var qm := QuadMesh.new()
	qm.size = Vector2(0.32, 0.32)
	qm.material = flash_mat

	var mi := MeshInstance3D.new()
	mi.mesh = qm
	flash_parent.add_child(mi)

# Вспомогательные функции создания лоу-поли примитивов
func _create_box(box_size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	mi.mesh = mesh
	return mi

func _create_cylinder(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = mat
	mi.mesh = mesh
	return mi
