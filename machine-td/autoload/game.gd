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
	scoutDrone, attackHelicopter
}

# 塔类型
enum towerType {
	machineGunTower = 1000, cannonTower, rocketTower, EMPTower,
	droneBase, teslaCoilTower, laserTower, ironBox
}

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
	"atk": 14, # DPS 35（scope 只有 140，覆盖窗口短，DPS 不能再压）
	"cost": 20,
	"reload": 0.4,
	"scope": 140,
	"hp": 120,
	"maxHp": 120,
	"initTime": 0.6,
	"desc": "_machineGunTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.cannonTower: {
	"name": "_TowerName_cannon",
	"atk": 30, # DPS 60（单发高、打得慢）
	"cost": 35,
	"reload": 0.5,
	"scope": 180,
	"hp": 180,
	"maxHp": 180,
	"initTime": 0.9,
	"desc": "_cannonTowerDesc",
	"gridSize": Vector2i(1, 1)
	},
	towerType.rocketTower: {
	"name": "_TowerName_rocket",
	"atk": 40, # DPS 40，范围伤害
	"cost": 50,
	"reload": 1.0,
	"scope": 180,
	"hp": 220,
	"maxHp": 220,
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
	"scope": 240,
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
	"hp": 240,
	"maxHp": 240,
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
	"hp": 400,
	"maxHp": 400,
	"initTime": 1.0,
	"desc": "_ironBoxDesc",
	"gridSize": Vector2i(1, 1)
	}
}


# 敌人基础信息
# 字段：
#   hp 血量 / speed 移动速度(像素每秒) / reward 击杀金币 / lossPoints 逃脱扣血 / rewardExp 击杀经验
#   armor 物理伤害减免(0~1,能量伤害无视) / flying 空中单位(仅无人机/激光塔可命中)
#   atk 单次攻击伤害(对抗型才有值，推进型为0) / shootDelay 开火间隔秒(对抗型才有值)
#   scope 雷达半径(像素)：对抗/支援型的攻击或支援范围，推进型为0(不参战，雷达不侦测)
#   role 行为定位（用于信息面板标签）：pusher 推进型 / attacker 对抗型 / support 支援型 / bomber 自爆型 / siege 远程打击型 / air 空中单位
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
		"hp": 150, "speed": 50, "reward": 5, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.05, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.mediumTank: {
		"name": "_EnemyName_mediumTank",
		"hp": 300, "speed": 45, "reward": 8, "lossPoints": 2, "rewardExp": 4,
		"armor": 0.15, "flying": false, "atk": 15, "shootDelay": 0.9, "scope": 240, "role": "_EnemyRole_attacker"
	},
	enemyType.heavyTank: {
		"name": "_EnemyName_heavyTank",
		"hp": 600, "speed": 30, "reward": 20, "lossPoints": 3, "rewardExp": 10,
		"armor": 0.4, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.armoredTank: {
		"name": "_EnemyName_armoredTank",
		"hp": 360, "speed": 35, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.6, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.assaultBuggy: {
		"name": "_EnemyName_assaultBuggy",
		"hp": 120, "speed": 115, "reward": 4, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.1, "flying": false, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_pusher"
	},
	enemyType.medic: {
		"name": "_EnemyName_medic",
		"hp": 180, "speed": 50, "reward": 10, "lossPoints": 1, "rewardExp": 5,
		"armor": 0.1, "flying": false, "atk": 20, "shootDelay": 3.0, "scope": 180, "role": "_EnemyRole_support"
	},
	enemyType.suicideTruck: {
		"name": "_EnemyName_suicideTruck",
		"hp": 90, "speed": 90, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": false, "atk": 90, "shootDelay": 0.0, "scope": 150, "role": "_EnemyRole_bomber"
	},
	enemyType.missileTruck: {
		"name": "_EnemyName_missileTruck",
		"hp": 260, "speed": 40, "reward": 12, "lossPoints": 2, "rewardExp": 6,
		"armor": 0.25, "flying": false, "atk": 35, "shootDelay": 1.8, "scope": 700, "role": "_EnemyRole_siege"
	},
	enemyType.scoutDrone: {
		"name": "_EnemyName_scoutDrone",
		"hp": 45, "speed": 130, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": true, "atk": 0, "shootDelay": 1.0, "scope": 0, "role": "_EnemyRole_air"
	},
	enemyType.attackHelicopter: {
		"name": "_EnemyName_attackHelicopter",
		"hp": 380, "speed": 80, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.2, "flying": true, "atk": 5, "shootDelay": 0.25, "scope": 300, "role": "_EnemyRole_air"
	},
}

#支持的语言
const language = [ {'text': 'English', 'code': 'en', 'id': 0},
 {'text': '简体中文', 'code': 'zh', 'id': 1}]
	

@warning_ignore("unused_signal")
signal enemyRewarded # 击败敌人
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
