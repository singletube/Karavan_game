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
	_on_health_changed(int(play_char.get("health")))
	update_weapon_stack_display()
	_connect_wave_spawner()
	_connect_caravan()
	
func _process(_delta : float) -> void:
	display_current_FPS()
	
	display_play_char_properties()
	
	display_weapon_properties()
	
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
	weapon_stack_label_text.text = "1–5 / КОЛЕСО — СМЕНА"
	
func display_weapon_properties() -> void:
	if weapon_manager.current_weapon:
		var resource: WeaponResource = weapon_manager.current_weapon.resources
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
	}
	return names.get(weapon_name, weapon_name)

func _build_game_hud() -> void:
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
	controls_hint.text = "1 Пистолет · 2 Автомат · 3 Дробовик · 4 Снайперка · 5 Ракетница\nЛКМ — огонь · R — перезарядка · колесо — смена · C/X — присесть"
	controls_hint.add_theme_font_size_override("font_size", 13)
	controls_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	controls_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	controls_hint.add_theme_constant_override("shadow_offset_x", 1)
	controls_hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(controls_hint)

	wave_label = Label.new()
	wave_label.name = "WaveStatus"
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.offset_left = -260.0
	wave_label.offset_top = 12.0
	wave_label.offset_right = 260.0
	wave_label.offset_bottom = 60.0
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.text = "ОЖИДАНИЕ ВОЛНЫ"
	wave_label.add_theme_font_size_override("font_size", 18)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	wave_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	wave_label.add_theme_constant_override("shadow_offset_x", 1)
	wave_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(wave_label)

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
	if caravan.has_signal("health_changed"):
		caravan.connect("health_changed", _on_caravan_health_changed)
	if caravan.has_signal("caravan_destroyed"):
		caravan.connect("caravan_destroyed", _on_caravan_destroyed)
	if caravan.has_signal("caravan_respawned"):
		caravan.connect("caravan_respawned", _on_caravan_respawned)
	_on_caravan_health_changed(int(caravan.get("health")), int(caravan.get("MAX_HEALTH")))

func _on_caravan_health_changed(current: int, max_hp: int) -> void:
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
	
	
	
	
	
	
