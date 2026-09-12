# Machine-TD 项目现状与缺口分析

> 更新日期：2026-09-12
> 本文档是项目的"体检报告"：已实现什么、缺什么、哪里有设计问题、按什么顺序补。
> 模块级的完整设计（数据结构、集成点、更新日志）见 [feature_design.md](feature_design.md)。
>
> 标注说明：`【实测】`= 已用 Godot 实际运行验证；`【静态】`= 由代码交叉引用扫描得出。

---

## 1. 项目概况

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.7（GL Compatibility） |
| 逻辑分辨率 | 1920 × 1080，`window/stretch/mode = viewport` |
| 网格 | 64 px（`StageData.TileSize`） |
| 规模 | 78 个脚本、66 个场景、12 个关卡场景、9 个 autoload、7 个着色器 |
| 关卡 | 16 个（id 0 教程 + id 1~15），数据在 `autoload/stageData.gd` |
| 存档 | `user://player_settings.cfg`、`user://player_data.cfg` |
| 多语言 | 中 / 英，唯一数据源 `lang/language.csv` |

---

## 2. 当前结构

```
autoload/   Game(数值表+信号) UserData(存档) StageData(关卡数据) TowerUpgradeManager(升级配置)
            AchievementManager(成就) SceneTransition(转场) SoundManage(音效) ExplosionManage EasterEgg
script/     map(关卡总控) base_level(波次/出怪/可建造) tower(塔基类) enemy(敌人基类)
            achievement_tracker(成就记录) + 各塔/各敌人/各 UI 脚本
scene/      level/(12 张地图) ui/(复用组件) + 各类弹窗面板塔敌人子弹
theme/      深色主题 theme.tres + 31 个 StyleBox
shader/     7 个（升级发光 / 雷达 / 成就图标发光 / 成就图标置灰 / 波次进度 / 背景 / 转场）
```

---

## 3. 已实现功能

### 3.1 核心流程

- 主菜单 → 选关 → 战斗（波次 / 出怪 / 建塔 / 结算）→ 星级评定 → 宝石奖励 → 存档
- 关卡解锁与星级记录、重复通关不重复发奖励
- 场景切换黑屏淡入淡出、暂停菜单、失败 / 通关结果弹窗、返回主菜单
- 关卡开场情报面板（敌人种类 / 数量 / 属性预览）

### 3.2 防御塔

- 7 种塔：机枪、加农、火箭、EMP、无人机基地、特斯拉线圈、激光
- 全部从 `Game.towerInfo` 数据驱动：攻击、费用、冷却、射程、血量、初始时间、占地格数
- 1×1 与 2×2 塔的网格占用、放置预览、合法区域检查、出售返还半价
- 塔选中后右侧信息面板（名称 / 等级 / 血量 / 经验 / 属性 / 售价）
- 雷达检测 → 目标选择 → 炮塔转向 → 自动开火
- 3 级升级系统：击杀积累经验自动升级，各塔独立配置
- 开火特效：炮口闪光 + 炮管后坐（机枪 / 加农 / 火箭三座有炮口的塔）
- 无人机基地：3 架无人机沿**塔射程边缘**巡逻（随升级外扩），攻击时绕目标盘旋，带 Line2D 飞行尾迹
- EMP 减速 **确实生效**（`emp_tower.gd` 直连雷达信号并改写 `enemy.speed`），特斯拉链式伤害也**基本完整**（4 目标贪心链、每跳 75% 衰减、`"energy"` 无视护甲）

### 3.3 敌人

- 10 种敌人：迷你坦克、中型坦克、重型坦克、装甲坦克、突击车、维修车、自爆车、导弹车、侦察无人机、攻击直升机
- 全部从 `Game.enemyInfo` 数据驱动（血量 / 速度 / 奖励 / 扣血 / 经验 / 护甲 / 对空 / 攻击力 / 开火间隔 / 雷达半径 / 行为定位）
- 三类行为：推进型、对抗型（直射 / 远程导弹）、支援型（治疗友军）、自爆型
- 雷达半径数据化：由 `enemy.gd::_applyRadarScope()` 统一同步碰撞体，推进型自动关闭侦测
- 护甲物理减伤、能量伤害无视护甲
- 点击敌人查看信息面板（与塔面板互斥复用右侧槽位），敌人死亡 / 逃脱 / 自爆后自动关闭

