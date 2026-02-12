extends "res://script/bullet.gd"


func _ready():
	lifetime = 5
	vec = Vector2(300, 0).rotated(angle)
	damage = 40
