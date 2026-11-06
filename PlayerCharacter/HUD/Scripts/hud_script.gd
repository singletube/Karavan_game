extends CanvasLayer

class_name HUD

const CampDialogueUIClass = preload("res://scripts/camp_dialogue_ui.gd")

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
var wave_panel: PanelContainer = null
var wave_label: Label = null
var wave_sub_label: Label = null
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
var camp_dialogue_ui: Control = null
var _is_caravan_blocked: bool = false

# --- Combat Feedback (Хэдшот и хитмаркер) ---
var headshot_container: Control = null
var headshot_icon: TextureRect = null
var headshot_label: Label = null
var hitmarker_ctrl: Control = null
var hitmarker_color: Color = Color.WHITE
var headshot_audio: AudioStreamPlayer = null

# --- Pause Menu (Пауза на ESC / F1) ---
var pause_overlay: Control = null
var pause_status_label: Label = null

# --- Out of Ammo Meme ---
var no_ammo_meme_panel: PanelContainer = null
var no_ammo_meme_texture: TextureRect = null
var _last_weapon_had_ammo: bool = true
var _meme_tween: Tween = null

var compass_panel: PanelContainer
var compass_tape: Control
var compass_caravan_label: Label
var caravan_ref: Node3D = null
var compass_pulse_timer: float = 0.0
var _caravan_last_health: int = -1
var _caravan_hurt_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	weapon_manager.weapon_stack_updated.connect(Callable(self, "update_weapon_stack_display"))
	$PlayerCharacterProperties.hide()
	$FPSProperties.hide()
	var crosshair := get_node_or_null("Crosshair") as Control
	if crosshair:
		crosshair.modulate = Color(1.0, 1.0, 1.0, 0.75)
		crosshair.offset_left = -12.0
		crosshair.offset_top = -12.0
		crosshair.offset_right = 12.0
		crosshair.offset_bottom = 12.0
	_style_weapon_properties()
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

func _style_weapon_properties() -> void:
	# Скрываем старые debug-метки ("Available weapons :", "Weapon name :", etc.)
	var left_col := weapon_properties.get_node_or_null("PanelContainer/HBoxContainer/VBoxContainer")
	if left_col:
		left_col.hide()

	# Полностью убираем серую рамку и фоновую коробку — делаем стильный парящий минималистичный HUD
	var transparent_style := StyleBoxEmpty.new()
	weapon_properties.add_theme_stylebox_override("panel", transparent_style)
	var pc := weapon_properties.get_node_or_null("PanelContainer") as PanelContainer
	if pc:
		pc.add_theme_stylebox_override("panel", transparent_style)

	weapon_properties.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_properties.offset_left = -220.0
	weapon_properties.offset_top = -85.0
	weapon_properties.offset_right = -24.0
	weapon_properties.offset_bottom = -20.0

	# Название оружия: аккуратный золотистый трекинг без рамок
	weapon_name_label_text.add_theme_font_size_override("font_size", 13)
	weapon_name_label_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 0.95))
	weapon_name_label_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	weapon_name_label_text.add_theme_constant_override("shadow_offset_x", 1)
	weapon_name_label_text.add_theme_constant_override("shadow_offset_y", 1)
	weapon_name_label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Патроны в магазине: крупный, четкий, чистый белый шрифт (как в современных AAA-шутерах)
	nb_ammo_in_mag_label_text.add_theme_font_size_override("font_size", 34)
	nb_ammo_in_mag_label_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	nb_ammo_in_mag_label_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	nb_ammo_in_mag_label_text.add_theme_constant_override("shadow_offset_x", 2)
	nb_ammo_in_mag_label_text.add_theme_constant_override("shadow_offset_y", 2)
	nb_ammo_in_mag_label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Патроны в резерве: полупрозрачный приглушенный тон
	nb_ammo_total_label_text.add_theme_font_size_override("font_size", 16)
	nb_ammo_total_label_text.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70, 0.65))
	nb_ammo_total_label_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	nb_ammo_total_label_text.add_theme_constant_override("shadow_offset_x", 1)
	nb_ammo_total_label_text.add_theme_constant_override("shadow_offset_y", 1)
	nb_ammo_total_label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Подсказка по выбору оружия — скрываем, чтобы не захламлять правый угол
	weapon_stack_label_text.hide()
	
func _process(delta : float) -> void:
	if get_tree().paused:
		return
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
	weapon_stack_label_text.text = "[1-6] Оружие · [V] Пинок"
	