### 3.4 UI 与主题

- 统一深色主题（浏览器深色风格）：弹窗、按钮、下拉、滑块、滚动条、分隔线、Tooltip 全覆盖
- 地图内的塔 / 敌人面板使用**独立的军事科技风**（深藏青 + 青色描边 + 外发光），与界面弹窗区分
- 主菜单 4 个按钮图标各自配色 + 成就图标悬停发光着色器
- 波次进度条（含关键波节点与悬停提示）、Toast 文本提示、生命条、星级评分

### 3.5 成就与数据

- 9 个成就，分累计型 / 单局型 / 里程碑三类，关卡内记录器挂在 map 场景
- 进度批量落盘（`auto_save=false`），通关 / 离场统一 flush，避免每杀一个敌人写一次盘
- 成就总览面板：图标并排的徽章格 + 悬停详情区 + 已解锁金边 / 未解锁置灰
- 获得成就时从屏幕右侧滑入提示，停留后缓缓滑回消失，多个成就自动排队
- 全部文案走 `lang/language.csv`

---

## 4. 地图与关卡系统专项（当前最大问题）

### 4.1 结论

**地图目前不是"设计得不好看"，而是"大部分关卡根本没有地图"。**
关卡的数据模型里只有一条 `Path2D` 曲线，地形、可建造区、出生点 / 终点都没有纳入其中，
所以每加一关只能靠复制场景 + 手抄一份网格坐标表，直接导致内容缺失和大量重复。

### 4.2 实测证据 【实测】

运行时读取每关 `TileMapLayer` 的实际用格数（`get_used_cells()`）：

| 关卡 | 场景文件 | bg 有 tile_set | bg 格子数 | fg 格子数 | 可建造格数 | Path2D 数 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 教程 | level_tutorial.tscn | ✅ | 135 | 0 | 36 | 1 |
| 1 | level_1.tscn | ✅ | 135 | 7 | **4** | 1 |
| 2 | level_2.tscn | ❌ | **0** | **0** | 36 | 1 |
| 3 | level_3.tscn | ❌ | **0** | **0** | 42 | 1 |
| 5 | level_5.tscn | ❌ | **0** | **0** | 48 | 1 |
| 10 | level_10.tscn | ❌ | **0** | **0** | 33 | 1 |

### 4.3 问题清单

#### ① 9 个关卡没有地形，战斗地图是纯色空屏（严重）【实测】

`level_2.tscn` ~ `level_10.tscn` 没有覆盖 `bg` / `fg` 节点，而 `base_level.tscn` 里的两个 `TileMapLayer`
既没有 `tile_set` 也没有 `tile_map_data`，所以这 9 关运行时 `bg.get_used_cells().size() == 0`，
整屏只有纯色背景 + 调试网格 + HUD。玩家看到的是"一条看不见的路 + 一堆敌人横穿空白屏幕"。

#### ② 6 个关卡共用同一张地图，且那张图只有 4 个可建造格（严重）

`level_1.tscn` 被 **id = 1、11、12、13、14、15 共 6 个关卡**引用（`autoload/stageData.gd:330,365,401,438,476`）。
这 6 关的地形、路线、可建造区完全相同，只有波次数据不同。

雪上加霜的是 `script/level_1.gd:21` 只给了 4 个可建造格：

```gdscript
allowArea.append_array([Vector2i(10,6),Vector2i(11,6),Vector2i(10,7),Vector2i(11,7)])
```

