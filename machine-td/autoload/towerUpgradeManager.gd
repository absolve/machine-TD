extends Node

signal tower_leveled_up(tower, level) # 防御塔升级（成就统计用）

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
		"lv2": {"atk": 55, "reload": 3.4, "scope": 315},
		"lv3": {"atk": 60, "reload": 2.8, "scope": 350},
	},
}

# 不参与升级的塔
# EMP 干扰塔只做减速、不造成任何伤害，因此拿不到击杀经验，默认停在 Lv.1。
# 它的 lv2 / lv3 配置保留在 configs 里，将来如果给它接上独立经验来源
# （例如"减速覆盖时长"或"助攻计数"），把这里删掉即可直接启用。
const NON_UPGRADABLE: Array = [Game.towerType.EMPTower]

# 获取当前等级的经验阈值
func getExpThreshold(towerType: Game.towerType, currentLevel: int) :
	match currentLevel:
		1:
			return configs[towerType]["exp2"]
		2:
			return configs[towerType]["exp3"]	
		_:
			return INF

# 该塔类型是否参与升级：既要有效配置，也不能在排除名单里
func canUpgrade(towerType) -> bool:
	return configs.has(towerType) and not (towerType in NON_UPGRADABLE)

# 获取目标等级的最终属性
func getLevelConfig(towerType: Game.towerType, targetLevel: int) -> Dictionary:
	if not configs.has(towerType):
		return {}
	return configs[towerType].get("lv%d" % targetLevel, {})
