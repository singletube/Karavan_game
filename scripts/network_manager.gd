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

		# Синхронизируем положение и состояние каравана для подключившегося клиента
		var caravan: Node = get_tree().current_scene.get_node_or_null("Caravan")
		if not caravan:
			caravan = get_tree().get_first_node_in_group("caravan")
		if caravan and caravan.has_method("send_full_sync_to_peer"):
			caravan.send_full_sync_to_peer(id)

		# Синхронизируем состояние волн для подключившегося клиента
		var spawner: Node = get_tree().current_scene.get_node_or_null("WaveSpawner")
		if not spawner:
			spawner = get_tree().get_first_node_in_group("wave_spawner")
		if spawner and spawner.has_method("send_full_sync_to_peer"):
			spawner.send_full_sync_to_peer(id)

		# Синхронизируем время суток (WorldSetup)
		var world_setup: Node = get_tree().current_scene.get_node_or_null("WorldSetup")
		if not world_setup:
			world_setup = get_tree().get_first_node_in_group("world_setup")
		if world_setup and world_setup.has_method("send_full_sync_to_peer"):
			world_setup.send_full_sync_to_peer(id)

		# Синхронизируем сид мира и процедурную генерацию пустыни (DesertGenerator)
		var desert_gen: Node = get_tree().current_scene.get_node_or_null("DesertGenerator")
		if not desert_gen:
			desert_gen = get_tree().get_first_node_in_group("desert_generator")
		if desert_gen and desert_gen.has_method("send_full_sync_to_peer"):
			desert_gen.send_full_sync_to_peer(id)

		# Синхронизируем списки уже расчищенных завалов и собранного лута
		rpc_id(id, "sync_all_cleared_obstacles", cleared_obstacles.keys())
		rpc_id(id, "sync_all_looted_crates", looted_crates.keys())

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
		var caravan: Node = get_tree().current_scene.get_node_or_null("Caravan")
		if not caravan:
			caravan = get_tree().get_first_node_in_group("caravan")
		if caravan and caravan.has_method("get_cargo_spawn_position"):
			(p as Node3D).global_position = caravan.get_cargo_spawn_position()
		else:
			(p as Node3D).global_position = Vector3(randf_range(-6.0, 6.0), 1.0, randf_range(-6.0, 6.0))

	return p

func _remove_player(id: int) -> void:
	var container: Node3D = _get_players_container()
	var node_name: String = str(id)
	if container.has_node(node_name):
		container.get_node(node_name).queue_free()

# === RPC СИНХРОНИЗАЦИЯ ИГРОКОВ ===
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

# === СИНХРОНИЗАЦИЯ ДОРОЖНЫХ ПРЕПЯТСТВИЙ (ОБВАЛЫ, БОЧКИ, МАШИНЫ) ===
var cleared_obstacles: Dictionary = {}

func request_clear_obstacle(obst_id: String, is_detonation: bool) -> void:
	if obst_id.is_empty():
		return
	if not multiplayer.has_multiplayer_peer():
		_apply_clear_obstacle(obst_id, is_detonation)
		return
	rpc("sync_clear_obstacle", obst_id, is_detonation)

@rpc("any_peer", "call_local", "reliable")
func sync_clear_obstacle(obst_id: String, is_detonation: bool) -> void:
	_apply_clear_obstacle(obst_id, is_detonation)

func _apply_clear_obstacle(obst_id: String, is_detonation: bool) -> void:
	cleared_obstacles[obst_id] = true
	var obst := _find_obstacle_by_id(obst_id)
	if obst and is_instance_valid(obst):
		if obst.has_method("clear_local"):
			obst.clear_local(is_detonation)
		else:
			obst.queue_free()

func _find_obstacle_by_id(obst_id: String) -> Node:
	var list := get_tree().get_nodes_in_group("road_obstacle")
	for node in list:
		if is_instance_valid(node) and node.has_meta("obstacle_id") and str(node.get_meta("obstacle_id")) == obst_id:
			return node
	return null

@rpc("authority", "reliable")
func sync_all_cleared_obstacles(all_ids: Array) -> void:
	for id in all_ids:
		var s_id: String = str(id)
		cleared_obstacles[s_id] = true
		var obst := _find_obstacle_by_id(s_id)
		if obst and is_instance_valid(obst):
			obst.queue_free()

# === СИНХРОНИЗАЦИЯ ЛУТА (ПРИПАСЫ НА ЗАПРАВКАХ И В ОАЗИСАХ) ===
var looted_crates: Dictionary = {}

func request_loot_crate(crate_id: String, player_id: int) -> void:
	if crate_id.is_empty():
		return
	if not multiplayer.has_multiplayer_peer():
		_apply_loot_crate(crate_id, player_id)
		return
	rpc("sync_loot_crate", crate_id, player_id)

@rpc("any_peer", "call_local", "reliable")
func sync_loot_crate(crate_id: String, player_id: int) -> void:
	_apply_loot_crate(crate_id, player_id)

func _apply_loot_crate(crate_id: String, player_id: int) -> void:
	looted_crates[crate_id] = true
	var crate := _find_crate_by_id(crate_id)
	if crate and is_instance_valid(crate) and crate.has_method("apply_loot_local"):
		crate.apply_loot_local(player_id)

func _find_crate_by_id(crate_id: String) -> Node:
	var list := get_tree().get_nodes_in_group("loot_crate")
	for node in list:
		if is_instance_valid(node) and node.has_meta("crate_id") and str(node.get_meta("crate_id")) == crate_id:
			return node
	# Резервный поиск среди интерактивных
	var interactives := get_tree().get_nodes_in_group("interactive")
	for node in interactives:
		if is_instance_valid(node) and node.has_meta("crate_id") and str(node.get_meta("crate_id")) == crate_id:
			return node
	return null

@rpc("authority", "reliable")
func sync_all_looted_crates(all_ids: Array) -> void:
	for id in all_ids:
		var s_id: String = str(id)
		looted_crates[s_id] = true
		var crate := _find_crate_by_id(s_id)
		if crate and is_instance_valid(crate) and crate.has_method("mark_already_looted"):
			crate.mark_already_looted()
