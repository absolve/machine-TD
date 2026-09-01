extends "res://script/tower.gd"

var bullet = preload("res://scene/gunBullet.tscn")

func _ready():
	turret.rotation = randf() * TAU
	super._ready()


func _physics_process(_delta):
	super._physics_process(_delta)
	var temp = getTarget()
	if temp == null:
		return

	var muzzle_pos= marker.global_position
	var direction = temp.global_position - muzzle_pos
	if direction.length_squared() < 0.01:
		return

	var target_angle = direction.angle()
	var current_angle = turret.rotation
	var angle_diff := wrapf(target_angle - current_angle, -PI, PI)
	turret.rotation = current_angle + angle_diff * min(1.0, rotationSpeed * _delta)

	if abs(angle_diff) < 0.12:
		fire(temp)

func fire(t):
	#print("fire")
	if canShot:
		player.play("fire")
		var temp = bullet.instantiate()
		temp.position = marker.global_position
		temp.angle = (t.global_position - marker.global_position).angle()
		temp.source_tower = self
		temp.damage = atk
		Game.addObj(temp)
		canShot = false
		delayTimer.start()


func _on_radar_area_entered(area):
	target.push_back(area)


func _on_radar_area_exited(area):
	target.erase(area)
