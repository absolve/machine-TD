extends Node
## 装甲列车 M1~M2 探针（headless，退出码 0 = 全过）。设计见 feature_design.md §二十五 25.10。
##
## 覆盖：
##   D1~D8  数据层（每节的数值，合计对齐要塞）
##   G1~G3  铺开：5 节、槽位间距 = CAR_SPACING、全部在路线内、同一中心线
##   G7 / S1~S3  共享减速：一节进 EMP 全列同慢、精确恢复、免疫开关
##   G4~G6  收拢：中间死→后面各前进一格；leader 死→整列不跳；尾车死→谁都不动
##   G8~G10 蜂群数量不翻倍、难度倍数照吃、全灭后编组自我释放
##
## 二阶段狂暴、车厢3 宝石、全灭爆炸属于 M3/M4，本探针不管。
## `countScale` 跳过 Boss 走的是 `buildWaveSpawner()`，而 Boss 还没挂进关卡（§19.9 M5），
## 所以 G8 这里验的是"编组只会补 4 节"这条更根本的约束。
##
## 跑法：
##   f:/Godot_v4.7.1-stable_win64.exe --headless --path machine-td ^
##     res://scene/test/train_boss_probe.tscn

const TRAIN_TYPE: int = Game.enemyType.bossTrain
const CAR_COUNT := 5
const CAR_SPACING := 72.0
const KILL_DAMAGE := 999999

var map: Node = null
var _fails: int = 0
## 假减速来源：编组会清掉 `is_instance_valid` 为假的来源，所以这个节点要一直活着
var fakeTower: Node = null


func _ok(cond: bool, label: String, detail := "") -> void:
	if cond:
		print("@@ PASS " + label)
	else:
		_fails += 1
		print("@@ FAIL " + label + "|" + detail)


func _ready() -> void:
	TranslationServer.set_locale("zh")
	StageData.currentStageId = 1
	Game.endlessMode = false
	Game.resetBattleMode()
	map = (load("res://scene/map.tscn") as PackedScene).instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame
	var intro: Node = map.get("levelIntroPanel")
	if intro != null and intro.has_method("close"):
		intro.call("close")
	for i in 6:
		await get_tree().process_frame
	fakeTower = Node.new()

	checkData()
	await checkFormation()
	await checkCompression()
	await checkSwarm()

	print("@@ DONE fails=%d" % _fails)
	fakeTower.free()
	get_tree().quit(0 if _fails == 0 else 1)


func levelNode() -> Node:
	return map.get("level")


## 只取**活着**的车厢，按 progress 从大到小（= 从最接近基地开始）排
func carsOf() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and int(node.get("enemyType")) == TRAIN_TYPE \
				and not bool(node.get("dead")):
			out.append(node)
	out.sort_custom(func(a, b) -> bool:
		return float(a.parent.progress) > float(b.parent.progress))
	return out


func snapshot(list: Array) -> Dictionary:
	var byId: Dictionary = {}
	for car in list:
		byId[car.get_instance_id()] = float(car.parent.progress)
	return byId


func progressOf(car: Node) -> float:
	return float(car.parent.progress)


func killCar(car: Node) -> void:
	car.call("hurt", KILL_DAMAGE, null, "energy")
	for i in 3:
		await get_tree().process_frame


## 到锚点的差距。用"间距"而不是绝对 progress 量收拢：
## 两次快照之间车厢一直在往前走（约 3px），绝对位移里混着这段路；
## 间距里的前进量相互抵消，判据就与测量时机无关了。
func gapsFrom(byId: Dictionary, anchorId: int) -> Dictionary:
	var out: Dictionary = {}
	if not byId.has(anchorId):
		return out
	for id in byId.keys():
		out[id] = float(byId[anchorId]) - float(byId[id])
	return out


# ───────────────────────────── 数据层 ─────────────────────────────

