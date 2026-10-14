extends Node

# =========================================================================
# ДИНАМИЧЕСКИЙ МУЗЫКАЛЬНЫЙ МЕНЕДЖЕР ПУСТЫНИ
# - Вне волны (передышка 15 сек): играет спокойная тема "Calm Before the Horde"
# - Во время волны врагов: играет динамичный боевой трек (Techno Cannibals, Desert Bloodbath, Neon Pharaoh и др.)
# - После победы над волной: плавный переход обратно на спокойную музыку
# =========================================================================

var music_player : AudioStreamPlayer
var calm_tracks : Array[AudioStream] = []
var combat_tracks : Array[AudioStream] = []

var played_combat_indices : Array[int] = []
var current_combat_index : int = -1

var is_combat : bool = false
var target_volume_db : float = -6.0
var fade_tween : Tween = null
var _connected_spawner : Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.name = "DesertMusicPlayer"
	music_player.bus = "Master"
	music_player.volume_db = target_volume_db
	add_child(music_player)

	music_player.finished.connect(_on_track_finished)
	_load_playlist()

	# На старте игры до первой волны играет спокойная музыка
	_play_calm_track(false)

func _process(_delta: float) -> void:
	_try_connect_wave_spawner()

func _load_playlist() -> void:
	calm_tracks.clear()
	combat_tracks.clear()

	const MUSIC_DIRECTORY := "res://assets/audio/music"
	var directory := DirAccess.open(MUSIC_DIRECTORY)
	if directory == null:
		push_warning("Папка с музыкой не найдена: %s" % MUSIC_DIRECTORY)
		return

	var file_paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
			file_paths.append(MUSIC_DIRECTORY.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	file_paths.sort()

	for p in file_paths:
		if ResourceLoader.exists(p):
			var stream: AudioStream = load(p) as AudioStream
			if stream:
				var fn_lower := p.get_file().to_lower()
				if fn_lower.contains("calm") or fn_lower.contains("before the horde"):
					calm_tracks.append(stream)
				else:
					combat_tracks.append(stream)

	print("MusicManager loaded: %d calm tracks, %d combat tracks" % [calm_tracks.size(), combat_tracks.size()])

func set_combat_mode(active: bool) -> void:
	if is_combat == active:
		return
	is_combat = active

	if is_combat:
		_play_next_combat_track(true)
	else:
		_play_calm_track(true)

func _transition_to_stream(new_stream: AudioStream, crossfade: bool = true) -> void:
	if not new_stream:
		return
	if music_player.stream == new_stream and music_player.playing:
		return

	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	if crossfade and music_player.playing:
		fade_tween = create_tween()
		# Быстрое плавное затухание текущего трека
		fade_tween.tween_property(music_player, "volume_db", -42.0, 0.65)
		fade_tween.tween_callback(func():
			music_player.stream = new_stream
			music_player.play()
		)
		# Плавное нарастание громкости нового трека
		fade_tween.tween_property(music_player, "volume_db", target_volume_db, 0.75)
	else:
		music_player.stream = new_stream
		music_player.volume_db = target_volume_db
		music_player.play()

func _play_calm_track(crossfade: bool = false) -> void:
	if calm_tracks.is_empty():
		if not combat_tracks.is_empty():
			_transition_to_stream(combat_tracks[0], crossfade)
		return

	# Выбираем случайный спокойный трек (Calm Before the Horde)
	var track: AudioStream = calm_tracks[randi() % calm_tracks.size()]
	_transition_to_stream(track, crossfade)

func _play_next_combat_track(crossfade: bool = false) -> void:
	if combat_tracks.is_empty():
		_play_calm_track(crossfade)
		return

	if played_combat_indices.size() >= combat_tracks.size():
		played_combat_indices.clear()

	var available: Array[int] = []
	for i in range(combat_tracks.size()):
		if not played_combat_indices.has(i) and (combat_tracks.size() <= 1 or i != current_combat_index):
			available.append(i)

	if available.is_empty():
		available.append(randi() % combat_tracks.size())

	var next_idx: int = available[randi() % available.size()]
	played_combat_indices.append(next_idx)
	current_combat_index = next_idx

	_transition_to_stream(combat_tracks[current_combat_index], crossfade)

func _on_track_finished() -> void:
	if is_combat:
		_play_next_combat_track(false)
	else:
		_play_calm_track(false)

func _try_connect_wave_spawner() -> void:
	if _connected_spawner != null and is_instance_valid(_connected_spawner):
		return

	var spawner: Node = null
	if get_tree().current_scene:
		spawner = get_tree().current_scene.get_node_or_null("WaveSpawner")
	if not spawner:
		spawner = get_tree().get_first_node_in_group("wave_spawner")

	if spawner and is_instance_valid(spawner):
		_connected_spawner = spawner
		if spawner.has_signal("wave_started"):
			spawner.connect("wave_started", Callable(self, "_on_wave_started_signal"))
		if spawner.has_signal("wave_completed"):
			spawner.connect("wave_completed", Callable(self, "_on_wave_completed_signal"))

func _on_wave_started_signal(_wave_num: int, _wave_name: String) -> void:
	set_combat_mode(true)

func _on_wave_completed_signal(_wave_num: int) -> void:
	set_combat_mode(false)