而 `level_1.tscn` 的 Curve2D 只有 2 个点（一条直线）。
于是被 11~15 关沿用的"高压后期关卡"（14~18 波、500~720 金币）**全场只能放 4 座 1×1 塔**；
七种塔里有 3 种是 2×2（无人机基地 / 特斯拉 / 激光），放一座就占满全场 → 这些关不可能凑齐 7 种塔。

#### ③ 可建造区与地形、路径完全脱钩（严重，机制级设计缺陷）

`allowArea` 是每个关卡脚本里**手写的网格坐标数组**，判定只看这个数组：

```gdscript
# base_level.gd:49
func canPlace(coverGrids: Array[Vector2i]) -> bool:
	for i in coverGrids:
		if i not in allowArea: return false     # 完全不知道地形和路径在哪
		if i in occupiedArea: return false
	return true
```

后果：
- 美术改了地图必须手动同步一份坐标表，漏改就会出现"看着是空地却建不了塔"或"看着是路却能建塔"
- **没有任何"不能建在路上"的校验**，塔可以盖在敌人的行军路线上
- 各关数量悬殊：`level_1` 只有 4 格，`level_5` 有 48 格

#### ④ 没有出生点与基地的可视化（中）

12 个关卡场景里除了 `TileMapLayer` / `Path2D` / `Timer` 没有任何节点。
敌人从屏幕左侧外（x ≈ -80）走进来、走到右侧外（x ≈ 1920）就判定"逃脱扣血"，
但地图上既没有出生点标记，也没有基地 / 终点。玩家看不出该守哪里，"基地生命"也失去了画面依托。

#### ⑤ 单路线架构锁死了玩法扩展（中）

```gdscript
# base_level.gd:11
@onready var path1 = get_node_or_null("Path2D")
```

硬编码只取一条路径。直接后果：成就「路线掌控者」（要求"多路线关卡胜利且无敌人逃脱"）
**在当前内容下永远无法达成** —— `map.gd::_is_multi_route_level()` 统计 Path2D 数量，全项目都是 1。
同时也挡住了"多入口 / 分岔路 / 空中独立航线"这类塔防常见设计。

#### ⑥ 调试网格一直开着（轻，但玩家可见）【静态】

```gdscript
# map.gd:29
var debug = true
```

`_draw()` 会绘制整屏 64px 间距的灰色网格线（30 竖 + 17 横），
并在鼠标旁用 **60px 字体**显示当前网格坐标。正式游玩会一直显示。

#### ⑦ 可建造区可视化机制已是死代码（轻）【静态】

`scene/placeable_area.tscn` / `script/placeable_area.gd` 没有任何场景实例化；
`map.gd:389` 遍历 `placeableArea` 组永远拿到空数组。
"可建造区高亮提示"这个曾经的设计已被 §③ 的手写坐标表取代，但没有清理。

### 4.4 根因分析

关卡的数据模型只有"一条路径曲线"这一项：

```
level_X.tscn
├── bg (TileMapLayer)   ← 大多为空
├── fg (TileMapLayer)   ← 大多为空
├── waveTimer / spawnerTimer
├── towerShadow
└── Path2D              ← 唯一真正定义关卡的东西
```

地形、可建造区、出生点、终点**都不在关卡数据里**，于是：
- 每加一关只能复制上一个场景再改曲线
- 可建造区只能另外写在脚本里，和地图天然不同步
- 想做多路线、多基地时没有承载它的数据结构

### 4.5 修复建议（按优先级）

