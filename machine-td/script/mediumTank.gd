extends "res://script/enemy.gd"

var parent: PathFollow2D
var bullet = preload("res://scene/enemy_bullet.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()

#func hurt(_num: int, _source = null):
	#hp -= _num
	#lifeBar.value = hp
	#if hp < 0:
		#ExplosionManage.playExplosion(global_position)
		#Game.defeatEnemy.emit(reward)
		#owner.queue_free()

func fire(t):
	if not is_instance_valid(t):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		b.global_position = turret.global_position
		b.angle = turret.global_rotation
		b.damage = atk
		b.target = t
		Game.addObj(b)
		delayTimer.start()
	

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
	if target.size() > 0:
		var temp = target[0]
		var direction = (temp.global_position - turret.global_position).normalized()
		var target_angle = direction.angle()
		turret.rotation = lerp_angle(turret.rotation, target_angle, rotationSpeed * _delta)
		if abs(turret.rotation - target_angle) < .1:
			fire(temp)

func _on_radar_area_entered(area):
	target.append(area)

func _on_radar_area_exited(area):
	target.erase(area)