func display_weapon_properties() -> void:
	if weapon_manager.current_weapon:
		var resource: WeaponResource = weapon_manager.current_weapon.resources
		if resource.weapon_name == "Chainsaw":
			weapon_name_label_text.text = "БЕНЗОПИЛА"
			nb_ammo_in_mag_label_text.text = "∞"
			nb_ammo_total_label_text.text = " | БАК ПОЛОН"
			nb_ammo_in_mag_label_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
			return

		var ammo_per_shot := maxi(1, resource.nb_proj_shots_at_same_time)
		var magazine := floori(float(resource.total_ammo_in_mag) / ammo_per_shot)
		var reserve := floori(float(weapon_manager.ammo_manager.ammo_dict.get(resource.ammo_type, 0)) / ammo_per_shot)
		if resource.all_ammo_in_mag:
			magazine = reserve
			reserve = 0
		weapon_name_label_text.text = _localized_weapon_name(resource.weapon_name)
		
		# Динамическая предупреждающая подсветка, если в обойме мало патронов
		var ref_mag := maxi(1, int(resource.total_ammo_in_mag_ref / ammo_per_shot)) if resource.total_ammo_in_mag_ref > 0 else 30
		var low_mag := magazine <= maxi(1, int(ref_mag * 0.25))
		if low_mag:
			nb_ammo_in_mag_label_text.add_theme_color_override("font_color", Color(1.0, 0.32, 0.25, 1.0))
		else:
			nb_ammo_in_mag_label_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))

		nb_ammo_in_mag_label_text.text = str(magazine)
		nb_ammo_total_label_text.text = " | %d" % reserve

		var total_available := magazine + reserve
		if resource.weapon_name != "Chainsaw":
			if total_available == 0:
				if _last_weapon_had_ammo:
					_last_weapon_had_ammo = false
					show_out_of_ammo_meme()
			else:
				if not _last_weapon_had_ammo:
					_last_weapon_had_ammo = true
					hide_out_of_ammo_meme()

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

	# --- 1. ПАНЕЛЬ ЗДОРОВЬЯ ИГРОКА (НИЖНИЙ ЛЕВЫЙ УГОЛ) ---
	var health_box := PanelContainer.new()
	health_box.name = "HealthPanel"
	health_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_box.offset_left = 24.0
	health_box.offset_top = -80.0
	health_box.offset_right = 240.0
	health_box.offset_bottom = -22.0

	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.04, 0.035, 0.03, 0.75)
	hp_style.border_color = Color(0.85, 0.70, 0.35, 0.40)
	hp_style.set_border_width_all(1)
	hp_style.set_corner_radius_all(10)
	hp_style.content_margin_left = 16.0
	hp_style.content_margin_right = 16.0
	hp_style.content_margin_top = 8.0
	hp_style.content_margin_bottom = 8.0
	hp_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	hp_style.shadow_size = 6
	health_box.add_theme_stylebox_override("panel", hp_style)

	var health_column := VBoxContainer.new()
	health_column.add_theme_constant_override("separation", 5)
	health_box.add_child(health_column)

	var hp_top_row := HBoxContainer.new()
	health_column.add_child(hp_top_row)

	var hp_icon := Label.new()
	hp_icon.text = "✚ HP"
	hp_icon.add_theme_font_size_override("font_size", 12)
	hp_icon.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35, 0.95))
	hp_top_row.add_child(hp_icon)

	health_label = Label.new()
	health_label.text = "100"
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_top_row.add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(180.0, 5.0)

	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.12, 0.04, 0.04, 0.85)
	bar_background.set_corner_radius_all(3)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.25, 0.88, 0.42, 1.0)
	bar_fill.set_corner_radius_all(3)

	health_bar.add_theme_stylebox_override("background", bar_background)
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	health_column.add_child(health_bar)
	add_child(health_box)

	# --- 2. МИНИМАЛИСТИЧНЫЙ ВИДЖЕТ КАРАВАНА (ВЕРХНИЙ ЦЕНТР, ПОД КОМПАСОМ) ---
	var caravan_style := StyleBoxFlat.new()
	caravan_style.bg_color = Color(0.02, 0.02, 0.02, 0.55)
	caravan_style.border_color = Color(0.85, 0.70, 0.30, 0.25)
	caravan_style.set_border_width_all(1)
	caravan_style.set_corner_radius_all(6)
	caravan_style.content_margin_left = 12.0
	caravan_style.content_margin_right = 12.0
	caravan_style.content_margin_top = 3.0
	caravan_style.content_margin_bottom = 4.0

	caravan_panel = PanelContainer.new()
	caravan_panel.name = "CaravanPanel"
	caravan_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caravan_panel.offset_left = -130.0
	caravan_panel.offset_top = 50.0
	caravan_panel.offset_right = 130.0
	caravan_panel.offset_bottom = 76.0
	caravan_panel.add_theme_stylebox_override("panel", caravan_style)

	var caravan_col := VBoxContainer.new()
	caravan_col.add_theme_constant_override("separation", 2)
	caravan_panel.add_child(caravan_col)

	caravan_label = Label.new()
	caravan_label.text = "КАРАВАН  500 / 500"
	caravan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caravan_label.add_theme_font_size_override("font_size", 10)
	caravan_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75, 0.95))
	caravan_col.add_child(caravan_label)

	caravan_bar = ProgressBar.new()
	caravan_bar.min_value = 0.0
	caravan_bar.max_value = 500.0
	caravan_bar.value = 500.0
	caravan_bar.show_percentage = false
	caravan_bar.custom_minimum_size = Vector2(220.0, 3.0)

	var c_bar_bg := StyleBoxFlat.new()
	c_bar_bg.bg_color = Color(0.10, 0.08, 0.05, 0.85)
	c_bar_bg.set_corner_radius_all(2)

	var c_bar_fill := StyleBoxFlat.new()
	c_bar_fill.bg_color = Color(0.92, 0.72, 0.25, 1.0)
	c_bar_fill.set_corner_radius_all(2)

	caravan_bar.add_theme_stylebox_override("background", c_bar_bg)
	caravan_bar.add_theme_stylebox_override("fill", c_bar_fill)
	caravan_col.add_child(caravan_bar)
	add_child(caravan_panel)

	# --- 3. СИСТЕМА БОЕВОЙ ОБРАТНОЙ СВЯЗИ (ХЭДШОТЫ И ХИТМАРКЕР) ---
	_build_combat_feedback_ui()

	# --- 4. МИНИМАЛИСТИЧНЫЙ ВИДЖЕТ ВРЕМЕНИ И ФОНАРИКА (ВЕРХНИЙ ПРАВЫЙ УГОЛ) ---
	var top_right_panel := PanelContainer.new()
	top_right_panel.name = "TopRightStatus"
	top_right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_panel.offset_left = -180.0
	top_right_panel.offset_top = 14.0
	top_right_panel.offset_right = -16.0
	top_right_panel.offset_bottom = 44.0

	var tr_style := StyleBoxFlat.new()
	tr_style.bg_color = Color(0.04, 0.035, 0.03, 0.65)
	tr_style.border_color = Color(0.85, 0.70, 0.35, 0.25)
	tr_style.set_border_width_all(1)
	tr_style.set_corner_radius_all(6)
	tr_style.content_margin_left = 10.0
	tr_style.content_margin_right = 10.0
	tr_style.content_margin_top = 2.0
	tr_style.content_margin_bottom = 2.0
	top_right_panel.add_theme_stylebox_override("panel", tr_style)

	var tr_hbox := HBoxContainer.new()
	tr_hbox.add_theme_constant_override("separation", 10)
	top_right_panel.add_child(tr_hbox)

	time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "☀️ 12:00"
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 0.95))
	tr_hbox.add_child(time_label)

	flashlight_label = Label.new()
	flashlight_label.name = "FlashlightLabel"
	flashlight_label.text = "🔦 F"
	flashlight_label.add_theme_font_size_override("font_size", 11)
	flashlight_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.8))
	tr_hbox.add_child(flashlight_label)

	add_child(top_right_panel)

	# --- 5. МИНИМАЛИСТИЧНЫЙ ИНТЕРАКТИВНЫЙ БАР [E] ПОД ПРИЦЕЛОМ ---
	var interact_style := StyleBoxFlat.new()
	interact_style.bg_color = Color(0.04, 0.035, 0.03, 0.75)
	interact_style.border_color = Color(0.9, 0.75, 0.3, 0.5)
	interact_style.set_border_width_all(1)
	interact_style.set_corner_radius_all(6)
	interact_style.content_margin_left = 12.0
	interact_style.content_margin_right = 12.0
	interact_style.content_margin_top = 6.0
	interact_style.content_margin_bottom = 6.0

	interact_box = PanelContainer.new()
	interact_box.name = "InteractBox"
	interact_box.set_anchors_preset(Control.PRESET_CENTER)
	interact_box.offset_left = -150.0
	interact_box.offset_top = 42.0
	interact_box.offset_right = 150.0
	interact_box.offset_bottom = 82.0
	interact_box.add_theme_stylebox_override("panel", interact_style)

	var interact_vbox := VBoxContainer.new()
	interact_vbox.add_theme_constant_override("separation", 4)
	interact_box.add_child(interact_vbox)

	interact_label = Label.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[E] ВЗАИМОДЕЙСТВИЕ"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 12)
	interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
	interact_vbox.add_child(interact_label)

	interact_bar = ProgressBar.new()
	interact_bar.name = "InteractProgressBar"
	interact_bar.min_value = 0.0
	interact_bar.max_value = 1.0
	interact_bar.value = 0.0
	interact_bar.show_percentage = false
	interact_bar.custom_minimum_size = Vector2(220.0, 4.0)

	var i_bg := StyleBoxFlat.new()
	i_bg.bg_color = Color(0.12, 0.10, 0.08, 0.85)
	i_bg.set_corner_radius_all(2)

	var i_fill := StyleBoxFlat.new()
	i_fill.bg_color = Color(0.35, 1.0, 0.45, 1.0)
	i_fill.set_corner_radius_all(2)

	interact_bar.add_theme_stylebox_override("background", i_bg)
	interact_bar.add_theme_stylebox_override("fill", i_fill)
	interact_vbox.add_child(interact_bar)

	interact_box.hide()
	add_child(interact_box)

	# --- 6. ТОСТ-УВЕДОМЛЕНИЯ ПО ЦЕНТРУ ---
	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.offset_left = -300.0
	toast_label.offset_top = -100.0
	toast_label.offset_right = 300.0
	toast_label.offset_bottom = -68.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
	toast_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	toast_label.add_theme_constant_override("shadow_offset_x", 1)
	toast_label.add_theme_constant_override("shadow_offset_y", 1)
	toast_label.hide()
	add_child(toast_label)

	_build_compass()

	# Диалоговое окно жителя лагеря (Торговля, Прокачка, Квесты)
	camp_dialogue_ui = CampDialogueUIClass.new()
	camp_dialogue_ui.name = "CampDialogueUI"
	add_child(camp_dialogue_ui)

	# Экран гибели
	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0.08, 0.01, 0.01, 0.82)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.hide()

	var death_text := Label.new()
	death_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_text.text = "ВЫ ПОГИБЛИ"
	death_text.add_theme_font_size_override("font_size", 48)
	death_text.add_theme_color_override("font_color", Color(1.0, 0.22, 0.16, 1.0))
	death_overlay.add_child(death_text)
	add_child(death_overlay)

	# Меню паузы (ESC / F1 с остановкой времени в одиночной игре)
	_build_pause_menu()

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

