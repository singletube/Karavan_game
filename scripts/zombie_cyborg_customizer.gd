class_name ZombieCyborgCustomizer
extends RefCounted

## Универсальный конфигуратор модульного шаблона Зомби-Киборга (`zombie_cyborg_template.glb`).
## Позволяет на лету (или из пресета / словаря / random seed) менять:
## - органические и кибернетические конечности (левая/правая рука, левая/правая нога);
## - импланты головы и челюсти (черепные пластины L/R, полный визор, рога-сирены, респиратор, кислотный распылитель);
## - импланты торса и спины (грудной реактор с рёбрами, тяжёлая броня, экзо-позвоночник, хим-баллоны);
## - оружие кибер-рук (клинки-рипперы L/R, осадный молот-крушитель, био-плазменная пушка);
## - одежду и экипировку (тактический жилет, плащ-капюшон кочевника, штаны-карго, пояс с батареями, ботинки);
## - цвета (свечение глаз/ядра, оттенок кожи, цвет металла брони, цвет жилета и штанов).

const TEMPLATE_SCENE_PATH := "res://models/zombies/zombie_cyborg_template.glb"

## Все доступные модульные слоты в `zombie_cyborg_template.glb`:
const ALL_SLOTS: Array[String] = [
	# Голова и челюсть (04_HeadImplants)
	"Slot_Head_CranialPlate_L",
	"Slot_Head_CranialPlate_R",
	"Slot_Head_Visor_Full",
	"Slot_Head_SirenHorns",
	"Slot_Jaw_Respirator",
	"Slot_Jaw_AcidSpitter",
	# Торс и спина (05_TorsoBackImplants)
	"Slot_Torso_ChestCore_R",
	"Slot_Torso_HeavyArmor",
	"Slot_Back_ExoSpine",
	"Slot_Back_ChemTanks",
	# Руки, наплечники и оружие (06_CyberArms)
	"Slot_Pauldron_L",
	"Slot_Pauldron_R",
	"Slot_ArmL_CyberClaw",
	"Slot_ArmL_Weapon_Blade",
	"Slot_ArmR_CyberClaw",
	"Slot_ArmR_Weapon_Blade",
	"Slot_ArmR_Weapon_Crusher",
	"Slot_ArmR_Weapon_Cannon",
	# Ноги и ботинки (07_CyberLegsBoots)
	"Slot_LegL_CyberStrut",
	"Slot_LegR_CyberStrut",
	"Slot_Boot_L",
	"Slot_Boot_R",
	# Одежда и ремни (03_Clothing)
	"Slot_Cloth_TacticalVest",
	"Slot_Cloth_RagsHood",
	"Slot_Cloth_CargoPants_Asym",
	"Slot_Cloth_CargoPants_Short",
	"Slot_Cloth_BeltHarness",
]

