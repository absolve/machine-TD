# Machine-TD

一个用 **Godot 4.7**（GL Compatibility 渲染后端）制作的 2D 塔防游戏。

> **项目状态：可玩，但未完成。**
> 核心塔防循环、7 种防御塔、10 种敌人、16 个关卡、存档 / 星级 / 宝石、成就系统已经跑通。
> 目前最拖后腿的是**地图与关卡内容**（详见 [game_analysis.md](game_analysis.md) 第四章），
> 音效系统、背包系统、能力技能系统尚未实现。
>
> **美术方向已定并已落地：所有关卡都在同一座"明亮装配车间"里**，流水线即敌人路径，终点是出口，
> 塔建在其余基座上。地面是**深蓝灰地砖**（`#333C57` + `#1A1C2C` 砖缝，取自 Tech Dungeon tileset），
> UI 是**深银金属仪表盘**（`#566C86` + `#94B0C2` 亮边），主强调色为安全黄。
> 规范见 [art_style.md](art_style.md)，实际效果见 [design/shots/](design/shots/)。
>
> ✅ **2026-09-13：地板 / 清屏色统一为 `#333C57`**（取自 Tech Dungeon tileset 最右区域的地砖色），
> 同时 UI 面板整体提到 `#566C86` 并换 `#94B0C2` 2px 亮边框，
> 以保持"地板 → 面板 → 边框"三层明度（0.046 / 0.144 / 0.412）。
> 主菜单 / 选关页的背景仍是原来的**平铺贴图 + 垂直滚动**效果，只加了 `tint` 把色调挪到蓝灰。
>
> ✅ **2026-09-13：车间瓦片集落地**。`sprite/tile/` 下 24 种 64×64 瓦片（= `StageData.TileSize`），
> 由 `scene/level/factory_floor.tres` 驱动（一张 PNG 一个 `TileSetAtlasSource`，加新瓦片不用重排图集）：
> **地面层 12 种**（基础 / 通风 / 排水 / 螺栓 / 花纹钢 / 检修口 / 排水沟 / 集水坑 / 油渍 / 裂纹 / 警示带 / **塔位基座**）
> + **路径层 12 个方向**（流水线皮带，含两个旋向的全部拐角）。
> 地面全部只用 `#333C57` / `#1A1C2C` / `#0D1016` / `#FFC61A` 四档 + 一个插值档，四周 1px 描边，
> 平铺后相邻两格合成 **2px 砖缝**；塔位基座是一块抬起的厚钢板（明度 0.468 vs 地板 0.235，一眼可见）；
> 皮带比地板深一档（0.113），用安全黄人字形箭头指方向。
> **出口 / 装饰层仍是占位。**
>
> ✅ **2026-09-13：美术资源全部接进游戏（v5.0）** —— 三件事一起做完了：
> **① 7 座塔接线**：`base` 换新底座、`turret` 换新炮塔贴图、`scale` 0.6 → 1.0、
> `Marker2D` 炮口距离逐个校准（机枪 31 / 加农 47 / 火箭 41 / EMP 24 / 激光 60 / 特斯拉 30 / 无人机 40）。
> 塔选择卡片图标与放置阴影（7 条动画）同步更新。合同见 [art_style.md](art_style.md) 的「接进游戏时的契约」。
> **② 教程关换皮**：`bg` 换成 `factory_floor.tres`，铺 30×17 = 510 格 ——
> 基础地板 + **第 4 行整行流水线** + allowArea 的 36 格 **塔位基座** + 顶部/底部通风格栅 +
> 最底一行**危险警示带** + 排水口 / 舱盖 / 裂纹 / 油渍 / 集水井点缀。
> 敌人路径曲线 y 从 320 移到 **288**（对齐格子中心）。实机截图 [`design/map_tutorial_new.png`](design/map_tutorial_new.png)、
> 七塔一览 [`design/map_tower_row.png`](design/map_tower_row.png)。
> **③ 地图内字号统一**：收敛到 **40 / 30 / 26 / 22** 四级字阶（原来从 11 到 40 混着用，
> `tower_status_ui` 的血量/经验只有 11px）。

## 运行

