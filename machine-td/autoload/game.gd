extends Node

const app_vec = "1.0.0" # 程序版本

enum bulletType {
	player, enemy
}

# 敌人类型（已定义场景的敌人）
enum enemyType {
	miniTank, mediumTank, heavyTank,
	# 推进型（地面）
	armoredTank, assaultBuggy, medic, suicideTruck,
	# 对抗型（地面）
	missileTruck,
	# 空中单位
	scoutDrone, attackHelicopter,
	# 重装堡垒型（多炮塔地面单位）
	experimentalTank,
	# 飞越地图的空中骚扰单位（单独路线，逃脱不扣血）
	battlePlane
}

# 塔类型
enum towerType {
	machineGunTower = 1000, cannonTower, rocketTower, EMPTower,
	droneBase, teslaCoilTower, laserTower, ironBox,
	# 移动机甲（后勤单位）：不杀敌、不升级，用激光修复附近残血防御塔。
	# 新增枚举值只追加在末尾 —— 中间插值会让已有存档 / 场景里写死的整数对不上。
	mech
}

## ── 无尽模式（设计见 endless_mode_design.md）──
## 模式开关：欢迎界面点「无尽模式」时置 true，回主菜单时复位。
## map.gd 据此跳过 allStage 查表、直接加载 scene/level/endless.tscn。
var endlessMode: bool = false
## 难度缩放（敌人 hp / atk 的乘数）：普通关卡恒为 1.0，无尽按波次设置。
var enemyScale: float = 1.0
var enemyAtkScale: float = 1.0

## ── 战斗模式（设计见 feature_design.md §十七）──
##
## 玩家在关卡选择页选一个模式，同一张图换一套倍数重打。
##
## ⚠️ 这些倍数**独立于 enemyScale / enemyAtkScale**，不要复用它们 ——
##    那两个被无尽模式每波重写（endless_level.gd），复用会互相覆盖。
##    enemy.gd 里是"两个相乘"，所以倍速的语义是叠加的。
##
## ⚠️ **绝对不要改出怪间隔**（曾经有过 `delayScale`，已删除）。
##    间隔一缩短，同一条路径上后一个敌人会追上前一个、**视觉上叠在一起**，
##    看起来像一坨、也分不清谁是谁。需要调节奏时**改移动速度**（`speedScale`）：
##    速度只影响"每个敌人在塔的射程里待多久"，不会让它们挤成一团。
##
## ⚠️ 离开关卡必须调 resetBattleMode()（code_design.md §7.6）：这是全局状态，
##    不复位会把"蜂群"带到下一局甚至主菜单。
const battleModeDefs = {
	"normal": {
		"name": "_Mode_normal",
		"desc": "_Mode_normal_desc",
		"countScale": 1.0,
		"hpScale": 1.0,
		"atkScale": 1.0,
		"speedScale": 1.0,
		"rewardScale": 1.0,
		"expScale": 1.0,
		"gemScale": 1.0,
		"recordsProgress": true,
	},
	# 蜂群：数量翻倍、个体变脆。总血量不变，但密度翻倍 —— 考验溅射/攻速。
	# 每杀收益必须跟着 ×0.5，否则击杀数翻倍会让金币与塔经验也翻倍，
	# 「困难模式」反而变成最容易的模式（详见设计文档 17.5）。
	# 数量翻倍但**出怪间隔不变** → 一波的敌人数是多了一倍、排成的队列也更长。
	# 所以这里把移速提到 ×1.2：队列走得快一点，不至于一波打两倍时间；
	# 代价是每个敌人在射程里待的时间变短（更难），正好符合挑战模式的定位。
	"swarm": {
		"name": "_Mode_swarm",
		"desc": "_Mode_swarm_desc",
		"countScale": 2.0,
		"hpScale": 0.5,
		"atkScale": 0.8,
		"speedScale": 1.2,
		"rewardScale": 0.5,
		"expScale": 0.5,
		"gemScale": 1.3,
		"recordsProgress": false,
	},
	# 铁流：数量不变、单个硬一倍 —— 考验破甲与持续输出。
	# 收益按"血量"结算：血量 ×2 → 每杀收益 ×2，做到"每点血的收入恒定"。
	# 移速不动：这一模式的"慢"来自敌人本身更耐打，不是靠拉长队列。
	"armor": {
		"name": "_Mode_armor",
		"desc": "_Mode_armor_desc",
		"countScale": 1.0,
		"hpScale": 2.0,
		"atkScale": 1.0,
		"speedScale": 1.0,
		"rewardScale": 2.0,
		"expScale": 2.0,
		"gemScale": 1.4,
		"recordsProgress": false,
	},
	# 精锐：血量略高、攻击显著提高 —— 考验塔的血量管理（对抗型敌人会真的拆塔）。
	"elite": {
		"name": "_Mode_elite",
		"desc": "_Mode_elite_desc",
		"countScale": 1.0,
		"hpScale": 1.3,
		"atkScale": 1.5,
		"speedScale": 1.1,
		"rewardScale": 1.3,
		"expScale": 1.3,
		"gemScale": 1.5,
		"recordsProgress": false,
	},
}

