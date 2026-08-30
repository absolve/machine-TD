extends "res://script/enemy.gd"
#导弹车  每隔一段时间发射导弹攻击范围的防御塔

var bulletScene = preload("res://scene/enemy_missile.tscn")


func _ready():
	parent = get_parent()
	setupEnemyInfo()


func fire(t):
	if not is_instance_valid(t):
		return
	if canShot:
		canShot = false
		var b = bulletScene.instantiate()
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


func _on_radar_area_entered(area: Area2D) -> void:
	target.append(area)


func _on_radar_area_exited(area: Area2D) -> void:
	target.erase(area)
