extends "res://script/bullet/bullet.gd"

@export var bulletSpeed: float = 400.0

func _ready() -> void:
	alignToAngle()
	lifetime = 3.0
	vec = Vector2(bulletSpeed, 0).rotated(angle)
	if damage <= 0:
		damage = 15


func _physics_process(delta: float) -> void:
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
		return
	#_check_hit()
	for area in get_overlapping_areas():
		if area.has_method("hurt"):
			area.hurt(damage)
			spawnHitEffect()
			queue_free()
			break

#func _check_hit():
	#for area in get_overlapping_areas():
		#if area.has_method("hurt"):
			#area.hurt(damage)
			#spawn_hit_effect()
			#queue_free()
			#return
