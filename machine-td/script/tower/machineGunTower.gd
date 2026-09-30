extends "res://script/tower/tower.gd"

var bullet = preload("res://scene/bullet/gunBullet.tscn")

@onready var shotSound = $ShotSound

func _ready():
	turret.rotation = randf() * TAU
	super._ready()


func fire(t):
	#print("fire")
	if canShot:
		player.play("fire")
		# 开火音在场景的 shotSound 节点上。机枪射速快、间隔短，所以：
		#   ①素材只有 0.2 秒（长的会叠成一团）
		#   ②节点音量压到 -9dB（火箭/加农是 -4dB）
		#   ③同一个 player 每次 play() 会重头播，只听到"哒"的那一下，正好是连发的手感
		shotSound.play()
		playMuzzleFlash(t.global_position)
		var temp = bullet.instantiate()
		temp.position = marker.global_position
		temp.angle = (t.global_position - marker.global_position).angle()
		temp.sourceTower = self
		temp.damage = atk
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

	var muzzlePos = marker.global_position
	var direction = temp.global_position - muzzlePos
	if direction.length_squared() < 0.01:
		return

	var targetAngle = direction.angle()
	var currentAngle = turret.rotation
	var angleDiff: float = wrapf(targetAngle - currentAngle, -PI, PI)
	turret.rotation = currentAngle + angleDiff * min(1.0, rotationSpeed * _delta)

	if abs(angleDiff) < 0.12:
		fire(temp)
