extends "res://script/tower/tower.gd"

var bullet = preload("res://scene/bullet/rocketbullet.tscn")

@onready var shotSound=$shotSound

func _ready():
	turret.rotation = randf() * TAU
	super._ready()


func _physics_process(_delta):
	super._physics_process(_delta)
	var temp = getTarget()
	if temp == null:
		return

	var muzzle_pos = get_muzzle_position()
	var direction = temp.global_position - muzzle_pos
	if direction.length_squared() < 0.01:
		return

	var target_angle = direction.angle()
	var current_angle = turret.rotation
	var angle_diff = wrapf(target_angle - current_angle, -PI, PI)
	turret.rotation = current_angle + angle_diff * min(1.0, rotationSpeed * _delta)

	if abs(angle_diff) < 0.12:
		fire(temp)

func fire(t):
	if canShot:
		player.play("fire")
		# 发射音就在本场景的 shotSound 节点上（AudioStreamPlayer2D，自带 2D 定位，
		# 离镜头远会自然变轻）。用 play() 而不是 SoundManage：这声音是塔自带的，
		# 跟着塔一起进场景树，塔被卖掉/摧毁时会自然停掉，不用手动管理。
		shotSound.play()
		play_muzzle_flash(t.global_position)
		var temp = bullet.instantiate()
		temp.position = get_muzzle_position()
		temp.angle = (t.global_position - get_muzzle_position()).angle()
		temp.source_tower = self
		Game.addObj(temp)
		canShot = false
		delayTimer.start()


func _on_radar_area_entered(area):
	add_target(area)


func _on_radar_area_exited(area):
	target.erase(area)
