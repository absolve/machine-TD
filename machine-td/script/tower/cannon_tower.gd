extends "res://script/tower/tower.gd"

var bullet = preload("res://scene/bullet/cannon_bullet.tscn")

@onready var shotSound = $ShotSound

func _ready():
	turret.rotation = randf() * TAU
	super._ready()

func fire(t):
	if canShot:
		player.play("fire")
		# 开火音就在本场景的 shotSound 节点上（AudioStreamPlayer2D，自带 2D 定位）。
		# ⚠️ 必须写 $ShotSound 不能写裸的 shotSound —— GDScript 不认裸标识符，
		#    而且它只在真实例化时才报错，光导入（--editor --quit）是查不出来的。
		shotSound.play()
		playMuzzleFlash(t.global_position)
		var temp = bullet.instantiate()
		temp.position = getMuzzlePosition()
		temp.angle = (t.global_position - getMuzzlePosition()).angle()
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

	var muzzlePos = getMuzzlePosition()
	var direction = temp.global_position - muzzlePos
	if direction.length_squared() < 0.01:
		return

	var targetAngle = direction.angle()
	var currentAngle = turret.rotation
	var angleDiff: float = wrapf(targetAngle - currentAngle, -PI, PI)
	turret.rotation = currentAngle + angleDiff * min(1.0, rotationSpeed * _delta)

	if abs(angleDiff) < 0.12:
		fire(temp)
