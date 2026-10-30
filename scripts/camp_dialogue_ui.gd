extends Control

class_name CampDialogueUI

# =========================================================================
# ИНТЕРАКТИВНЫЙ ДИАЛОГОВЫЙ ИНТЕРФЕЙС ЖИТЕЛЕЙ ЛАГЕРЯ (DEAD CENTER UI)
# =========================================================================
# Точно центрированное диалоговое окно в стиле тактического постапокалипсиса:
# 1. Торговец Фарид: боеприпасы, аптечки, провизия для осла
# 2. Оружейник Гассан: укрепление бортов, смазка ходовой, калибровка оружия
# 3. Капитан Башир: тактические задания гарнизона, разведка, награды

signal ui_closed

var current_npc_type: int = 0
var current_player: Node = null

var bg_overlay: ColorRect
var panel: PanelContainer
var role_badge: Label
var title_label: Label
var subtitle_label: Label
var content_container: VBoxContainer
var close_btn: Button

func _ready() -> void:
	# Растягиваем корневой контрол на весь экран
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()
	hide()

func open_for_npc(npc_type: int, npc_name: String, player: Node) -> void:
	current_npc_type = npc_type
	current_player = player

	if panel == null:
		_build_ui()

	# Включаем свободный курсор мыши
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Обновляем центрирование окна под актуальный размер вьюпорта
	_recenter_panel()

	title_label.text = npc_name.to_upper()
	_populate_content(npc_type)
	show()

func _recenter_panel() -> void:
	if not panel or not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if vp_size.x > 200.0 and vp_size.y > 200.0:
		var panel_w: float = mini(740.0, vp_size.x - 40.0)
		var panel_h: float = mini(540.0, vp_size.y - 40.0)
		panel.custom_minimum_size = Vector2(panel_w, panel_h)
		panel.offset_left = -panel_w * 0.5
		panel.offset_top = -panel_h * 0.5
		panel.offset_right = panel_w * 0.5
		panel.offset_bottom = panel_h * 0.5

func close_ui() -> void:
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui_closed.emit()

func _populate_content(type: int) -> void:
	for c in content_container.get_children():
		c.queue_free()

	match type:
		0: # TRADER
			role_badge.text = "[ ТОРГОВЕЦ ПУСТОШЕЙ ]"
			role_badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
			subtitle_label.text = "«Приветствую, путник! В пустыне патроны ценнее золота. Выбирай проверенное снаряжение!»"
			_add_trader_items()
		1: # MECHANIC
			role_badge.text = "[ МАСТЕР-ОРУЖЕЙНИК ]"
			role_badge.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			subtitle_label.text = "«Моё почтение! Могу навесить броню на повозку, подковать осла или пристрелять твои стволы!»"
			_add_mechanic_items()
		2: # COMMANDER
			role_badge.text = "[ КОМАНДИР ГАРНИЗОНА ]"
			role_badge.add_theme_color_override("font_color", Color(0.95, 0.40, 0.30))
			subtitle_label.text = "«Мы сдерживаем орды кибер-нежити на этом рубеже. Нам нужны хладнокровные стрелки!»"
			_add_commander_quests()