| 优先级 | 事项 | 改动量 |
| --- | --- | --- |
| P0 | `map.gd` 的 `debug` 改为 `false`（或 `OS.is_debug_build()`） | 1 行 |
| P0 | 给 level_2~level_10 补地形；至少先铺一层通用地面，避免纯色空屏 | 美术 |
| P0 | `allowArea` 改为**由 TileMapLayer 推导**：新增 `buildable` 图层，美术在编辑器刷格子，代码取 `get_used_cells()`，删掉各关脚本里的坐标数组 | 中 |
| P1 | 增加"路径占位"判定：采样 `Path2D.curve` 把路径经过的格子标记为不可建造 | 小 |
| P1 | 新增出生点 / 基地节点，把逃脱判定从 `progress_ratio >= 1` 改为"到达基地"，并补基地受击反馈 | 小 |
| P1 | 修 `level_1.gd` 的 4 格可建造区（被 6 个关卡共用，影响面最大） | 小 |
| P1 | `path1` 改为 `paths: Array[Path2D]`，出怪时按权重分配路线 → 解锁多路线关卡与对应成就 | 中 |
| P2 | 为 11~15 关制作独立地图；短期做不出来建议先把关卡数收敛到 10 | 美术 |
| P2 | 删除 `placeable_area` 死代码 | 小 |

---

## 5. 当前明确缺失或未完成的功能

> **2026-09-12 更新：P0 中的 ①②③ 三个「看起来能用、实际没生效」的核心机制已修复并通过实测验证**，
> 详见各项的「✅ 已修复」说明。原始问题描述保留在下方，便于回溯。

### P0：影响核心玩法

#### 1. 敌方远程单位整局只开火一次 —— ✅ 已修复（2026-09-12）【实测/静态】

**原问题**：`scene/enemy.tscn:27` 定义了 `delay` 定时器，但**它的 timeout 从未连接**（该场景唯一的 `[connection]`
是 `:30` 的 `input_event`），全项目 `_on_delay_timeout` 只存在于塔侧（`script/tower.gd:178`）。

而中等坦克 / 导弹车 / 攻击直升机 / 维修车开火后都会：

```gdscript
# mediumTank.gd:22-30（missileTruck / attackHelicopter / medic 同样写法）
if canShot:
	canShot = false
	...
	delayTimer.start()
```

`canShot` 在敌人侧**只被置 false、从来没有被复位**。结果：这 4 种敌人的 `shootDelay`
（1.5 / 3.0 / 0.5 / 8.0 秒）完全形同虚设，每个远程敌人整局只输出一次。

**修复**：
- `scene/enemy.tscn` 增加 `[connection signal="timeout" from="delay" to="." method="_on_delay_timeout"]`
- `script/enemy.gd` 新增 `_on_delay_timeout()` → `canShot = true`

**验证**：中型坦克（shootDelay 1.5）在机枪塔附近 **6 秒内实际开火 2 次**（修复前恒为 1）；
清空目标后等定时器超时，`canShot` 正确复位为 `true`。

#### 2. 地图内容缺失

见第 4 章。

#### 3. 失败判定差一 + 0 星 / 被打爆仍发宝石并解锁下一关 —— ✅ 已修复（2026-09-12）【实测】

**原问题**：

```gdscript
# map.gd:207
if titleNode.hp - point < 0:      # 只有打成负数才算失败，hp == 0 时游戏继续
```

`finish()` 无条件调用 `UserData.recordStageCompletion(...)`，
而 `autoload/userData.gd:104-126` 在 rating = 0 时**仍然**把当前关和下一关写进 `unlockedStages`（解锁下一关）、
发放 `gemReward`（首次通关判定只看"有没有记录"，不看星级）。
附带：失败时先 `pauseGame()` 弹暂停菜单、再弹结算窗 → 两个窗口同屏；`result_screen` 失败时从不隐藏"下一关"按钮。

**修复**：
- `script/map.gd::enemyEscape()` 改为**先扣血再判定**，`hp <= 0` 即基地被打爆（并 clamp 到 0，不再出现负血量）
- 新增 `map.gd::_on_defense_failed()`：直接弹失败结算，**不再调用 `pauseGame()`**
- `script/map.gd::finish()` 在 `rating <= 0` 时提前 return，不写星级、不发宝石、不解锁关卡
- `autoload/userData.gd::recordStageCompletion()` 在 `rating <= 0` 时直接 return（兜底，防调用方漏判）
- `script/result_screen.gd::setResult()` 失败时隐藏 `btnNextLevel`

