extends "res://script/aircraft.gd"

var home_base = null # 所属基地
var orbit_angle := 0.0 # 当前轨道角度
var orbit_radius := 100.0 # 基础轨道半径
var orbit_speed := 1.5 # 轨道角速度(弧度/秒)
var radius_var_amp := 25.0 # 半径波动幅度
var radius_var_freq := 2.0 # 主波动频率
var radius_var_freq2 := 3.7 # 次波动频率(不同频避免重复)
var angle_wobble_amp := 0.15 # 角度抖动幅度
var angle_wobble_freq := 1.3 # 角度抖动频率
var time := 0.0
var current_target = null # 当前锁定的敌人
var current_center := Vector2.ZERO # 当前轨道中心(平滑过渡)
var center_initialized := false
var canShot = true
var fire_cooldown := 0.0
var fire_delay := 0.5 # 开火间隔


func _ready():
	# 设置雷达检测敌人(layer 2), 信号在代码中连接避免重构场景
	radar.collision_mask = 2
	radar.area_entered.connect(_on_radar_area_entered)
	radar.area_exited.connect(_on_radar_area_exited)
	# 每架无人机参数随机化, 让运动轨迹各不相同
	orbit_speed = randf_range(0.2, 1.0)
	orbit_radius = randf_range(85.0, 115.0)
	radius_var_amp = randf_range(20.0, 30.0)
	radius_var_freq = randf_range(1.5, 2.5)
	radius_var_freq2 = randf_range(3.0, 4.5)
	angle_wobble_amp = randf_range(0.1, 0.2)
	angle_wobble_freq = randf_range(1.0, 1.6)


func _physics_process(delta):
	# 基地不存在时自动销毁
	if not home_base or not is_instance_valid(home_base):
		queue_free()
		return
	time += delta
	orbit_angle += orbit_speed * delta
	# 先更新目标
	_update_target()
	# 首帧初始化轨道中心
	if not center_initialized:
		current_center = home_base.global_position
		center_initialized = true
	# 确定轨道中心: 有敌人时围绕敌人, 无敌人时围绕基地
	var target_center = home_base.global_position
	if current_target and is_instance_valid(current_target):
		target_center = current_target.global_position
	# 平滑过渡轨道中心(从基地到敌人或敌人到基地)
	current_center = current_center.lerp(target_center, 2.0 * delta)
	# 灵动绕圈: 基础轨道 + 多频率半径波动 + 角度微抖, 非死板圆周
	var r = orbit_radius
	r += sin(time * radius_var_freq) * radius_var_amp
	r += sin(time * radius_var_freq2) * radius_var_amp * 0.4
	var a = orbit_angle + sin(time * angle_wobble_freq) * angle_wobble_amp
	var offset = Vector2(cos(a), sin(a)) * r
	global_position = current_center + offset
	# 朝向
	var target_angle: float
	if current_target and is_instance_valid(current_target):
		# 有敌人时朝向敌人
		target_angle = (current_target.global_position - global_position).angle()
		# 尝试开火(子弹发射功能后续实现)
		if canShot:
			fire()
			canShot = false
			fire_cooldown = fire_delay
	else:
		# 无敌人时朝向运动方向(轨道切线)
		target_angle = Vector2(-sin(a), cos(a)).angle()
	rotation = lerp_angle(rotation, target_angle, 10 * delta)
	# 开火冷却
	if not canShot:
		fire_cooldown -= delta
		if fire_cooldown <= 0:
			canShot = true


# 更新当前目标: 选择最近的敌人
func _update_target():
	current_target = null
	var best_dist = INF
	for t in target:
		if not is_instance_valid(t):
			continue
		var d = global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			current_target = t


# 开火(子弹发射功能后续实现)
func fire():
	if current_target and is_instance_valid(current_target):
		# TODO: 实现子弹发射
		pass


func _on_radar_area_entered(area):
	target.append(area)


func _on_radar_area_exited(area):
	target.erase(area)
