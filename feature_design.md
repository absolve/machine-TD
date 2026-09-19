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

---

## 九、后续可扩展模块（规划中）

以下模块为后续规划，待需求明确后补充详细设计：

1. **每日任务系统**：参考成就系统结构，每日刷新任务，完成奖励钻石/物品。
2. **关卡星级与奖励**：基于 `level_rating.gd` 扩展，三星通关奖励宝石。
3. **装备系统**：为塔添加可装备的强化道具，与背包系统共用 `ItemData` 结构。
4. **存档系统统一化**：将 `userData`、`backpack`、`achievement_manager` 的存档逻辑统一到一个 `SaveManager` 单例。

---

*本文档为 Machine-TD 项目功能模块设计记录，所有模块以独立、可扩展、信号驱动为设计核心。*