**验证**：`rating=0` 结算 → 宝石 0、不解锁、不写星级、分数不变；对照组 `rating=2` 仍正常解锁并写星级。
基地血量打到 0 → 弹出失败结算、星级 0、**暂停菜单不再同屏**、下一关按钮隐藏；失败后再调 `finish()` 也不发奖。

#### 4. 7 座塔里有 4 座永远无法升级 —— ✅ 已修复（2026-09-12）【实测】

**原问题**：升级依赖击杀归属（`script/enemy.gd:110-111` 只有 `_source is Tower` 才加经验），但：

| 文件 | 原代码 | 后果 |
| --- | --- | --- |
| `gun_bullet.gd:18` | `i.hurt(damage)` | 机枪塔 + 无人机基地的无人机拿不到经验 |
| `cannon_bullet.gd:18` | `i.hurt(damage)` | 加农炮塔拿不到经验 |
| `emp_tower.gd` | 只改 `enemy.speed`，从不调用 `hurt` | EMP 塔拿不到经验 |

**修复**：
- `gun_bullet.gd` / `cannon_bullet.gd` 改为 `i.hurt(damage, source_tower)`，把发射者传给敌人
- EMP 塔按设计**明确排除在升级体系外**：`autoload/towerUpgradeManager.gd` 新增
  `NON_UPGRADABLE = [EMPTower]` 与 `canUpgrade(type)`；`tower.gd::addExp()` 与
  `tower_detail_panel.gd` 都改用 `canUpgrade()`，EMP 的详情面板现在直接显示 `MAX`
  （此前会显示一条永远不涨的经验条）
- EMP 的 lv2 / lv3 配置**保留**，将来若给它接上独立经验来源（减速覆盖时长 / 助攻计数），
  把 `NON_UPGRADABLE` 里的条目删掉即可启用

**验证**：机枪塔用**自己的子弹**击杀中型坦克后经验 0 → 4，等级正常提升；
手动构造的 `gunBullet` 命中敌人后塔经验再次 +2；`addExp(9999)` 对 EMP 塔无效（等级恒为 1）。
`canUpgrade()` 判定：6 座塔可升级、EMP 明确不可升级。

#### 5. 音效系统完全没接（本轮明确推迟）

- `script/sound_manage.gd` **全文只有 10 行**，只有 `playEffect()`（播放 `Ting Coins.ogg`）；
  不存在 `playMusic` / `stopMusic` / 音量等任何其它接口。
- 全项目只有 **2 处**调用：`ui_button.gd:4`、`welcome.gd:60`。
- 建塔、开火、命中、爆炸、升级、敌人逃脱全部无声。
- `sound/button_on.mp3` 完全未被引用。
- **没有任何背景音乐资源**，因此 `title.gd` 的音乐开关、`setting.gd` 的 BGM 音量滑块
  都是对一条空 bus 操作（`set_bus_mute("Bg", ...)`），玩家感知不到任何效果。
- `scene/Tower.tscn` 的 `deploySound` 没设 bus（走 Master）→ **Sfx 静音开关对塔部署音无效**。

> 本轮已明确**推迟到后续处理**，但上面 3 条"假开关"建议先处理掉（要么接上，要么隐藏入口）。

#### 6. 1X / 2X 倍速三重断裂【静态】

- 后端：`script/map.gd:253-257` 的 `speedOn()` / `speedOff()` 都是 `pass`
- 接线：`script/title.gd:60-66` 的 `_on_btn_speed_toggled` **没有任何信号连接它**
- 界面：`scene/title.tscn` 的 `btnFast` `visible = false`、无 `toggle_mode`、Label 硬编码 `"x1"`，
  connection 列表里也没有它

三层都缺。要么补 `Engine.time_scale` + 按钮状态同步，要么先把入口彻底删掉。

### P1：影响完整体验

7. **成就奖励完全没接线**：9 个成就都定义了 `reward_gem`（10~30）与 `reward_title`（「天空守卫」「路线掌控者」），
   但这两个字段**只在定义处出现**，没有任何地方读取 → 解锁成就不发宝石、也没有称号系统。
