extends "res://script/enemy.gd"
#维修车 敌人



var parent: PathFollow2D

func _ready():
	parent = get_parent()
	setupEnemyInfo()
