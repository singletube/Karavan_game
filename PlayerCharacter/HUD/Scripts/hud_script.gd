extends CanvasLayer

class_name HUD

#player character reference variable
@onready var play_char: PlayerCharacter = $".."
@onready var weapon_manager: Node3D = %WeaponManager

#play char label references variables
@onready var current_state_label_text: Label = %CurrentStateLabelText
@onready var desired_move_speed_label_text: Label = %DesiredMoveSpeedLabelText
@onready var velocity_label_text: Label = %VelocityLabelText
@onready var velocity_vector_label_text : Label = %VelocityVectorLabelText
@onready var is_on_floor_label_text: Label = %IsOnFloorLabelText
@onready var ceiling_check_label_text: Label = %CeilingCheckLabelText
@onready var jump_buffer_label_text: Label = %JumpBufferLabelText
@onready var coyote_time_label_text: Label = %CoyoteTimeLabelText
@onready var nb_jumps_in_air_allowed_label_text: Label = %NbJumpsInAirAllowedLabelText
@onready var jump_cooldown_label_text: Label = %JumpCooldownLabelText
@onready var frames_per_second_label_text: Label = %FramesPerSecondLabelText
@onready var camera_rotation_label_text: Label = %CameraRotationLabelText
@onready var current_fov_label_text: Label = %CurrentFOVLabelText
@onready var camera_bob_vertical_offset_label_text: Label = %CameraBobVerticalOffsetLabelText
@onready var speed_lines_container: ColorRect = %SpeedLinesContainer

#weapon label references variables
@onready var weapon_stack_label_text: Label = %WeaponStackLabelText
@onready var weapon_name_label_text: Label = %WeaponNameLabelText
@onready var nb_ammo_in_mag_label_text: Label = %NbAmmoInMagLabelText
@onready var nb_ammo_total_label_text: Label = %NbAmmoTotalLabelText
@onready var weapon_properties: Control = $WeaponProperties

var health_panel: PanelContainer
var health_label: Label
var health_bar: ProgressBar
var death_overlay: ColorRect
var wave_label: Label
var caravan_panel: PanelContainer
var caravan_label: Label
var caravan_bar: ProgressBar
var time_panel: PanelContainer
var time_label: Label
var flashlight_label: Label
var interact_box: PanelContainer
var interact_label: Label
var interact_bar: ProgressBar
var toast_label: Label
var _is_caravan_blocked: bool = false

var compass_panel: PanelContainer
var compass_tape: Control
var compass_caravan_label: Label
var caravan_ref: Node3D = null
var compass_pulse_timer: float = 0.0
var _caravan_last_health: int = -1
var _caravan_hurt_timer: float = 0.0

func _ready() -> void:
	weapon_manager.weapon_stack_updated.connect(Callable(self, "update_weapon_stack_display"))
	$PlayerCharacterProperties.hide()
	$FPSProperties.hide()
	weapon_properties.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_properties.offset_left = -300.0
	weapon_properties.offset_top = -116.0
	weapon_properties.offset_right = -12.0
	weapon_properties.offset_bottom = -12.0
	for label in [weapon_stack_label_text, weapon_name_label_text, nb_ammo_in_mag_label_text, nb_ammo_total_label_text]:
		label.add_theme_font_size_override("font_size", 16)
	weapon_name_label_text.text = "ОРУЖИЕ:"
	nb_ammo_in_mag_label_text.text = "В МАГАЗИНЕ:"
	nb_ammo_total_label_text.text = "В ЗАПАСЕ:"
	_build_game_hud()
	if play_char.has_signal("health_changed"):
		play_char.connect("health_changed", _on_health_changed)
	if play_char.has_signal("player_died"):
		play_char.connect("player_died", _on_player_died)
	if play_char.has_signal("flashlight_toggled"):
		play_char.connect("flashlight_toggled", _on_flashlight_toggled)
	_on_health_changed(int(play_char.get("health")))
	update_weapon_stack_display()
	_connect_wave_spawner()
	_connect_caravan()
	
func _process(delta : float) -> void:
	display_current_FPS()
	display_play_char_properties()
	display_weapon_properties()
	_update_time_display()
	_update_compass(delta)
	