## Готовые пресеты под все игровые типы врагов (Walker, Runner, Brute, Spitter, Screamer, Exploder, Crawler)
const PRESETS: Dictionary = {
	# 1. WALKER: Стандартный штурмовой зомби-киборг
	"Walker": {
		"organic_limbs": {"arm_l": false, "arm_r": true, "leg_l": false, "leg_r": true},
		"slots": [
			"Slot_Head_CranialPlate_L", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_Pauldron_L", "Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_Boot_R",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Asym"
		],
		"colors": {
			"glow_color": Color(1.0, 0.08, 0.02),
			"skin_tint": Color(1.0, 1.0, 1.0),
			"armor_tint": Color(0.85, 0.88, 0.92),
			"shirt_tint": Color(0.85, 0.88, 0.80),
			"pants_tint": Color(0.80, 0.86, 0.95),
		}
	},
	"default_walker": {
		"organic_limbs": {"arm_l": false, "arm_r": true, "leg_l": false, "leg_r": true},
		"slots": [
			"Slot_Head_CranialPlate_L", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_Pauldron_L", "Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_Boot_R",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Asym"
		],
		"colors": {
			"glow_color": Color(1.0, 0.08, 0.02),
			"skin_tint": Color(1.0, 1.0, 1.0),
			"armor_tint": Color(0.85, 0.88, 0.92),
			"shirt_tint": Color(0.85, 0.88, 0.80),
			"pants_tint": Color(0.80, 0.86, 0.95),
		}
	},

	# 2. RUNNER: Скоростной преследователь-потрошитель (двойные клинки, визор, синее плазменное свечение)
	"Runner": {
		"organic_limbs": {"arm_l": false, "arm_r": false, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(0.08, 0.65, 1.0),
			"skin_tint": Color(0.84, 0.88, 0.98),
			"armor_tint": Color(0.55, 0.62, 0.75),
			"shirt_tint": Color(0.55, 0.60, 0.75),
			"pants_tint": Color(0.50, 0.55, 0.70),
		}
	},
	"dual_blade_stalker": {
		"organic_limbs": {"arm_l": false, "arm_r": false, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_Visor_Full", "Slot_Head_SirenHorns",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(0.08, 0.65, 1.0),
			"skin_tint": Color(0.84, 0.88, 0.98),
			"armor_tint": Color(0.55, 0.62, 0.75),
			"shirt_tint": Color(0.55, 0.60, 0.75),
			"pants_tint": Color(0.50, 0.55, 0.70),
		}
	},

	# 3. BRUTE: Тяжелый киборг-танк (массивная броня, осадный молот, двойные наплечники, оранжевый свет)
	"Brute": {
		"organic_limbs": {"arm_l": false, "arm_r": false, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_CranialPlate_L", "Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
			"Slot_Torso_HeavyArmor", "Slot_Back_ExoSpine",
			"Slot_Pauldron_L", "Slot_Pauldron_R",
			"Slot_ArmL_CyberClaw", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Crusher",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(1.0, 0.38, 0.02),
			"skin_tint": Color(0.78, 0.74, 0.72),
			"armor_tint": Color(0.55, 0.50, 0.45),
			"shirt_tint": Color(0.5, 0.5, 0.5),
			"pants_tint": Color(0.75, 0.68, 0.58),
		}
	},
	"heavy_siege_brute": {
		"organic_limbs": {"arm_l": false, "arm_r": false, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_CranialPlate_L", "Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
			"Slot_Torso_HeavyArmor", "Slot_Back_ExoSpine",
			"Slot_Pauldron_L", "Slot_Pauldron_R",
			"Slot_ArmL_CyberClaw", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Crusher",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(1.0, 0.38, 0.02),
			"skin_tint": Color(0.78, 0.74, 0.72),
			"armor_tint": Color(0.55, 0.50, 0.45),
			"shirt_tint": Color(0.5, 0.5, 0.5),
			"pants_tint": Color(0.75, 0.68, 0.58),
		}
	},

	# 4. SPITTER: Био-химический плеватель (сопло в челюсти, мешок яда, хим-баллоны, пушка, кислотно-зеленый свет)
	"Spitter": {
		"organic_limbs": {"arm_l": true, "arm_r": false, "leg_l": true, "leg_r": false},
		"slots": [
			"Slot_Head_CranialPlate_R", "Slot_Jaw_AcidSpitter",
			"Slot_Torso_ChestCore_R", "Slot_Back_ChemTanks",
			"Slot_Pauldron_R", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Cannon",
			"Slot_LegR_CyberStrut", "Slot_Boot_L",
			"Slot_Cloth_RagsHood", "Slot_Cloth_CargoPants_Asym"
		],
		"colors": {
			"glow_color": Color(0.15, 1.0, 0.08),
			"skin_tint": Color(0.76, 0.95, 0.72),
			"armor_tint": Color(0.60, 0.75, 0.62),
			"shirt_tint": Color(0.75, 0.85, 0.55),
			"pants_tint": Color(0.65, 0.75, 0.65),
		}
	},
	"toxic_bio_spitter": {
		"organic_limbs": {"arm_l": true, "arm_r": false, "leg_l": true, "leg_r": false},
		"slots": [
			"Slot_Head_CranialPlate_R", "Slot_Jaw_AcidSpitter",
			"Slot_Torso_ChestCore_R", "Slot_Back_ChemTanks",
			"Slot_Pauldron_R", "Slot_ArmR_CyberClaw", "Slot_ArmR_Weapon_Cannon",
			"Slot_LegR_CyberStrut", "Slot_Boot_L",
			"Slot_Cloth_RagsHood", "Slot_Cloth_CargoPants_Asym"
		],
		"colors": {
			"glow_color": Color(0.15, 1.0, 0.08),
			"skin_tint": Color(0.76, 0.95, 0.72),
			"armor_tint": Color(0.60, 0.75, 0.62),
			"shirt_tint": Color(0.75, 0.85, 0.55),
			"pants_tint": Color(0.65, 0.75, 0.65),
		}
	},

	# 5. SCREAMER: Акустическая сирена (височные рога-резонаторы, визор, открытый респиратор, пурпурный свет)
	"Screamer": {
		"organic_limbs": {"arm_l": false, "arm_r": true, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_SirenHorns", "Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(0.85, 0.15, 1.0),
			"skin_tint": Color(0.92, 0.80, 0.95),
			"armor_tint": Color(0.65, 0.55, 0.75),
			"shirt_tint": Color(0.45, 0.35, 0.50),
			"pants_tint": Color(0.35, 0.28, 0.40),
		}
	},

	# 6. EXPLODER: Нестабильный киборг-камикадзе (открытое искрящееся ядро, батареи, баллоны, пульсирующее багрово-янтарное свечение)
	"Exploder": {
		"organic_limbs": {"arm_l": false, "arm_r": false, "leg_l": false, "leg_r": true},
		"slots": [
			"Slot_Head_CranialPlate_L", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ChemTanks",
			"Slot_Pauldron_L", "Slot_ArmL_CyberClaw", "Slot_ArmR_CyberClaw",
			"Slot_LegL_CyberStrut", "Slot_Boot_R",
			"Slot_Cloth_TacticalVest", "Slot_Cloth_CargoPants_Asym", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(1.0, 0.22, 0.04),
			"skin_tint": Color(0.85, 0.72, 0.65),
			"armor_tint": Color(0.48, 0.38, 0.32),
			"shirt_tint": Color(0.35, 0.25, 0.20),
			"pants_tint": Color(0.30, 0.22, 0.18),
		}
	},

	# 7. CRAWLER: Быстрый низкий механический разведчик (двойные бионические ноги, темный воронёный титан)
	"Crawler": {
		"organic_limbs": {"arm_l": false, "arm_r": true, "leg_l": false, "leg_r": false},
		"slots": [
			"Slot_Head_Visor_Full", "Slot_Jaw_Respirator",
			"Slot_Torso_ChestCore_R", "Slot_Back_ExoSpine",
			"Slot_ArmL_CyberClaw", "Slot_ArmL_Weapon_Blade",
			"Slot_LegL_CyberStrut", "Slot_LegR_CyberStrut",
			"Slot_Cloth_CargoPants_Short", "Slot_Cloth_BeltHarness"
		],
		"colors": {
			"glow_color": Color(1.0, 0.75, 0.10),
			"skin_tint": Color(0.70, 0.75, 0.72),
			"armor_tint": Color(0.32, 0.35, 0.40),
			"shirt_tint": Color(0.20, 0.22, 0.25),
			"pants_tint": Color(0.18, 0.20, 0.24),
		}
	},
}

