extends "res://script/tower.gd"

var bullet=preload("res://scene/gunBullet.tscn")

func _ready():
	delay=1
	delayTimer.wait_time=delay
	pass

func _physics_process(_delta):
	var temp=getTarget()
	if temp:
		fire(temp)
		pass
	pass

func fire(t):
	print("fire")
	if canShot:
		var temp=bullet.instantiate()
		temp.position=global_position
		temp.angle=global_position.angle_to(t.global_position)
		Game.addObj(temp)
		canShot=false
	else:
		if delayTimer.is_stopped():
			delayTimer.start()


func _on_radar_area_entered(area):
	target.push_back(area)
	print(1111)


func _on_radar_area_exited(area):
	target.erase(area)
