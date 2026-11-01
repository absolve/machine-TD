extends "res://script/enemy/boss/boss.gd"
## ⑦ 要塞 `bossFortress` —— 大 boss，综合考验。
##
## 阶段 1（100%~50%）：炮塔开火 + 每 10 秒召唤 2 只精英小兵。
## 阶段 2（<50%）：**狂暴** —— 攻速 x1.5、移速 x1.3、**免疫减速**，并立刻召唤一波。
##
## 免疫减速只在阶段 2 开：前面半场它仍然吃 EMP，玩家不会觉得"EMP 白建"。

const PHASE2_HP_RATIO := 0.5
const SUMMON_INTERVAL := 10.0
const SUMMON_COUNT := 2
## 召唤物之间拉开 120px（34px 会挤在一起），并左右交替
const SUMMON_BACK_STEP := 120.0
const SUMMON_LATERAL := [-20.0, 20.0]
const MAX_ON_SCREEN := 90
## 阶段 2 的攻速与移速加成
const PHASE2_FIRE_MULT := 1.5
const PHASE2_SPEED_MULT := 1.3

var summonTimer: float = SUMMON_INTERVAL
var phase2: bool = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	tickShooter(delta)
	checkPhase2()
	summonTimer -= delta
	if summonTimer > 0.0:
		return
	summonTimer = SUMMON_INTERVAL
	doSummon()


func checkPhase2() -> void:
	if phase2 or hp * 2 > maxHp:
		return
	phase2 = true
	immuneSlow = true
	# 攻速：直接缩短开火间隔（比改 atk 更贴近"攻速提升"的语义）
	if delayTimer != null:
		delayTimer.wait_time = maxf(0.05, delayTimer.wait_time / PHASE2_FIRE_MULT)
	speed = maxi(1, int(round(float(speed) * PHASE2_SPEED_MULT)))
	baseSpeed = speed
	# 立刻来一波，让玩家感觉到"它变了"
	doSummon()


func doSummon() -> void:
	if aliveEnemyCount() + SUMMON_COUNT > MAX_ON_SCREEN:
		return
	for i in SUMMON_COUNT:
		var lateral: float = SUMMON_LATERAL[i % SUMMON_LATERAL.size()]
		summonAt(Game.enemyType.mediumTank, SUMMON_BACK_STEP * float(i + 1),
			1.0, {}, lateral)
