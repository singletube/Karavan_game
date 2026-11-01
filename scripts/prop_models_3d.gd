extends Node
class_name PropModels3D

# =========================================================================
# БИБЛИОТЕКА ВЫСОКОДЕТАЛИЗИРОВАННЫХ ПРОЦЕДУРНЫХ 3D МОДЕЛЕЙ (PROP LIBRARY)
# =========================================================================
# Архитектура: каждый маленький объект (шина, бочка, пальма, пистолет, череп,
# кактус, баррикада, кибер-трофей) моделируется как отдельный качественный
# компонент, после чего они собираются в составные сцены лагеря и террейна.

# --- PBR Материалы библиотеки ---
static var mat_tire_rubber     : StandardMaterial3D
static var mat_rim_metal       : StandardMaterial3D
static var mat_rim_chrome      : StandardMaterial3D

static var mat_drum_rusty      : StandardMaterial3D
static var mat_drum_hazard     : StandardMaterial3D
static var mat_drum_red        : StandardMaterial3D
static var mat_toxic_sludge    : StandardMaterial3D

static var mat_palm_trunk      : StandardMaterial3D
static var mat_palm_frond      : StandardMaterial3D
static var mat_coconut         : StandardMaterial3D

static var mat_gun_blued_steel : StandardMaterial3D
static var mat_gun_walnut      : StandardMaterial3D
static var mat_brass_shell     : StandardMaterial3D

static var mat_bone_ivory      : StandardMaterial3D
static var mat_cyber_chrome    : StandardMaterial3D
static var mat_cyber_glow_red  : StandardMaterial3D
static var mat_cyber_glow_cyan : StandardMaterial3D
static var mat_wire_copper     : StandardMaterial3D
static var mat_wire_insulation : StandardMaterial3D

static var mat_cactus_stem     : StandardMaterial3D
static var mat_cactus_rib      : StandardMaterial3D
static var mat_cactus_flower   : StandardMaterial3D

static var mat_sandbag_burlap  : StandardMaterial3D
static var mat_corrugated_iron : StandardMaterial3D
static var mat_rebar_steel     : StandardMaterial3D
static var mat_barbed_wire     : StandardMaterial3D

static var mat_ammo_box_green  : StandardMaterial3D
static var mat_pcb_board       : StandardMaterial3D
static var mat_sign_hazard     : StandardMaterial3D
static var mat_canyon_rock     : StandardMaterial3D

