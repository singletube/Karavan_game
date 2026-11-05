extends Node3D

# =========================================================================
# REALISTIC CYBORG ZOMBIE CONTROLLER
# Использует универсальный модульный шаблон zombie_cyborg_template.glb
# с высокодетализированной скульптурной 3D-анатомией, 2K PBR-текстурами
# и скелетными анимациями ZombieRig (Idle, Walk, Run, Attack, Hit, Death, Roar).
# =========================================================================

var current_type: String = "Walker"

# Ссылки на ноды
var _model_instance: Node3D = null
var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var eye_lights: Array[OmniLight3D] = []
var core_lights: Array[OmniLight3D] = []

# Состояние
var is_moving: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var has_died: bool = false
var death_timer: float = 0.0
var overload_pulse_timer: float = 0.0

# Базовый цвет свечения для данного киборга
var glow_color: Color = Color(1.0, 0.08, 0.02)

func _ready() -> void:
	pass

func setup_type(type_name: String) -> void:
	current_type = type_name
	_clear_model()

	# Получаем конфигурацию под конкретный игровой тип (с вариацией для ходоков)
	var seed_val: int = randi() if current_type == "Walker" else 0
	var cfg: Dictionary = ZombieCyborgCustomizer.get_config_for_type(current_type, seed_val)
	if cfg.has("colors") and cfg["colors"].has("glow_color"):
		glow_color = cfg["colors"]["glow_color"]

	# Инстанцируем модульный шаблон и применяем конфигурацию слотов и материалов
	_model_instance = ZombieCyborgCustomizer.instantiate_customized(cfg)
	if not _model_instance:
		push_error("CyborgModel3D: Не удалось создать модель для типа " + current_type)
		return

	_model_instance.name = "RealZombieCyborgInstance"
	add_child(_model_instance)

	# Поиск AnimationPlayer внутри glb
	anim_player = _model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		for c in _model_instance.find_children("*", "AnimationPlayer", true, false):
			anim_player = c as AnimationPlayer
			break

	if anim_player:
		_configure_animation_loops()
		if not anim_player.animation_finished.is_connected(_on_anim_finished):
			anim_player.animation_finished.connect(_on_anim_finished)

	# Поиск Skeleton3D
	skeleton = _model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		for c in _model_instance.find_children("*", "Skeleton3D", true, false):
			skeleton = c as Skeleton3D
			break

	# Настройка масштаба под анатомию и боевую роль
	_apply_type_customization()

	# Динамические источники света на глазах и реакторе
	if skeleton:
		_setup_lights(cfg)

	# Запуск анимации покоя
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func _clear_model() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_model_instance = null
	anim_player = null
	skeleton = null
	eye_lights.clear()
	core_lights.clear()
	is_dead = false
	has_died = false
	death_timer = 0.0
	is_hurt = false
	is_attacking = false
	is_moving = false
	overload_pulse_timer = 0.0

func _configure_animation_loops() -> void:
	if not anim_player:
		return
	var looping_anims = ["Idle", "Walk", "Run"]
	for a_name in looping_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR

	var single_anims = ["Attack", "Death", "Hit", "Roar"]
	for a_name in single_anims:
		if anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_NONE

func _apply_type_customization() -> void:
	match current_type:
		"Walker":
			# Стандартный штурмовой зомби (рост ~1.85м)
			scale = Vector3.ONE * 0.95
		"Runner":
			# Поджарый, скоростной сталкер
			scale = Vector3.ONE * 0.88
		"Brute":
			# Огромный тяжелый Джаггернаут-танк (рост ~2.6м)
			scale = Vector3.ONE * 1.38
		"Spitter":
			# Токсичный био-мутант
			scale = Vector3.ONE * 0.98
		"Screamer":
			# Акустическая сирена
			scale = Vector3.ONE * 1.00
		"Exploder":
			# Массивный взрывоопасный киборг с перегруженным ядром
			scale = Vector3.ONE * 1.05
		"Crawler":
			# Низкий механический разведчик
			scale = Vector3(0.95, 0.75, 0.95)
		_:
			scale = Vector3.ONE * 0.95

func _get_or_create_bone_att(bone_name: String) -> BoneAttachment3D:
	if not skeleton:
		return null
	for c in skeleton.get_children():
		if c is BoneAttachment3D and c.bone_name == bone_name:
			return c
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	att.name = "Att_" + bone_name
	skeleton.add_child(att)
	return att

