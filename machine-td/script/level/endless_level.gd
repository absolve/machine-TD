extends "res://script/level/base_level.gd"
## 无尽模式关卡（与 15 个关卡平级，但**不读 allStage**：map.gd 传的是 levelId = -1）。
##
## 和普通关卡的区别：
##   · 数值写在脚本里（10 血 / 400 金），不从 StageData 读；
##   · 波次编制**现场生成**（覆写 _build_wave_spawner），按波次解锁兵种、两条地面带子各分一半；
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

## 空中兵种：走路线3（`_collectRoutes()` 里第 3 个 Path2D）
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
	# 地图上还没有 placeableArea 实例时，先用代码给出可建造格，
	# 免得"进得去但没地方建塔"。M2 摆好真实塔位后这段自动不生效。
	if allowArea.is_empty():
		_fillFallbackAllowArea()
	# 本局统计：所有敌人（不分地面/空中）死亡都算进击杀数
	startedAtMsec = Time.get_ticks_msec()
	Game.enemyDefeated.connect(_onEnemyDefeated)


func _exit_tree() -> void:
	# 离开无尽：难度缩放必须复位，否则下一局普通关卡会带着 5 倍血量
	Game.enemyScale = 1.0
	Game.enemyAtkScale = 1.0


## 有敌人被消灭（信号来自 enemy.gd::hurt()）——只用来计数，不做别的。
func _onEnemyDefeated(_enemy, _source) -> void:
	kills += 1


## 本局已进行的秒数（结算显示用）
func elapsedSeconds() -> int:
	if startedAtMsec <= 0:
		return 0
	return int(floor(float(Time.get_ticks_msec() - startedAtMsec) / 1000.0))


## 覆写基类钩子：第 waveNo 波的生成记录**现场生成**。
func _build_wave_spawner(waveNo: int) -> Array:
	_applyDifficulty(waveNo)
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
		if not active.has(extra) and not (extraIsAir and _airCount(active) > 0):
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

	# 生成记录：地面兵种**两条带子各一半**（保证两条路都不断人），空中兵种走路线3
	var rows: Array = []
	for t in active:
		var count: int = int(counts[t])
		if count <= 0:
			continue
		if t in AIR_TYPES:
			rows.append({"time": waveNo, "type": t, "number": count, "route": AIR_ROUTE})
			continue
		var half: int = int(floor(float(count) / 2.0))
		if half > 0:
			rows.append({"time": waveNo, "type": t, "number": half, "route": 1})
		if count - half > 0:
			rows.append({"time": waveNo, "type": t, "number": count - half, "route": 2})
	return rows


## 活跃池里的空中兵种个数（用来避免一波全是飞机）
func _airCount(active: Array) -> int:
	var n: int = 0
	for t in active:
		if t in AIR_TYPES:
			n += 1
	return n


## 按波次设置难度缩放（敌人 hp / atk 与出怪节奏）
func _applyDifficulty(waveNo: int) -> void:
	var steps: float = float(waveNo - 1)
	Game.enemyScale = 1.0 + HP_SCALE_STEP * steps
	Game.enemyAtkScale = 1.0 + ATK_SCALE_STEP * steps
	spawnDelayScale = maxf(DELAY_SCALE_MIN, 1.0 - DELAY_SCALE_STEP * steps)


## 占位地图的可建造格：两条带子之间那 4 行（双倍覆盖区）。
## ⚠️ 这只是 M1 的临时方案 —— M2 会在场景里摆真实的 placeableArea 实例
##   （带可建造高亮），那时 `allowArea` 非空，这里就不会生效。
func _fillFallbackAllowArea() -> void:
	for row in FALLBACK_SLOT_ROWS:
		for col in range(int(FALLBACK_SLOT_COLS[0]), int(FALLBACK_SLOT_COLS[1]) + 1):
			allowArea.append(Vector2i(col, row))