## Инстанцирует модульный шаблон и сразу применяет пресет или словарь конфигурации.
static func instantiate_customized(preset_or_config: Variant = "default_walker") -> Node3D:
	var packed: PackedScene = load(TEMPLATE_SCENE_PATH)
	if packed == null:
		push_error("ZombieCyborgCustomizer: Не найден шаблон " + TEMPLATE_SCENE_PATH)
		return null
	var instance: Node3D = packed.instantiate()
	if typeof(preset_or_config) == TYPE_STRING:
		apply_preset(instance, preset_or_config)
	elif typeof(preset_or_config) == TYPE_DICTIONARY:
		apply_config(instance, preset_or_config)
	return instance

## Применяет конфигурацию под конкретный игровой тип врага с поддержкой seed-рандомизации (для разнообразия пехоты)
static func apply_for_enemy_type(model_root: Node3D, type_name: String, seed_val: int = 0) -> void:
	var cfg := get_config_for_type(type_name, seed_val)
	apply_config(model_root, cfg)

## Возвращает конфигурационный словарь для типа врага
static func get_config_for_type(type_name: String, seed_val: int = 0) -> Dictionary:
	if type_name == "Walker" and seed_val != 0:
		return generate_walker_variant(seed_val)
	if PRESETS.has(type_name):
		return PRESETS[type_name]
	var lower_name: String = type_name.to_lower()
	for k: String in PRESETS.keys():
		if k.to_lower() == lower_name:
			return PRESETS[k]
	return PRESETS["Walker"]

