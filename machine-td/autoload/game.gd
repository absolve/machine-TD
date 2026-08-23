extends Node

enum bulletType {
	player, enemy
}

# 敌人类型
enum enemyType {
	miniTank, mediumTank, heavyTank
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
	"atk": 10,
	"cost": 10,
	"reload": 0.1,
	'scope':128,
	"desc": "_machineGunTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.cannonTower: {
	"name": "cannonTower",
	"atk": 30,
	"cost": 20,
	"reload": 0.5,
	'scope':128,
	"desc": "_cannonTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.rocketTower: {
	"name": "rocketTower",
	"atk": 20,
	"cost": 30,
	"reload": 0.5,
	'scope':128,
	"desc": "_rocketTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.EMPTower: {
	"name": "EMPTower",
	"atk": 0,
	"cost": 40,
	"reload": 0,
	'scope':128,
	"desc": "_EMPTowerDesc",
	'gridSize': Vector2i(1, 1)
	},
	towerType.droneBase: {
	"name": "droneBase",
	"atk": 5,
	"cost": 50,
	"reload": 5,
	'scope':128,
	"desc": "_droneBaseDesc",
	'gridSize': Vector2i(2, 2)
	},
	towerType.teslaCoilTower: {
	"name": "teslaCoilTower",
	"atk": 40,
	"cost": 50,
	"reload": 2,
	'scope':128,
	"desc": "_teslaCoilTowerDesc",
	'gridSize': Vector2i(2, 2)
	},
	towerType.laserTower: {
	"name": "laserTower",
	"atk": 40,
	"cost": 60,
	"reload": 1,
	'scope':128,
	"desc": "_laserTowerDesc",
	'gridSize': Vector2i(2, 2)
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
