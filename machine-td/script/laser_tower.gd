extends "res://script/tower.gd"

const MAX_TARGETS := 3 # 最多同时锁定3个目标
const ROTATION_SMOOTH := 8.0 # 炮管旋转平滑系数
const LASER_EFFECT_SCENE := preload("res://scene/laser_muzzle_effect.tscn") # 开火粒子（贴图见 EffectAssets）

var laser_targets: Array = [] # 当前激光锁定的敌人


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


# 对所有锁定目标同时扣血一次(每次 atk 点伤害)，并在炮口与命中点播放开火粒子
func fire_lasers():
	_spawn_laser_effect(get_muzzle_position())
	for enemy in laser_targets:
		if is_instance_valid(enemy) and enemy.has_method("hurt"):
			enemy.hurt(atk,self)
			_spawn_laser_effect(enemy.global_position)


# 播放一次开火粒子特效（素材可在 EffectAssets 中统一替换）
func _spawn_laser_effect(pos: Vector2) -> void:
	var effect := LASER_EFFECT_SCENE.instantiate()
	Game.addObj(effect)
	# 加入场景树后再设置全局坐标，避免父节点偏移导致位置错误
	effect.global_position = pos


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
	super._draw()
	if laser_targets.is_empty():
		return
	var start = to_local(marker.global_position)
	for enemy in laser_targets:
		if not is_instance_valid(enemy):
			continue
		var end = to_local(enemy.global_position)
		_draw_laser_beam(start, end)


func _draw_laser_beam(start: Vector2, end: Vector2) -> void:
	var direction = end - start
	if direction.length_squared() <= 0.0001:
		return
	var brightness := randf_range(0.55, 1.0)
	var laser_color := Color(brightness, brightness * 0.08, brightness * 0.08, 1.0)
	draw_line(start, end, laser_color, 2.0, true)


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
