extends "res://script/bullet.gd"

@export var bullet_speed := 400.0

func _ready():
	lifetime = 3.0
	vec = Vector2(bullet_speed, 0).rotated(angle)
	if damage <= 0:
		damage = 15

func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
		return
	_check_hit()

func _check_hit():
	for area in get_overlapping_areas():
		if area.has_method("hurt"):
			area.hurt(damage)
			queue_free()
			return