func display_play_char_properties() -> void:
	#player character properties
	current_state_label_text.set_text(str(play_char.state_machine.curr_state_name))
	desired_move_speed_label_text.set_text(str(round_to_3_decimals(play_char.desired_move_speed)))
	velocity_label_text.set_text(str(round_to_3_decimals(play_char.velocity.length())))
	velocity_vector_label_text.set_text(str("[ ", round_to_3_decimals(play_char.velocity.x)," ", round_to_3_decimals(play_char.velocity.y)," ", round_to_3_decimals(play_char.velocity.z), " ]"))
	is_on_floor_label_text.set_text(str(play_char.is_on_floor()))
	ceiling_check_label_text.set_text(str(play_char.ceiling_check.is_colliding()))
	jump_buffer_label_text.set_text(str(play_char.jump_buff_on))
	coyote_time_label_text.set_text(str(round_to_3_decimals(play_char.coyote_jump_cooldown)))
	nb_jumps_in_air_allowed_label_text.set_text(str(play_char.nb_jumps_in_air_allowed))
	jump_cooldown_label_text.set_text(str(round_to_3_decimals(play_char.jump_cooldown)))
	
	#camera properties
	camera_rotation_label_text.set_text(str("[ ", round_to_3_decimals(play_char.cam.rotation.x)," ", round_to_3_decimals(play_char.cam.rotation.y)," ", round_to_3_decimals(play_char.cam.rotation.z), " ]"))
	current_fov_label_text.set_text(str(play_char.cam.fov))
	camera_bob_vertical_offset_label_text.set_text(str(round_to_3_decimals(play_char.cam.v_offset)))
	
func update_weapon_stack_display() -> void:
	weapon_stack_label_text.text = "1–6 / КОЛЕСО — СМЕНА"
	
func display_weapon_properties() -> void:
	if weapon_manager.current_weapon:
		var resource: WeaponResource = weapon_manager.current_weapon.resources
		if resource.weapon_name == "Chainsaw":
			weapon_name_label_text.text = "БЕНЗОПИЛА"
			nb_ammo_in_mag_label_text.text = "∞"
			nb_ammo_total_label_text.text = "ТОПЛИВО"
			return

		var ammo_per_shot := maxi(1, resource.nb_proj_shots_at_same_time)
		var magazine := floori(float(resource.total_ammo_in_mag) / ammo_per_shot)
		var reserve := floori(float(weapon_manager.ammo_manager.ammo_dict.get(resource.ammo_type, 0)) / ammo_per_shot)
		if resource.all_ammo_in_mag:
			magazine = reserve
			reserve = 0
		weapon_name_label_text.text = _localized_weapon_name(resource.weapon_name)
		nb_ammo_in_mag_label_text.text = str(magazine)
		nb_ammo_total_label_text.text = str(reserve)

func _localized_weapon_name(weapon_name: String) -> String:
	var names := {
		"Pistol": "ПИСТОЛЕТ",
		"Shotgun": "ДРОБОВИК",
		"AssaultRifle": "АВТОМАТ",
		"SniperRifle": "СНАЙПЕРКА",
		"RocketLauncher": "РАКЕТНИЦА",
		"Chainsaw": "БЕНЗОПИЛА",
	}
	return names.get(weapon_name, weapon_name)

var blood_overlay: Control
var _blood_textures: Array[ImageTexture] = []

