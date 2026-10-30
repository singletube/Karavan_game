extends Control

class_name CampDialogueUI

# =========================================================================
# ИНТЕРАКТИВНЫЙ ДИАЛОГОВЫЙ ИНТЕРФЕЙС ЖИТЕЛЕЙ ЛАГЕРЯ
# =========================================================================
# Шаблоны для:
# 1. Торговли: покупка патронов, аптечек, пополнение каравана
# 2. Прокачки (Мастерская): увеличение прочности каравана, броня осла, скорость ремонта
# 3. Квестов (Командир): получение заданий, разведка, награды

signal ui_closed

var current_npc_type: int = 0
var current_player: Node = null

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var content_container: VBoxContainer
var close_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()

func open_for_npc(npc_type: int, npc_name: String, player: Node) -> void:
	current_npc_type = npc_type
	current_player = player

	# Освобождаем курсор мыши для взаимодействия с UI
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	title_label.text = npc_name.to_upper()
	_populate_content(npc_type)
	show()

func close_ui() -> void:
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui_closed.emit()

func _populate_content(type: int) -> void:
	for c in content_container.get_children():
		c.queue_free()

	match type:
		0: # TRADER
			subtitle_label.text = "«Путник! В пустошах без патронов ты долго не протянешь. Выбирай припасы!»"
			_add_trader_items()
		1: # MECHANIC
			subtitle_label.text = "«Моё почтение, караванщик! Могу укрепить повозку или подковать твоего осла!»"
			_add_mechanic_items()
		2: # COMMANDER
			subtitle_label.text = "«Мы держим этот рубеж от орд нежити. Нам нужны опытные стрелки!»"
			_add_commander_quests()

func _add_trader_items() -> void:
	_create_action_card(
		"📦 Ящик армейских патронов",
		"Полное пополнение боекомплекта для всех видов стрелкового оружия.",
		"ПОПОЛНИТЬ БОЕЗАПАС",
		func():
			if current_player and current_player.has_method("notify_hud"):
				# Пополняем патроны через WeaponManager
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
		"🩹 Полевой медицинский набор",
		"Мгновенно восстанавливает здоровье стрелка до 100 HP.",
		"ИСПОЛЬЗОВАТЬ АПТЕЧКУ",
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
		"🌾 Запас провизии и вода для осла",
		"Успокаивает животное и восстанавливает +100 HP каравана.",
		"ПОКОРМИТЬ ОСЛА (+100 HP)",
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
		"🛡️ Бронированные борта повозки [УРОВЕНЬ 1]",
		"Укрепляет древесину повозки стальными пластинами. Ремонтирует +200 HP каравана.",
		"УСТАНОВИТЬ БРОНЕЛИСТЫ",
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
		"⚙️ Смазка осей и кованые подковы",
		"Облегчает ход повозки по барханам и песчаным завалам.",
		"ОБСЛУЖИТЬ КОЛЁСА И ПОДДЕЛАТЬ ПОД Turbо",
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ХОДОВАЯ ЧАСТЬ ОБСЛУЖЕНА! ОСЁЛ ГОТОВ К ДОРОГЕ", Color(1.0, 0.88, 0.35))
			close_ui()
	)

	_create_action_card(
		"🪚 Заточка зубьев бензопилы и стволов",
		"Качественная калибровка оружия и смазка механизмов.",
		"ОБСЛУЖИТЬ ОРУЖИЕ",
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ОРУЖИЕ ПРИВЕДЕНО К ИДЕАЛЬНОМУ БОЮ!", Color(1.0, 0.65, 0.2))
			close_ui()
	)

func _add_commander_quests() -> void:
	_create_action_card(
		"📜 КВЕСТ: «Зачистка внешнего периметра»",
		"Уничтожьте 15 киборгов-зомби в следующей волне за воротами аванпоста.\nНаграда: редкие боеприпасы и броня каравана.",
		"ВЗЯТЬ ЗАДАНИЕ",
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("КВЕСТ ПРИНЯТ: Зачистить следующий рубеж!", Color(1.0, 0.85, 0.25))
			close_ui()
	)

	_create_action_card(
		"🗺️ КВЕСТ: «Разведка заброшенной заправки»",
		"Отыщите ближайший схрон топлива вдоль дороги каравана.\nНаграда: ящик взрывчатки и сигнальные ракеты.",
		"ВЗЯТЬ РАЗВЕДКУ",
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("КВЕСТ ПРИНЯТ: Найти схрон с топливом!", Color(0.35, 1.0, 0.55))
			close_ui()
	)

	_create_action_card(
		"🚩 Получить благословение гарнизона",
		"Гарнизон передаёт каравану сигнальный маяк для вызова поддержки.",
		"ПРИНЯТЬ ПОМОЩЬ",
		func():
			if current_player and current_player.has_method("notify_hud"):
				current_player.notify_hud("ГАРНИЗОН ПОДДЕРЖИВАЕТ ВАШ КАРАВАН!", Color(0.9, 0.9, 1.0))
			close_ui()
	)

func _create_action_card(item_title: String, item_desc: String, btn_text: String, action: Callable) -> void:
	var card := PanelContainer.new()
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	c_style.border_color = Color(0.55, 0.45, 0.25, 0.7)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)
	c_style.content_margin_left = 14
	c_style.content_margin_right = 14
	c_style.content_margin_top = 10
	c_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", c_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var vbox_text := VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_text)

	var lbl_name := Label.new()
	lbl_name.text = item_title
	lbl_name.add_theme_font_size_override("font_size", 16)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox_text.add_child(lbl_name)

	var lbl_desc := Label.new()
	lbl_desc.text = item_desc
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_text.add_child(lbl_desc)

	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(170, 42)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.24, 0.18, 0.10, 0.95)
	btn_style.border_color = Color(0.85, 0.70, 0.30, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(action)
	hbox.add_child(btn)

	content_container.add_child(card)

func _build_ui() -> void:
	# Темный фоновый оверлей
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	add_child(bg)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_top = -240.0
	panel.offset_right = 340.0
	panel.offset_bottom = 240.0
	panel.custom_minimum_size = Vector2(680, 480)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.035, 0.03, 0.96)
	p_style.border_color = Color(0.85, 0.68, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 22
	p_style.content_margin_right = 22
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", p_style)
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# Заголовок
	var top_hbox := HBoxContainer.new()
	main_vbox.add_child(top_hbox)

	title_label = Label.new()
	title_label.text = "ЛАГЕРЬ ВЫЖИВШИХ"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = " [X] ЗАКРЫТЬ "
	close_btn.pressed.connect(close_ui)
	top_hbox.add_child(close_btn)

	# Подзаголовок / Реплика
	subtitle_label = Label.new()
	subtitle_label.text = "«Добро пожаловать в аванпост!»"
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(subtitle_label)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Скроллируемая область контента
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 10)
	scroll.add_child(content_container)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