func _build_combat_feedback_ui() -> void:
	# Звук хэдшота (новый звук от пользователя, мягкая комфортная громкость)
	headshot_audio = AudioStreamPlayer.new()
	headshot_audio.name = "HeadshotAudio"
	var hs_stream = load("res://assets/audio/headshot.mp3")
	if not hs_stream:
		hs_stream = load("res://assets/audio/headshot.wav")
	if hs_stream:
		headshot_audio.stream = hs_stream
	headshot_audio.volume_db = -8.0
	add_child(headshot_audio)

	# Оповещение хэдшота с картинкой-черепом над прицелом
	headshot_container = VBoxContainer.new()
	headshot_container.name = "HeadshotContainer"
	headshot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headshot_container.set_anchors_preset(Control.PRESET_CENTER)
	headshot_container.offset_left = -110.0
	headshot_container.offset_right = 110.0
	headshot_container.offset_top = -145.0
	headshot_container.offset_bottom = -25.0
	headshot_container.pivot_offset = Vector2(110.0, 60.0)
	headshot_container.add_theme_constant_override("separation", 2)
	headshot_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Картинка черепа с пулей (загруженная пользователем)
	headshot_icon = TextureRect.new()
	headshot_icon.name = "HeadshotIcon"
	headshot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs_tex = load("res://assets/textures/headshot_icon.png")
	if hs_tex:
		headshot_icon.texture = hs_tex
	headshot_icon.custom_minimum_size = Vector2(74.0, 74.0)
	headshot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	headshot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	headshot_container.add_child(headshot_icon)

	# Текст "⚡ В ГОЛОВУ! x2.5" под картинкой
	headshot_label = Label.new()
	headshot_label.name = "HeadshotLabel"
	headshot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headshot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headshot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headshot_label.text = "⚡ В ГОЛОВУ! x2.5"
	headshot_label.add_theme_font_size_override("font_size", 19)
	headshot_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22, 1.0))
	headshot_label.add_theme_color_override("font_shadow_color", Color(0.85, 0.08, 0.08, 0.95))
	headshot_label.add_theme_constant_override("shadow_offset_x", 2)
	headshot_label.add_theme_constant_override("shadow_offset_y", 2)
	headshot_container.add_child(headshot_label)

	headshot_container.hide()
	add_child(headshot_container)

	# Хитмаркер (перекрестие попадания)
	hitmarker_ctrl = Control.new()
	hitmarker_ctrl.name = "Hitmarker"
	hitmarker_ctrl.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_ctrl.offset_left = -16.0
	hitmarker_ctrl.offset_top = -16.0
	hitmarker_ctrl.offset_right = 16.0
	hitmarker_ctrl.offset_bottom = 16.0
	hitmarker_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker_ctrl.draw.connect(_draw_hitmarker)
	hitmarker_ctrl.hide()
	add_child(hitmarker_ctrl)

	# --- МЕМ "ТАК МНОГО ПИДРИЛ И ТАК МАЛО ПАТРОНОВ" ПРИ 0 ПАТРОНАХ ---
	no_ammo_meme_panel = PanelContainer.new()
	no_ammo_meme_panel.name = "NoAmmoMemePanel"
	no_ammo_meme_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	no_ammo_meme_panel.offset_left = -340.0
	no_ammo_meme_panel.offset_top = -290.0
	no_ammo_meme_panel.offset_right = -20.0
	no_ammo_meme_panel.offset_bottom = -105.0
	no_ammo_meme_panel.pivot_offset = Vector2(160.0, 92.0)
	no_ammo_meme_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var meme_style := StyleBoxFlat.new()
	meme_style.bg_color = Color(0.04, 0.03, 0.03, 0.92)
	meme_style.border_color = Color(0.95, 0.22, 0.18, 0.90)
	meme_style.set_border_width_all(2)
	meme_style.set_corner_radius_all(8)
	meme_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	meme_style.shadow_size = 12
	no_ammo_meme_panel.add_theme_stylebox_override("panel", meme_style)

	no_ammo_meme_texture = TextureRect.new()
	no_ammo_meme_texture.name = "MemeImage"
	var meme_tex = load("res://assets/textures/out_of_ammo_meme.jpg")
	if meme_tex:
		no_ammo_meme_texture.texture = meme_tex
	no_ammo_meme_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	no_ammo_meme_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	no_ammo_meme_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_ammo_meme_panel.add_child(no_ammo_meme_texture)

	no_ammo_meme_panel.hide()
	add_child(no_ammo_meme_panel)