func _setup_lights(cfg: Dictionary) -> void:
	# 1. Свет оптического глаза / визора на голове (кость "Head")
	var head_att := _get_or_create_bone_att("Head")
	if head_att:
		var eye_light := OmniLight3D.new()
		eye_light.name = "CyberEyeLight"
		eye_light.light_color = glow_color
		eye_light.light_energy = 2.4
		eye_light.omni_range = 4.2
		eye_light.omni_attenuation = 1.2
		eye_light.shadow_enabled = false
		# Позиция оптического глаза относительно кости Head (Z вперед, Y вверх)
		eye_light.position = Vector3(0.035, 0.08, -0.09)
		head_att.add_child(eye_light)
		eye_lights.append(eye_light)

	# 2. Свет грудного реакторного ядра (кость "Chest")
	var active_slots: Array = cfg.get("slots", [])
	if active_slots.has("Slot_Torso_ChestCore_R") or active_slots.has("Slot_Torso_HeavyArmor"):
		var chest_att := _get_or_create_bone_att("Chest")
		if chest_att:
			var core_light := OmniLight3D.new()
			core_light.name = "CyberCoreLight"
			core_light.light_color = glow_color
			core_light.light_energy = 2.0
			core_light.omni_range = 3.5
			core_light.omni_attenuation = 1.3
			core_light.shadow_enabled = false
			core_light.position = Vector3(-0.065, 0.02, -0.095)
			chest_att.add_child(core_light)
			core_lights.append(core_light)

# =========================================================================
# УПРАВЛЕНИЕ АНИМАЦИЯМИ (ВЫЗЫВАЕТСЯ ИЗ ENEMY.GD)
# =========================================================================
func _play_anim(p_name: String, blend: float = 0.1, custom_speed: float = 1.0) -> void:
	if not anim_player or not anim_player.has_animation(p_name):
		return
	if anim_player.current_animation != p_name or not anim_player.is_playing():
		anim_player.play(p_name, blend, custom_speed)

func update_animation(_delta: float, moving: bool, move_speed: float, attacking: bool, hurt: bool, dead: bool) -> void:
	if not anim_player:
		return

	is_moving = moving
	is_attacking = attacking
	is_hurt = hurt
	is_dead = dead

	# 1. Смерть: фиксирует труп без дерганий и гасит сенсоры
	if is_dead:
		var death_anim = "Death"
		if not has_died:
			has_died = true
			death_timer = 0.0
			for light in eye_lights:
				if is_instance_valid(light):
					light.light_energy = 0.0
			for light in core_lights:
				if is_instance_valid(light):
					light.light_energy = 0.0
			_play_anim(death_anim, 0.1)
			return

		death_timer += _delta
		var d_len: float = anim_player.get_animation(death_anim).length if anim_player.has_animation(death_anim) else 1.75
		if death_timer >= (d_len - 0.05) or not anim_player.is_playing() or anim_player.current_animation != death_anim:
			anim_player.pause()
			if anim_player.has_animation(death_anim):
				anim_player.seek(anim_player.get_animation(death_anim).length, true)
		return

	if has_died:
		return

	# Пульсация ядра у Подрывника (Exploder) перед взрывом
	if current_type == "Exploder" and is_attacking:
		overload_pulse_timer += _delta * 14.0
		var pulse: float = 2.0 + 3.0 * sin(overload_pulse_timer)
		for l in core_lights + eye_lights:
			if is_instance_valid(l):
				l.light_energy = maxf(0.5, pulse)

	# 2. Получение урона (Hit)
	if is_hurt:
		_play_anim("Hit", 0.08, 1.4)
		return

	# 3. Атака (Attack / Roar)
	if is_attacking:
		var atk_anim: String = "Roar" if current_type == "Screamer" else "Attack"
		var atk_speed: float = 1.4 if current_type == "Runner" else (0.9 if current_type == "Brute" else 1.1)
		if anim_player.current_animation == atk_anim:
			if not anim_player.is_playing():
				# Анимация удара завершилась, ждем в стойке покоя до следующего замаха
				_play_anim("Idle", 0.25)
			return
		else:
			_play_anim(atk_anim, 0.1, atk_speed)
			return

	# 4. Движение (Run для Runner, Walk для остальных)
	if is_moving:
		if current_type == "Runner":
			_play_anim("Run", 0.15, maxf(1.1, move_speed * 0.32))
		elif current_type == "Brute":
			_play_anim("Walk", 0.2, 0.82)
		else:
			_play_anim("Walk", 0.2, maxf(0.85, move_speed * 0.38))
		return

	# 5. Покой (Idle)
	if anim_player.current_animation != "Idle":
		_play_anim("Idle", 0.25)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "Death":
		if anim_player:
			anim_player.pause()
			if anim_player.has_animation(anim_name):
				anim_player.seek(anim_player.get_animation(anim_name).length, true)
