extends Node

# --- Музыкальный менеджер пустыни (случайное бесконечное воспроизведение) ---
var music_player : AudioStreamPlayer
var playlist : Array[AudioStream] = []
var played_indices : Array[int] = []
var current_index : int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -6.0
	add_child(music_player)

	music_player.finished.connect(_on_track_finished)
	_load_playlist()
	play_next_random()

func _load_playlist() -> void:
	const MUSIC_DIRECTORY := "res://assets/audio/music"
	var directory := DirAccess.open(MUSIC_DIRECTORY)
	if directory == null:
		push_warning("Папка с музыкой не найдена: %s" % MUSIC_DIRECTORY)
		return

	var music_paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
			music_paths.append(MUSIC_DIRECTORY.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	music_paths.sort()

	for p in music_paths:
		if ResourceLoader.exists(p):
			var stream: AudioStream = load(p) as AudioStream
			if stream:
				playlist.append(stream)

func play_next_random() -> void:
	if playlist.is_empty():
		return

	if played_indices.size() >= playlist.size():
		played_indices.clear()

	var available: Array[int] = []
	for i in range(playlist.size()):
		if not played_indices.has(i) and (playlist.size() <= 1 or i != current_index):
			available.append(i)

	if available.is_empty():
		available.append(randi() % playlist.size())

	var next_idx: int = available[randi() % available.size()]
	played_indices.append(next_idx)
	current_index = next_idx

	music_player.stream = playlist[current_index]
	music_player.play()

func _on_track_finished() -> void:
	play_next_random()
