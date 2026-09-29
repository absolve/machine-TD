extends Node

const TileSize = 64 # 网格大小

# ============================================================
# 敌人生成间隔（秒）—— 按**敌人类型**统一配置
# ============================================================
#
# allStage 里每条 enemySpawner 记录不再手写 'delay'，而是用
#     'delay': ENEMY_SPAWN_DELAY[Game.enemyType.xxx]
# 到这里查表。改节奏只要动这一张表，不用去 16 个关卡里逐个改。
#
# 取值规则：
#   · **最小值 1.6**（低于这个值敌人跟得太紧，看起来还是挤在一起）
#   · **每档递增 0.6**，越重越慢
#
# 当前档位（2026-09-26 第二次拉开）：
#   轻型 1.6  —— 迷你坦克 / 突击车 / 侦察无人机
#   中型 2.2  —— 中型坦克 / 维修车 / 自爆车
#   重型 2.8  —— 重型坦克 / 装甲坦克 / 导弹车 / 攻击直升机
const ENEMY_SPAWN_DELAY := {
	# ── 轻型：1.6 ──
	Game.enemyType.miniTank: 1.6,
	Game.enemyType.assaultBuggy: 1.6,
	Game.enemyType.scoutDrone: 1.6,
	# ── 中型：2.2（+0.6）──
	Game.enemyType.mediumTank: 2.2,
	Game.enemyType.medic: 2.2,
	Game.enemyType.suicideTruck: 2.2,
	# ── 重型：2.8（+0.6）──
	Game.enemyType.heavyTank: 2.8,
	Game.enemyType.armoredTank: 2.8,
	Game.enemyType.missileTruck: 2.8,
	Game.enemyType.attackHelicopter: 2.8,
}

## 取某个敌人类型的生成间隔。表里没配就回落到 1.6（最小值），
## 保证不会出现"没配 → 瞬间刷一堆"的情况。
func getSpawnDelay(enemyType) -> float:
	return float(ENEMY_SPAWN_DELAY.get(enemyType, 1.6))


# 当前选中的关卡ID（由 level_select 点击时设置，map 读取后加载对应场景）
var currentStageId: int = 0

## 各关卡启用的能力技能（key = 关卡 id，值 = 技能 id 数组，顺序即技能条显示顺序）
## 技能 id 定义见 autoload/ability_manager.gd 的 ABILITIES
## 没有列在这里的关卡不会显示技能条
const stageAbilities := {
	0: ["bombard", "invincible"], # 教程：显示全部
	2: ["bombard"],
	3: ["invincible"],
	4: ["bombard", "invincible"],
	5: ["bombard"],
	6: ["invincible"],
	7: ["bombard", "invincible"],
	8: ["bombard"],
	9: ["invincible"],
	10: ["bombard", "invincible"],
	11: ["bombard"],
	12: ["invincible"],
	13: ["bombard", "invincible"],
	14: ["bombard", "invincible"],
	15: ["bombard", "invincible"],
}


# 取某关卡启用的能力技能；未配置的关卡返回空数组（不显示技能条）
func getAbilities(stageId: int) -> Array:
	return stageAbilities.get(stageId, [])


## 各关卡**允许建造**的防御塔（key = 关卡 id，值 = 塔类型数组）
## 没有列在这里的关卡 = 不限制（tower_ui 会显示全部 7 座）
## 想放开某关就从这张表里删掉它，或补上缺的塔类型
var stageTowers: Dictionary = {
	#0: [Game.towerType.machineGunTower, Game.towerType.cannonTower, Game.towerType.rocketTower],
	1: [Game.towerType.machineGunTower, Game.towerType.cannonTower, Game.towerType.rocketTower],
	2: [Game.towerType.machineGunTower, Game.towerType.cannonTower, Game.towerType.rocketTower,
		Game.towerType.EMPTower],
	3: [Game.towerType.machineGunTower, Game.towerType.cannonTower, Game.towerType.rocketTower,
		Game.towerType.EMPTower, Game.towerType.teslaCoilTower],
	4: [Game.towerType.machineGunTower, Game.towerType.cannonTower, Game.towerType.rocketTower,
		Game.towerType.EMPTower, Game.towerType.teslaCoilTower, Game.towerType.laserTower],
	# 5 关及以后不配置 = 全部可建
}

# 取某关卡允许建造的塔；返回空数组表示「不限制」
func getTowers(stageId: int) -> Array:
	return stageTowers.get(stageId, [])

