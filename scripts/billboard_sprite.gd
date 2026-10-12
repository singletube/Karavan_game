extends Sprite3D

# Билборд: всегда смотрит на камеру (только по Y-оси, как в Doom)
# Godot's Sprite3D уже имеет billboard mode, но этот скрипт добавляет логику анимации

@export var billboard_mode : int = 1   # 1 = Y-only (Doom-style), 2 = full

@onready var anim_player : AnimationPlayer = get_node_or_null("AnimationPlayer")

var camera : Camera3D

func _ready() -> void:
	# Устанавливаем режим билборда
	if billboard_mode == 1:
		self.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		self.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _process(_delta: float) -> void:
	pass  # Godot billboard автоматически поворачивает спрайт