## 当前战斗模式 id（`battleModeDefs` 的 key）。
var battleMode: String = "normal"
## 从当前模式解出来的实际倍数；由 setBattleMode() / resetBattleMode() 统一维护。
var modeCountScale: float = 1.0
var modeHpScale: float = 1.0
var modeAtkScale: float = 1.0
## 敌人**移动速度**倍数（不是出怪间隔 —— 间隔不允许被模式改，见文件顶部说明）
var modeSpeedScale: float = 1.0
var modeRewardScale: float = 1.0
var modeExpScale: float = 1.0
var modeGemScale: float = 1.0

# 塔信息
#
# ★ 数值规范（2026-09-26 全表重做）：
#   1. **所有攻击力 atk 必须 < 100**（含升级后的 Lv.3，见 towerUpgradeManager.gd）
#   2. DPS = atk / reload。设计目标是"一塔打一群普通敌人需要时间"，
#      所以机枪塔这类高射速塔的 reload 不能太小，否则 DPS 爆掉（旧版 29/0.16 = 181）
#   3. 塔与敌人同尺度：普通敌人 hp 100~200，重型 250~450
const towerInfo = {
	towerType.machineGunTower: {
	"name": "_TowerName_machineGun",
	"atk": 8, # DPS 35（scope 只有 140，覆盖窗口短，DPS 不能再压）
	"cost": 20,
	"reload": 0.4,
	"scope": 140,
	"hp": 200,
	"maxHp": 200,
	"initTime": 0.5,
	"desc": "_machineGunTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.cannonTower: {
	"name": "_TowerName_cannon",
	"atk": 30, # DPS 60（单发高、打得慢）
	"cost": 35,
	"reload": 1.0,
	"scope": 200,
	"hp": 240,
	"maxHp": 240,
	"initTime": 0.9,
	"desc": "_cannonTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.rocketTower: {
	"name": "_TowerName_rocket",
	"atk": 40, # DPS 40，范围伤害
	"cost": 50,
	"reload": 1.0,
	"scope": 200,
	"hp": 240,
	"maxHp": 240,
	"initTime": 1.2,
	"desc": "_rocketTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.EMPTower: {
	"name": "_TowerName_emp",
	"atk": 20, # 不减血，atk 当"减速强度%"用（见 emp_tower.gd）
	"cost": 45,
	"reload": 4.0,
	"scope": 140,
	"hp": 150,
	"maxHp": 150,
	"initTime": 1.5,
	"desc": "_EMPTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.droneBase: {
	"name": "_TowerName_drone",
	"atk": 6, # DPS 30，靠多架同时输出
	"cost": 65,
	"reload": 0.2,
	"scope": 300,
	"hp": 200,
	"maxHp": 200,
	"initTime": 1.3,
	"desc": "_droneBaseDesc",
	"gridSize": Vector2i(2, 2)
	},
	towerType.teslaCoilTower: {
	"name": "_TowerName_tesla",
	"atk": 34, # DPS 40，链式闪电每跳 75%
	"cost": 65,
	"reload": 0.85,
	"scope": 240,
	"hp": 220,
	"maxHp": 220,
	"initTime": 1.4,
	"desc": "_teslaCoilTowerDesc",
	"gridSize": Vector2i(2, 2)
	},
	towerType.laserTower: {
	"name": "_TowerName_laser",
	"atk": 38, # DPS 38 单体，一次打所有锁定目标
	"cost": 90,
	"reload": 1.0,
	"scope": 240,
	"hp": 260,
	"maxHp": 260,
	"initTime": 1.6,
	"desc": "_laserTowerDesc",
	"gridSize": Vector2i(2, 2)
	},
	towerType.ironBox: {
	"name": "_TowerName_ironBox",
	"atk": 0, # 不攻击，纯防御
	"cost": 30,
	"reload": 1.0,
	"scope": 0,
	"hp": 500,
	"maxHp": 500,
	"initTime": 1.0,
	"desc": "_ironBoxDesc",
	"gridSize": Vector2i(1, 1)
	},
	# ── 移动机甲（后勤单位，见 script/tower/mech.gd）──
	# ★ atk 在这里是**维修量**，不是伤害：机甲的激光对防御塔发 `-atk`，
	#   而 tower.hurt() 是"血量 - ceil(参数)"，传负数就是回血。
	#   这样"维修/回收"和普通攻击共用同一条扣血通路，不用另开一套生命值接口。
	# ★ scope = 激光作用半径（自己的、别的塔够不着的那种"修理臂长度"）。
	# ★ 不参与升级：见 towerUpgradeManager 的 NON_UPGRADABLE。
	towerType.mech: {
	"name": "_TowerName_mech",
	"atk": 12, # 每次激光脉冲修复 12 点血（不是伤害）
	"cost": 70,
	"reload": 1.4, # 激光脉冲间隔（秒）
	"scope": 180, # 激光作用半径
	"hp": 320,
	"maxHp": 320,
	"initTime": 1.2,
	"desc": "_mechDesc",
	"gridSize": Vector2i(1, 1)
	}
}


