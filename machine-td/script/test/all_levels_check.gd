extends Node
## 一次性全关卡几何核查（跑完自动退出）
var _bad: int = 0

func _ready() -> void:
	var script: GDScript = load("res://script/level/base_level.gd")
	var paths: PackedStringArray = PackedStringArray()
	for i in range(0, 16):
		paths.append("res://scene/level/level_%d.tscn" % i)
		paths.append("res://scene/level/level_tutorial.tscn")
	paths.append("res://scene/level/endless.tscn")
	for path in paths:
		if not ResourceLoader.exists(path):
			print("@@ SKIP missing ", path)
			continue
		var lvl: Node = (load(path) as PackedScene).instantiate()
		add_child(lvl)
		await get_tree().process_frame
		var routes: Array = lvl.get("routes")
		for rIdx in routes.size():
			var c: Curve2D = (routes[rIdx] as Path2D).curve
			var pts := PackedVector2Array()
			for p in c.point_count:
				pts.append(c.get_point_position(p))
			# 最小相邻点距（防重叠采样）
			var minSep := INF
			for i in range(1, pts.size()):
				minSep = minf(minSep, pts[i].distance_to(pts[i - 1]))
			# 单步转角
			var maxTurn := 0.0
			for i in range(1, pts.size() - 1):
				var v1: Vector2 = pts[i] - pts[i - 1]
				var v2: Vector2 = pts[i + 1] - pts[i]
				if not v1.is_zero_approx() and not v2.is_zero_approx():
					maxTurn = maxf(maxTurn, absf(rad_to_deg(v1.angle_to(v2))))
			var tag := "OK"
			if minSep < 0.9 or maxTurn > 25.0:
				tag = "BAD"
				_bad += 1
			print("@@ [%s] %s route%d points=%d minSep=%.2f maxTurn=%.1f" % [tag, path.get_file(), rIdx + 1, pts.size(), minSep, maxTurn])
		lvl.queue_free()
		await get_tree().process_frame
	print("@@ ALL-DONE bad=%d" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)
