extends Node

# =========================================================================
# GOD MODE & DEVELOPER MENU (F6)
# =========================================================================
# Полнофункциональное меню разработчика и режим бога:
# - Бессмертие игрока и каравана
# - Бесконечные патроны
# - Изменение скорости осла/каравана (от 0x до 5x турбо)
# - Заморозка времени (Time Freeze) и заморозка зомби
# - Мгновенная смена времени суток (День / Закат / Ночь / Рассвет) и фиксация солнца
# - Мгновенный отхил игрока и починка каравана
# - Уничтожение всех зомби на карте (Nuke)
# - Телепортация к каравану и к лагерю
# =========================================================================

# --- Глобальные флаги и множители ---
var player_god_mode     : bool  = false
var caravan_god_mode    : bool  = false
var infinite_ammo       : bool  = false
var time_frozen         : bool  = false
var enemies_frozen      : bool  = false
var caravan_speed_mult  : float = 1.0
var player_speed_mult   : float = 1.0
var freeze_day_night    : bool  = false


func _get_first_node(group_name: String) -> Node:
	if not is_inside_tree():
		return null
	var t := get_tree()
	return t.get_first_node_in_group(group_name) if t else null

func _get_nodes(group_name: String) -> Array[Node]:
	if not is_inside_tree():
		return []
	var t := get_tree()
	return t.get_nodes_in_group(group_name) if t else []


var is_ui_open          : bool  = false

# --- UI Элементы ---
var canvas_layer        : CanvasLayer
var panel               : PanelContainer
var toast_label         : Label
var toast_timer         : float = 0.0

# Ссылки на элементы управления
var chk_player_god      : CheckBox
var chk_caravan_god     : CheckBox
var chk_inf_ammo        : CheckBox
var chk_freeze_time     : CheckBox
var chk_freeze_enemies  : CheckBox
var chk_freeze_sun      : CheckBox

var slider_caravan_spd  : HSlider
var lbl_caravan_spd     : Label
var slider_player_spd   : HSlider
var lbl_player_spd      : Label
var slider_day_time     : HSlider
var lbl_day_time        : Label

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			toggle_ui()
			get_viewport().set_input_as_handled()
		elif is_ui_open and event.keycode == KEY_ESCAPE:
			close_ui()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
		if toast_timer <= 0.0 and toast_label:
			toast_label.visible = false

	# Поддержание бессмертия при включенном God Mode
	if player_god_mode:
		var player := _get_first_node("player")
		if player and is_instance_valid(player):
			if player.get("health") != null and player.health < 100:
				player.health = 100
				if player.has_signal("health_changed"):
					player.health_changed.emit(100)

	if caravan_god_mode:
		var caravan := _get_first_node("caravan")
		if caravan and is_instance_valid(caravan):
			var max_hp: int = int(caravan.get("MAX_HEALTH")) if caravan.get("MAX_HEALTH") != null else 500
			if caravan.get("health") != null and caravan.health < max_hp:
				caravan.health = max_hp
				if caravan.has_signal("health_changed"):
					caravan.health_changed.emit(caravan.health, max_hp)

func toggle_ui() -> void:
	if is_ui_open:
		close_ui()
	else:
		open_ui()

func open_ui() -> void:
	is_ui_open = true
	if panel:
		panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_ui_values()
	show_toast("⚡ РЕЖИМ БОГА: ПАНЕЛЬ ОТКРЫТА (F6 для закрытия)")

func close_ui() -> void:
	is_ui_open = false
	if panel:
		panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	show_toast("РЕЖИМ БОГА: ПАНЕЛЬ ЗАКРЫТА")

func show_toast(text: String, duration: float = 3.0) -> void:
	if toast_label:
		toast_label.text = text
		toast_label.visible = true
		toast_timer = duration

# =========================================================================
# ДЕЙСТВИЯ DEV-МЕНЮ
# =========================================================================
func set_player_god_mode(enabled: bool) -> void:
	player_god_mode = enabled
	if enabled:
		heal_player()
		show_toast("🛡️ БЕССМЕРТИЕ ИГРОКА: ВКЛЮЧЕНО")
	else:
		show_toast("🛡️ БЕССМЕРТИЕ ИГРОКА: ВЫКЛЮЧЕНО")

func set_caravan_god_mode(enabled: bool) -> void:
	caravan_god_mode = enabled
	if enabled:
		heal_caravan()
		show_toast("🐪 БЕССМЕРТИЕ КАРАВАНА: ВКЛЮЧЕНО")
	else:
		show_toast("🐪 БЕССМЕРТИЕ КАРАВАНА: ВЫКЛЮЧЕНО")

