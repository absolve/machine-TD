# Machine-TD 功能模块设计与更新记录

> 本文档用于记录后续功能模块的设计方案与更新计划，便于独立开发、维护和扩展。
>
> **文档版本**：v1.1
> **创建日期**：2026-08-19
> **适用项目**：Machine-TD（Godot 4.7 塔防游戏）

---

## 目录

- [一、模块设计原则](#一模块设计原则)
- [二、背包系统（Backpack System）](#二背包系统backpack-system)
- [三、成就系统（Achievement System）](#三成就系统achievement-system)
- [四、能力技能系统（Ability / Active Skill System）](#四能力技能系统ability--active-skill-system)
- [五、波次进度条模块（Wave Progress Bar）](#五波次进度条模块wave-progress-bar)
- [六、防御塔升级系统（Tower Upgrade System）](#六防御塔升级系统tower-upgrade-system)
- [七、模块更新记录](#七模块更新记录)
- [八、后续可扩展模块（规划中）](#八后续可扩展模块规划中)

---

## 一、模块设计原则

为保证各功能模块独立、可维护、易扩展，所有新增模块遵循以下原则：

1. **独立 Autoload 单例**：每个模块以 Autoload 单例形式注册（如 `Backpack`、`AchievementManager`），全局可访问，互不耦合。
2. **数据与逻辑分离**：数据使用 `Resource` 脚本承载（符合项目 `userData.gd` 既有风格），便于序列化存档与未来扩展（类似 Spring Data JPA 的实体管理思路）。
3. **信号驱动**：模块对外通过 `signal` 暴露事件（如 `item_used`、`achievement_unlocked`），其它系统监听而非直接调用，降低耦合。
4. **UI 与数据分离**：UI 场景只负责展示，不持有业务状态；所有状态由单例管理。
5. **复用现有基础设施**：
   - 货币：复用 `userData.gem`（宝石/钻石）作为购买货币。
   - 事件：复用 `Game` 单例已有的 `defeatEnemy`、`enemyEscape`、`placeTower`、`sellTower`、`lastWave` 等信号作为成就触发源。
   - 提示：复用 `toast` 插件（`addons/toast/`）展示成就解锁提示。
   - 国际化：所有文案通过 `lang/language.csv` 的 key 引用。
6. **配置即数据**：物品、成就等条目以常量字典 / Resource 列表形式集中声明，新增条目无需改动业务逻辑。

---

## 二、背包系统（Backpack System）

### 2.1 模块定位

玩家使用**钻石（gem）**购买**物品**，物品存放在背包中，可在**战斗内使用**以获得增益或战术效果。模块独立于塔/敌人系统，通过信号与游戏交互。

### 2.2 文件结构

```
machine-td/
├── autoload/
│   └── backpack.gd                 # 背包系统单例（注册为 Autoload: Backpack）
├── script/
│   ├── item_data.gd                # 物品数据 Resource（单条物品定义）
│   ├── item_database.gd            # 物品数据库（所有物品定义集合）
│   └── inventory_item.gd           # 背包槽位 Resource（物品ID + 数量）
└── scene/
    ├── backpack_panel.tscn         # 背包 UI 面板（查看/使用物品）
    └── shop_panel.tscn             # 商店 UI 面板（购买物品）
```

### 2.3 数据结构设计

#### 2.3.1 物品定义 `item_data.gd`（Resource）

```gdscript
extends Resource
class_name ItemData

enum ItemCategory {
    CONSUMABLE,   # 消耗品（战斗内使用）
    MATERIAL,     # 材料（保留扩展，暂不实装）
    CURRENCY      # 货币类（保留扩展）
}

enum UseTarget {
    NONE,         # 无目标（直接生效，如恢复血量）
    TOWER,        # 需点击塔目标
    POSITION      # 需点击地图位置
}

@export var id: int                         # 物品唯一ID
@export var name_key: String                # 名称 i18n key
@export var desc_key: String                # 描述 i18n key
@export var icon: Texture2D                 # 物品图标
@export var category: ItemCategory
@export var use_target: UseTarget = UseTarget.NONE
@export var max_stack: int = 99             # 单格最大堆叠
@export var price: int = 0                  # 购买价格（钻石）
@export var sellable: bool = true           # 是否可出售
@export var use_effect: Dictionary = {}     # 使用效果参数（见 2.4）
```

#### 2.3.2 物品数据库 `item_database.gd`

```gdscript
extends Node
class_name ItemDatabase

# 集中声明所有物品，新增物品只需在此添加条目
const ITEMS: Dictionary = {
    1001: {
        "name_key": "_item_hpPotion_name",
        "desc_key": "_item_hpPotion_desc",
        "icon": preload("res://sprite/item/hp_potion.png"),
        "category": ItemData.ItemCategory.CONSUMABLE,
        "use_target": ItemData.UseTarget.NONE,
        "price": 20,
        "use_effect": {"type": "restore_health", "amount": 5}
    },
    1002: {
        "name_key": "_item_moneyBag_name",
        "desc_key": "_item_moneyBag_desc",
        "icon": preload("res://sprite/item/money_bag.png"),
        "category": ItemData.ItemCategory.CONSUMABLE,
        "use_target": ItemData.UseTarget.NONE,
        "price": 15,
        "use_effect": {"type": "add_money", "amount": 50}
    },
    1003: {
        "name_key": "_item_freezeBomb_name",
        "desc_key": "_item_freezeBomb_desc",
        "icon": preload("res://sprite/item/freeze_bomb.png"),
        "category": ItemData.ItemCategory.CONSUMABLE,
        "use_target": ItemData.UseTarget.NONE,
        "price": 30,
        "use_effect": {"type": "freeze_enemies", "duration": 3.0}
    },
    1004: {
        "name_key": "_item_towerBoost_name",
        "desc_key": "_item_towerBoost_desc",
        "icon": preload("res://sprite/item/tower_boost.png"),
        "category": ItemData.ItemCategory.CONSUMABLE,
        "use_target": ItemData.UseTarget.TOWER,
        "price": 25,
        "use_effect": {"type": "tower_attack_buff", "mult": 2.0, "duration": 8.0}
    }
}
```

#### 2.3.3 背包单例 `backpack.gd`

```gdscript
extends Node

# ===== 信号 =====
signal item_added(item_id: int, count: int)
signal item_removed(item_id: int, count: int)
signal item_used(item_id: int, target)        # target 可能是 null/Tower/Vector2
signal purchase_success(item_id: int)
signal purchase_failed(reason: String)

# ===== 状态 =====
# 背包内容：{ item_id: 数量 }
var _inventory: Dictionary = {}
# 物品数据库缓存
var _item_db: Dictionary = {}

func _ready() -> void:
    _item_db = ItemDatabase.ITEMS.duplicate()

# ===== 查询 =====
func get_item_count(item_id: int) -> int:
    return _inventory.get(item_id, 0)

func get_item_data(item_id: int) -> Dictionary:
    return _item_db.get(item_id, {})

func get_all_items() -> Array:
    return _inventory.keys().filter(func(id): return _inventory[id] > 0)

# ===== 增删 =====
func add_item(item_id: int, count: int = 1) -> void:
    var cur = get_item_count(item_id)
    var data = get_item_data(item_id)
    var max_stack = data.get("max_stack", 99)
    _inventory[item_id] = clampi(cur + count, 0, max_stack)
    item_added.emit(item_id, count)
    save()

func remove_item(item_id: int, count: int = 1) -> bool:
    var cur = get_item_count(item_id)
    if cur < count:
        return false
    _inventory[item_id] = cur - count
    item_removed.emit(item_id, count)
    save()
    return true

# ===== 购买 =====
func buy_item(item_id: int, count: int = 1) -> void:
    var data = get_item_data(item_id)
    if data.is_empty():
        purchase_failed.emit("item_not_found")
        return
    var total_cost = data.get("price", 0) * count
    if UserData.gem < total_cost:                # 复用 userData.gem
        purchase_failed.emit("not_enough_gem")
        return
    UserData.gem -= total_cost
    add_item(item_id, count)
    purchase_success.emit(item_id)

# ===== 使用（战斗内） =====
func use_item(item_id: int, target = null) -> bool:
    if get_item_count(item_id) <= 0:
        return false
    var data = get_item_data(item_id)
    if not _validate_target(data, target):
        return false
    _apply_effect(data.get("use_effect", {}), target)
    remove_item(item_id, 1)
    item_used.emit(item_id, target)
    return true

# ===== 效果应用 =====
func _apply_effect(effect: Dictionary, target) -> void:
    match effect.get("type", ""):
        "restore_health":
            Game.map.add_health(effect.get("amount", 0))   # 需 map 暴露 add_health
        "add_money":
            Game.map.add_money(effect.get("amount", 0))
        "freeze_enemies":
            Game.map.freeze_all_enemies(effect.get("duration", 3.0))
        "tower_attack_buff":
            target.apply_buff("atk_mult", effect.get("mult", 1.0), effect.get("duration", 0.0))

# ===== 存档 =====
const SAVE_PATH = "user://backpack_save.tres"
func save() -> void:
    var res = Resource.new()
    # 使用 userData 同样的序列化思路（或转为 JSON/Dictionary 保存）
    # 略：序列化 _inventory
func load() -> void:
    # 略：反序列化 _inventory
    pass
```

### 2.4 物品效果类型

| 效果类型            | 作用对象   | 说明                            |
| ------------------- | ---------- | ------------------------------- |
| `restore_health`    | 无目标     | 恢复玩家生命值                  |
| `add_money`         | 无目标     | 立即获得金币                    |
| `freeze_enemies`    | 无目标     | 冻结全场敌人若干秒              |
| `tower_attack_buff` | 塔         | 提升指定塔攻击力若干秒          |
| `speed_up_reload`   | 塔         | 提升指定塔射速若干秒            |
| `nuke`              | 位置       | 对点击位置范围伤害              |

### 2.5 UI 设计

#### 2.5.1 背包面板 `backpack_panel.tscn`

- **入口**：战斗内 HUD 新增"背包"按钮；主菜单 `welcome.tscn` 增加背包入口。
- **布局**：`Panel` + `GridContainer` 网格（每格 = 图标 + 数量徽标）。
- **交互**：
  - 点击物品：弹出 tooltip 显示名称/描述/使用方式。
  - 战斗内点击"使用"按钮 → 进入目标选择模式（根据 `use_target`）→ 选定后调用 `Backpack.use_item(id, target)`。
  - 非战斗场景仅可查看，禁用使用按钮。

#### 2.5.2 商店面板 `shop_panel.tscn`

- **入口**：主菜单 / 战斗准备界面新增"商店"按钮。
- **布局**：物品列表（图标 + 名称 + 价格 + 购买按钮），顶部显示当前宝石数量（监听 `UserData.gem` 变化）。
- **交互**：点击购买 → `Backpack.buy_item(id)` → 监听 `purchase_success` / `purchase_failed` 显示 toast 反馈。

### 2.6 集成点

| 集成点                  | 修改文件                | 说明                                                |
| ----------------------- | ----------------------- | --------------------------------------------------- |
| Autoload 注册           | `project.godot`         | 添加 `Backpack="*res://autoload/backpack.gd"`        |
| 宝石货币                | `userData.gd`           | 复用 `gem` 字段，需暴露 setter 并发信号 `gem_changed`|
| 战斗 HUD 背包按钮       | `map.tscn` / `map.gd`   | 新增按钮 + 快捷键（如 B）打开背包                    |
| 主菜单入口              | `welcome.tscn`          | 新增"背包""商店"按钮                                 |
| map 能力扩展            | `map.gd`                | 新增 `add_health`/`add_money`/`freeze_all_enemies`   |
| 塔 buff 接口            | `tower.gd`              | 新增 `apply_buff(type, mult, duration)`              |

---

## 三、成就系统（Achievement System）

### 3.1 模块定位

玩家在游戏中达成特定条件后**自动解锁成就**，解锁瞬间在游戏内**弹出提示**（复用 toast）。玩家可在专门的成就面板**查看所有成就及获得情况**。模块独立，通过监听 `Game` 已有信号驱动。

### 3.2 文件结构

```
machine-td/
├── autoload/
│   └── achievement_manager.gd     # 成就系统单例（注册为 Autoload: AchievementManager）
├── script/
│   ├── achievement_data.gd       # 成就定义 Resource
│   └── achievement_database.gd   # 成就数据库（所有成就定义）
└── scene/
    └── achievement_panel.tscn    # 成就查看面板
```

### 3.3 数据结构设计

#### 3.3.1 成就定义 `achievement_data.gd`（Resource）

```gdscript
extends Resource
class_name AchievementData

enum AchievementType {
    KILL_COUNT,        # 累计击杀数
    WAVE_CLEAR,        # 通关波次
    TOWER_PLACE,       # 累计放置塔数
    TOWER_SELL,        # 累计出售塔数
    NO_LEAK,           # 单关无敌人逃脱
    FAST_CLEAR,        # 快速通关
    GEM_EARN,          # 累计获得宝石
    SPECIAL            # 特殊成就（自定义条件）
}

enum AchievementTier {
    BRONZE, SILVER, GOLD, PLATINUM
}

@export var id: String                       # 成就唯一ID（字符串便于阅读）
@export var name_key: String                 # 名称 i18n key
@export var desc_key: String                 # 描述 i18n key
@export var icon: Texture2D
@export var type: AchievementType
@export var tier: AchievementTier
@export var target_value: int                # 达成目标值
@export var hidden: bool = false             # 是否为隐藏成就（未解锁前显示"???"）
@export var reward_gem: int = 0               # 解锁奖励（钻石）
```

#### 3.3.2 成就数据库 `achievement_database.gd`

```gdscript
extends Node
class_name AchievementDatabase

const ACHIEVEMENTS: Array = [
    {
        "id": "ach_kill_100",
        "name_key": "_ach_kill_100_name",
        "desc_key": "_ach_kill_100_desc",
        "type": AchievementData.AchievementType.KILL_COUNT,
        "tier": AchievementData.AchievementTier.BRONZE,
        "target_value": 100,
        "reward_gem": 10
    },
    {
        "id": "ach_kill_1000",
        "name_key": "_ach_kill_1000_name",
        "desc_key": "_ach_kill_1000_desc",
        "type": AchievementData.AchievementType.KILL_COUNT,
        "tier": AchievementData.AchievementTier.SILVER,
        "target_value": 1000,
        "reward_gem": 50
    },
    {
        "id": "ach_no_leak_stage1",
        "name_key": "_ach_no_leak_stage1_name",
        "desc_key": "_ach_no_leak_stage1_desc",
        "type": AchievementData.AchievementType.NO_LEAK,
        "tier": AchievementData.AchievementTier.GOLD,
        "target_value": 1,
        "reward_gem": 30
    },
    {
        "id": "ach_laser_lover",
        "name_key": "_ach_laser_lover_name",
        "desc_key": "_ach_laser_lover_desc",
        "type": AchievementData.AchievementType.TOWER_PLACE,
        "tier": AchievementData.AchievementTier.BRONZE,
        "target_value": 10,
        "reward_gem": 15,
        "extra": {"tower_type": "laserTower"}   # 附加条件：激光塔放置10次
    }
]
```

#### 3.3.3 成就管理器 `achievement_manager.gd`

```gdscript
extends Node

# ===== 信号 =====
signal achievement_unlocked(ach_id: String)
signal progress_updated(ach_id: String, current: int, target: int)

# ===== 状态 =====
var _progress: Dictionary = {}        # { ach_id: 当前进度值 }
var _unlocked: Dictionary = {}       # { ach_id: true } 已解锁集合
var _db: Array = []

func _ready() -> void:
    _db = AchievementDatabase.ACHIEVEMENTS.duplicate(true)
    load()
    _connect_game_signals()

# ===== 信号监听（复用 Game 单例已有信号） =====
func _connect_game_signals() -> void:
    Game.defeatEnemy.connect(_on_defeat_enemy)
    Game.placeTower.connect(_on_place_tower)
    Game.sellTower.connect(_on_sell_tower)
    Game.enemyEscape.connect(_on_enemy_escape)
    Game.lastWave.connect(_on_last_wave)

func _on_defeat_enemy() -> void:
    _add_progress_by_type(AchievementData.AchievementType.KILL_COUNT, 1)

func _on_place_tower(tower_type: int) -> void:
    _add_progress_by_type(AchievementData.AchievementType.TOWER_PLACE, 1, {"tower_type": tower_type})

func _on_sell_tower() -> void:
    _add_progress_by_type(AchievementData.AchievementType.TOWER_SELL, 1)

func _on_enemy_escape() -> void:
    # 标记本关已漏怪，用于 NO_LEAK 判定
    _stage_leaked = true

func _on_last_wave() -> void:
    if not _stage_leaked:
        _add_progress_by_type(AchievementData.AchievementType.NO_LEAK, 1)
    # 通关波次进度 +1
    _add_progress_by_type(AchievementData.AchievementType.WAVE_CLEAR, 1)

# ===== 进度推进 =====
func _add_progress_by_type(type: int, amount: int, extra: Dictionary = {}) -> void:
    for ach in _db:
        if ach.get("type") != type:
            continue
        if _unlocked.get(ach["id"], false):
            continue
        if extra.is_empty() and ach.has("extra"):
            continue   # 需要附加条件的成就，跳过通用推进
        if not extra.is_empty() and ach.get("extra", {}) != extra:
            continue
        _progress[ach["id"]] = _progress.get(ach["id"], 0) + amount
        progress_updated.emit(ach["id"], _progress[ach["id"]], ach["target_value"])
        if _progress[ach["id"]] >= ach["target_value"]:
            _unlock(ach["id"])

# ===== 解锁 =====
func _unlock(ach_id: String) -> void:
    if _unlocked.get(ach_id, false):
        return
    _unlocked[ach_id] = true
    achievement_unlocked.emit(ach_id)
    # 发放钻石奖励
    var ach = _get_ach(ach_id)
    if ach.get("reward_gem", 0) > 0:
        UserData.gem += ach["reward_gem"]
    save()
    # 复用 toast 弹出解锁提示
    Toast.show(Tr.tr(ach["name_key"]) + " " + Tr.tr("_achievement_unlocked_suffix"))

func _get_ach(ach_id: String) -> Dictionary:
    for ach in _db:
        if ach["id"] == ach_id:
            return ach
    return {}

# ===== 查询（供 UI 使用） =====
func get_all_achievements() -> Array:
    return _db

func is_unlocked(ach_id: String) -> bool:
    return _unlocked.get(ach_id, false)

func get_progress(ach_id: String) -> int:
    return _progress.get(ach_id, 0)

# ===== 存档 =====
const SAVE_PATH = "user://achievement_save.tres"
func save() -> void:
    # 序列化 _progress 与 _unlocked
    pass
func load() -> void:
    # 反序列化
    pass
```

### 3.4 成就类型与触发源映射

| 成就类型        | 触发信号（Game 单例） | 说明                          |
| --------------- | --------------------- | ----------------------------- |
| `KILL_COUNT`    | `defeatEnemy`         | 每次击败敌人 +1               |
| `TOWER_PLACE`   | `placeTower`          | 每次放塔 +1（可限定塔类型）   |
| `TOWER_SELL`    | `sellTower`           | 每次出售塔 +1                 |
| `WAVE_CLEAR`    | `lastWave`            | 通关一关 +1                   |
| `NO_LEAK`       | `enemyEscape` / `lastWave` | 本关未漏怪才算达成       |
| `FAST_CLEAR`    | `lastWave` + 计时     | 在限定时间内通关              |
| `GEM_EARN`      | `UserData.gem_changed` | 累计获得宝石数               |
| `SPECIAL`       | 自定义                | 如"放置3种不同塔"、"使用背包物品5次"等 |

### 3.5 UI 设计

#### 3.5.1 成就面板 `achievement_panel.tscn`

- **入口**：主菜单 `welcome.tscn` 新增"成就"按钮。
- **布局**：
  - 顶部：进度概览（已解锁 X / 总数 Y），进度条。
  - 主体：`ScrollContainer` + `VBoxContainer`，逐条列出成就卡片。
  - 成就卡片：图标（未解锁且 hidden 时显示问号占位） + 名称 + 描述 + 进度条（`当前/目标`）+ 奖励图标 + 勾/锁状态。
- **交互**：纯查看，无操作。点击卡片可放大图标查看详情。

#### 3.5.2 游戏内解锁提示

- 复用 `addons/toast/` 插件，在 `_unlock()` 中调用 `Toast.show()`。
- 提示内容：`【成就名称】 已解锁`，停留 2~3 秒自动消失。
- 可选：播放简短音效（复用 `sound/`）。

### 3.6 集成点

| 集成点            | 修改文件                | 说明                                                              |
| ----------------- | ----------------------- | ----------------------------------------------------------------- |
| Autoload 注册     | `project.godot`         | 添加 `AchievementManager="*res://autoload/achievement_manager.gd"` |
| 主菜单入口        | `welcome.tscn`          | 新增"成就"按钮                                                     |
| 信号监听          | 无需改动 `game.gd`      | 直接在 `_ready()` 连接已有信号                                     |
| 宝石奖励发放      | `userData.gd`           | 复用 `gem` 字段，建议增加 `gem_changed` 信号                       |
| 文案              | `lang/language.csv`     | 添加成就名称/描述的 i18n key                                      |
| 隐藏成就图标占位  | `sprite/`               | 新增问号占位图（或复用 `interrogation.png`）                      |

---

## 四、能力技能系统（Ability / Active Skill System）

### 4.1 模块定位

玩家在战斗中可使用两种**主动能力**，能力图标直接显示在 `map.tscn` 界面上（HUD 区域），点击后进入"选择目标/区域"模式生效。每次使用后进入**冷却时间**，冷却结束方可再次使用。模块独立于塔/敌人系统，通过信号驱动 UI 刷新与效果应用。

### 4.2 能力列表

| 能力 ID            | 名称       | 效果说明                                          | 目标类型   | 冷却时间（秒） | 建议图标             |
| ------------------ | ---------- | ------------------------------------------------- | ---------- | -------------- | ------------------- |
| `ability_bombard`  | 区域轰炸   | 玩家点击地图一个区域，对区域内所有敌人造成大量伤害 | 地图位置   | 30             | `sprite/bomb.png`   |
| `ability_shield`   | 防御塔无敌 | 玩家点击一座防御塔，使其在持续时间内无敌           | 塔         | 45             | `sprite/shield.png` |

### 4.3 文件结构

```
machine-td/
├── autoload/
│   └── ability_manager.gd          # 能力系统单例（注册为 Autoload: AbilityManager）
├── script/
│   ├── ability_data.gd            # 能力定义 Resource
│   └── ability_indicator.gd       # 目标选择指示器（鼠标跟随/范围预览）
└── scene/
    └── ability_bar.tscn           # 能力 UI 条（两个图标 + 冷却遮罩）
```

### 4.4 数据结构设计

#### 4.4.1 能力定义 `ability_data.gd`（Resource）

```gdscript
extends Resource
class_name AbilityData

enum TargetType {
    NONE,         # 无目标（立即生效）
    POSITION,     # 点击地图位置
    TOWER         # 点击防御塔
}

@export var id: String                         # 能力唯一ID
@export var name_key: String                   # 名称 i18n key
@export var desc_key: String                   # 描述 i18n key
@export var icon: Texture2D                    # 能力图标
@export var target_type: TargetType
@export var cooldown: float = 30.0             # 冷却时间（秒）
@export var effect: Dictionary = {}            # 效果参数（见 4.5）
@export var hotkey: int = -1                   # 快捷键（-1 表示无，如 KEY_Q / KEY_W）
```

#### 4.4.2 能力管理器 `ability_manager.gd`

```gdscript
extends Node

# ===== 信号 =====
signal ability_started(ability_id: String)            # 开始选择目标
signal ability_activated(ability_id: String, target)   # 已生效
signal ability_cooldown_started(ability_id: String, duration: float)
signal ability_cooldown_ended(ability_id: String)
signal ability_canceled(ability_id: String)            # 玩家取消选择

# ===== 能力定义（集中声明，便于扩展） =====
const ABILITIES: Array = [
    {
        "id": "ability_bombard",
        "name_key": "_ability_bombard_name",
        "desc_key": "_ability_bombard_desc",
        "icon": preload("res://sprite/bomb.png"),
        "target_type": AbilityData.TargetType.POSITION,
        "cooldown": 30.0,
        "effect": {
            "type": "area_damage",
            "radius": 128.0,
            "damage": 200
        },
        "hotkey": KEY_Q
    },
    {
        "id": "ability_shield",
        "name_key": "_ability_shield_name",
        "desc_key": "_ability_shield_desc",
        "icon": preload("res://sprite/shield.png"),
        "target_type": AbilityData.TargetType.TOWER,
        "cooldown": 45.0,
        "effect": {
            "type": "tower_invincible",
            "duration": 8.0
        },
        "hotkey": KEY_W
    }
]

# ===== 状态 =====
var _cooldowns: Dictionary = {}          # { ability_id: 剩余秒数 }
var _selecting_ability: String = ""     # 当前正在选择目标的能力ID（空表示未在选择中）

func _ready() -> void:
    load()
    set_process(true)

func _process(delta: float) -> void:
    # 冷却倒计时
    for id in _cooldowns.keys():
        if _cooldowns[id] > 0:
            _cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
            if _cooldowns[id] == 0.0:
                ability_cooldown_ended.emit(id)

# ===== 查询 =====
func get_ability_data(ability_id: String) -> Dictionary:
    for a in ABILITIES:
        if a["id"] == ability_id:
            return a
    return {}

func is_ready(ability_id: String) -> bool:
    return _cooldowns.get(ability_id, 0.0) <= 0.0

func get_cooldown_remaining(ability_id: String) -> float:
    return _cooldowns.get(ability_id, 0.0)

func get_cooldown_ratio(ability_id: String) -> float:
    # 0=就绪可点，1=刚释放。供 UI 绘制冷却遮罩
    var data = get_ability_data(ability_id)
    var cd = data.get("cooldown", 1.0)
    return clampf(_cooldowns.get(ability_id, 0.0) / cd, 0.0, 1.0) if cd > 0 else 0.0

# ===== 触发流程 =====
func try_activate(ability_id: String) -> void:
    if not is_ready(ability_id):
        ability_canceled.emit(ability_id)
        return
    var data = get_ability_data(ability_id)
    match data.get("target_type"):
        AbilityData.TargetType.NONE:
            _activate(ability_id, null)
        AbilityData.TargetType.POSITION, AbilityData.TargetType.TOWER:
            _selecting_ability = ability_id
            ability_started.emit(ability_id)   # 进入选择模式（由 map/ui 显示指示器）

# 玩家选定目标后由 map/ui 调用
func confirm_target(target) -> void:
    if _selecting_ability == "":
        return
    var id = _selecting_ability
    _selecting_ability = ""
    _activate(id, target)

# 玩家取消（右键 / ESC / 再次点击图标）
func cancel_selecting() -> void:
    if _selecting_ability != "":
        var id = _selecting_ability
        _selecting_ability = ""
        ability_canceled.emit(id)

# ===== 生效 =====
func _activate(ability_id: String, target) -> void:
    var data = get_ability_data(ability_id)
    _apply_effect(data.get("effect", {}), target)
    _cooldowns[ability_id] = data.get("cooldown", 0.0)
    ability_cooldown_started.emit(ability_id, _cooldowns[ability_id])
    ability_activated.emit(ability_id, target)
    save()

# ===== 效果应用（依赖 map.gd / tower.gd 接口） =====
func _apply_effect(effect: Dictionary, target) -> void:
    match effect.get("type"):
        "area_damage":
            Game.map.area_damage(target, effect.get("radius", 128.0), effect.get("damage", 100))
        "tower_invincible":
            target.set_invincible(true, effect.get("duration", 5.0))

# ===== 存档 =====
const SAVE_PATH = "user://ability_save.tres"
func save() -> void:
    # 序列化 _cooldowns（通常不必持久化，每次开战重置）
    pass
func load() -> void:
    pass
```

### 4.5 能力效果类型

| 效果类型            | 适用能力   | 作用对象 | 依赖接口（需在 map.gd / tower.gd 实现）         |
| ------------------- | ---------- | -------- | ----------------------------------------------- |
| `area_damage`       | 区域轰炸   | 地图位置 | `map.area_damage(pos: Vector2, radius: float, damage: int)` |
| `tower_invincible`  | 防御塔无敌 | 塔       | `tower.set_invincible(flag: bool, duration: float)`          |

> 设计说明：能力效果应用统一通过 `Game.map` 与 `tower` 暴露的方法调用，能力系统不直接操作敌人/塔内部数据，保持模块边界清晰。

### 4.6 UI 设计

#### 4.6.1 能力条 `ability_bar.tscn`

- **位置**：作为 `map.tscn` 中 `hud` 的子节点，固定在屏幕右下角（或左下角），与 `towerUI` 并列。
- **结构**：`HBoxContainer` 包含两个 `TextureButton`（轰炸图标 + 无敌图标），每个按钮叠加：
  - 冷却遮罩：`TextureProgressBar` 或 `ColorRect`（半透明黑），`fill_mode = 自下而上`，`value = (1 - cooldown_ratio) * 100`。
  - 冷却数字：`Label` 显示剩余秒数（取整）。
  - 就绪高亮：冷却结束时图标恢复全亮 + 可选脉冲动画提示。
- **状态联动**：
  - 监听 `AbilityManager.ability_started`：开始选择目标时，图标按钮显示按下态。
  - 监听 `AbilityManager.ability_cooldown_started/ended`：更新遮罩与可用状态。
  - 监听 `AbilityManager.ability_canceled`：恢复按钮常态。

#### 4.6.2 目标选择交互

- **进入选择模式**（`ability_started` 触发）：
  - `POSITION` 类型：鼠标跟随显示半透明圆形预览（半径 = 效果 `radius`），左键确认位置，右键取消。
  - `TOWER` 类型：鼠标悬停塔时高亮该塔，左键确认目标塔，右键取消。
- **确认/取消**：
  - 确认 → 调用 `AbilityManager.confirm_target(target)`。
  - 取消 → 调用 `AbilityManager.cancel_selecting()`。
- **快捷键**：支持 `Q`（轰炸）/ `W`（无敌）直接触发对应能力（见 `ability_data.hotkey`）。

### 4.7 集成点

| 集成点               | 修改文件                | 说明                                                                 |
| -------------------- | ----------------------- | -------------------------------------------------------------------- |
| Autoload 注册        | `project.godot`        | 添加 `AbilityManager="*res://autoload/ability_manager.gd"`           |
| 能力 UI 显示         | `map.tscn` / `map.gd`   | 在 `hud` 下挂载 `ability_bar.tscn`，连接信号刷新 UI                  |
| 目标选择处理         | `map.gd`                | `_unhandled_input` 中检测选择模式，捕获鼠标位置/悬停塔，调用确认接口 |
| 范围伤害接口         | `map.gd`                | 新增 `area_damage(pos, radius, damage)`：遍历 enemy 组造成伤害       |
| 塔无敌接口           | `tower.gd`              | 新增 `set_invincible(flag, duration)`：禁用受击/计时自动恢复         |
| 快捷键               | `map.gd` / `ability_bar.gd` | `_input` 中监听 Q/W 调用 `AbilityManager.try_activate`           |
| 文案                 | `lang/language.csv`     | 添加能力名称/描述 i18n key                                           |
| 图标资源             | `sprite/`              | 已有 `bomb.png`、`shield.png` 可复用                                 |

### 4.8 冷却时间设计说明

- **冷却独立计算**：两个能力各自独立冷却，互不影响。
- **冷却不持久化**：冷却时间仅战斗内有效，关卡结束/重开时重置（`_ready` 时清空 `_cooldowns`）。
- **UI 反馈三态**：
  1. 就绪：图标全亮，悬停显示 tooltip（名称/描述/快捷键）。
  2. 选择中：图标按下态，鼠标跟随指示器。
  3. 冷却中：图标变暗 + 遮罩从下往上消退 + 倒计时数字。

---

## 五、波次进度条模块（Wave Progress Bar）

### 5.1 模块定位（植物大战僵尸风格 · 极简版）

参考《植物大战僵尸》关卡底部的进度条：

- **一条长进度条**放在 `map.tscn` **右下角**，条内只有**几个阶段旗帜**（小旗子，不区分类型）。
- **起点 = 当前关卡**图标（或小旗帜），**终点 = BOSS 脸图标**，中间按 3 等分位置放若干阶段旗。
- 小车头（或小图标）沿进度条从起点移动到终点，表示当前波次进度。
- **无 tooltip、无分类、无动效**，只做一眼能看懂的进度展示。

### 5.2 文件结构

```
machine-td/
├── script/
│   └── wave_progress_bar.gd
└── scene/
    └── wave_progress_bar.tscn
```

### 5.3 极简数据配置

不在 stage 里写 `key_waves`。**每关只有 3 个阶段旗**，由脚本按总波数均匀计算位置（1/3、2/3、终点 BOSS）：

```gdscript
# wave_progress_bar.gd
@export var flag_count: int = 3  # 中间阶段旗数量，默认 3（植物大战僵尸即 3 段）
# 位置自动计算：
#   阶段 1 = ceil(total * 0.33)
#   阶段 2 = ceil(total * 0.66)
#   BOSS   = total（终点）
```

### 5.4 UI 场景结构（简单）

```
wave_progress_bar   Control, size=420x64, 锚右下, script=wave_progress_bar.gd
 └─ bar_bg          Panel, 半透明深灰底, size=400x16, position=(10,28), 圆角 4
     └─ bar_fill    Panel, 青绿渐变填充, size=0x16, 圆角 4, 宽度随进度 Tween
     └─ start_icon  TextureRect, position=(-24, -8), size=32x32, 关卡小图标
     └─ flag_1      TextureRect, position=(?, -8), 32x32, 阶段小旗
     └─ flag_2      TextureRect, position=(?, -8), 32x32, 阶段小旗
     └─ boss_icon   TextureRect, position=(392, -20), 48x48, BOSS 脸/终点旗
     └─ cart        TextureRect, position=(?, -4), 40x24, 小推车车头(当前进度)
```

### 5.5 脚本 `wave_progress_bar.gd`（极简）

```gdscript
extends Control

@onready var bar_bg = $bar_bg
@onready var bar_fill = $bar_bg/bar_fill
@onready var cart = $bar_bg/cart
@onready var flag_1 = $bar_bg/flag_1
@onready var flag_2 = $bar_bg/flag_2
@onready var boss_icon = $bar_bg/boss_icon
@onready var start_icon = $bar_bg/start_icon

var _total: int = 0
var _tween: Tween

# 每关开始调用一次
func setup(total_wave: int) -> void:
	_total = maxi(total_wave, 1)
	# 两个阶段旗按 1/3、2/3 放置
	var w: float = bar_bg.size.x
	flag_1.position.x = roundi(w * 0.33) - flag_1.size.x * 0.5
	flag_2.position.x = roundi(w * 0.66) - flag_2.size.x * 0.5
	boss_icon.position.x = w - boss_icon.size.x * 0.5
	# 初始进度 0
	_refresh(0, false)

# 每波开始推进（currWave 从 1..total）
func set_wave(wave: int) -> void:
	_refresh(clampf(float(wave) / float(_total), 0.0, 1.0), true)

func _refresh(ratio: float, animate: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var bar_w: float = bar_bg.size.x
	# 进度条宽度
	var target_fill_w: float = bar_w * ratio
	if animate:
		_tween = create_tween().set_parallel(true)
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(bar_fill, "size:x", target_fill_w, 0.3)
		# 小车头沿条移动（车头中心位置 = 进度 - 半车宽）
		var cart_x: float = bar_w * ratio - cart.size.x * 0.5
		_tween.tween_property(cart, "position:x", cart_x, 0.3)
	else:
		bar_fill.size.x = target_fill_w
		cart.position.x = bar_w * ratio - cart.size.x * 0.5
```

### 5.6 集成点（2 处调用，1 处挂载）

| 集成点 | 修改位置 | 代码 |
|--------|---------|------|
| 挂载 | `map.tscn` `hud/` 下 | 拖 `wave_progress_bar.tscn`，命名 `waveProgress`，锚右下，`margin=(right=-32, bottom=-32)` |
| 引用 | `map.gd` | `@onready var wave_progress = $hud/waveProgress` |
| 初始化 | `base_level.gd` `_ready()` 末尾 | `if Game.map: Game.map.wave_progress.setup(wave)` |
| 推进 | `base_level.gd` `_on_wave_timer_timeout()` 中 `currWave += 1` 后 | `if Game.map: Game.map.wave_progress.set_wave(currWave)` |

### 5.7 视觉示意（植物大战僵尸风格）

```
    ┌─────────────────────────────────────────────────┐
    │                                                 │
    │ 🏴 ░░░░░░░█ ████▒▒▒░░ ▼ ░░░░🏴░░░░░░░░░ 💀     │
    │   ↑         ╱车╲                   ↑            │
    │ 起点旗   小推车(当前)           BOSS终点        │
    │           10 / 20 波                             │
    └─────────────────────────────────────────────────┘
```

- 条中两个 🏴 阶段旗只做"视觉锚点"，不带分类和文字。
- 小推车沿条走，和进度条一起移动，Tween 0.3s 平滑。
- 不做 tooltip、不做脉冲动画、不做关键波高亮，保持极简。

---

## 六、防御塔升级系统（Tower Upgrade System）

### 6.1 模块定位

防御塔通过**击败敌人积累经验值**自动升级，**无需玩家手动操作**。每座塔共 **3 个等级**（Lv.1 初始 → Lv.2 → Lv.3 满级），即 **2 次升级**。升级后塔的攻击力、射程、射速等属性提升，并伴随视觉变化与提示。

**核心设计要点**：
- **击杀归属**：子弹携带来源塔引用，敌人死亡时将经验值结算给"完成击杀"的那座塔。
- **配置即数据**：每种塔类型的升级数值（经验阈值、属性倍率）集中声明在数据资源中，新增塔类型只需添加条目。
- **状态归属实例**：等级与经验值是每座塔实例自身的状态，存于 `tower.gd`；全局配置与查询由单例 `TowerUpgradeManager` 提供。

### 6.2 文件结构

```
machine-td/
├── autoload/
│   └── tower_upgrade_manager.gd   # 升级系统单例（注册为 Autoload: TowerUpgradeManager）
├── script/
│   └── tower_upgrade_data.gd      # 升级配置 Resource（单塔类型配置）
└── scene/
    └── (复用现有 tower.tscn 各塔场景，新增 level_badge 子节点)
```

> 不新增独立 UI 场景，等级展示直接挂载到塔自身节点上（见 6.6）。

### 6.3 击杀归属改造（关键改动）

当前 `enemy.hurt(damage)` 不感知攻击者，`Game.defeatEnemy` 也是全局广播。为使"击杀者"获得经验，采用**子弹携带来源塔**方案：

#### 6.3.1 子弹扩展 `bullet.gd`

```gdscript
extends Area2D

var vec = Vector2.ZERO
var target = null
var timer = 0
var lifetime = 0
var angle = 0
var damage = 0
var speed = 0
var source_tower: Tower = null    # 新增：发射该子弹的塔引用（可能为 null，兼容无主伤害）
```

#### 6.3.2 塔 `fire()` 注入来源

每个塔子类的 `fire(t)` 中实例化子弹后追加一行（以 `cannon_tower.gd` 为例）：

```gdscript
func fire(t):
    if canShot:
        player.play("fire")
        var temp = bullet.instantiate()
        temp.position = marker.global_position
        temp.angle = position.direction_to(t.global_position).angle()
        temp.source_tower = self          # 新增：归属到本塔
        Game.addObj(temp)
        canShot = false
        delayTimer.start()
```

> 所有塔子类（`machineGunTower`/`cannon_tower`/`rocket_tower`/`laser_tower`/`tesla_coil_tower` 等）的 `fire()` 均按此追加一行。
> 对激光/电塔等"无子弹瞬时伤害"类型：在直接调用 `enemy.hurt(damage, self)` 时把 `self` 作为第二参数传入即可。

#### 6.3.3 敌人 `hurt()` 接受来源

`enemy.gd` 基类改为：

```gdscript
func hurt(_num, _source = null):
    pass
```

子类（如 `mini_tank.gd`）改为：

```gdscript
func hurt(_num, _source = null):
    hp -= _num
    lifeBar.value = hp
    if hp < 0:
        ExplosionManage.playExplosion(global_position)
        Game.defeatEnemy.emit(reward)
        if _source is Tower:                       # 新增：归属经验
            _source.add_exp(_get_exp_reward())
        owner.queue_free()

func _get_exp_reward() -> int:
    # 经验值可复用 reward，也可单独配置
    return reward
```

> 子弹击中处 `i.hurt(damage)` 改为 `i.hurt(damage, source_tower)`，向后兼容（默认 `null` 表示无主伤害，不结算经验）。

### 6.4 数据结构设计

#### 6.4.1 升级配置 `tower_upgrade_data.gd`（Resource）

```gdscript
extends Resource
class_name TowerUpgradeData

@export var tower_type: int                   # 对应 Game.towerType 枚举值
@export var xp_to_lv2: int = 5                # Lv1 → Lv2 所需经验
@export var xp_to_lv3: int = 15               # Lv2 → Lv3 所需经验（累计）

# 各等级属性倍率（Lv1 = 1.0 基准）
@export var lv2_atk_mult: float = 1.5
@export var lv2_radar_mult: float = 1.2
@export var lv2_reload_mult: float = 0.85     # <1 表示射速变快（delay 变小）

@export var lv3_atk_mult: float = 2.2
@export var lv3_radar_mult: float = 1.4
@export var lv3_reload_mult: float = 0.7
```

#### 6.4.2 升级管理器 `tower_upgrade_manager.gd`

```gdscript
extends Node

# ===== 信号 =====
signal tower_leveled_up(tower, new_level: int)

# ===== 配置（集中声明，按 Game.towerType 枚举值索引） =====
const CONFIGS: Dictionary = {
    Game.towerType.machineGunTower: {
        "xp_to_lv2": 6, "xp_to_lv3": 18,
        "lv2": {"atk": 1.5, "radar": 1.2, "reload": 0.85},
        "lv3": {"atk": 2.2, "radar": 1.4, "reload": 0.7}
    },
    Game.towerType.cannonTower: {
        "xp_to_lv2": 4, "xp_to_lv3": 12,
        "lv2": {"atk": 1.6, "radar": 1.15, "reload": 0.85},
        "lv3": {"atk": 2.4, "radar": 1.3, "reload": 0.7}
    },
    Game.towerType.laserTower: {
        "xp_to_lv2": 5, "xp_to_lv3": 15,
        "lv2": {"atk": 1.5, "radar": 1.2, "reload": 0.9},
        "lv3": {"atk": 2.0, "radar": 1.4, "reload": 0.8}
    }
    # 其余塔类型按需追加，未配置的塔类型不会升级（保持 Lv1）
}

const MAX_LEVEL: int = 3

# ===== 查询 =====
func get_config(tower_type: int) -> Dictionary:
    return CONFIGS.get(tower_type, {})

func get_xp_threshold(tower_type: int, current_level: int) -> int:
    var cfg = get_config(tower_type)
    if cfg.is_empty():
        return INF   # 无配置则永远升不上去
    match current_level:
        1: return cfg.get("xp_to_lv2", INF)
        2: return cfg.get("xp_to_lv3", INF)
        _: return INF

func get_mults(tower_type: int, level: int) -> Dictionary:
    var cfg = get_config(tower_type)
    if cfg.is_empty() or level < 2:
        return {"atk": 1.0, "radar": 1.0, "reload": 1.0}
    return cfg.get("lv" + str(level), {"atk": 1.0, "radar": 1.0, "reload": 1.0})
```

#### 6.4.3 塔基类扩展 `tower.gd`

```gdscript
# ===== 升级状态（实例自身持有） =====
var level: int = 1
var exp: int = 0
# 记录初始值用于倍率计算
var _base_atk: int = 0
var _base_radar: float = 0.0
var _base_delay: float = 0.1

func _ready() -> void:
    # ... 既有初始化 ...
    _base_atk = atk
    _base_radar = radarScope
    _base_delay = delay

# ===== 经验积累与升级 =====
func add_exp(amount: int) -> void:
    if level >= TowerUpgradeManager.MAX_LEVEL:
        return
    if TowerUpgradeManager.get_config(_get_tower_type()).is_empty():
        return   # 该塔类型无升级配置
    exp += amount
    var threshold = TowerUpgradeManager.get_xp_threshold(_get_tower_type(), level)
    while exp >= threshold and level < TowerUpgradeManager.MAX_LEVEL:
        exp -= threshold
        _do_level_up()
        threshold = TowerUpgradeManager.get_xp_threshold(_get_tower_type(), level)

func _do_level_up() -> void:
    level += 1
    _apply_level_stats()
    TowerUpgradeManager.tower_leveled_up.emit(self, level)
    _play_level_up_fx()
    Toast.show(tr(name_key) + " " + tr("_tower_level_up_suffix") + " Lv." + str(level))

func _apply_level_stats() -> void:
    var m = TowerUpgradeManager.get_mults(_get_tower_type(), level)
    atk = int(_base_atk * m.get("atk", 1.0))
    radarScope = _base_radar * m.get("radar", 1.0)
    delay = _base_delay * m.get("reload", 1.0)
    # 同步给雷达碰撞体与开火计时器
    if raderShape and raderShape.shape:
        raderShape.shape.radius = radarScope
    if delayTimer:
        delayTimer.wait_time = delay

# 子类覆写：返回自身塔类型枚举值
func _get_tower_type() -> int:
    return -1

# ===== 升级特效 =====
func _play_level_up_fx() -> void:
    var tween = create_tween()
    tween.tween_property(turret, "scale", Vector2(1.3, 1.3), 0.15)
    tween.tween_property(turret, "scale", Vector2(1.0, 1.0), 0.2)
    # 可选：光环粒子 / 音效
```

> 子类需覆写 `_get_tower_type()` 返回对应枚举（如 `return Game.towerType.cannonTower`）。

### 6.5 升级数值示例

以机枪塔（`machineGunTower`，初始 atk=10、reload=0.1、radar=500）为例：

| 等级 | atk | reload(秒) | radar | 累计经验要求 |
| ---- | --- | ---------- | ----- | ------------ |
| Lv.1 | 10  | 0.10       | 500   | 0            |
| Lv.2 | 15  | 0.085      | 600   | 6            |
| Lv.3 | 22  | 0.07       | 700   | 18           |

### 6.6 UI 与视觉反馈

#### 6.6.1 等级徽章

- 在每个塔场景（如 `machineGunTower.tscn`）的根节点下新增 `level_badge`（`Sprite2D` 或 `Label`）。
- 根据 `tower.level` 显示对应数量的小星（1/2/3 颗），位置在塔基座上方。
- 满级（Lv.3）时徽章变为金色并加边框。

#### 6.6.2 选中塔时显示经验条

- 选中塔（`selected == true`）时，在 `_draw()` 中除现有雷达圈外，额外绘制经验进度环/条：
  - `exp / TowerUpgradeManager.get_xp_threshold(tower_type, level)` 比例填充。
  - 满级时显示 "MAX" 文字。

#### 6.6.3 升级瞬间反馈

- `turret` 缩放脉冲动画（已在 `_play_level_up_fx` 中实现）。
- `toast` 提示："机枪塔 升级到 Lv.2"。
- 可选：塔身短暂金光着色（`modulate` tween）。

### 6.7 集成点

| 集成点                  | 修改文件                                       | 说明                                                                                  |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------- |
| Autoload 注册           | `project.godot`                                | 添加 `TowerUpgradeManager="*res://autoload/tower_upgrade_manager.gd"`                 |
| 子弹来源字段            | `script/bullet.gd`                             | 新增 `source_tower` 字段                                                              |
| 各塔 `fire()` 注入来源  | `cannon_tower.gd` / `machineGunTower.gd` 等    | 实例化子弹后追加 `temp.source_tower = self`                                           |
| 瞬时伤害塔传来源        | `laser_tower.gd` / `tesla_coil_tower.gd` 等    | 调用 `enemy.hurt(damage, self)`                                                       |
| 敌人 `hurt` 接受来源    | `enemy.gd` / `mini_tank.gd` / `mediumTank.gd` / `heavyTank.gd` | `hurt(_num, _source=null)`，死亡时 `_source.add_exp(...)`               |
| 塔基类升级逻辑          | `tower.gd`                                     | 新增 `level`/`exp`/`add_exp`/`_do_level_up`/`_apply_level_stats`/`_get_tower_type`     |
| 各塔子类返回类型        | 各 `*_tower.gd`                                | 覆写 `_get_tower_type()` 返回对应枚举值                                               |
| 等级徽章节点            | 各塔 `.tscn` 场景                              | 新增 `level_badge` 子节点                                                             |
| 选中绘制经验条          | `tower.gd` `_draw()`                           | `selected` 时绘制 exp 进度                                                            |
| 文案                    | `lang/language.csv`                           | 添加 `_tower_level_up_suffix`（" 升级到 "）等 i18n key                               |

### 6.8 设计权衡说明

1. **为何不引入伤害贡献追踪**：当前游戏每发子弹伤害较高、击杀归属明确（最后一下），引入"按伤害比例分经验"会增加敌人内部的伤害记录字典与每帧统计开销，且与"击败敌人后获取经验"的需求表述不符。采用"击杀者独得经验"更简单且符合需求。
2. **为何状态放塔实例而非单例**：每座塔的等级/经验是实例私有状态，若集中到单例需要用字典 `{ tower_instance: {level, exp} }` 维护，反而增加复杂度且容易在塔被出售时遗留脏数据。塔实例销毁时状态自然释放，更干净。
3. **无配置的塔不升级**：`CONFIGS` 未配置的塔类型调用 `get_config` 返回空字典，`add_exp` 直接 return，保持 Lv.1 不变。便于分批上线：先实装机枪/加农/激光，其余塔后续补配置即可。
4. **经验值来源**：默认复用敌人的 `reward` 字段作为经验值，无需新增字段；若需差异化（如经验≠金币奖励），可在 `enemy.gd` 新增 `exp_reward` 字段并在 `_get_exp_reward()` 中返回。

---

## 七、模块更新记录

> 每次模块设计变更或新增模块时，在此追加记录，保持版本可追溯。

| 日期       | 模块             | 版本 | 变更说明                                               |
| ---------- | ---------------- | ---- | ------------------------------------------------------ |
| 2026-08-19 | 背包系统         | v1.0 | 初版设计：物品/商店/背包/战斗内使用完整方案            |
| 2026-08-19 | 成就系统         | v1.0 | 初版设计：成就定义/解锁/查看面板/游戏内提示            |
| 2026-08-19 | 能力技能系统     | v1.0 | 初版设计：区域轰炸/防御塔无敌双能力、冷却UI            |
| 2026-08-19 | 防御塔升级系统   | v1.0 | 初版设计：击杀积累经验自动升级、3级2升、配置化         |
| 2026-08-23 | 波次进度条模块   | v1.0 | 新增设计：右下角波次进度条 + 关键波节点 + 悬停 tooltip |

---

## 八、后续可扩展模块（规划中）

以下模块为后续规划，待需求明确后补充详细设计：

1. **每日任务系统**：参考成就系统结构，每日刷新任务，完成奖励钻石/物品。
2. **关卡星级与奖励**：基于 `level_rating.gd` 扩展，三星通关奖励宝石。
3. **装备系统**：为塔添加可装备的强化道具，与背包系统共用 `ItemData` 结构。
4. **存档系统统一化**：将 `userData`、`backpack`、`achievement_manager` 的存档逻辑统一到一个 `SaveManager` 单例。

---

*本文档为 Machine-TD 项目功能模块设计记录，所有模块以独立、可扩展、信号驱动为设计核心。*
