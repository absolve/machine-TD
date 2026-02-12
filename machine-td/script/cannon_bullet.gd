extends "res://script/bullet.gd"

func _ready():
	lifetime = 3
	vec = Vector2(500, 0).rotated(angle)
	damage = 30


func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
	var temp = get_overlapping_areas()
	if temp:
		for i in temp:
			if i.has_method("hurt"):
				i.hurt(damage)
		queue_free()
