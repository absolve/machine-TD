extends "res://script/level/base_level.gd"
## 无尽模式关卡（与 15 个关卡平级，但**不读 allStage**：map.gd 传的是 levelId = -1）。
##
## 和普通关卡的区别：
##   · 数值写在脚本里（10 血 / 400 金），不从 StageData 读；
##   · 波次编制**现场生成**（覆写 buildWaveSpawner），按波次解锁兵种、两条地面带子各分一半；
##   · `wave` 设成极大值，`currWave >= wave` 永不成立 → **永不"通关"**，只有基地被打爆；
##   · 难度按波次缩放（Game.enemyScale / Game.enemyAtkScale / spawnDelayScale）。
##
## 地图路线（见 endless_mode_design.md §4.2，双带并排 U 形）：
##   路线1 = row3（东行）→ col28 回头 → row11（西行）；
##   路线2 = row4（东行）→ col29 回头 → row12（西行）；两条带子全程相邻并排。
##   路线3 = 空中航线（无人机 / 攻击直升机 / 战斗飞机走这条）。

## ── 本关固定数值 ──
const ENDLESS_HEALTH: int = 10 # 基地血量：漏 10 个就结束（无尽固定 10）
const ENDLESS_MONEY: int = 400 # 起始金钱：够立 3~4 座塔
const ENDLESS_WAVE: int = 999999 # 总波数（形同无限，用来关掉"通关"判断）

## ── 同屏（＝单波总数）上限 ──
## 因为"上一波清空才开下一波"，波内总数就等于同屏上限。
## 你现在的要求是"起码 60+ 才有气势"，所以取 90；实测掉帧就调这个数。
const WAVE_CAP: int = 90
const WAVE_BASE: int = 18 # 第 1 波的敌人数量
const WAVE_STEP: float = 3.2 # 每波递增

## ── 难度缩放（设计文档 §5.3）──
const HP_SCALE_STEP: float = 0.15 # 每波敌人血量 +15%
const ATK_SCALE_STEP: float = 0.05 # 每波敌人攻击 +5%
const DELAY_SCALE_STEP: float = 0.015 # 每波出怪间隔 ×(1-1.5%)
const DELAY_SCALE_MIN: float = 0.45 # 出怪间隔缩放下限
const BOSS_INTERVAL: int = 5 # 每 5 波一个"高潮波"（数量 ×1.2）
const AIR_ROUTE: int = 3 # 空中航线 = 路线3
## 地图上应有的路线条数（路线1/2＝两条并排地面带子，路线3＝空中航线）。
## 摆缺了的话 getRoute() 会「回落到最后一条」，敌人全挤在一条路上 —— 见 _ready 的警告。
const ROUTE_TOTAL: int = 3

## 兵种解锁波次（设计文档 §5.1）
const UNLOCK: Array = [
	[1, Game.enemyType.miniTank],
	[3, Game.enemyType.assaultBuggy],
	[6, Game.enemyType.mediumTank],
	[9, Game.enemyType.scoutDrone],
	[12, Game.enemyType.suicideTruck],
	[12, Game.enemyType.medic],
	[15, Game.enemyType.heavyTank],
	[18, Game.enemyType.missileTruck],
	[18, Game.enemyType.attackHelicopter],
	[22, Game.enemyType.armoredTank],
	[25, Game.enemyType.battlePlane],
	[28, Game.enemyType.experimentalTank],
]

## 每种兵的数量基准（第 1 次解锁时的量）与上限
const COUNT_BASE := {
	Game.enemyType.miniTank: 8,
	Game.enemyType.assaultBuggy: 6,
	Game.enemyType.mediumTank: 4,
	Game.enemyType.scoutDrone: 4,
	Game.enemyType.suicideTruck: 3,
	Game.enemyType.medic: 2,
	Game.enemyType.heavyTank: 3,
	Game.enemyType.missileTruck: 2,
	Game.enemyType.attackHelicopter: 2,
	Game.enemyType.armoredTank: 3,
	Game.enemyType.battlePlane: 2,
	Game.enemyType.experimentalTank: 1,
}
const COUNT_CAP := {
	Game.enemyType.miniTank: 40,
	Game.enemyType.assaultBuggy: 30,
	Game.enemyType.mediumTank: 20,
	Game.enemyType.scoutDrone: 14,
	Game.enemyType.suicideTruck: 18,
	Game.enemyType.medic: 6,
	Game.enemyType.heavyTank: 14,
	Game.enemyType.missileTruck: 10,
	Game.enemyType.attackHelicopter: 10,
	Game.enemyType.armoredTank: 14,
	Game.enemyType.battlePlane: 10,
	Game.enemyType.experimentalTank: 5,
}

## 空中兵种：走路线3（`collectRoutes()` 里第 3 个 Path2D）
const AIR_TYPES: Array = [
	Game.enemyType.scoutDrone,
	Game.enemyType.attackHelicopter,
	Game.enemyType.battlePlane,
]

