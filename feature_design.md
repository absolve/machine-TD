# Machine-TD 功能模块设计与更新记录

> 本文档用于记录后续功能模块的设计方案与更新计划，便于独立开发、维护和扩展。
>
> **文档版本**：v2.5
> **创建日期**：2026-08-19
> **最近更新**：2026-11-01 —— **§二十一 模块 A「结算战报」已实现**：
> 结算页新增「塔 / 占比 / 伤害 / 击杀」四列表格（前 5 座）+ 漏怪类型汇总。
> 纯统计，不碰任何战斗数值；探针 16 项断言全过。§二十一 其余模块仍是设计稿。
> **上一版**：2026-10-24（§十八 塔技能已实现：9 座塔全覆盖，技能只提供派生值、与升级系统互不覆盖）
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
- [九、敌人攻击范围显示（Enemy Attack Range Indicator）](#九敌人攻击范围显示enemy-attack-range-indicator)
- [十、移动机甲 + 维修 / 回收（Mobile Mech）](#十移动机甲--维修--回收mobile-mech)
- [十一、敌人残骸与回收（Enemy Wreckage & Salvage）](#十一敌人残骸与回收enemy-wreckage--salvage)
- [十二、击杀金币飘字（Kill Reward Floating Text）](#十二击杀金币飘字kill-reward-floating-text)
- [十三、波次来袭横幅（Wave Incoming Banner）](#十三波次来袭横幅wave-incoming-banner)
- [十四、五个新模块的总览与依赖](#十四五个新模块的总览与依赖)
- [十五、后续可扩展模块（v2.x 待办）](#十五后续可扩展模块v2x-待办)
- [十六、1X / 2X 倍速（Game Speed）](#十六1x--2x-倍速game-speed)
- [十七、战斗模式（Battle Mode / Mutator）](#十七战斗模式battle-mode--mutator)
- [十八、防御塔主动技能（Tower Active Skill）](#十八防御塔主动技能tower-active-skill)
- [十九、Boss（小 boss / 大 boss）](#十九boss小-boss--大-boss)
- [二十、三个模块的实施顺序建议](#二十三个模块的实施顺序建议)
- [二十一、扩展内容设计（叠加式）](#二十一扩展内容设计叠加式)
- [二十二、内容充实设计（提前召唤 / 宝石商店）](#二十二内容充实设计提前召唤--宝石商店)
- [二十三、灵感库记录（塔防机制调研吸收，未排期）](#二十三灵感库记录塔防机制调研吸收未排期)
- [二十四、敌人新机制轴设计（补给车队 / 督战指挥车）](#二十四敌人新机制轴设计补给车队--督战指挥车)
- [二十五、装甲列车 boss（多部件大 boss）](#二十五装甲列车-boss多部件大-boss)
- [二十六、国际化扩语种（字体链与探针）](#二十六国际化扩语种字体链与探针)

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

> **实现状态：✅ 已实现**（2026-09-12 首版，**2026-10-23 复核为 12 个成就**）
> 含关卡内记录器、图标网格总览面板、右侧滑入获得提示；文案已全量中英双语。
> 现有 12 条：`first_defense` / `ground_breaker` / `iron_hunter` / `sky_guardian` / `full_armory` /
> `chain_reaction` / `veteran_tower` / `perfect_base` / `fortress_breaker` / `legion_slayer` + 无尽专属 `endless_10` / `endless_30`。
> **已知限制**：`reward_gem` / `reward_title` 两个字段仍**只定义、无人读取** → 解锁成就不发宝石、也没有称号系统（见 §15.1）。

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

> **实现状态：✅ 已实现**（2026-10-23 校对）
> 代码：`autoload/ability_manager.gd`（定义表 `ABILITIES` + 冷却/宝石/目标选择）、
> `script/ui/ability_bar.gd` + `ability_slot.gd`（战斗内技能栏）、`map.gd` 的目标选择与效果落地。
> 现有两个技能：**`bombard`**（区域轰炸：半径 100 / 伤害 200 / 6 秒冷却 / 1 宝石）、
> **`invincible`**（防御塔无敌：半径 80 / 持续 8 秒 / 8 秒冷却 / 1 宝石）。
> 本关启用哪些技能由 `StageData.stageAbilities` 配置，未配置即本关无技能。

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

| 2026-10-09 | §九 敌人攻击范围显示 | v1.0 | 新增设计（**未实现**）：点击敌人时把"会攻击防御塔的敌人"的射程画成一圈可见范围。**关键结论：判据不能用 `atk > 0`** —— 排查 13 种敌人后发现两个反例：**维修车 `atk=20` 但 `fire(targets: Array)` 是治疗友军**、**自爆车 `atk=80` 但走 `triggerSelfExplode()` 撞击**，两者都不远程打塔。因此改为在 `enemyInfo` 每条**显式声明 `showsRange`**（与 `hintRoutes` 同一思路：不做推断），本轮 8 种为 true（四种坦克 / 突击车 / 导弹车 / 攻击直升机 / 战斗飞机 / 实验坦克）、4 种为 false（迷你坦克 / 侦察无人机 / 维修车 / 自爆车）。画法与技能范围圈同源：由 `map.gd::_draw()` 绘制（**不新增 UI 节点**，天然跟随相机与缩放），锈红 `#C4553F` 半透明填充 + 实线外圈 + 4 段虚线内圈（与技能圈的实线区分，避免误认成我方技能）。取消时机与敌人信息面板同一生命周期 |
| 2026-10-09 | §十 移动机甲 + 维修 / 回收 | v1.0 | 新增设计（**未实现**）：一座**能在屏幕上移动、不占固定格**的后勤机甲，继承 `tower.gd` 拿到血量/承伤/选中/详情面板，但走自己的放置通道（**任意非路线格**，不要求 `placeableArea`）。① **移动**：选中 → 点地面 → 自己开过去（与现有"选塔→点格子"同操作）；本轮**不做寻路**，直线移动、撞到路线格就停并提示；移动时释放旧格占新格。② **不能出现在路线上**是核心约束，靠 `Path2D` 曲线采样的格集合判定。③ **自动作业**（不需要逐个下令）：每 0.5s 索敌一次，**谁近做谁**，维修优先于回收（塔被打爆不可逆、残骸只是钱）。④ **回收不需要开上路线** —— 机甲从当前位置**发一道激光**吸住残骸，持续 `salvageSeconds`；这条解决了"敌人多数死在路线上、而机甲不能上路线"的逻辑冲突（设计阶段正是这个冲突先暴露出来才定的方案）。⑤ 数值全部放 `@export`（`moveSpeed 220` / `repairScope 100` / `salvageScope 140` / `repairRate 25HP/s` / `salvageSeconds 1.2`），符合 §6.3「静态属性进 Inspector」。⑥ 全关卡可用（**含教程关**），塔卡片列表加第 9 张 |
| 2026-10-09 | §十一 敌人残骸与回收 | v1.0 | 新增设计（**未实现**）：地面敌人被击杀后**原地留一坨残骸**，存活 8~16 秒（按档次），可被 §十 的机甲回收，换回**该敌人原价 10%** 的金币（`maxi(1, floor(reward * 0.1))`）。① **空中单位不掉**（侦察无人机 / 攻击直升机 / 战斗飞机），地面 9 种全掉 —— 既符合"被击落 = 直接损毁"的直觉，也避开了"残骸掉在航线正下方"的尴尬。② **逃脱的敌人不留残骸**（没被摧毁），所以生成点必须放在 `hurt()` 的死亡分支、**不能**放 `_exit_tree()`（逃脱与场景卸载也会走那里）。③ **位置在 `freeSelf()` 之前取** —— `code_design.md` §7.5 明确写着节点 `free()` 之后读成员会静默变 `null`。④ **不做对象池**（与命中特效相反）：残骸要挂计时器、数量受单波敌人数限制，池化状态复杂而收益低。⑤ **平衡flag**：第 1 关有 99 只迷你坦克，按"至少 1 金币"全回收是 **+99**（初始 150），疑似过强，已在文档里写明"先按至少 1 实现、实测后再决定是否改成不足 1 就不掉" |
| 2026-10-09 | §十二 击杀金币飘字 | v1.0 | 新增设计（**未实现**）：敌人被摧毁时在**它倒下的位置**弹 `+N` 金币飘字，上飘 44px 后淡出。现状是**静默进账**（只看到顶栏数字跳，不知是哪只给的）。**关键发现：`Game.enemyRewarded` 信号不带位置**（`autoload/game.gd:260` 是裸 `signal enemyRewarded`），而飘字需要世界坐标 —— 对比"改信号签名"与"敌人在自己脚本里直接调静态入口"两个方案后**取后者**（敌人本来就有 `reward` 与 `global_position`，零信号改动）。**不复用 `toast_label`**：它是屏幕坐标的 HUD 提示（`fixedOffsetY = 70` 是屏幕底部偏移），飘字要世界坐标。**用对象池**（与 `ExplosionManage` 同一套，`POOL_MAX 24`）—— 与 §十一 残骸**故意相反**：飘字高频短命无状态适合池化，残骸要挂计时器不适合。位置必须在 `freeSelf()` **之前**取（`code_design.md` §7.5），与残骸是同一个坑 |
| 2026-10-09 | §十三 波次来袭横幅 | v1.0 | 新增设计（**未实现**）：每波开始时弹横幅告知本波会来哪些敌人。现状是**悄悄开始**（只发 `Game.dataRefreshed`，顶栏数字变一下），玩家常在敌人上路后才发现。**外观与动画参数直接抄 `battle_start_banner`**（`fadeInSec 0.26` / `holdSec 1.15` / `outScale 0.86` / 复用 `hazard_strip` 危险条纹），新建独立 `wave_banner` 而不是改造开场横幅（后者 `play()` 签名与 `startGame()` 调用点已稳定，改造会牵动开场流程）；也可让新脚本 `extends battle_start_banner.gd` 只覆写清单排版，符合 §6.2「基础脚本 + 子类只覆盖差异」。**数据来源零新增**：`base_level.buildWaveSpawner(wave)` 本来就返回 `{time, type, number}` 记录数组。**两个实现要点**：① `dataRefreshed` 是在 `buildWaveSpawner()` **之前**发的，所以 `map.gd` 要自己调一次 `buildWaveSpawner()` 取编制（该方法只读数据、不会重复生成敌人）；② 同一兵种可能有多条记录（走不同路线/偏移），**必须先按 type 合并 `number`** 再排序。敌人名必须走 `tr()`（`enemyInfo.name` 里存的就是翻译键，见 v5.4）。横幅 `mouse_filter = IGNORE`、不暂停、连点可跳过 |
| 2026-10-09 | §十四 五个新模块总览 | v1.0 | 补齐五个新模块（§九 / §十 / §十一 / §十二 / §十三）的依赖与建议顺序，并把原「十二、三个模块的相互依赖」并入本节：**前三个（§九 攻击范围 / §十二 金币飘字 / §十三 波次横幅）互相独立、都不改战斗逻辑**，可一次做完一起验；**§十一 残骸独立产生**、**§十 机甲依赖残骸**，按顺序做。同时把原「十三、后续可扩展模块」顺延为 §十五，目录与章节号同步 |

> **以下为 2026-10 的实施与修正记录**：§九 ~ §十三 五个模块已全部落地（上面 v1.0 行里的"未实现"是设计当时的快照，保留原文以便追溯）。

| 日期 | 模块 | 版本 | 说明 |
|---|---|---|---|
| 2026-10-23 | 文档全量校对 | v1.4 | 逐条核对实现状态并更正：§四 能力技能系统、§九~§十三 五个模块、无尽模式 全部**已实现**（此前均标❌未实现）。新增 §十六 倍速模块；§十五 改名为「v2.x 待办」并剥离已完成项，新增 §15.3 候选表指向 `roadmap.md`。所有计数按代码重新核实：**9 塔 / 12 敌人 / 12 成就 / 16 关 + 无尽 / 2 技能** |
| 2026-10-23 | §十六 1X/2X 倍速 | v1.0 | **接通既有半成品**：`btnFast` 原为 `PanelContainer`（无 `toggled` 信号）且 `visible=false`、`title.gd` 的处理函数没有信号连到、`map.gd` 的连接被注释且函数是空 `pass` —— 三处都补上。类型改为 `Button`（`toggle_mode`），复用 `card_style`，加速时染安全黄让状态可见。`hboxButton` 宽度 304→392 容纳第 5 个按钮。核心约束：`Engine.time_scale` 是**全局**状态，复位集中在 `resetGameSpeed()`，覆盖 `_exit_tree` / `finish` / `nextLevel` / `returnHome` 四个出口。已知取舍：无尽「用时」与机甲建造 CD 走 `Time.get_ticks_msec()`（真实时间），2 倍速下与游戏内时长有偏差 |
| 2026-10-23 | 星级奖励挂钩 | v1.0 | 需求：让星级**能兑换东西**（此前 `LevelRating` 只点亮三颗星，不解锁、不发奖，等于装饰）。设计：`userData.gd` 新增 `STAR_BONUS_RATIO`（2★=基础×0.25、3★=×0.50）与 `starBonusTotal(baseGem, rating)`；**奖励以该关 `gemReward` 为基数按比例给**，而不是固定值 —— 关卡基础奖励从 3 到 20 不等，固定值会把高关折扣掉。**防刷的关键**：`recordStageCompletion()` 改返回 `{"gem": 总发放, "starBonus": 其中来自星级的差额}`，星级奖励只发「最高星级提升」的差额（1★→只发基础；之后打 3★→只补 ceil(50%)−ceil(25%)），所以反复打同一关不会重复领、掉星重打也不会扣回去（差额夹到 0）。1 星是保底通关**不给**额外奖励，否则等于白涨基础奖励。`starBonusTotal` 用 `ceil` 而非 `round`：第 0 关 baseGem=3 时 25% = 0.75，向下取整会变成 0、等于白给。UI：`result_screen.setGemReward(amount, starBonus)` 只在 starBonus>0 时切换成新文案 `_GemRewardWithStar`（“获得宝石：+%d（含星级奖励 +%d）”），平时不多出半句话；`language.csv` 补 1 行。验证：数据探针 14 项断言全过（含 1★→3★ 累计应为 base+50%、掉星不减、rating 0 不发、未知关卡 id 不崩）；再走一遍真实 `finish()`（第 1 关满血三星）→ `获得宝石：+12（含星级奖励 +4）`，第二次 `finish()` 不再发放 |
| 2026-11-01 | §二十一 模块 A：战报改为可滚动表格 | v2.6 | 需求：「这个战报可以改布局成类似表格，可以滚动查看」。① **固定表头 + 滚动列表**：表头（塔 / 占比 / 伤害 / 击杀）放在 `ScrollContainer` **外面**——放进滚动区的话滚下去就看不到列名了；表头与数据行共用一张列宽表 `REPORT_COL_WIDTHS = [300, 90, 120, 90]`，两边的 `h_separation` 也一致，列才会对齐（探针断言 `header[0].size.x == grid[0].size.x`）。② **不再截断前 5 座**：既然能滚动，就把全部塔列出来。③ **高度自适应**：`min(行数 × 30 + 6, 240)`、下限 64 —— 塔少时不占地方，塔多时出现滚动条。④ 表头下加一条 1px 分隔线（`ColorRect`, alpha 0.14）区分列名与数据。⑤ 数字列右对齐（塔名长度不一，右对齐才数得清）。验证：探针 **10 项断言全过**（7 座塔全部入表 = 28 格、按伤害降序、表头 4 列、高度夹在 [64,240] 内且内容高于视口、表头与数据列宽一致、实际可滚动 `scroll_vertical` 变成 41、只有一行时高度回落到 64）；截图确认表格与滚动条
| 2026-11-01 | §二十一 模块 A：结算战报（实现） | v2.5 | 按设计稿落地「本局战报」。① **统计**：`tower.gd` 新增 `dealtDamage / killCount / overkill`；`enemy.gd::hurt()` 把**结算后的实际伤害**记到来源塔（护甲减免已算进去，反映真实贡献）、溢出单独记 `overkill`、死亡时给击杀者 `killCount + 1`、**逃脱时发新信号 `Game.enemyLeaked(enemy)`**。② **为什么不复用 `enemyEscaped`**：它只带 `lossPoints`，拿不到敌人类型，做不了"漏了什么"的汇总。③ **汇总**：`map.gd` 维护 `leakLog`（谁、剩多少血），`buildBattleReport()` 输出 `{towers(按伤害降序), totalDamage, leaks, leakTotal}`。④ **展示**：`result_screen.gd::setReport()` 在宝石行下方**用代码建** GridContainer（4 列：塔名+Lv / 占比 / 伤害 / 击杀，数字右对齐，带表头），前 5 座塔 + 一行漏怪汇总（没漏怪时显示绿色的"没有漏怪"）。胜利与失败两条结算路径都调用。⑤ 新增 10 个文案键。**设计约束遵守**：默认行为不变（不加任何战斗逻辑）、无存档字段改动、纯展示。验证：探针 **16 项断言全过**（伤害归属、击杀计数、溢出记录、漏怪记录含类型、总伤害汇总、按伤害排序、结算页报告可见、表格 12 格 = 表头+2 塔、漏怪行含敌名、空战报显示占位符）；截图确认版面
| 2026-11-01 | §十九 Boss 缺陷修复（压制永久化 / 召唤重叠） | v2.5 | 玩家实测反馈两条：「压制者好像会对塔进行永久压制」「巢母添加的敌人会挤在一起，最好分开点」。① **永久压制 = 真 bug**：`tower.gd` 的开火闸 `canShot` 平时由 `delayTimer.timeout → onDelayTimeout()` 恢复；若沉默正好覆盖冷却到期那一刻，`onDelayTimeout()` 会（正确地）提前返回，但**计时器已经停了、不会再来第二次**，`canShot` 就永远停在 false。修法：在 `_physics_process` 里检测"沉默归零的那一帧"，冷却也已走完则把 `canShot` 还回去；冷却未走完则交给 `onDelayTimeout()`。② **召唤重叠**：原来只把 `progress` 往后挪 26px，三只小坦克贴图仍会压在一起。改为**同时错开进度与横向** —— 巢母 `90px × 左右 ±22px`、要塞 `120px × ±20px`；`boss.gd::summonAt()` 因此新增 `lateral` 参数（写入 `spawnEnemy` 的 `offset`，复用既有的 `PathFollow2D.v_offset` 机制）。验证：回归探针 11 项断言全过 —— 沉默中冷却到期仍锁住（设计如此）→ 2.3s 后 `canShot` 恢复 true、连续两次压制都能恢复；巢母 3 只召唤物的 `progress` 间隔 90px（修前 26）、`v_offset` −22/−5/+22；截图确认三只沿路散开且左右错位
| 2026-11-01 | §十九 Boss 出场横幅 | v2.4 | 需求：「出场横幅 加一下」。**复用现有 `waveBanner` 实例**而不是新做一个场景 —— 它的淡入/停留/淡出、居中横带、上下危险条纹全部现成（`battle_start_banner.gd` 基类），Boss 只需要换文案。① `wave_banner.gd` 新增 `playBoss(bossName, traitText)`：清空兵种清单行、调父类 `play()` 播动画，停留时间 `holdSec + 0.9`（比普通波次多 0.9 秒，留给玩家读"怎么打"）。⚠️ `playWave()` 会把副标题永久 `visible = false`，所以 `playBoss()` 必须**重新显示** `subLabel` —— 否则名字下方的应对提示写进去也看不见。② `enemyInfo` 给 7 个 Boss 各加 `bossTip` 字段（复用测试场景已有的 `_BossTip_*` 文案，不用新写）。③ `map.gd` 连 `Game.bossSpawned` → `onBossSpawned()`，标题取 `bossBarName`、副标题取 `bossTip`。④ **分裂体小号不再重复播报**：新增 `enemy.silentBoss`，小号用 `props = {"canSplit": false, "silentBoss": true}` 生成；并把 `spawnEnemy()` 里 `props` 的应用挪到 `add_child` **之前**（`_ready()` 里就会读这些字段，放在之后等于没设）。效果：要塞出场时横幅显示「要塞 / 大 boss：半血后狂暴并免疫减速」。验证：探针 11 项断言全过（横幅存在且初始隐藏、Boss 出生即弹出、标题=名字、副标题可见且含提示、兵种清单行隐藏、约 2.8s 后自动收起、分裂体只播报自身一次、两个小号 0 次额外播报）。⚠️ 探针踩坑：用"等 N 帧"测 tween 会误判（渲染模式一帧远短于 1/60 秒），必须 `get_tree().create_timer()` 等真实时间
| 2026-11-01 | §十九 Boss 血条 UI | v2.3 | 需求：「Boss 血条 UI 是不是可以复用之前的血条，还是新做」→ 结论**新建但复用皮肤**，随后实现。① **为什么不能复用 `life_bar.tscn`**：它的根是 `Node2D`、作为敌人子节点跟坐标走，且 `_ready()` 里 `bar.visible=false` 靠 `flashFor()` **被击中才亮 3 秒**；Boss 血条要钉在屏幕顶部**常驻**，两者语义相反。② **复用**：`theme/style/tower_bar_bg.tres` + `tower_hp_fill.tres`（与塔详情面板/塔状态条同款视觉），布局参考 `wave_progress_bar.tscn`。③ **新文件**：`scene/ui/boss_health_bar.tscn`（Control + PanelContainer + NameLabel + ProgressBar + Ticks + PhaseTag，挂在 `map.tscn` 的 `Hud` 里）、`script/ui/boss_health_bar.gd`、`script/ui/boss_bar_ticks.gd`。④ **分段刻度自绘**：用子 Control 的 `_draw` 画 25/50/75% 三条线，50% 那条加粗换色当二阶段线 —— 不用 4 个 ProgressBar 拼（窗口缩放会错位）。⚠️ 必须画在 ProgressBar **上方**：Godot 里父节点的 `_draw` 会被自己的子节点盖住，所以刻度是子节点而不是写在血条根节点里。⑤ **选择规则**：同时多只 boss 只显示一只 —— 大 boss 优先，同级取最新。原本用 `get_nodes_in_group()` 的顺序当"最新"，但那个顺序**没有保证**（探针里翻车过一次），改为 `enemy.gd` 新增全局递增的 `spawnSeq` 做确定性比较。⑥ **信号**：`Game.bossSpawned` / `bossDefeated`，由 `enemy.gd::setupEnemyInfo()` 与 `hurt()` 的死亡分支发出 —— 血条不必每帧扫全场。⑦ 二阶段：血条填充转橙红 + 浮出 `PHASE 2` 标签 + 50% 刻度变红。踩坑：`boss.gd` 里重复声明了 `bossTier`（`enemy.gd` 新增了同名成员），GDScript 子类不能与父类同名字段 → 7 个 boss 脚本全部 Parse Error，删掉子类声明即可。验证：探针 **20 项断言全过**（挂在 HUD、无 boss 时隐藏、出生即绑定、名字正确、数值同步、受伤跟随、大 boss 抢占、小 boss 不抢、二阶段标签/刻度/变色、大 boss 死后回落到活着的小 boss、全灭隐藏）；截图确认常态与二阶段两种观感
| 2026-11-01 | §十九 Boss 实现（7 种场景 + 测试场景） | v2.2 | 需求：「如果没有特别需要改动的，就实现这些boss的场景，图片先空着或者用占位图，先不直接加到关卡里面；加一个测试场景专门用来测试这些boss」。① **7 种 Boss 全部落地**：`script/enemy/boss/` 下 1 个基类 + 7 个脚本，`scene/enemy/boss/` 下 7 个场景（**占位美术**：复用实验坦克/直升机 SVG + `modulate` 上色 + `scale`，生成脚本在 `.td_verify/gen_bosses.py`）。② **基类 `boss.gd`** 提供：读 Boss 字段、**地面脉冲光环**（`_draw`，按 `bossAuraColor` 区分类型 —— 没有专属美术时这是最可靠的识别手段）、`summonAt(kind, back, hpScale, props)`（带路线进度的召唤）、`tickShooter()`、以及**免疫减速的 `addSlow()` 钩子**。③ **行为**：铁壁=纯 `armor 0.7`；巢母=6s 招 3 只且**本体死亡即停**；突袭者=纯 speed 90；分裂体=死亡分裂 2 个 40% 血小号并用 `props={"canSplit":false}` **只分裂一层**；压制者=5s 让 260 内塔 `applySilence(2)`；炮艇=飞行 + 4s 投弹且**单次伤害封顶 15% 塔血量**（用户确认要加，否则"没建防空"直接必崩）；要塞=射击 + 10s 召唤 + **<50% 二阶段**（攻速 ×1.5 / 移速 ×1.3 / 免疫减速）。④ **配套**：`enemyType` 末尾 +7、`enemyInfo` +`isBoss/bossTier/bossBarName/bossAuraColor`、`enemyScenes` 登记 7 个场景（**但没配到任何关卡**）；`base_level.spawnEnemy()` 新增 `progress`（在当前位置生成，分裂/召唤用）、`hpScale`、`props` 三个可选字段；`tower.gd` 新增 `silencedLeft/isSilenced()/applySilence()`，用 `canShot` 做闸 —— **9 个塔脚本一行没改**。⑤ **测试场景 `scene/test/boss_test.tscn`**：直接 F6 运行，加载**真实第 1 关**当背景，左侧面板 7 个按钮各生成一种 boss，悬停显示"怎么打"，另有「清空 Boss」；**不进游戏流程**。⑥ 踩坑：手写 `.tscn` 时把子节点写成 `name="radar/shape"`（非法，必须 `name="shape" parent="radar"`），导致 radar 形状覆盖失败；另外把 `radar` 与 `radar_radius` 两个参数传错位，`muzzleOffset` 一度变成 1.0。已改为**用生成脚本产出 .tscn**，参数集中在一张表里。验证：探针 **51 项断言全过**（7 种全部生成、物理 31/能量 100、突袭者可被减速 90→63、巢母招 3 只且死后停、分裂出 2 个 40% 血且不可再分裂、压制者只沉默光环内、炮艇 flying 且伤害封顶 30、要塞二阶段 28→36 / 0.70→0.47 / 免疫减速、Boss 不显示头顶血条）；截图确认 5 只小 boss 与要塞+炮艇在场且光环可辨
| 2026-11-01 | §十九 Boss 设计重做（两级 + 7 种） | v2.1 | 需求：「每一关会有小 boss，不一定每关都需要大 boss，要设计几种 boss 出来，不一样的特点，增加游戏乐趣」。**结构**：小 boss **第 4 关起每关 1 个**（倒数第二波出，**前 3 关与教程关不放** —— 前三关还在教基本威胁，塞 900+ 血的大块头会劝退）；大 boss **仅第 6 / 9 / 12 / 15 关**（最后一波出，且这些关**同时**有小 boss 当热身）。**大 boss 从原来的 4/8/12/15 错开到 6/9/12/15**：否则第 4 关会"小 boss + 大 boss"同场，而那是玩家第一次见 boss。大 boss 带 **50% 二阶段**。**6 种类型各有"逼你换打法"的特点**：① 铁壁（护甲 0.7，逼你用能量伤害：特斯拉 / 加农炮破甲弹）② 巢母（每 6s 召唤 3 只，逼群伤）③ 突袭者（移速 ×1.8、不还击，逼 EMP 减速）④ 分裂体（死亡分裂 2 个 40% 血，逼持续范围伤害、逼你决定"什么时候杀"）⑤ 压制者（光环 260 内塔沉默 2s / 5s，逼你分散建塔）⑥ **炮艇（飞行小 boss，血 750、投弹拆塔、只有无人机/激光/火箭打得到，EMP 对它无效）** ⑦ 要塞（大 boss：4 炮塔 + 10s 召唤 + <50% 狂暴且免疫减速）。**关键设计决定**：**默认 boss 不免疫减速，只有大 boss 二阶段免疫** —— 否则 EMP 在"最需要它"的突袭者面前失效，等于废掉一座塔。**数值**：小 boss 血 400~1100、大 boss 3000，逐关乘 `bossHpMul`（`1.0 + 0.39 × (id-1)`）；`lossPoints` 小 3~5 / 大 8（基地 20 血，漏大 boss 是灾难级失误）。**数据结构**：boss 是**独立敌人类型**（追加 enum 末尾），`enemyInfo` 加 `isBoss / bossTier / bossBarName / bossAuraColor`；`StageData` 加 `bossWave / bossType / bossHpMul / bigBossWave / bigBossType`。**生成**：`buildWaveSpawner()` 追加 `isBoss` 记录，**跳过 `countScale`**（否则蜂群会刷 2 个 boss）。**美术缺口**用"可读性"顶替：放大 1.25~1.6 + `_draw()` 画本类型颜色的地面光环（复用敌人范围圈画法，零资源）+ 顶部大血条；⚠️ 放大仍要**提高 SVG 导入尺寸**（64→128 再缩到 0.9），否则糊。**明确不做**：飞行大 boss（可用塔压到 3 座、单一解法）、无敌护盾型（纯等待、没决策）。分 6 个阶段（M1 占位 → M2 血条 → M3 六个小 boss → M4 要塞 → M5 关卡配置 → M6 正式美术），并要求每个 boss 一个探针（见 19.10）
| 2026-10-25 | 战斗模式：**禁止改出怪间隔**，改用移动速度 | v1.1 | 需求：「这些模式当中，出怪的间隔不能修改，如果变少了，敌人会叠在一起，改移动速度是可以的」。**问题确认**：蜂群原本 `delayScale: 0.5`（出怪间隔减半），而敌人走的是同一条 `Path2D`，间隔一缩后一个就会追上前一个、**在路径上叠成一团**，既难看也分不清个体；铁流还用了 `delayScale: 1.25`（反向变慢）同样属于改间隔。**改法**：① 从 `battleModeDefs` 删掉 `delayScale` 字段、删掉全局 `Game.modeDelayScale`，`base_level.gd::nextSpawnDelay()` **不再读任何模式倍率**（只保留无尽模式自己的 `spawnDelayScale`，与战斗模式无关）；② 新增 `speedScale` + `Game.modeSpeedScale`，在 `enemy.gd::setupEnemyInfo()` 里乘到 `speed` 上，**并且必须在记录 `baseSpeed` 之前** —— 否则 EMP 的 `removeSlow()` 会按未加成的原速还原，把蜂群的 ×1.2 抹掉（这条有专门的断言）。③ 数值：蜂群 `speedScale 1.2`（数量 ×2 但间隔不变，一波队列更长，提速让节奏不至于拖成两倍；代价是每个敌人在射程里待的时间变短，符合挑战定位）、精锐 `1.1`、铁流 `1.0`（它的"慢"来自更耐打，不靠拉长队列）。④ 情报面板的**速度**列也乘模式倍率（之前只处理了血量），否则显示的是没加成的数值；`_Mode_swarm_desc` / `_Mode_elite_desc` 文案同步改为"移动速度 +20% / +10%"。验证：探针 11 项断言全过 —— **四种模式的 `nextSpawnDelay()` 全部 = 1.6000**、速度 normal 50 / swarm 60 / armor 50 / elite 55、EMP 对 60 减速到 48 且解除后回 60（不是 50）、情报面板速度列显示 60 / 54 |
| 2026-10-25 | 战斗模式可见性（徽章 + 横幅 + tooltip） | v1.0 | 需求：「选了模式进入关卡后，开始游戏介绍界面要有个**醒目的提醒**；左上角可以加一个显示模式（正常模式不用写）；最好鼠标放上去有提醒」。① **左上角常驻徽章**：`title.gd` 新增 `setBattleMode(modeId)`，在 `hboxLevel` 里**由代码创建**一块 `PanelContainer`（锈红底 `#6B2419` + 橙红描边 + 圆角 + 30px 字号）承载模式名，**正常模式 `visible=false`**。之所以用代码建而不改 `title.tscn`：它只是"带底色的文字 + tooltip"，没有需要在 Inspector 里调的静态属性，而且只有挑战模式才存在。⚠️ `mouse_filter` 必须是 `STOP`（默认值）——设成 `IGNORE` 的控件不参与悬停，`tooltip_text` 永远不会出现。② **开场介绍面板的醒目横幅**：`level_intro_panel.gd` 新增 `modeBanner`（整宽 `PanelContainer` + 两行 Label，30px，锈红底），**插在副标题正下方**。之前的做法是把 `[蜂群]` 拼在副标题前面 —— 和关卡描述混成一句，等于没提醒，已删除该前缀。③ **悬停说明（改为自定义面板）**：起初用 `Control.tooltip_text` 挂在徽章 / 横幅 / 关卡选择按钮上 —— 实测**原生 tooltip 是能弹的**，但会「没反应」：它固定有 **0.5 秒延迟**、字号颜色跟随全局主题、还要鼠标精确停在 87×47 的徽章内，玩家往往以为没做。现改为 `mouse_entered` / `mouse_exited` 驱动的**自定义提示面板**（`title.gd::buildModeTip/showModeTip/hideModeTip`：深色底 + 橙红描边 + 金色标题「蜂群」+ 正文规则，挂在 title 根节点、贴徽章正下方、越界自动夹紧、`mouse_filter = IGNORE` 避免自己触发 `mouse_exited` 造成闪烁），**零延迟**。徽章内边距也从 14/2 加大到 18/6、字号 30→32，更好点中。④ `map.gd` 不再往 `levelName` 拼 `" · 蜂群"`（拼字符串既没法带 tooltip、也没法单独上色），改为调 `titleNode.setBattleMode(Game.battleMode)`；无尽模式走同一条路（mode=normal → 自动隐藏）。⑤ 新增翻译键 `_ModeChallengeTitle`。验证：探针 10 项断言全过（蜂群：徽章可见且文案为"蜂群"、横幅可见、副标题不再有 `[` 前缀；正常模式：徽章与横幅都隐藏、`levelName` 无后缀）；悬停提示另跑一轮 13 项断言（`mouse_entered`/`mouse_exited` 已接线、触发后**立即**可见、标题=模式名、正文含规则与"不记录星级成就"、面板在屏幕内且位于徽章下方、移出即隐藏、切回正常模式连提示一起消失）；截图确认介绍页横幅、战斗中徽章与悬停面板
| 2026-10-24 | §十八 塔技能（实现） | v1.2 | 按 v1.1 设计落地，**9 座塔全部有技能**。① **框架在 `tower.gd`**：`skillKind / skillDef / skillActiveLeft / skillCooldownLeft / skillOn / skillDisabledLeft` + `setupSkill / hasSkill / canUseSkill / useSkill / toggleSkill / startTimedSkill / endTimedSkill / runInstantSkill / tickSkill / isSkillActive / isDisabled / canAct`。② **与升级不冲突的做法（用户明确要求）**：`atk / delay / radarScope` 是**升级系统拥有的基值**，技能只提供**派生值** `effectiveAtk / effectiveDelay / effectiveScope`，从不写回基值；同时把 `delayTimer.wait_time` 与 `raderShape.shape.radius` 两处派生写入收口到 `applyFireRate()` / `applySight()`，`levelUp()` 也改成调这两个入口。于是"技能生效中升级"= 基值更新 + 倍率仍然叠加，既不会被升级清掉，也不会双倍。③ **6 处伤害读取改为 `effectiveAtk()`**（机枪/加农/火箭/激光/特斯拉）与 `homeBase.effectiveAtk()`（无人机），`hurt()` 增加 `damageTakenMul()`（铁箱减伤），并抽出 `die()` 让`hurt()` 与技能自损 `applySelfDamage()` **共用同一条死亡流程**。④ 逐塔：机枪**过热**（atk×2、射速×2、自损 6/s、3s、CD18）；加农**破甲弹**（子弹新增 `damageType`，技能期间 `"energy"` 绕过 armor，射速×0.7）；火箭**导弹模式**（toggle：射程×1.6、伤害×1.25、弹速 520、转向 6.5，**`noSplash` 走独立分支直接 `enemy.hurt()`、不生成 bomb**）；EMP**强磁过载**（slowMul×2、5s、结束后 `disableAfter` 3s 停转且期间不提供减速）；激光**单体打击**（toggle：`maxTargets()` 3→1、atk×2.2、切换时释放多余锁定并关喷溅）；特斯拉**链式放电**（`maxChain()` +2、自损 5/s）；无人机**紧急升空**（伤害×1.5，`drone.gd` 读 `homeBase.effectiveAtk()`）；铁箱**应急装甲**（受伤×0.3）；机甲**紧急维修**（自身+半径180内各塔回 30% **各自** maxHp，用 `addHp` 不用负伤害，随后 `skillDisabledLeft=3` 整机停止：`mech.gd::_physics_process` 入口挡住 + `stopAllWork()` 收尾，含 `abortSalvage()` 释放残骸认领）。⑤ **UI**：`tower_detail_panel.tscn` 新增 `SkillRow`（**技能按钮单独一行**，用户要求）+ `btnSkill`；文案按 kind 区分（切换：/使用：）、显示冷却/生效/停止倒计时、生效时安全黄高亮；**面板数值改显示派生值**（否则切了模式看不出变化）。⑥ 文案 20 行。验证：探针 **41 项断言全过**，其中冲突相关的关键项 = 过热生效中 `levelUp()` → `atk 10 / effectiveAtk 20`、`delay 0.36 / effectiveDelay 0.18`、`delayTimer.wait_time == effectiveDelay`、`aniSpeed` 跟着派生值；toggle 生效中升级 → `base 210 / shape 336`；另验证自损 3s 恰好 18、切换 CD 拦截连点、激光 3→1、机甲回复 +72/+96 与停止 3s 后恢复；UI 截图确认按钮独立成行 |
| 2026-10-24 | §十八 塔技能表（需求修订 v1.1） | v1.1 | 需求三条：① 火箭塔切成远距离导弹、**没有爆炸范围**，切换 CD 3s；② 激光塔切成单体打击、只锁一个、伤害增加，切换 CD 3s；③ 机甲改成立刻修复自身与范围内塔 30%，之后无法使用（最终确定为**整个机甲停止 3 秒**）。**设计变更**：技能从"只有限时大招"扩成三种形态 —— `toggle`（功能切换，持续生效，3s 切换 CD）/ `timed`（限时增益，长冷却）/ `instant`（瞬发）。新数值全部对着代码当前值写，并用"从多少改到多少"标注：**火箭塔** atk 40→50、scope 200→320、弹速 300→520、转向 5.0→6.5，**`blastRadius 90` → 不溅射**；**激光塔** `MAX_TARGETS` 3→1、对单 atk 38→**95（×2.5 而非 ×3，满编 114 的时候切过去必须有代价）**；**机甲** `healRatio 30%`（各塔**自身**最大血量的 30%）、`healScope` 180（复用现有维修半径）、**`shutdown` 3s** —— 用户明确确认是**整个机甲停止 3 秒**（不能移动 / 不能维修 / 不能回收残骸），不是"按钮冷却 5 秒"。这两个概念在 18.2 里专门分开了：冷却只挡按钮，停止让单位整体失效，必须在 `_physics_process` 里挡。**新增的坑（六条，都写进 18.6；前三条是 toggle 的，后三条是停止的）**：① 导弹模式的"不溅射"不能靠把半径调小 —— `rocketbullet.gd::spawnBomb()` 里 `bomb.blastRadius = 90.0` 是写死的、伤害由 bomb 的范围结算，必须改成命中时直接 `enemy.hurt(atk)`、不生成 bomb；② 激光塔从 3 目标切到 1 目标时必须**把多余锁定移除并停光束**，否则会出现"只锁一个但三条光束还挂着"；③ `toggle` 改射程要**同时改** `radarScope` 与 `raderShape.shape.radius`，只改前者会"圈变大但打不到"（因此新增 `applySight()` 作为唯一入口，与 `applyFireRate()` 同一套路）。实施顺序也调了：把"一座 toggle（火箭塔）"提到最前（M2），先趟完 toggle 的坑再照抄激光塔 |
| 2026-10-24 | EMP 减速改为「取最强一条」（修叠加漂移） | v1.0 | 需求：「EMP 塔叠加的这个修改一下，敌人只能受到一个 EMP 塔的限制」。**旧实现的 bug**：`emp_tower.gd::applySlow` 直接改 `enemy.speed` —— 进入乘 `(1-ratio)`、离开除回去。两座 EMP 射程重叠时连乘两次；离开时按**各自**的比例除回，只要两座塔强度不同（或整数 `round` 累积误差）就除不回原值，敌人速度漂移到一个既不是原速、也不是任一减速值的结果。更糟的是"离开顺序"会影响结果。**修法**：把状态合并移到敌人身上（`enemy.gd`）—— 新增 `baseSpeed`（在 `setupEnemyInfo()` 读完 `enemyInfo` 后记下原速）与 `slowSources: Dictionary`（来源 → 比例），新增 `addSlow(source, ratio)` / `removeSlow(source)` / `refreshSpeed()` / `currentSlowRatio()`。`refreshSpeed()` **取最强的一条**而不是连乘：多座 EMP 重叠只受最强的那座限制（正好是需求要的语义），离开一座回落到次强，全部离开则精确恢复 `baseSpeed`；同时顺手剔除已释放的来源（塔被卖掉后 `is_instance_valid` 为假）。`emp_tower.gd` 去掉两处直接写 `enemy.speed`，改为 `enemy.addSlow(self, slowRatio())` / `enemy.removeSlow(self)`，`_exit_tree()` 也从"把速度除回去"改成"注销自己这个来源"（塔被卖掉 / 场景卸载必须注销，否则减速会永久残留）。上限 `MAX_SLOW_RATIO = 0.9`：留 10% 速度，避免将来把 EMP 的 atk 调高后出现速度 0、敌人卡在同一格的僵局。**行为变化**：以前 N 座 EMP 叠加能让敌人几乎静止，现在不行了 —— 这是需求明确要的。验证：探针 11 项断言全过（1 座 50→40、2 座仍 40 不叠加、移除一座仍 40、全部移除精确回 50、40% 与 20% 重叠时取 40%→30、离开强的回落到 20%→40、真实雷达 `area_entered` 路径生效、塔 `queue_free()` 后速度恢复） |
| 2026-10-24 | §十七 战斗模式（实现） | v1.0 | 按设计稿落地，四个模式：**正常 / 蜂群 / 铁流 / 精锐**。① `game.gd` 新增 `battleModeDefs`（每个模式一组倍数）+ `battleMode` 状态 + **独立**的 `modeHpScale / modeAtkScale / modeCountScale / modeRewardScale / modeExpScale / modeGemScale`（v1.1 另加 `modeSpeedScale`，见 2026-10-25 条），以及 `setBattleMode / applyBattleModeScales / resetBattleMode / isChallengeMode / getBattleModeDef`。**关键：没有复用 `Game.enemyScale`** —— 那个被无尽模式每波重写（`endless_level.gd:291`），复用会互相覆盖；`enemy.gd::setupEnemyInfo` 里改成两者**相乘**。② `base_level.buildWaveSpawner()` 逐条 `maxi(1, ceil(number × countScale))`（`duplicate()` 保证不污染 `StageData`），`nextSpawnDelay()` **不动**（出怪间隔不允许被模式改 —— 早期曾乘 `modeDelayScale`，v1.1 已删除，见 2026-10-25 条）。③ 关卡选择页底部加一排互斥模式按钮（代码创建，不改场景 —— 标题 75~202 与卡片 215~905 之间没有余量，只有底栏左侧空着），选中的挑战模式染锈红 + 下方一行说明；`loadMap()` 里才 `Game.setBattleMode()`。④ 顶栏关卡名挂角标「第 1 关 · 蜂群」；情报面板副标题前置 `[蜂群]` 并注明不记星级/成就。⑤ **奖励隔离**：`userData.recordStageCompletion()` 新增 `modeId` 参数，挑战模式走 `recordChallengeClear()` —— 不写 `stageRatings`、不解锁、不发星级奖励，宝石按 `ceil(baseGem × gemScale)` 发一次并记进新增的 `challengeCleared`（`"swarm:3"` 形式，随存档持久化）。**这一步是必须的**：挑战模式既然不写星级，就不能再拿星级表判断"首通"，否则每打一次都是首通、宝石无限刷。⑥ `achievement_tracker` 加 `trackingEnabled()`，挑战模式下 4 个入口（击杀/建造/升级/通关）全部早退，否则蜂群的翻倍击杀会把 `legion_slayer`(3000 杀) 加速刷满。⑦ **顺手修了情报面板的数值**：它原本直接读 `StageData` 原始值，蜂群下显示 x94 / 血量 150 而实际刷 x188 / 75 —— 现在 `collectEnemyStats()` 与 `buildEnemyList()` 都按同一套算法换算，并在挑战模式隐藏「3★ 额外宝石」格与星级规则说明。验证：探针 18 项断言全过（count 16→32、delay 1.6→0.8、StageData 不被污染、hp 150→75、reward 5→3、exp 2→1、armor hp 300/reward 10、挑战模式首通宝石 `ceil(8×1.3)=11`、重打不发、**不写星级**、无星级奖励、正常模式仍是 8+4=12 且写 3★、离开关卡 mode 与倍数全部复位）；UI 截图确认模式条与情报面板显示正确 |
| 2026-10-23 | 星级奖励：门槛放宽 + 可发现性 | v1.0 | 承接上一条。两个问题：① **3★ 要求"基地一滴血不掉"**（`calculateStars` 原本 `healthRatio >= 1.0`），在各关难度差异极大 —— 基地血量 10 和 20 的关，100% 意味着一个都不能漏；既然三星现在发宝石，这个门槛就过于苛刻。改为 **`>= 0.9`**（`THREE_STAR_HEALTH_RATIO`），允许漏 1~2 个。⚠️ 成就「零损防线」（`perfect_base`）**不受影响**，它走的是 `recordAchievements()` 里的 `flawless := hp >= level.health`（真·零损），星级放宽、成就门槛不放宽。② **玩家不知道星级能换宝石** —— 只有结算时看得到，而且是"已经拿到"之后。在**关卡开场情报面板**补了两处：`buildInfo()` 里新增一格 **「3★ 额外宝石 +N」**（金色 `COLOR_STAR_BONUS`，数值 = `UserData.starBonusTotal(gemReward, 3)`），以及 InfoBox 下方一行规则说明（`showStarHint()` 用代码创建 Label、插在 InfoBox 之后，不改场景文件）—— 同时交代"90% 即可"和"仅在刷新最高星级时发放"两件玩家猜不到的事。选择情报面板而不是关卡选择卡片：卡片只有 `num + 星级 + 锁标` 三样，塞说明会挤；情报面板在开打前弹出，时机也对。验证：门槛矩阵 7 项全过（20/20→3★、18/20=90%→3★、17/20=85%→2★、10/20=50%→2★、9/20=45%→1★、1/20→1★、0→0★）；情报面板复用测试通过（关卡页显示 → 无尽页隐藏 → 回关卡页恢复），无泄漏 |
| 2026-10-23 | 图鉴图标按当前美术重出 | v1.0 | `sprite/icon/unit/*.png` 全部停留在 10-07，而敌人 `_v2` 素材是 10-13 换的、之后车身与炮塔又各缩过一次 → 图鉴一直在显示旧美术。`art_style.md` 提到的 `tools/codex_icon_gen.html` **并不在仓库里**，改为新写生成器（`.td_verify/gen_codex_icons.gd`）：**直接渲染敌人场景**而非手工拼 PNG（敌人结构已不统一：多数有 `turret`、实验坦克有 4 个 `TurretFL/FR/BL/BR`、无人机有 4 个 `Rotor`、战斗飞机只有车身）。构图对齐既有 21 个图标：最长绘制边 124px、居中。两处返工：① 按**贴图画布**算包围盒 → 图标过度放大只看到轮子（64×64 画布里只装约 40px 车）；② 在 1:1 上**放大**导致发糊 → 改为 4 倍渲染后缩小 |
| 2026-10-23 | 成就图标居中修正 | v1.0 | 面板侧本来就已经居中（`CenterContainer` + `SHRINK_CENTER` + `STRETCH_KEEP_ASPECT_CENTERED`），问题在**素材本身**：8 个 PNG 的绘制内容在 128 画布里偏下 1~12px（`ground_breaker` 偏 12、`full_armory` 偏 10.5），放进圆形徽章再放大到 146px 后肉眼可见。修法：裁到绘制范围 → 居中贴回原尺寸画布（不缩放、不糊），残差 ≤0.5px。**4 个 SVG 本来就居中**（绘制框 1..126），未改动 |
| 2026-10-23 | 敌人素材尺寸归位 + 炮塔比例 | v1.0 | `_v2` 素材的绘制内容占画布约 95%，而旧素材只占 60~70%，导致换图后整体偏大。按敌人逐个缩放车身（迷你 0.871 / 中型 0.935 / 重型 0.968 / 装甲 0.968 / 突击车 0.726 / 维修车 0.758 / 自爆车 0.871 / 导弹车 0.871 / 无人机 1.217 / 直升机 0.981 / 实验坦克 1.516），炮塔再按同一车身系数缩放并把 `muzzleOffset` 按 `off_x + (old_m - off_x) * bw` 重算。**踩过的坑**：`str.replace` 的 needle 退化成单字符 `'s'` 把 `miniTank.tscn` 从 76 行写成 171,610 行（已从备份恢复，后改用只走 `re.subn` + 预期计数、不匹配就整文件放弃的写法） |
| 2026-10-23 | 敌人 `_physics_process` 缺 `super` | v1.0 | 9 个敌人子类各自重写了 `_physics_process` 却**没有调 `super`**，基类的雷达扫描与 `queue_redraw()` 从未执行 → 点击敌人后攻击范围圈**不旋转**。9 个文件全部补上 `super._physics_process(delta)` 作为首句；顺带补齐 4 处 `freeSelf()` 之后漏掉的 `return`。另修 `enemy.gd` 里 `lifeBar.global_position` 在 `parent == null` 时抛 Nil 中断 `_draw()` 的问题 |
| 2026-10-23 | 实验坦克 4 座炮塔不可见 | v1.0 | `TurretFL/FR/BL/BR` 在场景里写死 `visible = false` 且**没有任何代码打开**，而 `enemy.gd` 用 `turret.visible` 作为"能否用共享炮口开火"的判据 → 这辆坦克既看不见炮塔也**打不出子弹**（图鉴却宣传"4 炮塔"）。改为可见；**主炮塔 `turret` 保持隐藏**（它是基类占位兼开火开关，打开会多打一发隐形子弹） |
| 2026-10-23 | 生命条可见性改由持有者控制 | v1.0 | 原 `life_bar.gd` 的 `value` setter 里直接写 `visible = true`，而敌人信息面板每帧回写 `e.hp` → **只要点中敌人血条就被顶出来**，与"是否被击中"无关。拆成"数值只管数值"，新增 `flashFor/flash/conceal/isShowing/remaining`，由敌人/塔/机甲各自决定显隐。敌人规则：**选中不显示，被击中强制显示 3 秒**（`HIT_SHOW_SECONDS`）。踩坑：方法原本叫 `show`/`hide` 会**覆盖 `CanvasItem` 内建方法**导致解析失败，改为 `flash`/`conceal` |
| 2026-10-23 | 机甲抢同一坨残骸 | v1.0 | `pickSalvageTarget()` 只按最近距离选，多台机甲会锁定同一坨并来回拉扯。新增残骸认领：`wreckage.gd` 加 `salvager` 字段与 `tryClaim/releaseClaim/claimedBy`，机甲选目标时跳过已被他人认领的；`updateSalvage()` 不再每帧重选（新增 `advanceSalvage(delta)`），放弃时 `abortSalvage()` 释放认领 |
| 2026-10-23 | 图鉴补机甲图标 | v1.0 | 图鉴防御塔页原本只有 8 座塔，缺移动机甲。`codex_panel.gd` 的 `TOWERICONS` 补 `mechTower.png`（由 `mech_base_1.png` + `mech_turret_1.png` 合成，192×192），图鉴显示为 9 座 |
| 2026-11-02 | §二十二 H 提前召唤（实现） | v1.0 | 按设计稿落地。① **调度**：`base_level.tscn` 新增 `IntermissionTimer`（继承到全部关卡），上一波清空后进入 20 秒间歇；`onWaveTimerTimeout()` 拆出 `startNextWave()`，自然到点与提前召唤走同一条开波路径，**`nextSpawnDelay()` 未改一个字节**。② **默认值**：`WAVE_INTERMISSION = 20.0`，关卡数据可用 `waveInterval` 覆盖；**无尽 / 教程关设为 0**，保留"清空即下一波"的原节奏（无尽隐藏按钮，教程引导不该空等）。③ **奖励**：`min(ceil(剩余秒数) × 2, 该波击杀总金币 × 30%)`，按 UI 显示口径向上取整改为整数秒，避免"面板 12s 却给 23"；击杀金币乘 `modeRewardScale` 对齐挑战模式；Boss 波可召唤但恒为 0，按钮转警示色。④ **UI**：新增 `scene/ui/early_call_panel.tscn` + `script/ui/early_call_panel.gd`，挂在 map HUD 右下角（原进度条位置），`map.gd::_process` 每帧读 `level.getEarlyCallInfo()`；金币由 `map.gd::onEarlyCallPressed()` 入顶栏。⑤ `ENABLE_EARLY_CALL` 总开关保留。验证：临时探针 **43 项断言全过**（第 1 波前无按钮、间歇 20s、第 8 秒 +24、自然到点开下一波、1X/2X 同奖励、波内间隔未改、Boss 0 金币、无尽禁用、最后一波后无间歇、HUD 显示→点击→入账→收起整链路） |
| 2026-11-05 | 回血特效缩放 + 弯道平滑 | v1.0 | 反馈两条：「医疗车恢复动画偏大」「直角弯道敌人转身生硬」。① **回血特效**：`heal_particles.tscn` 缩放 0.20~0.32 → **0.12~0.20**（144px 贴图 → 17~29px），初速 170~280 → **120~190**（尺寸与散开半径同步收，避免"小十字飘很远"）；`enemy.gd::addHp()` 的参数注释同步更新。② **弯道平滑**：`base_level.collectRoutes()` 新增 `smoothRouteCorners()`——**转角点替换为圆弧采样点**（15°~160° 转角；半径由「顶点到弧中点内切 ≤4px」反推，切点距 ≤14px 且 ≤0.45×短边防相邻弧重叠；弧上按 2px 采样；烘焙间隔压到 2.5）。**关键实测**：Godot 4.7 的 Curve2D 已删除 point mode API，`set_point_in/out` 写进能读回、但对烘焙**零影响**（`enum_peek` 探针：baked length == 折线长度和）——所以放弃贝塞尔方案，纯折线加密任何版本行为一致。4px 预算的依据是传送带面宽只有 37px、分道最大 ±9px。③ **坑**：项目 GDScript **警告按错误处理**（`:=` 从 Variant 推断、不存在的枚举常量都会让脚本解析失败），探针场景因此静默挂起两次才查出；GDScript 常量是 `INF` 不是 `INFINITY`。验证：`scene/test/route_smooth_probe.tscn` **17/17 全过**（端点不动/顶点消失/内切 ≤4.3px/单步转角摊薄/幂等/折返豁免/level_1 双路线/回血四参数）；`all_levels_check.tscn` 全量核查 **45 条路线全 OK**——转角单步从 90° 摊到 ≤11.3°，点距 ≥1.89px 无一触发防重叠兜底，直线航线原样保留 |
| 2026-11-02 | §十九 多 Boss 血条（实现） | v1.0 | 需求：「Boss 只能每波一只吗？能不能有两只以上，血条怎么改」。① **血条从单条改多行堆叠**：`boss_health_bar.tscn` 改成 `Stack/Rows` 容器，单行抽成 `boss_health_row.tscn` + `boss_health_row.gd`；主脚本用 `rows: Dictionary`（Boss → 行）管理，出生加行、死亡/被释放删行，不再有"只跟一只"的状态。排序：大 Boss 优先、同级按 `spawnSeq` 从早到晚（新刷的小 Boss 不会顶掉旧行）。最多显示 **2 行**，超出显示「还有 N 只 Boss」；小 Boss 48px、大 Boss 56px（血条 10/12px，名字字号 24/26），行边框/名字用 `bossAuraColor` 区分；整体固定在标题栏正下方居中（top=112），不遮挡顶栏金币等信息。二阶段（50% 标签 + 刻度变色）仍在每行内独立生效。② **横幅去重**：`map.gd` 记录 `bossBannerWave/bossBannerTier`，同波只播一次，仅允许更高档位 Boss 再覆盖一次；测试场景 `boss_test.gd` 手动刷 Boss 前调 `resetBossBannerDedup()`。③ **Boss 不吃数量倍率**：`base_level.buildWaveSpawner()` 的 `modeCountScale` 跳过 `enemyInfo.isBoss` 行（与 §十七 设计一致，蜂群不会把 1 只 Boss 翻成 2 只）。验证：临时探针 **35 项断言全过**（1/2/3 行显示、第 4 只溢出 +1、大 Boss 置顶且 +2、 同波横幅不重复/大 Boss 覆盖、二阶段标签与刻度、击杀移除行、节点被绕过信号释放也能兜底清理、数量倍率只翻普通敌人不翻 Boss、全清隐藏）；另修 `map.tscn` 实例上的 `anchors_preset` 覆盖把血条贴到 y=0 的问题；最终按需求把血条放回标题栏正下方（top=112，探针确认标题栏底 98 < 血条顶 112），名字字号放大到 24/26 |
| 2026-11-02 | 波次 / Boss 横幅位置漂移（修复） | v1.0 | 现象：改了 Boss 血条位置后，玩家发现横幅位置也变了 —— 实际与血条无关，是横幅自身的既有 bug。`battle_start_banner.gd::play()` 里写 `band.position.y = 0.0`，而 band 的父节点是 `CenterContainer`：第一次播放时容器会重新排序并把 band 居中（y=435），紧接着的第二次播放（同一实例连播「波次横幅 → Boss 横幅」）容器不再排序，`position=0` 就真的把横幅顶到屏幕最上方。修法：删除 `band.position` 写入与 `position:y` 上移动画（`outOffsetY` 一并删除），位置完全交给 `CenterContainer`；进出场只保留淡入淡出 + 缩放。验证：探针连续播放 `playWave()` → `playBoss()`，两次 `band.position.y` 均为 **435**（1920×1080 下正中），不再出现 y=0 |
| 2026-11-12 | §二十六 M3a：实装 `zh_TW` / `ja` / `ru` 三个语种 | v1.0 | 需求：「其他语言的翻译先帮我加上，俄语的也加上」。**只追加 3 列**（`Keys`/`en`/`zh` 三列逐字未改，脚本对比验证）。① **为什么先只加这三个**：26.2 实测主字体谚文 0/11172、泰文 0/128、越南变音符 4/256，而 CJK 20976/20992、西里尔 100% —— 所以 `zh_TW`/`ja`/`ru` 是"字体安全"的那三个，`ko`/`th`/`vi` **故意不加**：现在登记进下拉等于给玩家一个切过去看豆腐块的按钮。② 登记链路全是数据驱动：`Game.language` 从 2 条到 5 条，`setting.gd` 的下拉/切换/持久化**一行没改**；`project.godot` 的 `locale/translations` 必须手写（实测 `--import` 不会自动加）。③ 语种判定重写：`SYSTEM_LANGUAGE_ALIASES`（`zh_TW/zh_HK/zh_MO/zh_Hant*` 走繁体）+ 地区精确表 → code 精确 → 语言前缀 → `en`；`loadSettings()` 的 schema 迁移原来硬写 `begins_with("zh") → "zh"`，会把繁体老玩家迁回简体，改成复用同一判定。规则拆成纯函数 `_languageFromLocaleString()` 才能测（`OS` 单例桩不掉），探针 C8 喂 10 组 locale。④ **顺带修掉一个存量视觉 bug**：主菜单按钮列固定 356px，实测 `get_combined_minimum_size()` 显示英文 `Endless Mode` 需要 379 —— **英文一直在被截断**；加 `ja`(388) / `ru`(411) 后更明显。列宽改 420（`btn_normal.tres` 是 StyleBoxFlat 矢量，拉宽不失真）。为放下做了三处短译（«Бесконечный» / «Энциклопедия» / «エンドレス»）。⑤ **两条我之前的判断被实测推翻**：`custom_minimum_size` 的 220/240 是**下限不是上限**，所以 §26.6 的 #5 #6 不成立（下拉装满 5 个语种名只需 215，父面板 968）；`_About_Text` 的"逐语种手工断行"也不成立（是 `RichTextLabel` + `autowrap=WORD_SMART`，zh/ru 实测内容高 513 < 面板 560）。⑥ **量宽度的两个时序坑**：`welcome.tscn` 内嵌 setting 面板，`setting.gd:44` 在 `_ready()` 里 `set_locale` → locale 必须 `add_child` **之后**设（否则五个语种量到同一份中文）；只 `set_locale` 不重算缓存的最小尺寸 → 必须把 `text` 摘下再装回去。⑦ 探针加 C8/C9/C10 + **C11 检查项对账**：我编辑 `_ready` 时曾把 C9/C10 挤到 `quit()` 后面，探针安静地报 `fails=0` —— "全绿"和"跑了"是两件事，现在每个检查组登记自己、末尾对账。合并工具沉到 `script/test/merge_locales.py`（预检占位符/`\n`/BBCode/**字形覆盖**，不干净就不写 CSV）。验证：`i18n_probe` **50/50**、`train_boss_probe` 33/33、`tower_quota_probe` 15/15、`all_levels_check` bad=0。**未做**：真机切一遍语言看排版（全是 headless 结论）；结算战报表那组列宽没实测（要打到通关才有内容），留作 M2 人工核对。 |
| 2026-11-12 | §二十六 国际化 M0：字体回退链 + 探针 | v1.0 | 需求：「先做第 0 步，把字体链和探针搞出来」（上游：「分析国际化还差几个，上架 Steam 要先加亚洲一些国家语言」）。**不加任何语种**，先把三类"在开发者机器上表现为一切正常"的事故变成机器检查。① **实测字体覆盖**（fontTools 与 Godot `Font.has_char()` 双向核对，唯一字体 `AlibabaPuHuiTi-3-85-Bold.ttf`）：CJK 20976/20992、西里尔 100% ⇒ 繁体与俄语几乎免费；假名 184/192 但缺 `・`/`々`；**谚文 0/11172、泰文 0/128、越南变音符 4/256** ⇒ 韩泰越必须自带字体。② 顺手抓到**现存 bug**：`_TutorialGuide4` 的 `▶` U+25B6 主字体没有 —— 现在能显示是靠 `.import:22` 的 `allow_system_fallback=true` 蹭玩家系统字体，Steam Deck / 精简系统上就是豆腐块。改文案而不是加字体（那个按钮本来就是贴图图标）。③ **回退链装配在代码**（`autoload/fontStack.gd`，注册在 `UserData` 之后）：`font/fallback/` 目录里的字体按**文件名排序**装进主字体的 `fallbacks`，前缀 `01_/02_` 就是优先级（`・` 在 JP/KR 字体里都有时，先命中者决定字形）。不写进 `.ttf.import` 的理由：主字体被 23 个场景共用、链只该配一次；且实测两种手写格式都被导入器拒绝并**重置回 `fallbacks=[]`**（填路径串报 `String to Object`，补 `[ext_resource]` 头报 `Resource file not found`），而 `*.import` 本身被 gitignore（`git ls-files` 计数 0）—— 配了也带不出本机。④ **两个坑 + 一个我自己写错又实测纠正的说法**：4.7 的 `TranslationServer` **没有 `has_key()`**（当静态方法调用直接 Parse Error），判"取不到"只能用 `translate(key) == key`，并配一条未知 key 的自检防止判据是空的；写这条时我先记成"`Font.has_char()` 只查自己、不顺着 `fallbacks` 找"，**实测推翻**：链清空 `has_char(한)=false`、挂上韩文字体即 `true`，且关掉 `allow_system_fallback` 后 `get_string_size("한국어")` 由 **108.0 → 120.0**，说明**真实排版也走链**；真正要记的是反向那半句 —— `has_char` **不认系统兜底**，所以它恰好是"打进包的字体够不够"的正确问法。⑤ 探针 `i18n_probe` **27 项**（含 C5f/C5g 锁"apply() 合并而不是覆盖"）：结构 / 四处登记同步（CSV 列 ⇄ `Game.language` ⇄ `project.godot` ⇄ `.translation`）/ 占位符 / **运行时文本与 CSV 逐条比对**（专门抓"改了 CSV 没跑 `--import`"，只查 key 存在抓不到）/ 链装配 / 逐字形覆盖 / **语种↔文字系统探测位**（抓"先登记语种、后补字体"的顺序错误 —— 那一刻该语种一个字符都没用到，覆盖检查是绿的）。⑥ **正反两轮自我证明**：临时加 `ko` 列 + 借系统 `malgun.ttf` 冒充回退字体 → C5c 链=2、C6/C7 的 ko 全 PASS，同时 C2a/C2c/C3/C4c 如期 FAIL；撤掉字体 → C6 FAIL 并报 `U+C11C x304 in _appName`、C7 FAIL 列 `U+AC00/U+D55C/U+3131`。**该字体仅本地验证、未提交、也不是合法分发方案**。另两轮踩坑：C5f 最初用 `FontVariation(base_font=主字体)` 当哨兵塞进主字体自己的 `fallbacks`，构成**引用环直接把进程问崩**（哨兵换成空 `FontFile` 才对）；`▶` 除了 CSV 还在 `script/ui/tutorial_guide.gd:208` 的硬编码兜底里出现第二处，一并改掉。清理后 `i18n_probe` 27/27、`train_boss_probe` 33/33、`tower_quota_probe` 15/15 回归不变；另清掉 `language.csv` 的一处行间空行。⑦ 待做（26.8）：M1 放 4 个 OFL 字体（本机无外网，本轮做不到）→ M2 布局 9 处固定宽度 + 泰文 `AUTOWRAP_WORD_SMART` 问题 → M3 加 `zh_TW/ja/ko` → M4 `vi/th` → M5 Steam 商店文案。另记一条现在就会咬人的：`userData.gd:89` 的 `begins_with("zh")` 把 `zh_TW/zh_HK` 判成简体 |
| 2026-11-12 | §二十五 装甲列车 M1~M2（实现） | v1.0 | 需求：「我想设计一种类似火车的 boss，每节车厢有炮塔，有 5 节车厢，独立血量，中间车厢被打爆其他就往前进，都被打爆就爆炸，逃离扣血每节单独扣」。**先做设计稿（25.1~25.12）再实现 M1~M2**。① **5 节都是真 `Enemy`**：独立 hp / 独立奖励 / 独立逃脱扣血全部白拿基类，`lossPoints 2` 每节各扣（探针 G11 实测漏两节 = 两次独立结算 = 4 点）。② **编组刚性 = 全队只有一个速度**：车厢把 `addSlow/removeSlow` 转发给 `train_conductor.gd` 的共享表，取最强一条算 `teamSpeed` 再写回每一节 —— 各节自算会让车厢间距漂走，火车散架（S1/S2/S3 覆盖）。③ **收拢只在死亡那一帧改写一次槽位**：锚点是"当前最前面那节活着的车厢"，所以 leader 死 → 整列不跳、中间死 → 后面各进一格、尾车死 → 谁都不动（G4/G5/G6）。④ **车厢 `extends enemy.gd` 而不是 `boss.gd`**：`boss.gd` 每帧压掉头顶血条，而列车顶部只有一条血条，"哪节在掉血"必须靠头顶条回答 —— 这是对 §19.7 第 6 条的有意破例，代价是光环绘制重复写约 15 行。⑤ 零件复用：炮塔 = `base_turret.tscn`（与实验坦克同一套），只是从"一个身体挂 4 炮"变成"5 个身体各挂 1 炮"。⑥ **踩到三处**：`.tscn` 里写 `#` 注释会让整个场景解析失败并连带 `stageData.gd` 编译失败（全项目报 autoload "does not inherit from Node"）；关卡的 `resolveOffset()` 给没写 offset 的兵种自动分 ±4px 车道，头节会歪出去，必须两头强制 0；**逃脱不走 `hurt()`**，所以没有 `onCarDied`，编组靠 `_process` 里 `pruneDead()` 收尾。⑦ 探针 `scene/test/train_boss_probe.tscn` **33 项全过**，回归 `tower_quota_probe` 15/15、`all_levels_check` bad=0。**已知未完成**：顶部血条现在显示的是头节自己 600 血（M3 的 `barProvider` 才改成合成血 + 5 段车厢格）、二阶段/宝石/终爆是 M4、挂关卡是 M5；**没在编辑器里真看过一列火车跑起来的样子**。⑧ **否决了需求的另一种读法**（打爆任意一节整列前移）：那会让"打爆尾车"也把列车推向基地，正确行为被惩罚、最优解退化成"别打" |
| 2026-11-05 | 建造许可证（§23.2 K 晋升实现） | v1.0 | 需求：「建造许可证这个功能可以实现，最小改动实现」。① **数据**：`stageData.gd` 新增 `towerQuota` 表（仿 `stageTowers` 的形状，**不塞进 `allStage` 条目** —— 与塔池放行同机制、同位置好维护），按 23.2.1 投放表配 3/4/7/11/15 五关；7 关"待验证"条目已核 —— `tower.gd:160` 实测火箭**可对空**（`canTargetAir` 含 droneBase/laser/rocket），限火箭成立。`getTowerQuota()` 返回 -1 = 不限。② **计数口径 = 实时扫组**：`map.countTowersAlive()` 直接数 `tower` 组存活节点（`is_queued_for_deletion` 过滤），**零簿记状态** —— 出售/爆毁/残骸化天然放额，不存在"忘了扣"的 bug 类型；组审计过，只有 `tower.gd` 一处 `add_to_group("tower")`，无人机不污染。③ **闸口**：`map.placeTower` 在池校验后加 `isQuotaFull` 拒绝（扣钱前，同机甲约束的写法）；无尽豁免；默认无配置 = 行为与现在完全一致。④ **UI**：`tower_ui.refreshQuotaLocks()` 按存活数灰卡片 + tooltip，挂 `towerPlaced / towerGridReleased` 双信号 `call_deferred` 刷新（等本帧 `add_child` 落定）；`Game.towerLocked.emit(type)` 开始带参，map 按"池未放行 or 许可证满"给不同文案；介绍面板 InfoBox 下方新增整宽许可行（仿 `starHintLabel` 的插入法）。⑤ **本地化**：`_BuildQuotaFull / _TowerQuotaTooltip / _BuildQuotaTitle` 三键（中英）。验证：`scene/test/tower_quota_probe.tscn`（真实 map + 第 3 关）**15/15 全过**（配额查询/第 5 座被拒/加农同闸/特斯拉不限/拆一座再建成功/无尽豁免/卡片灰显与恢复/信号整链路/CSV 键齐全）；`route_smooth_probe` 回归 17/17。探针踩坑两处：直调 `placeTower` 不经过 `towerPlaced` 信号，需 emit 才走真实链路；`find_child("vbox")` 撞名（HUD 里多个 vbox），必须走 `towerUINode.towerCardList` 引用 |

---

## 九、敌人攻击范围显示（Enemy Attack Range Indicator）

### 9.1 模块定位

点击敌人时，**会攻击防御塔的敌人**把它的攻击范围画出来，让玩家在布防前就能看出"这座塔会不会挨打"。

现状：敌人信息面板（§八 2026-09-12「敌人信息面板」）已经显示名称/血量/攻击/属性/收益，但**射程只有一个数字**，玩家得自己在脑子里换算成屏幕距离。本模块把这个数字变成地面上的一圈可见范围。

### 9.2 数据来源（已存在，无需新增字段）

`Game.enemyInfo` 每条已经有：

| 字段 | 含义 | 本模块用法 |
| --- | --- | --- |
| `scope` | 攻击范围（像素） | **画圈的半径** |
| `atk` | 单次伤害（0 = 不会攻击） | 初筛"会不会攻击" |
| `role` | 行为定位（`_EnemyRole_*`） | 辅助判定（见 9.3） |

### 9.3 ⚠️ 判据不能只看 `atk > 0`

**`atk > 0` 不等于"会远程打塔"** —— 项目里有两种特例，必须按行为排除：

| 敌人 | `atk` | 实际行为 | 是否画攻击范围 |
| --- | --- | --- | --- |
| `miniTank` | 0 | 纯推进 | ❌ |
| `scoutDrone` | 0 | 纯推进（飞行） | ❌ |
| `mediumTank` | 15 | `fire()` → 打塔 | ✅ |
| `heavyTank` | 25 | `attackTower()` | ✅ |
| `armoredTank` | 18 | `attackTower()` | ✅ |
| `assaultBuggy` | 6 | `attackTower()` | ✅ |
| `missileTruck` | 35 | `fire()`，`scope 700` | ✅（射程特别远，最能说明问题） |
| `attackHelicopter` | 5 | `fire()` | ✅ |
| `battlePlane` | 12 | `fire()` | ✅ |
| `experimentalTank` | 16 | 4 座 `BaseTurret` | ✅ |
| **`medic`** | **20** | **`fire(targets: Array)` = 治疗友军** | ❌（不打塔） |
| **`suicideTruck`** | **80** | **`triggerSelfExplode()` = 撞击自爆** | ❌（无远程攻击） |

**判据实现**：`enemyInfo` 每条新增一个显式字段 **`"showsRange": true/false`**，与 §八 的 `hintRoutes` 同一个思路 —— **显式声明，不做推断**。理由是这次正好踩到：medic / suicideTruck 的 `atk` 都大于 0，靠数值推断会画错，而后人看代码也猜不出"为什么这两条被排除"。

同时在 `game.gd` 的 `enemyInfo` 上方写一段注释说明 `showsRange` 的含义与那两个特例。

### 9.4 交互与视觉

- **触发**：点击敌人（复用已有的 `Game.enemyClicked` / 信息面板打开时机），只对 `showsRange` 为真的敌人生效。
- **取消**：点空白处 / 敌人死亡 / 逃脱 / 面板关闭 时一起收掉（与信息面板同一生命周期）。
- **画在哪**：**由 `map.gd` 的 `_draw()` 画**，与技能范围预览（`AbilityManager.isSelectingPosition()` 那个安全黄圆圈）**同一套做法** —— 不新增 UI 节点、不进 `Hud`、天然跟着相机与缩放。

  > ⚠️ 为什么不用 `Hud` 里的 `Control`：地图是会被相机推拉/缩放的 `Node2D`，`Control` 画在世界坐标外，得每帧自己换算屏幕位置；而 `map.gd` 本来就在 `_draw()` 里画技能圈，同源最省事也最不容易错位。

- **样式**（与 `art_style.md` 的语义色一致 —— 红=敌方）：

| 元素 | 颜色 | 说明 |
| --- | --- | --- |
| 范围外圈 | 锈红 `#C4553F`，alpha 0.9，宽 3 | 主体 |
| 范围填充 | 同色，alpha 0.10 | 让范围一眼看出是"面"不是"线" |
| 内圈刻度 | 同色虚线，4 段 | 与技能圈的实线区分开，避免误认成"我方技能" |

- **跟随**：画在敌人**当前世界坐标**上，敌人移动时圈跟着走（每帧 `queue_redraw()`，仅在选中且 `showsRange` 为真时）。
- **性能**：`queue_redraw()` 只在"有选中的攻击型敌人"期间调用；没有选中时一次都不重画（与技能圈的开关方式一致）。

### 9.5 集成点

| 位置 | 改动 |
| --- | --- |
| `autoload/game.gd` | `enemyInfo` 每条加 `"showsRange"` 字段 |
| `script/enemy/enemy.gd` | `setupEnemyInfo()` 读该字段存成 `@export showsRange: bool` |
| `script/map.gd` | 记录当前选中的敌人；`_draw()` 里多画一圈；选中/取消时 `queue_redraw()` |
| `lang/language.csv` | 无新增文案（纯图形） |

### 9.6 验证方式

- 逐条核对 `enemyInfo` 的 `showsRange` 与各敌人脚本的实际行为一致（**特别是 medic / suicideTruck 必须为 false**）。
- 运行时探针：选中每种敌人，断言"画圈的半径 == `enemyInfo.scope`"、"miniTank / scoutDrone / medic / suicideTruck 不画圈"。
- 视觉：`missileTruck`（scope 700）与 `mediumTank`（scope 240）同屏对比，确认半径差别明显、且圈不超出关卡边界时会被裁剪而不是画到屏幕外。

---

## 十、移动机甲 + 维修 / 回收（Mobile Mech）

### 10.1 模块定位

新增一座**能在屏幕上移动的机甲**。与所有现有防御塔的本质区别：**它不固定在格子上**。

职责三条：

1. **维修**防御塔（比塔自带的 `repairCost` 修理更省，见 10.5）
2. **回收**敌人残骸（§十一）
3. 自身**不攻击** —— 它是后勤单位，不是战斗单位

**限制：不能出现在敌人的路线上**（`Path2D` 所覆盖的格子）。这是它的核心约束，也是它与"再放一座塔"的区别：机动性换来的是"不能占路"。

### 10.2 与"塔"的关系：继承基类，但不受建造格限制

机甲**继承 `tower.gd`**（拿到血量 / 承伤 / 选中 / 详情面板 / 升级经验这一整套现成机制），但走**自己的放置通道**：

| 维度 | 普通防御塔 | 机甲 |
| --- | --- | --- |
| 放置位置 | 必须是 `placeableArea` 格 | **任意非路线格**（可跨可建造区） |
| 占用格子 | `addOccupiedArea()` 占住 | 占住当前格，**移动时释放旧格、占住新格** |
| 移动 | 不能 | 能（见 10.4） |
| 攻击 | 有 | **无**（`fire()` 不覆写，攻击逻辑不启用） |
| 承伤 | 敌人按 `targetValue` 选目标 | 同左（敌人会打它，这是它的风险） |

> ⚠️ **"任意非路线格"要靠格集合判定**：路线格集合来自各 `Path2D` 的 `Curve2D` 采样（`base_level.gd` 已有 `_collectRoutes()`）。机甲的目标格若落在路线格上，**拒绝移动并给一次红色提示**（与 `Game.towerLocked` 同款 toast）。

### 10.3 数据与文件

| 文件 | 内容 |
| --- | --- |
| `autoload/game.gd` | `enum towerType` 加 `mech = 1007`；`towerInfo` 加一条（见下表） |
| `script/tower/mech.gd` | 移动 + 自动作业状态机 |
| `script/tower/mech_repair_beam.gd` | 维修 / 回收激光的绘制与进度（也可并入 `mech.gd`） |
| `scene/tower/mech.tscn` | 机甲本体（`base` 车体 + `beamOrigin` Marker2D） |
| `sprite/tower/redesigned/mech_body.svg` | 美术素材 |
| `sprite/icon/unit/mech.png` | 塔卡片图标 |
| `lang/language.csv` | 塔名 / 描述 / 提示文案 |

**`towerInfo` 建议数值**（待平衡）：

```gdscript
towerType.mech: {
	"name": "_TowerName_mech",
	"atk": 0,          # 不攻击
	"cost": 60,
	"reload": 0.0,
	"scope": 0,        # 用 repairScope / salvageScope，见下
	"hp": 300,
	"maxHp": 300,
	"initTime": 1.2,
	"desc": "_mechDesc",
	"gridSize": Vector2i(1, 1)
}
```

专用参数（写在 `mech.gd` 的 `@export`，可在场景 Inspector 里调，符合 §6.3）：

| 参数 | 建议值 | 含义 |
| --- | --- | --- |
| `moveSpeed` | 220 px/s | 移动速度 |
| `repairScope` | 100 px | 维修激光射程（**检修半径**） |
| `salvageScope` | 140 px | 回收激光射程（比维修远，减少开上路线旁的压力） |
| `repairRate` | 25 HP/s | 维修速度 |
| `salvageSeconds` | 1.2 s | 回收一坨残骸所需时间 |
| `salvageRange` | 140 px | 同上（与 `salvageScope` 取其一，避免两个概念） |

### 10.4 移动

- **操作**：选中机甲 → 点地面目标格 → 机甲**自己开过去**（与"选塔 → 点格子"同一套操作，见 §八 v5.3 的塔选择交互）。
- **移动中**：直线朝目标格中心走，`moveSpeed` 匀速；到达后 `snapToCell()`（复用 `placeable_area.gd` 的思路）对齐格中心。
- **路径受阻**：机甲是移动单位，但**不做寻路**（本轮不做 A*）—— 只做"直线 + 撞到路线格就停并提示"。理由：可建造区之间本来就是连通的空地，绕路需求低；真需要绕的时候再加格子寻路（`Vector2i` 网格上的 BFS 很短）。
- **选择预览**：选中机甲后，把"可移动到的格"用**绿色半透明**标出、"路线格"用**红色**标出（复用 `placeable_area.gd` 的 `isShow` 高亮通道）。
- **移动中不能作业**：正在移动时中断维修/回收（避免"边走边吸"的怪异表现）；到达后重新索敌。

### 10.5 自动作业（范围型，不需要玩家逐个下令）

机甲的 `_physics_process` 里跑一个**简单状态机**，每 `0.5s` 重新索敌一次：

```text
IDLE ──(找到目标)──> WORKING ──(目标完成/失效)──> IDLE
  │                     │
  └──(玩家下令移动)──────┴──> MOVING ──(到达)──> IDLE
```

**索敌优先级**（同一帧只有一个目标，**谁近做谁**）：

1. **血量未满的防御塔**（`hp < maxHp`）→ 维修
2. **存活中的残骸**（§十一）→ 回收

> 为什么"维修优先"：塔被打爆是不可逆损失，残骸只是钱。玩家真想让机甲专注回收时，把残骸放在更近的位置即可（距离优先），不必再做一层手动优先级 UI。

**维修**：
- 锁定的塔进入 `repairScope` 后开始作业，`repairRate` 持续加血
- **收费**：按 §八 塔自带修理的比例口径（`REPAIR_COST_RATIO = 0.5`）× 恢复量**按秒结算**；钱不够则**中止**并给一次"金币不足"提示（复用 `_NotEnoughMoney`）
- 加满即完成，塔身上播 `playRepairGlow()`（复用现成特效）

**回收**：
- 锁定残骸进入 `salvageRange` 后开始作业，**持续 `salvageSeconds` 秒**
- 作业期间残骸头顶画一圈**进度环**，机甲到残骸之间拉一道**回收激光**（见 10.6）
- 完成后残骸销毁、入账 `scrapValue`（§十一）、飘字提示
- **残骸中途消失**（自然过期）→ 立刻切下一个目标

### 10.6 回收激光（为什么不需要"机甲走上路线"）

机甲**从当前位置发射一道激光**吸住残骸，全程不需要进入路线格。

- 光束：`Line2D`，从机甲 `beamOrigin` 连到残骸中心
- 配色：**电青 `#6FD6EA`**（与特斯拉 / 无人机的能量色一致，读作"我方作业"），芯部白、外晕青
- 进度：靠近残骸一端画一小段**递增的亮段**表示吸力进度（与 `air_route_hint` 的"逐段点亮"同一套读法）
- 束流期间的音效走 `SoundManage.playAt()`（**定位音效**，见 §八 2026-10-04「2D 听者」）

### 10.7 集成点

| 位置 | 改动 |
| --- | --- |
| `autoload/game.gd` | `towerType.mech`；`towerInfo` 一条 |
| `autoload/stageData.gd` | 机甲加入 `getTowers()` 的默认集合（全关卡可用，**教程关也可**） |
| `script/tower/tower_ui.gd` | `towersData` 加一条卡片（第 9 张） |
| `script/map.gd` | 放置通道放行机甲（跳过 `placeableArea` 检查，改为"非路线格"检查）；选中时高亮可移动区域 |
| `script/tower/tower_detail_panel.gd` | 机甲详情里显示"维修/回收"参数而非攻击力 |
| `scene/tower/mech.tscn` + 美术 | 新建 |
| `lang/language.csv` | 塔名 / 描述 / 「机甲不能开上敌人路线」「金币不足」 |

### 10.8 验证方式

- 路线格判定：断言机甲**无法**被放到任何一条路线覆盖的格子上（对 1~15 关 + 教程关 + 无尽逐关扫）。
- 移动：断言移动结束后位置落在目标格中心（误差 ≤1px）、移动中不占用旧格。
- 维修：造一座残血塔 → 断言机甲到位后 `hp` 按 `repairRate` 上升、金币按比例扣除、钱不够时中止。
- 回收：放一坨残骸 → 断言 `salvageSeconds` 后入账 `scrapValue`、残骸被销毁；中途让残骸过期 → 断言机甲切下一个目标、不卡死。
- 不攻击：断言机甲的 `atk == 0` 且不会产生任何子弹。

---

## 十一、敌人残骸与回收（Enemy Wreckage & Salvage）

### 11.1 模块定位

敌人被击杀后**在原地留下一坨残骸**，一段时间后自行消失；期间可以被维修机甲（§十）用激光回收，换回**该敌人原价 10%** 的金币。

设计目的：给"打完了就没了"的战斗补一层**战后清理**的小节奏，也让机甲有第二个存在理由。

### 11.2 数据

**谁掉残骸**：**地面单位全部掉**；**空中单位不掉**（`flying == true`）。

| 掉 | 不掉 |
| --- | --- |
| 迷你坦克 / 中型坦克 / 重型坦克 / 装甲坦克 / 突击车 / 维修车 / 自爆车 / 导弹车 / 实验坦克 | 侦察无人机 / 攻击直升机 / 战斗飞机 |

> 理由：空中单位被击落可以理解为"掉在场外"或"直接损毁"，而地面单位留下车体残骸符合直觉。这条规则也顺带避免了"飞机掉在航线正下方、机甲够得着但路线挡着"的尴尬。

**存活时长**按敌人档次走（价值越高留得越久）：

| 敌人 | `reward` | 残骸存活 | 回收价 = `reward × 10%` |
| --- | --- | --- | --- |
| 迷你坦克 | 5 | 8 s | **0**（见下） |
| 突击车 | 4 | 8 s | 0 |
| 自爆车 | 3 | 8 s | 0 |
| 小型（其余） | 6~12 | 10 s | 1 |
| 重型坦克 | 20 | 12 s | 2 |
| 装甲坦克 | 15 | 12 s | 2 |
| 实验坦克 | 40 | 16 s | 4 |

`scrapValue = floor(reward × 0.10)`，**至少 1**（否则 5 金币的迷你坦克算出 0，回收变成空操作）。也就是 `maxi(1, floor(reward * 0.10))`。

> ⚠️ 平衡提醒：第 1 关有 99 只迷你坦克，按"至少 1"算，全回收是 **+99 金币**（初始 150），接近一倍 —— 可能太强。建议先按"至少 1"实现，实测后再决定是否改成"不足 1 就不掉残骸"（即 `reward < 10` 的敌人不掉）。这个开关写成 `mech.gd` 里的一个常量方便调。

### 11.3 文件与结构

- `scene/fx/wreckage.tscn` + `script/fx/wreckage.gd`
  - 根 `Node2D`（或 `Area2D`，若将来要做"点击查看残骸价值"）
  - 子：`Sprite2D`（敌人 `base` 的贴图，**压暗 + 轻微随机倾斜**，读作"报废"）
  - 子：`Timer`（`one_shot`，存活时长）
  - 可选子：`CPUParticles2D` 小股烟（复用现有粒子资产）
- **不使用对象池**：与命中特效（`ExplosionManage` 池化）不同，残骸数量受"上一波敌人数量"限制且要挂计时器，池化收益低、状态复杂。等实测发现数量确实大（同屏上百）再考虑。

### 11.4 生命流程

```text
敌人死亡（enemy.gd 的 freeSelf() 之前，位置还有效）
   │
   ├─ flying == true        → 不掉，直接结束
   └─ flying == false       → 在敌人 global_position 生成 wreckage
                                 │
                                 ├─ 机甲回收（§十）→ 入账 scrapValue → 销毁 + 飘字
                                 └─ 存活时长到 → 淡出 → 销毁
```

**生成位置**：敌人**死亡瞬间的 `global_position`**（也就是"死在哪儿"），落在路线上是正常的 —— 回收靠激光，不需要机甲开上路线（§10.6）。

**关键实现点**：
- 必须在 `freeSelf()` **之前**取位置 —— 节点 `free()` 之后读成员会静默变 `null`（`code_design.md` §7.5 明确写着）。
- 生成发生在 `enemy.gd::hurt()` 的死亡分支里（与 `enemyDefeated` / 奖励同一个位置），**不要**放到 `_exit_tree()` —— 逃脱、场景卸载也会走 `_exit_tree()`，那会凭空产生残骸。
- **逃脱的敌人不留残骸**（没被摧毁，只是走出了屏幕）。

### 11.5 视觉

| 状态 | 表现 |
| --- | --- |
| 刚生成 | 残骸从 `scale 0.7` 弹到 `1.0`（0.15s），飘一小股烟 |
| 存活中 | 贴图压暗（`modulate` 灰）、随机 `±12°` 倾斜；剩余时间 < 25% 时开始**闪烁**（提示快没了） |
| 被回收中 | 头顶画进度环 + 与机甲之间的回收激光（§10.6） |
| 消失 | 淡出 0.3s 后 `queue_free()` |

配色遵循 `art_style.md`：残骸用**锈红/暗灰**系（敌方报废物），回收激光用电青（我方作业）。**不要把残骸画成亮的** —— 亮的会与敌人本体混淆。

### 11.6 与成就的联动（可选，本轮不做）

现有成就里 `legion_slayer`（3000 击杀）、`fortress_breaker`（30 辆实验坦克）都基于 `Game.enemyDefeated`，与残骸无关。若将来想做"回收大师"类成就，直接累加"回收次数"即可，不需要改本模块结构。

### 11.7 集成点

| 位置 | 改动 |
| --- | --- |
| `script/enemy/enemy.gd` | 死亡分支里按 `flying` 判定并生成残骸；`freeSelf()` 之前取位置 |
| `scene/fx/wreckage.tscn` + `script/fx/wreckage.gd` | 新建 |
| `script/tower/mech.gd` | 索敌时把残骸纳入目标（分组 `wreckage`） |
| `script/map.gd` | 残骸容器挂载点（与 `ExplosionManage` 同级，避免被关卡卸载带走） |
| `lang/language.csv` | 「回收 +N」飘字 |

### 11.8 验证方式

- 掉落规则：断言地面 9 种敌人**都**掉、空中 3 种**都不**掉；断言逃脱的敌人**不**留残骸。
- 位置：断言残骸坐标 == 敌人死亡坐标（误差 ≤1px）—— 这条能抓出"在 `free()` 之后取位置"的写法。
- 定价：断言 `scrapValue == maxi(1, floor(reward * 0.1))`，逐敌人核对表 11.2。
- 过期：断言存活时长到时残骸确实被销毁（不泄漏节点）。
- 回收：断言回收后金币恰好 +`scrapValue`、残骸被销毁、机甲回到 `IDLE`。

---

## 十二、击杀金币飘字（Kill Reward Floating Text）

### 12.1 模块定位

敌人被摧毁时，在**它倒下的位置**弹出一个 `+N` 的金币飘字，**向上飘一段后淡出**，让玩家立刻看到"这一下赚了多少"。

现状：击杀奖励是**静默进账**的 —— `enemy.gd` 发 `Game.enemyRewarded`，`map.gd` 转成顶栏 `money`，玩家只能看到顶栏数字跳一下，**根本不知道是哪只敌人给的、给了多少**。一波几十只的时候这个反馈缺口最明显。

### 12.2 ⚠️ 实现要点：`enemyRewarded` 信号不带位置

```gdscript
# autoload/game.gd:260
signal enemyRewarded        # ← 无参数！只有"发生了"这件事
```

而飘字需要**敌人倒下的世界坐标**。两种做法：

| 方案 | 做法 | 评价 |
| --- | --- | --- |
| A | 给信号加参数 `enemyRewarded(amount, pos)` | 要改信号签名 + 所有连接方，且 `map.gd` 已经有一处连接的写法要动 |
| **B（推荐）** | **在 `enemy.gd` 里直接调飘字的静态入口** | 敌人自己就有 `reward` 和 `global_position`，零信号改动 |

**采用 B**：`enemy.gd` 在死亡分支（与 `Game.enemyRewarded.emit()` 同一处）调 `RewardPopup.playAt(global_position, reward)`。

> ⚠️ **必须在 `freeSelf()` 之前调** —— `code_design.md` §7.5：节点 `free()` 之后读成员会静默变 `null`。这与 §十一 残骸的位置取值是同一个坑。

### 12.3 复用与新建

**不复用 `toast_label.tscn`**：它是**屏幕坐标**的提示（挂在 `Hud` 下的 `toastInfo`），`fixedOffsetY = 70` 是屏幕底部偏移；而飘字需要**世界坐标**跟随敌人倒下的位置（相机推拉时位置要对）。

新增：

| 文件 | 内容 |
| --- | --- |
| `scene/fx/reward_popup.tscn` | `Node2D` + `Label` |
| `script/fx/reward_popup.gd` | 池化 + `playAt(pos, amount)` 静态入口 |

**对象池**：与命中特效（`ExplosionManage`）**同一套做法** —— 一波几十只敌人会同时要飘字，每次 `instantiate()` 太浪费。池子常量与 `ExplosionManage` 对齐（`POOL_MAX` 建议 24）。

> 与 §十一 的残骸**故意相反**：残骸要挂计时器、数量受单波限制，所以不池化；飘字是"高频、短命、无状态"，正适合池化。

### 12.4 动画与视觉

| 阶段 | 时长 | 表现 |
| --- | --- | --- |
| 弹出 | 0.10 s | `scale 0.6 → 1.0`（`TRANS_BACK / EASE_OUT`，有一点回弹） |
| 上飘 | 0.55 s | `position.y -= 44`（`TRANS_QUAD / EASE_OUT`，先快后慢） |
| 淡出 | 0.25 s | `modulate.a → 0`，结束后回池 |

**样式**（遵循 `art_style.md` 的语义色 —— 金/黄 = 收益）：

- 文本：`+N`
- 颜色：`#FFC61A`（安全黄），带 1px 深色描边（`Label` 的 `theme_override_constants/outline_size = 4` + 深色 `font_outline_color`）—— 地图底色是深钢灰，没有描边的黄字在地板花纹上会糊掉
- 字号：40（与地图内 UI 字阶的"数值"档一致）
- `z_index` 高于敌人（敌人 `z_index = 2`，飘字取 20），确保压在敌人与特效之上

**随机抖动**：同帧多只敌人死亡时，起始位置各自加 `±14px` 随机偏移，避免叠成一坨看不清（这个方法在命中特效那边已经用过）。

### 12.5 集成点

| 位置 | 改动 |
| --- | --- |
| `scene/fx/reward_popup.tscn` + `script/fx/reward_popup.gd` | 新建（含池） |
| `script/enemy/enemy.gd` | 死亡分支、`freeSelf()` **之前**调 `RewardPopup.playAt()` |
| `script/map.gd` | 提供飘字节点的挂载点（与 `ExplosionManage` 同级，避免被关卡卸载带走） |
| `lang/language.csv` | `_RewardPopupFmt` = `"+%d"`（en/zh 相同，但按 §6.8 仍走 `tr()`） |

### 12.6 验证方式

- 断言飘字位置 == 敌人死亡坐标（误差 ≤1px）—— 这条能抓出"在 `free()` 之后取位置"的写法。
- 断言池子复用：连续击杀 30 只后，节点总数 **不超过 `POOL_MAX`**（不泄漏）。
- 断言文本 == `"+%d" % reward`，逐敌人核对（迷你坦克 `+5`、实验坦克 `+40`）。
- 视觉：一波 20 只同屏死亡时截图，确认飘字不重叠成糊字、且能被相机缩放正确跟随。

---

## 十三、波次来袭横幅（Wave Incoming Banner）

### 13.1 模块定位

**每一波开始时**弹一条横幅，告诉玩家这一波会来哪些敌人。

现状：新一波是**悄悄开始**的 —— `base_level.gd` 只发 `Game.dataRefreshed.emit({'wave': currWave})`，顶栏波次数字变一下，玩家往往在敌人已经上路后才发现。战斗飞机的空中航线还要靠单独的航线提示（§八 2026-10-04）来补，说明"提前告知"这件事本来就是刚需。

### 13.2 复用：横幅外观直接抄 `battle_start_banner`

`scene/battle_start_banner.tscn` 已经有现成的横幅结构，**直接复用它的层次与动画参数**：

```text
center (CenterContainer)
└── band (Control)
    ├── bg (ColorRect)
    ├── hazardTop / hazardBottom (危险条纹, scene/ui/hazard_strip.tscn)
    └── content/VBox
        ├── titleLabel   ← "第 3 波"
        └── subLabel     ← 敌人清单
```

- 动画参数照搬：`fadeInSec 0.26` / `holdSec 1.15` / `fadeOutSec 0.45` / `fromScale 0.86` / `outOffsetY -34`（`battle_start_banner.gd` 的 `@export`）
- 对外接口照搬：`play(title, sub, hold_override)` + `signal finished` + `skip()`

**新建 `scene/ui/wave_banner.tscn` + `script/ui/wave_banner.gd`**（而不是改造 `battle_start_banner`）：后者的 `play()` 签名与调用点（`map.gd::startGame`）已经稳定，改造它会牵动开场流程；新做一个只多一层"敌人清单"的组件，风险更低。

> 也可以更省：只加一个 `wave_banner.tscn`，脚本 `extends "res://script/ui/battle_start_banner.gd"`，只覆写"把清单排版进 `subLabel`"这一步。**这符合 `code_design.md` §6.2「先做基础场景 + 基础脚本，子类只覆盖差异」**。二选一，实现时看哪种更顺手。

### 13.3 横幅内容

**标题**：`tr("_WaveBannerFmt") % currWave` → "第 3 波" / "Wave 3"
**副标题**：本波**出现的敌人种类**，按"数量从多到少"排序，形如：

```text
迷你坦克 ×22  ·  中型坦克 ×5  ·  战斗飞机 ×3
```

数据来源：**`base_level.gd` 已经有现成的东西** —— `onWaveTimerTimeout()` 里 `currentSpawner.append_array(buildWaveSpawner(currWave))` 拿到的就是本波的 `{time, type, number, route?, offset?}` 记录数组（见 `stageData.gd:124` 的格式说明）。

**统计方法**（`_summarizeWave(rows) -> String`）：

```text
1. 按 type 聚合 number（同一兵种可能有多条记录 = 走了不同路线/偏移，要合并）
2. 按 number 降序排序
3. 每项显示 "tr(enemyInfo[type].name) ×N"
4. 用 " · " 连接
```

> ⚠️ 敌人名**必须走 `tr()`**：`Game.enemyInfo[x].name` 现在存的就是**翻译键**（如 `"_EnemyName_miniTank"`，见 §八 v5.4）。

**特殊文案**：
- 最后一波：标题改成 `tr("_FinalWave")` → "最后一波" / "Final Wave"（与 `_LvWaves` 那套键的命名对齐）
- 无尽模式：波次没有上限，标题用 `_WaveBannerFmt` 照常显示 `currWave`

### 13.4 触发时机与不打断

- **触发点**：`map.gd` 里接 `Game.dataRefreshed`（`base_level.gd:221` 发的那个），当 payload 带 `'wave'` 时弹横幅。

  > 为什么不用新信号：`dataRefreshed.emit({'wave': currWave})` 这一句**正好在 `buildWaveSpawner()` 之前**（`base_level.gd:220-224`），但那时 `currentSpawner` 还没填 —— 所以 `map.gd` 拿到 `currWave` 后要**自己调 `level.buildWaveSpawner(wave)`** 取编制。该方法本来就是公开的，不会重复生成敌人（`buildWaveSpawner` 只读数据、返回新数组）。

- **不打断游戏**：横幅是 `CanvasLayer` 上的覆盖层，**不暂停**、不拦输入（`mouse_filter = IGNORE`），与 `battle_start_banner` 同一层级（`PopupLayer`，`layer = 10`）。
- **与开场横幅不冲突**：`startGame()` 里 `await battleStartBanner.play()` 是**开打前**；第 1 波的横幅在**开打后**第一波计时器触发时才弹，两者天然错开。
- **与航线提示不冲突**：航线提示（`air_route_hint`）画在**地图世界层**（`z_index = -1`），横幅在 **HUD 层**，互不遮挡。
- **跳过**：连点屏幕可以提前收掉（复用 `skip()`）。

### 13.5 集成点

| 位置 | 改动 |
| --- | --- |
| `scene/ui/wave_banner.tscn` + `script/ui/wave_banner.gd` | 新建（外观与动画参数抄 `battle_start_banner`） |
| `script/map.gd` | 接 `Game.dataRefreshed`；`_showWaveBanner(wave)` 取编制 → 汇总 → 弹横幅 |
| `script/level/base_level.gd` | **无需改动**（`buildWaveSpawner()` 已经是公开接口） |
| `scene/map.tscn` | 横幅挂到 `PopupLayer` 下 |
| `lang/language.csv` | `_WaveBannerFmt` / `_FinalWave` / `_WaveEnemiesFmt`（分隔符格式） |

### 13.6 验证方式

- 断言汇总结果与实际编制一致：对 1~15 关逐波跑 `buildWaveSpawner(n)` → 断言"横幅里每个兵种 ×数量"之和 == 该波敌人总数、且**兵种集合完全相同**（这条能抓出"漏合并同兵种多条记录"的 bug）。
- 断言 `tr()` 生效：切英文后横幅显示 `Mini Tank` 而不是 `_EnemyName_miniTank`。
- 断言第一波横幅在 `battleStartBanner` 播完之后才出现（两者不叠在一起）。
- 断言横幅**不影响战斗**：弹出期间敌人照常移动、塔照常开火、鼠标点击仍能落到底下的地图（`mouse_filter = IGNORE`）。
- 无尽模式：连跑 30 波不报错、波次号正确递增。

---

## 十四、五个新模块的总览与依赖

| 模块 | 章节 | 依赖 | 建议顺序 |
| --- | --- | --- | --- |
| 敌人攻击范围显示 | §九 | 只读 `Game.enemyInfo` | **1**（改动最小） |
| 击杀金币飘字 | §十二 | 无（只读敌人的 `reward`） | **2**（独立、见效快） |
| 波次来袭横幅 | §十三 | 读 `base_level.buildWaveSpawner()` | **3**（独立） |
| 敌人残骸与回收 | §十一 | 无（独立产生） | **4** |
| 移动机甲 | §十 | **依赖 §十一** 的残骸 | **5**（最复杂，放最后） |

```text
§九  敌人攻击范围     独立
§十二 击杀金币飘字    独立
§十三 波次横幅        独立（复用 battle_start_banner 的外观）
§十一 敌人残骸        独立产生 ──┐
                                ▼
§十  移动机甲         依赖残骸 + 防御塔
```

**前三个（§九 / §十二 / §十三）互相独立、都不改战斗逻辑**，可以一次做完一起验；后两个（§十一 / §十）需要配套，按顺序做。

---

## 十五、后续可扩展模块（v2.x 待办）

> **状态更新（2026-10-23）**：本节原列 5 项，其中**无尽模式已完成**（见 `endless_mode_design.md` v1.3，M1~M5 全部落地）。
> 其余 4 项仍未开工。新的完整优先级排序、投入量与验收标准见 **[roadmap.md](roadmap.md)**，
> 本节只保留与本文档其它模块有直接依赖关系的条目。

### 15.1 仍未开工的存量项

1. **每日任务系统**：参考成就系统结构（`achievement_manager.gd` 的 `ACHIEVEMENTS` 定义表 + `achievement_tracker.gd` 的进度累加写法），每日刷新任务，完成奖励钻石/物品。
2. **关卡星级与奖励**：✅ **宝石部分已完成**（2026-10-23）—— 见 §八 同日条目，按最高星级的提升发差额。
   **仍待接**：用星级解锁该关的无尽入口（目前无尽模式是全局可选，不按关卡解锁）。
3. **装备系统**：为塔添加可装备的强化道具，与背包系统共用 `ItemData` 结构。
4. **存档系统统一化**：将 `userData`、`backpack`、`achievement_manager` 的存档逻辑统一到一个 `SaveManager` 单例。

### 15.2 已完成（从本节移出）

- ~~**无尽模式**~~ → ✅ **已实现**（v1.3）。独立关卡场景 `scene/level/endless.tscn` + `script/level/endless_level.gd` 复用 `map.tscn` 外壳；
  地图双传送带并排 U 形，同屏上限 90、基地血量 10、每 10 波奖励宝石。见 `endless_mode_design.md`。

### 15.3 v2.x 新增候选

详细论证与排期见 [roadmap.md](roadmap.md)，此处只列名目，避免两份文档各写一套：

| 候选 | 一句话 |
|---|---|
| 倍速档位 | ✅ **1X/2X 已实现**（见 §十六）；后续可扩 3X |
| 状态效果系统 | 用"状态列表"替掉 EMP 直接改 `enemy.speed` 的写法，顺带修多座 EMP 重叠时的速度漂移 |
| 塔联携 / 元素反应 | 依赖状态系统；不改美术，只改伤害计算 |
| Boss 波 | 每 4~5 波一个带专属机制的强敌 + 独立血条 |
| 关卡特殊规则（mutator） | 复用现有地图，只改规则（浓雾 / 蜂群 / 无射程提示） |
| 每日挑战 | 固定种子 + 固定敌人构成 |

---

## 十六、1X / 2X 倍速（Game Speed）

> **实现状态：✅ 已实现**（2026-10-23）。需求：**正常速度与 2 倍速两档**。

### 16.1 背景

这是一次**"把已有半成品接通"**的修复，不是从零新增。代码里早就躺着三样东西，但三处都没接上：

| 位置 | 原状态 |
|---|---|
| `scene/title.tscn` 的 `btnFast` | `visible = false`，且类型是 **`PanelContainer`**（不是按钮，没有 `toggled` 信号，点不了） |
| `script/menu/title.gd` | `onBtnSpeedToggled()` 已写好，但**没有任何信号连到它** |
| `script/map.gd` | `speedOnPressed` / `speedOffPressed` 的连接**被注释掉**，两个处理函数是空的 `pass` |

### 16.2 设计决定

- **两档而非多档**：需求明确只要 1X / 2X，多档会让顶栏按钮变成需要循环切换的设计，收益不大。
- **用 `Engine.time_scale`，不改各自的 delta**：`delta` 已被引擎按 `time_scale` 缩放，所以敌人的 `speed * delta`、
  `Timer` 节点（射速、波次、冷却）都会自动变快，**不需要改任何一处游戏逻辑**。
- **按钮状态必须肉眼可见**：70px 的小方块里只换 "1X"/"2X" 两个字符不显眼，所以加速时额外把按钮染成安全黄
  （`#FFC61A`，与 `art_style.md` 的强调色一致）。

### 16.3 关键约束：`time_scale` 是全局状态

`Engine.time_scale` **不是场景局部变量**，漏出去会带到关卡选择、主菜单甚至下一局。因此复位点必须覆盖所有出口：

| 复位点 | 覆盖的出口 |
|---|---|
| `map.gd::_exit_tree()` | 所有离开关卡的方式（回主菜单 / 下一关 / 重开 / 切场景）——这一层是兜底 |
| `map.gd::finish()` | 结算开始就退回 1X，否则结算界面、宝石飘字、成就弹窗会以 2 倍速一闪而过 |
| `map.gd::nextLevel()` / `returnHome()` | 场景淡入淡出本身也吃 `time_scale`，切场前先退回 |

统一走 `resetGameSpeed()`（同时把按钮外观掰回 1X），**不在各按钮回调里各写一遍**，避免以后新增出口时漏掉。

### 16.4 已知取舍：真实时间 vs 游戏时间

有两处计时用 `Time.get_ticks_msec()`（**真实时间，不受 `time_scale` 影响**），开 2 倍速时会出现相对偏差：

- `endless_level.gd::elapsedSeconds()` —— 无尽模式结算的"用时"是真实时间。2 倍速玩 10 分钟，显示"用时 10 分钟"，但游戏内实际跑了 20 分钟。
- `map.gd` 的机甲建造冷却（`mechLastBuiltMsec`，3 秒）—— 2 倍速下相当于游戏内 6 秒，即**加速时能相对更频繁地造机甲**。

两者都不影响正常游玩；若以后要做无尽排行榜，需要统一成"游戏内时长"。

### 16.5 验证

走**真实点击路径**（`button_pressed = true/false`，而非直接调处理函数）验证，因此同时证明了 `toggled` 连接确实存在：

```
按钮:  visible=true  toggle_mode=true  text=1X  rect=(1600,10) 70x78
起始:  time_scale = 1.00   text = 1X
按下:  time_scale = 2.00   text = 2X   modulate = 金色
弹起:  time_scale = 1.00   text = 1X   modulate = 白色
复位:  time_scale = 1.00   text = 1X
```

`run_in_project -Scene scene/map` → `run exit: 0`，无 SCRIPT ERROR。

---

> **以下 §十七 ~ §十九 均为设计稿，尚未实现**（2026-10-24）。
> 实现后请把各节的「实现状态」改成 ✅，并在 §八 补一条实施记录（含踩到的坑）。
> 三节的共同前提：遵守 `code_design.md` §7.6 —— 任何改到全局状态（`Engine.time_scale`、`Game.xxx` 缩放）的，
> 都必须在 `_exit_tree()` + 每条显式退出路径上复位。

---

## 十七、战斗模式（Battle Mode / Mutator）

> **实现状态：✅ 已实现**（2026-10-24）
> 需求原话：「在点击开始游戏的时候可以选择游戏模式，正常和蜂群或者还有其他的，
> 选了蜂群后敌人数 ×2，血量 −50%，这种的模式」
>
> **实现与设计稿的三点差异**（实现时按现实调整；下面 17.1~17.9 保留设计原样）：
> 1. **挑战模式的宝石改用 `challengeCleared` 记账**，不再靠 `stageRatings`。
>    因为挑战模式按设计不写星级，"是否首通"就无法再用星级表判断 ——
>    否则每打一次都会被当成首通，宝石可以无限刷。
>    存档新增 `[player] challengeCleared`（形如 `"swarm:3"`）。
> 2. **情报面板的数值也必须乘模式倍数**。设计稿只提到 `buildWaveSpawner` 与 `enemy.gd`，
>    但 `level_intro_panel` 是**直接读 `StageData` 原始值**的 —— 不改的话蜂群模式下
>    面板显示"x94、血量 150"，实际刷的是"x188、血量 75"，等于在骗玩家。
>    现在 `collectEnemyStats()` / `buildEnemyList()` 都按同一套算法
>    （逐条 `maxi(1, ceil(n × scale))`）换算。
> 3. **挑战模式下隐藏「3★ 额外宝石」格与星级规则说明**，并把「宝石奖励」显示成
>    实际会发的 `ceil(base × gemScale)` —— 挑战模式不记星级，摆着这两项会误导。

### 17.1 目标

同一张关卡，换一套**规则**重打。不新增地图、不改路线、不新增关卡场景 ——
纯靠倍数把既有内容重新组合，用最低成本换重玩价值。

### 17.2 非目标

- **不做**随机词条（那是无尽模式的后续玩法，和"玩家主动选模式"是两件事）
- **不做**新模式专属美术
- **不动** `StageData.allStage` 里既有的波次编排（只做倍数，不改兵种构成）

### 17.3 数据结构

模式表放 `autoload/game.gd`（沿用"数据与逻辑分离"，**不新增 autoload** —— 已经 10 个了）：

```gdscript
## 当前战斗模式 id。离开关卡必须复位成 "normal"（见 code_design.md §7.6）
var battleMode: String = "normal"

const battleModeDefs = {
	"normal": {
		"name": "_Mode_normal", "desc": "_Mode_normal_desc",
		"countScale": 1.0, "hpScale": 1.0, "atkScale": 1.0, "speedScale": 1.0,
		"rewardScale": 1.0, "expScale": 1.0, "gemScale": 1.0,
		"recordsProgress": true,
	},
	"swarm": {
		"name": "_Mode_swarm", "desc": "_Mode_swarm_desc",
		"countScale": 2.0,   # 敌人数 ×2
		"hpScale": 0.5,      # 血量 −50%
		"atkScale": 0.8,
		"speedScale": 1.2,   # 移动速度 +20%（⚠️ 不是出怪间隔！见 17.4 的说明）
		"rewardScale": 0.5,  # 每杀金币 ×0.5（见 17.5 收益守恒）
		"expScale": 0.5,     # 塔经验 ×0.5（同上）
		"gemScale": 1.3,
		"recordsProgress": false,
	},
	# …铁流 / 精锐 见 17.4
}
```

> ⚠️ **战斗模式禁止修改出怪间隔。**
> 早先实现过 `delayScale`（蜂群把间隔减半），实测**后一个敌人会追上前一个、在路径上叠成一团**，
> 看起来像一坨、也分不清谁是谁。现在只保留 `speedScale`（改敌人在射程里待多久），
> `base_level.gd::nextSpawnDelay()` 里**不再读任何模式倍率**（只保留无尽模式自己的 `spawnDelayScale`）。

### 17.4 模式表

| 模式 | 敌人数 | 血量 | 攻击 | 移动速度 | 每杀金币 | 塔经验 | 首通宝石 | 记录星级/成就 |
|---|---|---|---|---|---|---|---|---|
| **正常** `normal` | ×1 | ×1 | ×1 | ×1 | ×1 | ×1 | ×1 | ✅ |
| **蜂群** `swarm` | **×2** | **×0.5** | ×0.8 | **×1.2** | ×0.5 | ×0.5 | ×1.3 | ❌ |
| **铁流** `armor` | ×1 | ×2.0 | ×1.0 | ×1.0 | ×2.0 | ×2.0 | ×1.4 | ❌ |
| **精锐** `elite` | ×1 | ×1.3 | ×1.5 | ×1.1 | ×1.3 | ×1.3 | ×1.5 | ❌ |

三种挑战模式的定位差异：

- **蜂群**：总量不变（×2 数量 ×0.5 血量 = 总血量一样），但**个体变脆、密度翻倍** ——
  考验溅射/攻速，单体高伤塔反而吃亏。
- **铁流**：数量不变、单个硬一倍 —— 考验破甲与持续输出。
- **精锐**：数量不变、血略高、**攻击 ×1.5** —— 考验塔的血量管理（对抗型敌人会真的拆掉你的塔）。

### 17.5 关键：收益必须守恒（否则蜂群是白送的强化）

**这是本节最重要的一条。** 蜂群把击杀数翻倍，而 `enemyInfo` 里每条都有
`reward`（金币）与 `rewardExp`（塔经验）。如果照原样发放：

- 同一关的金币收入 **×2**
- 塔的升级速度 **×2**（塔靠击杀升级，见 §六）
- 成就 `legion_slayer`（累计 3000 杀）被加速刷满

结果「困难模式」反而成了**更容易**的模式。

所以 `rewardScale` / `expScale` 必须与 `countScale` 成反比，保证"每关总收益 ≈ 不变"。
挑战模式的额外回报改由 `gemScale`（首次通关宝石）体现 —— 一次性的、无法刷。

### 17.6 集成点

| 位置 | 改动 |
|---|---|
| `script/menu/level_select.gd` | 顶部加一条模式切换条；`loadMap()` 里写 `Game.battleMode = 选中模式` |
| `script/panel/level_intro_panel.gd` | 加一格显示当前模式；挑战模式用警示色（锈红）而不是青色 |
| `script/map.gd::loadLevel()` | 进入时把模式倍数写进 `Game.modeHpScale / modeAtkScale`；`_exit_tree()` 复位模式与倍数 |
| `script/level/base_level.gd::buildWaveSpawner()` | 对返回的每条记录 `number = maxi(1, ceil(number * countScale))` |
| `script/level/base_level.gd::nextSpawnDelay()` | **不改**（战斗模式不许动出怪间隔） |
| `script/enemy/enemy.gd::setupEnemyInfo()` | `hp *= Game.enemyScale * Game.modeHpScale`；`atk` 同理；**`speed *= Game.modeSpeedScale`（必须在记 `baseSpeed` 之前）**；`reward`/`rewardExp` 乘 `modeRewardScale`/`modeExpScale` |
| `autoload/userData.gd::recordStageCompletion()` | `recordsProgress == false` 时**不写 `stageRatings`**、不发星级奖励；首通宝石乘 `gemScale`。⚠️ 需要新增"当前模式"参数或直接读 `Game`（推荐传参，数据层不依赖全局） |
| `script/panel/achievement_tracker.gd` | 挑战模式不累加进度（与上一条同一判据） |

### 17.7 边界与坑

1. **绝对不要复用 `Game.enemyScale` 来实现模式血量。** 那个变量已经被无尽模式占用
   （`endless_level.gd:291` 每波重写），两边会互相覆盖。必须新增独立的
   `Game.modeHpScale` / `modeAtkScale`，在 `enemy.gd` 里**相乘**。
2. `currentSpawner` 里的记录是 `buildWaveSpawner()` 返回的 **`duplicate()` 副本**，
   改它的 `number` 不会污染 `StageData`。反之，若直接改 `enemyList` 就永久坏了。
3. **出怪间隔绝对不能被模式改（这条是实测踩出来的）。**
   曾经用 `delayScale: 0.5` 让蜂群"出怪翻倍"—— 结果是**后一个敌人会追上前一个、
   在路径上叠成一团**，看起来像一坨、也分不清谁是谁。
   间隔是"空间节奏"，一缩就必然重叠；要调节奏只能改**移动速度**（`speedScale`），
   它只影响敌人在射程里待多久，不会让它们挤在一起。
   `nextSpawnDelay()` 里因此**不再读任何模式倍率**。
4. 结算 `finish()` 的条件是"生产队列空 + 场上无敌人"，翻倍只影响时长、不影响逻辑 —— 但
   注意别把 `countScale` 应用两次（`buildWaveSpawner` 一次 + `onSpawnerTimerTimeout` 再一次）。
5. **挑战模式不记录星级**，因此也不触发 §十六 的星级奖励；它的额外回报走 `gemScale`。
   这条要写进 UI 文案，否则玩家会以为"我打了困难却没涨星"是 bug。
6. 顶栏要有**常驻**的模式标识，否则玩家分不清当前是哪个模式。
   ✅ 已实现：关卡名右边一块锈红**模式徽章**（正常模式不显示），带悬停说明；
   进场介绍面板另有一条整宽**挑战模式横幅**。详见 §八 2026-10-25 条。

### 17.8 分阶段

| 阶段 | 内容 | 可独立验证 |
|---|---|---|
| M1 | 模式表 + `Game.battleMode` + 倍数接线（先只做 normal / swarm） | 是（探针直接改 `Game.battleMode`） |
| M2 | 关卡选择 UI + 情报面板显示模式 | 是（截图） |
| M3 | 铁流 / 精锐 + 记录隔离（星级、成就） | 是 |
| M4 | 后续：自定义倍率 / 每日挑战 | — |

### 17.9 验收探针

- 同一关分别用 normal / swarm 跑，断言：敌人总数 **×2**、单只 hp **×0.5**、
  每杀金币 **×0.5**、塔经验 **×0.5**、移动速度 **×1.2**
- **四种模式的 `nextSpawnDelay()` 必须完全相等**（战斗模式不许动出怪间隔）
- EMP 减速要作用在"模式加成后的原速"上，解除后回到 60 而不是 50
- 挑战模式通关后 `UserData.getStageRating(stageId)` **不变**
- 挑战模式通关发的宝石 = `gemReward * gemScale`
- 退出关卡后 `Game.battleMode == "normal"`、`modeHpScale == 1.0`

---

## 十八、防御塔主动技能（Tower Active Skill）

> **实现状态：✅ 已实现**（2026-10-24）
> 需求原话（第一版）：「每个塔有个主动技能，机枪塔为过热扫射 3 秒，伤害增加但是为持续掉血，其他塔也都有相应的技能」
>
> **实现与设计稿的偏差**（实现时按代码现状调整，17.x/18.x 正文保留设计原样）：
> 1. **激光塔单体伤害 ×2.5 → ×2.2**。×2.5 在 Lv3 会到 `44×2.5 = 110`，破了项目
>    "atk 必须 < 100" 的数值规范（见 `game.gd` 的数值说明）。×2.2 得到 Lv1 84 / Lv3 97。
> 2. **加农炮"破甲弹"走 `damageType = "energy"`**。`enemy.gd::hurt()` 本来就有 energy 通道
>    （无视 armor），所以不用新做护甲系统，子弹加一个 `damageType` 字段即可。
> 3. **无人机基地的技能改成"伤害 ×1.5"**（原设计是射速 ×1.5）。`drone_base.gd` 没有自己的
>    开火计时器（开火在 `drone.gd` 里各机独立），改伤害只需让 `drone.gd` 读
>    `homeBase.effectiveAtk()`，比改射速干净得多。
> 4. **铁箱塔只做减伤**，没有"期间不能攻击"的代价 —— 铁箱本来就不攻击。
> 5. **技能按钮单独一行**（用户明确要求），用 `SkillRow` 承载，不和修理/出售挤在一起。
> 6. **面板显示派生值**：攻击 / 射速 / 范围读取 `effectiveAtk / effectiveDelay / effectiveScope`，
>    否则玩家切到"单体打击"看到攻击力没变，会以为技能没生效。
>
> **需求修订（2026-10-24，v1.1）**——
> 「1. 技能可以是一个功能切换，比如火箭塔切换成远距离导弹，但是没有爆炸范围效果了，技能切换 cd 3s；
> 2. 激光塔可切换成单个打击，只锁定一个敌人，伤害增加，技能切换 cd 3s；
> 3. 移动机甲改为立刻修复自身与范围内塔 30%，之后无法使用 5s」
>
> 也就是把技能从"只有限时大招"扩成**两种形态**：`toggle`（功能切换，3 秒切换 CD）
> 与 `instant`（瞬发）。下文 18.1~18.3、18.5~18.8 已按 v1.1 重写；
> 18.4 的技能表也换成了新数值（含从代码里对出来的当前值）。

### 18.1 设计原则：技能自带代价，并且分三种形态

**不设金钱 / 宝石消耗。** 钱是建塔的资源、宝石是全局技能（`bombard` / `invincible`）的资源，
再让塔技能吃钱会挤压核心循环。改用**副作用**平衡，让"什么时候开/切"成为决策。

技能分三种形态（`kind` 字段）：

| kind | 含义 | 冷却口径 | 用在哪 |
|---|---|---|---|
| **`toggle`** | **功能切换**：按下切到"另一种工作模式"，再按切回来（不是限时 buff） | **切换 CD 3 秒**（只为防连点抖，不是"一局只能用几次"） | 火箭塔（远距离导弹）、激光塔（单体打击） |
| `timed` | 限时增益：开 3~5 秒然后自动结束 | 长冷却 18~25 秒 | 机枪塔、加农炮、EMP、特斯拉、无人机基地、铁箱塔 |
| `instant` | 瞬发：点一下立刻生效 | 短冷却；**也可以换成"停止"**（单位整体失效一段时间） | 移动机甲（紧急维修 + **停止 3 秒**） |

> **`toggle` 是这次改动的重点**：技能不再只有"开一个大招"，
> 也可以是一个**持续的工作模式**——火箭塔切成远距离导弹、激光塔切成单体，切过去就一直保持，
> 想回原样再按一次。切换 CD 只有 3 秒，所以玩家可以按战况来回切（比如来一群小兵切回溅射）。

### 18.2 数据结构

挂在 `Game.towerInfo[type]["skill"]` 下（沿用既有数据表，不在 `tower.gd` 里硬编码）：

```gdscript
# ── timed（限时增益）示例：机枪塔 ──
"skill": {
	"kind": "timed",
	"name": "_Skill_overheat",
	"desc": "_Skill_overheat_desc",
	"duration": 3.0,
	"cooldown": 18.0,
	"atkMul": 2.0,          # 技能期间攻击力倍率
	"delayMul": 0.5,        # 技能期间开火间隔倍率（<1 = 更快）
	"selfHpPerSec": 6.0,    # 技能期间每秒自损
	"minHpRatio": 0.25,     # 血量低于此比例时拒绝触发
}

# ── toggle（功能切换）示例：火箭塔 ──
"skill": {
	"kind": "toggle",
	"name": "_Skill_missile",
	"desc": "_Skill_missile_desc",
	"switchCooldown": 3.0,  # 切换 CD（只防连点，不影响强度）
	# 切到"导弹模式"后覆盖的字段；没写的沿用基础值
	"sightBonus": 1.6,      # 射程 ×1.6  → 200 → 320
	"atkMul": 1.25,         # 伤害 ×1.25 → 40 → 50
	"splash": false,        # ⚠️ 关掉爆炸范围（这条是本技能的核心代价）
	"bulletSpeed": 520.0,   # 弹速 300 → 520
	"turnSpeed": 6.5,       # 转向角速度 5.0 → 6.5（速度变快，转向要跟上）
}

# ── instant（瞬发）示例：移动机甲 ──
"skill": {
	"kind": "instant",
	"name": "_Skill_emergency_repair",
	"desc": "_Skill_emergency_repair_desc",
	"healRatio": 0.30,      # 立刻治疗 30% 最大血量（自身 + 范围内所有塔）
	"healScope": 180.0,     # 范围 = 机甲现有的 radarScope（维修半径）
	"shutdown": 3.0,        # ⚠️ 用完之后整个机甲停止 3 秒：不能移动 / 维修 / 回收
}
```

> **`shutdown` 不是冷却。** 这两个概念要分开：
> - **冷却（cooldown）**：只是"这个技能暂时不能再按"，单位本身照常工作。
> - **停止（shutdown）**：**单位整个失效** —— 机甲这 3 秒不能移动、不发维修脉冲、不能回收残骸。
>
> 机甲用的是**停止**。它是这台机甲的"代价"，不是按钮的节流。
> 实现上必须由 `mech.gd::_physics_process` 统一挡住，而不是只在按钮回调里判断。

特殊效果（无视护甲 / 额外弹道 / 链式目标）另加布尔或整数字段，由**各塔子类**在
`fire()` 里读，不在基类里塞一堆 if。


### 18.3 `tower.gd` 新增

| 成员 / 函数 | 作用 |
|---|---|
| `skillActiveLeft: float` | `timed`：剩余秒数（>0 表示生效中） |
| `skillCooldownLeft: float` | 冷却剩余秒数（`toggle` 用的是切换 CD） |
| `skillDisabledLeft: float` | **停止剩余秒数**（>0 表示整个单位失效）。与冷却**不是一回事**，见 18.2 的说明 |
| `skillOn: bool` | `toggle`：当前是否处于"第二种模式"。**它才是持续状态**，不靠 `skillActiveLeft` |
| `canUseSkill() -> bool` | 有技能 + 不在冷却 + **不在停止** + 血量够 + （`timed` 时）未在技能中 |
| `activateSkill() -> bool` | `timed` / `instant` 的触发入口；返回是否成功（失败要给 UI 反馈） |
| `toggleSkill() -> bool` | `toggle` 的入口：翻转 `skillOn` + 开始 3 秒切换 CD |
| `endSkill()` | 结束 `timed` 技能、开始冷却、恢复系数 |
| `isDisabled() -> bool` | `skillDisabledLeft > 0.0`。**子类必须先问这个再干活**（见下） |
| `skillAtkMul() -> float` | `toggle` 且 `skillOn` 时返回 `atkMul`，否则 `atk` 的倍率（默认 1） |
| `effectiveAtk() -> int` | `atk × skillAtkMul()` —— **所有子类的 `fire()` 都改用它** |
| `effectiveDelay() -> float` | `delay × skillDelayMul` |
| `applyFireRate()` | **唯一**写 `delayTimer.wait_time` 的地方 |

⚠️ **停止不是"冷却的一种"，必须在子类的行为入口挡住。**
拿机甲举例：它有三个独立行为（移动 / 维修脉冲 / 回收），如果只在技能按钮的
`canUseSkill()` 里判断 `skillDisabledLeft`，那只是"按钮变灰"，
机甲照样会走路、修塔、捡残骸 —— 等于这个代价不存在。
正确做法是在 `mech.gd::_physics_process` 的**最前面**加一个总闸：

```gdscript
func _physics_process(delta: float) -> void:
	super._physics_process(delta)        # 雷达扫描/重绘仍要跑，否则选中圈会停
	if isDisabled():
		skillDisabledLeft -= delta       # 由基类推进，或这里推进
		stopAllWork()                    # 见 18.6 第 6 条
		return
	# …原有的移动 / 维修 / 回收
```

同理，`fire()` 里也要挡（防止停止瞬间已经排进队列的一发打出去）。

⚠️ **最大的坑：`delayTimer.wait_time` 有 2 处写，`delayTimer.start()` 有 6 处调。**
（写：`tower.gd:103` 的 `_ready()`、`tower.gd:193` 的 `levelUp()`；
调 `start()`：cannon / laser / machineGun / mech / rocket / tesla 各一处。）
`start()` 用的是**当前** `wait_time`，本身不写它 —— 所以只在 `fire()` 里"改射速"是无效的，
而且 `levelUp()` 会直接把 `wait_time` 重置回 `delay`。技能要改射速，**必须**走进同一个入口。

⚠️ **`toggle` 模式下的射程/弹速不是"缓存一次就完"**：
`radarScope` 还写在 `raderShape.shape.radius` 里（`_ready()` 与 `levelUp()` 各写一次），
切模式时必须**同时**改 `radarScope` 和碰撞体半径，否则圈画得远了、雷达却还只探 200px。
建议加 `applySight()` 作为唯一入口，和 `applyFireRate()` 同一套路。


### 18.4 各塔技能表

> 数值都以**当前代码里的实际值**为基准（`Game.towerInfo` + 各塔脚本里的常量），
> 括号里标的是"从多少改到多少"，方便实现后对账。

| 塔 | 类型 | 技能 | 效果 | 代价 / 切换条件 |
|---|---|---|---|---|
| 机枪塔 | timed | **过热扫射** | 3s 内 atk×2、射速×2（DPS≈4×） | 每秒自损 6（共 18HP）；CD 18s |
| 加农炮 | timed | 破甲弹 | 3s 内无视护甲 | 射速 ×0.7；CD 20s |
| **火箭塔** | **toggle** | **远距离导弹** | 射程 **200 → 320**（×1.6）、伤害 **40 → 50**（×1.25）、弹速 **300 → 520**、转向角速度 **5.0 → 6.5** | **失去爆炸范围**：`blastRadius 90` → 单体直击。**切换 CD 3s** |
| EMP | timed | 强磁过载 | 5s 内减速倍率翻倍 | 结束后停转 3s；CD 25s |
| **激光塔** | **toggle** | **单体打击** | 锁定目标 **3 → 1**（`MAX_TARGETS`）、对单伤害 **38 → 95**（×2.5） | 失去多目标：满编 3 目标总 DPS 由 114 降到 95。**切换 CD 3s** |
| 特斯拉 | timed | 链式放电 | 3s 内电弧多跳 2 个目标 | 每秒自损 5；CD 20s |
| 无人机基地 | timed | 紧急升空 | 4s 内射速 ×1.5 | 期间不可选中/出售；CD 24s |
| 铁箱塔 | timed | 应急装甲 | 4s 内受伤 −70% | 期间不能攻击；CD 20s |
| **移动机甲** | **instant** | **紧急维修** | 立刻治疗**自身 + 半径 180 内所有塔**，各 **30% 自身最大血量** | 用完后**整个机甲停止 3 秒**：不能移动、不能维修、不能回收残骸 |

**三条需要特别说明的：**

1. **火箭塔的导弹模式不是纯加强，是取舍。**
   射程 +60%、弹速 +73% 让它能打到以前够不着的远程敌人，但**没有爆炸范围**意味着
   对成群的推进型（蜂群模式下尤其明显）反而更弱。玩家应该"看情况切"，而不是一直开着。

2. **激光塔的单体伤害为什么是 ×2.5 而不是 ×3。**
   满编 3 目标时总 DPS 是 `38×3 = 114`；切成单目标只有 `95`，**对群明确变弱**。
   但对单目标时 `38 → 95` 是巨大提升，且**目标少于 3 个时反而比原模式强**。
   如果直接给 ×3（114），单目标就和满编对群持平，切过去就没有代价了。

3. **机甲的 30% 是"各自最大血量的 30%"，不是固定值。**
   机甲自己 320 血 → 回 96；被修的那座塔如果 240 血 → 回 72。
   用 `tower.addHp()` 治疗（**不能**用 `hurt(-n)`，见 18.6 第 2 条）。

4. **机甲的 3 秒是"停止"，不是"按钮冷却"。**
   按下之后这 3 秒里：**不能移动、不发维修脉冲、不能回收残骸**。
   这是用一次群体爆发换来的代价 —— 也正是它冷却能只给 3 秒的原因：
   如果只是按钮冷却、机甲照常修塔走路，3 秒对一次"群体回 30%"就太便宜了，那条代价等于不存在。
   实现上必须在 `_physics_process` 里整体挡住，**不能**只在按钮上判断（见 18.6 第 6 条）。

> **"破甲"依赖一个目前不存在的接缝**：`enemyInfo` 里有 `armor`（0~1），
> 但伤害结算处是直接乘还是逐条判断，实现前要先在 `enemy.gd::hurt()` / 子弹结算里确认。
> 若没有统一入口，**先实现机枪塔与铁箱塔**（不依赖护甲），破甲放到后面。

### 18.5 UI

- `scene/tower_detail_panel.tscn` 的 `ActionRow` 已经是"修理 / 出售"两个按钮，
  **加第三个 `btnSkill`** 即可 —— 这是既有模式，不用新开面板
- **按钮文案随类型变**：
  - `toggle`：显示"切到哪种模式"（如「导弹模式」/「溅射模式」），当前处于第二种模式时按钮高亮（安全黄）
  - `timed`：冷却中置灰 + 剩余秒数（`12s`）；生效中高亮 + 剩余持续时间（`2.4s`）
  - `instant`：只有冷却倒计时（`3s`）
- 视觉参考 `scene/ability_slot.tscn` 的冷却遮罩 + 数字（既有实现）
- `toggle` 的 3 秒切换 CD 期间按钮也要置灰 —— 否则玩家会以为点坏了

### 18.6 边界与坑

1. **技能期间塔被出售 / 被炸毁** → 计时器随节点释放，禁止留悬空引用（同 §7.5）。
2. **自损 / 治疗都不能走 `hurt()`**：
   - `hurt()` 在 `invincible` 时直接 return → 「无敌 + 过热」变白送，所以**自损**要单独 `applySelfDamage()`。
   - `hurt()` 里 `hp -= int(max(0.0, ceil(...)))` 把负伤害夹成 0 → **治疗**根本没效果
     （`mech.gd` 的注释里记着这个坑），必须用 `tower.addHp()`。
   - 两种情况的**死亡流程都得复用同一套**（释放格子、留残骸、记成就）。
3. 冷却用 `_physics_process` 推进 → 游戏暂停时自然暂停，正确；但**倍速（§十六）下冷却会加速**，
   这是可接受的（同 §16.4 的口径问题）。
4. 若塔在技能中升级，`levelUp()` 会重设 `delay`/`atk`/`radarScope` ——
   `applyFireRate()` 与 `applySight()` 必须重新叠上技能系数，否则升级会悄悄清掉技能效果。
   对 `toggle` 尤其致命：**切换状态 `skillOn` 是持久的，但系数是派生的**，派生那步漏了就跟没切一样。
5. `minHpRatio` / 切换 CD 拒绝触发时必须有提示（面板上短暂变红），否则玩家以为按钮坏了。

**`toggle` 专属的三条：**

6. **火箭塔导弹模式必须真的不溅射。** 现在 `rocketbullet.gd::spawnBomb()` 里
   `bomb.blastRadius = 90.0` 是**写死**的，而且伤害是靠 `bomb.tscn` 的范围结算。
   所以导弹模式不能只是"把半径调小"，要改成**命中时直接 `enemy.hurt(atk)`**、
   **不生成 bomb 场景**（否则要么仍溅射、要么生成一个半径 0 的爆炸导致 `get_overlapping_areas` 空转）。
   命中特效/烟仍然要播，见 `spawnHitEffect()`。
7. **激光塔切换时必须释放多余锁定。** `laser_tower.gd` 的 `laserTargets` 最多存 3 个，
   切到单体模式后要把第 2、3 个**从列表里移除并停止对应光束**，
   否则会出现"只锁定一个，但三条光束还挂在敌人身上"的视觉/伤害不一致。
   切回 3 目标模式时不用特殊处理 —— `collectTargets()` 会重新填。
8. **`toggle` 改射程要同时改两处**：`radarScope`（画圈 + 找目标）与
   `raderShape.shape.radius`（真实碰撞检测）。只改前者会出现"圈变大了但打不到"。

**机甲停止专属的三条：**

9. **停止必须在 `_physics_process` 里整体挡住，不能只挡按钮。**
   `mech.gd` 的 `_physics_process` 同时管三件事：移动（`updateMovement`）、
   维修脉冲（`repairTarget` / `fireRepairBeam`）、残骸回收（`updateSalvage`）。
   只在 `canUseSkill()` 里判断 `skillDisabledLeft` 的话，机甲照样会走路、修塔、捡残骸 ——
   这个代价就等于不存在。正确做法是在方法最前面加总闸，`super` 之后立刻 `return`。

10. **进入停止的瞬间要收尾，不能"挂着"。** 需要一个 `stopAllWork()`：
    - 正在回收 → `abortSalvage()`（**必须**，它会 `releaseClaim()` 释放残骸认领；
      否则这 3 秒里别的机甲也捡不了那坨残骸，等于把资源锁死 3 秒）
    - 正在移动 → 清掉目标格，原地停下（不要"暂停后接着走"，那会让玩家以为停止没生效）
    - 维修激光的粒子/光束 → 立刻停（`muzzleFx` 停止 emitting、`queue_redraw()`），
      否则会留着一条打到一半的激光

11. **停止不等于无敌。** 这 3 秒里机甲照样会被敌人打、照样会死。
    `hurt()` 不因为 `isDisabled()` 而返回 —— 这是代价的一部分，不是 bug。

### 18.7 分阶段

| 阶段 | 内容 |
|---|---|
| M1 | `applyFireRate()` / `applySight()` 重构（**不改行为**，先统一 2 处写 `wait_time` / 2 处写 `shape.radius` 的入口）+ `tower.gd` 技能框架（三种 kind） |
| M2 | 先做一座 `toggle`（火箭塔导弹模式）跑通全链路：切换状态、射程、无溅射 |
| M3 | 详情面板按钮 + 三种 kind 的文案/冷却 UI |
| M4 | 激光塔单体模式（含释放多余锁定）+ 机甲紧急维修（瞬发群体治疗） |
| M5 | 其余 6 座 `timed` 塔逐个接（每座一个探针） |
| M6 | 平衡调整 |

> 顺序刻意把"一座 toggle"提到最前面：`toggle` 的坑（释放锁定、射程双写、派生系数）
> 都集中在它身上，先用火箭塔趟一遍，后面激光塔就只是照抄。

### 18.8 验收探针

**通用**

- `timed`：冷却中 `canUseSkill()` 为 false、按钮不可点；生效中系数正确；结束后复原
- 塔在技能/切换状态下升级 → 系数仍在生效（验证 18.6 第 4 条）

**火箭塔（toggle）**

- 切换后 `radarScope` = 320 **且** `raderShape.shape.radius` = 320（两处同时变）
- 导弹模式命中一个敌人时，**周围 90px 内的其他敌人不掉血**（验证真的没溅射）
- 切回溅射模式后，同一次命中周围敌人重新掉血
- 3 秒内连按两次：第二次被拒绝（切换 CD）

**激光塔（toggle）**

- 单体模式：`laserTargets.size() <= 1`，光束只有一条
- 对单伤害 95（vs 正常 38），总 DPS 从满编 114 降到 95
- 切回后能重新锁定到 3 个

**移动机甲（instant + 停止）**

- 按下后：自身 hp +30% maxHp，半径 180 内每座受损塔各 +30% 自身 maxHp
- **满血的塔不会被"过度治疗"**（`addHp()` 内部已夹到 maxHp）
- **停止 3 秒内三件事全部无效**（这三条才是这条代价的关键，必须逐条断言）：
  1. **不能移动**：给一个移动指令，3 秒内位置不变
  2. **不能维修**：旁边放一座残血塔，3 秒内它的 hp **不涨**
  3. **不能回收**：旁边放一坨残骸，3 秒内不被回收；且残骸的 `salvager` 已释放
     （其他机甲此刻能认领它 —— 验证 18.6 第 10 条的 `abortSalvage()` 真的调了）
- 停止期间按钮显示倒计时且不可点
- 停止结束后的第一帧恢复工作（不用等下一轮脉冲）
- **停止期间仍然可以被打死**（`hurt()` 不受 `isDisabled()` 影响）

---

## 十九、Boss（小 boss / 大 boss）

> **实现状态：🟡 部分实现（2026-11-01）**
>
> **已完成**：7 种 Boss 的**场景 + 脚本 + 全部行为**、`enemyType` / `enemyInfo` / `enemyScenes`
> 数据登记、塔的「被沉默」机制、**专用测试场景** `scene/test/boss_test.tscn`。
> **未完成**：**挂进关卡**（`StageData.allStage` 里还没配 `bossWave` / `bossType` ——
> 目前只能从测试场景见到它们）、正式美术（现在全是占位贴图）。
>
> 需求原话（第一版）：「每关小 boss 也可以设计，只是现在美术缺乏」
>
> **需求修订（2026-11-01）**：
> 「每一关会有小 boss，我个人觉得不一定每关都需要大 boss，要设计几种 boss 出来，
> 不一样的特点，增加游戏乐趣」
>
> 也就是把 Boss 拆成**两级 + 多种类型**：小 boss 每关都有（负责"这一关的收尾"），
> 大 boss 只在少数关（负责"整段的里程碑"），而每种 boss 要有**明显不同的应对方式** ——
> 不是一个血更厚的坦克重复六次。

### 19.1 现状

12 种敌人全是常规单位，**没有 Boss 概念**（全项目搜 `boss` 无命中）。
最强的是实验坦克，但它只是"血多 + 4 座炮塔"，没有任何需要换打法的机制。

### 19.2 两级体系

| | **小 boss** | **大 boss** |
|---|---|---|
| 出场 | **第 4 关起，每关都有**（第 1~3 关与教程关没有） | **仅第 6 / 9 / 12 / 15 关**（最后一关必有） |
| 波次 | 倒数第二波 | **最后一波** |
| 血量 | 该关最强常规敌人 × 3 左右 | × 8 左右 |
| 数量 | 每关 **1 个** | 每关 **1 个** |
| 机制 | 单一特点（见 19.3） | 多条机制叠加 + **二阶段** |
| 奖励 | 金币 + 1~2 宝石 | 金币 + 3 宝石 + 成就计数 |
| UI | 顶部血条 | 顶部血条 + **50% 处二阶段刻度** + 出场横幅 |

**难度曲线上的理由（为什么前 3 关不放，以及大 boss 为什么错开到 6/9/12/15）**：

- **第 1~3 关不放小 boss**：这三关还在教"推进型 / 对抗型 / 空中"这些基本威胁，
  再塞一个 900 血的大块头会直接劝退。第 4 关开始玩家已经有 Lv.2 的塔，才打得动。
- **大 boss 从第 6 关起、每 3 关一个**：如果沿用原来的 4/8/12/15，第 4 关就会
  **小 boss + 大 boss 同场** —— 那是玩家第一次见 boss，太多了。
  错开到 6/9/12/15 之后，第 4~5 关是"适应小 boss"，第 6 关才第一次见大 boss。
- 大 boss 关**同时**有小 boss（倒数第二波热身、最后一波收尾），只在第 6 关及以后发生。

> 完整节奏：L1~3 无 boss → L4~5 小 boss → **L6 小+大** → L7~8 小 → **L9 小+大** →
> L10~11 小 → **L12 小+大** → L13~14 小 → **L15 小+大（最终关）**。

### 19.3 Boss 类型设计（核心）

设计原则：**每种 boss 逼你换一种应对**，而不是单纯堆血量。
下面 6 种小 boss 分别对应玩家的几种默认答案（堆物理 / 堆溅射 / 堆爆发 / 只补最后一刀 /
堆在一处 / 不建防空），每种都恰好**打不到**某一个默认答案。

小 boss 按关卡轮换：第 N 关（N ≥ 4）用 `SMALL_BOSS_ORDER[(N - 4) % 6]`，
顺序 = 铁壁 → 巢母 → 突袭者 → 分裂体 → 压制者 → 炮艇。
12 个 boss 关（L4~L15）正好每种出现 **2 次**，玩家不会连续两关见到同一个。

#### ① 铁壁 `bossBulwark` —— 打"只会堆物理伤害"的人

| 项 | 值 |
|---|---|
| 特点 | **护甲极高**（`armor 0.7`），移动慢（speed ×0.7），血中等 |
| 应对 | 物理伤害被砍 70% → 必须用**能量伤害**：特斯拉电弧、加农炮的「破甲弹」技能（`damageType = "energy"`） |
| 为什么有趣 | 它把"加农炮破甲弹"这个平时不显眼的技能变成刚需 |
| 视觉 | 复用 `armored_tank_v2_*`，`modulate` 偏蓝灰（厚钢板的颜色） |

#### ② 巢母 `bossHive` —— 打"只盯单体"的人

| 项 | 值 |
|---|---|
| 特点 | 血厚、**不还手**，每 6 秒在原地召唤 **3 只**该关最低级敌人 |
| 应对 | 需要**溅射/群伤**（火箭塔、激光塔、特斯拉）；无视小兵硬打本体会被淹没 |
| 约束 | 召唤物也占同屏上限（无尽模式 90）—— 上限快满时暂停召唤，避免把画面挤爆 |
| 为什么有趣 | 把"先清小兵还是先打本体"变成一个真实决策 |
| 视觉 | 复用 `experimental_tank_v4_*`，`modulate` 偏绿 + 缓慢脉动（"在产卵"） |

#### ③ 突袭者 `bossCharger` —— 打"塔摆得太稀"的人

| 项 | 值 |
|---|---|
| 特点 | **移速 ×1.8**、血量低（约为铁壁的 45%）、**不还击**，纯粹冲线 |
| 应对 | **EMP 减速**是唯一稳定的解法；配合高爆发秒掉。塔摆得稀就直接漏 |
| 注意 | 它是唯一会被 EMP 明显削弱的 boss（见 19.7 第 1 条：默认 boss **不免疫**减速，只有大 boss 才免疫） |
| 为什么有趣 | 给"EMP 塔"一个不可替代的出场理由 |
| 视觉 | 复用 `assault_buggy_v2_*`，`modulate` 偏橙红 + 尾部拖影（复用 `updateTrail` 思路） |

#### ④ 分裂体 `bossSplitter` —— 打"只在最后补一刀"的人

| 项 | 值 |
|---|---|
| 特点 | 死亡时**分裂成 2 个**各 40% 血的小号（**只分裂一层**，小号不会再分裂） |
| 应对 | 需要**持续范围伤害**；在小号出现的位置继续清掉。放在基地门口才打死＝灾难 |
| 约束 | 分裂物继承本体的位置与路线进度，但不继承减速状态（重新上状态） |
| 为什么有趣 | 让"击杀时机"变成决策：早杀和晚杀的结果不同 |
| 视觉 | 复用 `medic_v2_*` 底盘 + 双色 `modulate`，死亡时播一次镜像闪白 |

#### ⑤ 压制者 `bossJammer` —— 打"把塔堆在一处"的人

| 项 | 值 |
|---|---|
| 特点 | **光环半径 260**：每 5 秒让范围内所有防御塔**沉默 2 秒**（不能开火） |
| 应对 | **分散建塔**，别把输出全押在光环里；或者集火速杀（它的血是最薄的之一） |
| 实现 | 沉默 = 给塔一个 `silencedLeft`（同 §十八 的 `skillDisabledLeft` 思路），`fire()` 里挡 |
| 为什么有趣 | 唯一直接惩罚"塔堆在一起"的敌人 —— 和"塔靠击杀升级所以要分散"形成呼应 |
| 视觉 | 复用 `scout_drone_v2_*`（悬浮感）+ 地面画一圈**紫色脉动光环**（`_draw`，同敌人范围圈做法） |

#### ⑥ 炮艇 `bossGunship` —— 打"没建防空"的人（**飞行单位**）

| 项 | 值 |
|---|---|
| 特点 | **飞行**（`flying = true`）、血量中上（比铁壁薄）、移动慢，周期性对**最近的防御塔**投弹（范围伤害） |
| 应对 | 只有 **3 座塔能打空**：无人机基地、激光塔、火箭塔（`tower.gd::canTargetAir`）。没建这三座就只能看着它投弹 |
| 关键交互 | **EMP 对它完全无效** —— `emp_tower.onRadarAreaEntered` 里有 `not area.flying` 的判断。这是既成事实，设计上顺水推舟：飞机不怕地面减速场，很自然 |
| 另一层压力 | 它一边飞一边拆塔，逼玩家在"补防空"和"补输出"之间取舍 |
| 约束 | 走**常规路线**（不新增空中航线），所以仍需在到达基地前拦下；`lossPoints` 给 4 |
| 为什么有趣 | 前 5 种全是地面单位，"防空塔只在打无人机时有用"这个印象需要被重新建立 |
| 视觉 | 复用 `attack_helicopter_v2_body.*` + 旋翼帧，放大 1.4、`modulate` 偏紫；地面画一圈**淡紫光环**标出它的投弹范围 |

> ⚠️ 注意：这是**小 boss**，不是大 boss。飞行单位做成大 boss 会把可用塔压到 3 座、
> 整场变成单一解法（见 19.3 末尾"不做的"）。做成小 boss 就只是"这一关要留防空"。

#### ⑦ 大 boss：要塞 `bossFortress` —— 综合考验

| 项 | 值 |
|---|---|
| 外观 | 复用 `experimental_tank_v4_*`，放大到 1.25（配合提高后的 SVG 导入尺寸），偏金红 |
| 阶段 1（100%~50%） | 4 座炮塔交替开火 + 每 10 秒召唤 2 只精英小兵 |
| 阶段 2（<50%） | **狂暴**：攻速 ×1.5、移速 +30%、**免疫减速**，并立刻召唤一波 |
| 应对 | 前面所有 boss 的答案都要用上：破甲、溅射、减速（阶段 1 有效）、分散 |
| 为什么有趣 | 它是"整段的考试"，而不是又一种怪 |
| UI | 血条在 50% 处有**明显刻度 + 变色**，玩家能预期二阶段 |

> **不做的**：**飞行大 boss**（会把可用塔压缩到 3 座，一场战斗变成单一解法 ——
> 但**飞行小 boss 是可以的**，见 ⑥ 炮艇：它只要求"这一关留防空"，不支配整场）、
> 无敌护盾型（"必须等护盾消失"＝纯等待，没有决策）。

### 19.4 数值

所有 boss 的数值以 `Game.enemyInfo` 为**基数**，再乘该关的 `bossHpMul`（在 `StageData` 里显式写，
便于逐关调），这样不用给 15 个关卡各写一套 boss 数据。

| 类型 | 血（基数） | 护甲 | 速度 | 每杀金币 | 宝石 | `lossPoints` |
|---|---|---|---|---|---|---|
| 铁壁 `bossBulwark` | 900 | **0.70** | 35 | 80 | 1 | 3 |
| 巢母 `bossHive` | 1100 | 0.25 | 30 | 100 | 2 | 3 |
| 突袭者 `bossCharger` | 400 | 0.10 | **90** | 60 | 1 | **5** |
| 分裂体 `bossSplitter` | 800 | 0.20 | 40 | 90 | 1 | 3 |
| 压制者 `bossJammer` | 700 | 0.15 | 45 | 90 | 1 | 3 |
| **炮艇 `bossGunship`**（飞行） | 750 | 0.15 | 38 | 90 | 1 | 4 |
| **要塞（大）`bossFortress`** | **3000** | 0.35 | 28 | **300** | **3** | **8** |

`bossHpMul` 建议按关卡 id 线性增长（第 1 关 1.0 → 第 15 关 ≈ 6.5）：
`1.0 + 0.39 × (id - 1)`。大 boss 关再额外 ×1.0（它已经够厚，不必叠）。
小 boss 从**第 4 关**才开始，所以第一条 boss 的实血是 `900 × (1 + 0.39 × 3) ≈ 1945`
（铁壁）—— 相当于该关普通敌人的 3 倍多，是"要集火一会儿"的量级，不是打不动。

> 参考基准：普通敌人 hp 100~450、塔 Lv.3 的 DPS 约 40~90。3000 血的要塞需要
> **约 6~8 座满级塔集火 10 秒以上** —— 是"必须提前布好防线"的量级，不是"随手打死"。

### 19.5 数据结构

沿用 `enemyInfo`（不新开一张表，避免敌人代码分叉）。每个 boss 是一个**独立的敌人类型**
（追加到 `enemyType` 枚举**末尾**，遵守 §十七 的追加规则），有自己的场景与脚本，
但脚本 `extends "res://script/enemy/enemy.gd"`，复用移动 / 受击 / 奖励 / 掉落。

```gdscript
# Game.enemyType 末尾追加
bossBulwark, bossHive, bossCharger, bossSplitter, bossJammer, bossGunship, bossFortress

# Game.enemyInfo[type] 新增字段
"isBoss": true,
"bossTier": 1,                  # 1 = 小 boss，2 = 大 boss
"bossBarName": "_Boss_bulwark", # 血条上的名字（走 tr）
"bossAuraColor": Color(...),    # 地面光环颜色（区分类型，见 19.7 第 3 条）
```

`StageData.allStage` 每条新增：

```gdscript
'bossWave': 2,                                  # 第几波出小 boss；0/缺省 = 本关无
'bossType': Game.enemyType.bossBulwark,         # 出哪种小 boss
'bossHpMul': 1.0,                               # 该关 boss 血量系数
'bigBossWave': 3,                               # 大 boss 在第几波（仅第 4/8/12/15 关）
'bigBossType': Game.enemyType.bossFortress,
```

> 大 boss 的类型先固定为 `bossFortress` 一种。以后要加第二种大 boss，只需在
> `StageData` 里换 `bigBossType` —— 生成逻辑不用改。
> **第二种大 boss 已设计完：装甲列车，见 §二十五**（就是靠换这一行投放的）。

### 19.6 生成

`base_level.gd::buildWaveSpawner(waveNo)`：

```gdscript
if waveNo == bossWave and bossType != null:
    rows.append({"time": waveNo, "type": bossType, "number": 1, "route": 1, "isBoss": true})
if waveNo == bigBossWave and bigBossType != null:
    rows.append({"time": waveNo, "type": bigBossType, "number": 1, "route": 1, "isBoss": true})
```

⚠️ **Boss 不受战斗模式 `countScale` 影响**（§十七）——
否则蜂群模式会一次刷出 2 个 boss。判断依据是记录里的 `isBoss`，
`buildWaveSpawner()` 里对 `isBoss` 的行跳过倍数。

⚠️ **Boss 也不吃 `modeHpScale`？** 吃。难度模式对 boss 一样生效（它就是个敌人），
只有"数量"不翻倍。

### 19.7 关键决定与坑

1. **默认 boss 不免疫减速，只有大 boss 的阶段 2 才免疫。**
   原设计（v0）想给所有 boss 加"免疫减速"，但那会让 EMP 塔在最需要它的场合失效，
   而突袭者正是围绕 EMP 设计的。所以改成：小 boss **都可以被减速**（突袭者甚至依赖它），
   大 boss 只有进入二阶段后才免疫 —— 那时玩家已经打了半场，逻辑上也说得通。

2. **护甲必须能被穿透。** 铁壁的 0.7 护甲是给"只会物理"的玩家设的坎，
   但项目里已经有能量通道（`enemy.hurt(..., "energy")`）和加农炮「破甲弹」，
   所以它不是无解，只是要求换一套。**不要**再加"免疫某某伤害"这种无解设定。

3. **美术缺口：先用"可读性"顶替。**
   Boss 在没有专属美术前，靠三件事让玩家一眼认出它是 boss：
   - **尺寸**：比同类大 1.25~1.6 倍
   - **地面光环**：`_draw()` 画一圈本类型的颜色（复用敌人攻击范围圈的画法，零额外资源）
   - **顶部大血条**

   ⚠️ **放大位图会糊。** 素材是 SVG，Godot 导入时按 `width`/`height` 栅格化成位图；
   直接放大节点等于放大位图。要清晰必须**提高该 SVG 的导入尺寸**（64 → 128），
   再放到 0.9 倍 —— 这样进游戏是缩小而不是放大。
   （同 `art_style.md` v8.1「统一 scale 无法修正长宽比」是同一类问题。）

4. **召唤物不能把"无敌人"永远卡住。**
   `finish()` 的判定是"生产队列空 + 场上无敌人"。巢母召唤的小兵如果一直存在，
   最后一波就永远结算不了 —— 所以**召唤必须随本体死亡而停止**，
   且本关 boss 被清掉后当波剩余敌人正常结算即可（不需要额外逻辑）。

5. **Boss 逃跑代价要大。** `lossPoints` 给小 boss 3~5、大 boss 8；
   基地总共 20 血（普通关），漏一个大 boss 就是灾难级失误 —— 这是设计意图。

6. **Boss 血条与既有 `life_bar` 是两套。** Boss **不显示头顶血条**，只显示顶部大血条，
   否则同一只 boss 会有两条血条。

7. **成就别撞车。** 现有 `fortress_breaker`（击杀 30 个实验坦克）**不应**把大 boss 算进去 ——
   大 boss 是新类型，天然不会命中。另建议新增 `boss_slayer`（累计击败 10 个小 boss），
   并遵守 §17.6：挑战模式不计成就。

8. **「压制」必须能自动解除，否则是永久哑火（玩家实测报过）。**
   `tower.gd` 用 `canShot` 做开火闸，而 `canShot` 平时是**由冷却计时器**
   （`delayTimer.timeout → onDelayTimeout()`）重新置 true 的。
   如果沉默恰好覆盖了冷却到期的那一刻，`onDelayTimeout()` 会提前返回（正确地不放开），
   但**计时器已经停了、不会再来第二次** —— 于是 `canShot` 永远停在 false，塔彻底不再开火。
   修法：在 `_physics_process` 里检测"沉默归零的那一帧"，若冷却也已走完就把 `canShot` 还回去。
   > 教训：**任何"临时禁用一个由计时器恢复的状态"都要同时负责在解除时补恢复。**

9. **召唤物必须同时错开"进度"和"横向"。**
   只把 `progress` 往后挪 26px 时，三只小坦克的贴图仍然叠在一起（玩家反馈"挤成一坨"）。
   现在巢母是 **90px × 左右 ±22px**、要塞是 **120px × ±20px** ——
   `summonAt()` 因此多了 `lateral` 参数（写进 `spawnEnemy` 的 `offset`）。

10. **性能**：巢母 + 要塞的召唤物会叠加同屏数量，需与无尽模式的同屏上限（90）对齐；
   召唤前先查 `get_tree().get_nodes_in_group("enemy").size()`。

### 19.8 UI

> **实现状态：✅ 已完成（2026-11-01）**

- **顶部居中 Boss 血条**：`scene/ui/boss_health_bar.tscn`，挂在 `map.tscn` 的 `Hud` CanvasLayer 内
  （屏幕空间，不跟相机缩放）。**刻意不复用敌人的 `life_bar.tscn`**：
  那个根节点是 `Node2D`、挂在敌人身上跟着跑，语义是"被击中才亮 3 秒"；Boss 血条要**常驻**。
  **但皮肤复用了** `theme/style/tower_bar_bg.tres` + `tower_hp_fill.tres`，
  和塔详情面板 / 塔状态条是同一套视觉。
- 名称（走 `tr()`，取 `enemyInfo.bossBarName`）+ 血条 + **分段刻度**（25% / 50% / 75%）
- 刻度用**自绘 Control**（`script/ui/boss_bar_ticks.gd`）画线，不用 4 个 ProgressBar 拼 ——
  拼的话窗口一缩放就错位。线必须画在 ProgressBar **上方**，所以它是子节点
  （父节点的 `_draw` 会被自己的子节点盖住）。
- 大 boss：**50% 那条刻度加粗 + 换色**，填充转橙红，并浮出 `PHASE 2` 标签
- **多只 Boss 同时在场 → 多行堆叠**（2026-11-02 改）：每只活着的 Boss 占一行，
  大 Boss 在上、同级按**出生序号从早到晚**排（用 `enemy.gd` 的 `spawnSeq`，
  不能靠 `get_nodes_in_group()` 的顺序）。最多完整显示 **2 行**，超出的收进「还有 N 只 Boss」条。
  小 Boss 行高 48px、大 Boss 56px，血条厚度 10/12px；名字字号 24/26，用 `bossAuraColor` 染边框和名字。
  整体**固定在标题栏正下方居中**（top=112），不遮挡顶栏的波次 / 血量 / 金币 / 宝石。
  ⚠️ `map.tscn` 里该实例**不要**再写 `anchors_preset` —— 那会把场景里的锚点/偏移重置掉，
  血条就贴到标题栏上了（2026-11-02 踩过；探针确认标题栏底 98 < 血条顶 112）。
  每行都是独立场景 `scene/ui/boss_health_row.tscn`，状态各自维护，互不覆盖。
- Boss 死亡或节点被直接释放 → 对应行移除；全死光就隐藏
- **出场横幅去重**：同一波多只 Boss 只播一次（横幅只有一个实例，连播会互相截断）；
  若之后刷出更高档位的 Boss，允许再播一次（大 Boss 值得提示）。测试场景手动刷 Boss 时调
  `map.resetBossBannerDedup()` 清标记。
- **出场横幅 ✅**：复用 `waveBanner` 这个实例（`script/ui/wave_banner.gd::playBoss()`），
  标题= Boss 名、副标题= 一句话应对提示（`enemyInfo.bossTip`），停留比普通波次多 0.9s 留出阅读时间。
  ⚠️ `playWave()` 会把副标题永久藏起来，`playBoss()` 必须**重新显示**它，否则提示语写了也看不见。
  ⚠️ 分裂体的小号用 `silentBoss = true` 生成，**不会**再播一遍横幅。
  ⚠️ **不要写 `band.position`**：band 的父节点是 `CenterContainer`，居中由容器负责。
  旧代码在 `play()` 里写 `band.position.y = 0.0` —— 第一次播放时容器会重排并把它居中，
  但紧接的第二次播放（波次横幅 → Boss 横幅）容器不再重排，横幅就停在屏幕最上方。
  2026-11-02 实测：波次横幅 y=435（正中），紧接着的 Boss 横幅 y=0（顶部）。
  现在已删除所有 position 写入与上移动画，进出场只做淡入淡出/缩放，位置固定居中。

### 19.9 分阶段

| 阶段 | 内容 | 状态 |
|---|---|---|
| M1 | 数据字段 + 复用实验坦克（放大/上色/光环） | ✅ 已完成（含 `progress` / `hpScale` / `props` 三个 `spawnEnemy` 扩展） |
| M2 | 顶部 Boss 血条 UI（含二阶段刻度） | ⬜ 未做 |
| M3 | 小 boss 六连：铁壁 → 突袭者 → 巢母 → 分裂体 → 压制者 → 炮艇 | ✅ 已完成（6 个脚本 + 场景） |
| M4 | 大 boss 要塞（二阶段狂暴 + 免疫减速） | ✅ 已完成（**炮塔仍为单炮塔**，见 19.11 偏差 1） |
| M5 | 关卡配置（L4~L15 的 `bossWave` / `bossType` / `bossHpMul`，L6/9/12/15 的 `bigBoss*`）与平衡 | ⬜ 未做（**故意先不挂进关卡**，等测试场景调好手感） |
| M6 | 正式美术（提高 SVG 导入尺寸，替换贴图） | ⬜ 未做（当前是占位贴图） |
| M7 | 测试场景 `scene/test/boss_test.tscn` | ✅ 已完成（不在计划里，实现时补的） |

> 顺序的理由：**M3 里「压制者」和「炮艇」最后做** —— 压制者要给 `tower.gd` 加新状态
> （`silencedLeft`，和 §十八 的技能停摆同一套写法）；炮艇要验证
> **"只有 3 座塔能打空"**这条既有规则在 boss 血量下依然成立（别变成打不动的空中靶子）。

### 19.10 验收探针

**通用**

- 指定波次只生成 **1 个** boss；**蜂群模式下仍是 1 个**（`countScale` 不作用于 `isBoss`）
- **第 1~3 关不生成任何 boss**；第 4 关起每关 1 个小 boss
- 第 **6 / 9 / 12 / 15** 关同时有小 boss 与大 boss，其余 boss 关只有小 boss
- Boss 血条出现、数值与 `hp` 同步、死亡后隐藏
- Boss 不显示头顶血条
- Boss 与普通敌人同屏时，`finish()` 仍能正常结算

**逐个类型**

- **铁壁**：物理伤害被减免 ≈70%；`hurt(..., "energy")` 打满额
- **巢母**：召唤间隔 ≈6s、每次 3 只；**本体死亡后不再召唤**；召唤物不超过同屏上限
- **突袭者**：baseSpeed ≈90；被 EMP 减速后明显变慢（验证"可被减速"）
- **分裂体**：死亡后场上多出 **2 个**、各本体最大血量的 40%；小号不再分裂
- **压制者**：光环内的塔在周期内 `silencedLeft > 0` 且**打不出子弹**；范围外的塔不受影响
- **炮艇（飞行）**：`flying == true`；**EMP 对它无效**（`addSlow` 后 `speed` 不变 ——
  `emp_tower.onRadarAreaEntered` 本来就过滤 `area.flying`）；地面塔（机枪 / 加农 / 铁箱等）
  **打不到**它，无人机 / 激光 / 火箭可以；它的投弹能对塔造成伤害
- **要塞**：<50% 血后攻速/移速提升、**免疫减速**（`addSlow` 后 `speed` 不变）

**记录**

- 挑战模式击败 boss **不计**成就（§17.6）
- 普通模式击败 10 个小 boss 解锁 `boss_slayer`

---

### 19.11 已实现部分（2026-11-01）

#### 文件清单

| 文件 | 作用 |
|---|---|
| `script/enemy/boss/boss.gd` | Boss 基类：读 Boss 字段、画**脉冲光环**、`summonAt()`（带 progress 的召唤）、`tickShooter()`、`addSlow()` 免疫钩子 |
| `script/enemy/boss/boss_bulwark.gd` | 铁壁（无行为，全靠 `armor 0.7`） |
| `script/enemy/boss/boss_hive.gd` | 巢母：每 6s 召唤 3 只迷你坦克；**本体死亡即停**；同屏上限 90 |
| `script/enemy/boss/boss_charger.gd` | 突袭者（无行为，靠 speed 90） |
| `script/enemy/boss/boss_splitter.gd` | 分裂体：死亡分裂 2 个 40% 血小号，`props={"canSplit":false}` **只分裂一层** |
| `script/enemy/boss/boss_jammer.gd` | 压制者：每 5s 让 260 内所有塔 `applySilence(2)` |
| `script/enemy/boss/boss_gunship.gd` | 炮艇（飞行）：每 4s 向最近塔投弹，**单次伤害封顶 15% 塔血量** |
| `script/enemy/boss/boss_fortress.gd` | 要塞（大）：射击 + 每 10s 召唤；**<50% 进入二阶段**（攻速 ×1.5、移速 ×1.3、免疫减速） |
| `scene/enemy/boss/*.tscn` | 7 个 Boss 场景（**占位美术**：复用实验坦克 / 直升机贴图 + `modulate` 上色 + `scale`） |
| `scene/ui/boss_health_bar.tscn` + `script/ui/boss_health_bar.gd` | **顶部 Boss 血条容器**：多行堆叠、排序、最多 3 行 + 「+N」溢出条；规则见 19.8 |
| `scene/ui/boss_health_row.tscn` + `script/ui/boss_health_row.gd` | 单只 Boss 的血条行：名字、血条、分段刻度、二阶段变色 + `PHASE 2` 标签、Boss 身份色 |
| `script/ui/boss_bar_ticks.gd` | 血条上的分段刻度（自绘 3 条线，50% 那条加粗） |
| `script/ui/wave_banner.gd::playBoss()` | **Boss 出场横幅**（复用波次横幅实例，只换文案） |
| `scene/test/boss_test.tscn` + `script/test/boss_test.gd` | **专用测试场景**（见下） |

#### 配套改动

- `game.gd`：`enemyType` **末尾**追加 7 个值；`enemyInfo` 增加 `isBoss` / `bossTier` /
  `bossBarName` / `bossAuraColor` 字段。
- `stageData.gd::enemyScenes`：登记 7 个 Boss 场景。**但没有配到任何关卡**。
- `base_level.gd::spawnEnemy()`：新增两个可选字段
  - `progress` —— 从路线指定进度开始（分裂 / 召唤要在"当前位置"生成）
  - `hpScale` / `props` —— 血量系数与任意属性注入（分裂体小号用）
- `game.gd`：新增 `bossSpawned(boss)` / `bossDefeated(boss)` 信号（血条靠它接管，不必每帧扫全场）。
- `enemy.gd`：新增 `isBoss` / `bossTier` / `spawnSeq` 三个成员，
  `setupEnemyInfo()` 里发 `bossSpawned`，`hurt()` 的死亡分支里发 `bossDefeated`。
  `spawnSeq` 是全局递增的出生序号 —— 同级多只 boss 时靠它挑"最新"。
- `map.tscn`：`Hud` 下挂 `bossHealthBar` 实例。
- `map.gd`：连接 `Game.bossSpawned` → `onBossSpawned()` 播横幅。
- `enemyInfo`：7 个 Boss 各加 `bossTip`（复用测试场景那批 `_BossTip_*` 文案）。
- `enemy.gd`：新增 `silentBoss`（分裂体小号用，不发出 `bossSpawned`）。
- `base_level.gd::spawnEnemy()`：`props` 改在 `add_child` **之前**应用 ——
  `silentBoss` / `canSplit` 都要在 `_ready()` 里就能读到。
- `tower.gd`：新增 `silencedLeft` / `isSilenced()` / `applySilence()`；
  `_physics_process` 每帧把 `canShot` 压回 false，`onDelayTimeout()` 在压制期间不放行。
  9 个塔脚本**一行都没改**（它们都看 `canShot`）。

#### 怎么测

在编辑器里打开 `scene/test/boss_test.tscn`，按 **F6** 直接运行：

- 会加载**真实的第 1 关**当背景（路线 / 塔位 / HUD / 音效都是真的）
- 左侧面板列出 7 种 Boss，点一下就在 1 号路线生成一只
- 鼠标悬停按钮会显示"这个 Boss 该怎么打"
- 「清空 Boss」把场上敌人全部清掉（含召唤物），方便反复测

> ⚠️ 这个场景**不进游戏流程**：`StageData.allStage` 里没有入口，主菜单到不了。

#### 验收结果

探针 51 项断言全过，关键项：

```
physical=31 energy=100              # 铁壁：物理被砍 69%，能量打满
charger speed = 90, addSlow -> 63   # 突袭者可被减速
hive summons 3 minions              # 巢母召唤
hive stops summoning after death    # 死后不再召唤
splitter leaves exactly 2 shards    # 分裂体
shards have ~40% of parent maxHp    # 小号血量
shards cannot split again           # 只分裂一层
jammer silences the nearby tower    # 压制者
silenced tower cannot fire          # 沉默生效
towers outside the aura NOT silenced
gunship flying = true               # 炮艇
bomb damage=30 cap=30 (maxHp=200)   # 15% 封顶
fortress phase2: speed 28 -> 36, interval 0.70 -> 0.47, ignores slows
```

#### 与设计稿的偏差

1. **要塞没有做"4 座炮塔"**，用的是基类的单炮塔（`experimental_tank` 的 4 炮塔是它自己的实现）。
   单炮塔 + 更高攻速在体感上足够，做 4 炮塔要复制一套炮塔调度逻辑，留到 M6 再评估。
2. **Boss 血量还没乘 `bossHpMul`** —— 因为还没挂进关卡。字段已设计好（19.5），
   等 M5 配置关卡时一起加，否则现在乘了也没人用。
3. ~~顶部血条 UI 未做~~ → **已补上**（19.8）。Boss 仍然不显示头顶血条，只显示顶部那一条。
   探针 20 项断言全过（绑定/伤害同步/大 boss 抢占/小 boss 不抢/二阶段标记/大 boss 死后回落/全灭隐藏）。
4. **占位美术**：7 个 Boss 全是实验坦克/直升机贴图 + 上色。颜色已按 `bossAuraColor` 区分，
   地面上那一圈脉冲光环是目前最可靠的识别手段。
## 二十、三个模块的实施顺序建议

三者互相独立，但**有依赖与冲突点**，建议按下面顺序：

1. **§十八 M1（`applyFireRate()` 重构）先行** —— 它不改行为、风险低，却是塔技能的前提，
   而且顺手把"`wait_time` 有 2 处写、`start()` 有 6 处调"这个散点收成一个入口。
2. **§十七（战斗模式）** —— 收益守恒与记录隔离的逻辑独立，做完就能显著提升重玩价值。
3. **§十九（Boss）** —— 已扩成"两级 + 6 种类型"（见 19.2 / 19.3）。它本身不依赖别的模块，
   但**「压制者」会复用 §十八 的"单位停摆"写法**（给塔加 `silencedLeft`），
   所以要么放在 §十八 之后做、要么照抄那套状态写法。美术可先用放大 + 地面光环占位。
4. **§十八 M2~M4（塔技能）** —— 最后做，因为它需要逐塔调平衡。

**交叉冲突点（实现时必须一起考虑）**：

| 冲突 | 处理 |
|---|---|
| 蜂群 ×2 敌人 ↔ Boss 数量 | Boss 不吃 `countScale` |
| 挑战模式不记成就 ↔ Boss 击杀成就 | Boss 成就也只在正常模式记 |
| 塔技能自损 ↔ 无敌技能 | 自损绕过 `invincible` 判定，单独走 `applySelfDamage()` |
| 倍速 ↔ 技能冷却 / Boss 召唤计时 | 都走 `_physics_process`，随倍速加速（可接受，与 §16.4 口径一致） |
| 模式倍数 ↔ 无尽模式难度 | 两套独立变量相乘，**不要复用 `Game.enemyScale`** |

---

*本文档为 Machine-TD 项目功能模块设计记录，所有模块以独立、可扩展、信号驱动为设计核心。*

## 二十一、扩展内容设计（叠加式）

> **实现状态：📝 设计稿（未实现）**
>
> 需求原话：「目前如果游戏还需要扩展内容使游戏更好玩，还可以加哪些内容，帮我设计一下，
> 不要那种推翻重来的」
>
> 这一节**只收录"叠加式"扩展** —— 全部建立在已有系统之上
> （战斗模式 / 塔技能 / Boss / 星级宝石 / 图鉴 / 结算），
> 任何一条都**不改核心循环、不重做经济、不重画地图**。
> 已有的候选池（状态效果、塔联携、背包、局外成长、多路线）见 `roadmap.md` §三，
> 本节不重复；这里补的是它**还没覆盖**的四个缺口。

### 21.1 先看现在缺什么

把现有内容按"乐趣维度"摊开，能看出四个空白：

| 维度 | 现状 | 缺口 |
|---|---|---|
| **每局的变化** | 16 关固定编制 + 4 选 1 模式 | 同一关重打的理由只有"换模式" |
| **策略深度** | 摆位 + 何时开技能 | 塔不能设定攻击优先级，"打谁"全靠运气 |
| **反馈与成就** | 星级、宝石、12 成就、图鉴 | 打完不知道**哪座塔是 MVP**、血是怎么掉的 |
| **长期目标** | 全关卡 3★ | 全清之后没有继续玩的理由 |

下面 7 个模块正好各补一个缺口，并且**成本从低到高**排。

### 21.2 模块 A：结算战报 ✅ **已实现**（2026-11-01）

**玩点**：打完一关，结算页多一块「本局战报」：每座塔的**伤害占比**、**击杀数**、
**漏怪来源**、浪费的金币。玩家第一次能看见"我这座激光塔打了 41% 的输出"。

**为什么值得**：它不改变任何数值，却把已有内容**变得可读**。
塔防玩家最想看的就是"我的布局哪里出了问题"，现在的结算页只给星级和分数。

**实现要点**（几乎全是加法）：

- `tower.gd` 加三个计数器：`dealtDamage` / `killCount` / `overkill`
  （`hurt()` 里累加，`enemyDefeated` 里判来源）
- `map.gd` 记录 `leakLog`：每次 `enemyEscaped` 记 `{type, hp剩余, 路线}`
- `result_screen.gd` 加一个可折叠的列表页签
- **不改任何战斗逻辑**，只在既有信号上挂计数

**成本 S / 风险 低**（纯统计，不碰平衡）

**落地情况**：`tower.gd` 加 `dealtDamage / killCount / overkill`；
`enemy.gd::hurt()` 把结算后的实际伤害记到来源塔（护甲减免已经算进去）、死亡时给击杀者 +1、
逃脱时发新信号 `Game.enemyLeaked(enemy)`；`map.gd` 记 `leakLog` 并汇总成
`buildBattleReport()`；`result_screen.gd::setReport()` 在宝石行下方**用代码**建出一张表：
**固定表头**（塔 / 占比 / 伤害 / 击杀）+ **可滚动列表** + 一行漏怪汇总。
探针 16 项断言全过；截图确认结算页版面。

> 两个实现上的选择：① **不复用 `enemyEscaped`** —— 它只带 `lossPoints`，拿不到敌人类型，
> 所以另加了 `enemyLeaked(enemy)`；② 战报表格**在代码里建**而不是写进 `.tscn` ——
> 行数随塔的数量变化，场景里预摆 5 行再逐个隐藏更麻烦。

### 21.3 模块 B：塔的目标优先级

**玩点**：每座塔可以选「最近 / 最远 / 血最厚 / 血最少 / 空中优先 / 只打空中」。
激光塔选"只打空中"、特斯拉选"血最少"补刀、加农炮选"血最厚"打前排 —— 同一套塔能玩出不同流派。

**为什么值得**：这是塔防类型里**性价比最高**的策略深度来源 ——
玩家会立刻感到"是我的选择在起作用"，而不是"数值不够"。

**实现要点**：

- `tower.gd` 已有 `getTarget()` / `pickTarget()`，把选目标的比较函数抽成策略表：
  ```gdscript
  const TARGET_MODES := { "nearest": ..., "farthest": ..., "maxHp": ..., "minHp": ... }
  ```
- 「只打空中」= 复用 `can_target()` 里的 `area.flying`，不是新机制
- 详情面板加一行下拉（和 §十八 的技能按钮同一行思路）
- 默认"最近"，**不选就是现在的手感**，老存档零影响

**成本 S~M / 风险 低**（默认行为不变）

### 21.4 模块 C：模式双词条组合

**玩点**：现在只能 4 选 1。改成可以**叠加两个**（蜂群 + 铁流 = 又多数又耐打，
奖励按两条相乘）。同一关的重打理由从 4 种变成 10 种。

**为什么值得**：`battleModeDefs` 已经是纯数据表，倍率相乘本来就是既有机制 ——
**几乎零代码**就能把内容量翻一倍多。

**实现要点**：

- `Game.battleMode` 从 `String` 扩成 `Array[String]`（或保留单值 + `secondaryMode`）
- `applyBattleModeScales()` 里把两个 def 的倍率**逐项相乘**
- 关卡选择页的模式条改成"可多选，最多 2 个"
- `recordsProgress` 规则：**任一词条是挑战模式 → 不记星级/成就**（保守优先）

**成本 S / 风险 中**（组合可能出极端值，需要给倍率加夹紧上限）

> ⚠️ 注意：这一条会改 `Game.battleMode` 的类型，**属于"改数据形状"而不是"重做玩法"**。
> 如果不想动它，可以退一步：只做预设组合（正常/蜂群/铁流/精锐/**蜂群铁流**/**精锐蜂群**），
> 仍然是纯数据。

### 21.5 模块 D：敌人精英词缀

**玩点**：普通敌人有小概率带 1 个词缀 ——
**护盾**（首伤减免）、**再生**（每秒回血）、**迅捷**（移速 ×1.4）、**分裂**（死亡分裂一只小号）。
一关里出现几只"带光环的精英"，玩家必须临时改打法。

**为什么值得**：给"每局不一样"提供了**不重做关卡**的随机性来源，
而且完全复用 Boss 已经验证过的零件（分裂、光环、沉默）。

**实现要点**：

- `enemy.gd` 加 `affixes: Array[String]`，在 `setupEnemyInfo()` 里按关卡配置掷骰
- 四个词缀都是**已实现机制的复用**：护盾 ≈ `tower.damageTakenMul` 的反向、
  再生 ≈ `enemy.addHp`、迅捷 ≈ `speed ×`、分裂 ≈ `boss_splitter.doSplit()`
- 视觉：脚下画一圈小光环（`_draw`，和 Boss 光环同一个画法，换颜色）
- **难度控制**：词缀概率与种类由 `StageData` 每关配置，前期 0%

**成本 M / 风险 中**（会改变难度曲线，必须逐关配概率）

### 21.6 模块 E：地形装置（可建造区上的特殊格）

**玩点**：地图上有几种**非塔**的可交互格：

| 装置 | 效果 |
|---|---|
| **爆炸桶** | 被打爆时对周围敌人造成范围伤害（也可以自己点爆） |
| **传送带** | 敌人经过时移速 +40%（负收益，但旁边给 2 个塔位当补偿） |
| **雷达增益台** | 相邻塔射程 +15% |
| **维修台** | 相邻塔每秒回 1% 血 |

**为什么值得**：它把"摆哪里"从"覆盖多少格"变成"**怎么利用地形**"，
而地图本身不用重画 —— 只是在既有 `allowArea` 里标记几个特殊格。

**实现要点**：

- `StageData` 每关加 `specialTiles: [{ "grid": Vector2i, "kind": "explosive" }]`
- 一个 `special_tile.gd`（Area2D）负责效果，**塔的建造校验跳过这些格**
- 爆炸桶复用 `bomb.tscn` 的爆炸；增益台复用 `tower.gd` 的派生值（`effectiveScope` 再乘一次）
- 瓦片美术：`sprite/tile/` 已有 12 种地面瓦片，加 2~3 张即可

**成本 M / 风险 低**（不碰核心循环，只加一种可放置物；不做的话也不影响任何现有内容）

### 21.7 模块 F：塔的第二技能（二选一）

**玩点**：每座塔有 2 个主动技能，**开局前二选一**（或局内花金币切换一次）。
比如激光塔：「单体打击」或「超载」（3 秒内同时打 6 个目标但自损）。

**为什么值得**：§十八 的技能框架已经支持 `kind` + 数据表，
加第二套 def 就是加一行数据；而"二选一"立刻让**同一座塔**有了构筑分歧。

**实现要点**：

- `Game.towerSkills[type]` 从 1 条改成 `[def0, def1]`，`tower.gd::setupSkill()` 按选择取一条
- 选择 UI 放在**开局前的关卡介绍面板**（那里已经有情报区，位置现成）
- 选择存进 `player_data.cfg`，按塔类型记（下次进关沿用）
- **默认取第一套 = 现在的手感**

**成本 M / 风险 低**（完全不碰现有技能逻辑，只加索引层）

### 21.8 模块 G：每日挑战

**玩点**：每天一张固定 seed 的关卡（随机关卡 + 随机双词条 + 固定塔池），
本地记录最好成绩，连续参与给宝石。

**为什么值得**：它是"长期目标"缺口里**最省成本**的答案 ——
不需要新地图、不需要新敌种，只要把已有的关卡和模式**组合**起来。

**实现要点**：

- seed 取日期（`OS.get_date()` 拼字符串哈希），用 `randi_seed` 固定
- 从 16 关里抽一关 + 抽 1~2 个词条 + 抽 3~4 座塔放行（`StageData.stageTowers` 已有放行机制）
- 结果记进 `player_data.cfg` 的新字段 `dailyBest: { "date": score }`
- 入口放欢迎页（和"无尽模式"按钮同排）

**成本 M / 风险 低**（全部是既有系统的组合）

### 21.9 优先级与批次

| 批次 | 模块 | 理由 |
|---|---|---|
| **第一批** | **Boss 挂进关卡**（已完成 80%，只差数据）+ **A 结算战报** ✅ | 前者让已有内容真正上线；后者零风险、立刻提升"看懂自己打得好不好"。**A 已完成** |
| **第二批** | **B 目标优先级** + **C 模式双词条** | 两个都是 S 级成本，合起来显著提升策略深度与重打价值 |
| **第三批** | **D 精英词缀** + **E 地形装置** | 需要逐关配概率/摆格，工作量中等，但能明显改变每局体验 |
| **第四批** | **F 第二技能** + **G 每日挑战** | 依赖前面的构筑与模式，放在最后收益最大 |

> 每一批做完都可以单独发布 —— 这是"叠加式"的意义：**任何一批停下来都不留半成品**。

### 21.10 明确不做（会变成"推翻重来"）

| 想法 | 为什么不做 |
|---|---|
| **局外成长树**（永久升级） | 要重做经济与难度曲线，现有关卡的数值全部作废 |
| **多路线 / 分岔地图** | 要重画 16 张地图的路径与塔位 |
| **背包 / 装备系统** | 会让"塔"变成"装备"，等于换一套核心循环（设计稿 §二 保留，但不作为下一批） |
| **改像素/物理引擎** | 与玩法无关，纯风险 |
| **PvP / 联机** | 需要服务器与反作弊，且塔防不适合同步对战 |

### 21.11 通用验收要求

每个模块落地时必须满足：

1. **默认行为不变** —— 不选新模式 / 不设优先级 / 不用新技能时，手感与现在完全一致
2. **老存档可读** —— 新增字段缺省时回落默认值，不报错、不丢档
3. **一条能跑的探针** —— `.td_verify/` 下新增 `*_probe.gd`，输出 `@@` 断言
4. **不合并进关卡** —— 新内容先在测试场景验证，再决定挂进哪几关

---

## 二十二、内容充实设计（提前召唤 / 宝石商店）

> **实现状态：🟡 部分实现**（2026-11-02）—— 模块 H（提前召唤）已落地；模块 I（宝石商店）仍为设计稿。
>
> 需求原话：「提前召唤和宝石商店可以添加到文档里面」
>
> 这两个模块各补一个已核实的事实空白（见代码，2026-11-02 核对）：
>
> 1. **波次节奏玩家零参与** —— 出怪完全由 `base_level` 的波次调度自动推进，
>    玩家在间歇期只能等；塔防经典"速通变现"手段（提前召唤）缺失。
> 2. **宝石只有产出、没有消耗** —— `autoload/userData.gd` 里对 `gem` 只有 `gem +=`，
>    全项目没有任何减法出口。一个花不掉的货币不是资源，是计分板。

### 22.1 模块 H：提前召唤下一波（Call-Wave Early）

> **实现状态：✅ 已实现**（2026-11-02）

**玩点**：波与波之间的间歇期，顶栏出现「下一波 ⏱ 12s」和一个召唤按钮。
立即召唤则按**剩余等待秒数**折算金币奖励。玩家 layout 已经够强时，
"等怪"的空窗期可以合法地变成收入 —— 节奏旋钮交还给玩家。

**为什么值得**：它是成本最低的"高手向"机制：不改任何数值表、不加任何美术，
却同时补上"每局变化（快慢自选）"和"操作参与感"两个维度。

**规则设计**：

| 项 | 规则 |
|---|---|
| 生效区间 | 仅在第 2 波起的**波间间歇**；第 1 波不可提前（保留布防时间） |
| 奖励公式 | `bonus = min(floor(剩余秒数 × 2), 该波敌人击杀总金币 × 30%)` |
| Boss 波 | 可提前召唤但**不给金币**，按钮用警示色（提前拉 Boss 是战术，不该再白送钱） |
| 无尽模式 | **隐藏按钮**（v1 先不做；无尽的成绩含"用时"维度，提前召唤等于双重获利） |
| 总开关 | `const ENABLE_EARLY_CALL := true`（roadmap §二 原则②） |

**实现要点**：

- 提前召唤 = **截断当前间歇计时器**，立即走既有的"到点开下一波"路径。
  ⚠️ **绝对不改波内出怪间隔** —— §17.7 第 3 条的教训（"后一个追上前一个叠成一团"）
  对这里同样适用，`nextSpawnDelay()` 一个字节都不能动。
- 发金币复用既有 `addGold` 通道 → 金币飘字（§十二）自动生效。
- UI 挂在波次进度条（§五）右侧加一块倒计时 + 按钮；来袭横幅（§十三）的
  现有队列要保证"提前召唤后的横幅"与间歇倒计时横幅**不重叠**。
- 计时口径全部用**游戏内时长**（与批次 A 统一），2X 倍速下奖励折算与 1X 一致。

**收益守恒说明**：30% 上限是刻意的 —— 若"全程秒召唤"收益超过正常布防节奏，
它就成了唯一最优解，反而消灭策略。宁可偏保守，上线后再调。

**验收探针**：

- 间歇 20s、第 8s 召唤 → 金币 +24；若该波击杀总金币 ×30% < 24，则发封顶值
- 提前召唤后，该波**波内敌人间距分布**与不召唤时完全一致（断言 spawn 间隔未被改）
- 第 1 波间歇按钮不存在；最后一波清空后按钮消失
- `ENABLE_EARLY_CALL = false` 时，调度时序与改动前逐帧一致
- 2X 倍速下同样剩余秒数的奖励 = 1X 下的奖励

**成本 S / 风险 低**（不碰平衡表；主要风险点只有"叠成一团"，已用禁改间隔规避）

**落地说明（2026-11-02）**：

- 调度改造集中在 `script/level/base_level.gd`：新增 `IntermissionTimer`（`base_level.tscn`，继承到全部关卡），
  上一波清空后进入 20 秒间歇；`onWaveTimerTimeout()` 拆出 `startNextWave()`，自然到点与提前召唤复用同一条开波路径。
- 默认间歇 `WAVE_INTERMISSION = 20.0`，关卡数据可用 `waveInterval` 覆盖；**无尽 / 教程关设为 0**，
  保留原来的"清空即下一波"节奏（无尽本来就要隐藏按钮，教程引导不该卡在空等上）。
- 奖励 = `min(ceil(剩余秒数) × 2, 该波击杀总金币 × 30%)`。剩余秒数按 UI 显示口径向上取整，
  避免面板写"12s"却因内部还剩 11.98 秒只给 23；击杀金币按 `modeRewardScale` 同步挑战模式。
- Boss 波照常可召唤但奖励恒为 0，按钮文案换成警示色。奖励由 `map.gd::onEarlyCallPressed()` 入顶栏金币。
- UI 为独立场景 `scene/ui/early_call_panel.tscn`，挂在 map HUD 右下角（原波次进度条位置），
  间歇期显示倒计时与按钮；`map.gd::_process` 每帧同步 `level.getEarlyCallInfo()`。
- `ENABLE_EARLY_CALL = false` 时连间歇一起关掉，调度时序与改动前一致。
- 验证：临时探针 43 项断言全过（含自然到点、1X/2X 同奖励、波内间隔未改、Boss 无金币、无尽禁用、
  最后一波后无间歇、HUD 显示 → 点击 → 入账 → 收起整条链路）。

### 22.2 模块 I：宝石商店（Gem Shop）

**玩点**：主菜单一个商店页，宝石可以花掉。商品只卖**局内一次性便利**与**纯收藏**：

| 商品 | 价格 | 效果 | 每局限次 |
|---|---|---|---|
| **战地补给** | 2 宝石 | 进关后金币 +80（≈ 关卡起始金的 30~40%） | 2 次/局 |
| **租借塔** | 3 宝石 | 在**限塔池关卡**解锁一座未放行塔，本局可建 | 1 座/局 |
| **战地维修组** | 2 宝石 | 本局内第一座被摧毁的塔**自动原地重建**（保留等级，免再花建造金） | 1 次/局 |
| **图鉴彩绘** | 5 宝石/张 | 解锁图鉴中某单位的正式立绘页（纯收藏，永久） | — |

**为什么值得**：模块 H 与 §二十一 各设计（合同/猎首/整备站）都会往玩家手里塞宝石，
商店让"这局值不值得花 2 颗赌一把"成为开局前的最后一个决策。
所有商品都是**借用/一次性**，永久数值不变 —— 这是它比"局外成长（roadmap #9，
成本 L / 风险高）"便宜得多的原因，也是它**不触犯** §21.10「不做局外成长树」红线的原因。

**实现要点**：

- 数据全在 `userData.gd`：`spendGem(amount)`（禁止扣成负数）+
  新字段 `unlockedArt: Array[String]`（图鉴彩绘，永久）
- **租借塔不写回 `StageData.stageTowers`** —— 它是"本局通行证"：
  `isTowerAllowed()` 前加一层 session 级 override（`map.gd` 上的字典，离开关卡复位）
- **限次是局内状态**：补给/租借/维修的已用次数放 `map.gd`，
  遵守 `code_design.md` §7.6 的复位约定；彩绘解锁是**永久存档**，走 cfg
- 战地维修组：挂既有"塔被摧毁"信号，`_exit_tree` 前判"本局是否已触发过"；
  重建走既有建造路径 + 直接设回被毁塔的等级，不新开机制
- 定价校准基准：普通关首通宝石 ≈ 8~9（`StageData.gemReward`）。
  **单局可购商品总花费应 ≥ 3 倍的单局宝石产出**，保证商店是"选择性消费"
  而不是"每局全买"，否则它变成第二个金币系统。

**边界与坑**：

1. 购买即落盘（`cfg.set_value` 后立即 save），否则崩档丢宝石。
2. 宝石不足时按钮禁用（不是点了报错）。
3. 挑战模式/无尽能否购买：**允许**（商店只收宝石，不产出星级/成就，不破坏记录隔离）。
4. 租借塔在"不限塔池"的关卡（5 关及以后）按钮应**置灰并注明原因**，
   否则玩家会问"我花了宝石为什么没效果"。

**验收探针**：

- 买补给后 `gem` 精确减少、局内金币 +80；第三次购买被拒
- 租借塔后本关可建该塔；**退出重进同一关，该塔又不可建**（session 复位）
- 塔被摧毁 → 维修组自动重建且等级保留；第二座被毁的塔不触发
- 彩绘解锁跨重启保留；购买中途强杀进程后余额与解锁状态一致
- `gem` 不可能为负（直接调 `spendGem(999)` 断言返回 false 且余额不变）

**成本 S~M / 风险 低**（纯 UI + 存档读写 + 一个 session override；不碰战斗数值表）

### 22.3 批次建议

| 批次 | 内容 | 理由 |
|---|---|---|
| 第一批 | 模块 H 提前召唤 | 成本 S、零美术、立刻改变每局手感 |
| 第二批 | 模块 I 宝石商店（先只做补给 + 彩绘两格） | 先给宝石开一个出口，商品表后续随其他模块产出增加再扩 |
| 观察项 | 租借塔 / 维修组 | 依赖"限塔池玩法"变多（§二十一 G 每日挑战落地后价值才充分体现） |

---

## 二十三、灵感库记录（塔防机制调研吸收，未排期）

> **实现状态：📄 灵感记录（不作为开发承诺）**（2026-11-02）
>
> 需求原话：「先全部写入文档，但是不一定后期要全部实现，作为一个记录」
>
> 来源：对 Steam 塔防产品的机制调研（Bloons TD 6、Kingdom Rush、Legion TD 2、
> Element TD 2 / Gem TD、Shapebreaker、Cards and Towers、Gnomes 等）。
> 筛选标准：只收**能挂在"造塔 + 波次 + 固定路线 + 金币经济"地基上的叠加式机制**，
> 且不与 roadmap §三候选池、§二十一、§二十二 重复。
> 这一节**不进 roadmap 候选池、不排批次** —— 将来想启用哪条，再单独晋升为设计稿
> （补验收探针、冲突表、数值表），届时把该条状态改为 📝。
>
> 主要出处存档：
> - [Banana Farm (BTD6)](https://bloons.fandom.com/wiki/Banana_Farm_(BTD6))
> - [Legion TD 2 Game Manual](https://beta.legiontd2.com/manual/)
> - [Element TD 2 Towers](https://eletd2.fandom.com/wiki/Towers)
> - [Shapebreaker: TD Deckbuilder](https://store.steampowered.com/app/1924010/Shapebreaker__Tower_Defense_Deckbuilder/)
> - [Cards and Towers](https://steamcommunity.com/app/2464750)
> - [Gnomes 开发复盘（10 个月 roguelike TD）](https://howtomarketagame.com/2025-08-13/gnomes-tower-defense-with-10-month-dev-time-hits-367484/)

### 23.1 模块 J：支援塔族（灵感：BTD6 Monkey Village）

**玩点**：2 座**不攻击**的支援塔，效果是改写范围内其他塔的行为：

| 塔 | 光环 | 设计意图 |
|---|---|---|
| **雷达站** | 范围内塔射程 +15%，且使其可锁定空中单位 | 缓解"对空塔位不够"，让一栋建筑解决一片 |
| **指挥车** | 范围内塔攻速 +12%，但自身占一格零输出 | 摆位目标从"覆盖路线"变成"覆盖自己的塔" |

**与地形装置（§二十一 E）的分工**：E 是地图上**预设的特殊格**（利用地形），
J 是玩家**花钱建造的塔**（构筑决策）——两轴不同，若都实现则互相增强，不冲突。

**实现草记**：`towerType` 表末尾追加；射程乘区走 `effectiveScope`，
攻速必须走 §十八 M1 规划的 `applyFireRate()` 统一入口；
**光环取最强不叠加**（与 EMP 状态合并同一语义，禁止连乘）。

**成本 M / 风险 低**（前提：`applyFireRate()` 重构先行）

### 23.2 模块 K：建造许可证（灵感：BTD6「同塔限放 2~3 座」）

> **状态变更（2026-11-05）**：用户拍板**晋升并实现**。数据表 `StageData.towerQuota` 按 23.2.1
> 投放表配置了 3/4/7/11/15 五关；7 关那条的"待验证"已核 —— 实测 `tower.gd:160`
> 火箭可对空（`canTargetAir` 列表含 droneBase/laser/rocket），限火箭=逼玩家给激光/特斯拉分位，按原案成立。
> 实现与验收见 §八 2026-11-05 条。**以下内容为设计原稿，保留。**

**玩点**：`StageData` 关卡条目加可选字段 `towerQuota: { towerType: 次数 }`，
关卡介绍面板显示限额（"机枪 ×8 / 激光 ×2"），超出的塔在建造栏置灰。

**为什么值得**：全项目**成本最低**的构筑多样性来源 —— 一个计数判断 + 一行 UI。
不配字段的关卡 = 无限制，老存档零影响。它还能直接充当
每日挑战（§二十一 G）与 Boss Rush 玩法的现成规则素材，一份机制两处复用。

**实现草记**：限额计数放 `map.gd`（局内状态，遵守 §7.6 复位）；
置灰原因走塔位按钮既有 tooltip 通道。

**成本 S / 风险 低**

#### 23.2.1 关卡投放表（记录，未排期；2026-11-02 按 `StageData.allStage` 实测构成制定）

**总原则**：

| 规则 | 内容 | 理由 |
|---|---|---|
| 投放数量 | 16 关只配 **5 关**，间隔 ≥3 关 | 许可证是"风味调料"不是"主菜"，关关都限会变成另一个游戏 |
| 投放区间 | 只在第 3 关之后 | 前 3 关是新塔密集解锁期，限制和"学习新塔"抢注意力 |
| 词条数量 | 每关最多限 **2 种塔** | 限 3 种以上，玩家记忆负担从"一个巧思"变成"一张卷子" |
| 限谁 | **只限廉价泛用塔（机枪为主）或"本关容易过度投资"的塔**；刚解锁的新塔永远不限 | 限制的意图是"砍冗余"，不是"堵最小解"（BTD6 限香蕉农场同理） |
| 硬底线 | 该关既有最优解的塔数必须仍 ≤ 限额（实施时探针验证） | 否则 16 关平衡被新机制单方面改动，违反 roadmap 原则① |

**投放位置**（依据各关敌人构成，数字为 `allStage` 汇总实测值）：

| 关 | 本关构成特点 | 限额 | 要教的事 |
|---|---|---|---|
| **3** | heavyTank 首秀（×4）+ 特斯拉解锁 | 机枪 ≤4、加农 ≤4 | "泛用塔不够打装甲"——用限制代替教程，逼特斯拉/火箭上场 |
| **4** | buggy ×47 海 + 自爆 ×3 | 机枪 ≤8 | 机枪对蜂群性价比太高易无脑铺满，逼出"火箭溅射 + EMP 减速"分层防线 |
| **7** | 空中规模化第一张完整卷子（drone 6 + heli 5 + plane 3） | 火箭 ≤3（待定） | ⚠️ **挂"待验证"**：先实测 `can_target()` 哪些塔能对空再定限谁——火箭能对空则成立，否则换成限 EMP，宁可暂缓不拍错塔 |
| **11** | 全兵种 ≥10 的均衡大图（空中 17、重甲 22） | 特斯拉 ≤4、激光 ≤3 | 中期"专科依赖症"——两把专科刀限量，逼玩家重估加农破甲与机枪补刀 |
| **15** | 最重编制（buggy 72、heavy 52）+ Boss | 机枪 ≤6、加农 ≤6 | 终局仪式：最后一关强制"精英阵容"，全 campaign 唯一一处为剧情服务的限制 |

不投放：教程（0，12 种敌人全出场）、1/2（教学上升期）、5/6/8/9/10/12/13/14、无尽 ——
保持默认无限，避免限制与数值爬升曲线互相干扰。

#### 23.2.2 备选投放路线：自愿限令（更保守）

不动 campaign 任何一关，许可证只挂挑战内容：

- **战斗模式 × 限令**：选挑战模式时可自愿勾选一条限令（如"机枪 ≤8"），
  报酬 `gemScale +0.2` —— 玩家主动要限制换宝石，默认行为零变化；
- **每日挑战（§二十一 G）**的标配规则之一；
- **猎首模式**（§十九 Boss 变现玩法）每轮的固定变量。

两条路线**共用同一套判定代码**（`towerQuota` 字段 + `map.gd` 计数）。
建议顺序：先做自愿限令验证玩家接受度，再决定是否把 23.2.1 的 5 关配进 `StageData`。

### 23.3 模块 L：军需库利息（灵感：BTD6 香蕉农场"通胀衰减" + 自走棋存钱利息）

**玩点**："军需库"塔（不攻击）：每波结束按**当前持有金币**发 8% 利息，
单库封顶 +25 金；**同类递减**——第 2 座利率减半、第 3 座起无效。

**核心乐趣**：把塔防"有钱没处花"的废阶段变成每波一次的"存 vs 花"决策。
与 §二十二 H 提前召唤构成一对天然博弈（即时金币 vs 复利），两条互相抬价值。

**风险与限制**：会改变单关总收入 —— 按 roadmap 原则①，
**只在无尽模式与新玩法（猎首/每日）启用，老 16 关不配**，避免 16 关平衡漂移。
利息发的是金币不是宝石，不动宝石经济。

**成本 S~M / 风险 中**（收入曲线，需逐波核对上限）

### 23.4 模块 M：漏怪怒气（灵感：Legion TD 2「放走的敌人变成下波资源」）

**玩点**：每漏 1 个敌人，除照常扣血外，给共享**怒气条**充一格；
攒满可**免费重置一个已用主动技能的冷却**（或兑换一次提前召唤权，与 §二十二 H 联动）。

**核心反转**：漏怪从纯惩罚变成资源决策 —— "要不要故意放走这只重坦，
换一发区域轰炸清掉下波蜂群"。残局体验改善明显：漏了 2 只不等于摆烂。

**红线**：怒气是**补偿不是收益**。必须每关限次（建议 ≤2 格），扣血照常，
否则"故意漏怪刷怒气"成为新最优解，直接摧毁核心目标。

**实现草记**：挂 `Game.enemyLeaked`（§二十一 A 已建信号）累加；
重置冷却走 `ability_manager.gd` 既有的冷却字段，不新增通道。

**成本 S / 风险 中**（判定简单，风险全在"故意漏怪"的心理账户，数值上限要小）

### 23.5 模块 N：遗物三选一（灵感：Gnomes 等 roguelike TD 的 relic 层）

**玩点**：在无尽 / Boss Rush / 每日挑战里，每完成一批（5 波 / 每轮 Boss）
从 3 个随机**遗物**（本局限时被动）选 1：
`击杀金币 +5%`、`爆炸溅射 +20%`、`铁箱血量 +50%`、`EMP 范围 −30% 但攻速 ×2`……
结算页顶部渲染"本局构筑"清单（复用战报的表格代码）。

**与永久成长的分界**（防止日后反复讨论）：遗物**开局清零、不写存档**，
与 §21.10 红线的"局外成长树"是两类东西。

**关系说明**：早前讨论过的"无尽整备站"（波间 buff 三选一）是本模块的子集 ——
若本条实现，整备站不再单独做，三玩法共用一个选择层。

**风险**：词条相乘后期失控 → 池控制在 12~15 条，全部是"读既有统计 / 挂既有乘区"
的数据条目，同类效果取最强不叠加。

**成本 M / 风险 中**

### 23.6 模块 O：手牌模式（灵感：Shapebreaker / Cards and Towers，2024-25 卡牌 TD 流派）

**玩点**：战斗模式（§十七）的第 5 条词条变体：塔不从建造面板直接买，
从 **5 张手牌**中打出；打出后该牌进入冷却（按塔造价折算冷却波数），每波结束抽 1 张。
金币照常拾取，用途收窄为**升级已上场的塔**。

**核心乐趣**：把"何时建什么"从即时反应变成手牌管理（临场 hand 管理），
是重玩价值最大的单点改造；且"催波"在手牌节奏里天然成立，
与 H 提前召唤兼容。

**代价**：需要新手牌 UI（底部一行的牌槽 + 抽牌动画可省）；
机制上不碰数值表，纯"建造入口改道"。

**成本 M~L / 风险 中**（UI 是大头；玩法未验证前只是纸面推演，观望优先级最高）

### 23.7 模块 P：迷彩单位（灵感：BTD6 迷彩气球，"不可索敌"轴）

**空白依据**：塔的索敌筛选现在只有 `tower.gd` 一行
`return not area.flying or canTargetAir`（实测于 2026-11-02）——
整个"能不能打中"的轴没人住。现有敌人已覆盖：护甲 0~0.6、地空、拆塔、治疗、自爆、
多炮塔、飞越不扣血、Boss 行为（`game.gd::enemyInfo`），但全部默认"可见"。

**玩点**：`enemyInfo` 加可选字段 `"camo": true`；索敌判定扩成同格式的
`or canSeeCamo`。初期仅无人机基地 + 激光塔可打迷彩。
摆位问题从"谁覆盖路线"变成"**谁负责看**"——若 §23.1 雷达支援塔（穿迷彩光环）落地，
天然组成构筑题。

**防"被骗感"**（这条机制的体验红线）：
- 进关横幅明示"本关来袭含迷彩"（复用 §十三 横幅队列）；
- 情报面板对迷彩单位加问号位（点塔看说明也能查到）；
- 首战关只放 1~2 只迷彩，且路线前段至少有 2 格能建无人机基地。

**边界（写死，防日后反复讨论）**：迷彩是**兵种属性**，不做成精英词缀（§二十一 D）——
词缀 = 随机惊喜，迷彩 = 必须准备的题。两者语义不同通道，可共存不可混用。

**实现草记**：`enemyInfo` 末尾追加迷彩兵种（roadmap 原则③：只追加）；
`tower.gd` 判定函数扩一个 OR 分支；视觉 = 现有贴图半透明 + 轻微扭曲，零新美术。

**成本 M / 风险 中**（风险全在玩家预期管理，横幅做好就归零）

### 23.8 模块 Q：拾荒回收车（灵感：把 §十一 残骸经济变成争夺资源）

**空白依据**：残骸与回收（§十一）是玩家单方面捡的，敌人从不碰地图上的资源。

**玩点**：缓慢的回收车沿路"吞"残骸，每吞一块 `hp +15%`、护甲 `+0.05`
（体型/贴图层级变化作为视觉反馈）。残骸从纯福利变成**有代价的资源**——
"宁可提前引爆自爆车也别留大块残骸"这类微观技巧会自己长出来。

**实现草记**：敌人身上一圈残骸查询（复用 medic 的邻敌扫描写法改成扫残骸组）；
吞食走 `addHp` 既有通道；护甲乘区在 `hurt()` 里读的是条目字段，需确认是实例字段再改。

**投放**：第 12 关后（编制大、残骸密度才够）。若 §二十一 E 地形装置落地，
可加"吞爆桶反噬自身"变体。

**成本 M / 风险 中**（会拉长精英单位的实际击杀成本，投放密度要小）

### 23.9 模块 R：工事障碍车（灵感：敌人攻击"空间"而非塔）

**玩点**：每 4s 在 1×1 可建造格落一个路障，该格不能建塔；
射 3 发或火箭溅射炸掉清障。塔防品类里敌人攻击摆位可能性的设计很少见，新奇度高。

**红线**（负反馈机制必须有出口）：同时存在的障碍 ≤3 格；障碍**必须可清**且有明确提示；
避开机甲维修/回收路线格；建造校验时给出"被障碍占用"tooltip 而不是静默失败。

**成本 M~L / 风险 高**（本清单里唯一建议**最后做或不做**的：动的是建造循环的校验路径，
与机甲、地形装置（E）、许可证（K）的占格判定都要对一遍）

### 23.10 调研中被过滤掉的机制（避免重复劳动）

| 机制 | 已有对应 | 结论 |
|---|---|---|
| 陷阱连锁（Orcs Must Survive 式标记引爆） | roadmap #2 状态效果 + #3 塔联携 | 不另立模块，将来作为 #3 的组合素材 |
| 敌方掉落部件现场合成炮塔 | §十一 敌人残骸与回收 | 若做，应作为残骸系统的**扩展词条**，不是新模块 |
| 英雄化（经验曲线 + 大招） | §十 移动机甲 | 机甲已覆盖大部分体验，只缺"击杀升级"，挂在 #9 局外成长一起评估 |
| 全地图搬塔 / 轨道炮塔 | §十 移动机甲 + 铁箱 | 现有移动单位基建可再挖，但没有上面几条划算 |
| 元素合成塔池（Element TD 2 式 59 组合） | roadmap #3 塔联携 | 合成=改建造循环，超出"叠加"边界；联携保持"相邻触发"写法 |

---

## 二十四、敌人新机制轴设计（补给车队 / 督战指挥车）

> **实现状态：📝 设计稿（未实现）**（2026-11-02）
>
> 需求原话：「目前对于敌人的设计是不是有啥新的设计」→「都加入文档」
>
> 制定前先盘了现有敌人的**机制轴**（2026-11-02 实测 `game.gd::enemyInfo` 与敌人脚本）：
> 护甲 0~0.6 五档、速度 28~130、地/空二分、反击拆塔（突击快射 / 重坦齐射 /
> 导弹车 700 远程 siege）、治疗光环（`medic.gd` 邻敌 `addHp`）、自爆、
> 多炮塔要塞（实验坦克 4 炮塔 + `gemReward 2`）、飞越不扣血（战机 `lossPoints=0`
> + 50% 宝石掉落）、Boss 七行为。§二十一 D 精英词缀管"随机性"。
>
> 剩下**没人住的空白轴**共 5 条：高价值可猎杀目标 / 攻击型光环 / 不可索敌 /
> 敌人动地图资源 / 敌人占建造格。前两条（本节的 S、T）判定成本低、体验为正反馈，
> 晋升为设计稿进 roadmap（#21/#22）；后三条进 §二十三 灵感库（P/Q/R）。

### 24.1 模块 S：补给车队（波次级"猎杀决策"）

**玩点**：一支**值得投资源强吃、放走又不掉血**的护卫队：
运输车（血厚、速 25、`reward 40`、`gemReward 2`、**`lossPoints 0`**）+ 3~5 辆编制内护车。
玩家每波多一个真抉择：入口堆五座塔强吃车队，还是省火力专心守主线。

**为什么值得**：现有敌人要么漏了扣血、要么是经验包——没有任何"目标选择"层面的决策。
战机已经验证了"飞越不扣血"的判定链（`battlePlane.gd`），车队等于把这条链
从"独立航线骚扰"翻成"主线内的迷你 Boss 决策"，**且不需要新敌人兵种**——
运输车复用重坦贴图换色 + 货厢挂点（符合图鉴"每种敌人要有辨识轮廓"的既有约定，
若美术评估后轮廓不够，再升格为独立兵种）。

**数据结构**：不新增 `enemyType` 之外的一切——
`enemySpawner` 记录加可选字段 `escortGroup: { "carrier": {...}, "guards": [...] }`，
`buildWaveSpawner()` 组装时展开成普通条目（与模式倍率的交互：
运输车**吃 `hpScale` 不吃 `countScale`**，参照 §二十 冲突表里 Boss 的先例）。

**规则**：

| 项 | 规则 |
|---|---|
| 投放 | 第 6 关起每章 1~2 次，前期 0 次 |
| 奖励口径 | 运输车击杀给 `reward + gemReward`；**放走不掉血、不给怒气**（防与 §23.4 联动出"故意放走"漏洞） |
| 信息透明 | 来袭横幅单独显示"车队来袭"（复用 §十三）；情报面板给运输车标"高价值"角标 |
| 宝石防刷 | `gemReward` 走既有掉落，首通限定逻辑不动（反复刷关靠 `challengeCleared`/星级差额那套既有约束） |

**验收探针**：

- 车队波展开后：护车条目与手配等价；`escortGroup` 缺省时行为与现在完全一致（老存档）
- 运输车逃脱 → 基地血不变、怒气不涨；击杀 → 金币 +40×`modeRewardScale`、宝石掉落走 `gemReward` 既有通道
- 蜂群模式下护车数 ×2、运输车数恒 1（不吃 `countScale`）
- 横幅与既有"波次来袭"横幅同队列，不重叠

**成本 S / 风险 低**（纯数据组装 + 文案；唯一新字段 `escortGroup` 是可选缺省）

### 24.2 模块 T：督战指挥车（攻击型光环）

**玩点**：光环 200 内友军 `atk +20%`、护甲 `+0.1`。
击杀瞬间整列变软——敌人第一次有"该优先打谁"的答案，
也是 §二十一 模块 B（目标优先级）最好的用武之地（"指挥官优先"可做成预设项）。

**实现草记**：

- 新兵种追加 `enemyType.commandVehicle`（原则③表末尾追加）；
  数值锚点：`hp 450、speed 40、armor 0.3、reward 15、lossPoints 2`
  （介于重坦与装甲车之间，值得打但不至于打不动）
- 光环实现 = `medic.gd` 的邻敌扫描结构整段照抄，把 `addHp(atk)` 换成对目标挂
  `{atkMul, armorAdd}` 修正；**离开光环范围立即摘除**。
  ⚠️ 乘数走"目标自算 effective 值"（同 `effectiveScope` 的写法），
  **禁止直接改 `enemy.atk` 字段** —— 会复刻 EMP 减速漂移那个历史 bug（§八 2026-10-24 条）
- 多座指挥车：**同类光环取最强不叠加**（与状态合并同一语义）
- 视觉：复用 Boss 光环的地面圈画法（`_draw`）换黄色，`bossAuraColor` 字段的现成套路
- 投放：第 8、11 关（全兵种均衡大图，指挥车增益才成立）；编队配 1 辆，配 2 辆是后期关卡的"送分陷阱"（拆掉双光环的读图乐趣）

**验收探针**：

- 指挥车在场时邻敌伤害结算 ×1.2；指挥车被击杀 → 下一次伤害即回到 ×1.0（**不留残余**）
- 两辆指挥车光环重叠 → 邻敌仍是 ×1.2 不是 ×1.44
- 敌人 `atk` 字段本体不被改写（断言 `enemy.atk == 基础值`，防漂移写法回归）
- 蜂群/铁流模式下光环乘数与 `modeAtkScale` 相乘正确（`hurt` 结算顺序）

**成本 S~M / 风险 低**（有 medic 现成模板；风险集中在"别改字段本体"，探针已锁）

### 24.3 与其他模块的关系

| 关联 | 说明 |
|---|---|
| §二十一 D 精英词缀 | 词缀管随机惊喜，S/T 管兵种身份；可叠加（带"迅捷"的护车）但不可混用同一实现 |
| §二十一 B 目标优先级 | T 是 B 的最佳理由；B 落地时预设项加"指挥官优先" |
| §十九 Boss | S 的"放走不掉血"规则与 Boss 的"必须掉血"相反，靠 `lossPoints` 字段天然区分，无冲突 |
| §二十三 M 漏怪怒气 | S 运输车逃脱**不充怒气**（24.1 规则表已锁） |
| roadmap 原则① | 两模块都不改 `enemyInfo` 既有条目，只追加 —— 16 关平衡零漂移 |

---

## 二十五、装甲列车 boss（多部件大 boss）

> **实现状态：📝 设计稿（2026-11-12，未实现）**
>
> 需求原话：「我想设计一种类似火车的 boss，每节车厢有炮塔，有 5 节车厢，独立血量，
> 中间车厢被打爆，其他就会往前进，都被打爆就会爆炸，逃离扣血我想的是每节单独扣血」
>
> 四项待定已确认：**大 boss 第二种** / **一条合成血条 + 分段车厢格** /
> **每节 `lossPoints` 2（全漏 10）** / **终爆对周围塔造成范围伤害**。

### 25.1 它填的是哪条空白轴

§二十四 开头盘过的 5 条空白轴里，前 4 条已被 S/T/P/Q/R 认领或归档，
但**「一个 boss 由多个可击杀部件组成」这件事，现有 7 种 boss 一个都没做**
（§19.3 全是"单实体 + 一条机制"）。装甲列车 adds 三条现有 boss 都没有的东西：

| 新增轴 | 玩家被迫换的应对 |
|---|---|
| **多部件独立血量** | 火力被 5 个目标天然摊薄 —— "堆一座超级塔"的打法第一次失效，必须**铺开集火顺序** |
| **线性密集队列** | 溅射/群伤一次串打多节，单体高伤只啃一节 → **打"只会堆单体爆发"的人**（现有 6 种小 boss 没有一种惩罚这条） |
| **击杀顺序决策** | 先打哪节会改变列车的**长度**与**剩余火力**，见 25.3 |

设计原则仍然守住 §19.3 那句：**逼你换一种应对，而不是单纯堆血量**。
总血量刻意与要塞同档（3000 基数），它不是更厚的怪，是**形状不同**的怪。

### 25.2 编组结构

5 节**同质车厢**沿同一路线串成一列，每节是一个独立的 `Enemy` 实例，
自己带一座 `BaseTurret`（就是实验坦克那套子炮塔，见 §19.11 偏差 1 的反面 ——
这次是"多个身体 + 每个一炮"，不是"一个身体 + 四炮"）。

```
起点 ──────────────────────────────► 基地
 [车厢5] [车厢4] [车厢3] [车厢2] [车厢1]      ← 车厢1 最接近基地 = leader
   ↑
 中间那节（车厢3）身上标宝石，见 25.5
```

| 项 | 规则 |
|---|---|
| 槽位 | `progress[i] = leaderProgress - i × CAR_SPACING`（`i` 只数**活着**的车厢，从 0 起） |
| leader | 活着的最前面那节。它打死后**第 2 节自动上位**，列车继续前进 —— 没有"车头一死就停"的漏洞 |
| 起点铺开 | 生成时 leader 从 `4 × CAR_SPACING` 处入场，保证 5 节全在路线内（否则后几节 progress 为负、在起点外堆叠） |
| `CAR_SPACING` | 车厢贴图宽 × `scale` + 8px。占位美术阶段取 **72**（正式美术换贴图时跟着改这一个常量） |
| 车体朝向 | 由 `PathFollow2D` 自带的 `rotation` 跟曲线转，5 节自然弯成一列 —— 不需要手写朝向 |

### 25.3 核心机制：打爆一节，后面的收拢

**某节车厢被打爆 → 它后面的所有车厢整体前移一个 `CAR_SPACING`**，列车变短。
这正是需求里的"中间车厢被打爆，其他就会往前进"。

由此产生三条**真实**的策略，也是这个 boss 的全部乐趣来源：

| 打哪节 | 后果 |
|---|---|
| **尾车（车厢5）** | 后面没车厢 → **不推进任何东西**，纯粹削掉一座炮塔。最安全的答案 |
| **中间（车厢3）** | 后面两节各前移一格，列车收拢成更短的两团 → **溅射收益更高**，且**宝石在这节** |
| **leader（车厢1）** | 第 2 节顶上来，整列位置不变，但少一座最靠前的炮塔 —— 它同时是"最接近基地"的威胁 |

> **明确不做（已评估并否决）**：「打爆任意一节 → **整列**前移一格」（需求字面的另一种读法）。
> 它会让"打爆最后那节"和"打爆中间那节"都把整列车推向基地，
> 于是**正确行为被惩罚**、最优解变成"别打、先攒塔"。
> 收拢版本只让**死点之后**的车厢前进，玩家打死路威胁（leader）不受罚，
> 尾车前进一格也不会越界（它永远在最后）。

**压缩发生在死亡那一帧**，是一次性的 progress 改写，不是每帧重算
（每帧重算会在车厢被减速 / 恢复时抖动，见 25.7 第 1 条）。

### 25.4 二阶段（与要塞同构的"半血狂暴"）

以**合成血量**（5 节之和）判 50%，与现有大 boss 的 UI 口径保持一致：

| 触发 | 效果 |
|---|---|
| 合成血量 ≤ 50% | 编组速度 ×1.3、**全队免疫减速**（复用 `boss.gd::immuneSlow`，但作用在编组共享速度上）、立刻多开一节备用炮（车厢炮塔 `shootDelay ÷1.4`） |

> 为什么用合成血量而不是"还剩几节"：还剩 3 节 ≠ 剩 60% 血（可能 2 节残血 + 1 节满血）。
> 合成血量才能让玩家在顶部那一条上**一眼预期**狂暴什么时候来。

### 25.5 数值（基数，实际血量仍乘关卡 `bossHpMul`，见 §19.4）

| 项 | 每节 | 整列合计 |
|---|---|---|
| `hp` | 600 | **3000**（= 要塞同档） |
| `armor` | 0.30 | —— |
| `speed` | 26（编组共享，见 25.7 第 1 条） | 26 |
| 炮塔 `atk` / `shootDelay` / `scope` | 10 / 1.6s / 260 | 合计 DPS ≈ 31（要塞 ≈ 37） |
| `reward` 金币 | 60 | **300**（= 要塞同档） |
| `rewardExp` 塔经验 | 24 | 120（= 要塞同档） |
| `gemReward` | **只有车厢3 给 3**，其余 0 | 3（= 要塞同档） |
| `lossPoints` | **2** | 全漏 **10**（基地 20 血的 50%） |

`bossHpMul` 沿用 §19.4 的 `1.0 + 0.39 × (id - 1)`，**在 conductor 里对每节统一乘**（不在 5 个 enemyInfo 里各写一遍）。

> **宝石为什么挂在中间那节**：三个目的。① 总量仍然 = 要塞的 3，不破 §19.2 的奖励表；
> ② 给"打中间"一个正向理由，抵消 25.3 里"尾车最安全"造成的"没人敢打中间"；
> ③ 车厢3 被打爆同时触发收拢 → 奖励与机制在同一节点上，玩家会记住这件事。
>
> ⚠️ **不能靠车厢的 `gemReward` 字段实现**：`spawnEnemy()` 的 `props` 是在 `add_child` **之前**
> `set()` 的，而 `setupEnemyInfo()` 在 `_ready()` 里会用 `enemyInfo` 重新覆盖 `gemReward`
> （[enemy.gd:182](file:///F:/machine-TD/machine-td/script/enemy/enemy.gd#L182)）—— props 注入会被抹掉。
> 所以"哪一节掉宝石"由 **conductor 按槽位结算**（`canSplit` / `silentBoss` 之所以能用 props，
> 是因为那两个字段不从 `enemyInfo` 读）。

### 25.6 全灭爆炸

最后一节被打爆时，在**那节的位置**放一颗现成的 `bomb`（照抄
[suicideTruck.gd::triggerSelfExplode()](file:///F:/machine-TD/machine-td/script/enemy/suicideTruck.gd) 的写法）：

| 参数 | 值 | 理由 |
|---|---|---|
| `blastRadius` | 220 | 比自爆车的 120 大一档，大 boss 的收尾该有存在感 |
| `damage` | 60 | 相对 §19.10 探针里塔 `maxHp=200` 的量级 ≈ 30% —— 疼，但不会一炸拆塔 |
| `targetMask` | `1 << 0`（只命中塔） | 不能炸到敌人自己（编组都死了，留着只会污染统计） |
| `damageType` | `physical` | 与自爆车一致；不给它一个"能量爆炸"的新语义 |
| 视觉 | **只用 bomb 自己的动画** | ⚠️ 不要再叠 `ExplosionManage.playExplosion()`（`bomb.gd` 注释里已经写过这个坑） |

> **这条爆炸的设计意图**：让"最后一节在哪打死"变成决策 —— 拖到塔群边上补最后一刀，
> 会白送对面一片塔。它是 25.3 那套顺序决策的**收尾惩罚**，不是额外的随机坏运气。
> 因此**收拢（打中间/尾车）本身不爆炸**，只有整列全灭才炸。

### 25.7 实现草记

**新增文件**

| 文件 | 作用 |
|---|---|
| `script/enemy/boss/boss_train.gd` | 车厢：`extends boss.gd`。**不自主推进**（覆写掉 `super._physics_process` 里那段 `parent.progress += speed * delta`，改成只处理表现），把移动权交给 conductor；带一座 `BaseTurret` 挂点 |
| `script/enemy/boss/train_conductor.gd` | 编组控制器。**挂在 level 节点下，不挂在任何车厢上** —— 否则 leader 一死控制器跟着消失（25.8 第 3 条）。职责：槽位与 progress、死亡压缩、全队共享减速表、合成血条 provider、车厢3 宝石结算、全灭爆炸 |
| `scene/enemy/boss/boss_train.tscn` | 车厢场景（占位美术：复用 `armored_tank_v2_*` + `modulate` 铁灰 + `Turret` 实例一座） |

**数据登记（全部只追加，遵守 roadmap 原则③）**

```gdscript
# game.gd::enemyType 末尾追加（bossFortress 之后）
bossTrain

# game.gd::enemyInfo 新增一条：isBoss = true / bossTier = 2 /
#   bossBarName = "_BossName_train" / bossTip = "_BossTip_train"
#   bossAuraColor = Color(0.62, 0.66, 0.72)   # 铁灰：与要塞金红、炮艇紫明确分开
#   车厢不写 scope（炮塔自己带雷达），conductor 用 CAR_COUNT / CAR_SPACING 常量

# stageData.gd::enemyScenes 追加 bossTrain → boss_train.tscn
# StageData.allStage：'bigBossType': Game.enemyType.bossTrain   ← §19.5 预留的换型口子，生成逻辑一行不改
# lang/language.csv：_BossName_train / _BossTip_train 两条（en + zh）
# script/test/boss_test.gd::BOSS_ENTRIES：追加一条，方便按 F6 单测
```

**投放**：第 **9** 关（`bigBossType = bossTrain`）。
理由：L6 仍然是要塞（第一次见大 boss，综合考试），L9 换列车（**第二次见大 boss，形状完全不同**）——
这条正好兑现 §19.5 那句"以后要加第二种大 boss，只需在 StageData 里换 `bigBossType`"。
L12/L15 暂不换（要塞当终盘 Boss 更合适），轮换留给以后加第三种大 boss。

**三条必做的实现纪律**（都是这个 boss 独有的坑，不是通用建议）：

1. **速度必须是"全队一个数"**。车厢各自走 `refreshSpeed()` 的话，一节被 EMP 减速、
   另一节没减 → 车厢间距被拉长/挤叠，视觉直接变成"火车散架"，机制也就废了。
   做法：车厢覆写 `addSlow() / removeSlow()`，把来源转记到 conductor 的
   `teamSlowSources`，由 conductor 取最强一条算 `teamSpeed`，再把 `teamSpeed` **写回每节 `speed`**。
   > 这与 §八 2026-10-24 那条 EMP 减速漂移是同一类问题，只是这次多了一个"必须刚性"的约束。
2. **压缩只在死亡那一帧做一次** progress 改写。每帧按 `leader - i×spacing` 强制回写会和
   第 1 条打架（减速那一帧算出的 `i` 变了就会抖），也让"收拢"这个动作失去打击感。
3. **车厢要显示头顶血条**，这是对 §19.7 第 6 条（"boss 不显示头顶血条"）的**有意破例**：
   顶部只有**一条**合成血条，"到底哪节在掉血"必须靠头顶条 + 25.9 的分段格来回答。
   ⚠️ `boss.gd::_physics_process` 现在每帧把 `lifeBar.visible` 压回 false
   （[boss.gd:39](file:///F:/machine-TD/machine-td/script/enemy/boss/boss.gd#L39)），
   车厢这边要么把它放开，要么车厢干脆 `extends enemy.gd` 而不是 `boss.gd`，
   光环绘制从 `boss.gd` 抽成一个可复用片段。**推荐后者**（车厢是"部件"，语义上本来就不是完整 boss）。

### 25.8 血条：一条合成条 + 5 段车厢格

| 项 | 规则 |
|---|---|
| 顶部行数 | **仍然只有 1 行**（`MAX_ROWS = 2` 不动，不去占要塞那一行） |
| 血量 | 来自 conductor 的 `Σhp / ΣmaxHp`（含 `bossHpMul`），**不是** leader 车厢自己的血 |
| 分段格 | 血条上画 **5 段等分格**，每段 = 一节车厢。被打爆一节 → 那一格**变暗 + 画叉**（复用 `boss_bar_ticks.gd` 的自绘 Control 做法：线必须画在 ProgressBar **上方**，否则被盖住） |
| 与 fills 的关系 | 段格**只做分隔与状态**，不各自扣血 —— 填充仍是整条连续比例，所以"还剩多少总血"依然一眼可读 |
| 名字 | `_BossName_train`；`bossTip` 写"溅射打串、先拆尾车、中间那节有宝石、最后一节会炸"（横幅停留多 0.9s 的规则沿用 §19.8） |

**需要动的既有代码（这是本模块唯一一处非纯追加改动）**

- `boss_health_bar.onBossSpawned()`：只有 leader 车厢标 `isBoss` 发信号，其余 4 节用
  `props = {"silentBoss": true}` 生成 → 天然只建 1 行（`silentBoss` 是现成机制，分裂体小号已用过）。
- `boss_health_row.bind()/refresh()`：血量来源从"节点身上的 `hp/maxHp`"改成
  "节点有 `barProvider` 就用 provider 的 `barHp()/barMaxHp()/barCarSlots()`" ——
  对现有 7 种 boss 走原分支，**行为逐帧不变**。
- ⚠️ `boss_health_bar._process()` 现在判"绑定节点 `dead` 就删行"
  （[boss_health_bar.gd:74](file:///F:/machine-TD/machine-td/script/ui/boss_health_bar.gd#L74)）。
  leader 车厢打死后编组还有 4 节活着，**这条判据必须换成"provider 说编组还有活的不删行"**，
  否则整列还剩一半血、血条却当场消失。这是本模块最容易写错的一处。
- 大 boss 的 50% 加粗刻度 + `PHASE 2` 标签（§19.8）在合成条上照常生效 —— 25.4 就是按合成血量判的，正好对上。

### 25.9 关键决定与坑

1. **不吃蜂群 `countScale`**：列车每一节都标 `isBoss`，`buildWaveSpawner()` 现有的
   `isBoss` 跳过倍数分支就够用，不会出现"蜂群刷出 10 节列车"。但**只生成 1 行编排**：
   一个 `isBoss` 行 = 一个编组，其余 4 节由 leader 在 `_ready()` 里自己生成。
   > ⚠️ 千万别写成 `number: 5` —— 那会让 5 个编组各自铺开一列，场上出现 25 节车厢。
2. **`finish()` 结算**：判据是"队列空 + 场上无敌人"。5 节都是真 `Enemy`，
   死光 / 漏光之后场上自然干净，不需要特判。反过来说 ——
   **只要还有任何一节活着，这一波就不会结算**，这是大 boss 应有的黏度，不改。
3. **同屏上限**：5 节占 5 个名额（无尽模式上限 90）。本模块**不召唤**小兵，
   与 §19.7 第 10 条那条约束无关；但如果以后给列车加"甩车厢"技能，要按巢母那条查上限。
4. **漏怪扣血是分批的**：5 节依次到达基地 = 2 点 × 到达次数。中途玩家还有救，
   不会出现"一次失误直接 10 点没了"的不可读结算。全漏 10 点 = 基地 20 血的一半，
   与 §19.7 第 5 条"boss 逃跑代价要大"一致，但没有越过"一次致命"的红线。
5. **塔会把火力摊在 5 个目标上**：这是机制，不是 bug，不要给塔加"只打 leader"的特殊索敌。
   真想让塔集中，用 §二十一 B（目标优先级）里加"列车最近车厢优先"这类**通用**策略，
   而不是为这个 boss 单开一条分支。
6. **成就计数**：`boss_slayer`（§19.7 第 7 条建议，**目前还没实现**）将来落地时，
   一列列车只能算 **1 次**，不能算 5 次 —— 判据用"编组全灭"而不是"bossDefeated 信号次数"。
7. **倍速 / 挑战模式**：conductor 计时全走 `_physics_process`，2X 自动跟随（与 §二十 交叉冲突表口径一致）；
   挑战模式不计成就（§17.6）。

### 25.10 验收探针

**编组**

- 生成后场上恰好 **5 节**、相邻 `progress` 差 = `CAR_SPACING`、全部 `progress >= 0`
- 蜂群模式下仍然 5 节（不是 25 节）
- 打爆中间那节 → 其后车厢 `progress` 各 **增加一个** `CAR_SPACING`、其前车厢**不变**、leader `progress` **不变**
- 打爆 leader → 第 2 节成为 leader，整列位置不跳
- 打爆尾车 → 没有任何车厢移动
- 5 节 `speed` 任一帧都相同（断言 `cars[i].speed == cars[j].speed`）

**减速（对应 25.7 第 1 条）**

- 只让 1 节进 EMP → **5 节同时变慢且幅度相同**；离开后 5 节都精确回到 `teamBaseSpeed`
- 二阶段后 `addSlow` → 5 节 `speed` 一律不变（全队免疫）

**数值与结算**

- 合成血条 = `Σhp / ΣmaxHp`，打爆任意一节 **不删行**，只剩最后一节时仍显示
- 每节物理伤害被 `armor 0.3` 砍 30%；`hurt(..., "energy")` 打满额（沿用铁壁那条通道）
- 每节漏怪各扣基地 2 点；漏 3 节 = 6 点
- 只有车厢3 死亡给 3 宝石，其余 4 节 `gemReward == 0`
- 金币合计 = 300 × `modeRewardScale`（每节 60，与要塞同档）

**二阶段与终爆**

- 合成血量跨过 50% → 编组 `speed ×1.3`、免疫减速开、炮塔间隔 ÷1.4，**各只发生一次**
- 最后一节死亡 → `bomb` 实例出现、`blastRadius==220`、`targetMask==1<<0`、
  220 内的塔掉血 ≈ 60、**场上不出现第二套爆炸特效**
- 打爆非最后一节 → **不爆炸**
- 全灭后 `finish()` 正常结算（不卡在"场上无敌人"判定）

**回归**

- 现有 7 种 boss 顶部血条行为逐帧不变（`barProvider` 分支只对列车生效）
- 要塞（`bigBossType` 未改成列车的关卡）不受任何影响

### 25.11 分阶段

| 阶段 | 内容 | 成本 |
|---|---|---|
| M1 | `bossTrain` 兵种登记 + 车厢场景 + conductor（生成 5 节 / 槽位 / 起点铺开） | ✅ 已完成 |
| M2 | 死亡压缩 + 全队共享减速表（25.7 第 1、2 条） | ✅ 已完成（含"每节单独扣血"的实弹验证） |
| M3 | 合成血条 + 5 段车厢格 + `barProvider` 分支（含 25.8 那条删行判据） | M |
| M4 | 二阶段狂暴 + 车厢3 宝石 + 全灭爆炸 + i18n + 测试场景入口 | S |
| M5 | 挂进第 9 关 `bigBossType` + 平衡（**依赖 §19.9 的 M5：关卡 Boss 配置字段本身还没落过地**） | S |

> ⚠️ M5 的前置：`StageData` 里 `bossWave` / `bossHpMul` / `bigBossType` 四个字段
> 到现在一个都没配过（§19.11「Boss 还没挂进关卡」）。列车是**第二种**要挂进关卡的 boss，
> 别为它单独发明一套关卡配置写法 —— 先按 §19.5 把那四个字段落一次地，要塞和列车一起挂。

**成本 M~L / 风险 中**
风险集中在三处：全队共享减速（25.7 第 1 条）、血条行生命周期（25.8 ⚠️ 那条）、
以及"一列 = 5 个敌人实例"对波次结算与同屏上限的影响。三处都有现成模板可抄，
不涉及任何既有系统的重写。

### 25.12 与其他模块的关系

| 关联 | 说明 |
|---|---|
| §十九 Boss | 兑现 19.5「第二种大 boss 只需换 `bigBossType`」；`bossAuraColor` / `bossTier` / `bossTip` / `silentBoss` 全部复用；§19.7 第 6 条为车厢头顶血条**开一条有意破例** |
| §十九 要塞 | 总血、金币、经验、宝石四项**逐条对齐**（3000/300/120/3）—— 它是同档次的另一种形状，不是更强的 boss |
| §二十四 T 督战指挥车 | 都涉及"多个单位互相影响"，但方向相反：T 是**敌内**增益（别让火力摊薄），列车是**敌内**摊薄（逼你排顺序）。可以同关投放，读图负担要注意 |
| §二十一 D 精英词缀 | 词缀**不应**作用于车厢（5 节各 roll 一次会出现"三节带护盾的列车"这种极端值）；要加就加在整列一个层级 |
| §二十一 B 目标优先级 | 25.9 第 5 条指定的正解入口 |
| §十七 战斗模式 | 吃 `modeHpScale` / `modeSpeedScale`（它就是个敌人），**不吃 `countScale`** |
| 实验坦克 4 炮塔 | 同一批零件（`base_turret.tscn`），区别是"一个身体挂 4 炮"vs"5 个身体各挂 1 炮" |

---

### 25.13 已实现部分（M1~M2，2026-11-12）

#### 文件清单

| 文件 | 作用 |
|---|---|
| `script/enemy/boss/train_conductor.gd` | 编组控制器（**挂在 level 节点下**）：铺 5 节、槽位、起点铺开、死亡收拢、全队共享减速表、编组自我释放 |
| `script/enemy/boss/boss_train.gd` | 车厢：`extends enemy.gd`（**不是** `boss.gd`，见 25.7 第 3 条）；头节建编组、跟随节按 `trainGroupId` 归队；`addSlow`/`removeSlow` 转发编组；`hurt` 死后上报收拢 |
| `scene/enemy/boss/boss_train.tscn` | 车厢场景（占位美术：`armored_tank_v2_body_*` × `scale(1.3, 0.95)` + `modulate (0.74,0.78,0.84)` + 一座 `BaseTurret`） |
| `script/test/train_boss_probe.gd` + `scene/test/train_boss_probe.tscn` | M1~M2 探针（33 项断言，headless） |
| `game.gd` | `enemyType` 末尾追加 `bossTrain`（枚举值 19）；`enemyInfo` 一条数值（每节 600/0.3/26/60金/24经验/漏2，`gemReward 0`） |
| `stageData.gd::enemyScenes` | 登记车厢场景（**仍未配到任何关卡**，与 §19.11 同状态） |
| `lang/language.csv` | `_BossName_train` / `_BossTip_train`（en + zh） |
| `script/test/boss_test.gd::BOSS_ENTRIES` | 加一条，测试场景里能单独刷一列火车 |

炮塔数值在**场景 Inspector**里（与实验坦克同一套约定）：`atk 10`、`shootDelay 1.6`、
`radarScope 260`、`rotationSpeed 8`、`muzzleOffset 18.5` → 单节 DPS 约 6.3，5 节合计约 31。
`.tscn` 里**不能写 `#` 注释**（会让整个场景解析失败，实现时踩过一次：
连带 `preload` 它的 `stageData.gd` 编译失败、`stageData` autoload 直接挂掉，全项目报
"does not inherit from Node"），所以这些数字记录在这里而不是场景里。

#### 探针结果（33 项全过）

```
G1  exactly 5 carriages                 G2a/b/c  全部在路线内 + 间距 = CAR_SPACING 72
G3  all carriages on one track          G7   五节同一帧 speed 相同
S1  one carriage in EMP -> all 5 slow   S1b  team speed = base x (1 - strongest)
S2  exact restore to teamBaseSpeed      S3   immuneSlow swallows slows for every carriage
G4a/b/c  中间死：前面不动、后面各收拢一格
G5a/b/c  leader 死：顶上来的那节不跳，整列保持原位
G6  尾车死：谁都不动
G8  蜂群模式仍是一列 5 节（不是 25 节）  G9   modeHpScale 每节照吃
G11a/b/c 漏两节 = 两次独立逃脱结算 = 4 点伤害，剩下 3 节继续跑
G10a/b  全灭后场上无车厢 + 编组自我释放
```

跑法：

```
f:/Godot_v4.7.1-stable_win64.exe --headless --path machine-td \
  --quit-after 20000 res://scene/test/train_boss_probe.tscn
```

回归：`tower_quota_probe`（15/15）与 `all_levels_check`（bad=0）都重跑过，
现有 7 种 boss 与关卡编排不受影响。

#### 实现时发现的三处偏差（已回写进 25.7 的精神，但细节不同）

1. **头节会被关卡的自动车道劈出去**：`base_level.gd::resolveOffset()` 给没写 `offset`
   的兵种按类型自动分配 ±4px 左右车道，于是**跟随节（显式写 0）在中心线上、
   头节偏 4px** —— 一列歪车。修法两头都要下：跟随节的 `spawnInfo` 显式写 `"offset": 0.0`，
   conductor 在 `setup()` 里把头节的 `wrapper.v_offset` 强制归 0。
   （探针 G3 现在专门盯这条。）
2. **逃脱不走 `hurt()`，所以不会有 `onCarDied`**：`enemy.gd::_physics_process` 到达终点时
   直接 `freeSelf()`，既不置 `dead` 也不发死亡信号。conductor 除了"死时压缩"，
   还要在 `_process` 里 `pruneDead()` 收失效条目 —— 否则漏光一列火车后编组会一直不释放，
   也就永远占着一个 `groups` 条目。测试场景的「清空 Boss」是第三条路径（直接 `freeSelf`），
   同样靠这条兜住。
3. **探针必须量"到锚点的间距"，不能量绝对 progress**：两次快照之间整列一直在前进
   （3 帧约 3px），绝对位移里混着这段路，`CAR_SPACING` 会被测成 75。
   间距里的前进量相互抵消，判据才与测量时机无关。

#### 还没做的（M3 起）

- **顶部血条现在显示的是头节自己的 600 血**，不是 5 节的合成血量 —— 这是 M3 的
  `barProvider` 分支要改的第一件事（25.8）。也就是说**当前血条会"骗人"**：
  打死中间那节，条子纹丝不动。测试时别把它当成 bug 报。
- 二阶段狂暴 / 车厢3 宝石 / 全灭爆炸（M4，`immuneSlow` 开关已就位并被 S3 验过）
- 挂进第 9 关（M5，依赖 §19.9 的 Boss 关卡配置字段先落地）
- **未做视觉确认**：本轮全部结论来自 headless 探针，没有在编辑器里真跑过一局看
  占位贴图的比例、光环叠起来好不好认、五节车厢在弯道上贴不贴。

---

## 二十六、国际化扩语种（字体链与探针）

> **实现状态：🟡 M0 完成 + 已实装 3 个语种（`zh_TW` / `ja` / `ru`，2026-11-12）**
>
> `ko` / `th` / `vi` **故意还没加** —— 主字体对谚文/泰文/越南变音符是 0 覆盖（26.2 实测），
> 现在登记进下拉只是给玩家一个"切过去看豆腐块"的按钮。等 M1 放字体。
>
> 需求原话：「帮我分析游戏现在的国际化还需要增加几个，应该上架 steam 肯定需要这个，
> 我打算先加亚洲一些国家语言」→「先做第 0 步，把字体链和探针搞出来」
>
> 第 0 步的定义：**不加任何语种**，先把"加语种必然踩的坑"变成机器能检查的东西。
> 理由很直接 —— 三类最常见的事故（忘了登记、忘了重导、缺字形）
> **在开发者机器上全都表现为"一切正常"**，只有玩家的截图里才会出问题。

### 26.1 现状盘点（审计数字，2026-11-12 实测）

| 项 | 实测 | 含义 |
|---|---|---|
| 语种 | `en` / `zh` 两列，[game.gd:607](file:///F:/machine-TD/machine-td/autoload/game.gd#L607) 硬编码 | 语言下拉只有两项是因为 `Game.language` 只有两项 |
| 词条 | **304 个 key**（`lang/language.csv`） | 加一个语种 = 填 304 格 |
| 结构健康度 | 空值 **0**、重复 key **0**、每行列数一致、23 个含 `%d/%s` 的 key **各列占位符完全一致** | **没有技术债**，加语种是"加列"而不是"补债" |
| 长度特征 | en 均 27 字符 / zh 均 9.5；**260/304 条的英文长度 ≥ 中文两倍** | 现有布局一直是在"最短的中文"和"较长的英文"之间过的，韩文/泰文会更长 |
| 手工断行 | 全表只有 `_About_Text` 用了 `\n`（共 8 处转义） | 担心的"逐语种手工断行"负担基本不存在（26.6 实测证实：那是 `RichTextLabel` + `autowrap=WORD_SMART`，自己会折行） |
| 登记面 | **四处必须同步**：CSV 列 ↔ `Game.language` ↔ `project.godot:93 locale/translations` ↔ `lang/language.<code>.translation` | 第 0 步之前**没有任何东西检查这四处**，全靠人记 |
| 运行时链路 | `userData.gd:86-90` 启动判定 + `saveSettings` 持久化到 `user_settings.cfg`；`setting.gd:15-25` 填下拉、`:72-76` 切换 | 链路本身干净，不用动 |

### 26.2 真正的地基问题：全项目只有一个字体

唯一的字体是 `font/AlibabaPuHuiTi-3-85-Bold.ttf`（`theme/theme.tres:22` 的 `default_font`，
23 个场景各自挂这份 theme）。用 fontTools 与 Godot `Font.has_char()` **双向核对**的实测结果：

| 目标文字 | 主字体覆盖 | 结论 |
|---|---|---|
| CJK 统一表意文字 | **20976 / 20992（100%）**、Ext-A 6582/6592 | 繁体中文**几乎免费**（代价只是字形按大陆规范设计） |
| 西里尔字母 | 100% | 俄语免费（不在"亚洲"但顺带记一笔） |
| 假名（日语） | 184 / 192，缺的都是死码位，**但缺 `・` U+30FB 与 `々` U+3005** | 日文 UI 高频字符，要么补字体要么改文案 |
|谚文（韩语） | **0 / 11172**（Jamo 也是 0） | ❌ **必须自带字体** |
| 泰文 | **0 / 128**（辅音、上置元音、声调全缺） | ❌ **必须自带字体 + 排版改造**（见 26.6） |
| 越南语变音符 | Latin Extended Additional **4 / 256**（`ư ộ ề ễ` 全缺） | ❌ **必须自带字体** |

> ⚠️ **`allow_system_fallback=true` 是上架前最危险的开关**
> （`AlibabaPuHuiTi-3-85-Bold.ttf.import:22`）。缺字目前**靠玩家操作系统兜底**：
> Windows 会给韩文/泰文补字形，本机怎么测都"正常"；
> Steam Deck / Linux（fontconfig）或精简系统的玩家看到的是豆腐块。
> 这类 bug **在开发者机器上永远复现不出来**，所以必须用字形覆盖检查来防，而不是靠眼睛。

**顺手抓到一个现存 bug**：`_TutorialGuide4` 中英两列都用了 `▶`（U+25B6），主字体没有这个字形。
已改成文字描述（en "Tap the Play button…" / zh「点『播放』按钮开始出怪」）——
**改文案而不是加字体**，因为那个按钮本身是贴图图标，文字里引用一个符号本来就是多余表达。

### 26.3 字体回退链：装配在代码，不装配在 `.import`

新增 [autoload/fontStack.gd](file:///F:/machine-TD/machine-td/autoload/fontStack.gd)，
在 `project.godot` 的 autoload 里注册于 **UserData 之后**（比任何场景早，语种切换不受影响）：

- 启动时把 `res://font/fallback/` 目录里的 `.ttf/.otf/.woff/.woff2` 按**文件名排序**
  装进主字体的 `fallbacks` 链。
- **文件名前缀 = 优先级**（`01_NotoSansKR.otf`、`02_NotoSansThai.ttf`…）。
  同一个码位（`・` 就是典型）在 JP 与 KR 字体里都有时，先命中的那个决定字形风格 ——
  所以顺序必须可控，不能靠字母序。
- **只装链不下载字体**：目录为空时什么都不做，行为与本步改动前逐帧一致。
- **合并而不是覆盖**（本轮修掉的一个真 bug）：初版 `apply()` 是 `baseFont.fallbacks = 目录扫到的链`，等于每次启动把 `.ttf.import` / 主题 `FontVariation` 里配好的回退**抹掉**；现在先把"不是自己放进去的"留下，再追加目录里的，同一实体不重复入链（由 C5f/C5g 守着）。
- 加载失败必须 `push_warning`：否则链会**静默少一层**，缺字照样掉给系统兜底，
  而探针看着还是绿的（这是"检查器骗人"的一种）。
- `fontChain()` / `hasGlyphAcrossChain()` / `providerOf()` 给探针用。
  **实测语义（2026-11-12，纠正本节早期写法）**：
  · `Font.has_char()` **会顺着 `fallbacks` 往下找** —— 链清空时 `has_char(한)=false`，
    把韩文字体挂上就变 `true`。（先前记成"只查自己、必须手工遍历"是**错的**。）
  · 真实排版也走链：关掉 `allow_system_fallback` 后，
    `get_string_size("한국어")` 从 **108.0 → 120.0**（每字 36 的豆腐块换成 40 的真字形）。
  · 但 `has_char()` **不认系统兜底** —— 开着兜底时缺字照样被 OS 画出来（本机看着正常），
    `has_char` 仍然报 false。所以它恰好是"**我们自己打包的字体够不够**"的正确问法，
    探针 C6/C7 因此天然不受本机装了什么字体影响。

### 26.3b 回退链到底能配在几个地方（用户问"主题里能不能配 fallback"的完整答案）

实测四个位置，结论是：**`Theme` 本身没有 fallback 概念，fallback 挂在字体资源上**。

| 可配点 | 能不能生效 | 能不能提交 / 进包 | 说明 |
|---|---|---|---|
| `Theme`（`theme.tres`）上配 fallback | ❌ 没有这个字段 | —— | Theme 只有字体槽（`default_font`、每类控件的 `font`），**换字体不是补字形**：给 `Label` 整槽换成 NotoSansKR，Latin 与 CJK 也会一起换，不是"缺字时才借" |
| 主字体的 `.ttf.import` → `fallbacks=[]` | ✅ 编辑器 Import 面板可配 | ⚠️ **本机专属**：本仓库 `*.import` 被 gitignore（`.gitignore:18`，`git ls-files` 里 `.import` 计数为 **0**） | 手写该字段两种写法都被拒：填路径字符串报 `Unable to convert array index 0 from "String" to "Object"`；补 `[ext_resource]` 头报 `Resource file not found: res://1_fbkr`，随后 Godot 重新导入**把 `fallbacks` 重置回 `[]`** |
| 主题引用一个 **`FontVariation` .tres**（`base_font` = 主字体，`fallbacks` = […]） | ✅ 实测 `has_char` 与排版都走它 | ✅ `.tres` 进版本库、进导出包 | 这是"在主题里配 fallback"的**正解形态**：把 `theme.tres:22` 的 `default_font` 指向这个 .tres |
| `autoload/fontStack.gd` 运行时装配 | ✅ | ✅ `.gd` 进版本库、进包 | 本项目的选择：目录自动发现，加语种不用碰编辑器 |

两条实测细节值得记：

- `theme.tres` 里 `default_font` 引用的对象与 `load("res://font/…ttf")` 拿到的是**同一个实例**
  → 改一次，23 个挂这份主题的场景全部生效（这也是 runtime 方案能成立的根）。
- 配在 `FontVariation` 上的链与配在主字体上的链**互不覆盖、可以并存**
  （只给包装层配 → 包装层 `true`、主字体 `false`；只给主字体配 → 两层都 `true`）。
  所以 `fontStack` 改成**合并不覆盖**之后，三种配法同时用也不会互相抹掉。

> 另记一条对 M1 之后有用的开关：`allow_system_fallback` 是 `FontFile` 上的**运行时属性**
> （不只导入设置）。字体配齐后把它关掉，缺字就从"本机正常、别人豆腐块"变成
> **所有人都立刻看见的显式故障**。现在不动它，是因为 M1 还没做。

### 26.4 探针 `i18n_probe`（50 项断言；M0 落地时 27 项，加三个语种后扩到 50）

`script/test/i18n_probe.gd` + `scene/test/i18n_probe.tscn`（`export_presets.cfg:13` 的
`exclude_filter` 已经把 `scene/test/*` 挡在包里）。

| 组 | 查什么 | 抓的是哪类事故 |
|---|---|---|
| **C1** 结构 | 每行一格一列、无空 key 行、无空值、key 不重复、key 数合理 | 手工编辑 CSV 最容易碰坏引号/逗号 |
| **C2** 登记同步 | CSV 列 ⇄ `Game.language` ⇄ `project.godot` ⇄ 编译产物存在 | **加了列忘了登记** → 下拉里没有它；**有登记没有列** → 切过去全是 key |
| **C3** 占位符 | 每行各列的 `%d/%s/%f` 集合必须相同 | 漏了 `%d` 会让 `format()` 直接报错或显示成残缺句 |
| **C4a** 检测器自检 | 不存在的 key 必须**原样返回** | 保证 C4b 的"等于 key 就算缺"判据不是空的（4.7 的 `TranslationServer` **没有 `has_key`**，只能这么判） |
| **C4b/c** 运行时 | 每个语种每个 key 都取得到，**且取到的文本与 CSV 逐条一致** | 只查"key 在不在"抓不到**"改了 CSV 但没跑 `--import`"** —— 旧 `.translation` 里 key 也在，只是文案是旧的。比对前先还原 `\n/\t/\"` 转义（导入器开了 `unescape_translations=true`），否则 `_About_Text` 会误报 |
| **C5** 链装配 | 链长 = 1 + 目录里字体数、主字体能画 CJK、**私用区 U+E000 必须判缺** | 后一条是覆盖检查器的**反向自检**：用一个永远不该有的码位证明 `has_char` 真的会返回 false |
| **C5f/g** 合并语义 | 临时往链上塞一个外部字体再跑 `apply()`，它必须**还在链里**且链不重复 | 抓装配写成**覆盖而不是合并** —— 症状是"编辑器里配好的回退一进游戏就没了"，只有运行时能复现。⚠️ 哨兵必须是空 `FontFile`：拿 `FontVariation(base_font=主字体)` 当哨兵会构成**引用环，直接把进程问崩**（实测踩过） |
| **C6** 字形覆盖 | 每个语种、每个字符，在**整条链**里能不能画出来；失败时打印 `U+XXXX ×出现次数 in key` | 豆腐块本体 |
| **C7** 语种↔文字 | 按 locale code 查一组**代表性码位**（`ko` 查 `가 한 ㄱ`、`th` 查 `ก ั า`…） | **"先登记语种、后补字体、文案还没翻"** —— 那一刻 CSV 里没有该语种的文字，C6 全绿，但下拉里已经有了「한국어」 |
| **C8** 语种判定 | 纯函数 `_languageFromLocaleString()` 喂 10 组 locale（`zh_CN/zh_TW/zh_HK/zh_MO/ja_JP/ru_RU/en_US/de_DE/fr_FR/ko_KR`） | ① 繁体区被当简体；② 判定出来的 code 没登记（`set_locale` 切到一个没有译文的语言）；③ 未知语种没回 `en`（与 `Game.t()` 的兜底不一致 → 混排） |
| **C9** 主菜单宽度 | **装真实场景量真实控件**：逐个按钮比 `get_combined_minimum_size().x` 与它实际拿到的宽度 | 截断本体。三个前提写在函数注释里：locale 必须 `add_child` 之后设（setting.gd 会盖）、`text` 摘下再装回去（min size 有缓存）、不比字符数（按钮带图标 + 西里尔字母宽度只有字号的一半） |
| **C10** 语言下拉 | 装满 `Game.language` 后最坏需求 vs 可用宽度 | 语种名**不走翻译键**（玩家要用自己的字选回去），所以 C1~C9 都盖不到它 —— 这条同时把"240 是上限"那个错误判断钉死 |
| **C11** 对账 | 每个检查组进 `_ran`，末尾与 `EXPECTED_CHECKS` 比 | 我编辑 `_ready` 时把 C9/C10 挤到了 `quit()` 后面，探针照样报 `fails=0` —— **全绿不等于跑了** |

> C7 需要单独存在的原因值得记下来：**C6 是"用到的字"的检查，C7 是"这个语种该能写"的检查**。
> 加语种的真实顺序总是先让语种出现在下拉里、再放字体、最后才翻译，
> 所以在 C6 还是空集的时候，只有 C7 会响。

**正反两轮演练（探针的自我证明，2026-11-12）**
临时给 CSV 加了一整列 `ko`（304 格韩文），并用系统里的 `malgun.ttf` 冒充回退字体
—— **仅本地验证，绝不提交，也不是合法的分发方案**：

```
放字体：C5c chain=2  C6 locale ko PASS  C7 locale ko PASS
        同时 C2a / C2c / C3 / C4c 如期 FAIL（没登记、没 project.godot、没翻译、占位符缺失）
撤字体：C6 locale ko FAIL —— "U+C11C x304 in _appName | U+BCF4 x304 in _appName"
        C7 locale ko FAIL —— missing ["U+AC00", "U+D55C", "U+3131"]
清理后：25/25 绿；train_boss_probe 33/33、tower_quota_probe 15/15 回归不变
```

### 26.5 语种清单与实装状态

| 批次 | 语种 | 状态 | 理由 | 成本实测 |
|---|---|---|---|---|
| 第一批 | `zh_TW` 繁體中文 | ✅ **已实装** | 台港澳付费重镇，字体零成本（CJK 20976/20992） | 304 格简转繁；控件宽度与简体基本同（主菜单最坏 269 vs 269） |
| 第一批 | `ja` 日本語 | ✅ **已实装** | Steam 亚洲区收入密度最高 | 304 格；**必须避开 `々・`**（字体没有）→ 文案改用「次から次へと」「／」，探针 C6 逐字守 |
| 顺带 | `ru` Русский | ✅ **已实装** | 不在"亚洲"，但西里尔**满覆盖 = 零字体成本**，性价比高于泰/越 | 304 格；文本普遍比英文长，26.6 的宽度实测就是为它加的 |
| 第二批 | `ko` 한국어 | ⬜ **等 M1 字体** | 付费习惯好 | 304 格 + `01_NotoSansKR`；谚文 0/11172 |
| 第二批 | `vi` Tiếng Việt | ⬜ **等 M1 字体** | 增长快、盘子中等 | 304 格 + `04_NotoSans`（补变音符） |
| 第二批 | `th` ไทย | ⬜ **等 M1 字体 + 排版** | 盘子最小、成本最高 | 304 格 + `02_NotoSansThai`；泰文无词间空格（26.6 #8） |

**取舍讲清楚**：`th` 排最后是它同时吃"新字体 + 换行机制改造 + 最小付费盘"三项，
而 `ko/ja/zh_TW` 三个就能把亚洲主力付费区覆盖完（+ 现有 en/zh = 5 语种）。
另外若愿意把范围从"亚洲"放宽：`ru`（西里尔已满覆盖，**字体零成本**）、
`pt-BR/es` 的销量通常高于 `th/vi`。

### 26.6 布局风险清单（先按写死的宽度估，再按真实控件实测 —— 有两条被推翻）

| # | 位置 | 问题 |
|---|---|---|
| 1 | `scene/achievement_toast.tscn:26` 面板 `440×140` + `clip_text` + 省略号 | ❌ **实测不成立**（2026-11-12 加 `ru` 后逐条量过 25 条成就文案）：根节点是 `PanelContainer`，`440` 是**下限**，长文本只会把弹条撑宽；而 `achievement_toast.gd:77-83` 停靠位是用 `max(size.x, custom_minimum_size.x)` 算的，**跟着自己的宽度重算位置**，所以既不会截断也不会滑出屏外 |
| 2 | `script/ui/wave_banner.gd:14` 敌人名单单行 HBox、**不换行**、4 空格分隔 | ⚠️ **实测仍在悬崖边，而且是存量问题**：8 个名字全排 en 需要 1955 > band 1920（英文本来就已越界），ru 2133；只排 5 个时 ru 1404 ✔。加 `ko` 之前必须先解决（缩字号或允许两行） |
| 3 | `scene/welcome.tscn:110` 主菜单按钮列硬框 **356px** | ✅ **已修**：实测按钮带图标后 `get_combined_minimum_size()` 是 en 379 / ja 388 / ru 411 —— **英文本来就被截断**。列宽改成 420，五语种最坏 411 ✔。常驻断言 = 探针 C9 |
| 4 | `script/ui/result_screen.gd:69` 战报表列宽 `[300,90,120,90]` | ⚠️ **同一条老毛病**：那组数是按单元格**最小宽度**下发的，塔名变长时列会自己加宽。**但没实测过结算界面**（要打到通关才有内容），留作 M2 的人工核对项 |
| 5 | `scene/pause_menu.tscn:57` 四按钮 `220×54` 固定宽高 | ❌ **我判断错了**：`220` 是下限，面板 `offset ±250` = 500 宽，实测最宽的 ru 按钮需要 346 ✔ 放得下。真要留意的是**高度** —— 目前没有任何一处会折行，所以也不会出问题 |
| 6 | `scene/setting.tscn:93` 语言下拉 `240×56` | ❌ **我这条判断错了**：240 是 `custom_minimum_size`，是**下限不是上限**。实测装满 5 个语种名只需要 215（`Русский` 163），控件自己会长，父面板 968 宽 → 不截断。常驻断言 = 探针 C10，真被顶破时它会红 |
| 7 | `script/menu/level_card.gd:35` 按**字符数**选字号（80/58/34） | 这套逻辑是给数字设计的，别喂译文 |
| 8 | 全项目 **27 处** `AUTOWRAP_WORD_SMART`（17 处在场景、10 处在脚本） | **泰文没有词间空格** → 只能靠"词太长硬切"的兜底，切在音节中间 |
| 9 | `theme.tres` 由 23 个场景各自挂（`project.godot` 没有全局 `gui/theme/custom`） | 漏挂的控件用引擎默认字体 —— **字体链覆盖不到它们**，会出现同屏两种字形混排 |

### 26.7 已知会咬人的存量问题（不是本轮引入，但加语种时会爆）

1. ~~`userData.gd:89` 的 `OS.get_locale().begins_with("zh")` 把繁体区判成简体~~
   → ✅ **已修**（2026-11-12 加 `zh_TW` 时一起）：新增 `detectLanguageFromSystem()` +
   `SYSTEM_LANGUAGE_ALIASES`（`zh_TW/zh_HK/zh_MO/zh_Hant*` 一律走繁体），
   匹配顺序是**地区别名精确表 → 带地区的 code 精确匹配 → 语言前缀回落 → `en`**；
   `loadSettings()` 里 schema 迁移那段原来硬写 `begins_with("zh") → "zh"`，也改成复用同一个判定，
   否则老存档的繁体玩家会被"迁移"回简体。规则拆成纯函数 `_languageFromLocaleString(locale)`
   是因为 `OS` 单例桩不掉 —— 探针 C8 直接喂 10 组 locale 字符串测它。
2. 硬编码中文残留：`scene/result_screen.tscn:90`、`scene/ui/early_call_panel.tscn:47,53,60`
   的初值文案，以及 `script/ui/early_call_panel.gd:28-37`、`script/map.gd:600` 的中文
   `fallback` 实参 —— 运行时会被 `Game.t()` 覆盖，但**非中文语种**在刷新前会闪一下中文。
   全项目其他地方的 `fallback` 都是英文，这两处是例外。
3. Steam 侧还有一半工作量**不在这个仓库里**：商店页每语种要单独填标题/短描述/长描述/标签
   （约 1.5~2 千字一语种，与游戏内 304 条是两个口径），后台勾选的 Languages
   必须与实装严格一致（勾了 `Thai` 而游戏里没有是能被退材料的风险项），区域定价另算。

### 26.8 分阶段

| 阶段 | 内容 | 状态 |
|---|---|---|
| M0 | 字体回退链（合并语义）+ `i18n_probe` + 修 `▶` + 清 CSV 行间空行 | ✅ 完成 |
| M1 | 下载并投放 4 个 OFL 字体（`font/fallback/` 已备好目录与说明）→ 解锁 `ko` / `th` / `vi` | ⬜ 待做（**当前机器无外网，做不到**） |
| M2 | 布局改造：26.6 剩下的真项 **#2 波次横幅（唯一有实测数字支撑的）**、**#4 结算战报表**（还没实测）、#7、#8（泰文才需要）、**#9 全局 theme** | ⬜ 待做 |
| M3a | 加 `zh_TW` / `ja` / `ru` 三列（字体安全的那些）+ 语种判定表 + 主菜单列宽 420 | ✅ **完成**，`i18n_probe` 50 项全过（见 26.9） |
| M3b | 加 `ko`（等 M1 字体）；`ru` 已顺带做完 | ⬜ 待 M1 |
| M4 | 泰文换行（第 8 项）+ 加 `vi` / `th` | ⬜ 待做 |
| M5 | Steam 商店文案 + 后台 Languages + 区域定价 | ⬜ 待做 |

> 每一批做完都能单独发：**M0 已经把"加了语种但坏了没人知道"这条路堵住了**，
> 之后任何一次加列都会在探针里当场报出缺哪一步，不会拖到玩家截图。

### 26.9 M3a 实装记录：`zh_TW` / `ja` / `ru`（2026-11-12）

#### 动了什么

| 文件 | 内容 |
|---|---|
| `lang/language.csv` | **只追加 3 列**（`zh_TW` / `ja` / `ru`），`Keys`/`en`/`zh` 三列**逐字未改**（脚本对比过：`[r[1] for r in old]==[r[1] for r in new]` 为真） |
| `autoload/game.gd:607` | `Game.language` 从 2 条到 5 条（`繁體中文` / `日本語` / `Русский`）—— 语言下拉、切换、持久化全部数据驱动，`setting.gd` 一行没改 |
| `autoload/userData.gd` | 新增 `SYSTEM_LANGUAGE_ALIASES` + `detectLanguageFromSystem()` + 纯函数 `_languageFromLocaleString()`；`loadSettings()` 的 schema 迁移改成复用同一判定（原来硬写 `begins_with("zh") → "zh"`，会把繁体老玩家迁回简体） |
| `project.godot:94` | `locale/translations` 补 3 个 `.translation`（**Godot 不会自动加**，实测手写 `--import` 后仍要手动补这一行） |
| `scene/welcome.tscn:110` | 主菜单按钮列 `792..1148`(356) → `760..1180`(420)，中心仍是 970，`btn_normal.tres` 是 StyleBoxFlat（矢量），拉宽不失真 |
| `script/test/merge_locales.py` | 加列工具（预检 → 干跑 → `--write`），放在 `script/test/` 里：`export_presets.cfg:13` 的 `exclude_filter` 让它不进包，但进版本库 |
| `script/test/i18n_probe.gd` | 新增 C8 语种判定、C9 主菜单实测宽度、C10 下拉框、C11 检查项对账 |

#### 实测宽度（关掉 `allow_system_fallback` 后量，主菜单列可用 420）

| 语种 | 最坏按钮需要 | 结果 |
|---|---|---|
| en | 379（`Endless Mode`） | **改之前是 356 → 英文本来就一直在被截断** |
| zh / zh_TW | 269 | 一直 OK |
| ja | 388（`チュートリアル` / `ゲームスタート`） | 356 时会截断，420 后 OK |
| ru | 411（`Энциклопедия`） | 420 OK |

为放得下做的三处**短译**（不是硬约束让步，是本来就该短）：
`_Endless[ru]` «Бесконечный режим»→«Бесконечный»、`_Codex[ru]` «Энциклопедия юнитов»→«Энциклопедия»、
`_Endless[ja]` «エンドレスモード»→«エンドレス»。

#### 四条只有实测才知道的事

1. **`240 / 220` 这类是 `custom_minimum_size`，是下限不是上限** ——
   我把 §26.6 的 #5 #6 两条判断推翻了（下拉装满 5 个语种名只需 215，父面板 968 宽）。
   真会截断的只有**固定 offset 摆出来的容器**（主菜单列就是）。
2. **量宽度必须用 `get_combined_minimum_size()`，不能用"字符数 × 字号"** ——
   按钮带图标；而且一个汉字 39px、一个西里尔字母平均 ~20px，估算会把俄语算短一半。
3. **两个必须绕开的时序坑**：① `welcome.tscn` 内嵌 setting 面板，
   `setting.gd:44` 在 `_ready()` 里 `set_locale(UserData.language)` —— locale 只能在
   `add_child` **之后**设，否则被盖回去（我第一次量出来五个语种数字全一样就是这个原因）；
   ② 只 `set_locale` 不会让已布局控件重算最小尺寸（绘制走 `atr()`，但 min size 是缓存的）——
   必须把 `text` 摘下再装回去。
4. **`@@ DONE fails=0` 不等于检查跑过了** —— 我编辑 `_ready` 时把 C9/C10 挤到 `quit()` 之后，
   探针安静地报了全绿。所以加了 **C11：登记表对账**，每个检查组进 `_ran`，
   最后和 `EXPECTED_CHECKS` 比，漏跑当场红。

#### 探针结果

```
i18n_probe      50 项全过（C1~C7 各语种 ×5、C8 十组 locale 判定、C9 五语种按钮宽度、
                C10 下拉、C11 对账、C5f/C5g 链合并语义）
train_boss_probe 33/33     tower_quota_probe 15/15     all_levels_check bad=0
```

#### 还欠着什么

- **`ko` / `th` / `vi` 没加**，唯一原因是 M1 的字体没放进来（本机无外网）。
  放好 `font/fallback/01_NotoSansKR.otf` 之后，`merge_locales.py --codes ko` +
  `--write` + `--import` + 补 `project.godot` + 补 `Game.language` 五步，
  探针会把漏掉的那一步当场指出来。
- **没有在真机上切过一次语言**：以上全是 headless 结论。
  建议手工验一遍：主菜单切 `Русский`/`日本語` → 六个按钮是否完整、
  设置面板语言下拉、暂停菜单、结算战报表（300px 那列装塔名，§26.6 #4 还没实测）。

#### 一条反复出现的老毛病（这轮我自己错了三次）

这轮我把 `custom_minimum_size` 当成**上限**判断了三次（#1 成就弹条、#5 暂停按钮、#6 语言下拉），
三次都错 —— 它是下限，控件会随内容长大；主菜单列之所以真会截断，
是因为它是**固定 offset 摆出来的绝对布局**（`layout_mode = 0`），那才是硬框。
所以看场景里的数字时必须先问一句：**这是 min size 还是 offset？**

---

