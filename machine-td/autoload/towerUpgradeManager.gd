extends Node

const MAX_LEVEL: int = 3  # 最大等级

const configs: Dictionary = {
	Game.towerType.machineGunTower: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
	Game.towerType.cannonTower: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
	Game.towerType.rocketTower: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
	Game.towerType.droneBase: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
	Game.towerType.teslaCoilTower: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
	Game.towerType.laserTower: {
		"exp2": 10,
		"exp3": 20,
		"lv2": {},
		"lv3": {},
	},
}

# 获取当前等级的经验阈值
func getExpThreshold(towerType: Game.towerType, currentLevel: int) :
	match currentLevel:
		2:
			return configs[towerType]["exp2"]
		3:
			return configs[towerType]["exp3"]	
		_:
			return INF


