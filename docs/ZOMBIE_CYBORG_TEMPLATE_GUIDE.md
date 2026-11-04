# Универсальный модульный шаблон Зомби-Киборга — Инструкция по работе

Этот шаблон позволяет создавать десятки уникальных вариантов зомби-киборгов из единой риггированной базы (23 кости `ZombieRig` + 7 скелетных анимаций: `Idle`, `Walk`, `Run`, `Attack`, `Hit`, `Death`, `Roar`) тремя способами:
1. **В реальном времени в Godot 4** (через скрипт [`ZombieCyborgCustomizer`](file:///c:/Users/user/Documents/идет-караван-из-ирана/scripts/zombie_cyborg_customizer.gd) и модель [`zombie_cyborg_template.glb`](file:///c:/Users/user/Documents/идет-караван-из-ирана/models/zombies/zombie_cyborg_template.glb)).
2. **Через JSON-конфиги и командную строку Blender** (экспорт отдельного оптимизированного `.glb` под конкретный пресет через [`tools/zombie_cyborg_template.py`](file:///c:/Users/user/Documents/идет-караван-из-ирана/tools/zombie_cyborg_template.py)).
3. **Вручную в Blender** (открыв [`zombie_cyborg_template.blend`](file:///C:/Users/user/ZombieCyborg/zombie_cyborg_template.blend) и переключая глазки видимости коллекций и слотов в Outliner).

---

## 1. Архитектура шаблона и список всех модульных слотов

Все части персонажа разделены на **7 коллекций** в Blender и экспортируются как отдельные именованные `MeshInstance3D`-узлы внутри скелета `ZombieRig`:

### А. Органическое тело (`02_OrganicBody`)
Позволяет независимо ампутировать и заменять любую руку или ногу протезом:
| Имя узла (`MeshInstance3D`) | Назначение | Когда скрывать (`visible = false`) |
| :--- | :--- | :--- |
| `Body_TorsoHead` | Голова, шея, грудная клетка, живот, таз и культи бёдер/плеч | **Всегда включён** (`true`) |
| `Body_Arm_L` | Органическая левая рука (предплечье + кисть с когтями) | Скрывать, если включён `Slot_ArmL_CyberClaw` |
| `Body_Arm_R` | Органическая правая рука (предплечье + кисть с когтями) | Скрывать, если включён `Slot_ArmR_CyberClaw` |
| `Body_Leg_L` | Органическая левая голень и стопа | Скрывать, если включён `Slot_LegL_CyberStrut` |
| `Body_Leg_R` | Органическая правая голень и стопа | Скрывать, если включён `Slot_LegR_CyberStrut` |

### Б. Одежда и экипировка (`03_Clothing`)
| Имя слота | Описание |
| :--- | :--- |
| `Slot_Cloth_TacticalVest` | Рваный тактический жилет с хирургическим вырезом под грудной реактор и открытым каналом на спине под экзо-позвоночник |
| `Slot_Cloth_RagsHood` | Постапокалиптическая накидка-плащ кочевника на плечи и грудь |
| `Slot_Cloth_CargoPants_Asym` | Асимметричные рваные штаны-карго (высокий обрыв слева под кибер-колено, низкий справа) |
| `Slot_Cloth_CargoPants_Short` | Короткие оборванные бриджи (оба колена открыты — идеально для двух кибер-ног) |
| `Slot_Cloth_BeltHarness` | Тяжёлый кожано-стальной пояс с пряжкой и двумя светящимися энергоячейками по бокам |

### В. Импланты головы и челюсти (`04_HeadImplants`)
| Имя слота | Описание |
| :--- | :--- |
| `Slot_Head_CranialPlate_L` | Титановая черепная пластина на левом полушарии + светящийся оптический сканер левого глаза + лазер на брови |
| `Slot_Head_CranialPlate_R` | Титановая черепная пластина на правом полушарии + светящийся оптический сканер правого глаза |
| `Slot_Head_Visor_Full` | Сплошной тактический кибер-визор во всю ширину глазниц со светящейся щелью |
| `Slot_Head_SirenHorns` | Двойные акустические рога-резонаторы / нейроантенны на висках (для Крикунов / Screamer) |
| `Slot_Jaw_Respirator` | Стальной челюстной респиратор с боковыми фильтрами и двумя гофрированными шлангами к груди |
| `Slot_Jaw_AcidSpitter` | Химическое сопло-распылитель в нижней челюсти + светящийся токсичный мешок на горле (для Плевателей / Spitter) |

### Г. Импланты торса и спины (`05_TorsoBackImplants`)
| Имя слота | Описание |
| :--- | :--- |
| `Slot_Torso_ChestCore_R` | Вскрытая хирургическая полость в правой груди с 4 сломанными рёбрами и светящимся реакторным ядром |
| `Slot_Torso_HeavyArmor` | Нагрудные стальные бронепластины Джаггернаута на болтах + центральный энергоблок |
| `Slot_Back_ExoSpine` | 9-сегментный механический экзо-позвоночник с хромированными рельсами, энергоузлами и нейрокабелями к затылку |
| `Slot_Back_ChemTanks` | Два герметичных био-химических баллона со светящимися колбами и шлангами на спине |

### Д. Кибер-руки, наплечники и оружие (`06_CyberArms`)
| Имя слота | Описание |
| :--- | :--- |
| `Slot_Pauldron_L` / `Slot_Pauldron_R` | Клёпаный титановый наплечник на левое / правое плечо |
| `Slot_ArmL_CyberClaw` | Левый гидравлический протез руки с 4-палой когтистой механической кистью (заменяет `Body_Arm_L`) |
| `Slot_ArmR_CyberClaw` | Правый гидравлический протез руки с 4-палой когтистой механической кистью (заменяет `Body_Arm_R`) |
| `Slot_ArmL_Weapon_Blade` | Выдвижной хромированный клинок-риппер на левое предплечье |
| `Slot_ArmR_Weapon_Blade` | Выдвижной хромированный клинок-риппер на правое предплечье |
| `Slot_ArmR_Weapon_Crusher` | Тяжёлый гидравлический молот-крушитель на правую руку (для Танков / Brute) |
| `Slot_ArmR_Weapon_Cannon` | Ствол био-плазменной / кислотной пушки на правое предплечье |

### Е. Кибер-ноги и ботинки (`07_CyberLegsBoots`)
| Имя слота | Описание |
| :--- | :--- |
| `Slot_LegL_CyberStrut` | Левая гидравлическая бионическая нога с амортизатором и 3-палой когтистой стопой (заменяет `Body_Leg_L`) |
| `Slot_LegR_CyberStrut` | Правая гидравлическая бионическая нога с амортизатором и 3-палой когтистой стопой (заменяет `Body_Leg_R`) |
| `Slot_Boot_L` / `Slot_Boot_R` | Высокий кожаный армейский ботинок со стальными ремнями и рифлёной подошвой (для органической ноги) |

---

## 2. Способ 1: Кастомизация прямо в Godot 4 (на лету через GDScript)

В проект уже добавлен скрипт [`scripts/zombie_cyborg_customizer.gd`](file:///c:/Users/user/Documents/идет-караван-из-ирана/scripts/zombie_cyborg_customizer.gd) и модульная модель [`models/zombies/zombie_cyborg_template.glb`](file:///c:/Users/user/Documents/идет-караван-из-ирана/models/zombies/zombie_cyborg_template.glb).

### Пример 1: Спавн одного из 4 готовых пресетов
```gdscript
# Доступные пресеты: "default_walker", "heavy_siege_brute", "toxic_bio_spitter", "dual_blade_stalker"
var cyborg: Node3D = ZombieCyborgCustomizer.instantiate_customized("heavy_siege_brute")
add_child(cyborg)
```

### Пример 2: Случайная генерация уникального зомби-киборга по `seed`
```gdscript
var random_cfg: Dictionary = ZombieCyborgCustomizer.generate_random_config(randi())
var cyborg: Node3D = ZombieCyborgCustomizer.instantiate_customized(random_cfg)
add_child(cyborg)
```

### Пример 3: Своя собственная комбинация одежды, имплантов и цветов
```gdscript
var my_custom_cfg := {
    "organic_limbs": {
        "arm_l": false, # Левая рука — кибер-протез
        "arm_r": false, # Правая рука — кибер-протез
        "leg_l": true,  # Левая нога — органическая (в ботинке)
        "leg_r": false  # Правая нога — кибер-протез
    },
    "slots": [
        "Slot_Head_Visor_Full",
        "Slot_Jaw_Respirator",
        "Slot_Torso_ChestCore_R",
        "Slot_Back_ExoSpine",
        "Slot_Pauldron_L",
        "Slot_ArmL_CyberClaw",
        "Slot_ArmL_Weapon_Blade",
        "Slot_ArmR_CyberClaw",
        "Slot_ArmR_Weapon_Cannon",
        "Slot_Boot_L",
        "Slot_LegR_CyberStrut",
        "Slot_Cloth_RagsHood",
        "Slot_Cloth_CargoPants_Asym",
        "Slot_Cloth_BeltHarness"
    ],
    "colors": {
        "glow_color": Color(0.85, 0.10, 1.0),  # Фиолетовое свечение визора, ядра и пушки
        "skin_tint": Color(0.80, 0.85, 0.90),   # Пепельно-бледная кожа
        "armor_tint": Color(0.35, 0.38, 0.45),  # Тёмный титан
        "shirt_tint": Color(0.45, 0.35, 0.25),  # Пыльно-бурый плащ
        "pants_tint": Color(0.25, 0.28, 0.35)   # Тёмно-серые штаны
    }
}
var cyborg: Node3D = ZombieCyborgCustomizer.instantiate_customized(my_custom_cfg)
add_child(cyborg)
```

---

## 3. Способ 2: Экспорт отдельного `.glb` из JSON-файла через консоль

В папке [`C:\Users\user\ZombieCyborg\presets\`](file:///C:/Users/user/ZombieCyborg/presets) лежат 4 готовых JSON-конфига (`default_walker.json`, `heavy_siege_brute.json`, `toxic_bio_spitter.json`, `dual_blade_stalker.json`).

Вы можете скопировать любой JSON-файл, отредактировать список `"slots"` и `"colors"`, а затем запечь отдельный `.glb` (в котором неиспользуемые слоты будут автоматически удалены) одной командой PowerShell:

```powershell
# Экспорт по имени встроенного пресета:
& "E:\blender\blender.exe" --background --python "c:\Users\user\Documents\идет-караван-из-ирана\tools\zombie_cyborg_template.py" -- --preset heavy_siege_brute --out "C:\Users\user\ZombieCyborg\brute.glb"

# Экспорт по вашему собственному JSON-файлу:
& "E:\blender\blender.exe" --background --python "c:\Users\user\Documents\идет-караван-из-ирана\tools\zombie_cyborg_template.py" -- --config "C:\Users\user\ZombieCyborg\presets\my_custom.json" --out "C:\Users\user\ZombieCyborg\my_custom.glb"
```

---

## 4. Способ 3: Ручное редактирование и добавление новых деталей в Blender

1. Откройте [`C:\Users\user\ZombieCyborg\zombie_cyborg_template.blend`](file:///C:/Users/user/ZombieCyborg/zombie_cyborg_template.blend) в Blender.
2. В правом верхнем окне **Outliner** вы увидите аккуратную структуру коллекций:
   - `01_Rig` (`ZombieRig`)
   - `02_OrganicBody` (`Body_TorsoHead`, `Body_Arm_L/R`, `Body_Leg_L/R`)
   - `03_Clothing` (`Slot_Cloth_*`)
   - `04_HeadImplants` (`Slot_Head_*`, `Slot_Jaw_*`)
   - `05_TorsoBackImplants` (`Slot_Torso_*`, `Slot_Back_*`)
   - `06_CyberArms` (`Slot_Pauldron_*`, `Slot_ArmL_*`, `Slot_ArmR_*`)
   - `07_CyberLegsBoots` (`Slot_LegL_*`, `Slot_LegR_*`, `Slot_Boot_*`)
3. **Как добавить собственную новую деталь (например, новый шлем, шипы или оружие)**:
   - Смоделируйте или импортируйте деталь и расположите её в нужном месте персонажа (в Rest Pose на 1-м кадре).
   - Назовите объект `Slot_<Категория>_<Имя>` (например, `Slot_Head_GasMask`).
   - Добавьте модификатор **Armature** и укажите `Object: ZombieRig`.
   - Создайте на меше группу вершин (**Vertex Group**) с именем кости, к которой крепится деталь (например, `Head`, `Jaw`, `Chest`, `Forearm.L`, `Hand.R`, `Shin.L`), выделите все вершины в Edit Mode и нажмите **Assign** с весом `1.0`.
   - Экспортируйте `File -> Export -> glTF 2.0 (.glb)` — новый слот сразу станет доступен в `ZombieCyborgCustomizer`.
