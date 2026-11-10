extends Control

@onready var host_button       : Button   = $Panel/VBox/HostButton
@onready var join_button       : Button   = $Panel/VBox/JoinHBox/JoinButton
@onready var single_button     : Button   = $Panel/VBox/SingleButton
@onready var ip_edit           : LineEdit = $Panel/VBox/JoinHBox/IpEdit
@onready var status_label      : Label    = $Panel/VBox/StatusLabel
@onready var panel             : Control  = $Panel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	single_button.pressed.connect(_on_single_pressed)

	NetworkManager.connection_status_changed.connect(_on_status_changed)

	# Автоматически запускаем одиночную игру на старте, чтобы герой всегда был в мире
	if not multiplayer.has_multiplayer_peer():
		NetworkManager.start_singleplayer()
		panel.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		panel.show()

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_single_pressed() -> void:
	NetworkManager.start_singleplayer()
	_close_menu()

func _on_host_pressed() -> void:
	var err := NetworkManager.start_host()
	if err == OK:
		_close_menu()

func _on_join_pressed() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err := NetworkManager.join_game(ip)
	if err == OK:
		_close_menu()

func _close_menu() -> void:
	panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		NetworkManager.start_singleplayer()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if panel.visible and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F1):
			_close_menu()
			get_viewport().set_input_as_handled()