## Применяет именованный пресет из `PRESETS`.
static func apply_preset(model_root: Node3D, preset_name: String) -> void:
	var cfg: Dictionary = get_config_for_type(preset_name, 0)
	apply_config(model_root, cfg)

## Применяет произвольный словарь конфигурации (`organic_limbs`, `slots`, `colors`).
static func apply_config(model_root: Node3D, cfg: Dictionary) -> void:
	if model_root == null:
		return

	var org: Dictionary = cfg.get("organic_limbs", {"arm_l": false, "arm_r": true, "leg_l": false, "leg_r": true})
	var active_slots: Array = cfg.get("slots", [])

	# 1. Переключаем видимость органических частей тела и модульных слотов
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model_root, meshes)

	for mi in meshes:
		var n: String = mi.name
		if n == "Body_TorsoHead":
			mi.visible = true
		elif n == "Body_Arm_L":
			mi.visible = bool(org.get("arm_l", true))
		elif n == "Body_Arm_R":
			mi.visible = bool(org.get("arm_r", true))
		elif n == "Body_Leg_L":
			mi.visible = bool(org.get("leg_l", true))
		elif n == "Body_Leg_R":
			mi.visible = bool(org.get("leg_r", true))
		elif n.begins_with("Slot_"):
			mi.visible = active_slots.has(n)

	# 2. Применяем кастомные оттенки материалов (индивидуально для данного экземпляра)
	if cfg.has("colors"):
		var col_dict: Dictionary = cfg["colors"]
		apply_colors(model_root, col_dict)
		if col_dict.has("glow_color"):
			model_root.set_meta("glow_color", col_dict["glow_color"])

## Меняет цвета свечения, кожи, брони и одежды только на данном экземпляре модели.
static func apply_colors(model_root: Node3D, colors: Dictionary) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model_root, meshes)

	var mat_Overrides: Dictionary = {}
	for mi in meshes:
		if not mi.visible or mi.mesh == null:
			continue
		var surf_count: int = mi.mesh.get_surface_count()
		for s_idx in range(surf_count):
			var base_mat: Material = mi.get_active_material(s_idx)
			if not (base_mat is BaseMaterial3D):
				continue
			var mname: String = base_mat.resource_name
			if not mat_Overrides.has(mname):
				var dup: BaseMaterial3D = base_mat.duplicate()
				if mname.contains("Glow") and colors.has("glow_color"):
					var gc: Color = colors["glow_color"]
					dup.albedo_color = gc
					dup.emission_enabled = true
					dup.emission = gc
				elif mname.contains("Skin") and colors.has("skin_tint"):
					dup.albedo_color = colors["skin_tint"]
				elif (mname.contains("Steel") or mname.contains("GunMetal")) and colors.has("armor_tint"):
					dup.albedo_color = colors["armor_tint"]
				elif mname.contains("Shirt") and colors.has("shirt_tint"):
					dup.albedo_color = colors["shirt_tint"]
				elif mname.contains("Pants") and colors.has("pants_tint"):
					dup.albedo_color = colors["pants_tint"]
				mat_Overrides[mname] = dup
			mi.set_surface_override_material(s_idx, mat_Overrides[mname])

