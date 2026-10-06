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
- [七、场景切换（Scene Transition）](#七场景切换scene-transition)
- [八、模块更新记录](#八模块更新记录)
- [九、后续可扩展模块（规划中）](#九后续可扩展模块规划中)

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

> **实现状态：❌ 未实现** —— 本文档为设计稿，项目中尚无对应代码（`backpack` / `item` 相关文件数为 0）。

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

> **实现状态：✅ 已实现**（2026-09-12）—— 9 个成就全部接入实际事件，
> 含关卡内记录器、图标网格总览面板、右侧滑入获得提示；文案已全量中英双语。
> 已知限制：成就「路线掌控者」依赖多路线关卡，当前内容下无法达成（见 `game_analysis.md` §4.3）。

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

> **实现状态：❌ 未实现** —— 本文档为设计稿，项目中尚无对应代码（`ability` / `skill` 相关文件数为 0）。
>
> ⚠️ 该模块依赖地图侧的接口（区域选择、范围伤害、塔无敌），建议在 `game_analysis.md` §7 第一阶段的地图数据模型修好之后再落地。

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

> **实现状态：✅ 已实现** —— `scene/wave_progress_bar.tscn` + `script/wave_progress_bar.gd`，已挂在 map 的 HUD 上。

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

> **实现状态：✅ 已实现** —— `autoload/towerUpgradeManager.gd` + `tower.gd` 的 `addExp/levelUp`，
> 7 种塔都有 3 级配置；升级会同步攻击、射速、射程并播放发光特效。
>
> **例外**：EMP 干扰塔只减速、不造成伤害，拿不到击杀经验，已通过
> `TowerUpgradeManager.NON_UPGRADABLE` 明确排除在升级体系外（详情面板显示 `MAX`）。
> 它的 lv2 / lv3 配置保留着，将来接上独立经验来源后从名单里移除即可启用。
>
> 注：本文档 6.2 / 6.3 中的文件名与接口名（`tower_upgrade_manager.gd`、`_do_level_up`、`_apply_level_stats` 等）
> 是设计稿命名，实际实现用的是 `towerUpgradeManager.gd`、`levelUp()`、`addExp()`，以代码为准。

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

## 七、场景切换（Scene Transition）

### 7.1 模块定位

每次"主菜单 ↔ 选关 ↔ 战斗"跳转时的整屏过渡。**不是**一个玩法模块，所以只做两件事：
把旧画面盖住、在遮住的那段时间里异步加载新场景，加载完再擦掉遮罩。

### 7.2 文件结构

```
scene/scene_transition.tscn     自动加载的载体（Node → CanvasLayer → ColorRect）
script/scene_transition.gd      流程控制
shader/transition.gdshader      擦除效果（用户提供的通用遮罩着色器）
```

场景结构（改造前只有一个纯脚本，没有节点）：

```
sceneTransition   Node          process_mode = ALWAYS（暂停时也要能转场）
└─ canvasLayer    CanvasLayer   layer = 100，盖住所有常规 UI
   └─ overlay     ColorRect     全屏锚点 + ShaderMaterial(transition.gdshader)
```

**为什么改成"场景 + 脚本"**：着色器参数（颜色、方向、软边强度）现在直接存在场景的
`ShaderMaterial` 子资源里，能在编辑器里实时预览和调整，不用改代码；纯脚本方案没法挂材质。

### 7.3 对外接口

```gdscript
SceneTransition.change_scene(path: String, duration: float = 0.6) -> void
```

与改造前**完全一致**，6 个调用点（`level_select.gd:29,33`、`map.gd:387,391`、`welcome.gd:32,39`）
无需改动。`is_transitioning` 期间重复调用会被直接忽略（防重入）。

### 7.4 `transition.gdshader` 参数含义

着色器本身是通用的，本项目只用到其中一部分：

| 参数 | 本项目取值 | 说明 |
| --- | --- | --- |
| `factor` | 由脚本补间 | **0 = 完全透明，1 = 完全盖满**。进场 0→1，出场 1→0 |
| `base_color` | `(0.08, 0.09, 0.12)` | 幕布颜色，与深色 UI 主题一致 |
| `width` | `0.35` | 梯度映射宽度，同时决定柔边的绝对像素数 |
| `gradient_texture` | 黑→白竖直渐变 | 决定擦除方向与形状，改渐变方向即可换成左右擦除 |
| `gradient_fixed` | `false` | 用屏幕 UV 采样，遮罩跟着屏幕走而不是跟着控件走 |
| `shape_texture` | 纯白 8×8 | 纯白 = 不做噪点溶解，得到一条干净的扫描线 |
| `shape_feathering` | `0.35` | 柔边强度，实测 1080p 下过渡带 ≈ 80 px |
| `shape_treshold` | `1.0` | 撑满遮罩不透明度 |
| `node_resolution` | 运行时同步视口尺寸 | 只服务 `gradient_fixed = true` 的宽高比校正 |
| `shape_tiling` / `shape_rotation` / `shape_scroll` | 关闭态 | 留给"纹理溶解 + 滚动"的变体，当前不用 |

有效覆盖率 = `clamp((UV.y - progress) / width, 0, 1)`，其中
`progress = mix(-width, 1.0, factor)`，再经 `shape_feathering` 做一次 `smoothstep`。
所以 `factor` 在 `[0, 0.09]` 与 `[0.83, 1]` 两段是"空转"的（幕布还没出现 / 已经盖满），
实际扫屏发生在中间的约 74% 时间内——对 0.6 s 的过渡来说可以忽略。

### 7.5 流程

```
change_scene(path)
  ├─ overlay 显示，factor 0 → 1（duration * 0.5，最少 0.12 s）
  ├─ ResourceLoader.load_threaded_request(path)   异步，不卡帧
  ├─ 每帧轮询 load_threaded_get_status
  │    └─ LOADED → change_scene_to_packed() → factor 1 → 0（duration * 0.5）
  └─ 结束后 factor 复位 0、overlay 隐藏、is_transitioning = false
```

过渡期间 `_input()` 吞掉全部输入事件，避免点击穿透到正在消失的旧场景。

### 7.6 弹窗层级：为什么弹窗必须改成 Control

Godot 的 `Window` / `Popup` / `PopupPanel`（`PopupPanel` 也是 `Window` 的子类）默认以
**嵌入式子窗口**渲染，绘制在所有 `CanvasLayer` 之上。也就是说只要弹窗还是 Window，
layer 100 的转场遮罩就永远盖不住它 —— 转场时会看到弹窗浮在幕布上面。

因此 5 个弹窗全部改成了普通 `Control`：

| 弹窗 | 原类型 | 现类型 | 改动备注 |
| --- | --- | --- | --- |
| `about_panel` | PopupPanel | Control | 背景本来就在内层 PanelContainer 上，无视觉变化 |
| `level_intro_panel` | PopupPanel | Control | 背景 StyleBox 从 `panel` 主题项搬到新增的 `panelBg`(Panel) 节点，否则会丢掉底板 |
| `pause_menu` | Window | Control | 原本就是"全屏 bg + 居中面板"结构，几乎是纯类型替换 |
| `result_screen` | Window | Control | 同上 |
| `setting` | Window | Control | 关闭按钮由绝对坐标改为锚定到面板右上角 |

统一约定：

- 根节点 `Control`：`offset_right = 1920`、`offset_bottom = 1080`、`mouse_filter = STOP`
  （铺满全屏，保留模态输入拦截），`visible = false` 起步
- **不能用 `anchors_preset = 15`**：这些弹窗挂在 `Node2D` 下，而 Control 的锚点是相对
  "最近的 Control 祖先"解析的。父级是 `Node2D` 时锚定矩形是空的，全屏锚点会算出 0×0。
  必须写成显式 offset。
- 内容用 `anchors_preset = 8`（居中）+ `grow_horizontal/vertical = 2`，随内容自适应尺寸
- 需要在暂停状态下仍可交互的（`pause_menu` / `result_screen`）保留 `process_mode = ALWAYS`

`map.tscn` 里三个战斗内弹窗还要从 `map` 挪进新的 `popupLayer`(CanvasLayer, `layer = 10`)：
`hud` 本身就是 CanvasLayer，会盖住同级的普通 Control。
`welcome.tscn` 里没有 CanvasLayer，弹窗声明在 `ui` 之后即可自然压在 UI 上方。

### 7.7 验证方式

临时工程副本 + 两套自动化脚本，**合计 71 项断言 0 失败**：

1. **转场**（45 项，明细见 [game_analysis.md](game_analysis.md) §7.1）：结构、`factor` 语义、
   擦除方向、柔边宽度（扫描 `shape_feathering` 4 个取值）、边缘单调性与洁净度、
   以及 4 次连续切换的场景落点与状态复位。
2. **弹窗层级**（26 项）：5 个弹窗的类型、根矩形、内容是否在屏内，`CanvasLayer` 层号，
   `map.gd` 的 `@onready` 绑定与暂停态可交互性，以及**最关键的**：把遮罩拉到
   `factor = 1` 后整屏最大色偏为 **0.0000**（弹窗被完全盖住），
   同时与"弹窗可见"那一帧的像素差异达 0.66 ~ 0.94（证明弹窗原本确实画在屏幕上）。

---

## 八、模块更新记录

> 每次模块设计变更或新增模块时，在此追加记录，保持版本可追溯。

| 日期       | 模块             | 版本 | 变更说明                                               |
| ---------- | ---------------- | ---- | ------------------------------------------------------ |
| 2026-08-19 | 背包系统         | v1.0 | 初版设计：物品/商店/背包/战斗内使用完整方案（**未实现**）|
| 2026-08-19 | 成就系统         | v1.0 | 初版设计：成就定义/解锁/查看面板/游戏内提示            |
| 2026-08-19 | 能力技能系统     | v1.0 | 初版设计：区域轰炸/防御塔无敌双能力、冷却UI（**未实现**）|
| 2026-08-19 | 防御塔升级系统   | v1.0 | 初版设计：击杀积累经验自动升级、3级2升、配置化         |
| 2026-08-23 | 波次进度条模块   | v1.0 | 新增设计：右下角波次进度条 + 关键波节点 + 悬停 tooltip |
| 2026-09-12 | 深色 UI 主题     | v1.0 | 实现：所有弹出框统一为浏览器深色风格；地图内塔/敌人面板独立为军事科技风，与界面弹窗区分 |
| 2026-09-12 | 炮口开火特效     | v1.0 | 实现：抽出 `tower.play_muzzle_flash()`，机枪/加农/火箭塔接入炮口闪光 + 炮管后坐；无炮口的塔自动跳过 |
| 2026-09-12 | 敌人雷达数据化   | v1.0 | 实现：`Game.enemyInfo` 新增 `scope` 字段作为射程唯一来源，运行时统一同步雷达碰撞体；修复自爆车无碰撞体、维修车半径只有默认 10px 的问题 |
| 2026-09-12 | 敌人信息面板     | v1.0 | 实现：点击敌人显示名称/血量/攻击/属性/收益，与塔详情面板互斥复用右侧同一槽位，敌人死亡/逃脱/自爆后自动关闭 |
| 2026-09-12 | 无人机巡逻与尾迹 | v1.0 | 实现：巡逻半径改为贴合防御塔射程边缘（随升级外扩），新增 Line2D 飞行尾迹；顺带清理 `aircraft` 基类的死组件 |
| 2026-09-12 | 成就系统（落地） | v1.0 | 实现：关卡内记录器 `achievement_tracker` + 图标网格总览面板 + 右侧滑入获得提示；进度批量落盘；全量中英多语言 |
| 2026-09-12 | 项目文档         | v1.0 | README 重写为项目说明；`game_analysis.md` 更新为当前状态并新增「地图与关卡系统专项」章节 |
| 2026-09-12 | 核心正确性修复   | v1.0 | 修复三个"看起来能用、实际没生效"的机制：① 敌方 `delay` 定时器未接线导致远程敌人整局只开火一次；② 子弹未传 `source_tower` 导致 4/7 座塔无法升级；③ 结算门禁缺失导致 0 星/基地被打爆仍发宝石并解锁下一关 |
| 2026-09-12 | §6.3 击杀归属    | v1.0 | 该设计的实现补完：`gun_bullet` / `cannon_bullet` 已注入 `source_tower`；同时新增 `TowerUpgradeManager.canUpgrade()`，EMP 干扰塔按设计明确排除在升级体系外（详情面板显示 MAX） |
| 2026-09-12 | 场景切换         | v1.1 | 重构：纯脚本自动加载 → **场景 + 脚本**（`scene/scene_transition.tscn`：Node → CanvasLayer(100) → ColorRect + `ShaderMaterial`），接入用户提供的 `shader/transition.gdshader` 做自上而下柔边擦除；柔边强度由 0.08 调到 0.35（1080p 实测过渡带 18px → 80px）。对外 `change_scene(path, duration)` 与 6 个调用点不变，已删除旧 `autoload/sceneTransition.gd` 与旧的 `shader/scene_transition.gdshader`（零引用）。新增设计章节见 §七 |
| 2026-09-12 | 弹窗层级修复     | v1.1 | 修复"转场遮罩盖不住弹窗"：`about_panel` / `level_intro_panel` / `pause_menu` / `result_screen` / `setting` 由 `Window` / `PopupPanel` 改为普通 `Control`（嵌入式子窗口永远画在所有 `CanvasLayer` 之上）；`map.tscn` 新增 `popupLayer`(CanvasLayer, layer 10) 承载三个战斗内弹窗；根节点改用显式 offset 而非 `anchors_preset = 15`（父级是 Node2D 时锚定矩形为空）。详见 §7.6 |
| 2026-09-13 | 美术风格规范     | v1.0 | 新增 [art_style.md](art_style.md)：工厂世界观（流水线=路径 / 出口=终点 / 基座=塔位 / 五层关卡模板）、色彩系统（钢灰十阶 + 安全黄 + 9 个语义色，含实测 WCAG 对比度）、UI 组件规范（按钮三档 / 面板 / 状态条 / 反白 tooltip）、世界元素规范、单位识别（黄=我方 / 红=敌方）、字体与图标建议 |
| 2026-09-13 | UI 主题亮色迁移  | v2.0 | 全量迁移：`theme.tres` + 31 个 StyleBox 由深色改为亮色工厂主题；15 个场景的硬编码文字色、`achievement_panel.gd` / `level_intro_panel.gd` 的颜色常量、`background.gdshader`（暗贴图相乘 → 浅底图案叠加）、`project.godot` 清屏色一并调整。**未改动任何 `.tscn` 结构**，纯换皮可逆。详见 art_style.md §9/§10 |
| 2026-09-13 | UI 主题重建       | v3.0 | 亮色版实测整体过亮，按用户提供的参考资源包 `factory asset v.2 - chemical lab` 重建为**深银金属**：对 13 张参考图做像素直方图 + k-means 提取真实调色板（整体平均明度 0.336），主题面色全部投影到该金属阶梯上（最大偏差 ≤0.009）；主强调保持安全黄，语义色改用参考包的化学绿 / 锈红 / 青。同样未改动 `.tscn` 结构 |
| 2026-09-13 | 地板 + UI 再平衡 | v3.2 | 地板、清屏色统一为 `Tech Dungeon Roguelite` tileset 最右区域的地砖色 `#333C57`。地板明度骤降导致原深色面板与地板撞车（差 0.005），故按同一 Sweetie 16 色板把 UI 面板提到 `#566C86` + `#94B0C2` 2px 亮边框，文字整体提亮一档。三层明度 0.046 / 0.144 / 0.412。详见 art_style.md §9/§10 |
| 2026-09-13 | 背景场景还原     | v3.3 | `bg.tscn` 恢复为最初的「`background_tiled.png` 平铺 + UV 沿 Y 轴滚动 + 上暗下亮渐变」，只新增 `tint` 把中性灰（平均 `#2E2E2E`）映射到 `#333C57`。`tint` 为实测标定值（引擎采样纹理有自身色彩空间处理，不能按 PNG 平均值直接换算）：渲染实测 `#313953`，与目标偏差 0.018；滚动经 8 次不等间隔采样确认仍在 |
| 2026-09-13 | 标题图 + 动态条纹 | v3.4 | 标题改为图片接入欢迎页（`sprite/title_logo.png` + `scene/ui/title_logo.tscn`，挂 `light.gdshader` 扫光）；标题去掉四周钢板与描边，改成 1600×450 透明底；危险条纹抽成独立组件 `scene/ui/hazard_strip.tscn` + `shader/hazard_scroll.gdshader`，贴图 272×22 横向严格无缝，UV 沿 X 轴滚动；艺术字改用系统安装的 Black Ops One（OFL），工程内不再放字体文件，生成器 `tools/title_logo.gd` 通过 `OS.get_system_font_path()` 查找并回退到阿里普惠体 |
| 2026-09-13 | 车间地面瓦片集   | v3.5 | 新增项目级地板瓦片体系：`sprite/tile/` + `scene/level/factory_floor.tres`（`tile_size = 64×64`，正好等于 `StageData.TileSize`；**一张 PNG 一个 `TileSetAtlasSource`**，以后加新地砖只要丢图 + 加一条 source，不用重排图集）。手绘的 3 张 Aseprite 原稿（基础底板 / 通风格栅 / 排水格栅）解析校验后**原样入库**——64×64、颜色正好是项目色板、左右边缘与上下边缘完全相等（自带无缝）；另按同一色板补 8 种（螺栓板 / 花纹钢板 / 检修口 / 排水沟 / 集水坑 / 油渍 / 裂纹 / 安全警示带）凑成 11 种，解决"地面单一"。颜色白名单 `#333C57` / `#1A1C2C` / `#0D1016` / `#272C42` / `#FFC61A`，四周 1px 描边平铺后合成 2px 砖缝；警示带的 45° 条纹周期 16 整除 64，是**跨格连续**的（故意断开竖直砖缝）。顺带修掉 `tools/title_logo.tscn` 的 UTF-8 BOM（Godot 报 `Parse Error: Expected '['`）。验证：临时工程真机跑 `tile_check`，**174 项断言 0 失败**；另跑全工程冒烟（83 个场景 + 39 个资源全部可加载，0 警告）。`floor_vent` 的格栅节奏经确认规整为 6/6/6px + 上下各 14px（只动 2 行像素），并写进回归断言 |
| 2026-09-13 | 塔位基座瓦片     | v3.6 | 手绘 `精灵-0004.aseprite`（绿色 64×64 + 四边中点凸起）设计为**可建造基座瓦片** `sprite/tile/floor_slot.png`，纳入 `factory_floor.tres`（12 个 source）。参考 `Industrial&Underground2DMegaPropsPack` 的机械臂底座（分层圆台 + 一圈铆钉）与钢制工作台（受光顶面 + 亮边 + 青色钢架），读法定为「受光顶面 + 右下 3px 板厚 + 左上 1px 亮边」；原稿的四边凸起改成**内嵌**安装块（外凸会让相邻基座互撞）。配色不用手绘的 `#6ABE30` 而用 §5 已定的青色梯 `#3D7A72` → `#6BC2B0` + 四角 `#FFC61A` 螺栓 —— 实测绿色塔站在绿基座上会糊掉（对比图 `design/tile_base_slot_compare.png`）。台面明度 0.468 vs 地板 0.235，可建造区一眼可见；1px 砖缝与 `floor_*` 完全一致，可直接铺进同一个 `bg` TileMapLayer。验证：`tile_check` **193 项断言 0 失败** |
| 2026-09-13 | 流水线皮带瓦片   | v3.7 | 路径层落地：`sprite/tile/belt_*` 12 个方向件（4 直段 + 8 拐角，**两个旋向都齐**），纳入 `factory_floor.tres`（24 个 source）。生成方式为「中心线折线 + 距离场」：皮带面 `d<=18`（36px）、护栏 `18<d<=21`、其余地板；**相位 = 从入口边算起的弧长**，横向筋周期 16 / 人字形周期 32 都整除 64，所以跨格图案连续（第一版每张各自从零算相位，拼起来箭头撞成叉）。拐角外侧由距离场自动倒圆角，内侧保持直角。自检：12 件 × 4 边 = 48 条边，24 条连通边通道区间必须完全一致（`11..52/42px`）、24 条非连通边必须为 0。明度 0.113 vs 地板 0.235，路径比地板深一档。**注意**：关卡敌人仍沿 `Path2D` 的 `Curve2D` 走，皮带瓦片目前只是视觉标记，尚未接线。验证：`tile_check` **206 项断言 0 失败**（含 48 条边一致性） |
| 2026-09-13 | 炮塔与底座美术   | v3.8 | 手绘 `精灵-0005`（机枪塔，圆炮塔 + 双炮管）/ `精灵-0006`（大炮，圆炮身 + 单炮管）设计为可用的塔美术，并抽出**多层装配契约**：`base`(不旋转) + `turret`(绕节点原点旋转、贴图朝 +X + `Marker2D` 炮口) + `spark`。机枪塔补上后部弹药舱、炮盾、散热环、炮口制退器、舱盖、观瞄镜；加农炮补上后坐缓冲筒、炮口制退器、尾配重、8 颗铆钉、装填舱盖、黄警示弧。**机枪塔首版炮盾太长把两根炮管挡成一块，重做后管身露出 20px、两管间留 9px 缝**。底座 4 种型（圆台 / 八角 / 方板 / 三脚爪）统一 **48×48，比 64px 塔位瓦片小一圈**。配色试过用户原稿（灰机枪 / 绿大炮），实测灰的在青基座上发闷、绿的过饱和，统一改走 §6 亮银（对比图 `design/tower_compare_palette.png`），变体 B 留在 `.td_verify/tower/*_B.png`。`turret_cannon.png` 是 80×64，轴在贴图 (32,32)，**节点需 `offset = Vector2(8,0)`**。12 角度旋转检查无抖动。详见 art_style.md §6「塔的多层装配契约」 |
| 2026-09-13 | 加农炮简化       | v3.9 | 按反馈重做 `turret_cannon.png`：**炮管简化成一根等宽光管**（去掉炮口制退器 / 后坐缓冲筒 / 散热环 / 黄警示环），**炮身改成坦克舱盖**（座圈 + 盖板 + 左侧两个合页耳 + 拉手），去掉 8 颗铆钉 / 尾配重 / 观瞄镜 / 通风口等全部额外装饰。中途发现**拉手做成横杆会和炮管同高同色、视觉上连成一根长条**，舱盖读不出来 → 改成**垂直于炮管**的拉手。只保留合页销上 2px 黄点作为 §6「黄=我方」记号（整张图黄像素仅 4 个） |
| 2026-09-13 | 余下五塔美术   | v4.0 | 补齐剩余 5 座塔：**火箭塔**（手绘 `精灵-0007`，爱国者发射架读法：箱体压暗 + 4 根浅色发射管 + 4 个大管口）、**EMP 雷达**（大抛物面天线 + 中心馈源臂 + 发射头）、**激光塔**（128×128，8 发射头围一圈 + 中央亮黄核心）、**特斯拉**（128×128，两个并排线圈，厚圆环电极 + 电青中心球）、**无人机基地**（128×128，深色停机坪 + H 标志 + 8 盏安全黄指示灯），以及 2×2 通用大底座 `base_large.png`（104×104 < 128px 塔位区）。先查了代码：`machineGun / cannon / rocket / laser` 会朝目标旋转 `turret`，`tesla / emp / drone` 不旋转 —— 所以前三者必须朝 +X，后三者要各向同性或本身对称。中途修了三处读图问题：火箭塔的管子比箱体暗 → 读成通风口（改成管子亮、箱体暗）；EMP 天线太小 → 读不出是雷达（放大到 r=21 并加亮边）；特斯拉的**径向辐条把线圈读成了齿轮**（去掉辐条，改成厚圆环 + 左上受光/右下压暗，才读成甜甜圈）。验证：全工程冒烟 83 场景 + 39 资源 0 警告 0 错误 |
| 2026-09-13 | 特斯拉重做       | v4.1 | 手绘 `精灵-0008`（64×64：左侧圆润蓝色机体 + 内含发光核心 + 右侧一团灰色结构）解析后重做为 **128×128**（该塔 `gridSize = (2,2)`，原稿尺寸对不上）。灰色那团按俯视投影读成**螺旋绕组**，用「竖椭圆环 + 一道绕线」画成弹簧 —— 第一版圈距 5px 太密，整体读成**散热片**，拉开到 7px 并补上绕线才立住。机身做成装甲壳（分缝 + 6 颗铆钉 + 能量窗 + 顶部小电极），底座环 + 6 颗黄螺栓。能量色采用**手绘原稿的蓝 `#5B6EE1` / `#639BFF`**（实测对比度高于项目电青 `#6FD6EA`，电青版留在 `.td_verify/tower/tower_tesla_v2.png` 可随时换）。旧的「双线圈」版被本次替换 |
| 2026-09-13 | 特斯拉再返工     | v4.2 | 按反馈「不要底座、线圈围绕炮管、短一点、轮廓别歪」重做 `tower_tesla.png`：**去掉底座圆盘**，改成顶部**压扁椭圆环电极（torus）**+ 中央柱体 + 绕柱的**斜向带绕组**，整体压矮到 67×98。踩了三个读图坑：① 绕组画成「竖椭圆环」会读成散热片；② 斜度太小（36px 宽只升 5px）会退化成横条纹、整体糊成噪点，改成升 10px/圈距 11px/带宽 5px 才立住；③ 顶部大圆球会读成**路灯/麦克风**，必须换成环形电极。柱体左右边缘固定 `x=47/81`（中心 64）保证严格竖直且左右对称 —— 手绘原稿机身偏左会让整塔看着是歪的。过程版 V3 读成"路灯"已废弃 |
| 2026-09-13 | 特斯拉 V5        | v4.3 | 按用户给的参考图 `game_207.png`（44×28，橙色：圆角三角机身 + 内部竖板/3 点/2 大圆点 + 带齿火花隙 + 端电极）重画 `tower_tesla.png`，×2.7 放到 **128×128**。机身改用**三角形 SDF**（`形 = 三角形 ∪ 到三边距离 ≤ rOuter`，边缘 `W` 像素内描边）保证轮廓是干净圆弧 —— 第一次忘了按 `rOuter` 内缩顶点，膨胀后溢出画布并把右侧火花隙整个盖住。配色同时出了 **A 参考橙 `#F5821F`/`#FAC574`/`#A33230`/`#51021C`** 与 **B 项目银 + 电青**，默认装 A（忠于参考图），B 留在 `.td_verify/tower/tower_tesla_v5_silver.png`。V4（竖柱绕组版）被本次替换 |
| 2026-09-13 | 特斯拉换色 + 火箭塔重做 | v4.4 | ① `tower_tesla.png` 由参考图的**橙**换回**项目银 + 电青**（橙 `#F5821F` 不在项目色板里，且与 §6「黄=我方 / 锈红=敌方」语义擦边；1:1 战场实测过于抢眼）。② `turret_rocket.png` 按用户新给的线稿参考（**发射箱 6 面板 + 导轨 + 带后掠尾翼的导弹**）重做，从 64×64 的「爱国者四管发射架」改为 **80×64** 的「发射箱 + 出膛导弹」：箱体 6 个圆角面板 + 抬高肩部 + 圆柱弹体（5 道环形分段）+ 蛋形尖锥头（1/4 椭圆）+ 上下两片**实心后掠尾翼** + 一道黄警示环。中途返工两次：尾翼先用细线画 → 读成划痕，改成实心三角；导弹太短 → 箱子缩短、导弹前移、头锥从 12px 加长到 15px。非 64 宽，节点需 `offset = Vector2(8,0)` |
| 2026-09-13 | 火箭塔 V3        | v4.5 | 按用户新给的**多管导弹发射箱线稿**（2048×2048 3/4 视图：抬高边框的圆角箱体 + 管内伸出的多枚导弹尖头 + 四角小方块 + 中部提手槽）再重做 `turret_rocket.png`（仍 **80×64**，朝右，项目配色）：箱体抬高边框 + 内凹面板 + **4 条发射管槽** + **4 枚出膛导弹**（圆柱弹体 + 环形分段 + 蛋形尖锥头 + 黄警示环）+ 四角小方块 + 左侧提手槽。中途返工一次：**第一版 4 条管槽铺满箱体，边框/四角方块/提手槽全被盖住，箱子读成"4 条黑条纹"** —— 把管槽左端从 `x=5` 退到 `x=11`、箱体从 40 加宽到 48 才露出箱面。V2（箱+单弹）被本次替换 |
| 2026-09-13 | EMP 雷达改版     | v4.6 | 按用户给的**雷达阵面线稿**重做 `turret_emp.png`（64×64，1×1，不旋转）：**4 块梯形雷达面板按十字布局** + **中央八边形中枢**（内八边形 + `info_lt` 青点 + 小天线）+ **圆形底座环**（带 24 个栏杆点）+ 4 颗黄螺栓落在面板之间的斜向空档。面板用凸四边形扫描线填充，外缘受光条 / 内缘压暗条 / 4 道横向分缝做「阵面感」。中途返工一次：**第一版底座画成实心圆盘，把 4 块面板之间的空档全填满，整体读成「一个圆盘」** —— 改成只留一圈细环（内部透明）后十字布局才分离出来。旧版抛物面天线被本次替换 |
| 2026-09-13 | 激光塔改版       | v4.7 | 按用户给的**激光发射装置线稿**重做 `tower_laser.png`（128×128，2×2）：**中央多层同心核心**（5 层同心环 + `#FFD964` → `#FFF0B0` → 白）+ **八向辐射臂**（连杆 + 方箍 + 末端**圆柱发射头**，发射头探出平台外缘、镜片亮黄）+ **分段环形平台**（16 段明暗交替外缘 + 8 个矩形面板落在两臂空档）+ 8 颗黄螺栓。中途返工一次：**第一版平台做到 r=58、发射头只到 r=58，发射头全被平台包住，整张图读成「齿轮/花盘」** —— 平台收到 r=50.5、发射头伸到 r=60 才立住。旧版「八头围一圈」被本次替换 |
| 2026-09-13 | 美术资源接入 + 教程关换皮 + 字号统一 | v5.0 | **① 7 座塔全部接线**：`base` 用新底座（1×1 → `base_round`/`base_octagon`/`base_plate`，2×2 → `base_large`），`turret` 换成新炮塔贴图，`scale` 0.6 → 1.0，`Marker2D.position` = 炮口距离（机枪 31 / 加农 47 / 火箭 41 / EMP 24 / 激光 60 / 特斯拉 30 / 无人机 40），加农与火箭 `turret.offset = Vector2(8,0)`。**特斯拉的 `base` 故意留空**（塔身自带形态 + 银压银对比度太低）。`tower_ui.gd` 的卡片图标、`tower_shadow.tscn` 的 7 条放置阴影动画同步更新。**② 教程关换皮**：`bg` 的 TileSet 换成 `factory_floor.tres`，铺 30×17 = 510 格 —— 基础地板 + 第 4 行整行皮带 + allowArea 的 36 格 `floor_slot` + 顶部/底部通风格栅 + 最底一行危险警示带 + 排水口/舱盖/裂纹/油渍/集水井点缀。**路径曲线 y 从 320 移到 288**（对齐格子中心，皮带才不会错位半格）。**③ 字号统一**：地图内 UI 收敛到 **40 / 30 / 26 / 22** 四级字阶（面板标题 / 数值 / 区块标题与按钮 / 次要说明），`tower_status_ui` 的 11px 提到 18px。踩坑见下 |

**v5.0 的三个坑**：

1. **`tile_map_data` 不能手搓** —— 我按「12 字节/格」拼了 6120 字节，Godot 报 `Corrupted tile map data`。真实格式是 **510×12 + 2 字节头 = 6122**。最后的做法是让 Godot 自己铺一遍再把 `TileMapLayer.tile_map_data` 导出来，不再猜二进制格式。
2. **`Tower.tscn` 已经有 `turret` / `spark` 节点** —— 给特斯拉补 turret 时写了 `[node name="turret" type="AnimatedSprite2D"]`，结果生成**两个同名节点**（第二个盖住第一个）→ 线圈完全不显示。改成不带 `type` 的覆盖节点（`[node name="turret" parent="." index="3"]`）才对。
3. **PowerShell 的数组与字符串** —— `@('a' + $x + ', 0)')` 会按逗号拆成多个元素（`Vector2(` / `30` / `, 0)` 三行），必须给拼接加括号；哈希表的键也**不区分大小写**（`'b'` 和 `'B'` 会冲突），`$src = $SRC[$ch]` 更是直接把哈希表本身覆盖掉。 |
| 2026-09-13 | 语言修复 + 字号再放大 | v5.1 | ① **根因：`TranslationServer.set_locale()` 只在设置面板里调用** —— 从没打开过设置页的玩家，全局 locale 停在系统默认，导致「可翻译文案回退英文、场景里硬编码的中文原样显示」的混排（开场情报面板最明显：标题 `Tutorial`、表头 `Wave/Base HP/...`、`Enemy Intel`、`Begin Battle` 全是英文）。翻译键其实**一个都不缺**。修法：新增 `UserData.applyLanguage()`，由 `UserData._ready()` 调用，设置面板也改走它；`UserData.language` 默认从 `"en"` 改为空串 = **跟随系统**（`OS.get_locale()` 以 `zh` 开头选中文）。② **补 3 处场景里硬编码、运行时从未被覆盖的英文**：顶栏 `score:` → `_Score`、关卡卡 `LOCKED` → `_LevelLocked`、暂停菜单 `Pause` → `_Pause`（新增 3 个翻译键）。③ **字号整体再放大一档**：地图内 UI 从 40/30/26/22 提到 **46/36/30/26**，开场面板单独再大一档（标题 54 / 数值 40 / 区块 36 / 表头 26 / 数据行 30 / 按钮 30），面板从 1016×736 扩到 **1180×840**，表格列宽同步加宽。踩坑：**字号不只写在 `.tscn` 里** —— `level_intro_panel.gd` 的表头/数据行/信息块字号是 `add_theme_font_size_override` 运行时设的，只改场景不生效 |
| 2026-09-13 | 开场面板自适应 + 旧配置迁移 | v5.2 | 承接 v5.1 的两个遗留问题。① **老玩家仍是英文**：`user_settings.cfg` 里存着旧版默认值写死的 `language="en"`，`applyLanguage()` 尊重已存值 → 永远中文不了。加**设置 schema 迁移**（`SETTINGS_SCHEMA = 2`）：读到的 schema < 2 且 `language == "en"` 而系统是中文时，判定为「继承来的默认值」重新置为 `zh`，并回写一次。② **按钮点不动**：开场面板原本是**固定尺寸 + `ScrollContainer` 默认 `vertical_scroll_mode = AUTO`** —— AUTO 模式下滚动条还没显示时 `ScrollContainer` 会把子节点的最小高度**向上传播**，VBox 被撑到超出面板，页脚（含「开始战斗」按钮）被顶到面板外，同时列表内容压在按钮上。改成 **`CenterContainer` + `PanelContainer` 按内容自适应高度**，`ScrollContainer` 设 `vertical_scroll_mode = 2`（SHOW_ALWAYS，不再传播最小高度）+ `custom_minimum_size = (0, 360)`，面板加 `custom_maximum_size = (1180, 1010)` 兜底。同时删掉 `Margin` 上遗留的 `custom_maximum_size = (-1, 800)`（那是 736 高时代留下的） |
| 2026-09-13 | 关卡限制可建防御塔 | v5.3 | ① **`StageData.stageTowers`**：按关卡 id 配置「本关允许建造的塔类型数组」，**没列进去的关卡 = 不限制**（向后兼容）。配套 `getTowers(stage_id)`（空数组 = 不限制）与 `isTowerAllowed(stage_id, type)`。当前配置：教程 / 第 1 关 = 机枪 + 加农 + 火箭；第 2 关 + EMP；第 3 关 + 特斯拉；第 4 关 + 激光；**第 5 关及以后不限制**。② **塔选择栏 `tower_ui.gd`** 按配置过滤：被限制的塔**仍生成卡片但整张置灰（alpha 0.3）、点不下去、不显示选中框**，点了只弹提示 —— 比直接隐藏更能让玩家明白「这东西存在但本关不给用」。③ **兜底**：`map.gd::placeTower` 开头再查一次 `isTowerAllowed`，防止绕过 UI 直接发 `Game.placeTower`；新增 `Game.towerLocked` 信号（`tower_ui` 发出 → `map` 弹 toast）。④ 新增翻译键 `_TowerLockedInStage`。⑤ 顺带修好 `tower_card`：`tower_ui` 调用的 `setTowerName()` **在项目里根本不存在**（塔名 Label 也一起被删了），已补回 Label + 方法，卡片现在会显示塔名。⑥ 顺带修正全项目 11 个场景/资源里的**失效 `uid=`**（冒烟 WARNING 从 10 条回到 0） |
| 2026-09-13 | 显示名简化 + 塔卡片去名字 | v5.4 | ① **`towerInfo` / `enemyInfo` 的 `name` 字段直接改存翻译键**（`"_TowerName_machineGun"`、`"_EnemyName_miniTank"`），`enemyInfo` 的 `role` 同理（`"_EnemyRole_pusher"`）。② 于是 **三张映射表 `towerDisplayNameKeys` / `enemyDisplayNameKeys` / `enemyRoleKeys` 全部删掉**，三个取名字函数各缩成一行 `tr(...)` —— `game.gd` 净减约 45 行。之前那套「表里查 key → tr → 没命中回退英文原名」的写法是在 `name` 存英文标识符时代的产物，现在已经没有必要。③ **塔卡片去掉塔名**：`tower_card.tscn` 删掉 `MarginContainer3/name`，`tower_card.gd` 删掉 `nameLabel` 与 `setTowerName()`，`tower_ui.gd` 去掉对应调用；卡片回到 140×140，只剩「图标 + 价格」，名字由详情面板/悬停浮层展示。④ `tower_info.gd` 里 `str(obj.name)` 的兜底分支也统一走 `tr()` |
| 2026-09-13 | 自定义相机重写   | v5.5 | 需求：玩家可以滚轮缩放，但**相机绝不能拖出关卡** —— 否则会直接看到屏幕外新生成的敌人。`custom_camera.gd` 从 180 行（含约 65 行注释掉的死代码）重写为 **109 行**。踩了两个坑：**① 拖拽用世界坐标差值会自激** —— 原来写的是 `drag_start_world - get_global_mouse_position()`，而 `get_global_mouse_position()` 会跟着相机一起动，代入后等价于 `target = 2 * 起点 - 当前位置`，每帧把相机往反方向甩一次再被边界夹回来，表现就是「相机偏移 / 抖动」。**② 改成屏幕坐标差后仍有慢速漂移** —— 除以的是**当前 `zoom`**，而缩放动画没收敛时 `zoom` 每帧都在变，目标位置被持续推着走（实测 40 帧漂 4.88px）。最终方案：用 **`event.relative` 每帧相对位移累积**再除以当前 `zoom`，对两者都免疫；起手跨过阈值的那个事件丢弃，避免刚拖就跳。边界判定按 `anchor_mode = FIXED_TOP_LEFT`（`global_position` = 可视区左上角）简化成一句 `左上角 ∈ [关卡左上角, 关卡右下角 - 视口世界尺寸]`，关卡比视口小就贴住左上角；`_process` 里**先用当前缩放夹实际位置再渲染**，所以缩放过渡期间也不会露出界外。另外补 `reset_view()`，`map.gd` 每次加载关卡时调用，避免上一关的缩放/位置带过来。验证：鼠标停住 40 帧漂移 **0.000000px**、拖 200px 屏幕位移相机正好移动 `200/zoom` 世界像素、六个方向各拖 100 帧**越界 0 帧** |
| 2026-09-13 | 音频素材入库     | v5.6 | 音源：`E:\音乐文件` = **Sonniss #GameAudioGDC Bundle Part 9**，347 个 WAV / 7.47GB，授权 **ROYALTY-FREE（可商用、无需署名）**。**关键结论：这是音效库，不是配乐库** —— 里面没有任何旋律 BGM，能当背景音乐用的只有 4 首 **60 秒级环境循环**。转换为 **OGG Vorbis / 44.1kHz**（不用 MP3：MP3 编码器首尾有静音填充，无法无缝循环；项目原本也用的是 `.ogg`），命令走 `D:\VLC\vlc.exe -I dummy --sout=#transcode{...}`。产出 **30 个文件 / 6.8 MB**（源 WAV 约 330MB）：`sound/bgm/` 4 首（`factory_ambient` 工厂机械底噪、`combat_reactor` 科幻反应堆、`dark_synth`、`shimmer_bells`，**4 首全部 `.import` 里 `loop=true`**）+ `sound/sfx/` 26 个（塔建造 / 冰冻技能 / 电弧 / 故障 / 爆炸 / 波次号角 / UI 七件套 / 金币 / 机械 / 敌人吼叫）。来源与授权记录在 `sound/CREDITS.md`。**尚未接线**：项目的 `Bg` 音频总线早就建好了，但至今没有任何东西在上面播放 |
| 2026-09-13 | 音频重组 + UI 点击音 | v5.7 | ① **去重**：原先散在 `sound/` 根目录的 `Ting Coins.ogg` / `Tower Deploy.ogg`，与本次转换出的 `sfx/coin.ogg` / `sfx/tower_deploy.ogg` 是**同一批音源的两个副本**（体积一致、MD5 不同说明是同源两次导出）。删掉根目录那两份，三处引用同步改到 `sfx/` 下：`sound_manage.tscn`（全局 UI 点击）、`setting.tscn`（音量滑块试听 ×3）、`tower/Tower.tscn`（建塔音）。**顺序是先改引用、再确认无残留、最后才删文件**。② **两种点击音分开**：`SoundManage` 增加第二条通道 —— `playEffect()`（`sfx/coin.ogg`，菜单/通用按钮，`ui_button.gd` 与 `welcome.gd` 在用）与 **`playConfirm()`（`sfx/ui_confirm.ogg`，地图内按钮）**；`title.gd` 的 5 个按钮处理函数（开始/倍速/静音/音乐/返回）与 `map.gd::_on_button_pressed` 全部改调 `playConfirm()`。两个 `AudioStreamPlayer` 都挂 `Sfx` 总线，静音开关同时生效。③ 发现 `sound/button_on.mp3` 已成**孤立文件**（全项目零引用），未删除仅记录；`Pickup.wav` 仍被设置页音量滑块使用，保留 |
| 2026-09-13 | UI 点击音去重    | v5.8 | 反馈：「UIButton 里点击会播 `SoundManage.playEffect()`，其他场景用了这个按钮会响两声」。**先做了完整排查，结论是磁盘上没有重复连接** —— 写运行时脚本遍历 `welcome` / `level_select` / `pause_menu` / `result_screen` 里全部 **11 个 `ui_button` 实例**，每个 `pressed` 信号上 `_on_pressed` **恰好 1 条**；又扫了全项目所有播音点（`ui_button.gd` / `welcome.gd` / `title.gd`×5 / `map.gd` / `setting.gd`×3 / `sound_opinion.gd` / `tower.gd`）与所有场景脚本，没有"同一按钮播两遍"的代码。但项目里确实存在**两套互斥的按钮模式**容易踩坑：`ui_button.tscn`（自带脚本、自身出声）vs `menuBtn.tscn`（无脚本、需场景显式播），混用在同一个按钮上必然两声。因此做了三重修法：① **`ui_button.gd` 明确为唯一播放点**，新增 `@export var click_sound`（`COIN` / `CONFIRM`），想换音色改这个属性而不是在场景里补一句；② **`SoundManage` 加去重闸**（`DEDUPE_WINDOW = 30ms`，两条通道共用一把闸）—— 无论谁多播一次都只会听到一声，跨通道的 `coin + confirm` 也互斥；③ 在 `ui_button.gd` / `title.gd` / `sound/CREDITS.md` 写明约定。验证：11 个实例播音处理函数都恰好 1 个、紧随的第二次请求与跨通道请求都被吃掉、超过 30ms 后能正常再响、`level_select`/`pause_menu`/`result_screen` 都不自己播音 |
| 2026-09-13 | 暂停菜单双击音排查 | v5.9 | 反馈「暂停菜单的按钮点一下响两声」。真机复现（加载 `map.tscn` → `paused = true` → 打开暂停菜单）后测得：`btnResume.pressed` 上只有 **2 条**连接（`btnResume._on_pressed` 播音 + `pauseMenu.<lambda>` 发信号），单次 `pressed` 只播 **1 声**；栈追踪也确认 `[SoundManage] play effect ← ui_button.gd _on_pressed()` **只有一个调用点** —— 磁盘上没有能播两声的代码路径。但**一次点击被重复派发**（重复事件 / 两条路径）确实会响两声，因此加了两道保险：① **`ui_button.gd` 按钮级连点保护**（`CLICK_GUARD_MSEC = 120`，同一按钮 120ms 内只认一次，不同按钮互不影响）；② 保留 `SoundManage` 的 30ms 全局去重闸。另加 **`SoundManage.trace_plays`**（调试版自动开）—— 真还听到两声时看控制台哪两条栈都触发了。排查中踩的坑：测试里按 `btnRestart` 会触发 `reload_current_scene()`，导致测试场景自我套娃（日志里 `map` 打印 79 次），测按钮前必须先断开换场景回调；headless 下帧极快，各测试段之间要隔 200ms 才能让保护窗口/去重闸清空，否则会出现假阴性 |
| 2026-09-13 | 顶栏按钮音收口 | v6.0 | 用户指出多出来的那一声来自 **title 场景**。查明根因：顶栏 5 个按钮是 `menuBtn.tscn`，本身**没有脚本、不出声**，所以上一轮我给 `title.gd` 的 5 个处理函数补了 `playConfirm()`。**问题出在 `btnStart` 是 `toggle_mode = true` 的 ▶/⏸ 切换按钮**：① `toggled` 在状态来回切时都会触发，配合 `pauseGame()`/`resumeGame()` 不同步按钮状态，一旦状态错位，后续点击的 `toggled` 方向就反过来，声音时机跟着错乱；② 两套按钮模式（`ui_button` 自带音 vs `menuBtn` 场景补音）混用本身就是"一声变两声"的温床。改法：**新增 `menu_btn.gd` 挂到 `menuBtn.tscn`**，`_ready()` 里按内部按钮是否为 `toggle_mode` 去接 `toggled` 或 `pressed`，点击音回到按钮自己身上；**`title.gd` 删掉全部 5 处 `playConfirm()`**；`map.gd` 的 `startGame`/`pauseGame`/`resumeGame` 改用新增的 **`title.set_pause_button()`**（内部 `set_pressed_no_signal`）同步 ▶/⏸ 状态 —— **直接写 `button_pressed` 会触发 `toggled` 再发一次信号并多响一声**。验证：点 ▶ 只响 1 声且状态同步、点 ⏸ 只响 1 声、`set_pause_button` 连调 3 次 0 声、暂停菜单 Resume 只响 1 声且 HUD 跟着回位 |
| 2026-09-13 | 三个手感问题 | v6.1 | 用户报的三个问题，根因都是一句话：**状态变了却没通知该重绘/该同步的人**。① **技能取消后黄色范围圈不消失** —— `map.gd::_physics_process` 只在 `AbilityManager.is_selecting_position()` 为真时 `queue_redraw()`，**取消后再没人调 `_draw`，最后一帧的圈就留在画布上**（和 `laser_tower.gd` 里那句注释是同一个坑）。修法：`_ready` 里把 `selection_started` / `selection_ended` 都接到 `_on_ability_selection_changed()` → `queue_redraw()`。② **顶栏 ▶/⏸ 图标和状态对不上** —— 这个是上一版 v6.0 我自己引入的：`set_pause_button()` 的参数语义**写反了**（运行中应为按下/⏸，我传的是 false），导致运行中仍显示 ▶，点一下反而暂停；用暂停菜单 Resume 后图标也不回 ⏸。修法：方法改名 **`set_playing(playing)`** 并在注释里写清「`button_pressed=true` → ⏸ → 意思是运行中」，`startGame`/`resumeGame` 传 `true`、`pauseGame` 传 `false`。**`title.tscn` 的贴图无需改动**（`texture_normal`=▶、`texture_pressed`=⏸ 本来就是对的），`title.gd` 的信号分支也无需改动。验证：技能选中→取消全链路、初始 ▶ / startGame ⏸ / pauseGame ▶ / Resume 回 ⏸、且每次同步 0 声、恢复后再点能正常暂停 |
| 2026-09-16 | 能力技能系统     | v1.0 | 实现：`autoload/ability_manager.gd`（Autoload `AbilityManager`）+ `scene/ability_bar.tscn`（地图左侧技能条）。单个图标抽成通用场景 `scene/ability_slot.tscn`，内置 `Timer` 作为冷却唯一来源，冷却遮罩改用 `shader/ability_cooldown.gdshader` 顺时针扇形扫描（材质 `resource_local_to_scene`）。技能开关集中在 `StageData.stageAbilities` 配置表，未配置的关卡不显示技能条。首批两个技能：区域轰炸（点地图范围伤害 200 / 半径 140 / CD 30s）、塔防御护盾（点地图使范围内所有塔无敌 8s / 半径 220 / CD 45s，**按需求由点选单塔改为范围生效**）。图标暂用占位素材 |
| 2026-09-20 | 敌人出发偏移（贴传送带） | v1.0 | 需求：有些关卡的路线两边各压着一条传送带（如 `level_1` 的路线正好走在两排皮带中间的缝上），敌人贴着中线走看着「错位」，要给敌人加一个**非随机**的横向偏移。实现：`StageData.allStage` 的 `enemySpawner` 每条支持可选键 **`'offset'`**（像素，默认 0 = 老关卡行为不变）；`base_level.gd::_spawn_enemy()` 在 `add_child` **之后**把它写到敌人根节点（PathFollow2D）的 `v_offset` 上。偏移算在**路线自己的坐标系**里，所以是固定值、拐弯时跟着一起拐、全程平行于中线（不是随机抖动，也不会越走越偏）；**正 = 行进方向的右侧，负 = 左侧**。同一波想让敌人分走两条带子，就写两条 `time` 相同、`offset` 相反、`route` 相同的记录。`±32` = 半个格子，正好从缝上挪到某条带子中心。校验：`level_1` 的皮带是两格宽带（rows 3/4 cols 0..11 → cols 10/11 rows 5..10 → rows 1/2 cols 10..29），而路线点正好落在边界线上（y=256 / x=704 / y=128），所以一个 `±32` 就能全程贴住同一条带子 |
| 2026-09-20 | 传送带 / 塔位基座改 AnimatedSprite2D | v1.0 | 需求：传送带要能挂多套动画、**按方向选动画**，之后还要加不同类型（外观）的皮带；可建造格同理要能换多张图。① **`scene/belt.tscn` 根节点 `Sprite2D` → `AnimatedSprite2D`**：方向不再由贴图文件名推出，而是看 `animation`（`belt_we.png` → 动画 `we`）。新增 `sprite/tile/belt_frames.tres`：12 个方向动画（4 直段 + 8 拐角），每个动画 1 帧 = 原来那张 PNG —— **往动画里加帧就是动画**，节奏由 SpriteFrames 的 `speed` 决定。② `script/belt.gd`：`get_key()` 改读动画名（兼容 `we` / `belt_we` / `belt_fast_we` 三种命名），新增 `set_direction()`；`_ready()` 里先 `_ensure_animation()`（动画名对不上就回落 `we` / 第一个动画，免得 `play()` 报错）再 `play()`；删掉已无意义的 `speed` 导出。③ **换皮带类型 = 换 `sprite_frames`**（如 `belt_frames_fast.tres`），动画名沿用同一套方向名即可，脚本无需改动。④ `scene/placeable_area.tscn` 的子节点 `slot` 同样 `Sprite2D` → `AnimatedSprite2D`，新增 `sprite/tile/floor_slot_frames.tres`（动画 `default`，1 帧 = `floor_slot.png`），`placeable_area.gd` 负责替它起跑动画。⑤ **关卡场景同步迁移**：`level_1..15` 共 **1958 个** belt 实例的 `texture = ExtResource("N_belt_xx")` 全部改成 `animation = &"xx"`，并删掉因此变孤立的 7~10 条 `belt_*.png` ext_resource、重算 `load_steps`（脚本批量改 + 逐文件校验：覆盖数 == 节点数、残留 texture 引用 0）。`level_tutorial.tscn` 的 30 个 belt 本来就没覆盖贴图（方向一直走场景默认），无需改。⑥ `material` 仍挂在 AnimatedSprite2D 上，`shader/belt_flow.gdshader` 的 `route_phase` 明暗波机制**完全不变** |
| 2026-09-25 | 特斯拉线圈塔重做为「磁暴线圈坦克」 | v6.0 | 需求：按**红警3 磁暴线圈坦克**的读法重画特斯拉线圈防御塔素材。设计定为 **俯视装甲平台 + 对角线两座线圈立柱（柱顶一对金属大电极球）+ 球间磁暴电弧**：平台是圆滑八边形（投影 + 外缘亮边 + 内圈分缝 + 四角装甲块 + 上下安全黄警示条 + 右上/左下通风格栅），两座线圈对角摆（柱基环 → 柱身绕组 → 柱顶电极球），球间拉一道**电青电弧**（白芯、断开两段、带两处细分支）。**V5 → V6 的六次返工都记在 `art_style.md` §6**：① 左右并排的双柱在俯视里右柱会被左柱压住 → 改对角线（顺便吃满 128×128 的对角长度，两球间距才够拉电弧）；② 球画太大、柱身全被埋 → 缩小球、抬高柱基；③ 电弧画到 4.4px 宽读成**电缆/传动带** → 外晕收到 2.4、青体 1.3、白芯 0.75 并断开两段，才立住成"放电"；④ 中央集流环和电弧抢读、变成一个金属疙瘩 → 只留一颗埋进主梁的指示灯。产出 **128×128**（`gridSize = (2,2)` 不变，`base` 仍故意留空，`Marker2D` 30 / 不旋转 → 无需改任何 `.tscn`），配色按用户选择用**项目银 + 电青**（A 版），图鉴图标 `sprite/icon/unit/teslaCoilTower.png` 一并重出（旧的还是 V5 之前的低对比度版本）。生成器：`.td_verify/tower_lib.ps1`（绘制工具箱）+ `.td_verify/gen_tesla_v9.ps1`（定稿版），1:1 战场预览 `.td_verify/preview_tesla.ps1`。验证：Godot 4.7.1 真机跑 `tower_runtime_check` —— 七座塔的节点/贴图/尺寸断言**全绿**，`import 错误（无）`，截图确认新塔在关卡里正常渲染（`design/tower_tesla_ingame.png`） |
| 2026-09-25 | 火箭塔改单枚导弹 + 圆形底盘 | v6.1 | 需求：① 火箭发射塔改成**只有一个导弹的发射架**；② 底盘改成**圆形**。① `turret_rocket.png`（仍 **80×64**、轴心 (32,32)）由「抬高边框四联装发射箱 + 4 枚出膛导弹」重做为**轴心转盘 + 低矮基座 + U 形托槽 + 1 枚导弹**：弹体用**竖截面距离场**画（尾部收口 + 椭圆锥头 + 4 道深色分段环 + 分阶明暗），配两片后掠实心尾翼 + 一道黄警示环 + 轴心 6 颗黄螺栓。② 新增 **`sprite/tower/base_round_launch.png`（48×48）圆形发射台**：外环台面 + 内圈凹槽 + 中央承力台（带轴孔）+ 四角固定爪 + 8 颗黄螺栓；`rocketTower.tscn` 的 `base` 由 `base_plate.png` 换成它（**方板留给 EMP 独用**）。③ 弹头前移到轴心右侧 44px，`Marker2D.position.x` 与 `spark.offset.x` 同步 **45 / 34 → 53**（旧值是按四联装弹头位置定的，不改会出现"导弹还没飞到敌人就已经爆"）。**两处返工**：架体第一版做了"后方大箱 + 液压斜撑 + 前托架"，三条斜线交叉在 1:1 下读成乱线 → 做减法只留托槽；托槽槽口算得刚好与弹体相切，1:1 时透出 1px 缝读成"导弹浮着" → 槽口咬进弹体 2px。**旋转塔特有的坑**：弹体照旧版铺到画布左缘（旧版 bbox x=1..57），转到 180° 时弹尾会被 80×64 画布裁掉 → 弹体收到 x=22..76，两侧留 14px / 2px。验证：新增 `.td_verify/rocket_rot_check.ps1` 出 12 角度 × 2 底盘的旋转检查图；Godot 4.7.1 真机跑 `tower_runtime_check` —— 火箭塔节点/贴图/尺寸断言全绿，`import 错误（无）`。详见 `art_style.md` §6 |

| 2026-10-02 | 实验坦克（多炮塔敌人） | v1.0 | 需求：新增一种会**用炮塔攻击防御塔**的重装敌人。① `Game.enemyType` 加 `experimentalTank`，`Game.enemyInfo` 加一条数据（hp 900 / speed 28 / reward 40 / armor 0.5 / **单塔** atk 16 · 0.8s / scope 300），并新增行为定位 `_EnemyRole_fortress`（要塞型）。② 场景 `scene/enemy/experimental_tank.tscn` 继承 `enemy.tscn`：车体**不参战**，四角挂 **4 座 `BaseTurret`**（复用 `scene/turret/base_turret.tscn`，`ownerType = ENEMY`）各自索敌 / 转向 / 开火，车体自带的 `turret` 隐藏；移动与逃脱结算沿用 `enemy.gd`，`experimentalTank.gd` 只做 `setupEnemyInfo()`。③ 新增美术 `experimental_tank_body.svg`（96×96 四座圈底盘）+ `experimental_tank_turret.svg`（56×24，轴心 (20,12) → `offset (8,0)` / `muzzleOffset 32`）+ 图鉴图标 `sprite/icon/unit/experimental_tank.svg`，`.import` 一并入库。④ 配套数据：`StageData.enemyScenes`、`ENEMY_SPAWN_DELAY`（3.4 单独一档）、`base_level.gd` 分道幅度、`codex_panel.gd`（图标 + 要塞型说明）、`language.csv`（名称 / 定位 / 说明）。**未加入任何关卡波次**，需要时往 `allStage` 的 `enemySpawner` 写一条即可 |

| 2026-10-02 | 火箭弹追踪（子弹自带雷达） | v1.0 | 需求：火箭塔打不中人（子弹 300 像素/秒直射，目标稍一移动就擦身而过，然后拖到 5 秒寿命才自炸）。做法：① `scene/bullet/rocketbullet.tscn` 新增 `Radar` 子节点（Area2D，`collision_layer = 0` / `collision_mask = 2`，`CircleShape2D` 半径 170），`area_entered` / `area_exited` 接到子弹脚本；② `script/bullet/rocketbullet.gd` 维护雷达圈内候选敌人，每物理帧取"最近的、仍有效的、且 `flying` 与出膛时 `targetFlying` 一致"的目标，用有限角速度 `@export turnSpeed`（默认 5 弧度/秒 ≈ 60 像素转弯半径）把 `angle` **逐渐**转过去并同步 `rotation`，再沿更新后的方向前进；③ 速度由写死的 300 提为 `@export bulletSpeed` 方便调手感。命中判定与爆炸逻辑不变（bomb 仍用 `filterFlyingTargets` + `targetFlying` 只伤同类，"只追同类"正是为了不和爆炸过滤打架）。**注意**：`base_turret.gd` 上一轮已改为"按炮塔自己位置选最近目标"，与本次互不影响 |

| 2026-10-02 | 特殊敌人掉落宝石 | v1.0 | 需求：给敌人加"宝石奖励"作为**特殊奖励** —— 只有特殊敌人被击败才掉，数量 1 / 2 / 不掉。做法：① `Game.enemyInfo` 每种敌人新增 `gemReward` 字段（普通敌人 `0`，写进字段说明；目前只有 `experimentalTank = 2`）；② `Enemy` 增加 `@export gemReward`，`setupEnemyInfo()` 从表里读；③ 击败时 `enemy.gd` 发新信号 `Game.gemRewarded(amount)`（`gemReward <= 0` 不发），`map` 接收后 `UserData.addGem()` 入账 + **立即 `savePlayerData()`**（中途掉落的宝石不能等结算才落盘，玩家可能在结算前退出）+ 复用 `AbilityManager.gemChanged` 刷新顶栏与技能条 + `addNotice(_GemPicked)` 青色提示。**注意**：宝石在关卡内就能用（技能消耗），这是有意为之；若担心"反复重开刷宝石"，把 `gemReward` 改回 0 即可 |

| 2026-10-02 | 战斗飞机（飞越型空中敌人） | v1.0 | 需求：新增一种"飞越地图"的飞行敌人 —— 会打防御塔、走**自己的一条独立路线**（横跨全图）、逃脱不扣基地血、有概率掉宝石，定位是"增加乐趣"。做法：① `Game.enemyType` 加 `battlePlane`，`enemyInfo` 加一条（hp 220 / speed 130 / flying / atk 12 · 0.5s / scope 320 / **lossPoints 0** / `gemReward 1` + `gemRewardChance 0.5`）。② 新字段 `gemRewardChance`（不写 = 1.0）：`enemy.gd` 掉落时先过 `randf() <= gemRewardChance`，"不是每只都掉"。③ `script/enemy/battlePlane.gd` 覆写 `_physics_process()` —— 到终点**静静 `queue_free()`，不发 `Game.enemyEscaped`**（否则 map 会播"漏怪"锣，对一架本来就不扣血的飞机是误导）；开火逻辑与攻击直升机同款。④ 新场景 `scene/enemy/battle_plane.tscn`（`turret` 隐藏当瞄准参考、`muzzleOffset 28`）+ 美术 `battle_plane_body.svg` / 图鉴图标 `battle_plane.svg`。⑤ **教程关新增路线2**：`level_tutorial.tscn` 加 `Curve2D_r2_0` + `Path2D2`（`(-96,128) → (880,560) → (2016,1010)` 的顺畅斜线，从画面左上飞入、右下飞出，中途正好压过建造区），`beltLayer/placeableLayer/propLayer` 的 `index` 顺延 6/7/8；`stageData` 的 Tutorial `'routes'` 1→2，第 4/7/10 波各出 2/2/3 架（全关 +7 个敌人）。**注意**：飞机在场时"本波清空"判定会等它飞出屏幕（约 18 秒），但它总是排在波次最前、远早于该波刷完，所以不拖节奏 |

| 2026-10-03 | 实验坦克外形调整 | v1.1 | 需求：车身**变窄拉长**、炮塔**变短**。① `experimental_tank_body.svg`（96×96 不变）：装甲面 76×56 → **84×40**（更长更窄），履带高度 22 → 18 并把上下履带收进 `y 14..32 / 64..82`，投影同步收窄；② `experimental_tank_turret.svg` 画布 56×24 → **48×24**，炮管（含炮口）从 52 收到 **42**，座圈 r 10 → 8；随之 `Turret` 的 `offset` `(8,0)` → `(6,0)`、每座炮塔 `muzzleOffset` `32` → `24`（子弹仍从炮口出）；③ 四座挂点从 `(±18,±16)` 收到 `(±20,±10)`（贴合新装甲面的 4 个座圈，座圈 r 10 → 9），主碰撞盒 `(72,58)` → `(80,40)`；④ 图鉴图标按新比例重画。验证：浏览器把 body + 4×turret 按场景数值装配，四个炮塔正好落在车身座圈上 |

| 2026-10-03 | 敌人素材统一为平涂 | v1.0 | 需求：敌人素材风格与防御塔不一致（塔没有用渐变）。排查：全工程 `sprite/` 下只有 **13 个文件**用了 `linearGradient`，全部是敌人侧 —— 迷你 / 中型 / 重型 / 装甲坦克的 body+turret、实验坦克 body+turret、战斗飞机的 body、以及实验坦克 / 战斗飞机两张图鉴图标（突击车 / 维修车 / 自爆车 / 导弹车 / 侦察无人机 / 攻击直升机原本就是平涂）。做法：删掉 `<defs>` 渐变块，把渐变引用换成同色阶的实色 —— 主装甲 `url(#armor\|#hull)` → `#566c86`、履带 `url(#track)` → `#333c57`、炮塔盘 → `#94b0c2`（与已平涂敌人的"壳 `#566c86` + 炮塔 `#94b0c2`"约定一致）；原有的 `#dceaf2` 受光顶面 / `#333c57` 压暗块 / `#1a1c2c` 描边全部保留，所以体积感靠"平涂 + 分块"表达，正是塔的画法。**未改动任何几何形状、尺寸、挂点与 `.import`**（图鉴图标与单位素材都只是换填充），因此不受影响的场景无需同步。验证：全工程 `grep linearGradient\|url(#` **0 命中**；20 张 enemy/icon SVG 全部 XML 合法；浏览器把平涂后的 4 种坦克 + 实验坦克 + 战斗飞机 + 两张图标与塔的美术并排比对，色阶与画法一致 |

| 2026-10-03 | 图鉴卡片 / 图标 / 详情栏 | v1.0 | 需求三条 + 一个 bug。① **卡片不显示名字**：删掉 `codex_card.tscn` 的 `nameLabel` 与 `codex_card.gd` 里对应的读写，卡片只剩一张单位图（名字仍在悬停 tooltip 和底部详情栏）；② **卡片素材换成新图**：排查发现 `sprite/icon/unit/*.png` 里的**敌人图标还是最初美术包的旧图**（棕色老坦克），而塔的图标在 v6/v7 重绘时已同步 —— 于是新增生成器 `tools/codex_icon_gen.html` + `tools/codex_icon_server.py`，在浏览器里把**游戏里的真实素材分层合成**（车体先画、炮塔 / 旋翼后画；炮塔轴心与挂点由场景里的 `offset` 反推）再光栅化，直接写出 12 张 160×160 PNG；表里 id 10/11 由 SVG 改指 PNG，两张手绘 SVG 图标（含 `.import`）随之删除；③ **详情栏左侧图标放大**：`IconCenter` 104→168、`detailIcon` 96→160、`DetailBox` 最小高 216→282；④ 顺带修 bug：**实验坦克图标的炮塔画在车体之前**，看起来像"炮塔埋在车身下面" —— 新合成器一律把炮塔画在车体之上，实验坦克的 4 座炮塔还按四角挂点朝外摆，读图更清楚。只动图标与图鉴 UI，**没有改任何战斗数值、场景与挂点** |

| 2026-10-03 | 图鉴图标（补防御塔 + 归一化） | v1.1 | 承接上一条。用户指出"**防御塔没有替换**"——查证确实如此：那条只重出了敌人，塔的图标仍停留在 `rocketTower.png`＝方板 + 四联装（现行是圆形发射台 + 单管架）、`EMPTower.png`＝旧造型那一代，只有特斯拉在 v6.0 同步过。做法：① 生成器配置抽成通用的 `layers`（`pivot` 轴心 / `target` 落点 / `deg` / `s` 缩放），把 **8 座塔**也纳入 —— 塔的 `turret.offset` / `scale` 直接照抄各塔场景（机枪 0 · 加农 (10,0) · 火箭 (8,0)×0.6 · EMP·铁箱 0 · 激光 ×0.6；无人机与特斯拉只有一层），素材用 `sprite/tower/redesigned/*.svg`（已核对：**每张 SVG 母稿尺寸与场景里用的 PNG 完全一致**，用矢量才能在小塔被放大时保持清晰）；② 20 张图标统一按"包围盒最大边归一化"到 192×192（单位占约 70%），网格视觉尺寸才整齐；③ 过程中踩了一个坑：第一版轴心变换多算了一次 `pivot`（写成 `translate(pivot+target) …`），导致底座与炮塔各按自己的轴心错位（机枪塔看起来"底座缩在左上角"），改为 `translate(target) rotate(deg) scale(s) translate(-pivot)` 后正常。仍**未改动任何战斗数值、场景与挂点** |

| 2026-10-03 | 敌人炮口位置（muzzleOffset） | v1.0 | 需求：**子弹发射位置不准** —— 有炮塔的敌人是从**炮塔轴心**（= 敌人体中心）出膛的，看起来像从车体/肚子里飞出来；独立炮塔（`BaseTurret`）同样只认轴心。做法：① 基场景 `enemy.tscn` 在 `turret` 下新增 **1 个 `Muzzle` Marker2D**（12 种敌人全部继承，插在 `turret` 与 `shape` 之间，**不改变任何子节点 index**，派生场景无需同步）；② `enemy.gd` 新增 `@onready muzzleMarker`，由 `setupEnemyInfo()` 把 `Vector2(muzzleOffset, 0)` 写进标记。**成员故意不叫 `muzzle`** —— `attackTower()` 及 `mediumTank` / `missileTruck` / `attackHelicopter` / `battlePlane` 里都有 `var muzzle: Vector2` 局部变量，重名会触发 `SHADOWED_VARIABLE`。标记位置**必须由代码写**：基场景里的 Marker2D 是 (0,0)，子场景的覆盖只要在编辑器里保存一次就会被丢掉（防御塔那边特斯拉已经丢过一次，表现是"闪电从塔中心发出来"，见 `tower.gd` 的 `muzzleOffset` 注释）。③ `getMuzzlePosition()` 改为"有**可见**炮塔 → `turret/Muzzle`（跟着炮管转，正好在炮口）；没炮塔（直升机 / 飞机 / 卡车 / 突击车 / 无人机）→ 机身前方 `muzzleOffset` 处（跟着机头转）"，判断条件仍是 `turret.visible`（基场景自带的 turret 节点在派生场景里删不掉，只能用 `visible = false` 表达"这个敌人没有炮塔"）。④ `mediumTank.gd` 原来直写 `turret.global_position` 且绕过该函数，改为 `getMuzzlePosition()`；顺带把 `mediumTank` / `missileTruck` 的 `fire(target)` 形参改名 `towerTarget`（与另两个脚本统一，且不再遮蔽基类成员 `var target`）。**取值全部实测、不靠估算**：用浏览器按场景里的 `position` / `offset` 把"车体 + 炮塔"真素材分层合成到 canvas，再扫**开火高度上最靠右的绘制像素**反推（该高度上炮管/车头一定是最右的图元）。结果：迷你 26 / 中型 29 / 重型 33 / 装甲 35（四辆坦克原取值正确）、突击车 23、维修车 24、自爆车 27、导弹车 27、无人机 15、直升机 26、**实验坦克 46**（车体素材是 96×96，轴心在 48 不是 32，按 64 算会少 14px）、战斗飞机 27；重复扫描后 13 项（含实验坦克 4 座独立炮塔的 24）与实测值偏差均 ≤0.7px（抗锯齿测量误差）。⑤ 顺带修同类 bug：`rocketTower.tscn` 的 `muzzleOffset` 早先被丢成 0（火箭从塔中心出膛），按同一方法补回 **41**。验证：17 个改动文件 `get_errors` 全绿；临时测量脚本与校验页用完即删 |

| 2026-10-03 | 车轮改俯视角 | v1.0 | 需求：突击车这类**没有履带**的敌人，车轮画成了圆 —— 圆是**侧视图**的读法，俯视角看到的应该是车轮的**接地面**（沿车头方向拉长的圆角矩形）。做法：`sprite/enemy/redesigned/` 里 4 种带轮敌人（突击车 / 维修车 / 自爆卡车 / 导弹车）的"轮胎 + 轮毂"两组 `<circle>` 全部换成 `<rect rx>` 胶囊形：轮胎 **14×8**（原来是 r=6 的圆，即 12×12）、轮毂 **8×4**（原来 r=3）；**轮心坐标一个都没动**，所以轮距、挂点、碰撞盒、上一版的 `muzzleOffset` 全部不受影响。尺寸是拿对比图定的：先试 12×8（1.5:1），在图标那种小尺寸下仍偏圆，最后定 **14×8（1.75:1）**；长轴沿 X（车头方向），与坦克履带用 `<rect rx="5">` 是同一种画法（`svg` 的 `shape-rendering="crispEdges"` 也沿用，保持硬边风格）。只改这 4 个 SVG 的车轮图元，**未改任何几何位置、图层顺序、场景与数值**。② 同步重出**图鉴图标**：`assault_buggy.png` / `medic.png` / `suicide_truck.png` / `missile_truck.png` 四张，其余 16 张字节完全不变（说明只影响这 4 个）。③ 顺带修工具坑：给 `tools/codex_icon_gen.html` 取素材的 `fetch` 加 **cache-buster**。踩的坑记一下：改完素材重跑生成器，浏览器命中缓存拿到旧 SVG，图标"看着没变"；更隐蔽的是**生成器页面本身也会被缓存**，那时连新加的 cache-buster 都不生效 —— 必须用带参数（`?v=xxx`）的 URL 打开页面才会加载新 JS。验证：图标里量到的轮宽 **34px**（14×8 预期 33.5，12×8 则应是 29），4 张图标字节数全部变化而其余不变 |

| 2026-10-03 | 自爆车 / 导弹车货厢重画 | v1.0 | 需求：这两辆车"**没有车身、画的也是乱的**" —— 自爆卡车的车身应该是**炸药**，导弹车的应该是**发射管**。1:1 放大旧素材后确认三处硬伤：① **货厢是空箱子**（一块纯灰矩形），完全读不出这台车干什么；② **货厢压进驾驶室**（货厢 x 9~38、驾驶室 x 32~58，重叠 **6px**），两坨糊在一起；③ 货厢里那两条**锯齿状 `<path>`**（本意是货/导弹，实际画成了"梳子"）再叠上两条横线，1:1 下就是一团乱线。重画方案：两车共用同一套**底盘 + 驾驶室 + 三轴车轮**，只换货厢 —— 自爆车 = **一枚带尾翼的炸弹**（14×8 机身、尾部菱形尾翼、顶端受光 + 底端压暗、机身橙色危险环、深色弹头帽、尾门三段危险条纹）；导弹车 = **双发射管**（亮银管身 + 顶端受光条 + 前端 `#333C57` 管口套 + 内层深色 + 亮色管芯，画法照抄火箭塔 `turret_rocket.svg` 的发射箱）。顺带一起改掉的：④ 车轮从 2 轴 4 轮补成 **3 轴 6 轮**（驾驶室下面原来没有前轮，车头是悬空的）；⑤ 驾驶室统一成"亮银块 + 深色风挡 + 方形舱盖 + 橙色示警灯"，且**与货厢之间留 2px 间隙**。**未改任何场景与数值**：重画后用同一套像素扫描复核，开火高度上最靠右的绘制像素仍是 **27** → 两车的 `muzzleOffset = 27.0` 不用动。同步重出 `suicide_truck.png` / `missile_truck.png` 两张图鉴图标（其余 18 张字节不变）。规范沉淀到 `art_style.md` §6「敌人车辆的读法」。验证：SVG XML 合法；4 倍放大对比图确认"车轮 / 驾驶室 / 货厢"三者分离可读；图标放大复核确认新车身 |

| 2026-10-03 | 轻型载具改履带 | v1.0 | 承接上一条：用户看过车轮版后改主意 —— "**还是都换成履带吧，小一点就行了**"。做法：把 4 种轻型载具（突击车 / 维修车 / 自爆卡车 / 导弹车）的**车轮整组（"轮胎 + 轮毂"两块 `<g>`）删掉，换成坦克那套履带**：`fill #333c57` + `stroke #101820` 1.5 的 `<rect rx="4">` 胶囊，两侧各一条、上下对称于载具中线，再叠一列 **5 根亮色履带齿**（`#94b0c2`，2 宽 × 6 高，等距 9）。尺寸比坦克**小一档**（坦克 13~15 高 / 长 50~56 / 6 根齿；轻型载具 **9 高 / 长 43~48 / 5 根齿**），且履带长度正好落在原车轮的外缘范围内，所以**整车轮廓一点没变** —— 相当于把 2~3 对轮子"连"成一条带子。**未改任何场景与数值**：换完重新扫像素，4 辆车的炮口值仍是 **23 / 24 / 27 / 27** = 场景现值，`muzzleOffset` 一个都不用动。同步重出 4 张图鉴图标（`assault_buggy.png` / `medic.png` / `suicide_truck.png` / `missile_truck.png`，其余 16 张字节不变）。`art_style.md` §6「敌人车辆的读法」同步改成"一律走履带 + 尺寸分两档 + 履带齿是识别记号"。验证：SVG XML 合法；与 2 辆坦克同屏 2.6 倍对比图确认履带齿节奏一致但视觉分量明显小一档 |

| 2026-10-03 | 教程关战斗飞机走错路线 | v1.0 | 反馈："**战斗飞机在教程关卡中没有出现在独立的路线上**"。根因：`base_level.gd::_spawnEnemy()` 取路线写的是 `getRoute(int(spawnInfo.get("route", 1)))` —— **`enemySpawner` 里不写 `'route'` 就默认走路线1**；而教程关那三条战斗飞机记录（第 4 / 7 / 10 波）**全都漏了 `'route': 2`**，于是飞机被塞到路线1（地面传送带那条直线）上飞，独立航线 `Path2D2` 从头到尾是空的。修法：三条记录补上 `'route': 2`，并在第一条上方写明"不写就走路线1"这个坑。核对无误：教程关 `'routes': 2` 与场景里 `Path2D`(index 4) / `Path2D2`(index 5) 数量一致，`getRoute(2)` → `routes[1]` = Path2D2（曲线 `Curve2D_r2_0` = (−96,128) → (880,560) → (2016,1010)，横跨全图的对角航线）✓。**只改关卡数据，无代码改动** |

| 2026-10-03 | rocketTower.tscn 解析报错 + 火箭炮口值修正 | v1.0 | 反馈：`Parse Error: Parse error. [Resource file res://scene/tower/rocketTower.tscn:171]`。根因是**我上一版往 `.tscn` 里写了 `#` 注释** —— `.tscn` / `.tres` 是 Godot 的文本资源格式，**不支持注释**，那两行写在 `muzzleOffset` 上方的说明直接把整个火箭塔场景搞成解析失败（同一个坑也在 `experimental_tank.tscn` 41~42 行埋着，只是那个场景还没被加载到）。修法：把 4 行 `#` 全删掉，说明改写到 `tower.gd` 的 `##` 文档注释与 `code_design.md`（§6.3 正文 + §8 审查清单各加一条，明确"`.tscn` 里不能写注释"）。② 借机核对炮口值，发现**我上一版给火箭塔填的 41 是错的**：当时按"发射管口在贴图 x≈73"估的，实测（把炮塔贴图按 1:1 画到 canvas 再扫像素）最右绘制像素是 **78**，正确值 = 78 − 80/2 + `turret.offset.x` 8 = **46**（机枪塔实测 30、场景现值 31；加农实测 49、场景现值 50 —— 各差 1px 属抗锯齿误差，都不用动）。③ 顺带修 `Spark.offset`：`muzzleOffset` 是 **turret 节点本地坐标**，而 `Spark` 挂在塔根节点下不受 `turret.scale` 影响，两者不是同一单位 —— 火箭塔 `scale = 0.6`，闪光原写 45（≈ 按世界坐标估的），比真正的炮口（46 × 0.6 ≈ 27.6）远出 17px，开火时闪光会飘在炮管外面。已改成 **28**，并在 `tower.gd` 的 `muzzleOffset` 注释里写明这个单位换算（`spark.offset.x = muzzleOffset × turret.scale`）。**只动 `rocketTower.tscn` 两个数值、`tower.gd` 注释与两份文档，无逻辑改动** |

| 2026-10-03 | 工具箱图标两态 | v1.0 | 需求：`towerUI` 的工具箱图标做成**两个** —— 一个**没打开**的，一个**打开**的（打开的那张里面放一把锤子）。做法：① 新增 `sprite/icon/ui/redesigned/toolbox_closed.svg`（关着：盖合上 + 提手 + 两枚安全黄卡扣 + 正面标签 / 铭牌 + 两侧卡扣）与 `toolbox_open.svg`（打开：**盖子连着提手一起掀到后面**、箱口露出深色内腔、里面立着一把锤子 —— 锤头带爪、柄上细下粗），沿用原工具箱图标的配色与像素硬边画法（`#5E7A8C` / `#94B0C2` / `#A8C0CE` / `#333C57` + 安全黄 `#FFC61A`）；`.import` 按老规矩手写（`path` 里的哈希 = md5(`res://` 路径)，已逐条核对）。② `tower_ui.gd` 加 `iconClosed` / `iconOpen` 两个 `preload` 与 `@onready toolboxIcon`，在 `_onIconGuiInput()` 里随 `isOpen` 换 `texture` —— 工具箱状态一眼可见，不再靠"把图标调暗到 0.5"暗示。③ 于是把 `tower_ui.tscn` 三个动画里的 `icon:modulate:a` 轨道删掉（只留 `ScrollContainer:visible`），图标不再变淡。④ 清掉被取代的旧素材：`sprite/icon/ui/toolbox.png`(+`.import`，原来只有"敞开 + 三把工具"一态) 与 `redesigned/toolbox.svg`(+`.import`)；两个新图标的 `uid` 直接沿用被删文件的那两个，所以 `tower_ui.tscn` 的 `ExtResource` 只改 `path` 不动 `uid`。验证：两张 SVG XML 合法；2× 与 1:1 并排渲染确认"合上 = 箱子 / 打开 = 掀盖 + 一把锤子"两态区分明确。**中途返工三轮**：提手高光画到立柱上导致提手读不出来 → 收回横梁内；锤子像 T 字尺 → 加锤爪、加厚锤头、柄改上细下粗；锤头和掀起的盖子挤在一起 → 盖子整体抬高、锤子降到箱口 |

| 2026-10-03 | 打开的工具箱去掉锤子 | v1.1 | 承接上一条：用户看过后要求"**打开的工具箱还是不要显示锤子了**"。做法：删掉 `toolbox_open.svg` 里锤子的 6 条 `<path>`（锤头 / 锤爪 / 柄 / 两条高光 / 底纹），空箱口保留深色内腔，另加一道 `#333C57` 内底（`M26 62H102V70`），免得开口只剩一块黑洞。`tower_ui.gd` 与 `tower_ui.tscn` **无需改动**（两态切换逻辑、文件名、`.import` 都没变）。验证：SVG XML 合法；2× 与 1:1 渲染复核"合上 = 关箱 / 打开 = 掀盖空箱"两态仍然一眼可分 |

| 2026-10-03 | 关卡1 双路线分离 + 竖直段带子朝向 | v1.0 | 反馈："关卡1的路线是两条，但是却放在一起，位置不对，传送带是两条，传送带位置如果是终点应该是屏幕外，重新调整一下"。排查：把 `level_1.tscn` 的 116 格传送带与 2 条 `Curve2D` 解析成格坐标后发现三处问题 —— ① 两条路线的绝大部分点都压在**两条带子车道的中分线**上（主干 `y=256`、竖直段 `x=704`、上支线 `y=128`），所以视觉上"两条路线叠在一起"；② 两条路线**都只走主干**（rows 3/4），上支线（rows 1/2）、下支线（rows 11/12）与竖直段（cols 10/11）**没有任何敌人经过**；③ 两处终点都落在 `x=1920`（＝场地右边界＝屏幕边缘），敌人正好在镜头边缘消失。修法（标准**双车道分流**：左车道转左栏、右车道转右栏）：路线1 = 主干**上车道** `y=224` → `col10` 转**北** → 上支线**内车道** `y=160` → 终点外扩到 `x=1984`（屏幕外 64px）；路线2 = 主干**下车道** `y=288` → `col11` 转**南** → 竖直段右车道 `x=736` → 下支线**内车道** `y=736` → 同样外扩到 `x=1984`；两条起点都从 `x=-80` 外移到 `x=-96`（同在屏幕外）。③ 竖直段 16 格原本**只有 `routePhase` 没有 `animation`**（渲染成横向"梯子"贴图）→ 按行进方向补齐 `wn`/`se`/`ns`/`ne` 等（含路线不经过的左栏 `col10` 与下支线 `row12`，让两条车道都读得通）。验证：写脚本把两条路线按格展开，逐格核对"这格有没有带子 + 带子朝向是否与行进方向一致" —— **34 格 / 40 格全部命中，问题数 0**；另出一张"真实带子贴图 + 路线"俯视图确认分流与拐角；`get_errors` 全绿；顺带确认关卡数据 `'routes': 2` 与场景 2 个 `Path2D` 一致，且 44 / 36 只小坦克本来就分别走 route 1 / route 2（所以问题正是"两条路线看起来是同一条"）。补充说明：带子最后一格到 `col29`（`x=1920`）为止，路线终点在其外 64px —— 这 64px 完全在屏幕外，看不到敌人走在空地上；相机被限制在场地内，所以**没有**再加场地外的带子格。踩坑记录：用正则替换 `PackedVector2Array(...)` 时替换串里自带了外层括号，而正则分组已经把 `PackedVector2Array(` 吃掉 → 生成 `PackedVector2Array((...))` **双层括号**，Godot 会解析失败；改成只替换括号内的坐标串。**只改场景里 2 条曲线与 18 格 `animation`，无代码与数值改动** |

| 2026-10-03 | 关卡 2-15 路线/传送带/塔位重建 | v1.0 | 用户做完关卡1 后要求："**后续 2-15 的关卡重新调整一下，如果有两条传送带肯定需要两条路线，可放置区域不能太多**"（拍板的做法：带子只留路线经过的格子；塔位约 80~95 格）。把 16 个关卡场景解析成格坐标后确认 4 个共性问题：① **两条路线全部压在两条带子车道的中分线上**（`y=384`、`x=448` 这类正好卡在格线上的坐标），所以视觉上"两条路线叠在一起"；② 路线**拐角是斜切过去的**，根本没踩在带子格上（例：关卡2 路线1 在 `x=1504`（第 23.5 列）拐弯，而带子竖直段在 22 列）；③ 13 个关卡的**终点正好落在场地右边缘 `x=1920`**，敌人在镜头边缘消失；④ 可放置格 73~155 格，普遍偏多。做法：① 先写校验器 `tools/level_tools/analyze.py` —— 逐格走两条路线，断言"横向段的 y / 纵向段的 x 必须是格中心（≡32 mod 64）""每格都要有带子""带子朝向必须等于该格的入口边+出口边"，把视觉问题变成可判定数据。② 再写重建器 `tools/level_tools/rebuild.py` —— **不再依赖（部分写错的）带子箭头**，改按**带子形状**搜路径：从原路线的入场格走到出场格，代价函数优先直行（避免台阶锯齿），并尽量避开另一条路线已占用的格子（于是共享入场、中途分叉或汇合的关卡会自动变成"两条并排车道"，如关卡4 顶部分成 14/15 两列、关卡7 出口分成 7/8 两行）；两端并排车道按"拐向哪一侧就走哪条"选，避免两股车流交叉。③ 求出路径后**带子朝向由路径反推**（入口边+出口边），顺手修掉原来写错的拐角。④ 带子只保留路径经过的格子（每段单车道，平均砍掉约 45%：112→59、181→63……），删掉的带子节点连同没人引用的 `ShaderMaterial`、方向贴图 `ext_resource` 一起清理，`beltLayer` 子节点 `index` 重排。⑤ 朝向写法从逐格 `texture = ExtResource(...belt_ns.png)` 覆盖**统一改成 `animation` / `autoplay`**（与关卡1 现在的写法和 `belt_frames.tres` 里 12 个方向动画一致，两者渲染结果相同），`routePhase` 按"从起点沿路线的弧长 − 0.25 格"重算（与旧数据同一约定：首格 1.75，每格 +1）。⑥ 两端延长到场外（≥64px，端点用 min/max 兜底），终点不再停在屏幕边缘。⑦ 塔位按"距新路线 ≤2 格"保留，超 95 格的关卡再挖掉最外侧整条带，落到 73~95 格。**踩坑**：第一次写回时把起点格的入口边取了两次反，生成非法方向 `ss`（校验器立刻报出来），修完从备份恢复重跑。验证：16 个场景全部**问题数 0**（全程走在车道中心、每格都有带子且朝向一致、起终点都在场外）；`.tscn` 无注释；每关仍为 2 个 `Path2D` 与 `'routes': 2` 一致；`get_errors` 全绿；另出 15 关缩略图总览（真实带子贴图 + 路线 + 塔位）肉眼核对。顺带修好教程关：路线1 终点原本停在 `x≈1856`（镜头内），已延到 `x=1984` 出屏。**只改关卡场景，无代码与数值改动**；改动前的场景备份在 `tools/level_tools/bak_before_20261003/` |

| 2026-10-04 | 关卡 5-15 加入实验坦克与战斗飞机（带独立空中航线） | v1.0 | 需求："**从第五关开始增加实验坦克和攻击飞机到关卡里面，攻击飞机单独路线，后续关卡逐步增加**"。按 `game.gd` 的设定拆成两种用法：`battlePlane` 是"**飞越地图的空中骚扰单位**"——不沿传送带走、`lossPoints = 0`（逃脱不扣基地血）、且只有无人机基地/激光塔/火箭塔打得到它，所以它必须走**自己的一条独立航线**；`experimentalTank` 是**4 座独立炮塔的地面要塞**，必须走地面传送带（路线 1/2）。做法：① 新增工具 `tools/level_tools/add_air_route.py`，给 5-15 关场景插入 `Curve2D_r3_<关卡>` 子资源 + `Path2D3` 节点，做成**横穿全图的空中航线**（3 个控制点、切线手柄取相邻点连线的 25%，与教程关那条航线同一种画法；两端都出屏 ≥64px；TL→BR 与 TR→BL 两种走向交替，避免每关都一样）。节点插在 `Path2D2` 之后、`index` 取当前根子节点最大值 +1，保证它排在两条地面路线之后 = **路线3**（`base_level.gd::_collectRoutes()` 按子节点顺序收集，第 3 个 Path2D 就是路线3）；关卡13 的场景根子节点**不写 `index`**（顺序由文件先后决定），工具按该文件自己的风格不写 index 插在 Path2D2 后面；每次插入后重算 `load_steps`。② 关卡数据 `'routes': 2` → `'routes': 3`，`enemySpawner` 追加两类记录：战斗飞机全部走 `'route': 3`；实验坦克分走路线 1 / 路线 2，**单辆时按关卡奇偶轮流给两条路线**（保证两条传送带都会出现实验坦克），不再产生 `'number': 0` 的空记录。③ 递增节奏（飞机 = 最后 N 波 × 每波 M 架；坦克 = 倒数第 2 波 a 辆 + 末波 b 辆）：关卡5 `1×2 / 1`、6 `1×2 / 1`、7 `1×3 / 2`、8 `2×3 / 2`、9 `2×4 / 3`、10 `2×4 / 3`、11 `2×6 / 4`、12 `3×5 / 4`、13 `3×6 / 5`、14 `3×6 / 5`、15 `3×7 / 6` —— 合计 **113 架战斗飞机、36 辆实验坦克**，两条曲线都不下降。④ 关卡5 的 `description` 补一句"实验坦克与战斗飞机（独立空中航线）首次亮相"。**不需要改代码**：`_spawnEnemy()` 本来就写着"'route' 不写就是路线1；写 2、3 …… 就从别的路线出发"，飞机的侧向 `v_offset` 散开也照常生效。验证：关卡 1-4 仍是 `routes=2` / 2 个 Path2D，关卡 5-15 全部 `routes=3` / 3 个 Path2D；每关 spawner 用到的路线号都 ≤ 声明数；11 条空中航线均为 3 点、两端出屏 64~160px；`get_errors` 全绿；无 `'number': 0` 记录。改动前的备份在 `tools/level_tools/bak_before_20261004/` |

| 2026-10-04 | 空中航线提示动画 | v1.0 | 需求："**战斗飞机的航线地图是没有显示出来的，所以应该加一个显示这个航线的动画，在出现这个航线的时候、敌人生成时，给玩家显示一个动画提醒敌人前进路线然后消失，在 baseLevel 里面增加这个空中航线的动画如果有的话**"。做法：① 新增 `scene/level/air_route_hint.tscn` + `script/level/air_route_hint.gd` —— 三层 [Line2D]：暗色底衬 14px（在半透明里把线从背景上"抠"出来）、航线主线 8px（警示黄 `#FFC61A`，透明度 0.65）、流光段 13px（满不透明的同色）。**不写 shader、不依赖任何贴图**，全靠 Line2D 折线 + **弧长切片**：`_sliceRoute(fromLen, toLen)` 按累计弧长取点，所以"生长"就是取 `0 → progress×总长`，"流光"就是取 `head → head+150px`、head 从 -150 跑到总长。② 时序（常量都在脚本顶部、配着来，流光两趟正好在淡出前进完）：底衬淡入 + 主线生长 0.55s → 流光 1.0s/趟 ×2（趟间 0.55s）→ 停留 2.0s → 淡出 0.7s → `queue_free()`，整段约 3.3s。③ `base_level.gd` 新增 `_collectBareRoutes()`：`_ready` 时逐条路线沿线采样、算"贴传送带的采样点占比"，**占比 < 50% 的算"玩家看不见的路线"**；`_spawnEnemy()` 里如果这次刷的敌人走的是这种路线，就 `_showRouteHint()` 画一次，**每一波最多画一次**（`_hintShownInWave` 在 `_onWaveTimerTimeout()` 开新一波时重置）。提示节点 `z_index = -1` → 压在敌人下面、盖在地面与传送带上面。**⚠️ 判据的关键坑**：最初想用"路线附近有没有传送带"，但**空中航线是横穿全图的，一定会从地面带子上方飞过** —— 那样判会得出"附近有带子 → 不用提示"的**相反**结论。必须看**整条路线有没有被带子铺满**，所以判据是占比而不是存在性。验证：写脚本 `tools/level_tools/check_route_coverage.py`，按 Curve2D 的三次贝塞尔（控制点 = 点 ± 手柄）精确采样每条路线 —— 16 个关卡的**地面路线占比 72~93%**（不提示）、**空中航线 9~31%**（提示）、教程关那条对角线 16.3%（提示），50% 阈值两边余量都很大；另在浏览器里按同一时序逐帧还原，确认线宽与配色（游戏是 1920×1080 画面显示在 960×540 窗口，线宽按这个折算，最终定 8/13px）。颜色与线宽全放在场景 Inspector 里，代码只管时序与切片；`AirRouteHint` 虽然写了 `class_name`，但 `base_level` 里用不写类型的局部变量动态调用，免得依赖工程重新扫描的时机 |

| 2026-10-04 | 航线提示：改成数据显式声明 + 虚线逐段点亮 | v1.1 | 承接上一条，用户两条反馈。① "**allStage 里面敌人出现哪里加个字段用来标记这一条航线是需要提示的航线，这样判断就会简单些**" —— 原来那套"算整条路线贴传送带的采样点占比 < 50%"虽然实测能用（地面路线 72~93%、空中航线 9~31%），但本质是**推断**：以后加一条空中航线、或某条地面路线恰好又短又少带子，都可能判错，而且看代码的人猜不出"它凭什么提示"。改法：`allStage` 每个关卡加 `'hintRoutes': [路线号…]`（不写 = 本关都不提示），战斗飞机那条空中航线直接写上；`StageData` 加 `getHintRoutes(stageId)`（与 `getRouteCount` 同款），`base_level.gd` **删掉** `_collectBareRoutes()` 和三个 `BARE_ROUTE_*` 常量，改成 `_ready` 里把声明的路线号读进 `hintRoutes: Array[int]`、`_spawnEnemy()` 里用 `routes.find(route) + 1 in hintRoutes` 判断。当前数据：教程关 `[2]`、关卡 5-15 `[3]`；数据格式说明也补进了 `allStage` 上方那段大注释。② "**提示的航线可以显示成虚线段，每一段逐步发亮会好点**" —— 原来是一条实线生长 + 一段流光，看起来像"一条路面"；改成**一截截虚线沿航向逐段点亮**：已亮段保持警示黄、正在亮的那一截换成更粗的**白亮色当"头"**（方向一眼可见）、还没亮的只留 22% 的淡影（先把整条走向透给玩家，好提前布防）。实现改为脚本自己的 `_draw()`（一截 = 一条 `draw_line`，虚线按弧长切，`dashLength 26 / dashGap 20`），场景里那两条 Line2D 随之删掉、只留暗色底衬 `Back`；点亮进度由 `tween_method(_setLitProgress)` 驱动，**只在"又亮了一截"时 `queue_redraw()`**，不每帧重画。时长：底衬淡入 0.5s → 逐段点亮 1.4s → 停留 1.2s → 淡出 0.7s（约 3.8s）。虚线长度/间隔/线宽/三种颜色全部 `@export`，在 `air_route_hint.tscn` 里调。验证：`get_errors` 全绿；校验脚本改成 `tools/level_tools/check_hint_routes.py` —— 逐条路线按三次贝塞尔精确采样算"贴传送带占比"，再跟数据里声明的 `hintRoutes` 对一遍（声明要提示的应该占比低、没声明的应该占比高），**16 个关卡总问题数 0**；另在浏览器里按同一时序还原三帧，确认"已亮黄段 + 白亮的头 + 前方淡影"三态在传送带旁边分得清 |

| 2026-10-04 | 战斗飞机改导弹 + 敌人行进动画 + 无人机旋翼 | v1.0 | 用户一次提了四条，这是其中三条（第四条轰炸技能见下一行）。① "**战斗飞机改成发射导弹**" —— `battlePlane.gd` 的 `bullet` 从普通子弹换成 `scene/bullet/enemy_missile.tscn`（现成的追尾导弹，`missileSpeed 220` / `turnSpeed 4` / 自带 `missile_smoke_trail` 拖尾），发射音效换成 `rocket_fire_b`；飞机本来就"飞过地图顺手轰塔"，导弹会自己修正方向，观感更像空中火力。② "**敌人移动生成一个简单的动画：车身履带错位，生成不同车身作为动画，动画速度快点**" —— 做法是**给每个载具再画一帧车身**：`<名称>_body_2.svg`，内容与第一帧**逐字节相同、只把履带齿沿履带方向平移半个齿距**（浅色齿块重新错位），两帧快速交替就是"履带在滚"。齿距各不相同，平移量按实测取：小坦克 / 中型坦克 / 重型坦克 / 装甲坦克齿距 8 → 平移 4，实验坦克齿距 12 → 平移 6，突击车 / 医疗车 / 自爆卡车 / 导弹车齿距 9 → 平移 4。实现细节：齿块 4 个坦克存在 `<g fill="#dceaf2">`、5 个轻型车存在 `<g fill="#94b0c2">`（**分组写法还不一样**：装甲坦克的 `<g>` 和内容在同一行，正则必须容忍），脚本两种颜色、两种换行都兼容。场景侧：9 个 `scene/enemy/*.tscn` 各加一条 `_body_2.svg` 的 `ext_resource`，车身 `SpriteFrames` 的 `default` 动画由 1 帧改 2 帧，`"speed"` **5.0 → 8.0**（"速度快点"）。**踩到一个必踩的坑**：全项目 `scene/enemy/*.tscn` 里**根本没有 `autoplay`、`enemy.gd` 里也没有 `play()`** —— 以前车身只有一帧，动画没播也看不出来；现在多帧了不播就是**白做**，所以在基场景 `enemy.tscn` 的 `base` 节点加 `autoplay = "default"`（一处生效、所有敌人继承）。③ "**无人机的素材小一点，四个轴改成旋转的动画**" —— `scout_drone_body.svg` 里那把"十字桨叶"删掉（只留四个座圈），新建 `scout_drone_rotor.svg`（22×22、**两叶** —— 只有两叶才看得出在转，四叶转起来像没动）；`scout_drone.tscn` 机体 `base` 缩到 **0.8**，四个座圈位置（SVG (14,14)/(50,14)/(14,50)/(50,50) 换算成局部 ∓18）摆 4 个 `Sprite2D`（`RotorFL/FR/BL/BR`，位置 ×0.8 = ∓14.4、同样缩 0.8），`scoutDrone.gd` 每帧转（`ROTOR_SPIN_SPEED 22.0` rad/s，**相邻两个反向转**，和攻击直升机主旋翼同一套写法）。碰撞体 `RectangleShape2D 30×30` **保持不动**（只缩视觉、不改手感）。验证：9 张 `_2.svg` 全部生成且 XML 合法、场景里每条 `_body_2.svg` 引用都能在磁盘上找到实体（**曾出现过一次悬空引用**：脚本漏了装甲坦克的齿分组，接线脚本照样写了引用 —— 所以查了这个）；`get_errors` 全绿；`.tscn` 无注释。工具：`tools/gen_enemy_frames.py` 保留（以后加新载具要再出一帧错位贴图），一次性的接线脚本 `wire_enemy_frames.py` / `wire_drone_rotors.py` 已删 |
| 2026-10-04 | 轰炸技能专属演出 | v1.0 | 需求："**使用轰炸技能时候，轰炸的动画要大点，粒子效果比如烟雾要有一个扩散的效果，视觉冲击要大，可单独做一个场景复用之前逻辑就好了**"。做法：新增 `scene/fx/bombard_strike.tscn` + `script/fx/bombard_strike.gd`，**完全复用现有爆炸资产**（不新画贴图）—— `play(radius)` 里按技能半径放大：中心叠一发大爆炸（`explosion.tscn`，缩放 `1.9 × k`）+ 火焰 / 火星 / 余烬三颗粒子（`1.6 × k`），再在圆心撒 **9 团烟**，每团各自沿随机角度 `tween` 到 `120 × k` 外、同时胀到 `2.4 × k`（`TRANS_CUBIC / EASE_OUT`、0.85s）—— 常规模块化爆炸是"一团爆开"，这里是"**一圈烟往外翻**"，视觉冲击差别就在这层扩散。`k = clamp(半径/100, 0.8, 2.2)`，所以以后调技能半径演出会自动跟着变。音效换 `explode_large`（普通爆炸是 `explode_small`）。`map.gd::areaDamage()` 里在原有 `ExplosionManage.playExplosion(center)` 之后调 `_playBombardStrike(center, radius)`，技能专属、子弹爆炸仍走 `ExplosionManage`（池化节点）不受影响。**顺手抓到一个真 bug**：上一次改动把"生成演出"这件事写了两遍 —— `areaDamage()` 里既调 `_playBombardStrike()` 又内联 `instantiate()` 了一遍，实测会**同时放两套特效和两声爆炸**（因为两处都能跑通、不报错，光看代码容易滑过去），已删掉内联那份。验证：`get_errors` 里 `bombard_strike.gd` / `bombard_strike.tscn` 全绿；`map.gd` 报 `preload ... does not exist` 属**语言服务器缓存**（文件确实在 `scene/fx/`，341 字节、被 `map.gd` 正确引用）|

| 2026-10-04 | 履带滚动改 4 帧（1/4 齿距步进） | v1.1 | 反馈："这个履带的滚动不是很自然，错位的应该都是横条"。**原因**：上一版是**两帧、每帧错半个齿距**（齿距 8px → 错 4px），而等距重复的齿纹上"往前 4px"和"往后 4px"**画面完全等价**，眼睛读不出滚动方向，只会觉得齿在原地抖。齿条本身没错：9 辆车的履带都是横着跑、齿都是竖条，用户在竖直路段看到的"横条"就是把车转 90° 后看到的这些齿。改法：**每辆车 4 帧、每帧步进 1/4 齿距**（帧 k 平移 `round(齿距×k/4)`）—— 相邻帧位移 2px、反向要走 6px，方向唯一；`speed` **8 → 16**（4 帧 × 16fps ≈ 每秒滚过 4 个齿距）。步进量：齿距 8 的四个坦克 2/4/6，实验坦克齿距 12 为 3/6/9，四辆轻型车齿距 9 为 2/4/7（取整）。生成器 `tools/gen_enemy_frames.py` 改成一次出 3 帧，齿色（坦克 `#dceaf2` / 轻型车 `#94b0c2`）与分组换行写法差异照旧兼容。**⚠️ 期间发现 Godot 编辑器在同时保存这些场景**：`heavy_tank.tscn` / `armored_tank.tscn` / `enemy.tscn` 等被编辑器重存过（多出 `unique_id=` / `frame_progress` 字段，属正常），但 **`armored_tank.tscn` 被存成了一个很旧且残缺的版本** —— 车身/炮塔贴图、SpriteFrames、碰撞体全部丢失（`git diff` 可证），已按 `medium_tank.tscn` 的结构重建（车身 4 帧 + 炮塔 + `RectangleShape2D 48×34` + 命中闪白材质，保留 `enemyType = 3` / `muzzleOffset = 35.0` / 炮塔 `offset = Vector2(17, 0)`）。**在编辑器里开着这些场景的话，改完请先 Reload from disk 再保存**，否则会把改动盖回去。验证：9 辆车全部 4 帧 / speed 16.0；基线 `enemy.tscn` 的 `autoplay = "default"` 仍在（否则多帧也播不起来）；`.tscn` 无注释 |

| 2026-10-04 | 敌人炮塔开火后坐 | v1.0 | 需求：“**目前敌人的炮塔没有一个发射子弹后退的动画，独立炮塔也是缺少的，一些敌人比如飞行单位没有炮塔的没有，参考一下防御塔的炮塔发射后腿动画，给敌人加上默认这个动画**”。做法：**抄防御塔的观感、换成代码实现**。防御塔是在 `player` 里放一段 "fire" 动画（`turret:offset` 从 (0,0) → (-5,0) → (0,0)，全长 0.2s，见 `machineGunTower.tscn` 的 `Animation_k8n1u`，`cannonTower` / `rocketTower` 同款）；敌人一辆车一个场景，挨个挂 AnimationPlayer 太啰嗦，所以改成在基类里用 `Tween` 做同一件事 —— `enemy.gd::playTurretRecoil()`：把 `turret.offset` 从场景配的基准值（如装甲坦克 `Vector2(17, 0)`）沿炮管反方向推 5px（0.1s）再弹回（0.1s），**只动贴图 offset、不带动 `Muzzle`**，所以炮口位置与命中判定完全不受影响（与防御塔动画的行为一致）。挂载点覆盖敌人开火的**三条通道**：① 通用 `enemy.gd::attackTower()`（装甲坦克 / 重型坦克走这条）② 实验坦克的 4 座**独立子炮塔** —— 加在 `base_turret.gd::fireAt()` 里，并用 `ownerType == ENEMY` 限定给敌人（**防御塔不加**：塔本来就有 "fire" 动画，再加一层会变成双重后坐）③ 自己写 `fire()` 的敌人（中型坦克手动补一句）。**默认跳过**：`turret == null` 或 `turret.visible == false` —— 基场景 `enemy.tscn` 自带 turret 节点、派生场景删不掉，所以“没有炮塔”是靠 `visible = false` 表达的（无人机 / 直升机 / 战斗飞机 / 导弹车 / 突击车 / 自爆车 / 维修车都在这类），飞行单位因此天然不受影响。可调：`enemy.gd` 的 `@export var turretRecoil = 5.0`，每个敌人可在自己场景里覆盖。验证：`get_errors` 四个文件全绿；逐场景核对炮塔可见性 —— **生效**：装甲 / 重型 / 中型坦克 + 实验坦克 4 座子炮塔；**跳过**：其余（无可见炮塔）|

| 2026-10-04 | 第一关加入中型坦克 + 上调数量 | v1.0 | 需求：“**第一关增加中型坦克，坦克的数量都增加一些**”。关卡1 原来是纯迷你坦克（3 波 80 只，全是 `lossPoints 1` 的推土机），而 `mediumTank` 是**会还击的射手**（hp 300 / atk 15 / 射程 240 / 0.9s 一发，见 `game.gd::enemyInfo`），所以按“首次登场”来配量：**第 2 波两条带子各 1 辆**（让玩家第一次遇到"敌人会打塔"，自然学会把塔往后放），**第 3 波 2 + 1 辆**，全关共 5 辆 —— 比关卡2 末波的 3 辆略多，但不至于在第二关就把新手劝退。迷你坦克数量同步上调（6/7 → 8/8、18/8 → 20/12、20/21 → 22/24），全关 80 → 99 只。`description` 补一句“第 2 波起中型坦克首次登场，会向防御塔开火”，让关卡介绍面板提前提示。`'routes'`（2）、`'wave'`（3）、`health`（20）、`money`（150）都没动 —— 敌人变多本身带来的击杀收益已经够补。验证：`get_errors` 全绿；脚本按 `enemySpawner` 逐波统计确认编制与所用路线号（全部 ≤ 声明的 2）|

| 2026-10-04 | 关卡 category / description 走翻译 | v1.0 | 反馈：“**category 和 description 没有实现国际化**”。排查确认：`allStage` 里 16 个关卡（教程 + 1~15）的 `category` / `description` 都是硬编码中文，而全项目唯一的消费点是 `script/panel/level_intro_panel.gd::_fillHeader()` —— 它把原文直接塞进 `subtitleLabel`，从没经过 `Game.t()`，所以切英文后关卡介绍面板的副标题/说明仍是中文（关卡标题、敌人名、成就、`_EnemyDesc_*` 那些早就走键了）。改法：① `stageData.gd` 里这两个字段改成**翻译键**，命名跟既有的 `_LevelTitleFmt` / `_Tutorial` 对齐：教程关 `_TutorialCategory` / `_TutorialDescription`，数字关卡 `_LevelNCategory` / `_LevelNDescription`（共 32 个键）。② `lang/language.csv`（三列 `Keys,en,zh`）补 32 行：中文原文原样搬到 zh 列，英文**按各关主题重写**（车间/库区那套措辞，不是直译）；新行统一加引号，免得文案里的逗号把列切错。③ `_fillHeader()` 过一遍 `Game.t(key, key)`（键缺失时显示键本身，与敌人名 `tr()` 的行为一致），**判空仍然用 key**，保住原代码“只有副标题 / 只有说明”的写法。顺带修掉同文件两处既有告警：`_makeCell()` 的 `align` 参数 `int` → `HorizontalAlignment`（`INT_AS_ENUM_WITHOUT_CAST`，调用方传的本来就是 `HORIZONTAL_ALIGNMENT_*`），`_addChip()` 里的局部 `titleLabel` 改名 `chipTitle`（`SHADOWED_VARIABLE`，原名字盖住了类里的 `@onready var titleLabel`）。验证：`csv` 模块解析 —— 190 行数据、**字段不足 0 行、重复键 0 个**、32 个新键中英文均非空；`grep` 确认 `stageData.gd` 已无中文 category/description；`get_errors` 中 `stageData.gd` 全绿。**⚠️ `.translation` 是 Godot 按 CSV 导入生成的二进制**，本机没有 Godot 可执行文件，所以要**在编辑器里打开一次工程**让它重新导入 `language.csv`，新键才生效（否则面板会显示成 `_Level1Category` 这种键名）|

| 2026-10-04 | 成就：删 route_master + 加两个战斗成就 | v1.0 | 需求：“**成就系统里面 route_master 可以删除，增加两个成就，消灭 30 辆实验坦克和消灭 3000 个敌人**”。做法：① `autoload/achievement_manager.gd` 的 `ACHIEVEMENTS` 删掉 `route_master`（原条件 = 多路线关卡零损通关，与 `perfect_base` 高度重叠、实际很容易和“完美基地”同时弹两个 toast），换成两条 combat 成就：**`fortress_breaker`**（target 30 = 实验坦克 / 4 炮塔要塞，奖励 40 宝石 + 称号“要塞终结者”）与 **`legion_slayer`**（target 3000 = 全部敌人、不分地空，奖励 50 宝石 + 称号“千军之敌”）。② 进度来源 `script/panel/achievement_tracker.gd`：`_onEnemyDefeated()` 里加 **无条件累加 `legion_slayer`**，以及 **`enemyType == experimentalTank` 时累加 `fortress_breaker`**（与既有 `heavyTank/armoredTank → iron_hunter` 同一写法，`auto_save = false`，靠通关闭包 / 退场景统一 flush）。③ 删掉 `recordStageCleared()` 里的 route_master 分支，`multi_route` 参数改名 `_multi_route` 保留 —— 调用方是位置传参，删参数得连带改 `map.gd`，没必要。④ 两个新成就各画一个图标，**完全照现有成就图标的画法**（128×128 准星环 + 四向黄刻度 + 中间浅蓝徽记；配色 `#94b0c2` 环 / `#ffc61a` 刻度 / `#566c86` 主体 / `#1a1c2c` 描边）：要塞终结者 = 宽底盘 + 4 个炮塔圈（要塞型），千军之敌 = 3×2 的小车阵列（讲“数量”）。为省事用 SVG —— `_loadIcon()` 走 `ResourceLoader.exists() + load()`，未导入时会自动回落到 `sprite/achievement_3d.png`，不会报错。⑤ `lang/language.csv` 删掉 `_Achv_route_master_name` / `_desc` 两行、补上 4 行新文案（英文按成就语气重写，不是直译），数据行 190 → 192。清理：删掉已无引用的 `sprite/icon/achv_route_master.png` + `.import`。验证：脚本交叉核对 —— **10 个成就条目**的 name/desc 翻译键都存在、图标文件都存在；`achievement_tracker` 里 `addProgress/setProgress` 引用的成就 id **无悬空**；`csv` 解析 192 行、字段不足 0 行、重复键 0 个；`get_errors` 两个文件全绿。备注：存档里若已解锁过 `route_master`，那只是个用不到的旧 id —— 成就面板遍历的是 `ACHIEVEMENTS`，不会显示也不会报错；`reward_title` 目前**只定义、没人读**，所以新成就的称号是中文原文（等称号系统接上再考虑走翻译键） |

| 2026-10-04 | 无尽模式 M1：代码骨架 + 占位地图 | v1.0 | 需求确认后开工（设计师反馈：**先做一张地图、双带并排少弯道、同屏起码 60+、基地血固定 10、出口放左侧**；设计稿见 `endless_mode_design.md`）。M1 落地内容：① `autoload/game.gd` 加 `endlessMode` / `enemyScale` / `enemyAtkScale` 三个全局量（normal 关卡本来就是 1.0，因此对其他模式零影响）。② `script/level/base_level.gd` 抽出两个可覆写钩子：`_build_wave_spawner(waveNo)`（默认＝从关卡数据筛 `time == waveNo`，无尽覆写它现场生成）与 `spawnDelayScale`（出怪间隔整体缩放，乘在 `_nextSpawnDelay()` 的返回值上）。③ `script/enemy/enemy.gd::setupEnemyInfo()` 末尾按 `Game.enemyScale/enemyAtkScale` 缩放 hp / atk（无尽按波次调）；`script/level/endless_level.gd` 在 `_exit_tree()` 里**复位缩放**，否则会污染下一局普通关卡。④ 新增 `script/level/endless_level.gd`：10 血 / 400 金 / `wave = 999999`（永不触发“通关”），覆写钩子按固定 seed 生成编制 —— 活跃池 = 迷你坦克 + 突击车（提供数量）+ 最近解锁的 2 种 + 随机 1 种（**空中兵种最多 1 种**）；按权重分配后**夹到单兵种上限**，名额不足再轮询补足（否则会出现“一波 45 台装甲坦克”这种荒唐编制）；地面兵种**两条带子各一半**、空中兵种走路线3；同屏上限 90。⑤ 新增 `scene/level/endless.tscn`（**占位版：3 条路线 + 脚本**，M2 才摆真实带子/塔位/地面）。⑥ `script/map.gd` 无尽分支：直接加载无尽场景（`levelId = -1`，`allStage` 匹配不到所以数值由脚本接管）、技能全开、跳过塔种类限制、不看关卡情报直接提示开战、藏掉波数进度条、基地被打爆时先落 `endlessBestWave` 记录（**不碰 stageRatings / 关卡解锁 / 关卡通关成就**）。⑦ `scene/welcome.tscn` 加一个「无尽模式」按钮 + `welcome.gd::_onEndlessPressed()`（复用教程按钮的图标与配色，零新增资源）。⑧ `autoload/userData.gd` 加 `endlessBestWave / endlessBestKills / endlessRuns`（老存档缺字段回落 0，可向前兼容）。⑨ `lang/language.csv` 加 8 个 `_Endless*` 键。踩坑记录：第一个补丁用“抽函数声明行的缩进再拼函数体”的写法，但 **GDScript 顶层函数的缩进是空** → 新函数体写成了 0 缩进，而且新函数被插到了 `func xxx():` 的**下一行**（挤进原函数体）， `map.gd` / `base_level.gd` 双双语法报错；已按“顶层函数体统一 1 tab + 插在函数之间”修正。验证：`get_errors` 除 `endless_level.gd` 的“父类无法解析”（**语言服务器缓存**，`base_level.gd` 本身已无错误）外均干净；`.tscn` 无注释；CSV 校验 200 行 / 字段不足 0 / 重复键 0；另用脚本按同一公式导出 W1~W60 的波次表（同屏 W1=18 → W15=74 → W25+=90，空中占比压到 8~10，血倍率 W30=5.35）|

| 2026-10-04 | 无尽模式 M2 + M4：真实地图 + 统计与成就 | v1.0 | 承接上一条。**M2 地图**：新增生成器 `tools/level_tools/make_endless.py`（可重复执行），产出 `scene/level/endless.tscn` —— 从 `level_2.tscn` 抄地面 `bg`（TileMapLayer + tile_map_data）与 4 个 `ext_resource` 的 uid，再按规格写入 3 条 Curve2D + 130 条带子 + 105 个塔位。**几何踩坑**：两条并排车道做 180° 掉头时，90° 网格上只要有一格重合就会互相压住——第一版「外圈 row3 在 col28 回头、内圈 row4 在 col29 回头」让路线2 的东行段穿过了路线1 的竖段，`analyze.py` 直接报「带子对不上 3 处 / 2 处」。正解是**内圈比外圈更早回头**（row4 在 col28、row3 在 col29），去程/竖段/回程三段两条带子始终相邻不重叠（代价是回程上下顺序反过来——这本来就与真实道路掉头一致）。另外把「折线展开成格子」改成**按段显式写朝向码**（`we`/`ew`/`ns` + 拐角 `ws`/`nw`），避免拐角格被两段各算一次、后算的覆盖前算的。验证：`analyze.py scene/level/endless.tscn` → **问题数 0**（路线1 70 格 / 路线2 66 格全程在格子中心、带子朝向一致；路线3 空中航线只有"含斜线"提示，属正常）。**M4 统计与成就**：① `endless_level.gd` 统计 `kills` 与开局时间戳（接 `Game.enemyDefeated`），提供 `elapsedSeconds()`；② `map.gd::_recordEndlessResult()` 结算时写 `endlessBestWave` / `endlessBestKills`（破纪录才更新击杀数）、推进 `endless_10` / `endless_30` 进度，并用 `addNotice` 报出「你撑到了第 N 波 / 击杀总数 / 用时」；③ 成就表加两条：`endless_10`（到第 10 波，20 宝石）、`endless_30`（到第 30 波，50 宝石 + 称号“无尽行者”），图标沿用现有成就画法（准星环 + 黄刻度 + 中间徽记：三层推进箭头 / 钟面）；④ `language.csv` 加 4 个成就键。**顺带**：无尽里敌人照样走 `Game.enemyDefeated`，所以 `legion_slayer`（3000 击杀）与 `fortress_breaker`（30 辆实验坦克）在无尽里会自动累积。验证：成就交叉校验脚本 —— **12 条成就**的 name/desc 翻译键与图标文件**全部存在**、`addProgress/setProgress` 引用的 id **无悬空**；`get_errors` 三个 `.gd` 全绿。**未做（下一批）**：暂停菜单的「结束本局」按钮、结算面板把击杀/用时排成字段（现在用飘字提示代替）|

| 2026-10-04 | 无尽模式收尾：暂停结束 + 结算字段 + 介绍页 | v1.0 | 三件收尾。① **暂停菜单「结束本局」**：`pause_menu.tscn` 加一个 `btnGiveUp`（沿用同款按钮实例），`pause_menu.gd` 加 `giveUpPressed` 信号 + `showGiveUp(flag)` 控制显隐（默认隐藏）；`map.gd` 接上 `_onEndlessGiveUp()` —— 先 `pauseMenu.hide()`、再取消暂停、然后走**和基地被打爆完全一样**的结算路径 `_onDefenseFailed()`（含最高记录落盘与无尽成就），只是不用等基地真的没血；每次 `pauseGame()` 同步一次显隐，普通关卡看不到这个按钮。② **结算面板显示击杀/用时**：新增成员 `_endlessStatsText`，`_recordEndlessResult()` 里拼成“你撑到了第 N 波 · 击杀 x · 用时 m:ss”并存下来（同时用作飘字），`_onDefenseFailed()` 里在 `resultScreen.setResult(true)` **之后**写进 `resultScreen.waveLabel`——⚠️ 必须放在 setResult 之后，它自己也会写这个 label（普通关卡那里显示“波次 x/y”，无尽没有总波数，正好换成战绩）。③ **波次显示与进度条**：`title.gd` 的波次文本抽成 `_refreshWaveLabel()`，无尽显示 `7/-`（不再出现 `7/999999`）；map 的 `waveProgressBar` 在 `_ready` 统一隐藏，`syncWaveProgressBar()` 函数与 4 处调用全部注释（暂时用不上，注释里写明了怎么恢复）。④ **无尽专属介绍页**：不新做 UI，给现有 `level_intro_panel.gd` 加 `showEndless(bestWave)` —— 同一个面板、同样的“点开始关闭”流程，内容换成标题“无尽模式”+ 副标题“没有终点…”、三个信息块（基地血量 10 / 同屏上限 90 / **最高记录 N**）、三行规则文字；`map.gd::showLevelIntro()` 的无尽分支改成调用它（面板不存在时退回“直接提示点开始”，不会卡住）；`language.csv` 补 7 个键。验证：`get_errors` 全绿；CSV 211 行、字段不足 0、重复键 0；`.tscn` 无注释 |

| 2026-10-04 | 无尽地图 M5：弯道可建造区 + 装饰物 | v1.0 | 需求：“**无尽关卡弯道的地方加一些可放置区域，地图里面也加一些装饰物，不用太多，在一些空包的地方**”。① **弯道加塔位**：原来只有中间一块（rows 5~9 × col 2~22 = 105 格），竖段在 col28/col29，离塔位最右缘 6 格 ≈384px，普通射程根本够不着 → 弯道是火力真空。`make_endless.py` 把塔位改成四块：中路双覆盖 105 + 内侧拐角（rows 5~9 × col 23~27）25 + 右上外侧拐角（rows 1~2 × col 23~29）14 + 右下外侧拐角（rows 12~13 × col 23~29）14 = **158 格**。三块拐角都紧贴带子（间距 ≤2 格），把 U 形整段纳入火力网；塔位总量仍小于地图格数的 1/3，钱和人口才是瓶颈，不会因此变简单。② **装饰物 21 件**：先读 `script/level/prop.gd` 确认装饰物**不参与玩法**（无碰撞、不占建造格），再写工具 `tools/level_tools/prop_check.py` 用**实际 position**（不是节点名里那两个数字，那个和位置对不上）复查官方关卡，反推出两条硬规则 —— **贴图绝不压带子格/塔位格**（1/2/15 关各 0 处）、**大件坐标要让贴图压满整格**（奇数格宽 → 中心落格中心 ≡32，偶数格宽 → 中心压格线 ≡0；大件场景 `snapToGrid=false`，小件是 true 会被吸附）。按这两条摆：上位空带（row0~2）7 件、U 形靠左窄空地（col0~1，row5~9）2 件、下位空带（row12~16）7 件、大件 5 件（transformer / generator 在上带，cooling_tower / container / storage_tank 在下带）当视觉锚点；生成器内置自检（出界 / 压路面 / 压塔位 / 互相重叠 任一即报错退出）。③ **顺带修一个真 bug**：回程腿的 `routePhase` 原来按**列号递增**写（`_west(11, 0, 28)`），而行进方向是列号递减 —— 而 shader 的波位置是 `sin((route_phase / wave_length - TIME * wave_speed) * TAU)`，相位必须沿行进方向逐格 +1，所以这两条回程带子的箭头一直是**倒着跑**的。先写工具 `tools/level_tools/belt_phase_check.py` 用官方关卡反推约定（1/2/15 关分别 65/57/59 次递增、**0 次递减**），确认无误后把 `_west` 改成列号递减；并把这项检查并入 `analyze.py`（作为**提示**输出、不计入问题数，因为手工关卡里 level_1 本来就有 2 处历史遗留相位跳变）。④ **新增可视化工具** `tools/level_tools/render_preview.py`：不依赖 Pillow（自己写 PNG），把带子（按 routePhase 取色 + 画箭头方向）/ 塔位 / 装饰 / 路线画成一张 1920×1088 预览图，改完地图不用开 Godot 就能先看一眼布局。验证：`analyze.py`（含相位检查）无尽 **问题数 0 / 相位不连续 0 处**；`prop_check.py` 无尽 **压带子 0 / 压塔位 0**；1/2/15 关重跑仍为 0 问题（未改动它们）|

| 2026-10-04 | 2D 听者：给地图相机加 AudioListener2D | v1.0 | 反馈：“**之前项目里面播放声音有使用 AudioListener2D，但是 map 里面没有添加 AudioListener2D，看下添加在哪里，相机是移动的**”。排查发现这不只是“少了个节点”，而是**2D 定位音效一直没生效**：① `sound_manage.gd::_hasListener()` 用 `get_nodes_in_group("cameras")` 找相机，但 Godot 4 的 `Camera2D` 只加入 `__cameras_<视口id>` / `__cameras_c<画布id>` 这种**带 id 的内部组**（查引擎源码 `camera_2d.cpp` 确认），`"cameras"` 永远是空 → 检测恒为 false → 所有 `SoundManage.playAt()`（塔开火/命中/爆炸/被击毁…共 12 处调用）都静默退化成了居中播放，没有声像也没有距离衰减。② 修法：`scene/custom_camera.tscn` 里给 `CustomCamera` 加一个挂在它下面的 `AudioListener2D`（`current = true` + `groups=["audio_listener"]`），这样它**天然跟着相机走**，不用任何跟随代码。③ ⚠️ 位置不能留在相机原点上：本相机是 `anchor_mode = 0`（FIXED_TOP_LEFT，节点位置 = 可视区**左上角**），听者留在那里声像会整体歪向一边；`custom_camera.gd` 加 `_syncAudioListener()`，每帧把听者设到 `get_screen_center_position()`（可视区中心），相机拖动/缩放都跟得上，`_ready()` 里另外调一次 `make_current()`（AudioListener2D 光放进场景不生效，必须 make_current）。④ `_hasListener()` 重写为：认 `audio_listener` 组里 `is_current()` 的 AudioListener2D，或 `Viewport.get_camera_2d()` 有启用的相机（Godot 4 无生效听者时听者取**屏幕中心**，不是原点——旧注释写反了，一并订正）。⑤ 顺手审了 12 个 `playAt` 调用点传的坐标：`global_position` / `getMuzzlePosition()`（内部就是 `muzzleMarker.global_position`）全是世界坐标，之前只是被压着没暴露问题，现在打开定位音效不会有“声音位置算错”的隐患。验证：`get_errors` 两个 `.gd` 全绿（只剩 `sound_manage.gd` 里一条**早已存在**的 `_bgmVolumeDb` 未使用告警）；`scene_lint.py` 对 `custom_camera.tscn` / `map.tscn` 体检通过；`.tscn` 无注释。**听感变化提醒**：定位音效是第一次真正生效，远处音效会随距离衰减（`playAt` 默认 `max_distance = 1400`），太闷就调这个参数 |

| 2026-10-05 | 修复：无尽模式进关后一个敌人都不出 | v1.0 | 反馈：“**这个无尽模式开始了没有任何敌人**”。根因不在无尽脚本，而在**关卡场景的信号连接**：`base_level.gd` 的 `waveTimer.start()` / `spawnerTimer.start()` 只是把计时器启动，真正驱动波次的是 `WaveTimer.timeout → _onWaveTimerTimeout` 与 `SpawnerTimer.timeout → _onSpawnerTimerTimeout`，而这两条连接**不在 `base_level.tscn` 里**（该文件 0 条 `[connection]`），历来是**逐个关卡场景**各写一份。16 个关卡场景都有这两行，唯独我用 `tools/level_tools/make_endless.py` 生成的 `scene/level/endless.tscn` 漏了 → 计时器空转、无任何回调 → **一个敌人都不出，且不报错、不卡顿**（地图/HUD/建塔/相机全都正常，所以看起来像“模式坏了”而不是“没连上”）。排查法：拿一个能正常出怪的关卡场景（level_2）与它做**结构对比**，差异只有 `Path2D3`（空中航线，故意多）和这两条 `[connection]`。修复三层：① **就地补** `endless.tscn` 的两条连接（**不重新生成场景** —— 该文件已被编辑器保存过，有 `unique_id` 与手调过的装饰物坐标，重新生成会把用户的调整冲掉）；② 生成器 `make_endless.py` 补写这两行，并在写完文件后**自检**这两行在不在，缺了直接报错退出；③ `base_level.gd::_ready()` 加**代码兜底**：`if not waveTimer.timeout.is_connected(...)` 才 connect —— 已连过的关卡自动跳过（不会重复连接），任何漏连的场景都能自救。另给 `tools/level_tools/scene_lint.py` 加了规则：**凡实例化 `base_level.tscn` 的场景都必须带这两条连接**，用它跑修复前的备份能准确报出 2 处问题。验证：`scene_lint` level_1 / level_15 / level_tutorial / endless 全过（修复前的备份报 2 处）；`analyze.py` 无尽仍 **问题数 0**；`get_errors` 全绿。⚠️ 注意：编辑器若已打开该场景，必须 **Reload from disk** 再测试，否则编辑器内存里的旧版本一保存就把补的连接又抹掉了 |
| 2026-10-06 | 修复：无尽模式"一次只有一条路线出敌人" | v1.0 | 反馈：“**无尽模式目前都是单条路线出现敌人，应该每条路线都出敌人**”。地图本身没问题（`endless.tscn` 里 `Path2D`/`Path2D2`/`Path2D3` 三条路线都在，`_collectRoutes()` 收全 3 条）。真因在**出怪队列的顺序**：`_build_wave_spawner()` 生成的记录是「先把路线1的兵排完，再排路线2」，而 `base_level.gd::_onSpawnerTimerTimeout()` 是**先进先出、每拍只放队首那一个** → 整波前半段只有路线1出兵、后半段只有路线2，玩家看到的自然是“一次只出一条路线”（设计文档 §5.2 写的“两条带子始终都有敌人”没落地）。改为：先把每个兵种拆进各条路线的队列（地面两条各一半、奇数余 1 给路线1；空中走路线3），再**按比例交织**成一条队列 —— 每拍挑“进度最落后”的那条路线（`已出场数 / 该路线总数` 最小者）。数量相等时即 1、2、1、2 严格交替；数量悬殊时小股部队也会被均匀撒在整波里；飞机穿插登场而不是末尾全上。另：相邻的“同路线同兵种”记录合并成 `number=N`，行为完全一致。附带一道兜底：`_ready()` 里若 `get_route_count() < 3` 就 `push_warning` —— `getRoute()` 越界会静默回落到最后一条路线，那才是真的“全挤在一条路上”。Python 侧模拟验证（照抄算法跑第1/12波与各种奇偶编制）：出怪总数不变、各路线切换从 1~2 次变成 15~17 次、路线1/2 分布只差 1 个 |
| 2026-10-06 | 新增：教程关「首次使用引导」（可跳过） | v1.0 | 需求：“**教程关卡应该有个类似 app 第一使用时的一个引导，比如点击这个按钮然后点击其他地方的功能，这个功能单独一个场景只在教程关卡里面使用，玩家可以跳过这个**”。做法：新增独立场景 `scene/tutorial_guide.tscn` + `script/ui/tutorial_guide.gd`，**只有教程关**会实例化（`map.gd::_setupTutorialGuide()`，非教程关连场景都不会被 load）。① **遮罩**：不做反向遮罩——把屏幕切成上/下/左/右 4 块深色矩形（`Color(0.02,0.03,0.05,0.62)`），中间那块自然就“透”出来；高亮用 `draw_style_box` 画圆角描边 + 一条跟着 `sin` 呼吸的光晕（`RING_PERIOD=1.6s`）。② **一步怎么算完成**：遮罩 `mouse_filter=IGNORE`，玩家点击照常落到底下的真按钮/地图上，引导只判断“这件事有没有发生”（开工具箱→轮询 `towerUI.isOpen`；选塔→听 `Game.selectTower`；建塔→听 `Game.towerPlaced`；开打→轮询 `btnStart.button_pressed`；放技能→听 `AbilityManager.abilityActivated`）—— 不画假按钮、不替玩家转发点击。③ **步骤顺序**：先教建塔再教开打（点 ▶ 之后 1.6 秒一个敌人，新手还在读提示就已经漏怪了）：开工具箱 → 选塔卡片（高亮机枪塔那张）→ 点高亮的可建造格建塔 → 点 ▶ 开打 →（**宝石够才有**）放技能 → “知道了”收工。④ **宝石那一步是条件步骤**：`UserData.gem` 新存档为 0，硬塞一步“放个技能”会让任务做不完 —— `_can_use_ability()` 不满足时直接不加。⑤ **高亮框跟着目标走**：每帧用 `get_global_transform_with_canvas()` 重算（Hud 控件与地图格子都用它，相机推拉/窗口缩放都准），可建造格挑“完整在屏幕内、离屏幕中心最近”的那一格。⑥ **层级与暂停**：引导在 `CanvasLayer.layer=5`（低于 `PopupLayer=10`），关卡情报/暂停/结算弹窗天然盖在它上面；`process_mode=ALWAYS` 且暂停期间自动 `hide()`（否则压暗层会透过暂停菜单）。⑦ 文案 8 条走 `lang/language.csv`（`_TutorialGuide1..6` / `_TutorialGuideSkip` / `_TutorialGuideOk`，en+zh），代码里带英文兜底。验证：翻译表字段数/重复键/`Game.t` 用键全覆盖、`.tscn` 资源路径与 `$` 节点路径逐条对账、`map.gd` 接线顺序（必须在 `setupAbilities()` 之后）、引导脚本关键行为（暂停收起 / 宝石门控）全部脚本化检查通过；`get_errors` 全绿；`scene_lint.py` 三个场景全过 |

| 2026-10-06 | 调整：引导「放技能」那一步点一下即过 + 补右键取消提示 | v1.0 | 反馈：“**到了这个技能提示的地方，可以点击然后直接下一个步骤，选择技能和防御塔的时候加个右键可以取消的提示**”。① **技能步放行条件放宽**：原来只听 `AbilityManager.abilityActivated`（＝玩家得真的把技能砸到地图上才算过），现在**点一下就过** —— 三路信号任一到就算完成：瞬发技能 `abilityActivated`、范围技能 `selectionStarted`（点图标即进入“选目标”状态）、被拦下 `abilityFailed`（宝石不够/冷却中）。最后一路是为了**不把玩家卡在一个完不成的任务上**：他确实点过了，就该放行。② **「右键取消」提示**：气泡里加一行小字（`hintLabel`，金黄 22px），显隐**跟着状态走、不跟着步骤走** —— `AbilityManager.isSelecting()` 或 `level.towerShadow.active` 为真（＝选好了还没落地）就出现，平时不占地方；显隐切换时 `bubble.reset_size()` 重排气泡高度。文案 `_TutorialGuideCancelHint`（“右键取消选择”/“Right-click to cancel.”）。核对过 `project.godot`：`selectCancel` 只绑了 `button_index = 2`（鼠标右键），没有键盘替代键，所以提示说右键没写错。⚠️ 目前这行提示**只在教程关**出现（它属于引导场景）；若要做成“所有关卡选中塔/技能时都提示”的全局提示，需要把它挪到 HUD 层（另开一个小场景，见 map.gd 里 `_setupTutorialGuide` 同款接法）。验证：信号名/参数个数与 `ability_manager.gd` 逐条对账（多收参数会运行时炸）、`_process` 每帧确实调用了提示刷新、场景里 `hintLabel` 插在正文与按钮之间的正确位置、9 个翻译键全覆盖，全部脚本化检查通过；`get_errors` 全绿 |
| 2026-10-06 | 修复：进教程关报 `Nonexistent function 'setup' in base 'CanvasLayer'` | v1.0 | 报错栈：`map.gd:157 @ _setupTutorialGuide()`。根因：引导场景的**根节点是 `CanvasLayer`（`layer = 5`，要它才能盖在相机之上又低于 PopupLayer），脚本挂在它里面那层 `Root` 控件上**（CanvasLayer 没有 `size`、也没有 `_draw`，遮罩只能由 Control 画）；而 `scene.instantiate()` 返回的是**根节点**，于是 `setup()` 调到了没脚本的 CanvasLayer 上。修法：`map.gd::_find_guide_root()` —— 根有 `setup` 就用根，否则找第一层子节点，都没有才 `push_error`。**不写死节点名**（编辑器里改名不会悄悄坏），失败会大声报错而不是静默失效 |

---

## 九、后续可扩展模块（规划中）

以下模块为后续规划，待需求明确后补充详细设计：

1. **每日任务系统**：参考成就系统结构，每日刷新任务，完成奖励钻石/物品。
2. **关卡星级与奖励**：基于 `level_rating.gd` 扩展，三星通关奖励宝石。
3. **装备系统**：为塔添加可装备的强化道具，与背包系统共用 `ItemData` 结构。
4. **存档系统统一化**：将 `userData`、`backpack`、`achievement_manager` 的存档逻辑统一到一个 `SaveManager` 单例。
5. **无尽模式**：见根目录 `endless_mode_design.md`（**设计稿 v1.1，未开工**）——独立关卡场景 + 复用 `map.tscn` 外壳；地图固定一张：**双传送带并排 U 形（只 2 个弯）**，用于把同屏敌人堆到 60~80；含难度曲线公式、性能上限与 M1~M5 里程碑。

---

*本文档为 Machine-TD 项目功能模块设计记录，所有模块以独立、可扩展、信号驱动为设计核心。*