func _build_game_hud() -> void:
	_init_blood_textures()
	blood_overlay = Control.new()
	blood_overlay.name = "ScreenBloodOverlay"
	blood_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blood_overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.055, 0.88)
	panel_style.border_color = Color(0.85, 0.62, 0.25, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	var health_box := PanelContainer.new()
	health_box.name = "HealthPanel"
	health_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_box.offset_left = 12.0
	health_box.offset_top = -58.0
	health_box.offset_right = 230.0
	health_box.offset_bottom = -12.0
	health_box.add_theme_stylebox_override("panel", panel_style)
	var health_column := VBoxContainer.new()
	health_column.add_theme_constant_override("separation", 3)
	health_box.add_child(health_column)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.84))
	health_column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(196.0, 14.0)
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.14, 0.035, 0.035, 1.0)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.9, 0.25, 1.0)
	health_bar.add_theme_stylebox_override("background", bar_background)
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	health_column.add_child(health_bar)
	add_child(health_box)

	var controls_hint := Label.new()
	controls_hint.name = "ControlsHint"
	controls_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls_hint.offset_left = -500.0
	controls_hint.offset_top = -50.0
	controls_hint.offset_right = 500.0
	controls_hint.offset_bottom = -8.0
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_hint.text = "1–6 Оружие · ЛКМ огонь/пилить · R перезар · F фонарик · E разобрать/лут\nКолесо мыши — смена · C/X присесть · Защищайте караван и осла!"
	controls_hint.add_theme_font_size_override("font_size", 13)
	controls_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	controls_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	controls_hint.add_theme_constant_override("shadow_offset_x", 1)
	controls_hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(controls_hint)

	var caravan_style := StyleBoxFlat.new()
	caravan_style.bg_color = Color(0.04, 0.035, 0.02, 0.9)
	caravan_style.border_color = Color(0.92, 0.72, 0.28, 0.9)
	caravan_style.set_border_width_all(1)
	caravan_style.set_corner_radius_all(6)

	caravan_panel = PanelContainer.new()
	caravan_panel.name = "CaravanPanel"
	caravan_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caravan_panel.offset_left = -160.0
	caravan_panel.offset_top = 62.0
	caravan_panel.offset_right = 160.0
	caravan_panel.offset_bottom = 106.0
	caravan_panel.add_theme_stylebox_override("panel", caravan_style)

	var caravan_col := VBoxContainer.new()
	caravan_col.add_theme_constant_override("separation", 2)
	caravan_panel.add_child(caravan_col)

	caravan_label = Label.new()
	caravan_label.text = "КАРАВАН (ПОВОЗКА И ОСЁЛ): 500 / 500"
	caravan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caravan_label.add_theme_font_size_override("font_size", 13)
	caravan_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 1.0))
	caravan_col.add_child(caravan_label)

	caravan_bar = ProgressBar.new()
	caravan_bar.min_value = 0.0
	caravan_bar.max_value = 500.0
	caravan_bar.value = 500.0
	caravan_bar.show_percentage = false
	caravan_bar.custom_minimum_size = Vector2(300.0, 10.0)

	var c_bar_bg := StyleBoxFlat.new()
	c_bar_bg.bg_color = Color(0.12, 0.08, 0.04, 1.0)
	var c_bar_fill := StyleBoxFlat.new()
	c_bar_fill.bg_color = Color(0.95, 0.76, 0.22, 1.0)
	caravan_bar.add_theme_stylebox_override("background", c_bar_bg)
	caravan_bar.add_theme_stylebox_override("fill", c_bar_fill)
	caravan_col.add_child(caravan_bar)
	add_child(caravan_panel)

	wave_label = Label.new()
	wave_label.name = "WaveStatus"
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.offset_left = -260.0
	wave_label.offset_top = 112.0
	wave_label.offset_right = 260.0
	wave_label.offset_bottom = 160.0
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.text = "ОЖИДАНИЕ ВОЛНЫ"
	wave_label.add_theme_font_size_override("font_size", 18)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	wave_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	wave_label.add_theme_constant_override("shadow_offset_x", 1)
	wave_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(wave_label)

	# Панель подсказки взаимодействия [E] (по центру экрана под прицелом)
	var interact_style := StyleBoxFlat.new()
	interact_style.bg_color = Color(0.04, 0.04, 0.05, 0.88)
	interact_style.border_color = Color(0.9, 0.75, 0.3, 0.9)
	interact_style.set_border_width_all(1)
	interact_style.set_corner_radius_all(6)

	interact_box = PanelContainer.new()
	interact_box.name = "InteractBox"
	interact_box.set_anchors_preset(Control.PRESET_CENTER)
	interact_box.offset_left = -170.0
	interact_box.offset_top = 46.0
	interact_box.offset_right = 170.0
	interact_box.offset_bottom = 98.0
	interact_box.add_theme_stylebox_override("panel", interact_style)

	var interact_vbox := VBoxContainer.new()
	interact_vbox.add_theme_constant_override("separation", 3)
	interact_box.add_child(interact_vbox)

	interact_label = Label.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[E] ВЗАИМОДЕЙСТВИЕ"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 14)
	interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	interact_vbox.add_child(interact_label)

	interact_bar = ProgressBar.new()
	interact_bar.name = "InteractProgressBar"
	interact_bar.min_value = 0.0
	interact_bar.max_value = 1.0
	interact_bar.value = 0.0
	interact_bar.show_percentage = false
	interact_bar.custom_minimum_size = Vector2(280.0, 8.0)
	var i_bg := StyleBoxFlat.new()
	i_bg.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	var i_fill := StyleBoxFlat.new()
	i_fill.bg_color = Color(0.3, 1.0, 0.45, 1.0)
	interact_bar.add_theme_stylebox_override("background", i_bg)
	interact_bar.add_theme_stylebox_override("fill", i_fill)
	interact_vbox.add_child(interact_bar)

	interact_box.hide()
	add_child(interact_box)

	# Всплывающее текстовое уведомление (Toast)
	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.offset_left = -300.0
	toast_label.offset_top = -120.0
	toast_label.offset_right = 300.0
	toast_label.offset_bottom = -80.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45, 1.0))
	toast_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	toast_label.add_theme_constant_override("shadow_offset_x", 1)
	toast_label.add_theme_constant_override("shadow_offset_y", 1)
	toast_label.hide()
	add_child(toast_label)

	_build_compass()

	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0.08, 0.0, 0.0, 0.76)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.hide()
	var death_text := Label.new()
	death_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_text.text = "ВЫ ПОГИБЛИ"
	death_text.add_theme_font_size_override("font_size", 58)
	death_text.add_theme_color_override("font_color", Color(1.0, 0.18, 0.12, 1.0))
	death_overlay.add_child(death_text)
	add_child(death_overlay)

