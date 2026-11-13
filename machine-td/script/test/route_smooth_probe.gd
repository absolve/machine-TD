extends Node
## 路线弯道体检（headless，退出码 0 = 全过）。
##
## 为什么需要它：敌人走 PathFollow2D，转弯手感完全由 `base_level.gd::smoothRouteCorners`
## 决定，而它做错时**不会报错**：
##   ① 内切量太小（首版 4px）→ 90° 只花 15px 行程，高速兵种看起来是原地甩头；
##   ② 半径与传送带弯头贴图对不上 → 敌人贴着弯头外侧边轨走；
##   ③ 64px 的"一格错位"上两段弧相接，采样点重合 → 旧的密度兜底会让**整条路线**
##      静默退回直角（level_1 / level_9 就是这么漏的）；
##   ④ 关卡的弯头贴图方向填错 → 带子看起来拐不过去。
##
## 跑法：
##   f:/Godot_v4.7.1-stable_win64.exe --headless --path machine-td \
##     res://scene/test/route_smooth_probe.tscn
##
## 口径：传送带弯头 = r32 的四分之一圆，90° 内切 13.25px、切点距 32px；
## 空中航线（转角 <15°）一个点都不该被改。

const LEVEL_DIR := "res://scene/level"
const TILE := 64.0
## 与 base_level.gd 的 ROUTE_SAMPLE_STEP 一致（StageData.TileSize * 0.5）
const ROUTE_SAMPLE_STEP := 32.0
const CORNER_RADIUS := 32.0
const TURN_MIN_DEG := 15.0
## r=32 时每个采样点约 3.5°；留一倍余量抓"某处仍是直角"
const MAX_STEP_DEG := 6.0
const MIN_GAP := 1.0
## 弧中点/切点都在输出点里，允许浮点与去重带来的微小偏差
const GEOM_TOL := 0.31

var _fails: int = 0
var _ran: Array[String] = []
const EXPECTED_CHECKS := ["R1", "R2", "R3", "R4", "R5", "R6", "R7"]

var _groupFail: Dictionary = {}
var _levelCount: int = 0
var _groundRoutes: int = 0
var _airRoutes: int = 0
var _cornerCount: int = 0
var _maxStepDeg: float = 0.0
var _maxCutErr: float = 0.0
var _minGapSeen: float = INF
var _tutorialCorners: int = 0


func _ok(cond: bool, label: String, detail := "") -> void:
	if cond:
		print("@@ PASS " + label)
	else:
		_fails += 1
		print("@@ FAIL " + label + "|" + detail)


func _fail(group: String, msg: String) -> void:
	if not _groupFail.has(group):
		_groupFail[group] = []
	_groupFail[group].append(msg)


