extends "res://script/enemy.gd"

var parent:PathFollow2D

func _ready():
	parent=get_parent()
	pass
	
func hurt(_num):
	hp -= _num
	lifeBar.value = hp
	if hp < 0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		owner.queue_free()

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress+=speed*_delta	
	if parent.progress_ratio>=1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
