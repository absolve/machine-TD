extends "res://script/tower/tower.gd"

var bullet = preload("res://scene/bullet/rocketbullet.tscn")

@onready var shotSound=$ShotSound

func _ready():
	turret.rotation = randf() * TAU
	super._ready()


func fire(t):
	if canShot:
		player.play("fire")
		# 发射音就在本场景的 shotSound 节点上（AudioStreamPlayer2D，自带 2D 定位，
		# 离镜头远会自然变轻）。用 play() 而不是 SoundManage：这声音是塔自带的，
		# 跟着塔一起进场景树，塔被卖掉/摧毁时会自然停掉，不用手动管理。
		shotSound.play()
		playMuzzleFlash(t.global_position)
		var temp = bullet.instantiate()
		temp.position = getMuzzlePosition()
		temp.angle = (t.global_position - getMuzzlePosition()).angle()
		temp.sourceTower = self
		Game.addObj(temp)
		canShot = false
		delayTimer.start()


func _onRadarAreaEntered(area):
	addTarget(area)


func _onRadarAreaExited(area):
	target.erase(area)


func _physics_process(_delta):
	super._physics_process(_delta)
	var temp = getTarget()
	if temp == null:
		return

	var muzzlePos = getMuzzlePosition()
	var direction = temp.global_position - muzzlePos
	if direction.length_squared() < 0.01:
		return

	var targetAngle = direction.angle()
	var currentAngle = turret.rotation
	var angleDiff = wrapf(targetAngle - currentAngle, -PI, PI)
	turret.rotation = currentAngle + angleDiff * min(1.0, rotationSpeed * _delta)

	if abs(angleDiff) < 0.12:
		fire(temp)
