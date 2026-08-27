extends "res://script/bullet.gd"

@export var missile_speed := 220.0
@export var turn_speed := 4.0

func _ready():
	lifetime = 6.0
	vec = Vector2(missile_speed, 0).rotated(angle)
	if damage <= 0:
		damage = 35

func _physics_process(delta):
	timer += delta
	if timer > lifetime:
		queue_free()
		return
	_update_direction(delta)
	position += vec * delta
	_check_hit()

func _update_direction(delta):
	if not target or not is_instance_valid(target):
		return
	var desired_direction = global_position.direction_to(target.global_position)
	var desired_angle = desired_direction.angle()
	var current_angle = vec.angle()
	var new_angle = rotate_toward(current_angle, desired_angle, turn_speed * delta)
	vec = Vector2(missile_speed, 0).rotated(new_angle)
	rotation = new_angle

func _check_hit():
	for area in get_overlapping_areas():
		if area.has_method("hurt"):
			area.hurt(damage)
			queue_free()
			return
