extends "res://script/bullet.gd"

var bomb=preload("res://scene/bomb.tscn")


func _ready():
	lifetime = 5
	vec = Vector2(300, 0).rotated(angle)
	damage = 40
	rotate(angle)

func _physics_process(delta):
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
	var temp = get_overlapping_areas()
	if temp:
		var b=bomb.instantiate()
		b.global_position=global_position
		Game.addObj(b)
		queue_free()