func checkData() -> void:
	var info: Dictionary = Game.enemyInfo.get(TRAIN_TYPE, {})
	# §25.5：以下都是**每节**的量，合计 3000 血 / 300 金 / 120 经验 = 要塞同档
	_ok(int(info.get("hp", 0)) == 600, "D1 hp 600 per carriage (x5 = fortress tier)")
	_ok(int(info.get("reward", 0)) == 60, "D2 reward 60 per carriage (x5 = 300)")
	_ok(int(info.get("rewardExp", 0)) == 24, "D3 exp 24 per carriage (x5 = 120)")
	_ok(int(info.get("lossPoints", 0)) == 2, "D4 lossPoints 2 per carriage (x5 = 10)")
	_ok(int(info.get("gemReward", -1)) == 0, "D5 gemReward 0 (middle carriage pays via group)")
	_ok(absf(float(info.get("armor", -1.0)) - 0.3) < 0.001, "D6 armor 0.3")
	_ok(bool(info.get("isBoss", false)) and int(info.get("bossTier", 0)) == 2,
		"D7 isBoss + bossTier 2 (skipped by countScale)")
	var csv: FileAccess = FileAccess.open("res://lang/language.csv", FileAccess.READ)
	var text: String = csv.get_as_text() if csv != null else ""
	_ok(text.contains("_BossName_train") and text.contains("_BossTip_train"),
		"D8 locale keys for the train")


# ───────────────────────────── G1~G3 铺开 ─────────────────────────────

func checkFormation() -> void:
	levelNode().call("spawnEnemy", {"type": TRAIN_TYPE, "route": 1})
	for i in 8:
		await get_tree().process_frame
	var cars: Array = carsOf()
	_ok(cars.size() == CAR_COUNT, "G1 exactly 5 carriages", "got=%d" % cars.size())
	if cars.size() != CAR_COUNT:
		return

	var head: float = progressOf(cars[0])
	var tail: float = progressOf(cars[cars.size() - 1])
	_ok(tail >= 0.0 and head >= 0.0, "G2a whole train inside the route",
			"head=%.1f tail=%.1f" % [head, tail])
	_ok(absf((head - tail) - CAR_SPACING * float(CAR_COUNT - 1)) < 2.0,
		"G2b slots spread by CAR_SPACING", "span=%.1f expect=%.1f"
			% [head - tail, CAR_SPACING * float(CAR_COUNT - 1)])
	var gapsOk: bool = true
	for i in range(1, cars.size()):
		var gap: float = progressOf(cars[i - 1]) - progressOf(cars[i])
		if absf(gap - CAR_SPACING) > 2.0:
			gapsOk = false
	_ok(gapsOk, "G2c every neighbour gap == CAR_SPACING")
	# 横向必须归到同一条中心线：关卡的自动车道会把没写 offset 的兵种劈成两排
	var lanes: Dictionary = {}
	for car in cars:
		lanes[round(float(car.parent.v_offset))] = true
	_ok(lanes.size() == 1 and lanes.has(0.0), "G3 all carriages on one track",
			"v_offsets=%s" % str(lanes.keys()))

	await checkSameSpeedAndSlow(cars)


## G7 + S1~S3：全队只有一个速度（§25.7 第 1 条）
func checkSameSpeedAndSlow(cars: Array) -> void:
	var speeds: Dictionary = {}
	for car in cars:
		speeds[int(car.get("speed"))] = true
	_ok(speeds.size() == 1, "G7 all carriages share one speed",
			"distinct=%s" % str(speeds.keys()))

	var group: Node = cars[0].get("trainGroup")
	_ok(group != null and is_instance_valid(group), "S0 carriage found its group")
	if group == null or not is_instance_valid(group):
		return
	var baseSpeed: int = int(cars[0].get("baseSpeed"))

	# S1 只让**中间那节**进减速圈：整列一起慢
	cars[2].call("addSlow", fakeTower, 0.3)
	await get_tree().process_frame
	var afterSlow: Dictionary = {}
	for car in cars:
		afterSlow[int(car.get("speed"))] = true
	var expected: int = maxi(1, int(round(float(baseSpeed) * 0.7)))
	_ok(afterSlow.size() == 1 and afterSlow.has(expected),
		"S1 one carriage in EMP -> whole train slows",
			"speeds=%s expect=%d base=%d" % [str(afterSlow.keys()), expected, baseSpeed])

	# S2 离开后**精确**回到原速（各节自己乘除会漂 —— §八 那个 EMP 历史 bug 的翻版）
	cars[2].call("removeSlow", fakeTower)
	await get_tree().process_frame
	var restored: bool = true
	for car in cars:
		if int(car.get("speed")) != baseSpeed:
			restored = false
	_ok(restored, "S2 exact restore to teamBaseSpeed")

	# S3 免疫开关（M4 二阶段用的就是这一条）
	group.set("immuneSlow", true)
	cars[1].call("addSlow", fakeTower, 0.3)
	await get_tree().process_frame
	var immuneHeld: bool = true
	for car in cars:
		if int(car.get("speed")) != baseSpeed:
			immuneHeld = false
	_ok(immuneHeld, "S3 immuneSlow swallows slows for every carriage")
	cars[1].call("removeSlow", fakeTower)
	group.set("immuneSlow", false)