1. 用 Godot 4.7 打开 `machine-td/` 目录（不是仓库根目录）
2. 直接 F5 运行，主场景是 `scene/welcome.tscn`
3. 首次打开编辑器时会自动从 `lang/language.csv` 重新生成 `lang/*.translation`

## 目录结构

```
machine-td/                  Godot 工程根目录
├── autoload/                全局单例（9 个）
│   ├── game.gd              塔 / 敌人的数值表、全局信号、显示名查询
│   ├── userData.gd          设置与玩家存档读写
│   ├── stageData.gd         16 个关卡的波次、血量、金币、宝石奖励
│   ├── towerUpgradeManager.gd  7 种塔的 3 级升级配置
│   ├── achievement_manager.gd  9 个成就的定义、进度与解锁
│   ├── sceneTransition    场景切换（`scene/scene_transition.tscn` + 同名脚本，着色器擦除）
│   └── easterEgg.gd         启动时打印 ASCII Logo
├── script/                  78 个脚本
│   ├── map.gd               关卡总控：读关、放塔、结算
│   ├── base_level.gd        关卡基类：波次、出怪、可建造区
│   ├── tower.gd             防御塔基类：雷达、选中、升级、开火特效
│   ├── enemy.gd             敌人基类：血量、护甲、雷达、点击选中
│   ├── achievement_tracker.gd  关卡内成就进度记录
│   └── (各塔 / 各敌人 / 各 UI 脚本)
├── scene/                   66 个场景
│   ├── level/               12 个关卡场景（base_level + 教程 + 1~10）
│   ├── ui/                  通用按钮等复用组件
│   └── (各类弹窗 / 面板 / 塔 / 敌人 / 子弹)
├── theme/                   深色主题：theme.tres + 31 个 StyleBox
├── shader/                  7 个着色器（升级发光、成就图标、波次进度、场景擦除等）
├── sprite/                  美术素材（`sprite/tile/` 为 64px 车间地面瓦片）
├── lang/language.csv        中英文案（唯一数据源）
└── design/                  概念图与验证截图（在仓库根目录）
```

## 关键约定

| 项 | 值 |
|---|---|
| 逻辑分辨率 | 1920 × 1080（`window/stretch/mode = viewport`，画布固定该尺寸） |
| 网格大小 | 64 px（`StageData.TileSize`，与 `map.gd` 的 `cellSize` 需保持一致） |
| 碰撞层 | 1=tower / 2=enemy / 3=bullet / 4=placeableArea / 5=EMPArea |
| 存档路径 | `user://player_settings.cfg`、`user://player_data.cfg` |
| 多语言 | 只改 `lang/language.csv`，不要手改 `*.translation`（它是导入产物，已被 gitignore） |
| 数据驱动 | 塔的数值在 `Game.towerInfo`，敌人在 `Game.enemyInfo`，关卡在 `StageData.allStage`。**`name` / `role` 字段里存的就是翻译键**（如 `_TowerName_machineGun`），取显示名只要一次 `tr()` |
| 关卡限制 | 可建防御塔按关卡配置在 `StageData.stageTowers`（未配置 = 全开）；可用的能力技能在 `StageData.stageAbilities` |
| 文案 | 界面用 `_t(key, fallback)` 取翻译，未命中时回退英文而不是显示 key |

## 当前完成度

> ✅ **2026-09-12：三个"看起来能用、实际没生效"的核心机制已修复**（详见 [game_analysis.md](game_analysis.md) §5）：
> ① 敌方远程单位整局只开火一次 → 已恢复冷却开火
> ② 7 座塔里有 4 座永远无法升级 → 机枪 / 加农 / 无人机基地已恢复；EMP 按设计明确不可升级
> ③ 0 星 / 基地被打爆也会发宝石并解锁下一关 → 已补结算门禁
>
> 这三条修完，**实际难度曲线与成长节奏会明显不同于修复前**，建议重新过一遍关卡平衡。
>
> ✅ **2026-09-12：场景切换重构为"场景 + 脚本"**。原来只有一个纯脚本自动加载，现在
> `scene/scene_transition.tscn`（Node → CanvasLayer(layer 100) → ColorRect + `shader/transition.gdshader`），
> 由着色器做自上而下的柔边擦除，颜色 / 方向 / 软边强度都能在场景里调，不用改代码。
> 对外接口 `SceneTransition.change_scene(path, duration)` 与 6 个调用点保持不变。
>
> ✅ **2026-09-12：5 个弹窗由 `Window` / `PopupPanel` 改为普通 `Control`**。Godot 会把
> `Window` 系节点渲染成**嵌入式子窗口**，绘制在所有 `CanvasLayer` 之上——只要弹窗还是
> Window，转场遮罩就永远盖不住它。现在 `about_panel` / `level_intro_panel` / `pause_menu` /
> `result_screen` / `setting` 全部是 `Control`，`map.tscn` 另加了 `popupLayer`
> (CanvasLayer, layer 10) 承载三个战斗内弹窗（`hud` 也是 CanvasLayer，会压住同级 Control）。