static func _load_tex(filename: String) -> Texture2D:
	var path: String = "res://assets/textures/props/" + filename
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	# Надежный фолбэк прямой загрузки через Image (работает до генерации .import файлов)
	var os_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(os_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func _ensure_materials() -> void:
	if mat_tire_rubber != null:
		return

	# Резина шины с глубокой шероховатостью и текстурой протектора
	mat_tire_rubber = StandardMaterial3D.new()
	mat_tire_rubber.albedo_color = Color(0.12, 0.12, 0.13)
	mat_tire_rubber.roughness = 0.95
	var tex_tire := _load_tex("tire_tread.png")
	if tex_tire:
		mat_tire_rubber.albedo_texture = tex_tire
		mat_tire_rubber.uv1_scale = Vector3(2, 2, 2)

	# Стальной диск колеса
	mat_rim_metal = StandardMaterial3D.new()
	mat_rim_metal.albedo_color = Color(0.38, 0.35, 0.32)
	mat_rim_metal.metallic = 0.75
	mat_rim_metal.roughness = 0.55

	# Хромированные болты
	mat_rim_chrome = StandardMaterial3D.new()
	mat_rim_chrome.albedo_color = Color(0.85, 0.88, 0.92)
	mat_rim_chrome.metallic = 0.95
	mat_rim_chrome.roughness = 0.20

	# Бочки: ржавая, аварийная и горючая с текстурами коррозии и трафаретов
	mat_drum_rusty = StandardMaterial3D.new()
	mat_drum_rusty.albedo_color = Color(0.48, 0.28, 0.18)
	mat_drum_rusty.metallic = 0.40
	mat_drum_rusty.roughness = 0.85
	var tex_rust := _load_tex("corrugated_rust.png")
	if tex_rust:
		mat_drum_rusty.albedo_texture = tex_rust

	mat_drum_hazard = StandardMaterial3D.new()
	mat_drum_hazard.albedo_color = Color(0.95, 0.85, 0.20)
	mat_drum_hazard.metallic = 0.30
	mat_drum_hazard.roughness = 0.65
	var tex_hazard := _load_tex("barrel_hazard.png")
	if tex_hazard:
		mat_drum_hazard.albedo_texture = tex_hazard

	mat_drum_red = StandardMaterial3D.new()
	mat_drum_red.albedo_color = Color(0.85, 0.22, 0.15)
	mat_drum_red.metallic = 0.35
	mat_drum_red.roughness = 0.55
	var tex_drum_red := _load_tex("barrel_red.png")
	if tex_drum_red:
		mat_drum_red.albedo_texture = tex_drum_red

	mat_toxic_sludge = StandardMaterial3D.new()
	mat_toxic_sludge.albedo_color = Color(0.20, 0.92, 0.30)
	mat_toxic_sludge.emission_enabled = true
	mat_toxic_sludge.emission = Color(0.22, 0.98, 0.35)
	mat_toxic_sludge.emission_energy_multiplier = 2.4
	mat_toxic_sludge.roughness = 0.10
	var tex_toxic := _load_tex("toxic_sludge_ground.png")
	if tex_toxic:
		mat_toxic_sludge.albedo_texture = tex_toxic

	# Пальма: кора, крона и кокосы с фотореалистичными текстурами волокон
	mat_palm_trunk = StandardMaterial3D.new()
	mat_palm_trunk.albedo_color = Color(0.38, 0.28, 0.20)
	mat_palm_trunk.roughness = 0.95
	var tex_bark := _load_tex("palm_bark.png")
	if tex_bark:
		mat_palm_trunk.albedo_texture = tex_bark
		mat_palm_trunk.uv1_scale = Vector3(1, 4, 1)

	mat_palm_frond = StandardMaterial3D.new()
	mat_palm_frond.albedo_color = Color(0.28, 0.55, 0.20)
	mat_palm_frond.roughness = 0.65
	mat_palm_frond.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex_leaf := _load_tex("palm_leaf.png")
	if tex_leaf:
		mat_palm_frond.albedo_texture = tex_leaf

	mat_coconut = StandardMaterial3D.new()
	mat_coconut.albedo_color = Color(0.28, 0.20, 0.14)
	mat_coconut.roughness = 0.85

	# Оружейные материалы (вороненая сталь с микроцарапинами, ореховое дерево с кольцами)
	mat_gun_blued_steel = StandardMaterial3D.new()
	mat_gun_blued_steel.albedo_color = Color(0.20, 0.22, 0.26)
	mat_gun_blued_steel.metallic = 0.92
	mat_gun_blued_steel.roughness = 0.28
	var tex_steel := _load_tex("blued_metal.png")
	if tex_steel:
		mat_gun_blued_steel.albedo_texture = tex_steel

	mat_gun_walnut = StandardMaterial3D.new()
	mat_gun_walnut.albedo_color = Color(0.42, 0.25, 0.14)
	mat_gun_walnut.roughness = 0.60
	var tex_wood := _load_tex("walnut_wood.png")
	if tex_wood:
		mat_gun_walnut.albedo_texture = tex_wood

	mat_brass_shell = StandardMaterial3D.new()
	mat_brass_shell.albedo_color = Color(0.95, 0.80, 0.35)
	mat_brass_shell.metallic = 0.95
	mat_brass_shell.roughness = 0.20

	# Кости и кибернетика
	mat_bone_ivory = StandardMaterial3D.new()
	mat_bone_ivory.albedo_color = Color(0.92, 0.88, 0.80)
	mat_bone_ivory.roughness = 0.75
	var tex_bone := _load_tex("skull_bone.png")
	if tex_bone:
		mat_bone_ivory.albedo_texture = tex_bone

	mat_cyber_chrome = StandardMaterial3D.new()
	mat_cyber_chrome.albedo_color = Color(0.80, 0.82, 0.88)
	mat_cyber_chrome.metallic = 0.95
	mat_cyber_chrome.roughness = 0.22
	var tex_circuit := _load_tex("cyber_circuit.png")
	if tex_circuit:
		mat_cyber_chrome.albedo_texture = tex_circuit

	mat_cyber_glow_red = StandardMaterial3D.new()
	mat_cyber_glow_red.albedo_color = Color(1.0, 0.05, 0.05)
	mat_cyber_glow_red.emission_enabled = true
	mat_cyber_glow_red.emission = Color(1.0, 0.10, 0.08)
	mat_cyber_glow_red.emission_energy_multiplier = 4.0

	mat_cyber_glow_cyan = StandardMaterial3D.new()
	mat_cyber_glow_cyan.albedo_color = Color(0.05, 0.80, 1.0)
	mat_cyber_glow_cyan.emission_enabled = true
	mat_cyber_glow_cyan.emission = Color(0.10, 0.90, 1.0)
	mat_cyber_glow_cyan.emission_energy_multiplier = 3.2

	mat_wire_copper = StandardMaterial3D.new()
	mat_wire_copper.albedo_color = Color(0.88, 0.48, 0.24)
	mat_wire_copper.metallic = 0.85
	mat_wire_copper.roughness = 0.35

	mat_wire_insulation = StandardMaterial3D.new()
	mat_wire_insulation.albedo_color = Color(0.12, 0.45, 0.80)
	mat_wire_insulation.roughness = 0.50

	# Кактус с текстурой ребристой кожи и ареол с колючками
	mat_cactus_stem = StandardMaterial3D.new()
	mat_cactus_stem.albedo_color = Color(0.24, 0.48, 0.20)
	mat_cactus_stem.roughness = 0.80
	var tex_cactus := _load_tex("cactus_skin.png")
	if tex_cactus:
		mat_cactus_stem.albedo_texture = tex_cactus
		mat_cactus_stem.uv1_scale = Vector3(2, 4, 2)

	mat_cactus_rib = StandardMaterial3D.new()
	mat_cactus_rib.albedo_color = Color(0.28, 0.55, 0.24)
	mat_cactus_rib.roughness = 0.75

	mat_cactus_flower = StandardMaterial3D.new()
	mat_cactus_flower.albedo_color = Color(0.96, 0.80, 0.18)
	mat_cactus_flower.roughness = 0.60

	# Фортификация и укрытия (грубая текстура мешковины и рифленого ржавого листа)
	mat_sandbag_burlap = StandardMaterial3D.new()
	mat_sandbag_burlap.albedo_color = Color(0.65, 0.56, 0.44)
	mat_sandbag_burlap.roughness = 0.95
	var tex_burlap := _load_tex("sandbag_burlap.png")
	if tex_burlap:
		mat_sandbag_burlap.albedo_texture = tex_burlap
		mat_sandbag_burlap.uv1_scale = Vector3(2, 2, 2)

	mat_corrugated_iron = StandardMaterial3D.new()
	mat_corrugated_iron.albedo_color = Color(0.55, 0.48, 0.42)
	mat_corrugated_iron.metallic = 0.65
	mat_corrugated_iron.roughness = 0.70
	if tex_rust:
		mat_corrugated_iron.albedo_texture = tex_rust
		mat_corrugated_iron.uv1_scale = Vector3(2, 2, 2)

	mat_rebar_steel = StandardMaterial3D.new()
	mat_rebar_steel.albedo_color = Color(0.32, 0.28, 0.26)
	mat_rebar_steel.metallic = 0.80
	mat_rebar_steel.roughness = 0.60

	mat_barbed_wire = StandardMaterial3D.new()
	mat_barbed_wire.albedo_color = Color(0.24, 0.24, 0.26)
	mat_barbed_wire.metallic = 0.85
	mat_barbed_wire.roughness = 0.45

	# Припасы и электроника
	mat_ammo_box_green = StandardMaterial3D.new()
	mat_ammo_box_green.albedo_color = Color(0.26, 0.36, 0.22)
	mat_ammo_box_green.metallic = 0.35
	mat_ammo_box_green.roughness = 0.65

	mat_pcb_board = StandardMaterial3D.new()
	mat_pcb_board.albedo_color = Color(0.12, 0.40, 0.20)
	mat_pcb_board.roughness = 0.40
	if tex_circuit:
		mat_pcb_board.albedo_texture = tex_circuit

	mat_sign_hazard = StandardMaterial3D.new()
	mat_sign_hazard.albedo_color = Color(0.96, 0.75, 0.18)
	mat_sign_hazard.roughness = 0.55
	var tex_sign := _load_tex("warning_sign_cyborg.png")
	if tex_sign:
		mat_sign_hazard.albedo_texture = tex_sign

	# Красный песчаник каньона
	mat_canyon_rock = StandardMaterial3D.new()
	mat_canyon_rock.albedo_color = Color(0.72, 0.38, 0.25)
	mat_canyon_rock.roughness = 0.92
	var tex_canyon := _load_tex("red_canyon_rock.png")
	if tex_canyon:
		mat_canyon_rock.albedo_texture = tex_canyon
		mat_canyon_rock.uv1_scale = Vector3(1.5, 1.5, 1.5)

# -------------------------------------------------------------------------
# Базовые хелперы геометрии
# -------------------------------------------------------------------------
static func _box(p: Node3D, sz: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	b.material = mat
	mi.mesh = b
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	p.add_child(mi)
	return mi

static func _cyl(p: Node3D, h: float, r_top: float, r_bot: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, segs: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.height = h
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.radial_segments = segs
	c.material = mat
	mi.mesh = c
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	p.add_child(mi)
	return mi

static func _sph(p: Node3D, rad: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rad
	s.height = rad * 2.0
	s.material = mat
	mi.mesh = s
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	p.add_child(mi)
	return mi

# =========================================================================
# 1. ДЕТАЛИЗИРОВАННАЯ АВТОМОБИЛЬНАЯ ШИНА С ДИСКОМ И БОЛТАМИ (TIRE)
# =========================================================================
static func create_tire(has_rim: bool = true, deflated: bool = false) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropTire"

	var y_scale := 0.75 if deflated else 1.0

	# Внешний резиновый протектор
	var tread := _cyl(root, 0.28, 0.40, 0.40, mat_tire_rubber, Vector3(0, 0.28 * 0.5 * y_scale, 0), Vector3.ZERO, 16)
	tread.scale.y = y_scale

	# Округлые боковины покрышки (фаски)
	_cyl(root, 0.32, 0.36, 0.36, mat_tire_rubber, Vector3(0, 0.28 * 0.5 * y_scale, 0), Vector3.ZERO, 16)

	if has_rim:
		# Стальной штампованный диск
		_cyl(root, 0.30, 0.24, 0.24, mat_rim_metal, Vector3(0, 0.28 * 0.5 * y_scale, 0), Vector3.ZERO, 12)
		# Центральная ступица
		_cyl(root, 0.34, 0.08, 0.08, mat_rim_chrome, Vector3(0, 0.28 * 0.5 * y_scale, 0), Vector3.ZERO, 8)
		# 5 хромированных колесных гаек по кругу
		for i in range(5):
			var a: float = float(i) * (TAU / 5.0)
			var nx: float = cos(a) * 0.15
			var nz: float = sin(a) * 0.15
			_cyl(root, 0.35, 0.02, 0.02, mat_rim_chrome, Vector3(nx, 0.28 * 0.5 * y_scale, nz), Vector3.ZERO, 6)

	return root

static func create_tire_stack(count: int = 3) -> Node3D:
	_ensure_materials()
	var stack := Node3D.new()
	stack.name = "PropTireStack"

	for i in range(count):
		var t := create_tire(i == count - 1 or randf() < 0.5, i == 0)
		t.position = Vector3(randf_range(-0.04, 0.04), float(i) * 0.26, randf_range(-0.04, 0.04))
		t.rotation.y = randf_range(0, TAU)
		stack.add_child(t)

	return stack

# =========================================================================
# 2. ДЕТАЛИЗИРОВАННАЯ 200-ЛИТРОВАЯ СТАЛЬНАЯ БОЧКА (OIL DRUM)
# =========================================================================
static func create_oil_drum(variant: String = "rusty") -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropOilDrum_%s" % variant

	var mat: StandardMaterial3D = mat_drum_rusty
	if variant == "hazard":
		mat = mat_drum_hazard
	elif variant == "red":
		mat = mat_drum_red

	var h: float = 0.95
	var r: float = 0.32

	# Основной цилиндр корпуса
	_cyl(root, h, r, r, mat, Vector3(0, h * 0.5, 0), Vector3.ZERO, 14)

	# Два прокатанных ребра жесткости (stiffener rings)
	_cyl(root, 0.05, r + 0.018, r + 0.018, mat, Vector3(0, h * 0.35, 0), Vector3.ZERO, 14)
	_cyl(root, 0.05, r + 0.018, r + 0.018, mat, Vector3(0, h * 0.65, 0), Vector3.ZERO, 14)

	# Верхний и нижний выступающие буртики (chimes)
	_cyl(root, 0.04, r + 0.015, r + 0.015, mat_rebar_steel, Vector3(0, h * 0.98, 0), Vector3.ZERO, 14)
	_cyl(root, 0.04, r + 0.015, r + 0.015, mat_rebar_steel, Vector3(0, h * 0.02, 0), Vector3.ZERO, 14)

	# Утопленная крышка с закручивающимися пробками (Bung plugs 2" и 3/4")
	_cyl(root, 0.03, 0.04, 0.04, mat_rebar_steel, Vector3(0.14, h, 0.0), Vector3.ZERO, 6)
	_cyl(root, 0.03, 0.025, 0.025, mat_rebar_steel, Vector3(-0.14, h, 0.08), Vector3.ZERO, 6)

	# Если токсичная бочка — светящаяся лужица утечки и подтек
	if variant == "toxic":
		_cyl(root, 0.02, 0.45, 0.45, mat_toxic_sludge, Vector3(0.18, 0.01, 0.18), Vector3.ZERO, 10)
		_box(root, Vector3(0.06, 0.45, 0.02), mat_toxic_sludge, Vector3(r + 0.005, 0.35, 0.0))

	return root

# =========================================================================
# 3. ДЕТАЛИЗИРОВАННАЯ ФИНИКОВАЯ ПАЛЬМА (PALM TREE)
# =========================================================================
static func create_palm_tree(height: float = 6.2, lean_angle: float = 0.14) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropPalmTree"

	# Искривленный наборный ствол из 6 сегментов с текстурой чешуек
	var current_pos := Vector3.ZERO
	var current_rot := Vector3.ZERO
	var seg_count: int = 6
	var seg_h: float = height / float(seg_count)

	for i in range(seg_count):
		var frac: float = float(i) / float(seg_count)
		var r_bot: float = lerpf(0.38, 0.22, frac)
		var r_top: float = lerpf(0.35, 0.18, (float(i + 1) / float(seg_count)))

		var lean_step := Vector3(sin(lean_angle * frac) * 0.08, 0.0, cos(lean_angle * frac) * 0.08)
		var seg := _cyl(root, seg_h, r_top, r_bot, mat_palm_trunk, current_pos + Vector3(0, seg_h * 0.5, 0) + lean_step, current_rot, 10)
		
		# Кольцевой выступ старых срезанных ветвей
		_cyl(seg, 0.08, r_bot + 0.03, r_bot + 0.03, mat_palm_trunk, Vector3(0, -seg_h * 0.4, 0), Vector3.ZERO, 10)

		current_pos += Vector3(lean_step.x, seg_h, lean_step.z)
		current_rot.x += 0.04

	# Крона пальмы: 14 пышных поникающих ветвей-вееров (fronds)
	var crown_pos := current_pos
	for fi in range(14):
		var a: float = float(fi) * (TAU / 14.0) + randf_range(-0.1, 0.1)
		var frond_root := Node3D.new()
		frond_root.position = crown_pos
		frond_root.rotation.y = a
		root.add_child(frond_root)

		# Дугообразно изогнутая черешковая ось ветви
		var pitch: float = deg_to_rad(randf_range(-25.0, -45.0))
		var frond_len: float = randf_range(2.6, 3.4)

		# Центральный черешок
		var stalk := _cyl(frond_root, frond_len, 0.02, 0.05, mat_palm_trunk, Vector3(0, 0, frond_len * 0.5), Vector3(PI * 0.5 + pitch, 0, 0), 6)
		# 3 сегмента зеленого веера с пониканием к концу
		for si in range(3):
			var s_frac: float = float(si + 1) / 3.0
			var blade_w: float = sin(s_frac * PI) * 0.85 + 0.2
			var blade := _box(stalk, Vector3(blade_w, 0.03, frond_len * 0.32), mat_palm_frond, Vector3(0, 0, (float(si) - 1.0) * frond_len * 0.3))
			blade.rotation.x = deg_to_rad(float(si) * 8.0)

	# Гроздь кокосов под кроной
	for ci in range(5):
		var ca: float = float(ci) * (TAU / 5.0)
		var c_pos := crown_pos + Vector3(cos(ca) * 0.25, -0.3, sin(ca) * 0.25)
		_sph(root, 0.12, mat_coconut, c_pos)

	return root

# =========================================================================
# 4. ДЕТАЛИЗИРОВАННЫЙ ПИСТОЛЕТ И ВИНТОВКА (GUN PROPS)
# =========================================================================
static func create_pistol_prop() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropPistol"

	# Рамка и затвор (ствольная коробка)
	_box(root, Vector3(0.04, 0.07, 0.22), mat_gun_blued_steel, Vector3(0, 0.08, 0))
	# Рифление на затворе для взвода
	_box(root, Vector3(0.044, 0.065, 0.05), mat_rebar_steel, Vector3(0, 0.08, 0.07))
	# Дульный срез и ствол
	_cyl(root, 0.06, 0.016, 0.016, mat_gun_blued_steel, Vector3(0, 0.08, -0.12), Vector3(PI * 0.5, 0, 0), 8)
	# Мушка и целик
	_box(root, Vector3(0.008, 0.015, 0.012), mat_gun_blued_steel, Vector3(0, 0.12, -0.10))
	_box(root, Vector3(0.012, 0.015, 0.012), mat_gun_blued_steel, Vector3(0, 0.12, 0.09))

	# Пистолетная рукоять под наклоном с деревянными щечками
	var grip := _box(root, Vector3(0.038, 0.13, 0.06), mat_gun_walnut, Vector3(0, 0.0, 0.05), Vector3(deg_to_rad(-18.0), 0, 0))
	# Пятка магазина
	_box(grip, Vector3(0.042, 0.015, 0.065), mat_gun_blued_steel, Vector3(0, -0.07, 0))
	# Спусковая скоба и спусковой крючок
	_box(root, Vector3(0.015, 0.05, 0.05), mat_gun_blued_steel, Vector3(0, 0.03, -0.01))
	_box(root, Vector3(0.008, 0.03, 0.01), mat_brass_shell, Vector3(0, 0.035, -0.01), Vector3(deg_to_rad(15.0), 0, 0))

	return root

static func create_rifle_prop() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropRifle"

	# Ствольная коробка
	_box(root, Vector3(0.05, 0.09, 0.35), mat_gun_blued_steel, Vector3(0, 0.06, 0))
	# Длинный ствол с пламегасителем
	_cyl(root, 0.55, 0.016, 0.018, mat_gun_blued_steel, Vector3(0, 0.06, -0.42), Vector3(PI * 0.5, 0, 0), 8)
	_cyl(root, 0.06, 0.022, 0.018, mat_gun_blued_steel, Vector3(0, 0.06, -0.71), Vector3(PI * 0.5, 0, 0), 8) # дульный тормоз

	# Газовая трубка над стволом
	_cyl(root, 0.32, 0.012, 0.012, mat_gun_blued_steel, Vector3(0, 0.085, -0.32), Vector3(PI * 0.5, 0, 0), 8)

	# Цевье из дерева
	_box(root, Vector3(0.055, 0.075, 0.28), mat_gun_walnut, Vector3(0, 0.06, -0.30))

	# Изогнутый секторный магазин (банан)
	var mag := _box(root, Vector3(0.035, 0.18, 0.07), mat_gun_blued_steel, Vector3(0, -0.06, -0.08), Vector3(deg_to_rad(20.0), 0, 0))

	# Деревянный приклад с затыльником
	var stock := _box(root, Vector3(0.045, 0.11, 0.32), mat_gun_walnut, Vector3(0, 0.02, 0.32), Vector3(deg_to_rad(-8.0), 0, 0))
	_box(stock, Vector3(0.048, 0.12, 0.015), mat_rebar_steel, Vector3(0, 0, 0.16)) # затыльник

	# Пистолетная рукоятка
	_box(root, Vector3(0.036, 0.12, 0.05), mat_gun_walnut, Vector3(0, -0.04, 0.10), Vector3(deg_to_rad(-24.0), 0, 0))

	return root

# =========================================================================
# 5. ДЕТАЛИЗИРОВАННЫЙ ЧЕРЕП ЧЕЛОВЕКА И КИБОРГА (SKULL & CYBORG TROPHY)
# =========================================================================
static func create_skull_human() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropSkullHuman"

	# Черепная коробка (сферический свод)
	_sph(root, 0.13, mat_bone_ivory, Vector3(0, 0.13, 0))
	# Височные и лобные кости
	_box(root, Vector3(0.18, 0.14, 0.16), mat_bone_ivory, Vector3(0, 0.11, 0.02))

	# Лицевая часть и верхняя челюсть
	_box(root, Vector3(0.13, 0.09, 0.12), mat_bone_ivory, Vector3(0, 0.05, -0.08))

	# Глазницы (глубокие черные впадины)
	_box(root, Vector3(0.04, 0.04, 0.04), mat_tire_rubber, Vector3(-0.045, 0.09, -0.12))
	_box(root, Vector3(0.04, 0.04, 0.04), mat_tire_rubber, Vector3(0.045, 0.09, -0.12))

	# Грушевидное носовое отверстие
	_box(root, Vector3(0.02, 0.03, 0.03), mat_tire_rubber, Vector3(0, 0.06, -0.13))

	# Зубные ряды
	for t in range(6):
		var tx: float = -0.04 + float(t) * 0.016
		_box(root, Vector3(0.012, 0.018, 0.015), mat_bone_ivory, Vector3(tx, 0.01, -0.12))

	return root

static func create_skull_cyborg() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropSkullCyborg"

	# Левая половина — выбеленная кость
	_box(root, Vector3(0.09, 0.14, 0.16), mat_bone_ivory, Vector3(-0.045, 0.11, 0))
	_box(root, Vector3(0.04, 0.04, 0.04), mat_tire_rubber, Vector3(-0.045, 0.09, -0.09)) # обычная глазница

	# Правая половина — обнаженный титановый эндоскелет киборга
	_box(root, Vector3(0.09, 0.14, 0.16), mat_cyber_chrome, Vector3(0.045, 0.11, 0))

	# Зловещий светящийся красный оптический окуляр в правой глазнице
	var eye_bezel := _cyl(root, 0.03, 0.028, 0.028, mat_cyber_chrome, Vector3(0.045, 0.09, -0.08), Vector3(PI * 0.5, 0, 0), 8)
	_cyl(eye_bezel, 0.02, 0.02, 0.02, mat_cyber_glow_red, Vector3(0, 0.015, 0), Vector3.ZERO, 8)

	var eye_light := OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.1, 0.1)
	eye_light.light_energy = 1.6
	eye_light.omni_range = 2.5
	eye_light.position = Vector3(0.045, 0.09, -0.12)
	root.add_child(eye_light)

	# Металлическая челюсть с титановыми зубами-имплантами
	_box(root, Vector3(0.12, 0.04, 0.10), mat_cyber_chrome, Vector3(0, 0.01, -0.06))

	# Свисающие пучки разорванных нейронных проводов
	for w in range(4):
		var wx: float = 0.02 + float(w) * 0.02
		var w_mat = mat_wire_copper if w % 2 == 0 else mat_wire_insulation
		_cyl(root, 0.18, 0.005, 0.005, w_mat, Vector3(wx, -0.08, -0.02), Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.3, 0.3)), 4)

	return root

static func create_cyborg_spike_trophy() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropCyborgSpikeTrophy"

	# Стальная арматурина / пика (высота 2.4м), вбитая в песок
	_cyl(root, 2.4, 0.025, 0.035, mat_rebar_steel, Vector3(0, 1.2, 0), Vector3(deg_to_rad(randf_range(-4, 4)), 0, deg_to_rad(randf_range(-4, 4))), 8)

	# Насаженная на острие голова зомби-киборга
	var head := create_skull_cyborg()
	head.position = Vector3(0, 2.22, 0)
	head.rotation = Vector3(deg_to_rad(15.0), deg_to_rad(randf_range(-30, 30)), 0)
	root.add_child(head)

	# Предупреждающая табличка на арматуре: "CYBORG KILL ZONE"
	var sign_board := _box(root, Vector3(0.55, 0.28, 0.03), mat_sign_hazard, Vector3(0, 1.45, 0.04), Vector3(0, 0, deg_to_rad(-6.0)))
	# Черная полоса трафарета
	_box(sign_board, Vector3(0.48, 0.05, 0.035), mat_tire_rubber, Vector3(0, 0, 0.005))

	# Опорная шина у основания пики
	var base_tire := create_tire(true, false)
	base_tire.position = Vector3(0, 0.0, 0)
	root.add_child(base_tire)

	return root

# =========================================================================
# 6. ДЕТАЛИЗИРОВАННЫЙ КАКТУС САГУАРО (CACTUS)
# =========================================================================
static func create_cactus_detailed() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropCactusDetailed"

	var h: float = randf_range(3.0, 4.2)
	var r: float = 0.25

	# Главный ствол с 8 выраженными продольными ребрами
	var stem := _cyl(root, h, r * 0.9, r, mat_cactus_stem, Vector3(0, h * 0.5, 0), Vector3.ZERO, 10)
	for ri in range(8):
		var ra: float = float(ri) * (TAU / 8.0)
		_box(stem, Vector3(0.03, h, 0.03), mat_cactus_rib, Vector3(cos(ra) * r, 0, sin(ra) * r))

	# Округлая верхушка с желтыми пустынными цветами
	_sph(root, r * 0.9, mat_cactus_stem, Vector3(0, h, 0))
	_sph(root, 0.08, mat_cactus_flower, Vector3(0, h + 0.18, 0))

	# Две ветви-руки под органическими углами
	var arms_data := [
		{ "y": h * 0.45, "len": 0.55, "up": 1.1, "rot": 0.0 },
		{ "y": h * 0.62, "len": 0.50, "up": 0.9, "rot": PI * 0.75 }
	]
	for ad in arms_data:
		var a_node := Node3D.new()
		a_node.position = Vector3(0, ad.y, 0)
		a_node.rotation.y = ad.rot
		root.add_child(a_node)

		var arm_len: float = ad.len
		var arm_up: float = ad.up

		# Горизонтальный отросток
		_cyl(a_node, arm_len, r * 0.75, r * 0.75, mat_cactus_stem, Vector3(arm_len * 0.5, 0, 0), Vector3(0, 0, PI * 0.5), 8)
		# Вертикальная стремящаяся к солнцу ветка
		_cyl(a_node, arm_up, r * 0.70, r * 0.75, mat_cactus_stem, Vector3(arm_len, arm_up * 0.5, 0), Vector3.ZERO, 8)
		_sph(a_node, r * 0.70, mat_cactus_stem, Vector3(arm_len, arm_up, 0))
		_sph(a_node, 0.06, mat_cactus_flower, Vector3(arm_len, arm_up + 0.12, 0))

	return root

# =========================================================================
# 7. ФОРТИФИКАЦИЯ: СТЕНА ИЗ МЕШКОВ С ПЕСКОМ (SANDBAG WALL)
# =========================================================================
static func create_sandbag_wall(length: float = 2.4, layers: int = 3) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropSandbagWall"

	var bag_w: float = 0.55
	var bag_h: float = 0.22
	var bag_d: float = 0.32

	var count_x := int(ceil(length / bag_w))
	for l in range(layers):
		var offset_x: float = (bag_w * 0.5) if (l % 2 == 1) else 0.0
		for i in range(count_x):
			var bx: float = -length * 0.5 + float(i) * bag_w + offset_x
			var by: float = float(l) * bag_h + bag_h * 0.5
			var b_node := _box(root, Vector3(bag_w * 0.94, bag_h * 0.92, bag_d), mat_sandbag_burlap, Vector3(bx, by, 0), Vector3(randf_range(-0.04, 0.04), randf_range(-0.05, 0.05), randf_range(-0.03, 0.03)))
			# Завязка мешка с одного торца
			_sph(b_node, 0.05, mat_sandbag_burlap, Vector3(bag_w * 0.44, 0, 0))

	return root

# =========================================================================
# 8. ПРОТИВОТАНКОВЫЙ ЕЖ С КОЛЮЧЕЙ ПРОВОЛОКОЙ (TANK TRAP HEDGEHOG)
# =========================================================================
static func create_tank_trap_hedgehog() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropTankTrapHedgehog"

	# 3 скрещенных стальных двутавра I-Beam длиной 2.0м
	var beam_len: float = 2.0
	var angles := [
		Vector3(deg_to_rad(45.0), deg_to_rad(35.0), 0),
		Vector3(deg_to_rad(-45.0), deg_to_rad(35.0), 0),
		Vector3(0, deg_to_rad(-55.0), deg_to_rad(90.0))
	]
	for ang in angles:
		var beam := _box(root, Vector3(0.16, beam_len, 0.16), mat_rebar_steel, Vector3(0, 0.75, 0), ang)
		# Ребра двутавра
		_box(beam, Vector3(0.24, beam_len, 0.03), mat_drum_rusty, Vector3.ZERO)

	# Центральная крепежная накладка с 4 болтами
	_box(root, Vector3(0.32, 0.32, 0.32), mat_rebar_steel, Vector3(0, 0.75, 0))

	# Спираль колючей проволоки вокруг ежа
	_cyl(root, 0.9, 0.55, 0.55, mat_barbed_wire, Vector3(0, 0.75, 0), Vector3(deg_to_rad(20.0), 0, 0), 10)

	return root

# =========================================================================
# 9. РОССЫПЬ СТРЕЛЯНЫХ ЛАТУННЫХ ГИЛЬЗ И ПАТРОННЫЙ ЦИНК (AMMO & CASINGS)
# =========================================================================
static func create_ammo_crate_open() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropAmmoCrateOpen"

	# Армейский деревянный/металлический ящик с откинутой крышкой
	_box(root, Vector3(0.60, 0.28, 0.40), mat_ammo_box_green, Vector3(0, 0.14, 0))
	# Откинутая крышка сбоку
	var lid := _box(root, Vector3(0.60, 0.04, 0.40), mat_ammo_box_green, Vector3(0, 0.26, 0.24), Vector3(deg_to_rad(-70.0), 0, 0))

	# Ряды золотистых латунных патронов внутри
	for rz in range(3):
		for rx in range(6):
			var px: float = -0.22 + float(rx) * 0.08
			var pz: float = -0.12 + float(rz) * 0.10
			_cyl(root, 0.14, 0.016, 0.018, mat_brass_shell, Vector3(px, 0.20, pz), Vector3.ZERO, 6)

	return root

static func create_spent_casings_pile(radius: float = 0.6) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropSpentCasingsPile"

	# Россыпь из 18 отдельных гильз на песке
	for i in range(18):
		var a: float = randf_range(0, TAU)
		var d: float = randf_range(0.05, radius)
		var cx: float = cos(a) * d
		var cz: float = sin(a) * d
		var casing := _cyl(root, 0.065, 0.009, 0.010, mat_brass_shell, Vector3(cx, 0.015, cz), Vector3(0, randf_range(0, TAU), PI * 0.5), 6)

	return root

# =========================================================================
# 10. КУЧА ЭЛЕКТРОННОГО МУСОРА И СВЕТЯЩИХСЯ БАТАРЕЙ (TECH SALVAGE JUNK)
# =========================================================================
static func create_tech_salvage_pile() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropTechSalvagePile"

	# Сломанный CRT монитор / терминал
	_box(root, Vector3(0.48, 0.42, 0.44), mat_rim_metal, Vector3(-0.25, 0.21, 0), Vector3(0, deg_to_rad(15.0), 0))
	_box(root, Vector3(0.38, 0.32, 0.02), mat_tire_rubber, Vector3(-0.25, 0.21, 0.22), Vector3(0, deg_to_rad(15.0), 0)) # экран

	# Зеленые печатные платы (PCB) с конденсаторами
	_box(root, Vector3(0.35, 0.02, 0.25), mat_pcb_board, Vector3(0.20, 0.02, -0.15), Vector3(0, deg_to_rad(-35.0), 0))
	for cap in range(4):
		_cyl(root, 0.06, 0.02, 0.02, mat_rim_chrome, Vector3(0.12 + float(cap) * 0.05, 0.05, -0.15), Vector3.ZERO, 6)

	# Светящаяся кибер-батарея (синее неоновое свечение)
	var cell := _cyl(root, 0.32, 0.07, 0.07, mat_cyber_glow_cyan, Vector3(0.15, 0.08, 0.22), Vector3(0, 0, PI * 0.5), 8)
	_cyl(cell, 0.04, 0.08, 0.08, mat_rim_chrome, Vector3(0, -0.14, 0), Vector3.ZERO, 8)
	_cyl(cell, 0.04, 0.08, 0.08, mat_rim_chrome, Vector3(0, 0.14, 0), Vector3.ZERO, 8)

	var cell_light := OmniLight3D.new()
	cell_light.light_color = Color(0.1, 0.8, 1.0)
	cell_light.light_energy = 2.0
	cell_light.omni_range = 3.5
	cell_light.position = Vector3(0.15, 0.20, 0.22)
	root.add_child(cell_light)

	# Оторванная механическая рука киборга
	_cyl(root, 0.45, 0.04, 0.05, mat_cyber_chrome, Vector3(-0.05, 0.04, -0.28), Vector3(0, deg_to_rad(45.0), PI * 0.5), 6)
	_box(root, Vector3(0.08, 0.04, 0.10), mat_cyber_chrome, Vector3(0.12, 0.04, -0.42)) # манипулятор-клешня

	return root

# =========================================================================
# 11. МОНУМЕНТАЛЬНАЯ АРКА КРАСНОГО КАНЬОНА (RED CANYON ROCK ARCH)
# =========================================================================
static func create_canyon_arch(span_width: float = 16.0, arch_height: float = 9.5) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropCanyonArch"

	var half_w := span_width * 0.5
	# Левый монолитный пилон со ступенчатыми уступами
	for i in range(4):
		var y_pos := float(i) * 2.2 + 1.1
		var x_pos := -half_w - float(i) * 0.4
		var sz := Vector3(4.8 - float(i) * 0.4, 2.4, 5.2 - float(i) * 0.3)
		var rot := Vector3(0.04 * float(i), 0.08 * float(i), 0.06)
		_box(root, sz, mat_canyon_rock, Vector3(x_pos, y_pos, 0.0), rot)

	# Правый монолитный пилон со ступенчатыми уступами
	for i in range(4):
		var y_pos := float(i) * 2.2 + 1.1
		var x_pos := half_w + float(i) * 0.4
		var sz := Vector3(4.8 - float(i) * 0.4, 2.4, 5.2 - float(i) * 0.3)
		var rot := Vector3(-0.03 * float(i), -0.07 * float(i), -0.06)
		_box(root, sz, mat_canyon_rock, Vector3(x_pos, y_pos, 0.0), rot)

	# Верхний свод арки, нависающий над трактом
	var segs := 6
	for s in range(segs):
		var t := float(s) / float(segs - 1)
		var t_norm := (t - 0.5) * 2.0 # -1.0 to 1.0
		var x_s := t_norm * (half_w * 0.85)
		var y_s := arch_height - (t_norm * t_norm) * 1.6
		var rot_z := -t_norm * 0.28
		_box(root, Vector3(span_width / float(segs) * 1.25, 2.8, 4.4), mat_canyon_rock, Vector3(x_s, y_s, 0.0), Vector3(0.02, 0.0, rot_z))

	# Карнизы и отвалившиеся песчаниковые валуны у подножья
	_box(root, Vector3(2.4, 1.4, 2.2), mat_canyon_rock, Vector3(-half_w + 1.8, 0.7, 1.4), Vector3(0.1, 0.3, 0.05))
	_box(root, Vector3(2.2, 1.2, 2.6), mat_canyon_rock, Vector3(half_w - 1.8, 0.6, -1.2), Vector3(-0.08, -0.25, -0.04))

	return root

# =========================================================================
# 12. КИСЛОТНО-ТОКСИЧЕСКИЙ БАССЕЙН С ПУЗЫРЯМИ (TOXIC SLUDGE POOL)
# =========================================================================
static func create_toxic_pool(radius: float = 3.6) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropToxicSludgePool"

	# Зеркало кипящей ядовитой жижи
	_cyl(root, 0.12, radius, radius * 1.08, mat_toxic_sludge, Vector3(0.0, 0.06, 0.0), Vector3.ZERO, 16)

	# Светящееся радиоактивное освещение
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.25, 1.0, 0.4)
	glow.light_energy = 2.5
	glow.omni_range = radius * 2.6
	glow.position = Vector3(0.0, 0.8, 0.0)
	root.add_child(glow)

	# Всплывшие радиоактивные пузыри
	_sph(root, 0.35, mat_toxic_sludge, Vector3(-0.4 * radius, 0.15, 0.2 * radius))
	_sph(root, 0.22, mat_toxic_sludge, Vector3(0.3 * radius, 0.12, -0.3 * radius))
	_sph(root, 0.28, mat_toxic_sludge, Vector3(0.1 * radius, 0.14, 0.5 * radius))

	# Обугленные кислотой камни и обломки по кромке лужи
	var rock_count := 8
	for i in range(rock_count):
		var ang := float(i) / float(rock_count) * TAU + 0.15
		var r_dist := radius * (0.95 + 0.25 * sin(float(i) * 2.3))
		var r_pos := Vector3(cos(ang) * r_dist, 0.25, sin(ang) * r_dist)
		var r_sz := Vector3(0.9, 0.5, 0.8)
		_box(root, r_sz, mat_drum_rusty, r_pos, Vector3(0.1, ang, 0.15))

	# Утопленная полузатопленная бочка с радиацией
	_cyl(root, 0.88, 0.30, 0.30, mat_drum_hazard, Vector3(-0.35 * radius, 0.25, -0.2 * radius), Vector3(deg_to_rad(35.0), deg_to_rad(20.0), 0.0), 12)

	return root

# =========================================================================
# 13. ПРЕДУПРЕЖДАЮЩИЙ ЗНАК КИБОРГ-УГРОЗЫ НА СТОЙКЕ (CYBORG WARNING SIGN)
# =========================================================================
static func create_hazard_warning_sign_mesh(variant: int = 0) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "PropWarningSign"

	# Стальная несущая стойка из швеллера
	_cyl(root, 2.6, 0.045, 0.055, mat_rebar_steel, Vector3(0.0, 1.3, 0.0), Vector3.ZERO, 8)

	# Ромбовидный / прямоугольный предупреждающий щит
	_box(root, Vector3(0.85, 0.85, 0.04), mat_sign_hazard, Vector3(0.0, 2.1, 0.05), Vector3(0.0, 0.0, deg_to_rad(45.0) if variant == 0 else 0.0))

	# Насаженный кибер-череп на острие стойки
	if variant >= 1:
		var skull := create_skull_cyborg()
		skull.position = Vector3(0.0, 2.8, 0.0)
		skull.scale = Vector3(0.7, 0.7, 0.7)
		root.add_child(skull)

	return root
