# Machine-TD

一个用 **Godot 4.7**（GL Compatibility 渲染后端）制作的 2D 塔防游戏。

> **项目状态：可玩，但未完成。**
> 核心塔防循环、7 种防御塔、10 种敌人、16 个关卡、存档 / 星级 / 宝石、成就系统已经跑通。
> 目前最拖后腿的是**地图与关卡内容**（详见 [game_analysis.md](game_analysis.md) 第四章），
> 音效系统、背包系统、能力技能系统尚未实现。
>
> **美术方向已定并已落地：所有关卡都在同一座"明亮装配车间"里**，流水线即敌人路径，终点是出口，
> 塔建在其余基座上。UI 走**深银金属**（调色板从参考资源包
> `factory asset v.2 - chemical lab` 提取），世界中性与 HUD 沉稳，主强调色为安全黄。
> 规范见 [art_style.md](art_style.md)，实际效果见 [design/shots/](design/shots/)。
>
> ✅ **2026-09-13：UI 主题重建为 v2.0 深银金属**——先做过一版亮色（v1.0，面板明度 0.94）但整体过亮，
> 已整体压到中低明度并换成金属色相。`theme.tres` + 31 个 StyleBox 全部重写，
> 15 个场景的硬编码文字色与内联 StyleBox 一并调整，**未改动任何 `.tscn` 结构**。
> 世界美术（工厂地面 / 流水线贴图）尚未制作，背景目前是按新基色着色的占位；
> 背景基色与清屏色同为 `#8C9195`，欢迎页、选关页与战斗地图底色完全一致。

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
├── sprite/                  美术素材
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
| 数据驱动 | 塔的数值在 `Game.towerInfo`，敌人在 `Game.enemyInfo`，关卡在 `StageData.allStage` |
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
| UI 主题（弹窗 / 按钮 / 列表 / 滚动条） | ✅ 已接，**2026-09-13 重建为 v2.0 深银金属** |
| 场景切换（着色器擦除 + 异步加载） | ✅ 已接并已运行验证 |
| 世界美术（工厂地面 / 流水线 / 出口） | ❌ 仅有风格规范与浅色占位背景 |
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