## Создает интересные вариации для стандартных ходоков-зомби (Walker), чтобы толпа не выглядела клонами
static func generate_walker_variant(seed_val: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var cyber_left_arm: bool = true
	var cyber_right_arm: bool = rng.randf() < 0.25
	var cyber_left_leg: bool = true
	var cyber_right_leg: bool = rng.randf() < 0.20

	var slots: Array[String] = []

	# Голова
	if rng.randf() < 0.65:
		slots.append("Slot_Head_CranialPlate_L")
	else:
		slots.append("Slot_Head_Visor_Full")
	slots.append("Slot_Jaw_Respirator")

	# Торс
	if rng.randf() < 0.70:
		slots.append("Slot_Torso_ChestCore_R")
	else:
		slots.append("Slot_Torso_HeavyArmor")
	slots.append("Slot_Back_ExoSpine")

	# Руки
	slots.append("Slot_ArmL_CyberClaw")
	if rng.randf() < 0.80:
		slots.append("Slot_ArmL_Weapon_Blade")
	if rng.randf() < 0.70:
		slots.append("Slot_Pauldron_L")

	if cyber_right_arm:
		slots.append("Slot_ArmR_CyberClaw")
		if rng.randf() < 0.50:
			slots.append("Slot_ArmR_Weapon_Blade")

	# Ноги
	slots.append("Slot_LegL_CyberStrut")
	if cyber_right_leg:
		slots.append("Slot_LegR_CyberStrut")
	else:
		slots.append("Slot_Boot_R")

	# Одежда
	slots.append("Slot_Cloth_TacticalVest" if rng.randf() < 0.70 else "Slot_Cloth_RagsHood")
	slots.append("Slot_Cloth_CargoPants_Asym" if not cyber_right_leg else "Slot_Cloth_CargoPants_Short")
	if rng.randf() < 0.50:
		slots.append("Slot_Cloth_BeltHarness")

	var glow_c: Color = Color(1.0, rng.randf_range(0.04, 0.16), 0.02)
	return {
		"organic_limbs": {
			"arm_l": not cyber_left_arm,
			"arm_r": not cyber_right_arm,
			"leg_l": not cyber_left_leg,
			"leg_r": not cyber_right_leg,
		},
		"slots": slots,
		"colors": {
			"glow_color": glow_c,
			"skin_tint": Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.85, 1.0), rng.randf_range(0.80, 0.95)),
			"armor_tint": Color(rng.randf_range(0.70, 0.90), rng.randf_range(0.72, 0.92), rng.randf_range(0.75, 0.95)),
			"shirt_tint": Color(rng.randf_range(0.70, 0.90), rng.randf_range(0.70, 0.90), rng.randf_range(0.65, 0.85)),
			"pants_tint": Color(rng.randf_range(0.65, 0.85), rng.randf_range(0.70, 0.90), rng.randf_range(0.75, 0.98)),
		}
	}

