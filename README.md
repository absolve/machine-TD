# Machine-TD

一个用 **Godot 4.7**（GL Compatibility 渲染后端）制作的 2D 塔防游戏。

> **项目状态：可玩，但未完成。**
> 核心塔防循环、7 种防御塔、10 种敌人、16 个关卡、存档 / 星级 / 宝石、成就系统已经跑通。
> 目前最拖后腿的是**地图与关卡内容**（详见 [game_analysis.md](game_analysis.md) 第四章），
> 音效系统、背包系统、能力技能系统尚未实现。

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
│   ├── sceneTransition.gd   黑屏淡入淡出的场景切换
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
├── shader/                  7 个着色器（升级发光、雷达、成就图标发光等）
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

| 模块 | 状态 |
|---|---|
| 主循环（选关 → 战斗 → 结算 → 存档） | ✅ 已接，结算门禁已修复 |
| 7 种防御塔（放置 / 攻击 / 出售 / 升级 / 开火特效） | ✅ 已接，EMP 按设计不参与升级 |
| 10 种敌人（含对抗型 / 支援型 / 自爆型） | ✅ 已接，远程单位冷却开火已修复 |
| 敌人雷达与攻击范围 | ✅ 已接且已验证 |
| 塔 / 敌人点击查看信息面板 | ✅ 已接 |
| 成就系统（记录 + 总览面板 + 获得提示） | ✅ 已接（奖励字段未接线、`route_master` 无法达成） |
| 深色 UI 主题（弹窗 / 按钮 / 列表 / 滚动条） | ✅ 已接 |
| 波次进度条、开场情报面板 | ✅ 已接 |
| 地图与关卡内容 | ⚠️ **问题集中区**，见 `game_analysis.md` §4 |
| 1X / 2X 倍速 | ❌ 后端 / 接线 / 界面三层都缺 |
| 音效与背景音乐 | ❌ 只有 1 个 UI 音效接口；无 BGM 资源（本轮明确推迟） |
| 背包系统 | ❌ 只有设计文档，无代码 |
| 能力技能系统 | ❌ 只有设计文档，无代码 |

## 文档

| 文档 | 用途 |
|---|---|
| [game_analysis.md](game_analysis.md) | **项目现状与缺口分析**：已实现 / 未实现 / 地图专项 / 开发顺序 |
| [feature_design.md](feature_design.md) | **模块设计记录**：每个模块的完整设计、数据结构、集成点、更新日志 |
| [design/](design/) | 概念图与各功能的运行验证截图 |

## 许可

见 [LICENSE](LICENSE)。