func _on_health_changed(value: int) -> void:
	var current_health := clampi(value, 0, 100)
	health_bar.value = current_health
	health_label.text = "ЗДОРОВЬЕ: %d%%" % current_health
	var fill_style := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = Color(0.2, 0.9, 0.25, 1.0).lerp(Color(0.95, 0.12, 0.08, 1.0), 1.0 - float(current_health) / 100.0)
	death_overlay.visible = current_health <= 0

func _on_player_died() -> void:
	death_overlay.show()

func _connect_wave_spawner() -> void:
	var spawner := get_tree().current_scene.get_node_or_null("WaveSpawner")
	if spawner == null:
		return
	if spawner.has_signal("wave_started"):
		spawner.connect("wave_started", _on_wave_started)
	if spawner.has_signal("wave_completed"):
		spawner.connect("wave_completed", _on_wave_completed)
	if spawner.has_signal("enemies_remaining"):
		spawner.connect("enemies_remaining", _on_enemies_remaining)
	if spawner.has_signal("wave_countdown"):
		spawner.connect("wave_countdown", _on_wave_countdown)

func _on_wave_started(wave_number: int, wave_name: String) -> void:
	wave_label.text = "ВОЛНА %d: %s\nВраги атакуют караван!" % [wave_number, wave_name.to_upper()]

func _on_wave_completed(wave_number: int) -> void:
	wave_label.text = "ВОЛНА %d ОТБИТА\nПередышка..." % wave_number

func _on_enemies_remaining(count: int) -> void:
	if count > 0 and wave_label.text.begins_with("ВОЛНА"):
		wave_label.text = "%s\nОСТАЛОСЬ ВРАГОВ: %d" % [wave_label.text.get_slice("\n", 0), count]
	elif count == 0 and wave_label.text.begins_with("ВОЛНА"):
		wave_label.text = "ВСЕ ВРАГИ УНИЧТОЖЕНЫ"

func _on_wave_countdown(seconds: int) -> void:
	if not wave_label.text.begins_with("ВОЛНА") or wave_label.text.contains("ОТБИТА"):
		wave_label.text = "ПОДГОТОВКА\nСЛЕДУЮЩАЯ ВОЛНА ЧЕРЕЗ %d СЕК" % seconds
		
func display_current_FPS() -> void:
	frames_per_second_label_text.set_text(str(Engine.get_frames_per_second()))
	
func display_speed_lines(value : bool) -> void:
	speed_lines_container.visible = value
	
