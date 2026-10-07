extends "res://script/enemy/enemy.gd"



func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()

	
#func hurt(_num: int, _source = null):
	#hp -= _num
	#lifeBar.value = hp
	#if hp < 0:
		#ExplosionManage.playExplosion(global_position)
		#Game.enemyRewarded.emit(reward)

#func _physics_process(_delta):
	#if points.size() == 0:
		#return
	#parent.progress += speed * _delta
	#if parent.progress_ratio >= 1:
		#Game.enemyEscaped.emit(lossPoints)
