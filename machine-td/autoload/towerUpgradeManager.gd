extends Node

const MAX_LEVEL: int = 3  # 最大等级

const configs: Dictionary = {
	Game.towerType.machineGunTower: {
		"exp2": 8,
		"exp3": 18,
		"lv2": {"atk": 24, "reload": 0.18, "scope": 315},
		"lv3": {"atk": 29, "reload": 0.16, "scope": 330},
	},
	Game.towerType.cannonTower: {
		"exp2": 12,
		"exp3": 28,
		"lv2": {"atk": 39, "reload": 0.72, "scope": 340},
		"lv3": {"atk": 50, "reload": 0.65, "scope": 360},
	},
	Game.towerType.rocketTower: {
		"exp2": 15,
		"exp3": 32,
		"lv2": {"atk": 52, "reload": 1.35, "scope": 375},
		"lv3": {"atk": 68, "reload": 1.2, "scope": 400},
	},
	Game.towerType.droneBase: {
		"exp2": 18,
		"exp3": 40,
		"lv2": {"atk": 10, "reload": 0.54, "scope": 440},
		"lv3": {"atk": 13, "reload": 0.48, "scope": 480},
	},
	Game.towerType.teslaCoilTower: {
		"exp2": 20,
		"exp3": 45,
		"lv2": {"atk": 32, "reload": 1.35, "scope": 440},
		"lv3": {"atk": 42, "reload": 1.2, "scope": 480},
	},
	Game.towerType.laserTower: {
		"exp2": 22,
		"exp3": 50,
		"lv2": {"atk": 39, "reload": 0.92, "scope": 480},
		"lv3": {"atk": 51, "reload": 0.84, "scope": 510},
	},
	Game.towerType.EMPTower: {
		"exp2": 16,
		"exp3": 36,
		"lv2": {"atk": 0, "reload": 3.4, "scope": 315},
		"lv3": {"atk": 0, "reload": 2.8, "scope": 350},
	},
}

# 获取当前等级的经验阈值
func getExpThreshold(towerType: Game.towerType, currentLevel: int) :
	match currentLevel:
		1:
			return configs[towerType]["exp2"]
		2:
			return configs[towerType]["exp3"]	
		_:
			return INF

# 获取目标等级的最终属性
func getLevelConfig(towerType: Game.towerType, targetLevel: int) -> Dictionary:
	if not configs.has(towerType):
		return {}
	return configs[towerType].get("lv%d" % targetLevel, {})