func round_to_3_decimals(value: float) -> float:
	return round(value * 1000.0) / 1000.0

func _connect_caravan() -> void:
	await get_tree().process_frame
	var caravan: Node = get_tree().current_scene.get_node_or_null("Caravan")
	if not caravan:
		caravan = get_tree().get_first_node_in_group("caravan")
	if caravan == null:
		return
	caravan_ref = caravan as Node3D
	if caravan.has_signal("health_changed"):
		caravan.connect("health_changed", _on_caravan_health_changed)
	if caravan.has_signal("caravan_destroyed"):
		caravan.connect("caravan_destroyed", _on_caravan_destroyed)
	if caravan.has_signal("caravan_respawned"):
		caravan.connect("caravan_respawned", _on_caravan_respawned)
	if caravan.has_signal("caravan_blocked_status"):
		caravan.connect("caravan_blocked_status", _on_caravan_blocked_status)
	_on_caravan_health_changed(int(caravan.get("health")), int(caravan.get("MAX_HEALTH")))

func _on_caravan_blocked_status(blocked: bool, _reason: String) -> void:
	_is_caravan_blocked = blocked
	if caravan_label:
		if blocked:
			caravan_label.text = "⚠️ КАРАВАН ОСТАНОВЛЕН: ЗАВАЛ НА ПУТИ!"
			caravan_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2, 1.0))
		else:
			var caravan = get_tree().get_first_node_in_group("caravan")
			if caravan:
				_on_caravan_health_changed(int(caravan.get("health")), int(caravan.get("MAX_HEALTH")))
			caravan_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 1.0))

func show_interaction_prompt(prompt_text: String, progress: float = 0.0, show_bar: bool = false) -> void:
	if not interact_box or not interact_label or not interact_bar:
		return
	interact_label.text = prompt_text
	interact_bar.visible = show_bar
	interact_bar.value = clampf(progress, 0.0, 1.0)
	interact_box.show()

func hide_interaction_prompt() -> void:
	if interact_box:
		interact_box.hide()

func show_toast(msg: String, col: Color = Color(0.3, 1.0, 0.45), duration: float = 2.8) -> void:
	if not toast_label:
		return
	toast_label.text = msg
	toast_label.add_theme_color_override("font_color", col)
	toast_label.modulate.a = 1.0
	toast_label.show()
	var tw := create_tween()
	tw.tween_interval(duration * 0.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, duration * 0.4)
	tw.chain().tween_callback(toast_label.hide)

func _on_caravan_health_changed(current: int, max_hp: int) -> void:
	if _caravan_last_health > 0 and current < _caravan_last_health:
		_caravan_hurt_timer = 2.8
	_caravan_last_health = current

	if caravan_bar and caravan_label:
		caravan_bar.max_value = max_hp
		caravan_bar.value = current
		caravan_label.text = "КАРАВАН (ПОВОЗКА И ОСЁЛ): %d / %d" % [current, max_hp]
		var fill_style := caravan_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style and max_hp > 0:
			fill_style.bg_color = Color(0.95, 0.76, 0.22, 1.0).lerp(Color(0.95, 0.15, 0.1, 1.0), 1.0 - (float(current) / float(max_hp)))

func _on_caravan_destroyed() -> void:
	if caravan_label:
		caravan_label.text = "КАРАВАН УНИЧТОЖЕН!"
	death_overlay.show()

func _on_caravan_respawned() -> void:
	death_overlay.hide()

