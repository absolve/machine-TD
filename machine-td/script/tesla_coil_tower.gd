extends "res://script/tower.gd"

const MAX_CHAIN := 4 # 闪电最多链4个敌人
const LIGHTNING_DURATION := 0.18 # 单次闪电显示时长
const FLICKER_INTERVAL := 0.03 # 闪电抖动重算间隔
const CHAIN_MAX_DIST := 220.0 # 链间最大距离
const LIGHTNING_COLOR := Color(0.45, 0.85, 1.0, 1.0) # 闪电主色(青蓝)

var chain_targets: Array = [] # 当前闪电链上的敌人(按顺序)
var lightning_timer := 0.0 # 闪电显示剩余时间
var flicker_timer := 0.0 # 下次抖动重算倒计时
var jagged_points: PackedVector2Array = PackedVector2Array() # 缓存的折线点


func _ready() -> void:
	super._ready()
	pass
	

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	var t = getTarget()
	if t and canShot:
		fire_lightning(t)
		canShot = false
		delayTimer.start()

	if lightning_timer > 0:
		lightning_timer -= _delta
		flicker_timer -= _delta
		if flicker_timer <= 0:
			_regenerate_jagged_points()
			flicker_timer = FLICKER_INTERVAL
		queue_redraw()

# func _process(delta):
# 	if lightning_timer > 0:
# 		lightning_timer -= delta
# 		flicker_timer -= delta
# 		if flicker_timer <= 0:
# 			_regenerate_jagged_points()
# 			flicker_timer = FLICKER_INTERVAL
# 		queue_redraw()

# 触发闪电: 以某个敌人为起点,收集最多MAX_CHAIN个链上敌人并显示特效
func fire_lightning(initial_target):
	chain_targets = _collect_chain(initial_target)
	lightning_timer = LIGHTNING_DURATION
	flicker_timer = 0.0
	_regenerate_jagged_points()
	queue_redraw()
	# TODO: 在此对 chain_targets 中每个敌人施加伤害/减速
	
	
# 贪心收集链上敌人: 从首个敌人开始,每次找最近的未使用目标
func _collect_chain(first) -> Array:
	var result: Array = [first]
	var used: Dictionary = {first: true}
	var current = first
	while result.size() < MAX_CHAIN:
		var next = null
		var best_dist = CHAIN_MAX_DIST
		for t in target:
			if used.has(t):
				continue
			var d = t.global_position.distance_to(current.global_position)
			if d < best_dist:
				best_dist = d
				next = t
		if next == null:
			break
		result.append(next)
		used[next] = true
		current = next
	return result

# 重新生成抖动折线点: 炮口 -> 敌人1 -> 敌人2 -> ... 
func _regenerate_jagged_points():
	jagged_points.clear()
	if chain_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	jagged_points.append(start)
	for enemy in chain_targets:
		var end = to_local(enemy.global_position)
		var seg = _generate_segment(start, end, 6, 18.0)
		for p in seg:
			jagged_points.append(p)
		jagged_points.append(end)
		start = end

# 在 from->to 之间生成抖动中点(不含首尾)
func _generate_segment(from: Vector2, to: Vector2, segments: int, jitter: float) -> Array:
	var arr: Array = []
	var dir = to - from
	if dir.length() < 1.0:
		return arr
	var normal = dir.normalized()
	var perp = Vector2(-normal.y, normal.x)
	for i in range(1, segments):
		var t = float(i) / segments
		var base1 = from + dir * t
		var offset = perp * randf_range(-jitter, jitter)
		arr.append(base1 + offset)
	return arr

func _draw():
	if lightning_timer <= 0 or jagged_points.size() < 2:
		return
	# 外发光: 宽+低透明
	draw_polyline(jagged_points, Color(LIGHTNING_COLOR.r, LIGHTNING_COLOR.g, LIGHTNING_COLOR.b, 0.3), 6.0, true)
	# 中层
	draw_polyline(jagged_points, Color(LIGHTNING_COLOR.r, LIGHTNING_COLOR.g, LIGHTNING_COLOR.b, 0.7), 3.0, true)
	# 内核: 细+纯白高亮
	draw_polyline(jagged_points, Color(1.0, 1.0, 1.0, 1.0), 1.0, true)
	# 每个击中点画一个光晕
	for enemy in chain_targets:
		var p = to_local(enemy.global_position)
		draw_circle(p, 10.0, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(p, 5.0, Color(LIGHTNING_COLOR.r, LIGHTNING_COLOR.g, LIGHTNING_COLOR.b, 0.8))





func _on_radar_area_entered(area: Area2D) -> void:
	target.push_back(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
