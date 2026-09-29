extends Node

signal towerLeveledUp(tower, level) # 防御塔升级（成就统计用）

const MAX_LEVEL: int = 3  # 最大等级

# ★ 升级数值规范（2026-09-26 第三次调整）：
#   · **Lv.3 的 atk 也必须 < 100**
#   · 基础塔的 scope 已被大幅缩短（140~240），敌人穿过单塔射程只有 3~4 秒，
#     所以 DPS 不能再压 —— 否则一塔一辈子只能打掉三四十点血、完全拦不住。
#     这里让 Lv2/Lv3 的 DPS 大约是 Lv1 的 1.9x / 2.7x。
const configs: Dictionary = {
	Game.towerType.machineGunTower: {
		"exp2": 8,
		"exp3": 18,
		"lv2": {"atk": 22, "reload": 0.36, "scope": 165},
		"lv3": {"atk": 31, "reload": 0.30, "scope": 185},
	},
	Game.towerType.cannonTower: {
		"exp2": 12,
		"exp3": 28,
		"lv2": {"atk": 44, "reload": 0.45, "scope": 205},
		"lv3": {"atk": 62, "reload": 0.38, "scope": 235},
	},
	Game.towerType.rocketTower: {
		"exp2": 15,
		"exp3": 32,
		"lv2": {"atk": 56, "reload": 0.90, "scope": 205},
		"lv3": {"atk": 78, "reload": 0.75, "scope": 235},
	},
	Game.towerType.droneBase: {
		"exp2": 18,
		"exp3": 40,
		"lv2": {"atk": 10, "reload": 0.18, "scope": 270},
		"lv3": {"atk": 14, "reload": 0.15, "scope": 300},
	},
	Game.towerType.teslaCoilTower: {
		"exp2": 20,
		"exp3": 45,
		"lv2": {"atk": 30, "reload": 0.85, "scope": 270},
		"lv3": {"atk": 42, "reload": 0.72, "scope": 305},
	},
	Game.towerType.laserTower: {
		"exp2": 22,
		"exp3": 50,
		"lv2": {"atk": 32, "reload": 0.75, "scope": 270},
		"lv3": {"atk": 44, "reload": 0.62, "scope": 305},
	},
	Game.towerType.EMPTower: {
		"exp2": 16,
		"exp3": 36,
		"lv2": {"atk": 50, "reload": 3.4, "scope": 165},
		"lv3": {"atk": 70, "reload": 2.8, "scope": 190},
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
