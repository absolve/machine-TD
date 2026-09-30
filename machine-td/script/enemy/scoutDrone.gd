extends "res://script/enemy/enemy.gd"
## 侦察无人机：空中侦察型敌人。


func _ready() -> void:
	parent = get_parent()
	setupEnemyInfo()
	