# =========================================================================
# КОМПАС НАВИГАЦИИ С УКАЗАТЕЛЕМ КАРАВАНА
# =========================================================================
func _build_compass() -> void:
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.03, 0.025, 0.02, 0.88)
	c_style.border_color = Color(0.85, 0.68, 0.28, 0.85)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)

	compass_panel = PanelContainer.new()
	compass_panel.name = "CompassPanel"
	compass_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_panel.offset_left = -210.0
	compass_panel.offset_top = 10.0
	compass_panel.offset_right = 210.0
	compass_panel.offset_bottom = 58.0
	compass_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_theme_stylebox_override("panel", c_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(vbox)

	compass_tape = Control.new()
	compass_tape.name = "CompassTape"
	compass_tape.custom_minimum_size = Vector2(400.0, 24.0)
	compass_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_tape.draw.connect(_draw_compass)
	vbox.add_child(compass_tape)

	compass_caravan_label = Label.new()
	compass_caravan_label.name = "CompassCaravanLabel"
	compass_caravan_label.text = "КАРАВАН: ПОИСК..."
	compass_caravan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_caravan_label.add_theme_font_size_override("font_size", 11)
	compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	vbox.add_child(compass_caravan_label)

	add_child(compass_panel)

func _update_compass(delta: float) -> void:
	if not compass_panel:
		return

	compass_pulse_timer += delta
	if _caravan_hurt_timer > 0.0:
		_caravan_hurt_timer = maxf(0.0, _caravan_hurt_timer - delta)

	if caravan_ref == null or not is_instance_valid(caravan_ref):
		caravan_ref = get_tree().get_first_node_in_group("caravan") as Node3D

	if caravan_ref and is_instance_valid(caravan_ref) and play_char:
		var to_c: Vector3 = caravan_ref.global_position - play_char.global_position
		to_c.y = 0.0
		var dist: float = to_c.length()

		if _caravan_hurt_timer > 0.0:
			compass_caravan_label.text = "⚠️ КАРАВАН ПОД АТАКОЙ! %dм" % int(dist)
			compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
		elif _is_caravan_blocked:
			compass_caravan_label.text = "🚫 КАРАВАН ОСТАНОВЛЕН (ЗАВАЛ): %dм" % int(dist)
			compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2, 1.0))
		elif dist < 4.5:
			compass_caravan_label.text = "🐫 ВЫ В КУЗОВЕ КАРАВАНА"
			compass_caravan_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
		elif dist < 12.0:
			compass_caravan_label.text = "🐫 КАРАВАН РЯДОМ: %dм" % int(dist)
			compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1.0))
		else:
			compass_caravan_label.text = "🐫 КАРАВАН: %dм" % int(dist)
			compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))

	if compass_tape:
		compass_tape.queue_redraw()

