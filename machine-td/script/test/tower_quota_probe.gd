extends Node
## 建造许可证 探针（headless，退出码 0 = 全过）。设计见 feature_design.md §23.2。
##
## 走真实 map 加载（第 3 关，配了 机枪≤4 / 加农≤4），断言：
##   Q1 数据层配额查询   Q2 建到第 5 座被拒   Q3 isQuotaFull
##   Q4 加农同闸、特斯拉不限                 Q5 free 一座后天然放额
##   Q6 无尽模式豁免     Q7 卡片置灰/恢复     Q8 本地化键齐全

var _fails: int = 0

func _ok(cond: bool, label: String, detail := "") -> void:
	if cond:
		print("@@ PASS " + label)
	else:
		_fails += 1
		print("@@ FAIL " + label + "|" + detail)

func _ready() -> void:
	StageData.currentStageId = 3
	Game.endlessMode = false
	Game.resetBattleMode()
	var map: Node = (load("res://scene/map.tscn") as PackedScene).instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame
	var intro: Node = map.get("levelIntroPanel")
	if intro != null and intro.has_method("close"):
		intro.call("close")
	for i in 6:
		await get_tree().process_frame

	# ── Q1 数据层 ──
	_ok(StageData.getTowerQuota(3, Game.towerType.machineGunTower) == 4, "Q1a stage3 MG quota 4")
	_ok(StageData.getTowerQuota(3, Game.towerType.teslaCoilTower) == -1, "Q1b stage3 tesla unlimited")
	_ok(StageData.getTowerQuota(1, Game.towerType.machineGunTower) == -1, "Q1c stage1 no quota")

	map.titleNode.money = 50000
	var mg: int = Game.towerType.machineGunTower
	var cannon: int = Game.towerType.cannonTower
	var tesla: int = Game.towerType.teslaCoilTower
	_build(map, mg, 5, 900)
	_build(map, cannon, 5, 950)
	_build(map, tesla, 3, 980)
	_ok(map.countTowersAlive(mg) == 4, "Q2 5th MG rejected", "alive=%d" % map.countTowersAlive(mg))
	_ok(map.isQuotaFull(mg) == true, "Q3 MG full")
	_ok(map.countTowersAlive(cannon) == 4, "Q4a cannon gated too", "alive=%d" % map.countTowersAlive(cannon))
	_ok(map.countTowersAlive(tesla) == 3, "Q4b tesla uncapped", "alive=%d" % map.countTowersAlive(tesla))

	# 放掉一座 MG → 无簿记、扫组即放额 → 再建成功
	var firstTower: Node = null
	for t in get_tree().get_nodes_in_group("tower"):
		if t.get("type") == mg:
			firstTower = t
			break
	if firstTower != null:
		firstTower.free()
	_ok(map.isQuotaFull(mg) == false, "Q5a slot freed after removal")
	_build(map, mg, 1, 1005)
	_ok(map.countTowersAlive(mg) == 4, "Q5b rebuild after free", "alive=%d" % map.countTowersAlive(mg))

	# 无尽豁免
	Game.endlessMode = true
	_build(map, mg, 1, 1010)
	_ok(map.countTowersAlive(mg) == 5, "Q6 endless ignores quota", "alive=%d" % map.countTowersAlive(mg))
	Game.endlessMode = false

	# 卡片态：探针直调 placeTower 不走真实点击的 Game.towerPlaced 信号，
	# 所以先显式刷新一次验证灰显逻辑，再 emit 一次验证"信号→刷新"整链路。
	# 注意取卡片容器必须走 ui.towerCardList —— map 场景里有多个叫 "vbox" 的节点。
	var ui: Node = map.get("towerUINode")
	if ui != null and ui.has_method("refreshQuotaLocks"):
		ui.call("refreshQuotaLocks")
	var cards = ui.get("towerCardList") if ui != null else null
	var mgLocked := false
	var teslaOpen := false
	if cards != null:
		for card in cards.get_children():
			if not ("type" in card):
				continue
			if card.type == mg:
				mgLocked = card.locked
			if card.type == tesla:
				teslaOpen = (not card.locked)
	_ok(ui != null, "Q7a towerUINode reachable")
	_ok(mgLocked, "Q7b MG card greyed at quota", "cards=%s" % str(cards))
	_ok(teslaOpen, "Q7c tesla card open")
	# 真实链路：emit 一次 towerPlaced（MG 已满 → placeTower 拒绝且无副作用，
	# 但 tower_ui 的信号回调会 deferred 刷新卡片 —— 这里只确认链路不报错、状态不回退）
	var g9 := Vector2i(1100, 1100)
	var cover9: Array[Vector2i] = [g9]
	Game.towerPlaced.emit(mg, 20, g9, cover9, Vector2i(1, 1))
	for i in 4:
		await get_tree().process_frame
	if cards != null:
		for card in cards.get_children():
			if "type" in card and card.type == mg:
				mgLocked = card.locked
	# Q6 在无尽豁免段建了第 5 座 MG（真实链路留下的超额塔）—— 断言"不再增长"而非固定 4
	_ok(mgLocked and map.countTowersAlive(mg) == 5, "Q7d signal path refresh (still capped)",
		"alive=%d" % map.countTowersAlive(mg))

	# 本地化键
	var csv: FileAccess = FileAccess.open("res://lang/language.csv", FileAccess.READ)
	var text: String = csv.get_as_text() if csv != null else ""
	var keysOK: bool = text.contains("_BuildQuotaFull") and text.contains("_TowerQuotaTooltip") and text.contains("_BuildQuotaTitle")
	_ok(keysOK, "Q8 lang keys present")

	print("@@ DONE fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _build(map: Node, type: int, times: int, baseGrid: int) -> void:
	for i in times:
		var g := Vector2i(baseGrid + i, baseGrid + i)
		var cover: Array[Vector2i] = [g]
		map.placeTower(type, 20, g, cover, Vector2i(1, 1))
