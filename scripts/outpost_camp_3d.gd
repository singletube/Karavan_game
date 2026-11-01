extends Node3D

class_name OutpostCamp3D

# =========================================================================
# УКРЕПЛЕННЫЙ ЛАГЕРЬ ВЫЖИВШИХ / ОАЗИС БЕЗОПАСНОСТИ НА КАРАВАННОМ ТРАКТЕ
# =========================================================================
# Включает:
# - Входные и выходные массивные ворота с ручным механизмом открытия [E]
# - Защищенный периметр (стены из песчаника, мешки с песком, колючая проволока)
# - Зону безопасности: караван въезжает внутрь, входные ворота закрываются,
#   волны зомби и таймер спавна приостанавливаются.
# - Жителей лагеря (NPC с детальными 3D моделями):
#   * Торговец боеприпасами и медикаментами (Торговля)
#   * Оружейный мастер / Механик (Прокачка каравана и оружия)
#   * Командир аванпоста (Квесты и награды)
# - Интерактивный диалоговый/торговый UI с курсором мыши

var camp_id: String = ""
var entry_gate_closed: bool = false
var exit_gate_opened: bool = false
var caravan_inside: bool = false

# Ноды ворот
var entry_gate_node: Node3D = null
var entry_gate_col: CollisionShape3D = null
var exit_gate_node: Node3D = null
var exit_gate_col: CollisionShape3D = null
var exit_gate_trigger: Node3D = null

# Детектор въезда каравана
var check_timer: float = 0.0

func _ready() -> void:
	add_to_group("outpost_camp")

func _process(delta: float) -> void:
	check_timer += delta
	if check_timer < 0.25:
		return
	check_timer = 0.0

	_check_caravan_entry()

func _check_caravan_entry() -> void:
	var caravan := get_tree().get_first_node_in_group("caravan") as Node3D
	if not caravan or not is_instance_valid(caravan):
		return

	var caravan_pos: Vector3 = caravan.global_position
	var camp_pos: Vector3 = global_position

	# Относительное положение каравана вдоль дороги лагеря (Z направлен вдоль движения каравана)
	var rel: Vector3 = caravan_pos - camp_pos
	var fwd_dist: float = -rel.z # Караван движется в сторону -Z
	var side_dist: float = absf(rel.x)

	if side_dist > 16.0:
		return

	# Караван заехал за входные ворота (вглубь лагеря)
	if not caravan_inside and not entry_gate_closed and fwd_dist >= 1.0 and fwd_dist <= 26.0:
		_on_caravan_entered_camp(caravan)

func _on_caravan_entered_camp(_caravan: Node3D) -> void:
	caravan_inside = true
	entry_gate_closed = true

	# Закрываем входные ворота за караваном
	if entry_gate_node:
		var tw := create_tween()
		tw.tween_property(entry_gate_node, "position:y", 2.2, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if entry_gate_col:
		entry_gate_col.disabled = false

	# Уведомляем WaveSpawner о мирной зоне (приостанавливаем волны)
	var spawner := get_tree().current_scene.get_node_or_null("WaveSpawner")
	if spawner and spawner.has_method("set_camp_peaceful_zone"):
		spawner.set_camp_peaceful_zone(true)

	# Уведомляем караван об остановке в лагере
	var caravan := get_tree().get_first_node_in_group("caravan")
	if caravan and caravan.has_method("set_in_camp"):
		caravan.set_in_camp(true)

	# Уведомление игрокам
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("notify_hud"):
			p.notify_hud("⛺ КАРАВАН В БЕЗОПАСНОСТИ! ЛАГЕРЬ ВЫЖИВШИХ", Color(0.35, 1.0, 0.45))

func open_exit_gate_by_player(player: Node) -> void:
	if exit_gate_opened:
		return

	var c_id: String = camp_id
	var net_mgr := get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if net_mgr != null and net_mgr.has_method("request_open_camp_gate") and not c_id.is_empty():
		net_mgr.request_open_camp_gate(c_id)
	else:
		apply_open_exit_gate()

	if player and player.has_method("notify_hud"):
		player.notify_hud("ВОРОТА ОТКРЫТЫ! КАРАВАН ПРОДОЛЖАЕТ ПУТЬ", Color(1.0, 0.88, 0.35))

func apply_open_exit_gate() -> void:
	if exit_gate_opened:
		return
	exit_gate_opened = true

	# Анимация поднятия выходных ворот
	if exit_gate_node:
		var tw := create_tween()
		tw.tween_property(exit_gate_node, "position:y", 6.8, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if exit_gate_col:
		exit_gate_col.disabled = true

	# Снимаем блокировку с каравана
	var caravan := get_tree().get_first_node_in_group("caravan")
	if caravan and caravan.has_method("set_in_camp"):
		caravan.set_in_camp(false)

	# Возобновляем спавн волн
	var spawner := get_tree().current_scene.get_node_or_null("WaveSpawner")
	if spawner and spawner.has_method("set_camp_peaceful_zone"):
		spawner.set_camp_peaceful_zone(false)

	# Убираем интерактивный триггер
	if exit_gate_trigger and is_instance_valid(exit_gate_trigger):
		exit_gate_trigger.remove_from_group("interactive")
