extends Node

const DEFAULT_PORT := 7000
const MAX_PLAYERS  := 16

const PLAYER_SCENE = preload("res://PlayerCharacter/player_character_scene.tscn")

@onready var world: Node3D = get_tree().current_scene
var players_container: Node3D

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_status_changed(status: String)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _get_players_container() -> Node3D:
	if not players_container or not is_instance_valid(players_container):
		var found: Node = get_tree().current_scene.get_node_or_null("Players")
		if found and found is Node3D:
			players_container = found as Node3D
		else:
			players_container = Node3D.new()
			players_container.name = "Players"
			get_tree().current_scene.add_child(players_container)
	return players_container

# === ОДИНОЧНАЯ ИГРА ===
func start_singleplayer() -> void:
	emit_signal("connection_status_changed", "Режим: Одиночная игра")
	_spawn_player(1)

# === ХОСТ (СЕРВЕР) ===
func start_host(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		emit_signal("connection_status_changed", "Ошибка создания сервера: %d" % err)
		return err

	multiplayer.multiplayer_peer = peer
	emit_signal("connection_status_changed", "Сервер запущен (порт %d). Ожидание игроков..." % port)

	# Спавним хоста (ID = 1)
	_spawn_player(1)
	return OK

# === КЛИЕНТ (ПОДКЛЮЧЕНИЕ) ===
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		emit_signal("connection_status_changed", "Ошибка подключения: %d" % err)
		return err

	multiplayer.multiplayer_peer = peer
	emit_signal("connection_status_changed", "Подключение к %s:%d..." % [address, port])
	return OK

# === СИГНАЛЫ ENet ===
func _on_peer_connected(id: int) -> void:
	emit_signal("player_connected", id)
	emit_signal("connection_status_changed", "Игрок #%d подключился!" % id)

	# Если мы хост, спавним нового игрока у себя и синхронизируем список существующих
	if multiplayer.is_server():
		_spawn_player(id)

		# Сообщаем новому клиенту обо всех уже существующих игроках
		var existing_ids: Array = []
		var container := _get_players_container()
		for child in container.get_children():
			if child.name.is_valid_int():
				existing_ids.append(child.name.to_int())

		rpc_id(id, "sync_all_players", existing_ids)
		# Всем остальным клиентам сообщаем о новом игроке
		rpc("spawn_remote_player", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("player_disconnected", id)
	emit_signal("connection_status_changed", "Игрок #%d отключился." % id)
	_remove_player(id)
	if multiplayer.is_server():
		rpc("remove_remote_player", id)

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	emit_signal("connection_status_changed", "Успешно подключено! Ваш ID: %d" % my_id)
	_spawn_player(my_id)

func _on_connection_failed() -> void:
	emit_signal("connection_status_changed", "Не удалось подключиться к серверу.")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	emit_signal("connection_status_changed", "Сервер закрыл соединение.")
	multiplayer.multiplayer_peer = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# === СПАВН И УДАЛЕНИЕ ===
func _spawn_player(id: int) -> Node:
	var container: Node3D = _get_players_container()
	var node_name: String = str(id)
	if container.has_node(node_name):
		return container.get_node(node_name)

	var p: Node = PLAYER_SCENE.instantiate()
	p.name = node_name
	container.add_child(p)

	if p is Node3D:
		(p as Node3D).global_position = Vector3(randf_range(-6.0, 6.0), 1.0, randf_range(-6.0, 6.0))

	# Обновляем HUD для локального игрока
	var hud: Node = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("_find_and_connect_player"):
		hud._find_and_connect_player()

	return p

func _remove_player(id: int) -> void:
	var container: Node3D = _get_players_container()
	var node_name: String = str(id)
	if container.has_node(node_name):
		container.get_node(node_name).queue_free()

# === RPC СИНХРОНИЗАЦИЯ ===
@rpc("authority", "reliable")
func sync_all_players(all_ids: Array) -> void:
	for id in all_ids:
		_spawn_player(int(id))

@rpc("authority", "reliable")
func spawn_remote_player(id: int) -> void:
	_spawn_player(id)

@rpc("authority", "reliable")
func remove_remote_player(id: int) -> void:
	_remove_player(id)
