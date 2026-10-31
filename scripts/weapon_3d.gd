extends Node3D

# =========================================================================
# WEAPON 3D RIG (FIRST-PERSON VIEW)
# Использует настоящие 3D-модели оружия (GLB):
# - Револьвер .44 (Revolver.glb)
# - Обрез двустволки (Shotgun.glb)
# - Автомат каравана (AssaultRifle.glb)
# - Ракетница RPG (RocketLauncher.glb)
# =========================================================================

const MODEL_REVOLVER = preload("res://models/weapons/Revolver.glb")
const MODEL_SHOTGUN  = preload("res://models/weapons/Shotgun.glb")
const MODEL_RIFLE    = preload("res://models/weapons/AssaultRifle.glb")
const MODEL_ROCKET   = preload("res://models/weapons/RocketLauncher.glb")

# --- Базовые трансформации для выравнивания по центру ---
const BASE_POS := Vector3(0.0, -0.19, -0.42)
const BASE_ROT := Vector3(0.0, 0.0, 0.0)

const FLASH_POSITIONS = [
	Vector3(0.0, 0.035, -0.36), # Revolver
	Vector3(0.0, 0.025, -0.58), # Shotgun
	Vector3(0.0, 0.020, -0.55), # Rifle
	Vector3(0.0, 0.030, -0.52)  # Rocket
]

var current_weapon_idx : int = 0
var weapon_nodes       : Array = []

# Физические параметры отдачи
var recoil_z   : float = 0.0
var recoil_rot : float = 0.0
var bob_time   : float = 0.0

var muzzle_flash_3d : Node3D = null

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

	if muzzle_flash_3d and idx >= 0 and idx < FLASH_POSITIONS.size():
		muzzle_flash_3d.position = FLASH_POSITIONS[idx]

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
# ПОСТРОЕНИЕ 3D МОДЕЛЕЙ ОРУЖИЯ (НАСТОЯЩИЕ 3D GLB МОДЕЛИ)
# =========================================================================
func _build_3d_weapons() -> void:
	# --- 1. РЕВОЛЬВЕР .44 (Слот 1) ---
	var rev_root := Node3D.new()
	rev_root.name = "Weapon3D_Revolver"
	add_child(rev_root)
	weapon_nodes.append(rev_root)

	var rev = MODEL_REVOLVER.instantiate()
	rev.scale = Vector3.ONE * 0.22
	rev.rotation_degrees = Vector3(0, 90, 0)
	rev.position = Vector3(0.0, -0.02, 0.08)
	rev_root.add_child(rev)

	# --- 2. ОБРЕЗ ДВУСТВОЛКИ (Слот 2) ---
	var shot_root := Node3D.new()
	shot_root.name = "Weapon3D_Shotgun"
	add_child(shot_root)
	weapon_nodes.append(shot_root)

	var shot = MODEL_SHOTGUN.instantiate()
	shot.scale = Vector3.ONE * 0.18
	shot.rotation_degrees = Vector3(0, 90, 0)
	shot.position = Vector3(0.0, -0.04, 0.12)
	shot_root.add_child(shot)

	# --- 3. АВТОМАТ КАРАВАНА (Слот 3) ---
	var rif_root := Node3D.new()
	rif_root.name = "Weapon3D_Rifle"
	add_child(rif_root)
	weapon_nodes.append(rif_root)

	var rif = MODEL_RIFLE.instantiate()
	rif.scale = Vector3.ONE * 0.36
	rif.rotation_degrees = Vector3(0, 90, 0)
	rif.position = Vector3(0.0, -0.045, 0.06)
	rif_root.add_child(rif)

	# --- 4. РАКЕТНИЦА RPG (Слот 4) ---
	var rkt_root := Node3D.new()
	rkt_root.name = "Weapon3D_Rocket"
	add_child(rkt_root)
	weapon_nodes.append(rkt_root)

	var rkt = MODEL_ROCKET.instantiate()
	rkt.scale = Vector3.ONE * 0.44
	rkt.rotation_degrees = Vector3(0, 90, 0)
	rkt.position = Vector3(0.0, -0.04, 0.04)
	rkt_root.add_child(rkt)

# =========================================================================
# ВСПЫШКА ВЫСТРЕЛА (3D FLASH + LIGHT)
# =========================================================================
func _build_muzzle_flash() -> void:
	var flash_parent := Node3D.new()
	flash_parent.name = "MuzzleFlash3D"
	flash_parent.position = FLASH_POSITIONS[0]
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
	if ResourceLoader.exists("res://assets/textures/muzzle_flash.png"):
		flash_mat.albedo_texture = load("res://assets/textures/muzzle_flash.png")
	elif ResourceLoader.exists("res://Weapons/Images/muzzle_flash.png"):
		flash_mat.albedo_texture = load("res://Weapons/Images/muzzle_flash.png")
	elif ClassDB.class_exists("TextureGen") or Engine.has_singleton("TextureGen"):
		# Fallback to generator if available
		pass
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var qm := QuadMesh.new()
	qm.size = Vector2(0.32, 0.32)
	qm.material = flash_mat

	var mi := MeshInstance3D.new()
	mi.mesh = qm
	flash_parent.add_child(mi)
