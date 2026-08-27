extends "res://script/enemy.gd"
#装甲坦克 敌人

var parent: PathFollow2D

func _ready():
	parent = get_parent()
	setupEnemyInfo()
