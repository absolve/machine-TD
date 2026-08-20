extends "res://script/tower.gd"

const MAX_TARGETS := 3 # 最多同时锁定3个目标
const LASER_COLOR := Color(1.0, 0.2, 0.2, 1.0) # 激光颜色(红色)
const ROTATION_SMOOTH := 8.0 # 炮管旋转平滑系数

var laser_targets: Array = [] # 当前激光锁定的敌人


func _ready():
	super._ready()
	#var mat =base.material as ShaderMaterial
	#mat.set_shader_parameter("enabled", 1.0)
	#var tween = create_tween()
	#tween.tween_property(mat, "shader_parameter/intensity", 1.5, 0.15)
	#tween.tween_interval(10.6)
	#tween.tween_property(mat, "shader_parameter/intensity", 0.0, 0.4)
	#tween.tween_callback(func(): mat.set_shader_parameter("enabled", 0.0))
	
		
func _physics_process(_delta: float):
	# 收集最多3个有效目标
	laser_targets = _collect_targets()

	# 炮管朝向第一个目标旋转
	if not laser_targets.is_empty() and is_instance_valid(laser_targets[0]):
		var direction = (laser_targets[0].global_position - turret.global_position).normalized()
		var target_angle = direction.angle()
		turret.rotation = lerp_angle(turret.rotation, target_angle, ROTATION_SMOOTH * _delta)

	# 伤害扣血: 使用 delayTimer/canShot 间隔扣血(与其他塔一致的脉冲机制)
	if not laser_targets.is_empty() and canShot:
		fire_lasers()
		canShot = false
		delayTimer.start()

	# 只要有目标就持续重绘(激光视觉一直存在,不与扣血频率绑定)
	# 注意: 目标消失时也必须 queue_redraw, 否则 _draw 不会被调用来清空画布, 会留下激光残影
	queue_redraw()


# 对所有锁定目标同时扣血一次(每次 atk 点伤害)
func fire_lasers():
	for enemy in laser_targets:
		if is_instance_valid(enemy) and enemy.has_method("hurt"):
			enemy.hurt(atk)


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
	if laser_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	for enemy in laser_targets:
		if not is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		# 外层: 电流抖动效果(每帧随机偏移产生电弧)
		_draw_electric_arc(start, end, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.4), 15.0)
		# 中层
		draw_line(start, end, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.7), 5.0)
		# 内核: 粗+纯白高亮
		draw_line(start, end, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.4), 1.0)
		# 击中点光晕
		draw_circle(end, 12.0, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.5))
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
