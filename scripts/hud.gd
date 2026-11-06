extends Control

@onready var health_bar        : ProgressBar = $BottomBar/HBox/HealthBar
@onready var health_label      : Label       = $BottomBar/HBox/HealthLabel
@onready var ammo_label        : Label       = $BottomBar/HBox/AmmoLabel
@onready var weapon_name_label : Label       = $BottomBar/HBox/WeaponNameLabel
@onready var slot_hint_label   : Label       = $BottomBar/HBox/SlotHintLabel
@onready var crosshair         : Control     = $Crosshair
@onready var hit_flash         : ColorRect   = $HitFlash
@onready var death_screen      : Control     = $DeathScreen

# --- Боевой фидбек: хэдшот, хитмаркер, уведомления и подсказки ---
var hitmarker_ctrl      : Control            = null
var headshot_container  : VBoxContainer      = null
var headshot_icon       : TextureRect        = null
var headshot_label      : Label              = null
var headshot_tween      : Tween              = null
var interact_prompt     : Label              = null
var toast_panel         : PanelContainer     = null
var toast_label         : Label              = null
var toast_tween         : Tween              = null
var headshot_audio      : AudioStreamPlayer  = null
var snd_headshot_stream : AudioStream        = null

# --- Pause Menu ---
var pause_overlay       : Control            = null
var pause_status_label  : Label              = null

# --- Out of Ammo Meme ---
var no_ammo_meme_panel   : PanelContainer     = null
var no_ammo_meme_texture : TextureRect        = null
var _meme_tween          : Tween              = null
var _last_had_ammo       : bool               = true

# --- Предупреждение о сканировании дроном-черепом ---
var drone_scan_panel     : PanelContainer     = null
var drone_scan_label     : Label              = null
var _drone_scan_tween    : Tween              = null

var target_player : Node = null
var _displayed_health: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	hit_flash.modulate.a = 0.0
	death_screen.hide()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.show_percentage = false
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color(0.12, 0.035, 0.035, 0.95)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.2, 0.9, 0.25, 1.0)
	health_bar.add_theme_stylebox_override("background", health_background)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	ammo_label.add_theme_font_size_override("font_size", 17)
	slot_hint_label.add_theme_font_size_override("font_size", 12)
	slot_hint_label.text = "1–5: оружие · Колесо: смена · ЛКМ: огонь · R: перезарядка · C/X: присесть · E: действие"

	# Инициализация боевого UI (хитмаркеры, хэдшоты, уведомления)
	_setup_combat_ui()
	_build_pause_menu()

	await get_tree().process_frame
	_find_and_connect_player()
	_find_and_connect_spawner()

