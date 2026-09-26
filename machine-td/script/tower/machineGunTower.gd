extends "res://script/tower/tower.gd"

var bullet = preload("res://scene/bullet/gunBullet.tscn")

@onready var shotSound=$shotSound

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
		# 开火音在场景的 shotSound 节点上。机枪射速快、间隔短，所以：
		#   ①素材只有 0.2 秒（长的会叠成一团）
		#   ②节点音量压到 -9dB（火箭/加农是 -4dB）
		#   ③同一个 player 每次 play() 会重头播，只听到"哒"的那一下，正好是连发的手感
		shotSound.play()
		play_muzzle_flash(t.global_position)
		var temp = bullet.instantiate()
		temp.position = marker.global_position
		temp.angle = (t.global_position - marker.global_position).angle()
		temp.source_tower = self
		temp.damage = atk
		Game.addObj(temp)
		canShot = false
		delayTimer.start()


func _on_radar_area_entered(area):
	add_target(area)


func _on_radar_area_exited(area):
	target.erase(area)
