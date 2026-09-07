extends "res://script/tower.gd"

const MAX_TARGETS := 3 # 最多同时锁定3个目标
const LASER_COLOR := Color(0.05, 1.0, 0.48, 1.0) # 绿色电浆激光
const ROTATION_SMOOTH := 8.0 # 炮管旋转平滑系数

var laser_targets: Array = [] # 当前激光锁定的敌人
var beam_time := 0.0


func _ready():
	turret.rotation = randf() * TAU
	super._ready()
	#var mat =base.material as ShaderMaterial
	#mat.set_shader_parameter("enabled", 1.0)
	#var tween = create_tween()
	#tween.tween_property(mat, "shader_parameter/intensity", 1.5, 0.15)
	#tween.tween_interval(10.6)
	#tween.tween_property(mat, "shader_parameter/intensity", 0.0, 0.4)
	#tween.tween_callback(func(): mat.set_shader_parameter("enabled", 0.0))
	
		
func _physics_process(_delta: float):
	super._physics_process(_delta)
	beam_time += _delta
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
			enemy.hurt(atk,self)


# 收集最多MAX_TARGETS个有效目标
func _collect_targets() -> Array:
	var result: Array = []
	for t in target:
		if is_instance_valid(t) and can_target(t):
			result.append(t)
			if result.size() >= MAX_TARGETS:
				break
	return result


func _draw():
	super._draw()
	if laser_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	for enemy in laser_targets:
		if not is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		_draw_laser_beam(start, end, LASER_COLOR)
		# 击中点光晕
		draw_circle(end, 6.0, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.5))
		draw_circle(end, 3.0, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.8))


func _draw_laser_beam(start: Vector2, end: Vector2, base_color: Color) -> void:
	var direction = end - start
	if direction.length_squared() <= 0.0001:
		return
	var perp = Vector2(-direction.y, direction.x).normalized()
	var beam_points := _build_beam_points(start, end, perp, 6.0)
	# 宽而柔和的绿色外晕
	draw_polyline(beam_points, Color(base_color.r, base_color.g, base_color.b, 0.16), 7.0, true)
	draw_polyline(beam_points, Color(base_color.r, base_color.g, base_color.b, 0.28), 4.0, true)
	# 高亮的电浆主体与白绿色核心
	draw_polyline(beam_points, Color(0.0, 1.0, 0.34, 0.9), 2.2, true)
	draw_polyline(beam_points, Color(0.72, 1.0, 0.84, 1.0), 1.0, true)

func _build_beam_points(start: Vector2, end: Vector2, perp: Vector2, amplitude: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segment_count := 18
	for i in range(segment_count + 1):
		var progress := float(i) / segment_count
		var point := start.lerp(end, progress)
		if i != 0 and i != segment_count:
			var wave := sin(beam_time * 42.0 + float(i) * 2.7)
			var flicker := sin(beam_time * 71.0 + float(i) * 5.1) * 0.35
			point += perp * (wave + flicker) * amplitude
		points.append(point)
	return points


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
	add_target(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