func _setup_combat_ui() -> void:
	# 1. Хитмаркер (4 диагональные засечки вокруг перекрестия)
	hitmarker_ctrl = Control.new()
	hitmarker_ctrl.name = "Hitmarker"
	hitmarker_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker_ctrl.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_ctrl.modulate.a = 0.0
	add_child(hitmarker_ctrl)

	var offsets := [
		Vector2(-12, -12), Vector2(12, -12),
		Vector2(-12, 12),  Vector2(12, 12)
	]
	for off in offsets:
		var tick := ColorRect.new()
		tick.custom_minimum_size = Vector2(4, 4)
		tick.color = Color(1.0, 0.2, 0.2, 0.95)
		tick.position = off - Vector2(2, 2)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hitmarker_ctrl.add_child(tick)

	# 2. Оповещение хэдшота с картинкой-черепом над прицелом
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

	headshot_icon = TextureRect.new()
	headshot_icon.name = "HeadshotIcon"
	headshot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/textures/headshot_icon.png"):
		headshot_icon.texture = load("res://assets/textures/headshot_icon.png")
	headshot_icon.custom_minimum_size = Vector2(74.0, 74.0)
	headshot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	headshot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	headshot_container.add_child(headshot_icon)

	headshot_label = Label.new()
	headshot_label.name = "HeadshotLabel"
	headshot_label.text = "⚡ В ГОЛОВУ! x2.5"
	headshot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headshot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headshot_label.add_theme_font_size_override("font_size", 19)
	headshot_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.18, 1.0))
	headshot_label.add_theme_color_override("font_shadow_color", Color(0.9, 0.1, 0.05, 0.85))
	headshot_label.add_theme_constant_override("shadow_offset_x", 2)
	headshot_label.add_theme_constant_override("shadow_offset_y", 2)
	headshot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headshot_container.add_child(headshot_label)

	headshot_container.modulate.a = 0.0
	add_child(headshot_container)

	# 3. Аудиосопровождение хэдшота (новый звук от пользователя, потише)
	headshot_audio = AudioStreamPlayer.new()
	headshot_audio.name = "HeadshotAudio"
	headshot_audio.volume_db = -8.0
	if ResourceLoader.exists("res://assets/audio/headshot.mp3"):
		snd_headshot_stream = load("res://assets/audio/headshot.mp3")
		headshot_audio.stream = snd_headshot_stream
	elif ResourceLoader.exists("res://assets/audio/headshot.wav"):
		snd_headshot_stream = load("res://assets/audio/headshot.wav")
		headshot_audio.stream = snd_headshot_stream
	add_child(headshot_audio)

	# 4. Подсказка взаимодействия ([E] Взять патроны / Открыть)
	interact_prompt = Label.new()
	interact_prompt.name = "InteractPrompt"
	interact_prompt.text = ""
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", 16)
	interact_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65, 1.0))
	interact_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	interact_prompt.add_theme_constant_override("shadow_offset_x", 1)
	interact_prompt.add_theme_constant_override("shadow_offset_y", 1)
	interact_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER)
	interact_prompt.offset_left = -200.0
	interact_prompt.offset_right = 200.0
	interact_prompt.offset_top = 36.0
	interact_prompt.offset_bottom = 66.0
	interact_prompt.visible = false
	add_child(interact_prompt)

	# 5. Стильный всплывающий Toast (для подобранного лута)
	toast_panel = PanelContainer.new()
	toast_panel.name = "ToastPanel"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -240.0
	toast_panel.offset_right = 240.0
	toast_panel.offset_top = -140.0
	toast_panel.offset_bottom = -96.0
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.07, 0.06, 0.82)
	toast_style.border_color = Color(0.85, 0.65, 0.25, 0.9)
	toast_style.border_width_left = 1
	toast_style.border_width_right = 1
	toast_style.border_width_top = 1
	toast_style.border_width_bottom = 1
	toast_style.corner_radius_bottom_left = 5
	toast_style.corner_radius_bottom_right = 5
	toast_style.corner_radius_top_left = 5
	toast_style.corner_radius_top_right = 5
	toast_style.content_margin_left = 16.0
	toast_style.content_margin_right = 16.0
	toast_style.content_margin_top = 6.0
	toast_style.content_margin_bottom = 6.0
	toast_panel.add_theme_stylebox_override("panel", toast_style)

	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0.0
	add_child(toast_panel)

	# 6. Мем "Так много пидрил и так мало патронов" при 0 патронах
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

	# 7. Предупреждение о сканировании дроном-черепом
	drone_scan_panel = PanelContainer.new()
	drone_scan_panel.name = "DroneScanPanel"
	drone_scan_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	drone_scan_panel.offset_left = -225.0
	drone_scan_panel.offset_top = 52.0
	drone_scan_panel.offset_right = 225.0
	drone_scan_panel.offset_bottom = 86.0
	drone_scan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ds_style := StyleBoxFlat.new()
	ds_style.bg_color = Color(0.18, 0.02, 0.02, 0.88)
	ds_style.border_color = Color(1.0, 0.22, 0.18, 0.95)
	ds_style.set_border_width_all(2)
	ds_style.set_corner_radius_all(6)
	ds_style.content_margin_left = 12.0
	ds_style.content_margin_right = 12.0
	ds_style.content_margin_top = 4.0
	ds_style.content_margin_bottom = 4.0
	drone_scan_panel.add_theme_stylebox_override("panel", ds_style)

	drone_scan_label = Label.new()
	drone_scan_label.name = "DroneScanLabel"
	drone_scan_label.text = "⚠️ ДРОН-ЧЕРЕП СКАНИРУЕТ! ВОЛНА УСКОРЕНА x2"
	drone_scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drone_scan_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drone_scan_label.add_theme_font_size_override("font_size", 13)
	drone_scan_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	drone_scan_panel.add_child(drone_scan_label)

	drone_scan_panel.hide()
	add_child(drone_scan_panel)

