extends "res://script/enemy.gd"

#侦察无人机 敌人

var parent: PathFollow2D

func _ready():
	parent = get_parent()
	setupEnemyInfo()
	