func _draw_hitmarker() -> void:
	if not hitmarker_ctrl:
		return
	var c := Vector2(16.0, 16.0)
	var col := hitmarker_color
	var d := 4.0
	var len := 7.0
	hitmarker_ctrl.draw_line(c + Vector2(-d, -d), c + Vector2(-d - len, -d - len), col, 2.0)
	hitmarker_ctrl.draw_line(c + Vector2(d, -d), c + Vector2(d + len, -d - len), col, 2.0)
	hitmarker_ctrl.draw_line(c + Vector2(-d, d), c + Vector2(-d - len, d + len), col, 2.0)
	hitmarker_ctrl.draw_line(c + Vector2(d, d), c + Vector2(d + len, d + len), col, 2.0)

func show_headshot_feedback() -> void:
	if headshot_audio:
		headshot_audio.pitch_scale = randf_range(0.98, 1.02)
		headshot_audio.play()
	if hitmarker_ctrl:
		hitmarker_color = Color(1.0, 0.25, 0.25, 1.0)
		hitmarker_ctrl.queue_redraw()
		hitmarker_ctrl.modulate.a = 1.0
		hitmarker_ctrl.show()
		var tw_hm := create_tween()
		tw_hm.tween_interval(0.08)
		tw_hm.tween_property(hitmarker_ctrl, "modulate:a", 0.0, 0.14)
		tw_hm.chain().tween_callback(hitmarker_ctrl.hide)

	if headshot_container:
		headshot_container.scale = Vector2(1.45, 1.45)
		headshot_container.modulate.a = 1.0
		headshot_container.show()
		var tw := create_tween().set_parallel(true)
		tw.tween_property(headshot_container, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var seq := create_tween()
		seq.tween_interval(0.50)
		seq.tween_property(headshot_container, "modulate:a", 0.0, 0.25)
		seq.chain().tween_callback(headshot_container.hide)

func show_hit_feedback() -> void:
	if hitmarker_ctrl:
		hitmarker_color = Color(1.0, 1.0, 1.0, 0.9)
		hitmarker_ctrl.queue_redraw()
		hitmarker_ctrl.modulate.a = 1.0
		hitmarker_ctrl.show()
		var tw_hm := create_tween()
		tw_hm.tween_interval(0.05)
		tw_hm.tween_property(hitmarker_ctrl, "modulate:a", 0.0, 0.09)
		tw_hm.chain().tween_callback(hitmarker_ctrl.hide)

func show_out_of_ammo_meme() -> void:
	if not no_ammo_meme_panel:
		return
	if _meme_tween and _meme_tween.is_valid():
		_meme_tween.kill()

	no_ammo_meme_panel.scale = Vector2(0.65, 0.65)
	no_ammo_meme_panel.modulate.a = 1.0
	no_ammo_meme_panel.show()

	_meme_tween = create_tween()
	_meme_tween.tween_property(no_ammo_meme_panel, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_meme_tween.tween_interval(3.2)
	_meme_tween.tween_property(no_ammo_meme_panel, "modulate:a", 0.0, 0.5)
	_meme_tween.tween_callback(no_ammo_meme_panel.hide)

func hide_out_of_ammo_meme() -> void:
	if no_ammo_meme_panel and no_ammo_meme_panel.visible:
		if _meme_tween and _meme_tween.is_valid():
			_meme_tween.kill()
		_meme_tween = create_tween()
		_meme_tween.tween_property(no_ammo_meme_panel, "modulate:a", 0.0, 0.25)
		_meme_tween.tween_callback(no_ammo_meme_panel.hide)

func _on_wave_started(_wave_number: int, _wave_name: String) -> void:
	pass

func _on_wave_completed(_wave_number: int) -> void:
	pass

func _on_enemies_remaining(_count: int) -> void:
	pass

func _on_wave_countdown(_seconds: int) -> void:
	pass
		
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

func _on_caravan_blocked_status(blocked: bool, reason: String) -> void:
	_is_caravan_blocked = blocked
	if caravan_label:
		if blocked:
			if reason.contains("ЛАГЕР"):
				caravan_label.text = "⛺ КАРАВАН В БЕЗОПАСНОСТИ: ЛАГЕРЬ ВЫЖИВШИХ"
				caravan_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
			else:
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

func open_camp_dialogue_ui(npc_type: int, npc_name: String, player: Node) -> void:
	if camp_dialogue_ui:
		camp_dialogue_ui.open_for_npc(npc_type, npc_name, player)

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
	c_style.bg_color = Color(0.02, 0.02, 0.02, 0.45)
	c_style.border_color = Color(0.85, 0.70, 0.35, 0.25)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(8)
	c_style.content_margin_left = 10.0
	c_style.content_margin_right = 10.0
	c_style.content_margin_top = 2.0
	c_style.content_margin_bottom = 2.0

	compass_panel = PanelContainer.new()
	compass_panel.name = "CompassPanel"
	compass_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_panel.offset_left = -190.0
	compass_panel.offset_top = 8.0
	compass_panel.offset_right = 190.0
	compass_panel.offset_bottom = 46.0
	compass_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_theme_stylebox_override("panel", c_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(vbox)

	compass_tape = Control.new()
	compass_tape.name = "CompassTape"
	compass_tape.custom_minimum_size = Vector2(360.0, 20.0)
	compass_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_tape.draw.connect(_draw_compass)
	vbox.add_child(compass_tape)

	compass_caravan_label = Label.new()
	compass_caravan_label.name = "CompassCaravanLabel"
	compass_caravan_label.text = "КАРАВАН: ПОИСК..."
	compass_caravan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_caravan_label.add_theme_font_size_override("font_size", 10)
	compass_caravan_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 0.95))
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

	var caravan_str: String = "КАРАВАН: ПОИСК..."
	var caravan_text_color: Color = Color(1.0, 0.85, 0.35, 1.0)

	if caravan_ref and is_instance_valid(caravan_ref) and play_char:
		var to_c: Vector3 = caravan_ref.global_position - play_char.global_position
		to_c.y = 0.0
		var dist: float = to_c.length()

		if _caravan_hurt_timer > 0.0:
			caravan_str = "⚠️ КАРАВАН ПОД АТАКОЙ! %dм" % int(dist)
			caravan_text_color = Color(1.0, 0.25, 0.2, 1.0)
		elif _is_caravan_blocked:
			caravan_str = "🚫 КАРАВАН ОСТАНОВЛЕН (ЗАВАЛ): %dм" % int(dist)
			caravan_text_color = Color(1.0, 0.45, 0.2, 1.0)
		elif dist < 4.5:
			caravan_str = "🐫 ВЫ В КУЗОВЕ КАРАВАНА"
			caravan_text_color = Color(0.4, 1.0, 0.5, 1.0)
		elif dist < 12.0:
			caravan_str = "🐫 КАРАВАН РЯДОМ: %dм" % int(dist)
			caravan_text_color = Color(1.0, 0.92, 0.5, 1.0)
		else:
			caravan_str = "🐫 КАРАВАН: %dм" % int(dist)
			caravan_text_color = Color(1.0, 0.85, 0.35, 1.0)

	# Поиск других игроков (напарников) для компаса
	var nearest_mate_dist: float = -1.0
	if play_char:
		var all_players: Array = get_tree().get_nodes_in_group("player")
		for p in all_players:
			if p != play_char and is_instance_valid(p) and p is Node3D and not (p.get("is_dead") == true):
				var to_m: Vector3 = (p as Node3D).global_position - play_char.global_position
				to_m.y = 0.0
				var m_dist: float = to_m.length()
				if nearest_mate_dist < 0.0 or m_dist < nearest_mate_dist:
					nearest_mate_dist = m_dist

	if compass_caravan_label:
		if nearest_mate_dist >= 0.0:
			compass_caravan_label.text = "%s   |   🤠 НАПАРНИК: %dм" % [caravan_str, int(nearest_mate_dist)]
		else:
			compass_caravan_label.text = caravan_str
		compass_caravan_label.add_theme_color_override("font_color", caravan_text_color)

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

	# 1. Метка Каравана на компасе (золотой 🐫)
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

	# 2. Метки других игроков (напарников) на компасе (бирюзовый/циан 🤠)
	var all_players: Array = get_tree().get_nodes_in_group("player")
	for p in all_players:
		if p != play_char and is_instance_valid(p) and p is Node3D and not (p.get("is_dead") == true):
			var mate := p as Node3D
			var to_m: Vector3 = mate.global_position - play_char.global_position
			to_m.y = 0.0
			if to_m.length_squared() > 0.001:
				var m_dist: float = to_m.length()
				var m_fwd := to_m.normalized()
				var m_yaw_rad: float = atan2(m_fwd.x, -m_fwd.z)
				var m_diff_deg: float = wrapf(rad_to_deg(m_yaw_rad - cam_yaw_rad), -180.0, 180.0)

				var mate_col := Color(0.28, 0.95, 1.0, 1.0)

				if abs(m_diff_deg) <= 56.0:
					var marker_x: float = cx + m_diff_deg * pixels_per_deg
					compass_tape.draw_circle(Vector2(marker_x, 15.0), 3.0, mate_col)
					if font:
						var m_icon := "🤠"
						var icon_sz := font.get_string_size(m_icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
						compass_tape.draw_string(font, Vector2(marker_x - icon_sz.x * 0.5, 12.0), m_icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, mate_col)
				elif m_diff_deg < -56.0:
					if font:
						var left_mate := "◀ 🤠"
						# Смещено вправо (38px), чтобы не перекрывать стрелку каравана (6px)
						compass_tape.draw_string(font, Vector2(38.0, 15.0), left_mate, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, mate_col)
				else:
					if font:
						var right_mate := "🤠 ▶"
						var rm_sz := font.get_string_size(right_mate, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11)
						# Смещено влево от края (38px), чтобы не перекрывать стрелку каравана
						compass_tape.draw_string(font, Vector2(w - rm_sz.x - 38.0, 15.0), right_mate, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, mate_col)


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

# =========================================================================
# МЕНЮ ПАУЗЫ (ESC / F1 С ПОЛНОЙ ОСТАНОВКОЙ ВРЕМЕНИ В ОДИНОЧНОЙ ИГРЕ)
# =========================================================================
func _build_pause_menu() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.04, 0.035, 0.03, 0.85)
	pause_overlay.hide()

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(center_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380.0, 360.0)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.065, 0.05, 0.95)
	p_style.border_color = Color(0.90, 0.75, 0.35, 0.70)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(12)
	p_style.content_margin_left = 28.0
	p_style.content_margin_right = 28.0
	p_style.content_margin_top = 24.0
	p_style.content_margin_bottom = 24.0
	p_style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	p_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", p_style)
	center_box.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Заголовок
	var title := Label.new()
	title.text = "⏸  ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	pause_status_label = Label.new()
	pause_status_label.text = "ОДИНОЧНАЯ ИГРА · ВРЕМЯ ОСТАНОВЛЕНО"
	pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_status_label.add_theme_font_size_override("font_size", 11)
	pause_status_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55, 0.95))
	vbox.add_child(pause_status_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Кнопка: Продолжить
	var resume_btn := _create_menu_button("▶  ПРОДОЛЖИТЬ  [ESC / F1]")
	resume_btn.pressed.connect(resume_game)
	vbox.add_child(resume_btn)

	# Кнопка: Полный экран
	var fs_btn := _create_menu_button("⛶  ПОЛНЫЙ ЭКРАН / ОКНО")
	fs_btn.pressed.connect(toggle_fullscreen)
	vbox.add_child(fs_btn)

	# Кнопка: Сетевое меню / Сервер
	var net_btn := _create_menu_button("🌐  СЕТЕВОЕ МЕНЮ / СЕРВЕР")
	net_btn.pressed.connect(open_network_lobby)
	vbox.add_child(net_btn)

	# Кнопка: Выход
	var quit_btn := _create_menu_button("✕  ВЫХОД ИЗ ИГРЫ", Color(1.0, 0.4, 0.35))
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

	add_child(pause_overlay)

func _create_menu_button(btn_text: String, text_col: Color = Color(1.0, 0.95, 0.85)) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0.0, 42.0)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.4))
	btn.focus_mode = Control.FOCUS_NONE

	var normal_s := StyleBoxFlat.new()
	normal_s.bg_color = Color(0.14, 0.12, 0.10, 0.9)
	normal_s.border_color = Color(0.55, 0.45, 0.25, 0.5)
	normal_s.set_border_width_all(1)
	normal_s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal_s)

	var hover_s := StyleBoxFlat.new()
	hover_s.bg_color = Color(0.24, 0.19, 0.14, 0.95)
	hover_s.border_color = Color(0.95, 0.80, 0.35, 0.9)
	hover_s.set_border_width_all(1)
	hover_s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover_s)

	var press_s := StyleBoxFlat.new()
	press_s.bg_color = Color(0.32, 0.25, 0.18, 1.0)
	press_s.border_color = Color(1.0, 0.88, 0.4, 1.0)
	press_s.set_border_width_all(1)
	press_s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", press_s)

	return btn

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_F1:
			toggle_pause()
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if pause_overlay and pause_overlay.visible:
		resume_game()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	if not pause_overlay:
		return

	var is_singleplayer: bool = (not multiplayer.has_multiplayer_peer()) or (multiplayer.get_peers().is_empty())
	if is_singleplayer:
		get_tree().paused = true
		if pause_status_label:
			pause_status_label.text = "ОДИНОЧНАЯ ИГРА · ВРЕМЯ ОСТАНОВЛЕНО"
			pause_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 0.95))
	else:
		if pause_status_label:
			pause_status_label.text = "СЕТЕВАЯ ИГРА · МИР НЕ ОСТАНАВЛИВАЕТСЯ"
			pause_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3, 0.95))

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_overlay.show()

func resume_game() -> void:
	if pause_overlay:
		pause_overlay.hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func open_network_lobby() -> void:
	resume_game()
	var net_menu = get_tree().current_scene.find_child("NetworkMenu", true, false)
	if net_menu:
		var p = net_menu.get_node_or_null("Panel")
		if p:
			p.show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	
	
	
	
	