func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	if enabled:
		refill_all_ammo()
		show_toast("♾️ БЕСКОНЕЧНЫЕ ПАТРОНЫ: ВКЛЮЧЕНО")
	else:
		show_toast("♾️ БЕСКОНЕЧНЫЕ ПАТРОНЫ: ВЫКЛЮЧЕНО")

func heal_player() -> void:
	var player := _get_first_node("player")
	if player and is_instance_valid(player):
		player.health = 100
		if player.has_signal("health_changed"):
			player.health_changed.emit(100)
		show_toast("❤ ЗДОРОВЬЕ ИГРОКА ВОССТАНОВЛЕНО (100 HP)")
	else:
		show_toast("Игрок не найден")

func heal_caravan() -> void:
	var caravan := _get_first_node("caravan")
	if caravan and is_instance_valid(caravan):
		var max_hp: int = int(caravan.get("MAX_HEALTH")) if caravan.get("MAX_HEALTH") != null else 500
		caravan.health = max_hp
		caravan.is_destroyed = false
		if caravan.has_signal("health_changed"):
			caravan.health_changed.emit(caravan.health, max_hp)
		show_toast("🛡️ КАРАВАН ПОЛНОСТЬЮ ПОЧИНЕН (500 HP)")
	else:
		show_toast("Караван не найден")

func set_time_freeze(frozen: bool) -> void:
	time_frozen = frozen
	if frozen:
		Engine.time_scale = 0.0001
		show_toast("⏸ ВРЕМЯ ЗАМОРОЖЕНО (TIME FREEZE)")
	else:
		Engine.time_scale = 1.0
		show_toast("▶ ВРЕМЯ ВОЗОБНОВЛЕНО (НОРМАЛЬНЫЙ ХОД)")

func set_enemies_frozen(frozen: bool) -> void:
	enemies_frozen = frozen
	var enemies := _get_nodes("Enemies")
	for e in enemies:
		if is_instance_valid(e):
			e.set_physics_process(not frozen)
			e.set_process(not frozen)
	show_toast("🛑 ЗОМБИ ЗАМОРОЖЕНЫ" if frozen else "▶ ЗОМБИ РАЗМОРОЖЕНЫ")

func set_caravan_speed(speed_mult: float) -> void:
	caravan_speed_mult = speed_mult
	var caravan := _get_first_node("caravan")
	if caravan and is_instance_valid(caravan):
		var base_spd: float = float(caravan.get("BASE_SPEED")) if caravan.get("BASE_SPEED") != null else 2.25
		caravan.move_speed = base_spd * caravan_speed_mult
	if lbl_caravan_spd:
		lbl_caravan_spd.text = "Скорость Осла: x%.1f" % caravan_speed_mult
	show_toast("🐪 СКОРОСТЬ ОСЛА: x%.1f" % caravan_speed_mult)

func set_player_speed(speed_mult: float) -> void:
	player_speed_mult = speed_mult
	var player := _get_first_node("player")
	if player and is_instance_valid(player):
		if player.get("walk_speed") != null:
			player.walk_speed = 9.0 * player_speed_mult
		if player.get("run_speed") != null:
			player.run_speed = 12.0 * player_speed_mult
	if lbl_player_spd:
		lbl_player_spd.text = "Скорость Игрока: x%.1f" % player_speed_mult
	show_toast("🏃 СКОРОСТЬ ИГРОКА: x%.1f" % player_speed_mult)

func set_time_of_day(time_val: float) -> void:
	var world_setup := _get_first_node("world_setup")
	if world_setup and is_instance_valid(world_setup):
		world_setup.time_of_day = clampf(time_val, 0.0, 1.0)
		if world_setup.has_method("_update_lighting_and_sky"):
			world_setup._update_lighting_and_sky()
	_update_time_label(time_val)

func set_freeze_day_night(frozen: bool) -> void:
	freeze_day_night = frozen
	var world_setup := _get_first_node("world_setup")
	if world_setup and is_instance_valid(world_setup):
		world_setup.pause_time = frozen
	show_toast("⏸ СМЕНА СУТОК ОСТАНОВЛЕНА" if frozen else "▶ СМЕНА СУТОК ВКЛЮЧЕНА")