8. **背包系统只有设计文档、没有代码**：`feature_design.md` §2 有完整设计，
   但 `item_data` / `item_database` / `backpack` / `backpack_panel` / `shop_panel` **一个文件都不存在**
   （旁证：`theme/style/item_border.tres` 无人引用）。
9. **能力技能系统只有设计文档、没有代码**：§4 设计了区域轰炸 / 塔无敌两个主动技能与冷却 UI，
   `ability_*` 相关文件数为 0。该模块依赖地图侧的"区域选择 / 范围伤害"接口，建议在地图数据模型修好后再做。
10. **成就「路线掌控者」永远无法达成** —— 依赖多路线关卡，见 §4.3 ⑤。
11. **关卡选择界面的描述面板永远是空白**【静态】：`level_select.tscn:56` 实例化了 `descriptionPanel`，
    但 `level_select.gd:4` 声明后从未使用，`level_card.gd:5` 的 `description` 也从未被赋值。
12. **结算界面波次标签永远不显示**【静态】：`result_screen.gd:5` 的 `waveLabel` 从未被赋值，场景里 `visible = false`。
13. **塔开火特效覆盖 3/7**：`tower.gd` 的 `play_muzzle_flash()` 依赖 `sparkPlayer` 节点，
    EMP / 特斯拉 / 激光 / 无人机基地没有该节点（代码注释自述"自动跳过"）。
    —— 这是有意为之（这三座塔没有炮口 / 已有自己的特效），但**无人机基地的无人机开火确实没有特效**，可以补。
14. **EMP 减速有隐患**【静态】：恢复速度用 `enemy.speed / (1.0 - slow_ratio)`，而 `slow_ratio` 由**当前** atk 计算；
    塔在被减速目标仍在范围内时升级（atk 50→55→60）会导致恢复比例不匹配，敌人**永久变慢**。
    另外多座 EMP 范围重叠会叠乘减速，且没有任何减速图标 / 特效反馈。
15. **敌人回血无特效**：`enemy.gd:113` 有 `#增加血量 TODO: 有个回复血量的特效` 待办。
16. **升级光效只做了一半**：`tower.gd:153-165` 只有"打开 shader → 等 1 秒 → 关闭"，
    淡入淡出与亮度补间全部被注释掉。
17. **战斗反馈偏弱**：塔被摧毁、基地受击、敌人逃脱都缺少画面与音效反馈。
18. **结算弹窗信息不完整**：没有关卡名、击杀数、建塔数、用时等统计。
19. **特斯拉闪电有一处空引用风险**【静态】：`tesla_coil_tower.gd:93-95` 的 `_regenerate_jagged_points`
    没有 `is_instance_valid` 校验，而闪电显示期 0.18 秒内目标很可能已 `queue_free`
    → 会刷 "previously freed instance" 错误（`_draw` 里有校验，这里漏了）。

### P2：内容与长期维护

20. **11~15 关复用同一张地图** —— 见 §4.3 ②。
21. **飞行单位体系未统一** —— `aircraft.gd` 已简化为飞行单位基类，但侦察无人机、攻击直升机仍直接继承 `enemy.gd`。
22. **存档没有版本号与迁移机制** —— 直接读写字段，未来增删字段时旧存档没有兼容处理。
23. **无"优先攻击高价值塔"的敌人 AI** —— `tower.gd:17` 的 `targetValue` 声明后从未使用。
24. **塔卡片的塔类型硬编码** —— `tower_ui.gd:22-28` 写死 `1001` / `1002`（应为枚举），
    且 tower4~7 的图标全部复用 `tower3.png`。
25. **未使用的字段**：`bullet.gd:11` 的 `speed`、`custom_camera.gd:9` 的 `zoomPosOffset`、
    `enemy.gd:12` 的 `vec`、`achievement_manager.gd` 的 `category`。

---

## 6. 建议清理的死代码与调试残留【静态】