func _add_trader_items() -> void:
	_create_action_card(
		"📦 Ящик армейских патронов",
		"Полное пополнение боекомплекта для всех видов оружия (автомат, дробовик, снайперка, револьвер).",
		"ПОПОЛНИТЬ БОЕЗАПАС",
		Color(0.25, 0.85, 0.45),
		func():
			if current_player and current_player.has_method("notify_hud"):
				var wm = current_player.get_node_or_null("WeaponManager")
				if wm and wm.get("ammo_manager"):
					var am = wm.ammo_manager
					if am.get("ammo_dict") and am.get("max_nb_per_ammo_dict"):
						for a_type in am.max_nb_per_ammo_dict:
							am.ammo_dict[a_type] = am.max_nb_per_ammo_dict[a_type]
				current_player.notify_hud("БОЕПРИПАСЫ ПОЛНОСТЬЮ ПОПОЛНЕНЫ!", Color(0.3, 1.0, 0.45))
			close_ui()
	)

	_create_action_card(
		"🩹 Полевой медицинский стимулятор",
		"Мгновенно восстанавливает здоровье стрелка до максимума (100 HP) и останавливает кровотечение.",
		"ИСПОЛЬЗОВАТЬ АПТЕЧКУ",
		Color(0.9, 0.35, 0.35),
		func():
			if current_player:
				current_player.health = 100
				if current_player.has_signal("health_changed"):
					current_player.health_changed.emit(100)
				if current_player.has_method("notify_hud"):
					current_player.notify_hud("ЗДОРОВЬЕ ВОССТАНОВЛЕНО ДО 100 HP!", Color(0.3, 1.0, 0.45))
			close_ui()
	)

	_create_action_card(
		"🌾 Запас чистой воды и фиников для осла",
		"Освежает животное, снижает усталость и восстанавливает +100 HP каравана.",
		"ПОКОРМИТЬ ОСЛА (+100 HP)",
		Color(1.0, 0.85, 0.35),
		func():
			var caravan = get_tree().get_first_node_in_group("caravan")
			if caravan and is_instance_valid(caravan):
				var cur: int = int(caravan.get("health"))
				var max_hp: int = int(caravan.get("MAX_HEALTH"))
				caravan.health = mini(max_hp, cur + 100)
				if caravan.has_signal("health_changed"):
					caravan.health_changed.emit(caravan.health, max_hp)
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ОСЁЛ НАКОРМЛЕН! +100 HP КАРАВАНА", Color(1.0, 0.85, 0.35))
			close_ui()
	)

func _add_mechanic_items() -> void:
	_create_action_card(
		"🛡️ Навесные бронелисты на борта повозки",
		"Укрепляет деревянную повозку стальными пластинами. Мгновенно ремонтирует +200 HP каравана.",
		"УСТАНОВИТЬ БРОНЮ (+200 HP)",
		Color(0.3, 0.8, 1.0),
		func():
			var caravan = get_tree().get_first_node_in_group("caravan")
			if caravan and is_instance_valid(caravan):
				var cur: int = int(caravan.get("health"))
				var max_hp: int = int(caravan.get("MAX_HEALTH"))
				caravan.health = mini(max_hp, cur + 200)
				if caravan.has_signal("health_changed"):
					caravan.health_changed.emit(caravan.health, max_hp)
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ПОВОЗКА УКРЕПЛЕНА! (+200 HP КАРАВАНА)", Color(0.2, 0.9, 1.0))
			close_ui()
	)

	_create_action_card(
		"⚙️ Смазка ступиц и кованые подковы осла",
		"Облегчает движение по сыпучим песчаным барханам и каменистым завалам.",
		"ОБСЛУЖИТЬ КОЛЁСА",
		Color(1.0, 0.75, 0.25),
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ХОДОВАЯ ЧАСТЬ ОБСЛУЖЕНА! ОСЁЛ ГОТОВ К ДОРОГЕ", Color(1.0, 0.88, 0.35))
			close_ui()
	)

	_create_action_card(
		"🪚 Заточка зубьев бензопилы и стволов",
		"Профессиональная чистка затворов, смазка механизмов и заточка режущих кромок.",
		"ОБСЛУЖИТЬ ОРУЖИЕ",
		Color(0.95, 0.60, 0.20),
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ОРУЖИЕ ПРИВЕДЕНО К ИДЕАЛЬНОМУ БОЮ!", Color(1.0, 0.65, 0.2))
			close_ui()
	)

func _add_commander_quests() -> void:
	_create_action_card(
		"📜 КВЕСТ: «Зачистка внешнего периметра»",
		"Уничтожьте 15 кибер-зомби в следующей волне за северными воротами лагеря.\nНаграда: редкие боеприпасы и усилители каравана.",
		"ВЗЯТЬ ЗАДАНИЕ",
		Color(0.95, 0.75, 0.30),
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("КВЕСТ ПРИНЯТ: Уничтожить киборгов на рубеже!", Color(1.0, 0.85, 0.25))
			close_ui()
	)

	_create_action_card(
		"🗺️ КВЕСТ: «Схрон топлива в заброшенном бункере»",
		"Разведайте координаты тайника с дизельным топливом вдоль пути каравана.\nНаграда: ящик связок динамита.",
		"ВЗЯТЬ РАЗВЕДКУ",
		Color(0.40, 0.90, 0.60),
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("КВЕСТ ПРИНЯТ: Найти схрон с топливом!", Color(0.35, 1.0, 0.55))
			close_ui()
	)

	_create_action_card(
		"🚩 Сигнальный маяк поддержки гарнизона",
		"Гарнизон передаёт каравану аварийную сигнальную ракетницу для вызова заградительного огня.",
		"ПРИНЯТЬ ПОДДЕРЖКУ",
		Color(0.85, 0.85, 1.0),
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ГАРНИЗОН ПОДДЕРЖИВАЕТ ВАШ КАРАВАН!", Color(0.9, 0.9, 1.0))
			close_ui()
	)