## ── 防御塔主动技能（设计见 feature_design.md §十八）──
##
## 三种 kind：
##   · `toggle`  —— 功能切换：切过去一直生效，再按一次切回来。`switchCooldown` 只防连点。
##   · `timed`   —— 限时增益：持续 `duration` 秒，结束后进入 `cooldown` 冷却。
##   · `instant` —— 瞬发：点一下立刻生效。机甲额外带一段 `shutdown`（整机停止）。
##
## ⚠️ **技能只影响"派生值"**（`tower.gd` 的 `effectiveAtk / effectiveDelay / effectiveScope`），
##    绝对不要写回 `atk` / `delay` / `radarScope`。
##    那三个是**升级系统的基值**（`tower.gd::levelUp` 会整体覆盖它们）——
##    技能写进去之后，升级一次就被覆盖，或者出现"技能×升级"双倍叠加。
##    这是本模块与升级功能不冲突的唯一保证。
const towerSkills = {
	towerType.machineGunTower: {
		"kind": "timed",
		"name": "_Skill_overheat",
		"desc": "_Skill_overheat_desc",
		"duration": 3.0,
		"cooldown": 18.0,
		"atkMul": 2.0,          # atk ×2（配合 delayMul 0.5 ≈ DPS ×4）
		"delayMul": 0.5,
		"selfHpPerSec": 6.0,    # 每秒自损 6（3 秒共 18）
		"minHpRatio": 0.25,     # 血量低于 25% 拒绝触发
	},
	towerType.cannonTower: {
		"kind": "timed",
		"name": "_Skill_pierce",
		"desc": "_Skill_pierce_desc",
		"duration": 3.0,
		"cooldown": 20.0,
		"delayMul": 1.4,        # 射速 ×0.7 —— 破甲的代价
		"pierceArmor": true,    # 子弹按能量伤害结算（enemy.hurt 的 "energy" 通道无视 armor）
	},
	towerType.rocketTower: {
		"kind": "toggle",
		"name": "_Skill_missile",
		"desc": "_Skill_missile_desc",
		"switchCooldown": 3.0,
		"atkMul": 1.25,         # 40 → 50（Lv3 78 → 98，仍守住 atk < 100 的规范）
		"sightMul": 1.6,        # 200 → 320
		"noSplash": true,       # ⚠️ 核心代价：不再有爆炸范围
		"bulletSpeed": 520.0,   # 300 → 520
		"turnSpeed": 6.5,       # 5.0 → 6.5（速度更快，转向要跟上）
	},
	towerType.EMPTower: {
		"kind": "timed",
		"name": "_Skill_overload",
		"desc": "_Skill_overload_desc",
		"duration": 5.0,
		"cooldown": 25.0,
		"slowMul": 2.0,         # 减速强度 ×2
		"disableAfter": 3.0,    # 结束后停转 3 秒（这 3 秒不提供减速）
	},
	towerType.laserTower: {
		"kind": "toggle",
		"name": "_Skill_singular",
		"desc": "_Skill_singular_desc",
		"switchCooldown": 3.0,
		"atkMul": 2.2,          # 38 → 84（Lv3 44 → 97，仍守住 atk < 100）
		"maxTargets": 1,        # 3 → 1
	},
	towerType.teslaCoilTower: {
		"kind": "timed",
		"name": "_Skill_chain",
		"desc": "_Skill_chain_desc",
		"duration": 3.0,
		"cooldown": 20.0,
		"chainExtra": 2,        # 电弧多跳 2 个目标
		"selfHpPerSec": 5.0,
		"minHpRatio": 0.2,
	},
	towerType.droneBase: {
		"kind": "timed",
		"name": "_Skill_scramble",
		"desc": "_Skill_scramble_desc",
		"duration": 4.0,
		"cooldown": 24.0,
		"delayMul": 0.667,      # 射速 ×1.5
	},
	towerType.ironBox: {
		"kind": "timed",
		"name": "_Skill_armor",
		"desc": "_Skill_armor_desc",
		"duration": 4.0,
		"cooldown": 20.0,
		"damageTakenMul": 0.3,  # 受到伤害 ×0.3
	},
	towerType.mech: {
		"kind": "instant",
		"name": "_Skill_emergency_repair",
		"desc": "_Skill_emergency_repair_desc",
		"healRatio": 0.30,      # 治疗 30% 各自最大血量（自身 + 范围内所有塔）
		"healScope": 180.0,
		"shutdown": 3.0,        # ⚠️ 用完后整机停止 3 秒：不能移动 / 维修 / 回收
	},
}


