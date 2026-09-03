extends "res://script/aircraft.gd"

const BULLET = preload("res://scene/gunBullet.tscn")
const FLIGHT_SPEED := 220.0
const ORBIT_RADIUS := 150.0
const ORBIT_SPEED := 1.0

enum FlightState { BASE_ORBIT, ATTACK_APPROACH, TARGET_ORBIT, RETURN_TO_BASE }

var home_base = null
var formation_index := 0
var formation_count := 1
var orbit_phase := 0.0
var orbit_time := 0.0
var current_target = null
var flight_state := FlightState.BASE_ORBIT
var fire_cooldown := 0.0
var fire_interval := 0.6
var bullet_damage := 8
var turn_rate := 6.0


func _ready() -> void:
	var drone_info: Dictionary = Game.towerInfo.get(Game.towerType.droneBase, {})
	bullet_damage = int(drone_info.get("atk", bullet_damage))
	fire_interval = float(drone_info.get("reload", fire_interval))


func _physics_process(delta: float) -> void:
	if not home_base or not is_instance_valid(home_base):
		queue_free()
		return

	fire_cooldown = max(fire_cooldown - delta, 0.0)
	# 所有无人机共用同一个相位时钟，任何时刻都按 orbit_phase 均匀分布，不会打乱阵型
	orbit_time = fmod(orbit_time + ORBIT_SPEED * delta, TAU)
	_update_target()
	match flight_state:
		FlightState.BASE_ORBIT:
			if current_target:
				flight_state = FlightState.ATTACK_APPROACH
			else:
				_orbit_around(home_base.global_position)
		FlightState.ATTACK_APPROACH:
			if not current_target:
				flight_state = FlightState.RETURN_TO_BASE
			else:
				var attack_slot = current_target.global_position + _get_orbit_offset()
				if global_position.distance_to(attack_slot) <= FLIGHT_SPEED * delta:
					# 已贴近自己的槽位，平滑切入环绕（偏差小于一帧移动距离）
					global_position = attack_slot
					flight_state = FlightState.TARGET_ORBIT
				else:
					_move_to(attack_slot, delta)
		FlightState.TARGET_ORBIT:
			if not current_target:
				flight_state = FlightState.RETURN_TO_BASE
			else:
				_orbit_around(current_target.global_position)
				if fire_cooldown <= 0.0:
					_fire_at_target()
					fire_cooldown = fire_interval
		FlightState.RETURN_TO_BASE:
			var return_slot = home_base.global_position + _get_orbit_offset()
			if global_position.distance_to(return_slot) <= FLIGHT_SPEED * delta:
				global_position = return_slot
				flight_state = FlightState.BASE_ORBIT
				current_target = null
			else:
				_move_to(return_slot, delta)


func setup_drone(base, index: int, count: int) -> void:
	home_base = base
	formation_index = index
	formation_count = max(count, 1)
	orbit_phase = TAU * formation_index / formation_count
	orbit_time = 0.0
	global_position = base.global_position + Vector2.from_angle(orbit_phase) * ORBIT_RADIUS
	turn_rate = randf_range(5.5, 7.5)


func _update_target() -> void:
	var defense_targets: Array = home_base.target if home_base else []
	if current_target and is_instance_valid(current_target) and defense_targets.has(current_target):
		return

	current_target = null
	if flight_state == FlightState.TARGET_ORBIT or flight_state == FlightState.ATTACK_APPROACH:
		flight_state = FlightState.RETURN_TO_BASE
	var nearest_distance := INF
	for enemy in defense_targets:
		if not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			current_target = enemy
	if current_target and flight_state == FlightState.RETURN_TO_BASE:
		flight_state = FlightState.ATTACK_APPROACH


func _move_to(destination: Vector2, delta: float) -> void:
	var distance = global_position.distance_to(destination)
	if distance <= 0.01:
		return
	var step = min(FLIGHT_SPEED * delta, distance)
	var target_direction = global_position.direction_to(destination)
	var turn_amount = turn_rate * delta
	var direction_angle = rotate_toward(rotation, target_direction.angle(), turn_amount)
	var direction = Vector2.from_angle(direction_angle)
	global_position += direction * step
	rotation = direction_angle


func _orbit_around(center: Vector2) -> void:
	var position_offset = _get_orbit_offset()
	var tangent = Vector2(-position_offset.y, position_offset.x).normalized()
	global_position = center + position_offset
	rotation = tangent.angle()


func _get_orbit_offset() -> Vector2:
	return Vector2.from_angle(orbit_time + orbit_phase) * ORBIT_RADIUS


func _fire_at_target() -> void:
	var bullet = BULLET.instantiate()
	bullet.global_position = global_position
	bullet.angle = (current_target.global_position - global_position).angle()
	bullet.source_tower = home_base
	bullet.damage = bullet_damage
	Game.addObj(bullet)