## Генерирует случайную осмысленную конфигурацию зомби-киборга по `seed_val`.
static func generate_random_config(seed_val: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var cyber_arm_l: bool = rng.randf() < 0.70
	var cyber_arm_r: bool = rng.randf() < 0.45 or (not cyber_arm_l)
	var cyber_leg_l: bool = rng.randf() < 0.65
	var cyber_leg_r: bool = rng.randf() < 0.35

	var slots: Array[String] = []

	# Голова
	var head_roll: float = rng.randf()
	if head_roll < 0.45:
		slots.append("Slot_Head_CranialPlate_L")
	elif head_roll < 0.75:
		slots.append("Slot_Head_CranialPlate_R")
	else:
		slots.append("Slot_Head_Visor_Full")
	if rng.randf() < 0.25:
		slots.append("Slot_Head_SirenHorns")

	# Челюсть
	if rng.randf() < 0.70:
		slots.append("Slot_Jaw_Respirator")
	else:
		slots.append("Slot_Jaw_AcidSpitter")

	# Торс и спина
	if rng.randf() < 0.65:
		slots.append("Slot_Torso_ChestCore_R")
	else:
		slots.append("Slot_Torso_HeavyArmor")

	if rng.randf() < 0.70:
		slots.append("Slot_Back_ExoSpine")
	else:
		slots.append("Slot_Back_ChemTanks")

	# Руки и оружие
	if cyber_arm_l:
		slots.append("Slot_ArmL_CyberClaw")
		if rng.randf() < 0.65:
			slots.append("Slot_Pauldron_L")
		if rng.randf() < 0.75:
			slots.append("Slot_ArmL_Weapon_Blade")
	if cyber_arm_r:
		slots.append("Slot_ArmR_CyberClaw")
		if rng.randf() < 0.55:
			slots.append("Slot_Pauldron_R")
		var w_roll: float = rng.randf()
		if w_roll < 0.45:
			slots.append("Slot_ArmR_Weapon_Blade")
		elif w_roll < 0.75:
			slots.append("Slot_ArmR_Weapon_Crusher")
		else:
			slots.append("Slot_ArmR_Weapon_Cannon")

	# Ноги и ботинки
	if cyber_leg_l:
		slots.append("Slot_LegL_CyberStrut")
	else:
		slots.append("Slot_Boot_L")
	if cyber_leg_r:
		slots.append("Slot_LegR_CyberStrut")
	else:
		slots.append("Slot_Boot_R")

	# Одежда
	if not slots.has("Slot_Torso_HeavyArmor"):
		slots.append("Slot_Cloth_TacticalVest" if rng.randf() < 0.65 else "Slot_Cloth_RagsHood")
	if cyber_leg_l and cyber_leg_r:
		slots.append("Slot_Cloth_CargoPants_Short")
	else:
		slots.append("Slot_Cloth_CargoPants_Asym")
	if rng.randf() < 0.60:
		slots.append("Slot_Cloth_BeltHarness")

	var glow_palette: Array[Color] = [
		Color(1.0, 0.08, 0.02), # Красный (стандарт)
		Color(1.0, 0.38, 0.02), # Оранжевый (индустриальный)
		Color(0.15, 1.0, 0.08), # Кислотно-зелёный (био-хим)
		Color(0.08, 0.65, 1.0), # Плазменно-синий
		Color(0.75, 0.15, 1.0), # Фиолетовый (перегрузка ядра)
	]

	return {
		"organic_limbs": {
			"arm_l": not cyber_arm_l,
			"arm_r": not cyber_arm_r,
			"leg_l": not cyber_leg_l,
			"leg_r": not cyber_leg_r,
		},
		"slots": slots,
		"colors": {
			"glow_color": glow_palette[rng.randi() % glow_palette.size()],
			"skin_tint": Color(rng.randf_range(0.75, 1.0), rng.randf_range(0.78, 1.0), rng.randf_range(0.72, 0.96)),
			"armor_tint": Color(rng.randf_range(0.45, 0.90), rng.randf_range(0.45, 0.90), rng.randf_range(0.45, 0.95)),
			"shirt_tint": Color(rng.randf_range(0.55, 0.95), rng.randf_range(0.55, 0.95), rng.randf_range(0.50, 0.90)),
			"pants_tint": Color(rng.randf_range(0.50, 0.90), rng.randf_range(0.55, 0.90), rng.randf_range(0.55, 0.95)),
		}
	}

static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)