# 敌人基础信息
# 字段：
#   hp 血量 / speed 移动速度(像素每秒) / reward 击杀金币 / lossPoints 逃脱扣血 / rewardExp 击杀经验
#   armor 物理伤害减免(0~1,能量伤害无视) / flying 空中单位(仅无人机/激光塔可命中)
#   atk 单次攻击伤害(对抗型才有值，推进型为0) / shootDelay 开火间隔秒(对抗型才有值)
#   scope 雷达半径(像素)：对抗/支援型的攻击或支援范围，推进型为0(不参战，雷达不侦测)
#   gemRewardChance 掉落概率(0~1)：**不写 = 1.0（必掉）**；写 0.5 就是"约一半才掉"
#   role 行为定位（用于信息面板标签）：pusher 推进型 / attacker 对抗型 / support 支援型 / bomber 自爆型 / siege 远程打击型 / air 空中单位 / fortress 要塞型
#   gemReward 击败掉落的**宝石**数量：0 = 不掉（普通敌人）/ 1 / 2 —— 只有"特殊敌人"才写非 0
#
# ★ 数值规范（2026-09-26 全表重做）：
#   1. **基础移速 speed = 50**。快慢只允许在这条基准上小幅浮动：
#      快速单位 80~130（突击车/自爆车/侦察无人机），重甲单位 30~50
#   2. **所有攻击力 atk 必须 < 100**（含自爆车——旧版 150 已超限）
#   3. **攻击频率整体上调**：旧版维修车 8 秒一箭、导弹车 3 秒一发，玩家几乎感觉不到压力；
#      现在 shooter 类 0.25~0.9 秒，支援/远程 1.8~3.0 秒
#
# 攻击模式：直射型(DPS=atk/shootDelay) / 远程打击型(追踪导弹，DPS=atk/shootDelay) / 自爆型(一次性总伤害，shootDelay无意义) / 空中直射型(DPS=atk/shootDelay)
# 攻击节奏参考：己方塔射程 280~450(像素)，cellSize=64，即塔约 4.4~7 格
const enemyInfo = {
	enemyType.miniTank: {
		"name": "_EnemyName_miniTank",
		"showsRange": false, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 150, "speed": 50, "reward": 5, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.05, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher",
		"gemReward": 0
	},
	enemyType.mediumTank: {
		"name": "_EnemyName_mediumTank",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 300, "speed": 45, "reward": 8, "lossPoints": 2, "rewardExp": 4,
		"armor": 0.25, "flying": false, "atk": 15, "shootDelay": 0.9, "scope": 240, "role": "_EnemyRole_attacker",
		"gemReward": 0
	},
	enemyType.heavyTank: {
		"name": "_EnemyName_heavyTank",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 600, "speed": 30, "reward": 20, "lossPoints": 3, "rewardExp": 10,
		"armor": 0.5, "flying": false, "atk": 25,
		"shootDelay": 1.8, "scope": 260, "role": "_EnemyRole_attacker",
		"gemReward": 0
	},
	enemyType.armoredTank: {
		"name": "_EnemyName_armoredTank",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 500, "speed": 35, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.6, "flying": false, "atk": 18,
		"shootDelay": 1.5, "scope": 220, "role": "_EnemyRole_attacker",
		"gemReward": 0
	},
	enemyType.assaultBuggy: {
		"name": "_EnemyName_assaultBuggy",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 140, "speed": 115, "reward": 4, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.1, "flying": false, "atk": 6,
		"shootDelay": 0.6, "scope": 180, "role": "_EnemyRole_attacker",
		"gemReward": 0
	},
	enemyType.medic: {
		"name": "_EnemyName_medic",
		"showsRange": false, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 200, "speed": 50, "reward": 10, "lossPoints": 1, "rewardExp": 5,
		"armor": 0.1, "flying": false, "atk": 20, "shootDelay": 3.0, "scope": 180, "role": "_EnemyRole_support",
		"gemReward": 0
	},
	enemyType.suicideTruck: {
		"name": "_EnemyName_suicideTruck",
		"showsRange": false, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 120, "speed": 90, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": false, "atk": 80, "shootDelay": 0.0, "scope": 150, "role": "_EnemyRole_bomber",
		"gemReward": 0
	},
	enemyType.missileTruck: {
		"name": "_EnemyName_missileTruck",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 260, "speed": 40, "reward": 12, "lossPoints": 2, "rewardExp": 6,
		"armor": 0.25, "flying": false, "atk": 35, "shootDelay": 1.8, "scope": 700, "role": "_EnemyRole_siege",
		"gemReward": 0
	},
	enemyType.scoutDrone: {
		"name": "_EnemyName_scoutDrone",
		"showsRange": false, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 100, "speed": 130, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": true, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_air",
		"gemReward": 0
	},
	enemyType.attackHelicopter: {
		"name": "_EnemyName_attackHelicopter",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 380, "speed": 80, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.2, "flying": true, "atk": 5, "shootDelay": 0.25, "scope": 300, "role": "_EnemyRole_air",
		"gemReward": 0
	},
	# 实验坦克：4 座独立炮塔（scene/enemy/experimental_tank.tscn，炮塔用 BaseTurret）。
	#
	# ★ atk / shootDelay / scope 描述的都是**单座炮塔**的数值，整车火力是它的 4 倍；
	#   4 座炮塔的实际数值在场景 Inspector 里设置（与这里保持一致）。
	# ★ gemReward = 2：要塞型特殊敌人，击败必掉 2 颗宝石（战斗飞机则是 50% 掉 1 颗）。
	#   想改掉落数量 / 给别的精英也加掉落，只改这一行或对应条目的 "gemReward" 即可。
	enemyType.experimentalTank: {
		"name": "_EnemyName_experimentalTank",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 1000, "speed": 28, "reward": 40, "lossPoints": 5, "rewardExp": 25,
		"armor": 0.5, "flying": false, "atk": 16, "shootDelay": 0.8, "scope": 300,
		"role": "_EnemyRole_fortress",
		"gemReward": 2
	},
	# 战斗飞机：**飞越地图**的空中骚扰单位，走关卡里单独摆的那条横跨全图的路线。
	# ★ lossPoints = 0：飞到终点直接离场，不扣基地血（battlePlane.gd 覆写了 _physics_process，
	#   连"漏怪"提示锣都不会播）。
	# ★ gemReward = 1 + gemRewardChance = 0.5：**不是每架都掉**，击落时约一半概率掉 1 颗。
	enemyType.battlePlane: {
		"name": "_EnemyName_battlePlane",
		"showsRange": true, # 点击时是否画攻击范围（见 feature_design.md §9.3）
		"hp": 240, "speed": 130, "reward": 12, "lossPoints": 0, "rewardExp": 6,
		"armor": 0.1, "flying": true, "atk": 12, "shootDelay": 0.5, "scope": 320,
		"role": "_EnemyRole_air",
		"gemReward": 1, "gemRewardChance": 0.5
	},
}