func _create_action_card(item_title: String, item_desc: String, btn_text: String, accent_col: Color, action: Callable) -> void:
	var card := PanelContainer.new()
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.06, 0.05, 0.045, 0.92)
	c_style.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.35)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(8)
	c_style.content_margin_left = 16
	c_style.content_margin_right = 16
	c_style.content_margin_top = 12
	c_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", c_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	card.add_child(hbox)

	var vbox_text := VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_text.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox_text)

	var lbl_name := Label.new()
	lbl_name.text = item_title
	lbl_name.add_theme_font_size_override("font_size", 15)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.94, 0.85))
	vbox_text.add_child(lbl_name)

	var lbl_desc := Label.new()
	lbl_desc.text = item_desc
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.add_theme_color_override("font_color", Color(0.72, 0.70, 0.65))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_text.add_child(lbl_desc)

	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(190, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.16, 0.13, 0.09, 0.95)
	btn_normal.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.75)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(6)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.24, 0.19, 0.12, 1.0)
	btn_hover.border_color = accent_col
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(action)
	hbox.add_child(btn)

	content_container.add_child(card)

func _build_ui() -> void:
	# 1. Затемняющий фон-оверлей на весь экран
	bg_overlay = ColorRect.new()
	bg_overlay.name = "BackgroundOverlay"
	bg_overlay.anchor_left = 0.0
	bg_overlay.anchor_top = 0.0
	bg_overlay.anchor_right = 1.0
	bg_overlay.anchor_bottom = 1.0
	bg_overlay.offset_left = 0.0
	bg_overlay.offset_top = 0.0
	bg_overlay.offset_right = 0.0
	bg_overlay.offset_bottom = 0.0
	bg_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg_overlay.color = Color(0.02, 0.02, 0.02, 0.78)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_overlay)

	# 2. Главное центрированное окно
	panel = PanelContainer.new()
	panel.name = "CenterDialoguePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370.0
	panel.offset_top = -270.0
	panel.offset_right = 370.0
	panel.offset_bottom = 270.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(740, 540)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.035, 0.03, 0.96)
	p_style.border_color = Color(0.85, 0.70, 0.35, 0.75)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(12)
	p_style.content_margin_left = 24
	p_style.content_margin_right = 24
	p_style.content_margin_top = 20
	p_style.content_margin_bottom = 20
	p_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	p_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", p_style)
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# Шапка: Бэйдж роли + Имя + Кнопка закрытия
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	main_vbox.add_child(top_bar)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	top_bar.add_child(title_vbox)

	role_badge = Label.new()
	role_badge.text = "[ АВАНПОСТ ВЫЖИВШИХ ]"
	role_badge.add_theme_font_size_override("font_size", 11)
	role_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_vbox.add_child(role_badge)

	title_label = Label.new()
	title_label.text = "ТОРГОВЕЦ ФАРИД"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
	title_vbox.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = " ✕ ЗАКРЫТЬ [ESC] "
	close_btn.custom_minimum_size = Vector2(130, 36)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.18, 0.06, 0.06, 0.9)
	close_style.border_color = Color(0.85, 0.3, 0.3, 0.8)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(close_ui)
	top_bar.add_child(close_btn)

	# Реплика жителя лагеря
	subtitle_label = Label.new()
	subtitle_label.text = "«Добро пожаловать в аванпост!»"
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(subtitle_label)

	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.85, 0.70, 0.35, 0.3)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)

	# Скроллируемый список доступных услуг / товаров
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 10)
	scroll.add_child(content_container)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