## 占位地图用的可建造格（M2 摆好真实 placeableArea 之后自动让位，见 _ready）
const FALLBACK_SLOT_ROWS: Array = [6, 7, 8, 9] # 两条带子之间那片"双倍覆盖区"
const FALLBACK_SLOT_COLS: Array = [1, 28]

## 本局统计（结算面板/最高记录用）：击杀总数 + 开局时间戳
var kills: int = 0
var startedAtMsec: int = 0


func _ready() -> void:
	super()
	# 数值：levelId = -1 在 allStage 里匹配不到，所以这里直接给
	wave = ENDLESS_WAVE
	health = ENDLESS_HEALTH
	money = ENDLESS_MONEY
	# 空中航线也要提示（地面两条都铺了带子，玩家一眼看得出走向）
	hintRoutes = [AIR_ROUTE]
	# 路线摆缺了要立刻看得见：getRoute() 越界时会回落到最后一条路线，
	# 于是「三条路线的编制」全挤在一条路上出（表现＝只有一条路线出兵），
	# 而且不报错。这里直接吼一声，别再靠猜。
	if getRouteCount() < ROUTE_TOTAL:
		push_warning("无尽地图只摆了 %d 条路线（应有 %d 条：2 条地面带子 + 1 条空中航线），敌人会挤在同一条路上"
			% [getRouteCount(), ROUTE_TOTAL])
	# 地图上还没有 placeableArea 实例时，先用代码给出可建造格，
	# 免得"进得去但没地方建塔"。M2 摆好真实塔位后这段自动不生效。
	if allowArea.is_empty():
		fillFallbackAllowArea()
	# 本局统计：所有敌人（不分地面/空中）死亡都算进击杀数
	startedAtMsec = Time.get_ticks_msec()
	Game.enemyDefeated.connect(onEnemyDefeated)


func _exit_tree() -> void:
	# 离开无尽：难度缩放必须复位，否则下一局普通关卡会带着 5 倍血量
	Game.enemyScale = 1.0
	Game.enemyAtkScale = 1.0


## 有敌人被消灭（信号来自 enemy.gd::hurt()）——只用来计数，不做别的。
func onEnemyDefeated(_enemy, _source) -> void:
	kills += 1


## 本局已进行的秒数（结算显示用）
func elapsedSeconds() -> int:
	if startedAtMsec <= 0:
		return 0
	return int(floor(float(Time.get_ticks_msec() - startedAtMsec) / 1000.0))