| 类别 | 对象 |
| --- | --- |
| 孤儿场景 | `scene/level_grid.tscn`、`scene/placeable_area.tscn` + `script/placeable_area.gd`、`scene/tower_status_ui.tscn` + `script/tower_status_ui.gd` |
| 孤儿着色器 | `shader/scene_transition.gdshader`（转场已改为纯 ColorRect 淡入淡出）、`shader/wave_progress_spark.gdshader`（进度条只用 glow 那支） |
| 孤儿资源 | `scene/level/fg_tile_set.tres`（关卡实际用 `new_tile_set.tres`）、`theme/style/item_border.tres`、`sound/button_on.mp3` |
| 陈旧副本 | `script/userData.gd` —— 是 `autoload/userData.gd` 的旧版本，既未注册也无人引用 |
| 空插件 | `addons/toast/` —— `autoLoad.gd` 只有 `extends Node`，`project.godot` 里也没有 `[editor_plugins]` 段，从未启用 |
| 调试残留 | `map.gd:29` 的 `debug = true`；`map.tscn` 的 `hud/Button`（`text="test"`、隐藏）+ `map.gd:399-402` |
| 生产路径 print | `map.gd`、`base_level.gd`、`tower.gd`、`tower_shadow.gd`、`tower_ui.gd`、`placeable_area.gd` 共约 13 处 |
| 大段注释代码 | `base_level.gd:161-171`、`map.gd:124-131` 与 `:411-413`、`tower.gd:164-170`、`laser_tower.gd:13-19`、`tesla_coil_tower.gd:37-44`、`about_panel.gd:9-17`、`level_1.gd:5-20`、`heavyTank.gd:11-17`、`mini_tank.gd:10-24`、`mediumTank.gd:11-17`、`tower_ui.gd:32-39,52-62`、`result_screen.gd:16-17` |

> `tower_status_ui` 的 `set_status` / `show_status` / `hide_status` 是全项目**唯一 3 个完全无引用的公开函数**
> —— 塔的状态展示已经改由右侧详情面板承担。

---

## 7. 重要运行时风险

1. **`owner.queue_free()` 销毁敌人** —— 敌人脚本依赖 `owner`（实际是场景实例根节点 `PathFollow2D`）释放节点。
   动态加入的节点 `owner` 不一定是预期对象，建议统一改为明确的敌人根引用。
   *（注：成就系统依赖"在节点释放前发信号"这一时机，改动此处需同步复核 `enemy.gd::hurt()`。）*
2. **雷达目标列表可能残留失效引用** —— 塔 / 敌人的 `target` 数组在目标被出售或销毁后可能留下野指针。
   自爆车已加清理，其余塔和敌人尚未统一；特斯拉的绘制路径更是直接缺校验（见 §5.19）。
3. **伤害类型没有完全贯通** —— 激光塔调用 `enemy.hurt()` 时未传 `"energy"`，护甲规则对激光不生效。
4. **通关结算可能重复触发** —— 结果窗口按钮与场景切换缺少统一的防重入保护。
5. **塔与敌人的点击判定用了两套写法** —— 塔用 `Input.is_action_just_pressed("click")`，
   敌人用事件对象的 `_event.is_action_pressed("click")`。真实输入下都正常，但不利于统一测试。

---

## 8. 建议开发顺序

### 第一阶段：修正确性 —— ✅ 主要三项已完成（2026-09-12）

1. ~~**接上敌人 `delay` 定时器**~~ —— ✅ 已完成，敌方远程火力节奏已恢复。
2. ~~**修失败判定与结算门禁**~~ —— ✅ 已完成，`hp <= 0` 判失败、rating ≤ 0 不发奖不解锁、
   失败不再同屏弹暂停菜单、隐藏"下一关"按钮。
3. ~~**让子弹携带击杀来源**~~ —— ✅ 已完成，机枪 / 加农 / 无人机基地恢复升级能力；
   EMP 明确排除在升级体系外。
