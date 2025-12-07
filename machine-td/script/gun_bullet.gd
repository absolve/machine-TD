extends "res://script/bullet.gd"


func _ready():
	lifetime=3
	speed=Vector2(500,0).rotated(angle)


func _physics_process(delta):
	timer+=delta
	position+=speed*delta
	if timer>lifetime:
		queue_free()
