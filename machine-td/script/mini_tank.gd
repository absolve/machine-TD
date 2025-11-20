extends "res://script/enemy.gd"


func _ready():
	speed=1000
	

func _physics_process(delta):
	if points.size()==0:
		return 
	var target =points[pointIndex]
	print(position.distance_to(target))
	if position.distance_to(target) < 1:
		print(pointIndex)
		pointIndex=wrapi(pointIndex+1, 0,points.size())
		target =points[pointIndex]
	vec = (target - position).normalized() * speed
	position+=vec*delta