# 该关卡是否允许建造某种塔
func isTowerAllowed(stageId: int, tower_type) -> bool:
	var allowed: Array = getTowers(stageId)
	if allowed.is_empty():
		return true
	return tower_type in allowed


## 某关卡声明的路线数（默认 1）。
## 真正的路线节点在关卡场景里 —— 场景里按顺序摆几个 Path2D 就有几条路线。
## 这个字段是给 UI / 一致性校验用的声明值，两边对不上时 base_level 会 push_warning。
func getRouteCount(stageId: int) -> int:
	for s in allStage:
		if int(s.get("id", -1)) == stageId:
			return maxi(1, int(s.get("routes", 1)))
	return 1


#关卡的数据
#
# enemySpawner 里每一条的写法：
#     {'time': 波次, 'type': 敌人类型, 'number': 数量}
#     {'time': 波次, 'type': 敌人类型, 'number': 数量, 'route': 路线号}   # 可选
#     {'time': 波次, 'type': 敌人类型, 'number': 数量, 'offset': 出发偏移}  # 可选，可与 route 同写
#
# 'route' 不写 = 从**路线1**出发；写 2、3 …… 就从对应路线出发。
# 路线号从 1 开始，对应关卡场景里 Path2D 的摆放顺序（第 1 个 Path2D 就是路线1）。
# 单路线关卡里写 'route': 2 不会出错，会自动回落到最后一条路线。
#
# 'offset' 不写 = 0（敌人贴着路线中线走）。
# 有些关卡的路线两边各压着一条传送带，中线正好落在两条带子中间，敌人看着就"错位"；
# 给一个**固定**的偏移（±32 = 半个格子，正好对到带子中线上）就能整条路都贴住其中一条。
# 单位：像素；正数 = **行进方向的右侧**，负数 = 左侧。偏移算在路线自己的坐标系里
# （PathFollow2D 的 v_offset），所以拐弯时会跟着一起拐，始终平行于中线。
# 想让同一波的敌人分走两条带子，就写两条 time 相同、offset 相反、route 相同的记录。
#
# 生成间隔**不在这里逐条写** —— 统一由上面的 ENEMY_SPAWN_DELAY 表按敌人类型决定。
# 生成器会一次只放一个敌人，放完按"下一个敌人的兵种"查表排下一拍，
# 所以同一时刻写再多记录也不会叠在一帧刷出来。
# 本关想整体放慢/加快，用 'spawnInterval'（只对表里没配的兵种生效）。
var allStage = [
	{
		'name': 'Tutorial',
		"id": 0,
		'routes': 1,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 3,
		'selectable': false,
		'type': '工厂',
		'category': '厂前空地',
		'description': '厂前空地。教程关卡，单向直线，逐一认识各类敌人的威胁与节奏',
		'wave': 10,
		'health': 25,
		'money': 1200,
		'spawnInterval': 1.0,   # 兜底间隔(秒)：只对 ENEMY_SPAWN_DELAY 表里没配的兵种生效
		'scene': 'res://scene/level/level_tutorial.tscn',
		# ★ 2026-09-26 改成"大量敌人"压力测试场：
		#   原来每波只有 1 个敌人（全关共 10 个），根本测不出满屏敌人的表现。
		#   现在全关约 247 个敌人，逐波加压：前几波铺基础兵，中段上重甲/支援，
		#   后段把快兵（突击车/自爆车/侦察无人机）和空军（直升机）混编一起冲。
		#   生成间隔由 ENEMY_SPAWN_DELAY 表按兵种决定（轻型 1.0 / 中型 1.4 / 重型 1.8），
		#   这里不用逐条写 delay。
		"enemySpawner": [
			# ── 第 1 波：迷你坦克铺路 ──
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 12},
			# ── 第 2 波：加入突击车（快兵，考验射程覆盖）──
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 12},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 8},
			# ── 第 3 波：中型坦克开始还击 ──
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 10},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 8},
			# ── 第 4 波：首台重甲，检测单体高血量 ──
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 10},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 5},
			# ── 第 5 波：维修车登场（会奶自己人）──
			{'time': 5, 'type': Game.enemyType.miniTank, 'number': 14},
			{'time': 5, 'type': Game.enemyType.medic, 'number': 4},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6},
			# ── 第 6 波：装甲坦克（高减伤）+ 自爆车 ──
			{'time': 6, 'type': Game.enemyType.armoredTank, 'number': 6},
			{'time': 6, 'type': Game.enemyType.mediumTank, 'number': 10},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 6},
			# ── 第 7 波：自爆车集群冲击 ──
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 14},
			{'time': 7, 'type': Game.enemyType.miniTank, 'number': 12},
			{'time': 7, 'type': Game.enemyType.assaultBuggy, 'number': 8},
			# ── 第 8 波：首次出现空军 ──
			{'time': 8, 'type': Game.enemyType.scoutDrone, 'number': 10},
			{'time': 8, 'type': Game.enemyType.attackHelicopter, 'number': 5},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 5},
			# ── 第 9 波：导弹车远程压制 ──
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 12},
			{'time': 9, 'type': Game.enemyType.mediumTank, 'number': 12},
			{'time': 9, 'type': Game.enemyType.medic, 'number': 5},
			# ── 第 10 波：总攻，所有兵种混编一起上 ──
			{'time': 10, 'type': Game.enemyType.heavyTank, 'number': 8},
			{'time': 10, 'type': Game.enemyType.armoredTank, 'number': 8},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 5},
			{'time': 10, 'type': Game.enemyType.suicideTruck, 'number': 10},
			{'time': 10, 'type': Game.enemyType.assaultBuggy, 'number': 10},
			{'time': 10, 'type': Game.enemyType.miniTank, 'number': 12}
		]
	},
	{
		'name': '1',
		"id": 1,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 5,
		'type': '工厂',
		'category': '厂区大门',
		'description': '敌人从厂区正门涌入，路线开阔，适合熟悉防守节奏',
		'wave': 3,
		'health': 20,
		'money': 150,
		'scene': 'res://scene/level/level_1.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 7, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 18, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 8, 'route': 2},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 20, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 21, 'route': 2}
		]
	},
	{
		'name': '2',
		"id": 2,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 6,
		'type': '工厂',
		'category': '门岗与装卸区',
		'description': '装卸区通道变宽，敌人开始成群从正门压上',
		'wave': 5,
		'health': 18,
		'money': 200,
		'scene': 'res://scene/level/level_2.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 4, 'route': 2},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 2},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 7, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 2},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.miniTank, 'number': 9, 'route': 1},
			{'time': 4, 'type': Game.enemyType.miniTank, 'number': 9, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2}
		]
	},
	{
		'name': '3',
		"id": 3,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 7,
		'type': '工厂',
		'category': '原料堆场',
		'description': '原料堆场道路收窄，第一次出现重型目标',
		'wave': 5,
		'health': 18,
		'money': 220,
		'scene': 'res://scene/level/level_3.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 10, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 11, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 10, 'route': 2},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 2},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1}
		]
	},
	{
		'name': '4',
		"id": 4,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 8,
		'type': '工厂',
		'category': '一号传送带',
		'description': '沿一号传送带布防，转角增多，自爆车开始出现',
		'wave': 7,
		'health': 16,
		'money': 190,
		'scene': 'res://scene/level/level_4.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 2},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 3, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 2},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 2},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 1},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 2},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 1},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 1},
			{'time': 7, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 2}
		]
	},
	{
		'name': '5',
		"id": 5,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 9,
		'type': '工厂',
		'category': '装配车间',
		'description': '进入装配车间，夹道更长，导弹车首次登场',
		'wave': 8,
		'health': 14,
		'money': 230,
		'scene': 'res://scene/level/level_5.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 2, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 3, 'route': 2},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 1},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 2, 'route': 2},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 2},
			{'time': 4, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 7, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2}
		]
	},
	{
		'name': '6',
		"id": 6,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 10,
		'type': '工厂',
		'category': '焊接车间',
		'description': '焊接车间内通道交错，空中与地面单位混合来袭',
		'wave': 9,
		'health': 12,
		'money': 280,
		'scene': 'res://scene/level/level_6.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 2},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 1},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 4, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 1},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 2},
			{'time': 4, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 1},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 5, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 1},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 2},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 8, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 8, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2}
		]
	},
	{
		'name': '7',
		"id": 7,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 11,
		'type': '工厂',
		'category': '喷涂车间',
		'description': '喷涂车间纵深更长，敌人密度明显提升',
		'wave': 10,
		'health': 12,
		'money': 320,
		'scene': 'res://scene/level/level_7.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 3, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 3, 'route': 2},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 1, 'route': 1},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 4, 'route': 1},
			{'time': 3, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 2},
			{'time': 4, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 2},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 1},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 1},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 2},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 10, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 10, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2}
		]
	},
	{
		'name': '8',
		"id": 8,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 12,
		'type': '工厂',
		'category': '质检线',
		'description': '质检线道路更窄，远程与空中单位密度提高',
		'wave': 11,
		'health': 11,
		'money': 360,
		'scene': 'res://scene/level/level_8.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 2},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 1},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 5, 'route': 2},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 1},
			{'time': 3, 'type': Game.enemyType.assaultBuggy, 'number': 4, 'route': 2},
			{'time': 4, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 4, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 1},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 5, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 5, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 2},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 1},
			{'time': 6, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 7, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 1},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 10, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 10, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 11, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 11, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2}
		]
	},
	{
		'name': '9',
		"id": 9,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 13,
		'type': '工厂',
		'category': '成品仓库',
		'description': '成品仓库高数量敌群压境，防线需要持续压制',
		'wave': 12,
		'health': 11,
		'money': 400,
		'scene': 'res://scene/level/level_9.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 1, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 2},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 1},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 1},
			{'time': 2, 'type': Game.enemyType.assaultBuggy, 'number': 5, 'route': 2},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 4, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 5, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 5, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 1},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 2},
			{'time': 9, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 9, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 10, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 10, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 11, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 11, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 12, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 12, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2}
		]
	},
	{
		'name': '10',
		"id": 10,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 14,
		'type': '工厂',
		'category': '中央控制室',
		'description': '通往中央控制室，综合考验地面、空中与远程防守',
		'wave': 13,
		'health': 10,
		'money': 450,
		'scene': 'res://scene/level/level_10.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 1},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 1},
			{'time': 2, 'type': Game.enemyType.miniTank, 'number': 6, 'route': 2},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 4, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 6, 'route': 2},
			{'time': 5, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 5, 'type': Game.enemyType.suicideTruck, 'number': 1, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 8, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 8, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 1},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 2},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 11, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 11, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 12, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 12, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 13, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 13, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2}
		]
	},
	{
		'name': '11',
		"id": 11,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 15,
		'type': '工厂',
		'category': '地下管廊',
		'description': '转入地下管廊，高密度重型单位连续出现',
		'wave': 14,
		'health': 10,
		'money': 500,
		'scene': 'res://scene/level/level_11.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 2, 'route': 2},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 7, 'route': 2},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 2},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 1},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 1},
			{'time': 7, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 1},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2}
		]
	},
	{
		'name': '12',
		"id": 12,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 16,
		'type': '工厂',
		'category': '动力机房',
		'description': '动力机房内多类型复合波次持续不断',
		'wave': 15,
		'health': 9,
		'money': 550,
		'scene': 'res://scene/level/level_12.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 8, 'route': 2},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 1},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 1, 'route': 2},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 1, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 1},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 9, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 9, 'route': 2},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 1},
			{'time': 8, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 2},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 9, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 11, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 11, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 2},
			{'time': 12, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 12, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 14, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 14, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 15, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 15, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2}
		]
	},
	{
		'name': '13',
		"id": 13,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 17,
		'type': '工厂',
		'category': '自动化仓储',
		'description': '自动化仓储，远程火力与重型单位同步增强',
		'wave': 16,
		'health': 9,
		'money': 600,
		'scene': 'res://scene/level/level_13.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 3, 'route': 2},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 9, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 9, 'route': 2},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 1},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 1},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 2},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 2, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 1},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 4, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 1},
			{'time': 5, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 5, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 5, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 8, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 2},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 9, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 10, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 2},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 1},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 1},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 1},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 2},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 2}
		]
	},
	{
		'name': '14',
		"id": 14,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 18,
		'type': '工厂',
		'category': '核心装配线',
		'description': '核心装配线，高数量、高强度的综合防守',
		'wave': 17,
		'health': 8,
		'money': 650,
		'scene': 'res://scene/level/level_14.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 10, 'route': 2},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 1},
			{'time': 1, 'type': Game.enemyType.scoutDrone, 'number': 4, 'route': 2},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 1},
			{'time': 2, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.missileTruck, 'number': 2, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 2, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 3, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 11, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 11, 'route': 2},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 5, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 6, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 6, 'route': 2},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 6, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 7, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 1},
			{'time': 7, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 2},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 1},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 1},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 10, 'type': Game.enemyType.assaultBuggy, 'number': 12, 'route': 1},
			{'time': 10, 'type': Game.enemyType.assaultBuggy, 'number': 12, 'route': 2},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 5, 'route': 1},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 2},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 2},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 1},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 2},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 1},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 2},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 7, 'route': 1},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 7, 'route': 2},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 5, 'route': 1},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 2},
			{'time': 17, 'type': Game.enemyType.heavyTank, 'number': 6, 'route': 1},
			{'time': 17, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 2}
		]
	},
	{
		'name': '15',
		"id": 15,
		'routes': 2,   # 本关路线数（和场景里 Path2D 的数量对应）
		"gemReward": 20,
		'type': '工厂',
		'category': '工厂核心',
		'description': '工厂核心，最终关卡，迎接最大规模的敌群',
		'wave': 18,
		'health': 8,
		'money': 720,
		'scene': 'res://scene/level/level_15.tscn',
		"enemySpawner": [
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 5, 'route': 1},
			{'time': 1, 'type': Game.enemyType.mediumTank, 'number': 4, 'route': 2},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 11, 'route': 1},
			{'time': 1, 'type': Game.enemyType.assaultBuggy, 'number': 11, 'route': 2},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 1},
			{'time': 2, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 5, 'route': 1},
			{'time': 2, 'type': Game.enemyType.scoutDrone, 'number': 5, 'route': 2},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 1},
			{'time': 3, 'type': Game.enemyType.heavyTank, 'number': 3, 'route': 2},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 1},
			{'time': 3, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 1},
			{'time': 4, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 2},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 12, 'route': 1},
			{'time': 4, 'type': Game.enemyType.assaultBuggy, 'number': 12, 'route': 2},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 5, 'type': Game.enemyType.missileTruck, 'number': 3, 'route': 2},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 1},
			{'time': 5, 'type': Game.enemyType.mediumTank, 'number': 6, 'route': 2},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 1},
			{'time': 6, 'type': Game.enemyType.heavyTank, 'number': 4, 'route': 2},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 7, 'route': 1},
			{'time': 6, 'type': Game.enemyType.scoutDrone, 'number': 7, 'route': 2},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 1},
			{'time': 7, 'type': Game.enemyType.attackHelicopter, 'number': 3, 'route': 2},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 5, 'route': 1},
			{'time': 7, 'type': Game.enemyType.suicideTruck, 'number': 4, 'route': 2},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 1},
			{'time': 8, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 2},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 1},
			{'time': 8, 'type': Game.enemyType.heavyTank, 'number': 5, 'route': 2},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 1},
			{'time': 9, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 2},
			{'time': 10, 'type': Game.enemyType.assaultBuggy, 'number': 13, 'route': 1},
			{'time': 10, 'type': Game.enemyType.assaultBuggy, 'number': 13, 'route': 2},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 5, 'route': 1},
			{'time': 11, 'type': Game.enemyType.suicideTruck, 'number': 5, 'route': 2},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 5, 'route': 1},
			{'time': 12, 'type': Game.enemyType.missileTruck, 'number': 4, 'route': 2},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 6, 'route': 1},
			{'time': 13, 'type': Game.enemyType.heavyTank, 'number': 6, 'route': 2},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 5, 'route': 1},
			{'time': 14, 'type': Game.enemyType.attackHelicopter, 'number': 4, 'route': 2},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 8, 'route': 1},
			{'time': 15, 'type': Game.enemyType.mediumTank, 'number': 8, 'route': 2},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 5, 'route': 1},
			{'time': 16, 'type': Game.enemyType.missileTruck, 'number': 5, 'route': 2},
			{'time': 17, 'type': Game.enemyType.suicideTruck, 'number': 6, 'route': 1},
			{'time': 17, 'type': Game.enemyType.suicideTruck, 'number': 6, 'route': 2},
			{'time': 18, 'type': Game.enemyType.heavyTank, 'number': 7, 'route': 1},
			{'time': 18, 'type': Game.enemyType.heavyTank, 'number': 7, 'route': 2}
		]
	},
]

var enemyScenes = {
	Game.enemyType.miniTank: preload("res://scene/enemy/miniTank.tscn"),
	Game.enemyType.mediumTank: preload("res://scene/enemy/medium_tank.tscn"),
	Game.enemyType.heavyTank: preload("res://scene/enemy/heavy_tank.tscn"),
	Game.enemyType.armoredTank: preload("res://scene/enemy/armored_tank.tscn"),
	Game.enemyType.assaultBuggy: preload("res://scene/enemy/assault_buggy.tscn"),
	Game.enemyType.medic: preload("res://scene/enemy/medic.tscn"),
	Game.enemyType.suicideTruck: preload("res://scene/enemy/suicide_truck.tscn"),
	Game.enemyType.missileTruck: preload("res://scene/enemy/missile_truck.tscn"),
	Game.enemyType.scoutDrone: preload("res://scene/enemy/scout_drone.tscn"),
	Game.enemyType.attackHelicopter: preload("res://scene/enemy/attack_helicopter.tscn")
}
