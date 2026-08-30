extends "res://script/enemy.gd"

#攻击直升机 敌人

var bullet = preload("res://scene/enemy_bullet.tscn")


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()


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
		if is_instance_valid(temp):
			fire(temp)


func _on_radar_area_entered(area):
	target.append(area)


func _on_radar_area_exited(area):
	target.erase(area)