func _draw_compass() -> void:
	if not compass_tape or not play_char or not play_char.cam:
		return

	var w: float = compass_tape.size.x
	var h: float = compass_tape.size.y
	var cx: float = w * 0.5

	# Вектор взгляда камеры по горизонтали
	var cam_fwd: Vector3 = -play_char.cam.global_transform.basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length_squared() < 0.001:
		cam_fwd = Vector3(0.0, 0.0, -1.0)
	cam_fwd = cam_fwd.normalized()

	var cam_yaw_rad: float = atan2(cam_fwd.x, -cam_fwd.z)
	var cam_yaw_deg: float = wrapf(rad_to_deg(cam_yaw_rad), 0.0, 360.0)

	var fov_deg: float = 120.0
	var pixels_per_deg: float = w / fov_deg

	# Направляющая линия шкалы
	compass_tape.draw_line(Vector2(12.0, h - 3.0), Vector2(w - 12.0, h - 3.0), Color(0.85, 0.65, 0.25, 0.4), 1.0)

	var font: Font = compass_tape.get_theme_default_font()
	var font_size: int = 11

	# Насечки делений шкалы компаса через каждые 15 градусов
	var start_deg: int = int(floor((cam_yaw_deg - 60.0) / 15.0)) * 15
	var end_deg: int = int(ceil((cam_yaw_deg + 60.0) / 15.0)) * 15

	for d_deg in range(start_deg, end_deg + 1, 15):
		var diff: float = float(d_deg) - cam_yaw_deg
		var x: float = cx + diff * pixels_per_deg
		if x < 6.0 or x > w - 6.0:
			continue

		var norm_deg: int = int(round(wrapf(float(d_deg), 0.0, 360.0))) % 360
		var is_cardinal: bool = (norm_deg % 90 == 0)
		var is_subcardinal: bool = (norm_deg % 45 == 0) and not is_cardinal

		var tick_h: float = 8.0 if is_cardinal else (5.0 if is_subcardinal else 3.0)
		var tick_col := Color(0.95, 0.85, 0.45, 0.85) if is_cardinal else Color(0.70, 0.60, 0.40, 0.55)
		compass_tape.draw_line(Vector2(x, h - 3.0), Vector2(x, h - 3.0 - tick_h), tick_col, 1.2 if is_cardinal else 1.0)

		var label_str: String = ""
		match norm_deg:
			0:   label_str = "С"
			45:  label_str = "СВ"
			90:  label_str = "В"
			135: label_str = "ЮВ"
			180: label_str = "Ю"
			225: label_str = "ЮЗ"
			270: label_str = "З"
			315: label_str = "СЗ"

		if not label_str.is_empty() and font:
			var col := Color(1.0, 0.88, 0.32, 1.0) if norm_deg == 0 else Color(0.92, 0.86, 0.72, 0.95)
			var str_sz := font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			compass_tape.draw_string(font, Vector2(x - str_sz.x * 0.5, 12.0), label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)

	# Центральный золотой визир (стрелочка ▼)
	var arrow_pts := PackedVector2Array([
		Vector2(cx - 5.0, 0.0),
		Vector2(cx + 5.0, 0.0),
		Vector2(cx, 6.0)
	])
	compass_tape.draw_colored_polygon(arrow_pts, Color(1.0, 0.85, 0.30, 1.0))

	# Метка Каравана на компасе
	if caravan_ref and is_instance_valid(caravan_ref):
		var to_c: Vector3 = caravan_ref.global_position - play_char.global_position
		to_c.y = 0.0
		if to_c.length_squared() > 0.001:
			var c_fwd := to_c.normalized()
			var c_yaw_rad: float = atan2(c_fwd.x, -c_fwd.z)
			var c_diff_deg: float = wrapf(rad_to_deg(c_yaw_rad - cam_yaw_rad), -180.0, 180.0)

			var marker_col := Color(1.0, 0.82, 0.25, 1.0)
			if _is_caravan_blocked or _caravan_hurt_timer > 0.0:
				var pulse: float = 0.5 + 0.5 * sin(compass_pulse_timer * 9.0)
				marker_col = Color(1.0, 0.2, 0.1).lerp(Color(1.0, 0.85, 0.2), pulse)

			if abs(c_diff_deg) <= 56.0:
				var marker_x: float = cx + c_diff_deg * pixels_per_deg
				compass_tape.draw_circle(Vector2(marker_x, 15.0), 3.5, marker_col)
				if font:
					var c_icon := "🐫"
					var icon_sz := font.get_string_size(c_icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
					compass_tape.draw_string(font, Vector2(marker_x - icon_sz.x * 0.5, 12.0), c_icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, marker_col)
			elif c_diff_deg < -56.0:
				if font:
					var left_str := "◀ 🐫"
					compass_tape.draw_string(font, Vector2(6.0, 15.0), left_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker_col)
			else:
				if font:
					var right_str := "🐫 ▶"
					var r_sz := font.get_string_size(right_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12)
					compass_tape.draw_string(font, Vector2(w - r_sz.x - 6.0, 15.0), right_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, marker_col)


func _init_blood_textures() -> void:
	_blood_textures.clear()
	for pattern: int in range(5):
		var size: int = 64
		var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		var center := Vector2(32.0, 32.0)
		var base_radius: float = randf_range(11.0, 16.0)

		# Основное неровное органическое пятно крови
		for y: int in range(size):
			for x: int in range(size):
				var pos := Vector2(float(x), float(y))
				var d: float = pos.distance_to(center)
				var angle: float = (pos - center).angle()
				var noise_r: float = base_radius * (1.0 + 0.35 * sin(angle * 5.0 + float(pattern)) + 0.22 * cos(angle * 3.0))
				if d <= noise_r:
					var edge_alpha: float = clampf((noise_r - d) / 2.5, 0.0, 1.0)
					var col := Color(randf_range(0.72, 0.92), 0.02, 0.035, edge_alpha * 0.92)
					img.set_pixel(x, y, col)

		# Стекающая вниз струйка капли (на некоторых текстурах)
		if pattern % 2 == 1:
			var drip_len: int = randi_range(14, 24)
			var drip_w: float = 2.8
			for dy: int in range(drip_len):
				var py: int = clampi(int(center.y) + int(base_radius * 0.5) + dy, 0, size - 1)
				var px_center: int = int(center.x) + int(sin(float(dy) * 0.45) * 2.0)
				for dx: int in range(-int(drip_w), int(drip_w) + 1):
					var px: int = clampi(px_center + dx, 0, size - 1)
					var d_tail: float = absf(float(dx)) / drip_w
					if d_tail <= 1.0:
						var a: float = (1.0 - d_tail) * (1.0 - (float(dy) / float(drip_len)) * 0.45)
						img.set_pixel(px, py, Color(0.78, 0.02, 0.03, a * 0.9))

		# Мелкие сателлитные брызги вокруг
		for s: int in range(6):
			var sat_angle: float = randf() * TAU
			var sat_dist: float = base_radius + randf_range(5.0, 13.0)
			var sat_pos: Vector2 = center + Vector2(cos(sat_angle), sin(sat_angle)) * sat_dist
			var sat_r: float = randf_range(1.4, 3.2)
			for sy: int in range(maxi(0, int(sat_pos.y - sat_r)), mini(size, int(sat_pos.y + sat_r + 1))):
				for sx: int in range(maxi(0, int(sat_pos.x - sat_r)), mini(size, int(sat_pos.x + sat_r + 1))):
					if Vector2(float(sx), float(sy)).distance_to(sat_pos) <= sat_r:
						img.set_pixel(sx, sy, Color(0.82, 0.015, 0.03, 0.88))

		_blood_textures.append(ImageTexture.create_from_image(img))

func add_screen_blood_splatter(count: int = 3) -> void:
	if not blood_overlay or _blood_textures.is_empty():
		return

	# Ограничение максимального количества брызг на экране
	if blood_overlay.get_child_count() > 22:
		var oldest: Node = blood_overlay.get_child(0)
		if oldest:
			oldest.queue_free()

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280.0, 720.0)

	for i in range(count):
		var tex: ImageTexture = _blood_textures[randi() % _blood_textures.size()]
		var splat := TextureRect.new()
		splat.texture = tex
		splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		splat.pivot_offset = Vector2(32.0, 32.0)
		splat.rotation = randf() * TAU

		var s: float = randf_range(1.0, 2.2)
		splat.scale = Vector2(s, s)

		# Расположение на экране: чаще ближе к центру и разлетается по сторонам
		var rx: float = randf_range(vp_size.x * 0.15, vp_size.x * 0.85)
		var ry: float = randf_range(vp_size.y * 0.15, vp_size.y * 0.85)
		splat.position = Vector2(rx, ry)

		splat.modulate = Color(1.0, 1.0, 1.0, randf_range(0.85, 1.0))
		blood_overlay.add_child(splat)

		# Плавное стекание капель вниз и постепенное высыхание / исчезновение
		var fade_time: float = randf_range(2.0, 3.4)
		var drip_offset: float = randf_range(18.0, 45.0)
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(splat, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(splat, "position:y", splat.position.y + drip_offset, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(Callable(splat, "queue_free"))

func _on_flashlight_toggled(is_on: bool) -> void:
	if flashlight_label:
		if is_on:
			flashlight_label.text = "🔦 [F] ФОНАРИК: ВКЛ"
			flashlight_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
		else:
			flashlight_label.text = "🔦 [F] ФОНАРИК: ВЫКЛ"
			flashlight_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))

func _update_time_display() -> void:
	if time_label == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root and scene_root.has_method("get_clock_time"):
		var clock_str: String = scene_root.get_clock_time()
		var phase_name: String = scene_root.get_phase_name()
		var icon: String = "☀️"
		var col: Color = Color(1.0, 0.92, 0.72)
		match phase_name:
			"ДЕНЬ":
				icon = "☀️"
				col = Color(1.0, 0.92, 0.65)
			"ЗАКАТ":
				icon = "🌅"
				col = Color(1.0, 0.55, 0.25)
			"НОЧЬ":
				icon = "🌙"
				col = Color(0.65, 0.80, 1.0)
			"РАССВЕТ":
				icon = "🌄"
				col = Color(1.0, 0.75, 0.50)
		time_label.text = "%s %s · %s" % [icon, clock_str, phase_name]
		time_label.add_theme_color_override("font_color", col)
	
	
	
	
	
	
