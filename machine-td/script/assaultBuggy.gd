extends "res://script/enemy.gd"
#突击车 敌人 快速推进


func _ready():
	parent = get_parent()
	setupEnemyInfo()
