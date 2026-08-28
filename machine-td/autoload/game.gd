extends Node

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
	droneBase, teslaCoilTower, laserTower
}

# 塔信息
const towerInfo = {
	towerType.machineGunTower: {
	"name": "machineGunTower",
	"atk": 20,
	"cost": 20,
	"reload": 0.2,
	'scope': 300,
	"desc": "_machineGunTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.cannonTower: {
	"name": "cannonTower",
	"atk": 30,
	"cost": 35,
	"reload": 0.8,
	'scope': 320,
	"desc": "_cannonTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.rocketTower: {
	"name": "rocketTower",
	"atk": 40,
	"cost": 50,
	"reload": 1.5,
	'scope': 350,
	"desc": "_rocketTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.EMPTower: {
	"name": "EMPTower",
	"atk": 0,
	"cost": 45,
	"reload": 4.0,
	'scope': 280,
	"desc": "_EMPTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.droneBase: {
	"name": "droneBase",
	"atk": 8,
	"cost": 65,
	"reload": 0.6,
	'scope': 400,
	"desc": "_droneBaseDesc",
	'gridSize': Vector2i(2, 2)
	},
	towerType.teslaCoilTower: {
	"name": "teslaCoilTower",
	"atk": 25,
	"cost": 65,
	"reload": 1.5,
	'scope': 400,
	"desc": "_teslaCoilTowerDesc",
	'gridSize': Vector2i(2, 2)
	},
	towerType.laserTower: {
	"name": "laserTower",
	"atk": 30,
	"cost": 90,
	"reload": 1,
	'scope': 450,
	"desc": "_laserTowerDesc",
	'gridSize': Vector2i(2, 2)
	},
}


# 敌人基础信息（结合 game_analysis 敌人设计，作为初始数值，后续可调参）
# 字段：
#   hp 血量 / speed 移动速度(像素每秒) / reward 击杀金币 / lossPoints 逃脱扣血 / rewardExp 击杀经验
#   armor 物理伤害减免(0~1,能量伤害无视) / flying 空中单位(仅无人机/激光塔可命中)
#   atk 单次攻击伤害(对抗型才有值，推进型为0) / shootDelay 开火间隔秒(对抗型才有值)
# 攻击模式：直射型(DPS=atk/shootDelay) / 远程打击型(追踪导弹，DPS=atk/shootDelay) / 自爆型(一次性总伤害，shootDelay无意义) / 空中直射型(DPS=atk/shootDelay)
const enemyInfo = {
	enemyType.miniTank: {
		"name": "miniTank",
		"hp": 100, "speed": 100, "reward": 5, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": false, "atk": 0, "shootDelay": 1.0
	},
	enemyType.mediumTank: {
		"name": "mediumTank",
		"hp": 200, "speed": 100, "reward": 8, "lossPoints": 2, "rewardExp": 4,
		"armor": 0.0, "flying": false, "atk": 15, "shootDelay": 1.5
	},
	enemyType.heavyTank: {
		"name": "heavyTank",
		"hp": 600, "speed": 50, "reward": 20, "lossPoints": 3, "rewardExp": 10,
		"armor": 0.2, "flying": false, "atk": 0, "shootDelay": 1.0
	},
	enemyType.armoredTank: {
		"name": "armoredTank",
		"hp": 400, "speed": 50, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.5, "flying": false, "atk": 0, "shootDelay": 1.0
	},
	enemyType.assaultBuggy: {
		"name": "assaultBuggy",
		"hp": 80, "speed": 220, "reward": 4, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.1, "flying": false, "atk": 0, "shootDelay": 1.0
	},
	enemyType.medic: {
		"name": "medic",
		"hp": 120, "speed": 100, "reward": 10, "lossPoints": 1, "rewardExp": 5,
		"armor": 0.0, "flying": false, "atk": 0, "shootDelay": 1.0
	},
	enemyType.suicideTruck: {
		"name": "suicideTruck",
		"hp": 60, "speed": 160, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": false, "atk": 150, "shootDelay": 0.0
	},
	enemyType.missileTruck: {
		"name": "missileTruck",
		"hp": 180, "speed": 50, "reward": 12, "lossPoints": 2, "rewardExp": 6,
		"armor": 0.0, "flying": false, "atk": 35, "shootDelay": 3.0
	},
	enemyType.scoutDrone: {
		"name": "scoutDrone",
		"hp": 30, "speed": 160, "reward": 3, "lossPoints": 1, "rewardExp": 2,
		"armor": 0.0, "flying": true, "atk": 0, "shootDelay": 1.0
	},
	enemyType.attackHelicopter: {
		"name": "attackHelicopter",
		"hp": 280, "speed": 100, "reward": 15, "lossPoints": 2, "rewardExp": 8,
		"armor": 0.0, "flying": true, "atk": 5, "shootDelay": 0.5
	},
}

@warning_ignore("unused_signal")
signal defeatEnemy # 击败敌人
@warning_ignore("unused_signal")
signal enemyEscape # 敌人逃脱
@warning_ignore("unused_signal")
signal selectTower # 选择塔
@warning_ignore("unused_signal")
signal placeTower # 放置塔
@warning_ignore("unused_signal")
signal refreshData # 游戏数据刷新
@warning_ignore("unused_signal")
signal sellTower # 出售塔
@warning_ignore("unused_signal")
signal lastWave # 最后一波
@warning_ignore("unused_signal")
signal clickTower


var map = null

func addObj(obj):
	if map:
		map.add_child(obj)
