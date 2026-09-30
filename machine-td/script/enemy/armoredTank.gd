extends "res://script/enemy/enemy.gd"
## 装甲坦克：厚甲推进型敌人。


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()