func kill_all_enemies() -> void:
	var count := 0
	var enemies := _get_nodes("Enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999)
			count += 1
	var enemies2 := _get_nodes("enemy")
	for e in enemies2:
		if is_instance_valid(e) and not enemies.has(e) and e.has_method("take_damage"):
			e.take_damage(99999)
			count += 1
	show_toast("💥 УНИЧТОЖЕНО %d ЗОМБИ (NUKE)" % count)

func teleport_to_caravan() -> void:
	var player := _get_first_node("player")
	var caravan := _get_first_node("caravan")
	if player and caravan and is_instance_valid(player) and is_instance_valid(caravan):
		player.global_position = caravan.global_position + Vector3(0.0, 1.2, 3.5)
		show_toast("🐪 ТЕЛЕПОРТАЦИЯ К КАРАВАНУ УСПЕШНА")
	else:
		show_toast("Караван или игрок не найден")

func teleport_to_camp() -> void:
	var player := _get_first_node("player")
	var camps := _get_nodes("outpost_camp")
	if player and not camps.is_empty() and is_instance_valid(player):
		var target_camp = camps[0]
		player.global_position = target_camp.global_position + Vector3(0.0, 1.2, 0.0)
		show_toast("⛺ ТЕЛЕПОРТАЦИЯ В ЛАГЕРЬ УСПЕШНА")
	else:
		show_toast("Лагерь пока не сгенерирован (пройдите дальше по дороге)")

func refill_all_ammo() -> void:
	# Восполняем обойму текущего оружия
	var wm := _get_first_node("weapon_manager")
	if not wm:
		var p := _get_first_node("player")
		if p:
			wm = p.find_child("WeaponManager", true, false)
	if wm and wm.get("ammo_manager") != null:
		var am = wm.ammo_manager
		if am.get("ammo_dict") != null:
			for k in am.ammo_dict.keys():
				am.ammo_dict[k] = 999
	show_toast("📦 ПАТРОНЫ ВО ВСЕХ ОРУЖИЯХ ПОПОЛНЕНЫ ДО МАКСИМУМА")

func spawn_zombie(z_type: String, count: int = 1) -> void:
	var player := _get_first_node("player")
	var caravan := _get_first_node("caravan")

	var base_pos := Vector3.ZERO
	var fwd_dir := Vector3(0, 0, 1)

	if player and is_instance_valid(player):
		var cam: Node3D = player.get_node_or_null("Head/Camera3D") as Node3D
		if cam:
			fwd_dir = -cam.global_transform.basis.z.normalized()
			fwd_dir.y = 0.0
			fwd_dir = fwd_dir.normalized()
		else:
			fwd_dir = -player.global_transform.basis.z.normalized()
			fwd_dir.y = 0.0
			fwd_dir = fwd_dir.normalized()
		if fwd_dir.length_squared() < 0.01:
			fwd_dir = Vector3(0, 0, 1)
		base_pos = player.global_position + fwd_dir * 8.0
	elif caravan and is_instance_valid(caravan):
		base_pos = caravan.global_position + Vector3(0, 0, 8.0)
	else:
		base_pos = Vector3(0, 0, 8.0)

	var spawner := _get_first_node("wave_spawner")

	for i in range(count):
		var offset := Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-3.5, 3.5)) if count > 1 else Vector3.ZERO
		var target_pos := base_pos + offset
		if spawner and is_instance_valid(spawner) and spawner.has_method("_spawn_single_enemy"):
			spawner._spawn_single_enemy(z_type, target_pos)
		else:
			var scn = preload("res://scenes/enemy.tscn")
			var enemy = scn.instantiate()
			enemy.zombie_type = z_type
			var sy = DesertGenerator.get_height(target_pos.x, target_pos.z) + 0.8
			target_pos.y = sy
			var tree = get_tree()
			if tree and tree.current_scene:
				var enemies_cont = tree.current_scene.get_node_or_null("Enemies")
				if not enemies_cont:
					enemies_cont = tree.current_scene
				enemies_cont.add_child(enemy)
				enemy.global_position = target_pos

	show_toast("🧟 Спавн: %s (x%d)" % [z_type, count])

