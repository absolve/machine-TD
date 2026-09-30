extends "res://script/bullet/bullet.gd"

@export var missileSpeed: float = 220.0
@export var turnSpeed: float = 4.0

func _ready() -> void:
	alignToAngle()
	lifetime = 6.0
	vec = Vector2(missileSpeed, 0).rotated(angle)
	if damage <= 0:
		damage = 35


func updateDirection(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	var desiredDirection = global_position.direction_to(target.global_position)
	var desiredAngle = desiredDirection.angle()
	var currentAngle = vec.angle()
	var newAngle = rotate_toward(currentAngle, desiredAngle, turnSpeed * delta)
	vec = Vector2(missileSpeed, 0).rotated(newAngle)
	rotation = newAngle

#func _check_hit():
	#for area in get_overlapping_areas():
		#if area.has_method("hurt"):
			#area.hurt(damage)
			#spawn_hit_effect()
			#queue_free()
			#return


func _physics_process(delta: float) -> void:
	timer += delta
	if timer > lifetime:
		queue_free()
		return
	updateDirection(delta)
	position += vec * delta
	#_check_hit()
	for area in get_overlapping_areas():
		if area.has_method("hurt"):
			area.hurt(damage)
			spawnHitEffect()
			queue_free()
			break
