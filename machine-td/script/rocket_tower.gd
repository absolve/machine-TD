extends "res://script/tower.gd"

var bullet = preload("res://scene/rocketbullet.tscn")

func _ready():
	delay = 1
	delayTimer.wait_time = delay
	super._ready()


func _physics_process(_delta):
	var temp = getTarget()
	if temp:
		var direction = (temp.global_position - turret.global_position).normalized()
		var target_angle = direction.angle()
		#turret.rotate(deg_to_rad(90))
		turret.rotation = lerp_angle(turret.rotation, target_angle, rotationSpeed * _delta)
		#turret.look_at(temp.global_position)
		if abs(turret.rotation - target_angle) < .1:
			fire(temp)
	
		
func fire(t):
	#print("fire")
	if canShot:
		#player.play("fire")
		var temp = bullet.instantiate()
		temp.position = marker.global_position
		temp.angle = position.direction_to(t.global_position).angle()
		
		Game.addObj(temp)
		canShot = false
		delayTimer.start()


func _on_radar_area_entered(area):
	target.push_back(area)


func _on_radar_area_exited(area):
	target.erase(area)