func set_skull_drone_scanning(is_scanning: bool) -> void:
	if not drone_scan_panel:
		return
	if is_scanning:
		drone_scan_panel.show()
		if not _drone_scan_tween or not _drone_scan_tween.is_valid():
			_drone_scan_tween = create_tween().set_loops()
			_drone_scan_tween.tween_property(drone_scan_panel, "modulate:a", 0.45, 0.35)
			_drone_scan_tween.tween_property(drone_scan_panel, "modulate:a", 1.0, 0.35)
	else:
		if _drone_scan_tween and _drone_scan_tween.is_valid():
			_drone_scan_tween.kill()
		drone_scan_panel.modulate.a = 1.0
		drone_scan_panel.hide()

# =========================================================================
# БОЕВОЙ ФИДБЕК: ХЭДШОТ, ХИТМАРКЕР И ОПОВЕЩЕНИЯ
# =========================================================================
func show_headshot_feedback() -> void:
	# 1. Звук пробития шлема / критического попадания
	if headshot_audio:
		headshot_audio.pitch_scale = randf_range(0.96, 1.05)
		headshot_audio.play()

	# 2. Золотисто-красный хитмаркер с пульсацией
	if hitmarker_ctrl:
		hitmarker_ctrl.modulate = Color(1.5, 1.2, 0.2, 1.0)
		hitmarker_ctrl.scale = Vector2(1.4, 1.4)
		var h_tween := create_tween().set_parallel(true)
		h_tween.tween_property(hitmarker_ctrl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		h_tween.tween_property(hitmarker_ctrl, "modulate:a", 0.0, 0.35).set_delay(0.08)

	# 3. Анимированный баннер с черепом "⚡ В ГОЛОВУ! x2.5"
	if headshot_container:
		if headshot_tween and headshot_tween.is_valid():
			headshot_tween.kill()
		headshot_container.modulate.a = 1.0
		headshot_container.scale = Vector2(1.4, 1.4)
		headshot_tween = create_tween().set_parallel(true)
		headshot_tween.tween_property(headshot_container, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		headshot_tween.tween_property(headshot_container, "modulate:a", 0.0, 0.25).set_delay(0.50)

func show_hit_feedback() -> void:
	# Обычное попадание по телу: короткая белая засечка хитмаркера
	if hitmarker_ctrl:
		hitmarker_ctrl.modulate = Color(1.0, 1.0, 1.0, 0.85)
		hitmarker_ctrl.scale = Vector2.ONE
		var h_tween := create_tween()
		h_tween.tween_property(hitmarker_ctrl, "modulate:a", 0.0, 0.18)

func show_interaction_prompt(prompt_text: String) -> void:
	if interact_prompt:
		interact_prompt.text = prompt_text
		interact_prompt.visible = not prompt_text.is_empty()

func hide_interaction_prompt() -> void:
	if interact_prompt:
		interact_prompt.visible = false

func show_toast(msg: String, col: Color = Color(1.0, 0.92, 0.45, 1.0)) -> void:
	if toast_label and toast_panel:
		if toast_tween and toast_tween.is_valid():
			toast_tween.kill()
		toast_label.text = msg
		toast_label.add_theme_color_override("font_color", col)
		toast_panel.modulate.a = 1.0
		toast_panel.offset_bottom = -96.0

		toast_tween = create_tween()
		toast_tween.tween_interval(2.2)
		toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)

# =========================================================================
# ПОДКЛЮЧЕНИЕ СПАВНЕРА (БЕЗ ОТОБРАЖЕНИЯ НАВЯЗЧИВОЙ ТАБЛИЧКИ СЛОЖНОСТИ)
# =========================================================================
func _find_and_connect_spawner() -> void:
	var spawner: Node = get_tree().current_scene.find_child("WaveSpawner", true, false)
	if spawner:
		connect_spawner(spawner)

func connect_spawner(spawner: Node) -> void:
	# Сигналы подключаются для поддержания логики сетевой синхронизации,
	# но громоздкие таблички сложности и таймеров больше не выводятся на экран
	pass

func _find_and_connect_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node and p.has_method("is_local") and p.is_local():
			connect_player(p)
			return
	if players.size() > 0:
		connect_player(players[0])

func connect_player(p: Node) -> void:
	target_player = p
	if not p.is_connected("health_changed", _on_health_changed):
		p.health_changed.connect(_on_health_changed)
	if not p.is_connected("ammo_changed", _on_ammo_changed):
		p.ammo_changed.connect(_on_ammo_changed)
	if not p.is_connected("player_died", _on_player_died):
		p.player_died.connect(_on_player_died)
	if p.has_signal("weapon_changed") and not p.is_connected("weapon_changed", _on_weapon_changed):
		p.weapon_changed.connect(_on_weapon_changed)
	if p.has_method("get_combat_status"):
		var status: Dictionary = p.call("get_combat_status")
		if status.has("health"):
			_on_health_changed(int(status.health))
		if status.has("weapon_name"):
			_on_weapon_changed(str(status.weapon_name), null, int(status.magazine), int(status.reserve))

func _on_health_changed(value: int) -> void:
	var clamped_health := clampi(value, 0, 100)
	health_bar.value = clamped_health
	health_label.text = "HP: %d%%" % clamped_health
	var fill_style := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = Color(0.2, 0.9, 0.25, 1.0).lerp(Color(0.95, 0.12, 0.08, 1.0), 1.0 - float(clamped_health) / 100.0)
	if clamped_health <= 0:
		death_screen.show()
	else:
		death_screen.hide()
	if _displayed_health >= 0 and clamped_health < _displayed_health:
		_flash_damage()
	_displayed_health = clamped_health

func _on_ammo_changed(current: int, total: int) -> void:
	ammo_label.text = "В МАГАЗИНЕ: %d    В ЗАПАСЕ: %d" % [current, total]
	if (current + total) <= 0:
		if _last_had_ammo:
			_last_had_ammo = false
			show_out_of_ammo_meme()
	else:
		if not _last_had_ammo:
			_last_had_ammo = true
			hide_out_of_ammo_meme()

func _on_weapon_changed(w_name: String, _tex: Texture2D, cur_ammo: int, tot_ammo: int) -> void:
	var display_names := {
		"Pistol": "ПИСТОЛЕТ",
		"Shotgun": "ДРОБОВИК",
		"AssaultRifle": "АВТОМАТ",
		"SniperRifle": "СНАЙПЕРСКАЯ ВИНТОВКА",
		"RocketLauncher": "РАКЕТНИЦА",
	}
	weapon_name_label.text = display_names.get(w_name, w_name)
	ammo_label.text = "В МАГАЗИНЕ: %d    В ЗАПАСЕ: %d" % [cur_ammo, tot_ammo]
	if (cur_ammo + tot_ammo) <= 0:
		if _last_had_ammo:
			_last_had_ammo = false
			show_out_of_ammo_meme()
	else:
		if not _last_had_ammo:
			_last_had_ammo = true
			hide_out_of_ammo_meme()

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

func _on_player_died() -> void:
	death_screen.show()

func _flash_damage() -> void:
	hit_flash.modulate.a = 0.45
	var tween: Tween = create_tween()
	tween.tween_property(hit_flash, "modulate:a", 0.0, 0.4)

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if is_instance_valid(target_player):
		var current_health: Variant = target_player.get("health")
		if current_health != null and int(current_health) != _displayed_health:
			_on_health_changed(int(current_health))

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