# ───────────────────────────── G4~G6 收拢（§25.3）─────────────────────────────

func checkCompression() -> void:
	var cars: Array = carsOf()
	if cars.size() != CAR_COUNT:
		_ok(false, "G4 setup needs 5 carriages", "got=%d" % cars.size())
		return

	# ── G4 打爆中间那节 → 它后面各前进一格，前面的一律不动 ──
	var before: Dictionary = snapshot(cars)
	var headId: int = cars[0].get_instance_id()
	var killedId: int = cars[1].get_instance_id()
	var behindIds: Array = [cars[2].get_instance_id(), cars[3].get_instance_id(),
		cars[4].get_instance_id()]
	await killCar(cars[1])
	var after: Dictionary = snapshot(carsOf())
	var bg: Dictionary = gapsFrom(before, headId)
	var ag: Dictionary = gapsFrom(after, headId)
	_ok(not after.has(killedId), "G4a middle carriage gone")
	_ok(ag.has(headId) and absf(ag[headId] - bg[headId]) < 1.0,
		"G4b carriage in front did NOT move")
	var closed: bool = true
	for id in behindIds:
		if not (bg.has(id) and ag.has(id)):
			closed = false
			continue
		# 到 leader 的间距应当**恰好缩短一格**
		if absf((bg[id] - ag[id]) - CAR_SPACING) > 2.0:
			closed = false
	_ok(closed, "G4c carriages behind each closed one slot",
			"gaps %s -> %s" % [str(bg.values()), str(ag.values())])

	# ── G6 打爆尾车 → 谁都不动（"先拆尾车最安全"的由来）──
	cars = carsOf()
	before = snapshot(cars)
	headId = cars[0].get_instance_id()
	await killCar(cars[cars.size() - 1])
	after = snapshot(carsOf())
	bg = gapsFrom(before, headId)
	ag = gapsFrom(after, headId)
	var tailStill: bool = after.size() == 3
	for id in ag.keys():
		if not bg.has(id) or absf(ag[id] - bg[id]) > 1.0:
			tailStill = false
	_ok(tailStill, "G6 killing the rear carriage moves nothing",
			"alive=%d gaps=%s" % [after.size(), str(ag.values())])

	# ── G5 打爆 leader → 第 2 节顶上来，整列位置不跳 ──
	cars = carsOf()
	before = snapshot(cars)
	var oldHeadId: int = cars[0].get_instance_id()
	var newHeadId: int = cars[1].get_instance_id()
	await killCar(cars[0])
	after = snapshot(carsOf())
	# 锚点换成顶上来的那节：两次都以它为基准比间距，才能证明"整列没被往前推"
	bg = gapsFrom(before, newHeadId)
	ag = gapsFrom(after, newHeadId)
	_ok(not after.has(oldHeadId), "G5a leader carriage gone")
	_ok(ag.has(newHeadId) and after.has(newHeadId), "G5b a carriage took over the lead")
	var held: bool = after.size() == 2
	for id in ag.keys():
		if id == newHeadId:
			continue
		if not bg.has(id) or absf(ag[id] - bg[id]) > 1.0:
			held = false
	_ok(held, "G5c every remaining carriage kept its slot",
			"alive=%d gaps=%s" % [after.size(), str(ag.values())])