# 支持的界面语言。
const language = [ {'text': 'English', 'code': 'en', 'id': 0},
 {'text': '简体中文', 'code': 'zh', 'id': 1}]
	

@warning_ignore("unused_signal")
signal enemyRewarded # 击败敌人
## 击败"特殊敌人"掉落宝石时发出，参数是掉落数量（1 或 2）。
## 数量来自 `enemyInfo` 的 `gemReward` 字段，普通敌人为 0（不发这个信号）。
## 由 map 接收 → UserData.addGem() 入账并落盘 → 刷新顶栏。
@warning_ignore("unused_signal")
signal gemRewarded(amount: int)
@warning_ignore("unused_signal")
signal enemyEscaped # 敌人逃脱
@warning_ignore("unused_signal")
signal selectTower # 选择塔
@warning_ignore("unused_signal")
signal towerPlaced # 放置塔
@warning_ignore("unused_signal")
signal dataRefreshed # 游戏数据刷新
@warning_ignore("unused_signal")
signal towerSold # 出售塔
## 塔**离开棋盘**时发出（出售 or 被打爆），参数是它占用的格子。
## map 收到后把格子归还到 occupiedArea。
## ⚠️ 原来只有"出售"会归回格子，塔被打爆时格子永远占着 —— 那块地就再也建不了塔了。
@warning_ignore("unused_signal")
signal towerGridReleased(coverGrid: Array[Vector2i])
@warning_ignore("unused_signal")
signal towerRepaired # 修理塔（参数：花费, 塔节点）
@warning_ignore("unused_signal")
signal lastWaveStarted # 最后一波
@warning_ignore("unused_signal")
signal towerClicked
@warning_ignore("unused_signal")
signal towerLocked # 玩家点了本关禁用的防御塔（tower_ui 发出，map 弹提示）
@warning_ignore("unused_signal")
signal enemyClicked # 点击敌人（在地图上选中敌人，由 enemy.gd 的 input_event 发出）
@warning_ignore("unused_signal")
signal enemyDefeated(enemy, source) # 敌人被击杀（成就统计用；在节点释放前发出）