# =========================================================================
# ПОСТРОЕНИЕ ПОЛЬЗОВАТЕЛЬСКОГО ИНТЕРФЕЙСА (UI)
# =========================================================================
func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 120
	canvas_layer.name = "GodModeCanvas"
	add_child(canvas_layer)

	# --- Всплывающее уведомление (Toast) внизу экрана ---
	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.visible = false
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_top = -65.0
	toast_label.offset_bottom = -25.0

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.12, 0.16, 0.92)
	toast_style.border_color = Color(0.2, 0.8, 1.0, 0.8)
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(6)
	toast_style.content_margin_left = 20
	toast_style.content_margin_right = 20
	toast_label.add_theme_stylebox_override("normal", toast_style)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	toast_label.add_theme_font_size_override("font_size", 16)
	canvas_layer.add_child(toast_label)

	# --- Главная Панель Меню ---
	panel = PanelContainer.new()
	panel.name = "GodModePanel"
	panel.visible = false
	panel.custom_minimum_size = Vector2(520, 640)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.07, 0.08, 0.11, 0.95)
	bg_style.border_color = Color(0.18, 0.75, 0.95, 0.85)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(10)
	bg_style.shadow_color = Color(0.0, 0.5, 0.8, 0.3)
	bg_style.shadow_size = 18
	bg_style.content_margin_left = 18
	bg_style.content_margin_right = 18
	bg_style.content_margin_top = 16
	bg_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", bg_style)
	canvas_layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Заголовок меню
	var title_bar := HBoxContainer.new()
	var lbl_title := Label.new()
	lbl_title.text = "⚡ РЕЖИМ БОГА / DEV-МЕНЮ (F6)"
	lbl_title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(lbl_title)

	var btn_close := Button.new()
	btn_close.text = " ✕ ЗАКРЫТЬ "
	btn_close.pressed.connect(close_ui)
	title_bar.add_child(btn_close)
	vbox.add_child(title_bar)

	vbox.add_child(_create_separator())

	# --- РАЗДЕЛ 1: БЕССМЕРТИЕ И ЗДОРОВЬЕ ---
	vbox.add_child(_create_section_label("🛡️ БЕССМЕРТИЕ И ЗДОРОВЬЕ"))

	chk_player_god = CheckBox.new()
	chk_player_god.text = " Бессмертие Игрока (Player God Mode)"
	chk_player_god.toggled.connect(set_player_god_mode)
	vbox.add_child(chk_player_god)

	chk_caravan_god = CheckBox.new()
	chk_caravan_god.text = " Бессмертие Каравана и Осла (Caravan God Mode)"
	chk_caravan_god.toggled.connect(set_caravan_god_mode)
	vbox.add_child(chk_caravan_god)

	chk_inf_ammo = CheckBox.new()
	chk_inf_ammo.text = " Бесконечные Патроны (Infinite Ammo)"
	chk_inf_ammo.toggled.connect(set_infinite_ammo)
	vbox.add_child(chk_inf_ammo)

	var hbox_heal := HBoxContainer.new()
	var btn_heal_p := Button.new()
	btn_heal_p.text = "❤ Полный Отхил (100 HP)"
	btn_heal_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_heal_p.pressed.connect(heal_player)
	hbox_heal.add_child(btn_heal_p)

	var btn_heal_c := Button.new()
	btn_heal_c.text = "🛡️ Починить Караван (500 HP)"
	btn_heal_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_heal_c.pressed.connect(heal_caravan)
	hbox_heal.add_child(btn_heal_c)
	vbox.add_child(hbox_heal)

	vbox.add_child(_create_separator())

	# --- РАЗДЕЛ 2: СКОРОСТЬ И ВРЕМЯ ---
	vbox.add_child(_create_section_label("⏳ СКОРОСТЬ И ВРЕМЯ"))

	chk_freeze_time = CheckBox.new()
	chk_freeze_time.text = " ⏸ Заморозка Мира (Time Freeze: Engine.time_scale = 0)"
	chk_freeze_time.toggled.connect(set_time_freeze)
	vbox.add_child(chk_freeze_time)

	chk_freeze_enemies = CheckBox.new()
	chk_freeze_enemies.text = " 🛑 Заморозить только Зомби (Freeze Enemies)"
	chk_freeze_enemies.toggled.connect(set_enemies_frozen)
	vbox.add_child(chk_freeze_enemies)

	# Ползунок скорости каравана
	lbl_caravan_spd = Label.new()
	lbl_caravan_spd.text = "Скорость Осла: x1.0"
	vbox.add_child(lbl_caravan_spd)

	slider_caravan_spd = HSlider.new()
	slider_caravan_spd.min_value = 0.0
	slider_caravan_spd.max_value = 5.0
	slider_caravan_spd.step = 0.25
	slider_caravan_spd.value = 1.0
	slider_caravan_spd.value_changed.connect(set_caravan_speed)
	vbox.add_child(slider_caravan_spd)

	var hbox_spd_btns := HBoxContainer.new()
	for spd in [0.0, 1.0, 2.0, 5.0]:
		var b := Button.new()
		b.text = ("0x (Стоп)" if spd == 0.0 else ("x%.0f%s" % [spd, " Турбо" if spd == 5.0 else ""]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s_val = spd
		b.pressed.connect(func():
			slider_caravan_spd.value = s_val
			set_caravan_speed(s_val)
		)
		hbox_spd_btns.add_child(b)
	vbox.add_child(hbox_spd_btns)

	# Скорость бега игрока
	lbl_player_spd = Label.new()
	lbl_player_spd.text = "Скорость Игрока: x1.0"
	vbox.add_child(lbl_player_spd)

	slider_player_spd = HSlider.new()
	slider_player_spd.min_value = 1.0
	slider_player_spd.max_value = 3.0
	slider_player_spd.step = 0.2
	slider_player_spd.value = 1.0
	slider_player_spd.value_changed.connect(set_player_speed)
	vbox.add_child(slider_player_spd)

	vbox.add_child(_create_separator())

	# --- РАЗДЕЛ 3: СУТКИ (ДЕНЬ / НОЧЬ) ---
	vbox.add_child(_create_section_label("☀️ СМЕНА ДНЯ И НОЧИ"))

	lbl_day_time = Label.new()
	lbl_day_time.text = "Время суток: 12:00 (День)"
	vbox.add_child(lbl_day_time)

	slider_day_time = HSlider.new()
	slider_day_time.min_value = 0.0
	slider_day_time.max_value = 1.0
	slider_day_time.step = 0.01
	slider_day_time.value = 0.45
	slider_day_time.value_changed.connect(set_time_of_day)
	vbox.add_child(slider_day_time)

	var hbox_time_btns := HBoxContainer.new()
	var time_presets := [
		{"name": "🌅 Рассвет", "val": 0.25},
		{"name": "☀️ Полдень", "val": 0.45},
		{"name": "🌇 Закат", "val": 0.72},
		{"name": "🌙 Ночь", "val": 0.92}
	]
	for p in time_presets:
		var b := Button.new()
		b.text = p["name"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v_val: float = float(p["val"])
		b.pressed.connect(func():
			slider_day_time.value = v_val
			set_time_of_day(v_val)
		)
		hbox_time_btns.add_child(b)
	vbox.add_child(hbox_time_btns)

	chk_freeze_sun = CheckBox.new()
	chk_freeze_sun.text = " ⏸ Зафиксировать время (остановить суточный цикл)"
	chk_freeze_sun.toggled.connect(set_freeze_day_night)
	vbox.add_child(chk_freeze_sun)

	vbox.add_child(_create_separator())

	# --- РАЗДЕЛ 4: БОЕВЫЕ И ТАКТИЧЕСКИЕ ДЕЙСТВИЯ ---
	vbox.add_child(_create_section_label("⚡ ТАКТИЧЕСКИЕ ДЕЙСТВИЯ"))

	var btn_nuke := Button.new()
	btn_nuke.text = "💥 Уничтожить всех зомби на карте (NUKE)"
	btn_nuke.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	btn_nuke.pressed.connect(kill_all_enemies)
	vbox.add_child(btn_nuke)

	var hbox_tp := HBoxContainer.new()
	var btn_tp_caravan := Button.new()
	btn_tp_caravan.text = "🐪 Телепорт к каравану"
	btn_tp_caravan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tp_caravan.pressed.connect(teleport_to_caravan)
	hbox_tp.add_child(btn_tp_caravan)

	var btn_tp_camp := Button.new()
	btn_tp_camp.text = "⛺ Телепорт к лагерю"
	btn_tp_camp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tp_camp.pressed.connect(teleport_to_camp)
	hbox_tp.add_child(btn_tp_camp)
	vbox.add_child(hbox_tp)

	var btn_ammo := Button.new()
	btn_ammo.text = "📦 Пополнить все боеприпасы до 999"
	btn_ammo.pressed.connect(refill_all_ammo)
	vbox.add_child(btn_ammo)

	vbox.add_child(_create_separator())

	# --- РАЗДЕЛ 5: СПАВН ЗОМБИ (DEV SPAWNER) ---
	vbox.add_child(_create_section_label("🧟 СПАВН ЗОМБИ (DEV SPAWNER)"))

	var grid_zombies := GridContainer.new()
	grid_zombies.columns = 2
	grid_zombies.add_theme_constant_override("h_separation", 8)
	grid_zombies.add_theme_constant_override("v_separation", 6)
	grid_zombies.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var z_configs := [
		{"type": "Walker",   "label": "🧟 Штурмовик (Walker)"},
		{"type": "Runner",   "label": "⚡ Бегун (Runner)"},
		{"type": "Brute",    "label": "🛡️ Громила (Brute)"},
		{"type": "Crawler",  "label": "🕷️ Ползун (Crawler)"},
		{"type": "Spitter",  "label": "🧪 Плевун (Spitter)"},
		{"type": "Screamer", "label": "📢 Сирена (Screamer)"},
		{"type": "Exploder", "label": "💣 Камикадзе (Exploder)"},
	]

	for cfg in z_configs:
		var z_type: String = cfg["type"]
		var b := Button.new()
		b.text = cfg["label"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): spawn_zombie(z_type, 1))
		grid_zombies.add_child(b)

	# Кнопка для случайного зомби
	var btn_rand := Button.new()
	btn_rand.text = "🎲 Случайный зомби"
	btn_rand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rand.pressed.connect(func():
		var all_types := ["Walker", "Runner", "Brute", "Crawler", "Spitter", "Screamer", "Exploder"]
		spawn_zombie(all_types.pick_random(), 1)
	)
	grid_zombies.add_child(btn_rand)
	vbox.add_child(grid_zombies)

	# Кнопки спавна групп и орд
	var hbox_horde := HBoxContainer.new()
	var btn_all_types := Button.new()
	btn_all_types.text = "☠️ Все виды (по 1 шт)"
	btn_all_types.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_all_types.pressed.connect(func():
		for t in ["Walker", "Runner", "Brute", "Crawler", "Spitter", "Screamer", "Exploder"]:
			spawn_zombie(t, 1)
		show_toast("☠️ Заспавнены все 7 видов зомби!")
	)
	hbox_horde.add_child(btn_all_types)

	var btn_horde := Button.new()
	btn_horde.text = "🔥 Орда x3 (21 шт)"
	btn_horde.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_horde.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	btn_horde.pressed.connect(func():
		for t in ["Walker", "Runner", "Brute", "Crawler", "Spitter", "Screamer", "Exploder"]:
			spawn_zombie(t, 3)
		show_toast("🔥 Заспавнена ОРДА: 21 кибер-зомби!")
	)
	hbox_horde.add_child(btn_horde)
	vbox.add_child(hbox_horde)

func _refresh_ui_values() -> void:
	if chk_player_god:
		chk_player_god.set_pressed_no_signal(player_god_mode)
	if chk_caravan_god:
		chk_caravan_god.set_pressed_no_signal(caravan_god_mode)
	if chk_inf_ammo:
		chk_inf_ammo.set_pressed_no_signal(infinite_ammo)
	if chk_freeze_time:
		chk_freeze_time.set_pressed_no_signal(time_frozen)
	if chk_freeze_enemies:
		chk_freeze_enemies.set_pressed_no_signal(enemies_frozen)
	if chk_freeze_sun:
		chk_freeze_sun.set_pressed_no_signal(freeze_day_night)
	if slider_caravan_spd:
		slider_caravan_spd.set_value_no_signal(caravan_speed_mult)
		lbl_caravan_spd.text = "Скорость Осла: x%.1f" % caravan_speed_mult
	if slider_player_spd:
		slider_player_spd.set_value_no_signal(player_speed_mult)
		lbl_player_spd.text = "Скорость Игрока: x%.1f" % player_speed_mult

	var world_setup := _get_first_node("world_setup")
	if world_setup and is_instance_valid(world_setup) and slider_day_time:
		var cur_tod: float = float(world_setup.get("time_of_day")) if world_setup.get("time_of_day") != null else 0.45
		slider_day_time.set_value_no_signal(cur_tod)
		_update_time_label(cur_tod)

func _update_time_label(time_norm: float) -> void:
	var total_minutes := int(time_norm * 24.0 * 60.0)
	var hours := (total_minutes / 60) % 24
	var minutes := total_minutes % 60
	var phase_name := "День"
	if time_norm < 0.22 or time_norm >= 0.85:
		phase_name = "Ночь"
	elif time_norm >= 0.22 and time_norm < 0.35:
		phase_name = "Рассвет"
	elif time_norm >= 0.68 and time_norm < 0.85:
		phase_name = "Закат"
	if lbl_day_time:
		lbl_day_time.text = "Время суток: %02d:%02d (%s)" % [hours, minutes, phase_name]

func _create_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	l.add_theme_font_size_override("font_size", 14)
	return l

func _create_separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 6)
	return s
