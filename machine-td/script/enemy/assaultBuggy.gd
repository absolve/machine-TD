extends "res://script/enemy/enemy.gd"
## 突击车：快速推进型敌人。


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()