## 覆写基类钩子：第 waveNo 波的生成记录**现场生成**。
func buildWaveSpawner(waveNo: int) -> Array:
	applyDifficulty(waveNo)
	var rng := RandomNumberGenerator.new()
	# 固定 seed：同一波次的编制可复现（将来要做每日挑战，把这里换成日期即可）
	rng.seed = 20261004 + waveNo * 977

	var target: int = mini(WAVE_BASE + int(WAVE_STEP * float(waveNo - 1)), WAVE_CAP)
	if waveNo % BOSS_INTERVAL == 0:
		target = mini(int(float(target) * 1.2), WAVE_CAP)

	# 活跃兵种池：轻型主力（提供"数量"）+ 最近解锁的 2 种（提供"花样"）+ 可能再补 1 种。
	# 为什么固定带上迷你坦克 / 突击车：90 个同屏要是全是重型，玩家根本清不完；
	# 无尽的味道应该是"一群轻兵压过来、里面混几台硬的"。
	var active: Array = [Game.enemyType.miniTank]
	if waveNo >= 3:
		active.append(Game.enemyType.assaultBuggy)
	var unlocked: Array = []
	for row in UNLOCK:
		if waveNo >= int(row[0]):
			unlocked.append(row[1])
	for i in range(maxi(0, unlocked.size() - 2), unlocked.size()):
		if not active.has(unlocked[i]):
			active.append(unlocked[i])
	if unlocked.size() > 2:
		var extra = unlocked[rng.randi_range(0, unlocked.size() - 1)]
		# 空中兵种最多只进 1 种：一周全是飞机的话，没防空的玩家没法玩
		var extraIsAir: bool = extra in AIR_TYPES
		if not active.has(extra) and not (extraIsAir and airCount(active) > 0):
			active.append(extra)

	# 权重：基准量随波次缓慢上涨，受每种上限约束
	var totalWeight: float = 0.0
	var weights: Dictionary = {}
	for t in active:
		var grow: float = 1.0 + 0.05 * float(waveNo - 1)
		var w: float = minf(float(COUNT_BASE.get(t, 2)) * grow, float(COUNT_CAP.get(t, 2)))
		weights[t] = w
		totalWeight += w
	if totalWeight <= 0.0:
		totalWeight = 1.0

	# 先按权重分、再夹到各自上限（否则会出现"一波 45 台装甲坦克"），
	# 然后把剩下的名额补给还没到上限的兵种 —— 总数因此自然逼近 target。
	var counts: Dictionary = {}
	var total: int = 0
	for t in active:
		var c: int = maxi(1, int(round(float(target) * float(weights[t]) / totalWeight)))
		counts[t] = mini(c, int(COUNT_CAP.get(t, 2)))
		total += int(counts[t])
	var guard: int = 0
	while total < target and guard < 500:
		guard += 1
		var progressed: bool = false
		for t in active:
			if total >= target:
				break
			if int(counts[t]) < int(COUNT_CAP.get(t, 2)):
				counts[t] = int(counts[t]) + 1
				total += 1
				progressed = true
		if not progressed:
			break

	# ── 生成记录：**每条路线同时出兵** ──
	## 分兵规则：地面兵种两条带子各一半（奇数余 1 个给路线1），空中兵种走路线3。
	##
	## ⚠️ 上一版是"先把路线1的兵全部排完，再排路线2" —— 而生成队列是**先进先出、
	##    一次只放队首那一个**（见 base_level.gd::onSpawnerTimerTimeout），
	##    结果整波的前半段只有路线1出兵、后半段只有路线2，玩家看到的是
	##    "一次只出一条路线的敌人"（"两条带子始终都有敌人"的设计意图没落地）。
	##    现在改成：先把每个兵种拆进各条路线的队列，再**按比例交织**成一条队列，
	##    几条路线从第一秒起就同时进人。
	var lanes: Dictionary = {}
	lanes[1] = []
	lanes[2] = []
	lanes[AIR_ROUTE] = []
	for t in active:
		var count: int = int(counts[t])
		if count <= 0:
			continue
		if t in AIR_TYPES:
			for _i in count:
				lanes[AIR_ROUTE].append(t)
			continue
		# 奇数余 1 个给路线1（与 endless_mode_design.md §5.2 的写法一致）
		var half: int = int(ceil(float(count) / 2.0))
		for _i in half:
			lanes[1].append(t)
		for _i in count - half:
			lanes[2].append(t)

	# 交织：每一拍挑**进度最落后**的那条路线（进度 = 该路线已出场数 / 该路线总数）。
	# 这是按比例合并多路流水的标准做法：
	#   · 两条带子数量相等 → 严格 1、2、1、2 交替，两列纵队同时推进；
	#   · 数量悬殊（比如 16 : 2）→ 小股的那条也会被均匀撒在整波里，
	#     而不是"挤在某一段"或"末尾才出现"。
	# 空中航线同样按这个比例插进去，所以飞机是穿插登场、不是最后一波全上。
	var laneList: Array = []
	for routeNo in [1, 2, AIR_ROUTE]:
		var items: Array = lanes[routeNo]
		if not items.is_empty():
			laneList.append({"route": int(routeNo), "items": items, "i": 0})

	var totalSpawn: int = 0
	for lane in laneList:
		totalSpawn += (lane["items"] as Array).size()

	var rows: Array = []
	for _k in totalSpawn:
		var best: Dictionary = {}
		var bestProgress: float = 2.0
		for lane in laneList:
			var items: Array = lane["items"]
			var idx: int = int(lane["i"])
			if idx >= items.size():
				continue
			var progress: float = float(idx) / float(items.size())
			if progress < bestProgress - 0.000001:
				bestProgress = progress
				best = lane
		if best.is_empty():
			break
		var spawnType = (best["items"] as Array)[int(best["i"])]
		best["i"] = int(best["i"]) + 1
		# 相邻的"同路线 + 同兵种"合并成一条记录（出怪间隔查表按兵种走，行为完全一致）
		var appended: bool = false
		if not rows.is_empty():
			var last: Dictionary = rows[rows.size() - 1]
			if int(last.get("route", 0)) == int(best["route"]) and last.get("type") == spawnType:
				last["number"] = int(last["number"]) + 1
				appended = true
		if not appended:
			rows.append({"time": waveNo, "type": spawnType, "number": 1,
				"route": int(best["route"])})
	return rows


## 活跃池里的空中兵种个数（用来避免一波全是飞机）
func airCount(active: Array) -> int:
	var n: int = 0
	for t in active:
		if t in AIR_TYPES:
			n += 1
	return n


## 按波次设置难度缩放（敌人 hp / atk 与出怪节奏）
func applyDifficulty(waveNo: int) -> void:
	var steps: float = float(waveNo - 1)
	Game.enemyScale = 1.0 + HP_SCALE_STEP * steps
	Game.enemyAtkScale = 1.0 + ATK_SCALE_STEP * steps
	spawnDelayScale = maxf(DELAY_SCALE_MIN, 1.0 - DELAY_SCALE_STEP * steps)


## 占位地图的可建造格：两条带子之间那 4 行（双倍覆盖区）。
## ⚠️ 这只是 M1 的临时方案 —— M2 会在场景里摆真实的 placeableArea 实例
##   （带可建造高亮），那时 `allowArea` 非空，这里就不会生效。
func fillFallbackAllowArea() -> void:
	for row in FALLBACK_SLOT_ROWS:
		for col in range(int(FALLBACK_SLOT_COLS[0]), int(FALLBACK_SLOT_COLS[1]) + 1):
			allowArea.append(Vector2i(col, row))
