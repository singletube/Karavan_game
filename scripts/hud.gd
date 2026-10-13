extends Control

@onready var health_bar        : ProgressBar = $BottomBar/HBox/HealthBar
@onready var health_label      : Label       = $BottomBar/HBox/HealthLabel
@onready var ammo_label        : Label       = $BottomBar/HBox/AmmoLabel
@onready var weapon_name_label : Label       = $BottomBar/HBox/WeaponNameLabel
@onready var slot_hint_label   : Label       = $BottomBar/HBox/SlotHintLabel
@onready var crosshair         : Control     = $Crosshair
@onready var hit_flash         : ColorRect   = $HitFlash
@onready var death_screen      : Control     = $DeathScreen

# --- Элементы отображения волн ---
var wave_panel           : PanelContainer = null
var wave_title_label     : Label          = null
var wave_subtitle_label  : Label          = null

var target_player : Node = null
var _displayed_health: int = -1

func _ready() -> void:
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
	slot_hint_label.text = "1–5: оружие · Колесо: смена · ЛКМ: огонь · R: перезарядка · C/X: присесть"
	_setup_wave_ui()

	await get_tree().process_frame
	_find_and_connect_player()
	_find_and_connect_spawner()

func _setup_wave_ui() -> void:
	var existing: Node = get_node_or_null("WavePanel")
	if existing and existing is PanelContainer:
		wave_panel = existing as PanelContainer
		wave_title_label = wave_panel.get_node_or_null("VBox/WaveTitleLabel") as Label
		wave_subtitle_label = wave_panel.get_node_or_null("VBox/WaveSubtitleLabel") as Label
		return

	# Создание стильной верхней панели информации о волнах
	wave_panel = PanelContainer.new()
	wave_panel.name = "WavePanel"
	wave_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_panel.offset_left = -220.0
	wave_panel.offset_right = 220.0
	wave_panel.offset_top = 18.0
	wave_panel.offset_bottom = 85.0
	wave_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.70)
	style.border_color = Color(0.65, 0.50, 0.25, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	wave_panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_panel.add_child(vbox)

	wave_title_label = Label.new()
	wave_title_label.name = "WaveTitleLabel"
	wave_title_label.text = "ПОДГОТОВКА"
	wave_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title_label.add_theme_font_size_override("font_size", 20)
	wave_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	vbox.add_child(wave_title_label)

	wave_subtitle_label = Label.new()
	wave_subtitle_label.name = "WaveSubtitleLabel"
	wave_subtitle_label.text = "Ожидание волны..."
	wave_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_subtitle_label.add_theme_font_size_override("font_size", 15)
	wave_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(wave_subtitle_label)

	add_child(wave_panel)

func _find_and_connect_spawner() -> void:
	var spawner: Node = get_tree().current_scene.find_child("WaveSpawner", true, false)
	if spawner:
		connect_spawner(spawner)

func connect_spawner(spawner: Node) -> void:
	if not spawner.is_connected("wave_started", _on_wave_started):
		spawner.wave_started.connect(_on_wave_started)
	if not spawner.is_connected("wave_completed", _on_wave_completed):
		spawner.wave_completed.connect(_on_wave_completed)
	if not spawner.is_connected("enemies_remaining", _on_enemies_remaining):
		spawner.enemies_remaining.connect(_on_enemies_remaining)
	if not spawner.is_connected("wave_countdown", _on_wave_countdown):
		spawner.wave_countdown.connect(_on_wave_countdown)

func _on_wave_started(wave_num: int, wave_name: String) -> void:
	if wave_title_label:
		wave_title_label.text = "ВОЛНА %d: %s" % [wave_num, wave_name.to_upper()]
		wave_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	if wave_subtitle_label:
		wave_subtitle_label.text = "Враги атакуют караван!"
		wave_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))

func _on_wave_completed(wave_num: int) -> void:
	if wave_title_label:
		wave_title_label.text = "ВОЛНА %d ОТБИТА!" % wave_num
		wave_title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	if wave_subtitle_label:
		wave_subtitle_label.text = "Передышка..."
		wave_subtitle_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0))

func _on_enemies_remaining(count: int) -> void:
	if wave_subtitle_label:
		if count > 0:
			wave_subtitle_label.text = "Осталось врагов: %d" % count
			wave_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
		else:
			wave_subtitle_label.text = "Все враги уничтожены!"
			wave_subtitle_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))

func _on_wave_countdown(seconds: int) -> void:
	if wave_title_label and not wave_title_label.text.begins_with("ВОЛНА"):
		wave_title_label.text = "ПОДГОТОВКА"
		wave_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	if wave_subtitle_label:
		wave_subtitle_label.text = "Следующая волна через: %d сек" % seconds
		wave_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0))

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
	# Signals can be emitted before the HUD finds a newly spawned player. Pull
	# the current state now so the initial weapon and ammo are never stale.
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

func _on_player_died() -> void:
	death_screen.show()

func _flash_damage() -> void:
	hit_flash.modulate.a = 0.45
	var tween: Tween = create_tween()
	tween.tween_property(hit_flash, "modulate:a", 0.0, 0.4)

func _process(_delta: float) -> void:
	# Keep health visible even if the player was spawned before signal hookup or
	# a multiplayer health signal arrived before the HUD connected.
	if is_instance_valid(target_player):
		var current_health: Variant = target_player.get("health")
		if current_health != null and int(current_health) != _displayed_health:
			_on_health_changed(int(current_health))
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
