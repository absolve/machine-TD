extends "res://script/enemy.gd"
#自爆卡车 敌人



func _ready():
	parent = get_parent()
	setupEnemyInfo()

func _physics_process(_delta):
	if points.size() == 0:
		return
	parent.progress += speed * _delta
	if parent.progress_ratio >= 1:
		Game.enemyEscape.emit(lossPoints)
		owner.queue_free()