| 模块 | 状态 |
|---|---|
| 主循环（选关 → 战斗 → 结算 → 存档） | ✅ 已接，结算门禁已修复 |
| 7 种防御塔（放置 / 攻击 / 出售 / 升级 / 开火特效） | ✅ 已接，EMP 按设计不参与升级 |
| 10 种敌人（含对抗型 / 支援型 / 自爆型） | ✅ 已接，远程单位冷却开火已修复 |
| 敌人雷达与攻击范围 | ✅ 已接且已验证 |
| 塔 / 敌人点击查看信息面板 | ✅ 已接 |
| 成就系统（记录 + 总览面板 + 获得提示） | ✅ 已接（奖励字段未接线、`route_master` 无法达成） |
| UI 主题（弹窗 / 按钮 / 列表 / 滚动条） | ✅ 已接，**2026-09-13 重建为深银金属 v3.2** |
| 场景切换（着色器擦除 + 异步加载） | ✅ 已接并已运行验证 |
| 世界美术（工厂地面 / 流水线 / 出口） | ✅ 瓦片 24 种已出并**已接进教程关**（`factory_floor.tres`，510 格）；⚠️ 出口 / 装饰层未做，其余 9 关仍是旧地面 |
| 7 座塔美术接线 | ✅ **2026-09-13 全部接上**（炮塔 + 底座 + 炮口 + 卡片图标 + 放置阴影） |
| 地图内字号 | ✅ **2026-09-13 统一为 46 / 36 / 30 / 26**（v5.1 再放大一档） |
| 多语言 | ✅ **2026-09-13 修复**：`set_locale` 原先只在设置面板里调用 → 没进过设置页就是中英混排；现由 `UserData.applyLanguage()` 在启动时执行，默认跟随系统语言 |
| 关卡限制可建防御塔 | ✅ **2026-09-13 已接**：`StageData.stageTowers` 按关卡配置放行列表（未配置 = 全开），塔选择栏里被限制的塔**置灰且不可点**，`map.placeTower` 另有兜底拦截 |
| 音频素材 | ⚠️ **2026-09-13 已入库未接线**：`sound/bgm/` 4 首环境循环（已设 `loop`）+ `sound/sfx/` 26 个音效，共 6.8 MB OGG，来源与授权见 [`sound/CREDITS.md`](machine-td/sound/CREDITS.md)。**`Bg` 总线至今没有东西在播** |
| 波次进度条、开场情报面板 | ✅ 已接 |
| 地图与关卡内容 | ⚠️ **问题集中区**，见 `game_analysis.md` §4 |
| 1X / 2X 倍速 | ❌ 后端 / 接线 / 界面三层都缺 |
| 音效与背景音乐 | ❌ 只有 1 个 UI 音效接口；无 BGM 资源（本轮明确推迟） |
| 背包系统 | ❌ 只有设计文档，无代码 |
| 能力技能系统 | ❌ 只有设计文档，无代码 |

## 文档

| 文档 | 用途 |
|---|---|
| [art_style.md](art_style.md) | **美术风格规范**：工厂主题、色彩系统、UI 组件、世界元素、单位识别、迁移记录 |
| [game_analysis.md](game_analysis.md) | **项目现状与缺口分析**：已实现 / 未实现 / 地图专项 / 开发顺序 |
| [feature_design.md](feature_design.md) | **模块设计记录**：每个模块的完整设计、数据结构、集成点、更新日志 |
| [design/](design/) | 概念图与各功能的运行验证截图 |

## 许可

见 [LICENSE](LICENSE)。