func _ready() -> void:
	for path in scenePaths():
		await checkLevel(path)
	_finishGroup("R1", "每个地面弯都真的被圆化（没有整条路线静默回退）")
	_finishGroup("R2", "圆角 = 传送带弯头：切点距 32px、内切 13.25px")
	_finishGroup("R3", "采样点距 ≥1px、每步朝向 ≤6°（无直线折角）")
	_finishGroup("R4", "每个弯的弯头贴图方向 = 入口边→出口边")
	_finishGroup("R5", "平滑前后 routeArea（机甲不能开上的格子）一致")
	_finishGroup("R6", "教程关也有弯道（≥2 个）且弯头齐全")
	_finishGroup("R7", "空中航线逐点未被改动")
	_ran.append("R7")

	print("@@ INFO levels=%d groundRoutes=%d airRoutes=%d corners=%d" % [
		_levelCount, _groundRoutes, _airRoutes, _cornerCount])
	print("@@ INFO 最大每步转角=%.2f° 最大内切误差=%.3fpx 最小点距=%.2fpx 教程弯=%d" % [
		_maxStepDeg, _maxCutErr, _minGapSeen, _tutorialCorners])

	var skipped: Array = []
	for c in EXPECTED_CHECKS:
		if not _ran.has(c):
			skipped.append(c)
	_ok(skipped.is_empty(), "R8 every registered check actually ran",
			"skipped=%s ran=%s" % [str(skipped), str(_ran)])

	print("@@ DONE fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _finishGroup(group: String, title: String) -> void:
	var errs: Array = _groupFail.get(group, [])
	_ran.append(group)
	_ok(errs.is_empty(), "%s %s" % [group, title],
			"%d 处 | %s" % [errs.size(), " ; ".join(errs.slice(0, 6))])


func scenePaths() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(LEVEL_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		if f.begins_with("level_") or f == "endless.tscn":
			out.append(LEVEL_DIR + "/" + f)
	out.sort()
	return out


func checkLevel(path: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		_fail("R1", "%s 打不开" % path)
		return
	var lv: Node = ps.instantiate()
	if lv == null:
		_fail("R1", "%s 实例化失败" % path)
		return
	_levelCount += 1
	var sceneName: String = path.get_file()

	var routes: Array = []
	for child in lv.get_children():
		if child is Path2D:
			routes.append(child)
	var orig: Array = []
	for route in routes:
		var arr: PackedVector2Array = PackedVector2Array()
		for i in route.curve.point_count:
			arr.append(route.curve.get_point_position(i))
		orig.append(arr)

	# 进树才会跑 _ready → collectRoutes → smoothRouteCorners
	add_child(lv)
	var belts: Dictionary = collectBelts(lv)
	var after: Array = []
	for route in routes:
		var arr: PackedVector2Array = PackedVector2Array()
		for i in route.curve.point_count:
			arr.append(route.curve.get_point_position(i))
		after.append(arr)

	for r in routes.size():
		checkRoute(sceneName, routes[r], orig[r] as PackedVector2Array,
				after[r] as PackedVector2Array, belts)
	checkRouteArea(sceneName, lv, routes, after)
	if sceneName == "level_tutorial.tscn":
		checkTutorial(sceneName, routes, orig, belts)

	remove_child(lv)
	lv.free()
	await get_tree().process_frame


## ── 单条路线 ──

func checkRoute(sceneName: String, route: Path2D, src: PackedVector2Array,
		pts: PackedVector2Array, belts: Dictionary) -> void:
	if src.size() < 3:
		return

	var corners: Array = []
	for i in range(1, src.size() - 1):
		var a: Vector2 = src[i - 1]
		var b: Vector2 = src[i]
		var c: Vector2 = src[i + 1]
		var u1: Vector2 = (b - a).normalized()
		var u2: Vector2 = (c - b).normalized()
		var turn: float = absf(rad_to_deg(u1.angle_to(u2)))
		if turn >= TURN_MIN_DEG:
			corners.append({"b": b, "u1": u1, "u2": u2, "turn": turn,
					"segMin": minf(a.distance_to(b), b.distance_to(c))})

	if corners.is_empty():
		_airRoutes += 1
		if pts != src:
			_fail("R7", "%s 空中航线被改动了（原 %d 点 → %d 点）" % [sceneName, src.size(), pts.size()])
		return

	_groundRoutes += 1
	# R1：点数必须变多（圆角被真正写进曲线）
	if pts.size() <= src.size():
		_fail("R1", "%s 有 %d 个弯但点数没变（%d）" % [sceneName, corners.size(), pts.size()])

	# R3：点距与朝向渐变
	var prevGap: float = INF
	for i in range(1, pts.size()):
		var gap: float = pts[i].distance_to(pts[i - 1])
		prevGap = minf(prevGap, gap)
		if gap < MIN_GAP:
			_fail("R3", "%s 采样点距 %.2fpx（第 %d 点）" % [sceneName, gap, i])
	for i in range(2, pts.size()):
		var d1: Vector2 = (pts[i - 1] - pts[i - 2]).normalized()
		var d2: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var stepDeg: float = absf(rad_to_deg(d1.angle_to(d2)))
		_maxStepDeg = maxf(_maxStepDeg, stepDeg)
		if stepDeg > MAX_STEP_DEG:
			_fail("R3", "%s 第 %d 点处一步转 %.2f°" % [sceneName, i, stepDeg])
	_minGapSeen = minf(_minGapSeen, prevGap)

	# R2 / R4：逐个弯核对几何与贴图
	for corner in corners:
		_cornerCount += 1
		var b: Vector2 = corner["b"]
		var u1: Vector2 = corner["u1"]
		var u2: Vector2 = corner["u2"]
		var halfTurn: float = deg_to_rad(float(corner["turn"])) * 0.5
		var tMax: float = float(corner["segMin"]) * 0.5
		var r: float = minf(CORNER_RADIUS, tMax / tan(halfTurn))
		var t: float = r * tan(halfTurn)
		var cut: float = r * (1.0 / cos(halfTurn) - 1.0)
		var t1: Vector2 = b - u1 * t
		var t2: Vector2 = b + u2 * t

		if not hasPointNear(pts, t1, GEOM_TOL):
			_fail("R2", "%s 弯 %s 缺入切点（应距顶点 %.1fpx）" % [sceneName, posText(b), t])
		if not hasPointNear(pts, t2, GEOM_TOL):
			_fail("R2", "%s 弯 %s 缺出切点（应距顶点 %.1fpx）" % [sceneName, posText(b), t])
		var nearest: float = nearestDistance(pts, b)
		var cutErr: float = absf(nearest - cut)
		_maxCutErr = maxf(_maxCutErr, cutErr)
		if cutErr > GEOM_TOL:
			_fail("R2", "%s 弯 %s 内切 %.2fpx（应 %.2fpx）" % [sceneName, posText(b), nearest, cut])

		# R4：弯头贴图必须"入口边→出口边"，且顶点上真的摆了一格
		var key: Vector2i = Vector2i(roundi(b.x / TILE), roundi(b.y / TILE))
		var want: String = entrySide(u1) + exitSide(u2)
		if not belts.has(key):
			_fail("R4", "%s 弯 %s 没有传送带" % [sceneName, posText(b)])
		elif str(belts[key]) != want:
			_fail("R4", "%s 弯 %s 贴图 %s（应 %s）" % [sceneName, posText(b), belts[key], want])

	# R5：平滑不能**新增**路线格（会白占塔位）；消失的只允许是端点那一格 ——
	# 原折线长度往往是 32 的整数倍，最后一点正好压在终点格边界上；圆角让路径
	# 短了 13.7px/弯，末样本退后半格，这一格本来也不在行进面上。
	var origCells: Dictionary = polylineCells(src)
	var smoothCells: Dictionary = polylineCells(pts)
	for g in smoothCells:
		if not origCells.has(g):
			_fail("R5", "%s 平滑后多出格子 %s" % [sceneName, str(g)])
	var ends: Array[Vector2] = [src[0], src[src.size() - 1]]
	for g in origCells:
		if smoothCells.has(g):
			continue
		var centre: Vector2 = (Vector2(g) + Vector2(0.5, 0.5)) * TILE
		var nearEnd: bool = false
		for e in ends:
			nearEnd = nearEnd or centre.distance_to(e) <= TILE * 1.5
		if not nearEnd:
			_fail("R5", "%s 路线中段丢了格子 %s" % [sceneName, str(g)])


## ── 路线格集合 ──

## 关卡自己算的 routeArea 必须与我按**平滑后**折线采样的结果一致 ——
## 这条顺带证明 `_ready` 用的是圆角后的曲线，而不是退回折线的旧数据。
func checkRouteArea(sceneName: String, lv: Node, routes: Array, after: Array) -> void:
	var expected: Dictionary = {}
	for r in routes.size():
		var route: Path2D = routes[r]
		for local in samplePolyline(after[r] as PackedVector2Array):
			var g: Vector2i = lv.call("world2Grid", route.to_global(local))
			expected[g] = true
	var actual: Dictionary = {}
	for g in lv.get("routeArea"):
		actual[g] = true
	if actual.size() != expected.size():
		_fail("R5", "%s routeArea %d 格 / 实测 %d 格" % [sceneName, actual.size(), expected.size()])
		return
	for g in actual:
		if not expected.has(g):
			_fail("R5", "%s routeArea 多出格子 %s" % [sceneName, str(g)])
			return


func polylineCells(pts: PackedVector2Array) -> Dictionary:
	var out: Dictionary = {}
	for local in samplePolyline(pts):
		out[Vector2i(floori(local.x / TILE), floori(local.y / TILE))] = true
	return out


func samplePolyline(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var total: float = 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var travelled: float = 0.0
	var seg: int = 0
	var segStart: float = 0.0
	while travelled <= total:
		while seg < pts.size() - 2 and travelled > segStart + pts[seg + 1].distance_to(pts[seg]):
			segStart += pts[seg + 1].distance_to(pts[seg])
			seg += 1
		var segLen: float = pts[seg + 1].distance_to(pts[seg])
		var k: float = 0.0 if segLen <= 0.0 else clampf((travelled - segStart) / segLen, 0.0, 1.0)
		out.append(pts[seg].lerp(pts[seg + 1], k))
		travelled += ROUTE_SAMPLE_STEP
	return out


## ── 教程关 ──

func checkTutorial(sceneName: String, routes: Array, orig: Array, belts: Dictionary) -> void:
	for i in orig.size():
		var src: PackedVector2Array = orig[i]
		for j in range(1, src.size() - 1):
			var u1: Vector2 = (src[j] - src[j - 1]).normalized()
			var u2: Vector2 = (src[j + 1] - src[j]).normalized()
			if absf(rad_to_deg(u1.angle_to(u2))) >= TURN_MIN_DEG:
				_tutorialCorners += 1
	if _tutorialCorners < 2:
		_fail("R6", "%s 只有 %d 个弯（教程要 ≥2，和普通关卡一致）" % [sceneName, _tutorialCorners])


## ── 工具 ──

func collectBelts(lv: Node) -> Dictionary:
	var out: Dictionary = {}
	var layer: Node = lv.get_node_or_null("beltLayer")
	if layer == null:
		return out
	for b in layer.get_children():
		if b is AnimatedSprite2D:
			var key: Vector2i = Vector2i(roundi(b.position.x / TILE), roundi(b.position.y / TILE))
			out[key] = str(b.animation)
	return out


func hasPointNear(pts: PackedVector2Array, target: Vector2, tol: float) -> bool:
	for p in pts:
		if p.distance_to(target) <= tol:
			return true
	return false


func nearestDistance(pts: PackedVector2Array, target: Vector2) -> float:
	var best: float = INF
	for p in pts:
		best = minf(best, p.distance_to(target))
	return best


## 入口边 = 行进方向的反方向（east 进 → "w"）
func entrySide(u: Vector2) -> String:
	if absf(u.x) > absf(u.y):
		return "w" if u.x > 0.0 else "e"
	return "n" if u.y > 0.0 else "s"


func exitSide(u: Vector2) -> String:
	if absf(u.x) > absf(u.y):
		return "e" if u.x > 0.0 else "w"
	return "s" if u.y > 0.0 else "n"


func posText(p: Vector2) -> String:
	return "(%d,%d)" % [roundi(p.x), roundi(p.y)]