# ───────────────────────────── G8~G10 ─────────────────────────────

func checkSwarm() -> void:
	# 直接 freeSelf（不走 hurt）：顺便验证编组不会攥着已释放的车厢
	var group: Node = null
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and int(node.get("enemyType")) == TRAIN_TYPE:
			group = node.get("trainGroup")
			node.call("freeSelf")
	for i in 6:
		await get_tree().process_frame
	_ok(carsOf().is_empty(), "G8a cleared for the swarm check")

	Game.setBattleMode("swarm")
	levelNode().call("spawnEnemy", {"type": TRAIN_TYPE, "route": 1})
	for i in 8:
		await get_tree().process_frame
	var cars: Array = carsOf()
	_ok(cars.size() == CAR_COUNT, "G8 swarm mode still one train of 5 (not 25)",
		"got=%d" % cars.size())
	# §19.6：难度倍数照吃，只有数量不翻倍
	var info: Dictionary = Game.enemyInfo.get(TRAIN_TYPE, {})
	var scaled: int = int(cars[0].get("maxHp"))
	var expectHp: int = maxi(1, int(ceil(float(info.get("hp", 0)) * Game.modeHpScale)))
	_ok(scaled == expectHp, "G9 modeHpScale applies to each carriage",
			"hp=%d expect=%d scale=%.2f" % [scaled, expectHp, Game.modeHpScale])
	Game.resetBattleMode()

	await checkLeakPerCarriage(cars)

	# 全灭 → 编组控制器自我释放（§25.7：不留悬空编组，否则波次结算会被卡住）
	for car in cars:
		if is_instance_valid(car):
			car.call("hurt", KILL_DAMAGE, null, "energy")
	for i in 10:
		await get_tree().process_frame
	_ok(carsOf().is_empty(), "G10a fully wiped -> wave can settle")
	_ok(group == null or not is_instance_valid(group),
		"G10b group freed itself with the train", "valid=%s" % str(is_instance_valid(group)))


## ── G11 每节车厢**单独**扣基地血（§25.5，需求里那条"逃离扣血每节单独扣"）──
## 判据用 `enemyLeaked`（带节点，可按类型过滤）而不是 `enemyEscaped`（只带数字）——
## 关卡自己的波次也在漏怪，只数总点数会被污染。
var _leakIds: Array = []
var _leakPoints: int = 0

func checkLeakPerCarriage(cars: Array) -> void:
	if cars.size() != CAR_COUNT:
		_ok(false, "G11 setup needs 5 carriages", "got=%d" % cars.size())
		return
	var route: Path2D = cars[0].parent.get_parent() as Path2D
	if route == null:
		_ok(false, "G11 route not found")
		return
	_leakIds.clear()
	_leakPoints = 0
	Game.enemyLeaked.connect(onLeakProbe)
	# 把头两节直接推到终点附近：它们各自在下一次物理帧触发自己的逃脱结算
	var endProgress: float = route.curve.get_baked_length() - 2.0
	cars[0].parent.progress = endProgress
	cars[1].parent.progress = endProgress
	for i in 8:
		await get_tree().process_frame
	Game.enemyLeaked.disconnect(onLeakProbe)
	_ok(_leakIds.size() == 2, "G11a each leaking carriage fires its own escape",
			"leaked=%d" % _leakIds.size())
	_ok(_leakPoints == 4, "G11b lossPoints 2 x 2 carriages = 4 damage",
			"points=%d" % _leakPoints)
	# 剩下的 3 节还在：漏掉两节不等于整列消失（§25.9 第 2 条，波次不能提前结算）
	_ok(carsOf().size() == CAR_COUNT - 2, "G11c rest of the train keeps running",
			"alive=%d" % carsOf().size())


func onLeakProbe(enemy: Node) -> void:
	if not is_instance_valid(enemy) or int(enemy.get("enemyType")) != TRAIN_TYPE:
		return
	_leakIds.append(enemy.get_instance_id())
	_leakPoints += int(enemy.get("lossPoints"))
