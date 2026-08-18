extends "res://script/tower.gd"

const MAX_TARGETS := 3 # 最多同时锁定3个目标
const LASER_DURATION := 0.12 # 激光显示时长(略大于reload保证连续)
const LASER_COLOR := Color(1.0, 0.2, 0.2, 1.0) # 激光颜色(红色)

var laser_targets: Array = [] # 当前激光锁定的敌人
var laser_timer := 0.0 # 激光显示剩余时间


func _ready():
	#delay = 0.1
	#delayTimer.wait_time = delay
	super._ready()


func _physics_process(_delta: float):
	# 收集最多3个有效目标
	laser_targets = _collect_targets()
	if not laser_targets.is_empty() and canShot:
		fire_lasers()
		canShot = false
		delayTimer.start()
	if laser_timer > 0:
		laser_timer -= _delta
		queue_redraw()


# 对所有锁定目标同时开火
func fire_lasers():
	laser_timer = LASER_DURATION
	for enemy in laser_targets:
		if is_instance_valid(enemy) and enemy.has_method("hurt"):
			enemy.hurt(atk)
	queue_redraw()


# 收集最多MAX_TARGETS个有效目标
func _collect_targets() -> Array:
	var result: Array = []
	for t in target:
		if is_instance_valid(t):
			result.append(t)
			if result.size() >= MAX_TARGETS:
				break
	return result


func _draw():
	if laser_timer <= 0 or laser_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	for enemy in laser_targets:
		if not is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		# 外层: 电流抖动效果(每帧随机偏移产生电弧)
		_draw_electric_arc(start, end, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.4), 12.0)
		# 中层
		draw_line(start, end, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.7), 15.0)
		# 内核: 粗+纯白高亮
		draw_line(start, end, Color(1.0, 1.0, 1.0, 1.0), 2.0)
		# 击中点光晕
		draw_circle(end, 12.0, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(end, 6.0, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.8))


# 绘制电流抖动电弧: 沿直线分段, 每段随机垂直偏移
func _draw_electric_arc(start: Vector2, end: Vector2, color: Color, width: float, segments: int = 8, jitter: float = 8.0):
	var direction = end - start
	var perp = Vector2(-direction.y, direction.x).normalized()
	var prev = start
	for i in range(1, segments):
		var t = float(i) / float(segments)
		var point = start + direction * t
		# 端点不偏移, 中间点随机垂直抖动
		point += perp * randf_range(-jitter, jitter)
		draw_line(prev, point, color, width)
		prev = point
	draw_line(prev, end, color, width)


func _on_radar_area_entered(area: Area2D) -> void:
	target.push_back(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