4. **关掉 `debug` 网格**（1 行）—— ⬜ 待办。
5. **补特斯拉闪电的空引用校验**、清理生产路径 print —— ⬜ 待办。

### 第二阶段：把地图扶正（当前内容层最高优先级）

6. 可建造区改为由 `buildable` TileMapLayer 推导，删掉各关脚本里的手写坐标表。
7. 补路径占位判定，杜绝塔建在路上。
8. 修 `level_1.gd` 的 4 格可建造区（被 6 个关卡共用）。
9. 给 level_2~level_10 铺地形，让每关看起来不同。
10. 收敛关卡数或补齐 11~15 关地图，消除"6 关同一张图"。

### 第三阶段：补齐体验与系统

11. 加出生点 / 基地节点，逃脱判定改为"到达基地"，补基地受击反馈。
12. 成就奖励接线（宝石 / 称号）。
13. 实现或明确下线倍速与音频两个空壳（补 BGM 或删掉音乐开关；`sound_manage.gd` 扩成含音乐与音量的接口）。
14. 修 EMP 减速的恢复比例隐患、补减速反馈。
15. 多路线支持，解锁「路线掌控者」成就。

### 第四阶段：内容与系统扩展

16. 背包系统落地（设计已就绪）。
17. 能力技能系统落地（设计已就绪，依赖地图接口）。
18. 通关统计与结算信息完善、飞行单位体系统一、新敌人 / Boss。

---

## 9. 最低测试清单

每次改动核心系统后至少验证：

- 7 种塔都能正确放置、攻击、出售，并读取各自属性与升级配置。
- **7 种塔都能通过击杀正常升级**（改完子弹来源后必测）。
- **远程敌人（中型坦克 / 导弹车 / 攻击直升机 / 维修车）能按 `shootDelay` 持续开火**。
- 塔不能建在敌人行军路线上（加路径占位判定后必测）。
- 每关都能正常出怪、结算、记录星级；**0 星 / 基地被打爆时不解锁下一关、不发宝石**；重复通关不重复发奖励。
- 敌人死亡 / 逃脱 / 自爆 / 攻击塔后节点都能正确释放，雷达 `target` 无残留。
- 成就：累计型跨关卡累加正确；单局型不被低分局覆盖；通关类同帧多解锁时提示能排队播出。
- 退出重进后关卡解锁、评分、宝石、成就、设置都还在。
- 暂停 / 重试 / 下一关 / 返回主菜单不会重复触发场景切换。
- 中英切换后，弹窗、塔 / 敌人面板、成就界面的文案都随语言变化。

---

## 10. 结论

项目的主循环、塔 / 敌人体系、UI 主题、成就系统已经完整可用。

**2026-09-12 已修复三个"看起来能用、实际没生效"的核心机制**（均通过实测）：

1. ✅ 敌方远程单位整局只开火一次（`delay` 定时器未接线）→ 已恢复冷却开火，
   实测中型坦克 6 秒内开火 2 次（修复前恒为 1）
2. ✅ 4/7 座塔永远无法升级（子弹不传击杀来源）→ 机枪 / 加农 / 无人机基地已恢复升级；
   EMP 按设计明确排除在升级体系外，详情面板改显 `MAX`
3. ✅ 0 星 / 被击破也能拿宝石并解锁下一关（结算门禁缺失）→ 已补门禁，
   失败时不再同屏弹暂停菜单、隐藏"下一关"按钮

这三条修完，**实际难度曲线和成长节奏会明显区别于修复前**，建议重新过一遍关卡平衡。

当前**最紧迫的仍然是地图**：它的数据模型缺了地形、出生点、终点和可建造区，
导致 9 个关卡没有画面、6 个关卡共用一张只有 4 个可建造格的图、可建造区靠手抄坐标维护。
建议按 §8 第一阶段的剩余项（关 debug 网格、补空引用校验）收尾，
再进入第二阶段扶正地图，之后才往背包、能力、音效这些新系统上投人。