var map = null

func addObj(obj):
	if map:
		map.add_child(obj)

# ===== 显示名 =====
# towerInfo / enemyInfo 的 "name"（以及 enemyInfo 的 "role"）里存的**直接就是翻译键**，
# 例如 "_TowerName_machineGun" / "_EnemyRole_pusher"。
# 所以取显示名只要一次 tr()，不再需要额外维护三张映射表。

func getTowerDisplayName(tower_type) -> String:
	return tr(str(towerInfo.get(tower_type, {}).get("name", "")))


func getEnemyDisplayName(_enemyType) -> String:
	return tr(str(enemyInfo.get(_enemyType, {}).get("name", "")))


# 敌人行为定位标签（role 字段同样是翻译键）
func getEnemyRoleName(_enemyType) -> String:
	return tr(str(enemyInfo.get(_enemyType, {}).get("role", "")))


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认文本
func t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated: String = tr(key)
	return fallback if translated == key else translated


## ── 战斗模式 ──

## 取某个模式的定义；id 无效时退回 normal 的定义（永远返回可用字典）。
func getBattleModeDef(modeId: String = "") -> Dictionary:
	var key: String = modeId if not modeId.is_empty() else battleMode
	var def = battleModeDefs.get(key, null)
	if def is Dictionary:
		return def
	return battleModeDefs["normal"]


## 切换模式：写 id，并把倍数解出来。
## 这是**唯一**该改 battleMode + 倍数的入口 —— 调用方不要自己写 modeXxxScale。
func setBattleMode(modeId: String) -> void:
	battleMode = modeId if battleModeDefs.has(modeId) else "normal"
	applyBattleModeScales()


## 把 battleMode 对应的倍数写进 modeXxxScale。重复调用是幂等的。
func applyBattleModeScales() -> void:
	var def: Dictionary = getBattleModeDef()
	modeCountScale = float(def.get("countScale", 1.0))
	modeHpScale = float(def.get("hpScale", 1.0))
	modeAtkScale = float(def.get("atkScale", 1.0))
	modeSpeedScale = float(def.get("speedScale", 1.0))
	modeRewardScale = float(def.get("rewardScale", 1.0))
	modeExpScale = float(def.get("expScale", 1.0))
	modeGemScale = float(def.get("gemScale", 1.0))


## 复位成正常模式。离开关卡时必须调（_exit_tree），否则模式会漏到下一局。
func resetBattleMode() -> void:
	setBattleMode("normal")


## 当前模式是否"挑战模式"（不记录星级 / 成就进度）。
func isChallengeMode() -> bool:
	return not bool(getBattleModeDef().get("recordsProgress", true))


## 当前模式的显示名 / 说明（已翻译）。
func getBattleModeName(modeId: String = "") -> String:
	var def: Dictionary = getBattleModeDef(modeId)
	var key: String = str(def.get("name", ""))
	return t(key, key)


func getBattleModeDesc(modeId: String = "") -> String:
	var def: Dictionary = getBattleModeDef(modeId)
	var key: String = str(def.get("desc", ""))
	return t(key, key)
