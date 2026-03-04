extends "res://script/enemy.gd"

var parent:PathFollow2D


func _ready() -> void:
	parent=get_parent()

func hurt(_num):
	hp -= _num
	lifeBar.value = hp
	if hp < 0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		owner.queue_free()

func fire(t):
	
	pass


func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress+=speed*_delta	
	if parent.progress_ratio>=1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
	if target.size()>0:
		var temp =target[0]
		var direction = (temp.global_position - turret.global_position).normalized()
		var target_angle = direction.angle()
		turret.rotation = lerp_angle(turret.rotation, target_angle, rotationSpeed * _delta)
		if abs(turret.rotation - target_angle) < .1:
			fire(temp)

func _on_radar_area_entered(area):
	target.append(area)

func _on_radar_area_exited(area):
	target.erase(area)
