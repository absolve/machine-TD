extends Node
## 弯道平滑（圆弧细分）+ 回血特效缩放 探针（headless 运行，退出码 0 = 全过）
##
## 用法：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path machine-td \
##     res://scene/test/route_smooth_probe.tscn
##
## 背景：Godot 4.7 的 Curve2D 已无 point mode API，且实测 set_point_in/out 的手柄
## 对烘焙**零影响**（enum_peek 探针确认 baked length == 折线长度和）。
## 所以平滑走「转角点替换为圆弧采样点」的纯折线加密路线，这里验证的就是它的几何。
##
## 断言组：
##   S1~S7  合成直角折线：端点不动 / 顶点消失 / 内切 <=4.3px / 单步转角摊薄 / 幂等 / 折返豁免
##   L1~L6  第 1 关两条真实路线的密度、内切预算、端点与共线点保留
##   H1~H4  heal_particles 缩放 0.12~0.20、初速 120~190

const LEVEL_ORIG_R1 := [Vector2(-96, 224), Vector2(672, 224), Vector2(672, 160), Vector2(1808, 160), Vector2(1984, 160)]
const LEVEL_ORIG_R2 := [Vector2(-96, 288), Vector2(736, 288), Vector2(736, 736), Vector2(1808, 736), Vector2(1984, 736)]

var _fails: int = 0


func _ok(cond: bool, label: String, detail := "") -> void:
	if cond:
		print("@@ PASS " + label)
	else:
		_fails += 1
		print("@@ FAIL " + label + "|" + detail)


func _ready() -> void:
	var levelScript: GDScript = load("res://script/level/base_level.gd")
	_checkSynthetic(levelScript)

	var level: Node = (load("res://scene/level/level_1.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_checkLevel(level)
	_checkHealFx()

	print("@@ DONE fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _polyline(c: Curve2D) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in c.point_count:
		pts.append(c.get_point_position(i))
	return pts


func _maxDeviation(pts: PackedVector2Array, orig: PackedVector2Array) -> float:
	var worst := 0.0
	for p in pts:
		var best := INF
		for i in range(orig.size() - 1):
			best = minf(best, _distToSeg(p, orig[i], orig[i + 1]))
		worst = maxf(worst, best)
	return worst


func _distToSeg(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t - point).length()


func _maxStepTurn(pts: PackedVector2Array) -> float:
	var worst := 0.0
	for i in range(1, pts.size() - 1):
		var v1 := pts[i] - pts[i - 1]
		var v2 := pts[i + 1] - pts[i]
		if v1.is_zero_approx() or v2.is_zero_approx():
			continue
		worst = maxf(worst, absf(rad_to_deg(v1.angle_to(v2))))
	return worst


func _checkSynthetic(script: GDScript) -> void:
	var orig := PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 150), Vector2(400, 150)])
	var c := Curve2D.new()
	for p in orig:
		c.add_point(p)
	script.smoothRouteCorners(c)
	var pts := _polyline(c)
	_ok(pts[0] == Vector2(0, 0) and pts[pts.size() - 1] == Vector2(400, 150), "S1 endpoints untouched")
	var cornerStillThere := false
	for p in pts:
		if p.distance_to(Vector2(200, 0)) < 0.5:
			cornerStillThere = true
	_ok(not cornerStillThere, "S2 corner vertex replaced by arc")
	var dev := _maxDeviation(pts, orig)
	_ok(dev <= 4.3, "S3 arc cut-in <= 4.3px (belt 37px budget)", "%.2f" % dev)
	var baked: PackedVector2Array = c.get_baked_points()
	var turn: float = _maxStepTurn(baked)
	_ok(turn <= 25.0, "S4 per-step turn spread (was 90 snap)", "%.1f" % turn)
	var before := _polyline(c)
	script.smoothRouteCorners(c)
	_ok(_polyline(c) == before, "S5 idempotent")
	_ok(c.bake_interval <= 2.5 + 0.001, "S6 bake interval tightened", str(c.bake_interval))

	var u := Curve2D.new()
	for p in [Vector2(0, 0), Vector2(100, 0), Vector2(2, 1)]:
		u.add_point(p)
	script.smoothRouteCorners(u)
	_ok(_polyline(u) == PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(2, 1)]),
		"S7 U-turn left alone")


func _checkLevel(level: Node) -> void:
	var routes: Array = level.get("routes")
	_ok(routes.size() == 2, "L1 level_1 has 2 routes", str(routes.size()))
	var c1: Curve2D = (routes[0] as Path2D).curve
	var c2: Curve2D = (routes[1] as Path2D).curve
	_ok(c1.point_count > 5, "L2 route1 densified", str(c1.point_count))
	_ok(_maxDeviation(_polyline(c1), PackedVector2Array(LEVEL_ORIG_R1)) <= 4.3, "L3 route1 within cut-in budget")
	_ok(_maxDeviation(_polyline(c2), PackedVector2Array(LEVEL_ORIG_R2)) <= 4.3, "L4 route2 within cut-in budget")
	var p1 := _polyline(c1)
	_ok(p1[0] == Vector2(-96, 224) and p1[p1.size() - 1] == Vector2(1984, 160), "L5 route1 endpoints kept")
	var kept := false
	for p in p1:
		if p.distance_to(Vector2(1808, 160)) < 0.01:
			kept = true
	_ok(kept, "L6 straight point kept verbatim")


func _checkHealFx() -> void:
	var fx: Node = (load("res://scene/fx/heal_particles.tscn") as PackedScene).instantiate()
	var p: Node = fx.get_node_or_null("Particles")
	if p == null:
		_ok(false, "H0 heal Particles node found")
		return
	_ok(is_equal_approx(float(p.get("scale_amount_min")), 0.12), "H1 scale_min 0.12", str(p.get("scale_amount_min")))
	_ok(is_equal_approx(float(p.get("scale_amount_max")), 0.20), "H2 scale_max 0.20", str(p.get("scale_amount_max")))
	_ok(is_equal_approx(float(p.get("initial_velocity_min")), 120.0), "H3 velocity_min 120", str(p.get("initial_velocity_min")))
	_ok(is_equal_approx(float(p.get("initial_velocity_max")), 190.0), "H4 velocity_max 190", str(p.get("initial_velocity_max")))
	add_child(fx)
	fx.queue_free()
