extends "res://script/enemy/enemy.gd"

#侦察无人机 敌人


func _ready():
	parent = get_parent()
	setupEnemyInfo()
	
